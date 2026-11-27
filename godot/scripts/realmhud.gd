class_name RealmHud
extends RefCounted
## A realm battle's screen: the match at the top (the sanctum's two gauges, or the siege's clock, wards and nucleus) with
## the two sides' rosters beside it; your health, shield and people at the bottom left; your weapon at the bottom right
## (rounds, or the sword's three blows, or the staff's heat); what you can do and how soon along the bottom; over the
## view, your people's own crosshair, the marks of hits, the foes shown to you, and the screen's own moments.

const BLUE := Color("5f9cff"); const RED := Color("ff5260"); const GOLD := Color("ffd66b"); const VIOLET := Color("b892ff"); const CYAN := Color("8ff7ea")
const INITIAL := {"elf": "엘", "dwarf": "드", "orc": "오", "demon": "악"}
const BOMB_SHORT := {"oil": "기름", "gravity": "중력", "smoke": "연막"}
const ALT := {"elf": "차징 사격", "dwarf": "연금술 유탄", "orc": "사슬 도끼", "demon": "흡수 광선"}

var h: Hud
var veil: ColorRect = null

func draw(hud: Hud, ci, s: Vector2, c: Vector2, touch: bool) -> void:
	h = hud; var rm: Realm = h.m.game.rm; var f := rm.me
	if f == null: return
	_veils(ci, s, c, rm, f)
	_marks(ci, rm, f)
	if f.alive: _cross(ci, s, c, rm, f)
	_hits(ci, c, rm)
	_top(ci, s, c, rm)
	h._feed(ci, s, touch, h.m.f_body, h.m.f_mono)
	_vitals(ci, s, touch, rm, f)
	_weapon(ci, s, touch, rm, f)
	if not touch: _chips(ci, s, c, rm, f)
	_prompt(ci, s, c, touch, rm, f)

# ---------------- over the view ----------------
func _veils(ci, s: Vector2, c: Vector2, rm: Realm, f: Realm.Fighter) -> void:
	var t: float = h.m.time
	if f.alive and h.m.cam != null and rm.kit.in_smoke(h.m.cam.global_position): ci.draw_rect(Rect2(Vector2.ZERO, s), Color(0.42, 0.28, 0.66, 0.62))   # in the smoke: little to see
	if f.alive and f.race == "orc" and f.ult_t > 0.0: h._glow(ci, "hurt", 0.55 + 0.3 * sin(t * 9.0))   # the warlord's red, beating
	if f.alive and f.race == "demon" and f.ult_t > 0.0: h._glow(ci, "low", 0.5 + 0.2 * sin(t * 5.0))
	if f.alive and f.burn_t > 0.0: h._glow(ci, "hurt", 0.35)
	if not f.alive: h._glow(ci, "down", 1.0)
	if rm.flash.has("parry"):
		var a := float(rm.flash.parry) / 0.25; ci.draw_arc(c, 30.0 + (1.0 - a) * 60.0, 0.0, TAU, 40, Color(0.9, 0.97, 1.0, a), 3.0)
	# the dagger's finishing blow: for a moment the view is black and white, turned inside out
	var on := rm.flash.has("execute")
	if on and veil == null and ci is Control:
		veil = ColorRect.new(); veil.set_anchors_preset(Control.PRESET_FULL_RECT); veil.mouse_filter = Control.MOUSE_FILTER_IGNORE; veil.show_behind_parent = true
		var sh := Shader.new(); sh.code = "shader_type canvas_item;\nuniform sampler2D screen : hint_screen_texture, filter_linear;\nvoid fragment() { vec3 c = texture(screen, SCREEN_UV).rgb; float l = dot(c, vec3(0.299, 0.587, 0.114)); COLOR = vec4(vec3(1.0 - l), 1.0); }"
		var sm := ShaderMaterial.new(); sm.shader = sh; veil.material = sm; (ci as Control).add_child(veil)
	if veil != null and is_instance_valid(veil): veil.visible = on

