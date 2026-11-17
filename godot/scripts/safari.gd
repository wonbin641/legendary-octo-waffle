class_name Safari
extends RefCounted
## Stage 3-1: a very wide savanna with a watchtower in the middle. Five minutes of the animals living wild, then every one of them
## comes for the tower. Ported from src/04d_savanna.js, src/04h_tower.js and src/07i_safari.js: every seeded number is drawn in the
## same order, so trees, rocks, mounds, crates and animals are where the browser game has them.

const T_STAMPEDE := 300.0   # five minutes
const ROSTER := [["zebra", 12], ["buffalo", 13], ["hippo", 12], ["rhino", 12], ["cheetah", 12], ["tiger", 12], ["lionM", 14], ["giraffe", 3], ["elephant", 4], ["gorilla", 6]]
# the safari's lowland gorillas: the lab's gorilla build and fists, half as hard like every other animal here
const GORILLA := {"kong": true, "hp": 1000, "scale": 1.15, "dmgMul": 0.5, "name": "로랜드고릴라"}
const TOWER := {"hp": 10000.0, "ph": 3.84, "half": 2.6, "base": 3.2, "step": 0.48, "steps": 8}
const WATER := {"x": 62.0, "z": -48.0, "r": 22.0}
# at the tower: what each kind does to it, and how often. rams back off and run at it; the rest bite and claw at the planks
const SIEGE := {"buffalo": {"dmg": 20.0, "cd": [1.6, 2.2], "ram": true}, "rhino": {"dmg": 24.0, "cd": [1.8, 2.4], "ram": true}, "elephant": {"dmg": 52.0, "cd": [2.2, 2.8], "ram": true},
	"hippo": {"dmg": 14.0, "cd": [1.6, 2.2]}, "lionM": {"dmg": 10.0, "cd": [1.2, 1.6]}, "tiger": {"dmg": 10.0, "cd": [1.1, 1.5]}, "cheetah": {"dmg": 8.0, "cd": [1.0, 1.3]}, "gorilla": {"dmg": 9.0, "cd": [1.4, 2.0]}}

var t := 0.0
var stampede := false
var warned := 0
var player: Player
var game = null
var enemies = null
var fx: Fx = null
# the tower
var standing := true
var hp := 10000.0
var on := false            # you are up on it (or high on its steps)
var cols: Array = []
var slots: Array = []      # places along its foot: {x, z, nx, nz, owner, t}
var marks := {}
var shake := 0.0
var fall_t := -1.0
var fall_dir := 1.0
var crack_t := 0.0
var hinted := false
var landed := false
var clock := 0.0
var outer: Node3D; var inner: Node3D
var roads: Array = []      # the dirt tracks and the acacias, for the map
var trees: Array = []

func left() -> float: return maxf(0.0, T_STAMPEDE - t)
func holds() -> bool: return standing and on

# ---- the browser game's canvases for the plain (drawn once, then kept) ----
static var _tx := {}
## dry grass: speckles, short strokes, darker patches (512 across, 110 times over the plain)
static func grass_tex() -> ImageTexture:
	if not _tx.has("grass"):
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8); img.fill(Color("8c874a"))
		Gfx.speckle(img, 9000, [Color("9a9352"), Color("7f7b42"), Color("a39a58"), Color("75723e"), Color("8a7a48"), Color("6f7a3e")], 2.2)
		var ink := [Color(70 / 255.0, 64 / 255.0, 30 / 255.0, 0.5), Color(190 / 255.0, 175 / 255.0, 110 / 255.0, 0.45), Color(95 / 255.0, 110 / 255.0, 50 / 255.0, 0.45)]
		for i in 1400: var x := randf() * 512; var y := randf() * 512; Gfx.fline(img, Vector2(x, y), Vector2(x + randf_range(-3, 3), y - randf_range(4, 9)), ink[randi() % 3])
		for i in 16: Gfx.fellipse(img, randf() * 512, randf() * 512, randf_range(20, 70), randf_range(10, 40), randf_range(0, 3), Color(110 / 255.0, 85 / 255.0, 50 / 255.0, randf_range(0.08, 0.2)))
		_tx.grass = Gfx.tex(img)
	return _tx.grass
## a dirt track with two wheel ruts along it
static func dirt_tex() -> ImageTexture:
	if not _tx.has("dirt"):
		var img := Image.create(128, 256, false, Image.FORMAT_RGBA8); img.fill(Color("8a6a45")); Gfx.speckle(img, 2500, [Color("94744c"), Color("7c5e3c"), Color("a07e55"), Color("6f5435")], 2)
		var rut := Color(60 / 255.0, 44 / 255.0, 28 / 255.0, 0.35); Gfx.frect(img, 28, 0, 14, 256, rut); Gfx.frect(img, 86, 0, 14, 256, rut)
		_tx.dirt = Gfx.tex(img)
	return _tx.dirt
