class_name Fx
extends Node3D
## Effects, as src/05_fx.js has them: tracers, the two particle pools (glow and smoke) that sparks, dust, smoke and fire
## are made of, explosions, debris, bullet holes; and the toy room's own bits (Godot only: water, foam taps, caps, bottle rockets).

var _tracers: Array = []
var _flames: Array = []
var _lights: Array = []
var _tmat: StandardMaterial3D; var _tmat_s: Material   # (the tracers' material, and as Forward+ draws it: Gfx.see_through)
var _bmat: StandardMaterial3D
var _glow: Pool
var _smoke: Pool
var _boom: OmniLight3D   # one light for every blast, moved to the newest (the browser game's boomLight)
var _boom_t := 0.0
const BOOM_COL := [1.0, 0.55, 0.2]

func _ready() -> void:
	_tmat = Gfx.unlit(World.lin(Color(1.0, 0.85, 0.6)), false); _tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bmat = Gfx.unlit(World.lin(Color(1.0, 0.62, 0.25)), false); _bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tmat_s = Gfx.see_through(_tmat)
	var dot := _dot_tex()
	_glow = Pool.new(900, true, dot); add_child(_glow.node)
	_smoke = Pool.new(260, false, dot); add_child(_smoke.node)
	_boom = OmniLight3D.new(); _boom.light_color = World.lin("ff8a3a"); _boom.omni_range = 16.0; _boom.light_energy = 0.0; _boom.visible = false; add_child(_boom)

# ---- the two particle pools (makeSystem): soft round specks that always face the camera; "glow" is added on top (sparks,
# fire, flashes), "smoke" is laid over (dust, smoke). A full pool gives the oldest place to the newest. Each pool is one mesh
# made again every frame from the specks in flight, so however many fly it costs one draw. (A MultiMesh changed in place
# does not always reach the screen on the web renderer; a mesh made afresh always does.) Sizes are widths in metres. ----
class Pool:
	var cap: int
	var mesh := ArrayMesh.new()
	var node := MeshInstance3D.new()
	var p: Array = []   # specks in flight: [life left, life, position, velocity, size at start, size at end, colour, gravity, drag]
	var cursor := 0
	var shown := 0
	var _vx := PackedVector3Array(); var _col := PackedColorArray(); var _uv := PackedVector2Array(); var _idx := PackedInt32Array()

	func _init(n: int, add: bool, tex: Texture2D) -> void:
		cap = n
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX; mat.albedo_texture = tex
		mat.vertex_color_use_as_albedo = true; mat.vertex_color_is_srgb = true; mat.disable_fog = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		node.mesh = mesh; node.material_override = Gfx.see_through(mat); node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))   # never culled, as frustumCulled = false
		_vx.resize(n * 4); _col.resize(n * 4); _uv.resize(n * 4); _idx.resize(n * 6)
		for i in n:
			var o := i * 4
			_uv[o] = Vector2(0, 0); _uv[o + 1] = Vector2(1, 0); _uv[o + 2] = Vector2(1, 1); _uv[o + 3] = Vector2(0, 1)
			_idx[i * 6] = o; _idx[i * 6 + 1] = o + 1; _idx[i * 6 + 2] = o + 2; _idx[i * 6 + 3] = o; _idx[i * 6 + 4] = o + 2; _idx[i * 6 + 5] = o + 3

	func emit(at: Vector3, vel: Vector3, life: float, s0: float, s1: float, col: Color, grav: float, drag: float, raw := false) -> void:
		if not raw: col = Fx.shown(col)
		var s := [life, life, at, vel, s0, s1, col, grav, drag]
		if p.size() < cap: p.push_back(s)
		else: p[cursor] = s; cursor = (cursor + 1) % cap

	## move every speck (gravity, drag, a bounce off the floor), then lay them all out facing the camera (basis b)
	func step(dt: float, b: Basis) -> void:
		var i := 0; var n := 0; var rx := b.x * 0.5; var uy := b.y * 0.5
		while i < p.size():
			var s: Array = p[i]; s[0] -= dt
			if s[0] <= 0.0: p[i] = p[p.size() - 1]; p.pop_back(); continue
			var k: float = 1.0 - s[0] / s[1]
			var v: Vector3 = s[3]; v.y -= s[7] * dt; v *= exp(-s[8] * dt)
			var q: Vector3 = s[2] + v * dt
			var fy := 0.0 if Phys.PIT == null else Phys.floor_y(q.x, q.z)
			if q.y < fy + 0.02: q.y = fy + 0.02; v.y *= -0.35; v.x *= 0.6; v.z *= 0.6
			s[2] = q; s[3] = v
			var c: Color = s[6]; var z: float = lerpf(s[4], s[5], k); var r := rx * z; var u := uy * z; var o := n * 4
			_vx[o] = q - r - u; _vx[o + 1] = q + r - u; _vx[o + 2] = q + r + u; _vx[o + 3] = q - r + u
			var cc := Color(c.r, c.g, c.b, c.a * (1.0 - k * k)); _col[o] = cc; _col[o + 1] = cc; _col[o + 2] = cc; _col[o + 3] = cc
			n += 1; i += 1
		if n > 0 or shown > 0:
			mesh.clear_surfaces()
			if n > 0:
				var arr := []; arr.resize(Mesh.ARRAY_MAX)
				arr[Mesh.ARRAY_VERTEX] = _vx.slice(0, n * 4); arr[Mesh.ARRAY_COLOR] = _col.slice(0, n * 4); arr[Mesh.ARRAY_TEX_UV] = _uv.slice(0, n * 4); arr[Mesh.ARRAY_INDEX] = _idx.slice(0, n * 6)
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		shown = n

	func reset() -> void:
		p.clear(); cursor = 0; shown = 0; mesh.clear_surfaces()

