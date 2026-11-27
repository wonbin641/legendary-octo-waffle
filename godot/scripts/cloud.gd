extends Node
## The account: sign in with an id and your progress is kept on the game's server too (server/ at the top of the
## repository: Cloudflare Workers and a D1 database), so a phone, a computer and a browser go on from the same place.
## Nobody has to sign in: without it the game saves on the device as it always has.
##
## The password never leaves the device. What goes to the server is a key stretched from it here (PBKDF2-HMAC-SHA256,
## the id as salt, 100,000 rounds: slow on purpose, so a stolen database is slow to guess against), a few milliseconds
## of it each frame. The server knows a signed-in device by a token, kept with the id in the game's own storage.
##
## Which progress stays is never decided behind the player's back when both sides have some: the account's save has a
## number (rev) that goes up with each write, a device sends the number it last saw with its own save, and when another
## device has written in between and this one has changes too, the player is asked (ask). A device with no progress of
## its own takes the account's; an account with none takes the device's.

const BASE := "https://accounts.yarr07.workers.dev"   # the server (server/ at the top of the repository); "" would mean none: then the game shows no account at all
## the pages the server answers from a browser (server/wrangler.toml, ORIGINS): the web game anywhere else (the claude.ai
## artifact, a copy on another site) shows no account, rather than one whose every request the browser would refuse
const WEB_PAGES := ["https://wonbin641.github.io"]
const ROUNDS := 100000    # the key's stretching (the server's kdf 1)
const ID_MIN := 3; const ID_MAX := 16; const PW_MIN := 8; const PW_MAX := 64
const RETRY := 15.0; const RETRY_MAX := 300.0   # the server not reached: again in 15 s, then twice as long each time, 5 minutes at most

## "sign": signed in or out. "sync": a save has gone up, or could not. "ask": a choice to make. "applied": the account's
## progress is now this device's. "busy": working (the key, a request): progress has how far
signal changed(what: String)

var base := BASE
var rounds := ROUNDS
var store_key := "account"     # where the device keeps who is signed in (Store's storage)
var transport := Callable()    # (the checks: stands in for the network) func(method, path, body, token) -> {status, json}
var idle := Callable()         # is the game at rest in the menu? (main) Only then is the account's progress put in place of the device's
var id := ""; var token := ""; var rev := 0; var dirty := false; var at := 0
var ask := {}                  # a choice to make: the account's save {data, rev, updated}, against this device's
var incoming := {}             # the account's newer save, waiting for the menu
var busy := false; var progress := 0.0
var offline := false           # the last try did not reach the server
var lost := false              # signed out by the server (the password was set again somewhere, or 180 days away): sign in again
var _wait := 0.0; var _fails := 0; var _applying := false; var _talking := false

func enabled() -> bool: return base != ""
func signed_in() -> bool: return token != ""
func asking() -> bool: return not ask.is_empty()

func _ready() -> void:
	if OS.has_feature("web"):
		var o := str(JavaScriptBridge.eval("(function(){try{return window.YARR07_API||''}catch(e){return ''}})()"))
		var re := RegEx.new(); re.compile("^http://(127\\.0\\.0\\.1|localhost):[0-9]{2,5}$")
		if re.search(o) != null: base = o   # (the browser checks: a server on this very machine, and nowhere else)
		elif not WEB_PAGES.has(str(JavaScriptBridge.eval("(function(){try{return location.origin||''}catch(e){return ''}})()"))): base = ""
	var d = Store._read(store_key)
	if d is Dictionary and str(d.get("token", "")) != "":
		id = str(d.get("id", "")); token = str(d.token); rev = int(d.get("rev", 0)); dirty = bool(d.get("dirty", false)); at = int(d.get("at", 0))
	Store.saved.connect(_on_saved)
	if enabled() and signed_in(): refresh.call_deferred()

## (the checks) nothing goes to a server in this run, whoever is signed in on this machine; what the device keeps of the
## sign-in is not touched
func mute() -> void:
	base = ""; transport = Callable(); id = ""; token = ""; rev = 0; dirty = false; at = 0; ask = {}; incoming = {}; offline = false; lost = false

func _keep() -> void:
	Store._write(store_key, {"id": id, "token": token, "rev": rev, "dirty": dirty, "at": at} if signed_in() else {})

