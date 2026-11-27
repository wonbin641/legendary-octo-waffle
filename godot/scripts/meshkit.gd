class_name MeshKit
extends RefCounted
## Shapes gathered into one mesh, each corner with its own colour: boxes, upright round things (a trunk, a column, a
## tower's wall, a cone of a roof), domes, flat discs and rings, strips between two points. A whole map's worth of one
## material is then one thing to draw, where each shape as a node of its own was a draw call apiece (stage 5 taught that).
## Colours are screen colours, as Gfx.merge_boxes takes them.

var vs := PackedVector3Array(); var ns := PackedVector3Array(); var cs := PackedColorArray(); var idx := PackedInt32Array()

func is_empty() -> bool: return vs.is_empty()

## three corners as a face, turned so that it is seen from the side their normals point to (Godot shows the side from which
## the corners run clockwise)
func _tri(a: int, b: int, c: int) -> void:
	if (vs[c] - vs[a]).cross(vs[b] - vs[a]).dot(ns[a] + ns[b] + ns[c]) >= 0.0: idx.push_back(a); idx.push_back(b); idx.push_back(c)
	else: idx.push_back(a); idx.push_back(c); idx.push_back(b)
func corners() -> int: return vs.size()

## four corners in a row round a face (seen from outside: anticlockwise), one normal for all
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, nrm = null) -> void:
	var n: Vector3 = nrm if nrm != null else (b - a).cross(c - a).normalized() * -1.0
	var o := vs.size()
	vs.push_back(a); vs.push_back(b); vs.push_back(c); vs.push_back(d)
	for i in 4: ns.push_back(n); cs.push_back(col)
	_tri(o, o + 1, o + 2); _tri(o, o + 2, o + 3)

## a box of this size with its middle at (x, y, z), turned by yaw about the upright axis
func box(sx: float, sy: float, sz: float, x: float, y: float, z: float, col: Color, yaw := 0.0) -> void:
	var hx := sx * 0.5; var hy := sy * 0.5; var hz := sz * 0.5; var c := Vector3(x, y, z)
	var ax := Vector3(hx, 0, 0); var az := Vector3(0, 0, hz); var up := Vector3(0, hy, 0); var nx := Vector3.RIGHT; var nz := Vector3.BACK
	if yaw != 0.0: var b := Basis(Vector3.UP, yaw); ax = b * ax; az = b * az; nx = b * nx; nz = b * nz
	quad(c + ax - up + az, c + ax - up - az, c + ax + up - az, c + ax + up + az, col, nx)
	quad(c - ax - up - az, c - ax - up + az, c - ax + up + az, c - ax + up - az, col, -nx)
	quad(c - ax + up + az, c + ax + up + az, c + ax + up - az, c - ax + up - az, col, Vector3.UP)
	quad(c - ax - up - az, c + ax - up - az, c + ax - up + az, c - ax - up + az, col, Vector3.DOWN)
	quad(c - ax - up + az, c + ax - up + az, c + ax + up + az, c - ax + up + az, col, nz)
	quad(c + ax - up - az, c - ax - up - az, c - ax + up - az, c + ax + up - az, col, -nz)

