class_name Ui
extends Control
## Every screen that is not the fight itself: the main menu (the harbour control console), the shop, the weapon layout, gun
## customisation, the codex, settings and saving, the briefing, the pause and the result sheet.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a")
const ALARM := Color("ff5260"); const VITAL := Color("5ed6b0"); const LINE := Color(0.56, 0.61, 0.69, 0.35)
const NOTE := {1: "밀수 조직원 100명 · 총소리를 들으면 몰려옵니다", 6: "오토바이 헬멧 쓴 조직원 100명 · 헬멧은 헤드샷 한 번에 벗겨짐", 5: "단검 20 · 파란 광선검 10 · 쌍광선검 · 야구방망이 · 자폭맨 · 저격 · 보스는 기관총 · 오른쪽 아래 구석에서 시작",
	2: "불타는 오두막 마을 · 좀비 100마리 · 체력 없이 감염과 중독만 · 해독약 상자는 오두막 안에만", 7: "넓은 사파리 · 5분 뒤 동물 93마리가 가운데 감시탑으로 습격 · 탑 체력 10,000", 8: "우리를 하나씩 · 앞 우리 동물을 다 잡아야 원숭이 박사가 다음 우리를 엶 · 모든 우리 방탄유리",
	9: "아이 방 전체가 싸움터 · 장난감 100개 · 플라스틱 군인, 액션 피규어, 태엽·RC 유닛, 조립 블록 피규어",
	3: "우리 10개가 차례로 열리는 연구소 · 얼룩말·기린·코끼리를 타고 싸움 · 보스 고릴라는 방탄유리 우리에", 4: "우주선 복도 · 운전실의 황금 드론 · 메인홀의 3페이즈 보스 드론 (잡으면 끝) · 숨은 스파이더 마인",
	10: "엘프의 숲 · 서쪽 경계에서 동쪽 대마법사의 탑까지 · 엘프 60명과 대마법사 · 회복 물약 상자 없음 · 달샘 연못이 체력을 채워 줍니다",
	11: "정사각형 평원 · 네 모서리의 엘프·드워프·오크·악마 건물 · 고른 종족의 건물은 아군을, 나머지 셋은 적을 소환 · 적 건물과 남은 적을 모두 쓰러뜨리면 클리어", 12: "오크의 땅 · 준비 중", 13: "악마의 땅 · 준비 중"}
# (stage 6's four places hang under stage 5: 6-1 below it, 6-2 below that, then back to the left with 6-3 and up to 6-4)
const NODE_AT := {1: [0.09, 0.17], 2: [0.295, 0.17], 3: [0.50, 0.17], 4: [0.705, 0.17], 9: [0.91, 0.17], 6: [0.09, 0.50], 5: [0.09, 0.82], 7: [0.50, 0.50], 8: [0.50, 0.82],
	10: [0.91, 0.50], 11: [0.91, 0.82], 12: [0.705, 0.82], 13: [0.705, 0.50]}
const TRACKS := [[1, 2], [2, 3], [3, 4], [4, 9], [1, 6], [6, 5], [3, 7], [7, 8], [9, 10], [10, 11], [11, 12], [12, 13]]
const BUILT := [1, 6, 5, 2, 3, 7, 8, 4, 9, 10, 11]   # stages the Godot version can play so far
const RACE_SHORT := {"elf": "엘", "dwarf": "드", "orc": "오", "demon": "악"}

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
var br_modes: HFlowContainer   # stage 5: the sweep, or one of the three team modes
# the tactical map: drawn on the briefing and on its own screen (M, the pause's map button, the touch map button)
var tac: TacMap
var br_body: VBoxContainer; var br_box: BoxContainer; var br_side: VBoxContainer; var br_leg_h: HFlowContainer; var br_leg_v: VBoxContainer
var mp_box: BoxContainer; var mp_map: Control; var mp_side: VBoxContainer; var mp_leg_h: HFlowContainer; var mp_leg_v: VBoxContainer; var mp_code: Label; var mp_hint: Label
var do_map: Callable; var do_map_close: Callable
var map_short := false   # a short landscape screen: the map on the left, the rest beside it
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
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.scroll_deadzone = TOUCH_SLOP; v.add_child(sc)
	var body := vbox(10); sc.add_child(body)
	# the buttons along the bottom go on to a second line when they do not fit (the browser game's .actions wrap)
	var foot := HFlowContainer.new(); foot.add_theme_constant_override("h_separation", 8); foot.add_theme_constant_override("v_separation", 8); v.add_child(foot)
	var msg := lbl("", f_body, 13, SODIUM, true); msg.custom_minimum_size.x = 200.0; foot.add_child(msg)
	return [root, body, foot, msg]

func layout() -> void:
	_layout_maps()
	if ov.has("grid"): (ov.grid as GridContainer).columns = 5 if size.x >= 560 else 2   # the result's five numbers: on one line, or two to a line on a narrow screen
	for key in screens:
		var root: Control = screens[key]
		if not root.has_meta("panel"): continue
		var p: PanelContainer = root.get_meta("panel"); var w := minf(p.get_meta("max_w"), size.x - 16.0); var h := size.y - 16.0
		p.position = Vector2((size.x - w) / 2, 8); p.size = Vector2(w, h)
	_layout_menu()

func show_screen(key: String) -> void:
	cur = key
	for k in screens: (screens[k] as Control).visible = k == key
	_opening = true   # (opened afresh: its list starts at the top)
	match key:
		"menu": refresh_menu()
		"shop": render_shop()
		"loadout": render_loadout()
		"custom": render_custom()
		"codex": render_codex()
		"settings": render_settings()
		"account": render_account()
		"pause": render_pause()
		"brief": _brief_gear()   # (back from the layout or the shop: the guns to deploy with, the kit, whether 출동 can be pressed)
		"over": _over_money()    # (back from the shop: the bag as it is now)
	_opening = false
	if key != "": _focus_first.call_deferred(screens[key])

var _opening := false
## a list drawn again in its place (a button in it pressed): its scroller stays where it was, not sent back to the top (the
## rows go and come back, and for that moment there is nothing to scroll). Put back once the new rows are laid out
func _hold_scroll(list: Control) -> void:
	if _opening or not is_inside_tree(): return
	var sc := list.get_parent() as ScrollContainer
	if sc == null or sc.scroll_vertical <= 0: return
	var at := sc.scroll_vertical
	var put := func() -> void:
		if is_instance_valid(sc): sc.scroll_vertical = at
	put.call_deferred(); get_tree().process_frame.connect(put, CONNECT_ONE_SHOT)

func _focus_first(n: Node) -> void:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree() and not (c as Button).disabled and (c as Button).has_meta("first"): (c as Button).grab_focus(); return

func open_sub(key: String) -> void:   # a screen opened from another: closing it goes back
	back_stack.push_back(cur); show_screen(key)
func close_sub() -> void:
	show_screen(back_stack.pop_back() if not back_stack.is_empty() else "menu")

## a finger on a list (a phone, a touch screen): Godot's lists scroll as a dragged finger, sent on as the mouse, moves them,
## but only when the press gets to the list. So what is in a list (a button, a shop row's panel) lets the press through to it,
## all but what a finger drags itself (a slider, a text box), and a gun box opens when the finger lifts, not as it lands.
## A finger that moves more than TOUCH_SLOP (in the screen's points) scrolls, and the button under it lets go; one that
## stays put is a tap.
const TOUCH_SLOP := 10.0
func _touch_fit(n: Node) -> void:
	if not n is Control or not is_ancestor_of(n): return
	var c := n as Control
	if c.get_viewport() != get_viewport(): return   # (a gun box's drop-down is a window of its own: left as Godot makes it)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE or c is ScrollContainer or c is Slider or c is ScrollBar or c is LineEdit or c is TextEdit or c is SpinBox: return
	var p := n.get_parent()
	while p != null and p != self:
		if p is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			if c is OptionButton and is_touch: (c as BaseButton).action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			return
		p = p.get_parent()

func _ready() -> void:
	get_tree().node_added.connect(_touch_fit)

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE   # (already in the tree: the offsets must be set too)
	tac = TacMap.new(); tac.game = game; tac.f_mono = f_mono; tac.f_bold = f_bold
	_build_menu(); _build_shop(); _build_loadout(); _build_custom(); _build_codex(); _build_settings(); _build_dialog(); _build_account(); _build_brief(); _build_map(); _build_altar(); _build_pause(); _build_over()
	resized.connect(layout); layout()

# ================= the main menu: the harbour control console =================
func _build_menu() -> void:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root); screens["menu"] = root
	strip = PanelContainer.new(); strip.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.92), LINE, 0, 8)); root.add_child(strip)
	var sh := hbox(18); strip.add_child(sh)
	strip_l = lbl("● 7번 야드 관제", f_mono, 12, SODIUM); strip_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; strip_l.clip_text = true; strip_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; sh.add_child(strip_l)
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
	var c2v := vbox(2); c2.add_child(c2v); c2v.add_child(lbl("권장 스펙", f_mono, 10, STEEL)); d_spec = lbl("", f_bold, 18, VITAL); c2v.add_child(d_spec)
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
	d_go.get_parent().move_child(d_go, 4 if m == "phone" else 5)   # on a low screen the button comes before the list of gear, so it is never off the bottom
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
	if Store.SOON.has(s): return ["soon", "준비 중"]   # (named on the board, not made yet)
	var open := Store.stage_open(s); var done: bool = Store.save.cleared.has(s); var best := int(Store.save.best.get("t%d" % s, 0))
	if not open: return ["locked", "잠김 · %s 클리어 후" % Store.STAGE_TAG[Store.NEEDS[s]]] if Store.NEEDS.has(s) else ["locked", "잠김"]
	if done and s == Store.ST_PLAIN: return ["done", "클리어 · 종족 %d/4" % ModePlain.cleared_by().size()]
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
		else:   # locked: a dashed ring and a padlock (one not made yet: three dots)
			board.draw_circle(p, r, NIGHT)
			for k in 10: board.draw_arc(p, r, k * TAU / 10, k * TAU / 10 + TAU / 20, 6, Color(STEEL, 0.9), 2.0)
			if st[0] == "soon":
				for k in 3: board.draw_circle(p + Vector2((k - 1) * r * 0.42, 0), r * 0.11, STEEL)
			else: board.draw_rect(Rect2(p + Vector2(-r * 0.32, -r * 0.05), Vector2(r * 0.64, r * 0.45)), STEEL); board.draw_arc(p + Vector2(0, -r * 0.05), r * 0.24, PI, TAU, 10, STEEL, 2.0)
		if s == Store.ST_PLAIN and st[0] != "soon":   # 6-2: which peoples have taken it, as four small marks beside its dot
			var by := ModePlain.cleared_by(); var dr := 3.6 if pc else 2.6
			for i in 4:
				var race: String = Races.ORDER[i]; var q := p + Vector2(r + 7.0 + dr, (i - 1.5) * (dr * 2.0 + 2.0))
				board.draw_circle(q, dr, Color(str(Races.R[race].col)) if by.has(race) else Color(NIGHT, 0.9)); board.draw_arc(q, dr, 0, TAU, 12, Color(str(Races.R[race].col)), 1.2)
		# the label under the dot
		var b: Button = stage_btns[s]; var box := Rect2(b.position + Vector2(0, 22.0 + r + 4), Vector2(b.size.x, 58.0 if pc else 46.0))
		board.draw_rect(box, Color(0.055, 0.075, 0.13, 0.9) if picked else Color(NIGHT, 0.7)); board.draw_rect(box, SODIUM if picked else LINE, false, 1.0)
		var fs := 14 if pc else 10; var y := box.position.y + (14 if pc else 11)
		board.draw_string(f_mono, Vector2(box.position.x, y), Store.STAGE_TAG[s], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 10 if pc else 9, STEEL)
		board.draw_string(f_title, Vector2(box.position.x, y + fs + 3), Game.STAGES[s].name, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs, STEEL if (st[0] == "locked" or st[0] == "soon") else INK)
		board.draw_string(f_mono, Vector2(box.position.x, y + fs + (18 if pc else 14)), st[1], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 10 if pc else 9, VITAL if st[0] == "done" else (SODIUM if st[0] == "open" else STEEL))
	if pc:   # legend
		var y := board.size.y - 14.0
		board.draw_circle(Vector2(22, y - 4), 5, VITAL); board.draw_string(f_mono, Vector2(34, y), "클리어", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)
		board.draw_arc(Vector2(100, y - 4), 5, 0, TAU, 16, SODIUM, 2.0); board.draw_string(f_mono, Vector2(112, y), "도전 가능", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)

