class_name Enemies
extends Node3D
## The enemies: people with pistols (stage 1). Ported from src/07a_enemies.js and the people's part of src/07b_ai.js.
## Zombies, the other kits, animals and robots join with their stages.

const ETYPES := {"thug": {"hp": 100, "speed": 3.6, "r": 0.35, "h": 1.8, "name": "조직원"}}
const KITS := {"pistol": {"name": "권총", "range": 32.0, "near": 8.0, "far": 20.0, "end": 0.62}}
const JACKETS := ["2b3440", "3d4a33", "4a3b30", "2e2e34", "5a5248", "283a4a", "47302e"]
const SKIN := ["c99a7a", "a8775a", "e0b895", "7d5a44"]
const KEEP_PAD := 0.14
const ACT_R := 55.0
const VIS_R := 85.0

class Foe:
	var type := "thug"; var T: Dictionary; var K: Dictionary; var kit := "pistol"
	var g: Node3D; var leg_l: Node3D; var leg_r: Node3D; var upper: Node3D; var arm_l: Node3D; var arm_r: Node3D; var bar: Node3D; var fill: MeshInstance3D
	var pos := Vector3.ZERO; var vel := Vector3.ZERO; var vy := 0.0; var yaw := 0.0
	var boss := false; var name := ""; var scale := 1.0; var R := 0.35; var H := 1.8; var mass := 1.0
	var hp := 100.0; var max_hp := 100.0; var dmg_mul := 1.0; var diff := 0.0; var speed := 3.6
	var alive := true; var alert := false; var awake := false; var dist := 999.0; var lod := 0.0
	var state := "move"; var los := false; var los_t := 0.0; var no_los := 0.0; var react := 0.0
	var fire_t := 1.0; var burst := 0; var burst_t := 0.0; var strafe := 1.0; var strafe_t := 1.0
	var walk := 0.0; var flinch := 0.0; var idle_t := 0.0; var idle_yaw := 0.0; var has_idle_yaw := false
	var dead_t := 0.0; var fall_dir := -1.0; var vanish := false; var sid := -1
	var foot := {}; var foot_r := 0.0; var parts: Array = []; var muzzle := Vector3(0.2, 1.42, 0.62)
	var extra := false; var self_det := false; var no_pay := false
	var fly := false; var head_x := 0.0   # a flying thing; a head that takes more than the gun's usual headshot (0: the usual)

var list: Array[Foe] = []
var dying: Array[Foe] = []
var skip_calm := false
var player: Player
var cam: Camera3D
var proj: Proj
var on_kill: Callable = Callable()   # (foe, weak)
var _meshes := {}
var _mat: StandardMaterial3D
var _bar_bg: StandardMaterial3D
var _bar_fill: StandardMaterial3D
var _bar_mesh: QuadMesh

func _ready() -> void:
	_mat = StandardMaterial3D.new(); _mat.vertex_color_use_as_albedo = true; _mat.roughness = 0.85
	_bar_bg = Gfx.unlit(Color(0.05, 0.06, 0.09), false); _bar_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; _bar_bg.billboard_keep_scale = true
	_bar_fill = Gfx.unlit(Color("ff5260"), false); _bar_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; _bar_fill.billboard_keep_scale = true; _bar_fill.no_depth_test = false
	_bar_mesh = QuadMesh.new(); _bar_mesh.size = Vector2(1, 1)

func _box_mesh(key: String, parts: Array) -> ArrayMesh:
	if not _meshes.has(key): _meshes[key] = Gfx.merge_boxes(parts)
	return _meshes[key]

func _part(parent: Node3D, at: Vector3, key: String, parts: Array) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	var m := MeshInstance3D.new(); m.mesh = _box_mesh(key, parts); m.material_override = _mat; n.add_child(m)
	return n

