class_name Reward
extends Node
## A boss's chest giving you a gun you did not have, or 6-A's spoils (start_spoils): shown big. A card across the upper middle of the screen (the crosshair
## stays clear under it) with the gun's name in large letters and the gun itself turning in it, gold rays wheeling behind,
## confetti blown up from both sides and raining down, fireworks bursting over it, and a fanfare (sounds/reward_fanfare.wav).
## Game.party_t holds the stage's clear back until it has been seen. Its own random numbers: the game's are not drawn.

const LONG := 4.8           # how long it is on, seconds (Game.PARTY waits as long)
const COLS := ["f2c14e", "ff5260", "5ed6b0", "5f9cff", "ffffff", "f78fb3", "ffa94d"]
const GOLD := Color("f2c14e"); const GOLD_DEEP := Color("b8862a"); const NIGHT := Color(0.04, 0.06, 0.12, 0.93); const INK := Color("ece6d8")

var m                       # main: the fonts
var id := ""                # the gun won ("" when nothing is on; "spoils" for 6-A's)
var kind := "gun"           # gun, or spoils: 6-A's spoils, a row for each thing (RaidLoot.grant's list)
var rows: Array = []        # the spoils' rows: {kind, id, n, name}
var head := ""; var sub_head := ""
var t := 0.0                # how long it has been on
var bits: Array = []        # the confetti: [x, y, vx, vy, angle, spin, colour, w, h, flutter phase], in pixels of the screen
var booms: Array = []       # the fireworks: [x, y, at, colour, directions: Array of [angle, speed]]
var stars: Array = []       # glints round the card: [x, y (0..1 of the card), phase]
var vp: SubViewport         # the gun turning, drawn into a picture of its own (a little world of its own, with its own lights)
var turn: Node3D
var models: GunModels
var _R := RandomNumberGenerator.new()
var _size := Vector2(1280, 720)

func on() -> bool: return id != ""

## the gun won, on a screen this big: everything starts from here
func start(gun: String, screen: Vector2) -> void:
	kind = "gun"; id = gun
	_party(screen)
	_show_gun()
	Snd.play("reward_fanfare")

## 6-A won: the spoils, a row each, under the rank (and the difficulty past the Normal)
func start_spoils(list: Array, rank: String, diff: String, screen: Vector2) -> void:
	kind = "spoils"; id = "spoils"; rows = list.duplicate(); head = "토벌 보상 · 등급 " + rank
	sub_head = ("난이도 " + str(RaidLoot.DIFF[diff].name) + " · " if diff != "normal" else "") + "연금술 공방(처음 화면)에 보관됩니다"
	_party(screen)
	if vp != null: vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Snd.play("reward_fanfare")
	if rows.any(func(r): return str(r.kind) == "relic" or str(r.kind) == "box" or str(r.kind) == "look"): Snd.play("rd_relic", 1.1)

