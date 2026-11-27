class_name Grade
extends CanvasLayer
## The browser game's finishing pass on a computer (src/03b_gfx.js Post), worked as it works it: from the 3D picture
## (Picture) the bright parts are picked (a soft knee), blurred down five halvings and added back up, one picture each
## (each drawn after the one it reads, so all in the same frame), then over the picture: the bloom, a touch more
## saturation, a vignette and a little dither, at the picture's own size, and shown on the window over the bare picture.
## Phones and the two lowest quality levels go without, as there.

const BRIGHT := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform vec2 texel; uniform float threshold = 0.76; uniform float knee = 0.14;
vec3 tap(vec2 uv, vec2 o) { return texture(tex, uv + o * texel).rgb; }
void fragment() {
	vec3 c = (tap(UV, vec2(-1.0, -1.0)) + tap(UV, vec2(1.0, -1.0)) + tap(UV, vec2(-1.0, 1.0)) + tap(UV, vec2(1.0, 1.0))) * 0.25;
	float br = max(c.r, max(c.g, c.b));
	float s = clamp(br - threshold + knee, 0.0, 2.0 * knee); s = s * s / (4.0 * knee + 1e-4);
	COLOR = vec4(c * max(s, br - threshold) / max(br, 1e-4), 1.0);
}
"""
const DOWN := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform vec2 texel;
void fragment() {
	vec3 s = texture(tex, UV).rgb * 4.0;
	s += texture(tex, UV - texel).rgb + texture(tex, UV + texel).rgb;
	s += texture(tex, UV + vec2(texel.x, -texel.y)).rgb + texture(tex, UV + vec2(-texel.x, texel.y)).rgb;
	COLOR = vec4(s * 0.125, 1.0);
}
"""
## the way back up: the smaller picture spread over this one's texels and added to what this level already holds (the
## browser game draws it with additive blending into the same picture)
const UP := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform sampler2D base : filter_linear, repeat_disable;
uniform vec2 texel;
void fragment() {
	vec3 s = texture(tex, UV + vec2(-2.0 * texel.x, 0.0)).rgb + texture(tex, UV + vec2(2.0 * texel.x, 0.0)).rgb
	       + texture(tex, UV + vec2(0.0, -2.0 * texel.y)).rgb + texture(tex, UV + vec2(0.0, 2.0 * texel.y)).rgb;
	s += (texture(tex, UV - texel).rgb + texture(tex, UV + texel).rgb
	    + texture(tex, UV + vec2(texel.x, -texel.y)).rgb + texture(tex, UV + vec2(-texel.x, texel.y)).rgb) * 2.0;
	COLOR = vec4(texture(base, UV).rgb + s / 12.0, 1.0);
}
"""
const FINAL := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : filter_linear, repeat_disable;
uniform sampler2D bloom : filter_linear, repeat_disable;
uniform float strength = 0.55; uniform float vig = 0.6; uniform float sat = 1.07;
void fragment() {
	vec3 c = texture(scene, UV).rgb + texture(bloom, UV).rgb * strength;
	float l = dot(c, vec3(0.299, 0.587, 0.114)); c = mix(vec3(l), c, sat);
	vec2 q = UV - 0.5; c *= clamp(1.0 - dot(q, q) * vig, 0.0, 1.0);
	c += (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
	COLOR = vec4(c, 1.0);
}
"""
const N_MIP := 5

var source: SubViewport = null   # the 3D picture (Picture.scene_vp)
var mips: Array[SubViewport] = []   # the bright pass, then four halvings
var ups: Array[SubViewport] = []    # back up: ups[i] is level i with everything below added in (ups[0] is the bloom)
var final_vp: SubViewport
var mat_bright: ShaderMaterial; var mat_final: ShaderMaterial
var _mats_down: Array[ShaderMaterial] = []; var _mats_up: Array[ShaderMaterial] = []
var show: TextureRect
var _size := Vector2i.ZERO

var allowed := true   # phones go without (main sets this)
var level_post := true   # the computer's quality ladder runs it from level 2 up (main sets this)

func _ready() -> void:
	layer = -1   # over the bare 3D picture, under every screen and the HUD
	visibility_changed.connect(_on_visible)

