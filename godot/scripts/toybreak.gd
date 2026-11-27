class_name ToyBreak
extends RefCounted
## Stage 5 (Godot only): toys do not bleed, they break. What a hit does to each kind (a plastic soldier's skin whitens
## where it was struck and its helmet or pack is knocked off; a brick figure sheds studs, then its hat and its cape; a
## wind-up car's cabin jumps on its gears and wires, and sparks), what a water gun, a soda can and the spray can leave on
## a toy (wet and squeaking, sticky and fizzing, scorched and smoking), how each kind falls (a soldier topples stiff on
## its base, or spins off through the air from a blast; an action figure pops apart at its joints and its head rolls
## away; a wind-up car unwinds, whirls three times, puffs black and tips over, losing a wheel; a brick figure comes apart
## into its bricks), the pieces left lying about (they rattle when someone treads on them) until the claw or the broom's
## shadow clears them away, and the package a toy comes back out of.
## It only shows and sounds: who is hurt, where anyone stands and what they do next are as they were. Nothing here is
## drawn from the game's own random numbers (it has a generator of its own, and its sounds play at pitches it picks),
## so a fight goes as it would have gone without it.

const GRAV := 18.0
const CAP := 84              # pieces lying about at once (a phone: CAP_PHONE); past it the oldest goes
const CAP_PHONE := 44
const LIFE := 36.0           # a piece nobody clears away is gone after this long
const CELL := 2.0            # the squares the lying pieces are sorted into, for whoever treads on them
const SWEEP_EVERY := 15.0    # with enough lying about, the claw (or the broom) comes this often
const SWEEP_MIN := 8
const SWEEP_R := 5.0
const WET_T := 7.0           # how long a soaking shows
const GOO_T := 7.0           # ...and a soda can's syrup
const CHAR_T := 3.2          # seconds alight to be scorched black
const SMOKE_AFTER := 2.5     # it smokes on this long after the fire is out
const MARKS := 5             # stress marks kept on one part of a soldier
const HEAR := 42.0           # beyond this a breakage makes no sound at all
const BURST := 40            # pieces made in one frame before the rest who fall in it simply burst into specks (a blast among many)

# a piece's state
enum { FLY, SETTLE, REST, GOING, HELD }

class Piece:
	var n: Node3D                    # it turns about this node's origin: the middle of the part
	var v := Vector3.ZERO
	var w := Vector3.ZERO            # how it tumbles: an axis times radians a second
	var half := Vector3.ONE * 0.1    # half its size, along its own axes
	var low := 0.1                   # how high its middle rides while it tumbles
	var state := FLY
	var age := 0.0; var life := 36.0
	var kind := "plastic"            # what it sounds like: plastic, brick, metal, card
	var roll := 0.0                  # a round thing's radius (a head, a wheel): it rolls on
	var heavy := false               # a whole body: it is not kicked about
	var small := false               # too small to tread on
	var bounce := 0.34
	var hits := 0
	var t := 0.0                     # the time left of settling flat, or of going
	var q0 := Quaternion.IDENTITY; var q1 := Quaternion.IDENTITY; var y1 := 0.0
	var cell := Vector2i.ZERO; var filed := false
	var calm := 0.0                  # no rattle again until this has run out
	var off := Vector3.ZERO          # held by the claw: where it hangs under it
	var fuse := false                # once it lies still its meshes are made one

var tf: ToyFoes
var rng := RandomNumberGenerator.new()
var root: Node3D = null
var pieces: Array[Piece] = []
var cells := {}
var active: Array = []       # toys with something showing that runs out or moves: wet, sticky, smoking, a cabin on its spring
var packs: Array = []        # packages being torn open
var claw: Dictionary = {}    # the claw on its way (empty: none)
var broom: Dictionary = {}   # ...or the broom's shadow
var sweep_t := SWEEP_EVERY
var clock := 0.0
var on_splash: Callable = Callable()   # (the HUD: water on the glass)
var stats := {"marks": 0, "pieces": 0, "sweeps": 0, "packs": 0, "bursts": 0}   # (for the checks)
var _snd_at := {}
var _mats := {}
var _tread_t := 0.0
var _made := 0               # pieces made since the last frame

func _init() -> void:
	rng.seed = 0x70795f62

func en() -> Enemies: return tf.en
func cap() -> int: return CAP_PHONE if tf.en.phone else CAP
func on() -> bool: return tf.world != null and tf.world.toy != null and tf.en != null and tf.en.is_inside_tree()

func _root() -> Node3D:
	if root == null or not is_instance_valid(root): root = Node3D.new(); root.name = "Breaks"; tf.en.add_child(root)
	return root

func clear() -> void:
	if root != null and is_instance_valid(root): root.queue_free()
	root = null; pieces.clear(); cells.clear(); active.clear(); packs.clear(); claw = {}; broom = {}; sweep_t = SWEEP_EVERY; _snd_at.clear(); clock = 0.0
	if _warm != null and is_instance_valid(_warm): _warm.queue_free()
	_warm = null; _warm_n = 0

## as the toy room starts: the pictures, shapes and skins made once now (a stress mark's picture alone is a sixtieth of a
## second's work), and each new kind of material drawn for a few frames, a speck at the foot of the view, so the renderer
## has it ready before the first hit of the fight needs it
func prepare() -> void:
	if not on(): return
	var mats: Array = [_mark_mat(), _clear_mat(), _shadow_mat(), _wheel_mat(), plastic(Color.WHITE)]
	for fl: String in GOO_COL: mats.push_back(_goo_mat(fl))
	for key: Array in [["s10", true, "", 0], ["s0cola0", false, "cola", 0], ["s02", false, "", 2]]: mats.push_back(_shared_skin(key[0], key[1], key[2], key[3]))
	var rim := Gfx.std(Color.WHITE, 0.07); rim.rim_enabled = true; mats.push_back(rim)   # (a soldier's own plastic, wet)
	_strand_mesh(); half_mesh(-1.0); half_mesh(1.0)
	var cam := tf.en.cam
	if cam == null or not cam.is_inside_tree(): return
	if _warm != null and is_instance_valid(_warm): _warm.queue_free()
	_warm = Node3D.new(); cam.add_child(_warm); _warm_n = 12
	for i in mats.size():
		var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.003, 0.003); mi.mesh = q; mi.material_override = mats[i]; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(-0.2 + i * 0.006, -0.22, -0.6); _warm.add_child(mi)
var _warm: Node3D = null
var _warm_n := 0

# ---------------- little helpers ----------------
func rnd(a: float, b: float) -> float: return rng.randf_range(a, b)
func _rv(h: float, up0: float, up1: float) -> Vector3: return Vector3(rnd(-h, h), rnd(up0, up1), rnd(-h, h))

## a sound of the breakages: not farther than HEAR from the listener, and the same one not again within gap seconds
func snd(name: String, at: Vector3, gain := 1.0, gap := 0.05, pitch := 0.0) -> bool:
	if at.distance_to(Snd.listener) > HEAR: return false
	if clock - float(_snd_at.get(name, -9.0)) < gap: return false
	_snd_at[name] = clock; Snd.toy(name, gain, at, pitch if pitch > 0.0 else rnd(0.94, 1.06)); return true

## a speck of the toy room's own (as Fx._bit: its size a radius), with nothing drawn from the game's numbers
func bit(at: Vector3, col: Color, life: float, vel: Vector3, s0: float, s1: float, grav := 0.0, add := false, drag := 0.0) -> void:
	if tf.fx != null: tf.fx._bit(at, col, life, vel, s0, s1, grav, add, drag)

func _mat(key: String, make: Callable) -> Material:
	if not _mats.has(key): _mats[key] = make.call()
	return _mats[key]

## solid plastic of one colour (a soldier's helmet once it is off him: his own skin fades with him)
func plastic(col: Color) -> Material:
	return _mat("p" + col.to_html(false), func() -> Material: return Gfx.std(Color(col, 1.0), 0.45))

# ---------------- the pieces ----------------
## the box round a node's meshes (its own and those under it), in its frame
static func bounds(n: Node3D) -> AABB:
	var out := AABB(); var any := false; var all: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D: all.push_back(n)
	for c in all:
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var t := Transform3D.IDENTITY; var a: Node = mi
		while a != n: t = (a as Node3D).transform * t; a = a.get_parent()
		var bb: AABB = t * mi.mesh.get_aabb()
		out = out.merge(bb) if any else bb; any = true
	return out if any else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))

## a node that is somewhere in the scene becomes a piece: from now on it tumbles about its own middle. It stays where
## it is and as it is turned; the oldest piece makes room for it when there are too many
func take(n: Node3D, v: Vector3, w: Vector3, kind := "plastic", life := LIFE) -> Piece:
	var bb := bounds(n); var gt := n.global_transform; var sc := gt.basis.get_scale()
	var h := Node3D.new(); _root().add_child(h)
	h.global_transform = Transform3D(Basis(gt.basis.get_rotation_quaternion()), gt * bb.get_center())
	n.reparent(h, true)
	var p := Piece.new(); p.n = h; p.v = v; p.w = w; p.kind = kind; p.life = life
	p.half = Vector3(maxf(0.01, bb.size.x * sc.x * 0.5), maxf(0.01, bb.size.y * sc.y * 0.5), maxf(0.01, bb.size.z * sc.z * 0.5))
	p.low = (p.half.x + p.half.y + p.half.z) / 3.0
	_room(); pieces.push_back(p); stats.pieces = int(stats.pieces) + 1; _made += 1
	return p

## a new piece made of boxes (a mesh of that name, made once), at a place and a turn
func make(key: String, parts: Array, at: Transform3D, v: Vector3, w: Vector3, kind := "plastic", mat: Material = null) -> Piece:
	var n := Node3D.new(); _root().add_child(n); n.global_transform = at
	var mi := MeshInstance3D.new(); mi.mesh = tf.en._box_mesh(key, parts); mi.material_override = mat if mat != null else tf.en._mat; n.add_child(mi)
	return take(n, v, w, kind)