## the confetti, the fireworks and the glints, made anew
func _party(screen: Vector2) -> void:
	t = 0.0; _size = screen; bits.clear(); booms.clear(); stars.clear(); _R.randomize()
	var k := screen.y / 720.0
	for side: float in [-1.0, 1.0]:   # two cannons low at the sides, aimed up and in
		for i in 55:
			var a := deg_to_rad(_R.randf_range(55.0, 82.0)); var sp := _R.randf_range(900.0, 1500.0) * k
			bits.push_back([screen.x * (0.5 + side * 0.48), screen.y * 0.62, -side * cos(a) * sp, -sin(a) * sp, _R.randf() * TAU, _R.randf_range(-9.0, 9.0),
				Color(COLS[_R.randi() % COLS.size()]), _R.randf_range(6.0, 11.0) * k, _R.randf_range(3.0, 6.0) * k, _R.randf() * TAU])
	for i in 70:   # and a rain from above
		bits.push_back([_R.randf() * screen.x, -_R.randf() * screen.y * 0.7, _R.randf_range(-40.0, 40.0) * k, _R.randf_range(60.0, 160.0) * k, _R.randf() * TAU, _R.randf_range(-6.0, 6.0),
			Color(COLS[_R.randi() % COLS.size()]), _R.randf_range(6.0, 10.0) * k, _R.randf_range(3.0, 5.0) * k, _R.randf() * TAU])
	var R := card_rect(screen)
	for i in 7:   # fireworks round the card's edges, one after another (left and right by turns)
		var dirs: Array = []
		for j in 36: dirs.push_back([j * TAU / 36.0 + _R.randf_range(-0.06, 0.06), _R.randf_range(0.7, 1.0)])
		var lx := R.position.x + R.size.x * _R.randf_range(0.0, 0.22) if i % 2 == 0 else R.end.x - R.size.x * _R.randf_range(0.0, 0.22)
		booms.push_back([lx, R.position.y + R.size.y * (_R.randf_range(0.0, 0.25) if i % 3 != 2 else _R.randf_range(0.85, 1.05)), 0.12 + i * 0.4 + _R.randf_range(0.0, 0.12), Color(COLS[_R.randi() % 4]), dirs])
	for i in 14: stars.push_back([_R.randf(), _R.randf(), _R.randf() * TAU])

func stop() -> void:
	id = ""; kind = "gun"; bits.clear(); booms.clear()
	if vp != null: vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

func update(dt: float) -> void:
	if not on(): return
	t += dt
	if t >= LONG: stop(); return
	var k := _size.y / 720.0
	for b: Array in bits:   # thrown, slowed by the air, falling and fluttering
		b[3] += 520.0 * k * dt; var drag := exp(-dt * 2.4); b[2] *= drag; b[3] = minf(b[3] * drag, 150.0 * k) if b[3] > 0.0 else b[3] * drag
		b[0] += (b[2] + sin(t * 5.0 + b[9]) * 38.0 * k) * dt; b[1] += b[3] * dt; b[4] += b[5] * dt
	if turn != null:   # the gun shown side on, swinging a little to show it off
		turn.rotation = Vector3(0.12 * sin(t * 0.9), PI / 2 + 0.38 * sin(t * 1.25), 0.06 * sin(t * 1.7))

## how far in it is: 0 to 1 over its first half second (a little past 1 on the way: a pop), back to 0 over its last 0.6 s
func _in() -> float:
	var u := clampf(t / 0.45, 0.0, 1.0); var pop := 1.0 + 2.2 * pow(u - 1.0, 3) + 1.2 * pow(u - 1.0, 2)   # (an ease out with a little overshoot)
	return pop * clampf((LONG - t) / 0.6, 0.0, 1.0)
func _alpha() -> float: return clampf(t / 0.25, 0.0, 1.0) * clampf((LONG - t) / 0.6, 0.0, 1.0)

## the card's rectangle on a screen this big
static func card_rect(s: Vector2, n_rows := 0) -> Rect2:
	var h := maxf(s.y * 0.42, 170.0); var w := clampf(minf(s.x * 0.8, 860.0 * s.y / 720.0), 300.0, s.x - 16.0)   # (as big on any screen, for its height)
	if n_rows > 0: h = clampf(s.y * (0.2 + 0.06 * n_rows), 170.0, s.y * 0.8)   # (the spoils: as tall as their rows need)
	return Rect2(s.x / 2.0 - w / 2.0, s.y * 0.055, w, h)

