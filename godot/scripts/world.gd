class_name World
extends Node3D
## The yard for each stage. Ported from src/04a_world.js and src/04c_stage.js: the same seeded random numbers in the same
## order, so every container, crate and lamp stands where it does in the browser game (tests/run.gd checks this).

const CONT_COLORS := ["8c3a2b", "2c4f7c", "356b45", "c4682a", "7b8288", "2f7a7a", "6a2a35", "b8ab8a"]
const OWNERS := ["YRD", "KJT", "HWS", "SLV", "PRC", "DGN", "TRV", "BNK"]
const STAGE_STYLE := {
	# stage 5, the toy room: a sunny bedroom, bright and warm
	9: {"toy": true, "fog": [0.55, 0.62, 0.68], "density": 0.004, "zenith": [0.55, 0.62, 0.68], "glow": [0.0, 0.0, 0.0], "hemi": ["ffffff", "cdb99a", 0.5], "moon": ["fff1d6", 0.62], "lamp": ["ffffff", 0.0], "seed": 77, "crates": 24, "sunOff": [30, 60, 34], "exposure": 0.95},
	# 1-2: the same docks later that night, a little colder, laid out differently
	5: {"fog": [0.024, 0.031, 0.052], "density": 0.016, "zenith": [0.005, 0.008, 0.019], "glow": [0.05, 0.03, 0.03], "hemi": ["5a6c98", "2a2422", 0.6], "moon": ["a8bcff", 0.44], "lamp": ["ffb060", 1.8], "seed": 11, "crates": 40, "singles": 14, "empty": 0.12},
	# 1-1: the docks again, another night, another layout, mist over the water
	6: {"fog": [0.03, 0.034, 0.05], "density": 0.018, "zenith": [0.007, 0.008, 0.016], "glow": [0.07, 0.04, 0.024], "hemi": ["5f6f92", "2b2420", 0.6], "moon": ["b0c0ff", 0.42], "lamp": ["ffa040", 1.85], "seed": 19, "crates": 40, "singles": 12, "empty": 0.1},
	# the village: deep blue night, a big moon, fires flickering orange
	2: {"fog": [0.018, 0.024, 0.04], "density": 0.019, "zenith": [0.004, 0.007, 0.02], "glow": [0.07, 0.03, 0.008], "hemi": ["4c5c86", "1a1914", 0.42], "moon": ["c4d6ff", 0.62], "lamp": ["ff7a30", 2.6],
		"seed": 23, "crates": 46, "fire": true, "sunOff": [-40, 49, -49]},
	# inside the spaceship: dark plating, cold blue-white light
	4: {"indoor": true, "ship": true, "fog": [0.012, 0.016, 0.026], "density": 0.011, "zenith": [0.004, 0.006, 0.012], "glow": [0.02, 0.03, 0.05], "hemi": ["8aa0d0", "34363e", 0.85], "moon": ["e2ecff", 0.75], "lamp": ["9fd4ff", 1.5],
		"seed": 61, "crates": 24, "sunOff": [-18, 70, 22], "exposure": 1.12},
	# the sealed lab: cold fluorescent light from above, a pale tiled floor
	3: {"indoor": true, "lab": true, "ride": true, "fog": [0.02, 0.026, 0.032], "density": 0.008, "zenith": [0.004, 0.006, 0.01], "glow": [0.02, 0.03, 0.04], "hemi": ["dfe8f0", "5a6066", 0.95], "moon": ["f4f8ff", 0.95], "lamp": ["e6f2ff", 2.2],
		"seed": 41, "crates": 40, "sunOff": [-12, 70, 18], "exposure": 1.08},
	# 3-2: the same lab on the night shift: a little cooler and dimmer, another layout of crates
	8: {"indoor": true, "lab": true, "ride": true, "seq": true, "fog": [0.016, 0.022, 0.03], "density": 0.009, "zenith": [0.004, 0.006, 0.01], "glow": [0.02, 0.03, 0.04], "hemi": ["d4e0f0", "4e5660", 0.85], "moon": ["e8f0ff", 0.85], "lamp": ["d8e8ff", 2.0],
		"seed": 43, "crates": 40, "sunOff": [-12, 70, 18], "exposure": 1.02},
	# 3-1: the old safari at golden hour, a low sun, warm haze over the grass
	7: {"day": true, "savanna": true, "ride": true, "fog": [0.30, 0.25, 0.17], "density": 0.0058, "zenith": [0.10, 0.20, 0.42], "glow": [0.55, 0.28, 0.08], "hemi": ["b0c4e0", "6b5a3a", 0.62], "moon": ["ffd7a8", 1.0], "exposure": 0.82,
		"lamp": ["ffffff", 0.0], "seed": 41, "sunOff": [-70, 38, 25], "crates": 46},
	1: {"fog": [0.026, 0.033, 0.052], "density": 0.016, "zenith": [0.006, 0.008, 0.017], "glow": [0.06, 0.036, 0.022], "hemi": ["5d6f96", "2b2420", 0.62],
		"moon": ["a8bcff", 0.42], "lamp": ["ffa548", 1.8], "seed": 7, "crates": 40, "singles": 12, "empty": 0.1},
}