func _room() -> void:
	var live := 0; var oldest: Piece = null
	for p in pieces:
		if p.state == GOING or p.state == HELD: continue
		live += 1
		if oldest == null or p.age > oldest.age: oldest = p
	if live >= cap() and oldest != null: _go(oldest, 0.15)

func _go(p: Piece, t := 0.25) -> void:
	if p.state == GOING: return
	_unfile(p); p.state = GOING; p.t = t; p.life = t; p.v = Vector3.ZERO

func _file(p: Piece) -> void:
	var c := Vector2i(floori(p.n.position.x / CELL), floori(p.n.position.z / CELL)); p.cell = c; p.filed = true
	if not cells.has(c): cells[c] = []
	(cells[c] as Array).push_back(p)

func _unfile(p: Piece) -> void:
	if not p.filed: return
	p.filed = false
	if cells.has(p.cell):
		(cells[p.cell] as Array).erase(p)
		if (cells[p.cell] as Array).is_empty(): cells.erase(p.cell)

## how many lie still (what the claw comes for)
func lying() -> int:
	var n := 0
	for p in pieces:
		if p.state == REST: n += 1
	return n

## what a piece comes down on at a place: the highest thing under it, and on the bare floor the rug's top where the rug lies
static func floor_at(x: float, y: float, z: float, r := 0.08) -> float:
	var gy := Phys.ground_at(x, y, z, r)
	return gy + ToyRoom.rug(x, z) if gy < 0.01 else gy

## the piece has stopped: it tips onto a flat side (the one nearest down, or its broadest when it stands on end) and lies
func _rest(p: Piece, gy: float) -> void:
	var q := p.n.quaternion; var b := Basis(q); var h := [p.half.x, p.half.y, p.half.z]
	var best := 0; var best_d := -1.0
	for i in 3:
		var d := absf((b[i] as Vector3).y)
		if d > best_d: best_d = d; best = i
	var least := 0
	for i in 3:
		if float(h[i]) < float(h[least]): least = i
	if float(h[best]) > float(h[least]) * 1.6: best = least   # standing on an end or an edge: over onto its broad side
	var ax: Vector3 = b[best]; var sgn := 1.0 if ax.y >= 0.0 else -1.0; var to := Vector3.UP * sgn
	var turn := Quaternion.IDENTITY
	if ax.distance_to(to) > 0.001:
		var cr := ax.cross(to)
		turn = Quaternion(cr.normalized(), ax.angle_to(to)) if cr.length() > 0.0001 else Quaternion(Vector3.RIGHT, PI)
	p.q0 = q; p.q1 = (turn * q).normalized(); p.y1 = gy + float(h[best]); p.state = SETTLE; p.t = 0.16; p.v = Vector3.ZERO; p.w = Vector3.ZERO

func _tap(p: Piece, hard: float) -> void:
	if p.small: return
	var at := p.n.position
	if p.kind == "brick": snd("toy_rattle", at, clampf(hard * 0.16, 0.25, 0.9), 0.06, rnd(0.9, 1.25))
	elif p.kind == "metal": snd("toy_stud", at, clampf(hard * 0.2, 0.3, 0.9), 0.06, rnd(0.6, 0.8))
	elif p.kind == "card": pass
	elif p.heavy: snd("toy_clatter", at, clampf(hard * 0.14, 0.35, 1.0), 0.12)
	else: snd("toy_rattle", at, clampf(hard * 0.12, 0.2, 0.7), 0.07, rnd(0.62, 0.82))

## one piece's turn in the air or along the floor
func _fly(p: Piece, dt: float) -> void:
	var n := p.n; var pos := n.position; var low := p.roll if p.roll > 0.0 else p.low
	p.v.y -= GRAV * dt
	var hx := p.v.x * dt; var hz := p.v.z * dt
	if absf(hx) + absf(hz) > 0.0004:   # sideways: off the walls (an upright stub stands in for it)
		var res := Phys.move_xz(Vector3(pos.x, pos.y - low + 0.07, pos.z), hx, hz, 0.1, maxf(0.14, low), 0.0); var q: Vector3 = res[0]
		if res[1]:
			var sp := Vector2(p.v.x, p.v.z).length()
			if absf(q.x - (pos.x + hx)) > 0.0004: p.v.x *= -p.bounce
			if absf(q.z - (pos.z + hz)) > 0.0004: p.v.z *= -p.bounce
			if sp > 1.2: _tap(p, sp)
			if p.roll > 0.0: p.v.x *= 0.3; p.v.z *= 0.3   # a rolling thing stops against a wall
			p.hits += 1
		pos.x = q.x; pos.z = q.z; var lim := Phys.HALF - 0.15   # (the room's edge stops it as a wall does)
		if absf(pos.x) > lim: pos.x = clampf(pos.x, -lim, lim); p.v.x *= -p.bounce * (0.3 if p.roll > 0.0 else 1.0)
		if absf(pos.z) > lim: pos.z = clampf(pos.z, -lim, lim); p.v.z *= -p.bounce * (0.3 if p.roll > 0.0 else 1.0)
	var ny := pos.y + p.v.y * dt; var down := false
	if p.v.y <= 0.0:
		var gy := floor_at(pos.x, pos.y - low + 0.02, pos.z)
		if ny - low <= gy:
			ny = gy + low; down = true; var vy := -p.v.y
			if vy > 2.2:   # a bounce
				p.v.y = vy * p.bounce; p.v.x *= 0.72; p.v.z *= 0.72; p.hits += 1; _tap(p, vy)
				p.w = p.w * 0.55 + Vector3(rnd(-2, 2), rnd(-2, 2), rnd(-2, 2))
			else:
				p.v.y = 0.0
				var slow := exp(-dt * (0.85 if p.roll > 0.0 else 7.0)); p.v.x *= slow; p.v.z *= slow; p.w *= exp(-dt * 6.0)
				if Vector2(p.v.x, p.v.z).length() < (0.3 if p.roll > 0.0 else 0.45) or p.age > 7.0: pos.y = ny; n.position = pos; _rest(p, gy); return
	pos.y = ny; n.position = pos
	if p.roll > 0.0 and down:   # rolling: it turns as fast as it goes
		var hv := Vector3(p.v.x, 0.0, p.v.z); var s := hv.length()
		if s > 0.05: n.quaternion = (Quaternion(Vector3.UP.cross(hv / s), s / p.roll * dt) * n.quaternion).normalized()
	else:
		var wl := p.w.length()
		if wl > 0.01: n.quaternion = (Quaternion(p.w / wl, wl * dt) * n.quaternion).normalized()

## every piece's turn: flying, tipping flat, lying (until its time is up), shrinking away
func _pieces(dt: float) -> void:
	for i in range(pieces.size() - 1, -1, -1):
		var p := pieces[i]; p.age += dt; p.calm -= dt
		match p.state:
			FLY: _fly(p, dt)
			SETTLE:
				p.t -= dt; var u := clampf(1.0 - p.t / 0.16, 0.0, 1.0); u = u * u * (3.0 - 2.0 * u)
				p.n.quaternion = p.q0.slerp(p.q1, u); p.n.position.y = lerpf(p.n.position.y, p.y1, u)
				if p.t <= 0.0:
					p.state = REST; _file(p)
					if p.fuse: p.fuse = false; fuse(p)
			REST:
				if p.age > p.life: _go(p)
			GOING:
				p.t -= dt; p.n.scale = Vector3.ONE * maxf(0.001, p.t / maxf(p.life, 0.001)); p.n.position += p.v * dt   # (swept: carried along as it goes)
				if p.t <= 0.0: p.n.queue_free(); pieces.remove_at(i)

