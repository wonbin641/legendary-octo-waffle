extends Node
## Colliders, the spatial index, rays and the flow-field navigation: a line-for-line port of src/04b_physics.js,
## so that movement and enemy paths behave as they do in the browser game. Godot's own physics is not used.

class Box:
	var minx: float; var miny: float; var minz: float
	var maxx: float; var maxy: float; var maxz: float
	var kind: String = "concrete"
	var ref = null
	var q: int = 0
	var door := false; var step := false; var grate := false; var glass := false; var tower := false

var HALF := 66.0
var colliders: Array[Box] = []
const SPC := 8.0
var SPN := 20
var SPO := 80.0
var cells: Array = []
var qstamp := 1
var PIT = null  # {x0, x1, z0, z1, y} or null
var nav_mask: Callable = Callable()

func set_world_size(half: float) -> void:
	HALF = half; SPO = half + 14.0; SPN = ceili((2.0 * SPO) / SPC)
	cells = []; cells.resize(SPN * SPN)
	for i in cells.size(): cells[i] = []

func clear() -> void:
	colliders.clear(); PIT = null; nav_mask = Callable()

func floor_y(x: float, z: float) -> float:
	return PIT.y if PIT != null and x > PIT.x0 and x < PIT.x1 and z > PIT.z0 and z < PIT.z1 else 0.0

func _ci(v: float) -> int:
	return clampi(floori((v + SPO) / SPC), 0, SPN - 1)

func add_collider(minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float, kind := "concrete", ref = null) -> Box:
	var b := Box.new()
	b.minx = minx; b.miny = miny; b.minz = minz; b.maxx = maxx; b.maxy = maxy; b.maxz = maxz; b.kind = kind; b.ref = ref
	colliders.push_back(b)
	if cells.size() == SPN * SPN:
		for i in range(_ci(minx), _ci(maxx) + 1):
			for j in range(_ci(minz), _ci(maxz) + 1): cells[j * SPN + i].push_back(b)
	return b

func index_colliders() -> void:
	cells = []; cells.resize(SPN * SPN)
	for i in cells.size(): cells[i] = []
	for b in colliders:
		for i in range(_ci(b.minx), _ci(b.maxx) + 1):
			for j in range(_ci(b.minz), _ci(b.maxz) + 1): cells[j * SPN + i].push_back(b)

func remove_collider(b: Box) -> void:
	colliders.erase(b)
	for i in range(_ci(b.minx), _ci(b.maxx) + 1):
		for j in range(_ci(b.minz), _ci(b.maxz) + 1): cells[j * SPN + i].erase(b)

var _near: Array[Box] = []
func query_near(minx: float, minz: float, maxx: float, maxz: float) -> Array[Box]:
	_near.clear(); qstamp += 1
	var i0 := _ci(minx); var i1 := _ci(maxx); var j0 := _ci(minz); var j1 := _ci(maxz)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			for b: Box in cells[j * SPN + i]:
				if b.q != qstamp: b.q = qstamp; _near.push_back(b)
	return _near

## while a stage is being built: is any box in this upright slab of space?
func box_at(x: float, z: float, r: float, y0: float, y1: float) -> bool:
	for b in colliders:
		if x + r > b.minx and x - r < b.maxx and z + r > b.minz and z - r < b.maxz and y1 > b.miny and y0 < b.maxy: return true
	return false

## while a stage is being built: is anything within m of this footprint?
func occupied(minx: float, minz: float, maxx: float, maxz: float, m: float) -> bool:
	for b in colliders:
		if maxx + m > b.minx and minx - m < b.maxx and maxz + m > b.minz and minz - m < b.maxz: return true
	return false

