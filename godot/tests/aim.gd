extends Node
## Aiming, in the whole game with a real window: each gun you can take into stage 1 (iron sights), aimed all the way, leaves the
## middle of the screen as it is without the gun (held on its sight line, as before 1.5.5, the top of most guns sat right under
## the aim), and the gun is drawn no bigger for the zoom (the world zooms, the gun in your hands does not, as the browser
## game's own camera for it). The toy guns and the optics are checked by rays in tests/run.gd. Needs a real window:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 --path godot res://tests/aim.tscn

const R := 0.05   # the middle: a disc 5 % of the screen's height across each way from the aim
var fails := 0
var main

func check(name: String, ok: bool, info = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ((" " + str(info)) if str(info) != "" else ""))
	if not ok: fails += 1

func _frames(n := 2) -> void:
	for i in n: await get_tree().process_frame
func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
## the share of the middle that differs between two pictures
func _differs(a: Image, b: Image) -> float:
	var c := Vector2(a.get_width() / 2.0, a.get_height() / 2.0); var r := a.get_height() * R; var n := 0; var hit := 0
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x, y).distance_to(c) > r: continue
			n += 1; var p := a.get_pixel(x, y); var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.06: hit += 1
	return float(hit) / maxf(1.0, n)

func _ready() -> void:
	Store.ephemeral = true   # (nothing the checks write reaches this machine's own save and settings)
	Cloud.mute()   # (whoever is signed in on this machine: the checks' saves go to no account)
	main = load("res://main.tscn").instantiate(); add_child(main)
	await _frames(3)
	if DisplayServer.get_name() == "headless": print("FAIL needs a real window: run under xvfb-run as at the top of this file"); get_tree().quit(1); return
	var keep_save: Dictionary = Store.save.duplicate(true); var keep_settings: Dictionary = Store.settings.duplicate(true)   # (put back at the end)
	Store.save = Store.save0(); Store.settings.dev = true; Store.settings.god = true   # (every gun to hand; nothing hurts you while you look)
	var ids := ["pistol", "shotgun", "rifle", "smg", "gl", "lmg", "rocket"]; Store.save.loadout = ids.duplicate()
	main.command("start 1"); await _wait(1.0); main.player.invuln = 1e9
	var covered := {}
	for id in ids:
		main.guns.switch_to(id); await _wait(0.6)
		main.guns.ads_held = true; await _wait(1.0)
		var a := get_viewport().get_texture().get_image()
		main.view.visible = false; await _frames(3)
		var b := get_viewport().get_texture().get_image(); main.view.visible = true
		covered[id] = snappedf(_differs(a, b), 0.001)
		if id == "rifle": await _lens_check()
		main.guns.ads_held = false; await _wait(0.4)
	check("aimed all the way, no gun hides what you aim at: the middle of the screen looks the same with the gun as without it, for every gun of stage 1",
		covered.values().all(func(v): return v <= 0.01), covered)
	main.to_menu(); Store.save = keep_save; Store.settings = keep_settings; Store.persist(); Store.persist_settings()
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## the rifle aimed (the world zoomed to 42 degrees): two points of it fall on the screen just where a camera at the hip's angle
## of view, with no zoom, would put them
func _lens_check() -> void:
	var cam: Camera3D = main.cam; var g: Node3D = main.gun_models.rifle
	var ref := Camera3D.new(); cam.get_parent().add_child(ref); ref.global_transform = cam.global_transform; ref.fov = main.base_fov; ref.near = cam.near; ref.far = cam.far
	var off := []
	for i: int in [0, g.get_child_count() - 1]:
		var mi: Node3D = g.get_child(i)
		var plain: Vector3 = cam.global_transform * (main.view.transform * g.transform * mi.transform).origin   # (where it is held, before the lens)
		off.push_back(snappedf(cam.unproject_position(mi.global_position).distance_to(ref.unproject_position(plain)), 0.01))
	ref.free()
	check("aimed, the world zooms but the gun in your hands is drawn as at the hip's angle of view (the rifle: %.0f degrees of view, %.0f for the gun)" % [cam.fov, main.base_fov],
		cam.fov < main.base_fov - 20.0 and off.all(func(d): return d < 0.5), off)