## a piece that lies still is drawn as one mesh for each material on it from here on (a toppled soldier is six meshes
## and his marks; a car its body, key, cabin and works)
func fuse(p: Piece) -> void:
	var groups := {}; var n := 0
	for c in p.n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not (mi.mesh is ArrayMesh) or mi.mesh.get_surface_count() == 0 or not mi.is_visible_in_tree() or mi.material_override == null: continue
		var t := Transform3D.IDENTITY; var a: Node = mi
		while a != p.n: t = (a as Node3D).transform * t; a = a.get_parent()
		if not groups.has(mi.material_override): groups[mi.material_override] = []
		(groups[mi.material_override] as Array).push_back([mi, t]); n += 1
	if n < 2: return
	var made: Array = []
	for mat: Material in groups:
		var vs := PackedVector3Array(); var ns := PackedVector3Array(); var cs := PackedColorArray(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
		for it: Array in groups[mat]:
			var arr: Array = ((it[0] as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0); var t: Transform3D = it[1]; var nb := t.basis.inverse().transposed(); var o := vs.size()
			var v0: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in v0: vs.push_back(t * v)
			for nv: Vector3 in arr[Mesh.ARRAY_NORMAL]: ns.push_back((nb * nv).normalized())
			if arr[Mesh.ARRAY_COLOR] != null: cs.append_array(arr[Mesh.ARRAY_COLOR])
			else:
				for k in v0.size(): cs.push_back(Color.WHITE)
			if arr[Mesh.ARRAY_TEX_UV] != null: uv.append_array(arr[Mesh.ARRAY_TEX_UV])
			else: uv.resize(vs.size())
			for k: int in arr[Mesh.ARRAY_INDEX]: idx.push_back(k + o)
		var out := []; out.resize(Mesh.ARRAY_MAX); out[Mesh.ARRAY_VERTEX] = vs; out[Mesh.ARRAY_NORMAL] = ns; out[Mesh.ARRAY_COLOR] = cs; out[Mesh.ARRAY_TEX_UV] = uv; out[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		var one := MeshInstance3D.new(); one.mesh = am; one.material_override = mat; made.push_back(one)
	for c in p.n.get_children(): c.queue_free()
	for one: MeshInstance3D in made: p.n.add_child(one)

## someone walks over the pieces: they rattle and are kicked along (a whole body only knocks)
func tread(at: Vector3, vel: Vector3, r: float) -> int:
	if cells.is_empty(): return 0
	var n := 0; var x0 := floori((at.x - r - 0.3) / CELL); var x1 := floori((at.x + r + 0.3) / CELL); var z0 := floori((at.z - r - 0.3) / CELL); var z1 := floori((at.z + r + 0.3) / CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var c := Vector2i(cx, cz)
			if not cells.has(c): continue
			for p: Piece in (cells[c] as Array).duplicate():
				if p.state != REST or p.small or p.calm > 0.0: continue
				var q := p.n.position
				if absf(q.y - at.y) > 0.7 or Vector2(q.x - at.x, q.z - at.z).length() > r + maxf(p.half.x, p.half.z) * 0.6: continue
				n += 1; p.calm = 0.9
				if p.heavy: snd("toy_clatter", q, 0.45, 0.25, rnd(1.1, 1.3)); continue
				snd("toy_rattle", q, 0.8, 0.07, rnd(0.9, 1.2) if p.kind == "brick" else rnd(0.65, 0.85))
				var d := Vector3(vel.x, 0.0, vel.z); d = d.normalized() if d.length() > 0.2 else Vector3(rnd(-1, 1), 0.0, rnd(-1, 1)).normalized()
				_unfile(p); p.state = FLY; p.hits = 0; p.age = minf(p.age, p.life - 3.0)
				p.v = d * rnd(1.4, 2.8) + Vector3(rnd(-0.6, 0.6), rnd(1.2, 2.4), rnd(-0.6, 0.6)); p.w = Vector3(rnd(-7, 7), rnd(-7, 7), rnd(-7, 7))
	return n

# ---------------- a hit ----------------
## a toy was hit (by you, by a blast, by a toy of the other side): what shows of it. Called for every hit, the last too
func struck(e: Enemies.Foe, at: Vector3, dir: Vector3, weak: bool, dmg: float) -> void:
	if not on() or e.g == null or not e.g.visible or _made >= BURST: return   # (nor in a moment when too much is breaking already)
	match e.type:
		"soldier": _hit_soldier(e, at, dir, weak, dmg)
		"brick": _hit_brick(e, at, dir, weak)
		"rc": _hit_rc(e, at)
		_: _hit_figure(e, at, dir)
	if tf.en.cause == "shotgun": wet(e)   # the pump water gun

# ---- plastic soldiers: the skin whitens where it was struck; a shot to the head knocks the helmet off, a hard one the pack
const S_UP := [[Vector3(0, 0.36, 0), Vector3(0.22, 0.31, 0.13)], [Vector3(0, 0.8, 0.01), Vector3(0.11, 0.125, 0.12)]]   # the torso's box and the head's, in the upper half's frame
const S_LEG := [[Vector3(0, -0.45, 0), Vector3(0.075, 0.45, 0.085)]]
func _hit_soldier(e: Enemies.Foe, at: Vector3, dir: Vector3, weak: bool, dmg: float) -> void:
	var k := e.k
	_mark(e, at)
	if weak and bool(k.get("helmet", false)): _shed_soldier(e, "helmet", dir)
	elif bool(k.get("pack", false)) and (dmg >= e.max_hp * 0.3 or e.hp <= e.max_hp * 0.5): _shed_soldier(e, "pack", dir)

func _shed_soldier(e: Enemies.Foe, what: String, dir: Vector3) -> void:
	var k := e.k; k[what] = false
	var hel := bool(k.get("helmet", false)); var pk := bool(k.get("pack", false))
	(e.upper.get_child(0) as MeshInstance3D).mesh = tf.en._box_mesh("ts_up" + ("h" if hel else "") + ("p" if pk else ""), ToyFoes.soldier_up(hel, pk))
	var W := "ffffff"; var m: StandardMaterial3D = k.mat; var col: Color = k.get("col0", Color(m.albedo_color, 1.0))
	var d := Vector3(dir.x, 0.0, dir.z); d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)
	if what == "helmet":
		var p := make("ts_helmet", [[0.3, 0.1, 0.32, 0, 0, 0, W]], e.upper.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), d * rnd(1.8, 3.2) + _rv(1.0, 4.2, 5.6), _rv(9.0, -9.0, 9.0), "plastic", plastic(col))
		p.bounce = 0.4
	else:
		make("ts_pack", [[0.3, 0.34, 0.14, 0, 0, 0, W]], e.upper.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.42, -0.2)), d * rnd(1.5, 2.6) + _rv(1.0, 3.0, 4.2), _rv(7.0, -7.0, 7.0), "plastic", plastic(col))
	snd("toy_stud", e.pos + Vector3(0, 1.5, 0), 0.8, 0.05, rnd(0.6, 0.75))

## the pale mark of bent plastic, on the face of the part nearest where the shot struck
func _mark(e: Enemies.Foe, at: Vector3) -> void:
	var p: Vector3 = e.upper.global_transform.affine_inverse() * at
	var anchor: Node3D = e.upper; var boxes: Array = S_UP; var name := "up"
	if p.y < 0.02:   # below the belt: the leg on that side
		name = "ll" if p.x < 0.0 else "lr"; anchor = e.leg_l if p.x < 0.0 else e.leg_r; p = anchor.global_transform.affine_inverse() * at; boxes = S_LEG
	var bx: Array = boxes[1] if (boxes.size() > 1 and p.y > 0.68) else boxes[0]
	var c: Vector3 = bx[0]; var h: Vector3 = bx[1]; var d := p - c; var ax := 0; var best := -1.0
	for i in 3:
		var f := absf(d[i]) / h[i]
		if f > best: best = f; ax = i
	var nrm := Vector3.ZERO; nrm[ax] = 1.0 if d[ax] >= 0.0 else -1.0
	var q := Vector3(clampf(d.x, -h.x * 0.8, h.x * 0.8), clampf(d.y, -h.y * 0.85, h.y * 0.85), clampf(d.z, -h.z * 0.8, h.z * 0.8)); q[ax] = (h[ax] + 0.006) * nrm[ax]
	if not e.k.has("marks"): e.k.marks = {}
	var marks: Dictionary = e.k.marks
	if not marks.has(name):
		var mi := MeshInstance3D.new(); mi.mesh = ArrayMesh.new(); mi.material_override = _mark_mat(); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; anchor.add_child(mi)
		marks[name] = {"mi": mi, "list": []}
	var L: Array = marks[name].list
	L.push_back([c + q, nrm, rnd(0.075, 0.11), rnd(0.0, TAU)])
	if L.size() > MARKS: L.pop_front()
	_mark_mesh(marks[name].mi, L); stats.marks = int(stats.marks) + 1

