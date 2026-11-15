class_name World
extends Node3D
## The yard for each stage. Ported from src/04a_world.js and src/04c_stage.js: the same seeded random numbers in the same
## order, so every container, crate and lamp stands where it does in the browser game (tests/run.gd checks this).

const CONT_COLORS := ["8c3a2b", "2c4f7c", "356b45", "c4682a", "7b8288", "2f7a7a", "6a2a35", "b8ab8a"]
const OWNERS := ["YRD", "KJT", "HWS", "SLV", "PRC", "DGN", "TRV", "BNK"]
const STAGE_STYLE := {
	# stage 5, the toy room: a sunny bedroom, bright and warm
	9: {"toy": true, "fog": [0.55, 0.62, 0.68], "density": 0.004, "zenith": [0.55, 0.62, 0.68], "glow": [0.0, 0.0, 0.0], "hemi": ["ffffff", "cdb99a", 0.5], "moon": ["fff1d6", 0.62], "lamp": ["ffffff", 0.0], "seed": 77, "crates": 0, "sunOff": [30, 60, 34], "exposure": 0.95},
	# 1-2: the same docks later that night, a little colder, laid out differently
	5: {"fog": [0.024, 0.031, 0.052], "density": 0.016, "zenith": [0.005, 0.008, 0.019], "glow": [0.05, 0.03, 0.03], "hemi": ["5a6c98", "2a2422", 0.6], "moon": ["a8bcff", 0.44], "lamp": ["ffb060", 1.8], "seed": 11, "crates": 40, "singles": 14, "empty": 0.12},
	# 1-1: the docks again, another night, another layout, mist over the water
	6: {"fog": [0.03, 0.034, 0.05], "density": 0.018, "zenith": [0.007, 0.008, 0.016], "glow": [0.07, 0.04, 0.024], "hemi": ["5f6f92", "2b2420", 0.6], "moon": ["b0c0ff", 0.42], "lamp": ["ffa040", 1.85], "seed": 19, "crates": 40, "singles": 12, "empty": 0.1},
	# the village: deep blue night, a big moon, fires flickering orange
	2: {"fog": [0.018, 0.024, 0.04], "density": 0.019, "zenith": [0.004, 0.007, 0.02], "glow": [0.07, 0.03, 0.008], "hemi": ["4c5c86", "1a1914", 0.42], "moon": ["c4d6ff", 0.62], "lamp": ["ff7a30", 2.6],
		"seed": 23, "crates": 46, "fire": true, "sunOff": [-40, 49, -49]},
	# inside the spaceship: dark plating, cold blue-white light
	4: {"indoor": true, "ship": true, "fog": [0.012, 0.016, 0.026], "density": 0.011, "zenith": [0.004, 0.006, 0.012], "glow": [0.02, 0.03, 0.05], "hemi": ["8aa0d0", "34363e", 0.85], "moon": ["e2ecff", 0.75], "lamp": ["9fd4ff", 1.5],
		"seed": 61, "crates": 24, "sunOff": [-18, 70, 22], "exposure": 1.1, "lampMul": 1.0},
	# the sealed lab: cold fluorescent light from above, a pale tiled floor
	3: {"indoor": true, "lab": true, "ride": true, "fog": [0.02, 0.026, 0.032], "density": 0.008, "zenith": [0.004, 0.006, 0.01], "glow": [0.02, 0.03, 0.04], "hemi": ["dfe8f0", "5a6066", 0.95], "moon": ["f4f8ff", 0.95], "lamp": ["e6f2ff", 2.2],
		"seed": 41, "crates": 40, "sunOff": [-12, 70, 18], "exposure": 0.8, "lampMul": 0.4},
	# 3-2: the same lab on the night shift: a little cooler and dimmer, another layout of crates
	8: {"indoor": true, "lab": true, "ride": true, "seq": true, "fog": [0.016, 0.022, 0.03], "density": 0.009, "zenith": [0.004, 0.006, 0.01], "glow": [0.02, 0.03, 0.04], "hemi": ["d4e0f0", "4e5660", 0.85], "moon": ["e8f0ff", 0.85], "lamp": ["d8e8ff", 2.0],
		"seed": 43, "crates": 40, "sunOff": [-12, 70, 18], "exposure": 0.76, "lampMul": 0.4},
	# 3-1: the old safari at golden hour, a low sun, warm haze over the grass
	7: {"day": true, "savanna": true, "ride": true, "fog": [0.30, 0.25, 0.17], "density": 0.0058, "zenith": [0.10, 0.20, 0.42], "glow": [0.55, 0.28, 0.08], "hemi": ["b0c4e0", "6b5a3a", 0.62], "moon": ["ffd7a8", 1.0], "exposure": 0.6,
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
var lamps: Array = []       # {x, y, z}
var blink: Array = []
var lights: Array[OmniLight3D] = []
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
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
var flames: Array = []   # stage 5's room and its gimmicks
var _backdrop_blink: Array = []
var _tex := {}

func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sh := Shader.new()
	sh.code = "shader_type sky; uniform vec3 horizon; uniform vec3 zenith; uniform vec3 glow;\nvoid sky(){ float h = EYEDIR.y; vec3 c = mix(horizon, zenith, smoothstep(0.0, 0.6, h)); c += glow * exp(-max(h, 0.0) * 12.0) * smoothstep(-0.08, 0.0, h); COLOR = c; }"
	sky_mat = ShaderMaterial.new(); sky_mat.shader = sh
	var sky := Sky.new(); sky.sky_material = sky_mat; sky.radiance_size = Sky.RADIANCE_SIZE_32; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.glow_enabled = true; env.glow_intensity = 0.5; env.glow_bloom = 0.05; env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	moon = DirectionalLight3D.new(); moon.shadow_enabled = true; moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 80.0; moon.shadow_bias = 0.06; moon.shadow_normal_bias = 1.5; add_child(moon)
	for i in 6:
		var l := OmniLight3D.new(); l.omni_range = 30.0; l.omni_attenuation = 1.0; l.light_energy = 0.0; l.shadow_enabled = false; add_child(l); lights.push_back(l)
	_tex.asphalt = Gfx.asphalt_tex(); _tex.concrete = Gfx.concrete_tex(); _tex.crate = Gfx.crate_tex()
	_tex.pool = Gfx.glow_tex(Color(1, 0.784, 0.549, 0.5), Color(1, 0.627, 0.314, 0.16))
	_build_backdrop()

static func lin(c) -> Color:  # a colour as three.js r128 used it (linear numbers), for Godot's sRGB colour properties
	return (c if c is Color else Color(c)).linear_to_srgb()
static func rgb(a: Array) -> Color:
	return Color(a[0], a[1], a[2])

# ---- sky, skyline, the ship at the quay: built once ----
func _build_backdrop() -> void:
	var night := Node3D.new(); night.name = "Night"; add_child(night)
	var sil_a := Gfx.unlit(lin(Color(0.007, 0.009, 0.017)), false); var sil_b := Gfx.unlit(lin(Color(0.011, 0.014, 0.026)), false)
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
		var mi := MeshInstance3D.new(); mi.mesh = pair[0].commit(); mi.material_override = pair[1]; night.add_child(mi)
	night.add_child(Gfx.points(win, lin("ffc27a"), 2.0))
	var stars := PackedVector3Array()
	for i in 600:
		var a := randf() * TAU; var e := randf_range(0.12, 1.4)
		stars.push_back(Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 300.0)
	night.add_child(Gfx.points(stars, lin("8090b8"), 1.3, 0.7))
	var mq := QuadMesh.new(); mq.size = Vector2(62, 62)
	var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.albedo_texture = Gfx.moon_tex(); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mm.disable_fog = true; mm.no_depth_test = false
	var ms := MeshInstance3D.new(); ms.mesh = mq; ms.material_override = mm; ms.position = Vector3(-130, 160, -160); night.add_child(ms)
	# water and a container ship moored beyond the quay (east side)
	var wp := PlaneMesh.new(); wp.size = Vector2(260, 420)
	var water := MeshInstance3D.new(); water.mesh = wp; water.material_override = Gfx.std(lin("0a1626"), 0.25, 0.2); water.position = Vector3(197, -2.4, 0); night.add_child(water)
	var hull := MeshInstance3D.new(); hull.mesh = Gfx.merge_boxes([[32, 15, 230, 0, 5, 0], [26, 4, 20, 0, 4, 118], [24, 26, 18, 0, 25, 88], [18, 8, 12, 0, 42, 88]])
	hull.material_override = Gfx.std(lin("2a1f22"), 0.8, 0.3); hull.position = Vector3(96, 0, 0); night.add_child(hull)
	var xf := []; var cols := []
	var z := -100.0
	while z < 75 and xf.size() < 360:
		var x := -13.0
		while x <= 13 and xf.size() < 360:
			for k in 2 + randi() % 4:
				if xf.size() >= 360: break
				xf.push_back(Transform3D(Basis.IDENTITY, Vector3(96 + x, 13.8 + k * 2.6, z)))
				var c := Color(CONT_COLORS[randi() % 8]); cols.push_back(Color(c.r * 0.7, c.g * 0.7, c.b * 0.7))
			x += 2.5
		z += 12.6
	var bm2 := BoxMesh.new(); bm2.size = Vector3(2.44, 2.59, 12.19)
	var deck := Gfx.multimesh(bm2, xf, cols); var dm := Gfx.std(lin("5a3a34"), 0.7); dm.vertex_color_use_as_albedo = true; deck.material_override = dm; night.add_child(deck)
	var bw := PackedVector3Array()
	for i in 80: bw.push_back(Vector3(96 + randf_range(-12, 12), randf_range(14, 36), 79 - randf_range(0, 0.5)))
	night.add_child(Gfx.points(bw, lin("fff0c8"), 2.2))
	var mast := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.7; sm.height = 1.4; sm.radial_segments = 8; sm.rings = 6
	mast.mesh = sm; mast.material_override = Gfx.unlit(lin("ff3a3a"), false); mast.position = Vector3(96, 47, 88); night.add_child(mast); _backdrop_blink.push_back(mast)

func dispose() -> void:
	if group: group.queue_free(); group = null
	Phys.clear(); crates.clear(); lamps.clear(); blink = _backdrop_blink.duplicate(); crate_mm = null; toy = null; village = null; lab = null; safari = null; ship = null; flames.clear()

func build_stage(stage: int) -> void:
	dispose()
	var S: Dictionary = STAGE_STYLE[stage]; style = S
	var R := Rng.new(S.seed)
	var G := Node3D.new(); G.name = "Stage"; add_child(G); group = G
	# light and air
	sky_mat.set_shader_parameter("horizon", Vector3(S.fog[0], S.fog[1], S.fog[2]))
	sky_mat.set_shader_parameter("zenith", Vector3(S.zenith[0], S.zenith[1], S.zenith[2]))
	sky_mat.set_shader_parameter("glow", Vector3(S.glow[0], S.glow[1], S.glow[2]))
	env.fog_light_color = lin(rgb(S.fog)); env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 4.0; env.fog_depth_end = 1.9 / S.density; env.fog_depth_curve = 1.5; env.fog_density = 1.0; env.fog_sky_affect = 0.0
	env.ambient_light_color = lin(Color(S.hemi[0]).lerp(Color(S.hemi[1]), 0.35)); env.ambient_light_energy = S.hemi[2] * 0.6
	moon.light_color = lin(S.moon[0]); moon.light_energy = S.moon[1]
	var off: Array = S.get("sunOff", [-30, 50, -20])
	moon.look_at_from_position(Vector3(off[0], off[1], off[2]), Vector3.ZERO, Vector3.UP)
	for l in lights: l.light_color = lin(S.lamp[0]); l.light_energy = 0.0
	_lamp_t = 0.0
	env.tonemap_exposure = S.get("exposure", 1.15); env.glow_enabled = not S.get("toy", false)
	(get_node("Night") as Node3D).visible = not S.get("toy", false)
	if S.get("toy", false):
		env.ambient_light_color = Color(S.hemi[0]).lerp(Color(S.hemi[1]), 0.35); env.ambient_light_energy = S.hemi[2]; env.fog_depth_end = 400.0; moon.light_color = Color(S.moon[0])
		toy = ToyRoom.new(); toy.build(self, G); return
	(get_node("Night") as Node3D).visible = not S.get("day", false) and not S.get("indoor", false)
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
		var bm := BoxMesh.new(); bm.size = Vector3(wsx, 4.2, wsz)
		var m := MeshInstance3D.new(); m.mesh = bm; m.material_override = wall_mat; m.position = Vector3(wx, 2.1, wz); G.add_child(m)
		Phys.add_collider(wx - wsx / 2, 0, wz - wsz / 2, wx + wsx / 2, 10, wz + wsz / 2, "concrete")
	var cb := BoxMesh.new(); cb.size = Vector3(1, 0.45, 2 * E + 2)
	var curb := MeshInstance3D.new(); curb.mesh = cb; curb.material_override = Gfx.std(lin("c9c6bd"), 0.95, 0.0, _tex.concrete); curb.position = Vector3(E + 0.2, 0.22, 0); G.add_child(curb)
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
	var crane_mat := Gfx.std(lin("c9a227"), 0.6, 0.3); var blink_mat := Gfx.unlit(lin("ff3a3a"), false)
	for c: Array in ([[-24.0, -22.0], [24.0, 22.0], [-48.0, 22.0], [48.0, -22.0]] if stage == 1 else [[24.0, 22.0], [-24.0, -22.0], [48.0, 22.0]]):
		var cx: float = c[0]; var cz: float = c[1]; var parts := []
		for sx: int in [-1, 1]:
			for sz: int in [-1, 1]:
				parts.push_back([0.9, 21, 0.9, sx * 8.5, 10.5, sz * 6.6])
				Phys.add_collider(cx + sx * 8.5 - 0.45, 0, cz + sz * 6.6 - 0.45, cx + sx * 8.5 + 0.45, 21, cz + sz * 6.6 + 0.45, "metal")
		parts.append_array([[18.8, 1.3, 1.3, 0, 21, -6.6], [18.8, 1.3, 1.3, 0, 21, 6.6], [1.3, 1.3, 14.5, -8.5, 21, 0], [1.3, 1.3, 14.5, 8.5, 21, 0]])
		parts.append_array([[4, 2, 4, R.rng(-5, 5), 22.6, 0], [2.2, 2.2, 2.2, 8.5, 17.5, -4.8], [1.6, 0.6, 3.6, -8.5, 0.6, 0], [1.6, 0.6, 3.6, 8.5, 0.6, 0]])
		var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); m.material_override = crane_mat; m.position = Vector3(cx, 0, cz); G.add_child(m)
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
	var poles := Gfx.multimesh(pm, pole_x); poles.material_override = Gfx.std(lin("3a3f48"), 0.6, 0.6); G.add_child(poles)
	var hm := BoxMesh.new(); hm.size = Vector3(1.4, 0.3, 0.7)
	var heads := Gfx.multimesh(hm, head_x); heads.material_override = Gfx.unlit(lin("ffd08a")); G.add_child(heads)
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 6.5; cm.height = 15; cm.radial_segments = 24; cm.cap_top = false; cm.cap_bottom = false
	var csh := Shader.new()
	csh.code = "shader_type spatial; render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled; uniform vec3 col; uniform float op; varying float h;\nvoid vertex(){ h = (VERTEX.y + 7.5) / 15.0; }\nvoid fragment(){ float g = h < 0.5 ? mix(0.0, 0.09, h * 2.0) : mix(0.09, 1.0, (h - 0.5) * 2.0); ALBEDO = col * g * op; }"
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
	var bars := Gfx.multimesh(_jersey_mesh(), bar_x); var jm := Gfx.std(lin("d8d6cf"), 0.95, 0.0, _tex.concrete); jm.cull_mode = BaseMaterial3D.CULL_DISABLED; bars.material_override = jm; G.add_child(bars)

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
	var lbl := Label3D.new(); lbl.text = "07"; lbl.font = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"); lbl.font_size = 96; lbl.pixel_size = 10.0 / 256.0
	lbl.modulate = Color(0.788, 0.588, 0.173, 0.9); lbl.outline_size = 0; lbl.shaded = true; lbl.rotation.x = -PI / 2; lbl.position = Vector3(0, 0.014, 1); G.add_child(lbl)

	# containers, one batch per colour and length
	var groups := {}
	for p: Dictionary in place:
		var k: String = "%d_%d" % [p.ci, 1 if p.long else 0]
		if not groups.has(k): groups[k] = []
		groups[k].push_back(p)
	var door_m := {}; var top_m := {}
	for k: String in groups:
		var list: Array = groups[k]; var ci: int = list[0].ci; var long: bool = list[0].long; var color := Color(CONT_COLORS[ci])
		var mesh := Gfx.box3(12.19 if long else 6.06, 2.59, 2.44)
		if not door_m.has(ci): door_m[ci] = Gfx.std(Color.WHITE, 0.62, 0.3, Gfx.door_tex(color)); top_m[ci] = Gfx.std(lin(Gfx.shade(color, 0.75)), 0.75, 0.25)
		mesh.surface_set_material(0, door_m[ci]); mesh.surface_set_material(1, top_m[ci]); mesh.surface_set_material(2, Gfx.std(Color.WHITE, 0.62, 0.3, Gfx.side_tex(color, long)))
		var xs := []
		for p: Dictionary in list: xs.push_back(Transform3D(Basis(Vector3.UP, PI / 2 if p.axis == "z" else 0.0), Vector3(p.x, 1.295 + p.lv * 2.59, p.z)))
		G.add_child(Gfx.multimesh(mesh, xs))

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
	var bm := BoxMesh.new(); bm.size = Vector3(1.2, 1.2, 1.2)
	var mmi := Gfx.multimesh(bm, xs); mmi.material_override = Gfx.std(Color.WHITE, 0.9, 0.0, _tex.crate); G.add_child(mmi); crate_mm = mmi.multimesh

func damage_crate(c: Dictionary, dmg: float, _at: Vector3) -> void:
	if c.dead: return
	c.hp -= dmg
	if c.hp > 0.0: return
	c.dead = true
	if crate_mm: crate_mm.set_instance_transform(c.idx, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(c.x, -5, c.z)))
	Phys.remove_collider(c.b); Phys.nav_patch(c.b.minx, c.b.minz, c.b.maxx, c.b.maxz)  # just round it, not the whole grid
	var at := Vector3(c.x, c.y + 0.6, c.z)
	if fx: fx.chips(at)
	Snd.play("crack", 1.0, at)
	if on_crate.is_valid(): on_crate.call(c)

