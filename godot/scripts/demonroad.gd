class_name DemonRoad
extends RefCounted
## Stage 6-A, the road to the fallen mage tower (타락한 마탑의 진격로): a party of four, one of each people, walks it from the
## wood at its west end to the sky altar at its east end, one section at a time. A seal of red runes shuts each section
## off until everything that holds it is down (ModeRaid lifts them):
##   0  the camp          a clearing in the wood: the rune altar, the blessing circle, the supply crates; nothing to fight
##   1  the ruined gate   a square of broken obsidian ramparts; the demons' guards behind the rubble
##   2  the chain bridge  a hundred metres of planks hung on chains over the lava caldera; snipers on pillars, a giant beast
##   3  the tower         its hall, and the spiral stair round its inner wall up to the top floor; Karnok, the executioner
##   4  the sky altar     beyond the tower's top, on a pillar of rock out of the lava: Baal, lord of the abyss
## It all grows darker and redder as it climbs (the light is the world's: STAGE_STYLE). Everything is boxes to stand on
## (the round things drawn round over them); east of the chasm's west cliff the floor is the lava (Phys.PIT), and whoever
## falls into it is done for.

const HALF := 192.0
const X0 := -186.0; const X1 := 186.0; const WZ := 30.0
const LAVA := -9.0                                  # the lava's face: the pit's floor
const CLIFF := -46.0                                # the chasm's west cliff: east of it, all stands up out of the lava
const GATE_X0 := -118.0; const GATE_X1 := -58.0; const GATE_Z := 25.0; const GATE_W := 3.6   # the ramparts' square; half its ways through
const BR_X1 := 62.0; const BR_W := 2.75             # the chain bridge: to the tower's rock, half its width
const MID := [-6.0, 6.0, 7.0]                       # the bridge's middle landing: x from, to, half its width
const ISLE := [60.0, 106.0, 24.0]                   # the tower's rock: x from, to, half its width
const TC := Vector2(84.0, 0.0)                      # the tower's middle
const T_OUT := 16.0; const T_IN := 14.8; const T_STAIR := 11.2; const T_BAL := 9.0; const T_TOP := 24.0; const T_ROOF := 31.0
const STEPS := 80; const SPIRAL := 576.0; const ST_END := 300.0   # the stair: its steps, how far round (deg), where it comes out on top
const ST_A0 := ST_END - SPIRAL                      # where it starts (deg): the door is at 180, to the west
const DOOR_A := 180.0; const EXIT_A := 0.0          # the hall's door (west) and the top floor's (east)
const CORE_AT := Vector3(84.0, 0.0, 0.0)            # the gravity circle in the hall's floor, under the middle of the well
const HB_X0 := 100.0; const HB_X1 := 116.0; const HB_W := 3.0   # the high bridge from the top floor (then steps down to the altar)
const AC := Vector2(154.0, 0.0); const AR := 26.0; const AR_SMALL := 21.0; const A_Y := 20.0       # the sky altar
const PILLAR_R := 17.0; const COOL_R := 11.0; const PAD_R := 20.5; const STAKE_R := 24.4
## where a fallen one of the party comes back, section by section (the last one reached)
const CHECK := [Vector3(-166.0, 0.0, 0.0), Vector3(-104.0, 0.0, 0.0), Vector3(-36.0, 0.0, 0.0), Vector3(66.0, 0.0, 0.0), Vector3(104.0, 24.0, 0.0)]
## the seals: [x from, x to, z half, y from, y to, the section that lifts it]
const SEALS := [[GATE_X1 - 1.0, GATE_X1 + 1.0, GATE_W + 0.4, 0.0, 6.0, 1], [TC.x - T_OUT - 0.6, TC.x - T_IN + 0.6, 2.4, 0.0, 5.0, 2], [TC.x + T_IN - 0.6, TC.x + T_OUT + 0.6, HB_W + 0.2, T_TOP, T_TOP + 5.0, 3]]

const C_GRASS := Color("3d5a32"); const C_GRASS2 := Color("4a6a3a"); const C_DIRT := Color("6e5a3e"); const C_PINE := Color("1f3a2a"); const C_PINE2 := Color("2c4a33")
const C_BARK := Color("4a3426"); const C_CANVAS := Color("b9a47a"); const C_CANVAS2 := Color("8f7a52")
const C_OBS := Color("1d1a22"); const C_OBS2 := Color("2b2733"); const C_OBS3 := Color("3a3442"); const C_ASH := Color("5a5258"); const C_ASH2 := Color("443e44")
const C_ROCK := Color("3b2f2c"); const C_ROCK2 := Color("2a2220"); const C_PLANK := Color("6a4a30"); const C_PLANK2 := Color("553a24"); const C_IRON := Color("4c4a50"); const C_IRON2 := Color("6d6a72")
const C_LAVA := Color("ff6a1a"); const C_LAVA2 := Color("ffb347"); const C_EMBER := Color("ff3a12"); const C_RUNE := Color("ff2a3a"); const C_VIOLET := Color("b04aff"); const C_COLD := Color("6ad8ff"); const C_GOLD := Color("e0b050")

var world: World; var G: Node3D
var kits: Array = []          # what is lit, a mesh for each stretch of the map
var glow := MeshKit.new()     # what shines by itself: lava, embers, runes
var clear := MeshKit.new()    # what is seen through: the seals' air, smoke of the braziers
var _mat_lit: StandardMaterial3D; var _mat_glow: StandardMaterial3D; var _mat_clear: StandardMaterial3D
var posts: Array = []         # where the demons stand: {type, x, y, z, yaw, sec, perch}
var seals: Array = []         # {box, node, sec, open}
var pillars: Array = []       # the altar's six obsidian pillars: {i, a, box, node, up}
var rim: Array = []           # the altar's outer ring, that falls in the last phase: {boxes, node}
var rim_down := false
var pads: Array = []          # the altar's two gravity circles: Vector3
var cools: Array = []         # the altar's two cooling circles: Vector3
var stakes: Array = []        # the chain stakes round the altar's edge: Vector3
var ledges: Array = []        # the stone shelves on the stair's outer wall: {a, y}
var crates: Array = []        # the camp's supply crates: Vector3
var bless_at := Vector3(-162.0, 0.0, -9.0); var altar_at := Vector3(-170.0, 0.0, 7.0)
var braziers: Array = []      # {at, node, t}
var lava_n: MeshInstance3D = null; var _lava_t := 0.0
var t := 0.0

# ---------------- building helpers ----------------
func _k(x: float) -> MeshKit: return kits[clampi(int((x - X0) / 93.0), 0, 3)]
func block(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color, kind := "concrete") -> Phys.Box:
	_k((x0 + x1) * 0.5).slab(x0, y0, z0, x1, y1, z1, col)
	return Phys.add_collider(x0, y0, z0, x1, y1, z1, kind)
func slab(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color) -> void: _k((x0 + x1) * 0.5).slab(x0, y0, z0, x1, y1, z1, col)
func wall(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, kind := "concrete") -> Phys.Box: return Phys.add_collider(x0, y0, z0, x1, y1, z1, kind)
func post(type: String, x: float, y: float, z: float, sec: int, more := {}) -> void:
	var p := {"type": type, "x": x, "y": y, "z": z, "yaw": PI / 2.0, "sec": sec}; p.merge(more); posts.push_back(p)

## steps along x from (xa, ya) to (xb, yb) between z0 and z1, none higher than 0.3; solid down to foot
func stairs_x(xa: float, ya: float, xb: float, yb: float, z0: float, z1: float, col: Color, foot: float) -> void:
	var n := maxi(1, ceili(absf(yb - ya) / 0.3)); var dx := (xb - xa) / n; var dy := (yb - ya) / n
	for i in n:
		var top := ya + dy * (i + 1) if dy > 0.0 else ya + dy * i
		var xs := xa + dx * i; var xe := xa + dx * (i + 1)
		block(minf(xs, xe), foot, z0, maxf(xs, xe), top, z1, col)

