extends Node3D
## The running game: the 3D scene, the states (menu, briefing, playing, paused, result), input for mouse, keyboard and touch,
## the camera and the HUD. The screens are in ui.gd, a stage's rules in game.gd.

const NIGHT := Color("0d1220"); const INK := Color("ece6d8"); const STEEL := Color("8f9bb0"); const SODIUM := Color("f2a33a"); const VITAL := Color("5ed6b0")
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
var toy_models := {}; var ruler: Node3D; var inspect := false; var laser: MeshInstance3D; var laser_dot: MeshInstance3D
var needle: Node3D; var needle_arm: Node3D; var needle_syr: Node3D; var needle_juice: MeshInstance3D
var gm_models: GunModels
var jet_puff_t := 0.0
var cut: Cut   # the cutscenes: in by helicopter, out by helicopter, the lab, the ship, the look behind a sealed door
var view: Node3D; var gun_models := {}; var gun_mats := {}; var flash: MeshInstance3D; var flash_light: OmniLight3D
var hud: Control; var touch_ui: Control; var fps_label: Label
var hudd: Hud   # the fight's screen (scripts/hud.gd)
var heat_k := -1.0
var cu_ang := 0.6
var cu_light: OmniLight3D = null   # the menu scene is dark: the gun being fitted out gets a lamp of its own
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
	guns.hitmark = func(killed: bool, head: bool) -> void: hudd.hitmark(killed, head); Snd.play("headshot" if head else "hit")
	proj.player = player; proj.world = world; proj.enemies = enemies; proj.fx = fx; proj.hitmark = guns.hitmark
	enemies.player = player; enemies.cam = cam; enemies.proj = proj; loot.player = player; loot.fx = fx; enemies.fx = fx; enemies.hitmark = guns.hitmark; enemies.say = func(t: String) -> void: feed(t, 0)
	game.world = world; game.player = player; game.enemies = enemies; game.guns = guns; game.proj = proj; game.loot = loot; game.fx = fx
	game.banner = banner; game.feed = feed; game.on_result = _on_result
	enemies.on_bite = game.bitten; enemies.on_poison = game.poison; enemies.on_stun = game.stun; enemies.banner = banner; game.hint = hint
	game.on_flash = func(a: float, from: Vector3) -> void: hudd.hurt(a, from)
	game.on_pay = func(n: int) -> void: if look_mode != "touch": hudd.money_pop(n)
	enemies.on_kill = game.on_kill; world.on_crate = game.on_crate; loot.take = game.take_loot; loot.open_chest = game.open_chest
	player.on_hurt = func(dmg: float, from: Vector3) -> void: hudd.hurt(dmg, from); Snd.play("hurt")
	player.on_step = func() -> void: Snd.play("step")
	player.say = func(t: String) -> void: feed(t, 0)
	world.build_stage(1)
	_build_guns(); _build_hud()
	cut = Cut.new(); add_child(cut); cut.cam = cam; cut.player = player; cut.game = game; cut.world = world; cut.enemies = enemies; cut.fx = fx
	cut.build_overlay(hud.get_parent(), f_title, f_mono)
	ui = Ui.new(); ui.f_title = f_title; ui.f_body = f_body; ui.f_bold = f_bold; ui.f_mono = f_mono; ui.game = game; ui.guns = guns; ui.is_touch = is_touch
	ui.do_deploy = func() -> void: enter_play(true)
	ui.do_resume = resume_game; ui.do_quit = func() -> void: game.forfeit(); game.return_rentals(); to_menu()
	ui.do_menu = to_menu; ui.do_again = func(stage: int) -> void:
		if game.sp != null and game.result != "clear" and stage == game.stage:   # back to the save point, as things were when you took it
			game.from_save(); ui.show_screen(""); enter_play(); banner("세이브 포인트에서 다시", "처치 %d · 열쇠를 가진 채 운전실에서 시작합니다" % game.kills, 3.0); return
		state = "brief"; ui.in_stage = false; ui.open_brief(stage)
	ui.on_settings = apply_settings; ui.do_map = open_map; ui.do_map_close = close_map
	hud.get_parent().add_child(ui); ui.build(); ui.tac.cam = cam
	get_viewport().size_changed.connect(_on_resize); _on_resize()
	apply_settings(); to_menu(); _bridge()