func refresh_menu() -> void:
	if strip == null: return
	var n_clear: int = Store.save.cleared.size()
	strip_r.text = "가방 %s    클리어 %d / %d" % [Store.won(Store.save.money), n_clear, Store.playable().size()]
	strip_l.text = "● 7번 야드 관제" + ("  ·  개발자 모드 켜짐" if Store.settings.dev else "") + ("  ·  " + account_badge() if Cloud.enabled() else "")
	var cxb: Button = rail_btns[4]; var cx_ok := Codex.ready()   # the book opens with your first clear (always in developer mode)
	if cxb.disabled == cx_ok: cxb.disabled = not cx_ok; cxb.set_meta("label", "도감" if cx_ok else "도감 · 첫 클리어 후"); _layout_menu()
	var set_label := "설정 · 계정" if Cloud.enabled() else "설정 · 저장"   # (the account is in with the settings and the save codes)
	if str(rail_btns[5].get_meta("label")) != set_label: rail_btns[5].set_meta("label", set_label); _layout_menu()
	var open := Store.stage_open(sel); var st: Array = _status(sel); var best := int(Store.save.best.get("t%d" % sel, 0)); var done: bool = Store.save.cleared.has(sel)
	d_code.text = "스테이지 " + Store.STAGE_TAG[sel] + "  ·  " + st[1]
	d_name.text = Game.STAGES[sel].name
	d_note.text = NOTE[sel] + (" · 다시 하면 보상 없음" if done and sel != Store.ST_PLAIN else "")
	d_best.text = Store.fmt_time(best) if best > 0 else "—"
	if sel == Store.ST_PLAIN:   # 6-2: the peoples that have taken it, each with its best time (a first win with each pays)
		var by := ModePlain.cleared_by(); var parts: Array = []
		for r: String in Races.ORDER: parts.push_back(str(Races.R[r].name) + " " + (Store.fmt_time(float(by[r])) if by.has(r) else "—"))
		d_note.text += "\n깬 종족 · " + " · ".join(parts)
		var bt := 0
		for r: String in by: bt = int(by[r]) if bt == 0 else mini(bt, int(by[r]))
		d_best.text = Store.fmt_time(bt) if bt > 0 else "—"
	var fit := Meta.fits(sel); var miss := Meta.missing(sel)
	var no_spec: bool = Meta.spec(sel).all.is_empty() and Meta.spec(sel).any.is_empty()
	d_spec.text = "—" if no_spec else ("적합" if fit else "부적합"); d_spec.add_theme_color_override("font_color", INK if no_spec else (VITAL if fit else ALARM))
	d_spec_list.text = "" if no_spec else "권장 스펙 · " + Meta.spec_text(sel) + ("" if fit else "\n없는 것 · " + ", ".join(miss.map(func(id): return Meta.name_of(id))))
	var built := BUILT.has(sel)
	d_go.disabled = not open or not built
	d_msg.text = ("스테이지 %s을 깨면 열립니다" % Store.STAGE_TAG[Store.NEEDS[sel]] if Store.NEEDS.has(sel) else "") if not open else ("" if built else "이 스테이지는 아직 Godot판에 옮기지 않았습니다")
	if Store.SOON.has(sel): d_msg.text = "준비 중인 스테이지입니다 · 맵이 정해지면 열립니다"
	board.queue_redraw()

func _to_brief() -> void:
	if not Store.stage_open(sel) or not BUILT.has(sel): return
	open_brief(sel)

# ================= the shop =================
func _build_shop() -> void:
	var s := sheet("shop", "상점", "가방 0원"); shop_list = s[1]; shop_msg = s[3]
	shop_head = s[0].get_meta("title"); shop_money = s[0].get_meta("code")
	var b := btn("돌아가기", "primary", close_sub); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

const REC_FILL := Color(0.95, 0.64, 0.23, 0.17)   # the shop: a gun or item in the stage's recommended kit (and not had yet) is filled amber
func _row(title: String, tag: String, desc: String, state: String, price: String, buttons: Array, own := false, bars := [], rec := false) -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _box(REC_FILL if rec else (Color(0.1, 0.16, 0.2, 0.55) if own else Color(NIGHT, 0.5)), Color(SODIUM, 0.8) if rec else (Color(VITAL, 0.5) if own else LINE), 2 if rec else 1, 10))
	p.set_meta("rec", rec)
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

## the shop in stage 5's run (its briefing, its pause, its result sheet): the toy room hands you its nine toy guns, so there no gun is
## rented, given bullets or put in the layout (what you rented before waits for the next stage: Game.return_rentals)
func toy_shop() -> bool:
	return game != null and game.stage == Store.ST_TOY and (in_stage or back_stack.has("brief") or back_stack.has("over"))

func _gun_row(id: String, rec := false) -> Control:
	var W: Dictionary = Custom.weapon(id); var rented: bool = Store.save.rented.has(id); var owned: bool = Store.save.owned.has(id); var free: bool = id == "pistol" or Store.settings.dev
	var has: bool = free or rented or owned; var fee := Weapons.rent(id); var mid := in_stage; var toy := toy_shop()
	var price := "무료" if id == "pistol" else ("무료 · 개발자 모드" if Store.settings.dev else ("보유 · 영구 (보물상자)" if owned else ("대여 중" if rented else "대여료 " + Store.won(fee))))
	var bs := []
	if toy: pass   # (the row as it is, with nothing to press)
	elif not has: bs.push_back(["대여", func() -> void: shop_msg.text = Meta.rent(id, mid); _after_buy(), Store.save.money < fee])
	elif rented and not owned and not mid and not Store.settings.dev: bs.push_back(["대여 취소", func() -> void: shop_msg.text = Meta.cancel_rent(id); _after_buy()])
	if has and mid and not toy and Weapons.AMMO100.has(id):
		var pk := Meta.ammo_pack(id, guns); var c: int = pk[1]; var rk: bool = W.get("rocket", false); var st: Dictionary = guns.wstate[id]; var full := Meta.ammo_room(id, guns) < 1
		bs.push_back([("로켓 +1 · " if rk else ("총알 가득" if full else "총알 +%d · " % int(pk[0]))) + ("" if (full and not rk) else (Store.won(c) if c > 0 else "무료")) + (" (%d/12)" % int(st.mag + st.reserve) if rk else ""),
			func() -> void: shop_msg.text = Meta.buy_ammo(id, guns); _after_buy(), Store.save.money < c or full])
	var in_lo: bool = Store.save.loadout.has(id)
	var state := "" if (not has or toy) else ("%d번 칸" % (Store.save.loadout.find(id) + 1) if in_lo else "빈 칸이 없어 무기 편성에서 넣어 주세요" if not Store.save.loadout.has(null) else "무기 편성에서 넣어 주세요")
	if has and not toy and not in_lo and Store.save.loadout.has(null): bs.push_back(["무기 편성", func() -> void: Meta.place(id); _after_buy()])
	return _row(W.name, W.model, W.cls + " · 총알 " + ("무제한" if W.reserve == INF else "%d발" % int(W.reserve)) + (" · " + W.note if W.has("note") else ""), state, price, bs, has,
		[["피해", (W.dmg * W.pellets) / 170.0], ["연사", (1.0 / W.rate) / 22.2], ["탄창", log(W.mag) / log(1200.0)]], rec)

func _item_row(id: String, rec := false) -> Control:
	var I: Dictionary = Meta.ITEMS[id]; var have: bool = int(Store.save.items[id]) > 0; var price: int = 0 if Store.settings.dev else I.price
	return _row(I.name, I.tag, I.desc_touch if (is_touch and I.has("desc_touch")) else I.desc, Meta.item_state(id), Store.won(price) if price > 0 else "무료 · 개발자 모드",
		[["보유 중" if have else "구매", func() -> void: shop_msg.text = Meta.buy_item(id); _after_buy(), have or Store.save.money < price]], have, [], rec)

func _after_buy() -> void:
	if in_stage: guns.loadout = game.layout(); guns.slots = guns.loadout.filter(func(x): return x != null); guns.none = guns.slots.is_empty()
	render_shop()

func render_shop() -> void:
	_hold_scroll(shop_list); clear(shop_list); var mid := in_stage
	shop_money.text = "가방 " + Store.won(Store.save.money)
	var toy := toy_shop()
	shop_head.text = "상점 · 개발자 모드: 모두 무료" if Store.settings.dev else ("상점 · 장난감 방" if toy else ("상점 · 대여는 이번 스테이지 동안" if mid else "상점 · 아이템과 무기 대여"))
	# the stage's recommended kit, when something in it is missing
	var miss: Array = Meta.missing(shop_ctx) if shop_ctx > 0 else []
	if not miss.is_empty():
		shop_list.add_child(_head("추천 상품 · 스테이지 %s 권장 스펙에 없는 것" % Store.STAGE_TAG[shop_ctx], ALARM))
		for id in miss: shop_list.add_child(_item_row(id, true) if Meta.ITEMS.has(id) else _gun_row(id, true))
	shop_list.add_child(_head("아이템 · 다 쓸 때까지 가지고 다닙니다"))
	for id in Meta.ITEM_ORDER: shop_list.add_child(_item_row(id, miss.has(id)))
	var have := int(Store.save.items.ivory); var can: int = have if Store.ivory_lock == null else mini(have, Store.ivory_lock)
	var ib := [["1개 팔기", func() -> void: shop_msg.text = Meta.sell_ivory(1); render_shop(), can < 1]]
	if can > 1: ib.push_back(["모두 팔기 · " + Store.won(Meta.ivory_price() * can), func() -> void: shop_msg.text = Meta.sell_ivory(can); render_shop()])
	shop_list.add_child(_row("상아", "팔기", "스테이지 3의 코끼리를 잡으면 얻습니다(다시 하기에서는 안 나옴). 1개에 " + Store.won(Meta.ivory_price()) + "에 삽니다.", "%d개 가지고 있음" % have if have > 0 else "없음", "1개 " + Store.won(Meta.ivory_price()), ib, have > 0))
	shop_list.add_child(_head("무기 대여 · 장난감 방에서는 장난감 총만 씁니다" if toy else ("무기 대여 · 이번 스테이지 동안" if mid else "무기 대여 · 다음 스테이지 한 번")))
	if toy: shop_list.add_child(lbl("대여한 무기는 여기서 반납되지 않고 다음에 다른 스테이지에서 씁니다", f_body, 13, INK, true))
	for id in Weapons.ORDER: shop_list.add_child(_gun_row(id, miss.has(id)))

# ================= the weapon layout =================
func _build_loadout() -> void:
	var s := sheet("loadout", "무기 편성 · 1-7번 키에 놓을 총", "YRD-LOAD", 620.0); lo_list = s[1]; lo_msg = s[3]
	var b := btn("완료", "primary", close_loadout); b.set_meta("first", true)
	var r := btn("무기 대여", "ghost", func() -> void: shop_ctx = sel; open_sub("shop"))
	var c := btn("총기 커스텀", "ghost", func() -> void: open_sub("custom")); s[0].set_meta("cu", c)
	s[2].add_child(b); s[2].add_child(r); s[2].add_child(c); s[2].move_child(b, 0); s[2].move_child(r, 1); s[2].move_child(c, 2)

## the weapon layout closed (its 완료, Esc, the phone's back button: all come here): in a fight, not with no gun at all in it
func close_loadout() -> void:
	if in_stage and game.layout().all(func(x): return x == null): lo_msg.text = "싸우는 중에는 무기를 하나 이상 넣어야 합니다"; return
	close_sub()

## back from the screen on top (Esc, the phone's back button): the weapon layout through its own check
func back() -> void:
	if cur == "loadout": close_loadout()
	elif cur == "account": close_account()
	else: close_sub()

## the weapon order changed in the pause or on the loadout screen: the number keys follow at once, the gun in hand stays in hand
func _relayout() -> void:
	if not in_stage: return
	guns.loadout = game.layout(); guns.slots = guns.loadout.filter(func(x): return x != null); guns.none = guns.slots.is_empty()
