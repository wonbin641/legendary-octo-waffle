extends Node3D
## The running game: states (menu, playing, paused), input for mouse, keyboard and touch, the camera, a first HUD.
## Stage 2 of the port: you can walk stage 1. The real menu (design B), weapons and enemies come in the next stages.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a")
const BASE_FOV := 74.0

var world: World
var cam: Camera3D
var player := Player.new()
var state := "menu"
var time := 0.0
var menu_t := 0.0
var look_mode := "lock"            # lock (pointer lock), drag (no lock: aim by moving the mouse, Q/E turn), touch
var is_touch := false
var ever_locked := false
var lock_wait := -1.0
var show_fps := false
var dpr := 1.0
var ui: Control; var menu: Control; var pause: Control; var hud: Control; var touch_ui: Control
var hint_label: Label; var fps_label: Label; var pause_note: Label
var hint_t := 0.0
var f_title: Font; var f_body: Font; var f_bold: Font; var f_mono: Font
# touch: the D-pad on the left, look by dragging anywhere else
var joy_id := -1; var look_id := -1; var joy := Vector2.ZERO; var pad_sprint := false; var pad_last_up := -9.0
var _js_cb

func _ready() -> void:
	f_title = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf"); f_body = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-Regular.ttf")
	f_bold = load("res://fonts/ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf"); f_mono = load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf")
	f_mono.fallbacks = [f_bold]; f_title.fallbacks = [f_bold]  # the mono and title fonts have gaps; the body font fills them
	if OS.has_feature("web"):
		dpr = float(JavaScriptBridge.eval("window.devicePixelRatio || 1"))
		is_touch = bool(JavaScriptBridge.eval("(window.matchMedia && matchMedia('(pointer: coarse)').matches) || ('ontouchstart' in window && navigator.maxTouchPoints > 0)"))
	if is_touch: look_mode = "touch"
	get_window().content_scale_factor = dpr
	# the 3D picture is drawn at most at 1.25x (touch) or 1.6x (desktop) of the page's size, as in the browser game
	get_viewport().scaling_3d_scale = minf(1.0, (1.25 if is_touch else 1.6) / dpr)
	world = World.new(); add_child(world)
	cam = Camera3D.new(); cam.near = 0.05; cam.far = 460.0; cam.fov = BASE_FOV; cam.rotation_order = EULER_ORDER_YXZ; add_child(cam); cam.make_current()
	world.build_stage(1)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize); _on_resize()
	_set_state("menu")
	_bridge()

func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size; var aspect := s.x / maxf(1.0, s.y)
	# a narrow screen keeps the same width of view by opening the lens (up to 86 degrees)
	cam.fov = BASE_FOV if aspect >= 1.25 else clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(33.0)) / aspect)), BASE_FOV, 86.0)

# ---------------- UI ----------------
func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, primary: bool) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(150, 48); b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", f_title if primary else f_bold); b.add_theme_font_size_override("font_size", 24 if primary else 15)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new(); sb.set_content_margin_all(10); sb.content_margin_left = 22; sb.content_margin_right = 22
		if st == "focus": sb.draw_center = false; sb.border_color = SODIUM; sb.set_border_width_all(2); sb.set_expand_margin_all(3)
		elif primary: sb.bg_color = SODIUM if st == "normal" else SODIUM.lightened(0.15)
		else: sb.bg_color = Color(NIGHT, 0.6); sb.border_color = Color(STEEL, 0.45 if st == "normal" else 0.9); sb.set_border_width_all(1)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, NIGHT if primary else INK)
	return b

