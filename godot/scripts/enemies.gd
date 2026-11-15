class_name Enemies
extends Node3D
## The enemies: people with guns and blades (stages 1, 1-1, 1-2) and zombies (stage 2). Ported from src/07a_enemies.js and src/07b_ai.js.
## Animals and robots join with their stages.

const ETYPES := {"thug": {"hp": 100, "speed": 3.6, "r": 0.35, "h": 1.8, "name": "조직원"}, "zombie": {"hp": 180, "speed": 1.6, "r": 0.35, "h": 1.8, "name": "좀비"}}
const ROT := ["7d8f6a", "6f7f63", "8a9a7a", "75806a"]
const RAGS := ["3b3a35", "4a4038", "2f3536", "534a3f", "3e4a4c"]
const REVIVE := 3.0   # a zombie that drops gets back up after this long unless it is shot again
# what an armed man carries: the gun in his right hand (boxes laid along the arm) and how he fights.
# range: starts a fight inside it; near/far: the distance he tries to keep; end: how far the muzzle sits from the shoulder
const KITS := {
	"pistol": {"name": "권총", "gun": [[0.045, 0.1, 0.18, 0, -0.66, 0.06, "1d2024"]], "range": 32.0, "near": 8.0, "far": 20.0, "end": 0.62},
	"deagle": {"name": "데저트 이글", "gun": [[0.06, 0.3, 0.12, 0, -0.78, 0.02, "d9a531"], [0.05, 0.08, 0.07, 0, -0.64, -0.04, "b8861e"]], "range": 34.0, "near": 7.0, "far": 18.0, "end": 0.95},
	"dagger": {"name": "단검", "gun": [[0.04, 0.13, 0.045, 0, -0.66, 0.03, "2a1e16"], [0.035, 0.035, 0.11, 0, -0.73, 0.03, "8a8f98"], [0.018, 0.27, 0.05, 0, -0.88, 0.03, "d6dbe3"]], "range": 60.0, "near": 0.0, "far": 0.0, "end": 0.8, "melee": true, "run": 5.2},
	"bomber": {"name": "자폭맨", "gun": [], "range": 80.0, "near": 0.0, "far": 0.0, "end": 0.6, "melee": true, "vest": true, "run": 6.2},
	"saber2": {"name": "쌍광선검", "gun": [[0.05, 0.2, 0.05, 0, -0.7, 0.03, "bfc4cc"]], "range": 60.0, "near": 0.0, "far": 0.0, "end": 0.8, "melee": true, "blade": true, "dual": true, "run": 4.6},
	"bat": {"name": "야구방망이", "gun": [[0.036, 0.26, 0.036, 0, -0.75, 0.03, "26262a"], [0.05, 0.3, 0.05, 0, -1.03, 0.03, "b9bec6"], [0.066, 0.34, 0.066, 0, -1.34, 0.03, "d3d7dd"], [0.07, 0.03, 0.07, 0, -1.52, 0.03, "9ea3ab"]], "range": 50.0, "near": 0.0, "far": 0.0, "end": 0.8, "melee": true, "run": 4.5},
	"smg": {"name": "기관단총", "gun": [[0.06, 0.46, 0.12, 0, -0.84, 0.03, "24272c"], [0.04, 0.06, 0.16, 0, -0.8, -0.08, "1b1d20"]], "range": 30.0, "near": 6.0, "far": 14.0, "end": 1.07},
	"rifle": {"name": "돌격소총", "gun": [[0.06, 0.8, 0.12, 0, -0.98, 0.03, "2b2f26"], [0.05, 0.06, 0.18, 0, -0.86, -0.09, "1b1d20"]], "range": 40.0, "near": 8.0, "far": 22.0, "end": 1.38},
	"sniper": {"name": "저격총", "gun": [[0.05, 1.12, 0.09, 0, -1.12, 0.03, "2a2e24"], [0.06, 0.26, 0.06, 0, -0.86, -0.07, "111111"]], "range": 95.0, "near": 0.0, "far": 0.0, "end": 1.68, "still": true},
	"shotgun": {"name": "샷건", "gun": [[0.07, 0.84, 0.11, 0, -1.0, 0.03, "4a3424"], [0.06, 0.2, 0.07, 0, -1.05, 0.09, "2a2a2a"]], "range": 18.0, "near": 4.0, "far": 9.0, "end": 1.42},
	"gl": {"name": "유탄발사기", "gun": [[0.12, 0.58, 0.13, 0, -0.9, 0.03, "3d4430"], [0.13, 0.2, 0.13, 0, -1.25, 0.03, "2a2e24"]], "range": 45.0, "near": 10.0, "far": 28.0, "end": 1.35},
	"nade": {"name": "수류탄", "gun": [[0.08, 0.1, 0.08, 0, -0.68, 0.03, "3d4430"]], "range": 26.0, "near": 9.0, "far": 20.0, "end": 0.62, "belt": true},
	"flame": {"name": "화염방사기", "gun": [[0.07, 0.74, 0.09, 0, -0.98, 0.03, "3a3a3a"], [0.05, 0.1, 0.05, 0, -1.38, 0.03, "8a5a2a"]], "range": 30.0, "near": 2.5, "far": 6.5, "end": 1.45, "tank": true},
	"saber": {"name": "광선검", "gun": [[0.05, 0.2, 0.05, 0, -0.7, 0.03, "bfc4cc"]], "range": 60.0, "near": 0.0, "far": 0.0, "end": 0.8, "melee": true, "blade": true, "run": 4.3},
	"lmg": {"name": "기관총", "gun": [[0.1, 0.98, 0.16, 0, -1.06, 0.03, "2c2f28"], [0.14, 0.16, 0.12, 0, -0.8, -0.1, "3d4430"]], "range": 45.0, "near": 8.0, "far": 24.0, "end": 1.55},
}
# guns that fire bullets: shots per burst (from, to), gap between shots, damage, pause between bursts (from, to)
const BURST := {"pistol": [1, 3, 0.32, 9.0, 1.1, 2.3], "deagle": [1, 1, 0.3, 45.0, 1.3, 2.2], "smg": [6, 9, 0.08, 7.0, 1.3, 2.1], "rifle": [3, 5, 0.11, 11.0, 1.2, 2.0], "lmg": [12, 18, 0.075, 10.0, 1.0, 1.6], "shotgun": [1, 1, 0.3, 11.0, 1.2, 1.8]}
const JACKETS := ["2b3440", "3d4a33", "4a3b30", "2e2e34", "5a5248", "283a4a", "47302e"]
const SKIN := ["c99a7a", "a8775a", "e0b895", "7d5a44"]
const KEEP_PAD := 0.14
const ACT_R := {1: 55.0, 6: 55.0, 5: 55.0, 2: 45.0, 3: 95.0, 8: 95.0, 7: 95.0}
const VIS_R := {1: 85.0, 6: 85.0, 5: 85.0, 2: 72.0, 3: 165.0, 8: 165.0, 7: 150.0}

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
	var fly := false; var head_x := 0.0
	var helmet := false; var helmet_node: Node3D = null; var vest_shot := false; var vest_light: Node3D = null
	var swing_cd := 0.0; var swing_t := 0.0; var swing_l := false; var stabbed := false; var bat_hit := false
	var downed := false; var down_t := 0.0; var rising := false; var revived := false; var down_parts: Array = []
	var dash_used := false; var rage := false; var charge_cd := 0.0; var state_t := 0.0; var hit_done := false; var cx := 0.0; var cz := 0.0; var attack_cd := 0.0; var moan_t := 0.0
	# animals (stages 3, 3-1)
	var animal := false; var kong := false; var minion := false; var wild := false; var tamed := false; var ridden := false; var caged := false; var glassed := false; var cage := {}
	var release_t := 0.0; var fury := false; var angry := false; var bs := ""; var bt := 0.0; var bt_max := 1.0; var buff := 1.0; var kneel_t := 0.0; var attack_t := 0.0; var pounce_cd := 0.0
	var roar_t := 0.0; var roar_cd := 0.0; var airborne := false; var windup := 0.0; var graze := 0.0; var home := Vector2.ZERO; var wx := 0.0; var wz := 0.0; var cstate := ""
	var detour_t := 0.0; var dx2 := 0.0; var dz2 := 0.0; var stuck_t := 0.0; var bx0 := 0.0; var bz0 := 0.0; var last_x := 0.0; var last_z := 0.0; var has_last := false; var pin_t := 0.0; var ghost_t := 0.0
	var zig_t := 0.0; var fx_ := 0.0; var fz_ := 0.0; var bit := false; var roared := false; var tossed := false; var v0 := 0.0; var pass_v := 0.0; var slot = null; var claim_t := 0.0; var sg_cd := 0.0
	var bleed_n := 0; var bleed_t := 0.0; var bleed_acc := 0.0; var k := {}; var legs: Array = []; var body: Node3D = null; var head: Node3D = null; var neck_base: Array = []; var yaw_off := 0.0
	var fuse := 0.0; var beep2 := false; var flame_on := 0.0; var flame_acc := 0.0; var flame_snd := 0.0; var aim_t := 0.0; var laser: MeshInstance3D = null   # a flying thing; a head that takes more than the gun's usual headshot (0: the usual)

