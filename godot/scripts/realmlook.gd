class_name RealmLook
extends RefCounted
## What is seen of a realm battle: the nine others' bodies (each people's shape, your side's in blue and theirs in red),
## what flies, what lies about, the made things, your own weapon in your hands, and the moments that give a blow its
## weight (each element's own mark where it strikes, each people's own way of going when it falls).

const TEAM_COL := {"us": "4f86e0", "them": "d8454f"}
const ELEM_COL := {"arcane": Color(0.62, 0.5, 1.0), "fire": Color(1.0, 0.5, 0.15), "physical": Color(0.85, 0.9, 1.0), "alchemy": Color(0.3, 0.95, 0.8)}
const MODEL_H := 1.86      # the height the bodies are drawn at before each people's own scale
const HIP := 0.92

var rm: Realm
var root: Node3D = null
var view: Node3D = null    # your weapon
var models := {}           # race -> its node in your hands
var dagger: Node3D = null
var kick := 0.0; var swing_t := 0.0; var swing_len := 0.0; var swing_kind := ""; var swing_i := 0
var hip := 1.0               # (a narrow screen: the weapon comes in from the side less far; Main sets it)
const VIEW_SCALE := {"elf": 1.0, "dwarf": 0.66, "orc": 0.75, "demon": 0.8}
const TIP := {"elf": Vector3(0, 0.03, -0.38), "dwarf": Vector3(0, 0, -0.46), "orc": Vector3(0, 0, -1.1), "demon": Vector3(0, 0, -0.72)}   # the weapon's mouth in its own frame
var shield_nodes: Array = []
var _mats := {}
var _meshes := {}
var _blue_bar: Material = null; var _white_bar: Material = null
var _ghosts: Array = []    # what is left a moment where someone fell: {n, t}

func _root() -> Node3D:
	if root == null or not is_instance_valid(root):
		root = Node3D.new(); root.name = "Realm"
		if rm.en != null: rm.en.add_child(root)
	return root

func clear() -> void:
	if root != null and is_instance_valid(root): root.queue_free()
	root = null
	if view != null and is_instance_valid(view): view.queue_free()
	view = null; models.clear(); shield_nodes.clear(); _ghosts.clear()

func _unlit(key: String, col: Color, add := false) -> Material:
	if not _mats.has(key):
		var m := Gfx.unlit(col, false); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mats[key] = Gfx.see_through(m)
	return _mats[key]

func _box(key: String, size: Vector3) -> Mesh:
	if not _meshes.has(key): var b := BoxMesh.new(); b.size = size; _meshes[key] = b
	return _meshes[key]

func _mi(mesh: Mesh, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _root()).add_child(m)
	return m

# ---------------- the bodies ----------------
static func parts(race: String, team: String) -> Dictionary:
	var tc: String = TEAM_COL[team]; var skin := "e6c8a8"; var coat := "3f6b55"; var legc := "3b3226"; var boot := "241c14"; var trim := "6b4a2c"
	match race:
		"dwarf": skin = "d9a98a"; coat = "6b5a4a"; legc = "4a3a2c"; trim = "c08a3a"
		"orc": skin = "6f9a4a"; coat = "4a3a30"; legc = "3a2c24"; trim = "8a8f98"
		"demon": skin = "a8382e"; coat = "2a1c22"; legc = "22161c"; trim = "d0a040"
	var leg := [[0.15, 0.9, 0.17, 0, -0.45, 0, legc], [0.16, 0.1, 0.27, 0, -0.87, 0.05, boot]]
	if race == "demon": leg = [[0.19, 0.9, 0.26, 0, -0.45, 0, coat], [0.2, 0.06, 0.28, 0, -0.9, 0, trim]]
	var up := [[0.42, 0.62, 0.25, 0, 0.36, 0, coat], [0.44, 0.07, 0.27, 0, 0.1, 0, trim], [0.22, 0.25, 0.23, 0, 0.8, 0.01, skin],
		[0.46, 0.13, 0.28, 0, 0.52, 0, tc], [0.4, 0.5, 0.04, 0, 0.32, -0.15, tc]]   # (the band across the chest and the cloak: his side's colour)
	var arm := [[0.12, 0.62, 0.13, 0, -0.29, 0, coat], [0.1, 0.1, 0.11, 0, -0.62, 0, skin]]
	var right := arm.duplicate(); var left := arm.duplicate()
	match race:
		"elf":
			up.append_array([[0.24, 0.1, 0.25, 0, 0.93, -0.01, "e9e2c0"], [0.24, 0.4, 0.06, 0, 0.7, -0.13, "e9e2c0"], [0.035, 0.2, 0.07, -0.125, 0.88, -0.03, skin, [0.55, 0, 0.42]], [0.035, 0.2, 0.07, 0.125, 0.88, -0.03, skin, [0.55, 0, -0.42]]])
			right.append_array([[0.07, 0.6, 0.08, 0, -0.72, 0.06, "5a3d22"], [0.6, 0.05, 0.05, 0, -0.98, 0.06, "c9d3dc"], [0.1, 0.1, 0.1, 0, -0.6, 0.13, "8ff7ea"]])
		"dwarf":
			up.append_array([[0.27, 0.13, 0.28, 0, 0.93, 0, "8a8f98"], [0.05, 0.12, 0.05, 0, 1.03, 0, "c08a3a"], [0.2, 0.32, 0.1, 0, 0.6, 0.13, "c46a2a"], [0.32, 0.42, 0.16, 0, 0.4, -0.22, "b07a2e"], [0.1, 0.36, 0.1, -0.1, 0.42, -0.33, "d6a43a"], [0.1, 0.36, 0.1, 0.1, 0.42, -0.33, "d6a43a"]])
			right.append_array([[0.17, 0.62, 0.17, 0, -0.8, 0.05, "b07a2e"], [0.26, 0.12, 0.26, 0, -1.14, 0.05, "d6a43a"], [0.12, 0.3, 0.12, 0, -0.55, -0.1, "6a7280"]])
		"orc":
			up.append_array([[0.04, 0.09, 0.04, -0.07, 0.72, 0.13, "f0ead8"], [0.04, 0.09, 0.04, 0.07, 0.72, 0.13, "f0ead8"], [0.22, 0.13, 0.32, -0.31, 0.66, 0, "8a8f98"], [0.22, 0.13, 0.32, 0.31, 0.66, 0, "8a8f98"], [0.1, 0.16, 0.1, 0, 0.98, -0.04, "241c14"]])
			right.append_array([[0.13, 0.05, 1.6, 0, -0.62, 0.92, "c9d3dc"], [0.06, 0.03, 1.5, 0, -0.62, 0.92, "b03030"], [0.42, 0.07, 0.07, 0, -0.62, 0.12, "6b4a2c"]])
			arm[0][6] = skin; left[0] = [0.12, 0.62, 0.13, 0, -0.29, 0, skin]; right[0] = [0.12, 0.62, 0.13, 0, -0.29, 0, skin]
		"demon":
			up.append_array([[0.05, 0.22, 0.05, -0.09, 1.0, 0, "1a1216", [0, 0, 0.3]], [0.05, 0.22, 0.05, 0.09, 1.0, 0, "1a1216", [0, 0, -0.3]], [0.1, 0.5, 0.26, 0, 0.36, 0.01, trim]])
			right.append_array([[0.05, 0.05, 1.7, 0, -0.6, 0.32, "2a1c22"], [0.17, 0.17, 0.17, 0, -0.6, 1.2, "ff7a2a"], [0.26, 0.04, 0.26, 0, -0.6, 1.08, trim]])
	return {"leg": leg, "up": up, "left": left, "right": right}

