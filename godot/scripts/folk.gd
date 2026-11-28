class_name Folk
extends RefCounted
## The peoples of stage 6, a world with a hero in it (you) and four peoples, each holding one of its places: the elves 6-1,
## the dwarves 6-2, the orcs 6-3, the demons 6-4. Here they are built, moved and fought; so far the elves:
##   석궁병 (ranger)    a repeating crossbow from behind cover, three bolts at a time; out of sight, a bolt glanced off a
##                     silverwood's mirror bark round the corner (its way shown a moment before it flies)
##   바람검사 (blade)   lies in wait, then comes in dashes from side to side, leaps what is in the way, cuts and springs back
##   저격수 (sniper)    a longbow up in the boughs: a line of light on you while it draws, then one hard arrow
##   비전술사 (mage)    a slow ball of light that follows you and bursts; steps away through the air when you come close
##   대마법사 (archmage) the tower's master, on the observatory at its top (see _archmage)
## They stand where their place puts them (ElfWood.posts) and fight from there: nobody here walks the whole map after you.

const KINDS := {
	"elf_ranger": {"race": "elf", "name": "엘프 석궁병", "hp": 130, "speed": 3.8, "r": 0.34, "h": 1.85, "money": 1200, "sight": 46.0},
	"elf_blade": {"race": "elf", "name": "엘프 바람검사", "hp": 150, "speed": 5.6, "r": 0.34, "h": 1.85, "money": 1400, "sight": 30.0},
	"elf_sniper": {"race": "elf", "name": "엘프 저격수", "hp": 110, "speed": 3.0, "r": 0.34, "h": 1.85, "money": 1600, "sight": 70.0},
	"elf_mage": {"race": "elf", "name": "엘프 비전술사", "hp": 170, "speed": 3.0, "r": 0.34, "h": 1.85, "money": 1800, "sight": 50.0},
	"archmage": {"race": "elf", "name": "대마법사", "hp": 6500, "speed": 3.2, "r": 0.42, "h": 2.15, "money": 2000, "sight": 70.0},
	# 6-B's demons (Hellfolk): r and h at their body's own size (each kind is drawn at its own: Hellfolk.LOOK)
	"dm_imp": {"race": "demon", "name": "흑요석 임프", "hp": 100, "speed": 5.5, "r": 0.5, "h": 2.1, "money": 1200, "sight": 36.0},
	"dm_guard": {"race": "demon", "name": "악마 경비병", "hp": 300, "speed": 4.2, "r": 0.4, "h": 2.1, "money": 1600, "sight": 34.0},
	"dm_adept": {"race": "demon", "name": "혈월 주술사", "hp": 200, "speed": 3.4, "r": 0.38, "h": 2.1, "money": 1800, "sight": 40.0},
	"dm_sniper": {"race": "demon", "name": "유황 저격병", "hp": 160, "speed": 3.0, "r": 0.38, "h": 2.1, "money": 2000, "sight": 46.0},
	"dm_warden": {"race": "demon", "name": "사슬 감시자", "hp": 1100, "speed": 3.8, "r": 0.42, "h": 2.1, "money": 3000, "sight": 36.0},
	"inquisitor": {"race": "demon", "name": "심연의 고문관", "hp": 8000, "speed": 3.4, "r": 0.42, "h": 2.1, "money": 2000, "sight": 70.0},
}
const BOLT := {"speed": 54.0, "dmg": 11.0}; const TRICK := {"speed": 52.0, "dmg": 22.0, "warn": 0.55}
const ARROW := {"speed": 105.0, "dmg": 70.0, "draw": 1.7, "rest": 3.2}
const ORB := {"speed": 13.0, "dmg": 55.0, "turn": 1.4, "splash": 3.2, "life": 5.5}
const CUT := {"dmg": 40.0, "reach": 2.3}
const MAX_SHOTS := 48

var en: Enemies; var player: Player; var game; var world: World; var fx: Fx; var proj: Proj
var wood: ElfWood = null     # 6-1's own things: mirror trunks, ferns and mist to hide in, the amplifying circle
var hell := Hellfolk.new()   # 6-B's demons (their minds; their shots fly here)
var altar: Caldera = null:   # 6-B's own things: the ash to hide in, the briars that feed them, the lava
	set(v): altar = v; hell.altar = v
var shots: Array = []        # what is in the air: {kind, pos, vel, dmg, life, n, r, splash, turn, node, amp}
var lines: Array = []        # ways shown before a shot: {a, b, life, node}
var runes: Array = []        # circles on the floor about to burst: {at, r, t, dmg, node}
var root: Node3D = null
var _mats := {}; var _box: BoxMesh; var _orb: SphereMesh; var _disc: MeshInstance3D
var dealt := {}              # what each way of hurting you has cost you this stage: {"bolt": hp, "cut": hp, ...} (the checks read it)
var sent := {}               # ...and how many of each were sent your way

func _init() -> void: hell.fk = self

func clear() -> void:
	hell.clear()
	if root != null and is_instance_valid(root): root.queue_free()   # (what was in the air, the lines and the runes go with it)
	shots.clear(); lines.clear(); runes.clear(); root = null; boss = null; beam_on = false; dealt.clear(); sent.clear(); _later.clear(); _beam_nodes.clear()

func _hurt(kind: String, dmg: float, from: Vector3, zone := "body") -> void:
	var before := player.hp; player.hurt(dmg, from, zone); dealt[kind] = float(dealt.get(kind, 0.0)) + (before - player.hp)

func _root() -> Node3D:
	if root == null or not is_instance_valid(root): root = Node3D.new(); root.name = "FolkShots"; root.set_meta("shadow", false); en.add_child(root)
	return root

func _mat(key: String, col: Color, add := true) -> Material:
	if not _mats.has(key):
		var m := Gfx.unlit(col, false); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED; _mats[key] = Gfx.see_through(m)
	return _mats[key]

# ---------------- how they look ----------------
const SKIN := "f1e3d0"; const HAIR := ["e4e9ef", "ecd893", "c9d6c2"]
func _hpart(o: Vector3, r: float, mult := 1.0, weak := false) -> Dictionary: return {"o": o, "r": r, "mult": mult, "weak": weak, "bomb": false}

