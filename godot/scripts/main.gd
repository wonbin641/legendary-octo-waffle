extends Node3D
## The running game: states (menu, playing, paused), input for mouse, keyboard and touch, the camera, a first HUD.
## Stage 2 of the port: you can walk stage 1. The real menu (design B), weapons and enemies come in the next stages.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a")
const BASE_FOV := 74.0

var world: World
var fx: Fx
var proj: Proj
var enemies: Enemies
var guns: Guns
var view: Node3D
var gun_models := {}
var gun_mats := {}
var flash: MeshInstance3D
var flash_light: OmniLight3D
var base_fov := BASE_FOV
var hit_t := 0.0; var hit_kill := false; var hit_head := false
var hurt_t := 0.0
var banner_t := 0.0
var banner_label: Label; var banner_sub: Label
var fire_id := -1
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
	fx = Fx.new(); add_child(fx); world.fx = fx
	proj = Proj.new(); add_child(proj); enemies = Enemies.new(); guns = Guns.new()
	guns.player = player; guns.cam = cam; guns.world = world; guns.enemies = enemies; guns.fx = fx; guns.proj = proj
	guns.hint = hint; guns.banner = banner; guns.hitmark = func(killed: bool, head: bool) -> void: hit_t = 0.18; hit_kill = killed; hit_head = head; Snd.play("hit")
	proj.player = player; proj.world = world; proj.enemies = enemies; proj.fx = fx; proj.hitmark = guns.hitmark
	player.on_hurt = func(_dmg: float, _from: Vector3) -> void: hurt_t = 0.35; Snd.play("hurt")
	player.on_step = func() -> void: Snd.play("step")
	_build_guns()
	_build_ui()
	get_viewport().size_changed.connect(_on_resize); _on_resize()
	_set_state("menu")
	_bridge()

func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size; var aspect := s.x / maxf(1.0, s.y)
	# a narrow screen keeps the same width of view by opening the lens (up to 86 degrees)
	base_fov = BASE_FOV if aspect >= 1.25 else clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(33.0)) / aspect)), BASE_FOV, 86.0)
	cam.fov = base_fov
	if guns: guns.base_fov = base_fov

# ---------------- the gun in your hands (plain shapes for now) ----------------
const GUN_SHAPE := {"pistol": [0.2, 0.05, 0.035], "shotgun": [0.62, 0.06, 0.05], "rifle": [0.6, 0.065, 0.045], "smg": [0.4, 0.07, 0.045], "sniper": [0.8, 0.055, 0.045],
	"gl": [0.5, 0.11, 0.09], "lmg": [0.72, 0.09, 0.07], "rocket": [0.85, 0.12, 0.12]}
func _build_guns() -> void:
	view = Node3D.new(); cam.add_child(view)
	for id in Weapons.ORDER:
		var d: Array = GUN_SHAPE[id]; var g := Node3D.new(); view.add_child(g); g.visible = false; gun_models[id] = g
		var mat := Gfx.std(World.lin("3b4048"), 0.45, 0.35); gun_mats[id] = mat
		var parts := [[d[2], d[1], d[0], 0, 0, -d[0] / 2], [d[2] * 0.8, 0.11, 0.045, 0, -0.07, -0.03]]   # barrel and body, grip
		if d[0] > 0.3: parts.push_back([d[2] * 0.7, 0.1, 0.05, 0, -0.07, -d[0] * 0.45])                      # magazine or fore grip
		var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; g.add_child(m)
	flash = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16); flash.mesh = q
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_texture = Gfx.glow_tex(Color(1, 0.95, 0.8, 1), Color(1, 0.7, 0.3, 0.6))
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.disable_fog = true
	flash.material_override = fm; flash.visible = false; view.add_child(flash)
	flash_light = OmniLight3D.new(); flash_light.light_color = Color(1, 0.8, 0.5); flash_light.omni_range = 9.0; flash_light.light_energy = 0.0; cam.add_child(flash_light)