## the browser game's seeded generator (mulberry32), bit for bit
class Rng:
	var s: int
	func _init(seed_: int) -> void: s = seed_ & 0xFFFFFFFF
	func next() -> float:
		s = (s + 0x6D2B79F5) & 0xFFFFFFFF
		var t := ((s ^ (s >> 15)) * (1 | s)) & 0xFFFFFFFF
		t = ((t + (((t ^ (t >> 7)) * (61 | t)) & 0xFFFFFFFF)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
	func rng(a: float, b: float) -> float: return a + next() * (b - a)

var style: Dictionary = STAGE_STYLE[1]
var group: Node3D = null
var crates: Array = []      # {idx, hp, x, z, y, dead, b}
var crate_mm: MultiMesh = null
var crate_mmi: MultiMeshInstance3D = null; var crate_xf: Array = []   # the crates' node and where each one stands
var lamps: Array = []       # {x, y, z}
var blink: Array = []
var lights: Array[OmniLight3D] = []
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var fog_mat: ShaderMaterial
var grade: Grade = null   # the computer's finishing pass, tuned per stage
var moon_shadow: MoonShadow          # the moon's shadow picture (see MoonShadow)
var shadow_mat: ShaderMaterial       # and the layer that lays it over the frame
var shadow_layer: MeshInstance3D
var ao: AoView                       # the computer's ambient occlusion (see AoView), and its layer
var ao_mat: ShaderMaterial
var ao_layer: MeshInstance3D
var use_ao := true                   # phones go without, as the browser game's
var hand_root: Node = null           # the gun in hand: its drawn things go on their own render layer
static var shadow_map_size := 2048   # as the browser game's computer setting; phones use 1024 there and here
var caster_roots: Array = []         # drawn things added under these cast the moon's shadow (people, animals, robots, loot)
var fog_layer: MeshInstance3D
var hemi_up: DirectionalLight3D
var hemi_dn: DirectionalLight3D
var _shadow_off: Array = [-30, 50, -20]
var lamp_scale := 1.0   # 0 puts the lamp lights out (pictures that compare light by light)
var _fresh: Array = []   # drawn things added since the last frame, to be given three.js's material rules (Gfx.three_like)
const LAMP_K := 2.944        # Godot energy per unit of three.js intensity, with this range and falloff
const LAMP_RANGE := 26.75
const LAMP_ATTEN := 0.82
var start := {"x": 0.0, "z": 6.0, "yaw": 0.0}
var spawns: Array = []
var _lamp_t := 0.0
var on_crate: Callable = Callable()   # called with the crate when one breaks
var fx: Fx = null
var toy: ToyRoom = null
var village: Village = null
var lab: Lab = null
var ship: Ship = null
var safari: Safari = null
var steady := false   # pictures beside the browser game's: lamps and fires at their mean brightness, no flicker
var fire_mats: Array = []   # the village's flames, embers and smoke (their time is set each frame)
var _backdrop_blink: Array = []
var _tex := {}

func _ready() -> void:
	# the picture as three.js r128 drew it (see Gfx): tone mapped inside each material, fog laid over the finished colours
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("0b0f1a")   # the browser game's clear colour: only past the far plane
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_white = Gfx.TONE_WHITE; env.tonemap_exposure = Gfx.exposure(1.15)
	# Godot's own fog, for see-through things only: the browser game's FogExp2 is 1 - exp(-(d z)^2), which smoothstep(0, sqrt(3)/d)
	# follows within 0.05
	env.fog_enabled = true; env.fog_mode = Environment.FOG_MODE_DEPTH; env.fog_depth_begin = 0.0; env.fog_depth_curve = 1.0; env.fog_density = 1.0; env.fog_sky_affect = 0.0
	env.glow_enabled = false   # glow moves tone mapping into a pass after the fog layer has blended; the browser game's bloom is Grade's
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	# the sky dome: a sphere 380 m round the middle of the map, as the browser game's, drawn after the fog layer (it takes none)
	sky_mat = ShaderMaterial.new(); sky_mat.shader = Gfx.sky_shader(); sky_mat.render_priority = Gfx.PRIO_SKY
	var sm := SphereMesh.new(); sm.radius = 380.0; sm.height = 760.0; sm.radial_segments = 32; sm.rings = 16
	var dome := MeshInstance3D.new(); dome.name = "Sky"; dome.mesh = sm; dome.material_override = sky_mat; dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.custom_aabb = AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800)); add_child(dome)
	# the fog layer over everything solid
	fog_mat = ShaderMaterial.new(); fog_mat.shader = Gfx.fog_shader(); fog_mat.render_priority = Gfx.PRIO_FOG
	var fq := QuadMesh.new(); fq.size = Vector2(2, 2)
	fog_layer = MeshInstance3D.new(); fog_layer.name = "FogLayer"; fog_layer.mesh = fq; fog_layer.material_override = fog_mat
	fog_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; fog_layer.extra_cull_margin = 16384.0; add_child(fog_layer)
	# three.js's hemisphere light, sky colour from above and ground colour from below, mixed by the surface's slope:
	# the middle of the two as ambient light, and half their difference as a light straight down and a negative one straight up
	hemi_up = DirectionalLight3D.new(); hemi_up.rotation = Vector3(-PI / 2, 0, 0); hemi_up.light_specular = 0.0; hemi_up.shadow_enabled = false; add_child(hemi_up)
	hemi_dn = DirectionalLight3D.new(); hemi_dn.rotation = Vector3(PI / 2, 0, 0); hemi_dn.light_specular = 0.0; hemi_dn.shadow_enabled = false; hemi_dn.light_negative = true; add_child(hemi_dn)
	# the moon lights in the main pass; its shadow comes from MoonShadow (only stage 5, this port's own room, keeps Godot's)
	moon = DirectionalLight3D.new(); moon.shadow_enabled = false; moon.light_specular = 1.0; moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 80.0; moon.shadow_bias = 0.06; moon.shadow_normal_bias = 1.5; add_child(moon)
	moon_shadow = MoonShadow.new(); add_child(moon_shadow); moon_shadow.setup(shadow_map_size)
	shadow_mat = ShaderMaterial.new(); var ssh := Shader.new(); ssh.code = MoonShadow.LAYER_SHADER % Gfx.ALBEDO_GLSL; shadow_mat.shader = ssh; shadow_mat.render_priority = Gfx.PRIO_SHADOW
	shadow_mat.set_shader_parameter("shadow_map", moon_shadow.get_texture()); shadow_mat.set_shader_parameter("map_size", float(shadow_map_size)); shadow_mat.set_shader_parameter("flip", 1.0)
	shadow_mat.set_shader_parameter("lamp_range", LAMP_RANGE); shadow_mat.set_shader_parameter("lamp_atten", LAMP_ATTEN)
	var sq := QuadMesh.new(); sq.size = Vector2(2, 2)
	shadow_layer = MeshInstance3D.new(); shadow_layer.name = "ShadowLayer"; shadow_layer.mesh = sq; shadow_layer.material_override = shadow_mat
	shadow_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; shadow_layer.extra_cull_margin = 16384.0; add_child(shadow_layer)
	ao = AoView.new(); add_child(ao); ao.setup()
	ao_mat = ShaderMaterial.new(); var ash := Shader.new(); ash.code = AoView.APPLY_SHADER % Gfx.ALBEDO_GLSL; ao_mat.shader = ash; ao_mat.render_priority = Gfx.PRIO_AO
	ao_mat.set_shader_parameter("ao_tex", ao.get_texture())
	var aq := QuadMesh.new(); aq.size = Vector2(2, 2)
	ao_layer = MeshInstance3D.new(); ao_layer.name = "AoLayer"; ao_layer.mesh = aq; ao_layer.material_override = ao_mat
	ao_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; ao_layer.extra_cull_margin = 16384.0; add_child(ao_layer)
	# the full-screen layers and the sky are for the main camera only (the shadow and occlusion cameras would run them too)
	for n: VisualInstance3D in [shadow_layer, fog_layer, ao_layer, dome]: n.layers = 1 << (Gfx.MAIN_ONLY - 1)
	# the lamps: three.js point lights reaching 30 m with (1 - d/30)^2; Godot's falloff fitted to it from 6 to 30 m (within 0.035, 0.012 past 8 m)
	for i in 6:
		var l := OmniLight3D.new(); l.omni_range = LAMP_RANGE; l.omni_attenuation = LAMP_ATTEN; l.light_energy = 0.0; l.shadow_enabled = false; l.light_specular = 0.5; add_child(l); lights.push_back(l)   # (gloss 0.5 is the physical amount for a point light, doubled inside; 1.0 for the moon)
	get_tree().node_added.connect(_on_node_added)
	_tex.asphalt = Gfx.asphalt_tex(); _tex.concrete = Gfx.concrete_tex(); _tex.crate = Gfx.crate_tex()
	_tex.pool = Gfx.glow_tex(Color(1, 0.784, 0.549, 0.5), Color(1, 0.627, 0.314, 0.16))
	_build_backdrop()

