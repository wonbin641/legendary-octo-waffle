class_name ArtKit
extends RefCounted
## Sculpted shapes for the realm's weapons and bodies (the art direction paper's: white marble and gold, hammered iron and
## bronze, black obsidian glass), gathered into one mesh whose every corner also says what its surface is: COLOR is its
## colour (a screen colour) and, in alpha, how much it glows (or, in a fill, how far along the fill it lies); UV says how
## metal (x) and how rough (y); UV2 its pattern (x: marble's veins, hammered iron, leather...) and which of the art
## shader's lights it answers to (y: a charge, a heat, a fill). RaceArt's shader draws them.
## Shapes go where the current transform puts them (at / push / pop), in the current paint.

const PLAIN := 0; const MARBLE := 1; const IRON := 2; const LEATHER := 3; const OBSIDIAN := 4; const WORN := 5; const WOOD := 6
const SKIN := 7; const BONE := 8; const CLOTH := 9; const CRYSTAL := 10

var vs := PackedVector3Array(); var ns := PackedVector3Array(); var cs := PackedColorArray()
var u1 := PackedVector2Array(); var u2 := PackedVector2Array(); var idx := PackedInt32Array()
var xf := Transform3D.IDENTITY; var _nb := Basis.IDENTITY
var _stack: Array[Transform3D] = []
var col := Color.WHITE; var glow := 0.0; var surf := Vector2(0.0, 0.6); var tag := Vector2.ZERO
var detail := 1.0     # how finely round things are cut (a body far off: less)

func is_empty() -> bool: return vs.is_empty()
func corners() -> int: return vs.size()

## the paint for what comes next: its colour, how metal and rough, its pattern, its glow group and how much it glows
func paint(c, metal := 0.0, rough := 0.6, pattern := PLAIN, group := 0, lit := 0.0) -> ArtKit:
	col = c if c is Color else Color(str(c)); surf = Vector2(metal, rough); tag = Vector2(pattern, group); glow = lit
	return self

func push(t: Transform3D) -> void:
	_stack.push_back(xf); xf = xf * t; _nb = xf.basis.inverse().transposed()
func pop() -> void:
	xf = _stack.pop_back(); _nb = xf.basis.inverse().transposed()
## push a move, a turn (radians, x then y then z as Godot's own euler) and a scale
func at(p: Vector3, r := Vector3.ZERO, s := Vector3.ONE) -> void:
	push(Transform3D(Basis.from_euler(r) * Basis.from_scale(s), p))
## push a frame that looks from p along fwd (its -Z), its up near up
func toward(p: Vector3, fwd: Vector3, up := Vector3.UP) -> void:
	var z := -fwd.normalized(); var x := up.cross(z)
	if x.length() < 0.001: x = Vector3.RIGHT.cross(z)
	x = x.normalized(); push(Transform3D(Basis(x, z.cross(x), z), p))

func sides(n: int) -> int: return maxi(3, int(round(n * detail)))

# ---------------- the corners and faces ----------------
func _v(p: Vector3, n: Vector3, a := -1.0) -> int:
	vs.push_back(xf * p); ns.push_back((_nb * n).normalized())
	var c := col; c.a = glow if a < 0.0 else a; cs.push_back(c); u1.push_back(surf); u2.push_back(tag)
	return vs.size() - 1

## a face of three corners, turned to be seen from the side its normals point to (Godot: clockwise from the front)
func _tri(a: int, b: int, c: int) -> void:
	if (vs[c] - vs[a]).cross(vs[b] - vs[a]).dot(ns[a] + ns[b] + ns[c]) >= 0.0: idx.push_back(a); idx.push_back(b); idx.push_back(c)
	else: idx.push_back(a); idx.push_back(c); idx.push_back(b)

