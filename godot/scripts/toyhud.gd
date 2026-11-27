class_name ToyHud
extends RefCounted
## Stage 5's fight screen: the same things Hud shows, as things from a child's desk stuck to the corners of the screen
## (the pieces are ToyKit's). Bottom left, your health as the charge strip on an AA battery (ten cells, red and blinking
## from 20 % down, a LOW BATTERY sticker shaking on it), the vest as spare building blocks and the jetpack as a wind-up
## dial above it. Bottom right, the gun's rounds as darts, drops, caps, tacks, balls and bands in a blister tray: one
## leaves with each shot, a reload fills them back one by one; the nine toys in vending-machine capsules above it.
## Top middle, a twin-bell alarm clock for the time left (it shakes and rings through the last 30 seconds) between two
## flip boards for the sides' scores. Top left, the room in crayon on squared paper, the toys as pushpins. In the middle,
## a crosshair for each toy, star stickers for hits, and the kill lines on strips of masking tape at the top right.
## Hud draws these on stage 5 only; every other stage's screen is its own.
##
## Each piece is a control of its own under the HUD, drawn again only when what it shows has changed (its sway, a jolt, a
## shake are the control's own turn and place, which cost nothing to redraw): the battery, its sticker, the tray, the top
## group, the clock, the paper map (ten times a second), the kill lines, and one over them all for what flies. Where
## there is no HUD to hold them (the checks, which record what is drawn), the same pieces are drawn in one go.

const K := preload("res://scripts/toykit.gd")

var m            # main: the game, the player, the guns, the look mode (as Hud.m)
var hud: Hud
var t := 0.0
var boards := {}           # the flip boards: name -> {"n": the number shown, "old": the one before, "f": how far the card has turned (1: still)}
var stickers: Array = []   # hit stickers round the crosshair: {kind, ang, dist, age, life, rot, col, r}
var tray_gun := ""; var tray_mag := -1; var tray_kick := 0.0
var dial_full := 0.0       # the longest time the clock has had to show: its hand's full turn
var ringing := false; var _rang := false
var nodes := {}            # the pieces as controls (when Main's HUD is there to hold them)
var sigs := {}             # what each last showed
var _size := Vector2(1280, 720); var _touch := false; var _pop_at := Vector2(200, 52)
var _rng := RandomNumberGenerator.new()   # (its own: the stickers' scatter takes nothing from the game's numbers)
var drops: Array = []      # water on the glass (a toy's water gun has hit you): {p: where, as a part of the screen, r, age, life, v}
var wet_t := 0.0           # ...and how long your shoes squeak for it

const CELLS := 10
const LOW := 20.0          # per cent: from here down the cells are red and blink, and the sticker is on
const RING_AT := 30.0      # seconds left: from here the clock rings
const NONE := [0.0, 0.0, 0.0, 0.0]
const WET := 7.0           # seconds a soaking lasts
const DROPS := 26          # drops on the glass at once

func reset() -> void:
	boards.clear(); stickers.clear(); sigs.clear(); tray_gun = ""; tray_mag = -1; tray_kick = 0.0; dial_full = 0.0; ringing = false; _rang = false; drops.clear(); wet_t = 0.0
	if hud != null and hud.is_toy(): K.sheet(); plan_tex()   # (the toy room is starting: its pictures made now, not in the fight)

# ---------------- what there is to show ----------------
## how many of the battery's ten cells are lit for this much health (per cent): any health at all lights one
static func cells_lit(pct: float) -> int: return clampi(ceili(pct / (100.0 / CELLS)), 0, CELLS)

static func _is_clock(v: String) -> bool:
	var q := v.split(":")
	return q.size() == 2 and q[0].is_valid_int() and q[1].length() == 2 and q[1].is_valid_int()

## "2 / 3", "63%" or "12" as a board's number and what follows it
static func _board_of(label: String, v: String) -> Dictionary:
	var n := v; var tail := ""
	if v.contains(" / "): n = v.get_slice(" / ", 0); tail = "/" + v.get_slice(" / ", 1)
	elif v.ends_with("%"): n = v.trim_suffix("%"); tail = "%"
	return {"label": label, "n": int(n) if n.is_valid_int() else 0, "tail": tail}

## the cells of the box at the top (a mode's hud_cells, or the sweep's stage, kills and bag) sorted into the toy screen's
## pieces: the clock, our board and theirs, small tags, the bag. The sweep has no sides: its kills take our board
static func top_model(cells_in: Array) -> Dictionary:
	var out := {"time": null, "us": null, "them": null, "tags": [], "money": ""}
	for q: Array in cells_in:
		var label := str(q[0]); var v := str(q[1]); var col: Color = q[2]
		if label == "스테이지": continue
		if label == "가방": out.money = v
		elif out.time == null and (v == "연장전" or _is_clock(v)): out.time = {"label": label, "text": v, "red": col.is_equal_approx(K.THEM)}
		elif out.us == null and col.is_equal_approx(K.US): out.us = _board_of(label, v); out.us.col = K.US
		elif out.them == null and col.is_equal_approx(K.THEM): out.them = _board_of(label, v); out.them.col = K.THEM
		else: out.tags.push_back([label, v])
	if out.us == null and out.them == null and not out.tags.is_empty() and str(out.tags[0][1]).contains(" / "):
		var k: Array = out.tags.pop_front(); out.us = _board_of(str(k[0]), str(k[1])); out.us.col = K.YELLOW
	return out

## a kill line's parts for the log: [who, whom, a head shot?]; [] when the line tells of something else
static func kill_parts(text: String) -> Array:
	if text == "아군 병정이 쓰러졌습니다": return ["상대", "아군 병정", false]
	var by := "나"; var rest := text
	if rest.begins_with("아군이 "): by = "아군"; rest = rest.substr(4)
	if rest.ends_with(" · 머리 명중"): return [by, rest.trim_suffix(" · 머리 명중"), true]
	if rest.ends_with(" 처치"): return [by, rest.trim_suffix(" 처치"), false]
	return []

## the crosshair each toy has: the water gun a ring of drops, the laser a red dot, the bottle rocket a target...
const CROSS := {"pistol": "sucker", "shotgun": "drops", "rifle": "bars", "smg": "tee", "sniper": "laser", "gl": "sling", "lmg": "ring", "rocket": "target", "flame": "spray"}

## the seconds the clock has left to show (a team mode's), or -1 for the sweep, which has none; and whether it is overtime
func time_left() -> float: return float(m.game.tm.mode.time_left) if m.game.tm != null else -1.0
func overtime() -> bool: return m.game.tm != null and m.game.tm.mode.get("overtime") == true

## the cells at the top as the game has them now
func cells() -> Array:
	var g: Game = m.game
	if g.tm != null: return g.tm.mode.hud_cells()
	return [["스테이지", Store.STAGE_TAG[g.stage], K.YELLOW], ["처치", "%d / %d" % [g.kills + g.calm, g.goal], K.INK], ["가방", Store.won(Store.save.money), K.INK]]

## the touch map button on stage 5 is the little map itself: where it lies (top right, as the button; never so tall it
## reaches the round buttons)
static func touch_map(s: Vector2, ins: Array) -> Rect2:
	var d := clampf(roundf(s.y * 0.19), 46.0, 74.0)
	return Rect2(s.x - 14.0 - d - float(ins[2]), 10.0 + float(ins[1]), d, d)