## (this and ground_at and ceil_at walk the index's cells themselves, in query_near's order, rather than gather a list first)
func collide_at(x: float, y: float, z: float, r: float, h: float) -> Box:
	qstamp += 1; var st := qstamp
	var x0 := x - r; var x1 := x + r; var z0 := z - r; var z1 := z + r; var top := y + h
	for i in range(_ci(x0), _ci(x1) + 1):
		for j in range(_ci(z0), _ci(z1) + 1):
			for b: Box in cells[j * SPN + i]:
				if b.q == st: continue
				b.q = st
				if x1 <= b.minx or x0 >= b.maxx or z1 <= b.minz or z0 >= b.maxz: continue
				if top <= b.miny or y >= b.maxy - 0.001: continue
				return b
	return null

## p is a Vector3 held by the caller; returns [new_p, blocked]
func move_xz(p: Vector3, dx: float, dz: float, r: float, h: float, step_h: float) -> Array:
	var blocked := false
	for axis in 2:
		var d := dx if axis == 0 else dz
		if d == 0.0: continue
		var nx := p.x + d if axis == 0 else p.x
		var nz := p.z + d if axis == 1 else p.z
		var b := collide_at(nx, p.y, nz, r, h)
		if b == null: p.x = nx; p.z = nz; continue
		if step_h > 0.0 and b.maxy - p.y <= step_h and collide_at(nx, b.maxy + 0.002, nz, r, h) == null:
			p.x = nx; p.z = nz; p.y = b.maxy + 0.001; continue
		blocked = true
		if axis == 0: p.x = minf(p.x, b.minx - r - 0.001) if d > 0.0 else maxf(p.x, b.maxx + r + 0.001)
		else: p.z = minf(p.z, b.minz - r - 0.001) if d > 0.0 else maxf(p.z, b.maxz + r + 0.001)
	return [p, blocked]

func ground_at(x: float, y: float, z: float, r: float) -> float:
	var g := floor_y(x, z)
	qstamp += 1; var st := qstamp
	var x0 := x - r; var x1 := x + r; var z0 := z - r; var z1 := z + r; var lim := y + 0.06
	for i in range(_ci(x0), _ci(x1) + 1):
		for j in range(_ci(z0), _ci(z1) + 1):
			for b: Box in cells[j * SPN + i]:
				if b.q == st: continue
				b.q = st
				if x1 <= b.minx or x0 >= b.maxx or z1 <= b.minz or z0 >= b.maxz: continue
				if b.maxy <= lim and b.maxy > g: g = b.maxy
	return g

func ceil_at(x: float, y: float, z: float, r: float, h: float) -> float:
	var c := INF
	qstamp += 1; var st := qstamp
	var x0 := x - r; var x1 := x + r; var z0 := z - r; var z1 := z + r; var lim := y + h - 0.05
	for i in range(_ci(x0), _ci(x1) + 1):
		for j in range(_ci(z0), _ci(z1) + 1):
			for b: Box in cells[j * SPN + i]:
				if b.q == st: continue
				b.q = st
				if x1 <= b.minx or x0 >= b.maxx or z1 <= b.minz or z0 >= b.maxz: continue
				if b.miny >= lim and b.miny < c: c = b.miny
	return c

