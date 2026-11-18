class_name Robots
extends RefCounted
## The ship's crew (stage 4): CCTV turrets on the ceiling, patrol bots with glow batons, little quad drones, spider mines hidden in the
## floor, the gold commander drone on the bridge, and the three-shell boss drone in the main hall; homing rockets, the boss's laser,
## the mines' blasts. Ported from src/07e_robots.js and src/07h_shipbots.js.

# shot: [min burst, max burst, seconds between bolts, damage, min pause, max pause]
const ROBOTS := {
	"cctv": {"name": "CCTV 포탑", "hp": 45, "speed": 0.0, "r": 0.3, "h": 0.45, "money": 500, "mode": "cctv", "sight": 30.0, "range": 32.0, "shot": [1, 1, 0.1, 4.0, 1.0, 1.6]},
	"patrol": {"name": "순찰 로봇", "hp": 160, "speed": 1.6, "r": 0.4, "h": 1.95, "money": 1000, "mode": "patrol", "sight": 26.0, "dmg": 60.0},
	"droneA": {"name": "드론", "hp": 1, "speed": 5.5, "r": 0.45, "h": 0.35, "money": 800, "mode": "droneA", "sight": 36.0, "range": 40.0, "shot": [2, 3, 0.16, 5.0, 1.1, 1.9]},
	"mine": {"name": "스파이더 마인", "hp": 1, "speed": 8.5, "r": 0.35, "h": 0.32, "money": 500, "mode": "mine", "sight": 7.5, "dmg": 100.0},
	"gdrone": {"name": "황금꿀벌드론", "hp": 5000, "speed": 4.2, "r": 1.3, "h": 1.6, "money": 1500, "mode": "gdrone", "sight": 34.0, "range": 42.0, "shot": [7, 9, 0.08, 13.0, 1.0, 1.6], "mid": true},
	"bdrone": {"name": "보스 드론", "hp": 9000, "speed": 5.0, "r": 2.5, "h": 5.0, "money": 2000, "mode": "bdrone", "sight": 60.0, "range": 70.0},
}
# the outline of each from above at scale 1 (x0, x1, z0, z1), measured in the browser game
const FEET := {"bdrone": [-2.975, 2.975, -2.731449, 2.394797], "gdrone": [-2.28, 2.28, -2.48, 0.992], "cctv": [-0.18, 0.18, -0.21, 0.52], "patrol": [-0.49, 0.49, -0.22, 0.52],
	"droneA": [-0.56, 0.56, -0.56, 0.56], "mine": [-0.553432, 0.553432, -0.610434, 0.610434]}
# the boss's three phases: speed, height over you, distance from you, seconds of aiming, how fast the aim follows, rockets in a salvo
# (and over how long), mines dropped, pause between attacks
const BPH := [{"sp": 5.0, "y": [8.0, 11.0], "dist": [16.0, 24.0], "charge": 3.0, "track": 7.0, "rockets": 1, "win": 0.0, "mines": 5, "gap": [4.2, 5.4]},
	{"sp": 8.0, "y": [6.0, 9.5], "dist": [12.0, 20.0], "charge": 2.0, "track": 9.0, "rockets": 10, "win": 1.0, "mines": 10, "gap": [3.2, 4.2]},
	{"sp": 12.0, "y": [3.2, 7.0], "dist": [8.0, 16.0], "charge": 1.0, "track": 12.0, "rockets": 100, "win": 2.5, "mines": 20, "gap": [2.4, 3.2]}]
const LASER_WARN := 3.0   # seconds of red eye before the aim starts
const SHELL_R := [2.5, 1.5, 0.75]
const MAX_ROCKETS := 220

var en: Enemies
var player: Player
var game = null
var world: World
var fx: Fx = null
var proj: Proj
var rockets: Array = []    # {p, v, dmg, life, see_t, sees}
var blasts: Array = []     # mines going off: {at, t}
var rocket_mm: MultiMeshInstance3D = null
var _rocket_mesh: CylinderMesh = null
var _rockets_drawn := 0
var aim_line: MeshInstance3D = null; var beam: MeshInstance3D = null; var beam_core: MeshInstance3D = null; var beam_t := 0.0
var _aim_mat: Material; var _beam_mat: Material; var _core_mat: Material; var _fx_clock := 0.0
var _mats := {}

func rnd(a: float, b: float) -> float: return randf_range(a, b)

func clear() -> void:
	rockets.clear(); blasts.clear(); beam_t = 0.0
	if aim_line != null and is_instance_valid(aim_line): aim_line.visible = false; beam.visible = false; beam_core.visible = false
	if rocket_mm != null and is_instance_valid(rocket_mm): rocket_mm.multimesh = null
	_rockets_drawn = 0

func _mat(key: String, color: Color, glow := false) -> StandardMaterial3D:
	if not _mats.has(key): _mats[key] = Gfx.unlit(color, false) if glow else Gfx.std(color, 0.42, 0.55)
	return _mats[key]

func _node(parent: Node3D, at: Vector3, parts: Array, key: String) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	if not parts.is_empty(): var mi := MeshInstance3D.new(); mi.mesh = en._box_mesh(key, parts); mi.material_override = en._mat; n.add_child(mi)
	return n

func _part(o: Vector3, r: float, weak := false) -> Dictionary: return {"o": o, "r": r, "mult": 1.0, "weak": weak, "bomb": false}
func shell_parts(R: float) -> Array: return [_part(Vector3.ZERO, R), _part(Vector3(0, 0, R * 0.9), R * 0.3, true)]

# ---- the browser game's buildShipBot: the same parts, colours and materials ----
func _kit() -> StandardMaterial3D:   # the plating: vertex colours on a semi-metal (three.js roughness 0.42, metalness 0.55)
	if not _mats.has("kit"): var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.roughness = 0.42; m.metallic = 0.55; _mats.kit = m
	return _mats.kit
func _basic(hex: String) -> StandardMaterial3D:   # a MeshBasicMaterial: lit by nothing, tone mapped
	if not _mats.has("b" + hex): _mats["b" + hex] = Gfx.unlit(World.lin(hex))
	return _mats["b" + hex]
func _kmesh(parent: Node3D, key: String, parts: Array, at := Vector3.ZERO) -> MeshInstance3D:   # merged plating parts; the hit flash shows on them
	if not en._meshes.has(key): en._meshes[key] = Gfx.kit_mesh(parts)
	var mi := MeshInstance3D.new(); mi.mesh = en._meshes[key]; mi.material_override = _kit(); mi.position = at; mi.set_meta("body", true); parent.add_child(mi); return mi
func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = at; parent.add_child(mi); return mi
func _grp(parent: Node3D, at := Vector3.ZERO) -> Node3D: var n := Node3D.new(); n.position = at; parent.add_child(n); return n
func _bx(sx: float, sy: float, sz: float) -> BoxMesh: var b := BoxMesh.new(); b.size = Vector3(sx, sy, sz); return b
func _see(hex: String, alpha: float, add := false, two_sided := false) -> Material:   # a see-through MeshBasicMaterial (no depth written)
	var m := Gfx.unlit(World.lin(hex)); m.albedo_color.a = alpha; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if two_sided: m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return Gfx.see_through(m)
func _shine(key: String, hex: String, rough: float, metal: float, env_k: float, map: Texture2D = null, emis := Color(0, 0, 0), two_sided := false) -> ShaderMaterial:
	if not _mats.has(key): _mats[key] = BotLook.shine(hex, rough, metal, env_k, map, emis, two_sided)
	return _mats[key]
## the boss's eye: blue and open, or red about to fire (shown as it is, without tone mapping); its glow follows
func eye_tint(e: Enemies.Foe, red: bool) -> void:
	var c := Color("ff1a10") if red else Color("1478ff"); (e.k.eye_mat as ShaderMaterial).set_shader_parameter("mul", Vector3(c.r, c.g, c.b))
	Gfx.tint(e.k.eye_glow, Color(World.lin("ff3a2a" if red else "2f8cff"), 0.34))