## a piece of a ring round c: between two angles and two radii, its top at y1 (drawn), and the boxes to stand on under it
func ring_piece(kit: MeshKit, c: Vector2, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, col: Color, col_side: Color) -> void:
	var cc := Vector3(c.x, 0.0, c.y); var d0 := Vector3(cos(a0), 0.0, sin(a0)); var d1 := Vector3(cos(a1), 0.0, sin(a1))
	var up0 := Vector3(0, y0, 0); var up1 := Vector3(0, y1, 0)
	kit.quad(cc + d0 * r0 + up1, cc + d0 * r1 + up1, cc + d1 * r1 + up1, cc + d1 * r0 + up1, col, Vector3.UP)
	kit.quad(cc + d0 * r0 + up0, cc + d0 * r1 + up0, cc + d1 * r1 + up0, cc + d1 * r0 + up0, col_side.darkened(0.3), Vector3.DOWN)
	kit.quad(cc + d0 * r1 + up0, cc + d1 * r1 + up0, cc + d1 * r1 + up1, cc + d0 * r1 + up1, col_side, (d0 + d1).normalized())
	kit.quad(cc + d0 * r0 + up0, cc + d1 * r0 + up0, cc + d1 * r0 + up1, cc + d0 * r0 + up1, col_side, -(d0 + d1).normalized())
	var t0 := Vector3(-d0.z, 0.0, d0.x); var t1 := Vector3(-d1.z, 0.0, d1.x)
	kit.quad(cc + d0 * r0 + up0, cc + d0 * r1 + up0, cc + d0 * r1 + up1, cc + d0 * r0 + up1, col_side, -t0)
	kit.quad(cc + d1 * r0 + up0, cc + d1 * r1 + up0, cc + d1 * r1 + up1, cc + d1 * r0 + up1, col_side, t1)
func ring_solid(c: Vector2, r0: float, r1: float, a: float, y0: float, y1: float, cell := 1.6) -> Array:
	var out := []; var n := maxi(1, ceili((r1 - r0) / (cell * 0.84)))
	for i in n:
		var r := lerpf(r0 + cell * 0.42, r1 - cell * 0.42, float(i) / maxf(1.0, n - 1.0)) if n > 1 else (r0 + r1) * 0.5
		var x := c.x + cos(a) * r; var z := c.y + sin(a) * r
		out.push_back(Phys.add_collider(x - cell * 0.5, y0, z - cell * 0.5, x + cell * 0.5, y1, z + cell * 0.5, "concrete"))
	return out

## the stair's height at an angle round the tower (deg, as far round as it has come from its foot); -1 off it
static func stair_y_at(deg: float) -> float:
	var u := (deg - ST_A0) / SPIRAL
	if u < 0.0 or u > 1.0: return -1.0
	return T_TOP * (floor(u * STEPS) + 1.0) / float(STEPS)
## where on the stair someone stands: [how far round it (deg from the foot, 0..SPIRAL), the stair's height there], or []
static func on_stair(p: Vector3) -> Array:
	var d := Vector2(p.x - TC.x, p.z - TC.y); var r := d.length()
	if r < T_STAIR - 0.4 or r > T_IN + 0.2: return []
	var a := fposmod(rad_to_deg(atan2(d.y, d.x)) - ST_A0, 360.0)
	for turn in 2:   # (the stair goes round more than once: the turn whose height is nearest the feet)
		var u := a + turn * 360.0
		if u > SPIRAL: continue
		var y := T_TOP * (floorf(u / SPIRAL * STEPS) + 1.0) / float(STEPS)
		if absf(p.y - y) < 3.0: return [u, y]
	return []
static func stair_point(u: float, r := 13.0) -> Vector3:
	var a := deg_to_rad(ST_A0 + u); var y := T_TOP * (floorf(clampf(u, 0.0, SPIRAL - 0.01) / SPIRAL * STEPS) + 1.0) / float(STEPS)
	return Vector3(TC.x + cos(a) * r, y, TC.y + sin(a) * r)
static func altar_point(deg: float, r: float) -> Vector3:
	var a := deg_to_rad(deg); return Vector3(AC.x + cos(a) * r, A_Y, AC.y + sin(a) * r)

# ---------------- the map ----------------
func build(w: World, group: Node3D) -> void:
	world = w; G = group
	Phys.set_world_size(HALF); Phys.set_nav(int(HALF * 2.0) + 4, 1.0)
	Phys.PIT = {"x0": CLIFF, "x1": HALF + 10.0, "z0": -HALF - 10.0, "z1": HALF + 10.0, "y": LAVA}
	for i in 4: kits.push_back(MeshKit.new())
	_mat_lit = StandardMaterial3D.new(); _mat_lit.vertex_color_use_as_albedo = true; _mat_lit.roughness = 0.92
	_edges(); _camp(); _gate(); _bridge(); _tower(); _high(); _altar(); _lava()
	_posts()
	_meshes()
	world.start = {"x": CHECK[0].x, "z": CHECK[0].z, "yaw": -PI / 2.0}; world.spawns.clear()
	Phys.index_colliders(); Phys.build_nav()

func _meshes() -> void:
	for k: MeshKit in kits:
		if not k.is_empty(): k.node(_mat_lit, G)
	_mat_glow = Gfx.unlit(Color.WHITE, false); _mat_glow.vertex_color_use_as_albedo = true
	if not glow.is_empty(): var gn := glow.node(_mat_glow, G); gn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat_clear = Gfx.unlit(Color.WHITE, false); _mat_clear.vertex_color_use_as_albedo = true; _mat_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _mat_clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not clear.is_empty(): var cn := clear.node(Gfx.see_through(_mat_clear), G); cn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## the sides: the wood close along the camp and the gate, the caldera's walls beyond, a wall at each end