## where the pieces lie on a screen of this size and how big they are drawn: the battery, the tray, the top group's
## anchor, the little map, where the kill lines start
static func layout(s: Vector2, touch: bool, ins: Array = NONE) -> Dictionary:
	if touch:
		var k := 0.8; var tk := 0.9 if s.y <= 340.0 else 1.0   # (a very short screen's round buttons sit closer in: the tray a little smaller in its corner)
		return {"k": k, "tray_k": tk, "battery": Rect2(16.0 + float(ins[0]), s.y - 12.0 - float(ins[3]) - 62.0 * k, 216.0 * k, 62.0 * k),
			"tray": Rect2(s.x - 14.0 - float(ins[2]) - 108.0 * tk, s.y - 10.0 - float(ins[3]) - 98.0 * tk, 108.0 * tk, 98.0 * tk),
			"top": Vector2(s.x / 2.0, 6.0 + float(ins[1])), "top_k": 0.8, "map": touch_map(s, ins), "feed": Vector2(70.0 + float(ins[0]), 14.0 + float(ins[1]))}
	var k2 := 1.0 if s.x >= 900.0 else 0.85
	return {"k": k2, "tray_k": k2, "battery": Rect2(18.0, s.y - 18.0 - 62.0 * k2, 216.0 * k2, 62.0 * k2), "tray": Rect2(s.x - 18.0 - 264.0 * k2, s.y - 18.0 - 112.0 * k2, 264.0 * k2, 112.0 * k2),
		"top": Vector2(s.x / 2.0, 8.0), "top_k": k2, "map": Rect2(18.0, 16.0, 150.0 * k2, 150.0 * k2), "feed": Vector2(s.x - 16.0, 14.0)}

func _layout() -> Dictionary: return layout(_size, _touch, m.safe_in if _touch else NONE)

# ---------------- what the game tells it ----------------
## a hit: a star sticker pops up by the crosshair (an orange one and a small one for the head; a ddakji and a burst of
## stars for a kill)
func hit(kill: bool, head: bool) -> void:
	var a0 := _rng.randf() * TAU
	if kill:
		stickers.push_back({"kind": "ddakji", "ang": a0, "dist": 30.0, "age": 0.0, "life": 0.42, "rot": _rng.randf_range(-0.5, 0.5), "col": K.RED, "r": 11.0})
		for i in 3: stickers.push_back({"kind": "star", "ang": a0 + 1.6 + i * 1.5, "dist": 26.0 + i * 3.0, "age": 0.0, "life": 0.4, "rot": _rng.randf() * TAU, "col": K.YELLOW if i != 1 else K.ORANGE, "r": 6.0 + i})
	elif head:
		stickers.push_back({"kind": "star", "ang": a0, "dist": 26.0, "age": 0.0, "life": 0.3, "rot": _rng.randf() * TAU, "col": K.ORANGE, "r": 9.0})
		stickers.push_back({"kind": "star", "ang": a0 + 2.4, "dist": 22.0, "age": 0.0, "life": 0.26, "rot": _rng.randf() * TAU, "col": K.YELLOW, "r": 5.5})
	else: stickers.push_back({"kind": "star", "ang": a0, "dist": 22.0, "age": 0.0, "life": 0.2, "rot": _rng.randf() * TAU, "col": K.YELLOW, "r": 6.5})
	if stickers.size() > 14: stickers = stickers.slice(stickers.size() - 14)

## a toy's water gun has hit you: drops gather at the edges of the glass and run down it, and your shoes squeak for a while
func splash() -> void:
	wet_t = WET
	for i in 4:
		var side := _rng.randi() % 4; var along := _rng.randf(); var deep := _rng.randf_range(0.02, 0.13)
		var p := Vector2(along, deep) if side == 0 else (Vector2(along, 1.0 - deep) if side == 1 else (Vector2(deep, along) if side == 2 else Vector2(1.0 - deep, along)))
		drops.push_back({"p": p, "r": _rng.randf_range(9.0, 21.0), "age": 0.0, "life": _rng.randf_range(2.6, 4.6), "v": _rng.randf_range(0.004, 0.02)})
	if drops.size() > DROPS: drops = drops.slice(drops.size() - DROPS)

func update(dt: float) -> void:
	t += dt; wet_t = maxf(0.0, wet_t - dt)
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]; d.age += dt; d.p.y += float(d.v) * dt * (1.0 + float(d.age))
		if d.age > d.life: drops.remove_at(i)
	if nodes.is_empty() and m.get("hud") is Control: attach(m.hud)
	if not nodes.is_empty(): _size = (m.hud as Control).size; _touch = m.look_mode == "touch"
	for k in boards:
		var b: Dictionary = boards[k]
		if b.f < 1.0: b.f = minf(1.0, float(b.f) + dt / 0.3)
	# a shot jolts the gun's card
	var guns: Guns = m.guns; var mag := int(guns.st().mag)
	if guns.cur == tray_gun and mag < tray_mag and guns.reload_t <= 0.0: tray_kick = 1.0
	tray_gun = guns.cur; tray_mag = mag; tray_kick = maxf(0.0, tray_kick - dt * 7.0)
	for i in range(stickers.size() - 1, -1, -1):
		stickers[i].age += dt
		if stickers[i].age > stickers[i].life: stickers.remove_at(i)
	# the clock: its dial's full turn is the longest it has had to show; it rings from 30 seconds down (and all overtime)
	var tl := time_left(); dial_full = maxf(dial_full, tl)
	ringing = m.game.tm != null and not m.game.ended and ((tl > 0.0 and tl <= RING_AT) or overtime())
	if ringing and not _rang: _rang = true; Snd.play("toy_alarm", 0.8)
	if not nodes.is_empty(): _sync()

# ---------------- the pieces as controls of their own ----------------
func _node(name: String, parent: Control, paint: Callable) -> void:
	var n := Control.new(); n.mouse_filter = Control.MOUSE_FILTER_IGNORE; n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; parent.add_child(n); nodes[name] = n
	n.draw.connect(func() -> void: K.at(n, Transform2D.IDENTITY); K.hold = true; paint.call(n); K.flush(n))

func attach(parent: Control) -> void:
	_node("glass", parent, func(n: Control) -> void: draw_glass(n))   # (under the pieces: they are stuck on the glass, the water runs down it)
	_node("map", parent, func(n: Control) -> void: draw_map(n, (_layout().map as Rect2).size.x, _touch))
	_node("top", parent, func(n: Control) -> void: draw_top(n))
	_node("clock", nodes.top, func(n: Control) -> void: draw_clock(n))
	_node("feed", parent, func(n: Control) -> void: draw_feed(n))
	_node("battery", parent, func(n: Control) -> void: draw_battery(n, hud._items(_touch)))
	_node("low", nodes.battery, func(n: Control) -> void: draw_low(n))
	_node("tray", parent, func(n: Control) -> void: draw_tray(n, _touch))
	_node("over", parent, func(n: Control) -> void: draw_over(n))

## shown only in the toy room
func show(on: bool) -> void:
	for k in ["glass", "map", "top", "feed", "battery", "tray", "over"]:
		if nodes.has(k) and (nodes[k] as Control).visible != on: (nodes[k] as Control).visible = on

## a piece is drawn again when what it shows is no longer what it showed
func _mark(name: String, sig) -> void:
	if not sigs.has(name) or sigs[name] != sig: sigs[name] = sig; (nodes[name] as Control).queue_redraw()

