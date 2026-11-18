class_name ToyFoes
extends RefCounted
## Stage 5's enemies: four kinds of toy, each with its own way of moving and two things only it can do.
##   plastic soldiers: one piece of green or tan plastic. still for 2 s they go see-through, blinking out of sight and back every
##     second (aim help reaches half as far, the health bar shows from half as far, never while out of sight); explosions barely
##     shove them. snipers and ambushers on the bed and the desk, and riders standing on the wind-up cars.
##   action figures: jointed heroes on the high ground. they jump twice, and coming down from a height they spread a cape and glide,
##     shooting on the way.
##   wind-up and RC units: cars on the floor, each with a plastic soldier standing on it. the car and its rider are two toys, each
##     with its own health: the car drives on its own (at you when you are close and in its sight, ramming; anywhere at random
##     otherwise, and it never stops), the rider only shoots at you when he sees you and never steers. the longer a car runs the
##     faster it goes, and it cannot turn sharply at speed. toys near one shoot faster (it shares its battery); broken, its battery
##     bursts in sparks and its rider steps down and fights on foot.
##   brick figures: block people round the block bridge. they climb straight up walls, shed bricks as they are hurt (a shed brick
##     picked up again heals them, and so does a quiet moment), and put up little brick walls to shoot from behind.

const TOYS := {
	"soldier": {"name": "플라스틱 군인", "hp": 110, "speed": 3.4, "r": 0.35, "h": 1.8, "money": 1000, "sight": 32.0},   # a sniper watches out to 60 m
	"figure": {"name": "액션 피규어", "hp": 140, "speed": 5.2, "r": 0.35, "h": 1.8, "money": 1500, "sight": 36.0},
	"rc": {"name": "태엽·RC 유닛", "hp": 90, "speed": 3.0, "r": 0.6, "h": 0.8, "money": 800, "sight": 26.0},
	"brick": {"name": "조립 블록 피규어", "hp": 160, "speed": 3.0, "r": 0.35, "h": 1.8, "money": 1200, "sight": 30.0},
}
const FEET := {"soldier": [-0.4, 0.4, -0.2, 0.52], "figure": [-0.42, 0.42, -0.3, 0.52], "rc": [-0.5, 0.5, -0.85, 0.85], "brick": [-0.42, 0.42, -0.22, 0.5]}
const CAMO_AFTER := 2.0      # seconds a soldier must keep still before it fades
const CAMO_ALPHA := 0.0       # ...out of sight for a second, back for a second, while it keeps still
const CAMO_BLINK := 1.0
const RC_TOP := 14.0         # a wound-up car's top speed
const RC_WANDER := 6.0       # ...and how fast it goes driving about at random
const SEAT := Vector3(0, 0.75, -0.1)   # where a rider stands on a car: on the roof of its cabin
const RC_ACCEL := 3.2
const SHARE_R := 8.0         # how far a car's battery reaches
const SHARE_MUL := 1.4       # ...and how much faster toys near it shoot
const SPARK_R := 3.5
const SPARK_DMG := 25.0
const WALL_MAX := 12

var en: Enemies
var player: Player
var game = null
var world: World
var fx: Fx = null
var proj: Proj
var tm = null            # the team modes' ToyMatch (null in the sweep: the toys play as above)
var bricks: Array = []   # shed brick parts lying about: {n, pos, t}
var walls: Array = []    # the little brick walls: crate-like records in world.crates

func rnd(a: float, b: float) -> float: return randf_range(a, b)

func clear() -> void:
	for b in bricks:
		if is_instance_valid(b.n): (b.n as Node3D).queue_free()
	for c in walls:
		if is_instance_valid(c.node): (c.node as Node3D).queue_free()
	bricks.clear(); walls.clear()

func _node(parent: Node3D, at: Vector3, parts: Array, key: String, mat: Material = null) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	var mi := MeshInstance3D.new(); mi.mesh = en._box_mesh(key, parts); mi.material_override = mat if mat != null else en._mat; n.add_child(mi); return n

func _hpart(o: Vector3, r: float, mult := 1.0, weak := false) -> Dictionary: return {"o": o, "r": r, "mult": mult, "weak": weak, "bomb": false}