## the park's sign
static func sign_tex() -> ImageTexture:
	if not _tx.has("sign"):
		var img := Image.create(512, 256, false, Image.FORMAT_RGBA8); img.fill(Color("e8d9a8")); Gfx.frect(img, 0, 0, 512, 16, Color("6a3a1e")); Gfx.frect(img, 0, 240, 512, 16, Color("6a3a1e"))
		Gfx.text(img, "제3구역 맹수 사파리", load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"), 62, 256, 112, "center", "alphabetic", Color("3a2412"))
		Gfx.text(img, "차량 밖으로 나가지 마세요", load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"), 30, 256, 186, "center", "alphabetic", Color("8a1e14"))
		_tx.sign = Gfx.tex(img)
	return _tx.sign
## the tower's boards: eight planks side by side with dark seams, grain and knots (once over each face of a box)
static func plank_tex() -> ImageTexture:
	if not _tx.has("plank"):
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color("7d5b3a"))
		var cols := [Color("86613e"), Color("74533a"), Color("8c6943"), Color("6e4f33")]
		for i in 8: Gfx.frect(img, i * 32 + 1, 0, 30, 256, cols[randi() % 4]); Gfx.frect(img, i * 32, 0, 2, 256, Color(30 / 255.0, 18 / 255.0, 8 / 255.0, 0.55))
		Gfx.speckle(img, 1400, [Color(60 / 255.0, 40 / 255.0, 20 / 255.0, 0.35), Color(150 / 255.0, 110 / 255.0, 70 / 255.0, 0.25)], 2)
		for i in 16: var kr := randf_range(1.5, 3); Gfx.fellipse(img, randf_range(0, 256), randf_range(0, 256), kr, kr, 0.0, Color(40 / 255.0, 26 / 255.0, 12 / 255.0, 0.6))
		_tx.plank = Gfx.tex(img)
	return _tx.plank
## the tower's name board on its railing
static func tower_sign_tex() -> ImageTexture:
	if not _tx.has("tsign"):
		var img := Image.create(256, 96, false, Image.FORMAT_RGBA8); img.fill(Color("e6d6a6")); Gfx.frect(img, 0, 0, 256, 8, Color("6a3a1e")); Gfx.frect(img, 0, 88, 256, 8, Color("6a3a1e"))
		Gfx.text(img, "감시탑", load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"), 46, 128, 50, "center", "middle", Color("3a2412"))
		_tx.tsign = Gfx.tex(img)
	return _tx.tsign
## boxes in one mesh, every face textured as three.js's BoxGeometry, its picture scaled (su across, sv up from the bottom).
## part: [sx, sy, sz, x, y, z, su, sv]
static func _plank_boxes(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var a := Gfx.box(Vector3(p[0], p[1], p[2])).surface_get_arrays(0); var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		for i in uvs.size(): uvs[i] = Vector2(uvs[i].x * p[6], 1.0 - (1.0 - uvs[i].y) * p[7])
		a[Mesh.ARRAY_TEX_UV] = uvs; var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		st.append_from(m, 0, Transform3D(Basis.IDENTITY, Vector3(p[3], p[4], p[5])))
	return st.commit()
## tall dry grass: blades curving up from the foot of a see-through card
static func blade_tex() -> ImageTexture:
	if not _tx.has("blade"):
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
		var cols := [Color("c7b46a"), Color("a99b55"), Color("d8c47c"), Color("8f8a48"), Color("b8a35e")]
		for i in 46:
			var x := randf_range(8, 120); var top := randf_range(10, 60); var c: Color = cols[randi() % 5]; var lw := randf_range(1.5, 3)
			var p0 := Vector2(x, 128); var p1 := Vector2(x + randf_range(-6, 6), (128 + top) / 2); var p2 := Vector2(x + randf_range(-14, 14), top); var prev := p0
			for k in range(1, 13):   # (a quadratic curve, as a canvas quadraticCurveTo strokes it)
				var u := k / 12.0; var q := p0 * (1 - u) * (1 - u) + p1 * 2 * u * (1 - u) + p2 * u * u
				_blade_seg(img, prev, q, c, lw); prev = q
		# the clear texels take the blades' mean colour (still clear): the smaller copies a far tuft is drawn from then average
		# blades with blades, not with black. The browser game's are darkened that way, but there four-sample alpha-to-coverage
		# blends those edges into the ground; here they came out as near-black flecks
		var sum := Vector4.ZERO
		for y in 128:
			for x in 128: var o := img.get_pixel(x, y); sum += Vector4(o.r * o.a, o.g * o.a, o.b * o.a, o.a)
		var mean := Color(sum.x / sum.w, sum.y / sum.w, sum.z / sum.w, 0.0)
		for y in 128:
			for x in 128:
				if img.get_pixel(x, y).a == 0.0: img.set_pixel(x, y, mean)
		_tx.blade = Gfx.tex(img)
	return _tx.blade
static func _blade_seg(img: Image, a: Vector2, b: Vector2, c: Color, lw: float) -> void:   # a stroke on a clear picture: the colour itself, its coverage the alpha
	var ab := b - a; var L2 := maxf(ab.length_squared(), 1e-6); var m := lw / 2.0 + 1.0
	for py in range(maxi(0, int(floor(minf(a.y, b.y) - m))), mini(128, int(ceil(maxf(a.y, b.y) + m)))):
		for px in range(maxi(0, int(floor(minf(a.x, b.x) - m))), mini(128, int(ceil(maxf(a.x, b.x) + m)))):
			var q := Vector2(px + 0.5, py + 0.5); var t := clampf((q - a).dot(ab) / L2, 0.0, 1.0); var cov := clampf(lw / 2.0 + 0.5 - q.distance_to(a + ab * t), 0.0, 1.0)
			if cov <= 0.0: continue
			var o := img.get_pixel(px, py); var na := cov + o.a * (1.0 - cov)
			img.set_pixel(px, py, Color((c.r * cov + o.r * o.a * (1.0 - cov)) / na, (c.g * cov + o.g * o.a * (1.0 - cov)) / na, (c.b * cov + o.b * o.a * (1.0 - cov)) / na, na))

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	var gm := PlaneMesh.new(); gm.size = Vector2(1200, 1200); var ground := MeshInstance3D.new(); ground.mesh = gm
	var grm := Gfx.std(Color.WHITE, 0.97, 0.0, grass_tex()); grm.uv1_scale = Vector3(110, 110, 1); ground.material_override = grm; G.add_child(ground)
	var free := func(x: float, z: float, rad: float) -> bool:
		for b in Phys.colliders:
			if x + rad > b.minx and x - rad < b.maxx and z + rad > b.minz and z - rad < b.maxz: return false
		return true
	# dirt tracks: a wobbly loop and a cross road
	var road := []; var road_b := []
	for i in 73: var a := (i / 72.0) * TAU; var rr := 98.0 + sin(a * 3.0) * 12.0; road.push_back(Vector2(cos(a) * rr, sin(a) * rr))
	for i in 25: road_b.push_back(Vector2(sin(i * 0.5) * 8.0, -170.0 + i * 14.2))
	roads = [road, road_b]
	var near_road := func(x: float, z: float, d: float) -> bool:
		for line in [road, road_b]:
			for p: Vector2 in line:
				if Vector2(p.x - x, p.y - z).length() < d: return true
		return false
	var rv := PackedVector3Array(); var ruv := PackedVector2Array(); var rn := PackedVector3Array(); var ri := PackedInt32Array()
	for line in [road, road_b]:
		for i in line.size() - 1:
			# each piece as the browser game lays it: flat, then turned by -atan2(dx, dz), which tilts it the other way about its
			# middle (along dx, -dz), so the pieces zigzag apart rather than join up; kept as it looks there
			var p0: Vector2 = line[i]; var p1: Vector2 = line[i + 1]; var len := p0.distance_to(p1); var d0 := (p1 - p0) / len
			var d := Vector2(d0.x, -d0.y); var n := Vector2(d0.y, d0.x)
			var c := (p0 + p1) / 2; var hl := (len + 0.6) / 2; var o := rv.size()
			for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:   # (6 wide, its picture 12 m long: the ruts run along it)
				var pp: Vector2 = c + n * 3.0 * q[0] + d * hl * q[1]; rv.push_back(Vector3(pp.x, 0.015, pp.y)); ruv.push_back(Vector2((q[0] + 1) / 2.0, (q[1] + 1) / 2.0 * len / 12.0)); rn.push_back(Vector3.UP)
			if (rv[o + 2] - rv[o]).cross(rv[o + 1] - rv[o]).y > 0.0: ri.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])   # (facing up: Godot winds front faces clockwise)
			else: ri.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	var ra := []; ra.resize(Mesh.ARRAY_MAX); ra[Mesh.ARRAY_VERTEX] = rv; ra[Mesh.ARRAY_NORMAL] = rn; ra[Mesh.ARRAY_TEX_UV] = ruv; ra[Mesh.ARRAY_INDEX] = ri
	var rmesh := ArrayMesh.new(); rmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ra)
	var roads_mi := MeshInstance3D.new(); roads_mi.name = "Roads"; roads_mi.mesh = rmesh; roads_mi.material_override = Gfx.std(Color.WHITE, 0.95, 0.0, dirt_tex()); G.add_child(roads_mi)
	# the waterhole where hippos wallow
	var wm := MeshInstance3D.new(); wm.name = "Water"; var wc := CylinderMesh.new(); wc.top_radius = WATER.r; wc.bottom_radius = WATER.r; wc.height = 0.02; wm.mesh = wc; wm.material_override = Gfx.std(World.lin("4a6457"), 0.12, 0.15); wm.position = Vector3(WATER.x, 0.05, WATER.z); G.add_child(wm); MoonShadow.no_receive(wm)
	var mud := MeshInstance3D.new(); var mc := CylinderMesh.new(); mc.top_radius = WATER.r + 7; mc.bottom_radius = WATER.r + 7; mc.height = 0.02; mud.mesh = mc; mud.material_override = Gfx.std(World.lin("6a4a30"), 0.9); mud.position = Vector3(WATER.x, 0.02, WATER.z); G.add_child(mud)
	# perimeter fence of the safari park
	var E := 178.0
	for q in [[0.0, -E - 0.5, 2 * E + 2, 1.0], [0.0, E + 0.5, 2 * E + 2, 1.0], [-E - 0.5, 0.0, 1.0, 2 * E + 2], [E + 0.5, 0.0, 1.0, 2 * E + 2]]:
		Phys.add_collider(q[0] - q[2] / 2, 0, q[1] - q[3] / 2, q[0] + q[2] / 2, 12, q[1] + q[3] / 2, "wood")
	var posts := []; var ft := -E
	while ft <= E:
		for q in [[ft, -E], [ft, E], [-E, ft], [E, ft]]: posts.push_back(Transform3D(Basis.IDENTITY, Vector3(q[0], 0.85, q[1])))
		ft += 6.0
	var pb := BoxMesh.new(); pb.size = Vector3(0.16, 1.7, 0.16); var pim := Gfx.multimesh(pb, posts); pim.name = "Posts"; pim.material_override = Gfx.std(World.lin("5a4636"), 0.9); G.add_child(pim); MoonShadow.no_receive(pim)
	var wire := []
	for y: float in [0.7, 1.4]: wire.append_array([[2 * E, 0.03, 0.03, 0, y, -E], [2 * E, 0.03, 0.03, 0, y, E], [0.03, 0.03, 2 * E, -E, y, 0], [0.03, 0.03, 2 * E, E, y, 0]])
	var wire_mi := MeshInstance3D.new(); wire_mi.name = "Wire"; wire_mi.mesh = Gfx.merge_boxes(wire); wire_mi.material_override = Gfx.unlit(World.lin("3a3a36")); G.add_child(wire_mi); MoonShadow.no_receive(wire_mi)
	_build_tower(G, 0.0, 0.0)
	var wood := Gfx.std(World.lin("7a5a3a"), 0.9)   # the park's sign, by where you start
	var sg := Node3D.new(); sg.position = Vector3(-9, 0, 13); sg.rotation.y = 0.35; G.add_child(sg)
	var board := MeshInstance3D.new(); board.name = "Sign"; board.mesh = Gfx.box(Vector3(3.2, 1.6, 0.1)); board.material_override = wood; board.position.y = 2.2; sg.add_child(board); MoonShadow.caster(board); MoonShadow.no_receive(board)
	var face := MeshInstance3D.new(); face.name = "SignFace"; var fq := QuadMesh.new(); fq.size = Vector2(3.2, 1.6); face.mesh = fq; face.material_override = Gfx.std(Color.WHITE, 0.8, 0.0, sign_tex()); face.position = Vector3(0, 2.2, 0.051); sg.add_child(face); MoonShadow.no_receive(face)
	var sposts := MeshInstance3D.new(); sposts.name = "SignPosts"; sposts.mesh = Gfx.merge_boxes([[0.14, 2.2, 0.14, -1.3, 1.1, 0], [0.14, 2.2, 0.14, 1.3, 1.1, 0]]); sposts.material_override = wood; sg.add_child(sposts); MoonShadow.no_receive(sposts)
	# acacia trees, kopje boulders, termite mounds, bushes
	trees = []; var tries := 0
	while trees.size() < 120 and tries < 2000:
		tries += 1; var x := R.rng(-170, 170); var z := R.rng(-170, 170)
		if Vector2(x, z - 10).length() < 16 or Vector2(x - WATER.x, z - WATER.z).length() < WATER.r + 8 or near_road.call(x, z, 5.0) or not free.call(x, z, 3.0): continue
		var h := R.rng(3.6, 6.2); var cr := R.rng(3.2, 5.5); trees.push_back([x, z, h, cr]); Phys.add_collider(x - 0.3, 0, z - 0.3, x + 0.3, h, z + 0.3, "wood")
	var tr_x := []; var cr_x := []
	for q in trees:
		var ry := R.next() * TAU
		tr_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(1, q[2], 1)), Vector3(q[0], q[2] / 2, q[1])))
		cr_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(q[3], q[3] * 0.26, q[3])), Vector3(q[0], q[2], q[1])))
	var tm := CylinderMesh.new(); tm.top_radius = 0.18; tm.bottom_radius = 0.3; tm.height = 1.0; tm.radial_segments = 6; tm.rings = 0
	var trunks := MeshInstance3D.new(); trunks.mesh = Gfx.bake(tm, tr_x); trunks.material_override = Gfx.std(World.lin("5a4636"), 0.95); G.add_child(trunks); MoonShadow.caster(trunks)
	var crowns := MeshInstance3D.new(); crowns.mesh = Gfx.bake(Gfx.arrays_mesh(Gfx.three_sphere(12, 6), 2.0), cr_x); crowns.material_override = Gfx.std(World.lin("4b5a2c"), 0.9); G.add_child(crowns); MoonShadow.caster(crowns)
	var rocks := []; var c := 0; tries = 0
	while c < 26 and tries < 600:
		tries += 1; var cx := R.rng(-165, 165); var cz := R.rng(-165, 165)
		if Vector2(cx, cz - 10).length() < 22 or Vector2(cx - WATER.x, cz - WATER.z).length() < WATER.r + 12 or near_road.call(cx, cz, 8.0) or not free.call(cx, cz, 6.0): continue
		c += 1; var n := 2 + int(floor(R.next() * 3))
		for k in n:
			var x := cx + R.rng(-4, 4); var z := cz + R.rng(-4, 4); var s := R.rng(1.2, 3.4); var sy := s * R.rng(0.6, 1)
			rocks.push_back([x, z, s, sy]); Phys.add_collider(x - s * 0.78, 0, z - s * 0.78, x + s * 0.78, sy * 0.95, z + s * 0.78, "concrete")
	var rk_x := []
	for q in rocks:
		var a := R.next(); var b := R.next() * TAU; var cc := R.next()
		rk_x.push_back(Transform3D(Basis.from_euler(Vector3(a, b, cc), EULER_ORDER_XYZ).scaled_local(Vector3(q[2], q[3], q[2])), Vector3(q[0], q[3] * 0.45, q[1])))
	var rim := MeshInstance3D.new(); rim.mesh = Gfx.bake_flat(Gfx.dodeca_tris(), rk_x); rim.material_override = Gfx.std(World.lin("8f8374"), 0.92); G.add_child(rim); MoonShadow.caster(rim)
	var mounds := []; tries = 0
	while mounds.size() < 34 and tries < 800:
		tries += 1; var x := R.rng(-170, 170); var z := R.rng(-170, 170)
		if Vector2(x, z - 10).length() < 14 or near_road.call(x, z, 4.0) or Vector2(x - WATER.x, z - WATER.z).length() < WATER.r + 6 or not free.call(x, z, 2.0): continue
		var h := R.rng(1.8, 3.2); mounds.push_back([x, z, h]); Phys.add_collider(x - 0.7, 0, z - 0.7, x + 0.7, h, z + 0.7, "concrete")
	var md_x := []
	for q in mounds: var ry := R.next() * TAU; md_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(0.95, q[2], 0.95)), Vector3(q[0], 0, q[1])))
	var mim := MeshInstance3D.new(); mim.mesh = Gfx.bake_flat(Gfx.cone_tris(7, 1.0, 1.0, 0.0), md_x); mim.material_override = Gfx.std(World.lin("9a5a3a"), 0.95); G.add_child(mim); MoonShadow.caster(mim)
	var bu_x := []
	for i in 260:
		var x := R.rng(-172, 172); var z := R.rng(-172, 172); var s := R.rng(0.6, 1.5); var ry := R.next() * TAU
		bu_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(s * 1.4, s * 0.75, s * 1.2)), Vector3(x, s * 0.35, z)))
	var bim := MeshInstance3D.new(); bim.mesh = Gfx.bake(Gfx.arrays_mesh(Gfx.three_sphere(8, 5), 2.0), bu_x); bim.material_override = Gfx.std(World.lin("55632f"), 0.95); G.add_child(bim)
	# tall dry grass tufts: three crossed cards each, the blades cut out of a picture
	var tu_x := []
	for i in 3200:
		var x := R.rng(-176, 176); var z := R.rng(-176, 176); var s := R.rng(0.7, 1.5); var ry := R.next() * TAU; var sy := s * R.rng(0.8, 1.3)
		tu_x.push_back(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(s, sy, s)), Vector3(x, 0, z)))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var cq := QuadMesh.new(); cq.size = Vector2(1.4, 1.0); st.append_from(cq, 0, Transform3D(Basis(Vector3.UP, k * PI / 3.0), Vector3(0, 0.5, 0)))
	var tim := Gfx.multimesh(st.commit(), tu_x); var tum := Gfx.std(Color.WHITE, 0.95, 0.0, blade_tex()); tum.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; tum.alpha_scissor_threshold = 0.3
	# no shadow falls on it, and the occlusion passes it by: the browser game's occlusion draws the cards into its depth picture
	# but leaves their blades unshaded and lets them shade the ground only a little (0.3); here they stay out of that picture
	# (seen by the main camera alone) and their marked pixels are left out when it is laid over
	tum.cull_mode = BaseMaterial3D.CULL_DISABLED; tum.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE; tum.alpha_antialiasing_edge = 0.0; MoonShadow.grass(tum); tim.layers = 1 << (Gfx.MAIN_ONLY - 1); tim.name = "Tufts"; tim.material_override = tum; tim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; G.add_child(tim)
	# far hills fading into the haze
	var hills := PackedVector3Array()
	for i in 30:
		var a := (i / 30.0) * TAU + randf_range(-0.08, 0.08); var rr := randf_range(290, 350); var hr := randf_range(50, 110); var hh := randf_range(18, 52)
		var hx := Transform3D(Basis(Vector3.UP, randf_range(0, TAU)).scaled_local(Vector3(1, 1, randf_range(0.6, 1))), Vector3(cos(a) * rr, hh / 2 - 2, sin(a) * rr))
		hills.append_array(hx * Gfx.cone_tris(9, hr, hh, -hh / 2))
	var hill_mi := MeshInstance3D.new(); hill_mi.name = "Hills"; hill_mi.mesh = Gfx.bake_flat(hills, [Transform3D.IDENTITY]); hill_mi.material_override = Gfx.std(World.lin("75683f"), 1.0); G.add_child(hill_mi); MoonShadow.no_receive(hill_mi)
	# supply crates scattered over the plain; three of them up on the tower
	var up := [[-1.85, -1.85], [1.85, -1.85], [-1.85, 1.85]]
	w._place_crates(G, int(S.get("crates", 46)) + 3, func() -> Array:
			if not up.is_empty(): var q: Array = up.pop_front(); return [q[0], q[1], TOWER.ph]
			var x := R.rng(-170, 170); var z := R.rng(-170, 170); return [x, z, 0.0],
		func(x: float, z: float, y: float) -> bool: return y > 0.0 or (Vector2(x, z).length() > 11 and Vector2(x, z - 20).length() > 6 and free.call(x, z, 1.2) and Vector2(x - WATER.x, z - WATER.z).length() > WATER.r + 3), true)
	Phys.index_colliders(); Phys.build_nav()
	w.start = {"x": 0.0, "z": 20.0, "yaw": 0.0}; w.spawns.clear()

