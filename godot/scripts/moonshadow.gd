class_name MoonShadow
extends SubViewport
## The browser game's moon shadow: a three.js directional light with a soft (PCF-soft) shadow map over a box 80 m across
## that follows the player, cast only by what it marks castShadow and taken only by what it marks receiveShadow.
## Godot's compatibility renderer draws a shadowed light in a pass of its own, tone maps that pass alone and adds it in
## sRGB, which brightens what the moon lights and darkens what it barely lights. So the moon here is an ordinary light in
## the main pass, and its shadow is made from this picture: the depth of every caster seen from the moon, packed into
## colour; World's shadow layer then takes the moon's share of the light back out wherever the picture says it is blocked.

const CASTER := 11      # render layer of what casts a moon shadow
const ENCODE := 20      # render layer of the quad that packs this picture's depth into colour (seen by no other camera)
const BOX := 80.0       # the shadow box, as the browser game's (left -40 .. right 40, near 1, far 160)

var cam: Camera3D
var _quad: MeshInstance3D

const ENCODE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
%s
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
	// the compatibility renderer keeps depth reversed (1 at the near plane, 0 behind everything): stored as 0 near, 1 far
	float d = min(1.0 - texture(depth_tex, SCREEN_UV).r, 0.99999);
	vec3 enc = fract(d * vec3(1.0, 255.0, 65025.0));
	enc -= enc.yzz * vec3(1.0 / 255.0, 1.0 / 255.0, 0.0);
	// the bytes pass through the tone mapper (linear here) and Godot's sRGB encode on the way out: send what comes back as them
	ALBEDO = albedo_of(pow((enc + 0.055) / 1.055, vec3(2.4))); ALPHA = 1.0;
}
"""

func setup(map_size: int) -> void:
	size = Vector2i(map_size, map_size); render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_DISABLED; debug_draw = Viewport.DEBUG_DRAW_UNSHADED; transparent_bg = false; positional_shadow_atlas_size = 0
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_exposure = 1.0
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = BOX; cam.near = 1.0; cam.far = 160.0
	cam.cull_mask = (1 << (CASTER - 1)) | (1 << (ENCODE - 1)); cam.environment = env; add_child(cam); cam.current = true
	var sh := Shader.new(); sh.code = ENCODE_SHADER % Gfx.ALBEDO_GLSL
	var m := ShaderMaterial.new(); m.shader = sh
	var q := QuadMesh.new(); q.size = Vector2(2, 2)
	_quad = MeshInstance3D.new(); _quad.mesh = q; _quad.material_override = m; _quad.layers = 1 << (ENCODE - 1)
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _quad.extra_cull_margin = 16384.0; cam.add_child(_quad); _quad.position = Vector3(0, 0, -2)

## as the browser game's updateWorld: the box centred on the player, snapped to its texels, the moon sunOff away
func place(px: float, pz: float, off: Array) -> void:
	var texel := BOX / size.x; var sx := roundf(px / texel) * texel; var sz := roundf(pz / texel) * texel
	var from := Vector3(sx + off[0], off[1], sz + off[2]); var to := Vector3(sx, 0, sz)
	cam.look_at_from_position(from, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD)

## world to the picture's clip space
func world_to_clip() -> Projection:
	return cam.get_camera_projection() * Projection(cam.global_transform.affine_inverse())

## mark a drawn thing (and everything under it) as casting the moon's shadow, or not
## what takes no moon shadow marks its pixels (the stencil), and the shadow layer passes them by: people, animals, robots
## and loot, which in the browser game cast shadows but do not receive them. Solid materials only
const UNSHADOWED := 2   # (the shadow layer's shader names the same number)
const GRASS := 3        # the savanna's tall grass cards: no shadow on them either, and the occlusion leaves their blades be (AoView names it too)
const HAND := 4         # the gun in your hands (GunModels): the occlusion leaves it be, as the browser game draws it after that (AoView names it too)
static func no_receive(n: Node) -> void:
	if not (n is GeometryInstance3D): return
	var g := n as GeometryInstance3D; var mats: Array = [g.material_override]
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		for i in mi.get_surface_override_material_count(): mats.push_back(mi.get_surface_override_material(i))
		if mi.mesh:
			for i in mi.mesh.get_surface_count(): mats.push_back(mi.mesh.surface_get_material(i))
	for m in mats:
		if m is BaseMaterial3D and (m as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			var b := m as BaseMaterial3D
			b.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM; b.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
			b.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS; b.stencil_reference = UNSHADOWED
			if Gfx.fplus: b.disable_receive_shadows = true   # (Forward+ draws the moon's own shadow: the same rule, said to it)

## the browser game's grass tufts take no shadow, and its occlusion pass marks their blades (src/03b_gfx.js tag): both from this mark
static func grass(m: BaseMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM; m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS; m.stencil_reference = GRASS
	if Gfx.fplus: m.disable_receive_shadows = true

## a solid material of the gun in your hands: marked, so the occlusion passes it by wherever it is (not only nearer than a
## set distance, which also left a wall you stood against without its occlusion); the moon's shadow layer passes it by too
static func hand(m: BaseMaterial3D) -> void:
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM; m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS; m.stencil_reference = HAND

static func caster(n: Node, on := true) -> void:
	if n is VisualInstance3D: (n as VisualInstance3D).set_layer_mask_value(CASTER, on)
	for c in n.get_children(): caster(c, on)

## the shadow layer, over the main picture: where the picture above says the moon is blocked, the moon's share of the
## light comes back out of the colour. The light a surface took is worked out as the browser game lights it (hemisphere,
## moon, the six lamps), from its place and slope read off the depth buffer; the colour is undone through Godot's ACES to
## the light it was lit with, scaled, and tone mapped again on the way out
const LAYER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
stencil_mode read, compare_greater, 2;   // (passes where 2 is greater than the mark: neither no-shadow (2), grass (3) nor the gun in hand (4))
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D shadow_map : filter_nearest;
uniform mat4 shadow_clip;
uniform float map_size = 2048.0;
uniform float flip = 0.0;
uniform vec3 moon_dir; uniform vec3 moon_col;
uniform vec3 hemi_sky; uniform vec3 hemi_ground;
uniform vec4 lamp_pos[6]; uniform vec3 lamp_col;
uniform float lamp_range = 26.75; uniform float lamp_atten = 0.82;
uniform float exposure = 1.0;
uniform float bias = 0.0006; uniform float normal_bias = 0.03;
%s
%s
vec3 view_at(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, ndc_z(d), 1.0);
	return v.xyz / v.w;
}
float stored(vec2 uv) { return dot(texture(shadow_map, vec2(uv.x, mix(uv.y, 1.0 - uv.y, flip))).rgb, vec3(1.0, 1.0 / 255.0, 1.0 / 65025.0)); }
float lit(vec2 uv, float z) { return step(z, stored(uv)); }
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
// the colour to lay over this pixel, or alpha 0 to leave it (the fragment function cannot return early)
vec4 shade(vec2 suv, vec2 vsize, mat4 ipm, mat4 iv) {
	float d0 = texture(depth_tex, suv).r;
	if (d0 <= 0.000001) return vec4(0.0);   // nothing drawn here (depth is reversed: 0 is behind everything)
	vec2 px = 1.0 / vsize;
	vec3 P = view_at(suv, ipm);
	if (-P.z < 0.9) return vec4(0.0);   // the gun in hand: lit apart in the browser game, never in the moon's shadow
	// the surface's slope from its neighbours' depth, the nearer of the two on each side (as the browser game's AO)
	vec3 pr = view_at(suv + vec2(px.x, 0.0), ipm) - P, pl = P - view_at(suv - vec2(px.x, 0.0), ipm);
	vec3 pu = view_at(suv + vec2(0.0, px.y), ipm) - P, pd = P - view_at(suv - vec2(0.0, px.y), ipm);
	vec3 nv = normalize(cross(abs(pr.z) < abs(pl.z) ? pr : pl, abs(pu.z) < abs(pd.z) ? pu : pd));
	if (dot(nv, -P) < 0.0) nv = -nv;
	vec3 n = normalize(mat3(iv) * nv);
	vec3 p = (iv * vec4(P, 1.0)).xyz;
	float nl = max(dot(n, moon_dir), 0.0);
	if (nl <= 0.0) return vec4(0.0);
	vec4 sc = shadow_clip * vec4(p + n * normal_bias, 1.0); sc.xyz /= sc.w;
	vec2 uv = sc.xy * 0.5 + 0.5; float z = sc.z * 0.5 + 0.5 - bias;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || z > 1.0) return vec4(0.0);
	// three.js r128's PCF-soft: sixteen taps over three texels, the outer ones weighted by where the point falls
	float t = 1.0 / map_size; vec2 f = fract(uv * map_size + 0.5); uv -= f * t;
	float v = (lit(uv, z) + lit(uv + vec2(t, 0.0), z) + lit(uv + vec2(0.0, t), z) + lit(uv + vec2(t), z)
		+ mix(lit(uv + vec2(-t, 0.0), z), lit(uv + vec2(2.0 * t, 0.0), z), f.x) + mix(lit(uv + vec2(-t, t), z), lit(uv + vec2(2.0 * t, t), z), f.x)
		+ mix(lit(uv + vec2(0.0, -t), z), lit(uv + vec2(0.0, 2.0 * t), z), f.y) + mix(lit(uv + vec2(t, -t), z), lit(uv + vec2(t, 2.0 * t), z), f.y)
		+ mix(mix(lit(uv + vec2(-t, -t), z), lit(uv + vec2(2.0 * t, -t), z), f.x), mix(lit(uv + vec2(-t, 2.0 * t), z), lit(uv + vec2(2.0 * t, 2.0 * t), z), f.x), f.y)) / 9.0;
	if (v >= 0.999) return vec4(0.0);
	vec3 H = mix(hemi_ground, hemi_sky, 0.5 * n.y + 0.5);
	vec3 Li = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		vec3 l = lamp_pos[i].xyz - p; float dl = length(l);
		float nd = dl / lamp_range; nd *= nd; nd *= nd; nd = max(1.0 - nd, 0.0); nd *= nd;
		Li += lamp_col * lamp_pos[i].w * nd * pow(max(dl, 0.0001), -lamp_atten) * max(dot(n, l / max(dl, 0.0001)), 0.0);
	}
	vec3 M = moon_col * nl;
	vec3 base = H + Li;
	// the moon's gloss (three.js GGX, as Godot's directional light at gloss 1.0), reckoned for a rough dielectric
	// (roughness 0.9, as most of what lies in the yard) and taken at half, which is what matches the browser game's shadows
	// on its asphalt seen low along the ground: it goes out whole in the shadow, the diffuse light only by the moon's share
	vec3 V = normalize(iv[3].xyz - p); vec3 Hh = normalize(moon_dir + V);
	float nvw = max(dot(n, V), 1e-4), nh = max(dot(n, Hh), 0.0), lh = max(dot(moon_dir, Hh), 0.0);
	float a2 = 0.6561; float dd = nh * nh * (a2 - 1.0) + 1.0; float Dg = a2 / (3.14159265 * dd * dd);
	float Vg = 0.5 / max(nl * sqrt(a2 + (1.0 - a2) * nvw * nvw) + nvw * sqrt(a2 + (1.0 - a2) * nl * nl), 1e-5);
	float Fr = 0.04 + 0.96 * exp2((-5.55473 * lh - 6.98316) * lh);
	vec3 X = unshow(texture(screen_tex, suv).rgb);
	vec3 S = min(0.5 * moon_col * 3.14159265 * nl * Fr * Vg * Dg, X * 0.8);
	return vec4((X - S) * (base + v * M) / max(base + M, vec3(1e-5)) + v * S, 1.0);
}
void fragment() {
	vec4 r = shade(SCREEN_UV, VIEWPORT_SIZE, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (r.a <= 0.0) discard;
	ALBEDO = albedo_of(r.rgb); ALPHA = 1.0;
}
"""