# ray vs static boxes and the ground; the result is left in these
var rh_t := 0.0
var rh_n := Vector3.ZERO
var rh_box: Box = null
func raycast_static(o: Vector3, d: Vector3, max_t: float) -> bool:
	var best := max_t; var hit := false
	if d.y < -1e-6:
		var fy := 0.0
		if PIT != null:
			var t0 := -o.y / d.y; var hx := o.x + d.x * t0; var hz := o.z + d.z * t0
			if o.y < 0.0 or (hx > PIT.x0 and hx < PIT.x1 and hz > PIT.z0 and hz < PIT.z1): fy = PIT.y
		var tg := (fy - o.y) / d.y
		if tg >= 0.0 and tg < best: best = tg; rh_n = Vector3.UP; rh_box = null; hit = true
	var ex := o.x + d.x * best; var ez := o.z + d.z * best
	# each box's three slabs in turn, x then y then z (written out: no lists made for each box)
	var ox := o.x; var oy := o.y; var oz := o.z; var dx := d.x; var dy := d.y; var dz := d.z
	for b in query_near(minf(o.x, ex), minf(o.z, ez), maxf(o.x, ex), maxf(o.z, ez)):
		if b.grate and not b.glass: continue
		var t0 := 0.0; var t1 := best; var ax := -1; var sg := 0.0
		if absf(dx) < 1e-9:
			if ox < b.minx or ox > b.maxx: continue
		else:
			var ta: float = (b.minx - ox) / dx; var tb: float = (b.maxx - ox) / dx; var s := -1.0
			if ta > tb: var q := ta; ta = tb; tb = q; s = 1.0
			if ta > t0: t0 = ta; ax = 0; sg = s
			if tb < t1: t1 = tb
			if t0 > t1: continue
		if absf(dy) < 1e-9:
			if oy < b.miny or oy > b.maxy: continue
		else:
			var ta: float = (b.miny - oy) / dy; var tb: float = (b.maxy - oy) / dy; var s := -1.0
			if ta > tb: var q := ta; ta = tb; tb = q; s = 1.0
			if ta > t0: t0 = ta; ax = 1; sg = s
			if tb < t1: t1 = tb
			if t0 > t1: continue
		if absf(dz) < 1e-9:
			if oz < b.minz or oz > b.maxz: continue
		else:
			var ta: float = (b.minz - oz) / dz; var tb: float = (b.maxz - oz) / dz; var s := -1.0
			if ta > tb: var q := ta; ta = tb; tb = q; s = 1.0
			if ta > t0: t0 = ta; ax = 2; sg = s
			if tb < t1: t1 = tb
			if t0 > t1: continue
		if t0 < best:
			best = t0; hit = true; rh_box = b
			rh_n = Vector3(sg if ax == 0 else 0.0, sg if ax == 1 else 0.0, sg if ax == 2 else 0.0)
	rh_t = best
	return hit

func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var v := b - a; var l := v.length()
	if l < 0.01: return true
	return not raycast_static(a, v / l, l - 0.05)

# ---------- navigation: a grid flow field toward the player ----------
var nav_n := 140
var nav_off := 70.0
var nav_cs := 1.0
var nav_blocked := PackedByteArray()
# the flow field's own grids are a cell wider all round, the ring blocked, so its search needs no checks for the edges
# (the same field as searching nav_blocked itself; nav_dist[(j + 1) * _np + i + 1] is cell (i, j)'s steps to the player)
var nav_dist := PackedInt32Array()
var _np := 0                          # their width: nav_n + 2
var _pblk := PackedByteArray()        # nav_blocked inside the ring
var _pdist0 := PackedInt32Array()     # the field a search starts from: -1 open, -2 blocked (the ring too)
var _bfs := PackedInt32Array()

func set_nav(n: int, cs: float) -> void:
	nav_n = n; nav_cs = cs; nav_off = (n * cs) / 2.0

func nav_i(v: float) -> int:
	return clampi(floori((v + nav_off) / nav_cs), 0, nav_n - 1)

func _nav_mark(b: Box, i0: int, j0: int, i1: int, j1: int) -> void:
	if b.miny >= 1.6 or b.door or b.step: return
	var pad := 0.5
	var x0 := maxi(i0, floori((b.minx - pad + nav_off) / nav_cs)); var x1 := mini(i1, floori((b.maxx + pad + nav_off) / nav_cs))
	var z0 := maxi(j0, floori((b.minz - pad + nav_off) / nav_cs)); var z1 := mini(j1, floori((b.maxz + pad + nav_off) / nav_cs))
	for i in range(x0, x1 + 1):
		for j in range(z0, z1 + 1):
			var cx := (i + 0.5) * nav_cs - nav_off; var cz := (j + 0.5) * nav_cs - nav_off
			var ex := maxf(maxf(b.minx - cx, 0.0), cx - b.maxx); var ez := maxf(maxf(b.minz - cz, 0.0), cz - b.maxz)
			if sqrt(ex * ex + ez * ez) < pad + 0.15 * nav_cs: nav_blocked[j * nav_n + i] = 1