func update_world(dt: float, t: float, px: float, pz: float) -> void:
	_lamp_t -= dt
	if _lamp_t <= 0.0:
		_lamp_t = 0.35
		var near := lamps.duplicate()
		near.sort_custom(func(a, b): return (a.x - px) * (a.x - px) + (a.z - pz) * (a.z - pz) < (b.x - px) * (b.x - px) + (b.z - pz) * (b.z - pz))
		for i in lights.size():
			if i < near.size(): lights[i].position = Vector3(near[i].x, near[i].y, near[i].z); lights[i].light_energy = style.lamp[1] * 2.0 * style.get("lampMul", 1.0)
			else: lights[i].light_energy = 0.0
	if style.get("fire", false):   # the fires flicker
		for i in lights.size():
			if lights[i].light_energy > 0.0: lights[i].light_energy = style.lamp[1] * (0.72 + 0.18 * sin(t * 13.0 + i * 2.1) + 0.1 * sin(t * 29.0 + i * 5.7))
		for i in flames.size(): (flames[i] as Node3D).scale = Vector3(1.0 + 0.12 * sin(t * 11.0 + i), 1.0 + 0.2 * sin(t * 17.0 + i * 3.1), 1.0 + 0.12 * cos(t * 9.0 + i))
	for i in blink.size(): blink[i].visible = fmod(t + i * 0.3, 1.8) < 0.25