## your side over their heads, the foes shown to you through whatever stands between, what the match is about
func _marks(ci, rm: Realm, f: Realm.Fighter) -> void:
	var cam: Camera3D = h.m.cam
	if cam == null: return
	var room := Rect2(Vector2(-200, -200), ci.size + Vector2(400, 400)); var fm: Font = h.m.f_mono
	for o: Realm.Fighter in rm.all:
		if o.me or not o.alive: continue
		var top := o.pos + Vector3(0, o.H + 0.75, 0)
		if cam.is_position_behind(top): continue
		var p := cam.unproject_position(top)
		if not p.is_finite() or not room.has_point(p): continue
		if o.team == f.team:
			if top.distance_to(cam.global_position) < 90.0: ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -8), p + Vector2(6, -8), p + Vector2(0, 0)]), BLUE)
			if o.carrying: ci.draw_rect(Rect2(p.x - 4, p.y - 22, 8, 12), Color("ff9a3a"))
		else:
			if o.mark_t > 0.0:   # shown: a violet diamond on him, whatever is in the way
				var q := cam.unproject_position(o.feet_mid())
				ci.draw_polyline(PackedVector2Array([q + Vector2(0, -13), q + Vector2(10, 0), q + Vector2(0, 13), q + Vector2(-10, 0), q + Vector2(0, -13)]), VIOLET, 2.0)
			if o.carrying: ci.draw_rect(Rect2(p.x - 5, p.y - 16, 10, 14), RED)
	for q: Dictionary in rm.mode.marks():
		var at: Vector3 = q.at
		if cam.is_position_behind(at): continue
		var p := cam.unproject_position(at)
		if not p.is_finite() or not room.has_point(p): continue
		var col := Color(str(q.c)); var d := at.distance_to(cam.global_position)
		ci.draw_polyline(PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 0), p + Vector2(0, 8), p + Vector2(-7, 0), p + Vector2(0, -8)]), col, 2.0)
		h._t(ci, fm, "%s %dm" % [str(q.label), int(d)], p.x, p.y + 10, 10, col, "center")

func _cross(ci, s: Vector2, c: Vector2, rm: Realm, f: Realm.Fighter) -> void:
	var ink := Color(str(Store.settings.get("crossColor", "ece6d8"))); var t: float = h.m.time
	match f.race:
		"elf":
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: ci.draw_line(c + d * 5.0, c + d * 12.0, ink, 1.5)
			if f.charge > 0.0:   # the heavy shot drawn: a ring that closes, gold when it is full
				var q := minf(1.0, f.charge / float(Races.XBOW.charge))
				ci.draw_arc(c, 18.0, -PI / 2.0, -PI / 2.0 + TAU * q, 32, GOLD if f.charged else CYAN, 2.5)
			if f.gauge >= float(Races.GAUGE.max):   # the star rain ready: a little constellation about the mark
				for i in 5: var a := i * TAU / 5.0 + t * 0.6; ci.draw_circle(c + Vector2(cos(a), sin(a)) * 26.0, 1.6, VIOLET)
		"dwarf":
			var fov := deg_to_rad(h.m.cam.fov) if h.m.cam != null else 1.2
			var r := maxf(10.0, tan(float(Races.CANNON.spread)) * (s.y * 0.5) / tan(fov * 0.5))
			ci.draw_arc(c, r, 0.0, TAU, 36, ink, 1.5); ci.draw_circle(c, 1.6, ink)
		"orc":
			for sg: float in [-1.0, 1.0]: ci.draw_polyline(PackedVector2Array([c + Vector2(sg * 16, -9), c + Vector2(sg * 9, 0), c + Vector2(sg * 16, 9)]), ink, 2.0)
			for i in 3: ci.draw_circle(c + Vector2((i - 1) * 9.0, 22.0), 3.0, SODIUM_if(i < f.combo or (i == f.combo and f.swing_t > 0.0)))
		"demon":
			ci.draw_circle(c, 1.8, ink); ci.draw_arc(c, 9.0, 0.0, TAU, 24, Color(ink, 0.5), 1.0)
			var crit := float(Races.RUNE.core_crit) if f.rune("dm_core") else float(Races.STAFF.crit)
			var a0 := deg_to_rad(20.0); var a1 := deg_to_rad(160.0); var q := clampf(f.heat / 100.0, 0.0, 1.0)   # the heat: an arc under the mark
			ci.draw_arc(c, 24.0, a0, a1, 24, Color(0.9, 0.9, 0.9, 0.2), 3.0)
			var hot := f.heat >= crit; var col := Color(1.0, 0.25, 0.1) if hot else Color(1.0, 0.65, 0.2)
			if f.ult_t > 0.0: ci.draw_arc(c, 24.0, 0.0, TAU, 40, Color(1.0, 0.35, 0.1, 0.7 + 0.3 * sin(t * 14.0)), 3.0)   # the furnace: a ring of fire, shut
			elif f.seal_t > 0.0: ci.draw_arc(c, 24.0, a0, a1, 24, Color(0.6, 0.6, 0.7, 0.9), 3.0)
			elif q > 0.0 and (f.heat < 95.0 or fmod(t, 0.2) < 0.12): ci.draw_arc(c, 24.0, a1 - (a1 - a0) * q, a1, 24, col, 3.0)
			var ac := a1 - (a1 - a0) * crit / 100.0; ci.draw_line(c + Vector2(cos(ac), sin(ac)) * 20.0, c + Vector2(cos(ac), sin(ac)) * 28.0, Color.WHITE, 1.5)

