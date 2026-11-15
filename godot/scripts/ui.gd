class_name Ui
extends Control
## Every screen that is not the fight itself: the main menu (the harbour control console), the shop, the weapon layout, gun
## customisation, the codex, settings and saving, the briefing, the pause and the result sheet.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a")
const ALARM := Color("ff5260"); const VITAL := Color("5ed6b0"); const LINE := Color(0.56, 0.61, 0.69, 0.35)
const NOTE := {1: "밀수 조직원 100명 · 총소리를 들으면 몰려옵니다", 6: "오토바이 헬멧 쓴 조직원 100명 · 헬멧은 헤드샷 한 번에 벗겨짐", 5: "단검 20 · 파란 광선검 10 · 쌍광선검 · 야구방망이 · 자폭맨 · 저격 · 보스는 기관총 · 내릴 곳을 고름",
	2: "불타는 오두막 마을 · 좀비 100마리 · 체력 없이 감염과 중독만", 7: "넓은 사파리 · 5분 뒤 동물 100마리가 가운데 감시탑으로 습격 · 탑 체력 10,000", 8: "우리를 하나씩 · 앞 우리 동물을 다 잡아야 원숭이 박사가 다음 우리를 엶 · 모든 우리 방탄유리",
	9: "아이 방 전체가 싸움터 · 지금은 맵과 장난감 무기만 둘러볼 수 있습니다 · 적은 아직 없습니다",
	3: "우리 10개가 차례로 열리는 연구소 · 얼룩말·기린·코끼리를 타고 싸움 · 보스 고릴라는 방탄유리 우리에", 4: "우주선 복도 · 운전실의 황금 드론 · 메인홀의 3페이즈 보스 드론 · 숨은 스파이더 마인"}
const NODE_AT := {1: [0.09, 0.17], 2: [0.295, 0.17], 3: [0.50, 0.17], 4: [0.705, 0.17], 9: [0.91, 0.17], 6: [0.09, 0.50], 5: [0.09, 0.82], 7: [0.50, 0.50], 8: [0.50, 0.82]}
const TRACKS := [[1, 2], [2, 3], [3, 4], [4, 9], [1, 6], [6, 5], [3, 7], [7, 8]]
const BUILT := [1, 9]   # stages the Godot version can play so far

var f_title: Font; var f_body: Font; var f_bold: Font; var f_mono: Font
var game: Game; var guns: Guns
var is_touch := false
var sel := 1                      # the stage picked on the map
var screens := {}
var cur := ""
var back_stack: Array = []
var do_deploy: Callable; var do_resume: Callable; var do_quit: Callable; var do_menu: Callable; var do_again: Callable; var on_settings: Callable
var in_stage := false             # a stage is under way (the shop and the layout are opened from the pause)
# menu parts
var strip: Control; var rail: Control; var board: Control; var detail: PanelContainer; var stage_btns := {}; var rail_btns: Array = []
var d_code: Label; var d_name: Label; var d_note: Label; var d_best: Label; var d_spec: Label; var d_spec_list: Label; var d_go: Button; var d_msg: Label
var strip_l: Label; var strip_r: Label; var brand: Control
var shop_ctx := 0                 # the stage whose recommended kit the shop shows first (0: none)
var shop_list: VBoxContainer; var shop_msg: Label; var shop_head: Label; var shop_money: Label
var lo_list: VBoxContainer; var lo_sum: Label; var lo_msg: Label
var cu_gun := "pistol"; var cu_body: VBoxContainer
var cx_tab := "gun"; var cx_list: VBoxContainer
var set_body: VBoxContainer; var set_msg: Label
var dlg_title: Label; var dlg_text: Label; var dlg_in: LineEdit; var dlg_msg: Label; var dlg_ok: Button; var dlg_kind := ""
var br_title: Label; var br_code: Label; var br_map: Control; var br_note: Label; var br_gear: Label; var br_go: Button
var pa_note: Label; var pa_body: VBoxContainer
var ov: Dictionary = {}

# ---------------- small builders ----------------
func lbl(text: String, font: Font, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _box(bg: Color, border: Color, bw := 1, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(bw); sb.set_content_margin_all(pad)
	return sb

func btn(text: String, kind := "ghost", cb: Callable = Callable()) -> Button:   # kind: primary, ghost, small, rail
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_ALL
	var primary := kind == "primary"
	b.custom_minimum_size = Vector2(0, 44); b.add_theme_font_override("font", f_title if primary else f_bold); b.add_theme_font_size_override("font_size", 22 if primary else (13 if kind == "small" else 14))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new(); sb.set_content_margin_all(8); sb.content_margin_left = 16; sb.content_margin_right = 16
		if st == "focus": sb.draw_center = false; sb.border_color = SODIUM; sb.set_border_width_all(2); sb.set_expand_margin_all(2)
		elif st == "disabled": sb.bg_color = Color(NIGHT, 0.5); sb.border_color = Color(STEEL, 0.2); sb.set_border_width_all(1)
		elif primary: sb.bg_color = SODIUM if st == "normal" else SODIUM.lightened(0.15)
		elif kind == "rail": sb.bg_color = Color(SODIUM, 0.0 if st == "normal" else 0.14); sb.content_margin_left = 20
		else: sb.bg_color = Color(NIGHT, 0.6 if st == "normal" else 0.9); sb.border_color = Color(STEEL, 0.45 if st == "normal" else 0.95); sb.set_border_width_all(1)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, NIGHT if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color(STEEL, 0.6))
	if kind == "rail": b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if cb.is_valid(): b.pressed.connect(cb)
	return b

func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h
func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return v
func clear(n: Node) -> void:
	for c in n.get_children(): n.remove_child(c); c.queue_free()

## a document sheet over the dimmed scene: [root, body (inside a scroller), footer row, message label]
func sheet(key: String, title: String, code: String, max_w := 760.0) -> Array:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.visible = false; add_child(root); screens[key] = root
	var dim := ColorRect.new(); dim.color = Color(NIGHT, 0.62); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.94), LINE, 1, 16)); root.add_child(panel)
	panel.set_meta("max_w", max_w); root.set_meta("panel", panel)
	var v := vbox(10); panel.add_child(v)
	var head := hbox(); v.add_child(head)
	var t := lbl(title, f_mono, 12, STEEL); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.clip_text = true; head.add_child(t); var c := lbl(code, f_mono, 12, SODIUM); head.add_child(c)
	root.set_meta("title", t); root.set_meta("code", c)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	var body := vbox(10); sc.add_child(body)
	var foot := hbox(); v.add_child(foot)
	var msg := lbl("", f_body, 13, SODIUM, true); foot.add_child(msg)
	return [root, body, foot, msg]

func layout() -> void:
	for key in screens:
		var root: Control = screens[key]
		if not root.has_meta("panel"): continue
		var p: PanelContainer = root.get_meta("panel"); var w := minf(p.get_meta("max_w"), size.x - 16.0); var h := size.y - 16.0
		p.position = Vector2((size.x - w) / 2, 8); p.size = Vector2(w, h)
	_layout_menu()

func show_screen(key: String) -> void:
	cur = key
	for k in screens: (screens[k] as Control).visible = k == key
	match key:
		"menu": refresh_menu()
		"shop": render_shop()
		"loadout": render_loadout()
		"custom": render_custom()
		"codex": render_codex()
		"settings": render_settings()
		"pause": render_pause()
	if key != "": _focus_first.call_deferred(screens[key])

func _focus_first(n: Node) -> void:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree() and not (c as Button).disabled and (c as Button).has_meta("first"): (c as Button).grab_focus(); return