func _move_gun(id: String, step: int, toys: bool, again: Callable) -> void:
	if Meta.move_gun(id, step, toys): Snd.play("reload0")
	_relayout(); again.call()
## (across: left and right arrows, for things laid out in a row as the toy shelf's)
func _arrows(row: HBoxContainer, up: Callable, down: Callable, can_up: bool, can_down: bool, across := false) -> void:
	var u := btn("◀" if across else "▲", "small", up); u.disabled = not can_up; u.tooltip_text = "앞 번호로"; row.add_child(u)
	var d := btn("▶" if across else "▼", "small", down); d.disabled = not can_down; d.tooltip_text = "뒤 번호로"; row.add_child(d)
## the guns in your hands in key order, each with arrows to move it (the pause; the toy room's nine toy guns there)
func _gun_order(into: VBoxContainer, again: Callable) -> void:
	var toys: bool = game.stage == Store.ST_TOY; var lay: Array = guns.loadout; var held := lay.filter(func(x): return x != null)
	into.add_child(_head("무기 순서 · 숫자 키 %d-%d번" % [1, lay.size()]))
	for i in lay.size():
		var id = lay[i]
		if id == null: continue
		var row := hbox(8); into.add_child(row); var at := held.find(id)
		var k := lbl(str(i + 1), f_mono, 15, SODIUM); k.custom_minimum_size = Vector2(22, 0); row.add_child(k)
		var nm := lbl(Toys.NAMES[id] if toys else Weapons.LIST[id].name + " " + Weapons.LIST[id].model, f_body, 14, INK); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(nm)
		_arrows(row, func() -> void: _move_gun(id, -1, toys, again), func() -> void: _move_gun(id, 1, toys, again),
			Meta.can_move_toy(id, -1) if toys else at > 0, Meta.can_move_toy(id, 1) if toys else at < held.size() - 1)
	if toys and Toys.lead(Store.save.loadout) > 0:
		into.add_child(lbl("1-%d번은 무기 편성 순서를 따릅니다 · 그 뒤는 나머지 장난감" % Toys.lead(Store.save.loadout), f_body, 12, STEEL, true))

## the toy room's nine toys on the shop's shelf, each in its package in key order (its picture from the side under the
## bubble, its name, its key on the tag); the arrows under one move it a place
func _toy_shelf(into: VBoxContainer, again: Callable) -> void:
	var lay: Array = Toys.order_for(Store.save.loadout, Store.save.toy_order); var n := Toys.lead(Store.save.loadout)
	into.add_child(_head("장난감 진열대 · 숫자 키 1-%d번 차례" % lay.size()))
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 10); flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL; into.add_child(flow)
	for i in lay.size():
		var id = lay[i]
		if i == n and n > 0:   # the layout's toys first, the others on a shelf of their own
			into.add_child(lbl("1-%d번 · 무기 편성에 넣은 총의 장난감판, 무기 편성 순서대로" % n, f_body, 12, STEEL, true))
			into.add_child(_head("나머지 장난감 · %d-%d번" % [n + 1, lay.size()]))
			flow = HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 10); flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL; into.add_child(flow)
		var cell := VBoxContainer.new(); cell.add_theme_constant_override("separation", 2); flow.add_child(cell)
		var pk := Control.new(); pk.custom_minimum_size = Vector2(136, 116); pk.mouse_filter = Control.MOUSE_FILTER_IGNORE; pk.set_meta("toy", id); cell.add_child(pk)
		pk.draw.connect(func() -> void:
			ToyKit.pack(pk, pk.size, Toys.NAMES[id], Color(str(ToyKit.BRICKS[i % 5])).lightened(0.4), "", false, false, false, func(r: Rect2) -> void: ToyKit.gun(pk, str(id), r.grow(-2.0)), 0.0, str(i + 1)))
		var row := hbox(6); row.alignment = BoxContainer.ALIGNMENT_CENTER; cell.add_child(row)
		_arrows(row, func() -> void: _move_gun(id, -1, true, again), func() -> void: _move_gun(id, 1, true, again), Meta.can_move_toy(id, -1), Meta.can_move_toy(id, 1), true)

func render_loadout() -> void:
	_hold_scroll(lo_list); clear(lo_list); (screens.loadout.get_meta("cu") as Button).visible = not in_stage
	(screens.loadout.get_meta("title") as Label).text = "무기 편성 · 장난감 가게 진열대" if (toy_shop() and in_stage) else ("무기 편성 · 장난감 방도 이 순서대로" if toy_shop() else "무기 편성 · 1-7번 키에 놓을 총")
	if toy_shop() and in_stage:   # the toy room hands you all nine toy guns: only their order (keys 1-9) changes
		_toy_shelf(lo_list, render_loadout)
		lo_list.add_child(lbl("장난감 방에서는 장난감 총 아홉 자루를 모두 듭니다 · 화살표로 숫자 키 차례를 바꿉니다", f_body, 13, INK, true))
		return
	# (before a stage-5 run, from its briefing or its result sheet: the layout itself, then the shelf of toys it makes, below)
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
			Meta.set_slot(i, ob.get_item_metadata(ix)); _relayout(); render_loadout())
		var note := "" if cur_id == null else ("이번에는 빈 칸" if not Store.gun_available(cur_id) else ("무료" if cur_id == "pistol" else ("개발자 모드" if Store.settings.dev else ("보유" if Store.save.owned.has(cur_id) else "대여 중"))))
		var nl := lbl(note, f_mono, 11, STEEL); nl.custom_minimum_size = Vector2(84, 0); row.add_child(nl)
		_arrows(row, func() -> void: Meta.swap_slots(i, i - 1); Snd.play("reload0"); _relayout(); render_loadout(),
			func() -> void: Meta.swap_slots(i, i + 1); Snd.play("reload0"); _relayout(); render_loadout(), i > 0, i < 6)
	var ready := []
	for i in 7:
		var id = Store.save.loadout[i]
		if id != null and Store.gun_available(id): ready.push_back("%d %s" % [i + 1, Weapons.LIST[id].short])
	lo_sum = lbl("출동하면 쓸 무기 · " + " · ".join(ready) if not ready.is_empty() else "넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다", f_body, 13, INK if not ready.is_empty() else ALARM, true)
	if toy_shop(): lo_sum.text = "장난감 방에서는 장난감 총 아홉 자루를 모두 듭니다 · 무기 편성에 넣은 총이 앞 번호에 옵니다"; lo_sum.add_theme_color_override("font_color", INK)
	lo_list.add_child(lo_sum)
	if toy_shop(): _toy_shelf(lo_list, render_loadout)

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
	var s := sheet("codex", "도감 · 무기와 적의 모든 수치", "CODEX", 1060.0); cx_list = s[1]
	var b := btn("돌아가기", "primary", close_sub); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

func _bar_row(name: String, value: String, frac: float) -> Control:
	var h := hbox(8); var n := lbl(name, f_mono, 11, STEEL); n.custom_minimum_size = Vector2(56, 0); h.add_child(n)
	var pb := ProgressBar.new(); pb.custom_minimum_size = Vector2(0, 8); pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; pb.show_percentage = false; pb.max_value = 1.0; pb.value = clampf(frac, 0.02, 1.0)
	pb.add_theme_stylebox_override("background", _box(Color(NIGHT, 0.8), LINE, 0, 0)); pb.add_theme_stylebox_override("fill", _box(SODIUM, SODIUM, 0, 0)); h.add_child(pb)
	var v := lbl(value, f_mono, 11, INK); v.custom_minimum_size = Vector2(92, 0); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(v)
	return h

var cx_st := "all"   # the enemy book's stage filter
## a card in the books: the name (and a boss badge, the stages), the line under it, the price, the numbers with bars, a note
func _cx_card(c: Dictionary, stages: bool) -> Control:
	var locked: bool = c.get("locked", false); var boss: int = int(c.get("boss", 0))
	var border := Color(STEEL, 0.25) if locked else (Color(ALARM, 0.55) if boss == 1 else (Color(SODIUM, 0.55) if boss == 2 else (Color(SODIUM, 0.45) if c.get("own", false) else LINE)))
	var bg := Color(ALARM, 0.05) if boss == 1 and not locked else (Color(SODIUM, 0.04) if boss == 2 and not locked else Color(INK, 0.015 if locked else 0.03))
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _box(bg, border, 1, 12)); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(7); p.add_child(v)
	var top := HFlowContainer.new(); top.add_theme_constant_override("h_separation", 8); v.add_child(top)
	top.add_child(lbl("???" if locked else str(c.name), f_title, 21, STEEL if locked else INK))
	if boss > 0 and not locked:
		var bd := lbl("보스" if boss == 1 else "중간보스", f_mono, 10, Color.WHITE if boss == 1 else NIGHT); var bp := PanelContainer.new(); bp.add_theme_stylebox_override("panel", _box(ALARM if boss == 1 else SODIUM, ALARM if boss == 1 else SODIUM, 0, 2)); bp.add_child(bd); bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(bp)
	if stages:
		for st in c.st:
			var sp := PanelContainer.new(); sp.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), LINE, 1, 2)); sp.add_child(lbl(str(st), f_mono, 10, INK)); sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(sp)
	if locked:
		var tags: Array = c.st
		v.add_child(lbl("스테이지 " + " · ".join(tags) + (" 중 하나를" if tags.size() > 1 else Codex.eul(str(tags[0]))) + " 깨면 열립니다", f_body, 12, STEEL, true)); return p
	if str(c.get("sub", "")) != "": v.add_child(lbl(str(c.sub), f_body, 12, STEEL, true))
	if str(c.get("tag", "")) != "": v.add_child(lbl(str(c.tag), f_mono, 11, SODIUM, true))
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 5); v.add_child(g)
	for r: Array in c.rows:
		var dt := lbl(str(r[0]), f_mono, 11, STEEL); dt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; g.add_child(dt)
		var dd := vbox(4); dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dd.add_child(lbl(str(r[1]), f_body, 13, Color("d9dee8"), true))
		if r.size() > 2:
			var bar := Control.new(); bar.custom_minimum_size = Vector2(0, 4); var fr := clampf(float(r[2]), 0.03, 1.0)
			bar.draw.connect(func() -> void: bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(INK, 0.12)); bar.draw_rect(Rect2(0, 0, bar.size.x * fr, bar.size.y), SODIUM)); dd.add_child(bar)
		g.add_child(dd)
	if str(c.get("note", "")) != "": v.add_child(lbl(str(c.note), f_body, 12, STEEL, true))
	return p