var list: Array[Foe] = []
var dying: Array[Foe] = []
var skip_calm := false
var player: Player
var cam: Camera3D
var proj: Proj
var on_kill: Callable = Callable()   # (foe, weak)
var say: Callable = Callable()       # a line for the feed
var hitmark: Callable = Callable()
var fx: Fx = null
var flying: Array = []                # helmets knocked off: [node, velocity, age]
var helmet_hint := false
var down_hint := false
var stage := 1
var on_bite: Callable = Callable()     # (foe): a zombie's bite landed
var on_poison: Callable = Callable()   # (foe): a zombie's dash landed
var on_stun: Callable = Callable()     # (foe): the boss's charge landed
var banner: Callable = Callable()
var animals: Animals
var _bar_green: StandardMaterial3D
var _bar_amber: StandardMaterial3D
var _meshes := {}
var _mat: StandardMaterial3D
var _bar_bg: StandardMaterial3D
var _bar_fill: StandardMaterial3D
var _bar_mesh: QuadMesh

func _ready() -> void:
	_mat = StandardMaterial3D.new(); _mat.vertex_color_use_as_albedo = true; _mat.roughness = 0.85
	_bar_bg = Gfx.unlit(Color(0.05, 0.06, 0.09), false); _bar_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; _bar_bg.billboard_keep_scale = true
	_bar_fill = Gfx.unlit(Color("ff5260"), false); _bar_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; _bar_fill.billboard_keep_scale = true; _bar_fill.no_depth_test = false
	_bar_green = _bar_fill.duplicate(); _bar_green.albedo_color = Color("9be88f"); _bar_amber = _bar_fill.duplicate(); _bar_amber.albedo_color = Color("f2a33a")
	animals = Animals.new(); animals.en = self
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
	var zombie := e.type == "zombie"
	var body: String = RAGS[randi() % RAGS.size()] if zombie else JACKETS[randi() % JACKETS.size()]; var skin: String = ROT[randi() % ROT.size()] if zombie else SKIN[randi() % SKIN.size()]; var pants := "2c2c2a" if zombie else "22252b"
	e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; add_child(e.g)
	var leg := [[0.15, 0.9, 0.17, 0, -0.45, 0, pants], [0.16, 0.09, 0.27, 0, -0.88, 0.05, "161616"]]
	e.leg_l = _part(e.g, Vector3(-0.11, 0.92, 0), "leg", leg); e.leg_r = _part(e.g, Vector3(0.11, 0.92, 0), "leg", leg)
	var K := e.K; var up := [[0.44, 0.62, 0.26, 0, 0.36, 0, body], [0.22, 0.25, 0.24, 0, 0.8, 0.01, skin], [0.24, 0.08, 0.26, 0, 0.94, 0, pants]]
	if K.get("vest", false): up.append_array([[0.42, 0.28, 0.07, 0, 0.42, 0.15, "5b4a2c"], [0.07, 0.22, 0.05, -0.13, 0.42, 0.2, "8a3a24"], [0.07, 0.22, 0.05, 0, 0.42, 0.2, "8a3a24"], [0.07, 0.22, 0.05, 0.13, 0.42, 0.2, "8a3a24"], [0.36, 0.02, 0.02, 0, 0.53, 0.21, "d8c040"]])
	if K.get("tank", false): up.append_array([[0.13, 0.46, 0.13, -0.09, 0.42, -0.21, "8a2a1e"], [0.13, 0.46, 0.13, 0.09, 0.42, -0.21, "8a2a1e"], [0.03, 0.3, 0.03, 0.2, 0.3, -0.12, "2a2a2a"]])
	if K.get("belt", false):
		for i in 4: up.push_back([0.07, 0.08, 0.07, -0.15 + i * 0.1, 0.06, 0.15, "3d4430"])
	if zombie: up.append_array([[0.035, 0.025, 0.01, -0.05, 0.82, 0.13, "fff0a0"], [0.035, 0.025, 0.01, 0.05, 0.82, 0.13, "fff0a0"]])   # pale eyes
	e.upper = _part(e.g, Vector3(0, 0.92, 0), "up" + body + skin + e.kit, up)
	var arm := [[0.12, 0.62, 0.13, 0, -0.29, 0, body], [0.1, 0.1, 0.1, 0, -0.62, 0, skin]]
	e.arm_l = _part(e.upper, Vector3(-0.29, 0.6, 0), "arm" + body + skin + ("2" if K.get("dual", false) else ""), arm + ([[0.05, 0.2, 0.05, 0, -0.7, 0.03, "bfc4cc"]] if K.get("dual", false) else []))
	e.arm_r = _part(e.upper, Vector3(0.29, 0.6, 0), "armg" + body + skin + e.kit, arm + ([] if zombie else K.gun))
	if K.get("blade", false):   # a glowing blade on the hilt; two red ones for the dual wielders
		for a in ([e.arm_r, e.arm_l] if K.get("dual", false) else [e.arm_r]):
			var bl := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.05, 1.15, 0.05); bl.mesh = bm; bl.position = Vector3(0, -1.38, 0.03)
			var bmat := Gfx.unlit(Color(1.0, 0.45, 0.45) if K.get("dual", false) else Color(0.55, 0.78, 1.0), false); bl.material_override = bmat; a.add_child(bl)
	if K.get("vest", false):
		var vl := MeshInstance3D.new(); var vb := BoxMesh.new(); vb.size = Vector3(0.05, 0.05, 0.03); vl.mesh = vb; vl.material_override = Gfx.unlit(Color(1, 0.16, 0.1), false); vl.position = Vector3(0.11, 1.45, 0.215); e.g.add_child(vl); e.vest_light = vl
	e.parts = [{"o": Vector3(0, 1.72, 0.01), "r": 0.15, "mult": 1.0, "weak": true, "bomb": false}, {"o": Vector3(0, 1.3, 0), "r": 0.3, "mult": 1.0, "weak": false, "bomb": false},
		{"o": Vector3(0, 0.95, 0), "r": 0.22, "mult": 0.9, "weak": false, "bomb": false}, {"o": Vector3(0, 0.48, 0), "r": 0.24, "mult": 0.7, "weak": false, "bomb": false}]
	# the bomb strapped to a bomber's chest: one bullet in it and it goes off
	if K.get("vest", false): e.parts.insert(1, {"o": Vector3(0, 1.34, 0.18), "r": 0.2, "mult": 1.0, "weak": false, "bomb": true})
	e.bar = Node3D.new(); e.bar.visible = false; add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = _bar_mesh; bg.material_override = _bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = _bar_mesh; e.fill.material_override = _bar_fill; e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)
	if zombie: e.fill.material_override = _bar_green