## the soft round speck: white, its edge fading out as smoothstep(0.5, 0.05, distance from the middle)
static func _dot_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64: img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.5, 0.05, Vector2((x + 0.5) / 64.0 - 0.5, (y + 0.5) / 64.0 - 0.5).length())))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## one speck of light (FX.glow.emit): where, how fast, how long, width at start and end, colour with alpha, gravity, drag
## the browser game's specks are drawn by a shader of its own that writes their colour straight to the screen, with no tone
## mapping: here every material is tone mapped, so a speck gets the colour that tone maps to the one asked for
## (stage 5's own bits keep theirs). Cached per colour; the stage's exposure is set by World
static var exposure := 1.15
static var _shown := {}
static func shown(c: Color) -> Color:
	var k := Vector4(c.r, c.g, c.b, exposure)
	if not _shown.has(k):
		var t := Vector3(minf(c.r, 0.97), minf(c.g, 0.97), minf(c.b, 0.97))   # tone mapping never quite reaches white
		var a := Gfx.albedo_of(Gfx.scene_for(t, exposure)); _shown[k] = Color(a.x, a.y, a.z)
	var r: Color = _shown[k]
	return Color(r.r, r.g, r.b, c.a)

func glow(at: Vector3, vel: Vector3, life: float, s0: float, s1: float, col: Color, grav := 0.0, drag := 0.0) -> void:
	_glow.emit(at, vel, life, s0, s1, col, grav, drag)

## specks in flight in both pools
func live() -> int:
	return _glow.p.size() + _smoke.p.size()