func _build_tower(G: Node3D, x: float, z: float) -> void:
	var PH: float = TOWER.ph; var H: float = TOWER.half; var Bh: float = TOWER.base
	outer = Node3D.new(); outer.position = Vector3(x, 0, z); G.add_child(outer); inner = Node3D.new(); outer.add_child(inner)
	var NS := int(TOWER.steps); var SH: float = TOWER.step
	# planks: the skirt (its picture 2.5 times across, 0.8 up), the platform (twice each way), the eight solid steps (0.6, 1.4)
	var pl := [[2 * Bh, 2.0, 2 * Bh, 0.0, 1.0, 0.0, 2.5, 0.8], [2 * H, 0.24, 2 * H, 0.0, PH - 0.12, 0.0, 2.0, 2.0]]
	for k in range(1, NS + 1): var h: float = k * SH; var z0: float = H + 0.5 * (NS - k); pl.push_back([1.4, h, 0.5, 0.0, h / 2, z0 + 0.25, 0.6, 1.4])
	# beams: the frame (corner legs, a sill round the skirt's top, joists under the platform), cross braces on each side,
	# the railing (open to the south where the steps come up), the roof's four poles, and the steps' stringers, handrails and posts
	var beams := []
	var at := func(sx: float, sy: float, sz: float, px: float, py: float, pz: float, b := Basis.IDENTITY) -> void: beams.push_back([Vector3(sx, sy, sz), Transform3D(b, Vector3(px, py, pz))])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: at.call(0.42, PH - 1.9, 0.42, sx * (H - 0.2), 1.9 + (PH - 1.9) / 2 - 0.12, sz * (H - 0.2))
	at.call(2 * Bh + 0.12, 0.16, 0.16, 0.0, 2.06, Bh); at.call(2 * Bh + 0.12, 0.16, 0.16, 0.0, 2.06, -Bh); at.call(0.16, 0.16, 2 * Bh + 0.12, Bh, 2.06, 0.0); at.call(0.16, 0.16, 2 * Bh + 0.12, -Bh, 2.06, 0.0)
	at.call(2 * H + 0.2, 0.22, 0.22, 0.0, PH - 0.35, H); at.call(2 * H + 0.2, 0.22, 0.22, 0.0, PH - 0.35, -H); at.call(0.22, 0.22, 2 * H + 0.2, H, PH - 0.35, 0.0); at.call(0.22, 0.22, 2 * H + 0.2, -H, PH - 0.35, 0.0)
	var brace := func(ax: float, az: float, bx2: float, bz: float, y0: float, y1: float) -> void:   # (a box from one end to the other, turned as three.js's lookAt and a quarter turn about x)
		var a := Vector3(ax, y0, az); var b := Vector3(bx2, y1, bz); var dv := (b - a).normalized(); var xa := Vector3.UP.cross(dv).normalized()
		at.call(0.14, a.distance_to(b), 0.14, (ax + bx2) / 2, (y0 + y1) / 2, (az + bz) / 2, Basis(xa, dv, xa.cross(dv)))
	var e := H - 0.2
	for s in [-1.0, 1.0]:
		brace.call(-e, s * e, e, s * e, 2.1, PH - 0.4); brace.call(e, s * e, -e, s * e, 2.1, PH - 0.4); brace.call(s * e, -e, s * e, e, 2.1, PH - 0.4); brace.call(s * e, e, s * e, -e, 2.1, PH - 0.4)
	for q in [[-H, -H], [H, -H], [-H, H], [H, H], [0.0, -H], [-H, 0.0], [H, 0.0], [-0.8, H], [0.8, H]]: at.call(0.12, 1.1, 0.12, q[0], PH + 0.55, q[1])
	for y in [PH + 0.55, PH + 1.05]:
		at.call(2 * H, 0.08, 0.08, 0.0, y, -H); at.call(0.08, 0.08, 2 * H, -H, y, 0.0); at.call(0.08, 0.08, 2 * H, H, y, 0.0)
		at.call(H - 0.8, 0.08, 0.08, -(H + 0.8) / 2, y, H); at.call(H - 0.8, 0.08, 0.08, (H + 0.8) / 2, y, H)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]: at.call(0.14, 6.7 - PH, 0.14, sx * (H - 0.12), PH + (6.7 - PH) / 2, sz * (H - 0.12))
	var run := 0.5 * NS; var ang := atan2(PH, run); var slen := Vector2(PH, run).length()
	for sx in [-0.78, 0.78]:
		at.call(0.1, 0.3, slen, sx, PH / 2 - 0.05, H + run / 2, Basis(Vector3.RIGHT, ang)); at.call(0.07, 0.07, slen, sx, PH / 2 + 1.0, H + run / 2, Basis(Vector3.RIGHT, ang))
		for k in 3: at.call(0.08, 1.0, 0.08, sx, PH * (k / 2.0) + 0.5, H + run - k * run / 2 - 0.1)
	var pm := MeshInstance3D.new(); pm.name = "Planks"; pm.mesh = _plank_boxes(pl); pm.material_override = Gfx.std(Color.WHITE, 0.9, 0.0, plank_tex()); inner.add_child(pm)
	var bst := SurfaceTool.new(); bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in beams: var bb := BoxMesh.new(); bb.size = q[0]; bst.append_from(bb, 0, q[1])
	var bm := MeshInstance3D.new(); bm.name = "Beams"; bm.mesh = bst.commit(); bm.material_override = Gfx.std(World.lin("5a3f28"), 0.92); inner.add_child(bm)
	# the roof: a tin pyramid open underneath, shaded round as three.js's ConeGeometry(H * 1.55, 1.3, 4) is (its normals lean
	# out at the corners, each face's tip taking the next corner's)
	var rv := PackedVector3Array(); var rn := PackedVector3Array(); var rr := H * 1.55; var slope := rr / 1.3; var ap := Vector3(0, 8.0, 0)
	for k in 4:
		var t0 := k * PI / 2 + PI / 4; var t1 := t0 + PI / 2
		var b0 := Vector3(rr * sin(t0), 6.7, rr * cos(t0)); var b1 := Vector3(rr * sin(t1), 6.7, rr * cos(t1))
		var n0 := Vector3(sin(t0), slope, cos(t0)).normalized(); var n1 := Vector3(sin(t1), slope, cos(t1)).normalized()
		if (ap - b0).cross(b1 - b0).dot(Vector3(sin(t0 + PI / 4), 1.0, cos(t0 + PI / 4))) > 0.0: rv.append_array([b0, b1, ap])   # (outside the front face: Godot winds them clockwise)
		else: rv.append_array([b0, ap, b1])
		rn.append_array([n0, n1, n1])
	var ra := []; ra.resize(Mesh.ARRAY_MAX); ra[Mesh.ARRAY_VERTEX] = rv; ra[Mesh.ARRAY_NORMAL] = rn
	var rmesh := ArrayMesh.new(); rmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ra)
	var tin := Gfx.std(World.lin("8b8f92"), 0.55, 0.55); tin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof := MeshInstance3D.new(); roof.name = "Roof"; roof.mesh = rmesh; roof.material_override = tin; inner.add_child(roof)
	for n: Node in [pm, bm, roof]: MoonShadow.caster(n)
	# a sign on the railing (no shadow either way)
	var sgn := MeshInstance3D.new(); sgn.name = "TowerSign"; var sq := QuadMesh.new(); sq.size = Vector2(1.5, 0.56); sgn.mesh = sq; sgn.material_override = Gfx.std(Color.WHITE, 0.8, 0.0, tower_sign_tex())
	sgn.position = Vector3(-1.7, PH + 0.8, H + 0.07); inner.add_child(sgn); MoonShadow.no_receive(sgn)
	var add := func(minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float, grate := false) -> void:
		var b := Phys.add_collider(x + minx, miny, z + minz, x + maxx, maxy, z + maxz, "wood"); b.grate = grate; b.tower = true; cols.push_back(b)
	add.call(-Bh, 0.0, -Bh, Bh, 2.0, Bh)
	add.call(-H, PH - 0.24, -H, H, PH, H)
	for k in range(1, int(TOWER.steps) + 1): var h2: float = k * TOWER.step; var z1: float = H + 0.5 * (TOWER.steps - k); add.call(-0.7, 0.0, z1, 0.7, h2, z1 + 0.5)
	add.call(-H, PH, -H - 0.06, H, PH + 1.1, -H + 0.06, true); add.call(-H - 0.06, PH, -H, -H + 0.06, PH + 1.1, H, true); add.call(H - 0.06, PH, -H, H + 0.06, PH + 1.1, H, true)
	add.call(-H, PH, H - 0.06, -0.75, PH + 1.1, H + 0.06, true); add.call(0.75, PH, H - 0.06, H, PH + 1.1, H + 0.06, true)
	add.call(-H - 0.1, 6.7, -H - 0.1, H + 0.1, 7.0, H + 0.1)
	# sixteen places along its foot, one animal each
	var s_end: float = H + 0.5 * TOWER.steps
	var along := func(x0: float, z0: float, x1: float, z1: float, nx: float, nz: float) -> void:
		var L := Vector2(x1 - x0, z1 - z0).length(); var n := maxi(1, roundi(L / 1.9))
		for i in n: var u := (i + 0.5) / n; slots.push_back({"x": x + x0 + (x1 - x0) * u, "z": z + z0 + (z1 - z0) * u, "nx": nx, "nz": nz, "owner": null, "t": -9.0})
	along.call(-Bh, -Bh, Bh, -Bh, 0.0, -1.0); along.call(-Bh, -Bh, -Bh, Bh, -1.0, 0.0); along.call(Bh, -Bh, Bh, Bh, 1.0, 0.0)
	along.call(-Bh, Bh, -0.7, Bh, 0.0, 1.0); along.call(0.7, Bh, Bh, Bh, 0.0, 1.0)
	along.call(-0.7, Bh, -0.7, s_end, -1.0, 0.0); along.call(0.7, Bh, 0.7, s_end, 1.0, 0.0); along.call(-0.7, s_end, 0.7, s_end, 0.0, 1.0)