# ---------------- the key ----------------
## PBKDF2-HMAC-SHA256, one block (32 bytes), a part at a time
class Kdf:
	var ctx := HashingContext.new()
	var ipad := PackedByteArray(); var opad := PackedByteArray(); var u := PackedByteArray()
	var a0 := 0; var a1 := 0; var a2 := 0; var a3 := 0
	var left := 0
	func _init(password: PackedByteArray, salt: PackedByteArray, n: int) -> void:
		var k := password
		if k.size() > 64: ctx.start(HashingContext.HASH_SHA256); ctx.update(k); k = ctx.finish()
		k.resize(64); ipad.resize(64); opad.resize(64)
		for i in 64: ipad[i] = k[i] ^ 0x36; opad[i] = k[i] ^ 0x5c
		u = _mac(salt + PackedByteArray([0, 0, 0, 1])); _fold(); left = n - 1
	func _mac(msg: PackedByteArray) -> PackedByteArray:
		ctx.start(HashingContext.HASH_SHA256); ctx.update(ipad); ctx.update(msg); var inner := ctx.finish()
		ctx.start(HashingContext.HASH_SHA256); ctx.update(opad); ctx.update(inner); return ctx.finish()
	func _fold() -> void:
		a0 ^= u.decode_s64(0); a1 ^= u.decode_s64(8); a2 ^= u.decode_s64(16); a3 ^= u.decode_s64(24)
	func step(n: int) -> void:
		for i in mini(n, left): u = _mac(u); _fold()
		left -= mini(n, left)
	func out() -> PackedByteArray:
		var o := PackedByteArray(); o.resize(32); o.encode_s64(0, a0); o.encode_s64(8, a1); o.encode_s64(16, a2); o.encode_s64(24, a3)
		return o

static func clean_id(t: String) -> String:
	return t.strip_edges().to_lower()

static func id_error(i: String) -> String:
	var re := RegEx.new(); re.compile("^[a-z0-9_]{%d,%d}$" % [ID_MIN, ID_MAX])
	return "" if re.search(i) != null else "아이디는 영문 소문자, 숫자, 밑줄(_)로 %d~%d자입니다" % [ID_MIN, ID_MAX]

static func pw_error(p: String) -> String:
	if p.length() < PW_MIN: return "비밀번호는 %d자 이상입니다" % PW_MIN
	return "" if p.length() <= PW_MAX else "비밀번호는 %d자까지입니다" % PW_MAX

## the key the server knows a password by, all at once (the checks; the game works it out a part each frame: stretch)
static func key_of(the_id: String, password: String, n := ROUNDS) -> String:
	var k := Kdf.new(password.to_utf8_buffer(), ("yarr07:" + clean_id(the_id)).to_utf8_buffer(), n)
	k.step(k.left)
	return k.out().hex_encode()

## the same key, worked out without holding the game up: in a browser by the browser's own PBKDF2 (off the game's
## thread, a tenth of a second), elsewhere here, some 30 ms of it each frame
func stretch(the_id: String, password: String) -> String:
	var salt := "yarr07:" + clean_id(the_id)
	if OS.has_feature("web"):
		var k := await _stretch_web(password, salt)
		if k != "": return k
	var k2 := Kdf.new(password.to_utf8_buffer(), salt.to_utf8_buffer(), rounds)
	while k2.left > 0:
		var t0 := Time.get_ticks_msec()
		while k2.left > 0 and Time.get_ticks_msec() - t0 < 30: k2.step(400)
		progress = 1.0 - float(k2.left) / float(rounds); changed.emit("busy")
		if k2.left > 0: await get_tree().process_frame
	return k2.out().hex_encode()

## the browser's PBKDF2 (Web Crypto): "" when the page has none (then the game's own does it)
func _stretch_web(password: String, salt: String) -> String:
	var js := "(function(p,s,n){window.__yarrKey='';try{var e=new TextEncoder();crypto.subtle.importKey('raw',e.encode(p),'PBKDF2',false,['deriveBits'])" \
		+ ".then(function(k){return crypto.subtle.deriveBits({name:'PBKDF2',salt:e.encode(s),iterations:n,hash:'SHA-256'},k,256)})" \
		+ ".then(function(b){window.__yarrKey=Array.from(new Uint8Array(b)).map(function(x){return x.toString(16).padStart(2,'0')}).join('')})" \
		+ ".catch(function(){window.__yarrKey='none'})}catch(x){window.__yarrKey='none'}})(%s,%s,%d)"
	JavaScriptBridge.eval(js % [JSON.stringify(password), JSON.stringify(salt), rounds])
	for i in 600:
		var got := str(JavaScriptBridge.eval("(function(){var k=window.__yarrKey||'';if(k)window.__yarrKey='';return k})()"))
		if got.length() == 64: return got
		if got == "none": return ""
		await get_tree().process_frame
	return ""

