class_name Ship
extends RefCounted
## Stage 4: inside a spaceship. From the airlock a narrow dog-leg passage climbs north into a long corridor (160 m). The bridge is at
## its west end (two storeys, a gallery at 7 m), the main hall at its east end with the reactor in the middle. Both have sliding doors.
## Ported from src/04f_ship.js: the same walls, the same colliders in the same order, the same crates.

const ROOMS := [   # x0, z0, x1, z1, ceiling height, kind
	[-123.0, -28.0, -92.0, 13.0, 16.0, "bridge"], [-92.0, -12.5, 68.0, -2.5, 6.0, "corr"], [68.0, -48.0, 162.0, 45.0, 16.0, "hall"],
	[-26.5, -2.5, -22.0, 7.0, 4.5, "pass"], [-44.0, 7.0, -22.0, 13.0, 4.5, "pass"], [-44.0, 13.0, -39.5, 25.0, 4.5, "pass"], [-44.0, 25.0, -39.5, 29.5, 4.5, "lock"]]
const START := {"x": -41.75, "z": 22.6, "yaw": 0.0}
const DOOR_Z := 25.0
const REACTOR := {"x": 120.0, "z": -6.0, "r": 1.7}
const DAIS := [[96.0, -28.0, 144.0, 16.0, 0.45], [105.0, -20.0, 135.0, 8.0, 0.9], [112.0, -14.0, 128.0, 2.0, 1.35]]
const PILLARS := [[80.0, -34.0], [80.0, 30.0], [154.0, -36.0], [154.0, 32.0]]   # 1.2 m half-width, floor to ceiling
const BRIDGE := {"gy": 7.0, "x0": -123.0, "x1": -92.0, "z0": -28.0, "z1": 13.0, "stairX0": -117.0, "stairX1": -107.4, "eastX": -97.0, "steps": 16}
const DOORS := [{"x": -91.7, "z0": -12.5, "z1": -2.5, "h": 6.0, "name": "운전실", "inward": -1.0, "room": "bridge", "who": "gdrone", "title": "황금꿀벌드론", "tone": "bee", "needKey": false},
	{"x": 67.7, "z0": -12.5, "z1": -2.5, "h": 6.0, "name": "메인홀", "inward": 1.0, "room": "hall", "who": "bdrone", "title": "최첨단 감시 드론 보스 B-3", "tone": "boss", "needKey": true}]
const KEY := Vector3(-105, 1.6, -7.5)   # the main hall's key, stuck upright in the commander's console on the bridge
const SAVE := {"x": -98.5, "z": -7.5, "yaw": -PI / 2}   # where the save point puts you back
const HATCHES := [[75.2, -16.0], [75.2, 22.0], [90.0, 40.0], [118.0, 40.8], [150.0, 20.0], [150.0, -28.0], [118.0, -42.8], [86.0, -38.0]]
# under the hall's floor, round the reactor, an upside-down stepped pyramid: three flights of eight 37.5 cm steps, two landings, 9 m down
const PYR_OX := 27.0
const PYR_OZ := 25.0
const PYR_BOTTOM := -9.0

var steps: Array = []     # {k, ax, az, y, w, land}
var air_door: Node3D      # the airlock's inner door: it rolls up as the stage starts and shuts behind you
var door_open := 0.0
var closing := false
var on_cut: Callable = Callable()   # the look inside a sealed door (main's cutscene); without it you are simply put inside
var pyr_bx := 0.0; var pyr_bz := 0.0
var doors: Array = []
var hatches: Array = []
var hatch_q: Array = []
var hatch_wait := 0.0
var key := false
var key_obj: Node3D
var key_hint_t := 0.0
var save_t := 0.0
var pit := {}
var broken := false
var break_t := 0.0
var player: Player
var game = null
var enemies = null
var world: World
var fx: Fx = null
var core_mat: StandardMaterial3D
var ring: Node3D            # the slow ring over the reactor
var screens_mat: StandardMaterial3D   # the bridge's screens, flickering
var key_glow: MeshInstance3D

static func room_at(x: float, z: float) -> Array:   # the room a point is in (the airlock does not count: you never get in there)
	for R: Array in ROOMS:
		if R[5] != "lock" and x >= R[0] and x <= R[2] and z >= R[1] and z <= R[3]: return R
	return []
static func ceil_at(x: float, z: float) -> float:
	for R: Array in ROOMS:
		if R[5] != "lock" and x >= R[0] and x <= R[2] and z >= R[1] and z <= R[3]: return R[4]
	return 30.0
static func in_pit(x: float, z: float, m := 0.0) -> bool:
	return absf(x - REACTOR.x) < PYR_OX + m and absf(z - REACTOR.z) < PYR_OZ + m

# ---- the browser game's canvases for the ship (drawn once, then kept) ----
static var _tx := {}
static func _c(r: int, g: int, b: int, a := 1.0) -> Color: return Color(r / 255.0, g / 255.0, b / 255.0, a)
static func _grid(img: Image, n: int, col: Color, lw: float, both := true) -> void:   # canvas strokes at k * size / n, k = 0..n
	var w := float(img.get_width()); var h := float(img.get_height())
	for k in n + 1:
		Gfx.frect(img, k * w / n - lw / 2, 0, lw, h, col)
		if both: Gfx.frect(img, 0, k * h / n - lw / 2, w, lw, col)
## the corridor's floor plates: speckled steel in a four-by-four grid, a rivet at each corner, darker wear (6 m a picture)
static func plate_tex() -> ImageTexture:
	if not _tx.has("plate"):
		var w := 512; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("2b3039"))
		Gfx.speckle(img, 5000, [Color("30353f"), Color("262a32"), Color("343a45")], 1.6); _grid(img, 4, _c(12, 14, 18, 0.9), 3)
		var c4 := w / 4.0
		for i in 4:
			for j in 4:
				for d: Vector2 in [Vector2(10, 10), Vector2(c4 - 10, 10), Vector2(10, c4 - 10), Vector2(c4 - 10, c4 - 10)]: Gfx.fellipse(img, i * c4 + d.x, j * c4 + d.y, 2.5, 2.5, 0.0, _c(160, 170, 190, 0.35))
		for i in 10: Gfx.fellipse(img, randf() * w, randf() * w, randf_range(15, 60), randf_range(6, 25), randf_range(0, 3), _c(8, 10, 14, randf_range(0.1, 0.25)))
		_tx.plate = Gfx.tex(img)
	return _tx.plate
## the hall's floor: darker plates, two by two, two of them outlined in faint cyan
static func hall_tex() -> ImageTexture:
	if not _tx.has("hall"):
		var w := 512; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("1f242d"))
		Gfx.speckle(img, 4000, [Color("232832"), Color("1b1f27"), Color("272d38")], 1.6); _grid(img, 2, _c(8, 10, 14, 0.95), 4)
		Gfx.srect(img, 26, 26, w / 2.0 - 52, w / 2.0 - 52, _c(90, 200, 255, 0.35), 2); Gfx.srect(img, w / 2.0 + 26, w / 2.0 + 26, w / 2.0 - 52, w / 2.0 - 52, _c(90, 200, 255, 0.35), 2)
		_tx.hall = Gfx.tex(img)
	return _tx.hall
## the walls: upright panels in two shades, a dark seam half-way up, a yellow line near the foot (3 m a picture)
static func panel_tex() -> ImageTexture:
	if not _tx.has("panel"):
		var w := 256; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("3a404d"))
		for x in range(0, w, 64): Gfx.frect(img, x + 2, 2, 60, w - 4, Color("353a46") if (x / 64) % 2 else Color("3f4653"))
		Gfx.frect(img, 0, w / 2.0 - 2, w, 4, _c(10, 12, 16, 0.8)); Gfx.frect(img, 0, w - 10, w, 6, _c(200, 170, 60, 0.5))
		Gfx.speckle(img, 1200, [Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.05)], 1.5)
		_tx.panel = Gfx.tex(img)
	return _tx.panel
## the passage's floor and the bridge's stairs: a steel grating
static func grate_tex() -> ImageTexture:
	if not _tx.has("grate"):
		var w := 128; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("1c2027"))
		for i in range(0, w, 8): Gfx.frect(img, i, 0, 3, w, Color("4a5260")); Gfx.frect(img, 0, i, w, 3, Color("4a5260"))
		_tx.grate = Gfx.tex(img)
	return _tx.grate
## the bridge's carpet: dark blue, a faint line across
static func carpet_tex() -> ImageTexture:
	if not _tx.has("carpet"):
		var w := 256; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("1a2233"))
		Gfx.speckle(img, 3000, [Color("1d2639"), Color("161d2b"), Color("202a3f")], 1.4); Gfx.frect(img, 0, w / 2.0 - 1, w, 2, _c(120, 170, 255, 0.18))
		_tx.carpet = Gfx.tex(img)
	return _tx.carpet
## the ceilings: dark tiles, two by two (4 m a picture)
static func ceil_tex() -> ImageTexture:
	if not _tx.has("ceil"):
		var w := 256; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("22262e"))
		_grid(img, 2, Color("15181d"), 4); Gfx.speckle(img, 800, [Color(1, 1, 1, 0.04), Color(0, 0, 0, 0.2)], 1.5)
		_tx.ceil = Gfx.tex(img)
	return _tx.ceil
## the pit's steps: plates in four columns, faint ribs across
static func step_tex() -> ImageTexture:
	if not _tx.has("step"):
		var w := 256; var img := Image.create(w, w, false, Image.FORMAT_RGBA8); img.fill(Color("262b34"))
		Gfx.speckle(img, 2600, [Color("2a3039"), Color("21252d"), Color("2e343f")], 1.4); _grid(img, 4, _c(8, 10, 14, 0.9), 3, false)
		for y in range(6, w, 14): Gfx.frect(img, 0, y, w, 2, _c(150, 175, 210, 0.10))
		_tx.step = Gfx.tex(img)
	return _tx.step