func _edges() -> void:
	wall(X0 - 4.0, LAVA - 2.0, -WZ - 4.0, X1 + 4.0, 70.0, -WZ); wall(X0 - 4.0, LAVA - 2.0, WZ, X1 + 4.0, 70.0, WZ + 4.0)
	wall(X0 - 4.0, LAVA - 2.0, -WZ - 4.0, X0, 70.0, WZ + 4.0); wall(X1, LAVA - 2.0, -WZ - 4.0, X1 + 4.0, 70.0, WZ + 4.0)
	# the ground west of the chasm: grass in the camp, ash towards the gate
	slab(X0, -0.6, -WZ, -128.0, 0.0, WZ, C_GRASS); slab(-128.0, -0.6, -WZ, CLIFF, 0.0, WZ, C_ASH2)
	for i in 70:
		var x := X0 + 4.0 + fposmod(i * 37.3, 54.0); var z := -WZ + 2.0 + fposmod(i * 23.7, 2.0 * WZ - 4.0); var r := 1.2 + fposmod(i * 0.77, 2.2)
		_k(x).disc(x, 0.012 + (i % 3) * 0.004, z, r, [C_GRASS2, C_GRASS.darkened(0.15), C_DIRT.lerp(C_GRASS, 0.5)][i % 3], 8)
	_k(-150.0).strip(Vector3(X0 + 6.0, 0.02, 0.0), Vector3(-128.0, 0.02, 0.0), 3.4, C_DIRT)
	_k(-90.0).strip(Vector3(-128.0, 0.02, 0.0), Vector3(CLIFF, 0.02, 0.0), 3.6, C_ASH.darkened(0.1))
	# the wood: dark pines along both sides of the camp, thinning out and burnt towards the gate
	for side: float in [-1.0, 1.0]:
		var x := X0 + 3.0; var i := 0
		while x < -60.0:
			var burnt := x > -126.0; var z := side * (WZ - 1.5 - (i % 3) * 1.6); var h := 15.0 + (i % 4) * 3.0
			_pine(x, z, h, burnt)
			x += 4.2 + (i % 3) * 1.6; i += 1
		slab(X0, 0.0, side * (WZ + 2.0) - 0.5, -60.0, 22.0, side * (WZ + 2.0) + 0.5, C_PINE.darkened(0.5))
	# the caldera: its black walls east of the cliff, red-lit from below
	for side: float in [-1.0, 1.0]:
		slab(CLIFF, LAVA, side * (WZ + 0.5) - 1.0, X1, 40.0, side * (WZ + 0.5) + 1.0, C_ROCK2)
		var x := CLIFF + 4.0; var j := 0
		while x < X1 - 4.0:
			var h := 18.0 + fposmod(j * 7.3, 22.0); var zz := side * (WZ - 1.0 - fposmod(j * 1.7, 3.0))
			_k(x).cyl(x, LAVA, zz, 3.2 + fposmod(j * 0.9, 2.0), 1.4, h - LAVA, C_ROCK if j % 2 == 0 else C_ROCK2, 7, true)
			glow.strip(Vector3(x - 1.0, LAVA + 0.4, zz - side * 2.6), Vector3(x + 1.0, LAVA + 3.0 + (j % 3), zz - side * 2.4), 0.14, C_EMBER.darkened(0.25), false)
			x += 9.5 + fposmod(j * 3.1, 5.0); j += 1
	# the chasm's west face, down to the lava
	block(CLIFF - 1.0, LAVA, -WZ, CLIFF, 0.0, WZ, C_ROCK)

func _pine(x: float, z: float, h: float, burnt: bool) -> void:
	var k := _k(x)
	k.cyl(x, 0.0, z, 0.45, 0.25, h, C_BARK.darkened(0.3) if burnt else C_BARK, 6, false)
	Phys.add_collider(x - 0.45, 0.0, z - 0.45, x + 0.45, h, z + 0.45, "wood")
	if burnt: return
	for i in 3: k.cyl(x, h * (0.3 + i * 0.22), z, 2.6 - i * 0.7, 0.2, h * 0.32, C_PINE if i % 2 == 0 else C_PINE2, 7, false)

## 0, the camp: tents round a fire, the rune altar, the blessing circle, the supply crates
func _camp() -> void:
	var k := _k(-160.0)
	for tn: Array in [[-176.0, -14.0, 0.3], [-172.0, 13.0, -0.4], [-152.0, 16.0, 0.6], [-150.0, -17.0, -0.2]]:
		_tent(tn[0], tn[1], tn[2])
	# the fire in the middle
	k.cyl(-160.0, 0.0, 0.0, 1.4, 1.4, 0.3, C_ASH2, 10, true)
	for i in 8: var a := i * TAU / 8.0; k.box(0.5, 0.35, 0.35, -160.0 + cos(a) * 1.5, 0.17, sin(a) * 1.5, C_ASH, -a)
	glow.cyl(-160.0, 0.3, 0.0, 0.8, 0.0, 1.4, C_LAVA2, 6, false); world.lamps.push_back({"x": -160.0, "y": 2.0, "z": 0.0})
	wall(-161.2, 0.0, -1.2, -158.8, 0.4, 1.2)
	# the rune altar: a stone table with glowing runes (B opens it while you stand near it)
	block(altar_at.x - 1.2, 0.0, altar_at.z - 0.8, altar_at.x + 1.2, 1.0, altar_at.z + 0.8, C_OBS3)
	for i in 3: glow.box(0.5, 0.04, 0.5, altar_at.x - 0.7 + i * 0.7, 1.02, altar_at.z, C_COLD.darkened(0.15))
	# the blessing circle: blue runes on the grass
	glow.disc(bless_at.x, 0.04, bless_at.z, 3.6, C_COLD, 32, 3.3); glow.disc(bless_at.x, 0.04, bless_at.z, 2.4, C_COLD.darkened(0.2), 32, 2.2)
	for s in 6: var a := s * TAU / 6.0; glow.strip(Vector3(bless_at.x + cos(a) * 2.3, 0.04, bless_at.z + sin(a) * 2.3), Vector3(bless_at.x + cos(a + 2.1) * 2.3, 0.04, bless_at.z + sin(a + 2.1) * 2.3), 0.08, C_COLD.darkened(0.1))
	world.lamps.push_back({"x": bless_at.x, "y": 1.5, "z": bless_at.z})
	# the supply crates: bombs and what each weapon needs
	for c: Vector3 in [Vector3(-158.0, 0.0, 10.0), Vector3(-146.0, 0.0, -6.0)]:
		block(c.x - 0.7, 0.0, c.z - 0.5, c.x + 0.7, 0.9, c.z + 0.5, C_PLANK, "wood"); slab(c.x - 0.75, 0.9, c.z - 0.55, c.x + 0.75, 0.98, c.z + 0.55, C_PLANK2)
		glow.box(0.3, 0.3, 0.02, c.x, 0.5, c.z + 0.51, C_GOLD)
		crates.push_back(c)

func _tent(x: float, z: float, yaw: float) -> void:
	var k := _k(x); var d := Vector3(cos(yaw), 0, sin(yaw)); var s := Vector3(-d.z, 0, d.x)
	var a := Vector3(x, 0, z); var top := Vector3(x, 2.6, z)
	for sd: float in [-1.0, 1.0]:
		k.quad(a + s * sd * 2.0 - d * 2.2, a + s * sd * 2.0 + d * 2.2, top + d * 2.2, top - d * 2.2, C_CANVAS if sd < 0.0 else C_CANVAS2, (s * sd + Vector3.UP).normalized())
	wall(x - 2.0, 0.0, z - 2.0, x + 2.0, 1.6, z + 2.0, "wood")

