class_name ElfWood
extends RefCounted
## Stage 6-1, the elves' place: the Silverwood border and the Archmage's spiral tower. Seven times as long as it is wide,
## walked from its west end (the wood's edge) to its east end (the tower), with three ways up and down along it: the silver
## stream under the ground, the root paths on it, the bridges between the boughs above.
##   0-2  the Silverwood border   where you start; great roots as trenches; the wind path's circles (faster on your feet)
##   2-4  the Moonwell glade      open ground, a white marble pavilion over a pond that mends you (and hides you in mist)
##   4-6  the Resonance ravine    the crystal bridge between two gatehouses, the stream below, the tree bridges above
##   6-7  the spiral tower        its court, the stair round its outside, the library, the observatory under the dome
## Godot has no slopes or round walls here: all of it is boxes to walk on (the round things are drawn round over them).

const HALF := 158.0
const X0 := -154.0; const X1 := 154.0; const WZ := 22.0
const START_Y := 3.0                                             # the terrace you start on
const WIND := [-131.0, -96.0, 10.0]                              # the wind path: from x, to x, half its width
const WELL := Vector3(-22.0, 0.5, 0.0); const WELL_R := 3.0      # the moonwell's pond (its water's height)
const PIT_X0 := 52.0; const PIT_X1 := 82.0; const PIT_Y := -6.0  # the ravine
const TOP := 8.0                                                 # the decks up in the boughs
const DK := 3.2                                                  # half a deck's width
const TC := Vector2(134.0, 0.0)                                  # the tower's middle
const T_CORE := 8.0; const T_STAIR := 12.0; const T_DECK := 14.0; const T_F2 := 10.0; const T_F3 := 20.0
const STEPS := 60                                                # a flight's steps, once round
const AMP := Vector3(119.0, 0.0, 0.0); const AMP_R := 3.0        # the amplifying circle at the stair's foot

const C_BARK := Color("b4bfbc"); const C_BARK2 := Color("939f9c"); const C_ROOT := Color("a3aeaa")
const C_MOSS := Color("3a5f43"); const C_MOSS2 := Color("46704f"); const C_PATH := Color("8e968b"); const C_LEAF := Color("1d4741"); const C_LEAF2 := Color("2b6257")
const C_MARBLE := Color("c9d0cd"); const C_MARBLE2 := Color("aeb7b4"); const C_ROCK := Color("6b736e"); const C_ROCK2 := Color("535b57")
const C_WOOD := Color("8a5a34"); const C_WOOD2 := Color("6c4426"); const C_ROOF := Color("54361f")
const C_STONE := Color("9a9ea8"); const C_STONE2 := Color("7e828c"); const C_BRASS := Color("d6a43a")
const C_CYAN := Color("8ff7ea"); const C_RUNE := Color("dcfff9"); const C_VIOLET := Color("b892ff"); const C_GOLD := Color("ffd66b"); const C_WATER := Color("9fd6e0"); const C_LAPIS := Color("36476f")

var world: World; var G: Node3D
var kits: Array = []          # what is lit: a mesh for each stretch of the map (so the far end is not drawn from the near one)
var glow := MeshKit.new()     # what shines by itself: runes, crystals, windows
var clear := MeshKit.new()    # what is seen through: water, glass
var mirrors := {}             # the silverwoods' trunks (their boxes): an elf's bolt glances off them
var posts: Array = []         # where the elves stand: {type, x, y, z, yaw, perch}
var trees: Array = []         # [x, z, r] (the map draws them)
var decks: Array = []         # the tree decks: [x, z]
var lanterns: Array = []      # {n, at, sway, v}
var _mat_lit: StandardMaterial3D; var _mat_glow: StandardMaterial3D; var _mat_clear: StandardMaterial3D
var player: Player; var game; var enemies: Enemies; var fx: Fx; var proj: Proj
var t := 0.0
var obelisks: Array = []      # {x, y, z, n, mat, hot, rang}
var ferns: Array = []         # the veil-fern beds: {x, z, r, mat, a}
var puffs: Array = []         # the gravity-spore puffballs: {x, y, z, c, n, lift, grow}
var portals: Array = []       # {a, b, r}: step on a, you are at b
var racks: Array = []         # {x, y, z, t}
var spinners: Array = []      # the astrolabes' rings and the great sphere's: {n, axis, speed}
var perches: Array = []       # where the Archmage steps to, round the sphere
var books: Node3D = null
var well_t := 0.0; var mist := 0.0; var mist_n: MeshInstance3D = null; var wind_t := 0.0; var port_cd := 0.0; var spin := 1.0
var _told := {}; var _shots := 0; var _fired := 9.0; var _ob_t := 0.0

# ---------------- building helpers ----------------
func _k(x: float) -> MeshKit: return kits[clampi(int((x - X0) / 77.0), 0, 3)]

## a box to see and to stand on or against (given by its corners)
func block(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color, kind := "concrete") -> Phys.Box:
	_k((x0 + x1) * 0.5).slab(x0, y0, z0, x1, y1, z1, col)
	return Phys.add_collider(x0, y0, z0, x1, y1, z1, kind)
## ...only to see
func slab(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color) -> void: _k((x0 + x1) * 0.5).slab(x0, y0, z0, x1, y1, z1, col)
## ...only to stand on or against
func wall(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, kind := "concrete") -> Phys.Box: return Phys.add_collider(x0, y0, z0, x1, y1, z1, kind)

## steps along x: from (xa, ya) to (xb, yb), between z0 and z1, each no higher than 0.3; solid down to `foot`, or planks
func stairs_x(xa: float, ya: float, xb: float, yb: float, z0: float, z1: float, col: Color, foot = null, kind := "concrete") -> void:
	var n := maxi(1, ceili(absf(yb - ya) / 0.3)); var dx := (xb - xa) / n; var dy := (yb - ya) / n
	for i in n:
		var top := ya + dy * (i + 1) if dy > 0.0 else ya + dy * i   # (going down, a step is as high as where it starts)
		var xs := xa + dx * i; var xe := xa + dx * (i + 1)
		var lo: float = foot if foot != null else top - 0.3
		block(minf(xs, xe), lo, z0, maxf(xs, xe), top, z1, col, kind)

## a silverwood: its trunk (a bolt glances off it), the swell of its foot, its crown high up
func tree(x: float, z: float, r: float, h := 36.0, y0 := 0.0, crown := true) -> void:
	var k := _k(x)
	k.cyl(x, y0, z, r * 1.7, r, 2.6, C_BARK2.lerp(C_MOSS, 0.5), 10, false, false, 0.0, TAU, C_BARK)   # (moss at its foot)
	k.cyl(x, y0 + 2.6, z, r, r * 0.78, h - 2.6, C_BARK, 10, false, false, 0.0, TAU, C_BARK2)
	var b := Phys.add_collider(x - r * 0.82, y0, z - r * 0.82, x + r * 0.82, y0 + h, z + r * 0.82, "wood"); mirrors[b] = true
	trees.push_back([x, z, r]); _bark(k, x, z, r, y0, h)
	if crown:
		for i in 3:
			var a := i * TAU / 3.0 + x * 0.37; var rr := r * (3.2 + (i % 2) * 0.9)
			k.dome(x + cos(a) * r * 2.2, y0 + h - 9.0 + i * 2.2, z + sin(a) * r * 2.2, rr, C_LEAF if i % 2 == 0 else C_LEAF2, 8, 3, 0.55, false, C_LEAF2)
			k.disc(x + cos(a) * r * 2.2, y0 + h - 9.0 + i * 2.2, z + sin(a) * r * 2.2, rr, C_LEAF.darkened(0.25), 8, 0.0, 0.0, TAU, false)

## what is on a silverwood's bark: the dark eyes a white poplar has, crystals of magic set in it, shelves of fungus
func _bark(k: MeshKit, x: float, z: float, r: float, y0: float, h: float, marks := 9) -> void:
	for i in marks:
		var a := i * 2.399963 + x * 0.61 + z * 0.37; var y := y0 + 2.9 + fposmod(i * 1.37 + x * 0.3, 1.0) * 10.5 + (i % 3) * 0.8
		var rr := r * (1.0 - 0.22 * (y - y0 - 2.6) / maxf(h - 2.6, 1.0)) * 0.992 + 0.012   # (the trunk draws in a little as it rises; ten flat sides)
		var n := Vector3(cos(a), 0, sin(a)); var t := Vector3(-n.z, 0, n.x); var c := Vector3(x, y, z) + n * rr; var w := 0.2 + (i % 3) * 0.07
		if i % 4 == 3: glow.quad(c - t * 0.09, c - Vector3(0, 0.2, 0), c + t * 0.09, c + Vector3(0, 0.2, 0), C_CYAN.darkened(0.1), n)   # a crystal in the bark
		else: k.quad(c - t * w, c - Vector3(0, 0.07, 0), c + t * w, c + Vector3(0, 0.07, 0), C_BARK2.darkened(0.5), n)
	for i in 3:
		var a := i * 2.1 + x * 0.83 + z; var y := y0 + 1.5 + i * 1.15 + fposmod(x * 0.7 + i, 1.0) * 0.5; var rr := r * 0.96; var fr := 0.42 + (i % 2) * 0.22
		var fc: Color = [Color("e2c79a"), Color("d39a5c"), Color("ecdcb6")][i]
		k.disc(x + cos(a) * rr, y, z + sin(a) * rr, fr, fc, 8, 0.0, a - PI * 0.5, a + PI * 0.5); k.disc(x + cos(a) * rr, y - 0.05, z + sin(a) * rr, fr, fc.darkened(0.35), 8, 0.0, a - PI * 0.5, a + PI * 0.5, false)

## a root lying along the ground: something to shelter behind (1.5 high) or to vault (1.0)
func root(x0: float, z0: float, x1: float, z1: float, h: float) -> void:
	block(x0, 0.0, z0, x1, h, z1, C_ROOT, "wood")
	slab(x0 + 0.12, h, z0 + 0.12, x1 - 0.12, h + 0.14, z1 - 0.12, C_BARK)

## a leyline conduit: a crystal on a stone foot, waist high, solid
func conduit(x: float, z: float, y := 0.0) -> void:
	block(x - 0.5, y, z - 0.5, x + 0.5, y + 0.75, z + 0.5, C_STONE2)
	glow.cyl(x, y + 0.75, z, 0.32, 0.0, 0.55, C_CYAN, 6, false)
	Phys.add_collider(x - 0.3, y + 0.75, z - 0.3, x + 0.3, y + 1.15, z + 0.3, "concrete")
	world.lamps.push_back({"x": x, "y": y + 2.6, "z": z})

## a ring of the tower: one step (or one piece of a floor) between two angles and two radii, its top at y1
func ring_piece(kit: MeshKit, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, col: Color, col_side: Color) -> void:
	var c := Vector3(TC.x, 0.0, TC.y); var d0 := Vector3(cos(a0), 0.0, sin(a0)); var d1 := Vector3(cos(a1), 0.0, sin(a1))
	var up0 := Vector3(0, y0, 0); var up1 := Vector3(0, y1, 0)
	kit.quad(c + d0 * r0 + up1, c + d0 * r1 + up1, c + d1 * r1 + up1, c + d1 * r0 + up1, col, Vector3.UP)
	kit.quad(c + d0 * r0 + up0, c + d0 * r1 + up0, c + d1 * r1 + up0, c + d1 * r0 + up0, col_side.darkened(0.3), Vector3.DOWN)
	kit.quad(c + d0 * r1 + up0, c + d1 * r1 + up0, c + d1 * r1 + up1, c + d0 * r1 + up1, col_side, (d0 + d1).normalized())
	kit.quad(c + d0 * r0 + up0, c + d1 * r0 + up0, c + d1 * r0 + up1, c + d0 * r0 + up1, col_side, -(d0 + d1).normalized())
	var t0 := Vector3(-d0.z, 0.0, d0.x); var t1 := Vector3(-d1.z, 0.0, d1.x)
	kit.quad(c + d0 * r0 + up0, c + d0 * r1 + up0, c + d0 * r1 + up1, c + d0 * r0 + up1, col_side, -t0)
	kit.quad(c + d1 * r0 + up0, c + d1 * r1 + up0, c + d1 * r1 + up1, c + d1 * r0 + up1, col_side, t1)

