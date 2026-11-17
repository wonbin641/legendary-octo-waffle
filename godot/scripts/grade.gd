class_name Grade
extends CanvasLayer
## The browser game's finishing pass on a computer (src/03b_gfx.js Post): over the finished picture, the bright parts
## bloomed back in, a touch more saturation, a vignette and a little dither. Phones draw without it, as there.
## The browser game blurs its bright pass down five halvings and adds them back up; here the screen's own mipmaps stand
## in for those halvings, so the bright pass is taken after each blur rather than before it (a small light glows less).

const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float threshold = 0.76;
uniform float knee = 0.14;
uniform float strength = 0.55;
uniform float vig = 0.6;
uniform float sat = 1.07;
vec3 bright(vec3 c) {
	float br = max(c.r, max(c.g, c.b));
	float s = clamp(br - threshold + knee, 0.0, 2.0 * knee); s = s * s / (4.0 * knee + 1e-4);
	return c * max(s, br - threshold) / max(br, 1e-4);
}
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb;
	vec3 b = vec3(0.0);
	for (int k = 1; k <= 5; k++) b += bright(textureLod(screen, SCREEN_UV, float(k)).rgb);
	c += b * strength;
	float l = dot(c, vec3(0.299, 0.587, 0.114)); c = mix(vec3(l), c, sat);
	vec2 q = SCREEN_UV - 0.5; c *= clamp(1.0 - dot(q, q) * vig, 0.0, 1.0);
	c += (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
	COLOR = vec4(c, 1.0);
}
"""

var mat: ShaderMaterial
var rect: ColorRect

func _ready() -> void:
	layer = -1   # over the 3D picture, under every screen and the HUD
	mat = ShaderMaterial.new(); var sh := Shader.new(); sh.code = SHADER; mat.shader = sh
	rect = ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; rect.material = mat
	add_child(rect)

var allowed := true   # phones go without (main sets this)
var level_post := true   # the computer's quality ladder runs it from level 2 up (main sets this)

## the browser game's Post.tune: daylight and the white lab bloom less and darken the corners less. Stage 5, this port's
## own room, keeps the light it was made with: no finishing pass
func tune(style: Dictionary) -> void:
	visible = allowed and level_post and not style.get("toy", false)
	var day: bool = style.get("day", false) or style.get("lab", false)
	mat.set_shader_parameter("threshold", 0.9 if day else 0.76); mat.set_shader_parameter("knee", 0.08 if day else 0.14)
	mat.set_shader_parameter("strength", 0.3 if day else 0.55); mat.set_shader_parameter("vig", 0.4 if day else 0.6)
	mat.set_shader_parameter("sat", 1.04 if day else 1.07)