func _pass(code: String, src: Texture2D) -> Array:
	var vp := SubViewport.new(); vp.disable_3d = true; vp.transparent_bg = false; vp.size = Vector2i(2, 2)
	var m := ShaderMaterial.new(); var sh := Shader.new(); sh.code = code; m.shader = sh
	if src != null: m.set_shader_parameter("tex", src)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.material = m; vp.add_child(r); add_child(vp)
	return [vp, m]

## the passes, each made after the one it reads (so it is drawn after it): bright, four downs, four ups, the final
func attach(src: SubViewport) -> void:
	source = src
	var q := _pass(BRIGHT, src.get_texture()); mips.push_back(q[0]); mat_bright = q[1]
	for i in range(1, N_MIP):
		q = _pass(DOWN, mips[i - 1].get_texture()); mips.push_back(q[0]); _mats_down.push_back(q[1])
	ups.resize(N_MIP); ups[N_MIP - 1] = mips[N_MIP - 1]
	_mats_up.resize(N_MIP)
	for i in range(N_MIP - 1, 0, -1):   # level i-1 gets level i (already brought up) added in
		q = _pass(UP, ups[i].get_texture()); (q[1] as ShaderMaterial).set_shader_parameter("base", mips[i - 1].get_texture())
		ups[i - 1] = q[0]; _mats_up[i - 1] = q[1]
	q = _pass(FINAL, null); final_vp = q[0]; mat_final = q[1]
	mat_final.set_shader_parameter("scene", src.get_texture()); mat_final.set_shader_parameter("bloom", ups[0].get_texture())
	show = TextureRect.new(); show.set_anchors_preset(Control.PRESET_FULL_RECT); show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; show.stretch_mode = TextureRect.STRETCH_SCALE; show.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	show.texture = final_vp.get_texture(); add_child(show)
	RenderingServer.frame_pre_draw.connect(_sync); _on_visible()

func _exit_tree() -> void:   # (the server's signal outlives this node: let go of it)
	if RenderingServer.frame_pre_draw.is_connected(_sync): RenderingServer.frame_pre_draw.disconnect(_sync)

## the browser game's Post size(): the bright pass at half the picture's size, each next level half that
func _sync() -> void:
	if source == null or not visible: return
	var w := source.size
	if w == _size: return
	_size = w; final_vp.size = w
	mat_bright.set_shader_parameter("texel", Vector2(1.0 / w.x, 1.0 / w.y))
	var m := w
	for i in N_MIP:
		m = Vector2i(maxi(1, m.x >> 1), maxi(1, m.y >> 1)); mips[i].size = m
		if i > 0: ups[i - 1].size = mips[i - 1].size
	for i in range(1, N_MIP): _mats_down[i - 1].set_shader_parameter("texel", Vector2(1.0 / mips[i - 1].size.x, 1.0 / mips[i - 1].size.y))
	for i in range(1, N_MIP): _mats_up[i - 1].set_shader_parameter("texel", Vector2(0.5 / mips[i].size.x, 0.5 / mips[i].size.y))

## off, the passes stop too
func _on_visible() -> void:
	var mode := SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	for vp: SubViewport in mips + ups + ([final_vp] if final_vp else []):
		if vp != null: vp.render_target_update_mode = mode
	if visible: _size = Vector2i.ZERO; _sync()

## the browser game's Post.tune: daylight and the white lab bloom less and darken the corners less. Stage 5, this port's
## own room, keeps the light it was made with: no finishing pass
func tune(style: Dictionary) -> void:
	visible = allowed and level_post and not style.get("toy", false)
	var day: bool = style.get("day", false) or style.get("lab", false)
	if mat_bright:
		mat_bright.set_shader_parameter("threshold", 0.9 if day else 0.76); mat_bright.set_shader_parameter("knee", 0.08 if day else 0.14)
	if mat_final:
		mat_final.set_shader_parameter("strength", 0.3 if day else 0.55); mat_final.set_shader_parameter("vig", 0.4 if day else 0.6)
		mat_final.set_shader_parameter("sat", 1.04 if day else 1.07)
	_tuned = {"threshold": 0.9 if day else 0.76, "knee": 0.08 if day else 0.14, "strength": 0.3 if day else 0.55, "vig": 0.4 if day else 0.6, "sat": 1.04 if day else 1.07}
var _tuned := {}