func _mark_mesh(mi: MeshInstance3D, L: Array) -> void:
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for it: Array in L:
		var o: Vector3 = it[0]; var n: Vector3 = it[1]; var s: float = it[2]
		var u := n.cross(Vector3.UP) if absf(n.y) < 0.9 else Vector3.RIGHT; u = u.normalized().rotated(n, float(it[3])); var v := n.cross(u)
		var j := vs.size()
		vs.append_array([o - u * s - v * s, o + u * s - v * s, o + u * s + v * s, o - u * s + v * s]); ns.append_array([n, n, n, n])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]); idx.append_array([j, j + 1, j + 2, j, j + 2, j + 3])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_INDEX] = idx
	var am := mi.mesh as ArrayMesh; am.clear_surfaces(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

## the picture of a stress mark: a pale blotch with a ragged edge, whiter at its heart, and streaks running out of it
static func mark_image() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); var r := RandomNumberGenerator.new(); r.seed = 77; var streaks := []; var lobes := []
	for i in 6: streaks.push_back([r.randf() * TAU, r.randf_range(0.55, 1.0)])
	for i in 7: lobes.push_back([r.randf() * TAU, r.randf_range(0.5, 1.0)])
	for y in 64:
		for x in 64:
			var p := Vector2((x + 0.5) / 64.0 - 0.5, (y + 0.5) / 64.0 - 0.5) * 2.0; var d := p.length(); var ang := p.angle(); var edge := 0.5
			for l: Array in lobes: edge += 0.06 * float(l[1]) * cos((ang - float(l[0])) * (2.0 + float(l[1]) * 3.0))   # the ragged edge
			var a := smoothstep(edge, edge * 0.45, d) * 0.9
			for s: Array in streaks:
				var dir := Vector2(cos(s[0]), sin(s[0])); var along := p.dot(dir); var off := absf(p.x * dir.y - p.y * dir.x); var reach := float(s[1]) * 0.95
				if along > 0.0 and along < reach: a = maxf(a, clampf(1.0 - off / 0.06, 0.0, 1.0) * clampf(1.0 - along / reach, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps(); return img

func _mark_mat() -> Material:
	if not _mats.has("mark"):
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.97, 0.98, 0.95, 0.95); m.albedo_texture = ImageTexture.create_from_image(mark_image())
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.95; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if Gfx.fplus: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.disable_fog = true   # (the computer's renderer mixes see-through things in its own way: Gfx.see_through; there the mark is its own pale colour)
		_mats["mark"] = Gfx.see_through(m)
	return _mats["mark"]

## a soldier's marks fade with him when he goes see-through
func fade(e: Enemies.Foe, alpha: float) -> void:
	if not e.k.has("marks"): return
	for name in e.k.marks: (e.k.marks[name].mi as MeshInstance3D).transparency = clampf(1.0 - alpha, 0.0, 1.0)

# ---- brick figures: studs pop off at every hit; the hat goes at two thirds of its health (or to a shot at the head),
# the cape at one third; mended, they are back on
func _hit_brick(e: Enemies.Foe, at: Vector3, dir: Vector3, weak: bool) -> void:
	var col := Color(str(e.k.get("tint", "d62828")))
	for i in 3: bit(at, Color(col, 1.0), rnd(0.35, 0.6), -dir * rnd(0.5, 2.0) + _rv(2.2, 1.0, 3.6), 0.035, 0.03, 15.0)
	snd("toy_stud", at, 0.6, 0.06, rnd(0.95, 1.3))
	if weak and bool(e.k.get("hat", false)): e.k.hat_shot = true
	dress(e, dir)

## what a brick figure wears goes by its health
func dress(e: Enemies.Foe, dir := Vector3.ZERO) -> void:
	if e.type != "brick" or e.g == null or not e.k.has("acc"): return
	var k := e.k; var f := e.hp / maxf(e.max_hp, 1.0)
	if f >= 0.999: k.hat_shot = false
	var hat := f > 0.667 and not bool(k.get("hat_shot", false)); var cape := f > 0.334
	if hat == bool(k.hat) and cape == bool(k.cape): return
	var d := Vector3(dir.x, 0.0, dir.z); d = d.normalized() if d.length() > 0.01 else Vector3(sin(e.yaw), 0.0, cos(e.yaw))
	if on() and e.g.visible:
		if bool(k.hat) and not hat: _brick_bit(e, "hat", d)
		if bool(k.cape) and not cape: _brick_bit(e, "cape", d)
		if (hat and not bool(k.hat)) or (cape and not bool(k.cape)): snd("toy_stud", e.pos + Vector3(0, 1.5, 0), 0.6, 0.05, 1.5)
	k.hat = hat; k.cape = cape
	var cb := str(k.get("tint", "d62828")); var acc := str(k.acc)
	(e.upper.get_child(0) as MeshInstance3D).mesh = tf.en._box_mesh("tb_up" + ("h" if hat else "") + ("c" if cape else "") + cb, ToyFoes.brick_up(cb, acc, hat, cape))

func _brick_bit(e: Enemies.Foe, what: String, d: Vector3) -> Piece:
	var acc := str(e.k.acc); var ut := e.upper.global_transform; var mat := _skin_of(e)
	if what == "hat":
		return make("tbp_hat" + acc, [[0.36, 0.1, 0.36, 0, 0, 0, acc], [0.16, 0.07, 0.16, 0, 0.085, 0, acc]], ut * Transform3D(Basis.IDENTITY, Vector3(0, 1.02, 0)), d * rnd(1.0, 2.4) + _rv(1.4, 3.6, 5.2), _rv(8.0, -8.0, 8.0), "brick", mat)
	return make("tbp_cape" + acc, [[0.48, 0.52, 0.03, 0, 0, 0, acc]], ut * Transform3D(Basis.IDENTITY, Vector3(0, 0.36, -0.17)), d * rnd(0.8, 1.8) + _rv(1.2, 2.2, 3.6), _rv(6.0, -6.0, 6.0), "brick", mat)

# ---- wind-up cars: the cabin jumps on its hinge over the gears and wires, and it sparks; the worse off, the wider it gapes
func _hit_rc(e: Enemies.Foe, at: Vector3) -> void:
	var k := e.k
	if not k.has("panel"): _open_rc(e)
	k.pan_v = float(k.get("pan_v", 0.0)) + rnd(5.0, 8.0)
	for i in 3: bit(at, Color(0.65, 0.88, 1.0, 1.0), rnd(0.1, 0.2), _rv(3.0, -0.5, 3.0), 0.035, 0.008, 3.0, true)
	bit(at, Color(1.0, 0.85, 0.35, 1.0), 0.3, _rv(1.5, 0.5, 2.0), 0.05, 0.01, 5.0, true)
	snd("toy_zap", at, 0.5, 0.12); _wake(e)

func _open_rc(e: Enemies.Foe) -> void:
	var k := e.k; var cc := str(k.get("tint", "e63946")); var mat := _skin_of(e)
	(e.body.get_child(0) as MeshInstance3D).mesh = tf.en._box_mesh("tr_body_o" + cc, ToyFoes.rc_body(cc, false))
	k.guts = tf._node(e.g, Vector3.ZERO, ToyFoes.rc_guts(), "tr_guts", mat)
	k.panel = tf._node(e.g, Vector3(0, 0.49, -0.5), [[0.7, 0.26, 0.8, 0, 0.13, 0.4, "dfe8ee"]], "tr_cabin", mat)   # hinged at its back edge
	k.pan = 0.0
	if k.has("body"): (k.body as Array).append_array([(k.guts as Node3D).get_child(0), (k.panel as Node3D).get_child(0)])

## how far the cabin stands open when nothing shakes it
static func rc_gape(f: float) -> float: return 0.0 if f > 0.66 else (0.16 if f > 0.33 else 0.38)

# ---- action figures: chips of their own colour
func _hit_figure(e: Enemies.Foe, at: Vector3, dir: Vector3) -> void:
	var col := Color(str(e.k.get("tint", "d62828")))
	for i in 2: bit(at, Color(col, 1.0), rnd(0.25, 0.45), -dir * rnd(0.5, 1.5) + _rv(1.8, 0.6, 2.6), 0.03, 0.02, 14.0)

# ---------------- what a weapon leaves on a toy ----------------
const GOO_COL := {"cola": Color(0.5, 0.25, 0.08), "grape": Color(0.5, 0.2, 0.7)}
func _wake(e: Enemies.Foe) -> void:
	if not active.has(e): active.push_back(e)

## soaked by the water gun: a wet shine, drips, and its feet squeak as it walks
func wet(e: Enemies.Foe) -> void:
	e.k.wet = WET_T; _skin(e); _wake(e)

## in a burst soda can's syrup: brown or purple and sticky, strings from its feet to the floor, bubbles rising
func goo(e: Enemies.Foe, flavour: String) -> void:
	var fresh: bool = float(e.k.get("goo_t", 0.0)) <= 0.0 or str(e.k.get("goo", "")) != flavour
	e.k.goo = flavour; e.k.goo_t = GOO_T
	if fresh: _skin(e); _wake(e); snd("toy_fizz", e.pos, 0.6, 0.6)

## which soda a can is: it goes by where it bursts (the same every time)
static func flavour(at: Vector3) -> String: return "grape" if (int(floor(absf(at.x) * 3.0)) + int(floor(absf(at.z) * 3.0))) % 2 == 0 else "cola"

## a can bursts: everyone in its puddle from the start
func soda(at: Vector3, r: float, units: Array) -> void:
	if not on(): return
	var fl := flavour(at); var c: Color = GOO_COL[fl]
	for i in 14: bit(at + Vector3(rnd(-0.4, 0.4), 0.2, rnd(-0.4, 0.4)), Color(c.lightened(0.15), 0.85), rnd(0.5, 0.9), _rv(3.2, 2.0, 5.5), 0.06, 0.03, 13.0)
	snd("toy_fizz", at, 1.0, 0.3)
	for u in units:
		if u.alive and Vector2(u.pos.x - at.x, u.pos.z - at.z).length() < r and absf(u.pos.y - at.y) < 1.2: goo(u, fl)

## you stand in the syrup: bubbles about your feet, and it fizzes
func goo_feet(at: Vector3, fl: String, dt: float) -> void:
	if not on(): return
	if rng.randf() < dt * 14.0: bit(at + Vector3(rnd(-0.5, 0.5), 0.05, rnd(-0.5, 0.5)), Color(1.0, 0.95, 0.85, 0.7), rnd(0.5, 0.9), Vector3(rnd(-0.1, 0.1), rnd(0.5, 1.1), rnd(-0.1, 0.1)), 0.02, 0.035, -0.6)
	if rng.randf() < dt * 5.0: bit(at + Vector3(rnd(-0.4, 0.4), 0.3, rnd(-0.4, 0.4)), Color(GOO_COL[fl], 0.8), 0.4, Vector3(0, -0.6, 0), 0.03, 0.02, 10.0)
	snd("toy_fizz", at, 0.7, 1.1)

## the spray can's fire is on it (called each frame it burns): its plastic scorches black, and smoke stands over it
func burning(e: Enemies.Foe, dt: float) -> void:
	if not on() or e.g == null: return
	e.k.char = minf(1.0, float(e.k.get("char", 0.0)) + dt / CHAR_T); e.k.smoke = SMOKE_AFTER; _skin(e); _wake(e)

static func skin_col(base: Color, wet_on: bool, goo_on: String, ch: int) -> Color:
	var c := base
	if wet_on: c = Color(c.r * 0.8, c.g * 0.84, c.b * 0.9)
	if goo_on != "": c = c.lerp(GOO_COL[goo_on], 0.6)
	if ch > 0: c = c.lerp(Color(0.035, 0.03, 0.03), [0.0, 0.4, 0.66, 0.85][ch])
	return Color(c.r, c.g, c.b, 1.0)
static func skin_rough(base: float, wet_on: bool, goo_on: String, ch: int) -> float:
	if ch >= 2: return 0.97
	if goo_on != "": return 0.16
	return 0.07 if wet_on else base

## the meshes of a toy that wear the shared skin (found once; what is added to it later is added here)
func _body(e: Enemies.Foe) -> Array:
	if not e.k.has("body"):
		var out := []
		for n in e.g.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).material_override == tf.en._mat: out.push_back(n)
		e.k.body = out
	return e.k.body

## the skin a toy wears now (for a part made new for it)
func _skin_of(e: Enemies.Foe) -> Material:
	if e.type == "soldier": return e.k.mat
	var key := str(e.k.get("skin", "s00"))
	return _mats[key] if (key != "s00" and _mats.has(key)) else tf.en._mat

