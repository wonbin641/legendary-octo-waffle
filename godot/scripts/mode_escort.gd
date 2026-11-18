class_name ModeEscort
extends ToyMode
## 장난감 기차 호위전: push the freight train down the line into their terminal. A big plastic track runs from the carpet
## (south-west), east along it, north through a tunnel under the bed, west along the north floor, round and up a square
## spiral ramp of building blocks, and along the desk to the terminal at its far end. The train is an engine and a cargo
## wagon walled with blocks (cover for whoever rides it) with an ammo box on board: a little fortress on wheels. It goes
## while one of ours is beside it and none of theirs, the faster the more of us; with both sides beside it, it stands; left
## alone it rolls back (never past a checkpoint). Their side lays thumbtacks (the train crawls over them) and mousetraps
## (it stops dead) on the track ahead, both shot to bits by a few rounds, and keeps snipers on the bookshelf and the wardrobe.

const H := 0.128571   # the spiral's rise a metre: 9 m over its 70
const TRACK := [Vector3(-38, 0, 52), Vector3(28, 0, 52), Vector3(28, 0, -38), Vector3(-18, 0, -38),
	Vector3(-18, 1.2857, -48), Vector3(-28, 2.5714, -48), Vector3(-28, 3.8571, -38), Vector3(-18, 5.1429, -38),
	Vector3(-18, 6.4286, -48), Vector3(-28, 7.7143, -48), Vector3(-28, 9.0, -38), Vector3(-28, 9.0, -28), Vector3(-28, 9.0, -14), Vector3(-48, 9.0, -14)]
const CP_AT := [2, 3, 11]       # the checkpoints: the corner after the tunnel, the foot of the spiral, the top of it at the desk
const ENGINE_AHEAD := 6.0       # the engine runs this far ahead of the wagon; the train is in when the engine is at the end
const PUSH_R := 7.0
const START := 150.0            # seconds to the first checkpoint, and each one reached gives this much more
const CP_TIME := 90.0
const CP_PAY := 5000
const SPEED := 1.6              # one of us beside it; each one more adds 0.25, up to 2.4 (three quarters of that on the spiral)
const BACK_AFTER := 8.0         # left alone this long, it starts rolling back
const BACK_V := 0.5
const TRAPS_MAX := 3
const AMMO_CD := 20.0
const SPAWN_US := [[Vector3(-34, 0, 58), Vector3(-30, 0, 57), Vector3(-26, 0, 58), Vector3(-34, 0, 61)],
	[Vector3(34, 0, -32), Vector3(36, 0, -38), Vector3(32, 0, -44), Vector3(38, 0, -42)],
	[Vector3(-8, 0, -34), Vector3(-6, 0, -40), Vector3(-10, 0, -44), Vector3(-4, 0, -36)],
	[Vector3(-24, 9, -24), Vector3(-25, 9, -20), Vector3(-23.5, 9, -17), Vector3(-26, 9, -10)]]
const SPAWN_THEM := [Vector3(-48, 9, -4), Vector3(-52, 9, -8), Vector3(-44, 9, -22), Vector3(-40, 9, -24), Vector3(-56, 9, -10), Vector3(-50, 9, -24)]
const NESTS := [Vector3(-44, 20, -58), Vector3(-26, 20, -58), Vector3(28, 24, -57)]
const GUARDS := [Vector3(-42, 9, -18), Vector3(-54, 9, -12)]
const SQUAD := [["soldier", "sniper", "nest"], ["soldier", "sniper", "nest"], ["soldier", "sniper", "nest"], ["soldier", "trooper", "trap"], ["brick", "brick", "trap"],
	["figure", "smg", "guard"], ["brick", "brick", "guard"], ["soldier", "trooper", "push"], ["soldier", "trooper", "push"], ["figure", "shotgun", "push"], ["figure", "smg", "push"], ["soldier", "trooper", "push"]]

var room: ToyRoom
var cum: Array = []             # the track's length up to each of its points
var total := 0.0
var d := 0.0                    # where the wagon is along the track
var cp := 0                     # checkpoints reached
var cp_d: Array = []
var overtime := false
var idle_t := 0.0
var slow_t := 0.0
var stop_t := 0.0
var near_us := 0
var near_them := 0
var moving := 0.0               # how fast it went this turn (- rolling back)
var traps: Array = []           # {kind, d, pos, node, rec (crate record), dead}
var ammo_t := 0.0
var cars := {}                  # wagon / engine: {node, boxes: [Phys.Box]}
var done := false
var _whistle_t := 0.0

func _init() -> void:
	time_left = START; lose_stamp = "호위 실패"; lose_title = "기차가 종착역에 닿지 못했습니다"

func skips(what: String) -> bool:
	return what in ["train", "tacks_mid", "tacks_east", "block_-18_50", "block_14_52", "sock_24_18"]

# ---------------- the track ----------------
func _measure() -> void:
	cum = [0.0]
	for i in range(1, TRACK.size()): cum.push_back(float(cum[i - 1]) + (TRACK[i] as Vector3).distance_to(TRACK[i - 1]))
	total = cum[cum.size() - 1]; cp_d = CP_AT.map(func(i): return float(cum[i]))