func draw(ci) -> void:
	if not on(): return
	var s: Vector2 = ci.size; _size = s; var a := _alpha(); var e := _in(); var R := card_rect(s, rows.size() if kind == "spoils" else 0); var c := R.get_center()
	# the rays wheeling behind the card, and a white flash as it opens
	if t < 0.3: ci.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.97, 0.85, 0.35 * (1.0 - t / 0.3)))
	var rr := maxf(s.x, s.y) * 0.75 * e
	for i in 18:
		var a0 := t * 0.35 + i * TAU / 18.0
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rr, c + Vector2(cos(a0 + 0.12), sin(a0 + 0.12)) * rr]), Color(GOLD.r, GOLD.g, GOLD.b, (0.16 if i % 2 == 0 else 0.09) * a))
	# the card, popping in from the middle
	var Rc := Rect2(c - R.size * e / 2.0, R.size * e)
	if e > 0.05:
		ci.draw_rect(Rc.grow(10.0), Color(0, 0, 0, 0.35 * a)); ci.draw_rect(Rc, Color(NIGHT.r, NIGHT.g, NIGHT.b, NIGHT.a * a))
		ci.draw_rect(Rc, Color(GOLD.r, GOLD.g, GOLD.b, a), false, 3.0); ci.draw_rect(Rc.grow(-7.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.45 * a), false, 1.0)
	if e > 0.6:
		var h := Rc.size.y; var y := Rc.position.y
		# the ribbon over the top edge
		var rib_h := minf(h * 0.16, 72.0 * s.y / 720.0); var rib := Rect2(c.x - Rc.size.x * 0.3, y - rib_h * 0.45, Rc.size.x * 0.6, rib_h)
		ci.draw_rect(rib, Color(GOLD.r, GOLD.g, GOLD.b, a)); ci.draw_rect(rib, Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, a), false, 2.0)
		for sd: float in [-1.0, 1.0]:   # its ends folded back
			var ex := rib.position.x if sd < 0.0 else rib.end.x; var tip := ex + sd * rib_h * 0.6
			ci.draw_colored_polygon(PackedVector2Array([Vector2(ex, rib.position.y + rib_h * 0.2), Vector2(tip, rib.position.y + rib_h * 0.2), Vector2(tip - sd * rib_h * 0.25, rib.position.y + rib_h * 0.6), Vector2(tip, rib.end.y + rib_h * 0.2), Vector2(ex, rib.end.y + rib_h * 0.2)]), Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, a))
		if kind == "spoils": _spoils(ci, Rc, rib, a)
		else: _gun_card(ci, Rc, rib, a)
		for S: Array in stars:   # glints along the card's edge
			var gx: float = Rc.position.x + float(S[0]) * Rc.size.x; var gy: float = Rc.position.y + (0.0 if float(S[1]) < 0.5 else Rc.size.y); var tw := maxf(0.0, sin(t * 6.0 + float(S[2])))
			_star(ci, Vector2(gx, gy), (5.0 + 7.0 * tw) * minf(h, 300.0) / 300.0, Color(1, 0.95, 0.75, tw * a))
	# the fireworks, over the card's edges
	var kk := s.y / 720.0
	for B: Array in booms:
		var u: float = (t - float(B[2])) / 1.2
		if u < 0.0 or u > 1.0: continue
		var col: Color = B[3]; var o := Vector2(B[0], B[1]); var reach := (1.0 - pow(1.0 - u, 3)) * 170.0 * kk
		if u < 0.18: ci.draw_circle(o, (18.0 * (1.0 - u / 0.18) + 4.0) * kk, Color(1, 1, 0.9, 0.6 * (1.0 - u / 0.18) * a))
		for d: Array in B[4]:
			var dir := Vector2(cos(float(d[0])), sin(float(d[0]))); var r1: float = reach * float(d[1]); var sag := Vector2(0, u * u * 40.0 * kk)
			ci.draw_line(o + dir * maxf(0.0, r1 - 22.0 * kk) + sag, o + dir * r1 + sag, Color(col.r, col.g, col.b, (1.0 - u * u) * a), 3.5 * kk + 1.0)
			ci.draw_circle(o + dir * r1 + sag, 2.6 * kk + 0.8, Color(1, 1, 1, (1.0 - u) * a))
	# the confetti over everything
	for b: Array in bits:
		var p := Vector2(b[0], b[1])
		if p.y < -20.0 or p.y > s.y + 20.0: continue
		var col: Color = b[6]; var flip := absf(cos(t * 7.0 + float(b[9])))   # (turning over as it falls: thinner, then wide again)
		var hw: float = float(b[7]) * 0.5; var hh: float = float(b[8]) * 0.5 * (0.25 + 0.75 * flip); var ang: float = b[4]
		var xa := Vector2(cos(ang), sin(ang)); var ya := Vector2(-xa.y, xa.x)
		ci.draw_colored_polygon(PackedVector2Array([p - xa * hw - ya * hh, p + xa * hw - ya * hh, p + xa * hw + ya * hh, p - xa * hw + ya * hh]), Color(col.r, col.g, col.b, a))

