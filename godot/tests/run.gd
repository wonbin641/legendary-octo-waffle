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
	en.on_bite = gm.bitten; en.on_poison = gm.poison; en.on_stun = gm.stun
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
	# ---------------- stages 1-1 and 1-2 ----------------
	for stn in [6, 5, 2, 3, 7, 4]:
		var R9: Dictionary = ref.stages[str(stn)]; Store.save = Store.save0(); gm.drop_pick = null; gm.begin(stn)
		var cb := 0
		for i in mini(60, Phys.colliders.size()):
			var b9 = Phys.colliders[i]; var q9: Array = R9.first[i]
			if absf(b9.minx - q9[0]) > 2e-6 or absf(b9.minz - q9[1]) > 2e-6 or absf(b9.maxy - q9[2]) > 2e-6: cb += 1
		var nb := 0; var nh := 0
		for i in Phys.nav_blocked.size():
			if Phys.nav_blocked[i] != 0: nb += 1; nh = (nh * 31 + i) % 1000000007
		check("stage %s: the docks are laid out as in the browser game" % Store.STAGE_TAG[stn], Phys.colliders.size() == int(R9.colliders) and cb == 0 and nb == int(R9.navBlocked) and nh == int(R9.navHash) and w.crates.size() == R9.crates.size(), "%d colliders" % Phys.colliders.size())
		var eb := 0; var efirst := ""
		for i in mini(en.list.size(), R9.enemies.size()):
			var e9 = en.list[i]; var q9: Array = R9.enemies[i]
			var moved9: bool = stn == 3 and (absf(e9.pos.x - q9[0]) > 11.0 or absf(e9.pos.z - q9[1]) > 11.0)   # the lab's animals had paced about their cages by the time they were written down
			var still9: bool = stn != 3 and (stn != 4 or e9.type in ["cctv", "mine", "gdrone", "bdrone"])   # the ship's patrols and drones had moved off by the time they were written down
			if (still9 and (absf(e9.pos.x - q9[0]) > 1e-4 or absf(e9.pos.z - q9[1]) > 1e-4)) or moved9 or e9.type != q9[7] or (absf(e9.pos.y - q9[2]) > 1e-3 and (stn != 4 or e9.type == "mine")) or e9.kit != q9[3] or (1 if e9.boss else 0) != int(q9[4]) or e9.max_hp != q9[5] or (1 if e9.helmet else 0) != int(q9[6]):
				eb += 1
				if efirst == "": efirst = "#%d %s %s vs %s" % [i, str(e9.pos), e9.kit, str(q9)]
		check("stage %s: all 100 stand where the browser game puts them, with the same weapons" % Store.STAGE_TAG[stn], en.list.size() == R9.enemies.size() and eb == 0 and gm.goal == int(R9.goal), efirst)
		var cb9 := 0
		for i in mini(w.crates.size(), R9.crates.size()):
			if absf(w.crates[i].x - R9.crates[i][0]) > 1e-4 or absf(w.crates[i].z - R9.crates[i][1]) > 1e-4: cb9 += 1
		check("stage %s: every crate is where the browser game has it" % Store.STAGE_TAG[stn], cb9 == 0, cb9)
		check("stage %s: you start where the browser game starts you" % Store.STAGE_TAG[stn], absf(w.start.x - R9.start[0]) < 1e-4 and absf(w.start.z - R9.start[1]) < 1e-4 and absf(w.start.yaw - R9.start[2]) < 1e-4, w.start)
	# ---------------- stage 2: the burning village ----------------
	gm.begin(2); var s2_V2: Dictionary = ref.stages["2"]
	var s2_cbad := 0
	for i in mini(w.crates.size(), s2_V2.crates.size()):
		if absf(w.crates[i].x - s2_V2.crates[i][0]) > 1e-4 or absf(w.crates[i].z - s2_V2.crates[i][1]) > 1e-4: s2_cbad += 1
	check("stage 2: 15 huts, and every crate where the browser game has it", w.village.huts.size() == int(s2_V2.huts) and s2_cbad == 0 and w.crates.size() == 46, "%d huts %d off" % [w.village.huts.size(), s2_cbad])
	check("stage 2: zombies, one giant among them", en.list.all(func(e): return e.type == "zombie") and gm.boss != null and gm.boss.max_hp == 2200.0 and gm.boss.scale == 1.7 and en.list[1].max_hp == 180.0 and gm.antidotes == 1)
	# no health in the village
	pl.invuln = 0.0; pl.hurt(500, Vector3.ZERO)
	check("stage 2: nothing takes health away", pl.hp == Player.MAX_HP)
	# a zombie drops, and gets back up unless it is shot again
	var s2_z1 = en.list[5]; var s2_zdir := Vector3(0, 0, 1)
	var s2_zk := en.damage(s2_z1, 500, s2_z1.pos, s2_zdir, false)
	check("stage 2: a zombie out of health drops but is not dead yet", not s2_zk and s2_z1.alive and s2_z1.downed and gm.kills == 0)
	pl.pos = Vector3(s2_z1.pos.x + 60, 0, s2_z1.pos.z); pl.invuln = 1e9
	for i in 190: en.update(0.02, 0.0)
	check("stage 2: left alone for 3.7 s it is back on its feet at full health", not s2_z1.downed and s2_z1.hp == 180.0 and s2_z1.revived and s2_z1.alert)
	var s2_m0: int = Store.save.money
	en.damage(s2_z1, 500, s2_z1.pos, s2_zdir, false); en.damage(s2_z1, 1, s2_z1.pos, s2_zdir, false)
	check("stage 2: shot again on the ground it is gone, and one that had got up pays 1,000", not s2_z1.alive and gm.kills == 1 and Store.save.money == s2_m0 + 1000, Store.save.money - s2_m0)
	var s2_z2 = en.list[5]; s2_m0 = Store.save.money
	en.damage(s2_z2, 500, s2_z2.pos, s2_zdir, true); en.damage(s2_z2, 1, s2_z2.pos, s2_zdir, true)
	check("stage 2: finished before it ever rose, with a shot to the head: 1,000 x 1.5 x 1.5", Store.save.money == s2_m0 + 2250, Store.save.money - s2_m0)
	# a bite: 5 seconds; the antidote takes 0.82 s to work and the gun is busy for 1.35 s
	pl.invuln = 0.0; gm.bitten(en.list[0])
	check("stage 2: a bite starts a 5 second countdown", gm.infected and gm.infect_t == 5.0)
	gm.bitten(en.list[0])
	check("stage 2: another bite takes a second off", absf(gm.infect_t - 4.0) < 1e-6)
	gm.use_antidote()
	check("stage 2: the syringe goes in: no shooting meanwhile, and the countdown holds", gm.inject_on and gm.antidotes == 0 and g.busy > 1.3)
	for i in 45: gm.update(0.02)
	check("stage 2: cured 0.82 s into the injection", not gm.infected and gm.inject_on)
	for i in 30: gm.update(0.02)
	check("stage 2: the hands are free again after 1.35 s", not gm.inject_on and g.busy == 0.0)
	# poison from a dash: 8 seconds, and with no antidote left it is the end
	gm.poison(en.list[0])
	check("stage 2: a dash poisons for 8 seconds", gm.poison_t == 8.0)
	gm.use_antidote()
	check("stage 2: with no antidote there is nothing to inject", not gm.inject_on)
	check("stage 2: a crate gives an antidote, up to five", gm.take_loot("anti") and gm.antidotes == 1)
	gm.antidotes = 5; check("stage 2: a sixth stays on the ground", not gm.take_loot("anti"))
	gm.antidotes = 0
	for i in 410: gm.update(0.02)
	check("stage 2: the poison runs out and so do you", gm.ended and gm.result == "poison")
	gm.begin(2); pl.invuln = 0.0; gm.bitten(en.list[0])
	for i in 260: gm.update(0.02)
	check("stage 2: five seconds after a bite with no cure you are one of them", gm.ended and gm.result == "zombie")
	# an ordinary zombie dashes once at 30% health; the boss rages at half and charges
	gm.begin(2); var s2_z3 = en.list[7]; pl.invuln = 1e9; pl.pos = Vector3(s2_z3.pos.x, 0, s2_z3.pos.z + 6.0)
	s2_z3.lod = 0.0; en.damage(s2_z3, 130, s2_z3.pos, s2_zdir, false); en.update(0.02, 0.0)
	check("stage 2: at 30% health a zombie screams and dashes", s2_z3.state == "dash" and s2_z3.dash_used, s2_z3.state)
	pl.invuln = 0.0; var s2_hitp := false
	for i in 60:
		en.update(0.02, 0.0)
		if gm.poison_t > 0.0: s2_hitp = true; break
	check("stage 2: the dash reaches you and poisons", s2_hitp and s2_z3.state == "move")
	gm.begin(2); var s2_zb = gm.boss; pl.invuln = 1e9; pl.pos = Vector3(s2_zb.pos.x, 0, s2_zb.pos.z + 12.0); s2_zb.yaw = 0.0
	var s2_sp0: float = s2_zb.speed; s2_zb.lod = 0.0; en.damage(s2_zb, 1200, s2_zb.pos, s2_zdir, false); en.update(0.02, 0.0)
	check("stage 2: at half health the boss rages and is 1.9 times as fast", s2_zb.rage and absf(s2_zb.speed - s2_sp0 * 1.9) < 1e-5)
	pl.invuln = 0.0; var s2_stunned := false
	for i in 400:
		pl.pos = Vector3(s2_zb.pos.x, 0, s2_zb.pos.z + 8.0) if s2_zb.state == "move" else pl.pos
		en.update(0.02, 0.0)
		if pl.stun_t > 0.0: s2_stunned = true; break
	check("stage 2: its charge knocks you out for 2 seconds", s2_stunned and absf(pl.stun_t - 2.0) < 0.05 and pl.hp == Player.MAX_HP, pl.stun_t)
	pl.in_f = 1.0; var s2_before2 := pl.pos; pl.vel = Vector3.ZERO; pl.update(0.02, null, 0.0)
	check("stage 2: knocked out, you cannot walk", pl.pos.distance_to(s2_before2) < 0.01)
	pl.in_f = 0.0; pl.stun_t = 0.0
	# ---------------- stage 3: the lab ----------------
	gm.begin(3); var lab: Lab = w.lab; var an: Animals = en.animals; pl.invuln = 0.0
	check("stage 3: 90 animals in ten cages, the giant gorilla in the last", en.list.size() == 90 and gm.goal == 90 and gm.boss != null and gm.boss.max_hp == 5200.0 and gm.boss.scale == 3.0 and lab.cages[5].animals.size() == 3 and lab.cages[8].animals.size() == 2)
	var zb3 = lab.cages[0].animals[0]; var gb3 = lab.cages[9].animals[0]
	check("stage 3: bullets pass between the bars but stop on the boss's glass", not Phys.raycast_static(Vector3(-37.5, 1.5, 20.0), Vector3(0, 0, 1), 10.0) and Phys.raycast_static(Vector3(14.7, 1.5, -20.0), Vector3(0, 0, -1), 12.0))
	en.damage(gb3, 500, gb3.pos, Vector3(0, 0, 1), false)
	check("stage 3: nothing hurts the boss behind its glass", gb3.hp == 5200.0)
	for i in 495: lab.update(0.02)
	check("stage 3: 9.9 s in every cage is still shut", not lab.cages[0].open and lab.next_cage().n == 1)
	var col3: int = Phys.colliders.size()
	for i in 10: lab.update(0.02)
	check("stage 3: at 10 s the first cage opens: its four walls stop blocking and the zebras are let out", lab.cages[0].open and Phys.colliders.size() == col3 - 4 and not zb3.caged and zb3.release_t > 0.0 and lab.next_cage().n == 2)
	for i in 750: lab.update(0.02)
	check("stage 3: the second opens 15 s later", lab.cages[1].open and not lab.cages[2].open)
	# riding: a zebra from the floor, a giraffe only from a zebra
	for i in 60: en.update(0.02, 0.0)
	pl.pos = Vector3(zb3.pos.x, 0, zb3.pos.z + 1.5); pl.yaw = 0.0; pl.grounded = true
	var gf3 = lab.cages[5].animals[0]
	check("stage 3: a zebra can be mounted from the floor, a giraffe cannot", an.ride_find() == zb3 and not an.ride_ok(gf3) == true or gf3.caged)
	an.ride_on(zb3)
	check("stage 3: riding a zebra tames it, and that counts like a kill", an.m == zb3 and zb3.tamed and gm.calm == 1 and an.tier == 1)
	pl.in_f = 1.0; var p3: Vector3 = zb3.pos
	for i in 50: pl.update(0.02, null, 0.0)
	check("stage 3: it goes where you steer it, and you sit on its back", zb3.pos.distance_to(p3) > 2.0 and absf(pl.pos.y - (zb3.pos.y + 1.62 - 0.7)) < 1e-4, zb3.pos.distance_to(p3))
	pl.in_f = 0.0
	# a blow meant for you lands on the animal under you, and it bleeds
	var bf3 = lab.cages[1].animals[0]; bf3.caged = false; var hp3: float = zb3.hp
	an.hit(bf3, "gore")
	check("stage 3: up on a zebra the buffalo's horns hit the zebra: 25, and it bleeds", zb3.hp == hp3 - 25.0 and pl.hp == Player.MAX_HP and zb3.bleed_n == 1 and pl.stun_t == 0.0, zb3.hp)
	an.ride_off(false)
	check("stage 3: off again, standing beside it", an.m == null and pl.grounded and not zb3.ridden)
	# on foot: gored (25, out cold 3 s, a wound), bitten, tossed
	an.hit(bf3, "gore")
	check("stage 3: on foot the buffalo's charge takes 25, knocks you out for 3 s and opens a wound", pl.hp == Player.MAX_HP - 25.0 and absf(pl.stun_t - 3.0) < 1e-6 and an.bleed_n == 1 and an.bleed_t == 10.0)
	pl.stun_t = 0.0; var hp4: float = pl.hp
	for i in 100: an.bleed_update(0.02)
	check("stage 3: a wound takes 5 a second", absf((hp4 - pl.hp) - 10.0) <= 1.0, hp4 - pl.hp)
	an.bleed_add(); check("stage 3: a second wound stacks and restarts the clock", an.bleed_n == 2 and an.bleed_t == 10.0)
	gm.take_loot("hp"); check("stage 3: a potion stops the bleeding", an.bleed_n == 0 and an.bleed_t == 0.0)
	var rh3 = lab.cages[3].animals[0]; pl.pos = Vector3(0, 0, 0); pl.vel = Vector3.ZERO
	an.toss(rh3)
	check("stage 3: a rhino's horn sends you straight up at 13 m/s", pl.toss_on and pl.vel == Vector3(0, 13, 0))
	var top3 := 0.0
	for i in 200:
		pl.update(0.02, null, 0.0); top3 = maxf(top3, pl.pos.y)
		if not pl.toss_on: break
	check("stage 3: up about 4.4 m and down again: 50 and a wound", not pl.toss_on and top3 > 4.0 and top3 < 4.8 and an.bleed_n == 1, top3)
	var tg3 = lab.cages[6].animals[0]; pl.invuln = 0.0
	check("stage 3: a tiger's roar makes you run for a second", an.fear(tg3) and pl.fear_t == 1.0)
	pl.fear_t = 0.0; an.bleed_stop()
	# the male lion's roar
	var ln3 = lab.cages[7].animals[0]; ln3.caged = false; var el3 = lab.cages[8].animals[0]; el3.caged = false; el3.hp = 1000.0; el3.pos = ln3.pos + Vector3(5, 0, 0)
	an.king_roar(ln3)
	check("stage 3: the lion's roar gives the others a third of their health back and makes them faster", el3.hp == 1000.0 + 12000.0 * 0.35 and absf(el3.buff - 1.1) < 1e-6 and el3.kneel_t == 1.2)
	# money: an animal's own price, a giraffe's head takes ten times
	gm.begin(3); var m3: int = Store.save.money; var z3b = w.lab.cages[0].animals[1]; z3b.caged = false
	en.damage(z3b, 999, z3b.pos, Vector3(0, 0, 1), false)
	var r3b = w.lab.cages[3].animals[1]; r3b.caged = false; en.damage(r3b, 9999, r3b.pos, Vector3(0, 0, 1), false)
	check("stage 3: a zebra pays 1,000, a rhino 3,000", Store.save.money == m3 + 4000 and gm.kills == 2, Store.save.money - m3)
	check("stage 3: a giraffe's head takes ten times the damage", w.lab.cages[5].animals[0].head_x == 10.0)
	# the gorilla: out of its cage it punches for 500
	var kg = gm.boss; kg.caged = false; kg.release_t = 0.0; kg.fury = true; kg.angry = true; kg.alert = true; kg.lod = 0.0; pl.invuln = 0.0; pl.hp = Player.MAX_HP
	pl.pos = Vector3(kg.pos.x, 0, kg.pos.z + en.stop_dist(kg) + 1.0); kg.yaw = 0.0; kg.k = {}
	var hit3 := false
	for i in 150:
		en.update(0.02, 0.0); pl.pos = Vector3(kg.pos.x, 0, kg.pos.z + en.stop_dist(kg) + 1.0); pl.vel = Vector3.ZERO
		if pl.hp < Player.MAX_HP: hit3 = true; break
	check("stage 3: the giant gorilla's haymaker takes 500", hit3 and pl.hp == Player.MAX_HP - 500.0, pl.hp)
	kg.k.mode = "beat"; kg.k.t = 1.49; kg.k.called = false; var g3: int = gm.goal; pl.invuln = 1e9
	en.update(0.02, 0.0); en.update(0.02, 0.0)
	check("stage 3: its chest-beating calls seven gorillas down, a quarter of its health each", an.minions() == 7 and gm.goal == g3 + 7 and en.list[en.list.size() - 1].max_hp == 1300.0, an.minions())
	pl.invuln = 0.0; pl.hp = Player.MAX_HP; gm.slam(kg)
	check("stage 3: under its leap you are done for", gm.ended and gm.result == "slam")
	# ---------------- stage 3-1: the safari ----------------
	gm.begin(7); var sf: Safari = w.safari; pl.invuln = 0.0
	check("stage 3-1: 100 animals living wild, a tower of 10,000, three crates up on it", en.list.size() == 100 and en.list.all(func(e): return e.wild) and sf.hp == 10000.0 and sf.slots.size() == 16 and w.crates[0].y == 3.84, sf.slots.size())
	check("stage 3-1: the stampede is five minutes away", sf.left() == 300.0 and not sf.stampede)
	pl.pos = Vector3(0, 3.84, 0); sf.update(0.02)
	check("stage 3-1: up on the platform counts as holding the tower", sf.on and sf.holds())
	sf.t = 299.99; sf.update(0.02)
	check("stage 3-1: at five minutes every wild animal is set off", sf.stampede and en.list.all(func(e): return e.fury and e.alert))
	var bf7 = null
	for e in en.list:
		if e.type == "buffalo": bf7 = e; break
	var s7 = sf.slots[0]; bf7.pos = Vector3(s7.x + s7.nx * 3.0, 0, s7.z + s7.nz * 3.0); bf7.lod = 0.0
	for i in 400:
		en.update(0.02, 0.0)
		if sf.hp < 10000.0: break
	check("stage 3-1: with you on the tower a buffalo rams the tower: 20 a blow", sf.hp == 9980.0, sf.hp)
	var col7: int = Phys.colliders.size(); sf.hurt(9990.0, Vector3.ZERO)
	check("stage 3-1: at zero the tower comes down and you fall with it", not sf.standing and Phys.colliders.size() == col7 - 16 and pl.stun_t >= 1.0 and not sf.holds())
	# ---------------- stage 4: the spaceship ----------------
	gm.begin(4); var s4_sh: Ship = w.ship; var s4_rb: Robots = en.robots; pl.invuln = 0.0
	var bee4 = gm.mid; var boss4 = gm.boss
	check("stage 4: the boss drone (9,000) sealed in the hall, the gold bee (5,000) on the bridge", boss4 != null and boss4.max_hp == 9000.0 and boss4.sealed and bee4 != null and bee4.max_hp == 5000.0 and bee4.sealed and bee4.scale == 1.25)
	check("stage 4: both doors are shut and stop bullets", Phys.raycast_static(Vector3(-85, 1.5, -7.5), Vector3(-1, 0, 0), 20.0) and absf(Phys.rh_t - 6.5) < 0.01, Phys.rh_t)
	en.damage(bee4, 100, bee4.pos, Vector3(0, 0, 1), false)
	# the hall's door wants the key
	pl.pos = Vector3(67.0, 0, -7.5); s4_sh.update(0.02, 0.0)
	check("stage 4: without the key the hall's door stays shut", s4_sh.doors[1].mode == "shut")
	# the bridge: step up to the door and you are put inside, locked in with the bee
	pl.pos = Vector3(-91.0, 0, -7.5); s4_sh.update(0.02, 0.0)
	check("stage 4: at the bridge door you are let in and locked in with the bee, which wakes", s4_sh.doors[0].mode == "locked" and pl.pos.x < -93.0 and not bee4.sealed and bee4.alert)
	check("stage 4: the key cannot be pulled while the bee lives", not s4_sh.take_key())
	var s4_m4: int = Store.save.money; pl.invuln = 1e9
	en.damage(bee4, 1e6, bee4.pos, Vector3(0, 0, 1), false)
	check("stage 4: the bee pays ten times its price and its door opens for good", Store.save.money == s4_m4 + 15000 and s4_sh.doors[0].mode == "open" and gm.mid == null, Store.save.money - s4_m4)
	pl.pos = Vector3(Ship.KEY.x + 1.0, 0.45, Ship.KEY.z)
	check("stage 4: pulling the key out is the save point", s4_sh.take_key() and s4_sh.key and gm.sp != null and gm.sp.kills == 1 and gm.sp.key)
	# dying after it: back on the bridge with the key, the kills and the bag as they were
	var s4_k4: int = gm.kills; var s4_bag4: int = Store.save.money
	en.damage(en.list[5], 1e6, en.list[5].pos, Vector3(0, 0, 1), false); pl.invuln = 0.0; pl.hp = 1.0; pl.hurt(50, Vector3.ZERO); gm.update(0.02)
	check("stage 4: you fall after the save point", gm.ended and gm.result == "dead" and gm.sp != null)
	gm.from_save()
	check("stage 4: back at the save point: on the bridge, the key in your pocket, the bee still dead, kills and bag as they were", not gm.ended and gm.kills == s4_k4 and Store.save.money == s4_bag4 and w.ship.key and w.ship.doors[0].mode == "open"
		and absf(pl.pos.x - Ship.SAVE.x) < 1e-4 and en.list.filter(func(e): return e.type == "gdrone").is_empty() and en.list.size() == 99 and pl.hp == Player.MAX_HP, en.list.size())
	s4_sh = w.ship; boss4 = gm.boss
	# with the key the hall's door lets you in
	for i in 30: s4_sh.update(0.02, 0.0)
	pl.pos = Vector3(67.0, 0, -7.5); s4_sh.update(0.02, 0.0)
	check("stage 4: with the key the hall's door lets you in and locks; the boss and its patrols wake", s4_sh.doors[1].mode == "locked" and pl.pos.x > 69.0 and not boss4.sealed and en.list.filter(func(e): return e.sealed).is_empty())
	# the boss: three shells, a third of its health each
	pl.invuln = 1e9; boss4.lod = 0.0; en.update(0.02, 0.0)
	en.damage(boss4, 5000, boss4.pos, Vector3(0, 0, 1), false)
	check("stage 4: no blow takes the boss past a third of its health: the outer shell bursts and phase 2 begins", boss4.hp == 6000.0 and boss4.k.phase == 1 and boss4.R == 1.5 and s4_sh.break_t > 0.0, boss4.hp)
	en.damage(boss4, 500, boss4.pos, Vector3(0, 0, 1), false)
	check("stage 4: while the shell comes apart nothing gets through", boss4.hp == 6000.0)
	var s4_col4: int = Phys.colliders.size()
	for i in 100: s4_sh.update(0.02, 0.0)
	check("stage 4: 1.8 s later the hall's floor falls into the stepped pit, 9 m down", s4_sh.broken and Phys.PIT != null and Phys.PIT.y == -9.0 and Phys.colliders.size() == s4_col4 - 3 and Phys.ground_at(100.0, 1.0, -6.0, 0.3) < -0.3, Phys.ground_at(100.0, 1.0, -6.0, 0.3))
	for i in 80: en.update(0.02, 0.0)
	en.damage(boss4, 5000, boss4.pos, Vector3(0, 0, 1), false)
	check("stage 4: at a third left the second shell goes: phase 3, and the hatches are about to open", boss4.hp == 3000.0 and boss4.k.phase == 2 and boss4.R == 0.75 and s4_sh.hatch_wait > 0.0)
	for i in 140: en.update(0.02, 0.0)
	check("stage 4: the hatches open and drones start coming up", s4_sh.hatches[0].open and s4_sh.hatch_q.size() > 0)
	# the laser: touching the beam is the end
	check("stage 4: the beam's reach is measured along its whole length", absf(Robots.seg_dist(Vector3(0, 1, 0), Vector3(10, 1, 0), Vector3(5, 0, 0.4), Vector3(5, 1.7, 0.4)) - 0.4) < 1e-5)
	# a mine: buried, wakes when you come close, and goes off for 100
	gm.begin(4); pl.invuln = 0.0; pl.hp = Player.MAX_HP
	var mn4 = null
	for e in en.list:
		if e.type == "mine": mn4 = e; break
	pl.pos = Vector3(mn4.pos.x + 2.0, 0, mn4.pos.z); mn4.lod = 0.0; Phys.update_flow(pl.pos.x, pl.pos.z); var s4_went := false
	for i in 150:
		en.update(0.02, 0.0); pl.pos = Vector3(pl.pos.x, 0, pl.pos.z)
		if not mn4.alive and pl.hp < Player.MAX_HP: s4_went = true; break
	check("stage 4: a buried mine springs up, runs at you and goes off: 100, and no money for it", s4_went and pl.hp == Player.MAX_HP - 100.0 and gm.kills == 1 and gm.stats.earned == 0, "%s %s %s d=%.2f bt=%.2f kills=%d blasts=%d" % [pl.hp, mn4.bs, mn4.alive, Vector2(pl.pos.x - mn4.pos.x, pl.pos.z - mn4.pos.z).length(), mn4.bt, gm.kills, en.robots.blasts.size()])
	# rockets home on you and burst
	pl.hp = Player.MAX_HP; pl.pos = Vector3(0, 0, -7.5); s4_rb.rocket(Vector3(-10, 3, -7.5), Vector3(1, 0, 0), 100.0, 15.0)
	for i in 100:
		s4_rb.tick(0.02)
		if s4_rb.rockets.is_empty(): break
	check("stage 4: a homing rocket finds you: 100 at the centre of the blast", s4_rb.rockets.is_empty() and pl.hp <= Player.MAX_HP - 50.0, pl.hp)
	gm.sp = null
	# 1-1: the helmet takes the first shot to the head
	gm.begin(6); var hm = en.list[3]; var hd9: Vector3 = en.part_centre(hm, hm.parts[0])
	var k9 := en.damage(hm, 85, hd9, Vector3(0, 0, -1), true)
	check("1-1: the first shot to the head only knocks the helmet off", not k9 and hm.alive and hm.hp == 100.0 and not hm.helmet and en.flying.size() == 1)
	en.damage(hm, 85, hd9, Vector3(0, 0, -1), true); check("1-1: after that the head is hit as usual", hm.hp == 15.0)
	check("1-1: the boss wears one too", gm.boss.helmet and gm.boss.name == "헬멧 두목")
	# 1-2: who is there
	gm.begin(5); var count := {}
	for e9 in en.list: count[e9.kit] = int(count.get(e9.kit, 0)) + 1
	check("1-2: 5 snipers, 9 desert eagles, 10 bombers, 3 flamethrowers, 12 rifles, 20 knives, 10 + 5 lightsabers, 10 grenadiers, 15 bats, a machine-gun boss",
		count == {"sniper": 5, "deagle": 9, "bomber": 10, "flame": 3, "rifle": 12, "dagger": 20, "saber": 10, "saber2": 5, "nade": 10, "bat": 15, "lmg": 1} and gm.boss.kit == "lmg" and gm.boss.max_hp == 2600.0, count)
	var sn = en.list.filter(func(e8): return e8.kit == "sniper")
	check("1-2: the snipers stand up on container stacks", sn.all(func(e8): return e8.pos.y > 2.0))
	# a bomber's vest: shot in the bomb it goes off at once and the kill pays; reaching you he blows himself up and pays nothing
	var bm9 = en.list.filter(func(e8): return e8.kit == "bomber"); var b1 = bm9[0]; var m0: int = Store.save.money; pl.invuln = 1e9
	var rb9 = en.raycast(en.part_centre(b1, b1.parts[1]) + Vector3(sin(b1.yaw), 0, cos(b1.yaw)) * 4.0, -Vector3(sin(b1.yaw), 0, cos(b1.yaw)), 10.0)
	check("1-2: a ray at a bomber's chest finds the bomb", rb9 != null and rb9.enemy == b1 and rb9.bomb)
	en.blow_vest(b1, Vector3(0, 0, -1)); check("1-2: a bullet in the bomb kills him and pays", not b1.alive and Store.save.money == m0 + 1000 and pr.list.size() == 1 and pr.list[0].kind == "bomb")
	for i in 60: pr.update(1.0 / 30.0)
	check("1-2: and the vest goes off (others caught in it go off too)", pr.list.is_empty())
	gm.begin(5); pl.invuln = 1e9; bm9 = en.list.filter(func(e8): return e8.kit == "bomber")
	var b2 = bm9[1]; pl.reset(b2.pos.x + 1.2, b2.pos.z, 0.0); pl.pos.y = b2.pos.y; pl.invuln = 0.0; pl.hp = 1000.0; pl.update(0.0, cam, 0.0); en.alarm(b2); b2.state = "engage"; b2.react = 0.0; m0 = Store.save.money; var kills0 := gm.kills
	for i in 60: en.update(1.0 / 30.0, 0.0); pr.update(1.0 / 30.0)
	check("1-2: a bomber who reaches you blows himself up: it hurts, it counts, and he pays nothing (others caught in the blast do)", not b2.alive and b2.self_det and pl.hp < 1000.0 and gm.kills >= kills0 + 1 and Store.save.money == m0 + (gm.kills - kills0 - 1) * 1000,
		"hp %d kills +%d money +%d" % [int(pl.hp), gm.kills - kills0, Store.save.money - m0])
	# a lightsaber and a bat hit hard and aim at the head; a helmet you wear stops one such blow
	var sb9 = en.list.filter(func(e8): return e8.kit == "saber")[0]; Store.save.items.helmet = 1
	pl.reset(sb9.pos.x + 1.0, sb9.pos.z, 0.0); pl.pos.y = sb9.pos.y; pl.hp = 1000.0; pl.invuln = 0.0; pl.update(0.0, cam, 0.0); en.alarm(sb9); sb9.state = "engage"; sb9.react = 0.0
	for e8 in en.list:
		if e8 != sb9: e8.awake = false; e8.lod = 99.0; e8.alert = false
	for i in 20: en.update(1.0 / 30.0, 0.0)
	check("1-2: your motorcycle helmet takes the first lightsaber cut", pl.hp == 1000.0 and int(Store.save.items.helmet) == 0, pl.hp)
	for i in 50: en.update(1.0 / 30.0, 0.0)
	check("1-2: the next cut is 300", pl.hp == 700.0 or pl.hp == 400.0, pl.hp)
	# a grenade thrown by a grenadier: it bounces, beeps and bursts
	pr.clear(); pl.reset(0.0, 0.0, 0.0); pl.hp = 1000.0; pl.invuln = 0.0; pr.egrenade(Vector3(8, 1.5, 0), Vector3(0, 0.3, 0), "nade")
	for i in 100: pr.update(1.0 / 30.0)
	check("1-2: a thrown grenade goes off beside you (up to 100)", pr.list.is_empty() and pl.hp < 1000.0 and pl.hp >= 900.0, pl.hp)
	# 1-2: choosing where to be put down
	gm.begin(5); var d9 = gm.pick_drop(-50.0, -50.0)
	check("1-2: you can pick where you are put down, and it is kept for another go", d9 != null and Vector2(pl.pos.x + 50.0, pl.pos.z + 50.0).length() < 10.0 and Phys.collide_at(pl.pos.x, 0.05, pl.pos.z, 0.36, 1.7) == null, pl.pos)
	gm.begin(5); check("1-2: the next go starts there again", Vector2(pl.pos.x - d9.x, pl.pos.z - d9.z).length() < 0.01); gm.drop_pick = null
	# ---------------- stage 5: the toy room ----------------
	Store.save = Store.save0(); gm.begin(9); var toy: ToyRoom = w.toy
	check("the toy room: no enemies yet, every toy gun in hand", toy != null and en.list.is_empty() and g.loadout == Toys.ORDER and Store.stage_open(9))
	var simt := func(sec: float) -> void:
		for i in roundi(sec * 30): pl.update(1.0 / 30.0, cam, 0.0); toy.update(1.0 / 30.0, pl); g.update(1.0 / 30.0)
	pl.in_f = 0.0; pl.in_s = 0.0; pl.in_run = false; simt.call(4.0)
	check("you come down under a parachute", pl.pos.y > 8.0 and pl.pos.y < 20.0 and not pl.grounded, pl.pos.y)
	simt.call(4.0); check("and land on the carpet", pl.grounded and pl.pos.y < 0.2, pl.pos)
	var walk := func(x: float, y: float, z: float, yaw: float, sec: float, run := false) -> Vector3:
		pl.reset(x, z, yaw); pl.pos.y = y; pl.in_f = 1.0; pl.in_run = run; simt.call(sec); pl.in_f = 0.0; pl.in_run = false; return pl.pos
	var q1: Vector3 = walk.call(-2.0, 0.0, 20.0, -PI / 2, 4.0)
	check("up the hanging blanket onto the mattress", absf(q1.y - ToyRoom.BED_Y) < 0.05 and q1.x > 10.0, q1)
	q1 = walk.call(-22.0, 0.0, 24.0, PI / 2, 3.2)
	check("up the stacked books beside the desk", q1.y > 8.5 and q1.x < -36.0, q1)
	q1 = walk.call(-26.0, ToyRoom.DESK_Y, 0.0, -PI / 2, 9.0)
	check("across the block bridge from the desk to the bed", absf(q1.y - ToyRoom.BED_Y) < 0.05 and q1.x > 12.0, q1)
	q1 = walk.call(-34.0, ToyRoom.DESK_Y + 1.01, -22.5, 0.0, 7.0)
	check("up the lamp's neck to the top of the bookshelf", absf(q1.y - ToyRoom.SHELF_Y) < 0.05 and q1.z < -56.0, q1)
	q1 = walk.call(-5.0, ToyRoom.SHELF_Y, -61.5, -PI / 2, 3.0)
	check("from the bookshelf up the books to the wardrobe's top", absf(q1.y - ToyRoom.WARD_Y) < 0.05 and q1.x > 8.0, q1)
	q1 = walk.call(60.5, ToyRoom.BED_Y, 31.7, PI / 2, 3.45); q1 = walk.call(q1.x, q1.y, 31.7, 0.0, 0.8)
	check("up the ladder to the upper bunk", absf(q1.y - ToyRoom.BUNK_Y) < 0.05, q1)
	# springs
	pl.reset(6.0, -22.0, -PI / 2); pl.pos.y = 0.45; simt.call(0.1); var up0 := pl.vel.y; pl.in_f = 1.0; simt.call(2.2); pl.in_f = 0.0
	check("the spring by the bed throws you onto the mattress", up0 > 15.0 and absf(pl.pos.y - ToyRoom.BED_Y) < 0.05, "%s %s" % [str(up0), str(pl.pos)])
	pl.reset(9.0, -32.5, 0.0); pl.pos.y = ToyRoom.BED_Y + 0.45; simt.call(0.1); var peak := 0.0
	for i in 40: simt.call(0.05); peak = maxf(peak, pl.pos.y)
	check("the spring on the mattress reaches the upper bunk's height", peak > ToyRoom.BUNK_Y + 0.5, peak)
	# catapults
	pl.reset(-14.0, 30.0, 0.0); pl.pos.y = 0.45; simt.call(4.0)
	check("the catapult lands you on top of the bookshelf", absf(pl.pos.y - ToyRoom.SHELF_Y) < 0.6 and pl.pos.z < -56.0 and pl.grounded, pl.pos)
	pl.reset(52.0, 41.0, 0.0); pl.pos.y = 0.45; simt.call(4.0)
	check("the other catapult lands you on the upper bunk", absf(pl.pos.y - ToyRoom.BUNK_Y) < 0.6 and pl.grounded, pl.pos)
	# the tape measure
	pl.reset(42.0, -57.0, PI); pl.pos.y = ToyRoom.WARD_Y; pl.in_f = 1.0; simt.call(0.6); pl.in_f = 0.0; var onzip: bool = toy.riding != null; simt.call(5.0)
	check("the tape measure carries you from the wardrobe down to the upper bunk", onzip and toy.riding == null and absf(pl.pos.y - ToyRoom.BUNK_Y) < 0.6 and pl.pos.z > -10.0, pl.pos)
	# mattress, tacks, train
	pl.reset(30.0, 0.0, 0.0); pl.pos.y = ToyRoom.BED_Y; simt.call(0.1); var jm := pl.jump_mul; pl.reset(0.0, 56.0, 0.0); simt.call(0.1)
	check("a springier jump on the mattress, an ordinary one on the floor", jm > 1.1 and pl.jump_mul == 1.0)
	pl.reset(-4.0, 46.0, 0.0); pl.hp = 1000.0; simt.call(2.0)
	check("thumbtacks slow you and prick", pl.slow_mul < 0.6 and pl.hp < 1000.0 and pl.hp > 800.0, pl.hp)
	var car: Dictionary = toy.train.cars[1]; pl.reset(car.pos.x, car.pos.z, 0.0); pl.pos.y = 0.45; var p0 := pl.pos; simt.call(3.0)
	check("a wagon of the toy train carries you along", pl.pos.distance_to(p0) > 20.0 and absf(pl.pos.y - 0.45) < 0.05 and Vector2(pl.pos.x - car.pos.x, pl.pos.z - car.pos.z).length() < 1.0, pl.pos)
	# the toy guns
	var okm := true
	for id in Toys.ORDER + ["ruler"]:
		var n := Toys.build(id); okm = okm and n.get_child_count() >= 5 and Toys.NAMES.has(id) and Toys.LENGTH.has(id); n.free()
	check("nine toy guns and the ruler are modelled", okm and Toys.ORDER.size() == 9)
	g.reset(Toys.ORDER.duplicate()); g.cur = "flame"; g.cooldown = 0.0; pl.reset(0.0, 56.0, 0.0); pl.update(0.0, cam, 0.0); g.trigger = true; simt.call(1.0); g.trigger = false
	check("the spray-can flamethrower sprays (20 a second)", g.wstate.flame.mag < 120 and g.wstate.flame.mag >= 104, g.wstate.flame.mag)
	# ---- the toys' sounds, reloads and effects ----
	gm.begin(9); pl.reset(0.0, 56.0, 0.0); pl.pitch = -0.25; pl.update(0.0, cam, 0.0); Snd.keep_log = true; g.fx = fxn; pr.fx = fxn
	check("in the toy room the guns are toys", g.toy)
	var missing_snd := []
	for id in Toys.ORDER:
		if not ResourceLoader.exists("res://sounds/toy_shot_%s.wav" % id): missing_snd.push_back("shot " + id)
		for st9 in Toys.RELOAD_SND.get(id, []):
			if not ResourceLoader.exists("res://sounds/%s.wav" % st9[1]): missing_snd.push_back(st9[1])
	for nm in ["toy_hit_rifle", "toy_hit_shotgun", "toy_hit_sniper", "toy_boom", "toy_ruler", "toy_pump", "toy_stretch"]:
		if not ResourceLoader.exists("res://sounds/%s.wav" % nm): missing_snd.push_back(nm)
	check("every toy sound exists", missing_snd.is_empty(), missing_snd)
	for id in ["rifle", "shotgun", "sniper", "smg", "rocket"]:
		g.reset(Toys.ORDER.duplicate()); g.cur = id; g.cooldown = 0.0; Snd.played.clear(); pl.pitch = -0.25; pl.update(0.0, cam, 0.0)
		g.trigger = true; g.trigger_edge = true; simt.call(0.1); g.trigger = false; simt.call(2.5); pr.update(3.0)
		var shot_ok: bool = Snd.played.has("toy_shot_" + id) and not Snd.played.has("shot_" + str(Weapons.LIST[id].sound))
		var land_ok: bool = Snd.played.has("toy_boom") if id == "rocket" else (Snd.played.has("toy_hit_" + id))
		g.reload_t = 0.0; g.wstate[id].mag = 0; Snd.played.clear(); g.start_reload(); var W9: Dictionary = Custom.weapon(id)
		var model := Toys.build(id); var seen := {}
		for i in roundi(W9.reload * 30) + 2:
			var f9: float = (1.0 - g.reload_t / W9.reload) if g.reload_t > 0.0 else -1.0; Toys.pose(model, id, f9, g.wstate[id].mag, W9.mag, g.since_shot)
			match id:
				"rifle":
					if f9 > 0.25 and f9 < 0.4 and not model.get_node("mag").visible: seen.out = true
					if f9 > 0.8 and model.get_node("slide").position.z > 0.05: seen.rack = true
				"shotgun":
					if f9 > 0.3 and model.get_node("bottle").visible: seen.bottle = true
					if f9 > 0.05 and f9 < 0.1: seen.low = model.get_node("water").scale.z
					if f9 > 0.58: seen.high = model.get_node("water").scale.z
					if f9 > 0.7 and model.get_node("pump").position.z > 0.04: seen.pump = true
				"sniper":
					if f9 > 0.6 and model.get_node("band").position.z > 0.3: seen.drawn = true
					if f9 > 0.9 and model.get_node("tack").visible: seen.tack = true
				"smg":
					if f9 > 0.2 and f9 < 0.5 and model.get_node("cyl").position.x > 0.05: seen.open = true
					if f9 > 0.42 and f9 < 0.5 and not model.get_node("ring").visible: seen.gone = true
				"rocket":
					if f9 > 0.3 and model.get_node("rocket").visible: seen.inn = true
					if f9 > 0.7 and model.get_node("lighter").visible: seen.lit = true
			simt.call(1.0 / 30.0)
		model.free()
		var steps: Array = Toys.RELOAD_SND[id].map(func(st8): return st8[1]); var heard := Snd.played.filter(func(nm8): return steps.has(nm8))
		var anim_ok: bool = {"rifle": seen.has("out") and seen.has("rack"), "shotgun": seen.has("bottle") and seen.has("pump") and float(seen.get("low", 1.0)) < 0.2 and float(seen.get("high", 0.0)) > 0.95,
			"sniper": seen.has("drawn") and seen.has("tack"), "smg": seen.has("open") and seen.has("gone"), "rocket": seen.has("inn") and seen.has("lit")}[id]
		check("toy %s: its own shot and landing sounds, a reload in steps (%s), the parts move" % [id, ", ".join(steps)], shot_ok and land_ok and heard == steps and g.wstate[id].mag == int(W9.mag) and anim_ok,
			"shot %s land %s heard %s anim %s %s" % [str(shot_ok), str(land_ok), str(heard), str(anim_ok), str(seen)])
	g.reset(Toys.ORDER.duplicate()); g.cur = "shotgun"; var wm := Toys.build("shotgun"); Toys.pose(wm, "shotgun", -1.0, 3.0, 6.0, 9.0)
	check("the water gun's tank shows what is left (half full with 3 of 6)", absf(wm.get_node("water").scale.z - 0.5) < 0.01); wm.free()
	gm.begin(1); Snd.played.clear(); g.reset(["pistol", "rifle"]); g.cur = "rifle"; g.cooldown = 0.0; pl.reset(0, 6, 0); pl.pitch = 1.2; pl.update(0.0, cam, 0.0); g.trigger = true; simt.call(0.2); g.trigger = false
	check("outside the toy room the guns sound as before", not g.toy and Snd.played.has("shot_rifle") and not Snd.played.has("toy_shot_rifle"))
	Snd.keep_log = false
	gm.begin(1)
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)
