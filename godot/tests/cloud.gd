extends Node
## The game's own account code (scripts/cloud.gd) against the real account server: server/src/index.js running in
## Cloudflare's runtime on this machine, started by server/test/game.test.mjs, which then runs this. Real requests over
## HTTP, the real key (100,000 rounds), the real answers.
## Run: (in server/) GODOT=/path/to/godot node test/game.test.mjs

var fails := 0
func check(name: String, ok: bool, info = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ((" " + str(info)) if str(info) != "" else ""))
	if not ok: fails += 1

## until it is so, or two hundred frames... (a request takes a few)
func _until(cond: Callable, secs := 10.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0: return false
		await get_tree().process_frame
	return true

func _ready() -> void:
	var url := OS.get_environment("YARR07_ACCOUNTS"); var re := RegEx.new(); re.compile("^http://127\\.0\\.0\\.1:[0-9]{2,5}$")
	if re.search(url) == null: print("FAIL needs the address of a server on this machine in YARR07_ACCOUNTS: run server/test/game.test.mjs"); get_tree().quit(1); return
	var C = Cloud; var K = load("res://scripts/cloud.gd")
	var keep_save: Dictionary = Store.save.duplicate(true)
	C.mute(); C.store_key = "account_check"; C.base = url; C.rounds = K.ROUNDS; C._forget()
	var progress := func(money: int, cleared: Array) -> void:
		Store.save = Store.save0(); Store.save.money = money; Store.save.cleared = cleared.duplicate(); Store.fix_save(); Store.persist()
	var code_re := RegEx.new(); code_re.compile("^([2-9A-HJ-NP-Z]{4}-){3}[2-9A-HJ-NP-Z]{4}$")
	# another device of the same account, at the level of the requests: signs in for itself and writes a save
	var other := func(pw: String, money: int) -> int:
		var li: Dictionary = await C._call("POST", "/login", {"id": "e2e_kid", "key": K.key_of("e2e_kid", pw)})
		var d: Dictionary = Store.save0(); d.money = money; d.cleared = [1, 2]
		var pu: Dictionary = await C._call("PUT", "/save", {"data": d, "base": int(li.json.save.rev)}, str(li.json.token))
		return int(pu.json.get("rev", -1))

	progress.call(5000, [1])
	var t0 := Time.get_ticks_msec(); var up: Dictionary = await C.sign_up("E2E_Kid", "real pass 1"); var t_up := Time.get_ticks_msec() - t0
	check("signing up with the real server: a recovery code of its kind, this device's progress up as rev 1",
		up.ok and code_re.search(str(up.get("recovery", ""))) != null and C.signed_in() and C.id == "e2e_kid" and C.rev == 1 and not C.dirty and C.at > 1700000000, [up.ok, C.id, C.rev, "%d ms" % t_up])
	Store.save.money = 7000; Store.save.cleared = [1, 6]; Store.persist()
	var went: bool = await _until(func() -> bool: return not C.dirty and C.rev == 2)
	check("a save on the device goes up by itself (after its moment's wait)", went and not C.offline, [C.rev, C.dirty, C.offline])
	await C.sign_out(); progress.call(0, [])
	var in1: Dictionary = await C.sign_in("e2e_kid", "real pass 1")
	check("signing in on a device with no progress: the account's comes down as it went up", in1.ok and int(Store.save.money) == 7000 and Store.save.cleared == [1, 6] and C.rev == 2 and not C.asking(), [in1, Store.save.money, Store.save.cleared, C.rev])
	var bad: Dictionary = await C.sign_in("e2e_kid", "real pass 1")   # (already signed in: the game's screens do not offer it; the server answers all the same)
	await C.sign_out()
	var wrong: Dictionary = await C.sign_in("e2e_kid", "not the pass"); var taken: Dictionary = await C.sign_up("e2e_kid", "another pass 2")
	check("a wrong password and a taken id are refused by the server, in the game's words", bad.ok and not wrong.ok and str(wrong.error).contains("맞지 않습니다") and not taken.ok and str(taken.error).contains("이미 있는") and not C.signed_in(), [wrong, taken])
	await C.sign_in("e2e_kid", "real pass 1")
	var their_rev: int = await other.call("real pass 1", 900)
	await C.refresh()
	check("another device has saved: looked at, its newer progress comes down here", their_rev == 3 and int(Store.save.money) == 900 and Store.save.cleared == [1, 2] and C.rev == 3 and not C.asking(), [their_rev, Store.save.money, C.rev])
	their_rev = await other.call("real pass 1", 1200)
	Store.save.money = 950; Store.persist()
	var asked: bool = await _until(func() -> bool: return C.asking())
	check("both have saved since: the server refuses this device's save, and the player is asked", asked and their_rev == 4 and int(C.ask.data.money) == 1200 and int(Store.save.money) == 950, [asked, their_rev])
	await C.choose("device")
	var gs: Dictionary = await C._call("GET", "/save", null, C.token)
	check("the answer 'this device's' goes over the account's, as rev 5", not C.asking() and C.rev == 5 and not C.dirty and int(gs.json.save.rev) == 5 and int(gs.json.save.data.money) == 950, [C.rev, gs.status])
	var old_token: String = C.token
	var rc_bad: Dictionary = await C.recover("e2e_kid", "ZZZZ-ZZZZ-ZZZZ-ZZZZ", "brand new pass"); var rc: Dictionary = await C.recover("e2e_kid", str(up.recovery).to_lower(), "brand new pass")
	var old_tok: Dictionary = await C._call("GET", "/save", null, old_token); var old_pw: Dictionary = await C._call("POST", "/login", {"id": "e2e_kid", "key": K.key_of("e2e_kid", "real pass 1")})
	check("the recovery code sets a new password: a new code, the old sign-in and the old password dead, the progress as it was",
		not rc_bad.ok and str(rc_bad.error).contains("복구 코드") and rc.ok and code_re.search(str(rc.recovery)) != null and rc.recovery != up.recovery and int(old_tok.status) == 401 and int(old_pw.status) == 401 and C.signed_in() and C.rev == 5 and not C.asking(),
		[rc_bad, rc.ok, old_tok.status, old_pw.status, C.rev])
	var del_bad: Dictionary = await C.delete_account("real pass 1"); var del: Dictionary = await C.delete_account("brand new pass")
	var after: Dictionary = await C.sign_in("e2e_kid", "brand new pass")
	check("deleting the account with the password: gone from the server, the device's own progress kept", not del_bad.ok and del.ok and not after.ok and not C.signed_in() and int(Store.save.money) == 950, [del_bad, del, after])
	C.base = "http://127.0.0.1:9"   # (nothing listens there)
	var t1 := Time.get_ticks_msec(); var none: Dictionary = await C.sign_in("e2e_kid", "brand new pass"); var t_none := Time.get_ticks_msec() - t1
	check("no server to reach: the game says so (and soon), and nobody is signed in", not none.ok and str(none.error).contains("서버에 연결하지 못했습니다") and not C.signed_in() and t_none < 15000, [none, "%d ms" % t_none])
	C._forget()
	for f in ["account_check", "account_check_before"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s.json" % f))
	C.store_key = "account"; C.mute()
	Store.save = keep_save; Store.fix_save(); Store.persist()
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)