## the point on the track this far along, and the way it runs there (a turn is eased over three metres)
func at(dist: float) -> Vector3:
	dist = clampf(dist, 0.0, total)
	for i in range(1, TRACK.size()):
		if dist <= float(cum[i]) or i == TRACK.size() - 1:
			var a: Vector3 = TRACK[i - 1]; var b: Vector3 = TRACK[i]; var l: float = float(cum[i]) - float(cum[i - 1])
			var p := a.lerp(b, clampf((dist - float(cum[i - 1])) / maxf(l, 0.001), 0.0, 1.0))
			if i > 3 and i <= 10: p.y += H   # (up on the spiral's steps: on top of the one under it)
			return p
	return TRACK[TRACK.size() - 1]

func heading(dist: float) -> float:
	var a := at(dist - 1.5); var b := at(dist + 1.5)
	if Vector2(b.x - a.x, b.z - a.z).length() < 0.01: a = at(dist - 3.0); b = at(dist)
	return atan2(b.x - a.x, b.z - a.z)

func climbing(dist: float) -> bool: return dist > float(cum[3]) and dist < float(cum[10])

func extra_nodes() -> Dictionary:
	# (on the lane's middle line, at its corners: across a run's steps a toy would stand on two of them at once and stick)
	return {"sp0": Vector3(-18, 0, -34), "sp1": Vector3(-18, 1.2857, -48), "sp2": Vector3(-28, 2.5714, -48), "sp3": Vector3(-28, 3.8571, -38), "sp4": Vector3(-18, 5.1429, -38),
		"sp5": Vector3(-18, 6.4286, -48), "sp6": Vector3(-28, 7.7143, -48), "sp7": Vector3(-28, 9.0, -38), "sp8": Vector3(-28, 9.0, -29), "dk_ne": Vector3(-28, 9, -20)}

func extra_edges() -> Array:
	return [["m_n", "sp0", false, ""], ["z_n", "sp0", false, ""], ["sp0", "sp1", false, "high"], ["sp1", "sp2", false, "high"], ["sp2", "sp3", false, "high"], ["sp3", "sp4", false, "high"],
		["sp4", "sp5", false, "high"], ["sp5", "sp6", false, "high"], ["sp6", "sp7", false, "high"], ["sp7", "sp8", false, "high"], ["sp8", "dk_ne", false, "high"],
		["dk_ne", "dk_n15", false, "high"], ["dk_ne", "dk_e", false, "high"], ["dk_ne", "dk_n1", false, "high"]]

func cut_nodes() -> Array: return ["w_n"]   # (under the spiral)

func keep_off(x: float, z: float, y: float) -> bool:
	for i in range(1, TRACK.size()):
		var a: Vector3 = TRACK[i - 1]; var b: Vector3 = TRACK[i]
		if absf(y - (a.y + b.y) / 2.0) > 4.0: continue
		if ToyMatch._seg_d(Vector2(x, z), Vector2(a.x, a.z), Vector2(b.x, b.z)) < 4.0: return true
	if x > -32.0 and x < -14.0 and z > -52.0 and z < -26.0: return true   # the spiral
	for L in SPAWN_US + [SPAWN_THEM]:
		for p: Vector3 in L:
			if Vector2(x - p.x, z - p.z).length() < 4.0 and absf(y - p.y) < 2.0: return true
	return false

func start() -> Dictionary: return {"x": -30.0, "z": 58.0, "yaw": 0.0}

