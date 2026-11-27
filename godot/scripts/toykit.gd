class_name ToyKit
## Stage 5's look, the pieces: things from a child's desk, drawn flat on the screen. Corrugated cardboard, see-through
## plastic, die-cut stickers, strips of masking tape, a bold hand (the Jua font), and small pictures of the toys' own
## ammunition and of the nine toy guns (side views worked out from the parts their 3D models are built of: Toys.parts).
## Everything draws into `ci`: a control being drawn, or anything with the same draw_* calls (the checks record them).
##
## Nearly all of it is put down as rectangles cut from one small sheet of white shapes (a disc, a ring, rounded corners,
## a star, a drop, the torn end of a tape, the point of a price tag), each given its colour as it is drawn. The renderer
## sends rectangles off the same picture together, however many and however turned; a polygon, a circle, a line or a
## stretching box drawn as such, or a change from the shapes to the letters and back, each costs a call of its own, and a
## phone's browser feels every one of them (drawn that way the toy room's screen took 300 to 600 calls a frame; this
## way some 50). So a rounded box here is nine rectangles, a line a thin turned one, and the words of a piece are held
## back (`hold`) and put down after its shapes, all of one size together (`flush`).

const INK := Color("2b2d42"); const PAPER := Color("fffaf0"); const KRAFT := Color("d2ad72"); const KRAFT_D := Color("a07c48")
const RED := Color("e63946"); const YELLOW := Color("ffd23a"); const BLUE := Color("3d8bd4"); const GREEN := Color("4cc96a"); const ORANGE := Color("f77f00"); const STEEL := Color("c9ced6")
const US := Color("5f9cff"); const THEM := Color("ff5260"); const ME := Color("5ed6b0")
const TAPES := ["9fe0c8", "f7a8b8", "f9dc6b", "9cc9f5", "c9b3f5"]   # masking tape: mint, pink, yellow, sky, lilac
const BRICKS := ["e63946", "f4d35e", "3d7dca", "5fbf8f", "f77f00"]  # the building blocks' five colours (ToyRoom's bridge)
const SHADE := Color(0, 0, 0, 0.26)

