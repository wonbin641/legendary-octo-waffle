class_name ToyRoom
extends RefCounted
## Stage 5: a child's bedroom seen at toy size. You are about 5 cm tall, so the bed is a plateau, the desk a cliff and the
## bookshelf a mountain. West: the desk. East: the bunk bed. Between them a bridge of building blocks. South: the carpet,
## the toy bins and the train. North: the bookshelf and the wardrobe, the highest ground.
## Heights: floor 0, mattress 6, desk 9, upper bunk 15, bookshelf 20, wardrobe 24.

const HALF := 70.0
const BED_Y := 6.0
## the furniture's names on the tactical map, as the owner drew them: [name, x, z] at the middle of each piece seen from above
## (the bookshelf and the wardrobe along the north wall, the desk to the west, the bunk bed to the east)
const NAMES := [["책장", -34.0, -63.0], ["옷장", 28.0, -62.0], ["책상", -42.0, -4.0], ["2층침대", 36.0, 0.0]]
const BED := [10.0, -30.0, 62.0, 30.0, 4.0]   # under the bed: [minx, minz, maxx, maxz] and below this height (the frame is at 4.4)
static func under_bed(p: Vector3) -> bool: return p.x > BED[0] and p.x < BED[2] and p.z > BED[1] and p.z < BED[3] and p.y < BED[4]
const DESK_Y := 9.0
const BUNK_Y := 15.0
const SHELF_Y := 20.0
const WARD_Y := 24.0

var world: World
var G: Node3D
var parts: Array = []            # boxes to merge into one mesh: [sx, sy, sz, x, y, z, colour]
var pads: Array = []             # springs: {x, z, y, r, vy}
var catapults: Array = []        # {x, z, y, r, vel: Vector3}
var ziplines: Array = []         # {a: Vector3, b: Vector3, speed}
var tacks: Array = []            # thumbtack patches: {x, z, r}
var beds: Array = []             # mattress areas: [minx, minz, maxx, maxz, y] (a little more spring in your jump)
var train: Dictionary = {}
var riding = null                # the zipline you are on: {line, t}
var _tack_t := 0.0
var tm = null                    # the team mode being played here (ToyMatch), or null for the sweep
var train_hold := false          # (bedtime: the toy train keeps still while the room's owner looks in)

## a part of the room the team mode builds its own way, or leaves out to make room for its own things
func _skip(what: String) -> bool: return tm != null and tm.mode.skips(what)

# ---------- building helpers ----------
## a box given by its corners; it is drawn and (unless told otherwise) stands in the way
func box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, color: String, kind := "concrete", solid := true) -> Phys.Box:
	parts.push_back([x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, color])
	return Phys.add_collider(x0, y0, z0, x1, y1, z1, kind) if solid else null

## steps climbing along x or z: n steps of 'rise', each 'run' deep and 'width' wide, starting at (x, y, z); dir is "+x", "-x", "+z" or "-z"
func stairs(x: float, y: float, z: float, dir: String, n: int, rise: float, run: float, width: float, color: String, color2 := "") -> void:
	for i in n:
		var c := color2 if (color2 != "" and i % 2 == 1) else color; var top := y + (i + 1) * rise
		match dir:
			"+x": box(x + i * run, y, z - width / 2, x + (i + 1) * run, top, z + width / 2, c)
			"-x": box(x - (i + 1) * run, y, z - width / 2, x - i * run, top, z + width / 2, c)
			"+z": box(x - width / 2, y, z + i * run, x + width / 2, top, z + (i + 1) * run, c)
			"-z": box(x - width / 2, y, z - (i + 1) * run, x + width / 2, top, z - i * run, c)