## 1, the ruined gate: a square of obsidian ramparts, its corner towers, broken in places; rubble to hide behind inside
func _gate() -> void:
	var x0 := GATE_X0; var x1 := GATE_X1; var zz := GATE_Z
	for side: float in [-1.0, 1.0]:   # the long walls north and south, with breaks
		for seg: Array in [[x0 + 7.0, x0 + 22.0, 7.5], [x0 + 26.0, x0 + 38.0, 5.0], [x0 + 41.0, x1 - 7.0, 7.5]]:
			block(seg[0], 0.0, side * zz - 1.0, seg[1], seg[2], side * zz + 1.0, C_OBS2)
			slab(seg[0], seg[2], side * zz - 1.2, seg[1], seg[2] + 0.4, side * zz + 1.2, C_OBS3)
	for wx: float in [x0, x1]:   # the west and east walls, a way through each (the east one sealed till the guards are down)
		for zs: Array in [[-zz + 1.0, -GATE_W], [GATE_W, zz - 1.0]]:
			block(wx - 1.0, 0.0, zs[0], wx + 1.0, 8.0, zs[1], C_OBS2)
			slab(wx - 1.2, 8.0, zs[0], wx + 1.2, 8.4, zs[1], C_OBS3)
		slab(wx - 1.0, 6.0, -GATE_W, wx + 1.0, 8.0, GATE_W, C_OBS2)   # (over the way through)
		for zs: float in [-GATE_W, GATE_W]: glow.box(0.12, 6.0, 0.12, wx, 3.0, zs, C_RUNE.darkened(0.45))
	for cx: float in [x0, x1]:   # the corner towers, two of them broken down
		for cz: float in [-zz, zz]:
			var h := 13.0 if (cx == x0) == (cz < 0.0) else 8.5
			block(cx - 3.5, 0.0, cz - 3.5, cx + 3.5, h, cz + 3.5, C_OBS)
			for i in 4: slab(cx - 3.6 + i * 2.0, h, cz - 3.6, cx - 3.0 + i * 2.0, h + 1.0, cz + 3.6, C_OBS3)
			glow.box(0.6, 1.2, 0.05, cx, h - 3.0, cz + signf(-cz) * 3.52, C_EMBER.darkened(0.2))
	# the rubble inside: fallen pieces of rampart, waist and chest high, and broken columns
	for r: Array in [[-106.0, -9.0, 5.0, 1.0, 1.5], [-104.0, 8.0, 1.2, 4.6, 1.4], [-96.0, -17.0, 4.0, 1.2, 1.6], [-94.0, 1.5, 1.1, 3.8, 1.2], [-92.0, 15.0, 4.6, 1.2, 1.5],
			[-84.0, -7.0, 3.6, 1.2, 1.4], [-82.0, 9.0, 1.2, 4.2, 1.6], [-74.0, -14.0, 1.2, 4.0, 1.5], [-72.0, 3.0, 4.2, 1.2, 1.3], [-66.0, 16.0, 3.4, 1.2, 1.6], [-66.0, -4.0, 1.2, 3.0, 1.5]]:
		block(r[0] - r[2] * 0.5, 0.0, r[1] - r[3] * 0.5, r[0] + r[2] * 0.5, r[4], r[1] + r[3] * 0.5, C_OBS2)
		slab(r[0] - r[2] * 0.5 + 0.2, r[4], r[1] - r[3] * 0.5 + 0.2, r[0] + r[2] * 0.5 - 0.3, r[4] + 0.25, r[1] + r[3] * 0.5 - 0.2, C_OBS3)
	for c: Array in [[-110.0, 18.0], [-100.0, -2.0], [-88.0, -19.0], [-78.0, 17.0], [-70.0, -9.0]]:
		_k(c[0]).cyl(c[0], 0.0, c[1], 0.8, 0.7, 3.4 + fposmod(c[0] * 0.3, 2.0), C_OBS3, 8, true); wall(c[0] - 0.7, 0.0, c[1] - 0.7, c[0] + 0.7, 4.0, c[1] + 0.7)
	# outside the long walls: rock up to the wood's edge (the breaks in the walls lead nowhere)
	for side: float in [-1.0, 1.0]: block(x0 - 4.0, 0.0, side * (zz + 1.0) if side > 0.0 else -WZ, x1 + 4.0, 10.0, -(zz + 1.0) if side < 0.0 else WZ, C_ROCK2)
	# braziers by the way out to the bridge
	for bz: float in [-6.0, 6.0]: _brazier(Vector3(-52.0, 0.0, bz))

## a fire in an iron bowl on a stand
func _brazier(at: Vector3) -> void:
	var k := _k(at.x)
	k.cyl(at.x, at.y, at.z, 0.18, 0.18, 1.2, C_IRON, 6, false); k.cyl(at.x, at.y + 1.2, at.z, 0.4, 0.7, 0.4, C_IRON2, 8, true)
	wall(at.x - 0.5, at.y, at.z - 0.5, at.x + 0.5, at.y + 1.6, at.z + 0.5)
	glow.cyl(at.x, at.y + 1.6, at.z, 0.55, 0.0, 1.0, C_LAVA2, 6, false)
	world.lamps.push_back({"x": at.x, "y": at.y + 2.4, "z": at.z}); braziers.push_back({"at": at, "t": 0.0})

## 2, the chain bridge: planks hung between iron rails, a landing of stone half way, broken rails where you could fall
func _bridge() -> void:
	var y := 0.0
	# the planks: across the bridge, with thin gaps (a plank every 0.9 m)
	var x := CLIFF; var pi := 0
	while x < BR_X1:
		var xe := minf(x + 0.8, BR_X1)
		if xe <= MID[0] or x >= MID[1]: slab(x, y - 0.4, -BR_W, xe, y, BR_W, C_PLANK if pi % 2 == 0 else C_PLANK2)
		x += 0.9; pi += 1
	# what you walk on: the planks drawn, one board under them all to stand on (no foot goes through a gap)
	wall(CLIFF, y - 0.4, -BR_W, BR_X1, y, BR_W, "wood")
	slab(CLIFF, y - 0.7, -BR_W + 0.3, BR_X1, y - 0.4, -BR_W + 0.7, C_IRON); slab(CLIFF, y - 0.7, BR_W - 0.7, BR_X1, y - 0.4, BR_W - 0.3, C_IRON)
	# the rails: iron, waist high; broken in two places (nothing keeps you on the planks there)
	var breaks := [[-24.0, -16.0, -1.0], [26.0, 33.0, 1.0]]
	for side: float in [-1.0, 1.0]:
		var spans := [[CLIFF, MID[0]], [MID[1], BR_X1]]
		for sp: Array in spans:
			var a: float = sp[0]; var b: float = sp[1]
			var cuts := breaks.filter(func(q): return float(q[2]) == side and float(q[0]) >= a and float(q[1]) <= b)
			var pts := [a]
			for q in cuts: pts.push_back(q[0]); pts.push_back(q[1])
			pts.push_back(b)
			for i in range(0, pts.size(), 2):
				var p0: float = pts[i]; var p1: float = pts[i + 1]
				block(p0, y, side * BR_W - (0.18 if side > 0.0 else 0.0), p1, y + 1.1, side * BR_W + (0.0 if side > 0.0 else 0.18), C_IRON)
				var px := p0
				while px <= p1 + 0.01: _k(px).box(0.2, 1.5, 0.2, px, y + 0.75, side * (BR_W + 0.05), C_IRON2); px += 6.0
	# the chains it hangs from: down from the tower's shoulder and up from the cliff, sagging over the lava
	for side: float in [-1.0, 1.0]:
		for i in 24:
			var u0 := i / 24.0; var u1 := (i + 1) / 24.0
			var a := Vector3(lerpf(CLIFF, BR_X1, u0), y + 1.1 + 10.0 * (1.0 - 4.0 * u0 * (1.0 - u0)) + 2.0, side * (BR_W + 0.1))
			var b := Vector3(lerpf(CLIFF, BR_X1, u1), y + 1.1 + 10.0 * (1.0 - 4.0 * u1 * (1.0 - u1)) + 2.0, side * (BR_W + 0.1))
			_k(a.x).beam(a, b, 0.16, C_IRON2)
			if i % 3 == 0: _k(a.x).beam(a, Vector3(a.x, y + 1.1, a.z), 0.06, C_IRON)
	# the landing half way: stone on a pillar of rock out of the lava; braziers; low walls to hide behind
	block(MID[0], LAVA, -MID[2], MID[1], y, MID[2], C_ROCK)
	slab(MID[0] + 0.2, y, -MID[2] + 0.2, MID[1] - 0.2, y + 0.06, MID[2] - 0.2, C_OBS3)
	for s: float in [-1.0, 1.0]:
		block(MID[0] + 1.0, y, s * (MID[2] - 1.4), MID[1] - 1.0, y + 1.3, s * (MID[2] - 0.6), C_OBS2)
		_brazier(Vector3(MID[0] + 0.8, y, s * (MID[2] - 0.8)))
	# the snipers' pillars either side, a little way off the bridge (only a leap or a blink reaches them)
	for p: Array in [[-30.0, -11.0], [16.0, 11.5], [40.0, -11.0], [52.0, 10.0]]:
		block(p[0] - 1.6, LAVA, p[1] - 1.6, p[0] + 1.6, 6.0, p[1] + 1.6, C_ROCK)
		slab(p[0] - 1.7, 6.0, p[1] - 1.7, p[0] + 1.7, 6.2, p[1] + 1.7, C_OBS3)
		for e: Array in [[-1.6, -1.6], [1.4, -1.6], [-1.6, 1.4], [1.4, 1.4]]: block(p[0] + e[0], 6.0, p[1] + e[1], p[0] + e[0] + 0.2, 7.0, p[1] + e[1] + 0.2, C_OBS2)
		glow.disc(p[0], 6.22, p[1], 0.9, C_RUNE.darkened(0.3), 10, 0.7)
	# torches at both ends
	for tx: float in [CLIFF + 1.5, BR_X1 - 1.5]:
		for s: float in [-1.0, 1.0]:
			_k(tx).cyl(tx, y, s * (BR_W + 0.7), 0.14, 0.12, 2.6, C_IRON, 6, false); glow.cyl(tx, y + 2.6, s * (BR_W + 0.7), 0.3, 0.0, 0.6, C_LAVA2, 6, false)
			world.lamps.push_back({"x": tx, "y": y + 3.0, "z": s * (BR_W + 0.7)})

