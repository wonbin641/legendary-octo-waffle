class_name Safari
extends RefCounted
## Stage 3-1: a very wide savanna with a watchtower in the middle. Five minutes of the animals living wild, then every one of them
## comes for the tower. Ported from src/04d_savanna.js, src/04h_tower.js and src/07i_safari.js: every seeded number is drawn in the
## same order, so trees, rocks, mounds, crates and animals are where the browser game has them.

const T_STAMPEDE := 300.0   # five minutes
const ROSTER := [["zebra", 12], ["buffalo", 13], ["hippo", 12], ["rhino", 12], ["cheetah", 12], ["tiger", 12], ["lionM", 14], ["giraffe", 3], ["elephant", 4], ["gorilla", 6]]
# the safari's lowland gorillas: the lab's gorilla build and fists, half as hard like every other animal here
const GORILLA := {"kong": true, "hp": 1000, "scale": 1.15, "dmgMul": 0.5, "name": "로랜드고릴라"}
const TOWER := {"hp": 10000.0, "ph": 3.84, "half": 2.6, "base": 3.2, "step": 0.48, "steps": 8}
const WATER := {"x": 62.0, "z": -48.0, "r": 22.0}
# at the tower: what each kind does to it, and how often. rams back off and run at it; the rest bite and claw at the planks
const SIEGE := {"buffalo": {"dmg": 20.0, "cd": [1.6, 2.2], "ram": true}, "rhino": {"dmg": 24.0, "cd": [1.8, 2.4], "ram": true}, "elephant": {"dmg": 52.0, "cd": [2.2, 2.8], "ram": true},
	"hippo": {"dmg": 14.0, "cd": [1.6, 2.2]}, "lionM": {"dmg": 10.0, "cd": [1.2, 1.6]}, "tiger": {"dmg": 10.0, "cd": [1.1, 1.5]}, "cheetah": {"dmg": 8.0, "cd": [1.0, 1.3]}, "gorilla": {"dmg": 9.0, "cd": [1.4, 2.0]}}

var t := 0.0
var stampede := false
var warned := 0
var player: Player
var game = null
var enemies = null
var fx: Fx = null
# the tower
var standing := true
var hp := 10000.0
var on := false            # you are up on it (or high on its steps)
var cols: Array = []
var slots: Array = []      # places along its foot: {x, z, nx, nz, owner, t}
var marks := {}
var shake := 0.0
var fall_t := -1.0
var fall_dir := 1.0
var crack_t := 0.0
var hinted := false
var landed := false
var clock := 0.0
var outer: Node3D; var inner: Node3D

