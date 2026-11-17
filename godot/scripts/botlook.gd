class_name BotLook
## How the ship's crew is drawn in the browser game (src/07h_shipbots.js buildShipBot): its pictures (the boss's white shell, its
## iris), three.js's geometry where Godot's own differs (a sphere cut open at the top, a flat disc), and the shiny materials.
## The gold bee, the boss's shells and armour, its lens and the bee's eyes reflect the browser game's ShineEnv, a soft studio sky
## with four bright panels; Godot's reflections are off everywhere (as three.js has none elsewhere), so that sky is worked out
## here, in the material, with three.js r128's own image-based-light formulas.

static var _tx := {}
static var _shaders := {}

const SHINE := """
shader_type spatial;
render_mode diffuse_lambert, fog_disabled%s;
stencil_mode write, compare_always, 2;   // (robots take no moon shadow: MoonShadow.UNSHADOWED)
uniform vec3 col = vec3(1.0);
uniform sampler2D map : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform float rough = 0.5; uniform float metal = 0.0; uniform vec3 emis = vec3(0.0); uniform float env_k = 1.0;
%s
// the studio sky: blue-grey above, dark below (three.js's colour numbers, linear), and four bright panels facing the middle
const vec3 S_TOP = vec3(0.603922, 0.705882, 0.862745); const vec3 S_MID = vec3(0.227451, 0.262745, 0.337255); const vec3 S_BOT = vec3(0.062745, 0.074510, 0.094118);
// its cosine-weighted mean, for diffuse light: baked into nine spherical harmonics (from 400,000 samples of the same sky)
const vec3 SH[9] = vec3[9](vec3(1.09832, 1.25451, 1.52018), vec3(0.47433, 0.52976, 0.61468), vec3(-0.00065, 0.01017, 0.02544), vec3(0.01162, 0.01511, 0.02024),
	vec3(0.00269, 0.00191, 0.00108), vec3(-0.01698, -0.01555, -0.01276), vec3(-0.01285, -0.01153, -0.00801), vec3(0.01414, 0.01382, 0.01253), vec3(-0.02978, -0.03288, -0.03432));
vec3 sky(vec3 d) { return d.y >= 0.0 ? mix(S_MID, S_TOP, pow(d.y, 0.7)) : mix(S_MID, S_BOT, pow(-d.y, 0.5)); }
float panel(vec3 d, vec3 P, float w, float soft) {   // a w x 0.4w panel at P, turned to face the middle (three.js's lookAt)
	float dist = length(P); vec3 n = P / dist; float c = dot(d, n);
	if (c <= 0.0) return 0.0;
	vec3 z = -n; vec3 x = normalize(cross(vec3(0.0, 1.0, 0.0), z)); vec3 y = cross(z, x); vec3 h = d * (dist / c) - P; float e = soft * dist;
	return (1.0 - smoothstep(w * 0.5 - e, w * 0.5 + e, abs(dot(h, x)))) * (1.0 - smoothstep(w * 0.2 - e, w * 0.2 + e, abs(dot(h, y))));
}
vec3 studio(vec3 d, float r) {   // the sky as PMREM leaves it for this roughness: the panels' edges softened with it
	float soft = 0.02 + r * 0.35; vec3 c = sky(d);
	c = mix(c, vec3(1.0), panel(d, vec3(5.0, 6.0, 2.0), 6.0, soft));
	c = mix(c, vec3(1.0, 0.886275, 0.690196), panel(d, vec3(-6.0, 4.0, -3.0), 4.0, soft));
	c = mix(c, vec3(1.0), panel(d, vec3(0.0, 8.0, -6.0), 8.0, soft));
	c = mix(c, vec3(0.623529, 0.784314, 1.0), panel(d, vec3(3.0, -2.0, 7.0), 5.0, soft));
	return c;
}
vec3 irradiance(vec3 n) {
	return max(SH[0] * 0.282095 + SH[1] * 0.488603 * n.y + SH[2] * 0.488603 * n.z + SH[3] * 0.488603 * n.x + SH[4] * 1.092548 * n.x * n.y + SH[5] * 1.092548 * n.y * n.z
		+ SH[6] * 0.315392 * (3.0 * n.z * n.z - 1.0) + SH[7] * 1.092548 * n.x * n.z + SH[8] * 0.546274 * (n.x * n.x - n.y * n.y), vec3(0.0));
}
void fragment() {
	vec3 base = col * texture(map, UV).rgb;
	ALBEDO = albedo_of(base); METALLIC = metal; ROUGHNESS = rough;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float nv = clamp(dot(n, v), 0.0, 1.0);
	// three.js r128: F_Schlick_RoughnessDependent, integrateSpecularBRDF, BRDF_Specular_Multiscattering_Environment, RE_IndirectSpecular_Physical
	vec3 f0 = mix(vec3(0.04), base, metal);
	vec3 F = (max(vec3(1.0 - rough), f0) - f0) * exp2((-5.55473 * nv - 6.98316) * nv) + f0;
	vec4 r4 = rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
	float a004 = min(r4.x * r4.x, exp2(-9.28 * nv)) * r4.x + r4.y; vec2 brdf = vec2(-1.04, 1.04) * a004 + r4.zw;
	vec3 fss = F * brdf.x + brdf.y; float ems = 1.0 - (brdf.x + brdf.y);
	vec3 favg = f0 + (1.0 - f0) * 0.047619; vec3 fms = fss * favg / (1.0 - ems * favg);
	vec3 irr = irradiance(n) * env_k; vec3 rad = studio(reflect(-v, n), rough) * env_k;
	vec3 diffuse = base * (1.0 - metal) * (1.0 - (fss + fms * ems));
	EMISSION = albedo_of(rad * fss + fms * ems * irr + diffuse * irr + emis);   // (added to Godot's own lights, as three.js adds it to its)
}
"""

