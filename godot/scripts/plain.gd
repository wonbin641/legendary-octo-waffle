class_name BannerPlain
extends RefCounted
## Stage 6-2, 네 깃발 평원 (the plain of the four banners): a square of open grassland 144 m a side, ringed by low cliffs
## and the hills beyond them. In each corner stands one people's landmark under its own banner, and each summons its
## people every so often (ModePlain): the elves' moon spire in the north-west, the dwarves' rune forge in the north-east,
## the orcs' war totem in the south-west, the demons' rift gate in the south-east. Between them the old crossing stones in
## the middle, a road from each corner to them and a ring road round them, and the plain's cover: boulders, low walls of
## fieldstone, a few groves; each corner's ground kept as its people keeps it.
## Everything here is boxes to stand on or against, as everywhere in this port. A landmark's boxes carry the landmark
## (ModePlain makes it a thing that can be broken, and a shot that meets one of its boxes meets it); when it falls it sinks
## into its own dust and its ruin is left where it stood.

const HALF := 76.0                 # to the cliffs' outer face (the collision world)
const IN := 72.0                   # the walkable square's half side: the cliffs' foot
const CORNER := 50.0               # each landmark's middle, out from the map's middle along x and along z
const SPOT := {"elf": Vector2(-1, -1), "dwarf": Vector2(1, -1), "orc": Vector2(-1, 1), "demon": Vector2(1, 1)}   # north-west, north-east, south-west, south-east
const NAMES := {"elf": "달빛 첨탑", "dwarf": "룬 대장간", "orc": "전쟁 토템", "demon": "지옥 균열문"}
const BODY := {"elf": [4.4, 15.0], "dwarf": [6.4, 9.5], "orc": [5.4, 13.0], "demon": [4.8, 12.0]}   # what of it can be struck: the radius of its middle, its height
const RING := 30.0                 # the ring road round the middle
const STONES := 10.0               # the crossing stones' circle
const GRID := 9.0                  # the others' waypoints: one every so many metres over the open ground

const C_GRASS := Color("5f7d3a"); const C_GRASS2 := Color("6f8e44"); const C_GRASS3 := Color("4f6c32"); const C_ROAD := Color("9a8462"); const C_ROAD2 := Color("85704f")
const C_ROCK := Color("7d7a70"); const C_ROCK2 := Color("66635b"); const C_CLIFF := Color("8a7f6a"); const C_CLIFF2 := Color("6e6452"); const C_HILL := Color("6f8458"); const C_HILL2 := Color("5d7449")
const C_BARK := Color("5a4330"); const C_LEAF := Color("4f7a34"); const C_LEAF2 := Color("3f6a2c")
const C_MARBLE := Color("dfe4e2"); const C_MARBLE2 := Color("c2cac8"); const C_SILVER := Color("b9c6cc"); const C_TEAL := Color("63d8c2"); const C_CYAN := Color("8ff7ea"); const C_MOSS := Color("3f6a52")
const C_STONE := Color("8d8f96"); const C_STONE2 := Color("6f7178"); const C_BRASS := Color("d6a43a"); const C_EMBER := Color("ff8a2a"); const C_IRON := Color("4a4e56"); const C_PAVE := Color("8a8a84")
const C_HIDE := Color("a8875c"); const C_HIDE2 := Color("8a6a44"); const C_WOOD := Color("6c4a2c"); const C_BONE := Color("e8e0c8"); const C_RED := Color("a8281e"); const C_ORCG := Color("7fae4a"); const C_DIRT := Color("7a6046")
const C_OBS := Color("231a24"); const C_OBS2 := Color("3a2a3c"); const C_LAVA := Color("ff5a1a"); const C_HELL := Color("c8503a"); const C_VIOLET := Color("b02ad8"); const C_ASH := Color("3d3432")

var world: World; var G: Node3D
var kit := MeshKit.new()           # the plain's own lit things, one mesh
var glow := MeshKit.new()          # what shines by itself
var clear := MeshKit.new()         # what is seen through (the banners' cloth)
var halls := {}                    # race -> its landmark: {at, front, side, node, boxes, ruin, ruin_boxes, fallen, fall_t, spin, smoke, hurt}
var trees: Array = []              # [x, z, r] (the map draws them)
var rocks: Array = []              # [x, z, half w, half d] (the boulders)
var fx: Fx = null
var rm = null                      # the battle on this plain (Realm)
var t := 0.0
var _lit: StandardMaterial3D; var _glow_m: StandardMaterial3D; var _clear_m: StandardMaterial3D
var _hk := {}                      # the landmark being built: its own kits (lit, glow, clear, spin)
var _smoke_t := 0.0

static func at(race: String) -> Vector3: var s: Vector2 = SPOT[race]; return Vector3(s.x * CORNER, 0.0, s.y * CORNER)
## the way a landmark faces: toward the middle of the plain
static func front(race: String) -> Vector3: var s: Vector2 = SPOT[race]; return -Vector3(s.x, 0.0, s.y).normalized()
static func side(race: String) -> Vector3: var f := front(race); return Vector3(-f.z, 0.0, f.x)
## where its summoned stand when they appear, in front of it (and you, when you come back at yours)
static func spots(race: String) -> Array:
	var c := at(race); var f := front(race); var s := side(race); var out: Array = []
	for i in 6: out.push_back(c + f * (float(BODY[race][0]) + 4.5 + (i / 3) * 2.2) + s * ((i % 3) - 1) * 2.6)
	return out

# ---------------- building helpers ----------------
## a box to see and to stand against, in the kit given (a landmark's boxes are kept with it)
func block(k: MeshKit, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color, keep = null) -> Phys.Box:
	k.slab(x0, y0, z0, x1, y1, z1, col)
	var b := Phys.add_collider(x0, y0, z0, x1, y1, z1, "concrete")
	if keep != null: (keep as Array).push_back(b)
	return b
func wall(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, keep = null) -> Phys.Box:
	var b := Phys.add_collider(x0, y0, z0, x1, y1, z1, "concrete")
	if keep != null: (keep as Array).push_back(b)
	return b

func build(w: World, group: Node3D, mine := "elf") -> void:
	world = w; G = group
	Phys.set_world_size(HALF); Phys.set_nav(int(HALF * 2.0) + 4, 1.0)
	_lit = StandardMaterial3D.new(); _lit.vertex_color_use_as_albedo = true; _lit.roughness = 0.92
	_glow_m = Gfx.unlit(Color.WHITE, false); _glow_m.vertex_color_use_as_albedo = true
	_clear_m = Gfx.unlit(Color.WHITE, false); _clear_m.vertex_color_use_as_albedo = true; _clear_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _clear_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground(); _roads(); _middle(); _border(); _hills()
	for r: String in ["elf", "dwarf", "orc", "demon"]: _hall(r)
	_groves(); _cover()
	_node(kit, glow, clear, G)
	var s0 := (spots(mine)[1] as Vector3); var f := front(mine)
	world.start = {"x": s0.x, "z": s0.z, "yaw": atan2(-f.x, -f.z)}; world.spawns.clear()
	Phys.index_colliders(); Phys.build_nav()