## the animals spread over the plain: herds of zebra, buffalo and giraffe, hippos round the waterhole, the cats and elephants further out
func populate(put: Callable, find: Callable, SR: World.Rng) -> void:
	for row in ROSTER:
		var kind: String = row[0]; var c: int = row[1]; var guard := 0
		while c > 0 and guard < 400:
			guard += 1
			if kind == "zebra" or kind == "buffalo" or kind == "giraffe":
				var center = find.call(70.0, 10.0, 2.0)
				if center == null: break
				if put.call(kind, center, {}) != null: c -= 1
				var herd := 3 if kind == "giraffe" else int(floor(SR.rng(3, 6)))
				for i in range(1, herd):
					if c <= 0: break
					if put.call(kind, find.call(60.0, 2.6, 1.3, center, 8.0), {}) != null: c -= 1
			elif kind == "gorilla":   # two troops of three
				var center2 = find.call(85.0, 12.0, 2.0)
				if center2 == null: break
				if put.call(kind, center2, GORILLA) != null: c -= 1
				for i in range(1, 3):
					if c <= 0: break
					if put.call(kind, find.call(80.0, 3.0, 1.3, center2, 7.0), GORILLA) != null: c -= 1
			elif kind == "hippo":
				var a := SR.rng(0, TAU)
				var p = find.call(60.0, 3.0, 1.5, {"x": WATER.x + cos(a) * (WATER.r + 2.5), "z": WATER.z + sin(a) * (WATER.r + 2.5)}, 4.0)
				if p == null: p = find.call(70.0, 6.0, 2.0)
				if put.call(kind, p, {}) != null: c -= 1
			else:
				var el := kind == "elephant"
				if put.call(kind, find.call(90.0 if el else 80.0, 14.0 if el else 8.0, 2.4 if el else 1.4), {}) != null: c -= 1

