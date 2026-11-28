class_name Hud
extends RefCounted
## The fight's screen, laid out as the browser game's (src/08c_hud.js, src/01_head.html): the stage, kills and bag in a box at the top
## middle with the kill bar under it (and the next cage, the bleeding, the boss under that), the kill lines at the top right, health at
## the bottom left, the gun and its rounds at the bottom right with the slots above. Over the view: where a hit came from, the red edge
## of low health, the green of infection or poison with a heartbeat, the white of a stun, arrows to the last ten enemies (or to the
## chest), the rocket's lock, the hit mark, the reload bar, the hint, the banner, and the SMG's green wind.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a"); const ALARM := Color("ff5260"); const VITAL := Color("5ed6b0")
const PANEL := Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.78); const LINE := Color(233 / 255.0, 228 / 255.0, 216 / 255.0, 0.16)

var m   # main: the game, the player, the guns, the look mode, the fonts
var hurt_t := 0.0
var arcs: Array = []   # where hits came from: [life, from]
var arc_i := 0
var hit_t := 0.0; var hit_kill := false; var hit_head := false
var heart_t := 0.0
var lock_t := 0.0; var lock_e = null
var pops: Array = []    # money popping out under the box: [text, age]
var feed: Array = []    # kill lines: [text, pay, age, red]
var banner_big := ""; var banner_small := ""; var banner_t := 0.0; var banner_a := 0.0
var hint_text := ""; var hint_t := 0.0
var ghost := 1.0        # the red behind the health bar, catching up after a hit
var ghost_wait := 0.0
var wind_k := 0.0; var wind: Array = []
var _tex := {}
var toy := ToyHud.new()   # stage 5's own screen: the same things as a child's desk would show them (scripts/toyhud.gd)
var realm := RealmHud.new()   # stage 6's team battles: their own screen (scripts/realmhud.gd)

func _init() -> void:
	toy.hud = self
	for i in 4: arcs.push_back([0.0, Vector3.ZERO])
	for i in 40: wind.push_back({"a": randf() * TAU, "r": 0.5 + randf() * 0.6, "v": 0.7 + randf() * 0.6, "l": 0.08 + randf() * 0.14, "wd": 1.6 + randf() * 2.2})

func reset() -> void:
	feed.clear(); pops.clear(); hit_t = 0.0; hurt_t = 0.0; hint_t = 0.0; banner_t = 0.0; banner_a = 0.0; ghost = 1.0; toy.reset()
	for A in arcs: A[0] = 0.0

# ---------------- what the game tells it ----------------
func hurt(dmg: float, from) -> void:
	hurt_t = minf(0.6, 0.2 + dmg * 0.012)
	if from is Vector3: arcs[arc_i] = [1.2, from]; arc_i = (arc_i + 1) % arcs.size()

func hitmark(kill: bool, head: bool) -> void:
	hit_t = 0.35 if kill else (0.26 if head else 0.16); hit_kill = kill; hit_head = head
	if is_toy(): toy.hit(kill, head)

## stage 5, the toy room: its screen is ToyHud's
func is_toy() -> bool: return m != null and m.game != null and m.game.stage == Store.ST_TOY

func say_feed(text: String, pay := 0, red := false) -> void:
	feed.push_front([text, pay, 0.0, red])
	if feed.size() > 4: feed.pop_back()

func money_pop(n: int) -> void: pops.push_back(["+" + Store.won(n), 0.0])
func banner(big: String, small: String, sec: float) -> void: banner_big = big; banner_small = small; banner_t = sec
func hint(text: String, sec := 1.6) -> void: hint_text = text; hint_t = sec

func update(dt: float) -> void:
	hit_t = maxf(0.0, hit_t - dt); hurt_t = maxf(0.0, hurt_t - dt)
	for A in arcs: A[0] = maxf(0.0, A[0] - dt)
	for i in range(pops.size() - 1, -1, -1):
		pops[i][1] += dt
		if pops[i][1] > 1.2: pops.remove_at(i)
	for i in range(feed.size() - 1, -1, -1):
		feed[i][2] += dt
		if feed[i][2] > 2.85: feed.remove_at(i)
	if banner_t > 0.0: banner_t -= dt
	banner_a = move_toward(banner_a, 1.0 if banner_t > 0.35 else 0.0, dt / 0.35)
	if hint_t > 0.0: hint_t -= dt
	# the red behind health: it waits a quarter second, then slides down to the health in 0.6 s
	var f: float = clampf(m.player.hp / m.player.max_hp, 0.0, 1.0)
	if ghost < f: ghost = f; ghost_wait = 0.0
	elif ghost > f:
		ghost_wait += dt
		if ghost_wait > 0.25: ghost = maxf(f, ghost - dt * 1.4)
	else: ghost_wait = 0.0
	# infection and poison: a heartbeat that quickens as the time runs out
	var g: Game = m.game
	if g.infected or g.poison_t > 0.0:
		var T: float = minf(g.infect_t, g.poison_t) if (g.infected and g.poison_t > 0.0) else (g.infect_t if g.infected else g.poison_t)
		heart_t -= dt
		if heart_t <= 0.0: heart_t = 0.45 + T * 0.12; Snd.play("heart"); Snd.buzz(25)
	else: heart_t = 0.0
	# the SMG's green wind, stronger the faster you run with it
	var sp: float = m.player.speed_xz; var want := minf(1.0, maxf(0.3, (sp - 0.8) / 7.0)) if (m.state == "playing" and m.guns.cur == "smg" and not m.guns.none and sp > 0.8) else 0.0
	wind_k += (want - wind_k) * (1.0 - exp(-dt * 6.0))
	if wind_k >= 0.012:
		for p in wind:
			p.r += p.v * dt * (0.8 + wind_k * 1.6)
			if p.r > 1.15: p.r = 0.46 + randf() * 0.22; p.a = randf() * TAU; p.v = 0.7 + randf() * 0.6; p.l = 0.08 + randf() * 0.14
	if is_toy(): toy.m = m; toy.update(dt)
	elif not toy.nodes.is_empty(): toy.show(false)   # (out of the toy room: its pieces put away)