func open_sub(key: String) -> void:   # a screen opened from another: closing it goes back
	back_stack.push_back(cur); show_screen(key)
func close_sub() -> void:
	show_screen(back_stack.pop_back() if not back_stack.is_empty() else "menu")

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE   # (already in the tree: the offsets must be set too)
	_build_menu(); _build_shop(); _build_loadout(); _build_custom(); _build_codex(); _build_settings(); _build_dialog(); _build_brief(); _build_pause(); _build_over()
	resized.connect(layout); layout()

# ================= the main menu: the harbour control console =================
func _build_menu() -> void:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root); screens["menu"] = root
	strip = PanelContainer.new(); strip.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.92), LINE, 0, 8)); root.add_child(strip)
	var sh := hbox(18); strip.add_child(sh)
	strip_l = lbl("● 7번 야드 관제", f_mono, 12, SODIUM); strip_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sh.add_child(strip_l)
	strip_r = lbl("", f_mono, 12, INK); sh.add_child(strip_r)
	rail = PanelContainer.new(); rail.add_theme_stylebox_override("panel", _box(Color(0.04, 0.055, 0.1, 0.9), LINE, 0, 0)); root.add_child(rail)
	var rv := vbox(0); rail.add_child(rv)
	brand = Control.new(); brand.custom_minimum_size = Vector2(0, 150); rv.add_child(brand); brand.draw.connect(_draw_brand)
	var items := [["작전", func() -> void: show_screen("menu")], ["상점", func() -> void: shop_ctx = sel; open_sub("shop")], ["무기 편성", func() -> void: open_sub("loadout")],
		["총기 커스텀", func() -> void: open_sub("custom")], ["도감", func() -> void: open_sub("codex")], ["설정 · 저장", func() -> void: open_sub("settings")]]
	var rg := GridContainer.new(); rg.columns = 1; rg.add_theme_constant_override("h_separation", 0); rg.add_theme_constant_override("v_separation", 0); rv.add_child(rg); rail.set_meta("grid", rg)
	for i in items.size():
		var b := btn("", "rail", items[i][1]); b.set_meta("label", items[i][0]); b.set_meta("num", "%02d" % (i + 1)); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rg.add_child(b); rail_btns.push_back(b)
	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; rv.add_child(sp)
	var bug := lbl("버그 제보\nccoo112@naver.com", f_mono, 10, STEEL); var bm := MarginContainer.new(); bm.add_theme_constant_override("margin_left", 20); bm.add_theme_constant_override("margin_bottom", 12); bm.add_child(bug); rv.add_child(bm); rail.set_meta("bug", bm)
	board = Control.new(); root.add_child(board); board.draw.connect(_draw_board)
	for s in Store.STAGE_ORDER:
		var b := Button.new(); b.flat = true; b.focus_mode = Control.FOCUS_ALL
		var fs := StyleBoxFlat.new(); fs.draw_center = false; fs.border_color = SODIUM; fs.set_border_width_all(2); b.add_theme_stylebox_override("focus", fs)
		for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: sel = s; refresh_menu()); board.add_child(b); stage_btns[s] = b
	detail = PanelContainer.new(); detail.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.74), LINE, 1, 14)); root.add_child(detail)
	var dv := vbox(8); detail.add_child(dv)
	d_code = lbl("", f_mono, 12, SODIUM); dv.add_child(d_code)
	d_name = lbl("", f_title, 34, INK); dv.add_child(d_name)
	d_note = lbl("", f_body, 13, INK, true); dv.add_child(d_note)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); dv.add_child(grid); detail.set_meta("grid", grid)
	var c1 := PanelContainer.new(); c1.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.6), LINE, 1, 8)); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(c1)
	var c1v := vbox(2); c1.add_child(c1v); c1v.add_child(lbl("최단 기록", f_mono, 10, STEEL)); d_best = lbl("—", f_bold, 18, INK); c1v.add_child(d_best)
	var c2 := PanelContainer.new(); c2.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.6), LINE, 1, 8)); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(c2)
	var c2v := vbox(2); c2.add_child(c2v); c2v.add_child(lbl("추천 스펙", f_mono, 10, STEEL)); d_spec = lbl("", f_bold, 18, VITAL); c2v.add_child(d_spec)
	d_spec_list = lbl("", f_body, 12, STEEL, true); dv.add_child(d_spec_list)
	d_go = btn("출동", "primary", func() -> void: _to_brief()); d_go.set_meta("first", true); dv.add_child(d_go)
	var row := hbox(); dv.add_child(row); detail.set_meta("row", row)
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(b1)
	var b2 := btn("무기 편성", "ghost", func() -> void: open_sub("loadout")); b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(b2)
	d_msg = lbl("", f_body, 12, SODIUM, true); dv.add_child(d_msg)

func _mode() -> String:
	return "portrait" if size.y > size.x * 1.1 else ("phone" if size.y < 520 else "pc")

func _draw_brand() -> void:
	var m := _mode()
	if m == "pc":
		brand.draw_string(f_title, Vector2(20, 62), "야르", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, INK); brand.draw_string(f_title, Vector2(20, 116), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, SODIUM)
		brand.draw_string(f_mono, Vector2(20, 140), "단독 작전 · 작업 지시서", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, STEEL)
	else:
		brand.draw_string(f_title, Vector2(14, 32), "야르", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK); brand.draw_string(f_title, Vector2(66, 32), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, SODIUM)