func apply_settings() -> void:
	Snd.touch = look_mode == "touch"
	Snd.volume = float(Store.settings.vol); player.sens = float(Store.settings.sens)
	guns.auto_fire = look_mode == "touch" and bool(Store.settings.autoFire); guns.auto_jab = look_mode == "touch"
	for id in Weapons.ORDER: gm_models.apply_look(id, Custom.setup(id))   # parts and paint
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
	view = Node3D.new(); cam.add_child(view); _build_needle(cam)
	gm_models = GunModels.new(); gm_models.build(view)
	for id in Weapons.ORDER: gun_models[id] = gm_models.models[id].g
	for id in Toys.ORDER: var t := Toys.build(id); view.add_child(t); t.visible = false; toy_models[id] = t
	ruler = Toys.build("ruler"); view.add_child(ruler); ruler.visible = false
	# the laser pointer's beam and its dot (stage 5's rifle, while you aim)
	laser = MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.006, 0.006, 1.0); laser.mesh = lb
	var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color(1, 0.1, 0.08, 0.55); lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; lm.disable_fog = true
	laser.material_override = lm; laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; laser.visible = false; add_child(laser)
	laser_dot = MeshInstance3D.new(); var ls := SphereMesh.new(); ls.radius = 0.05; ls.height = 0.1; laser_dot.mesh = ls; var dm: StandardMaterial3D = lm.duplicate(); dm.albedo_color = Color(1, 0.15, 0.1, 1); laser_dot.material_override = dm; laser_dot.visible = false; add_child(laser_dot)
	flash = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16); flash.mesh = q
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_texture = Gfx.glow_tex(Color(1, 0.95, 0.8, 1), Color(1, 0.7, 0.3, 0.6))
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.disable_fog = true
	flash.material_override = fm; flash.visible = false; view.add_child(flash)
	flash_light = OmniLight3D.new(); flash_light.light_color = Color(1, 0.8, 0.5); flash_light.omni_range = 9.0; flash_light.light_energy = 0.0; cam.add_child(flash_light)

static func _smooth(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0); return k * k * (3.0 - 2.0 * k)

## the antidote in the hands: a bare left forearm and a syringe of green
func _build_needle(parent: Node3D) -> void:
	needle = Node3D.new(); needle.visible = false; parent.add_child(needle)
	var vm := StandardMaterial3D.new(); vm.vertex_color_use_as_albedo = true; vm.roughness = 0.8; vm.no_depth_test = false
	needle_arm = Node3D.new(); needle.add_child(needle_arm)
	var am := MeshInstance3D.new(); am.mesh = Gfx.merge_boxes([[0.24, 0.058, 0.062, -0.13, 0, 0, "222a37"], [0.13, 0.048, 0.052, 0.055, 0.001, 0, "c99a7a"], [0.055, 0.06, 0.066, 0.145, 0, 0, "26292e"], [0.012, 0.062, 0.066, -0.006, 0, 0, "222a37"]]); am.material_override = vm; needle_arm.add_child(am)
	needle_syr = Node3D.new(); needle.add_child(needle_syr)
	var sm := MeshInstance3D.new(); sm.mesh = Gfx.merge_boxes([[0.13, 0.03, 0.03, 0, 0, 0, "dfe8ee"], [0.06, 0.005, 0.005, -0.095, 0, 0, "c9ced6"], [0.008, 0.04, 0.04, 0.066, 0, 0, "f0f0ea"], [0.09, 0.01, 0.01, 0.11, 0, 0, "f0f0ea"], [0.008, 0.036, 0.036, 0.156, 0, 0, "f0f0ea"], [0.06, 0.07, 0.07, 0.05, -0.04, 0.01, "26292e"]])
	var gm := vm.duplicate(); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.albedo_color = Color(1, 1, 1, 0.75); sm.material_override = gm; needle_syr.add_child(sm)
	needle_juice = MeshInstance3D.new(); var jm := BoxMesh.new(); jm.size = Vector3(0.12, 0.022, 0.022); needle_juice.mesh = jm; needle_juice.material_override = Gfx.unlit(Color("58ff7a"), false); needle_syr.add_child(needle_juice)