# ---------------- drawing ----------------
## the radial glows over the whole view, each with its own stops [[at, colour], ...] (one table: a key always has the same picture)
const GLOW_STOPS := {
	"hurt": [[0.0, Color(1, 40 / 255.0, 60 / 255.0, 0)], [0.45, Color(1, 40 / 255.0, 60 / 255.0, 0)], [1.0, Color(1, 40 / 255.0, 60 / 255.0, 0.55)]],
	"low": [[0.0, Color(120 / 255.0, 0, 20 / 255.0, 0)], [0.55, Color(120 / 255.0, 0, 20 / 255.0, 0)], [1.0, Color(120 / 255.0, 0, 20 / 255.0, 0.6)]],
	"toxic": [[0.0, Color(70 / 255.0, 190 / 255.0, 90 / 255.0, 0)], [0.35, Color(70 / 255.0, 190 / 255.0, 90 / 255.0, 0)], [1.0, Color(70 / 255.0, 190 / 255.0, 90 / 255.0, 0.5)]],
	"stun": [[0.0, Color(1, 1, 1, 0.18)], [0.45, Color(200 / 255.0, 200 / 255.0, 210 / 255.0, 0.35)], [1.0, Color(20 / 255.0, 20 / 255.0, 30 / 255.0, 0.75)]],
	"down": [[0.0, Color(0, 0, 0, 0.35)], [0.5, Color(0, 0, 0, 0.5)], [1.0, Color(0.05, 0.02, 0.02, 0.85)]],
	"watch": [[0.0, Color(1, 0.85, 0.5, 0)], [0.6, Color(1, 0.85, 0.5, 0.0)], [1.0, Color(1, 0.75, 0.35, 0.4)]],
	"wind": [[0.0, Color(70 / 255.0, 1, 150 / 255.0, 0)], [0.5, Color(70 / 255.0, 1, 150 / 255.0, 0)], [1.0, Color(70 / 255.0, 1, 150 / 255.0, 0.24)]],
	"burn": [[0.0, Color(1, 110 / 255.0, 20 / 255.0, 0)], [0.5, Color(1, 110 / 255.0, 20 / 255.0, 0)], [1.0, Color(1, 90 / 255.0, 10 / 255.0, 0.5)]],
}

## a radial glow over the whole view, as the browser's "radial-gradient(ellipse at center, ...)", from its stops in GLOW_STOPS
func _radial_tex(key: String) -> GradientTexture2D:
	if _tex.has(key): return _tex[key]
	var stops: Array = GLOW_STOPS[key]
	var gr := Gradient.new(); gr.offsets = PackedFloat32Array(stops.map(func(q): return float(q[0]))); gr.colors = PackedColorArray(stops.map(func(q): return q[1]))
	var t := GradientTexture2D.new(); t.gradient = gr; t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(0.5 + 0.7071, 0.5); t.width = 256; t.height = 256
	_tex[key] = t; return t

func _glow(ci, key: String, a: float) -> void:
	if a <= 0.004: return
	ci.draw_texture_rect(_radial_tex(key), Rect2(Vector2.ZERO, ci.size), false, Color(1, 1, 1, clampf(a, 0.0, 1.0)))

func _w(font: Font, text: String, fs: int) -> float: return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## text with its top at y (the browser places boxes by their top), left/centre/right of x
func _t(ci, font: Font, text: String, x: float, y: float, fs: int, col: Color, align := "left", shadow := true) -> float:
	var w := _w(font, text, fs); var px := x if align == "left" else (x - w / 2.0 if align == "center" else x - w); var py := y + font.get_ascent(fs)
	if shadow: ci.draw_string(font, Vector2(px + 1, py + 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75 * col.a))
	ci.draw_string(font, Vector2(px, py), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col); return w

func _panel(ci, r: Rect2, bg := PANEL, line := LINE) -> void:
	ci.draw_rect(r, bg); ci.draw_rect(r, line, false, 1.0)

