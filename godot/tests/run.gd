extends Node
## Checks the port against numbers taken from the browser game (tests/dump_reference.js writes reference_stage1.json).
## Run: godot --headless --path godot res://tests/run.tscn

var fails := 0

## stands in for a control when the checks draw the tactical map: keeps the round marks and the words
class MapRec:
	var circles: Array = []
	var texts: Array = []
	func draw_rect(_r: Rect2, _c: Color, _f := true, _w := -1.0, _aa := false) -> void: pass
	func draw_circle(p: Vector2, r: float, c: Color, _f := true, _w := -1.0, _aa := false) -> void: circles.push_back([p, r, c])
	func draw_arc(_c: Vector2, _r: float, _a0: float, _a1: float, _n: int, _col: Color, _w := -1.0, _aa := false) -> void: pass
	func draw_line(_a: Vector2, _b: Vector2, _c: Color, _w := -1.0, _aa := false) -> void: pass
	func draw_dashed_line(_a: Vector2, _b: Vector2, _c: Color, _w := -1.0, _d := 2.0, _al := true, _aa := false) -> void: pass
	func draw_polyline(_p: PackedVector2Array, _c: Color, _w := -1.0, _aa := false) -> void: pass
	func draw_polygon(_p: PackedVector2Array, _c: PackedColorArray, _uv := PackedVector2Array(), _t = null) -> void: pass
	func draw_colored_polygon(_p: PackedVector2Array, _c: Color, _uv := PackedVector2Array(), _t = null) -> void: pass
	func draw_string(_f: Font, _p: Vector2, t: String, _a := 0, _w := -1.0, _s := 16, _m := Color.WHITE) -> void: texts.push_back(t)
	func draw_string_outline(_f: Font, _p: Vector2, _t: String, _a := 0, _w := -1.0, _s := 16, _o := 1, _m := Color.WHITE) -> void: pass
	## the enemy marks at a 600-pixel map: dots of 3.2, 4.2 and 5.5, the boss's 7
	func dots() -> int:
		var n := 0
		for c: Array in circles:
			var r: float = c[1]
			var col: Color = c[2]
			if (absf(r - 3.2) < 1e-3 or absf(r - 4.2) < 1e-3 or absf(r - 5.5) < 1e-3 or absf(r - 7.0) < 1e-3) and col.a > 0.4 and not col.is_equal_approx(Color(58 / 255.0, 74 / 255.0, 34 / 255.0, 0.85)): n += 1   # (not a tree)
		return n
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
	check("cleared: recorded, best time kept, money and gun stay, 2 and 1-1 offered next", shown == ["clear"] and Store.save.cleared == [1] and Store.save.best.has("t1") and Store.save.money == 119000 and Store.save.owned.size() == 1 \
		and Store.next_stages(1) == [2, 6], str(Store.next_stages(1)))
	var keep_save: Dictionary = Store.save; var keep_dev: bool = Store.settings.dev; Store.save = Store.save0(); Store.settings.dev = false
	check("every stage can be played from the start: none waits for another to be cleared", Store.STAGE_ORDER.size() == 9 and Store.STAGE_ORDER.all(func(s): return Store.stage_open(s)) and not Store.stage_open(10))
	Store.save = keep_save; Store.settings.dev = keep_dev
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
	for stn in [6, 5, 2, 3, 7, 4, 8]:
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
			var moved9: bool = (stn == 3 or stn == 8) and (absf(e9.pos.x - q9[0]) > 11.0 or absf(e9.pos.z - q9[1]) > 11.0)   # the lab's animals had paced about their cages by the time they were written down
			var still9: bool = stn != 3 and stn != 8 and (stn != 4 or e9.type in ["cctv", "mine", "gdrone", "bdrone"])   # the ship's patrols and drones had moved off by the time they were written down
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
	var s2_up: MeshInstance3D = en.list[1].upper.get_child(0); var s2_cols: PackedColorArray = s2_up.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check("stage 2: a zombie has no hair, only its two pale eyes (the browser game's build: body, head, eyes)",
		s2_cols.size() == 4 * 24 and s2_cols[2 * 24].is_equal_approx(Color("fff0a0")) and s2_cols[3 * 24].is_equal_approx(Color("fff0a0")) and not s2_cols.has(Color("2c2c2a")))
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
	var s2_ft: float = s2_zb.flash_t; s2_zb.flash_t = 0.0; en._glow(s2_zb, "rage")   # (as the next frame does once the hit's flash is over)
	var s2_rm: StandardMaterial3D = (s2_zb.upper.get_child(0) as MeshInstance3D).material_override; var s2_ov: StandardMaterial3D = (s2_zb.upper.get_child(0) as MeshInstance3D).material_overlay
	check("stage 2: raging it turns red as the browser game's (its colours times 1, 0.4, 0.36, and a red glow that pulses about 0.3)",
		s2_rm.albedo_color.is_equal_approx(World.lin(Color(1, 0.4, 0.36))) and not s2_rm.emission_enabled and s2_ov != null and s2_ov.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
		and absf(s2_ov.albedo_color.srgb_to_linear().r - 0.3) <= 0.141 and absf(s2_ov.albedo_color.srgb_to_linear().g - 0.02) < 0.002, s2_ft)
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
	# ---------------- stage 3-2: the lab, one cage at a time ----------------
	gm.begin(8); var lb8: Lab = w.lab; pl.invuln = 1e9
	check("stage 3-2: every cage is glass, and only the first is on a clock (5 s)", lb8.seq and lb8.cages[0].open_at == 5.0 and lb8.cages[1].held and lb8.cages[0].animals[0].glassed and lb8.cages[0].panels[0].col.glass)
	var z8 = lb8.cages[0].animals[0]; en.damage(z8, 999, z8.pos, Vector3(0, 0, 1), false)
	check("stage 3-2: nothing behind the glass can be hurt", z8.alive and z8.hp == 150.0)
	for i in 260: lb8.update(0.02)
	check("stage 3-2: the first cage opens at 5 s; the second waits for it to be emptied", lb8.cages[0].open and not lb8.cages[1].open and lb8.wait_left(lb8.cages[1]) == 12 and lb8.next_cage().n == 2)
	for e in lb8.cages[0].animals.slice(1): en.damage(e, 999, e.pos, Vector3(0, 0, 1), false)
	for i in 100: lb8.update(0.02)
	check("stage 3-2: one zebra left: the second cage stays shut", not lb8.cages[1].open and lb8.wait_left(lb8.cages[1]) == 1)
	en.animals.ride_on(z8)
	for i in 30: lb8.update(0.02)
	check("stage 3-2: taming the last one counts too: the monkey reaches for his button", lb8.wait_left(lb8.cages[1]) == 0 and (lb8.reach != null or lb8.cages[1].open_at < INF))
	for i in 60: lb8.update(0.02)
	check("stage 3-2: and half a second after the push the second cage opens", lb8.cages[1].open and not lb8.cages[2].open)
	en.animals.ride_off(true)
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
	gm.begin(4); var s4_cam = null
	for e in en.list:
		if e.type == "cctv": s4_cam = e; break
	check("stage 4: a ceiling camera shoots from its own lens, not from where a man's gun would be", en.muzzle_of(s4_cam).distance_to(s4_cam.pos) < 0.5, en.muzzle_of(s4_cam) - s4_cam.pos)
	# ---------------- stage 5: the toy room ----------------
	gm.begin(9); var s5_tf: ToyFoes = en.toys; pl.invuln = 1e9
	var s5_kinds := {}
	for e in en.list: s5_kinds[e.type] = int(s5_kinds.get(e.type, 0)) + 1
	check("stage 5: a hundred toys: 30 plastic soldiers, 22 action figures, 24 wind-up cars, 24 brick figures", en.list.size() == 100 and gm.goal == 100 and s5_kinds.get("soldier", 0) == 30 and s5_kinds.get("figure", 0) == 22 and s5_kinds.get("rc", 0) == 24 and s5_kinds.get("brick", 0) == 24, s5_kinds)
	var s5_bad := ""
	for e in en.list:
		var gy5 := Phys.ground_at(e.pos.x, e.pos.y + 0.1, e.pos.z, e.R)
		if absf(gy5 - e.pos.y) > 0.05 or Phys.collide_at(e.pos.x, e.pos.y + 0.05, e.pos.z, e.R, 1.5) != null: s5_bad = "%s %s" % [e.type, str(e.pos)]; break
	check("stage 5: every toy stands on something and inside nothing", s5_bad == "", s5_bad)
	var s5_first: Vector3 = en.list[0].pos; var s5_last: Vector3 = en.list[99].pos; gm.begin(9); s5_tf = en.toys
	check("stage 5: the same toys in the same places every time", en.list[0].pos == s5_first and en.list[99].pos == s5_last)
	var s5_hi := {"soldier": 0.0, "figure": 0.0}
	for e in en.list:
		if s5_hi.has(e.type): s5_hi[e.type] = maxf(s5_hi[e.type], e.pos.y)
	check("stage 5: soldiers up on the bookshelf, figures up on the wardrobe", s5_hi.soldier >= 19.9 and s5_hi.figure >= 23.9, s5_hi)
	# plastic soldier: still for 2 s it fades, and aim help reaches only half as far; a hit shows it again; blasts barely move it
	var s5_s = en.list.filter(func(e): return e.type == "soldier")[0]
	s5_s.pos = Vector3(2, 0, 50); s5_s.k.post = s5_s.pos; s5_s.alert = false; s5_s.los = false; s5_s.k.reveal = 0.0
	for i in 25: s5_tf.update(s5_s, 0.1, 50.0, Vector2(50, 0), 0.0)
	var s5_eye: Vector3 = s5_s.pos + Vector3(20, 1.2, 0)
	var s5_off := func() -> Vector3:   # just off the body: where the aim help would pull your shot onto it
		var d0: Vector3 = (en.part_centre(s5_s, s5_s.parts[1]) - s5_eye).normalized(); return d0.rotated(d0.cross(Vector3.UP).normalized(), 0.035)
	var s5_a1 = en.assist(s5_eye, s5_off.call(), 0.05, 30.0)
	check("stage 5: a soldier still for 2 s crouches and fades; aim help no longer reaches it from 20 m", s5_tf.camo(s5_s) and float(s5_s.k.alpha) < 0.5 and s5_s.g.scale.y < 0.8 and s5_a1 == null, [s5_s.k.alpha, s5_s.g.scale.y])
	check("stage 5: crouched, its head is lower too (the hit spheres follow it down)", absf(en.part_centre(s5_s, s5_s.parts[0]).y - s5_s.pos.y - 1.72 * s5_s.g.scale.y) < 0.01)
	s5_s.vel = Vector3.ZERO; en.damage(s5_s, 1, s5_s.pos, Vector3(1, 0, 0), false)
	check("stage 5: a hit gives it away (aim help finds it again) and barely shoves it", not s5_tf.camo(s5_s) and en.assist(s5_eye, s5_off.call(), 0.05, 30.0) != null and absf(s5_s.vel.x - 0.18) < 1e-4, s5_s.vel)
	# action figure: a second jump at the top of the first; coming down a long way it glides on its cape
	var s5_f = en.list.filter(func(e): return e.type == "figure")[0]
	s5_f.pos = Vector3(-2, 0, 12); s5_f.vy = 0.0; s5_f.alert = true; s5_f.los = true; s5_f.k.jumps = 0; s5_f.k.glide = false; s5_f.k.jump_cd = 0.0; pl.pos = Vector3(40, 6, 12)
	var s5_peak := 0.0; var s5_two := false
	for i in 70:
		var t5 := Vector2(pl.pos.x - s5_f.pos.x, pl.pos.z - s5_f.pos.z); s5_tf.update(s5_f, 0.02, t5.length(), t5, atan2(t5.x, t5.y)); s5_peak = maxf(s5_peak, s5_f.pos.y)
		if int(s5_f.k.jumps) == 2: s5_two = true
	check("stage 5: an action figure jumps twice: higher than one jump can take it", s5_two and s5_peak > 4.5, s5_peak)
	s5_f.pos = Vector3(-2, 20, 12); s5_f.vy = 0.0; s5_f.k.glide = false; s5_f.k.jumps = 2
	for i in 50:
		var t6 := Vector2(pl.pos.x - s5_f.pos.x, pl.pos.z - s5_f.pos.z); s5_tf.update(s5_f, 0.02, t6.length(), t6, atan2(t6.x, t6.y))
	check("stage 5: falling from high up it spreads its cape: a second's drop is under 3 m (not 9.5)", bool(s5_f.k.glide) and s5_f.pos.y > 17.0, s5_f.pos.y)
	# wind-up car: faster the longer it runs; it rams; broken, its battery bursts; toys near it shoot faster
	var s5_r = en.list.filter(func(e): return e.type == "rc")[0]
	s5_r.pos = Vector3(-30, 0, 48.5); s5_r.yaw = PI / 2; s5_r.vel = Vector3.ZERO; s5_r.k.v = 0.0; s5_r.k.back_t = 0.0; s5_r.alert = true; s5_r.los = true; pl.pos = Vector3(10, 0, 48.5)
	var s5_x0: float = s5_r.pos.x
	for i in 150:
		var t7 := Vector2(pl.pos.x - s5_r.pos.x, pl.pos.z - s5_r.pos.z); s5_tf.update(s5_r, 0.02, t7.length(), t7, atan2(t7.x, t7.y))
	check("stage 5: a wind-up car picks up speed as it runs (about 9.6 m/s after 3 s)", absf(float(s5_r.k.v) - 9.6) < 0.2 and s5_r.pos.x - s5_x0 > 12.0, [s5_r.k.v, s5_r.pos.x - s5_x0])
	pl.invuln = 0.0; pl.hp = Player.MAX_HP; s5_r.k.v = 10.0; s5_r.k.back_t = 0.0; pl.pos = Vector3(s5_r.pos.x + 1.4, 0, s5_r.pos.z); s5_r.yaw = PI / 2
	var t8 := Vector2(pl.pos.x - s5_r.pos.x, pl.pos.z - s5_r.pos.z); s5_tf.update(s5_r, 0.02, t8.length(), t8, atan2(t8.x, t8.y))
	check("stage 5: at 10 m/s its ram takes about 21", absf((Player.MAX_HP - pl.hp) - 21.0) <= 1.0 and float(s5_r.k.v) == 0.0, Player.MAX_HP - pl.hp)
	var s5_near = en.list.filter(func(e): return e.type == "soldier")[1]; s5_near.pos = s5_r.pos + Vector3(0, 0, 3.0)
	check("stage 5: a toy within 8 m of a car shares its battery: it shoots 1.4 times as fast", s5_tf._share(s5_near) == ToyFoes.SHARE_MUL and s5_tf._share(s5_s) == 1.0)
	pl.hp = Player.MAX_HP; pl.pos = Vector3(s5_r.pos.x + 1.5, 0, s5_r.pos.z); en.damage(s5_r, 999, s5_r.pos, Vector3(0, 0, 1), false)
	check("stage 5: broken, its battery bursts: sparks for you close by", not s5_r.alive and Player.MAX_HP - pl.hp >= 15.0 and Player.MAX_HP - pl.hp <= 25.0, Player.MAX_HP - pl.hp)
	pl.invuln = 1e9
	# brick figure: a brick off at every quarter of its health; a brick picked up goes back on; a quiet moment and it is whole
	var s5_b = en.list.filter(func(e): return e.type == "brick")[0]
	s5_b.pos = Vector3(-2, 0, 49); s5_b.alert = true; s5_b.los = true; var s5_n0: int = s5_tf.bricks.size()
	en.damage(s5_b, 45, s5_b.pos, Vector3(0, 0, 1), false); en.damage(s5_b, 40, s5_b.pos, Vector3(0, 0, 1), false)
	check("stage 5: a brick figure drops a brick at every quarter of its health lost", s5_tf.bricks.size() == s5_n0 + 2 and s5_b.hp == 75.0, s5_tf.bricks.size() - s5_n0)
	s5_tf.bricks[s5_n0].pos = s5_b.pos; s5_b.k.quiet = 0.0; pl.pos = Vector3(30, 0, 49)
	s5_tf.update(s5_b, 0.02, 32.0, Vector2(32, 0), PI / 2)
	check("stage 5: picking a brick up puts its quarter back", s5_b.hp == 115.0 and s5_tf.bricks.size() == s5_n0 + 1, s5_b.hp)
	s5_b.k.quiet = 6.0; s5_b.los = false; s5_tf.update(s5_b, 0.02, 32.0, Vector2(32, 0), PI / 2)
	check("stage 5: out of the fight for 5 s it snaps back together all at once", s5_b.hp == 160.0 and int(s5_b.k.shed) == 0)
	var s5_c0: int = w.crates.size(); s5_tf._build_wall(s5_b, Vector2(1, 0)); var s5_w = w.crates[w.crates.size() - 1] if w.crates.size() > s5_c0 else null
	check("stage 5: it puts up a little brick wall towards you, and it stands in the way", s5_w != null and s5_w.wall and Phys.collide_at(s5_w.x, s5_w.y + 0.3, s5_w.z, 0.2, 0.5) == s5_w.b)
	var s5_l0: int = lt.list.size(); w.damage_crate(s5_w, 60, Vector3(s5_w.x, 0.6, s5_w.z))
	check("stage 5: shot down it is gone, and nothing falls out of it", s5_w.dead and Phys.collide_at(s5_w.x, s5_w.y + 0.3, s5_w.z, 0.2, 0.5) == null and lt.list.size() == s5_l0)
	for b in s5_tf.bricks: (b.n as Node3D).queue_free()
	s5_tf.bricks.clear(); s5_b.pos = Vector3(7.4, 0, 41); s5_b.yaw = PI / 2; s5_b.los = false; s5_b.vel = Vector3.ZERO; pl.pos = Vector3(30, 3, 41)
	for i in 70:
		var t9 := Vector2(pl.pos.x - s5_b.pos.x, pl.pos.z - s5_b.pos.z); s5_tf.update(s5_b, 0.02, t9.length(), t9, atan2(t9.x, t9.y))
	check("stage 5: blocked by a toy block, it climbs straight up the side and onto the top", absf(s5_b.pos.y - 2.0) < 0.05 and s5_b.pos.x > 8.0, s5_b.pos)
	s5_b.pos = Vector3(9.3, 0, -28.8); var s5_post := s5_tf._climb_top(s5_b, Vector2(1, 0))      # against a bunk bed post (26 m)
	s5_b.pos = Vector3(-69.3, 0, 40.0); var s5_room := s5_tf._climb_top(s5_b, Vector2(-1, 0))    # against the room's west wall
	s5_b.pos = Vector3(7.4, 0, 41.0); var s5_blk := s5_tf._climb_top(s5_b, Vector2(1, 0))        # against a toy block (2 m)
	check("stage 5: it climbs a toy block, but not a bed post or the room's wall", s5_post < 0.0 and s5_room < 0.0 and absf(s5_blk - 2.0) < 1e-4, [s5_post, s5_room, s5_blk])
	# a fight: on the carpet the toys come and shoot; then all hundred down is a clear
	gm.begin(9); pl.reset(0.0, 50.0, 0.0); pl.update(0.0, cam, 0.0); pl.invuln = 1e9; var s5_shots := 0   # your eyes (the camera) where you stand
	for i in 600:
		en.update(0.02, i * 0.02); pr.update(0.02); gm.update(0.02)
		if pr.list.size() > 0: s5_shots += 1
	check("stage 5: within 12 s on the carpet the toys wake, come and shoot", s5_shots > 0 and en.list.filter(func(e): return e.alert).size() >= 10, [s5_shots, en.list.filter(func(e): return e.alert).size()])
	for e in en.list.duplicate(): en.damage(e, 1e6, e.pos, Vector3(0, 0, 1), false)
	for i in 120: gm.update(0.02)
	check("stage 5: all hundred down is a clear", gm.ended and gm.result == "clear" and gm.kills == 100, [gm.kills, gm.result])
	pr.clear()
	# 1-1: the helmet takes the first shot to the head
	gm.begin(6); var hm = en.list[3]; var hd9: Vector3 = en.part_centre(hm, hm.parts[0])
	var hm_mi: MeshInstance3D = (hm.helmet_node as Node3D).get_child(0); var hm_mat: StandardMaterial3D = hm_mi.material_override
	check("1-1: the helmet is the browser game's MotoHelmet: its fourteen boxes, glossy (roughness 0.18, metalness 0.35)",
		(hm_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 14 * 24 and absf(hm_mat.roughness - 0.18) < 1e-6 and absf(hm_mat.metallic - 0.35) < 1e-6)
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
	# 1-2's looks, as the browser game's build: the gold desert eagle in gold metal apart from the arm, the lightsabers' blades in a halo, the vest's red light
	var vcount9 := func(n: Node3D) -> int: return ((n.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var dg9 = en.list.filter(func(e8): return e8.kit == "deagle")[0]
	var gold9: Array = dg9.arm_r.get_children().filter(func(ch9): return ch9 is MeshInstance3D and ch9.material_override is StandardMaterial3D and ch9.material_override.metallic > 0.5)
	var gmat9: StandardMaterial3D = gold9[0].material_override if gold9.size() == 1 else null
	check("1-2: the gold desert eagle is gold metal, not a tint (e2b23c, roughness 0.22, metalness 0.9, a 4a3300 glow at 0.55), apart from the arm's boxes",
		gmat9 != null and gmat9.albedo_color.is_equal_approx(World.lin("e2b23c")) and absf(gmat9.roughness - 0.22) < 1e-6 and absf(gmat9.metallic - 0.9) < 1e-6 and gmat9.emission_enabled
		and gmat9.emission.is_equal_approx(World.lin("4a3300")) and absf(gmat9.emission_energy_multiplier - 0.55) < 1e-6 and vcount9.call(dg9.arm_r) == 2 * 24 and not gmat9.vertex_color_use_as_albedo)
	var blades9 := func(e8) -> Array:
		var found := []
		for arm9 in [e8.arm_r, e8.arm_l]:
			for ch9 in arm9.get_children():
				if ch9 is MeshInstance3D and ch9.mesh is BoxMesh: found.push_back(ch9)
		return found
	var sabre_ok := func(got9: Array, n9: int, core9: String, glow9: String, al9: float) -> bool:
		if got9.size() != n9 * 2: return false
		for bx9 in got9:
			var mt9: StandardMaterial3D = bx9.material_override; var halo9: bool = (bx9.mesh as BoxMesh).size.x > 0.05
			if not (bx9.mesh as BoxMesh).size.is_equal_approx(Vector3(0.09, 1.22, 0.09) if halo9 else Vector3(0.035, 1.15, 0.035)) or not bx9.position.is_equal_approx(Vector3(0, -1.38, 0.03)): return false
			if mt9.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED: return false
			if halo9 and not (mt9.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and mt9.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and absf(mt9.albedo_color.a - al9) < 1e-6 and Color(mt9.albedo_color, 1.0).is_equal_approx(World.lin(glow9))): return false
			if not halo9 and not mt9.albedo_color.is_equal_approx(World.lin(core9)): return false
		return true
	check("1-2: a lightsaber is a thin blade (a8d4ff) in a halo of added light (2a62ff at 42%); the dual wielders' two are red (ff8a8a in ff2a3a at 38%)",
		sabre_ok.call(blades9.call(en.list.filter(func(e8): return e8.kit == "saber")[0]), 1, "a8d4ff", "2a62ff", 0.42) and sabre_ok.call(blades9.call(en.list.filter(func(e8): return e8.kit == "saber2")[0]), 2, "ff8a8a", "ff2a3a", 0.38))
	var vb9 = en.list.filter(func(e8): return e8.kit == "bomber")[0]
	check("1-2: a bomber's vest light is the browser game's red (ff2a1a)", (vb9.vest_light.material_override as StandardMaterial3D).albedo_color.is_equal_approx(World.lin("ff2a1a")))
	en._glow(dg9, "flash"); var fl9: StandardMaterial3D = (dg9.arm_r.get_child(0) as MeshInstance3D).material_overlay
	check("1-2: a hit's flash (the browser game's 0.6, 0.35, 0.2 glow) lights the body, not the gold gun",
		fl9 != null and fl9.albedo_color.is_equal_approx(World.lin(Color(0.6, 0.35, 0.2))) and gold9[0].material_overlay == null and (dg9.upper.get_child(0) as MeshInstance3D).material_overlay == fl9)
	en._glow(dg9, "")
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
	check("the toy room: a hundred toys in it, every toy gun in hand", toy != null and en.list.size() == 100 and g.loadout == Toys.ORDER and Store.stage_open(9))
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
	# ---------------- the tactical map ----------------
	var tm := TacMap.new(); tm.game = gm; tm.cam = cam; tm.f_mono = SystemFont.new(); tm.f_bold = SystemFont.new()
	var map_of := func(st: int) -> MapRec:
		var rc := MapRec.new(); tm.setup(st); tm.draw(rc, Vector2(600, 600)); return rc
	var shown_of := func() -> int:
		return en.list.filter(func(e): return e.alive and not e.ridden and not (e.type == "mine" and (e.bs == "hidden" or e.bs == ""))).size()
	var map_bad := []
	for st9 in [1, 6, 5, 2, 3, 7, 8, 4, 9]:
		gm.begin(st9); var rc9: MapRec = map_of.call(st9)
		var where9: String = {3: "출입문", 8: "출입문", 4: "에어록"}.get(st9, "내리는 곳")
		if rc9.dots() != shown_of.call() or not rc9.texts.has("N ↑") or not rc9.texts.has(where9): map_bad.push_back("%d: %d dots / %d, %s" % [st9, rc9.dots(), shown_of.call(), str(rc9.texts.slice(0, 4))])
	check("the tactical map opens on all nine stages: a mark for every enemy, north, the scale and the drop point", map_bad.is_empty(), map_bad)
	gm.begin(1); var m_before: int = (map_of.call(1) as MapRec).dots(); var m_one = en.list.filter(func(e): return e.alive and not e.boss)[0]
	en.damage(m_one, 5000, m_one.pos, Vector3(0, 0, -1), false)
	check("an enemy shot dead is gone from the map", (map_of.call(1) as MapRec).dots() == m_before - 1, [m_before, (map_of.call(1) as MapRec).dots()])
	gm.begin(4); tm.setup(4); var m_px := Vector2(300, 300); var m_w := tm.to_world(Vector2(600, 600), m_px)
	var m_k := 600.0 / (2.0 * (tm.H + TacMap.PAD)); var m_back := Vector2((m_w.x - tm.CX + tm.H + TacMap.PAD) * m_k, (m_w.y - tm.CZ + tm.H + TacMap.PAD) * m_k)
	check("a point on the map leads back to the ground it shows (the ship's map is centred 19 m east)", m_back.distance_to(m_px) < 1e-3 and absf(m_w.x - 19.0) < 1e-3 and absf(m_w.y) < 1e-3, m_w)
	gm.begin(3); var m_lab: MapRec = map_of.call(3); var m_cage_tags := m_lab.texts.filter(func(t: String): return t.contains(" ") and t.split(" ")[0].is_valid_int())
	check("the lab's map: every cage numbered with its animal, and the seconds until it opens", m_cage_tags.size() == 10 and m_lab.texts.has("10초") and m_lab.texts.has("%d초" % ceili(Lab.FIRST + Lab.STEP * 9)), m_cage_tags)
	gm.begin(8); var m_seq: MapRec = map_of.call(8)
	check("3-2's map: the cages that wait for the one before them say so", m_seq.texts.filter(func(t: String): return t == "앞 우리를 비우면").size() == 9 and m_seq.texts.has("5초"))
	gm.begin(7); var m_t0: MapRec = map_of.call(7); w.safari.hp = 5000.0; var m_t1: MapRec = map_of.call(7); w.safari.standing = false; var m_t2: MapRec = map_of.call(7); w.safari.standing = true; w.safari.hp = 10000.0
	check("3-1's map: the watchtower and how much it has left, and when it is down", m_t0.texts.has("감시탑 100%") and m_t1.texts.has("감시탑 50%") and m_t2.texts.has("감시탑 무너짐"))
	gm.begin(4); var m_s0: MapRec = map_of.call(4); w.ship.break_floor(); var m_s1: MapRec = map_of.call(4)
	check("the ship's map: once the hall's floor falls in, the pit's landings and floor are marked with their depths", not m_s0.texts.has("-9m") and m_s1.texts.has("-3m") and m_s1.texts.has("-6m") and m_s1.texts.has("-9m"), m_s1.texts.filter(func(t: String): return t.ends_with("m")))
	tm.setup(4); var m_l4: Array = tm.legend(true).map(func(it): return it[1]); tm.setup(5); var m_l5: Array = tm.legend(false).map(func(it): return it[1]); tm.setup(9); var m_l9: Array = tm.legend(true).map(func(it): return it[1])
	check("the legend: each stage's kinds, the drop point to pick on 1-2's briefing, who is after you while you play; the toy room has no boss",
		m_l4.has("스파이더 마인 (움직일 때만)") and m_l4.has("흰 테두리 · 나를 쫓는 중") and m_l4.has("에어록 · 시작하는 곳") and m_l5.has("내리는 곳 · 지도를 눌러 바꾸기") and not m_l5.has("흰 테두리 · 나를 쫓는 중")
		and m_l9.has("플라스틱 군인") and m_l9.has("조립 블록 피규어") and not m_l9.has("보스"), [m_l4.size(), m_l5.size(), m_l9])
	# ---------------- the cutscenes: played through or skipped, they end the same ----------------
	var ct := Cut.new(); add_child(ct); ct.cam = cam; ct.player = pl; ct.game = gm; ct.world = w; ct.enemies = en; ct.fx = fxn
	var c_done := [0]; var c_end := func() -> void: c_done[0] += 1
	var c_run := func(sec: float) -> void:
		for i in roundi(sec * 30.0):
			if not ct.active(): break
			ct.update(1.0 / 30.0); fxn.update(1.0 / 30.0)
			if w.ship != null: w.ship.anim_door(1.0 / 30.0)
	# in by helicopter: down the rope, on the ground at the drop point looking the way you will face
	gm.begin(1); Snd.keep_log = true; Snd.played.clear(); c_done[0] = 0; ct.start_intro(1, c_end); var c_rope := false
	for i in 230:
		ct.update(1.0 / 30.0)
		if ct.rope.visible: c_rope = true
		if not ct.active(): break
	var c_st: Dictionary = w.start
	check("in by helicopter: down the rope beside it, then on the ground where the stage starts (7.2 s)", c_done[0] == 1 and not ct.active() and c_rope and Snd.played.has("land") and Snd.played.has("rotor")
		and Vector2(cam.global_position.x - c_st.x, cam.global_position.z - c_st.z).length() < 0.01 and absf(cam.global_position.y - Player.EYE) < 0.01 and not ct.heli.visible, [c_done[0], c_rope, cam.global_position])
	gm.begin(1); c_done[0] = 0; ct.start_intro(1, c_end); c_run.call(1.0); ct.skip()
	check("skipped, the helicopter is gone and play starts the same", c_done[0] == 1 and not ct.active() and not ct.heli.visible and not ct.rope.visible and ct.fade_to == 0.0)
	pl.reset(5, 30, 0.7); c_done[0] = 0; ct.start_outro(c_end); var c_climb := false
	for i in 270:
		ct.update(1.0 / 30.0)
		if ct.fig.visible and ct.fig.position.y > 1.0: c_climb = true
		if not ct.active(): break
	check("out by helicopter: up the rope ladder, then black (8.6 s)", c_done[0] == 1 and c_climb and ct.fade_to == 1.0 and not ct.fig.visible)
	# the lab: the monkey slams his button and the boards light up; the clock itself starts with play
	gm.begin(3); var L3: Lab = w.lab
	var c_dark: bool = not L3.pressed and not L3.clock and str(L3.cages[0].shown) == "- -"
	c_done[0] = 0; Snd.played.clear(); ct.start_intro(3, c_end); var c_press_t := -1.0
	for i in 330:
		ct.update(1.0 / 30.0)
		if L3.pressed and c_press_t < 0.0: c_press_t = float(ct.C.t)
		if not ct.active(): break
	check("the lab's opening: dark boards, the monkey's button at 4.1 s, the boards count, and the cages' clock waits for play", c_dark and c_done[0] == 1 and absf(c_press_t - 4.13) < 0.05 and L3.clock and L3.t == 0.0
		and Snd.played.has("press") and Snd.played.has("siren") and str(L3.cages[0].shown) == "10", [c_dark, c_press_t, L3.t, L3.cages[0].shown])
	gm.begin(3); L3 = w.lab; c_done[0] = 0; ct.start_intro(3, c_end); c_run.call(1.0); ct.skip()
	L3.update(1.0)
	check("skipped before the button: it is pressed for you, and the first cage still opens 10 s into play", c_done[0] == 1 and L3.pressed and absf(L3.t - 1.0) < 1e-6 and not L3.cages[0].open and float(L3.cages[0].open_at) == 10.0)
	c_done[0] = 0; ct.start_outro(c_end); c_run.call(8.0)
	check("out of the lab: the alarm stops, the sealed door rolls up, black", c_done[0] == 1 and not L3.alarm and L3.door_open == 1.0 and ct.fade_to == 1.0)
	# the ship: the airlock's inner door rolls up, you step out, it shuts behind you
	gm.begin(4); var S4: Ship = w.ship; c_done[0] = 0; ct.start_intro(4, c_end); var c_up := 0.0
	for i in 200:
		ct.update(1.0 / 30.0); S4.anim_door(1.0 / 30.0); c_up = maxf(c_up, S4.door_open)
		if not ct.active(): break
	var c_shut0: bool = S4.closing and S4.door_open > 0.9
	for i in 45: S4.anim_door(1.0 / 30.0)
	check("the ship's opening: the airlock door rolls up, then shuts behind you", c_done[0] == 1 and c_up == 1.0 and c_shut0 and S4.door_open == 0.0 and S4.air_door.position.y == 2.25, [c_up, S4.door_open])
	gm.begin(4); S4 = w.ship; c_done[0] = 0; ct.start_intro(4, c_end); c_run.call(0.5); ct.skip()
	for i in 45: S4.anim_door(1.0 / 30.0)
	check("skipped, the airlock ends shut just the same", c_done[0] == 1 and not S4.closing and S4.door_open == 0.0)
	c_done[0] = 0; ct.start_outro(c_end); c_run.call(7.5)
	check("out of the ship: back through the airlock, and it shuts", c_done[0] == 1 and S4.door_open == 0.0 and ct.fade_to == 1.0)
	# a sealed door: a look at the bee, its name, then you are inside and it locks
	for c_skip in [false, true]:
		gm.begin(4); S4 = w.ship; var D4: Dictionary = S4.doors[0]; var bee = S4.drone(D4)
		S4.on_cut = func(D: Dictionary, e: Enemies.Foe, done: Callable) -> void: ct.start_boss_intro(D, e, done)
		S4.enter(D4); var c_mid: String = D4.mode; var c_kind := ct.kind()
		if c_skip: c_run.call(0.4); ct.skip()
		else: c_run.call(2.0)
		check("the bridge door: a second and a half looking at the gold bee, then locked in with it (%s)" % ("skipped" if c_skip else "watched"),
			c_kind == "boss" and c_mid == "cut" and D4.mode == "locked" and not bee.sealed and absf(pl.pos.x - (D4.x + D4.inward * 2.4)) < 1e-4 and not ct.active(), [c_kind, c_mid, D4.mode, pl.pos])
	S4.on_cut = Callable(); Snd.keep_log = false
	# ---------------- the save code by mail ----------------
	var ms := Store.save0(); ms.cleared = [1, 6]; ms.money = 119000; var mcode := SaveCode.encode(ms)
	var mt := SaveCode.mail_text(ms, mcode, "2026-11-16 09:30"); var mlines: PackedStringArray = str(mt.body).split("\r\n")
	check("the mail: the code, when it was saved, the stages cleared and the bag, as the browser game writes it",
		mt.subject == "야르 07 저장 코드 · 2026-11-16 09:30" and mlines[0] == "야르 07 저장 코드" and mlines[2] == mcode and mlines[4] == "저장한 때: 2026-11-16 09:30" and mlines[5] == "깬 스테이지: 1, 1-1"
		and mlines[6] == "가방: 119,000원" and mlines[8].begins_with("게임 처음 화면의 '불러오기'"), mlines)
	var ml := SaveCode.mail_links(" someone@example.com ", mt.subject, mt.body); var mn := SaveCode.mail_links("not an address", mt.subject, mt.body)
	check("the mail app and Gmail links: to the address when it is one, the code in the body",
		str(ml.mailto).begins_with("mailto:someone@example.com?subject=") and str(ml.mailto).contains(mcode) and str(ml.gmail).begins_with("https://mail.google.com/mail/?view=cm&fs=1&to=someone%40example.com&su=")
		and str(mn.mailto).begins_with("mailto:?subject=") and not str(mn.gmail).contains("&to=") and str(mn.gmail).contains("&body="), [ml.mailto.left(60), mn.gmail.left(70)])
	# ---------------- the codex ----------------
	var cx_all := Codex.foes(); var cx_by := {}
	for e in cx_all: cx_by[e.name] = e
	var cx_fields := cx_all.all(func(e): return e.has("st") and e.has("hp") and e.has("speed") and e.has("arms") and e.has("dmg") and e.has("trait") and e.has("skill"))
	check("the enemy book: every enemy of the eight stages, 35 cards, each with health, speed, arms, damage, traits and skills", cx_all.size() == 35 and cx_fields, cx_all.size())
	check("its numbers come from the game's tables, as the browser game writes them",
		str(cx_by["조직 두목"].dmg).begins_with("한 발 14 ·") and str(cx_by["코뿔소"].dmg).begins_with("떨어질 때 50 +") and str(cx_by["코끼리"].dmg).begins_with("엄니 36 · 돌진 43 +")
		and str(cx_by["기린"].trait).begins_with("머리를 맞히면 데미지 10배") and int(cx_by["거대 로랜드고릴라"].pay) == 50000 and str(cx_by["최첨단 감시 드론 B-3"].hp) == "9,000 (3페이즈)"
		and str(cx_by["CCTV 포탑"].dmg) == "한 발 4 · 1발씩, 1~1.6초마다", [cx_by["조직 두목"].dmg, cx_by["코끼리"].dmg, cx_by["CCTV 포탑"].dmg])
	var cx_g := Codex.guns(); var cx_rk: Dictionary = cx_g[Weapons.ORDER.find("rocket")]; var cx_rkw := Custom.weapon("rocket")
	var cx_dps := Codex.n(float(cx_rkw.dmg) / (float(cx_rkw.rate) + float(cx_rkw.reload)))
	check("the gun book: a one-round magazine counts its reload in the DPS, and every gun shows DPS with the reload too", cx_g.size() == 9 and str(cx_rk.rows[2][1]) == cx_dps + " · 재장전 포함 " + cx_dps
		and str(cx_g[0].rows[2][1]).contains(" · 재장전 포함 ") and cx_g[8].name == "근접 공격", [cx_rk.rows[2][1], cx_dps])
	var cx_keep: Dictionary = Store.save; var cx_dev: bool = Store.settings.dev; Store.settings.dev = false; Store.save = Store.save0()
	var cx_none := not Codex.ready() and cx_all.filter(func(e): return Codex.seen(e.st)).is_empty(); Store.save.cleared = [1]
	var cx_one := Codex.ready() and cx_all.filter(func(e): return Codex.seen(e.st)).size() == 2 and Codex.seen(["3", "3-1", "3-2"]) == false
	Store.save.cleared = [7]; var cx_safari := Codex.seen(["3", "3-1", "3-2"]) and not Codex.seen(["3", "3-2"])
	Store.save = cx_keep; Store.settings.dev = cx_dev
	check("the book opens with the first clear, and each card with a stage it is in", cx_none and cx_one and cx_safari)
	# ---------------- the fight's screen and its effects ----------------
	var hud_m := {"game": gm, "player": pl, "enemies": en, "loot": lt, "guns": g, "state": "playing", "time": 0.0}
	var hud9 := Hud.new(); hud9.m = hud_m; gm.begin(1); pl.reset(0, 6, 0.0)
	hud9.hurt(30.0, Vector3(10, 0, 6)); var h_arc: float = hud9.arcs[0][0]; var h_t := hud9.hurt_t
	for i in 40: hud9.update(1.0 / 30.0)
	check("a hit: the red edge (0.2 + 1.2 % of the damage, at most 0.6 s) and an arc towards where it came from, gone after 1.2 s", absf(h_t - 0.56) < 1e-6 and h_arc == 1.2 and hud9.arcs[0][0] == 0.0, [h_t, h_arc])
	var h_none := hud9.aims(gm).size()
	for e in en.list.duplicate():
		if en.list.size() > 10 and not e.boss: en.vanish(e); gm.kills += 1
	var h_three := hud9.aims(gm).size(); gm.begin(4); for e in en.list.duplicate():
		if en.list.size() > 10: en.vanish(e); gm.kills += 1
	var h_ship := hud9.aims(gm).size()
	check("arrows: none while many are left, the nearest three once ten or fewer are, never on the ship", h_none == 0 and h_three == 3 and h_ship == 0, [h_none, h_three, h_ship])
	gm.begin(2); Snd.keep_log = true; Snd.played.clear(); gm.infected = true; gm.infect_t = 5.0
	for i in 60: hud9.update(1.0 / 30.0)
	var h_beats := Snd.played.filter(func(n): return n == "heart").size(); gm.infected = false; Snd.keep_log = false
	check("infected: a heartbeat (about every 1.05 s with 5 s to go)", h_beats == 2, h_beats)
	gm.begin(1); var h_thug = en.list.filter(func(e): return not e.boss)[0]; h_thug.lod = 0.0
	en.damage(h_thug, 10.0, h_thug.pos + Vector3(0, 1.3, 0), Vector3(0, 0, -1), false); var h_f: float = h_thug.flash_t
	en.update(0.02, 0.0); var h_on: String = h_thug.glow
	for i in 6: en.update(0.02, 0.0)
	check("a man hit glows orange for 0.08 s", h_f == 0.08 and h_on == "flash" and h_thug.glow == "" and (h_thug.g.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_overlay == null, [h_f, h_on, h_thug.glow])
	fxn.clear(); for i in 60: fxn.update(1.0 / 30.0)
	var h_n0: int = fxn._debris.size() + fxn.live(); fxn.chunks(Vector3(0, 1, 0), 9, 0.28, "wood"); fxn.sparks(Vector3(0, 1, 0), 4, [1.0, 0.8, 0.5], 2.5)
	var h_n1: int = fxn._debris.size() + fxn.live(); var h_low := 9.0
	for i in 150:
		fxn.update(1.0 / 30.0)
		for d in fxn._debris: h_low = minf(h_low, (d[0] as Node3D).position.y)
	check("splinters and sparks fly, bounce off the ground, and are gone (debris in 4 s at most)", h_n1 == h_n0 + 13 and fxn._debris.size() + fxn.live() == 0 and h_low > -0.01, [h_n0, h_n1, h_low])
	fxn.clear(); fxn.explode(Vector3(0, 2, 0), true); var h_ex := [fxn._glow.p.size(), fxn._smoke.p.size(), fxn._boom.visible]
	fxn.update(1.0 / 30.0); var h_drawn := [fxn._glow.shown, fxn._smoke.shown]
	for i in 3000: fxn.sparks(Vector3.ZERO, 1, [1.0, 1.0, 1.0], 1.0)
	for i in 400: fxn.puff(Vector3.ZERO, 1, 0.5, 0.3)
	var h_full := [fxn._glow.p.size(), fxn._smoke.p.size()]
	for i in 70: fxn.decal(Vector3(0, 1, 5), Vector3(0, 0, -1))
	var h_hole: Transform3D = fxn.hole_xf[0]
	for i in 20: fxn.update(1.0 / 30.0)
	check("a blast as the browser game's: 70 sparks and 14 balls of fire, 16 puffs of smoke, a light that dies in 0.35 s; the pools hold 900 and 260 specks at most",
		h_ex == [84, 16, true] and h_drawn == [84, 16] and h_full == [900, 260] and not fxn._boom.visible, [h_ex, h_drawn, h_full, fxn._boom.visible])
	check("bullet holes: the newest 64 stay, each lying flat on the wall it struck", fxn.hole_xf.size() == 64 and fxn._holes.get_surface_count() == 1 and h_hole.basis.z.normalized().dot(Vector3(0, 0, -1)) > 0.99 and h_hole.origin.distance_to(Vector3(0, 1, 4.98)) < 0.001,
		[fxn.hole_xf.size(), h_hole.basis.z.normalized(), h_hole.origin])
	g.shots = 40; g.hits = 12; gm.begin(1); gm.update(0.02)
	check("a new stage counts its shots and hits from nothing (the result's accuracy is that stage's alone)", g.shots == 0 and g.hits == 0 and gm.stats.shots == 0 and gm.stats.hits == 0, [g.shots, g.hits, gm.stats.shots])
	gm.begin(1); var h_old: MultiMesh = w.crate_mm; var h_cr: Dictionary = w.crates[0]
	w.damage_crate(h_cr, 9999.0, Vector3(h_cr.x, 0.6, h_cr.z))
	check("a broken crate leaves the picture: the crates are drawn from a new MultiMesh with that one at no size (on the web one changed in place kept showing it)",
		h_cr.dead and w.crate_mm != h_old and w.crate_mmi.multimesh == w.crate_mm and (w.crate_xf[h_cr.idx] as Transform3D).basis.get_scale().length() < 0.001 and w.crate_mm.instance_count == w.crate_xf.size(),
		[h_cr.dead, w.crate_mm != h_old, w.crate_xf.size()])
	gm.begin(1)
	# ---- E: the browser game's picture ----
	var e_fit := func(x: float) -> float: return (x * (x + 0.0245786) - 0.000090537) / (x * (0.983729 * x + 0.432951) + 0.238081)
	check("Godot's ACES draws three.js's curve: exposure e/0.6/1.8 and a white (14.26) at which Godot's divide-by-white is 1",
		absf(Gfx.exposure(1.15) * 1.8 - 1.15 / 0.6) < 1e-9 and absf(e_fit.call(Gfx.TONE_WHITE * 1.8) - 1.0) < 1e-3, e_fit.call(Gfx.TONE_WHITE * 1.8))
	var e_ramp := []; var e_ok := true
	for q: Array in [[0.035, 41.1], [0.2, 145.4], [0.5, 204.2], [1.0, 230.4]]:
		var dv := Gfx.display(Vector3(q[0], q[0], q[0]), 1.15).x * 255.0; e_ramp.push_back(snappedf(dv, 0.1)); e_ok = e_ok and absf(dv - float(q[1])) < 0.6
	check("the display curve gives the browser game's grey ramp (0.035, 0.2, 0.5, 1.0 -> 41, 145, 204, 230 of 255)", e_ok, e_ramp)
	var e_f := Vector3(0.026, 0.033, 0.052); var e_l := Gfx.scene_for(e_f, 1.15); var e_back := Gfx.display(e_l, 1.15)
	check("the fog: the scene colour mixed in by the fog layer tone maps back to the browser game's fog colour (it mixed fog in after tone mapping)",
		e_back.distance_to(e_f) < 1e-5 and w.fog_mat.get_shader_parameter("density") == 0.016, [e_back, w.fog_mat.get_shader_parameter("density")])
	var e_al := Gfx.albedo_of(Vector3(0.01, 0.2, 0.8)); var e_dec := func(v: float) -> float: return v * (v * (v * 0.305306011 + 0.682171111) + 0.012522878)
	check("colours sent to a shader come back through the compatibility renderer's sRGB decode as asked",
		absf(e_dec.call(e_al.x) - 0.01) < 1e-6 and absf(e_dec.call(e_al.y) - 0.2) < 1e-6 and absf(e_dec.call(e_al.z) - 0.8) < 1e-6)
	check("the exposures are the browser game's (3-1 0.82, lab 1.08, night lab 1.02, ship 1.12, others 1.15)",
		World.STAGE_STYLE[7].exposure == 0.82 and World.STAGE_STYLE[3].exposure == 1.08 and World.STAGE_STYLE[8].exposure == 1.02 and World.STAGE_STYLE[4].exposure == 1.12 and not World.STAGE_STYLE[1].has("exposure"))
	var e_worst := 0.0
	for d in [6.0, 10.0, 15.2, 20.0, 24.0]:
		var nd := pow(d / World.LAMP_RANGE, 4.0); var godot := World.LAMP_K * pow(maxf(1.0 - nd, 0.0), 2.0) * pow(d, -World.LAMP_ATTEN)
		e_worst = maxf(e_worst, absf(godot - pow(1.0 - d / 30.0, 2.0)))
	check("a lamp falls off as three.js's point light (1 - d/30)^2 within 0.035 from 6 to 24 m", e_worst < 0.035, snappedf(e_worst, 0.0001))
	check("the moon lights in the main pass (a shadowed light gets a pass of its own, tone mapped alone); its shadow comes from the shadow picture; moon and lamps gloss as three.js's (1.0 directional, 0.5 point)",
		not w.moon.shadow_enabled and w.shadow_layer.visible and w.moon_shadow.render_target_update_mode == SubViewport.UPDATE_ALWAYS and absf(w.moon.light_specular - 1.0) < 1e-6 and absf((w.lights[0] as OmniLight3D).light_specular - 0.5) < 1e-6,
		[w.moon.shadow_enabled, w.shadow_layer.visible, w.moon_shadow.render_target_update_mode, w.moon.light_specular])
	w.moon_shadow.place(10.3, -5.7, [-30, 50, -20]); var e_tx := MoonShadow.BOX / w.moon_shadow.size.x; var e_cp := w.moon_shadow.cam.global_position
	check("the shadow box as the browser game's: 80 m across, near 1, far 160, on the player and snapped to its texels",
		w.moon_shadow.cam.size == 80.0 and w.moon_shadow.cam.near == 1.0 and w.moon_shadow.cam.far == 160.0 and e_cp.distance_to(Vector3(roundf(10.3 / e_tx) * e_tx - 30, 50, roundf(-5.7 / e_tx) * e_tx - 20)) < 1e-4, e_cp)
	var e_cast := 0; var e_cont := 0; var e_ground_casts := false
	for n in w.group.get_children():
		if n is VisualInstance3D and (n as VisualInstance3D).get_layer_mask_value(MoonShadow.CASTER): e_cast += 1
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh.mesh.get_surface_count() == 3: e_cont += 1 if (n as VisualInstance3D).get_layer_mask_value(MoonShadow.CASTER) else -1000
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh and ((n as MeshInstance3D).mesh as PlaneMesh).size.x >= 240: e_ground_casts = (n as VisualInstance3D).get_layer_mask_value(MoonShadow.CASTER)
	check("what casts the moon's shadow is what the browser game marks: containers, crates, cranes, poles, barriers, not the ground", e_cont > 0 and e_cast >= e_cont + 4 and not e_ground_casts, [e_cast, e_cont])
	var e_box := Gfx.box(Vector3(2, 3, 4)); var e_uv: PackedVector2Array = e_box.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]; var e_uvok := e_uv.size() == 24
	for i in e_uv.size(): e_uvok = e_uvok and e_uv[i] == [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)][i % 4]
	check("a textured box shows the whole picture on every face, as three.js's BoxGeometry (Godot's BoxMesh shows a sixth)", e_uvok)
	var e_side: Image = Gfx.side_tex(Color("8c3a2b"), Store.iso_code("BNK", 382794), "BNK", true).get_image(); var e_ink := 0; var e_mark := 0
	for y in range(14, 44):
		for x in range(330, 500): var e_c := e_side.get_pixel(x, y); e_ink += 1 if e_c.r > 0.75 and e_c.g > 0.75 else 0
	for y in range(56, 92):
		for x in range(18, 110): var e_c := e_side.get_pixel(x, y); e_mark += 1 if e_c.g > 0.5 and e_c.b > 0.45 else 0
	check("a container's side carries its ISO code, size-type code and owner's mark, as the browser game paints them", e_ink > 150 and e_mark > 150, [e_ink, e_mark])
	var e_labels := w.group.find_children("*", "Label3D", true, false).size(); var e_07 := false
	for n in w.group.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh and ((n as MeshInstance3D).mesh as PlaneMesh).size == Vector2(10, 5) and (n as Node3D).position.distance_to(Vector3(0, 0.014, 1)) < 1e-4: e_07 = true
	check("the yard's 07 is paint on the ground, lit like it (10 x 5 m at the start), not a floating label", e_07 and e_labels == 0)
	Fx.exposure = 1.15; var e_sc := Fx.shown(Color(1.0, 0.55, 0.2, 0.7)); var e_sd := Gfx.display(Vector3(e_dec.call(e_sc.r), e_dec.call(e_sc.g), e_dec.call(e_sc.b)), 1.15)
	check("specks show on screen the colour asked for (the browser game writes theirs with no tone mapping)", e_sd.distance_to(Vector3(0.97, 0.55, 0.2)) < 0.004 and absf(e_sc.a - 0.7) < 1e-6, e_sd)
	w.set_ao(false); var e_off := not w.ao_layer.visible and w.ao.render_target_update_mode == SubViewport.UPDATE_DISABLED; w.set_ao(true)
	check("the computer's ambient occlusion can be switched off (phones and stage 5 go without)", e_off and w.ao_layer.visible)
	w.gfx_fixed = false; w.gfx_level = 4; w.use_ao = true; w.set_ao(true)
	for i in 81: w.govern(1.0 / 40.0)   # two seconds at 40 a second: one step down, the occlusion stays
	var e_l1 := [w.gfx_level, w.ao_layer.visible]
	for i in 81: w.govern(1.0 / 40.0)   # another: level 2, the occlusion goes
	var e_l2 := [w.gfx_level, w.ao_layer.visible]
	for i in 3 * 121: w.govern(1.0 / 60.0)   # three good spells: back up to 3, the occlusion returns
	var e_l3 := [w.gfx_level, w.ao_layer.visible]
	check("the occlusion follows the browser game's quality ladder: down a step per sagging two seconds, gone below level 3, back after three good spells",
		e_l1 == [3, true] and e_l2 == [2, false] and e_l3[1] == true and int(e_l3[0]) >= 3, [e_l1, e_l2, e_l3])
	w.gfx_level = 4; w.use_ao = true; w.set_ao(true)
	var e_gr := Grade.new(); add_child(e_gr); e_gr.tune(World.STAGE_STYLE[9]); var e_toy := e_gr.visible; e_gr.tune(World.STAGE_STYLE[1]); var e_yard := e_gr.visible
	e_gr.allowed = false; e_gr.tune(World.STAGE_STYLE[1]); var e_phone := e_gr.visible; e_gr.queue_free()
	check("the finishing pass: on a computer in the browser game's stages, never in stage 5 (this port's own room keeps its light) nor on phones", not e_toy and e_yard and not e_phone, [e_toy, e_yard, e_phone])
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)
