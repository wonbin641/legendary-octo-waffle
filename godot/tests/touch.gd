extends Node
## A finger on the menus, as on a phone: a window the size of a 2400 x 1080 phone at 420 dpi (2.625 pixels a point), a
## finger pressed, dragged and lifted through Godot's Input (as Android sends it), on the lists the phone app scrolls (the
## weapon layout in the menu and in a stage, the shop, the codex, the settings), on a gun box, a slider and the save-code
## box, and on the fire button in a fight. It needs a real window (a phone's size cannot be had headless):
## xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --resolution 2400x1080 --path godot res://tests/touch.tscn

const K := 2.625
var fails := 0
var main

func check(name: String, ok: bool, info = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ((" " + str(info)) if str(info) != "" else ""))
	if not ok: fails += 1

func _frames(n := 2) -> void:
	for i in n: await get_tree().process_frame
func _press(p: Vector2) -> void:
	var e := InputEventScreenTouch.new(); e.position = p * K; e.pressed = true; Input.parse_input_event(e); await _frames()
func _lift(p: Vector2) -> void:
	var e := InputEventScreenTouch.new(); e.position = p * K; e.pressed = false; Input.parse_input_event(e); await _frames()
func _tap(p: Vector2) -> void:
	await _press(p); await _lift(p)
## the Esc key pressed and let go, as a keyboard sends it
func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.physical_keycode = KEY_ESCAPE; e.pressed = down; Input.parse_input_event(e); await _frames()
## a finger pressed at p, moved by `by` over ten frames and lifted there
func _drag(p: Vector2, by: Vector2) -> void:
	await _press(p)
	for i in 10:
		var m := InputEventScreenDrag.new(); m.position = (p + by * (i + 1) / 10.0) * K; m.relative = by / 10.0 * K; Input.parse_input_event(m); await _frames(1)
	await _lift(p + by)

func _list() -> ScrollContainer:
	return (main.ui.screens[main.ui.cur] as Control).find_children("*", "ScrollContainer", true, false)[0]
func _room(sc: ScrollContainer) -> int:
	return int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
func _any_open() -> bool:
	for ob in (main.ui.screens[main.ui.cur] as Control).find_children("*", "OptionButton", true, false):
		if (ob as OptionButton).get_popup().visible: return true
	return false
## the list scrolled from the top by a finger drag up from p (settling for a moment); and whether a gun box opened
func _scrolls(p: Vector2) -> Array:
	var sc := _list(); sc.scroll_vertical = 0; await _frames()
	await _drag(p, Vector2(0, -90)); await get_tree().create_timer(0.5).timeout
	var opened := _any_open()
	for ob in sc.find_children("*", "OptionButton", true, false): (ob as OptionButton).get_popup().hide()
	return [sc.scroll_vertical, opened]

func _layout_checks(where: String) -> void:
	var sc := _list(); var row: Control = sc.get_child(0).get_child(2)
	var on_box: Array = await _scrolls((row.get_child(1) as Control).get_global_rect().get_center())
	var on_num: Array = await _scrolls((row.get_child(0) as Control).get_global_rect().get_center())
	check(where + ": a finger dragged up scrolls the weapon layout, from a gun box (which stays shut) or from a slot's number",
		_room(sc) > 40 and on_box[0] > 40 and not on_box[1] and on_num[0] > 40, [_room(sc), on_box, on_num])
	sc.scroll_vertical = 0; await _frames()
	var ob: OptionButton = sc.get_child(0).get_child(1).get_child(1); var c := ob.get_global_rect().get_center()
	await _press(c); var on_press := ob.get_popup().visible; await _lift(c); var pop := ob.get_popup(); var open := pop.visible
	var was = Store.save.loadout[1]
	if open: await _tap(Vector2(pop.position.x + pop.size.x * 0.5, pop.position.y + pop.size.y * 1.5 / pop.item_count))
	check(where + ": a tap on slot 2's gun box opens it as the finger lifts (not as it lands), and a tap on its first gun puts that gun in slot 2",
		not on_press and open and was == null and Store.save.loadout[1] == "pistol", [on_press, open, was, Store.save.loadout[1]])