# ---------------- the hand ----------------
static var _font: Font
## the bold hand everything in stage 5 is written in (Jua, cut down to the letters the game uses: tools/make_toy_font.py);
## a letter it lacks is drawn by the body font
static func hand() -> Font:
	if _font == null:
		_font = load("res://fonts/jua_Jua-Regular.ttf")
		(_font as FontFile).fallbacks = [load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf")]
	return _font

static func width(s: String, fs: int) -> float: return hand().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

static var hold := false        # words are kept until `flush` (a piece's shapes first, then its words)
static var _held: Array = []     # [has an edge, size, the transform they were written under, place, words, colour, edge, edge colour]

## words with their top at y, left / centre / right of x; an edge of another colour round them if asked. Returns their width
static func text(ci, s: String, x: float, y: float, fs: int, col: Color, align := "left", edge := 0, edge_col := Color.WHITE) -> float:
	var f := hand(); var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var px := x if align == "left" else (x - w / 2.0 if align == "center" else x - w); var py := y + f.get_ascent(fs)
	if hold: _held.push_back([edge > 0, fs, _cur, Vector2(px, py), s, col, edge, edge_col]); return w
	if edge > 0: ci.draw_string_outline(f, Vector2(px, py), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, edge, edge_col)
	ci.draw_string(f, Vector2(px, py), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col); return w

## the words held back, put down now: the edges first, then the words, each size's together
static func flush(ci) -> void:
	hold = false
	if _held.is_empty(): return
	var f := hand(); var sizes := {}
	for q: Array in _held: sizes[q[1]] = true
	for pass_n in 2:
		for fs in sizes:
			for q: Array in _held:
				if q[1] != fs or (pass_n == 0 and not q[0]): continue
				ci.draw_set_transform_matrix(q[2])
				if pass_n == 0: ci.draw_string_outline(f, q[3], q[4], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, q[6], q[7])
				else: ci.draw_string(f, q[3], q[4], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, q[5])
	_held.clear(); _cur = _xf; ci.draw_set_transform_matrix(_xf)

# ---------------- the sheet of white shapes ----------------
const SHEET := Vector2i(1024, 128)
## where each shape lies on the sheet (apart from one another: the sheet is kept at half sizes too, for small drawings)
const SPR := {"px": Rect2(6, 6, 4, 4), "disc": Rect2(32, 8, 64, 64), "ring": Rect2(128, 8, 64, 64), "ring2": Rect2(224, 8, 64, 64), "star": Rect2(320, 8, 64, 64), "starw": Rect2(416, 8, 64, 64),
	"drop": Rect2(512, 8, 40, 64), "r4": Rect2(592, 8, 10, 10), "r6": Rect2(624, 8, 14, 14), "r8": Rect2(660, 8, 18, 18), "r12": Rect2(700, 8, 26, 26),
	"l8": Rect2(750, 8, 18, 18), "l12": Rect2(790, 8, 26, 26), "zig": Rect2(840, 8, 8, 32), "tag": Rect2(872, 8, 24, 32), "bar": Rect2(924, 8, 8, 4)}
static var _sheet: ImageTexture

static func star_pts(c: Vector2, R: float, rot := 0.0, inner := 0.46) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 10: var a := rot - PI / 2.0 + i * PI / 5.0; p.push_back(c + Vector2(cos(a), sin(a)) * (R if i % 2 == 0 else R * inner))
	return p

## how far a point is from a shape's edge, less than nothing inside it: a box with round corners, a polygon
static func _box_sd(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r); return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
static func _poly_sd(p: Vector2, v: PackedVector2Array) -> float:
	var d := INF; var inside := false; var n := v.size(); var j := n - 1
	for i in n:
		var a := v[i]; var b := v[j]; var e := b - a; var w := p - a
		d = minf(d, (w - e * clampf(w.dot(e) / e.length_squared(), 0.0, 1.0)).length_squared())
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x: inside = not inside
		j = i
	return -sqrt(d) if inside else sqrt(d)

## the sheet's picture: every shape white, its edge a pixel soft
static func sheet_image() -> Image:
	var img := Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGBA8); img.fill(Color(1, 1, 1, 0)); img.fill_rect(Rect2i(2, 2, 12, 12), Color.WHITE)
	var put := func(name: String, sd: Callable) -> void:
		var r: Rect2 = SPR[name]
		for y in int(r.size.y):
			for x in int(r.size.x):
				var a := clampf(0.5 - float(sd.call(Vector2(x + 0.5, y + 0.5))), 0.0, 1.0)
				if a > 0.0: img.set_pixel(int(r.position.x) + x, int(r.position.y) + y, Color(1, 1, 1, a))
	var c := Vector2(32, 32)
	put.call("disc", func(p: Vector2) -> float: return p.distance_to(c) - 31.0)
	put.call("ring", func(p: Vector2) -> float: return absf(p.distance_to(c) - 28.5) - 2.5)
	put.call("ring2", func(p: Vector2) -> float: return absf(p.distance_to(c) - 26.0) - 5.0)
	var st := star_pts(c, 31.0); var stw := star_pts(c, 31.0, 0.0, 0.56)
	put.call("star", func(p: Vector2) -> float: return _poly_sd(p, st))
	put.call("starw", func(p: Vector2) -> float: return _poly_sd(p, stw))
	var cone := PackedVector2Array([Vector2(20, 1), Vector2(37, 40), Vector2(3, 40)])
	put.call("drop", func(p: Vector2) -> float: return minf(p.distance_to(Vector2(20, 45)) - 18.0, _poly_sd(p, cone)))
	for rr: int in [4, 6, 8, 12]:
		var h := Vector2(rr + 1.0, rr + 1.0)
		put.call("r%d" % rr, func(p: Vector2) -> float: return _box_sd(p - h, h - Vector2(0.5, 0.5), float(rr) - 0.5))
	for rr: int in [8, 12]:
		var h2 := Vector2(rr + 1.0, rr + 1.0)
		put.call("l%d" % rr, func(p: Vector2) -> float: return absf(_box_sd(p - h2, h2 - Vector2(1.25, 1.25), float(rr) - 1.25)) - 0.75)
	put.call("zig", func(p: Vector2) -> float: return 2.6 * absf(fposmod(p.y, 8.0) / 4.0 - 1.0) - p.x)   # a torn end: teeth 2.6 deep
	put.call("tag", func(p: Vector2) -> float: return maxf((absf(p.y - 16.0) - p.x) * 0.7, 3.5 - p.distance_to(Vector2(12, 16))))   # a point, and a hole for the string
	var bar: Rect2 = SPR.bar   # a line's body: its two long edges soft
	for y in 4:
		for x in 8: img.set_pixel(int(bar.position.x) + x, int(bar.position.y) + y, Color(1, 1, 1, 1.0 if (y == 1 or y == 2) else 0.4))
	img.generate_mipmaps()
	return img

static func sheet() -> ImageTexture:
	if _sheet == null: _sheet = ImageTexture.create_from_image(sheet_image())
	return _sheet

# ---------------- putting shapes down ----------------
static var _xf := Transform2D.IDENTITY; static var _cur := Transform2D.IDENTITY
## the place, turn and size everything that follows is drawn at; `sub` turns or leans one thing within it, `unsub` goes back
static func at(ci, t: Transform2D) -> void: _xf = t; _cur = t; ci.draw_set_transform_matrix(t)
static func sub(ci, pos: Vector2, rot := 0.0, sc := Vector2.ONE, skew := 0.0) -> void: _cur = _xf * Transform2D(rot, sc, skew, pos); ci.draw_set_transform_matrix(_cur)
static func unsub(ci) -> void: _cur = _xf; ci.draw_set_transform_matrix(_xf)