func tracer(from: Vector3, to: Vector3) -> void:
	var l := from.distance_to(to)
	if l < 0.5: return
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.024, 0.024, l); m.mesh = b; m.material_override = _tmat_s
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.transparency = 0.1; add_child(m)
	m.look_at_from_position((from + to) / 2, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_tracers.push_back([m, 0.06, 0.06])

## FX.explode: sparks flung out (colour as [r, g, b]), a ball of fire, dark smoke, and a flash of light
func explode(at: Vector3, big := true, col: Array = BOOM_COL) -> void:
	var sc := Color(col[0], col[1], col[2], 1.0)
	for i in (70 if big else 40):
		var a := randf() * TAU; var e := randf_range(-0.4, 1.2); var s := randf_range(2.0, 11.0 if big else 8.0)
		_glow.emit(at, Vector3(cos(a) * cos(e) * s, sin(e) * s, sin(a) * cos(e) * s), randf_range(0.3, 0.8), randf_range(0.08, 0.2), 0.02, sc, 8.0, 1.8)
	for i in (14 if big else 8):
		_glow.emit(at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), Vector3(randf_range(-1, 1), randf_range(0, 1.5), randf_range(-1, 1)),
			randf_range(0.25, 0.45), 1.6 if big else 1.0, 3.2 if big else 2.0, Color(1, 0.6, 0.25, 0.55), 0.0, 2.0)
	puff(at, 16 if big else 9, 0.12, 1.4 if big else 0.9)
	_boom.position = at + Vector3(0, 0.5, 0); _boom.light_energy = 8.0 if big else 5.2; _boom.visible = true; _boom_t = 0.35

## a lick of flame from a spray can: a small bright ball that runs out along the jet and fades
## the spray can's fire: a ball of flame thrown out along a shot, slowing and swelling as it goes, gone after FLAME_LIFE s,
## by when it has gone about as far as the fire burns (reach): it travels 0.7 of its first speed times its life
const FLAME_LIFE := 0.55
static var _flame_mesh: SphereMesh = null
func flame(from: Vector3, dir: Vector3, reach := 9.5) -> void:
	if _flame_mesh == null: _flame_mesh = SphereMesh.new(); _flame_mesh.radius = 1.0; _flame_mesh.height = 2.0; _flame_mesh.radial_segments = 8; _flame_mesh.rings = 5
	var m := MeshInstance3D.new(); m.mesh = _flame_mesh
	var mat: StandardMaterial3D = _bmat.duplicate(); mat.albedo_color = World.lin(Color(1.0, randf_range(0.45, 0.8), 0.15)); m.material_override = Gfx.see_through(mat); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.position = from; add_child(m)
	var v := reach / (0.7 * FLAME_LIFE)
	_flames.push_back([m, 0.0, dir * v * randf_range(0.85, 1.05) + Vector3(randf_range(-1, 1), randf_range(-0.5, 1.5), randf_range(-1, 1)), 0.35 + reach * 0.05])

# the toy room's bits go into the same pools; their sizes are radii (a speck as wide as twice that)
func _bit(at: Vector3, color: Color, life: float, vel: Vector3, s0: float, s1: float, grav := 0.0, add := true, drag := 0.0) -> void:
	(_glow if add else _smoke).emit(at, vel, life, s0 * 2.0, s1 * 2.0, color, grav, drag, true)

## a streak from the muzzle to where the shot went: a foam dart, a jet of water, a band, a tack
func streak(from: Vector3, to: Vector3, color: Color, width: float, life: float) -> void:
	var l := from.distance_to(to)
	if l < 0.3: return
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(width, width, l); m.mesh = b
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = color; m.material_override = Gfx.see_through(mat)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(m)
	m.look_at_from_position((from + to) / 2, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_tracers.push_back([m, life, 0.0])

## water hitting something: drops fly up and fall
func splash(at: Vector3) -> void:
	for i in 5: _bit(at, Color(0.45, 0.72, 1.0, 0.8), 0.45, Vector3(randf_range(-2, 2), randf_range(1.5, 4), randf_range(-2, 2)), 0.07, 0.03, 12.0, false)

## a soft bounce where a foam dart or a tack lands
func tap(at: Vector3, color: Color) -> void:
	_bit(at, color, 0.18, Vector3.ZERO, 0.04, 0.16, 0.0, false)

## the thin white smoke of a cap going off
func smoke(at: Vector3) -> void:
	for i in 2: _bit(at, Color(0.95, 0.95, 0.95, 0.45), 0.7, Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 0.9), randf_range(-0.2, 0.2)), 0.02, 0.11, 0.0, false)