## a surface through rings of points (each as many). closed: a ring's last point joins its first; loop: the last ring
## joins the first. smooth: normals shared (else each four-sided piece flat). nrm: the normals given (else worked out,
## and turned away from each ring's middle; face: or toward this side, for an open sheet). aval: the glow (or fill
## place) of each ring
func grid(rings: Array, closed := true, smooth := true, nrm: Array = [], aval := PackedFloat32Array(), loop := false, face := Vector3.ZERO) -> void:
	var R := rings.size()
	if R < 2: return
	var C: int = (rings[0] as PackedVector3Array).size()
	var mids: Array[Vector3] = []
	for r: PackedVector3Array in rings:
		var m := Vector3.ZERO
		for p in r: m += p
		mids.push_back(m / maxf(1.0, r.size()))
	var N: Array = nrm
	if N.is_empty():
		N = []
		for i in R:
			var row := PackedVector3Array(); var ra: PackedVector3Array = rings[i]
			var ip := (i - 1 + R) % R if loop else maxi(i - 1, 0); var inx := (i + 1) % R if loop else mini(i + 1, R - 1)
			for j in C:
				var jp := (j - 1 + C) % C if closed else maxi(j - 1, 0); var jn := (j + 1) % C if closed else mini(j + 1, C - 1)
				var tu: Vector3 = ra[jn] - ra[jp]; var tv: Vector3 = (rings[inx] as PackedVector3Array)[j] - (rings[ip] as PackedVector3Array)[j]
				var n := tu.cross(tv)
				var out: Vector3 = face if face != Vector3.ZERO else ra[j] - mids[i]
				if n.length_squared() < 1e-14: n = out if out.length_squared() > 1e-14 else (mids[inx] - mids[ip])
				n = n.normalized()
				if n.dot(out) < 0.0: n = -n
				row.push_back(n)
			N.push_back(row)
	var has_a := aval.size() == R
	var span := R if loop else R - 1; var cspan := C if closed else C - 1
	if smooth:
		var base: Array[int] = []
		for i in R:
			base.push_back(vs.size()); var ra: PackedVector3Array = rings[i]; var na: PackedVector3Array = N[i]
			for j in C: _v(ra[j], na[j], aval[i] if has_a else -1.0)
		for i in span:
			var a0 := base[i]; var a1 := base[(i + 1) % R]
			for j in cspan:
				var j1 := (j + 1) % C
				_tri(a0 + j, a1 + j, a1 + j1); _tri(a0 + j, a1 + j1, a0 + j1)
	else:
		for i in span:
			var ra: PackedVector3Array = rings[i]; var rb: PackedVector3Array = rings[(i + 1) % R]
			var aa := aval[i] if has_a else -1.0; var ab := aval[(i + 1) % R] if has_a else -1.0
			for j in cspan:
				var j1 := (j + 1) % C
				var p0 := ra[j]; var p1 := rb[j]; var p2 := rb[j1]; var p3 := ra[j1]
				var n := (p1 - p0).cross(p3 - p0) + (p2 - p3).cross(p2 - p1)
				var out: Vector3 = (face if face != Vector3.ZERO else (p0 + p2) * 0.5 - (mids[i] + mids[(i + 1) % R]) * 0.5)
				if n.length_squared() < 1e-16: n = out
				n = n.normalized()
				if n.dot(out) < 0.0: n = -n
				var k0 := _v(p0, n, aa); var k1 := _v(p1, n, ab); var k2 := _v(p2, n, ab); var k3 := _v(p3, n, aa)
				_tri(k0, k1, k2); _tri(k0, k2, k3)

## a ring closed over: a flat face across it, facing away from `away`
func cap(ring: PackedVector3Array, away: Vector3, flat2d := PackedVector2Array()) -> void:
	var m := Vector3.ZERO
	for p in ring: m += p
	m /= maxf(1.0, ring.size())
	var n := Vector3.ZERO   # (Newell's normal of the ring)
	for j in ring.size():
		var a := ring[j]; var b := ring[(j + 1) % ring.size()]
		n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if n.length_squared() < 1e-16: return
	n = n.normalized()
	if n.dot(m - away) < 0.0: n = -n
	if flat2d.size() == ring.size():   # (a ring that is not round about its middle: cut into faces properly)
		var tris := Geometry2D.triangulate_polygon(flat2d)
		if tris.size() >= 3:
			var o := vs.size()
			for p in ring: _v(p, n)
			for k in range(0, tris.size(), 3): _tri(o + tris[k], o + tris[k + 1], o + tris[k + 2])
			return
	var c := _v(m, n); var o2 := vs.size()
	for p in ring: _v(p, n)
	for j in ring.size(): _tri(c, o2 + j, o2 + (j + 1) % ring.size())