func draw(ci) -> void:
	var s: Vector2 = ci.size; var c := s / 2.0; var g: Game = m.game; var pl: Player = m.player; var guns: Guns = m.guns; var touch: bool = m.look_mode == "touch"
	var t: float = m.time; var W: Dictionary = guns.w(); var st: Dictionary = guns.st()
	var f_title: Font = m.f_title; var f_body: Font = m.f_body; var f_bold: Font = m.f_bold; var f_mono: Font = m.f_mono
	var pct := clampf(pl.hp / pl.max_hp, 0.0, 1.0) * 100.0
	var toy_on := g.stage == Store.ST_TOY   # the toy room: the same things, drawn as ToyHud draws them
	if toy_on: toy.m = m
	# ---- over the view ----
	_wind(ci, s, c)
	_glow(ci, "hurt", hurt_t * 2.2)
	if g.stage != 2 and pct < 35.0 and not (g.rm != null and pl.out): _glow(ci, "low", (0.55 + sin(t * 6.0) * 0.25) * (1.0 - pct / 35.0) + 0.2)
	var inf := g.infected; var poi := g.poison_t > 0.0; var T := 0.0
	if inf or poi:
		T = minf(g.infect_t, g.poison_t) if (inf and poi) else (g.infect_t if inf else g.poison_t)
		_glow(ci, "toxic", 0.55 + sin(t * 9.0) * 0.25 + maxf(0.0, 5.0 - T) * 0.06)
	if pl.stun_t > 0.0: _glow(ci, "stun", clampf(pl.stun_t, 0.0, 1.0) * (0.75 + sin(t * 7.0) * 0.15))
	if g.burn_t > 0.0: _glow(ci, "burn", 0.5 + sin(t * 8.0) * 0.18)   # (6-B: set alight: the edges of the view flicker orange)
	if g.tm != null and pl.out: _glow(ci, "down", 1.0)   # down: the view darkens
	if g.tm != null and g.tm.key == "freeze" and str(g.tm.mode.phase) in ["open", "look"]: _glow(ci, "watch", 0.6 + 0.4 * sin(t * 5.0))
	_scope_and_cross(ci, s, c, W, guns, pl)
	_dmgdir(ci, c, pl)
	if g.tm != null: _friends(ci, g)
	_targets(ci, c, g, pl)
	_lock(ci, s, W, guns, st)
	if toy_on: toy.stickers_draw(ci, c)   # (the toy room: star stickers instead)
	elif hit_t > 0.0:   # the hit mark: white, orange for the head, red for a kill
		var hc := ALARM if hit_kill else (SODIUM if hit_head else Color.WHITE); var sc := (1.75 if hit_head else 1.35) if hit_kill else (1.3 if hit_head else 1.0); hc.a = clampf(hit_t * 6.0, 0.0, 1.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: ci.draw_line(c + d.normalized() * 2.0 * sc, c + d.normalized() * 16.0 * sc, hc, 2.0)
	if guns.reload_t > 0.0 and toy_on: toy.reload_bar(ci, c, 1.0 - guns.reload_t / float(W.reload))
	elif guns.reload_t > 0.0:
		ci.draw_rect(Rect2(c.x - 60, c.y + 44, 120, 4), Color(233 / 255.0, 228 / 255.0, 216 / 255.0, 0.15)); ci.draw_rect(Rect2(c.x - 60, c.y + 44, 120.0 * (1.0 - guns.reload_t / float(W.reload)), 4), SODIUM)
	# the hint under the crosshair: what was said, or what to press now
	var ht := hint_text if hint_t > 0.0 else ""
	if ht == "" and int(st.mag) == 0 and float(st.reserve) > 0.0 and guns.reload_t <= 0.0: ht = "장전 버튼을 누르세요" if touch else "R 키로 재장전"
	if ht == "" and not touch: ht = m.key_hint()
	if ht != "" and toy_on: toy.words(ci, ht, c.x, c.y + 58, 13)
	elif ht != "": _t(ci, f_mono, ht, c.x, c.y + 58, 12, SODIUM, "center")
	# the banner a quarter of the way down; the status line over it; infection's countdown under it
	if banner_a > 0.0 and banner_big != "":
		var bf := int(clampf(s.x * 0.09, 40, 92)); var bc := INK; bc.a = banner_a; var sc2 := SODIUM; sc2.a = banner_a
		if toy_on: ToyKit.text(ci, banner_big, c.x, s.y * 0.24, bf, Color(1, 1, 1, banner_a), "center", maxi(4, bf / 7), Color(ToyKit.INK, banner_a)); toy.words(ci, banner_small, c.x, s.y * 0.24 + bf * 1.15 + 6, 15, ToyKit.INK, "center", banner_a)
		else: _t(ci, f_title, banner_big, c.x, s.y * 0.24, bf, bc, "center"); _t(ci, f_mono, banner_small, c.x, s.y * 0.24 + bf * 1.15 + 6, 13, sc2, "center")
	var stt := _status(pl, g, touch)
	if stt != "" and toy_on:
		if g.tm != null and (pl.out or stt == "움직이지 마세요!"): toy.words(ci, stt, c.x, s.y * 0.36, int(clampf(s.x * 0.05, 24, 40)), ToyKit.RED if stt == "움직이지 마세요!" else ToyKit.INK)
		else: toy.words(ci, stt, c.x, s.y * 0.23, int(clampf(s.x * 0.036, 15, 20)), ToyKit.INK)
	elif stt != "":
		if pl.stun_t > 0.0: _t(ci, f_title, stt, c.x, s.y * 0.23, int(clampf(s.x * 0.08, 30, 52)), Color.WHITE, "center")
		elif g.tm != null and (pl.out or stt == "움직이지 마세요!"): _t(ci, f_title, stt, c.x, s.y * 0.36, int(clampf(s.x * 0.05, 24, 40)), ALARM if stt == "움직이지 마세요!" else INK, "center")
		else: _t(ci, f_bold, stt, c.x, s.y * 0.23, int(clampf(s.x * 0.036, 15, 20)), Color("b9f5a8"), "center")
	if inf or poi:
		var what := "감염 + 중독" if (inf and poi) else ("감염됨" if inf else "중독됨"); var pulse := 1.0 + 0.06 * (0.5 + 0.5 * sin(t * PI * 2.0))
		var msg := (what + (" · 해독약 버튼을 누르세요" if touch else " · F 키로 해독약 사용")) if g.antidotes > 0 else what + " · 해독약이 없습니다! 상자를 부수세요"
		var bfs := int(clampf(s.x * 0.12, 48, 84) * pulse)
		_t(ci, f_title, "%.1f" % maxf(0.0, T), c.x, s.y * 0.30, bfs, Color("9be88f"), "center"); _t(ci, f_mono, msg, c.x, s.y * 0.30 + bfs * 1.1, 13, Color("d9f5d2"), "center")
	if g.burn_t > 0.0:   # (6-B) what burns on you, and how long it has left
		_t(ci, f_bold, "화상 %.1f초 · 냉각 수조를 지나면 꺼집니다" % g.burn_t, c.x, c.y + 78, 13, Color("ffb070"), "center")
	if toy_on:   # the toy room: the clock and the boards, the tape, the paper map, the battery, the tray are ToyHud's own controls
		if toy.nodes.is_empty(): toy.draw_all(ci, s, touch)   # (...or, with no HUD to hold them, drawn here in one go)
		return
	if g.rm != null: realm.draw(self, ci, s, c, touch); return   # (a realm battle: its own screen from here)
	# ---- the box at the top ----
	_topbox(ci, s, c, g, f_mono, f_bold, f_title)
	_feed(ci, s, touch, f_body, f_mono)
	_vbars(ci, s, g, pl, f_title, f_bold)
	# ---- health, bottom left ----
	var bottom := 12.0 if touch else 18.0; var vw := minf(200.0, s.x * 0.4) if touch else minf(280.0, s.x * 0.42); var vx := 16.0
	var items := _items(touch, g); var iy := s.y - bottom
	if not items.is_empty(): iy -= 20.0
	if g.stage == 2:   # the village has no health: the antidotes you carry
		var y0 := iy - 34.0
		var lw := _t(ci, f_mono, "해독약", vx, y0 + 18, 10, STEEL); var nw := _t(ci, f_mono, str(g.antidotes), vx + lw + 8, y0, 34, Color("9be88f")); _t(ci, f_mono, "개", vx + lw + nw + 16, y0 + 18, 10, STEEL)
	else:
		var by := iy - 8.0; var y0 := by - 6.0 - 34.0
		var hw := _t(ci, f_mono, str(ceili(pl.hp)), vx, y0, 34, INK); _t(ci, f_mono, "체력", vx + hw + 10, y0 + 18, 10, STEEL)
		ci.draw_rect(Rect2(vx, by, vw, 8), Color(233 / 255.0, 228 / 255.0, 216 / 255.0, 0.12))
		ci.draw_rect(Rect2(vx, by, vw * ghost, 8), Color(1, 82 / 255.0, 96 / 255.0, 0.55))
		ci.draw_rect(Rect2(vx, by, vw * pct / 100.0, 8), VITAL if pct > 50.0 else (SODIUM if pct > 25.0 else ALARM)); ci.draw_rect(Rect2(vx, by, vw, 8), LINE, false, 1.0)
	var cx := vx
	for it: Array in items:   # what you carry, as chips under your health
		var tw := _w(f_bold, it[0], 11) + 14.0; var col: Color = ALARM if it[1] == "low" else (SODIUM if it[1] == "jet" else INK)
		_panel(ci, Rect2(cx, s.y - bottom - 18, tw, 18), Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.55), Color(col, 0.55) if it[1] != "" else Color(INK, 0.3)); _t(ci, f_bold, it[0], cx + 7, s.y - bottom - 17, 11, col, "left", false); cx += tw + 5.0
	# ---- the gun, bottom right; the slots above it (not on a phone) ----
	var ax := s.x - 16.0; var ay := s.y - bottom
	var mag := str(int(st.mag)); var res := "/ " + ("∞" if float(st.reserve) == INF else str(int(st.reserve)))
	var rw := _w(f_mono, res, 18); _t(ci, f_mono, res, ax, ay - 22, 18, STEEL, "right"); _t(ci, f_mono, mag, ax - rw - 8, ay - 40, 40, ALARM if int(st.mag) <= ceili(float(W.mag) * 0.25) else INK, "right")
	var wn: String = Toys.NAMES[guns.cur] if g.stage == Store.ST_TOY else str(W.model) + " " + str(W.name) + (" · 이동 -%d%%" % roundi((1.0 - float(W.moveMul)) * 100.0) if W.get("heavy", false) else "") + (" · 과열" if (W.get("heat", false) and st.get("hot", false)) else "")
	_t(ci, f_title, wn, ax, ay - 40 - 6 - 22, 18, SODIUM, "right")
	if not touch:
		var x := ax; var sy := s.y - 96.0 - 18.0
		for i in range(guns.loadout.size() - 1, -1, -1):
			var id = guns.loadout[i]
			if id == null: continue
			var txt := "%d %s" % [i + 1, (Toys.NAMES[id] if g.stage == Store.ST_TOY else Custom.weapon(id).short)]; var tw := _w(f_mono, txt, 11) + 14.0; x -= tw
			var on: bool = id == (guns.pending if guns.pending != null else guns.cur)
			_panel(ci, Rect2(x, sy, tw, 18), SODIUM if on else PANEL, SODIUM if on else LINE); _t(ci, f_mono, txt, x + 7, sy + 1, 11, NIGHT if on else STEEL, "left", false); x -= 4.0