func build(f: Realm.Fighter) -> void:
	var en := rm.en
	if en == null: return
	if f.body.has("g") and is_instance_valid(f.body.g): (f.body.g as Node).queue_free()
	if f.body.has("bar") and is_instance_valid(f.body.bar): (f.body.bar as Node).queue_free()
	var P := parts(f.race, f.team); var key := "rm_%s_%s_" % [f.race, f.team]
	var g := Node3D.new(); g.rotation_order = EULER_ORDER_YXZ; _root().add_child(g)
	var wide := f.R / 0.36
	g.scale = Vector3(wide, f.H / MODEL_H, wide)
	var b := {"g": g, "ph": randf() * TAU}
	b.leg_l = en._part(g, Vector3(-0.11, HIP, 0), key + "leg", P.leg); b.leg_r = en._part(g, Vector3(0.11, HIP, 0), key + "leg", P.leg)
	b.upper = en._part(g, Vector3(0, HIP, 0), key + "up", P.up)
	b.arm_l = en._part(b.upper, Vector3(-0.28, 0.6, 0), key + "al", P.left); b.arm_r = en._part(b.upper, Vector3(0.28, 0.6, 0), key + "ar", P.right)
	var bar := Node3D.new(); bar.visible = false; _root().add_child(bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.84, 0.08, 1); bar.add_child(bg)
	if _blue_bar == null:
		_blue_bar = (en._bar_fill as StandardMaterial3D).duplicate(); (_blue_bar as StandardMaterial3D).albedo_color = Color("5f9cff")
		_white_bar = (en._bar_fill as StandardMaterial3D).duplicate(); (_white_bar as StandardMaterial3D).albedo_color = Color("e8f4ff")
	var fill := MeshInstance3D.new(); fill.mesh = en._bar_mesh; fill.material_override = _blue_bar if f.team == "us" else en._bar_fill; fill.scale = Vector3(0.8, 0.05, 1); bar.add_child(fill)
	var sh := MeshInstance3D.new(); sh.mesh = en._bar_mesh; sh.material_override = _white_bar; sh.scale = Vector3(0.0, 0.03, 1); sh.position = Vector3(0, 0.07, 0); bar.add_child(sh)
	b.bar = bar; b.fill = fill; b.sh = sh
	f.body = b

func _place(f: Realm.Fighter, dt: float) -> void:
	var b := f.body
	if b.is_empty() or not is_instance_valid(b.g): return
	var g: Node3D = b.g
	g.visible = f.alive and not (f.inv > 0.0 and f.dash_kind == "rift")
	if not f.alive: (b.bar as Node3D).visible = false; return
	g.position = f.pos; g.rotation.y = atan2(f.aim.x, f.aim.z)
	var sp := Vector2(f.vel.x, f.vel.z).length(); var amt := clampf(sp / 5.0, 0.0, 1.0)
	b.ph = float(b.ph) + sp * dt * 1.9
	var sw := sin(float(b.ph)) * 0.7 * amt
	(b.leg_l as Node3D).rotation.x = sw; (b.leg_r as Node3D).rotation.x = -sw
	var pitch := asin(clampf(f.aim.y, -1.0, 1.0))
	(b.upper as Node3D).rotation.x = -pitch * 0.35
	var ar := -1.35 - pitch * 0.6; var al := -1.1 - pitch * 0.5
	match f.race:
		"elf":
			if f.charge > 0.0: ar += 0.15; al -= 0.25
			if f.reload_t > 0.0: ar = -0.7; al = -1.6
		"dwarf":
			if f.reload_t > 0.0: ar = -0.6; al = -0.9
		"orc":
			ar = -0.9; al = -0.3
			if f.swing_t > 0.0 and f.swing_len > 0.0:
				var u := 1.0 - f.swing_t / f.swing_len
				ar = lerpf(-2.9, -0.15, clampf(u / 0.45, 0.0, 1.0)) if u < 0.6 else lerpf(-0.15, -0.9, (u - 0.6) / 0.4)
				al = ar * 0.6
			if f.cast_t > 0.0: ar = -2.9; al = -2.9
		"demon":
			ar = -1.25 - pitch * 0.6; al = -1.5 if f.beam_on else -0.4
			if f.seal_t > 0.0: ar = -0.5
	if f.dag_t > float(Races.DAGGER.cd) - 0.22: al = -1.9
	if f.parry_t > 0.0: al = -2.1
	if f.stun_t > 0.05: ar = -0.3; al = -0.3
	(b.arm_r as Node3D).rotation.x = ar; (b.arm_l as Node3D).rotation.x = al
	if f.leaping: (b.leg_l as Node3D).rotation.x = -0.9; (b.leg_r as Node3D).rotation.x = 0.6
	# the bar over his head: when he is hurt, shielded or marked
	var bar: Node3D = b.bar
	bar.visible = f.hp < f.max_hp - 0.5 or f.shield > 0.5 or f.over > 0.5 or f.mark_t > 0.0 or f.carrying
	if bar.visible:
		bar.position = f.pos + Vector3(0, f.H + 0.32, 0)
		var q := clampf(f.hp / f.max_hp, 0.0, 1.0); (b.fill as Node3D).scale.x = 0.8 * q; (b.fill as Node3D).position.x = -0.4 * (1.0 - q)
		var s := clampf((f.shield + f.over) / 125.0, 0.0, 1.0); (b.sh as Node3D).scale.x = 0.8 * s; (b.sh as Node3D).position.x = -0.4 * (1.0 - s)

