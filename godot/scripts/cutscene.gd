class_name Cut
extends Node3D
## The cutscenes (src/08d_cutscene.js). A helicopter brings you in: you sit in its open door over the drop point, slide down a rope and
## watch it pull away; after a clear it comes back, a rope ladder drops and you climb in. The lab has no helicopter: a look over the
## cages, the monkey slams his red button, every cage starts counting; leaving, the sealed door rolls up and you walk out. The ship:
## in the airlock the inner door rolls up and you step out (it shuts behind you); leaving, you walk back in and it shuts. At the ship's
## two sealed doors, a second and a half inside before the door locks behind you. Space, Esc, Enter, E, a click or a tap skips;
## skipped or not, it ends in the same state.

const OLIVE := "4a5236"; const DARK := "2a2d31"; const GLASS := "1d3448"; const STRIPE := "d6a12e"; const FLOOR := "3a3d38"

var cam: Camera3D; var player: Player; var game: Game; var world: World; var enemies: Enemies; var fx: Fx
var touch := false
var C := {}
var clock := 0.0   # its own time, for the hover's bob
var heli: Node3D; var rotor: Node3D; var tail: Node3D; var beam: MeshInstance3D; var pool: MeshInstance3D; var pool_mat: Material; var rope: Node3D
var fig: Node3D; var arm_l: Node3D; var arm_r: Node3D
# the screen: black bars top and bottom, the caption, the skip line, a boss's name, and a black fade
var overlay: Control; var cap: VBoxContainer; var cap_title: Label; var cap_sub: Label; var skip_lbl: Label; var card: Label; var fade: ColorRect
var fade_to := 0.0
var cap_t := 0.0; var card_t := 0.0

func active() -> bool: return not C.is_empty()
func kind() -> String: return str(C.get("kind", ""))

static func ease_(t: float) -> float: return t * t * (3.0 - 2.0 * t)

## boxes (and a few balls) in one coloured mesh: [w, h, d, x, y, z, colour, rotation?, ball?]
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var ball: bool = p.size() > 8 and p[8]
		var src: PrimitiveMesh
		if ball: var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; sp.radial_segments = 10; sp.rings = 7; src = sp
		else: var bx := BoxMesh.new(); src = bx
		var bas := Basis.from_scale(Vector3(p[0], p[1], p[2]))
		if p.size() > 7 and p[7] is Array: var e: Array = p[7]; bas = Basis(Vector3.BACK, e[2]) * Basis(Vector3.UP, e[1]) * Basis(Vector3.RIGHT, e[0]) * bas   # three.js: x, then y, then z
		var a := src.get_mesh_arrays(); var col := Color(str(p[6])); var xf := Transform3D(bas, Vector3(p[3], p[4], p[5]))
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]; var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i in ix: st.set_color(col); st.set_normal((bas.inverse().transposed() * ns[i]).normalized()); st.add_vertex(xf * vs[i])
	return st.commit()