func _process(_dt: float) -> void:
	if sun_spr.visible:
		var sc := get_viewport().get_camera_3d(); var so: Array = style.get("sunOff", [-30, 50, -20])
		if sc: sun_spr.global_position = sc.global_position + Vector3(so[0], so[1], so[2]).normalized() * 330.0
	if ao_layer.visible:
		var c := get_viewport().get_camera_3d()
		if c: ao.follow(c, get_viewport().get_visible_rect().size)
		ao_mat.set_shader_parameter("ao_texel", Vector2(1.0 / ao.size.x, 1.0 / ao.size.y))
	if not shadow_layer.visible: return
	shadow_mat.set_shader_parameter("shadow_clip", moon_shadow.world_to_clip())
	var lp := PackedVector4Array()
	for l: OmniLight3D in lights: lp.push_back(Vector4(l.position.x, l.position.y, l.position.z, l.light_energy if l.visible else 0.0))
	shadow_mat.set_shader_parameter("lamp_pos", lp)

## the browser game's quality ladder on a computer (Gfx.govern), the part that decides the ambient occlusion: from the top
## level it steps down while the frame rate sags under 50 (two steps under 30), and the occlusion goes below level 3; it
## creeps back up after three spells above 57, and holds off a minute if a step up does not last. gfx_fixed keeps it at
## the top, as the browser game's "high" setting does
var gfx_fixed := false
var gfx_level := 4
var _gv := {"acc": 0.0, "n": 0, "good": 0, "t": 0.0, "up_at": -1e9, "hold": 0.0}
func govern(delta: float) -> void:
	if gfx_fixed: return
	var G := _gv; G.t += delta; G.acc += delta; G.n += 1
	if G.acc < 2.0: return
	var avg: float = G.acc / G.n; G.acc = 0.0; G.n = 0
	if avg > 1.0 / 50.0 and gfx_level > 0:
		if G.t - G.up_at < 10.0: G.hold = G.t + 60.0   # the last step up did not hold: stay put for a while
		gfx_level -= 2 if avg > 1.0 / 30.0 and gfx_level > 1 else 1; G.good = 0
	elif avg < 1.0 / 57.0 and gfx_level < 4:
		G.good += 1
		if G.good >= 3 and G.t > G.hold: gfx_level += 1; G.good = 0; G.up_at = G.t
	else: G.good = 0
	var want := gfx_level >= 3
	if want != use_ao: use_ao = want; set_ao(want and toy == null)

## the computer's ambient occlusion on or off (phones, stage 5's own room, or a frame rate that cannot carry it)
func set_ao(on: bool) -> void:
	ao_layer.visible = on; ao.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED

func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D:
		if not RenderingServer.frame_pre_draw.is_connected(_flush_fresh): RenderingServer.frame_pre_draw.connect(_flush_fresh, CONNECT_ONE_SHOT)
		_fresh.push_back(n)
## right before each frame is drawn, everything added since gets three.js's material rules (its materials are set by then)
func _flush_fresh() -> void:
	for n in _fresh:
		if not is_instance_valid(n): continue
		Gfx.three_like(n)
		var a: Node = n.get_parent(); var sh = null   # (a body marked "shadow" says whether what is on it casts: see Enemies.cast_shadow)
		while a != null:
			if sh == null and a.has_meta("shadow"): sh = a.get_meta("shadow")
			if a in caster_roots: MoonShadow.caster(n, sh != false); MoonShadow.no_receive(n); break
			if a == hand_root: (n as VisualInstance3D).layers = 1 << (Gfx.IN_HAND - 1); break
			a = a.get_parent()
	_fresh.clear()

static func lin(c) -> Color:  # a colour as three.js r128 used it (linear numbers), for Godot's sRGB colour properties
	return (c if c is Color else Color(c)).linear_to_srgb()
static func rgb(a: Array) -> Color:
	return Color(a[0], a[1], a[2])

# ---- sky, skyline, the ship at the quay: built once ----
var _port: Array[Node3D] = []   # the harbour backdrop: skyline, its windows, water, the ship (only at the docks)
var moon_spr: MeshInstance3D
var sun_spr: MeshInstance3D   # the low sun of 3-1: a glow 70 across, kept 330 m off along the sunlight from wherever you look

static func is_yard(n: int) -> bool: return n == 1 or n == 5 or n == 6