# ---------------- the server ----------------
func _call(method: String, path: String, body = null, tok := "") -> Dictionary:
	if transport.is_valid(): return await transport.call(method, path, body, tok)
	var req := HTTPRequest.new(); req.timeout = 12.0; req.accept_gzip = false; add_child(req)
	var head := PackedStringArray()
	if body != null: head.push_back("Content-Type: application/json")
	if tok != "": head.push_back("Authorization: Bearer " + tok)
	var how := HTTPClient.METHOD_GET if method == "GET" else (HTTPClient.METHOD_PUT if method == "PUT" else HTTPClient.METHOD_POST)
	if req.request(base + path, head, how, JSON.stringify(body) if body != null else "") != OK: req.queue_free(); return {"status": 0, "json": {}}
	var res: Array = await req.request_completed   # [result, code, headers, body]
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS: return {"status": 0, "json": {}}
	var j = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"status": int(res[1]), "json": j if j is Dictionary else {}}

## why it did not work, for the player
static func why(r: Dictionary, doing: String) -> String:
	var e := str((r.json as Dictionary).get("error", ""))
	match int(r.status):
		0: return "서버에 연결하지 못했습니다. 인터넷 연결을 확인하고 다시 해 주세요."
		409: return "이미 있는 아이디입니다. 다른 아이디를 써 주세요."
		401:
			if e == "auth": return "로그인이 끝났습니다. 다시 로그인해 주세요."
			return "아이디 또는 복구 코드가 맞지 않습니다" if doing == "recover" else ("비밀번호가 맞지 않습니다" if doing == "delete" else "아이디 또는 비밀번호가 맞지 않습니다")
		429:
			var m := maxi(1, ceili(float((r.json as Dictionary).get("wait", 60)) / 60.0))
			return "여러 번 틀렸거나 너무 자주 시도했습니다. 약 %d분 뒤에 다시 해 주세요." % m
		400: return "입력한 것을 다시 확인해 주세요"
	return "서버에 문제가 있습니다. 잠시 뒤에 다시 해 주세요."

func _busy(on: bool) -> void:
	busy = on; progress = 0.0; changed.emit("busy")

func _signed(i: String, tok: String) -> void:
	id = i; token = tok; rev = 0; dirty = false; at = 0; ask = {}; incoming = {}; offline = false; lost = false; _fails = 0; _wait = 0.0; _keep(); changed.emit("sign")

## the device forgets who was signed in (by_server: it was the server that ended it, and the player is told to sign in again)
func _forget(by_server := false) -> void:
	id = ""; token = ""; rev = 0; dirty = false; at = 0; ask = {}; incoming = {}; offline = false; lost = by_server; _fails = 0; _wait = 0.0; _keep(); changed.emit("sign")

## a new account: {ok, error} or {ok, recovery}. This device's progress goes up to it
func sign_up(new_id: String, password: String) -> Dictionary:
	var i := clean_id(new_id); var e := id_error(i)
	if e == "": e = pw_error(password)
	if e != "" or busy: return {"ok": false, "error": e}
	_busy(true)
	var r := await _call("POST", "/register", {"id": i, "key": await stretch(i, password), "kdf": 1})
	if int(r.status) != 201 or str(r.json.get("token", "")) == "": _busy(false); return {"ok": false, "error": why(r, "up")}
	_signed(i, str(r.json.get("token", ""))); await _settle(null); _busy(false)
	return {"ok": true, "recovery": str(r.json.get("recovery", ""))}

func sign_in(the_id: String, password: String) -> Dictionary:
	var i := clean_id(the_id); var e := id_error(i)
	if e == "" and password == "": e = "비밀번호를 넣어 주세요"
	if e != "" or busy: return {"ok": false, "error": e}
	_busy(true)
	var r := await _call("POST", "/login", {"id": i, "key": await stretch(i, password)})
	if int(r.status) != 200 or str(r.json.get("token", "")) == "": _busy(false); return {"ok": false, "error": why(r, "in")}
	_signed(i, str(r.json.get("token", ""))); await _settle(r.json.get("save")); _busy(false)
	return {"ok": true}