func left() -> float: return maxf(0.0, T_STAMPEDE - t)
func holds() -> bool: return standing and on

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	var gm := PlaneMesh.new(); gm.size = Vector2(1200, 1200); var ground := MeshInstance3D.new(); ground.mesh = gm; ground.material_override = Gfx.std(World.lin("8c874a"), 0.97); G.add_child(ground)
	var free := func(x: float, z: float, rad: float) -> bool:
		for b in Phys.colliders:
			if x + rad > b.minx and x - rad < b.maxx and z + rad > b.minz and z - rad < b.maxz: return false
		return true
	# dirt tracks: a wobbly loop and a cross road
	var road := []; var road_b := []
	for i in 73: var a := (i / 72.0) * TAU; var rr := 98.0 + sin(a * 3.0) * 12.0; road.push_back(Vector2(cos(a) * rr, sin(a) * rr))
	for i in 25: road_b.push_back(Vector2(sin(i * 0.5) * 8.0, -170.0 + i * 14.2))
	var near_road := func(x: float, z: float, d: float) -> bool:
		for line in [road, road_b]:
			for p: Vector2 in line:
				if Vector2(p.x - x, p.y - z).length() < d: return true
		return false
	var rx := []
	for line in [road, road_b]:
		for i in line.size() - 1:
			var p0: Vector2 = line[i]; var p1: Vector2 = line[i + 1]; var len := p0.distance_to(p1)
			rx.push_back(Transform3D(Basis(Vector3.UP, atan2(p1.x - p0.x, p1.y - p0.y)).scaled_local(Vector3(6, 1, len + 0.6)), Vector3((p0.x + p1.x) / 2, 0.015, (p0.y + p1.y) / 2)))
	var rq := PlaneMesh.new(); rq.size = Vector2(1, 1); var roads := Gfx.multimesh(rq, rx); roads.material_override = Gfx.std(World.lin("8a6a45"), 0.95); G.add_child(roads)
	# the waterhole where hippos wallow
	var wm := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = WATER.r; wc.bottom_radius = WATER.r; wc.height = 0.02; wm.mesh = wc; wm.material_override = Gfx.std(World.lin("4a6457"), 0.12, 0.15); wm.position = Vector3(WATER.x, 0.05, WATER.z); G.add_child(wm)
	var mud := MeshInstance3D.new(); var mc := CylinderMesh.new(); mc.top_radius = WATER.r + 7; mc.bottom_radius = WATER.r + 7; mc.height = 0.02; mud.mesh = mc; mud.material_override = Gfx.std(World.lin("6a4a30"), 0.9); mud.position = Vector3(WATER.x, 0.02, WATER.z); G.add_child(mud)
	# perimeter fence of the safari park
	var E := 178.0
	for q in [[0.0, -E - 0.5, 2 * E + 2, 1.0], [0.0, E + 0.5, 2 * E + 2, 1.0], [-E - 0.5, 0.0, 1.0, 2 * E + 2], [E + 0.5, 0.0, 1.0, 2 * E + 2]]:
		Phys.add_collider(q[0] - q[2] / 2, 0, q[1] - q[3] / 2, q[0] + q[2] / 2, 12, q[1] + q[3] / 2, "wood")
	var posts := []; var ft := -E
	while ft <= E:
		for q in [[ft, -E], [ft, E], [-E, ft], [E, ft]]: posts.push_back(Transform3D(Basis.IDENTITY, Vector3(q[0], 0.85, q[1])))
		ft += 6.0
	var pb := BoxMesh.new(); pb.size = Vector3(0.16, 1.7, 0.16); var pim := Gfx.multimesh(pb, posts); pim.material_override = Gfx.std(World.lin("5a4636"), 0.9); G.add_child(pim)
	_build_tower(G, 0.0, 0.0)
	# acacia trees, kopje boulders, termite mounds, bushes
	var trees := []; var tries := 0
	while trees.size() < 120 and tries < 2000:
		tries += 1; var x := R.rng(-170, 170); var z := R.rng(-170, 170)
		if Vector2(x, z - 10).length() < 16 or Vector2(x - WATER.x, z - WATER.z).length() < WATER.r + 8 or near_road.call(x, z, 5.0) or not free.call(x, z, 3.0): continue
		var h := R.rng(3.6, 6.2); var cr := R.rng(3.2, 5.5); trees.push_back([x, z, h, cr]); Phys.add_collider(x - 0.3, 0, z - 0.3, x + 0.3, h, z + 0.3, "wood")
	var tr_x := []; var cr_x := []
	for q in trees:
		var ry := R.next() * TAU
		tr_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(1, q[2], 1)), Vector3(q[0], q[2] / 2, q[1])))
		cr_x.push_back(Transform3D(Basis.from_scale(Vector3(q[3], q[3] * 0.26, q[3])), Vector3(q[0], q[2], q[1])))
	var tm := CylinderMesh.new(); tm.top_radius = 0.18; tm.bottom_radius = 0.3; tm.height = 1.0; tm.radial_segments = 6
	var trunks := Gfx.multimesh(tm, tr_x); trunks.material_override = Gfx.std(World.lin("5a4636"), 0.95); G.add_child(trunks)
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 12; sm.rings = 6
	var crowns := Gfx.multimesh(sm, cr_x); crowns.material_override = Gfx.std(World.lin("4b5a2c"), 0.9); G.add_child(crowns)
	var rocks := []; var c := 0; tries = 0
	while c < 26 and tries < 600:
		tries += 1; var cx := R.rng(-165, 165); var cz := R.rng(-165, 165)
		if Vector2(cx, cz - 10).length() < 22 or Vector2(cx - WATER.x, cz - WATER.z).length() < WATER.r + 12 or near_road.call(cx, cz, 8.0) or not free.call(cx, cz, 6.0): continue
		c += 1; var n := 2 + int(floor(R.next() * 3))
		for k in n:
			var x := cx + R.rng(-4, 4); var z := cz + R.rng(-4, 4); var s := R.rng(1.2, 3.4); var sy := s * R.rng(0.6, 1)
			rocks.push_back([x, z, s, sy]); Phys.add_collider(x - s * 0.78, 0, z - s * 0.78, x + s * 0.78, sy * 0.95, z + s * 0.78, "concrete")
	var rk_x := []
	for q in rocks:
		var a := R.next(); var b := R.next() * TAU; var cc := R.next()
		rk_x.push_back(Transform3D(Basis.from_euler(Vector3(a, b, cc)).scaled_local(Vector3(q[2], q[3], q[2])), Vector3(q[0], q[3] * 0.45, q[1])))
	var rm := SphereMesh.new(); rm.radius = 1.0; rm.height = 2.0; rm.radial_segments = 6; rm.rings = 3
	var rim := Gfx.multimesh(rm, rk_x); rim.material_override = Gfx.std(World.lin("8f8374"), 0.92); G.add_child(rim)
	var mounds := []; tries = 0
	while mounds.size() < 34 and tries < 800:
		tries += 1; var x := R.rng(-170, 170); var z := R.rng(-170, 170)
		if Vector2(x, z - 10).length() < 14 or near_road.call(x, z, 4.0) or Vector2(x - WATER.x, z - WATER.z).length() < WATER.r + 6 or not free.call(x, z, 2.0): continue
		var h := R.rng(1.8, 3.2); mounds.push_back([x, z, h]); Phys.add_collider(x - 0.7, 0, z - 0.7, x + 0.7, h, z + 0.7, "concrete")
	var md_x := []
	for q in mounds: var ry := R.next() * TAU; md_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(0.95, q[2], 0.95)), Vector3(q[0], q[2] / 2, q[1])))
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 1.0; cm.height = 1.0; cm.radial_segments = 7
	var mim := Gfx.multimesh(cm, md_x); mim.material_override = Gfx.std(World.lin("9a5a3a"), 0.95); G.add_child(mim)
	var bu_x := []
	for i in 260:
		var x := R.rng(-172, 172); var z := R.rng(-172, 172); var s := R.rng(0.6, 1.5); var ry := R.next() * TAU
		bu_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(s * 1.4, s * 0.75, s * 1.2)), Vector3(x, s * 0.35, z)))
	var bm := SphereMesh.new(); bm.radius = 1.0; bm.height = 2.0; bm.radial_segments = 8; bm.rings = 5
	var bim := Gfx.multimesh(bm, bu_x); bim.material_override = Gfx.std(World.lin("55632f"), 0.95); G.add_child(bim)
	# tall dry grass tufts: the numbers are drawn as in the browser game, every fourth one is drawn
	var tu_x := []
	for i in 3200:
		var x := R.rng(-176, 176); var z := R.rng(-176, 176); var s := R.rng(0.7, 1.5); var ry := R.next() * TAU; var sy := s * R.rng(0.8, 1.3)
		if i % 4 == 0: tu_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(s * 0.5, sy, s * 0.5)), Vector3(x, sy / 2, z)))
	var gm2 := CylinderMesh.new(); gm2.top_radius = 0.0; gm2.bottom_radius = 0.6; gm2.height = 1.0; gm2.radial_segments = 4
	var tim := Gfx.multimesh(gm2, tu_x); tim.material_override = Gfx.std(World.lin("b8a35e"), 0.95); G.add_child(tim)
	# supply crates scattered over the plain; three of them up on the tower
	var up := [[-1.85, -1.85], [1.85, -1.85], [-1.85, 1.85]]
	w._place_crates(G, int(S.get("crates", 46)) + 3, func() -> Array:
			if not up.is_empty(): var q: Array = up.pop_front(); return [q[0], q[1], TOWER.ph]
			var x := R.rng(-170, 170); var z := R.rng(-170, 170); return [x, z, 0.0],
		func(x: float, z: float, y: float) -> bool: return y > 0.0 or (Vector2(x, z).length() > 11 and Vector2(x, z - 20).length() > 6 and free.call(x, z, 1.2) and Vector2(x - WATER.x, z - WATER.z).length() > WATER.r + 3), true)
	Phys.index_colliders(); Phys.build_nav()
	w.start = {"x": 0.0, "z": 20.0, "yaw": 0.0}; w.spawns.clear()