## ...and what is stood on there: small boxes laid across the ring from r0 to r1 at angle a
func ring_solid(r0: float, r1: float, a: float, y0: float, y1: float, cell := 1.6) -> void:
	var n := maxi(1, ceili((r1 - r0) / (cell * 0.84)))
	for i in n:
		var r := lerpf(r0 + cell * 0.42, r1 - cell * 0.42, float(i) / maxf(1.0, n - 1.0)) if n > 1 else (r0 + r1) * 0.5
		var x := TC.x + cos(a) * r; var z := TC.y + sin(a) * r
		Phys.add_collider(x - cell * 0.5, y0, z - cell * 0.5, x + cell * 0.5, y1, z + cell * 0.5, "concrete")

func post(type: String, x: float, y: float, z: float, yaw := PI / 2.0, more := {}) -> void:
	var p := {"type": type, "x": x, "y": y, "z": z, "yaw": yaw}; p.merge(more); posts.push_back(p)

# ---------------- the map ----------------
func build(w: World, group: Node3D) -> void:
	world = w; G = group
	Phys.set_world_size(HALF); Phys.set_nav(int(HALF * 2.0) + 4, 1.0)
	Phys.PIT = {"x0": PIT_X0, "x1": PIT_X1, "z0": -WZ - 6.0, "z1": WZ + 6.0, "y": PIT_Y}
	for i in 4: kits.push_back(MeshKit.new())
	_mat_lit = StandardMaterial3D.new(); _mat_lit.vertex_color_use_as_albedo = true; _mat_lit.roughness = 0.9
	_ground(); _meadow(); _edges(); _border(); _glade(); _ravine(); _crag(); _tower()
	_dress(); _posts()
	_meshes()
	world.start = {"x": X0 + 8.0, "z": 0.0, "yaw": -PI / 2.0, "y": START_Y}; world.spawns.clear()
	Phys.index_colliders(); Phys.build_nav()

func _meshes() -> void:
	for k: MeshKit in kits:
		if not k.is_empty(): k.node(_mat_lit, G)
	_mat_glow = Gfx.unlit(Color.WHITE, false); _mat_glow.vertex_color_use_as_albedo = true
	if not glow.is_empty(): var gn := glow.node(_mat_glow, G); gn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat_clear = Gfx.unlit(Color.WHITE, false); _mat_clear.vertex_color_use_as_albedo = true; _mat_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _mat_clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not clear.is_empty(): var cn := clear.node(Gfx.see_through(_mat_clear), G); cn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## the ground: moss either side of the ravine, the ravine's own floor, a pale path down the middle
func _ground() -> void:
	for seg: Array in [[X0, -66.0, C_MOSS], [-66.0, 22.0, C_MOSS2], [22.0, PIT_X0, C_MOSS], [PIT_X1, 112.0, C_ROCK2.lerp(C_MOSS, 0.5)], [112.0, X1, C_STONE2]]:
		slab(seg[0], -0.6, -WZ - 6.0, seg[1], 0.0, WZ + 6.0, seg[2])
	slab(PIT_X0, PIT_Y - 0.6, -WZ - 6.0, PIT_X1, PIT_Y, WZ + 6.0, C_ROCK2.darkened(0.15))
	# the ravine's two faces (you cannot walk through them from below)
	block(PIT_X0 - 0.8, PIT_Y, -WZ - 6.0, PIT_X0, 0.0, WZ + 6.0, C_ROCK)
	block(PIT_X1, PIT_Y, -WZ - 6.0, PIT_X1 + 0.8, 0.0, WZ + 6.0, C_ROCK)
	# the path, from the foot of the start's steps to the tower's gate
	var pts := [[-128.0, 0.0], [-108.0, -2.0], [-90.0, 2.5], [-70.0, -1.0], [-44.0, 0.0], [-6.0, 0.0], [20.0, 1.0], [46.0, 0.0], [PIT_X0, 0.0]]
	for i in pts.size() - 1:
		var a := Vector3(pts[i][0], 0.03, pts[i][1]); var b := Vector3(pts[i + 1][0], 0.03, pts[i + 1][1])
		_k((a.x + b.x) * 0.5).strip(a, b, 3.2, C_PATH)
	_k(96.0).strip(Vector3(PIT_X1, 0.03, 0), Vector3(113.0, 0.03, 0), 3.6, C_PATH)

## what grows on the ground west of the ravine: moss in lighter and darker patches (off the path and the pavilion's floor),
## and star flowers, small lights low in the grass, in drifts
func _meadow() -> void:
	var R := World.Rng.new(611)
	for i in 150:
		var x: float = R.rng(X0 + 20.0, PIT_X0 - 3.0); var z: float = R.rng(-WZ + 1.0, WZ - 1.0); var r: float = R.rng(1.2, 3.4)
		if absf(z) < r + 3.0 or Vector2(x - WELL.x, z - WELL.z).length() < 15.5 + r: continue
		_k(x).disc(x, 0.01 + (i % 4) * 0.005, z, r, [C_MOSS.darkened(0.2), C_MOSS2.lightened(0.08), C_MOSS.lerp(C_LEAF2, 0.4)][i % 3], 9)
	for i in 60:
		var x: float = R.rng(X0 + 22.0, PIT_X0 - 3.0); var z: float = R.rng(-WZ + 1.5, WZ - 1.5); var col: Color = [C_CYAN, C_RUNE, C_VIOLET, Color("ffe9a8")][i % 4]
		if Vector2(x - WELL.x, z - WELL.z).length() < 9.0: continue
		for j in 5: glow.disc(x + R.rng(-1.2, 1.2), 0.14, z + R.rng(-1.2, 1.2), 0.065, col, 5)

## the edges: the wood standing close along both sides, a cliff at each end
func _edges() -> void:
	wall(X0 - 4.0, PIT_Y - 2.0, -WZ - 4.0, X1 + 4.0, 60.0, -WZ); wall(X0 - 4.0, PIT_Y - 2.0, WZ, X1 + 4.0, 60.0, WZ + 4.0)
	wall(X0 - 4.0, PIT_Y - 2.0, -WZ - 4.0, X0, 60.0, WZ + 4.0); wall(X1, PIT_Y - 2.0, -WZ - 4.0, X1 + 4.0, 60.0, WZ + 4.0)
	for side: float in [-1.0, 1.0]:
		var x := X0 + 6.0; var i := 0
		while x < 112.0:
			var pit := x > PIT_X0 - 2.0 and x < PIT_X1 + 2.0
			var z := side * (WZ + 2.6 + (i % 3) * 1.3); var r := 1.7 + (i % 4) * 0.35
			_k(x).cyl(x, PIT_Y if pit else 0.0, z, r * 1.5, r * 0.8, 40.0 + (6.0 if pit else 0.0), C_BARK2 if i % 2 == 0 else C_BARK, 8, false)
			x += 8.5 + (i % 3) * 1.7; i += 1
		# the dark of the wood behind them, and its roof of leaves
		slab(X0 - 4.0, PIT_Y, side * (WZ + 5.5) - 0.5, 112.0, 26.0, side * (WZ + 5.5) + 0.5, C_LEAF.darkened(0.45))
		var tx := X0 - 2.0; var ti := 0   # (trunks farther in, seen dimly: the wood goes on)
		while tx < 112.0:
			var tw := 0.5 + (ti % 4) * 0.28; var tz := side * (WZ + 4.95); var tc := C_BARK2.darkened(0.55 + (ti % 3) * 0.09)
			_k(tx).quad(Vector3(tx - tw, PIT_Y, tz), Vector3(tx + tw, PIT_Y, tz), Vector3(tx + tw * 0.8, 26.0, tz), Vector3(tx - tw * 0.8, 26.0, tz), tc, Vector3(0, 0, -side))
			tx += 2.3 + (ti % 5) * 0.9; ti += 1
		var cx := X0 + 10.0; var j := 0
		while cx < 108.0:
			_k(cx).dome(cx, 20.0 + (j % 3) * 2.5, side * (WZ - 1.0 + (j % 2) * 3.0), 9.0 + (j % 3) * 2.0, C_LEAF if j % 2 == 0 else C_LEAF2, 8, 3, 0.5, false, C_LEAF2.darkened(0.1))
			_k(cx).disc(cx, 20.0 + (j % 3) * 2.5, side * (WZ - 1.0 + (j % 2) * 3.0), 9.0 + (j % 3) * 2.0, C_LEAF.darkened(0.4), 8, 0.0, 0.0, TAU, false)
			cx += 13.0; j += 1
		# rock round the tower's court
		slab(112.0, 0.0, side * (WZ + 0.2), X1 + 4.0, 22.0, side * (WZ + 6.0), C_ROCK2)
	slab(X0 - 4.0, 0.0, -WZ - 6.0, X0, 30.0, WZ + 6.0, C_ROCK2); slab(X1, 0.0, -WZ - 6.0, X1 + 4.0, 34.0, WZ + 6.0, C_ROCK2)