func build_room(r: ToyRoom) -> void:
	room = r; _measure()
	# the rails and sleepers all along it
	for i in range(1, TRACK.size()):
		var a: Vector3 = TRACK[i - 1]; var b: Vector3 = TRACK[i]; var along_x := absf(b.x - a.x) > 0.5; var n := ceili(Vector2(b.x - a.x, b.z - a.z).length())
		for k in n:
			var f0 := float(k) / n; var f1 := float(k + 1) / n; var p0 := a.lerp(b, f0); var p1 := a.lerp(b, f1); var top := maxf(p0.y, p1.y)
			if top > 0.05: _slab(p0, p1, top, along_x)   # up off the floor: a block deck under it
			var y := top + 0.02
			if k % 2 == 0: r.parts.push_back([3.0 if not along_x else 0.5, 0.1, 0.5 if not along_x else 3.0, (p0.x + p1.x) / 2.0, y + 0.05, (p0.z + p1.z) / 2.0, "8d5a34"])   # a sleeper
			for side: float in [-0.75, 0.75]:
				var cx: float = (p0.x + p1.x) / 2.0 + (0.0 if along_x else side); var cz: float = (p0.z + p1.z) / 2.0 + (side if along_x else 0.0)
				r.parts.push_back([1.02 if along_x else 0.14, 0.14, 0.14 if along_x else 1.02, cx, y + 0.17, cz, "8d99ae"])
	# the spiral's core: a tower of blocks; posts at its outer corners
	var cols := ["e63946", "f4d35e", "3d7dca", "5fbf8f", "f77f00"]
	for k in 8: r.box(-26.0, k * 1.5, -46.0, -20.0, (k + 1) * 1.5, -40.0, cols[k % 5])
	for q in [[-30.1, -50.1], [-15.9, -50.1], [-30.1, -35.9], [-15.9, -35.9]]: r.box(q[0] - 0.45, 0.0, q[1] - 0.45, q[0] + 0.45, 9.4, q[1] + 0.45, "c9ced6", "metal")
	# the tunnel's mouths, at both ends of the bed
	for z in [30.0, -30.0]:
		r.box(24.8, 0.0, z - 0.4, 25.6, 4.4, z + 0.4, "8d99ae"); r.box(30.4, 0.0, z - 0.4, 31.2, 4.4, z + 0.4, "8d99ae"); r.box(24.8, 3.8, z - 0.4, 31.2, 4.4, z + 0.4, "5c6170", "concrete", false)
	# the stations: a platform at the start, the terminal with its house and a buffer at the end of the line
	r.box(-44.0, 0.0, 54.2, -32.0, 0.6, 56.4, "c98b5a")
	r.box(-52.0, 9.0, -17.4, -44.0, 9.8, -16.0, "c98b5a"); r.box(-52.0, 9.0, -21.0, -46.0, 13.0, -17.6, "e9c46a"); r.box(-52.6, 13.0, -21.6, -45.4, 13.6, -17.0, "d62828", "concrete", false)
	r.box(-50.0, 9.0, -15.6, -49.0, 10.6, -12.4, "e63946")
	var font: Font = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf")
	var sign := Label3D.new(); sign.font = font; sign.text = "종착역"; sign.font_size = 160; sign.pixel_size = 0.01; sign.modulate = Color("2b2d42"); sign.outline_size = 0; sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; sign.position = Vector3(-49.0, 12.0, -17.5); r.G.add_child(sign)
	var sign2 := Label3D.new(); sign2.font = font; sign2.text = "출발역"; sign2.font_size = 140; sign2.pixel_size = 0.01; sign2.modulate = Color("2b2d42"); sign2.outline_size = 0; sign2.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; sign2.position = Vector3(-38.0, 2.2, 56.5); r.G.add_child(sign2)
	_train()

## one metre of the track off the floor: a slab of block on its own posts (on the spiral, the turn under it stays clear)
func _slab(p0: Vector3, p1: Vector3, top: float, along_x: bool) -> void:
	var x0 := minf(p0.x, p1.x); var x1 := maxf(p0.x, p1.x); var z0 := minf(p0.z, p1.z); var z1 := maxf(p0.z, p1.z)
	if along_x: z0 -= 1.6; z1 += 1.6; x0 -= 0.02; x1 += 0.02
	else: x0 -= 1.6; x1 += 1.6; z0 -= 0.02; z1 += 0.02
	room.box(x0, maxf(0.0, top - 0.4), z0, x1, top, z1, "5fbf8f" if int(top * 3.0) % 2 == 0 else "3d7dca")

## the train: an engine, and the cargo wagon behind it walled with blocks, an ammo box on board
func _train() -> void:
	var eng := Node3D.new(); room.G.add_child(eng)
	var em := MeshInstance3D.new(); em.mesh = Gfx.merge_boxes([[2.6, 0.5, 5.0, 0, 0.45, 0, "2b2d42"], [2.2, 1.8, 3.0, 0, 1.6, -0.8, "3d6fd1"], [2.4, 2.4, 1.6, 0, 1.9, 1.6, "3d6fd1"],
		[0.7, 1.2, 0.7, 0, 3.1, -1.4, "2b2d42"], [2.6, 0.3, 1.8, 0, 3.25, 1.6, "f4d35e"], [2.7, 0.6, 0.5, 0, 0.5, -2.6, "e63946"], [0.6, 0.6, 0.2, -0.8, 1.6, -2.35, "ffe066"], [0.6, 0.6, 0.2, 0.8, 1.6, -2.35, "ffe066"]], true)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.5; em.material_override = mat; eng.add_child(em)
	var wag := Node3D.new(); room.G.add_child(wag)
	var parts := [[2.8, 0.45, 5.2, 0, 0.225, 0, "f77f00"]]
	var bc := ["e63946", "f4d35e", "3d7dca", "5fbf8f"]
	for i in 5:   # block walls down both sides, and across the front
		for side in [-1.22, 1.22]: parts.push_back([0.36, 1.2, 1.0, side, 1.05, -2.0 + i * 1.0, bc[(i + (0 if side < 0 else 2)) % 4]])
	for i in 3: parts.push_back([0.9, 1.0, 0.36, -0.95 + i * 0.95, 0.95, 2.42, bc[(i + 1) % 4]])
	parts.push_back([1.0, 0.75, 0.9, 0, 0.82, 1.4, "2a9d8f"]); parts.push_back([1.02, 0.14, 0.92, 0, 0.9, 1.4, "f4d35e"])   # the ammo box, a yellow band round it
	var wm := MeshInstance3D.new(); wm.mesh = Gfx.merge_boxes(parts, true); wm.material_override = mat; wag.add_child(wm)
	var lab := Label3D.new(); lab.font = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"); lab.text = "탄약"; lab.font_size = 64; lab.pixel_size = 0.006; lab.position = Vector3(0, 1.25, 1.4); lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lab.modulate = Color("f4f1e8"); wag.add_child(lab)
	cars = {"engine": {"node": eng, "boxes": []}, "wagon": {"node": wag, "boxes": []}}
	_place_train(0.0, 0.0)