## the stage, kills and bag; the kill bar; then the safari's or the lab's clock, the bleeding and the boss, stacked under it
func _topbox(ci, s: Vector2, c: Vector2, g: Game, f_mono: Font, f_bold: Font, f_title: Font) -> void:
	var done := g.kills + g.calm
	var cells := [["스테이지", Store.STAGE_TAG[g.stage], SODIUM], ["처치", "%d / %d" % [done, g.goal], INK], ["가방", Store.won(Store.save.money), INK]]
	if g.tm != null: cells = g.tm.mode.hud_cells()   # stage 5's team modes: their own cells
	var ws := []; var total := 0.0
	for q in cells: var w: float = maxf(74.0, maxf(_w(f_mono, q[0], 10), _w(f_mono, q[1], 18)) + 28.0); ws.push_back(w); total += w
	var x0 := c.x - total / 2.0; var y0 := 14.0; var h := 48.0
	_panel(ci, Rect2(x0, y0, total, h))
	var x := x0
	for i in cells.size():
		if i > 0: ci.draw_line(Vector2(x, y0), Vector2(x, y0 + h), LINE, 1.0)
		_t(ci, f_mono, cells[i][0], x + ws[i] / 2.0, y0 + 6, 10, STEEL, "center", false); _t(ci, f_mono, cells[i][1], x + ws[i] / 2.0, y0 + 20, 18, cells[i][2], "center", false); x += ws[i]
	var y := y0 + h + 3.0
	var bar := [clampf(float(done) / maxf(1.0, g.goal), 0.0, 1.0), SODIUM] if g.tm == null else g.tm.mode.hud_bar()
	ci.draw_rect(Rect2(x0, y, total, 4), Color(INK, 0.14)); ci.draw_rect(Rect2(x0, y, total * clampf(float(bar[0]), 0.0, 1.0), 4), bar[1]); y += 7.0
	var pop_y := y
	# the safari: the time to the stampede, then how many are left. the lab: the next cage and its countdown
	var sf: Safari = m.world.safari; var lab: Lab = m.world.lab; var lb := ""; var txt := ""; var sec := ""; var soon := false
	if sf != null and not g.ended:
		var L := sf.left(); var cs := ceili(L)
		lb = "습격 중" if sf.stampede else "습격까지"; txt = "남은 동물" if sf.stampede else "동물 %d마리가 감시탑으로" % g.goal
		sec = ("%d마리" % (g.goal - g.kills - g.calm)) if sf.stampede else "%d:%02d" % [cs / 60, cs % 60]; soon = not sf.stampede and L <= 30.0
	elif lab != null and lab.running:
		var nc = lab.next_cage()
		if nc != null:
			var alive := 0
			for e in nc.animals:
				if e.alive: alive += 1
			lb = "다음 우리"; txt = "%d번 · %s" % [nc.n, ("보스 " + Game.BOSS[3].name) if nc.boss else "%s %d마리" % [Animals.ANIMALS[nc.type].name, alive]]
			sec = (("버튼을 누르는 중" if lab.reach == nc else "앞 우리 %d마리 남음" % mini(99, lab.wait_left(nc))) if nc.held else "%d초" % ceili(maxf(0.0, nc.open_at - lab.t)))
			soon = not nc.held and nc.open_at - lab.t <= 3.0
	var lines: Array = [[lb, txt, sec, soon]] if lb != "" else []
	if g.tm != null and not g.ended: lines = g.tm.mode.hud_lines()
	for L: Array in lines:
		y += 4.0; var lx := _t(ci, f_mono, L[0], x0, y + 5, 10, SODIUM); var tx := _t(ci, f_bold, L[1], x0 + lx + 8, y + 1, 13, INK)
		var pulse := 1.0 + (0.06 * (0.5 + 0.5 * sin(m.time * PI / 0.35)) if L[3] else 0.0)
		_t(ci, f_mono, L[2], x0 + lx + tx + 16, y - 2, int(18 * pulse), ALARM if L[3] else SODIUM); y += 22.0
	var an: Animals = m.enemies.animals
	if an.bleed_t > 0.0:   # bleeding: how many wounds and how long they keep going
		y += 4.0; var bt := "출혈 ×%d" % an.bleed_n; var bw := _w(f_bold, bt, 12) + 10.0
		ci.draw_rect(Rect2(x0, y, bw, 17), Color("c8242f")); _t(ci, f_bold, bt, x0 + 5, y + 1, 12, Color.WHITE, "left", false)
		_t(ci, f_bold, "%d초 · 초당 %d" % [ceili(an.bleed_t), int(Animals.BLEED_DPS * an.bleed_n)], x0 + bw + 5, y + 1, 12, Color("ff8a8a")); y += 17.0
	# the boss, once it has noticed you (4-2's, the gold commander: the bee)
	var B: Enemies.Foe = g.boss
	if g.mid != null and g.mid.alive and g.mid.alert and (B == null or not B.alive or not B.alert or g.mid.dist < B.dist): B = g.mid
	if B != null and B.alive and (B.alert or B.angry or B.hp < B.max_hp) and B.dist < 110.0:
		y += 4.0; var nm := "보스 · " + B.name + (" · %d페이즈" % (int(B.k.phase) + 1) if (B.type == "bdrone" and B.k.has("phase")) else "")
		var nw := _t(ci, f_title, nm, x0, y, 13, Color("ffb3a8")); var bx := x0 + nw + 8.0; var bwid := maxf(120.0, x0 + total - bx)
		ci.draw_rect(Rect2(bx, y + 4, bwid, 7), Color(NIGHT, 0.7)); ci.draw_rect(Rect2(bx, y + 4, bwid * clampf(B.hp / B.max_hp, 0.0, 1.0), 7), ALARM); ci.draw_rect(Rect2(bx, y + 4, bwid, 7), Color(ALARM, 0.5), false, 1.0); y += 18.0
	for p: Array in pops:   # money from a kill drops out under the box and fades
		var k: float = p[1] / 1.2; _t(ci, f_mono, p[0], x0 + total - 4, pop_y + 6 + 24.0 * k, 13, Color(SODIUM, 1.0 - k), "right")