## kits into the scene: the lit, the shining and the see-through, each one mesh
func _node(lit: MeshKit, gl: MeshKit, cl: MeshKit, parent: Node3D) -> void:
	if not lit.is_empty(): lit.node(_lit, parent)
	if not gl.is_empty(): var gn := gl.node(_glow_m, parent); gn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not cl.is_empty(): var cn := cl.node(Gfx.see_through(_clear_m), parent); cn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------- the ground ----------------
func _ground() -> void:
	kit.slab(-HALF - 2.0, -0.6, -HALF - 2.0, HALF + 2.0, 0.0, HALF + 2.0, C_GRASS)
	var R := World.Rng.new(6201)
	for i in 170:   # the grass in lighter and darker drifts
		var x: float = R.rng(-IN + 3.0, IN - 3.0); var z: float = R.rng(-IN + 3.0, IN - 3.0); var r: float = R.rng(2.0, 6.5)
		kit.disc(x, 0.005 + (i % 4) * 0.003, z, r, [C_GRASS2, C_GRASS3, C_GRASS.lightened(0.06)][i % 3], 9)
	for i in 90:   # small flowers, as light specks in the grass
		var x: float = R.rng(-IN + 4.0, IN - 4.0); var z: float = R.rng(-IN + 4.0, IN - 4.0); var col: Color = [Color("f2e6a8"), Color("e8c0e8"), Color("f4f4ee")][i % 3]
		for j in 4: kit.disc(x + R.rng(-1.0, 1.0), 0.03, z + R.rng(-1.0, 1.0), 0.09, col, 5)
	# each corner's own ground
	var GR := {"elf": [C_MOSS, C_MOSS.lightened(0.1)], "dwarf": [C_PAVE, C_PAVE.darkened(0.12)], "orc": [C_DIRT, C_DIRT.darkened(0.15)], "demon": [C_ASH, C_ASH.lightened(0.06)]}
	for r: String in GR:
		var c := at(r)
		kit.disc(c.x, 0.012, c.z, 21.0, GR[r][0], 24)
		for i in 26:
			var a := i * 2.399963; var d := 5.0 + fposmod(i * 3.7, 15.0)
			kit.disc(c.x + cos(a) * d, 0.018, c.z + sin(a) * d, 1.4 + (i % 3) * 0.7, GR[r][1], 8)
		if r == "dwarf":   # flagstones
			for i in 9:
				for j in 9:
					if (i + j) % 2 == 0: kit.slab(c.x - 13.5 + i * 3.0, 0.0, c.z - 13.5 + j * 3.0, c.x - 11.0 + i * 3.0, 0.025, c.z - 11.0 + j * 3.0, C_PAVE.lightened(0.05))
		if r == "demon":   # the burnt ground's cracks, lava showing through
			for i in 11:
				var a := i * TAU / 11.0 + 0.3; var p0 := c + Vector3(cos(a), 0, sin(a)) * 6.5; var p1 := c + Vector3(cos(a + 0.18), 0, sin(a + 0.18)) * 17.0
				glow.strip(Vector3(p0.x, 0.03, p0.z), Vector3(p1.x, 0.03, p1.z), 0.28 - (i % 3) * 0.06, C_LAVA)

## a road from each landmark's door to the stones in the middle, and the ring road round them
func _roads() -> void:
	for r: String in SPOT:
		var c := at(r); var f := front(r); var a := c + f * (float(BODY[r][0]) + 2.0); var b := -f * (STONES + 3.0)
		kit.strip(Vector3(a.x, 0.04, a.z), Vector3(b.x, 0.04, b.z), 4.6, C_ROAD)
		kit.strip(Vector3(a.x, 0.045, a.z), Vector3(b.x, 0.045, b.z), 1.2, C_ROAD2)
	var n := 28
	for i in n:
		var a0 := i * TAU / n; var a1 := (i + 1) * TAU / n
		kit.strip(Vector3(cos(a0) * RING, 0.035, sin(a0) * RING), Vector3(cos(a1) * RING, 0.035, sin(a1) * RING), 3.6, C_ROAD)

## the old crossing stones: a low round dais and ten standing stones about it
func _middle() -> void:
	kit.cyl(0, 0, 0, 5.4, 5.1, 0.35, C_ROCK, 18, true, false, 0.0, TAU, C_ROCK.lightened(0.08))
	wall(-5.0, 0.0, -2.4, 5.0, 0.35, 2.4); wall(-2.4, 0.0, -5.0, 2.4, 0.35, 5.0)   # (a cross of two boxes, near enough the round dais)
	glow.disc(0, 0.37, 0, 2.2, Color("f2d58a").darkened(0.35), 18, 1.9)   # (a worn ring of old runes)
	for i in 10:
		var a := i * TAU / 10.0 + 0.16; var x := cos(a) * STONES; var z := sin(a) * STONES
		var w := 0.7 + (i % 3) * 0.15; var h := 3.2 + (i % 4) * 0.55
		if i == 3 or i == 8: h = 1.3   # (two have fallen: something to crouch behind)
		block(kit, x - w, 0.0, z - w * 0.7, x + w, h, z + w * 0.7, C_ROCK2 if i % 2 == 0 else C_ROCK)
		kit.slab(x - w - 0.05, h - 0.12, z - w * 0.7 - 0.05, x + w + 0.05, h, z + w * 0.7 + 0.05, C_MOSS.lerp(C_ROCK, 0.5))