static func _vmat(rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.roughness = rough; m.metallic = metal; return m

func _ready() -> void:
	# a utility helicopter, its door open on one side, built from panels so the cabin reads from inside too
	heli = Node3D.new(); heli.rotation_order = EULER_ORDER_YXZ; add_child(heli)
	var body := MeshInstance3D.new(); body.material_override = _vmat(0.65, 0.25); heli.add_child(body)
	body.mesh = merge([[2.3, 0.12, 4.2, 0, 0.75, 0, FLOOR], [2.3, 0.12, 4.2, 0, 2.75, 0, OLIVE], [0.1, 2.0, 4.2, -1.12, 1.75, 0, OLIVE],
		[2.3, 2.0, 0.1, 0, 1.75, -2.1, OLIVE], [0.1, 0.5, 4.2, 1.12, 0.95, 0, OLIVE], [0.1, 0.45, 4.2, 1.12, 2.55, 0, OLIVE],
		[2.2, 1.9, 1.9, 0, 1.75, 2.9, OLIVE, null, true], [1.9, 1.1, 1.2, 0, 2.15, 3.35, GLASS, null, true],
		[0.62, 0.62, 5.8, 0, 2.25, -4.9, OLIVE], [0.16, 1.7, 1.1, 0, 3.0, -7.6, OLIVE], [2.2, 0.1, 0.65, 0, 2.3, -7.0, OLIVE],
		[0.2, 0.62, 0.9, 0, 2.25, -6.3, STRIPE], [1.4, 0.7, 2.6, 0, 3.15, -0.3, DARK], [0.18, 0.6, 0.18, 0, 3.75, 0, DARK],
		[0.12, 0.12, 4.6, -1.25, 0.08, 0.2, DARK], [0.12, 0.12, 4.6, 1.25, 0.08, 0.2, DARK],
		[0.1, 0.7, 0.1, -1.2, 0.4, 1.4, DARK], [0.1, 0.7, 0.1, 1.2, 0.4, 1.4, DARK], [0.1, 0.7, 0.1, -1.2, 0.4, -1.2, DARK], [0.1, 0.7, 0.1, 1.2, 0.4, -1.2, DARK],
		[0.55, 0.5, 0.5, -0.5, 1.05, -1.6, "24262a"], [0.55, 0.5, 0.5, 0.5, 1.05, -1.6, "24262a"], [1.6, 0.7, 0.12, 0, 1.45, -1.95, "24262a"],
		[0.3, 0.2, 0.4, 0.75, 0.35, 3.4, "cfcfcf"]])
	var blade := StandardMaterial3D.new(); blade.albedo_color = Color("1c1e21"); blade.roughness = 0.6
	rotor = Node3D.new(); rotor.position = Vector3(0, 4.08, 0); heli.add_child(rotor)
	for i in 4:
		var arm := Node3D.new(); arm.rotation.y = i * PI / 2.0; rotor.add_child(arm)
		var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.32, 0.05, 7.2); b.mesh = bm; b.material_override = blade; b.position.z = 3.6; arm.add_child(b)
	var disc := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 7.2; dm.bottom_radius = 7.2; dm.height = 0.001; dm.radial_segments = 32; disc.mesh = dm
	var dmat := StandardMaterial3D.new(); dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dmat.albedo_color = Color(Color("9aa4b4"), 0.1); dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED; dmat.no_depth_test = false; disc.material_override = Gfx.see_through(dmat); disc.position.y = 4.08; disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; heli.add_child(disc)
	tail = Node3D.new(); tail.position = Vector3(0.2, 3.0, -7.6); heli.add_child(tail)
	for i in 2:
		var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.04, 1.5, 0.16); b.mesh = bm; b.material_override = blade; b.rotation.x = i * PI / 2.0; tail.add_child(b)
	# the searchlight's cone under it and the pool of light on the ground (at night)
	beam = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 5.0; cm.height = 18.0; cm.radial_segments = 20; cm.cap_top = false; cm.cap_bottom = false; beam.mesh = cm
	var bg := Gradient.new(); bg.set_color(0, Color(1, 1, 1, 1)); bg.set_color(1, Color(1, 1, 1, 0)); var bt := GradientTexture2D.new(); bt.gradient = bg; bt.fill_from = Vector2(0, 0); bt.fill_to = Vector2(0, 1)
	var bmat := StandardMaterial3D.new(); bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bmat.albedo_color = Color(Color("fff2d0"), 0.12); bmat.albedo_texture = bt
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bmat.cull_mode = BaseMaterial3D.CULL_DISABLED; bmat.disable_fog = true; beam.material_override = Gfx.see_through(bmat)
	beam.position = Vector3(0, -8, 3.5); beam.rotation.x = 0.35; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; heli.add_child(beam)
	pool = MeshInstance3D.new(); var pq := PlaneMesh.new(); pq.size = Vector2(14, 14); pool.mesh = pq
	var pg := Gradient.new(); pg.set_color(0, Color(1, 1, 1, 1)); pg.set_color(1, Color(1, 1, 1, 0)); var pt := GradientTexture2D.new(); pt.gradient = pg; pt.fill = GradientTexture2D.FILL_RADIAL; pt.fill_from = Vector2(0.5, 0.5); pt.fill_to = Vector2(1.0, 0.5)
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.albedo_color = Color("fff2d0"); pm.albedo_texture = pt
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; pool_mat = Gfx.see_through(pm); pool.material_override = pool_mat; pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.visible = false; add_child(pool)
	rope = Node3D.new(); var rm := MeshInstance3D.new(); var rc := CylinderMesh.new(); rc.top_radius = 0.035; rc.bottom_radius = 0.035; rc.height = 1.0; rc.radial_segments = 6; rm.mesh = rc
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color("6b5a3a"); rmat.roughness = 0.9; rm.material_override = rmat; rm.position.y = -0.5; rope.add_child(rm); rope.visible = false; add_child(rope)
	# you, seen from outside: dark kit, a helmet, a rifle across the back
	fig = Node3D.new(); fig.rotation_order = EULER_ORDER_YXZ; add_child(fig)
	var fm := _vmat(0.85); var fb := MeshInstance3D.new(); fb.material_override = fm; fig.add_child(fb)
	fb.mesh = merge([[0.46, 0.64, 0.28, 0, 1.28, 0, "2f3a2a"], [0.36, 0.3, 0.12, 0, 1.3, 0.16, "3d4a33"], [0.23, 0.25, 0.24, 0, 1.72, 0.01, "c99a7a"],
		[0.28, 0.16, 0.3, 0, 1.86, 0, "3a4430", null, true], [0.08, 0.08, 0.9, 0.12, 1.3, -0.2, "1d2024", [0.9, 0, 0]],
		[0.16, 0.9, 0.18, -0.11, 0.47, 0, "2a3326"], [0.16, 0.9, 0.18, 0.11, 0.47, 0, "2a3326"], [0.17, 0.1, 0.28, -0.11, 0.04, 0.05, "161616"], [0.17, 0.1, 0.28, 0.11, 0.04, 0.05, "161616"]])
	for sx in [-1.0, 1.0]:
		var a := Node3D.new(); a.position = Vector3(0.3 * sx, 1.52, 0); fig.add_child(a)
		var am := MeshInstance3D.new(); am.material_override = fm; am.mesh = merge([[0.12, 0.6, 0.13, 0, -0.28, 0, "2f3a2a"], [0.1, 0.1, 0.1, 0, -0.6, 0, "2a2a2a"]]); a.add_child(am)
		if sx < 0: arm_l = a
		else: arm_r = a
	heli.visible = false; fig.visible = false