func build(e: Enemies.Foe, type: String) -> void:
	e.robot = true; e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; en.add_child(e.g)
	e.k = {"spin": 0.0, "seed": randf() * 10.0}
	match type:
		"cctv":   # a white camera on a short arm from the ceiling, a red eye in the lens and a small gun under it; it turns to follow you
			_kmesh(e.g, "s_cctv_arm", [[0.26, 0.04, 0.26, 0, 0.44, 0, "2a2f3a"], [0.06, 0.36, 0.06, 0, 0.26, 0, "3a4150"]])
			e.head = _grp(e.g)
			_kmesh(e.head, "s_cctv_cam", [[0.2, 0.16, 0.34, 0, 0, 0.02, "d5d9e0"], [0.25, 0.03, 0.42, 0, 0.095, 0.05, "bfc4cc"], [0.13, 0.13, 0.04, 0, 0, 0.2, "1c2028"], [0.045, 0.045, 0.24, 0, -0.105, 0.17, "1c2028"]])
			_add(e.head, _bx(0.06, 0.06, 0.02), _basic("ff2a2a"), Vector3(0, 0, 0.225))
			e.muzzle = Vector3(0, -0.105, 0.3); e.eye_h = 0.0; e.fly = true; e.bar_y = -0.45
			e.parts = [_part(Vector3(0, 0, 0.04), 0.21), _part(Vector3(0, 0, 0.21), 0.075, true)]
		"patrol":   # a security robot in white with orange bands, a yellow visor, and a long glow baton in its right hand
			var c1 := "d8dce4"; var c2 := "5a6170"; var c3 := "2a2f3a"; var band := "e8902a"
			for sx: float in [-1.0, 1.0]:
				var leg := _grp(e.g, Vector3(sx * 0.14, 0.95, 0)); _kmesh(leg, "s_pleg", [[0.18, 0.92, 0.2, 0, -0.46, 0, c2], [0.22, 0.12, 0.34, 0, -0.9, 0.06, c3], [0.2, 0.07, 0.22, 0, -0.42, 0.02, band]])
				if sx < 0: e.leg_l = leg
				else: e.leg_r = leg
			e.upper = _grp(e.g, Vector3(0, 0.95, 0))
			_kmesh(e.upper, "s_pupper", [[0.52, 0.6, 0.32, 0, 0.36, 0, c1], [0.54, 0.08, 0.34, 0, 0.5, 0, band], [0.2, 0.14, 0.3, -0.34, 0.66, 0, c2], [0.2, 0.14, 0.3, 0.34, 0.66, 0, c2],
				[0.12, 0.08, 0.12, 0, 0.71, 0, c3], [0.3, 0.26, 0.3, 0, 0.87, 0, c1], [0.32, 0.05, 0.32, 0, 1.0, 0, band], [0.03, 0.22, 0.03, 0.1, 1.08, -0.05, c3]])
			_add(e.upper, _bx(0.24, 0.06, 0.02), _basic("ffd23a"), Vector3(0, 0.88, 0.155))
			e.arm_l = _grp(e.upper, Vector3(-0.34, 0.6, 0)); _kmesh(e.arm_l, "s_parm", [[0.13, 0.6, 0.15, 0, -0.29, 0, c2], [0.12, 0.12, 0.12, 0, -0.62, 0, c3]])
			e.arm_r = _grp(e.upper, Vector3(0.34, 0.6, 0)); _kmesh(e.arm_r, "s_parm_r", [[0.13, 0.6, 0.15, 0, -0.29, 0, c2], [0.12, 0.12, 0.12, 0, -0.62, 0, c3], [0.05, 0.16, 0.05, 0, -0.74, 0.03, "2a2a2a"]])
			_add(e.arm_r, BotLook.cyl(0.035, 0.035, 0.66, 8), _basic("d8ff7a"), Vector3(0, -1.14, 0.03))
			if not _mats.has("baton_glow"): _mats.baton_glow = _see("8aff3a", 0.38, true)
			_add(e.arm_r, BotLook.cyl(0.085, 0.085, 0.72, 8), _mats.baton_glow, Vector3(0, -1.14, 0.03))
			e.parts = [_part(Vector3(0, 1.81, 0), 0.17, true), _part(Vector3(0, 1.33, 0), 0.33), {"o": Vector3(0, 0.98, 0), "r": 0.25, "mult": 0.9, "weak": false, "bomb": false}, {"o": Vector3(0, 0.5, 0), "r": 0.26, "mult": 0.7, "weak": false, "bomb": false}]
			e.eye_h = 1.82
		"droneA":   # a little quadcopter: a flat body, arms out to the four corners with a propeller on each, a red eye under the nose
			_kmesh(e.g, "s_drone", [[0.42, 0.12, 0.42, 0, 0, 0, "cfd4dc"], [0.3, 0.1, 0.3, 0, -0.1, 0.02, "2a2f3a"], [0.84, 0.04, 0.06, 0, 0.02, 0, "3a4150", [0, PI / 4, 0]],
				[0.84, 0.04, 0.06, 0, 0.02, 0, "3a4150", [0, -PI / 4, 0]], [0.05, 0.08, 0.18, 0, -0.16, 0.16, "1c2028"]])
			e.k.rotors = []
			for q in [[0.3, 0.3], [-0.3, 0.3], [0.3, -0.3], [-0.3, -0.3]]:
				_kmesh(e.g, "s_hub", [[0.08, 0.07, 0.08, 0, 0, 0, "2a2f3a"]], Vector3(q[0], 0.05, q[1]))
				var ro := _grp(e.g, Vector3(q[0], 0.1, q[1])); _kmesh(ro, "s_rotor", [[0.42, 0.012, 0.05, 0, 0, 0, "1c2028"], [0.05, 0.012, 0.42, 0, 0, 0, "1c2028"]]); e.k.rotors.push_back(ro)
			_add(e.g, _bx(0.08, 0.05, 0.03), _basic("ff2a2a"), Vector3(0, -0.13, 0.25))
			e.muzzle = Vector3(0, -0.16, 0.28); e.eye_h = 0.0; e.fly = true; e.bar_y = 0.5
			e.parts = [_part(Vector3.ZERO, 0.34), _part(Vector3(0, -0.12, 0.2), 0.1, true)]
		"mine":   # a squat dark disc with six folded legs and a dim red eye; it lies buried flush with the floor until something comes close
			e.body = _grp(e.g)
			_kmesh(e.body, "s_mine", [[0.56, 0.14, 0.56, 0, 0.1, 0, "24282f", null, false, true], [0.4, 0.08, 0.4, 0, 0.19, 0, "30353e", null, false, true], [0.62, 0.03, 0.62, 0, 0.06, 0, "1a1d22"]])
			var lm := Gfx.unlit(World.lin("401010")); _add(e.body, _bx(0.07, 0.03, 0.07), lm, Vector3(0, 0.235, 0.06)); e.k.light = lm
			e.k.cl = []
			for i in 6:
				var a := (i / 6.0) * TAU + 0.5; var lp := _grp(e.g, Vector3(cos(a) * 0.24, 0.1, sin(a) * 0.24)); lp.rotation_order = EULER_ORDER_YXZ; lp.rotation.y = -a
				_kmesh(lp, "s_mine_leg", [[0.3, 0.04, 0.05, 0.15, 0, 0, "3a4150"], [0.04, 0.22, 0.04, 0.3, -0.1, 0, "2a2f3a"]]); e.k.cl.push_back(lp)
			e.parts = [_part(Vector3(0, 0.12, 0), 0.3)]; e.eye_h = 0.3; e.bar_y = 0.7
		"gdrone":   # the commander, a golden bee: a hull in polished gold, a red visor, two engines, twin cannons, eyes, feelers, a striped tail
			# (its gold's and its eyes' emissive glow: the browser game sets them, then spawning clears every one of the robot's materials'
			# emissive to black (Enemies.spawn); the eyes glow again only from its first charge)
			var gold := _shine("gold", "d99a1e", 0.14, 1.0, 1.25)
			var gm := func(mesh: Mesh, at: Vector3, sc := Vector3.ONE) -> MeshInstance3D: var mi := _add(e.g, mesh, gold, at); mi.scale = sc; return mi
			gm.call(BotLook.sphere(1, 28, 16), Vector3.ZERO, Vector3(1.25, 0.62, 1.05))
			gm.call(BotLook.sphere(0.55, 20, 10, 0, TAU, 0, PI / 2), Vector3(0, 0.32, -0.1))
			gm.call(_bx(0.07, 0.42, 0.9), Vector3(0, 0.78, -0.15))
			for sx: float in [-1.0, 1.0]:
				var nac: MeshInstance3D = gm.call(BotLook.cyl(0.3, 0.24, 1.35, 16), Vector3(sx * 1.3, -0.05, -0.05)); nac.rotation.x = PI / 2
				var th := _add(e.g, BotLook.disc(0.2, 16), _basic("6fc8ff"), Vector3(sx * 1.3, -0.05, -0.74)); th.rotation.y = PI
			_kmesh(e.g, "s_bee_kit", [[0.13, 0.13, 0.95, -0.38, -0.46, 0.55, "1c2028"], [0.13, 0.13, 0.95, 0.38, -0.46, 0.55, "1c2028"], [0.9, 0.12, 0.3, 0, -0.4, 0.15, "2a2f3a"],
				[0.03, 0.6, 0.03, -0.35, 0.75, -0.4, "2a2f3a"], [0.03, 0.45, 0.03, 0.35, 0.68, -0.4, "2a2f3a"]])
			_add(e.g, _bx(0.95, 0.12, 0.05), _basic("ff3a2a"), Vector3(0, 0.06, 1.02))
			var eye_m := BotLook.shine("1c0d06", 0.12, 0.4, 1.4); e.k.bee_eye = eye_m   # (its own: it glows as the bee winds up to charge)
			if not _mats.has("feeler"): _mats.feeler = Gfx.std(World.lin("241a0c"), 0.6)
			for sx: float in [-1.0, 1.0]:
				var ey := _add(e.g, BotLook.sphere(0.36, 18, 12), eye_m, Vector3(sx * 0.55, 0.16, 0.78)); ey.scale = Vector3(0.75, 1.15, 0.85)
				var an := _add(e.g, BotLook.cyl(0.025, 0.025, 0.85, 6), _mats.feeler, Vector3(sx * 0.22, 0.86, 0.86)); an.rotation_order = EULER_ORDER_XYZ; an.rotation = Vector3(0.7, 0, -sx * 0.35)
				gm.call(BotLook.sphere(0.07, 8, 6), Vector3(sx * 0.36, 1.2, 1.12))
			gm.call(BotLook.sphere(1, 24, 14), Vector3(0, -0.04, -1.3), Vector3(0.95, 0.8, 1.25))
			if not _mats.has("bee_band"): _mats.bee_band = Gfx.std(World.lin("15100a"), 0.35, 0.5)
			for q in [[-0.95, 0.88], [-1.35, 0.95], [-1.78, 0.78]]:
				var bd := _add(e.g, BotLook.cyl(q[1], q[1], 0.2, 24, true), _mats.bee_band, Vector3(0, -0.04, q[0])); bd.rotation.x = PI / 2; bd.scale = Vector3(1.01, 1, 0.85)
			var sting := _add(e.g, BotLook.cyl(0.0, 0.16, 0.6, 10), _mats.bee_band, Vector3(0, -0.08, -2.75)); sting.rotation.x = -PI / 2
			# four see-through wings that beat: an ellipse 2.5 x 0.84 lying flat, reaching out from its root
			if not _mats.has("wing"): _mats.wing = _see("dcecff", 0.38, false, true)
			if not en._meshes.has("s_wing"):
				var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.append_from(BotLook.disc(1, 20), 0, Transform3D(Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(1.25, 0.42, 1)), Vector3(1.15, 0, -0.15))); en._meshes.s_wing = st.commit()
			e.k.wings = []
			for sx: float in [-1.0, 1.0]:
				for q in [[0.15, 1.0], [-0.45, 0.78]]:
					var wg := _grp(e.g, Vector3(sx * 0.4, 0.62, q[0])); var wm := _add(wg, en._meshes.s_wing, _mats.wing, Vector3.ZERO); wm.scale = Vector3(sx * q[1], 1, q[1]); e.k.wings.push_back({"g": wg, "sx": sx})
			e.muzzle = Vector3(0.38, -0.46, 1.08); e.eye_h = 0.0; e.fly = true; e.bar_y = 1.8
			e.parts = [_part(Vector3.ZERO, 1.12), _part(Vector3(0, 0.06, 0.98), 0.24, true), _part(Vector3(0, 0, -1.3), 0.95)]
		_:   # the boss: three shells, one inside the other (5 m and 3 m armoured, the 1.5 m white core); the eye looks out of every one
			var white := _shine("b_white", "eef1f6", 0.22, 0.3, 1.2, BotLook.shell_tex()); var armor := _shine("b_armor", "9aa4b6", 0.33, 0.65, 1.0)
			if not _mats.has("b_dark"): _mats.b_dark = Gfx.std(World.lin("1a1f28"), 0.4, 0.5); var sk := Gfx.std(World.lin("10141c"), 0.6, 0.4); sk.cull_mode = BaseMaterial3D.CULL_DISABLED; _mats.b_sock = sk
			var dark: StandardMaterial3D = _mats.b_dark; var lens := _shine("b_lens", "0a1428", 0.12, 0.7, 1.1); var lights := _basic("3a9cff")
			var ex := Gfx.exposure(float(World.STAGE_STYLE[4].get("exposure", 1.15)))
			e.k.eye_mat = Gfx.untoned(Color("1478ff"), BotLook.iris_tex(), ex); var pupil := Gfx.untoned(Color("d8ecff"), null, ex)
			var glow := StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow.albedo_texture = BotLook.pool_tex(); glow.albedo_color = Color(World.lin("2f8cff"), 0.34)
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; e.k.eye_glow = Gfx.see_through(glow)
			e.k.shells = []
			var HOLE := asin(0.46)
			for k in 3:
				var R: float = SHELL_R[k]; var s := _grp(e.g)
				# a sphere with a round opening (the top cap left off, turned to face forward)
				if not en._meshes.has("s_shell%d" % k):
					var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.append_from(BotLook.sphere(R, 44, 26, 0, TAU, HOLE, PI - HOLE), 0, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)); en._meshes["s_shell%d" % k] = st.commit()
				_add(s, en._meshes["s_shell%d" % k], white, Vector3.ZERO)
				# in the opening: a dark socket, a white rim, a dark lens ring, the iris (blue, open) and a bright core, set back a little
				var eye := _grp(s, Vector3(0, 0, R * 0.9)); var rim_z := cos(HOLE) * R - R * 0.9
				var sock := _add(eye, BotLook.cyl(R * 0.46, R * 0.46, R * 0.16, 40, true), _mats.b_sock, Vector3(0, 0, rim_z - R * 0.08)); sock.rotation.x = PI / 2
				_add(eye, BotLook.disc(R * 0.46, 40), dark, Vector3(0, 0, rim_z - R * 0.16))
				_add(eye, BotLook.torus(R * 0.455, R * 0.04, 10, 44), white, Vector3(0, 0, rim_z))
				_add(eye, BotLook.disc(R * 0.4, 40), lens, Vector3(0, 0, rim_z - R * 0.12))
				_add(eye, BotLook.torus(R * 0.36, R * 0.028, 8, 40), dark, Vector3(0, 0, rim_z - R * 0.11))
				_add(eye, BotLook.disc(R * 0.33, 40), e.k.eye_mat, Vector3(0, 0, rim_z - R * 0.1))
				_add(eye, BotLook.disc(R * 0.085, 24), pupil, Vector3(0, 0, rim_z - R * 0.095))
				var gq := QuadMesh.new(); gq.size = Vector2.ONE * R * 1.15; _add(eye, gq, glow, Vector3(0, 0, rim_z + R * 0.05))
				# light strips round the middle and under the belly
				for a: float in [-2.5, -1.8, -1.05, 1.05, 1.8, 2.5]: var lb := _add(s, _bx(R * 0.36, R * 0.05, R * 0.04), lights, Vector3(sin(a) * R, 0, cos(a) * R)); lb.rotation.y = a + PI / 2
				for a: float in [-0.6, 0.0, 0.6]: var lb2 := _add(s, _bx(R * 0.32, R * 0.04, R * 0.05), lights, Vector3(sin(a) * R * 0.62, -R * 0.78, cos(a) * R * 0.62)); lb2.rotation_order = EULER_ORDER_XYZ; lb2.rotation = Vector3(0.9, a, 0)
				if k < 2:   # armour: plates over the shell (never over the eye), rocket pods on both flanks, fins on top of the big one
					var np := 10 if k == 0 else 6
					for i in np:
						var th := (float(i) / np) * TAU + 0.3; var ph := 0.55 if i % 2 else -0.45; var d := Vector3(sin(th) * cos(ph), sin(ph), cos(th) * cos(ph))
						if d.z > 0.55 and absf(d.y) < 0.6: continue
						var xa := Vector3.UP.cross(d).normalized(); var plate := _add(s, _bx(R * 0.62, R * 0.46, R * 0.1), armor, d * R * 0.98); plate.basis = Basis(xa, d.cross(xa), d)   # (its face turned outward)
					for sx: float in [-1.0, 1.0]:
						_add(s, _bx(R * 0.3, R * 0.5, R * 0.7), armor, Vector3(sx * R * 1.02, 0.05 * R, 0))
						for j in 4: _add(s, BotLook.disc(R * 0.06, 12), dark, Vector3(sx * R * 1.02 + (0.07 if j % 2 else -0.07) * R, (0.17 if j < 2 else -0.12) * R, R * 0.36 + 0.002))
					if k == 0:
						for sx: float in [-1.0, 1.0]: _add(s, _bx(R * 0.05, R * 0.4, R * 0.6), armor, Vector3(sx * R * 0.25, R * 0.98, -R * 0.1))
				s.visible = k == 0
				e.k.shells.push_back({"g": s, "R": R, "eye": eye})
			e.no_far = true; e.fly = true; e.eye_h = 0.0; e.bar_y = 3.2; e.parts = shell_parts(2.5); e.boss_guard = true   # (never drawn baked, as there)
	e.bar = Node3D.new(); e.bar.visible = false; en.add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = en._bar_mesh; e.fill.material_override = _mat("bar", Color("8ec8ff"), true).duplicate(); e.fill.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; e.fill.material_override.billboard_keep_scale = true
	e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)