## the gun's card: "새 총 획득!" on the ribbon, the gun's name big, its model and kind, the gun itself turning
func _gun_card(ci, Rc: Rect2, rib: Rect2, a: float) -> void:
	var W: Dictionary = Weapons.LIST[id]; var f_t: Font = m.f_title; var f_b: Font = m.f_bold; var h := Rc.size.y; var c := Rc.get_center(); var rib_h := rib.size.y
	_text(ci, f_t, "새 총 획득!", c.x, rib.position.y + rib_h * 0.12, int(rib_h * 0.66), Color(0.1, 0.07, 0.02, a), false)
	var big := int(maxf(h * 0.2, 26.0)); var name_y := rib.end.y + h * 0.04
	_text(ci, f_t, str(W.name), c.x, name_y, big, Color(1, 1, 1, a), true, Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, a))
	var sub_y := name_y + big * 1.08
	_text(ci, f_b, "%s · %s" % [str(W.model), str(W.cls)], c.x, sub_y, int(maxf(h * 0.07, 13.0)), Color(GOLD.r, GOLD.g, GOLD.b, a), true)
	var pic_top := sub_y + h * 0.1; var pic_h := Rc.end.y - h * 0.14 - pic_top
	if vp != null and pic_h > 20.0:
		var pw := minf(Rc.size.x * 0.94, pic_h * 3.0); var pr := Rect2(c.x - pw / 2.0, pic_top, pw, pw / 3.0)
		if pr.size.y > pic_h: pr = Rect2(c.x - pic_h * 1.5, pic_top, pic_h * 3.0, pic_h)
		ci.draw_texture_rect(_glow_tex(), Rect2(pr.get_center() - Vector2(pr.size.x * 0.42, pr.size.y * 0.62), Vector2(pr.size.x * 0.84, pr.size.y * 1.24)), false, Color(1, 1, 1, 0.75 * a))
		ci.draw_texture_rect(vp.get_texture(), pr, false, Color(1, 1, 1, a))
	_text(ci, m.f_mono, "영구히 내 총 · 살아서 나가면 · 모든 총 탄약 가득", c.x, Rc.end.y - h * 0.11, int(maxf(h * 0.05, 11.0)), Color(INK.r, INK.g, INK.b, 0.85 * a), false)