# ---------------- paths ----------------
## points through these, smoothly (Catmull-Rom), each stretch cut in n
static func spline(pts: Array, n := 6) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pts.size() < 2: return out
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]; var p1: Vector3 = pts[i]; var p2: Vector3 = pts[i + 1]; var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for k in n:
			var t := float(k) / n; var t2 := t * t; var t3 := t2 * t
			out.push_back(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.push_back(pts[pts.size() - 1])
	return out

static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n := 12) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n + 1:
		var t := float(k) / n; var u := 1.0 - t
		out.push_back(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return out

## frames along a path (no twisting): [tangent, normal (up), binormal (side)] at each point
static func frames(path: PackedVector3Array, up := Vector3.UP, loop := false) -> Array:
	var n := path.size(); var out: Array = []
	var prev_n := Vector3.ZERO
	for i in n:
		var a: Vector3 = path[(i - 1 + n) % n] if loop else path[maxi(i - 1, 0)]; var b: Vector3 = path[(i + 1) % n] if loop else path[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		if t.length_squared() < 0.5: t = Vector3.FORWARD
		var nn: Vector3
		if i == 0:
			nn = up - t * up.dot(t)
			if nn.length_squared() < 1e-6: nn = Vector3.RIGHT - t * t.x
		else:
			nn = prev_n - t * prev_n.dot(t)
			if nn.length_squared() < 1e-8: nn = prev_n
		nn = nn.normalized(); prev_n = nn
		out.push_back([t, nn, t.cross(nn).normalized()])
	return out

## a cross-section (its points as (across, up)) carried along a path. sc: its scale at each point (a Vector2 for all,
## or an array of them, or of floats); twist: radians it turns along the way
func sweep(path: PackedVector3Array, shape: PackedVector2Array, sc = Vector2.ONE, up := Vector3.UP, smooth := true, caps := true, closed := true, twist := 0.0, aval := PackedFloat32Array(), loop := false) -> Array:
	var F := frames(path, up, loop); var rings: Array = []
	for i in path.size():
		var s: Vector2 = Vector2.ONE
		if sc is Vector2: s = sc
		elif sc is Array or sc is PackedFloat32Array or sc is PackedVector2Array:
			var v = sc[mini(i, sc.size() - 1)]
			s = v if v is Vector2 else Vector2(float(v), float(v))
		var f: Array = F[i]; var tw := twist * (float(i) / maxf(1.0, path.size() - 1))
		var ring := PackedVector3Array()
		for q in shape:
			var e := q.rotated(tw)
			ring.push_back(path[i] + (f[2] as Vector3) * e.x * s.x + (f[1] as Vector3) * e.y * s.y)
		rings.push_back(ring)
	grid(rings, closed, smooth, [], aval, loop)
	if caps and not loop and closed:
		cap(rings[0], path[mini(1, path.size() - 1)]); cap(rings[rings.size() - 1], path[maxi(path.size() - 2, 0)])
	return rings

static func circle(n: int, r := 1.0, a0 := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n: var a := a0 + TAU * k / n; out.push_back(Vector2(cos(a), sin(a)) * r)
	return out

## a round tube along a path; r: one radius, or one for each point
func tube(path: PackedVector3Array, r, n := 8, caps := true, up := Vector3.UP, smooth := true) -> void:
	var sc: Array = []
	if r is float or r is int: sc = [Vector2(float(r), float(r))]
	else:
		for v in r: sc.push_back(Vector2(float(v), float(v)))
	sweep(path, circle(sides(n)), sc, up, smooth, caps)

## a round thing turned about the upright (y) axis: its outline as (radius, height) from the bottom up
func lathe(profile: PackedVector2Array, n := 16, a0 := 0.0, a1 := TAU, smooth := true, caps := false, aval := PackedFloat32Array()) -> void:
	var m := sides(n); var full := absf(a1 - a0) >= TAU - 0.001; var cnt := m if full else m + 1
	var rings: Array = []
	for q in profile:
		var ring := PackedVector3Array()
		for k in cnt:
			var a := lerpf(a0, a1, float(k) / m)
			ring.push_back(Vector3(cos(a) * q.x, q.y, sin(a) * q.x))
		rings.push_back(ring)
	# the normals: from the outline's own slope, round the axis
	var N: Array = []
	for i in profile.size():
		var a := profile[maxi(i - 1, 0)]; var b := profile[mini(i + 1, profile.size() - 1)]; var d := b - a
		var n2 := Vector2(d.y, -d.x).normalized()   # (outward of a rising outline)
		if n2.length_squared() < 0.5: n2 = Vector2(1, 0)
		var row := PackedVector3Array()
		for k in cnt:
			var ang := lerpf(a0, a1, float(k) / m)
			row.push_back(Vector3(cos(ang) * n2.x, n2.y, sin(ang) * n2.x))
		N.push_back(row)
	if smooth: grid(rings, full, true, N, aval)
	else: grid(rings, full, false, [], aval)
	if caps:
		if profile[0].x > 0.0001: cap(rings[0], Vector3(0, profile[profile.size() - 1].y, 0))
		if profile[profile.size() - 1].x > 0.0001: cap(rings[rings.size() - 1], Vector3(0, profile[0].y, 0))

func cyl(r0: float, r1: float, h: float, n := 12, caps := true, smooth := true) -> void:
	lathe(PackedVector2Array([Vector2(r0, 0.0), Vector2(r1, h)]), n, 0.0, TAU, smooth, caps)

## a ball stretched to the radii r (an egg, a muscle, a head); its normals true to its shape
func ball(c: Vector3, r: Vector3, n := 12, rings := 8) -> void:
	var m := sides(n); var q := maxi(3, int(round(rings * detail))); var R: Array = []; var N: Array = []
	for j in q + 1:
		var e := -PI * 0.5 + PI * float(j) / q; var ce := cos(e); var se := sin(e)
		var ring := PackedVector3Array(); var nr := PackedVector3Array()
		for k in m:
			var a := TAU * float(k) / m; var d := Vector3(cos(a) * ce, se, sin(a) * ce)
			ring.push_back(c + d * r); nr.push_back(Vector3(d.x / maxf(r.x, 1e-5), d.y / maxf(r.y, 1e-5), d.z / maxf(r.z, 1e-5)).normalized())
		R.push_back(ring); N.push_back(nr)
	grid(R, true, true, N)

## a half ball (a rivet, a dome) standing on p, its top toward n
func dome(p: Vector3, n: Vector3, r: float, h := -1.0, m := 8) -> void:
	toward(p, n.normalized()); push(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO))   # (lathe's up: along n)
	var prof := PackedVector2Array(); var hh := r if h < 0.0 else h
	for j in 4: var e := PI * 0.5 * float(j) / 3.0; prof.push_back(Vector2(cos(e) * r, sin(e) * hh))
	lathe(prof, m); pop(); pop()

## a ring (torus) round the y axis: R its radius, r its thickness; a0..a1 only part of the way round
func torus(R: float, r: float, n := 16, m := 6, a0 := 0.0, a1 := TAU) -> void:
	var path := PackedVector3Array(); var full := absf(a1 - a0) >= TAU - 0.001; var k := sides(n)
	for i in (k if full else k + 1): var a := lerpf(a0, a1, float(i) / k); path.push_back(Vector3(cos(a) * R, 0.0, sin(a) * R))
	sweep(path, circle(sides(m), r), Vector2.ONE, Vector3.UP, true, not full, true, 0.0, PackedFloat32Array(), full)

## a chain's link: a stretched ring, long along z
func link(len: float, wide: float, r: float, m := 5) -> void:
	var path := PackedVector3Array(); var h := (len - wide) * 0.5; var rr := wide * 0.5
	for i in 6: var a := PI * float(i) / 5.0; path.push_back(Vector3(cos(a) * rr, 0.0, -h - sin(a) * rr))
	for i in 6: var a := PI + PI * float(i) / 5.0; path.push_back(Vector3(cos(a) * rr, 0.0, h - sin(a) * rr))
	sweep(path, circle(sides(m), r), Vector2.ONE, Vector3.UP, true, false, true, 0.0, PackedFloat32Array(), true)

## a gem of n sides: a point up (h_up) and down (h_dn), flat faces
func gem(r: float, h_up: float, h_dn: float, n := 4, a0 := 0.0) -> void:
	var ring := PackedVector3Array()
	for k in n: var a := a0 + TAU * k / n; ring.push_back(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var top := Vector3(0, h_up, 0); var bot := Vector3(0, -h_dn, 0)
	for k in n:
		var a := ring[k]; var b := ring[(k + 1) % n]
		for tip: Vector3 in [top, bot]:
			var nn := (a - tip).cross(b - tip).normalized()
			if nn.dot((a + b + tip) / 3.0) < 0.0: nn = -nn
			var i0 := _v(tip, nn); var i1 := _v(a, nn); var i2 := _v(b, nn); _tri(i0, i1, i2)

# ---------------- flat outlines made solid ----------------
## an outline (in x, y) made a solid slab `depth` thick along z, its edges rounded by `bevel` in `steps`. The outline
## should go round once without crossing itself
func extrude(poly: PackedVector2Array, depth: float, bevel := 0.0, steps := 2, front := true, back := true) -> void:
	var P := poly
	if _area(P) < 0.0: P = _reversed(P)
	var M := P.size()
	var n2 := PackedVector2Array()   # (each corner's outward way, half-way between its two sides)
	for j in M:
		var a := P[(j - 1 + M) % M]; var b := P[j]; var c := P[(j + 1) % M]
		var e1 := (b - a).normalized(); var e2 := (c - b).normalized()
		var o1 := Vector2(e1.y, -e1.x); var o2 := Vector2(e2.y, -e2.x); var o := (o1 + o2)
		if o.length_squared() < 1e-8: o = o1
		o = o.normalized(); var k := maxf(0.35, o.dot(o1)); n2.push_back(o / k)
	var hz := depth * 0.5; var rings: Array = []; var N: Array = []
	var st := maxi(1, steps) if bevel > 0.0 else 0
	var phis: Array[float] = []
	if st == 0: phis = [0.0]
	else:
		for k in st + 1: phis.push_back(PI * 0.5 * float(k) / st)
	var order: Array = []   # (from the back face's edge round the side to the front face's edge)
	for k in range(phis.size() - 1, -1, -1): order.push_back([-1.0, phis[k]])
	for k in phis.size(): order.push_back([1.0, phis[k]])
	for o: Array in order:
		var sgn: float = o[0]; var phi: float = o[1]
		var inset := bevel * (1.0 - cos(phi)); var z := sgn * (hz - bevel + bevel * sin(phi))
		var ring := PackedVector3Array(); var nr := PackedVector3Array()
		for j in M:
			var q := P[j] - n2[j] * inset
			ring.push_back(Vector3(q.x, q.y, z))
			var on := n2[j].normalized()
			nr.push_back(Vector3(on.x * cos(phi), on.y * cos(phi), sgn * sin(phi)).normalized())
		rings.push_back(ring); N.push_back(nr)
	grid(rings, true, true, N)
	var inner := PackedVector2Array()
	for j in M: inner.push_back(P[j] - n2[j] * bevel)
	if front: cap(rings[rings.size() - 1], Vector3(0, 0, -1.0), inner)
	if back: cap(rings[0], Vector3(0, 0, 1.0), inner)

static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for j in p.size(): var q := p[j]; var r := p[(j + 1) % p.size()]; a += q.x * r.y - r.x * q.y
	return a * 0.5
static func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for j in range(p.size() - 1, -1, -1): o.push_back(p[j])
	return o

## a box with rounded edges, its middle at c
func rbox(size: Vector3, c := Vector3.ZERO, bevel := 0.004, steps := 2) -> void:
	var b := minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)
	at(c); extrude(rrect(size.x, size.y, b, 2), size.z, b, steps); pop()

## a rectangle w x h with its corners rounded by r (each corner in n pieces)
static func rrect(w: float, h: float, r: float, n := 3) -> PackedVector2Array:
	var out := PackedVector2Array(); var hw := w * 0.5 - r; var hh := h * 0.5 - r
	for c: Vector2 in [Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh), Vector2(hw, -hh)]:
		var a0 := atan2(signf(c.y), signf(c.x)) - PI * 0.25
		for k in n + 1:
			var a := a0 + PI * 0.5 * float(k) / n
			out.push_back(c + Vector2(cos(a), sin(a)) * r)
	return out

## a crescent: a ring's arc of radius R round (0, 0), sw radians either side of +x, thickest (w) in its middle, its horns
## to points
static func crescent(R: float, w: float, sw: float, n := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var t := -1.0 + 2.0 * k / n; var a := t * sw
		out.push_back(Vector2(cos(a), sin(a)) * R)
	for k in range(n - 1, 0, -1):
		var t := -1.0 + 2.0 * k / n; var a := t * sw
		var th := w * pow(maxf(0.0, 1.0 - t * t), 0.65)
		out.push_back(Vector2(cos(a), sin(a)) * (R - th))
	return out

# ---------------- ornament ----------------
## a scroll of filigree: from p along `dir`, curling in at its end (turns of a shrinking spiral); in the plane's (x, y)
static func scroll(p: Vector2, dir: float, len: float, curl: float, turns := 1.25, left := true, n := 18) -> PackedVector2Array:
	var out := PackedVector2Array(); var d := Vector2(cos(dir), sin(dir)); var s := 1.0 if left else -1.0
	var stem := maxi(2, n / 3)
	for k in stem: out.push_back(p + d * len * float(k) / stem)
	var c0 := p + d * len; var nrm := Vector2(-d.y, d.x) * s; var centre := c0 + nrm * curl
	var a0 := atan2(c0.y - centre.y, c0.x - centre.x)
	for k in n + 1:
		var t := float(k) / n; var a := a0 + s * t * turns * TAU; var r := curl * (1.0 - 0.82 * t)
		out.push_back(centre + Vector2(cos(a), sin(a)) * r)
	return out

## a raised line along a curve drawn in a plane (the plane: the current transform's x, y; its face toward +z)
func relief(curve: PackedVector2Array, r: float, lift := 0.0, n := 5) -> void:
	var path := PackedVector3Array()
	for q in curve: path.push_back(Vector3(q.x, q.y, lift))
	var shape := PackedVector2Array()
	var m := maxi(3, n)
	for k in m + 1: var a := PI * float(k) / m; shape.push_back(Vector2(cos(a), sin(a)) * r)   # (a half round: its back in the surface)
	sweep(path, shape, Vector2.ONE, Vector3(0, 0, 1), true, false, false)

## a rune: a few strokes in a box `s` big, the same for the same number (in the plane's x, y, raised a little toward +z)
func rune(seed_n: int, s: float, w: float, lift := 0.0005) -> void:
	var r := RandomNumberGenerator.new(); r.seed = seed_n * 7919 + 13
	var pts := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, 0)]
	var strokes := [[4, 5]]   # (a stem, and two or three strokes off it)
	for k in 2 + r.randi() % 2:
		var a := r.randi() % pts.size(); var b := r.randi() % pts.size()
		if a != b: strokes.push_back([a, b])
	for st: Array in strokes:
		var a: Vector2 = pts[st[0]] * s; var b: Vector2 = pts[st[1]] * s; var d := b - a
		if d.length() < 0.001: continue
		var nn := Vector2(-d.y, d.x).normalized() * w * 0.5
		var q0 := Vector3(a.x + nn.x, a.y + nn.y, lift); var q1 := Vector3(b.x + nn.x, b.y + nn.y, lift); var q2 := Vector3(b.x - nn.x, b.y - nn.y, lift); var q3 := Vector3(a.x - nn.x, a.y - nn.y, lift)
		var i0 := _v(q0, Vector3.BACK); var i1 := _v(q1, Vector3.BACK); var i2 := _v(q2, Vector3.BACK); var i3 := _v(q3, Vector3.BACK)
		_tri(i0, i1, i2); _tri(i0, i2, i3)