func _layout_menu() -> void:
	if strip == null: return
	var m := _mode(); var W := size.x; var H := size.y; var top := 34.0
	strip.position = Vector2.ZERO; strip.size = Vector2(W, top)
	var rw := 232.0 if m == "pc" else (132.0 if m == "phone" else W)
	var small := m != "pc"
	brand.custom_minimum_size.y = 150.0 if m == "pc" else (44.0 if m == "portrait" else 40.0)
	for b: Button in rail_btns:
		b.text = ("%s   %s" % [b.get_meta("num"), b.get_meta("label")]) if m == "pc" else str(b.get_meta("label"))
		b.custom_minimum_size.y = 46.0 if m == "pc" else (44.0 if m == "portrait" else clampf(floorf((H - top - 40.0) / 6.0), 36.0, 46.0))   # a short phone: all six still fit
		b.add_theme_font_size_override("font_size", 15 if m == "pc" else 13)
	(rail.get_meta("bug") as Control).visible = m == "pc"
	(rail.get_meta("grid") as GridContainer).columns = 3 if m == "portrait" else 1
	if m == "portrait":
		# everything stacked: the brand and the menu on top, the map, then the picked stage
		var rh := 44.0 + 44.0 * 2 + 4; rail.position = Vector2(0, top); rail.size = Vector2(W, rh)
		var bh := minf(H * 0.36, 320.0); board.position = Vector2(0, top + rh); board.size = Vector2(W, bh)
		detail.position = Vector2(8, top + rh + bh + 4); detail.size = Vector2(W - 16, H - (top + rh + bh + 12))
	else:
		rail.position = Vector2(0, top); rail.size = Vector2(rw, H - top)
		var dw := 380.0 if m == "pc" else minf(300.0, W * 0.38)
		board.position = Vector2(rw, top); board.size = Vector2(W - rw - dw - (18 if m == "pc" else 8), H - top)
		detail.position = Vector2(W - dw - (18 if m == "pc" else 6), top + (18 if m == "pc" else 6)); detail.size = Vector2(dw, 0 if m == "pc" else H - top - 12)
		if m == "pc": detail.reset_size(); detail.size.x = dw
	d_name.add_theme_font_size_override("font_size", 34 if m == "pc" else 22); d_note.add_theme_font_size_override("font_size", 13 if m == "pc" else 11)
	(detail.get_meta("row") as Control).visible = m != "phone"
	d_spec_list.add_theme_font_size_override("font_size", 12 if m == "pc" else 10)
	d_go.custom_minimum_size.y = 52.0 if m == "pc" else 44.0
	var pad := 8 if small else 14; (detail.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(pad)
	_place_nodes(); board.queue_redraw(); brand.queue_redraw()

func _node_pos(s: int) -> Vector2:
	var m := _mode(); var top := 34.0 if m != "phone" else 22.0
	var a: Array = NODE_AT[s]; var inner := Vector2(board.size.x - 24.0, board.size.y - top - (30.0 if m == "pc" else 8.0) - (10.0 if m == "pc" else 34.0))   # room for the last row's label
	return Vector2(12.0 + a[0] * inner.x, top + a[1] * inner.y)

func _place_nodes() -> void:
	var m := _mode(); var w := 124.0 if m == "pc" else minf(80.0, board.size.x * 0.195); var h := 46.0 + (58.0 if m == "pc" else 46.0)   # the dot, then the label box
	for s in stage_btns:
		var p := _node_pos(s); (stage_btns[s] as Button).position = Vector2(clampf(p.x - w / 2, 2, board.size.x - w - 2), p.y - 22.0); (stage_btns[s] as Button).size = Vector2(w, h)

func _status(s: int) -> Array:   # [state, line]
	var open := Store.stage_open(s); var done: bool = Store.save.cleared.has(s); var best := int(Store.save.best.get("t%d" % s, 0))
	if not open: return ["locked", "잠김"]
	if done: return ["done", "클리어" + (" " + Store.fmt_time(best) if best > 0 else "")]
	return ["open", "도전 가능"]

func _draw_board() -> void:
	var m := _mode(); var pc := m == "pc"
	if m != "phone":
		board.draw_string(f_mono, Vector2(16, 22), "작전 경로", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL); board.draw_string(f_title, Vector2(92, 24), "스테이지를 고르세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if pc else 15, INK)
	else: board.draw_string(f_mono, Vector2(10, 14), "작전 경로 · 스테이지를 고르세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, STEEL)
	for t in TRACKS:
		var a := _node_pos(t[0]); var b := _node_pos(t[1]); var open := Store.stage_open(t[1])
		if open: board.draw_line(a, b, SODIUM, 4.0 if pc else 3.0)
		else: board.draw_dashed_line(a, b, Color(INK, 0.3), 3.0 if pc else 2.0, 6.0)
	for s in Store.STAGE_ORDER:
		var p := _node_pos(s); var st: Array = _status(s); var picked: bool = s == sel
		var r := (20.0 if picked else 15.0) * (1.0 if pc else 0.7)
		if picked:   # the picked stage: a lit lamp with a play mark
			board.draw_circle(p, r + 6, Color(SODIUM, 0.22)); board.draw_circle(p, r, SODIUM)
			board.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.3, -r * 0.42), p + Vector2(r * 0.48, 0), p + Vector2(-r * 0.3, r * 0.42)]), NIGHT)
		elif st[0] == "done":   # cleared: filled, with a tick
			board.draw_circle(p, r, VITAL); board.draw_polyline(PackedVector2Array([p + Vector2(-r * 0.4, 0), p + Vector2(-r * 0.1, r * 0.3), p + Vector2(r * 0.42, -r * 0.32)]), NIGHT, 2.5)
		elif st[0] == "open": board.draw_circle(p, r, NIGHT); board.draw_arc(p, r, 0, TAU, 32, SODIUM, 3.0)   # open: an empty ring
		else:   # locked: a dashed ring and a padlock
			board.draw_circle(p, r, NIGHT)
			for k in 10: board.draw_arc(p, r, k * TAU / 10, k * TAU / 10 + TAU / 20, 6, Color(STEEL, 0.9), 2.0)
			board.draw_rect(Rect2(p + Vector2(-r * 0.32, -r * 0.05), Vector2(r * 0.64, r * 0.45)), STEEL); board.draw_arc(p + Vector2(0, -r * 0.05), r * 0.24, PI, TAU, 10, STEEL, 2.0)
		# the label under the dot
		var b: Button = stage_btns[s]; var box := Rect2(b.position + Vector2(0, 22.0 + r + 4), Vector2(b.size.x, 58.0 if pc else 46.0))
		board.draw_rect(box, Color(0.055, 0.075, 0.13, 0.9) if picked else Color(NIGHT, 0.7)); board.draw_rect(box, SODIUM if picked else LINE, false, 1.0)
		var fs := 14 if pc else 10; var y := box.position.y + (14 if pc else 11)
		board.draw_string(f_mono, Vector2(box.position.x, y), Store.STAGE_TAG[s], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 10 if pc else 9, STEEL)
		board.draw_string(f_title, Vector2(box.position.x, y + fs + 3), Game.STAGES[s].name, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, STEEL if st[0] == "locked" else INK)
		board.draw_string(f_mono, Vector2(box.position.x, y + fs + (18 if pc else 14)), st[1], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 10 if pc else 9, VITAL if st[0] == "done" else (SODIUM if st[0] == "open" else STEEL))
	if pc:   # legend
		var y := board.size.y - 14.0
		board.draw_circle(Vector2(22, y - 4), 5, VITAL); board.draw_string(f_mono, Vector2(34, y), "클리어", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)
		board.draw_arc(Vector2(100, y - 4), 5, 0, TAU, 16, SODIUM, 2.0); board.draw_string(f_mono, Vector2(112, y), "도전 가능", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)
		for k in 6: board.draw_arc(Vector2(196, y - 4), 5, k * TAU / 6, k * TAU / 6 + TAU / 12, 4, STEEL, 2.0)
		board.draw_string(f_mono, Vector2(208, y), "잠김", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)

func refresh_menu() -> void:
	if strip == null: return
	var n_clear: int = Store.save.cleared.size()
	strip_r.text = "가방 %s    클리어 %d / 8" % [Store.won(Store.save.money), n_clear]
	strip_l.text = "● 7번 야드 관제" + ("  ·  개발자 모드 켜짐" if Store.settings.dev else "")
	var open := Store.stage_open(sel); var st: Array = _status(sel); var best := int(Store.save.best.get("t%d" % sel, 0)); var done: bool = Store.save.cleared.has(sel)
	d_code.text = "스테이지 " + Store.STAGE_TAG[sel] + "  ·  " + st[1]
	d_name.text = Game.STAGES[sel].name
	var pre: int = Store.PREREQ[sel]
	d_note.text = (NOTE[sel] + (" · 다시 하면 보상 없음" if done else "")) if open else "스테이지 %s%s 깨면 열립니다" % [Store.STAGE_TAG[pre], _eul(Store.STAGE_TAG[pre])]
	d_best.text = Store.fmt_time(best) if best > 0 else "—"
	var fit := Meta.fits(sel); var miss := Meta.missing(sel)
	var no_spec: bool = Meta.spec(sel).all.is_empty() and Meta.spec(sel).any.is_empty()
	d_spec.text = "—" if no_spec else ("적합" if fit else "부적합"); d_spec.add_theme_color_override("font_color", INK if no_spec else (VITAL if fit else ALARM))
	d_spec_list.text = "" if no_spec else "추천 스펙 · " + Meta.spec_text(sel) + ("" if fit else "\n없는 것 · " + ", ".join(miss.map(func(id): return Meta.name_of(id))))
	var built := BUILT.has(sel)
	d_go.disabled = not open or not built
	d_msg.text = "" if (built or not open) else "이 스테이지는 아직 Godot판에 옮기지 않았습니다"
	board.queue_redraw()