## the password forgotten: the recovery code sets a new one (and is itself replaced: the answer has the new code)
func recover(the_id: String, code: String, password: String) -> Dictionary:
	var i := clean_id(the_id); var e := id_error(i)
	if e == "" and code.strip_edges() == "": e = "복구 코드를 넣어 주세요"
	if e == "": e = pw_error(password)
	if e != "" or busy: return {"ok": false, "error": e}
	_busy(true)
	var r := await _call("POST", "/recover", {"id": i, "recovery": code, "key": await stretch(i, password), "kdf": 1})
	if int(r.status) != 200 or str(r.json.get("token", "")) == "": _busy(false); return {"ok": false, "error": why(r, "recover")}
	_signed(i, str(r.json.get("token", ""))); await _settle(r.json.get("save")); _busy(false)
	return {"ok": true, "recovery": str(r.json.get("recovery", ""))}

## this device forgets the account (its progress stays on the device, and on the account)
func sign_out() -> void:
	if not signed_in() or busy: return
	_busy(true)
	if dirty and ask.is_empty(): await _push()   # (what is not up yet goes up first, if the server answers)
	var tok := token; _forget()
	await _call("POST", "/logout", null, tok)     # (the device has forgotten either way)
	_busy(false)

## the account and all it holds, gone from the server: needs the password again. The device keeps its own progress
func delete_account(password: String) -> Dictionary:
	if not signed_in() or busy: return {"ok": false, "error": ""}
	if password == "": return {"ok": false, "error": "비밀번호를 넣어 주세요"}
	_busy(true)
	var r := await _call("POST", "/delete", {"key": await stretch(id, password)}, token)
	if int(r.status) == 401 and str(r.json.get("error", "")) == "auth": _lose(); _busy(false); return {"ok": false, "error": why(r, "delete")}
	if int(r.status) != 200: _busy(false); return {"ok": false, "error": why(r, "delete")}
	_forget(); _busy(false)
	return {"ok": true}

# ---------------- which progress ----------------
## a save as the game holds it once loaded, as text: two saves are the same progress when these are the same
func shape(d: Dictionary) -> String:
	var keep: Dictionary = Store.save
	Store.save = Store.save0()
	var j = JSON.parse_string(JSON.stringify(d))
	if j is Dictionary: Store.save.merge(j, true)
	Store.fix_save()
	var out := JSON.stringify(Store.save); Store.save = keep
	return out
func same(a: Dictionary, b: Dictionary) -> bool: return shape(a) == shape(b)
func fresh(a: Dictionary) -> bool: return shape(a) == shape(Store.save0())

## a save in a line, for the choice: the bag, the stages cleared, the guns owned
static func summary(d: Dictionary) -> String:
	var cl = d.get("cleared", []); var ow = d.get("owned", [])
	return "가방 %s · 클리어 %d / %d · 가진 총 %d자루" % [Store.won(int(d.get("money", 0))), (cl as Array).size() if cl is Array else 0, Store.STAGE_ORDER.size(), ((ow as Array).size() if ow is Array else 0) + 1]

## a moment on the server's clock, as this device's day and time
static func when(unix: int) -> String:
	if unix <= 0: return ""
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().bias) * 60)
	return "%d월 %d일 %02d:%02d" % [d.month, d.day, d.hour, d.minute]

## just signed in: the account's progress against this device's
func _settle(remote) -> void:
	if not (remote is Dictionary) or not (remote.get("data") is Dictionary): dirty = true; await _push(); return   # nothing kept there yet: this device's goes up
	if same(remote.data, Store.stored()): _in_step(remote); return
	if fresh(Store.stored()): _apply(remote); return   # a device with no progress of its own takes the account's
	ask = remote; changed.emit("ask")

func _in_step(remote: Dictionary) -> void:
	rev = int(remote.get("rev", 0)); at = int(remote.get("updated", 0)); dirty = false; offline = false; _fails = 0; _keep(); changed.emit("sync")

## the account's progress in place of this device's (which is kept aside, as account_before in the game's storage)
func _apply(remote: Dictionary) -> void:
	_applying = true
	Store._write(store_key + "_before", Store.stored())
	Store.save = Store.save0(); Store.save.merge((remote.data as Dictionary).duplicate(true), true); Store.fix_save(); Store.persist()
	_applying = false
	rev = int(remote.get("rev", 0)); at = int(remote.get("updated", 0)); dirty = false; incoming = {}; ask = {}; offline = false; _fails = 0; _keep(); changed.emit("applied")