## the black bars, the caption and the rest, in the HUD's layer (under the menus: the result sheet comes up over the fade)
func build_overlay(parent: Control, f_title: Font, f_mono: Font) -> void:
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.visible = false; parent.add_child(overlay)
	for top in [true, false]:
		var r := ColorRect.new(); r.color = Color.BLACK; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(r)
		r.anchor_left = 0; r.anchor_right = 1; r.anchor_top = 0.0 if top else 0.89; r.anchor_bottom = 0.11 if top else 1.0
	cap = VBoxContainer.new(); cap.add_theme_constant_override("separation", 4); cap.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(cap)
	cap_title = Label.new(); cap_title.add_theme_font_override("font", f_title); cap_title.add_theme_color_override("font_color", Color("ece6d8"))
	cap_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75)); cap_title.add_theme_constant_override("shadow_offset_y", 2); cap_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cap.add_child(cap_title)
	cap_sub = Label.new(); cap_sub.add_theme_font_override("font", f_mono); cap_sub.add_theme_font_size_override("font_size", 13); cap_sub.add_theme_color_override("font_color", Color("f2a33a"))
	cap_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9)); cap_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cap.add_child(cap_sub)
	skip_lbl = Label.new(); skip_lbl.add_theme_font_override("font", f_mono); skip_lbl.add_theme_font_size_override("font_size", 11); skip_lbl.add_theme_color_override("font_color", Color(0.925, 0.902, 0.847, 0.65)); overlay.add_child(skip_lbl)
	card = Label.new(); card.add_theme_font_override("font", f_title); card.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7)); card.add_theme_constant_override("shadow_offset_y", 4); card.add_theme_constant_override("shadow_outline_size", 10); card.visible = false; overlay.add_child(card)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; fade.set_anchors_preset(Control.PRESET_FULL_RECT); parent.add_child(fade)

## the caption bottom left over the lower bar, the skip line bottom right, the boss's name big at the right; sized from the screen
func _layout() -> void:
	if overlay == null: return
	var s := overlay.size; var bar := s.y * 0.11
	cap_title.add_theme_font_size_override("font_size", int(clampf(s.x * 0.05, 26, 46)))
	cap.position = Vector2(24, 0); cap.size = Vector2(s.x * 0.82, 0); cap.reset_size(); cap.size.x = s.x * 0.82; cap.position.y = s.y - bar - 22 - cap.size.y
	skip_lbl.reset_size(); skip_lbl.position = Vector2(s.x - 16 - skip_lbl.size.x, s.y - s.y * 0.032 - skip_lbl.size.y)
	card.add_theme_font_size_override("font_size", int(clampf(s.x * 0.074, 40, 104)))
	card.size = Vector2(s.x * 0.88, 0); card.reset_size(); card.size.x = s.x * 0.88; card.position = Vector2(s.x - 28 - card.size.x + 46.0 * (1.0 - clampf(card_t / 0.35, 0, 1)), s.y - bar - 20 - card.size.y)

func _show(title: String, sub: String) -> void:
	cap_t = 0.0
	if overlay == null: return
	overlay.visible = true; cap_title.text = title; cap_sub.text = sub; cap_title.visible = title != ""; cap_sub.visible = sub != ""
	skip_lbl.text = "화면을 누르면 건너뜁니다" if touch else "클릭 · Space 키로 건너뛰기"; card.visible = false

func _sub(text: String) -> void:
	if cap_sub != null: cap_sub.text = text; cap_sub.visible = text != ""

## black at once, then it clears (or the other way); the browser game's fade takes 0.7 s
func set_fade(now: float, to: float) -> void:
	fade_to = to
	if fade != null: fade.color.a = now