func _build_backdrop() -> void:
	var sunq := QuadMesh.new(); sunq.size = Vector2(70, 70); var sunm := StandardMaterial3D.new(); sunm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sunm.albedo_texture = Gfx.glow_tex(Color(1, 244 / 255.0, 214 / 255.0, 1), Color(1, 190 / 255.0, 110 / 255.0, 0.35)); sunm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sunm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; sunm.disable_fog = true; sunm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	sun_spr = MeshInstance3D.new(); sun_spr.mesh = sunq; sun_spr.material_override = sunm; sun_spr.visible = false; sun_spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sun_spr)
	var night := Node3D.new(); night.name = "Night"; add_child(night)
	# the skyline, its lit windows, the stars and the moon take no fog in the browser game: drawn after the fog layer
	var sil_a := Gfx.backdrop(Gfx.unlit(lin(Color(0.007, 0.009, 0.017)), false)); var sil_b := Gfx.backdrop(Gfx.unlit(lin(Color(0.011, 0.014, 0.026)), false))
	var st_a := SurfaceTool.new(); st_a.begin(Mesh.PRIMITIVE_TRIANGLES); var st_b := SurfaceTool.new(); st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var win := PackedVector3Array()
	for i in 52:
		var a := (i / 52.0) * TAU; var r := randf_range(200, 235); var h := randf_range(10, 50); var w := randf_range(10, 24)
		if cos(a) > 0.55: continue  # the sea side stays open
		var pos := Vector3(cos(a) * r, h / 2 - 2, sin(a) * r)
		var bm := BoxMesh.new(); bm.size = Vector3(w, h, randf_range(10, 20))
		var xf := Transform3D(Basis.IDENTITY, pos).looking_at(Vector3(0, h / 2, 0), Vector3.UP)
		(st_b if i % 3 else st_a).append_from(bm, 0, xf)
		for k in int(h / 4):
			if randf() < 0.3: win.push_back(Vector3(pos.x + randf_range(-w / 2, w / 2) * 0.8, randf_range(1, h - 2), pos.z + randf_range(-3, 3)))
	for pair in [[st_a, sil_a], [st_b, sil_b]]:
		var mi := MeshInstance3D.new(); mi.mesh = pair[0].commit(); mi.material_override = pair[1]; night.add_child(mi); _port.push_back(mi)
	var wins := Gfx.points(win, lin("ffc27a"), 2.0); night.add_child(wins); _port.push_back(wins)
	var stars := PackedVector3Array()
	for i in 600:
		var a := randf() * TAU; var e := randf_range(0.12, 1.4)
		stars.push_back(Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 300.0)
	night.add_child(Gfx.points(stars, lin("8090b8"), 1.3, 0.7))
	var mq := QuadMesh.new(); mq.size = Vector2(62, 62)
	var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.albedo_texture = Gfx.moon_tex(); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mm.disable_fog = true; mm.no_depth_test = false
	var ms := MeshInstance3D.new(); ms.mesh = mq; ms.material_override = mm; ms.position = Vector3(-130, 160, -160); night.add_child(ms); moon_spr = ms
	# water and a container ship moored beyond the quay (east side)
	var wp := PlaneMesh.new(); wp.size = Vector2(260, 420)
	var water := MeshInstance3D.new(); water.mesh = wp; water.material_override = Gfx.std(lin("0a1626"), 0.25, 0.2); water.position = Vector3(197, -2.4, 0); night.add_child(water); _port.push_back(water)
	var hull := MeshInstance3D.new(); hull.mesh = Gfx.merge_boxes([[32, 15, 230, 0, 5, 0], [26, 4, 20, 0, 4, 118], [24, 26, 18, 0, 25, 88], [18, 8, 12, 0, 42, 88]])
	hull.material_override = Gfx.std(lin("2a1f22"), 0.8, 0.3); hull.position = Vector3(96, 0, 0); night.add_child(hull); _port.push_back(hull)
	var xf := []; var cols := []
	var z := -100.0
	while z < 75 and xf.size() < 360:
		var x := -13.0
		while x <= 13 and xf.size() < 360:
			for k in 2 + randi() % 4:
				if xf.size() >= 360: break
				xf.push_back(Transform3D(Basis.IDENTITY, Vector3(96 + x, 13.8 + k * 2.6, z)))
				var c := Color(CONT_COLORS[randi() % 8]); cols.push_back(lin(Color(c.r * 0.7, c.g * 0.7, c.b * 0.7)))   # (an instance colour is read as a screen colour)
			x += 2.5
		z += 12.6
	var bm2 := BoxMesh.new(); bm2.size = Vector3(2.44, 2.59, 12.19)
	var deck := Gfx.multimesh(bm2, xf, cols); var dm := Gfx.std(lin("5a3a34"), 0.7); dm.vertex_color_use_as_albedo = true; deck.material_override = dm; night.add_child(deck); _port.push_back(deck)
	var bw := PackedVector3Array()
	for i in 80: bw.push_back(Vector3(96 + randf_range(-12, 12), randf_range(14, 36), 79 - randf_range(0, 0.5)))
	var bwp := Gfx.points(bw, lin("fff0c8"), 2.2, 1.0, true); night.add_child(bwp); _port.push_back(bwp)   # the ship's windows do take fog
	var mast := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.7; sm.height = 1.4; sm.radial_segments = 8; sm.rings = 6
	mast.mesh = sm; mast.material_override = Gfx.backdrop(Gfx.unlit(lin("ff3a3a"), false)); mast.position = Vector3(96, 47, 88); night.add_child(mast); _backdrop_blink.push_back(mast); _port.push_back(mast)

func dispose() -> void:
	if group: group.queue_free(); group = null
	Phys.clear(); crates.clear(); lamps.clear(); blink = _backdrop_blink.duplicate(); crate_mm = null; crate_mmi = null; crate_xf = []; toy = null; village = null; lab = null; safari = null; ship = null; fire_mats.clear()