## the cliffs all round (what stops you), the grass on their tops
func _border() -> void:
	wall(-HALF, -1.0, -HALF, HALF, 14.0, -IN); wall(-HALF, -1.0, IN, HALF, 14.0, HALF)
	wall(-HALF, -1.0, -HALF, -IN, 14.0, HALF); wall(IN, -1.0, -HALF, HALF, 14.0, HALF)
	var R := World.Rng.new(6202)
	for side_i in 4:
		var x := -HALF
		while x < HALF:
			var w: float = R.rng(6.0, 10.0); var h: float = R.rng(6.0, 11.5); var d: float = R.rng(0.0, 0.4)   # (a face no more than a hand in front of what stops you)
			var x1 := minf(HALF, x + w)
			var col: Color = C_CLIFF if int(x) % 3 != 0 else C_CLIFF2
			match side_i:
				0: kit.slab(x, 0.0, -HALF - 2.0, x1, h, -IN + d, col); kit.slab(x, h, -HALF - 2.0, x1, h + 0.3, -IN + d, C_GRASS3)
				1: kit.slab(x, 0.0, IN - d, x1, h, HALF + 2.0, col); kit.slab(x, h, IN - d, x1, h + 0.3, HALF + 2.0, C_GRASS3)
				2: kit.slab(-HALF - 2.0, 0.0, x, -IN + d, h, x1, col); kit.slab(-HALF - 2.0, h, x, -IN + d, h + 0.3, x1, C_GRASS3)
				3: kit.slab(IN - d, 0.0, x, HALF + 2.0, h, x1, col); kit.slab(IN - d, h, x, HALF + 2.0, h + 0.3, x1, C_GRASS3)
			x = x1
	for i in 40:   # boulders fallen at the cliffs' foot
		var along: float = R.rng(-IN + 4.0, IN - 4.0); var s: float = R.rng(0.6, 1.4)
		var p := Vector3(along, 0, -IN + s + 0.4) if i % 4 == 0 else (Vector3(along, 0, IN - s - 0.4) if i % 4 == 1 else (Vector3(-IN + s + 0.4, 0, along) if i % 4 == 2 else Vector3(IN - s - 0.4, 0, along)))
		block(kit, p.x - s, 0.0, p.z - s * 0.8, p.x + s, s * 1.2, p.z + s * 0.8, C_ROCK2 if i % 2 == 0 else C_ROCK)

## hills beyond the cliffs, to the horizon
func _hills() -> void:
	for i in 22:
		var a := i * TAU / 22.0 + 0.11; var d := 150.0 + (i % 4) * 14.0; var r := 36.0 + (i % 5) * 7.0   # (each well beyond the cliffs)
		kit.dome(cos(a) * d, -2.0, sin(a) * d, r, C_HILL if i % 2 == 0 else C_HILL2, 12, 4, 0.32 + (i % 3) * 0.06, false, C_HILL.lightened(0.08))

# ---------------- trees, boulders, walls ----------------
func tree(x: float, z: float, s := 1.0) -> void:
	kit.cyl(x, 0, z, 0.55 * s, 0.38 * s, 5.4 * s, C_BARK, 8, false)
	wall(x - 0.45 * s, 0.0, z - 0.45 * s, x + 0.45 * s, 5.4 * s, z + 0.45 * s)
	for i in 3:
		var a := i * TAU / 3.0 + x * 0.3; var o := 1.3 * s
		kit.dome(x + cos(a) * o, 4.4 * s + i * 0.5, z + sin(a) * o, 2.6 * s, C_LEAF if i % 2 == 0 else C_LEAF2, 9, 3, 0.8, false, C_LEAF.lightened(0.1))
		kit.disc(x + cos(a) * o, 4.4 * s + i * 0.5, z + sin(a) * o, 2.6 * s, C_LEAF2.darkened(0.3), 9, 0.0, 0.0, TAU, false)
	trees.push_back([x, z, 3.2 * s])

## a silverwood of the elves' corner: a pale trunk, a teal crown
func silver_tree(x: float, z: float, s := 1.0) -> void:
	kit.cyl(x, 0, z, 0.5 * s, 0.32 * s, 8.0 * s, C_SILVER, 8, false)
	wall(x - 0.4 * s, 0.0, z - 0.4 * s, x + 0.4 * s, 8.0 * s, z + 0.4 * s)
	for i in 3:
		var a := i * TAU / 3.0 + z * 0.4
		kit.dome(x + cos(a) * 1.2 * s, 6.5 * s + i * 0.6, z + sin(a) * 1.2 * s, 2.3 * s, Color("2b6257") if i % 2 == 0 else Color("1d4741"), 9, 3, 0.7, false, C_TEAL.darkened(0.3))
	for i in 2: glow.box(0.12, 0.22, 0.04, x + cos(i * 2.0) * 0.45 * s, 2.0 + i * 1.6, z + sin(i * 2.0) * 0.45 * s, C_CYAN.darkened(0.1))
	trees.push_back([x, z, 2.8 * s])

func _groves() -> void:
	var at_ := [[-20.0, -38.0], [22.0, 36.0], [-38.0, 16.0], [36.0, -18.0], [-6.0, 52.0], [8.0, -54.0], [54.0, 6.0], [-54.0, -8.0]]
	var R := World.Rng.new(6203)
	for gi in at_.size():
		var gx: float = at_[gi][0]; var gz: float = at_[gi][1]
		for j in 3 + gi % 2:
			var a: float = R.rng(0.0, TAU); var d: float = R.rng(0.0, 4.5)
			tree(gx + cos(a) * d, gz + sin(a) * d, R.rng(0.85, 1.2))
	for p: Array in [[-60.0, -36.0], [-36.0, -62.0], [-64.0, -58.0], [-30.0, -44.0], [-44.0, -30.0]]: silver_tree(p[0], p[1], 1.0 + fposmod(p[0] * 0.13, 0.3))

## whether a place is clear for a boulder or a wall: off the roads, away from the landmarks and the stones, apart from the rest
func _free(x: float, z: float, room: float) -> bool:
	if absf(x) > IN - 6.0 or absf(z) > IN - 6.0: return false
	var p := Vector2(x, z)
	if p.length() < STONES + 5.0 or absf(p.length() - RING) < 3.2 + room: return false
	for r: String in SPOT:
		var c := at(r); var f := front(r)
		if p.distance_to(Vector2(c.x, c.z)) < float(BODY[r][0]) + 13.0: return false
		# (the road from it to the middle: its line, and a few metres either side)
		var a := Vector2(c.x, c.z); var d := Vector2(-f.x, -f.z) * -1.0; d = Vector2(f.x, f.z)
		var along := (p - a).dot(d)
		if along > 0.0 and along < a.length() and absf((p - a).cross(d)) < 3.5 + room: return false
	for q: Array in rocks:
		if p.distance_to(Vector2(q[0], q[1])) < 6.0 + room: return false
	for q: Array in trees:
		if p.distance_to(Vector2(q[0], q[1])) < float(q[2]) + 2.0 + room: return false
	return true