## kill lines: top right (top left after the pause button on a phone), the newest on top, fading after 2.4 s
func _feed(ci, s: Vector2, touch: bool, f_body: Font, f_mono: Font) -> void:
	var y := 14.0; var fs := 12 if touch else 13
	for L: Array in feed:
		var a := 1.0 - clampf((float(L[2]) - 2.4) / 0.45, 0.0, 1.0); var tw := _w(f_body, L[0], fs); var mw := (_w(f_mono, "+" + Store.won(L[1]), fs) + 8.0) if int(L[1]) > 0 else 0.0
		var w := tw + mw + 20.0; var x := 70.0 if touch else s.x - 16.0 - w; var r := Rect2(x, y, w, fs + 12.0)
		ci.draw_rect(r, Color(PANEL, PANEL.a * a)); var edge := Color(ALARM if L[3] else SODIUM, a)
		ci.draw_rect(Rect2(x if touch else x + w - 3.0, y, 3, r.size.y), edge)
		_t(ci, f_body, L[0], x + 10 + (3 if touch else 0), y + 4, fs, Color(INK, a), "left", false)
		if mw > 0.0: _t(ci, f_mono, "+" + Store.won(L[1]), x + 10 + tw + 8 + (3 if touch else 0), y + 4, fs, Color(SODIUM, a), "left", false)
		y += r.size.y + 4.0