func render_codex() -> void:
	_hold_scroll(cx_list); clear(cx_list)
	var every := Codex.foes(); var open_n := every.filter(func(e): return Codex.seen(e.st)).size()
	var tabs := hbox(4); cx_list.add_child(tabs)
	for t in [["gun", "총기도감"], ["enemy", "적 도감 %d/%d" % [open_n, every.size()]]]:
		var b := btn(t[1], "primary" if cx_tab == t[0] else "ghost", func() -> void: cx_tab = t[0]; render_codex()); b.add_theme_font_override("font", f_title); b.add_theme_font_size_override("font_size", 20); tabs.add_child(b)
	var cols := maxi(1, int((minf(1060.0, size.x - 16.0) - 32.0 + 10.0) / 320.0))
	if cx_tab == "enemy":
		var chips := HFlowContainer.new(); chips.add_theme_constant_override("h_separation", 6); chips.add_theme_constant_override("v_separation", 6); cx_list.add_child(chips)
		for ch in Codex.CHIPS:
			var cb := btn(ch[1] if ch[0] == "all" else "스테이지 " + str(ch[1]), "primary" if cx_st == ch[0] else "small", func() -> void: cx_st = ch[0]; render_codex())
			cb.add_theme_font_override("font", f_mono); cb.add_theme_font_size_override("font_size", 12); chips.add_child(cb)
	var grid := GridContainer.new(); grid.columns = cols; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); cx_list.add_child(grid)
	if cx_tab == "gun":
		for c: Dictionary in Codex.guns(): grid.add_child(_cx_card(c, false))
		cx_list.add_child(lbl(Codex.INFO_GUN, f_body, 12, STEEL, true)); return
	for e: Dictionary in every:
		if cx_st != "all" and not (e.st as Array).has(cx_st): continue
		if not Codex.seen(e.st): grid.add_child(_cx_card({"locked": true, "st": e.st}, true)); continue
		var rows := [["체력", e.hp], ["이동속도", e.speed], ["무장", e.arms], ["데미지", e.dmg], ["특징", e.trait], ["스킬", e.skill]]
		if e.has("pay"): rows.push_back(["처치 보상", Store.won(int(e.pay) * Store.PAY)])   # (twice the browser game's, as every income here)
		grid.add_child(_cx_card({"name": e.name, "st": e.st, "boss": e.get("boss", 0), "rows": rows}, true))
	cx_list.add_child(lbl(Codex.INFO_FOE, f_body, 12, STEEL, true))

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
const GFX := [["auto", "자동"], ["high", "최고 화질"], ["fast", "프레임 우선"]]
## the settings, in the browser game's order (main menu and pause alike): sensitivity, volume, auto fire (touch), graphics
## (computers), the crosshair and its colour, the FPS readout (and, in developer mode, invincibility)
func _settings_rows(into: VBoxContainer, _full: bool) -> void:
	into.add_child(_slider("터치 감도" if is_touch else "마우스 감도", "sens", 0.2, 3.0, 0.1, func(v: float) -> String: return "%.1f" % v))
	into.add_child(_slider("음량", "vol", 0.0, 1.0, 0.05, func(v: float) -> String: return str(roundi(v * 100))))
	into.add_child(_slider("음악", "music", 0.0, 1.0, 0.05, func(v: float) -> String: return str(roundi(v * 100))))   # (stage 5's music)
	if is_touch:
		into.add_child(_check("자동 사격", "autoFire"))
		into.add_child(_check("좀비 시체 자동 사격 · 스테이지 2", "corpseShot"))   # (Guns._corpse_shot)
		into.add_child(lbl("서 있는 좀비를 쓰러뜨리면 조준이 저절로 그 시신으로 가서 한 발 쏘고(다시 일어나지 않게), 원래 보던 곳으로 돌아옵니다.", f_body, 12, STEEL, true))
	else:
		var gr := hbox(10); into.add_child(gr); var gl := lbl("그래픽", f_body, 14, INK); gl.custom_minimum_size = Vector2(96, 0); gr.add_child(gl)
		var gi := 0
		for i in GFX.size():
			if GFX[i][0] == str(Store.settings.get("gfx", "auto")): gi = i
		gr.add_child(_option(GFX.map(func(g): return g[1]), gi, func(j: int) -> void: Store.settings.gfx = GFX[j][0]; Store.persist_settings(); on_settings.call()))
	var cr := hbox(10); into.add_child(cr); cr.add_child(lbl("조준선", f_body, 14, INK))
	var ci := 0; var cj := 0
	for i in CROSS.size():
		if CROSS[i][0] == Store.settings.cross: ci = i
	for i in CROSS_COL.size():
		if CROSS_COL[i][0] == Store.settings.crossColor: cj = i
	cr.add_child(_option(CROSS.map(func(c): return c[1]), ci, func(j: int) -> void: Store.settings.cross = CROSS[j][0]; Store.persist_settings()))
	cr.add_child(lbl("색", f_body, 14, INK)); cr.add_child(_option(CROSS_COL.map(func(c): return c[1]), cj, func(j: int) -> void: Store.settings.crossColor = CROSS_COL[j][0]; Store.persist_settings()))
	var row := hbox(16); into.add_child(row)
	row.add_child(_check("FPS 표시", "fps"))
	if Store.settings.dev: row.add_child(_check("무적", "god"))

func render_settings() -> void:
	clear(set_body)
	((screens.settings as Control).get_meta("title") as Label).text = "설정 · 계정 · 저장" if Cloud.enabled() else "설정 · 저장"
	if Cloud.enabled() and not in_stage:   # the account: who is signed in, and the way to its screen (from the menu only: never in a fight)
		set_body.add_child(_head("계정"))
		set_body.add_child(lbl((Cloud.id + " · " if Cloud.signed_in() else "") + Cloud.status_text(), f_body, 13, ALARM if Cloud.asking() else INK, true))
		var ar := HFlowContainer.new(); ar.add_theme_constant_override("h_separation", 8); ar.add_theme_constant_override("v_separation", 8); set_body.add_child(ar)
		ar.add_child(btn("진행 상황 고르기" if Cloud.asking() else ("계정 · 로그아웃" if Cloud.signed_in() else "로그인 · 회원가입"), "small", open_account))
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

# ---------- one small dialog for save, load, reset and the developer password (Dialog and SaveMail in src/08f_meta.js) ----------
var dlg_cancel: Button; var dlg_head: Label; var mail_box: VBoxContainer; var mail_in: LineEdit; var dlg_code: Label
func _build_dialog() -> void:
	var s := sheet("dlg", "진행 상황", "YRD-SAVE", 560.0); var body: VBoxContainer = s[1]; dlg_msg = s[3]; dlg_head = s[0].get_meta("title")
	dlg_title = lbl("", f_title, 30, INK); body.add_child(dlg_title); dlg_text = lbl("", f_body, 13, INK, true); body.add_child(dlg_text)
	dlg_in = LineEdit.new(); dlg_in.custom_minimum_size = Vector2(0, 46); dlg_in.add_theme_font_override("font", f_mono); dlg_in.add_theme_font_size_override("font_size", 15); body.add_child(dlg_in)
	dlg_in.text_submitted.connect(func(_t: String) -> void: _dialog_ok())
	# the code to keep: in a box of its own, wrapped, all of it in sight
	var cb := PanelContainer.new(); cb.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.9), LINE, 1, 12)); body.add_child(cb)
	dlg_code = lbl("", f_mono, 18, SODIUM, true); dlg_code.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY; cb.add_child(dlg_code); dlg_code.set_meta("box", cb)
	# the save code by mail: an address (kept on this device only), the mail app, Gmail, or the whole mail copied
	mail_box = vbox(10); body.add_child(mail_box)
	mail_box.add_child(lbl("이메일로 보내 두기", f_bold, 13, SODIUM))
	mail_in = LineEdit.new(); mail_in.custom_minimum_size = Vector2(0, 46); mail_in.placeholder_text = "받을 주소 (내 이메일, 비워 둬도 됨)"; mail_in.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	mail_in.add_theme_font_override("font", f_bold); mail_in.add_theme_font_size_override("font_size", 16); mail_box.add_child(mail_in)
	mail_in.text_changed.connect(func(t: String) -> void: Store.settings.mailTo = t.strip_edges(); Store.persist_settings())
	var mr := HFlowContainer.new(); mr.add_theme_constant_override("h_separation", 8); mr.add_theme_constant_override("v_separation", 8); mail_box.add_child(mr)
	mr.add_child(btn("메일 앱으로 보내기", "ghost", func() -> void: _send_mail("mailto")))
	mr.add_child(btn("Gmail로 보내기", "ghost", func() -> void: _send_mail("gmail")))
	mr.add_child(btn("메일 내용 복사", "ghost", func() -> void: _copy_mail()))
	mail_box.add_child(lbl("보내 둔 메일 속 코드를 다른 기기나 다시 설치한 앱의 처음 화면 '불러오기'에 넣으면 이어서 할 수 있습니다. 메일 앱이 열리지 않으면 '메일 내용 복사'로 복사해 직접 보내세요. 주소는 이 기기에만 기억됩니다.", f_body, 12, STEEL, true))
	dlg_ok = btn("확인", "primary", _dialog_ok); dlg_ok.set_meta("first", true); dlg_cancel = btn("닫기", "ghost", close_sub)
	s[2].add_child(dlg_ok); s[2].add_child(dlg_cancel); s[2].move_child(dlg_ok, 0); s[2].move_child(dlg_cancel, 1)