## each piece put in its place (its sway and shakes with it), and drawn again if what it shows has changed
func _sync() -> void:
	show(true)
	var L := _layout(); var g: Game = m.game; var pl: Player = m.player; var guns: Guns = m.guns
	# the battery: jolted by a hit; its sticker shaking while it is low
	var pct := clampf(pl.hp / Player.MAX_HP, 0.0, 1.0) * 100.0; var low := pct <= LOW; var bn: Control = nodes.battery; var BR: Rect2 = L.battery
	bn.position = Vector2(BR.position.x, BR.end.y); bn.scale = Vector2.ONE * float(L.k); bn.rotation = _sway(0.0) + sin(t * 55.0) * 0.02 * clampf(hud.hurt_t / 0.3, 0.0, 1.0)
	var ln: Control = nodes.low; ln.visible = low; ln.position = Vector2(108, -60); ln.rotation = -0.05 + sin(t * 11.0) * 0.07
	_mark("battery", [cells_lit(pct), cells_lit(hud.ghost * 100.0), low, ceili(pl.hp), int(t / 0.25) if low else 0, str(hud._items(_touch)), int(Store.save.items.vest), pl.jet_on, int(pl.jet_t * 10.0) if pl.jet_on else 0, _touch])
	_mark("low", 1)
	# the tray: kicked by a shot
	var tn: Control = nodes.tray; var TR: Rect2 = L.tray; tn.position = TR.position + Vector2(0, tray_kick * 2.5); tn.scale = Vector2.ONE * float(L.tray_k); tn.rotation = _sway(2.0)
	var st: Dictionary = guns.st()
	_mark("tray", [guns.cur, int(st.mag), str(st.reserve), str(guns.pending), str(guns.loadout), int(clampf(guns.melee_cd / 0.62, 0.0, 1.0) * 6.0),
		int(g.tm.mode.cans) if (g.tm != null and g.tm.key == "freeze") else -1, _touch])
	# the top group, and the clock in it (shaking as it rings)
	var pn: Control = nodes.top; pn.position = L.top; pn.scale = Vector2.ONE * float(L.top_k)
	var M := top_model(cells()); _boards_tick(M); var turning := []
	for k in boards:
		if float(boards[k].f) < 1.0: turning.push_back(int(float(boards[k].f) * 30.0))
	var lines: Array = g.tm.mode.hud_lines() if (g.tm != null and not g.ended) else []
	_mark("top", [str(M), str(lines), turning, int(t / 0.35) if lines.any(func(q): return q[3]) else 0, ringing, int(g.stats.time) if g.tm == null else 0])
	var cn: Control = nodes.clock; cn.position = Vector2(sin(t * 61.0) * 1.6 if ringing else 0.0, 46.0); cn.rotation = sin(t * 47.0) * 0.1 if ringing else 0.0
	_mark("clock", [int(_frac() * 360.0), ringing, int(t * 30.0) if ringing else 0, int(g.stats.time) if g.tm == null else 0, M.time != null and bool(M.time.red)])
	# the paper map (its pins move: ten times a second is plenty), the kill lines, and what flies over everything
	var mn: Control = nodes.map; var MR: Rect2 = L.map; mn.position = MR.get_center(); mn.rotation = 0.0 if _touch else -0.035 + _sway(4.0)
	_mark("map", [int(t * 10.0), _touch, MR.size.x])
	var fsig := []
	for q: Array in hud.feed:
		var age := float(q[2]); fsig.push_back([q[0], q[1], q[3], int(age * 60.0) if age < 0.16 else (int(age * 30.0) if age > 2.4 else 0)])
	_mark("feed", [fsig, _touch, _size])
	_mark("over", int(t * 120.0) if not hud.pops.is_empty() else 0)
	_mark("glass", int(t * 120.0) if not drops.is_empty() else 0)

# ---------------- drawing ----------------
## the sway of a piece stuck on the glass: a fraction of a degree, each piece in its own time
func _sway(phase: float) -> float: return sin(t * 1.15 + phase) * 0.005
func _at(ci, pos: Vector2, rot := 0.0, k := 1.0) -> void: K.at(ci, Transform2D(rot, Vector2(k, k), 0.0, pos))

## words anywhere over the view: ink with a white edge, as cut from a sheet of stickers
func words(ci, s: String, x: float, y: float, fs: int, col := K.INK, align := "center", a := 1.0) -> void:
	K.text(ci, s, x, y, fs, Color(col, a), align, maxi(3, fs / 5), Color(1, 1, 1, 0.92 * a))

# ---- health, bottom left ----
## the battery and what you carry above it, from its bottom left corner
func draw_battery(ci, items: Array) -> void:
	var pl: Player = m.player; var pct := clampf(pl.hp / Player.MAX_HP, 0.0, 1.0) * 100.0; var low := pct <= LOW; var lit := cells_lit(pct); var ghost := cells_lit(hud.ghost * 100.0); var y0 := -46.0
	K.rbox(ci, Rect2(204, y0 + 14, 11, 18), K.STEEL, 4.0, Color("8d99ae"), 1.0, true)
	K.rbox(ci, Rect2(0, y0, 206, 46), Color("2f3140"), 12.0, Color("1b1c26"), 1.0, true)
	K.rbox(ci, Rect2(150, y0, 56, 46), Color("e2a03f"), 12.0); K.solid(ci, Rect2(144, y0, 18, 46), Color("e2a03f")); K.solid(ci, Rect2(144, y0 + 1, 2, 44), Color("b9791f"))   # the gold band at its head
	K.solid(ci, Rect2(10, y0 + 4, 186, 3), Color(1, 1, 1, 0.14)); K.text(ci, "AA", 10, y0 + 15, 13, Color(1, 1, 1, 0.9))
	# the charge strip: ten cells in a dark window
	K.rbox(ci, Rect2(34, y0 + 9, 104, 28), Color("14151c"), 6.0)
	var blink := fmod(t, 0.5) < 0.28
	for i in CELLS:
		var cr := Rect2(38.0 + i * 9.7, y0 + 13, 7.8, 20); var col := Color(1, 1, 1, 0.08)
		if i < lit: col = (K.RED if blink else Color(K.RED, 0.3)) if low else Color("5fe07a")
		elif i < ghost: col = Color(1, 0.45, 0.5, 0.75)   # what a hit has just taken, a moment longer
		K.solid(ci, cr, col)
		if i < lit and not low: K.solid(ci, Rect2(cr.position.x, cr.position.y, cr.size.x, 5), Color(1, 1, 1, 0.28))
	K.text(ci, str(ceili(pl.hp)), 176, y0 + 11, 21, K.RED.darkened(0.25) if low else K.INK, "center")
	# "체력" on a strip of tape across its end
	K.sub(ci, Vector2(24, y0 - 3), -0.08); K.tape(ci, Rect2(-23, -8, 46, 16), K.tape_col(0)); K.text(ci, "체력", 0, -8, 11, K.INK, "center"); K.unsub(ci)
	# what you carry, above it (beside the warning sticker when that is on): the vest as spare building blocks, the jetpack
	# as a wind-up dial, the rest as stickers
	var x := 54.0 if not low else 168.0; var iy := y0 - 26.0
	for it: Array in items:
		var txt := str(it[0])
		if txt.begins_with("조끼"):
			var left := int(Store.save.items.vest)
			K.text(ci, "조끼", x, iy + 5, 11, K.INK, "left", 3); var bx := x + K.width("조끼", 11) + 5.0
			for i in 10:
				var br := Rect2(bx + (i % 5) * 11.0, iy + 4.0 + (i / 5) * 11.0, 9, 6)
				if i < left: K.brick(ci, br, Color(str(K.BRICKS[i % 5])))
				else: K.solid(ci, br, Color(0, 0, 0, 0.22))
			x = bx + 55.0 + 8.0
		elif txt.begins_with("제트팩"): x = _dial(ci, Vector2(x + 12.0, iy + 12.0), 1.0, txt.get_slice(" · ", 1)) + 8.0
		else:
			var w := K.width(txt, 11) + 14.0
			K.sticker(ci, Rect2(x, iy + 2, w, 20), K.YELLOW if it[1] == "jet" else Color.WHITE, 6.0); K.text(ci, txt, x + 7, iy + 5, 11, K.INK); x += w + 6.0
	if pl.jet_on: _dial(ci, Vector2(x + 12.0, iy + 12.0), clampf(pl.jet_t / 10.0, 0.0, 1.0), "%.1f초" % maxf(0.0, pl.jet_t))