func _pose_gun(dt: float) -> void:
	var W := guns.w(); var a := guns.ads * guns.ads * (3.0 - 2.0 * guns.ads); var d: Array = GUN_SHAPE[guns.cur]
	var toy := game.stage == 9; var shown: bool = not guns.scoped() and not guns.none
	for id in gun_models: (gun_models[id] as Node3D).visible = not toy and id == guns.cur and shown
	for id in toy_models: (toy_models[id] as Node3D).visible = toy and id == guns.cur and shown and not guns.melee_on
	ruler.visible = toy and guns.melee_on   # the jab swings a ruler
	if toy:
		d = [Toys.LENGTH[guns.cur], 0.07, 0.05]
		Toys.pose(toy_models[guns.cur], guns.cur, (1.0 - guns.reload_t / W.reload) if guns.reload_t > 0.0 else -1.0, guns.st().mag, W.mag, guns.since_shot)
	var beam: bool = toy and guns.cur == "sniper" and guns.ads > 0.25 and guns.reload_t <= 0.0 and state == "playing"
	laser.visible = beam and not guns.scoped(); laser_dot.visible = beam
	if beam:   # the pointer's red line runs out to whatever it touches
		var o := cam.global_position; var f := -cam.global_basis.z; Phys.raycast_static(o, f, 320.0); var end := o + f * Phys.rh_t; var from := guns.muzzle()
		laser_dot.position = end - f * 0.03; laser_dot.scale = Vector3.ONE * clampf(Phys.rh_t * 0.05, 0.6, 6.0)
		if from.distance_to(end) > 0.5: laser.look_at_from_position((from + end) / 2, end, Vector3.UP if absf(f.y) < 0.99 else Vector3.RIGHT); laser.scale = Vector3(1, 1, from.distance_to(end))
	var hip_scale := clampf((hud.size.x / maxf(1.0, hud.size.y)) / 1.5, 0.55, 1.0)
	var pos := Vector3(0.17 * lerpf(hip_scale, 1.0, a), -0.16, -0.3).lerp(Vector3(0.0, -d[1] / 2 - 0.012, -0.24), a)
	if not toy: pos = GunModels.hip(guns.cur).lerp(GunModels.ads(guns.cur), a); pos.x *= lerpf(hip_scale, 1.0, a)
	var bob := clampf(player.speed_xz / 6.0, 0.0, 1.4) * (1.0 if player.grounded else 0.2) * (1.0 - a * 0.85); var ph := player.step_phase; var sprint := player.sprint_blend
	pos.x += sin(ph) * 0.012 * bob + sprint * 0.04; pos.y += -absf(cos(ph)) * 0.012 * bob - sprint * 0.05 + player.land_dip * 0.4; pos.z += guns.kick_z * (1.0 - a * 0.5)
	var rot := Vector3(guns.kick_rot * (1.0 - a * 0.5) - sprint * 0.35, sprint * 0.55, sin(ph) * 0.01 * bob)
	if guns.reload_t > 0.0:
		var c := sin((1.0 - guns.reload_t / W.reload) * PI)
		if toy: rot.x += c * 0.22; rot.z += c * 0.3; pos.y += c * 0.02; pos.x -= c * 0.05   # tipped up and turned a little, so you see the hands' work
		else: rot.x -= c * 0.5; rot.z += c * 0.6; pos.y -= c * 0.06
	if guns.switch_t > 0.0: var c2 := sin(guns.switch_t / 0.36 * PI); pos.y -= c2 * 0.3; rot.x -= c2 * 0.6
	if guns.melee_on:  # the jab: the gun thrusts forward and turns on its side, then comes back
		var u := guns.melee_t / Weapons.MELEE_T; var k := u / 0.28 if u < 0.28 else maxf(0.0, 1.0 - (u - 0.28) / 0.72); var j := k * k * (3.0 - 2.0 * k)
		pos += Vector3(-j * 0.12, j * 0.03, -j * 0.3); rot += Vector3(j * 0.15, j * 0.9, j * 0.35)
	# the antidote: the gun goes down, the left forearm comes up across the view and the needle goes in
	if game.inject_on:
		var it := game.inject_t; var D := Game.INJECT_DUR
		var low := _smooth(0.0, 0.28, it) * (1.0 - _smooth(D - 0.3, D, it)); pos.y -= low * 0.34; rot.x -= low * 0.7
		var up := _smooth(0.05, 0.35, it) * (1.0 - _smooth(D - 0.28, D, it)); var dn := (1.0 - up) * 0.2
		var stab := _smooth(0.36, 0.48, it) * (1.0 - _smooth(0.92, 1.05, it)); var push := _smooth(0.5, 0.82, it)
		needle.visible = true; needle_arm.position = Vector3(-0.035, -0.17 - dn, -0.5); needle_arm.rotation = Vector3(0.55, 0.42, 0.2)
		needle_syr.position = Vector3(0.135 - stab * 0.03, -0.1 - dn - stab * 0.022, -0.47); needle_syr.rotation = Vector3(0.1, 0.35, -0.62)
		needle_juice.scale.x = maxf(0.04, 1.0 - push); needle_juice.position.x = 0.002 - push * 0.058
	else: needle.visible = false
	if inspect: pos = Vector3(0.02, -0.03, -0.62 - d[0] * 0.25); rot = Vector3(0.18, 1.15, 0.0)   # held out to look at
	var GM: Dictionary = gm_models.models[guns.cur]
	if GM.tip != null: (GM.tip as Node3D).visible = guns.st().mag > 0   # the rocket's nose shows while one is loaded
	view.position = pos; view.rotation = rot
	flash.visible = guns.flash_t > 0.0 and guns.ads < 0.5 and (not toy or guns.cur == "smg"); flash.position = Vector3(0, 0, -d[0] - 0.05) if toy else Vector3(0, GunModels.MUZZLE[guns.cur][1], GM.flash_z)
	flash_light.light_energy = (3.0 if not toy else (1.2 if guns.cur == "smg" else 0.0)) if guns.flash_t > 0.0 else flash_light.light_energy * exp(-dt * 30)
	var heat: Dictionary = guns.wstate.lmg  # the machine gun goes red as it heats
	var hk: float = (0.9 + 0.1 * sin(time * 18.0)) if heat.hot else pow(heat.heat, 1.6)
	if absf(hk - heat_k) > 0.004: heat_k = hk; gm_models.heat("lmg", hk)
	# the laser's red dot, out in the world where the crosshair falls
	var dot_on: bool = not toy and state == "playing" and not guns.none and Custom.setup(guns.cur).under == "laser" and guns.switch_t <= 0.0 and guns.reload_t <= 0.0
	if dot_on:
		var o2 := cam.global_position; var f2 := -cam.global_basis.z
		if Phys.raycast_static(o2, f2, 90.0): var t2 := Phys.rh_t - 0.04; laser_dot.visible = true; laser_dot.position = o2 + f2 * t2; laser_dot.scale = Vector3.ONE * (0.35 + t2 * 0.035)
		else: laser_dot.visible = false
	elif not toy: laser_dot.visible = false

# ---------------- the HUD ----------------
func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	return l

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud); hud.draw.connect(_draw_hud)
	hudd = Hud.new(); hudd.m = self
	touch_ui = Control.new(); touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT); touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; touch_ui.visible = false; root.add_child(touch_ui); touch_ui.draw.connect(_draw_touch)
	fps_label = _label("", f_mono, 12, SODIUM); fps_label.position = Vector2(12, 40); fps_label.z_index = 50; root.add_child(fps_label)