# ---------------- your own hands ----------------
func _view() -> void:
	if view != null and is_instance_valid(view): return
	var parent: Node = rm.world.hand_root if (rm.world != null and rm.world.hand_root != null) else rm.cam
	if parent == null or rm.en == null: return
	view = Node3D.new(); view.name = "RealmHands"; parent.add_child(view)
	var en := rm.en
	var held := {
		"elf": [[0.05, 0.05, 0.5, 0, 0, -0.1, "5a3d22"], [0.46, 0.035, 0.035, 0, 0.01, -0.33, "c9d3dc"], [0.07, 0.07, 0.07, 0, 0.04, -0.16, "8ff7ea"], [0.02, 0.02, 0.4, 0, 0.035, -0.12, "dcfff9"]],
		"dwarf": [[0.13, 0.13, 0.46, 0, 0, -0.14, "b07a2e"], [0.2, 0.2, 0.1, 0, 0, -0.4, "d6a43a"], [0.09, 0.2, 0.09, 0, -0.1, 0.05, "6a7280"], [0.05, 0.05, 0.3, 0.09, 0.03, -0.1, "8a8f98"]],
		"orc": [[0.09, 0.035, 1.15, 0, 0, -0.62, "c9d3dc"], [0.04, 0.02, 1.05, 0, 0.012, -0.62, "b03030"], [0.34, 0.05, 0.05, 0, 0, -0.03, "6b4a2c"], [0.045, 0.045, 0.24, 0, 0, 0.1, "3a2c24"]],
		"demon": [[0.035, 0.035, 0.95, 0, 0, -0.2, "2a1c22"], [0.12, 0.12, 0.12, 0, 0, -0.7, "ff7a2a"], [0.19, 0.03, 0.19, 0, 0, -0.62, "d0a040"]],
	}
	for r: String in held:
		var n: Node3D = en._part(view, Vector3.ZERO, "rm_hand_" + r, held[r]); n.visible = false; models[r] = n
	dagger = en._part(view, Vector3.ZERO, "rm_hand_dagger", [[0.035, 0.012, 0.3, 0, 0, -0.17, "dfe8f0"], [0.1, 0.03, 0.03, 0, 0, -0.01, "8a6a2a"], [0.03, 0.03, 0.1, 0, 0, 0.05, "3a2c24"]]); dagger.visible = false

func _hands(dt: float) -> void:
	_view()
	if view == null: return
	var f := rm.me; var on: bool = f != null and f.alive and rm.player != null and not rm.player.out and not (rm.game != null and bool(rm.game.ended))
	for r: String in models: (models[r] as Node3D).visible = on and r == f.race
	kick = maxf(0.0, kick - dt * 6.0)
	if swing_t > 0.0 and rm.stop_t <= 0.0: swing_t = maxf(0.0, swing_t - dt)
	if not on: dagger.visible = false; return
	var n: Node3D = models[f.race]; var t := rm.clock
	var mv := clampf(rm.player.speed_xz / 5.0, 0.0, 1.3) * (1.0 if rm.player.grounded else 0.2)
	var bob := -absf(cos(rm.player.step_phase)) * 0.012 * mv
	var at := Vector3(0.21 * hip + sin(rm.player.step_phase) * 0.01 * mv, -0.2 + bob + rm.player.land_dip * 0.4, -0.5 + kick * 0.07); var rot := Vector3(kick * 0.12, 0.0, 0.0)
	match f.race:
		"elf":
			if f.charge > 0.0: var c := minf(1.0, f.charge / float(Races.XBOW.charge)); at += Vector3(-0.07 * c, 0.03 * c, 0.05 * c) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0015 * c
			if f.reload_t > 0.0: var u := 1.0 - f.reload_t / float(Races.XBOW.reload); at.y -= 0.12 * sin(u * PI); rot.z = 0.7 * sin(u * PI); rot.x += 0.3 * sin(u * PI)   # (tipped over while its core draws mana in)
		"dwarf":
			at += Vector3(0.05, -0.05, 0.0); rot.y = -0.06
			if f.reload_t > 0.0: var u := 1.0 - f.reload_t / float(Races.CANNON.reload); at.y -= 0.14 * sin(u * PI); rot.x += 0.5 * sin(u * PI)
		"orc":   # the great sword, held up before you; its three blows: across, back across, down from overhead
			at = Vector3(0.3, -0.36, -0.42); rot = Vector3(1.05, 0.25, -0.2)
			if f.swing_t > 0.0 and f.swing_len > 0.0:
				var u := clampf((1.0 - f.swing_t / f.swing_len) / 0.5, 0.0, 1.0); var dirn := -1.0 if f.combo == 1 else 1.0
				if f.combo == 2: rot = Vector3(lerpf(1.9, -0.5, u), 0.0, 0.0); at = Vector3(0.1, -0.26, -0.5)
				else: rot = Vector3(0.25, lerpf(-1.3, 1.3, u) * dirn, 0.9 * dirn); at = Vector3(lerpf(0.34, -0.2, u) * dirn, -0.26, -0.5)
			if f.cast_t > 0.0: rot = Vector3(1.7, 0, 0); at = Vector3(0.1, -0.2, -0.45)
		"demon":
			at += Vector3(0.08, -0.08, 0.04); rot.x += 0.16; rot.y = -0.1
			if f.seal_t > 0.0: at.y -= 0.1; rot.z = 0.5
			if f.beam_on: at += Vector3(-0.06, 0.03, 0.0)
	n.position = at; n.rotation = rot; n.scale = Vector3.ONE * float(VIEW_SCALE[f.race])
	# the dagger in the left hand: a cut, or held up to turn a missile
	var cut := f.dag_t > float(Races.DAGGER.cd) - 0.25
	dagger.visible = cut or f.parry_t > 0.0
	if cut: var u := (f.dag_t - (float(Races.DAGGER.cd) - 0.25)) / 0.25; dagger.position = Vector3(-0.22 + 0.4 * (1.0 - u), -0.2, -0.45); dagger.rotation = Vector3(0, 0.6, 1.2)
	elif f.parry_t > 0.0: dagger.position = Vector3(-0.1, -0.12, -0.4); dagger.rotation = Vector3(0, 1.3, 1.57)

## where your weapon's mouth is seen (what you fire is drawn coming out of it); anyone else's: where his shots start
func view_muzzle(f: Realm.Fighter) -> Vector3:
	if f.me and models.has(f.race) and is_instance_valid(models[f.race]) and (models[f.race] as Node3D).is_visible_in_tree():
		return (models[f.race] as Node3D).global_transform * (TIP[f.race] as Vector3)
	return rm.kit.muzzle(f) + f.aim * 0.6