## 6-A's spoils: a row for each, its mark and its line, one after another; a relic, a choice box, a look or a title in gold
func _spoils(ci, Rc: Rect2, rib: Rect2, a: float) -> void:
	var f_t: Font = m.f_title; var f_b: Font = m.f_bold; var c := Rc.get_center(); var rib_h := rib.size.y; var h := Rc.size.y; var k := _size.y / 720.0
	_text(ci, f_t, head, c.x, rib.position.y + rib_h * 0.12, int(rib_h * 0.62), Color(0.1, 0.07, 0.02, a), false)
	var top := rib.end.y + 10.0 * k; var bottom := Rc.end.y - 30.0 * k; var n := maxi(1, rows.size())
	var rh := clampf((bottom - top) / n, 14.0, 46.0 * k); var fs := int(clampf(rh * 0.52, 11.0, 22.0 * k))
	var x0 := Rc.position.x + maxf(Rc.size.x * 0.1, rh * 1.4)
	for i in rows.size():
		var r: Dictionary = rows[i]; var y := top + rh * i; var big: bool = str(r.kind) in ["relic", "box", "look", "title"]
		var u := clampf((t - 0.35 - i * 0.12) / 0.3, 0.0, 1.0)   # (one row after another, each sliding in)
		if u <= 0.0: continue
		var aa := a * u; var dx := (1.0 - u) * 30.0 * k
		var col := Color(GOLD.r, GOLD.g, GOLD.b, aa) if big else Color(INK.r, INK.g, INK.b, aa)
		if big: ci.draw_rect(Rect2(Rc.position.x + 10, y + 1, Rc.size.x - 20, rh - 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.12 * aa))
		_icon(ci, r, Vector2(x0 - rh * 0.6 + dx, y + rh * 0.5), rh * 0.3, aa)
		var tx := RaidLoot.line(r); var ffont: Font = f_t if big else f_b; var fz := fs + (2 if big else 0)
		var w := ffont.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fz).x; var room := Rc.end.x - 14.0 - (x0 + dx)
		if w > room: fz = maxi(9, int(fz * room / w))
		ci.draw_string(ffont, Vector2(x0 + dx, y + rh * 0.5 + ffont.get_ascent(fz) * 0.42), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fz, col)
	_text(ci, m.f_mono, sub_head, c.x, Rc.end.y - 24.0 * k, int(maxf(12.0 * k, 10.0)), Color(INK.r, INK.g, INK.b, 0.85 * a), false)

## a spoil's mark: a gem for each material, a coin, a rune for a relic, a box, a star for a title or a look
func _icon(ci, r: Dictionary, at: Vector2, rr: float, a: float) -> void:
	match str(r.kind):
		"mat":
			var col := Color(str(RaidLoot.MAT_COL.get(str(r.id), "ffffff")))
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -rr), at + Vector2(rr * 0.8, -rr * 0.2), at + Vector2(rr * 0.5, rr), at + Vector2(-rr * 0.5, rr), at + Vector2(-rr * 0.8, -rr * 0.2)]), Color(col.r, col.g, col.b, a))
			ci.draw_line(at + Vector2(0, -rr), at + Vector2(0, rr), Color(1, 1, 1, 0.35 * a), 1.5)
		"coins":
			ci.draw_circle(at, rr, Color(GOLD.r, GOLD.g, GOLD.b, a)); ci.draw_arc(at, rr * 0.7, 0, TAU, 20, Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, a), 2.0)
		"relic", "dup":
			var col := Color("b04aff") if str(r.kind) == "relic" else Color(0.6, 0.55, 0.6)
			ci.draw_circle(at, rr * 1.15, Color(col.r, col.g, col.b, 0.3 * a)); ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -rr), at + Vector2(rr * 0.7, 0), at + Vector2(0, rr), at + Vector2(-rr * 0.7, 0)]), Color(col.r, col.g, col.b, a))
			ci.draw_line(at + Vector2(-rr * 0.35, -rr * 0.2), at + Vector2(rr * 0.35, rr * 0.2), Color(1, 0.9, 1, a), 2.0)
		"box":
			ci.draw_rect(Rect2(at - Vector2(rr, rr * 0.7), Vector2(rr * 2, rr * 1.5)), Color(0.35, 0.12, 0.5, a)); ci.draw_rect(Rect2(at - Vector2(rr * 0.18, rr * 0.7), Vector2(rr * 0.36, rr * 1.5)), Color(GOLD.r, GOLD.g, GOLD.b, a))
		_: _star(ci, at, rr * 1.2, Color(GOLD.r, GOLD.g, GOLD.b, a))