## the animal under you and the safari's watchtower: tall red bars on the right
func _vbars(ci, s: Vector2, g: Game, pl: Player, f_title: Font, f_bold: Font) -> void:
	var an: Animals = m.enemies.animals; var sf: Safari = m.world.safari; var bars := []
	if an.m != null: bars.push_back([str(Animals.SEAT[an.m.type].name) + ("\n출혈 ×%d" % an.m.bleed_n if an.m.bleed_t > 0.0 else ""), an.m.hp, an.m.max_hp])
	if sf != null and sf.standing and not g.ended: bars.push_back(["감시탑\n탑 위" if sf.on else "감시탑", sf.hp, Safari.TOWER.hp])
	var x := s.x - 18.0
	for b: Array in bars:
		var f: float = clampf(float(b[1]) / float(b[2]), 0.0, 1.0); var cxm := x - 32.0; var top := s.y * 0.2; var bottom := s.y * 0.7
		var num := Store.won(maxi(0, ceili(b[1]))).trim_suffix("원"); _t(ci, f_title, num, cxm, top, 30, Color("ff6b62"), "center")
		var lines: PackedStringArray = str(b[0]).split("\n"); var lh := 17.0 * lines.size()
		var r := Rect2(cxm - 15, top + 36, 30, maxf(80.0, bottom - top - 36 - 6 - lh))
		ci.draw_rect(r, Color(NIGHT, 0.75)); ci.draw_rect(r, Color(1, 98 / 255.0, 88 / 255.0, 0.7), false, 2.0)
		var low := f < 0.25; var pulse := (0.85 + 0.15 * sin(m.time * PI / 0.4)) if low else 1.0
		var fh := (r.size.y - 6.0) * f; ci.draw_rect(Rect2(r.position.x + 3, r.end.y - 3 - fh, 24, fh), Color(Color("ff7a6e").lerp(Color("d6261c"), 0.5), pulse))
		for i in lines.size(): _t(ci, f_bold, lines[i], cxm, r.end.y + 6 + i * 17, 13, INK, "center")
		x -= 64.0 + 16.0