func build(e: Enemies.Foe, type: String, opts: Dictionary) -> void:
	e.toy = true; e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; en.add_child(e.g)
	var role: String = opts.get("role", "")
	e.k = {"role": role, "still": 0.0, "reveal": 0.0, "post": Vector3.ZERO, "move_t": 0.0, "jumps": 0, "glide": false, "v": 0.0, "heading": 0.0, "quiet": 9.0, "shed": 0, "wall_cd": rnd(4, 9), "climb": false, "back_t": 0.0}
	var human := [_hpart(Vector3(0, 1.72, 0.01), 0.15, 1.0, true), _hpart(Vector3(0, 1.3, 0), 0.3), _hpart(Vector3(0, 0.95, 0), 0.22, 0.9), _hpart(Vector3(0, 0.48, 0), 0.24, 0.7)]
	match type:
		"soldier":   # one colour all over, on a flat base, a rifle moulded into the hands
			var mat := Gfx.std(World.lin(["3f7a3a", "b89b63", "203f8a"][clampi(int(opts.get("tint", 0)), 0, 2)]), 0.45); e.k.mat = mat; e.k.alpha = 1.0   # green, tan; blue for ours in the team modes
			var W := "ffffff"; var leg := [[0.15, 0.9, 0.17, 0, -0.45, 0, W], [0.16, 0.09, 0.27, 0, -0.88, 0.05, W]]
			_node(e.g, Vector3.ZERO, [[0.7, 0.05, 0.5, 0, 0.025, 0.05, W]], "ts_base", mat)
			e.leg_l = _node(e.g, Vector3(-0.11, 0.92, 0), leg, "ts_leg", mat); e.leg_r = _node(e.g, Vector3(0.11, 0.92, 0), leg, "ts_leg", mat)
			e.upper = _node(e.g, Vector3(0, 0.92, 0), [[0.44, 0.62, 0.26, 0, 0.36, 0, W], [0.22, 0.25, 0.24, 0, 0.8, 0.01, W], [0.3, 0.1, 0.32, 0, 0.95, 0, W]], "ts_up", mat)
			e.arm_l = _node(e.upper, Vector3(-0.29, 0.6, 0), [[0.12, 0.62, 0.13, 0, -0.29, 0, W]], "ts_arm", mat)
			e.arm_r = _node(e.upper, Vector3(0.29, 0.6, 0), [[0.12, 0.62, 0.13, 0, -0.29, 0, W], [0.05, 1.05 if role == "sniper" else 0.75, 0.08, 0, -0.95, 0.03, W]], "ts_gun_" + role, mat)
			e.parts = human; e.muzzle = Vector3(0.2, 1.42, 1.3 if role == "sniper" else 1.0); e.k.base_y = [1.72, 1.3, 0.95, 0.48]
			var car = opts.get("car", null)
			if car != null: e.k.car = car; e.carried = true; car.k.rider = e; carry(car)   # standing on the cabin roof of its car
		"figure":   # a hero in bright colours with a cape
			var c1: String = ["d62828", "1d4ed8", "f4b400", "7b2cbf"][int(opts.get("tint", 0)) % 4]; var c2: String = ["f4b400", "d62828", "1d4ed8", "f4b400"][int(opts.get("tint", 0)) % 4]
			var leg2 := [[0.15, 0.9, 0.17, 0, -0.45, 0, c1], [0.17, 0.2, 0.28, 0, -0.82, 0.05, c2]]
			e.leg_l = _node(e.g, Vector3(-0.11, 0.92, 0), leg2, "tf_leg" + c1); e.leg_r = _node(e.g, Vector3(0.11, 0.92, 0), leg2, "tf_leg" + c1)
			e.upper = _node(e.g, Vector3(0, 0.92, 0), [[0.46, 0.62, 0.26, 0, 0.36, 0, c1], [0.2, 0.2, 0.02, 0, 0.42, 0.14, c2], [0.22, 0.25, 0.24, 0, 0.8, 0.01, "e0b895"], [0.24, 0.1, 0.25, 0, 0.9, -0.01, c1]], "tf_up" + c1)
			e.arm_l = _node(e.upper, Vector3(-0.3, 0.6, 0), [[0.12, 0.62, 0.13, 0, -0.29, 0, c1], [0.12, 0.14, 0.14, 0, -0.6, 0, c2]], "tf_arm" + c1)
			e.arm_r = _node(e.upper, Vector3(0.3, 0.6, 0), [[0.12, 0.62, 0.13, 0, -0.29, 0, c1], [0.12, 0.14, 0.14, 0, -0.6, 0, c2], [0.07, 0.5 if role == "smg" else 0.7, 0.1, 0, -0.9, 0.03, "24272c"]], "tf_gun" + c1 + role)
			e.head = _node(e.upper, Vector3(0, 0.62, -0.14), [[0.5, 0.85, 0.03, 0, -0.42, 0, c2]], "tf_cape" + c2)   # the cape, hanging down the back
			e.parts = human; e.muzzle = Vector3(0.2, 1.42, 0.9)
		"rc":   # a little car with a wind-up key
			var cc: String = ["e63946", "3d7dca", "f77f00", "5fbf8f"][int(opts.get("tint", 0)) % 4]
			e.body = _node(e.g, Vector3.ZERO, [[0.9, 0.3, 1.6, 0, 0.35, 0, cc], [0.7, 0.26, 0.8, 0, 0.62, -0.1, "dfe8ee"], [0.22, 0.42, 0.14, -0.5, 0.21, 0.5, "1c1c1c"], [0.22, 0.42, 0.14, 0.5, 0.21, 0.5, "1c1c1c"],
				[0.22, 0.42, 0.14, -0.5, 0.21, -0.5, "1c1c1c"], [0.22, 0.42, 0.14, 0.5, 0.21, -0.5, "1c1c1c"], [0.5, 0.08, 0.06, 0, 0.36, 0.82, "ffe066"]], "tr_body" + cc)
			e.head = _node(e.g, Vector3(0, 0.6, -0.86), [[0.06, 0.06, 0.2, 0, 0, -0.08, "c9ced6"], [0.34, 0.2, 0.05, 0, 0, -0.2, "c9a227"]], "tr_key")   # the key, turning on its back
			e.parts = [_hpart(Vector3(0, 0.42, 0), 0.55), _hpart(Vector3(0, 0.6, -0.95), 0.2, 1.0, true)]; e.eye_h = 0.6; e.muzzle = Vector3(0, 0.5, 0.9)
		_:   # a block person: square legs, a square body, a round yellow head with a stud on top
			var cb: String = ["d62828", "1d4ed8", "2a9d8f", "f77f00"][int(opts.get("tint", 0)) % 4]
			var leg3 := [[0.2, 0.75, 0.24, 0, -0.38, 0, "24272c"]]
			e.leg_l = _node(e.g, Vector3(-0.12, 0.78, 0), leg3, "tb_leg"); e.leg_r = _node(e.g, Vector3(0.12, 0.78, 0), leg3, "tb_leg")
			e.upper = _node(e.g, Vector3(0, 0.78, 0), [[0.5, 0.62, 0.3, 0, 0.33, 0, cb], [0.3, 0.3, 0.3, 0, 0.82, 0, "f4d35e"], [0.16, 0.08, 0.16, 0, 1.01, 0, "f4d35e"], [0.16, 0.04, 0.02, 0, 0.78, 0.16, "1c1c1c"]], "tb_up" + cb)
			e.arm_l = _node(e.upper, Vector3(-0.32, 0.56, 0), [[0.13, 0.5, 0.14, 0, -0.24, 0, cb], [0.14, 0.14, 0.16, 0, -0.52, 0.02, "f4d35e"]], "tb_arm" + cb)
			e.arm_r = _node(e.upper, Vector3(0.32, 0.56, 0), [[0.13, 0.5, 0.14, 0, -0.24, 0, cb], [0.14, 0.14, 0.16, 0, -0.52, 0.02, "f4d35e"], [0.07, 0.34, 0.1, 0, -0.72, 0.03, "8d99ae"]], "tb_gun" + cb)
			e.parts = [_hpart(Vector3(0, 1.6, 0), 0.17, 1.0, true), _hpart(Vector3(0, 1.15, 0), 0.32), _hpart(Vector3(0, 0.75, 0), 0.24, 0.9), _hpart(Vector3(0, 0.38, 0), 0.24, 0.7)]; e.muzzle = Vector3(0.22, 1.3, 0.8); e.k.tint = cb
	e.bar = Node3D.new(); e.bar.visible = false; en.add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = en._bar_mesh; e.fill.material_override = en._bar_fill; e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)