## 0-2, the Silverwood border: the terrace you start on, the wind path, the great roots
func _border() -> void:
	# the terrace, its marble hall and its steps
	block(X0, 0.0, -16.0, X0 + 16.0, START_Y, 16.0, C_ROCK)
	slab(X0 + 0.5, START_Y, -15.0, X0 + 15.5, START_Y + 0.06, 15.0, C_MARBLE2)
	for side: float in [-1.0, 1.0]: stairs_x(X0 + 16.0, START_Y, X0 + 25.0, 0.0, side * 10.0 - 3.0, side * 10.0 + 3.0, C_MARBLE2, 0.0)
	var k := _k(X0)
	for cx: float in [X0 + 3.0, X0 + 8.0, X0 + 13.0]:
		for cz: float in [-5.0, 5.0]:
			k.cyl(cx, START_Y, cz, 0.3, 0.26, 5.0, C_MARBLE, 8, false); wall(cx - 0.3, START_Y, cz - 0.3, cx + 0.3, START_Y + 5.0, cz + 0.3)
	k.box(12.0, 0.4, 11.4, X0 + 8.0, START_Y + 5.2, 0.0, C_MARBLE)
	for s: float in [-1.0, 1.0]: k.box(12.0, 0.25, 6.6, X0 + 8.0, START_Y + 6.6, s * 2.6, C_MARBLE2, 0.0)   # (the roof's two slopes, flat here)
	k.box(12.4, 0.3, 1.0, X0 + 8.0, START_Y + 7.4, 0.0, C_MARBLE)
	k.cyl(X0 + 6.0, START_Y, -11.5, 2.4, 2.4, 0.3, C_MARBLE2, 12); k.dome(X0 + 6.0, START_Y + 4.0, -11.5, 2.5, C_MARBLE, 10, 3, 0.8, false, C_MARBLE2)
	for i in 6: k.cyl(X0 + 6.0 + cos(i * TAU / 6.0) * 2.1, START_Y + 0.3, -11.5 + sin(i * TAU / 6.0) * 2.1, 0.14, 0.14, 3.7, C_MARBLE, 6, false)
	# the wind path: three circles of runes drawn on the ground along the way, and marks between them that point east
	for i in 3:
		var x: float = WIND[0] + 6.5 + i * 11.0; var zc := [-1.5, 1.2, -0.4][i] as float
		glow.disc(x, 0.05, zc, 4.3, C_RUNE, 36, 4.05); glow.disc(x, 0.05, zc, 3.1, C_CYAN.darkened(0.1), 36, 2.98)
		for s in 12:
			var a := s * TAU / 12.0; glow.strip(Vector3(x + cos(a) * 3.3, 0.05, zc + sin(a) * 3.3), Vector3(x + cos(a) * 3.85, 0.05, zc + sin(a) * 3.85), 0.16 if s % 3 else 0.34, C_RUNE)
		for s in 3:
			var a0 := s * TAU / 3.0 + i; var a1 := a0 + TAU / 3.0
			glow.strip(Vector3(x + cos(a0) * 2.9, 0.05, zc + sin(a0) * 2.9), Vector3(x + cos(a1) * 2.9, 0.05, zc + sin(a1) * 2.9), 0.1, C_CYAN.darkened(0.15))
		glow.disc(x, 0.05, zc, 0.5, C_RUNE, 6, 0.32)
		if i < 2:
			for s in 3:
				var cx := x + 5.4 + s * 0.9
				glow.strip(Vector3(cx - 0.45, 0.05, zc - 0.7), Vector3(cx, 0.05, zc), 0.14, C_RUNE); glow.strip(Vector3(cx - 0.45, 0.05, zc + 0.7), Vector3(cx, 0.05, zc), 0.14, C_RUNE)
	# the silverwoods and their roots
	for t: Array in [[-101.0, -13.0, 2.6], [-93.0, 12.0, 3.0], [-81.0, -9.0, 2.4], [-73.0, 14.0, 2.8], [-68.5, -15.5, 2.2]]: tree(t[0], t[1], t[2])
	for r: Array in [[-98.0, -13.6, -90.5, -12.6, 1.5], [-101.6, -10.2, -100.6, -3.8, 1.0], [-106.5, -13.6, -103.8, -12.6, 1.0],
			[-89.8, 11.5, -83.0, 12.5, 1.5], [-93.6, 2.6, -92.6, 8.8, 1.0], [-99.4, 11.6, -96.2, 12.6, 1.0],
			[-78.4, -9.5, -72.0, -8.5, 1.5], [-81.5, -7.6, -80.5, -2.2, 1.0], [-86.6, -9.5, -83.6, -8.5, 1.0],
			[-76.0, 13.5, -84.0, 14.5, 1.0], [-73.5, 4.4, -72.5, 11.0, 1.5], [-70.0, 13.6, -66.4, 14.6, 1.0]]:
		root(minf(r[0], r[2]), minf(r[1], r[3]), maxf(r[0], r[2]), maxf(r[1], r[3]), r[4])
	for c: Array in [[-112.0, 6.0], [-104.0, -4.0], [-88.0, -1.5], [-76.0, 2.0]]: conduit(c[0], c[1])

## 2-4, the Moonwell glade: open ground, the pavilion over the pond, low walls, the first decks at its far edge
func _glade() -> void:
	var k := _k(WELL.x); var wx := WELL.x; var wz := WELL.z
	k.disc(wx, 0.04, wz, 15.0, C_MARBLE2.darkened(0.12), 28, 8.2)
	# the pavilion's foot (two steps), its eight columns, its roof (which stops what comes down from above)
	k.cyl(wx, 0.0, wz, 8.0, 8.0, 0.25, C_MARBLE2, 28); k.cyl(wx, 0.25, wz, 7.0, 7.0, 0.25, C_MARBLE, 28)
	for b: Array in [[8.0, 3.3], [5.7, 5.7], [3.3, 8.0]]: wall(wx - b[0], 0.0, wz - b[1], wx + b[0], 0.25, wz + b[1])
	for b: Array in [[7.0, 2.9], [4.95, 4.95], [2.9, 7.0]]: wall(wx - b[0], 0.0, wz - b[1], wx + b[0], 0.5, wz + b[1])
	for i in 8:
		var a := (i + 0.5) * TAU / 8.0; var cx := wx + cos(a) * 6.0; var cz := wz + sin(a) * 6.0
		k.cyl(cx, 0.5, cz, 0.3, 0.24, 5.5, C_MARBLE, 8, false); k.cyl(cx, 0.5, cz, 0.42, 0.42, 0.3, C_MARBLE2, 8)
		wall(cx - 0.26, 0.5, cz - 0.26, cx + 0.26, 6.0, cz + 0.26)
	k.cyl(wx, 6.0, wz, 6.9, 6.9, 0.5, C_MARBLE2, 28, true, true); k.dome(wx, 6.5, wz, 6.6, C_MARBLE, 16, 5, 0.62, false, C_MARBLE2)
	k.dome(wx, 6.0, wz, 6.4, C_MARBLE2.darkened(0.2), 16, 4, 0.6, true)
	k.cyl(wx, 10.6, wz, 0.18, 0.0, 1.6, C_BRASS, 6, false)
	for b: Array in [[6.9, 2.9], [4.9, 4.9], [2.9, 6.9]]: wall(wx - b[0], 6.0, wz - b[1], wx + b[0], 6.5, wz + b[1])
	# the pond: its rim, its water (the water mends you)
	k.cyl(wx, 0.5, wz, WELL_R + 0.35, WELL_R + 0.35, 0.16, C_MARBLE2, 20, false); k.disc(wx, 0.66, wz, WELL_R + 0.35, C_MARBLE2, 20, WELL_R)
	clear.disc(wx, 0.6, wz, WELL_R, Color(C_WATER, 0.72), 20)
	glow.disc(wx, 0.56, wz, WELL_R * 0.55, C_CYAN.darkened(0.15), 16)
	world.lamps.push_back({"x": wx, "y": 3.4, "z": wz})
	# the stars set in the floor: lines of light that show where you are through smoke
	var stars := [[-9.0, -4.0], [-4.5, -10.5], [3.0, -11.5], [10.0, -6.0], [11.5, 2.5], [6.0, 10.0], [-3.0, 11.5], [-10.5, 6.0]]
	for i in stars.size():
		var a := Vector3(wx + stars[i][0], 0.07, wz + stars[i][1]); var b := Vector3(wx + stars[(i + 3) % stars.size()][0], 0.07, wz + stars[(i + 3) % stars.size()][1])
		glow.strip(a, b, 0.12, C_GOLD.darkened(0.1)); glow.disc(a.x, 0.08, a.z, 0.3, Color("7fb4ff"), 6)
	# low marble walls to cross the open ground behind
	for m: Array in [[-50.0, -9.0, 4.0, 0.0], [-46.0, 8.0, 0.0, 4.0], [-36.0, -14.0, 4.0, 0.0], [-34.0, 13.0, 4.0, 0.0], [-8.0, -12.0, 0.0, 4.0], [-6.0, 10.0, 4.0, 0.0], [4.0, -3.0, 0.0, 4.5], [-58.0, 2.0, 0.0, 4.0]]:
		var lx: float = maxf(m[2], 0.7); var lz: float = maxf(m[3], 0.7)
		block(m[0] - lx * 0.5, 0.0, m[1] - lz * 0.5, m[0] + lx * 0.5, 1.05, m[1] + lz * 0.5, C_MARBLE2); slab(m[0] - lx * 0.5 - 0.1, 1.05, m[1] - lz * 0.5 - 0.1, m[0] + lx * 0.5 + 0.1, 1.2, m[1] + lz * 0.5 + 0.1, C_MARBLE)
	for c: Array in [[-60.0, -10.0], [-40.0, 3.0], [-4.0, -1.0], [14.0, 4.0]]: conduit(c[0], c[1])
	# the wood stands back from the glade: a few silverwoods along its sides
	for t: Array in [[-58.0, -17.5, 2.4], [-44.0, 18.0, 2.6], [-30.0, -18.5, 2.2], [-12.0, 18.5, 2.5], [-2.0, -18.0, 2.3]]: tree(t[0], t[1], t[2])

## a deck round a silverwood's trunk, up in the boughs, with a little house on it
func deck(x: float, z: float, open: Array, y0 := 0.0) -> void:
	tree(x, z, 1.8, 38.0 - y0, y0); decks.push_back([x, z])
	var k := _k(x)
	# its floor: eight planks with gaps between them (through the gaps you can look, and shoot, down); two beams under them
	var pw := 2.0 * DK / 8.0
	for i in 8: block(x - DK, TOP - 0.3, z - DK + i * pw + 0.06, x + DK, TOP, z - DK + (i + 1) * pw - 0.06, C_WOOD if i % 2 == 0 else C_WOOD.lightened(0.07), "wood")
	for s: float in [-1.0, 1.0]: slab(x + s * (DK - 0.5) - 0.12, TOP - 0.52, z - DK, x + s * (DK - 0.5) + 0.12, TOP - 0.3, z + DK, C_WOOD2)
	for s: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var sx: int = s[0]; var sz: int = s[1]
		# a rail along the side; where a bridge or a way up comes in, a gap two metres wide is left in the middle of it
		for seg: Array in ([[-DK, -1.0], [1.0, DK]] if open.has(s) else [[-DK, DK]]):
			if sx != 0: block(x + sx * (DK - 0.15), TOP, z + seg[0], x + sx * DK, TOP + 0.95, z + seg[1], C_WOOD2, "wood")
			else: block(x + seg[0], TOP, z + sz * (DK - 0.15), x + seg[1], TOP + 0.95, z + sz * DK, C_WOOD2, "wood")
	for cx: float in [-DK + 0.2, DK - 0.2]:
		for cz: float in [-DK + 0.2, DK - 0.2]: k.box(0.2, 3.0, 0.2, x + cx, TOP + 1.5, z + cz, C_WOOD2)
	k.box(2.0 * DK + 1.0, 0.2, DK + 0.8, x, TOP + 3.3, z - DK * 0.5 - 0.2, C_ROOF, 0.0); k.box(2.0 * DK + 1.0, 0.2, DK + 0.8, x, TOP + 3.3, z + DK * 0.5 + 0.2, C_ROOF, 0.0); k.box(2.0 * DK + 1.2, 0.28, 0.9, x, TOP + 3.75, z, C_ROOF.lightened(0.1))

## a bridge of planks and rope between two decks, along x or along z
func rope_bridge(xa: float, za: float, xb: float, zb: float, y := TOP) -> void:
	var along_x := absf(xb - xa) > absf(zb - za)
	var x0 := minf(xa, xb); var x1 := maxf(xa, xb); var z0 := minf(za, zb); var z1 := maxf(za, zb)
	if along_x: x0 += DK; x1 -= DK; z0 -= 1.0; z1 += 1.0
	else: z0 += DK; z1 -= DK; x0 -= 1.0; x1 += 1.0
	block(x0, y - 0.25, z0, x1, y, z1, C_WOOD, "wood")
	var k := _k((x0 + x1) * 0.5); var n := maxi(2, int((x1 - x0 if along_x else z1 - z0) / 1.5))
	for s: float in [0.0, 1.0]:
		var a := Vector3(x0 if along_x else lerpf(x0, x1, s), y + 1.0, lerpf(z0, z1, s) if along_x else z0); var b := Vector3(x1 if along_x else a.x, y + 1.0, a.z if along_x else z1)
		k.beam(a, b, 0.07, C_WOOD2)
		for i in n + 1: var q := a.lerp(b, float(i) / n); k.beam(q, q - Vector3(0, 1.0, 0), 0.05, C_WOOD2)