func SODIUM_if(on: bool) -> Color: return Hud.SODIUM if on else Color(0.9, 0.9, 0.9, 0.25)

## hits: a white cross; a head: a gold diamond bursting apart and a violet glow that lingers a moment
func _hits(ci, c: Vector2, rm: Realm) -> void:
	for q: Dictionary in rm.marks:
		var t := float(q.t)
		if bool(q.head):
			if t < 0.15: ci.draw_circle(c, 26.0, Color(0.7, 0.5, 1.0, 0.28 * (1.0 - t / 0.15)))
			if t < 0.35:
				var a := 1.0 - t / 0.35; var o := 6.0 + t * 90.0
				for d: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
					var p := c + d * o; var x := Vector2(-d.y, d.x)
					ci.draw_colored_polygon(PackedVector2Array([p + d * 7.0, p + x * 5.0, p - d * 3.0, p - x * 5.0]), Color(GOLD, a))
		elif t < 0.25:
			var a := 1.0 - t / 0.25; var col := Color(CYAN if q.get("thing", false) else Color.WHITE, a); var sc := clampf(0.8 + float(q.dmg) / 90.0, 0.8, 1.7)
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: ci.draw_line(c + d.normalized() * 3.0 * sc, c + d.normalized() * 14.0 * sc, col, 2.0)