## the wagon's frame: [centre, heading, along x?]
func _frame(dist: float) -> Array:
	var p := at(dist); var h := heading(dist); return [p, h, absf(sin(h)) > 0.7]

## put the train at this point of the track: its pictures, and the boxes that stand in the way and carry who stands on them
func _place_train(old_d: float, new_d: float) -> void:
	var fw := _frame(new_d); var fe := _frame(new_d + ENGINE_AHEAD)
	var old_w := _frame(old_d)
	# who is standing on the wagon goes with it
	var delta: Vector3 = (fw[0] as Vector3) - (old_w[0] as Vector3)
	if delta.length() > 0.0001 and not (cars.wagon.boxes as Array).is_empty():
		var deck: Phys.Box = cars.wagon.boxes[0]
		for b in _bodies():
			var bp: Vector3 = m.feet(b); var r: float = Player.R if b is Player else b.R
			if absf(bp.y - deck.maxy) < 0.16 and bp.x > deck.minx - r * 0.5 and bp.x < deck.maxx + r * 0.5 and bp.z > deck.minz - r * 0.5 and bp.z < deck.maxz + r * 0.5:
				if b is Player: m.player.pos += delta
				else: b.pos += delta
	for c in cars.values():
		for bx: Phys.Box in c.boxes: Phys.remove_collider(bx)
		c.boxes = []
	var wp: Vector3 = fw[0]; var wx: bool = fw[2]
	var hl := 2.6; var hw := 1.45
	var ax := hl if wx else hw; var az := hw if wx else hl
	var wb: Array = cars.wagon.boxes
	wb.push_back(Phys.add_collider(wp.x - ax, wp.y, wp.z - az, wp.x + ax, wp.y + 0.45, wp.z + az, "wood"))   # the deck
	var s := Vector2(sin(fw[1]), cos(fw[1]))   # forward
	for side: float in [-1.22, 1.22]:   # the side walls (1.2 m over the deck), and the front one
		var off: Vector2 = Vector2(s.y, -s.x) * side   # to the side of the way it runs
		var cx: float = wp.x + off.x; var cz: float = wp.z + off.y
		var sx := 2.5 if wx else 0.18; var sz := 0.18 if wx else 2.5
		wb.push_back(Phys.add_collider(cx - sx, wp.y + 0.45, cz - sz, cx + sx, wp.y + 1.65, cz + sz, "wood"))
	var fx_ := wp.x + s.x * 2.42; var fz := wp.z + s.y * 2.42
	wb.push_back(Phys.add_collider(fx_ - (0.18 if wx else 1.4), wp.y + 0.45, fz - (1.4 if wx else 0.18), fx_ + (0.18 if wx else 1.4), wp.y + 1.45, fz + (1.4 if wx else 0.18), "wood"))
	var ac := Vector3(wp.x + s.x * 1.4, wp.y, wp.z + s.y * 1.4)
	wb.push_back(Phys.add_collider(ac.x - 0.5, wp.y + 0.45, ac.z - 0.5, ac.x + 0.5, wp.y + 1.2, ac.z + 0.5, "wood"))
	for bx: Phys.Box in wb: bx.step = true   # (the floor's flow field leaves it out)
	var ep: Vector3 = fe[0]; var ex: bool = fe[2]
	var eb := Phys.add_collider(ep.x - (2.5 if ex else 1.3), ep.y, ep.z - (1.3 if ex else 2.5), ep.x + (2.5 if ex else 1.3), ep.y + 3.4, ep.z + (1.3 if ex else 2.5), "metal"); eb.step = true
	cars.engine.boxes = [eb]
	(cars.wagon.node as Node3D).position = wp; (cars.wagon.node as Node3D).rotation.y = fw[1]
	(cars.engine.node as Node3D).position = ep; (cars.engine.node as Node3D).rotation.y = fe[1]
	# anyone it runs into is pushed along, or up onto the deck
	if delta.length() > 0.0001:
		for b in _bodies():
			var bp: Vector3 = m.feet(b); var r: float = Player.R if b is Player else b.R; var h: float = Player.HEIGHT if b is Player else b.H
			var hit: Phys.Box = Phys.collide_at(bp.x, bp.y, bp.z, r, h)
			if hit == null or not (wb.has(hit) or hit == eb): continue
			var np: Vector3 = Phys.move_xz(bp, delta.x * 1.6, delta.z * 1.6, r, h, 0.0)[0]
			if Phys.collide_at(np.x, np.y, np.z, r, h) != null and hit == wb[0]: np.y = hit.maxy + 0.01
			if b is Player: m.player.pos = np
			else: b.pos = np

func _bodies() -> Array:
	var out: Array = m.units("us") + m.units("them")
	if m.player_in(): out.push_back(m.player)
	return out

func wagon_pos() -> Vector3: return at(d)