# ---------------- what flies ----------------
func shot(s: Dictionary) -> Dictionary:
	var size := Vector3(0.04, 0.04, 0.8); var col := Color(0.56, 0.97, 0.92, 0.95); var key: String = s.kind
	match s.kind:
		"big": size = Vector3(0.07, 0.07, 1.3); col = Color(0.8, 0.62, 1.0, 1.0)
		"ember": size = Vector3(0.13, 0.13, 0.3); col = Color(1.0, 0.25, 0.08, 1.0) if s.get("hot", false) else Color(1.0, 0.6, 0.2, 0.95); key = "ember_hot" if s.get("hot", false) else "ember"
		"gren": size = Vector3(0.22, 0.22, 0.22); col = Color(0.3, 0.9, 0.75, 1.0)
		"flask": size = Vector3(0.18, 0.24, 0.18); col = {"oil": Color(0.2, 0.55, 0.5, 1.0), "gravity": Color(0.45, 0.2, 0.8, 1.0), "smoke": Color(0.7, 0.5, 1.0, 1.0)}[s.bomb]; key = "flask_" + str(s.bomb)
		"wave": size = Vector3(2.6, 0.1, 0.5); col = Color(1.0, 0.16, 0.12, 0.8)
		"axe": size = Vector3(0.5, 0.08, 0.4); col = Color(0.8, 0.84, 0.9, 1.0)
		"bolt": size = Vector3(0.09, 0.09, 0.5); col = Color(0.75, 0.9, 1.0, 1.0)
	if s.has("size"): size = s.size   # (6-A's demons' missiles: each its own size and colour)
	if s.has("col"): col = s.col
	if rm.en == null: return s
	var m := _mi(_box("shot_" + str(s.kind), size), _unlit("shot_" + key, col, s.kind != "axe" and s.kind != "flask" and s.kind != "gren"))
	m.position = s.pos; s.node = m; s.age = 0.0
	var by: Realm.Fighter = s.by
	if by != null and by.me and s.kind != "wave": s.vis = view_muzzle(by) - (s.pos as Vector3)   # (yours: drawn from your weapon's mouth, closing on the line you aim along)
	return s

func shot_gone(s: Dictionary) -> void:
	if s.has("node") and is_instance_valid(s.node): (s.node as Node).queue_free()
	s.erase("node")

func shot_turned(_s: Dictionary) -> void: pass

func _shots(_dt: float) -> void:
	for s: Dictionary in rm.kit.shots:
		if not s.has("node") or not is_instance_valid(s.node): continue
		var n: Node3D = s.node; var p: Vector3 = s.pos; var v: Vector3 = s.vel
		s.age = float(s.get("age", 0.0)) + _dt
		n.position = p + (s.vis as Vector3) * maxf(0.0, 1.0 - float(s.age) / 0.14) if s.has("vis") else p
		if v.length() > 0.1 and absf(v.normalized().y) < 0.99: n.look_at(p + v, Vector3.UP)
		if s.kind == "axe": n.rotate_object_local(Vector3.RIGHT, rm.clock * 18.0)
		if rm.fx != null and randf() < 0.5:
			match s.kind:
				"big": rm.fx.glow(p, Vector3.ZERO, 0.25, 0.12, 0.02, Color(0.7, 0.55, 1.0, 0.7))
				"ember": rm.fx.glow(p, Vector3(0, 0.4, 0), 0.18, 0.1, 0.02, Color(1.0, 0.45, 0.1, 0.7))
				"wave": rm.fx.glow(p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.8, Vector3.ZERO, 0.2, 0.25, 0.04, Color(1.0, 0.12, 0.1, 0.6))
				"gren", "flask": rm.fx.glow(p, Vector3.ZERO, 0.3, 0.08, 0.02, Color(0.4, 1.0, 0.85, 0.5))
				"fspear", "lance", "jav", "hfire", "fball": rm.fx.glow(p, Vector3(0, 0.5, 0), 0.3, 0.16 if s.kind == "hfire" or s.kind == "fball" else 0.1, 0.03, Color(1.0, 0.42, 0.1, 0.75))
				"fbolt": rm.fx.glow(p, Vector3.ZERO, 0.2, 0.08, 0.02, Color(0.7, 0.35, 1.0, 0.7))

# ---------------- what lies or hangs about ----------------
func _flat(r: float, key: String, col: Color, y := 0.04) -> MeshInstance3D:
	if not _meshes.has("disc"): var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.02; c.radial_segments = 28; c.rings = 1; _meshes["disc"] = c
	var m := _mi(_meshes["disc"], _unlit(key, col)); m.scale = Vector3(r, 1.0, r); m.position.y = y
	return m

func _ball(r: float, key: String, col: Color, half := false) -> MeshInstance3D:
	var k := "half" if half else "ball"
	if not _meshes.has(k): var s := SphereMesh.new(); s.radius = 1.0; s.height = 1.0 if half else 2.0; s.is_hemisphere = half; s.radial_segments = 20; s.rings = 8; _meshes[k] = s
	var m := _mi(_meshes[k], _unlit(key, col)); m.scale = Vector3.ONE * r
	return m

func field(fd: Dictionary) -> Dictionary:
	if rm.en == null: return fd
	var g := Node3D.new(); _root().add_child(g); g.position = fd.pos; fd.node = g
	_dress(fd)
	return fd

func _dress(fd: Dictionary) -> void:
	var g: Node3D = fd.node
	for c in g.get_children(): c.queue_free()
	var r := float(fd.r); var m: MeshInstance3D = null
	match fd.kind:
		"oil": m = _flat(r, "f_oil", Color(0.08, 0.3, 0.28, 0.72))
		"fire": m = _flat(r, "f_fire", Color(1.0, 0.42, 0.08, 0.6))
		"frost": m = _flat(r, "f_frost", Color(0.7, 0.92, 1.0, 0.55))
		"smoke": m = _ball(r, "f_smoke", Color(0.5, 0.32, 0.78, 0.62)); m.position.y = 1.2
		"gravity": m = _ball(1.0, "f_grav", Color(0.12, 0.04, 0.25, 0.9)); m.position.y = 1.0
		"dome": m = _ball(r, "f_dome", Color(0.72, 0.9, 1.0, 0.2), true)
		"star": m = _flat(r, "f_star", Color(0.7, 0.6, 1.0, 0.22))
		"furnace": m = _flat(r, "f_furnace", Color(0.45, 0.05, 0.02, 0.26))
		"trail": m = _flat(1.0, "f_trail", Color(1.0, 0.4, 0.1, 0.6))
	if m == null: return
	m.get_parent().remove_child(m); g.add_child(m)
	if fd.kind == "trail":
		var a: Vector3 = fd.a; var b: Vector3 = fd.b; var ab := b - a
		m.scale = Vector3(1.1, 1.0, ab.length() * 0.5 + 0.6); g.rotation.y = atan2(ab.x, ab.z); g.position = (a + b) * 0.5 + Vector3(0, 0.02, 0)

func field_changed(fd: Dictionary) -> void:
	if fd.has("node") and is_instance_valid(fd.node): _dress(fd)

func field_gone(fd: Dictionary) -> void:
	if fd.has("node") and is_instance_valid(fd.node): (fd.node as Node).queue_free()
	fd.erase("node")