static func solid(ci, r: Rect2, col: Color) -> void: ci.draw_texture_rect_region(sheet(), r, SPR.px, col)
static func disc(ci, c: Vector2, r: float, col: Color) -> void: ci.draw_texture_rect_region(sheet(), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), SPR.disc, col)
## a ring out to r (its line an eleventh of that; a fifth with `thick`, for small ones)
static func ring(ci, c: Vector2, r: float, col: Color, thick := false) -> void: ci.draw_texture_rect_region(sheet(), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), SPR.ring2 if thick else SPR.ring, col)
## the upper or the lower half of a disc
static func half(ci, c: Vector2, r: float, col: Color, upper: bool) -> void:
	var s: Rect2 = SPR.disc
	if upper: ci.draw_texture_rect_region(sheet(), Rect2(c.x - r, c.y - r, r * 2.0, r), Rect2(s.position, Vector2(64, 32)), col)
	else: ci.draw_texture_rect_region(sheet(), Rect2(c.x - r, c.y, r * 2.0, r), Rect2(s.position + Vector2(0, 32), Vector2(64, 32)), col)
## a drop, k tall, its point up
static func drop(ci, c: Vector2, k: float, col: Color) -> void: ci.draw_texture_rect_region(sheet(), Rect2(c.x - k * 0.3125, c.y - k * 0.5, k * 0.625, k), SPR.drop, col)
## a line: a thin rectangle turned along it (a darker, wider one under it if asked, so it shows on anything)
static func line(ci, a: Vector2, b: Vector2, col: Color, w := 2.0, under := false) -> void:
	var d := b - a; var L := d.length()
	if L <= 0.0: return
	var back := _cur; _cur = back * Transform2D(d.angle(), a); ci.draw_set_transform_matrix(_cur)
	if under: ci.draw_texture_rect_region(sheet(), Rect2(-1.0, -w / 2.0 - 1.5, L + 2.0, w + 3.0), SPR.bar, Color(0, 0, 0, 0.3 * col.a))
	ci.draw_texture_rect_region(sheet(), Rect2(0.0, -w / 2.0 - 0.5, L, w + 1.0), SPR.bar, col)
	_cur = back; ci.draw_set_transform_matrix(back)

## a corner piece of the sheet stretched over a rectangle as nine pieces: the corners keep their size, the sides and the
## middle stretch (rectangles off the sheet as everything else: a box that stretches by itself is sent off alone)
static func _nine(ci, spr: String, d: Rect2, col: Color, middle := true) -> void:
	var s: Rect2 = SPR[spr]; var mg := (s.size.x - 2.0) / 2.0; var cx := minf(mg, d.size.x / 2.0); var cy := minf(mg, d.size.y / 2.0); var tex := sheet()
	var xs := [d.position.x, d.position.x + cx, d.end.x - cx, d.end.x]; var ys := [d.position.y, d.position.y + cy, d.end.y - cy, d.end.y]
	var us := [s.position.x, s.position.x + mg, s.end.x - mg, s.end.x]; var vs := [s.position.y, s.position.y + mg, s.end.y - mg, s.end.y]
	for j in 3:
		if ys[j + 1] - ys[j] <= 0.0: continue
		for i in 3:
			if xs[i + 1] - xs[i] <= 0.0 or (i == 1 and j == 1 and not middle): continue
			ci.draw_texture_rect_region(tex, Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j]), Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]), col)
static func _corner(radius: float) -> int: return 4 if radius < 5.0 else (6 if radius < 7.0 else (8 if radius < 10.0 else 12))

## a box with round corners (4, 6, 8 or 12: the nearest that fits), an edge of another colour round it and a shadow under it if asked
static func rbox(ci, r: Rect2, col: Color, radius := 6.0, edge = null, edge_w := 0.0, shadow := false) -> void:
	var spr := "r%d" % _corner(minf(radius, minf(r.size.x, r.size.y) / 2.0)); var out := r.grow(edge_w) if edge != null else r
	if shadow: _nine(ci, spr, Rect2(out.position + Vector2(1.0, 2.5), out.size), Color(0, 0, 0, SHADE.a * col.a))
	if edge != null: _nine(ci, spr, out, edge)
	_nine(ci, spr, r, col)

static var _kraft: ImageTexture
## corrugated cardboard, in greys to be tinted: the flutes every 6 pixels, a little grain
static func kraft_tex() -> ImageTexture:
	if _kraft == null:
		var n := 256; var img := Image.create(n, n, false, Image.FORMAT_RGBA8); var R := RandomNumberGenerator.new(); R.seed = 5
		for x in n:
			var v := 0.9 + 0.07 * (0.5 + 0.5 * sin(x * TAU / 6.0)); img.fill_rect(Rect2i(x, 0, 1, n), Color(v, v, v))
		for i in 2600:
			var px := R.randi_range(0, n - 1); var py := R.randi_range(0, n - 1); var c := img.get_pixel(px, py); var d := R.randf_range(-0.06, 0.05)
			img.set_pixel(px, py, Color(c.r + d, c.g + d, c.b + d))
		_kraft = ImageTexture.create_from_image(img)
	return _kraft