## space through the windows: stars, a planet rising from below at planet_x across, the frames between the panes
static func space_tex(planet_x: float) -> ImageTexture:
	var key_ := "space%.2f" % planet_x
	if not _tx.has(key_):
		var w := 1024; var h := 256; var img := Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(Color("02040a"))
		for i in 700: Gfx.frect(img, randf() * w, randf() * h, randf_range(1, 2.4), randf_range(1, 2.4), _c(220, 230, 255, randf_range(0.25, 1)))
		# the planet: a canvas radial gradient from 20 to h * 1.15 round (w * planet_x, h * 1.25), worked out a quarter size and enlarged
		var stops := [[0.0, Color("9fd0ff")], [0.55, Color("3a6aa8")], [0.9, Color("0e1c38")], [1.0, Color(0, 0, 0, 0)]]
		var g := Image.create(w / 4, h / 4, false, Image.FORMAT_RGBA8); var gc := Vector2(w * planet_x, h * 1.25); var r1 := h * 1.15
		for y in h / 4:
			for x in w / 4:
				var t := clampf((Vector2(x * 4 + 2, y * 4 + 2).distance_to(gc) - 20.0) / (r1 - 20.0), 0.0, 1.0); var c: Color = stops[3][1]
				for k in 3:
					if t <= stops[k + 1][0]: c = (stops[k][1] as Color).lerp(stops[k + 1][1], (t - stops[k][0]) / (stops[k + 1][0] - stops[k][0])); break
				g.set_pixel(x, y, c)
		g.resize(w, h, Image.INTERPOLATE_BILINEAR); img.blend_rect(g, Rect2i(0, 0, w, h), Vector2i.ZERO)
		for k in 6: Gfx.frect(img, k * w / 5.0 - 5, 0, 10, h, _c(30, 36, 48))   # the frame between the panes
		_tx[key_] = Gfx.tex(img)
	return _tx[key_]
## a sign after the drawing: a worn dark plate in a thick frame, the name in heavy old-style letters, a block arrow at the end it
## points to (left, right, or up for straight on). Bridge orange, hall green
static func sign_tex(text: String, dir: String, col: Color) -> ImageTexture:
	var key_ := "sign" + text + dir
	if not _tx.has(key_):
		var w := 1024; var h := 320; var img := Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(Color("0e1219"))
		for i in 1400: Gfx.frect(img, randf() * w, randf() * h, 1 + randf() * 3, 1 + randf() * 3, Color(1, 1, 1, randf() * 0.035))
		Gfx.srect(img, 16, 16, w - 32, h - 32, col, 16)
		var aw := 280.0; var left := dir == "left"; var ax := 48.0 if left else w - 48.0 - aw; var cy := h / 2.0
		if dir == "up":   # a tall arrow: head on top, shaft below
			var cx := ax + aw / 2; var top := 46.0; var bot := h - 46.0; var hw := 118.0; var sw := 46.0; var neck := top + 120
			Gfx.ftri(img, Vector2(cx, top), Vector2(cx + hw, neck), Vector2(cx - hw, neck), col); Gfx.frect(img, cx - sw, neck, 2 * sw, bot - neck, col)
		else:   # a long arrow: shaft, then a broad head; mirrored for the left
			var sg := -1.0 if left else 1.0; var x0 := ax + aw if left else ax; var tip := x0 + sg * aw; var neck := x0 + sg * aw * 0.5; var hh := 112.0; var sh := 44.0
			Gfx.frect(img, minf(x0, neck), cy - sh, absf(neck - x0), 2 * sh, col); Gfx.ftri(img, Vector2(neck, cy - hh), Vector2(tip, cy), Vector2(neck, cy + hh), col)
		var tx := (ax + aw + w - 48) / 2 + 10 if left else (48 + ax) / 2 - 10
		Gfx.text(img, text, load("res://fonts/yardsign_hahmlet_subset.woff2"), 176, tx, cy + 10, "center", "middle", col, 5, Color("0e1219"))
		_tx[key_] = Gfx.tex(img)
	return _tx[key_]
## the ship's doors, drawn by the owner of this port: a dark panel in a black frame, a blue seam of light down the middle, and in
## the middle a black ring that the seam crosses in an S. The bridge's and the hall's two leaves part along that seam, S and all;
## the airlock's door rises in one piece and the sealed doors along the corridor stay shut, with the same face
const RING_R := 0.215      # the ring's radius, as a share of the door's height
const RING_W := 0.055      # its line, as a share of the height
const SEAM_S := 0.28       # how far the seam swings out each way inside the ring, as a share of its radius
const SEAM_W := 0.022      # the seam's line, as a share of the height
## where the seam runs at height v (metres from the floor), measured across the door from its left edge
static func seam_u(v: float, w: float, h: float) -> float:
	var R := RING_R * h; var y := (h * 0.5 - v) / R   # -1 at the ring's top, 1 at its bottom
	if absf(y) >= 1.0: return w * 0.5
	return w * 0.5 - SEAM_S * R * sin(PI * y)
## the face for a door w by h metres: [colour, glow (the seam)], cached by size
static func door_face(w: float, h: float) -> Array:
	var key := "face%.2fx%.2f" % [w, h]
	if not _tx.has(key):
		var ph := 384; var pw := roundi(384.0 * w / h); var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8); var glow := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
		img.fill(Color("434a5a")); glow.fill(Color.BLACK)
		var k := ph / h; var fr := maxf(4.0, 0.035 * ph)   # pixels a metre; the frame's width
		img.fill_rect(Rect2i(0, 0, pw, roundi(fr)), Color("15181e")); img.fill_rect(Rect2i(0, ph - roundi(fr), pw, roundi(fr)), Color("15181e"))
		img.fill_rect(Rect2i(0, 0, roundi(fr), ph), Color("15181e")); img.fill_rect(Rect2i(pw - roundi(fr), 0, roundi(fr), ph), Color("15181e"))
		var R := RING_R * ph; var cx := pw * 0.5; var cy := ph * 0.5; var rw := RING_W * ph; var sw := SEAM_W * ph; var blue := Color("3f8cff")
		# the seam above and below the ring: a straight line of blue light
		for band: Array in [[fr, cy - R - rw * 0.5], [cy + R + rw * 0.5, ph - fr]]:
			var y0: int = roundi(band[0]); var y1: int = roundi(band[1])
			img.fill_rect(Rect2i(roundi(cx - sw * 0.5), y0, maxi(1, roundi(sw)), y1 - y0), blue); glow.fill_rect(Rect2i(roundi(cx - sw * 0.5), y0, maxi(1, roundi(sw)), y1 - y0), blue)
		# the ring, and the S across it (black), drawn pixel by pixel round the ring only, smoothed at the edges
		var ink := Color("0d0f13")
		for py in range(maxi(0, int(cy - R - rw)), mini(ph, int(cy + R + rw) + 1)):
			for px in range(maxi(0, int(cx - R - rw)), mini(pw, int(cx + R + rw) + 1)):
				var dx := px + 0.5 - cx; var dy := py + 0.5 - cy; var r := sqrt(dx * dx + dy * dy)
				var a := clampf(rw * 0.5 - absf(r - R) + 0.5, 0.0, 1.0)
				if r < R:
					var su := seam_u(h * 0.5 - dy / k, w, h) * k - cx   # the S at this height, in pixels from the middle
					a = maxf(a, clampf(sw * 0.75 - absf(dx - su) + 0.5, 0.0, 1.0))
				if a > 0.0: img.set_pixel(px, py, img.get_pixel(px, py).lerp(ink, a))
		_tx[key] = [Gfx.tex(img), Gfx.tex(glow)]
	return _tx[key]
## the door's material: the face, its seam glowing a little, both sides drawn (a leaf is a thin slab cut along the seam)
static func door_mat(w: float, h: float) -> StandardMaterial3D:
	var f := door_face(w, h); var m := Gfx.std(Color.WHITE, 0.5, 0.55, f[0])
	m.emission_enabled = true; m.emission_texture = f[1]; m.emission = Color.WHITE; m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY; m.emission_energy_multiplier = 1.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
## one leaf of a sliding door, w by h and th thick, cut along the seam (left: the part before it). centred on the door, the face
## across z, its thickness along x, standing on the floor
static func leaf_mesh(w: float, h: float, th: float, left: bool) -> ArrayMesh:
	var seam := PackedVector2Array([Vector2(w * 0.5, 0.0)]); var R := RING_R * h
	for i in 33: var v := h * 0.5 - R + 2.0 * R * i / 32.0; seam.push_back(Vector2(seam_u(v, w, h), v))
	seam.push_back(Vector2(w * 0.5, h))
	var poly := PackedVector2Array()
	if left: poly.push_back(Vector2(0, 0)); poly.append_array(seam); poly.push_back(Vector2(0, h))
	else:
		poly.push_back(Vector2(w, 0)); poly.push_back(Vector2(w, h))
		for i in range(seam.size() - 1, -1, -1): poly.push_back(seam[i])
	var idx := Geometry2D.triangulate_polygon(poly); var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sd: float in [1.0, -1.0]:   # the two faces
		for i in idx: var q := poly[i]; st.set_normal(Vector3(sd, 0, 0)); st.set_uv(Vector2(q.x / w, 1.0 - q.y / h)); st.add_vertex(Vector3(sd * th * 0.5, q.y, q.x - w * 0.5))
	var area := 0.0
	for i in poly.size(): area += poly[i].cross(poly[(i + 1) % poly.size()])
	for i in poly.size():   # the edges all round, facing out
		var a := poly[i]; var b := poly[(i + 1) % poly.size()]; var e := (b - a).normalized(); var o := Vector2(e.y, -e.x) * (1.0 if area > 0.0 else -1.0)
		var nn := Vector3(0, o.y, o.x); var ua := Vector2(a.x / w, 1.0 - a.y / h); var ub := Vector2(b.x / w, 1.0 - b.y / h)
		for c: Array in [[a, th, ua], [b, th, ub], [b, -th, ub], [a, th, ua], [b, -th, ub], [a, -th, ua]]:
			var q2: Vector2 = c[0]; st.set_normal(nn); st.set_uv(c[2]); st.add_vertex(Vector3(float(c[1]) * 0.5, q2.y, q2.x - w * 0.5))
	return st.commit()

## a column of red light standing up out of an open hatch: black above, orange at the floor
static func shaft_tex() -> ImageTexture:
	if not _tx.has("shaft"):
		var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var t := (y + 0.5) / 64.0; var c := Color("000000").lerp(Color("2a0800"), t / 0.55) if t < 0.55 else Color("2a0800").lerp(Color("ff5a22"), (t - 0.55) / 0.45)
			for x in 4: img.set_pixel(x, y, c.linear_to_srgb())   # (a linear canvas in the browser game: shown as encoded)
		_tx.shaft = Gfx.tex(img)
	return _tx.shaft