# ---------------- the match, at the top ----------------
func _top(ci, s: Vector2, c: Vector2, rm: Realm) -> void:
	var H := rm.mode.hud(); var fm: Font = h.m.f_mono; var fb: Font = h.m.f_bold
	var w := minf(380.0, s.x * 0.5); var x0 := c.x - w / 2.0; var y0 := 12.0; var hh := 74.0
	h._panel(ci, Rect2(x0, y0, w, hh))
	h._t(ci, fm, str(H.get("title", "")), c.x, y0 + 5, 11, Hud.STEEL, "center", false)
	if H.has("us"):   # the sanctum: the two gauges, a tick at the half, the rounds won as pips
		for i in 2:
			var team := "us" if i == 0 else "them"; var col := BLUE if i == 0 else RED; var by := y0 + 24.0 + i * 15.0; var bx := x0 + 46.0; var bw := w - 110.0
			var v := clampf(float(H[team]) / 100.0, 0.0, 1.0)
			h._t(ci, fm, "우리" if i == 0 else "적", x0 + 10, by - 3, 11, col, "left", false)
			ci.draw_rect(Rect2(bx, by, bw, 9), Color(1, 1, 1, 0.1)); ci.draw_rect(Rect2(bx, by, bw * v, 9), col)
			ci.draw_line(Vector2(bx + bw * float(H.mark) / 100.0, by - 1), Vector2(bx + bw * float(H.mark) / 100.0, by + 10), Color(1, 1, 1, 0.6), 1.0)
			h._t(ci, fm, "%d%%" % int(float(H[team])), bx + bw + 6, by - 3, 11, Hud.INK, "left", false)
			for k in 2: ci.draw_circle(Vector2(x0 + w - 22.0 + k * 11.0, by + 4.5), 3.5, col if int(H.wins[team]) > k else Color(1, 1, 1, 0.16))
	else:   # the siege: the clock, the two wards, and once it is open the nucleus under its shield
		var tl := float(H.get("clock", 0.0)); h._t(ci, fm, "%d:%02d" % [int(tl) / 60, int(tl) % 60], x0 + 12, y0 + 22, 20, Hud.ALARM if tl < 30.0 else Hud.INK, "left", false)
		var wd: Dictionary = H.get("wards", {})
		for i in 2:
			var k := "a" if i == 0 else "b"; var px := x0 + 96.0 + i * 46.0; var up: bool = wd.get(k, false)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(px, y0 + 24), Vector2(px + 8, y0 + 34), Vector2(px, y0 + 44), Vector2(px - 8, y0 + 34)]), GOLD if up else Color(1, 1, 1, 0.14))
			h._t(ci, fb, k.to_upper(), px + 12, y0 + 26, 13, Hud.INK if up else Hud.STEEL, "left", false)
		if H.has("nuc"):
			var bx := x0 + 196.0; var bw := w - 208.0
			ci.draw_rect(Rect2(bx, y0 + 26, bw, 7), Color(1, 1, 1, 0.1)); ci.draw_rect(Rect2(bx, y0 + 26, bw * clampf(float(H.nuc_shield), 0.0, 1.0), 7), CYAN)
			ci.draw_rect(Rect2(bx, y0 + 36, bw, 9), Color(1, 1, 1, 0.1)); ci.draw_rect(Rect2(bx, y0 + 36, bw * clampf(float(H.nuc), 0.0, 1.0), 9), VIOLET)
		elif float(H.get("fuse", 0.0)) > 0.0:
			var bx := x0 + 196.0; var bw := w - 208.0
			ci.draw_rect(Rect2(bx, y0 + 28, bw, 9), Color(1, 1, 1, 0.1)); ci.draw_rect(Rect2(bx, y0 + 28, bw * float(H.fuse) / ModeSiege.FUSE, 9), Color("ff9a3a"))
			if float(H.get("cut", 0.0)) > 0.0: ci.draw_rect(Rect2(bx, y0 + 40, bw * clampf(float(H.cut), 0.0, 1.0), 5), CYAN)
	h._t(ci, fm, str(H.get("sub", "")), c.x, y0 + hh - 17, 12, Hud.SODIUM, "center", false)
	# the two sides: each one's people, dimmed while he is down (with the seconds till he is back)
	for i in 2:
		var team := "us" if i == 0 else "them"; var list := rm.team_of(team); var col := BLUE if i == 0 else RED
		for k in list.size():
			var o: Realm.Fighter = list[k]; var bx := (x0 - 8.0 - (k + 1) * 26.0) if i == 0 else (x0 + w + 8.0 + k * 26.0)
			if bx < 4.0 or bx > s.x - 28.0: continue
			var r := Rect2(bx, y0, 22, 22)
			ci.draw_rect(r, Color(col, 0.75 if o.alive else 0.16)); ci.draw_rect(r, Color.WHITE if o.me else Color(col, 0.9), false, 1.5 if o.me else 1.0)
			h._t(ci, fb, str(INITIAL[o.race]), bx + 11, y0 + 3, 12, Hud.NIGHT if o.alive else Hud.STEEL, "center", false)
			if o.alive: ci.draw_rect(Rect2(bx, y0 + 24, 22.0 * clampf(o.hp / o.max_hp, 0.0, 1.0), 3), col)
			else: h._t(ci, fm, str(ceili(o.back_t)), bx + 11, y0 + 24, 10, Hud.STEEL, "center", false)
			if o.gauge >= float(Races.GAUGE.max) and o.alive and i == 0: ci.draw_circle(Vector2(bx + 19, y0 + 3), 2.6, GOLD)