func update(dt: float) -> void:
	clock += dt; _tower_update(dt)
	if stampede or (game and game.ended): return
	t += dt; var l := T_STAMPEDE - t
	if warned < 1 and l <= 60.0: warned = 1; Snd.play("alarm"); game.say_banner("1분 뒤 습격", "감시탑 위로 올라가 준비하세요", 2.8)
	if warned < 2 and l <= 10.0: warned = 2; Snd.play("alarm"); game.say_banner("10초 뒤 습격", "땅이 울리기 시작합니다", 2.2); player.shake = maxf(player.shake, 0.15)
	if l <= 0.0: go()

## the stampede: every animal still alive (and not tamed) is set off at once and heads for you, and the tower you stand on
func go() -> void:
	if stampede: return
	stampede = true; t = T_STAMPEDE; var roars := 0
	for e in enemies.list:
		if not e.alive or not e.wild or e.tamed: continue
		e.angry = true; e.alert = true; e.awake = true
		if not e.fury: e.fury = true; e.state = "chase"; enemies.animals.wake(e)
		if e.type != "zebra" and roars < 8 and randf() < 0.25: roars += 1; Snd.play("roar_" + e.T.roar, 1.0, e.pos)
	Snd.play("quake", 1.0, player.pos); Snd.play("siren"); player.shake = maxf(player.shake, 0.45); Snd.buzz(220)
	game.say_banner("동물들이 몰려옵니다!", "탑 위에 있으면 동물들은 탑부터 칩니다 · 기린은 목으로 탑 위까지 칩니다" if holds() else "감시탑으로 올라가세요!", 3.4)
	game.say_feed("습격 시작 · 모든 동물이 감시탑으로")