## a card of corrugated cardboard with a shadow under it
static func card(ci, r: Rect2, col := KRAFT, radius := 8.0) -> void:
	rbox(ci, r, col, radius, col.darkened(0.22), 1.0, true)
	var inr := r.grow(-radius * 0.6); var src := Rect2(Vector2.ZERO, Vector2(minf(inr.size.x, 256.0), minf(inr.size.y, 256.0)))
	if inr.size.x > 2.0 and inr.size.y > 2.0: ci.draw_texture_rect_region(kraft_tex(), inr, src, Color(col.r, col.g, col.b, 0.9))

## a clear plastic bubble: a faint body, a bright rim, two streaks of light leaning across it
static func plastic(ci, r: Rect2, radius := 8.0) -> void:
	var big := minf(r.size.x, r.size.y) >= 26.0 and radius >= 10.0
	rbox(ci, r, Color(1, 1, 1, 0.16), 12.0 if big else 8.0); _nine(ci, "l12" if big else "l8", r, Color(1, 1, 1, 0.62), false)
	var w := minf(r.size.x * 0.34, 46.0); var h := r.size.y - 6.0
	if h < 6.0 or w < 6.0: return
	sub(ci, Vector2(r.position.x + r.size.x * 0.1 + h * 0.35, r.position.y + 3.0), 0.0, Vector2.ONE, -0.34)
	solid(ci, Rect2(0, 0, w * 0.5, h), Color(1, 1, 1, 0.16)); solid(ci, Rect2(w * 0.62, 0, w * 0.14, h), Color(1, 1, 1, 0.12)); unsub(ci)

## a die-cut sticker: its colour inside a white edge, a shadow
static func sticker(ci, r: Rect2, col: Color, radius := 6.0) -> void: rbox(ci, r, col, radius, Color(1, 1, 1, col.a), 2.0, true)

## a strip of masking tape, its two ends torn in a zigzag (the caller turns it)
static func tape(ci, r: Rect2, col: Color, a := 0.92) -> void:
	var e := minf(8.0, r.size.x * 0.3)
	for pass_n in 2:
		var o := Vector2(0.8, 1.6) if pass_n == 0 else Vector2.ZERO; var c := Color(0, 0, 0, 0.2 * a) if pass_n == 0 else Color(col, a); var p := r.position + o
		ci.draw_texture_rect_region(sheet(), Rect2(p.x, p.y, e, r.size.y), SPR.zig, c); ci.draw_texture_rect_region(sheet(), Rect2(p.x + r.size.x - e, p.y, -e, r.size.y), SPR.zig, c)   # (the far end: the same piece turned round)
		solid(ci, Rect2(p.x + e, p.y, r.size.x - 2.0 * e, r.size.y), c)
	solid(ci, Rect2(r.position.x + 3.0, r.position.y + 1.0, r.size.x - 6.0, maxf(1.0, r.size.y * 0.2)), Color(1, 1, 1, 0.25 * a))

static func tape_col(i: int) -> Color: return Color(str(TAPES[posmod(i, TAPES.size())]))

## a price tag: pointed at its left end, a hole there for the string
static func price_tag(ci, r: Rect2, col := RED) -> void:
	var e := r.size.y * 0.75
	for pass_n in 2:
		var o := Vector2(1.0, 2.0) if pass_n == 0 else Vector2.ZERO; var c := Color(0, 0, 0, SHADE.a * col.a) if pass_n == 0 else col; var p := r.position + o
		ci.draw_texture_rect_region(sheet(), Rect2(p.x, p.y, e, r.size.y), SPR.tag, c); solid(ci, Rect2(p.x + e, p.y, r.size.x - e, r.size.y), c)

## a star sticker with its white edge
static func star(ci, c: Vector2, R: float, col: Color, rot := 0.0, a := 1.0) -> void:
	sub(ci, c, rot); var w := R * 1.25
	ci.draw_texture_rect_region(sheet(), Rect2(-w + 0.8, -w + 1.6, w * 2.0, w * 2.0), SPR.starw, Color(0, 0, 0, 0.22 * a))
	ci.draw_texture_rect_region(sheet(), Rect2(-w, -w, w * 2.0, w * 2.0), SPR.starw, Color(1, 1, 1, a)); ci.draw_texture_rect_region(sheet(), Rect2(-R, -R, R * 2.0, R * 2.0), SPR.star, Color(col, a)); unsub(ci)

## a ddakji: the folded paper tile children slap on the ground, two colours in its four squares
static func ddakji(ci, c: Vector2, R: float, col_a: Color, col_b: Color, rot := 0.0, a := 1.0) -> void:
	sub(ci, c, rot); var h := R * 0.8
	solid(ci, Rect2(-h * 1.14 + 1.0, -h * 1.14 + 2.0, h * 2.28, h * 2.28), Color(0, 0, 0, 0.25 * a)); solid(ci, Rect2(-h * 1.14, -h * 1.14, h * 2.28, h * 2.28), Color(1, 1, 1, a))
	solid(ci, Rect2(-h, -h, h, h), Color(col_a, a)); solid(ci, Rect2(0, 0, h, h), Color(col_a, a)); solid(ci, Rect2(0, -h, h, h), Color(col_b, a)); solid(ci, Rect2(-h, 0, h, h), Color(col_b, a))
	disc(ci, Vector2.ZERO, h * 0.3, Color(1, 1, 1, 0.9 * a)); unsub(ci)

