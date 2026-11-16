class_name Lab
extends RefCounted
## Stages 3 and 3-2: a sealed animal lab. Ten cages along the walls, a mad scientist monkey behind a window in the north wall.
## In stage 3 the cages open on a clock (10 s, then one every 15 s); in 3-2 each opens when the one before it is empty.
## Ported from src/04g_lab.js: the same colliders in the same order, the same crates, the same animals in the same places.

const HALF := 54.0
const CEIL := 15.0
const FIRST := 10.0
const STEP := 15.0
const WIN := {"w": 8.0, "y0": 5.0, "y1": 10.0, "depth": 5.0}
const CAGES := [
	{"n": 1, "type": "zebra", "x": -37.5, "z": 33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 2, "type": "buffalo", "x": 37.5, "z": 33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 3, "type": "hippo", "x": -37.5, "z": 11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 4, "type": "rhino", "x": 37.5, "z": 11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 5, "type": "cheetah", "x": -37.5, "z": -11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 6, "type": "giraffe", "x": 37.5, "z": -11.1, "w": 11.0, "d": 11.0, "h": 3.6, "count": 3},
	{"n": 7, "type": "tiger", "x": -37.5, "z": -33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 8, "type": "lionM", "x": 37.5, "z": -33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 9, "type": "elephant", "x": -12.45, "z": -33.6, "w": 15.0, "d": 15.0, "h": 4.2, "scale": 0.9, "count": 2},
	{"n": 10, "type": "gorilla", "x": 14.7, "z": -35.85, "w": 12.0, "d": 12.0, "h": 6.0, "boss": true},
]

var t := 0.0
var running := false
var seq := false
var cages: Array = []
var reach = null          # 3-2: the cage the monkey is reaching out to open
var push_t := -1.0        # ...and how long until his hand comes down on the button
var player: Player
var fx: Fx = null
var game = null           # Game: banners and feed lines
var monkey: Node3D
var monkey_mode := "idle"
var monkey_t := 0.0
var _arm_l: Node3D; var _arm_r: Node3D
var _bar_mat: StandardMaterial3D; var _glass_mat: StandardMaterial3D; var _kick_mat: StandardMaterial3D = null
var _glow_mat: StandardMaterial3D = null
## a beacon's red glow, added light that shows while it turns
func _beacon_glow() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new(); _glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _glow_mat.albedo_texture = Gfx.glow_tex(Color(1, 60 / 255.0, 50 / 255.0, 0.95), Color(1, 30 / 255.0, 20 / 255.0, 0.3))
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; _glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; _glow_mat.disable_fog = true
	return _glow_mat
var beacons: Array = []
var pressed := false      # the monkey has slammed his button (in the opening scene, or as play begins if it was skipped)
var clock := false        # the boards count down (before the button they show "- -")
var alarm := false        # the red beacons turn
var door: Node3D          # the sealed door in the south wall: it rolls up as you leave
var door_open := 0.0
var _press_at := 1.0
var _ex := 1.0            # the stage's exposure, for what the browser game draws untoned

static var _tx := {}
static func _font(k: String) -> FontFile:
	return load({"title": "res://fonts/blackhansans_BlackHanSans-Regular.ttf", "mono": "res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf", "bold": "res://fonts/ibmplexsanskr_IBMPlexSansKR-Bold.ttf"}[k])
## pale lab tiles (512 across, 27 times over the floor)
static func tiles_tex() -> ImageTexture:
	if not _tx.has("tiles"):
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8); img.fill(Color("b8bfc5"))
		Gfx.speckle(img, 6000, [Color("c0c7cd"), Color("aeb5bb"), Color("c6ccd1"), Color("a8afb5")], 2)
		for i in 10: Gfx.fellipse(img, randf() * 512, randf() * 512, randf_range(20, 70), randf_range(10, 40), randf_range(0, 3), Color(70 / 255.0, 80 / 255.0, 90 / 255.0, randf_range(0.04, 0.1)))
		for k in 5: Gfx.frect(img, k * 128 - 2, 0, 4, 512, Color("8a9299")); Gfx.frect(img, 0, k * 128 - 2, 512, 4, Color("8a9299"))
		_tx.tiles = Gfx.tex(img)
	return _tx.tiles
## the walls: white panels, a line, a teal band, dark skirting, vent slots (512 x 256, 13.5 times along a long wall)
static func wall_tex() -> ImageTexture:
	if not _tx.has("wall"):
		var img := Image.create(512, 256, false, Image.FORMAT_RGBA8); img.fill(Color("d3d9de"))
		Gfx.speckle(img, 2500, [Color("dbe0e4"), Color("cbd1d6")], 2)
		var x := 0.0
		while x <= 512.0: Gfx.frect(img, x - 1.5, 0, 3, 256, Color("a9b1b8")); x += 128.0
		Gfx.frect(img, 0, 84, 512, 3, Color("a9b1b8")); Gfx.frect(img, 0, 150, 512, 22, Color("2f7f86")); Gfx.frect(img, 0, 230, 512, 26, Color("27323a"))
		x = 32.0
		while x < 512.0:
			for k in 6: Gfx.frect(img, x + k * 9, 40, 5, 24, Color("9aa3aa"))
			x += 128.0
		_tx.wall = Gfx.tex(img)
	return _tx.wall
## yellow and black hazard stripes (128 x 32)
static func hazard_tex() -> ImageTexture:
	if not _tx.has("hazard"):
		var img := Image.create(128, 32, false, Image.FORMAT_RGBA8); img.fill(Color("e3b21c")); var h := 32.0; var x := -h
		while x < 128.0 + h: Gfx.fpoly(img, PackedVector2Array([Vector2(x, h), Vector2(x + 12, h), Vector2(x + 12 + h, 0), Vector2(x + h, 0)]), Color("16181b")); x += 24.0
		_tx.hazard = Gfx.tex(img)
	return _tx.hazard
## straw on a cage floor (256 across, three times over)
static func straw_tex() -> ImageTexture:
	if not _tx.has("straw"):
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color("6d6a58"))
		var ink := [Color(190 / 255.0, 160 / 255.0, 80 / 255.0, 0.55), Color(150 / 255.0, 120 / 255.0, 60 / 255.0, 0.5), Color(90 / 255.0, 80 / 255.0, 60 / 255.0, 0.4)]
		for i in 900:
			var c: Color = ink[randi() % 3]; var lw := randf_range(1, 2); var x := randf() * 256; var y := randf() * 256; var a := randf() * TAU; var l := randf_range(6, 18)
			Gfx.fline(img, Vector2(x, y), Vector2(x + cos(a) * l, y + sin(a) * l), c, lw)
		_tx.straw = Gfx.tex(img)
	return _tx.straw
## a cage number painted on the floor
static func num_tex(n: int) -> ImageTexture:
	var key := "num%d" % n
	if not _tx.has(key):
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
		Gfx.text(img, "%02d" % n, _font("title"), 92, 64, 68, "center", "middle", Color(227 / 255.0, 178 / 255.0, 28 / 255.0, 0.85))
		_tx[key] = Gfx.tex(img)
	return _tx[key]