func _build_tower(G: Node3D, x: float, z: float) -> void:
	var PH: float = TOWER.ph; var H: float = TOWER.half; var Bh: float = TOWER.base
	outer = Node3D.new(); outer.position = Vector3(x, 0, z); G.add_child(outer); inner = Node3D.new(); outer.add_child(inner)
	var parts := [[2 * Bh, 2.0, 2 * Bh, 0, 1.0, 0, "7d5b3a"], [2 * H, 0.24, 2 * H, 0, PH - 0.12, 0, "7d5b3a"]]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.push_back([0.42, PH - 1.9, 0.42, sx * (H - 0.2), 1.9 + (PH - 1.9) / 2 - 0.12, sz * (H - 0.2), "5a3f28"]); parts.push_back([0.14, 6.7 - PH, 0.14, sx * (H - 0.12), PH + (6.7 - PH) / 2, sz * (H - 0.12), "5a3f28"])
	for q in [[-H, -H], [H, -H], [-H, H], [H, H], [0.0, -H], [-H, 0.0], [H, 0.0], [-0.8, H], [0.8, H]]: parts.push_back([0.12, 1.1, 0.12, q[0], PH + 0.55, q[1], "5a3f28"])
	for y in [PH + 0.55, PH + 1.05]:
		parts.append_array([[2 * H, 0.08, 0.08, 0, y, -H, "5a3f28"], [0.08, 0.08, 2 * H, -H, y, 0, "5a3f28"], [0.08, 0.08, 2 * H, H, y, 0, "5a3f28"], [H - 0.8, 0.08, 0.08, -(H + 0.8) / 2, y, H, "5a3f28"], [H - 0.8, 0.08, 0.08, (H + 0.8) / 2, y, H, "5a3f28"]])
	parts.push_back([2 * H + 1.6, 0.3, 2 * H + 1.6, 0, 6.85, 0, "8b8f92"])
	for k in range(1, int(TOWER.steps) + 1): var h: float = k * TOWER.step; var z0: float = H + 0.5 * (TOWER.steps - k); parts.push_back([1.4, h, 0.5, 0, h / 2, z0 + 0.25, "86613e"])
	var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.9; m.material_override = mat; inner.add_child(m)
	var add := func(minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float, grate := false) -> void:
		var b := Phys.add_collider(x + minx, miny, z + minz, x + maxx, maxy, z + maxz, "wood"); b.grate = grate; cols.push_back(b)
	add.call(-Bh, 0.0, -Bh, Bh, 2.0, Bh)
	add.call(-H, PH - 0.24, -H, H, PH, H)
	for k in range(1, int(TOWER.steps) + 1): var h2: float = k * TOWER.step; var z1: float = H + 0.5 * (TOWER.steps - k); add.call(-0.7, 0.0, z1, 0.7, h2, z1 + 0.5)
	add.call(-H, PH, -H - 0.06, H, PH + 1.1, -H + 0.06, true); add.call(-H - 0.06, PH, -H, -H + 0.06, PH + 1.1, H, true); add.call(H - 0.06, PH, -H, H + 0.06, PH + 1.1, H, true)
	add.call(-H, PH, H - 0.06, -0.75, PH + 1.1, H + 0.06, true); add.call(0.75, PH, H - 0.06, H, PH + 1.1, H + 0.06, true)
	add.call(-H - 0.1, 6.7, -H - 0.1, H + 0.1, 7.0, H + 0.1)
	# sixteen places along its foot, one animal each
	var s_end: float = H + 0.5 * TOWER.steps
	var along := func(x0: float, z0: float, x1: float, z1: float, nx: float, nz: float) -> void:
		var L := Vector2(x1 - x0, z1 - z0).length(); var n := maxi(1, roundi(L / 1.9))
		for i in n: var u := (i + 0.5) / n; slots.push_back({"x": x + x0 + (x1 - x0) * u, "z": z + z0 + (z1 - z0) * u, "nx": nx, "nz": nz, "owner": null, "t": -9.0})
	along.call(-Bh, -Bh, Bh, -Bh, 0.0, -1.0); along.call(-Bh, -Bh, -Bh, Bh, -1.0, 0.0); along.call(Bh, -Bh, Bh, Bh, 1.0, 0.0)
	along.call(-Bh, Bh, -0.7, Bh, 0.0, 1.0); along.call(0.7, Bh, Bh, Bh, 0.0, 1.0)
	along.call(-0.7, Bh, -0.7, s_end, -1.0, 0.0); along.call(0.7, Bh, 0.7, s_end, 1.0, 0.0); along.call(-0.7, s_end, 0.7, s_end, 0.0, 1.0)