## g: the game, for what only a stage gives you (stage 6's alchemist's bomb: ready, or the seconds until it is)
func _items(touch: bool, g: Game = null) -> Array:
	var it: Dictionary = Store.save.items; var chips := []
	if Store.settings.dev and Store.settings.god: chips.push_back(["무적 · 개발자 모드", "jet"])
	if g != null and g.has_flask(): chips.push_back([("연금술 폭탄 준비" if touch else "연금술 폭탄 · G") if g.flask_cd <= 0.0 else "연금술 폭탄 %d초" % ceili(g.flask_cd), "jet" if g.flask_cd <= 0.0 else ""])
	if int(it.helmet) > 0: chips.push_back(["헬멧", ""])
	if int(it.vest) > 0: chips.push_back(["조끼 %d/10" % int(it.vest), "low" if int(it.vest) <= 3 else ""])
	if int(it.jet) > 0: chips.push_back(["제트팩 · 점프 두 번" if touch else "제트팩 · Space 두 번", "jet"])
	if int(it.ivory) > 0: chips.push_back(["상아 %d" % int(it.ivory), ""])
	return chips

func _status(pl: Player, g: Game, touch: bool) -> String:
	if g.tm != null and pl.out and not g.ended: return g.tm.mode.status() if pl.held else ("장난감 상자 안 · %d초 뒤 다시 출동" % ceili(g.tm.down_t) if g.tm.down_why == "box" else "쓰러짐 · %d초 뒤 다시 출동" % ceili(g.tm.down_t))
	if pl.stun_t > 0.0: return "기절 %.1f" % pl.stun_t
	if pl.fear_t > 0.0: return "공포 %.1f" % pl.fear_t
	if pl.toss_on: return "공중으로 날아가는 중"
	if g.inject_on: return "해독약 주사 중"
	if pl.jet_on: return "제트백팩 %.1f초" % maxf(0.0, pl.jet_t) + ("" if touch else " · Space 위로 · Ctrl(C) 아래로")
	if g.tm != null and not g.ended: return g.tm.mode.status()
	return ""

## where hits came from: a red arc round the crosshair, turned towards it, fading over a second
func _dmgdir(ci, c: Vector2, pl: Player) -> void:
	var sy := sin(pl.yaw); var cy := cos(pl.yaw)
	for A in arcs:
		if A[0] <= 0.0: continue
		var fr: Vector3 = A[1]; var dx := fr.x - pl.pos.x; var dz := fr.z - pl.pos.z; var rot := atan2(dx * cy - dz * sy, -dx * sy - dz * cy)
		var col := Color(ALARM, clampf(A[0], 0.0, 1.0))
		ci.draw_arc(c, 68.0, -PI / 2.0 - PI / 4.0 + rot, -PI / 2.0 + PI / 4.0 + rot, 24, Color(col, col.a * 0.35), 9.0)
		ci.draw_arc(c, 68.0, -PI / 2.0 - PI / 4.0 + rot, -PI / 2.0 + PI / 4.0 + rot, 24, col, 4.0)

## arrows round the crosshair: to the chest you have to open, or (with ten or fewer left) to the nearest three enemies; on the ship
## only in 4-1 (cleared when every robot of its corridor is down: the last ones found this way)
func aims(g: Game) -> Array:
	var out := []
	if g.tm != null: return [] if (g.ended or m.player.out) else g.tm.mode.aims()   # stage 5's team modes: batteries, home, the train, traps
	if g.rm != null: return []   # (a realm battle marks its own things over the view)
	var chest = m.loot.pending() if g._chest_wait else null
	if chest != null: out.push_back([Vector2(chest.x, chest.z), 0.95])
	else:
		var left := g.goal - g.kills - g.calm
		if left > 0 and left <= 10 and not g.ended and Store.ship(g.stage) in ["", "corr"]:
			var near: Array = m.enemies.list.filter(func(e): return e.alive and not e.tamed and not e.extra)
			near.sort_custom(func(a, b): return a.dist < b.dist)
			for i in mini(3, near.size()): out.push_back([Vector2(near[i].pos.x, near[i].pos.z), 0.95 if i == 0 else 0.55])
	return out

func _targets(ci, c: Vector2, g: Game, pl: Player) -> void:
	var sy := sin(pl.yaw); var cy := cos(pl.yaw)
	for a in aims(g):
		var p: Vector2 = a[0]; var dx := p.x - pl.pos.x; var dz := p.y - pl.pos.z; var rot := atan2(dx * cy - dz * sy, -dx * sy - dz * cy)
		var tri := PackedVector2Array([Vector2(0, -96), Vector2(7, -83), Vector2(-7, -83)])
		for i in 3: tri[i] = c + tri[i].rotated(rot)
		ci.draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(1, 1.5), tri[1] + Vector2(1, 1.5), tri[2] + Vector2(1, 1.5)]), Color(0, 0, 0, 0.5 * a[1]))
		ci.draw_colored_polygon(tri, Color(a[2] if a.size() > 2 else SODIUM, a[1]))