## a toy's skin for what is on it now: dry or wet, clean or sticky, how badly scorched (a soldier has plastic of his own
## to change; the others share theirs, one skin for each state)
func _skin(e: Enemies.Foe) -> void:
	var k := e.k; var wet_on := float(k.get("wet", 0.0)) > 0.0; var goo_on := str(k.get("goo", "")) if float(k.get("goo_t", 0.0)) > 0.0 else ""
	var ch := int(floor(clampf(float(k.get("char", 0.0)), 0.0, 1.0) * 3.0 + 0.001))
	var key := "s%d%s%d" % [1 if wet_on else 0, goo_on, ch]
	if key == str(k.get("skin", "s00")): return
	k.skin = key
	if e.type == "soldier":
		var m: StandardMaterial3D = k.mat
		if not k.has("col0"): k.col0 = Color(m.albedo_color, 1.0); k.rough0 = m.roughness
		var c := skin_col(k.col0, wet_on, goo_on, ch); m.albedo_color = Color(c.r, c.g, c.b, m.albedo_color.a); m.roughness = skin_rough(float(k.rough0), wet_on, goo_on, ch)
		m.rim_enabled = (wet_on or goo_on != "") and ch < 2; m.rim = 0.9; m.rim_tint = 0.25
		return
	var mat: Material = tf.en._mat if key == "s00" else _shared_skin(key, wet_on, goo_on, ch)
	for mi: MeshInstance3D in _body(e): mi.material_override = mat

func _shared_skin(key: String, wet_on: bool, goo_on: String, ch: int) -> Material:
	if not _mats.has(key):
		var d: StandardMaterial3D = (tf.en._mat as StandardMaterial3D).duplicate(); d.albedo_color = skin_col(Color.WHITE, wet_on, goo_on, ch); d.roughness = skin_rough(0.85, wet_on, goo_on, ch)
		if (wet_on or goo_on != "") and ch < 2: d.rim_enabled = true; d.rim = 0.9; d.rim_tint = 0.25   # (the sheen of something wet)
		Gfx._three_mat(d); _mats[key] = d
	return _mats[key]

## the strings of syrup between a walking toy's feet and the floor
func _strands(e: Enemies.Foe, show: bool) -> void:
	var k := e.k
	if not show or e.leg_l == null:
		if k.has("strands"):
			for n in k.strands: (n as Node3D).queue_free()
			k.erase("strands")
		return
	if not k.has("strands"):
		var made := []
		for i in 2:
			var mi := MeshInstance3D.new(); mi.mesh = _strand_mesh(); mi.material_override = _goo_mat(str(k.goo)); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; e.g.add_child(mi); made.push_back(mi)
		k.strands = made
	var legs := [e.leg_l, e.leg_r]; var lift := (floor_at(e.pos.x, e.pos.y, e.pos.z, e.R) - e.pos.y) / maxf(e.g.scale.y, 0.01)   # (the floor the blob lies on, in his own measure)
	for i in 2:
		var leg: Node3D = legs[i]; var mi: MeshInstance3D = k.strands[i]; var hip := leg.position.y; var s := leg.rotation.x
		var sole := hip - (hip - 0.02) * cos(s)
		mi.visible = leg.is_visible_in_tree(); mi.position = Vector3(leg.position.x, lift, -(hip - 0.02) * sin(s) * 0.85); mi.scale = Vector3(1.0, maxf(sole - lift, 0.02), 1.0)

func _goo_mat(fl: String) -> Material:
	if not _mats.has("goo" + fl):
		var m := Gfx.std(GOO_COL[fl], 0.14); m.cull_mode = BaseMaterial3D.CULL_DISABLED; _mats["goo" + fl] = m
	return _mats["goo" + fl]

## one string, a metre tall: two crossed strips, broad at the foot and at the floor and thin between, and a blob of
## syrup on the floor it rises from
var _strand: ArrayMesh = null
func _strand_mesh() -> ArrayMesh:
	if _strand != null: return _strand
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var idx := PackedInt32Array(); var rows := [[0.0, 0.085], [0.5, 0.022], [1.0, 0.07]]
	for ax in 2:
		var side := Vector3.RIGHT if ax == 0 else Vector3.BACK; var nrm := Vector3.BACK if ax == 0 else Vector3.RIGHT; var o := vs.size()
		for r: Array in rows: vs.append_array([Vector3(0, r[0], 0) - side * float(r[1]), Vector3(0, r[0], 0) + side * float(r[1])]); ns.append_array([nrm, nrm])
		for j in 2: idx.append_array([o + j * 2, o + j * 2 + 1, o + j * 2 + 3, o + j * 2, o + j * 2 + 3, o + j * 2 + 2])
	var c := vs.size(); vs.push_back(Vector3(0, 0.012, 0)); ns.push_back(Vector3.UP)   # the blob: eight sides, a little off round
	for i in 8: var a := TAU * i / 8.0; vs.push_back(Vector3(cos(a) * (0.2 if i % 2 == 0 else 0.15), 0.012, sin(a) * (0.17 if i % 3 == 0 else 0.21))); ns.push_back(Vector3.UP)
	for i in 8: idx.append_array([c, c + 1 + (i + 1) % 8, c + 1 + i])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_INDEX] = idx
	_strand = ArrayMesh.new(); _strand.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return _strand

## each toy with something on it: the water dries, the syrup wears off, the smoke thins, a car's cabin settles on its spring
func _toys(dt: float) -> void:
	for i in range(active.size() - 1, -1, -1):
		var e: Enemies.Foe = active[i]
		if not e.alive or e.g == null or not is_instance_valid(e.g): active.remove_at(i); continue
		var k := e.k; var busy := false; var seen: bool = e.g.visible and not bool(k.get("gone", false)); var top := Vector3(e.pos.x, e.pos.y + e.H * 0.92, e.pos.z)
		var w := float(k.get("wet", 0.0))
		if w > 0.0:
			w -= dt; k.wet = w; busy = true
			if w <= 0.0: _skin(e)
			elif seen:
				k.drip = float(k.get("drip", 0.0)) - dt
				if float(k.drip) <= 0.0: k.drip = rnd(0.12, 0.3); bit(e.pos + Vector3(rnd(-e.R, e.R), rnd(0.3, 1.0) * e.H, rnd(-e.R, e.R)), Color(0.55, 0.78, 1.0, 0.75), 0.5, Vector3(0, -0.5, 0), 0.03, 0.02, 12.0)
				var ph := int(floor(e.walk / PI))   # a squeak at each step
				if ph != int(k.get("sq", ph)): snd("toy_squeak", e.pos, 0.55, 0.11)
				k.sq = ph
		var g := float(k.get("goo_t", 0.0))
		if g > 0.0:
			g -= dt; k.goo_t = g; busy = true
			if g <= 0.0: _skin(e); _strands(e, false)
			else:
				_strands(e, seen)
				k.fizz = float(k.get("fizz", 0.0)) - dt
				if seen and float(k.fizz) <= 0.0:
					k.fizz = rnd(0.07, 0.16)
					bit(e.pos + Vector3(rnd(-e.R, e.R), rnd(0.02, 0.5), rnd(-e.R, e.R)), Color(1.0, 0.95, 0.85, 0.7), rnd(0.5, 0.9), Vector3(rnd(-0.1, 0.1), rnd(0.5, 1.1), rnd(-0.1, 0.1)), 0.02, 0.035, -0.6)
		var sm := float(k.get("smoke", 0.0))
		if sm > 0.0:
			var alight := e.burn_t > 0.0
			if not alight: sm -= dt; k.smoke = sm
			busy = true; k.smoke_e = float(k.get("smoke_e", 0.0)) - dt
			if seen and float(k.smoke_e) <= 0.0:
				k.smoke_e = 0.07 if alight else 0.15
				bit(top + Vector3(rnd(-0.12, 0.12), 0.0, rnd(-0.12, 0.12)), Color(0.07, 0.07, 0.08, 0.5 if alight else 0.3), rnd(1.1, 1.6), Vector3(rnd(-0.15, 0.15), rnd(1.5, 2.3), rnd(-0.15, 0.15)), 0.09, rnd(0.3, 0.42), -0.25, false, 0.5)
		if k.has("panel"):
			var f := e.hp / maxf(e.max_hp, 1.0); var rest := rc_gape(f); var pan := float(k.pan); var pv := float(k.get("pan_v", 0.0))
			pv += ((rest - pan) * 90.0 - pv * 9.0) * dt; pan += pv * dt
			if pan < 0.0: pan = 0.0; pv = absf(pv) * 0.3
			k.pan = pan; k.pan_v = pv; (k.panel as Node3D).rotation.x = -pan
			if absf(pan - rest) > 0.003 or absf(pv) > 0.03: busy = true
			if f < 0.5:   # half broken: it goes on sparking
				busy = true; k.zap = float(k.get("zap", 0.6)) - dt
				if seen and float(k.zap) <= 0.0:
					k.zap = rnd(0.5, 1.4); var at := e.pos + Vector3(rnd(-0.2, 0.2), 0.62, rnd(-0.3, 0.1))
					for j in 2: bit(at, Color(0.65, 0.88, 1.0, 1.0), rnd(0.1, 0.2), _rv(2.4, 0.5, 3.0), 0.035, 0.008, 3.0, true)
					snd("toy_zap", at, 0.3, 0.4)
		if not busy: active.remove_at(i)

# ---------------- a fall ----------------
## a toy has fallen: its kind's own way of going (seen: it was in sight; out of sight it is simply gone)
func fell(e: Enemies.Foe, weak: bool, dir, seen := true) -> void:
	if not e.toy or e.g == null: return
	if not on(): return   # (nowhere but the toy room: it falls as anyone does)
	var k := e.k; active.erase(e); _strands(e, false); k.dead = "gone"
	if not seen or e.vanish: e.g.visible = false; return
	if _made >= BURST:   # too many falling in this one moment to break each apart: this one goes in a burst of its own colours
		var col: Color = (k.mat as StandardMaterial3D).albedo_color if e.type == "soldier" else Color(str(k.get("tint", "d62828")))
		for i in 10: bit(Vector3(e.pos.x, e.pos.y + e.H * rnd(0.2, 0.9), e.pos.z), Color(col, 1.0), rnd(0.4, 0.8), _rv(3.0, 1.0, 5.0), 0.06, 0.04, 15.0)
		e.g.visible = false; stats.bursts = int(stats.bursts) + 1; return
	var d := Vector3(dir.x, 0.0, dir.z) if dir != null else Vector3.ZERO
	d = d.normalized() if d.length() > 0.01 else Vector3(-sin(e.yaw), 0.0, -cos(e.yaw))
	var blast: bool = tf.en.blast or tf.en.cause in ["rocket", "gl"]
	var mid := Vector3(e.pos.x, e.pos.y + e.H * 0.5, e.pos.z)
	match e.type:
		"soldier": _fall_soldier(e, d, blast)
		"figure": _fall_figure(e, d, mid)
		"rc": k.dead = "haywire"; k.dt = 0.0; k.yaw0 = e.yaw; k.side = 1.0 if rng.randf() < 0.5 else -1.0; k.step = 0; k.lift = floor_at(e.pos.x, e.pos.y, e.pos.z, e.R) - e.pos.y; snd("toy_unwind", mid, 1.0, 0.1)
		_: _fall_brick(e, d, mid)

