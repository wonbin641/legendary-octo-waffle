extends Node3D
## The running game: the 3D scene, the states (menu, briefing, playing, paused, result), input for mouse, keyboard and touch,
## the camera and the HUD. The screens are in ui.gd, a stage's rules in game.gd.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a")
const BASE_FOV := 74.0

var world: World; var fx: Fx; var proj: Proj; var enemies: Enemies; var loot: Loot; var guns: Guns; var game: Game; var ui: Ui
var cam: Camera3D
var player := Player.new()
var state := "menu"
var time := 0.0
var menu_t := 0.0
var look_mode := "lock"            # lock (pointer lock), drag (no lock: aim by moving the mouse, Q/E turn), touch
var is_touch := false
var ever_locked := false
var lock_wait := -1.0
var dpr := 1.0
var base_fov := BASE_FOV
var toy_models := {}; var ruler: Node3D; var inspect := false
var view: Node3D; var gun_models := {}; var gun_mats := {}; var flash: MeshInstance3D; var flash_light: OmniLight3D
var hud: Control; var touch_ui: Control; var hint_label: Label; var fps_label: Label; var banner_label: Label; var banner_sub: Label
var hint_t := 0.0; var banner_t := 0.0; var hit_t := 0.0; var hit_kill := false; var hit_head := false; var hurt_t := 0.0
var feed_lines: Array = []         # [text, seconds left]
var f_title: Font; var f_body: Font; var f_bold: Font; var f_mono: Font
var joy_id := -1; var look_id := -1; var fire_id := -1; var joy := Vector2.ZERO; var pad_sprint := false; var pad_last_up := -9.0
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
	fx = Fx.new(); add_child(fx); world.fx = fx
	proj = Proj.new(); add_child(proj); enemies = Enemies.new(); add_child(enemies); loot = Loot.new(); add_child(loot)
	guns = Guns.new(); game = Game.new()
	guns.player = player; guns.cam = cam; guns.world = world; guns.enemies = enemies; guns.fx = fx; guns.proj = proj
	guns.hint = hint; guns.banner = banner
	guns.hitmark = func(killed: bool, head: bool) -> void: hit_t = 0.18; hit_kill = killed; hit_head = head; Snd.play("headshot" if head else "hit")
	proj.player = player; proj.world = world; proj.enemies = enemies; proj.fx = fx; proj.hitmark = guns.hitmark
	enemies.player = player; enemies.cam = cam; enemies.proj = proj; loot.player = player
	game.world = world; game.player = player; game.enemies = enemies; game.guns = guns; game.proj = proj; game.loot = loot; game.fx = fx
	game.banner = banner; game.feed = feed; game.on_result = _on_result
	enemies.on_kill = game.on_kill; world.on_crate = game.on_crate; loot.take = game.take_loot; loot.open_chest = game.open_chest
	player.on_hurt = func(_dmg: float, _from: Vector3) -> void: hurt_t = 0.35; Snd.play("hurt")
	player.on_step = func() -> void: Snd.play("step")
	player.say = func(t: String) -> void: feed(t, 0)
	world.build_stage(1)
	_build_guns(); _build_hud()
	ui = Ui.new(); ui.f_title = f_title; ui.f_body = f_body; ui.f_bold = f_bold; ui.f_mono = f_mono; ui.game = game; ui.guns = guns; ui.is_touch = is_touch
	ui.do_deploy = enter_play; ui.do_resume = resume_game; ui.do_quit = func() -> void: game.forfeit(); game.return_rentals(); to_menu()
	ui.do_menu = to_menu; ui.do_again = func(stage: int) -> void: state = "brief"; ui.in_stage = false; ui.open_brief(stage)
	ui.on_settings = apply_settings
	hud.get_parent().add_child(ui); ui.build()
	get_viewport().size_changed.connect(_on_resize); _on_resize()
	apply_settings(); to_menu(); _bridge()