## a pushpin seen from above, standing in the paper: its shadow, its head, a glint
static func pin(ci, p: Vector2, r: float, col: Color, a := 1.0) -> void:
	disc(ci, p + Vector2(r * 0.4, r * 0.55), r, Color(0, 0, 0, 0.28 * a))
	disc(ci, p, r, Color(col.darkened(0.3), a)); disc(ci, p, r * 0.72, Color(col, a)); disc(ci, p + Vector2(-r * 0.26, -r * 0.3), r * 0.24, Color(1, 1, 1, 0.8 * a))

# ---------------- the toys' ammunition ----------------
## what a gun's rounds look like in the tray, how many pockets the tray has for them (across, down) and how many rounds a
## pocket stands for (the gatling's 240 bands lie eight to a pocket)
const TRAY := {
	"pistol": {"icon": "dart", "cols": 6, "rows": 2, "per": 1},
	"shotgun": {"icon": "drop", "cols": 6, "rows": 1, "per": 1},
	"rifle": {"icon": "dart2", "cols": 10, "rows": 3, "per": 1},
	"smg": {"icon": "cap", "cols": 10, "rows": 4, "per": 1},
	"sniper": {"icon": "tack", "cols": 5, "rows": 1, "per": 1},
	"gl": {"icon": "ball", "cols": 6, "rows": 1, "per": 1},
	"lmg": {"icon": "band", "cols": 10, "rows": 3, "per": 8},
	"rocket": {"icon": "rocket", "cols": 1, "rows": 1, "per": 1},
	"flame": {"icon": "puff", "cols": 10, "rows": 3, "per": 4},
}

## one round, about k pixels tall, standing with its middle at c; n picks a bouncy ball's colour
static func ammo(ci, icon: String, c: Vector2, k: float, a := 1.0, n := 0) -> void:
	match icon:
		"dart", "dart2":   # a foam dart: the shaft and its rubber head (the pistol's white with a red sucker, the blaster's blue with an orange tip)
			var body := Color("f2f2f2") if icon == "dart" else Color("3d8bd4"); var head := RED if icon == "dart" else ORANGE
			solid(ci, Rect2(c.x - k * 0.15, c.y - k * 0.12, k * 0.3, k * 0.6), Color(body, a)); solid(ci, Rect2(c.x - k * 0.15, c.y + k * 0.34, k * 0.3, k * 0.14), Color(body.darkened(0.25), a))
			disc(ci, c + Vector2(0, -k * 0.22), k * 0.25, Color(head, a))
		"drop":   # a drop of water
			drop(ci, c, k * 0.95, Color(BLUE, a)); disc(ci, c + Vector2(-k * 0.1, k * 0.1), k * 0.09, Color(1, 1, 1, 0.75 * a))
		"cap":   # a paper cap off the ring
			disc(ci, c, k * 0.36, Color(RED, a)); disc(ci, c, k * 0.15, Color(Color("5a1a1f"), a))
		"tack":  # a red pushpin
			disc(ci, c, k * 0.36, Color(RED.darkened(0.3), a)); disc(ci, c, k * 0.26, Color(RED, a)); disc(ci, c + Vector2(-k * 0.09, -k * 0.1), k * 0.08, Color(1, 1, 1, 0.8 * a))
		"ball":  # a bouncy ball
			disc(ci, c, k * 0.4, Color(Color(str(BRICKS[posmod(n, BRICKS.size())])), a)); disc(ci, c + Vector2(-k * 0.13, -k * 0.15), k * 0.1, Color(1, 1, 1, 0.8 * a))
		"band":  # a rubber band
			ci.draw_texture_rect_region(sheet(), Rect2(c.x - k * 0.32, c.y - k * 0.44, k * 0.64, k * 0.88), SPR.ring2, Color(Color("c98b3a"), a))
		"puff":  # a puff of the spray, alight
			drop(ci, c, k * 0.95, Color(ORANGE, a)); disc(ci, c + Vector2(0, k * 0.2), k * 0.14, Color(YELLOW, a))
		"rocket":   # a bottle rocket lying along the tray: its stick, the body, a yellow band, the nose, the fuse
			var L := k * 2.6
			solid(ci, Rect2(c.x - L * 0.5, c.y + k * 0.06, L * 0.62, maxf(1.5, k * 0.07)), Color(Color("e9c46a"), a))
			solid(ci, Rect2(c.x - L * 0.02, c.y - k * 0.2, L * 0.34, k * 0.4), Color(RED, a)); solid(ci, Rect2(c.x + L * 0.2, c.y - k * 0.2, L * 0.07, k * 0.4), Color(YELLOW, a))
			disc(ci, Vector2(c.x + L * 0.32, c.y), k * 0.2, Color(YELLOW, a))
			solid(ci, Rect2(c.x - L * 0.06, c.y - k * 0.4, maxf(1.0, k * 0.06), k * 0.22), Color(BLUE, a))

## an empty pocket of the tray
static func pocket(ci, c: Vector2, k: float) -> void: disc(ci, c, k * 0.2, Color(0, 0, 0, 0.16))