## a spark off a burning fuse or a rocket's tail
func spark(at: Vector3) -> void:
	_bit(at, Color(1.0, randf_range(0.6, 0.9), 0.3, 1.0), 0.3, Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)), 0.05, 0.01, 4.0)

## a bottle rocket going off: a pop of coloured stars
func firework(at: Vector3) -> void:
	var cols := [Color(1, 0.3, 0.35), Color(1, 0.85, 0.3), Color(0.4, 0.8, 1), Color(0.5, 1, 0.6), Color(1, 0.5, 0.9)]
	_bit(at, Color(1, 0.95, 0.8, 1), 0.2, Vector3.ZERO, 0.4, 2.6)
	for i in 26:
		var a := randf() * TAU; var e := randf_range(-0.6, 1.2); var sp := randf_range(5, 11)
		_bit(at, Color(cols[i % 5], 1.0), randf_range(0.6, 1.0), Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * sp, 0.16, 0.03, 7.0)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.8, 0.6); l.light_energy = 6.0; l.omni_range = 14.0; l.position = at; add_child(l); _lights.push_back([l, 0.3])

## sparks (FX.sparks): bright specks thrown out, falling and slowing; colour as [r, g, b]
func sparks(p: Vector3, n: int, col: Array, speed: float) -> void:
	var c := Color(col[0], col[1], col[2], 1.0)
	for i in n:
		_glow.emit(p, Vector3(randf_range(-1, 1) * speed, randf_range(-0.3, 1.2) * speed, randf_range(-1, 1) * speed), randf_range(0.18, 0.45), randf_range(0.05, 0.1), 0.01, c, 9.0, 2.5)

## debris (FX.chunks): splinters of wood or bits of metal that fly, bounce on the ground, tumble and shrink away
var _debris: Array = []
var _wood_mat: StandardMaterial3D; var _metal_mat: StandardMaterial3D
func chunks(p: Vector3, n: int, size: float, kind: String) -> void:
	if _wood_mat == null:
		_wood_mat = StandardMaterial3D.new(); _wood_mat.albedo_color = World.lin("8a6238"); _wood_mat.roughness = 0.9
		_metal_mat = StandardMaterial3D.new(); _metal_mat.albedo_color = World.lin("6a7280"); _metal_mat.roughness = 0.5; _metal_mat.metallic = 0.6
	for i in n:
		if _debris.size() >= 48: var old: Array = _debris.pop_front(); (old[0] as Node3D).queue_free()
		var m := MeshInstance3D.new(); var b := BoxMesh.new(); m.mesh = b; m.material_override = _wood_mat if kind == "wood" else _metal_mat
		var s := size * randf_range(0.5, 1.2); m.scale = Vector3(s, s * randf_range(0.4, 1.0), s * randf_range(0.6, 1.4)); m.position = p + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3)); add_child(m)
		_debris.push_back([m, Vector3(randf_range(-4, 4), randf_range(3, 8), randf_range(-4, 4)), Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)), randf_range(2.5, 4.0)])

## dust or smoke (FX.puff): soft grey specks that drift up, grow and fade
func puff(p: Vector3, n: int, shade: float, size: float) -> void:
	var c := Color(shade, shade, minf(1.0, shade * 1.08), 0.5)
	for i in n:
		_smoke.emit(p + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)), Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 1.1), randf_range(-0.6, 0.6)),
			randf_range(0.6, 1.4), size * 0.5, size * randf_range(1.3, 2.0), c, -0.4, 1.5)