func spawn(type: String, x: float, z: float, opts := {}) -> Foe:
	var beast: bool = Animals.ANIMALS.has(type)
	var e := Foe.new(); e.type = type; e.T = Animals.ANIMALS[type] if beast else ETYPES[type]; e.kit = opts.get("kit", "pistol"); e.K = KITS.get(e.kit, KITS.pistol)
	if beast: animals.build(e, type, opts)
	else: _build(e)
	if opts.get("helmet", false):   # a full-face motorcycle helmet: the first shot to the head knocks it off
		e.helmet = true; e.helmet_node = _helmet(); e.upper.add_child(e.helmet_node)
	var sc: float = opts.get("scale", 1.0)
	# a person's outline from above, in his own frame (x right, z forward): arms out at the front
	e.foot = {"x0": -0.4 * sc, "x1": 0.4 * sc, "z0": -0.18 * sc, "z1": 0.52 * sc}
	e.foot_r = Vector2(0.4 * sc, 0.52 * sc).length()
	e.boss = opts.get("boss", false); e.mass = (1.3 if type == "zombie" else 1.0) * (2.0 if e.boss else 1.0) * (sc if sc > 1.05 else 1.0)
	if beast:   # the outline measured from the browser game's model
		var F: Array = Animals.FEET[type]; e.foot = {"x0": F[0] * sc, "x1": F[1] * sc, "z0": F[2] * sc, "z1": F[3] * sc}
		e.foot_r = Vector2(maxf(-e.foot.x0, e.foot.x1), maxf(-e.foot.z0, e.foot.z1)).length()
		e.mass = 40.0 if (e.kong and e.boss) else Animals.MASS[type] * (2.0 if e.boss else 1.0) * (sc if sc > 1.05 else 1.0)
		e.sg_cd = randf_range(0.2, 1.0)
	e.name = opts.get("name", e.T.name); e.scale = sc; e.R = e.T.r * sc; e.H = e.T.h * sc
	e.hp = roundf(opts.get("hp", e.T.hp)); e.max_hp = e.hp; e.diff = opts.get("diff", 0.0); e.dmg_mul = opts.get("dmgMul", 1.0)
	e.speed = e.T.speed * randf_range(0.9, 1.1) * (0.9 if e.boss else 1.0)
	if type == "zombie": e.speed = 1.7 if e.boss else randf_range(1.25, 2.0)
	e.pos = Vector3(x, opts.get("y", 0.0), z); e.yaw = opts.get("yaw", randf() * TAU)
	e.lod = randf() * 0.5; e.los_t = randf() * 0.3; e.fire_t = randf_range(0.8, 1.6); e.strafe = 1.0 if randf() < 0.5 else -1.0; e.strafe_t = randf_range(1, 2.5); e.walk = randf() * TAU
	e.muzzle = Vector3(0.2, 1.42, e.K.end)
	if type != "zombie" and e.K.has("run"): e.speed = maxf(e.speed, e.K.run * 0.9)   # melee men close the distance quickly even before they see you
	e.g.position = e.pos; e.g.rotation = Vector3(0, e.yaw, 0); e.g.scale = Vector3.ONE * sc
	if e.boss: e.bar.scale = Vector3.ONE * 1.6
	if beast: animals.init(e)
	list.push_back(e)
	return e

func part_centre(e: Foe, p: Dictionary) -> Vector3:
	var cy := cos(e.yaw); var sy := sin(e.yaw); var o: Vector3 = p.o
	return Vector3(e.pos.x + (o.x * cy + o.z * sy) * e.scale, e.pos.y + o.y * e.scale, e.pos.z + (-o.x * sy + o.z * cy) * e.scale)