## 3, the tower: its rock, the round wall with the door to the west, the hall, the stair round the inside up to the top floor
## (a balcony over the well), the roof; the gravity circle in the hall's floor
func _tower() -> void:
	block(ISLE[0], LAVA, -ISLE[2], ISLE[1], 0.0, ISLE[2], C_ROCK)
	slab(ISLE[0] + 0.3, 0.0, -ISLE[2] + 0.3, ISLE[1] - 0.3, 0.05, ISLE[2] - 0.3, C_ASH2)
	var k := _k(TC.x); var cx := TC.x; var cz := TC.y
	# the round wall: 48 pieces, the door left open to the west, the top floor's door to the east, windows of fire
	var n := 48
	for i in n:
		var a0 := i * TAU / n; var a1 := (i + 1) * TAU / n; var am := rad_to_deg((a0 + a1) * 0.5)
		var door := absf(fposmod(am - DOOR_A + 180.0, 360.0) - 180.0) < 6.0
		var exit_ := absf(fposmod(am - EXIT_A + 180.0, 360.0) - 180.0) < 7.0
		var y_lo := 5.0 if door else 0.0
		ring_piece(k, TC, T_IN, T_OUT, a0, a1, y_lo, T_TOP if exit_ else T_ROOF, C_OBS if i % 2 == 0 else C_OBS2, C_OBS2)
		if exit_: ring_piece(k, TC, T_IN, T_OUT, a0, a1, T_TOP + 5.0, T_ROOF, C_OBS2, C_OBS2)
		var mid := (a0 + a1) * 0.5
		if i % 6 == 3 and not door and not exit_:
			for wy: float in [8.0, 18.0]: glow.box(0.08, 2.2, 0.7, cx + cos(mid) * (T_OUT + 0.02), wy, cz + sin(mid) * (T_OUT + 0.02), C_EMBER.darkened(0.35), -mid)
	for i in 96:   # (what stops you: a ring of close-set boxes in the wall's thickness, the two ways through left open)
		var am := (i + 0.5) * 360.0 / 96.0; var a := deg_to_rad(am); var px := cx + cos(a) * (T_IN + 0.6); var pz := cz + sin(a) * (T_IN + 0.6)
		var door := absf(fposmod(am - DOOR_A + 180.0, 360.0) - 180.0) < 6.0
		var exit_ := absf(fposmod(am - EXIT_A + 180.0, 360.0) - 180.0) < 7.0
		if door: Phys.add_collider(px - 0.62, 5.0, pz - 0.62, px + 0.62, T_ROOF, pz + 0.62, "concrete")
		elif exit_: Phys.add_collider(px - 0.62, 0.0, pz - 0.62, px + 0.62, T_TOP, pz + 0.62, "concrete"); Phys.add_collider(px - 0.62, T_TOP + 5.0, pz - 0.62, px + 0.62, T_ROOF, pz + 0.62, "concrete")
		else: Phys.add_collider(px - 0.62, 0.0, pz - 0.62, px + 0.62, T_ROOF, pz + 0.62, "concrete")
	# the hall's floor, and its runes round the gravity circle
	k.disc(cx, 0.06, cz, T_IN, C_OBS3, 40)
	glow.disc(CORE_AT.x, 0.08, CORE_AT.z, 2.6, C_VIOLET.darkened(0.45), 24, 2.35); glow.disc(CORE_AT.x, 0.08, CORE_AT.z, 1.4, C_VIOLET.darkened(0.55), 6, 1.2)
	# the stair: STEPS steps round the inner wall from ST_A0 to ST_END, each 0.3 up; solid at its foot, a slab above
	var da := deg_to_rad(SPIRAL) / STEPS
	for j in STEPS:
		var a0 := deg_to_rad(ST_A0) + j * da; var a1 := a0 + da; var top := T_TOP * (j + 1) / float(STEPS); var solid := top < 3.2
		ring_piece(k, TC, T_STAIR, T_IN, a0, a1, 0.0 if solid else top - 0.55, top, C_OBS3 if j % 2 == 0 else C_ASH2, C_OBS2)
		ring_solid(TC, T_STAIR, T_IN, (a0 + a1) * 0.5, 0.0 if solid else top - 0.55, top)
		# the low wall along its inner edge (the well side): knee high, broken off near the top where the balcony is
		if j % 2 == 0 and top < T_TOP - 1.0:
			var am := (a0 + a1) * 0.5; var px := cx + cos(am) * (T_STAIR + 0.18); var pz := cz + sin(am) * (T_STAIR + 0.18)
			k.box(0.3, 0.55, 1.7, px, top + 0.27, pz, C_OBS2, -am); Phys.add_collider(px - 0.18, top, pz - 0.18, px + 0.18, top + 0.55, pz + 0.18, "concrete")
	# the shelves on the outer wall: carved stone sticking out a metre above the steps, every 36 degrees (the fire wave goes
	# by under whoever stands on one)
	var u := 18.0
	while u < SPIRAL - 20.0:
		var a := deg_to_rad(ST_A0 + u); var sy := stair_y_at(ST_A0 + u); var px := cx + cos(a) * 14.25; var pz := cz + sin(a) * 14.25
		k.box(1.1, 0.35, 1.5, px, sy + 0.85, pz, C_OBS3, -a); k.box(0.9, 0.7, 0.4, cx + cos(a) * 14.6, sy + 0.4, cz + sin(a) * 14.6, C_OBS2, -a)
		Phys.add_collider(px - 0.55, sy + 0.68, pz - 0.55, px + 0.55, sy + 1.02, pz + 0.55, "concrete")
		ledges.push_back({"u": u, "y": sy + 1.02, "at": Vector3(px, sy + 1.02, pz)})
		u += 36.0
	# the top floor: round from the balcony's edge to the wall, open over the stair's last stretch (headroom)
	var gaps := [ST_END - 56.0, ST_END + 1.0]
	var tn := 60
	for i in tn:
		var a0 := i * TAU / tn; var a1 := (i + 1) * TAU / tn; var am := rad_to_deg((a0 + a1) * 0.5)
		var over: bool = fposmod(am - float(gaps[0]), 360.0) < float(gaps[1]) - float(gaps[0])
		var r0 := T_STAIR if over else T_BAL
		if over: continue
		ring_piece(k, TC, r0, T_IN, a0, a1, T_TOP - 0.5, T_TOP, C_OBS3 if i % 2 == 0 else C_OBS2, C_OBS2)
		ring_solid(TC, r0, T_IN, (a0 + a1) * 0.5, T_TOP - 0.5, T_TOP, 1.5)
		# the balcony's rail over the well (Karnok breaks it when he comes down)
		var px := cx + cos((a0 + a1) * 0.5) * (T_BAL + 0.2); var pz := cz + sin((a0 + a1) * 0.5) * (T_BAL + 0.2)
		k.box(0.3, 1.0, 1.0, px, T_TOP + 0.5, pz, C_OBS2, -(a0 + a1) * 0.5); Phys.add_collider(px - 0.2, T_TOP, pz - 0.2, px + 0.2, T_TOP + 1.0, pz + 0.2, "concrete")
	# the roof: a cone over all, lit from within by the well's fire; the well's fire itself, low in the hall
	k.cyl(cx, T_ROOF, cz, T_OUT + 0.6, 1.0, 9.0, C_OBS, 24, true)
	k.disc(cx, T_ROOF, cz, T_OUT + 0.6, C_OBS2, 24, 0.0, 0.0, TAU, false)
	for i in 12:
		var a := i * TAU / 12.0; glow.box(0.08, 0.08, 4.0, cx + cos(a) * 6.0, T_ROOF - 0.2, cz + sin(a) * 6.0, C_RUNE.darkened(0.4), -a + PI / 2.0)
	for q: Array in [[0.0, 6.0], [120.0, 14.0], [240.0, 20.0]]: world.lamps.push_back({"x": cx + cos(deg_to_rad(q[0])) * 6.0, "y": q[1], "z": cz + sin(deg_to_rad(q[0])) * 6.0})