## the warning sticker, about its middle
func draw_low(ci) -> void:
	K.sticker(ci, Rect2(-52, -15, 104, 30), K.YELLOW, 6.0); K.text(ci, "LOW BATTERY", 0, -14, 11, K.INK, "center"); K.text(ci, "방전 경고", 0, -3, 13, K.RED, "center")

## the jetpack: a wind-up key's dial, its hand at how much spring is left (full before it is used); returns where it ends
func _dial(ci, c: Vector2, f: float, note: String) -> float:
	K.disc(ci, c + Vector2(0.8, 1.8), 12.5, K.SHADE); K.disc(ci, c, 12.5, K.INK); K.disc(ci, c, 10.5, K.PAPER)
	var a0 := PI * 0.75; var n := maxi(1, int(10.0 * f))
	for i in n: K.line(ci, c + Vector2(cos(a0 + PI * 1.5 * f * i / n), sin(a0 + PI * 1.5 * f * i / n)) * 8.0, c + Vector2(cos(a0 + PI * 1.5 * f * (i + 1) / n), sin(a0 + PI * 1.5 * f * (i + 1) / n)) * 8.0, K.ORANGE, 3.0)
	var a := a0 + PI * 1.5 * f; K.line(ci, c, c + Vector2(cos(a), sin(a)) * 8.5, K.RED, 2.0); K.disc(ci, c, 2.0, K.INK)
	# the key: a stem and two wings
	var kx := c.x + 14.0; K.solid(ci, Rect2(kx - 2.0, c.y - 1.5, 6, 3), K.STEEL); K.disc(ci, Vector2(kx + 7.0, c.y - 4.5), 4.0, K.YELLOW); K.disc(ci, Vector2(kx + 7.0, c.y + 4.5), 4.0, K.YELLOW)
	var w := K.text(ci, note, kx + 14.0, c.y - 7.0, 11, K.INK, "left", 3)
	return kx + 14.0 + w

func battery(ci, s: Vector2, touch: bool, items: Array) -> void:
	_size = s; _touch = touch; var L := _layout(); var R: Rect2 = L.battery; var pl: Player = m.player
	_at(ci, Vector2(R.position.x, R.end.y), _sway(0.0) + sin(t * 55.0) * 0.02 * clampf(hud.hurt_t / 0.3, 0.0, 1.0), float(L.k)); K.hold = true; draw_battery(ci, items); K.flush(ci)
	if pl.hp / Player.MAX_HP * 100.0 <= LOW: K.at(ci, K._xf * Transform2D(-0.05 + sin(t * 11.0) * 0.07, Vector2(108, -60))); K.hold = true; draw_low(ci); K.flush(ci)
	K.at(ci, Transform2D.IDENTITY)

# ---- the gun, bottom right ----
## the gun's card, from the top left corner of its place: the toy's name on a strip of tape, how many rounds are in it on
## a yellow sticker and how many more you carry on a price tag (no pictures of the rounds: the numbers say it). A phone's
## is smaller, a long name on two lines, and has no capsules
const NAME_FS := 24; const NAME_FS_TOUCH := 18   # (1.6 times what the name was: 15, a phone's 11)
func draw_tray(ci, touch: bool) -> void:
	var guns: Guns = m.guns; var W: Dictionary = guns.w(); var st: Dictionary = guns.st()
	var id: String = guns.cur; var mag := int(st.mag); var cap := float(W.mag); var res := "/ " + ("∞" if float(st.reserve) == INF else str(int(st.reserve)))
	var name: String = Toys.NAMES.get(id, str(W.name)); var lowmag := mag <= ceili(cap * 0.25); var num := K.RED.darkened(0.2) if lowmag else K.INK
	if touch:
		K.card(ci, Rect2(0, 12, 108, 86), K.KRAFT, 6.0)
		var lines: Array = K.two_lines(name, NAME_FS_TOUCH, 102.0); var th := 5.0 + 20.0 * lines.size()
		K.sub(ci, Vector2(54, 3.0 + th / 2.0), -0.03); K.tape(ci, Rect2(-54, -th / 2.0, 108, th), K.tape_col(2))
		for i in lines.size(): K.text(ci, str(lines[i]), 0, -th / 2.0 + 1.0 + i * 20.0, NAME_FS_TOUCH, K.INK, "center")
		K.unsub(ci)
		var top := 6.0 + th + 4.0; var room := 94.0 - top; var fs := 30 if lines.size() == 1 else 24   # (what is left of the card under the tape)
		var mw := K.width(str(mag), fs); var rw := K.width(res, 14); var sw := minf(100.0, mw + rw + 22.0); var sy := top + (room - (fs + 6.0)) / 2.0
		K.sticker(ci, Rect2(54.0 - sw / 2.0, sy, sw, fs + 6.0), K.YELLOW, 6.0)
		K.text(ci, str(mag), 54.0 - sw / 2.0 + 9.0, sy - 1.0, fs, num, "left"); K.text(ci, res, 54.0 + sw / 2.0 - 8.0, sy + fs - 13.0, 14, K.INK, "right")
	else:
		K.card(ci, Rect2(0, 12, 264, 100), K.KRAFT, 8.0)
		K.solid(ci, Rect2(14, 20, 24, 5), Color(0, 0, 0, 0.3))   # the slot it hung from in the shop
		K.sub(ci, Vector2(132, 35), -0.02); var tw := maxf(150.0, K.width(name, NAME_FS) + 30.0); K.tape(ci, Rect2(-tw / 2.0, -16, tw, 32), K.tape_col(2)); K.text(ci, name, 0, -16, NAME_FS, K.INK, "center"); K.unsub(ci)
		K.sticker(ci, Rect2(34, 58, 104, 48), K.YELLOW, 12.0); K.text(ci, str(mag), 86, 57, 41, num, "center")
		K.price_tag(ci, Rect2(148, 68, 88, 28)); K.text(ci, res, 229, 69, 20, Color.WHITE, "right")
		_capsules(ci, guns)

