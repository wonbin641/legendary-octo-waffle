class_name Fx
extends Node3D
## Effects, kept plain for now: tracers, explosions and a puff of chips where a crate breaks.

var _tracers: Array = []
var _booms: Array = []
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

func chips(at: Vector3) -> void:
	explode(at, false)

func update(dt: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i][1] -= dt
		if _tracers[i][1] <= 0.0: _tracers[i][0].queue_free(); _tracers.remove_at(i)
	for i in range(_booms.size() - 1, -1, -1):
		var b: Array = _booms[i]; b[1] += dt; var u: float = b[1] / b[2]
		if u >= 1.0: b[0].queue_free(); _booms.remove_at(i); continue
		(b[0] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.3, b[3], 1.0 - (1.0 - u) * (1.0 - u))
		((b[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 1.0 - u
		(b[4] as OmniLight3D).light_energy = 8.0 * (1.0 - u)

func clear() -> void:
	for t in _tracers: t[0].queue_free()
	for b in _booms: b[0].queue_free()
	_tracers.clear(); _booms.clear()