## the reset's button is red
func _danger(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = (ALARM if st == "normal" else ALARM.lightened(0.15)) if on else (SODIUM if st == "normal" else SODIUM.lightened(0.15)); b.add_theme_stylebox_override(st, sb)

func open_dialog(kind: String) -> void:
	dlg_kind = kind; dlg_msg.text = ""; dlg_in.visible = kind == "save" or kind == "load" or kind == "dev"; dlg_in.secret = kind == "dev"; dlg_in.editable = kind != "save"; dlg_in.text = ""; dlg_ok.visible = true
	dlg_in.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER if kind == "dev" else LineEdit.KEYBOARD_TYPE_DEFAULT; mail_box.visible = kind == "save"; _danger(dlg_ok, kind == "reset")
	dlg_in.visible = kind == "load" or kind == "dev"; (dlg_code.get_meta("box") as Control).visible = kind == "save"
	match kind:
		"save":
			dlg_head.text = "진행 상황 저장"; dlg_title.text = "저장 코드"; dlg_code.text = SaveCode.encode(Store.save, Store.money_lock, Store.ivory_lock, Store.own_lock); dlg_ok.text = "코드 복사"; dlg_cancel.text = "닫기"
			dlg_text.text = "이 코드를 적어 두거나 복사해 두세요. 처음 화면의 불러오기에 넣으면 지금의 돈, 열린 스테이지, 깬 스테이지, 최단 기록, 무기 편성, 가진 총, 아이템과 상아, 총기 커스텀으로 돌아갑니다. 대여 중인 무기는 코드에 들어가지 않습니다."
			mail_in.text = str(Store.settings.get("mailTo", ""))
		"load":
			dlg_head.text = "진행 상황 불러오기"; dlg_title.text = "불러오기"; dlg_ok.text = "불러오기"; dlg_cancel.text = "취소"; dlg_in.placeholder_text = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXX"
			dlg_text.text = "저장할 때 받은 코드를 넣으세요. 지금 진행 상황은 코드의 내용으로 바뀌고, 대여 중인 무기는 반납됩니다(대여료는 돌려받지 않습니다)." + (" 로그인 중이라 계정의 진행 상황도 코드의 내용으로 바뀝니다." if Cloud.signed_in() else "")
		"reset":
			dlg_head.text = "진행 상황 초기화"; dlg_title.text = "모두 지울까요?"; dlg_ok.text = "초기화"; dlg_cancel.text = "취소"
			dlg_text.text = "돈, 열린 스테이지, 깬 기록, 최단 기록, 무기 편성, 대여 중인 무기, 가진 총, 아이템과 상아, 총기 커스텀을 모두 지우고 처음 상태로 돌아갑니다. 되돌릴 수 없으니 필요하면 먼저 저장 코드를 받아 두세요. 설정(감도, 음량, 개발자 모드)은 그대로입니다." + (" 로그인 중이라 계정에 저장된 진행 상황도 함께 지워집니다." if Cloud.signed_in() else "")
		"dev":
			dlg_head.text = "개발자 모드"; dlg_title.text = "비밀번호"; dlg_ok.text = "켜기"; dlg_cancel.text = "취소"; dlg_in.placeholder_text = "비밀번호"
			dlg_text.text = "개발자 모드를 켜려면 비밀번호를 넣으세요. 켜면 모든 스테이지와 모든 총, 아이템을 무료로 쓸 수 있고 무적이 됩니다(무적은 설정에서 끌 수 있습니다)."
	# the first press: as there, the reset and the save start on 취소/닫기 (so one Enter or Space wipes nothing), the load and the
	# password on their box (focused below, after the screen's first button)
	var calm := kind == "save" or kind == "reset"
	(dlg_cancel if calm else dlg_ok).set_meta("first", true); (dlg_ok if calm else dlg_cancel).remove_meta("first")
	open_sub("dlg")
	if dlg_in.visible: dlg_in.grab_focus.call_deferred()

## the mail: the code, when, the stages cleared and the bag; to the address if one is written
func mail_now() -> Dictionary:
	return SaveCode.mail_text(Store.save, dlg_code.text if dlg_kind == "save" else SaveCode.encode(Store.save, Store.money_lock, Store.ivory_lock, Store.own_lock), SaveCode.now_text())

var last_link := ""   # (the checks read which page was opened)
func _send_mail(how: String) -> void:
	var m := mail_now(); var links := SaveCode.mail_links(mail_in.text, m.subject, m.body); last_link = links[how]
	if OS.has_feature("web"): JavaScriptBridge.eval("try{window.open(%s, '_blank', 'noopener')}catch(e){}" % JSON.stringify(last_link))
	else: OS.shell_open(last_link)
	dlg_msg.text = "메일 앱을 엽니다 · 열리지 않으면 Gmail이나 메일 내용 복사를 써 주세요" if how == "mailto" else "Gmail 쓰기 창을 엽니다"

func _copy_mail() -> void:
	var m := mail_now(); var all: String = m.subject + "\n\n" + str(m.body).replace("\r\n", "\n")
	DisplayServer.clipboard_set(all)
	if OS.has_feature("web"): JavaScriptBridge.eval("try{navigator.clipboard.writeText(%s)}catch(e){}" % JSON.stringify(all))
	dlg_msg.text = "메일 내용을 복사했습니다 · 메일에 붙여 넣어 보내세요"

func _dialog_ok() -> void:
	match dlg_kind:
		"save":
			DisplayServer.clipboard_set(dlg_code.text)
			if OS.has_feature("web"): JavaScriptBridge.eval("try{navigator.clipboard.writeText(%s)}catch(e){}" % JSON.stringify(dlg_code.text))
			dlg_msg.text = "복사했습니다"
		"load":
			var d = SaveCode.decode(dlg_in.text)
			if d == null: dlg_msg.text = "코드가 맞지 않습니다. 글자를 다시 확인해 주세요."; Snd.play("empty"); return
			Store.save = Store.save0(); Store.save.merge(d, true); Store.fix_save(); Store.persist(); Snd.play("buy"); close_sub()
			var done: Array = Store.STAGE_ORDER.filter(func(st): return Store.save.cleared.has(st)).map(func(st): return Store.STAGE_TAG[st])
			set_msg.text = "불러왔습니다 · 가방 " + Store.won(Store.save.money) + " · 깬 스테이지 " + (", ".join(done) if not done.is_empty() else "없음"); on_settings.call()
		"reset":
			Store.save = Store.save0(); Store.fix_save(); Store.persist(); Snd.play("reload0"); close_sub(); set_msg.text = "모든 진행 상황을 지웠습니다"; on_settings.call()
		"dev":
			if SaveCode.dev_hash(dlg_in.text.strip_edges()) != SaveCode.DEV_HASH: dlg_msg.text = "비밀번호가 틀렸습니다"; Snd.play("empty"); return
			Store.settings.dev = true; Store.settings.god = true; Store.persist_settings(); close_sub(); set_msg.text = "개발자 모드 · 모든 스테이지와 모든 총을 쓸 수 있고 무적입니다"; render_settings()

# ================= the account (Cloud): sign in with an id, and the progress is kept on the server too =================
## in: sign in. up: sign up. rc: the recovery code sets a new password. code: the recovery code, shown this once.
## ask: this device's progress or the account's. me: signed in. del: delete the account
var ac_mode := "in"
var ac_body: VBoxContainer; var ac_msg: Label; var ac_head: Label; var ac_ok: Button; var ac_close: Button
var ac_id: LineEdit; var ac_pw: LineEdit; var ac_pw2: LineEdit; var ac_rc: LineEdit; var ac_state: Label
var ac_code := ""; var ac_last_id := ""
func _build_account() -> void:
	var s := sheet("account", "계정", "YRD-ID", 560.0); ac_body = s[1]; ac_msg = s[3]; ac_head = s[0].get_meta("title")
	ac_ok = btn("로그인", "primary", _account_ok); ac_ok.set_meta("first", true); ac_close = btn("닫기", "ghost", back)
	s[2].add_child(ac_ok); s[2].add_child(ac_close); s[2].move_child(ac_ok, 0); s[2].move_child(ac_close, 1)
	Cloud.changed.connect(_account_changed)

## who is signed in, for the menu's top line
func account_badge() -> String:
	if not Cloud.signed_in(): return "게스트"
	return Cloud.id + (" · 골라야 함" if Cloud.asking() else (" · 연결 안 됨" if Cloud.offline else ""))

func open_account() -> void:
	if not Cloud.enabled() or in_stage: return
	ac_mode = "ask" if Cloud.asking() else ("me" if Cloud.signed_in() else "in"); ac_msg.text = "다시 로그인해 주세요" if Cloud.lost else ""
	open_sub("account")

## Esc, the phone's back button, 닫기: not while the recovery code is still on show, and from the delete question back to the account
func close_account() -> void:
	if Cloud.busy: return
	if ac_mode == "code": ac_msg.text = "복구 코드를 적어 두었으면 '적어 두었습니다'를 눌러 주세요"; return
	if ac_mode == "del": _account_mode("me"); return
	close_sub()

func _account_mode(m: String) -> void:
	if ac_id != null: ac_last_id = ac_id.text
	ac_mode = m; ac_msg.text = ""; render_account()
	if not is_touch and ac_id != null: _focus_box.call_deferred(ac_id)   # (a phone's keyboard comes up when the box is tapped, not before)

func _focus_box(e) -> void:
	if is_instance_valid(e) and (e as Control).is_inside_tree() and (e as Control).is_visible_in_tree(): (e as Control).grab_focus()

## a box to type in. On a phone the list moves the box to the top when it is tapped, clear of the keyboard
func _field(hint: String, secret := false, max_len := 64) -> LineEdit:
	var e := LineEdit.new(); e.custom_minimum_size = Vector2(0, 46); e.placeholder_text = hint; e.secret = secret; e.max_length = max_len
	e.add_theme_font_override("font", f_bold); e.add_theme_font_size_override("font_size", 16)
	if secret: e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	e.text_submitted.connect(func(_t: String) -> void: _account_ok())
	e.focus_entered.connect(func() -> void:
		if not is_touch: return
		var sc := ac_body.get_parent() as ScrollContainer
		if sc != null: sc.set_deferred("scroll_vertical", maxi(0, int(e.position.y) - 6)))
	return e

func _note(t: String, color := STEEL) -> void:
	ac_body.add_child(lbl(t, f_body, 12, color, true))

func _row8() -> HFlowContainer:
	var r := HFlowContainer.new(); r.add_theme_constant_override("h_separation", 8); r.add_theme_constant_override("v_separation", 8); ac_body.add_child(r)
	return r

func render_account() -> void:
	clear(ac_body); ac_id = null; ac_pw = null; ac_pw2 = null; ac_rc = null; ac_state = null
	if ac_mode != "code":   # (the recovery code stays on show until it is put away)
		if Cloud.signed_in(): ac_mode = "ask" if Cloud.asking() else ("del" if ac_mode == "del" else "me")
		elif ac_mode != "up" and ac_mode != "rc": ac_mode = "in"
	_danger(ac_ok, ac_mode == "del"); ac_ok.visible = ac_mode != "ask"; ac_close.visible = ac_mode != "code" and ac_mode != "me"; ac_close.text = "닫기"
	match ac_mode:
		"in":
			ac_head.text = "계정 · 로그인"; ac_ok.text = "로그인"
			ac_id = _field("아이디", false, Cloud.ID_MAX); ac_id.text = ac_last_id; ac_body.add_child(ac_id)
			ac_pw = _field("비밀번호", true, Cloud.PW_MAX); ac_body.add_child(ac_pw)
			var row := _row8()
			row.add_child(btn("회원가입", "small", func() -> void: _account_mode("up")))
			row.add_child(btn("비밀번호를 잊었어요 (복구 코드)", "small", func() -> void: _account_mode("rc")))
			_note("로그인하면 진행 상황이 계정에도 저장되어 휴대폰, PC, 웹 어디서든 같은 아이디로 이어서 할 수 있습니다. 로그인하지 않아도 지금처럼 이 기기에 저장하며 계속 할 수 있습니다.")
		"up":
			ac_head.text = "계정 · 회원가입"; ac_ok.text = "가입하기"
			ac_id = _field("아이디 (영문 소문자, 숫자, 밑줄 · %d~%d자)" % [Cloud.ID_MIN, Cloud.ID_MAX], false, Cloud.ID_MAX); ac_id.text = ac_last_id; ac_body.add_child(ac_id)
			ac_pw = _field("비밀번호 (%d자 이상)" % Cloud.PW_MIN, true, Cloud.PW_MAX); ac_body.add_child(ac_pw)
			ac_pw2 = _field("비밀번호 한 번 더", true, Cloud.PW_MAX); ac_body.add_child(ac_pw2)
			_row8().add_child(btn("이미 계정이 있어요 (로그인)", "small", func() -> void: _account_mode("in")))
			_note("이메일이나 이름은 받지 않습니다. 서버에는 아이디, 알아볼 수 없게 바꾼 비밀번호, 게임 진행 상황만 저장됩니다. 가입하면 이 기기의 지금 진행 상황이 계정에 저장됩니다.")
		"rc":
			ac_head.text = "계정 · 비밀번호 다시 정하기"; ac_ok.text = "새 비밀번호로 바꾸기"
			ac_id = _field("아이디", false, Cloud.ID_MAX); ac_id.text = ac_last_id; ac_body.add_child(ac_id)
			ac_rc = _field("복구 코드 (XXXX-XXXX-XXXX-XXXX)", false, 40); ac_rc.add_theme_font_override("font", f_mono); ac_body.add_child(ac_rc)
			ac_pw = _field("새 비밀번호 (%d자 이상)" % Cloud.PW_MIN, true, Cloud.PW_MAX); ac_body.add_child(ac_pw)
			ac_pw2 = _field("새 비밀번호 한 번 더", true, Cloud.PW_MAX); ac_body.add_child(ac_pw2)
			_row8().add_child(btn("로그인으로 돌아가기", "small", func() -> void: _account_mode("in")))
			_note("가입할 때 받은 복구 코드로 새 비밀번호를 정합니다. 바꾸면 복구 코드도 새것으로 바뀌고, 로그인해 둔 다른 기기는 모두 로그아웃됩니다.")
		"code":
			ac_head.text = "계정 · 복구 코드"; ac_ok.text = "적어 두었습니다"
			ac_body.add_child(lbl("복구 코드", f_title, 30, INK))
			var cb := PanelContainer.new(); cb.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.9), LINE, 1, 12)); ac_body.add_child(cb)
			cb.add_child(lbl(ac_code, f_mono, 22, SODIUM))
			_row8().add_child(btn("코드 복사", "small", func() -> void:
				DisplayServer.clipboard_set(ac_code)
				if OS.has_feature("web"): JavaScriptBridge.eval("try{navigator.clipboard.writeText(%s)}catch(e){}" % JSON.stringify(ac_code))
				ac_msg.text = "복사했습니다"))
			_note("비밀번호를 잊었을 때 새 비밀번호를 정할 수 있는 하나뿐인 방법입니다. 지금 한 번만 보여 드리니 꼭 적어 두거나 복사해 두세요. 이 코드를 아는 사람은 비밀번호를 바꿀 수 있으니 남에게 보여 주지 마세요.", INK)
		"ask":
			ac_head.text = "계정 · 진행 상황 고르기"; ac_close.text = "나중에"
			_note("이 기기와 계정(%s)의 진행 상황이 다릅니다. 어느 쪽으로 이어서 할지 골라 주세요. 고르지 않은 쪽의 진행 상황은 사라집니다." % Cloud.id, INK)
			var two := GridContainer.new(); two.columns = 2 if size.x >= 560.0 else 1; two.add_theme_constant_override("h_separation", 10); two.add_theme_constant_override("v_separation", 10)   # side by side where there is room: both in sight at once
			two.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ac_body.add_child(two)
			for side in ["device", "account"]:
				var pn := PanelContainer.new(); pn.add_theme_stylebox_override("panel", _box(Color(NIGHT, 0.6), LINE, 1, 10)); pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; two.add_child(pn)
				var pv := vbox(6); pn.add_child(pv)
				var saved_at := Cloud.when(int(Cloud.ask.get("updated", 0)))
				pv.add_child(lbl("이 기기" if side == "device" else ("계정" + (" · 마지막 저장 " + saved_at if saved_at != "" else "")), f_bold, 14, SODIUM))
				pv.add_child(lbl(Cloud.summary(Store.stored() if side == "device" else Cloud.ask.get("data", {})).replace(" · ", "\n"), f_body, 13, INK, true))   # (a line each: the bag, the stages, the guns)
				pv.add_child(btn("이 기기 것으로 이어 하기" if side == "device" else "계정 것으로 이어 하기", "ghost", func() -> void: _account_choose(side)))
		"me":
			ac_head.text = "계정"; ac_ok.text = "닫기"
			ac_body.add_child(lbl(Cloud.id, f_title, 30, INK))
			ac_state = lbl(Cloud.status_text(), f_body, 13, INK, true); ac_body.add_child(ac_state)
			var row5 := _row8()
			row5.add_child(btn("지금 저장", "small", func() -> void: _account_sync()))
			row5.add_child(btn("로그아웃", "small", func() -> void: _account_out()))
			row5.add_child(btn("계정 삭제", "small", func() -> void: _account_mode("del")))
			_note("진행 상황은 바뀔 때마다 계정에 저장됩니다. 다른 기기에서도 같은 아이디로 로그인하면 이어서 할 수 있습니다. 로그아웃해도 이 기기의 진행 상황은 그대로 남습니다. 비밀번호를 바꾸려면 로그아웃한 뒤 '비밀번호를 잊었어요'에서 복구 코드로 새로 정하세요.")
		"del":
			ac_head.text = "계정 · 삭제"; ac_ok.text = "계정 삭제"; ac_close.text = "취소"
			ac_body.add_child(lbl("계정을 지울까요?", f_title, 30, INK))
			_note("계정(%s)과 계정에 저장된 진행 상황을 서버에서 모두 지웁니다. 되돌릴 수 없습니다. 이 기기에 있는 진행 상황은 그대로 남습니다. 비밀번호를 넣어 확인해 주세요." % Cloud.id, INK)
			ac_pw = _field("비밀번호", true, Cloud.PW_MAX); ac_body.add_child(ac_pw)
	if is_touch and (ac_id != null or ac_pw != null):   # room to move a box up clear of the phone's keyboard
		var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 240); sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; ac_body.add_child(sp)
	_account_busy()

