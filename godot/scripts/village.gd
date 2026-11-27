class_name Village
extends RefCounted
## Stage 2: a village of log huts at night, several of them burning, under a big moon. Ported from src/04e_village.js: every
## seeded random number is drawn in the same order (also the ones that only pick a colour), so each hut, prop, pine and crate
## stands where it does in the browser game.

const LOG := ["5b4532", "4f3b2a", "664d36", "563f2d"]
const CHAR := ["1d1712", "261d16", "16120e", "2e231a"]
const ROOF := ["46382a", "3d3124", "4b3c2b"]

var ghosts: Array = []       # the browser game's crates out in the village: in the way only while the zombies are put down
var ghost_at: Array = []     # ...and where they stood
var R: World.Rng
var parts: Array = []     # boxes for one mesh: [sx, sy, sz, x, y, z, colour, (rotation)]
var fires: Array = []     # [x, y, z, power]
var huts: Array = []
var pines: Array = []
var crown_colors: Array = []   # each pine's crown colour, outer forest too (as stored: screen colours)

func r(a: float, b: float) -> float: return R.rng(a, b)
func pick(a: Array) -> String: return a[int(floor(R.next() * a.size()))]

func build(w: World, G: Node3D, S: Dictionary, rng: World.Rng) -> void:
	R = rng
	# ground: trampled earth and dark grass (the browser game's canvas, 24 times each way)
	var gm := PlaneMesh.new(); gm.size = Vector2(260, 260); var ground := MeshInstance3D.new(); ground.mesh = gm
	var grm := Gfx.std(Color.WHITE, 1.0, 0.0, Gfx.dirt_tex()); grm.uv1_scale = Vector3(24, 24, 1); ground.material_override = grm; G.add_child(ground)
	# the edge of the village: a palisade of sharpened logs
	var E := 67.0
	for q in [[0.0, -E - 0.6, 2 * E + 2, 1.2], [0.0, E + 0.6, 2 * E + 2, 1.2], [-E - 0.6, 0.0, 1.2, 2 * E + 2], [E + 0.6, 0.0, 1.2, 2 * E + 2]]:
		Phys.add_collider(q[0] - q[2] / 2, 0, q[1] - q[3] / 2, q[0] + q[2] / 2, 10, q[1] + q[3] / 2, "wood")
	var stakes := []; var t := -E
	while t <= E: stakes.append_array([[t, -E - 0.3], [t, E + 0.3], [-E - 0.3, t], [E + 0.3, t]]); t += 0.52
	var sx := []
	for s in stakes:
		var h := r(2.7, 3.5); var rot := Vector3(r(-0.05, 0.05), r(0, 3), r(-0.05, 0.05))
		sx.push_back(Transform3D(Basis.from_euler(rot).scaled_local(Vector3(1, h, 1)), Vector3(s[0], h / 2, s[1])))
	var sm := CylinderMesh.new(); sm.top_radius = 0.05; sm.bottom_radius = 0.21; sm.height = 1.0; sm.radial_segments = 7; sm.rings = 0
	var stake_mi := MeshInstance3D.new(); stake_mi.mesh = Gfx.bake(sm, sx); stake_mi.material_override = Gfx.std(World.lin("3a2b1d"), 0.95); G.add_child(stake_mi); MoonShadow.caster(stake_mi)
	# black forest on the horizon
	var sil := []
	for i in 170:
		var a := (i / 170.0) * TAU + r(-0.02, 0.02); var d := r(140, 190); var h := r(16, 34)
		sil.push_back(Transform3D(Basis.from_scale(Vector3(h * 0.32, h, h * 0.32)), Vector3(cos(a) * d, h / 2 - 1, sin(a) * d)))
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 1.0; cone.height = 1.0; cone.radial_segments = 6
	var silm := Gfx.multimesh(cone, sil); silm.material_override = Gfx.backdrop(Gfx.unlit(World.lin(Color(0.006, 0.008, 0.012)), false)); G.add_child(silm)   # (no fog, as there)

	# where the huts go: an inner ring round the plaza and an outer ring, doors turned towards the middle, some burning, two in ruins
	var inside := []; var spots := []
	for i in 6: var a := (i / 6.0) * TAU + 0.35 + r(-0.12, 0.12); var d := r(23, 28); spots.push_back([cos(a) * d, sin(a) * d])
	for i in 9: var a := (i / 9.0) * TAU + r(-0.1, 0.1); var d := r(44, 52); spots.push_back([cos(a) * d, sin(a) * d])
	var kinds := []
	for i in spots.size(): kinds.push_back("ok")
	for k in [1, 4, 7, 9, 12, 13]: kinds[k] = "burn"
	kinds[3] = "ruin"; kinds[10] = "ruin"
	for i in spots.size():
		var x: float = spots[i][0]; var z: float = spots[i][1]
		if Vector2(x, z - 6).length() < 15: continue
		var fx := -x; var fz := -z
		var yaw := (PI / 2 if fx > 0 else -PI / 2) if absf(fx) > absf(fz) else (0.0 if fz > 0 else PI)
		var W := float([5.4, 6.2, 7][int(floor(R.next() * 3))]); var D := float([4.4, 5][int(floor(R.next() * 2))])
		# line the doorway up with the walking grid so zombies can find their way in and out
		var cx := x; var cz := z; var across := absf(sin(yaw)) < 0.5
		if across: cx = _jsround(cx - 0.5) + 0.5
		else: cz = _jsround(cz - 0.5) + 0.5
		var ex := W / 2 + 1 if across else D / 2 + 1; var ez := D / 2 + 1 if across else W / 2 + 1
		if absf(cx) > 60 or absf(cz) > 60 or Phys.occupied(cx - ex, cz - ez, cx + ex, cz + ez, 2): continue
		_hut(cx, cz, yaw, W, D, kinds[i], inside); huts.push_back({"x": cx, "z": cz, "yaw": yaw, "W": W, "D": D, "kind": kinds[i]})

	# the plaza: a bonfire in a ring of stones, logs to sit on
	var BX := 0.0; var BZ := -5.0
	for i in 10: var a := (i / 10.0) * TAU; parts.push_back([0.45, 0.32, 0.4, BX + cos(a) * 1.05, 0.16, BZ + sin(a) * 1.05, "5d5c59" if i % 2 else "4d4c4a", [0, a, 0]])
	for i in 4: var a := (i / 4.0) * TAU + 0.4; parts.push_back([1.5, 0.2, 0.2, BX + cos(a) * 0.3, 0.25, BZ + sin(a) * 0.3, "2a2018", [0, a, 0.35]])
	Phys.add_collider(BX - 1.3, 0, BZ - 1.3, BX + 1.3, 0.7, BZ + 1.3, "concrete")
	fires.push_back([BX, 0.3, BZ, 2.0])
	for q in [[-4.6, -5.0, 0.2], [4.6, -5.5, -0.2], [0.0, -9.8, 1.57]]:
		parts.push_back([2.4, 0.42, 0.42, q[0], 0.21, q[1], "4a3826", [0, q[2], 0]]); var c := absf(cos(q[2])); var s := absf(sin(q[2]))
		Phys.add_collider(q[0] - 1.2 * c - 0.21 * s, 0, q[1] - 1.2 * s - 0.21 * c, q[0] + 1.2 * c + 0.21 * s, 0.42, q[1] + 1.2 * s + 0.21 * c, "wood")

	# cover in between: hay bales, barrels, carts, log piles, bits of fence
	var n := 0; var tries := 0
	while n < 34 and tries < 600:
		tries += 1; var x := r(-60, 60); var z := r(-60, 60)
		if Vector2(x, z - 3).length() < 14 or Phys.occupied(x - 2.6, z - 2.6, x + 2.6, z + 2.6, 1.5): continue
		_prop(x, z); n += 1

	# pines between the huts and outside the fence
	n = 0; tries = 0
	while n < 95 and tries < 2000:
		tries += 1; var x := r(-64, 64); var z := r(-64, 64)
		if Vector2(x, z - 3).length() < 17 or Phys.occupied(x - 1.6, z - 1.6, x + 1.6, z + 1.6, 0.6): continue
		var h := r(7, 13); var cr := r(1.8, 2.8); pines.push_back([x, z, h, cr]); Phys.add_collider(x - 0.28, 0, z - 0.28, x + 0.28, h, z + 0.28, "wood"); n += 1
	var all := pines.duplicate()
	for i in 150: var a := R.next() * TAU; var d := r(70, 96); var th := r(9, 16); var tcr := r(2.2, 3.4); all.push_back([cos(a) * d, sin(a) * d, th, tcr])
	var trunk_x := []; var crown_x := []; var crown_c := []
	for p in all:
		trunk_x.push_back(Transform3D(Basis.from_scale(Vector3(1, p[2] * 0.4, 1)), Vector3(p[0], p[2] * 0.2, p[1])))
		var ry := R.next() * 3.0
		crown_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(p[3], p[2] * 0.95, p[3])), Vector3(p[0], p[2] * 0.1, p[1])))
		var hue := 0.36 + r(-0.03, 0.03); var lum := r(0.09, 0.14); crown_c.push_back(Gfx.hsl(hue, 0.35, lum))   # (three.js: setHSL, then to linear; Godot reads a vertex colour as a screen colour)
	crown_colors = crown_c
	var tm := CylinderMesh.new(); tm.top_radius = 0.16; tm.bottom_radius = 0.28; tm.height = 1.0; tm.radial_segments = 6; tm.rings = 0
	var trunks := MeshInstance3D.new(); trunks.mesh = Gfx.bake(tm, trunk_x); trunks.material_override = Gfx.std(World.lin("3a2a1c"), 0.95); G.add_child(trunks); MoonShadow.caster(trunks)
	var crowns := MeshInstance3D.new(); crowns.mesh = Gfx.bake(crown_mesh(), crown_x, crown_c); crowns.name = "Crowns"
	var crm := Gfx.std(Color.WHITE, 0.9); crm.vertex_color_use_as_albedo = true; crm.vertex_color_is_srgb = true; crowns.material_override = crm; G.add_child(crowns); MoonShadow.caster(crowns)

	# crates: two in every hut, and none out in the village (the antidotes are found indoors: the owner's rule). The browser game's
	# crates out in the village are still worked out where they would be, and stand in the way while the zombies are put down, so
	# the zombies stand where the browser game puts them; then they go (drop_ghosts, from Game.begin)
	var count := maxi(int(S.crates), inside.size() + 16); var hc := 0; var xs := []; var i := 0; tries = 0
	while i < count and tries < count * 40:
		tries += 1; var in_hut := hc < inside.size(); var x: float; var z: float
		if in_hut: x = inside[hc][0]; z = inside[hc][1]; hc += 1
		else: x = r(-62, 62); z = r(-62, 62)
		var ok: bool = (not Phys.box_at(x, z, 0.58, 0.05, 1.15)) if in_hut else (Vector2(x, z - 6).length() >= 6 and not Phys.occupied(x - 0.6, z - 0.6, x + 0.6, z + 0.6, 0.3))
		if not ok: continue
		var turn := randf_range(-0.2, 0.2)
		if not in_hut: ghosts.push_back(Phys.add_collider(x - 0.6, 0, z - 0.6, x + 0.6, 1.2, z + 0.6, "wood")); ghost_at.push_back(Vector2(x, z)); i += 1; continue
		var cr := {"idx": xs.size(), "hp": 45.0, "x": x, "z": z, "y": 0.0, "dead": false}   # its place among the crates drawn (the ghosts are not drawn)
		xs.push_back(Transform3D(Basis(Vector3.UP, turn), Vector3(x, 0.6, z)))
		cr.b = Phys.add_collider(x - 0.6, 0, z - 0.6, x + 0.6, 1.2, z + 0.6, "wood", cr); w.crates.push_back(cr); i += 1
	var mmi := Gfx.multimesh(Gfx.box(Vector3(1.2, 1.2, 1.2)), xs); mmi.material_override = Gfx.std(Color.WHITE, 0.9, 0.0, w._tex.crate); G.add_child(mmi); MoonShadow.caster(mmi); w.crate_mm = mmi.multimesh; w.crate_mmi = mmi; w.crate_xf = xs.duplicate()

	# everything built of logs, in one mesh
	var mi := MeshInstance3D.new(); mi.mesh = Gfx.merge_boxes(parts); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.vertex_color_is_srgb = true; mat.roughness = 0.92; mi.material_override = mat; G.add_child(mi); MoonShadow.caster(mi)
	# fire: flames, sparks and smoke drawn as camera-facing cards; each fire also lends one of the six flickering lights
	w.fire_mats = build_fires(G, fires, float(S.density), Gfx.exposure(float(S.get("exposure", 1.15))))
	for f in fires: w.lamps.push_back({"x": f[0], "y": f[1] + 0.9 + f[3] * 0.3, "z": f[2]})
	Phys.index_colliders(); Phys.build_nav()
	w.start = {"x": 0.0, "z": 8.0, "yaw": 0.0}; w.spawns.clear()