# ---------------- the nine toy guns, from the side ----------------
static var _shapes := {}
const HIDE := ["bottle", "lighter"]   # parts a reload brings out: not in the picture
## a toy's side view: {"parts": [["r", Rect2, Color] or ["c", centre, radius, Color]], "box": Rect2}, in metres, the barrel to the right
static func gun_shape(id: String) -> Dictionary:
	if _shapes.has(id): return _shapes[id]
	var out := []; var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for p0: Array in Toys.parts(id):
		var p := p0.duplicate()
		if p[p.size() - 1] is String and str(p[p.size() - 1]).begins_with("@"):
			if str(p.pop_back()).substr(1) in HIDE: continue
		var r := Rect2(); var round := false; var c := Vector2.ZERO; var rad := 0.0; var col := Color.WHITE
		if p[0] == "b":
			r = Rect2(-float(p[6]) - float(p[3]) / 2.0, -float(p[5]) - float(p[2]) / 2.0, float(p[3]), float(p[2])); col = Color(str(p[7]))
			if p.size() > 10: col.a = float(p[10])
		elif p[0] == "c":
			var cx := -float(p[5]); var cy := -float(p[4]); col = Color(str(p[6])); rad = float(p[1])
			if p.size() > 11: col.a = float(p[11])
			if str(p[7]) == "z": r = Rect2(cx - float(p[2]) / 2.0, cy - rad, float(p[2]), rad * 2.0)
			elif str(p[7]) == "y": r = Rect2(cx - rad, cy - float(p[2]) / 2.0, rad * 2.0, float(p[2]))
			else: round = true; c = Vector2(cx, cy)
		else: round = true; c = Vector2(-float(p[4]), -float(p[3])); rad = float(p[1]); col = Color(str(p[5]))
		if round: r = Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0); out.push_back(["c", c, rad, col])
		else: out.push_back(["r", r, col])
		lo = Vector2(minf(lo.x, r.position.x), minf(lo.y, r.position.y)); hi = Vector2(maxf(hi.x, r.end.x), maxf(hi.y, r.end.y))
	_shapes[id] = {"parts": out, "box": Rect2(lo, hi - lo)}
	return _shapes[id]

## the toy's picture fitted into a rectangle, its middle in the rectangle's
static func gun(ci, id: String, into: Rect2, a := 1.0) -> void:
	var S := gun_shape(id); var b: Rect2 = S.box
	if b.size.x <= 0.0 or b.size.y <= 0.0: return
	var k := minf(into.size.x / b.size.x, into.size.y / b.size.y); var o := into.get_center() - b.get_center() * k
	for q: Array in S.parts:
		var col: Color = q[q.size() - 1]; col.a *= a
		if q[0] == "r": var r: Rect2 = q[1]; solid(ci, Rect2(o + r.position * k, Vector2(maxf(1.0, r.size.x * k), maxf(1.0, r.size.y * k))), col)
		else: disc(ci, o + (q[1] as Vector2) * k, maxf(0.8, float(q[2]) * k), col)

# ---------------- small things of the room ----------------
## a building block seen from the side: its body and two studs
static func brick(ci, r: Rect2, col: Color, a := 1.0) -> void:
	solid(ci, r, Color(col, a)); solid(ci, Rect2(r.position.x, r.end.y - maxf(1.0, r.size.y * 0.2), r.size.x, maxf(1.0, r.size.y * 0.2)), Color(col.darkened(0.25), a))
	var sw := r.size.x * 0.26; var shh := r.size.y * 0.3
	for i in 2: solid(ci, Rect2(r.position.x + r.size.x * (0.14 + i * 0.46), r.position.y - shh, sw, shh), Color(col.lightened(0.12), a))

## an AA battery standing up, as the batteries of the battery rush: its body, the gold cap, the nub
static func aa(ci, r: Rect2, a := 1.0) -> void:
	solid(ci, Rect2(r.position.x + r.size.x * 0.3, r.position.y, r.size.x * 0.4, r.size.y * 0.1), Color(STEEL, a))
	solid(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.1, r.size.x, r.size.y * 0.9), Color(Color("23252f"), a)); solid(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.1, r.size.x, r.size.y * 0.24), Color(Color("d98f3d"), a))

# ---------------- the toy shop's shelf ----------------
const MODE_CARD := {"sweep": "8fd18a", "rush": "f6d55c", "escort": "8cc4f5", "freeze": "c7b2f2"}   # each mode's package

## a name on one line, or broken in two at the space nearest its middle when it is wider than `room`
static func two_lines(s: String, fs: int, room: float) -> Array:
	if width(s, fs) <= room or not s.contains(" "): return [s]
	var best := -1; var at_i := 0
	while true:
		at_i = s.find(" ", at_i + 1)
		if at_i < 0: break
		if best < 0 or absi(at_i - s.length() / 2) < absi(best - s.length() / 2): best = at_i
	return [s.substr(0, best), s.substr(best + 1)]