## a hundred toys about the room, each kind where it fights best. the same every time
func populate(put: Callable, SR: World.Rng) -> void:
	var st := world.start; var placed: Array = []
	var at := func(x0: float, x1: float, z0: float, z1: float, y: float, gap: float, rad := 0.6):
		for k in 80:
			var x := SR.rng(x0, x1); var z := SR.rng(z0, z1); var gy := Phys.ground_at(x, y + 1.2, z, 0.05)
			if absf(Phys.ground_at(x, y + 1.2, z, rad) - gy) > 0.01: continue   # flat under its whole footprint: not on an edge or a step
			if absf(gy - y) > 0.5 or Phys.collide_at(x, gy + 0.05, z, rad, 1.8) != null or Vector2(x - st.x, z - st.z).length() < 16.0: continue
			var ok := true
			for p: Vector3 in placed:
				if p.distance_to(Vector3(x, gy, z)) < gap: ok = false; break
			if not ok: continue
			placed.push_back(Vector3(x, gy, z)); return {"x": x, "z": z, "y": gy}
		return null
	var B := ToyRoom.BED_Y; var D := ToyRoom.DESK_Y; var U := ToyRoom.BUNK_Y; var S := ToyRoom.SHELF_Y; var W := ToyRoom.WARD_Y
	var n := 0
	# plastic soldiers: ambushers in the blanket's trenches and on the desk; snipers by the pencil pot, on the upper bunk and the bookshelf
	for i in 14: put.call("soldier", at.call(12.0, 47.0, -28.0, 28.0, B, 3.0), {"role": "trooper", "tint": i % 2})
	for i in 6: put.call("soldier", at.call(-60.0, -24.0, -26.0, 18.0, D, 3.5), {"role": "trooper", "tint": i % 2})
	for i in 6: put.call("soldier", at.call(-60.0, -36.0, -26.0, 18.0, D, 5.0), {"role": "sniper", "tint": 0})
	for i in 2: put.call("soldier", at.call(12.0, 46.0, -28.0, -8.0, U, 6.0), {"role": "sniper", "tint": 1})
	for i in 2: put.call("soldier", at.call(-60.0, -8.0, -67.0, -58.0, S, 8.0), {"role": "sniper", "tint": 0})
	# action figures: the bookshelf, the wardrobe, the upper bunk, the block bridge
	for i in 6: put.call("figure", at.call(-60.0, -8.0, -67.0, -58.0, S, 4.0), {"role": "smg" if i % 2 else "shotgun", "tint": i})
	for i in 4: put.call("figure", at.call(8.0, 48.0, -67.0, -56.0, W, 4.0), {"role": "smg" if i % 2 else "shotgun", "tint": i + 1})
	for i in 6: put.call("figure", at.call(12.0, 60.0, -28.0, 28.0, U, 5.0), {"role": "smg" if i % 2 else "shotgun", "tint": i + 2})
	for i in 4: put.call("figure", at.call(-21.0, -7.0, -3.2, 3.2, D, 3.0), {"role": "shotgun" if i % 2 else "smg", "tint": i + 3})
	for i in 2: put.call("figure", at.call(-46.0, -24.0, -20.0, 16.0, D, 4.0), {"role": "smg", "tint": i})
	# wind-up and RC units under the bed and on the carpet, a plastic soldier standing on each: two toys apiece
	for i in 12:
		var p = at.call(13.0, 60.0, -28.0, 28.0, 0.0, 4.0, 0.8) if i < 6 else at.call(-44.0, 44.0, 34.0, 66.0, 0.0, 5.0, 0.8)
		var car = put.call("rc", p, {"tint": i if i < 6 else i - 5})
		if car == null: continue
		if put.call("soldier", p, {"role": "rider", "tint": i % 2, "car": car, "yaw": car.yaw}) != null: carry(car)
	# brick figures: on and under the block bridge, among the blocks on the carpet, by the toy bins
	for i in 6: put.call("brick", at.call(-21.0, 8.0, -3.4, 3.4, D, 2.2), {"tint": i})
	for i in 4: put.call("brick", at.call(-4.0, 9.0, -3.4, 3.4, D - 2.0, 2.2), {"tint": i + 1})
	for i in 6: put.call("brick", at.call(-20.0, 8.0, -12.0, 12.0, 0.0, 3.0), {"tint": i + 2})
	for i in 8: put.call("brick", at.call(-34.0, 34.0, 38.0, 64.0, 0.0, 4.0), {"tint": i + 3})
	# anyone who found no room in their own corner goes on the mattress
	n = en.list.size()
	while n < 100:
		var p = at.call(12.0, 47.0, -28.0, 28.0, B, 2.0)
		if p == null: break
		put.call("soldier", p, {"role": "trooper", "tint": n % 2}); n += 1

