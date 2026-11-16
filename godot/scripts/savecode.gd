class_name SaveCode
## Save codes: progress packed into 41 letters with a check, typed back in to restore. The same format as SaveCode in
## src/08f_meta.js, so a code from the browser game loads here and the other way round. The numbers are longer than 64 bits,
## so they are handled as lists of bits (most significant first).

const AL := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const F1 := [["ver", 4], ["money", 27], ["unlocked", 2], ["cleared", 3], ["t1", 13], ["t2", 13], ["t3", 13], ["lo", 21]]
const F2 := [["ver", 4], ["money", 27], ["unlocked", 3], ["cleared", 5], ["t1", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["lo", 21]]
const F3 := [["ver", 4], ["money", 27], ["cleared", 6], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["lo", 21]]
const F4 := [["ver", 4], ["money", 27], ["cleared", 6], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["lo", 21], ["ih", 1], ["iv", 4], ["ij", 1]]
const F5 := [["ver", 4], ["money", 27], ["cleared", 6], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["lo", 21], ["ih", 1], ["iv", 4], ["ij", 1], ["ivory", 6]]
const F6 := [["ver", 4], ["money", 27], ["cleared", 6], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["lo", 21], ["ih", 1], ["iv", 4], ["ij", 1], ["ivory", 6], ["own", 6]]
const F7 := [["ver", 4], ["money", 27], ["cleared", 7], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["t7", 13], ["lo", 21], ["ih", 1], ["iv", 4], ["ij", 1], ["ivory", 6], ["own", 6]]
const F8 := [["ver", 4], ["money", 27], ["cleared", 8], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["t7", 13], ["t8", 13], ["lo", 28], ["ih", 1], ["iv", 4], ["ij", 1], ["ivory", 6], ["own", 7]]
# version 9 (57 letters, the Godot version) adds each gun's customisation: sight, muzzle, underbarrel (2 bits each) and paint (4 bits), in Weapons.ORDER
const F9 := [["ver", 4], ["money", 27], ["cleared", 8], ["t1", 13], ["t6", 13], ["t5", 13], ["t2", 13], ["t3", 13], ["t4", 13], ["t7", 13], ["t8", 13], ["lo", 28], ["ih", 1], ["iv", 4], ["ij", 1], ["ivory", 6], ["own", 7],
	["c0", 10], ["c1", 10], ["c2", 10], ["c3", 10], ["c4", 10], ["c5", 10], ["c6", 10], ["c7", 10]]
const BY_LEN := {57: [F9, 9], 22: [F1, 1], 28: [F2, 2], 30: [F3, 3], 31: [F4, 4], 32: [F5, 5], 34: [F6, 6], 36: [F7, 7], 41: [F8, 8]}
# which bit is which stage, as each version wrote them
const ORDER2 := [1, 5, 2, 3, 4]
const ORDER6 := [1, 6, 5, 2, 3, 4]
const ORDER7 := [1, 6, 5, 2, 3, 4, 7]
const ORDER8 := [1, 6, 5, 2, 3, 4, 7, 8]
const OWN7 := ["shotgun", "rifle", "smg", "sniper", "gl", "lmg", "rocket"]

static func _push(bits: Array, value: int, n: int) -> void:
	for i in range(n - 1, -1, -1): bits.push_back((value >> i) & 1)

## the 12-bit check: FNV-1a over the number written in hexadecimal (no leading zeros), folded
static func _check(bits: Array) -> int:
	var b := bits.duplicate()
	while b.size() % 4 != 0: b.push_front(0)
	var hex := ""
	for i in range(0, b.size(), 4): hex += "0123456789abcdef"[b[i] * 8 + b[i + 1] * 4 + b[i + 2] * 2 + b[i + 3]]
	hex = hex.lstrip("0")
	if hex == "": hex = "0"
	var h := 0x811c9dc5
	for ch in hex: h ^= ch.unicode_at(0); h = (h * 16777619) & 0xFFFFFFFF
	return (h ^ (h >> 12)) & 0xfff

## the Godot version's code: everything the browser game's code holds, and the guns' customisation
static func encode(save: Dictionary, money_lock = null, ivory_lock = null, own_lock = null) -> String:
	return _encode(save, money_lock, ivory_lock, own_lock, 9)

## the browser game's format (version 8, 41 letters): no customisation, but the browser game can read it
static func encode_v8(save: Dictionary, money_lock = null, ivory_lock = null, own_lock = null) -> String:
	return _encode(save, money_lock, ivory_lock, own_lock, 8)

static func _encode(save: Dictionary, money_lock, ivory_lock, own_lock, ver: int) -> String:
	var t := func(k: String) -> int: return mini(int(save.best.get(k, 0)), 8191)
	var lo := 0
	for i in 7:
		var id = save.loadout[i]
		lo += ((Weapons.ORDER.find(id) + 1) if id != null else 0) << (4 * i)
	var cleared := 0; var done: Array = (save.cleared as Array).map(func(n): return int(n))   # (a save read from text holds 1.0, not 1)
	for i in ORDER8.size():
		if done.has(ORDER8[i]): cleared |= 1 << i
	var own := 0; var owned: Array = save.owned if own_lock == null else own_lock
	for i in OWN7.size():
		if owned.has(OWN7[i]): own |= 1 << i
	var v := {"ver": ver, "money": clampi(int(save.money) if money_lock == null else mini(int(save.money), money_lock), 0, (1 << 27) - 1), "cleared": cleared,
		"t1": t.call("t1"), "t6": t.call("t6"), "t5": t.call("t5"), "t2": t.call("t2"), "t3": t.call("t3"), "t4": t.call("t4"), "t7": t.call("t7"), "t8": t.call("t8"), "lo": lo,
		"ih": 1 if save.items.helmet else 0, "iv": clampi(int(save.items.vest), 0, 10), "ij": 1 if save.items.jet else 0,
		"ivory": clampi(int(save.items.ivory) if ivory_lock == null else mini(int(save.items.ivory), ivory_lock), 0, 63), "own": own}
	var cu = save.get("custom", {})
	for i in Weapons.ORDER.size():
		var c: Dictionary = cu.get(Weapons.ORDER[i], {}) if cu is Dictionary and cu.get(Weapons.ORDER[i]) is Dictionary else {}
		for slot in Custom.SLOTS:   # only what fits the gun is written
			if not Custom.fits(Weapons.ORDER[i], slot, Custom.part_of(slot, c.get(slot)).id): c = c.duplicate(); c.erase(slot)
		v["c%d" % i] = (Custom.part_index("sight", c.get("sight")) << 8) | (Custom.part_index("muzzle", c.get("muzzle")) << 6) | (Custom.part_index("under", c.get("under")) << 4) | Custom.paint_index(c.get("paint"))
	var F: Array = F9 if ver == 9 else F8; var letters := 57 if ver == 9 else 41
	var bits := []
	for f in F: _push(bits, v[f[0]], f[1])
	_push(bits, _check(bits), 12)
	while bits.size() < letters * 5: bits.push_front(0)
	var s := ""
	for i in letters:
		var k := 0
		for j in 5: k = k * 2 + bits[i * 5 + j]
		s += AL[k]
		if i % 5 == 4 and i < letters - 1: s += "-"
	return s

## a save from a code, or null when the code is not a good one
static func decode(text: String):
	var clean := text.to_upper().replace(" ", "").replace("-", "").replace("\n", "").replace("\t", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if not BY_LEN.has(clean.length()): return null
	var F: Array = BY_LEN[clean.length()][0]; var ver: int = BY_LEN[clean.length()][1]
	var bits := []
	for ch in clean:
		var k := AL.find(ch)
		if k < 0: return null
		_push(bits, k, 5)
	var ck := 0
	for i in range(bits.size() - 12, bits.size()): ck = ck * 2 + bits[i]
	var p := bits.slice(0, bits.size() - 12)
	if _check(p) != ck: return null
	var o := {}; var at := p.size()
	for i in range(F.size() - 1, -1, -1):
		var n: int = F[i][1]; var val := 0
		for j in range(at - n, at): val = val * 2 + p[j]
		o[F[i][0]] = val; at -= n
	for j in at:
		if p[j] != 0: return null
	if o.ver != ver or int(o.get("iv", 0)) > 10: return null
	if ver <= 2 and (o.unlocked < 1 or o.unlocked > (3 if ver == 1 else 5)): return null
	var best := {}
	for k in ["t1", "t6", "t5", "t2", "t3", "t4", "t7", "t8"]:
		if int(o.get(k, 0)) > 0: best[k] = o[k]
	var order: Array = [1, 2, 3] if ver == 1 else (ORDER2 if ver == 2 else (ORDER6 if ver <= 6 else (ORDER7 if ver == 7 else ORDER8)))
	var cleared := []
	for i in order.size():
		if o.cleared & (1 << i): cleared.push_back(order[i])
	if ver == 2 and cleared.has(5): cleared.push_back(6)
	var lo := []; var x: int = o.lo; var base := 16 if ver >= 8 else 8
	for i in 7:
		var c := x % base; x /= base
		lo.push_back(Weapons.ORDER[c - 1] if (c > 0 and c <= Weapons.ORDER.size()) else null)
	var owned := []
	for i in OWN7.size():
		if int(o.get("own", 0)) & (1 << i): owned.push_back(OWN7[i])
	var custom := {}
	if ver == 9:
		for i in Weapons.ORDER.size():
			var c: int = o["c%d" % i]
			if c == 0 or (c & 15) >= Custom.PAINTS.size(): continue
			custom[Weapons.ORDER[i]] = {"sight": Custom.PARTS.sight.list[(c >> 8) & 3].id, "muzzle": Custom.PARTS.muzzle.list[(c >> 6) & 3].id, "under": Custom.PARTS.under.list[(c >> 4) & 3].id, "paint": Custom.PAINTS[c & 15].id}
	return {"custom": custom, "v": 4, "money": o.money, "cleared": cleared, "best": best, "loadout": lo, "rented": [], "owned": owned,
		"items": {"helmet": o.get("ih", 0), "vest": o.get("iv", 0), "jet": o.get("ij", 0), "ivory": o.get("ivory", 0)}}

## the developer mode password is kept only as this hash
static func dev_hash(t: String) -> int:
	var h := 0x811c9dc5
	for ch in "yard07-dev:" + t: h ^= ch.unicode_at(0); h = (h * 16777619) & 0xFFFFFFFF
	return h
const DEV_HASH := 0x87114c2b

# ---------------- sending the code by mail (SaveMail in src/08f_meta.js) ----------------
## the mail's subject and body: the code, when it was saved, the stages cleared and the bag. when: "YYYY-MM-DD HH:MM"
static func mail_text(save: Dictionary, code: String, when: String) -> Dictionary:
	var done: Array = Store.STAGE_ORDER.filter(func(st): return (save.cleared as Array).has(st)).map(func(st): return Store.STAGE_TAG[st])
	var subject := "야르 07 저장 코드 · " + when
	var body := "\r\n".join(["야르 07 저장 코드", "", code, "", "저장한 때: " + when, "깬 스테이지: " + (", ".join(done) if not done.is_empty() else "없음"), "가방: " + Store.won(save.money), "",
		"게임 처음 화면의 '불러오기'에 위 코드를 넣으면 이 진행 상황으로 돌아갑니다."])
	return {"subject": subject, "body": body}

static func now_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]

## a written address that looks like one, or "" (an empty or odd address leaves the mail's "to" empty)
static func mail_addr(a: String) -> String:
	a = a.strip_edges(); var re := RegEx.new(); re.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	return a if re.search(a) != null else ""

## the mail app's link and Gmail's compose page, both filled in
static func mail_links(addr: String, subject: String, body: String) -> Dictionary:
	var a := mail_addr(addr)
	return {"mailto": "mailto:" + a.uri_encode().replace("%40", "@") + "?subject=" + subject.uri_encode() + "&body=" + body.uri_encode(),
		"gmail": "https://mail.google.com/mail/?view=cm&fs=1" + ("&to=" + a.uri_encode() if a != "" else "") + "&su=" + subject.uri_encode() + "&body=" + body.uri_encode()}