## boxes whose picture keeps its size in metres on every face (s metres a picture), as the browser game's uvBox: x faces take
## (z, y), the top and bottom (x, z), the rest (x, y). list: [x0, y0, z0, x1, y1, z1]
static func uv_boxes(list: Array, s: float) -> ArrayMesh:
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	for q in list:
		var lo := Vector3(q[0], q[1], q[2]); var hi := Vector3(q[3], q[4], q[5]); var c := (lo + hi) / 2; var hh := (hi - lo) / 2
		for f: Array in [[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
				[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]:
			var n: Vector3 = f[0]; var fc := c + n * hh; var rr: Vector3 = (f[1] as Vector3) * hh; var tt: Vector3 = (f[2] as Vector3) * hh; var o := vs.size()
			for pv: Vector3 in [fc - rr + tt, fc + rr + tt, fc - rr - tt, fc + rr - tt]:
				vs.push_back(pv); ns.push_back(n)
				var uv := Vector2(pv.z, pv.y) if absf(n.x) > 0.5 else (Vector2(pv.x, pv.z) if absf(n.y) > 0.5 else Vector2(pv.x, pv.y))
				uvs.push_back(Vector2(uv.x / s, 1.0 - uv.y / s))   # (three.js counts v up from the picture's foot)
			idx.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX] = vs; a[Mesh.ARRAY_NORMAL] = ns; a[Mesh.ARRAY_TEX_UV] = uvs; a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a); return m