func _sheet(code: String) -> Array:  # a document panel: [the panel, its body]
	var p := PanelContainer.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(NIGHT, 0.86); sb.border_color = Color(STEEL, 0.35); sb.set_border_width_all(1); sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); p.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var l := _label("작업 지시서 · 단독 작전", f_mono, 11, STEEL); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(l); head.add_child(_label(code, f_mono, 11, SODIUM))
	return [p, v]

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	# HUD: crosshair, hint line, frame rate
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	hud.draw.connect(func() -> void:
		var c := hud.size / 2
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: hud.draw_line(c + d * 5, c + d * 12, Color(INK, 0.9), 2.0)
		hud.draw_circle(c, 1.2, Color(INK, 0.9)))
	hint_label = _label("", f_bold, 15, INK); hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH; hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN; hint_label.offset_bottom = -90; hud.add_child(hint_label)
	fps_label = _label("", f_mono, 12, SODIUM); fps_label.position = Vector2(12, 10); ui.add_child(fps_label)
	# touch controls
	touch_ui = Control.new(); touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT); touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; touch_ui.visible = false; ui.add_child(touch_ui)
	touch_ui.draw.connect(_draw_touch)
	# the first screen (a stand-in until the real main menu, design B, is built)
	menu = CenterContainer.new(); menu.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(menu)
	var ms := _sheet("YRDU 070707 7"); menu.add_child(ms[0]); var mv: VBoxContainer = ms[1]
	var title := HBoxContainer.new(); title.add_theme_constant_override("separation", 14); mv.add_child(title)
	title.add_child(_label("야르", f_title, 84, INK)); title.add_child(_label("07", f_title, 84, SODIUM))
	mv.add_child(_label("스테이지 1 · 컨테이너 부두", f_bold, 16, INK))
	var note := _label("Godot 이식 2단계 시험판 · 이동과 지도만 있습니다", f_body, 13, STEEL); mv.add_child(note)
	var go := _button("출동", true); mv.add_child(go); go.pressed.connect(func() -> void: start_stage())
	# pause
	pause = CenterContainer.new(); pause.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(pause)
	var bg := ColorRect.new(); bg.color = Color(NIGHT, 0.55); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; pause.add_child(bg); pause.move_child(bg, 0)
	var ps := _sheet("YRD-PAUSE"); pause.add_child(ps[0]); var pv: VBoxContainer = ps[1]
	pv.add_child(_label("일시정지", f_title, 56, INK))
	pause_note = _label("", f_body, 13, STEEL); pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pause_note.custom_minimum_size = Vector2(300, 0); pv.add_child(pause_note)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); pv.add_child(row)
	var res := _button("계속하기", true); row.add_child(res); res.pressed.connect(func() -> void: resume_game())
	var fpsb := _button("FPS 표시", false); row.add_child(fpsb); fpsb.pressed.connect(func() -> void: show_fps = not show_fps)
	var quit := _button("작전 포기", false); row.add_child(quit); quit.pressed.connect(func() -> void: _set_state("menu"))

func _touch_rects() -> Dictionary:
	var s := ui.size; var pad := 150.0
	return {"pad": Rect2(22, s.y - pad - 22, pad, pad), "jump": Rect2(s.x - 96, s.y - 96, 72, 72), "pause": Rect2(s.x - 62, 14, 48, 48)}

