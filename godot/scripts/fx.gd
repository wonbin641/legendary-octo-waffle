class_name Fx
extends Node3D
## Effects, kept plain for now: tracers, explosions and a puff of chips where a crate breaks.

var _tracers: Array = []
var _booms: Array = []
var _flames: Array = []
var _bits: Array = []
var _lights: Array = []
var _tmat: StandardMaterial3D
var _bmat: StandardMaterial3D

func _ready() -> void:
	_tmat = Gfx.unlit(Color(1.0, 0.85, 0.6), false); _tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bmat = Gfx.unlit(Color(1.0, 0.62, 0.25), false); _bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func tracer(from: Vector3, to: Vector3) -> void:
	var l := from.distance_to(to)
	if l < 0.5: return
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.015, 0.015, l); m.mesh = b; m.material_override = _tmat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(m)
	m.look_at_from_position((from + to) / 2, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_tracers.push_back([m, 0.05])

func explode(at: Vector3, big := true) -> void:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.radial_segments = 12; s.rings = 8; m.mesh = s
	m.material_override = _bmat.duplicate(); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.position = at; add_child(m)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.7, 0.4); l.light_energy = 8.0; l.omni_range = 16.0; m.add_child(l)
	_booms.push_back([m, 0.0, 0.4, 3.2 if big else 1.2, l])

## a lick of flame from a spray can: a small bright ball that runs out along the jet and fades
func flame(from: Vector3, dir: Vector3) -> void:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.radial_segments = 8; s.rings = 5; m.mesh = s
	var mat: StandardMaterial3D = _bmat.duplicate(); mat.albedo_color = Color(1.0, randf_range(0.45, 0.8), 0.15); m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.position = from; add_child(m)
	_flames.push_back([m, 0.0, dir * randf_range(18.0, 24.0) + Vector3(randf_range(-1, 1), randf_range(-0.5, 1.5), randf_range(-1, 1))])

# ---- small things that fly and fade: [node, age, life, velocity, size at start, size at end, gravity, alpha at start] ----
func _bit(at: Vector3, color: Color, life: float, vel: Vector3, s0: float, s1: float, grav := 0.0, glow := true) -> void:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.radial_segments = 8; s.rings = 4; m.mesh = s
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = color; mat.disable_fog = true
	if glow: mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.position = at; m.scale = Vector3.ONE * s0; add_child(m)
	_bits.push_back([m, 0.0, life, vel, s0, s1, grav, color.a])

## a streak from the muzzle to where the shot went: a foam dart, a jet of water, a band, a tack
func streak(from: Vector3, to: Vector3, color: Color, width: float, life: float) -> void:
	var l := from.distance_to(to)
	if l < 0.3: return
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(width, width, l); m.mesh = b
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = color; m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(m)
	m.look_at_from_position((from + to) / 2, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_tracers.push_back([m, life])

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

func chips(at: Vector3) -> void:
	explode(at, false)

func update(dt: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i][1] -= dt
		if _tracers[i][1] <= 0.0: _tracers[i][0].queue_free(); _tracers.remove_at(i)
	for i in range(_bits.size() - 1, -1, -1):
		var b: Array = _bits[i]; b[1] += dt; var u: float = b[1] / b[2]
		if u >= 1.0: b[0].queue_free(); _bits.remove_at(i); continue
		b[3] = (b[3] as Vector3) + Vector3(0, -b[6] * dt, 0); var n: MeshInstance3D = b[0]
		n.position += (b[3] as Vector3) * dt; n.scale = Vector3.ONE * lerpf(b[4], b[5], u); (n.material_override as StandardMaterial3D).albedo_color.a = b[7] * (1.0 - u)
	for i in range(_lights.size() - 1, -1, -1):
		_lights[i][1] -= dt; (_lights[i][0] as OmniLight3D).light_energy = 6.0 * maxf(0.0, _lights[i][1] / 0.3)
		if _lights[i][1] <= 0.0: _lights[i][0].queue_free(); _lights.remove_at(i)
	for i in range(_flames.size() - 1, -1, -1):
		var f: Array = _flames[i]; f[1] += dt; var u: float = f[1] / 0.38
		if u >= 1.0: f[0].queue_free(); _flames.remove_at(i); continue
		(f[0] as MeshInstance3D).position += (f[2] as Vector3) * dt * (1.0 - u * 0.6); (f[0] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.06, 0.55, u)
		((f[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 1.0 - u
	for i in range(_booms.size() - 1, -1, -1):
		var b: Array = _booms[i]; b[1] += dt; var u: float = b[1] / b[2]
		if u >= 1.0: b[0].queue_free(); _booms.remove_at(i); continue
		(b[0] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.3, b[3], 1.0 - (1.0 - u) * (1.0 - u))
		((b[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 1.0 - u
		(b[4] as OmniLight3D).light_energy = 8.0 * (1.0 - u)

func clear() -> void:
	for t in _tracers: t[0].queue_free()
	for b in _booms: b[0].queue_free()
	for f in _flames: f[0].queue_free()
	for b in _bits: b[0].queue_free()
	for l in _lights: l[0].queue_free()
	_bits.clear(); _lights.clear()
	_tracers.clear(); _booms.clear(); _flames.clear()