## the first enemy a ray meets before max_t: null, or {enemy, t, weak, mult, bomb}
func raycast(o: Vector3, d: Vector3, max_t: float):
	var best := max_t; var hit: Foe = null; var r_mult := 1.0; var r_weak := false; var r_bomb := false
	for e in list:
		if not e.alive: continue
		if (e.pos.x - o.x) * d.x + (e.pos.z - o.z) * d.z < -2.0 * e.scale: continue
		for p in (e.down_parts if e.downed else e.parts):
			var c := part_centre(e, p); var oc := o - c; var pr: float = p.r * e.scale
			var b := oc.dot(d); var cc := oc.length_squared() - pr * pr; var disc := b * b - cc
			if disc < 0.0: continue
			var t := -b - sqrt(disc)
			if t < 0.0: t = -b + sqrt(disc)
			if t > 0.0 and (t < best - 0.02 or (t < best + 0.02 and p.weak and hit == e and not r_weak)): best = t; hit = e; r_mult = p.mult; r_weak = p.weak; r_bomb = p.bomb
	if hit == null: return null
	return {"enemy": hit, "t": best, "mult": r_mult, "weak": r_weak, "bomb": r_bomb}

## touch aim help: the direction to the body part closest to the line of fire (within max_ang), or null
func assist(o: Vector3, d: Vector3, max_ang: float, max_dist: float):
	var best_score := INF; var best = null
	for e in list:
		if not e.alive or not e.g.visible: continue
		for p in (e.down_parts if e.downed else e.parts):
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
	if e.alert or not e.alive or e.downed: return
	e.alert = true; e.state = "move"
	if e.type == "zombie":
		if e.dist < 30.0: Snd.play("moan", 1.0, e.pos)
	else: e.react = maxf(e.react, randf_range(0.4, 0.8))

## gunfire carries: everyone within earshot comes for you
func noise(at: Vector3, r: float) -> void:
	for e in list:
		if not e.alive: continue
		var d := Vector2(e.pos.x - at.x, e.pos.z - at.z).length()
		if d > r: continue
		if e.animal: animals.hear(e, d)
		else: alarm(e)

func damage(e: Foe, dmg: float, _at: Vector3, dir: Vector3, weak: bool, quiet := false) -> bool:
	if not e.alive: return false
	if e.glassed and e.caged: Snd.play("metal", 1.0, _at); return false   # behind bulletproof glass nothing hurts it
	if weak and e.helmet: _knock_helmet(e, dir); return false   # a helmet takes the first shot to the head and flies off
	# a zombie lying on the ground: one more hit and the body is gone for good
	if e.downed: Snd.play("squelch", 1.0, e.pos); e.vanish = true; kill(e, weak, dir); return true
	e.hp -= dmg
	if quiet:   # bleeding: no flinch, no shove
		if e.hp <= 0.0: kill(e, false, dir); return true
		return false
	e.flinch = 1.0
	if not e.boss and not e.ridden: e.vel.x += dir.x * 0.9; e.vel.z += dir.z * 0.9
	if e.animal: animals.provoke(e)
	elif e.type == "zombie": alarm(e)
	else:
		alarm(e); e.los = true; e.react = minf(e.react, 0.3)
		for o in list:
			if Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 18.0: alarm(o)
	if e.hp <= 0.0:
		if e.type == "zombie": _down(e, dir); return false
		kill(e, weak, dir); return true
	return false

## zombies do not stay dead: they drop, and unless shot again within 3 seconds they get back up at full health
func _down(e: Foe, dir) -> void:
	e.downed = true; e.down_t = 0.0; e.hp = 0.0; e.state = "down"; e.vel = Vector3.ZERO; e.flinch = 0.0; e.rising = false
	e.fall_dir = 1.0
	if dir != null: e.fall_dir = 1.0 if sin(e.yaw) * dir.x + cos(e.yaw) * dir.z > 0.0 else -1.0
	# where the body is once it lies flat, for bullets: along the fall direction, just off the ground
	e.down_parts = e.parts.map(func(p): return {"o": Vector3(p.o.x, maxf(0.16, p.o.y * 0.12 + 0.08), e.fall_dir * p.o.y * 0.99), "r": p.r * 1.05, "mult": 1.0, "weak": p.weak, "bomb": false})
	e.fill.material_override = _bar_amber
	Snd.play("thud", 1.0, e.pos); Snd.play("moan", 1.0, e.pos)
	if not down_hint and say.is_valid(): down_hint = true; say.call("쓰러진 좀비는 3초 안에 한 번 더 쏴야 사라집니다 · 안 그러면 다시 일어납니다")

func _update_downed(e: Foe, dt: float) -> void:
	e.down_t += dt; var t := e.down_t
	if t < REVIVE:
		var k := minf(1.0, t / 0.45); var ease := k * k * (3.0 - 2.0 * k)
		e.g.rotation = Vector3(e.fall_dir * ease * 1.45, e.yaw, sin(t * 38.0) * 0.06 if t > REVIVE - 1.0 else 0.0)   # twitches before it rises
		e.leg_l.rotation.x = 0.0; e.leg_r.rotation.x = 0.0; e.upper.rotation.x = 0.0
	elif t < REVIVE + 0.7:
		if not e.rising: e.rising = true; Snd.play("revive", 1.0, e.pos)
		var k2 := (t - REVIVE) / 0.7; var ease2 := k2 * k2 * (3.0 - 2.0 * k2)
		e.g.rotation = Vector3(e.fall_dir * (1.0 - ease2) * 1.45, e.yaw, 0)
	else:
		e.downed = false; e.rising = false; e.hp = e.max_hp; e.dash_used = false; e.revived = true   # too late for the bonus
		e.state = "move"; e.alert = true; e.charge_cd = 3.0
		e.g.rotation = Vector3(0, e.yaw, 0); e.fill.material_override = _bar_green; e.bar.visible = false
		if e.boss and banner.is_valid(): banner.call(e.name + " 부활", "쓰러지면 3초 안에 한 번 더 쏘세요", 2.2)
		return
	# the bar above the body counts down to the moment it gets back up
	e.bar.visible = e.g.visible; e.bar.position = Vector3(e.pos.x, e.pos.y + 0.7 * e.scale, e.pos.z)
	var f := clampf(1.0 - t / REVIVE, 0.0, 1.0); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1.0 - f)