func _account_busy() -> void:
	ac_ok.disabled = Cloud.busy
	for b in ac_body.find_children("*", "Button", true, false): (b as Button).disabled = Cloud.busy
	if Cloud.busy: ac_msg.text = ("비밀번호를 암호로 바꾸는 중… %d%%" % roundi(Cloud.progress * 100.0)) if (Cloud.progress > 0.0 and Cloud.progress < 1.0) else "서버와 이야기하는 중…"

func _account_fail(r: Dictionary) -> void:
	ac_msg.text = str(r.get("error", ""))
	if ac_msg.text != "": Snd.play("empty")
	_account_busy()

func _account_ok() -> void:
	if Cloud.busy: return
	match ac_mode:
		"in":
			ac_last_id = ac_id.text
			var r: Dictionary = await Cloud.sign_in(ac_id.text, ac_pw.text)
			if not r.ok: _account_fail(r); return
			Snd.play("buy"); ac_mode = "me"; ac_msg.text = "" if Cloud.asking() else "로그인했습니다"; render_account()
		"up":
			ac_last_id = ac_id.text
			if ac_pw.text != ac_pw2.text: _account_fail({"error": "비밀번호가 서로 다릅니다"}); return
			var r2: Dictionary = await Cloud.sign_up(ac_id.text, ac_pw.text)
			if not r2.ok: _account_fail(r2); return
			Snd.play("buy"); ac_code = str(r2.get("recovery", "")); ac_mode = "code"; ac_msg.text = "가입했습니다 · 복구 코드를 적어 두세요"; render_account()
		"rc":
			ac_last_id = ac_id.text
			if ac_pw.text != ac_pw2.text: _account_fail({"error": "비밀번호가 서로 다릅니다"}); return
			var r3: Dictionary = await Cloud.recover(ac_id.text, ac_rc.text, ac_pw.text)
			if not r3.ok: _account_fail(r3); return
			Snd.play("buy"); ac_code = str(r3.get("recovery", "")); ac_mode = "code"; ac_msg.text = "비밀번호를 바꿨습니다 · 새 복구 코드를 적어 두세요"; render_account()
		"code":
			ac_code = ""; ac_mode = "me"; ac_msg.text = "" if Cloud.asking() else "로그인했습니다 · 진행 상황이 계정에 저장됩니다"; render_account()
		"me": close_sub()
		"del":
			var r4: Dictionary = await Cloud.delete_account(ac_pw.text)
			if not r4.ok: _account_fail(r4); return
			Snd.play("reload0"); ac_mode = "in"; ac_msg.text = "계정을 지웠습니다 · 이 기기의 진행 상황은 그대로입니다"; render_account()

func _account_choose(side: String) -> void:
	if Cloud.busy: return
	await Cloud.choose(side)
	if Cloud.asking(): ac_msg.text = "서버에 연결하지 못했습니다. 잠시 뒤에 다시 골라 주세요."; Snd.play("empty"); render_account(); return
	Snd.play("buy"); ac_mode = "me"; ac_msg.text = "이 기기의 진행 상황을 계정에 저장했습니다" if side == "device" else "계정의 진행 상황을 불러왔습니다"; render_account()

func _account_sync() -> void:
	if Cloud.busy: return
	await Cloud.sync_now()
	ac_msg.text = "" if (Cloud.asking() or not Cloud.signed_in()) else ("서버에 연결하지 못했습니다" if Cloud.offline else "계정에 저장했습니다"); render_account()

func _account_out() -> void:
	if Cloud.busy: return
	await Cloud.sign_out()
	ac_mode = "in"; ac_msg.text = "로그아웃했습니다 · 이 기기의 진행 상황은 그대로입니다"; render_account()

## the account has changed under the screens: the menu's top line and the settings follow, the account's own screen keeps
## what is being typed, and a choice that turns up while the menu is on show opens by itself
func _account_changed(what: String) -> void:
	if what == "busy":
		if cur == "account": _account_busy()
		return
	if what == "applied": on_settings.call()   # (the guns' parts and paint, the menu's numbers)
	if cur == "menu":
		refresh_menu()
		if what == "ask" and not in_stage: open_account()
	elif cur == "settings": render_settings()
	elif cur == "account" and not Cloud.busy:
		if what == "sync" and ac_mode != "ask":
			if ac_state != null: ac_state.text = Cloud.status_text()
		elif ac_mode != "code": render_account()

# ================= the briefing =================
func _build_brief() -> void:
	var s := sheet("brief", "작전 브리핑 · 위에서 본 지도", "스테이지 1", 760.0); br_body = s[1]; br_code = s[0].get_meta("code")
	br_title = lbl("", f_title, 36, INK); br_body.add_child(br_title)
	br_box = BoxContainer.new(); br_box.vertical = true; br_box.add_theme_constant_override("separation", 14); br_body.add_child(br_box)
	br_map = Control.new(); br_map.custom_minimum_size = Vector2(260, 260); br_map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; br_box.add_child(br_map)
	br_map.draw.connect(func() -> void: tac.draw(br_map, br_map.size))
	br_side = vbox(10); br_box.add_child(br_side)
	br_modes = _flow(); br_modes.alignment = FlowContainer.ALIGNMENT_BEGIN; br_modes.add_theme_constant_override("h_separation", 10); br_modes.add_theme_constant_override("v_separation", 14); br_side.add_child(br_modes)
	br_modes.draw.connect(func() -> void:   # the shelf's plank under each row of packages
		if sel != Store.ST_TOY: return
		var rows := {}
		for c in br_modes.get_children():
			if c is Control and (c as Control).visible: rows[roundi((c as Control).position.y + (c as Control).size.y)] = true
		for y in rows: ToyKit.plank(br_modes, Rect2(-4.0, float(y) - 6.0, br_modes.size.x + 8.0, 9.0)))
	br_leg_h = _flow(); br_side.add_child(br_leg_h); br_leg_v = vbox(6); br_side.add_child(br_leg_v)
	br_gear = lbl("", f_body, 13, SODIUM, true); br_side.add_child(br_gear); br_note = lbl("", f_body, 13, INK, true); br_side.add_child(br_note)
	br_go = btn("출동", "primary", func() -> void: _deploy()); br_go.set_meta("first", true)
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("무기 편성", "ghost", func() -> void: open_sub("loadout")); var b3 := btn("돌아가기", "ghost", func() -> void: do_menu.call())
	for i in 4: s[2].add_child([br_go, b1, b2, b3][i]); s[2].move_child([br_go, b1, b2, b3][i], i)

func open_brief(stage: int) -> void:
	sel = stage; game.begin(stage); tac.setup(stage); back_stack.clear(); show_screen("brief"); _legend(br_leg_h, br_leg_v, false)
	br_code.text = "스테이지 " + Store.STAGE_TAG[stage]; br_title.text = Game.STAGES[stage].name + (" · " + ToyMatch.SHORT[game.tm.key] if game.tm != null else (" · " + str(Realm.NAMES[game.rm.key]) if game.rm != null else ""))
	if game.rm != null and game.rm.key == "plain": br_title.text = Game.STAGES[stage].name + " · " + str(Races.R[Realm.picked_race()].name) + "로 출전"
	br_note.text = Game.STAGES[stage].intro + (("\n동물 %d마리 · 감시탑 체력 10,000" % game.goal if stage == 7 else ("\n적 %d%s" % [game.goal, Game.STAGES[stage].unit] if game.boss == null else "\n" + game.boss_msg + "\n적 %d · 보스 1" % (game.goal - 1))) if game.goal > 0 else "")
	if game.tm != null: br_note.text = game.tm.mode.brief() + ("\n이미 이긴 모드라 다시 하기 보상은 없습니다" if game.replay else "\n첫 승리 보너스 " + Store.won(game.tm.mode.bonus()))
	if game.rm != null: br_note.text = "\n".join(PackedStringArray(game.rm.mode.brief())) + ("\n이미 이긴 모드라 다시 하기 보상은 없습니다" if game.replay else "\n첫 승리 보너스 " + Store.won(game.rm.mode.bonus()))
	if game.rm != null and game.rm.key == "plain": br_note.text = "\n".join(PackedStringArray(game.rm.mode.brief())) + ("\n이 종족으로 이미 깼습니다 · 다시 하기 보상은 없습니다" if game.replay else "\n이 종족으로 처음 깨면 보너스 " + Store.won(game.rm.mode.bonus()))
	_mode_buttons(stage); br_map.queue_redraw()

## a button that is a picture: `paint` draws it (it is handed the button), a press calls `cb`
func _pack(min_size: Vector2, paint: Callable, cb: Callable = Callable()) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = min_size
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func() -> void: paint.call(b))
	for sg in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]: (sg as Signal).connect(b.queue_redraw)
	if cb.is_valid(): b.pressed.connect(cb)
	return b

## how big a mode's package is on this screen: four to the row beside (or under) the map, two when there is no room for four
func _pack_size() -> Vector2:
	var short := size.x > size.y and size.y <= 600.0; var inner := minf(980.0 if short else 760.0, size.x - 16.0) - 32.0
	var room := inner - 24.0 - ((maxf(minf(size.y - 140.0, size.x * 0.56), 140.0) + 14.0) if short else 0.0)   # (less the sheet's scroll bar; on a short screen the map takes its square first)
	var per := 4 if room >= 430.0 else 2; var w := clampf(floorf((room - (per - 1) * 10.0) / per), 96.0, 160.0)
	return Vector2(w, roundf(w * (0.98 if short else 1.08)))