func _nav_apply_mask(i0: int, j0: int, i1: int, j1: int) -> void:
	if not nav_mask.is_valid(): return
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			if not nav_mask.call((i + 0.5) * nav_cs - nav_off, (j + 0.5) * nav_cs - nav_off): nav_blocked[j * nav_n + i] = 1

func build_nav() -> void:
	var n := nav_n
	nav_blocked = PackedByteArray(); nav_blocked.resize(n * n)
	for b in colliders: _nav_mark(b, 0, 0, n - 1, n - 1)
	_nav_apply_mask(0, 0, n - 1, n - 1)
	_pad_nav()

## the flow field's grids from nav_blocked: it inside a ring of blocked cells, the field empty
func _pad_nav() -> void:
	var n := nav_n; var P := n + 2; _np = P
	var ring := PackedByteArray(); ring.resize(P); ring.fill(1)
	var out := ring.duplicate()
	for j in n: out.append(1); out.append_array(nav_blocked.slice(j * n, j * n + n)); out.append(1)
	out.append_array(ring); _pblk = out
	var d0 := PackedInt32Array(); d0.resize(P * P); d0.fill(-2)
	for j in n:
		var row := j * n; var at := (j + 1) * P + 1
		for i in n:
			if nav_blocked[row + i] == 0: d0[at + i] = -1
	_pdist0 = d0
	nav_dist = PackedInt32Array(); nav_dist.resize(P * P); nav_dist.fill(-1); _bfs.resize(P * P); flow_busy = false

## something small went (a crate broke): redo only the cells round where it stood
func nav_patch(minx: float, minz: float, maxx: float, maxz: float) -> void:
	if nav_blocked.is_empty(): return
	var m := 1.5
	var i0 := nav_i(minx - m); var i1 := nav_i(maxx + m); var j0 := nav_i(minz - m); var j1 := nav_i(maxz + m)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1): nav_blocked[j * nav_n + i] = 0
	for b in query_near(i0 * nav_cs - nav_off - 1.0, j0 * nav_cs - nav_off - 1.0, (i1 + 1) * nav_cs - nav_off + 1.0, (j1 + 1) * nav_cs - nav_off + 1.0):
		_nav_mark(b, i0, j0, i1, j1)
	_nav_apply_mask(i0, j0, i1, j1)
	if _np != nav_n + 2: _pad_nav(); return
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var b := nav_blocked[j * nav_n + i]; var at := (j + 1) * _np + i + 1; _pblk[at] = b; _pdist0[at] = -2 if b != 0 else -1
	flow_busy = false   # (a search under way was looking at the grid as it was)

## the whole search now (the game's own every 0.3 s goes by flow_start and flow_step)
func update_flow(px: float, pz: float) -> void:
	flow_start(px, pz); flow_step(-1)

# a search under way: its field and queue, how far it has got, and the player's cell it started from
var flow_busy := false
var _fd := PackedInt32Array(); var _fh := 0; var _ft := 0; var _fle := 0; var _fdd := 0; var _fs := 0; var _fsb := false

## a breadth-first search from the player's cell, layer by layer: four sides, then the four corners, a corner only past two
## open sides. The cells start at -1 when open and -2 when blocked (the player's own cell, if blocked, holds -3 till the end:
## done, and still blocked for the corners), so one look at a side says both whether to step there and whether it is open.
## Written out, on locals: the same field as a loop over the eight ways, several times quicker in GDScript
func flow_start(px: float, pz: float) -> void:
	var P := _np
	if P == 0: flow_busy = false; return
	_fd = _pdist0.duplicate()
	_fs = (nav_i(pz) + 1) * P + nav_i(px) + 1; _fsb = _fd[_fs] == -2
	_fd[_fs] = -3 if _fsb else 0
	_bfs[0] = _fs; _fh = 0; _ft = 1; _fle = 1; _fdd = 1; flow_busy = true