func _lose() -> void:
	_forget(true)

func _missed() -> void:
	offline = true; _fails += 1; _wait = minf(RETRY_MAX, RETRY * pow(2.0, _fails - 1)); changed.emit("sync")

## this device's progress up to the account: written there only if nobody else has written since this device last looked
## (or, forced, after the player chose this device's)
func _push(force := false) -> void:
	_talking = true
	var data: Dictionary = Store.stored().duplicate(true); var tok := token
	var r := await _call("PUT", "/save", {"data": data, "base": rev, "force": force}, tok)
	_talking = false
	if token != tok: return   # (signed out, or in as someone else, while it was on its way)
	match int(r.status):
		200:
			rev = int(r.json.get("rev", rev)); at = int(r.json.get("updated", at)); offline = false; _fails = 0
			dirty = not same(data, Store.stored())   # (the game may have saved again meanwhile: that goes up next)
			if force: ask = {}
			_keep(); changed.emit("sync")
		409:
			var remote = r.json.get("save")
			if remote is Dictionary and remote.get("data") is Dictionary:
				if same(remote.data, data): _in_step(remote)
				else: offline = false; ask = remote; changed.emit("ask")
			else: _missed()
		401: _lose()
		_: _missed()

## what the account holds now (at the start, and when the player asks): newer than this device's, it comes down
func refresh() -> void:
	if not enabled() or not signed_in() or _talking: return
	_talking = true; var tok := token
	var r := await _call("GET", "/save", null, tok)
	_talking = false
	if token != tok: return
	if int(r.status) == 401: _lose(); return
	if int(r.status) != 200: _missed(); return
	offline = false; _fails = 0
	var remote = r.json.get("save")
	if not (remote is Dictionary) or not (remote.get("data") is Dictionary): dirty = true; _wait = 0.0; _keep(); return   # nothing there: this device's goes up
	if int(remote.get("rev", 0)) == rev: changed.emit("sync"); return   # nobody else has written (what this device still has to send goes up by itself)
	if same(remote.data, Store.stored()): _in_step(remote); return
	if dirty: ask = remote; changed.emit("ask")
	else: incoming = remote; _take()

## the account's newer progress comes down when the game is at rest in the menu (never under a stage in play)
func _take() -> void:
	if incoming.is_empty(): return
	if dirty and not same(incoming.data, Store.stored()): ask = incoming; incoming = {}; changed.emit("ask"); return
	if not idle.is_valid() or idle.call(): _apply(incoming)

## the player's answer to ask: "device" (this device's progress goes over the account's) or "account" (the other way)
func choose(which: String) -> void:
	if ask.is_empty() or busy: return
	if which == "account": _apply(ask); return
	_busy(true); dirty = true; await _push(true); _busy(false)

## send now what is waiting, and see what the account has (the account screen's button)
func sync_now() -> void:
	if not signed_in() or busy or asking(): return
	_busy(true)
	await refresh()
	if signed_in() and dirty and ask.is_empty() and incoming.is_empty(): await _push()
	_busy(false)

func _on_saved() -> void:
	if not enabled() or not signed_in() or _applying: return
	dirty = true; _keep()
	if _fails == 0: _wait = 2.0   # a moment, so a run of saves goes up as one

func _process(dt: float) -> void:
	if not enabled() or not signed_in() or busy or _talking: return
	if not incoming.is_empty(): _take(); return
	if not dirty or not ask.is_empty(): return
	_wait -= dt
	if _wait <= 0.0: _wait = 5.0; _push()

## where things stand, in a line
func status_text() -> String:
	if not signed_in(): return "다시 로그인해 주세요 · 이 기기의 진행 상황은 그대로입니다" if lost else "게스트 · 진행 상황은 이 기기에만 저장됩니다"
	if asking(): return "이 기기와 계정의 진행 상황이 달라 골라야 합니다"
	if offline: return "서버에 연결하지 못했습니다 · 이 기기에는 저장되어 있고, 연결되면 계정에도 저장됩니다"
	if dirty: return "계정에 저장하는 중…"
	return "계정에 저장됨" + (" · " + when(at) if at > 0 else "")