## a pine's crown: three cones stacked (the browser game's crownGeo), its foot at 0
static func crown_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [[1.0, 0.62, 0.42], [0.78, 0.5, 0.7], [0.5, 0.36, 0.92]]:
		var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = q[0]; cm.height = q[1]; cm.radial_segments = 7; cm.rings = 0; cm.cap_top = false
		st.append_from(cm, 0, Transform3D(Basis.IDENTITY, Vector3(0, q[2], 0)))
	return st.commit()

## flames, embers and smoke as cards turned to the camera, one draw each, moved entirely on the GPU (the browser game's
## buildFires). Its shaders write their colours untoned, so these turn them back through the tone mapping first
const FIRE_SHADER := """
shader_type spatial;
%s
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
render_mode unshaded, %s, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
#else
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
#endif
uniform float ft; uniform float rise; uniform float life = 1.0; uniform float spread; uniform float fogD; uniform float exposure = 1.0;
varying vec2 vUv; varying float vSeed; varying float vK; varying float vFog;
%s
%s
%s
void vertex() {
	vUv = UV; vSeed = CUSTOM0.z;
	float k = rise > 0.0 ? fract(ft / life + vSeed) : 0.0; vK = k;
	vec3 p = VERTEX + vec3(sin(vSeed * 41.0 + ft * 1.3) * spread * k, k * rise, cos(vSeed * 23.0 + ft * 1.1) * spread * k);
	vec4 mv = MODELVIEW_MATRIX * vec4(p, 1.0);
	float s = rise > 0.0 ? (0.6 + k * 1.6) : 1.0;
	mv.xy += (UV - 0.5) * CUSTOM0.xy * s; mv.y += CUSTOM0.y * 0.5 * (rise > 0.0 ? 0.0 : 1.0);
	vFog = exp(-pow(fogD * length(mv.xyz), 2.0));
	VERTEX = mv.xyz;
}
%s
void fragment() {
	vec4 o = shade(vUv, vSeed, vK, vFog);
	if (o.a < 0.0) discard;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = albedo_of(unshow(clamp(o.rgb, 0.0, 1.0))); ALPHA = clamp(o.a, 0.0, 1.0);
#else
	ALBEDO = shown(clamp(o.rgb, 0.0, 1.0), clamp(o.a, 0.0, 1.0), SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX); ALPHA = 1.0;   // (as shown: Gfx.SHOWN_GLSL)
#endif
}
"""
const FLAME_FS := """
vec4 shade(vec2 p, float seed, float k, float fogv) {
	float w = sin(p.y * 7.0 + ft * 9.0 + seed * 6.28) * 0.07 * p.y;
	float x = (p.x - 0.5 + w) / (0.44 * (1.0 - p.y * 0.8) + 0.03);
	float tip = 1.0 - smoothstep(0.5 + 0.28 * sin(ft * 6.0 + seed * 9.0), 1.0, p.y);
	float a = (1.0 - smoothstep(0.55, 1.0, abs(x))) * tip * smoothstep(0.0, 0.1, p.y);
	if (a < 0.02) return vec4(0.0, 0.0, 0.0, -1.0);
	float core = (1.0 - abs(x)) * (1.0 - p.y);
	vec3 c = mix(vec3(0.9, 0.18, 0.03), vec3(1.0, 0.62, 0.16), smoothstep(0.05, 0.5, core));
	c = mix(c, vec3(1.0, 0.92, 0.7), smoothstep(0.55, 0.95, core));
	return vec4(c * a * 1.5 * fogv, a);
}
"""
const EMBER_FS := """
vec4 shade(vec2 p, float seed, float k, float fogv) {
	float d = length(p - vec2(0.5)) * 2.0; float a = (1.0 - smoothstep(0.2, 1.0, d)) * (1.0 - k);
	if (a < 0.02) return vec4(0.0, 0.0, 0.0, -1.0);
	return vec4(vec3(1.0, 0.55, 0.15) * a * 1.6 * fogv, a);
}
"""
const SMOKE_FS := """
vec4 shade(vec2 p, float seed, float k, float fogv) {
	float d = length(p - vec2(0.5)) * 2.0; float a = (1.0 - smoothstep(0.3, 1.0, d)) * smoothstep(0.0, 0.15, k) * (1.0 - k) * 0.42;
	if (a < 0.01) return vec4(0.0, 0.0, 0.0, -1.0);
	return vec4(vec3(0.07, 0.07, 0.075) * (0.6 + 0.4 * fogv), a * (0.4 + 0.6 * fogv));
}
"""