func build(e: Enemies.Foe, type: String, opts: Dictionary) -> void:
	if str(KINDS[type].get("race", "")) == "demon": hell.build(e, type, opts); return
	e.folk = true; e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; en.add_child(e.g)
	var v := int(opts.get("v", 0)); var hair: String = HAIR[v % 3]
	var coat := "2f6b4f"; var trim := "6b4a2c"; var legc := "3b3226"; var big := type == "archmage"
	match type:
		"elf_blade": coat = "1f7a78"; trim = "c9d3dc"; legc = "24403f"
		"elf_sniper": coat = "2a4038"; trim = "3d5a4c"; legc = "26302b"
		"elf_mage": coat = "5b3f9e"; trim = "e0b84a"; legc = "3a2a66"
		"archmage": coat = "dfe8ff"; trim = "e0b84a"; legc = "8fa0d8"; hair = "f4f6fa"
	var robe := type == "elf_mage" or big
	var leg := [[0.15, 0.9, 0.17, 0, -0.45, 0, legc], [0.16, 0.1, 0.27, 0, -0.87, 0.05, trim]]
	if robe: leg = [[0.2, 0.92, 0.3, 0, -0.46, 0, coat], [0.21, 0.06, 0.31, 0, -0.9, 0, trim]]
	e.leg_l = en._part(e.g, Vector3(-0.11, 0.92, 0), "fk_leg" + type, leg); e.leg_r = en._part(e.g, Vector3(0.11, 0.92, 0), "fk_leg" + type, leg)
	# the body: a slim coat, a belt, the head with its long hair and its pointed ears
	var up := [[0.4, 0.62, 0.24, 0, 0.36, 0, coat], [0.42, 0.07, 0.26, 0, 0.1, 0, trim], [0.2, 0.24, 0.22, 0, 0.8, 0.01, SKIN],
		[0.23, 0.1, 0.25, 0, 0.93, -0.01, hair], [0.24, 0.42, 0.06, 0, 0.68, -0.13, hair],
		[0.035, 0.2, 0.07, -0.125, 0.88, -0.03, SKIN, [0.55, 0, 0.42]], [0.035, 0.2, 0.07, 0.125, 0.88, -0.03, SKIN, [0.55, 0, -0.42]]]   # (the ears: long, swept up and back)
	if type == "elf_sniper": up.append_array([[0.3, 0.2, 0.3, 0, 0.9, -0.03, coat], [0.46, 0.5, 0.05, 0, 0.36, -0.15, trim]])   # a hood and a cloak
	if type == "elf_blade": up.append_array([[0.44, 0.2, 0.28, 0, 0.56, 0, trim], [0.12, 0.1, 0.3, -0.26, 0.64, 0, trim], [0.12, 0.1, 0.3, 0.26, 0.64, 0, trim]])   # a breastplate, shoulder plates
	if robe: up.append_array([[0.5, 0.56, 0.05, 0, 0.3, -0.15, trim], [0.1, 0.5, 0.26, 0, 0.36, 0.01, trim]])
	if big: up.append_array([[0.3, 0.07, 0.3, 0, 1.0, 0, trim], [0.2, 0.3, 0.2, 0, 1.18, 0, coat], [0.1, 0.22, 0.1, 0, 1.42, 0, coat], [0.16, 0.42, 0.1, 0, 0.5, 0.13, hair]])   # a tall hat, a long beard
	e.upper = en._part(e.g, Vector3(0, 0.92, 0), "fk_up%s%d" % [type, v % 3], up)
	var arm := [[0.11, 0.62, 0.12, 0, -0.29, 0, coat], [0.09, 0.1, 0.1, 0, -0.62, 0, SKIN]]
	var left := arm.duplicate(); var right := arm.duplicate()
	match type:
		"elf_ranger": right.append_array([[0.07, 0.07, 0.62, 0, -0.66, 0.26, "5a3d22"], [0.56, 0.05, 0.05, 0, -0.66, 0.5, "c9d3dc"], [0.03, 0.03, 0.5, 0, -0.62, 0.3, "8ff7ea"]])   # the crossbow: stock, bow, the bolt in it
		"elf_blade": right.append_array([[0.035, 0.9, 0.06, 0, -1.12, 0.03, "dff7ff"]]); left.append_array([[0.035, 0.9, 0.06, 0, -1.12, 0.03, "dff7ff"]])
		"elf_sniper": left.append_array([[0.04, 1.7, 0.05, 0, -0.62, 0.12, "5a3d22"], [0.015, 1.6, 0.015, 0, -0.62, 0.0, "e8e8e8"]])   # the longbow and its string
		"elf_mage": right.append_array([[0.05, 1.5, 0.05, 0, -0.5, 0.05, "6b4a2c"], [0.14, 0.14, 0.14, 0, 0.3, 0.05, "b892ff"]])
		"archmage": right.append_array([[0.06, 1.9, 0.06, 0, -0.5, 0.05, "e0b84a"], [0.2, 0.2, 0.2, 0, 0.5, 0.05, "8ff7ea"], [0.3, 0.05, 0.3, 0, 0.36, 0.05, "e0b84a"]])
	e.arm_l = en._part(e.upper, Vector3(-0.27, 0.6, 0), "fk_al" + type, left); e.arm_r = en._part(e.upper, Vector3(0.27, 0.6, 0), "fk_ar" + type, right)
	e.parts = [_hpart(Vector3(0, 1.72, 0.01), 0.15, 1.0, true), _hpart(Vector3(0, 1.3, 0), 0.3), _hpart(Vector3(0, 0.95, 0), 0.22, 0.9), _hpart(Vector3(0, 0.48, 0), 0.24, 0.7)]
	e.muzzle = Vector3(0.27, 1.38, 0.75); e.eye_h = 1.65
	e.bar = Node3D.new(); e.bar.visible = false; en.add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = en._bar_mesh; e.fill.material_override = en._bar_fill; e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)
	var P: Dictionary = opts.get("post", {})
	e.k = {"post": Vector3(float(P.get("x", 0.0)), float(P.get("y", 0.0)), float(P.get("z", 0.0))), "perch": bool(P.get("perch", false)), "cd": randf_range(0.6, 1.6), "burst": 0, "burst_t": 0.0,
		"side": 1.0 if randf() < 0.5 else -1.0, "side_t": randf_range(1.0, 2.5), "trick": randf_range(2.0, 5.0), "aim": 0.0, "blink": randf_range(3.0, 6.0), "strike": 0.0, "hit": false,
		"dash": randf_range(0.4, 1.2), "zig": 1.0, "zig_t": 0.5, "leap": randf_range(2.0, 4.0), "back": 0.0, "wait": type == "elf_blade", "phase": 1, "act": 2.5, "port": 4.0, "seen_t": 0.0,
		"fly": 0.0, "fv": Vector2.ZERO}