# ---------------- you, at the bottom left ----------------
func _vitals(ci, s: Vector2, touch: bool, rm: Realm, f: Realm.Fighter) -> void:
	var fm: Font = h.m.f_mono; var fb: Font = h.m.f_bold
	var bottom := 12.0 if touch else 18.0; var vw := minf(200.0, s.x * 0.4) if touch else minf(280.0, s.x * 0.42); var vx := 16.0
	var by := s.y - bottom - 30.0; var y0 := by - 6.0 - 34.0
	var hw: float = h._t(ci, fm, str(ceili(maxf(0.0, f.hp))), vx, y0, 34, Hud.INK)
	h._t(ci, fm, "/ %d · %s" % [int(f.max_hp), str(Races.R[f.race].name)], vx + hw + 10, y0 + 18, 11, Hud.STEEL)
	var full := f.max_hp + maxf(f.shield, 0.0) + maxf(f.over, 0.0); var q := clampf(f.hp / full, 0.0, 1.0); var pct := f.hp / f.max_hp
	ci.draw_rect(Rect2(vx, by, vw, 8), Color(233 / 255.0, 228 / 255.0, 216 / 255.0, 0.12))
	ci.draw_rect(Rect2(vx, by, vw * q, 8), Hud.VITAL if pct > 0.5 else (Hud.SODIUM if pct > 0.25 else Hud.ALARM))
	var x := vx + vw * q
	if f.over > 0.0: var ow := vw * f.over / full; ci.draw_rect(Rect2(x, by, ow, 8), GOLD); x += ow
	if f.shield > 0.0: ci.draw_rect(Rect2(x, by, vw * f.shield / full, 8), Color("e8f4ff"))
	ci.draw_rect(Rect2(vx, by, vw, 8), Hud.LINE, false, 1.0)
	# what is on you, as chips under the bar
	var chips: Array = []
	if f.shield > 0.5: chips.push_back(["보호막 %d" % int(f.shield), Color("e8f4ff")])
	if f.over > 0.5: chips.push_back(["광폭화 %.0f초" % f.ult_t, GOLD])
	if f.stacks > 0: chips.push_back(["피의 갈증 ×%d" % f.stacks, RED])
	if rm.critical(f): chips.push_back(["임계 · 이동 +12%", Color(1.0, 0.45, 0.15)])
	if f.burn_t > 0.0: chips.push_back(["화상", Color(1.0, 0.5, 0.15)])
	if not f.slows.is_empty() and not rm.unstoppable(f): chips.push_back(["둔화", CYAN])
	if f.haste_t > 0.0 or f.ley_t > 0.0: chips.push_back(["가속", Hud.VITAL])
	if f.mark_t > 0.0: chips.push_back(["드러남", VIOLET])
	if f.inv > 0.0: chips.push_back(["무적", Color.WHITE])
	if f.carrying: chips.push_back(["폭탄 운반", Color("ff9a3a")])
	var cx := vx
	for it: Array in chips:
		var tw: float = h._w(fb, it[0], 11) + 14.0
		h._panel(ci, Rect2(cx, by + 12, tw, 18), Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.55), Color(it[1] as Color, 0.6)); h._t(ci, fb, it[0], cx + 7, by + 13, 11, it[1], "left", false); cx += tw + 5.0