func round_thing(mesh: Mesh, at: Vector3, color: String, rough := 0.6, metal := 0.0, alpha := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = mesh; var mat := Gfx.std(Color(color), rough, metal)
	if alpha < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color.a = alpha
	m.material_override = mat; m.position = at; G.add_child(m)
	return m

func cyl(at: Vector3, r: float, h: float, color: String, solid := true, top_r := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r if top_r < 0.0 else top_r; c.height = h; c.radial_segments = 20
	if solid: Phys.add_collider(at.x - r * 0.9, at.y - h / 2, at.z - r * 0.9, at.x + r * 0.9, at.y + h / 2, at.z + r * 0.9, "concrete")
	return round_thing(c, at, color)

func ball(at: Vector3, r: float, color: String, solid := true) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2
	if solid: Phys.add_collider(at.x - r * 0.75, at.y - r, at.z - r * 0.75, at.x + r * 0.75, at.y + r * 0.8, at.z + r * 0.75, "concrete")
	return round_thing(s, at, color, 0.35)

# ---------- the room ----------
func build(w: World, group: Node3D) -> void:
	world = w; G = group
	Phys.set_world_size(HALF); Phys.set_nav(150, 1.0)
	# floor boards, the walls, the skirting
	for i in 14: box(-HALF + i * 10.0, -0.5, -HALF, -HALF + (i + 1) * 10.0 - 0.15, 0.0, HALF, "b98a5a" if i % 2 else "c49766", "wood", false)
	box(-HALF, -0.6, -HALF, HALF, -0.5, HALF, "6e4f30", "wood", false)
	for wl in [[-HALF - 1.0, -HALF, -HALF, HALF], [HALF, -HALF, HALF + 1.0, HALF], [-HALF, -HALF - 1.0, HALF, -HALF], [-HALF, HALF, HALF, HALF + 1.0]]:
		if wl[1] == HALF and _skip("south_wall"): continue   # (bedtime: the wall with the room's door in it)
		box(wl[0], 0, wl[1], wl[2], 46.0, wl[3], "cfe3ea"); box(wl[0] - (0.0 if wl[2] - wl[0] > 5 else 0.3), 0, wl[1] - (0.3 if wl[2] - wl[0] > 5 else 0.0), wl[2] + (0.0 if wl[2] - wl[0] > 5 else 0.3), 2.2, wl[3] + (0.3 if wl[2] - wl[0] > 5 else 0.0), "f4f1e8", "concrete", false)
	_bed(); _desk(); _bridge(); _south(); _north()
	if tm != null: tm.mode.build_room(self); tm.build_graph()   # the team mode's own things, then the ways the toys walk
	# everything boxy in one mesh
	var mi := MeshInstance3D.new(); mi.mesh = Gfx.merge_boxes(parts, true); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.75; mi.material_override = mat; G.add_child(mi)
	_crates()
	Phys.index_colliders(); Phys.build_nav()
	world.start = {"x": 0.0, "z": 56.0, "yaw": 0.0} if tm == null else tm.mode.start(); world.spawns.clear()

## wooden toy boxes with health potions in them, as in every other stage: on the floor, in the blanket's trenches, on the desk and the
## upper bunk; never on a way up (stairs, ladder, springs, catapults, the ends of the bridge and the tapes), the train's track or the tacks
const CRATES := 24
func _crates() -> void:
	var R := World.Rng.new(77); var placed: Array = []
	var levels := [[0.5, -62.0, 62.0, -62.0, 62.0, 0.0], [0.7, 12.0, 47.0, -28.0, 28.0, BED_Y], [0.85, -60.0, -24.0, -26.0, 18.0, DESK_Y], [1.0, 12.0, 58.0, -28.0, 28.0, BUNK_Y]]
	var keep_off := func(x: float, z: float, y: float) -> bool:
		var near := func(px: float, pz: float, r: float) -> bool: return Vector2(x - px, z - pz).length() < r
		if y == 0.0:
			if (x > -2.0 and x < 11.5 and z > 14.0 and z < 26.0) or (x > -41.5 and x < -20.5 and z > 18.5 and z < 29.5): return true   # the blanket and the books, up
			if near.call(6.0, -22.0, 3.5) or near.call(6.0, 10.0, 3.5) or near.call(-14.0, 30.0, 4.5) or near.call(52.0, 41.0, 4.5) or near.call(-4.0, 46.0, 6.5) or near.call(30.0, 43.0, 5.0): return true
			if absf(x) > 62.0 or z > 63.5 or absf(z - 36.5) < 2.6 or near.call(0.0, 56.0, 10.0): return true   # the train, and where you come down
		elif y == BED_Y: return (x < 19.0 and absf(z) < 6.0) or near.call(30.0, 0.0, 3.0)
		elif y == DESK_Y: return (x > -30.0 and absf(z) < 6.0) or (x > -38.0 and x < -30.0 and z > -28.0 and z < -20.0) or (x > -42.0 and z > 16.0) or near.call(-30.0, -6.0, 4.0)
		else: return near.call(30.0, 0.0, 4.0) or near.call(45.9, 10.3, 4.0) or (x > 38.0 and z > 24.0)   # where the tape and the catapult put you down, the ladder's top
		return false
	world._place_crates(G, CRATES, func() -> Array:
			var k := R.next(); var L: Array = levels[3]
			for l in levels:
				if k < l[0]: L = l; break
			var x := R.rng(L[1], L[2]); var z := R.rng(L[3], L[4]); return [x, z, L[5]],
		func(x: float, z: float, y: float) -> bool:
			var g0 := Phys.ground_at(x, y + 1.0, z, 0.05)
			if absf(g0 - y) > 0.01 or absf(Phys.ground_at(x, y + 1.0, z, 0.75) - g0) > 0.01: return false   # flat under the whole box
			if Phys.collide_at(x, y + 0.05, z, 0.7, 1.25) != null or Phys.ceil_at(x, y, z, 0.6, 1.2) < y + 1.3 or keep_off.call(x, z, y): return false
			if tm != null and tm.keep_off(x, z, y): return false   # (a team mode: not on the toys' ways, nor at a base)
			for p: Vector3 in placed:
				if p.distance_to(Vector3(x, y, z)) < 4.0: return false
			placed.push_back(Vector3(x, y, z)); return true, true)

## east: the bunk bed. the lower mattress is the main battlefield; under it, a dark crawl space
func _bed() -> void:
	var x0 := 10.0; var x1 := 62.0; var z0 := -30.0; var z1 := 30.0
	for p in [[x0, z0], [x1 - 2.4, z0], [x0, z1 - 2.4], [x1 - 2.4, z1 - 2.4]]: box(p[0], 0, p[1], p[0] + 2.4, 26.0, p[1] + 2.4, "a6d96a", "wood")   # the four posts, floor to top
	box(x0, 4.4, z0, x1, 5.2, z1, "8cc456", "wood"); box(x0 + 0.6, 5.2, z0 + 0.6, x1 - 0.6, BED_Y, z1 - 0.6, "d2efb0", "bed")   # frame and mattress (walk under it: 4.4 m clear)
	beds.push_back([x0, z0, x1, z1, BED_Y])
	box(x1, 0, z0, x1 + 1.6, 26.0, z1, "a6d96a", "wood")   # the headboard, against the east wall
	# pillows and the teddy bear at the head of the bed: bunkers
	box(49.0, BED_Y, -26.0, 59.0, BED_Y + 2.6, -8.0, "fdfdfd", "bed"); box(49.0, BED_Y, 8.0, 59.0, BED_Y + 2.6, 26.0, "ffe9a8", "bed")
	box(51.5, BED_Y, -4.5, 58.5, BED_Y + 5.0, 4.5, "a9743f", "bed"); ball(Vector3(55.0, BED_Y + 7.2, 0), 2.6, "b98146", false)
	for e in [-1.0, 1.0]: ball(Vector3(55.0, BED_Y + 9.4, e * 2.2), 0.9, "8e5f31", false); ball(Vector3(52.0, BED_Y + 3.0, e * 4.6), 1.4, "b98146", false)
	ball(Vector3(52.8, BED_Y + 6.9, 0), 1.0, "f0d9b0", false)
	# a crumpled blanket: long folds with trenches between them, gaps to cross through
	var folds := [[16.0, -24.0, 2.0, 20.0, "7fb4e0"], [22.0, -6.0, 2.2, 22.0, "6aa3d6"], [28.0, -26.0, 1.9, 16.0, "7fb4e0"], [28.0, -4.0, 1.9, 12.0, "7fb4e0"], [34.0, 6.0, 2.3, 20.0, "5b95cc"],
		[40.0, -22.0, 2.0, 24.0, "6aa3d6"], [40.0, 10.0, 2.0, 14.0, "6aa3d6"], [16.0, 6.0, 1.8, 18.0, "5b95cc"]]
	for f in folds: box(f[0], BED_Y, f[1], f[0] + 2.6, BED_Y + f[2], f[1] + f[3], f[4], "bed"); box(f[0] + 0.5, BED_Y + f[2], f[1] + 0.6, f[0] + 2.1, BED_Y + f[2] + 0.35, f[1] + f[3] - 0.6, "8fc0ea", "bed", false)
	# the blanket hangs over the west edge down to the floor: the way up from the carpet
	stairs(x0 - 14 * 0.75, 0, 20.0, "+x", 14, BED_Y / 14.0, 0.75, 9.0, "6aa3d6", "7fb4e0")   # lowest step out on the floor, the top one against the bed
	# the upper bunk: its slab, a rail to hide behind, and the ladder up from the mattress
	box(x0, BUNK_Y - 1.0, z0, x1, BUNK_Y - 0.4, z1, "8cc456", "wood"); box(x0 + 0.6, BUNK_Y - 0.4, z0 + 0.6, x1 - 0.6, BUNK_Y, z1 - 0.6, "ffd9e2", "bed"); beds.push_back([x0, z0, x1, z1, BUNK_Y])
	for r in [[x0, z0, x1, z0 + 0.6], [x0, z1 - 0.6, x0 + 30.0, z1], [x0, z0, x0 + 0.6, -6.0], [x0, 6.0, x0 + 0.6, z1]]: box(r[0], BUNK_Y, r[1], r[2], BUNK_Y + 1.3, r[3], "a6d96a", "wood")
	stairs(x1 - 3.0, BED_Y, z1 + 1.7, "-x", 20, (BUNK_Y - BED_Y) / 20.0, 0.9, 3.4, "a6d96a", "8cc456")   # outside the frame on the south side; the rail is open where it arrives
	box(48.0, BUNK_Y, -24.0, 58.0, BUNK_Y + 2.4, -10.0, "fdfdfd", "bed"); box(20.0, BUNK_Y, 4.0, 22.6, BUNK_Y + 1.8, 22.0, "f7a8bd", "bed"); box(34.0, BUNK_Y, -22.0, 36.6, BUNK_Y + 1.8, -2.0, "f7a8bd", "bed")
	# springs: by the bed's west corners on the floor (up to the mattress and the desk), and on the mattress (up to the upper bunk)
	_spring(6.0, -22.0, 0.0, 21.0); _spring(6.0, 10.0, 0.0, 21.0)
	box(6.0, 0, -35.0, 14.0, BED_Y, -30.0, "f77f00", "wood"); _spring(9.0, -32.5, BED_Y, 21.5)   # a stool at the bed's corner, level with the mattress, with the spring for the upper bunk
	box(58.0, 4.4, z1, x1, BED_Y, z1 + 3.4, "8cc456", "wood")                                    # a bedside shelf: the foot of the ladder
	# under the bed: socks, a slipper, lost balls. dark and close
	for s in [[18.0, -20.0, 7.0, 2.6, "e85d75"], [30.0, 4.0, 2.6, 8.0, "f2f2f2"], [44.0, -12.0, 8.0, 2.4, "5fbf8f"], [24.0, 18.0, 6.0, 2.4, "f2c14e"], [50.0, 14.0, 2.6, 7.0, "9b7fd1"], [38.0, -24.0, 2.4, 6.0, "f2f2f2"]]:
		if _skip("sock_%d_%d" % [int(s[0]), int(s[1])]): continue   # (the train's tunnel)
		box(s[0], 0, s[1], s[0] + s[2], 1.7, s[1] + s[3], s[4], "bed")
	box(34.0, 0, 16.0, 46.0, 1.2, 21.0, "3d7dca", "bed"); box(34.0, 1.2, 16.0, 40.0, 3.2, 21.0, "3d7dca", "bed")   # a slipper
	ball(Vector3(22.0, 1.6, -4.0), 1.6, "e63946"); ball(Vector3(52.0, 1.3, -22.0), 1.3, "ffd166"); ball(Vector3(46.0, 2.0, 2.0), 2.0, "2a9d8f")

## west: the study desk. high ground with a long view over the bed
func _desk() -> void:
	var x0 := -62.0; var x1 := -22.0; var z0 := -28.0; var z1 := 20.0
	box(x0, DESK_Y - 1.0, z0, x1, DESK_Y, z1, "c8a26b", "wood")
	box(x0, 0, z0, x0 + 18.0, DESK_Y - 1.0, z0 + 16.0, "b98f58", "wood")   # the drawer unit
	for i in 3: box(x0 + 18.0, 0.6 + i * 2.6, z0 + 1.0, x0 + 18.4, 2.8 + i * 2.6, z0 + 15.0, "a67c48", "wood", false)
	for p in [[x1 - 2.0, z0], [x1 - 2.0, z1 - 2.0], [x0, z1 - 2.0]]: box(p[0], 0, p[1], p[0] + 2.0, DESK_Y - 1.0, p[1] + 2.0, "a67c48", "wood")
	# the pencil holder and its pencils: a round tower to shoot from behind
	cyl(Vector3(-50.0, DESK_Y + 4.0, 10.0), 3.4, 8.0, "2a9d8f")
	for p in [[-51.2, 9.0, "f4d35e", 0.12], [-49.0, 11.2, "e63946", -0.1], [-50.4, 11.4, "3d7dca", 0.05], [-48.8, 8.8, "5fbf8f", -0.14]]:
		var pc := cyl(Vector3(p[0], DESK_Y + 9.5, p[1]), 0.34, 9.0, p[2], false); pc.rotation.z = p[3]; var tip := cyl(Vector3(p[0] - sin(p[3]) * 5.0, DESK_Y + 14.4, p[1]), 0.34, 1.0, "3a2a1a", false, 0.02); tip.rotation.z = p[3]
	# the desk lamp: a heavy base, and its bent neck is the climb to the bookshelf
	cyl(Vector3(-34.0, DESK_Y + 0.5, -22.0), 3.6, 1.0, "e9c46a")
	stairs(-34.0, DESK_Y + 1.0, -24.0, "-z", 22, (SHELF_Y - DESK_Y - 1.0) / 22.0, 1.25, 2.4, "e9c46a", "dcb353")
	box(-37.0, SHELF_Y - 0.4, -56.0, -31.0, SHELF_Y, -51.5, "e9c46a")   # the lamp head rests against the shelf: the last stretch
	var shade := cyl(Vector3(-40.0, SHELF_Y + 3.0, -46.0), 4.2, 4.0, "f4a261", false, 1.6); shade.rotation.z = 0.5
	# stacked school books: steps up from the floor to the desk on the south side, and cover on top
	stairs(-22.0, 0, z1 + 4.0, "-x", 19, 0.47, 0.95, 8.0, "e63946", "3d7dca")   # along the desk's south edge, rising westward; step off north onto the desk
	box(-46.0, DESK_Y, -8.0, -38.0, DESK_Y + 1.1, 0.0, "3d7dca"); box(-45.4, DESK_Y + 1.1, -7.2, -38.8, DESK_Y + 2.1, -0.6, "e63946"); box(-44.6, DESK_Y + 2.1, -6.4, -39.6, DESK_Y + 3.0, -1.4, "f4d35e")
	box(-30.0, DESK_Y, 6.0, -24.0, DESK_Y + 2.4, 16.0, "9b7fd1"); box(-60.0, DESK_Y, -4.0, -56.0, DESK_Y + 6.0, 6.0, "f2f2f2")   # a box of crayons, an eraser block
	# the globe
	cyl(Vector3(-56.0, DESK_Y + 0.4, -20.0), 2.2, 0.8, "5a4632"); cyl(Vector3(-56.0, DESK_Y + 1.6, -20.0), 0.35, 2.0, "5a4632", false); ball(Vector3(-56.0, DESK_Y + 5.4, -20.0), 3.2, "3d8bd4")

## the middle: a bridge of building blocks from the desk to the bed, where the two sides meet head on
func _bridge() -> void:
	var cols := ["e63946", "f4d35e", "3d7dca", "5fbf8f", "f77f00"]
	for i in 8: box(-22.0 + i * 2.0, DESK_Y - 0.8, -4.0, -20.0 + i * 2.0, DESK_Y, 4.0, cols[i % 5])                                    # the level deck, 16 m
	for i in 8: box(-6.0 + i * 2.0, DESK_Y - 0.8 - (i + 1) * 0.375, -4.0, -4.0 + i * 2.0, DESK_Y - (i + 1) * 0.375, 4.0, cols[(i + 2) % 5])   # eight blocks down to the mattress
	for px in [-16.0, -6.0, 4.0]:                                                                                                       # towers of blocks under it
		var h := DESK_Y - 0.8 if px < -5.0 else BED_Y - 1.2
		var k := 0; var y := 0.0
		while y < h - 0.01: var top := minf(y + 1.6, h); box(px - 1.6, y, -3.0, px + 1.6, top, 3.0, cols[k % 5]); y = top; k += 1
	for c in [[-18.0, -4.0], [-12.0, 3.0], [-4.0, -4.0], [2.0, 3.0]]: box(c[0], DESK_Y - (0.0 if c[0] < -6.0 else (c[0] + 6.0) / 2.0 * 0.375 + 0.375), c[1], c[0] + 2.0, DESK_Y + 1.5 - (0.0 if c[0] < -6.0 else (c[0] + 6.0) / 2.0 * 0.375), c[1] + 1.0, cols[int(absf(c[0])) % 5])   # blocks to duck behind
	for i in 16: cyl(Vector3(-21.0 + i * 2.0, DESK_Y + 0.12 - (0.0 if i < 8 else (i - 7) * 0.375), -3.0), 0.5, 0.24, cols[i % 5], false)                 # studs

## south: the carpet, the toy bins, the train. open ground and the long way round
func _south() -> void:
	box(-46.0, 0.0, 34.0, 46.0, 0.08, 66.0, "d8a7b1", "bed", false); box(-43.0, 0.08, 36.0, 43.0, 0.1, 64.0, "e9c7ce", "bed", false)   # the rug
	for b in [[-52.0, "3d7dca"], [42.0, "e63946"]]:   # two toy bins, one by each side's start
		box(b[0], 0, 46.0, b[0] + 10.0, 7.0, 47.0, b[1]); box(b[0], 0, 57.0, b[0] + 10.0, 7.0, 58.0, b[1]); box(b[0], 0, 47.0, b[0] + 1.0, 7.0, 57.0, b[1]); box(b[0] + 9.0, 0, 47.0, b[0] + 10.0, 7.0, 57.0, b[1])
		box(b[0] + 1.0, 0, 47.0, b[0] + 9.0, 4.4, 57.0, "f4d35e", "bed")
	var cols := ["e63946", "f4d35e", "3d7dca", "5fbf8f", "f77f00", "9b7fd1"]
	var blocks := [[-24.0, 40.0, 4.0, 2.0, 2.0], [-18.0, 50.0, 2.0, 2.0, 4.0], [-8.0, 58.0, 4.0, 3.2, 2.0], [8.0, 40.0, 2.0, 2.0, 2.0], [14.0, 52.0, 6.0, 2.0, 2.0], [24.0, 44.0, 2.0, 4.0, 2.0], [-30.0, 60.0, 2.0, 2.0, 2.0], [30.0, 60.0, 4.0, 2.0, 2.0]]
	for i in blocks.size():
		var b: Array = blocks[i]
		if not _skip("block_%d_%d" % [int(b[0]), int(b[1])]): box(b[0], 0, b[1], b[0] + b[2], b[3], b[1] + b[4], cols[i % 6])
	ball(Vector3(-12.0, 2.4, 44.0), 2.4, "f77f00"); ball(Vector3(20.0, 1.5, 60.0), 1.5, "5fbf8f"); ball(Vector3(-36.0, 1.2, 42.0), 1.2, "9b7fd1")
	_catapult(-14.0, 30.0, Vector3(-5.6, 34.0, -32.2))   # to the top of the bookshelf
	_catapult(52.0, 41.0, Vector3(-2.4, 30.0, -12.0))     # from the south-east corner onto the upper bunk
	if not _skip("tacks_mid"): tacks.push_back({"x": -4.0, "z": 46.0, "r": 5.0})
	if not _skip("tacks_east"): tacks.push_back({"x": 30.0, "z": 43.0, "r": 3.5})
	for t in tacks:
		for i in 14:
			var a := i * 2.4; var rr: float = t.r * sqrt((i + 0.5) / 14.0); var p := Vector3(t.x + cos(a) * rr, 0.0, t.z + sin(a) * rr)
			cyl(p + Vector3(0, 0.06, 0), 0.5, 0.12, ["e63946", "f4d35e", "3d7dca"][i % 3], false); cyl(p + Vector3(0, 0.5, 0), 0.05, 0.8, "c9ced6", false, 0.0)
	# the train: a loop of track round the carpet and under the desk's edge, an engine and two flat wagons you can ride
	var loop := [Vector3(-66.0, 0, 36.5), Vector3(66.0, 0, 36.5), Vector3(66.0, 0, 67.0), Vector3(-66.0, 0, 67.0)]
	if _skip("train"): train = {"loop": loop, "t": 0.0, "speed": 0.0, "cars": []}; return   # (the escort: its own train on its own track)
	for i in 4:
		var a: Vector3 = loop[i]; var b: Vector3 = loop[(i + 1) % 4]; var along_x := absf(b.x - a.x) > 1.0
		for s in [-0.9, 0.9]: box(minf(a.x, b.x) - (0.0 if along_x else -s + 0.1), 0, minf(a.z, b.z) - (-s + 0.1 if along_x else 0.0), maxf(a.x, b.x) + (0.0 if along_x else s + 0.1), 0.14, maxf(a.z, b.z) + (s + 0.1 if along_x else 0.0), "8d99ae", "metal", false)
	train = {"loop": loop, "t": 0.0, "speed": 9.0, "cars": []}
	for i in 3:
		var n := Node3D.new(); G.add_child(n)
		var m := MeshInstance3D.new(); n.add_child(m); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.5; m.material_override = mat
		if i == 0: m.mesh = Gfx.merge_boxes([[2.6, 0.5, 5.0, 0, 0.45, 0, "2b2d42"], [2.2, 1.8, 3.0, 0, 1.6, 0.8, "e63946"], [2.4, 2.4, 1.6, 0, 1.9, -1.6, "e63946"], [0.7, 1.2, 0.7, 0, 3.1, 1.4, "2b2d42"], [2.6, 0.3, 1.8, 0, 3.25, -1.6, "f4d35e"]], true)
		else: m.mesh = Gfx.merge_boxes([[2.8, 0.45, 5.0, 0, 0.225, 0, "3d7dca" if i == 1 else "5fbf8f"], [0.2, 0.7, 5.0, -1.3, 0.8, 0, "f4d35e"], [0.2, 0.7, 5.0, 1.3, 0.8, 0, "f4d35e"]], true)
		train.cars.push_back({"n": n, "b": null, "off": i * 6.0, "pos": Vector3.ZERO, "engine": i == 0})

## north: the bookshelf and the wardrobe. the top of the room, hard to reach, a long way to see
func _north() -> void:
	box(-62.0, 0, -HALF, -6.0, SHELF_Y, -56.0, "8d6e4b", "wood")
	for i in 4: box(-61.0, 4.0 + i * 4.0, -56.2, -7.0, 4.4 + i * 4.0, -56.0, "6f553a", "wood", false)
	var cols := ["e63946", "f4d35e", "3d7dca", "5fbf8f", "f77f00", "9b7fd1", "f2f2f2"]
	for i in 26: box(-60.0 + i * 2.05, 0.2 + (i % 4) * 4.0 + 0.4, -56.4, -58.2 + i * 2.05, 3.4 + (i % 4) * 4.0 + (i % 3) * 0.2, -56.0, cols[i % 7], "wood", false)   # book spines
	for b in [[-58.0, 3.2, 6.0], [-48.0, 2.4, 9.0], [-22.0, 3.6, 5.0], [-14.0, 2.0, 4.0]]: box(b[0], SHELF_Y, -66.0, b[0] + b[2], SHELF_Y + b[1], -60.0, cols[int(absf(b[0])) % 7])   # books lying on top: cover
	box(6.0, 0, -HALF, 50.0, WARD_Y, -54.0, "f1e3c8", "wood"); box(27.8, 0.5, -54.2, 28.2, WARD_Y - 0.5, -54.0, "cbb894", "wood", false)
	cyl(Vector3(26.0, 12.0, -53.8), 0.5, 0.5, "c9a227", false); cyl(Vector3(30.0, 12.0, -53.8), 0.5, 0.5, "c9a227", false)
	box(12.0, WARD_Y, -66.0, 22.0, WARD_Y + 3.0, -58.0, "c98b5a"); box(34.0, WARD_Y, -64.0, 44.0, WARD_Y + 2.0, -58.0, "9b7fd1")   # a shoe box, a folded jumper
	# a ruler laid from the bookshelf to the wardrobe, and a few steps of books up to the wardrobe's top
	box(-8.0, SHELF_Y - 0.4, -63.0, 6.0, SHELF_Y, -60.0, "ffe066", "wood")
	stairs(-3.0, SHELF_Y, -61.5, "+x", 9, (WARD_Y - SHELF_Y) / 9.0, 1.0, 3.0, "3d7dca", "e63946")
	# the tape measure: hooked on the wardrobe's top, its tape pulled out across the room down to the upper bunk. a zipline
	box(40.0, WARD_Y, -60.0, 44.0, WARD_Y + 3.0, -57.6, "f4d35e")
	_zip(Vector3(42.0, WARD_Y + 2.2, -54.4), Vector3(30.0, BUNK_Y + 2.6, 0.0))   # down onto the upper bunk
	_zip(Vector3(-20.0, SHELF_Y + 1.8, -55.4), Vector3(-30.0, DESK_Y + 2.0, -6.0))   # a shoelace from the bookshelf down to the desk

# ---------- gimmicks ----------
func _spring(x: float, z: float, y: float, vy: float) -> void:
	for i in 4: cyl(Vector3(x, y + 0.12 + i * 0.16, z), 1.5 - (i % 2) * 0.2, 0.08, "c9ced6", false)
	cyl(Vector3(x, y + 0.82, z), 1.9, 0.2, "e63946", false)
	Phys.add_collider(x - 1.7, y, z - 1.7, x + 1.7, y + 0.45, z + 1.7, "metal")
	pads.push_back({"x": x, "z": z, "y": y + 0.45, "r": 1.9, "vy": vy})

func _catapult(x: float, z: float, vel: Vector3) -> void:
	box(x - 2.0, 0, z - 1.4, x + 2.0, 0.45, z + 1.4, "8d6e4b", "wood"); var arm := Node3D.new(); G.add_child(arm); arm.position = Vector3(x, 0.45, z); arm.rotation.y = atan2(vel.x, vel.z)
	var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes([[0.5, 0.3, 5.0, 0, 1.4, -1.6, "c98b5a"], [0.4, 1.8, 0.4, -0.9, 0.9, 0.6, "8d6e4b"], [0.4, 1.8, 0.4, 0.9, 0.9, 0.6, "8d6e4b"], [1.8, 0.2, 1.8, 0, 1.3, -3.8, "f4d35e"]], true)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.7; m.material_override = mat; m.rotation.x = -0.3; arm.add_child(m)
	catapults.push_back({"x": x, "z": z, "y": 0.45, "r": 1.6, "vel": vel})

func _zip(a: Vector3, b: Vector3) -> void:
	var d := b - a; var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5, 0.04, d.length()); m.mesh = bm; m.material_override = Gfx.std(Color("ffe066"), 0.5); G.add_child(m)
	m.look_at_from_position((a + b) / 2, b, Vector3.UP)
	ziplines.push_back({"a": a, "b": b, "speed": 20.0})

func _loop_at(d: float) -> Array:   # a point d metres along the train's loop, and the heading there
	var loop: Array = train.loop; var total := 0.0; var seg := []
	for i in 4: var l: float = (loop[(i + 1) % 4] - loop[i]).length(); seg.push_back(l); total += l
	d = fposmod(d, total)
	for i in 4:
		if d <= seg[i]: var a: Vector3 = loop[i]; var b: Vector3 = loop[(i + 1) % 4]; return [a.lerp(b, d / seg[i]), atan2(b.x - a.x, b.z - a.z)]
		d -= seg[i]
	return [loop[0], 0.0]

## what the room does each frame: the train runs, springs and catapults throw you, the tape measure carries you, tacks hurt
func update(dt: float, p: Player) -> void:
	# the train: each car is a moving platform; standing on one, you go with it
	if not train_hold: train.t += dt * train.speed
	for c in train.cars:
		var at: Array = _loop_at(train.t - c.off); var np: Vector3 = at[0]; var old: Vector3 = c.pos
		var top := 0.45 if not c.engine else 3.4; var hx := 1.4 if absf(sin(at[1])) < 0.5 else 2.5; var hz := 2.5 if absf(sin(at[1])) < 0.5 else 1.4
		var on: bool = c.b != null and absf(p.pos.x - old.x) < hx + Player.R and absf(p.pos.z - old.z) < hz + Player.R and absf(p.pos.y - top) < 0.12 and p.grounded
		if c.b != null: Phys.remove_collider(c.b)
		c.b = Phys.add_collider(np.x - hx, 0, np.z - hz, np.x + hx, top, np.z + hz, "metal"); c.b.step = true   # (the flow field ignores it)
		if on and old != Vector3.ZERO: p.pos += np - old
		elif Phys.collide_at(p.pos.x, p.pos.y, p.pos.z, Player.R, Player.HEIGHT) == c.b:   # it runs into you: you are pushed along and it stings
			p.pos = Phys.move_xz(p.pos, (np.x - old.x) * 1.5, (np.z - old.z) * 1.5, Player.R, Player.HEIGHT, 0.0)[0]
			if Phys.collide_at(p.pos.x, p.pos.y, p.pos.z, Player.R, Player.HEIGHT) == c.b: p.pos.y = top + 0.01
		c.pos = np; (c.n as Node3D).position = np; (c.n as Node3D).rotation.y = at[1]
	# the tape measure: touch its top end and you slide down it
	if riding != null:
		var L: Dictionary = riding.line; var len_: float = (L.b - L.a).length(); riding.t += L.speed * dt / len_
		var q: Vector3 = (L.a as Vector3).lerp(L.b, minf(riding.t, 1.0)); p.pos = q - Vector3(0, 1.9, 0); p.vel = Vector3.ZERO; p.grounded = false
		if riding.t >= 1.0: p.vel = (L.b - L.a).normalized() * 6.0; riding = null
		return
	for L in ziplines:
		if Vector3(p.pos.x, p.pos.y + 1.0, p.pos.z).distance_to(L.a) < 2.2 and p.since_zip > 1.0: riding = {"line": L, "t": 0.0}; p.since_zip = 0.0; return
	p.since_zip += dt
	if p.grounded:
		for s in pads:
			if absf(p.pos.y - s.y) < 0.2 and Vector2(p.pos.x - s.x, p.pos.z - s.z).length() < s.r: p.vel.y = s.vy; p.grounded = false; Snd.play("pump")
		for c in catapults:
			if absf(p.pos.y - c.y) < 0.2 and Vector2(p.pos.x - c.x, p.pos.z - c.z).length() < c.r: p.launch(c.vel); Snd.play("swing")
	# a softer, springier jump on a mattress
	p.jump_mul = 1.0
	for b in beds:
		if absf(p.pos.y - b[4]) < 0.3 and p.pos.x > b[0] and p.pos.x < b[2] and p.pos.z > b[1] and p.pos.z < b[3]: p.jump_mul = 1.18
	# thumbtacks: they slow you and prick
	p.slow_mul = 1.0; _tack_t -= dt
	for t in tacks:
		if p.pos.y < 0.3 and Vector2(p.pos.x - t.x, p.pos.z - t.z).length() < t.r:
			p.slow_mul = 0.55
			if _tack_t <= 0.0: _tack_t = 0.5; p.hurt(20.0, Vector3(t.x, 0, t.z), "fire")