func apply_settings() -> void:
	Snd.volume = float(Store.settings.vol); player.sens = float(Store.settings.sens)
	guns.auto_fire = look_mode == "touch" and bool(Store.settings.autoFire); guns.auto_jab = look_mode == "touch"
	for id in gun_mats:   # paint
		var p: Dictionary = Custom.PAINTS[Custom.paint_index(Custom.setup(id).paint)]; var m: StandardMaterial3D = gun_mats[id]
		m.albedo_color = World.lin(p.get("c", "3b4048")); m.metallic = p.get("metal", 0.35); m.roughness = p.get("rough", 0.45); m.set_meta("base", m.albedo_color)
	if ui and ui.cur == "menu": ui.refresh_menu()

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
	for id in Toys.ORDER: var t := Toys.build(id); view.add_child(t); t.visible = false; toy_models[id] = t
	ruler = Toys.build("ruler"); view.add_child(ruler); ruler.visible = false
	flash = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16); flash.mesh = q
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_texture = Gfx.glow_tex(Color(1, 0.95, 0.8, 1), Color(1, 0.7, 0.3, 0.6))
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.disable_fog = true
	flash.material_override = fm; flash.visible = false; view.add_child(flash)
	flash_light = OmniLight3D.new(); flash_light.light_color = Color(1, 0.8, 0.5); flash_light.omni_range = 9.0; flash_light.light_energy = 0.0; cam.add_child(flash_light)

func _pose_gun(dt: float) -> void:
	var W := guns.w(); var a := guns.ads * guns.ads * (3.0 - 2.0 * guns.ads); var d: Array = GUN_SHAPE[guns.cur]
	var toy := game.stage == 9; var shown: bool = not guns.scoped() and not guns.none
	for id in gun_models: (gun_models[id] as Node3D).visible = not toy and id == guns.cur and shown
	for id in toy_models: (toy_models[id] as Node3D).visible = toy and id == guns.cur and shown and not guns.melee_on
	ruler.visible = toy and guns.melee_on   # the jab swings a ruler
	if toy: d = [Toys.LENGTH[guns.cur], 0.07, 0.05]
	var hip_scale := clampf((hud.size.x / maxf(1.0, hud.size.y)) / 1.5, 0.55, 1.0)
	var pos := Vector3(0.17 * lerpf(hip_scale, 1.0, a), -0.16, -0.3).lerp(Vector3(0.0, -d[1] / 2 - 0.012, -0.24), a)
	var bob := clampf(player.speed_xz / 6.0, 0.0, 1.4) * (1.0 if player.grounded else 0.2) * (1.0 - a * 0.85); var ph := player.step_phase; var sprint := player.sprint_blend
	pos.x += sin(ph) * 0.012 * bob + sprint * 0.04; pos.y += -absf(cos(ph)) * 0.012 * bob - sprint * 0.05 + player.land_dip * 0.4; pos.z += guns.kick_z * (1.0 - a * 0.5)
	var rot := Vector3(guns.kick_rot * (1.0 - a * 0.5) - sprint * 0.35, sprint * 0.55, sin(ph) * 0.01 * bob)
	if guns.reload_t > 0.0: var c := sin((1.0 - guns.reload_t / W.reload) * PI); rot.x -= c * 0.5; rot.z += c * 0.6; pos.y -= c * 0.06
	if guns.switch_t > 0.0: var c2 := sin(guns.switch_t / 0.36 * PI); pos.y -= c2 * 0.3; rot.x -= c2 * 0.6
	if guns.melee_on:  # the jab: the gun thrusts forward and turns on its side, then comes back
		var u := guns.melee_t / Weapons.MELEE_T; var k := u / 0.28 if u < 0.28 else maxf(0.0, 1.0 - (u - 0.28) / 0.72); var j := k * k * (3.0 - 2.0 * k)
		pos += Vector3(-j * 0.12, j * 0.03, -j * 0.3); rot += Vector3(j * 0.15, j * 0.9, j * 0.35)
	if inspect: pos = Vector3(0.02, -0.03, -0.62 - d[0] * 0.25); rot = Vector3(0.18, 1.15, 0.0)   # held out to look at
	view.position = pos; view.rotation = rot
	flash.visible = guns.flash_t > 0.0 and guns.ads < 0.5; flash.position = Vector3(0, 0, -d[0] - 0.05)
	flash_light.light_energy = 3.0 if guns.flash_t > 0.0 else flash_light.light_energy * exp(-dt * 30)
	var heat: Dictionary = guns.wstate.lmg  # the machine gun goes red as it heats
	var hk: float = (0.9 + 0.1 * sin(time * 18.0)) if heat.hot else pow(heat.heat, 1.6)
	var lm: StandardMaterial3D = gun_mats.lmg; lm.albedo_color = (lm.get_meta("base", World.lin("3b4048")) as Color).lerp(Color(0.9, 0.12, 0.05), hk * 0.85)