# ---------------- shared ----------------
func _turn(e: Enemies.Foe, yaw: float, rate: float, dt: float) -> void: en._turn_toward(e, yaw, rate, dt)

func _call(e: Enemies.Foe, r: float) -> void:
	for o in en.list:
		if o.toy and not o.alert and o != e and o.pos.distance_to(e.pos) < r: en.alarm(o)

## how much faster this toy shoots: 1, or more with a wind-up car's battery close by (looked up twice a second)
func share(e: Enemies.Foe) -> float:
	if e.type == "rc": return 1.0
	return float(e.k.get("share", 1.0))

func _share(e: Enemies.Foe) -> float:
	for o in en.list:
		if o.alive and o.type == "rc" and o.pos.distance_to(e.pos) < SHARE_R: return SHARE_MUL
	return 1.0

func _shoot(e: Enemies.Foe, speed: float, dmg: float, spread: float, snd: String) -> void:
	var mz := en.muzzle_of(e); var d := mz.distance_to(player.pos)
	var aim := Vector3(player.pos.x + player.vel.x * d / (speed * 1.3), player.pos.y + 1.25, player.pos.z + player.vel.z * d / (speed * 1.3))
	proj.bullet(mz, aim, speed, dmg * e.dmg_mul, spread); Snd.play(snd, 1.0, mz); e.k.reveal = 1.5

## bursts: shots from a to b, gap seconds apart, then a pause of p0 to p1. returns true while a burst is going
func _burst(e: Enemies.Foe, dt: float, a: int, b: int, gap: float, p0: float, p1: float, speed: float, dmg: float, spread: float, snd: String) -> bool:
	e.fire_t -= dt * share(e)
	if e.burst > 0:
		e.burst_t -= dt
		if e.burst_t <= 0.0: e.burst -= 1; e.burst_t = gap; _shoot(e, speed, dmg, spread, snd)
		return true
	if e.fire_t <= 0.0: e.burst = randi_range(a, b); e.burst_t = 0.0; e.fire_t = rnd(p0, p1)
	return false

func _walk(e: Enemies.Foe, sp: float, dt: float, aim: bool) -> void:
	e.walk += dt * sp * 2.6; var s := sin(e.walk) * clampf(sp / 3.0, 0.0, 1.0) * 0.7
	e.leg_l.rotation.x = s; e.leg_r.rotation.x = -s
	if aim: e.arm_r.rotation = Vector3(-PI / 2 + 0.05, 0, 0); e.arm_l.rotation = Vector3(-1.25, 0, 0.5)
	else: e.arm_r.rotation = Vector3(-s * 0.8, 0, 0); e.arm_l.rotation = Vector3(s * 0.8, 0, 0)
	e.flinch = maxf(0.0, e.flinch - dt * 5.0); e.upper.rotation.x = -e.flinch * 0.25