# ---------------- the two sides ----------------
func populate() -> void:
	for i in 6: m.add_unit("us", "soldier", SPAWN_US[0][i % 4] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), {"job": "ride" if i < 2 else "escort", "idx": i})
	for i in SQUAD.size():
		var q: Array = SQUAD[i]; var at_: Vector3 = NESTS[i] if q[2] == "nest" else SPAWN_THEM[i % SPAWN_THEM.size()]
		m.add_unit("them", q[0], at_, {"gun": q[1], "job": q[2], "idx": i, "tint": i % 4})

func on_respawn(u, _team: String) -> void:
	if u is Player: return
	u.k.trap_cd = randf_range(6.0, 12.0); u.k.trap_at = null; u.k.lay_t = 0.0
	if u.k.job == "nest": u.k.look = Vector3(-20, 0, -20)

func spawn_at(team: String, who := "") -> Vector3:
	if team == "them":
		if who == "nest": return NESTS[randi() % NESTS.size()]
		return SPAWN_THEM[randi() % SPAWN_THEM.size()]
	var L: Array = SPAWN_US[mini(cp, 3)]
	for k in 8:
		var p: Vector3 = L[randi() % L.size()] + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		if Phys.collide_at(p.x, p.y + 0.05, p.z, 0.5, 1.8) == null: return p
	return L[0]

func goal(u: Enemies.Foe) -> Dictionary:
	var team: String = u.k.team; var idx := int(u.k.spawn_opts.get("idx", 0)); var wp := wagon_pos(); var h := heading(d); var fwd := Vector3(sin(h), 0, cos(h)); var side := Vector3(fwd.z, 0, -fwd.x)
	if team == "us":
		if u.k.job == "ride":   # up onto the wagon from the back, then stay on it, behind the blocks
			var back := wp - fwd * 3.6
			if u.pos.distance_to(wp) > 3.4: return {"at": back, "near": 1.0, "hurry": true}
			return {"at": wp - fwd * (0.8 if idx % 2 else -0.1) + side * (0.55 if idx % 2 else -0.55), "near": 0.4}
		var off := side * (4.5 if idx % 2 else -4.5) - fwd * (2.0 + (idx % 3) * 2.0)
		return {"at": wp + off, "near": 2.0}
	match str(u.k.job):
		"nest": u.k.look = wp; return {"at": u.k.post, "near": 1.0}
		"guard": u.k.look = wp; return {"at": GUARDS[idx % 2], "near": 1.2}
		"trap":
			if u.k.trap_at != null: return {"at": u.k.trap_at, "near": 1.0, "hurry": true}
	# to the train, to stand beside it (it does not move while they are there)
	return {"at": wp + fwd * (3.0 + (idx % 3) * 2.0) + side * (3.5 if idx % 2 else -3.5), "near": 2.5}

## nothing to fight: our soldiers shoot the traps on the track near them
func spare_target(u: Enemies.Foe):
	if u.k.team != "us": return null
	for t in traps:
		if t.dead: continue
		var tp: Vector3 = t.pos
		if u.pos.distance_to(tp) < 26.0 and Phys.line_of_sight(u.pos + Vector3(0, u.eye_h, 0), tp + Vector3(0, 0.3, 0)): return tp + Vector3(0, 0.2, 0)
	return null

# ---------------- the turn ----------------
func update(dt: float) -> void:
	if done: return
	if not overtime: time_left = maxf(0.0, time_left - dt)
	near_us = 0; near_them = 0
	var wp := wagon_pos()
	if m.player_in() and m.player.pos.distance_to(wp) < PUSH_R: near_us += 1
	for u in m.units("us"):
		if u.pos.distance_to(wp) < PUSH_R: near_us += 1
	for u in m.units("them"):
		if u.pos.distance_to(wp) < PUSH_R: near_them += 1
	if time_left <= 0.0:   # out of time: it goes on (overtime) only while one of us is by the train
		if near_us > 0:
			if not overtime: overtime = true; m.game.say_banner("연장전!", "기차 곁에서 버티세요", 1.8); Snd.play("alarm")
		else: done = true; m.game.lose_match(); return
	var v := 0.0
	slow_t = maxf(0.0, slow_t - dt); stop_t = maxf(0.0, stop_t - dt)
	if stop_t > 0.0: v = 0.0
	elif near_us > 0 and near_them == 0:
		v = minf(2.4, SPEED + 0.25 * (near_us - 1)) * (0.75 if climbing(d) else 1.0) * (0.35 if slow_t > 0.0 else 1.0); idle_t = 0.0
	elif near_us > 0: idle_t = 0.0
	else:
		idle_t += dt
		if idle_t > BACK_AFTER: v = -BACK_V
	var floor_d: float = float(cp_d[cp - 1]) if cp > 0 else 0.0
	var nd := clampf(d + v * dt, floor_d, total - ENGINE_AHEAD)
	moving = (nd - d) / maxf(dt, 0.0001)
	if nd != d:
		var od := d; d = nd; _place_train(od, nd)
		_whistle_t -= dt
		if _whistle_t <= 0.0 and v > 0.0: _whistle_t = 9.0; Snd.play("toy_slide", 0.8, wp)
	for i in range(cp, cp_d.size()):
		if d >= float(cp_d[i]) and cp == i: _checkpoint()
	if d >= total - ENGINE_AHEAD - 0.01: _arrive(); return
	_traps(dt)
	_ammo(dt)
	for u in m.units("them"):
		if u.k.job == "trap": _trapper(u, dt)