## a shiny material: three.js colour (hex), roughness, metalness, envMapIntensity, an optional map and emissive (linear, scaled)
static func shine(hex: String, rough: float, metal: float, env_k: float, map: Texture2D = null, emis := Color(0, 0, 0), two_sided := false) -> ShaderMaterial:
	var key := "two" if two_sided else "one"
	if not _shaders.has(key): var sh := Shader.new(); sh.code = SHINE % [", cull_disabled" if two_sided else "", Gfx.ALBEDO_GLSL]; _shaders[key] = sh
	var m := ShaderMaterial.new(); m.shader = _shaders[key]; var c := Color(hex)
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b)); m.set_shader_parameter("rough", rough); m.set_shader_parameter("metal", metal); m.set_shader_parameter("env_k", env_k)
	m.set_shader_parameter("emis", Vector3(emis.r, emis.g, emis.b))
	if map: m.set_shader_parameter("map", map)
	return m

## the boss's shell: white plating in bands round it, seams across them, dark vents, a little grime and shine
static func shell_tex() -> ImageTexture:
	if not _tx.has("shell"):
		var w := 1024; var h := 512; var img := Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(Color("eef1f6")); var ln := Color(70 / 255.0, 80 / 255.0, 96 / 255.0, 0.75)
		for v: float in [0.18, 0.36, 0.5, 0.64, 0.82]: Gfx.frect(img, 0, v * h - 1.5, w, 3, ln)
		for i in 12:
			var x := (i / 12.0) * w + (18.0 if i % 2 else 0.0)
			Gfx.frect(img, x - 1.5, 0.18 * h, 3, 0.18 * h, ln); Gfx.frect(img, x + 30 - 1.5, 0.5 * h, 3, 0.14 * h, ln); Gfx.frect(img, x - 20 - 1.5, 0.64 * h, 3, 0.18 * h, ln)
		for i in 14: Gfx.frect(img, randf_range(0, w), randf_range(0.2, 0.8) * h, randf_range(10, 26), randf_range(4, 8), Color(40 / 255.0, 46 / 255.0, 58 / 255.0, 0.8))
		Gfx.speckle(img, 1500, [Color(0, 0, 0, 0.06), Color(1, 1, 1, 0.3)], 1.5)
		_tx.shell = Gfx.tex(img)
	return _tx.shell
## the boss's iris: a grey radial drawing the material tints blue (or red, about to fire), rings and spokes like a lens
static func iris_tex() -> ImageTexture:
	if not _tx.has("iris"):
		var w := 256; var c := w / 2.0; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
		var stops := [[0.0, Color("ffffff")], [0.2, Color("ffffff")], [0.36, Color("d4e6ff")], [0.62, Color("8fb4ec")], [0.86, Color("5579bd")], [1.0, Color("2a3f73")]]
		for y in w:
			for x in w:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c).length(); var cov := clampf(c - d + 0.5, 0.0, 1.0)
				if cov <= 0.0: continue
				var t := clampf(d / c, 0.0, 1.0); var col: Color = stops[5][1]
				for k in 5:
					if t <= stops[k + 1][0]: col = (stops[k][1] as Color).lerp(stops[k + 1][1], (t - stops[k][0]) / (stops[k + 1][0] - stops[k][0])); break
				img.set_pixel(x, y, Color(col.r, col.g, col.b, cov))
		for r: float in [0.44, 0.66, 0.84]: _ring(img, c, c * r, 4.0, Color(1, 1, 1, 0.45))
		for i in 20: var a := (i / 20.0) * TAU; Gfx.fline(img, Vector2(c + cos(a) * c * 0.5, c + sin(a) * c * 0.5), Vector2(c + cos(a) * c * 0.92, c + sin(a) * c * 0.92), Color(1, 1, 1, 0.28), 3.0)
		_tx.iris = Gfx.tex(img)
	return _tx.iris