# ---------------- the helicopter ----------------
func _hover_height(x: float, z: float) -> float:
	# thin things (lamp posts, crane legs) do not count; the rotor clears container stacks, rocks and trees
	var top := 0.0
	for b in Phys.query_near(x - 9, z - 9, x + 9, z + 9):
		if b.maxy < 30.0 and (b.maxx - b.minx) * (b.maxz - b.minz) > 3.0: top = maxf(top, b.maxy)
	return maxf(7.0, top + 4.5)

func _place(px: float, py: float, pz: float, yaw: float, pitch := 0.0, roll := 0.0) -> void:
	heli.position = Vector3(px, py, pz); heli.rotation = Vector3(pitch, yaw, roll)

func _door_world(down := 0.0, reach := 1.05) -> Vector3:   # the open door is on the right side (local -x), just behind the cockpit
	var s := sin(heli.rotation.y); var c := cos(heli.rotation.y)
	return Vector3(heli.position.x - c * reach, heli.position.y + 1.6 - down, heli.position.z + s * reach)

func _approach(t: float, t0: float, t1: float) -> float:
	# in nose-down, a flare, and it settles into the hover between t0 and t1
	var k := ease_(clampf((t - t0) / (t1 - t0), 0, 1)); var lift := 3.5 if world.style.get("indoor", false) else 28.0
	_place(lerpf(C.sx, C.hx, k), lerpf(C.hy + lift, C.hy, k) + sin(clock * 2.1) * 0.15, lerpf(C.sz, C.hz, k), C.yaw, lerpf(0.18, -0.06, k) + ((1.0 - k) * 0.4 if k > 0.85 else 0.0), sin(clock * 1.3) * 0.02)
	return k

func _depart(t: float, t0: float) -> void:
	var k := clampf((t - t0) / 3.0, 0, 1); var kk := k * k; var indoor: bool = world.style.get("indoor", false)
	_place(C.hx + C.fx * kk * 70.0, C.hy + kk * (2.0 if indoor else 26.0) + k * (0.5 if indoor else 3.0), C.hz + C.fz * kk * 70.0, C.yaw, 0.22 * minf(1.0, k * 3.0), 0.0)

func _title(stage: int) -> String: return "스테이지 %s · %s" % [Store.STAGE_TAG[stage], Game.STAGES[stage].name]

func start_intro(stage: int, on_done: Callable) -> void:
	if world.lab != null: _start_lab_intro(stage, on_done); return
	if world.ship != null: _start_ship_intro(stage, on_done); return
	var st: Dictionary = world.start; var hy := _hover_height(st.x, st.z); var yaw: float = st.yaw + PI   # the helicopter faces the way you will face
	var fxv := -sin(float(st.yaw)); var fzv := -cos(float(st.yaw))
	var rx := -cos(yaw); var rz := sin(yaw); var hx: float = st.x - rx * 1.05; var hz: float = st.z - rz * 1.05   # hover so that the door hangs over the start
	C = {"kind": "in", "t": 0.0, "dur": 7.2, "done": on_done, "hx": hx, "hy": hy, "hz": hz, "yaw": yaw, "fx": fxv, "fz": fzv, "sx": hx - fxv * 95.0, "sz": hz - fzv * 95.0, "landed": false}
	heli.visible = true; rope.visible = false; fig.visible = false; beam.visible = not world.style.get("day", false); pool.visible = beam.visible
	_show(_title(stage), Game.STAGES[stage].intro); set_fade(1.0, 0.0)

func start_outro(on_done: Callable) -> void:
	if world.lab != null: _start_lab_outro(on_done); return
	if world.ship != null: _start_ship_outro(on_done); return
	var p := player.pos; var hy := _hover_height(p.x, p.z); var yaw := player.yaw + PI
	var rx := -cos(yaw); var rz := sin(yaw); var hx := p.x - rx * 1.05; var hz := p.z - rz * 1.05
	var fxv := -sin(player.yaw); var fzv := -cos(player.yaw)
	if world.style.get("indoor", false): var dx := -p.x; var dz := 75.0 - p.z; var dl := maxf(0.001, Vector2(dx, dz).length()); fxv = dx / dl; fzv = dz / dl
	# a camera behind you, a little to the side, looking up at the pick-up; kept out of containers and rocks
	var c0 := Vector3(p.x - fxv * 15.0 + fzv * 6.0, p.y + 4.0 + hy * 0.35, p.z - fzv * 15.0 - fxv * 6.0); var up := Vector3(p.x, p.y + 4.0 + hy * 0.35, p.z)
	for k in 10:
		if Phys.collide_at(c0.x, c0.y - 1.5, c0.z, 0.4, 2.0) != null or not Phys.line_of_sight(c0, Vector3(p.x, p.y + 1.2, p.z)): c0 = c0.lerp(up, 0.25)
		else: break
	C = {"kind": "out", "t": 0.0, "dur": 8.6, "done": on_done, "hx": hx, "hy": hy, "hz": hz, "yaw": yaw, "fx": fxv, "fz": fzv, "sx": hx - fxv * 95.0, "sz": hz - fzv * 95.0,
		"px": p.x, "py": p.y, "pz": p.z, "cam": c0, "faded": false}
	heli.visible = true; fig.visible = true; fig.position = p; fig.rotation = Vector3(0, player.yaw + PI, 0); arm_l.rotation = Vector3.ZERO; arm_r.rotation = Vector3.ZERO
	beam.visible = not world.style.get("day", false); pool.visible = beam.visible
	_show("탈출", "스테이지 %s 클리어 · 헬기가 데리러 왔습니다" % Store.STAGE_TAG[game.stage])