static func _eul(tag: String) -> String:   # 을/를 after a stage number
	return "을" if tag[tag.length() - 1] in ["1", "3", "6", "7", "8", "0"] else "를"

func _to_brief() -> void:
	if not Store.stage_open(sel) or not BUILT.has(sel): return
	open_brief(sel)

# ================= the shop =================
func _build_shop() -> void:
	var s := sheet("shop", "상점", "가방 0원"); shop_list = s[1]; shop_msg = s[3]
	shop_head = s[0].get_meta("title"); shop_money = s[0].get_meta("code")
	var b := btn("돌아가기", "primary", close_sub); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

func _row(title: String, tag: String, desc: String, state: String, price: String, buttons: Array, own := false, bars := []) -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _box(Color(0.1, 0.16, 0.2, 0.55) if own else Color(NIGHT, 0.5), Color(VITAL, 0.5) if own else LINE, 1, 10))
	var narrow := size.x < 560
	var h: BoxContainer = vbox(6) if narrow else hbox(12); p.add_child(h)
	var left := vbox(2); h.add_child(left)
	var th := hbox(8); left.add_child(th); th.add_child(lbl(title, f_bold, 15, INK)); th.add_child(lbl(tag, f_mono, 11, SODIUM))
	left.add_child(lbl(desc, f_body, 12, STEEL, true))
	if state != "": left.add_child(lbl(state, f_mono, 11, VITAL if own else STEEL))
	if not bars.is_empty():   # 피해 / 연사 / 탄창 as small bars
		var bh := hbox(6); left.add_child(bh)
		for b in bars:
			bh.add_child(lbl(b[0], f_mono, 10, STEEL)); var pb := ProgressBar.new(); pb.custom_minimum_size = Vector2(54, 6); pb.show_percentage = false; pb.max_value = 1.0; pb.value = clampf(b[1], 0.04, 1.0)
			pb.add_theme_stylebox_override("background", _box(Color(NIGHT, 0.8), LINE, 0, 0)); pb.add_theme_stylebox_override("fill", _box(SODIUM, SODIUM, 0, 0)); pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; bh.add_child(pb)
	var right := vbox(4); right.size_flags_horizontal = Control.SIZE_SHRINK_END if not narrow else Control.SIZE_EXPAND_FILL; h.add_child(right)
	right.add_child(lbl(price, f_mono, 12, INK))
	var bb := hbox(6); right.add_child(bb)
	for b in buttons:
		var x := btn(b[0], "small", b[1]); x.disabled = b.size() > 2 and b[2]; bb.add_child(x)
	return p

func _head(t: String, color := STEEL) -> Label:
	return lbl(t, f_mono, 12, color)

func _gun_row(id: String) -> Control:
	var W: Dictionary = Custom.weapon(id); var rented: bool = Store.save.rented.has(id); var owned: bool = Store.save.owned.has(id); var free: bool = id == "pistol" or Store.settings.dev
	var has: bool = free or rented or owned; var fee := Weapons.rent(id); var mid := in_stage
	var price := "무료" if id == "pistol" else ("무료 · 개발자 모드" if Store.settings.dev else ("보유 · 영구 (보물상자)" if owned else ("대여 중" if rented else "대여료 " + Store.won(fee))))
	var bs := []
	if not has: bs.push_back(["대여", func() -> void: shop_msg.text = Meta.rent(id, mid); _after_buy(), Store.save.money < fee])
	elif rented and not owned and not mid and not Store.settings.dev: bs.push_back(["대여 취소", func() -> void: shop_msg.text = Meta.cancel_rent(id); _after_buy()])
	if has and mid and Weapons.AMMO100.has(id):
		var c: int = 0 if Store.settings.dev else Weapons.AMMO100[id]; var rk: bool = W.get("rocket", false); var st: Dictionary = guns.wstate[id]
		bs.push_back([("로켓 +1 · " if rk else "총알 +100 · ") + (Store.won(c) if c > 0 else "무료") + (" (%d/12)" % int(st.mag + st.reserve) if rk else ""), func() -> void: shop_msg.text = Meta.buy_ammo(id, guns); _after_buy(), Store.save.money < c])
	var in_lo: bool = Store.save.loadout.has(id)
	var state := "" if not has else ("%d번 칸" % (Store.save.loadout.find(id) + 1) if in_lo else "빈 칸이 없어 무기 편성에서 넣어 주세요" if not Store.save.loadout.has(null) else "무기 편성에서 넣어 주세요")
	if has and not in_lo and Store.save.loadout.has(null): bs.push_back(["무기 편성", func() -> void: Meta.place(id); _after_buy()])
	return _row(W.name, W.model, W.cls + " · 총알 " + ("무제한" if W.reserve == INF else "%d발" % int(W.reserve)) + (" · " + W.note if W.has("note") else ""), state, price, bs, has,
		[["피해", (W.dmg * W.pellets) / 170.0], ["연사", (1.0 / W.rate) / 22.2], ["탄창", log(W.mag) / log(1200.0)]])

func _item_row(id: String) -> Control:
	var I: Dictionary = Meta.ITEMS[id]; var have: bool = int(Store.save.items[id]) > 0; var price: int = 0 if Store.settings.dev else I.price
	return _row(I.name, I.tag, I.desc_touch if (is_touch and I.has("desc_touch")) else I.desc, Meta.item_state(id), Store.won(price) if price > 0 else "무료 · 개발자 모드",
		[["보유 중" if have else "구매", func() -> void: shop_msg.text = Meta.buy_item(id); _after_buy(), have or Store.save.money < price]], have)

func _after_buy() -> void:
	if in_stage: guns.loadout = game.layout(); guns.slots = guns.loadout.filter(func(x): return x != null); guns.none = guns.slots.is_empty()
	render_shop()

func render_shop() -> void:
	clear(shop_list); var mid := in_stage
	shop_money.text = "가방 " + Store.won(Store.save.money)
	shop_head.text = "상점 · 개발자 모드: 모두 무료" if Store.settings.dev else ("상점 · 대여는 이번 스테이지 동안" if mid else "상점 · 아이템과 무기 대여")
	# the stage's recommended kit, when something in it is missing
	var miss: Array = Meta.missing(shop_ctx) if shop_ctx > 0 else []
	if not miss.is_empty():
		shop_list.add_child(_head("추천 상품 · 스테이지 %s 추천 스펙에 없는 것" % Store.STAGE_TAG[shop_ctx], ALARM))
		for id in miss: shop_list.add_child(_item_row(id) if Meta.ITEMS.has(id) else _gun_row(id))
	shop_list.add_child(_head("아이템 · 다 쓸 때까지 가지고 다닙니다"))
	for id in Meta.ITEM_ORDER: shop_list.add_child(_item_row(id))
	var have := int(Store.save.items.ivory); var can: int = have if Store.ivory_lock == null else mini(have, Store.ivory_lock)
	var ib := [["1개 팔기", func() -> void: shop_msg.text = Meta.sell_ivory(1); render_shop(), can < 1]]
	if can > 1: ib.push_back(["모두 팔기 · " + Store.won(Meta.IVORY_PRICE * can), func() -> void: shop_msg.text = Meta.sell_ivory(can); render_shop()])
	shop_list.add_child(_row("상아", "팔기", "스테이지 3의 코끼리를 잡으면 얻습니다(다시 하기에서는 안 나옴). 1개에 " + Store.won(Meta.IVORY_PRICE) + "에 삽니다.", "%d개 가지고 있음" % have if have > 0 else "없음", "1개 " + Store.won(Meta.IVORY_PRICE), ib, have > 0))
	shop_list.add_child(_head("무기 대여 · 이번 스테이지 동안" if mid else "무기 대여 · 다음 스테이지 한 번"))
	for id in Weapons.ORDER: shop_list.add_child(_gun_row(id))