## the high bridge from the top floor's door to the sky altar: stone, walled, steps down at its end
func _high() -> void:
	block(HB_X0, T_TOP - 1.2, -HB_W, HB_X1, T_TOP, HB_W, C_OBS3)
	for s: float in [-1.0, 1.0]: block(HB_X0, T_TOP, s * HB_W - (0.3 if s > 0.0 else 0.0), HB_X1, T_TOP + 1.1, s * HB_W + (0.0 if s > 0.0 else 0.3), C_OBS2)
	stairs_x(HB_X1, T_TOP, AC.x - AR + 1.0, A_Y, -HB_W, HB_W, C_OBS3, A_Y - 1.4)
	for s: float in [-1.0, 1.0]:
		var n := 14
		for i in n:
			var x0 := lerpf(HB_X1, AC.x - AR + 1.0, float(i) / n); var x1 := lerpf(HB_X1, AC.x - AR + 1.0, float(i + 1) / n); var yy := lerpf(T_TOP, A_Y, float(i + 1) / n)
			block(x0, yy, s * HB_W - (0.3 if s > 0.0 else 0.0), x1, yy + 1.1, s * HB_W + (0.0 if s > 0.0 else 0.3), C_OBS2)
	# its arches underneath, down to the lava
	for ax: float in [104.0, 112.0, 120.0]:
		_k(ax).cyl(ax, LAVA, 0.0, 1.6, 1.3, T_TOP - 1.2 - LAVA, C_ROCK2, 8, false)

## 4, the sky altar: a round floor on a pillar of rock, its rim (which falls in the last phase), six obsidian pillars, the
## two cooling circles and the two gravity circles, the chain stakes round the edge, the great sigil in the middle
func _altar() -> void:
	var k := _k(AC.x); var cx := AC.x; var cz := AC.y
	k.cyl(cx, LAVA, cz, AR - 3.0, AR + 1.0, A_Y - 1.0 - LAVA, C_ROCK, 24, false)
	# the inner floor (it stays): boxes in a ring of cells to stand on, drawn as a disc
	k.disc(cx, A_Y + 0.02, cz, AR_SMALL, C_OBS2, 40)
	var cell := 2.0; var r := cell * 0.5
	while r < AR_SMALL:
		var n := maxi(6, int(TAU * r / cell))
		for i in n:
			var a := i * TAU / n; var x := cx + cos(a) * r; var z := cz + sin(a) * r
			Phys.add_collider(x - cell * 0.6, A_Y - 1.0, z - cell * 0.6, x + cell * 0.6, A_Y, z + cell * 0.6, "concrete")
		r += cell * 0.84
	wall(cx - 1.2, A_Y - 1.0, cz - 1.2, cx + 1.2, A_Y, cz + 1.2)
	# the rim, from AR_SMALL to AR: its own boxes and mesh (it falls away in the last phase)
	var rk := MeshKit.new(); var boxes: Array = []
	var rn := 48
	for i in rn:
		var a0 := i * TAU / rn; var a1 := (i + 1) * TAU / rn
		ring_piece(rk, Vector2.ZERO, AR_SMALL, AR, a0, a1, A_Y - 1.0, A_Y, C_OBS3 if i % 2 == 0 else C_OBS2, C_OBS2)
		# the parapet round the edge, open to the west where the steps come up
		var am := rad_to_deg((a0 + a1) * 0.5)
		if absf(fposmod(am - 180.0 + 180.0, 360.0) - 180.0) > 8.0:
			var px := cos((a0 + a1) * 0.5) * (AR - 0.35); var pz := sin((a0 + a1) * 0.5) * (AR - 0.35)
			rk.box(0.5, 1.2, 3.5, px, A_Y + 0.6, pz, C_OBS, -(a0 + a1) * 0.5)
			boxes.push_back(Phys.add_collider(cx + px - 0.4, A_Y, cz + pz - 0.4, cx + px + 0.4, A_Y + 1.2, cz + pz + 0.4, "concrete"))
			if i % 4 == 0:   # spikes standing out from the rim
				rk.cyl(px * 1.03, A_Y + 1.2, pz * 1.03, 0.4, 0.0, 3.2, C_OBS, 5, false)
	for i in 112: boxes.append_array(ring_solid(AC, AR_SMALL - 0.6, AR - 0.2, (i + 0.5) * TAU / 112.0, A_Y - 1.0, A_Y, 2.0))
	for deg: float in [45.0, 135.0, 225.0, 315.0]:   # the chain stakes, on the rim (they go with it)
		var p := altar_point(deg, STAKE_R); stakes.push_back(p)
		rk.cyl(p.x - cx, A_Y, p.z - cz, 0.35, 0.25, 1.8, C_IRON, 6, true); boxes.push_back(Phys.add_collider(p.x - 0.35, A_Y, p.z - 0.35, p.x + 0.35, A_Y + 1.8, p.z + 0.35, "concrete"))
	var rnode := rk.node(_mat_lit, G); rnode.position = Vector3(cx, 0, cz)
	rim.push_back({"boxes": boxes, "node": rnode})
	# the parapet that stands once the rim is gone (built now, its boxes only added then: see collapse)
	# the sigil in the middle: two rings and a star of red runes
	glow.disc(cx, A_Y + 0.05, cz, 10.0, C_RUNE.darkened(0.35), 48, 9.6); glow.disc(cx, A_Y + 0.05, cz, 6.4, C_RUNE.darkened(0.45), 40, 6.1)
	for i in 5:
		var a := -PI / 2.0 + i * TAU / 5.0; var b := -PI / 2.0 + (i + 2) * TAU / 5.0
		glow.strip(Vector3(cx + cos(a) * 9.6, A_Y + 0.05, cz + sin(a) * 9.6), Vector3(cx + cos(b) * 9.6, A_Y + 0.05, cz + sin(b) * 9.6), 0.18, C_RUNE.darkened(0.3))
	# the six pillars of obsidian runes (cover; three fall in the second phase, the rest in the third)
	for i in 6:
		var a := deg_to_rad(30.0 + i * 60.0); var px := cx + cos(a) * PILLAR_R; var pz := cz + sin(a) * PILLAR_R
		var pk := MeshKit.new(); pk.box(2.2, 7.0, 2.2, 0, 3.5, 0, C_OBS, -a); pk.cyl(0, 7.0, 0, 1.2, 0.0, 1.6, C_OBS2, 4, false)
		for j in 3: pk.box(1.0, 0.14, 0.02, cos(a + PI) * 1.12, 2.0 + j * 1.6, sin(a + PI) * 1.12, C_RUNE, -a + PI / 2.0)
		var pn := pk.node(_mat_lit, G); pn.position = Vector3(px, A_Y, pz)
		var pb := Phys.add_collider(px - 1.1, A_Y, pz - 1.1, px + 1.1, A_Y + 7.0, pz + 1.1, "concrete")
		pillars.push_back({"i": i, "a": a, "at": Vector3(px, A_Y, pz), "box": pb, "node": pn, "up": true})
	# the cooling circles (north and south) and the gravity circles (east and west of the middle, on the rim's inside)
	for deg: float in [90.0, 270.0]:
		var p := altar_point(deg, COOL_R); cools.push_back(p)
		glow.disc(p.x, A_Y + 0.06, p.z, 2.6, C_COLD, 28, 2.35); glow.disc(p.x, A_Y + 0.06, p.z, 1.3, C_COLD.darkened(0.3), 6, 1.1)
		world.lamps.push_back({"x": p.x, "y": A_Y + 1.6, "z": p.z})
	for deg: float in [0.0, 180.0]:
		var p := altar_point(deg, 15.0 if deg == 180.0 else 15.0); pads.push_back(p)
		glow.disc(p.x, A_Y + 0.06, p.z, 2.2, C_VIOLET, 28, 1.95); glow.disc(p.x, A_Y + 0.06, p.z, 1.0, C_VIOLET.darkened(0.3), 6, 0.8)
	for deg: float in [60.0, 150.0, 240.0, 330.0]: world.lamps.push_back({"x": altar_point(deg, 22.0).x, "y": A_Y + 3.0, "z": altar_point(deg, 22.0).z})