# ---------------- the lab ----------------
func _start_lab_intro(stage: int, on_done: Callable) -> void:
	C = {"kind": "lab", "t": 0.0, "dur": 10.6, "done": on_done, "beat": 0}
	heli.visible = false; rope.visible = false; fig.visible = false; pool.visible = false
	_show(_title(stage), Game.STAGES[stage].intro); set_fade(1.0, 0.0)

func _lab_intro(dt: float, t: float) -> void:
	var L: Lab = world.lab; var st: Dictionary = world.start; var H := Lab.HALF; var W: Dictionary = Lab.WIN; var desk := Vector3(0, W.y0 + 1.5, -H - 3.0)
	if t < 2.6:
		var k := ease_(t / 2.6)
		_look_from(Vector3(lerpf(-46.5, -18, k), lerpf(12.5, 10.5, k), lerpf(49.5, 45, k)), Vector3(lerpf(-9, 6, k), 2, -15))
	elif t < 6.4:
		if C.beat == 0: C.beat = 1; L.monkey_press(1.5); Snd.play("cackle", 1.0, desk); _sub("미친 원숭이 박사가 버튼을 누릅니다")
		# right up to his window in the north wall, looking in at him and his console
		var k := ease_((t - 2.6) / 3.8)
		_look_from(Vector3(lerpf(-1.7, -0.9, k), lerpf(W.y0 + 2.6, W.y0 + 2.2, k), lerpf(-H + 4.6, -H + 2.0, k)), Vector3(0.25, W.y0 + 1.3, -H - 3.2))
		if C.beat == 1 and t > 4.1: C.beat = 2; L.press(); Snd.play("press"); Snd.play("siren"); Snd.buzz(80)
		if C.beat == 2 and t > 4.6:
			C.beat = 3; Snd.play("cackle", 1.0, desk)
			_sub("첫 우리가 5초 뒤 열립니다 · 다음 우리는 앞 우리의 동물을 다 잡아야 원숭이 박사가 엽니다" if L.seq else "우리 10개에 카운트다운이 시작됐습니다 · 10초 뒤 첫 우리가 열립니다")
	elif t < 8.9:
		# along the west cages: their boards now count down
		if C.beat == 3: C.beat = 4; Snd.play("alarm"); L.monkey_mode = "cackle"; L.monkey_t = 0.0
		var k := ease_((t - 6.4) / 2.5)
		_look_from(Vector3(-19.5, lerpf(8, 6, k), lerpf(-21, 18, k)), Vector3(-37.5, 4.2, lerpf(-30, 24, k)))
		if randf() < dt * 1.5 and not enemies.list.is_empty():
			var a: Enemies.Foe = enemies.list[randi() % enemies.list.size()]
			if a.animal: Snd.play("roar_" + str(a.T.get("roar", "grunt")), 1.0, a.pos)
	else:
		var k := ease_(clampf((t - 8.9) / 1.5, 0, 1))
		_look_from(Vector3(st.x, lerpf(6, Player.EYE, k), lerpf(st.z - 8, st.z, k)), Vector3(st.x, lerpf(2, Player.EYE, k), st.z - 30))
		if t >= C.dur: finish()

func _start_lab_outro(on_done: Callable) -> void:
	var H := Lab.HALF
	C = {"kind": "labout", "t": 0.0, "dur": 7.4, "done": on_done, "cam": Vector3(5.5, 2.6, H - 9.5), "rumble": false, "faded": false}
	world.lab.alarm = false; heli.visible = false; fig.visible = true; fig.position = Vector3(0, 0, H - 10.5); fig.rotation = Vector3.ZERO
	_show("탈출", "스테이지 %s 클리어 · 비상 출입문이 열립니다" % Store.STAGE_TAG[game.stage]); Snd.play("siren")