# ================= the weapon layout =================
func _build_loadout() -> void:
	var s := sheet("loadout", "무기 편성 · 1-7번 키에 놓을 총", "YRD-LOAD", 620.0); lo_list = s[1]; lo_msg = s[3]
	var b := btn("완료", "primary", func() -> void:
		if in_stage and game.layout().all(func(x): return x == null): lo_msg.text = "싸우는 중에는 무기를 하나 이상 넣어야 합니다"; return
		close_sub()); b.set_meta("first", true)
	var r := btn("무기 대여", "ghost", func() -> void: shop_ctx = sel; open_sub("shop"))
	var c := btn("총기 커스텀", "ghost", func() -> void: open_sub("custom")); s[0].set_meta("cu", c)
	s[2].add_child(b); s[2].add_child(r); s[2].add_child(c); s[2].move_child(b, 0); s[2].move_child(r, 1); s[2].move_child(c, 2)

func render_loadout() -> void:
	clear(lo_list); (screens.loadout.get_meta("cu") as Button).visible = not in_stage
	for i in 7:
		var cur_id = Store.save.loadout[i]; var row := hbox(10); lo_list.add_child(row)
		var k := lbl(str(i + 1), f_mono, 16, SODIUM); k.custom_minimum_size = Vector2(22, 0); row.add_child(k)
		var ob := OptionButton.new(); ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ob.custom_minimum_size = Vector2(0, 44); ob.add_theme_font_override("font", f_body); ob.add_theme_font_size_override("font_size", 14); row.add_child(ob)
		ob.add_item("비어 있음"); ob.set_item_metadata(0, null); var pick := 0
		for id in Weapons.ORDER:
			var ok := Store.gun_available(id)
			if not ok and id != cur_id: continue
			var W: Dictionary = Weapons.LIST[id]; var at: int = Store.save.loadout.find(id); var mv := " (%d번에서 옮기기)" % (at + 1) if (at >= 0 and at != i) else ""
			ob.add_item(W.name + " " + W.model + (" (대여 필요)" if not ok else (" · 보유" + mv if Store.save.owned.has(id) else mv))); ob.set_item_metadata(ob.item_count - 1, id)
			if id == cur_id: pick = ob.item_count - 1
		ob.select(pick)
		ob.item_selected.connect(func(ix: int) -> void:
			Meta.set_slot(i, ob.get_item_metadata(ix))
			if in_stage: guns.loadout = game.layout(); guns.slots = guns.loadout.filter(func(x): return x != null); guns.none = guns.slots.is_empty()
			render_loadout())
		var note := "" if cur_id == null else ("이번에는 빈 칸" if not Store.gun_available(cur_id) else ("무료" if cur_id == "pistol" else ("개발자 모드" if Store.settings.dev else ("보유" if Store.save.owned.has(cur_id) else "대여 중"))))
		var nl := lbl(note, f_mono, 11, STEEL); nl.custom_minimum_size = Vector2(84, 0); row.add_child(nl)
	var ready := []
	for i in 7:
		var id = Store.save.loadout[i]
		if id != null and Store.gun_available(id): ready.push_back("%d %s" % [i + 1, Weapons.LIST[id].short])
	lo_sum = lbl("출동하면 쓸 무기 · " + " · ".join(ready) if not ready.is_empty() else "넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다", f_body, 13, INK if not ready.is_empty() else ALARM, true)
	lo_list.add_child(lo_sum)

# ================= gun customisation =================
func _build_custom() -> void:
	var s := sheet("custom", "총기 커스텀 · 부착물과 색", "YRD-GUN", 620.0); cu_body = s[1]
	var b := btn("완료", "primary", close_sub); b.set_meta("first", true); var r := btn("이 총 기본으로", "ghost", func() -> void: Custom.reset(cu_gun); render_custom())
	s[2].add_child(b); s[2].add_child(r); s[2].move_child(b, 0); s[2].move_child(r, 1)

func _option(items: Array, picked: int, cb: Callable) -> OptionButton:
	var ob := OptionButton.new(); ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ob.custom_minimum_size = Vector2(0, 44); ob.add_theme_font_override("font", f_body); ob.add_theme_font_size_override("font_size", 14)
	for t in items: ob.add_item(t)
	ob.select(picked); ob.item_selected.connect(cb); return ob

func render_custom() -> void:
	clear(cu_body)
	var names: Array = Weapons.ORDER.map(func(id): return Weapons.LIST[id].name + " " + Weapons.LIST[id].model)
	cu_body.add_child(_option(names, Weapons.ORDER.find(cu_gun), func(ix: int) -> void: cu_gun = Weapons.ORDER[ix]; render_custom()))
	var set := Custom.setup(cu_gun)
	for slot in Custom.SLOTS:
		var P: Dictionary = Custom.PARTS[slot]; var fit: Array = P.list.filter(func(p): return Custom.fits(cu_gun, slot, p.id))
		var row := hbox(10); cu_body.add_child(row); var k := lbl(P.name, f_bold, 14, SODIUM); k.custom_minimum_size = Vector2(60, 0); row.add_child(k)
		var col := vbox(2); row.add_child(col)
		if fit.size() < 2: col.add_child(lbl("이 총에는 달 수 없습니다", f_body, 13, STEEL)); continue
		var ix := 0
		for i in fit.size():
			if fit[i].id == set[slot]: ix = i
		col.add_child(_option(fit.map(func(p): return p.name), ix, func(j: int) -> void: Custom.set_part(cu_gun, slot, fit[j].id); render_custom()))
		col.add_child(lbl(fit[ix].desc, f_body, 12, STEEL, true))
	var prow := hbox(10); cu_body.add_child(prow); var pk := lbl("색", f_bold, 14, SODIUM); pk.custom_minimum_size = Vector2(60, 0); prow.add_child(pk)
	prow.add_child(_option(Custom.PAINTS.map(func(p): return p.name), Custom.paint_index(set.paint), func(j: int) -> void: Custom.set_part(cu_gun, "paint", Custom.PAINTS[j].id); render_custom()))
	var W := Custom.weapon(cu_gun); var B: Dictionary = Weapons.LIST[cu_gun]
	var line := func(name: String, key: String, fmt: String, scale_: float) -> String:
		var a := float(B.get(key, 7.0)) * scale_; var b := float(W.get(key, 7.0)) * scale_
		return name + " " + (fmt % b) + ("" if absf(a - b) < 1e-9 else " (기본 " + (fmt % a) + ")")
	cu_body.add_child(lbl(" · ".join([line.call("데미지", "dmg", "%.1f", 1.0), line.call("반동", "recoil", "%.1f", 1000.0), line.call("퍼짐", "spread", "%.1f", 1000.0), line.call("정조준 퍼짐", "adsSpread", "%.1f", 1000.0), line.call("정조준 속도", "adsSpeed", "%.1f", 1.0)]), f_mono, 11, INK, true))
	on_settings.call()   # the gun in your hands is repainted

# ================= the codex =================
func _build_codex() -> void:
	var s := sheet("codex", "도감 · 무기와 적의 모든 수치", "CODEX"); cx_list = s[1]
	var b := btn("돌아가기", "primary", close_sub); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