## the rim falls into the lava: its boxes and its mesh go, a new parapet stands at the inner floor's edge
func collapse() -> void:
	if rim_down: return
	rim_down = true
	for q: Dictionary in rim:
		for b: Phys.Box in q.boxes: Phys.remove_collider(b)
		if is_instance_valid(q.node): (q.node as Node3D).queue_free()
	var pk := MeshKit.new()
	for i in 40:
		var a0 := i * TAU / 40.0; var a1 := (i + 1) * TAU / 40.0; var am := (a0 + a1) * 0.5
		var px := AC.x + cos(am) * (AR_SMALL - 0.3); var pz := AC.y + sin(am) * (AR_SMALL - 0.3)
		pk.box(0.45, 1.1, 3.3, px, A_Y + 0.55, pz, C_OBS3.lightened(0.05), -am)
		Phys.add_collider(px - 0.35, A_Y, pz - 0.35, px + 0.35, A_Y + 1.1, pz + 0.35, "concrete")
	pk.node(_mat_lit, G)
	Phys.index_colliders()

## a pillar shatters (Baal's wings, the floor's slam)
func break_pillar(p: Dictionary) -> void:
	if not p.up: return
	p.up = false; Phys.remove_collider(p.box)
	if is_instance_valid(p.node): (p.node as Node3D).queue_free()
	var bk := MeshKit.new()   # (its stump and broken pieces lying about)
	bk.box(2.2, 1.2, 2.2, 0, 0.6, 0, C_OBS2, -float(p.a))
	for j in 4: bk.box(0.9, 0.5, 1.3, cos(j * 1.7) * 2.0, 0.25, sin(j * 1.7) * 2.0, C_OBS, j * 0.8)
	var bn := bk.node(_mat_lit, G); bn.position = p.at
	Phys.add_collider(p.at.x - 1.1, A_Y, p.at.z - 1.1, p.at.x + 1.1, A_Y + 1.2, p.at.z + 1.1, "concrete")
	Phys.index_colliders()

## the lava: a sheet of fire under it all east of the cliff, lit from within, its crust moving
func _lava() -> void:
	var m := MeshKit.new(); var step := 12.0
	var x := CLIFF; var i := 0
	while x < X1:
		var z := -WZ; var j := 0
		while z < WZ:
			var c := C_LAVA.lerp(C_LAVA2, fposmod(i * 0.37 + j * 0.61, 1.0) * 0.6).lerp(C_EMBER, fposmod(i * 0.53 + j * 0.29, 1.0) * 0.4)
			m.quad(Vector3(x, LAVA + 0.3, z), Vector3(x + step, LAVA + 0.3, z), Vector3(x + step, LAVA + 0.3, z + step), Vector3(x, LAVA + 0.3, z + step), c, Vector3.UP)
			z += step; j += 1
		x += step; i += 1
	# the crust: dark rafts on it
	for q in 60:
		var px := CLIFF + 4.0 + fposmod(q * 41.3, X1 - CLIFF - 8.0); var pz := -WZ + 2.0 + fposmod(q * 17.9, 2.0 * WZ - 4.0); var r := 1.2 + fposmod(q * 0.61, 2.6)
		m.disc(px, LAVA + 0.33, pz, r, C_ROCK2.darkened(0.3), 7)
	var mat := Gfx.unlit(Color.WHITE, false); mat.vertex_color_use_as_albedo = true
	lava_n = m.node(mat, G); lava_n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for q in 14: world.lamps.push_back({"x": CLIFF + 8.0 + q * 16.0, "y": LAVA + 3.0, "z": 12.0 if q % 2 == 0 else -12.0})

# ---------------- who stands where ----------------
## the demons' posts by section (sec 1 the gate, 2 the bridge, 3 the tower; the bosses: ModeRaid puts them)
func _posts() -> void:
	# the gate's guards, behind the rubble and on the broken walls
	for p: Array in [[-104.0, -11.0], [-102.0, 9.5], [-94.0, -19.0], [-92.0, 4.0], [-90.0, 17.0], [-82.0, -9.0], [-80.0, 11.0], [-70.0, 5.0], [-68.0, -6.0], [-64.0, 17.0]]:
		post("guard", p[0], 0.0, p[1], 1)
	post("guard", -73.5, 0.0, -18.0, 1); post("guard", -86.0, 0.0, 0.0, 1)
	# the bridge: snipers on the pillars, guards on the landing, the beast at the far end
	for p: Array in [[-30.0, -11.0], [16.0, 11.5], [40.0, -11.0], [52.0, 10.0]]: post("sniper", p[0], 6.2, p[1], 2, {"perch": true})
	post("guard", -2.0, 0.0, -4.0, 2); post("guard", 2.0, 0.0, 4.0, 2); post("guard", 0.0, 0.0, 0.0, 2)
	post("beast", 46.0, 0.0, 0.0, 2)
	# the tower: its defenders up the stair (they shoot down at you), Karnok on the balcony (ModeRaid)
	for u: float in [250.0, 330.0, 410.0, 480.0]:
		var q := stair_point(u, 13.4); post("defender", q.x, q.y, q.z, 3, {"perch": true})
	for deg: float in [150.0, 210.0]:
		var a := deg_to_rad(deg); post("defender", TC.x + cos(a) * 12.0, T_TOP, TC.y + sin(a) * 12.0, 3, {"perch": true})