## one person: legs, a torso with the head, two arms (the gun in the right hand)
func _build(e: Foe) -> void:
	var body: String = JACKETS[randi() % JACKETS.size()]; var skin: String = SKIN[randi() % SKIN.size()]; var pants := "22252b"
	e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; add_child(e.g)
	var leg := [[0.15, 0.9, 0.17, 0, -0.45, 0, pants], [0.16, 0.09, 0.27, 0, -0.88, 0.05, "161616"]]
	e.leg_l = _part(e.g, Vector3(-0.11, 0.92, 0), "leg", leg); e.leg_r = _part(e.g, Vector3(0.11, 0.92, 0), "leg", leg)
	e.upper = _part(e.g, Vector3(0, 0.92, 0), "up" + body + skin, [[0.44, 0.62, 0.26, 0, 0.36, 0, body], [0.22, 0.25, 0.24, 0, 0.8, 0.01, skin], [0.24, 0.08, 0.26, 0, 0.94, 0, pants]])
	var arm := [[0.12, 0.62, 0.13, 0, -0.29, 0, body], [0.1, 0.1, 0.1, 0, -0.62, 0, skin]]
	e.arm_l = _part(e.upper, Vector3(-0.29, 0.6, 0), "arm" + body + skin, arm)
	e.arm_r = _part(e.upper, Vector3(0.29, 0.6, 0), "armg" + body + skin, arm + [[0.045, 0.1, 0.18, 0, -0.66, 0.06, "1d2024"]])
	e.parts = [{"o": Vector3(0, 1.72, 0.01), "r": 0.15, "mult": 1.0, "weak": true}, {"o": Vector3(0, 1.3, 0), "r": 0.3, "mult": 1.0, "weak": false},
		{"o": Vector3(0, 0.95, 0), "r": 0.22, "mult": 0.9, "weak": false}, {"o": Vector3(0, 0.48, 0), "r": 0.24, "mult": 0.7, "weak": false}]
	e.bar = Node3D.new(); e.bar.visible = false; add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = _bar_mesh; bg.material_override = _bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = _bar_mesh; e.fill.material_override = _bar_fill; e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)

func spawn(type: String, x: float, z: float, opts := {}) -> Foe:
	var e := Foe.new(); e.type = type; e.T = ETYPES[type]; e.kit = opts.get("kit", "pistol"); e.K = KITS.get(e.kit, KITS.pistol)
	_build(e)
	var sc: float = opts.get("scale", 1.0)
	# a person's outline from above, in his own frame (x right, z forward): arms out at the front
	e.foot = {"x0": -0.4 * sc, "x1": 0.4 * sc, "z0": -0.18 * sc, "z1": 0.52 * sc}
	e.foot_r = Vector2(0.4 * sc, 0.52 * sc).length()
	e.boss = opts.get("boss", false); e.mass = (2.0 if e.boss else 1.0) * (sc if sc > 1.05 else 1.0)
	e.name = opts.get("name", e.T.name); e.scale = sc; e.R = e.T.r * sc; e.H = e.T.h * sc
	e.hp = roundf(opts.get("hp", e.T.hp)); e.max_hp = e.hp; e.diff = opts.get("diff", 0.0); e.dmg_mul = opts.get("dmgMul", 1.0)
	e.speed = e.T.speed * randf_range(0.9, 1.1) * (0.9 if e.boss else 1.0)
	e.pos = Vector3(x, opts.get("y", 0.0), z); e.yaw = opts.get("yaw", randf() * TAU)
	e.lod = randf() * 0.5; e.los_t = randf() * 0.3; e.fire_t = randf_range(0.8, 1.6); e.strafe = 1.0 if randf() < 0.5 else -1.0; e.strafe_t = randf_range(1, 2.5); e.walk = randf() * TAU
	e.muzzle = Vector3(0.2, 1.42, e.K.end)
	e.g.position = e.pos; e.g.rotation = Vector3(0, e.yaw, 0); e.g.scale = Vector3.ONE * sc
	if e.boss: e.bar.scale = Vector3.ONE * 1.6
	list.push_back(e)
	return e

func part_centre(e: Foe, p: Dictionary) -> Vector3:
	var cy := cos(e.yaw); var sy := sin(e.yaw); var o: Vector3 = p.o
	return Vector3(e.pos.x + (o.x * cy + o.z * sy) * e.scale, e.pos.y + o.y * e.scale, e.pos.z + (-o.x * sy + o.z * cy) * e.scale)

## the first enemy a ray meets before max_t: null, or {enemy, t, weak, mult, bomb}
func raycast(o: Vector3, d: Vector3, max_t: float):
	var best := max_t; var hit: Foe = null; var r_mult := 1.0; var r_weak := false
	for e in list:
		if not e.alive: continue
		if (e.pos.x - o.x) * d.x + (e.pos.z - o.z) * d.z < -2.0 * e.scale: continue
		for p in e.parts:
			var c := part_centre(e, p); var oc := o - c; var pr: float = p.r * e.scale
			var b := oc.dot(d); var cc := oc.length_squared() - pr * pr; var disc := b * b - cc
			if disc < 0.0: continue
			var t := -b - sqrt(disc)
			if t < 0.0: t = -b + sqrt(disc)
			if t > 0.0 and (t < best - 0.02 or (t < best + 0.02 and p.weak and hit == e and not r_weak)): best = t; hit = e; r_mult = p.mult; r_weak = p.weak
	if hit == null: return null
	return {"enemy": hit, "t": best, "mult": r_mult, "weak": r_weak, "bomb": false}