func _lab_outro(_dt: float, t: float) -> void:
	var L: Lab = world.lab; var H := Lab.HALF
	L.door_open = ease_(clampf((t - 0.4) / 2.4, 0, 1))
	if t > 0.4 and not C.rumble: C.rumble = true; Snd.play("quake", 1.0, Vector3(0, 3, H - 1))
	var k := clampf((t - 1.8) / 4.6, 0, 1); var walk := t > 1.8 and k < 1.0
	fig.position = Vector3(0, absf(sin(t * 8.0)) * 0.05 if walk else 0.0, lerpf(H - 10.5, H + 5.0, k)); fig.rotation = Vector3.ZERO
	arm_l.rotation.x = sin(t * 8.0) * 0.5 if walk else 0.0; arm_r.rotation.x = -sin(t * 8.0) * 0.5 if walk else 0.0
	_look_from(C.cam, Vector3(0, 2.2, lerpf(H - 6.0, H + 2.0, ease_(clampf(t / 6.0, 0, 1)))))
	if t > C.dur - 1.1 and not C.faded: C.faded = true; fade_to = 1.0
	if t >= C.dur: finish()

# ---------------- the ship ----------------
func _start_ship_intro(stage: int, on_done: Callable) -> void:
	C = {"kind": "ship", "t": 0.0, "dur": 6.4, "done": on_done, "beat": 0}
	heli.visible = false; rope.visible = false; fig.visible = false; pool.visible = false
	world.ship.door_open = 0.0; world.ship.closing = false
	_show(_title(stage), "도킹 완료 · 에어록 압력을 맞추는 중"); set_fade(1.0, 0.0)

func _ship_intro(_dt: float, t: float) -> void:
	var st: Dictionary = world.start; var S: Ship = world.ship; var dz := Ship.DOOR_Z
	if t < 2.2:
		_look_from(Vector3(st.x + 1.1, 1.72 + sin(t * 1.3) * 0.02, 28.7), Vector3(st.x, 2.1, dz))
		if C.beat == 0 and t > 0.9: C.beat = 1; Snd.play("press"); _sub(Game.STAGES[game.stage].intro)
	elif t < 3.7:
		if C.beat == 1: C.beat = 2; Snd.play("clank", 1.0, Vector3(st.x, 2, dz)); Snd.play("swoosh", 1.0, Vector3(st.x, 2, dz))
		S.door_open = ease_((t - 2.2) / 1.5)
		_look_from(Vector3(st.x + 1.1 - (t - 2.2) * 0.4, 1.72, 28.7 - (t - 2.2) * 0.3), Vector3(st.x, 2.1 + S.door_open, dz - 4.0))
	else:
		var k := ease_(clampf((t - 3.7) / 2.4, 0, 1))
		_look_from(Vector3(lerpf(st.x + 0.5, st.x, k), lerpf(1.72, Player.EYE, k), lerpf(28.2, st.z, k)), Vector3(st.x, lerpf(2.1, Player.EYE, k), st.z - 20.0))
		if t >= C.dur: finish()

func _start_ship_outro(on_done: Callable) -> void:
	var st: Dictionary = world.start
	C = {"kind": "shipout", "t": 0.0, "dur": 7.0, "done": on_done, "cam": Vector3(st.x + 1.5, 2.6, 15.2), "hiss": false, "faded": false}
	heli.visible = false; fig.visible = true; fig.position = Vector3(st.x, 0, 18.5); fig.rotation = Vector3.ZERO
	_show("탈출", "스테이지 %s 클리어 · 에어록으로 빠져나갑니다" % Store.STAGE_TAG[game.stage]); Snd.play("press")

func _ship_outro(_dt: float, t: float) -> void:
	var st: Dictionary = world.start; var S: Ship = world.ship
	S.door_open = ease_(clampf((t - 0.3) / 1.6, 0, 1)) if t < 5.2 else ease_(clampf(1.0 - (t - 5.2) / 1.2, 0, 1))
	if t > 0.3 and not C.hiss: C.hiss = true; Snd.play("swoosh", 1.0, Vector3(st.x, 2, Ship.DOOR_Z))
	var k := clampf((t - 1.2) / 3.8, 0, 1); var walk := t > 1.2 and k < 1.0
	fig.position = Vector3(st.x, absf(sin(t * 8.0)) * 0.05 if walk else 0.0, lerpf(18.5, 28.0, k)); fig.rotation = Vector3.ZERO
	arm_l.rotation.x = sin(t * 8.0) * 0.5 if walk else 0.0; arm_r.rotation.x = -sin(t * 8.0) * 0.5 if walk else 0.0
	if k >= 1.0: fig.visible = false
	_look_from(C.cam, Vector3(st.x, 1.8, lerpf(21, 26, ease_(clampf(t / 6.0, 0, 1)))))
	if t > C.dur - 1.1 and not C.faded: C.faded = true; fade_to = 1.0
	if t >= C.dur: finish()

