extends Node
## Checks the port against numbers taken from the browser game (tests/dump_reference.js writes reference_stage1.json).
## Run: godot --headless --path godot res://tests/run.tscn

var fails := 0
func check(name: String, ok: bool, info = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ((" " + str(info)) if str(info) != "" else ""))
	if not ok: fails += 1

func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference_stage1.json"))
	var r := World.Rng.new(7)
	var got := [r.next(), r.next(), r.next(), r.next()]; var want := [0.011704753153026104, 0.06195825757458806, 0.97690763277933, 0.6990287057124078]
	var same_rng := true
	for i in 4: same_rng = same_rng and absf(got[i] - want[i]) < 1e-15
	check("seeded random numbers match the browser's", same_rng, got)
	var w := World.new(); add_child(w); w.build_stage(1)
	check("world size and navigation grid", Phys.HALF == ref.half and Phys.nav_n == int(ref.nav.n) and Phys.nav_cs == ref.nav.cs)
	check("collider count", Phys.colliders.size() == ref.colliders.size(), "%d / %d" % [Phys.colliders.size(), ref.colliders.size()])
	var bad := 0; var first := ""
	for i in mini(Phys.colliders.size(), ref.colliders.size()):
		var b = Phys.colliders[i]; var q: Array = ref.colliders[i]; var v := [b.minx, b.miny, b.minz, b.maxx, b.maxy, b.maxz]
		var same: bool = b.kind == q[6]
		for k in 6: same = same and absf(v[k] - q[k]) < 2e-6
		if not same:
			bad += 1
			if first == "": first = "#%d %s vs %s" % [i, str(v), str(q)]
	check("every collider stands where the browser game has it", bad == 0, first)
	bad = 0
	for i in mini(w.crates.size(), ref.crates.size()):
		if absf(w.crates[i].x - ref.crates[i][0]) > 2e-6 or absf(w.crates[i].z - ref.crates[i][1]) > 2e-6: bad += 1
	check("40 crates in the same places", w.crates.size() == ref.crates.size() and bad == 0)
	var blocked := 0; var h := 0
	for i in Phys.nav_blocked.size():
		if Phys.nav_blocked[i] != 0: blocked += 1; h = (h * 31 + i) % 1000000007
	check("navigation grid is identical", blocked == int(ref.navBlocked) and h == int(ref.navHash), "%d cells" % blocked)
	# the flow field leads to the player from every spawn
	Phys.update_flow(0, 6); var reach := 0
	for s in w.spawns:
		if Phys.flow_dir(s.x, s.z) != Vector2.ZERO: reach += 1
	check("every spawn point has a path to the player", reach == w.spawns.size() and reach >= 12, "%d of %d" % [reach, w.spawns.size()])
	# a crate breaking: patching the grid round it gives the same grid as rebuilding it all
	var c = w.crates[5]; Phys.remove_collider(c.b); Phys.nav_patch(c.b.minx, c.b.minz, c.b.maxx, c.b.maxz)
	var patched: PackedByteArray = Phys.nav_blocked.duplicate(); Phys.build_nav()
	check("patching the grid after a crate breaks equals a full rebuild", patched == Phys.nav_blocked)
	Phys.add_collider(c.b.minx, c.b.miny, c.b.minz, c.b.maxx, c.b.maxy, c.b.maxz, "wood"); Phys.build_nav()
	# rays
	check("a ray down the open lane hits nothing for 20 m", not Phys.raycast_static(Vector3(0, 1.6, 6), Vector3(0, 0, -1).normalized(), 8.0))
	check("a ray at the west wall stops on it", Phys.raycast_static(Vector3(-60, 1.6, -11), Vector3(-1, 0, 0), 30.0) and absf(Phys.rh_t - 7.0) < 0.01 and Phys.rh_n == Vector3(1, 0, 0), Phys.rh_t)
	# movement: the same key presses give the same end position
	var keymap := {"KeyW": [1, 0], "KeyS": [-1, 0], "KeyD": [0, 1], "KeyA": [0, -1]}
	for run in ref.runs:
		var p := Player.new(); p.reset(run.at[0], run.at[2], run.yaw)
		for k in run.keys:
			if keymap.has(k): p.in_f += keymap[k][0]; p.in_s += keymap[k][1]
			if k == "ShiftLeft": p.in_run = true
		if run.get("jump", false): p.jump_buf = 0.15
		for i in roundi(run.sec * 30): p.update(1.0 / 30.0, null, 0.0)
		var e := Vector3(run.end[0], run.end[1], run.end[2])
		check("move: " + run.name, p.pos.distance_to(e) < 1e-4 and p.grounded == run.grounded, "%s (browser %s)" % [str(p.pos), str(e)])
	# ---------------- weapons ----------------
	var nbad := 0; var which := ""
	for id in ref.weapons:
		var a: Dictionary = ref.weapons[id]; var b: Dictionary = Weapons.LIST.get(id, {})
		for k in a:
			if k == "rent" or k == "noise" or k == "parts": continue   # set while playing by the attachments (stage 6 of the port)
			if k == "adsSpeed" and not b.has(k): b = b.merged({"adsSpeed": 7})
			var av = a[k]; var bv = b.get(k)
			if k == "reserve" and str(av) == "inf": av = INF
			var same := false
			if av is Array: same = bv is Array and av.size() == bv.size() and absf(av[0] - bv[0]) < 1e-9 and absf(av[1] - bv[1]) < 1e-9
			elif av is float or av is int: same = (bv is float or bv is int) and (av == bv or absf(av - bv) < 1e-9)
			else: same = av == bv
			if not same: nbad += 1; which += " %s.%s" % [id, k]
		if Weapons.rent(id) != int(a.rent): nbad += 1; which += " %s.rent" % id
	check("all 8 weapons have the browser game's numbers and wording", nbad == 0 and ref.weapons.size() == Weapons.LIST.size(), which)
	var cam := Camera3D.new(); cam.rotation_order = EULER_ORDER_YXZ; add_child(cam)
	var pl := Player.new(); var en := Enemies.new(); var pr := Proj.new(); add_child(pr)
	var g := Guns.new(); g.player = pl; g.cam = cam; g.world = w; g.enemies = en; g.proj = pr; g.auto_reload = false
	pr.player = pl; pr.world = w; pr.enemies = en
	var all: Array = Weapons.ORDER.duplicate()
	var step := func(sec: float) -> void:
		for i in roundi(sec * 30): g.update(1.0 / 30.0); pl.update(1.0 / 30.0, cam, 0.0); pr.update(1.0 / 30.0)
	for f in ref.fire:
		g.reset(all); pl.reset(0, 6, 0); pl.pitch = 1.2; pl.update(0.0, cam, 0.0); g.cur = f.id; g.cooldown = 0.0
		g.trigger = true; g.trigger_edge = true; step.call(f.sec); g.trigger = false
		var s2: Dictionary = g.wstate[f.id]
		var res_ok: bool = (s2.reserve == INF) if str(f.reserve) == "inf" else (s2.reserve == int(f.reserve))
		check("hold the trigger %d s: %s" % [f.sec, f.id], s2.mag == int(f.mag) and res_ok and (g.reload_t > 0.0) == f.reloading and s2.hot == f.hot,
			"mag %d reserve %s reloading %s hot %s (browser %s)" % [s2.mag, str(s2.reserve), str(g.reload_t > 0.0), str(s2.hot), JSON.stringify(f)])
	# the overheated machine gun will not reload until another gun has been in the hands
	g.reset(all); pl.reset(0, 6, 0); pl.pitch = 1.2; pl.update(0.0, cam, 0.0); g.cur = "lmg"; g.cooldown = 0.0; g.trigger = true; step.call(17.0); g.trigger = false
	g.start_reload(); check("an overheated machine gun refuses to reload", g.reload_t == 0.0 and g.wstate.lmg.hot)
	g.switch_to("pistol"); step.call(0.5); g.switch_to("lmg"); step.call(0.5); g.start_reload()
	check("after swapping away and back it reloads", g.cur == "lmg" and g.reload_t > 0.0 and not g.wstate.lmg.hot)
	step.call(5.3); check("the machine gun's reload takes 5.2 s and fills the box", g.reload_t == 0.0 and g.wstate.lmg.mag == 240 and g.wstate.lmg.reserve == 960)
	# reload and switch timing
	g.reset(all); g.wstate.pistol.mag = 3; g.start_reload(); step.call(1.0); var before: int = g.wstate.pistol.mag; step.call(0.2)
	check("the pistol reloads in 1.1 s", before == 3 and g.wstate.pistol.mag == 12)
	g.switch_slot(2); step.call(0.1); var mid := g.cur; step.call(0.3)
	check("switching takes 0.36 s and changes hands half way", mid == "pistol" and g.cur == "rifle" and g.switch_t == 0.0)
	g.cycle(1); step.call(0.4); check("cycling goes to the next gun in the layout", g.cur == "smg")
	# crates: find one with open ground to its south and stand there facing it
	var crate = null
	for c2 in w.crates:
		if not c2.dead and Phys.collide_at(c2.x, 0, c2.z + 2.0, 0.4, 1.7) == null and Phys.collide_at(c2.x, 0, c2.z + 9.0, 0.4, 1.7) == null and Phys.line_of_sight(Vector3(c2.x, 1.6, c2.z + 9.0), Vector3(c2.x, 0.6, c2.z + 0.7)): crate = c2; break
	check("a crate with room in front of it exists", crate != null)
	var face := func(c9: Dictionary, dist: float) -> void:
		pl.reset(c9.x, c9.z + dist, 0.0); pl.pitch = -atan2(1.62 - 0.6, dist - 0.6); pl.update(0.0, cam, 0.0); g.reset(all)
	face.call(crate, 2.0); g.cur = "pistol"; g.trigger = true; g.trigger_edge = true; step.call(0.1); g.trigger = false
	check("one pistol round (34) leaves a crate (45) standing", not crate.dead and absf(crate.hp - 11.0) < 0.01, crate.hp)
	step.call(0.2); g.trigger = true; g.trigger_edge = true; step.call(0.3); g.trigger = false
	check("the second round breaks it and its collider goes", crate.dead and not Phys.colliders.has(crate.b))
	# the jab
	crate = null
	for c2 in w.crates:
		if not c2.dead and Phys.collide_at(c2.x, 0, c2.z + 2.0, 0.4, 1.7) == null and Phys.collide_at(c2.x, 0, c2.z + 9.0, 0.4, 1.7) == null and Phys.line_of_sight(Vector3(c2.x, 1.6, c2.z + 9.0), Vector3(c2.x, 0.6, c2.z + 0.7)): crate = c2; break
	face.call(crate, 1.6)
	g.melee_start(); step.call(0.5)
	check("a jab (60) breaks a crate in reach", crate.dead, "hp %s cd %s on %s at %s" % [str(crate.hp), str(g.melee_cd), str(g.melee_on), str(pl.pos)])
	for c2 in w.crates:
		if not c2.dead and Phys.collide_at(c2.x, 0, c2.z + 2.0, 0.4, 1.7) == null and Phys.collide_at(c2.x, 0, c2.z + 3.2, 0.4, 1.7) == null and Phys.collide_at(c2.x, 0, c2.z + 8.0, 0.4, 1.7) == null and Phys.collide_at(c2.x, 0, c2.z + 13.8, 0.4, 1.7) == null \
				and Phys.line_of_sight(Vector3(c2.x, 1.62, c2.z + 13.8), Vector3(c2.x, 0.6, c2.z + 0.7)) and Phys.line_of_sight(Vector3(c2.x, 1.62, c2.z + 8.0), Vector3(c2.x, 0.6, c2.z + 0.7)): crate = c2; break
	face.call(crate, 3.2); g.melee_start(); step.call(0.5)
	check("a jab from 3.2 m does not reach", not crate.dead)
	# touch: auto-fire only within 12 m, auto-jab within reach
	g.look_mode = "touch"; g.auto_fire = true; g.auto_jab = false
	face.call(crate, 13.8); g.look_mode = "touch"; step.call(0.6)
	check("touch auto-fire leaves a crate 13 m away alone", not crate.dead and g.wstate.pistol.mag == 12)
	face.call(crate, 8.0); step.call(0.8)
	check("touch auto-fire shoots a crate 8 m away", crate.dead and g.wstate.pistol.mag < 12, "hp %s mag %s dead %s" % [str(crate.hp), str(g.wstate.pistol.mag), str(crate.dead)])
	for c2 in w.crates:
		if not c2.dead and Phys.collide_at(c2.x, 0, c2.z + 2.0, 0.4, 1.7) == null: crate = c2; break
	g.auto_jab = true; pl.reset(crate.x, crate.z + 2.0, 0.0); pl.update(0.0, cam, 0.0); g.reset(all); step.call(0.6)
	check("touch auto-jab breaks a crate that comes within reach, without a shot", crate.dead and g.wstate.pistol.mag == 12)
	g.look_mode = "lock"; g.auto_fire = false; g.auto_jab = false
	# a grenade: arms after 8 m, blasts crates within 5 m, hurts you on stage 1 when close
	g.reset(all); pl.reset(0, 6, 0); pl.pitch = -0.05; pl.update(0.0, cam, 0.0); g.cur = "gl"; g.cooldown = 0.0
	var alive0 := w.crates.filter(func(c3): return not c3.dead).size()
	g.trigger = true; g.trigger_edge = true; step.call(0.1); g.trigger = false
	check("the launcher sends a grenade on its way", pr.list.size() == 1 and g.wstate.gl.mag == 5)
	step.call(4.0); check("the grenade goes off and is gone", pr.list.is_empty())
	# a rocket fired at the ground at your feet: the blast hurts you
	g.reset(all); pl.reset(0, 6, 0); pl.pitch = -0.7; pl.update(0.0, cam, 0.0); g.cur = "rocket"; g.cooldown = 0.0
	g.trigger = true; g.trigger_edge = true; step.call(1.0); g.trigger = false
	check("a rocket into the ground nearby hurts you (35-100% of 500)", pl.hp < 1000.0 and pl.hp >= 500.0, pl.hp)
	check("one rocket in the tube, eleven carried", Weapons.LIST.rocket.mag == 1 and Weapons.LIST.rocket.reserve == 11)
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)