## its turn while it falls (from Enemies.update_dying): true once nothing more of it is to be moved from there
func dying(e: Enemies.Foe, dt: float) -> bool:
	match str(e.k.get("dead", "")):
		"topple": return _topple(e, dt)
		"haywire": return _haywire(e, dt)
	return true

# ---- a plastic soldier: one stiff piece. it tips over on the edge of its base, as it stood; a blast throws it up, turning
func _fall_soldier(e: Enemies.Foe, d: Vector3, blast: bool) -> void:
	var k := e.k; var m: StandardMaterial3D = k.mat
	m.albedo_color.a = 1.0; m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED; fade(e, 1.0)   # (fallen while it was see-through: whole again)
	for c in e.g.get_children(): (c as Node3D).visible = true
	var air := e.carried or e.pos.y > Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.25
	if blast or air:
		var v := d * (rnd(3.0, 5.5) if blast else rnd(1.8, 2.8)) + Vector3(0, rnd(9.5, 12.5) if blast else rnd(2.5, 4.0), 0)
		var p := take(e.g, v, Vector3.UP.cross(d).normalized() * (rnd(9.0, 13.0) if blast else rnd(4.0, 6.5)) + Vector3(0, rnd(-3.0, 3.0), 0), "plastic")
		p.heavy = true; p.fuse = true; p.bounce = 0.28; k.dead = "thrown"; k.g_taken = true; return
	k.dead = "topple"; k.dt = 0.0; k.fall = d; k.sc = e.g.scale; k.hit = false; k.lie = lie_angle(e, d); k.lift = floor_at(e.pos.x, e.pos.y, e.pos.z, e.R) - e.pos.y

const TOPPLE := 0.5          # seconds from upright to the floor
## how far over it goes before something of it meets the floor: it lies on the edge of its base and on whatever of it
## comes down first (its head, falling on its back; a shoulder, falling sideways; its gun, falling on its face)
func lie_angle(e: Enemies.Foe, d: Vector3) -> float:
	var pivot := _pivot(e, d); var best := PI / 2.0 + 0.35
	for c in e.g.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree(): continue
		var bb := mi.mesh.get_aabb(); var gt := mi.global_transform
		for i in 8:
			var p: Vector3 = gt * bb.get_endpoint(i); var h := p.y - pivot.y
			if h > 0.08: best = minf(best, PI / 2.0 + atan2((pivot - p).dot(d), h))
	return clampf(best, 0.9, PI / 2.0 + 0.35)

## the edge of its base on the side it falls to (the base is 0.7 wide and 0.5 deep, its middle a little ahead of him)
func _pivot(e: Enemies.Foe, d: Vector3) -> Vector3:
	var fwd := Vector3(sin(e.yaw), 0.0, cos(e.yaw)); var right := Vector3(fwd.z, 0.0, -fwd.x); var along := d.dot(fwd)
	return e.pos + d * ((0.3 if along > 0.0 else 0.2) * absf(along) + 0.35 * absf(d.dot(right)))

func _topple(e: Enemies.Foe, dt: float) -> bool:
	var k := e.k; k.dt = float(k.dt) + dt; var t := float(k.dt); var lie := float(k.lie); var ang := lie
	if t < TOPPLE: ang = lie * pow(t / TOPPLE, 2.2)
	elif t < TOPPLE + 0.24: ang = lie - 0.13 * sin((t - TOPPLE) / 0.24 * PI)   # one small bounce
	if t >= TOPPLE and not bool(k.hit): k.hit = true; snd("toy_clatter", e.pos, 1.0, 0.1)
	topple_pose(e, ang)
	if t < TOPPLE + 0.3: return false
	var p := take(e.g, Vector3.ZERO, Vector3.ZERO, "plastic"); p.heavy = true; p.state = REST; _file(p); fuse(p); k.g_taken = true
	return true

## the soldier as he stood, tipped by an angle about the edge of his base on the side he falls to
func topple_pose(e: Enemies.Foe, ang: float) -> void:
	var k := e.k; var d: Vector3 = k.fall; var axis := Vector3.UP.cross(d).normalized(); var pivot := _pivot(e, d); var R := Basis(axis, ang)
	var up := Vector3(0, float(k.get("lift", 0.0)) * clampf(ang / 0.5, 0.0, 1.0), 0)   # (up out of the rug's pile as he goes over)
	e.g.transform = Transform3D(R * Basis(Vector3.UP, e.yaw) * Basis.from_scale(k.sc), pivot + R * (e.pos - pivot) + up)

# ---- an action figure: its joints pop, and it is seven pieces: head, body, arms, legs, cape. the head rolls off
func _fall_figure(e: Enemies.Foe, d: Vector3, mid: Vector3) -> void:
	var k := e.k; var c1 := str(k.get("tint", "d62828")); var c2 := str(k.get("acc", "f4b400")); var mat := _skin_of(e)
	snd("toy_pop", mid, 1.0, 0.08)
	var head_at: Transform3D = e.upper.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.82, 0))
	for limb: Node3D in [e.arm_l, e.arm_r, e.head, e.leg_l, e.leg_r]:
		var out: Vector3 = limb.global_position - mid; out.y = 0.0; out = out.normalized() if out.length() > 0.02 else Vector3.ZERO
		take(limb, out * rnd(1.6, 3.2) + d * rnd(1.0, 2.6) + Vector3(0, rnd(2.4, 4.6), 0), _rv(9.0, -9.0, 9.0), "plastic")
		for j in 2: bit(limb.global_position, Color(1, 1, 1, 0.8), 0.22, _rv(1.5, 0.0, 2.0), 0.03, 0.01, 6.0)
	(e.upper.get_child(0) as MeshInstance3D).mesh = tf.en._box_mesh("tf_torso" + c1, [[0.46, 0.62, 0.26, 0, 0.36, 0, c1], [0.2, 0.2, 0.02, 0, 0.42, 0.14, c2]])
	take(e.upper, d * rnd(1.2, 2.4) + Vector3(0, rnd(2.0, 3.4), 0), _rv(5.0, -5.0, 5.0), "plastic")
	var side := Vector3(d.z, 0.0, -d.x) * rnd(-1.6, 1.6)
	var head := make("tf_head" + c1, [[0.22, 0.25, 0.24, 0, -0.02, 0.01, "e0b895"], [0.24, 0.1, 0.25, 0, 0.08, -0.01, c1]], head_at, d * rnd(4.4, 6.4) + side + Vector3(0, rnd(3.0, 4.2), 0), Vector3.ZERO, "plastic", mat)
	head.roll = 0.13; head.bounce = 0.42
	k.dead = "apart"

# ---- a wind-up car: its key runs wild, it whirls three times round, puffs black, tips onto its side and loses a wheel
const WHIRL := 1.15
const TIP := 0.42
func _haywire(e: Enemies.Foe, dt: float) -> bool:
	var k := e.k; k.dt = float(k.dt) + dt; var t := float(k.dt); var side := float(k.side); var top := e.pos + Vector3(0, 0.7, 0)
	if e.head != null: e.head.rotation.z -= dt * 70.0 * clampf(1.4 - t / WHIRL, 0.0, 1.0)   # the key, unwinding
	if t < WHIRL:
		var u := t / WHIRL
		e.g.rotation = Vector3(0.0, float(k.yaw0) + TAU * 3.0 * (2.0 * u - u * u), sin(t * 31.0) * 0.07 * (1.0 - u))
		if rng.randf() < dt * 9.0: bit(top, Color(1.0, 0.85, 0.35, 1.0), 0.3, _rv(2.0, 0.5, 2.5), 0.05, 0.01, 5.0, true)
		return false
	if int(k.step) == 0:   # the puff of black smoke
		k.step = 1; snd("toy_puff", top, 1.0, 0.1)
		for i in 9: bit(top + Vector3(rnd(-0.2, 0.2), 0.0, rnd(-0.3, 0.3)), Color(0.05, 0.05, 0.06, 0.62), rnd(0.9, 1.5), Vector3(rnd(-0.5, 0.5), rnd(0.9, 2.2), rnd(-0.5, 0.5)), 0.14, rnd(0.45, 0.7), -0.3, false, 1.2)
	var u2 := clampf((t - WHIRL) / TIP, 0.0, 1.0); var ang := PI / 2.0 * (1.0 - (1.0 - u2) * (1.0 - u2))
	if u2 >= 1.0: ang -= 0.1 * sin(clampf((t - WHIRL - TIP) / 0.2, 0.0, 1.0) * PI)   # it rocks once
	tip_pose(e, ang)
	if int(k.step) == 1 and u2 >= 0.5:   # a wheel off the side that comes up, rolling away
		k.step = 2; var lost := 0 if side > 0.0 else 1; var cc := str(k.get("tint", "e63946"))
		(e.body.get_child(0) as MeshInstance3D).mesh = tf.en._box_mesh("tr_body_%s%d%s" % ["o" if k.has("panel") else "", lost, cc], ToyFoes.rc_body(cc, not k.has("panel"), lost))
		var yb := Basis(Vector3.UP, float(k.yaw0)); var go: Vector3 = yb * Vector3(-side * 0.55, 0.0, 0.83).normalized()
		var n := MeshInstance3D.new(); var cyl := CylinderMesh.new(); cyl.top_radius = 0.21; cyl.bottom_radius = 0.21; cyl.height = 0.14; cyl.radial_segments = 10; cyl.rings = 1; n.mesh = cyl
		n.material_override = _wheel_mat(); _root().add_child(n)
		n.global_transform = Transform3D(Basis(go, Vector3.UP.cross(go), Vector3.UP), e.g.global_transform * Vector3(ToyFoes.RC_WHEELS[lost].x, 0.21, ToyFoes.RC_WHEELS[lost].y))
		var wp := take(n, go * rnd(4.5, 6.5) + Vector3(0, rnd(1.5, 2.5), 0), Vector3.ZERO, "metal"); wp.roll = 0.21; wp.bounce = 0.4
		snd("toy_clatter", e.pos, 0.9, 0.1)
	if t < WHIRL + TIP + 0.22: return false
	var p := take(e.g, Vector3.ZERO, Vector3.ZERO, "metal"); p.heavy = true; p.state = REST; _file(p); fuse(p); k.g_taken = true
	return true

