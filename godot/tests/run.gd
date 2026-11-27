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
	Cloud.mute()   # (whoever is signed in on this machine: the checks' saves go to no account)
	Store.settings.dev = false; Store.settings.god = false; Store.settings.gfx = "auto"; Store.settings.toyMode = "sweep"   # (whatever this machine kept from playing: the checks start from a fresh player's settings)
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
	var price_now := {"rocket": [150000, 45000]}   # [price, rental] set by the owner of this port; the browser game's is [300000, 90000]
	for id in ref.weapons:
		var a: Dictionary = ref.weapons[id]; var b: Dictionary = Weapons.LIST.get(id, {})
		for k in a:
			if k == "rent" or k == "noise" or k == "parts": continue   # set while playing by the attachments (stage 6 of the port)
			if k == "adsSpeed" and not b.has(k): b = b.merged({"adsSpeed": 7})
			var av = a[k]; var bv = b.get(k)
			if k == "reserve" and str(av) == "inf": av = INF
			if k == "price" and price_now.has(id): av = price_now[id][0]
			var same := false
			if av is Array: same = bv is Array and av.size() == bv.size() and absf(av[0] - bv[0]) < 1e-9 and absf(av[1] - bv[1]) < 1e-9
			elif av is float or av is int: same = (bv is float or bv is int) and (av == bv or absf(av - bv) < 1e-9)
			else: same = av == bv
			if not same: nbad += 1; which += " %s.%s" % [id, k]
		if Weapons.rent(id) != (int(price_now[id][1]) if price_now.has(id) else int(a.rent)): nbad += 1; which += " %s.rent" % id
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
	check("all income is twice the browser game's (the owner's rule): the boss's pay on the briefing is what it really pays, 20,000 doubled",
		Store.PAY == 2 and gm.boss_msg.ends_with(Store.won(40000)) and Game.boss_pay(Game.BOSS[3]) == 2500 * 20 * 2 and Game.boss_pay(Game.BOSS[4]) == 2000 * 20 * 2, gm.boss_msg)
	# hits: body 34, head 85; three body shots or two head shots kill a man (100)
	var t0 = ft; var hd: Vector3 = en.part_centre(t0, t0.parts[0]); var bd: Vector3 = en.part_centre(t0, t0.parts[1])
	var rh = en.raycast(hd + Vector3(0, 0, 5), Vector3(0, 0, -1), 20.0); var rb = en.raycast(bd + Vector3(0, 0, 5), Vector3(0, 0, -1), 20.0)
	check("a ray at the head finds the head, a ray at the chest the body", rh != null and rh.enemy == t0 and rh.weak and rb != null and rb.enemy == t0 and not rb.weak and rb.mult == 1.0)
	var money0: int = Store.save.money
	en.damage(t0, 34, bd, Vector3(0, 0, -1), false); en.damage(t0, 34, bd, Vector3(0, 0, -1), false)
	check("two body shots leave him standing, and he is awake now", t0.alive and t0.hp == 32.0 and t0.alert)
	check("the third kills him and pays 1,000, doubled", en.damage(t0, 34, bd, Vector3(0, 0, -1), false) and not t0.alive and Store.save.money == money0 + 1000 * Store.PAY and gm.kills == 1)
	var t1 = en.list[2]
	en.damage(t1, 85, hd, Vector3(0, 0, -1), true); en.damage(t1, 85, hd, Vector3(0, 0, -1), true)
	check("a kill by a shot to the head pays 1,500, doubled", not t1.alive and Store.save.money == money0 + 2500 * Store.PAY and gm.stats.heads == 1)
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
	check("99 down: 99,000 doubled in the bag, the boss still to go", gm.kills == 99 and Store.save.money == 99000 * Store.PAY and not gm.ended)
	var bp: Vector3 = bossy.pos
	en.damage(bossy, 5000, bossy.pos, Vector3(0, 0, -1), false)
	check("the boss pays 20,000 doubled and leaves a chest; the stage waits for it", Store.save.money == 119000 * Store.PAY and lt.chests.size() == 1 and not gm.ended)
	pl.pos = Vector3(bp.x, 0, bp.z + 1.0); sim.call(0.2)
	check("opening the chest gives a gun for good and ends the stage", Store.save.owned.size() == 1 and gm.ended and gm.result == "clear")
	sim.call(2.0)
	check("cleared: recorded, best time kept, money and gun stay, 2 and 1-1 offered next", shown == ["clear"] and Store.save.cleared == [1] and Store.save.best.has("t1") and Store.save.money == 119000 * Store.PAY and Store.save.owned.size() == 1 \
		and Store.next_stages(1) == [2, 6], str(Store.next_stages(1)))
	var keep_save: Dictionary = Store.save; var keep_dev: bool = Store.settings.dev; Store.save = Store.save0(); Store.settings.dev = false
	var ul_open := Store.STAGE_ORDER.filter(func(s): return Store.stage_open(s))
	Store.save.cleared = [1]; var ul_1 := [Store.stage_open(6), Store.stage_open(5)]; Store.save.cleared = [1, 6]; ul_1.push_back(Store.stage_open(5))
	Store.save.cleared = [3]; var ul_3 := [Store.stage_open(7), Store.stage_open(8)]; Store.save.cleared = [3, 7]; ul_3.push_back(Store.stage_open(8))
	Store.save.cleared = [5, 8]; var ul_kept := [Store.stage_open(5), Store.stage_open(8), Store.stage_open(6), Store.stage_open(7)]; Store.save.cleared = []
	check("the five main stages (1 to 5) are open from the start; a side stage opens when the one before it is cleared (1-1 after 1, 1-2 after 1-1, 3-1 after 3, 3-2 after 3-1), and a stage once cleared stays open",
		Store.STAGE_ORDER.size() == 9 and ul_open == [1, 2, 3, 4, 9] and ul_1 == [true, false, true] and ul_3 == [true, false, true] and ul_kept == [true, true, false, false] and not Store.stage_open(10), [ul_open, ul_1, ul_3, ul_kept])
	Store.save = keep_save; Store.settings.dev = keep_dev
	gm.begin(1); en.damage(en.list[3], 1000, en.list[3].pos, Vector3(0, 0, -1), false)
	check("a stage played again pays nothing", gm.replay and Store.save.money == 119000 * Store.PAY)
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
	# the weapon order, in the menu or the middle of a stage: a gun swaps with the next gun before or after it in your hands
	var wo_keep: Array = Store.save.loadout.duplicate(); Store.save.loadout = ["pistol", "gl", null, "smg", null, null, null]
	var wo_moves := [Meta.move_gun("smg", -1), Meta.move_gun("pistol", -1), Meta.move_gun("smg", -1)]; var wo_a: Array = Store.save.loadout.duplicate()
	Meta.swap_slots(3, 2); var wo_b: Array = Store.save.loadout.duplicate(); Meta.swap_slots(0, -1)
	check("the weapon order: a gun moves ahead of the gun before it (the empty slots stay put), not past the first; the loadout screen swaps neighbouring slots",
		wo_moves == [true, false, true] and wo_a == ["smg", "pistol", null, "gl", null, null, null] and wo_b == ["smg", "pistol", "gl", null, null, null, null] and Store.save.loadout == wo_b, [wo_moves, wo_a, wo_b])
	Store.save.loadout = wo_keep
	line = Meta.cancel_rent("smg")
	check("cancelling a rental gives the fee back", Store.save.money == 79000 and not Store.save.rented.has("smg") and not Meta.fits(2))
	Meta.buy_item("helmet"); Meta.buy_item("vest")
	check("items: a helmet (1,000) and a vest (5,000, ten blocks)", Store.save.money == 73000 and Store.save.items.helmet == 1 and Store.save.items.vest == 10 and Meta.item_state("vest") == "착용 중 · 내구 10/10" and Meta.buy_item("helmet").contains("이미"))
	Store.save.items.ivory = 3
	check("ivory sells for 50,000 a piece, doubled", Meta.sell_ivory(2).contains("+200,000원") and Store.save.money == 273000 and Store.save.items.ivory == 1 and Meta.ivory_price() == 100000)
	# the shop: what the stage's recommended kit still lacks is filled amber, up top and again in the lists below (the owner's rule)
	var sh_keep: Dictionary = Store.save; Store.save = Store.save0()
	var sh_ui := Ui.new(); add_child(sh_ui); sh_ui._build_shop(); sh_ui.shop_ctx = 3; sh_ui.render_shop()
	var sh_rec := 0; var sh_plain := 0; var sh_ok := true
	for c9 in sh_ui.shop_list.get_children():
		if not (c9 is PanelContainer) or not c9.has_meta("rec"): continue
		var sb9: StyleBoxFlat = (c9 as PanelContainer).get_theme_stylebox("panel")
		if bool(c9.get_meta("rec")): sh_rec += 1; sh_ok = sh_ok and sb9.bg_color == Ui.REC_FILL
		else: sh_plain += 1; sh_ok = sh_ok and sb9.bg_color != Ui.REC_FILL
	var sh_miss: Array = Meta.missing(3)
	check("the shop: the guns and items stage 3's recommended kit lacks are filled amber, up top and again in the lists below; the rest as ever",
		sh_miss.size() == 8 and sh_rec == 2 * sh_miss.size() and sh_plain > 0 and sh_ok, [sh_rec, sh_plain, sh_miss])
	sh_ui.queue_free(); Store.save = sh_keep
	check("the guided rocket launcher rents for 45,000 (half the browser game's 90,000)", Weapons.rent("rocket") == 45000 and Weapons.LIST.rocket.price == 150000)
	Store.settings.dev = true
	var dv_cl: Array = Store.save.cleared.duplicate(); Store.save.cleared = []
	check("developer mode: every stage open (the side stages too, nothing cleared), every gun free to carry", Store.STAGE_ORDER.all(func(s9): return Store.stage_open(s9)) and Store.gun_available("rocket"))
	Store.settings.god = true; var dv_chips: Array = Hud.new()._items(false); Store.settings.god = false; var dv_off: Array = Hud.new()._items(false)
	check("developer mode's invincibility is shown on the screen while it is on", dv_chips.size() > 0 and dv_chips[0][0] == "무적 · 개발자 모드" and not dv_off.any(func(c): return c[0] == "무적 · 개발자 모드"), [dv_chips, dv_off])
	Store.save.cleared = dv_cl
	Store.settings.dev = false
	# rentals go back when a stage you went into ends; a briefing left, or the app started again, keeps them for the next (as the browser game's)
	Store.save.loadout = ["pistol", "gl", null, null, null, null, null]; gm.begin(1); gm.return_rentals()
	var rt_brief: bool = Store.save.rented == ["gl"]
	var rt_app := Game.new(); rt_app.return_rentals(); var rt_start: bool = Store.save.rented == ["gl"]   # (a fresh game, as when the app starts)
	check("a rental is kept when you leave the briefing (or the back button) and when the app starts again: it is for the next stage you go into", rt_brief and rt_start and not gm.deployed, Store.save.rented)
	gm.deployed = true   # (출동: into the stage)
	check("a rented gun is in your hands for the stage", g.slots == ["pistol", "gl"])
	pl.invuln = 0.0; pl.hp = 1.0; pl.hurt(50, Vector3.ZERO); sim.call(1.2)
	check("and goes back when the stage ends", Store.save.rented.is_empty() and gm.layout() == ["pistol", null, null, null, null, null, null])
	# an elephant's ivory, as the browser game's: one for each elephant killed for pay (a first clear), none on a replay
	var iv_cl: Array = Store.save.cleared.duplicate(); Store.save.cleared = []; Store.save.items.ivory = 0; gm.begin(7)
	var iv_el: Array = en.list.filter(func(e): return e.alive and e.type == "elephant")
	if not iv_el.is_empty(): en.damage(iv_el[0], 1e6, iv_el[0].pos, Vector3(0, 0, 1), false)
	var iv1 := int(Store.save.items.ivory)
	Store.save.cleared = [7]; gm.begin(7); var iv_el2: Array = en.list.filter(func(e): return e.alive and e.type == "elephant")
	if not iv_el2.is_empty(): en.damage(iv_el2[0], 1e6, iv_el2[0].pos, Vector3(0, 0, 1), false)
	check("an elephant killed leaves its ivory, one to sell at the shop (100,000원); none on a replay", iv_el.size() > 0 and iv1 == 1 and int(Store.save.items.ivory) == 1, [iv_el.size(), iv1, Store.save.items.ivory])
	Store.save.cleared = iv_cl; Store.save.items.ivory = 0; Store.ivory_lock = null
	# ---------------- stages 1-1 and 1-2 ----------------
	for stn in [6, 5, 2, 3, 7, 4, 8]:
		var R9: Dictionary = ref.stages[str(stn)]; Store.save = Store.save0(); gm.begin(stn)
		var cb := 0
		for i in mini(60, Phys.colliders.size()):
			var b9 = Phys.colliders[i]; var q9: Array = R9.first[i]
			if absf(b9.minx - q9[0]) > 2e-6 or absf(b9.minz - q9[1]) > 2e-6 or absf(b9.maxy - q9[2]) > 2e-6: cb += 1
		# (stage 2: the browser game's crates out in the village are gone, the antidotes are indoors; put back for a moment, the yard is the browser game's)
		var gh9: Array = w.village.ghost_at if stn == 2 else []; var ghb9: Array = []
		for gp9: Vector2 in gh9: ghb9.push_back(Phys.add_collider(gp9.x - 0.6, 0, gp9.y - 0.6, gp9.x + 0.6, 1.2, gp9.y + 0.6, "wood"))
		if not ghb9.is_empty(): Phys.build_nav()
		var nb := 0; var nh := 0; var ncol9 := Phys.colliders.size()
		for i in Phys.nav_blocked.size():
			if Phys.nav_blocked[i] != 0: nb += 1; nh = (nh * 31 + i) % 1000000007
		for b9 in ghb9: Phys.remove_collider(b9)
		if not ghb9.is_empty(): Phys.build_nav()
		check("stage %s: the docks are laid out as in the browser game" % Store.STAGE_TAG[stn], ncol9 == int(R9.colliders) and cb == 0 and nb == int(R9.navBlocked) and nh == int(R9.navHash) and w.crates.size() + gh9.size() == R9.crates.size(), "%d colliders" % ncol9)
		# (stages 3, 3-1 and 3-2: the lions are fewer and bigger, the owner's rule: the lab keeps six of its twelve in a checkerboard, the savanna every other of its fourteen)
		var E9: Array = R9.enemies
		if stn == 3 or stn == 7 or stn == 8:
			var lion0: int = 73 if stn == 7 else 75; var keep9: Array = [0, 2, 4, 6, 8, 10, 12] if stn == 7 else [0, 2, 5, 7, 8, 10]; E9 = []
			for i in R9.enemies.size():
				var q9: Array = (R9.enemies[i] as Array).duplicate()
				if q9[7] == "lionM":
					if not keep9.has(i - lion0): continue
					q9[5] = 340.0 * Lab.LION_SCALE
				E9.push_back(q9)
			var lz9: Array = en.list.filter(func(e): return e.type == "lionM")
			check("stage %s: the lions are fewer and bigger: %d of the browser game's %d, half as big again and as tough" % [Store.STAGE_TAG[stn], keep9.size(), 14 if stn == 7 else 12],
				lz9.size() == keep9.size() and lz9.all(func(e): return absf(e.scale - Lab.LION_SCALE) < 1e-6 and e.max_hp == 340.0 * Lab.LION_SCALE and e.hp == e.max_hp), lz9.size())
		var eb := 0; var efirst := ""
		for i in mini(en.list.size(), E9.size()):
			var e9 = en.list[i]; var q9: Array = E9[i]
			var moved9: bool = (stn == 3 or stn == 8) and (absf(e9.pos.x - q9[0]) > 11.0 or absf(e9.pos.z - q9[1]) > 11.0)   # the lab's animals had paced about their cages by the time they were written down
			var still9: bool = stn != 3 and stn != 8 and (stn != 4 or e9.type in ["cctv", "mine", "gdrone", "bdrone"])   # the ship's patrols and drones had moved off by the time they were written down
			if (still9 and (absf(e9.pos.x - q9[0]) > 1e-4 or absf(e9.pos.z - q9[1]) > 1e-4)) or moved9 or e9.type != q9[7] or (absf(e9.pos.y - q9[2]) > 1e-3 and (stn != 4 or e9.type == "mine")) or e9.kit != q9[3] or (1 if e9.boss else 0) != int(q9[4]) or e9.max_hp != q9[5] or (1 if e9.helmet else 0) != int(q9[6]):
				eb += 1
				if efirst == "": efirst = "#%d %s %s vs %s" % [i, str(e9.pos), e9.kit, str(q9)]
		check("stage %s: all 100 stand where the browser game puts them, with the same weapons" % Store.STAGE_TAG[stn], en.list.size() == E9.size() and eb == 0 and gm.goal == int(R9.goal) - (R9.enemies.size() - E9.size()), efirst)
		var cb9 := 0
		for i in mini(w.crates.size(), R9.crates.size()):
			if absf(w.crates[i].x - R9.crates[i][0]) > 1e-4 or absf(w.crates[i].z - R9.crates[i][1]) > 1e-4: cb9 += 1
		for j in gh9.size():   # (stage 2: where the ones out in the village would be)
			var gq9: Array = R9.crates[w.crates.size() + j]
			if absf(gh9[j].x - gq9[0]) > 1e-4 or absf(gh9[j].y - gq9[1]) > 1e-4: cb9 += 1
		check("stage %s: every crate is where the browser game has it" % Store.STAGE_TAG[stn], cb9 == 0, cb9)
		if stn == 5:   # 1-2 puts you down in the bottom right corner of the map (the owner's choice); the enemies are as there
			check("stage 1-2: you start in the corner at the bottom right of the map, not at the browser game's south edge", w.start.x > 54.0 and w.start.z > 54.0 and Vector2(R9.start[0], R9.start[1]).distance_to(Vector2(w.start.x, w.start.z)) > 40.0, w.start)
		else: check("stage %s: you start where the browser game starts you" % Store.STAGE_TAG[stn], absf(w.start.x - R9.start[0]) < 1e-4 and absf(w.start.z - R9.start[1]) < 1e-4 and absf(w.start.yaw - R9.start[2]) < 1e-4, w.start)
	# ---------------- stage 2: the burning village ----------------
	gm.begin(2); var s2_V2: Dictionary = ref.stages["2"]
	var s2_cbad := 0
	for i in mini(w.crates.size(), s2_V2.crates.size()):
		if absf(w.crates[i].x - s2_V2.crates[i][0]) > 1e-4 or absf(w.crates[i].z - s2_V2.crates[i][1]) > 1e-4: s2_cbad += 1
	var s2_out := 0
	for cr2 in w.crates:
		var in2 := false
		for h2 in w.village.huts:
			var dx2: float = cr2.x - h2.x; var dz2: float = cr2.z - h2.z; var c2 := cos(float(h2.yaw)); var sn2 := sin(float(h2.yaw))
			if absf(dx2 * c2 - dz2 * sn2) < float(h2.W) / 2 and absf(dx2 * sn2 + dz2 * c2) < float(h2.D) / 2: in2 = true
		if not in2: s2_out += 1
	check("stage 2: 15 huts, two crates in every one and none out in the village (the antidotes are indoors: the owner's rule), each where the browser game has it",
		w.village.huts.size() == int(s2_V2.huts) and s2_cbad == 0 and w.crates.size() == 2 * w.village.huts.size() and s2_out == 0 and w.village.ghosts.is_empty() and w.village.ghost_at.size() == s2_V2.crates.size() - w.crates.size(),
		"%d huts %d crates %d off %d outside" % [w.village.huts.size(), w.crates.size(), s2_cbad, s2_out])
	check("stage 2: the crates out in the village leave no wall behind them", w.village.ghost_at.all(func(gp: Vector2): return Phys.collide_at(gp.x, 0.05, gp.y, 0.3, 1.0) == null))
	check("stage 2: zombies, one giant among them", en.list.all(func(e): return e.type == "zombie") and gm.boss != null and gm.boss.max_hp == 2200.0 and gm.boss.scale == 1.7 and en.list[1].max_hp == 180.0 and gm.antidotes == 1)
	check("stage 2: a zombie stoops from the moment it is put down, asleep or not (the browser game's spawn: 0.28 forward)", en.list.all(func(z9): return absf(z9.upper.rotation.x - 0.28) < 1e-6))
	# people, animals, robots and loot take no moon shadow, as in the browser game: their solid materials mark the stencil
	var s2_probe := MeshInstance3D.new(); s2_probe.mesh = BoxMesh.new(); var s2_pm := StandardMaterial3D.new(); s2_probe.material_override = s2_pm; en.add_child(s2_probe)
	var s2_glass := MeshInstance3D.new(); s2_glass.mesh = BoxMesh.new(); var s2_gm9 := StandardMaterial3D.new(); s2_gm9.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; s2_glass.material_override = s2_gm9; en.add_child(s2_glass)
	var s2_roots: Array = w.caster_roots; w.caster_roots = [en]   # (as the game sets them: what is under the enemies)
	w._flush_fresh(); w.caster_roots = s2_roots
	check("people, animals and robots take no moon shadow: their solid materials write the stencil the shadow layer passes by (see-through ones do not)",
		s2_pm.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and s2_pm.stencil_reference == MoonShadow.UNSHADOWED and (s2_pm.stencil_flags & BaseMaterial3D.STENCIL_FLAG_WRITE) != 0
		and s2_gm9.stencil_mode == BaseMaterial3D.STENCIL_MODE_DISABLED and MoonShadow.LAYER_SHADER.contains("stencil_mode read, compare_greater, %d;" % MoonShadow.UNSHADOWED)
		and MoonShadow.GRASS > MoonShadow.UNSHADOWED)   # (the layer draws only where the mark is below 2: neither people's 2 nor the savanna grass's 3)
	s2_probe.queue_free(); s2_glass.queue_free()
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
	check("stage 2: shot again on the ground it is gone, and one that had got up pays 1,000, doubled", not s2_z1.alive and gm.kills == 1 and Store.save.money == s2_m0 + 1000 * Store.PAY, Store.save.money - s2_m0)
	var s2_z2 = en.list[5]; s2_m0 = Store.save.money
	en.damage(s2_z2, 500, s2_z2.pos, s2_zdir, true); en.damage(s2_z2, 1, s2_z2.pos, s2_zdir, true)
	check("stage 2: finished before it ever rose, with a shot to the head: 1,000 x 1.5 x 1.5, doubled", Store.save.money == s2_m0 + 2250 * Store.PAY, Store.save.money - s2_m0)
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
	# zombies hear gunfire half as far again as anyone (the owner's rule)
	gm.begin(2); pl.invuln = 1e9
	var s2_ea = en.list[9]; var s2_ea0: bool = s2_ea.alert; var s2_np: Vector3 = s2_ea.pos + Vector3(13.0, 0, 0)
	en.noise(s2_np, 10.0); var s2_heard: bool = s2_ea.alert
	var s2_eb = null
	for z9 in en.list:
		if not z9.alert and Vector2(z9.pos.x - s2_np.x, z9.pos.z - s2_np.z).length() > 16.0 and not z9.boss: s2_eb = z9; break
	en.noise(s2_eb.pos + Vector3(16.0, 0, 0), 10.0)
	check("stage 2: zombies hear a shot half as far again as anyone: 13 m off a 10 m shot one comes, 16 m off one sleeps on", Enemies.ZOMBIE_EAR == 1.5 and not s2_ea0 and s2_heard and not s2_eb.alert, [s2_ea0, s2_heard])
	# stage 2's looks, as the browser game's village
	check("stage 2: no harbour behind the village (skyline, water, the ship), no blinking mast, and a bigger moon (92 to the docks' 62)",
		w._port.size() == 8 and w._port.all(func(n9): return not n9.visible) and w.blink.is_empty() and (w.moon_spr.mesh as QuadMesh).size == Vector2(92, 92))
	var s2_ground: MeshInstance3D = null; var s2_sil: MultiMeshInstance3D = null; var s2_crowns: MeshInstance3D = null; var s2_cards := {}
	for n9 in w.group.get_children():
		if n9 is MeshInstance3D and (n9 as MeshInstance3D).mesh is PlaneMesh and ((n9 as MeshInstance3D).mesh as PlaneMesh).size == Vector2(260, 260): s2_ground = n9
		if n9 is MultiMeshInstance3D and (n9 as MultiMeshInstance3D).multimesh.instance_count == 170: s2_sil = n9
		if n9 is MeshInstance3D and n9.name == "Crowns": s2_crowns = n9
		if n9 is MeshInstance3D and (n9 as MeshInstance3D).material_override is ShaderMaterial and w.fire_mats.has((n9 as MeshInstance3D).material_override): s2_cards[(n9 as MeshInstance3D).material_override] = n9
	var s2_gm: StandardMaterial3D = s2_ground.material_override if s2_ground else null
	check("stage 2: the ground is the browser game's earth-and-grass picture, 24 times each way, roughness 1",
		s2_gm != null and s2_gm.albedo_texture != null and s2_gm.uv1_scale == Vector3(24, 24, 1) and s2_gm.roughness == 1.0)
	var s2_sm: StandardMaterial3D = s2_sil.material_override if s2_sil else null
	check("stage 2: the black forest on the horizon takes no fog (drawn after the fog layer)", s2_sm != null and s2_sm.render_priority == Gfx.PRIO_BACKDROP and s2_sm.disable_fog)
	var s2_cab: AABB = Village.crown_mesh().get_aabb(); var s2_cc: Array = w.village.crown_colors; var s2_hsl_ok := s2_cc.size() == 95 + 150
	for cc9: Color in s2_cc:
		var mx := maxf(cc9.r, maxf(cc9.g, cc9.b)); var mn := minf(cc9.r, minf(cc9.g, cc9.b)); var ll := (mx + mn) / 2.0
		if absf((mx - mn) / (1.0 - absf(2.0 * ll - 1.0)) - 0.35) > 0.002 or ll < 0.0899 or ll > 0.1401 or cc9.g <= cc9.r: s2_hsl_ok = false
	check("stage 2: a pine's crown is three cones stacked (0.11 to 1.10 of its height), green as the browser game's (HSL: saturation 0.35, lightness 0.09 to 0.14)",
		absf(s2_cab.position.y - 0.11) < 1e-3 and absf(s2_cab.end.y - 1.10) < 1e-3 and absf(s2_cab.size.x - 1.95) < 0.01 and s2_hsl_ok, [s2_cab, s2_hsl_ok])
	var s2_cn: PackedVector3Array = s2_crowns.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] if s2_crowns else PackedVector3Array(); var s2_upn := 0
	for nn9 in s2_cn: if nn9.y > 0.9: s2_upn += 1
	check("stage 2: the crowns, stretched tall, light as three.js lights them (their slopes face out, not up at the sky)",
		s2_crowns != null and s2_cn.size() > 0 and s2_upn == 0 and (s2_crowns.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray).size() == s2_cn.size(), s2_upn)
	var s2_want := [0, 0, 0]
	for f9 in w.village.fires: s2_want[0] += roundi(5 + f9[3] * 5); s2_want[1] += roundi(4 + f9[3] * 4); s2_want[2] += roundi(6 + f9[3] * 8)
	var s2_fire_ok := w.fire_mats.size() == 3 and s2_cards.size() == 3
	if s2_fire_ok:
		for k9 in 3:
			var fm9: ShaderMaterial = w.fire_mats[k9]; var verts: int = ((s2_cards[fm9] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var want9: Array = [[9.0, 6.5, 2.2, "blend_mix", 2], [0.0, 1.0, 0.0, "blend_add", 3], [5.0, 2.2, 1.4, "blend_add", 4]][k9]
			if verts != s2_want[k9] * 4 or absf(fm9.get_shader_parameter("rise") - want9[0]) > 1e-6 or absf(fm9.get_shader_parameter("life") - want9[1]) > 1e-6 or absf(fm9.get_shader_parameter("spread") - want9[2]) > 1e-6 \
					or not fm9.shader.code.contains(want9[3]) or fm9.render_priority != want9[4] or absf(fm9.get_shader_parameter("fogD") - 0.019) > 1e-6: s2_fire_ok = false
	check("stage 2: each fire is the browser game's cards: smoke (5 + 5p, rising 9 m over 6.5 s), flames (4 + 4p, added light), embers (6 + 8p, rising 5 m over 2.2 s)", s2_fire_ok, s2_want)
	gm.begin(1)
	check("stage 1: the harbour is back behind the yard, the mast blinks, the moon is the docks' size", w._port.all(func(n9): return n9.visible) and not w.blink.is_empty() and (w.moon_spr.mesh as QuadMesh).size == Vector2(62, 62) and w.fire_mats.is_empty())
	# ---------------- stage 3: the lab ----------------
	gm.begin(3); var lab: Lab = w.lab; var an: Animals = en.animals; pl.invuln = 0.0
	check("stage 3: 84 animals in ten cages (six big lions where the browser game has twelve), the giant gorilla in the last", en.list.size() == 84 and gm.goal == 84 and lab.cages[7].animals.size() == 6 and gm.boss != null and gm.boss.max_hp == 5200.0 and gm.boss.scale == 3.0 and lab.cages[5].animals.size() == 3 and lab.cages[8].animals.size() == 2)
	var zb3 = lab.cages[0].animals[0]; var gb3 = lab.cages[9].animals[0]
	# the lab as the browser game draws it
	var l3_tex := {}   # what each lab picture is put on
	for n9 in w.group.find_children("*", "MeshInstance3D", true, false):
		var m9 = (n9 as MeshInstance3D).material_override
		if m9 is StandardMaterial3D and (m9 as StandardMaterial3D).albedo_texture != null:
			var tx9: Texture2D = (m9 as StandardMaterial3D).albedo_texture; l3_tex[tx9] = int(l3_tex.get(tx9, 0)) + 1
	check("stage 3: the floor is pale tiles (27 times each way), the walls white panels with the teal band and dark skirting, and stencilled signs on three walls",
		l3_tex.has(Lab.tiles_tex()) and l3_tex.get(Lab.wall_tex(), 0) >= 8 and l3_tex.has(Lab._tx.sign1) and l3_tex.get(Lab._tx.sign1, 0) == 2 and l3_tex.has(Lab._tx.sign2), l3_tex.size())
	check("stage 3: hazard paint round every cage, on its kick plates and under the window; each cage's number on the floor; straw inside",
		l3_tex.get(Lab.hazard_tex(), 0) >= 40 + 40 + 1 and range(1, 11).all(func(n9): return l3_tex.has(Lab.num_tex(n9))) and l3_tex.get(Lab.straw_tex(), 0) == 10 and l3_tex.has(Lab.door_tex()))
	var l3_untoned := w.group.find_children("*", "MultiMeshInstance3D", true, false).filter(func(n9): return n9.material_override is ShaderMaterial)
	check("stage 3: the ceiling panels shine white as the browser game's (1.6, 1.7, 1.8, not tone mapped)",
		l3_untoned.size() == 1 and (l3_untoned[0].material_override as ShaderMaterial).get_shader_parameter("mul") == Vector3(1.6, 1.7, 1.8))
	check("stage 3: the scientist has his wild white hair, goggles, ears and legs (the browser game's monkey)", lab._mk_head != null and lab._mk_head.get_child_count() == 2 and lab._leg_l != null and lab._leg_r != null)
	# the animals, part for part as AnimalKit.quad
	var zs3: Dictionary = Animals.quad_spec("zebra"); var ts3: Dictionary = Animals.quad_spec("tiger"); var hs3: Dictionary = Animals.quad_spec("hippo")
	check("stage 3: a zebra is an egg-shaped striped body (a sphere scaled 0.66 x 0.84 x 1.95) on hoofed legs, stripes on its body and neck, its mane plain",
		zs3.P[0][9] == true and zs3.P[0][8] == false and zs3.P[3][8] == true and zs3.plain and zs3.legs.size() == 4 and Animals.kit_tex("zebra") != null and zb3.legs.size() == 4
		and ((zb3.legs[0].get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 48)
	check("stage 3: cats open their jaws (a jaw on its own pivot), the hippo tips its head and drops its jaw",
		ts3.subs.size() == 1 and ts3.subs[0].name == "jaw" and hs3.subs.map(func(sb): return sb.name) == ["head", "jaw"] and lab.cages[6].animals[0].jaw != null and lab.cages[2].animals[0].head != null and lab.cages[2].animals[0].jaw != null)
	# the gorillas: KongKit's rig, the head and chest hit spheres riding on it (D7)
	check("stage 3: the giant gorilla is the browser game's rig (hips, torso, head, arms and forearms, legs and shins)",
		gb3.rig.has("torso") and gb3.rig.has("foreL") and gb3.rig.has("shinR") and gb3.legs.is_empty() and gb3.parts[0].has("node") and gb3.parts[1].has("node"))
	var g3_o0: Vector3 = gb3.parts[0].o
	gb3.k = {"mode": "beat", "t": 0.3, "combo": 0, "arm": 1, "hit": true, "chargeCd": 9.0, "jumpCd": 9.0, "summonCd": 9.0, "summons": 0, "engaged": 0.0, "called": true}
	for i in 30: en.animals._kong(gb3, 0.02, 0.0, 10.0, 0.0)
	check("stage 3: rearing up to beat its chest, its head's hit sphere goes up with it (it follows the pose)", gb3.parts[0].o.y > g3_o0.y + 0.15, [g3_o0, gb3.parts[0].o])
	var mb3 := Gfx.merge_boxes([[1, 1, 1, 0, 0, 0, "ffffff", [0.5, 0.5, 0]]]).surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var want3 := (Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.5)) * Vector3(0, 1, 0)
	check("merged boxes turn as three.js turns a geometry: x first, then y, then z", mb3.has(want3) or Array(mb3).any(func(nn): return nn.distance_to(want3) < 1e-4))
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
	# the browser game's ridden mount glows a moment when it is hit (its body's emissive 0.6, 0.35, 0.2 for the flash)
	en.damage(zb3, 1.0, zb3.pos, Vector3(0, 0, 1), false); en.update(0.02, 0.0)
	var fl3_on := 0; var fl3_body := 0
	for fl3_n in (zb3.g as Node3D).find_children("*", "MeshInstance3D", true, false):
		if fl3_n.has_meta("body"): fl3_body += 1; fl3_on += 1 if (fl3_n as MeshInstance3D).material_overlay == en._flash_mat else 0
	for i in 5: en.update(0.02, 0.0)
	var fl3_off := true
	for fl3_n in (zb3.g as Node3D).find_children("*", "MeshInstance3D", true, false):
		if fl3_n.has_meta("body") and (fl3_n as MeshInstance3D).material_overlay != null: fl3_off = false
	check("stage 3: the zebra you ride glows a moment when it is hit, as there (the hit flash on its whole body, then gone)", fl3_body >= 5 and fl3_on == fl3_body and fl3_off, [fl3_body, fl3_on])
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
	check("stage 3: a zebra pays 1,000, a rhino 3,000, both doubled", Store.save.money == m3 + 4000 * Store.PAY and gm.kills == 2, Store.save.money - m3)
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
	check("stage 3-1: 93 animals living wild (seven big lions where the browser game has fourteen), a tower of 10,000, three crates up on it", en.list.size() == 93 and gm.goal == 93 and en.list.all(func(e): return e.wild) and sf.hp == 10000.0 and sf.slots.size() == 16 and w.crates[0].y == 3.84, sf.slots.size())
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
	check("stage 4: the bee pays ten times its price, doubled, and its door opens for good", Store.save.money == s4_m4 + 15000 * Store.PAY and s4_sh.doors[0].mode == "open" and gm.mid == null, Store.save.money - s4_m4)
	pl.pos = Vector3(Ship.KEY.x + 1.0, 0.45, Ship.KEY.z)
	check("stage 4: pulling the key out is the save point", s4_sh.take_key() and s4_sh.key and gm.sp != null and gm.sp.kills == 1 and gm.sp.key)
	# dying after it: back on the bridge with the key, the kills and the bag as they were
	var s4_k4: int = gm.kills; var s4_bag4: int = Store.save.money
	en.damage(en.list[5], 1e6, en.list[5].pos, Vector3(0, 0, 1), false); pl.invuln = 0.0; pl.hp = 1.0; pl.hurt(50, Vector3.ZERO); gm.update(0.02)
	check("stage 4: you fall after the save point", gm.ended and gm.result == "dead" and gm.sp != null)
	gm.from_save()
	check("stage 4: back at the save point you are in the stage again (a rental goes back when it ends)", gm.deployed)
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
	# its mines: thrown out of its belly in a wide ring round the spot under it (the owner's rule), not dropped in a heap under it
	var s4_was: Array = en.list.duplicate(); var s4_at: Vector3 = boss4.pos
	s4_rb._drop_mines(boss4, 10)
	var s4_mines: Array = en.list.filter(func(e): return not s4_was.has(e) and e.type == "mine")
	for i in 55: en.update(0.02, 0.0)
	var s4_d: Array = s4_mines.map(func(m): return Vector2(m.pos.x - s4_at.x, m.pos.z - s4_at.z).length()); var s4_q := {}
	for m in s4_mines: s4_q[int(fposmod(atan2(m.pos.z - s4_at.z, m.pos.x - s4_at.x), TAU) / (TAU / 4.0))] = true
	var s4_mean: float = (s4_d.reduce(func(a, b): return a + b, 0.0) / s4_d.size()) if not s4_d.is_empty() else 0.0
	check("stage 4: ten mines from the boss drone land in a wide ring all round it (2.5 to 8.5 m out), and lie arming",
		s4_mines.size() == 10 and s4_mines.all(func(m): return m.bs == "arm") and s4_d.min() >= 1.0 and s4_d.max() <= Robots.MINE_R[1] + 10 * Robots.MINE_R[2] + 0.5 and s4_mean >= 3.5 and s4_q.size() == 4, [s4_d, s4_q.keys()])
	# the boss drone down is the ship won, robots left or not: open its chest and you are out (the owner's rule)
	var s4_left: int = en.list.filter(func(e): return e.alive and not e.extra and e != boss4).size()
	en.damage(boss4, 1e6, boss4.pos, Vector3(0, 0, 1), false)
	check("stage 4: the boss drone down, the stage waits only for its chest, though robots are left", not boss4.alive and s4_left > 0 and lt.pending() != null and not gm.ended and gm._chest_wait, s4_left)
	var s4_ch: Dictionary = lt.pending(); pl.pos = Vector3(float(s4_ch.x), float(s4_ch.y), float(s4_ch.z) + 1.0); lt.update(0.02); gm.update(0.02)
	check("stage 4: its chest opened, the ship is cleared", gm.ended and gm.result == "clear" and Store.save.cleared.has(4), [gm.ended, gm.result])
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
	var s5_riders := en.list.filter(func(e): return e.carried)
	check("stage 5: a hundred toys: 42 plastic soldiers (12 of them standing on the 12 wind-up cars), 22 action figures, 24 brick figures",
		en.list.size() == 100 and gm.goal == 100 and s5_kinds.get("soldier", 0) == 42 and s5_kinds.get("figure", 0) == 22 and s5_kinds.get("rc", 0) == 12 and s5_kinds.get("brick", 0) == 24
		and s5_riders.size() == 12 and s5_riders.all(func(r): return r.type == "soldier" and r.k.car.type == "rc" and r.k.car.k.rider == r), s5_kinds)
	var s5_bad := ""
	for e in en.list:
		if e.carried:   # a rider stands on the roof of his car
			var c5: Vector3 = e.k.car.pos
			if absf(e.pos.y - c5.y - ToyFoes.SEAT.y) > 0.01 or Vector2(e.pos.x - c5.x, e.pos.z - c5.z).length() > 0.2: s5_bad = "rider %s on %s" % [str(e.pos), str(c5)]; break
			continue
		var gy5 := Phys.ground_at(e.pos.x, e.pos.y + 0.1, e.pos.z, e.R)
		if absf(gy5 - e.pos.y) > 0.05 or Phys.collide_at(e.pos.x, e.pos.y + 0.05, e.pos.z, e.R, 1.5) != null: s5_bad = "%s %s" % [e.type, str(e.pos)]; break
	check("stage 5: every toy stands on something and inside nothing (a rider on his car's roof)", s5_bad == "", s5_bad)
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
	# ...and still, it blinks: out of sight for a second, back for a second, over and over (not drawn at all while out of sight)
	var s5_bl = en.list.filter(func(e): return e.type == "soldier" and not e.carried)[3]
	s5_bl.pos = Vector3(-2, 0, 50); s5_bl.k.post = s5_bl.pos; s5_bl.alert = false; s5_bl.los = false; s5_bl.k.reveal = 0.0; s5_bl.k.still = 0.0; s5_bl.k.blink = 0.0; s5_bl.k.move_t = 0.0
	var s5_seen := []; var s5_drawn := []
	for i in 112:
		s5_tf.update(s5_bl, 0.05, 50.0, Vector2(50, 0), 0.0)
		if i in [51, 71, 91, 111]: s5_seen.push_back(not s5_tf.gone(s5_bl)); s5_drawn.push_back((s5_bl.g.get_child(1) as Node3D).visible)
	check("stage 5: a soldier gone still blinks: out of sight for a second, back for a second, and so on", s5_seen == [false, true, false, true] and s5_drawn == s5_seen and s5_tf.camo(s5_bl), [s5_seen, s5_drawn])
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
	s5_r.pos = Vector3(-30, 0, 48.5); s5_r.yaw = PI / 2; s5_r.vel = Vector3.ZERO; s5_r.k.v = 0.0; s5_r.k.back_t = 0.0; s5_r.alert = true; s5_r.los = true; pl.pos = Vector3(-5, 0, 48.5)   # (25 m: close and in its sight, so it comes at you)
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
	# riders: a plastic soldier standing on each car, two toys with their own health; the car drives itself, the rider only shoots
	var s5_rd = s5_r.k.get("rider", null)
	check("stage 5: its car broken, the rider steps down onto the floor and fights on, a soldier on foot", s5_rd != null and s5_rd.alive and not s5_rd.carried and s5_rd.k.role == "trooper"
		and absf(s5_rd.pos.y - Phys.ground_at(s5_rd.pos.x, s5_rd.pos.y + 0.2, s5_rd.pos.z, s5_rd.R)) < 0.05, s5_rd.pos if s5_rd != null else null)
	var s5_c2 = en.list.filter(func(e): return e.type == "rc" and e.alive and e.k.get("rider", null) != null)[0]; var s5_r2 = s5_c2.k.rider; var s5_h0: float = s5_c2.hp
	en.damage(s5_r2, 30, s5_r2.pos, Vector3(0, 0, 1), false)
	check("stage 5: the rider and his car each have their own health: a shot at the rider leaves the car whole", s5_r2.hp == s5_r2.max_hp - 30.0 and s5_c2.hp == s5_h0 and s5_r2.alive and s5_c2.alive)
	seed(5149)   # (out of sight the car drives about at random from here on: the same draws every run, so the car below starts where it always does)
	s5_c2.pos = Vector3(-30, 0, 48.5); s5_c2.yaw = PI / 2; s5_c2.k.v = 0.0; s5_c2.k.back_t = 0.0; s5_c2.k.wander_t = 0.0; s5_c2.vel = Vector3.ZERO; s5_c2.alert = true; s5_c2.los = false
	s5_r2.alert = true; s5_r2.los = true; s5_r2.react = 0.0; s5_r2.fire_t = 0.0; s5_r2.burst = 0; pl.pos = Vector3(-30, 0, 70.0); pr.clear(); var s5_shot := 0; var s5_off2 := 0.0
	for i in 90:
		var s5_tc := Vector2(pl.pos.x - s5_c2.pos.x, pl.pos.z - s5_c2.pos.z); s5_tf.update(s5_c2, 0.02, s5_tc.length(), s5_tc, atan2(s5_tc.x, s5_tc.y))
		var s5_tr := Vector2(pl.pos.x - s5_r2.pos.x, pl.pos.z - s5_r2.pos.z); s5_tf.update(s5_r2, 0.02, s5_tr.length(), s5_tr, atan2(s5_tr.x, s5_tr.y))
		s5_shot = maxi(s5_shot, pr.list.size()); s5_off2 = maxf(s5_off2, Vector2(s5_r2.pos.x - s5_c2.pos.x, s5_r2.pos.z - s5_c2.pos.z).length())
	check("stage 5: the rider goes where his car goes, standing on its roof, and shoots when he sees you", s5_shot > 0 and s5_off2 < 0.2 and absf(s5_r2.pos.y - s5_c2.pos.y - ToyFoes.SEAT.y) < 0.01 and s5_c2.pos.distance_to(Vector3(-30, 0, 48.5)) > 1.0, [s5_shot, s5_off2])
	# the car out of your sight: it drives about at random and never stops, and not faster than 6 m/s
	seed(5150)   # (its turns are drawn at random: the same draws every run)
	s5_c2.alert = false; s5_c2.los = false; pl.pos = Vector3(-30, 0, -60.0); var s5_prev: Vector3 = s5_c2.pos; var s5_path := 0.0; var s5_vmax := 0.0; var s5_vmin := INF; pr.clear()
	for i in 300:
		var s5_tw := Vector2(pl.pos.x - s5_c2.pos.x, pl.pos.z - s5_c2.pos.z); s5_tf.update(s5_c2, 0.02, s5_tw.length(), s5_tw, atan2(s5_tw.x, s5_tw.y))
		s5_path += s5_c2.pos.distance_to(s5_prev); s5_prev = s5_c2.pos; s5_vmax = maxf(s5_vmax, float(s5_c2.k.v))
		if i > 150: s5_vmin = minf(s5_vmin, float(s5_c2.k.v))
	check("stage 5: with you out of its sight a car keeps driving about at random (it never stops), no faster than 6 m/s", s5_path > 8.0 and s5_vmax <= ToyFoes.RC_WANDER + 1e-6 and s5_vmin > 0.0, [s5_path, s5_vmax, s5_vmin])
	en.damage(s5_r2, 999, s5_r2.pos, Vector3(0, 0, 1), false)
	s5_c2.pos = Vector3(-30, 0, 48.5); s5_c2.yaw = PI / 2; s5_c2.vel = Vector3.ZERO; s5_c2.k.v = 0.0; s5_c2.k.back_t = 0.0; s5_c2.k.heading = PI / 2; s5_c2.k.wander_t = 3.0   # (off along the open carpet)
	var s5_cp: Vector3 = s5_c2.pos
	for i in 50:
		var s5_tz := Vector2(pl.pos.x - s5_c2.pos.x, pl.pos.z - s5_c2.pos.z); s5_tf.update(s5_c2, 0.02, s5_tz.length(), s5_tz, atan2(s5_tz.x, s5_tz.y))
	check("stage 5: shot off his car, the rider is down and the car drives on by itself", not s5_r2.alive and s5_c2.alive and s5_c2.pos.distance_to(s5_cp) > 1.0)
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
	_team_modes(gm, en, pl, g, pr, w, cam)
	_music(gm, en, pl, w)
	_mobile()
	_fixes_153(gm, en, pl, g, pr, cam, fxn)
	_fixes_154(gm, en, pl, w)
	_aim_clear()
	_corpse_shot(gm, en, pl, g, cam)
	_lmg_sound()
	await _accounts()
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
	en.blow_vest(b1, Vector3(0, 0, -1)); check("1-2: a bullet in the bomb kills him and pays", not b1.alive and Store.save.money == m0 + 1000 * Store.PAY and pr.list.size() == 1 and pr.list[0].kind == "bomb")
	for i in 60: pr.update(1.0 / 30.0)
	check("1-2: and the vest goes off (others caught in it go off too)", pr.list.is_empty())
	gm.begin(5); pl.invuln = 1e9; bm9 = en.list.filter(func(e8): return e8.kit == "bomber")
	var b2 = bm9[1]; pl.reset(b2.pos.x + 1.2, b2.pos.z, 0.0); pl.pos.y = b2.pos.y; pl.invuln = 0.0; pl.hp = 1000.0; pl.update(0.0, cam, 0.0); en.alarm(b2); b2.state = "engage"; b2.react = 0.0; m0 = Store.save.money; var kills0 := gm.kills
	for i in 60: en.update(1.0 / 30.0, 0.0); pr.update(1.0 / 30.0)
	check("1-2: a bomber who reaches you blows himself up: it hurts, it counts, and he pays nothing (others caught in the blast do)", not b2.alive and b2.self_det and pl.hp < 1000.0 and gm.kills >= kills0 + 1 and Store.save.money == m0 + (gm.kills - kills0 - 1) * 1000 * Store.PAY,
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
	# 1-2: always put down in the corner at the bottom right of the map (it was the bottom left up to 1.6.0: the owner's choice)
	gm.begin(5); var c9 := Vector2(pl.pos.x, pl.pos.z); var near9 := INF
	for e9 in en.list: near9 = minf(near9, Vector2(e9.pos.x, e9.pos.z).distance_to(c9))
	var in9 := Vector2(-sin(pl.yaw), -cos(pl.yaw)).dot(-c9.normalized())
	check("1-2: you always come down in the corner at the bottom right of the map (the east and south ends) on open ground, facing in, with nobody close",
		c9.x > 54.0 and c9.y > 54.0 and Phys.collide_at(pl.pos.x, 0.05, pl.pos.z, 0.36, 1.7) == null and Vector2(w.start.x, w.start.z).distance_to(c9) < 0.01 and in9 > 0.9 and near9 > 12.0, [c9, in9, near9])
	gm.begin(5); check("1-2: and there again on the next go", Vector2(pl.pos.x, pl.pos.z).distance_to(c9) < 0.01)
	# ---------------- stage 5: the toy room ----------------
	Store.save = Store.save0(); gm.begin(9); var toy: ToyRoom = w.toy
	check("the toy room: a hundred toys in it, every toy gun in hand", toy != null and en.list.size() == 100 and g.loadout == Toys.ORDER and Store.stage_open(9))
	var to_moved := Meta.move_gun("rocket", -1, true); var to_lay: Array = gm.layout(); var to_first := Meta.move_gun("pistol", -1, true)
	check("the toy room's nine toy guns change order too (keys 1-9), and keep it", to_moved and not to_first and to_lay[6] == "rocket" and to_lay[7] == "lmg" and to_lay.size() == 9 and Store.save.toy_order == to_lay, to_lay)
	Store.save.toy_order = Toys.ORDER.duplicate(); g.reset(gm.layout())
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
	# the spray-can flamethrower: a wide cone every way round, 15 m, six jets of 2.5 a shot, and what it hits burns on
	var FW: Dictionary = Custom.weapon("flame")
	check("the spray-can flamethrower: 15 m, a cone 0.24 wide every way round (0.18 down the sights), eight jets of 2.5 a shot, 20 shots a second (400 a second when all of it lands; it was 75)",
		FW.range == 15.0 and FW.spread == 0.24 and FW.adsSpread == 0.18 and int(FW.pellets) == 8 and FW.dmg == 2.5 and FW.rate == 0.05 and FW.flame)
	var fl_t = en.list.filter(func(e): return e.alive and e.type == "soldier")[0]; fl_t.hp = 2000.0; fl_t.max_hp = 2000.0; fl_t.burn_t = 0.0
	pl.reset(0.0, 56.0, 0.0); pl.update(0.0, cam, 0.0); var fl_eye := cam.global_position; fl_t.pos = Vector3(fl_eye.x, 0.0, fl_eye.z - 7.0)
	var fl_aim: Vector3 = Vector3(fl_t.pos.x, fl_t.pos.y + 1.0, fl_t.pos.z) - fl_eye; pl.pitch = atan2(fl_aim.y, Vector2(fl_aim.x, fl_aim.z).length()); pl.update(0.0, cam, 0.0)
	g.reset(Toys.ORDER.duplicate()); g.cur = "flame"; g.cooldown = 0.0; var fl_n0: int = fxn._flames.size(); var fl_h0: float = fl_t.hp
	seed(5300); g.trigger = true; g.trigger_edge = true
	for i in 18: g.update(1.0 / 60.0)   # (0.3 s: six sprays, the fire thickest in the middle of its cone)
	g.trigger = false
	var fl_v: Vector3 = fxn._flames[fxn._flames.size() - 1][2] if fxn._flames.size() > fl_n0 else Vector3.ZERO; var fl_reach: float = fl_v.length() * Fx.FLAME_LIFE * 0.7
	check("0.3 s of spray at a toy 7 m off hurts it, sets it alight, and its fire is drawn on every spray (two balls of flame, on a hit too) out about as far as it burns",
		fl_t.hp < fl_h0 and fl_t.burn_t > 2.6 and fxn._flames.size() >= fl_n0 + 10 and fl_reach > 11.0 and fl_reach < 17.5, [fl_h0 - fl_t.hp, fl_t.burn_t, fxn._flames.size() - fl_n0, fl_reach])
	var fl_h1: float = fl_t.hp
	for i in 160: en._burns(0.02)
	check("a toy alight burns on for 3 s after the fire leaves it: 12 every half second, six times", is_equal_approx(fl_h1 - fl_t.hp, 6.0 * Enemies.BURN_DMG) and fl_t.burn_t == 0.0 and Enemies.BURN_DMG == 12.0, fl_h1 - fl_t.hp)
	en.ignite(fl_t); for i in 50: en._burns(0.02)
	en.ignite(fl_t); for i in 60: en._burns(0.02)
	check("each touch of the fire starts its 3 s over (it does not stack)", fl_t.burn_t > 1.7 and fl_t.burn_t < 1.9, fl_t.burn_t)
	fl_t.burn_t = 0.0; fl_t.hp = 10.0; var fl_k0: int = gm.kills; en.ignite(fl_t); for i in 30: en._burns(0.02)
	check("a toy the burning finishes is your kill", not fl_t.alive and gm.kills == fl_k0 + 1, [fl_t.alive, gm.kills - fl_k0])
	var bu := Ui.new(); bu.game = gm; add_child(bu); bu._build_brief(); var bu_keep: Array = (Store.save.toy_order as Array).duplicate()
	Store.save.toy_order = ["pistol", "shotgun", "rifle", "smg", "sniper", "gl", "flame", "lmg", "rocket"]; bu.sel = 9; bu.br_gear.text = ""; bu.br_go.disabled = true; bu._brief_gear()
	check("stage 5's briefing with the spray can moved onto keys 1-7: its toy guns as ever, and 출동 open", bu.br_gear.text.begins_with("장난감 무기 9종") and not bu.br_go.disabled, bu.br_gear.text)
	Store.save.toy_order = bu_keep; bu.free()
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
	gm.begin(9); var nm_rc: MapRec = map_of.call(9); var nm_bad := []
	var nm_h := {"책장": ToyRoom.SHELF_Y, "옷장": ToyRoom.WARD_Y, "책상": ToyRoom.DESK_Y, "2층침대": ToyRoom.BUNK_Y}
	for nm: Array in ToyRoom.NAMES:
		var nm_on := Phys.colliders.any(func(b: Phys.Box) -> bool: return float(nm[1]) > b.minx and float(nm[1]) < b.maxx and float(nm[2]) > b.minz and float(nm[2]) < b.maxz and b.maxy >= float(nm_h.get(nm[0], 99.0)) - 0.01)
		if not nm_rc.texts.has(nm[0]) or not nm_on: nm_bad.push_back(nm)
	var nm_p := {}
	for nm: Array in ToyRoom.NAMES: nm_p[nm[0]] = Vector2(nm[1], nm[2])
	check("5: the map names the furniture as the owner drew it: 책장 and 옷장 along the top (north), 책상 on the left, 2층침대 on the right, each over its piece; no other stage has them",
		nm_bad.is_empty() and nm_p.size() == 4 and nm_p["책장"].x < nm_p["옷장"].x and nm_p["책상"].x < nm_p["2층침대"].x and maxf(nm_p["책장"].y, nm_p["옷장"].y) < minf(nm_p["책상"].y, nm_p["2층침대"].y)
		and not (map_of.call(1) as MapRec).texts.has("책장"), nm_bad)
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
	check("the legend: each stage's kinds, 1-2's drop point in its fixed corner (the bottom right: no longer one to pick), who is after you while you play; the toy room has no boss",
		m_l4.has("스파이더 마인 (움직일 때만)") and m_l4.has("흰 테두리 · 나를 쫓는 중") and m_l4.has("에어록 · 시작하는 곳") and m_l5.has("헬기에서 내리는 곳 · 오른쪽 아래 구석") and not m_l5.any(func(t): return str(t).contains("눌러")) and not m_l5.has("흰 테두리 · 나를 쫓는 중")
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
	Fx.exposure = 1.12; var e_so := Fx.shown(Color(1.0, 0.3, 0.05)); var e_sod := Gfx.display(Vector3(e_dec.call(e_so.r), e_dec.call(e_so.g), e_dec.call(e_so.b)), 1.12); Fx.exposure = 1.15
	check("a speck redder than the screen can show (a robot's burning bits) still comes out nearest to it", absf(e_sod.x - 0.97) < 0.003 and absf(e_sod.y - 0.3) < 0.003 and absf(e_sod.z - 0.05) < 0.04, e_sod)
	w.set_ao(false); var e_off := not w.ao_layer.visible and w.ao.render_target_update_mode == SubViewport.UPDATE_DISABLED; w.set_ao(true)
	check("the computer's ambient occlusion can be switched off (phones and stage 5 go without)", e_off and w.ao_layer.visible)
	w.gfx_mode = "auto"; w.gfx_apply(4)
	for i in 81: w.govern(1.0 / 40.0)   # two seconds at 40 a second: one step down, the occlusion stays
	var e_l1 := [w.gfx_level, w.ao_layer.visible]
	for i in 81: w.govern(1.0 / 40.0)   # another: level 2, the occlusion goes
	var e_l2 := [w.gfx_level, w.ao_layer.visible]
	for i in 3 * 121: w.govern(1.0 / 60.0)   # three good spells: back up to 3, the occlusion returns
	var e_l3 := [w.gfx_level, w.ao_layer.visible]
	check("the occlusion follows the browser game's quality ladder: down a step per sagging two seconds, gone below level 3, back after three good spells",
		e_l1 == [3, true] and e_l2 == [2, false] and e_l3[1] == true and int(e_l3[0]) >= 3, [e_l1, e_l2, e_l3])
	# the whole ladder, as the browser game's Gfx: what each level sets, the three settings, a computer drawing without its card
	var gl_want := [[0.85, false, 1024, 0.0, false], [1.0, false, 2048, 28.0, false], [1.0, true, 2048, 28.0, false], [1.5, true, 4096, 45.0, true], [2.0, true, 4096, 45.0, true]]
	var gl_ok := World.GFX_LEVELS.size() == 5 and World.GFX_LEVELS.map(func(L): return L.name) == ["낮음", "보통", "높음", "매우 높음", "최고"]
	var gl_seen := []
	for gl_i in 5:
		var L: Dictionary = World.GFX_LEVELS[gl_i]; gl_ok = gl_ok and [L.pr, L.post, L.shadow, L.esh, L.ao] == gl_want[gl_i] and Enemies.ESH[gl_i] == L.esh
		w.gfx_apply(gl_i); gl_seen.push_back([w.gfx_level, w.moon_shadow.size.x, w.ao_layer.visible])
	check("the quality ladder's five levels as the browser game's (pixel ratio, bloom, shadow picture, enemies' shadow reach, occlusion), and each sets its shadow picture and occlusion",
		gl_ok and gl_seen == [[0, 1024, false], [1, 2048, false], [2, 2048, false], [3, 4096, true], [4, 4096, true]], gl_seen)
	w.gfx_apply(4); w.gfx_set_mode("fast"); var gl_fast := w.gfx_level
	for i in 3 * 121: w.govern(1.0 / 60.0)
	var gl_fast2 := w.gfx_level; w.gfx_set_mode("high"); var gl_high := w.gfx_level
	for i in 3 * 81: w.govern(1.0 / 20.0)
	var gl_high2 := w.gfx_level; w.gfx_set_mode("auto"); var gl_auto := w.gfx_level
	w.gfx_soft = true; w.gfx_init(3); var gl_soft := w.gfx_level; w.gfx_mode = "high"; w.gfx_init(3); var gl_soft_hi := w.gfx_level
	w.gfx_soft = false; w.gfx_mode = "auto"; w.gfx_init(2); var gl_saved := [w.gfx_level, Store.level_saved()]; w.gfx_init(-1); var gl_first := w.gfx_level
	check("the 그래픽 setting: 프레임 우선 stays at level 1 or below, 최고 화질 holds the top whatever the frame rate, 자동 starts from the top; without a graphics card level 0 unless told the top; the level it settled at is kept for next time",
		gl_fast == 1 and gl_fast2 == 1 and gl_high == 4 and gl_high2 == 4 and gl_auto == 4 and gl_soft == 0 and gl_soft_hi == 4 and gl_saved == [2, 2] and gl_first == 4,
		[gl_fast, gl_fast2, gl_high, gl_high2, gl_auto, gl_soft, gl_soft_hi, gl_saved, gl_first])
	var gl_main = load("res://scripts/main.gd")
	var gl_txt: String = gl_main.perf_format(59.6, 16.78, 21.4, 3.26, false, "최고", "auto", 1280, 720, 1.0, true, true, 4096, 312, 120400, "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)")
	var gl_soft_txt: String = gl_main.perf_format(30.0, 33.3, 40.0, 9.0, false, "낮음", "fast", 1088, 612, 0.85, false, false, 1024, 90, 40000, "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)")
	check("the FPS readout's four lines word for word as the browser game's (the graphics card's name shortened as there, the warning when the CPU draws)",
		gl_txt == "FPS 60 · 16.8ms (최악 21) · CPU 3.3ms\n그래픽 최고 (자동) · 해상도 1280×720 (1.00배) · 블룸 · AO · 그림자 4096\n드로우콜 312 · 삼각형 120k\nGPU NVIDIA GeForce RTX 3060"
		and gl_soft_txt.ends_with("· 그래픽 가속 꺼짐: CPU로 그리는 중") and gl_soft_txt.contains("그래픽 낮음 (프레임 우선) · 해상도 1088×612 (0.85배) · 그림자 1024"), [gl_txt, gl_soft_txt])
	w.gfx_mode = "auto"; w.gfx_apply(4)
	var e_gr := Grade.new(); add_child(e_gr); e_gr.tune(World.STAGE_STYLE[9]); var e_toy := e_gr.visible; e_gr.tune(World.STAGE_STYLE[1]); var e_yard := e_gr.visible
	e_gr.allowed = false; e_gr.tune(World.STAGE_STYLE[1]); var e_phone := e_gr.visible; e_gr.queue_free()
	check("the finishing pass: on a computer in the browser game's stages, never in stage 5 (this port's own room keeps its light) nor on phones", not e_toy and e_yard and not e_phone, [e_toy, e_yard, e_phone])
	# the 3D picture of its own and the finishing pass worked from it, pass by pass as the browser game's Post
	var pc := Picture.new(); add_child(pc); var pc_cam := Camera3D.new(); add_child(pc_cam); pc_cam.position = Vector3(3, 2, 1); pc_cam.fov = 61.0
	pc.follow = pc_cam; pc.share = 0.5; pc._sync(); var pc_win := Vector2(get_viewport().size)
	var pc_ok: bool = pc.scene_vp.size == Vector2i(roundi(pc_win.x * 0.5), roundi(pc_win.y * 0.5)) and pc.scene_cam.global_position.is_equal_approx(Vector3(3, 2, 1)) and pc.scene_cam.fov == 61.0 and pc.scene_cam.current
	pc_ok = pc_ok and pc.scene_vp.world_3d == get_viewport().find_world_3d() and pc.show.texture == pc.scene_vp.get_texture() and pc.layer < 0
	pc.share = 1.0; pc.scene_vp.size = Vector2i(1280, 720); pc.follow = null
	var gp := Grade.new(); add_child(gp); gp.attach(pc.scene_vp); gp.visible = true; gp._size = Vector2i.ZERO; gp._sync()
	var gp_sizes: Array = gp.mips.map(func(m): return m.size)
	var gp_ok: bool = gp_sizes == [Vector2i(640, 360), Vector2i(320, 180), Vector2i(160, 90), Vector2i(80, 45), Vector2i(40, 22)] and gp.final_vp.size == Vector2i(1280, 720)
	gp_ok = gp_ok and (gp.mat_bright.get_shader_parameter("texel") as Vector2).is_equal_approx(Vector2(1.0 / 1280.0, 1.0 / 720.0)) and gp.mat_bright.get_shader_parameter("tex") == pc.scene_vp.get_texture()
	for gi in range(1, 5):
		var gd: ShaderMaterial = gp._mats_down[gi - 1]; var gu: ShaderMaterial = gp._mats_up[gi - 1]
		gp_ok = gp_ok and gd.get_shader_parameter("tex") == gp.mips[gi - 1].get_texture() and (gd.get_shader_parameter("texel") as Vector2).is_equal_approx(Vector2(1.0 / gp.mips[gi - 1].size.x, 1.0 / gp.mips[gi - 1].size.y))
		gp_ok = gp_ok and gu.get_shader_parameter("tex") == gp.ups[gi].get_texture() and gu.get_shader_parameter("base") == gp.mips[gi - 1].get_texture() and gp.ups[gi - 1].size == gp.mips[gi - 1].size
		gp_ok = gp_ok and (gu.get_shader_parameter("texel") as Vector2).is_equal_approx(Vector2(0.5 / gp.mips[gi].size.x, 0.5 / gp.mips[gi].size.y))
	var gp_order := gp.get_children().filter(func(c): return c is SubViewport)
	var gp_want := []; gp_want.append_array(gp.mips); gp_want.append_array([gp.ups[3], gp.ups[2], gp.ups[1], gp.ups[0], gp.final_vp])
	gp_ok = gp_ok and gp_order.size() == gp_want.size()
	for gi in mini(gp_order.size(), gp_want.size()): gp_ok = gp_ok and gp_order[gi] == gp_want[gi]   # each made after the one it reads, so drawn after it
	gp_ok = gp_ok and gp.mat_final.get_shader_parameter("scene") == pc.scene_vp.get_texture() and gp.mat_final.get_shader_parameter("bloom") == gp.ups[0].get_texture() and gp.show.texture == gp.final_vp.get_texture()
	gp.tune(World.STAGE_STYLE[1]); var gp_night: Dictionary = gp._tuned.duplicate(); gp.tune(World.STAGE_STYLE[7]); var gp_day: Dictionary = gp._tuned.duplicate()
	gp_ok = gp_ok and gp_night == {"threshold": 0.76, "knee": 0.14, "strength": 0.55, "vig": 0.6, "sat": 1.07} and gp_day == {"threshold": 0.9, "knee": 0.08, "strength": 0.3, "vig": 0.4, "sat": 1.04}
	gp_ok = gp_ok and Grade.BRIGHT.contains("s = s * s / (4.0 * knee + 1e-4);") and Grade.DOWN.contains("* 0.125") and Grade.UP.contains("s / 12.0") and Grade.FINAL.contains("43758.5453) - 0.5) / 255.0")
	gp.visible = false; var gp_off: bool = gp.mips.all(func(m): return m.render_target_update_mode == SubViewport.UPDATE_DISABLED) and gp.final_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED
	check("the finishing pass as the browser game's Post, from a 3D picture of its own (the window's world, the main camera's view, its share of the window's size): the bright pass at half size, four halvings down, four back up each adding the one below, then bloom, saturation, vignette and dither at the picture's size; night and day tuned as there; off, its passes stop",
		pc_ok and gp_ok and gp_off, [pc.scene_vp.size, gp_sizes, gp_night, gp_day])
	gp.queue_free(); pc.queue_free(); pc_cam.queue_free()
	# ---- E 3-1: the savanna by day, as the browser game draws it ----
	gm.begin(7); var sv := func(nm: String) -> Node: return w.group.find_child(nm, true, false)
	var sv_cam := Camera3D.new(); add_child(sv_cam); sv_cam.position = Vector3(5, 2, 7); sv_cam.current = true; w._process(0.0)
	var sv_sm := w.sun_spr.material_override as StandardMaterial3D; var sv_off: Array = World.STAGE_STYLE[7].sunOff
	var sv_want := Vector3(5, 2, 7) + Vector3(sv_off[0], sv_off[1], sv_off[2]).normalized() * 330.0
	check("3-1: a low sun, a glow 70 across with no fog and no depth, kept 330 m out along the sunlight from the camera",
		w.sun_spr.visible and (w.sun_spr.mesh as QuadMesh).size == Vector2(70, 70) and sv_sm.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED and sv_sm.disable_fog
		and sv_sm.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and w.sun_spr.global_position.distance_to(sv_want) < 1e-3, w.sun_spr.global_position)
	sv_cam.queue_free()
	var sv_tu: MultiMeshInstance3D = sv.call("Tufts"); var sv_tm := sv_tu.material_override as StandardMaterial3D
	check("3-1: 3200 tufts of three crossed cards, both sides drawn, cut out at 0.3 with alpha to coverage, casting no shadow",
		sv_tu.multimesh.instance_count == 3200 and sv_tu.multimesh.mesh.get_faces().size() == 18 and sv_tm.cull_mode == BaseMaterial3D.CULL_DISABLED
		and sv_tm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and is_equal_approx(sv_tm.alpha_scissor_threshold, 0.3)
		and sv_tm.alpha_antialiasing_mode == BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE and not sv_tu.get_layer_mask_value(MoonShadow.CASTER))
	check("3-1: no moon shadow on the tufts and no occlusion on their blades: marked (3), kept out of the occlusion's picture, and both layers pass them by",
		sv_tm.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and sv_tm.stencil_reference == MoonShadow.GRASS and (sv_tu.layers & w.ao.cam.cull_mask) == 0
		and sv_tu.layers == 1 << (Gfx.MAIN_ONLY - 1) and AoView.APPLY_SHADER.contains("stencil_mode read, compare_not_equal, 3;")
		and MoonShadow.LAYER_SHADER.contains("stencil_mode read, compare_greater, 2;") and MoonShadow.GRASS == 3 and MoonShadow.UNSHADOWED == 2)
	w.ao.follow(w.ao.cam, Vector2i(1280, 720)); var ao_bh: ShaderMaterial = (w.ao.blur_h.get_child(0) as ColorRect).material; var ao_bv: ShaderMaterial = (w.ao.blur_v.get_child(0) as ColorRect).material
	check("the occlusion is blurred as the browser game's two seven-tap passes: across, then down, each at half size and weighed by depth, then enlarged smoothly and multiplied in",
		AoView.BLUR_SHADER.contains("for (int i = -3; i <= 3; i++)") and AoView.BLUR_SHADER.contains("exp(-float(i * i) / 8.0) * max(0.0, 1.0 - abs(z - zc) / (0.04 * zc + 0.08))")
		and w.ao.size == Vector2i(640, 360) and w.ao.blur_h.size == w.ao.size and w.ao.blur_v.size == w.ao.size
		and ao_bh.get_shader_parameter("src") == w.ao.get_texture() and ao_bv.get_shader_parameter("src") == w.ao.blur_h.get_texture()
		and (ao_bh.get_shader_parameter("dir") as Vector2).is_equal_approx(Vector2(1.0 / 640.0, 0.0)) and (ao_bv.get_shader_parameter("dir") as Vector2).is_equal_approx(Vector2(0.0, 1.0 / 360.0))
		and w.ao_mat.get_shader_parameter("ao_tex") == w.ao.blur_v.get_texture() and AoView.APPLY_SHADER.contains("uniform sampler2D ao_tex : filter_linear")
		and w.get_children().find(w.ao) < w.get_children().find(w.ao.blur_h) and w.get_children().find(w.ao.blur_h) < w.get_children().find(w.ao.blur_v))
	var ao_gun := MeshInstance3D.new(); var ao_glass := Gfx.unlit(Color(0.6, 0.8, 1.0, 0.2), false); ao_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; ao_gun.material_override = ao_glass
	var ao_steel := MeshInstance3D.new(); var ao_sm := Gfx.std(Color.GRAY, 0.5); ao_steel.material_override = ao_sm; World._after_ao(ao_gun); World._after_ao(ao_steel)
	check("the occlusion is multiplied over everything drawn, see-through things too (the browser game multiplies its whole picture after the world); only the gun's see-through parts come after it",
		w.ao_mat.render_priority == Gfx.PRIO_AO and Gfx.PRIO_AO > 0 and Gfx.PRIO_AO > Gfx.PRIO_SKY and Gfx.PRIO_AO > Gfx.PRIO_FOG and ao_glass.render_priority == Gfx.PRIO_HAND and Gfx.PRIO_HAND > Gfx.PRIO_AO and ao_sm.render_priority == 0)
	ao_gun.free(); ao_steel.free()
	var sv_bl := Safari.blade_tex().get_image(); var sv_clear := 0; var sv_dark := 0
	for sv_y in 128:
		for sv_x in 128:
			var sv_c := sv_bl.get_pixel(sv_x, sv_y)
			if sv_c.a == 0.0: sv_clear += 1; sv_dark += 1 if sv_c.r < 0.3 else 0
	check("3-1: the blades' picture is clear between the blades, its clear texels the blades' own colour (a far tuft is not darkened toward black)", sv_clear > 4000 and sv_dark == 0, [sv_clear, sv_dark])
	var sv_rd: MeshInstance3D = sv.call("Roads"); var sv_rv: PackedVector3Array = sv_rd.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sv_p0 := Vector2(0, -170); var sv_p1 := Vector2(sin(0.5) * 8.0, -170.0 + 14.2); var sv_len := sv_p0.distance_to(sv_p1); var sv_d0 := (sv_p1 - sv_p0) / sv_len
	var sv_mid := (sv_p0 + sv_p1) / 2; var sv_d := Vector2(sv_d0.x, -sv_d0.y); var sv_nn := Vector2(sv_d0.y, sv_d0.x); var sv_hl := (sv_len + 0.6) / 2
	var sv_road_ok := sv_rv.size() == (72 + 24) * 4
	for sv_q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var sv_pp: Vector2 = sv_mid + sv_nn * 3.0 * sv_q[0] + sv_d * sv_hl * sv_q[1]; var sv_found := false
		for sv_k in range(72 * 4, 72 * 4 + 4): sv_found = sv_found or sv_rv[sv_k].distance_to(Vector3(sv_pp.x, 0.015, sv_pp.y)) < 1e-4
		sv_road_ok = sv_road_ok and sv_found
	check("3-1: the dirt tracks: 96 pieces 6 m wide, each laid as the browser game lays it (tilted the other way about its middle, so they zigzag)", sv_road_ok)
	var sv_nr := []
	for sv_name in ["Hills", "Posts", "Wire", "Water", "Sign", "SignFace", "SignPosts", "TowerSign"]:
		var sv_m := (sv.call(sv_name) as GeometryInstance3D).material_override as BaseMaterial3D
		if not (sv_m.stencil_reference == MoonShadow.UNSHADOWED and sv_m.stencil_flags == BaseMaterial3D.STENCIL_FLAG_WRITE): sv_nr.push_back(sv_name)
	check("3-1: what takes no shadow there takes none here: the far hills, the fence, the waterhole, the park's sign and the tower's", sv_nr.is_empty(), sv_nr)
	var sv_pk: MeshInstance3D = sv.call("Planks"); var sv_bm: MeshInstance3D = sv.call("Beams"); var sv_rf: MeshInstance3D = sv.call("Roof"); var sv_ts: MeshInstance3D = sv.call("TowerSign")
	var sv_t1 := SurfaceTool.new(); sv_t1.begin(Mesh.PRIMITIVE_TRIANGLES); sv_t1.append_from(Gfx.box(Vector3.ONE), 0, Transform3D.IDENTITY); var sv_per_p: int = sv_t1.commit().surface_get_array_len(0)
	var sv_t2 := SurfaceTool.new(); sv_t2.begin(Mesh.PRIMITIVE_TRIANGLES); sv_t2.append_from(BoxMesh.new(), 0, Transform3D.IDENTITY); var sv_per_b: int = sv_t2.commit().surface_get_array_len(0)
	var sv_uv: PackedVector2Array = sv_pk.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]; var sv_umax := 0.0
	for sv_k in sv_per_p: sv_umax = maxf(sv_umax, sv_uv[sv_k].x)
	var sv_bb := sv_bm.mesh.get_aabb()
	check("3-1: the tower in planks (skirt, platform, eight steps; the picture 2.5 times round the skirt) and 53 beams (legs, sill, joists, braces, railing, roof poles, stringers, handrails, posts)",
		sv_pk.mesh.surface_get_array_len(0) == 10 * sv_per_p and is_equal_approx(sv_umax, 2.5) and (sv_pk.material_override as StandardMaterial3D).albedo_texture == Safari.plank_tex()
		and sv_bm.mesh.surface_get_array_len(0) == 53 * sv_per_b and absf(sv_bb.end.z - 6.70) < 0.02 and absf(sv_bb.end.y - 6.7) < 1e-3,
		[sv_pk.mesh.surface_get_array_len(0) / sv_per_p, sv_umax, sv_bm.mesh.surface_get_array_len(0) / float(sv_per_b), sv_bb])
	var sv_ra: Array = sv_rf.mesh.surface_get_arrays(0); var sv_rp: PackedVector3Array = sv_ra[Mesh.ARRAY_VERTEX]; var sv_rn: PackedVector3Array = sv_ra[Mesh.ARRAY_NORMAL]
	var sv_tin := sv_rf.material_override as StandardMaterial3D; var sv_roof_ok := sv_rp.size() == 12; var sv_cr := 2.6 * 1.55 * sqrt(0.5)
	for sv_k in sv_rp.size():
		var sv_v := sv_rp[sv_k]
		sv_roof_ok = sv_roof_ok and sv_rn[sv_k].y > 0.9 and (absf(sv_v.y - 8.0) < 1e-4 or (absf(sv_v.y - 6.7) < 1e-4 and absf(absf(sv_v.x) - sv_cr) < 1e-3 and absf(absf(sv_v.z) - sv_cr) < 1e-3))
	check("3-1: its roof a tin pyramid (four faces, open underneath, square to the tower, shaded round as three.js's cone), both sides drawn",
		sv_roof_ok and sv_tin.cull_mode == BaseMaterial3D.CULL_DISABLED and is_equal_approx(sv_tin.metallic, 0.55) and is_equal_approx(sv_tin.roughness, 0.55))
	check("3-1: the tower casts the moon's shadow (planks, beams, roof); its name board, up on the railing, casts none",
		sv_pk.get_layer_mask_value(MoonShadow.CASTER) and sv_bm.get_layer_mask_value(MoonShadow.CASTER) and sv_rf.get_layer_mask_value(MoonShadow.CASTER)
		and not sv_ts.get_layer_mask_value(MoonShadow.CASTER) and (sv_ts.mesh as QuadMesh).size == Vector2(1.5, 0.56) and sv_ts.position.distance_to(Vector3(-1.7, 3.84 + 0.8, 2.6 + 0.07)) < 1e-4
		and Safari.plank_tex().get_width() == 256 and Safari.tower_sign_tex().get_height() == 96)
	check("textures are filtered 16 times across slopes on a computer and 8 times on a phone, as the browser game's MAX_ANISO",
		ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level") == 4 and ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level.mobile", 0) == 3)
	gm.begin(1); var sv_night := not w.sun_spr.visible; gm.begin(7); gm.begin(9); var sv_toyroom := not w.sun_spr.visible; gm.begin(1)
	check("the sun is for the day: gone again by night, and not in stage 5's room", sv_night and sv_toyroom)
	# ---- E 4: the ship and its crew, as the browser game draws them ----
	gm.begin(4); var e4_find := func(nm: String) -> Node: return w.group.find_child(nm, true, false)
	var e4_w := []
	for t: ImageTexture in [Ship.plate_tex(), Ship.hall_tex(), Ship.panel_tex(), Ship.grate_tex(), Ship.carpet_tex(), Ship.ceil_tex(), Ship.step_tex(), Ship.space_tex(0.62), Ship.shaft_tex()]: e4_w.push_back(t.get_width())
	var e4_pn := Ship.panel_tex().get_image(); var e4_yl := e4_pn.get_pixel(128, 249); var e4_sp := Ship.space_tex(0.62).get_image(); var e4_pl := e4_sp.get_pixel(int(1024 * 0.62), 250)
	check("4: the ship's pictures at the browser game's sizes, the wall panels with their yellow line near the foot, space with a blue planet rising",
		e4_w == [512, 512, 256, 128, 256, 256, 256, 1024, 4] and e4_yl.r > e4_yl.b + 0.1 and e4_yl.g > e4_yl.b and e4_pl.b > 0.45 and e4_pl.b > e4_pl.r and Ship.grate_tex().get_image().get_pixel(1, 1).is_equal_approx(Color("4a5260")), [e4_w, e4_yl, e4_pl])
	# the doors as the owner of this port drew them: a blue seam down the middle that crosses the black ring in the middle in an S;
	# the bridge's and the hall's two leaves part along it
	var dr_w := 10.0; var dr_h := 6.0; var dr_R := Ship.RING_R * dr_h
	var dr_s := [Ship.seam_u(dr_h * 0.5 + dr_R * 0.5, dr_w, dr_h) - dr_w * 0.5, Ship.seam_u(dr_h * 0.5 - dr_R * 0.5, dr_w, dr_h) - dr_w * 0.5, Ship.seam_u(dr_h * 0.9, dr_w, dr_h) - dr_w * 0.5]
	var dr_img: Image = (Ship.door_face(dr_w, dr_h)[0] as ImageTexture).get_image(); var dr_pw := dr_img.get_width(); var dr_ph := dr_img.get_height()
	var dr_top := dr_img.get_pixel(dr_pw / 2, int(dr_ph * 0.15)); var dr_ring := dr_img.get_pixel(dr_pw / 2 + roundi(dr_ph * Ship.RING_R), dr_ph / 2); var dr_panel := dr_img.get_pixel(int(dr_pw * 0.25), int(dr_ph * 0.3))
	var dr_D: Dictionary = w.ship.doors[0]; var dr_o0: float = dr_D.open; dr_D.open = 1.0; w.ship._slide(dr_D); var dr_gap: float = (dr_D.b as Node3D).position.z - (dr_D.a as Node3D).position.z
	dr_D.open = dr_o0; w.ship._slide(dr_D)
	var al_img: Image = Ship.airlock_tex().get_image(); var al_mat = (w.ship.air_door as MeshInstance3D).material_override
	var al_foot := al_img.get_pixel(5, 250); var al_red := 0
	for al_y in range(95, 112):
		for al_x in range(70, 186): var al_c := al_img.get_pixel(al_x, al_y); al_red += 1 if al_c.r > 0.8 and al_c.g < 0.4 and al_c.b < 0.35 else 0
	check("4: the door you start at (the airlock's inner door) wears its own face again, as before 1.2.0 (the owner's wish): striped yellow at its foot, 에어록 in red; the others keep the drawn face",
		al_mat is StandardMaterial3D and (al_mat as StandardMaterial3D).albedo_texture == Ship.airlock_tex() and al_img.get_width() == 256 and al_foot.r > 0.8 and al_foot.g > 0.6 and al_foot.b < 0.4 and al_red > 150
		and (dr_D.a as MeshInstance3D).material_override != al_mat, [al_foot, al_red])
	check("4: the doors as drawn: a blue seam down the middle, crossing the black ring in the middle in an S; the bridge's and the hall's two leaves part along it, all the way",
		dr_s[0] > 0.2 and dr_s[1] < -0.2 and absf(dr_s[2]) < 1e-6 and dr_pw == 640 and dr_top.b > dr_top.r + 0.3 and dr_ring.r < 0.1 and dr_ring.b < 0.1 and absf(dr_panel.r - Color("434a5a").r) < 0.02
		and absf(dr_gap - dr_w) < 0.01 and (dr_D.a as MeshInstance3D).mesh.get_faces().size() > 100, [dr_s, dr_top, dr_ring, dr_panel, dr_gap])
	var e4_sg := Ship.sign_tex("운전실", "up", Color("f2a33a")).get_image(); var e4_or := 0
	for e4_y in range(70, 260, 3):
		for e4_x in range(100, 640, 3): var e4_c := e4_sg.get_pixel(e4_x, e4_y); e4_or += 1 if e4_c.r > 0.8 and e4_c.g > 0.5 and e4_c.b < 0.4 else 0
	var e4_ar := e4_sg.get_pixel(836, 110); var e4_fr := e4_sg.get_pixel(20, 160)
	check("4: the signs in the browser game's letters (its own six-letter font), framed, with a block arrow", e4_or > 400 and e4_ar.r > 0.8 and e4_ar.b < 0.4 and e4_fr.r > 0.8 and e4_fr.b < 0.4, [e4_or, e4_ar, e4_fr])
	var e4_wm: MeshInstance3D = e4_find.call("Walls"); var e4_wa: Array = e4_wm.mesh.surface_get_arrays(0); var e4_uv_ok := true
	for e4_i in range(0, (e4_wa[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 97):
		var e4_v: Vector3 = e4_wa[Mesh.ARRAY_VERTEX][e4_i]; var e4_n: Vector3 = e4_wa[Mesh.ARRAY_NORMAL][e4_i]; var e4_u: Vector2 = e4_wa[Mesh.ARRAY_TEX_UV][e4_i]
		var e4_want := Vector2(e4_v.z, e4_v.y) if absf(e4_n.x) > 0.5 else (Vector2(e4_v.x, e4_v.z) if absf(e4_n.y) > 0.5 else Vector2(e4_v.x, e4_v.y))
		e4_uv_ok = e4_uv_ok and e4_u.distance_to(Vector2(e4_want.x / 3.0, 1.0 - e4_want.y / 3.0)) < 1e-4
	var e4_fc: MeshInstance3D = e4_find.call("Floor_corr")
	check("4: walls in panels laid by the metre (3 m a picture on every face, as uvBox), the corridor's floor in plates, the passage's a grating, the bridge carpeted",
		e4_uv_ok and (e4_wm.material_override as StandardMaterial3D).albedo_texture == Ship.panel_tex() and (e4_fc.material_override as StandardMaterial3D).albedo_texture == Ship.plate_tex()
		and ((e4_find.call("Floor_pass") as MeshInstance3D).material_override as StandardMaterial3D).albedo_texture == Ship.grate_tex() and ((e4_find.call("Floor_bridge") as MeshInstance3D).material_override as StandardMaterial3D).albedo_texture == Ship.carpet_tex())
	var e4_pm: MeshInstance3D = e4_find.call("Pipes"); var e4_pmat := e4_pm.material_override as StandardMaterial3D; var e4_gl: MeshInstance3D = e4_find.call("Glow")
	check("4: pipes along the passage and the corridor, the bridge's railings with posts (from x -107.4), rings up the reactor down into its pit (steel, no shadow on them); the glowing strips unlit and unshadowed",
		absf(e4_pm.mesh.get_aabb().position.x + 107.44) < 0.01 and absf(e4_pm.mesh.get_aabb().end.x - 121.72) < 0.01 and absf(e4_pm.mesh.get_aabb().position.y + 7.1) < 0.02 and e4_pmat.albedo_color.is_equal_approx(World.lin("59627a")) and is_equal_approx(e4_pmat.roughness, 0.45) and is_equal_approx(e4_pmat.metallic, 0.6)
		and e4_pmat.stencil_reference == MoonShadow.UNSHADOWED and (e4_gl.material_override as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and (e4_gl.material_override as StandardMaterial3D).stencil_reference == MoonShadow.UNSHADOWED,
		e4_pm.mesh.get_aabb())
	var e4_bw: MeshInstance3D = e4_find.call("BridgeWindow"); var e4_hw: MeshInstance3D = e4_find.call("HallWindow"); var e4_signs := 0
	for e4_n2 in w.group.find_children("*", "MeshInstance3D", true, false):
		var e4_q = (e4_n2 as MeshInstance3D).mesh
		if e4_q is QuadMesh and ((e4_q as QuadMesh).size.is_equal_approx(Vector2(4.3, 4.3 * 0.3125)) or (e4_q as QuadMesh).size.is_equal_approx(Vector2(4.4, 4.4 * 0.3125))): e4_signs += 1
	check("4: windows onto space on the bridge (27 x 11) and the hall (56 x 7), four signs (two at the junction, one hung before each door), five red lamps blinking in the passage",
		(e4_bw.mesh as QuadMesh).size == Vector2(27, 11) and (e4_hw.mesh as QuadMesh).size == Vector2(56, 7) and (e4_bw.material_override as StandardMaterial3D).albedo_texture == Ship.space_tex(0.62) and e4_signs == 4 and w.blink.size() == 5, [e4_signs, w.blink.size()])
	var e4_sh: Ship = w.ship; e4_sh.update(0.01, 0.3); var e4_k := 0.85 + 0.15 * sin(4.3 * 0.3); var e4_ry0: float = e4_sh.ring.rotation.y; e4_sh.update(0.5, 0.8)
	var e4_rt: TorusMesh = (e4_sh.ring as MeshInstance3D).mesh
	check("4: the bridge's screens flicker, the ring over the reactor (12 m round) turns slowly, the key is a gold bow and shaft with an added glow",
		e4_sh.screens_mat.albedo_color.is_equal_approx(World.lin(Color(0.85 + 0.15 * sin(4.3 * 0.8), 0.85 + 0.15 * sin(4.3 * 0.8), 0.85 + 0.15 * sin(4.3 * 0.8)))) and e4_k > 0.0
		and is_equal_approx(e4_sh.ring.rotation.y - e4_ry0, 0.5 * 0.35) and is_equal_approx(e4_rt.outer_radius, 12.22) and e4_sh.ring.position.distance_to(Vector3(120, 15.6, -6)) < 1e-4
		and e4_sh.key_obj.get_child(0).mesh is TorusMesh and (e4_sh.key_glow.material_override as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD)
	var e4_hide := true
	for e4_n3: Node3D in e4_sh.pit.show: e4_hide = e4_hide and not e4_n3.visible
	e4_sh.break_floor(); var e4_show := not (e4_sh.pit.dais as Node3D).visible and not (e4_sh.pit.dais_glow as Node3D).visible
	for e4_n3: Node3D in e4_sh.pit.show: e4_show = e4_show and e4_n3.visible
	e4_sh.open_hatches(); e4_sh.update(1.0, 2.0); var e4_h0: Dictionary = e4_sh.hatches[0]
	check("4: the pit's steps, landings, their lights and its floor show only when the hall's floor breaks (the dais and its lights go); open hatches stand up a column of red light",
		e4_hide and e4_show and (e4_h0.shaft as Node3D).visible and (e4_h0.shaft as Node3D).scale.y > 0.5 and ((e4_h0.shaft as MeshInstance3D).mesh as CylinderMesh).cap_top == false and e4_sh.hatches.size() == 8)
	# the crew
	var q4_t := {}
	for q4_e in en.list:
		if not q4_t.has(q4_e.type): q4_t[q4_e.type] = q4_e
	var q4_body := 0; var q4_kit_ok := true
	for q4_n in (q4_t.patrol.g as Node3D).find_children("*", "MeshInstance3D", true, false):
		if q4_n == q4_t.patrol.far: continue   # (the whole baked for far away, which D10 checks below)
		if q4_n.has_meta("body"): q4_body += 1; var q4_m := (q4_n as MeshInstance3D).material_override as StandardMaterial3D; q4_kit_ok = q4_kit_ok and is_equal_approx(q4_m.roughness, 0.42) and is_equal_approx(q4_m.metallic, 0.55)
	check("4: the robots' plating as the browser game's (roughness 0.42, metalness 0.55), and it shows the hit flash", q4_body == 5 and q4_kit_ok, q4_body)
	var q4_d = q4_t.droneA; var q4_ro: Node3D = q4_d.k.rotors[0]; var q4_ry := q4_ro.rotation.y; en.robots.update(q4_d, 0.1, 80.0, Vector2(1, 0), 0.0)
	var q4_m2 = q4_t.mine; en.robots.update(q4_m2, 0.1, 80.0, Vector2(1, 0), 0.0)
	check("4: the little drone's four propellers turn (and it flies level when it has not seen you); the spider mine's six legs lie folded while it is buried",
		q4_d.k.rotors.size() == 4 and is_equal_approx(q4_ro.rotation.y - q4_ry, 4.2) and is_equal_approx(q4_d.g.rotation.x, 0.08) and q4_m2.k.cl.size() == 6 and is_equal_approx((q4_m2.k.cl[0] as Node3D).rotation.z, -0.75))
	var q4_b = q4_t.gdrone; en.robots.update(q4_b, 0.05, 80.0, Vector2(1, 0), 0.0); var q4_w0: Node3D = q4_b.k.wings[0].g
	var q4_gold: ShaderMaterial = null
	for q4_n in (q4_b.g as Node3D).get_children():
		if q4_n is MeshInstance3D and (q4_n as MeshInstance3D).material_override is ShaderMaterial and is_equal_approx(float((q4_n as MeshInstance3D).material_override.get_shader_parameter("metal")), 1.0): q4_gold = (q4_n as MeshInstance3D).material_override; break
	var q4_ee: Vector3 = (q4_b.k.bee_eye as ShaderMaterial).get_shader_parameter("emis")
	check("4: the golden bee: polished gold that reflects the browser game's studio sky, four wings beating, its eyes dark until it charges (spawning clears their glow)",
		q4_gold != null and is_equal_approx(float(q4_gold.get_shader_parameter("rough")), 0.14) and q4_gold.shader.code.contains("vec3 studio(") and q4_b.k.wings.size() == 4 and absf(q4_w0.rotation.z) > 0.01 and q4_ee == Vector3.ZERO)
	var q4_bs = q4_t.bdrone; var q4_s0: Dictionary = q4_bs.k.shells[0]; var q4_ball: MeshInstance3D = (q4_s0.g as Node3D).get_child(0); var q4_zmax := -99.0
	for q4_v: Vector3 in q4_ball.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: q4_zmax = maxf(q4_zmax, q4_v.z)
	en.robots.eye_tint(q4_bs, true); var q4_red: Vector3 = (q4_bs.k.eye_mat as ShaderMaterial).get_shader_parameter("mul"); var q4_rg := (q4_bs.k.eye_glow as StandardMaterial3D).albedo_color; en.robots.eye_tint(q4_bs, false)
	check("4: the boss: three shells (5, 3 and 1.5 m) open at the front for the eye, white plating with its seams; the eye blue, red before it fires, its glow with it",
		q4_bs.k.shells.size() == 3 and (q4_bs.k.shells[1].g as Node3D).visible == false and absf(q4_zmax - 2.5 * cos(asin(0.46))) < 1e-3
		and (q4_ball.material_override as ShaderMaterial).get_shader_parameter("map") == BotLook.shell_tex() and q4_red.is_equal_approx(Vector3(1.0, 26 / 255.0, 16 / 255.0)) and q4_rg.is_equal_approx(Color(World.lin("ff3a2a"), 0.34)),
		[q4_zmax, q4_red])
	check("the shiny robots take no moon shadow either (their own shader writes the mark)", BotLook.SHINE.contains("stencil_mode write, compare_always, 2;") and Gfx.unlit(Color.WHITE).stencil_reference == MoonShadow.UNSHADOWED)
	# ---------------- sounds: the browser game's own, made by its own code, mixed as it mixes them ----------------
	var sd_rifle := Snd.takes("shot_rifle"); var sd_coin := Snd.takes("coin"); var sd_toy := Snd.takes("toy_boom")
	var sd_p0 := Snd.pan_as_web(0.0); var sd_p8 := Snd.pan_as_web(0.8)
	var sd_l := (1.0 - sd_p8.x) * sd_p8.y; var sd_r := (1.0 + sd_p8.x) * sd_p8.y   # (what Godot's panner then gives each ear)
	var sd_lis := Snd.listener; var sd_yaw := Snd.listener_yaw
	Snd.listener = Vector3.ZERO; Snd.listener_yaw = 0.0; var sd_a := Snd.place(Vector3(5, 0, 0)); var sd_b := Snd.place(Vector3(-20, 0, 0))
	Snd.listener_yaw = PI / 2.0; var sd_c := Snd.place(Vector3(0, 0, -4)); Snd.listener = sd_lis; Snd.listener_yaw = sd_yaw
	var sd_comp := AudioServer.get_bus_effect(AudioServer.get_bus_index("Mix"), 0) as AudioEffectCompressor
	check("sounds: the browser game's own takes (four of one it varies each time, one of one it never does), panned as its StereoPanner (equal power) and quietened with distance as its spatial(), through its master compressor as measured",
		sd_rifle.size() == 4 and sd_coin.size() == 1 and sd_toy.size() == 1 and (sd_rifle[0] as AudioStreamWAV).mix_rate == 44100
		and absf(sd_p0.x) < 1e-6 and absf(sd_p0.y - sqrt(0.5)) < 1e-5 and absf(sd_l - cos(0.45 * PI)) < 1e-5 and absf(sd_r - sin(0.45 * PI)) < 1e-5
		and is_equal_approx(sd_a.x, 1.0) and absf(sd_a.y - 5.0 / 7.0) < 1e-5 and absf(sd_b.x - 1.6 / 2.8) < 1e-5 and is_equal_approx(sd_b.y, -0.8) and absf(sd_c.y - 4.0 / 6.0) < 1e-5
		and sd_comp != null and is_equal_approx(sd_comp.threshold, -5.6) and is_equal_approx(sd_comp.ratio, 1.3) and is_equal_approx(sd_comp.gain, 0.74)
		and AudioServer.get_bus_send(AudioServer.get_bus_index("Voice0")) == "Mix" and AudioServer.get_bus_effect(AudioServer.get_bus_index("Voice0"), 0) is AudioEffectPanner,
		[sd_rifle.size(), sd_coin.size(), sd_p8, sd_a, sd_b, sd_c])
	var sd_vol := Snd.volume; Snd.volume = 0.7
	Snd.jet(0.8); var sd_j1 := Snd._jet; Snd.jet(0.45, 1.0); var sd_j2 := Snd._jet; Snd.jet(0.85, 0.08); var sd_j3 := Snd._jet
	var sd_jl: AudioStreamWAV = (Snd._loops["jet_hi"] as AudioStreamPlayer).stream; Snd.jet(0.0); var sd_j4 := Snd._jet; Snd.volume = sd_vol
	var sd_rot: AudioStreamWAV = load("res://sounds/rotor.wav")
	check("sounds: the jetpack as the browser game's jet (0.8 lit, 0.45 hovering, 0.85 climbing, eased a tenth of a second), from its two takes, each looping whole (3 s; the rotor 6 s)",
		sd_j1.is_equal_approx(Vector2(0.0, 0.8 / 0.85)) and sd_j2.is_equal_approx(Vector2(1.0, 0.0)) and absf(sd_j3.y - (1.0 - exp(-1.0))) < 1e-4 and sd_j4 == Vector2.ZERO
		and Snd.takes("jet_lo").size() == 1 and Snd.takes("jet_hi").size() == 1 and sd_jl.loop_mode == AudioStreamWAV.LOOP_FORWARD and sd_jl.loop_end == 3 * 44100
		and roundi(sd_rot.get_length() * sd_rot.mix_rate) == 6 * 44100 and not (Snd._loops["jet_hi"] as AudioStreamPlayer).playing, [sd_j1, sd_j2, sd_j3, sd_jl.loop_end])
	Snd.keep_log = true; Snd.played.clear(); en.damage(q4_t.patrol, 1.0, q4_t.patrol.pos, Vector3(0, 0, 1), false); var sd_metal := Snd.played.has("metal")
	var sd_was := [q4_bs.k.duplicate(), q4_bs.pos, q4_bs.yaw, (q4_bs.g as Node3D).rotation, q4_bs.alert]
	if not q4_bs.k.has("phase"): en.robots._boss(q4_bs, 0.0, 999.0, 0.0)   # (its fight's state, as its first update makes it)
	Snd.played.clear(); q4_bs.k.mode = "warn"; q4_bs.k.t = Robots.LASER_WARN; q4_bs.k.phase = 0; en.robots._boss(q4_bs, 0.001, 20.0, 0.0); var sd_lock := Snd.played.duplicate(); Snd.keep_log = false
	q4_bs.k = sd_was[0]; q4_bs.pos = sd_was[1]; q4_bs.yaw = sd_was[2]; (q4_bs.g as Node3D).rotation = sd_was[3]; q4_bs.alert = sd_was[4]; en.robots.aim_off()
	check("sounds where the browser game plays them: a robot rings of metal when hit; the boss's laser lock wails for its phase (siren2, 3.25 s); each enemy gun its own far voice",
		sd_metal and sd_lock.has("laser_siren1") and not sd_lock.has("siren") and Enemies.FAR_SHOT == {"deagle": "far_deagle", "smg": "far_smg", "rifle": "far_rifle", "lmg": "far_rifle", "shotgun": "far_shotgun", "sniper": "far_sniper"},
		[sd_metal, sd_lock])
	# ---------------- D10: far away one baked mesh (the browser game's bakeFar and setFar); the moon's shadow as there ----------------
	check("D10: the ship's crew is drawn baked far away, all but the boss drone (as there), the bake drawn with the plating's material",
		q4_bs.far == null and q4_bs.no_far and q4_t.patrol.far != null and q4_t.patrol.far.material_override == en.robots._kit() and q4_t.cctv.far != null and q4_t.gdrone.far != null and q4_t.mine.far != null)
	gm.begin(1); en.phone = false; en.esh = 45.0
	var d10_px := pl.pos.x; var d10_pz := pl.pos.z
	var d10_a: Enemies.Foe = en.spawn("thug", d10_px + 27.0, d10_pz, {"kit": "pistol"})
	var d10_vc := 0; var d10_parts := 0
	for d10_n in d10_a.g.find_children("*", "MeshInstance3D", true, false):
		var d10_m = (d10_n as MeshInstance3D).mesh
		if d10_n != d10_a.far and d10_m is ArrayMesh and ((d10_m as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0:
			d10_vc += (d10_m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(); d10_parts += 1
	var d10_fm: ArrayMesh = d10_a.far.mesh; var d10_bb := d10_fm.get_aabb()
	check("D10: a person far away is one mesh, his five parts merged where they stand as built (feet to hair, -0.005 to 1.9 m), hidden until then, drawn with the body's material",
		d10_parts == 5 and d10_fm.get_surface_count() == 1 and (d10_fm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == d10_vc and not d10_a.far.visible
		and d10_a.far.material_override == en._mat and d10_a.far.has_meta("body") and absf(d10_bb.position.y + 0.005) < 1e-4 and absf(d10_bb.end.y - 1.9) < 1e-4, [d10_parts, d10_bb])
	d10_a.lod = 0.0; en.update(0.001, 0.0); var d10_near := not d10_a.is_far and not d10_a.far.visible and d10_a.upper.visible
	d10_a.pos = Vector3(d10_px + 29.0, d10_a.pos.y, d10_pz); d10_a.lod = 0.0; en.update(0.001, 0.0)
	var d10_only := true
	for d10_c in d10_a.g.get_children(): d10_only = d10_only and (d10_c as Node3D).visible == (d10_c == d10_a.far)
	check("D10: past 28 m only the baked mesh shows (setFar); a beast's line is 45 m, in the lab 46 (18 on a phone), a boss's half as far again",
		d10_near and d10_a.is_far and d10_only and Enemies.far_line(false, false, false, false) == 28.0 and Enemies.far_line(true, false, false, false) == 45.0
		and Enemies.far_line(true, false, true, false) == 46.0 and Enemies.far_line(true, false, true, true) == 18.0 and Enemies.far_line(false, true, false, false) == 42.0
		and Enemies.far_line(true, true, false, true) == 67.5)
	en._glow(d10_a, "flash"); var d10_flash: bool = d10_a.far.material_overlay != null and d10_a.far.material_overlay == en._flash_mat; en._glow(d10_a, "")
	check("D10: a hit's flash shows on the baked mesh too (it is the body's material there)", d10_flash and d10_a.far.material_overlay == null)
	# the moon's shadow: on a computer only within esh (0, 28, 28, 45, 45 m by quality level), never on a phone, never from a health bar
	var d10_roots: Array = w.caster_roots; w.caster_roots = [en]; w._flush_fresh()
	var d10_cast := func(e) -> int:
		var k := 0
		for d10_q in (e.g as Node3D).find_children("*", "GeometryInstance3D", true, false):
			if (d10_q as VisualInstance3D).get_layer_mask_value(MoonShadow.CASTER): k += 1
		return k
	var d10_all: int = (d10_a.g as Node3D).find_children("*", "GeometryInstance3D", true, false).size()
	var d10_c29: int = d10_cast.call(d10_a)
	d10_a.pos = Vector3(d10_px + 50.0, d10_a.pos.y, d10_pz); d10_a.lod = 0.0; en.update(0.001, 0.0); var d10_c50: int = d10_cast.call(d10_a)
	en.esh = Enemies.ESH[1]; d10_a.pos = Vector3(d10_px + 30.0, d10_a.pos.y, d10_pz); d10_a.lod = 0.0; en.update(0.001, 0.0); var d10_c30: int = d10_cast.call(d10_a)
	d10_a.pos = Vector3(d10_px + 20.0, d10_a.pos.y, d10_pz); d10_a.lod = 0.0; en.update(0.001, 0.0); var d10_c20: int = d10_cast.call(d10_a)
	var d10_bar := 0
	for d10_q in d10_a.bar.find_children("*", "GeometryInstance3D", true, false):
		if (d10_q as VisualInstance3D).get_layer_mask_value(MoonShadow.CASTER): d10_bar += 1
	en.esh = 45.0; en.phone = true
	var d10_b: Enemies.Foe = en.spawn("thug", d10_px + 8.0, d10_pz + 2.0, {"kit": "pistol"}); w._flush_fresh(); d10_b.lod = 0.0; en.update(0.001, 0.0)
	var d10_cp: int = d10_cast.call(d10_b); en.phone = false
	check("D10: enemies cast the moon's shadow within 45 m at the top quality and 28 m below it, never on a phone; their health bars never",
		d10_c29 == d10_all and d10_all >= 6 and d10_c50 == 0 and d10_c30 == 0 and d10_c20 == d10_all and d10_bar == 0 and d10_cp == 0 and Enemies.ESH == [0.0, 28.0, 28.0, 45.0, 45.0],
		[d10_all, d10_c29, d10_c50, d10_c30, d10_c20, d10_bar, d10_cp])
	# a helmet is in the bake; knocked off, the bake is made again without it
	var d10_h: Enemies.Foe = en.spawn("thug", d10_px + 12.0, d10_pz + 3.0, {"kit": "pistol", "helmet": true})
	var d10_n0: int = (d10_h.far.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var d10_hv: int = ((d10_h.helmet_node.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	en._knock_helmet(d10_h, Vector3(0, 0, 1)); var d10_n1: int = (d10_h.far.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var d10_fly: Node3D = en.flying.back()[0]
	check("D10: a helmet is in the baked mesh, and knocking it off bakes it again without (as there); the tumbling helmet casts the moon's shadow, not on a phone",
		d10_n0 - d10_n1 == d10_hv and d10_hv == 14 * 24 and not d10_h.is_far and d10_fly.get_meta("shadow", false) == true, [d10_n0, d10_n1, d10_hv])
	# a striped beast keeps its picture; the boss intro shows a drone whole even if it was drawn baked
	var d10_z: Enemies.Foe = en.spawn("zebra", d10_px + 60.0, d10_pz + 60.0, {})
	var d10_za: Array = d10_z.far.mesh.surface_get_arrays(0)
	var d10_zok: bool = d10_z.far.material_override == en.animals._kit_mats["zebra"] and (d10_za[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == (d10_za[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	en.list.erase(d10_z); d10_z.g.queue_free(); d10_z.bar.queue_free()
	en.set_far(d10_a, true); ct.start_boss_intro({"x": 0.0, "inward": 1.0, "z0": 0.0, "z1": 1.0, "title": "", "tone": "bee"}, d10_a, Callable()); var d10_cut := not d10_a.is_far and d10_a.upper.visible and not d10_a.far.visible; ct.skip()
	check("D10: a striped beast's baked mesh keeps its picture (the same material, the parts' picture coordinates); a boss intro shows the drone whole", d10_zok and d10_cut)
	w.caster_roots = d10_roots
	# ---------------- quicker, with the same answers as the browser game's own ways of finding them (kept below as _ref_*) ----------------
	gm.begin(1); seed(21)
	var sp_n: int = Phys.nav_n; var sp_P: int = Phys._np; var sp_bad := 0; var sp_ways := 0; var sp_reached := 0
	var sp_blk := -1; var sp_cs: float = Phys.nav_cs; var sp_off: float = Phys.nav_off
	for sp_c in range(sp_n + 1, sp_n * sp_n - sp_n - 1):   # a blocked cell beside an open one (as beside a container)
		if Phys.nav_blocked[sp_c] == 1 and Phys.nav_blocked[sp_c + 1] == 0 and sp_c % sp_n < sp_n - 1: sp_blk = sp_c; break
	var sp_starts := [Vector2(pl.pos.x, pl.pos.z), Vector2(-40, 25), Vector2(55, -50), Vector2(((sp_blk % sp_n) + 0.5) * sp_cs - sp_off, ((sp_blk / sp_n) + 0.5) * sp_cs - sp_off)]
	for sp_s: Vector2 in sp_starts:   # (the last stands in a blocked cell, as you can beside a wall)
		var sp_ref := _ref_flow(sp_s.x, sp_s.y)
		Phys.flow_start(sp_s.x, sp_s.y)
		var sp_slices := 0
		while not Phys.flow_step(0): sp_slices += 1   # a slice at a time
		var sp_cells := 0
		for sp_j in sp_n:
			for sp_i in sp_n:
				if maxi(sp_ref[sp_j * sp_n + sp_i], -1) != maxi(Phys.nav_dist[(sp_j + 1) * sp_P + sp_i + 1], -1): sp_bad += 1
				if sp_ref[sp_j * sp_n + sp_i] >= 0: sp_cells += 1
		sp_reached += sp_cells
		for sp_k in 400:
			var sp_x := randf_range(-sp_off - 2, sp_off + 2); var sp_z := randf_range(-sp_off - 2, sp_off + 2)
			if _ref_flow_dir(sp_ref, sp_x, sp_z) != Phys.flow_dir(sp_x, sp_z): sp_ways += 1
		if sp_cells > 2048 and sp_slices < 2: sp_bad += 1   # (a big search really went in slices; one shut in a small space ends at once)
	check("the enemies' way to you: the same steps from every cell and the same way at every point as the browser game's search, four starts (one in a blocked cell), searched a slice at a time",
		sp_bad == 0 and sp_ways == 0 and sp_reached > 3 * 10000 and sp_blk > 0, [sp_bad, sp_ways, sp_reached])
	var sep_bad := 0; var sep_moved := 0
	for sep_t in 4:
		var sep_c := Vector2(pl.pos.x + randf_range(-15, 15), pl.pos.z + randf_range(-15, 15)); var sep_r: float = [3.0, 6.0, 14.0, 40.0][sep_t]
		for sep_e in en.list: sep_e.pos = Vector3(sep_c.x + randf_range(-sep_r, sep_r), sep_e.pos.y, sep_c.y + randf_range(-sep_r, sep_r)); sep_e.awake = randf() < 0.8
		en.list[1].downed = true
		var sep_at := en.list.map(func(fo): return fo.pos)
		_ref_separate(en.list); var sep_want := en.list.map(func(fo): return fo.pos)
		for sep_i in en.list.size(): en.list[sep_i].pos = sep_at[sep_i]
		en._separate()
		for sep_i in en.list.size():
			if en.list[sep_i].pos != sep_want[sep_i]: sep_bad += 1
			if sep_want[sep_i] != sep_at[sep_i]: sep_moved += 1
		en.list[1].downed = false
	check("bodies pushed apart pair by pair exactly as the browser game's loop over every pair, on four crowds (the awake and the not, one lying down)", sep_bad == 0 and sep_moved > 100, [sep_bad, sep_moved])
	var ph_bad := [0, 0, 0, 0]; var ph_hits := [0, 0]
	for ph_k in 3000:
		var ph_b: Phys.Box = Phys.colliders[randi() % Phys.colliders.size()]
		var ph_x := randf_range(ph_b.minx - 2, ph_b.maxx + 2); var ph_z := randf_range(ph_b.minz - 2, ph_b.maxz + 2); var ph_y := randf_range(-1, ph_b.maxy + 1)
		var ph_r := randf_range(0.1, 2.5); var ph_h := randf_range(0.3, 4.0)
		var ph_cref = _ref_collide(ph_x, ph_y, ph_z, ph_r, ph_h)
		if ph_cref != Phys.collide_at(ph_x, ph_y, ph_z, ph_r, ph_h): ph_bad[0] += 1
		if ph_cref != null: ph_hits[0] += 1
		if _ref_ground(ph_x, ph_y, ph_z, ph_r) != Phys.ground_at(ph_x, ph_y, ph_z, ph_r): ph_bad[1] += 1
		if _ref_ceil(ph_x, ph_y, ph_z, ph_r, ph_h) != Phys.ceil_at(ph_x, ph_y, ph_z, ph_r, ph_h): ph_bad[2] += 1
		var ph_dv := Vector3(randf_range(-1, 1), randf_range(-0.5, 0.3), randf_range(-1, 1)) if ph_k % 5 != 0 else Vector3(randf_range(-1, 1), 0, 0)
		if ph_dv.length() < 0.01: continue
		var ph_o := Vector3(ph_x, randf_range(0.2, 6.0), ph_z); ph_dv = ph_dv.normalized(); var ph_mt := randf_range(1, 80)
		var ph_href := _ref_ray(ph_o, ph_dv, ph_mt); var ph_hnew := Phys.raycast_static(ph_o, ph_dv, ph_mt)
		if ph_href: ph_hits[1] += 1
		if ph_href != ph_hnew or _rr_t != Phys.rh_t or (ph_href and (_rr_n != Phys.rh_n or _rr_box != Phys.rh_box)): ph_bad[3] += 1
	check("bumping into boxes, the ground and ceiling under and over you, and rays: the same answers as the browser game's (3000 of each)", ph_bad == [0, 0, 0, 0] and ph_hits[0] > 500 and ph_hits[1] > 1000, [ph_bad, ph_hits])
	w._gv = {"acc": 0.0, "n": 0, "good": 0, "t": 0.0, "up_at": -1e9, "hold": 0.0}; w.gfx_mode = "auto"; w.gfx_apply(0)
	for un_i in 3 * 81: w.govern(1.0 / 40.0)   # the computer's game: never below level 0, and 자동 starts at the top
	var un_desk := [w.gfx_level, w.gfx_under]; w.gfx_init(-1); un_desk.push_back(w.gfx_level); w.gfx_init(3); un_desk.push_back(w.gfx_level)
	w.web = true; w.gfx_init(-1); un_desk.push_back(w.gfx_level); w.gfx_init(3); un_desk.push_back(w.gfx_level); w.gfx_set_mode("auto"); un_desk.push_back(w.gfx_level)
	w._gv = {"acc": 0.0, "n": 0, "good": 0, "t": 0.0, "up_at": -1e9, "hold": 0.0}; w.gfx_apply(0); var un_seen := []
	for un_k in 3:
		for un_i in 81: w.govern(1.0 / 40.0)   # two seconds under 50 a second, at level 0
		un_seen.push_back([w.gfx_level, w.gfx_under])
	for un_i in 3 * 121: w.govern(1.0 / 60.0)   # three good spells: a step back
	un_seen.push_back([w.gfx_level, w.gfx_under])
	for un_i in 6 * 121: w.govern(1.0 / 60.0)   # six more: level 0 whole again, then level 1
	un_seen.push_back([w.gfx_level, w.gfx_under])
	w.gfx_apply(0); w.gfx_set_under(2); w.gfx_set_mode("high"); var un_high := [w.gfx_level, w.gfx_under]
	for un_i in 3 * 81: w.govern(1.0 / 20.0)
	un_high.append_array([w.gfx_level, w.gfx_under]); w.web = false; w.gfx_mode = "auto"; w.gfx_apply(4)
	check("the web is the taster: 자동 starts at level 0 there (the computer's game at the top, or where it settled) and only there goes below it: the picture three quarters, then three fifths of level 0's size while the frame rate still sags, back a step per three good spells before the ladder climbs; never on 최고 화질",
		un_desk == [0, 0, 4, 3, 0, 0, 0] and un_seen == [[0, 1], [0, 2], [0, 2], [0, 1], [1, 0]] and un_high == [4, 0, 4, 0] and World.UNDER_SHARE == [1.0, 0.75, 0.6], [un_desk, un_seen, un_high])
	# ---- the computer's game on Forward+ (these run on the compatibility path: Gfx.fplus is false here, as on the web)
	var fp_main = load("res://scripts/main.gd")
	var fp_share := [fp_main.level_share(2.0, 2.0, true), fp_main.level_share(2.0, 1.0, true), fp_main.level_share(0.85, 1.0, true), fp_main.level_share(2.0, 1.0, false), fp_main.level_share(1.5, 1.0, false), fp_main.level_share(0.85, 1.0, false)]
	var fp_fine := [Picture.fine_share(2.0, 1280.0), Picture.fine_share(2.0, 1920.0), Picture.fine_share(2.0, 2560.0), Picture.fine_share(2.0, 3840.0), Picture.fine_share(1.5, 1920.0), Picture.fine_share(0.85, 3840.0)]
	check("the picture's size up the ladder: on the web the level's pixel ratio, at most the screen's; the computer's game draws its top levels finer than the window (1.5 and 2 times each way) and no wider than 3840 pixels",
		fp_share == [1.0, 1.0, 0.85, 2.0, 1.5, 0.85] and fp_fine == [2.0, 2.0, 1.5, 1.0, 1.5, 0.85], [fp_share, fp_fine])
	var fp_tex := Gfx.glow_tex(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	var fp_m := StandardMaterial3D.new(); fp_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fp_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fp_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; fp_m.albedo_color = Color(1, 0.5, 0.25, 0.4); fp_m.albedo_texture = fp_tex; fp_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fp_m.render_priority = 3
	var fp_same: bool = Gfx.see_through(fp_m) == fp_m and not Gfx.fplus
	Gfx.fplus = true; var fp_s = Gfx.see_through(fp_m); var fp_mix_m := StandardMaterial3D.new(); fp_mix_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fp_mix_m.disable_fog = true
	var fp_mix = Gfx.see_through(fp_mix_m); Gfx.fplus = false
	var fp_code: String = (fp_s as ShaderMaterial).shader.code if fp_s is ShaderMaterial else ""; var fp_mix_code: String = (fp_mix as ShaderMaterial).shader.code if fp_mix is ShaderMaterial else ""
	var fp_param := [fp_s.get_shader_parameter("albedo") == fp_m.albedo_color, fp_s.get_shader_parameter("tex") == fp_tex, fp_s.render_priority] if fp_s is ShaderMaterial else []
	Gfx.set_alpha(fp_s, 0.7); var fp_a: float = Gfx.get_tint(fp_s).a; Gfx.tint(fp_m, Color(1, 0, 0, 0.5)); Gfx.set_alpha(fp_m, 0.25)
	check("a see-through glow as three.js mixes it: the material itself on the web's renderer; on Forward+ a shader with its colour, picture, billboard and fog that adds the light showing it as the screen adds it (a mixed one laid over), whose colour and alpha change the same way",
		fp_same and fp_s is ShaderMaterial and fp_param == [true, true, 3] and fp_code.contains("#define SHOWN_ADD") and fp_code.contains("#define BILLBOARD") and fp_code.contains("#define TEX") and fp_code.contains("#define FOG")
		and fp_code.contains("hint_screen_texture") and fp_mix is ShaderMaterial and not fp_mix_code.contains("#define SHOWN_ADD") and not fp_mix_code.contains("#define FOG")
		and absf(fp_a - 0.7) < 1e-6 and fp_m.albedo_color == Color(1, 0, 0, 0.25), [fp_param, fp_a, fp_m.albedo_color])
	var fp_vm := StandardMaterial3D.new(); fp_vm.vertex_color_use_as_albedo = true; var fp_vn := MeshInstance3D.new(); fp_vn.mesh = BoxMesh.new(); fp_vn.material_override = fp_vm
	Gfx.three_like(fp_vn); var fp_vc := fp_vm.vertex_color_is_srgb; fp_vn.free()
	var fp_globals := ["yard_exposure", "yard_tone_k", "yard_fog_density", "yard_fog_disp", "yard_fog_scene", "yard_fog_end"].filter(func(g): return ProjectSettings.has_setting("shader_globals/" + g))
	check("vertex colours are screen colours (the compatibility renderer reads them so, Forward+ only when told); the see-through layers' globals are declared, and the tone mapping's white comes out as Godot's: 1 at the browser game's white, 1.28 at the toy room's",
		fp_vc and fp_globals.size() == 6 and absf(Gfx.tone_k(Gfx.TONE_WHITE) - 1.0) < 0.002 and absf(Gfx.tone_k(1.0) - 1.2803) < 0.002, [fp_vc, fp_globals, Gfx.tone_k(Gfx.TONE_WHITE), Gfx.tone_k(1.0)])
	gm.begin(1)
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails else 0)

# ---------------- the browser game's own ways (src/04b_physics.js, src/07b_ai.js), as this port had them line for line: the
# quicker ones in the game must give the same answers ----------------
const _REF_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
# ---------------- stage 5's team modes ----------------
## the whole fight for a while, as the game's frame runs it
func _tick(gm: Game, en: Enemies, pl: Player, g: Guns, pr: Proj, w: World, cam: Camera3D, sec: float) -> void:
	for i in roundi(sec * 30.0):
		pl.update(1.0 / 30.0, cam, 0.0); w.toy.update(1.0 / 30.0, pl); g.update(1.0 / 30.0); en.update(1.0 / 30.0, 0.0); pr.update(1.0 / 30.0); gm.update(1.0 / 30.0)

## every way of a mode's waypoints can be walked: a toy put at one end and steered at the other gets there (one-way drops too)
func _walk_edges(tm: ToyMatch) -> Array:
	var u: Enemies.Foe = tm.allies[0]; var bad: Array = []; var seen := {}
	for a in tm.adj:
		var pa: Vector3 = tm.nodes[a]; var gy := Phys.ground_at(pa.x, pa.y + 0.6, pa.z, u.R)
		if absf(gy - pa.y) > 0.3 or Phys.collide_at(pa.x, gy + 0.05, pa.z, u.R, u.H) != null: bad.push_back("node " + a); continue
		pa.y = gy   # (on a stepped ramp the step under it can be a little higher)
		for ed: Array in tm.adj[a]:
			var b: String = ed[0]
			if seen.has(a + ">" + b): continue
			seen[a + ">" + b] = true
			var pb: Vector3 = tm.nodes[b]; u.pos = pa; u.vy = 0.0; u.vel = Vector3.ZERO; var ok := false
			for i in roundi((float(ed[1]) / 3.4 + 6.0) * 30.0):
				var d := Vector2(pb.x - u.pos.x, pb.z - u.pos.z)
				if d.length() < 1.0 and absf(pb.y - u.pos.y) < 1.0: ok = true; break
				var dn := d.normalized(); tm._move(u, dn.x * 3.4, dn.y * 3.4, 1.0 / 30.0)
			if not ok: bad.push_back("%s>%s at %s" % [a, b, str(u.pos.snapped(Vector3.ONE * 0.1))])
	return bad

func _team_modes(gm: Game, en: Enemies, pl: Player, g: Guns, pr: Proj, w: World, cam: Camera3D) -> void:
	var run := func(sec: float) -> void: _tick(gm, en, pl, g, pr, w, cam, sec)
	var money0: int = Store.save.money; var best0: Dictionary = (Store.save.best as Dictionary).duplicate()
	check("stage 5's modes: the sweep by default; a team mode is picked in the briefing and kept in the settings", ToyMatch.picked() == "sweep" and ToyMatch.MODES == ["sweep", "rush", "escort", "freeze"])
	# ---- the shared part, in the battery rush ----
	Store.settings.toyMode = "rush"; gm.begin(9); var tm: ToyMatch = gm.tm
	check("battery rush: our six blue soldiers (kept off the enemies' list) against twelve of the room's toys, each on its side", tm != null and tm.mode is ModeRush and tm.allies.size() == 6 and en.list.size() == 12 and gm.goal == 0
		and tm.allies.all(func(a): return a.k.team == "us" and not en.list.has(a)) and en.list.all(func(e): return e.k.team == "them"), [tm.allies.size(), en.list.size()])
	var a0: Enemies.Foe = tm.allies[0]; var ray_o := a0.pos + Vector3(0, 1.2, 5.0)
	check("our soldiers are blue, and nothing of yours hits them (your shots pass through)", (a0.k.mat as StandardMaterial3D).albedo_color.is_equal_approx(World.lin("203f8a")) and en.raycast(ray_o, Vector3(0, 0, -1), 20.0) == null)
	var bad_r := _walk_edges(tm)
	check("battery rush: every way the toys take round the room can be walked (floor, under the bed, desk, bridge, mattress, the stairs, the drops)", bad_r.is_empty(), bad_r)
	# their round hits ours; ours hits theirs and pays you nothing
	pl.invuln = 1e9; var e0: Enemies.Foe = en.list[0]; a0 = tm.allies[1]
	e0.pos = Vector3(-6, 0, 20); a0.pos = Vector3(-6, 0, 28); e0.g.position = e0.pos; a0.g.position = a0.pos; var hp_a := a0.hp
	pr.bullet(e0.pos + Vector3(0, 1.4, 0.6), a0.pos + Vector3(0, 1.0, 0), 80.0, 10.0, 0.0, "them")
	for i in 20: pr.update(1.0 / 30.0)
	check("their round hits one of ours", a0.hp < hp_a, [hp_a, a0.hp])
	var hp_e := e0.hp; var m_before: int = Store.save.money
	pr.bullet(a0.pos + Vector3(0, 1.4, -0.6), e0.pos + Vector3(0, 1.0, 0), 80.0, 2000.0, 0.0, "us")
	for i in 20: pr.update(1.0 / 30.0)
	check("ours hits theirs; downed by one of ours it pays you nothing (and comes back at its base later)", not e0.alive and Store.save.money == m_before and tm.queue.size() == 1 and int(tm.score.us) == 1, [hp_e, Store.save.money - m_before, tm.queue.size()])
	run.call(float(ToyMatch.BACK.them) + 0.2)
	check("...back at its base", en.list.filter(func(e): return e.alive).size() == 12 and en.list.any(func(e): return e.pos.z < -40.0))
	# you fall: down a few seconds, then back at the base, fresh
	var them0 := int(tm.score.them); pl.invuln = 0.0; pl.hp = 0.0; gm.update(0.02)
	check("you fall: down (no moving, no shooting), a point to them, not the end", pl.out and not gm.ended and int(tm.score.them) == them0 + 1, [them0, tm.score.them])
	var sh0 := g.shots; g.fire(); check("down, your gun does nothing", g.shots == sh0)
	run.call(ToyMatch.PLAYER_BACK + 0.2)
	check("...and back at your base a few seconds later, at full health", not pl.out and pl.hp == Player.MAX_HP and pl.pos.z > 40.0)
	# the batteries
	var R: ModeRush = tm.mode; pl.invuln = 1e9
	gm.begin(9); tm = gm.tm; R = tm.mode; pl.invuln = 1e9
	for u in tm.units("us") + tm.units("them"): u.speed = 0.0   # (everyone stands, so the checks are yours alone)
	run.call(ModeRush.FIRST_DROP + 0.1)
	check("battery rush: the first battery comes down %d s in, on the block bridge or the rug in the middle" % int(ModeRush.FIRST_DROP), R.batteries.size() == 1 and R.batteries[0].state == "fall")
	run.call(3.5)
	var bat: Dictionary = R.batteries[0]; var bp: Vector3 = bat.pos
	check("...and lands there, a light over it so you can find it", bat.state == "ground" and ((absf(bp.y - 9.0) < 0.1 and absf(bp.x + 14.0) < 3.0) or (absf(bp.y) < 0.1 and absf(bp.x + 6.0) < 3.0)) and (bat.beacon as Node3D).visible, bp)
	pl.reset(bp.x + 1.0, bp.z, 0.0); pl.pos.y = bp.y; pl.invuln = 1e9; g.reset(gm.layout()); g.cur = "rifle"
	run.call(0.6); var half := R.carry == null and R.pull > 0.3
	run.call(0.6)
	check("a second beside it pulls it free: in your arms", half and R.carry == bat and bat.state == "carried" and R.player_carrying())
	run.call(0.5)
	check("carrying it: the dart pistol and the ruler only, and a little slower", g.cur == "pistol" and g.lock_to == "pistol" and pl.carry_mul == ModeRush.CARRY_MUL)
	g.switch_to("rifle"); run.call(0.5); check("...the rifle stays away", g.cur == "pistol")
	var m1: int = Store.save.money; pl.pos = Vector3(0, 0, 50); run.call(0.2)
	check("in our fortress, by the robot: it goes into its chest (1 of 3), you are paid, your hands are free", int(R.slots.us) == 1 and R.carry == null and g.lock_to == "" and pl.carry_mul == 1.0 and Store.save.money == m1 + ModeRush.DELIVER_PAY * Store.PAY, [R.slots, Store.save.money - m1])
	# a carrier who falls drops it where he fell
	R.cmd(["carry"]); pl.pos = Vector3(-6, 0, 20); pl.invuln = 0.0; pl.hp = 0.0; gm.update(0.02); pl.invuln = 1e9
	var dropped: Array = R.batteries.filter(func(b): return b.state == "ground")
	check("down with a battery: it falls where you fell", dropped.size() >= 1 and Vector2(dropped[dropped.size() - 1].pos.x + 6.0, dropped[dropped.size() - 1].pos.z - 20.0).length() < 1.0 and R.carry == null and g.lock_to == "")
	run.call(ToyMatch.PLAYER_BACK + 0.2)
	# their carrier at their gate plugs his in, whether or not you are carrying one yourself
	pl.pos = Vector3(-6, 0, 20); R.cmd(["carry"]); R._drop(); var rb_b: Dictionary = R.batteries[R.batteries.size() - 1]; R._land(rb_b, (rb_b.land as Vector3).y)
	var rb_u = tm.units("them")[0]; R._take(rb_b, rb_u); rb_u.pos = ModeRush.ZONE.them; var rb_s0 := int(R.slots.them); run.call(0.2)
	check("battery rush: their carrier at their gate plugs his battery in even while you carry one", R.carry != null and int(R.slots.them) == rb_s0 + 1 and rb_u.k.carrying == null, [R.slots, R.carry != null])
	pl.pos = Vector3(0, 0, 50); run.call(0.2)   # (and yours goes in too, so the rest starts with your hands free)
	# three in: the robot wakes and burns their fortress down; you win
	var fort_box: Phys.Box = R.forts.them.boxes[0]; var m2: int = Store.save.money; Store.save.best.erase("t9r")
	R.cmd(["give", "us", "3"]); run.call(1.0)
	check("three in: our robot wakes (eyes lit, arms going up), and nobody fights while it does", R.phase == "wake" and (R.robots.us.eye_mat as StandardMaterial3D).emission_energy_multiplier > 2.0 and R.hold(tm.allies[0]))
	run.call(6.0)
	check("lasers and foam missiles: their fortress falls (its walls gone), and it is a win", bool(R.forts.them.down) and not Phys.colliders.has(fort_box) and gm.ended and gm.result == "clear")
	check("the win: its best time kept, the first win's bonus paid", Store.save.best.has("t9r") and Store.save.money == m2 + ModeRush.new().bonus(), Store.save.money - m2)
	# their three: a loss
	gm.begin(9); tm = gm.tm; R = tm.mode; pl.invuln = 1e9
	check("once won it pays no more (a replay)", gm.replay)
	var m3: int = Store.save.money; Store.save.money += 777; gm.stats.earned += 777
	R.cmd(["give", "them", "3"]); run.call(7.5)
	check("their robot wakes first: our fortress falls, it is a loss, and what you earned in there is gone", gm.ended and gm.result == "lost" and bool(R.forts.us.down) and Store.save.money == m3, [gm.result, Store.save.money - m3])
	gm.begin(9); tm = gm.tm; R = tm.mode; pl.invuln = 1e9; R.time_left = 0.5; run.call(1.0)
	check("the power runs out: a loss", gm.ended and gm.result == "lost" and R.lose_stamp == "전원 꺼짐")
	# ---- the train escort ----
	Store.settings.toyMode = "escort"; gm.begin(9); tm = gm.tm; var E: ModeEscort = tm.mode; pl.invuln = 1e9
	check("train escort: six of ours by the train on the carpet, twelve of theirs (three snipers up on the bookshelf and the wardrobe)", tm.allies.size() == 6 and en.list.size() == 12 and en.list.filter(func(e): return e.k.job == "nest" and e.pos.y >= 19.9).size() == 3)
	var bad_e := _walk_edges(tm)
	check("train escort: every way can be walked, up the spiral to the desk and down", bad_e.is_empty(), bad_e)
	check("the track: from the carpet's station through the tunnel under the bed, round the spiral, on along the desk (about 316 m); the spiral takes it 9 m up",
		absf(E.total - 316.6) < 1.0 and E.at(0.0).distance_to(Vector3(-38, 0, 52)) < 0.01 and absf(E.at(E.total).y - 9.0) < 0.01 and E.at(120.0).x == 28.0 and absf(E.at(120.0).z) < 30.0, [E.total, E.at(120.0)])
	for u in tm.units("us") + tm.units("them"): u.speed = 0.0; u.pos.x += 200.0 if false else 0.0
	for u in tm.units("us"): u.pos = Vector3(-60, 0, 60) + Vector3(randf(), 0, randf()); u.g.position = u.pos
	for u in tm.units("them"):
		if u.k.job != "nest": u.pos = Vector3(-50, 9, 0) + Vector3(randf(), 0, randf()); u.g.position = u.pos
	var wp := E.wagon_pos(); pl.reset(wp.x, wp.z + 4.0, 0.0); var d0 := E.d
	run.call(2.0)
	check("one of us beside it and none of them: it goes (1.6 m/s)", absf((E.d - d0) / 2.0 - ModeEscort.SPEED) < 0.15, (E.d - d0) / 2.0)
	var foe: Enemies.Foe = tm.units("them").filter(func(e): return e.k.job != "nest")[0]; wp = E.wagon_pos(); foe.pos = wp + Vector3(0, 0, -5); foe.g.position = foe.pos
	var d1 := E.d; run.call(1.0)
	check("one of them beside it too: it stands", absf(E.d - d1) < 0.01 and E.near_them >= 1)
	foe.pos = Vector3(-50, 9, 2); pl.pos = Vector3(-60, 0, 30); var d2 := E.d; run.call(ModeEscort.BACK_AFTER + 2.0)
	check("left alone it rolls back after %d s (half a metre a second)" % int(ModeEscort.BACK_AFTER), E.d < d2 - 0.6 and E.d > d2 - 1.5, d2 - E.d)
	# riding the wagon, the ammo box, a checkpoint
	E.cmd(["at", "150"]); wp = E.wagon_pos(); pl.reset(wp.x, wp.z, 0.0); pl.pos.y = wp.y + 0.46; pl.vel = Vector3.ZERO; pl.update(1.0 / 30.0, cam, 0.0)
	var p_on := pl.pos; var t0 := E.time_left; var m4: int = Store.save.money
	g.wstate.rifle.reserve = 0; run.call(4.0)
	check("you on the wagon go with it (stood behind its block walls)", pl.pos.distance_to(p_on) > 4.0 and absf(pl.pos.y - (E.wagon_pos().y + 0.45)) < 0.2, pl.pos.distance_to(p_on))
	check("past the corner after the tunnel: checkpoint 1, more time, paid", E.cp == 1 and E.time_left > t0 and Store.save.money == m4 + (0 if gm.replay else ModeEscort.CP_PAY * Store.PAY))
	check("by the ammo box on the wagon every gun fills up", float(g.wstate.rifle.reserve) == float(Custom.weapon("rifle").reserve))
	# traps
	pl.pos = Vector3(-60, 0, 30); E.cmd(["at", "60"]); E.idle_t = 0.0; wp = E.wagon_pos(); pl.reset(wp.x, wp.z - 3.0, 0.0)
	E.cmd(["trap", "tack", str(E.d + ModeEscort.ENGINE_AHEAD + 5.0)]); E.cmd(["trap", "mouse", str(E.d + ModeEscort.ENGINE_AHEAD + 8.5)])
	check("their traps lie on the track ahead: thumbtacks and a mousetrap", E.traps.size() == 2)
	run.call(2.0); var slow: bool = E.slow_t > 0.0
	run.call(6.0); var stopped: bool = E.stop_t > 0.0 or E.state().stop > 0.0
	check("the train crawls over the thumbtacks, and the mousetrap stops it dead", slow and (stopped or E.traps.is_empty()), [slow, E.stop_t])
	E.cmd(["trap", "mouse", str(E.d + 30.0)]); var tr: Dictionary = E.traps[E.traps.size() - 1]
	w.damage_crate(tr.rec, 200.0, tr.pos)
	check("a trap shot to bits is gone", tr.dead and E.traps.filter(func(t): return not t.dead).size() < E.traps.size() + 1 and not Phys.colliders.has(tr.rec.b))
	E.cmd(["at", str(E.total)]); run.call(0.2)
	check("the engine at the terminal: a win", gm.ended and gm.result == "clear")
	gm.begin(9); tm = gm.tm; E = tm.mode; pl.invuln = 1e9; pl.pos = Vector3(-60, 0, 30)
	for u in tm.units("us"): u.pos = Vector3(60, 0, -60); u.speed = 0.0
	E.time_left = 0.3; run.call(1.0)
	check("out of time with nobody of ours by the train: a loss", gm.ended and gm.result == "lost")
	# ---- bedtime ----
	Store.settings.toyMode = "freeze"; gm.begin(9); tm = gm.tm; var F: ModeFreeze = tm.mode; pl.invuln = 1e9
	check("bedtime: five of ours, eleven of theirs; the south wall has the room's door, and the hall behind it", tm.allies.size() == 5 and en.list.size() == 11 and F.door != null and F.giant != null)
	var bad_f := _walk_edges(tm)
	check("bedtime: every way can be walked", bad_f.is_empty(), bad_f)
	pl.reset(-20.0, 40.0, 0.0); pl.update(0.0, cam, 0.0)
	F.cmd(["visit"]); run.call(0.2)
	check("footsteps, the knob turns, an alarm: the warning", F.phase == "warn" and F.visits == 1)
	run.call(ModeFreeze.WARN + ModeFreeze.OPEN + 0.1)
	check("three seconds later the door is open and the owner leans in to look", F.phase == "look" and F.door.rotation.y < -1.5 and F.giant.rotation.x < -0.5 and w.toy.train_hold)
	var held_n := (tm.units("us") + tm.units("them")).filter(func(u): return F.hold(u)).size(); var all_n := (tm.units("us") + tm.units("them")).size()
	check("the toys keep still once they have heard it (now and then one is slow to)", held_n >= all_n - 4 and held_n > 0, [held_n, all_n])
	var box_us := int(F.boxed.us); var sc_them := int(tm.score.them)
	pl.in_f = 1.0; run.call(1.0); pl.in_f = 0.0
	check("you move while it looks: caught", F._is_caught(pl) or pl.out)
	run.call(1.5)
	check("the hand comes down and picks you up", pl.out and (pl.held or int(F.boxed.us) > box_us))
	run.call(4.0)
	check("...into the toy box: out of the fight, a point to them", pl.out and not pl.held and int(F.boxed.us) == box_us + 1 and int(tm.score.them) >= sc_them + 1 and absf(absf(pl.pos.x) - 47.0) < 3.0, [pl.pos, F.boxed])
	for i in roundi((ModeFreeze.BOX_BACK_YOU + 4.0) / 0.5):   # (no new visit meanwhile: coming back while it looks in would be another catch)
		if F.phase == "calm": F.next_t = 999.0
		run.call(0.5)
	check("...back at your base a long while later", not pl.out and pl.pos.z > 30.0 and pl.pos.x < 0.0, pl.pos)
	# back at your base in the middle of a look: it sees you where you are now (not where you were when it looked in), so standing still is safe
	for i in 20:
		if F.grab == null and F.caught.is_empty(): break
		run.call(0.5)
	F.phase = "calm"; F.caught.clear(); pl.reset(-20.0, 0.0, 0.0); pl.update(0.0, cam, 0.0); F.cmd(["look"]); run.call(0.1)
	var lk_on: bool = F.phase == "look"; pl.out = true; tm.down_t = 0.0; tm._player_back(); run.call(1.5)
	check("bedtime: back at your base while it looks in (40 m from where it first saw you), standing still: not caught", lk_on and not F._is_caught(pl) and not pl.out and not pl.held, [lk_on, F._is_caught(pl), pl.pos])
	# a toy of theirs moving while it looks is boxed: a point to us (everyone else keeping still: no soda on the floor or in the air, nobody still sliding)
	for i in 20:
		if F.grab == null: break
		run.call(0.5)
	for q in F.puddles + F.flying: (q.node as Node3D).queue_free()
	F.puddles.clear(); F.flying.clear()
	F.phase = "calm"; F.caught.clear(); F.cmd(["look"])
	for u in tm.units("us") + tm.units("them"): u.k.freeze_at = 0.0; u.k.erase("can_at"); u.k.slip = Vector2.ZERO; u.k.slip_t = 0.0
	var mover: Enemies.Foe = tm.units("them")[0]; mover.k.freeze_at = 99.0; mover.speed = 6.0; mover.k.hot = mover.pos + Vector3(8, 0, 0); mover.k.hot_t = 99.0
	var sc_us := int(tm.score.us); var bx_them := int(F.boxed.them); tm.queue.clear(); var mv_t := 0.0
	while mv_t < 30.0 and (en.list.has(mover) or (F.grab != null and F.grab.get("unit") == mover)): run.call(0.5); mv_t += 0.5   # (the hand takes them one at a time: off the field when it is picked up, counted when it is dropped in the box)
	check("one of theirs that moves while it looks goes into the box: off the field, a point to us (a point for every one of theirs boxed)",
		not en.list.has(mover) and int(F.boxed.them) >= bx_them + 1 and int(tm.score.us) - sc_us == int(F.boxed.them) - bx_them, [F.boxed, tm.score, mv_t])
	check("...and back on their side after a long wait", tm.queue.any(func(q): return q.team == "them" and float(q.t) > ModeFreeze.BOX_BACK - 3.0))
	# soda cans: whoever is in the puddle slides about
	for i in 20:
		if F.grab == null: break
		run.call(0.5)
	F.phase = "calm"; F.phase_t = 0.0; F.next_t = 999.0; F.visit_t = 0.0; tm.down_t = 0.0; pl.reset(-20.0, 30.0, 0.0); pl.invuln = 1e9; pl.update(0.0, cam, 0.0); cam.rotation = Vector3(-0.3, 0.0, 0.0); cam.position = pl.pos + Vector3(0, 1.62, 0)
	var cans0 := F.cans; var thrown := F.throw_can(); run.call(2.0)
	var vic: Enemies.Foe = tm.units("them")[0]; vic.speed = 0.0
	if not F.puddles.is_empty(): vic.pos = F.puddles[0].pos; vic.g.position = vic.pos
	var vp := vic.pos; run.call(1.0)
	check("a soda can: thrown, it bursts and the floor there gets slippery; a toy in it slides about", thrown and F.cans == cans0 - 1 and F.puddles.size() == 1 and vic.pos.distance_to(vp) > 0.8, [F.puddles.size(), vic.pos.distance_to(vp)])
	tm.score.us = ModeFreeze.TARGET; run.call(0.1)
	check("bedtime: the first side to %d points wins" % ModeFreeze.TARGET, gm.ended and gm.result == "clear")
	# back to the sweep for whatever follows
	Store.settings.toyMode = "sweep"; Store.save.money = money0; Store.save.best = best0; pl.in_f = 0.0
	gm.begin(9); check("the sweep again: the hundred toys, no team mode", gm.tm == null and en.list.size() == 100)

## stage 5's music (tools/make_music.py, scripts/music.gd): the files, and the player's states fed by hand with the audio's
## time (Music.update's dt), as Main feeds them a frame at a time
func _music(gm: Game, en: Enemies, pl: Player, w: World) -> void:
	var M := Music; M.keep_log = true; M.log.clear()
	var keep_vol := M.volume; var keep_svol := Snd.volume; var keep_lis := Snd.listener; M.volume = 0.6; Snd.volume = 0.7
	# the files: the march's six layers are 16 bars at 120 (32 s), the overtime's seven the same 16 bars at 150 (25.6 s), the
	# briefing's music box 24 s, each looping whole; the drum's lead-in, the bell and the two trumpets once
	var bad := []
	for k in Music.LAYERS + ["alarm"]:
		for pre in ["m_", "o_"]:
			if pre == "m_" and k == "alarm": continue
			var s: AudioStream = (M._n if pre == "m_" else M._o)[k].stream
			var want := Music.LOOP if pre == "m_" else Music.OT_LOOP
			if s == null or not (s is AudioStreamOggVorbis) or absf(s.get_length() - want) > 0.001 or not (s as AudioStreamOggVorbis).loop: bad.push_back(pre + k)
	for one in ["leadin", "ot_bell", "trumpet_us", "trumpet_them"]:
		if not ResourceLoader.exists("res://music/%s.ogg" % one): bad.push_back(one)
	var lob: AudioStream = M._lobby.stream
	check("stage 5's music: the march's six layers 16 bars at 120 (32 s), the overtime's seven at 150 (25.6 s), the briefing's music box (24 s), all looping; the lead-in, bell and trumpets",
		bad.is_empty() and lob != null and absf(lob.get_length() - 24.0) < 0.001 and (lob as AudioStreamOggVorbis).loop and Music.LOOP == 32.0 and is_equal_approx(Music.OT_LOOP, 25.6), bad)
	var mb := AudioServer.get_bus_index("Music"); var mlp := AudioServer.get_bus_effect(mb, 0) as AudioEffectLowPassFilter
	check("the music has its own bus, straight to the master (past the sounds' compressor), with a low-pass that is off until needed",
		mb == Snd.music_bus and mb > 0 and AudioServer.get_bus_send(mb) == "Master" and mlp != null and not AudioServer.is_bus_effect_enabled(mb, 0) and M._n.war.bus == &"Music", mb)
	var run := func(ctx: Dictionary, sec: float) -> void:
		for i in roundi(sec / 0.05): M.update(0.05, ctx, 0.05)
	var base := {"what": "march", "paused": false, "spawn": false, "bed": false, "near": 0, "shots": 0, "hp": 1000.0, "ot": false, "teams": true}
	run.call({}, 3.0)
	run.call({"what": "lobby"}, 1.5); var s_lob: Dictionary = M.status()
	check("the music: the briefing plays the music box alone", s_lob.what == "lobby" and s_lob.playing == ["lobby"], s_lob.playing)
	run.call(base, 0.05); var s_lead: Dictionary = M.status()
	check("going in: the tin drum, the march's six layers already going round with it, silent, two bars before their first",
		s_lead.what == "leadin" and s_lead.playing.has("leadin") and Music.LAYERS.all(func(k): return s_lead.playing.has("m_" + k)) and absf(s_lead.t - (Music.LOOP - Music.LEADIN + 0.05)) < 1e-3
		and M.fade == 0.0 and M._n.war.volume_db < -80.0, s_lead)
	run.call(base, Music.LEADIN - 0.05); var s_kick: Dictionary = M.status()
	check("the drum done: the march from its first bar, the whole band for its first four bars", s_kick.what == "march" and s_kick.state == "battle" and s_kick.t < 0.06 and s_kick.level.war == 1.0 and M.fade == 1.0
		and M._n.war.volume_db > -30.0, s_kick)
	run.call(base, Music.KICKOFF + 3.0); var s_ex: Dictionary = M.status()
	check("then, on the move: the xylophone and pizzicato over the wood block, the boomwhackers lightly; no kazoos, no music box",
		s_ex.state == "explore" and absf(s_ex.level.xylo - 1.0) < 0.02 and absf(s_ex.level.beat - 0.85) < 0.02 and absf(s_ex.level.bass - 0.55) < 0.02 and s_ex.level.war < 0.02 and s_ex.level.box < 0.02, s_ex)
	var bed := base.duplicate(); bed.bed = true; run.call(bed, 3.0); var s_bed: Dictionary = M.status()
	check("under the bed: only the boomwhackers and the clock's tick-tock, the music's bus through a low-pass (900 Hz)",
		s_bed.state == "bed" and s_bed.level.bass > 0.98 and s_bed.level.tick > 0.98 and s_bed.level.xylo < 0.02 and s_bed.level.war < 0.02 and absf(s_bed.lp - 900.0) < 5.0
		and AudioServer.is_bus_effect_enabled(mb, 0) and absf(mlp.cutoff_hz / s_bed.lp - 1.0) < 0.02, s_bed)
	run.call(base, 3.0)
	check("out from under it: the filter opens and goes off", M.lp > 18000.0 and not AudioServer.is_bus_effect_enabled(mb, 0), M.lp)
	var fight := base.duplicate(); fight.near = 3; run.call(fight, 2.0); var f1: String = M.state; var fw: float = M.level.war
	fight.near = 0; run.call(fight, 1.0); var f2: String = M.state; run.call(fight, 8.0); var f3: String = M.state
	check("three enemies about you: the whole band (kazoos and recorders, tin drum, toy piano); it holds a moment after, then back to the march on the move",
		f1 == "battle" and fw > 0.9 and f2 == "battle" and f3 == "explore", [f1, fw, f2, f3])
	var shoot := base.duplicate(); var sh := 0
	for i in 40: sh += 1; shoot.shots = sh; M.update(0.05, shoot, 0.05)
	var f4: String = M.state; run.call(shoot, 10.0)
	var hurt := base.duplicate(); hurt.shots = sh; run.call(hurt, 0.5)
	for i in 3: hurt.hp = 1000.0 - 100.0 * (i + 1); run.call(hurt, 0.3)
	check("firing away (20 shots in two seconds) is a fight too, and so is being hit", f4 == "battle" and M.state == "battle", [f4, M.state, M.heat])
	run.call(hurt, 10.0)
	var down := base.duplicate(); down.spawn = true; run.call(down, 3.0); var s_sp: Dictionary = M.status()
	run.call(base, 2.0); var sp2: String = M.state; run.call(base, 4.0); var sp3: String = M.state
	check("down and waiting to come back: the music box, its wood block, a clock far off; back at your base a few seconds more, then the march on the move",
		s_sp.state == "spawn" and s_sp.level.box > 0.9 and absf(s_sp.level.tick - 0.45) < 0.03 and s_sp.level.xylo < 0.05 and sp2 == "spawn" and sp3 == "explore", [s_sp.state, sp2, sp3])
	# the overtime: the other set started silent where it will be at the next bar line, heard from that bar line
	var ot := base.duplicate(); ot.ot = true; M.log.clear()
	M.update(0.05, ot, 0.05); var o_prep: bool = M.switching; var o_at: float = M.t_next; var o_in: float = M.switch_in; var o_play: bool = M._o.war.playing and M._o.alarm.playing
	var o_wait := 0.0
	while not M.ot and o_wait < 3.0: M.update(0.05, ot, 0.05); o_wait += 0.05
	run.call(ot, 0.3); var s_ot: Dictionary = M.status()
	check("the last 30 seconds: the march 1.25 times as fast and a semitone up, its set started silent and taken over at the next bar line (the same bar), the alarm clock hurrying, the bell",
		o_prep and o_play and o_in > -0.06 and o_in <= Music.BAR + 1e-6 and absf(o_at / Music.OT_BAR - roundf(o_at / Music.OT_BAR)) < 1e-6 and o_wait <= Music.BAR + 0.06 and s_ot.ot and s_ot.w_ot == 1.0
		and not M._n.war.playing and M._o.alarm.playing and M._o.alarm.volume_db > -40.0 and M.log.has("shot ot_bell") and absf(s_ot.t - (o_at + 0.3)) < 0.06, [o_in, o_at, o_wait, s_ot.t, M.log])
	run.call(ot, 12.0)
	check("and the two sides' toy trumpets now and then", M.log.any(func(l): return str(l).begins_with("shot trumpet_")), M.log)
	var back := base.duplicate(); var b_wait := 0.0
	while M.ot and b_wait < 3.0: M.update(0.05, back, 0.05); b_wait += 0.05
	run.call(back, 0.3)
	check("time put back on the clock (a checkpoint): the march as it was, at the next bar line", not M.ot and b_wait <= Music.OT_BAR + 0.06 and M._n.war.playing and not M._o.war.playing, [b_wait, M.ot])
	# a blast close by: the tape stretches
	Snd.listener = Vector3.ZERO; M.blast(Vector3(10, 0, 0)); run.call(base, 0.5); var tp0: float = M.pitch
	M.blast(Vector3(3, 0, 0)); run.call(base, 0.5); var tp1: float = M.pitch; var tpv: float = M._n.xylo.pitch_scale
	run.call(base, 1.1); var tp2: float = M.pitch
	check("a blast within 6 m: the music's tape stretches (down to 0.62 and back up over 1.5 s); one 10 m off leaves it be",
		tp0 == 1.0 and absf(tp1 - Music.TAPE_LOW) < 1e-6 and absf(tpv - tp1) < 1e-5 and tp2 == 1.0 and Music.tape_pitch(0.0) == 1.0 and Music.tape_pitch(Music.TAPE) == 1.0 and Music.tape_pitch(1.1) > Music.TAPE_LOW, [tp0, tp1, tp2])
	var ps := base.duplicate(); ps.paused = true; var v_play: float = M._n.xylo.volume_db; run.call(ps, 0.2); var v_pause: float = M._n.xylo.volume_db
	M.volume = 0.0; run.call(base, 0.2); var v_off: float = M._n.xylo.volume_db; M.volume = 0.6
	check("paused, the music goes quieter (-8 dB); the 음악 setting at 0, silent", absf((v_pause - v_play) - linear_to_db(0.4)) < 0.2 and v_off < -90.0, [v_play, v_pause, v_off])
	var st_ui := Ui.new(); add_child(st_ui); var st_box := VBoxContainer.new(); st_ui.add_child(st_box); st_ui._settings_rows(st_box, true)
	var st_labels := []
	for n9 in st_box.find_children("*", "Label", true, false): st_labels.push_back((n9 as Label).text)
	st_ui.queue_free()
	check("the settings: 음악 under 음량 (stage 5's music, 70 to start with)", st_labels.has("음악") and st_labels.find("음악") == st_labels.find("음량") + 2 and float(Store.settings.get("music", -1.0)) >= 0.0
		and str(load("res://scripts/store.gd").source_code).contains('"music": 0.7'), st_labels)
	run.call({}, 2.5); var s_end: Dictionary = M.status()
	check("anywhere but stage 5: nothing", s_end.what == "" and s_end.playing.is_empty(), s_end.playing)
	# what Main tells it (Main.music_for), and the blasts that reach it from the toy room
	var mn = load("res://scripts/main.gd")
	Store.settings.toyMode = "escort"; gm.begin(9); var m_tm = gm.tm
	var c_play: Dictionary = mn.music_for("playing", true, m_tm, false, Vector3(30, 0, 0), false, 2, 5, 900.0)
	var c_bed_up: Dictionary = mn.music_for("playing", true, m_tm, false, Vector3(30, 6.5, 0), false, 0, 0, 1000.0)
	var c_out: Dictionary = mn.music_for("playing", true, m_tm, false, Vector3(5, 0, 0), true, 0, 0, 1000.0)
	var under := Phys.raycast_static(Vector3(30, 1, 0), Vector3.UP, 10.0); var under_t := Phys.rh_t
	check("Main's word to it: the briefing's and the results' music box; in play the march, under the bed beneath the bed's frame (not on the mattress), down and waiting, paused; nothing elsewhere",
		mn.music_for("brief", true, null, false, Vector3.ZERO, false, 0, 0, 0.0) == {"what": "lobby"} and mn.music_for("gameover", true, null, false, Vector3.ZERO, false, 0, 0, 0.0) == {"what": "lobby"}
		and mn.music_for("playing", false, null, false, Vector3.ZERO, false, 0, 0, 0.0).is_empty() and mn.music_for("menu", true, null, false, Vector3.ZERO, false, 0, 0, 0.0).is_empty()
		and c_play.what == "march" and c_play.bed and c_play.near == 2 and c_play.shots == 5 and not c_play.spawn and not c_bed_up.bed and not c_out.bed and c_out.spawn
		and mn.music_for("paused", true, null, false, Vector3.ZERO, false, 0, 0, 0.0).paused and under and absf(under_t - 3.4) < 0.01, [c_play, under_t])
	if m_tm != null:
		m_tm.mode.time_left = 25.0; var c_ot: Dictionary = mn.music_for("playing", true, m_tm, false, Vector3.ZERO, false, 0, 0, 0.0)
		m_tm.mode.time_left = 31.0; var c_no: Dictionary = mn.music_for("playing", true, m_tm, false, Vector3.ZERO, false, 0, 0, 0.0)
		var c_end: Dictionary = mn.music_for("playing", true, m_tm, true, Vector3.ZERO, false, 0, 0, 0.0)
		check("the overtime is the clock's last 30 seconds of a team mode (not after it is over)", c_ot.ot and not c_no.ot and not c_end.ot and c_ot.teams, [c_ot.ot, c_no.ot])
	# a wind-up car's battery bursting by you, in a match: the tape
	Store.settings.toyMode = "sweep"; gm.begin(9); run.call(base, Music.LEADIN + 0.5); M.log.clear()
	var rc = en.list.filter(func(e): return e.type == "rc")[0]
	pl.pos = Vector3(rc.pos.x + 1.5, rc.pos.y, rc.pos.z); Snd.listener = pl.pos; pl.invuln = 1e9; en.toys.rc_burst(rc); var t_rc: bool = M.log.has("tape")
	check("a wind-up car's battery bursting by you: the music's tape stretches", t_rc, M.log)
	run.call({}, 2.5)
	M.volume = keep_vol; Snd.volume = keep_svol; Snd.listener = keep_lis; M.keep_log = false; pl.invuln = 0.0

## the phone app (tools/build_android.sh): what the game does differently there, and how its export is set up
func _mobile() -> void:
	var mn = load("res://scripts/main.gd")
	var acts := [mn.back_action("playing", "", false), mn.back_action("paused", "map", false), mn.back_action("paused", "pause", false), mn.back_action("paused", "shop", true),
		mn.back_action("menu", "shop", true), mn.back_action("menu", "menu", false), mn.back_action("brief", "brief", false), mn.back_action("gameover", "over", false),
		mn.back_action("cutscene", "", false), mn.back_action("shot", "", false)]
	check("the phone's back button, as Esc: a fight pauses; the map, a screen opened from another and the pause itself close; the briefing and the results go back to the menu; the menu leaves the app; a cutscene is skipped",
		acts == ["pause", "close_map", "resume", "close", "close", "quit", "menu", "menu", "skip", "none"], acts)
	check("a phone app's page units are its screen's density over 160 dpi (a 420 dpi phone: 2.625, its browser's pixel ratio)",
		is_equal_approx(mn.phone_ratio(420), 2.625) and mn.phone_ratio(100) == 1.0 and mn.phone_ratio(160) == 1.0 and mn.phone_ratio(2000) == 4.0)
	check("the phone app: landscape either way round (as the old app), the back button left to the game, ETC2/ASTC as Android's export asks",
		int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE and not bool(ProjectSettings.get_setting("application/config/quit_on_go_back"))
		and bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")))
	var cfg := ConfigFile.new(); var err := cfg.load("res://export_presets.cfg"); var sec := ""
	for s9 in cfg.get_sections():
		if s9.begins_with("preset.") and not s9.ends_with(".options") and cfg.get_value(s9, "platform", "") == "Android": sec = s9 + ".options"
	var keys: PackedStringArray = cfg.get_section_keys(sec) if sec != "" else PackedStringArray()
	var secret := false
	for k in keys:
		if (k.begins_with("keystore/") or k.contains("password")) and str(cfg.get_value(sec, k)) != "": secret = true
	check("the Android export: the old app's package (the new app updates it), signed, a version code past the old app's 29, vibration, full screen, 64-bit and 32-bit ARM; no key or password in the file",
		err == OK and sec != "" and cfg.get_value(sec, "package/unique_name") == "app.yard07.game" and cfg.get_value(sec, "package/signed") == true and int(cfg.get_value(sec, "version/code")) > 29
		and cfg.get_value(sec, "permissions/vibrate") == true and cfg.get_value(sec, "screen/immersive_mode") == true and cfg.get_value(sec, "architectures/arm64-v8a") == true
		and cfg.get_value(sec, "architectures/armeabi-v7a") == true and not secret, sec)
	var ins: Array = mn.insets_of(Rect2(96, 0, 2304, 1080), Vector2(2400, 1080), 2.625)   # (a camera hole on the left: 96 px of a 2400 x 1080 screen)
	var s9 := Vector2(914, 411); var z4 := [0.0, 0.0, 0.0, 0.0]
	var r0: Dictionary = mn.touch_rects_for(s9, z4); var r1: Dictionary = mn.touch_rects_for(s9, ins)
	var b0: Dictionary = mn.touch_buttons_for(s9, z4, false); var b1: Dictionary = mn.touch_buttons_for(s9, [0.0, 0.0, 30.0, 12.0], false)
	check("a phone app keeps its touch controls clear of a camera hole (Android 15 on draws the game under it): the pad and the pause move in by the hole; without one, all where they were",
		absf(ins[0] - 96.0 / 2.625) < 1e-4 and ins[1] == 0.0 and ins[2] == 0.0 and ins[3] == 0.0 and r0.pad == Rect2(10, s9.y / 2.0 - 78.0, 156, 156) and r0.pause == Rect2(16, 14, 42, 42)
		and r0.map == Rect2(s9.x - 60.0, 14, 46, 46) and is_equal_approx(r1.pad.position.x, 10.0 + ins[0]) and is_equal_approx(r1.pause.position.x, 16.0 + ins[0])
		and is_equal_approx((b1.fire[0] as Vector2).x, (b0.fire[0] as Vector2).x - 30.0) and is_equal_approx((b1.fire[0] as Vector2).y, (b0.fire[0] as Vector2).y - 12.0), [ins, r1.pad])
	# a finger on the menus (the phone app, a phone's browser): Godot's lists, sliders, gun boxes and text boxes follow a finger
	# only as the mouse it also comes as; the game itself reads the finger (tests/touch.tscn drags a real finger over them)
	var fm := InputEventMouseButton.new(); fm.device = InputEvent.DEVICE_ID_EMULATION; var rm := InputEventMouseButton.new(); var ft := InputEventScreenTouch.new()
	check("a finger also comes as the mouse, so the menus' lists scroll, sliders slide, gun boxes pick and text boxes type; the game itself reads only the finger (its mouse copy never aims or fires)",
		bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")) and not mn.game_reads(fm) and mn.game_reads(rm) and mn.game_reads(ft))
	var tu := Ui.new(); tu.is_touch = true; add_child(tu); tu._build_loadout(); tu._build_shop(); tu._build_settings(); tu._build_dialog()
	tu.render_loadout(); tu.shop_ctx = 1; tu.render_shop(); tu.render_settings(); tu.open_dialog("load")
	var t_lists: Array = []
	for k9 in ["loadout", "shop", "settings", "dlg"]:   # (each sheet's own list, not those inside a gun box's drop-down, a window of its own)
		t_lists.append_array((tu.screens[k9] as Control).find_children("*", "ScrollContainer", true, false).filter(func(s): return (s as Node).get_viewport() == tu.get_viewport()))
	var t_pass := true; var t_keep := 0; var t_obs := 0; var t_rel := true; var t_slop := true; var t_rows := 0
	for sc9 in t_lists:
		t_slop = t_slop and is_equal_approx((sc9 as ScrollContainer).scroll_deadzone, Ui.TOUCH_SLOP)
		for c9 in (sc9 as Node).find_children("*", "Control", true, false):
			if c9 is ScrollBar or (c9 as Node).get_viewport() != tu.get_viewport(): continue
			if c9 is Slider or c9 is LineEdit:
				if (c9 as Control).mouse_filter == Control.MOUSE_FILTER_STOP: t_keep += 1
				else: t_pass = false
				continue
			if (c9 as Control).mouse_filter == Control.MOUSE_FILTER_STOP: t_pass = false
			if c9 is PanelContainer: t_rows += 1
			if c9 is OptionButton: t_obs += 1; t_rel = t_rel and (c9 as BaseButton).action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE
	var du := Ui.new(); add_child(du); du._build_loadout(); du.render_loadout(); var d_obs: Array = (du.screens.loadout as Control).find_children("*", "OptionButton", true, false)
	var d_press := d_obs.size() == 7 and d_obs.all(func(o): return (o as BaseButton).action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS and (o as Control).mouse_filter == Control.MOUSE_FILTER_PASS)
	check("the menus' lists on a phone: all in them (buttons, gun boxes, shop rows) lets a finger's press through to the list, so a drag that starts on any of it scrolls; sliders and text boxes keep their own; a gun box opens as the finger lifts; a finger moves 10 points before it scrolls; a computer's gun boxes still open as the mouse goes down",
		t_lists.size() == 4 and t_pass and t_keep >= 4 and t_obs >= 7 and t_rel and t_slop and t_rows > 10 and d_press, [t_lists.size(), t_pass, t_keep, t_obs, t_rel, t_slop, t_rows, d_press])
	tu.close_sub(); tu.queue_free(); du.queue_free()
	var fg := Image.load_from_file("res://mobile/icon_fg.png"); var bg := Image.load_from_file("res://mobile/icon_bg.png")
	check("the app's adaptive icon: the old app's foreground on its night blue, 432 px each", fg != null and bg != null and fg.get_size() == Vector2i(432, 432) and bg.get_size() == Vector2i(432, 432)
		and bg.get_pixel(10, 10).is_equal_approx(Color("0d1220")))

# ---------------- the bug note's 15-20 (godot/BUGS.md), fixed in 1.5.3 ----------------
func _fixes_153(gm: Game, en: Enemies, pl: Player, g: Guns, pr: Proj, cam: Camera3D, fxn: Fx) -> void:
	var keep_save: Dictionary = Store.save.duplicate(true); var keep_cam := cam.global_transform
	# 15: the briefing and the result sheet are drawn again when you come back to them
	Store.save = Store.save0(); Store.save.loadout = [null, null, null, null, null, null, null]; Store.save.money = 50000
	var fu := Ui.new(); var fg := Game.new(); fu.game = fg   # (with the game's own fonts; freed at once when done, so it is never drawn without its map)
	fu.f_title = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"); fu.f_body = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-Regular.ttf")
	fu.f_bold = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"); fu.f_mono = load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf")
	add_child(fu); fu._build_brief(); fu._build_loadout(); fu._build_shop(); fu._build_over(); fu._build_dialog()
	fu.sel = 1; fu.show_screen("brief"); var b_shut: bool = fu.br_go.disabled
	fu.open_sub("loadout"); Store.save.loadout[0] = "pistol"; fu.back()   # (a gun put in, the layout left by Esc or the back button)
	check("bug 15: a briefing come back to from the weapon layout is drawn again: the gun put in is listed and 출동 opens",
		b_shut and fu.cur == "brief" and not fu.br_go.disabled and fu.br_gear.text.contains("1 " + Weapons.LIST.pistol.short), [b_shut, fu.cur, fu.br_go.disabled, fu.br_gear.text])
	fu.show_result("dead"); var ov0: String = (fu.ov.best as Label).text
	fu.shop_ctx = 1; fu.open_sub("shop"); Store.save.money += 120000; fu.back()   # (as if ivory were sold in the shop)
	check("bug 15: the result sheet come back to from the shop shows the bag as it is now",
		ov0.ends_with("가방 " + Store.won(50000)) and fu.cur == "over" and (fu.ov.best as Label).text.ends_with("가방 " + Store.won(170000)), [ov0, (fu.ov.best as Label).text])
	# 16: the reset and the save start on 취소/닫기, the load and the password on 확인 (and then their box)
	var focus_on := {}
	for kd in ["reset", "save", "load", "dev"]:
		fu.open_dialog(kd); fu._focus_first(fu.screens.dlg)
		focus_on[kd] = "cancel" if fu.dlg_cancel.has_focus() else ("ok" if fu.dlg_ok.has_focus() else "none")
		fu.close_sub()
	check("bug 16: the reset's and the save's first focus is 취소/닫기 (one Enter or Space wipes nothing), as the browser game's; the load and the password start on their own button",
		focus_on == {"reset": "cancel", "save": "cancel", "load": "ok", "dev": "ok"}, focus_on)
	# 17: in a fight the weapon layout is not left with no gun in it, however it is closed
	fu.in_stage = true; fu.show_screen("brief"); fu.back_stack.clear(); Store.save.loadout = [null, null, null, null, null, null, null]
	fu.open_sub("loadout"); fu.lo_msg.text = ""; fu.back(); var l_back: String = fu.cur; var l_msg: String = fu.lo_msg.text
	var done_b: Button = null
	for b9 in (fu.screens.loadout as Control).find_children("*", "Button", true, false):
		if (b9 as Button).text == "완료": done_b = b9
	fu.lo_msg.text = ""; done_b.pressed.emit(); var l_done: String = fu.cur; var l_msg2: String = fu.lo_msg.text
	Store.save.loadout[0] = "pistol"; fu.back(); var l_ok: String = fu.cur; fu.in_stage = false
	check("bug 17: in a fight the weapon layout is not shut with no gun in it, by Esc or the back button as by 완료; with a gun in it, it shuts",
		l_back == "loadout" and l_done == "loadout" and l_msg == "싸우는 중에는 무기를 하나 이상 넣어야 합니다" and l_msg2 == l_msg and l_ok == "brief", [l_back, l_done, l_msg, l_ok])
	# 18: stage 5's shop rents no gun (the toy room hands you its nine toy guns), and what you rented waits for the next stage
	var presses := func() -> Array:
		var out := []
		for b9 in fu.shop_list.find_children("*", "Button", true, false):
			var t9: String = (b9 as Button).text
			if t9 == "대여" or t9 == "대여 취소" or t9 == "무기 편성" or t9.begins_with("총알 +100") or t9.begins_with("로켓 +1"): out.push_back(t9)
		return out
	var says := func() -> String:
		var out := ""
		for l9 in fu.shop_list.get_children():
			if l9 is Label: out += (l9 as Label).text + "|"
		return out
	Store.save = Store.save0(); Store.save.money = 1000000; Store.save.rented = ["gl"]; Store.save.loadout = ["pistol", "gl", null, null, null, null, null]
	fg.stage = 9; fu.back_stack = ["brief"]; fu.shop_ctx = 9; fu.render_shop(); var t_brief: Array = presses.call(); var t_say: String = says.call()
	fu.in_stage = true; fu.back_stack = ["pause"]; fu.render_shop(); var t_pause: Array = presses.call(); fu.in_stage = false
	fg.stage = 1; fu.back_stack = ["brief"]; fu.shop_ctx = 1; fu.render_shop(); var t_one: Array = presses.call()
	check("bug 18: stage 5's shop (from its briefing or its pause) has no gun to rent, cancel, load or put in the layout, and says why; another stage's has",
		t_brief.is_empty() and t_pause.is_empty() and t_say.contains("장난감 방에서는 장난감 총만 씁니다") and t_one.has("대여") and t_one.has("대여 취소"), [t_brief, t_pause, t_one.size(), t_say.left(160)])
	var rr := Game.new(); rr.stage = 9; rr.deployed = true; rr.return_rentals(); var r9: Array = (Store.save.rented as Array).duplicate()
	rr.stage = 1; rr.deployed = true; rr.return_rentals()
	check("bug 18: a rental is not used up by stage 5 (its toy guns only): it waits for the next stage, and goes back when that one ends",
		r9 == ["gl"] and not rr.deployed and (Store.save.rented as Array).is_empty(), [r9, Store.save.rented])
	fu.back_stack.clear(); fu.free()
	# 19: what the guided rocket locks on to
	var fk := Enemies.Foe.new(); fk.g = Node3D.new(); fk.dist = 100.0
	var lk := [en.lockable(fk)]
	fk.ridden = true; lk.push_back(en.lockable(fk)); fk.ridden = false
	fk.caged = true; lk.push_back(en.lockable(fk)); fk.caged = false
	fk.g.visible = false; lk.push_back(en.lockable(fk)); fk.g.visible = true
	fk.T = {"mode": "mine"}; fk.bs = "hidden"; lk.push_back(en.lockable(fk)); fk.bs = ""; lk.push_back(en.lockable(fk)); fk.bs = "run"; lk.push_back(en.lockable(fk)); fk.T = {}; fk.bs = ""
	fk.toy = true; fk.type = "soldier"; fk.k = {"still": ToyFoes.CAMO_AFTER + 1.0, "reveal": 0.0, "gone": false}; lk.push_back(en.lockable(fk))
	fk.dist = 5.0; lk.push_back(en.lockable(fk)); fk.k.gone = true; lk.push_back(en.lockable(fk)); fk.g.free()
	check("bug 19: what a guided rocket may lock on to, as the browser game's: not a beast you ride, one in a cage, one too far off to be drawn, a spider mine lying buried or not yet set (one running at you it may), nor in stage 5 a toy soldier gone in its blink or hiding farther off than its bar shows",
		lk == [true, false, false, false, false, false, true, false, true, false], lk)
	Store.save = Store.save0(); gm.begin(4); var lm = null; var lo := Vector3.ZERO
	for e9 in en.list:
		if not (e9.alive and e9.type == "mine" and e9.bs == "hidden"): continue
		e9.pos.y = float(e9.k.baseY)   # (on the floor, as when it wakes: only its state differs between the two looks)
		var c9: Vector3 = pr.rocket_centre(e9)
		for off: Vector3 in [Vector3(0, 1.6, 6), Vector3(6, 1.6, 0), Vector3(0, 1.6, -6), Vector3(-6, 1.6, 0)]:
			if Phys.line_of_sight(c9 + off, c9): lm = e9; lo = c9 + off; break
		if lm != null: break
		e9.pos.y = float(e9.k.baseY) - 0.16
	var lk_hid = null; var lk_run = null
	if lm != null:
		cam.global_position = lo; cam.look_at(pr.rocket_centre(lm)); lk_hid = g.rocket_lock(); lm.bs = "run"; lk_run = g.rocket_lock(); lm.bs = "hidden"
	check("bug 19: in stage 4 the lock passes over a spider mine lying buried in the middle of the sights, and takes it once it is up and running",
		lm != null and lk_hid != lm and lk_run == lm, [lm != null, lk_hid == lm, lk_run == lm])
	# 20: 1-2's flamethrower man's fire, and the cache of screen colours
	var keep_fx = en.fx; en.fx = fxn; gm.begin(5); pl.invuln = 1e9; var fm = null
	for e9 in en.list:
		if e9.alive and e9.kit == "flame": fm = e9; break
	Fx._shown.clear(); var f_cols := -1; var f_specks := 0
	if fm != null:
		for i in 120: fm.flame_on = 1.0; en._fight(fm, 1.0 / 60.0, 5.0)
		f_cols = Fx._shown.size(); f_specks = fxn._glow.p.size()
	en.fx = keep_fx
	Fx._shown.clear()
	for i in 200: Fx.shown(Color(1.0, 0.5 + i * 1e-5, 0.1))
	var f_near := Fx._shown.size()
	for i in Fx.SHOWN_MAX + 40: Fx.shown(Color(float(i & 63) / 63.0, float((i >> 6) & 63) / 63.0, 0.5))
	check("bug 20: 1-2's flamethrower man's fire (360 specks in 2 s) has its screen colours worked out six times at most; colours nearer than 1/255 share one; and the cache is let go of past 2,048 colours",
		fm != null and f_specks > 0 and f_cols >= 1 and f_cols <= Enemies.FLAME_COLS.size() and f_near == 1 and Fx._shown.size() <= Fx.SHOWN_MAX, [f_cols, f_specks, f_near, Fx._shown.size()])
	Fx._shown.clear(); Store.save = keep_save; cam.global_transform = keep_cam

# ---------------- the bug note's 11-14 (godot/BUGS.md), fixed in 1.5.4 (the fight standing still once you fall, and the
# touch buttons let go in a pause, are checked with the whole game in tests/fight.gd and tests/touch.gd) ----------------
func _fixes_154(gm: Game, en: Enemies, pl: Player, w: World) -> void:
	var keep_save: Dictionary = Store.save.duplicate(true); var keep_down: Callable = gm.on_down
	# 11: falling tells the game's frame at once (it stops the fight there and then), and a run already over gets nothing
	Store.save = Store.save0(); gm.begin(1); var downs := []
	gm.on_down = func(k: String) -> void: downs.push_back(k)
	pl.jet_on = true; gm.over("dead")
	var c_owned: Array = (Store.save.owned as Array).duplicate(); gm.open_chest()
	check("bug 11: falling tells the game's frame at once (as the browser game's, the fight stops there and then) and ends the jetpack; a chest opened after takes nothing",
		downs == ["dead"] and not pl.jet_on and Store.save.owned == c_owned, [downs, pl.jet_on, Store.save.owned])
	gm.on_down = keep_down
	gm.begin(4); var shp: Ship = w.ship
	for o in en.list:
		if o.type == "gdrone": o.alive = false   # (the key lies there only once the gold bee is down)
	pl.pos = Vector3(Ship.KEY.x + 1.0, Phys.ground_at(Ship.KEY.x + 1.0, 1.0, Ship.KEY.z, Player.R), Ship.KEY.z)
	gm.ended = true; var k_over: bool = shp.take_key(); var k_had: bool = shp.key
	gm.ended = false; var k_live: bool = shp.take_key()
	check("bug 11: stage 4's key is not taken once the run is over (no save point without a bag to go back to); in the fight it is",
		not k_over and not k_had and k_live and shp.key, [k_over, k_had, k_live])
	var mn = load("res://scripts/main.gd")
	check("bug 11: in the second after you fall the phone's back button does nothing (the result is on its way)", mn.back_action("down", "", false) == "none", mn.back_action("down", "", false))
	# 12: a stage cleared in the air: the jetpack off and down on the floor for the way out
	Store.save = Store.save0(); gm.begin(1); pl.invuln = 1e9
	var gy := Phys.ground_at(pl.pos.x, pl.pos.y + 1.0, pl.pos.z, Player.R); var g_exp := Phys.ground_at(pl.pos.x, gy + 7.0, pl.pos.z, Player.R)
	pl.pos.y = gy + 7.0; pl.jet_on = true; pl.grounded = false; pl.vel.y = 2.0
	gm.finish()
	check("bug 12: a stage cleared while flying turns the jetpack off and sets you on the floor for the way out, as the browser game's",
		gm.ended and not pl.jet_on and g_exp < gy + 6.0 and absf(pl.pos.y - g_exp) < 1e-4 and pl.vel.y == 0.0, [gm.ended, pl.jet_on, pl.pos.y, g_exp])
	# 13: the jetpack does not start on an animal, thrown, down (stage 5) or held (bedtime); on your feet it does
	Store.save = Store.save0(); gm.begin(1); var fake := Enemies.Foe.new(); var jt := []
	for how in ["none", "ride", "toss", "out", "held"]:
		pl.jet_end(); Store.save.items.jet = 1; pl.stun_t = 0.0; pl.jet_last_tap = -9.0
		en.animals.m = fake if how == "ride" else null; pl.toss_on = how == "toss"; pl.out = how == "out"; pl.held = how == "held"
		pl.jet_tap(100.0); pl.jet_tap(100.1); jt.push_back([pl.jet_on, int(Store.save.items.jet)])
	en.animals.m = null; pl.toss_on = false; pl.out = false; pl.held = false; pl.jet_end()
	check("bug 13: the jetpack does not start (nor use up its one go) on an animal or thrown, as the browser game's, nor down or held in stage 5; on your feet it does",
		jt == [[true, 0], [false, 1], [false, 1], [false, 1], [false, 1]], jt)
	Store.save = keep_save

# ---------------- aimed, no gun hides what you aim at (1.5.5) ----------------
## the triangles of what is drawn under root (but not under skip, nor a part marked "no_clear"), in the eye's space with root at `at`
func _tris(root: Node3D, at: Vector3, skip: Node = null) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.has_meta("no_clear") or (skip != null and skip.is_ancestor_of(mi)): continue
		var t := mi.transform; var p := mi.get_parent(); var shown := mi.visible
		while p != null and p != root: shown = shown and (p as Node3D).visible; t = (p as Node3D).transform * t; p = p.get_parent()
		if not shown: continue
		for v in mi.mesh.get_faces(): out.push_back(t * v + at)
	return out
## the rays from the eye through the middle of the screen and two rings about it (radius r, a tangent): those that hit something
func _hits(tris: PackedVector3Array, r: float) -> int:
	var dirs := [Vector3(0, 0, -1)]
	for ring: float in [0.5, 0.97]:
		for i in 12: dirs.push_back(Vector3(cos(i * TAU / 12.0) * r * ring, sin(i * TAU / 12.0) * r * ring, -1.0).normalized())
	var hit := 0
	for d: Vector3 in dirs:
		for i in range(0, tris.size(), 3):
			if Geometry3D.ray_intersects_triangle(Vector3.ZERO, d, tris[i], tris[i + 1], tris[i + 2]) != null: hit += 1; break
	return hit
func _aim_clear() -> void:
	var holder := Node3D.new(); add_child(holder); var gmm := GunModels.new(); gmm.build(holder); var bad := []; var lifted := 0
	for id in Weapons.ORDER:
		var M: Dictionary = gmm.models[id]; var g: Node3D = M.g; g.visible = true
		var sights := ["iron"]
		for pid in (M.parts.sight as Dictionary).keys(): sights.push_back(pid)
		for sg in sights:
			gmm.apply_look(id, {"sight": sg, "muzzle": "none", "under": "none", "paint": "base"})
			for slot in ["muzzle", "under"]:   # (the biggest of each on at once: the worst it can be)
				for k in M.parts[slot]: (M.parts[slot][k] as Node3D).visible = true
			var optic: Node3D = M.parts.sight.get(sg)
			var at: Vector3 = gmm.ads(id); var n := _hits(_tris(g, at, optic), GunModels.CLEAR * 0.999)
			if sg == "iron" and _hits(_tris(g, Vector3(0, -GunModels.MUZZLE[id][2], GunModels.HIP[id][3])), GunModels.CLEAR * 0.999) > 0: lifted += 1   # (held as before: on the sight line)
			if n > 0: bad.push_back("%s %s: %d" % [id, sg, n])
			if optic != null and _hits(_tris(optic, at + optic.position), 0.0) == 0: bad.push_back("%s %s: the optic is off the eye line" % [id, sg])
		g.visible = false
	var MS = load("res://scripts/main.gd")
	for id in Toys.ORDER:
		var t := Toys.build(id); holder.add_child(t)
		var off: Vector2 = GunModels.clear_offset(t, MS.TOY_ADS, GunModels.CLEAR, MS.TOY_TURNS)
		var n2 := _hits(_tris(t, MS.TOY_ADS + Vector3(off.x, off.y, 0)), GunModels.CLEAR * 0.999); var n0 := _hits(_tris(t, MS.TOY_ADS), GunModels.CLEAR * 0.999)
		if n2 > 0: bad.push_back("toy %s: %d" % [id, n2])
		if n0 > 0: lifted += 1
	check("aimed, no gun hides what you aim at: nothing of the eight guns (iron sights or any optic, the biggest muzzle and under-barrel parts on) nor the nine toy guns comes within 6 %% of the screen's height of the middle, by rays through the middle; an optic's window stays on the eye line; held as before, %d of the 17 covered it" % lifted,
		bad.is_empty() and lifted >= 12, bad)
	holder.free()

# ---------------- stage 2's zombie corpse shot on a touch screen (1.5.6) ----------------
## a zombie knocked down 30 degrees off to the side, then the game's frames for a second: the most the aim came onto the body (degrees
## off), the shots fired, whether the body is gone, and how far the aim is from where it was (degrees)
func _cs_try(gm: Game, en: Enemies, pl: Player, g: Guns, cam: Camera3D, look: String, on: bool, stage_as := 2) -> Array:
	gm.begin(2); pl.invuln = 1e9; g.look_mode = look; g.corpse_shot = on; g.auto_fire = false; g.stage = stage_as
	pl.update(0.0, cam, 0.0)
	var eye := cam.global_position; var spot := Vector3.ZERO; var face := 0.0
	for i in 16:   # an open way from where you stand
		var a := pl.yaw + i * TAU / 16.0; var p := Vector3(pl.pos.x - sin(a) * 7.0, 0.0, pl.pos.z - cos(a) * 7.0)
		p.y = Phys.ground_at(p.x, 1.0, p.z, 0.4)
		if Phys.line_of_sight(eye, p + Vector3(0, 0.3, 0)) and Phys.line_of_sight(eye, p + Vector3(0, 1.4, 0)): spot = p; face = a; break
	var z = null
	for e in en.list:
		if e.alive and e.type == "zombie" and not e.boss: z = e; break
	z.pos = spot; z.g.position = spot; pl.yaw = face + deg_to_rad(30.0); pl.pitch = 0.0; pl.update(0.0, cam, 0.0)
	var home := Vector2(pl.yaw, pl.pitch); var shots0 := g.shots
	en.damage(z, z.hp + 1.0, z.pos + Vector3(0, 1, 0), Vector3(0, 0, 1), false)
	var best := 180.0; var t := 0.0
	for i in 60:
		t += 1.0 / 60.0; pl.update(1.0 / 60.0, cam, t); g.update(1.0 / 60.0)   # (the enemies stand still: none walks into the shot; the body would lie 3 s)
		if z.alive and z.downed: best = minf(best, rad_to_deg((-cam.global_basis.z).angle_to(g._cs_point(z) - cam.global_position)))
	var back := rad_to_deg(Vector2(wrapf(pl.yaw - home.x, -PI, PI), pl.pitch - home.y).length())
	g.look_mode = "drag"; g.corpse_shot = false; g.stage = 2
	return [snappedf(best, 0.1), g.shots - shots0, not z.alive, snappedf(back, 0.1)]
func _corpse_shot(gm: Game, en: Enemies, pl: Player, g: Guns, cam: Camera3D) -> void:
	var keep_save: Dictionary = Store.save.duplicate(true); Store.save = Store.save0()
	var on := _cs_try(gm, en, pl, g, cam, "touch", true)
	check("stage 2 on a touch screen: a zombie you knock down gets the aim turned onto its body and one shot, so it is gone for good, and the aim goes back to where it was",
		on[0] < 2.0 and on[1] == 1 and on[2] and on[3] < 0.5, on)
	var off := _cs_try(gm, en, pl, g, cam, "touch", false); var mouse := _cs_try(gm, en, pl, g, cam, "drag", true); var other := _cs_try(gm, en, pl, g, cam, "touch", true, 1)
	check("the corpse shot does nothing with the option off, on a computer (mouse) or in another stage",
		[off, mouse, other].all(func(r): return r[1] == 0 and not r[2] and r[3] < 0.01), [off, mouse, other])
	var cu := Ui.new(); cu.f_title = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"); cu.f_body = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-Regular.ttf")
	cu.f_bold = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"); cu.f_mono = load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf"); add_child(cu)
	var found := func(touch: bool) -> Array:
		cu.is_touch = touch; var box := VBoxContainer.new(); cu.add_child(box); cu._settings_rows(box, true); var out := []
		for c in box.find_children("*", "CheckBox", true, false):
			if (c as CheckBox).text.begins_with("좀비 시체 자동 사격"): out.push_back((c as CheckBox).button_pressed)
		box.free(); return out
	var on_touch: Array = found.call(true); var on_pc: Array = found.call(false); cu.free()
	check("the corpse shot is a setting on a touch screen (the phone app), on for a new player; a computer's settings do not show it",
		bool(Store.settings0(true).corpseShot) and bool(Store.settings0(false).corpseShot) and on_touch == [bool(Store.settings.get("corpseShot", true))] and on_pc.is_empty(), [on_touch, on_pc])
	Store.save = keep_save

func _ref_flow(px: float, pz: float) -> PackedInt32Array:
	var n: int = Phys.nav_n; var dist := PackedInt32Array(); dist.resize(n * n); dist.fill(-1); var q := PackedInt32Array(); q.resize(n * n)
	var blk := Phys.nav_blocked; var s := Phys.nav_i(pz) * n + Phys.nav_i(px); var head := 0; var tail := 0
	q[tail] = s; tail += 1; dist[s] = 0
	while head < tail:
		var c := q[head]; head += 1
		var i := c % n; var j := c / n; var d := dist[c] + 1
		for k in 8:
			var di: int = _REF_DIRS[k][0]; var dj: int = _REF_DIRS[k][1]; var ni := i + di; var nj := j + dj
			if ni < 0 or nj < 0 or ni >= n or nj >= n: continue
			var nc := nj * n + ni
			if dist[nc] != -1 or blk[nc] != 0: continue
			if di != 0 and dj != 0 and (blk[j * n + ni] != 0 or blk[nj * n + i] != 0): continue
			dist[nc] = d; q[tail] = nc; tail += 1
	return dist
func _ref_flow_dir(dist: PackedInt32Array, x: float, z: float) -> Vector2:
	var n: int = Phys.nav_n; var i := Phys.nav_i(x); var j := Phys.nav_i(z); var blk := Phys.nav_blocked
	var bd := dist[j * n + i]
	if bd < 0: bd = 1000000000
	var bi := -1; var bj := -1
	for k in 8:
		var di: int = _REF_DIRS[k][0]; var dj: int = _REF_DIRS[k][1]; var ni := i + di; var nj := j + dj
		if ni < 0 or nj < 0 or ni >= n or nj >= n: continue
		var d := dist[nj * n + ni]
		if d < 0 or d >= bd: continue
		if di != 0 and dj != 0 and (blk[j * n + ni] != 0 or blk[nj * n + i] != 0): continue
		bd = d; bi = ni; bj = nj
	if bi < 0: return Vector2.ZERO
	return Vector2((bi + 0.5) * Phys.nav_cs - Phys.nav_off - x, (bj + 0.5) * Phys.nav_cs - Phys.nav_off - z).normalized()
func _ref_separate(list: Array) -> void:
	for i in list.size():
		var a = list[i]
		for j in range(i + 1, list.size()):
			var b = list[j]
			if (not a.awake and not b.awake) or a.downed or b.downed or a.fly or b.fly: continue
			var dx: float = b.pos.x - a.pos.x; var dz: float = b.pos.z - a.pos.z
			if absf(dx) > 5.0 or absf(dz) > 5.0: continue
			var d := sqrt(dx * dx + dz * dz); var m: float = a.R + b.R + 0.1
			if d < m and d > 0.001:
				var push := (m - d) * 0.5
				a.pos = Phys.move_xz(a.pos, -dx / d * push, -dz / d * push, a.R, a.H, 0.0)[0]; b.pos = Phys.move_xz(b.pos, dx / d * push, dz / d * push, b.R, b.H, 0.0)[0]
func _ref_near(minx: float, minz: float, maxx: float, maxz: float) -> Array:
	var out := []; Phys.qstamp += 1; var st: int = Phys.qstamp
	for i in range(Phys._ci(minx), Phys._ci(maxx) + 1):
		for j in range(Phys._ci(minz), Phys._ci(maxz) + 1):
			for b in Phys.cells[j * Phys.SPN + i]:
				if b.q != st: b.q = st; out.push_back(b)
	return out
func _ref_collide(x: float, y: float, z: float, r: float, h: float):
	for b in _ref_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if y + h <= b.miny or y >= b.maxy - 0.001: continue
		return b
	return null
func _ref_ground(x: float, y: float, z: float, r: float) -> float:
	var g := Phys.floor_y(x, z)
	for b in _ref_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if b.maxy <= y + 0.06 and b.maxy > g: g = b.maxy
	return g
func _ref_ceil(x: float, y: float, z: float, r: float, h: float) -> float:
	var c := INF
	for b in _ref_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if b.miny >= y + h - 0.05 and b.miny < c: c = b.miny
	return c
var _rr_t := 0.0; var _rr_n := Vector3.ZERO; var _rr_box = null
func _ref_ray(o: Vector3, d: Vector3, max_t: float) -> bool:
	var best := max_t; var hit := false
	if d.y < -1e-6:
		var fy := 0.0
		if Phys.PIT != null:
			var t0 := -o.y / d.y; var hx := o.x + d.x * t0; var hz := o.z + d.z * t0
			if o.y < 0.0 or (hx > Phys.PIT.x0 and hx < Phys.PIT.x1 and hz > Phys.PIT.z0 and hz < Phys.PIT.z1): fy = Phys.PIT.y
		var tg := (fy - o.y) / d.y
		if tg >= 0.0 and tg < best: best = tg; _rr_n = Vector3.UP; _rr_box = null; hit = true
	var ex := o.x + d.x * best; var ez := o.z + d.z * best
	for b in _ref_near(minf(o.x, ex), minf(o.z, ez), maxf(o.x, ex), maxf(o.z, ez)):
		if b.grate and not b.glass: continue
		var t0 := 0.0; var t1 := best; var ax := -1; var sg := 0.0
		var lo := [b.minx, b.miny, b.minz]; var hi := [b.maxx, b.maxy, b.maxz]
		var miss := false
		for k in 3:
			var ok: float = o[k]; var dk: float = d[k]
			if absf(dk) < 1e-9:
				if ok < lo[k] or ok > hi[k]: miss = true; break
			else:
				var ta: float = (lo[k] - ok) / dk; var tb: float = (hi[k] - ok) / dk; var s := -1.0
				if ta > tb: var q := ta; ta = tb; tb = q; s = 1.0
				if ta > t0: t0 = ta; ax = k; sg = s
				if tb < t1: t1 = tb
				if t0 > t1: miss = true; break
		if miss: continue
		if t0 < best:
			best = t0; hit = true; _rr_box = b
			_rr_n = Vector3(sg if ax == 0 else 0.0, sg if ax == 1 else 0.0, sg if ax == 2 else 0.0)
	_rr_t = best
	return hit

# ---------------- the account: sign in with an id, the progress kept on the server too (1.6.0) ----------------
## stands in for the account server in these checks (server/src/index.js, checked on its own in server/test): the same
## answers, kept in memory
class Accounts:
	var users := {}; var sessions := {}; var down := false; var wait := 0; var calls: Array = []; var bodies: Array = []; var n := 0
	func _j(x): return JSON.parse_string(JSON.stringify(x))   # (as over the wire: every number comes back a float)
	func _open(id: String) -> String:
		n += 1; var t := "t%042d" % n; sessions[t] = id; return t
	func _end(id: String) -> void:
		for t in sessions.keys():
			if sessions[t] == id: sessions.erase(t)
	func handle(method: String, path: String, body, tok: String) -> Dictionary:
		calls.push_back(method + " " + path); bodies.push_back(JSON.stringify(body))
		if down: return {"status": 0, "json": {}}
		var b: Dictionary = _j(body) if body is Dictionary else {}
		var id := str(b.get("id", ""))
		match path:
			"/register":
				if users.has(id): return {"status": 409, "json": {"error": "taken"}}
				n += 1; users[id] = {"key": b.get("key"), "code": "CODE-%04d-AAAA-BBBB" % n, "save": null}
				return {"status": 201, "json": {"id": id, "token": _open(id), "recovery": users[id].code}}
			"/login":
				if wait > 0: return {"status": 429, "json": {"error": "wait", "wait": wait}}
				if not users.has(id) or users[id].key != b.get("key"): return {"status": 401, "json": {"error": "wrong"}}
				return {"status": 200, "json": {"id": id, "token": _open(id), "save": _j(users[id].save)}}
			"/recover":
				if not users.has(id) or users[id].code != b.get("recovery"): return {"status": 401, "json": {"error": "wrong"}}
				n += 1; users[id].key = b.get("key"); users[id].code = "CODE-%04d-CCCC-DDDD" % n; _end(id)
				return {"status": 200, "json": {"id": id, "token": _open(id), "recovery": users[id].code, "save": _j(users[id].save)}}
		if not sessions.has(tok): return {"status": 401, "json": {"error": "auth"}}
		var me: String = sessions[tok]
		match method + " " + path:
			"GET /save": return {"status": 200, "json": {"save": _j(users[me].save)}}
			"PUT /save": return put(me, b.get("data"), int(b.get("base", 0)), bool(b.get("force", false)))
			"POST /logout": sessions.erase(tok); return {"status": 200, "json": {"ok": true}}
			"POST /delete":
				if users[me].key != b.get("key"): return {"status": 401, "json": {"error": "wrong"}}
				users.erase(me); _end(me)
				return {"status": 200, "json": {"ok": true}}
		return {"status": 404, "json": {"error": "nope"}}
	## a save written: by this device, or (called by the checks) by another device of the same account
	func put(me: String, data, base: int, force := false) -> Dictionary:
		var cur = users[me].save; var rev := int(cur.rev) if cur != null else 0
		if cur != null and not force and base != rev: return {"status": 409, "json": {"error": "conflict", "save": _j(cur)}}
		users[me].save = {"data": _j(data), "rev": rev + 1, "updated": 1795000000 + rev * 60}
		return {"status": 200, "json": {"rev": rev + 1, "updated": 1795000000 + rev * 60}}

func _accounts() -> void:
	var C = Cloud; var K = load("res://scripts/cloud.gd")
	var v1 = K.Kdf.new("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 1); var v2 = K.Kdf.new("password".to_utf8_buffer(), "salt".to_utf8_buffer(), 4096); v2.step(v2.left)
	var k_all: String = K.key_of("someone", "correct horse")
	C.rounds = K.ROUNDS; var t_k := Time.get_ticks_msec(); var k_parts: String = await C.stretch("  SomeOne ", "correct horse"); t_k = Time.get_ticks_msec() - t_k
	check("the account's key is PBKDF2-HMAC-SHA256 as the standard has it (its known answers for 1 and 4096 rounds; a password longer than a hash block; one in Korean), salted with the id in lower case, 100,000 rounds, the same worked out a part each frame",
		v1.out().hex_encode() == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b" and v2.out().hex_encode() == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"
		and K.key_of("someone", "p".repeat(80), 50) == "cf688ec702d574e984a811c122bad245d3697ba59de47fc8d7529237d85ae233" and K.key_of("someone", "비밀번호 한글", 50) == "14236e01f17c6e8279a15daee04875f3e902b5bebff28527bea1b7335f92b62f"
		and k_all == "2891b140f4147d4ea1a2f5cc779f1cb15a3e2fcdf76d61be2c908745fa65c6a9" and k_parts == k_all and K.key_of("someone", "Correct horse", 50) != K.key_of("someone", "correct horse", 50), "%d ms" % t_k)
	var web_re := RegEx.new(); web_re.compile("^https://[a-z0-9.-]+\\.[a-z]+$")
	check("the game's account server is an https address out on the net (never one on this machine), and the checks have it switched off", web_re.search(K.BASE) != null and not K.BASE.contains("127.0.0.1") and not K.BASE.contains("localhost") and not C.enabled(), K.BASE)
	var toml := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../server/wrangler.toml"))
	var orx := RegEx.new(); orx.compile("(?m)^ORIGINS = \"([^\"]*)\""); var om := orx.search(toml)
	var listed: Array = Array(om.get_string(1).split(",")).map(func(x): return str(x).strip_edges()) if om != null else []
	check("the web game turns its account on only on the pages the server answers from a browser (the same list as server/wrangler.toml's ORIGINS)", om != null and listed == K.WEB_PAGES, [listed, K.WEB_PAGES])
	check("an id is 3 to 16 of a-z, 0-9 and _, a password 8 to 64 letters of any kind",
		K.id_error("ab") != "" and K.id_error("has space") != "" and K.id_error("한글아이디") != "" and K.id_error("a".repeat(17)) != "" and K.id_error("Upper") != "" and K.id_error("good_id_1") == ""
		and K.pw_error("1234567") != "" and K.pw_error("12345678") == "" and K.pw_error("한글 비밀번호도") == "" and K.pw_error("p".repeat(65)) != "")
	var keep_save: Dictionary = Store.save.duplicate(true); var keep_locks := [Store.money_lock, Store.ivory_lock, Store.own_lock]
	Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null   # (not in a stage, whatever the checks before left)
	var srv := Accounts.new(); var events: Array = []; var on_ev := func(w: String) -> void: events.push_back(w)
	C.changed.connect(on_ev)
	C.store_key = "account_check"; C.base = "http://check"; C.transport = srv.handle; C.rounds = 300; C.idle = Callable(); C._forget()
	var progress := func(money: int, cleared: Array) -> void:   # this device's progress, written as the game writes it
		Store.save = Store.save0(); Store.save.money = money; Store.save.cleared = cleared.duplicate(); Store.fix_save(); Store.persist()
	var acct := func() -> Dictionary: return srv.users.get("mina_07", {})
	# ---- signing up; saves go up by themselves
	progress.call(5000, [1])
	var up: Dictionary = await C.sign_up("Mina_07", "pass word 1")
	check("signing up: the id in lower case, a recovery code to keep, and this device's progress on the account as its first save; the server is sent a key, never the password",
		up.ok and str(up.recovery).begins_with("CODE-") and C.signed_in() and C.id == "mina_07" and acct.call().get("key") == K.key_of("mina_07", "pass word 1", 300) and acct.call().save != null
		and int(acct.call().save.rev) == 1 and int(acct.call().save.data.money) == 5000 and C.rev == 1 and not C.dirty and not srv.bodies.any(func(b): return str(b).contains("pass word 1")), [up, C.id, C.rev, C.dirty])
	Store.save.money = 7000; Store.persist()
	var was_dirty: bool = C.dirty; var n_before := srv.calls.size()
	C._process(1.0); var held_back: bool = srv.calls.size() == n_before   # (a moment first, so a run of saves goes up as one)
	C._process(1.5)
	check("a save on the device goes up to the account by itself a moment later, as the next rev",
		was_dirty and held_back and not C.dirty and int(acct.call().save.rev) == 2 and int(acct.call().save.data.money) == 7000 and C.rev == 2 and C.status_text().begins_with("계정에 저장됨"), [was_dirty, held_back, C.dirty, C.rev, C.status_text()])
	Store.money_lock = 7000; Store.save.money = 9999; Store.persist(); C._process(3.0)   # in a stage: what you pick up there is not yours yet
	var in_stage_money := int(acct.call().save.data.money); Store.money_lock = null; Store.save.money = 7000
	check("inside a stage the account gets what the device keeps: what you came in with, not what you have picked up there", in_stage_money == 7000 and int(acct.call().save.rev) == 3, [in_stage_money, acct.call().save.rev])
	await C.sign_out()
	var n_out := srv.calls.size(); Store.save.money = 7100; Store.persist(); C._process(9.0)
	check("signing out: the device forgets the account and its sign-in is ended on the server; the progress stays on the device, and saves after that go nowhere",
		not C.signed_in() and srv.sessions.is_empty() and int(Store.save.money) == 7100 and srv.calls.size() == n_out and srv.calls[-1] == "POST /logout" and C.status_text().begins_with("게스트"), [C.signed_in(), srv.sessions.size(), srv.calls.slice(-2)])
	# ---- signing in: which progress
	progress.call(0, [])   # a device with no progress of its own
	events.clear()
	var in1: Dictionary = await C.sign_in("MINA_07", "pass word 1")
	var aside = Store._read("account_check_before")
	check("signing in on a device with no progress of its own: the account's comes down, and is written on the device",
		in1.ok and int(Store.save.money) == 7000 and Store.save.cleared == [1] and C.rev == 3 and not C.dirty and not C.asking() and events.has("applied") and aside is Dictionary and int(Store._read("save").money) == 7000, [in1, Store.save.money, C.rev, events])
	await C.sign_out()
	var n_bad := srv.calls.size()
	var bad: Dictionary = await C.sign_in("mina_07", "not the one"); var nobody: Dictionary = await C.sign_in("nobody_here", "pass word 1")
	srv.wait = 840; var slow: Dictionary = await C.sign_in("mina_07", "pass word 1"); srv.wait = 0
	var taken: Dictionary = await C.sign_up("mina_07", "another pass"); var n_asked := srv.calls.size() - n_bad
	var short: Dictionary = await C.sign_up("new_one", "short"); var odd: Dictionary = await C.sign_up("Bad Id!", "long enough pw")
	check("a wrong password and an unknown id get the same words and sign nobody in; too many tries: how long to wait; an id already taken is refused; a short password or an id of other letters does not even go to the server",
		not bad.ok and bad.error == nobody.error and str(bad.error).contains("맞지 않습니다") and not slow.ok and str(slow.error).contains("14분") and not taken.ok and str(taken.error).contains("이미 있는")
		and not short.ok and str(short.error).contains("8자") and not odd.ok and str(odd.error).contains("아이디는") and srv.calls.size() - n_bad == n_asked and n_asked == 4 and not C.signed_in(), [bad, slow, taken, short, odd, n_asked])
	progress.call(100, [2])   # this device has gone its own way
	events.clear(); var n_ask := srv.calls.size()
	var in2: Dictionary = await C.sign_in("mina_07", "pass word 1")
	Store.save.money = 150; Store.persist(); C._process(9.0)   # (a save while the question stands)
	check("signing in where the device and the account both have progress: neither is written over, the player is asked, and until the answer no save goes up",
		in2.ok and C.asking() and events.has("ask") and int(Store.save.money) == 150 and int(acct.call().save.data.money) == 7000 and int(acct.call().save.rev) == 3 and not srv.calls.slice(n_ask).has("PUT /save") and C.status_text().contains("골라야"),
		[in2, C.asking(), events, srv.calls.slice(n_ask)])
	await C.choose("account")
	check("the answer 'the account's': its progress is now this device's", not C.asking() and int(Store.save.money) == 7000 and Store.save.cleared == [1] and C.rev == 3 and not C.dirty and int(acct.call().save.rev) == 3, [C.asking(), Store.save.money, C.rev])
	await C.sign_out(); progress.call(100, [2]); await C.sign_in("mina_07", "pass word 1"); var asked2: bool = C.asking()
	await C.choose("device")
	check("the answer 'this device's': it goes over the account's, as the next rev", asked2 and not C.asking() and int(acct.call().save.data.money) == 100 and int(acct.call().save.rev) == 4 and C.rev == 4 and not C.dirty and int(Store.save.money) == 100, [asked2, C.asking(), acct.call().save.rev, C.rev])
	await C.sign_out(); events.clear(); await C.sign_in("mina_07", "pass word 1")
	check("signing in where both hold the same progress asks nothing and moves nothing", C.signed_in() and not C.asking() and not events.has("ask") and not events.has("applied") and C.rev == 4 and not C.dirty, [events, C.rev])
	# ---- two devices
	var other := func(money: int) -> void:   # another device of the same account plays on and saves
		var d: Dictionary = Store.save0(); d.money = money; d.cleared = [1, 2]; srv.put("mina_07", d, int(acct.call().save.rev))
	other.call(900)
	C.idle = func() -> bool: return false   # (this device is in a stage)
	await C.refresh(); var waits: bool = int(Store.save.money) == 100 and not C.incoming.is_empty()
	C.idle = func() -> bool: return true
	C._process(0.1)
	check("another device has played on: its newer progress comes down here, but only when the game is at rest in the menu, never under a stage in play",
		waits and int(Store.save.money) == 900 and Store.save.cleared == [1, 2] and C.rev == 5 and C.incoming.is_empty() and not C.asking() and not C.dirty, [waits, Store.save.money, C.rev])
	other.call(1200); Store.save.money = 950; Store.persist(); C._process(3.0)   # both have played since
	check("both devices have played since: this one's save is not written over the other's (the server refuses it), and the player is asked",
		C.asking() and int(C.ask.data.money) == 1200 and int(acct.call().save.data.money) == 1200 and int(acct.call().save.rev) == 6 and int(Store.save.money) == 950 and C.dirty, [C.asking(), acct.call().save.rev, C.dirty])
	await C.choose("device")
	# ---- the server out of reach; the device signed out by the server
	srv.down = true; Store.save.money = 1000; Store.persist(); C._process(3.0)
	var w1: float = C._wait; var off1: bool = C.offline and C.dirty and C.status_text().begins_with("서버에 연결하지 못했습니다")
	C._process(16.0); var w2: float = C._wait
	srv.down = false; C._process(31.0)
	check("the server out of reach: the save is on the device all the same and the game says so; it tries again after 15 seconds, then 30, and when the server answers the save goes up",
		off1 and is_equal_approx(w1, 15.0) and is_equal_approx(w2, 30.0) and int(Store._read("save").money) == 1000 and not C.offline and not C.dirty and int(acct.call().save.data.money) == 1000, [off1, w1, w2, C.offline, C.dirty])
	var kept = Store._read("account_check"); var n_again := srv.calls.size()
	var again = K.new(); again.store_key = "account_check"; again.base = "http://check"; again.transport = srv.handle; add_child(again)
	for i in 2: await get_tree().process_frame   # (its first look at the account comes right after it starts)
	check("the sign-in is kept on the device (the id and a token, never the password): the game started again is still signed in, and looks at once at what the account holds",
		kept is Dictionary and kept.get("id") == "mina_07" and str(kept.get("token")) == C.token and not JSON.stringify(kept).contains("pass") and again.signed_in() and again.id == "mina_07" and again.rev == C.rev and srv.calls.slice(n_again).has("GET /save"),
		[kept is Dictionary, again.signed_in(), srv.calls.slice(n_again)])
	again.free()
	srv.sessions.clear(); Store.save.money = 1100; Store.persist(); C._process(3.0)
	check("the server no longer knows this device (the password was set again elsewhere, or half a year away): it is signed out and told to sign in again, its progress untouched",
		not C.signed_in() and C.lost and int(Store.save.money) == 1100 and C.status_text().begins_with("다시 로그인"), [C.signed_in(), C.lost, C.status_text()])
	# ---- the recovery code; deleting
	var code: String = acct.call().code
	var rc_bad: Dictionary = await C.recover("mina_07", "WRONG-CODE-0000-0000", "new pass word"); var rc: Dictionary = await C.recover("Mina_07", code, "new pass word")
	check("the recovery code sets a new password and signs in, and a new code comes back in its place; a wrong code is refused",
		not rc_bad.ok and str(rc_bad.error).contains("복구 코드") and rc.ok and str(rc.recovery) != code and str(rc.recovery).begins_with("CODE-") and C.signed_in() and not C.lost and acct.call().key == K.key_of("mina_07", "new pass word", 300),
		[rc_bad, rc, C.signed_in()])
	if C.asking(): await C.choose("device")
	var del_bad: Dictionary = await C.delete_account("not it"); var still: bool = C.signed_in() and srv.users.has("mina_07"); var mine := int(Store.save.money)
	var del: Dictionary = await C.delete_account("new pass word")
	check("deleting the account asks for the password again; then the id, its progress and its sign-ins are gone from the server, and the device, signed out, keeps its own progress",
		not del_bad.ok and str(del_bad.error).contains("비밀번호가 맞지") and still and del.ok and not srv.users.has("mina_07") and srv.sessions.is_empty() and not C.signed_in() and not C.lost and int(Store.save.money) == mine and mine == 1100,
		[del_bad, still, del, srv.users.keys()])
	# ---- the screens
	var au := Ui.new(); au.f_title = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"); au.f_body = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-Regular.ttf")
	au.f_bold = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"); au.f_mono = load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf"); au.on_settings = func() -> void: pass
	add_child(au); au._build_menu(); au._build_settings(); au._build_dialog(); au._build_account()
	var shown := func(t: String) -> bool: return (au.screens[au.cur] as Control).find_children("*", "Button", true, false).any(func(b): return (b as Button).text == t and (b as Button).is_visible_in_tree())
	au.show_screen("menu"); var badge0: String = au.strip_l.text; var rail0 := str(au.rail_btns[5].get_meta("label"))
	au.open_sub("settings"); var set_in: bool = shown.call("로그인 · 회원가입"); au.close_sub()
	au.in_stage = true; au.open_sub("settings"); var set_stage: bool = not shown.call("로그인 · 회원가입"); au.open_account(); var no_open: bool = au.cur == "settings"; au.close_sub(); au.in_stage = false
	C.base = ""; au.open_sub("settings"); var set_off: bool = not shown.call("로그인 · 회원가입"); au.close_sub(); var badge_off: String = au.strip_l.text; var rail_off := str(au.rail_btns[5].get_meta("label")); C.base = "http://check"
	check("the menu: the top line says 게스트 and the settings (now 설정 · 계정) have the way to sign in; in a stage, or with no server set for the game, there is no account to see",
		badge0.contains("게스트") and rail0 == "설정 · 계정" and set_in and set_stage and no_open and set_off and not badge_off.contains("게스트") and rail_off == "설정 · 저장", [badge0, rail0, set_in, set_stage, no_open, set_off, badge_off, rail_off])
	progress.call(300, [1])
	au.show_screen("menu"); au.open_account(); var m0: String = au.ac_mode
	au._account_mode("up"); au.ac_id.text = "Screen_Kid"; au.ac_pw.text = "screen pass"; au.ac_pw2.text = "screen pasS"
	await au._account_ok(); var mismatch: String = au.ac_msg.text; var not_yet: bool = not C.signed_in()
	au.ac_pw2.text = "screen pass"; await au._account_ok()
	var code_shown: bool = au.ac_mode == "code" and (au.screens.account as Control).find_children("*", "Label", true, false).any(func(l): return (l as Label).text == srv.users.screen_kid.code)
	au.back(); var stays: bool = au.cur == "account" and au.ac_mode == "code"   # (Esc, the phone's back button)
	await au._account_ok(); var me_now: bool = au.ac_mode == "me" and au.ac_code == ""
	au.back(); var badge1: String = au.strip_l.text
	au.open_dialog("reset"); var warned: bool = au.dlg_text.text.contains("계정에 저장된 진행 상황도"); au.close_sub()
	check("the account screen: signing up needs the password twice the same; then the recovery code is on show, and stays until 적어 두었습니다 is pressed (Esc and the back button do not put it away); the menu's top line then has the id, and the reset says the account's progress goes too",
		m0 == "in" and mismatch.contains("서로 다릅니다") and not_yet and code_shown and stays and me_now and au.cur == "menu" and badge1.contains("screen_kid") and C.signed_in() and warned, [m0, mismatch, not_yet, code_shown, stays, me_now, au.cur, badge1, warned])
	var d2: Dictionary = Store.save0(); d2.money = 4444; srv.put("screen_kid", d2, 1)   # another device saves
	Store.save.money = 350; Store.persist(); C._process(3.0)                            # and this one has earned something too
	var popped: bool = au.cur == "account" and au.ac_mode == "ask"
	var sides: Array = (au.screens.account as Control).find_children("*", "Button", true, false).filter(func(b): return (b as Button).is_visible_in_tree() and (b as Button).text.ends_with("이어 하기")).map(func(b): return (b as Button).text)
	var bags: Array = (au.screens.account as Control).find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.begins_with("가방 ")).map(func(l): return (l as Label).text.get_slice("\n", 0))
	au.back(); var later: bool = au.cur == "menu" and C.asking() and au.strip_l.text.contains("골라야 함")
	au.open_sub("settings"); var set_ask: bool = shown.call("진행 상황 고르기"); au.open_account()
	await au._account_choose("account")
	check("the question of which progress opens by itself over the menu, with each side's bag and a button for each; put off (나중에), the menu and the settings go on saying it must be answered; answered, the account's progress is on the device",
		popped and sides == ["이 기기 것으로 이어 하기", "계정 것으로 이어 하기"] and bags == ["가방 " + Store.won(350), "가방 " + Store.won(4444)] and later and set_ask and not C.asking() and int(Store.save.money) == 4444 and au.ac_mode == "me",
		[popped, sides, bags, later, set_ask, C.asking(), Store.save.money, au.ac_mode])
	au._account_mode("del"); au.back(); var del_back: bool = au.cur == "account" and au.ac_mode == "me"   # (취소, Esc)
	au._account_mode("del"); au.ac_pw.text = "screen pass"; await au._account_ok()
	var gone: bool = au.ac_mode == "in" and not C.signed_in() and not srv.users.has("screen_kid") and au.ac_msg.text.contains("지웠습니다")
	srv.users["old_hand"] = {"key": K.key_of("old_hand", "hand pass 1", 300), "code": "CODE-0000-EEEE-FFFF", "save": {"data": d2, "rev": 9, "updated": 1795000000}}
	progress.call(0, []); au.ac_id.text = "old_hand"; au.ac_pw.text = "wrong pass"; await au._account_ok(); var said: String = au.ac_msg.text
	au.ac_pw.text = "hand pass 1"; await au._account_ok()
	check("deleting from the account screen: 취소 goes back to the account, the password again deletes it; signing in there: a wrong password says so, the right one signs in and brings the account's progress",
		del_back and gone and said.contains("맞지 않습니다") and C.signed_in() and C.id == "old_hand" and au.ac_mode == "me" and int(Store.save.money) == 4444 and C.rev == 9, [del_back, gone, said, C.id, au.ac_mode, Store.save.money, C.rev])
	au.free()
	C.changed.disconnect(on_ev); C._forget()
	for f in ["account_check", "account_check_before"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s.json" % f))
	C.store_key = "account"; C.rounds = K.ROUNDS; C.idle = Callable(); C.mute()   # (and nothing goes to a server for the rest of the checks either)
	Store.save = keep_save; Store.fix_save(); Store.money_lock = keep_locks[0]; Store.ivory_lock = keep_locks[1]; Store.own_lock = keep_locks[2]; Store.persist()

# ---------------- the machine gun's shot: the Godot version's own since 1.6.1 (tools/render_sounds.js, godotLmg) ----------------
## a WAV file as tools/render_sounds.js writes it (16-bit mono): [samples, rate]
func _wav(path: String) -> Array:
	var b := FileAccess.get_file_as_bytes(path); var n := b.decode_u32(40) / 2; var x := PackedFloat32Array(); x.resize(n)
	for i in n: x[i] = b.decode_s16(44 + i * 2) / 32767.0
	return [x, b.decode_u32(24)]
## how high a sound sits (its RMS frequency: how fast it changes against how big it is), its peak and its length in seconds
func _pitch_of(path: String) -> Vector3:
	var w := _wav(path); var x: PackedFloat32Array = w[0]; var e := 0.0; var d := 0.0; var pk := 0.0
	for i in x.size():
		e += x[i] * x[i]; pk = maxf(pk, absf(x[i]))
		if i > 0: d += (x[i] - x[i - 1]) * (x[i] - x[i - 1])
	return Vector3(float(w[1]) / TAU * sqrt(d / maxf(e, 1e-12)), pk, x.size() / float(w[1]))

func _lmg_sound() -> void:
	var takes: Array = ["shot_lmg", "shot_lmg__1", "shot_lmg__2", "shot_lmg__3"].map(func(n): return _pitch_of("res://sounds/%s.wav" % n))
	var rifle := _pitch_of("res://sounds/shot_rifle.wav")
	check("the machine gun's shot is lower, duller and quieter than before (the owner's wish): four takes, each sitting far below the rifle's (no bright crack, no clack of the belt), lower at its peak and short",
		takes.size() == 4 and takes.all(func(t: Vector3) -> bool: return t.x < 600.0 and t.y < rifle.y * 0.7 and t.z < 0.35) and rifle.x > 1500.0, [takes, rifle])