func tray(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; var L := _layout(); var R: Rect2 = L.tray
	_at(ci, R.position + Vector2(0, tray_kick * 2.5), _sway(2.0), float(L.tray_k)); K.hold = true; draw_tray(ci, touch); K.flush(ci); K.at(ci, Transform2D.IDENTITY)

## a vending-machine capsule: a coloured cup under a clear lid (lifted by `open`, 0..1), what is in it drawn between the two
func capsule(ci, c: Vector2, r: float, col: Color, open: float, inside: Callable) -> void:
	K.disc(ci, c + Vector2(0.8, 2.0), r, Color(0, 0, 0, 0.22)); K.half(ci, c, r, col, false)
	inside.call()
	var lc := c + Vector2(0, -open * r * 0.7)
	K.half(ci, lc, r, Color(1, 1, 1, 0.3), true); ci.draw_texture_rect_region(K.sheet(), Rect2(lc.x - r, lc.y - r, r * 2.0, r), Rect2((K.SPR.ring as Rect2).position, Vector2(64, 32)), Color(1, 1, 1, 0.8))
	K.solid(ci, Rect2(lc.x - r * 0.55, lc.y - r * 0.62, r * 0.3, maxf(1.2, r * 0.1)), Color(1, 1, 1, 0.6)); K.solid(ci, Rect2(c.x - r, c.y - 0.75, r * 2.0, 1.5), col.darkened(0.3))

## the toys you carry, each in its capsule above the tray (keys 1-9), the one in your hand opened and bigger; to the
## left of the tray the 30 cm ruler's capsule (its lid comes back down as the swing recovers) and, at bedtime, the soda cans'
func _capsules(ci, guns: Guns) -> void:
	var lay: Array = guns.loadout; var cur = guns.pending if guns.pending != null else guns.cur; var x := 252.0
	for i in range(lay.size() - 1, -1, -1):
		var id = lay[i]
		if id == null: continue
		var on: bool = id == cur; var r := 15.0 if on else 11.0; x -= r; var c := Vector2(x, -5.0 - (5.0 if on else 0.0))
		var icon: String = K.ROUND.get(str(id), "dart")   # (what it shoots: easier to tell apart this small than the toy itself)
		capsule(ci, c, r, Color(str(K.BRICKS[i % 5])), 0.5 if on else 0.0, func() -> void: K.ammo(ci, icon, c + Vector2(0, -r * 0.3), r * (0.42 if icon == "rocket" else 0.95), 1.0, i))
		K.text(ci, str(i + 1), c.x, c.y + (1.0 if on else 0.0), 11, Color.WHITE, "center")
		if on: K.ring(ci, c, r + 3.5, K.YELLOW)
		x -= r + 5.0
	var cd := clampf(guns.melee_cd / 0.62, 0.0, 1.0); var rc := Vector2(-22.0, 84.0)
	capsule(ci, rc, 17.0, K.BLUE, cd, func() -> void:
		K.solid(ci, Rect2(rc.x - 13.0, rc.y - 9.0, 26, 6), Color("ffe066"))   # the ruler, its centimetres marked
		for i in 6: K.solid(ci, Rect2(rc.x - 11.0 + i * 4.4, rc.y - 9.0, 1, 3 if i % 2 == 0 else 2), K.INK))
	K.text(ci, "V", rc.x, rc.y + 16.0, 11, K.INK, "center", 3)
	if m.game.tm != null and m.game.tm.key == "freeze":
		var cc := Vector2(-62.0, 84.0); var cans := int(m.game.tm.mode.cans)
		capsule(ci, cc, 17.0, K.RED, 0.0, func() -> void:
			if cans > 0: K.solid(ci, Rect2(cc.x - 5.0, cc.y - 9.0, 10, 17), Color("d7263d")); K.solid(ci, Rect2(cc.x - 5.0, cc.y - 9.0, 10, 3), K.STEEL); K.solid(ci, Rect2(cc.x - 5.0, cc.y - 2.0, 10, 3), Color.WHITE))
		K.text(ci, "G ×%d" % cans, cc.x, cc.y + 16.0, 11, K.INK, "center", 3)

# ---- the clock and the boards, top middle ----
## a board's number has changed: its cards start to turn
func _boards_tick(M: Dictionary) -> void:
	for key: String in ["us", "them"]:
		if M[key] == null: continue
		var n := int(M[key].n); var st: Dictionary = boards.get(key, {})
		if st.is_empty(): boards[key] = {"n": n, "old": n, "f": 1.0}
		elif int(st.n) != n: st.old = st.n; st.n = n; st.f = 0.0

func _board(ci, key: String, x: float, y: float, B: Dictionary, right: bool) -> float:
	var n := int(B.n); var digits := 3 if n >= 100 else 2; var st: Dictionary = boards.get(key, {"n": n, "old": n, "f": 1.0})
	var w := digits * 23.0 + 9.0; var x0 := x - w if right else x; var col: Color = B.col; var ink := K.INK if col.is_equal_approx(K.YELLOW) else Color.WHITE
	K.rbox(ci, Rect2(x0, y, w, 44), K.INK, 6.0, Color("15161f"), 1.0, true)
	for i in 2: K.disc(ci, Vector2(x0 + w * (0.3 + 0.4 * i), y - 1.0), 3.0, K.STEEL); K.disc(ci, Vector2(x0 + w * (0.3 + 0.4 * i), y - 1.0), 1.3, Color("5b6170"))   # the rings the cards hang on
	var f := float(st.f); var turn := absf(cos(f * PI)) if f < 1.0 else 1.0; var show_n := int(st.old) if f < 0.5 else n; var txt := str(show_n).pad_zeros(digits)
	for i in digits:
		var cx := x0 + 5.0 + i * 23.0; var cy := y + 22.0
		K.sub(ci, Vector2(cx + 10.0, cy), 0.0, Vector2(1.0, maxf(0.06, turn)))
		K.rbox(ci, Rect2(-10, -17, 20, 34), col, 4.0); K.text(ci, txt[i], 0, -17, 27, ink, "center"); K.unsub(ci)
		K.solid(ci, Rect2(cx, cy - 0.75, 20, 1.5), Color(0, 0, 0, 0.35))   # the hinge across the middle
	var label := str(B.label) + ((" " + str(B.tail)) if str(B.tail) != "" else "")
	var lw := K.width(label, 11) + 14.0; var lx := x0 + w / 2.0
	K.sub(ci, Vector2(lx, y + 55.0), 0.03 if right else -0.03); K.tape(ci, Rect2(-lw / 2.0, -8, lw, 16), K.tape_col(3 if col.is_equal_approx(K.US) else (1 if col.is_equal_approx(K.THEM) else 2))); K.text(ci, label, 0, -8, 11, K.INK, "center"); K.unsub(ci)
	return w

## how much of the clock's dial is still to run
func _frac() -> float: return clampf(time_left() / maxf(1.0, dial_full), 0.0, 1.0) if (m.game.tm != null and not overtime()) else 0.0

## the twin-bell clock about its middle: the time left as a slice of its dial and by its hand, or (the sweep, which has
## none to count down) the minutes and seconds gone as two hands; its hammer and bells ringing through the last 30 seconds
func draw_clock(ci) -> void:
	var g: Game = m.game; var R := 26.0; var frac := _frac(); var gone := float(g.stats.time) if g.tm == null else -1.0
	var M := top_model(cells()); var urgent: bool = ringing or (M.time != null and bool(M.time.red))
	for sx: float in [-1.0, 1.0]:
		K.line(ci, Vector2(sx * R * 0.5, R * 0.8), Vector2(sx * R * 0.82, R * 1.16), K.INK, 4.0)   # its feet
		var bc := Vector2(sx * R * 0.62, -R * 0.9) + (Vector2(sin(t * 80.0 + sx) * 1.2, 0) if ringing else Vector2.ZERO)
		K.disc(ci, bc, R * 0.4, Color("c9a227")); K.disc(ci, bc + Vector2(0, -1.0), R * 0.33, K.YELLOW); K.disc(ci, bc + Vector2(-R * 0.1, -R * 0.14), R * 0.09, Color(1, 1, 1, 0.8))   # the bells
	var hx := sin(t * 70.0) * R * 0.34 if ringing else 0.0
	K.line(ci, Vector2(0, -R * 0.95), Vector2(hx, -R * 1.34), K.INK, 2.5); K.disc(ci, Vector2(hx, -R * 1.36), R * 0.11, K.INK)   # the hammer between them
	K.disc(ci, Vector2(1.0, 2.5), R, K.SHADE); K.disc(ci, Vector2.ZERO, R, K.RED.darkened(0.25)); K.disc(ci, Vector2.ZERO, R * 0.93, K.RED); K.disc(ci, Vector2.ZERO, R * 0.78, K.PAPER)
	var hand_col := K.RED if urgent else K.INK
	if gone < 0.0:
		if frac > 0.003:   # the time left, as a slice of the dial (the one shape here drawn as itself)
			var n := maxi(3, int(30.0 * frac)); var pts := PackedVector2Array([Vector2.ZERO])
			for i in n + 1: var a := -PI / 2.0 + TAU * frac * i / n; pts.push_back(Vector2(cos(a), sin(a)) * R * 0.7)
			ci.draw_colored_polygon(pts, Color(K.RED, 0.42) if urgent else Color(K.BLUE, 0.3))
		var ha := -PI / 2.0 + TAU * frac; K.line(ci, Vector2.ZERO, Vector2(cos(ha), sin(ha)) * R * 0.66, hand_col, 2.5)
	else:
		var ma := -PI / 2.0 + TAU * fmod(gone / 60.0, 60.0) / 60.0; var sa := -PI / 2.0 + TAU * fmod(gone, 60.0) / 60.0
		K.line(ci, Vector2.ZERO, Vector2(cos(ma), sin(ma)) * R * 0.46, K.INK, 3.0); K.line(ci, Vector2.ZERO, Vector2(cos(sa), sin(sa)) * R * 0.66, K.RED, 1.6)
	for i in 12: var a2 := TAU * i / 12.0; K.line(ci, Vector2(cos(a2), sin(a2)) * R * (0.6 if i % 3 == 0 else 0.68), Vector2(cos(a2), sin(a2)) * R * 0.76, Color(K.INK, 0.8), 2.0 if i % 3 == 0 else 1.0)
	K.disc(ci, Vector2.ZERO, R * 0.1, hand_col)
	if ringing:   # the ring, as strokes flying off the bells
		for sx: float in [-1.0, 1.0]:
			for j in 3:
				var k := fmod(t * 3.0 + j * 0.33, 1.0); var dir := Vector2(sx * 0.8, -0.6).rotated((j - 1) * 0.5 * sx); var o := Vector2(sx * R * 0.9, -R * 1.1) + dir * R * (0.4 + k * 0.5)
				K.line(ci, o, o + dir * R * 0.22, Color(K.RED, 1.0 - k), 2.0)

## the top group from the middle of the screen's top edge: the boards either side of the clock's place, the time in
## figures on a tag under it, the bag on a brown luggage tag with small tags under it, the mode's own line on a strip of paper
func draw_top(ci) -> void:
	var g: Game = m.game; var M := top_model(cells())
	var urgent: bool = ringing or (M.time != null and bool(M.time.red))
	var cs := int(g.stats.time); var ttxt: String = str(M.time.text) if M.time != null else "%d:%02d" % [cs / 60, cs % 60]
	var tw := maxf(54.0, K.width(ttxt, 15) + 20.0)
	K.sticker(ci, Rect2(-tw / 2.0, 80, tw, 22), Color.WHITE, 6.0); K.text(ci, ttxt, 0, 82, 15, K.RED if urgent else K.INK, "center")
	if M.time != null: K.text(ci, str(M.time.label), 0, 101, 11, K.INK, "center", 3)
	var right_edge := 44.0
	if M.us != null: _board(ci, "us", -44.0, 22.0, M.us, true)
	if M.them != null: right_edge += _board(ci, "them", 44.0, 22.0, M.them, false)
	var x := right_edge + 12.0; var mt := "가방 " + str(M.money); var mw := K.width(mt, 11) + 30.0
	K.price_tag(ci, Rect2(x, 24, mw, 22), K.KRAFT_D); K.text(ci, mt, x + 20.0, 28, 11, Color.WHITE)
	var ty := 54.0
	for q: Array in M.tags:
		var tt := str(q[0]) + " " + str(q[1]); var qw := K.width(tt, 11) + 16.0
		K.sticker(ci, Rect2(x + 4.0, ty, qw, 20), K.YELLOW, 6.0); K.text(ci, tt, x + 12.0, ty + 3.0, 11, K.INK); ty += 25.0
	_pop_at = Vector2(x + mw, ty - 4.0)   # (where the money a kill pays drops out: under the tag and its small ones)
	var lines: Array = g.tm.mode.hud_lines() if (g.tm != null and not g.ended) else []
	var y := 118.0
	for Ln: Array in lines:
		var a := str(Ln[0]); var b := str(Ln[1]); var v := str(Ln[2]); var hot: bool = Ln[3]
		var aw := K.width(a, 11) + 14.0; var bw := K.width(b, 11); var vw := (K.width(v, 15) + 10.0) if v != "" else 0.0; var W := aw + bw + vw + 26.0
		K.sticker(ci, Rect2(-W / 2.0, y, W, 24), Color.WHITE, 6.0)
		K.tape(ci, Rect2(-W / 2.0 + 5.0, y + 4.0, aw, 16), K.RED if hot else K.tape_col(0)); K.text(ci, a, -W / 2.0 + 5.0 + aw / 2.0, y + 5.0, 11, Color.WHITE if hot else K.INK, "center")
		K.text(ci, b, -W / 2.0 + aw + 12.0, y + 5.0, 11, K.INK)
		if v != "": K.text(ci, v, W / 2.0 - 8.0, y + 3.0, 15, (K.RED if fmod(t, 0.7) < 0.35 else K.RED.darkened(0.3)) if hot else K.ORANGE.darkened(0.2), "right")
		y += 29.0

func top(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; var L := _layout(); _boards_tick(top_model(cells()))
	_at(ci, L.top, 0.0, float(L.top_k)); K.hold = true; draw_top(ci); K.flush(ci)
	K.at(ci, K._xf * Transform2D(sin(t * 47.0) * 0.1 if ringing else 0.0, Vector2(sin(t * 61.0) * 1.6 if ringing else 0.0, 46.0))); draw_clock(ci)
	K.at(ci, Transform2D.IDENTITY)

# ---- the little map, top left ----
## the room as a child would draw it: [what, min x, min z, max x, max z, crayon]. The bed blue, the desk brown.
const PLAN := [
	["rug", -46.0, 34.0, 46.0, 66.0, "f6b6c6"], ["bed", 10.0, -30.0, 62.0, 30.0, "4f8fe0"], ["pillow", 49.0, -26.0, 59.0, -8.0, "ffffff"], ["pillow", 49.0, 8.0, 59.0, 26.0, "ffe9a8"],
	["desk", -62.0, -28.0, -22.0, 20.0, "a8703c"], ["shelf", -62.0, -70.0, -6.0, -56.0, "e8913c"], ["wardrobe", 6.0, -70.0, 50.0, -54.0, "9b7fd1"],
	["bin", -52.0, 46.0, -42.0, 58.0, "3d7dca"], ["bin", 42.0, 46.0, 52.0, 58.0, "e63946"],
	["block", -22.0, -4.0, -14.0, 4.0, "e63946"], ["block", -14.0, -4.0, -6.0, 4.0, "f4d35e"], ["block", -6.0, -4.0, 2.0, 4.0, "3d7dca"], ["block", 2.0, -4.0, 10.0, 4.0, "5fbf8f"],
]
const PLAN_PX := 200
static var _plan: ImageTexture

## the plan's picture, made once: squared paper, each piece of furniture hatched in crayon with its edge pressed harder
static func plan_image() -> Image:
	var n := PLAN_PX; var img := Image.create(n, n, false, Image.FORMAT_RGBA8); var paper := Color("fdf8ea"); img.fill(paper)
	for i in range(0, n, 8):
		var gc := Color("a9cbe6") if i % 40 == 0 else Color("d3e4f1")
		img.fill_rect(Rect2i(i, 0, 1, n), gc); img.fill_rect(Rect2i(0, i, n, 1), gc)
	var H := ToyRoom.HALF + 2.0; var k := n / (2.0 * H); var R := RandomNumberGenerator.new(); R.seed = 9
	for S: Array in PLAN:
		var x0 := int(roundf((float(S[1]) + H) * k)); var z0 := int(roundf((float(S[2]) + H) * k)); var x1 := int(roundf((float(S[3]) + H) * k)); var z1 := int(roundf((float(S[4]) + H) * k))
		var col := Color(str(S[5])); var ph := R.randf() * 6.0; var edge := col.darkened(0.3)
		for y in range(z0, z1):
			for x in range(x0, x1):
				var e := mini(mini(x - x0, x1 - 1 - x), mini(y - z0, z1 - 1 - y))
				if e == 0 and sin((x * 0.9 + y * 1.3) * 0.7 + ph) > 0.55: continue   # a ragged edge
				var a := 0.92 if e <= 1 else clampf(0.62 + 0.3 * sin((x * 0.95 + y * 0.62) * 1.7 + sin(y * 0.23 + ph) * 2.0) + R.randf_range(-0.14, 0.1), 0.2, 0.95)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(edge if e <= 1 else col, a))
	return img

static func plan_tex() -> ImageTexture:
	if _plan == null: _plan = ImageTexture.create_from_image(plan_image())
	return _plan

## the paper map about its middle, S across: the plan, the mode's own marks, the toys as pins, you as an arrow
func draw_map(ci, S: float, touch: bool) -> void:
	var g: Game = m.game; var o := Vector2(-S / 2.0, -S / 2.0)
	K.solid(ci, Rect2(o + Vector2(1.5, 3.0), Vector2(S, S)), Color(0, 0, 0, 0.3)); ci.draw_texture_rect(plan_tex(), Rect2(o, Vector2(S, S)), false)
	var H := ToyRoom.HALF + 2.0; var k := S / (2.0 * H); var u := S / 240.0
	var X := func(x: float) -> float: return o.x + (x + H) * k
	var Z := func(z: float) -> float: return o.y + (z + H) * k
	var w: World = m.world
	if w != null and w.toy != null and not (w.toy.train.cars as Array).is_empty():   # the toy train's loop, in pencil
		var lp: Array = w.toy.train.loop
		for i in lp.size(): var a: Vector3 = lp[i]; var b: Vector3 = lp[(i + 1) % lp.size()]; K.line(ci, Vector2(X.call(a.x), Z.call(a.z)), Vector2(X.call(b.x), Z.call(b.z)), Color(0.35, 0.37, 0.45, 0.75), maxf(1.0, 1.4 * u))
	if g.tm != null: g.tm.mode.tac(ci, X, Z, k, u)   # the mode's own marks: bases, the track, batteries
	var pr := maxf(2.2, 3.0 * u)
	for e: Enemies.Foe in m.enemies.list:   # theirs: red pins (a soldier keeping still under his camouflage, fainter)
		if e.alive: K.pin(ci, Vector2(X.call(e.pos.x), Z.call(e.pos.z)), pr, K.RED, 0.45 if (e.toy and m.enemies.toys != null and m.enemies.toys.camo(e)) else 1.0)
	if g.tm != null:
		for a in g.tm.allies:   # ours: blue pins
			if a.alive and not bool(a.k.get("gone", false)): K.pin(ci, Vector2(X.call(a.pos.x), Z.call(a.pos.z)), pr, K.US)
	# you: a green arrow sticker pointing the way you face (north on the paper is -z)
	var pl: Player = m.player; var pp := Vector2(X.call(pl.pos.x), Z.call(pl.pos.z)); var ang := atan2(-cos(pl.yaw), -sin(pl.yaw))
	var au := maxf(0.7, u)
	K.sub(ci, pp, ang + PI / 2.0); K.drop(ci, Vector2(0, -2.0 * au), 20.0 * au, Color.WHITE); K.drop(ci, Vector2(0, -2.0 * au), 14.5 * au, Color("1faa7d")); K.disc(ci, Vector2(0, 1.6 * au), 2.0 * au, Color.WHITE); K.unsub(ci)
	# two strips of tape hold the paper to the glass (a phone's is the map button: "지도" on its corner instead)
	if touch: K.sticker(ci, Rect2(o.x + S - 30.0, o.y + S - 13.0, 32, 16), K.YELLOW, 4.0); K.text(ci, "지도", o.x + S - 14.0, o.y + S - 13.0, 11, K.INK, "center")
	else:
		for q: Array in [[Vector2(o.x + 4.0, o.y + 2.0), -0.7, 4], [Vector2(o.x + S - 4.0, o.y + 2.0), 0.7, 1]]:
			K.sub(ci, q[0], q[1]); K.tape(ci, Rect2(-18, -6, 36, 12), K.tape_col(q[2]), 0.85); K.unsub(ci)
		K.text(ci, "M", o.x + S - 12.0, o.y + S - 17.0, 11, Color(K.INK, 0.7), "center", 3)

func minimap(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; var R: Rect2 = _layout().map
	_at(ci, R.get_center(), 0.0 if touch else -0.035 + _sway(4.0), 1.0); K.hold = true; draw_map(ci, R.size.x, touch); K.flush(ci); K.at(ci, Transform2D.IDENTITY)

# ---- the middle: the crosshair, the stickers ----
func _arc(ci, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w := 2.0) -> void:
	for i in n: K.line(ci, c + Vector2(cos(lerpf(a0, a1, float(i) / n)), sin(lerpf(a0, a1, float(i) / n))) * r, c + Vector2(cos(lerpf(a0, a1, float(i + 1) / n)), sin(lerpf(a0, a1, float(i + 1) / n))) * r, col, w)

## the crosshair of the toy in your hand; `gap` is the spread as it falls on the screen, `ink` the colour chosen in the settings
func cross(ci, c: Vector2, gap: float, ink: Color, id: String) -> void:
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]; var dark := Color(0, 0, 0, 0.3 * ink.a)
	K.at(ci, Transform2D.IDENTITY)
	match str(CROSS.get(id, "bars")):
		"sucker":   # the dart pistol: a sucker's ring and four short marks
			K.ring(ci, c, 5.5, dark, true); K.ring(ci, c, 4.5, ink, true)
			for d: Vector2 in dirs: K.line(ci, c + d * (gap + 3.0), c + d * (gap + 9.0), ink, 2.0, true)
		"drops":    # the water gun: a ring of eight drops as wide as the spray
			var r := maxf(gap, 16.0)
			for i in 8:
				var a := TAU * i / 8.0 + PI / 8.0
				K.sub(ci, c + Vector2(cos(a), sin(a)) * r, a + PI / 2.0); K.drop(ci, Vector2(0, -1.5), 12.0, dark); K.drop(ci, Vector2(0, -1.5), 9.5, ink)
			K.unsub(ci); K.disc(ci, c, 1.6, ink)
		"tee":      # the cap gun: left, right and down
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]: K.line(ci, c + d * gap, c + d * (gap + 8.0), ink, 2.0, true)
			K.disc(ci, c, 1.6, ink)
		"laser":    # the laser pointer: a red dot, glowing
			K.disc(ci, c, 7.0, Color(1, 0.16, 0.1, 0.22 * ink.a)); K.disc(ci, c, 3.6, Color(1, 0.16, 0.1, ink.a)); K.disc(ci, c, 1.4, Color(1, 0.8, 0.75, ink.a))
		"sling":    # the slingshot: its fork under the middle
			_arc(ci, c + Vector2(0, gap * 0.5), maxf(gap + 5.0, 11.0), PI * 0.15, PI * 0.85, 8, dark, 4.0); _arc(ci, c + Vector2(0, gap * 0.5), maxf(gap + 5.0, 11.0), PI * 0.15, PI * 0.85, 8, ink, 2.0); K.disc(ci, c, 2.0, ink)
		"ring":     # the gatling: a ring with its six rods marked
			var r2 := maxf(gap + 3.0, 10.0); K.ring(ci, c, r2 + 1.0, ink)
			for i in 6: var a2 := TAU * i / 6.0; K.line(ci, c + Vector2(cos(a2), sin(a2)) * (r2 - 3.0), c + Vector2(cos(a2), sin(a2)) * (r2 + 3.0), ink, 2.0)
			K.disc(ci, c, 1.6, ink)
		"target":   # the bottle rocket: a target's three rings
			K.ring(ci, c, 7.0, ink, true); K.ring(ci, c, 14.0, ink); K.ring(ci, c, 21.0, Color(ink, ink.a * 0.7))
			for d: Vector2 in dirs: K.line(ci, c + d * 21.0, c + d * 28.0, ink, 2.0, true)
			K.disc(ci, c, 1.8, Color(1, 0.25, 0.2, ink.a))
		"spray":    # the spray can: its cone of mist, three arcs widening
			for i in 3: _arc(ci, c + Vector2(0, 4.0), 7.0 + i * 6.0, -PI * 0.5 - 0.5 - i * 0.07, -PI * 0.5 + 0.5 + i * 0.07, 5, Color(ink, ink.a * (1.0 - i * 0.22)), 2.0)
			K.disc(ci, c, 1.6, ink)
		_:          # the blaster: four thick bars, a foam dart's width
			for d: Vector2 in dirs: K.line(ci, c + d * gap, c + d * (gap + 9.0), ink, 3.0, true)
			K.disc(ci, c, 1.6, ink)