func _cover() -> void:
	var R := World.Rng.new(6204); var n := 0; var tries := 0
	while n < 30 and tries < 900:
		tries += 1
		var x: float = R.rng(-IN + 6.0, IN - 6.0); var z: float = R.rng(-IN + 6.0, IN - 6.0); var w: float = R.rng(0.9, 1.8); var d: float = R.rng(0.8, 1.5); var h: float = R.rng(1.1, 2.4)
		if not _free(x, z, maxf(w, d)): continue
		block(kit, x - w, 0.0, z - d, x + w, h, z + d, C_ROCK if n % 2 == 0 else C_ROCK2)
		kit.slab(x - w * 0.7, h, z - d * 0.6, x + w * 0.6, h + 0.35, z + d * 0.7, C_ROCK.lightened(0.05))   # (its rounder top)
		rocks.push_back([x, z, w, d]); n += 1
	# low fieldstone walls across the open ground between the corners
	var walls := [[0.0, -44.0, 9.0, true], [0.0, 44.0, 9.0, true], [-44.0, 0.0, 9.0, false], [44.0, 0.0, 9.0, false],
		[0.0, -20.0, 6.0, true], [0.0, 20.0, 6.0, true], [20.0, 0.0, 6.0, false], [-20.0, 0.0, 6.0, false]]   # (across the ways between the corners, off the roads)
	for q: Array in walls:
		var x: float = q[0]; var z: float = q[1]; var half: float = float(q[2]) * 0.5; var along_x: bool = q[3]
		if along_x: block(kit, x - half, 0.0, z - 0.4, x + half, 1.2, z + 0.4, C_STONE2)
		else: block(kit, x - 0.4, 0.0, z - half, x + 0.4, 1.2, z + half, C_STONE2)
		for i in int(q[2]):   # (its stones, lighter and darker)
			var o := -half + 0.5 + i
			if along_x: kit.slab(x + o - 0.45, 1.2, z - 0.42, x + o + 0.45, 1.32, z + 0.42, C_STONE if i % 2 == 0 else C_PAVE)
			else: kit.slab(x - 0.42, 1.2, z + o - 0.45, x + 0.42, 1.32, z + o + 0.45, C_STONE if i % 2 == 0 else C_PAVE)

# ---------------- the landmarks ----------------
## a banner on a pole: its cloth in the people's colour, its sign on it shining
func banner(k: MeshKit, gl: MeshKit, cl: MeshKit, p: Vector3, face: Vector3, col: Color, sign_col: Color, h := 9.0) -> void:
	k.cyl(p.x, 0, p.z, 0.12, 0.09, h, C_IRON, 6, false); k.ball(p.x, h + 0.15, p.z, 0.22, C_BRASS, 6, 4)
	var s := Vector3(-face.z, 0, face.x); var top := p + Vector3(0, h - 0.4, 0)
	var a := top + s * 0.1; var b := top + s * 2.6; var c := b + Vector3(0, -3.6, 0) + s * 0.2; var d := a + Vector3(0, -3.9, 0)
	cl.quad(a, b, c, d, Color(col, 0.92), face); cl.quad(b, a, d, c, Color(col.darkened(0.2), 0.92), -face)
	var m := (a + b + c + d) * 0.25 + face * 0.04
	gl.quad(m + Vector3(0, 0.7, 0), m + s * 0.55, m + Vector3(0, -0.7, 0), m - s * 0.55, sign_col, face)   # (its sign: a diamond)
	gl.quad(m - s * 0.55, m + Vector3(0, -0.7, 0), m + s * 0.55, m + Vector3(0, 0.7, 0), sign_col, -face)

func _hall(race: String) -> void:
	var lit := MeshKit.new(); var gl := MeshKit.new(); var cl := MeshKit.new(); var sp := MeshKit.new()
	_hk = {"lit": lit, "glow": gl, "clear": cl, "spin": sp}
	var H := {"race": race, "at": at(race), "front": front(race), "side": side(race), "boxes": [], "fallen": false, "fall_t": 0.0, "hurt": 0.0, "smoke": [], "ruin_spec": []}
	halls[race] = H
	match race:
		"elf": _elf(H)
		"dwarf": _dwarf(H)
		"orc": _orc(H)
		"demon": _demon(H)
	var n := Node3D.new(); n.name = "Hall_" + race; G.add_child(n); H.node = n
	_node(lit, gl, cl, n)
	if not sp.is_empty():   # what turns: the elves' crystal, the demons' rift
		var sn := Node3D.new(); n.add_child(sn); sn.position = H.spin_at; _node(MeshKit.new(), sp, MeshKit.new(), sn); H.spin = sn
	_ruin(H)