var _glow: GradientTexture2D
func _glow_tex() -> GradientTexture2D:   # a soft gold light behind the gun
	if _glow == null:
		var gr := Gradient.new(); gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0]); gr.colors = PackedColorArray([Color(1.0, 0.82, 0.38, 0.55), Color(1.0, 0.7, 0.25, 0.18), Color(1.0, 0.7, 0.25, 0.0)])
		_glow = GradientTexture2D.new(); _glow.gradient = gr; _glow.fill = GradientTexture2D.FILL_RADIAL; _glow.fill_from = Vector2(0.5, 0.5); _glow.fill_to = Vector2(1.0, 0.5); _glow.width = 128; _glow.height = 128
	return _glow

func _text(ci, font: Font, text: String, x: float, y: float, fs: int, col: Color, shadow: bool, edge := Color(0, 0, 0, 0)) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x; var px := x - w / 2.0; var py := y + font.get_ascent(fs)
	if edge.a > 0.0: ci.draw_string_outline(font, Vector2(px, py), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 9), edge)
	if shadow: ci.draw_string(font, Vector2(px + 2, py + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * col.a))
	ci.draw_string(font, Vector2(px, py), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _star(ci, at: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.01: return
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.22, -r * 0.22), at + Vector2(r, 0), at + Vector2(r * 0.22, r * 0.22), at + Vector2(0, r), at + Vector2(-r * 0.22, r * 0.22), at + Vector2(-r, 0), at + Vector2(-r * 0.22, -r * 0.22)]), col)

## the gun in its little world: made the first time (all eight, as the hands' are), then only the one won shown, painted and
## fitted out as you have it, without the hands, middled and sized to fill the picture
func _show_gun() -> void:
	if vp == null:
		vp = SubViewport.new(); vp.own_world_3d = true; vp.transparent_bg = true; vp.size = Vector2i(768, 256); vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		var cam := Camera3D.new(); cam.fov = 24.0; cam.position = Vector3(0, 0.08, 2.2); vp.add_child(cam); cam.look_at(Vector3.ZERO); cam.current = true
		var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR; env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.53, 0.62); env.ambient_light_energy = 0.4; var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
		var key := DirectionalLight3D.new(); key.rotation = Vector3(-0.75, 0.55, 0.0); key.light_energy = 2.2; vp.add_child(key)
		var rim := DirectionalLight3D.new(); rim.rotation = Vector3(-0.2, PI - 0.6, 0.0); rim.light_color = Color("ffd27a"); rim.light_energy = 2.0; vp.add_child(rim)
		var under := DirectionalLight3D.new(); under.rotation = Vector3(0.9, 0.0, 0.0); under.light_color = Color("9fb6ff"); under.light_energy = 0.5; vp.add_child(under)
		turn = Node3D.new(); vp.add_child(turn); models = GunModels.new(); models.build(turn)
	for gid in models.models: (models.models[gid].g as Node3D).visible = gid == id
	if not models.models.has(id): return
	models.apply_look(id, Custom.setup(id)); models.show_hands(id, false)
	var g: Node3D = models.models[id].g; g.position = Vector3.ZERO; g.scale = Vector3.ONE
	var bb := _bounds(g, Transform3D.IDENTITY)
	var long := maxf(bb.size.z, 0.05); var k := 2.35 / long   # the gun's length across most of the picture
	g.scale = Vector3.ONE * k; g.position = -bb.get_center() * k
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update(0.0)

## what a gun's shown meshes take up, in its own space
static func _bounds(n: Node3D, xf: Transform3D) -> AABB:
	var out := AABB(); var any := false
	for ch in n.get_children():
		if not (ch is Node3D) or not (ch as Node3D).visible: continue
		var cx: Transform3D = xf * (ch as Node3D).transform
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null and not ch.has_meta("no_clear"):
			var b: AABB = cx * (ch as MeshInstance3D).mesh.get_aabb(); out = b if not any else out.merge(b); any = true
		var sub := _bounds(ch, cx)
		if sub.size != Vector3.ZERO: out = sub if not any else out.merge(sub); any = true
	return out