func build_stage(stage: int) -> void:
	dispose()
	var S: Dictionary = STAGE_STYLE[stage]; style = S
	if grade: grade.tune(S)
	var R := Rng.new(S.seed)
	var G := Node3D.new(); G.name = "Stage"; add_child(G); group = G
	# light and air, as the browser game sets them for the stage
	var e: float = S.get("exposure", 1.15); var fogc := Vector3(S.fog[0], S.fog[1], S.fog[2])
	env.tonemap_exposure = Gfx.exposure(e); env.tonemap_white = Gfx.TONE_WHITE; Fx.exposure = e
	sky_mat.set_shader_parameter("horizon", fogc)
	sky_mat.set_shader_parameter("zenith", Vector3(S.zenith[0], S.zenith[1], S.zenith[2]))
	sky_mat.set_shader_parameter("glow", Vector3(S.glow[0], S.glow[1], S.glow[2]))
	var fog_scene := Gfx.scene_for(fogc, e)   # three.js mixed the fog colour into the finished picture; this scene colour tone maps to it
	fog_mat.set_shader_parameter("col", Gfx.albedo_of(fog_scene)); fog_mat.set_shader_parameter("density", float(S.density))
	env.fog_light_color = Color(fog_scene.x, fog_scene.y, fog_scene.z).linear_to_srgb(); env.fog_depth_end = sqrt(3.0) / S.density
	var hs := Color(S.hemi[0]); var hg := Color(S.hemi[1]); var hi: float = S.hemi[2]
	env.ambient_light_color = lin(Color((hs.r + hg.r) / 2, (hs.g + hg.g) / 2, (hs.b + hg.b) / 2)); env.ambient_light_energy = hi
	var half := lin(Color((hs.r - hg.r) / 2, (hs.g - hg.g) / 2, (hs.b - hg.b) / 2))
	hemi_up.light_color = half; hemi_dn.light_color = half; hemi_up.light_energy = hi; hemi_dn.light_energy = hi
	moon.light_color = lin(S.moon[0]); moon.light_energy = S.moon[1]
	var off: Array = S.get("sunOff", [-30, 50, -20])
	moon.look_at_from_position(Vector3(off[0], off[1], off[2]), Vector3.ZERO, Vector3.UP)
	# the shadow layer works the light out as the browser game does: colour numbers as linear, times the intensity
	var mc := Color(S.moon[0]); shadow_mat.set_shader_parameter("moon_col", Vector3(mc.r, mc.g, mc.b) * float(S.moon[1]))
	shadow_mat.set_shader_parameter("moon_dir", Vector3(off[0], off[1], off[2]).normalized())
	shadow_mat.set_shader_parameter("hemi_sky", Vector3(hs.r, hs.g, hs.b) * hi); shadow_mat.set_shader_parameter("hemi_ground", Vector3(hg.r, hg.g, hg.b) * hi)
	var lamp_c := Color(S.lamp[0]); shadow_mat.set_shader_parameter("lamp_col", Vector3(lamp_c.r, lamp_c.g, lamp_c.b)); shadow_mat.set_shader_parameter("exposure", Gfx.exposure(e))
	_shadow_off = off; moon_shadow.place(start.x, start.z, off)
	moon.shadow_enabled = false; shadow_layer.visible = true; moon_shadow.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ao_mat.set_shader_parameter("strength", ao.tune(S)); ao_mat.set_shader_parameter("exposure", Gfx.exposure(e)); set_ao(use_ao)
	for l in lights: l.light_color = lin(S.lamp[0]); l.light_energy = 0.0; l.set_meta("on", false)
	_lamp_t = 0.0
	(get_node("Night") as Node3D).visible = not S.get("toy", false)
	sun_spr.visible = S.get("day", false)
	if S.get("toy", false):
		# stage 5 is this port's own room, not the browser game's: it keeps the light it was made with
		env.tonemap_white = 1.0; env.tonemap_exposure = e; fog_mat.set_shader_parameter("density", 0.0)
		env.ambient_light_color = Color(S.hemi[0]).lerp(Color(S.hemi[1]), 0.35); env.ambient_light_energy = S.hemi[2]; env.fog_depth_end = 400.0; moon.light_color = Color(S.moon[0])
		hemi_up.light_energy = 0.0; hemi_dn.light_energy = 0.0
		moon.shadow_enabled = true; shadow_layer.visible = false; moon_shadow.render_target_update_mode = SubViewport.UPDATE_DISABLED; set_ao(false)
		toy = ToyRoom.new(); toy.build(self, G); return
	(get_node("Night") as Node3D).visible = not S.get("day", false) and not S.get("indoor", false)
	# the harbour skyline and ship only belong to the docks; the village gets the stars and a bigger moon
	for p in _port: p.visible = is_yard(stage)
	(moon_spr.mesh as QuadMesh).size = Vector2.ONE * (92.0 if stage == 2 else 62.0)   # (a billboard keeps no node scale)
	if not is_yard(stage): blink.clear()
	if S.get("ship", false): Phys.set_world_size(166.0); Phys.set_nav(334, 1.0); ship = Ship.new(); ship.build(self, G, S, R); return
	if S.get("lab", false): Phys.set_world_size(Lab.HALF + 1); Phys.set_nav(int(2 * Lab.HALF + 8), 1.0); lab = Lab.new(); lab.build(self, G, S, R); return
	if S.get("savanna", false): Phys.set_world_size(178.0); Phys.set_nav(180, 2.0); safari = Safari.new(); safari.build(self, G, S, R); return
	Phys.set_world_size(66.0); Phys.set_nav(140, 1.0)
	if stage == 2: village = Village.new(); village.build(self, G, S, R); return

	var gm := PlaneMesh.new(); gm.size = Vector2(240, 240)
	var gmat := Gfx.std(Color.WHITE, 0.93, 0.0, _tex.asphalt); gmat.uv1_scale = Vector3(22, 22, 1)
	var ground := MeshInstance3D.new(); ground.mesh = gm; ground.material_override = gmat; G.add_child(ground)

	# perimeter: concrete walls on three sides, the quay edge to the east
	var E := 67.0
	var wall_mat := Gfx.std(Color.WHITE, 0.95, 0.0, _tex.concrete); wall_mat.uv1_scale = Vector3(34, 1, 1)
	for w: Array in [[0.0, -E - 0.6, 2 * E + 2, 1.2], [0.0, E + 0.6, 2 * E + 2, 1.2], [-E - 0.6, 0.0, 1.2, 2 * E + 2]]:
		var wx: float = w[0]; var wz: float = w[1]; var wsx: float = w[2]; var wsz: float = w[3]
		var m := MeshInstance3D.new(); m.mesh = Gfx.box(Vector3(wsx, 4.2, wsz)); m.material_override = wall_mat; m.position = Vector3(wx, 2.1, wz); G.add_child(m)
		Phys.add_collider(wx - wsx / 2, 0, wz - wsz / 2, wx + wsx / 2, 10, wz + wsz / 2, "concrete")
	var curb := MeshInstance3D.new(); curb.mesh = Gfx.box(Vector3(1, 0.45, 2 * E + 2)); curb.material_override = Gfx.std(lin("c9c6bd"), 0.95, 0.0, _tex.concrete); curb.position = Vector3(E + 0.2, 0.22, 0); G.add_child(curb)
	Phys.add_collider(E - 0.3, 0, -E - 1, E + 1.5, 10, E + 1, "concrete")
	var bol := CylinderMesh.new(); bol.top_radius = 0.22; bol.bottom_radius = 0.28; bol.height = 0.7; bol.radial_segments = 10
	var bx := []
	for i in 12: bx.push_back(Transform3D(Basis.IDENTITY, Vector3(E - 0.1, 0.8, -60 + i * 11)))
	var bolm := Gfx.multimesh(bol, bx); bolm.material_override = Gfx.std(lin("23262b"), 0.6, 0.5); G.add_child(bolm)

	# blocks of container stacks with lanes between them
	var place := []
	var stack := func(x: float, z: float, long: bool, axis: String, h: int) -> void:
		var L := 12.19 if long else 6.06
		var hx := L / 2 if axis == "x" else 1.22; var hz := 1.22 if axis == "x" else L / 2
		if h == 0:
			var q := R.next(); h = 1 if q < 0.28 else (2 if q < 0.74 else 3)
		for lv in h: place.push_back({"x": x, "z": z, "long": long, "lv": lv, "ci": int(floor(R.next() * 8)), "axis": axis})
		Phys.add_collider(x - hx, 0, z - hz, x + hx, h * 2.59, z + hz, "metal")
	for bx_: float in [-48.0, -24.0, 0.0, 24.0, 48.0]:
		for bz: float in [-44.0, -22.0, 0.0, 22.0, 44.0]:
			if (bx_ == 0.0 and bz == 0.0) or R.next() < S.empty: continue
			for k in 4:
				var z := bz - 3.66 + k * 2.44; var p := R.next()
				if p < 0.12: continue
				if p < 0.34:
					if R.next() > 0.15: stack.call(bx_ - 3.05, z, false, "x", 0)
					if R.next() > 0.15: stack.call(bx_ + 3.05, z, false, "x", 0)
				else: stack.call(bx_, z, true, "x", 0)

	# rubber-tyred gantry cranes straddling some blocks
	var crane_mat := Gfx.std(lin("c9a227"), 0.6, 0.3); var blink_mat := Gfx.backdrop(Gfx.unlit(lin("ff3a3a"), false))
	for c: Array in ([[-24.0, -22.0], [24.0, 22.0], [-48.0, 22.0], [48.0, -22.0]] if stage == 1 else [[24.0, 22.0], [-24.0, -22.0], [48.0, 22.0]]):
		var cx: float = c[0]; var cz: float = c[1]; var parts := []
		for sx: int in [-1, 1]:
			for sz: int in [-1, 1]:
				parts.push_back([0.9, 21, 0.9, sx * 8.5, 10.5, sz * 6.6])
				Phys.add_collider(cx + sx * 8.5 - 0.45, 0, cz + sz * 6.6 - 0.45, cx + sx * 8.5 + 0.45, 21, cz + sz * 6.6 + 0.45, "metal")
		parts.append_array([[18.8, 1.3, 1.3, 0, 21, -6.6], [18.8, 1.3, 1.3, 0, 21, 6.6], [1.3, 1.3, 14.5, -8.5, 21, 0], [1.3, 1.3, 14.5, 8.5, 21, 0]])
		parts.append_array([[4, 2, 4, R.rng(-5, 5), 22.6, 0], [2.2, 2.2, 2.2, 8.5, 17.5, -4.8], [1.6, 0.6, 3.6, -8.5, 0.6, 0], [1.6, 0.6, 3.6, 8.5, 0.6, 0]])
		var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); m.material_override = crane_mat; m.position = Vector3(cx, 0, cz); G.add_child(m); MoonShadow.caster(m)
		var bl := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.4; sm.height = 0.8; sm.radial_segments = 8; sm.rings = 6
		bl.mesh = sm; bl.material_override = blink_mat; bl.position = Vector3(cx, 22.3, cz - 6.6); G.add_child(bl); blink.push_back(bl)

	# lamp towers: many posts, the six nearest the player get real lights
	var lamp_spots := []
	for x: float in [-36.0, -12.0, 12.0, 36.0]:
		for z: float in [-33.0, -11.0, 11.0, 33.0]:
			if not Phys.occupied(x - 0.3, z - 0.3, x + 0.3, z + 0.3, 0.5): lamp_spots.push_back([x, z])
	var pole_x := []; var head_x := []; var cone_x := []; var pool_x := []
	for s: Array in lamp_spots:
		var lx: float = s[0]; var lz: float = s[1]
		pole_x.push_back(Transform3D(Basis.IDENTITY, Vector3(lx, 8, lz))); Phys.add_collider(lx - 0.25, 0, lz - 0.25, lx + 0.25, 16, lz + 0.25, "metal")
		head_x.push_back(Transform3D(Basis.IDENTITY, Vector3(lx + 0.6, 15.9, lz)))
		cone_x.push_back(Transform3D(Basis.IDENTITY, Vector3(lx + 0.6, 8.2, lz)))
		pool_x.push_back(Transform3D(Basis.IDENTITY, Vector3(lx + 0.6, 0.03, lz)))
		lamps.push_back({"x": lx + 0.6, "y": 15.2, "z": lz})
	var pm := CylinderMesh.new(); pm.top_radius = 0.16; pm.bottom_radius = 0.22; pm.height = 16; pm.radial_segments = 8
	var poles := Gfx.multimesh(pm, pole_x); poles.material_override = Gfx.std(lin("3a3f48"), 0.6, 0.6); G.add_child(poles); MoonShadow.caster(poles)
	var hm := BoxMesh.new(); hm.size = Vector3(1.4, 0.3, 0.7)
	var heads := Gfx.multimesh(hm, head_x); heads.material_override = Gfx.unlit(lin("ffd08a")); G.add_child(heads)
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 6.5; cm.height = 15; cm.radial_segments = 24; cm.cap_top = false; cm.cap_bottom = false
	var csh := Shader.new()
	csh.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled; uniform vec3 col; uniform float op; varying float h;\n" + Gfx.ALBEDO_GLSL \
		+ "void vertex(){ h = (VERTEX.y + 7.5) / 15.0; }\nvoid fragment(){ float t = 1.0 - h; float s = t < 0.5 ? mix(1.0, 0.33333, t * 2.0) : mix(0.33333, 0.0, t * 2.0 - 1.0);\n" \
		+ "\tfloat g = s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4); ALBEDO = albedo_of(col * g); ALPHA = op; }"
	var cmat := ShaderMaterial.new(); cmat.shader = csh; var lc := Color(S.lamp[0]); cmat.set_shader_parameter("col", Vector3(lc.r, lc.g, lc.b)); cmat.set_shader_parameter("op", 0.1)
	var cones := Gfx.multimesh(cm, cone_x); cones.material_override = cmat; cones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; G.add_child(cones)
	var plm := PlaneMesh.new(); plm.size = Vector2(18, 18)
	var pmat := StandardMaterial3D.new(); pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pmat.albedo_texture = _tex.pool; pmat.albedo_color = lin(S.lamp[0])
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; pmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var pools := Gfx.multimesh(plm, pool_x); pools.material_override = pmat; pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; G.add_child(pools)

	# single containers dropped across lanes
	var i := 0; var tries := 0
	while i < S.singles and tries < 300:
		tries += 1
		var x := R.rng(-58, 58); var z := R.rng(-58, 58); var axis := "z" if R.next() < 0.5 else "x"
		var hx := 3.05 if axis == "x" else 1.22; var hz := 1.22 if axis == "x" else 3.05
		if Vector2(x, z - 6).length() < 14 or Phys.occupied(x - hx, z - hz, x + hx, z + hz, 3): continue
		stack.call(x, z, false, axis, 1 if R.next() < 0.6 else 2); i += 1
	# jersey barriers: a ring around the plaza plus some in the lanes
	var bar := [[-6.0, -3.0, "x"], [6.0, -3.0, "x"], [-9.0, 6.0, "z"], [9.0, 6.0, "z"], [0.0, 13.0, "x"], [-3.0, -12.0, "x"], [4.0, -14.0, "z"]]
	i = 0; tries = 0
	while i < 16 and tries < 300:
		tries += 1
		var x := R.rng(-60, 60); var z := R.rng(-60, 60); var a := "x" if R.next() < 0.5 else "z"
		if Phys.occupied(x - 1.6, z - 1.6, x + 1.6, z + 1.6, 1.2): continue
		bar.push_back([x, z, a]); i += 1
	var bar_x := []
	for b: Array in bar:
		var bx0: float = b[0]; var bz0: float = b[1]
		bar_x.push_back(Transform3D(Basis(Vector3.UP, PI / 2 if b[2] == "x" else 0.0), Vector3(bx0, 0, bz0)))
		if b[2] == "x": Phys.add_collider(bx0 - 1.5, 0, bz0 - 0.3, bx0 + 1.5, 0.82, bz0 + 0.3, "concrete")
		else: Phys.add_collider(bx0 - 0.3, 0, bz0 - 1.5, bx0 + 0.3, 0.82, bz0 + 1.5, "concrete")
	var bars := Gfx.multimesh(_jersey_mesh(), bar_x); var jm := Gfx.std(lin("d8d6cf"), 0.95, 0.0, _tex.concrete); jm.cull_mode = BaseMaterial3D.CULL_DISABLED; bars.material_override = jm; G.add_child(bars); MoonShadow.caster(bars)

	# wooden crates all over the yard
	_place_crates(G, S.crates, func() -> Array: return [R.rng(-62, 62), R.rng(-62, 62)],
		func(x: float, z: float) -> bool: return Vector2(x, z - 6).length() >= 5 and not Phys.occupied(x - 0.6, z - 0.6, x + 0.6, z + 0.6, 0.35))

	# lane paint
	var dash_x := []
	for z: float in [-33.0, -11.0, 11.0, 33.0]:
		for t in range(-64, 65, 4):
			if not Phys.occupied(t - 0.1, z - 0.1, t + 0.1, z + 0.1, 0): dash_x.push_back(Transform3D(Basis.IDENTITY, Vector3(t, 0.012, z)))
	for x: float in [-36.0, -12.0, 12.0, 36.0]:
		for t in range(-64, 65, 4):
			if not Phys.occupied(x - 0.1, t - 0.1, x + 0.1, t + 0.1, 0): dash_x.push_back(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(x, 0.012, t)))
	var dmesh := PlaneMesh.new(); dmesh.size = Vector2(2.2, 0.16)
	var dashes := Gfx.multimesh(dmesh, dash_x); dashes.material_override = Gfx.std(lin("c9962c"), 0.85); dashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; G.add_child(dashes)
	# the yard number painted on the ground: the browser game's canvas "07", lit like the asphalt it lies on
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	Gfx.text(img, "07", load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"), 96, 128, 68, "center", "middle", Color8(201, 150, 44, 230))
	var lm := Gfx.std(Color(1, 1, 1, 0.6 if stage == 2 else 1.0), 0.85, 0.0, Gfx.tex(img)); lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; lm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var lp := PlaneMesh.new(); lp.size = Vector2(10, 5)
	var lbl := MeshInstance3D.new(); lbl.mesh = lp; lbl.material_override = lm; lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; lbl.position = Vector3(0, 0.014, 1); G.add_child(lbl)

	# containers, one batch per colour and length
	var groups := {}
	for p: Dictionary in place:
		var k: String = "%d_%d" % [p.ci, 1 if p.long else 0]
		if not groups.has(k): groups[k] = []
		groups[k].push_back(p)
	var door_m := {}; var top_m := {}
	var serial := 418203 + stage * 1111
	for k: String in groups:
		var list: Array = groups[k]; var ci: int = list[0].ci; var long: bool = list[0].long; var color := Color(CONT_COLORS[ci])
		serial = (serial * 7 + 1301) % 1000000
		var owner: String = OWNERS[(ci * 3 + (1 if long else 0)) % OWNERS.size()]
		var mesh := Gfx.box3(12.19 if long else 6.06, 2.59, 2.44)
		if not door_m.has(ci): door_m[ci] = Gfx.std(Color.WHITE, 0.62, 0.3, Gfx.door_tex(color)); top_m[ci] = Gfx.std(lin(Gfx.shade(color, 0.75)), 0.75, 0.25)
		mesh.surface_set_material(0, door_m[ci]); mesh.surface_set_material(1, top_m[ci]); mesh.surface_set_material(2, Gfx.std(Color.WHITE, 0.62, 0.3, Gfx.side_tex(color, Store.iso_code(owner, serial), owner, long)))
		var xs := []
		for p: Dictionary in list: xs.push_back(Transform3D(Basis(Vector3.UP, PI / 2 if p.axis == "z" else 0.0), Vector3(p.x, 1.295 + p.lv * 2.59, p.z)))
		var cmm := Gfx.multimesh(mesh, xs); G.add_child(cmm); MoonShadow.caster(cmm)

	Phys.index_colliders(); Phys.build_nav()
	spawns.clear()
	for x: float in [-61.0, -36.0, -12.0, 12.0, 36.0, 61.0]:
		for z: float in [-61.0, -33.0, -11.0, 11.0, 33.0, 61.0]:
			if Phys.nav_blocked[Phys.nav_i(z) * Phys.nav_n + Phys.nav_i(x)] == 0 and Vector2(x, z).length() > 14: spawns.push_back({"x": x, "z": z})
	start = {"x": 0.0, "z": 6.0, "yaw": 0.0}

func _jersey_mesh() -> ArrayMesh:
	var prof := PackedVector2Array([Vector2(-0.32, 0), Vector2(0.32, 0), Vector2(0.3, 0.08), Vector2(0.12, 0.3), Vector2(0.1, 0.82), Vector2(-0.1, 0.82), Vector2(-0.12, 0.3), Vector2(-0.3, 0.08)])
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := prof.size()
	for i in n:
		var a := prof[i]; var b := prof[(i + 1) % n]; var u0 := float(i) / n; var u1 := float(i + 1) / n
		var v := [Vector3(a.x, a.y, -1.5), Vector3(b.x, b.y, -1.5), Vector3(b.x, b.y, 1.5), Vector3(a.x, a.y, 1.5)]; var uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 3), Vector2(u0, 3)]
		for t: int in [0, 1, 2, 0, 2, 3]: st.set_uv(uv[t]); st.add_vertex(v[t])
	var tri := Geometry2D.triangulate_polygon(prof)
	for zc: float in [-1.5, 1.5]:
		for t in tri: st.set_uv(prof[t]); st.add_vertex(Vector3(prof[t].x, prof[t].y, zc))
	st.generate_normals()
	return st.commit()

