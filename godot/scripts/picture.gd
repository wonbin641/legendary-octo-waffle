class_name Picture
extends CanvasLayer
## The 3D picture. The browser game draws its world into a picture of its own (a four times multisampled render target
## on a computer), works its finishing pass from that picture, and only then shows it on the page. So here the world is
## drawn into this SubViewport (sharing the window's world, by a camera that follows the main one right before each
## frame is drawn), at the size the quality ladder asks (its pixel ratio of the page), and shown under everything on the
## window, smoothly enlarged as a browser enlarges its canvas. The finishing pass (Grade) reads the same picture.
## The window itself draws no 3D: the occlusion and the moon's shadow pictures, made before this one, feed it.

var scene_vp: SubViewport
var scene_cam: Camera3D
var follow: Camera3D           # the main camera
var share := 1.0               # the picture's size as a share of the window's (pixel ratio over the screen's)
const MAX_W := 3840.0          # a picture drawn finer than the window (the computer's top levels) is at most this wide
var show: TextureRect

func _ready() -> void:
	layer = -2   # under the finishing pass (-1) and every screen
	scene_vp = SubViewport.new(); scene_vp.name = "Scene"; scene_vp.own_world_3d = false; scene_vp.transparent_bg = false
	scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; scene_vp.size = Vector2i(2, 2)
	scene_vp.world_3d = get_viewport().find_world_3d()
	scene_cam = Camera3D.new(); scene_cam.name = "Camera"; scene_vp.add_child(scene_cam); add_child(scene_vp)
	scene_cam.current = true
	show = TextureRect.new(); show.set_anchors_preset(Control.PRESET_FULL_RECT); show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; show.stretch_mode = TextureRect.STRETCH_SCALE; show.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	show.texture = scene_vp.get_texture(); add_child(show)
	RenderingServer.frame_pre_draw.connect(_sync)

## multisampling: four times on a computer, none on a phone (the browser game's antialias: !isTouch)
func set_msaa(m: Viewport.MSAA) -> void:
	scene_vp.msaa_3d = m

## a share above 1 (finer than the window) only as far as MAX_W pixels wide, and never below the window's own size for it
static func fine_share(s: float, width: float) -> float:
	return minf(s, maxf(1.0, MAX_W / maxf(width, 1.0))) if s > 1.0 else s
## the picture's size in pixels
func render_size() -> Vector2i:
	return scene_vp.size

## right before the frame is drawn: the camera where the main one is (after everything has moved it), the size the window
## and the ladder ask
func _sync() -> void:
	if follow == null or not is_instance_valid(follow): return
	var win := Vector2(get_viewport().size); var s := fine_share(share, win.x)
	var want := Vector2i(maxi(1, roundi(win.x * s)), maxi(1, roundi(win.y * s)))
	if scene_vp.size != want: scene_vp.size = want
	scene_cam.global_transform = follow.global_transform; scene_cam.fov = follow.fov; scene_cam.near = follow.near; scene_cam.far = follow.far
	scene_cam.cull_mask = follow.cull_mask; scene_cam.keep_aspect = follow.keep_aspect; scene_cam.projection = follow.projection
	scene_cam.h_offset = follow.h_offset; scene_cam.v_offset = follow.v_offset; scene_cam.environment = follow.environment; scene_cam.attributes = follow.attributes