# ---------------- the tower ----------------
## a place at the tower for this animal: the one it already has, or the free one nearest to it. null: all taken, wait
func claim(e):
	if e.slot != null and e.slot.owner == e: e.slot.t = clock; return e.slot
	var best = null; var bd := INF
	for s in slots:
		if s.owner != null and s.owner != e and s.owner.alive and clock - s.t < 0.6: continue
		var d := Vector2(s.x - e.pos.x, s.z - e.pos.z).length()
		if d < bd: bd = d; best = s
	if best != null: best.owner = e; best.t = clock; e.slot = best
	return best

## where you are: up on the platform, or high enough on the steps that nothing but a giraffe reaches you
func player_on() -> bool:
	if not standing: return false
	var px := player.pos.x - outer.position.x; var pz := player.pos.z - outer.position.z; var py := player.pos.y
	if py > TOWER.ph - 0.6 and absf(px) < TOWER.half + 0.1 and absf(pz) < TOWER.half + 0.1: return true
	return py > 2.3 and absf(px) < 0.8 and pz > TOWER.half - 0.1 and pz < TOWER.half + 0.5 * TOWER.steps + 0.1

func hurt(dmg: float, at: Vector3) -> void:
	if not standing or (game and game.ended) or dmg <= 0.0: return
	hp = maxf(0.0, hp - dmg); shake = minf(1.0, shake + 0.2 + dmg / 60.0)
	if fx: fx.chunks(at, 4 if dmg >= 40.0 else 2, 0.12, "wood"); fx.puff(at, 3 if dmg >= 40.0 else 1, 0.55, 0.5)
	if crack_t <= 0.0:
		crack_t = 0.12; Snd.play("crack", 1.0, at)
		if dmg >= 40.0: Snd.play("thud", 1.0, at)
	if on:
		player.shake = maxf(player.shake, 0.05 + dmg / 500.0)
		if dmg >= 40.0: Snd.buzz(40)
	var f: float = hp / TOWER.hp
	for m: float in [0.75, 0.5, 0.25, 0.1]:
		if f <= m and not marks.has(m): marks[m] = true; game.say_banner("감시탑 체력 %d%%" % roundi(m * 100), "곧 무너집니다! 탑을 치는 동물부터 잡으세요" if m <= 0.25 else "탑을 공격하는 동물을 쏘세요", 2.0)
	if hp <= 0.0: collapse()