## the cards round each fire [x, y, z, power]; returns the three layers' materials (World sets their time each frame)
static func build_fires(G: Node3D, list: Array, density: float, exposure: float) -> Array:
	var flames := []; var embers := []; var smoke := []
	for f in list:
		var x: float = f[0]; var y: float = f[1]; var z: float = f[2]; var p: float = f[3]
		for i in roundi(4 + p * 4):
			var s := randf_range(0.6, 1.1) * p; flames.push_back([x + randf_range(-0.45, 0.45) * p, y - 0.1, z + randf_range(-0.45, 0.45) * p, s * 0.7, s * 1.25, randf()])
		for i in roundi(6 + p * 8): embers.push_back([x + randf_range(-0.4, 0.4) * p, y + 0.2, z + randf_range(-0.4, 0.4) * p, 0.07, 0.07, randf()])
		for i in roundi(5 + p * 5): smoke.push_back([x + randf_range(-0.3, 0.3), y + 0.8 * p, z + randf_range(-0.3, 0.3), 1.4 * p, 1.4 * p, randf()])
	return [_fire_layer(G, smoke, SMOKE_FS, false, {"rise": 9.0, "life": 6.5, "spread": 2.2}, 2, density, exposure),
		_fire_layer(G, flames, FLAME_FS, true, {}, 3, density, exposure),
		_fire_layer(G, embers, EMBER_FS, true, {"rise": 5.0, "life": 2.2, "spread": 1.4}, 4, density, exposure)]