## the animals spread over the plain: herds of zebra, buffalo and giraffe, hippos round the waterhole, the cats and elephants further out
func populate(put: Callable, find: Callable, SR: World.Rng) -> void:
	for row in ROSTER:
		var kind: String = row[0]; var c: int = row[1]; var guard := 0
		while c > 0 and guard < 400:
			guard += 1
			if kind == "zebra" or kind == "buffalo" or kind == "giraffe":
				var center = find.call(70.0, 10.0, 2.0)
				if center == null: break
				if put.call(kind, center, {}) != null: c -= 1
				var herd := 3 if kind == "giraffe" else int(floor(SR.rng(3, 6)))
				for i in range(1, herd):
					if c <= 0: break
					if put.call(kind, find.call(60.0, 2.6, 1.3, center, 8.0), {}) != null: c -= 1
			elif kind == "gorilla":   # two troops of three
				var center2 = find.call(85.0, 12.0, 2.0)
				if center2 == null: break
				if put.call(kind, center2, GORILLA) != null: c -= 1
				for i in range(1, 3):
					if c <= 0: break
					if put.call(kind, find.call(80.0, 3.0, 1.3, center2, 7.0), GORILLA) != null: c -= 1
			elif kind == "hippo":
				var a := SR.rng(0, TAU)
				var p = find.call(60.0, 3.0, 1.5, {"x": WATER.x + cos(a) * (WATER.r + 2.5), "z": WATER.z + sin(a) * (WATER.r + 2.5)}, 4.0)
				if p == null: p = find.call(70.0, 6.0, 2.0)
				if put.call(kind, p, {}) != null: c -= 1
			else:
				var el := kind == "elephant"
				if put.call(kind, find.call(90.0 if el else 80.0, 14.0 if el else 8.0, 2.4 if el else 1.4), {}) != null: c -= 1