func _checkpoint() -> void:
	cp += 1; time_left += CP_TIME; overtime = false
	var pay := 0 if m.game.replay else CP_PAY * Store.PAY
	if pay > 0: Store.save.money += pay; m.game.stats.earned += pay; Store.persist(); Snd.play("coin"); m.game._say(m.game.on_pay, [pay])
	Snd.play("horn"); Snd.play("clear")
	m.game.say_banner("체크포인트 %d / 3" % cp, "시간 +%d초 · 아군은 이제 여기서 다시 나옵니다" % int(CP_TIME), 2.4)
	m.game._say(m.game.feed, ["체크포인트 %d 통과" % cp, pay, false])

func _arrive() -> void:
	done = true; d = total - ENGINE_AHEAD
	Snd.play("horn"); Snd.play("clear")
	var end: Vector3 = TRACK[TRACK.size() - 1]
	if m.fx: m.fx.firework(end + Vector3(0, 4, 0)); m.fx.firework(end + Vector3(3, 6, 2)); m.fx.explode(end + Vector3(0, 2, 0), true, [1.0, 0.8, 0.3])
	m.game.win_match()

## the traps: the train meets them where they lie (tacks slow it, a mousetrap stops it dead); you step on them too
func _traps(dt: float) -> void:
	var front := d + ENGINE_AHEAD + 2.6
	for t in traps:
		if t.dead: continue
		if front >= float(t.d) - 0.3 and front <= float(t.d) + 3.0:
			if t.kind == "tack": slow_t = 4.0; Snd.play("toy_tack", 1.0, t.pos); m.game.say_feed("기차가 압정을 밟았습니다 · 느려집니다")
			else: stop_t = 3.5; Snd.play("clank", 1.0, t.pos); Snd.play("crack", 1.0, t.pos); m.game.say_feed("쥐덫! 기차가 멈췄습니다")
			_break(t)
			continue
		if t.kind == "mouse" and m.player_in() and Vector2(m.player.pos.x - t.pos.x, m.player.pos.z - t.pos.z).length() < 1.1 and absf(m.player.pos.y - t.pos.y) < 0.8:
			m.player.hurt(60.0, t.pos, "body"); Snd.play("clank", 1.0, t.pos); m.game.say_feed("쥐덫을 밟았습니다"); _break(t)
	traps = traps.filter(func(t): return not t.dead)
	if traps.size() > 6: _break(traps[0])

func _lay(kind: String, dist: float) -> void:
	var p := at(dist); var n := Node3D.new(); n.position = p; room.G.add_child(n); var hdg := heading(dist); n.rotation.y = hdg
	var hx := 1.6; var hz := 0.8
	if kind == "tack":
		for i in 10:
			var a := i * 2.4; var rr := 1.3 * sqrt((i + 0.5) / 10.0); var q := Vector3(cos(a) * rr, 0.0, sin(a) * rr * 0.6)
			var c := room.cyl(Vector3.ZERO, 0.45, 0.1, ["e63946", "f4d35e", "3d7dca"][i % 3], false); c.reparent(n, false); c.position = q + Vector3(0, 0.25, 0)
			var pin := room.cyl(Vector3.ZERO, 0.05, 0.7, "c9ced6", false, 0.0); pin.reparent(n, false); pin.position = q + Vector3(0, 0.6, 0)
	else:
		var mm := MeshInstance3D.new(); mm.mesh = Gfx.merge_boxes([[3.0, 0.2, 1.6, 0, 0.1, 0, "c98b5a"], [2.8, 0.08, 0.08, 0, 0.26, -0.6, "c9ced6"], [0.08, 0.08, 1.2, -1.36, 0.26, 0, "c9ced6"], [0.08, 0.08, 1.2, 1.36, 0.26, 0, "c9ced6"], [0.5, 0.12, 0.4, 0.3, 0.26, 0.2, "f4d35e"]], true)
		var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.6; mm.material_override = mat; n.add_child(mm)
	var along_x := absf(sin(hdg)) > 0.7; var ax := hx if not along_x else hz; var az := hz if not along_x else hx
	var rec := {"idx": -1, "hp": 45.0 if kind == "tack" else 80.0, "x": p.x, "z": p.z, "y": p.y, "dead": false, "wall": true, "trap": kind, "node": n}
	rec.b = Phys.add_collider(p.x - ax, p.y, p.z - az, p.x + ax, p.y + 0.3, p.z + az, "wood", rec); m.world.crates.push_back(rec)
	var t := {"kind": kind, "d": dist, "pos": p, "node": n, "rec": rec, "dead": false, "tack": null}
	if kind == "tack": t.tack = {"x": p.x, "z": p.z, "r": 1.6}; room.tacks.push_back(t.tack)
	traps.push_back(t)
	Snd.play("toy_click", 1.0, p)
	m.game.say_feed("상대가 선로에 " + ("압정" if kind == "tack" else "쥐덫") + "을 깔았습니다")