## the sealed door: grey steel, hazard chevrons along the foot, a seam, its name
static func door_tex() -> ImageTexture:
	if not _tx.has("door"):
		var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color("5c646c")); Gfx.speckle(img, 1200, [Color("656d75"), Color("545b63")], 2)
		var x := -256.0
		while x < 256.0: Gfx.fpoly(img, PackedVector2Array([Vector2(x, 256), Vector2(x + 20, 256), Vector2(x + 60, 216), Vector2(x + 40, 216)]), Color("e3b21c")); x += 40.0
		Gfx.frect(img, 0, 125, 256, 6, Color("3b4249")); Gfx.text(img, "비상 출입문", _font("bold"), 30, 128, 70, "center", "alphabetic", Color("e8e2d0"))
		_tx.door = Gfx.tex(img)
	return _tx.door
## the green monitor picture
static func screen_tex() -> ImageTexture:
	if not _tx.has("screen"):
		var img := Image.create(256, 128, false, Image.FORMAT_RGBA8); img.fill(Color("04140e")); var prev := Vector2.ZERO; var x := 0.0
		while x < 256.0:
			var p := Vector2(x, 64 + sin(x * 0.07) * 22 + sin(x * 0.23) * 8)
			if x > 0.0: Gfx.fline(img, prev, p, Color("3bff9a"), 2.0)
			prev = p; x += 4.0
		Gfx.text(img, "SUBJECT 01-10", _font("mono"), 16, 10, 20, "left", "alphabetic", Color("3bff9a")); Gfx.text(img, "AGGRESSION 98%", _font("mono"), 16, 10, 118, "left", "alphabetic", Color("3bff9a"))
		_tx.screen = Gfx.tex(img)
	return _tx.screen
## a server rack's face: rows of units with little lights
static func rack_tex() -> ImageTexture:
	if not _tx.has("rack"):
		var img := Image.create(128, 256, false, Image.FORMAT_RGBA8); img.fill(Color("15191e")); var y := 8
		while y < 248:
			Gfx.frect(img, 6, y, 116, 11, Color("232a31"))
			for k in 5: Gfx.frect(img, 12 + k * 7, y + 4, 4, 3, Color(["3bff9a", "2b6b4a", "ffb340", "3a9dff", "1c2a24"][randi() % 5]))
			y += 14
		_tx.rack = Gfx.tex(img)
	return _tx.rack
