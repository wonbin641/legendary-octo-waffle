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
	var pl := Player.new(); var en := Enemies.new(); add_child(en); var pr := Proj.new(); add_child(pr); en.player = pl; en.proj = pr; en.cam = cam
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
	# ---------------- a run of stage 1 ----------------
	Store.save = Store.save0(); Store.settings.dev = false; Store.settings.god = false; Store.money_lock = null; Store.own_lock = null; Store.ivory_lock = null
	var fxn := Fx.new(); add_child(fxn); var lt := Loot.new(); add_child(lt); lt.player = pl
	var gm := Game.new(); gm.world = w; gm.player = pl; gm.enemies = en; gm.guns = g; gm.proj = pr; gm.loot = lt; gm.fx = fxn
	en.on_kill = gm.on_kill; w.on_crate = gm.on_crate; lt.take = gm.take_loot; lt.open_chest = gm.open_chest; g.auto_reload = true
	var shown := []; gm.on_result = func(kind: String) -> void: shown.push_back(kind)
	gm.begin(1)
	check("stage 1 holds 100 enemies, one of them the boss", en.list.size() == 100 and int(ref.goal) == gm.goal and gm.boss != null and gm.boss.max_hp == 1600.0 and gm.boss.dmg_mul == 1.6)
	bad = 0; first = ""
	for i in mini(en.list.size(), ref.enemies.size()):
		var e2 = en.list[i]; var q: Array = ref.enemies[i]
		if absf(e2.pos.x - q[0]) > 1e-4 or absf(e2.pos.z - q[1]) > 1e-4 or (1 if e2.boss else 0) != int(q[2]) or e2.max_hp != q[3] or absf(e2.scale - q[4]) > 1e-6:
			bad += 1
			if first == "": first = "#%d %s vs %s" % [i, str(e2.pos), str(q)]
	check("every enemy stands where the browser game puts it", bad == 0, first)
	var near = en.list[5]; pl.reset(near.pos.x + 9.0, near.pos.z, 0.0); pl.update(0.0, cam, 0.0); en.noise(pl.pos, 30.0)
	var sim := func(sec: float) -> void:
		for i in roundi(sec * 30): g.update(1.0 / 30.0); pl.update(1.0 / 30.0, cam, 0.0); en.update(1.0 / 30.0, 0.0); pr.update(1.0 / 30.0); lt.update(1.0 / 30.0); gm.update(1.0 / 30.0)
	pl.invuln = 0.0; pl.hp = 100000.0   # (plenty of health, to watch the whole fight)
	var tr := []
	for q9 in 5: sim.call(2.0); tr.push_back(maxi(1, int(pl.hp - 99000.0)))
	# the browser game, same spot, three runs: [1000,703,514,289,91], [964,694,433,190,1], [1000,730,379,172,0]
	check("standing still near a group: they close in and shoot you down as fast as in the browser game", tr[1] < 900 and tr[1] > 500 and tr[2] < 650 and tr[2] > 250 and tr[4] < 200, str(tr))
	Store.save = Store.save0(); Store.money_lock = null; Store.own_lock = null; Store.ivory_lock = null; gm.begin(1)
	var fb = gm.boss; var ft = en.list[1] if en.list[0].boss else en.list[0]
	check("a person's and the boss's footprints match the browser game", absf(ft.foot.x1 - ref.foot.thug.x1) < 1e-6 and absf(ft.foot.z0 - ref.foot.thug.z0) < 1e-6 and absf(ft.foot.z1 - ref.foot.thug.z1) < 1e-6 and absf(ft.foot_r - ref.foot.thug.R) < 1e-6 \
		and absf(fb.foot.x1 - ref.foot.boss.x1) < 1e-6 and absf(fb.foot.z1 - ref.foot.boss.z1) < 1e-6 and absf(fb.foot_r - ref.foot.boss.R) < 1e-6 and absf(fb.mass - ref.foot.boss.mass) < 1e-9)
	check("the pistol is all you carry on a new save", g.slots == ["pistol"])
	# hits: body 34, head 85; three body shots or two head shots kill a man (100)
	var t0 = ft; var hd: Vector3 = en.part_centre(t0, t0.parts[0]); var bd: Vector3 = en.part_centre(t0, t0.parts[1])
	var rh = en.raycast(hd + Vector3(0, 0, 5), Vector3(0, 0, -1), 20.0); var rb = en.raycast(bd + Vector3(0, 0, 5), Vector3(0, 0, -1), 20.0)
	check("a ray at the head finds the head, a ray at the chest the body", rh != null and rh.enemy == t0 and rh.weak and rb != null and rb.enemy == t0 and not rb.weak and rb.mult == 1.0)
	var money0: int = Store.save.money
	en.damage(t0, 34, bd, Vector3(0, 0, -1), false); en.damage(t0, 34, bd, Vector3(0, 0, -1), false)
	check("two body shots leave him standing, and he is awake now", t0.alive and t0.hp == 32.0 and t0.alert)
	check("the third kills him and pays 1,000", en.damage(t0, 34, bd, Vector3(0, 0, -1), false) and not t0.alive and Store.save.money == money0 + 1000 and gm.kills == 1)
	var t1 = en.list[2]
	en.damage(t1, 85, hd, Vector3(0, 0, -1), true); en.damage(t1, 85, hd, Vector3(0, 0, -1), true)
	check("a kill by a shot to the head pays 1,500", not t1.alive and Store.save.money == money0 + 2500 and gm.stats.heads == 1)
	# they come for you and shoot: stand still near a group and lose health
	near = en.list[5]; pl.reset(near.pos.x + 9.0, near.pos.z, 0.0); pl.update(0.0, cam, 0.0); en.noise(pl.pos, 30.0)
	pl.invuln = 0.0; sim.call(3.0)
	var closest := 999.0
	for e3 in en.list: closest = minf(closest, Vector2(e3.pos.x - pl.pos.x, e3.pos.z - pl.pos.z).length())
	check("nobody stands inside you", closest > 0.5, closest)
	# dying loses what was earned in there
	pl.hp = 1.0; pl.invuln = 0.0; pl.hurt(50, Vector3.ZERO); sim.call(1.2)
	check("falling ends the run and forfeits the money earned in it", gm.ended and shown == ["dead"] and Store.save.money == money0 and not Store.save.cleared.has(1), "%s money %d" % [str(shown), Store.save.money])
	# clear it: kill everyone, the boss last; the chest must be opened before the helicopter comes
	shown.clear(); gm.begin(1); pl.invuln = 1e9
	var bossy = gm.boss
	for e4 in en.list.duplicate():
		if e4 != bossy: en.damage(e4, 1000, e4.pos, Vector3(0, 0, -1), false)
	check("99 down: 99,000 in the bag, the boss still to go", gm.kills == 99 and Store.save.money == 99000 and not gm.ended)
	var bp: Vector3 = bossy.pos
	en.damage(bossy, 5000, bossy.pos, Vector3(0, 0, -1), false)
	check("the boss pays 20,000 and leaves a chest; the stage waits for it", Store.save.money == 119000 and lt.chests.size() == 1 and not gm.ended)
	pl.pos = Vector3(bp.x, 0, bp.z + 1.0); sim.call(0.2)
	check("opening the chest gives a gun for good and ends the stage", Store.save.owned.size() == 1 and gm.ended and gm.result == "clear")
	sim.call(2.0)
	check("cleared: recorded, best time kept, money and gun stay, 2 and 1-1 open", shown == ["clear"] and Store.save.cleared == [1] and Store.save.best.has("t1") and Store.save.money == 119000 and Store.save.owned.size() == 1 \
		and Store.stage_open(2) and Store.stage_open(6) and not Store.stage_open(3) and gm.opened == [2, 6], str(gm.opened))
	gm.begin(1); en.damage(en.list[3], 1000, en.list[3].pos, Vector3(0, 0, -1), false)
	check("a stage played again pays nothing", gm.replay and Store.save.money == 119000)
	check("money reads with thousands separators", Store.won(119000) == "119,000원" and Store.fmt_time(252) == "4:12")
	# ---------------- save codes ----------------
	nbad = 0; which = ""
	for cd in ref.codes:
		var sv: Dictionary = cd.save
		for i in 7:
			if sv.loadout[i] == null: sv.loadout[i] = null
		var code := SaveCode.encode_v8(sv)
		if code != cd.code: nbad += 1; which += " wrote %s for %s" % [code, cd.code]
		var back = SaveCode.decode(cd.code)
		if back == null or int(back.money) != int(sv.money) or back.loadout != sv.loadout or back.owned.size() != sv.owned.size() or back.cleared.size() != sv.cleared.size() or int(back.items.vest) != int(sv.items.vest) or int(back.items.ivory) != int(sv.items.ivory) \
			or int(back.best.get("t1", 0)) != int(sv.best.get("t1", 0)) or int(back.best.get("t8", 0)) != int(sv.best.get("t8", 0)): nbad += 1; which += " read %s wrongly: %s" % [cd.code, str(back)]
	check("save codes: writes what the browser game writes, and reads its codes back", nbad == 0 and ref.codes.size() == 3, which)
	check("a mistyped code is refused; O, I, L and spaces are forgiven", SaveCode.decode("20000-000R7-W1DC0-00000-00000-00000-00333-E000Y-M") == null and SaveCode.decode("2oooo ooor7 w1dco ooooo ooooo ooooo oo333 eoooy n") != null and SaveCode.decode("hello") == null)
	# the Godot version's own code also carries each gun's customisation
	Store.save = Store.save0(); Store.save.money = 54321; Store.save.cleared = [1]; Store.save.owned = ["rifle"]; Store.save.loadout = ["pistol", "rifle", null, null, null, null, null]
	Custom.set_part("rifle", "sight", "holo"); Custom.set_part("rifle", "muzzle", "sup"); Custom.set_part("rifle", "under", "vgrip"); Custom.set_part("rifle", "paint", "gold"); Custom.set_part("pistol", "under", "vgrip"); Custom.set_part("smg", "paint", "pink")
	var code9 := SaveCode.encode(Store.save); var back9 = SaveCode.decode(code9)
	check("the save code carries gun customisation (57 letters)", code9.replace("-", "").length() == 57 and back9 != null and back9.custom.rifle == {"sight": "holo", "muzzle": "sup", "under": "vgrip", "paint": "gold"} and back9.custom.smg.paint == "pink" and int(back9.money) == 54321 and back9.owned == ["rifle"], code9)
	check("a part that does not fit a gun is not kept (a pistol takes only a laser underneath)", Custom.setup("pistol").under == "none" and not back9.custom.has("pistol") and Custom.setup("rocket").sight == "iron")
	var wr := Custom.weapon("rifle"); var w0: Dictionary = Weapons.LIST.rifle
	check("parts change the gun's numbers as the browser game's do", absf(wr.dmg - 42 * 0.92) < 1e-9 and absf(wr.adsSpread - 0.0008 * 0.7) < 1e-12 and absf(wr.adsSpeed - 6 * 1.1) < 1e-9 and absf(wr.recoil - 0.021 * 0.8) < 1e-12 and absf(wr.bloom - 0.0045 * 0.75) < 1e-12 and wr.noise == 0.4 and w0.dmg == 42 and Custom.weapon("shotgun") == Weapons.LIST.shotgun)
	Custom.reset("rifle"); check("resetting a gun puts it back as it was", Custom.weapon("rifle") == Weapons.LIST.rifle)
	check("the developer password is checked by its hash only", SaveCode.dev_hash("1234") != SaveCode.DEV_HASH and SaveCode.dev_hash("") != SaveCode.DEV_HASH)
	# ---------------- the recommended kit, the shop, the layout ----------------
	Store.save = Store.save0(); Store.settings.dev = false; Store.money_lock = null; Store.own_lock = null; Store.ivory_lock = null
	check("stage 1 wants the pistol: a new save fits", Meta.fits(1) and Meta.missing(1).is_empty())
	check("stage 2 (and 1-1) want the launcher and one of rifle, SMG, machine gun", not Meta.fits(2) and Meta.missing(2) == ["gl", "rifle", "smg", "lmg"] and Meta.missing(6) == Meta.missing(2))
	check("1-2: everything but the jetpack, rocket launcher, shotgun and pistol", Meta.spec(5).all == ["rifle", "smg", "sniper", "gl", "lmg", "helmet", "vest"])
	check("3: everything but the jetpack, shotgun and pistol", Meta.spec(3).all == ["rifle", "smg", "sniper", "gl", "lmg", "rocket", "helmet", "vest"] and Meta.spec(4).all == Meta.spec(3).all)
	check("3-1 and 3-2: everything but the pistol", Meta.spec(7).all == ["shotgun", "rifle", "smg", "sniper", "gl", "lmg", "rocket", "helmet", "vest", "jet"] and Meta.spec(8).all == Meta.spec(7).all)
	check("renting needs the money", Meta.rent("gl", false).ends_with("더 필요합니다") and Store.save.rented.is_empty())
	Store.save.money = 100000
	var line := Meta.rent("gl", false)
	check("renting the launcher costs 21,000 and it goes into slot 2", Store.save.money == 79000 and Store.save.rented == ["gl"] and Store.save.loadout[1] == "gl" and line.contains("2번 칸"), line)
	check("the launcher alone is not enough for stage 2", not Meta.fits(2) and Meta.missing(2) == ["rifle", "smg", "lmg"])
	Meta.rent("smg", false)
	check("with an SMG too, stage 2 fits", Meta.fits(2) and Meta.fits(6) and Store.save.money == 79000 - 8400)
	Meta.set_slot(2, null)
	check("a gun taken out of the layout no longer counts", not Meta.fits(2))
	Meta.set_slot(5, "smg"); Meta.set_slot(0, "smg")
	check("a gun sits in one slot only", Store.save.loadout[0] == "smg" and Store.save.loadout[5] == null and Meta.fits(2))
	line = Meta.cancel_rent("smg")
	check("cancelling a rental gives the fee back", Store.save.money == 79000 and not Store.save.rented.has("smg") and not Meta.fits(2))
	Meta.buy_item("helmet"); Meta.buy_item("vest")
	check("items: a helmet (10,000) and a vest (50,000, ten blocks)", Store.save.money == 19000 and Store.save.items.helmet == 1 and Store.save.items.vest == 10 and Meta.item_state("vest") == "착용 중 · 내구 10/10" and Meta.buy_item("helmet").contains("이미"))
	Store.save.items.ivory = 3
	check("ivory sells for 50,000 a piece", Meta.sell_ivory(2).contains("+100,000원") and Store.save.money == 119000 and Store.save.items.ivory == 1)
	Store.settings.dev = true
	check("developer mode: every stage open, every gun free to carry", Store.stage_open(4) and Store.gun_available("rocket"))
	Store.settings.dev = false
	# rentals go back when a stage ends
	Store.save.loadout = ["pistol", "gl", null, null, null, null, null]; gm.begin(1)
	check("a rented gun is in your hands for the stage", g.slots == ["pistol", "gl"])
	pl.invuln = 0.0; pl.hp = 1.0; pl.hurt(50, Vector3.ZERO); sim.call(1.2)
	check("and goes back when the stage ends", Store.save.rented.is_empty() and gm.layout() == ["pistol", null, null, null, null, null, null])
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)