## a thin flat line from a to b (a scratch), lying on a face whose normal is n
func strip_line(a: Vector3, b: Vector3, w: float, n: Vector3) -> void:
	var d := b - a
	if d.length() < 0.0001: return
	var s := d.cross(n).normalized() * w * 0.5
	var i0 := _v(a - s, n); var i1 := _v(b - s, n); var i2 := _v(b + s, n); var i3 := _v(a + s, n); _tri(i0, i1, i2); _tri(i0, i2, i3)

## a flat piece (a membrane, a cloth), its points given row by row, seen from both sides
func sheet(rows: Array, face: Vector3) -> void:
	grid(rows, false, true, [], PackedFloat32Array(), false, face)
	grid(rows, false, true, [], PackedFloat32Array(), false, -face)


# ---------------- plain solids (a map's: big, flat-sided) ----------------
## four corners as a face (in order round it), its normal n
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var i0 := _v(a, n); var i1 := _v(b, n); var i2 := _v(c, n); var i3 := _v(d, n); _tri(i0, i1, i2); _tri(i0, i2, i3)

## a box by its corners, flat-sided (the bottom left off when it is sunk in something)
func slab(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, bottom := false) -> void:
	quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP)
	if bottom: quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN)
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK)
	quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD)
	quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT)