## stage 5's modes, as packages on a toy shop's shelf: each a card with what the mode is about under a clear bubble, its
## name and a price tag (the first win's bonus); the one picked edged in yellow. A press tears another open (a rip, and
## what is inside springs out) and builds the room for it
var _torn := ""
func _mode_buttons(stage: int) -> void:
	clear(br_modes); br_modes.visible = stage == Store.ST_TOY or stage == Store.ST_ELF or stage == Store.ST_PLAIN
	if stage == Store.ST_ELF: _realm_buttons(); return
	if stage == Store.ST_PLAIN: _realm_buttons(false); return   # (6-2: no modes, only your people and your bomb)
	if stage != Store.ST_TOY: return
	var cur_mode := ToyMatch.picked(); var ps := _pack_size()
	for k: String in ToyMatch.MODES:
		var won: bool = Store.save.cleared.has(Store.ST_TOY) if k == "sweep" else Store.save.best.has("t9" + k.substr(0, 1))
		var tag: String = ("장난감 %d개" % int(Game.STAGES[Store.ST_TOY].goal)) if k == "sweep" else ("다시 하기" if won else "첫 승리 +" + Store.won(ToyMode.new().bonus()))
		var b := _pack(ps, func(c: Button) -> void:
			ToyKit.pack(c, c.size, ToyMatch.NAMES[k], Color(str(ToyKit.MODE_CARD[k])), tag, k == cur_mode, c.is_hovered() or c.has_focus(), won, func(r: Rect2) -> void: ToyKit.scene(c, k, r), float(c.get_meta("pop", 0.0))),
			func() -> void: _pick_mode(k))
		b.set_meta("mode", k); b.tooltip_text = ToyMatch.NAMES[k]; br_modes.add_child(b)
		if k == cur_mode and _torn == k and is_inside_tree():
			create_tween().tween_method(func(v: float) -> void:
				if is_instance_valid(b): b.set_meta("pop", v); b.queue_redraw(), 0.0, 1.0, 0.5)
	_torn = ""

func _pick_mode(k: String) -> void:
	if ToyMatch.picked() == k: return
	Store.settings.toyMode = k; Store.persist_settings(); Snd.play("toy_rip"); _torn = k; open_brief(9)

func _brief_gear() -> void:
	if (sel == Store.ST_ELF and Realm.picked() != "solo") or sel == Store.ST_PLAIN:   # (a realm battle: your people's own arms, not the layout)
		var R: Dictionary = Races.R[Realm.picked_race()]
		br_gear.text = "%s · %s · 룬 단검 · 연금술 폭탄\n좌클릭 공격 · 우클릭 특수 · Shift 이동기 · Q(또는 G) 폭탄 · V 단검 · F 튕겨내기 · X 비전 비기 · B 룬 제단(%s)" % [str(R.name), str(R.weapon), "준비 시간이나 우리 건물 곁" if sel == Store.ST_PLAIN else "준비 시간"]
		br_gear.add_theme_color_override("font_color", SODIUM); br_go.disabled = false; return
	if sel == Store.ST_TOY:   # (first: the toy room's nine toy guns are not the layout, and its spray can is no gun of Weapons.LIST)
		var k := ToyMatch.picked()
		br_gear.text = "장난감 무기 9종 · 1-9번 키(무기 편성 순서가 앞 번호)" + {"rush": " · 건전지를 들면 다트 권총과 30cm 자만", "escort": " · 화물칸 탄약 상자에서 보급", "freeze": " · 탄산 캔 G"}.get(k, ""); br_go.disabled = false; return
	var ready := []; var lo := game.layout()
	for i in 7:
		if lo[i] != null: ready.push_back("%d %s" % [i + 1, Weapons.LIST[lo[i]].short])
	var fit := Meta.fits(sel)
	br_gear.text = ("지도 오른쪽 아래 구석(동남쪽 끝)에 내립니다\n" if sel == Store.ST_ARMED else "") + ("출동하면 쓸 무기 · " + " · ".join(ready) if not ready.is_empty() else "넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다") + "\n권장 스펙 · " + ("적합" if fit else "부적합")
	br_gear.add_theme_color_override("font_color", SODIUM if fit else ALARM); br_go.disabled = ready.is_empty()

func _deploy() -> void:
	game.guns.reset(game.layout())   # what the shop and the layout changed since the briefing opened
	if game.guns.none and game.rm == null: return
	game.deployed = true   # (from here on the rentals are used: they go back when the stage ends)
	back_stack.clear(); show_screen(""); do_deploy.call()

# ================= the tactical map =================
func _flow() -> HFlowContainer:
	var f := HFlowContainer.new(); f.add_theme_constant_override("h_separation", 14); f.add_theme_constant_override("v_separation", 6); f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return f

## what each mark on the map means: a row of items under the map, or a column beside it on a short screen
func _legend(h: HFlowContainer, v: VBoxContainer, live: bool) -> void:
	clear(h); clear(v)
	for it: Array in tac.legend(live):
		for box: Container in [h, v]:
			var row := hbox(6); var ic := Control.new(); ic.custom_minimum_size = Vector2(18, 18); ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ic.draw.connect(func() -> void: tac.legend_icon(ic, it)); row.add_child(ic); row.add_child(lbl(str(it[1]), f_body, 12, Color("cfd5e0"))); box.add_child(row)
	h.visible = not map_short; v.visible = map_short

func _build_map() -> void:
	var s := sheet("map", "작전 지도", "처치 0 / 100", 760.0); var body: VBoxContainer = s[1]; mp_code = s[0].get_meta("code"); mp_hint = s[3]
	mp_box = BoxContainer.new(); mp_box.vertical = true; mp_box.add_theme_constant_override("separation", 14); body.add_child(mp_box)
	mp_map = Control.new(); mp_map.custom_minimum_size = Vector2(260, 260); mp_map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mp_box.add_child(mp_map)
	mp_map.draw.connect(func() -> void: tac.draw(mp_map, mp_map.size))
	mp_side = vbox(10); mp_box.add_child(mp_side); mp_leg_h = _flow(); mp_side.add_child(mp_leg_h); mp_leg_v = vbox(6); mp_side.add_child(mp_leg_v)
	var b := btn("닫기", "primary", func() -> void: do_map_close.call()); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)
	mp_hint.add_theme_color_override("font_color", STEEL)

## the map screen, over the paused fight
## stage 6-1's choices on the briefing: the wood on your own, or one of the two team battles; for a battle, your people and
## the alchemical bomb you carry
func _realm_buttons(modes := true) -> void:
	var box := vbox(8); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; br_modes.add_child(box)
	var cur := Realm.picked(); var race := Realm.picked_race(); var bomb := Realm.picked_bomb()
	var row := func(title: String, items: Array, picked: String, cb: Callable) -> void:
		box.add_child(lbl(title, f_mono, 11, STEEL))
		var f := _flow(); f.alignment = FlowContainer.ALIGNMENT_BEGIN; f.add_theme_constant_override("h_separation", 8); box.add_child(f)
		for it: Array in items:
			var b := btn(str(it[1]), "primary" if it[0] == picked else "ghost", func() -> void: cb.call(str(it[0])))
			b.set_meta("pick", it[0]); f.add_child(b)
	if modes:
		row.call("작전", Realm.MODES.map(func(k): return [k, Realm.NAMES[k]]), cur, func(k: String) -> void: _pick_setting("realmMode", k))
		if cur == "solo": return
	row.call("종족", Races.ORDER.map(func(r): return [r, Races.R[r].name]), race, func(r: String) -> void: _pick_setting("realmRace", r))
	var R: Dictionary = Races.R[race]
	box.add_child(lbl("%s · 체력 %d · 이동 %.1f m/s · 교전 거리 %s\n무기 %s · 패시브 %s · 이동기 %s · 비전 비기 %s" % [str(R.role), int(R.hp), float(R.speed), str(R.range), str(R.weapon), str(R.passive), str(R.skill), str(R.ult)], f_body, 12, INK, true))
	row.call("연금술 폭탄", Races.BOMBS.map(func(b): return [b, Races.BOMB[b].name]), bomb, func(b: String) -> void: _pick_setting("realmBomb", b))
	box.add_child(lbl(str(Races.BOMB[bomb].text), f_body, 12, INK, true))

func _pick_setting(key: String, v: String) -> void:
	if str(Store.settings.get(key, "")) == v: return
	Store.settings[key] = v; Store.persist_settings(); Snd.play("reload0"); open_brief(sel)

# ================= the rune altar =================
## a realm battle's preparation: your people and your bombs changed, runes cut into the three slots for shards (and, when
## your side holds the tower, where its two summoning traps lie). The fight waits while it is open
var al_body: VBoxContainer; var do_altar_close: Callable
func _build_altar() -> void:
	var s := sheet("altar", "고대 룬 제단", "RUNE-ALTAR", 760.0); al_body = s[1]
	var b := btn("닫기", "primary", func() -> void: do_altar_close.call()); b.set_meta("first", true); s[2].add_child(b); s[2].move_child(b, 0)

func open_altar() -> void:
	render_altar(); show_screen("altar")