## zombie skills. ordinary zombies dash once when down to 30% health, and that dash poisons;
## the boss enrages at half health (red, much faster) and every few seconds rears up and charges, which stuns you
func _zombie_skill(e: Foe, dt: float, dist: float, to: Vector2) -> bool:
	if e.boss and not e.rage and e.hp <= e.max_hp * 0.5:
		e.rage = true; e.speed *= 1.9; e.charge_cd = 1.6
		for n in e.g.find_children("*", "MeshInstance3D", true, false):   # it turns red
			var rm: StandardMaterial3D = _mat.duplicate(); rm.albedo_color = Color(1, 0.4, 0.36); rm.emission_enabled = true; rm.emission = Color(0.3, 0.02, 0.01); (n as MeshInstance3D).material_override = rm
		Snd.play("rage", 1.0, e.pos); player.shake = maxf(player.shake, 0.25)
		if banner.is_valid(): banner.call(e.name + " 폭주", "빨라지고 가끔 돌진합니다 · 맞으면 2초 기절", 2.4)
	if not e.boss and not e.dash_used and e.hp > 0.0 and e.hp <= e.max_hp * 0.3 and e.state != "lunge":
		e.dash_used = true; e.state = "dash"; e.state_t = 1.1; e.hit_done = false
		e.cx = to.x / dist; e.cz = to.y / dist; e.yaw = atan2(e.cx, e.cz)
		Snd.play("scream", 1.0, e.pos)
	if e.boss and e.rage and e.state == "move":
		e.charge_cd -= dt
		if e.charge_cd <= 0.0 and dist > 3.5 and dist < 26.0 and e.los: e.state = "windup"; e.state_t = 0.65; Snd.play("rage", 1.0, e.pos)
	if e.state == "windup":
		e.state_t -= dt; _turn_toward(e, atan2(to.x, to.y), 7.0, dt)
		e.upper.rotation.x = -0.32; e.arm_l.rotation.x = -2.6; e.arm_r.rotation.x = -2.6; e.leg_l.rotation.x = 0.35; e.leg_r.rotation.x = -0.35
		if e.state_t <= 0.0: e.state = "charge"; e.state_t = 1.4; e.hit_done = false; e.cx = sin(e.yaw); e.cz = cos(e.yaw)
		return true
	if e.state == "dash" or e.state == "charge":
		var charge := e.state == "charge"; var sp := 13.0 if charge else 8.5
		e.state_t -= dt
		var blocked := _ground_move(e, e.cx * sp, e.cz * sp, dt)
		_animate(e, sp, dt, false)
		e.arm_l.rotation.x = -1.6; e.arm_r.rotation.x = -1.65; e.upper.rotation.x = 0.5
		if not e.hit_done and dist < stop_dist(e) + 0.55 and absf(player.pos.y - e.pos.y) < 1.6 * e.scale:
			e.hit_done = true
			if charge:
				if on_stun.is_valid(): on_stun.call(e)
			elif on_poison.is_valid(): on_poison.call(e)
		if charge and fx and randf() < dt * 18.0: fx.smoke(Vector3(e.pos.x, 0.25, e.pos.z))
		if e.state_t <= 0.0 or blocked or e.hit_done: e.state = "move"; e.charge_cd = randf_range(5, 8)
		return true
	return false