func stickers_draw(ci, c: Vector2) -> void:
	if stickers.is_empty(): return
	K.at(ci, Transform2D.IDENTITY)
	for S: Dictionary in stickers:
		var f: float = float(S.age) / float(S.life); var pop := minf(1.0, float(S.age) / 0.07); var sc := pop * (1.0 + 0.25 * maxf(0.0, 1.0 - float(S.age) / 0.14)); var a := clampf((1.0 - f) / 0.35, 0.0, 1.0)
		var p := c + Vector2(cos(S.ang), sin(S.ang)) * (float(S.dist) + 10.0 * f)
		if S.kind == "ddakji": K.ddakji(ci, p, float(S.r) * sc, K.RED, K.BLUE, float(S.rot) + f * 1.2, a)
		else: K.star(ci, p, float(S.r) * sc, S.col, float(S.rot) + f * 0.8, a)

## the reload under the crosshair: a yellow ruler filling up
func reload_bar(ci, c: Vector2, f: float) -> void:
	K.solid(ci, Rect2(c.x - 62, c.y + 42, 124, 11), K.INK); K.solid(ci, Rect2(c.x - 61, c.y + 43, 122, 9), Color(1, 1, 1, 0.75))
	K.solid(ci, Rect2(c.x - 60, c.y + 44, 120.0 * clampf(f, 0.0, 1.0), 7), Color("ffe066"))
	for i in range(1, 12): K.solid(ci, Rect2(c.x - 60.0 + i * 10.0, c.y + 44, 1, 4 if i % 2 == 0 else 2.5), Color(K.INK, 0.7))

