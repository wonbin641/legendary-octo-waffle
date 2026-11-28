class_name RaceArt
extends RefCounted
## The four peoples drawn as the art direction paper draws them (신화 & 판타지 FPS: 종족 원화 설정 및 개별 무기 클로즈업
## 가이드): each weapon close up in your hands, with the hands that hold it, its own moving parts and the gauges on it
## (diegetic UI), and each people's body in its silhouette from the paper's three views. Shapes are ArtKit's; what they
## are made of is drawn by the art shader below: three.js-style physical light with a soft studio sky worked out in the
## material (reflections are off in the game), the paper's materials as patterns (white marble's veins, hammered iron,
## leather, obsidian with lava in its cracks, worn gold and bronze, wood, skin, bone) and glow groups the weapon's
## state lights (the crossbow's charge, the cannon's heat, the sword's bloodlust, the staff's heat).

const K := preload("res://scripts/artkit.gd")

const ART := """
shader_type spatial;
render_mode diffuse_lambert, fog_disabled%s;
%s
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 key_col = vec3(1.0, 0.97, 0.92);   // (held) the studio's key light, from up and to the left
uniform vec3 rim_col = vec3(0.7, 0.8, 1.0);     // and the light behind it, from the right
uniform float key_k = 1.0;
uniform float env_k = 1.0;        // the studio sky in its reflections
uniform float amb_k = 0.0;        // and its soft light on the matte parts (the weapon in your hands takes some)
uniform vec3 tint = vec3(1.0);    // the studio's light leaning to the place's own
uniform float view_env = 0.0;     // 1: the studio turns with the eye (the weapon in your hands), 0: it stays with the world
uniform float pscale = 7.0;       // the patterns: tiles a metre
uniform float far = 18.0;         // past this the patterns fade out
uniform float glow[8];            // each glow group's brightness...
uniform vec3 glow_col[8];         // ...and colour (linear)
uniform float fill = 0.0;         // group 7: how far along its length the fill has come (0..1)
varying vec3 opos; varying vec3 onrm;
%s
const vec3 S_TOP = vec3(0.86, 0.84, 0.8); const vec3 S_MID = vec3(0.34, 0.31, 0.28); const vec3 S_BOT = vec3(0.06, 0.055, 0.05);
const vec3 SH[9] = vec3[9](vec3(1.09832, 1.25451, 1.52018), vec3(0.47433, 0.52976, 0.61468), vec3(-0.00065, 0.01017, 0.02544), vec3(0.01162, 0.01511, 0.02024),
	vec3(0.00269, 0.00191, 0.00108), vec3(-0.01698, -0.01555, -0.01276), vec3(-0.01285, -0.01153, -0.00801), vec3(0.01414, 0.01382, 0.01253), vec3(-0.02978, -0.03288, -0.03432));
vec3 sky(vec3 d) { return d.y >= 0.0 ? mix(S_MID, S_TOP, pow(d.y, 0.7)) : mix(S_MID, S_BOT, pow(-d.y, 0.5)); }
float panel(vec3 d, vec3 P, float w, float soft) {
	float dist = length(P); vec3 n = P / dist; float c = dot(d, n);
	if (c <= 0.0) return 0.0;
	vec3 z = -n; vec3 x = normalize(cross(vec3(0.0, 1.0, 0.0), z)); vec3 y = cross(z, x); vec3 h = d * (dist / c) - P; float e = soft * dist;
	return (1.0 - smoothstep(w * 0.5 - e, w * 0.5 + e, abs(dot(h, x)))) * (1.0 - smoothstep(w * 0.2 - e, w * 0.2 + e, abs(dot(h, y))));
}
vec3 studio(vec3 d, float r) {
	float soft = 0.02 + r * 0.35; vec3 c = sky(d);
	c = mix(c, vec3(1.25), panel(d, vec3(5.0, 6.0, 2.0), 6.0, soft));
	c = mix(c, vec3(1.1, 0.95, 0.75), panel(d, vec3(-6.0, 4.0, -3.0), 4.0, soft));
	c = mix(c, vec3(1.15), panel(d, vec3(0.0, 8.0, -6.0), 8.0, soft));
	c = mix(c, vec3(0.62, 0.78, 1.0), panel(d, vec3(3.0, -2.0, 7.0), 5.0, soft));
	return c;
}
vec3 irradiance(vec3 n) {
	return max(SH[0] * 0.282095 + SH[1] * 0.488603 * n.y + SH[2] * 0.488603 * n.z + SH[3] * 0.488603 * n.x + SH[4] * 1.092548 * n.x * n.y + SH[5] * 1.092548 * n.y * n.z
		+ SH[6] * 0.315392 * (3.0 * n.z * n.z - 1.0) + SH[7] * 1.092548 * n.x * n.z + SH[8] * 0.546274 * (n.x * n.x - n.y * n.y), vec3(0.0));
}
vec3 lin(vec3 s) { return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), s)); }
vec4 tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z + 1e-5);
	return texture(noise_tex, p.yz) * w.x + texture(noise_tex, p.xz + 0.37) * w.y + texture(noise_tex, p.xy + 0.71) * w.z;
}
void vertex() { opos = VERTEX; onrm = NORMAL; }
void fragment() {
	vec3 base = lin(COLOR.rgb); float metal = UV.x; float rough = UV.y; float mask = COLOR.a;
	int pat = int(UV2.x + 0.5); int grp = int(UV2.y + 0.5);
	float near_k = 1.0 - smoothstep(far * 0.6, far, length(VERTEX));
	float crack = 0.0;
	if (pat > 0 && near_k > 0.0) {
		vec4 nz = tri(opos * pscale, onrm);
		if (pat == 1) {          // white marble: grey veins and a little cloud
			float v = smoothstep(0.70, 0.92, nz.r) * near_k; float cl = (nz.b - 0.5) * near_k;
			base = mix(base * (1.0 + 0.08 * cl), base * vec3(0.58, 0.58, 0.64), v * 0.8); rough = clamp(rough + v * 0.12 - cl * 0.12, 0.04, 1.0);
		} else if (pat == 2) {   // hammered iron: dents
			float d = (nz.g - 0.5) * near_k; base *= 1.0 + d * 0.55; rough = clamp(rough + d * 0.4, 0.05, 1.0);
		} else if (pat == 3) {   // leather
			float d = (nz.b - 0.5) * near_k; base *= 1.0 + d * 0.5; rough = clamp(rough + 0.08 + d * 0.25, 0.05, 1.0);
		} else if (pat == 4) {   // obsidian: dark glass with faint swirls, lava in its cracks
			base *= 1.0 + (nz.r - 0.5) * 0.9 * near_k; crack = (1.0 - smoothstep(0.012, 0.05, nz.a)) * near_k;
		} else if (pat == 5) {   // worn gold or bronze
			float d = (nz.b - 0.5) * near_k; base *= 1.0 + d * 0.3; rough = clamp(rough + d * 0.3, 0.05, 1.0);
		} else if (pat == 6) {   // wood's grain
			float g = sin(opos.z * 55.0 + nz.r * 9.0) * 0.5 + 0.5; base *= mix(1.0, 0.7 + 0.42 * g, near_k); rough = clamp(rough + (g - 0.5) * 0.15, 0.05, 1.0);
		} else if (pat == 7) {   // skin: mottled
			base *= 1.0 + (nz.b - 0.5) * 0.32 * near_k + (nz.g - 0.5) * 0.12 * near_k;
		} else if (pat == 8) {   // weathered bone
			float d = (nz.g - 0.5) * near_k; base = mix(base, base * vec3(0.78, 0.7, 0.55), clamp(-d * 1.6, 0.0, 1.0)); rough = clamp(rough - d * 0.2, 0.05, 1.0);
		} else if (pat == 9) {   // cloth
			base *= 1.0 + (nz.b - 0.5) * 0.4 * near_k;
		}
	}
	vec3 n; vec3 v;
	if (view_env > 0.5) { n = NORMAL; v = VIEW; }
	else { n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz); }
	float nv = clamp(dot(n, v), 0.0, 1.0);
	vec3 emis = vec3(0.0);
	if (grp == 0) emis = base * mask * 3.0;
	else if (grp == 7) { float on = 1.0 - smoothstep(fill - 0.025, fill + 0.025, mask); emis = glow_col[7] * glow[7] * on * (0.78 + 0.22 * sin(TIME * 7.0 - mask * 40.0)); }
	else { float m = pat == 4 ? max(mask * 0.35, crack) : mask; emis = glow_col[grp] * glow[grp] * m; }
	if (pat == 10) emis *= 0.55 + 1.6 * pow(1.0 - nv, 2.0);   // (a crystal: brightest at its edges)
	ALBEDO = albedo_of(base); METALLIC = metal; ROUGHNESS = rough;
	vec3 f0 = mix(vec3(0.04), base, metal);
	vec3 F = (max(vec3(1.0 - rough), f0) - f0) * exp2((-5.55473 * nv - 6.98316) * nv) + f0;
	vec4 r4 = rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
	float a004 = min(r4.x * r4.x, exp2(-9.28 * nv)) * r4.x + r4.y; vec2 brdf = vec2(-1.04, 1.04) * a004 + r4.zw;
	vec3 fss = F * brdf.x + brdf.y; float ems = 1.0 - (brdf.x + brdf.y);
	vec3 favg = f0 + (1.0 - f0) * 0.047619; vec3 fms = fss * favg / (1.0 - ems * favg);
	vec3 irr = irradiance(n) * tint; vec3 rad = studio(reflect(-v, n), rough) * tint;
	vec3 diffuse = base * (1.0 - metal) * (1.0 - (fss + fms * ems));
#ifdef HELD
	// the weapon in your hands, lit as the paper's renders are: a key light up and to the left, a cooler one behind it
	// to the right, the studio's soft light all round, its reflections; the place's light only in the tint
	vec3 L1 = normalize(vec3(-0.45, 0.75, 0.55)); vec3 L2 = normalize(vec3(0.85, 0.2, -0.5));
	float wrap = (pat == 1 || pat == 7) ? 0.3 : 0.0;
	float d1 = max(0.0, (dot(n, L1) + wrap) / (1.0 + wrap)); float d2 = max(0.0, dot(n, L2));
	vec3 lit = (key_col * d1 * key_k + rim_col * d2 * 0.45) * tint + irr * amb_k;
	vec3 h = normalize(L1 + v); float nh = max(0.0, dot(n, h)); float a = max(rough * rough, 0.003); float a2 = a * a;
	float dd = nh * nh * (a2 - 1.0) + 1.0; float D = a2 / (3.14159 * dd * dd);
	vec3 spec = F * min(D, 60.0) * d1 * 0.22 * key_col * key_k * tint;
	vec3 c = diffuse * lit + spec + (rad * fss + fms * ems * irr) * env_k + emis;
	ALBEDO = albedo_of(c);
#else
	EMISSION = albedo_of((rad * fss + fms * ems * irr) * env_k + diffuse * irr * amb_k + emis);
#endif
}
"""