func _break(t: Dictionary) -> void:
	if t.dead: return
	t.dead = true
	if t.tack != null: room.tacks.erase(t.tack)
	var rec: Dictionary = t.rec
	if not rec.dead:
		rec.dead = true; Phys.remove_collider(rec.b)
		if is_instance_valid(t.node): (t.node as Node3D).queue_free()
	if m.fx: m.fx.chunks(t.pos + Vector3(0, 0.3, 0), 6, 0.25, "wood")

## a trap shot to bits (the room's crate code has taken it apart already)
func trap_broken(c: Dictionary) -> void:
	for t in traps:
		if t.rec == c and not t.dead:
			t.dead = true
			if t.tack != null: room.tacks.erase(t.tack)
			m.game.say_feed(("압정" if t.kind == "tack" else "쥐덫") + "을 부쉈습니다")

## a trapper: every so often it walks to the track ahead of the train and lays a trap there
func _trapper(u: Enemies.Foe, dt: float) -> void:
	var k := u.k; k.trap_cd = float(k.get("trap_cd", 8.0)) - dt
	if k.trap_at == null:
		if float(k.trap_cd) <= 0.0 and traps.filter(func(t): return not t.dead).size() < TRAPS_MAX:
			var td := minf(d + ENGINE_AHEAD + randf_range(14.0, 30.0), total - 3.0)
			if td > d + ENGINE_AHEAD + 6.0: k.trap_at = at(td); k.trap_d = td; k.lay_t = 0.0; k.repath = true
		return
	if Vector2(u.pos.x - (k.trap_at as Vector3).x, u.pos.z - (k.trap_at as Vector3).z).length() < 1.6 and absf(u.pos.y - (k.trap_at as Vector3).y) < 1.0:
		k.lay_t = float(k.lay_t) + dt
		if float(k.lay_t) > 1.2:
			if float(k.trap_d) > d + ENGINE_AHEAD + 3.0: _lay("tack" if randf() < 0.55 else "mouse", float(k.trap_d))
			k.trap_at = null; k.trap_cd = randf_range(14.0, 20.0); k.repath = true
	elif float(k.trap_d) < d + ENGINE_AHEAD + 3.0: k.trap_at = null; k.trap_cd = 4.0   # the train got there first

## the ammo box on the wagon: stand by it and every gun is filled (then it needs a while to fill again)
func _ammo(dt: float) -> void:
	ammo_t = maxf(0.0, ammo_t - dt)
	if ammo_t > 0.0 or not m.player_in(): return
	var wp := wagon_pos(); var h := heading(d); var box := wp + Vector3(sin(h), 0, cos(h)) * 1.4
	if Vector2(m.player.pos.x - box.x, m.player.pos.z - box.z).length() < 2.0 and absf(m.player.pos.y - wp.y) < 2.2:
		var any := false
		for id in m.guns.slots:
			var W: Dictionary = Custom.weapon(id); var st: Dictionary = m.guns.wstate[id]
			if float(st.reserve) < float(W.reserve): st.reserve = W.reserve; any = true
		if any: ammo_t = AMMO_CD; Snd.play("pickup_ammo"); m.game.say_feed("탄약 보급 상자 · 모든 총 탄약 가득")

# ---------------- what you see ----------------
func progress() -> float: return clampf(d / (total - ENGINE_AHEAD), 0.0, 1.0)

func hud_cells() -> Array:
	var cs := ceili(time_left)
	return [["스테이지", "5", Color("f2a33a")], ["남은 시간", "연장전" if overtime else "%d:%02d" % [cs / 60, cs % 60], Color("ff5260") if (overtime or time_left < 30.0) else Color("ece6d8")],
		["진행", "%d%%" % roundi(progress() * 100.0), Color("5f9cff")], ["체크포인트", "%d / 3" % cp, Color("ece6d8")], ["가방", Store.won(Store.save.money), Color("ece6d8")]]

func hud_bar() -> Array: return [progress(), Color("5f9cff")]

func hud_lines() -> Array:
	var what := ""
	if stop_t > 0.0: what = "쥐덫에 걸려 멈춤 %.1f초" % stop_t
	elif near_us > 0 and near_them > 0: what = "막힘 · 상대가 기차 곁에 있습니다"
	elif near_us > 0: what = "밀고 있음 · 아군 %d" % near_us + (" · 압정 때문에 느림" if slow_t > 0.0 else "")
	elif idle_t > BACK_AFTER: what = "아무도 없어 되밀리는 중"
	else: what = "멈춤 · 기차 곁(7 m)으로 가세요"
	var dd: float = m.player.pos.distance_to(wagon_pos())
	return [["기차", what, "%d m" % roundi(dd), stop_t > 0.0 or (near_them > 0 and near_us > 0)]]

func status() -> String:
	if ammo_t > AMMO_CD - 1.5: return "탄약 보급 완료"
	return ""

func aims() -> Array:
	var out: Array = []
	var wp := wagon_pos()
	if m.player.pos.distance_to(wp) > 14.0: out.push_back([Vector2(wp.x, wp.z), 0.95, Color("5f9cff")])
	for t in traps:
		if not t.dead and (t.pos as Vector3).distance_to(m.player.pos) < 45.0: out.push_back([Vector2(t.pos.x, t.pos.z), 0.75, Color("ff9a3a")])
	return out