## down it comes: the colliders go at once, the frame topples and sinks into a heap of dust
func collapse() -> void:
	if not standing: return
	var was := player_on()
	standing = false; on = false; fall_t = 0.0; fall_dir = 1.0 if randf() < 0.5 else -1.0
	for b in cols: Phys.remove_collider(b)
	cols.clear(); Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	var c := Vector3(outer.position.x, 1.5, outer.position.z); Snd.play("crack", 1.0, c); Snd.play("quake", 1.0, c); Snd.play("boom_small", 1.0, c)
	if fx:
		for i in 14: var a := i / 14.0 * TAU; fx.puff(Vector3(outer.position.x + cos(a) * 3.5, 0.5, outer.position.z + sin(a) * 3.5), 2, 0.6, 1.4)
		fx.chunks(Vector3(outer.position.x, 3, outer.position.z), 18, 0.3, "wood")
	player.shake = maxf(player.shake, 0.7); Snd.buzz(260)
	if was:
		player.grounded = false; player.vel.y = 2.5; player.vel.x += fall_dir * 2.0; player.stun_t = maxf(player.stun_t, 1.0)
		game.say_banner("감시탑이 무너졌습니다", "땅으로 떨어졌습니다 · 이제 동물들이 나를 노립니다", 3.0)
	else: game.say_banner("감시탑이 무너졌습니다", "이제 숨을 곳이 없습니다", 2.6)
	game.say_feed("감시탑 붕괴")