## the seals: a wall of red light across each way on, standing till its section is cleared
func make_seals() -> void:
	for s: Array in SEALS:
		var b := Phys.add_collider(s[0], s[3], -s[2], s[1], s[4], s[2], "concrete")
		var m := MeshKit.new(); var xm := (float(s[0]) + float(s[1])) * 0.5
		m.quad(Vector3(xm, s[3], -s[2]), Vector3(xm, s[3], s[2]), Vector3(xm, s[4], s[2]), Vector3(xm, s[4], -s[2]), Color(1.0, 0.15, 0.2, 0.42), Vector3(1, 0, 0))
		for i in 5:
			var yy := lerpf(float(s[3]) + 0.6, float(s[4]) - 0.4, i / 4.0)
			m.strip(Vector3(xm + 0.02, yy, -s[2]), Vector3(xm + 0.02, yy, s[2]), 0.09, Color(1.0, 0.35, 0.3, 0.85), false)
		var mat := Gfx.unlit(Color.WHITE, false); mat.vertex_color_use_as_albedo = true; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var n := m.node(Gfx.see_through(mat), G); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seals.push_back({"box": b, "node": n, "sec": int(s[5]), "open": false})
	Phys.index_colliders()

## a section cleared: its seal goes
func open_seal(sec: int) -> bool:
	var did := false
	for q: Dictionary in seals:
		if int(q.sec) != sec or q.open: continue
		q.open = true; did = true; Phys.remove_collider(q.box)
		if is_instance_valid(q.node): (q.node as Node3D).queue_free()
	if did: Phys.index_colliders()
	return did

func seal_open(sec: int) -> bool:
	for q: Dictionary in seals:
		if int(q.sec) == sec: return q.open
	return true

## which section a place is in (by how far east it is, and up the tower)
static func section_of(p: Vector3) -> int:
	if p.x < GATE_X0 - 4.0: return 0
	if p.x < GATE_X1 + 1.0: return 1
	if p.x < 64.0: return 2
	if p.x < HB_X0 + 0.5 and not (p.y > T_TOP - 1.0 and p.x > TC.x + T_IN - 1.0): return 3
	return 4

## the way the party walks, as waypoints for the others (RealmAI): the path from the camp to the altar, the stair as a chain
func graph_nodes() -> Dictionary:
	var out := {}
	var line := [[-176.0, 0.0], [-166.0, 0.0], [-156.0, 3.0], [-144.0, 0.0], [-132.0, 0.0], [GATE_X0 - 3.0, 0.0], [GATE_X0 + 3.0, 0.0], [-108.0, 0.0], [-100.0, -4.0], [-98.0, 12.0], [-88.0, -12.0], [-87.0, 0.0],
		[-78.0, 4.0], [-76.0, -18.0], [-70.0, 12.0], [-64.0, 0.0], [GATE_X1 - 3.0, 0.0], [GATE_X1 + 3.0, 0.0], [-50.0, 0.0], [CLIFF + 2.0, 0.0]]
	for i in line.size(): out["w%02d" % i] = Vector3(line[i][0], 0.0, line[i][1])
	var x := CLIFF + 6.0; var i2 := 0
	while x < BR_X1 - 1.0:
		out["b%02d" % i2] = Vector3(x, 0.0, 0.0); x += 6.0; i2 += 1
	out["mid_n"] = Vector3(0.0, 0.0, -5.0); out["mid_s"] = Vector3(0.0, 0.0, 5.0)
	out["isle_w"] = Vector3(BR_X1 + 1.0, 0.0, 0.0); out["door"] = Vector3(TC.x - T_OUT - 0.6, 0.0, 0.0); out["hall_w"] = Vector3(TC.x - 10.0, 0.0, 0.0)
	out["hall_c"] = Vector3(TC.x, 0.0, 0.0); out["hall_s"] = Vector3(TC.x, 0.0, 8.0); out["hall_n"] = Vector3(TC.x, 0.0, -8.0)
	var u := 2.0; var k := 0
	while u < SPIRAL:
		out["s%02d" % k] = stair_point(u, 13.0); u += 12.0; k += 1
	out["s_top"] = stair_point(SPIRAL - 2.0, 13.0) + Vector3(0, 0, 0)
	for deg: float in [320.0, 345.0, 10.0, 40.0, 70.0, 100.0, 130.0, 160.0, 190.0, 220.0]:
		var a := deg_to_rad(deg); out["top_%d" % int(deg)] = Vector3(TC.x + cos(a) * 12.0, T_TOP, TC.y + sin(a) * 12.0)
	out["exit"] = Vector3(TC.x + T_OUT + 0.8, T_TOP, 0.0); out["hb_e"] = Vector3(HB_X1 - 1.0, T_TOP, 0.0); out["hb_foot"] = Vector3(AC.x - AR + 2.5, A_Y, 0.0)
	for deg in range(0, 360, 30):
		out["ar_%d" % deg] = altar_point(float(deg), 18.5); out["ai_%d" % deg] = altar_point(float(deg), 11.0)
	out["ar_c"] = Vector3(AC.x, A_Y, AC.y)
	return out

func graph_edges() -> Array:
	var e := []
	var w := []
	for i in 20: w.push_back("w%02d" % i)
	for i in w.size() - 1: e.push_back([w[i], w[i + 1]])
	e.push_back(["w08", "w10"]); e.push_back(["w09", "w11"]); e.push_back(["w11", "w13"]); e.push_back(["w12", "w14"]); e.push_back(["w13", "w15"])
	var b := []
	var x := CLIFF + 6.0; var i2 := 0
	while x < BR_X1 - 1.0: b.push_back("b%02d" % i2); x += 6.0; i2 += 1
	e.push_back(["w19", b[0]])
	for i in b.size() - 1: e.push_back([b[i], b[i + 1]])
	var nodes := graph_nodes()
	for q: String in b:
		var p: Vector3 = nodes[q]
		if absf(p.x) < 4.0: e.push_back([q, "mid_n"]); e.push_back([q, "mid_s"])
	e.push_back([b[b.size() - 1], "isle_w"]); e.push_back(["isle_w", "door"]); e.push_back(["door", "hall_w"]); e.push_back(["hall_w", "hall_c"]); e.push_back(["hall_c", "hall_s"]); e.push_back(["hall_c", "hall_n"])
	e.push_back(["hall_w", "hall_s"]); e.push_back(["hall_w", "hall_n"])
	var s := []
	var u := 2.0
	while u < SPIRAL: s.push_back("s%02d" % s.size()); u += 12.0
	e.push_back(["hall_s", s[0]]); e.push_back(["hall_n", s[0]]); e.push_back(["hall_c", s[0]])
	for i in s.size() - 1: e.push_back([s[i], s[i + 1]])
	e.push_back([s[s.size() - 1], "s_top"])
	var tops := ["top_320", "top_345", "top_10", "top_40", "top_70", "top_100", "top_130", "top_160", "top_190", "top_220"]
	e.push_back(["s_top", "top_320"])
	for i in tops.size() - 1: e.push_back([tops[i], tops[i + 1]])
	e.push_back(["top_345", "exit"]); e.push_back(["top_10", "exit"]); e.push_back(["exit", "hb_e"]); e.push_back(["hb_e", "hb_foot"]); e.push_back(["hb_foot", "ar_180"])
	for deg in range(0, 360, 30):
		e.push_back(["ar_%d" % deg, "ar_%d" % ((deg + 30) % 360)]); e.push_back(["ar_%d" % deg, "ai_%d" % deg]); e.push_back(["ai_%d" % deg, "ar_c"])
	return e

## where Karnok stands on the balcony, looking down the well at the stair
func balcony_at(deg := 120.0) -> Vector3:
	var a := deg_to_rad(deg); return Vector3(TC.x + cos(a) * (T_BAL + 1.2), T_TOP, TC.y + sin(a) * (T_BAL + 1.2))

# ---------------- each frame ----------------
func update(dt: float, _p: Player) -> void:
	t += dt
	if lava_n != null and is_instance_valid(lava_n):
		_lava_t += dt
		lava_n.position.y = sin(_lava_t * 0.6) * 0.12