# ---------------- shared ----------------
func _turn(e: Enemies.Foe, yaw: float, rate: float, dt: float) -> void: en._turn_toward(e, yaw, rate, dt)

func call_near(e: Enemies.Foe, r: float) -> void:
	for o in en.list:
		if o.robot and not o.alert and o != e and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < r: en.alarm(o)

## the way towards you on foot: straight when it sees you, along the walking grid when it does not
func _dir(e: Enemies.Foe, dist: float, to: Vector2, near: float) -> Vector2:
	if dist < near and e.los: return to / dist
	var fd := Phys.flow_dir(e.pos.x, e.pos.z)
	return fd if fd != Vector2.ZERO else to / dist

## bolts in bursts at you
func fire(e: Enemies.Foe, dt: float, dist: float) -> bool:
	var S: Array = e.T.shot; e.fire_t -= dt
	if e.burst > 0:
		e.burst_t -= dt
		if e.burst_t <= 0.0:
			e.burst -= 1; e.burst_t = S[2]; var mz := en.muzzle_of(e)
			var aim := Vector3(player.pos.x + player.vel.x * dist / 110.0, player.pos.y + 1.25, player.pos.z + player.vel.z * dist / 110.0)
			proj.bullet(mz, aim, 62.0, S[3] * e.dmg_mul, 0.3 + dist * 0.024 + player.speed_xz * 0.07 - (0.12 if e.boss else 0.0)); Snd.play("zap", 1.0, mz)
		return true
	if e.fire_t <= 0.0: e.burst = randi_range(S[0], S[1]); e.burst_t = 0.0; e.fire_t = rnd(S[4], S[5])
	return false