## a big stencilled wall sign
static func sign_tex(text: String, sub: String) -> ImageTexture:
	var img := Image.create(512, 160, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	Gfx.text(img, text, _font("title"), 92, 256, 66, "center", "middle", Color(39 / 255.0, 50 / 255.0, 58 / 255.0, 0.92))
	Gfx.text(img, sub, _font("mono"), 26, 256, 134, "center", "middle", Color(47 / 255.0, 127 / 255.0, 134 / 255.0, 0.95))
	return Gfx.tex(img)
## a textured box whose picture is repeated rx by ry from (ox, oy), as a three.js texture's repeat and offset lay it
static func _tex_box(size: Vector3, map: Texture2D, rough: float, rx: float, ry: float, ox := 0.0, oy := 0.0, metal := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = Gfx.box(size); var mat := Gfx.std(Color.WHITE, rough, metal, map)
	mat.uv1_scale = Vector3(rx, ry, 1); mat.uv1_offset = Vector3(ox, 1.0 - ry - oy, 0)   # (three.js counts v from the bottom)
	m.material_override = mat
	return m

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	seq = S.get("seq", false); var E := HALF; fx = w.fx; _ex = Gfx.exposure(float(S.get("exposure", 1.15)))
	_bar_mat = Gfx.std(World.lin("8d949c"), 0.38, 0.75)
	_glass_mat = Gfx.std(Color(0.66, 0.86, 1.0, 0.2), 0.05, 0.3); _glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_m := PlaneMesh.new(); floor_m.size = Vector2(2 * E, 2 * E); var fl := MeshInstance3D.new(); fl.mesh = floor_m
	var flm := Gfx.std(Color.WHITE, 0.55, 0.05, tiles_tex()); flm.uv1_scale = Vector3(27, 27, 1); fl.material_override = flm; G.add_child(fl)   # pale lab tiles
	var ce := MeshInstance3D.new(); ce.mesh = floor_m; ce.material_override = Gfx.std(World.lin("2b3038"), 0.9); ce.rotation.x = PI; ce.position.y = CEIL; G.add_child(ce)
	var walls := []   # boxes drawn in one mesh
	# west and east walls
	for q in [[-E - 1, 0.0, 2.0, 2 * E + 4], [E + 1, 0.0, 2.0, 2 * E + 4]]:   # white panels, a teal band, dark skirting
		var wb := _tex_box(Vector3(q[2], CEIL, q[3]), wall_tex(), 0.7, 13.5, 1); wb.position = Vector3(q[0], CEIL / 2, q[1]); G.add_child(wb)
		Phys.add_collider(q[0] - q[2] / 2, 0, q[1] - q[3] / 2, q[0] + q[2] / 2, 40, q[1] + q[3] / 2, "concrete")
	# the north wall is flat, with a square window in it: four pieces round the opening
	var WX: float = WIN.w / 2; var W0 := 2 * E + 4
	for q in [[-W0 / 2, -WX, 0.0, CEIL], [WX, W0 / 2, 0.0, CEIL], [-WX, WX, 0.0, WIN.y0], [-WX, WX, WIN.y1, CEIL]]:
		var nb := _tex_box(Vector3(q[1] - q[0], q[3] - q[2], 2.0), wall_tex(), 0.7, (q[1] - q[0]) / W0 * 13.5, (q[3] - q[2]) / CEIL, (q[0] + W0 / 2) / W0 * 13.5, q[2] / CEIL)
		nb.position = Vector3((q[0] + q[1]) / 2, (q[2] + q[3]) / 2, -E - 1); G.add_child(nb)
		Phys.add_collider(q[0], q[2], -E - 2, q[1], 40.0 if q[3] >= CEIL else q[3], -E, "concrete")
	# the south wall has the doorway in it: two long pieces and a lintel, and the door, shut for good while you are inside
	var DW := 4.2
	for sx in [-1.0, 1.0]:
		var ww := E + 2 - DW; var sb := _tex_box(Vector3(ww, CEIL, 2.0), wall_tex(), 0.7, 6, 1); sb.position = Vector3(sx * (DW + ww / 2), CEIL / 2, E + 1); G.add_child(sb)
		Phys.add_collider(DW if sx > 0 else -E - 2, 0, E, E + 2 if sx > 0 else -DW, 40, E + 2, "concrete")
	var lb := _tex_box(Vector3(2 * DW, CEIL - 7, 2.0), wall_tex(), 0.7, 1, (CEIL - 7) / CEIL, 0, 7 / CEIL); lb.position = Vector3(0, 7 + (CEIL - 7) / 2, E + 1); G.add_child(lb)
	# the short bright corridor behind the door
	var cor := MeshInstance3D.new(); cor.mesh = Gfx.merge_boxes([[0.4, 7, 13, -DW - 0.2, 3.5, E + 6.5], [0.4, 7, 13, DW + 0.2, 3.5, E + 6.5], [2 * DW + 0.8, 0.4, 13, 0, 7.2, E + 6.5], [2 * DW, 0.1, 13, 0, -0.04, E + 6.5]])
	cor.material_override = Gfx.std(World.lin("4a525a"), 0.7); G.add_child(cor)
	var day := MeshInstance3D.new(); var dq := QuadMesh.new(); dq.size = Vector2(2 * DW, 7); day.mesh = dq; day.material_override = Gfx.untoned(Color(2.2, 2.2, 2.1), null, _ex)
	day.position = Vector3(0, 3.5, E + 12.5); day.rotation.y = PI; G.add_child(day)
	# big stencilled signs: on the west and east walls, and over the door
	if not _tx.has("sign1"): _tx.sign1 = sign_tex("격리동 B-07", "ANIMAL CONTAINMENT · DO NOT OPEN"); _tx.sign2 = sign_tex("출입 통제", "BIOLAB 07 · SEALED")
	for q in [[_tx.sign1, Vector2(16, 5), Vector3(-E + 0.02, 9.5, 0), PI / 2], [_tx.sign1, Vector2(16, 5), Vector3(E - 0.02, 9.5, 0), -PI / 2], [_tx.sign2, Vector2(14, 4.4), Vector3(0, 9.8, E - 0.02), PI]]:
		var sg := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = q[1]; sg.mesh = sq
		var sm := Gfx.std(Color.WHITE, 0.8, 0.0, q[0]); sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; sg.material_override = sm
		sg.position = q[2]; sg.rotation.y = q[3]; G.add_child(sg)
	Phys.add_collider(-DW, 7, E, DW, 40, E + 2, "concrete"); Phys.add_collider(-DW, 0, E - 0.4, DW, 7, E + 2, "metal")
	# trusses under the ceiling
	var truss := []; var tx := -45.0
	while tx <= 45.0: truss.push_back([0.4, 0.7, 2 * E, tx, CEIL - 0.6, 0]); tx += 10.0
	for tz: float in [-40.5, -13.5, 13.5, 40.5]: truss.push_back([2 * E, 0.3, 0.3, 0, CEIL - 1.0, tz])
	var tm := MeshInstance3D.new(); tm.mesh = Gfx.merge_boxes(truss); tm.material_override = Gfx.std(World.lin("4a5058"), 0.6, 0.5); G.add_child(tm)
	# the scientist's room behind the glass: bright, a console with the big red button
	var RZ := -E - 2; var RD: float = WIN.depth; var RX := WX + 1.2
	var steel := Gfx.std(World.lin("3a4148"), 0.5, 0.6)
	var add_boxes := func(list: Array, mat: Material) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = Gfx.merge_boxes(list); mi.material_override = mat; G.add_child(mi); return mi
	add_boxes.call([[2 * RX, 0.3, RD, 0, WIN.y0 - 0.15, RZ - RD / 2], [2 * RX, 0.3, RD, 0, WIN.y1 + 0.55, RZ - RD / 2]], Gfx.std(World.lin("252b31"), 0.9))
	add_boxes.call([[2 * RX, WIN.y1 - WIN.y0 + 0.7, 0.3, 0, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD], [0.3, WIN.y1 - WIN.y0 + 0.7, RD, -RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2],
		[0.3, WIN.y1 - WIN.y0 + 0.7, RD, RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2]], Gfx.std(World.lin("3b4652"), 0.85))
	add_boxes.call([[2 * RX - 1, 0.08, 0.7, 0, WIN.y1 + 0.38, RZ - 1.2], [2 * RX - 1, 0.08, 0.7, 0, WIN.y1 + 0.38, RZ - RD + 1.2]], Gfx.untoned(Color(1.5, 1.6, 1.55), null, _ex))   # its lights
	var fr := 0.3   # a steel frame round the window on the lab side, and a strip of hazard paint under it
	add_boxes.call([[WIN.w + 2 * fr, fr, 0.3, 0, WIN.y0 - fr / 2, -E + 0.12], [WIN.w + 2 * fr, fr, 0.3, 0, WIN.y1 + fr / 2, -E + 0.12], [fr, WIN.y1 - WIN.y0, 0.3, -WX - fr / 2, (WIN.y0 + WIN.y1) / 2, -E + 0.12],
		[fr, WIN.y1 - WIN.y0, 0.3, WX + fr / 2, (WIN.y0 + WIN.y1) / 2, -E + 0.12]], steel)
	var hzs := MeshInstance3D.new(); var hq := QuadMesh.new(); hq.size = Vector2(WIN.w + 2 * fr, 0.35); hzs.mesh = hq; var hzm := Gfx.std(Color.WHITE, 0.7, 0.0, hazard_tex()); hzm.uv1_scale = Vector3(5, 1, 1)
	hzs.material_override = hzm; hzs.position = Vector3(0, WIN.y0 - fr - 0.2, -E + 0.03); G.add_child(hzs)
	add_boxes.call([[6.0, 0.8, 0.8, 0, WIN.y0 + 0.4, RZ - 0.55], [6.0, 0.12, 0.95, 0, WIN.y0 + 0.85, RZ - 0.55]], steel)   # the console
	for i in 4:   # a wall of monitors behind him
		var sc := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(2.0, 1.15); sc.mesh = sq; sc.material_override = Gfx.untoned(Color.WHITE, screen_tex(), _ex)
		sc.position = Vector3([-3.4, -1.15, 1.15, 3.4][i], WIN.y0 + 2.5 + (i % 2) * 0.2, RZ - RD + 0.17); G.add_child(sc)
	var by := WIN.y0 + 0.95   # the big red button on its yellow ring
	var bb := MeshInstance3D.new(); var bbm := CylinderMesh.new(); bbm.top_radius = 0.22; bbm.bottom_radius = 0.24; bbm.height = 0.06; bbm.radial_segments = 20; bbm.rings = 0; bb.mesh = bbm
	bb.material_override = Gfx.std(World.lin("e3b21c"), 0.5); bb.position = Vector3(0.55, by - 0.06, RZ - 0.45); G.add_child(bb)
	var bt := MeshInstance3D.new(); var btm := CylinderMesh.new(); btm.top_radius = 0.15; btm.bottom_radius = 0.16; btm.height = 0.12; btm.radial_segments = 20; btm.rings = 0; bt.mesh = btm
	var btmat := Gfx.std(World.lin("d11c1c"), 0.35); btmat.emission_enabled = true; btmat.emission = World.lin("500000"); bt.material_override = btmat; bt.position = Vector3(0.55, by, RZ - 0.45); G.add_child(bt)
	var gl := MeshInstance3D.new(); var gq := QuadMesh.new(); gq.size = Vector2(WIN.w, WIN.y1 - WIN.y0); gl.mesh = gq; gl.material_override = _glass_mat; gl.position = Vector3(0, (WIN.y0 + WIN.y1) / 2, -E - 0.02); G.add_child(gl)
	Phys.add_collider(-WX, WIN.y0, -E - 0.3, WX, WIN.y1, -E, "metal")   # bulletproof
	_build_monkey(G, Vector3(0, WIN.y0, RZ - 1.35))
	# light panels in the ceiling
	var panels := []
	for x: float in [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]:
		for z: float in [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]:
			panels.push_back(Transform3D(Basis.IDENTITY, Vector3(x, CEIL - 1.25, z))); w.lamps.push_back({"x": x, "y": CEIL - 1.6, "z": z})
	var pm := BoxMesh.new(); pm.size = Vector3(4.2, 0.12, 1.4); var pmm := Gfx.multimesh(pm, panels); pmm.material_override = Gfx.untoned(Color(1.6, 1.7, 1.8), null, _ex); G.add_child(pmm)   # (white, untoned)
	# red alarm beacons on the walls
	for q in [[-E + 0.3, 6.0, -27.0], [-E + 0.3, 6.0, 27.0], [E - 0.3, 6.0, -27.0], [E - 0.3, 6.0, 27.0], [-21.0, 6.0, -E + 0.3], [21.0, 6.0, -E + 0.3], [-15.0, 7.0, E - 0.3], [15.0, 7.0, E - 0.3], [-E + 0.3, 6.0, 0.0], [E - 0.3, 6.0, 0.0]]:
		var b := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.28; bm.bottom_radius = 0.32; bm.height = 0.5; bm.radial_segments = 12; bm.rings = 0; b.mesh = bm
		b.material_override = Gfx.untoned(Color("401010"), null, _ex); b.position = Vector3(q[0], q[1], q[2]); G.add_child(b)
		var gs := MeshInstance3D.new(); var gq2 := QuadMesh.new(); gq2.size = Vector2(4, 4); gs.mesh = gq2; gs.material_override = _beacon_glow(); gs.position = b.position; gs.visible = false; G.add_child(gs)
		beacons.push_back({"b": b, "s": gs})
	# cages: straw on the floor, four hinged walls, a countdown board above
	var straw := Gfx.std(Color.WHITE, 0.95, 0.0, straw_tex()); straw.uv1_scale = Vector3(3, 3, 1)
	var stripe := Gfx.std(Color.WHITE, 0.8, 0.0, hazard_tex())
	for def: Dictionary in CAGES:
		var c := def.duplicate(); c.open = false; c.open_at = FIRST + STEP * (int(def.n) - 1); c.opened_t = 0.0; c.panels = []; c.animals = []; c.clang = false; c.held = false; c.last_beep = 0; c.boss = def.get("boss", false)
		if seq:   # 3-2: the first opens 5 s in, every other one waits for the one before it to be emptied
			if int(def.n) == 1: c.open_at = 5.0
			else: c.held = true; c.open_at = INF
		var st := MeshInstance3D.new(); var sm := PlaneMesh.new(); sm.size = Vector2(c.w - 0.4, c.d - 0.4); st.mesh = sm; st.material_override = straw; st.position = Vector3(c.x, 0.012, c.z); G.add_child(st)
		# hazard stripes just outside the bars
		for q in [[c.x, c.z - c.d / 2 - 0.35, c.w + 1.4, 0.6, 0], [c.x, c.z + c.d / 2 + 0.35, c.w + 1.4, 0.6, 0], [c.x - c.w / 2 - 0.35, c.z, c.d, 0.6, 1], [c.x + c.w / 2 + 0.35, c.z, c.d, 0.6, 1]]:
			var hs := MeshInstance3D.new(); var hp := QuadMesh.new(); hp.size = Vector2(q[2], q[3]); hs.mesh = hp; hs.material_override = stripe
			hs.rotation = Vector3(-PI / 2, 0, PI / 2 if q[4] else 0.0); hs.rotation_order = EULER_ORDER_XYZ; hs.position = Vector3(q[0], 0.014, q[1]); G.add_child(hs)
		# the cage number painted on the floor, on the side facing the middle of the room
		var nm := MeshInstance3D.new(); var nq := QuadMesh.new(); nq.size = Vector2(2.6, 2.6); nm.mesh = nq
		var nmat := Gfx.std(Color.WHITE, 0.8, 0.0, num_tex(int(c.n))); nmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; nmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; nm.material_override = nmat
		nm.rotation_order = EULER_ORDER_XYZ
		if absf(c.x) > 20: nm.position = Vector3(c.x - signf(c.x) * (c.w / 2 + 2.2), 0.016, c.z); nm.rotation = Vector3(-PI / 2, 0, signf(c.x) * PI / 2)
		else: nm.position = Vector3(c.x, 0.016, c.z + c.d / 2 + 2.2); nm.rotation = Vector3(-PI / 2, 0, 0)
		G.add_child(nm)
		for side in ["n", "s", "e", "w"]: c.panels.push_back(_panel(G, c, side))
		_board(G, c); c.shown = ""
		cages.push_back(c); _draw(c)
	# lab furniture in the middle: cover that stays put (outside every cage's fall zone)
	var bench_m := Gfx.std(World.lin("dfe3e6"), 0.5, 0.2); var top_m := Gfx.std(World.lin("2c3339"), 0.4, 0.3); var scr_m := Gfx.untoned(Color.WHITE, screen_tex(), _ex)
	var flask_m := Gfx.std(Color(World.lin("9fe0c8"), 0.6), 0.1); flask_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for q in [[-10.5, 31.5, 0], [10.5, 31.5, 0], [-15.75, 9.0, 1], [15.75, 9.0, 1], [-15.75, -14.0, 1], [15.75, -14.0, 1], [0.0, 38.0, 0], [-22.0, 22.0, 0], [22.0, 22.0, 0]]:
		var bg := Node3D.new(); bg.position = Vector3(q[0], 0, q[1]); bg.rotation.y = PI / 2 if q[2] else 0.0; G.add_child(bg)
		var bnb := MeshInstance3D.new(); bnb.mesh = Gfx.box(Vector3(4.2, 0.85, 1.2)); bnb.material_override = bench_m; bnb.position.y = 0.425; bg.add_child(bnb); MoonShadow.caster(bnb)
		var bnt := MeshInstance3D.new(); bnt.mesh = Gfx.box(Vector3(4.3, 0.08, 1.3)); bnt.material_override = top_m; bnt.position.y = 0.89; bg.add_child(bnt)
		for sx: float in [-1.2, 0.3]:   # two monitors, showing the subjects
			var mo := MeshInstance3D.new(); mo.mesh = Gfx.box(Vector3(0.8, 0.5, 0.06)); mo.material_override = top_m; mo.position = Vector3(sx, 1.25, -0.2); bg.add_child(mo)
			var sc := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(0.72, 0.42); sc.mesh = sq; sc.material_override = scr_m; sc.position = Vector3(sx, 1.25, -0.165); bg.add_child(sc)
		var fl2 := MeshInstance3D.new(); var fm := CylinderMesh.new(); fm.top_radius = 0.12; fm.bottom_radius = 0.16; fm.height = 0.36; fm.radial_segments = 10; fm.rings = 0; fl2.mesh = fm
		fl2.material_override = flask_m; fl2.position = Vector3(1.4, 1.11, 0.1); bg.add_child(fl2)
		var hx := 0.6 if q[2] else 2.1; var hz := 2.1 if q[2] else 0.6
		Phys.add_collider(q[0] - hx, 0, q[1] - hz, q[0] + hx, 0.93, q[1] + hz, "metal")
	# specimen tanks: glass cylinders of glowing green liquid with something curled up inside
	var tank_glass := Gfx.std(Color(World.lin("bfefff"), 0.22), 0.05, 0.3); tank_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; tank_glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var liquid := Gfx.untoned(Color(0.25, 0.9, 0.45), null, _ex, 0.5); var shadowy := Gfx.std(World.lin("1d2a1f"), 0.9)
	var cyl := func(r0: float, r1: float, h: float, n: int, open_ended := false) -> CylinderMesh:
		var cm := CylinderMesh.new(); cm.top_radius = r0; cm.bottom_radius = r1; cm.height = h; cm.radial_segments = n; cm.rings = 0; cm.cap_top = not open_ended; cm.cap_bottom = not open_ended; return cm
	for q in [[0.0, 18.0], [-9.75, -3.0], [9.75, -3.0], [0.0, -17.0], [-22.0, 2.0], [22.0, 2.0]]:
		for y: float in [0.25, 3.35]:   # the steel base and cap
			var bs := MeshInstance3D.new(); bs.mesh = cyl.call(1.0, 1.05, 0.5, 20); bs.material_override = steel; bs.position = Vector3(q[0], y, q[1]); G.add_child(bs)
		var tg := MeshInstance3D.new(); tg.mesh = cyl.call(0.9, 0.9, 2.6, 24, true); tg.material_override = tank_glass; tg.position = Vector3(q[0], 1.8, q[1]); G.add_child(tg)
		var lq := MeshInstance3D.new(); lq.mesh = cyl.call(0.85, 0.85, 2.4, 20); lq.material_override = liquid; lq.position = Vector3(q[0], 1.72, q[1]); G.add_child(lq)
		var th := MeshInstance3D.new(); var ts := SphereMesh.new(); ts.radius = 0.45; ts.height = 0.9; ts.radial_segments = 12; ts.rings = 8; th.mesh = ts; th.material_override = shadowy
		th.scale = Vector3(1, 1.3, 0.8); th.position = Vector3(q[0], 1.7, q[1]); G.add_child(th)
		Phys.add_collider(q[0] - 1.0, 0, q[1] - 1.0, q[0] + 1.0, 3.6, q[1] + 1.0, "metal")
	var rack_m := Gfx.std(Color.WHITE, 0.6, 0.4, rack_tex()); rack_m.emission_enabled = true; rack_m.emission = Color.WHITE; rack_m.emission_texture = rack_tex(); rack_m.emission_energy_multiplier = 0.6
	for q in [[-18.0, -9.75], [18.0, -9.75], [-18.0, 24.0], [18.0, 24.0], [-26.0, -18.0], [26.0, -18.0], [0.0, 28.0]]:   # server racks with blinking lights
		var rk := MeshInstance3D.new(); rk.mesh = Gfx.box(Vector3(1.2, 2.4, 2.6)); rk.material_override = rack_m; rk.position = Vector3(q[0], 1.2, q[1]); G.add_child(rk); MoonShadow.caster(rk)
		Phys.add_collider(q[0] - 0.6, 0, q[1] - 1.3, q[0] + 0.6, 2.4, q[1] + 1.3, "metal")
	for q in [[-18.0, E - 0.9], [18.0, E - 0.9], [-32.0, E - 0.9], [32.0, E - 0.9]]:   # shelves of supplies either side of the door
		for y in [0.3, 1.2, 2.1]: walls.push_back([6.0, 0.08, 1.2, q[0], y, q[1], "59626b"])
		walls.push_back([0.08, 2.6, 1.2, q[0] - 2.96, 1.3, q[1], "59626b"]); walls.push_back([0.08, 2.6, 1.2, q[0] + 2.96, 1.3, q[1], "59626b"])
		for k in 9:   # boxes of supplies on them
			var sup := MeshInstance3D.new(); sup.mesh = Gfx.box(Vector3(randf_range(0.4, 0.8), randf_range(0.3, 0.6), randf_range(0.5, 0.9)))
			sup.material_override = Gfx.std(World.lin(["c9b48a", "8fa3b8", "e8e8e0", "6f8a6a"][randi() % 4]), 0.8)
			sup.position = Vector3(q[0] + randf_range(-2.6, 2.6), 0.34 + floorf(k / 3.0) * 0.9 + 0.2, q[1] + randf_range(-0.2, 0.2)); G.add_child(sup)
		Phys.add_collider(q[0] - 3, 0, q[1] - 0.6, q[0] + 3, 2.6, q[1] + 0.6, "metal")
	var wm := MeshInstance3D.new(); wm.mesh = Gfx.merge_boxes(walls); var wmat := StandardMaterial3D.new(); wmat.vertex_color_use_as_albedo = true; wmat.roughness = 0.7; wm.material_override = wmat; G.add_child(wm)
	var frame := MeshInstance3D.new(); frame.mesh = Gfx.merge_boxes([[10, 0.8, 0.8, 0, 7.4, 0], [0.8, 7.4, 0.8, -4.6, 3.7, 0], [0.8, 7.4, 0.8, 4.6, 3.7, 0]]); frame.material_override = Gfx.std(World.lin("30363c"), 0.5, 0.6)
	frame.position = Vector3(0, 0, E - 0.3); G.add_child(frame)
	var dm := _tex_box(Vector3(8.4, 7.0, 0.4), door_tex(), 0.55, 1, 1, 0, 0, 0.5); dm.position = Vector3(0, 3.5, E - 0.15); G.add_child(dm); door = dm
	# wooden crates: in the middle and the aisles, never where a cage wall will land
	var in_fall := func(x: float, z: float, m: float) -> bool:
		for c in cages:
			if absf(x - c.x) < c.w / 2 + c.h + m and absf(z - c.z) < c.d / 2 + c.h + m: return true
		return false
	w._place_crates(G, int(S.crates), func() -> Array: var x := R.rng(-E + 2, E - 2); var z := R.rng(-E + 2, E - 2); return [x, z],
		func(x: float, z: float) -> bool: return Vector2(x, z - (E - 4.5)).length() > 6 and not in_fall.call(x, z, 0.9) and not Phys.box_at(x, z, 1.2, 0.05, 1.25))
	Phys.index_colliders(); Phys.build_nav()
	w.start = {"x": 0.0, "z": E - 4.5, "yaw": 0.0}; w.spawns.clear()

## one wall of a cage: posts, rails and bars, standing on its hinge line; it falls outwards when the cage opens
func _panel(G: Node3D, c: Dictionary, side: String) -> Dictionary:
	var along := side == "n" or side == "s"; var W: float = c.w if along else c.d - 0.3; var H: float = c.h; var tk := 0.16; var off := (int(c.n) % 2) * 0.15
	var parts := [[tk, H, tk, -W / 2 + tk / 2, H / 2, -tk / 2, "8d949c"], [tk, H, tk, W / 2 - tk / 2, H / 2, -tk / 2, "8d949c"], [W, 0.14, tk, 0, H - 0.07, -tk / 2, "8d949c"], [W, 0.16, tk, 0, 0.08, -tk / 2, "8d949c"],
		[W, 0.07, 0.07, 0, H * 0.52, -tk / 2, "8d949c"]]
	var x := -W / 2 + 0.3 + off
	while x < W / 2 - 0.2: parts.push_back([0.05, H - 0.2, 0.05, x, H / 2, -tk / 2, "8d949c"]); x += 0.3
	var P := Node3D.new(); var F := Node3D.new(); P.add_child(F)
	var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); m.material_override = _bar_mat; F.add_child(m)
	if _kick_mat == null: _kick_mat = Gfx.std(Color.WHITE, 0.7, 0.0, hazard_tex()); _kick_mat.uv1_scale = Vector3(6, 1, 1); _kick_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var kick := MeshInstance3D.new(); var kq := QuadMesh.new(); kq.size = Vector2(W - 0.3, 0.42); kick.mesh = kq; kick.material_override = _kick_mat; kick.position = Vector3(0, 0.42, 0.005); F.add_child(kick)
	var glassy: bool = c.boss or seq
	if glassy:   # lined with bulletproof glass: nothing gets through until it is let out
		var g := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(W - 0.3, H - 0.3); g.mesh = q; g.material_override = _glass_mat; g.position = Vector3(0, H / 2, -tk - 0.03); F.add_child(g)
	var hy := 0.03 + (int(c.n) % 4) * 0.012; var hw: float = c.w / 2; var hd: float = c.d / 2; var T := 0.25; var col: Phys.Box
	match side:
		"n": P.position = Vector3(c.x, hy, c.z - hd); P.rotation.y = PI; col = Phys.add_collider(c.x - hw, 0, c.z - hd, c.x + hw, H, c.z - hd + T, "metal")
		"s": P.position = Vector3(c.x, hy, c.z + hd); col = Phys.add_collider(c.x - hw, 0, c.z + hd - T, c.x + hw, H, c.z + hd, "metal")
		"e": P.position = Vector3(c.x + hw, hy, c.z); P.rotation.y = PI / 2; col = Phys.add_collider(c.x + hw - T, 0, c.z - hd, c.x + hw, H, c.z + hd, "metal")
		_: P.position = Vector3(c.x - hw, hy, c.z); P.rotation.y = -PI / 2; col = Phys.add_collider(c.x - hw, 0, c.z - hd, c.x - hw + T, H, c.z + hd, "metal")
	G.add_child(P); MoonShadow.caster(P)   # the cage's frame and bars cast the moon's shadow, as there
	col.grate = true; col.glass = glassy   # bullets and eyes pass between the bars, but not through glass
	return {"side": side, "P": P, "F": F, "col": col, "fall_t": -1.0, "wob": 0.0, "W": W, "H": H}

## the mad scientist: a chimp in a lab coat with goggles and wild white hair (the browser game's buildMonkey)
var _mk_body: Node3D; var _mk_head: Node3D; var _leg_l: Node3D; var _leg_r: Node3D; var _mk_base_y := 0.0; var _mode_t := 3.0
func _build_monkey(G: Node3D, at: Vector3) -> void:
	var fur := "4a3122"; var skin := "c9a183"; var coat := "eef0ec"
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.8
	var mesh := func(parent: Node3D, list: Array, m: Material = null) -> void:
		var x := MeshInstance3D.new(); x.mesh = Gfx.merge_boxes(list); x.material_override = m if m else mat; parent.add_child(x)
	monkey = Node3D.new(); monkey.position = at; monkey.scale = Vector3.ONE * 1.6; G.add_child(monkey); _mk_base_y = at.y
	_mk_body = Node3D.new(); _mk_body.position.y = 0.5; monkey.add_child(_mk_body)
	mesh.call(_mk_body, [[0.34, 0.46, 0.26, 0, 0.26, 0, fur], [0.4, 0.5, 0.3, 0, 0.24, 0.005, coat], [0.42, 0.3, 0.31, 0, -0.06, 0, coat], [0.12, 0.34, 0.02, 0, 0.3, 0.16, "ffffff"], [0.08, 0.06, 0.02, 0.1, 0.36, 0.16, "3a6fb0"]])
	_mk_head = Node3D.new(); _mk_head.position = Vector3(0, 0.62, 0.02); _mk_body.add_child(_mk_head)
	mesh.call(_mk_head, [[0.3, 0.28, 0.27, 0, 0.1, 0, fur], [0.23, 0.2, 0.07, 0, 0.07, 0.13, skin], [0.15, 0.09, 0.08, 0, 0.0, 0.17, "b48466"],
		[0.08, 0.11, 0.04, -0.18, 0.1, 0, skin], [0.08, 0.11, 0.04, 0.18, 0.1, 0, skin], [0.32, 0.045, 0.3, 0, 0.14, 0, "1d1f22"],
		[0.05, 0.13, 0.05, -0.09, 0.3, -0.02, "f4f4f0", [0, 0, 0.5]], [0.05, 0.15, 0.05, 0.08, 0.31, 0.0, "f4f4f0", [0.2, 0, -0.5]],
		[0.05, 0.12, 0.05, 0, 0.32, -0.08, "f4f4f0", [-0.5, 0, 0]], [0.05, 0.11, 0.05, -0.16, 0.26, -0.04, "f4f4f0", [0, 0, 1.0]], [0.05, 0.11, 0.05, 0.16, 0.26, -0.04, "f4f4f0", [0, 0, -1.0]],
		[0.1, 0.02, 0.02, 0, -0.04, 0.2, "2a1a12"]])
	mesh.call(_mk_head, [[0.08, 0.065, 0.03, -0.065, 0.14, 0.15], [0.08, 0.065, 0.03, 0.065, 0.14, 0.15]], Gfx.untoned(Color("8ff0ff"), null, _ex))   # the goggles' lenses, glowing
	for sx in [-1.0, 1.0]:
		var a := Node3D.new(); a.rotation_order = EULER_ORDER_YXZ; a.position = Vector3(sx * 0.24, 0.46, 0); _mk_body.add_child(a)
		mesh.call(a, [[0.13, 0.3, 0.13, 0, -0.14, 0, coat], [0.09, 0.3, 0.09, 0, -0.42, 0, fur], [0.1, 0.1, 0.12, 0, -0.6, 0.02, skin]])
		var l := Node3D.new(); l.position = Vector3(sx * 0.1, 0.5, 0); monkey.add_child(l)
		mesh.call(l, [[0.12, 0.42, 0.13, 0, -0.24, 0, fur], [0.12, 0.06, 0.2, 0, -0.48, 0.04, skin]])
		if sx < 0: _arm_l = a; _leg_l = l
		else: _arm_r = a; _leg_r = l
	MoonShadow.caster(monkey)   # it casts the moon's shadow and, as there, takes none
	for n in monkey.find_children("*", "MeshInstance3D", true, false): MoonShadow.no_receive(n)

## the animals go in their cages: twelve of each kind in a loose grid (three giraffes, two elephants), the boss alone in the last one

func populate(put: Callable, SR: World.Rng, boss_opts: Dictionary) -> void:
	for c in cages:
		if c.boss:
			var o := {"boss": true, "yaw": 0.0}; o.merge(boss_opts, true)
			var e = put.call("gorilla", {"x": c.x, "z": c.z}, o)
			if e != null: e.cage = c; e.caged = true; c.animals.push_back(e); e.glassed = true   # behind its glass nothing hurts it
			continue
		var T: Dictionary = Animals.ANIMALS[c.type]; var sc: float = c.get("scale", 1.0); var count: int = c.get("count", 12); var cols := mini(4, count); var rows := ceili(float(count) / cols)
		var iw: float = c.w - 1.2; var id: float = c.d - 1.2; var cw := iw / cols; var ch := id / rows
		for k in count:
			var i := k % cols; var j := k / cols; var jx := maxf(0.0, cw / 2 - T.r * sc - 0.2); var jz := maxf(0.0, ch / 2 - T.r * sc - 0.2)
			var x: float = c.x - iw / 2 + cw * (i + 0.5) + (SR.next() * 2 - 1) * jx; var z: float = c.z - id / 2 + ch * (j + 0.5) + (SR.next() * 2 - 1) * jz
			var yaw := SR.next() * TAU
			var e = put.call(c.type, {"x": x, "z": z}, {"yaw": yaw, "scale": sc})
			if e != null: e.cage = c; e.caged = true; c.animals.push_back(e); e.glassed = seq   # 3-2: every cage is glass

## a cage opens: its walls stop blocking at once and start to fall, and the animals inside are let loose
func open(c: Dictionary) -> void:
	c.open = true; c.opened_t = t
	for p in c.panels: Phys.remove_collider(p.col); p.fall_t = 0.0; p.wob = 0.0
	Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	var left := 0
	for e in c.animals:
		if e.alive: left += 1; e.caged = false; e.release_t = randf_range(0.15, 0.9); e.alert = true; e.awake = true   # awake however far away you are, so they really come out
	var at := Vector3(c.x, c.h, c.z); Snd.play("alarm"); Snd.play("clank", 1.0, at); Snd.buzz(60)
	var nm: String = Animals.ANIMALS[c.type].name
	if game:
		if c.boss: game.say_banner("10번 우리 열림", "보스 " + Game.BOSS[3].name + " · 조심하세요", 2.8)
		else: game.say_banner("%d번 우리 열림" % c.n, "%s %d마리" % [nm, left], 1.8)
		game.say_feed("%d번 우리 열림 · %s%s" % [c.n, nm, "" if c.boss else " %d마리" % left])

func _fall(c: Dictionary, dt: float) -> void:
	for p in c.panels:
		if p.fall_t >= 0.0 and p.fall_t < 1.6:
			p.fall_t += dt; var ft: float = p.fall_t; var T := 0.72
			var a: float = (PI / 2) * (ft / T) * (ft / T) if ft < T else PI / 2 - 0.13 * absf(sin((ft - T) * 13.0)) * exp(-(ft - T) * 7.0)
			if ft >= 1.6: a = PI / 2
			(p.F as Node3D).rotation.x = a
			if ft >= T and not p.get("dust", false):   # dust along the far edge where the wall slapped down
				p.dust = true
				if fx:
					var yw: float = (p.P as Node3D).rotation.y; var ox := sin(yw); var oz := cos(yw); var tx := cos(yw); var tz := -sin(yw); var pp: Vector3 = (p.P as Node3D).position
					for k in range(-2, 3): fx.puff(Vector3(pp.x + ox * p.H * 0.8 + tx * k * p.W * 0.22, 0.3, pp.z + oz * p.H * 0.8 + tz * k * p.W * 0.22), 2, 0.75, 0.9)
			if ft >= T and not c.clang:
				c.clang = true; Snd.play("clang", 1.0, Vector3(c.x, 0.4, c.z))
				var d := Vector2(player.pos.x - c.x, player.pos.z - c.z).length()
				if d < 30.0: player.shake = maxf(player.shake, 0.22 * (1.0 - d / 30.0))
		elif p.fall_t < 0.0 and p.wob > 0.0: p.wob = maxf(0.0, p.wob - dt * 2.2); (p.F as Node3D).rotation.x = sin(t * 40.0) * 0.025 * p.wob

## an animal hit the bars from inside: that wall shakes
func rattle(c: Dictionary, x: float, z: float) -> void:
	var best = null; var bd := 1e9
	for p in c.panels:
		var d := Vector2(p.P.position.x - x, p.P.position.z - z).length()
		if d < bd: bd = d; best = p
	if best != null and best.fall_t < 0.0: best.wob = 1.0; Snd.play("clank", 1.0, Vector3(x, 1, z))

## 3-2: how many of the animals let out of the cage before this one are still loose and wild
func wait_left(c: Dictionary) -> int:
	if int(c.n) < 2: return 0
	var prev: Dictionary = cages[int(c.n) - 2]; var n := 0
	for e in prev.animals:
		if e.alive and not e.tamed: n += 1
	return n + (0 if prev.open else 99)

## the next cage to open, for the HUD
func next_cage():
	var best = null
	for c in cages:
		if not c.open and (best == null or c.open_at < best.open_at): best = c
	if best == null: return null
	if best.open_at == INF:   # 3-2: the lowest-numbered one still shut
		for c in cages:
			if not c.open: return c
	return best

func update(dt: float) -> void:
	if not running: running = true; clock = true; alarm = true
	t += dt
	if push_t >= 0.0:   # the monkey's arm is on its way to the button
		push_t -= dt
		if push_t < 0.0 and reach != null: reach.held = false; reach.open_at = t + 0.5; reach = null; Snd.play("press"); Snd.buzz(40)
	for c in cages:
		if c.held:
			# 3-2: shut until the cage before it is empty (every animal dead or tamed); then the monkey reaches out and pushes his button
			var prev: Dictionary = cages[int(c.n) - 2]
			if reach == null and prev.open and wait_left(c) == 0:
				reach = c; push_t = 0.45; monkey_mode = "reach"; monkey_t = 0.0; Snd.play("cackle", 1.0, Vector3(0, WIN.y0 + 1.5, -HALF - 3))
				if game: game.say_banner("%d번 우리를 비웠습니다" % prev.n, "원숭이 박사가 %d번 우리 버튼을 누릅니다 · %s%s" % [c.n, Animals.ANIMALS[c.type].name, " (보스)" if c.boss else ""], 2.4)
		elif not c.open:
			var remain: float = c.open_at - t; var s := ceili(remain)
			if s <= 3 and s >= 1 and c.last_beep != s: c.last_beep = s; Snd.play("beep", 1.0, Vector3(c.x, c.h + 2, c.z))
			if remain <= 0.0: open(c)
		_fall(c, dt); _draw(c)

## the monkey's red button: the boards light up and the alarm starts (the clock itself runs once play begins)
func press() -> void:
	pressed = true; alarm = true; clock = true
	for c in cages: _draw(c)

func monkey_press(at: float) -> void:
	monkey_mode = "press"; monkey_t = 0.0; _press_at = at

## the countdown board hanging over each cage (src/04g_lab.js display): a dark case on two cables, the same screen on all four sides
var _case_mat: StandardMaterial3D
var _bf := {}
func _board(G: Node3D, c: Dictionary) -> void:
	if _case_mat == null:
		_case_mat = StandardMaterial3D.new(); _case_mat.albedo_color = World.lin("1c2026"); _case_mat.roughness = 0.5; _case_mat.metallic = 0.6
		_bf = {"mono": load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf"), "bold": load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"), "title": load("res://fonts/blackhansans_BlackHanSans-Regular.ttf")}
	var vp := SubViewport.new(); vp.size = Vector2i(256, 128); vp.disable_3d = true; vp.render_target_update_mode = SubViewport.UPDATE_ONCE; G.add_child(vp)
	var cv := Control.new(); cv.size = Vector2(256, 128); vp.add_child(cv); cv.draw.connect(func() -> void: _paint(cv, c))
	var sz: float = 3.2 if c.boss else 2.4; var y: float = c.h + (2.6 if c.boss else 2.1)
	var root := Node3D.new(); root.position = Vector3(c.x, y, c.z); G.add_child(root)
	var box := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(sz - 0.01, sz * 0.5 - 0.01, sz - 0.01); box.mesh = bm; box.material_override = _case_mat; root.add_child(box)
	var face := Gfx.untoned(Color.WHITE, vp.get_texture(), _ex)   # (the board's face is drawn untoned, as there)
	for k in 4:
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(sz, sz * 0.5); q.mesh = qm; q.material_override = face
		q.rotation.y = k * PI / 2.0; q.position = Vector3(sin(k * PI / 2.0), 0, cos(k * PI / 2.0)) * sz / 2.0; root.add_child(q)
	for sx in [-1.0, 1.0]:   # the cables up to the ceiling
		var cab := MeshInstance3D.new(); var cm := BoxMesh.new(); var len := CEIL - y - sz * 0.25; cm.size = Vector3(0.05, len, 0.05); cab.mesh = cm; cab.material_override = _case_mat
		cab.position = Vector3(sx * sz * 0.35, sz * 0.25 + len / 2.0, 0); root.add_child(cab)
	c.board = {"vp": vp, "cv": cv}