## a piece of a ring round (cx, cz): between radii r0 and r1, angles a0 and a1 (radians), its top at y1, its foot at y0;
## its top in n pieces round. ends: its two end faces too. under: its underside too
func ring_sector(cx: float, cz: float, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, n := 16, ends := true, under := false) -> void:
	var m := maxi(1, int(round(n * detail)))
	for i in m:
		var b0 := lerpf(a0, a1, float(i) / m); var b1 := lerpf(a0, a1, float(i + 1) / m)
		var d0 := Vector3(cos(b0), 0, sin(b0)); var d1 := Vector3(cos(b1), 0, sin(b1)); var c := Vector3(cx, 0, cz)
		var t0 := c + d0 * r0; var t1 := c + d0 * r1; var t2 := c + d1 * r1; var t3 := c + d1 * r0
		quad(t0 + Vector3(0, y1, 0), t1 + Vector3(0, y1, 0), t2 + Vector3(0, y1, 0), t3 + Vector3(0, y1, 0), Vector3.UP)
		if under: quad(t0 + Vector3(0, y0, 0), t1 + Vector3(0, y0, 0), t2 + Vector3(0, y0, 0), t3 + Vector3(0, y0, 0), Vector3.DOWN)
		var nm := (d0 + d1).normalized()
		quad(t1 + Vector3(0, y0, 0), t2 + Vector3(0, y0, 0), t2 + Vector3(0, y1, 0), t1 + Vector3(0, y1, 0), nm)
		if r0 > 0.01: quad(t3 + Vector3(0, y0, 0), t0 + Vector3(0, y0, 0), t0 + Vector3(0, y1, 0), t3 + Vector3(0, y1, 0), -nm)
	if ends:
		for e: Array in [[a0, -1.0], [a1, 1.0]]:
			var a: float = e[0]; var d := Vector3(cos(a), 0, sin(a)); var tn := Vector3(-d.z, 0, d.x) * float(e[1]); var c := Vector3(cx, 0, cz)
			quad(c + d * r0 + Vector3(0, y0, 0), c + d * r1 + Vector3(0, y0, 0), c + d * r1 + Vector3(0, y1, 0), c + d * r0 + Vector3(0, y1, 0), tn)

# ---------------- the mesh ----------------
func mesh() -> ArrayMesh:
	if vs.is_empty(): return null
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_COLOR] = cs; arr[Mesh.ARRAY_TEX_UV] = u1; arr[Mesh.ARRAY_TEX_UV2] = u2; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func node(mat: Material, parent: Node = null, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh(); mi.material_override = mat
	if name != "": mi.name = name
	if parent != null: parent.add_child(mi)
	return mi

## start afresh (the paint and the transform kept)
func clear() -> void:
	vs = PackedVector3Array(); ns = PackedVector3Array(); cs = PackedColorArray(); u1 = PackedVector2Array(); u2 = PackedVector2Array(); idx = PackedInt32Array()