## the elves' moon spire: a white tower on a round dais, its balcony, four pillars about it, a crown of leaves and a
## crystal turning over it, a crescent moon shining on its face
func _elf(H: Dictionary) -> void:
	var k: MeshKit = _hk.lit; var gl: MeshKit = _hk.glow; var c: Vector3 = H.at; var f: Vector3 = H.front; var bx: Array = H.boxes
	k.cyl(c.x, 0, c.z, 7.0, 6.7, 0.4, C_MARBLE2, 18, true, false, 0.0, TAU, C_MARBLE)
	wall(c.x - 6.4, 0.0, c.z - 3.0, c.x + 6.4, 0.4, c.z + 3.0, bx); wall(c.x - 3.0, 0.0, c.z - 6.4, c.x + 3.0, 0.4, c.z + 6.4, bx)
	for i in 12: gl.disc(c.x + cos(i * TAU / 12.0) * 6.2, 0.42, c.z + sin(i * TAU / 12.0) * 6.2, 0.18, C_CYAN.darkened(0.15), 6)
	k.cyl(c.x, 0.4, c.z, 2.7, 1.9, 12.6, C_MARBLE, 14, false)
	wall(c.x - 2.2, 0.4, c.z - 2.2, c.x + 2.2, 13.0, c.z + 2.2, bx)
	for y: float in [3.2, 6.4]: k.cyl(c.x, y, c.z, 2.7 - y * 0.065 + 0.12, 2.7 - y * 0.065 + 0.1, 0.3, C_SILVER, 14, false)
	k.disc(c.x, 9.3, c.z, 3.5, C_MARBLE2, 16, 1.95); k.disc(c.x, 9.05, c.z, 3.5, C_MARBLE2.darkened(0.2), 16, 1.95, 0.0, TAU, false)
	k.cyl(c.x, 9.05, c.z, 3.5, 3.5, 0.25, C_SILVER, 16, false)
	for i in 4:   # the pillars about the foot, a ring on their heads
		var a := i * TAU / 4.0 + PI / 4.0; var px := c.x + cos(a) * 4.9; var pz := c.z + sin(a) * 4.9
		k.cyl(px, 0.4, pz, 0.36, 0.3, 4.4, C_MARBLE, 8, true); wall(px - 0.32, 0.4, pz - 0.32, px + 0.32, 4.8, pz + 0.32, bx)
	k.cyl(c.x, 4.8, c.z, 5.2, 5.2, 0.28, C_SILVER, 20, false); k.disc(c.x, 5.08, c.z, 5.2, C_MARBLE2, 20, 4.6)
	for i in 3:   # the crown of leaves
		var a := i * TAU / 3.0 + 0.4
		k.dome(c.x + cos(a) * 1.5, 12.2 + i * 0.4, c.z + sin(a) * 1.5, 2.4, Color("2b6257") if i % 2 == 0 else Color("1d4741"), 10, 3, 0.75, false, C_TEAL.darkened(0.25))
	# the crystal, turning slowly over the crown
	var sp: MeshKit = _hk.spin
	sp.cyl(0, 0.0, 0, 0.95, 0.0, 2.4, C_CYAN, 6, false); sp.cyl(0, -1.0, 0, 0.0, 0.95, 1.0, C_CYAN.darkened(0.2), 6, false)
	H.spin_at = c + Vector3(0, 15.2, 0)
	# the crescent on the tower's face, toward the middle
	var s := Vector3(-f.z, 0, f.x); var o := c + f * 2.42 + Vector3(0, 7.6, 0)
	for i in 8:
		var a0 := 0.7 + i * 0.6; var a1 := a0 + 0.6; var w0 := 0.04 + 0.16 * sin(i / 8.0 * PI); var w1 := 0.04 + 0.16 * sin((i + 1) / 8.0 * PI)
		var d0 := s * cos(a0) + Vector3(0, sin(a0), 0); var d1 := s * cos(a1) + Vector3(0, sin(a1), 0)
		gl.quad(o + d0 * (1.1 - w0), o + d0 * (1.1 + w0), o + d1 * (1.1 + w1), o + d1 * (1.1 - w1), C_CYAN, f)
	banner(k, gl, _hk.clear, c + f * 7.5 + s * 5.0, f, Color(C_TEAL, 1.0).darkened(0.1), Color("eafffb"))
	for i in 7:   # crystals in the moss
		var a := i * 0.9 + 0.3; var p := c + Vector3(cos(a), 0, sin(a)) * (9.5 + (i % 3) * 2.0)
		gl.cyl(p.x, 0.0, p.z, 0.32, 0.0, 1.2 + (i % 3) * 0.4, C_CYAN.darkened(0.1), 5, false)
	H.smoke = [c + Vector3(1.6, 9.4, 0.4), c + Vector3(-1.2, 6.0, 1.4), c + Vector3(0.4, 3.0, -1.9)]
	H.ruin_spec = [[-3.0, 0.0, -2.0, 1.2, 1.4, 1.8], [0.6, 0.0, -0.8, 3.6, 0.9, 2.6], [-2.2, 0.0, 1.0, 0.6, 2.2, 3.4]]

## the dwarves' rune forge: a squat keep of grey stone, its upper storey and roof, battlements, two chimneys glowing at
## their mouths, a great gold door worked with runes, an anvil and a brazier before it
func _dwarf(H: Dictionary) -> void:
	var k: MeshKit = _hk.lit; var gl: MeshKit = _hk.glow; var c: Vector3 = H.at; var bx: Array = H.boxes
	block(k, c.x - 6.0, 0.0, c.z - 5.0, c.x + 6.0, 7.0, c.z + 5.0, C_STONE, bx)
	k.slab(c.x - 6.08, 0.0, c.z - 5.08, c.x + 6.08, 1.0, c.z + 5.08, C_STONE2)
	k.slab(c.x - 6.05, 3.4, c.z - 5.05, c.x + 6.05, 3.6, c.z + 5.05, C_STONE2)
	block(k, c.x - 4.5, 7.0, c.z - 3.8, c.x + 4.5, 9.2, c.z + 3.8, C_STONE2, bx)
	block(k, c.x - 3.0, 9.2, c.z - 2.5, c.x + 3.0, 9.9, c.z + 2.5, C_IRON, bx)
	for i in 8:   # battlements
		var x := c.x - 5.6 + i * 1.6
		k.slab(x, 7.0, c.z - 5.0, x + 0.8, 7.8, c.z - 4.4, C_STONE); k.slab(x, 7.0, c.z + 4.4, x + 0.8, 7.8, c.z + 5.0, C_STONE)
	for i in 6:
		var z := c.z - 4.6 + i * 1.6
		k.slab(c.x - 6.0, 7.0, z, c.x - 5.4, 7.8, z + 0.8, C_STONE); k.slab(c.x + 5.4, 7.0, z, c.x + 6.0, 7.8, z + 0.8, C_STONE)
	for q: Array in [[4.3, -3.6], [1.4, -3.9]]:   # the chimneys, at the back (away from the middle)
		var x: float = c.x + q[0]; var z: float = c.z + q[1]
		block(k, x - 0.8, 7.0, z - 0.8, x + 0.8, 12.6, z + 0.8, C_STONE2, bx)
		k.slab(x - 0.95, 12.2, z - 0.95, x + 0.95, 12.6, z + 0.95, C_IRON)
		gl.slab(x - 0.6, 12.6, z - 0.6, x + 0.6, 12.64, z + 0.6, C_EMBER)
		H.smoke.push_back(Vector3(x, 12.9, z))
	# the great door, on the south face (toward the middle), and runes shining on the west face too
	var dz := c.z + 5.0
	k.slab(c.x - 2.2, 0.0, dz, c.x + 2.2, 4.9, dz + 0.25, C_STONE2)
	k.slab(c.x - 1.7, 0.0, dz + 0.25, c.x + 1.7, 4.3, dz + 0.4, C_BRASS)
	for i in 5: gl.slab(c.x - 1.2 + i * 0.6, 0.8, dz + 0.41, c.x - 1.05 + i * 0.6, 3.6, dz + 0.43, Color("ffd66b"))
	gl.slab(c.x - 1.3, 3.7, dz + 0.41, c.x + 1.3, 3.85, dz + 0.43, Color("ffd66b"))
	var wx := c.x - 6.0
	for i in 3: gl.slab(wx - 0.03, 1.4 + i * 1.6, c.z - 2.4, wx - 0.01, 1.55 + i * 1.6, c.z + 2.4, Color("ffd66b").darkened(0.15))
	for q: Array in [[-3.6, 2.0], [3.6, 2.0]]: gl.slab(c.x + q[0] - 0.5, q[1], dz - 0.02, c.x + q[0] + 0.5, q[1] + 1.2, dz + 0.02, C_EMBER.darkened(0.1))   # (the forge's light at two windows)
	# the anvil and the brazier
	var ax := c.x - 3.2; var az := c.z + 8.0
	block(k, ax - 0.6, 0.0, az - 0.35, ax + 0.6, 0.55, az + 0.35, C_IRON, bx); k.slab(ax - 0.85, 0.55, az - 0.3, ax + 0.8, 0.85, az + 0.3, C_IRON.lightened(0.1))
	var bxx := c.x + 3.4; var bzz := c.z + 8.2
	k.cyl(bxx, 0.0, bzz, 0.5, 0.75, 1.1, C_IRON, 8, false); gl.disc(bxx, 1.12, bzz, 0.6, C_EMBER, 8)
	H.smoke.push_back(Vector3(bxx, 1.4, bzz))
	for i in 4:   # barrels and a cart of ore by the wall
		var p := c + Vector3(-7.2, 0, -3.0 + i * 1.3); k.cyl(p.x, 0, p.z, 0.5, 0.5, 1.1, C_WOOD, 8, true); k.cyl(p.x, 0.5, p.z, 0.52, 0.52, 0.1, C_IRON, 8, false)
	banner(k, gl, _hk.clear, c + Vector3(-7.5, 0, 7.0), H.front, Color(Races.R.dwarf.col), Color("fff2c8"))
	H.smoke.append_array([c + Vector3(-3.0, 9.4, 1.0), c + Vector3(2.5, 7.2, 3.0)])
	H.ruin_spec = [[-5.0, 0.0, -3.5, 1.0, 1.6, 2.0], [0.0, 0.0, -4.0, 5.0, 1.2, 1.0], [-3.0, 0.0, 1.0, 3.5, 0.9, 4.0], [3.0, 0.0, -1.5, 5.5, 2.0, 1.5]]