## see-through glass and crystal: the studio's light off its face, strongest at its edges, the rest let through
const GLASS := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, fog_disabled;
uniform vec4 col : source_color = vec4(0.8, 0.9, 1.0, 0.1);
uniform float shine = 1.0;
%s
const vec3 S_TOP = vec3(0.70, 0.76, 0.86); const vec3 S_MID = vec3(0.26, 0.27, 0.31); const vec3 S_BOT = vec3(0.05, 0.05, 0.06);
vec3 sky(vec3 d) { return d.y >= 0.0 ? mix(S_MID, S_TOP, pow(d.y, 0.7)) : mix(S_MID, S_BOT, pow(-d.y, 0.5)); }
void fragment() {
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0); float fr = 0.04 + 0.96 * pow(1.0 - nv, 4.0);
	vec3 r = reflect(-VIEW, NORMAL); vec3 s = sky(r) + vec3(1.4) * smoothstep(0.86, 0.95, dot(r, normalize(vec3(0.45, 0.75, 0.3))));
	vec3 c = mix(col.rgb, s, fr) * shine;
	ALBEDO = albedo_of(c); ALPHA = clamp(col.a + fr * 0.85, 0.0, 1.0);
}
"""

static var _shaders := {}
static var _noise: ImageTexture = null
static var _meshes := {}      # built shapes, kept for the whole run (a body's are the same for everyone of its side)
static var _sprite_tex: ImageTexture = null

static func noise_tex() -> ImageTexture:
	if _noise != null: return _noise
	var n := 256
	var make := func(kind: int, freq: float, frac: int, oct: int, ret := 0) -> PackedByteArray:
		var fn := FastNoiseLite.new(); fn.seed = 7 + kind; fn.noise_type = kind; fn.frequency = freq; fn.fractal_type = frac; fn.fractal_octaves = oct
		if kind == FastNoiseLite.TYPE_CELLULAR: fn.cellular_return_type = ret; fn.cellular_jitter = 0.9
		var img := fn.get_seamless_image(n, n, false, false, 0.12, true); img.convert(Image.FORMAT_L8)
		return img.get_data()
	var r: PackedByteArray = make.call(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, FastNoiseLite.FRACTAL_RIDGED, 4)
	var g: PackedByteArray = make.call(FastNoiseLite.TYPE_CELLULAR, 0.05, FastNoiseLite.FRACTAL_NONE, 1, FastNoiseLite.RETURN_DISTANCE)
	var b: PackedByteArray = make.call(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06, FastNoiseLite.FRACTAL_FBM, 3)
	var a: PackedByteArray = make.call(FastNoiseLite.TYPE_CELLULAR, 0.022, FastNoiseLite.FRACTAL_NONE, 1, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var out := PackedByteArray(); out.resize(n * n * 4)
	for i in n * n:
		var k := i * 4; out[k] = r[i]; out[k + 1] = g[i]; out[k + 2] = b[i]; out[k + 3] = a[i]
	var img2 := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, out); img2.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img2)
	return _noise

static func _shader(key: String) -> Shader:
	if not _shaders.has(key):
		var sh := Shader.new()
		if key == "glass": sh.code = GLASS % Gfx.ALBEDO_GLSL
		elif key.begins_with("held"): sh.code = ART % [", unshaded" + (", cull_disabled" if key == "held_two" else ""), "#define HELD", Gfx.ALBEDO_GLSL]
		else: sh.code = ART % [", cull_disabled" if key == "two" else "", "", Gfx.ALBEDO_GLSL]
		_shaders[key] = sh
	return _shaders[key]

## the art material: held (the weapon in your hands: the studio turns with your eye, a little of its soft light on it) or
## worn (a body in the world: the place's light, less of the studio); glows: group -> [screen colour, brightness]
static func mat(held: bool, glows := {}, two := false) -> ShaderMaterial:
	var key := ("held_two" if held else "two") if two else ("held" if held else "one")
	var m := ShaderMaterial.new(); m.shader = _shader(key)
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("view_env", 1.0 if held else 0.0); m.set_shader_parameter("env_k", 0.85 if held else 0.55)
	m.set_shader_parameter("amb_k", 0.42 if held else 0.0); m.set_shader_parameter("pscale", 7.0 if held else 3.5); m.set_shader_parameter("far", 18.0 if held else 22.0)
	var gl := PackedFloat32Array(); gl.resize(8); var gc := PackedVector3Array(); gc.resize(8)
	for g: int in glows:
		var e: Array = glows[g]; var c: Color = (e[0] as Color).srgb_to_linear(); gc[g] = Vector3(c.r, c.g, c.b); gl[g] = float(e[1])
	m.set_shader_parameter("glow", gl); m.set_shader_parameter("glow_col", gc)
	return m

## a group's light set on a material (colour as a screen colour, made linear; brightness)
static func set_glow(m: ShaderMaterial, g: int, c: Color, k: float) -> void:
	var gc: PackedVector3Array = m.get_shader_parameter("glow_col"); var gl: PackedFloat32Array = m.get_shader_parameter("glow")
	var l := c.srgb_to_linear(); gc[g] = Vector3(l.r, l.g, l.b); gl[g] = k
	m.set_shader_parameter("glow_col", gc); m.set_shader_parameter("glow", gl)

static func glass(c: Color, prio := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _shader("glass"); m.set_shader_parameter("col", c); m.render_priority = prio
	return m

## a soft round light that always faces you (a crystal's halo, an ember's), added to what is behind it
static func sprite(c: Color, size: float, parent: Node3D = null) -> MeshInstance3D:
	if _sprite_tex == null: _sprite_tex = Gfx.glow_tex(Color(1, 1, 1, 1), Color(1, 1, 1, 0.45))
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_texture = _sprite_tex; fm.albedo_color = c
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.disable_fog = true; fm.no_depth_test = false
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = Gfx.see_through(fm); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null: parent.add_child(mi)
	return mi

## a mesh built once by `make` (given a fresh kit) and kept under `key`
static func built(key: String, make: Callable, detail := 1.0) -> ArrayMesh:
	if not _meshes.has(key):
		var k := ArtKit.new(); k.detail = detail; make.call(k); _meshes[key] = k.mesh()
	return _meshes[key]

static func piece(parent: Node3D, key: String, make: Callable, m: Material, at := Vector3.ZERO, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = built(key, make); mi.material_override = m; mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "": mi.name = name
	parent.add_child(mi)
	return mi

static func hexc(s: String) -> Color: return Color(s)

# ---------------- the paper's colours ----------------
## each people's weapon colours (screen colours), and the mythic skin's in their place
const PAL := {
	"elf": {"marble": "eceef1", "gold": "d8a33e", "ivory": "efe3c2", "groove": "2a2630", "glow": "38bdf8", "charge": "a855f7", "core": "8f45e8", "gem": "4fd8e8",
		"glove": "5e4330", "glove2": "3e2c20", "cuff": "e9e4d6", "skin": "e8c9ac"},
	"dwarf": {"iron": "4a4d55", "iron2": "34363c", "bronze": "b67c3c", "copper": "c56f3e", "leather": "5a3a24", "wood": "6e4426", "brass": "d9aa4a", "dial": "efe6cf",
		"needle": "c0302a", "valve": "b8241c", "glow": "f59e0b", "steam": "e0f2fe", "blue": "5a6a9a", "oil": "3a2a12", "frost": "9fd8ff", "gaunt": "a8743a", "gaunt2": "5a3a24"},
	"orc": {"steel": "35373b", "edge": "8d9197", "bone": "d6c9aa", "wrap": "6b4a2c", "chain": "3a3c40", "glow": "ef4444", "rune": "b01818", "skin": "6f9a4a",
		"skin2": "567a38", "brace": "4a4c50", "haft": "4a3424"},
	"demon": {"obsid": "15121a", "obsid2": "221c26", "chain": "4c4548", "hot": "ff4a1a", "lava": "f97316", "white": "fef08a", "core": "060406", "skin": "a8382e",
		"skin2": "7a2420", "claw": "121014", "brace": "1c171f"},
}
const SKIN_PAL := {
	"elf": {"marble": "221a2c", "gold": "9b6ad6", "ivory": "3a2a4a", "groove": "120c18", "glow": "c98bff", "charge": "e8d0ff", "core": "d0a0ff", "gem": "c98bff"},
	"dwarf": {"iron": "2c2224", "iron2": "1e1618", "bronze": "6a3428", "copper": "8a3a24", "glow": "ff6a1a", "steam": "ff8a5a", "blue": "6a2a1a"},
	"orc": {"steel": "1c1618", "edge": "ff8a2a", "glow": "ff5a1a", "rune": "ff5a1a"},
	"demon": {"obsid": "0b080d", "chain": "2a2024", "core": "000000"},
}
static func pal(race: String, skinned := false) -> Dictionary:
	var p: Dictionary = (PAL[race] as Dictionary).duplicate()
	if skinned: p.merge(SKIN_PAL.get(race, {}), true)
	var out := {}
	for k: String in p: out[k] = Color(str(p[k]))
	return out

# ---------------- hands ----------------
## a hand closed round a grip whose axis is the frame's y (the grip `r` round, at the origin): the back of the hand to +x,
## the fingers round the front (-z) and over to -x, the thumb round the back (+z). side -1: a left hand (mirrored).
## look: "glove" (the elf's), "gaunt" (the dwarf's bronze), "orc", "demon"; P: its colours; arm: the way the forearm goes
static func hand(k: ArtKit, P: Dictionary, r: float, side: float, look: String, arm := Vector3(0.25, -0.35, 1.0), open := 0.0) -> void:
	var fat := 1.0; var c1: Color; var c2: Color; var skin_pat := ArtKit.LEATHER; var m1 := 0.0; var r1 := 0.75
	match look:
		"glove": c1 = P.glove; c2 = P.glove2
		"gaunt": c1 = P.gaunt; c2 = P.gaunt2; m1 = 1.0; r1 = 0.4; skin_pat = ArtKit.WORN; fat = 1.15
		"orc": c1 = P.skin; c2 = P.skin2; skin_pat = ArtKit.SKIN; r1 = 0.62; fat = 1.3
		"demon": c1 = P.skin; c2 = P.skin2; skin_pat = ArtKit.SKIN; r1 = 0.5; fat = 1.0
	k.push(Transform3D(Basis.from_scale(Vector3(side, 1.0, 1.0)), Vector3.ZERO))
	# the fingers: index on top, little finger below, each in three bones round the grip
	var lens := [[0.042, 0.026, 0.021], [0.046, 0.029, 0.022], [0.043, 0.027, 0.021], [0.034, 0.021, 0.018]]
	var rads := [0.0088, 0.009, 0.0086, 0.0075]
	for i in 4:
		var y := 0.026 - i * 0.0185; var fr: float = rads[i] * fat; var R := r + fr * 0.95
		var a := -0.35 + open * 0.6; var pts: Array = [Vector3(cos(a) * (r + 0.022 * fat), y, -sin(a) * (r + 0.022 * fat) * 0.6)]
		for j in 3:
			var L: float = lens[i][j] * (1.0 + (fat - 1.0) * 0.5)
			a += 2.0 * asin(clampf(L / (2.0 * R), 0.0, 0.99)) * (1.0 - open * 0.55)
			pts.push_back(Vector3(cos(a) * R, y - j * 0.001, -sin(a) * R))
		var path := ArtKit.spline(pts, 4)
		var radii := PackedFloat32Array()
		for q in path.size(): var t := float(q) / (path.size() - 1); radii.push_back(fr * (1.06 - 0.28 * t))
		k.paint(c1, m1, r1, skin_pat); k.tube(path, radii, 7)
		var tip: Vector3 = path[path.size() - 1]
		k.ball(tip, Vector3.ONE * fr * 0.78, 7, 4)
		if look == "gaunt":   # (a plate on each bone)
			for j in 3:
				var p0: Vector3 = pts[j]; var p1: Vector3 = pts[j + 1]; var mid := (p0 + p1) * 0.5; var out := Vector3(mid.x, 0, mid.z).normalized()
				k.paint(c1.lightened(0.08), 1.0, 0.32, ArtKit.WORN); k.toward(mid + out * fr * 0.5, (p1 - p0).normalized(), out); k.rbox(Vector3(fr * 2.2, fr * 1.2, (p1 - p0).length() * 0.8), Vector3.ZERO, 0.002); k.pop()
		if look == "demon":   # (black claws)
			var d: Vector3 = (path[path.size() - 1] - path[path.size() - 2]).normalized()
			k.paint(P.claw, 0.3, 0.15); k.tube(PackedVector3Array([tip - d * 0.004, tip + d * 0.012 + Vector3(0, -0.002, 0), tip + d * 0.02 + Vector3(0, -0.006, 0)]), PackedFloat32Array([fr * 0.62, fr * 0.35, 0.0006]), 6)
		if look == "orc" or look == "glove":   # (knuckles)
			k.paint(c2 if look == "glove" else c1.darkened(0.05), m1, r1, skin_pat); k.ball(pts[1] + Vector3(0, 0, 0) * 0.0, Vector3.ONE * fr * 1.12, 6, 4)
	# the palm and the back of the hand
	k.paint(c1, m1, r1, skin_pat)
	k.ball(Vector3(r + 0.016 * fat, -0.004, 0.012), Vector3(0.017 * fat, 0.042, 0.033) , 10, 6)
	if look == "gaunt":
		k.paint(c1.lightened(0.1), 1.0, 0.3, ArtKit.WORN); k.ball(Vector3(r + 0.028, -0.004, 0.006), Vector3(0.012, 0.045, 0.035), 10, 5)
		for j in 3: k.dome(Vector3(r + 0.039, 0.022 - j * 0.022, 0.006), Vector3.RIGHT, 0.0035)
	elif look == "glove":
		k.paint(c2, 0.0, 0.7, ArtKit.LEATHER); k.ball(Vector3(r + 0.025, -0.004, 0.008), Vector3(0.008, 0.038, 0.028), 8, 5)
	# the thumb, round the back of the grip
	var tp: Array = [Vector3(r + 0.012, -0.03, 0.03)]; var ta := 0.6
	for j in 3:
		ta += 0.62; tp.push_back(Vector3(cos(ta) * (r + 0.011), 0.008 + j * 0.01, sin(ta) * (r + 0.011) + 0.006))
	var tpath := ArtKit.spline(tp, 4); var tr := PackedFloat32Array()
	for q in tpath.size(): var t := float(q) / (tpath.size() - 1); tr.push_back(0.011 * fat * (1.15 - 0.35 * t))
	k.paint(c1, m1, r1, skin_pat); k.tube(tpath, tr, 7); k.ball(tpath[tpath.size() - 1], Vector3.ONE * 0.0075 * fat, 7, 4)
	if look == "demon":
		var tt: Vector3 = tpath[tpath.size() - 1]; var dd: Vector3 = (tpath[tpath.size() - 1] - tpath[tpath.size() - 2]).normalized()
		k.paint(P.claw, 0.3, 0.15); k.tube(PackedVector3Array([tt, tt + dd * 0.016]), PackedFloat32Array([0.005, 0.0006]), 6)
	# the wrist and the forearm, going off out of sight
	var w0 := Vector3(r + 0.016 * fat, -0.032, 0.03); var ad := arm.normalized()
	var apath := PackedVector3Array([w0, w0 + ad * 0.06, w0 + ad * 0.16, w0 + ad * 0.34])
	var ar := PackedFloat32Array([0.024 * fat, 0.027 * fat, 0.032 * fat, 0.036 * fat])
	k.paint(c1, m1, r1, skin_pat); k.tube(apath, ar, 10)
	match look:
		"glove":   # a dark leather vambrace laced with gold, a white-and-gold plate on its back
			k.paint(P.glove2, 0.0, 0.62, ArtKit.LEATHER); k.tube(PackedVector3Array([w0 + ad * 0.04, w0 + ad * 0.22]), PackedFloat32Array([0.028, 0.034]), 12)
			k.paint(P.gold, 1.0, 0.22, ArtKit.WORN)
			for e: float in [0.04, 0.13, 0.22]: k.toward(w0 + ad * e, ad); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.0285 + e * 0.028, 0.0022, 16, 5); k.pop(); k.pop()
			k.paint(P.cuff, 0.0, 0.3, ArtKit.MARBLE); k.toward(w0 + ad * 0.13, ad, Vector3(1, 0.4, 0)); k.ball(Vector3(0.0, 0.026, 0.0), Vector3(0.016, 0.007, 0.07), 10, 5); k.pop()
		"gaunt":   # a flared bronze cuff, riveted
			k.paint(P.gaunt, 1.0, 0.35, ArtKit.WORN); k.tube(PackedVector3Array([w0 + ad * 0.04, w0 + ad * 0.1, w0 + ad * 0.22]), PackedFloat32Array([0.04, 0.036, 0.04]), 12)
			k.paint(P.gaunt.darkened(0.2), 1.0, 0.4, ArtKit.WORN); k.toward(w0 + ad * 0.04, ad); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.041, 0.004, 16, 5); k.pop(); k.pop()
		"orc":   # leather wraps and an iron bracer with studs
			k.paint(P.wrap, 0.0, 0.8, ArtKit.LEATHER); k.tube(PackedVector3Array([w0 + ad * 0.0, w0 + ad * 0.05]), PackedFloat32Array([0.03, 0.032]), 10)
			k.paint(P.brace, 0.9, 0.55, ArtKit.IRON); k.tube(PackedVector3Array([w0 + ad * 0.08, w0 + ad * 0.24]), PackedFloat32Array([0.043, 0.048]), 12)
			for j in 4:
				var o := Vector3(cos(j * 1.2 + 0.3), sin(j * 1.2 + 0.3), 0) * 0.046
				k.toward(w0 + ad * 0.16, ad); k.paint(P.edge, 1.0, 0.35); k.tube(PackedVector3Array([o, o * 1.45]), PackedFloat32Array([0.006, 0.0008]), 6); k.pop()
		"demon":   # an obsidian bracer with spikes
			k.paint(P.brace, 0.3, 0.12, ArtKit.OBSIDIAN, 1); k.tube(PackedVector3Array([w0 + ad * 0.06, w0 + ad * 0.22]), PackedFloat32Array([0.031, 0.036]), 10)
			for j in 3:
				var o := Vector3(cos(j * 1.6 + 0.8), sin(j * 1.6 + 0.8), 0) * 0.033
				k.toward(w0 + ad * (0.1 + j * 0.04), ad); k.tube(PackedVector3Array([o, o * 1.8 + Vector3(0, 0, 0.02)]), PackedFloat32Array([0.007, 0.0008]), 6); k.pop()
	k.pop()

# ---------------- helpers for the weapons ----------------
## an outline drawn side-on (each point (z, y): z back toward you, y up) made a slab `t` thick across x
static func side(k: ArtKit, zy: Array, t: float, bevel := 0.004, steps := 2, x := 0.0) -> void:
	var p := PackedVector2Array()
	for q: Vector2 in zy: p.push_back(Vector2(-q.x, q.y))
	k.at(Vector3(x, 0, 0), Vector3(0, PI / 2.0, 0)); k.extrude(p, t, bevel, steps); k.pop()

## a ring of gold round an axis: at p, the ring's axis along d
static func band(k: ArtKit, p: Vector3, d: Vector3, R: float, r: float, n := 18) -> void:
	k.toward(p, d); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(R, r, n, 5); k.pop(); k.pop()

## filigree on a flat side: scrolls drawn in the plane x = x0 (facing +x if out > 0), each [z, y, dir, len, curl, turns, left]
static func filigree(k: ArtKit, x0: float, out: float, list: Array, r := 0.0011) -> void:
	k.at(Vector3(x0, 0, 0), Vector3(0, PI / 2.0 if out > 0.0 else -PI / 2.0, 0))
	for s: Array in list:
		var zz: float = s[0]; var px := -zz if out > 0.0 else zz
		var c := ArtKit.scroll(Vector2(px, float(s[1])), float(s[2]) if out > 0.0 else PI - float(s[2]), float(s[3]), float(s[4]), float(s[5]), bool(s[6]) == (out > 0.0))
		k.relief(c, r, 0.0)
	k.pop()

## a unit stick along -z (a string, a beam): scaled along z to its length where it is used
static func stick_mesh(key: String, r: float, c: Color, group := 1, lit := 1.0) -> ArrayMesh:
	return built(key, func(k: ArtKit) -> void:
		k.paint(c, 0.0, 0.4, ArtKit.PLAIN, group, lit); k.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -1.0)]), r, 6, false))

## a node that stretches `stick` from a to b (in its parent's frame)
static func stretch(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a; var L := d.length()
	if L < 0.0001: n.visible = false; return
	n.visible = true
	var z := -d / L; var x := Vector3.UP.cross(z)
	if x.length() < 0.001: x = Vector3.RIGHT
	x = x.normalized(); var y := z.cross(x)
	n.transform = Transform3D(Basis(x, y, z * L), a)

# ---------------- the elves' arcane repeater (비전 연발 석궁) ----------------
## white marble and antique gold; an open chamber with a violet octahedral crystal floating in it; a long rail of ivory
## and gold with rune marks along its groove; asymmetric limbs, a string of teal mana; for a sight four gold crescents
## floating round the line you aim along. Its moving parts: the crescents (they close on the middle as it charges), the
## core (it pulses with each shot and rises to be filled on the reload), the string (drawn back as it charges), the gold
## lever on its left (thrown by your left hand on the reload) and the arrow of light laid on the rail
const XB_SIGHT := Vector3(0, 0.112, -0.03)
const XB_CORE := Vector3(0, 0.024, -0.112)
const XB_TIP := Vector3(0, 0.062, -0.66)
const XB_NOCK_R := Vector3(0.318, 0.045, -0.448)
const XB_NOCK_L := Vector3(-0.334, 0.036, -0.452)
const XB_STRING_Z := -0.262      # where the string rests (drawn: XB_DRAWN)
const XB_DRAWN := -0.168

static func xbow(skinned := false) -> Dictionary:
	var P := pal("elf", skinned); var key := "xb" + ("_sk" if skinned else "")
	var m := mat(true, {1: [P.glow, 2.2], 2: [P.core, 2.6], 3: [P.glow, 1.2], 4: [P.gem, 2.0]})
	var root := Node3D.new(); root.name = "Xbow"
	piece(root, key + "_body", func(k: ArtKit) -> void: _xbow_body(k, P), m)
	var rig := {"root": root, "mat": m, "tip": XB_TIP}
	# the four crescents, floating round the sight line
	var sight := Node3D.new(); sight.position = XB_SIGHT; root.add_child(sight); rig.sight = sight
	var cres: Array = []
	for i in 4:
		var big := i % 2 == 0
		var c := piece(sight, key + ("_cres_big" if big else "_cres_small"), func(k: ArtKit) -> void:
			k.paint(P.gold, 1.0, 0.18, ArtKit.WORN, 3, 0.0)
			k.extrude(ArtKit.crescent(0.036 if big else 0.03, 0.011 if big else 0.008, 0.78 if big else 0.55, 16), 0.0045, 0.0014, 2)
			k.paint(P.glow, 0.0, 0.3, ArtKit.PLAIN, 3, 1.0); k.at(Vector3.ZERO, Vector3.ZERO); k.extrude(ArtKit.crescent(0.0262 if big else 0.0215, 0.0016, 0.7 if big else 0.48, 12), 0.0052, 0.0, 0); k.pop(), m)
		c.rotation.z = i * PI / 2.0 + (0.0 if big else 0.0); cres.push_back(c)
	rig.crescents = cres
	# the core: a violet octahedron in the chamber, a halo round it
	var core := Node3D.new(); core.position = XB_CORE; root.add_child(core); rig.core = core
	piece(core, key + "_core", func(k: ArtKit) -> void:
		k.paint(P.core, 0.0, 0.08, ArtKit.CRYSTAL, 2, 0.85); k.gem(0.0135, 0.019, 0.019, 4, PI / 4.0)
		k.paint(P.core.lightened(0.35), 0.0, 0.05, ArtKit.CRYSTAL, 2, 1.0); k.gem(0.006, 0.009, 0.009, 4, 0.0), m)
	rig.halo = sprite(Color(P.core.r, P.core.g, P.core.b, 0.55), 0.11, core)
	# the string: two lengths from the nocks to where it is drawn
	var sm := stick_mesh(key + "_string", 0.0016, P.glow, 1, 1.4)
	var strs: Array = []
	for i in 2: var s := MeshInstance3D.new(); s.mesh = sm; s.material_override = m; s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(s); strs.push_back(s)
	rig.string = strs
	rig.nub = sprite(Color(P.glow.r, P.glow.g, P.glow.b, 0.6), 0.05, root)
	for nk: Vector3 in [XB_NOCK_L, XB_NOCK_R]: var g := sprite(Color(P.glow.r, P.glow.g, P.glow.b, 0.5), 0.035, root); g.position = nk
	# the arrow of light on the rail
	var bolt := piece(root, key + "_bolt", func(k: ArtKit) -> void:
		k.paint(P.glow, 0.0, 0.3, ArtKit.PLAIN, 1, 1.6); k.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -0.3)]), PackedFloat32Array([0.0022, 0.0022]), 6)
		k.gem(0.005, 0.004, 0.004, 4); k.at(Vector3(0, 0, -0.3)); k.push(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)); k.cyl(0.006, 0.0, 0.022, 6); k.pop(); k.pop(), m, Vector3(0, 0.0675, -0.2))
	rig.bolt = bolt
	# the gold lever on its left side
	var lever := Node3D.new(); lever.position = Vector3(-0.031, 0.02, -0.052); root.add_child(lever); rig.lever = lever
	piece(lever, key + "_lever", func(k: ArtKit) -> void:
		k.paint(P.gold, 1.0, 0.22, ArtKit.WORN)
		k.at(Vector3(0, 0, 0), Vector3(0, PI / 2.0, 0)); k.cyl(0.007, 0.007, 0.004, 12); k.pop()
		side(k, [Vector2(0.0, 0.004), Vector2(0.05, 0.0), Vector2(0.062, -0.006), Vector2(0.05, -0.01), Vector2(0.0, -0.004)], 0.004, 0.0012, 2, -0.004)
		k.ball(Vector3(-0.005, -0.006, 0.062), Vector3(0.006, 0.006, 0.006), 8, 5), m)
	# the hands: your right round the grip, your left under the fore-end
	piece(root, "xb_rhand" + ("_sk" if skinned else ""), func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.93, -0.37).normalized(), Vector3(0, 0.37, 0.93).normalized()), Vector3(0, -0.072, 0.052)))
		hand(k, P, 0.0175, 1.0, "glove", Vector3(0.25, -0.79, 0.76)); k.pop(), m)
	var lh := Node3D.new(); lh.name = "lhand"; root.add_child(lh); rig.lhand = lh
	piece(lh, "xb_lhand", func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3(0, 0.0, -0.37)))
		hand(k, P, 0.025, -1.0, "glove", Vector3(0.4, -1.0, 0.3)); k.pop(), m)
	return rig

static func _xbow_body(k: ArtKit, P: Dictionary) -> void:
	var marble: Color = P.marble; var gold: Color = P.gold
	# the stock: its outline side-on, white marble edged in gold
	var stock := [Vector2(0.045, 0.02), Vector2(0.12, 0.016), Vector2(0.24, 0.008), Vector2(0.33, 0.004), Vector2(0.352, -0.004), Vector2(0.358, -0.06), Vector2(0.352, -0.12),
		Vector2(0.33, -0.124), Vector2(0.25, -0.092), Vector2(0.17, -0.07), Vector2(0.115, -0.058), Vector2(0.095, -0.05), Vector2(0.07, -0.03), Vector2(0.05, -0.012)]
	k.paint(marble, 0.0, 0.3, ArtKit.MARBLE); side(k, stock, 0.042, 0.009, 3)
	k.paint(gold, 1.0, 0.24, ArtKit.WORN); side(k, [Vector2(0.346, 0.006), Vector2(0.364, 0.004), Vector2(0.37, -0.12), Vector2(0.352, -0.126)], 0.046, 0.003, 2)   # (the butt plate)
	for sx: float in [1.0, -1.0]:
		var line := PackedVector3Array()
		for q: Vector2 in [Vector2(0.06, 0.005), Vector2(0.13, 0.002), Vector2(0.24, -0.004), Vector2(0.335, -0.008)]: line.push_back(Vector3(sx * 0.0205, q.y, q.x))
		k.tube(ArtKit.spline(Array(line), 4), 0.0012, 5)
		var line2 := PackedVector3Array()
		for q: Vector2 in [Vector2(0.11, -0.05), Vector2(0.19, -0.072), Vector2(0.27, -0.098), Vector2(0.335, -0.112)]: line2.push_back(Vector3(sx * 0.0205, q.y, q.x))
		k.tube(ArtKit.spline(Array(line2), 4), 0.0012, 5)
	filigree(k, 0.0212, 1.0, [[0.16, -0.025, 0.2, 0.05, 0.012, 1.3, true], [0.25, -0.045, 3.4, 0.04, 0.011, 1.2, false], [0.29, -0.03, 0.5, 0.03, 0.009, 1.4, true]])
	filigree(k, -0.0212, -1.0, [[0.16, -0.025, 0.2, 0.05, 0.012, 1.3, true], [0.25, -0.045, 3.4, 0.04, 0.011, 1.2, false]])
	# the grip, sloping back under your right hand, gold rings at its wrist
	k.paint(marble, 0.0, 0.3, ArtKit.MARBLE)
	var g0 := Vector3(0, -0.012, 0.03); var g1 := Vector3(0, -0.128, 0.077)
	k.sweep(PackedVector3Array([g0, g0.lerp(g1, 0.5), g1]), ArtKit.circle(14), [Vector2(0.019, 0.023), Vector2(0.0175, 0.022), Vector2(0.019, 0.024)], Vector3(0, 0, -1))
	k.paint(gold, 1.0, 0.22, ArtKit.WORN); k.ball(g1 + Vector3(0, -0.004, 0.002), Vector3(0.021, 0.008, 0.025), 12, 5)
	for e: float in [0.0, 0.08]: band(k, g0.lerp(g1, e) + Vector3(0, 0, 0), (g1 - g0).normalized(), 0.0225, 0.0026)
	# the receiver round the open chamber
	k.paint(marble, 0.0, 0.28, ArtKit.MARBLE)
	k.rbox(Vector3(0.056, 0.036, 0.205), Vector3(0, -0.017, -0.1), 0.007, 2)
	k.rbox(Vector3(0.056, 0.074, 0.048), Vector3(0, 0.018, -0.03), 0.007, 2)
	k.rbox(Vector3(0.056, 0.074, 0.046), Vector3(0, 0.018, -0.19), 0.007, 2)
	for sx: float in [1.0, -1.0]: k.rbox(Vector3(0.011, 0.013, 0.12), Vector3(sx * 0.0225, 0.049, -0.11), 0.004, 2)
	k.paint(P.groove, 0.2, 0.5); k.rbox(Vector3(0.036, 0.003, 0.118), Vector3(0, 0.0, -0.111), 0.001, 1)   # (the chamber's dark floor)
	k.paint(gold, 1.0, 0.2, ArtKit.WORN)
	for sx: float in [1.0, -1.0]:   # the gold frame round the window, each side; gold scrollwork at its corners
		k.at(Vector3(sx * 0.0285, 0.022, -0.111), Vector3(0, PI / 2.0 * sx, 0)); var rr := ArtKit.rrect(0.118, 0.05, 0.009, 3); rr.push_back(rr[0]); k.relief(rr, 0.0022); k.pop()
		filigree(k, sx * 0.0285, sx, [[-0.005, -0.012, 3.0, 0.02, 0.008, 1.2, true], [-0.205, -0.012, 0.1, 0.02, 0.008, 1.2, false]], 0.0011)
	for z: float in [-0.006, -0.214]:   # (gold rims round the receiver's two ends)
		var rr := ArtKit.rrect(0.058, 0.076, 0.008, 3); rr.push_back(rr[0]); k.at(Vector3(0, 0.018, z)); k.relief(rr, 0.0022); k.pop()
	# the trigger and its guard, gold
	side(k, [Vector2(-0.03, -0.035), Vector2(-0.024, -0.05), Vector2(-0.02, -0.062), Vector2(-0.016, -0.058), Vector2(-0.02, -0.046), Vector2(-0.024, -0.035)], 0.006, 0.0015, 1)
	var guard := ArtKit.spline([Vector3(0, -0.035, -0.06), Vector3(0, -0.068, -0.05), Vector3(0, -0.078, -0.02), Vector3(0, -0.07, 0.01), Vector3(0, -0.05, 0.03)], 5)
	k.tube(guard, 0.0028, 6); k.ball(Vector3(0, -0.079, -0.03), Vector3(0.005, 0.005, 0.005), 8, 5)
	# the rail: ivory with gold edges either side of its dark groove, rune marks along it, a gold point at its end
	k.paint(P.ivory, 0.0, 0.32, ArtKit.MARBLE); k.rbox(Vector3(0.04, 0.016, 0.45), Vector3(0, 0.054, -0.418), 0.004, 2)
	k.paint(gold, 1.0, 0.2, ArtKit.WORN)
	for sx: float in [1.0, -1.0]: k.rbox(Vector3(0.0125, 0.006, 0.44), Vector3(sx * 0.0125, 0.0645, -0.418), 0.0018, 1)
	k.paint(P.groove, 0.3, 0.35); k.rbox(Vector3(0.0115, 0.004, 0.445), Vector3(0, 0.063, -0.418), 0.001, 1)
	for i in 15:
		var z := -0.215 - i * 0.027
		for sx: float in [1.0, -1.0]:
			k.paint(gold.lightened(0.15), 1.0, 0.18, ArtKit.PLAIN, 1, 0.55); k.rbox(Vector3(0.0035, 0.0016, 0.009 if i % 3 == 0 else 0.005), Vector3(sx * 0.0072, 0.0675, z), 0.0006, 1)
	k.paint(gold, 1.0, 0.2, ArtKit.WORN)
	side(k, [Vector2(-0.636, 0.0545), Vector2(-0.66, 0.06), Vector2(-0.636, 0.069), Vector2(-0.62, 0.068), Vector2(-0.62, 0.05)], 0.034, 0.003, 2)
	# the fore-end under it, tapering, with gold scrolls on its sides
	k.paint(marble, 0.0, 0.3, ArtKit.MARBLE)
	var rings: Array = []
	for i in 7:
		var t := i / 6.0; var z := lerpf(-0.205, -0.5, t); var w := lerpf(0.05, 0.036, t); var y0 := lerpf(-0.034, -0.02, t); var y1 := 0.046
		var rr := ArtKit.rrect(w, y1 - y0, 0.012, 3); var ring := PackedVector3Array()
		for q in rr: ring.push_back(Vector3(q.x, (y0 + y1) * 0.5 + q.y, z))
		rings.push_back(ring)
	k.grid(rings, true, true); k.cap(rings[6], Vector3(0, 0, 0))
	k.paint(gold, 1.0, 0.22, ArtKit.WORN)
	for sx: float in [1.0, -1.0]:
		filigree(k, sx * 0.0245, sx, [[-0.24, 0.0, 3.3, 0.06, 0.012, 1.3, true], [-0.33, 0.012, 0.0, 0.05, 0.01, 1.4, false], [-0.33, -0.006, 3.0, 0.05, 0.011, 1.2, true], [-0.42, 0.005, 0.2, 0.05, 0.009, 1.3, true]])
		var edge := PackedVector3Array()
		for i in 7: var t := i / 6.0; edge.push_back(Vector3(sx * lerpf(0.025, 0.018, t), lerpf(-0.024, -0.012, t), lerpf(-0.21, -0.5, t)))
		k.tube(edge, 0.0012, 5)
	# the limbs' mount: gold, a teal gem either side
	k.rbox(Vector3(0.074, 0.03, 0.06), Vector3(0, 0.02, -0.5), 0.006, 2)
	for sx: float in [1.0, -1.0]:
		k.paint(P.gem, 0.0, 0.08, ArtKit.CRYSTAL, 4, 0.9); k.at(Vector3(sx * 0.038, 0.02, -0.5), Vector3(0, 0, PI / 2.0)); k.gem(0.007, 0.006, 0.006, 6); k.pop()
		k.paint(gold, 1.0, 0.2, ArtKit.WORN); band(k, Vector3(sx * 0.037, 0.02, -0.5), Vector3(sx, 0, 0), 0.0085, 0.0018, 14)
	# the limbs: white marble, their edges gold, their tips gold with teal nocks; the left a little longer and lower
	for sx: float in [1.0, -1.0]:
		var tip: Vector3 = XB_NOCK_R if sx > 0.0 else XB_NOCK_L
		var pts := [Vector3(sx * 0.035, 0.021, -0.5), Vector3(sx * 0.12, 0.024, -0.478), Vector3(sx * 0.22, 0.03 if sx > 0.0 else 0.024, -0.435), Vector3(tip.x * 0.92, tip.y - 0.004, tip.z + 0.03), tip]
		var path := ArtKit.spline(pts, 6); var sc := []
		for i in path.size(): var t := float(i) / (path.size() - 1); sc.push_back(Vector2(lerpf(0.0075, 0.0042, t), lerpf(0.017, 0.0075, t)))
		k.paint(marble, 0.0, 0.28, ArtKit.MARBLE); k.sweep(path, ArtKit.circle(14), sc, Vector3.UP)
		k.paint(gold, 1.0, 0.2, ArtKit.WORN)
		for e: float in [1.0, -1.0]:
			var ed := PackedVector3Array()
			for i in path.size() - 2: var t := float(i) / (path.size() - 1); ed.push_back(path[i] + Vector3(0, e * lerpf(0.0158, 0.0068, t), 0))
			k.tube(ed, 0.0019, 6, false)
		for e: float in [0.15, 0.32]:   # (gold bands round the limb near its root, and scrolls between)
			var q: int = int(e * (path.size() - 1)); var d: Vector3 = (path[q + 1] - path[q]).normalized()
			k.toward(path[q], d); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.at(Vector3.ZERO, Vector3.ZERO, Vector3(0.6, 1.0, 1.25)); k.torus(0.0135, 0.0018, 16, 5); k.pop(); k.pop(); k.pop()
		var dt: Vector3 = (path[path.size() - 1] - path[path.size() - 3]).normalized()
		k.tube(PackedVector3Array([tip - dt * 0.012, tip, tip + dt * 0.018]), PackedFloat32Array([0.0068, 0.0064, 0.0008]), 8)
		k.paint(P.glow, 0.0, 0.3, ArtKit.PLAIN, 1, 1.0); band(k, tip - dt * 0.004, dt, 0.0072, 0.0016, 12)
	# the sight's mounts: two little gold wings at the receiver's back
	k.paint(gold, 1.0, 0.2, ArtKit.WORN)
	for sx: float in [1.0, -1.0]:
		side(k, [Vector2(-0.03, 0.054), Vector2(0.0, 0.055), Vector2(0.008, 0.062), Vector2(-0.004, 0.064), Vector2(-0.022, 0.058)], 0.004, 0.0012, 1, sx * 0.025)

# ---------------- the dwarves' runic blunderbuss (룬 증기 산탄포) ----------------
## hammered cast iron, flaring to a bell, dwarven runes raised round it and its mouth blued by heat; riveted bronze; a
## boiler on its left side with a round pressure gauge whose needle never quite rests, copper pipes and a red-handled
## valve; under the barrel a mortar whose glass shows the grenade's liquid. It breaks open to load. Its moving parts: the
## barrel (on its hinge), the hammer, the gauge's needle, the valve's wheel, the mortar's liquid, five brass shells
const DW_HINGE := Vector3(0, -0.006, -0.07)
const DW_TIP := Vector3(0, 0.03, -0.56)
const DW_GAUGE := Vector3(-0.107, 0.034, -0.035)
const DW_VENTS := [Vector3(-0.05, 0.05, 0.02), Vector3(0.05, 0.05, 0.02)]

static func cannon(skinned := false) -> Dictionary:
	var P := pal("dwarf", skinned); var key := "dw" + ("_sk" if skinned else "")
	var m := mat(true, {1: [P.glow, 0.0], 2: [P.glow, 0.0], 3: [Color("ffd27a"), 1.4]})
	var root := Node3D.new(); root.name = "Cannon"
	var rig := {"root": root, "mat": m, "tip": DW_TIP}
	piece(root, key + "_body", func(k: ArtKit) -> void: _cannon_body(k, P), m)
	var barrel := Node3D.new(); barrel.position = DW_HINGE; root.add_child(barrel); rig.barrel = barrel
	piece(barrel, key + "_barrel", func(k: ArtKit) -> void: _cannon_barrel(k, P), m)
	var hammer := Node3D.new(); hammer.position = Vector3(0.026, 0.058, 0.03); root.add_child(hammer); rig.hammer = hammer
	piece(hammer, key + "_hammer", func(k: ArtKit) -> void:
		k.paint(P.iron2, 0.9, 0.45, ArtKit.IRON)
		side(k, [Vector2(0.0, -0.006), Vector2(0.012, -0.004), Vector2(0.016, 0.02), Vector2(0.006, 0.042), Vector2(-0.01, 0.046), Vector2(-0.014, 0.036), Vector2(-0.002, 0.03), Vector2(0.004, 0.012), Vector2(-0.004, 0.0)], 0.008, 0.0015, 1)
		k.paint(Color("8a8070"), 0.1, 0.8); k.rbox(Vector3(0.007, 0.01, 0.012), Vector3(0, 0.044, -0.014), 0.001, 1)   # (the flint in its jaw)
		k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN); k.at(Vector3.ZERO, Vector3(0, 0, PI / 2.0)); k.cyl(0.006, 0.006, 0.012, 10); k.pop(), m)
	# the gauge's needle and the valve's red wheel
	var needle := Node3D.new(); needle.position = DW_GAUGE + Vector3(-0.007, 0, 0); needle.rotation = Vector3(0, -PI / 2.0, 0); root.add_child(needle); rig.needle = needle
	piece(needle, key + "_needle", func(k: ArtKit) -> void:
		k.paint(P.needle, 0.3, 0.4, ArtKit.PLAIN, 3, 0.15); k.extrude(PackedVector2Array([Vector2(-0.0016, -0.004), Vector2(0.0016, -0.004), Vector2(0.0005, 0.021), Vector2(-0.0005, 0.021)]), 0.0012, 0.0, 0)
		k.paint(P.brass, 1.0, 0.3); k.at(Vector3.ZERO, Vector3(PI / 2.0, 0, 0)); k.cyl(0.0032, 0.0032, 0.003, 10); k.pop(), m)
	var valve := Node3D.new(); valve.position = Vector3(-0.07, 0.083, -0.07); root.add_child(valve); rig.valve = valve
	piece(valve, key + "_valve", func(k: ArtKit) -> void:
		k.paint(P.valve, 0.2, 0.45); k.torus(0.016, 0.0032, 18, 6)
		for i in 4: var a := i * PI / 2.0 + PI / 4.0; k.tube(PackedVector3Array([Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * 0.016]), 0.0022, 6, false)
		k.paint(P.brass, 1.0, 0.3, ArtKit.WORN); k.cyl(0.0045, 0.004, 0.006, 10), m)
	# the mortar's liquid behind its glass (the grenade's colour: oil, or frost with the rune)
	var liq := Node3D.new(); liq.position = Vector3(0, -0.052, -0.128); root.add_child(liq); rig.liquid = liq
	var lm := mat(true, {2: [P.oil, 0.6]}); rig.liq_mat = lm
	piece(liq, key + "_liquid", func(k: ArtKit) -> void:
		k.paint(Color.WHITE, 0.0, 0.15, ArtKit.PLAIN, 2, 0.35); k.at(Vector3.ZERO, Vector3(-PI / 2.0, 0, 0)); k.cyl(0.0175, 0.0175, 0.104, 14); k.pop(), lm)
	var gl := MeshInstance3D.new(); gl.mesh = built("dw_glass", func(k: ArtKit) -> void:
		k.at(Vector3(0, -0.052, -0.128), Vector3(-PI / 2.0, 0, 0)); k.cyl(0.0205, 0.0205, 0.104, 18, false); k.pop())
	gl.material_override = glass(Color(0.8, 0.9, 1.0, 0.08), Gfx.PRIO_HAND); gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(gl)
	# five brass shells, held in your left hand on the reload
	var shells := Node3D.new(); shells.visible = false; root.add_child(shells); rig.shells = shells
	piece(shells, key + "_shells", func(k: ArtKit) -> void:
		for i in 5:
			var x := (i - 2) * 0.017
			k.paint(P.brass, 1.0, 0.25, ArtKit.WORN); k.at(Vector3(x, 0, 0), Vector3(-PI / 2.0, 0, 0)); k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0085, 0.0), Vector2(0.0085, 0.004), Vector2(0.0075, 0.005), Vector2(0.0075, 0.05), Vector2(0.0, 0.052)]), 12, 0.0, TAU, true); k.pop()
			k.paint(P.glow, 0.0, 0.4, ArtKit.PLAIN, 1, 0.8); k.at(Vector3(x, 0, -0.03)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.0078, 0.0009, 12, 4); k.pop(); k.pop()
		k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN); k.rbox(Vector3(0.09, 0.006, 0.014), Vector3(0, -0.009, 0.004), 0.002, 1), m)
	# the hands in bronze gauntlets: the right round the grip, the left under the mortar
	piece(root, key + "_rhand", func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.9, -0.44).normalized(), Vector3(0, 0.44, 0.9).normalized()), Vector3(0, -0.078, 0.07)))
		hand(k, P, 0.02, 1.0, "gaunt", Vector3(0.25, -0.75, 0.8)); k.pop(), m)
	var lh := Node3D.new(); lh.name = "lhand"; root.add_child(lh); rig.lhand = lh
	piece(lh, key + "_lhand", func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3(0, -0.045, -0.26)))
		hand(k, P, 0.03, -1.0, "gaunt", Vector3(0.4, -1.0, 0.3)); k.pop(), m)
	return rig

static func _cannon_barrel(k: ArtKit, P: Dictionary) -> void:
	# (built from the hinge: the bore 0.036 above it, running forward)
	k.at(Vector3(0, 0.036, 0.0), Vector3(-PI / 2.0, 0, 0))
	k.paint(P.iron, 0.85, 0.5, ArtKit.IRON)
	k.lathe(PackedVector2Array([Vector2(0.0, -0.002), Vector2(0.034, -0.002), Vector2(0.036, 0.01), Vector2(0.034, 0.06), Vector2(0.031, 0.2), Vector2(0.033, 0.3)]), 24)
	k.paint(P.iron.lerp(P.blue, 0.55), 0.85, 0.42, ArtKit.IRON)
	k.lathe(PackedVector2Array([Vector2(0.033, 0.3), Vector2(0.038, 0.36), Vector2(0.05, 0.42), Vector2(0.067, 0.46), Vector2(0.072, 0.472), Vector2(0.068, 0.48), Vector2(0.058, 0.476)]), 26)
	k.paint(P.iron2, 0.6, 0.6, ArtKit.IRON, 1, 0.55)   # (the bore, glowing amber when hot)
	k.lathe(PackedVector2Array([Vector2(0.058, 0.476), Vector2(0.045, 0.44), Vector2(0.026, 0.38), Vector2(0.023, 0.2), Vector2(0.022, 0.0)]), 20)
	# bronze bands, riveted
	for y: float in [0.012, 0.15, 0.3]:
		k.paint(P.bronze, 1.0, 0.32, ArtKit.WORN); k.at(Vector3(0, y, 0)); k.lathe(PackedVector2Array([Vector2(0.0, -0.011), Vector2(0.036 if y < 0.2 else 0.035, -0.011), Vector2(0.038, -0.006), Vector2(0.038, 0.006), Vector2(0.036, 0.011), Vector2(0.0, 0.011)]), 24); k.pop()
		for i in 8: var a := i * TAU / 8.0; k.paint(P.brass, 1.0, 0.3); k.dome(Vector3(cos(a) * 0.038, y, sin(a) * 0.038), Vector3(cos(a), 0, sin(a)), 0.0026, 0.0018, 6)
	# dwarven runes raised round it, two rows, glowing amber when it is hot
	for row in 2:
		for i in 6:
			var a := i * TAU / 6.0 + row * 0.5; var y := 0.08 + row * 0.12; var rr := 0.0325 if row == 0 else 0.0315
			var o := Vector3(cos(a), 0, sin(a))
			k.paint(P.iron.lightened(0.12), 0.9, 0.4, ArtKit.PLAIN, 1, 1.0); k.toward(Vector3(o.x * rr, y, o.z * rr), -o, Vector3.UP); k.rune(i + row * 6, 0.016, 0.0024, 0.0012); k.pop()
	k.pop()
	# the hinge's knuckle
	k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN); k.at(Vector3.ZERO, Vector3(0, 0, PI / 2.0)); k.cyl(0.011, 0.011, 0.07, 14); k.pop()

static func _cannon_body(k: ArtKit, P: Dictionary) -> void:
	# the breech block: riveted bronze, the hinge's cheeks either side
	k.paint(P.bronze, 1.0, 0.36, ArtKit.WORN)
	k.rbox(Vector3(0.074, 0.08, 0.13), Vector3(0, 0.024, 0.0), 0.009, 2)
	for sx: float in [1.0, -1.0]:
		k.rbox(Vector3(0.012, 0.05, 0.05), Vector3(sx * 0.04, -0.004, -0.07), 0.004, 1)
		for i in 4: for j in 2: k.paint(P.brass, 1.0, 0.3); k.dome(Vector3(sx * 0.037, 0.0 + j * 0.05, 0.05 - i * 0.032), Vector3(sx, 0, 0), 0.0028, 0.002, 6)
		# a vent grille each side, where the steam comes out
		k.paint(P.iron2, 0.8, 0.5, ArtKit.IRON); k.rbox(Vector3(0.006, 0.026, 0.034), Vector3(sx * 0.038, 0.05, 0.02), 0.002, 1)
		for i in 4: k.paint(Color("2a2420"), 0.4, 0.7); k.rbox(Vector3(0.007, 0.0028, 0.028), Vector3(sx * 0.038, 0.04 + i * 0.0065, 0.02), 0.0006, 1)
		k.paint(P.bronze, 1.0, 0.36, ArtKit.WORN)
	k.paint(P.iron2, 0.85, 0.45, ArtKit.IRON); k.rbox(Vector3(0.05, 0.012, 0.03), Vector3(0.0, 0.07, 0.045), 0.003, 1)   # (the frizzen's pan)
	# the boiler on the left: a bronze tank with domed ends, two rows of rivets, the gauge on its side and the valve on top
	k.paint(P.bronze, 1.0, 0.34, ArtKit.WORN)
	k.at(Vector3(-0.072, 0.03, 0.03), Vector3(-PI / 2.0, 0, 0))
	k.lathe(PackedVector2Array([Vector2(0.0, -0.012), Vector2(0.018, -0.008), Vector2(0.03, 0.0), Vector2(0.032, 0.02), Vector2(0.032, 0.15), Vector2(0.03, 0.17), Vector2(0.018, 0.178), Vector2(0.0, 0.182)]), 22)
	for y: float in [0.03, 0.14]:
		for i in 12: var a := i * TAU / 12.0; k.paint(P.brass, 1.0, 0.3); k.dome(Vector3(cos(a) * 0.032, y, sin(a) * 0.032), Vector3(cos(a), 0, sin(a)), 0.0024, 0.0017, 6)
	k.paint(P.copper, 1.0, 0.3, ArtKit.WORN); for y: float in [0.06, 0.11]: k.at(Vector3(0, y, 0)); k.torus(0.0328, 0.0026, 22, 5); k.pop()
	k.pop()
	# the pressure gauge: a bronze bezel, a cream face with its marks (the red past the safe line)
	k.paint(P.bronze.lightened(0.1), 1.0, 0.25, ArtKit.WORN); k.toward(DW_GAUGE, Vector3(1, 0, 0)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	k.torus(0.026, 0.0042, 24, 6); k.at(Vector3(0, -0.006, 0)); k.cyl(0.024, 0.024, 0.01, 22); k.pop()
	k.pop(); k.pop()
	k.paint(P.dial, 0.0, 0.5); k.toward(DW_GAUGE + Vector3(-0.004, 0, 0), Vector3(1, 0, 0)); k.at(Vector3(0, 0, 0)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.cyl(0.022, 0.022, 0.002, 22); k.pop(); k.pop(); k.pop()
	for i in 11:
		var a := lerpf(-2.4, 2.4, i / 10.0); var red := i >= 8
		k.paint(P.needle if red else Color("2a2420"), 0.0, 0.6); k.toward(DW_GAUGE + Vector3(-0.0062, 0, 0), Vector3(1, 0, 0))
		var d := Vector2(sin(a), cos(a))
		var q0 := d * 0.0155; var q1 := d * (0.02 if i % 5 == 0 else 0.0182); var nn := Vector2(-d.y, d.x) * 0.0007
		var i0 := k._v(Vector3(q0.x + nn.x, q0.y + nn.y, 0.0), Vector3.BACK); var i1 := k._v(Vector3(q1.x + nn.x, q1.y + nn.y, 0.0), Vector3.BACK); var i2 := k._v(Vector3(q1.x - nn.x, q1.y - nn.y, 0.0), Vector3.BACK); var i3 := k._v(Vector3(q0.x - nn.x, q0.y - nn.y, 0.0), Vector3.BACK)
		k._tri(i0, i1, i2); k._tri(i0, i2, i3); k.pop()
	# copper pipes from the boiler to the breech, and the valve's stem
	k.paint(P.copper, 1.0, 0.28, ArtKit.WORN)
	k.tube(ArtKit.spline([Vector3(-0.078, 0.062, -0.1), Vector3(-0.07, 0.085, -0.09), Vector3(-0.04, 0.09, -0.06), Vector3(-0.02, 0.07, -0.04)], 5), 0.0042, 8)
	k.tube(ArtKit.spline([Vector3(-0.06, 0.0, 0.16), Vector3(-0.05, -0.02, 0.12), Vector3(-0.035, -0.02, 0.08)], 5), 0.0042, 8)
	for p: Vector3 in [Vector3(-0.078, 0.062, -0.1), Vector3(-0.02, 0.07, -0.04)]: k.paint(P.brass, 1.0, 0.3); k.at(p); k.ball(Vector3.ZERO, Vector3.ONE * 0.0062, 8, 5); k.pop()
	k.paint(P.brass, 1.0, 0.3, ArtKit.WORN); k.at(Vector3(-0.07, 0.058, -0.07)); k.cyl(0.004, 0.004, 0.026, 10); k.pop()
	# the mortar under the barrel: bronze ends, its glass between them (drawn on its own)
	k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN)
	for z: float in [-0.12, -0.24]:
		k.at(Vector3(0, -0.052, z), Vector3(-PI / 2.0, 0, 0)); k.lathe(PackedVector2Array([Vector2(0.0, -0.008), Vector2(0.024, -0.008), Vector2(0.026, -0.004), Vector2(0.026, 0.004), Vector2(0.024, 0.008), Vector2(0.0, 0.008)]), 20); k.pop()
	k.paint(P.iron2, 0.8, 0.5, ArtKit.IRON); k.at(Vector3(0, -0.052, -0.248), Vector3(-PI / 2.0, 0, 0)); k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.02, 0.0), Vector2(0.022, 0.04), Vector2(0.026, 0.07), Vector2(0.02, 0.07), Vector2(0.016, 0.04), Vector2(0.0, 0.035)]), 18); k.pop()
	for sx: float in [1.0, -1.0]: k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN); k.rbox(Vector3(0.006, 0.006, 0.13), Vector3(sx * 0.0215, -0.052, -0.18), 0.0015, 1)
	k.paint(P.bronze, 1.0, 0.36, ArtKit.WORN); k.rbox(Vector3(0.03, 0.04, 0.04), Vector3(0, -0.03, -0.1), 0.005, 1)   # (its bracket to the breech)
	# the trigger and its guard
	k.paint(P.iron2, 0.85, 0.45, ArtKit.IRON)
	side(k, [Vector2(-0.01, -0.016), Vector2(-0.004, -0.032), Vector2(0.0, -0.044), Vector2(0.005, -0.04), Vector2(0.0, -0.028), Vector2(-0.004, -0.016)], 0.007, 0.0015, 1)
	k.paint(P.bronze, 1.0, 0.36, ArtKit.WORN); k.tube(ArtKit.spline([Vector3(0, -0.016, -0.04), Vector3(0, -0.05, -0.03), Vector3(0, -0.058, 0.0), Vector3(0, -0.05, 0.03), Vector3(0, -0.03, 0.05)], 5), 0.003, 6)
	# the stock: dark oak, wrapped in worn leather at its wrist, a bronze butt plate
	k.paint(P.wood, 0.0, 0.55, ArtKit.WOOD)
	side(k, [Vector2(0.062, 0.05), Vector2(0.14, 0.04), Vector2(0.26, 0.026), Vector2(0.3, 0.024), Vector2(0.305, -0.06), Vector2(0.29, -0.11), Vector2(0.22, -0.09), Vector2(0.15, -0.07),
		Vector2(0.11, -0.12), Vector2(0.08, -0.13), Vector2(0.055, -0.05), Vector2(0.062, -0.01)], 0.05, 0.012, 3)
	k.paint(P.bronze, 1.0, 0.34, ArtKit.WORN); side(k, [Vector2(0.298, 0.03), Vector2(0.315, 0.028), Vector2(0.318, -0.06), Vector2(0.3, -0.118), Vector2(0.286, -0.114), Vector2(0.3, -0.06)], 0.054, 0.004, 2)
	k.paint(P.leather, 0.0, 0.75, ArtKit.LEATHER)
	for i in 5:
		var z := 0.13 + i * 0.022
		k.at(Vector3(0, -0.02 - i * 0.004, z)); k.rbox(Vector3(0.056, 0.085 - i * 0.006, 0.016), Vector3.ZERO, 0.007, 2); k.pop()
	k.paint(P.bronze, 1.0, 0.36, ArtKit.WORN); k.ball(Vector3(0, -0.13, 0.095), Vector3(0.026, 0.01, 0.03), 12, 5)   # (the grip's cap)

# ---------------- the orcs' blood-rune greatsword and chain axe (피의 룬 대검 & 사슬 도끼) ----------------
## a single-edged blade of black forged iron as wide as a man's chest, notched and scratched toward its point, a deep
## fuller down it carved with blood runes (they fill with crimson light as the bloodlust stacks: group 7's fill); a
## crossguard of beast fangs and iron spikes, a grip wound in rough leather, a pommel wrapped in heavy chain that runs to
## the axe in your left hand (held reversed, a red hook rune in its blade). The sword is built along -z from your
## right fist; the axe along +y from its head
const OR_LEN := 1.12
const OR_TIP := Vector3(0.0, 0, -1.2)
const OR_POMMEL := Vector3(0, 0, 0.16)
const OR_AXE_TOP := Vector3(0, 0.36, 0)

static func greatsword(skinned := false) -> Dictionary:
	var P := pal("orc", skinned); var key := "or" + ("_sk" if skinned else "")
	var m := mat(true, {1: [P.glow, 2.4], 7: [P.glow, 0.0]})
	var root := Node3D.new(); root.name = "Greatsword"
	var rig := {"root": root, "mat": m}
	var sword := Node3D.new(); sword.name = "sword"; root.add_child(sword); rig.sword = sword
	piece(sword, key + "_sword", func(k: ArtKit) -> void: _sword_body(k, P), m)
	piece(sword, "or_rhand" + ("_sk" if skinned else ""), func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(0, 0, 0.04)))
		hand(k, P, 0.021, 1.0, "orc", Vector3(0.3, -0.8, -0.3)); k.pop(), m)
	var tipn := Node3D.new(); tipn.position = OR_TIP; sword.add_child(tipn); rig.tip_node = tipn
	var axe := Node3D.new(); axe.name = "axe"; root.add_child(axe); rig.axe = axe
	var held := piece(axe, key + "_axe", func(k: ArtKit) -> void: axe_body(k, P), m); rig.axe_mesh = held
	var lh := piece(axe, "or_lhand" + ("_sk" if skinned else ""), func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), Vector3(0, 0.2, 0)))
		hand(k, P, 0.017, -1.0, "orc", Vector3(-0.3, -0.75, -0.6)); k.pop(), m)
	rig.lhand = lh
	# the chain from the pommel to the axe: its links placed each frame between the two
	var link := built("or_link", func(k: ArtKit) -> void: k.paint(P.chain, 0.9, 0.5, ArtKit.IRON); k.link(0.034, 0.02, 0.0042, 6))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = link; mm.instance_count = 18
	var ch := MultiMeshInstance3D.new(); ch.multimesh = mm; ch.material_override = m; ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(ch); rig.chain = ch
	return rig

## the axe alone (in your hand, or thrown): its head at the origin, its haft up along +y
static func axe_body(k: ArtKit, P: Dictionary) -> void:
	k.paint(P.haft, 0.0, 0.7, ArtKit.WOOD); k.tube(PackedVector3Array([Vector3(0, -0.03, 0), Vector3(0, 0.36, 0)]), PackedFloat32Array([0.0125, 0.0115]), 10)
	k.paint(P.wrap, 0.0, 0.8, ArtKit.LEATHER)
	for i in 7: var y := 0.12 + i * 0.016; k.at(Vector3(0, y, 0), Vector3(0.0, 0.0, 0.22)); k.torus(0.0135, 0.0032, 12, 4); k.pop()
	k.paint(P.steel, 0.85, 0.55, ArtKit.IRON); k.at(Vector3(0, 0.36, 0)); k.ball(Vector3.ZERO, Vector3(0.017, 0.012, 0.017), 10, 5); k.pop()
	# the head: a bearded blade forward (-z), a hook behind, wedged on the haft
	k.paint(P.steel, 0.85, 0.52, ArtKit.IRON)
	k.rbox(Vector3(0.03, 0.07, 0.04), Vector3(0, 0.02, 0.0), 0.006, 2)
	var blade := PackedVector2Array([Vector2(0.015, 0.05), Vector2(0.06, 0.06), Vector2(0.11, 0.085), Vector2(0.13, 0.05), Vector2(0.138, 0.0), Vector2(0.13, -0.05), Vector2(0.11, -0.09), Vector2(0.07, -0.08), Vector2(0.04, -0.03), Vector2(0.015, -0.012)])
	k.at(Vector3(0, 0.02, 0), Vector3(0, PI / 2.0, 0)); k.extrude(blade, 0.014, 0.004, 2); k.pop()
	k.paint(P.edge, 1.0, 0.32, ArtKit.IRON)   # (its honed edge)
	var e := PackedVector3Array()
	for q: Vector2 in [Vector2(0.11, 0.085), Vector2(0.13, 0.05), Vector2(0.138, 0.0), Vector2(0.13, -0.05), Vector2(0.11, -0.09)]: e.push_back(Vector3(0, 0.02 + q.y, -q.x))
	k.tube(ArtKit.spline(Array(e), 4), 0.0032, 6)
	k.paint(P.steel, 0.85, 0.5, ArtKit.IRON); k.tube(PackedVector3Array([Vector3(0, 0.03, 0.016), Vector3(0, 0.035, 0.06), Vector3(0, 0.005, 0.085)]), PackedFloat32Array([0.009, 0.006, 0.001]), 8)
	# the red hook rune in its middle, both faces
	for sx: float in [1.0, -1.0]:
		k.paint(P.rune, 0.2, 0.4, ArtKit.PLAIN, 1, 1.0); k.at(Vector3(sx * 0.0072, 0.02, -0.075), Vector3(0, PI / 2.0 * sx, 0))
		k.rune(31, 0.032, 0.005, 0.0); k.relief(ArtKit.scroll(Vector2(0.0, -0.01), PI * 0.5, 0.012, 0.007, 0.9, true, 10), 0.0018, 0.0); k.pop()

static func _sword_body(k: ArtKit, P: Dictionary) -> void:
	# the grip: wound in leather bandage, the hand round it from 0 to 0.1
	k.paint(P.wrap.darkened(0.3), 0.0, 0.8, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0, 0, -0.04), Vector3(0, 0, 0.15)]), 0.019, 10)
	k.paint(P.wrap, 0.0, 0.85, ArtKit.LEATHER)
	for i in 9: var z := -0.03 + i * 0.019; k.at(Vector3(0, 0, z), Vector3(PI / 2.0, 0.0, 0.0)); k.push(Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3.ZERO)); k.torus(0.0205, 0.0042, 12, 4); k.pop(); k.pop()
	# the pommel: an iron knob with the chain wound round it
	k.paint(P.steel, 0.85, 0.5, ArtKit.IRON); k.ball(Vector3(0, 0, 0.165), Vector3(0.027, 0.027, 0.03), 12, 6)
	k.paint(P.chain, 0.9, 0.5, ArtKit.IRON)
	for i in 6:
		var a := i * TAU / 6.0
		k.at(Vector3(cos(a) * 0.026, sin(a) * 0.026, 0.155 + (i % 2) * 0.012), Vector3(0, 0, a)); k.link(0.03, 0.017, 0.0038, 5); k.pop()
	# the crossguard: a bar of iron, beast fangs curving forward from its ends, spikes
	k.paint(P.steel, 0.85, 0.55, ArtKit.IRON); k.rbox(Vector3(0.3, 0.05, 0.045), Vector3(0.02, 0, -0.065), 0.01, 2)
	for sx: float in [1.0, -1.0]:
		var b := Vector3(sx * 0.15 + 0.02, 0, -0.065)
		k.paint(P.bone, 0.0, 0.62, ArtKit.BONE); k.tube(ArtKit.spline([b, b + Vector3(sx * 0.04, 0.0, -0.03), b + Vector3(sx * 0.05, 0.0, -0.09), b + Vector3(sx * 0.03, 0.0, -0.15)], 5), PackedFloat32Array([0.017, 0.015, 0.012, 0.009, 0.006, 0.004, 0.002, 0.0008]), 9)
		k.paint(P.steel, 0.9, 0.45, ArtKit.IRON)
		for j in 2: var o := b + Vector3(-sx * 0.05 * j, 0, 0); k.tube(PackedVector3Array([o + Vector3(0, 0.02, 0), o + Vector3(0, 0.055, 0.01)]), PackedFloat32Array([0.008, 0.0008]), 6); k.tube(PackedVector3Array([o + Vector3(0, -0.02, 0), o + Vector3(0, -0.055, 0.01)]), PackedFloat32Array([0.008, 0.0008]), 6)
	# the blade: straight spine on the left, the edge on the right widening to a broad clipped point; notches near it
	var st: Array = []
	for i in 46:
		var t := float(i) / 45.0; st.push_back(t)
	var rings: Array = []
	var L := OR_LEN; var nicks := [0.62, 0.71, 0.79, 0.86, 0.93]
	for t: float in st:
		var z := -0.09 - t * L
		var wb := -0.07 + 0.02 * smoothstep(0.86, 1.0, t)       # the spine, turning in at the point
		var we := lerpf(0.085, 0.16, smoothstep(0.0, 0.8, t))   # the edge, widening to a cleaver's
		if t > 0.84: we = lerpf(we, wb + 0.02, pow(smoothstep(0.84, 1.0, t), 0.8))   # (the broad clipped point)
		for nk: float in nicks: we -= 0.006 * maxf(0.0, 1.0 - absf(t - nk) * 90.0)
		var th := lerpf(0.0105, 0.0065, t)
		var ff := 0.014; var fx := -0.026                       # the fuller's middle and half-width
		var sec := [Vector2(wb, th), Vector2(fx - ff, th * 0.96), Vector2(fx - ff * 0.5, th * 0.42), Vector2(fx + ff * 0.5, th * 0.42), Vector2(fx + ff, th * 0.92),
			Vector2(lerpf(fx + ff, we, 0.62), th * 0.68), Vector2(we, 0.0),
			Vector2(lerpf(fx + ff, we, 0.62), -th * 0.68), Vector2(fx + ff, -th * 0.92), Vector2(fx + ff * 0.5, -th * 0.42), Vector2(fx - ff * 0.5, -th * 0.42), Vector2(fx - ff, -th * 0.96), Vector2(wb, -th)]
		if t > 0.97: for q in sec.size(): sec[q] = Vector2(lerpf((sec[q] as Vector2).x, wb + 0.02, (t - 0.97) / 0.03), (sec[q] as Vector2).y * (1.0 - (t - 0.97) / 0.03 * 0.9))
		var ring := PackedVector3Array()
		for q: Vector2 in sec: ring.push_back(Vector3(q.x, q.y, z))
		rings.push_back(ring)
	k.paint(P.steel, 0.82, 0.6, ArtKit.IRON); k.grid(rings, true, false); k.cap(rings[0], Vector3(0, 0, -0.5))
	# its honed edge, paler, and the scratches near the point
	k.paint(P.edge, 0.95, 0.38, ArtKit.IRON)
	var edge := PackedVector3Array()
	for i in rings.size() - 1: var r: PackedVector3Array = rings[i]; edge.push_back(r[6])
	k.tube(edge, 0.0016, 5, false)
	k.paint(P.steel.lightened(0.25), 0.9, 0.42)
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for i in 9:
		var t := rng.randf_range(0.55, 0.95); var z := -0.09 - t * L; var x := rng.randf_range(0.0, 0.06); var a := rng.randf_range(-0.6, 0.6)
		for sy: float in [1.0, -1.0]:
			var p0 := Vector3(x, sy * 0.0075, z); var d := Vector3(sin(a), 0, cos(a)) * rng.randf_range(0.02, 0.05)
			k.strip_line(p0, p0 + d, 0.0011, Vector3(0, sy, 0))
	# the blood runes down the fuller, and its channel: they light as far as the bloodlust has filled it (group 7)
	for sy: float in [1.0, -1.0]:
		var ch: Array = []; var av := PackedFloat32Array()
		for i in 30:
			var t := float(i) / 29.0 * 0.82; var z := -0.11 - t * L; var th := lerpf(0.0105, 0.0065, t) * 0.42 + 0.0003
			ch.push_back(PackedVector3Array([Vector3(-0.033, sy * th, z), Vector3(-0.019, sy * th, z)])); av.push_back(t / 0.82)
		var nn: Array = []
		for i in 30: nn.push_back(PackedVector3Array([Vector3(0, sy, 0), Vector3(0, sy, 0)]))
		k.paint(P.rune.darkened(0.5), 0.3, 0.45, ArtKit.PLAIN, 7, 0.0); k.grid(ch, false, true, nn, av)
		for i in 9:
			var t := 0.06 + i * 0.085; var z := -0.11 - t * L; var th := lerpf(0.0105, 0.0065, t) * 0.42 + 0.0006
			k.paint(P.rune, 0.2, 0.5, ArtKit.PLAIN, 7, t / 0.82); k.toward(Vector3(-0.026, sy * th, z), Vector3(0, -sy, 0), Vector3(0, 0, -1)); k.rune(i + 50, 0.012, 0.0021, 0.0); k.pop()

# ---------------- the demons' hellfire staff (지옥불 마법 스태프) ----------------
## a shaft of cracked black obsidian glass with lava light in its cracks, its head split into three curved horns of
## obsidian round an ember core like a black eclipse turning in the gap; a red-hot chain wound three times round its
## neck. The core grows and turns faster with the heat, the horns open wider; past 80% it bursts white-hot and spits
## black ash; at 100% the horns close on it, the chain bites and a red rune lock hangs about the staff. Built along -z
## from your fist
const DM_HEAD := Vector3(0, 0, -0.74)
const DM_TIP := Vector3(0, 0, -0.8)

static func staff(skinned := false) -> Dictionary:
	var P := pal("demon", skinned); var key := "dm" + ("_sk" if skinned else "")
	var m := mat(true, {1: [P.lava, 1.6], 2: [P.hot, 2.0], 3: [P.lava, 3.0]})
	var root := Node3D.new(); root.name = "Staff"
	var rig := {"root": root, "mat": m, "tip": DM_TIP}
	piece(root, key + "_shaft", func(k: ArtKit) -> void: _staff_body(k, P), m)
	piece(root, "dm_rhand", func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(0, 0, 0.0)))
		hand(k, P, 0.019, 1.0, "demon", Vector3(0.3, -0.8, -0.3)); k.pop(), m)
	# the three horns of its crown, each on its own pivot (they open with the heat and close on the seal)
	var horns: Array = []
	for i in 3:
		var hp := Node3D.new(); hp.position = Vector3(0, 0, -0.665); hp.rotation = Vector3(0, 0, i * TAU / 3.0); root.add_child(hp)
		var hn := Node3D.new(); hp.add_child(hn); horns.push_back(hn)
		piece(hn, key + "_horn", func(k: ArtKit) -> void:
			var pts := [Vector3(0.0, 0.014, 0.0), Vector3(0.0, 0.03, -0.03), Vector3(0.0, 0.052, -0.07), Vector3(0.0, 0.056, -0.11), Vector3(0.0, 0.04, -0.15), Vector3(0.0, 0.016, -0.17)]
			var path := ArtKit.spline(pts, 5); var sc := []
			for q in path.size(): var t := float(q) / (path.size() - 1); sc.push_back(Vector2(lerpf(0.011, 0.0012, pow(t, 0.8)), lerpf(0.016, 0.0016, pow(t, 0.8))))
			k.paint(P.obsid, 0.35, 0.08, ArtKit.OBSIDIAN, 1, 0.1); k.sweep(path, ArtKit.circle(7), sc, Vector3(0, 1, 0), false)
			for q in 3:   # (ridges along its outer curve)
				var e := path[3 + q * 4]; k.paint(P.obsid2, 0.35, 0.1, ArtKit.OBSIDIAN, 1, 0.2); k.tube(PackedVector3Array([e, e + Vector3(0, 0.012, 0.004)]), PackedFloat32Array([0.004, 0.0005]), 5), m)
	rig.horns = horns
	# the ember core: a black eclipse in a ring of fire, turning
	var core := Node3D.new(); core.position = DM_HEAD; root.add_child(core); rig.core = core
	piece(core, key + "_core", func(k: ArtKit) -> void:
		k.paint(P.core, 0.4, 0.08, ArtKit.PLAIN); k.ball(Vector3.ZERO, Vector3.ONE * 0.026, 16, 10)
		k.paint(P.lava, 0.0, 0.5, ArtKit.PLAIN, 3, 1.0); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.03, 0.0035, 28, 6)
		for i in 10: var a := i * TAU / 10.0; k.tube(PackedVector3Array([Vector3(cos(a), 0, sin(a)) * 0.031, Vector3(cos(a + 0.25), 0, sin(a + 0.25)) * 0.046]), PackedFloat32Array([0.003, 0.0004]), 5, false)
		k.pop(), m)
	rig.corona = sprite(Color(1.0, 0.45, 0.1, 0.7), 0.2, core)
	# the chain wound three times round its neck: drawn tighter as it heats
	var chain := Node3D.new(); chain.position = Vector3(0, 0, -0.6); root.add_child(chain); rig.chain = chain
	piece(chain, key + "_chain", func(k: ArtKit) -> void:
		for i in 21:
			var a := i * TAU * 3.0 / 21.0; var z := -i * 0.0028; var p := Vector3(cos(a) * 0.036, sin(a) * 0.036, z)
			var tg := Vector3(-sin(a), cos(a), -0.06).normalized()
			k.paint(P.chain, 0.85, 0.5, ArtKit.IRON, 2, 0.6); k.toward(p, tg, Vector3(cos(a), sin(a), 0)); k.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)), Vector3.ZERO)); k.link(0.017, 0.011, 0.0026, 5); k.pop(); k.pop(), m)
	# the rune lock: a ring of red runes and a lock that hang about the staff while it is sealed
	var lock := Node3D.new(); lock.position = Vector3(0, 0, -0.62); lock.visible = false; root.add_child(lock); rig.lock = lock
	var lm := mat(true, {1: [Color("ff2a2a"), 3.0]}, true)
	piece(lock, "dm_lock", func(k: ArtKit) -> void:
		for i in 12:
			var a := i * TAU / 12.0; k.paint(Color("ff3030"), 0.0, 0.5, ArtKit.PLAIN, 1, 1.0)
			k.toward(Vector3(cos(a) * 0.075, sin(a) * 0.075, 0), Vector3(-cos(a), -sin(a), 0), Vector3(0, 0, -1)); k.rune(70 + i, 0.02, 0.0028, 0.0); k.pop()
		k.paint(Color("ff3030"), 0.0, 0.5, ArtKit.PLAIN, 1, 0.7)
		k.at(Vector3.ZERO, Vector3(PI / 2.0, 0, 0)); k.torus(0.088, 0.0018, 40, 4); k.torus(0.062, 0.0012, 40, 4); k.pop()
		k.at(Vector3(0, 0.1, 0)); k.rbox(Vector3(0.03, 0.024, 0.004), Vector3.ZERO, 0.003, 1); k.at(Vector3(0, 0.016, 0), Vector3(PI / 2.0, 0, 0)); k.torus(0.009, 0.0025, 14, 4, 0.0, PI); k.pop(); k.pop(), lm)
	# your left hand, open: it comes up to pour the beam out
	var lh := Node3D.new(); lh.name = "lhand"; lh.visible = false; root.add_child(lh); rig.lhand = lh
	piece(lh, "dm_lhand", func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3.ZERO))
		hand(k, P, 0.02, -1.0, "demon", Vector3(0.4, -1.0, 0.3), 1.0); k.pop(), m)
	# the eclipse skin's shards, turning round the core above 80% heat
	if skinned:
		var orb := Node3D.new(); orb.position = DM_HEAD; root.add_child(orb); rig.orbit = orb
		for i in 4:
			var sh := piece(orb, "dm_shard", func(k: ArtKit) -> void: k.paint(P.obsid2, 0.4, 0.06, ArtKit.OBSIDIAN, 3, 0.5); k.gem(0.008, 0.018, 0.012, 5), m)
			sh.position = Vector3(cos(i * TAU / 4.0) * 0.075, sin(i * TAU / 4.0) * 0.075, 0.0)
	return rig

static func _staff_body(k: ArtKit, P: Dictionary) -> void:
	# the shaft: obsidian glass broken into facets, lava in its cracks (group 1: the heat), thicker at its neck
	var path := PackedVector3Array(); var sc := []
	var rng := RandomNumberGenerator.new(); rng.seed = 66
	for i in 40:
		var t := float(i) / 39.0; var z := lerpf(0.3, -0.6, t)
		path.push_back(Vector3(sin(t * 7.0) * 0.002, cos(t * 5.0) * 0.002, z))
		var r := 0.016 + 0.003 * sin(t * 23.0) + (0.006 if t > 0.93 else 0.0) + (0.004 if t < 0.03 else 0.0)
		sc.push_back(Vector2(r * rng.randf_range(0.9, 1.1), r * rng.randf_range(0.9, 1.1)))
	k.paint(P.obsid, 0.3, 0.07, ArtKit.OBSIDIAN, 1, 0.0); k.sweep(path, ArtKit.circle(6), sc, Vector3.UP, false, true, true, 2.2)
	# glassy shards set in it, and lava seams down it
	for i in 8:
		var t := 0.12 + i * 0.1; var z := lerpf(0.3, -0.6, t); var a := i * 2.4
		k.paint(P.obsid2, 0.35, 0.06, ArtKit.OBSIDIAN, 1, 0.0); k.at(Vector3(cos(a) * 0.016, sin(a) * 0.016, z), Vector3(0, 0, a)); k.gem(0.006, 0.014, 0.004, 3); k.pop()
	k.paint(P.lava, 0.0, 0.5, ArtKit.PLAIN, 1, 1.0)
	for j in 3:
		var a := j * TAU / 3.0 + 0.4; var seam := PackedVector3Array()
		for i in 14: var t := 0.06 + i * 0.065; seam.push_back(Vector3(cos(a + sin(i * 1.7) * 0.25) * 0.0175, sin(a + sin(i * 1.7) * 0.25) * 0.0175, lerpf(0.3, -0.6, t)))
		k.tube(seam, 0.0012, 4, false)
	# the butt: an obsidian point; the neck's collar below the horns
	k.paint(P.obsid, 0.3, 0.07, ArtKit.OBSIDIAN, 1, 0.0); k.at(Vector3(0, 0, 0.3), Vector3(PI / 2.0, 0, 0)); k.cyl(0.02, 0.003, 0.06, 6, true, false); k.pop()
	k.paint(P.obsid2, 0.35, 0.08, ArtKit.OBSIDIAN, 1, 0.0); k.at(Vector3(0, 0, -0.6), Vector3(-PI / 2.0, 0, 0)); k.lathe(PackedVector2Array([Vector2(0.0, -0.01), Vector2(0.022, -0.01), Vector2(0.03, 0.04), Vector2(0.034, 0.068), Vector2(0.018, 0.075), Vector2(0.0, 0.075)]), 9, 0.0, TAU, false); k.pop()

# ---------------- what everyone carries: the rune dagger and the three alchemy bombs ----------------
## the rune dagger, reversed in your left hand: short and double-edged, its blade bright as a mirror with silver runes
## down both faces. Its parry: the wrist turned to set the flat of the blade before you, a hexagon of runes flashing out
## (the shield is its own node: rig.shield). look: your people's hand
const HAND_LOOK := {"elf": "glove", "dwarf": "gaunt", "orc": "orc", "demon": "demon"}
static func dagger(race: String) -> Dictionary:
	var P := pal(race); var m := mat(true, {1: [Color("9fe8ff"), 1.6], 2: [Color("bfefff"), 2.5]})
	var root := Node3D.new(); root.name = "Dagger"
	piece(root, "dg_blade", func(k: ArtKit) -> void:
		# the blade: down from the fist (reversed), along -y; a diamond section, a ridge down its middle
		var rings: Array = []
		for i in 16:
			var t := float(i) / 15.0; var y := -0.035 - t * 0.2; var w := 0.017 * (1.0 - pow(t, 2.2)) + 0.001; var th := 0.0042 * (1.0 - t * 0.7)
			rings.push_back(PackedVector3Array([Vector3(-w, y, 0), Vector3(0, y, th), Vector3(w, y, 0), Vector3(0, y, -th)]))
		k.paint(Color("e6ebf0"), 1.0, 0.07); k.grid(rings, true, false); k.cap(rings[0], Vector3(0, 0, 0))
		for sz: float in [1.0, -1.0]:   # (the silver runes, both faces)
			for i in 5:
				var t := 0.12 + i * 0.15; var y := -0.035 - t * 0.2
				k.paint(Color("dff6ff"), 1.0, 0.1, ArtKit.PLAIN, 1, 0.6); k.toward(Vector3(sz * 0.0035, y, sz * 0.0026), Vector3(-sz * 0.6, 0, -sz), Vector3(0, 1, 0)); k.rune(90 + i, 0.0075, 0.0011, 0.0); k.pop()
		# the guard, the grip, the pommel
		k.paint(Color("b8c0c8"), 1.0, 0.2, ArtKit.WORN); k.rbox(Vector3(0.06, 0.012, 0.016), Vector3(0, -0.03, 0), 0.004, 2)
		k.paint(Color("3a2c22"), 0.0, 0.8, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0, -0.026, 0), Vector3(0, 0.07, 0)]), 0.0115, 9)
		k.paint(Color("b8c0c8"), 1.0, 0.2, ArtKit.WORN); k.ball(Vector3(0, 0.077, 0), Vector3(0.014, 0.011, 0.014), 10, 5)
		k.paint(Color("6fe0ff"), 0.0, 0.1, ArtKit.CRYSTAL, 2, 0.9); k.at(Vector3(0, 0.077, 0.0), Vector3(PI / 2.0, 0, 0)); k.gem(0.005, 0.007, 0.007, 6); k.pop(), m)
	piece(root, "dg_hand_" + race, func(k: ArtKit) -> void:
		k.push(Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), Vector3(0, 0.022, 0)))
		hand(k, P, 0.0125, -1.0, HAND_LOOK[race], Vector3(-0.35, -0.6, -1.0)); k.pop(), m)
	# the hexagon of runes the parry throws up
	var sh := Node3D.new(); sh.position = Vector3(0, -0.1, -0.04); sh.visible = false; root.add_child(sh)
	var hm := MeshInstance3D.new(); hm.mesh = built("dg_hex", func(k: ArtKit) -> void:
		var hexo := ArtKit.circle(6, 0.16, PI / 6.0)
		k.paint(Color("aef3ff"), 0.0, 0.5, ArtKit.PLAIN, 0, 0.55); k.extrude(hexo, 0.002, 0.0, 0)
		k.paint(Color("e8fdff"), 0.0, 0.5, ArtKit.PLAIN, 0, 1.0)
		for i in 6: var a := i * TAU / 6.0 + PI / 6.0; k.at(Vector3(cos(a) * 0.11, sin(a) * 0.11, 0.002)); k.rune(110 + i, 0.03, 0.004, 0.0); k.pop())
	var hmat := StandardMaterial3D.new(); hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; hmat.vertex_color_use_as_albedo = true; hmat.albedo_color = Color(0.6, 0.95, 1.0, 0.35)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; hmat.cull_mode = BaseMaterial3D.CULL_DISABLED; hmat.disable_fog = true
	hm.material_override = Gfx.see_through(hmat); hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; sh.add_child(hm)
	var edge := MeshInstance3D.new(); edge.mesh = built("dg_hex_edge", func(k: ArtKit) -> void:
		k.paint(Color("e8fdff"), 0.0, 0.5, ArtKit.PLAIN, 0, 1.0); var ring := ArtKit.circle(6, 0.16, PI / 6.0); ring.push_back(ring[0]); k.relief(ring, 0.004, 0.0)
		var ring2 := ArtKit.circle(6, 0.07, PI / 6.0); ring2.push_back(ring2[0]); k.relief(ring2, 0.0025, 0.0))
	edge.material_override = hm.material_override; edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; sh.add_child(edge)
	return {"root": root, "mat": m, "shield": sh, "shield_mat": hm.material_override}

## an alchemy bomb, to hold or to throw: "oil" (a round amber flask, black oil sloshing in it, a lit wick in its neck),
## "gravity" (three bronze gyroscope rings round a small violet black hole), "smoke" (a hexagonal crystal capsule of
## crystal powder, its pin). Its moving parts: the oil (it sloshes), the rings (they turn), the wick's flame
static func bomb(kind: String) -> Dictionary:
	var m := mat(true, {1: [Color("ffb040"), 3.0], 2: [Color("a855f7"), 3.0], 3: [Color("c9a0ff"), 1.6]})
	var root := Node3D.new(); root.name = "Bomb_" + kind; var rig := {"root": root, "mat": m, "spin": []}
	match kind:
		"oil":
			var oil := piece(root, "bm_oil", func(k: ArtKit) -> void:
				k.paint(Color("120c08"), 0.2, 0.15); k.ball(Vector3(0, -0.004, 0), Vector3(0.036, 0.028, 0.036), 14, 8), m)
			rig.oil = oil
			var gl := MeshInstance3D.new(); gl.mesh = built("bm_flask", func(k: ArtKit) -> void:
				var prof := PackedVector2Array()
				for j in 13:
					var e := -PI * 0.5 + PI * float(j) / 12.0; prof.push_back(Vector2(cos(e) * 0.044 + 0.0001, sin(e) * 0.036))
				prof.push_back(Vector2(0.012, 0.042)); prof.push_back(Vector2(0.011, 0.06))
				for lobe in 8:   # (the pumpkin's ribs: eight lobes, each a slice of the round)
					k.lathe(prof, 3, lobe * TAU / 8.0, (lobe + 1) * TAU / 8.0))
			gl.material_override = glass(Color(0.95, 0.55, 0.12, 0.32)); gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(gl)
			piece(root, "bm_cork", func(k: ArtKit) -> void:
				k.paint(Color("8a6a44"), 0.0, 0.85, ArtKit.WOOD); k.at(Vector3(0, 0.056, 0)); k.cyl(0.0105, 0.012, 0.014, 10); k.pop()
				k.paint(Color("d8cfb8"), 0.0, 0.9, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(0, 0.068, 0), Vector3(0.003, 0.08, 0.002), Vector3(-0.002, 0.09, 0.004)], 4), 0.0028, 6)
				k.paint(Color("ffb040"), 0.0, 0.5, ArtKit.PLAIN, 1, 1.0); k.ball(Vector3(-0.002, 0.093, 0.004), Vector3(0.0035, 0.005, 0.0035), 8, 5), m)
			var fl := sprite(Color(1.0, 0.6, 0.2, 0.85), 0.05, root); fl.position = Vector3(-0.002, 0.098, 0.004); rig.flame = fl
		"gravity":
			piece(root, "bm_hole", func(k: ArtKit) -> void:
				k.paint(Color("050308"), 0.4, 0.06); k.ball(Vector3.ZERO, Vector3.ONE * 0.018, 14, 8)
				k.paint(Color("a855f7"), 0.0, 0.3, ArtKit.PLAIN, 2, 1.0); k.push(Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3.ZERO)); k.torus(0.024, 0.0022, 24, 5); k.pop(), m)
			var hal := sprite(Color(0.65, 0.3, 1.0, 0.6), 0.09, root); rig.halo = hal
			for i in 3:
				var ring := Node3D.new(); ring.rotation = [Vector3(0, 0, 0), Vector3(PI / 2.0, 0, 0), Vector3(0, 0, PI / 2.0)][i]; root.add_child(ring)
				piece(ring, "bm_ring%d" % i, func(k: ArtKit) -> void:
					var R := 0.034 + i * 0.007
					k.paint(Color("b67c3c"), 1.0, 0.3, ArtKit.WORN); k.lathe(PackedVector2Array([Vector2(R - 0.003, -0.004), Vector2(R + 0.003, -0.004), Vector2(R + 0.003, 0.004), Vector2(R - 0.003, 0.004), Vector2(R - 0.003, -0.004)]), 30, 0.0, TAU, false)
					for j in 2: var a := j * PI; k.paint(Color("d9aa4a"), 1.0, 0.25); k.at(Vector3(cos(a) * R, 0, sin(a) * R), Vector3(0, 0, PI / 2.0)); k.cyl(0.0035, 0.0035, 0.006, 8); k.pop()
					for j in 6: var a := j * TAU / 6.0 + 0.5; k.paint(Color("a855f7"), 0.0, 0.4, ArtKit.PLAIN, 3, 1.0); k.at(Vector3(cos(a) * (R + 0.0032), 0, sin(a) * (R + 0.0032)), Vector3(0, -a, 0)); k.push(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)); k.rune(130 + j + i * 6, 0.005, 0.0009, 0.0); k.pop(); k.pop(), m)
				(rig.spin as Array).push_back(ring)
		"smoke":
			piece(root, "bm_powder", func(k: ArtKit) -> void:
				k.paint(Color("c9a0ff"), 0.0, 0.4, ArtKit.CRYSTAL, 3, 0.7); k.at(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 1)); k.gem(0.014, 0.03, 0.03, 6, PI / 6.0); k.pop(), m)
			var cap := MeshInstance3D.new(); cap.mesh = built("bm_capsule", func(k: ArtKit) -> void:
				k.lathe(PackedVector2Array([Vector2(0.0, -0.052), Vector2(0.021, -0.03), Vector2(0.021, 0.03), Vector2(0.0, 0.052)]), 6, PI / 6.0, PI / 6.0 + TAU, false))
			cap.material_override = glass(Color(0.62, 0.42, 0.95, 0.35)); cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(cap)
			piece(root, "bm_pin", func(k: ArtKit) -> void:
				k.paint(Color("d8a33e"), 1.0, 0.2, ArtKit.WORN)
				for y: float in [-0.03, 0.03]: k.at(Vector3(0, y, 0)); k.lathe(PackedVector2Array([Vector2(0.0, -0.003), Vector2(0.0225, -0.003), Vector2(0.0225, 0.003), Vector2(0.0, 0.003)]), 6, PI / 6.0, PI / 6.0 + TAU, false); k.pop()
				k.at(Vector3(0, 0.058, 0)); k.cyl(0.004, 0.004, 0.008, 8); k.at(Vector3(0, 0.016, 0), Vector3(PI / 2.0, 0, 0)); k.torus(0.009, 0.0016, 16, 4); k.pop(); k.pop(), m)
	return rig

# ---------------- the bodies (제1부: 종족 원화 설정 청사진) ----------------
## each people's body at its own true size, in the parts a body is moved by: two legs from the hip, the upper body from
## the hip (its head in it), two arms from the shoulders (the weapon in the right), and the demon's wings and tail.
## Their silhouettes are the paper's three views: the elf slim, narrow-shouldered, a quiver on its back, white marble
## and gold light armour in flowing lines; the demon with great curved horns, wide bat wings and its spine running on
## into a tail; the orc a mass of muscle, spiked pauldrons, hunched forward to charge; the dwarf short and stout, round
## heavy armour, a steam pack of bronze and leather on its back. Each side's colour on a cloak, sash or loincloth.
## Returns {leg, up, al, ar: meshes, hip, leg_x, sho: (x, y above the hip), [wing, tail: meshes, wing_at, tail_at]}
const BODY_TEAM := {"us": "3f74d0", "them": "c8343e"}
static func body(race: String, team: String, skinned := false) -> Dictionary:
	var key := "body_%s_%s%s" % [race, team, "_sk" if skinned else ""]
	if _meshes.has(key): return _meshes[key]
	var tc := Color(str(BODY_TEAM[team])); var P := pal(race, skinned); var d := 0.62
	var out := {}
	match race:
		"elf":
			out = {"hip": 0.88, "leg_x": 0.085, "sho": Vector2(0.195, 0.5)}
			out.leg = built(key + "_leg", func(k: ArtKit) -> void: _elf_leg(k), d)
			out.up = built(key + "_up", func(k: ArtKit) -> void: _elf_up(k, tc), d)
			out.al = built(key + "_al", func(k: ArtKit) -> void: _elf_arm(k, false, P), d)
			out.ar = built(key + "_ar", func(k: ArtKit) -> void: _elf_arm(k, true, P), d)
		"dwarf":
			out = {"hip": 0.5, "leg_x": 0.11, "sho": Vector2(0.3, 0.42)}
			out.leg = built(key + "_leg", func(k: ArtKit) -> void: _dwarf_leg(k), d)
			out.up = built(key + "_up", func(k: ArtKit) -> void: _dwarf_up(k, tc), d)
			out.al = built(key + "_al", func(k: ArtKit) -> void: _dwarf_arm(k, false, P), d)
			out.ar = built(key + "_ar", func(k: ArtKit) -> void: _dwarf_arm(k, true, P), d)
		"orc":
			out = {"hip": 0.92, "leg_x": 0.15, "sho": Vector2(0.4, 0.62)}
			out.leg = built(key + "_leg", func(k: ArtKit) -> void: _orc_leg(k), d)
			out.up = built(key + "_up", func(k: ArtKit) -> void: _orc_up(k, tc), d)
			out.al = built(key + "_al", func(k: ArtKit) -> void: _orc_arm(k, false, P), d)
			out.ar = built(key + "_ar", func(k: ArtKit) -> void: _orc_arm(k, true, P), d)
		"demon":
			out = {"hip": 0.95, "leg_x": 0.1, "sho": Vector2(0.24, 0.55), "wing_at": Vector3(0.07, 0.46, -0.13), "tail_at": Vector3(0, 0.02, -0.12)}
			out.leg = built(key + "_leg", func(k: ArtKit) -> void: _demon_leg(k), d)
			out.up = built(key + "_up", func(k: ArtKit) -> void: _demon_up(k, tc), d)
			out.al = built(key + "_al", func(k: ArtKit) -> void: _demon_arm(k, false, P), d)
			out.ar = built(key + "_ar", func(k: ArtKit) -> void: _demon_arm(k, true, P), d)
			out.wing = built("body_demon_wing", func(k: ArtKit) -> void: _demon_wing(k), d)
			out.wing_l = built("body_demon_wing_l", func(k: ArtKit) -> void: k.push(Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)); _demon_wing(k); k.pop(), d)   # (the left: the same, mirrored in its corners, not by a node's negative scale)
			out.tail = built("body_demon_tail", func(k: ArtKit) -> void: _demon_tail(k), d)
	_meshes[key] = out
	return out

static var _body_m: ShaderMaterial = null; static var _body_m2: ShaderMaterial = null
## the bodies' material (all of them share it; their glows: 1 teal (the elves'), 2 violet, 3 lava, 4 crimson, 5 amber, 6 eyes)
static func body_mat(two := false) -> ShaderMaterial:
	if two and _body_m2 != null: return _body_m2
	if not two and _body_m != null: return _body_m
	var m := mat(false, {1: [Color("38bdf8"), 2.0], 2: [Color("a855f7"), 2.2], 3: [Color("f97316"), 2.6], 4: [Color("ef4444"), 2.2], 5: [Color("f59e0b"), 1.6], 6: [Color("ffd23a"), 3.0]}, two)
	if two: _body_m2 = m
	else: _body_m = m
	return m

## a limb's piece: a tube from a to b, radius ra to rb
static func _limb(k: ArtKit, a: Vector3, b: Vector3, ra: float, rb: float, n := 10) -> void:
	k.tube(PackedVector3Array([a, a.lerp(b, 0.5), b]), PackedFloat32Array([ra, (ra + rb) * 0.52, rb]), n)

## a weapon carried in a right arm: built forward along -z, up +y, it is laid along the arm (forward: down the arm)
static func _in_hand(k: ArtKit, at: Vector3) -> void:
	k.push(Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), at))

# --- the elf ---
static func _elf_leg(k: ArtKit) -> void:
	k.paint("2e3440", 0.0, 0.7, ArtKit.CLOTH); _limb(k, Vector3(0, 0, 0), Vector3(0, -0.43, 0.015), 0.066, 0.05)
	_limb(k, Vector3(0, -0.43, 0.015), Vector3(0, -0.8, -0.01), 0.048, 0.036)
	k.paint("e6e3da", 0.1, 0.3, ArtKit.MARBLE); k.ball(Vector3(0, -0.61, 0.028), Vector3(0.046, 0.17, 0.034), 10, 6)   # (the greave)
	k.paint("d8a33e", 1.0, 0.25, ArtKit.WORN); k.ball(Vector3(0, -0.43, 0.04), Vector3(0.04, 0.042, 0.034), 10, 6)   # (the knee)
	k.paint("e6e3da", 0.1, 0.3, ArtKit.MARBLE); k.ball(Vector3(0, -0.2, 0.03), Vector3(0.058, 0.15, 0.04), 10, 6)
	k.paint("3a3028", 0.0, 0.6, ArtKit.LEATHER)   # (the boot, pointed)
	k.tube(PackedVector3Array([Vector3(0, -0.8, -0.03), Vector3(0, -0.86, 0.02), Vector3(0, -0.875, 0.12), Vector3(0, -0.87, 0.16)]), PackedFloat32Array([0.04, 0.042, 0.03, 0.006]), 9)
	k.paint("d8a33e", 1.0, 0.25, ArtKit.WORN); k.at(Vector3(0, -0.79, -0.005)); k.torus(0.04, 0.005, 14, 4); k.pop()

static func _elf_up(k: ArtKit, tc: Color) -> void:
	var white := Color("e9e6dd"); var gold := Color("d8a33e")
	k.paint("2e3440", 0.0, 0.7, ArtKit.CLOTH); k.ball(Vector3(0, 0.04, 0), Vector3(0.14, 0.1, 0.1), 12, 6)
	_limb(k, Vector3(0, 0.08, 0), Vector3(0, 0.26, 0.0), 0.11, 0.115, 12)
	# the breastplate: white with a gold trim, a slim waist, sculpted
	k.paint(white, 0.15, 0.28, ArtKit.MARBLE); k.ball(Vector3(0, 0.36, 0.012), Vector3(0.16, 0.17, 0.115), 14, 8)
	k.paint(gold, 1.0, 0.22, ArtKit.WORN); k.at(Vector3(0, 0.24, 0.0)); k.torus(0.118, 0.008, 18, 5); k.pop()
	k.tube(ArtKit.spline([Vector3(-0.1, 0.46, 0.08), Vector3(0, 0.36, 0.125), Vector3(0.1, 0.46, 0.08)], 5), 0.006, 6)
	k.tube(PackedVector3Array([Vector3(0, 0.46, 0.1), Vector3(0, 0.26, 0.118)]), 0.005, 6)
	# its side's colour: a sash across the chest and a cloak behind
	k.paint(tc, 0.0, 0.75, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(0.15, 0.48, 0.03), Vector3(0.0, 0.33, 0.13), Vector3(-0.13, 0.16, 0.08)], 5), 0.017, 6)
	var rows: Array = []
	for j in 7:
		var t := float(j) / 6.0; var y := lerpf(0.5, -0.42, t); var w := lerpf(0.15, 0.24, t); var z := lerpf(-0.12, -0.2, t)
		var row := PackedVector3Array()
		for i in 7: var u := lerpf(-1.0, 1.0, float(i) / 6.0); row.push_back(Vector3(u * w, y, z + (1.0 - u * u) * 0.04 * (0.5 + t)))
		rows.push_back(row)
	k.sheet(rows, Vector3(0, 0, -1))
	# the armoured skirt: plates before and behind, white edged in gold
	for z: float in [0.1, -0.1]:
		k.paint(white, 0.15, 0.3, ArtKit.MARBLE); k.at(Vector3(0, -0.1, z), Vector3(0.12 * signf(z), 0, 0)); k.rbox(Vector3(0.19, 0.3, 0.014), Vector3.ZERO, 0.006, 1); k.pop()
		k.paint(gold, 1.0, 0.25, ArtKit.WORN); k.at(Vector3(0, -0.24, z + 0.01 * signf(z)), Vector3(0.12 * signf(z), 0, 0)); k.rbox(Vector3(0.2, 0.018, 0.018), Vector3.ZERO, 0.004, 1); k.pop()
	k.paint(gold, 1.0, 0.25, ArtKit.WORN); k.at(Vector3(0, 0.06, 0)); k.torus(0.135, 0.012, 18, 5); k.pop()   # (the belt)
	# the shoulders: small curved plates
	for sx: float in [1.0, -1.0]:
		k.paint(white, 0.15, 0.28, ArtKit.MARBLE); k.ball(Vector3(sx * 0.17, 0.48, 0.0), Vector3(0.07, 0.05, 0.075), 10, 6)
		k.paint(gold, 1.0, 0.22, ArtKit.WORN); k.at(Vector3(sx * 0.17, 0.465, 0.0)); k.torus(0.066, 0.005, 14, 4); k.pop()
	# the neck and the head: a fair face, long ears, pale hair down the back, a gold circlet and a tall crest
	k.paint("e8c9ac", 0.0, 0.55, ArtKit.SKIN); _limb(k, Vector3(0, 0.5, 0), Vector3(0, 0.6, 0.005), 0.042, 0.04, 8)
	k.ball(Vector3(0, 0.68, 0.012), Vector3(0.078, 0.098, 0.088), 12, 8)
	for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.07, 0.68, 0.0), Vector3(sx * 0.11, 0.72, -0.03), Vector3(sx * 0.14, 0.77, -0.06)]), PackedFloat32Array([0.016, 0.01, 0.001]), 6)
	k.paint("2a3a5a", 0.0, 0.4, ArtKit.PLAIN, 1, 0.6); for sx: float in [1.0, -1.0]: k.ball(Vector3(sx * 0.03, 0.69, 0.09), Vector3(0.012, 0.007, 0.006), 6, 4)
	k.paint("efe0b0", 0.1, 0.45, ArtKit.CLOTH); k.ball(Vector3(0, 0.71, -0.02), Vector3(0.088, 0.094, 0.088), 12, 7)
	k.tube(ArtKit.spline([Vector3(0, 0.7, -0.07), Vector3(0, 0.55, -0.11), Vector3(0, 0.38, -0.13), Vector3(0, 0.26, -0.13)], 5), PackedFloat32Array([0.07, 0.06, 0.05, 0.04, 0.03, 0.025, 0.02, 0.014, 0.01, 0.006, 0.004, 0.002, 0.001, 0.001, 0.001, 0.001]), 8)
	k.paint(gold, 1.0, 0.2, ArtKit.WORN); k.at(Vector3(0, 0.735, 0.0), Vector3(0.12, 0, 0)); k.torus(0.087, 0.007, 18, 5); k.pop()
	k.paint(white, 0.15, 0.28, ArtKit.MARBLE); side(k, [Vector2(0.06, 0.74), Vector2(-0.04, 0.8), Vector2(-0.11, 0.86), Vector2(-0.09, 0.8), Vector2(0.0, 0.75)], 0.012, 0.004, 1)
	k.paint("4fd8e8", 0.0, 0.1, ArtKit.CRYSTAL, 1, 0.8); k.at(Vector3(0, 0.735, 0.088), Vector3(PI / 2.0, 0, 0)); k.gem(0.009, 0.006, 0.006, 4); k.pop()
	# the quiver on its back, aslant, bolts with teal fletching out of it
	k.paint("5a3d22", 0.0, 0.65, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0.1, 0.1, -0.16), Vector3(-0.08, 0.56, -0.17)]), PackedFloat32Array([0.045, 0.05]), 10)
	k.paint(gold, 1.0, 0.25, ArtKit.WORN)
	for e: float in [0.15, 0.85]:
		var p := Vector3(0.1, 0.1, -0.16).lerp(Vector3(-0.08, 0.56, -0.17), e); k.toward(p, Vector3(-0.18, 0.46, -0.01)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.05, 0.006, 14, 4); k.pop(); k.pop()
	for i in 5:
		var o := Vector3(-0.08, 0.56, -0.17) + Vector3((i - 2) * 0.014, 0.0, (i % 2) * 0.012 - 0.006)
		k.paint("c9d3dc", 0.8, 0.3); k.tube(PackedVector3Array([o, o + Vector3(-0.03, 0.12, 0.0)]), 0.0035, 5)
		k.paint("38bdf8", 0.0, 0.4, ArtKit.PLAIN, 1, 0.8); k.ball(o + Vector3(-0.028, 0.1, 0.0), Vector3(0.01, 0.024, 0.004), 6, 4)

static func _elf_arm(k: ArtKit, right: bool, P: Dictionary) -> void:
	k.paint("2e3440", 0.0, 0.7, ArtKit.CLOTH); _limb(k, Vector3.ZERO, Vector3(0, -0.28, 0), 0.044, 0.036)
	k.paint("e9e6dd", 0.15, 0.3, ArtKit.MARBLE); _limb(k, Vector3(0, -0.28, 0), Vector3(0, -0.5, 0.01), 0.036, 0.031)
	k.paint("d8a33e", 1.0, 0.22, ArtKit.WORN); for y: float in [-0.3, -0.48]: k.at(Vector3(0, y, 0.003)); k.torus(0.036, 0.004, 12, 4); k.pop()
	k.paint("5e4330", 0.0, 0.65, ArtKit.LEATHER); k.ball(Vector3(0, -0.55, 0.012), Vector3(0.034, 0.045, 0.036), 9, 5)
	if not right: return
	# the crossbow: white marble and gold, its violet core, its limbs and teal string
	_in_hand(k, Vector3(0, -0.55, 0.05))
	var m := Color(P.marble); var g := Color(P.gold)
	k.paint(m, 0.1, 0.3, ArtKit.MARBLE); k.rbox(Vector3(0.05, 0.06, 0.2), Vector3(0, 0.01, -0.05), 0.01, 1)
	side(k, [Vector2(0.05, 0.03), Vector2(0.3, 0.0), Vector2(0.3, -0.1), Vector2(0.16, -0.06), Vector2(0.05, -0.03)], 0.04, 0.008, 1)
	k.paint(P.core, 0.0, 0.08, ArtKit.CRYSTAL, 2, 0.9); k.at(Vector3(0, 0.04, -0.06)); k.gem(0.016, 0.022, 0.022, 4, PI / 4.0); k.pop()
	k.paint(P.ivory, 0.1, 0.3, ArtKit.MARBLE); k.rbox(Vector3(0.04, 0.02, 0.5), Vector3(0, 0.05, -0.35), 0.005, 1)
	k.paint(g, 1.0, 0.22, ArtKit.WORN); k.rbox(Vector3(0.044, 0.008, 0.5), Vector3(0, 0.062, -0.35), 0.002, 1)
	k.paint(P.glow, 0.0, 0.4, ArtKit.PLAIN, 1, 0.7); k.rbox(Vector3(0.008, 0.004, 0.5), Vector3(0, 0.067, -0.35), 0.001, 1)
	for sx: float in [1.0, -1.0]:
		var pts := [Vector3(sx * 0.03, 0.03, -0.52), Vector3(sx * 0.16, 0.035, -0.49), Vector3(sx * 0.28, 0.04, -0.42), Vector3(sx * 0.33, 0.045, -0.45)]
		k.paint(m, 0.1, 0.3, ArtKit.MARBLE); k.sweep(ArtKit.spline(pts, 4), ArtKit.circle(8), [Vector2(0.008, 0.016), Vector2(0.005, 0.008)], Vector3.UP)
		k.paint(P.glow, 0.0, 0.4, ArtKit.PLAIN, 1, 1.0); k.tube(PackedVector3Array([pts[3], Vector3(0, 0.06, -0.24)]), 0.003, 5, false)
	k.paint(g, 1.0, 0.2, ArtKit.WORN)
	for i in 4: var a := i * PI / 2.0; k.at(Vector3(0, 0.13, 0.0), Vector3(0, 0, a)); k.extrude(ArtKit.crescent(0.04, 0.01, 0.6, 8), 0.005, 0.0, 0); k.pop()
	k.pop()

# --- the dwarf ---
static func _dwarf_leg(k: ArtKit) -> void:
	k.paint("4a3a2c", 0.0, 0.75, ArtKit.LEATHER); _limb(k, Vector3.ZERO, Vector3(0, -0.24, 0.02), 0.09, 0.078)
	k.paint("b67c3c", 1.0, 0.36, ArtKit.WORN); k.ball(Vector3(0, -0.24, 0.035), Vector3(0.075, 0.06, 0.07), 10, 6)
	k.ball(Vector3(0, -0.36, 0.02), Vector3(0.08, 0.1, 0.08), 10, 6)
	k.paint("3a2a1e", 0.0, 0.7, ArtKit.LEATHER)   # (the boot: big, a bronze toe cap)
	k.tube(PackedVector3Array([Vector3(0, -0.42, -0.02), Vector3(0, -0.47, 0.03), Vector3(0, -0.485, 0.13)]), PackedFloat32Array([0.075, 0.08, 0.06]), 10)
	k.paint("b67c3c", 1.0, 0.35, ArtKit.WORN); k.ball(Vector3(0, -0.475, 0.13), Vector3(0.06, 0.04, 0.05), 10, 5)

static func _dwarf_up(k: ArtKit, tc: Color) -> void:
	var br := Color("b67c3c"); var br2 := Color("8a5a2a")
	k.paint("6e6e74", 0.6, 0.55, ArtKit.IRON); k.lathe(PackedVector2Array([Vector2(0.0, -0.16), Vector2(0.22, -0.16), Vector2(0.24, -0.06), Vector2(0.2, 0.08), Vector2(0.0, 0.08)]), 14)   # (a skirt of mail)
	# the round breastplate, riveted, a rune at its heart
	k.paint(br, 1.0, 0.34, ArtKit.WORN); k.ball(Vector3(0, 0.25, 0.02), Vector3(0.25, 0.25, 0.22), 16, 10)
	for i in 9:
		var a := -1.2 + i * 0.3
		k.paint("d9aa4a", 1.0, 0.3); k.dome(Vector3(sin(a) * 0.255, 0.18, cos(a) * 0.225 + 0.02), Vector3(sin(a), 0, cos(a)), 0.009, 0.006, 5)
	k.paint("f59e0b", 0.0, 0.4, ArtKit.PLAIN, 5, 1.0); k.toward(Vector3(0, 0.27, 0.238), Vector3(0, 0, -1)); k.rune(7, 0.07, 0.01, 0.0); k.pop()
	k.paint("4a3424", 0.0, 0.7, ArtKit.LEATHER); k.at(Vector3(0, 0.07, 0.01)); k.torus(0.235, 0.028, 18, 5); k.pop()
	k.paint("d9aa4a", 1.0, 0.25, ArtKit.WORN); k.rbox(Vector3(0.1, 0.07, 0.03), Vector3(0, 0.07, 0.245), 0.01, 1)
	k.paint(tc, 0.0, 0.75, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(0.22, 0.4, 0.05), Vector3(0.05, 0.28, 0.24), Vector3(-0.18, 0.1, 0.16)], 5), 0.022, 6)
	k.rbox(Vector3(0.14, 0.2, 0.012), Vector3(0, -0.06, 0.205), 0.004, 1)   # (a tabard below the belt)
	# great round pauldrons
	for sx: float in [1.0, -1.0]:
		k.paint(br, 1.0, 0.34, ArtKit.WORN); k.ball(Vector3(sx * 0.26, 0.43, 0.0), Vector3(0.13, 0.1, 0.13), 12, 7)
		k.paint(br2, 1.0, 0.4, ArtKit.WORN); k.at(Vector3(sx * 0.26, 0.4, 0.0)); k.torus(0.125, 0.012, 16, 4); k.pop()
	# the head: a bronze helm with a nose guard and a crest, the plume its side's colour; a great orange beard in braids
	k.paint("d9a98a", 0.0, 0.55, ArtKit.SKIN); k.ball(Vector3(0, 0.6, 0.04), Vector3(0.105, 0.1, 0.1), 12, 8)
	k.ball(Vector3(0, 0.6, 0.14), Vector3(0.025, 0.03, 0.025), 8, 5)
	k.paint(br, 1.0, 0.32, ArtKit.WORN); k.dome(Vector3(0, 0.63, 0.03), Vector3.UP, 0.12, 0.11, 14)
	k.at(Vector3(0, 0.63, 0.03)); k.torus(0.118, 0.012, 18, 5); k.pop()
	k.rbox(Vector3(0.022, 0.09, 0.02), Vector3(0, 0.6, 0.15), 0.006, 1)
	k.paint(tc, 0.0, 0.8, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(0, 0.74, 0.05), Vector3(0, 0.8, -0.02), Vector3(0, 0.78, -0.12), Vector3(0, 0.7, -0.17)], 4), PackedFloat32Array([0.022, 0.026, 0.024, 0.02, 0.016, 0.012, 0.009, 0.006, 0.004, 0.002, 0.001, 0.001, 0.001]), 7)
	var beard := Color("c8602a")
	k.paint(beard, 0.0, 0.85, ArtKit.CLOTH); k.ball(Vector3(0, 0.5, 0.12), Vector3(0.12, 0.13, 0.075), 12, 7)
	k.ball(Vector3(0, 0.575, 0.15), Vector3(0.07, 0.025, 0.03), 10, 5)   # (the moustache)
	for sx: float in [1.0, -1.0]:
		k.paint(beard, 0.0, 0.85, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(sx * 0.05, 0.42, 0.15), Vector3(sx * 0.055, 0.32, 0.17), Vector3(sx * 0.05, 0.22, 0.17)], 4), PackedFloat32Array([0.03, 0.026, 0.022, 0.02, 0.018, 0.016, 0.014, 0.012, 0.01]), 7)
		k.paint("d9aa4a", 1.0, 0.25); k.at(Vector3(sx * 0.052, 0.3, 0.17)); k.torus(0.02, 0.006, 10, 4); k.pop()
		k.paint("e0a070", 0.0, 0.85, ArtKit.CLOTH); k.ball(Vector3(sx * 0.045, 0.64, 0.135), Vector3(0.035, 0.012, 0.015), 8, 4)
	# the steam pack: a bronze boiler on its back, riveted, a round grille, a stack, copper pipes to the shoulders
	k.paint(br, 1.0, 0.34, ArtKit.WORN); k.at(Vector3(0, 0.14, -0.27)); k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.04), Vector2(0.16, 0.36), Vector2(0.12, 0.43), Vector2(0.0, 0.46)]), 16); k.pop()
	k.paint(br2, 1.0, 0.4, ArtKit.WORN); for y: float in [0.2, 0.42]: k.at(Vector3(0, y, -0.27)); k.torus(0.162, 0.01, 18, 4); k.pop()
	k.paint("2a2420", 0.6, 0.5, ArtKit.IRON); k.toward(Vector3(0, 0.33, -0.43), Vector3(0, 0, 1)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.cyl(0.075, 0.075, 0.01, 16); k.pop(); k.pop()
	k.paint("d9aa4a", 1.0, 0.25, ArtKit.WORN); k.toward(Vector3(0, 0.33, -0.44), Vector3(0, 0, 1)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.078, 0.009, 18, 4)
	for i in 4: k.at(Vector3(0, 0, 0)); k.rbox(Vector3(0.13, 0.006, 0.008), Vector3(0, 0.006, -0.045 + i * 0.03), 0.002, 1); k.pop()
	k.pop(); k.pop()
	k.paint("2a2c30", 0.8, 0.5, ArtKit.IRON); k.at(Vector3(0.08, 0.6, -0.27)); k.cyl(0.026, 0.03, 0.12, 10, true, false); k.pop()
	k.paint("c56f3e", 1.0, 0.3, ArtKit.WORN)
	for sx: float in [1.0, -1.0]: k.tube(ArtKit.spline([Vector3(sx * 0.12, 0.5, -0.24), Vector3(sx * 0.2, 0.52, -0.12), Vector3(sx * 0.24, 0.47, -0.04)], 4), 0.012, 7)
	k.paint("4a3424", 0.0, 0.7, ArtKit.LEATHER); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.16, 0.45, 0.05), Vector3(sx * 0.15, 0.45, -0.2)]), 0.018, 6)

static func _dwarf_arm(k: ArtKit, right: bool, P: Dictionary) -> void:
	k.paint("4a3a2c", 0.0, 0.75, ArtKit.LEATHER); _limb(k, Vector3.ZERO, Vector3(0, -0.2, 0.0), 0.07, 0.062)
	k.paint("b67c3c", 1.0, 0.35, ArtKit.WORN); _limb(k, Vector3(0, -0.2, 0), Vector3(0, -0.36, 0.01), 0.066, 0.06)
	k.paint("8a5a2a", 1.0, 0.4, ArtKit.WORN); k.at(Vector3(0, -0.21, 0)); k.torus(0.068, 0.009, 12, 4); k.pop()
	k.paint("a8743a", 1.0, 0.36, ArtKit.WORN); k.ball(Vector3(0, -0.41, 0.012), Vector3(0.055, 0.06, 0.055), 9, 6)
	if not right: return
	# the blunderbuss: a flared iron barrel, a bronze breech and boiler, a wood stock
	_in_hand(k, Vector3(0, -0.42, 0.05))
	k.paint(P.iron, 0.8, 0.5, ArtKit.IRON); k.at(Vector3(0, 0.04, -0.06), Vector3(-PI / 2.0, 0, 0)); k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.032, 0.25), Vector2(0.045, 0.34), Vector2(0.07, 0.4), Vector2(0.05, 0.4), Vector2(0.026, 0.36)]), 12); k.pop()
	k.paint(P.glow, 0.0, 0.5, ArtKit.PLAIN, 5, 0.5); k.at(Vector3(0, 0.04, -0.3), Vector3(-PI / 2.0, 0, 0)); k.torus(0.036, 0.004, 12, 4); k.pop()
	k.paint(P.bronze, 1.0, 0.35, ArtKit.WORN); k.rbox(Vector3(0.08, 0.09, 0.14), Vector3(0, 0.03, 0.02), 0.012, 1)
	k.at(Vector3(-0.07, 0.03, 0.06), Vector3(-PI / 2.0, 0, 0)); k.cyl(0.03, 0.03, 0.16, 10); k.pop()
	k.paint(P.dial, 0.0, 0.5); k.at(Vector3(-0.1, 0.03, -0.02), Vector3(0, 0, PI / 2.0)); k.cyl(0.02, 0.02, 0.006, 10); k.pop()
	k.paint(P.wood, 0.0, 0.55, ArtKit.WOOD); side(k, [Vector2(0.08, 0.05), Vector2(0.26, 0.02), Vector2(0.26, -0.08), Vector2(0.1, -0.07)], 0.05, 0.01, 1)
	k.pop()

# --- the orc ---
static func _orc_leg(k: ArtKit) -> void:
	k.paint("3a2c24", 0.0, 0.75, ArtKit.LEATHER); _limb(k, Vector3.ZERO, Vector3(0, -0.45, 0.04), 0.11, 0.085, 12)
	k.paint("6f9a4a", 0.0, 0.6, ArtKit.SKIN); _limb(k, Vector3(0, -0.45, 0.04), Vector3(0, -0.78, 0.0), 0.08, 0.065, 12)
	k.paint("4a4c52", 0.7, 0.55, ArtKit.IRON); k.ball(Vector3(0, -0.45, 0.07), Vector3(0.075, 0.07, 0.06), 10, 6)
	k.tube(PackedVector3Array([Vector3(0, -0.45, 0.12), Vector3(0, -0.43, 0.2)]), PackedFloat32Array([0.02, 0.001]), 6)
	k.paint("4a3a2c", 0.0, 0.85, ArtKit.CLOTH); k.ball(Vector3(0, -0.76, 0.0), Vector3(0.09, 0.05, 0.09), 10, 5)   # (fur at the boot's top)
	k.paint("2a2018", 0.0, 0.7, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0, -0.8, -0.02), Vector3(0, -0.88, 0.04), Vector3(0, -0.9, 0.17)]), PackedFloat32Array([0.075, 0.08, 0.06]), 10)

static func _orc_up(k: ArtKit, tc: Color) -> void:
	var skin := Color("6f9a4a"); var iron := Color("4a4c52")
	# a mass of muscle, hunched forward: the belly, the great chest thrust forward, the hump of the back
	k.paint("3a2c24", 0.0, 0.75, ArtKit.LEATHER); k.ball(Vector3(0, 0.06, 0.0), Vector3(0.22, 0.12, 0.17), 12, 6)
	k.paint(skin, 0.0, 0.6, ArtKit.SKIN); k.ball(Vector3(0, 0.28, 0.05), Vector3(0.25, 0.22, 0.2), 14, 8)
	k.ball(Vector3(0, 0.52, 0.11), Vector3(0.31, 0.22, 0.22), 14, 8)
	k.ball(Vector3(0, 0.6, -0.04), Vector3(0.27, 0.18, 0.18), 12, 7)
	for sx: float in [1.0, -1.0]: k.ball(Vector3(sx * 0.12, 0.5, 0.22), Vector3(0.11, 0.08, 0.06), 10, 6)   # (the chest's slabs)
	# an iron plate on its chest, a chain across, the belt and its side's loincloth
	k.paint(iron, 0.85, 0.55, ArtKit.IRON); k.ball(Vector3(-0.1, 0.42, 0.2), Vector3(0.15, 0.13, 0.06), 10, 6)
	k.paint("3a3c40", 0.9, 0.5, ArtKit.IRON)
	var cpath := ArtKit.spline([Vector3(0.28, 0.66, 0.08), Vector3(0.1, 0.45, 0.3), Vector3(-0.15, 0.22, 0.24), Vector3(-0.25, 0.1, 0.12)], 6)
	for i in cpath.size() - 1: var a := cpath[i]; var b := cpath[i + 1]; k.toward((a + b) * 0.5, (b - a).normalized()); k.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)), Vector3.ZERO)); k.link(0.045, 0.026, 0.006, 4); k.pop(); k.pop()
	k.paint("4a3424", 0.0, 0.7, ArtKit.LEATHER); k.at(Vector3(0, 0.1, 0.01)); k.torus(0.235, 0.035, 18, 5); k.pop()
	k.paint(iron, 0.9, 0.45, ArtKit.IRON); k.ball(Vector3(0, 0.1, 0.24), Vector3(0.06, 0.05, 0.03), 8, 5)
	k.paint(tc, 0.0, 0.8, ArtKit.CLOTH)
	for z: float in [0.2, -0.17]:
		var rows: Array = []
		for j in 5:
			var t := float(j) / 4.0; var row := PackedVector3Array()
			for i in 5: var u := lerpf(-1.0, 1.0, float(i) / 4.0); row.push_back(Vector3(u * lerpf(0.13, 0.11, t), lerpf(0.06, -0.38, t), z + signf(z) * (t * 0.05 + (1.0 - u * u) * 0.02)))
			rows.push_back(row)
		k.sheet(rows, Vector3(0, 0, signf(z)))
	# the great spiked pauldrons of black iron
	for sx: float in [1.0, -1.0]:
		var c := Vector3(sx * 0.38, 0.7, 0.04)
		k.paint(iron, 0.85, 0.5, ArtKit.IRON); k.ball(c, Vector3(0.17, 0.12, 0.18), 12, 7)
		k.paint(iron.lightened(0.08), 0.85, 0.5, ArtKit.IRON); k.ball(c + Vector3(sx * 0.03, -0.06, 0.0), Vector3(0.16, 0.06, 0.17), 12, 5)
		k.paint("8d9197", 0.95, 0.35, ArtKit.IRON)
		for i in 5:
			var a := -1.0 + i * 0.5; var o := Vector3(sx * cos(a) * 0.1, 0.11, sin(a) * 0.14)
			k.tube(PackedVector3Array([c + o, c + o * 1.2 + Vector3(sx * 0.04, 0.12, 0)]), PackedFloat32Array([0.022, 0.001]), 6)
	# the head, low and thrust forward: a heavy jaw, tusks up from it, a brow like a ledge, a black topknot
	k.paint(skin, 0.0, 0.6, ArtKit.SKIN); _limb(k, Vector3(0, 0.66, 0.12), Vector3(0, 0.78, 0.22), 0.1, 0.085)
	k.ball(Vector3(0, 0.84, 0.27), Vector3(0.11, 0.115, 0.11), 12, 8)
	k.ball(Vector3(0, 0.78, 0.33), Vector3(0.1, 0.06, 0.07), 10, 6)
	k.paint(skin.darkened(0.15), 0.0, 0.6, ArtKit.SKIN); k.ball(Vector3(0, 0.88, 0.35), Vector3(0.1, 0.025, 0.04), 10, 5)
	k.paint("d6c9aa", 0.0, 0.55, ArtKit.BONE); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.05, 0.79, 0.37), Vector3(sx * 0.06, 0.84, 0.395), Vector3(sx * 0.055, 0.87, 0.385)]), PackedFloat32Array([0.013, 0.009, 0.001]), 6)
	k.paint("ff3a1a", 0.0, 0.5, ArtKit.PLAIN, 0, 0.9); for sx: float in [1.0, -1.0]: k.ball(Vector3(sx * 0.04, 0.855, 0.365), Vector3(0.012, 0.007, 0.006), 6, 4)
	k.paint(skin, 0.0, 0.6, ArtKit.SKIN); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.1, 0.85, 0.26), Vector3(sx * 0.15, 0.88, 0.22)]), PackedFloat32Array([0.025, 0.002]), 6)
	k.paint("1a1412", 0.0, 0.8, ArtKit.CLOTH); k.tube(ArtKit.spline([Vector3(0, 0.95, 0.22), Vector3(0, 1.0, 0.16), Vector3(0, 0.96, 0.08), Vector3(0, 0.86, 0.04)], 4), PackedFloat32Array([0.03, 0.03, 0.028, 0.025, 0.022, 0.02, 0.017, 0.014, 0.011, 0.008, 0.005, 0.002, 0.001]), 7)

## the greatsword left standing where its orc fell, its point in the ground (y up from it)
static func sword_left(k: ArtKit) -> void:
	k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 1.35, 0)))
	var P := pal("orc")
	k.paint(P.wrap, 0.0, 0.8, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0, 0, 0.12), Vector3(0, 0, -0.08)]), 0.022, 8)
	k.paint(P.steel, 0.85, 0.5, ArtKit.IRON); k.rbox(Vector3(0.3, 0.05, 0.045), Vector3(0.02, 0, -0.09), 0.01, 1)
	k.paint(P.bone, 0.0, 0.6, ArtKit.BONE); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.17, 0, -0.09), Vector3(sx * 0.21, 0, -0.14), Vector3(sx * 0.19, 0, -0.22)]), PackedFloat32Array([0.016, 0.01, 0.001]), 6)
	k.paint(P.steel, 0.82, 0.58, ArtKit.IRON)
	k.at(Vector3.ZERO, Vector3(-PI / 2.0, 0, 0)); k.extrude(PackedVector2Array([Vector2(-0.07, 0.1), Vector2(-0.07, 1.05), Vector2(-0.05, 1.18), Vector2(0.06, 1.14), Vector2(0.17, 0.98), Vector2(0.14, 0.5), Vector2(0.09, 0.1)]), 0.016, 0.004, 1)
	k.paint(P.rune, 0.2, 0.5, ArtKit.PLAIN, 4, 0.5); k.at(Vector3(-0.025, 0.6, 0.0)); k.extrude(PackedVector2Array([Vector2(-0.014, -0.45), Vector2(0.014, -0.45), Vector2(0.014, 0.4), Vector2(-0.014, 0.4)]), 0.019, 0.0, 0); k.pop(); k.pop()
	k.pop()

static func _orc_arm(k: ArtKit, right: bool, P: Dictionary) -> void:
	var skin := Color("6f9a4a")
	k.paint(skin, 0.0, 0.6, ArtKit.SKIN); _limb(k, Vector3.ZERO, Vector3(0, -0.3, 0.02), 0.1, 0.085, 12)
	k.ball(Vector3(0, -0.12, 0.05), Vector3(0.075, 0.1, 0.07), 10, 6)
	_limb(k, Vector3(0, -0.3, 0.02), Vector3(0, -0.56, 0.04), 0.085, 0.07, 12)
	k.paint("4a4c52", 0.7, 0.55, ArtKit.IRON); _limb(k, Vector3(0, -0.4, 0.03), Vector3(0, -0.55, 0.04), 0.09, 0.082, 12)
	k.paint("8d9197", 0.95, 0.35, ArtKit.IRON); for i in 3: var a := i * 2.1; k.tube(PackedVector3Array([Vector3(cos(a) * 0.085, -0.47, 0.035 + sin(a) * 0.085), Vector3(cos(a) * 0.13, -0.45, 0.035 + sin(a) * 0.13)]), PackedFloat32Array([0.014, 0.001]), 5)
	k.paint("6b4a2c", 0.0, 0.8, ArtKit.LEATHER); k.ball(Vector3(0, -0.62, 0.05), Vector3(0.07, 0.075, 0.07), 10, 6)
	if not right: return
	# the blood-rune greatsword: a cleaver of black iron, the crimson fuller, bone fangs at its guard
	_in_hand(k, Vector3(0, -0.62, 0.05))
	k.paint(P.wrap, 0.0, 0.8, ArtKit.LEATHER); k.tube(PackedVector3Array([Vector3(0, 0, 0.12), Vector3(0, 0, -0.08)]), 0.022, 8)
	k.paint(P.steel, 0.85, 0.5, ArtKit.IRON); k.rbox(Vector3(0.3, 0.05, 0.045), Vector3(0.02, 0, -0.09), 0.01, 1)
	k.paint(P.bone, 0.0, 0.6, ArtKit.BONE); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.17, 0, -0.09), Vector3(sx * 0.21, 0, -0.14), Vector3(sx * 0.19, 0, -0.22)]), PackedFloat32Array([0.016, 0.01, 0.001]), 6)
	k.paint(P.steel, 0.82, 0.58, ArtKit.IRON)
	var blade := PackedVector2Array([Vector2(-0.07, 0.1), Vector2(-0.07, 1.05), Vector2(-0.05, 1.18), Vector2(0.06, 1.14), Vector2(0.17, 0.98), Vector2(0.14, 0.5), Vector2(0.09, 0.1)])
	k.at(Vector3(0, 0, 0), Vector3(-PI / 2.0, 0, 0)); k.extrude(blade, 0.016, 0.004, 1)
	k.paint(P.rune, 0.2, 0.5, ArtKit.PLAIN, 4, 0.9); k.at(Vector3(-0.025, 0.6, 0.0)); k.extrude(PackedVector2Array([Vector2(-0.014, -0.45), Vector2(0.014, -0.45), Vector2(0.014, 0.4), Vector2(-0.014, 0.4)]), 0.019, 0.0, 0); k.pop()
	k.paint(P.edge, 0.95, 0.38, ArtKit.IRON); k.tube(ArtKit.spline([Vector3(0.09, 0.1, 0), Vector3(0.14, 0.5, 0), Vector3(0.17, 0.98, 0), Vector3(0.06, 1.14, 0)], 4), 0.005, 5, false)
	k.pop(); k.pop()

# --- the demon ---
static func _demon_leg(k: ArtKit) -> void:
	var skin := Color("a8382e"); var dark := Color("231a20")
	k.paint(dark, 0.4, 0.4, ArtKit.OBSIDIAN); _limb(k, Vector3.ZERO, Vector3(0, -0.4, 0.12), 0.085, 0.065)
	k.paint(skin, 0.0, 0.55, ArtKit.SKIN); _limb(k, Vector3(0, -0.4, 0.12), Vector3(0, -0.74, -0.06), 0.06, 0.045)
	k.paint(dark, 0.4, 0.35, ArtKit.OBSIDIAN); k.ball(Vector3(0, -0.4, 0.15), Vector3(0.06, 0.06, 0.05), 9, 5)
	k.tube(PackedVector3Array([Vector3(0, -0.38, 0.19), Vector3(0, -0.33, 0.27)]), PackedFloat32Array([0.018, 0.001]), 6)
	k.paint(skin.darkened(0.2), 0.0, 0.55, ArtKit.SKIN); _limb(k, Vector3(0, -0.74, -0.06), Vector3(0, -0.92, 0.04), 0.045, 0.04, 8)
	k.paint("121014", 0.3, 0.2)
	for sx: float in [-1.0, 0.0, 1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.03, -0.92, 0.04), Vector3(sx * 0.04, -0.94, 0.1), Vector3(sx * 0.045, -0.95, 0.13)]), PackedFloat32Array([0.016, 0.01, 0.001]), 6)

static func _demon_up(k: ArtKit, tc: Color) -> void:
	var skin := Color("a8382e"); var dark := Color("231a20")
	k.paint(skin, 0.0, 0.55, ArtKit.SKIN); k.ball(Vector3(0, 0.06, 0), Vector3(0.16, 0.1, 0.11), 12, 6)
	_limb(k, Vector3(0, 0.1, 0.0), Vector3(0, 0.3, 0.01), 0.13, 0.15, 12)
	k.ball(Vector3(0, 0.42, 0.02), Vector3(0.2, 0.17, 0.13), 14, 8)
	for i in 3: k.ball(Vector3(0, 0.15 + i * 0.065, 0.11), Vector3(0.07, 0.03, 0.025), 8, 4)   # (the belly's ridges)
	# dark armour on the chest and shoulders, spiked; the spine's ridge running down to the tail
	k.paint(dark, 0.4, 0.3, ArtKit.OBSIDIAN); k.ball(Vector3(0, 0.44, 0.06), Vector3(0.19, 0.12, 0.1), 12, 6)
	for sx: float in [1.0, -1.0]:
		var c := Vector3(sx * 0.21, 0.52, 0.0)
		k.ball(c, Vector3(0.09, 0.07, 0.09), 10, 6)
		for i in 3: var a := -0.7 + i * 0.7; k.tube(PackedVector3Array([c + Vector3(sx * 0.05, 0.04, sin(a) * 0.06), c + Vector3(sx * 0.11, 0.13, sin(a) * 0.09)]), PackedFloat32Array([0.016, 0.001]), 6)
	for i in 6: var y := 0.1 + i * 0.08; k.tube(PackedVector3Array([Vector3(0, y, -0.12 - (0.02 if i > 2 else 0.0)), Vector3(0, y + 0.03, -0.17)]), PackedFloat32Array([0.014, 0.001]), 5)
	k.paint(tc, 0.0, 0.8, ArtKit.CLOTH)
	for z: float in [0.12, -0.11]:
		var rows: Array = []
		for j in 5:
			var t := float(j) / 4.0; var row := PackedVector3Array()
			for i in 5: var u := lerpf(-1.0, 1.0, float(i) / 4.0); row.push_back(Vector3(u * lerpf(0.09, 0.06, t), lerpf(0.06, -0.42, t), z + signf(z) * (t * 0.03)))
			rows.push_back(row)
		k.sheet(rows, Vector3(0, 0, signf(z)))
	k.paint("d0a040", 1.0, 0.3, ArtKit.WORN); k.at(Vector3(0, 0.07, 0)); k.torus(0.16, 0.014, 18, 4); k.pop()
	k.paint(tc, 0.0, 0.8, ArtKit.CLOTH); for sx: float in [1.0, -1.0]: k.at(Vector3(sx * 0.21, 0.45, 0.0), Vector3(0, 0, -sx * 0.3)); k.torus(0.075, 0.014, 12, 4); k.pop()
	# the head: red, a ridged brow, burning eyes, fangs, and the great curved horns
	k.paint(skin, 0.0, 0.55, ArtKit.SKIN); _limb(k, Vector3(0, 0.55, 0.0), Vector3(0, 0.64, 0.02), 0.06, 0.055, 8)
	k.ball(Vector3(0, 0.72, 0.03), Vector3(0.085, 0.1, 0.095), 12, 8)
	k.ball(Vector3(0, 0.66, 0.08), Vector3(0.06, 0.04, 0.05), 10, 5)
	k.paint(skin.darkened(0.25), 0.0, 0.5, ArtKit.SKIN); k.ball(Vector3(0, 0.755, 0.1), Vector3(0.075, 0.018, 0.03), 10, 4)
	k.paint("ffd23a", 0.0, 0.4, ArtKit.PLAIN, 6, 1.0); for sx: float in [1.0, -1.0]: k.ball(Vector3(sx * 0.033, 0.735, 0.118), Vector3(0.014, 0.008, 0.006), 6, 4)
	k.paint("e8e0d0", 0.0, 0.4, ArtKit.BONE); for sx: float in [1.0, -1.0]: k.tube(PackedVector3Array([Vector3(sx * 0.02, 0.655, 0.12), Vector3(sx * 0.022, 0.635, 0.125)]), PackedFloat32Array([0.006, 0.001]), 5)
	for sx: float in [1.0, -1.0]: k.paint(skin, 0.0, 0.55, ArtKit.SKIN); k.tube(PackedVector3Array([Vector3(sx * 0.08, 0.73, 0.0), Vector3(sx * 0.13, 0.76, -0.04)]), PackedFloat32Array([0.02, 0.001]), 6)
	k.paint("2a2024", 0.2, 0.35, ArtKit.BONE)
	for sx: float in [1.0, -1.0]:
		var hp := ArtKit.spline([Vector3(sx * 0.055, 0.79, 0.03), Vector3(sx * 0.12, 0.88, -0.02), Vector3(sx * 0.2, 0.95, -0.12), Vector3(sx * 0.24, 1.05, -0.12), Vector3(sx * 0.22, 1.13, -0.02), Vector3(sx * 0.18, 1.15, 0.06)], 5)
		var hr := PackedFloat32Array()
		for i in hp.size(): var t := float(i) / (hp.size() - 1); hr.push_back(lerpf(0.035, 0.002, pow(t, 0.9)))
		k.tube(hp, hr, 8)
		for i in 5: var q: Vector3 = hp[2 + i * 4]; k.paint("3a2e30", 0.2, 0.4, ArtKit.BONE); k.at(q); k.torus(hr[2 + i * 4] * 1.05, 0.004, 10, 3); k.pop()

static func _demon_arm(k: ArtKit, right: bool, P: Dictionary) -> void:
	var skin := Color("a8382e")
	k.paint(skin, 0.0, 0.55, ArtKit.SKIN); _limb(k, Vector3.ZERO, Vector3(0, -0.3, 0.0), 0.06, 0.05)
	k.ball(Vector3(0, -0.12, 0.03), Vector3(0.05, 0.08, 0.05), 9, 5)
	_limb(k, Vector3(0, -0.3, 0), Vector3(0, -0.54, 0.02), 0.048, 0.04)
	k.paint("231a20", 0.4, 0.3, ArtKit.OBSIDIAN); _limb(k, Vector3(0, -0.36, 0.005), Vector3(0, -0.52, 0.02), 0.054, 0.048)
	for i in 2: k.tube(PackedVector3Array([Vector3(0.04, -0.4 - i * 0.07, 0.03), Vector3(0.09, -0.38 - i * 0.07, 0.05)]), PackedFloat32Array([0.012, 0.001]), 5)
	k.paint(skin.darkened(0.1), 0.0, 0.55, ArtKit.SKIN); k.ball(Vector3(0, -0.59, 0.02), Vector3(0.04, 0.05, 0.04), 9, 5)
	k.paint("121014", 0.3, 0.2); for i in 4: var x := -0.03 + i * 0.02; k.tube(PackedVector3Array([Vector3(x, -0.62, 0.04), Vector3(x, -0.66, 0.06)]), PackedFloat32Array([0.007, 0.001]), 5)
	if not right: return
	# the hellfire staff: cracked obsidian, three horns round an ember core
	_in_hand(k, Vector3(0, -0.6, 0.04))
	k.paint(P.obsid, 0.3, 0.08, ArtKit.OBSIDIAN, 3, 0.0); k.tube(PackedVector3Array([Vector3(0, 0, 0.4), Vector3(0, 0, -0.2), Vector3(0, 0, -0.75)]), PackedFloat32Array([0.02, 0.018, 0.024]), 6, true, Vector3.UP, false)
	k.paint(P.chain, 0.85, 0.5, ArtKit.IRON, 3, 0.5); for i in 3: k.at(Vector3(0, 0, -0.7 - i * 0.02), Vector3(PI / 2.0, 0, 0)); k.torus(0.03, 0.006, 10, 4); k.pop()
	for i in 3:
		var a := i * TAU / 3.0; var r := Vector3(cos(a), sin(a), 0)
		k.paint(P.obsid, 0.35, 0.08, ArtKit.OBSIDIAN, 3, 0.0); k.tube(ArtKit.spline([r * 0.02 + Vector3(0, 0, -0.76), r * 0.08 + Vector3(0, 0, -0.84), r * 0.07 + Vector3(0, 0, -0.95), r * 0.02 + Vector3(0, 0, -1.0)], 4), PackedFloat32Array([0.018, 0.016, 0.014, 0.012, 0.01, 0.008, 0.006, 0.004, 0.003, 0.002, 0.001, 0.001, 0.001]), 6)
	k.paint("060406", 0.4, 0.1); k.ball(Vector3(0, 0, -0.9), Vector3.ONE * 0.04, 10, 6)
	k.paint(P.lava, 0.0, 0.5, ArtKit.PLAIN, 3, 1.0); k.at(Vector3(0, 0, -0.9), Vector3(PI / 2.0, 0, 0)); k.torus(0.045, 0.006, 16, 4); k.pop()
	k.pop()

static func _demon_wing(k: ArtKit) -> void:
	# a bat's wing, half spread, out to +x from its root: the arm's bones, four fingers, the membrane between them
	var bone := Color("2a2024"); var skin := Color("5a1a1e")
	var sh := Vector3(0, 0, 0); var el := Vector3(0.28, 0.22, -0.12); var wr := Vector3(0.55, 0.32, -0.2)
	k.paint(bone, 0.1, 0.45, ArtKit.BONE); k.tube(PackedVector3Array([sh, el]), PackedFloat32Array([0.03, 0.022]), 7); k.tube(PackedVector3Array([el, wr]), PackedFloat32Array([0.022, 0.016]), 7)
	k.tube(PackedVector3Array([wr, wr + Vector3(0.05, 0.08, 0.01)]), PackedFloat32Array([0.012, 0.001]), 5)   # (the thumb's claw)
	var tips := [Vector3(1.0, 0.18, -0.25), Vector3(0.95, -0.25, -0.22), Vector3(0.72, -0.55, -0.18), Vector3(0.42, -0.72, -0.12)]
	for tp: Vector3 in tips: k.tube(PackedVector3Array([wr, wr.lerp(tp, 0.55) + Vector3(0, 0.03, 0), tp]), PackedFloat32Array([0.014, 0.01, 0.002]), 6)
	k.paint(skin, 0.0, 0.6, ArtKit.SKIN)
	var edge := [el.lerp(wr, 0.0), wr] + tips + [Vector3(0.12, -0.55, -0.05), Vector3(0.02, -0.2, 0.0)]
	var rows: Array = []
	for j in 7:   # (the membrane: rows from the wrist out to the trailing edge, scalloped between the fingers)
		var t := float(j) / 6.0; var row := PackedVector3Array()
		for i in edge.size():
			var p: Vector3 = edge[i]; var c := wr.lerp(Vector3(0.3, -0.1, -0.08), 0.5)
			var sag := 0.0 if (i >= 1 and i <= 5) else 0.0
			row.push_back(c.lerp(p, t) + Vector3(0, 0, -0.04 * sin(t * PI)) + Vector3(0, sag, 0))
		rows.push_back(row)
	k.sheet(rows, Vector3(0, 0, -1))

static func _demon_tail(k: ArtKit) -> void:
	var pts := [Vector3(0, 0, 0), Vector3(0, -0.12, -0.18), Vector3(0, -0.4, -0.38), Vector3(0.05, -0.75, -0.5), Vector3(0.12, -0.86, -0.72), Vector3(0.1, -0.85, -0.95)]
	var path := ArtKit.spline(pts, 5); var rr := PackedFloat32Array()
	for i in path.size(): var t := float(i) / (path.size() - 1); rr.push_back(lerpf(0.05, 0.012, t))
	k.paint("a8382e", 0.0, 0.55, ArtKit.SKIN); k.tube(path, rr, 8)
	k.paint("231a20", 0.4, 0.3, ArtKit.OBSIDIAN)
	for i in 6: var q: Vector3 = path[2 + i * 4]; var d: Vector3 = (path[3 + i * 4] - q).normalized(); var up := d.cross(Vector3.RIGHT).normalized(); k.tube(PackedVector3Array([q - up * rr[2 + i * 4] * 0.6, q - up * (rr[2 + i * 4] + 0.04)]), PackedFloat32Array([0.012, 0.001]), 5)
	var tip: Vector3 = path[path.size() - 1]
	k.at(tip, Vector3(0, PI / 2.0, 0)); k.extrude(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.05), Vector2(0.14, 0.0), Vector2(0.06, -0.05)]), 0.012, 0.003, 1); k.pop()