## touch aim help: the direction to the body part closest to the line of fire (within max_ang), or null
func assist(o: Vector3, d: Vector3, max_ang: float, max_dist: float):
	var best_score := INF; var best = null
	for e in list:
		if not e.alive or not e.g.visible: continue
		for p in e.parts:
			var v := part_centre(e, p) - o; var dist := v.length()
			if dist < 0.5 or dist > max_dist: continue
			var c := v.dot(d) / dist
			if c < 0.9: continue
			var score := acos(minf(1.0, c)) - atan(p.r * e.scale / dist)
			if score > max_ang or score >= best_score: continue
			if score <= 0.0: return null
			if Phys.line_of_sight(o, o + v): best_score = score; best = v / dist
	return best

## wake an enemy up: it starts hunting you
func alarm(e: Foe) -> void:
	if e.alert or not e.alive: return
	e.alert = true; e.state = "move"; e.react = maxf(e.react, randf_range(0.4, 0.8))

## gunfire carries: everyone within earshot comes for you
func noise(at: Vector3, r: float) -> void:
	for e in list:
		if e.alive and Vector2(e.pos.x - at.x, e.pos.z - at.z).length() <= r: alarm(e)

func damage(e: Foe, dmg: float, _at: Vector3, dir: Vector3, weak: bool) -> bool:
	if not e.alive: return false
	e.hp -= dmg; e.flinch = 1.0
	if not e.boss: e.vel.x += dir.x * 0.9; e.vel.z += dir.z * 0.9
	alarm(e); e.los = true; e.react = minf(e.react, 0.3)
	for o in list:
		if Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 18.0: alarm(o)
	if e.hp <= 0.0: kill(e, weak, dir); return true
	return false

func kill(e: Foe, weak: bool, dir) -> void:
	e.alive = false; e.dead_t = 0.0; e.bar.visible = false; e.g.visible = true
	e.fall_dir = -1.0
	if dir != null: e.fall_dir = 1.0 if sin(e.yaw) * dir.x + cos(e.yaw) * dir.z > 0.0 else -1.0
	list.erase(e); dying.push_back(e)
	Snd.play("thud", 1.0, e.pos)
	if e.boss: Snd.play("boom", 0.6, e.pos)
	if on_kill.is_valid(): on_kill.call(e, weak)

func splash(c: Vector3, radius: float, dmg: float, skip = null) -> void:
	for e in list.duplicate():
		if e == skip: continue
		var d := Vector3(e.pos.x - c.x, e.pos.y + 1.0 - c.y, e.pos.z - c.z).length()
		if d > radius + e.R: continue
		var mid := Vector3(e.pos.x, e.pos.y + e.H * 0.6, e.pos.z)
		if not Phys.line_of_sight(c, mid): continue
		var k := 1.0 - minf(1.0, d / (radius + e.R))
		damage(e, dmg * (0.35 + 0.65 * k), mid, Vector3((e.pos.x - c.x) / maxf(d, 0.001), 0, (e.pos.z - c.z) / maxf(d, 0.001)), false)

func blow_vest(_e, _dir: Vector3) -> void:
	pass

func clear() -> void:
	for e in list: e.g.queue_free(); e.bar.queue_free()
	for e in dying: e.g.queue_free(); e.bar.queue_free()
	list.clear(); dying.clear()

# ---------------- the people's AI ----------------
func stop_dist(e: Foe) -> float:
	return e.foot.z1 + Player.R + KEEP_PAD

func _turn_toward(e: Foe, yaw: float, rate: float, dt: float) -> void:
	var d := yaw - e.yaw; d = atan2(sin(d), cos(d)); e.yaw += clampf(d, -rate * dt, rate * dt)

func muzzle_of(e: Foe) -> Vector3:
	var cy := cos(e.yaw); var sy := sin(e.yaw); var m := e.muzzle
	return Vector3(e.pos.x + (m.x * cy + m.z * sy) * e.scale, e.pos.y + m.y * e.scale, e.pos.z + (-m.x * sy + m.z * cy) * e.scale)

func _ground_move(e: Foe, vx: float, vz: float, dt: float) -> bool:
	var res := Phys.move_xz(e.pos, vx * dt, vz * dt, e.R, e.H, 0.45); e.pos = res[0]
	var gy := Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R)
	if e.pos.y > gy: e.vy -= 18.0 * dt; e.pos.y = maxf(gy, e.pos.y + e.vy * dt)
	else: e.pos.y = gy; e.vy = 0.0
	e.pos.x = clampf(e.pos.x, -Phys.HALF + e.R, Phys.HALF - e.R); e.pos.z = clampf(e.pos.z, -Phys.HALF + e.R, Phys.HALF - e.R)
	return res[1]