## 4-6, the Resonance ravine: the decks in the boughs and their bridges, the crystal bridge and its gatehouses, the stream
func _ravine() -> void:
	# the decks (the first two stand at the glade's far edge)
	deck(10.0, -13.0, [[1, 0]]); deck(10.0, 13.0, [[1, 0], [-1, 0]]); deck(30.0, -13.0, [[1, 0], [-1, 0], [0, 1]]); deck(30.0, 13.0, [[1, 0], [-1, 0], [0, -1]])
	deck(48.0, -13.0, [[1, 0], [-1, 0]]); deck(48.0, 13.0, [[-1, 0]]); deck(67.0, -13.0, [[1, 0], [-1, 0]], PIT_Y); deck(86.0, -13.0, [[-1, 0], [1, 0]])
	rope_bridge(10.0, -13.0, 30.0, -13.0); rope_bridge(30.0, -13.0, 48.0, -13.0); rope_bridge(48.0, -13.0, 67.0, -13.0); rope_bridge(67.0, -13.0, 86.0, -13.0)
	rope_bridge(10.0, 13.0, 30.0, 13.0); rope_bridge(30.0, 13.0, 48.0, 13.0); rope_bridge(30.0, -13.0, 30.0, 13.0)
	stairs_x(0.3, 0.0, 10.0 - DK, TOP, 12.1, 13.9, C_WOOD, null, "wood")   # the plank stair up to the first deck (what a ladder would be)
	for s: float in [12.1, 13.9]: _k(4.0).beam(Vector3(0.3, 0.9, s), Vector3(10.0 - DK, TOP + 0.9, s), 0.08, C_WOOD2)
	for t: Array in [[20.0, 19.0, 2.4], [38.0, -19.0, 2.3], [41.0, 19.5, 2.2], [22.0, -19.0, 2.0]]: tree(t[0], t[1], t[2])
	for c: Array in [[26.0, -3.0], [40.0, 5.0]]: conduit(c[0], c[1])
	# the gatehouses at the two ends of the crystal bridge: two spired towers and a lintel, a narrow way between
	for gx: float in [PIT_X0 - 5.0, PIT_X1 + 1.0]:
		var k := _k(gx)
		for s: float in [-1.0, 1.0]:
			block(gx, 0.0, s * 4.6 - 2.3, gx + 4.0, 9.0, s * 4.6 + 2.3, C_MARBLE2)
			k.cyl(gx + 2.0, 9.0, s * 4.6, 2.5, 2.5, 0.5, C_MARBLE, 8); k.cyl(gx + 2.0, 9.5, s * 4.6, 2.2, 0.0, 6.5, Color("5d7fb8"), 8, false)
			glow.box(0.5, 3.0, 0.12, gx + 2.0, 5.2, s * 4.6 + s * 2.36, C_CYAN.darkened(0.2))
		block(gx, 4.6, -2.3, gx + 4.0, 6.2, 2.3, C_MARBLE)
		glow.box(4.02, 0.2, 3.0, gx + 2.0, 4.5, 0.0, C_GOLD.darkened(0.2))
	# the bridge: its deck over the ravine, low walls along it, a pier in the stream
	block(PIT_X0, -0.7, -3.0, PIT_X1, 0.0, 3.0, C_MARBLE2)
	for s: float in [-1.0, 1.0]:
		for seg: Array in [[PIT_X0, 60.0], [63.0, 71.0], [74.0, PIT_X1]]: block(seg[0], 0.0, s * 3.0 - 0.25, seg[1], 0.95, s * 3.0 + 0.25, C_MARBLE)
	block(65.5, PIT_Y, -1.5, 68.5, -0.7, 1.5, C_MARBLE2.darkened(0.1))
	var kb := _k(67.0)
	for i in 5: kb.box(2.2 - i * 0.3, 0.5, 6.0, PIT_X0 + 1.1 + i * 1.6, -1.0 - i * 0.55, 0.0, C_MARBLE2.darkened(0.08)); kb.box(2.2 - i * 0.3, 0.5, 6.0, PIT_X1 - 1.1 - i * 1.6, -1.0 - i * 0.55, 0.0, C_MARBLE2.darkened(0.08))
	for cx: float in [56.0, 61.5, 72.5, 78.0]:
		for s: float in [-1.0, 1.0]: glow.cyl(cx, 0.95, s * 3.0, 0.2, 0.0, 0.9, C_CYAN if int(cx) % 2 == 0 else C_VIOLET, 5, false)
	# the ways down and up: steps cut into each face
	stairs_x(PIT_X0, 0.0, PIT_X0 + 10.0, PIT_Y, 13.0, 17.0, C_ROCK, PIT_Y)
	stairs_x(PIT_X1 - 10.0, PIT_Y, PIT_X1, 0.0, -17.0, -13.0, C_ROCK, PIT_Y)
	# the stream: silver water winding along the bottom, stones in it, the singing crystals in the rock
	var sp := [[66.0, -24.0], [63.5, -15.0], [69.0, -6.0], [72.0, 3.0], [66.5, 11.0], [63.0, 18.0], [65.0, 26.0]]
	for i in sp.size() - 1:
		clear.strip(Vector3(sp[i][0], PIT_Y + 0.06, sp[i][1]), Vector3(sp[i + 1][0], PIT_Y + 0.06, sp[i + 1][1]), 5.5, Color(C_WATER, 0.5))
		glow.strip(Vector3(sp[i][0], PIT_Y + 0.04, sp[i][1]), Vector3(sp[i + 1][0], PIT_Y + 0.04, sp[i + 1][1]), 2.2, Color("3f7f8c"))
	for q: Array in [[57.0, -8.0, 1.6, C_CYAN], [77.0, 9.0, 1.9, C_VIOLET], [58.5, 6.0, 1.2, C_VIOLET], [76.0, -4.0, 1.4, C_CYAN], [61.0, -19.0, 1.5, C_CYAN], [74.0, 19.0, 1.3, C_VIOLET]]:
		for j in 3:
			var a: float = j * 2.1 + float(q[0]); glow.cyl(q[0] + cos(a) * 0.5 * j, PIT_Y, q[1] + sin(a) * 0.5 * j, 0.45 * q[2] / (1.0 + j * 0.4), 0.0, q[2] * (1.8 - j * 0.45), q[3], 5, false)
		wall(q[0] - 0.5, PIT_Y, q[1] - 0.5, q[0] + 0.5, PIT_Y + 1.6, q[1] + 0.5); world.lamps.push_back({"x": q[0], "y": PIT_Y + 3.6, "z": q[1]})
	for q: Array in [[60.0, 2.0], [70.0, -11.0], [75.5, 14.0], [56.0, 16.5]]: block(q[0] - 0.9, PIT_Y, q[1] - 0.8, q[0] + 0.9, PIT_Y + 0.9, q[1] + 0.8, C_ROCK2)

## the crags past the ravine: rock closing in on the way from both sides, the hill of terraces on the south side with the
## round stone on top and the plank bridge from it to the tower's library
func _crag() -> void:
	# the north rocks: you can walk their tops from the last deck round to the tower's court
	block(90.0, 0.0, -WZ, 98.0, 7.0, -9.0, C_ROCK); block(98.0, 0.0, -WZ, 106.0, 9.0, -10.0, C_ROCK2); block(106.0, 0.0, -WZ, 112.5, 6.0, -11.0, C_ROCK)
	stairs_x(95.2, 7.0, 98.0, 9.0, -WZ, -13.0, C_ROCK2, 7.0)   # the steps up between the two tops
	stairs_x(86.0 + DK, TOP, 86.0 + DK + 1.2, 7.0, -14.0, -12.0, C_WOOD, null, "wood")   # from the last deck down onto the rock
	for q: Array in [[93.0, -11.5, 2.6, 2.2], [102.0, -13.0, 3.4, 2.0], [109.0, -14.0, 2.8, 1.8]]: _k(q[0]).dome(q[0], 6.0, q[1], q[2], C_ROCK2, 6, 2, q[3], false, C_ROCK)
	# the hill of terraces
	block(88.0, 0.0, 7.0, 106.0, 3.3, WZ, C_ROCK); block(93.0, 3.3, 10.0, 106.0, 6.6, WZ, C_ROCK2); block(98.0, 6.6, 9.0, 106.0, T_F2, WZ, C_ROCK)
	# (each stair starts a step and a half in from the edge below it, so there is somewhere to stand at its foot)
	stairs_x(83.6, 0.0, 88.0, 3.3, 8.0, 11.0, C_STONE2, 0.0); stairs_x(89.4, 3.3, 93.0, 6.6, 12.0, 14.6, C_STONE2, 3.3); stairs_x(94.4, 6.6, 98.0, T_F2, 15.6, 18.2, C_STONE2, 6.6)
	var k := _k(100.0)
	k.cyl(102.0, T_F2, 16.5, 3.6, 3.6, 0.22, C_STONE, 16); k.cyl(102.0, T_F2 + 0.22, 16.5, 2.8, 2.8, 0.2, C_MARBLE2, 16)
	wall(99.6, T_F2, 14.1, 104.4, T_F2 + 0.22, 18.9); wall(100.2, T_F2, 14.7, 103.8, T_F2 + 0.42, 18.3)
	for i in 5: glow.strip(Vector3(102.0 + cos(i * TAU / 5.0) * 2.2, T_F2 + 0.44, 16.5 + sin(i * TAU / 5.0) * 2.2), Vector3(102.0 + cos((i + 2) * TAU / 5.0) * 2.2, T_F2 + 0.44, 16.5 + sin((i + 2) * TAU / 5.0) * 2.2), 0.1, C_RUNE)
	# the plank bridge to the library
	var bx1 := TC.x - sqrt(T_DECK * T_DECK - 10.75 * 10.75) + 0.4
	block(106.0, T_F2 - 0.3, 9.5, bx1, T_F2, 12.0, C_WOOD, "wood")
	for s: float in [9.5, 12.0]:
		k.beam(Vector3(106.0, T_F2 + 1.0, s), Vector3(bx1, T_F2 + 1.0, s), 0.07, C_WOOD2)
		for i in 9: var q := Vector3(lerpf(106.0, bx1, i / 8.0), T_F2 + 1.0, s); k.beam(q, q - Vector3(0, 1.0, 0), 0.05, C_WOOD2)
	for px: float in [110.5, 117.0]: slab(px - 0.25, 0.0, 9.6, px + 0.25, T_F2 - 0.3, 10.1, C_WOOD2); slab(px - 0.25, 0.0, 11.4, px + 0.25, T_F2 - 0.3, 11.9, C_WOOD2)