func _fields(dt: float) -> void:
	var fx := rm.fx
	for fd: Dictionary in rm.kit.fields:
		if not fd.has("node") or not is_instance_valid(fd.node): continue
		var g: Node3D = fd.node; var c: Vector3 = fd.pos; var r := float(fd.r)
		if fd.kind != "trail": g.position = c
		if fx == null: continue
		var a := randf() * TAU; var q := sqrt(randf()) * r; var p := c + Vector3(cos(a) * q, 0.1, sin(a) * q)
		match fd.kind:
			"fire":
				for i in 2: fx.glow(c + Vector3(cos(a + i) * q, 0.1, sin(a + i) * q), Vector3(0, randf_range(1.5, 3.2), 0), 0.5, 0.5, 0.05, Color(1.0, randf_range(0.3, 0.6), 0.08, 0.8), 0.0, 0.5)
			"frost":
				if randf() < dt * 20.0: fx.glow(p, Vector3(0, 0.3, 0), 0.9, 0.3, 0.1, Color(0.8, 0.95, 1.0, 0.45))
			"smoke":
				if randf() < dt * 14.0: fx.glow(c + Vector3(cos(a) * q, randf_range(0.2, 2.6), sin(a) * q), Vector3(0, 0.25, 0), 1.2, 0.9, 1.4, Color(0.6, 0.4, 0.9, 0.3))
			"gravity":
				g.scale = Vector3.ONE * (0.8 + 0.2 * sin(rm.clock * 30.0))
				for i in 2:
					var o := Vector3(cos(a + i * 2.0), randf_range(-0.2, 0.8), sin(a + i * 2.0)) * r
					fx.glow(c + Vector3(0, 1.0, 0) + o, -o * 2.2, 0.4, 0.08, 0.16, Color(0.6, 0.35, 1.0, 0.8))
			"furnace":
				for i in 3: fx.glow(c + Vector3(cos(a + i * 2.1) * q, 0.1, sin(a + i * 2.1) * q), Vector3(0, randf_range(1.0, 2.6), 0), 0.6, 0.3, 0.04, Color(1.0, randf_range(0.15, 0.45), 0.05, 0.8), 0.0, 0.4)
			"trail":
				var ab: Vector3 = (fd.b as Vector3) - (fd.a as Vector3)
				fx.glow((fd.a as Vector3) + ab * randf() + Vector3(0, 0.1, 0), Vector3(0, randf_range(1.2, 2.4), 0), 0.4, 0.4, 0.04, Color(1.0, 0.45, 0.1, 0.8))
			"star":
				if float(fd.t) > float(Races.ULT.elf.t) and randf() < dt * 30.0: fx.glow(c + Vector3(cos(a) * r, 0.15, sin(a) * r), Vector3(0, 1.2, 0), 0.5, 0.2, 0.03, Color(0.85, 0.75, 1.0, 0.9))
			"dome":
				if randf() < dt * 12.0: fx.glow(c + Vector3(cos(a) * r, randf_range(0.2, 2.0), sin(a) * r), Vector3(0, 0.6, 0), 0.8, 0.5, 0.8, Color(0.9, 0.97, 1.0, 0.3))

## a star arrow comes down (on someone, or on the bare ground)
func star(at: Vector3, hit: bool) -> void:
	if rm.fx == null: return
	rm.fx.streak(at + Vector3(randf_range(-0.6, 0.6), 13.0, randf_range(-0.6, 0.6)), at + Vector3(0, 0.9 if hit else 0.0, 0), Color(0.8, 0.7, 1.0, 0.9), 0.05, 0.16)
	rm.fx.sparks(at + Vector3(0, 0.9 if hit else 0.1, 0), 4, [0.75, 0.65, 1.0], 2.5)

# ---------------- made things, and the modes' own ----------------
func thing(th: Dictionary) -> Dictionary:
	if rm.en == null or th.has("node"): return th
	var en := rm.en
	match th.kind:
		"turret":
			var g := Node3D.new(); _root().add_child(g); g.position = th.pos
			en._part(g, Vector3.ZERO, "rm_turret", [[1.2, 0.25, 1.2, 0, 0.125, 0, "8a6a2a"], [0.7, 0.9, 0.7, 0, 0.7, 0, "b07a2e"], [0.9, 0.12, 0.9, 0, 1.2, 0, "d6a43a"], [0.22, 0.22, 0.9, 0, 1.42, 0.3, "6a7280"], [0.34, 0.34, 0.34, 0, 1.42, 0, "8ff7ea"]])
			th.node = g
		"trap": pass   # (the mode draws its circle)
	return th

func thing_gone(th: Dictionary) -> void:
	if th.get("keep", false): return
	if th.has("node") and is_instance_valid(th.node):
		if rm.fx != null: rm.fx.chunks((th.pos as Vector3) + Vector3(0, 0.8, 0), 8, 0.14, "metal"); rm.fx.puff((th.pos as Vector3) + Vector3(0, 1.0, 0), 6, 0.9, 0.6)
		(th.node as Node).queue_free()
	th.erase("node")

func thing_hit(th: Dictionary, elem: String, at: Vector3) -> void:
	if rm.fx == null: return
	var c: Color = ELEM_COL[elem]
	if float(th.get("shield", 0.0)) > 0.0:
		for i in 6: var a := i * TAU / 6.0; rm.fx.glow(at, Vector3(cos(a), sin(a), 0.0) * 2.4, 0.3, 0.1, 0.02, Color(0.6, 0.75, 1.0, 0.9))   # (six ways: the shield's own mark)
	else: rm.fx.sparks(at, 4, [c.r, c.g, c.b], 3.0)
	if randf() < 0.3: Snd.play("rm_shield_hit" if float(th.get("shield", 0.0)) > 0.0 else str(th.get("snd", "metal")), 0.5, at)

func prop(kind: String, at: Vector3, label: String) -> Node3D:
	if rm.en == null: return null
	var en := rm.en; var g := Node3D.new(); _root().add_child(g); g.position = at
	match kind:
		"altar":
			en._part(g, Vector3.ZERO, "rm_altar", [[1.6, 0.4, 1.6, 0, 0.2, 0, "9a9ea8"], [1.0, 0.7, 1.0, 0, 0.75, 0, "7e828c"], [1.3, 0.12, 1.3, 0, 1.16, 0, "d6a43a"]])
			var c := _mi(_box("crystal", Vector3(0.5, 1.1, 0.5)), _unlit("crystal", Color(0.55, 0.95, 1.0, 0.85), true), g); c.position = Vector3(0, 1.9, 0); c.rotation = Vector3(0.6, 0.8, 0.0); c.name = "crystal"
			var ring := _flat(ModeSiege.SET_R, "altar_ring", Color(1.0, 0.84, 0.42, 0.25)); ring.get_parent().remove_child(ring); g.add_child(ring); ring.name = "ring"
			var t := Label3D.new(); t.text = label; t.font_size = 96; t.pixel_size = 0.012; t.billboard = BaseMaterial3D.BILLBOARD_ENABLED; t.position = Vector3(0, 3.0, 0); t.modulate = Color("ffd66b"); t.no_depth_test = true; g.add_child(t)
		"bomb":
			en._part(g, Vector3.ZERO, "rm_bomb", [[0.5, 0.5, 0.5, 0, 0.3, 0, "2c6a60"], [0.16, 0.2, 0.16, 0, 0.65, 0, "d6a43a"], [0.6, 0.08, 0.6, 0, 0.3, 0, "d6a43a"]])
			var l := _mi(_box("bomb_l", Vector3(0.14, 0.14, 0.14)), _unlit("bomb_l", Color(1.0, 0.5, 0.15, 1.0), true), g); l.position = Vector3(0, 0.82, 0)
		"nucleus":
			var core := _ball(1.1, "nucleus", Color(0.62, 0.5, 1.0, 0.9)); core.get_parent().remove_child(core); g.add_child(core); core.position = Vector3(0, 1.3, 0); core.name = "core"
			var sh := _ball(1.5, "nuc_shield", Color(0.5, 0.75, 1.0, 0.28)); sh.get_parent().remove_child(sh); g.add_child(sh); sh.position = Vector3(0, 1.3, 0); sh.name = "shield"
		"seal":
			var w := _mi(_box("seal", Vector3(3.1, 4.6, 0.12)), _unlit("seal", Color(0.45, 0.7, 1.0, 0.45), true), g); w.position = Vector3(0, 2.3, 0)
		"trap":
			var d := _flat(float(ModeSiege.TRAP.r), "trap", Color(0.56, 0.97, 0.92, 0.4)); d.get_parent().remove_child(d); g.add_child(d)
			var d2 := _flat(float(ModeSiege.TRAP.r) * 0.55, "trap2", Color(0.85, 0.65, 1.0, 0.5), 0.06); d2.get_parent().remove_child(d2); g.add_child(d2)
	return g