static func _ring(img: Image, c: float, r: float, lw: float, col: Color) -> void:   # a canvas arc stroked all round
	for y in range(int(c - r - lw), int(c + r + lw) + 1):
		for x in range(int(c - r - lw), int(c + r + lw) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): continue
			var cov := clampf(lw / 2.0 + 0.5 - absf(Vector2(x + 0.5 - c, y + 0.5 - c).length() - r), 0.0, 1.0) * col.a
			if cov > 0.0: var o := img.get_pixel(x, y); img.set_pixel(x, y, Color(o.r + (col.r - o.r) * cov, o.g + (col.g - o.g) * cov, o.b + (col.b - o.b) * cov, o.a))
## the lamps' pool of light (World's), for the glow round the boss's eye
static func pool_tex() -> ImageTexture:
	if not _tx.has("pool"): _tx.pool = Gfx.glow_tex(Color(1, 0.784, 0.549, 0.5), Color(1, 0.627, 0.314, 0.16))
	return _tx.pool

## three.js's SphereGeometry(r, w, h, phi0, phi_len, theta0, theta_len): its vertices, normals and picture coordinates
static func sphere(r: float, ws: int, hs: int, phi0 := 0.0, phi_len := TAU, th0 := 0.0, th_len := PI) -> ArrayMesh:
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	for iy in hs + 1:
		var v := float(iy) / hs
		for ix in ws + 1:
			var u := float(ix) / ws; var th := th0 + v * th_len; var ph := phi0 + u * phi_len
			var p := Vector3(-r * cos(ph) * sin(th), r * cos(th), r * sin(ph) * sin(th)); vs.push_back(p); ns.push_back(p.normalized() if p.length() > 0.0 else Vector3.UP)
			uvs.push_back(Vector2(u, v))   # (three.js's 1 - v, counted from the picture's foot: the same row)
	var row := ws + 1
	for iy in hs:
		for ix in ws:
			var a := iy * row + ix + 1; var b := iy * row + ix; var c := (iy + 1) * row + ix; var d := (iy + 1) * row + ix + 1
			if iy != 0 or th0 > 0.0: idx.append_array([a, d, b])   # (three.js's a, b, d and b, c, d, wound the other way for Godot)
			if iy != hs - 1 or th0 + th_len < PI: idx.append_array([b, d, c])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m
## three.js's CircleGeometry: a flat disc facing +z
static func disc(r: float, seg: int) -> ArrayMesh:
	var vs := PackedVector3Array([Vector3.ZERO]); var ns := PackedVector3Array([Vector3.BACK]); var uvs := PackedVector2Array([Vector2(0.5, 0.5)]); var idx := PackedInt32Array()
	for i in seg + 1: var a := float(i) / seg * TAU; vs.push_back(Vector3(cos(a) * r, sin(a) * r, 0)); ns.push_back(Vector3.BACK); uvs.push_back(Vector2((cos(a) + 1) / 2, 1.0 - (sin(a) + 1) / 2))
	for i in seg: idx.append_array([0, i + 2, i + 1])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m
## a cylinder (three.js's: radius at the top and at the foot, height, sides), open-ended if asked
static func cyl(rt: float, rb: float, h: float, seg: int, open := false) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 0; c.cap_top = not open; c.cap_bottom = not open
	return c
## three.js's TorusGeometry(radius, tube, radial, tubular) lies in the xy plane; Godot's in xz: this one is turned to three.js's
static func torus(r: float, tube: float, radial: int, tubular: int) -> ArrayMesh:
	var t := TorusMesh.new(); t.inner_radius = r - tube; t.outer_radius = r + tube; t.rings = tubular; t.ring_segments = radial
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.append_from(t, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)); return st.commit()