## 6-7, the spiral tower: its court and colonnade, the stair that winds round its outside (twice), the library on the
## gallery half way up, the observatory on top under the glass dome, the great turning sphere in the middle of it
func _tower() -> void:
	var k := _k(TC.x); var cx := TC.x; var cz := TC.y
	k.disc(cx, 0.03, cz, 22.0, C_STONE.darkened(0.1), 40, T_STAIR)
	# the core
	k.cyl(cx, 0.0, cz, T_CORE, T_CORE, T_F3, C_STONE, 32, false); k.cyl(cx, T_F2 - 0.6, cz, T_CORE + 0.25, T_CORE + 0.25, 0.6, C_STONE2, 32, false); k.cyl(cx, T_F3 - 0.5, cz, T_CORE + 0.25, T_CORE + 0.25, 0.5, C_STONE2, 32, false)
	for b: Array in [[8.0, 3.3], [5.7, 5.7], [3.3, 8.0]]: wall(cx - b[0], 0.0, cz - b[1], cx + b[0], T_F3, cz + b[1])
	for i in 12:
		var a := i * TAU / 12.0 + 0.2
		for yy: float in [3.0, 13.5]: glow.box(0.12, 2.6, 0.9, cx + cos(a) * (T_CORE + 0.05), yy + 1.3, cz + sin(a) * (T_CORE + 0.05), Color("6f9bff").darkened(0.15), -a)
	# the first flight: from the west foot, round by the south and the east, up to the gallery's west end
	var da := TAU / STEPS
	for j in STEPS:
		var a0 := PI - j * da; var a1 := a0 - da; var top := T_F2 * (j + 1) / float(STEPS); var solid := j * 360.0 / STEPS < 200.0
		ring_piece(k, T_CORE, T_STAIR, a1, a0, 0.0 if solid else top - 0.45, top, C_STONE if j % 2 == 0 else C_STONE2, C_STONE2)
		ring_solid(T_CORE, T_STAIR, (a0 + a1) * 0.5, 0.0 if solid else top - 0.45, top)
	# the gallery (the library): three quarters of the way round, from the west by the south and the east to the north
	var g_end := 262.0; var gn := 27
	for j in gn:
		var a0 := PI - deg_to_rad(g_end) * j / gn; var a1 := PI - deg_to_rad(g_end) * (j + 1) / gn
		ring_piece(k, T_CORE, T_DECK, a1, a0, T_F2 - 0.5, T_F2, C_MARBLE2 if j % 2 == 0 else C_STONE, C_STONE2)
		ring_solid(T_CORE, T_DECK, (a0 + a1) * 0.5, T_F2 - 0.5, T_F2, 2.2)
		# its outer rail, and bookshelves along it
		var am := (a0 + a1) * 0.5; var shelf := j % 4 == 1 and j > 2
		if absf(rad_to_deg(am) - 129.8) > 9.0:   # (where the plank bridge comes in, the rail is open)
			var rx := cx + cos(am) * (T_DECK - 0.3); var rz := cz + sin(am) * (T_DECK - 0.3); var hh := 2.4 if shelf else 1.0
			k.box(0.7 if shelf else 0.35, hh, 1.7, rx, T_F2 + hh * 0.5, rz, C_WOOD2 if shelf else C_MARBLE, -am)
			Phys.add_collider(rx - 0.5, T_F2, rz - 0.5, rx + 0.5, T_F2 + hh, rz + 0.5, "wood" if shelf else "concrete")
			if shelf:
				for row in 3: glow.box(0.06, 0.34, 1.3, cx + cos(am) * (T_DECK - 0.68), T_F2 + 0.5 + row * 0.7, cz + sin(am) * (T_DECK - 0.68), [Color("b0503a"), Color("3a6fb0"), Color("b89a3a")][row].darkened(0.25), -am)
	# the second flight: from the gallery's east side, round by the north, the west and the south, up to the top
	for j in STEPS:
		var a0 := -j * da; var a1 := a0 - da; var top := T_F2 + (T_F3 - T_F2) * (j + 1) / float(STEPS); var solid := j * 360.0 / STEPS < 76.0
		ring_piece(k, T_CORE, 10.6, a1, a0, T_F2 if solid else top - 0.45, top, C_MARBLE2 if j % 2 == 0 else C_STONE, C_STONE2)
		ring_solid(T_CORE, 10.6, (a0 + a1) * 0.5, T_F2 if solid else top - 0.45, top, 1.5)
	# the observatory: the core's top, wider on the west and north; eight pillars; the dome of glass; the sphere
	k.disc(cx, T_F3 + 0.01, cz, T_CORE, C_LAPIS, 32)
	# the stars set in its floor, gold in lapis: a ring, and the lines of a constellation across it
	glow.disc(cx, T_F3 + 0.03, cz, 6.4, C_GOLD.darkened(0.2), 40, 6.28); glow.disc(cx, T_F3 + 0.03, cz, 3.2, C_GOLD.darkened(0.3), 32, 3.12)
	var st := [[-5.2, -2.0], [-2.6, -4.6], [1.2, -5.4], [4.8, -2.8], [5.4, 1.6], [2.4, 4.9], [-1.8, 5.2], [-4.9, 2.6]]
	for i in st.size():
		var a := Vector3(cx + st[i][0], T_F3 + 0.03, cz + st[i][1]); var b := Vector3(cx + st[(i + 3) % st.size()][0], T_F3 + 0.03, cz + st[(i + 3) % st.size()][1])
		glow.strip(a, b, 0.07, C_GOLD.darkened(0.25)); glow.disc(a.x, T_F3 + 0.04, a.z, 0.24, Color("9fc4ff"), 6)
	var on := 26
	for j in on:
		var a0 := deg_to_rad(100.0) + deg_to_rad(260.0) * j / on; var a1 := deg_to_rad(100.0) + deg_to_rad(260.0) * (j + 1) / on
		ring_piece(k, T_CORE, 10.6, a0, a1, T_F3 - 0.5, T_F3, C_STONE if j % 2 == 0 else C_MARBLE2, C_STONE2)
		ring_solid(T_CORE, 10.6, (a0 + a1) * 0.5, T_F3 - 0.5, T_F3, 1.5)
		var am := (a0 + a1) * 0.5
		k.box(0.3, 1.0, 1.3, cx + cos(am) * 10.45, T_F3 + 0.5, cz + sin(am) * 10.45, C_MARBLE, -am); Phys.add_collider(cx + cos(am) * 10.45 - 0.4, T_F3, cz + sin(am) * 10.45 - 0.4, cx + cos(am) * 10.45 + 0.4, T_F3 + 1.0, cz + sin(am) * 10.45 + 0.4)
	for i in 8:
		var a := (i + 0.5) * TAU / 8.0; var px := cx + cos(a) * 7.5; var pz := cz + sin(a) * 7.5
		k.cyl(px, T_F3, pz, 0.38, 0.32, 5.2, C_MARBLE, 8, false); wall(px - 0.32, T_F3, pz - 0.32, px + 0.32, T_F3 + 5.2, pz + 0.32)
	k.cyl(cx, T_F3 + 5.2, cz, 8.1, 8.1, 0.5, C_STONE2, 32, false); k.disc(cx, T_F3 + 5.2, cz, 8.1, C_STONE2, 32, 6.9, 0.0, TAU, false)
	clear.dome(cx, T_F3 + 5.7, cz, 8.0, Color(0.25, 0.4, 0.95, 0.42), 20, 6, 0.9, false, Color(0.35, 0.55, 1.0, 0.5)); clear.dome(cx, T_F3 + 5.7, cz, 7.9, Color(0.2, 0.32, 0.8, 0.3), 20, 6, 0.9, true)
	for i in 8: var a := i * TAU / 8.0; k.beam(Vector3(cx + cos(a) * 8.0, T_F3 + 5.7, cz + sin(a) * 8.0), Vector3(cx + cos(a) * 2.0, T_F3 + 12.4, cz + sin(a) * 2.0), 0.16, C_BRASS)
	k.cyl(cx, T_F3, cz, 1.5, 1.1, 0.7, C_STONE2, 12); wall(cx - 1.1, T_F3, cz - 1.1, cx + 1.1, T_F3 + 0.7, cz + 1.1)
	# the court: its colonnade round the west side, the gate, the round bastion on the south-west
	for i in 11:
		var a := deg_to_rad(100.0 + i * 16.0)
		if absf(rad_to_deg(a) - 180.0) < 6.0: continue   # the gate
		var px := cx + cos(a) * 21.0; var pz := cz + sin(a) * 21.0
		if absf(pz) > WZ - 1.0: continue
		k.box(1.0, 5.0, 1.0, px, 2.5, pz, C_MARBLE2, -a); wall(px - 0.5, 0.0, pz - 0.5, px + 0.5, 5.0, pz + 0.5)
		k.box(1.3, 0.5, 6.2, px, 5.25, pz, C_MARBLE, -a)
	for s: float in [-1.0, 1.0]:
		block(cx - 22.0, 0.0, s * 2.6 - 0.8, cx - 20.2, 6.5, s * 2.6 + 0.8, C_MARBLE2); k.cyl(cx - 21.1, 6.5, s * 2.6, 1.1, 0.0, 2.6, Color("5d7fb8"), 6, false)
	var bq := Vector2(cx + cos(deg_to_rad(135.0)) * 19.0, cz + sin(deg_to_rad(135.0)) * 19.0)
	k.cyl(bq.x, 0.0, bq.y, 4.2, 4.2, 0.5, C_STONE, 16); wall(bq.x - 3.0, 0.0, bq.y - 3.0, bq.x + 3.0, 0.5, bq.y + 3.0)

# ---------------- what stands about: lanterns, obelisks, ferns, puffballs, portals, banners, vines, the turning rings ----------------
func obelisk(x: float, z: float, y := 0.0) -> void:
	block(x - 0.35, y, z - 0.35, x + 0.35, y + 2.0, z + 0.35, C_STONE2); _k(x).cyl(x, y + 2.0, z, 0.36, 0.0, 0.5, C_STONE2, 4, false)
	var m := MeshKit.new()
	for i in 4:
		var a := i * TAU / 4.0; var d := Vector3(cos(a), 0, sin(a)) * 0.36
		for j in 3: m.box(0.3 if j != 1 else 0.16, 0.12, 0.02, d.x, 0.55 + j * 0.42, d.z, Color.WHITE, -a + PI / 2.0)
	var mat := Gfx.unlit(Color("6fd6ff"), false); var n := m.node(mat, G); n.position = Vector3(x, y, z); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	obelisks.push_back({"x": x, "y": y, "z": z, "n": n, "mat": mat, "hot": false, "rang": 0.0})

## a bed of veil ferns: fronds as tall as you, a curtain from far off; step in and they part (you see out from within)
func fern(x: float, z: float, r: float, y := 0.0) -> void:
	var m := MeshKit.new(); var n := int(r * r * 3.4)
	for i in n:
		var a := i * 2.399963; var rr := r * sqrt((i + 0.5) / n); var px := cos(a) * rr; var pz := sin(a) * rr; var h := 2.05 + sin(i * 1.7) * 0.3
		var lean := Vector3(cos(a * 1.3) * 0.5, 0, sin(a * 1.3) * 0.5); var side := Vector3(-sin(a * 2.1), 0, cos(a * 2.1)) * 0.5
		# a frond: a broad blade that narrows to its tip, two leaflets off it
		m.quad(Vector3(px, 0, pz) - side * 0.9, Vector3(px, 0, pz) + side * 0.9, Vector3(px, h * 0.6, pz) + lean * 0.5 + side * 0.7, Vector3(px, h * 0.6, pz) + lean * 0.5 - side * 0.7, Color(0.2, 0.62, 0.55, 0.9))
		m.quad(Vector3(px, h * 0.6, pz) + lean * 0.5 - side * 0.7, Vector3(px, h * 0.6, pz) + lean * 0.5 + side * 0.7, Vector3(px, h, pz) + lean + side * 0.08, Vector3(px, h, pz) + lean - side * 0.08, Color(0.36, 0.86, 0.74, 0.86))
		m.strip(Vector3(px, h * 0.45, pz) + lean * 0.3, Vector3(px, h * 0.9, pz) + lean * 0.4 + side * 1.6, 0.34, Color(0.5, 0.95, 0.82, 0.8), false)
	var mat := Gfx.unlit(Color.WHITE, false); mat.vertex_color_use_as_albedo = true; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := m.node(Gfx.see_through(mat), G); node.position = Vector3(x, y, z); node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ferns.push_back({"x": x, "y": y, "z": z, "r": r, "mat": mat, "a": 1.0, "n": node})