func prop_state(n, state: String) -> void:
	if n == null or not is_instance_valid(n): return
	var c := (n as Node).get_node_or_null("crystal"); var core := (n as Node).get_node_or_null("core"); var sh := (n as Node).get_node_or_null("shield"); var ring := (n as Node).get_node_or_null("ring")
	if c != null: (c as Node3D).visible = state == "whole"
	if ring != null: (ring as Node3D).visible = state == "whole"
	if core != null: (core as Node3D).visible = state != "broken"
	if sh != null: (sh as Node3D).visible = state != "broken"

func base_shield(on: bool) -> void:
	for n in shield_nodes:
		if is_instance_valid(n): (n as Node).queue_free()
	shield_nodes.clear()
	if not on or rm.en == null: return
	for team in ["us", "them"]:
		var b: Vector3 = rm.mode.base_of(team); b.y = Phys.ground_at(b.x, b.y + 0.6, b.z, 0.3)
		var m := _ball(6.6, "base_" + team, Color("5f9cff" if team == "us" else "ff5260", 0.16), true); m.position = b; shield_nodes.push_back(m)

func decoy(dc: Dictionary) -> Dictionary:
	if rm.en == null: return dc
	var by: Realm.Fighter = dc.by
	var g := Node3D.new(); _root().add_child(g); g.position = dc.pos; g.rotation.y = atan2(by.aim.x, by.aim.z); g.scale = Vector3(by.R / 0.36, by.H / MODEL_H, by.R / 0.36)
	var m := _mi(rm.en._box_mesh("rm_ghost", [[0.42, 0.62, 0.25, 0, 1.28, 0, "ffffff"], [0.22, 0.25, 0.23, 0, 1.72, 0.01, "ffffff"], [0.34, 0.9, 0.2, 0, 0.47, 0, "ffffff"], [0.6, 0.05, 0.05, 0, 1.3, 0.6, "ffffff"]]), _unlit("ghost", Color(0.45, 0.95, 0.85, 0.55)), g)
	m.set_meta("ghost", true); dc.node = g
	return dc

func decoy_gone(dc: Dictionary) -> void:
	if dc.has("node") and is_instance_valid(dc.node):
		if rm.fx != null: rm.fx.sparks((dc.pos as Vector3) + Vector3(0, 1.0, 0), 8, [0.5, 1.0, 0.9], 2.0)
		(dc.node as Node).queue_free()
	dc.erase("node")

# ---------------- the moments ----------------
func reload(_f: Realm.Fighter) -> void: pass
func fired(f: Realm.Fighter, kind: String) -> void:
	if f.me: kick = 1.0 if kind == "big" or kind == "gren" else 0.45
	if rm.fx == null: return
	var at := view_muzzle(f); var sz := 0.5 if f.me else 1.0
	if kind == "arrow" or kind == "big": rm.fx.glow(at, f.aim * 2.0, 0.12, 0.14 * sz, 0.02, Color(0.6, 1.0, 0.95, 0.8))
	elif kind == "ember": rm.fx.glow(at, f.aim * 3.0 + Vector3(0, 0.5, 0), 0.14, 0.16 * sz, 0.03, Color(1.0, 0.5, 0.12, 0.8))

## the cannon goes off: a ring of steam from its mouth, the shards' ways, sparks where they end
func cannon(f: Realm.Fighter, ends: Array, all_close: bool) -> void:
	if f.me: kick = 1.6 if all_close else 1.1
	if rm.fx == null: return
	var o := view_muzzle(f); var up := Vector3.UP if absf(f.aim.y) < 0.95 else Vector3.RIGHT; var x := f.aim.cross(up).normalized(); var y := x.cross(f.aim); var sz := 0.35 if f.me else 1.0
	for i in 10: var a := i * TAU / 10.0; rm.fx.glow(o + f.aim * 0.15, f.aim * 5.0 + (x * cos(a) + y * sin(a)) * 2.2, 0.35, 0.16 * sz, 0.5 * sz, Color(0.95, 0.98, 1.0, 0.45), 0.0, 3.0)   # (the vortex ring)
	for i in ends.size():
		var e: Vector3 = ends[i]
		if i % 2 == 0: rm.fx.streak(o, e, Color(1.0, 0.85, 0.6, 0.5), 0.02, 0.06)
		if i % 3 == 0: rm.fx.sparks(e, 2, [1.0, 0.8, 0.5], 2.5)

func steam(at: Vector3, r: float) -> void:
	if rm.fx == null: return
	for i in 12: var a := i * TAU / 12.0; rm.fx.glow(at, Vector3(cos(a), 0.25, sin(a)) * r * 2.2, 0.5, 0.3, 0.9, Color(0.95, 0.98, 1.0, 0.45), 0.0, 2.5)

func swing(f: Realm.Fighter, kind: String, i: int) -> void:
	if f.me: swing_kind = kind; swing_i = i; swing_len = 0.3; swing_t = 0.3

func sealed(f: Realm.Fighter) -> void:
	if rm.fx != null: rm.fx.puff(rm.kit.muzzle(f) + f.aim * 0.6, 5, 0.25, 0.4)