static func _fire_layer(G: Node3D, list: Array, fs: String, add: bool, opts: Dictionary, order: int, density: float, exposure: float) -> ShaderMaterial:
	var vs := PackedVector3Array(); var uvs := PackedVector2Array(); var cu := PackedFloat32Array(); var idx := PackedInt32Array()
	for i in list.size():
		var it: Array = list[i]
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:   # (uv as three.js's plane: v = 1 at the top)
			vs.push_back(Vector3(it[0], it[1], it[2])); uvs.push_back(c); cu.append_array([it[3], it[4], it[5], 0.0])
		var b := i * 4; idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_CUSTOM0] = cu; arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var sh := Shader.new(); sh.code = FIRE_SHADER % ["#define SHOWN_ADD" if add else "", "blend_add" if add else "blend_mix", Gfx.ALBEDO_GLSL, Gfx.UNSHOW_GLSL, Gfx.SHOWN_GLSL, fs]
	var mat := ShaderMaterial.new(); mat.shader = sh; mat.render_priority = order
	mat.set_shader_parameter("rise", float(opts.get("rise", 0.0))); mat.set_shader_parameter("life", float(opts.get("life", 1.0))); mat.set_shader_parameter("spread", float(opts.get("spread", 0.0)))
	mat.set_shader_parameter("fogD", density); mat.set_shader_parameter("exposure", exposure)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 500, 800))   # never culled, as in the browser game
	G.add_child(mi)
	return mat