func _pose_gun(dt: float) -> void:
	var W := guns.w(); var a := guns.ads * guns.ads * (3.0 - 2.0 * guns.ads); var d: Array = GUN_SHAPE[guns.cur]
	for id in gun_models: (gun_models[id] as Node3D).visible = id == guns.cur and not guns.scoped() and not guns.none
	var hip_scale := clampf((ui.size.x / maxf(1.0, ui.size.y)) / 1.5, 0.55, 1.0)
	var pos := Vector3(0.17 * lerpf(hip_scale, 1.0, a), -0.16, -0.3).lerp(Vector3(0.0, -d[1] / 2 - 0.012, -0.24), a)
	var bob := clampf(player.speed_xz / 6.0, 0.0, 1.4) * (1.0 if player.grounded else 0.2) * (1.0 - a * 0.85); var ph := player.step_phase; var sprint := player.sprint_blend
	pos.x += sin(ph) * 0.012 * bob + sprint * 0.04; pos.y += -absf(cos(ph)) * 0.012 * bob - sprint * 0.05 + player.land_dip * 0.4; pos.z += guns.kick_z * (1.0 - a * 0.5)
	var rot := Vector3(guns.kick_rot * (1.0 - a * 0.5) - sprint * 0.35, sprint * 0.55, sin(ph) * 0.01 * bob)
	if guns.reload_t > 0.0: var c := sin((1.0 - guns.reload_t / W.reload) * PI); rot.x -= c * 0.5; rot.z += c * 0.6; pos.y -= c * 0.06
	if guns.switch_t > 0.0: var c2 := sin(guns.switch_t / 0.36 * PI); pos.y -= c2 * 0.3; rot.x -= c2 * 0.6
	if guns.melee_on:  # the jab: the gun thrusts forward and turns on its side, then comes back
		var u := guns.melee_t / Weapons.MELEE_T; var k := u / 0.28 if u < 0.28 else maxf(0.0, 1.0 - (u - 0.28) / 0.72); var j := k * k * (3.0 - 2.0 * k)
		pos += Vector3(-j * 0.12, j * 0.03, -j * 0.3); rot += Vector3(j * 0.15, j * 0.9, j * 0.35)
	view.position = pos; view.rotation = rot
	flash.visible = guns.flash_t > 0.0 and guns.ads < 0.5; flash.position = Vector3(0, 0, -d[0] - 0.05)
	flash_light.light_energy = 3.0 if guns.flash_t > 0.0 else flash_light.light_energy * exp(-dt * 30)
	var heat: Dictionary = guns.wstate.lmg  # the machine gun goes red as it heats
	var hk: float = (0.9 + 0.1 * sin(time * 18.0)) if heat.hot else pow(heat.heat, 1.6)
	(gun_mats.lmg as StandardMaterial3D).albedo_color = World.lin("3b4048").lerp(Color(0.9, 0.12, 0.05), hk * 0.85)

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
	hud.draw.connect(_draw_hud)
	banner_label = _label("", f_title, 34, SODIUM); banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner_label.offset_top = 70; hud.add_child(banner_label)
	banner_sub = _label("", f_bold, 14, INK); banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner_sub.offset_top = 116; hud.add_child(banner_sub)
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
	var note := _label("Godot 이식 3단계 시험판 · 무기 8종과 상자 · 적은 아직 없습니다", f_body, 13, STEEL); mv.add_child(note)
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