## the car lying over by an angle on the outer edge of its wheels, on the side it tips to
func tip_pose(e: Enemies.Foe, ang: float) -> void:
	var k := e.k; var side := float(k.side); var yb := Basis(Vector3.UP, float(k.yaw0)); var roll := Basis(Vector3.BACK, -side * ang); var pivot := Vector3(side * 0.61, 0.0, 0.0)
	e.g.transform = Transform3D(yb * roll, e.pos + yb * (pivot - roll * pivot) + Vector3(0, float(k.get("lift", 0.0)) * clampf(ang / 0.5, 0.0, 1.0), 0))

func _wheel_mat() -> Material:
	if not _mats.has("wheel"): _mats["wheel"] = Gfx.std(World.lin("1c1c1c"), 0.8)
	return _mats["wheel"]

# ---- a brick figure: all its bricks at once (head, two of the body, arms, hands, the legs in two each, the gun, and
# the hat and cape if it still had them)
func _fall_brick(e: Enemies.Foe, d: Vector3, mid: Vector3) -> void:
	var k := e.k; var cb := str(k.get("tint", "d62828")); var Y := "f4d35e"; var D := "24272c"; var mat := _skin_of(e)
	snd("toy_crumble", mid, 1.0, 0.08)
	var ut := e.upper.global_transform; var bits: Array = [
		["tbp_head", [[0.3, 0.3, 0.3, 0, 0, 0, Y], [0.16, 0.08, 0.16, 0, 0.19, 0, Y], [0.16, 0.04, 0.02, 0, -0.04, 0.16, "1c1c1c"]], ut, Vector3(0, 0.82, 0)],
		["tbp_chest" + cb, [[0.5, 0.31, 0.3, 0, 0, 0, cb], [0.12, 0.05, 0.12, -0.13, 0.18, 0, cb], [0.12, 0.05, 0.12, 0.13, 0.18, 0, cb]], ut, Vector3(0, 0.485, 0)],
		["tbp_belly" + cb, [[0.5, 0.31, 0.3, 0, 0, 0, cb]], ut, Vector3(0, 0.175, 0)],
		["tbp_gun", [[0.07, 0.34, 0.1, 0, 0, 0, "8d99ae"]], e.arm_r.global_transform, Vector3(0, -0.72, 0.03)]]
	for arm: Node3D in [e.arm_l, e.arm_r]:
		bits.push_back(["tbp_arm" + cb, [[0.13, 0.5, 0.14, 0, 0, 0, cb]], arm.global_transform, Vector3(0, -0.24, 0)])
		bits.push_back(["tbp_hand", [[0.14, 0.14, 0.16, 0, 0, 0, Y]], arm.global_transform, Vector3(0, -0.52, 0.02)])
	for leg: Node3D in [e.leg_l, e.leg_r]:
		for y: float in [-0.19, -0.565]: bits.push_back(["tbp_leg", [[0.2, 0.37, 0.24, 0, 0, 0, D]], leg.global_transform, Vector3(0, y, 0)])
	for b: Array in bits:
		var at: Transform3D = (b[2] as Transform3D) * Transform3D(Basis.IDENTITY, b[3]); var out := at.origin - mid; out.y = 0.0
		out = out.normalized() if out.length() > 0.02 else Vector3(rnd(-1, 1), 0.0, rnd(-1, 1)).normalized()
		make(b[0], b[1], at, out * rnd(1.2, 3.4) + d * rnd(0.6, 2.6) + Vector3(rnd(-0.8, 0.8), rnd(2.4, 5.6), rnd(-0.8, 0.8)), _rv(10.0, -10.0, 10.0), "brick", mat)
	if bool(k.get("hat", false)): _brick_bit(e, "hat", d)
	if bool(k.get("cape", false)): _brick_bit(e, "cape", d)
	var col := Color(cb)
	for i in 8: bit(mid + _rv(0.3, -0.4, 0.5), Color(col, 1.0), rnd(0.4, 0.7), _rv(3.0, 1.5, 5.0), 0.035, 0.03, 15.0)
	e.g.visible = false; k.dead = "apart"

# ---------------- coming back: out of a package ----------------
const PACK_SHUT := 0.22      # the package stands shut round him this long
const PACK_OPEN := 0.5       # ...then its clear front, torn down the middle, swings away in two halves
const PACK_END := 1.45
## someone is back at his base: the package he comes in stands round him (a card behind, clear plastic in front and at
## the sides), is torn open and falls away. Nobody is held or moved by it
func pack(at: Vector3, fwd: Vector3, team: String, mine := false) -> void:
	if not on(): return
	var n := Node3D.new(); _root().add_child(n); n.position = at; n.rotation.y = atan2(fwd.x, fwd.z)   # (its front along the way he faces)
	var col := "3d7dca" if team == "us" else "e63946"
	var card := tf._node(n, Vector3(0, 0, -0.5), [[1.6, 2.6, 0.05, 0, 1.3, 0, col], [1.6, 0.42, 0.06, 0, 2.3, 0, "f4d35e"], [0.3, 0.1, 0.07, 0, 2.42, 0, "2b2d42"], [1.3, 0.12, 0.06, 0, 0.18, 0, "ffffff"]], "pk_card" + col)
	var halves := []
	for s: float in [-1.0, 1.0]:
		var hn := Node3D.new(); n.add_child(hn); hn.position = Vector3(s * 0.75, 0, -0.47)
		var mi := MeshInstance3D.new(); mi.mesh = half_mesh(s); mi.material_override = _clear_mat(); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hn.add_child(mi); halves.push_back(hn)
	packs.push_back({"n": n, "t": 0.0, "halves": halves, "card": card, "mine": mine})
	snd("toy_rip", at + Vector3(0, 1.2, 0), 0.9 if mine else 0.7, 0.12); stats.packs = int(stats.packs) + 1
	for i in 6: bit(at + Vector3(rnd(-0.5, 0.5), rnd(0.8, 2.2), rnd(-0.2, 0.5)), Color(Color(col).lightened(0.4), 0.9), rnd(0.5, 0.9), _rv(1.6, 0.5, 2.5), 0.03, 0.02, 6.0)

func _packs(dt: float) -> void:
	for i in range(packs.size() - 1, -1, -1):
		var q: Dictionary = packs[i]; q.t = float(q.t) + dt; var t := float(q.t)
		var u := clampf((t - PACK_SHUT) / PACK_OPEN, 0.0, 1.0); var open := 1.0 - (1.0 - u) * (1.0 - u)
		for j in 2:
			var hn: Node3D = q.halves[j]; hn.rotation.y = (-1.0 if j == 0 else 1.0) * open * 2.1
			(hn.get_child(0) as MeshInstance3D).transparency = clampf((t - PACK_SHUT - 0.2) / 0.45, 0.0, 1.0)
			hn.visible = t < PACK_SHUT + 0.66
		var c: Node3D = q.card; var back := clampf((t - 0.95) / (PACK_END - 0.95), 0.0, 1.0)   # the card falls back and is gone
		c.rotation.x = -back * back * 1.45; c.scale = Vector3.ONE * (1.0 - back * back * 0.6)
		if t >= PACK_END: (q.n as Node3D).queue_free(); packs.remove_at(i)

## one half of the clear front: its side wall, its lid and the front with a jagged inner edge (where it was torn). The
## hinge it swings on is its back outer edge
static var _halves := {}
static func half_mesh(s: float) -> ArrayMesh:
	if _halves.has(s): return _halves[s]
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var idx := PackedInt32Array(); var Z := 0.92; var y0 := 0.12; var y1 := 2.32; var rows := 9
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		var o := vs.size(); vs.append_array([a, b, c, d]); ns.append_array([n, n, n, n]); idx.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
	quad.call(Vector3(0, y0, 0), Vector3(0, y0, Z), Vector3(0, y1, Z), Vector3(0, y1, 0), Vector3(s, 0, 0))   # the side
	var edge := func(j: int) -> float: return -s * 0.75 + (0.07 if j % 2 == 0 else -0.07)
	for j in rows - 1:
		var ya := lerpf(y0, y1, float(j) / (rows - 1)); var yb := lerpf(y0, y1, float(j + 1) / (rows - 1))
		quad.call(Vector3(0, ya, Z), Vector3(edge.call(j), ya, Z), Vector3(edge.call(j + 1), yb, Z), Vector3(0, yb, Z), Vector3(0, 0, 1))
	quad.call(Vector3(0, y1, 0), Vector3(0, y1, Z), Vector3(edge.call(rows - 1), y1, Z), Vector3(edge.call(rows - 1), y1, 0), Vector3(0, 1, 0))   # the lid
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); _halves[s] = m; return m