static func _jsround(v: float) -> float:   # Math.round: halves go up
	return floor(v + 0.5)

## a hut, built in its own frame (door on the +z wall, ridge along x), then turned to face the plaza
func _hut(cx: float, cz: float, yaw: float, W: float, D: float, kind: String, inside: Array) -> void:
	var P := []; var T := 0.22; var H := 2.6; var ridge := 1.35; var ov := 0.4; var Wd := 1.7
	var burning := kind == "burn"; var ruin := kind == "ruin"
	var fire_side := -1.0 if R.next() < 0.5 else 1.0   # which half of the roof burns
	var boxes := []                                    # collider boxes in hut space: [x0, x1, z0, z1, y0, y1]
	var wall := func(x0: float, x1: float, z0: float, z1: float, top: float, char_from: float) -> void:
		var y := 0.0; var k := 0
		while y < top - 0.02:
			var hh := minf(0.32, top - y); var burnt := ruin or (char_from >= 0.0 and y > char_from)
			var col: String = pick(CHAR) if burnt else LOG[(k + int(floor(R.next() * 2))) % 4]
			P.push_back([x1 - x0, hh * 0.95, z1 - z0, (x0 + x1) / 2, y + hh / 2, (z0 + z1) / 2, col]); y += 0.32; k += 1
		boxes.push_back([x0, x1, z0, z1, 0.0, top])
	var top_of := func() -> float: return r(0.9, 2.1) if ruin else H
	var hw := W / 2; var hd := D / 2
	# back and side walls, front wall split by the doorway; a burning hut is charred near the flames
	wall.call(-hw, hw, -hd, -hd + T, top_of.call(), 1.3 if burning else -1.0)
	wall.call(-hw, -hw + T, -hd + T, hd - T, top_of.call(), 1.0 if (burning and fire_side < 0) else -1.0)
	wall.call(hw - T, hw, -hd + T, hd - T, top_of.call(), 1.0 if (burning and fire_side > 0) else -1.0)
	wall.call(-hw, -Wd / 2, hd - T, hd, top_of.call(), 1.4 if (burning and fire_side < 0) else -1.0)
	wall.call(Wd / 2, hw, hd - T, hd, top_of.call(), 1.4 if (burning and fire_side > 0) else -1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: P.push_back([0.3, 1.6 if ruin else H + 0.1, 0.3, sx * (hw - 0.05), (1.6 if ruin else H + 0.1) / 2, sz * (hd - 0.05), pick(CHAR) if ruin else "3b2b1d"])
	if not ruin:
		P.push_back([0.16, 2.12, 0.3, -Wd / 2 - 0.02, 1.06, hd - T / 2, "35271a"]); P.push_back([0.16, 2.12, 0.3, Wd / 2 + 0.02, 1.06, hd - T / 2, "35271a"])
		P.push_back([Wd + 0.3, H - 2.1, T, 0, 2.1 + (H - 2.1) / 2, hd - T / 2, LOG[1]]); boxes.push_back([-Wd / 2, Wd / 2, hd - T, hd, 2.1, H])
		P.push_back([W - 0.5, 0.06, D - 0.5, 0, 0.03, 0, "33281d"])   # floor boards, a table
		if W >= 6:
			P.push_back([1.3, 0.08, 0.8, -hw + 1.3, 0.78, -hd + 0.9, "5a4330"])
			for q in [[0.75, 0.6], [1.85, 0.6], [0.75, 1.2], [1.85, 1.2]]: P.push_back([0.08, 0.74, 0.08, -hw + q[0], 0.37, -hd + q[1], "3b2b1d"])
			boxes.push_back([-hw + 0.6, -hw + 2, -hd + 0.45, -hd + 1.35, 0.0, 0.82])
		# gable roof: two sloped panels; a burning hut has a hole torn in one of them
		var a := atan2(ridge, hd + 0.05); var L := (hd + ov) / cos(a) + 0.1
		for s in [-1.0, 1.0]:
			var col := pick(ROOF); var y := H + ridge / 2 - 0.05; var z: float = s * (hd + ov) / 2 - s * 0.05
			if burning and s == 1.0:
				var half := (W + 2 * ov) / 2
				P.push_back([half, 0.13, L, -fire_side * half / 2, y, z, col, [-s * a, 0, 0]])
				P.push_back([0.25, 0.14, L * 0.9, -fire_side * 0.05, y, z, pick(CHAR), [-s * a, 0, 0]])
				for k in 3:
					var bw := r(0.6, 1.2); var bx := fire_side * r(0.4, half - 0.4); var by := y + r(-0.2, 0.2); var bz := z + r(-0.6, 0.6); var bc := pick(CHAR)
					P.push_back([bw, 0.07, 0.25, bx, by, bz, bc, [r(-0.4, 0.4), r(0, 3), r(-0.4, 0.4)]])
			else: P.push_back([W + 2 * ov, 0.13, L, 0, y, z, col, [-s * a, 0, 0]])
		P.push_back([W + 2 * ov + 0.1, 0.16, 0.22, 0, H + ridge + 0.02, 0, "2f2418"])
		for sx in [-1.0, 1.0]:   # gables at both ends, stepped
			for k in 4:
				var t0 := k / 4.0; var wz := D * (1 - t0 - 0.125) + 0.1; var yy := H + ridge * (t0 + 0.125)
				P.push_back([T, ridge / 4 + 0.02, wz, sx * (hw - T / 2), yy, 0, pick(CHAR) if (burning and sx == fire_side) else LOG[k % 4]])
		boxes.push_back([-hw, hw, -hd, hd, H - 0.12, H + 0.06])   # ceiling: you cannot jump out through the roof
	else:
		for k in 3:   # a burnt-out shell: fallen beams inside
			var bw := r(1.6, W - 0.6); var bx := r(-0.6, 0.6); var bz := r(-hd + 0.6, hd - 0.6); var bc := pick(CHAR)
			P.push_back([bw, 0.2, 0.22, bx, 0.12 + k * 0.08, bz, bc, [0, r(-0.6, 0.6), r(-0.15, 0.15)]])
	# into world space
	var c := cos(yaw); var s := sin(yaw)
	var tw := func(x: float, z: float) -> Array: return [cx + x * c + z * s, cz - x * s + z * c]
	for p in P:
		var q: Array = tw.call(p[3], p[5]); var rot: Array = p[7] if p.size() > 7 else [0, 0, 0]
		parts.push_back([p[0], p[1], p[2], q[0], p[4], q[1], p[6], rot, yaw])
	for b in boxes:
		var ps := [tw.call(b[0], b[2]), tw.call(b[1], b[2]), tw.call(b[0], b[3]), tw.call(b[1], b[3])]
		var xs: Array = ps.map(func(q): return q[0]); var zs: Array = ps.map(func(q): return q[1])
		Phys.add_collider(xs.min(), b[4], zs.min(), xs.max(), b[5], zs.max(), "wood")
	# flames: on the torn roof, licking up a wall corner, small ones in a ruin
	if burning:
		var f: Array = tw.call(fire_side * hw * 0.45, hd * 0.35); fires.push_back([f[0], H + 0.8, f[1], 1.9])
		f = tw.call(fire_side * hw * 0.15, hd * 0.1); fires.push_back([f[0], H + ridge * 0.7, f[1], 1.1])
		f = tw.call(fire_side * (hw - 0.3), hd - 0.3); fires.push_back([f[0], 0.2, f[1], 1.0])
	elif ruin and R.next() < 0.8:
		var fx := r(-hw + 1, hw - 1); var fz := r(-hd + 1, hd - 1); var f2: Array = tw.call(fx, fz); fires.push_back([f2[0], 0.15, f2[1], 0.6])
	# every hut keeps two crates: the back corner away from the table, and a front corner beside the door, away from any fire on the floor
	var e := hw - T - 0.68; var f3 := hd - T - 0.68
	inside.push_back(tw.call(e, -f3)); inside.push_back(tw.call(e if (burning and fire_side < 0) else -e, f3))

func _prop(x: float, z: float) -> void:
	var k := R.next()
	if k < 0.3:
		var a := 0.0 if R.next() < 0.5 else PI / 2; var w := 1.3; var d := 0.85
		parts.push_back([w, 0.9, d, x, 0.45, z, "7d6e36" if R.next() < 0.5 else "6e6230", [0, a, 0]])
		if a > 0.0: Phys.add_collider(x - d / 2, 0, z - w / 2, x + d / 2, 0.9, z + w / 2, "wood")
		else: Phys.add_collider(x - w / 2, 0, z - d / 2, x + w / 2, 0.9, z + d / 2, "wood")
	elif k < 0.5:
		for b in 3: var bx := x + (b - 1) * 0.65; parts.push_back([0.58, 0.95, 0.58, bx, 0.475, z, "4b3523"]); parts.push_back([0.62, 0.06, 0.62, bx, 0.25, z, "2b2b2b"]); parts.push_back([0.62, 0.06, 0.62, bx, 0.75, z, "2b2b2b"])
		Phys.add_collider(x - 1.0, 0, z - 0.3, x + 1.0, 0.95, z + 0.3, "wood")
	elif k < 0.68:
		parts.append_array([[2.6, 0.5, 1.4, x, 0.8, z, "4e3a27"], [2.6, 0.5, 0.08, x, 1.2, z - 0.66, "3e2e1f"], [2.6, 0.5, 0.08, x, 1.2, z + 0.66, "3e2e1f"], [0.12, 0.9, 0.9, x - 0.7, 0.45, z - 0.78, "2c2219"],
			[0.12, 0.9, 0.9, x - 0.7, 0.45, z + 0.78, "2c2219"], [1.6, 0.08, 0.08, x + 2.0, 0.6, z, "3e2e1f", [0, 0, 0.3]]])
		Phys.add_collider(x - 1.3, 0, z - 0.85, x + 1.3, 1.45, z + 0.85, "wood")
	elif k < 0.84:
		for b in 3:
			for c in 3 - b: parts.push_back([2.8, 0.36, 0.36, x, 0.2 + b * 0.32, z - 0.38 + c * 0.38 + b * 0.19, LOG[(b + c) % 4]])
		Phys.add_collider(x - 1.4, 0, z - 0.6, x + 1.4, 1.0, z + 0.6, "wood")
	else:
		var a := R.next() < 0.5; var L := r(3, 5); var t := 0.0
		while t <= L + 0.01:
			parts.push_back([0.14, 1.2, 0.14, x - L / 2 + t, 0.6, z, "3b2b1d"] if a else [0.14, 1.2, 0.14, x, 0.6, z - L / 2 + t, "3b2b1d"]); t += L / 3
		for y in [0.45, 0.95]: parts.push_back([L, 0.1, 0.07, x, y, z, "4a3826"] if a else [0.07, 0.1, L, x, y, z, "4a3826"])
		if a: Phys.add_collider(x - L / 2, 0, z - 0.1, x + L / 2, 1.2, z + 0.1, "wood")
		else: Phys.add_collider(x - 0.1, 0, z - L / 2, x + 0.1, 1.2, z + L / 2, "wood")

## the crates out in the village go (they stood in the way only while the zombies were put down): the antidotes are indoors
func drop_ghosts() -> void:
	if ghosts.is_empty(): return
	for b: Phys.Box in ghosts: Phys.remove_collider(b)
	ghosts.clear(); Phys.build_nav()