## a zombie that is after you: shamble straight for the player once close, otherwise follow the flow field; claw and bite at arm's length
func _zombie(e: Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var mvx: float; var mvz: float
	var fd := Phys.flow_dir(e.pos.x, e.pos.z)
	if dist < 9.0 and e.los: mvx = to.x / dist; mvz = to.y / dist
	elif fd != Vector2.ZERO: mvx = fd.x; mvz = fd.y
	else: mvx = to.x / dist; mvz = to.y / dist
	var sp := e.speed; e.attack_cd -= dt; var sd := stop_dist(e); var level := absf(player.pos.y - e.pos.y) < 1.6 * e.scale
	if e.state == "lunge":
		e.state_t -= dt; sp *= 0.2
		if e.state_t <= 0.0:
			e.state = "move"
			if dist < maxf(1.75, sd + 0.6) and level and on_bite.is_valid(): on_bite.call(e)
	elif dist < maxf(1.35, sd + 0.25) and e.attack_cd <= 0.0 and level: e.state = "lunge"; e.state_t = 0.35; e.attack_cd = 1.4
	if dist < sd + 0.05 and e.state != "lunge": sp = 0.0   # pressed against you: stop pushing, just claw
	mvx *= sp; mvz *= sp
	_turn_toward(e, face_yaw if dist < 9.0 else atan2(mvx, mvz), 3.5, dt)
	e.vel *= exp(-dt * 5.0)
	_ground_move(e, mvx + e.vel.x, mvz + e.vel.z, dt)
	_animate(e, sp, dt, false)
	if e.state == "lunge": e.arm_l.rotation.x = -1.75; e.arm_r.rotation.x = -1.8; e.upper.rotation.x = 0.45
	e.moan_t -= dt
	if e.moan_t <= 0.0:
		e.moan_t = randf_range(3, 8)
		if dist < 28.0: Snd.play("moan", 1.0, e.pos)

func kill(e: Foe, weak: bool, dir) -> void:
	e.alive = false; e.dead_t = 0.0; e.bar.visible = false; e.g.visible = true
	if e.laser: e.laser.visible = false
	if e.K.get("vest", false):   # the vest goes off (at once if the bomb itself was hit, or he set it off)
		var now := e.self_det or e.vest_shot; proj.bomb(e.pos, 0.02 if now else 0.3)
		if now: e.vanish = true
	e.fall_dir = 1.0 if e.type == "zombie" else -1.0; e.downed = false
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

## a bullet in a bomber's chest bomb: it goes off there and then, and the kill is yours
func blow_vest(e: Foe, dir: Vector3) -> void:
	if not e.alive: return
	e.vest_shot = true; e.hp = 0.0
	if say.is_valid(): say.call("자폭 조끼 명중 · 폭탄이 터졌습니다")
	kill(e, false, dir)

## a bomber who reaches you: his own vest, no money for you, but he counts as gone
func detonate(e: Foe) -> void:
	if e.alive: e.self_det = true; kill(e, false, null)

func _helmet() -> Node3D:
	var n := Node3D.new(); var m := MeshInstance3D.new()
	m.mesh = _box_mesh("helmet", [[0.34, 0.31, 0.36, 0, 0.83, -0.005, "0d0e10"], [0.3, 0.07, 0.31, 0, 1.0, -0.015, "0d0e10"], [0.33, 0.12, 0.12, 0, 0.67, -0.12, "0d0e10"], [0.3, 0.11, 0.11, 0, 0.7, 0.14, "0d0e10"],
		[0.28, 0.13, 0.03, 0, 0.825, 0.18, "3a4d60"], [0.26, 0.018, 0.034, 0, 0.885, 0.183, "c2d2e2"], [0.3, 0.05, 0.3, 0, 0.655, 0, "121316"]])
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.25; mat.metallic = 0.3; m.material_override = mat; n.add_child(m)
	return n

func _knock_helmet(e: Foe, dir: Vector3) -> void:
	e.helmet = false
	var n := e.helmet_node; e.helmet_node = null; var at := n.global_position; e.upper.remove_child(n); add_child(n); n.global_position = at; n.rotation.y = e.yaw; n.scale = Vector3.ONE * e.scale
	flying.push_back([n, Vector3(dir.x * 3.0 + randf_range(-1, 1), randf_range(3, 4.5), dir.z * 3.0 + randf_range(-1, 1)), 0.0])
	Snd.play("ping", 1.0, e.pos); e.flinch = 1.0
	if hitmark.is_valid(): hitmark.call(false, false)
	if not helmet_hint and say.is_valid(): helmet_hint = true; say.call("헬멧이 벗겨졌습니다 · 한 번 더 머리를 쏘세요")
	alarm(e)

func clear() -> void:
	for e in list + dying:
		e.g.queue_free(); e.bar.queue_free()
		if e.laser: e.laser.queue_free()
	for f in flying: f[0].queue_free()
	list.clear(); dying.clear(); flying.clear()
	if animals.player != null: animals.reset()

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

## how each kit fights once it has you in sight. returns true while it is busy (and moves slower)
func _fight(e: Foe, dt: float, dist: float) -> bool:
	var kit := e.kit; var m := e.dmg_mul; e.fire_t -= dt; var sd := stop_dist(e); var dy := absf(player.pos.y - e.pos.y)
	match kit:
		"saber", "saber2":   # runs you down and swings; one cut is 300. with a blade in each hand the cuts come twice as often
			var dual := kit == "saber2"; e.swing_cd -= dt
			if e.swing_t > 0.0:
				e.swing_t -= dt; var arm := e.arm_l if e.swing_l else e.arm_r
				arm.rotation = Vector3(-2.6 + (0.28 - e.swing_t) * 9.0, 0, 0.4 * (1.0 if e.swing_l else -1.0))
				if e.swing_t <= 0.0 and dist < sd + 1.3 and dy < 1.8: player.hurt(300.0 * m, e.pos, "head"); Snd.play("saber_hit", 1.0, e.pos)   # an overhead chop
				return true
			if dist < sd + 0.9 and e.swing_cd <= 0.0: e.swing_t = 0.28; e.swing_cd = 0.62 if dual else 1.25; e.swing_l = dual and not e.swing_l; Snd.play("saber_swing", 1.0, e.pos)
			if e.fire_t <= 0.0:
				e.fire_t = randf_range(1.2, 2.0)
				if dist < 25.0: Snd.play("saber_hum", 1.0, e.pos)
			return false
		"dagger":   # a knife: arm back, then a quick thrust; 70 a stab, nearly two a second once he is on you
			e.swing_cd -= dt
			if e.swing_t > 0.0:
				e.swing_t -= dt; var u := 1.0 - e.swing_t / 0.32
				e.arm_r.rotation = Vector3(-0.7 + u * 1.2 if u < 0.45 else -0.16 - (u - 0.45) / 0.55 * 1.5, 0, -0.12)
				if not e.stabbed and u >= 0.6:
					e.stabbed = true; Snd.play("swoosh", 1.0, e.pos)
					if dist < sd + 1.0 and dy < 1.7: player.hurt(70.0 * m, e.pos, "body"); Snd.play("squelch", 1.0, e.pos)
				return true
			if dist < sd + 0.8 and e.swing_cd <= 0.0: e.swing_t = 0.32; e.swing_cd = 0.55; e.stabbed = false
			return false
		"bat":   # the bat goes up over the shoulder, then comes round flat: 150 and a shove
			e.swing_cd -= dt
			if e.swing_t > 0.0:
				e.swing_t -= dt; var u := 1.0 - e.swing_t / 0.55
				if u < 0.55: var w := u / 0.55; e.arm_r.rotation = Vector3(-1.2 - w * 1.5, 0, -0.2 - w * 0.6)
				else: var w2 := (u - 0.55) / 0.45; e.arm_r.rotation = Vector3(-2.7 + w2 * 1.4, 0, -0.8 + w2 * 1.6)
				if not e.bat_hit and u >= 0.75:
					e.bat_hit = true; Snd.play("swoosh", 1.0, e.pos)
					if dist < sd + 1.25 and dy < 1.8:
						player.hurt(150.0 * m, e.pos, "head"); Snd.play("bat_hit", 1.0, e.pos)   # swung at head height
						player.vel.x += (player.pos.x - e.pos.x) / maxf(dist, 0.001) * 6.0; player.vel.z += (player.pos.z - e.pos.z) / maxf(dist, 0.001) * 6.0
				return true
			if dist < sd + 0.9 and e.swing_cd <= 0.0: e.swing_t = 0.55; e.swing_cd = 1.4; e.bat_hit = false
			return false
		"bomber":   # close enough: arms up, the vest beeps fast, and after a moment it all goes
			if e.fuse > 0.0:
				e.fuse -= dt; e.arm_l.rotation = Vector3(-2.9, 0, 0.35); e.arm_r.rotation = Vector3(-2.9, 0, -0.35)
				if not e.beep2 and e.fuse < 0.3: e.beep2 = true; Snd.play("beep", 1.0, e.pos)
				if e.fuse <= 0.0: detonate(e)
				return true
			if dist < sd + 1.4 and dy < 2.0: e.fuse = 0.6; e.beep2 = false; Snd.play("beep", 1.0, e.pos); Snd.play("scream", 1.0, e.pos)
			return false
		"flame":
			if e.flame_on > 0.0:
				e.flame_on -= dt; var mz := muzzle_of(e); var fx_ := sin(e.yaw); var fz := cos(e.yaw)
				if fx: fx.flame(mz, Vector3(fx_, 0.02, fz) * 0.45)
				# you are in the cone: inside 9.5 m and within about 20 degrees of where the nozzle points
				var c := ((player.pos.x - e.pos.x) * fx_ + (player.pos.z - e.pos.z) * fz) / maxf(dist, 0.001)
				if dist < 9.5 and c > 0.94 and dy < 2.2:
					e.flame_acc += 75.0 * m * dt
					if e.flame_acc >= 15.0: e.flame_acc -= 15.0; player.hurt(15.0, e.pos, "fire")
				e.flame_snd -= dt
				if e.flame_snd <= 0.0: e.flame_snd = 0.18; Snd.play("flame", 1.0, mz)
				return true
			if dist < 9.0 and e.fire_t <= 0.0: e.flame_on = randf_range(1.6, 2.4); e.fire_t = e.flame_on + randf_range(0.9, 1.5)
			return false
		"sniper":   # a red laser shows where he is aiming for a moment before the shot
			if e.laser == null:
				e.laser = MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.018, 0.018, 1.0); e.laser.mesh = lb
				var lm := Gfx.unlit(Color(1, 0.16, 0.16, 0.75), false); lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; e.laser.material_override = lm; e.laser.visible = false; add_child(e.laser)
			if e.aim_t > 0.0:
				e.aim_t -= dt; var mz := muzzle_of(e); var aim := Vector3(player.pos.x + player.vel.x * dist / 400.0, player.pos.y + 1.58, player.pos.z + player.vel.z * dist / 400.0)   # snipers go for the head
				var L := mz.distance_to(aim)
				if L > 0.5: e.laser.look_at_from_position((mz + aim) / 2, aim, Vector3.UP); e.laser.scale = Vector3(1, 1, L); e.laser.visible = true
				if e.aim_t <= 0.0: e.laser.visible = false; proj.bullet(mz, aim, 160.0, 140.0 * m, 0.05 + player.speed_xz * 0.12); Snd.play("shot_far", 1.2, mz); e.fire_t = randf_range(2.4, 3.4)
				return true
			if e.fire_t <= 0.0: e.aim_t = 1.3
			return false
		"gl", "nade":
			if e.fire_t <= 0.0:
				var mz := muzzle_of(e); var lead := 60.0 if kit == "gl" else 45.0
				var aim := Vector3(player.pos.x + player.vel.x * dist / lead, player.pos.y + 0.3, player.pos.z + player.vel.z * dist / lead)
				if kit == "nade": e.arm_r.rotation = Vector3(-2.8, 0, 0); mz.y += 0.4
				proj.egrenade(mz, aim, kit); e.fire_t = randf_range(2.6, 3.6) if kit == "gl" else randf_range(2.4, 3.6)
			return false
	# guns that fire bullets
	var G: Array = BURST.get(kit, BURST.pistol)
	if kit == "shotgun" and dist > 18.0: return false
	if e.burst > 0:
		e.burst_t -= dt
		if e.burst_t <= 0.0:
			e.burst -= 1; e.burst_t = G[2] * (0.62 if (e.boss and kit == "pistol") else 1.0)
			var mz := muzzle_of(e); var lead := 120.0 if kit == "shotgun" else 150.0
			var aim := Vector3(player.pos.x + player.vel.x * dist / lead, player.pos.y + 1.25, player.pos.z + player.vel.z * dist / lead)
			if kit == "shotgun":
				for k in 7: proj.bullet(mz, aim, 70.0, G[3] * m, 0.9 + dist * 0.05)
			else: proj.bullet(mz, aim, 95.0 if kit == "deagle" else 80.0, G[3] * m, (0.2 if kit == "deagle" else (0.55 if kit == "smg" else 0.35)) + dist * 0.028 + player.speed_xz * 0.08 - (0.15 if e.boss else 0.0))
			Snd.play("shot_far", 1.0, mz)
		return true
	if e.fire_t <= 0.0: e.burst = 4 if (e.boss and kit == "pistol") else randi_range(G[0], G[1]); e.burst_t = 0.0; e.fire_t = randf_range(G[4], G[5]) * (0.7 if e.boss else 1.0)
	return false