## a box given by its corners (as the colliders are)
func slab(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color) -> void:
	box(x1 - x0, y1 - y0, z1 - z0, (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5, col)

## an upright round thing standing at (x, y0, z): radius r0 at its foot and r1 at its top (0: a cone), h tall, of so many
## sides, smooth round; its top and foot closed if asked. a0..a1: only part of the way round (a wall with a gap)
func cyl(x: float, y0: float, z: float, r0: float, r1: float, h: float, col: Color, sides := 10, top := true, foot := false, a0 := 0.0, a1 := TAU, col_top = null) -> void:
	var o := vs.size(); var slope := (r0 - r1) / maxf(h, 0.0001); var ct: Color = col_top if col_top != null else col
	for i in sides + 1:
		var a := lerpf(a0, a1, float(i) / sides); var d := Vector3(cos(a), 0.0, sin(a)); var n := Vector3(d.x, slope, d.z).normalized()
		vs.push_back(Vector3(x, y0, z) + d * r0); ns.push_back(n); cs.push_back(col)
		vs.push_back(Vector3(x, y0 + h, z) + d * r1); ns.push_back(n); cs.push_back(ct)
	for i in sides:
		var k := o + i * 2
		_tri(k, k + 1, k + 3); _tri(k, k + 3, k + 2)
	if top and r1 > 0.0: disc(x, y0 + h, z, r1, ct, sides, 0.0, a0, a1)
	if foot and r0 > 0.0: disc(x, y0, z, r0, col, sides, 0.0, a0, a1, false)

## a flat disc (or a ring, from r_in out) at height y, facing up (or down)
func disc(x: float, y: float, z: float, r: float, col: Color, sides := 16, r_in := 0.0, a0 := 0.0, a1 := TAU, up := true) -> void:
	var o := vs.size(); var n := Vector3.UP if up else Vector3.DOWN
	for i in sides + 1:
		var a := lerpf(a0, a1, float(i) / sides); var d := Vector3(cos(a), 0.0, sin(a))
		vs.push_back(Vector3(x, y, z) + d * r_in); ns.push_back(n); cs.push_back(col)
		vs.push_back(Vector3(x, y, z) + d * r); ns.push_back(n); cs.push_back(col)
	for i in sides:
		var k := o + i * 2
		if up: _tri(k, k + 3, k + 1); _tri(k, k + 2, k + 3)
		else: _tri(k, k + 1, k + 3); _tri(k, k + 3, k + 2)

## half a ball with its flat side down at height y (squash: how tall for its width; from: how far up it starts, 0..1, for
## a dome with its foot cut off), seen from outside or, turned inside out, from within
func dome(x: float, y: float, z: float, r: float, col: Color, sides := 12, rings := 4, squash := 1.0, inside := false, col_top = null) -> void:
	var o := vs.size(); var ct: Color = col_top if col_top != null else col
	for j in rings + 1:
		var t := float(j) / rings; var e := t * PI * 0.5; var rr := cos(e) * r; var yy := sin(e) * r * squash
		for i in sides + 1:
			var a := TAU * float(i) / sides; var d := Vector3(cos(a), 0.0, sin(a))
			var n := Vector3(d.x * cos(e), sin(e) / maxf(squash, 0.01), d.z * cos(e)).normalized()
			vs.push_back(Vector3(x, y + yy, z) + d * rr); ns.push_back(-n if inside else n); cs.push_back(col.lerp(ct, t))
	var w := sides + 1
	for j in rings:
		for i in sides:
			var k := o + j * w + i
			if inside: _tri(k, k + 1, k + w + 1); _tri(k, k + w + 1, k + w)
			else: _tri(k, k + w, k + w + 1); _tri(k, k + w + 1, k + 1)

## a ball
func ball(x: float, y: float, z: float, r: float, col: Color, sides := 10, rings := 6, squash := 1.0) -> void:
	var o := vs.size()
	for j in rings + 1:
		var e := -PI * 0.5 + PI * float(j) / rings; var rr := cos(e) * r; var yy := sin(e) * r * squash
		for i in sides + 1:
			var a := TAU * float(i) / sides; var d := Vector3(cos(a), 0.0, sin(a))
			vs.push_back(Vector3(x, y + yy, z) + d * rr); ns.push_back(Vector3(d.x * cos(e), sin(e) / maxf(squash, 0.01), d.z * cos(e)).normalized()); cs.push_back(col)
	var w := sides + 1
	for j in rings:
		for i in sides:
			var k := o + j * w + i
			_tri(k, k + w, k + w + 1); _tri(k, k + w + 1, k + 1)

## a flat strip from a to b, this wide, lying (its face up) or standing (its face sideways); seen from both sides
func strip(a: Vector3, b: Vector3, width: float, col: Color, lying := true) -> void:
	var along := b - a
	if along.length() < 0.0001: return
	var side := (along.cross(Vector3.UP) if lying else Vector3.UP).normalized() * width * 0.5
	if lying and side.length() < 0.0001: side = Vector3.RIGHT * width * 0.5
	var n := along.cross(side).normalized()
	quad(a - side, a + side, b + side, b - side, col, n); quad(a + side, a - side, b - side, b + side, col, -n)

## a flat band from a to b that faces `face` (a vine down a wall, a pennant): seen from both sides
func ribbon(a: Vector3, b: Vector3, width: float, col: Color, face: Vector3) -> void:
	var along := b - a; var side := along.cross(face)
	if side.length() < 0.0001: return
	side = side.normalized() * width * 0.5; var n := side.cross(along).normalized()
	quad(a - side, a + side, b + side, b - side, col, n); quad(a + side, a - side, b - side, b + side, col, -n)

## a beam of four sides from a to b (a rope, a rail, a branch), this thick
func beam(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var along := b - a; var len := along.length()
	if len < 0.0001: return
	var f := along / len; var u := Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
	var s := f.cross(u).normalized() * thick * 0.5; var t := s.cross(f).normalized() * thick * 0.5
	quad(a + s - t, a + s + t, b + s + t, b + s - t, col, s.normalized()); quad(a - s + t, a - s - t, b - s - t, b - s + t, col, -s.normalized())
	quad(a + s + t, a - s + t, b - s + t, b + s + t, col, t.normalized()); quad(a - s - t, a + s - t, b + s - t, b - s - t, col, -t.normalized())

## all of it as one mesh (null if nothing was put in)
func mesh() -> ArrayMesh:
	if vs.is_empty(): return null
	var arr := []; arr.resize(Mesh.ARRAY_MAX); var uv := PackedVector2Array(); uv.resize(vs.size())
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = cs; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## ...on a node of its own, wearing this material
func node(mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh(); mi.material_override = mat
	if parent != null: parent.add_child(mi)
	return mi