func _ready() -> void:
	Store.ephemeral = true   # (nothing the checks write reaches this machine's own save and settings)
	Cloud.mute()   # (whoever is signed in on this machine: the checks' saves go to no account)
	get_window().size = Vector2i(2400, 1080); get_window().content_scale_factor = K
	main = load("res://main.tscn").instantiate(); add_child(main)
	await _frames(3)
	get_window().content_scale_factor = K; Input.emulate_touch_from_mouse = true   # (the window's system has no touch screen: Godot then takes the mouse as one)
	await _frames(2)
	if main.ui.size.x < 800.0 or not DisplayServer.is_touchscreen_available():
		print("FAIL needs a phone-sized window and a touch screen: run under xvfb-run as at the top of this file ", main.ui.size); get_tree().quit(1); return
	var keep_save: Dictionary = Store.save.duplicate(true); var keep_settings: Dictionary = Store.settings.duplicate(true)   # (put back at the end)
	Store.save = Store.save0(); Store.settings.dev = false; Store.settings.god = false; Store.save.money = 100000
	var ui = main.ui; ui.is_touch = true
	# the weapon layout from the menu
	ui.open_sub("loadout"); await _frames(); await _layout_checks("the menu"); ui.close_sub(); await _frames()
	# the shop: a drag scrolls from a row's words or from a rent button, and buys nothing; a tap buys once
	ui.shop_ctx = 1; ui.open_sub("shop"); await _frames()
	var sc := _list(); var words: Vector2 = (sc.get_child(0).get_child(2) as Control).get_global_rect().position + Vector2(30, 14)
	var on_words: Array = await _scrolls(words)
	var rent: Button = null
	for b in sc.find_children("*", "Button", true, false):
		if (b as Button).text == "대여" and not (b as Button).disabled: rent = b; break
	sc.scroll_vertical = 0; await _frames(); sc.ensure_control_visible(rent); await _frames()
	var s0 := sc.scroll_vertical; var m0: int = Store.save.money
	await _drag(rent.get_global_rect().get_center(), Vector2(0, -80)); await get_tree().create_timer(0.5).timeout
	var s1 := sc.scroll_vertical; var m1: int = Store.save.money; var r1: Array = (Store.save.rented as Array).duplicate()
	check("the shop: a finger dragged up scrolls it from a row's words and from a rent button, and the drag rents nothing",
		on_words[0] > 40 and s1 - s0 > 40 and m1 == m0 and r1.is_empty(), [_room(sc), on_words[0], s0, s1, m0, m1, r1])
	for b in sc.find_children("*", "Button", true, false):
		if (b as Button).text == "대여" and not (b as Button).disabled: rent = b; break
	sc.ensure_control_visible(rent); await _frames(); var s_tap := sc.scroll_vertical; await _tap(rent.get_global_rect().get_center()); await _frames(3)
	var s_after := sc.scroll_vertical
	check("the shop: drawn again after the rent, the list stays where it was scrolled to (not sent back to the top)", s_tap > 40 and s_after == s_tap, [s_tap, s_after])
	check("the shop: a tap on a rent button rents that gun once", (Store.save.rented as Array).size() == 1 and Store.save.money == m0 - Weapons.rent(Store.save.rented[0]), [Store.save.rented, Store.save.money])
	ui.close_sub(); await _frames()
	# the codex and the settings
	ui.open_sub("codex"); await _frames(); var cr := _list().get_global_rect()
	var cx: Array = await _scrolls(Vector2(cr.get_center().x, cr.position.y + cr.size.y * 0.7)); ui.close_sub(); await _frames()
	ui.open_sub("settings"); await _frames(); var sr := _list().get_global_rect()
	var sx: Array = await _scrolls(Vector2(sr.position.x + 30, sr.position.y + sr.size.y * 0.7))
	check("the codex and the settings scroll under a finger", cx[0] > 40 and sx[0] > 40, [cx, sx])
	_list().scroll_vertical = 0; await _frames()
	var sl: HSlider = (ui.screens.settings as Control).find_children("*", "HSlider", true, false)[0]; var g := sl.get_global_rect()
	var v_to := sl.min_value + (sl.max_value - sl.min_value) * 0.8
	await _drag(Vector2(g.position.x + g.size.x * 0.3, g.get_center().y), Vector2(g.size.x * 0.5, 0))
	check("a settings slider follows a finger along it, and the list stays put", absf(sl.value - v_to) < (sl.max_value - sl.min_value) * 0.08 and _list().scroll_vertical == 0, [sl.value, v_to])
	ui.close_sub(); await _frames()
	ui.open_dialog("load"); await _frames(); ui.dlg_in.release_focus(); await _frames(); await _tap(ui.dlg_in.get_global_rect().get_center())
	check("the save-code box takes a finger's tap (and so the phone's keyboard)", ui.dlg_in.has_focus()); ui.close_sub(); await _frames()
	# the account's screens under a finger (with a stand-in server that answers nothing: no request leaves this machine)
	Cloud.store_key = "account_check"; Cloud.base = "http://check"; Cloud.transport = func(_m: String, _p: String, _b, _t: String) -> Dictionary: return {"status": 0, "json": {}}
	var named := func(t: String) -> Button:
		for b in (ui.screens[ui.cur] as Control).find_children("*", "Button", true, false):
			if (b as Button).text == t and (b as Button).is_visible_in_tree(): return b
		return null
	ui.show_screen("menu"); ui.open_sub("settings"); await _frames(); _list().scroll_vertical = 0; await _frames()
	await _tap((named.call("로그인 · 회원가입") as Button).get_global_rect().get_center())
	var ac_open: bool = ui.cur == "account" and ui.ac_mode == "in"; var ac_issues := {"in": ui.audit()}
	ui.ac_id.release_focus(); ui.ac_pw.release_focus(); await _frames()
	await _tap(ui.ac_pw.get_global_rect().get_center()); await _frames(3)
	var box_top: float = ui.ac_pw.get_global_rect().position.y - _list().get_global_rect().position.y; var box_on: bool = ui.ac_pw.has_focus()
	for ch in "ab1":
		for down in [true, false]:
			var ke := InputEventKey.new(); ke.unicode = ch.unicode_at(0); ke.keycode = ch.to_upper().unicode_at(0) as Key; ke.pressed = down; Input.parse_input_event(ke); await _frames(1)
	var typed: String = ui.ac_pw.text
	var to_up: Button = named.call("회원가입"); _list().ensure_control_visible(to_up); await _frames(); await _tap(to_up.get_global_rect().get_center())
	var up_open: bool = ui.ac_mode == "up" and ui.ac_pw2 != null; _list().scroll_vertical = 0; await _frames(); ac_issues["up"] = ui.audit()
	ui._account_mode("rc"); await _frames(); ac_issues["rc"] = ui.audit()
	ui.ac_code = "ABCD-EFGH-JKLM-NPQR"; ui.ac_mode = "code"; ui.render_account(); await _frames(); ac_issues["code"] = ui.audit()
	main._back(); await _frames(); var code_stays: bool = ui.cur == "account" and ui.ac_mode == "code"   # (the phone's back button)
	ui.ac_code = ""; Cloud.id = "finger_kid"; Cloud.token = "t"; ui.ac_mode = "me"; ui.render_account(); await _frames(); ac_issues["me"] = ui.audit()
	ui._account_mode("del"); await _frames(); ac_issues["del"] = ui.audit()
	Cloud.ask = {"data": Store.save0(), "rev": 3, "updated": 1795000000}; ui.render_account(); await _frames(); ac_issues["ask"] = ui.audit()
	main._back(); await _frames(); var ask_shut: bool = ui.cur == "settings"
	Cloud.mute(); Cloud.store_key = "account"; ui.back(); await _frames()
	check("the account's screens on the phone: the way in from the settings by a tap; in every one of them nothing off the screen, squeezed, overlapping or too small to press; a tapped box takes the finger (and so the phone's keyboard), goes to the top of the list clear of it, and takes what is typed; the recovery code is not put away by the back button, the question of which progress is",
		ac_open and ac_issues.values().all(func(a): return (a as Array).is_empty()) and box_on and box_top < 12.0 and typed == "ab1" and up_open and code_stays and ask_shut and ui.cur == "menu", [ac_open, ac_issues, box_on, box_top, typed, up_open, code_stays, ask_shut, ui.cur])
	# a fight: the finger works the touch controls, and its mouse copy neither aims, fires nor grabs the pointer
	Store.save.rented = []; Store.save.loadout = ["pistol", null, null, null, null, null, null]
	main.command("start 1"); await get_tree().create_timer(0.8).timeout
	await _tap(Vector2(450, 200)); await get_tree().create_timer(0.2).timeout
	var fire: Vector2 = main._touch_buttons().fire[0]; var sh0: int = main.guns.shots
	await _press(fire); await get_tree().create_timer(0.4).timeout; var held: bool = main.guns.trigger; await _lift(fire); await get_tree().create_timer(0.2).timeout
	check("in a fight a tap turns the touch controls on and the fire button fires while held, the mouse left free",
		main.look_mode == "touch" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and held and not main.guns.trigger and main.guns.shots - sh0 >= 1, [main.look_mode, held, main.guns.shots - sh0])
	# the phone's own option: stage 2's zombie corpse shot, on at first, off when the setting is turned off (Guns._corpse_shot)
	Store.settings.corpseShot = Store.settings0(true).corpseShot; main.apply_settings()   # (as a new player has it)
	var cs_on: bool = main.guns.corpse_shot; Store.settings.corpseShot = false; main.apply_settings(); var cs_off: bool = main.guns.corpse_shot
	Store.settings.corpseShot = true; main.apply_settings()
	check("on the phone the zombie corpse shot is on at first in a fight, and off once its setting is turned off", cs_on and not cs_off and main.guns.corpse_shot, [cs_on, cs_off])
	# a finger on the jump or the down button (flying) as the pause comes, lifted only in the pause: let go with the pause, so
	# neither stays held when the fight goes on (bug-note 14: it once flew on up, or down, by itself)
	main.player.jet_on = true; main.player.jet_t = 10.0; await _frames(); var tb: Dictionary = main._touch_buttons(); var still := []   # (flying, with fuel: the down button shows)
	for bn in ["jump", "down"]:
		var bp: Vector2 = tb[bn][0]
		await _press(bp); var on: bool = main.player.in_up if bn == "jump" else main.player.in_down
		main.pause_game(); await _frames(); await _lift(bp); main.resume_game(); await _frames()
		still.push_back([on, main.player.in_up or main.player.in_down])
	main.player.jet_end()
	check("a finger on the jump or the down button as the pause comes is let go with it: neither stays held when the fight goes on", still == [[true, false], [true, false]], still)
	# the weapon layout in the pause of a stage (where it was first seen not to scroll)
	main.pause_game(); await _frames(); ui.open_sub("loadout"); await _frames(); await _layout_checks("a stage's pause")
	# there, emptied, the layout is not shut by the phone's back button or by Esc either (as by 완료); with a gun put back, Esc shuts it
	var lo_keep: Array = (Store.save.loadout as Array).duplicate(); Store.save.loadout = [null, null, null, null, null, null, null]; ui.render_loadout(); await _frames()
	main._back(); await _frames(); var by_back: String = ui.cur
	await _esc(); var by_esc: String = ui.cur
	Store.save.loadout = lo_keep; await _esc()
	check("in a fight the emptied weapon layout stays open by the phone's back button and by Esc (as by 완료); with a gun put back, Esc shuts it",
		by_back == "loadout" and by_esc == "loadout" and ui.cur == "pause", [by_back, by_esc, ui.cur])
	main.to_menu(); Store.save = keep_save; Store.settings = keep_settings; Store.persist(); Store.persist_settings()
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails > 0 else 0)