## bullet holes (FX.decal): 64 dark marks on what the shots struck, the oldest reused first; drawn as one mesh, made again
## when a mark is added
const HOLES := 64
var _holes: ArrayMesh
var _hole_n := 0
var hole_xf: Array = []   # where each mark lies
func decal(p: Vector3, n: Vector3) -> void:
	if _holes == null:
		_holes = ArrayMesh.new()
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = Gfx.glow_tex(Color8(8, 8, 10, 242), Color8(20, 20, 24, 153)); mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var mi := MeshInstance3D.new(); mi.mesh = _holes; mi.material_override = Gfx.see_through(mat); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000)); add_child(mi)
	var b := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.BACK, randf() * TAU)   # its face along the surface's normal, turned at random
	var xf := Transform3D(b.scaled(Vector3.ONE * randf_range(0.7, 1.3)), p + n * 0.02)
	if hole_xf.size() < HOLES: hole_xf.push_back(xf)
	else: hole_xf[_hole_n % HOLES] = xf
	_hole_n += 1
	var vx := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for i in hole_xf.size():
		var h: Transform3D = hole_xf[i]; var r := h.basis.x * 0.08; var u := h.basis.y * 0.08; var o := h.origin; var j := i * 4
		vx.append_array([o - r - u, o + r - u, o + r + u, o - r + u]); uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		idx.append_array([j, j + 2, j + 1, j, j + 3, j + 2])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vx; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_INDEX] = idx
	_holes.clear_surfaces(); _holes.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

func chips(at: Vector3) -> void:
	explode(at, false)

func update(dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cb := cam.global_transform.basis if cam != null else Basis.IDENTITY
	_glow.step(dt, cb); _smoke.step(dt, cb)
	if _boom_t > 0.0:
		_boom_t -= dt; _boom.light_energy *= exp(-dt * 9.0)
		if _boom_t <= 0.0: _boom.light_energy = 0.0; _boom.visible = false
	for i in range(_debris.size() - 1, -1, -1):
		var d: Array = _debris[i]; var m: MeshInstance3D = d[0]; d[3] -= dt
		if d[3] <= 0.0: m.queue_free(); _debris.remove_at(i); continue
		d[1] = (d[1] as Vector3) + Vector3(0, -16.0 * dt, 0); m.position += (d[1] as Vector3) * dt; m.rotation += (d[2] as Vector3) * dt
		var floor_y := m.scale.y * 0.5 + Phys.ground_at(m.position.x, m.position.y + 0.5, m.position.z, 0.05)
		if m.position.y < floor_y: m.position.y = floor_y; var v: Vector3 = d[1]; d[1] = Vector3(v.x * 0.6, -v.y * 0.3, v.z * 0.6); d[2] = (d[2] as Vector3) * 0.6
		if d[3] < 0.5: m.scale *= 1.0 - dt * 3.0
	for i in range(_tracers.size() - 1, -1, -1):
		var t: Array = _tracers[i]; t[1] -= dt
		if t[1] <= 0.0: t[0].queue_free(); _tracers.remove_at(i); continue
		if t[2] > 0.0: (t[0] as GeometryInstance3D).transparency = 1.0 - t[1] / t[2] * 0.9   # a gun's tracer fades out over its 0.06 s
	for i in range(_lights.size() - 1, -1, -1):
		_lights[i][1] -= dt; (_lights[i][0] as OmniLight3D).light_energy = 6.0 * maxf(0.0, _lights[i][1] / 0.3)
		if _lights[i][1] <= 0.0: _lights[i][0].queue_free(); _lights.remove_at(i)
	for i in range(_flames.size() - 1, -1, -1):
		var f: Array = _flames[i]; f[1] += dt; var u: float = f[1] / FLAME_LIFE
		if u >= 1.0: f[0].queue_free(); _flames.remove_at(i); continue
		(f[0] as MeshInstance3D).position += (f[2] as Vector3) * dt * (1.0 - u * 0.6); (f[0] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.06, float(f[3]), u)
		Gfx.set_alpha((f[0] as MeshInstance3D).material_override, 1.0 - u)

func clear() -> void:
	for d in _debris: (d[0] as Node3D).queue_free()
	_debris.clear()
	for t in _tracers: t[0].queue_free()
	for f in _flames: f[0].queue_free()
	for l in _lights: l[0].queue_free()
	_lights.clear(); _tracers.clear(); _flames.clear()
	_glow.reset(); _smoke.reset()
	_boom_t = 0.0; _boom.light_energy = 0.0; _boom.visible = false
	_hole_n = 0; hole_xf.clear()
	if _holes != null: _holes.clear_surfaces()