func _draw_hud() -> void:
	hudd.draw(hud)

## what the keys would do now, for the hint under the crosshair: pick up the hall's key, get on, change over, get off
func key_hint() -> String:
	if world.ship != null and world.ship.key_near(): return "E 키로 메인홀 열쇠 줍기"
	if int(guns.st().mag) <= 0 or not world.style.get("ride", false): return ""
	var an := enemies.animals; var act := _ride_act()
	if act == "": return ""
	return "E 키로 " + act + (" · X 키로 내리기" if (an.m != null and act != "내리기") else "")

func banner(title: String, sub: String, sec: float) -> void: hudd.banner(title, sub, sec)
func hint(text: String, sec: float) -> void: hudd.hint(text, sec)
func feed(text: String, pay := 0, red := false) -> void:
	if look_mode == "touch" and pay > 0: return   # on a phone the kill lines are left out: the bag at the top still counts up
	hudd.say_feed(text, pay, red)

## what E (or the button) would do now: get on, change over, or get off
func _ride_act() -> String:
	var an := enemies.animals; var tg := an.target if (an.target != null and an.target.alive) else null
	if tg != null: var nm: String = Animals.SEAT[tg.type].name; return nm + (Animals.euro(nm) + " 옮겨 타기" if an.m != null else " 타기")
	return "내리기" if an.m != null else ""

## the touch layout of the browser game: the D-pad at the left middle, the pause button top left, the map top right
func _touch_rects() -> Dictionary:
	var s := hud.size
	return {"pad": Rect2(10, s.y / 2.0 - 78.0, 156, 156), "pause": Rect2(16, 14, 42, 42), "map": Rect2(s.x - 14.0 - 46.0, 14, 46, 46)}

## the round buttons on the right: [centre, radius, label] (a little smaller and closer on a very short screen)
func _touch_buttons() -> Dictionary:
	var s := hud.size; var short := s.y <= 340.0
	var at := func(right: float, bottom: float, d: float) -> Vector2: return Vector2(s.x - right - d / 2.0, s.y - bottom - d / 2.0)
	var b := {}
	if short:
		b = {"fire": [at.call(26, 104, 78), 39.0, "사격"], "ads": [at.call(116, 152, 50), 25.0, "조준"], "jump": [at.call(116, 90, 50), 25.0, "점프"], "melee": [at.call(116, 28, 50), 25.0, "근접"],
			"reload": [at.call(50, 196, 50), 25.0, "장전"], "swap": [at.call(112, 214, 50), 25.0, "교체"]}
	else:
		b = {"fire": [at.call(28, 120, 84), 42.0, "사격"], "ads": [at.call(128, 170, 54), 27.0, "조준"], "jump": [at.call(128, 100, 54), 27.0, "점프"], "melee": [at.call(128, 30, 54), 27.0, "근접"],
			"reload": [at.call(52, 220, 54), 27.0, "장전"], "swap": [at.call(116, 240, 54), 27.0, "교체"]}
	if player.jet_on: b["down"] = [at.call(200, 96, 60), 30.0, "내려가기"]
	return b

## the pill buttons low in the middle: the antidote (while infected or poisoned), getting on or the hall's key, getting off
func _touch_pills() -> Dictionary:
	var s := hud.size; var p := {}
	var pill := func(text: String, bottom: float, h: float, pad: float, fs: int) -> Rect2:
		var w := f_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad * 2.0; return Rect2(s.x / 2.0 - w / 2.0, s.y - bottom - h, w, h)
	if (game.infected or game.poison_t > 0.0) and not game.inject_on:
		var at := "해독약 사용 (%d)" % game.antidotes if game.antidotes > 0 else "해독약 없음"; p["anti"] = [pill.call(at, 150, 54, 24, 15), at]
	var key := world.ship != null and world.ship.key_near(); var act := "메인홀 열쇠 줍기" if key else _ride_act()
	if act != "": p["car"] = [pill.call(act, 16, 50, 26, 15), act]
	if enemies.animals.m != null and enemies.animals.target != null: p["off"] = [pill.call("내리기", 76, 40, 18, 13), "내리기"]
	return p