func _animate(e: Foe, sp: float, dt: float, aim: bool) -> void:
	if e.type == "zombie":   # a shamble: arms out in front, the body rocking from side to side
		e.walk += dt * sp * 3.2; var zs := sin(e.walk) * minf(1.0, sp / 2.0) * 0.45
		e.leg_l.rotation.x = zs; e.leg_r.rotation.x = -zs
		var sway := sin(e.walk * 0.5) * 0.12
		e.arm_l.rotation = Vector3(-1.35 + sway, 0, 0.08); e.arm_r.rotation = Vector3(-1.4 - sway, 0, -0.08); e.upper.rotation.z = sin(e.walk * 0.5) * 0.06
		e.flinch = maxf(0.0, e.flinch - dt * 5.0); e.upper.rotation.x = 0.28 - e.flinch * 0.25
		return
	e.walk += dt * sp * 2.6; var s := sin(e.walk) * clampf(sp / 3.0, 0.0, 1.0)
	e.leg_l.rotation.x = s * 0.7; e.leg_r.rotation.x = -s * 0.7
	match e.kit:   # how each carries what he has
		"saber":
			if e.swing_t <= 0.0: e.arm_r.rotation = Vector3(-1.15 if aim else -0.5 - s * 0.3, 0, -0.3)
			e.arm_l.rotation = Vector3(s * 0.8, 0, 0.1)
		"saber2":
			if not (e.swing_t > 0.0 and not e.swing_l): e.arm_r.rotation = Vector3(-1.15 if aim else -0.5 - s * 0.3, 0, -0.3)
			if not (e.swing_t > 0.0 and e.swing_l): e.arm_l.rotation = Vector3(-1.15 if aim else -0.5 + s * 0.3, 0, 0.3)
		"dagger":
			if e.swing_t <= 0.0: e.arm_r.rotation = Vector3(-0.9 if aim else -0.55 - s * 0.3, 0, -0.12)
			e.arm_l.rotation = Vector3(s * 0.9, 0, 0.12)
		"bat":
			if e.swing_t <= 0.0: e.arm_r.rotation = Vector3(-2.3 if aim else -2.0 - s * 0.15, 0, -0.35)
			e.arm_l.rotation = Vector3(s * 0.8, 0, 0.1)
		"bomber":
			if e.fuse <= 0.0: e.arm_r.rotation = Vector3(-s * 1.1, 0, -0.15); e.arm_l.rotation = Vector3(s * 1.1, 0, 0.15)
		_:
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
	var vis: float = VIS_R.get(stage, 90.0) * (0.75 if DisplayServer.is_touchscreen_available() else 1.0)
	for e in list:
		if not e.alive: continue
		e.lod -= dt
		if e.lod <= 0.0:
			e.lod = 0.3 + randf() * 0.2; e.dist = Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z).length()
			e.g.visible = e.dist < vis * (1.6 if e.boss else 1.0); e.awake = e.alert or e.angry or e.dist < ACT_R.get(stage, 60.0)
			if not e.g.visible: e.bar.visible = false
		if e.downed: _update_downed(e, dt); e.g.position = e.pos; continue
		if e.ridden: e.bar.visible = false; continue   # you are on it: you steer it
		if not e.awake: continue
		var eye := Vector3(e.pos.x, e.pos.y + 1.65 * e.scale, e.pos.z)
		var to := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var dist := maxf(to.length(), 0.001)
		e.los_t -= dt
		if e.los_t <= 0.0: e.los_t = 0.2 + randf() * 0.1; e.los = dist < 70.0 and Phys.line_of_sight(eye, eye_cam)
		e.no_los = 0.0 if e.los else e.no_los + dt
		var face_yaw := atan2(to.x, to.y); var mvx := 0.0; var mvz := 0.0
		if e.animal:
			animals.update(e, dt, _time, dist, face_yaw)
			if not e.alive: continue
			e.g.position = e.pos; e.g.rotation.y = e.yaw + e.yaw_off
			if e.hp < e.max_hp and not e.ridden:
				e.bar.visible = e.g.visible; e.bar.position = Vector3(e.pos.x, e.pos.y + e.H + 0.4 * e.scale, e.pos.z)
				var af := clampf(e.hp / e.max_hp, 0.0, 1.0); e.fill.scale.x = 0.86 * af; e.fill.position.x = -0.43 * (1.0 - af)
			continue
		var zombie := e.type == "zombie"
		if not e.alert:
			if (e.los and dist < (16.0 if zombie else 30.0)) or dist < (5.0 if zombie else 7.0) or (e.boss and dist < 24.0):
				alarm(e)
				for o in list:
					if not zombie and not o.alert and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 15.0: alarm(o)
			else:
				if e.idle_t <= 0.0 and not e.has_idle_yaw: e.idle_t = randf_range(2, 6)
				e.idle_t -= dt
				if e.idle_t <= 0.0: e.idle_t = randf_range(3, 7); e.idle_yaw = e.yaw + randf_range(-1.3, 1.3); e.has_idle_yaw = true
				var isp := 0.0
				if zombie and e.idle_t > 3.0: isp = 0.5; _ground_move(e, sin(e.yaw) * isp, cos(e.yaw) * isp, dt)   # milling about
				_turn_toward(e, e.idle_yaw if e.has_idle_yaw else e.yaw, 1.2, dt); _animate(e, isp, dt, false)
				e.g.position = e.pos; e.g.rotation.y = e.yaw
				continue
		if zombie:
			if not _zombie_skill(e, dt, dist, to): _zombie(e, dt, dist, to, face_yaw)
			e.g.position = e.pos; e.g.rotation.y = e.yaw
			if e.hp < e.max_hp:
				e.bar.visible = e.g.visible; e.bar.position = Vector3(e.pos.x, e.pos.y + e.H + 0.4 * e.scale, e.pos.z)
				var zf := clampf(e.hp / e.max_hp, 0.0, 1.0); e.fill.scale.x = 0.66 * zf; e.fill.position.x = -0.33 * (1.0 - zf)
			continue
		if e.state == "move":
			var fd := Phys.flow_dir(e.pos.x, e.pos.z)
			if fd != Vector2.ZERO: mvx = fd.x * e.speed; mvz = fd.y * e.speed
			else: mvx = to.x / dist * e.speed; mvz = to.y / dist * e.speed
			_turn_toward(e, face_yaw if (e.los and dist < 34.0) else atan2(mvx, mvz), 6.0, dt)
			if e.los and dist < e.K.range * (1.2 if e.boss else 1.0): e.state = "engage"; e.react = (0.15 if e.K.get("melee", false) else randf_range(0.45, 0.9)) * (1.0 - e.diff * 0.35)
		else:
			e.strafe_t -= dt
			if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = randf_range(0.9, 2.4)
			var fx := to.x / dist; var fz := to.y / dist
			var melee: bool = e.K.get("melee", false)
			if melee: var sp: float = e.K.get("run", 4.3) * (1.0 if dist > stop_dist(e) + 0.2 else 0.0); mvx = fx * sp; mvz = fz * sp
			elif e.K.get("still", false): mvx = 0.0; mvz = 0.0
			else:
				var fwd := 1.0 if dist > e.K.far else (-0.8 if dist < e.K.near else 0.0)
				mvx = (fx * fwd - fz * e.strafe * 0.6) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * 0.6) * e.speed * 0.55
			_turn_toward(e, face_yaw, 9.0 if melee else 7.0, dt)
			e.react -= dt
			if e.no_los > 1.6 or dist > e.K.range + 6.0:
				e.state = "move"; e.flame_on = 0.0
				if e.laser: e.laser.visible = false
			if e.react <= 0.0 and (e.los or melee) and e.alive and _fight(e, dt, dist): mvx *= 0.4; mvz *= 0.4
			if not e.alive: continue   # a bomber who has just gone off
		if e.vest_light: e.vest_light.visible = fmod(_time * (14.0 if e.fuse > 0.0 else 3.0) + e.walk, 1.0) < 0.45
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
			if (not a.awake and not b.awake) or a.downed or b.downed: continue
			var dx := b.pos.x - a.pos.x; var dz := b.pos.z - a.pos.z
			if absf(dx) > 5.0 or absf(dz) > 5.0: continue
			var d := sqrt(dx * dx + dz * dz); var m := a.R + b.R + 0.1
			if d < m and d > 0.001:
				var push := (m - d) * 0.5
				a.pos = Phys.move_xz(a.pos, -dx / d * push, -dz / d * push, a.R, a.H, 0.0)[0]; b.pos = Phys.move_xz(b.pos, dx / d * push, dz / d * push, b.R, b.H, 0.0)[0]
	for e in list:
		if e.alive and e.awake and not e.downed and animals.m == null and e.ghost_t <= 0.0: _keep_out(e)   # riding, the animal under you does the shoving
	if animals.m != null and animals.m.alive: animals.seat()
	for i in range(flying.size() - 1, -1, -1):   # helmets tumbling away
		var f: Array = flying[i]; f[2] += dt; f[1].y -= 12.0 * dt; var n: Node3D = f[0]
		n.position += (f[1] as Vector3) * dt; n.rotation.x += 10.0 * dt
		if n.position.y <= 0.2: n.position.y = 0.2; f[1] = Vector3(f[1].x * 0.6, absf(f[1].y) * 0.25, f[1].z * 0.6)
		if f[2] > 4.0: n.queue_free(); flying.remove_at(i)
	# the fallen tip over, lie a while, then sink away
	for i in range(dying.size() - 1, -1, -1):
		var e := dying[i]; e.dead_t += dt
		var t := minf(1.0, e.dead_t / 0.5); var ease := t * t * (3.0 - 2.0 * t)
		if e.vanish: e.g.scale = Vector3.ONE * maxf(0.001, 1.0 - e.dead_t / 0.45) * e.scale; e.dead_t = 99.0 if e.dead_t > 0.45 else e.dead_t
		else: e.g.rotation = Vector3(e.fall_dir * ease * 1.45, e.yaw, 0)
		if e.dead_t > 2.6: e.pos.y -= dt * 0.6; e.g.position = e.pos
		if e.dead_t > 3.4:
			e.g.queue_free(); e.bar.queue_free(); dying.remove_at(i)
			if e.laser: e.laser.queue_free()