func tac(ci, X: Callable, Z: Callable, k: float, u: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector3 in TRACK: pts.push_back(Vector2(X.call(p.x), Z.call(p.z)))
	ci.draw_polyline(pts, Color(0.75, 0.78, 0.84, 0.7), 3.0 * u)
	var done_pts := PackedVector2Array()
	for i in TRACK.size():
		if float(cum[i]) <= d: done_pts.push_back(pts[i])
	var wp := wagon_pos(); done_pts.push_back(Vector2(X.call(wp.x), Z.call(wp.z)))
	if done_pts.size() >= 2: ci.draw_polyline(done_pts, Color("5f9cff"), 3.4 * u)
	for i in CP_AT.size():
		var p: Vector3 = TRACK[CP_AT[i]]; var q := Vector2(X.call(p.x), Z.call(p.z))
		ci.draw_circle(q, 6.0 * u, Color("3dff6e") if i < cp else Color(0.1, 0.12, 0.16, 0.9)); ci.draw_arc(q, 6.0 * u, 0, TAU, 20, Color.WHITE, 1.2 * u)
	var end: Vector3 = TRACK[TRACK.size() - 1]; ci.draw_rect(Rect2(X.call(end.x) - 5.0 * u, Z.call(end.z) - 5.0 * u, 10.0 * u, 10.0 * u), Color("ff5260"))
	ci.draw_rect(Rect2(X.call(wp.x) - 2.6 * k, Z.call(wp.z) - 2.6 * k, 5.2 * k, 5.2 * k), Color("ffd23a"))
	for t in traps:
		if not t.dead:
			var q := Vector2(X.call(t.pos.x), Z.call(t.pos.z)); ci.draw_line(q - Vector2(4, 4) * u, q + Vector2(4, 4) * u, Color("ff9a3a"), 2.0 * u); ci.draw_line(q + Vector2(-4, 4) * u, q + Vector2(4, -4) * u, Color("ff9a3a"), 2.0 * u)
	for n: Vector3 in NESTS: ci.draw_arc(Vector2(X.call(n.x), Z.call(n.z)), 5.0 * u, 0, TAU, 16, Color("ff5260"), 1.4 * u)

func legend() -> Array:
	return [["ally", "5f9cff", "아군 병정 · 기차가 간 길"], ["train", "ffd23a", "화물 열차"], ["soldier", "7fc96b", "플라스틱 군인 (책장·옷장 위 저격수)"], ["figure", "ff7a3a", "액션 피규어"], ["trap", "ff9a3a", "압정 · 쥐덫"], ["enemybase", "ff5260", "종착역"]]

func brief() -> String:
	return "선로 위의 화물 열차를 적진 종착역까지 밀어붙여라! · 페이로드 호위\n카펫 서쪽 출발역에서 카펫을 지나, 침대 밑 터널, 북쪽 바닥, 블록 나선 경사로를 돌아 올라 책상 위 종착역까지\n아군이 기차 곁(7 m)에 있고 상대가 없을 때만 갑니다 · 아군이 많을수록 빨라지고, 양쪽이 다 붙어 있으면 멈추고, 아무도 없으면 되밀립니다(체크포인트 뒤로는 안 감)\n화물칸 위 블록 바리케이드는 엄폐물, 가운데 탄약 상자 곁에 서면 탄약이 가득 찹니다\n상대는 선로 앞에 압정(느려짐)과 쥐덫(멈춤)을 깔고, 책장·옷장 꼭대기에서 저격합니다 · 덫은 쏴서 부술 수 있습니다\n체크포인트 3곳 · 하나마다 시간 +%d초 · 처음 %d초 · 아군 파란 병정 6 · 상대 장난감 12" % [int(CP_TIME), int(START)]

func brief_line() -> String: return "선로 위의 화물 열차를 적진 종착역까지 밀어붙여라!"
func win_title() -> String: return "기차 호위 성공"
func pause_line() -> String:
	var cs := ceili(time_left)
	return "진행 %d%% · 체크포인트 %d/3 · 남은 시간 %d:%02d" % [roundi(progress() * 100.0), cp, cs / 60, cs % 60]

func state() -> Dictionary:
	return {"d": d, "total": total, "cp": cp, "time": time_left, "overtime": overtime, "near_us": near_us, "near_them": near_them, "slow": slow_t, "stop": stop_t, "moving": moving, "idle": idle_t, "done": done,
		"traps": traps.filter(func(t): return not t.dead).map(func(t): return {"kind": t.kind, "d": t.d}), "ammo": ammo_t, "wagon": [wagon_pos().x, wagon_pos().y, wagon_pos().z],
		"jobs": m.units("us").map(func(u): return str(u.k.job)) + m.units("them").map(func(u): return str(u.k.job))}

## for the tests and pictures: at <d> (the train there), trap <tack|mouse> <d>, time <s>
func cmd(a: Array) -> Dictionary:
	match str(a[0]) if a.size() > 0 else "":
		"at":
			var nd := clampf(float(a[1]), 0.0, total - ENGINE_AHEAD); var od := d; d = nd; _place_train(od, nd); cp = 0
			while cp < cp_d.size() and d >= float(cp_d[cp]): cp += 1
		"trap": _lay(str(a[1]), float(a[2]))
		"time": time_left = float(a[1])
	return state()
