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

func collide_at(x: float, y: float, z: float, r: float, h: float) -> Box:
	for b in query_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if y + h <= b.miny or y >= b.maxy - 0.001: continue
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
	for b in query_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if b.maxy <= y + 0.06 and b.maxy > g: g = b.maxy
	return g

func ceil_at(x: float, y: float, z: float, r: float, h: float) -> float:
	var c := INF
	for b in query_near(x - r, z - r, x + r, z + r):
		if x + r <= b.minx or x - r >= b.maxx or z + r <= b.minz or z - r >= b.maxz: continue
		if b.miny >= y + h - 0.05 and b.miny < c: c = b.miny
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
	for b in query_near(minf(o.x, ex), minf(o.z, ez), maxf(o.x, ex), maxf(o.z, ez)):
		if b.grate and not b.glass: continue
		var t0 := 0.0; var t1 := best; var ax := -1; var sg := 0.0
		var lo := [b.minx, b.miny, b.minz]; var hi := [b.maxx, b.maxy, b.maxz]
		var miss := false
		for k in 3:
			var ok: float = o[k]; var dk: float = d[k]
			if absf(dk) < 1e-9:
				if ok < lo[k] or ok > hi[k]: miss = true; break
			else:
				var ta: float = (lo[k] - ok) / dk; var tb: float = (hi[k] - ok) / dk; var s := -1.0
				if ta > tb: var q := ta; ta = tb; tb = q; s = 1.0
				if ta > t0: t0 = ta; ax = k; sg = s
				if tb < t1: t1 = tb
				if t0 > t1: miss = true; break
		if miss: continue
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
var nav_dist := PackedInt32Array()
var _bfs := PackedInt32Array()
const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]

func set_nav(n: int, cs: float) -> void:
	nav_n = n; nav_cs = cs; nav_off = (n * cs) / 2.0; _bfs.resize(n * n)

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
	nav_dist = PackedInt32Array(); nav_dist.resize(n * n); nav_dist.fill(-1)
	for b in colliders: _nav_mark(b, 0, 0, n - 1, n - 1)
	_nav_apply_mask(0, 0, n - 1, n - 1)

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

func update_flow(px: float, pz: float) -> void:
	var n := nav_n
	nav_dist.fill(-1)
	var s := nav_i(pz) * n + nav_i(px)
	var head := 0; var tail := 0
	_bfs[tail] = s; tail += 1; nav_dist[s] = 0
	while head < tail:
		var c := _bfs[head]; head += 1
		var i := c % n; var j := c / n; var d := nav_dist[c] + 1
		for k in 8:
			var di: int = DIRS[k][0]; var dj: int = DIRS[k][1]; var ni := i + di; var nj := j + dj
			if ni < 0 or nj < 0 or ni >= n or nj >= n: continue
			var nc := nj * n + ni
			if nav_dist[nc] != -1 or nav_blocked[nc] != 0: continue
			if di != 0 and dj != 0 and (nav_blocked[j * n + ni] != 0 or nav_blocked[nj * n + i] != 0): continue
			nav_dist[nc] = d; _bfs[tail] = nc; tail += 1

## the way to walk from (x, z) toward the player, or Vector2.ZERO when there is none
func flow_dir(x: float, z: float) -> Vector2:
	var n := nav_n; var i := nav_i(x); var j := nav_i(z)
	var bd := nav_dist[j * n + i]
	if bd < 0: bd = 1000000000
	var bi := -1; var bj := -1
	for k in 8:
		var di: int = DIRS[k][0]; var dj: int = DIRS[k][1]; var ni := i + di; var nj := j + dj
		if ni < 0 or nj < 0 or ni >= n or nj >= n: continue
		var d := nav_dist[nj * n + ni]
		if d < 0 or d >= bd: continue
		if di != 0 and dj != 0 and (nav_blocked[j * n + ni] != 0 or nav_blocked[nj * n + i] != 0): continue
		bd = d; bi = ni; bj = nj
	if bi < 0: return Vector2.ZERO
	return Vector2((bi + 0.5) * nav_cs - nav_off - x, (bj + 0.5) * nav_cs - nav_off - z).normalized()