## the board over a cage: its number, the animal, the seconds left (drawn again only when what it shows changes)
func _draw(c: Dictionary) -> void:
	var remain: float = maxf(0.0, c.open_at - t); var sec := ceili(remain) if c.open_at != INF else -1
	var key: String = ("열림" if t - c.opened_t < 4.0 else "—") if c.open else ("잠김" if c.held else ("- -" if not clock else ("%d:%02d" % [sec / 60, sec % 60] if sec >= 60 else str(sec))))
	if c.shown == key: return
	c.shown = key; c.sec = sec
	var b: Dictionary = c.board; (b.cv as Control).queue_redraw(); (b.vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

func _paint(cv: Control, c: Dictionary) -> void:
	var w := 256.0; var h := 128.0; var key: String = c.shown; var sec: int = c.get("sec", -1); var off: bool = not clock and not c.open and not c.held
	var col := Color("5ed6b0") if c.open else (Color("8fb8ff") if c.held else (Color("3a4250") if off else (Color("ff4b4b") if sec <= 3 else Color("f2a33a"))))
	cv.draw_rect(Rect2(0, 0, w, h), Color("0a0d12"))
	cv.draw_rect(Rect2(3, 3, w - 6, h - 6), Color(94 / 255.0, 214 / 255.0, 176 / 255.0, 0.6) if c.open else (Color(1, 75 / 255.0, 75 / 255.0, 0.8) if (sec <= 3 and not off and not c.held) else Color(242 / 255.0, 163 / 255.0, 58 / 255.0, 0.35)), false, 6.0)
	var mono: Font = _bf.mono; var bold: Font = _bf.bold; var title: Font = _bf.title; var ink := Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.85)
	cv.draw_string(mono, Vector2(14, 12 + mono.get_ascent(20)), "%02d" % int(c.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	var nm: String = ("보스 · " + str(Animals.ANIMALS[c.type].name)) if c.boss else str(Animals.ANIMALS[c.type].name) + " ×12"
	cv.draw_string(bold, Vector2(w - 14 - bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 12 + bold.get_ascent(20)), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	var mid := func(text: String, font: Font, fs: int, y: float) -> void:
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x; cv.draw_string(font, Vector2(w / 2.0 - tw / 2.0, y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if c.open: mid.call(key, title, 58, 80)
	elif off: mid.call("- -", title, 64, 80)
	elif c.held: mid.call("잠김", title, 50, 66); mid.call("앞 우리를 비우면 열림", bold, 17, 106)
	else: mid.call(key, title, 76, 82)

## things that move whatever the game state is: the monkey, the beacons
func anim(dt: float, time: float) -> void:
	monkey_t += dt; _mode_t -= dt
	if monkey_mode in ["idle", "cackle", "clap"] and _mode_t <= 0.0: monkey_mode = ["idle", "idle", "cackle", "clap"][randi() % 4]; _mode_t = randf_range(2, 4.5)
	var al := Vector3(0, 0, 0.15); var ar := Vector3(0, 0, -0.15); var jump := 0.0; var bx := 0.0; var hx := 0.0; var hz := 0.0
	match monkey_mode:
		"press":   # the right fist up high, then down on the button, then a cackle
			var k := monkey_t - _press_at
			if k < 0.0: ar = Vector3(-3.0, 0, -0.2); al = Vector3(-1.2, 0.5, 0.3); hx = -0.3; jump = absf(sin(monkey_t * 9.0)) * 0.05
			elif k < 0.12: ar = Vector3(-3.0 + k / 0.12 * 1.85, 0, -0.2); hx = 0.2
			else:
				ar = Vector3(-1.15, 0, -0.2); hx = 0.25; al = Vector3(-2.6, 0, 0.6)
				if k > 0.5: var s5 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s5 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s5 * 0.25, 0, -0.5); hx = -0.35; jump = absf(sin(monkey_t * 7.0)) * 0.12
		"cackle": var s6 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s6 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s6 * 0.25, 0, -0.5); hx = -0.35 + s6 * 0.08; jump = absf(sin(monkey_t * 7.0)) * 0.12
		"clap": var s7 := sin(monkey_t * 16.0); al = Vector3(-1.3, 0.9 + s7 * 0.35, 0); ar = Vector3(-1.3, -0.9 - s7 * 0.35, 0); hx = -0.15; jump = absf(s7) * 0.03
		"panic": var s := sin(monkey_t * 24.0); al = Vector3(-2.9, 0, 0.9 + s * 0.4); ar = Vector3(-2.9, 0, -0.9 - s * 0.4); hz = s * 0.3; jump = absf(sin(monkey_t * 10.0)) * 0.25; bx = sin(monkey_t * 3.0) * 2.2
		"reach":   # 3-2: a long arm out over the console, a push on the button, then a cackle
			if monkey_t < 0.45: ar = Vector3(-1.55 * monkey_t / 0.45, 0, -0.1); al = Vector3(-0.4, 0, 0.2); hx = 0.25 * monkey_t / 0.45
			elif monkey_t < 0.62: ar = Vector3(-1.05, 0, -0.1); hx = 0.3
			else:
				var s2 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s2 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s2 * 0.25, 0, -0.5); hx = -0.35; jump = absf(sin(monkey_t * 7.0)) * 0.12
				if monkey_t > 1.8: monkey_mode = "idle"; _mode_t = 2.0
		_:   # rocking about
			var s4 := sin(monkey_t * 2.2); bx = s4 * 0.06; hz = s4 * 0.12; al = Vector3(-0.3 + s4 * 0.1, 0, 0.2); ar = Vector3(-0.8, -0.6, -0.3); hx = -0.05
	var f := 1.0 - exp(-dt * 14.0)
	if _arm_l:
		_arm_l.rotation = _arm_l.rotation.lerp(al, f); _arm_r.rotation = _arm_r.rotation.lerp(ar, f)
		_mk_head.rotation.x = lerpf(_mk_head.rotation.x, hx, f); _mk_head.rotation.z = lerpf(_mk_head.rotation.z, hz, f)
		monkey.position.x = lerpf(monkey.position.x, bx, f * 0.5); monkey.position.y = _mk_base_y + jump
		_leg_l.rotation.x = -jump * 2.0; _leg_r.rotation.x = -jump * 2.0
	if door != null: door.position.y = 3.5 + door_open * 6.6
	for i in beacons.size():
		var on := alarm and fmod(time * 1.6 + i * 0.25, 1.0) < 0.5; var bc := Color("ff2a20") if on else Color("401010")
		(beacons[i].b.material_override as ShaderMaterial).set_shader_parameter("mul", Vector3(bc.r, bc.g, bc.b)); beacons[i].s.visible = on