## stage 5's team modes: a little blue mark over each of our soldiers in view (a battery over one carrying), a red battery over
## theirs that carry one
func _friends(ci, g: Game) -> void:
	var cam: Camera3D = m.cam; var T: ToyMatch = g.tm
	var room := Rect2(Vector2(-200, -200), ci.size + Vector2(400, 400))   # (a mark right by the lens projects to nowhere: none drawn there)
	for a in T.allies:
		if not a.alive or bool(a.k.get("gone", false)): continue
		var top: Vector3 = a.pos + Vector3(0, a.H + 0.6, 0)
		if cam.is_position_behind(top) or top.distance_to(cam.global_position) > 80.0: continue
		var p := cam.unproject_position(top); var col := Color("5f9cff")
		if not p.is_finite() or not room.has_point(p): continue
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -8), p + Vector2(6, -8), p + Vector2(0, 0)]), col)
		if a.k.carrying != null: ci.draw_rect(Rect2(p.x - 4, p.y - 22, 8, 12), Color("ffd23a"))
	for e in m.enemies.list:
		if not e.alive or not e.k.has("team") or e.k.get("carrying") == null: continue
		var top2: Vector3 = e.pos + Vector3(0, e.H + 0.9, 0)
		if cam.is_position_behind(top2): continue
		var q := cam.unproject_position(top2)
		if not q.is_finite() or not room.has_point(q): continue
		ci.draw_rect(Rect2(q.x - 5, q.y - 16, 10, 14), Color("ff5260")); ci.draw_rect(Rect2(q.x - 2, q.y - 19, 4, 3), Color("ff5260"))

## the rocket launcher's lock: a turning red diamond on the enemy the next rocket would chase
func _lock(ci, s: Vector2, W: Dictionary, guns: Guns, st: Dictionary) -> void:
	if not W.get("rocket", false) or int(st.mag) <= 0 or guns.reload_t > 0.0 or m.state != "playing": lock_e = null; return
	lock_t -= m.get_process_delta_time()
	if lock_t <= 0.0: lock_t = 0.1; lock_e = guns.rocket_lock()
	if lock_e == null or not lock_e.alive: return
	var cam: Camera3D = m.cam; var at: Vector3 = m.proj.rocket_centre(lock_e)
	if cam.is_position_behind(at): return
	var p := cam.unproject_position(at)
	if p.x < -0.05 * s.x or p.x > 1.05 * s.x or p.y < -0.05 * s.y or p.y > 1.05 * s.y: return
	var spin := fmod(m.time, 1.2) / 1.2 * TAU; var pts := PackedVector2Array()
	for i in 5: pts.push_back(p + Vector2(20.0 * sqrt(2.0), 0).rotated(spin + PI / 4.0 + i * PI / 2.0))
	ci.draw_polyline(pts, Color(1, 70 / 255.0, 50 / 255.0, 0.35), 6.0); ci.draw_polyline(pts, Color("ff4b3a"), 2.0)
	_t(ci, m.f_mono, "LOCK", p.x + 26, p.y - 30, 11, Color("ff6b5a"))

func _scope_and_cross(ci, s: Vector2, c: Vector2, W: Dictionary, guns: Guns, pl: Player) -> void:
	var ink := Color(str(Store.settings.crossColor)); ink.a = 0.9
	if guns.scoped():   # through the scope: black all round a circle, a fine cross
		var r := minf(s.x, s.y) * 0.42
		ci.draw_arc(c, r + s.length(), 0, TAU, 96, Color.BLACK, s.length() * 2.0); ci.draw_arc(c, r, 0, TAU, 96, Color.BLACK, 4.0)
		ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.85), 1.0); ci.draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.85), 1.0); return
	if guns.none: return
	# the gap: the spread itself, as it falls on the screen
	var fov_r := deg_to_rad(m.cam.fov) / 2.0; var gap := roundf(tan(guns.current_spread()) / tan(fov_r) * s.y / 2.0 + 4.0)
	var co := (1.0 - guns.ads) * (1.0 - pl.sprint_blend); ink.a *= co
	if co > 0.01 and m.game.stage == Store.ST_TOY: toy.cross(ci, c, gap, ink, guns.cur)   # (the toy room: each toy its own)
	elif co > 0.01:
		match str(Store.settings.cross):
			"circle": ci.draw_arc(c, maxf(gap + 2.0, 9.0), 0, TAU, 40, ink, 1.5); ci.draw_circle(c, 1.5, ink)
			"big": ci.draw_arc(c, maxf(gap + 24.0, 40.0), 0, TAU, 56, ink, 2.0); ci.draw_circle(c, 1.5, ink)
			"dot": ci.draw_circle(c, 2.5, ink)
			_:
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: ci.draw_line(c + d * gap, c + d * (gap + 9.0), ink, 2.0)
				ci.draw_circle(c, 1.5, ink)
	if guns.ads > 0.6 and not W.get("scope", false): ci.draw_circle(c, 6.0, Color(1, 70 / 255.0, 50 / 255.0, 0.35)); ci.draw_circle(c, 3.0, Color("ff4b3a"))   # aiming down the sights: a red dot

## running with the SMG: green streaks rushing out past the edges, a faint green round the rim
func _wind(ci, s: Vector2, c: Vector2) -> void:
	if wind_k < 0.012: return
	_glow(ci, "wind", wind_k)
	var R := c.length()
	for p in wind:
		var fade := clampf((p.r - 0.44) / 0.18, 0.0, 1.0) * clampf((1.15 - p.r) / 0.25, 0.0, 1.0)
		if fade <= 0.0: continue
		var d := Vector2(cos(p.a), sin(p.a))
		ci.draw_polyline_colors(PackedVector2Array([c + d * p.r * R, c + d * (p.r + p.l) * R]), PackedColorArray([Color(140 / 255.0, 1, 180 / 255.0, 0), Color(140 / 255.0, 1, 180 / 255.0, 0.85 * wind_k * fade)]), p.wd * (0.7 + wind_k * 0.7))