func skilled(f: Realm.Fighter) -> void:
	if rm.fx == null: return
	var c := f.feet_mid()
	match f.race:
		"elf":
			for i in 10: rm.fx.glow(c + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4)), -f.dash_v * 0.12, 0.4, 0.2, 0.03, Color(0.85, 1.0, 0.95, 0.6))
		"dwarf": steam(c - f.dash_v.normalized() * 0.5, 1.0)
		"orc": rm.fx.puff(f.pos + Vector3(0, 0.2, 0), 5, 0.5, 0.5)
		"demon":
			for i in 14: rm.fx.glow(c + Vector3(randf_range(-0.4, 0.4), randf_range(-0.8, 0.8), randf_range(-0.4, 0.4)), Vector3(0, 0.6, 0), 0.5, 0.22, 0.03, Color(0.12, 0.02, 0.05, 0.9) if i % 3 > 0 else Color(1.0, 0.4, 0.1, 0.9))

func landed(f: Realm.Fighter) -> void:
	if rm.fx == null: return
	rm.fx.puff(f.pos + Vector3(0, 0.2, 0), 8, 0.5, 0.7)
	for i in 10: var a := i * TAU / 10.0; rm.fx.glow(f.pos + Vector3(0, 0.1, 0), Vector3(cos(a), 0.1, sin(a)) * 5.0, 0.3, 0.2, 0.05, Color(0.8, 0.7, 0.55, 0.6), 0.0, 3.0)
	if f.me and rm.player != null: rm.player.shake = maxf(rm.player.shake, 0.3)

func ulted(f: Realm.Fighter) -> void:
	if f.me or (rm.me != null and f.pos.distance_to(rm.me.pos) < 30.0): rm.duck_t = float(Races.DUCK.t)   # (one called near you: the music steps back for its signature)
	if rm.fx == null: return
	var c := f.feet_mid(); var col := Color(str(Races.R[f.race].col))
	for i in 24: var a := i * TAU / 24.0; rm.fx.glow(c, Vector3(cos(a), 0.4, sin(a)) * 6.0, 0.6, 0.3, 0.05, Color(col.r, col.g, col.b, 0.9), 0.0, 2.0)

func ult_over(_f: Realm.Fighter) -> void: pass

func executed(v: Realm.Fighter, _by: Realm.Fighter) -> void:
	if rm.fx == null: return
	var c := v.feet_mid() + Vector3(0, 0.3, 0)
	for i in 12:   # the soul's sign, cut in two: one half to each side
		var a := i * PI / 11.0; var side := 1.0 if i % 2 == 0 else -1.0
		rm.fx.glow(c + Vector3(cos(a) * 0.5, sin(a) * 0.5, 0), Vector3(side * 2.4, 0.4, 0), 0.6, 0.16, 0.02, Color(1.0, 0.2, 0.25, 0.95))

## each element leaves its own mark where it strikes the ground or a wall
func impact(elem: String, at: Vector3, n: Vector3) -> void:
	var fx := rm.fx
	if fx == null: return
	match elem:
		"arcane":   # violet cracks that stay three seconds, dust of light drifting
			for i in 3: fx.glow(at + n * 0.03 + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)), n * 0.1, 3.0, 0.12, 0.03, Color(0.72, 0.55, 1.0, 0.85))
			fx.sparks(at, 3, [0.56, 0.97, 0.92], 2.0)
		"fire":   # a glowing crack, black smoke rising
			fx.glow(at + n * 0.03, Vector3.ZERO, 1.2, 0.3, 0.1, Color(1.0, 0.35, 0.08, 0.9)); fx.puff(at + n * 0.1, 2, 0.12, 0.35)
		"physical": fx.chips(at); fx.sparks(at, 3, [1.0, 0.85, 0.6], 3.0); fx.decal(at, n)
		"alchemy":
			for i in 5: fx.glow(at + n * 0.05, Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1)) * 1.5, 0.5, 0.1, 0.03, Color(0.3, 0.95, 0.8, 0.9), 9.0, 1.0)

func burst(at: Vector3, r: float, elem: String) -> void:
	var fx := rm.fx
	if fx == null: return
	var c: Color = ELEM_COL[elem]
	for i in 26: fx.glow(at, Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)).normalized() * r * 2.4, 0.45, 0.4, 0.06, Color(c.r, c.g, c.b, 0.9), 2.0, 3.0)
	fx.puff(at, 6, 0.6, 0.9)
	if rm.player != null and rm.player.pos.distance_to(at) < r * 3.0: rm.player.shake = maxf(rm.player.shake, 0.35)

func amped(p: Vector3) -> void:
	if rm.fx != null: rm.fx.sparks(p, 6, [1.0, 0.85, 0.45], 3.0)

func parried(v: Realm.Fighter, c: Vector3) -> void:
	if v.me: rm.flash["parry"] = 0.25; rm.duck_t = maxf(rm.duck_t, 0.25)
	if rm.fx == null: return
	for i in 12: var a := i * TAU / 12.0; rm.fx.glow(c + v.aim * 0.5, (Vector3(cos(a), sin(a), 0.0)) * 3.0, 0.25, 0.14, 0.02, Color(0.9, 0.97, 1.0, 0.95))

## a shield takes the blow: six ways from the place, each element's own
func shield_hit(v: Realm.Fighter, elem: String, at: Vector3) -> void:
	if rm.fx == null: return
	var c: Color = ELEM_COL[elem]
	for i in 6: var a := i * TAU / 6.0; rm.fx.glow(at, Vector3(cos(a), sin(a), 0.0) * 2.2, 0.28, 0.12, 0.02, Color(c.r, c.g, c.b, 0.9))
	if elem == "physical": rm.fx.puff(at, 2, 0.9, 0.3)
	if v.me or randf() < 0.4: Snd.play("rm_shield_hit", 0.6, at)

## someone struck: each element's own specks; an orc's blow lands with weight
func struck(v: Realm.Fighter, elem: String, at: Vector3, from: Vector3, d: float) -> void:
	var fx := rm.fx
	if fx == null or d < 1.0: return
	var c: Color = ELEM_COL[elem]; var away := (at - from).normalized() if at.distance_to(from) > 0.01 else Vector3.UP
	var n := clampi(int(d / 12.0) + 2, 2, 8)
	match elem:
		"arcane":
			for i in n: fx.glow(at, (away * 0.5 + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1))) * 2.6, 0.4, 0.1, 0.02, Color(0.56, 0.97, 0.92, 0.9) if i % 2 == 0 else Color(0.72, 0.55, 1.0, 0.9), 4.0, 2.0)
		"fire":
			for i in n: fx.glow(at + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2)), Vector3(0, randf_range(0.8, 2.0), 0), 0.4, 0.22, 0.03, Color(1.0, randf_range(0.3, 0.6), 0.08, 0.9))
		"physical":   # each people bleeds its own mist
			var mc := {"elf": Color(0.8, 0.95, 0.9, 0.7), "dwarf": Color(0.95, 0.9, 0.8, 0.7), "orc": Color(0.75, 0.1, 0.1, 0.8), "demon": Color(0.25, 0.05, 0.08, 0.85)}.get(v.race, Color(0.25, 0.05, 0.08, 0.85)) as Color   # (6-A's demons: as the demons')
			for i in n: fx.glow(at, (away + Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)) * 0.8) * 2.4, 0.4, 0.14, 0.04, mc, 6.0, 2.0)
		"alchemy":
			for i in n: fx.glow(at, Vector3(randf_range(-1, 1), randf_range(0.4, 1.6), randf_range(-1, 1)) * 1.8, 0.5, 0.09, 0.02, Color(c.r, c.g, c.b, 0.9), 9.0, 1.0)