## the orcs' war totem: a great carved pole rising through the top of a hide tent, a horned skull on it, a palisade of
## stakes about the camp with low log walls, war drums, a fire pit and red banners
func _orc(H: Dictionary) -> void:
	var k: MeshKit = _hk.lit; var gl: MeshKit = _hk.glow; var c: Vector3 = H.at; var f: Vector3 = H.front; var bx: Array = H.boxes
	k.cyl(c.x, 0.0, c.z, 5.4, 0.7, 6.2, C_HIDE, 12, false, false, 0.0, TAU, C_HIDE2)
	for i in 6:   # the tent's seams and poles
		var a := i * TAU / 6.0
		k.beam(c + Vector3(cos(a) * 5.35, 0.05, sin(a) * 5.35), c + Vector3(cos(a) * 0.45, 7.2, sin(a) * 0.45), 0.12, C_WOOD)
	k.cyl(c.x, 0.0, c.z, 5.5, 5.4, 0.5, C_HIDE2, 12, false)
	wall(c.x - 3.9, 0.0, c.z - 3.9, c.x + 3.9, 2.4, c.z + 3.9, bx); wall(c.x - 2.4, 2.4, c.z - 2.4, c.x + 2.4, 4.4, c.z + 2.4, bx)
	var s := Vector3(-f.z, 0, f.x); var door := c + f * 5.0
	k.quad(door - s * 1.1 + Vector3(0, 0.02, 0), door + s * 1.1 + Vector3(0, 0.02, 0), door + s * 0.4 + Vector3(0, 2.6, 0), door - s * 0.4 + Vector3(0, 2.6, 0), C_OBS, f)   # (its dark way in)
	# the totem, out of the tent's top
	k.cyl(c.x, 4.0, c.z, 0.95, 0.85, 8.4, C_WOOD, 10, false)
	wall(c.x - 0.9, 4.4, c.z - 0.9, c.x + 0.9, 12.4, c.z + 0.9, bx)
	for i in 4: k.cyl(c.x, 5.6 + i * 1.6, c.z, 1.0, 1.0, 0.35, [C_RED, C_OBS, C_BONE, C_ORCG][i], 10, false)
	for i in 3:   # carved faces, eyes shining red
		var y := 6.4 + i * 1.7; var o := c + f * 0.95 + Vector3(0, y, 0)
		k.box(0.9, 0.7, 0.3, o.x, o.y, o.z, C_WOOD.darkened(0.25), atan2(f.x, f.z))
		for e: float in [-0.22, 0.22]: gl.box(0.14, 0.1, 0.06, o.x + s.x * e + f.x * 0.16, o.y + 0.12, o.z + s.z * e + f.z * 0.16, Color("ff3a2a"))
	var top := c + Vector3(0, 12.4, 0)   # the skull and its horns
	k.box(1.7, 1.5, 1.9, top.x, top.y + 0.75, top.z, C_BONE, atan2(f.x, f.z))
	for e: float in [-0.35, 0.35]: gl.box(0.3, 0.26, 0.1, top.x + s.x * e + f.x * 0.96, top.y + 0.95, top.z + s.z * e + f.z * 0.96, Color("ff2a1a"))
	for sg: float in [-1.0, 1.0]:
		var h0 := top + s * sg * 0.85 + Vector3(0, 1.1, 0); var h1 := h0 + s * sg * 1.3 + Vector3(0, 0.6, 0); var h2 := h1 + s * sg * 0.3 + Vector3(0, 1.4, 0)
		k.beam(h0, h1, 0.32, C_BONE.darkened(0.1)); k.beam(h1, h2, 0.22, C_BONE)
	H.spin_at = Vector3.ZERO
	# the palisade: stakes leaning out, open toward the middle; low log walls between some of them
	for i in 26:
		var a := i * TAU / 26.0; var d := Vector3(cos(a), 0, sin(a))
		if d.dot(f) > 0.6: continue
		var p := c + d * 8.6
		k.beam(p, p + d * 0.9 + Vector3(0, 2.5, 0), 0.2, C_WOOD.lightened(0.05))
		k.cyl(p.x + d.x * 0.9, 2.5, p.z + d.z * 0.9, 0.1, 0.0, 0.5, C_BONE, 5, false)
	for q: Array in [[0.0, 3.0], [1.6, 3.0], [3.3, 3.0], [-1.6, 3.0], [-3.3, 3.0]]:
		var a: float = atan2(-f.z, -f.x) + float(q[0]) * 0.55; var p := c + Vector3(cos(a), 0, sin(a)) * 8.0
		block(k, p.x - 1.2, 0.0, p.z - 1.2, p.x + 1.2, 1.15, p.z + 1.2, C_WOOD.darkened(0.1), bx)
	# drums, the fire pit, bones
	for e: float in [-3.0, 3.0]:
		var p := c + f * 7.4 + s * e
		k.cyl(p.x, 0.0, p.z, 0.7, 0.7, 1.0, C_RED.darkened(0.2), 10, true, false, 0.0, TAU, C_HIDE)
	var pit := c + f * 11.0
	for i in 9: k.box(0.5, 0.35, 0.4, pit.x + cos(i * TAU / 9.0) * 1.2, 0.17, pit.z + sin(i * TAU / 9.0) * 1.2, C_ROCK2, i * 0.7)
	gl.disc(pit.x, 0.2, pit.z, 0.9, C_EMBER, 10); gl.cyl(pit.x, 0.2, pit.z, 0.55, 0.0, 1.1, Color("ffb040"), 6, false)
	H.smoke.push_back(pit + Vector3(0, 1.0, 0))
	for i in 6: k.ball(c.x + cos(i * 1.3) * 10.5, 0.15, c.z + sin(i * 1.3) * 10.5, 0.28, C_BONE, 6, 4)
	banner(k, gl, _hk.clear, c + f * 8.5 + s * 4.5, f, Color(Races.R.orc.col).darkened(0.1), Color("ffe8d0"))
	banner(k, gl, _hk.clear, c + f * 8.5 - s * 4.5, f, C_RED, Color("ffe8d0"), 7.0)
	H.smoke.append_array([c + Vector3(0.0, 6.4, 0.0), c + s * 2.0 + Vector3(0, 3.6, 0)])
	H.ruin_spec = [[-3.0, 0.0, -3.0, 0.5, 0.8, 1.0], [-0.6, 0.0, -1.0, 3.2, 1.3, 2.4], [-2.6, 0.0, 1.2, 0.8, 0.7, 3.6]]