# ---------------- your weapon, at the bottom right ----------------
func _weapon(ci, s: Vector2, touch: bool, rm: Realm, f: Realm.Fighter) -> void:
	var fm: Font = h.m.f_mono; var ft: Font = h.m.f_title
	var ax := s.x - 16.0; var ay := s.y - (12.0 if touch else 18.0)
	if touch: ay -= 296.0; ax = s.x - 16.0   # (a phone: above the round buttons)
	h._t(ci, ft, str(Races.R[f.race].weapon), ax, ay - 68, 18, Hud.SODIUM, "right")
	match f.race:
		"elf", "dwarf":
			var W: Dictionary = Races.WEAPON[f.race]; var mag := rm.kit.mag(f)
			var res := "/ %d" % mag; var rw: float = h._w(fm, res, 18)
			h._t(ci, fm, res, ax, ay - 22, 18, Hud.STEEL, "right"); h._t(ci, fm, str(f.ammo), ax - rw - 8, ay - 40, 40, Hud.ALARM if f.ammo <= mag / 4 else Hud.INK, "right")
			if f.reload_t > 0.0:
				ci.draw_rect(Rect2(ax - 120, ay - 46, 120, 4), Color(1, 1, 1, 0.15)); ci.draw_rect(Rect2(ax - 120, ay - 46, 120.0 * (1.0 - f.reload_t / float(W.reload)), 4), Hud.SODIUM)
		"orc":
			for i in 3:
				var on := i < f.combo or (i == f.combo and f.swing_t > 0.0)
				ci.draw_rect(Rect2(ax - 96.0 + i * 34.0, ay - 30, 28, 12), Hud.SODIUM if on else Color(1, 1, 1, 0.14)); ci.draw_rect(Rect2(ax - 96.0 + i * 34.0, ay - 30, 28, 12), Hud.LINE, false, 1.0)
			h._t(ci, fm, "3연격 · 3타에 검기", ax, ay - 14, 11, Hud.STEEL, "right")
		"demon":
			var crit := float(Races.RUNE.core_crit) if f.rune("dm_core") else float(Races.STAFF.crit); var bw := 150.0; var bx := ax - bw
			ci.draw_rect(Rect2(bx, ay - 30, bw, 12), Color(1, 1, 1, 0.12)); ci.draw_rect(Rect2(bx + bw * crit / 100.0, ay - 30, bw * (1.0 - crit / 100.0), 12), Color(1.0, 0.3, 0.1, 0.25))
			ci.draw_rect(Rect2(bx, ay - 30, bw * clampf(f.heat / 100.0, 0.0, 1.0), 12), Color(1.0, 0.25, 0.1) if f.heat >= crit else Color(1.0, 0.65, 0.2)); ci.draw_rect(Rect2(bx, ay - 30, bw, 12), Hud.LINE, false, 1.0)
			h._t(ci, fm, ("봉인 %.1f초" % f.seal_t) if f.seal_t > 0.0 else ("열기 %d%%" % int(f.heat) + (" · 임계" if f.heat >= crit else "")), ax, ay - 14, 11, Hud.ALARM if f.seal_t > 0.0 else Hud.STEEL, "right")

## what you can do, and how soon: [key, name, how ready (0..1), what is written on it]
func chips(rm: Realm, f: Realm.Fighter) -> Array:
	var out: Array = []; var kit := rm.kit
	match f.race:
		"elf": out.push_back(["우클릭", ALT.elf, minf(1.0, f.charge / float(Races.XBOW.charge)) if f.charge > 0.0 else 1.0, "꾹 눌러 차징"])
		"dwarf": out.push_back(["우클릭", ALT.dwarf, 1.0 - f.alt_cd / float(Races.CANNON.gren_cd), ("%d초" % ceili(f.alt_cd)) if f.alt_cd > 0.0 else "준비"])
		"orc": out.push_back(["우클릭", ALT.orc, 1.0 - f.alt_cd / float(Races.SWORD.axe_cd), ("%d초" % ceili(f.alt_cd)) if f.alt_cd > 0.0 else "준비"])
		"demon": out.push_back(["우클릭", ALT.demon, 1.0 if f.hp > float(Races.STAFF.beam_floor) else 0.0, "체력 소모"])
	var S: Dictionary = Races.SKILL[f.race]; var cd := kit.skill_cd(f)
	out.push_back(["Shift", str(Races.R[f.race].skill), 1.0 if f.skill_n > 0 else 1.0 - f.skill_t / cd, ("×%d" % f.skill_n if int(S.charges) > 1 and f.skill_n > 0 else ("준비" if f.skill_n > 0 else "%d초" % ceili(f.skill_t)))])
	var bk: String = BOMB_SHORT[f.bomb_kinds[f.bomb_i % f.bomb_kinds.size()]] if not f.bomb_kinds.is_empty() else ""
	out.push_back(["Q", bk + " 폭탄", 1.0 if f.bombs > 0 else 1.0 - f.bomb_t / Races.BOMB_CD, ("×%d" % f.bombs) if f.bombs > 0 else "%d초" % ceili(f.bomb_t)])
	out.push_back(["V", "룬 단검", 1.0 - f.dag_t / float(Races.DAGGER.cd), "베기 · 처형"])
	out.push_back(["F", "튕겨내기", 1.0 - f.parry_cd / float(Races.DAGGER.parry_cd), ("%d초" % ceili(f.parry_cd)) if f.parry_cd > 0.0 else "준비"])
	var g := f.gauge / float(Races.GAUGE.max)
	out.push_back(["X", str(Races.R[f.race].ult), g if f.ult_t <= 0.0 else 1.0, ("%.0f초" % f.ult_t) if f.ult_t > 0.0 else ("준비" if g >= 1.0 else "%d%%" % int(g * 100.0))])
	return out