## a gravity-spore puffball: anything that hits it bursts it, and for four seconds the air over it carries you up
func puffball(x: float, z: float, y := 0.0) -> void:
	var p := {"x": x, "y": y, "z": z, "c": null, "n": null, "lift": 0.0, "grow": 0.0}; puffs.push_back(p); _puff_grow(p)

func _puff_grow(p: Dictionary) -> void:
	var m := MeshKit.new(); m.cyl(0, 0, 0, 0.22, 0.16, 0.5, Color("d9cfe6"), 8, false); m.dome(0, 0.42, 0, 0.62, Color("8a4fd0"), 10, 3, 0.75, false, Color("b98cf0"))
	for i in 5: m.dome(cos(i * 1.3) * 0.34, 0.66 + (i % 2) * 0.12, sin(i * 1.3) * 0.34, 0.1, Color("e6d4ff"), 5, 2)
	var n := m.node(_mat_lit, G); n.position = Vector3(p.x, p.y, p.z)
	var c := {"idx": -1, "hp": 1.0, "x": p.x, "z": p.z, "y": p.y, "dead": false, "puff": true, "node": n}
	c.b = Phys.add_collider(p.x - 0.55, p.y, p.z - 0.55, p.x + 0.55, p.y + 0.95, p.z + 0.55, "wood", c); c.b.step = true
	world.crates.push_back(c); p.c = c; p.n = n

## burst (Game.on_crate): the spores go up
func puffed(c: Dictionary) -> void:
	world.crates.erase(c)
	for p: Dictionary in puffs:
		if p.c != c: continue
		p.c = null; p.n = null; p.lift = 4.0; p.grow = 9.0; Snd.play("elf_puff", 1.0, Vector3(p.x, p.y + 0.5, p.z))
		_tell("puff", "중력 포자 버섯 · 4초 동안 그 위로 떠오릅니다")

func portal(a: Vector3, b: Vector3, col: Color) -> void:
	portals.push_back({"a": a, "b": b, "r": 1.4})
	for q: Vector3 in [a, b]:
		glow.disc(q.x, q.y + 0.05, q.z, 1.5, col, 20, 1.25); glow.disc(q.x, q.y + 0.05, q.z, 0.9, col.darkened(0.25), 6, 0.78)
	world.lamps.push_back({"x": a.x, "y": a.y + 2.8, "z": a.z})

## a lantern on a silver thread: a drop of glass that swings when you run past or a shot goes by
func lantern(x: float, y: float, z: float, drop := 2.4) -> void:
	var pivot := Node3D.new(); pivot.position = Vector3(x, y, z); G.add_child(pivot)
	if _lantern_mesh == null:
		var m := MeshKit.new(); m.beam(Vector3.ZERO, Vector3(0, -1.0, 0), 0.02, Color("dfe8ee")); m.cyl(0, -1.5, 0, 0.0, 0.2, 0.28, C_CYAN, 6, false); m.cyl(0, -1.22, 0, 0.2, 0.05, 0.24, C_RUNE, 6, false)
		_lantern_mesh = m.mesh()
	var mi := MeshInstance3D.new(); mi.mesh = _lantern_mesh; mi.material_override = _lantern_mat(); mi.scale = Vector3(1.0, drop / 1.5, 1.0); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pivot.add_child(mi)
	lanterns.push_back({"n": pivot, "at": Vector3(x, y - drop, z), "sway": 0.12, "ph": x * 0.7 + z}); world.lamps.push_back({"x": x, "y": y - drop + 0.2, "z": z})
var _lantern_mesh: ArrayMesh = null; var _lm: StandardMaterial3D = null
func _lantern_mat() -> StandardMaterial3D:
	if _lm == null: _lm = Gfx.unlit(Color.WHITE, false); _lm.vertex_color_use_as_albedo = true
	return _lm

## rings turning in the air (an astrolabe; the great sphere on the tower)
func rings(at: Vector3, radii: Array, thick: float, speed: float, orb := 0.0) -> void:
	var mat := Gfx.std(C_BRASS, 0.35, 0.8)
	for i in radii.size():
		var n := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.outer_radius = radii[i]; tm.inner_radius = float(radii[i]) - thick; tm.rings = 28; tm.ring_segments = 6
		n.mesh = tm; n.material_override = mat; n.position = at; n.rotation = Vector3(i * 1.1, i * 0.7, i * 0.5); G.add_child(n)
		spinners.push_back({"n": n, "axis": Vector3(sin(i * 2.1), cos(i * 1.3), sin(i * 0.7 + 1.0)).normalized(), "speed": speed * (1.0 + i * 0.35) * (1.0 if i % 2 == 0 else -1.0)})
	if orb > 0.0:
		var o := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = orb; sm.height = orb * 2.0; sm.radial_segments = 14; sm.rings = 8; o.mesh = sm
		o.material_override = Gfx.unlit(Color("9fd0ff"), false); o.position = at; o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; G.add_child(o); world.lamps.push_back({"x": at.x, "y": at.y, "z": at.z})

## a banner of silver thread on a pole, flying towards the tower (the way to go)
func banner(x: float, z: float, y := 0.0) -> void:
	var k := _k(x); k.cyl(x, y, z, 0.07, 0.05, 5.2, C_STONE, 6, false)
	# (silk the colour of the evening, thin enough to see through, a crescent moon worked on it in silver)
	clear.quad(Vector3(x, y + 5.0, z), Vector3(x + 2.6, y + 4.7, z + 0.2), Vector3(x + 2.9, y + 3.5, z - 0.1), Vector3(x, y + 3.4, z), Color(0.16, 0.34, 0.62, 0.72), Vector3(0, 0, 1))
	clear.quad(Vector3(x + 2.6, y + 4.7, z + 0.2), Vector3(x + 3.7, y + 4.05, z + 0.05), Vector3(x + 2.9, y + 3.5, z - 0.1), Vector3(x + 2.75, y + 4.1, z + 0.05), Color(0.16, 0.34, 0.62, 0.72), Vector3(0, 0, 1))   # its tail, pointing the way
	for s: float in [-1.0, 1.0]:
		var bz := z + 0.06 + s * 0.035
		for i in 7:   # the crescent: an arc of small pieces, thick in the middle, thin at its horns
			var a0 := 0.9 + i * 0.62; var a1 := a0 + 0.62; var w0 := 0.015 + 0.07 * sin(i / 7.0 * PI); var w1 := 0.015 + 0.07 * sin((i + 1) / 7.0 * PI)
			var c := Vector3(x + 1.3, y + 4.2, bz); var d0 := Vector3(cos(a0), sin(a0), 0); var d1 := Vector3(cos(a1), sin(a1), 0)
			glow.quad(c + d0 * (0.42 - w0), c + d0 * (0.42 + w0), c + d1 * (0.42 + w1), c + d1 * (0.42 - w1), C_RUNE, Vector3(0, 0, s))

## a rack of white jade for bolts and blades (see update: the alchemist's bomb comes back sooner by it)
func rack(x: float, z: float, y := 0.0) -> void:
	block(x - 0.7, y, z - 0.25, x + 0.7, y + 1.3, z + 0.25, C_MARBLE)
	for i in 4: glow.box(0.05, 0.9, 0.05, x - 0.45 + i * 0.3, y + 1.6, z, C_CYAN.darkened(0.1))
	racks.push_back({"x": x, "y": y, "z": z, "t": 0.0})

func _dress() -> void:
	# obelisks at the corners where someone could lie in wait
	for o: Array in [[-106.0, 9.5], [-84.0, -14.5], [-62.0, 14.0], [-10.0, -15.0], [36.0, -6.0], [85.5, 5.0, 0.0], [110.0, -6.5]]: obelisk(o[0], o[1])
	obelisk(60.0, 9.0, PIT_Y)
	# veil ferns
	for f: Array in [[-118.0, -15.0, 3.2], [-88.0, 16.5, 2.8], [-64.0, -5.0, 3.0], [-52.0, 17.0, 3.2], [-28.0, 16.0, 2.6], [18.0, -8.0, 3.0], [38.0, 15.0, 3.0], [100.0, 0.5, 2.6]]: fern(f[0], f[1], f[2])
	fern(74.0, -8.0, 2.8, PIT_Y); fern(57.0, 19.0, 2.4, PIT_Y)
	# the lanterns, hung from the boughs along the way
	for l: Array in [[-124.0, 6.0, -8.0], [-110.0, 6.5, 8.0], [-97.0, 6.0, -8.5], [-89.0, 6.5, 7.0], [-78.0, 6.0, -4.0], [-70.0, 6.5, 9.0], [-56.0, 7.0, -13.0], [-40.0, 7.0, 14.0], [-8.0, 7.0, 14.0], [2.0, 7.0, -13.0],
			[20.0, 13.0, -13.0], [20.0, 13.0, 13.0], [39.0, 13.0, -13.0], [39.0, 13.0, 13.0], [57.5, 13.0, -13.0], [76.5, 13.0, -13.0], [94.0, 12.0, 2.0], [108.0, 8.0, 1.0]]:
		lantern(l[0], l[1], l[2], 2.2 if l[1] < 10.0 else 3.4)
	# puffballs: at the roots under the bridges of the boughs, and down in the ravine
	puffball(21.0, -10.4); puffball(39.0, 10.4); puffball(-71.0, 17.5); puffball(60.5, -10.4, PIT_Y); puffball(92.5, -7.6)
	# the portals: from the stream up to the deck over it; from the court's bastion up to the library
	portal(Vector3(64.0, PIT_Y, 8.5), Vector3(67.0 - 2.4, TOP, -13.0 + 2.4), C_VIOLET)
	portal(Vector3(TC.x + cos(deg_to_rad(135.0)) * 19.0, 0.5, TC.y + sin(deg_to_rad(135.0)) * 19.0), Vector3(TC.x + cos(deg_to_rad(45.0)) * 12.2, T_F2, TC.y + sin(deg_to_rad(45.0)) * 12.2), Color("c9a8ff"))
	# the amplifying circle at the stair's foot
	glow.disc(AMP.x, 0.06, AMP.z, AMP_R, C_GOLD, 24, AMP_R - 0.3); glow.disc(AMP.x, 0.06, AMP.z, AMP_R * 0.62, C_GOLD.darkened(0.2), 4, AMP_R * 0.5)
	for i in 4: var a := i * TAU / 4.0 + 0.4; glow.strip(Vector3(AMP.x + cos(a) * 0.6, 0.07, AMP.z + sin(a) * 0.6), Vector3(AMP.x + cos(a) * (AMP_R - 0.4), 0.07, AMP.z + sin(a) * (AMP_R - 0.4)), 0.14, C_GOLD)
	world.lamps.push_back({"x": AMP.x, "y": 3.2, "z": AMP.z})
	# banners along the way, racks by the decks and the gates
	for b: Array in [[-127.0, -5.0], [-100.0, 6.0], [-66.0, -8.0], [-46.0, -15.0], [0.0, 9.0], [24.0, 6.0], [45.5, -8.5], [87.5, -8.0], [111.0, 5.5]]: banner(b[0], b[1])
	for r: Array in [[6.0, 9.6], [45.0, 8.5], [89.5, 2.0], [116.5, -5.0]]: rack(r[0], r[1])
	rack(TC.x + 12.5, TC.y - 4.0, T_F2)
	# dew vines down the tower and the ravine's faces
	for i in 14:
		var a := i * TAU / 14.0 + 0.3; var top := 9.0 + (i % 3) * 3.5
		glow.ribbon(Vector3(TC.x + cos(a) * (T_CORE + 0.08), top, TC.y + sin(a) * (T_CORE + 0.08)), Vector3(TC.x + cos(a + 0.05) * (T_CORE + 0.08), top - 3.0 - (i % 2) * 1.5, TC.y + sin(a + 0.05) * (T_CORE + 0.08)), 0.12, Color("b8fff0").darkened(0.2), Vector3(cos(a), 0, sin(a)))
	for i in 10:
		var z := -19.0 + i * 4.2
		glow.ribbon(Vector3(PIT_X0 + 0.03, -0.3, z), Vector3(PIT_X0 + 0.03, -2.4 - (i % 3) * 0.8, z + 0.3), 0.12, Color("b8fff0").darkened(0.25), Vector3(1, 0, 0))
		glow.ribbon(Vector3(PIT_X1 - 0.03, -0.3, z + 2.0), Vector3(PIT_X1 - 0.03, -2.0 - (i % 2) * 1.2, z + 2.3), 0.12, Color("b8fff0").darkened(0.25), Vector3(-1, 0, 0))
	# the astrolabe over the pavilion, another over the bridge; the great sphere under the dome; the library's books adrift
	rings(Vector3(WELL.x, 14.0, WELL.z), [1.7, 1.25], 0.07, 0.5, 0.3); rings(Vector3(67.0, 9.5, 0.0), [1.5, 1.1], 0.06, 0.4, 0.25)
	rings(Vector3(TC.x, T_F3 + 3.4, TC.y), [2.7, 2.25, 1.8], 0.12, 1.1, 0.75)
	var bm := MeshKit.new()
	for i in 14:
		var a := deg_to_rad(10.0 + i * 13.0); var r := 11.0 + (i % 3) * 1.1
		bm.box(0.5, 0.12, 0.36, cos(a) * r, 2.2 + (i % 4) * 0.7, sin(a) * r, [Color("b0503a"), Color("3a6fb0"), Color("b89a3a"), Color("5a8a4a")][i % 4], a + i)
	books = Node3D.new(); books.position = Vector3(TC.x, T_F2, TC.y); G.add_child(books); bm.node(_mat_lit, books)
	# the mist that rises off the moonwell
	var mm := MeshKit.new(); mm.dome(0, 0, 0, 6.2, Color(0.82, 0.95, 1.0, 0.5), 14, 4, 0.6, false, Color(0.9, 1.0, 1.0, 0.2)); mm.dome(0, 0, 0, 6.1, Color(0.82, 0.95, 1.0, 0.4), 14, 4, 0.6, true)
	var mmat := Gfx.unlit(Color(1, 1, 1, 0.0), false); mmat.vertex_color_use_as_albedo = true; mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist_n = mm.node(Gfx.see_through(mmat), G); mist_n.position = Vector3(WELL.x, 0.5, WELL.z); mist_n.visible = false; mist_n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mist_n.set_meta("mat", mmat)
	# where the Archmage steps to
	for i in 6: var a := i * TAU / 6.0 + 0.5; perches.push_back(Vector3(TC.x + cos(a) * 5.2, T_F3, TC.y + sin(a) * 5.2))
	for a: float in [deg_to_rad(200.0), deg_to_rad(270.0), deg_to_rad(330.0)]: perches.push_back(Vector3(TC.x + cos(a) * 9.4, T_F3, TC.y + sin(a) * 9.4))