func burning(f: Realm.Fighter) -> void:
	if rm.fx != null:
		for i in 3: rm.fx.glow(f.feet_mid() + Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.6), randf_range(-0.3, 0.3)), Vector3(0, 1.6, 0), 0.4, 0.26, 0.03, Color(1.0, 0.45, 0.1, 0.85))
	if f.me or randf() < 0.3: Snd.play("rm_burn", 0.5, null if f.me else f.feet_mid())

## someone falls: no body left lying; each people goes its own way
func fell(v: Realm.Fighter, _by, _o: Dictionary) -> void:
	if rm.mode.fell(v): return   # (6-A's demons go their own way)
	var fx := rm.fx; var c := v.feet_mid(); var top := v.pos + Vector3(0, v.H, 0)
	Snd.play("rm_die_" + v.race, 1.0, null if v.me else c)
	if fx == null: return
	match v.race:
		"elf":   # silver drops of light and leaves, rising
			for i in 26: fx.glow(v.pos + Vector3(randf_range(-0.35, 0.35), randf_range(0.1, v.H), randf_range(-0.35, 0.35)), Vector3(randf_range(-0.3, 0.3), randf_range(1.0, 2.6), randf_range(-0.3, 0.3)), randf_range(0.8, 1.5), 0.14, 0.02, Color(0.9, 0.97, 1.0, 0.85) if i % 3 > 0 else Color(0.35, 0.8, 0.5, 0.9))
		"dwarf":   # the rune armour comes apart; the pack lets out its last steam
			fx.chunks(c, 10, 0.16, "metal"); fx.puff(c + Vector3(0, 0.3, 0), 10, 0.95, 0.8)
		"orc":   # a burst of red; only the sword is left, stuck in the ground
			for i in 30: fx.glow(c, Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(2.0, 6.0), randf_range(0.5, 0.9), 0.4, 0.08, Color(0.8, 0.08, 0.08, 0.8), 1.0, 3.0)
			if rm.en != null:
				var s: Node3D = rm.en._part(_root(), v.pos + Vector3(0, 0.75, 0), "rm_left_sword", [[0.13, 1.6, 0.05, 0, 0, 0, "c9d3dc"], [0.42, 0.07, 0.07, 0, 0.7, 0, "6b4a2c"]]); s.rotation = Vector3(0.18, randf() * TAU, 0.1)
				_ghosts.push_back({"n": s, "t": 4.0})
		"demon":   # black ash and embers, drawn down into a crack in the ground
			for i in 28: fx.glow(v.pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, v.H), randf_range(-0.5, 0.5)), Vector3(0, randf_range(-3.5, -1.5), 0), randf_range(0.5, 0.9), 0.16, 0.03, Color(0.06, 0.03, 0.05, 0.95) if i % 4 > 0 else Color(1.0, 0.4, 0.1, 0.9))
			if rm.en != null:
				var d := _flat(0.9, "rift", Color(0.05, 0.0, 0.08, 0.9)); d.position = v.pos + Vector3(0, 0.05, 0); _ghosts.push_back({"n": d, "t": 0.9, "shrink": true})
	if top.y > 0.0 and v.me and rm.player != null: rm.player.shake = maxf(rm.player.shake, 0.4)

## someone off the field for good: his body and his bar
func drop(f: Realm.Fighter) -> void:
	for k in ["g", "bar"]:
		if f.body.has(k) and is_instance_valid(f.body[k]): (f.body[k] as Node).queue_free()
	f.body = {}

## a landmark summons (6-2): a circle of its people's colour on the ground before it, and light going up from it
func summoned(at: Vector3, race: String) -> void:
	var col := Color(str(Races.R[race].col))
	if rm.en != null: var d := _flat(3.2, "summon_" + race, Color(col, 0.42)); d.position = at + Vector3(0, 0.06, 0); _ghosts.push_back({"n": d, "t": 1.2})
	if rm.fx == null: return
	for i in 36:
		var a := i * TAU / 36.0
		rm.fx.glow(at + Vector3(cos(a) * 3.0, 0.1, sin(a) * 3.0), Vector3(0, randf_range(2.0, 5.0), 0), randf_range(0.6, 1.1), 0.22, 0.04, Color(col.lightened(0.3), 0.9))

func came_back(f: Realm.Fighter) -> void:
	if rm.fx == null: return
	for i in 14: rm.fx.glow(f.pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 1.8), randf_range(-0.5, 0.5)), Vector3(0, randf_range(0.6, 2.0), 0), 0.6, 0.24, 0.03, Color("5f9cff" if f.team == "us" else "ff7a70", 0.8))

func ported(_f: Realm.Fighter, a: Vector3, b: Vector3) -> void:
	if rm.fx == null: return
	for at: Vector3 in [a, b]:
		for i in 12: rm.fx.glow(at + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.8), randf_range(-0.6, 0.6)), Vector3(0, randf_range(0.5, 2.0), 0), 0.6, 0.3, 0.04, Color(0.72, 0.57, 1.0, 0.8))

func resonance(at: Vector3, r: float) -> void:
	if rm.fx == null: return
	for i in 40: var a := i * TAU / 40.0; rm.fx.glow(at + Vector3(0, 0.5, 0), Vector3(cos(a), 0.05, sin(a)) * r * 1.6, 0.7, 0.5, 0.1, Color(1.0, 0.84, 0.42, 0.9), 0.0, 1.0)
	if rm.player != null: rm.player.shake = maxf(rm.player.shake, 0.4)

# ---------------- the frame ----------------
func update(dt: float) -> void:
	for f: Realm.Fighter in rm.all:
		if not f.me and not rm.mode.place(f, dt): _place(f, dt)   # (6-A's demons: the mode draws its own)
	_shots(dt); _fields(dt); _hands(dt)
	for i in range(_ghosts.size() - 1, -1, -1):
		var q: Dictionary = _ghosts[i]; q.t = float(q.t) - dt
		if not is_instance_valid(q.n): _ghosts.remove_at(i); continue
		if q.get("shrink", false): (q.n as Node3D).scale = Vector3(maxf(0.01, float(q.t)), 1.0, maxf(0.01, float(q.t)))
		if float(q.t) <= 0.0: (q.n as Node).queue_free(); _ghosts.remove_at(i)
	# the demon's beam
	for f: Realm.Fighter in rm.all:
		if f.alive and f.beam_on and rm.fx != null: rm.fx.streak(view_muzzle(f), f.beam_end, Color(0.75, 0.1, 0.45, 0.6), 0.035 if f.me else 0.06, 0.05)