func _bar_row(name: String, value: String, frac: float) -> Control:
	var h := hbox(8); var n := lbl(name, f_mono, 11, STEEL); n.custom_minimum_size = Vector2(56, 0); h.add_child(n)
	var pb := ProgressBar.new(); pb.custom_minimum_size = Vector2(0, 8); pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; pb.show_percentage = false; pb.max_value = 1.0; pb.value = clampf(frac, 0.02, 1.0)
	pb.add_theme_stylebox_override("background", _box(Color(NIGHT, 0.8), LINE, 0, 0)); pb.add_theme_stylebox_override("fill", _box(SODIUM, SODIUM, 0, 0)); h.add_child(pb)
	var v := lbl(value, f_mono, 11, INK); v.custom_minimum_size = Vector2(92, 0); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(v)
	return h

func render_codex() -> void:
	clear(cx_list)
	var tabs := hbox(8); cx_list.add_child(tabs)
	for t in [["gun", "총기도감"], ["enemy", "적 도감"]]:
		var b := btn(t[1], "primary" if cx_tab == t[0] else "ghost", func() -> void: cx_tab = t[0]; render_codex()); b.add_theme_font_size_override("font_size", 15); tabs.add_child(b)
	var seen: bool = Store.settings.dev or not (Store.save.cleared as Array).is_empty()
	if cx_tab == "gun":
		for id in Weapons.ORDER:
			var W := Custom.weapon(id); var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.5), LINE, 1, 10)); cx_list.add_child(p)
			var v := vbox(4); p.add_child(v); var th := hbox(8); v.add_child(th); th.add_child(lbl(W.name, f_title, 18, INK)); th.add_child(lbl(W.model, f_mono, 11, SODIUM)); th.add_child(lbl(W.cls, f_body, 12, STEEL))
			if not seen: v.add_child(lbl("스테이지 1을 깨면 열립니다", f_bold, 14, SODIUM)); continue
			var shot: float = W.dmg * W.pellets; var rpm: float = 60.0 / W.rate; var dps: float = shot / W.rate
			v.add_child(_bar_row("데미지", ("%.1f" % shot) + (" (%d×%s)" % [W.pellets, str(W.dmg)] if W.pellets > 1 else ""), shot / 1000.0 if W.get("rocket", false) else shot / 180.0))
			v.add_child(_bar_row("연사", "%d발/분" % roundi(rpm), rpm / 1340.0)); v.add_child(_bar_row("DPS", "%d" % roundi(dps), dps / 1700.0)); v.add_child(_bar_row("사거리", "%d m" % int(W.range), W.range / 320.0))
			v.add_child(lbl("탄창 %d · 총알 %s · 재장전 %.1f초 · 머리 ×%s · 이동 ×%s%s" % [int(W.mag), "무제한" if W.reserve == INF else str(int(W.reserve)), W.reload, str(W.head), str(W.moveMul), " · " + W.note if W.has("note") else ""], f_body, 12, STEEL, true))
	else:
		var B: Dictionary = Game.BOSS[1]
		for c in [{"st": "1", "name": "조직원", "hp": 100, "speed": "3.2~4.0 m/s", "arms": "권총", "dmg": "한 발 9 · 1~3발씩 끊어 쏨", "trait": "부두 곳곳에 미리 자리 잡고 있음 · 보거나 총소리를 들으면 공격", "pay": 1000},
				{"st": "1", "boss": true, "name": B.name, "hp": B.hp, "speed": "2.9~3.6 m/s", "arms": "권총", "dmg": "한 발 %s · 4발 연사, 쉬는 시간이 짧음" % str(9 * B.dmgMul), "trait": "보스 · 크고 단단함 · 처치하면 보물상자 (총을 영구 소유)", "pay": 20000}]:
			var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.5), Color(ALARM, 0.6) if c.get("boss", false) else LINE, 1, 10)); cx_list.add_child(p)
			var v := vbox(4); p.add_child(v); var th := hbox(8); v.add_child(th); th.add_child(lbl(c.name, f_title, 18, INK)); th.add_child(lbl("스테이지 " + c.st, f_mono, 11, SODIUM))
			if not seen: v.add_child(lbl("스테이지 1을 깨면 열립니다", f_bold, 14, SODIUM)); continue
			v.add_child(_bar_row("체력", str(int(c.hp)), c.hp / 5200.0)); v.add_child(lbl("속도 %s · 무기 %s · %s" % [c.speed, c.arms, c.dmg], f_body, 12, INK, true)); v.add_child(lbl(c.trait + " · " + Store.won(c.pay), f_body, 12, STEEL, true))
		cx_list.add_child(lbl("다른 스테이지의 적은 그 스테이지를 Godot판에 옮기면서 들어옵니다", f_body, 12, STEEL, true))

# ================= settings and saving =================
func _build_settings() -> void:
	var s := sheet("settings", "설정 · 저장", "YRD-SAVE", 620.0); set_body = s[1]; set_msg = s[3]
	var b := btn("돌아가기", "primary", close_sub); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

func _slider(name: String, key: String, lo: float, hi: float, step: float, show: Callable) -> Control:
	var h := hbox(10); var n := lbl(name, f_body, 14, INK); n.custom_minimum_size = Vector2(96, 0); h.add_child(n)
	var sl := HSlider.new(); sl.min_value = lo; sl.max_value = hi; sl.step = step; sl.value = float(Store.settings[key]); sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sl.custom_minimum_size = Vector2(0, 44); sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(sl)
	var o := lbl(show.call(sl.value), f_mono, 13, SODIUM); o.custom_minimum_size = Vector2(40, 0); h.add_child(o)
	sl.value_changed.connect(func(v: float) -> void: Store.settings[key] = v; o.text = show.call(v); Store.persist_settings(); on_settings.call())
	return h

func _check(name: String, key: String) -> CheckBox:
	var c := CheckBox.new(); c.text = name; c.button_pressed = bool(Store.settings[key]); c.add_theme_font_override("font", f_body); c.add_theme_font_size_override("font_size", 14); c.custom_minimum_size = Vector2(0, 44)
	c.toggled.connect(func(on: bool) -> void: Store.settings[key] = on; Store.persist_settings(); on_settings.call())
	return c

const CROSS := [["cross", "십자"], ["circle", "원"], ["big", "큰 원"], ["dot", "점"]]
const CROSS_COL := [["ece6d8", "흰색"], ["5ed6b0", "초록"], ["ff5260", "빨강"], ["ffe14a", "노랑"], ["6fe4ff", "하늘"], ["ff8ac0", "분홍"], ["f2a33a", "주황"]]
func _settings_rows(into: VBoxContainer, full: bool) -> void:
	into.add_child(_slider("터치 감도" if is_touch else "마우스 감도", "sens", 0.2, 3.0, 0.1, func(v: float) -> String: return "%.1f" % v))
	into.add_child(_slider("음량", "vol", 0.0, 1.0, 0.05, func(v: float) -> String: return str(roundi(v * 100))))
	var row := hbox(16); into.add_child(row)
	if is_touch: row.add_child(_check("자동 사격", "autoFire"))
	row.add_child(_check("FPS 표시", "fps"))
	if Store.settings.dev: row.add_child(_check("무적", "god"))
	if not full: return
	var cr := hbox(10); into.add_child(cr); cr.add_child(lbl("조준선", f_body, 14, INK))
	var ci := 0; var cj := 0
	for i in CROSS.size():
		if CROSS[i][0] == Store.settings.cross: ci = i
	for i in CROSS_COL.size():
		if CROSS_COL[i][0] == Store.settings.crossColor: cj = i
	cr.add_child(_option(CROSS.map(func(c): return c[1]), ci, func(j: int) -> void: Store.settings.cross = CROSS[j][0]; Store.persist_settings()))
	cr.add_child(lbl("색", f_body, 14, INK)); cr.add_child(_option(CROSS_COL.map(func(c): return c[1]), cj, func(j: int) -> void: Store.settings.crossColor = CROSS_COL[j][0]; Store.persist_settings()))