func update(dt: float) -> void:
	clock += dt; _tower_update(dt)
	if stampede or (game and game.ended): return
	t += dt; var l := T_STAMPEDE - t
	if warned < 1 and l <= 60.0: warned = 1; Snd.play("alarm"); game.say_banner("1분 뒤 습격", "감시탑 위로 올라가 준비하세요", 2.8)
	if warned < 2 and l <= 10.0: warned = 2; Snd.play("alarm"); game.say_banner("10초 뒤 습격", "땅이 울리기 시작합니다", 2.2); player.shake = maxf(player.shake, 0.15)
	if l <= 0.0: go()

## the stampede: every animal still alive (and not tamed) is set off at once and heads for you, and the tower you stand on
func go() -> void:
	if stampede: return
	stampede = true; t = T_STAMPEDE; var roars := 0
	for e in enemies.list:
		if not e.alive or not e.wild or e.tamed: continue
		e.angry = true; e.alert = true; e.awake = true
		if not e.fury: e.fury = true; e.state = "chase"; enemies.animals.wake(e)
		if e.type != "zebra" and roars < 8 and randf() < 0.25: roars += 1; Snd.play("roar_" + e.T.roar, 1.0, e.pos)
	Snd.play("quake"); Snd.play("siren"); player.shake = maxf(player.shake, 0.45)
	game.say_banner("동물들이 몰려옵니다!", "탑 위에 있으면 동물들은 탑부터 칩니다 · 기린은 목으로 탑 위까지 칩니다" if holds() else "감시탑으로 올라가세요!", 3.4)
	game.say_feed("습격 시작 · 모든 동물이 감시탑으로")