func _chips(ci, s: Vector2, c: Vector2, rm: Realm, f: Realm.Fighter) -> void:
	var list := chips(rm, f); var fm: Font = h.m.f_mono; var fb: Font = h.m.f_bold
	var w := clampf((s.x * 0.5) / list.size(), 74.0, 104.0); var x := c.x - w * list.size() / 2.0; var y := s.y - 62.0
	for i in list.size():
		var q: Array = list[i]; var r := Rect2(x + i * w + 2.0, y, w - 4.0, 44.0); var ready := float(q[2]) >= 1.0; var ult := i == list.size() - 1
		var edge := (GOLD if ult else Hud.SODIUM) if ready else Hud.LINE
		h._panel(ci, r, Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.6), Color(edge, 0.85 if ready else 1.0))
		ci.draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x * clampf(float(q[2]), 0.0, 1.0), 3.0), GOLD if ult else (Hud.SODIUM if ready else Hud.STEEL))
		h._t(ci, fm, str(q[0]), r.position.x + 5, r.position.y + 2, 10, Hud.SODIUM if ready else Hud.STEEL, "left", false)
		h._t(ci, fm, str(q[3]), r.end.x - 5, r.position.y + 2, 10, Hud.INK if ready else Hud.STEEL, "right", false)
		h._t(ci, fb, _fit(fb, str(q[1]), 11, r.size.x - 8.0), r.position.x + r.size.x / 2.0, r.position.y + 19, 11, Hud.INK if ready else Hud.STEEL, "center", false)

func _fit(font: Font, text: String, fs: int, w: float) -> String:
	var t := text
	while t.length() > 2 and h._w(font, t, fs) > w: t = t.substr(0, t.length() - 1)
	return t

## a line under the crosshair: what the match wants of you now
func prompt(rm: Realm, f: Realm.Fighter, touch: bool) -> String:
	var md := rm.mode; var H := md.hud()
	if not f.alive: return "쓰러짐 · %d초 뒤 본진 마법진에서 다시 일어납니다" % ceili(f.back_t)
	if md.phase == "prep": return "준비 시간 · " + ("제단 버튼" if touch else "B 키") + "로 룬 제단을 엽니다"
	if f.cast_t > 0.0: return "포효!"
	if f.stun_t > 0.1: return "경직"
	if H.get("carrying", false): return ("폭탄 설치 중 %d%%" % int(float(H.plant) * 100.0)) if float(H.get("plant", 0.0)) > 0.0 else "폭탄 운반 중 · 결계 제단 A나 B 위에 4초 서 있으면 설치됩니다"
	if H.get("in_zone", false): return "성소 안 · " + ("적과 대치 중" if int(H["in"].them) > 0 else "각인 중")
	if f.race == "elf" and f.charged: return "차징 완료 · 놓으면 발사"
	if f.gauge >= float(Races.GAUGE.max) and f.ult_t <= 0.0: return ("비기 버튼" if touch else "X 키") + " · " + str(Races.ULT[f.race].name)
	return ""

func _prompt(ci, _s: Vector2, c: Vector2, touch: bool, rm: Realm, f: Realm.Fighter) -> void:
	var t := prompt(rm, f, touch)
	if t != "" and h.hint_t <= 0.0: h._t(ci, h.m.f_mono, t, c.x, c.y + 58, 12, Hud.SODIUM if f.alive else Hud.INK, "center")