func _clear_mat() -> Material:
	if not _mats.has("clear"):
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.86, 0.95, 1.0, 0.32); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.04; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["clear"] = m
	return _mats["clear"]

# ---------------- clearing up ----------------
const CLAW_DOWN := 0.8
const CLAW_GRAB := 0.4
const CLAW_UP := 1.0
const CLAW_HIGH := 20.0
const CLAW_SIZE := 2.4       # it is a child's toy, and the toys are small beside it
const BROOM_T := 1.5
const BROOM_RUN := 14.0
## with enough lying about, every so often the fullest corner is cleared: in the open by a toy claw on a cable coming
## down for it, under something low (the bed, the bridge) by the shadow of a broom sweeping through
func _sweep(dt: float) -> void:
	if not claw.is_empty(): _claw(dt); return
	if not broom.is_empty(): _broom(dt); return
	if lying() < SWEEP_MIN: return
	sweep_t -= dt
	if sweep_t > 0.0: return
	sweep_t = SWEEP_EVERY
	var c = pile()
	if c == null: return
	stats.sweeps = int(stats.sweeps) + 1
	if Phys.ceil_at(c.x, c.y + 0.2, c.z, 0.8, 1.0) - c.y > 9.0: _claw_start(c)
	else: _broom_start(c)

## the middle of the fullest corner: where the most pieces lie within a square and those next to it
func pile():
	var best := Vector2i.ZERO; var best_n := 0
	for c: Vector2i in cells:
		var n := 0
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]: n += (cells.get(c + Vector2i(dx, dz), []) as Array).size()
		if n > best_n: best_n = n; best = c
	if best_n == 0: return null
	var first: Vector3 = ((cells[best] as Array)[0] as Piece).n.position; var sum := Vector3.ZERO; var cnt := 0
	for p in _reach(first): sum += p.n.position; cnt += 1
	if cnt == 0: return null
	var mid := sum / cnt; mid.y = first.y - ((cells[best] as Array)[0] as Piece).half.y
	return mid

## the pieces lying within the sweep's reach of a place, on its level
func _reach(c: Vector3) -> Array:
	var out := []
	for p in pieces:
		var q := p.n.position
		if p.state == REST and absf(q.y - c.y) < 2.0 and Vector2(q.x - c.x, q.z - c.z).length() < SWEEP_R: out.push_back(p)
	return out

func _claw_start(c: Vector3) -> void:
	var n := Node3D.new(); _root().add_child(n); n.position = c + Vector3(0, CLAW_HIGH, 0); n.scale = Vector3.ONE * CLAW_SIZE
	tf._node(n, Vector3.ZERO, [[0.9, 0.4, 0.9, 0, 0.3, 0, "8d99ae"], [0.5, 0.3, 0.5, 0, 0.65, 0, "5a6270"], [0.1, 26.0, 0.1, 0, 13.8, 0, "3a3d42"], [0.34, 0.12, 0.34, 0, 0.06, 0, "e63946"]], "claw_hub")
	var fingers := []
	for i in 3:
		var a := TAU * i / 3.0; var f := tf._node(n, Vector3(sin(a) * 0.36, 0.2, cos(a) * 0.36), [[0.12, 0.95, 0.12, 0, -0.45, 0, "c9ced6"], [0.12, 0.12, 0.44, 0, -0.9, -0.17, "c9ced6"], [0.16, 0.16, 0.16, 0, 0.0, 0, "5a6270"]], "claw_finger")
		f.rotation_order = EULER_ORDER_YXZ; f.rotation = Vector3(-0.6, a, 0.0); fingers.push_back(f)   # (hanging outwards: open)
	claw = {"n": n, "at": c, "t": 0.0, "fingers": fingers, "held": [], "step": 0}
	snd("toy_crane", c + Vector3(0, 2.0, 0), 1.0, 0.2)

func _claw(dt: float) -> void:
	claw.t = float(claw.t) + dt; var t := float(claw.t); var n: Node3D = claw.n; var c: Vector3 = claw.at; var low := c.y + 0.95 * CLAW_SIZE; var grip := -0.6
	if t < CLAW_DOWN:
		var u := t / CLAW_DOWN; n.position.y = lerpf(c.y + CLAW_HIGH, low, 1.0 - (1.0 - u) * (1.0 - u))
	elif t < CLAW_DOWN + CLAW_GRAB:
		if int(claw.step) == 0:   # it closes on everything within reach
			claw.step = 1
			for p: Piece in _reach(c + Vector3(0, 0.3, 0)):
				_unfile(p); p.state = HELD; p.v = p.n.position; p.off = Vector3(rnd(-0.9, 0.9), rnd(-1.9, -0.7), rnd(-0.9, 0.9)); (claw.held as Array).push_back(p)
			snd("toy_rattle", c, 0.9, 0.05, 0.8)
		var u := (t - CLAW_DOWN) / CLAW_GRAB; var e := u * u * (3.0 - 2.0 * u); n.position.y = low; grip = lerpf(-0.6, 0.28, e)
		for p: Piece in claw.held: p.n.position = (p.v as Vector3).lerp(n.position + p.off, e); p.n.scale = Vector3.ONE * lerpf(1.0, 0.7, e)
	else:
		if int(claw.step) == 1: claw.step = 2; snd("toy_crane", c + Vector3(0, 2.0, 0), 0.8, 0.2, 1.25)
		var u := clampf((t - CLAW_DOWN - CLAW_GRAB) / CLAW_UP, 0.0, 1.0); n.position.y = lerpf(low, c.y + CLAW_HIGH + 2.0, u * u); grip = 0.28
		for p: Piece in claw.held: p.n.position = n.position + p.off
		if u >= 1.0:
			for p: Piece in claw.held: p.n.queue_free(); pieces.erase(p)
			n.queue_free(); claw = {}; return
	for f: Node3D in claw.fingers: f.rotation.x = grip

func _broom_start(c: Vector3) -> void:
	var dir := Vector3(1, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, 1)
	if rng.randf() < 0.5: dir = -dir
	var n := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(7.0, 5.0); n.mesh = pm; n.material_override = _shadow_mat(); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(n); n.position = c - dir * (BROOM_RUN * 0.5) + Vector3(0, 0.06, 0); n.rotation.y = atan2(dir.x, dir.z)   # (the picture's top leads)
	broom = {"n": n, "at": c, "dir": dir, "t": 0.0, "left": _reach(c + Vector3(0, 0.3, 0))}
	snd("toy_sweep", c, 1.0, 0.2)

func _broom(dt: float) -> void:
	broom.t = float(broom.t) + dt; var u := clampf(float(broom.t) / BROOM_T, 0.0, 1.0); var n: Node3D = broom.n; var c: Vector3 = broom.at; var dir: Vector3 = broom.dir
	var along := (u - 0.5) * BROOM_RUN; n.position = c + dir * along + Vector3(0, 0.06, 0)
	Gfx.set_alpha((n as MeshInstance3D).material_override, clampf(minf(u, 1.0 - u) * 6.0, 0.0, 1.0))
	var left: Array = broom.left
	for i in range(left.size() - 1, -1, -1):   # what the brush has reached goes with it
		var p: Piece = left[i]
		if p.state != REST: left.remove_at(i); continue
		if (p.n.position - c).dot(dir) < along + 1.6: _go(p, 0.32); p.v = dir * (BROOM_RUN / BROOM_T) + Vector3(0, 1.2, 0); left.remove_at(i)
	if u >= 1.0: n.queue_free(); broom = {}

## the broom's shadow: the head of the brush across the front, the handle running back from its middle
static func shadow_image() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var px := (x + 0.5) / 64.0; var py := (y + 0.5) / 64.0
			var head := smoothstep(0.02, 0.1, px) * smoothstep(0.98, 0.9, px) * smoothstep(0.03, 0.1, py) * smoothstep(0.42, 0.3, py)
			var handle := smoothstep(0.06, 0.02, absf(px - 0.5)) * smoothstep(0.24, 0.32, py) * smoothstep(1.0, 0.9, py)
			img.set_pixel(x, y, Color(0, 0, 0, maxf(head, handle * 0.9) * 0.5))
	img.generate_mipmaps(); return img

func _shadow_mat() -> Material:
	if not _mats.has("shadow"):
		var m := Gfx.unlit(Color(0, 0, 0, 1), false); m.albedo_texture = ImageTexture.create_from_image(shadow_image()); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; _mats["shadow"] = Gfx.see_through(m)
	return _mats["shadow"]

# ---------------- each frame ----------------
func tick(dt: float) -> void:
	if not on():
		if root != null: clear()
		return
	clock += dt; _made = 0
	if _warm_n > 0:
		_warm_n -= 1
		if _warm_n == 0 and _warm != null and is_instance_valid(_warm): _warm.queue_free(); _warm = null
	if not active.is_empty(): _toys(dt)
	if not pieces.is_empty(): _pieces(dt)
	if not packs.is_empty(): _packs(dt)
	_sweep(dt)
	if cells.is_empty(): return
	# who treads on what lies about: you at every step, the toys five times a second
	var pl := tf.player
	if pl != null and pl.grounded and not pl.out and Vector2(pl.vel.x, pl.vel.z).length() > 0.6: tread(pl.pos, pl.vel, 0.42)
	_tread_t -= dt
	if _tread_t > 0.0: return
	_tread_t = 0.2
	for e in tf.en.list: _unit_tread(e)
	if tf.tm != null:
		for a in tf.tm.allies: _unit_tread(a)

func _unit_tread(e: Enemies.Foe) -> void:
	if not e.alive or e.fly: return
	var k := e.k; var mv := Vector3(e.pos.x - float(k.get("tx", e.pos.x)), 0.0, e.pos.z - float(k.get("tz", e.pos.z))); k.tx = e.pos.x; k.tz = e.pos.z
	if mv.length() > 0.1: tread(e.pos, mv / 0.2, e.R + 0.1)