func update(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var T := e.T; var k := e.k
	k.reveal = maxf(0.0, float(k.reveal) - dt); k.quiet = float(k.quiet) + dt
	k.share_t = float(k.get("share_t", 0.0)) - dt
	if k.share_t <= 0.0: k.share_t = 0.5; k.share = _share(e)
	if not e.alert:
		var sight: float = 60.0 if k.role == "sniper" else T.sight
		if (e.los and dist < sight) or dist < 6.0: en.alarm(e); _call(e, 14.0)
	match e.type:
		"soldier": _rider(e, dt, dist, face_yaw) if e.carried else _soldier(e, dt, dist, to, face_yaw)
		"figure": _figure(e, dt, dist, to, face_yaw)
		"rc": _rc(e, dt, dist, to)
		_: _brick(e, dt, dist, to, face_yaw)

# ---------------- plastic soldiers ----------------
func camo(e: Enemies.Foe) -> bool: return e.type == "soldier" and float(e.k.still) >= CAMO_AFTER and float(e.k.reveal) <= 0.0

func _soldier(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var k := e.k; var sniper: bool = k.role == "sniper"; var sp := 0.0
	if k.post == Vector3.ZERO: k.post = e.pos
	# on the move to a new post: no cover, no camouflage
	if float(k.move_t) > 0.0:
		k.move_t = float(k.move_t) - dt; var pv := Vector2(k.post.x - e.pos.x, k.post.z - e.pos.z)
		if pv.length() < 0.5 or float(k.move_t) <= 0.0: k.move_t = 0.0
		else: var pn := pv.normalized(); sp = e.speed; _turn(e, atan2(pn.x, pn.y), 7.0, dt); en._ground_move(e, pn.x * sp, pn.y * sp, dt)
		k.still = 0.0
	else:
		k.still = float(k.still) + dt
		if e.alert:
			_turn(e, face_yaw, 5.0, dt)
			var rng := 90.0 if sniper else 45.0
			if e.los and dist < rng:
				e.react -= dt
				if e.react <= 0.0:
					if sniper: _burst(e, dt, 1, 1, 0.1, 3.5, 5.0, 140.0, 30.0, 0.25 + dist * 0.006, "toy_shot_sniper")
					else: _burst(e, dt, 3, 4, 0.12, 1.4, 2.2, 80.0, 10.0, 0.35 + dist * 0.028, "toy_shot_smg")
			else: e.react = maxf(e.react, 0.5)
			# you are right on top of it, or it has not seen you for a while: off to another post a few metres away
			k.back_t = float(k.back_t) + (dt if (not e.los or dist < 7.0) else -dt * 2.0); k.back_t = maxf(0.0, float(k.back_t))
			if float(k.back_t) > (1.2 if dist < 7.0 else 6.0):
				k.back_t = 0.0
				for t in 8:
					var a := rnd(0, TAU); var r := rnd(3.0, 7.0); var x := e.pos.x + cos(a) * r; var z := e.pos.z + sin(a) * r; var gy := Phys.ground_at(x, e.pos.y + 1.0, z, e.R)
					if absf(gy - e.pos.y) < 0.6 and Phys.collide_at(x, gy + 0.05, z, e.R, 1.8) == null: k.post = Vector3(x, gy, z); k.move_t = 3.0; break
		en._ground_move(e, e.vel.x, e.vel.z, dt); e.vel *= exp(-dt * 6.0)
	# crouched and blinking while it keeps still: out of sight for a second, back for a second, and so on; standing and plain while
	# it moves or has just fired
	var hid := camo(e); k.blink = float(k.get("blink", 0.0)) + dt if hid else 0.0
	_fade(e, CAMO_ALPHA if (hid and fmod(float(k.blink), 2.0 * CAMO_BLINK) < CAMO_BLINK) else 1.0, dt)
	var crouch := float(k.move_t) <= 0.0; e.g.scale.y = lerpf(e.g.scale.y, (0.72 if crouch else 1.0) * e.scale, 1.0 - exp(-dt * 10.0))
	var sy := e.g.scale.y / e.scale; e.H = 1.8 * e.g.scale.y; e.eye_h = 1.65 * sy; e.muzzle.y = 1.42 * sy
	for i in 4: e.parts[i].o.y = float(k.base_y[i]) * sy   # the hit spheres crouch with it
	_walk(e, sp, dt, e.alert and float(k.move_t) <= 0.0)

## the soldier's see-through plastic: quick to go and quick to come back (a blink); gone, it is not drawn at all, shadow and all
func _fade(e: Enemies.Foe, want: float, dt: float) -> void:
	var k := e.k; k.alpha = lerpf(float(k.alpha), want, 1.0 - exp(-dt * 14.0))
	if absf(float(k.alpha) - want) < 0.01: k.alpha = want
	var m: StandardMaterial3D = k.mat
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if float(k.alpha) > 0.98 else BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = float(k.alpha)
	k.gone = float(k.alpha) < 0.03
	for c in e.g.get_children(): (c as Node3D).visible = not bool(k.gone)
## out of sight right now (blinked out): its health bar stays hidden too
func gone(e: Enemies.Foe) -> bool: return e.type == "soldier" and bool(e.k.get("gone", false))

# ---------------- riders: plastic soldiers standing on the wind-up cars ----------------
## the rider goes where its car goes (the car is not his to steer), turns to face you and shoots when he sees you, as a trooper
func _rider(e: Enemies.Foe, dt: float, dist: float, face_yaw: float) -> void:
	var k := e.k; var car = k.get("car", null)
	if car == null or not car.alive: dismount(e); _soldier(e, dt, dist, Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z), face_yaw); return
	k.still = 0.0; carry(car)
	if e.alert:
		_turn(e, face_yaw, 6.0, dt)
		if e.los and dist < 45.0:
			e.react -= dt
			if e.react <= 0.0: _burst(e, dt, 3, 4, 0.12, 1.4, 2.2, 80.0, 10.0, 0.35 + dist * 0.028, "toy_shot_smg")
		else: e.react = maxf(e.react, 0.5)
	else: e.yaw = car.yaw
	_fade(e, 1.0, dt); _walk(e, 0.0, dt, e.alert)
## the rider stands on the car's roof: put him there (each time the car moves, so he never falls behind)
func carry(car: Enemies.Foe) -> void:
	var r = car.k.get("rider", null)
	if r == null or not r.alive or not r.carried: return
	var s := Vector3(SEAT.x * cos(car.yaw) + SEAT.z * sin(car.yaw), SEAT.y, -SEAT.x * sin(car.yaw) + SEAT.z * cos(car.yaw))
	r.pos = car.pos + s; r.vel = Vector3.ZERO; r.vy = 0.0
	if r.g != null: r.g.position = r.pos; r.g.rotation.y = r.yaw
## his car broken under him: he steps down onto the floor and fights on as a soldier on foot
func dismount(e: Enemies.Foe) -> void:
	if not e.carried: return
	e.carried = false; e.k.car = null; e.pos.y = Phys.ground_at(e.pos.x, e.pos.y + 0.2, e.pos.z, e.R); e.k.post = e.pos; e.k.move_t = 0.0; e.k.role = "trooper"
	if e.g != null: e.g.position = e.pos

# ---------------- action figures ----------------
func _figure(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var k := e.k; var T := e.T; var grounded := e.pos.y <= Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.02
	if not e.alert: _walk(e, 0.0, dt, false); en._ground_move(e, 0.0, 0.0, dt); return
	var f := to / dist; var smg: bool = k.role == "smg"; var above := player.pos.y - e.pos.y
	var near := 5.0 if not smg else 9.0; var fwd := 1.0 if dist > near + 3.0 else (-0.6 if dist < near - 2.0 else 0.0)
	e.strafe_t -= dt
	if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = rnd(0.8, 2.0)
	var sp: float = T.speed; var mvx := (f.x * fwd - f.y * e.strafe * 0.5) * sp; var mvz := (f.y * fwd + f.x * e.strafe * 0.5) * sp
	if grounded:
		k.jumps = 0; k.glide = false
		var before := e.pos; var blocked := en._ground_move(e, mvx + e.vel.x, mvz + e.vel.z, dt)
		# a wall in the way, or you are higher up: jump
		if (blocked or above > 1.2) and fwd > 0.0 and float(k.get("jump_cd", 0.0)) <= 0.0: e.vy = 11.0; e.pos.y += 0.05; k.jumps = 1; k.jump_cd = 0.9; Snd.play("swoosh", 0.6, e.pos)
		k.jump_cd = float(k.get("jump_cd", 0.0)) - dt
		_walk(e, before.distance_to(e.pos) / maxf(dt, 0.001), dt, e.los)
	else:
		# in the air: it steers, jumps once more at the top if you are still above it, and coming down a long way it spreads the cape
		var air0 := 6.5 if bool(k.glide) else sp
		e.pos = Phys.move_xz(e.pos, f.x * air0 * dt, f.y * air0 * dt, e.R, e.H, 0.3)[0]
		var gy := Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R); var drop := e.pos.y - gy
		if int(k.jumps) == 1 and e.vy < 1.0 and above > 0.5: e.vy = 10.0; k.jumps = 2; Snd.play("swoosh", 0.6, e.pos)
		if e.vy < -2.5 and drop > 3.0: k.glide = true
		if bool(k.glide): e.vy = maxf(e.vy, -2.5)
		e.vy -= 19.0 * dt; e.pos.y = maxf(gy, e.pos.y + e.vy * dt)
		var cl := Phys.ceil_at(e.pos.x, e.pos.y - e.vy * dt, e.pos.z, e.R, e.H)
		if e.pos.y + e.H > cl: e.pos.y = cl - e.H; e.vy = minf(e.vy, 0.0)
		if e.pos.y <= gy: e.vy = 0.0
		e.arm_l.rotation = Vector3(-2.6, 0, 0.5); e.arm_r.rotation = Vector3(-PI / 2, 0, 0); e.leg_l.rotation.x = 0.4; e.leg_r.rotation.x = -0.2
	e.head.rotation.x = lerpf(e.head.rotation.x, 1.35 if bool(k.glide) else (0.5 if not grounded else 0.08), 1.0 - exp(-dt * 8.0)); e.head.scale.x = lerpf(e.head.scale.x, 2.4 if bool(k.glide) else 1.0, 1.0 - exp(-dt * 8.0))
	e.vel *= exp(-dt * 6.0); _turn(e, face_yaw, 8.0, dt)
	# shooting: on its feet or gliding
	e.react -= dt
	if e.los and e.react <= 0.0 and (grounded or bool(k.glide)):
		if smg:
			if dist < 34.0: _burst(e, dt, 6, 9, 0.08, 1.2, 1.9, 80.0, 6.0, 0.55 + dist * 0.03, "toy_shot_smg")
		elif dist < 13.0:
			e.fire_t -= dt * share(e)
			if e.fire_t <= 0.0:
				e.fire_t = rnd(1.6, 2.2); var mz := en.muzzle_of(e)
				for i in 6: proj.bullet(mz, Vector3(player.pos.x, player.pos.y + 1.2, player.pos.z), 70.0, 6.0 * e.dmg_mul, 0.9 + dist * 0.05)
				Snd.play("toy_shot_shotgun", 1.0, mz); k.reveal = 1.5

# ---------------- wind-up and RC units ----------------
func _rc(e: Enemies.Foe, dt: float, dist: float, to: Vector2) -> void:
	var k := e.k
	e.head.rotation.z += dt * (4.0 + float(k.v) * 2.0)   # the key turns faster the faster it goes
	# where to go: at you when you are close and it can see you (to ram you); otherwise anywhere, a new way every few seconds or
	# when it runs into something, and it never stops. backing off for a moment after a hit
	var near: bool = e.los and dist < float(e.T.sight)
	var want := to / dist
	if not near:
		k.wander_t = float(k.get("wander_t", 0.0)) - dt
		if float(k.wander_t) <= 0.0: k.heading = rnd(0.0, TAU); k.wander_t = rnd(2.0, 5.0)
		want = Vector2(sin(float(k.heading)), cos(float(k.heading)))
	if float(k.back_t) > 0.0: k.back_t = float(k.back_t) - dt; want = -want
	# the longer it runs the faster it goes (not so fast just driving about); it cannot turn sharply at speed, so it swings wide (and slides)
	k.v = minf(RC_TOP if near else maxf(RC_WANDER, float(k.v) - RC_ACCEL * dt), float(k.v) + RC_ACCEL * dt); var v: float = k.v
	var turn := lerpf(6.0, 1.3, clampf(v / RC_TOP, 0.0, 1.0)); _turn(e, atan2(want.x, want.y), turn, dt)
	var head := Vector2(sin(e.yaw), cos(e.yaw)); var slide := lerpf(12.0, 2.2, clampf(v / RC_TOP, 0.0, 1.0))
	var cur := Vector2(e.vel.x, e.vel.z).lerp(head * v, 1.0 - exp(-dt * slide)); e.vel.x = cur.x; e.vel.z = cur.y
	var blocked := en._ground_move(e, cur.x, cur.y, dt)
	if blocked: k.v = v * 0.35; e.vel.x *= 0.3; e.vel.z *= 0.3; k.back_t = 0.5; k.wander_t = 0.0   # into a wall: nearly all its speed gone, and off another way
	# the ram: harder the faster it is going
	if near and float(k.back_t) <= 0.0 and v > 5.0 and dist < en.stop_dist(e) + 0.5 and absf(player.pos.y - e.pos.y) < 1.5:
		player.hurt((10.0 + 15.0 * clampf(v / RC_TOP, 0.0, 1.0)) * e.dmg_mul, e.pos, "body"); Snd.play("thud", 1.0, e.pos); Snd.play("metal", 1.0, e.pos)
		player.vel.x += to.x / dist * (4.0 + v * 0.5); player.vel.z += to.y / dist * (4.0 + v * 0.5)
		k.v = 0.0; e.vel = Vector3.ZERO; k.back_t = 1.5
	e.g.rotation.z = clampf(-(head.x * cur.y - head.y * cur.x) * 0.06, -0.3, 0.3)   # leaning in the slide
	carry(e)

## broken, its battery bursts: sparks for anyone close
func rc_burst(e: Enemies.Foe) -> void:
	var c := Vector3(e.pos.x, e.pos.y + 0.4, e.pos.z)
	if fx: fx.spark(c); fx.spark(c + Vector3(0.3, 0.2, 0)); fx.spark(c + Vector3(-0.2, 0.3, 0.2))
	Snd.play("toy_boom", 0.7, c)
	var r = e.k.get("rider", null)
	if r != null and r.alive: dismount(r)
	var d := c.distance_to(Vector3(player.pos.x, player.pos.y + 0.9, player.pos.z))
	if d < SPARK_R and Phys.line_of_sight(c, Vector3(player.pos.x, player.pos.y + 1.0, player.pos.z)): player.hurt(SPARK_DMG * (1.0 - 0.5 * d / SPARK_R), c, "body")

# ---------------- brick figures ----------------
func _brick(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var k := e.k; var T := e.T
	# a quiet moment (nobody has hit it for 4 s and it cannot see you) snaps its bricks back on
	if float(k.quiet) > 5.0 and not e.los and e.hp < e.max_hp: e.hp = e.max_hp; k.shed = 0; e.bar.visible = false; Snd.play("toy_click", 1.0, e.pos)
	# a shed brick underfoot goes back on at once
	if e.hp < e.max_hp:
		for i in range(bricks.size() - 1, -1, -1):
			if (bricks[i].pos as Vector3).distance_to(e.pos) < 1.1: e.hp = minf(e.max_hp, e.hp + e.max_hp / 4.0); k.shed = int((1.0 - e.hp / e.max_hp) * 4.0); (bricks[i].n as Node3D).queue_free(); bricks.remove_at(i); Snd.play("toy_click", 1.0, e.pos); break
	if not e.alert: _walk(e, 0.0, dt, false); en._ground_move(e, 0.0, 0.0, dt); return
	var f := to / dist; var fwd := 1.0 if dist > 20.0 else (-0.6 if dist < 8.0 else 0.0); var above := player.pos.y - e.pos.y
	if not e.los and dist > 6.0: fwd = 1.0
	# hurt, and a brick of its own is lying close: it goes for the brick first
	if e.hp < e.max_hp * 0.7:
		for b in bricks:
			var bv := Vector2(b.pos.x - e.pos.x, b.pos.z - e.pos.z)
			if bv.length() < 9.0 and absf(b.pos.y - e.pos.y) < 1.0: f = bv.normalized(); fwd = 1.2; break
	e.strafe_t -= dt
	if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = rnd(1.0, 2.6)
	var sp: float = T.speed; var mvx := (f.x * fwd - f.y * e.strafe * 0.35) * sp; var mvz := (f.y * fwd + f.x * e.strafe * 0.35) * sp
	var blocked := en._ground_move(e, mvx + e.vel.x, mvz + e.vel.z, dt); e.vel *= exp(-dt * 6.0)
	# a wall in the way with you beyond or above it: its studs grip and it walks straight up
	var top := -1.0
	if blocked and fwd > 0.0 and (above > 0.5 or not e.los): top = _climb_top(e, f)
	k.climb = top > e.pos.y + 0.05
	if bool(k.climb):
		e.vy = 0.0; e.pos.y = minf(top, e.pos.y + 3.2 * dt)
		if e.pos.y >= top - 0.06: e.pos = Phys.move_xz(e.pos, f.x * 0.7, f.y * 0.7, e.R, e.H, 0.5)[0]   # over the edge onto the top
	_turn(e, face_yaw, 6.0, dt); _walk(e, 2.0 if bool(k.climb) else sqrt(mvx * mvx + mvz * mvz), dt, e.los)
	e.react -= dt
	if e.los and dist < 40.0 and e.react <= 0.0 and not bool(k.climb): _burst(e, dt, 2, 3, 0.16, 1.2, 2.0, 75.0, 9.0, 0.4 + dist * 0.03, "toy_shot_pistol")
	# a little wall of bricks to shoot from behind, when it has you in sight and nothing to hide behind
	k.wall_cd = float(k.wall_cd) - dt
	if float(k.wall_cd) <= 0.0 and e.los and dist > 7.0 and dist < 34.0 and not bool(k.climb):
		k.wall_cd = rnd(9, 14); _build_wall(e, f)

## the top of the wall in front, if a brick figure can climb it: no taller than 10 m, room to stand on top, nothing overhead on the way
func _climb_top(e: Enemies.Foe, f: Vector2) -> float:
	var px := e.pos.x + f.x * (e.R + 0.25); var pz := e.pos.z + f.y * (e.R + 0.25)
	var b := Phys.collide_at(px, e.pos.y + 0.1, pz, 0.15, 1.6)
	if b == null or b.maxy - e.pos.y > 10.0: return -1.0
	if Phys.collide_at(px, b.maxy + 0.05, pz, e.R, e.H) != null: return -1.0
	if Phys.ceil_at(e.pos.x, e.pos.y, e.pos.z, e.R, e.H) < b.maxy + e.H: return -1.0
	return b.maxy

func _build_wall(e: Enemies.Foe, f: Vector2) -> void:
	if walls.filter(func(c): return not c.dead).size() >= WALL_MAX: return
	var x := e.pos.x + f.x * 1.3; var z := e.pos.z + f.y * 1.3; var y := Phys.ground_at(x, e.pos.y + 0.6, z, 0.3)
	if absf(y - e.pos.y) > 0.6 or Vector2(x - player.pos.x, z - player.pos.z).length() < 2.5: return
	var along_x := absf(f.y) >= absf(f.x)   # the wall stands across the line to you
	var hx := 1.0 if along_x else 0.25; var hz := 0.25 if along_x else 1.0
	if Phys.collide_at(x, y + 0.05, z, 1.0, 1.2) != null: return
	var n := Node3D.new(); n.position = Vector3(x, y, z); en.add_child(n)
	var cols := ["e63946", "f4d35e", "3d7dca", "5fbf8f"]; var parts := []
	for row in 3:
		for i in 2:
			var c: String = cols[(row + i) % 4]; var o := -0.5 + i
			parts.push_back([0.98, 0.38, 0.5, o, 0.2 + row * 0.4, 0.0, c] if along_x else [0.5, 0.38, 0.98, 0.0, 0.2 + row * 0.4, o, c])
			if row == 2:
				for so in [-0.25, 0.25]: parts.push_back([0.18, 0.08, 0.18, o + so, 1.22, 0.0, c] if along_x else [0.18, 0.08, 0.18, 0.0, 1.22, o + so, c])   # studs on top
	var mi := MeshInstance3D.new(); mi.mesh = Gfx.merge_boxes(parts); mi.material_override = en._mat; n.add_child(mi)
	var rec := {"idx": -1, "hp": 60.0, "x": x, "z": z, "y": y, "dead": false, "wall": true, "node": n}
	rec.b = Phys.add_collider(x - hx, y, z - hz, x + hx, y + 1.2, z + hz, "wood", rec); world.crates.push_back(rec); walls.push_back(rec)
	Snd.play("toy_click", 1.0, n.position); Snd.play("toy_mag_in", 1.0, n.position)

## hurt: at every quarter of its health gone a brick drops off and lies where it fell
func on_hurt(e: Enemies.Foe) -> void:
	e.k.quiet = 0.0; e.k.reveal = maxf(float(e.k.reveal), 1.0)
	if e.type == "soldier": e.k.still = 0.0
	if e.type != "brick" or not e.alive or e.hp <= 0.0: return
	var want := int((1.0 - e.hp / e.max_hp) * 4.0)
	while int(e.k.shed) < want:
		e.k.shed = int(e.k.shed) + 1
		var a := rnd(0, TAU); var p := Vector3(e.pos.x + cos(a) * rnd(0.8, 1.6), 0, e.pos.z + sin(a) * rnd(0.8, 1.6)); p.y = Phys.ground_at(p.x, e.pos.y + 0.6, p.z, 0.2)
		var n := Node3D.new(); n.position = p; en.add_child(n)
		var mi := MeshInstance3D.new(); mi.mesh = en._box_mesh("tb_part" + str(e.k.get("tint", "d62828")), [[0.36, 0.2, 0.2, 0, 0.1, 0, str(e.k.get("tint", "d62828"))], [0.1, 0.06, 0.1, -0.09, 0.23, 0, str(e.k.get("tint", "d62828"))], [0.1, 0.06, 0.1, 0.09, 0.23, 0, str(e.k.get("tint", "d62828"))]])
		mi.material_override = en._mat; n.add_child(mi); n.rotation.y = a; bricks.push_back({"n": n, "pos": p, "t": 0.0}); Snd.play("toy_click", 1.0, p)

## things lying about: you tread on a shed brick and it is gone (nobody snaps it back on)
func tick(dt: float) -> void:
	for i in range(bricks.size() - 1, -1, -1):
		var b: Dictionary = bricks[i]; b.t += dt
		if (b.pos as Vector3).distance_to(player.pos) < 0.9 or b.t > 40.0: (b.n as Node3D).queue_free(); bricks.remove_at(i)