# ---------------- the elves ----------------
const WEST := -PI / 2.0   # (facing the way you come from)
func _posts() -> void:
	# the border: crossbows behind the roots, two blades lying in wait behind the trunks
	for p: Array in [[-99.6, -7.0], [-91.6, 6.0], [-79.5, -3.0], [-71.4, 8.0], [-86.0, -15.5], [-76.5, 18.0]]: post("elf_ranger", p[0], 0.0, p[1], WEST)
	post("elf_blade", -95.5, 0.0, 16.5, WEST); post("elf_blade", -78.0, 0.0, -13.5, WEST)
	# the glade: crossbows behind the low walls, blades about the pavilion, a mage in it, bows on the first two decks
	for p: Array in [[-56.6, 2.0], [-44.6, 8.0], [-6.6, -12.0], [5.4, -3.0], [-50.0, -10.4], [-36.0, -15.4], [-34.0, 14.4], [-6.0, 11.4]]: post("elf_ranger", p[0], 0.0, p[1], WEST)
	post("elf_blade", -17.5, 0.5, 4.5, WEST); post("elf_blade", -26.5, 0.5, -4.5, WEST); post("elf_blade", -41.0, 0.0, -19.0, WEST)
	post("elf_mage", -16.6, 0.5, 0.0, WEST)
	_deck_post("elf_sniper", 10.0, -13.0, -1, 1); _deck_post("elf_sniper", 10.0, 13.0, -1, 1)
	# the ravine: the decks, the way to the bridge, the bridge, the stream, the crags
	_deck_post("elf_ranger", 30.0, -13.0, -1, -1); _deck_post("elf_sniper", 30.0, 13.0, 1, 1); _deck_post("elf_sniper", 48.0, -13.0, -1, 1)
	_deck_post("elf_sniper", 48.0, 13.0, -1, 1); _deck_post("elf_mage", 67.0, -13.0, 1, -1); _deck_post("elf_ranger", 86.0, -13.0, 1, 1)
	post("elf_ranger", 27.3, 0.0, -3.0, WEST); post("elf_ranger", 41.3, 0.0, 5.0, WEST); post("elf_blade", 36.0, 0.0, -9.0, WEST); post("elf_blade", 44.0, 0.0, 12.0, WEST)
	post("elf_ranger", 58.0, 0.0, -1.8, WEST); post("elf_ranger", 68.0, 0.0, 1.8, WEST); post("elf_mage", 79.5, 0.0, 0.0, WEST)
	post("elf_blade", 60.0, PIT_Y, -13.0, WEST); post("elf_blade", 73.0, PIT_Y, 13.0, WEST); post("elf_ranger", 70.5, PIT_Y, -3.0, WEST)
	post("elf_ranger", 95.0, 0.0, -6.0, WEST); post("elf_ranger", 101.0, 0.0, 4.0, WEST); post("elf_blade", 105.0, 0.0, -2.5, WEST)
	post("elf_sniper", 99.0, 3.3, 8.3, WEST, {"perch": true}); post("elf_ranger", 94.0, 6.6, 19.0, WEST, {"perch": true}); post("elf_mage", 103.2, T_F2, 20.0, WEST, {"perch": true})
	post("elf_ranger", 94.0, 7.0, -15.5, WEST, {"perch": true}); post("elf_sniper", 102.0, 9.0, -16.5, WEST, {"perch": true})
	# the tower: the court, the first flight, the library, the second flight; the Archmage on top
	post("elf_ranger", 116.0, 0.0, 6.5, WEST); post("elf_ranger", 126.0, 0.0, -16.5, WEST); post("elf_ranger", 118.0, 0.0, -9.0, WEST)
	post("elf_blade", 140.0, 0.0, -15.5, WEST); post("elf_blade", 147.0, 0.0, 7.0, WEST); post("elf_blade", 128.5, 0.0, 17.0, WEST)
	for q: Array in [["elf_ranger", 90.0, 10.0, 4.0], ["elf_mage", 0.0, 10.0, 6.5], ["elf_ranger", -90.0, 10.0, 9.0]]: _ring_post(q[0], q[1], q[2], q[3])
	for q: Array in [["elf_mage", 45.0, 12.6, T_F2 + 0.5], ["elf_sniper", 100.0, 12.6, T_F2 + 0.5], ["elf_ranger", -62.0, 12.8, T_F2 + 0.5], ["elf_sniper", 160.0, 12.6, T_F2 + 0.5]]: _ring_post(q[0], q[1], q[2], q[3])
	_ring_post("elf_ranger", -150.0, 9.3, 15.5)
	post("archmage", TC.x - 5.0, T_F3, TC.y, WEST, {"boss": true, "perch": true})

## an elf on a deck, in one of its corners (between the trunk and the rail)
func _deck_post(type: String, dx: float, dz: float, cx: int, cz: int) -> void: post(type, dx + cx * 2.4, TOP, dz + cz * 2.4, WEST, {"perch": true})

func _ring_post(type: String, deg: float, r: float, y: float) -> void:
	var a := deg_to_rad(deg); post(type, TC.x + cos(a) * r, y, TC.y + sin(a) * r, WEST, {"perch": true})

func populate(put: Callable) -> void:
	for i in posts.size():
		var p: Dictionary = posts[i]; var y := Phys.ground_at(p.x, float(p.y) + 0.7, p.z, 0.3)
		var o := {"yaw": p.yaw, "v": i, "post": {"x": p.x, "y": y, "z": p.z, "perch": p.get("perch", false)}}
		if p.get("boss", false): o.boss = true
		put.call(p.type, {"x": p.x, "z": p.z, "y": y}, o)

## the Archmage calls two blades to the top of the stair (they pay nothing: they were not here)
func summon(n: int) -> void:
	for i in n:
		var a := deg_to_rad(20.0 + i * 50.0); var x := TC.x + cos(a) * 6.2; var z := TC.y + sin(a) * 6.2
		var e := enemies.spawn("elf_blade", x, z, {"y": T_F3, "yaw": WEST, "post": {"x": x, "y": T_F3, "z": z}, "v": i})
		e.extra = true; e.k.wait = false; enemies.alarm(e)
		if fx != null: fx.spark(Vector3(x, T_F3 + 1.0, z))

## a place round the sphere for the Archmage to step to: not where he is, not on top of you
func perch_away(from: Vector3, you: Vector3):
	var ok := perches.filter(func(q: Vector3) -> bool: return q.distance_to(from) > 3.0 and Vector2(q.x - you.x, q.z - you.z).length() > 5.0 and Phys.collide_at(q.x, q.y + 0.05, q.z, 0.42, 2.1) == null)
	return ok[randi() % ok.size()] if not ok.is_empty() else null

## the tower's master is down: the great sphere runs down and stops
func still() -> void: spin = 0.0

# ---------------- what the place does ----------------
func _tell(key: String, text: String) -> void:
	if _told.has(key): return
	_told[key] = true
	if game != null: game.say_feed(text)

## whether you are out of an elf's sight for where you stand: in a bed of ferns or in the moonwell's mist, it far off, and
## you not having fired just now
func hides(p: Player, dist: float) -> bool:
	if dist < 9.0 or _fired < 2.0: return false
	if mist > 0.5 and Vector2(p.pos.x - WELL.x, p.pos.z - WELL.z).length() < 6.4: return true
	for f: Dictionary in ferns:
		if absf(p.pos.y - float(f.y)) < 1.5 and Vector2(p.pos.x - float(f.x), p.pos.z - float(f.z)).length() < float(f.r): return true
	return false