func _tower_update(dt: float) -> void:
	crack_t -= dt; on = player_on()
	if on and not hinted and not game.ended: hinted = true; game.say_hint("감시탑 위 · 동물들은 탑부터 공격합니다 (기린은 목으로 탑 위까지 칩니다)", 3.2)
	if standing:
		shake = maxf(0.0, shake - dt * 2.2); var lean: float = (1.0 - hp / TOWER.hp) * 0.035; var s := shake * 0.06
		inner.position = Vector3(randf_range(-1, 1) * s, 0, randf_range(-1, 1) * s); inner.rotation = Vector3(lean * 0.6, 0, lean)
	elif fall_t >= 0.0:
		fall_t += dt; var k := minf(1.0, fall_t / 1.5); var a := k * k * 1.45
		inner.rotation = Vector3(0, 0, fall_dir * a); inner.position = Vector3(fall_dir * sin(a) * 1.6, -maxf(0.0, fall_t - 1.5) * 1.2, 0)
		if fall_t > 1.5 and not landed:
			landed = true; var lp := Vector3(outer.position.x + fall_dir * 5.0, 0.5, outer.position.z); Snd.play("quake", 1.0, lp)
			if fx:
				for i in 10: fx.puff(lp + Vector3(randf_range(-3, 3), -0.1, randf_range(-3, 3)), 2, 0.6, 1.4)
		if fall_t > 4.0: outer.visible = false; fall_t = -1.0