func _draw_touch() -> void:
	var r := _touch_rects(); var p: Rect2 = r.pad; var c := p.get_center(); var line := Color(INK, 0.5)
	touch_ui.draw_arc(c, p.size.x / 2, 0, TAU, 48, Color(INK, 0.22), 2.0)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var on := (d.x != 0 and signf(joy.x) == d.x) or (d.y != 0 and signf(joy.y) == d.y)
		var t := c + d * p.size.x * 0.3; var n := Vector2(-d.y, d.x) * 13
		touch_ui.draw_colored_polygon(PackedVector2Array([t + d * 15, t - d * 5 + n, t - d * 5 - n]), SODIUM if on and (pad_sprint or true) else line)
	if pad_sprint: touch_ui.draw_arc(c, p.size.x / 2, 0, TAU, 48, SODIUM, 3.0)
	var j: Rect2 = r.jump; touch_ui.draw_arc(j.get_center(), 36, 0, TAU, 40, line, 2.0); touch_ui.draw_string(f_bold, j.get_center() + Vector2(-14, 6), "점프", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	var q: Rect2 = r.pause; touch_ui.draw_rect(Rect2(q.position + Vector2(15, 12), Vector2(6, 24)), line); touch_ui.draw_rect(Rect2(q.position + Vector2(27, 12), Vector2(6, 24)), line)

func hint(text: String, sec: float) -> void:
	hint_label.text = text; hint_t = sec

# ---------------- states ----------------
func _set_state(s: String) -> void:
	state = s
	menu.visible = s == "menu"; pause.visible = s == "paused"; hud.visible = s == "playing"; touch_ui.visible = s == "playing" and look_mode == "touch"
	if s != "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joy = Vector2.ZERO; joy_id = -1; look_id = -1; pad_sprint = false
	if s == "menu": (menu.get_child(0).get_child(0).get_child(4) as Button).grab_focus.call_deferred()

func start_stage() -> void:
	player.reset(world.start.x, world.start.z, world.start.yaw)
	_set_state("playing"); request_lock()
	hint("마우스 이동으로 조준 · WASD 이동 · Shift 달리기 · Space 점프" if look_mode != "touch" else "왼쪽 방향 패드로 이동 · 화면을 밀어 조준 · ▲를 두 번 눌러 달리기", 5.0)

func pause_game(msg := "") -> void:
	if state != "playing": return
	pause_note.text = msg; pause_note.visible = msg != ""; _set_state("paused")
	(pause.get_child(1).get_child(0).get_child(3).get_child(0) as Button).grab_focus.call_deferred()

func resume_game() -> void:
	if state != "paused": return
	_set_state("playing"); request_lock()

func request_lock() -> void:
	if look_mode != "lock": return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lock_wait = 1.4  # if the browser has not locked the pointer by then, aim by moving the mouse instead

# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F3 or e.physical_keycode == KEY_QUOTELEFT: show_fps = not show_fps  # some browsers keep F3 for themselves: the ` key does the same
		elif state == "playing":
			if e.physical_keycode == KEY_SPACE: player.jump_buf = 0.15
			if e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P: pause_game()
		elif state == "paused" and (e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P): resume_game()
	if state != "playing": return
	if e is InputEventMouseMotion and look_mode != "touch":
		if look_mode == "lock" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		# browsers sometimes report one huge jump right after the pointer locks; drop it
		if absf(e.relative.x) > 450 * dpr or absf(e.relative.y) > 450 * dpr: return
		player.look_dx += e.relative.x / dpr; player.look_dy += e.relative.y / dpr
	if e is InputEventMouseButton and e.pressed and look_mode == "lock" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: request_lock()
	if e is InputEventScreenTouch:
		if look_mode != "touch": look_mode = "touch"; is_touch = true; touch_ui.visible = true
		var r := _touch_rects(); var p: Vector2 = e.position / dpr
		if e.pressed:
			if (r.pause as Rect2).has_point(p): pause_game(); return
			if (r.jump as Rect2).has_point(p): player.jump_buf = 0.15; return
			if joy_id < 0 and (r.pad as Rect2).grow(12).has_point(p):
				joy_id = e.index; _pad_steer(p)
				pad_sprint = joy.y < 0 and joy.x == 0 and time - pad_last_up < 0.32  # a second tap on the up arrow, held: run
			elif look_id < 0: look_id = e.index
		else:
			if e.index == joy_id:
				if joy.y < 0 and joy.x == 0: pad_last_up = time
				joy_id = -1; joy = Vector2.ZERO; pad_sprint = false
			if e.index == look_id: look_id = -1
		touch_ui.queue_redraw()
	if e is InputEventScreenDrag:
		if e.index == joy_id: _pad_steer(e.position / dpr); touch_ui.queue_redraw()
		elif e.index == look_id: player.look_dx += e.relative.x / dpr * 1.7; player.look_dy += e.relative.y / dpr * 1.7

## the D-pad steers by where the thumb is relative to its centre: 60 degrees for each arrow, the 30 between them for diagonals
func _pad_steer(p: Vector2) -> void:
	var r: Rect2 = _touch_rects().pad; var d := p - r.get_center(); joy = Vector2.ZERO
	if d.length() > r.size.x * 0.12:
		var a := atan2(d.y, d.x); var q := roundf(a / (PI / 2)); var off := absf(a - q * PI / 2)
		joy = Vector2(roundf(cos(q * PI / 2)), roundf(sin(q * PI / 2))) if off < PI / 6 else Vector2(signf(d.x), signf(d.y))

func _read_keys() -> void:
	var k := func(c: Key) -> float: return 1.0 if Input.is_physical_key_pressed(c) else 0.0
	player.in_f = k.call(KEY_W) - k.call(KEY_S) - joy.y
	player.in_s = k.call(KEY_D) - k.call(KEY_A) + joy.x
	player.in_run = Input.is_physical_key_pressed(KEY_SHIFT) or (look_mode == "touch" and pad_sprint)
	player.in_turn = k.call(KEY_LEFT) - k.call(KEY_RIGHT) + ((k.call(KEY_Q) - k.call(KEY_E)) if look_mode == "drag" else 0.0)
	player.in_pitch = k.call(KEY_UP) - k.call(KEY_DOWN)

# ---------------- the frame ----------------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if state == "playing":
		time += dt
		if look_mode == "lock":
			var locked := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (not OS.has_feature("web") or bool(JavaScriptBridge.eval("!!document.pointerLockElement")))
			if locked: ever_locked = true; lock_wait = -1.0
			elif lock_wait > 0.0:
				lock_wait -= dt
				if lock_wait <= 0.0:
					if not ever_locked: look_mode = "drag"; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; hint("마우스 잠금이 막혀 있어 마우스 이동으로 조준합니다 · Q/E로 회전", 5.0)
					else: pause_game("마우스 잠금을 다시 켜지 못했습니다. 잠시 후 계속하기를 눌러 주세요.")
			elif ever_locked and lock_wait < 0.0: pause_game()  # Esc let the pointer go
		if state == "playing":
			_read_keys(); player.update(dt, cam, time)
			world.update_world(dt, time, player.pos.x, player.pos.z)
	elif state == "menu":
		time += dt; menu_t += dt * 0.04
		# behind the menu the camera circles the yard
		cam.position = Vector3(cos(menu_t) * 42.0, 16.0 + sin(menu_t * 2.0) * 2.0, sin(menu_t) * 42.0); cam.look_at(Vector3(0, 3, 0), Vector3.UP)
		world.update_world(dt, time, cam.position.x * 0.5, cam.position.z * 0.5)
	if hint_t > 0.0:
		hint_t -= dt
		if hint_t <= 0.0: hint_label.text = ""
	fps_label.text = ("%d FPS" % Engine.get_frames_per_second()) if show_fps else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: pause_game()

# ---------------- a door for the browser tests: window.__yarr("command") returns a small object ----------------
func _bridge() -> void:
	if not OS.has_feature("web"): return
	_js_cb = JavaScriptBridge.create_callback(_on_js)
	JavaScriptBridge.get_interface("window").__yarrCall = _js_cb
	JavaScriptBridge.eval("window.__yarr = (c) => { window.__yarrOut = 'null'; window.__yarrCall(c); return JSON.parse(window.__yarrOut); }; window.__godotReady = true; var st = document.getElementById('st'); if (st) st.remove();")

func _on_js(args: Array) -> void:
	JavaScriptBridge.eval("window.__yarrOut = %s" % JSON.stringify(JSON.stringify(command(str(args[0])))))

func command(line: String) -> Dictionary:
	var a := line.split(" ")
	match a[0]:
		"start": start_stage(); ever_locked = false; lock_wait = -1.0; look_mode = "drag" if look_mode == "lock" else look_mode; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"menu": _set_state("menu"); menu_t = float(a[1]) if a.size() > 1 else menu_t
		"pause": pause_game()
		"resume": resume_game()
		"at": player.pos = Vector3(float(a[1]), 0, float(a[2])); player.vel = Vector3.ZERO; player.yaw = float(a[3]); player.pitch = float(a[4]) if a.size() > 4 else 0.0
		"sim":
			player.in_f = float(a[2]); player.in_s = float(a[3]); player.in_run = a.size() > 4 and a[4] == "run"
			for i in roundi(float(a[1]) * 30): player.update(1.0 / 30.0, cam, time)
	return {"state": state, "look": look_mode, "pos": [player.pos.x, player.pos.y, player.pos.z], "yaw": player.yaw, "grounded": player.grounded,
		"colliders": Phys.colliders.size(), "crates": world.crates.size(), "fps": Engine.get_frames_per_second(), "size": [ui.size.x, ui.size.y], "dpr": dpr}