## a second and a half just inside a sealed door: the drone hangs in the middle doing what it does, turns to look at you at the end,
## and its name stands big in the bottom right (yellow for the bee, green for the boss); the camera drifts a little way in
func start_boss_intro(D: Dictionary, e: Enemies.Foe, on_done: Callable) -> void:
	var cz: float = (D.z0 + D.z1) / 2.0; var cam0 := Vector3(D.x + D.inward * 2.0, 2.6, cz); var at := e.pos
	C = {"kind": "boss", "t": 0.0, "dur": 1.5, "done": on_done, "D": D, "e": e, "cam0": cam0, "cam1": cam0.lerp(at, minf(0.4, 9.0 / maxf(1.0, cam0.distance_to(at)))), "base": at, "yaw0": e.yaw,
		"bar": e.bar.visible}   # (its health bar is out of the picture while it is shown, and back as it was after, watched or skipped)
	heli.visible = false; rope.visible = false; fig.visible = false; pool.visible = false
	e.g.visible = true; e.bar.visible = false
	if e.is_far: enemies.set_far(e, false)   # (it may still be drawn baked as far away)
	_show("", "")
	if card != null:
		card.text = str(D.title); card.add_theme_color_override("font_color", Color("ffd23a") if D.tone == "bee" else Color("36ff7a")); card.visible = true
	card_t = 0.0; Snd.play("alarm")

func _boss_intro(dt: float, t: float) -> void:
	var e: Enemies.Foe = C.e; var k := ease_(clampf(t / C.dur, 0, 1)); var b: Vector3 = C.base
	e.pos = Vector3(b.x + sin(t * 2.2) * 0.5, b.y + sin(t * 3.4) * 0.3, b.z + cos(t * 1.7) * 0.4)
	var face := atan2(cam.global_position.x - e.pos.x, cam.global_position.z - e.pos.z); var dy: float = face - C.yaw0; dy = atan2(sin(dy), cos(dy))
	e.yaw = C.yaw0 + dy * ease_(clampf((t - 0.5) / 0.8, 0, 1)); e.g.position = e.pos; e.g.rotation.y = e.yaw
	if e.k.has("shells"): e.g.rotation.z = sin(t * 2.0) * 0.05
	if e.type == "gdrone":   # the bee beating its wings, its eyes glowing brighter as it turns to you
		e.g.rotation.z = sin(t * 2.6) * 0.06; e.k.spin = float(e.k.get("spin", 0.0)) + dt; var wf := sin(float(e.k.spin) * 48.0)
		for W in e.k.get("wings", []): (W.g as Node3D).rotation.z = W.sx * (0.18 + wf * 0.42)
		if e.k.has("bee_eye"): (e.k.bee_eye as ShaderMaterial).set_shader_parameter("emis", Vector3(0.25 + 0.9 * k, 0.05 + 0.15 * k, 0.0))
	var cp: Vector3 = (C.cam0 as Vector3).lerp(C.cam1, k); cp.y += sin(t * 9.0) * 0.01
	_look_from(cp, e.pos)
	if t >= C.dur: finish()