## a bolt's way round a corner: off one face of a silverwood's trunk. [where it strikes the bark, where it ends], or null
func glance(from: Vector3, target: Vector3):
	for b: Phys.Box in mirrors:
		var cx := (b.minx + b.maxx) * 0.5; var cz := (b.minz + b.maxz) * 0.5
		if Vector2(cx - from.x, cz - from.z).length() > 32.0 or Vector2(cx - target.x, cz - target.z).length() > 32.0: continue
		for face in 4:
			var q := Vector3.ZERO; var n := Vector3.ZERO
			if face < 2:   # a face across x
				var px := b.maxx if face == 0 else b.minx; n = Vector3(1.0 if face == 0 else -1.0, 0, 0)
				if (from.x - px) * n.x <= 0.2 or (target.x - px) * n.x <= 0.2: continue
				var img := Vector3(2.0 * px - target.x, target.y, target.z); var tt := (px - from.x) / (img.x - from.x); q = from.lerp(img, tt)
				if q.z < b.minz + 0.1 or q.z > b.maxz - 0.1: continue
			else:
				var pz := b.maxz if face == 2 else b.minz; n = Vector3(0, 0, 1.0 if face == 2 else -1.0)
				if (from.z - pz) * n.z <= 0.2 or (target.z - pz) * n.z <= 0.2: continue
				var img2 := Vector3(target.x, target.y, 2.0 * pz - target.z); var t2 := (pz - from.z) / (img2.z - from.z); q = from.lerp(img2, t2)
				if q.x < b.minx + 0.1 or q.x > b.maxx - 0.1: continue
			if q.y < b.miny + 0.3 or q.y > b.maxy - 0.3: continue
			if Phys.line_of_sight(from, q + n * 0.06) and Phys.line_of_sight(q + n * 0.06, target): return [q, target]
	return null

func update(dt: float, p: Player) -> void:
	t += dt; port_cd = maxf(0.0, port_cd - dt)
	var guns = game.guns if game != null else null
	if guns != null:
		if int(guns.shots) != _shots: _shots = int(guns.shots); _fired = 0.0
		_fired += dt
	var live: bool = game == null or not game.ended
	# the wind path: on it, and for a few seconds after, your feet are a third faster
	if p.pos.x > WIND[0] and p.pos.x < WIND[1] and absf(p.pos.z) < WIND[2] and p.pos.y < 1.0: wind_t = 4.0; _tell("wind", "바람길 가속 진 · 이동 속도 +30%")
	else: wind_t = maxf(0.0, wind_t - dt)
	p.slow_mul = 1.3 if wind_t > 0.0 else 1.0
	if wind_t > 0.0 and fx != null and Vector2(p.vel.x, p.vel.z).length() > 3.0 and randf() < dt * 14.0:
		fx.glow(p.pos + Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 1.2), randf_range(-0.6, 0.6)), Vector3(-p.vel.x, 0.3, -p.vel.z) * 0.3, 0.4, 0.2, 0.03, Color(0.86, 1.0, 0.97, 0.5), 0.0, 1.0)
	# the moonwell: its water mends you; hold it five seconds and mist rises to hide you
	var in_well := Vector2(p.pos.x - WELL.x, p.pos.z - WELL.z).length() < WELL_R and p.pos.y < WELL.y + 1.2 and p.pos.y > -0.2
	if in_well and live and p.hp > 0.0:
		well_t += dt
		if p.hp < Player.MAX_HP: p.hp = minf(Player.MAX_HP, p.hp + 15.0 * dt)
		_tell("well", "생명의 달샘 · 초당 체력 15 회복 · 5초 머물면 물안개")
		if fx != null and randf() < dt * 8.0: fx.glow(Vector3(WELL.x + randf_range(-2.0, 2.0), WELL.y + 0.1, WELL.z + randf_range(-2.0, 2.0)), Vector3(0, randf_range(0.6, 1.4), 0), 0.9, 0.12, 0.02, Color(0.6, 1.0, 0.95, 0.7), 0.0, 0.5)
		if well_t >= 5.0 and mist < 1.0: _tell("mist", "물안개가 피어오릅니다 · 정자 안에서는 멀리서 보이지 않습니다")
	else: well_t = 0.0
	mist = move_toward(mist, 1.0 if well_t >= 5.0 else 0.0, dt / (1.2 if well_t >= 5.0 else 4.0))
	if mist_n != null:
		mist_n.visible = mist > 0.01
		if mist_n.visible: (mist_n.get_meta("mat") as StandardMaterial3D).albedo_color.a = mist; mist_n.rotation.y += dt * 0.1
	# the portals
	if port_cd <= 0.0 and live:
		for q: Dictionary in portals:
			var a: Vector3 = q.a
			if Vector2(p.pos.x - a.x, p.pos.z - a.z).length() < float(q.r) and absf(p.pos.y - a.y) < 0.9:
				var b: Vector3 = q.b; p.pos = b + Vector3(0, 0.05, 0); p.vel = Vector3.ZERO; port_cd = 1.5; Snd.play("elf_portal", 1.0, b); p.shake = maxf(p.shake, 0.2)
				if fx != null:
					for i in 12: fx.glow(b + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.8), randf_range(-0.6, 0.6)), Vector3(0, randf_range(0.5, 2.0), 0), 0.6, 0.3, 0.04, Color(0.72, 0.57, 1.0, 0.8), 0.0, 1.0)
				_tell("portal", "차원 도약 포탈 · 위층으로 옮겨졌습니다"); break
	# the puffballs: the spores' lift, and their growing back
	for q: Dictionary in puffs:
		if float(q.lift) > 0.0:
			q.lift = float(q.lift) - dt
			if Vector2(p.pos.x - float(q.x), p.pos.z - float(q.z)).length() < 1.9 and p.pos.y > float(q.y) - 0.5 and p.pos.y < float(q.y) + 11.5 and not p.jet_on:
				p.vel.y = maxf(p.vel.y, 9.5 if p.pos.y < float(q.y) + 9.2 else 0.8); p.grounded = false
			if fx != null and randf() < dt * 26.0: fx.glow(Vector3(float(q.x) + randf_range(-1.4, 1.4), float(q.y) + randf_range(0.0, 4.0), float(q.z) + randf_range(-1.4, 1.4)), Vector3(0, randf_range(5.0, 9.0), 0), 1.0, 0.16, 0.05, Color(0.78, 0.55, 1.0, 0.7), 0.0, 0.3)
		elif q.c == null:
			q.grow = float(q.grow) - dt
			if float(q.grow) <= 0.0 and Vector2(p.pos.x - float(q.x), p.pos.z - float(q.z)).length() > 1.4: _puff_grow(q)
	# the racks: pass one and the alchemist's bomb is back in your hand two seconds sooner (the same rack again after five)
	for r: Dictionary in racks:
		r.t = maxf(0.0, float(r.t) - dt)
		if float(r.t) <= 0.0 and game != null and game.flask_cd > 0.0 and absf(p.pos.y - float(r.y)) < 2.0 and Vector2(p.pos.x - float(r.x), p.pos.z - float(r.z)).length() < 2.4:
			r.t = 5.0; game.flask_cd = maxf(0.0, game.flask_cd - float(Game.FLASK.rack)); Snd.play("elf_chime", 0.8, Vector3(r.x, float(r.y) + 1.2, r.z))
			_tell("rack", "백옥 거치대 · 연금술 폭탄 대기 시간 −2초")
	# the amplifying circle: whatever flies through it is faster and bursts wider
	_amplify()
	# the obelisks: an elf within eight metres of one, and its runes go from blue to red and it rings
	_ob_t -= dt
	if _ob_t <= 0.0 and enemies != null:
		_ob_t = 0.25
		for o: Dictionary in obelisks:
			var hot := false
			for e in enemies.list:
				if e.alive and e.folk and absf(e.pos.y - float(o.y)) < 5.0 and Vector2(e.pos.x - float(o.x), e.pos.z - float(o.z)).length() < 8.0: hot = true; break
			if hot and not bool(o.hot) and t - float(o.rang) > 3.0 and Vector2(p.pos.x - float(o.x), p.pos.z - float(o.z)).length() < 40.0:
				o.rang = t; Snd.play("elf_chime", 1.0, Vector3(o.x, float(o.y) + 1.5, o.z)); _tell("obelisk", "룬 오벨리스크가 붉게 깜박입니다 · 8 m 안에 엘프가 있습니다")
			o.hot = hot
	for o: Dictionary in obelisks:
		var col := Color("ff4a4a").lerp(Color("5a1010"), 0.5 + 0.5 * sin(t * 12.0)) if bool(o.hot) else Color("6fd6ff")
		if (o.mat as StandardMaterial3D).albedo_color != col: (o.mat as StandardMaterial3D).albedo_color = col
	# the ferns part for whoever stands in them
	for f: Dictionary in ferns:
		var inside := absf(p.pos.y - float(f.y)) < 1.5 and Vector2(p.pos.x - float(f.x), p.pos.z - float(f.z)).length() < float(f.r)
		var want := 0.22 if inside else 1.0
		if absf(float(f.a) - want) > 0.005: f.a = move_toward(float(f.a), want, dt * 3.0); (f.mat as StandardMaterial3D).albedo_color.a = float(f.a)
	# the lanterns swing as you run by
	var sp := Vector2(p.vel.x, p.vel.z).length()
	for L: Dictionary in lanterns:
		var at: Vector3 = L.at
		if sp > 6.0 and absf(p.pos.x - at.x) < 2.4 and absf(p.pos.z - at.z) < 2.4 and absf(p.pos.y + 1.2 - at.y) < 3.0: L.sway = minf(0.6, float(L.sway) + dt * 2.5)
		L.sway = maxf(0.05, float(L.sway) - dt * 0.12)
		var n: Node3D = L.n
		if (cam_near(at, 60.0)): n.rotation = Vector3(sin(t * 2.1 + float(L.ph)) * float(L.sway), 0.0, cos(t * 1.7 + float(L.ph)) * float(L.sway) * 0.8)
	# the rings turn; the books drift round the tower
	for q: Dictionary in spinners: (q.n as Node3D).rotate(q.axis, float(q.speed) * dt * (spin if (q.n as Node3D).position.y > T_F3 else 1.0))
	if books != null: books.rotation.y += dt * 0.12; books.position.y = T_F2 + sin(t * 0.8) * 0.25

func cam_near(at: Vector3, r: float) -> bool: return player == null or Vector2(player.pos.x - at.x, player.pos.z - at.z).length() < r

## a shot goes by (Guns): a lantern near its way swings
func shot_by(o: Vector3, d: Vector3, reach: float) -> void:
	for L: Dictionary in lanterns:
		var at: Vector3 = L.at; var tt := clampf((at - o).dot(d), 0.0, reach)
		if (o + d * tt).distance_to(at) < 1.1: L.sway = 0.6

func _amplify() -> void:
	if enemies != null:
		for s: Dictionary in enemies.folk.shots:
			if bool(s.amp): continue
			var q: Vector3 = s.pos
			if Vector2(q.x - AMP.x, q.z - AMP.z).length() < AMP_R and q.y < 6.0: s.amp = true; s.vel = (s.vel as Vector3) * 1.5; s.r = float(s.r) + 0.25; s.splash = float(s.splash) * 1.5; _amp_fx(q)
	if proj != null:
		for q: Dictionary in proj.list:
			if q.get("amp", false) or not q.has("radius"): continue
			var at: Vector3 = q.pos
			if Vector2(at.x - AMP.x, at.z - AMP.z).length() < AMP_R and at.y < 6.0:
				q.amp = true; q.vel = (q.vel as Vector3) * 1.5; q.radius = float(q.radius) * 1.5
				if q.has("speed"): q.speed = float(q.speed) * 1.5
				_amp_fx(at)

func _amp_fx(at: Vector3) -> void:
	Snd.play("elf_chime", 0.6, at)
	if fx != null: fx.sparks(at, 6, [1.0, 0.85, 0.45], 3.0)