## a man with a pistol: bursts of 1-3 shots (the boss: 4, faster), 9 damage each
func _fight(e: Foe, dt: float, dist: float) -> bool:
	e.fire_t -= dt
	const G := [1, 3, 0.32, 9.0, 1.1, 2.3]
	if e.burst > 0:
		e.burst_t -= dt
		if e.burst_t <= 0.0:
			e.burst -= 1; e.burst_t = G[2] * (0.62 if e.boss else 1.0)
			var mz := muzzle_of(e)
			var aim := Vector3(player.pos.x + player.vel.x * dist / 150.0, player.pos.y + 1.25, player.pos.z + player.vel.z * dist / 150.0)
			proj.bullet(mz, aim, 80.0, G[3] * e.dmg_mul, 0.35 + dist * 0.028 + player.speed_xz * 0.08 - (0.15 if e.boss else 0.0))
			Snd.play("shot_far", 1.0, mz)
		return true
	if e.fire_t <= 0.0: e.burst = 4 if e.boss else randi_range(G[0], G[1]); e.burst_t = 0.0; e.fire_t = randf_range(G[4], G[5]) * (0.7 if e.boss else 1.0)
	return false

func _animate(e: Foe, sp: float, dt: float, aim: bool) -> void:
	e.walk += dt * sp * 2.6; var s := sin(e.walk) * clampf(sp / 3.0, 0.0, 1.0)
	e.leg_l.rotation.x = s * 0.7; e.leg_r.rotation.x = -s * 0.7
	if aim: e.arm_r.rotation = Vector3(-PI / 2 + 0.05, 0, 0); e.arm_l.rotation = Vector3(-1.25, 0, 0.5)
	else: e.arm_r.rotation = Vector3(-s * 0.8, 0, 0); e.arm_l.rotation = Vector3(s * 0.8, 0, 0)
	e.flinch = maxf(0.0, e.flinch - dt * 5.0); e.upper.rotation.x = -e.flinch * 0.25

## nobody walks into you: your body, and the camera with it, stays outside every enemy's footprint
func _keep_out(e: Foe) -> void:
	var p := player.pos
	if p.y > e.pos.y + e.H * 0.92 or e.pos.y > p.y + Player.HEIGHT: return
	var dx := p.x - e.pos.x; var dz := p.z - e.pos.z; var rr := e.foot_r + Player.R + KEEP_PAD
	if dx * dx + dz * dz > rr * rr: return
	var c := cos(e.yaw); var s := sin(e.yaw); var r := Player.R + KEEP_PAD; var F := e.foot
	var lx := dx * c - dz * s; var lz := dx * s + dz * c   # you, in the enemy's frame
	var pl: float = lx - (F.x0 - r); var pr: float = F.x1 + r - lx; var pb: float = lz - (F.z0 - r); var pf: float = F.z1 + r - lz
	if pl <= 0.0 or pr <= 0.0 or pb <= 0.0 or pf <= 0.0: return
	var m := minf(minf(pl, pr), minf(pb, pf)); var ox := 0.0; var oz := 0.0
	if m == pf: oz = pf
	elif m == pb: oz = -pb
	elif m == pl: ox = -pl
	else: ox = pr
	var wx := ox * c + oz * s; var wz := -ox * s + oz * c   # the way out for you, in world space
	var k := e.mass / (e.mass + 1.0); var before := p
	player.pos = Phys.move_xz(p, wx * k, wz * k, Player.R, Player.HEIGHT, 0.0)[0]
	var moved := player.pos - before
	# whatever you could not give (a wall behind you), the enemy gives
	e.pos = Phys.move_xz(e.pos, moved.x - wx, moved.z - wz, e.R, e.H, 0.0)[0]