func _sbox(bg: Color, line: Color, r: int, bw := 1.5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = line; sb.set_border_width_all(int(ceilf(bw))); sb.set_corner_radius_all(r); return sb

func _draw_touch() -> void:
	var r := _touch_rects(); var p: Rect2 = r.pad; var o := p.position; var key_line := Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.32); var arrow := Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.88)
	# the D-pad: four keys round a hub; a pressed arrow lights up, and ▲ turns solid while running
	touch_ui.draw_style_box(_sbox(Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.28), Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.14), 8, 1.0), Rect2(o + Vector2(52, 52), Vector2(52, 52)))
	for k in [["up", Vector2(52, 0), Vector2(0, -1)], ["down", Vector2(52, 104), Vector2(0, 1)], ["left", Vector2(0, 52), Vector2(-1, 0)], ["right", Vector2(104, 52), Vector2(1, 0)]]:
		var d: Vector2 = k[2]; var on := (d.x != 0 and signf(joy.x) == d.x) or (d.y != 0 and signf(joy.y) == d.y)
		var bg := SODIUM if (k[0] == "up" and pad_sprint) else (Color(SODIUM, 0.5) if on else Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.42))
		var kr := Rect2(o + k[1], Vector2(52, 52)); touch_ui.draw_style_box(_sbox(bg, SODIUM if on else key_line, 10), kr)
		var c := kr.get_center(); var n := Vector2(-d.y, d.x) * 11.0
		touch_ui.draw_colored_polygon(PackedVector2Array([c + d * 9.0, c - d * 6.0 + n, c - d * 6.0 - n]), arrow)
	if pad_sprint: touch_ui.draw_string(f_bold, o + Vector2(52, -9), "달리기", HORIZONTAL_ALIGNMENT_CENTER, 52, 11, SODIUM)
	var tb := _touch_buttons()
	for k in tb:
		var b: Array = tb[k]; var on: bool = (k == "fire" and guns.trigger) or (k == "ads" and guns.ads_held)
		touch_ui.draw_circle(b[0], b[1], Color(242 / 255.0, 163 / 255.0, 58 / 255.0, 0.45) if on else Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.45))
		touch_ui.draw_arc(b[0], b[1], 0, TAU, 40, SODIUM if on else Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.35), 1.5)
		touch_ui.draw_string(f_mono, b[0] + Vector2(-b[1], 4), b[2], HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2, 12 if k == "fire" else 11, INK)
	for k in _touch_pills():
		var q: Array = _touch_pills()[k]; var pr: Rect2 = q[0]
		var bg := Color(242 / 255.0, 163 / 255.0, 58 / 255.0, 0.9) if k == "car" else (Color(94 / 255.0, 214 / 255.0, 176 / 255.0, 0.4) if k == "anti" else Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.55))
		var ln := SODIUM if k == "car" else (VITAL if k == "anti" else Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.35))
		touch_ui.draw_style_box(_sbox(bg, ln, int(pr.size.y / 2.0)), pr)
		touch_ui.draw_string(f_bold, Vector2(pr.position.x, pr.get_center().y + 5), q[1], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13 if k == "off" else 15, NIGHT if k == "car" else INK)
	var q2: Rect2 = r.pause; touch_ui.draw_style_box(_sbox(Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.45), Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.35), 4), q2)
	touch_ui.draw_string(f_mono, Vector2(q2.position.x, q2.get_center().y + 5), "II", HORIZONTAL_ALIGNMENT_CENTER, q2.size.x, 13, INK)
	var mq: Rect2 = r.map; touch_ui.draw_style_box(_sbox(Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.45), Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.35), 6), mq)
	touch_ui.draw_string(f_bold, Vector2(mq.position.x, mq.get_center().y + 5), "지도", HORIZONTAL_ALIGNMENT_CENTER, mq.size.x, 12, INK)

# ---------------- states ----------------
func _set_state(s: String) -> void:
	state = s
	hud.visible = s == "playing"; touch_ui.visible = s == "playing" and look_mode == "touch"
	if s != "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joy = Vector2.ZERO; joy_id = -1; look_id = -1; fire_id = -1; pad_sprint = false
	if guns: guns.trigger = false; guns.ads_held = false
	if view: view.visible = s == "playing" or s == "paused"

func to_menu() -> void:
	game.sp = null   # leaving for the menu ends the run, save point and all
	if not game.ended and game.stats.time > 0.0: game.forfeit()
	game.return_rentals(); Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
	enemies.clear(); proj.clear(); loot.clear(); fx.clear(); player.jet_end()
	cam.fov = base_fov; ui.in_stage = false; ui.back_stack.clear(); cut.abort(); _set_state("menu"); ui.show_screen("menu")

func enter_play(intro := false) -> void:
	for gid in Weapons.ORDER: gm_models.show_hands(gid, true)
	if cu_light != null: cu_light.visible = false
	guns.look_mode = look_mode; apply_settings(); hudd.reset(); ui.in_stage = true
	if world.ship != null: world.ship.on_cut = _boss_cut
	if intro and world.toy == null:   # (the toy room has its own way in: you come down under a parachute)
		_set_state("cutscene"); cut.touch = look_mode == "touch"; cut.start_intro(game.stage, _go_play)
	else: _go_play()

## the fight starts (after the opening scene, or at once)
func _go_play() -> void:
	_set_state("playing"); request_lock(); player.invuln = maxf(player.invuln, 1.5)
	if game.boss_msg != "": banner("스테이지 " + Store.STAGE_TAG[game.stage], game.boss_msg, 3.5)
	hint("1번 우리가 10초 뒤에 열립니다 · 창살 사이로 쏠 수 있습니다" if world.lab != null else ("마우스 이동으로 조준 · Q/E로 회전 · M 키로 지도" if look_mode == "drag" else ("오른쪽 위 지도 버튼으로 적 위치를 볼 수 있습니다" if look_mode == "touch" else "M 키로 작전 지도를 볼 수 있습니다")), 3.5)

## the ship: standing at a sealed door, a short look at what waits inside before it locks behind you
func _boss_cut(D: Dictionary, e: Enemies.Foe, done: Callable) -> void:
	_set_state("cutscene"); player.jet_end(); cut.touch = look_mode == "touch"
	cut.start_boss_intro(D, e, func() -> void: done.call(); _back_to_play())