## a level floor from (x0, z0) to (x1, z1) at height y; uv(x, z) gives three.js's coordinates for a point on it
static func floor_quad(x0: float, z0: float, x1: float, z1: float, y: float, uv: Callable) -> ArrayMesh:
	var vs := PackedVector3Array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1)]); var uvs := PackedVector2Array()
	for pv in vs: var t: Vector2 = uv.call(pv.x, pv.z); uvs.push_back(Vector2(t.x, 1.0 - t.y))
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX] = vs; a[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	a[Mesh.ARRAY_TEX_UV] = uvs; a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])   # (facing up: Godot winds front faces clockwise)
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a); return m
static func _bx(sz: Array) -> BoxMesh: var b := BoxMesh.new(); b.size = Vector3(sz[0], sz[1], sz[2]); return b
## three.js's CircleGeometry: a flat disc facing +z, its picture laid across it
static func _disc(r: float, seg: int) -> ArrayMesh:
	var vs := PackedVector3Array([Vector3.ZERO]); var uvs := PackedVector2Array([Vector2(0.5, 0.5)]); var ns := PackedVector3Array([Vector3.BACK]); var idx := PackedInt32Array()
	for i in seg + 1:
		var a := float(i) / seg * TAU; var pv := Vector3(cos(a) * r, sin(a) * r, 0); vs.push_back(pv); ns.push_back(Vector3.BACK); uvs.push_back(Vector2((pv.x / r + 1) / 2, 1.0 - (pv.y / r + 1) / 2))
	for i in seg: idx.append_array([0, i + 2, i + 1])   # (Godot winds front faces clockwise)
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m
## a textured box as three.js's BoxGeometry is (the whole picture on every face), merged: [sx, sy, sz, x, y, z]
static func tex_boxes(list: Array) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in list: st.append_from(Gfx.box(Vector3(q[0], q[1], q[2])), 0, Transform3D(Basis.IDENTITY, Vector3(q[3], q[4], q[5])))
	return st.commit()

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	world = w
	var ax := PYR_OX; var az := PYR_OZ
	for k in range(1, 24):
		var L: float = 0.0 if k % 8 != 0 else [3.0, 2.5][k / 8 - 1]; var sw := 0.55 + L
		steps.push_back({"k": k, "ax": ax, "az": az, "y": -0.375 * k, "w": sw, "land": L > 0.0}); ax -= sw; az -= sw
	pyr_bx = ax; pyr_bz = az
	var solid := []; var glow := []
	var kit_mat := StandardMaterial3D.new(); kit_mat.vertex_color_use_as_albedo = true; kit_mat.vertex_color_is_srgb = true; kit_mat.roughness = 0.5; kit_mat.metallic = 0.45   # (vertex colours, as AnimalKit merges)
	var glow_mat := StandardMaterial3D.new(); glow_mat.vertex_color_use_as_albedo = true; glow_mat.vertex_color_is_srgb = true; glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # (MeshBasicMaterial: no light, no shadow)
	var box := func(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: String) -> void:
		Phys.add_collider(x0, y0, z0, x1, y1, z1, "metal"); solid.push_back([x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, col])
	# 1. the floor plan into a half-metre grid: every cell knows the ceiling over it (0 = outside the ship)
	var CS := 0.5; var GX := -126.0; var GZ := -50.0; var NX := 580; var NZ := 192; var h_at := PackedFloat32Array(); h_at.resize(NX * NZ)
	for Rm in ROOMS:
		var i0 := roundi((Rm[0] - GX) / CS); var i1 := roundi((Rm[2] - GX) / CS); var j0 := roundi((Rm[1] - GZ) / CS); var j1 := roundi((Rm[3] - GZ) / CS)
		for i in range(i0, i1):
			for j in range(j0, j1): h_at[j * NX + i] = maxf(h_at[j * NX + i], Rm[4])
	var H := func(i: int, j: int) -> float: return 0.0 if (i < 0 or j < 0 or i >= NX or j >= NZ) else h_at[j * NX + i]
	# 2. walls wherever a cell meets the outside, and lintels above an opening into a lower room
	var T := 0.6; var walls := []
	for d: int in [-1, 1]:
		for pass_ in 2:
			var n := NZ if pass_ == 0 else NX; var m := NX if pass_ == 0 else NZ
			for a in n:
				var cur = null
				for b in m + 1:
					var h := 0.0; var hn := 0.0
					if b < m:
						if pass_ == 0: h = H.call(b, a); hn = H.call(b, a + d)
						else: h = H.call(a, b); hn = H.call(a + d, b)
					if b < m and h > 0.0 and hn < h:
						var y0 := hn if hn > 0.0 else 0.0
						if cur != null and cur.y0 == y0 and cur.y1 == h and cur.b1 == b: cur.b1 = b + 1; continue
						if cur != null: walls.push_back(_wall(pass_, d, a, cur, GX, GZ, CS, T))
						cur = {"b0": b, "b1": b + 1, "y0": y0, "y1": h}
					elif cur != null: walls.push_back(_wall(pass_, d, a, cur, GX, GZ, CS, T)); cur = null
	for q in walls: Phys.add_collider(q[0], q[1], q[2], q[3], q[4], q[5], "metal")
	var wm := MeshInstance3D.new(); wm.name = "Walls"; wm.mesh = uv_boxes(walls, 3.0); wm.material_override = Gfx.std(Color.WHITE, 0.8, 0.2, panel_tex()); G.add_child(wm)
	# 3. ceilings and floors: plates in the corridor, a grating in the passage, carpet on the bridge (the hall's is laid round its pit)
	var floor_mat := {"corr": Gfx.std(Color.WHITE, 0.55, 0.45, plate_tex()), "pass": Gfx.std(Color.WHITE, 0.5, 0.6, grate_tex()), "bridge": Gfx.std(Color.WHITE, 0.9, 0.05, carpet_tex())}
	floor_mat.lock = floor_mat.pass
	var ceils := []
	for Rm in ROOMS:
		Phys.add_collider(Rm[0], Rm[4], Rm[1], Rm[2], Rm[4] + 0.4, Rm[3], "metal"); ceils.push_back([Rm[0], Rm[4], Rm[1], Rm[2], Rm[4] + 0.4, Rm[3]])
		if Rm[5] == "hall": continue   # the hall's floor is laid round its hidden pit
		var fs: float = 1.5 if Rm[5] == "pass" or Rm[5] == "lock" else (3.0 if Rm[5] == "bridge" else 6.0); var fx0: float = Rm[0]; var fz1: float = Rm[3]
		var fl := MeshInstance3D.new(); fl.name = "Floor_" + str(Rm[5]); fl.mesh = floor_quad(Rm[0], Rm[1], Rm[2], Rm[3], 0.002, func(px: float, pz: float) -> Vector2: return Vector2((px - fx0) / fs, (fz1 - pz) / fs))
		fl.material_override = floor_mat[Rm[5]]; G.add_child(fl)
	var cl := MeshInstance3D.new(); cl.name = "Ceilings"; cl.mesh = uv_boxes(ceils, 4.0); cl.material_override = Gfx.std(Color.WHITE, 0.8, 0.2, ceil_tex()); G.add_child(cl)
	var pipes := SurfaceTool.new(); pipes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pipe := func(a: Vector3, b: Vector3, r: float) -> void:   # three.js's CylinderGeometry(r, r, length, 8), along z or along x
		var cy := CylinderMesh.new(); cy.top_radius = r; cy.bottom_radius = r; cy.height = a.distance_to(b); cy.radial_segments = 8; cy.rings = 0
		pipes.append_from(cy, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2) if absf(b.z - a.z) > absf(b.x - a.x) else Basis(Vector3.BACK, PI / 2), (a + b) / 2))
	var screens := []
	# 4. the passage from the airlock: red warning lamps, the airlock door behind you
	pipe.call(Vector3(-43.7, 3.9, 13), Vector3(-43.7, 3.9, 25), 0.12); pipe.call(Vector3(-39.8, 3.7, 13), Vector3(-39.8, 3.7, 25), 0.09)
	pipe.call(Vector3(-44, 3.9, 7.3), Vector3(-22, 3.9, 7.3), 0.12); pipe.call(Vector3(-44, 3.7, 12.7), Vector3(-22, 3.7, 12.7), 0.09)
	pipe.call(Vector3(-26.2, 3.9, -2.5), Vector3(-26.2, 3.9, 7), 0.12); pipe.call(Vector3(-22.3, 3.7, -2.5), Vector3(-22.3, 3.7, 7), 0.09)
	for q in [[-41.75, 16.0], [-41.75, 20.0], [-38.0, 10.0], [-30.0, 10.0], [-24.25, 4.0], [-24.25, 0.0]]: glow.push_back([1.2, 0.05, 0.4, q[0], 4.46, q[1], "cfe6ff"])
	var red := Gfx.unlit(World.lin("ff2a2a"))   # red warning lamps, blinking
	for q in [[-43.95, 18.0], [-39.55, 14.0], [-33.0, 7.05], [-27.0, 12.95], [-26.45, 2.0]]:
		var bl := MeshInstance3D.new(); bl.mesh = Gfx.box(Vector3(0.25, 0.25, 0.25)); bl.material_override = red; bl.position = Vector3(q[0], 3.4, q[1]); G.add_child(bl); w.blink.push_back(bl)
	for q in [[-44.0, 7.0, -39.5, 13.0], [-26.5, 7.0, -22.0, 13.0], [-26.5, -2.5, -22.0, -1.6]]:   # hazard stripes at the turns
		for i in range(0, roundi((q[2] - q[0]) / 0.5), 2): glow.push_back([0.5, 0.01, 0.12, q[0] + 0.25 + i * 0.5, 0.012, q[1] + 0.1, "e8b040"]); glow.push_back([0.5, 0.01, 0.12, q[0] + 0.25 + i * 0.5, 0.012, q[3] - 0.1, "e8b040"])
	Phys.add_collider(-44, 0, DOOR_Z - 0.2, -39.5, 4.5, DOOR_Z + 0.2, "metal")
	solid.push_back([0.35, 4.5, 0.5, -44.0 + 0.17, 2.25, DOOR_Z, "2a2f3a"]); solid.push_back([0.35, 4.5, 0.5, -39.5 - 0.17, 2.25, DOOR_Z, "2a2f3a"])
	# inside the airlock: the outer hatch, a round window full of stars
	var hw_ := MeshInstance3D.new(); hw_.mesh = _disc(1.3, 32); var hwm := Gfx.unlit(Color.WHITE); hwm.albedo_texture = space_tex(0.3); hw_.material_override = hwm
	hw_.position = Vector3(-41.75, 2.2, 29.45); hw_.rotation.y = PI; G.add_child(hw_); solid.push_back([3.2, 3.2, 0.2, -41.75, 2.2, 29.5, "2a2f3a"])
	w.lamps.push_back({"x": -41.75, "y": 3.6, "z": 27.5})
	# 5. the corridor (160 m): pipes, a light strip on each wall, panels in the ceiling, low barricades to hide behind
	pipe.call(Vector3(-92, 5.2, -12.2), Vector3(68, 5.2, -12.2), 0.16); pipe.call(Vector3(-92, 4.7, -12.25), Vector3(68, 4.7, -12.25), 0.1)
	pipe.call(Vector3(-92, 5.2, -2.8), Vector3(-26.5, 5.2, -2.8), 0.16); pipe.call(Vector3(-22, 5.2, -2.8), Vector3(68, 5.2, -2.8), 0.16)
	for z: float in [-12.46, -2.54]: glow.push_back([160.0, 0.06, 0.04, -12.0, 2.4, z, "3a9cff"])
	var x := -88.0
	while x <= 64.0: glow.push_back([3.2, 0.06, 1.2, x, 5.97, -7.5, "dfeeff"]); x += 6.0
	var bi := 0; x = -84.0
	while x <= 60.0:
		var z: float = -4.2 if bi % 2 else -10.8
		if absf(x + 24.25) >= 4.0:   # keep the mouth of the passage clear
			box.call(x - 1.5, 0.0, z - 0.35, x + 1.5, 1.15, z + 0.35, "454d60"); solid.push_back([3.04, 0.08, 0.74, x, 1.16, z, "e8b040"])
		x += 12.0; bi += 1
	var side_x := []
	for sx: float in [-80.0, -55.0, -40.0, -15.0, 8.0, 33.0, 52.0]:   # sealed side doors along the corridor walls (the doors' face)
		side_x.push_back(Transform3D(Basis.IDENTITY, Vector3(sx, 1.6, -12.44))); side_x.push_back(Transform3D(Basis.IDENTITY, Vector3(sx + 6, 1.6, -2.56)))
		glow.push_back([0.3, 0.12, 0.05, sx + 1.5, 1.7, -12.36, "ff3a2a"]); glow.push_back([0.3, 0.12, 0.05, sx + 4.5, 1.7, -2.64, "ff3a2a"])
	var sign_at := func(tex: Texture2D, sx: float, sy: float, sz: float, ry: float, sw: float) -> void:   # unlit, as the browser game's MeshBasicMaterial
		var sm_ := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(sw, sw * 0.3125); sm_.mesh = sq; var smat_ := Gfx.unlit(Color.WHITE); smat_.albedo_texture = tex; sm_.material_override = smat_
		sm_.position = Vector3(sx, sy, sz); sm_.rotation.y = ry; G.add_child(sm_)
	var sdm := Gfx.multimesh(Gfx.box(Vector3(2.4, 3.2, 0.12)), side_x); sdm.material_override = door_mat(2.4, 3.2); G.add_child(sdm); MoonShadow.no_receive(sdm)
	sign_at.call(sign_tex("운전실", "left", Color("f2a33a")), -24.9, 3.3, -12.43, 0.0, 4.3); sign_at.call(sign_tex("메인홀", "right", Color("5ed6b0")), -18.1, 3.3, -12.43, 0.0, 4.3)
	x = -86.0
	while x <= 64.0: w.lamps.push_back({"x": x, "y": 5.2, "z": -7.5}); x += 12.0
	for q in [[-41.75, 3.9, 18.0], [-33.0, 3.9, 10.0], [-24.25, 3.9, 2.5]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	# 5b. the sliding doors onto the bridge and the hall: two leaves that part into the wall
	for D: Dictionary in DOORS:
		var d := D.duplicate(); var dw: float = D.z1 - D.z0; var dmat := door_mat(dw, D.h)
		for nm in ["a", "b"]:
			var leaf := MeshInstance3D.new(); leaf.mesh = leaf_mesh(dw, D.h, 0.3, nm == "a"); leaf.material_override = dmat; MoonShadow.caster(leaf); MoonShadow.no_receive(leaf); leaf.position = Vector3(D.x, 0.0, (D.z0 + D.z1) / 2); G.add_child(leaf); d[nm] = leaf
		d.open = 0.0; d.mode = "shut"; d.col = Phys.add_collider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, "metal"); d.col.door = true; doors.push_back(d)
		# a sign hung from the ceiling a few metres before the door, facing you as you come down the corridor: the name and 'straight on'
		var out: float = -D.inward; var hx: float = D.x + out * 4.5
		sign_at.call(sign_tex(D.name, "up", Color("f2a33a") if D.room == "bridge" else Color("5ed6b0")), hx, 4.5, -7.5, PI / 2 if out > 0 else -PI / 2, 4.4)
		solid.push_back([0.04, 0.95, 0.04, hx, 5.52, -9.2, "2a2f3a"]); solid.push_back([0.04, 0.95, 0.04, hx, 5.52, -5.8, "2a2f3a"])
		glow.push_back([0.06, 0.1, D.z1 - D.z0 + 0.4, D.x + (0.32 if D.x < 0 else -0.32), D.h + 0.15, -7.5, "e8b040"])
	# 6. the bridge: 31 x 41 m and 16 m high. A two-storey wall of windows onto space, rows of consoles facing it, the commander's
	# platform behind them, and an open gallery at 7 m round the other three sides, a wide stair up the north and south walls
	var BR := BRIDGE; var GY: float = BR.gy
	var win := MeshInstance3D.new(); win.name = "BridgeWindow"; var wq := QuadMesh.new(); wq.size = Vector2(27, 11); win.mesh = wq
	var winm := Gfx.unlit(Color.WHITE); winm.albedo_texture = space_tex(0.62); win.material_override = winm; win.position = Vector3(BR.x0 + 0.03, 8, -7.5); win.rotation.y = PI / 2; G.add_child(win)
	solid.push_back([0.2, 0.3, 27.4, BR.x0 + 0.1, 2.4, -7.5, "2a2f3a"]); solid.push_back([0.2, 0.3, 27.4, BR.x0 + 0.1, 13.6, -7.5, "2a2f3a"]); solid.push_back([0.2, 11.4, 0.3, BR.x0 + 0.1, 8.0, -7.5, "2a2f3a"])
	# the gallery floor, in three runs, with a blue light along its edge
	var gal := [[BR.stairX1, BR.z0, BR.x1, BR.z0 + 5], [BR.stairX1, BR.z1 - 5, BR.x1, BR.z1], [BR.eastX, BR.z0 + 5, BR.x1, BR.z1 - 5]]
	for q in gal: box.call(q[0], GY - 0.4, q[1], q[2], GY, q[3], "2f3542")
	glow.push_back([BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z0 + 5.02, "4fb8ff"]); glow.push_back([BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z1 - 5.02, "4fb8ff"])
	glow.push_back([0.05, 0.05, BR.z1 - BR.z0 - 10, BR.eastX - 0.02, GY - 0.2, (BR.z0 + BR.z1) / 2, "4fb8ff"])
	# railings on its open edges (bullets and eyes go through them): two rails and a post every 2.5 m, in the pipes' steel
	for q in [[BR.stairX1, BR.z0 + 4.95, BR.eastX, BR.z0 + 5.05], [BR.stairX1, BR.z1 - 5.05, BR.eastX, BR.z1 - 4.95], [BR.eastX - 0.05, BR.z0 + 5, BR.eastX + 0.05, BR.z1 - 5]]:
		var rb := Phys.add_collider(q[0], GY, q[1], q[2], GY + 1.1, q[3], "metal"); rb.grate = true
		var L: float = maxf(q[2] - q[0], q[3] - q[1]); var along: bool = q[2] - q[0] > q[3] - q[1]; var rcx: float = (q[0] + q[2]) / 2; var rcz: float = (q[1] + q[3]) / 2
		pipes.append_from(_bx([L, 0.07, 0.07] if along else [0.07, 0.07, L]), 0, Transform3D(Basis.IDENTITY, Vector3(rcx, GY + 1.05, rcz)))
		pipes.append_from(_bx([L, 0.05, 0.05] if along else [0.05, 0.05, L]), 0, Transform3D(Basis.IDENTITY, Vector3(rcx, GY + 0.55, rcz)))
		var rt := 0.0
		while rt <= L: pipes.append_from(_bx([0.08, 1.1, 0.08]), 0, Transform3D(Basis.IDENTITY, Vector3(q[0] + rt if along else rcx, GY + 0.55, rcz if along else q[1] + rt))); rt += 2.5
	# the stairs: sixteen steps of 0.44 m (people and robots both climb them), solid down to the floor, a grating with a yellow edge
	var step_run: float = (BR.stairX1 - BR.stairX0) / BR.steps; var stairs := []
	for q in [[BR.z0, BR.z0 + 5], [BR.z1 - 5, BR.z1]]:
		for k in range(1, int(BR.steps) + 1):
			var x0: float = BR.stairX0 + (k - 1) * step_run; var h: float = (float(k) / BR.steps) * GY
			Phys.add_collider(x0, 0, q[0], x0 + step_run, h, q[1], "metal"); stairs.push_back([step_run, h, q[1] - q[0], x0 + step_run / 2, h / 2, (q[0] + q[1]) / 2])
			glow.push_back([step_run * 0.9, 0.02, 0.06, x0 + step_run / 2, h + 0.011, q[1] - 0.1 if q[0] == BR.z0 else q[0] + 0.1, "e8b040"])
	var stair_mi := MeshInstance3D.new(); stair_mi.name = "Stairs"; stair_mi.mesh = tex_boxes(stairs); stair_mi.material_override = Gfx.std(Color.WHITE, 0.5, 0.6, grate_tex()); G.add_child(stair_mi); MoonShadow.caster(stair_mi)
	# ground floor: two rows of consoles facing the windows, the commander's platform behind them, and screens on the walls under the gallery
	for cx: float in [-118.5, -113.5]:
		for cz: float in [-19.0, -13.5, -1.5, 4.0]:
			box.call(cx - 0.5, 0.0, cz - 1.3, cx + 0.5, 1.05, cz + 1.3, "2c3240"); screens.push_back([0.06, 0.55, 2.2, cx - 0.3, 1.45, cz, "3fd0ff", [0.0, 0.0, 0.35]]); glow.push_back([0.05, 0.03, 2.4, cx + 0.48, 1.06, cz, "3a9cff"])
	box.call(-108.0, 0.0, -11.0, -102.0, 0.45, -4.0, "2a2f3a"); glow.push_back([6.04, 0.04, 0.04, -105.0, 0.46, -11.0, "e8b040"]); glow.push_back([6.04, 0.04, 0.04, -105.0, 0.46, -4.0, "e8b040"])
	box.call(-105.5, 0.45, -8.1, -104.5, 1.6, -6.9, "3b4252"); solid.push_back([1.1, 0.12, 1.1, -105.0, 0.95, -7.5, "5a6378"])
	# the main hall's key, stuck upright in the commander's console: a gold bow and collar over a short shaft, glowing so you can find it
	key_obj = Node3D.new(); key_obj.position = KEY; G.add_child(key_obj)
	var kmat := Gfx.std(World.lin("ffc83a"), 0.25, 0.85); kmat.emission_enabled = true; kmat.emission = World.lin("7a4c00"); kmat.emission_energy_multiplier = 0.9
	var bow := MeshInstance3D.new(); var bt := TorusMesh.new(); bt.inner_radius = 0.12; bt.outer_radius = 0.22; bt.rings = 24; bt.ring_segments = 10; bow.mesh = bt
	bow.rotation.x = PI / 2; bow.position.y = 0.5; bow.material_override = kmat; key_obj.add_child(bow)   # (three.js's torus stands upright)
	var kst := SurfaceTool.new(); kst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [[0.16, 0.05, 0.09, 0.0, 0.3], [0.065, 0.3, 0.065, 0.0, 0.15], [0.08, 0.05, 0.05, 0.06, 0.08]]: kst.append_from(_bx(q), 0, Transform3D(Basis.IDENTITY, Vector3(q[3], q[4], 0)))
	var kb := MeshInstance3D.new(); kb.mesh = kst.commit(); kb.material_override = kmat; key_obj.add_child(kb)
	for n: Node in [bow, kb]: MoonShadow.caster(n); MoonShadow.no_receive(n)
	key_glow = MeshInstance3D.new(); var kq := QuadMesh.new(); kq.size = Vector2(1.4, 1.4); key_glow.mesh = kq; var kgm := StandardMaterial3D.new(); kgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kgm.albedo_texture = Gfx.glow_tex(Color(1, 220 / 255.0, 120 / 255.0, 0.95), Color(1, 170 / 255.0, 40 / 255.0, 0.2)); kgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; kgm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	kgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; kgm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; kgm.albedo_color = Color(1, 1, 1, 0.7); key_glow.material_override = Gfx.see_through(kgm); key_glow.position.y = 0.38; key_obj.add_child(key_glow)
	for cz: float in [BR.z0 + 0.4, BR.z1 - 0.4]:
		for cx: float in [-104.0, -99.0]: box.call(cx - 1.4, 0.0, cz - 0.3, cx + 1.4, 1.1, cz + 0.3, "2c3240"); screens.push_back([2.4, 0.9, 0.05, cx, 2.1, cz + (0.3 if cz < 0 else -0.3), "3fd0ff"])
	# up on the gallery: consoles against the walls, and a big status board high on the east wall
	for cx: float in [-104.0, -98.0]:
		for cz: float in [BR.z0 + 0.4, BR.z1 - 0.4]: box.call(cx - 1.4, GY, cz - 0.3, cx + 1.4, GY + 1.1, cz + 0.3, "2c3240"); screens.push_back([2.4, 0.9, 0.05, cx, GY + 2.1, cz + (0.3 if cz < 0 else -0.3), "3fd0ff"])
	for cz: float in [-19.0, -11.0, -4.0, 4.0]: box.call(BR.x1 - 0.7, GY, cz - 1.4, BR.x1 - 0.1, GY + 1.1, cz + 1.4, "2c3240"); screens.push_back([0.05, 0.9, 2.4, BR.x1 - 0.4, GY + 2.1, cz, "3fd0ff"])
	screens.push_back([0.06, 2.6, 9.0, BR.x1 - 0.05, 12.0, -7.5, "3fd0ff"])
	var scr := MeshInstance3D.new(); scr.name = "Screens"; scr.mesh = Gfx.merge_boxes(screens); screens_mat = StandardMaterial3D.new(); screens_mat.vertex_color_use_as_albedo = true; screens_mat.vertex_color_is_srgb = true
	screens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; scr.material_override = screens_mat; G.add_child(scr); MoonShadow.no_receive(scr)
	var bx_ := -120.0
	while bx_ <= -95.0:
		for bz_: float in [-22.0, -14.0, -7.5, -1.0, 7.0]: glow.push_back([2.4, 0.05, 1.0, bx_, 15.97, bz_, "dfeeff"])
		bx_ += 6.0
	for q in gal:
		var gx: float = q[0] + 2
		while gx < q[2] - 1: glow.push_back([1.6, 0.04, 0.6, gx, GY - 0.42, (q[1] + q[3]) / 2, "cfe6ff"]); gx += 5.0
	for q in [[-115.0, 13.0, -16.0], [-115.0, 13.0, 1.0], [-104.0, 13.0, -7.5], [-100.0, 5.6, -25.5], [-100.0, 5.6, 10.5], [-100.0, GY + 3.5, -25.5], [-100.0, GY + 3.5, 10.5], [-94.5, GY + 3.5, -7.5]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	# 7. the main hall: the floor (solid round the walkway, panels over the pit that fall in at the boss's second phase), the stepped pit
	# under it, a stepped dais round the reactor, four pillars, tall cargo to hide behind, windows to the east
	var HR: Array = ROOMS[2]; var cx0: float = REACTOR.x; var cz0: float = REACTOR.z; var rx0 := cx0 - PYR_OX; var rx1 := cx0 + PYR_OX; var rz0 := cz0 - PYR_OZ; var rz1 := cz0 + PYR_OZ
	var hall_mat := Gfx.std(Color.WHITE, 0.5, 0.5, hall_tex())
	var hstrip := func(xa: float, za: float, xb: float, zb: float, y: float) -> MeshInstance3D:   # its picture laid by the metre, 6 m a picture
		var f := MeshInstance3D.new(); f.mesh = floor_quad(xa, za, xb, zb, y, func(px: float, pz: float) -> Vector2: return Vector2(px / 6.0, pz / 6.0)); f.material_override = hall_mat; G.add_child(f); return f
	for q in [[HR[0], HR[1], HR[2], rz0], [HR[0], rz1, HR[2], HR[3]], [HR[0], rz0, rx0, rz1], [rx1, rz0, HR[2], rz1]]: hstrip.call(q[0], q[1], q[2], q[3], 0.002)
	var bottom: MeshInstance3D = hstrip.call(cx0 - pyr_bx, cz0 - pyr_bz, cx0 + pyr_bx, cz0 + pyr_bz, PYR_BOTTOM + 0.002); bottom.visible = false
	var tiles := []; var tw := 2 * PYR_OX / 8; var td := 2 * PYR_OZ / 8; var tmesh := Gfx.box(Vector3(tw - 0.04, 0.14, td - 0.04))
	for i in 8:
		for k in 8:
			var tn := MeshInstance3D.new(); tn.mesh = tmesh; tn.material_override = hall_mat; tn.position = Vector3(rx0 + (i + 0.5) * tw, -0.068, rz0 + (k + 0.5) * td); G.add_child(tn); tiles.push_back({"n": tn, "d": 0.0, "vy": 0.0, "sx": 0.0, "sz": 0.0})
	var step_list := []; var land_list := []; var pglow := []
	var band := func(xa: float, za: float, xb: float, zb: float, top: float, land: bool) -> void:
		var c := Phys.add_collider(xa, PYR_BOTTOM, za, xb, top, zb, "metal"); c.step = true; (land_list if land else step_list).push_back([xa, PYR_BOTTOM, za, xb, top, zb])
	var T2 := 0.3   # the pit's own wall, just outside the rim
	band.call(rx0 - T2, rz0 - T2, rx1 + T2, rz0, 0.0, false); band.call(rx0 - T2, rz1, rx1 + T2, rz1 + T2, 0.0, false); band.call(rx0 - T2, rz0, rx0, rz1, 0.0, false); band.call(rx1, rz0, rx1 + T2, rz1, 0.0, false)
	for st in steps:
		var ix: float = st.ax - st.w; var iz: float = st.az - st.w
		band.call(cx0 - st.ax, cz0 - st.az, cx0 + st.ax, cz0 - iz, st.y, st.land); band.call(cx0 - st.ax, cz0 + iz, cx0 + st.ax, cz0 + st.az, st.y, st.land)
		band.call(cx0 - st.ax, cz0 - iz, cx0 - ix, cz0 + iz, st.y, st.land); band.call(cx0 + ix, cz0 - iz, cx0 + st.ax, cz0 + iz, st.y, st.land)
		var pc := "6fd2ff" if st.land or int(st.k) == steps.size() else "3a8ee6"; var py: float = st.y - 0.035   # a light along each tread's edge
		pglow.push_back([2 * ix + 0.18, 0.1, 0.09, cx0, py, cz0 - iz - 0.01, pc]); pglow.push_back([2 * ix + 0.18, 0.1, 0.09, cx0, py, cz0 + iz + 0.01, pc])
		pglow.push_back([0.09, 0.1, 2 * iz + 0.18, cx0 - ix - 0.01, py, cz0, pc]); pglow.push_back([0.09, 0.1, 2 * iz + 0.18, cx0 + ix + 0.01, py, cz0, pc])
	var rw := 0.16
	pglow.push_back([2 * PYR_OX + 2 * rw, 0.02, rw, cx0, 0.012, rz0 - rw / 2, "e8b040"]); pglow.push_back([2 * PYR_OX + 2 * rw, 0.02, rw, cx0, 0.012, rz1 + rw / 2, "e8b040"])
	pglow.push_back([rw, 0.02, 2 * PYR_OZ, rx0 - rw / 2, 0.012, cz0, "e8b040"]); pglow.push_back([rw, 0.02, 2 * PYR_OZ, rx1 + rw / 2, 0.012, cz0, "e8b040"])
	pglow.push_back([4.2, 0.9, 4.2, cx0, PYR_BOTTOM + 0.45, cz0, "353b48"])
	var step_mi := MeshInstance3D.new(); step_mi.name = "PitSteps"; step_mi.mesh = uv_boxes(step_list, 2.0); step_mi.material_override = Gfx.std(Color.WHITE, 0.55, 0.5, step_tex())
	var land_mi := MeshInstance3D.new(); land_mi.name = "PitLandings"; land_mi.mesh = uv_boxes(land_list, 6.0); land_mi.material_override = hall_mat
	var pit_glow := MeshInstance3D.new(); pit_glow.name = "PitGlow"; pit_glow.mesh = Gfx.merge_boxes(pglow); pit_glow.material_override = glow_mat
	for n: MeshInstance3D in [step_mi, land_mi, pit_glow]: n.visible = false; G.add_child(n)
	MoonShadow.caster(step_mi); MoonShadow.caster(land_mi); MoonShadow.no_receive(pit_glow)
	# the dais round the reactor stands on the panels: its own mesh, edge lights and colliders, so it can go with them
	var cols := []; var dparts := []; var dglow := []
	for k in DAIS.size():
		var q: Array = DAIS[k]; cols.push_back(Phys.add_collider(q[0], 0, q[1], q[2], q[4], q[3], "metal")); dparts.push_back([q[2] - q[0], q[4], q[3] - q[1], (q[0] + q[2]) / 2, q[4] / 2, (q[1] + q[3]) / 2, ["2f3542", "353b48", "3d4454"][k]])
		for e in [[q[0], q[1], q[2], q[1]], [q[0], q[3], q[2], q[3]], [q[0], q[1], q[0], q[3]], [q[2], q[1], q[2], q[3]]]:
			dglow.push_back([maxf(0.04, absf(e[2] - e[0])), 0.03, maxf(0.04, absf(e[3] - e[1])), (e[0] + e[2]) / 2, q[4] + 0.01, (e[1] + e[3]) / 2, "4fb8ff"])
	var dais := MeshInstance3D.new(); dais.name = "Dais"; dais.mesh = Gfx.merge_boxes(dparts); dais.material_override = kit_mat; G.add_child(dais); MoonShadow.caster(dais)
	var dais_glow := MeshInstance3D.new(); dais_glow.name = "DaisGlow"; dais_glow.mesh = Gfx.merge_boxes(dglow); dais_glow.material_override = glow_mat; G.add_child(dais_glow); MoonShadow.no_receive(dais_glow)
	pit = {"tiles": tiles, "cols": cols, "dais": dais, "dais_glow": dais_glow, "show": [step_mi, land_mi, pit_glow, bottom]}
	# the reactor: a glowing core from the pit's floor to the ceiling, eight rods round it, rings up its length, a slow ring over it
	Phys.add_collider(REACTOR.x - REACTOR.r, PYR_BOTTOM, REACTOR.z - REACTOR.r, REACTOR.x + REACTOR.r, 16, REACTOR.z + REACTOR.r, "metal")
	var core_h := 16.0 - PYR_BOTTOM
	var core := MeshInstance3D.new(); core.name = "Core"; var cm := CylinderMesh.new(); cm.top_radius = 1.2; cm.bottom_radius = 1.2; cm.height = core_h; cm.radial_segments = 24; cm.rings = 0; core.mesh = cm
	core_mat = Gfx.unlit(World.lin("8fd8ff")); core.material_override = core_mat; core.position = Vector3(REACTOR.x, PYR_BOTTOM + core_h / 2, REACTOR.z); G.add_child(core)
	for i in 8: var ra := (i / 8.0) * TAU; solid.push_back([0.22, core_h, 0.22, REACTOR.x + cos(ra) * 1.55, PYR_BOTTOM + core_h / 2, REACTOR.z + sin(ra) * 1.55, "3a4150"])
	for ry: float in [-7.0, -4.0, -1.0, 2.4, 5.5, 9.0, 12.5]:
		var tor := TorusMesh.new(); tor.inner_radius = 1.48; tor.outer_radius = 1.72; tor.rings = 28; tor.ring_segments = 6; pipes.append_from(tor, 0, Transform3D(Basis.IDENTITY, Vector3(REACTOR.x, ry, REACTOR.z)))
	ring = MeshInstance3D.new(); ring.name = "Ring"; var rtor := TorusMesh.new(); rtor.inner_radius = 11.78; rtor.outer_radius = 12.22; rtor.rings = 64; rtor.ring_segments = 6; (ring as MeshInstance3D).mesh = rtor
	(ring as MeshInstance3D).material_override = Gfx.unlit(World.lin("4fb8ff")); ring.position = Vector3(REACTOR.x, 15.6, REACTOR.z); G.add_child(ring)
	for q in PILLARS: box.call(q[0] - 1.2, 0.0, q[1] - 1.2, q[0] + 1.2, 16.0, q[1] + 1.2, "353b48"); glow.push_back([2.44, 0.1, 0.04, q[0], 3.0, q[1] - 1.22, "3a9cff"]); glow.push_back([2.44, 0.1, 0.04, q[0], 3.0, q[1] + 1.22, "3a9cff"])
	for q in [[78.0, 9.0, 2.6, 5.2], [100.0, 37.0, 5.2, 2.6], [134.0, 37.0, 5.2, 2.6], [156.0, -6.0, 2.6, 5.2], [96.0, -41.0, 5.2, 2.6], [132.0, -41.0, 5.2, 2.6], [86.0, 22.0, 5.2, 2.6], [86.0, -26.0, 5.2, 2.6], [78.0, -22.0, 2.6, 5.2]]:
		var h2 := R.rng(5.0, 5.8); var c2: String = ["4b5568", "5a4a3a", "3e5a52", "5a3e44", "41495c"][int(floor(R.next() * 5))]
		box.call(q[0] - q[2] / 2, 0.0, q[1] - q[3] / 2, q[0] + q[2] / 2, h2, q[1] + q[3] / 2, c2); solid.push_back([q[2] + 0.06, 0.18, q[3] + 0.06, q[0], h2 * 0.36, q[1], "e8b040"]); solid.push_back([q[2] + 0.06, 0.18, q[3] + 0.06, q[0], h2 * 0.86, q[1], "e8b040"])
		solid.push_back([q[2] + 0.04, 0.08, q[3] + 0.04, q[0], h2 * 0.5, q[1], "1c2028"])
	var hwin := MeshInstance3D.new(); hwin.name = "HallWindow"; var hwq := QuadMesh.new(); hwq.size = Vector2(56, 7); hwin.mesh = hwq; var hwinm := Gfx.unlit(Color.WHITE); hwinm.albedo_texture = space_tex(0.4)
	hwin.material_override = hwinm; hwin.position = Vector3(161.97, 9, -1.5); hwin.rotation.y = -PI / 2; G.add_child(hwin)
	var lx := 80.0
	while lx <= 152.0:
		var lz := -38.0
		while lz <= 34.0:
			if Vector2(lx - REACTOR.x, lz - REACTOR.z).length() > 14.0: glow.push_back([3.0, 0.06, 1.2, lx, 15.97, lz, "dfeeff"])
			lz += 9.0
		lx += 9.0
	for wy: float in [2.4, 9.0]: glow.push_back([0.04, 0.1, 93.0, 161.96, wy, -1.5, "3a9cff"]); glow.push_back([94.0, 0.1, 0.04, 115.0, wy, -47.96, "3a9cff"]); glow.push_back([94.0, 0.1, 0.04, 115.0, wy, 44.96, "3a9cff"])
	for q in [[84.0, 12.0, -34.0], [84.0, 12.0, 26.0], [152.0, 12.0, -30.0], [152.0, 12.0, 26.0], [120.0, 13.0, -6.0], [100.0, 6.0, -6.0], [140.0, 6.0, -6.0], [120.0, 6.0, 26.0], [120.0, 6.0, -36.0], [76.0, 8.0, -2.0], [160.0, 8.0, -2.0]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	# eight hatches in the floor, shut and dark until the boss's third phase; then two leaves slide apart over a red glow, and a column
	# of red light stands up out of each, bright at the floor and gone by head height (both shown as they are, without tone mapping)
	var ex := Gfx.exposure(float(S.get("exposure", 1.15)))
	var lid_mat := Gfx.std(World.lin("2a2f38"), 0.45, 0.7); var lid_mesh := Gfx.box(Vector3(1.2, 0.06, 2.4)); var shaft_mat := Gfx.untoned(Color.WHITE, shaft_tex(), ex, 0.9, true, true)
	for q in HATCHES:
		glow.push_back([2.7, 0.01, 0.14, q[0], 0.011, q[1] - 1.28, "e8b040"]); glow.push_back([2.7, 0.01, 0.14, q[0], 0.011, q[1] + 1.28, "e8b040"])
		glow.push_back([0.14, 0.01, 2.7, q[0] - 1.28, 0.011, q[1], "e8b040"]); glow.push_back([0.14, 0.01, 2.7, q[0] + 1.28, 0.011, q[1], "e8b040"])
		var la := MeshInstance3D.new(); la.mesh = lid_mesh; la.material_override = lid_mat; la.position = Vector3(q[0] - 0.6, 0.035, q[1]); G.add_child(la)
		var lb2 := MeshInstance3D.new(); lb2.mesh = lid_mesh; lb2.material_override = lid_mat; lb2.position = Vector3(q[0] + 0.6, 0.035, q[1]); G.add_child(lb2)
		var gq := MeshInstance3D.new(); var gp := PlaneMesh.new(); gp.size = Vector2(2.3, 2.3); gq.mesh = gp; gq.material_override = Gfx.untoned(Color("ff4a1e"), null, ex, 0.9); gq.position = Vector3(q[0], 0.012, q[1]); gq.visible = false; G.add_child(gq)
		var sh := MeshInstance3D.new(); var scyl := CylinderMesh.new(); scyl.top_radius = 1.15; scyl.bottom_radius = 1.25; scyl.height = 3.4; scyl.radial_segments = 16; scyl.rings = 0; scyl.cap_top = false; scyl.cap_bottom = false
		sh.mesh = scyl; sh.material_override = shaft_mat; sh.position = Vector3(q[0], 1.7, q[1]); sh.visible = false; G.add_child(sh)
		hatches.push_back({"x": q[0], "z": q[1], "a": la, "b": lb2, "glow": gq, "shaft": sh, "open": false, "k": 0.0})
	MoonShadow.no_receive(hatches[0].a)
	# light and draw: the solid kit (vertex colours), the airlock door, the pipes, everything that glows
	var sm := MeshInstance3D.new(); sm.name = "Solid"; sm.mesh = Gfx.merge_boxes(solid); sm.material_override = kit_mat; G.add_child(sm); MoonShadow.caster(sm)
	air_door = MeshInstance3D.new(); (air_door as MeshInstance3D).mesh = Gfx.box(Vector3(4.5, 4.5, 0.3)); (air_door as MeshInstance3D).material_override = door_mat(4.5, 4.5)
	air_door.position = Vector3(-41.75, 2.25, DOOR_Z); G.add_child(air_door); MoonShadow.no_receive(air_door)
	var pm := MeshInstance3D.new(); pm.name = "Pipes"; pm.mesh = pipes.commit(); pm.material_override = Gfx.std(World.lin("59627a"), 0.45, 0.6); G.add_child(pm); MoonShadow.no_receive(pm)
	var gmesh := MeshInstance3D.new(); gmesh.name = "Glow"; gmesh.mesh = Gfx.merge_boxes(glow); gmesh.material_override = glow_mat; G.add_child(gmesh); MoonShadow.no_receive(gmesh)
	# walking grid: only inside the ship
	Phys.nav_mask = func(nx: float, nz: float) -> bool: return not room_at(nx, nz).is_empty()
	# supply crates along the corridor, in the bridge and round the hall
	var fits := func(fx_: float, fz: float) -> bool:
		var Rm := room_at(fx_, fz)
		if Rm.is_empty() or Rm[5] == "pass": return false
		if in_pit(fx_, fz, 1.4) or Phys.box_at(fx_, fz, 1.3, 0.05, 1.25): return false   # never on the floor over the pit
		return fx_ > Rm[0] + 1.2 and fx_ < Rm[2] - 1.2 and fz > Rm[1] + 1.2 and fz < Rm[3] - 1.2
	var on_gallery := func(gx: float, gz: float) -> bool: return gx >= BR.stairX0 - 1 and gx <= BR.x1 and (gz <= BR.z0 + 6.2 or gz >= BR.z1 - 6.2 or gx >= BR.eastX - 1.2)
	w._place_crates(G, int(S.crates), func() -> Array:
			var k := R.next()
			if k < 0.45: var a := R.rng(-90, 66); var b := R.rng(-11.8, -3.2); return [a, b]
			if k < 0.65: var a2 := R.rng(-122, -98); var b2 := R.rng(-22, 7); return [a2, b2]
			var a3 := R.rng(69, 161); var b3 := R.rng(-47.5, 43.5); return [a3, b3],
		func(px: float, pz: float) -> bool:
			if not fits.call(px, pz) or on_gallery.call(px, pz) or absf(px - DOORS[0].x) <= 3.0 or absf(px - DOORS[1].x) <= 3.0: return false
			for hq in HATCHES:
				if Vector2(hq[0] - px, hq[1] - pz).length() < 2.6: return false
			return true)
	Phys.index_colliders(); Phys.build_nav()
	w.start = START.duplicate(); w.spawns.clear()

func _wall(pass_: int, d: int, a: int, c: Dictionary, GX: float, GZ: float, CS: float, T: float) -> Array:
	if pass_ == 0:
		var zb := GZ + (a if d < 0 else a + 1) * CS
		return [GX + c.b0 * CS, c.y0, zb - T if d < 0 else zb, GX + c.b1 * CS, c.y1 + 0.4, zb if d < 0 else zb + T]
	var xb := GX + (a if d < 0 else a + 1) * CS
	return [xb - T if d < 0 else xb, c.y0, GZ + c.b0 * CS, xb if d < 0 else xb + T, c.y1 + 0.4, GZ + c.b1 * CS]

## stage 4's hundred: the boss over the hall, the gold bee alone on the bridge, cameras up the passage and along the corridor,
## patrols and little drones along the corridor, and mines in the floor of the corridor and the hall
func populate(put: Callable, SR: World.Rng, boss_opts: Dictionary) -> void:
	var bo := {"boss": true, "yaw": -PI / 2}; bo.merge(boss_opts, true)
	var boss = put.call("bdrone", {"x": 106.0, "z": 22.0, "y": 9.5}, bo)
	if boss != null: boss.sealed = true
	var bee = put.call("gdrone", {"x": -108.0, "z": -7.5, "y": 9.5}, {"scale": 1.25, "yaw": PI / 2})
	if bee != null: bee.sealed = true
	for q in [[-43.4, 18.0, PI / 2], [-39.9, 14.2, -PI / 2], [-35.0, 7.45, 0.0], [-28.0, 12.55, PI], [-26.1, 4.0, PI / 2], [-22.4, 0.0, -PI / 2]]: put.call("cctv", {"x": q[0], "z": q[1], "y": 4.05}, {"yaw": q[2]})
	for i in 12: var north := i % 2 == 0; put.call("cctv", {"x": -86.0 + i * 13.3, "z": -12.05 if north else -2.95, "y": 5.55}, {"yaw": 0.0 if north else PI})
	# patrols: twelve walking beats along the corridor in two lanes
	for i in 12:
		var z: float = -5.2 if i % 2 else -9.8; var x0 := -86.0 + i * 12.5; var x1 := minf(64.0, x0 + SR.rng(7, 10)); var px := x0 + SR.rng(0.5, 2)
		var e = put.call("patrol", {"x": px, "z": z}, {"yaw": PI / 2})
		if e != null: e.k.wp = [Vector2(x0, z), Vector2(x1, z)]; e.k.wi = 1; e.k.waitT = SR.rng(0, 2)
	# and eight in the main hall, round the dais, sealed in with the boss
	for q in [[88.0, -45.5, 140.0, -45.5], [88.0, 43.3, 140.0, 43.3], [87.0, -22.0, 87.0, 18.0], [152.0, -22.0, 152.0, 18.0], [100.0, -33.2, 140.0, -33.2], [100.0, 21.2, 140.0, 21.2], [91.0, -26.0, 91.0, 10.0], [148.4, -26.0, 148.4, 10.0]]:
		var e2 = put.call("patrol", {"x": q[0], "z": q[1]}, {"yaw": atan2(q[2] - q[0], q[3] - q[1])})
		if e2 != null: e2.k.wp = [Vector2(q[0], q[1]), Vector2(q[2], q[3])]; e2.k.wi = 1; e2.k.waitT = SR.rng(0, 2); e2.sealed = true
	# little drones: two dozen along the corridor
	for i in 24:
		var dx := -86.0 + i * 6.3 + SR.rng(-1.5, 1.5); var dz := SR.rng(-11, -4); var dy := SR.rng(3, 4.6); var dyaw := SR.rng(0, TAU)
		put.call("droneA", {"x": dx, "z": dz, "y": dy}, {"yaw": dyaw})
	# spider mines, buried: sixteen in the corridor, twenty in the hall, a few metres apart, only on flat floor
	var mines := []
	var lay := func(n: int, x0: float, x1: float, z0: float, z1: float) -> void:
		var i := 0; var tries := 0
		while i < n and tries < 900:
			tries += 1; var x := SR.rng(x0, x1); var z := SR.rng(z0, z1); var y := Phys.ground_at(x, 1, z, 0.05); var flat := true
			for o in [[0.8, 0.0], [-0.8, 0.0], [0.0, 0.8], [0.0, -0.8]]:
				if absf(Phys.ground_at(x + o[0], 1, z + o[1], 0.05) - y) > 0.01: flat = false; break
			if not flat or Phys.collide_at(x, y + 0.05, z, 0.5, 0.6) != null or Vector2(x + 24.25, z + 2.5).length() < 6.0: continue
			var near := false
			for mq: Vector2 in mines:
				if Vector2(mq.x - x, mq.y - z).length() < 3.0: near = true; break
			if near: continue
			if x > DAIS[0][0] - 0.8 and x < DAIS[0][2] + 0.8 and z > DAIS[0][1] - 0.8 and z < DAIS[0][3] + 0.8: continue
			var bad := false
			for hq in HATCHES:
				if Vector2(hq[0] - x, hq[1] - z).length() < 2.2: bad = true
			for D in DOORS:
				if absf(D.x - x) < 4.0: bad = true
			if bad: continue
			var myaw := SR.rng(0, TAU)
			var e3 = put.call("mine", {"x": x, "z": z, "y": y - 0.16}, {"yaw": myaw})
			if e3 != null: e3.bs = "hidden"; e3.k.baseY = y; mines.push_back(Vector2(x, z)); i += 1
	lay.call(16, -88.0, 64.0, -11.6, -3.4)
	lay.call(20, ROOMS[2][0] + 1.5, ROOMS[2][2] - 1.5, ROOMS[2][1] + 1.5, ROOMS[2][3] - 1.5)

func drone(D: Dictionary):
	for o in enemies.list:
		if o.alive and o.type == D.who: return o
	return null

## you stand against a door from the corridor: a short look at what waits inside (the cutscene), then you are put just inside and the door
## shuts and locks behind you until the thing in there is dead
func enter(D: Dictionary) -> void:
	var e = drone(D)
	if e == null: D.mode = "open"; return   # nothing left in there: just a door
	Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
	if on_cut.is_valid(): D.mode = "cut"; on_cut.call(D, e, func() -> void: lock_in(D)); return
	lock_in(D)

func lock_in(D: Dictionary) -> void:
	var e = drone(D)
	var cz: float = (D.z0 + D.z1) / 2
	# nobody follows you in: anything standing in the doorway goes back out into the corridor
	for o in enemies.list:
		if o.alive and o != e and not o.fly and absf(o.pos.z - cz) < 6.0:
			var inside: float = (o.pos.x - D.x) * D.inward
			if inside > -0.6 and inside < 0.6: o.pos.x = D.x - D.inward * 2.5
			elif inside >= 0.6 and inside < 4.0: o.pos.x = D.x + D.inward * 5.0
	player.pos = Vector3(D.x + D.inward * 2.4, 0, cz); player.vel = Vector3.ZERO; player.yaw = PI / 2 if D.inward < 0 else -PI / 2; player.pitch = 0.0
	D.mode = "locked"
	if e != null: e.sealed = false; enemies.alarm(e)
	var here := room_at(player.pos.x, player.pos.z)
	for o in enemies.list:
		if o.alive and o.sealed and room_at(o.pos.x, o.pos.z) == here: o.sealed = false   # the hall's patrols too
	game.say_banner("문이 잠겼습니다", "황금꿀벌드론을 쓰러뜨려야 문이 열립니다" if D.room == "bridge" else "눈이 빨개지고 3초 뒤 빨간 조준선이 쫓아옵니다 · 레이저에 맞으면 즉사 · 벽 뒤로 숨으세요", 2.6)

## the thing behind a door is dead: that door opens for good
func on_down(e) -> void:
	for D in doors:
		if D.who == e.type:
			D.mode = "open"; Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
			if D.room == "bridge": save_t = 2.4   # the 'go and get the key' banner, once the kill banner has had its moment

func key_near() -> bool:   # only once the bee is down
	if key or key_obj == null: return false
	for o in enemies.list:
		if o.alive and o.type == "gdrone": return false
	return Vector2(player.pos.x - KEY.x, player.pos.z - KEY.z).length() < 2.6 and player.pos.y < 2.5

func take_key() -> bool:
	if (game != null and game.ended) or not key_near(): return false   # (a run already over takes no key: no save point without a bag to go back to)
	key = true; key_obj.visible = false; Snd.play("pickup_ammo"); Snd.play("buy")
	game.take_save()   # the save point: from here on, with the key in your pocket
	game.say_banner("세이브 포인트", "메인홀 열쇠 획득 · 이제 쓰러져도 열쇠를 가진 채 여기서 다시 시작합니다", 3.6); game.say_feed("메인홀 열쇠 획득 · 세이브 포인트")
	return true

## back from the save point: the bridge door stands open and the key is in your pocket
func restore(sp: Dictionary) -> void:
	var D: Dictionary = doors[0]; D.mode = "open"; D.open = 1.0
	if D.col != null: Phys.remove_collider(D.col); D.col = null
	_slide(D)
	if sp.key: key = true; key_obj.visible = false

func _slide(D: Dictionary) -> void:
	var w: float = (D.z1 - D.z0) / 2; var k: float = D.open * D.open * (3.0 - 2.0 * D.open); var zc: float = (D.z0 + D.z1) / 2
	(D.a as Node3D).position.z = zc - k * w; (D.b as Node3D).position.z = zc + k * w   # (each leaf all the way into the wall)

## the boss's second phase: the floor round the reactor breaks up and falls into the stepped pit under it. the dais goes with it;
## whatever stood there drops onto the steps (buried mines too, which land and arm again)
func break_floor() -> void:
	if broken: return
	broken = true
	Phys.PIT = {"x0": REACTOR.x - PYR_OX, "x1": REACTOR.x + PYR_OX, "z0": REACTOR.z - PYR_OZ, "z1": REACTOR.z + PYR_OZ, "y": PYR_BOTTOM}
	for c in pit.cols: Phys.remove_collider(c)
	(pit.dais as Node3D).visible = false; (pit.dais_glow as Node3D).visible = false
	for n in pit.show: (n as Node3D).visible = true
	for t in pit.tiles:
		var n: Node3D = t.n; t.d = randf_range(0, 0.9) * (0.4 + 0.6 * Vector2(n.position.x - REACTOR.x, n.position.z - REACTOR.z).length() / PYR_OX); t.vy = 0.0; t.sx = randf_range(-1.6, 1.6); t.sz = randf_range(-1.6, 1.6)
	for o in enemies.list:
		if o.alive and o.type == "mine" and in_pit(o.pos.x, o.pos.z) and (o.bs == "hidden" or o.bs == "arm"): o.bs = "fall"; o.vy = 0.0; o.vel = Vector3.ZERO
	Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	if fx:
		for i in 7: fx.explode(Vector3(REACTOR.x + randf_range(-PYR_OX, PYR_OX) * 0.8, 0.3, REACTOR.z + randf_range(-PYR_OZ, PYR_OZ) * 0.8), i < 2)
	Snd.play("boom", 1.0, Vector3(REACTOR.x, 0, REACTOR.z)); Snd.play("alarm"); player.shake = maxf(player.shake, 0.9); Snd.buzz(260)
	if fx: fx.chunks(Vector3(REACTOR.x, 0.5, REACTOR.z), 40, 0.5, "metal")
	game.say_banner("바닥 붕괴", "메인홀 바닥이 무너져 지하의 역피라미드 계단이 드러났습니다", 3.0)

## the boss's third phase: every hatch in the hall floor slides open and drones come up out of them, a few at a time
func open_hatches() -> void:
	if not hatch_q.is_empty() or hatches[0].open: return
	for Hh in hatches: Hh.open = true
	for i in 32: var Hq: Dictionary = hatches[i % hatches.size()]; hatch_q.push_back({"x": Hq.x, "z": Hq.z, "t": 1.2 + (i / hatches.size()) * 2.2 + randf_range(0, 0.8)})
	Snd.play("alarm"); game.say_banner("해치 개방", "메인홀 바닥에서 드론 수십 대가 출격합니다", 2.6)

## the airlock's inner door: shutting slowly once it is told to (after the opening scene), then held where it is
func anim_door(dt: float) -> void:
	if closing: door_open = maxf(0.0, door_open - dt * 0.9); closing = door_open > 0.0
	if air_door != null: air_door.position.y = 2.25 + door_open * 4.3

func update(dt: float, time: float) -> void:
	anim_door(dt)
	if break_t > 0.0:
		break_t -= dt
		if break_t <= 0.0: break_floor()
	if broken:
		for t in pit.tiles:
			var n: Node3D = t.n
			if not n.visible: continue
			t.d -= dt
			if t.d > 0.0: n.position.y = -0.068 + sin(t.d * 60.0) * 0.03; continue
			t.vy -= 18.0 * dt; n.position.y += t.vy * dt; n.rotation.x += t.sx * dt; n.rotation.z += t.sz * dt
			if n.position.y < PYR_BOTTOM - 2.0: n.visible = false
	# the two doors: shut until you stand right against one from the corridor side (the hall's also wants the key); shut, they stop bullets
	key_hint_t -= dt
	for D in doors:
		if D.mode == "shut" and not game.ended:
			var out: float = (player.pos.x - D.x) * -D.inward   # how far out in the corridor
			if out > 0.0 and out < 1.3 and player.pos.z > D.z0 + 0.3 and player.pos.z < D.z1 - 0.3 and player.pos.y < 2.5:
				if D.needKey and not key:
					if key_hint_t <= 0.0: key_hint_t = 3.5; game.say_hint("메인홀 문이 잠겨 있습니다 · 운전실 조종석에 꽂힌 열쇠가 필요합니다", 3.0); Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
				else: enter(D)
		var want: bool = D.mode == "open"; var o0: float = D.open
		D.open = clampf(D.open + (dt * 2.6 if want else -dt * 2.4), 0.0, 1.0)
		if D.open > 0.55 and D.col != null: Phys.remove_collider(D.col); D.col = null
		if D.open < 0.45 and D.col == null: D.col = Phys.add_collider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, "metal"); D.col.door = true
		if D.open != o0: _slide(D)
	for Hh in hatches:
		Hh.k = minf(1.0, Hh.k + (dt * 1.5 if Hh.open else 0.0)); (Hh.a as Node3D).position.x = Hh.x - 0.6 - Hh.k * 1.15; (Hh.b as Node3D).position.x = Hh.x + 0.6 + Hh.k * 1.15
		var hon: bool = Hh.k > 0.05; (Hh.glow as Node3D).visible = hon; (Hh.shaft as Node3D).visible = hon
		if hon:
			((Hh.glow as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("opacity", 0.75 + 0.2 * sin(time * 8.0 + Hh.x))
			var sy: float = Hh.k * (0.9 + 0.1 * sin(time * 5.0 + Hh.z)); (Hh.shaft as Node3D).scale.y = sy; (Hh.shaft as Node3D).position.y = 1.7 * sy
	if core_mat: var kk := 0.82 + 0.14 * sin(time * 2.6) + 0.04 * sin(time * 19.0); core_mat.albedo_color = World.lin(Color(0.45 * kk, 0.82 * kk, 1.0 * kk))   # (three.js's colour numbers are linear)
	if ring: ring.rotation.y += dt * 0.35
	if screens_mat: var sk := 0.85 + 0.15 * sin(time * 4.3); screens_mat.albedo_color = World.lin(Color(sk, sk, sk))
	if key_obj != null and key_obj.visible: key_obj.rotation.y += dt * 1.2; Gfx.set_alpha(key_glow.material_override, 0.55 + 0.3 * sin(time * 4.0))
	if save_t > 0.0:
		save_t -= dt
		if save_t <= 0.0 and not key: game.say_banner("운전실 문이 열렸습니다", "조종석에 꽂힌 메인홀 열쇠를 뽑으세요 · 뽑으면 세이브 포인트", 3.4)