## a package off the shelf, drawn into a control of this size: a coloured card with the slot it hangs by, a clear bubble
## with `inside` drawn in it (it is handed the bubble's rectangle), its name under the bubble, a price tag across its
## foot; the one picked stands a little forward in a yellow edge with a strip of tape saying so. `pop` (0..1) is how far
## what is inside has sprung out of the bubble after its package was torn open; `done` puts a star on a mode already won;
## `badge` a number on a round yellow sticker at its corner, as a toy's key
static func pack(ci, size: Vector2, title: String, col: Color, tag: String, picked: bool, lit: bool, done: bool, inside: Callable, pop := 0.0, badge := "") -> void:
	at(ci, Transform2D.IDENTITY)
	var k := size.x / 160.0; var lift := -3.0 * k if picked else 0.0
	var cr := Rect2(6.0 * k, 9.0 * k + lift, size.x - 12.0 * k, size.y - 15.0 * k)
	if picked: rbox(ci, cr.grow(4.0 * k), YELLOW, 12.0)
	elif lit: rbox(ci, cr.grow(2.5 * k), Color(1, 1, 1, 0.9), 12.0)
	card(ci, cr, col, 8.0)
	solid(ci, Rect2(cr.get_center().x - 12.0 * k, cr.position.y + 6.0 * k, 24.0 * k, 5.0 * k), Color(0, 0, 0, 0.3))
	var bub := Rect2(cr.position.x + 10.0 * k, cr.position.y + 18.0 * k, cr.size.x - 20.0 * k, cr.size.y * 0.5)
	var spring := sin(clampf(pop, 0.0, 1.0) * PI); var into := bub.grow(-5.0 * k + 9.0 * k * spring)
	rbox(ci, bub, Color(1, 1, 1, 0.5), 12.0)   # the card's pale inside, so what is in the bubble shows
	if spring < 0.05: inside.call(into); plastic(ci, bub, 10.0)
	else: plastic(ci, bub, 10.0); inside.call(Rect2(into.position + Vector2(0, -8.0 * k * spring), into.size))   # (out of its bubble for a moment)
	var fs := maxi(10, int(15.0 * k)); var lines := two_lines(title, fs, cr.size.x - 10.0 * k); var ty := bub.end.y + (4.0 if lines.size() > 1 else 10.0) * k
	for ln: String in lines: text(ci, ln, cr.get_center().x, ty, fs, INK, "center"); ty += fs * 1.08
	if tag != "":
		var tfs := maxi(9, int(11.0 * k)); var tw := width(tag, tfs) + 22.0 * k; var tr := Rect2(cr.get_center().x - tw / 2.0, cr.end.y - 23.0 * k, tw, 17.0 * k)
		price_tag(ci, tr); text(ci, tag, tr.end.x - 5.0 * k, tr.position.y + 1.0 * k, tfs, Color.WHITE, "right")
	if done: star(ci, Vector2(cr.end.x - 11.0 * k, cr.position.y + 12.0 * k), 9.0 * k, YELLOW, 0.2)
	if badge != "":
		var bc := Vector2(cr.position.x + 13.0 * k, cr.position.y + 12.0 * k); var bfs := maxi(11, int(16.0 * k))
		disc(ci, bc + Vector2(0.8, 1.8), 12.0 * k, SHADE); disc(ci, bc, 12.0 * k, Color.WHITE); disc(ci, bc, 10.0 * k, YELLOW); text(ci, badge, bc.x, bc.y - bfs * 0.62, bfs, INK, "center")
	if picked:
		sub(ci, Vector2(cr.position.x + 20.0 * k, cr.position.y + 6.0 * k), -0.28)
		tape(ci, Rect2(-20.0 * k, -8.0 * k, 40.0 * k, 16.0 * k), Color(str(TAPES[1]))); text(ci, "선택", 0, -8.0 * k, maxi(9, int(11.0 * k)), INK, "center"); unsub(ci)

## one of the room's toys standing on its base: a head, a body, two legs, a little gun
static func figure(ci, foot: Vector2, h: float, col: Color) -> void:
	var w := h * 0.36; var dk := col.darkened(0.25)
	solid(ci, Rect2(foot.x - w * 0.75, foot.y - h * 0.06, w * 1.5, h * 0.06), dk)
	solid(ci, Rect2(foot.x - w * 0.42, foot.y - h * 0.42, w * 0.34, h * 0.37), col); solid(ci, Rect2(foot.x + w * 0.08, foot.y - h * 0.42, w * 0.34, h * 0.37), col)
	solid(ci, Rect2(foot.x - w * 0.5, foot.y - h * 0.76, w, h * 0.36), col); disc(ci, Vector2(foot.x, foot.y - h * 0.87), h * 0.13, col.lightened(0.1))
	solid(ci, Rect2(foot.x + w * 0.3, foot.y - h * 0.66, w * 0.95, h * 0.07), INK)