func _back_to_play() -> void:
	_set_state("playing"); player.invuln = maxf(player.invuln, 1.0); request_lock()

func _on_result(kind: String) -> void:
	if kind == "clear" and state == "playing" and world.toy == null:   # out by helicopter (the lab's door, the ship's airlock), then the result
		_set_state("cutscene"); cut.touch = look_mode == "touch"; cut.start_outro(func() -> void: _show_result("clear")); return
	_show_result(kind)

func _show_result(kind: String) -> void:
	_set_state("gameover"); ui.in_stage = false; ui.show_result(kind); cut.fade_to = 0.0

func pause_game(msg := "") -> void:
	if state != "playing": return
	_set_state("paused"); ui.pa_note_text = msg; ui.back_stack.clear(); ui.show_screen("pause")

## the tactical map over the paused fight: from play (M, the touch map button) it goes back to play, from the pause back to the pause
var map_from := ""
func open_map(from: String) -> void:
	if from == "play" and state != "playing": return
	if from == "pause" and state != "paused": return
	map_from = from; guns.trigger = false
	if state == "playing": _set_state("paused")
	ui.back_stack.clear(); ui.open_map(look_mode == "touch")

func close_map() -> void:
	if ui.cur != "map": return
	var from := map_from; map_from = ""
	if from == "pause": ui.show_screen("pause")
	else: resume_game()

func resume_game() -> void:
	if state != "paused": return
	ui.back_stack.clear(); ui.show_screen(""); apply_settings(); _set_state("playing"); request_lock()

func request_lock() -> void:
	if look_mode != "lock": return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lock_wait = 1.4  # if the browser has not locked the pointer by then, aim by moving the mouse instead

# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if state == "cutscene":
		if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_E]) or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed): cut.skip()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F3 or e.physical_keycode == KEY_QUOTELEFT: Store.settings.fps = not Store.settings.fps; Store.persist_settings()  # some browsers keep F3 for themselves: the ` key does the same
		elif state == "playing":
			if e.physical_keycode == KEY_SPACE: player.jump_buf = 0.15; player.jet_tap(Time.get_ticks_msec() / 1000.0)
			if e.physical_keycode == KEY_R: guns.start_reload()
			if e.physical_keycode == KEY_V: guns.melee_start()
			if e.physical_keycode == KEY_F: game.use_antidote()
			if (e.physical_keycode == KEY_E and look_mode != "drag") or e.physical_keycode == KEY_G:
				if not (world.ship != null and world.ship.take_key()): enemies.animals.ride_toggle()
			if e.physical_keycode == KEY_X and enemies.animals.m != null: enemies.animals.ride_off(false)
			if e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_9: guns.switch_slot(e.physical_keycode - KEY_1)
			if e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P: pause_game()
			if e.physical_keycode == KEY_M: open_map("play")
		elif state == "paused" and ui.cur == "map" and (e.physical_keycode == KEY_M or e.physical_keycode == KEY_ESCAPE): close_map()
		elif state == "paused" and ui.cur == "pause" and e.physical_keycode == KEY_M: open_map("pause")
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
			if (r.map as Rect2).has_point(p): open_map("play"); return
			var tb := _touch_buttons(); var hit := ""
			for k in tb:
				if p.distance_to(tb[k][0]) <= tb[k][1] + 6.0: hit = k; break
			var pills := _touch_pills()
			for k in pills:
				if hit == "" and (pills[k][0] as Rect2).grow(4).has_point(p): hit = k
			match hit:
				"fire":  # the firing thumb also aims
					guns.trigger = true; guns.trigger_edge = true; fire_id = e.index
					if look_id < 0: look_id = e.index
				"jump": player.jump_buf = 0.15; player.jet_tap(Time.get_ticks_msec() / 1000.0); player.in_up = true; set_meta("jump_id", e.index)
				"down": player.in_down = true; set_meta("down_id", e.index)
				"ads": guns.ads_held = not guns.ads_held
				"reload": guns.start_reload()
				"melee": guns.melee_start()
				"anti": game.use_antidote()
				"car":
					if not (world.ship != null and world.ship.take_key()): enemies.animals.ride_toggle()
				"off": enemies.animals.ride_off(false)
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
	if world.lab != null: world.lab.anim(dt, time)
	if player.jet_on:
		jet_puff_t -= dt
		if jet_puff_t <= 0.0:
			jet_puff_t = 0.05; fx.puff(Vector3(player.pos.x + sin(player.yaw) * 0.35, player.pos.y + 0.6, player.pos.z + cos(player.yaw) * 0.35), 1, 0.35, 0.35)
			fx.glow(Vector3(player.pos.x + sin(player.yaw) * 0.3, player.pos.y + 0.7, player.pos.z + cos(player.yaw) * 0.3), Vector3(0, -4, 0), 0.25, 0.25, 0.05, Color(1, 0.6, 0.25, 0.8), 0.0, 1.0)
	var an := enemies.animals; an.find_t -= dt   # what you could get on (E or the touch button), looked for a few times a second
	if an.find_t <= 0.0: an.find_t = 0.15; an.target = an.ride_find() if world.style.get("ride", false) else null