# ---- the kill lines, top right ----
func draw_feed(ci) -> void:
	var touch := _touch; var at: Vector2 = _layout().feed; var y := at.y; var fs := 12 if touch else 13; var h := fs + 11.0
	for i in hud.feed.size():
		var Ln: Array = hud.feed[i]; var text := str(Ln[0]); var pay := int(Ln[1]); var age := float(Ln[2]); var red: bool = Ln[3]
		var a := 1.0 - clampf((age - 2.4) / 0.45, 0.0, 1.0); var stamp := clampf(age / 0.14, 0.0, 1.0)
		var P := kill_parts(text); var who := ""; var whom := ""; var gap := 0.0
		if not P.is_empty(): who = str(P[0]); whom = str(P[1]); gap = 36.0
		var tw := (K.width(who, fs) + gap + K.width(whom, fs)) if who != "" else K.width(text, fs)
		var pt := "+" + Store.won(pay); var pw := (K.width(pt, fs - 1) + 14.0) if pay > 0 else 0.0; var sw := 16.0 if (who != "" and bool(P[2])) else 0.0
		var w := tw + pw + sw + 24.0; var x := at.x if touch else at.x - w; var hsh := absi(hash(text))
		_at(ci, Vector2(x + w / 2.0, y + h / 2.0), (float(hsh % 7) - 3.0) * 0.006, lerpf(1.45, 1.0, stamp))   # pressed on like a stamp
		var x0 := -w / 2.0; var y0 := -h / 2.0
		K.tape(ci, Rect2(x0, y0, w, h), Color("f7a8b8") if red else K.tape_col(hsh % 5), 0.95 * a * stamp); var tx := x0 + 12.0
		if who != "":
			var wc := Color("1c4a9e") if who != "상대" else Color("ad1f2b"); var vc := Color("ad1f2b") if who != "상대" else Color("1c4a9e")
			tx += K.text(ci, who, tx, y0 + 4.0, fs, Color(wc, a))
			K.gun(ci, m.guns.cur if who == "나" else "pistol", Rect2(tx + 3.0, y0 + 3.0, gap - 6.0, h - 6.0), a); tx += gap
			tx += K.text(ci, whom, tx, y0 + 4.0, fs, Color(vc, a))
			if bool(P[2]): K.star(ci, Vector2(tx + 9.0, 0.0), 5.5, K.ORANGE, 0.2, a); tx += sw
		else: tx += K.text(ci, text, tx, y0 + 4.0, fs, Color(K.INK, a))
		if pay > 0: K.sticker(ci, Rect2(tx + 5.0, y0 + 3.0, pw - 3.0, h - 6.0), Color(K.YELLOW, roundf(a * 8.0) / 8.0), 6.0); K.text(ci, pt, tx + 5.0 + (pw - 3.0) / 2.0, y0 + 5.0, fs - 1, Color(K.INK, a), "center")
		y += h + 6.0
	K._xf = Transform2D.IDENTITY   # (the words held back keep each line's own turn; after them, plain again)