## carry the search on for at most this many microseconds (-1: to its end); when it ends the field is the new one. True when done
func flow_step(budget_usec: int) -> bool:
	if not flow_busy: return true
	var P := _np; var dist := _fd; var q := _bfs; _fd = PackedInt32Array(); _bfs = PackedInt32Array()   # (sole owners: no copies)
	var head := _fh; var tail := _ft; var layer_end := _fle; var d := _fdd
	var up := P + 1; var um := P - 1
	var stop := Time.get_ticks_usec() + budget_usec if budget_usec >= 0 else 0
	while head < tail:
		if head == layer_end: layer_end = tail; d += 1
		if stop != 0 and (head & 511) == 0 and head > _fh and Time.get_ticks_usec() > stop: break
		var c: int = q[head]; head += 1
		var r: int = dist[c + 1]; var l: int = dist[c - 1]; var dn: int = dist[c + P]; var u: int = dist[c - P]
		if r == -1: dist[c + 1] = d; q[tail] = c + 1; tail += 1
		if l == -1: dist[c - 1] = d; q[tail] = c - 1; tail += 1
		if dn == -1: dist[c + P] = d; q[tail] = c + P; tail += 1
		if u == -1: dist[c - P] = d; q[tail] = c - P; tail += 1
		if r >= -1:
			if dn >= -1 and dist[c + up] == -1: dist[c + up] = d; q[tail] = c + up; tail += 1
			if u >= -1 and dist[c - um] == -1: dist[c - um] = d; q[tail] = c - um; tail += 1
		if l >= -1:
			if dn >= -1 and dist[c + um] == -1: dist[c + um] = d; q[tail] = c + um; tail += 1
			if u >= -1 and dist[c - up] == -1: dist[c - up] = d; q[tail] = c - up; tail += 1
	_bfs = q
	if head < tail: _fd = dist; _fh = head; _ft = tail; _fle = layer_end; _fdd = d; return false
	if _fsb: dist[_fs] = 0
	nav_dist = dist; flow_busy = false
	return true

## the way to walk from (x, z) toward the player, or Vector2.ZERO when there is none
func flow_dir(x: float, z: float) -> Vector2:
	var P := _np
	if P == 0: return Vector2.ZERO
	var c := (nav_i(z) + 1) * P + nav_i(x) + 1; var dist := nav_dist; var blk := _pblk
	var bd: int = dist[c]
	if bd < 0: bd = 1000000000
	# the nearest of the eight to the player, the first of equals in this order: right, left, down, up, then the corners
	# (a corner only past two open sides)
	var bk := 0; var d: int = dist[c + 1]
	if d >= 0 and d < bd: bd = d; bk = 1
	d = dist[c - 1]
	if d >= 0 and d < bd: bd = d; bk = -1
	d = dist[c + P]
	if d >= 0 and d < bd: bd = d; bk = P
	d = dist[c - P]
	if d >= 0 and d < bd: bd = d; bk = -P
	d = dist[c + P + 1]
	if d >= 0 and d < bd and blk[c + 1] == 0 and blk[c + P] == 0: bd = d; bk = P + 1
	d = dist[c - P + 1]
	if d >= 0 and d < bd and blk[c + 1] == 0 and blk[c - P] == 0: bd = d; bk = 1 - P
	d = dist[c + P - 1]
	if d >= 0 and d < bd and blk[c - 1] == 0 and blk[c + P] == 0: bd = d; bk = P - 1
	d = dist[c - P - 1]
	if d >= 0 and d < bd and blk[c - 1] == 0 and blk[c - P] == 0: bd = d; bk = -P - 1
	if bk == 0: return Vector2.ZERO
	var nc := c + bk; var bi := nc % P - 1; var bj := nc / P - 1
	return Vector2((bi + 0.5) * nav_cs - nav_off - x, (bj + 0.5) * nav_cs - nav_off - z).normalized()