func update(dt: float, _time: float) -> void:
	var eye_cam := cam.global_position if cam else Vector3(player.pos.x, player.pos.y + Player.EYE, player.pos.z)
	var vis := VIS_R * (0.75 if DisplayServer.is_touchscreen_available() else 1.0)
	for e in list:
		if not e.alive: continue
		e.lod -= dt
		if e.lod <= 0.0:
			e.lod = 0.3 + randf() * 0.2; e.dist = Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z).length()
			e.g.visible = e.dist < vis * (1.6 if e.boss else 1.0); e.awake = e.alert or e.dist < ACT_R
			if not e.g.visible: e.bar.visible = false
		if not e.awake: continue
		var eye := Vector3(e.pos.x, e.pos.y + 1.65 * e.scale, e.pos.z)
		var to := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var dist := maxf(to.length(), 0.001)
		e.los_t -= dt
		if e.los_t <= 0.0: e.los_t = 0.2 + randf() * 0.1; e.los = dist < 70.0 and Phys.line_of_sight(eye, eye_cam)
		e.no_los = 0.0 if e.los else e.no_los + dt
		var face_yaw := atan2(to.x, to.y); var mvx := 0.0; var mvz := 0.0
		if not e.alert:
			if (e.los and dist < 30.0) or dist < 7.0 or (e.boss and dist < 24.0):
				alarm(e)
				for o in list:
					if not o.alert and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 15.0: alarm(o)
			else:
				if e.idle_t <= 0.0 and not e.has_idle_yaw: e.idle_t = randf_range(2, 6)
				e.idle_t -= dt
				if e.idle_t <= 0.0: e.idle_t = randf_range(3, 7); e.idle_yaw = e.yaw + randf_range(-1.3, 1.3); e.has_idle_yaw = true
				_turn_toward(e, e.idle_yaw if e.has_idle_yaw else e.yaw, 1.2, dt); _animate(e, 0.0, dt, false)
				e.g.rotation.y = e.yaw
				continue
		if e.state == "move":
			var fd := Phys.flow_dir(e.pos.x, e.pos.z)
			if fd != Vector2.ZERO: mvx = fd.x * e.speed; mvz = fd.y * e.speed
			else: mvx = to.x / dist * e.speed; mvz = to.y / dist * e.speed
			_turn_toward(e, face_yaw if (e.los and dist < 34.0) else atan2(mvx, mvz), 6.0, dt)
			if e.los and dist < e.K.range * (1.2 if e.boss else 1.0): e.state = "engage"; e.react = randf_range(0.45, 0.9) * (1.0 - e.diff * 0.35)
		else:
			e.strafe_t -= dt
			if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = randf_range(0.9, 2.4)
			var fx := to.x / dist; var fz := to.y / dist
			var fwd := 1.0 if dist > e.K.far else (-0.8 if dist < e.K.near else 0.0)
			mvx = (fx * fwd - fz * e.strafe * 0.6) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * 0.6) * e.speed * 0.55
			_turn_toward(e, face_yaw, 7.0, dt)
			e.react -= dt
			if e.no_los > 1.6 or dist > e.K.range + 6.0: e.state = "move"
			if e.react <= 0.0 and e.los and _fight(e, dt, dist): mvx *= 0.4; mvz *= 0.4
		e.vel *= exp(-dt * 6.0)
		var blocked := _ground_move(e, mvx + e.vel.x, mvz + e.vel.z, dt)
		if blocked and e.state == "engage": e.strafe *= -1.0
		_animate(e, sqrt(mvx * mvx + mvz * mvz), dt, e.state == "engage")
		e.g.position = e.pos; e.g.rotation.y = e.yaw
		if e.hp < e.max_hp:
			e.bar.visible = e.g.visible; e.bar.position = Vector3(e.pos.x, e.pos.y + e.H + 0.4 * e.scale, e.pos.z)
			var f := clampf(e.hp / e.max_hp, 0.0, 1.0); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1.0 - f)
	# bodies do not stand inside each other
	for i in list.size():
		var a := list[i]
		for j in range(i + 1, list.size()):
			var b := list[j]
			if not a.awake and not b.awake: continue
			var dx := b.pos.x - a.pos.x; var dz := b.pos.z - a.pos.z
			if absf(dx) > 5.0 or absf(dz) > 5.0: continue
			var d := sqrt(dx * dx + dz * dz); var m := a.R + b.R + 0.1
			if d < m and d > 0.001:
				var push := (m - d) * 0.5
				a.pos = Phys.move_xz(a.pos, -dx / d * push, -dz / d * push, a.R, a.H, 0.0)[0]; b.pos = Phys.move_xz(b.pos, dx / d * push, dz / d * push, b.R, b.H, 0.0)[0]
	for e in list:
		if e.alive and e.awake: _keep_out(e)
	# the fallen tip over, lie a while, then sink away
	for i in range(dying.size() - 1, -1, -1):
		var e := dying[i]; e.dead_t += dt
		var t := minf(1.0, e.dead_t / 0.5); var ease := t * t * (3.0 - 2.0 * t)
		e.g.rotation = Vector3(e.fall_dir * ease * 1.45, e.yaw, 0)
		if e.dead_t > 2.6: e.pos.y -= dt * 0.6; e.g.position = e.pos
		if e.dead_t > 3.4: e.g.queue_free(); e.bar.queue_free(); dying.remove_at(i)