func feed(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; K.hold = true; draw_feed(ci); K.flush(ci)

# ---- on the glass itself: drops of water at its edges, each with the light caught in it ----
func draw_glass(ci) -> void:
	for d: Dictionary in drops:
		var u: float = float(d.age) / float(d.life); var a := clampf(float(d.age) / 0.12, 0.0, 1.0) * clampf((1.0 - u) / 0.35, 0.0, 1.0)
		var c := Vector2(float(d.p.x) * _size.x, float(d.p.y) * _size.y); var r: float = d.r
		K.drop(ci, c + Vector2(0.8, 1.6), r * 2.3, Color(0.05, 0.12, 0.2, 0.16 * a)); K.drop(ci, c, r * 2.2, Color(0.72, 0.88, 1.0, 0.3 * a))
		K.disc(ci, c + Vector2(-r * 0.22, r * 0.2), r * 0.2, Color(1, 1, 1, 0.75 * a))

func glass(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; K.hold = true; draw_glass(ci); K.flush(ci)

# ---- over everything: the money a kill pays dropping out of the bag's tag ----
func draw_over(ci) -> void:
	var L := _layout(); var o: Vector2 = L.top; var tk := float(L.top_k)
	for p: Array in hud.pops:
		var k: float = float(p[1]) / 1.2; K.text(ci, str(p[0]), o.x + _pop_at.x * tk, o.y + (_pop_at.y + 22.0 * k) * tk, 14, Color(K.ORANGE.darkened(0.15), 1.0 - k), "right", 3, Color(1, 1, 1, 1.0 - k))

func over(ci, s: Vector2, touch: bool) -> void:
	_size = s; _touch = touch; K.hold = true; draw_over(ci); K.flush(ci)

## the whole screen in one go, where no controls hold the pieces (the checks)
func draw_all(ci, s: Vector2, touch: bool) -> void:
	glass(ci, s, touch); top(ci, s, touch); feed(ci, s, touch); minimap(ci, s, touch); battery(ci, s, touch, hud._items(touch)); tray(ci, s, touch); over(ci, s, touch)