func render_settings() -> void:
	clear(set_body)
	set_body.add_child(_head("설정")); _settings_rows(set_body, true)
	set_body.add_child(_head("저장"))
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8); set_body.add_child(row)
	row.add_child(btn("저장", "small", func() -> void: open_dialog("save"))); row.add_child(btn("불러오기", "small", func() -> void: open_dialog("load")))
	row.add_child(btn("초기화", "small", func() -> void: open_dialog("reset")))
	row.add_child(btn("개발자 모드 켜짐" if Store.settings.dev else "개발자 모드", "small", func() -> void:
		if Store.settings.dev: Store.settings.dev = false; Store.settings.god = false; Store.persist_settings(); set_msg.text = "개발자 모드를 껐습니다"; render_settings()
		else: open_dialog("dev")))
	set_body.add_child(_head("조작법"))
	set_body.add_child(lbl("왼쪽 방향 패드 이동 (▲ 두 번 눌러 달리기) · 화면을 밀어 조준 · 발사 · 조준 · 장전 · 근접 · 무기 · 점프" if is_touch else
		"WASD 이동 · Shift 달리기 · Space 점프 · 마우스 조준 · 좌클릭 발사 · 우클릭 조준 · R 재장전 · V 근접 · 1-7 무기 · 휠 무기 바꾸기 · Esc 일시정지 · 상점 · F3 FPS 표시", f_body, 13, INK, true))
	set_body.add_child(lbl("버그 제보: ccoo112@naver.com", f_body, 12, STEEL))

# ---------- one small dialog for save, load, reset and the developer password ----------
func _build_dialog() -> void:
	var s := sheet("dlg", "", "YRD-SAVE", 560.0); var body: VBoxContainer = s[1]; dlg_msg = s[3]
	dlg_title = lbl("", f_title, 30, INK); body.add_child(dlg_title); dlg_text = lbl("", f_body, 13, INK, true); body.add_child(dlg_text)
	dlg_in = LineEdit.new(); dlg_in.custom_minimum_size = Vector2(0, 46); dlg_in.add_theme_font_override("font", f_mono); dlg_in.add_theme_font_size_override("font_size", 15); body.add_child(dlg_in)
	dlg_in.text_submitted.connect(func(_t: String) -> void: _dialog_ok())
	dlg_ok = btn("확인", "primary", _dialog_ok); dlg_ok.set_meta("first", true); var c := btn("닫기", "ghost", close_sub)
	s[2].add_child(dlg_ok); s[2].add_child(c); s[2].move_child(dlg_ok, 0); s[2].move_child(c, 1)

func open_dialog(kind: String) -> void:
	dlg_kind = kind; dlg_msg.text = ""; dlg_in.visible = kind != "reset"; dlg_in.secret = kind == "dev"; dlg_in.editable = kind != "save"; dlg_in.text = ""; dlg_ok.visible = true
	match kind:
		"save":
			dlg_title.text = "저장"; dlg_in.text = SaveCode.encode(Store.save, Store.money_lock, Store.ivory_lock, Store.own_lock); dlg_ok.text = "복사"
			dlg_text.text = "이 코드를 적어 두거나 복사해 두세요. 처음 화면의 불러오기에 넣으면 지금의 돈, 열린 스테이지, 깬 스테이지, 최단 기록, 무기 편성, 가진 총, 아이템과 상아, 총기 커스텀으로 돌아갑니다. 대여 중인 무기는 코드에 들어가지 않습니다."
		"load":
			dlg_title.text = "불러오기"; dlg_ok.text = "확인"; dlg_text.text = "저장 코드를 넣으세요. 지금의 진행 상황은 코드의 것으로 바뀝니다."
		"reset":
			dlg_title.text = "초기화"; dlg_ok.text = "확인"
			dlg_text.text = "돈, 열린 스테이지, 깬 기록, 최단 기록, 무기 편성, 대여 중인 무기, 가진 총, 아이템과 상아, 총기 커스텀을 모두 지우고 처음 상태로 돌아갑니다. 되돌릴 수 없으니 필요하면 먼저 저장 코드를 받아 두세요. 설정(감도, 음량, 개발자 모드)은 그대로입니다."
		"dev":
			dlg_title.text = "개발자 모드"; dlg_ok.text = "확인"; dlg_text.text = "비밀번호를 넣으세요."
	open_sub("dlg")
	if dlg_in.visible and kind != "save": dlg_in.grab_focus.call_deferred()

func _dialog_ok() -> void:
	match dlg_kind:
		"save":
			DisplayServer.clipboard_set(dlg_in.text)
			if OS.has_feature("web"): JavaScriptBridge.eval("try{navigator.clipboard.writeText(%s)}catch(e){}" % JSON.stringify(dlg_in.text))
			dlg_msg.text = "복사했습니다 · 안 되면 코드를 길게 눌러 복사해 주세요"
		"load":
			var d = SaveCode.decode(dlg_in.text)
			if d == null: dlg_msg.text = "코드가 맞지 않습니다 · 다시 확인해 주세요"; Snd.play("empty"); return
			Store.save = Store.save0(); Store.save.merge(d, true); Store.fix_save(); Store.persist(); Snd.play("buy"); close_sub(); set_msg.text = "불러왔습니다 · 가방 " + Store.won(Store.save.money); on_settings.call()
		"reset":
			Store.save = Store.save0(); Store.fix_save(); Store.persist(); close_sub(); set_msg.text = "처음 상태로 돌아갔습니다"; on_settings.call()
		"dev":
			if SaveCode.dev_hash(dlg_in.text.strip_edges()) != SaveCode.DEV_HASH: dlg_msg.text = "비밀번호가 틀렸습니다"; Snd.play("empty"); return
			Store.settings.dev = true; Store.persist_settings(); close_sub(); set_msg.text = "개발자 모드를 켰습니다 · 모든 스테이지와 무기가 열립니다"; render_settings()

# ================= the briefing =================
func _build_brief() -> void:
	var s := sheet("brief", "작전 브리핑 · 위에서 본 지도", "스테이지 1", 620.0); var body: VBoxContainer = s[1]; br_code = s[0].get_meta("code")
	br_title = lbl("", f_title, 36, INK); body.add_child(br_title)
	br_map = Control.new(); br_map.custom_minimum_size = Vector2(0, 260); body.add_child(br_map); br_map.draw.connect(_draw_map)
	br_note = lbl("", f_body, 13, INK, true); body.add_child(br_note); br_gear = lbl("", f_body, 13, SODIUM, true); body.add_child(br_gear)
	br_go = btn("출동", "primary", func() -> void: _deploy()); br_go.set_meta("first", true)
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("무기 편성", "ghost", func() -> void: open_sub("loadout")); var b3 := btn("돌아가기", "ghost", func() -> void: do_menu.call())
	for i in 4: s[2].add_child([br_go, b1, b2, b3][i]); s[2].move_child([br_go, b1, b2, b3][i], i)

func open_brief(stage: int) -> void:
	sel = stage; game.begin(stage); back_stack.clear(); show_screen("brief"); _brief_gear()
	br_code.text = "스테이지 " + Store.STAGE_TAG[stage]; br_title.text = Game.STAGES[stage].name
	br_note.text = Game.STAGES[stage].intro + ("\n" + game.boss_msg + "\n적 %d · 보스 1" % (game.goal - 1) if game.goal > 0 else ""); br_map.queue_redraw()