func _place_crates(G: Node3D, count: int, cand: Callable, fits: Callable, with_y := false) -> void:
	var xs := []; var i := 0; var tries := 0
	while i < count and tries < count * 40:
		tries += 1
		var c: Array = cand.call(); var x: float = c[0]; var z: float = c[1]
		var y: float = c[2] if with_y else 0.0
		if not (fits.call(x, z, y) if with_y else fits.call(x, z)): continue
		xs.push_back(Transform3D(Basis(Vector3.UP, randf_range(-0.2, 0.2)), Vector3(x, y + 0.6, z)))
		var cr := {"idx": i, "hp": 45.0, "x": x, "z": z, "y": y, "dead": false}
		cr.b = Phys.add_collider(x - 0.6, y, z - 0.6, x + 0.6, y + 1.2, z + 0.6, "wood", cr); crates.push_back(cr); i += 1
	var mmi := Gfx.multimesh(Gfx.box(Vector3(1.2, 1.2, 1.2)), xs); mmi.material_override = Gfx.std(Color.WHITE, 0.9, 0.0, _tex.crate); G.add_child(mmi); MoonShadow.caster(mmi); crate_mm = mmi.multimesh; crate_mmi = mmi; crate_xf = xs.duplicate()

## a broken crate gone from the picture: the crates are drawn again from a new MultiMesh (one changed in place does not
## always reach the screen on the web renderer, and the broken crate stayed in view)
func hide_crate(c: Dictionary) -> void:
	if crate_mm == null or c.idx >= crate_xf.size(): return
	crate_xf[c.idx] = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(c.x, -5, c.z))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = crate_mm.mesh; mm.instance_count = crate_xf.size()
	for i in crate_xf.size(): mm.set_instance_transform(i, crate_xf[i])
	crate_mm = mm
	if is_instance_valid(crate_mmi): crate_mmi.multimesh = mm