func _walk(e: Enemies.Foe, sp: float, dt: float) -> void:
	e.walk += dt * sp * 2.4; var s := sin(e.walk) * minf(1.0, sp / 2.0) * 0.55
	e.leg_l.rotation.x = s; e.leg_r.rotation.x = -s; e.arm_r.rotation = Vector3(-s * 0.6, 0, 0); e.arm_l.rotation = Vector3(s * 0.6, 0, 0)
	e.flinch = maxf(0.0, e.flinch - dt * 5.0); e.upper.rotation.x = -e.flinch * 0.2

func update(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	e.k.spin += dt
	match e.type:
		"cctv": _cctv(e, dt, dist, face_yaw)
		"patrol": _patrol(e, dt, dist, to, face_yaw)
		"droneA": _drone(e, dt, dist, to, face_yaw)
		"mine": _mine(e, dt, dist, to)
		"gdrone": _bee(e, dt, dist, to, face_yaw)
		_: _boss(e, dt, dist, face_yaw)

# ---------------- CCTV: watches and sweeps; once it has you it follows you and shoots weak single bolts ----------------
func _cctv(e: Enemies.Foe, dt: float, dist: float, face_yaw: float) -> void:
	var seen: bool = e.los and dist < e.T.sight
	if not e.alert and seen: en.alarm(e); call_near(e, 22.0)
	if e.alert and seen:
		_turn(e, face_yaw, 3.0, dt)
		var dy := player.pos.y + 1.3 - e.pos.y; e.head.rotation.x = lerpf(e.head.rotation.x, clampf(-atan2(dy, dist), -0.3, 1.3), 1.0 - exp(-dt * 6.0))
		e.react -= dt
		if e.react <= 0.0: fire(e, dt, dist)
	else:
		e.yaw += sin(e.k.spin * 0.5 + e.k.seed) * dt * 0.6; e.head.rotation.x = lerpf(e.head.rotation.x, 0.45, 1.0 - exp(-dt))
		if e.alert: e.react = maxf(e.react, 0.4)

# ---------------- patrol bot: walks its beat; seen, it runs you down and swings the baton (60) ----------------
func _patrol(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var T := e.T; var k := e.k
	if not e.alert and e.los and dist < T.sight:
		var a := face_yaw - e.yaw; a = atan2(sin(a), cos(a))
		if absf(a) < 1.3 or dist < 6.0: en.alarm(e); call_near(e, 16.0); Snd.play("zap_turret", 1.0, e.pos)
	if not e.alert:
		var sp := 0.0
		if k.has("wp"):
			var w: Vector2 = k.wp[k.wi]; var dx := w.x - e.pos.x; var dz := w.y - e.pos.z; var l := sqrt(dx * dx + dz * dz)
			if k.waitT > 0.0: k.waitT -= dt; _turn(e, e.yaw + sin(k.waitT * 2.2) * 0.6, 1.4, dt)
			elif l < 0.6: k.wi = 1 - int(k.wi); k.waitT = rnd(1.2, 2.4)
			else: sp = T.speed; _turn(e, atan2(dx, dz), 3.0, dt); en._ground_move(e, dx / l * sp, dz / l * sp, dt)
		_walk(e, sp, dt); e.arm_r.rotation = Vector3(-0.35 - sin(e.walk) * 0.1, 0, -0.1)
		return
	var sd := en.stop_dist(e); var d := _dir(e, dist, to, 22.0)
	e.swing_cd -= dt; var sp2 := 5.8 if dist > sd + 0.15 else 0.0
	if e.swing_t > 0.0:
		e.swing_t -= dt; sp2 *= 0.3; var u := 1.0 - e.swing_t / 0.5
		e.arm_r.rotation = Vector3(-0.6 - u * 4.6 if u < 0.5 else -2.9 + (u - 0.5) * 4.4, 0, -0.15)   # up over its head, then down hard
		if not e.hit_done and u >= 0.62:
			e.hit_done = true; Snd.play("swoosh", 1.0, e.pos)
			if dist < sd + 1.2 and absf(player.pos.y - e.pos.y) < 1.8: player.hurt(T.dmg * e.dmg_mul, e.pos, "body"); Snd.play("bat_hit", 1.0, e.pos); player.vel.x += to.x / dist * 4.0; player.vel.z += to.y / dist * 4.0
	elif dist < sd + 0.8 and e.swing_cd <= 0.0: e.swing_t = 0.5; e.swing_cd = 1.15; e.hit_done = false
	_turn(e, face_yaw if dist < 10.0 else atan2(d.x, d.y), 7.0, dt)
	e.vel *= exp(-dt * 6.0); en._ground_move(e, d.x * sp2 + e.vel.x, d.y * sp2 + e.vel.z, dt)
	var keep := e.arm_r.rotation; _walk(e, sp2, dt)
	e.arm_r.rotation = keep if e.swing_t > 0.0 else Vector3(-0.95, 0, -0.15)   # baton up and ready

# ---------------- drone A: drifts about; once it has seen you it hangs over you, slides about and shoots small bolts ----------------
func _drone(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var T := e.T; var k := e.k; var ceil := Ship.ceil_at(e.pos.x, e.pos.z) - 0.9
	for ro: Node3D in k.get("rotors", []): ro.rotation.y += dt * 42.0
	if not e.alert:
		if (e.los and dist < T.sight) or dist < 8.0: en.alarm(e); call_near(e, 18.0)
		else:
			k.goalT = float(k.get("goalT", 0.0)) - dt
			if not k.has("goal") or k.goalT <= 0.0 or Vector2(k.goal.x - e.pos.x, k.goal.z - e.pos.z).length() < 1.5:
				var Rm := Ship.room_at(e.pos.x, e.pos.z)
				if Rm.is_empty(): Rm = Ship.ROOMS[2]
				k.goalT = rnd(3, 7); k.goal = Vector3(rnd(Rm[0] + 3, Rm[2] - 3), rnd(3.5, minf(10.0, Rm[4] - 1.5)), rnd(Rm[1] + 3, Rm[3] - 3))
			var dx: float = k.goal.x - e.pos.x; var dz: float = k.goal.z - e.pos.z; var l := maxf(sqrt(dx * dx + dz * dz), 0.001)
			var res := Phys.move_xz(e.pos, dx / l * 2.2 * dt, dz / l * 2.2 * dt, e.R, e.H, 0.8); e.pos = res[0]
			if res[1]: k.goalT = 0.0
			e.pos.y += (minf(k.goal.y, ceil) - e.pos.y) * (1.0 - exp(-dt)); _turn(e, atan2(dx, dz), 2.0, dt); e.g.rotation.x = 0.08
			return
	# no lower than 1.8 m over the floor under it (down in the hall's pit too), no higher than 22 m
	var lo := 2.4 if Phys.PIT == null else Phys.ground_at(e.pos.x, e.pos.y + 0.3, e.pos.z, e.R) + 1.8
	var ty := minf(clampf(player.pos.y + 4.0 + sin(k.spin * 1.3 + k.seed) * 1.2, lo, 22.0), ceil)
	e.pos.y += (ty - e.pos.y) * (1.0 - exp(-dt * 1.4))
	e.strafe_t -= dt
	if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = rnd(1.4, 3)
	var f := to / dist; var fd := Phys.flow_dir(e.pos.x, e.pos.z)
	if not e.los and fd != Vector2.ZERO: f = fd
	var fwd := 1.0 if (not e.los or dist > 15.0) else (-0.7 if dist < 8.0 else 0.0); var side := 0.8 if e.los else 0.0
	var mvx: float = (f.x * fwd - f.y * e.strafe * side) * T.speed; var mvz: float = (f.y * fwd + f.x * e.strafe * side) * T.speed
	e.vel *= exp(-dt * 3.0)
	var res2 := Phys.move_xz(e.pos, (mvx + e.vel.x) * dt, (mvz + e.vel.z) * dt, e.R, e.H, 0.0 if Phys.PIT == null else 0.8); e.pos = res2[0]
	if res2[1]: e.strafe *= -1.0
	_turn(e, face_yaw, 4.0, dt); e.g.rotation.x = clampf(fwd * 0.18, -0.2, 0.2); e.react -= dt
	if e.los and dist < T.range and e.react <= 0.0: fire(e, dt, dist)

# ---------------- spider mine: buried in the floor; you come within reach and it springs up, scuttles at you and goes off (100).
# one bullet sets it off too ----------------
func _light(e: Enemies.Foe, hex: String) -> void: (e.k.light as StandardMaterial3D).albedo_color = World.lin(hex)   # (a MeshBasicMaterial's colour)
## its legs: folded flat while it lies buried, scuttling when it is up; the body bobs as it runs
func _mine_legs(e: Enemies.Foe, dt: float, sp: float) -> void:
	e.walk += dt * (4.0 + sp * 3.0); var up := not (e.bs == "hidden" or e.bs == "arm" or e.bs == "fall")
	var cl: Array = e.k.get("cl", [])
	for i in cl.size(): (cl[i] as Node3D).rotation.z = -0.15 + sin(e.walk + i * 1.7) * 0.35 * minf(1.0, sp / 4.0) if up else -0.75
	if e.body: e.body.position.y = absf(sin(e.walk * 2.0)) * 0.03 if up else 0.0

func _mine(e: Enemies.Foe, dt: float, dist: float, to: Vector2) -> void:
	var T := e.T; var k := e.k
	match e.bs:
		"fall":   # thrown out by the boss: arcing down to the floor
			e.vy -= 18.0 * dt; e.pos += Vector3(e.vel.x, e.vy, e.vel.z) * dt
			var gy := Phys.ground_at(e.pos.x, e.pos.y + 0.3, e.pos.z, 0.2)
			if e.pos.y <= gy and e.vy < 0.0: e.pos.y = gy; k.baseY = gy; e.bs = "arm"; e.bt = 1.0; e.vel = Vector3.ZERO; Snd.play("metal", 1.0, e.pos); _puff(e.pos, 2, 0.3, 0.3)
			_mine_legs(e, dt, 0.0)
		"arm":   # landed: blinking while it arms itself
			e.bt -= dt; _light(e, "ff3020" if sin(e.bt * 30.0) > 0.0 else "401010")
			if e.bt <= 0.0:
				if dist < 9.0: e.bs = "wake"; e.bt = 0.3; Snd.play("chirp", 1.0, e.pos)
				else: e.bs = "hidden"; _light(e, "401010")
			_mine_legs(e, dt, 0.0)
		"hidden":
			e.pos.y = float(k.baseY) - 0.16
			if dist < T.sight and (e.los or dist < 3.5) and absf(player.pos.y - float(k.baseY)) < 2.5: e.bs = "wake"; e.bt = 0.3; Snd.play("chirp", 1.0, e.pos)
			_mine_legs(e, dt, 0.0)
		"wake":
			e.bt -= dt; e.pos.y = float(k.baseY) - 0.16 * maxf(0.0, e.bt / 0.3); _light(e, "ff2a1a")
			if e.bt <= 0.0: e.bs = "run"; e.bt = 7.0; e.alert = true
			_turn(e, atan2(to.x, to.y), 10.0, dt); _mine_legs(e, dt, 2.0)
		_:   # running at you
			e.bt -= dt; var d := _dir(e, dist, to, 12.0)
			en._ground_move(e, d.x * T.speed, d.y * T.speed, dt); _turn(e, atan2(d.x, d.y), 12.0, dt); _light(e, "ff2a1a" if fmod(e.bt * 8.0, 1.0) < 0.5 else "601010"); _mine_legs(e, dt, T.speed)
			if (dist < 1.25 and absf(player.pos.y - e.pos.y) < 1.6) or e.bt <= 0.0: en.detonate(e)

## a mine goes off: 100 to anyone close, crates break, other mines go with it
func mine_blast(at: Vector3, delay: float) -> void: blasts.push_back({"at": Vector3(at.x, at.y + 0.25, at.z), "t": delay})

func _blast(c: Vector3) -> void:
	if fx: fx.explode(c, false)
	Snd.play("boom_small", 1.0, c); en.noise(c, 30.0)
	var d := Vector3(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z).length()
	player.shake = maxf(player.shake, clampf(0.6 - d * 0.05, 0.0, 0.6))
	if d < 3.5 and Phys.line_of_sight(c, Vector3(player.pos.x, player.pos.y + 1.0, player.pos.z)): player.hurt(100.0 if d < 2.0 else roundf(100.0 * (1.0 - (d - 2.0) / 1.5)), c, "body")
	for cr in world.crates.duplicate():
		if not cr.dead and Vector3(cr.x - c.x, cr.y + 0.6 - c.y, cr.z - c.z).length() < 2.6: world.damage_crate(cr, 100.0, Vector3(cr.x, cr.y + 0.6, cr.z))
	en.splash(c, 3.0, 100.0)   # other mines go off in a chain

# ---------------- the gold commander drone, a golden bee: wakes the whole corridor when it sees you, shoots its twin cannons,
# and between bursts either calls little quad drones out of its belly or winds up and rams you (220 and a hard shove) ----------------
func _bee_drones(e: Enemies.Foe) -> int:
	var live := 0
	for o in en.list:
		if o.alive and o.from_bee: live += 1
	var n := mini(8 if e.rage else 6, 18 - live)
	if n <= 0: return 0
	for i in n:
		var a := (float(i) / n) * TAU + rnd(-0.3, 0.3); var mn := en.spawn("droneA", e.pos.x + cos(a) * 1.6, e.pos.z + sin(a) * 1.6, {"y": e.pos.y - 0.6, "yaw": e.yaw})
		mn.from_bee = true; mn.alert = true; mn.awake = true; mn.lod = 0.0; mn.vel = Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)
	game.goal += n
	if fx: fx.puff(Vector3(e.pos.x, e.pos.y - 0.5, e.pos.z), 6, 0.7, 0.6)
	Snd.play("spawn", 1.0, e.pos); game.say_feed("황금꿀벌드론이 드론 %d대를 불러냈습니다" % n)
	return n

func _bee_eye(e: Enemies.Foe, c: Color) -> void:   # three.js's emissive on the bee's eyes (linear)
	if e.k.has("bee_eye"): (e.k.bee_eye as ShaderMaterial).set_shader_parameter("emis", Vector3(c.r, c.g, c.b))
func _bee(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var T := e.T; var k := e.k
	if not k.has("baseY"): k.baseY = e.pos.y
	# wings beating all the time, faster when it is roused
	var wf := sin(k.spin * (46.0 if e.alert else 30.0))
	for W in k.get("wings", []): (W.g as Node3D).rotation.z = W.sx * (0.18 + wf * 0.42)
	if e.sealed: e.pos.y = float(k.baseY) + sin(k.spin * 1.2) * 0.15; e.g.rotation.z = sin(k.spin * 0.8) * 0.03; return   # behind its shut door: deaf and blind to you
	if not e.alert:
		e.pos.y = float(k.baseY) + sin(k.spin * 1.2) * 0.15; e.g.rotation.z = sin(k.spin * 0.8) * 0.03
		if (e.los and dist < T.sight) or dist < 10.0:
			en.alarm(e); Snd.play("alarm"); var n := 0
			for o in en.list:
				if o.robot and not o.alert and o != e and not o.boss and o.type != "mine" and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 75.0: en.alarm(o); n += 1
			game.say_feed("황금꿀벌드론이 경보를 울렸습니다 · 로봇 %d대가 몰려옵니다" % n)
		else: return
	var Rm: Array = Ship.ROOMS[0]
	if not e.rage and e.hp < e.max_hp * 0.5: e.rage = true; game.say_feed("황금꿀벌드론이 분노했습니다 · 더 빠르고 자주 돌진합니다")
	# the charge: a wind-up (shaking), then straight at where you stood; a wall or a hit ends it, and it hangs there a second
	if k.has("dash"):
		var D: Dictionary = k.dash; D.t += dt
		if D.mode == "wind":
			e.pos.x += rnd(-1, 1) * 0.04; e.pos.y += rnd(-1, 1) * 0.03; _turn(e, atan2(D.at.x - e.pos.x, D.at.z - e.pos.z), 6.0, dt); _bee_eye(e, Color(1.2, 0.2, 0.0) * D.t)
			if D.t >= 0.75: D.mode = "go"; D.t = 0.0; D.v = (D.at - e.pos).normalized(); Snd.play("swoosh", 1.0, e.pos)
			return
		if D.mode == "go":
			var sp := 32.0 if e.rage else 26.0; var v: Vector3 = D.v; e.g.rotation.x = 0.25
			var res := Phys.move_xz(e.pos, v.x * sp * dt, v.z * sp * dt, e.R * 0.8, 1.0, 0.0); e.pos = res[0]; e.pos.y = clampf(e.pos.y + v.y * sp * dt, 1.6, Ship.ceil_at(e.pos.x, e.pos.z) - 1.4)
			var pdx := player.pos.x - e.pos.x; var pdz := player.pos.z - e.pos.z; var py := clampf(e.pos.y, player.pos.y + 0.3, player.pos.y + Player.HEIGHT - 0.2)
			if not D.hit and Vector3(pdx, e.pos.y - py, pdz).length() < e.R + 0.7:
				D.hit = true; player.hurt(220.0, e.pos, "body"); Snd.play("thud", 1.0, player.pos); Snd.play("metal", 1.0, player.pos); Snd.buzz(160)
				var l := maxf(sqrt(pdx * pdx + pdz * pdz), 0.001); player.vel.x += pdx / l * 13.0; player.vel.z += pdz / l * 13.0; player.vel.y = 4.5; player.grounded = false; player.shake = maxf(player.shake, 0.7)
			if res[1] or D.hit or D.t > 1.5:
				D.mode = "rest"; D.t = 0.0
				if res[1]:
					Snd.play("thud", 1.0, e.pos); player.shake = maxf(player.shake, 0.25 if dist < 20.0 else 0.0)
					if fx: fx.sparks(e.pos, 14, [1.0, 0.8, 0.4], 4.0)
			return
		e.g.rotation.x = lerpf(e.g.rotation.x, 0.0, 1.0 - exp(-dt * 4.0)); _bee_eye(e, Color(0.23, 0.04, 0.0))
		if D.t > 1.0: k.erase("dash")   # resting after the charge: a sitting target
		else: return
	e.strafe_t -= dt
	if e.strafe_t <= 0.0: e.strafe *= -1.0; e.strafe_t = rnd(1.6, 3.2)
	var f := to / dist; var fwd := 0.6 if not e.los else (0.8 if dist > 16.0 else (-0.8 if dist < 9.0 else 0.0)); var sp2: float = T.speed * (1.4 if e.rage else 1.0)
	e.pos = Phys.move_xz(e.pos, (f.x * fwd - f.y * e.strafe * 0.9) * sp2 * dt, (f.y * fwd + f.x * e.strafe * 0.9) * sp2 * dt, e.R, 1.0, 0.0)[0]
	e.pos.x = clampf(e.pos.x, Rm[0] + 2.2, Rm[2] + 5.0); e.pos.z = clampf(e.pos.z, Rm[1] + 2.2, Rm[3] - 2.2)
	if e.pos.x > Rm[2] - 1.0: e.pos.z = clampf(e.pos.z, -11.0, -4.0)   # only out into the corridor mouth, not through its walls
	var ty := clampf(player.pos.y + 3.2 + sin(k.spin * 0.9) * 0.6, 2.8, (6.0 if e.pos.x > Rm[2] else Rm[4]) - 1.7)
	e.pos.y += (ty - e.pos.y) * (1.0 - exp(-dt * 1.5)); _turn(e, face_yaw, 3.0, dt); e.g.rotation.z = lerpf(e.g.rotation.z, -e.strafe * 0.1, 1.0 - exp(-dt * 3.0))
	e.react -= dt
	if e.los and dist < T.range and e.react <= 0.0:
		var b0 := e.burst; fire(e, dt * (1.6 if e.rage else 1.0), dist)
		if e.burst != b0: e.muzzle.x = -e.muzzle.x
	k.skillT = float(k.get("skillT", 4.0)) - dt
	if k.skillT <= 0.0 and dist < 45.0:
		k.skillT = rnd(2.6, 3.4) if e.rage else rnd(4, 5.5); var last: String = k.get("last", "")
		var want := "dash" if (last == "call" or not e.los) else ("call" if last == "dash" else ("call" if randf() < 0.5 else "dash"))
		if want == "call" and _bee_drones(e) > 0: k.last = "call"
		elif e.los and dist > 4.0: k.last = "dash"; k.dash = {"mode": "wind", "t": 0.0, "at": Vector3(player.pos.x, player.pos.y + 1.2, player.pos.z), "hit": false, "v": Vector3.ZERO}; Snd.play("charge", 1.0, e.pos); Snd.play("rage", 0.6, e.pos)

# ---------------- the boss drone ----------------
func _eye(e: Enemies.Foe) -> Vector3:
	var R: float = SHELL_R[e.k.phase]; var cy := cos(e.yaw); var sy := sin(e.yaw); var cp := cos(e.g.rotation.x); var sp := sin(e.g.rotation.x); var fz := R * 0.9
	return Vector3(e.pos.x + sy * cp * fz, e.pos.y - sp * fz, e.pos.z + cy * cp * fz)

## closest distance between segment a-b and segment c-d
static func seg_dist(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	var u := b - a; var v := d - c; var w := a - c; var A := u.dot(u); var B := u.dot(v); var C := v.dot(v); var D := u.dot(w); var E := v.dot(w)
	var den := A * C - B * B; var s := clampf((B * E - C * D) / den, 0.0, 1.0) if den > 1e-9 else 0.0; var t := (B * s + E) / C if C > 1e-9 else 0.0
	if t < 0.0: t = 0.0; s = clampf(-D / A, 0.0, 1.0) if A > 1e-9 else 0.0
	elif t > 1.0: t = 1.0; s = clampf((B - D) / A, 0.0, 1.0) if A > 1e-9 else 0.0
	return (w + u * s - v * t).length()

## what gets through to the boss: nothing while a shell comes apart, and never past a third of its health at once
func guard(e: Enemies.Foe, dmg: float) -> float:
	if not e.k.has("phase"): return dmg
	var k := e.k
	if k.mode == "shed": return 0.0
	var floor_hp: float = e.max_hp * 2.0 / 3.0 if k.phase == 0 else (e.max_hp / 3.0 if k.phase == 1 else -INF)
	if e.hp - dmg <= floor_hp: e.hp = floor_hp; _shed(e); return 0.0
	return dmg

## a third of its health gone: the outer shell blows apart and a smaller, faster drone comes out of it
func _shed(e: Enemies.Foe) -> void:
	var k := e.k
	if k.phase >= 2: return
	k.mode = "shed"; k.t = 0.0; k.salvo = 0; aim_off()
	var old: Dictionary = k.shells[k.phase]; k.phase += 1; var nw: Dictionary = k.shells[k.phase]
	if fx:
		fx.explode(e.pos, true); fx.explode(e.pos + Vector3(old.R * 0.5, 0, -old.R * 0.3), true); fx.explode(e.pos + Vector3(-old.R * 0.4, old.R * 0.4, 0), true)
		fx.chunks(e.pos, 26, 0.18 * old.R, "metal")
	Snd.play("boom", 1.0, e.pos); player.shake = maxf(player.shake, 0.5)
	(old.g as Node3D).visible = false; (nw.g as Node3D).visible = true
	e.R = nw.R; e.H = nw.R * 2.0; e.bar_y = nw.R + 0.7; e.parts = shell_parts(nw.R); eye_tint(e, false)
	game.say_banner("B-3 · %d페이즈" % (k.phase + 1), "껍데기가 모두 벗겨지고 핵이 드러났습니다 · 가장 작고 빠릅니다" if k.phase == 2 else "바깥 껍데기가 부서졌습니다 · 더 작고 빨라졌습니다", 2.6)
	if k.phase == 2: world.ship.hatch_wait = 2.6   # and, once the banner has gone, the floor opens: drones by the dozen
	if k.phase == 1: world.ship.break_t = 1.8      # and in the second the hall's floor breaks up and falls into the pit under it

func _drop_mines(e: Enemies.Foe, n: int) -> void:
	var live := 0
	for o in en.list:
		if o.extra and o.alive: live += 1
	n = mini(n, 45 - live)
	for i in n:
		var tx := 0.0; var tz := 0.0; var ty := 0.0
		for tries in 8:   # straight down out of its belly, spreading a little round the spot under it
			var a := rnd(0, TAU); var rr := rnd(0.2, 1.2 + n * 0.12); tx = e.pos.x + cos(a) * rr; tz = e.pos.z + sin(a) * rr; ty = Phys.ground_at(tx, e.pos.y, tz, 0.2)
			if not Ship.room_at(tx, tz).is_empty() and Phys.collide_at(tx, ty + 0.05, tz, 0.4, 0.5) == null: break
		var mn := en.spawn("mine", e.pos.x, e.pos.z, {"y": e.pos.y - e.R * 0.5, "yaw": rnd(0, TAU)})
		var T := rnd(0.45, 0.75); mn.extra = true; mn.bs = "fall"; mn.vel = Vector3((tx - e.pos.x) / T, 0, (tz - e.pos.z) / T); mn.vy = (ty - mn.pos.y + 0.5 * 18.0 * T * T) / T; mn.k.baseY = ty; mn.alert = true; mn.awake = true; mn.lod = 0.0
	Snd.play("clank", 1.0, e.pos)

func _make_fx() -> void:
	if aim_line != null and is_instance_valid(aim_line): return
	# the browser game's ShipFX, all added light: a thin red aiming line, then the beam, a red tube round a bright core
	_aim_mat = _see("ff2a2a", 0.7, true); _beam_mat = _see("ff3a2a", 0.85, true); _core_mat = _see("ffd8d0", 1.0, true)
	aim_line = MeshInstance3D.new(); aim_line.mesh = _bx(0.03, 0.03, 1.0); aim_line.material_override = _aim_mat; aim_line.visible = false; en.add_child(aim_line)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.append_from(BotLook.cyl(1, 1, 1, 10, true), 0, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)); var tube := st.commit()
	beam = MeshInstance3D.new(); beam.mesh = tube; beam.material_override = _beam_mat; beam.visible = false; en.add_child(beam)
	beam_core = MeshInstance3D.new(); beam_core.mesh = tube; beam_core.material_override = _core_mat; beam_core.visible = false; en.add_child(beam_core)
	for n: MeshInstance3D in [aim_line, beam, beam_core]: n.extra_cull_margin = 200.0; n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _lay(n: MeshInstance3D, a: Vector3, b: Vector3, w: float) -> void:
	if a.distance_to(b) < 0.05: return
	n.look_at_from_position((a + b) / 2, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT); n.scale = Vector3(w, w, a.distance_to(b))

func aim_off() -> void:
	if aim_line != null and is_instance_valid(aim_line): aim_line.visible = false

func _fire_laser(e: Enemies.Foe) -> void:
	var k := e.k; var from := _eye(e); var dir: Vector3 = (k.aim - from).normalized()
	var hit := Phys.raycast_static(from, dir, 160.0); var L := Phys.rh_t if hit else 160.0; var end := from + dir * L
	if hit and Phys.rh_box != null and Phys.rh_box.kind == "wood" and Phys.rh_box.ref is Dictionary: world.damage_crate(Phys.rh_box.ref, 999.0, end)
	_make_fx(); beam_t = 0.4; beam.visible = true; beam_core.visible = true; _lay(beam, from, end, 0.28); _lay(beam_core, from, end, 0.09); Snd.play("beam", 1.0, from)
	if fx: fx.sparks(end, 14, [1.0, 0.3, 0.2], 4.0)
	# touching the beam anywhere along its length is the end
	var a := Vector3(player.pos.x, player.pos.y + 0.2, player.pos.z); var b := Vector3(player.pos.x, player.pos.y + Player.HEIGHT, player.pos.z)
	if player.invuln <= 0.0 and seg_dist(from, end, a, b) < 0.55: game.laser(e)

func _launch(e: Enemies.Foe) -> void:
	var k := e.k; var sx := 1.0 if int(k.salvo) % 2 else -1.0; var cy := cos(e.yaw); var sy := sin(e.yaw)
	var from := Vector3(e.pos.x + cy * sx * e.R * 0.95, e.pos.y + e.R * 0.2, e.pos.z - sy * sx * e.R * 0.95)
	var dir := Vector3(cy * sx * 0.7 + sy * 0.5 + rnd(-0.4, 0.4), 0.5 + rnd(0, 0.6), -sy * sx * 0.7 + cy * 0.5 + rnd(-0.4, 0.4))
	rocket(from, dir, 100.0, 13.0 if k.phase == 2 else 15.0)
	if int(k.salvo) % 6 == 0: Snd.play("rocket_pod", 1.0, e.pos)   # (every sixth leaving its pod, as the browser game's bossLaunch)

func _boss(e: Enemies.Foe, dt: float, dist: float, face_yaw: float) -> void:
	if not e.k.has("phase"): e.k.merge({"phase": 0, "mode": "idle", "t": 0.0, "cd": 2.5, "last": "", "goalT": 0.0, "v": Vector3.ZERO, "aim": Vector3.ZERO, "salvo": 0, "salvoT": 0.0, "gapT": 0.0})
	var k := e.k; var P: Dictionary = BPH[k.phase]; k.t += dt; var HALL: Array = Ship.ROOMS[2]
	if k.mode == "idle":
		e.pos.y += sin(k.spin * 1.1) * dt * 0.3
		if e.sealed: e.yaw += dt * 0.25; return   # behind its shut door: turning slowly, aware of nothing
		if (e.los and dist < 45.0) or e.alert or dist < 20.0: k.mode = "move"; k.cd = 2.0; e.alert = true; Snd.play("alarm")
		else: _turn(e, face_yaw, 0.6, dt); return
	# where to be: round you at its own distance and height, inside the hall, clear of the reactor
	if k.mode != "shed":
		k.goalT -= dt
		if not k.has("goal") or k.goalT <= 0.0:
			var gx := 0.0; var gz := 0.0
			for t in 10:
				var a := rnd(0, TAU); var rr := rnd(P.dist[0], P.dist[1]); gx = player.pos.x + cos(a) * rr; gz = player.pos.z + sin(a) * rr
				if gx > HALL[0] + e.R + 2 and gx < HALL[2] - e.R - 2 and gz > HALL[1] + e.R + 2 and gz < HALL[3] - e.R - 2: break
			k.goal = Vector3(gx, minf(player.pos.y, 6.0) + rnd(P.y[0], P.y[1]), gz); k.goalT = rnd(1.6, 3)
		var to_goal: Vector3 = k.goal - e.pos; var l := to_goal.length(); var sp: float = P.sp * (0.4 if k.mode == "charge" else 1.0)
		k.v = (k.v as Vector3).lerp(to_goal / l * sp if l > 0.4 else Vector3.ZERO, 1.0 - exp(-dt * 2.0)); e.pos += (k.v as Vector3) * dt
	else: e.pos.y += sin(k.t * 9.0) * dt * 0.6
	var R := e.R
	e.pos.x = clampf(e.pos.x, HALL[0] + R + 0.6, HALL[2] - R - 0.6); e.pos.z = clampf(e.pos.z, HALL[1] + R + 0.6, HALL[3] - R - 0.6)
	e.pos.y = clampf(e.pos.y, Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, R * 0.5) + R + 0.4, Ship.ceil_at(e.pos.x, e.pos.z) - R)
	var rv := Vector2(e.pos.x - Ship.REACTOR.x, e.pos.z - Ship.REACTOR.z); var need: float = Ship.REACTOR.r + R + 0.8
	if rv.length() < need: var rn := rv.normalized() if rv.length() > 0.001 else Vector2(1, 0); e.pos.x = Ship.REACTOR.x + rn.x * need; e.pos.z = Ship.REACTOR.z + rn.y * need
	for q in Ship.PILLARS:
		var qv := Vector2(e.pos.x - q[0], e.pos.z - q[1]); var nd := 1.2 * 1.42 + R + 0.3
		if qv.length() < nd: var qn := qv.normalized() if qv.length() > 0.001 else Vector2(1, 0); e.pos.x = q[0] + qn.x * nd; e.pos.z = q[1] + qn.y * nd
	# face you, eye first
	_turn(e, face_yaw, 6.0 if k.phase == 2 else 3.0, dt)
	e.g.rotation.x = lerpf(e.g.rotation.x, clampf(atan2(e.pos.y - (player.pos.y + 1.2), dist), -0.6, 1.1), 1.0 - exp(-dt * 4.0))
	if k.phase == 2: e.g.rotation.z = sin(k.spin * 3.0) * 0.12   # the bare core wobbles
	if k.mode == "shed":
		if k.t >= 1.4: k.mode = "move"; k.cd = 1.2
		return
	# rockets already ordered keep leaving while it flies
	if k.salvo > 0:
		k.salvoT -= dt
		while k.salvo > 0 and k.salvoT <= 0.0: k.salvo -= 1; k.salvoT += maxf(k.gapT, 0.0001); _launch(e)
	if k.mode == "warn":   # the eye is red and it keeps moving; in three seconds the red line comes out, with the siren
		if k.t >= LASER_WARN: k.mode = "charge"; k.t = 0.0; k.aim = Vector3(player.pos.x, player.pos.y + 1.1, player.pos.z); Snd.play("laser_siren%d" % (int(k.phase) + 1))   # the laser-lock wail, its phase's charge + 0.25 s long (siren2)
		return
	if k.mode == "charge":
		# the aim drifts after you and holds still for the last quarter second
		var left: float = P.charge - k.t
		if left > 0.25:
			var dv: Vector3 = Vector3(player.pos.x, player.pos.y + 1.1, player.pos.z) - k.aim; var L := dv.length(); var step: float = P.track * dt
			if L > step: dv *= step / L
			k.aim += dv
		var from := _eye(e); var dir: Vector3 = (k.aim - from).normalized(); var hit := Phys.raycast_static(from, dir, 160.0)
		_make_fx(); aim_line.visible = true; _lay(aim_line, from, from + dir * (Phys.rh_t if hit else 160.0), 3.0 if left < 0.25 else 1.0)
		Gfx.set_alpha(_aim_mat, 1.0 if left < 0.25 else 0.45 + 0.3 * sin(_fx_clock * 30.0))   # (pulsing, then solid for the last quarter second)
		if k.t >= P.charge: aim_off(); _fire_laser(e); k.mode = "cool"; k.t = 0.0
		return
	if k.mode == "cool":
		if k.t > 0.35: eye_tint(e, false); k.mode = "move"
		return
	k.cd -= dt
	if k.cd <= 0.0:
		var opts: Array = ["laser", "rockets", "mines"].filter(func(s): return s != k.last and (s == "mines" or e.los))
		var s: String = opts[randi() % opts.size()] if not opts.is_empty() else "mines"; k.last = s
		if s == "laser": k.mode = "warn"; k.t = 0.0; eye_tint(e, true)   # red eye first: 3 s, then the aim
		elif s == "rockets": k.salvo = P.rockets; k.gapT = P.win / P.rockets if P.rockets > 1 else 0.0; k.salvoT = 0.0; Snd.play("rocket_pod", 1.0, e.pos)
		else: _drop_mines(e, P.mines)
		k.cd = rnd(P.gap[0], P.gap[1]) + (P.charge + LASER_WARN if s == "laser" else 0.0)

# ---------------- homing rockets: each one turns towards you a little at a time while it can see you (behind a wall it loses you and
# flies straight on into the wall) and bursts on a wall, the floor, or you ----------------
func rocket(from: Vector3, dir: Vector3, dmg: float, speed: float) -> void:
	if rockets.size() >= MAX_ROCKETS: return
	rockets.push_back({"p": from, "v": dir.normalized() * speed, "dmg": dmg, "life": 8.0, "see_t": randf() * 0.15, "sees": true})

func _rocket_blast(c: Vector3, dmg: float, loud: bool) -> void:
	if fx: fx.explode(c, false)
	if loud: Snd.play("boom_small", 1.0, c)
	var d := Vector3(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z).length()
	player.shake = maxf(player.shake, clampf(0.4 - d * 0.03, 0.0, 0.4))
	if d < 3.0 and Phys.line_of_sight(c, Vector3(player.pos.x, player.pos.y + 1.2, player.pos.z)): player.hurt(dmg if d < 1.2 else dmg * (1.0 - (d - 1.2) / 1.8 * 0.7), c, "body")

func tick(dt: float) -> void:
	# drones coming up out of the hall's hatches: not among the hundred, gone with the boss
	var sh: Ship = world.ship
	if sh != null:
		if sh.hatch_wait > 0.0:
			sh.hatch_wait -= dt
			if sh.hatch_wait <= 0.0 and game.boss != null and game.boss.alive: sh.open_hatches()
		for i in range(sh.hatch_q.size() - 1, -1, -1):
			var q: Dictionary = sh.hatch_q[i]; q.t -= dt
			if q.t > 0.0: continue
			sh.hatch_q.remove_at(i)
			if game.boss == null or not game.boss.alive: continue
			var mn := en.spawn("droneA", q.x + rnd(-0.4, 0.4), q.z + rnd(-0.4, 0.4), {"y": 0.3, "yaw": rnd(0, TAU)})
			mn.extra = true; mn.alert = true; mn.awake = true; mn.lod = 0.0; Snd.play("zap_drone", 1.0, mn.pos); _puff(Vector3(q.x, float(q.get("y", 0.0)) + 0.4, q.z), 2, 0.4, 0.5)
	for i in range(blasts.size() - 1, -1, -1):
		var b: Dictionary = blasts[i]; b.t -= dt
		if b.t <= 0.0: blasts.remove_at(i); _blast(b.at)
	_fx_clock += dt
	if beam_t > 0.0:
		beam_t -= dt; var bk := clampf(beam_t / 0.4, 0.0, 1.0); Gfx.set_alpha(_beam_mat, 0.85 * bk); Gfx.set_alpha(_core_mat, bk)
		if beam_t <= 0.0: beam.visible = false; beam_core.visible = false
	if rockets.is_empty() and _rockets_drawn == 0: return
	var target := Vector3(player.pos.x, player.pos.y + 1.0, player.pos.z); var loud := 0
	for i in range(rockets.size() - 1, -1, -1):
		var Rk: Dictionary = rockets[i]; Rk.life -= dt
		var p: Vector3 = Rk.p; var d := target - p; var dl := maxf(d.length(), 0.001); d /= dl
		Rk.see_t -= dt
		if Rk.see_t <= 0.0: Rk.see_t = 0.15; Rk.sees = Phys.line_of_sight(p, target)
		var v: Vector3 = Rk.v; var sp := v.length(); var vn := v / sp
		if Rk.sees: vn = vn.lerp(d, minf(1.0, 1.5 * dt)).normalized()
		Rk.v = vn * sp; var step := sp * dt; var hit := Phys.raycast_static(p, vn, step)
		p += vn * (Phys.rh_t if hit else step); Rk.p = p
		if hit or dl < 1.0 or Rk.life <= 0.0 or p.y < Phys.floor_y(p.x, p.z) + 0.05: _rocket_blast(p, Rk.dmg, loud < 4); loud += 1; rockets.remove_at(i); continue
		Rk.trail = Rk.get("trail", 0.0) - dt
		if Rk.trail <= 0.0:
			Rk.trail = 0.1 if rockets.size() > 40 else 0.04
			if fx: fx.glow(p, Vector3.ZERO, 0.35, 0.28, 0.06, Color(1, 0.55, 0.25, 0.8))
	if rocket_mm == null or not is_instance_valid(rocket_mm):
		_rocket_mesh = CylinderMesh.new(); _rocket_mesh.top_radius = 0.07; _rocket_mesh.bottom_radius = 0.1; _rocket_mesh.height = 0.6
		var rmat := Gfx.std(World.lin("c8ced8"), 0.35, 0.6); rmat.emission_enabled = true; rmat.emission = World.lin("331000")   # (the browser game's: steel, a faint warm glow)
		rocket_mm = MultiMeshInstance3D.new(); rocket_mm.material_override = rmat; MoonShadow.no_receive(rocket_mm); rocket_mm.custom_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 60, 400)); en.add_child(rocket_mm)
	# a new MultiMesh every frame: one changed in place does not always reach the screen on the web renderer
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = _rocket_mesh; mm.instance_count = rockets.size()
	for i in rockets.size():
		var Rk: Dictionary = rockets[i]; var dirv: Vector3 = (Rk.v as Vector3).normalized(); var up := Vector3.UP if absf(dirv.y) < 0.99 else Vector3.RIGHT
		mm.set_instance_transform(i, Transform3D(Basis.looking_at(dirv, up, true) * Basis(Vector3.RIGHT, PI / 2), Rk.p))   # (the thin end first, as three.js's lookAt turns it)
	rocket_mm.multimesh = mm; _rockets_drawn = rockets.size()

func _puff(p: Vector3, n: int, shade: float, size: float) -> void:
	if fx: fx.puff(p, n, shade, size)