func render_altar() -> void:
	var rm: Realm = game.rm
	if rm == null or rm.me == null: return
	var f: Realm.Fighter = rm.me
	clear(al_body)
	al_body.add_child(lbl("마력 파편 %d" % f.shards, f_title, 30, Color("ffd66b")))
	var row := func(title: String, items: Array, picked: Array, cb: Callable, off: Array = []) -> void:
		al_body.add_child(lbl(title, f_mono, 11, STEEL))
		var fl := _flow(); fl.alignment = FlowContainer.ALIGNMENT_BEGIN; fl.add_theme_constant_override("h_separation", 8); al_body.add_child(fl)
		for it: Array in items:
			var b := btn(str(it[1]), "primary" if picked.has(it[0]) else "ghost", func() -> void: cb.call(it[0]); render_altar())
			b.disabled = off.has(it[0]); b.set_meta("pick", it[0]); fl.add_child(b)
	row.call("종족 (다른 종족의 각인은 값을 돌려받습니다)", Races.ORDER.map(func(r): return [r, Races.R[r].name]), [f.race], func(r) -> void:
		rm.become(f, str(r)); Store.settings.realmRace = str(r); Store.persist_settings())
	row.call("연금술 폭탄", Races.BOMBS.map(func(b): return [b, Races.BOMB[b].name]), [f.bomb_kinds[0]], func(b) -> void:
		f.bomb_kinds = [str(b)]; rm.refit(f); Store.settings.realmBomb = str(b); Store.persist_settings())
	if f.rune("c_pouch"):
		row.call("둘째 폭탄 (이중 연금술 주머니)", Races.BOMBS.filter(func(b): return b != f.bomb_kinds[0]).map(func(b): return [b, Races.BOMB[b].name]), [f.bomb_kinds[1]] if f.bomb_kinds.size() > 1 else [], func(b) -> void:
			f.bomb_kinds = [f.bomb_kinds[0], str(b)]; f.bombs = 2)
	for slot: String in ["a", "b", "c"]:
		al_body.add_child(lbl("슬롯 %s · %s" % [slot.to_upper(), str(Races.SLOTS[slot])], f_bold, 14, SODIUM))
		for id: String in Races.runes_for(f.race, slot):
			var q: Dictionary = Races.RUNES[id]; var own := str(f.runes[slot]) == id
			var back := rm.cost_of(str(f.runes[slot])) if str(f.runes[slot]) != "" else 0
			var line := hbox(10)
			var b := btn(("%s · 장착됨 (누르면 뺍니다)" % str(q.name)) if own else "%s · 파편 %d" % [str(q.name), int(q.cost)], "primary" if own else "ghost", func() -> void:
				if own: rm.sell(f, slot)
				else: rm.buy(f, id)
				Snd.play("rm_shard"); render_altar())
			b.disabled = not own and f.shards + back < int(q.cost); b.set_meta("rune", id); line.add_child(b)
			var t := lbl(str(q.text), f_body, 12, INK, true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(t); al_body.add_child(line)
	if rm.mode is ModeSiege and (rm.mode as ModeSiege).defenders() == "us":   # your side holds the tower: where its two traps lie
		var sg: ModeSiege = rm.mode
		row.call("역소환 함정진 자리 (둘)", range(ModeSiege.SLOTS.size()).map(func(i): return [i, ModeSiege.SLOTS[i][0]]), sg.trap_pick, func(i) -> void:
			if sg.trap_pick.has(i): return
			sg.trap_pick = [sg.trap_pick[1], int(i)]; sg._lay_traps())

func open_map(touch: bool) -> void:
	tac.setup(game.stage); mp_code.text = ("스테이지 %s · %s" % [Store.STAGE_TAG[game.stage], ToyMatch.SHORT[game.tm.key]]) if game.tm != null else ("스테이지 %s · %s" % [Store.STAGE_TAG[game.stage], str(Realm.NAMES[game.rm.key])]) if game.rm != null else "스테이지 %s · 처치 %d / %d" % [Store.STAGE_TAG[game.stage], game.kills, game.goal]
	mp_hint.text = "게임 중 오른쪽 위 지도 버튼으로 다시 열 수 있습니다" if touch else "M 키로 열고 닫기"
	_legend(mp_leg_h, mp_leg_v, true); show_screen("map"); mp_map.queue_redraw()

## the map's size: under the title on a tall screen, at the left beside everything else on a short landscape one
func _layout_maps() -> void:
	if br_box == null: return
	var short := size.x > size.y and size.y <= 600.0; map_short = short
	for key in ["brief", "map"]: (screens[key].get_meta("panel") as PanelContainer).set_meta("max_w", 980.0 if short else 760.0)
	var inner := minf(980.0 if short else 760.0, size.x - 16.0) - 32.0
	# a short screen: what is left of the height once the sheet's edges, its heading and the button row are taken (16 + 32 + 18 + 20 + 52)
	var side_b := minf(size.y - 140.0, size.x * 0.56) if short else minf(minf(inner, size.y - 300.0), 620.0)
	var side_m := minf(size.y - 140.0, size.x * 0.56) if short else minf(minf(inner, size.y - 240.0), 620.0)
	for q in [[br_box, br_map, maxf(side_b, 140.0), br_leg_h, br_leg_v], [mp_box, mp_map, maxf(side_m, 140.0), mp_leg_h, mp_leg_v]]:
		var bx: BoxContainer = q[0]; var m: Control = q[1]
		bx.vertical = not short; m.custom_minimum_size = Vector2(q[2], q[2]); m.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if short else Control.SIZE_SHRINK_CENTER
		(q[3] as Control).visible = not short; (q[4] as Control).visible = short; m.queue_redraw()
	var want: Node = br_side if short else br_body
	if br_title.get_parent() != want: br_title.reparent(want); want.move_child(br_title, 0)
	if br_modes.get_parent() != want: br_modes.reparent(want)   # (stage 5's shelf: under the title, over the map)
	want.move_child(br_modes, br_title.get_index() + 1)
	var ps := _pack_size()   # (its packages keep to the room there is)
	for c in br_modes.get_children():
		if c.has_meta("mode"): (c as Control).custom_minimum_size = ps

# ================= pause =================
func _build_pause() -> void:
	var s := sheet("pause", "작업 지시서 · 단독 작전", "YRD-PAUSE", 560.0); pa_body = s[1]
	var b := btn("계속하기", "primary", func() -> void: do_resume.call()); b.set_meta("first", true)
	var bm := btn("지도", "ghost", func() -> void: do_map.call("pause"))
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("무기 편성", "ghost", func() -> void: open_sub("loadout")); var b3 := btn("작전 포기", "ghost", func() -> void: do_quit.call())
	for i in 5: s[2].add_child([b, bm, b1, b2, b3][i]); s[2].move_child([b, bm, b1, b2, b3][i], i)

func render_pause() -> void:
	clear(pa_body); pa_body.add_child(lbl("일시정지", f_title, 48, INK))
	if pa_note_text != "": pa_body.add_child(lbl(pa_note_text, f_body, 13, SODIUM, true))
	pa_body.add_child(lbl((game.tm.summary() + " · 처치 %d" % game.kills if game.tm != null else (game.rm.mode.pause_line() + " · 처치 %d" % game.kills if game.rm != null else "처치 %d / %d" % [game.kills, game.goal])) + " · 가방 %s" % Store.won(Store.save.money), f_mono, 13, INK, true))
	if not guns.none: _gun_order(pa_body, render_pause)
	_settings_rows(pa_body, false)
var pa_note_text := ""

# ================= the result sheet =================
func _build_over() -> void:
	var s := sheet("over", "작전 결과 보고", "—", 620.0); var body: VBoxContainer = s[1]
	ov.code = s[0].get_meta("code"); ov.stamp = lbl("작전 실패", f_title, 20, ALARM); body.add_child(ov.stamp)
	ov.title = lbl("", f_title, 40, INK, true); body.add_child(ov.title)
	var grid := GridContainer.new(); grid.columns = 5 if size.x >= 560 else 2; grid.add_theme_constant_override("h_separation", 18); grid.add_theme_constant_override("v_separation", 8); body.add_child(grid); ov.grid = grid
	for k in [["kills", "처치"], ["earn", "번 돈"], ["hs", "헤드샷"], ["acc", "명중률"], ["time", "시간"]]:
		var v := vbox(0); v.add_child(lbl(k[1], f_mono, 11, STEEL)); ov[k[0]] = lbl("0", f_bold, 20, INK); v.add_child(ov[k[0]]); grid.add_child(v)
	ov.best = lbl("", f_body, 13, STEEL, true); body.add_child(ov.best)
	ov.again = btn("다시 도전", "primary", func() -> void: do_again.call(game.stage)); ov.again.set_meta("first", true)
	ov.next = btn("", "primary", func() -> void: do_again.call(int(ov.next.get_meta("st")))); ov.next2 = btn("", "primary", func() -> void: do_again.call(int(ov.next2.get_meta("st"))))
	var b1 := btn("상점", "ghost", func() -> void: shop_ctx = sel; open_sub("shop")); var b2 := btn("처음 화면", "ghost", func() -> void: do_menu.call())
	for i in 5: s[2].add_child([ov.again, ov.next, ov.next2, b1, b2][i]); s[2].move_child([ov.again, ov.next, ov.next2, b1, b2][i], i)

func show_result(kind: String) -> void:
	var clear_ := kind == "clear"; var st: Dictionary = game.stats; var tag: String = Store.STAGE_TAG[game.stage]
	(ov.stamp as Label).text = "임무 완료" if clear_ else ("감염" if kind == "zombie" else ("중독" if kind == "poison" else ("출혈" if kind == "bleed" else ("레이저" if kind == "laser" else "작전 실패")))); (ov.stamp as Label).add_theme_color_override("font_color", VITAL if clear_ else ALARM)
	var md = game.tm.mode if game.tm != null else (game.rm.mode if game.rm != null else null)
	if md != null:   # a team match (stage 5's modes, stage 6's battles): its own stamp and title
		(ov.stamp as Label).text = "임무 완료" if clear_ else md.lose_stamp
	(ov.title as Label).text = (md.win_title() if clear_ else md.lose_title) if md != null else "스테이지 %s 클리어" % tag if clear_ else ("좀비가 되었습니다" if kind == "zombie" else ("독이 퍼져 쓰러졌습니다" if kind == "poison" else ("고릴라에게 짓눌렸습니다" if kind == "slam" else ("피를 너무 많이 흘렸습니다" if kind == "bleed" else ("보스 드론의 레이저에 맞았습니다" if kind == "laser" else "스테이지 %s · 쓰러짐" % tag)))))
	(ov.kills as Label).text = ("%d · %d 대 %d" % [st.kills, game.tm.score.us, game.tm.score.them]) if game.tm != null else ("%d · %d 대 %d" % [st.kills, game.rm.score("us"), game.rm.score("them")]) if game.rm != null else "%d%s / %d" % [st.kills, " + 길들임 %d" % game.calm if game.calm > 0 else "", game.goal]; (ov.earn as Label).text = Store.won(st.earned); (ov.hs as Label).text = str(st.heads)
	(ov.earn as Label).add_theme_color_override("font_color", ALARM if (not clear_ and st.earned > 0) else INK)
	(ov.acc as Label).text = "%d%%" % (roundi(100.0 * st.hits / st.shots) if st.shots > 0 else 0); (ov.time as Label).text = Store.fmt_time(st.time)
	(ov.code as Label).text = "보고 번호 " + Store.iso_code("YRD", (game.stage * 100000 + st.kills * 997) % 1000000)
	(ov.again as Button).text = "다시 하기" if clear_ else "다시 도전"
	var nx: Array = Store.next_stages(game.stage) if clear_ else []
	for i in 2:
		var b: Button = [ov.next, ov.next2][i]; b.visible = i < nx.size()
		if i < nx.size(): b.set_meta("st", nx[i]); b.text = "스테이지 %s%s" % [Store.STAGE_TAG[nx[i]], "으로" if Store.STAGE_TAG[nx[i]].ends_with("1") or Store.STAGE_TAG[nx[i]].ends_with("3") else "로"]; b.disabled = not BUILT.has(nx[i])
	var all_done: bool = Store.playable().all(func(s): return Store.save.cleared.has(s))
	ov.best_head = (("모든 스테이지를 깼습니다 · " if all_done else ("탑을 떠나 번 돈을 챙겼습니다 · " if Store.realm(game.stage) != "" else "헬기로 탈출해 번 돈을 챙겼습니다 · ")) if clear_ else ("탈출하지 못해 이번에 번 %s을 잃었습니다 · " % Store.won(st.earned) if st.earned > 0 else ""))
	if md != null: ov.best_head = (("이겨서 번 돈을 챙겼습니다 · 최고 기록 " + Store.fmt_time(float(Store.save.best.get(md.record_key(), 0)))) if clear_ else ("져서 이번에 번 %s을 잃었습니다" % Store.won(st.earned) if st.earned > 0 else "다시 도전해 보세요")) + " · "
	if clear_ and Weapons.LIST.has(str(st.get("prize", ""))):   # a boss's chest gave you a new gun: said first
		var PW: Dictionary = Weapons.LIST[str(st.prize)]; ov.best_head = "보물상자 · 새 총 %s %s 획득 · " % [PW.model, PW.name] + str(ov.best_head)
	back_stack.clear(); show_screen("over")   # (which writes the bag on the last line: _over_money)

## the result sheet's last line: how the run ended, then the bag as it is now (written again back from the shop)
func _over_money() -> void:
	(ov.best as Label).text = str(ov.get("best_head", "")) + "가방 " + Store.won(Store.save.money)

## a look over the screen on show (for the checks at five screen sizes): anything off the edge of the screen (outside a
## scrolling list), anything squeezed below the size its contents need, things to press lying on one another, and things
## to press smaller than 44 x 44 px. Each line says what and where.
func audit() -> Array:
	var out: Array = []; var vp := get_viewport_rect().size
	var root: Control = screens.get(cur)
	if root == null: return out
	var presses: Array = []
	_audit_walk(root, vp, out, presses, false, Rect2(Vector2.ZERO, vp))
	for i in presses.size():
		for j in range(i + 1, presses.size()):
			var a: Control = presses[i][0]; var b: Control = presses[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			var r := (presses[i][1] as Rect2).intersection(presses[j][1])
			if r.size.x > 2.0 and r.size.y > 2.0: out.push_back("겹침 %s / %s" % [_who(a), _who(b)])
	return out

# clip: what of the screen the control can show itself in (a scrolling list cuts off what is scrolled away)
func _audit_walk(c: Control, vp: Vector2, out: Array, presses: Array, scrolled: bool, clip: Rect2) -> void:
	if not c.is_visible_in_tree(): return
	var r := c.get_global_rect(); var seen := r.intersection(clip)
	if not scrolled and r.size.x > 0.5 and r.size.y > 0.5 and (r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0):
		out.push_back("화면 밖 %s %s" % [_who(c), _rs(r)])
	var m := c.get_combined_minimum_size()
	if m.x > c.size.x + 1.0 or m.y > c.size.y + 1.0: out.push_back("줄어듦 %s 필요 %dx%d 실제 %dx%d" % [_who(c), m.x, m.y, c.size.x, c.size.y])
	if (c is BaseButton or c is LineEdit) and seen.size.x > 0.5 and seen.size.y > 0.5:
		presses.push_back([c, seen])
		if r.size.x < 44.0 or r.size.y < 44.0: out.push_back("작음 %s %dx%d" % [_who(c), r.size.x, r.size.y])
	var inner := clip.intersection(r) if (c is ScrollContainer or c.clip_contents) else clip
	for ch in c.get_children():
		if ch is Control: _audit_walk(ch, vp, out, presses, scrolled or c is ScrollContainer, inner)

func _who(c: Control) -> String:
	var t := ""
	if c is Button: t = (c as Button).text
	elif c is Label: t = (c as Label).text
	elif c is LineEdit: t = (c as LineEdit).placeholder_text
	t = t.replace("\n", " ").strip_edges()
	return "%s「%s」" % [c.get_class(), t.substr(0, 18)] if t != "" else "%s(%s)" % [c.get_class(), c.name]

func _rs(r: Rect2) -> String:
	return "[%d,%d %dx%d]" % [r.position.x, r.position.y, r.size.x, r.size.y]