func damage_crate(c: Dictionary, dmg: float, _at: Vector3) -> void:
	if c.dead: return
	c.hp -= dmg
	if fx: fx.sparks(_at, 4, [0.85, 0.65, 0.4], 2.5)
	if c.hp > 0.0: return
	c.dead = true
	if c.has("node"):   # a brick wall: its own node
		if is_instance_valid(c.node): (c.node as Node3D).queue_free()
	else: hide_crate(c)
	Phys.remove_collider(c.b); Phys.nav_patch(c.b.minx, c.b.minz, c.b.maxx, c.b.maxz)  # just round it, not the whole grid
	var at := Vector3(c.x, c.y + 0.6, c.z)
	if fx: fx.chunks(at, 9, 0.28, "wood"); fx.puff(at, 4, 0.35, 0.6)
	Snd.play("crack", 1.0, at)
	if on_crate.is_valid(): on_crate.call(c)

func update_world(dt: float, t: float, px: float, pz: float) -> void:
	moon_shadow.place(px, pz, _shadow_off)   # the shadow box goes with the player, as the browser game's
	_lamp_t -= dt
	if _lamp_t <= 0.0:   # the six lights go to the six nearest lamps
		_lamp_t = 0.35
		var near := lamps.duplicate()
		near.sort_custom(func(a, b): return (a.x - px) * (a.x - px) + (a.z - pz) * (a.z - pz) < (b.x - px) * (b.x - px) + (b.z - pz) * (b.z - pz))
		for i in lights.size():
			lights[i].set_meta("on", i < near.size())
			if i < near.size(): lights[i].position = Vector3(near[i].x, near[i].y, near[i].z)
	for i in lights.size():
		var k: float = style.lamp[1] if lights[i].get_meta("on", false) else 0.0
		if style.get("flicker", false) and k > 0.0: k *= 0.85 if steady else (0.2 if sin(t * 17.0 + i * 5.3) > 0.94 else 1.0) * (0.85 + 0.15 * sin(t * 2.7 + i))
		if style.get("fire", false) and k > 0.0: k *= 0.72 if steady else 0.72 + 0.18 * sin(t * 13.0 + i * 2.1) + 0.1 * sin(t * 29.0 + i * 5.7)
		lights[i].light_energy = k * LAMP_K * lamp_scale
	for m in fire_mats: (m as ShaderMaterial).set_shader_parameter("ft", t)   # the fires burn on
	for i in blink.size(): blink[i].visible = fmod(t + i * 0.3, 1.8) < 0.25