## what a mode's package shows in its bubble: the sweep three of the room's toys, the battery rush its batteries, the
## escort the toy train, bedtime the bed
static func scene(ci, what: String, r: Rect2) -> void:
	var u := r.size.y / 72.0; var b := r.end.y - 2.0 * u; var cx := r.get_center().x
	match what:
		"rush":
			for i in 3: aa(ci, Rect2(cx - 40.0 * u + i * 21.0 * u, b - (54.0 - i * 9.0) * u, 16.0 * u, (54.0 - i * 9.0) * u))
			var o := Vector2(cx + 34.0 * u, b - 52.0 * u)   # a bolt of charge (the one shape here drawn as itself: a menu's screen, drawn once)
			var bolt := PackedVector2Array([o, o + Vector2(-14, 26) * u, o + Vector2(-3, 26) * u, o + Vector2(-10, 50) * u, o + Vector2(12, 18) * u, o + Vector2(1, 18) * u, o + Vector2(8, 0) * u])
			ci.draw_colored_polygon(bolt, ORANGE); bolt.push_back(bolt[0]); ci.draw_polyline(bolt, INK, maxf(1.0, 1.5 * u))
		"escort":
			solid(ci, Rect2(r.position.x, b - 3.0 * u, r.size.x, 3.0 * u), Color("8d99ae"))   # the rail and its sleepers
			for i in 7: solid(ci, Rect2(r.position.x + r.size.x * (i + 0.3) / 7.0, b - 1.0 * u, 5.0 * u, 3.0 * u), KRAFT_D)
			var x := cx + 4.0 * u   # the engine: boiler, cab, chimney, roof
			solid(ci, Rect2(x, b - 26.0 * u, 36.0 * u, 18.0 * u), RED); solid(ci, Rect2(x - 2.0 * u, b - 40.0 * u, 17.0 * u, 32.0 * u), RED.darkened(0.12)); solid(ci, Rect2(x - 5.0 * u, b - 44.0 * u, 23.0 * u, 5.0 * u), YELLOW)
			solid(ci, Rect2(x + 24.0 * u, b - 38.0 * u, 7.0 * u, 12.0 * u), INK); solid(ci, Rect2(x + 2.0 * u, b - 35.0 * u, 9.0 * u, 9.0 * u), Color("bfe6ff"))
			for i in 3: disc(ci, Vector2(x + 5.0 * u + i * 13.0 * u, b - 8.0 * u), 5.5 * u, INK); disc(ci, Vector2(x + 5.0 * u + i * 13.0 * u, b - 8.0 * u), 2.0 * u, STEEL)
			var wx := cx - 44.0 * u   # the wagon behind it, a crate on it
			solid(ci, Rect2(wx, b - 17.0 * u, 38.0 * u, 9.0 * u), BLUE); solid(ci, Rect2(wx + 8.0 * u, b - 31.0 * u, 20.0 * u, 14.0 * u), KRAFT); solid(ci, Rect2(wx + 38.0 * u, b - 13.0 * u, 8.0 * u, 2.0 * u), INK)
			for i in 2: disc(ci, Vector2(wx + 8.0 * u + i * 22.0 * u, b - 8.0 * u), 5.5 * u, INK); disc(ci, Vector2(wx + 8.0 * u + i * 22.0 * u, b - 8.0 * u), 2.0 * u, STEEL)
		"freeze":
			var wood := Color("8cc456")
			solid(ci, Rect2(cx - 46.0 * u, b - 14.0 * u, 92.0 * u, 8.0 * u), wood); solid(ci, Rect2(cx - 46.0 * u, b - 6.0 * u, 6.0 * u, 6.0 * u), wood); solid(ci, Rect2(cx + 40.0 * u, b - 6.0 * u, 6.0 * u, 6.0 * u), wood)
			solid(ci, Rect2(cx - 46.0 * u, b - 34.0 * u, 7.0 * u, 20.0 * u), wood)   # the headboard, the pillow, the blanket with someone under it
			solid(ci, Rect2(cx - 36.0 * u, b - 24.0 * u, 20.0 * u, 10.0 * u), Color.WHITE); solid(ci, Rect2(cx - 12.0 * u, b - 26.0 * u, 54.0 * u, 12.0 * u), Color("6aa3d6")); disc(ci, Vector2(cx - 24.0 * u, b - 29.0 * u), 7.0 * u, Color("f0d9b0"))
			var zs := maxi(8, int(15.0 * u))
			for i in 3: text(ci, "Z", cx - 6.0 * u + i * 14.0 * u, b - (50.0 + i * 8.0) * u, zs + i * 2, INK, "left", 3)
		_:
			figure(ci, Vector2(cx - 32.0 * u, b), 46.0 * u, Color("7fc96b")); figure(ci, Vector2(cx - 2.0 * u, b), 58.0 * u, Color("ff7a3a")); figure(ci, Vector2(cx + 30.0 * u, b), 44.0 * u, Color("ffd23a"))

## the plank of the shelf the packages stand on, along the foot of a row
static func plank(ci, r: Rect2) -> void:
	at(ci, Transform2D.IDENTITY); rbox(ci, r, Color("9a6b3f"), 4.0, Color("6f4a28"), 1.0, true); solid(ci, Rect2(r.position.x + 2.0, r.position.y + 1.5, r.size.x - 4.0, 2.0), Color(1, 1, 1, 0.22))