## the demons' rift gate: an obsidian floor, two spiked pillars and a horned lintel, the rift turning between them, lava
## cracks about it and spikes of black glass
func _demon(H: Dictionary) -> void:
	var k: MeshKit = _hk.lit; var gl: MeshKit = _hk.glow; var c: Vector3 = H.at; var f: Vector3 = H.front; var s: Vector3 = H.side; var bx: Array = H.boxes
	block(k, c.x - 5.5, 0.0, c.z - 5.5, c.x + 5.5, 0.42, c.z + 5.5, C_OBS2, bx)
	for i in 4: gl.strip(Vector3(c.x - 5.5 + i * 3.6, 0.44, c.z - 5.4), Vector3(c.x - 4.6 + i * 3.0, 0.44, c.z + 5.4), 0.12, C_LAVA)
	var tops: Array = []
	for e: float in [-3.3, 3.3]:
		var p := c + s * e
		k.cyl(p.x, 0.42, p.z, 1.25, 0.85, 10.6, C_OBS, 4, false, false, PI / 4.0, PI / 4.0 + TAU)
		wall(p.x - 0.95, 0.42, p.z - 0.95, p.x + 0.95, 11.0, p.z + 0.95, bx)
		k.cyl(p.x, 11.0, p.z, 0.85, 0.0, 2.2, C_OBS2, 4, false, false, PI / 4.0, PI / 4.0 + TAU)
		for i in 3: gl.box(0.08, 1.4, 0.08, p.x + f.x * 1.0, 2.5 + i * 2.8, p.z + f.z * 1.0, C_VIOLET)
		tops.push_back(p + Vector3(0, 10.4, 0))
	k.beam(tops[0] - s * 0.8, tops[1] + s * 0.8, 1.3, C_OBS2)
	for sg: float in [-1.0, 1.0]:
		var h0 := c + s * sg * 2.0 + Vector3(0, 11.0, 0); var h1 := h0 + s * sg * 1.0 + Vector3(0, 1.6, 0); var h2 := h1 - s * sg * 0.6 + Vector3(0, 1.2, 0)
		k.beam(h0, h1, 0.42, C_OBS); k.beam(h1, h2, 0.26, C_HELL.darkened(0.3))
	wall(c.x - 1.6, 0.42, c.z - 1.6, c.x + 1.6, 8.6, c.z + 1.6, bx)   # (the rift itself: nobody walks through it)
	# the rift: rings of fire and violet, standing between the pillars, turning
	var sp: MeshKit = _hk.spin
	sp.disc(0, 0, 0, 3.1, C_HELL, 24, 2.6); sp.disc(0, 0, 0, 2.6, C_VIOLET.darkened(0.2), 24, 2.0); sp.disc(0, 0, 0, 2.0, C_LAVA, 20, 1.3); sp.disc(0, 0, 0, 1.3, Color("2a0a18"), 18)
	sp.disc(0, 0, 0, 3.1, C_HELL.darkened(0.2), 24, 2.6, 0.0, TAU, false); sp.disc(0, 0, 0, 2.0, C_LAVA.darkened(0.2), 20, 1.3, 0.0, TAU, false); sp.disc(0, 0, 0, 1.3, Color("2a0a18"), 18, 0.0, 0.0, TAU, false)
	for i in 6: var a := i * TAU / 6.0; sp.box(0.5, 0.06, 0.18, cos(a) * 2.3, 0.0, sin(a) * 2.3, Color("ffd0a0"), -a)
	H.spin_at = c + Vector3(0, 5.6, 0)
	for i in 14:   # spikes of black glass about the gate
		var a := i * TAU / 14.0 + 0.2; var d := 7.5 + (i % 3) * 2.2; var p := c + Vector3(cos(a), 0, sin(a)) * d
		if Vector3(cos(a), 0, sin(a)).dot(f) > 0.75: continue
		var hh := 1.4 + (i % 4) * 0.7
		k.cyl(p.x, 0.0, p.z, 0.45, 0.0, hh, C_OBS, 5, false); gl.cyl(p.x, hh * 0.75, p.z, 0.12, 0.0, hh * 0.25, C_VIOLET, 4, false)
	banner(k, gl, _hk.clear, c + f * 7.5 + s * 5.0, f, Color(Races.R.demon.col), Color("ffd0b0"))
	H.smoke = [c + s * 3.3 + Vector3(0, 11.5, 0), c - s * 3.3 + Vector3(0, 11.5, 0), c + Vector3(0, 0.6, 0) + f * 2.5]
	H.ruin_spec = [[-4.0, 0.0, -1.5, -1.0, 1.4, 1.5], [1.0, 0.0, -2.0, 4.0, 1.0, 1.0], [-1.0, 0.0, 1.5, 2.5, 0.8, 4.0]]