func _draw_hud() -> void:
	var s := hud.size; var c := s / 2; var W := guns.w(); var st := guns.st(); var ink := Color(INK, 0.9)
	if guns.scoped():  # through the scope: black all round a circle, a fine cross
		var r := minf(s.x, s.y) * 0.42
		hud.draw_arc(c, r + s.length(), 0, TAU, 96, Color.BLACK, s.length() * 2.0)
		hud.draw_arc(c, r, 0, TAU, 96, Color.BLACK, 4.0)
		hud.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.8), 1.0); hud.draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.8), 1.0)
	elif guns.ads < 0.6 and not guns.none:
		var gap := 5.0 + guns.current_spread() * 420.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: hud.draw_line(c + d * gap, c + d * (gap + 7), ink, 2.0)
		hud.draw_circle(c, 1.2, ink)
	if hit_t > 0.0:  # a hit: a small X, red for a kill
		var col := Color("ff5260") if hit_kill else (SODIUM if hit_head else INK)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: hud.draw_line(c + d * 6, c + d * 13, col, 2.0)
	if hurt_t > 0.0: hud.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.2, 0.25, 0.28 * hurt_t / 0.35))
	# health, bottom left (above the D-pad on a touch screen)
	var hy := s.y - (196.0 if look_mode == "touch" else 34.0)
	hud.draw_rect(Rect2(22, hy, 180, 8), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(22, hy, 180 * player.hp / Player.MAX_HP, 8), Color("5ed6b0"))
	hud.draw_string(f_mono, Vector2(22, hy - 6), "HP %d" % int(player.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	# the gun, top right on a touch screen (the buttons have the bottom), bottom right otherwise
	var ax := s.x - (76.0 if look_mode == "touch" else 22.0); var ay := 96.0 if look_mode == "touch" else s.y - 30.0
	var res: String = "∞" if st.reserve == INF else str(int(st.reserve))
	hud.draw_string(f_title, Vector2(ax - 220, ay), str(int(st.mag)), HORIZONTAL_ALIGNMENT_RIGHT, 150, 40, Color("ff5260") if st.mag == 0 else INK)
	hud.draw_string(f_mono, Vector2(ax - 64, ay), "/ " + res, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, STEEL)
	hud.draw_string(f_bold, Vector2(ax - 220, ay - 44), "%s · %s" % [W.name, W.model], HORIZONTAL_ALIGNMENT_RIGHT, 220, 13, SODIUM)
	if guns.reload_t > 0.0:
		hud.draw_string(f_bold, Vector2(c.x - 60, c.y + 56), "재장전", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, INK)
		hud.draw_rect(Rect2(c.x - 60, c.y + 62, 120, 4), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(c.x - 60, c.y + 62, 120 * (1.0 - guns.reload_t / W.reload), 4), SODIUM)
	if W.get("heat", false):
		hud.draw_rect(Rect2(ax - 120, ay + 8, 120, 4), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(ax - 120, ay + 8, 120 * st.heat, 4), Color("ff5260") if st.hot else SODIUM)
	# the layout: 1-8
	var x := ax; var sy := ay - 66.0
	for i in range(guns.loadout.size() - 1, -1, -1):
		var id = guns.loadout[i]
		if id == null: continue
		var t := "%d %s" % [i + 1, Weapons.LIST[id].short]; var wd := f_mono.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		x -= wd; hud.draw_string(f_mono, Vector2(x, sy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SODIUM if id == guns.cur else Color(STEEL, 0.8)); x -= 12
		if x < s.x * 0.35: x = ax; sy -= 16

func banner(title: String, sub: String, sec: float) -> void:
	banner_label.text = title; banner_sub.text = sub; banner_t = sec

func _touch_rects() -> Dictionary:
	var s := ui.size; var pad := 150.0
	return {"pad": Rect2(22, s.y - pad - 22, pad, pad), "pause": Rect2(s.x - 62, 14, 48, 48)}

## the round buttons on the right: [centre, radius, label]
func _touch_buttons() -> Dictionary:
	var s := ui.size
	return {"fire": [Vector2(s.x - 92, s.y - 150), 42.0, "발사"], "jump": [Vector2(s.x - 62, s.y - 56), 32.0, "점프"], "ads": [Vector2(s.x - 176, s.y - 92), 30.0, "조준"],
		"reload": [Vector2(s.x - 186, s.y - 166), 26.0, "장전"], "melee": [Vector2(s.x - 156, s.y - 232), 26.0, "근접"], "swap": [Vector2(s.x - 82, s.y - 244), 26.0, "무기"]}

func _draw_touch() -> void:
	var r := _touch_rects(); var p: Rect2 = r.pad; var c := p.get_center(); var line := Color(INK, 0.5)
	touch_ui.draw_arc(c, p.size.x / 2, 0, TAU, 48, Color(INK, 0.22), 2.0)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var on := (d.x != 0 and signf(joy.x) == d.x) or (d.y != 0 and signf(joy.y) == d.y)
		var t := c + d * p.size.x * 0.3; var n := Vector2(-d.y, d.x) * 13
		touch_ui.draw_colored_polygon(PackedVector2Array([t + d * 15, t - d * 5 + n, t - d * 5 - n]), SODIUM if on and (pad_sprint or true) else line)
	if pad_sprint: touch_ui.draw_arc(c, p.size.x / 2, 0, TAU, 48, SODIUM, 3.0)
	var tb := _touch_buttons()
	for k in tb:
		var b: Array = tb[k]; var on: bool = (k == "fire" and guns.trigger) or (k == "ads" and guns.ads_held)
		touch_ui.draw_circle(b[0], b[1], Color(SODIUM, 0.35) if on else Color(NIGHT, 0.35)); touch_ui.draw_arc(b[0], b[1], 0, TAU, 40, SODIUM if on else line, 2.0)
		touch_ui.draw_string(f_bold, b[0] + Vector2(-b[1], 5), b[2], HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2, 13, INK)
	var q: Rect2 = r.pause; touch_ui.draw_rect(Rect2(q.position + Vector2(15, 12), Vector2(6, 24)), line); touch_ui.draw_rect(Rect2(q.position + Vector2(27, 12), Vector2(6, 24)), line)

func hint(text: String, sec: float) -> void:
	hint_label.text = text; hint_t = sec

# ---------------- states ----------------
func _set_state(s: String) -> void:
	state = s
	menu.visible = s == "menu"; pause.visible = s == "paused"; hud.visible = s == "playing"; touch_ui.visible = s == "playing" and look_mode == "touch"
	if s != "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joy = Vector2.ZERO; joy_id = -1; look_id = -1; fire_id = -1; pad_sprint = false
	if guns: guns.trigger = false; guns.ads_held = false
	if view: view.visible = s == "playing" or s == "paused"
	if s == "menu": (menu.get_child(0).get_child(0).get_child(4) as Button).grab_focus.call_deferred()

func start_stage() -> void:
	world.build_stage(1); proj.clear(); fx.clear()
	player.reset(world.start.x, world.start.z, world.start.yaw)
	# this trial build hands you every gun (keys 1-8); the real layout and rentals come with the shop
	guns.reset(Weapons.ORDER.duplicate()); guns.look_mode = look_mode; guns.auto_fire = look_mode == "touch"; guns.auto_jab = look_mode == "touch"
	_set_state("playing"); request_lock()
	hint("WASD 이동 · 좌클릭 발사 · 우클릭 조준 · R 재장전 · V 근접 · 1-8 무기" if look_mode != "touch" else "왼쪽 방향 패드로 이동 · 화면을 밀어 조준 · 상자를 조준하면 저절로 쏩니다", 6.0)

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
			if e.physical_keycode == KEY_R: guns.start_reload()
			if e.physical_keycode == KEY_V: guns.melee_start()
			if e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_8: guns.switch_slot(e.physical_keycode - KEY_1)
			if e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P: pause_game()
		elif state == "paused" and (e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P): resume_game()
	if state != "playing": return
	if e is InputEventMouseMotion and look_mode != "touch":
		if look_mode == "lock" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		# browsers sometimes report one huge jump right after the pointer locks; drop it
		if absf(e.relative.x) > 450 or absf(e.relative.y) > 450: return
		player.look_dx += e.relative.x; player.look_dy += e.relative.y
	if e is InputEventMouseButton and look_mode != "touch":
		if e.pressed and look_mode == "lock" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: request_lock(); return
		if e.button_index == MOUSE_BUTTON_LEFT:
			guns.trigger = e.pressed
			if e.pressed: guns.trigger_edge = true
		elif e.button_index == MOUSE_BUTTON_RIGHT: guns.ads_held = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_XBUTTON1: guns.melee_start()   # the mouse's back button
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN: guns.cycle(1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP: guns.cycle(-1)
	if e is InputEventScreenTouch:
		if look_mode != "touch": look_mode = "touch"; is_touch = true; touch_ui.visible = true
		var r := _touch_rects(); var p: Vector2 = e.position   # already in the page's units (the window is scaled by the device pixel ratio)
		if e.pressed:
			if (r.pause as Rect2).has_point(p): pause_game(); return
			var tb := _touch_buttons(); var hit := ""
			for k in tb:
				if p.distance_to(tb[k][0]) <= tb[k][1] + 6.0: hit = k; break
			match hit:
				"fire":  # the firing thumb also aims
					guns.trigger = true; guns.trigger_edge = true; fire_id = e.index
					if look_id < 0: look_id = e.index
				"jump": player.jump_buf = 0.15
				"ads": guns.ads_held = not guns.ads_held
				"reload": guns.start_reload()
				"melee": guns.melee_start()
				"swap": guns.cycle(1)
			if hit != "": touch_ui.queue_redraw(); return
			if joy_id < 0 and (r.pad as Rect2).grow(12).has_point(p):
				joy_id = e.index; _pad_steer(p)
				pad_sprint = joy.y < 0 and joy.x == 0 and time - pad_last_up < 0.32  # a second tap on the up arrow, held: run
			elif look_id < 0: look_id = e.index
		else:
			if e.index == joy_id:
				if joy.y < 0 and joy.x == 0: pad_last_up = time
				joy_id = -1; joy = Vector2.ZERO; pad_sprint = false
			if e.index == look_id: look_id = -1
			if e.index == fire_id: fire_id = -1; guns.trigger = false
		touch_ui.queue_redraw()
	if e is InputEventScreenDrag:
		if e.index == joy_id: _pad_steer(e.position); touch_ui.queue_redraw()
		elif e.index == look_id: player.look_dx += e.relative.x * 1.7; player.look_dy += e.relative.y * 1.7

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
			_read_keys(); guns.update(dt); player.update(dt, cam, time); proj.update(dt); fx.update(dt); _pose_gun(dt)
			world.update_world(dt, time, player.pos.x, player.pos.z); Snd.listener = cam.global_position
			hit_t = maxf(0.0, hit_t - dt); hurt_t = maxf(0.0, hurt_t - dt); hud.queue_redraw()
			if banner_t > 0.0:
				banner_t -= dt
				if banner_t <= 0.0: banner_label.text = ""; banner_sub.text = ""
			if player.hp <= 0.0: _set_state("menu")
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
			for i in roundi(float(a[1]) * 30): guns.update(1.0 / 30.0); player.update(1.0 / 30.0, cam, time); proj.update(1.0 / 30.0)
		"gun": guns.cur = a[1]; guns.pending = null; guns.switch_t = 0.0; guns.cooldown = 0.0
		"trigger": guns.trigger = a[1] == "1"; guns.trigger_edge = guns.trigger
		"ads": guns.ads_held = a[1] == "1"
		"touch": look_mode = "touch"; guns.look_mode = "touch"; guns.auto_fire = true; guns.auto_jab = true; touch_ui.visible = state == "playing"
	return {"state": state, "look": look_mode, "pos": [player.pos.x, player.pos.y, player.pos.z], "yaw": player.yaw, "grounded": player.grounded,
		"colliders": Phys.colliders.size(), "crates": world.crates.filter(func(c): return not c.dead).size(), "gun": guns.cur, "mag": guns.st().mag, "hp": player.hp, "ads": guns.ads, "fov": cam.fov, "fps": Engine.get_frames_per_second(), "size": [ui.size.x, ui.size.y], "dpr": dpr}