## a cutscene's frame: the world moves (lamps, the lab's monkey and beacons, the ship's airlock), the fight does not
func _cut_step(dt: float) -> void:
	time += dt; cut.update(dt); fx.update(dt); world.update_world(dt, time, cam.global_position.x, cam.global_position.z)
	if world.lab != null: world.lab.anim(dt, time)
	if world.ship != null: world.ship.anim_door(dt)
	Snd.listener = cam.global_position

var hold := false
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
		if state == "playing" and not hold:
			tick(dt); _pose_gun(dt); Snd.listener = cam.global_position
			hudd.update(dt); hud.queue_redraw()
			if touch_ui.visible: touch_ui.queue_redraw()   # the pills come and go with what is happening
	elif state == "cutscene":
		_cut_step(dt)
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
		# the customisation screen: the gun you are fitting out turns slowly beside the sheet (on a screen wide enough to have a beside)
		var cu: bool = ui.cur == "custom" and hud.size.x >= 980.0
		for id in gun_models: (gun_models[id] as Node3D).visible = cu and id == ui.cu_gun
		for id in toy_models: (toy_models[id] as Node3D).visible = false
		ruler.visible = false; flash.visible = false; needle.visible = false
		if cu_light == null: cu_light = OmniLight3D.new(); cu_light.omni_range = 4.0; cu_light.light_energy = 0.9; cu_light.light_color = Color(1.0, 0.96, 0.9); cam.add_child(cu_light)
		cu_light.visible = cu
		view.visible = cu
		if cu:
			cu_ang += dt * 0.45; gm_models.apply_look(ui.cu_gun, Custom.setup(ui.cu_gun)); gm_models.show_hands(ui.cu_gun, false)
			var dist := 0.55 + absf(GunModels.MUZZLE[ui.cu_gun][0]) * 0.9; var hw := tan(deg_to_rad(cam.fov) / 2.0) * dist * hud.size.x / maxf(1.0, hud.size.y)
			var bas := Basis(Vector3.UP, cu_ang); var mid := Vector3(0, 0, GunModels.MUZZLE[ui.cu_gun][0] / 2.0 + 0.12)
			view.rotation = Vector3(0, cu_ang, 0); view.position = Vector3(-hw * (0.5 + 310.0 / hud.size.x), 0.02, -dist) - bas * mid
			cu_light.position = Vector3(-hw * (0.5 + 310.0 / hud.size.x) + 0.3, 0.5, -dist + 0.7)
	cut.tick_fade(dt)
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
			if not (a.size() > 2 and a[2] == "intro"): cut.skip(); cut.set_fade(0.0, 0.0)
			if look_mode == "lock": look_mode = "drag"; guns.look_mode = "drag"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"menu": to_menu(); menu_t = float(a[1]) if a.size() > 1 else menu_t
		"screen": ui.shop_ctx = ui.sel; ui.open_sub(a[1])
		"select": ui.sel = int(a[1]); ui.refresh_menu()
		"brief": state = "brief"; ui.open_brief(int(a[1]))
		"back": ui.close_sub()
		"pause": pause_game()
		"map": open_map(a[1] if a.size() > 1 else "play")
		"mapclose": close_map()
		"skip": cut.skip()
		"dialog": ui.open_dialog(a[1])
		"mailaddr": ui.mail_in.text = a[1] if a.size() > 1 else ""; Store.settings.mailTo = ui.mail_in.text
		"mail": (ui._copy_mail() if a[1] == "copy" else ui._send_mail(a[1]))
		"resume": resume_game()
		"money": Store.save.money = int(a[1]); Store.persist(); ui.refresh_menu()
		"dev": Store.settings.dev = a[1] == "1"; Store.settings.god = a.size() > 2 and a[2] == "1"; ui.refresh_menu()
		"reset": Store.save = Store.save0(); Store.fix_save(); Store.persist(); ui.refresh_menu()
		"at": player.pos = Vector3(float(a[1]), 0, float(a[2])); player.vel = Vector3.ZERO; player.yaw = float(a[3]); player.pitch = float(a[4]) if a.size() > 4 else 0.0
		"sim":
			for i in roundi(float(a[1]) * 30):
				if state == "playing": tick(1.0 / 30.0)
				elif state == "cutscene": _cut_step(1.0 / 30.0); cut.tick_fade(1.0 / 30.0)
		"killall":   # every enemy but the boss (or the boss too with 'boss')
			for e in enemies.list.duplicate():
				if not e.boss or (a.size() > 1 and a[1] == "boss"): enemies.damage(e, 1e6, e.pos, Vector3(0, 0, -1), false)
		"inspect": inspect = a[1] == "1"
		"part": Custom.set_part(a[1], a[2], a[3]); apply_settings()
		"cugun": ui.cu_gun = a[1]; ui.render_custom()
		"bite": game.bitten(enemies.list[0])
		"lineup":   # stage 5: one of each kind of toy in a row on the carpet, 8 m in front of you
			var kinds := ["soldier", "figure", "rc", "brick"]
			for i in 4:
				var lst: Array = enemies.list.filter(func(e): return e.type == kinds[i])
				if lst.is_empty(): continue
				var e = lst[0]; e.pos = Vector3(-4.5 + i * 3.0, 0, 46.0); e.yaw = 0.0; e.vel = Vector3.ZERO; e.k.post = e.pos; e.g.position = e.pos; e.g.rotation.y = 0.0
			player.pos = Vector3(0, 0, 54); player.yaw = 0.0; player.pitch = -0.08; player.vel = Vector3.ZERO
		"glide":   # stage 5: an action figure dropped from 12 m in front of you, cape out
			var fl: Array = enemies.list.filter(func(e): return e.type == "figure")
			var f = fl[1]; f.pos = Vector3(2, 12, 46); f.vy = 0.0; f.k.glide = true; f.k.jumps = 2; f.alert = true
		"wall":   # stage 5: the brick figure in the lineup puts up a wall
			var bl: Array = enemies.list.filter(func(e): return e.type == "brick")
			enemies.toys._build_wall(bl[0], Vector2(0, 1))
		"takekey": world.ship.take_key()
		"hurt": player.invuln = 0.0; player.hurt(float(a[1]), Vector3.ZERO)
		"hold": hold = a[1] == "1"   # the clock stands still between bridge steps (for pictures of things that last a split second)
		"boom": # pictures of the effects: a blast (or dust, sparks, a bullet hole) this many metres in front of the camera
			var at := cam.global_position - cam.global_basis.z * (float(a[2]) if a.size() > 2 else 8.0)
			match a[1] if a.size() > 1 else "big":
				"small": fx.explode(at, false)
				"puff": fx.puff(at, 12, 0.6, 1.0)
				"white": fx.puff(at, 6, 1.0, 3.0)
				"crate":   # break the crate nearest to you
					var best = null
					for c in world.crates:
						if not c.dead and (best == null or Vector2(c.x - player.pos.x, c.z - player.pos.z).length() < Vector2(best.x - player.pos.x, best.z - player.pos.z).length()): best = c
					if best != null: world.damage_crate(best, 99999, Vector3(best.x, best.y + 0.6, best.z))
				"sparks": fx.sparks(at, 30, [1.0, 0.78, 0.45], 3.2)
				"hole": fx.decal(at, cam.global_basis.z)
				_: fx.explode(at, true)
		"again": ui.do_again.call(game.stage)
		"ride": enemies.animals.ride_toggle()
		"stampede": world.safari.t = Safari.T_STAMPEDE - 0.5
		"labt": world.lab.t = float(a[1])
		"key": player.in_f = float(a[1])
		"poison": game.poison(enemies.list[0])
		"anti": game.use_antidote()
		"take": game.take_loot(a[1])
		"reload": guns.st().mag = int(a[1]) if a.size() > 1 else 0; guns.start_reload()
		"cam":   # a free camera for pictures: x y z yaw pitch
			_set_state("shot"); ui.show_screen(""); cam.fov = base_fov; cam.position = Vector3(float(a[1]), float(a[2]), float(a[3])); cam.rotation = Vector3(float(a[5]), float(a[4]), 0)
		"gun": guns.cur = a[1]; guns.pending = null; guns.switch_t = 0.0; guns.cooldown = 0.0
		"trigger": guns.trigger = a[1] == "1"; guns.trigger_edge = guns.trigger
		"ads": guns.ads_held = a[1] == "1"
		"touch": look_mode = "touch"; guns.look_mode = "touch"; apply_settings(); touch_ui.visible = state == "playing"
	return {"state": state, "screen": ui.cur, "cut": cut.kind(), "link": ui.last_link, "dlgmsg": ui.dlg_msg.text, "clip": DisplayServer.clipboard_get() if a[0] == "mail" else "", "fade": cut.fade.color.a if cut.fade != null else 0.0, "look": look_mode, "pos": [player.pos.x, player.pos.y, player.pos.z], "yaw": player.yaw, "grounded": player.grounded,
		"colliders": Phys.colliders.size(), "specks": fx.live(), "crates": world.crates.filter(func(c): return not c.dead).size(), "enemies": enemies.list.size(), "kills": game.kills, "goal": game.goal, "ended": game.ended, "result": game.result,
		"gun": guns.cur, "slots": guns.slots, "mag": guns.st().mag, "hp": player.hp, "ads": guns.ads, "fov": cam.fov, "money": Store.save.money, "cleared": Store.save.cleared, "owned": Store.save.owned,
		"calm": game.calm, "riding": enemies.animals.m.type if enemies.animals.m != null else "", "bleed": enemies.animals.bleed_n, "tower": world.safari.hp if world.safari != null else -1.0, "cages": world.lab.cages.filter(func(c): return c.open).size() if world.lab != null else -1, "key": world.ship.key if world.ship != null else false, "doors": world.ship.doors.map(func(d): return d.mode) if world.ship != null else [], "phase": int(game.boss.k.get("phase", -1)) if game.boss != null else -1, "pit": Phys.PIT != null, "sp": game.sp != null, "infected": game.infected, "poison": game.poison_t, "antidotes": game.antidotes, "inject": game.inject_on, "stun": player.stun_t, "chest": loot.chests.size(), "boss": [game.boss.pos.x, game.boss.pos.z] if game.boss != null else [], "fit": Meta.fits(ui.sel), "ui": [ui.size.x, ui.size.y, ui._mode(), ui.detail.position.x, ui.detail.size.x, ui.board.size.x, ui.rail.size.x], "fps": Engine.get_frames_per_second(), "size": [hud.size.x, hud.size.y], "dpr": dpr}