## what is left of a landmark: its stones (or its timber, its black glass) in heaps, the ground scorched. Built now, shown
## when it falls
func _ruin(H: Dictionary) -> void:
	var k := MeshKit.new(); var c: Vector3 = H.at; var race: String = H.race
	var pal: Array = {"elf": [C_MARBLE, C_MARBLE2, C_SILVER], "dwarf": [C_STONE, C_STONE2, C_IRON], "orc": [C_HIDE, C_WOOD, C_BONE], "demon": [C_OBS, C_OBS2, C_ASH]}[race]
	k.disc(c.x, 0.02, c.z, float(BODY[race][0]) + 3.5, Color("2e2a26"), 18)
	var R := World.Rng.new(6300 + race.length() * 7)
	for q: Array in H.ruin_spec:
		k.slab(c.x + float(q[0]), float(q[1]), c.z + float(q[2]), c.x + float(q[3]), float(q[4]), c.z + float(q[5]), pal[0])
	for i in 26:
		var a: float = R.rng(0.0, TAU); var d: float = R.rng(0.5, float(BODY[race][0]) + 2.5); var sz: float = R.rng(0.35, 1.1)
		k.box(sz * 1.4, sz * 0.7, sz, c.x + cos(a) * d, sz * 0.35, c.z + sin(a) * d, pal[i % 3], R.rng(0.0, TAU))
	if race == "orc": k.beam(c + Vector3(-1.0, 0.3, -2.0), c + Vector3(3.5, 0.9, 2.5), 0.8, C_WOOD)   # (the totem, fallen)
	if race == "elf": k.beam(c + Vector3(2.0, 0.6, -1.0), c + Vector3(-5.5, 0.9, 4.0), 1.6, C_MARBLE)   # (the spire, fallen)
	var rn := Node3D.new(); rn.name = "Ruin_" + race; rn.visible = false; G.add_child(rn); k.node(_lit, rn); H.ruin = rn

# ---------------- what happens to them ----------------
## how hurt a landmark is (0 whole .. 1 fallen): smoke from it past a third, fire past two thirds
func set_hurt(race: String, q: float) -> void:
	if halls.has(race): (halls[race] as Dictionary).hurt = clampf(q, 0.0, 1.0)

## a landmark falls: its boxes go, its ruin's come, and it sinks into its dust (update)
func fall(race: String) -> void:
	var H: Dictionary = halls[race]
	if H.fallen: return
	H.fallen = true; H.fall_t = 0.0; H.dust_t = 0.0; H.hurt = 1.0
	for b: Phys.Box in H.boxes: Phys.remove_collider(b)
	H.boxes = []
	var c: Vector3 = H.at; var keep: Array = []
	for q: Array in H.ruin_spec: wall(c.x + float(q[0]), float(q[1]), c.z + float(q[2]), c.x + float(q[3]), float(q[4]), c.z + float(q[5]), keep)
	H.ruin_boxes = keep
	if fx != null:
		fx.explode(c + Vector3(0, 2.0, 0), true); fx.explode(c + Vector3(0, float(BODY[race][1]) * 0.6, 0), true)
		for i in 3: fx.chunks(c + Vector3(randf_range(-2, 2), 1.5 + i * 2.0, randf_range(-2, 2)), 10, 0.5, "metal" if race != "orc" else "wood")
		for i in 8: var a := i * TAU / 8.0; fx.puff(c + Vector3(cos(a) * 4.0, 0.6, sin(a) * 4.0), 6, 0.55, 2.6)

func update(dt: float) -> void:
	t += dt
	for race: String in halls:
		var H: Dictionary = halls[race]
		if H.has("spin") and is_instance_valid(H.spin):
			var sn: Node3D = H.spin
			if race == "elf": sn.rotation = Vector3(0, t * 0.6, 0); sn.position = (H.spin_at as Vector3) + Vector3(0, sin(t * 1.3) * 0.25, 0)
			elif race == "demon":
				var f: Vector3 = H.front; var s: Vector3 = H.side
				sn.basis = Basis(f, t * 1.4) * Basis(s, PI / 2.0)
		if H.fallen and float(H.fall_t) < 2.6:   # sinking into its dust, shaking as it goes
			H.fall_t = float(H.fall_t) + dt; var q := clampf(float(H.fall_t) / 2.4, 0.0, 1.0)
			var n: Node3D = H.node
			n.position = Vector3(sin(t * 47.0) * 0.12 * (1.0 - q), -q * q * float(BODY[race][1]) * 0.85, cos(t * 39.0) * 0.12 * (1.0 - q))
			if fx != null and randf() < dt * 14.0: var a := randf() * TAU; fx.puff((H.at as Vector3) + Vector3(cos(a) * 5.0, 0.5, sin(a) * 5.0), 3, 0.6, 2.2)
			if q >= 1.0: n.visible = false; (H.ruin as Node3D).visible = true
	_smoke_t -= dt
	if _smoke_t > 0.0 or fx == null: return
	_smoke_t = 0.35
	for race: String in halls:   # the chimneys' smoke and the fires; a hurt landmark's smoke and flames
		var H: Dictionary = halls[race]; var pts: Array = H.smoke; var hurt: float = H.hurt
		if H.fallen:
			if float(H.dust_t) < 30.0: H.dust_t = float(H.dust_t) + 0.35; fx.puff((H.at as Vector3) + Vector3(randf_range(-2, 2), 0.8, randf_range(-2, 2)), 2, 0.35, 1.8)   # (it smoulders half a minute)
			continue
		if race == "dwarf" and pts.size() >= 2:
			for i in 2: fx.puff(pts[i], 1, 0.62, 1.1); fx.glow(pts[i], Vector3(randf_range(-0.3, 0.3), 1.8, randf_range(-0.3, 0.3)), 0.8, 0.08, 0.02, Color(1.0, 0.6, 0.2, 1.0))
		if race == "orc" and pts.size() >= 1: fx.glow(pts[0], Vector3(randf_range(-0.4, 0.4), 2.2, randf_range(-0.4, 0.4)), 0.7, 0.09, 0.02, Color(1.0, 0.55, 0.15, 1.0))
		if hurt > 0.33:
			for p: Vector3 in pts.slice(maxi(0, pts.size() - 3)): fx.puff(p, 1 if hurt < 0.66 else 2, 0.28, 1.4)
		if hurt > 0.66:
			for p: Vector3 in pts.slice(maxi(0, pts.size() - 3)): fx.glow(p, Vector3(randf_range(-0.5, 0.5), 2.6, randf_range(-0.5, 0.5)), 0.6, 0.35, 0.05, Color(1.0, 0.45, 0.12, 1.0))

# ---------------- the others' ways ----------------
## waypoints over the open ground, one every GRID metres where there is room to stand: {name: [x, y, z]}
func graph_nodes() -> Dictionary:
	var out := {}; var n := int((IN - 5.0) * 2.0 / GRID) + 1; var x0 := -(n - 1) * GRID * 0.5
	for i in n:
		for j in n:
			var x := x0 + i * GRID; var z := x0 + j * GRID
			if Phys.collide_at(x, 0.05, z, 0.9, 1.8) != null: continue
			var inside := false
			for r: String in SPOT:
				if Vector2(x, z).distance_to(Vector2(at(r).x, at(r).z)) < float(BODY[r][0]) + 1.2: inside = true
			if inside: continue
			out["g%d_%d" % [i, j]] = [x, 0.0, z]
	return out