func _brief_gear() -> void:
	var ready := []; var lo := game.layout()
	for i in 7:
		if lo[i] != null: ready.push_back("%d %s" % [i + 1, Weapons.LIST[lo[i]].short])
	var fit := Meta.fits(sel)
	if sel == 9: br_gear.text = "장난감 무기 9종 · 1-9번 키"; br_go.disabled = false; return
	br_gear.text = ("출동하면 쓸 무기 · " + " · ".join(ready) if not ready.is_empty() else "넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다") + "\n추천 스펙 · " + ("적합" if fit else "부적합")
	br_gear.add_theme_color_override("font_color", SODIUM if fit else ALARM); br_go.disabled = ready.is_empty()

func _deploy() -> void:
	game.guns.reset(game.layout())   # what the shop and the layout changed since the briefing opened
	if game.guns.none: return
	back_stack.clear(); show_screen(""); do_deploy.call()

## the yard from above: what blocks the way, the crates, where you start, where the enemies stand
func _draw_map() -> void:
	var s := minf(br_map.size.x, br_map.size.y); var o := Vector2((br_map.size.x - s) / 2, 0); var half := Phys.HALF + 2.0; var k := s / (2.0 * half)
	br_map.draw_rect(Rect2(o, Vector2(s, s)), Color(0.04, 0.055, 0.1, 0.9)); br_map.draw_rect(Rect2(o, Vector2(s, s)), LINE, false, 1.0)
	var at := func(x: float, z: float) -> Vector2: return o + Vector2((x + half) * k, (z + half) * k)
	for b in Phys.colliders:
		if b.kind == "wood" and game.stage != 9: continue
		if game.stage == 9 and b.maxy - b.miny > 30.0: continue   # the room's walls
		br_map.draw_rect(Rect2(at.call(b.minx, b.minz), Vector2(maxf(1.0, (b.maxx - b.minx) * k), maxf(1.0, (b.maxz - b.minz) * k))), Color(STEEL, 0.75) if b.kind == "metal" else Color(STEEL, 0.4))
	for c in game.world.crates: br_map.draw_rect(Rect2(at.call(c.x - 0.6, c.z - 0.6), Vector2(2, 2)), Color("b98a55"))
	for e in game.enemies.list: br_map.draw_circle(at.call(e.pos.x, e.pos.z), 3.5 if e.boss else 1.6, ALARM)
	var st: Vector2 = at.call(game.world.start.x, game.world.start.z); br_map.draw_circle(st, 4.0, VITAL); br_map.draw_arc(st, 7.0, 0, TAU, 20, VITAL, 1.5)

# ================= pause =================
func _build_pause() -> void:
	var s := sheet("pause", "작업 지시서 · 단독 작전", "YRD-PAUSE", 560.0); pa_body = s[1]
	var b := btn("계속하기", "primary", func() -> void: do_resume.call()); b.set_meta("first", true)
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("무기 편성", "ghost", func() -> void: open_sub("loadout")); var b3 := btn("작전 포기", "ghost", func() -> void: do_quit.call())
	for i in 4: s[2].add_child([b, b1, b2, b3][i]); s[2].move_child([b, b1, b2, b3][i], i)

func render_pause() -> void:
	clear(pa_body); pa_body.add_child(lbl("일시정지", f_title, 48, INK))
	if pa_note_text != "": pa_body.add_child(lbl(pa_note_text, f_body, 13, SODIUM, true))
	pa_body.add_child(lbl("처치 %d / %d · 가방 %s" % [game.kills, game.goal, Store.won(Store.save.money)], f_mono, 13, INK))
	_settings_rows(pa_body, false)
var pa_note_text := ""

# ================= the result sheet =================
func _build_over() -> void:
	var s := sheet("over", "작전 결과 보고", "—", 620.0); var body: VBoxContainer = s[1]
	ov.code = s[0].get_meta("code"); ov.stamp = lbl("작전 실패", f_title, 20, ALARM); body.add_child(ov.stamp)
	ov.title = lbl("", f_title, 40, INK, true); body.add_child(ov.title)
	var grid := GridContainer.new(); grid.columns = 5 if size.x >= 560 else 2; grid.add_theme_constant_override("h_separation", 18); grid.add_theme_constant_override("v_separation", 8); body.add_child(grid)
	for k in [["kills", "처치"], ["earn", "번 돈"], ["hs", "헤드샷"], ["acc", "명중률"], ["time", "시간"]]:
		var v := vbox(0); v.add_child(lbl(k[1], f_mono, 11, STEEL)); ov[k[0]] = lbl("0", f_bold, 20, INK); v.add_child(ov[k[0]]); grid.add_child(v)
	ov.best = lbl("", f_body, 13, STEEL, true); body.add_child(ov.best)
	ov.again = btn("다시 도전", "primary", func() -> void: do_again.call(game.stage)); ov.again.set_meta("first", true)
	ov.next = btn("", "primary", func() -> void: do_again.call(int(ov.next.get_meta("st")))); ov.next2 = btn("", "primary", func() -> void: do_again.call(int(ov.next2.get_meta("st"))))
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("처음 화면", "ghost", func() -> void: do_menu.call())
	for i in 5: s[2].add_child([ov.again, ov.next, ov.next2, b1, b2][i]); s[2].move_child([ov.again, ov.next, ov.next2, b1, b2][i], i)

func show_result(kind: String) -> void:
	var clear_ := kind == "clear"; var st: Dictionary = game.stats; var tag: String = Store.STAGE_TAG[game.stage]
	(ov.stamp as Label).text = "임무 완료" if clear_ else "작전 실패"; (ov.stamp as Label).add_theme_color_override("font_color", VITAL if clear_ else ALARM)
	(ov.title as Label).text = "스테이지 %s 클리어" % tag if clear_ else "스테이지 %s · 쓰러짐" % tag
	(ov.kills as Label).text = "%d / %d" % [st.kills, game.goal]; (ov.earn as Label).text = Store.won(st.earned); (ov.hs as Label).text = str(st.heads)
	(ov.earn as Label).add_theme_color_override("font_color", ALARM if (not clear_ and st.earned > 0) else INK)
	(ov.acc as Label).text = "%d%%" % (roundi(100.0 * st.hits / st.shots) if st.shots > 0 else 0); (ov.time as Label).text = Store.fmt_time(st.time)
	(ov.code as Label).text = "보고 번호 " + Store.iso_code("YRD", (game.stage * 100000 + st.kills * 997) % 1000000)
	(ov.again as Button).text = "다시 하기" if clear_ else "다시 도전"
	var nx: Array = Store.next_stages(game.stage) if clear_ else []
	for i in 2:
		var b: Button = [ov.next, ov.next2][i]; b.visible = i < nx.size()
		if i < nx.size(): b.set_meta("st", nx[i]); b.text = "스테이지 %s%s" % [Store.STAGE_TAG[nx[i]], "으로" if Store.STAGE_TAG[nx[i]].ends_with("1") or Store.STAGE_TAG[nx[i]].ends_with("3") else "로"]; b.disabled = not BUILT.has(nx[i])
	var all_done: bool = Store.STAGE_ORDER.all(func(s): return Store.save.cleared.has(s))
	var opened := ("새로 열림 · 스테이지 " + ", ".join(game.opened.map(func(s): return Store.STAGE_TAG[s])) + " · ") if (clear_ and not game.opened.is_empty()) else ""
	(ov.best as Label).text = ((opened + ("모든 스테이지를 깼습니다 · " if all_done else "헬기로 탈출해 번 돈을 챙겼습니다 · ")) if clear_ else ("탈출하지 못해 이번에 번 %s을 잃었습니다 · " % Store.won(st.earned) if st.earned > 0 else "")) + "가방 " + Store.won(Store.save.money)
	back_stack.clear(); show_screen("over")
