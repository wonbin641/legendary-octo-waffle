class_name AoView
extends SubViewport
## The browser game's ambient occlusion on a computer at its two top quality levels (src/03b_gfx.js occlusion): a
## half-size depth picture of the solid world, twelve taps round each point in a spiral turned by a per-pixel noise,
## then blurred along depth and multiplied into the finished picture before the gun is drawn. Here the half-size
## picture is this viewport's, seen by a camera that follows the main one, and the occlusion it works out (with its
## depth, packed beside it) is blurred and multiplied in by World's AO layer. Phones go without, as there.

const LAYER := 17       # the quad that works the occlusion out, seen by this viewport's camera only (render layers run 1 to 20)
const SOLID := (1 << 0) | (1 << (MoonShadow.CASTER - 1))   # what it sees besides: the world (not the gun in hand)

var cam: Camera3D
var mat: ShaderMaterial
var _quad: MeshInstance3D

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float radius = 0.85; uniform float intensity = 1.3; uniform float bias = 0.012;
uniform float max_dist = 42.0; uniform float max_px = 48.0;
%s
vec3 vpos(vec2 uv, mat4 ipm) { float d = texture(depth_tex, uv).r; vec4 c = ipm * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0); return c.xyz / c.w; }
// the occlusion and the distance, as the browser game's aoMat (depth is reversed here: 0 is nothing drawn)
vec2 occl(vec2 suv, vec2 vsize, vec2 fc, mat4 ipm, mat4 pm) {
	if (texture(depth_tex, suv).r <= 0.000001) return vec2(1.0, 499.0);
	vec3 P = vpos(suv, ipm); float dist = -P.z;
	if (dist > max_dist) return vec2(1.0, dist);
	vec2 tx = 1.0 / vsize;
	vec3 pr = vpos(suv + vec2(tx.x, 0.0), ipm) - P, pl = P - vpos(suv - vec2(tx.x, 0.0), ipm);
	vec3 pu = vpos(suv + vec2(0.0, tx.y), ipm) - P, pd = P - vpos(suv - vec2(0.0, tx.y), ipm);
	vec3 N = normalize(cross(abs(pr.z) < abs(pl.z) ? pr : pl, abs(pu.z) < abs(pd.z) ? pu : pd));
	if (dot(N, -P) < 0.0) N = -N;
	float rpx = min(max_px, radius * pm[1][1] * 0.5 * vsize.y / dist), r2 = radius * radius, sum = 0.0;
	float phi = 6.2831853 * fract(52.9829189 * fract(dot(fc, vec2(0.06711056, 0.00583715))));
	for (int i = 0; i < 12; i++) {
		float a = (float(i) + 0.5) / 12.0, ang = a * 6.2831853 * 7.0 + phi;
		vec2 uv = suv + vec2(cos(ang), sin(ang)) * (a * rpx) * tx;
		if (texture(depth_tex, uv).r <= 0.000001) continue;
		vec3 v = vpos(uv, ipm) - P; float vv = dot(v, v), vn = dot(v, N);
		float f = max(r2 - vv, 0.0);
		sum += f * f * f * max((vn - bias) / (0.01 + vv), 0.0);
	}
	float A = max(0.0, 1.0 - sum * intensity / pow(radius, 6.0) * (5.0 / 12.0));
	return vec2(mix(1.0, A, smoothstep(max_dist, max_dist * 0.6, dist)), dist);
}
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
	vec2 o = occl(SCREEN_UV, VIEWPORT_SIZE, FRAGCOORD.xy, INV_PROJECTION_MATRIX, PROJECTION_MATRIX);
	// the occlusion in red, the distance (to 500 m) in green and blue; sent so that the bytes come back as these
	float d = clamp(o.y / 500.0, 0.0, 0.99998); float hi = floor(d * 255.0) / 255.0;
	vec3 enc = vec3(o.x, hi, (d - hi) * 255.0);
	ALBEDO = albedo_of(pow((clamp(enc, 0.0, 1.0) + 0.055) / 1.055, vec3(2.4))); ALPHA = 1.0;
}
"""

func setup() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS; msaa_3d = Viewport.MSAA_DISABLED; debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	transparent_bg = false; positional_shadow_atlas_size = 0
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_exposure = 1.0
	cam = Camera3D.new(); cam.cull_mask = SOLID | (1 << (LAYER - 1)); cam.environment = env; add_child(cam); cam.current = true
	mat = ShaderMaterial.new(); var sh := Shader.new(); sh.code = SHADER % Gfx.ALBEDO_GLSL; mat.shader = sh
	var q := QuadMesh.new(); q.size = Vector2(2, 2)
	_quad = MeshInstance3D.new(); _quad.mesh = q; _quad.material_override = mat; _quad.layers = 1 << (LAYER - 1)
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _quad.extra_cull_margin = 16384.0; cam.add_child(_quad); _quad.position = Vector3(0, 0, -1)

## follow the main camera, at half the window's size, as the browser game's half-size depth pass
func follow(main_cam: Camera3D, window: Vector2i) -> void:
	var s := Vector2i(maxi(1, window.x / 2), maxi(1, window.y / 2))
	if size != s: size = s
	cam.global_transform = main_cam.global_transform; cam.fov = main_cam.fov; cam.near = main_cam.near; cam.far = main_cam.far; cam.keep_aspect = main_cam.keep_aspect

## the browser game's Post.tune for the occlusion: daylight and the white lab reach a little further and press less
func tune(style: Dictionary) -> float:
	var day: bool = style.get("day", false) or style.get("lab", false)
	mat.set_shader_parameter("radius", 1.0 if day else 0.85); mat.set_shader_parameter("intensity", 1.2 if day else 1.3)
	return 0.85 if day else 0.9   # how strongly it is multiplied in

## the layer that lays it over the main picture: blurred along depth (as the browser game's two seven-tap passes, here a
## five-by-five) and multiplied into the finished colours
const APPLY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D ao_tex : filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 ao_texel; uniform float strength = 0.9; uniform float flip = 0.0; uniform float exposure = 1.0;   // (screen to screen: the same way up)
uniform float near_skip = 0.9;
%s
const float FA = 0.0245786; const float FB = 0.000090537; const float FC = 0.983729; const float FD = 0.432951; const float FE = 0.238081;
const mat3 RRT = mat3(vec3(0.59719 * 1.8, 0.35458 * 1.8, 0.04823 * 1.8), vec3(0.07600 * 1.8, 0.90834 * 1.8, 0.01566 * 1.8), vec3(0.02840 * 1.8, 0.13383 * 1.8, 0.83777 * 1.8));
const mat3 ODT = mat3(vec3(1.60475, -0.53108, -0.07367), vec3(-0.10208, 1.10813, -0.00605), vec3(-0.00327, -0.07276, 1.07602));
vec3 unshow(vec3 s) {
	vec3 t = pow((max(s, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)) * inverse(ODT);
	t = min(t, vec3(1.0));
	vec3 a = FC * t - 1.0, b = FD * t - FA, c = FE * t + FB;
	vec3 v = (-b - sqrt(max(b * b - 4.0 * a * c, vec3(0.0)))) / (2.0 * a);
	return max(v * inverse(RRT), vec3(0.0)) / exposure;
}
float dist_of(vec3 e) { return (e.g + e.b / 255.0) * 500.0; }
float apply(vec2 suv, mat4 ipm) {
	float d0 = texture(depth_tex, suv).r;
	if (d0 <= 0.000001) return 1.0;
	vec4 v = ipm * vec4(suv * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
	if (-v.z / v.w < near_skip) return 1.0;   // the gun in hand: drawn after the occlusion in the browser game
	vec2 uv = vec2(suv.x, mix(suv.y, 1.0 - suv.y, flip));
	vec3 c0 = texture(ao_tex, uv).rgb; float zc = dist_of(c0);
	float sum = 0.0, ws = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec3 c = texture(ao_tex, uv + vec2(float(i), float(j)) * ao_texel).rgb;
			float w = exp(-float(i * i + j * j) / 8.0) * max(0.0, 1.0 - abs(dist_of(c) - zc) / (0.04 * zc + 0.08));
			sum += c.r * w; ws += w;
		}
	}
	return mix(1.0, ws > 0.0 ? sum / ws : 1.0, strength);
}
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
	float m = apply(SCREEN_UV, INV_PROJECTION_MATRIX);
	if (m >= 0.999) discard;
	ALBEDO = albedo_of(unshow(vec3(m))); ALPHA = 1.0;   // tone mapped on the way out, it comes to m itself: the multiplier
}
"""