# ---------------- the HUD ----------------
func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	return l

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud); hud.draw.connect(_draw_hud)
	hint_label = _label("", f_bold, 15, INK); hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH; hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN; hint_label.offset_bottom = -90; hud.add_child(hint_label)
	banner_label = _label("", f_title, 34, SODIUM); banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner_label.offset_top = 70; hud.add_child(banner_label)
	banner_sub = _label("", f_bold, 14, INK); banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); banner_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner_sub.offset_top = 116; hud.add_child(banner_sub)
	touch_ui = Control.new(); touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT); touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; touch_ui.visible = false; root.add_child(touch_ui); touch_ui.draw.connect(_draw_touch)
	fps_label = _label("", f_mono, 12, SODIUM); fps_label.position = Vector2(12, 40); fps_label.z_index = 50; root.add_child(fps_label)

func _draw_hud() -> void:
	var s := hud.size; var c := s / 2; var W := guns.w(); var st := guns.st(); var ink := Color(str(Store.settings.crossColor)); ink.a = 0.9
	if guns.scoped():  # through the scope: black all round a circle, a fine cross
		var r := minf(s.x, s.y) * 0.42
		hud.draw_arc(c, r + s.length(), 0, TAU, 96, Color.BLACK, s.length() * 2.0); hud.draw_arc(c, r, 0, TAU, 96, Color.BLACK, 4.0)
		hud.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.8), 1.0); hud.draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.8), 1.0)
	elif guns.ads < 0.6 and not guns.none:
		var gap := 5.0 + guns.current_spread() * 420.0
		match str(Store.settings.cross):
			"circle": hud.draw_arc(c, gap + 3, 0, TAU, 40, ink, 2.0); hud.draw_circle(c, 1.2, ink)
			"big": hud.draw_arc(c, gap + 12, 0, TAU, 48, ink, 2.0); hud.draw_circle(c, 1.5, ink)
			"dot": hud.draw_circle(c, 2.6, ink)
			_:
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: hud.draw_line(c + d * gap, c + d * (gap + 7), ink, 2.0)
				hud.draw_circle(c, 1.2, ink)
	if hit_t > 0.0:  # a hit: a small X, red for a kill
		var col := Color("ff5260") if hit_kill else (SODIUM if hit_head else INK)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: hud.draw_line(c + d * 6, c + d * 13, col, 2.0)
	if hurt_t > 0.0: hud.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.2, 0.25, 0.28 * hurt_t / 0.35))
	# the count and the bag, top left; what you carry under it
	hud.draw_string(f_title, Vector2(16, 30), "처치 %d / %d" % [game.kills, game.goal], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	hud.draw_string(f_mono, Vector2(16, 50), "가방 " + Store.won(Store.save.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SODIUM)
	var it: Dictionary = Store.save.items; var carry := []
	if int(it.helmet) > 0: carry.push_back("헬멧")
	if int(it.vest) > 0: carry.push_back("조끼 %d" % int(it.vest))
	if int(it.jet) > 0 or player.jet_on: carry.push_back("제트백팩 %.0f초" % player.jet_t if player.jet_on else "제트백팩")
	if not carry.is_empty(): hud.draw_string(f_mono, Vector2(16, 68), " · ".join(carry), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STEEL)
	for i in feed_lines.size(): hud.draw_string(f_bold, Vector2(16, 92 + i * 18), feed_lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, clampf(feed_lines[i][1], 0.0, 1.0)))
	# health, bottom left (above the D-pad on a touch screen)
	var hy := s.y - (196.0 if look_mode == "touch" else 34.0)
	hud.draw_rect(Rect2(22, hy, 180, 8), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(22, hy, 180 * player.hp / Player.MAX_HP, 8), Color("5ed6b0"))
	hud.draw_string(f_mono, Vector2(22, hy - 6), "HP %d" % int(player.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	# the gun: top right on a touch screen (the buttons have the bottom), bottom right otherwise
	var ax := s.x - (76.0 if look_mode == "touch" else 22.0); var ay := 96.0 if look_mode == "touch" else s.y - 30.0
	var res: String = "∞" if st.reserve == INF else str(int(st.reserve))
	hud.draw_string(f_title, Vector2(ax - 220, ay), str(int(st.mag)), HORIZONTAL_ALIGNMENT_RIGHT, 150, 40, Color("ff5260") if st.mag == 0 else INK)
	hud.draw_string(f_mono, Vector2(ax - 64, ay), "/ " + res, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, STEEL)
	hud.draw_string(f_bold, Vector2(ax - 220, ay - 44), Toys.NAMES[guns.cur] if game.stage == 9 else "%s · %s" % [W.name, W.model], HORIZONTAL_ALIGNMENT_RIGHT, 220, 13, SODIUM)
	if guns.reload_t > 0.0:
		hud.draw_string(f_bold, Vector2(c.x - 60, c.y + 56), "재장전", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, INK)
		hud.draw_rect(Rect2(c.x - 60, c.y + 62, 120, 4), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(c.x - 60, c.y + 62, 120 * (1.0 - guns.reload_t / W.reload), 4), SODIUM)
	if W.get("heat", false):
		hud.draw_rect(Rect2(ax - 120, ay + 8, 120, 4), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(ax - 120, ay + 8, 120 * st.heat, 4), Color("ff5260") if st.hot else SODIUM)
	var x := ax; var sy := ay - 66.0
	for i in range(guns.loadout.size() - 1, -1, -1):
		var id = guns.loadout[i]
		if id == null: continue
		var t := "%d %s" % [i + 1, Custom.weapon(id).short]; var wd := f_mono.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		x -= wd; hud.draw_string(f_mono, Vector2(x, sy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SODIUM if id == guns.cur else Color(STEEL, 0.8)); x -= 12
	# the boss, once it is hurt: its name and health across the top
	if game.boss != null and game.boss.hp < game.boss.max_hp:
		var bw := minf(360.0, s.x * 0.4); hud.draw_string(f_bold, Vector2(c.x - bw / 2, 26), game.boss.name, HORIZONTAL_ALIGNMENT_CENTER, bw, 13, INK)
		hud.draw_rect(Rect2(c.x - bw / 2, 32, bw, 6), Color(NIGHT, 0.7)); hud.draw_rect(Rect2(c.x - bw / 2, 32, bw * game.boss.hp / game.boss.max_hp, 6), Color("ff5260"))

func banner(title: String, sub: String, sec: float) -> void:
	banner_label.text = title; banner_sub.text = sub; banner_t = sec
func hint(text: String, sec: float) -> void:
	hint_label.text = text; hint_t = sec
func feed(text: String, pay := 0) -> void:
	if is_touch and pay > 0: return   # on a phone the kill lines are left out: the bag at the top still counts up
	feed_lines.push_back([text + (" · +" + Store.won(pay) if pay > 0 else ""), 3.5])
	if feed_lines.size() > 5: feed_lines.pop_front()

func _touch_rects() -> Dictionary:
	var s := hud.size; var pad := 150.0
	return {"pad": Rect2(22, s.y - pad - 22, pad, pad), "pause": Rect2(s.x - 62, 14, 48, 48)}

## the round buttons on the right: [centre, radius, label]
func _touch_buttons() -> Dictionary:
	var s := hud.size
	var b := {"fire": [Vector2(s.x - 92, s.y - 150), 42.0, "발사"], "jump": [Vector2(s.x - 62, s.y - 56), 32.0, "점프"], "ads": [Vector2(s.x - 176, s.y - 92), 30.0, "조준"],
		"reload": [Vector2(s.x - 186, s.y - 166), 26.0, "장전"], "melee": [Vector2(s.x - 156, s.y - 232), 26.0, "근접"], "swap": [Vector2(s.x - 82, s.y - 244), 26.0, "무기"]}
	if player.jet_on: b["down"] = [Vector2(s.x - 140, s.y - 40), 26.0, "내려가기"]
	return b

func _draw_touch() -> void:
	var r := _touch_rects(); var p: Rect2 = r.pad; var c := p.get_center(); var line := Color(INK, 0.5)
	touch_ui.draw_arc(c, p.size.x / 2, 0, TAU, 48, SODIUM if pad_sprint else Color(INK, 0.22), 3.0 if pad_sprint else 2.0)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var on := (d.x != 0 and signf(joy.x) == d.x) or (d.y != 0 and signf(joy.y) == d.y)
		var t := c + d * p.size.x * 0.3; var n := Vector2(-d.y, d.x) * 13
		touch_ui.draw_colored_polygon(PackedVector2Array([t + d * 15, t - d * 5 + n, t - d * 5 - n]), SODIUM if on else line)
	var tb := _touch_buttons()
	for k in tb:
		var b: Array = tb[k]; var on: bool = (k == "fire" and guns.trigger) or (k == "ads" and guns.ads_held)
		touch_ui.draw_circle(b[0], b[1], Color(SODIUM, 0.35) if on else Color(NIGHT, 0.35)); touch_ui.draw_arc(b[0], b[1], 0, TAU, 40, SODIUM if on else line, 2.0)
		touch_ui.draw_string(f_bold, b[0] + Vector2(-b[1], 5), b[2], HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2, 13, INK)
	var q: Rect2 = r.pause; touch_ui.draw_rect(Rect2(q.position + Vector2(15, 12), Vector2(6, 24)), line); touch_ui.draw_rect(Rect2(q.position + Vector2(27, 12), Vector2(6, 24)), line)

# ---------------- states ----------------
func _set_state(s: String) -> void:
	state = s
	hud.visible = s == "playing"; touch_ui.visible = s == "playing" and look_mode == "touch"
	if s != "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joy = Vector2.ZERO; joy_id = -1; look_id = -1; fire_id = -1; pad_sprint = false
	if guns: guns.trigger = false; guns.ads_held = false
	if view: view.visible = s == "playing" or s == "paused"

func to_menu() -> void:
	if not game.ended and game.stats.time > 0.0: game.forfeit()
	game.return_rentals(); Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
	enemies.clear(); proj.clear(); loot.clear(); fx.clear(); player.jet_end()
	cam.fov = base_fov; ui.in_stage = false; ui.back_stack.clear(); _set_state("menu"); ui.show_screen("menu")

func enter_play() -> void:
	guns.look_mode = look_mode; apply_settings(); feed_lines.clear(); ui.in_stage = true
	_set_state("playing"); request_lock()
	if game.boss_msg != "": banner("스테이지 " + Store.STAGE_TAG[game.stage], game.boss_msg, 3.5)
	hint("WASD 이동 · 좌클릭 발사 · 우클릭 조준 · R 재장전 · V 근접" if look_mode != "touch" else "왼쪽 방향 패드로 이동 · 화면을 밀어 조준 · 적이나 상자를 조준하면 저절로 쏩니다", 5.0)

func _on_result(kind: String) -> void:
	_set_state("gameover"); ui.in_stage = false; ui.show_result(kind)

func pause_game(msg := "") -> void:
	if state != "playing": return
	_set_state("paused"); ui.pa_note_text = msg; ui.back_stack.clear(); ui.show_screen("pause")

func resume_game() -> void:
	if state != "paused": return
	ui.back_stack.clear(); ui.show_screen(""); apply_settings(); _set_state("playing"); request_lock()

func request_lock() -> void:
	if look_mode != "lock": return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lock_wait = 1.4  # if the browser has not locked the pointer by then, aim by moving the mouse instead

# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F3 or e.physical_keycode == KEY_QUOTELEFT: Store.settings.fps = not Store.settings.fps; Store.persist_settings()  # some browsers keep F3 for themselves: the ` key does the same
		elif state == "playing":
			if e.physical_keycode == KEY_SPACE: player.jump_buf = 0.15; player.jet_tap(Time.get_ticks_msec() / 1000.0)
			if e.physical_keycode == KEY_R: guns.start_reload()
			if e.physical_keycode == KEY_V: guns.melee_start()
			if e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_9: guns.switch_slot(e.physical_keycode - KEY_1)
			if e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P: pause_game()
		elif state == "paused" and ui.cur == "pause" and (e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P): resume_game()
		elif e.physical_keycode == KEY_ESCAPE and not ui.back_stack.is_empty(): ui.close_sub()
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
		if look_mode != "touch": look_mode = "touch"; is_touch = true; ui.is_touch = true; guns.look_mode = "touch"; apply_settings(); touch_ui.visible = true
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
				"jump": player.jump_buf = 0.15; player.jet_tap(Time.get_ticks_msec() / 1000.0); player.in_up = true; set_meta("jump_id", e.index)
				"down": player.in_down = true; set_meta("down_id", e.index)
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
			if e.index == get_meta("jump_id", -1): player.in_up = false; set_meta("jump_id", -1)
			if e.index == get_meta("down_id", -1): player.in_down = false; set_meta("down_id", -1)
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
	if look_mode != "touch": player.in_up = Input.is_physical_key_pressed(KEY_SPACE); player.in_down = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)

# ---------------- the frame ----------------
func tick(dt: float) -> void:
	time += dt
	_read_keys(); player.update(dt, cam, time)
	if world.toy: world.toy.update(dt, player)
	guns.update(dt); enemies.update(dt, time); proj.update(dt); loot.update(dt); game.update(dt); fx.update(dt)
	world.update_world(dt, time, player.pos.x, player.pos.z)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if state == "playing":
		if look_mode == "lock":
			var locked := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (not OS.has_feature("web") or bool(JavaScriptBridge.eval("!!document.pointerLockElement")))
			if locked: ever_locked = true; lock_wait = -1.0
			elif lock_wait > 0.0:
				lock_wait -= dt
				if lock_wait <= 0.0:
					if not ever_locked: look_mode = "drag"; guns.look_mode = "drag"; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; hint("마우스 잠금이 막혀 있어 마우스 이동으로 조준합니다 · Q/E로 회전", 5.0)
					else: pause_game("마우스 잠금을 다시 켜지 못했습니다. 잠시 후 계속하기를 눌러 주세요.")
			elif ever_locked and lock_wait < 0.0: pause_game()  # Esc let the pointer go
		if state == "playing":
			tick(dt); _pose_gun(dt); Snd.listener = cam.global_position
			hit_t = maxf(0.0, hit_t - dt); hurt_t = maxf(0.0, hurt_t - dt); hud.queue_redraw()
			if banner_t > 0.0:
				banner_t -= dt
				if banner_t <= 0.0: banner_label.text = ""; banner_sub.text = ""
			for i in range(feed_lines.size() - 1, -1, -1):
				feed_lines[i][1] -= dt
				if feed_lines[i][1] <= 0.0: feed_lines.remove_at(i)
	elif state == "gameover" and game.result != "clear":
		pass
	elif state == "shot":
		world.update_world(dt, time, cam.position.x, cam.position.z)
	elif state != "paused":
		time += dt; menu_t += dt * 0.04
		# behind the menu the camera circles the yard
		var orbit := 58.0 if world.toy else 42.0; var oh := 34.0 if world.toy else 16.0   # the toy room is seen from higher up
		cam.fov = base_fov; cam.position = Vector3(cos(menu_t) * orbit, oh + sin(menu_t * 2.0) * 2.0, sin(menu_t) * orbit); cam.look_at(Vector3(0, 6 if world.toy else 3, 0), Vector3.UP)
		world.update_world(dt, time, cam.position.x * 0.5, cam.position.z * 0.5)
	if hint_t > 0.0:
		hint_t -= dt
		if hint_t <= 0.0: hint_label.text = ""
	fps_label.text = ("%d FPS" % Engine.get_frames_per_second()) if Store.settings.fps else ""

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
		"start":   # straight into a stage, mouse aim without the pointer lock
			ui.sel = int(a[1]) if a.size() > 1 else 1; state = "brief"; ui.open_brief(ui.sel); ui._deploy(); ever_locked = false; lock_wait = -1.0
			if look_mode == "lock": look_mode = "drag"; guns.look_mode = "drag"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"menu": to_menu(); menu_t = float(a[1]) if a.size() > 1 else menu_t
		"screen": ui.shop_ctx = ui.sel; ui.open_sub(a[1])
		"select": ui.sel = int(a[1]); ui.refresh_menu()
		"brief": state = "brief"; ui.open_brief(int(a[1]))
		"back": ui.close_sub()
		"pause": pause_game()
		"resume": resume_game()
		"money": Store.save.money = int(a[1]); Store.persist(); ui.refresh_menu()
		"dev": Store.settings.dev = a[1] == "1"; Store.settings.god = a.size() > 2 and a[2] == "1"; ui.refresh_menu()
		"reset": Store.save = Store.save0(); Store.fix_save(); Store.persist(); ui.refresh_menu()
		"at": player.pos = Vector3(float(a[1]), 0, float(a[2])); player.vel = Vector3.ZERO; player.yaw = float(a[3]); player.pitch = float(a[4]) if a.size() > 4 else 0.0
		"sim":
			for i in roundi(float(a[1]) * 30):
				if state == "playing": tick(1.0 / 30.0)
		"killall":   # every enemy but the boss (or the boss too with 'boss')
			for e in enemies.list.duplicate():
				if not e.boss or (a.size() > 1 and a[1] == "boss"): enemies.damage(e, 1e6, e.pos, Vector3(0, 0, -1), false)
		"inspect": inspect = a[1] == "1"
		"cam":   # a free camera for pictures: x y z yaw pitch
			_set_state("shot"); ui.show_screen(""); cam.fov = base_fov; cam.position = Vector3(float(a[1]), float(a[2]), float(a[3])); cam.rotation = Vector3(float(a[5]), float(a[4]), 0)
		"gun": guns.cur = a[1]; guns.pending = null; guns.switch_t = 0.0; guns.cooldown = 0.0
		"trigger": guns.trigger = a[1] == "1"; guns.trigger_edge = guns.trigger
		"ads": guns.ads_held = a[1] == "1"
		"touch": look_mode = "touch"; guns.look_mode = "touch"; apply_settings(); touch_ui.visible = state == "playing"
	return {"state": state, "screen": ui.cur, "look": look_mode, "pos": [player.pos.x, player.pos.y, player.pos.z], "yaw": player.yaw, "grounded": player.grounded,
		"colliders": Phys.colliders.size(), "crates": world.crates.filter(func(c): return not c.dead).size(), "enemies": enemies.list.size(), "kills": game.kills, "goal": game.goal, "ended": game.ended, "result": game.result,
		"gun": guns.cur, "slots": guns.slots, "mag": guns.st().mag, "hp": player.hp, "ads": guns.ads, "fov": cam.fov, "money": Store.save.money, "cleared": Store.save.cleared, "owned": Store.save.owned,
		"chest": loot.chests.size(), "boss": [game.boss.pos.x, game.boss.pos.z] if game.boss != null else [], "fit": Meta.fits(ui.sel), "ui": [ui.size.x, ui.size.y, ui._mode(), ui.detail.position.x, ui.detail.size.x, ui.board.size.x, ui.rail.size.x], "fps": Engine.get_frames_per_second(), "size": [hud.size.x, hud.size.y], "dpr": dpr}