# ---------------- seeing ----------------
## whether an elf sees you now: in its sight, nothing in the way, and not while you are in the ferns or the mist with it far off
func sees(e: Enemies.Foe, dist: float) -> bool:
	if not e.los or dist > float(e.T.sight) * (1.3 if e.alert else 1.0): return false
	if wood != null and wood.hides(player, dist): return false
	if altar != null and altar.hides(player, dist): return false
	return true

func _wake(e: Enemies.Foe) -> void:
	en.alarm(e)
	for o in en.list:
		if o != e and o.alive and not o.alert and o.folk and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 15.0 and absf(o.pos.y - e.pos.y) < 6.0: en.alarm(o)

func on_hurt(e: Enemies.Foe, _dir: Vector3) -> void:
	if e.k.has("dm"): hell.on_hurt(e, _dir); return
	e.k.wait = false; e.k.seen_t = 2.0
	if e.type == "elf_mage" and float(e.k.blink) <= 2.5: e.k.blink = 0.0   # (struck: away, if the step is ready soon)

# ---------------- their turn ----------------
func update(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	if e.k.has("dm"): hell.update(e, dt, dist, to, face_yaw); return
	var k := e.k; var seen := sees(e, dist)
	k.seen_t = maxf(0.0, float(k.seen_t) - dt)
	if seen: k.seen_t = 1.2
	if bool(k.wait):   # lying in wait: gunfire far off does not bring it out; you do, close by and in its sight (or on top of it)
		if (seen and dist < 13.0) or dist < 4.5: k.wait = false; _wake(e)
		else: _idle(e, dt); return
	if not e.alert:
		if (seen and dist < float(e.T.sight)) or dist < 6.5: _wake(e)
		else: _idle(e, dt); return
	match e.type:
		"elf_ranger": _ranger(e, dt, dist, to, face_yaw, seen)
		"elf_blade": _blade(e, dt, dist, to, face_yaw, seen)
		"elf_sniper": _sniper(e, dt, dist, face_yaw, seen)
		"elf_mage": _mage(e, dt, dist, to, face_yaw, seen)
		"archmage": _archmage(e, dt, dist, to, face_yaw, seen)

func _idle(e: Enemies.Foe, dt: float) -> void:
	var k := e.k
	if bool(k.wait): _pose(e, 0.0, dt, "crouch"); en._ground_move(e, 0.0, 0.0, dt); return   # (lying in wait)
	if e.idle_t <= 0.0: e.idle_t = randf_range(2.5, 6.0); e.idle_yaw = e.yaw + randf_range(-0.9, 0.9); e.has_idle_yaw = true
	e.idle_t -= dt
	if e.has_idle_yaw: en._turn_toward(e, e.idle_yaw, 1.0, dt)
	_pose(e, 0.0, dt, "rest"); en._ground_move(e, 0.0, 0.0, dt)

## arms and legs: walking, at rest, the crossbow or the staff up, the bow drawn, the blades out, crouched
func _pose(e: Enemies.Foe, sp: float, dt: float, how: String) -> void:
	if e.is_far: e.walk += dt * sp * 2.6; e.flinch = maxf(0.0, e.flinch - dt * 5.0); return   # (far off it is one mesh: nothing to pose)
	e.walk += dt * sp * 2.6; var s := sin(e.walk) * clampf(sp / 3.0, 0.0, 1.0)
	e.leg_l.rotation.x = s * 0.7; e.leg_r.rotation.x = -s * 0.7
	e.flinch = maxf(0.0, e.flinch - dt * 5.0); var lean := -e.flinch * 0.25
	match how:
		"aim": e.arm_r.rotation = Vector3(-PI / 2 + 0.06, 0, 0); e.arm_l.rotation = Vector3(-1.2, 0, 0.45)
		"draw": e.arm_l.rotation = Vector3(-PI / 2, 0, 0.1); e.arm_r.rotation = Vector3(-1.45, 0, -0.5)
		"cast": e.arm_r.rotation = Vector3(-2.3, 0, -0.2); e.arm_l.rotation = Vector3(-1.0, 0, 0.5)
		"blades": e.arm_r.rotation = Vector3(-0.9 - s * 0.3, 0, -0.35); e.arm_l.rotation = Vector3(-0.9 + s * 0.3, 0, 0.35)
		"cut": e.arm_r.rotation = Vector3(-2.2, 0, 0.5); e.arm_l.rotation = Vector3(-0.4, 0, -0.6)
		"crouch": e.arm_r.rotation = Vector3(-0.6, 0, -0.3); e.arm_l.rotation = Vector3(-0.6, 0, 0.3); lean = 0.5
		_: e.arm_r.rotation = Vector3(-s * 0.8, 0, 0); e.arm_l.rotation = Vector3(s * 0.8, 0, 0)
	e.upper.rotation.x = lean
	var want := 0.72 if how == "crouch" else 1.0
	if absf(e.g.scale.y - want * e.scale) > 0.004: e.g.scale.y = lerpf(e.g.scale.y, want * e.scale, 1.0 - exp(-dt * 10.0))

## about its post: a step to one side and back, away from you if you are on top of it; never off a perch
func _hold(e: Enemies.Foe, dt: float, dist: float, to: Vector2, reach := 2.4) -> float:
	var k := e.k
	if bool(k.perch): en._ground_move(e, 0.0, 0.0, dt); return 0.0
	k.side_t = float(k.side_t) - dt
	if float(k.side_t) <= 0.0: k.side = -float(k.side); k.side_t = randf_range(1.2, 2.8)
	var post: Vector3 = k.post; var f := to / maxf(dist, 0.001); var want := Vector2(post.x, post.z) + Vector2(-f.y, f.x) * float(k.side) * reach
	if dist < 6.0: want -= f * 5.0   # (too close: back)
	var d := want - Vector2(e.pos.x, e.pos.z); var sp := 0.0; var mv := Vector2.ZERO
	if d.length() > 0.35: sp = e.speed * (1.0 if dist < 6.0 else 0.7); mv = d.normalized() * sp
	e.vel *= exp(-dt * 6.0)
	if en._ground_move(e, mv.x + e.vel.x, mv.y + e.vel.z, dt): k.side = -float(k.side)
	return sp

func _ranger(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; en._turn_toward(e, face_yaw, 7.0, dt)
	var sp := _hold(e, dt, dist, to); _pose(e, sp, dt, "aim")
	k.cd = float(k.cd) - dt; k.trick = float(k.trick) - dt
	if int(k.burst) > 0:   # the rest of three
		k.burst_t = float(k.burst_t) - dt
		if float(k.burst_t) <= 0.0: k.burst = int(k.burst) - 1; k.burst_t = 0.14; _bolt(e, 0.02 + dist * 0.0009)
		return
	if seen and dist < 50.0:
		if float(k.cd) <= 0.0: k.burst = 3; k.burst_t = 0.0; k.cd = randf_range(2.2, 3.2)
	elif not seen and e.alert and dist < 42.0 and float(k.trick) <= 0.0 and wood != null:
		k.trick = randf_range(4.0, 6.5)
		var from := en.muzzle_of(e); var path = wood.glance(from, _chest())
		if path != null: _trick(e, from, path)

func _chest() -> Vector3: return Vector3(player.pos.x, player.pos.y + 1.0, player.pos.z)

func _bolt(e: Enemies.Foe, spread: float) -> void:
	var from := en.muzzle_of(e); var d := (_chest() - from).normalized()
	d = (d + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * spread).normalized()
	shoot("bolt", from, d * float(BOLT.speed), float(BOLT.dmg) * e.dmg_mul); Snd.play("elf_bolt", 1.0, from)

## a bolt off a silverwood's bark: its way shown first (the way in, the way out), then the bolt along it
func _trick(e: Enemies.Foe, from: Vector3, path: Array) -> void:
	var q: Vector3 = path[0]; var tgt: Vector3 = path[1]
	line(from, q, float(TRICK.warn) + 0.25, Color(0.6, 1.0, 0.95, 0.75)); line(q, tgt, float(TRICK.warn) + 0.25, Color(0.6, 1.0, 0.95, 0.75))
	var dmg := float(TRICK.dmg) * e.dmg_mul
	_later.push_back({"t": float(TRICK.warn), "f": func() -> void:
		if e.alive: shoot("bolt", from, (q - from).normalized() * float(TRICK.speed), dmg, 1, "trick"); Snd.play("elf_bolt", 1.0, from)})

const STEP_UP := {"min": 2.2, "max": 12.0, "reach": 14.0, "over": 1.3}   # the wind step: how far up it carries a blade dancer, from how far off, how far over your level
func _blade(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, _seen: bool) -> void:
	var k := e.k; var f := to / maxf(dist, 0.001); var dy := absf(player.pos.y - e.pos.y)
	en._turn_toward(e, face_yaw, 10.0, dt); e.vel *= exp(-dt * 5.0)
	if float(k.fly) > 0.0:   # in the air on the wind step: where it was sent, until it comes down
		k.fly = float(k.fly) - dt; var fv: Vector2 = k.fv
		en._ground_move(e, fv.x, fv.y, dt); _pose(e, 6.0, dt, "blades")
		if e.vy <= 0.0 and e.pos.y <= Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.02: k.fly = 0.0
		if fx != null and randf() < dt * 24.0: fx.glow(Vector3(e.pos.x, e.pos.y + 0.3, e.pos.z), Vector3.ZERO, 0.3, 0.3, 0.05, Color(0.75, 1.0, 0.95, 0.5), 0.0, 1.0)
		return
	if float(k.strike) > 0.0:   # the cut: it lands a moment in
		k.strike = float(k.strike) - dt
		if not bool(k.hit) and float(k.strike) <= 0.42:
			k.hit = true
			if dist < float(CUT.reach) and dy < 1.7: _hurt("cut", float(CUT.dmg) * e.dmg_mul, e.pos, "body"); Snd.play("elf_cut", 1.0, e.pos)
		if float(k.strike) <= 0.0: k.back = 0.55; k.zig = -float(k.zig)
		en._ground_move(e, e.vel.x, e.vel.z, dt); _pose(e, 0.0, dt, "cut"); return
	if float(k.back) > 0.0:   # ...and springs back, to one side
		k.back = float(k.back) - dt
		var away := (-f + Vector2(-f.y, f.x) * float(k.zig) * 0.8).normalized() * 7.5
		en._ground_move(e, away.x, away.y, dt); _pose(e, 7.0, dt, "blades"); return
	if dist < 1.9 and dy < 1.7: k.strike = 0.6; k.hit = false; Snd.play("elf_swish", 1.0, e.pos); sent["cut"] = int(sent.get("cut", 0)) + 1; return
	# coming in: from side to side, in dashes; over what stands in the way; a leap from a few metres out
	k.zig_t = float(k.zig_t) - dt; k.dash = float(k.dash) - dt; k.leap = float(k.leap) - dt
	if float(k.zig_t) <= 0.0: k.zig = -float(k.zig); k.zig_t = randf_range(0.45, 0.8)
	var dashing := float(k.dash) < 0.0
	if float(k.dash) < -0.45: k.dash = randf_range(0.9, 1.5)
	var sp := 9.2 if dashing else e.speed
	var head := (f + Vector2(-f.y, f.x) * float(k.zig) * (0.55 if dist > 4.0 else 0.0)).normalized() * sp
	var grounded := e.pos.y <= Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.02
	var up := player.pos.y - e.pos.y
	if grounded and float(k.leap) <= 0.0 and up > float(STEP_UP.min) and up < float(STEP_UP.max) and dist < float(STEP_UP.reach) and dist > 1.0:
		# the wind step up to where you stand (a deck in the boughs, the tower's gallery): one great leap, the wind under it
		var h := up + float(STEP_UP.over); var vy := sqrt(2.0 * 18.0 * h); var t_all := vy / 18.0 + sqrt(2.0 * float(STEP_UP.over) / 18.0)
		k.leap = randf_range(4.0, 6.0); e.vy = vy; e.pos.y += 0.06; k.fly = t_all + 0.4; k.fv = (to / t_all).limit_length(14.0); _wind(e); return
	if grounded and float(k.leap) <= 0.0 and dist > 5.0 and dist < 10.0 and dy < 3.0:
		k.leap = randf_range(3.5, 5.5); e.vy = 7.2; e.pos.y += 0.06; e.vel.x = f.x * 6.5; e.vel.z = f.y * 6.5; _wind(e)   # (off the ground a hair, or the ground takes the leap back)
	var blocked := en._ground_move(e, head.x + e.vel.x, head.y + e.vel.z, dt)
	if blocked and grounded: e.vy = 8.6; e.pos.y += 0.06; _wind(e)   # over what stands in the way
	elif blocked and e.vy < 1.0 and e.vy > -4.0 and not bool(k.get("twice", false)): e.vy = 6.5; k.twice = true   # ...and once more in the air
	if grounded: k.twice = false
	if dashing and fx != null and randf() < dt * 30.0: fx.glow(Vector3(e.pos.x, e.pos.y + 0.9, e.pos.z), Vector3.ZERO, 0.25, 0.3, 0.05, Color(0.7, 1.0, 0.95, 0.5), 0.0, 1.0)
	_pose(e, sp, dt, "blades")

func _wind(e: Enemies.Foe) -> void:
	Snd.play("elf_wind", 0.8, e.pos)
	if fx != null:
		for i in 4: fx.glow(Vector3(e.pos.x + randf_range(-0.3, 0.3), e.pos.y + 0.2, e.pos.z + randf_range(-0.3, 0.3)), Vector3(0, randf_range(1.0, 2.5), 0), 0.4, 0.35, 0.05, Color(0.75, 1.0, 0.95, 0.6), 0.0, 1.0)

func _sniper(e: Enemies.Foe, dt: float, dist: float, face_yaw: float, seen: bool) -> void:
	var k := e.k; en._turn_toward(e, face_yaw, 5.0, dt); en._ground_move(e, 0.0, 0.0, dt)
	k.cd = float(k.cd) - dt
	if seen and float(k.cd) <= 0.0:
		k.aim = float(k.aim) + dt; var f := clampf(float(k.aim) / float(ARROW.draw), 0.0, 1.0)
		var from := en.muzzle_of(e) + Vector3(0, 0.15, 0); _aim_line(e, from, _chest(), f)
		if float(k.aim) >= float(ARROW.draw):
			k.aim = 0.0; k.cd = float(ARROW.rest) if dist > 9.0 else 1.3; _aim_off(e)
			shoot("arrow", from, (_chest() - from).normalized() * float(ARROW.speed), float(ARROW.dmg if dist > 9.0 else 40.0) * e.dmg_mul); Snd.play("elf_arrow", 1.0, from)
		_pose(e, 0.0, dt, "draw")
	else:
		if float(k.aim) > 0.0: k.aim = maxf(0.0, float(k.aim) - dt * 2.0)
		if float(k.aim) <= 0.0: _aim_off(e)
		_pose(e, 0.0, dt, "rest")

## the line of light a drawn bow lays on you: thin and green, whiter and steadier as the arrow is about to go
func _aim_line(e: Enemies.Foe, a: Vector3, b: Vector3, f: float) -> void:
	if e.laser == null:
		e.laser = MeshInstance3D.new(); e.laser.mesh = _unit_box(); e.laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _root().add_child(e.laser)
	e.laser.material_override = _mat("aim1" if f > 0.75 else "aim0", Color(1.0, 1.0, 0.95, 0.9) if f > 0.75 else Color(0.45, 1.0, 0.85, 0.5))
	_stretch(e.laser, a, b, 0.02 + 0.03 * f); e.laser.visible = true
func _aim_off(e: Enemies.Foe) -> void:
	if e.laser != null and is_instance_valid(e.laser): e.laser.visible = false

func _mage(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; en._turn_toward(e, face_yaw, 6.0, dt)
	k.cd = float(k.cd) - dt; k.blink = float(k.blink) - dt
	if float(k.blink) <= 0.0 and dist < 8.5 and not bool(k.perch): k.blink = randf_range(6.0, 8.0); _blink(e, to / maxf(dist, 0.001)); return
	var sp := _hold(e, dt, dist, to, 1.6)
	if seen and dist < 52.0 and float(k.cd) <= 0.0:
		k.cd = randf_range(3.8, 4.8); var from := en.muzzle_of(e) + Vector3(0, 0.6, 0)
		shoot("orb", from, (_chest() - from).normalized() * float(ORB.speed), float(ORB.dmg) * e.dmg_mul); Snd.play("elf_orb", 1.0, from)
	_pose(e, sp, dt, "cast" if float(k.cd) > 3.2 else "rest")

## a step through the air: gone here in a flash, there a few metres off (back towards its post if it can)
func _blink(e: Enemies.Foe, f: Vector2) -> void:
	var post: Vector3 = e.k.post
	for i in 10:
		var a := randf() * TAU; var r := randf_range(0.0, 5.0); var x := post.x + cos(a) * r; var z := post.z + sin(a) * r
		if i > 5: x = e.pos.x - f.x * 9.0 + cos(a) * 3.0; z = e.pos.z - f.y * 9.0 + sin(a) * 3.0
		var gy := Phys.ground_at(x, e.pos.y + 1.0, z, e.R)
		if absf(gy - e.pos.y) > 1.2 or Phys.collide_at(x, gy + 0.05, z, e.R, e.H) != null or Vector2(x - player.pos.x, z - player.pos.z).length() < 8.0: continue
		_flash(Vector3(e.pos.x, e.pos.y + 1.0, e.pos.z)); e.pos = Vector3(x, gy, z); e.vel = Vector3.ZERO; _flash(Vector3(x, gy + 1.0, z)); Snd.play("elf_blink", 1.0, e.pos); return

func _flash(at: Vector3) -> void:
	if fx == null: return
	for i in 8: fx.glow(at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.8, 0.8), randf_range(-0.3, 0.3)), Vector3(randf_range(-1.5, 1.5), randf_range(0.2, 2.0), randf_range(-1.5, 1.5)), 0.45, 0.4, 0.04, Color(0.72, 0.57, 1.0, 0.8), 0.0, 2.0)

# ---------------- the Archmage ----------------
## The tower's master, on the observatory under the dome. He steps from place to place round the great sphere and never
## comes to blows. Three parts, by his health:
##   all of it   a fan of five bolts, twice; a rune drawn on the floor under you that bursts a moment later
##   two thirds  the sphere's beam, low over the floor and sweeping round (jump it); once, two blade dancers called in
##   one third   quicker steps, fans of seven, two runes at a time, the beam with two arms
var boss: Enemies.Foe = null; var beam_on := false; var beam_a := 0.0; var beam_t := 0.0; var beam_arms := 1; var _beam_nodes: Array = []; var _beam_hit := 0.0
const BEAM := {"y": 0.55, "len": 10.2, "turn": 0.85, "dmg": 60.0, "every": 0.25, "for": 6.5}
func _archmage(e: Enemies.Foe, dt: float, dist: float, _to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; boss = e
	var f := e.hp / maxf(e.max_hp, 1.0); var ph := 1 if f > 0.66 else (2 if f > 0.33 else 3)
	if ph != int(k.phase):
		k.phase = ph; k.act = 1.2; _flash(Vector3(e.pos.x, e.pos.y + 1.2, e.pos.z)); Snd.play("elf_rune", 1.0, e.pos)
		if ph == 2 and wood != null: wood.summon(2)
		if game != null: game.say_feed("대마법사의 마력이 거세집니다" if ph == 2 else "대마법사가 마지막 힘을 끌어냅니다")
	en._turn_toward(e, face_yaw, 6.0, dt); en._ground_move(e, 0.0, 0.0, dt)
	k.port = float(k.port) - dt; k.act = float(k.act) - dt
	if float(k.port) <= 0.0 and wood != null:
		k.port = 3.0 if ph == 3 else 5.0
		var spot = wood.perch_away(e.pos, player.pos)
		if spot != null: _flash(Vector3(e.pos.x, e.pos.y + 1.2, e.pos.z)); e.pos = spot; e.vel = Vector3.ZERO; _flash(spot + Vector3(0, 1.2, 0)); Snd.play("elf_blink", 1.0, e.pos)
	var near: bool = seen or (dist < 26.0 and absf(player.pos.y - e.pos.y) < 6.0)
	if int(k.burst) > 0:
		k.burst_t = float(k.burst_t) - dt
		if float(k.burst_t) <= 0.0: k.burst = int(k.burst) - 1; k.burst_t = 0.5; _fan(e, 7 if ph == 3 else 5)
	elif near and float(k.act) <= 0.0:
		var pick := randi() % (2 if ph == 1 else 3)
		if pick == 2 and beam_on: pick = 0
		match pick:
			0: k.burst = 2; k.burst_t = 0.0; k.act = 2.6 if ph < 3 else 2.0
			1:
				_rune(player.pos, 3.0, 1.4, 90.0 * e.dmg_mul)
				if ph == 3: _rune(player.pos + Vector3(-sin(player.yaw), 0, -cos(player.yaw)) * 4.0, 3.0, 1.7, 90.0 * e.dmg_mul)
				k.act = 2.2 if ph < 3 else 1.6
			2: beam_on = true; beam_t = float(BEAM["for"]); beam_arms = 2 if ph == 3 else 1; beam_a = atan2(player.pos.z - ElfWood.TC.y, player.pos.x - ElfWood.TC.x) + PI * 0.5; k.act = 3.0; Snd.play("elf_beam", 1.0, e.pos)
	_pose(e, 0.0, dt, "cast" if (int(k.burst) > 0 or float(k.act) > 1.8) else "rest")

func _fan(e: Enemies.Foe, n: int) -> void:
	var from := en.muzzle_of(e) + Vector3(0, 0.5, 0); var d := (_chest() - from).normalized(); var side := d.cross(Vector3.UP).normalized()
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.085
		shoot("bolt", from, (d * cos(a) + side * sin(a)).normalized() * 40.0, 18.0 * e.dmg_mul, 0, "fan")
	Snd.play("elf_bolt", 1.0, from)

## one of them falls (its own way: a demon in embers and ash)
func fell(e: Enemies.Foe) -> void:
	if e.k.has("dm"): hell.fell(e)

func boss_down(e: Enemies.Foe) -> void:
	if e.k.has("dm"): hell.boss_down(e); return
	beam_on = false; _beam_show(false); boss = null
	for r: Dictionary in runes:
		if is_instance_valid(r.node): (r.node as Node3D).queue_free()
	runes.clear(); _flash(Vector3(e.pos.x, e.pos.y + 1.2, e.pos.z))
	if wood != null: wood.still()

## the sphere's beam: an arm of light (or two) from the middle of the observatory, low over its floor, turning
func _beam(dt: float) -> void:
	if not beam_on: return
	beam_t -= dt; beam_a += float(BEAM.turn) * dt; _beam_hit -= dt
	if beam_t <= 0.0 or boss == null or not boss.alive: beam_on = false; _beam_show(false); return
	var c := Vector3(ElfWood.TC.x, ElfWood.T_F3 + float(BEAM.y), ElfWood.TC.y)
	_beam_show(true)
	for i in beam_arms:
		var a := beam_a + i * PI; var tip := c + Vector3(cos(a), 0, sin(a)) * float(BEAM.len)
		_stretch(_beam_nodes[i], c, tip, 0.16)
		# you: on the observatory's floor, within the arm's reach, your feet under it
		var p := Vector2(player.pos.x - c.x, player.pos.z - c.z); var along := p.dot(Vector2(cos(a), sin(a))); var off := absf(p.dot(Vector2(-sin(a), cos(a))))
		if along > 0.5 and along < float(BEAM.len) and off < 0.55 and player.pos.y - ElfWood.T_F3 < float(BEAM.y) + 0.2 and player.pos.y - ElfWood.T_F3 > -0.5 and _beam_hit <= 0.0:
			_beam_hit = float(BEAM.every); _hurt("beam", float(BEAM.dmg), c, "fire")

func _beam_show(on: bool) -> void:
	while _beam_nodes.size() < 2 or not is_instance_valid(_beam_nodes[0]):
		if _beam_nodes.size() >= 2: _beam_nodes.clear()
		var n := MeshInstance3D.new(); n.mesh = _unit_box(); n.material_override = _mat("beam", Color(1.0, 0.85, 0.45, 0.9)); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.visible = false; _root().add_child(n); _beam_nodes.push_back(n)
	for i in 2: (_beam_nodes[i] as Node3D).visible = on and i < beam_arms

## a circle drawn on the floor: it bursts when its time is up
## more: {col (its colour), burn (seconds it sets you alight for), snd (the sound it is drawn with)}
func _rune(at: Vector3, r: float, fuse: float, dmg: float, more := {}) -> void:
	var gy := Phys.ground_at(at.x, at.y + 0.5, at.z, 0.3)
	var n := MeshInstance3D.new(); var m := MeshKit.new(); m.disc(0, 0, 0, 1.0, Color.WHITE, 24, 0.86); m.disc(0, 0, 0, 0.5, Color.WHITE, 5, 0.44)
	var col: Color = more.get("col", Color(1.0, 0.82, 0.35, 0.9))
	n.mesh = m.mesh(); n.material_override = _mat("rune" + col.to_html(), col); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(n); n.position = Vector3(at.x, gy + 0.06, at.z); n.scale = Vector3(r, 1.0, r)
	runes.push_back({"at": Vector3(at.x, gy, at.z), "r": r, "t": fuse, "dmg": dmg, "node": n, "col": col, "burn": float(more.get("burn", 0.0))}); Snd.play(str(more.get("snd", "elf_rune")), 0.7, at); sent["rune"] = int(sent.get("rune", 0)) + 1

# ---------------- what flies ----------------
var _later: Array = []   # things to do in a moment: {t, f}
func _unit_box() -> BoxMesh:
	if _box == null: _box = BoxMesh.new(); _box.size = Vector3.ONE
	return _box

## a thin box laid from a to b
func _stretch(n: Node3D, a: Vector3, b: Vector3, thick: float) -> void:
	var d := b - a; var len := d.length()
	if len < 0.001: n.visible = false; return
	var f := d / len; var up := Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT
	var x := up.cross(f).normalized(); var y := f.cross(x)
	n.global_transform = Transform3D(Basis(x * thick, y * thick, f * len), (a + b) * 0.5)

func line(a: Vector3, b: Vector3, life: float, col: Color) -> void:
	var n := MeshInstance3D.new(); n.mesh = _unit_box(); n.material_override = _mat("line%s" % col.to_html(), col); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(n); _stretch(n, a, b, 0.035); lines.push_back({"a": a, "b": b, "life": life, "node": n})

## src: what it counts as in `dealt` and `sent` (a fan's bolt is a bolt to look at, the Archmage's fan to count)
## (6-B's) more: {grav (it falls), burn (it sets you alight), shove (it throws you back), pull (it drags you to `from`)}
const SHOT_COL := {"bolt": Color(0.75, 1.0, 0.95, 0.95), "arrow": Color(1.0, 0.97, 0.8, 0.95), "fire": Color(1.0, 0.5, 0.12, 0.95), "lance": Color(1.0, 0.3, 0.1, 0.95),
	"spear": Color(1.0, 0.55, 0.15, 0.95), "hook": Color(0.75, 0.72, 0.7, 0.95), "orb": Color(0.72, 0.5, 1.0, 0.95), "ember": Color(1.0, 0.42, 0.1, 0.95)}
func shoot(kind: String, from: Vector3, vel: Vector3, dmg: float, bounces := 0, src := "", more := {}) -> void:
	if shots.size() >= MAX_SHOTS: return
	if src == "": src = kind
	sent[src] = int(sent.get(src, 0)) + 1
	var n := MeshInstance3D.new(); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; var round := kind == "orb" or kind == "ember"
	if round:
		if _orb == null: _orb = SphereMesh.new(); _orb.radius = 0.32; _orb.height = 0.64; _orb.radial_segments = 10; _orb.rings = 5
		n.mesh = _orb; n.material_override = _mat(kind, SHOT_COL[kind])
	else:
		n.mesh = _unit_box(); n.material_override = _mat(kind, SHOT_COL.get(kind, SHOT_COL.arrow))
	_root().add_child(n)
	var s := {"kind": kind, "pos": from, "vel": vel, "dmg": dmg, "life": float(ORB.life) if round else 2.6, "n": bounces, "r": 0.0, "splash": float(ORB.splash) if round else 0.0,
		"turn": float(ORB.turn) if round else 0.0, "node": n, "amp": false, "src": src, "speed": vel.length()}
	if kind == "ember": s.scale = 0.7
	s.merge(more, true)
	shots.push_back(s); _place(s)

func _place(s: Dictionary) -> void:
	var n: MeshInstance3D = s.node; var p: Vector3 = s.pos; var v: Vector3 = s.vel
	if s.kind == "orb" or s.kind == "ember": n.position = p; var k := (1.0 + (0.5 if bool(s.amp) else 0.0)) * float(s.get("scale", 1.0)); n.scale = Vector3.ONE * k
	else:
		var len := 1.5 if s.kind == "arrow" or s.kind == "lance" else (1.3 if s.kind == "spear" else (0.5 if s.kind == "hook" else 1.1))
		_stretch(n, p - v.normalized() * len, p, 0.05 * (1.6 if bool(s.amp) else 1.0))

func _gone(s: Dictionary) -> void:
	if is_instance_valid(s.node): (s.node as Node3D).queue_free()

func _burst(s: Dictionary, at: Vector3) -> void:
	var hot: bool = s.kind == "fire" or s.kind == "lance" or s.kind == "spear" or s.kind == "ember"
	if fx != null: fx.sparks(at, 8 if s.kind == "orb" or s.kind == "ember" else 4, [0.72, 0.55, 1.0] if s.kind == "orb" else ([1.0, 0.55, 0.15] if hot else [0.7, 1.0, 0.95]), 3.0)
	if float(s.splash) > 0.0:
		Snd.play("rm_burn" if hot else "elf_pop", 1.0, at)
		if fx != null:
			for i in 10: fx.glow(at, Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized() * randf_range(2.0, 5.0), 0.5, 0.5, 0.05, Color(1.0, 0.45, 0.1, 0.8) if hot else Color(0.72, 0.5, 1.0, 0.8), 0.0, 2.0)
		var d := _chest().distance_to(at)
		if d < float(s.splash):
			_hurt(str(s.src), float(s.dmg) * clampf(1.2 - d / float(s.splash), 0.3, 1.0), at, "body")
			if float(s.get("burn", 0.0)) > 0.0: hell._burn(float(s.burn))

func tick(dt: float) -> void:
	hell.tick(dt)
	for i in range(_later.size() - 1, -1, -1):
		_later[i].t = float(_later[i].t) - dt
		if float(_later[i].t) <= 0.0: var f: Callable = _later[i].f; _later.remove_at(i); f.call()
	for i in range(lines.size() - 1, -1, -1):
		var L: Dictionary = lines[i]; L.life = float(L.life) - dt
		if float(L.life) <= 0.0:
			if is_instance_valid(L.node): (L.node as Node3D).queue_free()
			lines.remove_at(i)
	for i in range(runes.size() - 1, -1, -1):
		var r: Dictionary = runes[i]; r.t = float(r.t) - dt
		if is_instance_valid(r.node): (r.node as Node3D).rotation.y += dt * 3.0
		if float(r.t) <= 0.0:
			var at: Vector3 = r.at
			if Vector2(player.pos.x - at.x, player.pos.z - at.z).length() < float(r.r) and absf(player.pos.y - at.y) < 1.6:
				_hurt("rune", float(r.dmg), at, "fire")
				if float(r.get("burn", 0.0)) > 0.0: hell._burn(float(r.burn))
			if fx != null:
				var rc: Color = r.get("col", Color(1.0, 0.82, 0.35, 0.9))
				for j in 14: var a := j * TAU / 14.0; fx.glow(at + Vector3(cos(a) * float(r.r) * 0.6, 0.2, sin(a) * float(r.r) * 0.6), Vector3(cos(a) * 1.5, randf_range(3.0, 7.0), sin(a) * 1.5), 0.6, 0.5, 0.05, rc, 0.0, 2.0)
			Snd.play("elf_pop", 1.0, at)
			if is_instance_valid(r.node): (r.node as Node3D).queue_free()
			runes.remove_at(i)
	_beam(dt)
	if shots.is_empty(): return
	var chest := _chest()
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]; s.life = float(s.life) - dt
		var v: Vector3 = s.vel; var p: Vector3 = s.pos
		if s.has("grav"): v.y -= float(s.grav) * dt; s.vel = v   # (a thrown spear falls)
		if float(s.turn) > 0.0:   # it follows you: it slows to turn (so it cannot circle you for ever) and comes on again once it points at you
			var want := (chest - p).normalized(); var cur := v.normalized(); var ang := cur.angle_to(want)
			if ang > 0.001: cur = cur.slerp(want, minf(1.0, float(s.turn) * dt / ang))
			v = cur * float(s.speed) * (1.0 - 0.75 * minf(1.0, ang / 1.2)); s.vel = v
		var step := v * dt; var len := step.length()
		if float(s.life) <= 0.0 or len <= 0.0: _burst(s, p); _gone(s); shots.remove_at(i); continue
		var d := step / len
		# you
		var t := clampf((chest - p).dot(d), 0.0, len); var q := p + d * t
		var dy := q.y - player.pos.y; var reach := 0.42 + float(s.r) + (0.25 if s.kind == "orb" else 0.0)
		if Vector2(q.x - player.pos.x, q.z - player.pos.z).length() < reach and dy > -0.1 and dy < 1.95:
			if float(s.splash) > 0.0: _burst(s, q)
			else:
				_hurt(str(s.src), float(s.dmg), p - d * 2.0, "head" if dy > 1.5 else "body")
				if float(s.get("burn", 0.0)) > 0.0: hell._burn(float(s.burn))
				if float(s.get("shove", 0.0)) > 0.0: player.launch(Vector3(d.x, 0.0, d.z).normalized() * float(s.shove) + Vector3(0, 2.0, 0))
				if float(s.get("pull", 0.0)) > 0.0 and s.get("from") != null and (s.from as Enemies.Foe).alive:   # a hook: it drags you in to whoever threw it
					var to: Vector3 = (s.from as Enemies.Foe).pos - player.pos; var flat := Vector3(to.x, 0, to.z)
					player.launch(flat.normalized() * minf(float(s.pull), flat.length() * 2.2) + Vector3(0, 4.0, 0)); Snd.play("rd_chain", 1.0)
			_gone(s); shots.remove_at(i); continue
		# the world
		if Phys.raycast_static(p, d, len):
			var at := p + d * Phys.rh_t
			if int(s.n) > 0 and wood != null and Phys.rh_box != null and wood.mirrors.has(Phys.rh_box):   # mirror bark: it glances off
				s.n = int(s.n) - 1; s.vel = v.bounce(Phys.rh_n); s.pos = at + Phys.rh_n * 0.03; Snd.play("elf_chime", 0.7, at)
				if fx != null: fx.sparks(at, 5, [0.8, 1.0, 1.0], 2.5)
				_place(s); continue
			_burst(s, at); _gone(s); shots.remove_at(i); continue
		s.pos = p + step; _place(s)