# ---------------- the tower ----------------
## a place at the tower for this animal: the one it already has, or the free one nearest to it. null: all taken, wait
func claim(e):
	if e.slot != null and e.slot.owner == e: e.slot.t = clock; return e.slot
	var best = null; var bd := INF
	for s in slots:
		if s.owner != null and s.owner != e and s.owner.alive and clock - s.t < 0.6: continue
		var d := Vector2(s.x - e.pos.x, s.z - e.pos.z).length()
		if d < bd: bd = d; best = s
	if best != null: best.owner = e; best.t = clock; e.slot = best
	return best

## where you are: up on the platform, or high enough on the steps that nothing but a giraffe reaches you
func player_on() -> bool:
	if not standing: return false
	var px := player.pos.x - outer.position.x; var pz := player.pos.z - outer.position.z; var py := player.pos.y
	if py > TOWER.ph - 0.6 and absf(px) < TOWER.half + 0.1 and absf(pz) < TOWER.half + 0.1: return true
	return py > 2.3 and absf(px) < 0.8 and pz > TOWER.half - 0.1 and pz < TOWER.half + 0.5 * TOWER.steps + 0.1

func hurt(dmg: float, at: Vector3) -> void:
	if not standing or (game and game.ended) or dmg <= 0.0: return
	hp = maxf(0.0, hp - dmg); shake = minf(1.0, shake + 0.2 + dmg / 60.0)
	if fx: fx.chips(at)
	if crack_t <= 0.0:
		crack_t = 0.12; Snd.play("crack", 1.0, at)
		if dmg >= 40.0: Snd.play("thud", 1.0, at)
	if on: player.shake = maxf(player.shake, 0.05 + dmg / 500.0)
	var f: float = hp / TOWER.hp
	for m: float in [0.75, 0.5, 0.25, 0.1]:
		if f <= m and not marks.has(m): marks[m] = true; game.say_banner("감시탑 체력 %d%%" % roundi(m * 100), "곧 무너집니다! 탑을 치는 동물부터 잡으세요" if m <= 0.25 else "탑을 공격하는 동물을 쏘세요", 2.0)
	if hp <= 0.0: collapse()

## down it comes: the colliders go at once, the frame topples and sinks into a heap of dust
func collapse() -> void:
	if not standing: return
	var was := player_on()
	standing = false; on = false; fall_t = 0.0; fall_dir = 1.0 if randf() < 0.5 else -1.0
	for b in cols: Phys.remove_collider(b)
	cols.clear(); Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	var c := Vector3(outer.position.x, 1.5, outer.position.z); Snd.play("crack", 1.0, c); Snd.play("quake", 1.0, c); Snd.play("boom", 0.6, c)
	player.shake = maxf(player.shake, 0.7)
	if was:
		player.grounded = false; player.vel.y = 2.5; player.vel.x += fall_dir * 2.0; player.stun_t = maxf(player.stun_t, 1.0)
		game.say_banner("감시탑이 무너졌습니다", "땅으로 떨어졌습니다 · 이제 동물들이 나를 노립니다", 3.0)
	else: game.say_banner("감시탑이 무너졌습니다", "이제 숨을 곳이 없습니다", 2.6)
	game.say_feed("감시탑 붕괴")

func _tower_update(dt: float) -> void:
	crack_t -= dt; on = player_on()
	if on and not hinted and not game.ended: hinted = true; game.say_hint("감시탑 위 · 동물들은 탑부터 공격합니다 (기린은 목으로 탑 위까지 칩니다)", 3.2)
	if standing:
		shake = maxf(0.0, shake - dt * 2.2); var lean: float = (1.0 - hp / TOWER.hp) * 0.035; var s := shake * 0.06
		inner.position = Vector3(randf_range(-1, 1) * s, 0, randf_range(-1, 1) * s); inner.rotation = Vector3(lean * 0.6, 0, lean)
	elif fall_t >= 0.0:
		fall_t += dt; var k := minf(1.0, fall_t / 1.5); var a := k * k * 1.45
		inner.rotation = Vector3(0, 0, fall_dir * a); inner.position = Vector3(fall_dir * sin(a) * 1.6, -maxf(0.0, fall_t - 1.5) * 1.2, 0)
		if fall_t > 1.5 and not landed: landed = true; Snd.play("quake", 1.0, Vector3(outer.position.x + fall_dir * 5.0, 0.5, outer.position.z))
		if fall_t > 4.0: outer.visible = false; fall_t = -1.0