func _look_from(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	if from.distance_to(to) > 0.001: cam.look_at(to, Vector3.UP)

# ---------------- every frame, and the end ----------------
func update(dt: float) -> void:
	if C.is_empty(): return
	clock += dt; C.t = float(C.t) + dt; var t: float = C.t
	_overlay(dt)
	match str(C.kind):
		"boss": _boss_intro(dt, t); return
		"lab": _lab_intro(dt, t); if not C.is_empty(): enemies.update(dt, clock)
		"labout": _lab_outro(dt, t)
		"ship": _ship_intro(dt, t)
		"shipout": _ship_outro(dt, t)
		"in": _heli_in(dt, t)
		"out": _heli_out(dt, t)
	if not C.is_empty() and (C.kind == "in" or C.kind == "out"): _wash(dt)

func _heli_in(dt: float, t: float) -> void:
	rotor.rotation.y += dt * 26.0; tail.rotation.x += dt * 40.0
	var st: Dictionary = world.start
	if t < 3.6:
		_approach(t, 0, 3.4)
		# sitting in the open door with your legs out: the ground slides by below
		var p := _door_world(0.15, 1.4); p.y += sin(clock * 9.0) * 0.02
		var s := sin(heli.rotation.y); var c := cos(heli.rotation.y)
		_look_from(p, Vector3(p.x - c * 9.0 + C.fx * 14.0, 0, p.z + s * 9.0 + C.fz * 14.0))
	elif t < 5.4:
		_approach(4, 0, 3.4)
		# down the rope beside the helicopter
		var k := ease_((t - 3.6) / 1.8); var d := _door_world(0.1)
		rope.visible = true; rope.position = d; rope.scale = Vector3(1, maxf(0.01, d.y), 1)
		_look_from(Vector3(lerpf(d.x, st.x, k), lerpf(d.y, Player.EYE, k), lerpf(d.z, st.z, k)), Vector3(st.x + C.fx * 10.0, lerpf(0, Player.EYE, k), st.z + C.fz * 10.0))
		if k > 0.98 and not C.landed: C.landed = true; Snd.play("land")
	else:
		rope.visible = false; _depart(t, 5.4)
		# on the ground: watch it pull away, then settle into the playing view
		var k := ease_(clampf((t - 6.2) / 1.0, 0, 1))
		_look_from(Vector3(st.x, Player.EYE, st.z), heli.position.lerp(Vector3(st.x + C.fx * 20.0, Player.EYE, st.z + C.fz * 20.0), k))
		if t >= C.dur: finish()

func _heli_out(dt: float, t: float) -> void:
	rotor.rotation.y += dt * 26.0; tail.rotation.x += dt * 40.0
	if t < 3.6: _approach(t, 0, 3.4)
	elif t < 6.2:
		_approach(4, 0, 3.4)
		# the rope ladder drops and you climb up into the door
		var d := _door_world(0.0); rope.visible = true; rope.position = d; rope.scale = Vector3(1, maxf(0.1, d.y - C.py), 1)
		var k := ease_(clampf((t - 3.9) / 2.1, 0, 1))
		fig.position = Vector3(lerpf(C.px, d.x, k), lerpf(C.py, d.y - 1.7, k), lerpf(C.pz, d.z, k))
		var climb := sin(t * 9.0) * (1.0 if (k > 0.0 and k < 1.0) else 0.0)
		arm_l.rotation.x = -2.6 + climb * 0.5; arm_r.rotation.x = -2.6 - climb * 0.5
		if k >= 1.0: fig.visible = false
	else:
		rope.visible = false; fig.visible = false; _depart(t, 6.2)
		if t > C.dur - 1.1 and not C.faded: C.faded = true; fade_to = 1.0
		if t >= C.dur: finish(); return
	# frame you and the hovering helicopter together; follow it once you are aboard
	var want: Vector3 = (fig.position + Vector3(0, 1, 0)).lerp(heli.position, 0.38) if fig.visible else heli.position
	C.look = want if not C.has("look") else (C.look as Vector3).lerp(want, 1.0 - exp(-dt * 4.0))
	_look_from(C.cam, C.look)

## the downwash kicking up dust, the searchlight's pool on the ground, the rotor louder the nearer it is
func _wash(_dt: float) -> void:
	var agl := heli.position.y - Phys.ground_at(heli.position.x, 50.0, heli.position.z, 1.0)
	if agl < 16.0 and randf() < 0.8 and fx != null:
		var a := randf() * TAU; var rr := randf_range(2.0, 7.0)
		fx.puff(Vector3(heli.position.x + cos(a) * rr, 0.3, heli.position.z + sin(a) * rr), 1, 0.6 if world.style.get("day", false) else 0.4, 1.2)
	if pool.visible: pool.position = Vector3(heli.position.x + C.fx * 3.0, 0.04, heli.position.z + C.fz * 3.0); Gfx.set_alpha(pool_mat, clampf(1.0 - agl / 40.0, 0, 1))
	Snd.loop("rotor", clampf(1.0 - heli.position.distance_to(cam.global_position) / 140.0, 0.05, 1.0))   # (the rotor's own 0.55 is in its take)

func _overlay(dt: float) -> void:
	cap_t += dt; card_t += dt
	if overlay == null: return
	cap.modulate.a = clampf(cap_t / 0.9, 0, 1); card.modulate.a = clampf(card_t / 0.35, 0, 1)
	_layout()

## every frame, cutscene or not: the fade eases toward where it is going (0.7 s from one end to the other)
func tick_fade(dt: float) -> void:
	if fade == null: return
	fade.color.a = move_toward(fade.color.a, fade_to, dt / 0.7)

## leaving for the menu in the middle of one: everything put away, nothing more happens
func abort() -> void:
	C = {}; heli.visible = false; rope.visible = false; fig.visible = false; pool.visible = false
	if overlay != null: overlay.visible = false; card.visible = false
	Snd.loop("rotor", 0.0); set_fade(0.0, 0.0)

func skip() -> void:
	if not C.is_empty(): finish()

func finish() -> void:
	var done: Callable = C.get("done", Callable()); var k := kind()
	if k == "boss":
		var be: Enemies.Foe = C.e
		if be != null and is_instance_valid(be.bar): be.bar.visible = bool(C.get("bar", false)) and be.alive
	C = {}; heli.visible = false; rope.visible = false; fig.visible = false; pool.visible = false
	if overlay != null: overlay.visible = false; card.visible = false
	Snd.loop("rotor", 0.0)
	if k == "in" or k == "lab" or k == "ship": fade_to = 0.0
	if k == "ship": world.ship.door_open = maxf(world.ship.door_open, 1.0); world.ship.closing = true   # the airlock shuts behind you
	if k == "lab":
		if not world.lab.pressed: world.lab.press(); Snd.play("siren")
		world.lab.monkey_mode = "idle"
	if done.is_valid(): done.call()
