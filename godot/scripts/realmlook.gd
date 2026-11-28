class_name RealmLook
extends RefCounted
## What is seen of a realm battle: the nine others' bodies (each people's shape, your side's in blue and theirs in red),
## what flies, what lies about, the made things, your own weapon in your hands, and the moments that give a blow its
## weight (each element's own mark where it strikes, each people's own way of going when it falls).

const ELEM_COL := {"arcane": Color(0.62, 0.5, 1.0), "fire": Color(1.0, 0.5, 0.15), "physical": Color(0.85, 0.9, 1.0), "alchemy": Color(0.3, 0.95, 0.8)}
const MODEL_H := 1.86      # a decoy's height before its maker's own scale

var rm: Realm
var root: Node3D = null
var view: Node3D = null    # your weapon
var models := {}           # race -> its node in your hands
var rigs := {}             # race -> its moving parts (RaceArt's: the crescents, the core, the string...)
var _rt := {}              # the moving parts' own clocks (a shot's pulse, the arrow laid again)
var dagger: Node3D = null
var daggers := {}          # race -> the rune dagger in its people's hand (RaceArt.dagger)
var bombs_held := {}       # kind -> the bomb your left hand throws (RaceArt.bomb), made when first thrown
var gauge: MeshInstance3D = null   # the furnace cannon's pressure gauge (its skin's: lava-lit while it loads)
var orbit: Node3D = null      # the obsidian staff's shards, round its top above 80% heat (its skin's)
var charm: Node3D = null      # Karnok's miniature mace, hung from the weapon in your hands
var kick := 0.0; var swing_t := 0.0; var swing_len := 0.0; var swing_kind := ""; var swing_i := 0
var hip := 1.0               # (a narrow screen: the weapon comes in from the side less far; Main sets it)
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
func build(f: Realm.Fighter) -> void:
	var en := rm.en
	if en == null: return
	if f.body.has("g") and is_instance_valid(f.body.g): (f.body.g as Node).queue_free()
	if f.body.has("bar") and is_instance_valid(f.body.bar): (f.body.bar as Node).queue_free()
	var sk := rm.kit.mine(f) and RaidLoot.skin_of(f.race) != ""   # (yours: its weapon in its mythic skin)
	var B: Dictionary = RaceArt.body(f.race, f.team, sk); var m := RaceArt.body_mat()
	var g := Node3D.new(); g.rotation_order = EULER_ORDER_YXZ; _root().add_child(g)
	g.scale = Vector3.ONE * (f.H / float(Races.R[f.race].h))   # (each people drawn at its own size: the paper's proportions)
	var b := {"g": g, "ph": randf() * TAU}
	var hip: float = B.hip; var lx: float = B.leg_x; var sho: Vector2 = B.sho
	b.leg_l = _bpart(g, Vector3(-lx, hip, 0), B.leg, m); b.leg_r = _bpart(g, Vector3(lx, hip, 0), B.leg, m)
	b.upper = _bpart(g, Vector3(0, hip, 0), B.up, m)
	b.arm_l = _bpart(b.upper, Vector3(-sho.x, sho.y, 0), B.al, m); b.arm_r = _bpart(b.upper, Vector3(sho.x, sho.y, 0), B.ar, m)
	if B.has("wing"):   # (the demon's wings, half spread, and its tail)
		var wa: Vector3 = B.wing_at
		b.wing_r = _bpart(b.upper, Vector3(wa.x, wa.y, wa.z), B.wing, m); b.wing_l = _bpart(b.upper, Vector3(-wa.x, wa.y, wa.z), B.wing, m); (b.wing_l as Node3D).scale = Vector3(-1, 1, 1)
		b.tail = _bpart(b.upper, B.tail_at, B.tail, m)
	var bar := Node3D.new(); bar.visible = false; _root().add_child(bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.84, 0.08, 1); bar.add_child(bg)
	if _blue_bar == null:
		_blue_bar = (en._bar_fill as StandardMaterial3D).duplicate(); (_blue_bar as StandardMaterial3D).albedo_color = Color("5f9cff")
		_white_bar = (en._bar_fill as StandardMaterial3D).duplicate(); (_white_bar as StandardMaterial3D).albedo_color = Color("e8f4ff")
	var fill := MeshInstance3D.new(); fill.mesh = en._bar_mesh; fill.material_override = _blue_bar if f.team == "us" else en._bar_fill; fill.scale = Vector3(0.8, 0.05, 1); bar.add_child(fill)
	var sh := MeshInstance3D.new(); sh.mesh = en._bar_mesh; sh.material_override = _white_bar; sh.scale = Vector3(0.0, 0.03, 1); sh.position = Vector3(0, 0.07, 0); bar.add_child(sh)
	b.bar = bar; b.fill = fill; b.sh = sh
	f.body = b

## a part of a body: a pivot, and its mesh on it
func _bpart(parent: Node3D, at: Vector3, mesh: Mesh, m: Material) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m; n.add_child(mi)
	return n

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
	if b.has("wing_r"):   # the wings breathe, and spread as it leaps or dashes; the tail sways
		var fl := sin(rm.clock * 2.2 + float(b.ph)) * 0.08 + (0.5 if f.leaping or f.dash_t > 0.0 else 0.0) * 0.6 + amt * 0.12
		(b.wing_r as Node3D).rotation = Vector3(0.0, 0.5 - fl, 0.15 + fl * 0.4); (b.wing_l as Node3D).rotation = Vector3(0.0, -0.5 + fl, -0.15 - fl * 0.4)
		(b.tail as Node3D).rotation = Vector3(0.1 * sin(rm.clock * 1.3 + float(b.ph)), 0.3 * sin(rm.clock * 1.7 + float(b.ph)), 0.0)
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
	for r: String in Races.ORDER:
		var sk := RaidLoot.skin_of(r) != ""
		# (the art paper's weapons: RaceArt's, with their hands and moving parts)
		var rig: Dictionary = {"elf": RaceArt.xbow, "dwarf": RaceArt.cannon, "orc": RaceArt.greatsword, "demon": RaceArt.staff}[r].call(sk)
		view.add_child(rig.root); (rig.root as Node3D).visible = false; models[r] = rig.root; rigs[r] = rig
		if sk and r == "dwarf": gauge = (rig.needle as Node3D).get_child(0)   # (the abyss furnace's gauge: its face lava-lit while it loads)
		if sk and r == "demon": orbit = rig.orbit   # (the eclipse staff's shards, round its core above 80% heat)
	charm = en._part(view, Vector3.ZERO, "rm_charm_mace", [[0.008, 0.07, 0.008, 0, -0.035, 0, "3a2c24"], [0.03, 0.03, 0.03, 0, -0.08, 0, "4c4a50"], [0.012, 0.012, 0.045, 0, -0.08, 0, "8a8f98"], [0.045, 0.012, 0.012, 0, -0.08, 0, "8a8f98"]]); charm.visible = false
	for r: String in Races.ORDER:   # the rune dagger, in each people's own left hand
		var dg: Dictionary = RaceArt.dagger(r); view.add_child(dg.root); (dg.root as Node3D).visible = false; daggers[r] = dg
	dagger = (daggers.elf as Dictionary).root

func _hands(dt: float) -> void:
	_view()
	if view == null: return
	var f := rm.me; var on: bool = f != null and f.alive and rm.player != null and not rm.player.out and not (rm.game != null and bool(rm.game.ended))
	for r: String in models: (models[r] as Node3D).visible = on and r == f.race
	kick = maxf(0.0, kick - dt * 6.0)
	if swing_t > 0.0 and rm.stop_t <= 0.0: swing_t = maxf(0.0, swing_t - dt)
	if not on: dagger.visible = false; charm.visible = false; return
	var n: Node3D = models[f.race]; var t := rm.clock
	var mv := clampf(rm.player.speed_xz / 5.0, 0.0, 1.3) * (1.0 if rm.player.grounded else 0.2)
	var bob := -absf(cos(rm.player.step_phase)) * 0.012 * mv
	var at := Vector3(0.21 * hip + sin(rm.player.step_phase) * 0.01 * mv, -0.2 + bob + rm.player.land_dip * 0.4, -0.5 + kick * 0.07); var rot := Vector3(kick * 0.12, 0.0, 0.0)
	match f.race:
		"elf":
			var pose := _elf(rigs.elf, f, dt, t, mv, bob); at = pose[0]; rot = pose[1]
		"dwarf":
			var pose := _dwarf(rigs.dwarf, f, dt, t, mv, bob); at = pose[0]; rot = pose[1]
		"orc":
			_orc(rigs.orc, f, dt, t, mv, bob); at = Vector3.ZERO; rot = Vector3.ZERO
		"demon":
			var pose := _demon(rigs.demon, f, dt, t, mv, bob); at = pose[0]; rot = pose[1]
	n.position = at; n.rotation = rot
	# the skins' moving parts: the gauge while the cannon loads, the shards above 80% heat; the charm swinging under the weapon
	if gauge != null and f.race == "dwarf": var lit := f.reload_t > 0.0 and fmod(t, 0.3) < 0.18; RaceArt.set_glow(rigs.dwarf.mat, 3, Color(1.0, 0.45, 0.08) if lit else Color("ffd27a"), 4.0 if lit else 1.4)
	if orbit != null and f.race == "demon": orbit.visible = f.heat >= float(Races.STAFF.crit); orbit.rotation.z = t * 4.0; orbit.rotation.x = 0.3 * sin(t * 2.0)
	charm.visible = RaidLoot.wearing("charm_mace")
	if charm.visible:
		var sway := sin(t * 3.1) * 0.25 + clampf(rm.player.vel.x * 0.04, -0.4, 0.4) + kick * 0.3
		charm.position = at + Vector3(-0.05, -0.07, 0.08); charm.rotation = Vector3(rot.x * 0.2 + 0.2 * sin(t * 2.3), 0, sway)
	# the dagger in your left hand: a cut across, reversed; or the parry, its flat set before you and the rune hexagon out
	for r: String in daggers: if r != f.race: ((daggers[r] as Dictionary).root as Node3D).visible = false
	var dg: Dictionary = daggers[f.race]; dagger = dg.root
	var cut := f.dag_t > float(Races.DAGGER.cd) - 0.25
	dagger.visible = cut or f.parry_t > 0.0
	var shield: Node3D = dg.shield; shield.visible = false
	if cut:
		var u := 1.0 - (f.dag_t - (float(Races.DAGGER.cd) - 0.25)) / 0.25; var e := smoothstep(0.0, 1.0, u)
		dagger.position = Vector3(0.14, -0.1, -0.33).lerp(Vector3(-0.3, -0.26, -0.38), e); dagger.rotation = Vector3(0.5, 1.1, 1.35).lerp(Vector3(0.1, -0.5, 0.9), e)
	elif f.parry_t > 0.0:
		var pl := rm.kit.parry_len(f); var u := 1.0 - f.parry_t / maxf(pl, 0.01); var tw := smoothstep(0.0, 0.2, u)
		dagger.position = Vector3(-0.14, -0.2, -0.36).lerp(Vector3(-0.05, -0.06, -0.3), tw); dagger.rotation = Vector3(0.3, 1.2, 0.6).lerp(Vector3(0.0, 0.0, 0.05), tw)
		shield.visible = true; var fl := 1.0 - smoothstep(0.0, 0.25, u) * 0.6; shield.scale = Vector3.ONE * lerpf(0.55, 1.0, smoothstep(0.0, 0.15, u))
		Gfx.set_alpha(dg.shield_mat, 0.55 * fl * (1.0 - smoothstep(0.8, 1.0, u)) + 0.08)
	# a bomb thrown: it leaves your left hand in an arc
	var thrown := swing_kind == "throw" and swing_t > 0.0
	for k: String in bombs_held: ((bombs_held[k] as Dictionary).root as Node3D).visible = false
	if thrown and not f.bomb_kinds.is_empty():
		var kind: String = f.bomb_kinds[(f.bomb_i - 1 + f.bomb_kinds.size()) % f.bomb_kinds.size()]
		if not bombs_held.has(kind): var b: Dictionary = RaceArt.bomb(kind); view.add_child(b.root); bombs_held[kind] = b
		var bn: Node3D = (bombs_held[kind] as Dictionary).root; var u := 1.0 - swing_t / maxf(swing_len, 0.01)
		bn.visible = u < 0.7; bn.position = Vector3(-0.2, -0.26, -0.3).lerp(Vector3(-0.06, -0.02, -0.62), u) + Vector3(0, sin(u * PI) * 0.08, 0); bn.rotation = Vector3(u * 6.0, u * 3.0, 0)
	_bombs_turn(dt)
	# your left hand off the weapon while it holds the dagger or throws
	var rig: Dictionary = rigs.get(f.race, {}); var busy := dagger.visible or thrown
	if rig.has("lhand") and f.race != "demon": (rig.lhand as Node3D).visible = not busy
	if f.race == "orc": (rig.axe as Node3D).visible = not busy; (rig.chain as Node3D).visible = not busy

## the bombs' own motion, in your hand or flying: the oil sloshing, the rings turning, the wick's flame
func _bombs_turn(dt: float) -> void:
	var t := rm.clock
	var all: Array = bombs_held.values()
	for s: Dictionary in rm.kit.shots:
		if s.has("bomb_rig"): all.push_back(s.bomb_rig)
	for b: Dictionary in all:
		if b.has("oil"): (b.oil as Node3D).scale = Vector3(1.0 + 0.06 * sin(t * 9.0), 1.0 - 0.08 * sin(t * 9.0 + 1.0), 1.0 + 0.05 * cos(t * 7.0))
		if b.has("flame"): (b.flame as Node3D).scale = Vector3.ONE * (0.8 + 0.3 * sin(t * 31.0) + 0.15 * sin(t * 17.0))
		for i in (b.spin as Array).size(): var r: Node3D = b.spin[i]; r.rotate_object_local(Vector3.UP, dt * (5.0 + i * 3.0))
		if b.has("halo"): (b.halo as Node3D).scale = Vector3.ONE * (0.9 + 0.2 * sin(t * 14.0))

## the arcane repeater in your hands: held low on the right; drawn up to your eye as it charges, the four crescents
## closing on the middle of your sight and the string drawn back, the core turning faster; on the reload your left hand
## throws the gold lever, the spent core rises and is filled with mana from your palm. Returns [where, turn]
func _elf(rig: Dictionary, f: Realm.Fighter, dt: float, t: float, mv: float, bob: float) -> Array:
	var W := Races.XBOW; var c := clampf(f.charge / float(W.charge), 0.0, 1.0) if f.charge > 0.0 else 0.0
	var up := smoothstep(0.0, 0.4, c)
	var hipp := Vector3(0.1 * hip + sin(rm.player.step_phase) * 0.008 * mv, -0.21 + bob + rm.player.land_dip * 0.4, -0.31 + kick * 0.012)
	var aim := Vector3(0.0, -RaceArt.XB_SIGHT.y, -0.235 - RaceArt.XB_SIGHT.z)
	var at := hipp.lerp(aim, up); var rot := Vector3(0.17 + kick * 0.02, 0.14, -0.1).lerp(Vector3(0.0, 0.0, 0.0), up)
	if c > 0.0: at += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0006 * c   # (held taut)
	var rl := 0.0
	if f.reload_t > 0.0: rl = 1.0 - f.reload_t / float(W.reload); at.y -= 0.05 * sin(rl * PI); rot.z += 0.35 * sin(rl * PI); rot.x += 0.12 * sin(rl * PI)
	# the crescents: their ring closes as it charges and they turn faster; locked at full charge
	var spin := float(_rt.get("xb_spin", 0.0)) + dt * (0.5 + 5.0 * c); _rt["xb_spin"] = spin
	var lock := 1.0 if f.charged else 0.0
	var cres: Array = rig.crescents
	for i in 4:
		var cn: Node3D = cres[i]; var a := i * PI / 2.0 + spin * (1.0 - lock) + lock * PI / 4.0
		var close := 0.0135 * c + 0.0015 * lock; var bob2 := sin(t * 2.2 + i * 1.7) * 0.0012 * (1.0 - c)
		cn.rotation = Vector3(0, 0, a); cn.position = Vector3(cos(a), sin(a), 0) * (-close + bob2)
	(rig.sight as Node3D).rotation.z = 0.0
	var gc: Color = Color(RaceArt.PAL.elf.glow).lerp(Color(RaceArt.PAL.elf.charge), c)
	RaceArt.set_glow(rig.mat, 3, gc, 1.2 + 3.0 * c + 2.0 * lock); RaceArt.set_glow(rig.mat, 1, gc, 2.2 + 2.0 * c)
	# the core: it turns as fast as the magazine is full, pulses with each shot, rises to be filled on the reload
	var core: Node3D = rig.core; var pulse := maxf(0.0, 1.0 - f.fired_t / 0.16)
	var cs := float(_rt.get("xb_core", 0.0)) + dt * (0.6 + 3.2 * float(f.ammo) / float(W.mag) + 6.0 * c); _rt["xb_core"] = cs
	var rise := 0.0
	if rl > 0.0: rise = smoothstep(0.15, 0.4, rl) * (1.0 - smoothstep(0.75, 0.95, rl)); cs += dt * 14.0 * rise; _rt["xb_core"] = cs
	core.rotation = Vector3(0, cs, 0); core.position = RaceArt.XB_CORE + Vector3(0, 0.062 * rise, 0); core.scale = Vector3.ONE * (1.0 + 0.32 * pulse + 0.1 * c + 0.06 * sin(t * 9.0) * c)
	(rig.halo as Node3D).scale = Vector3.ONE * (0.8 + 0.8 * pulse + 0.6 * c + 0.4 * rise)
	RaceArt.set_glow(rig.mat, 2, Color(RaceArt.PAL.elf.core).lerp(Color(1, 0.85, 1), pulse * 0.6), 2.4 + 3.0 * pulse + 2.0 * c)
	if rise > 0.3 and rm.fx != null and randf() < dt * 40.0:   # (mana from your palm drawn into it)
		var cw := (rig.root as Node3D).global_transform * (RaceArt.XB_CORE + Vector3(0, 0.062 * rise, 0)); var from := (rig.root as Node3D).global_transform * Vector3(-0.07, 0.0, -0.07)
		rm.fx.glow(from, (cw - from) * 4.0, 0.25, 0.012, 0.004, Color(0.45, 0.85, 1.0, 0.9))
	# the lever, thrown by your left hand at the start of the reload and back at its end
	var lv := smoothstep(0.0, 0.18, rl) * (1.0 - smoothstep(0.82, 1.0, rl)) if rl > 0.0 else 0.0
	(rig.lever as Node3D).rotation = Vector3(-1.25 * lv, 0, 0)
	var lh: Node3D = rig.lhand
	lh.position = Vector3(-0.045, 0.012, 0.29) * lv; lh.rotation = Vector3(0.0, 0.4 * lv, -0.5 * lv)
	# the string, drawn back as it charges; the arrow of light laid on the rail again after each shot
	var sz := lerpf(RaceArt.XB_STRING_Z, RaceArt.XB_DRAWN, smoothstep(0.0, 1.0, c)); var mid := Vector3(0, 0.0655, sz)
	var bend := 0.018 * c   # (the limbs give as the string is drawn)
	var nl := RaceArt.XB_NOCK_L + Vector3(bend, 0, bend * 0.6); var nr := RaceArt.XB_NOCK_R + Vector3(-bend, 0, bend * 0.6)
	RaceArt.stretch(rig.string[0], nl, mid); RaceArt.stretch(rig.string[1], nr, mid)
	(rig.nub as Node3D).position = mid; (rig.nub as Node3D).scale = Vector3.ONE * (0.7 + 1.2 * c)
	var laid := clampf((f.fired_t - 0.05) / 0.22, 0.0, 1.0) if f.reload_t <= 0.0 and f.ammo > 0 else 0.0
	var bolt: Node3D = rig.bolt; bolt.visible = laid > 0.02; bolt.scale = Vector3(laid, laid, 1.0); bolt.position = Vector3(0, 0.0675, mid.z + 0.002)
	return [at, rot]

## the rune blunderbuss in your hands: heavy and low on the right; it kicks up hard, its runes and bore glow amber and
## cool; the gauge's needle shivers with the pressure left in it (the shells in it), the mortar's glass fills as its
## grenade comes back. The reload: the red valve twisted, steam hissing out of both vents, the barrel broken open on its
## hinge, five brass shells pushed in at once by your left hand, shut. Returns [where, turn]
func _dwarf(rig: Dictionary, f: Realm.Fighter, dt: float, t: float, mv: float, bob: float) -> Array:
	var W := Races.CANNON
	var at := Vector3(0.12 * hip + sin(rm.player.step_phase) * 0.01 * mv, -0.2 + bob + rm.player.land_dip * 0.4, -0.3 + kick * 0.045); var rot := Vector3(0.12 + kick * 0.34, 0.12, -0.06)
	var heat := maxf(0.0, float(_rt.get("dw_heat", 0.0)) - dt * 0.45); _rt["dw_heat"] = heat
	RaceArt.set_glow(rig.mat, 1, Color(RaceArt.PAL.dwarf.glow if RaidLoot.skin_of("dwarf") == "" else RaceArt.SKIN_PAL.dwarf.glow), 0.25 + 4.5 * heat * heat)
	RaceArt.set_glow(rig.mat, 2, Color(RaceArt.PAL.dwarf.glow), 5.0 * heat)
	# the hammer: struck down as it fires, cocked again
	var since := float(_rt.get("dw_fired", 9.0)) + dt; _rt["dw_fired"] = since
	(rig.hammer as Node3D).rotation.x = (0.55 if since < 0.07 else lerpf(0.55, -0.35, clampf((since - 0.15) / 0.3, 0.0, 1.0)))
	# the needle: the pressure left, never quite still
	var pr := 0.12 + 0.76 * float(f.ammo) / float(W.mag) + sin(t * 23.0) * 0.012 + sin(t * 7.3) * 0.02 + heat * 0.06
	(rig.needle as Node3D).rotation = Vector3(0, -PI / 2.0, -lerpf(-2.4, 2.4, clampf(pr, 0.0, 1.0)))
	# the mortar's glass: the grenade's liquid filling back as it returns (frost-blue with the rune)
	var fill := clampf(1.0 - f.alt_cd / float(W.gren_cd), 0.03, 1.0) if f.alt_cd > 0.0 else 1.0
	(rig.liquid as Node3D).scale = Vector3(1, 1, fill)
	var frost := f.rune("dw_frost"); var lc: Color = Color(RaceArt.PAL.dwarf.frost) if frost else Color(RaceArt.PAL.dwarf.oil)
	RaceArt.set_glow(rig.liq_mat, 2, lc, 0.9 if frost else 0.35)
	# the reload
	var u := 1.0 - f.reload_t / float(W.reload) if f.reload_t > 0.0 else 0.0
	var valve := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.9, 1.0, u)) if u > 0.0 else 0.0
	(rig.valve as Node3D).rotation.y = -3.2 * valve
	var open := smoothstep(0.28, 0.42, u) * (1.0 - smoothstep(0.78, 0.9, u)) if u > 0.0 else 0.0
	(rig.barrel as Node3D).rotation.x = -0.62 * open
	var push := smoothstep(0.45, 0.72, u) if u > 0.0 else 0.0
	var sh: Node3D = rig.shells; sh.visible = u > 0.4 and u < 0.76
	sh.position = Vector3(-0.07, -0.02, 0.12).lerp(RaceArt.DW_HINGE + Vector3(0, 0.036, 0.01), push); sh.rotation = Vector3(0.0, 0.0, 0.0)
	var lh: Node3D = rig.lhand; var reach := smoothstep(0.36, 0.5, u) * (1.0 - smoothstep(0.76, 0.9, u)) if u > 0.0 else 0.0
	lh.position = (Vector3(-0.05, 0.02, 0.36) + (sh.position - Vector3(-0.07, -0.02, 0.12)) * 0.8) * reach; lh.rotation = Vector3(0.3 * reach, 0.6 * reach, 0.0)
	if u > 0.0: at.y -= 0.05 * sin(u * PI); rot.x += 0.22 * open; rot.z += 0.25 * sin(u * PI)
	# steam out of both vents as the valve opens (it scalds anyone at your side: RealmKit.vent)
	if u > 0.12 and u < 0.46 and rm.fx != null:
		var gx: Transform3D = (rig.root as Node3D).global_transform
		for v: Vector3 in RaceArt.DW_VENTS:
			if randf() < dt * 50.0: var side := (gx.basis * Vector3(signf(v.x), 0.35, 0.1)).normalized(); rm.fx.glow(gx * v, side * randf_range(1.5, 3.0), 0.45, 0.02, 0.16, Color(0.9, 0.96, 1.0, 0.55), -0.4, 2.0)
	return [at, rot]

## the greatsword in your right hand, held up before you, the chain axe reversed in your left, the chain between them.
## Its three blows: from up on the right down across to the left; from down on the left up to the right; raised over
## your head and swept flat across, its crescent of red flying on. The fuller fills with crimson as the bloodlust
## stacks (its three steps), a red haze off the blade at three. Thrown, the axe leaves your hand and its chain runs out
const OR_IDLE := [Vector3(0.27, -0.31, -0.4), Vector3(1.0, 0.28, -0.22)]
const OR_AXE_IDLE := [Vector3(-0.25, -0.27, -0.42), Vector3(0.2, -0.35, 0.55)]
func _orc(rig: Dictionary, f: Realm.Fighter, dt: float, t: float, mv: float, bob: float) -> void:
	var sw: Node3D = rig.sword; var ax: Node3D = rig.axe
	var sway := Vector3(sin(rm.player.step_phase) * 0.012 * mv, bob + rm.player.land_dip * 0.4 + sin(t * 1.3) * 0.004, 0.0)
	var p: Vector3 = OR_IDLE[0]; var r: Vector3 = OR_IDLE[1]
	if f.swing_t > 0.0 and f.swing_len > 0.0:
		var u := 1.0 - f.swing_t / f.swing_len; var go := smoothstep(0.06, 0.4, u); var back := smoothstep(0.55, 1.0, u)
		var keys: Array
		match f.combo:
			0: keys = [Vector3(0.36, -0.08, -0.34), Vector3(1.45, 0.75, -1.0), Vector3(-0.3, -0.4, -0.44), Vector3(0.15, -1.0, 0.75)]
			1: keys = [Vector3(-0.28, -0.4, -0.4), Vector3(0.25, -1.0, 1.0), Vector3(0.34, -0.06, -0.38), Vector3(1.5, 0.9, -0.55)]
			_:
				var lift := smoothstep(0.0, 0.22, u)
				keys = [Vector3(0.42, -0.16, -0.3).lerp(Vector3(0.1, 0.08, -0.18), lift * (1.0 - go)), Vector3(0.05, 1.3, -1.45).lerp(Vector3(2.3, 0.0, 0.0), lift * (1.0 - go)), Vector3(-0.32, -0.2, -0.42), Vector3(0.05, -1.25, -1.45)]
		var a: Vector3 = (keys[0] as Vector3).lerp(keys[2], go); var b: Vector3 = (keys[1] as Vector3).lerp(keys[3], go)
		p = a.lerp(OR_IDLE[0], back); r = b.lerp(OR_IDLE[1], back)
	if f.cast_t > 0.0: var c := clampf(f.cast_t / 0.6, 0.0, 1.0); p = p.lerp(Vector3(0.16, -0.12, -0.36), c); r = r.lerp(Vector3(1.45, 0.2, -0.2), c)   # (the rage: the sword raised high)
	if f.stun_t > 0.05: p += Vector3(0, -0.06, 0.04); r.x -= 0.3
	sw.position = p + sway; sw.rotation = r
	# the fuller: crimson filling as the bloodlust stacks; at three a red haze off the blade (the magma sword: lava, always full)
	var magma := RaidLoot.skin_of("orc") != ""
	var want := 1.0 if magma else float(f.stacks) / float(Races.LUST.max)
	var fl := move_toward(float(_rt.get("or_fill", 0.0)), want, dt * 1.6); _rt["or_fill"] = fl
	(rig.mat as ShaderMaterial).set_shader_parameter("fill", fl)
	RaceArt.set_glow(rig.mat, 7, Color(RaceArt.SKIN_PAL.orc.glow) if magma else Color(RaceArt.PAL.orc.glow), 3.2 + (1.5 if f.stacks >= int(Races.LUST.max) else 0.0) * (0.7 + 0.3 * sin(t * 9.0)))
	if (f.stacks >= int(Races.LUST.max) or magma) and rm.fx != null and randf() < dt * 30.0:
		var q := randf_range(0.15, 0.95); var at := sw.global_transform * Vector3(randf_range(-0.04, 0.08), 0, -0.09 - q * RaceArt.OR_LEN)
		rm.fx.glow(at, Vector3(0, randf_range(0.2, 0.5), 0), 0.6, 0.03, 0.09, Color(1.0, 0.12, 0.08, 0.35) if not magma else Color(1.0, 0.4, 0.08, 0.4), -0.3, 1.0)
	# the axe in your left hand, or out on its chain
	var out := false
	for s: Dictionary in rm.kit.shots:
		if s.kind == "axe" and s.get("by") == f: out = true; break
	var ap: Vector3 = OR_AXE_IDLE[0]; var ar: Vector3 = OR_AXE_IDLE[1]
	if out: ap = Vector3(-0.16, -0.18, -0.5); ar = Vector3(1.2, -0.2, 0.3)
	elif f.alt_cd > float(Races.SWORD.axe_cd) - 0.35: var k := (f.alt_cd - (float(Races.SWORD.axe_cd) - 0.35)) / 0.35; ap = ap.lerp(Vector3(-0.1, -0.12, -0.5), k); ar = ar.lerp(Vector3(1.6, 0.0, 0.2), k)   # (the throw)
	if f.swing_t > 0.0: ap += Vector3(-0.03, -0.03, 0.03)
	ax.position = ap + sway * 0.7; ax.rotation = ar
	(rig.axe_mesh as Node3D).visible = not out
	# the chain: from the pommel, sagging, to the axe's haft (or to your fist, the axe gone out on it)
	var a0 := sw.transform * RaceArt.OR_POMMEL; var a1 := ax.transform * (RaceArt.OR_AXE_TOP if not out else Vector3(0, 0.22, 0))
	var mm: MultiMesh = (rig.chain as MultiMeshInstance3D).multimesh; var n := mm.instance_count
	var mid := (a0 + a1) * 0.5 + Vector3(0, -0.12 - 0.05 * sin(t * 2.0), 0.02)
	var prev := a0
	for i in n:
		var u2 := (i + 0.5) / n; var q := a0.lerp(mid, u2).lerp(mid.lerp(a1, u2), u2)
		var u3 := (i + 1.0) / n; var q2 := a0.lerp(mid, u3).lerp(mid.lerp(a1, u3), u3)
		var d := (q2 - prev); if d.length() < 0.0001: d = Vector3.FORWARD
		var z := -d.normalized(); var x := Vector3.UP.cross(z)
		if x.length() < 0.01: x = Vector3.RIGHT
		x = x.normalized(); var y := z.cross(x)
		var bas := Basis(x, y, z) * Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)); var len := d.length() / 0.026
		mm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(1, 1, clampf(len, 0.6, 1.4))), q)); prev = q2
		if i == 0: rig["chain_ends"] = [q, q, q]
		elif i == n - 1: (rig.chain_ends as Array)[1] = q
		elif i == n / 2: (rig.chain_ends as Array)[2] = q   # (its first link, its last, the one in its middle: the checks read them)

## the hellfire staff in your right hand, its head up before you: flicked forward with each ember; its core grows and
## turns faster as it heats and the horns open wider; past 80% white-hot, spitting black ash; at 100% sealed: the horns
## shut on the core, the chain bites, the red rune lock about it. Your left hand comes up open to pour out the beam
func _demon(rig: Dictionary, f: Realm.Fighter, dt: float, t: float, mv: float, bob: float) -> Array:
	var W := Races.STAFF; var h := clampf(f.heat / 100.0, 0.0, 1.0); var crit := f.heat >= float(W.crit); var sealed := f.seal_t > 0.0
	var at := Vector3(0.25 * hip + sin(rm.player.step_phase) * 0.01 * mv, -0.34 + bob + rm.player.land_dip * 0.4, -0.37 - kick * 0.05); var rot := Vector3(1.0 - kick * 0.14, 0.1, -0.24)
	if sealed: var sl := clampf(f.seal_t / float(W.seal), 0.0, 1.0); at += Vector3(0.02, -0.06, 0.03) * minf(1.0, sl * 4.0); rot.z -= 0.3 * minf(1.0, sl * 4.0)
	if f.beam_on: at += Vector3(-0.03, 0.02, -0.02); rot.x -= 0.1
	# the core: its size and its turning are the heat; irregular as it fires; white-hot past the critical line
	var spin := float(_rt.get("dm_spin", 0.0)) + dt * (1.0 + 9.0 * h) * (0.0 if sealed else 1.0); _rt["dm_spin"] = spin
	var jit := (sin(t * 37.0) * 0.5 + sin(t * 23.0) * 0.5) * maxf(0.0, 1.0 - f.fired_t / 0.25) * 0.18
	var core: Node3D = rig.core; core.rotation = Vector3(0, 0, spin); core.scale = Vector3.ONE * ((0.7 + 0.55 * h + jit + (0.25 + 0.08 * sin(t * 20.0) if crit else 0.0)) * (0.55 if sealed else 1.0))
	var hot: Color = Color(RaceArt.PAL.demon.white) if crit else Color(RaceArt.PAL.demon.lava)
	var flick := 0.75 + 0.25 * sin(t * 13.0 + sin(t * 5.0) * 2.0)
	RaceArt.set_glow(rig.mat, 3, hot, (2.5 + 4.0 * h + (4.0 if crit else 0.0)) * (0.4 if sealed else 1.0))
	RaceArt.set_glow(rig.mat, 1, hot if crit else Color(RaceArt.PAL.demon.lava), (0.6 + 3.2 * h) * flick)
	RaceArt.set_glow(rig.mat, 2, Color(RaceArt.PAL.demon.hot), 0.4 + 3.5 * h + (2.0 if sealed else 0.0))
	var cor: Node3D = rig.corona; cor.scale = Vector3.ONE * (0.6 + 0.8 * h + (0.6 if crit else 0.0)) * (0.4 if sealed else 1.0)
	if crit and not sealed and rm.fx != null and randf() < dt * 25.0:   # (black ash off it)
		var cw := core.global_position; rm.fx.glow(cw, Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 0.9), randf_range(-0.3, 0.3)), 0.6, 0.012, 0.03, Color(0.05, 0.03, 0.04, 0.85), -0.5, 1.0)
	# the horns: wider with the heat; shut on the seal
	var open := lerpf(0.0, 0.32, h) - (0.42 if sealed else 0.0)
	var o := lerpf(float(_rt.get("dm_open", 0.0)), open, minf(1.0, dt * 10.0)); _rt["dm_open"] = o
	for hn: Node3D in rig.horns: hn.rotation.x = o
	# the chain bites as it heats (tighter, glowing), the lock while it is sealed
	var ch: Node3D = rig.chain; var tight := 1.0 - 0.1 * h - (0.12 if sealed else 0.0); ch.scale = Vector3(tight, tight, 1.0)
	var lock: Node3D = rig.lock; lock.visible = sealed
	if sealed: lock.rotation.z = t * 1.6; lock.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 12.0))
	# your left hand, open, up to pour the beam
	var lh: Node3D = rig.lhand; lh.visible = f.beam_on
	if f.beam_on: lh.position = Vector3(-0.16, 0.06, -0.28); lh.rotation = Vector3(-0.3, 0.5, 0.2)
	return [at, rot]

## where your weapon's mouth is seen (what you fire is drawn coming out of it); anyone else's: where his shots start
func view_muzzle(f: Realm.Fighter) -> Vector3:
	if f.me and models.has(f.race) and is_instance_valid(models[f.race]) and (models[f.race] as Node3D).is_visible_in_tree():
		if rigs[f.race].has("tip_node"): return (rigs[f.race].tip_node as Node3D).global_position
		return (models[f.race] as Node3D).global_transform * (rigs[f.race].tip as Vector3)
	return rm.kit.muzzle(f) + f.aim * 0.6

# ---------------- what flies ----------------
func shot(s: Dictionary) -> Dictionary:
	var size := Vector3(0.04, 0.04, 0.8); var col := Color(0.56, 0.97, 0.92, 0.95); var key: String = s.kind
	match s.kind:
		"big": size = Vector3(0.07, 0.07, 1.3); col = Color(0.8, 0.62, 1.0, 1.0)
		"ember":
			size = Vector3(0.13, 0.13, 0.3); col = Color(1.0, 0.25, 0.08, 1.0) if s.get("hot", false) else Color(1.0, 0.6, 0.2, 0.95); key = "ember_hot" if s.get("hot", false) else "ember"
			if s.get("over", false): size = Vector3(0.17, 0.17, 0.42); col = Color(0.75, 0.05, 0.1, 1.0); key = "ember_over"   # (the eclipse overload's: deep red, longer)
		"gren": size = Vector3(0.22, 0.22, 0.22); col = Color(0.3, 0.9, 0.75, 1.0)
		"flask": size = Vector3(0.18, 0.24, 0.18); col = {"oil": Color(0.2, 0.55, 0.5, 1.0), "gravity": Color(0.45, 0.2, 0.8, 1.0), "smoke": Color(0.7, 0.5, 1.0, 1.0)}[s.bomb]; key = "flask_" + str(s.bomb)
		"wave":
			size = Vector3(2.6, 0.1, 0.5); col = Color(1.0, 0.16, 0.12, 0.8)
			if s.get("skin", false): col = Color(0.06, 0.01, 0.03, 0.92); key = "wave_skin"   # (the magma sword's: a black eclipse with lava along it)
		"axe": size = Vector3(0.5, 0.08, 0.4); col = Color(0.8, 0.84, 0.9, 1.0)
		"bolt": size = Vector3(0.09, 0.09, 0.5); col = Color(0.75, 0.9, 1.0, 1.0)
	if s.has("size"): size = s.size   # (6-A's demons' missiles: each its own size and colour)
	if s.has("col"): col = s.col
	if rm.en == null: return s
	var m: Node3D
	if s.kind == "flask" and not s.has("size"):   # (the bomb itself, flying: RaceArt's)
		var b: Dictionary = RaceArt.bomb(str(s.bomb)); m = b.root; (b.root as Node3D).scale = Vector3.ONE * 1.6; _root().add_child(m); s.bomb_rig = b
	elif s.kind == "axe" and not s.has("size"):   # (the chain axe, spinning out)
		m = Node3D.new(); _root().add_child(m)
		var ax := MeshInstance3D.new(); ax.mesh = RaceArt.built("or_axe", func(k: ArtKit) -> void: RaceArt.axe_body(k, RaceArt.pal("orc"))); ax.material_override = _axe_mat(); ax.position = Vector3(0, -0.18, 0); ax.scale = Vector3.ONE * 1.5; m.add_child(ax)
	else: m = _mi(_box("shot_" + str(s.kind), size), _unlit("shot_" + key, col, s.kind != "axe" and s.kind != "flask" and s.kind != "gren"))
	m.position = s.pos; s.node = m; s.age = 0.0
	var by: Realm.Fighter = s.by
	if by != null and by.me and s.kind != "wave": s.vis = view_muzzle(by) - (s.pos as Vector3)   # (yours: drawn from your weapon's mouth, closing on the line you aim along)
	return s

var _axe_m: ShaderMaterial = null
func _axe_mat() -> ShaderMaterial:
	if _axe_m == null: _axe_m = RaceArt.mat(false, {1: [Color(RaceArt.PAL.orc.glow), 2.4]})
	return _axe_m

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
				"wave":
					rm.fx.glow(p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.8, Vector3.ZERO, 0.2, 0.25, 0.04, Color(1.0, 0.45, 0.08, 0.85) if s.get("skin", false) else Color(1.0, 0.12, 0.1, 0.6))
					if s.get("skin", false): rm.fx.glow(p + Vector3(randf_range(-1.3, 1.3), randf_range(-0.1, 0.2), 0), Vector3(0, 1.2, 0), 0.35, 0.2, 0.05, Color(1.0, 0.3, 0.05, 0.8))
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
	if f.me: kick = 1.6 if all_close else 1.1; _rt["dw_heat"] = minf(1.0, float(_rt.get("dw_heat", 0.0)) + 0.75); _rt["dw_fired"] = 0.0
	if rm.fx == null: return
	var o := view_muzzle(f); var up := Vector3.UP if absf(f.aim.y) < 0.95 else Vector3.RIGHT; var x := f.aim.cross(up).normalized(); var y := x.cross(f.aim); var sz := 0.35 if f.me else 1.0
	var furnace := rm.kit.mine(f) and RaidLoot.skin_of("dwarf") != ""   # (the abyss furnace skin: red sulphur smoke and sparks for the white steam)
	for i in 10: var a := i * TAU / 10.0; rm.fx.glow(o + f.aim * 0.15, f.aim * 5.0 + (x * cos(a) + y * sin(a)) * 2.2, 0.35, 0.16 * sz, 0.5 * sz, Color(0.75, 0.18, 0.08, 0.55) if furnace else Color(0.95, 0.98, 1.0, 0.45), 0.0, 3.0)   # (the vortex ring)
	if furnace: rm.fx.sparks(o + f.aim * 0.3, 6, [1.0, 0.55, 0.15], 4.0)
	for i in ends.size():
		var e: Vector3 = ends[i]
		if i % 2 == 0: rm.fx.streak(o, e, Color(1.0, 0.85, 0.6, 0.5), 0.02, 0.06)
		if i % 3 == 0: rm.fx.sparks(e, 2, [1.0, 0.8, 0.5], 2.5)

## the corrupted starlight crossbow's glance: a violet crack across the air from a to b, stars along it
func constellation(a: Vector3, b: Vector3) -> void:
	if rm.fx == null: return
	rm.fx.streak(a, b, Color(0.7, 0.35, 1.0, 0.85), 0.03, 1.2)
	var n := clampi(int(a.distance_to(b) / 1.5), 2, 14)
	for k in n: rm.fx.glow(a.lerp(b, (k + randf()) / n) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)), Vector3.ZERO, 1.2, 0.1, 0.06, Color(0.85, 0.65, 1.0, 0.95))

func steam(at: Vector3, r: float, by: Realm.Fighter = null) -> void:
	if rm.fx == null: return
	var furnace := by != null and rm.kit.mine(by) and RaidLoot.skin_of("dwarf") != ""
	for i in 12: var a := i * TAU / 12.0; rm.fx.glow(at, Vector3(cos(a), 0.25, sin(a)) * r * 2.2, 0.5, 0.3, 0.9, Color(0.75, 0.18, 0.08, 0.55) if furnace else Color(0.95, 0.98, 1.0, 0.45), 0.0, 2.5)
	if furnace: rm.fx.sparks(at + Vector3(0, 0.4, 0), 8, [1.0, 0.55, 0.15], 3.5)

func swing(f: Realm.Fighter, kind: String, i: int) -> void:
	if f.me: swing_kind = kind; swing_i = i; swing_len = 0.32; swing_t = 0.32

## the eclipse core's overload starting (on) or ending: a dark burst of fire about the staff; yours, a red edge on the view
func overload(f: Realm.Fighter, on: bool) -> void:
	if f.me: rm.flash["overload"] = 0.35 if on else 0.15
	if rm.fx == null: return
	var at := rm.kit.muzzle(f) + f.aim * 0.4
	for i in (18 if on else 8): rm.fx.glow(at, Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized() * 3.0, 0.35, 0.3, 0.05, Color(0.9, 0.15, 0.05, 0.9) if i % 3 else Color(0.05, 0.02, 0.04, 0.95), 2.0, 3.0)

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

## someone falls: no body left lying; each people goes its own way (felled by you in the eclipse elimination's look: a
## small black sun over his head half a second, then it bursts, and he goes as a demon goes, as ash into a crack)
func fell(v: Realm.Fighter, _by, _o: Dictionary) -> void:
	var ecl: bool = _by is Realm.Fighter and (_by as Realm.Fighter).me and RaidLoot.wearing("vfx_eclipse")
	if ecl: _eclipse_pop(v)
	if rm.mode.fell(v): return   # (6-A's demons go their own way)
	var fx := rm.fx; var c := v.feet_mid(); var top := v.pos + Vector3(0, v.H, 0)
	Snd.play("rm_die_" + v.race, 1.0, null if v.me else c)
	if fx == null: return
	var style: String = "demon" if ecl else v.race
	match style:
		"elf":   # silver drops of light and leaves, rising
			for i in 26: fx.glow(v.pos + Vector3(randf_range(-0.35, 0.35), randf_range(0.1, v.H), randf_range(-0.35, 0.35)), Vector3(randf_range(-0.3, 0.3), randf_range(1.0, 2.6), randf_range(-0.3, 0.3)), randf_range(0.8, 1.5), 0.14, 0.02, Color(0.9, 0.97, 1.0, 0.85) if i % 3 > 0 else Color(0.35, 0.8, 0.5, 0.9))
		"dwarf":   # the rune armour comes apart; the pack lets out its last steam
			fx.chunks(c, 10, 0.16, "metal"); fx.puff(c + Vector3(0, 0.3, 0), 10, 0.95, 0.8)
		"orc":   # a burst of red; only the sword is left, stuck in the ground
			for i in 30: fx.glow(c, Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(2.0, 6.0), randf_range(0.5, 0.9), 0.4, 0.08, Color(0.8, 0.08, 0.08, 0.8), 1.0, 3.0)
			if rm.en != null:
				var s := Node3D.new(); _root().add_child(s); s.position = v.pos + Vector3(0, 0.25, 0); s.rotation = Vector3(0.18, randf() * TAU, 0.1)
				var sm := MeshInstance3D.new(); sm.mesh = RaceArt.built("orc_sword_left", func(k: ArtKit) -> void: RaceArt.sword_left(k)); sm.material_override = RaceArt.body_mat(); s.add_child(sm)
				_ghosts.push_back({"n": s, "t": 4.0})
		"demon":   # black ash and embers, drawn down into a crack in the ground
			for i in 28: fx.glow(v.pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, v.H), randf_range(-0.5, 0.5)), Vector3(0, randf_range(-3.5, -1.5), 0), randf_range(0.5, 0.9), 0.16, 0.03, Color(0.06, 0.03, 0.05, 0.95) if i % 4 > 0 else Color(1.0, 0.4, 0.1, 0.9))
			if rm.en != null:
				var d := _flat(0.9, "rift", Color(0.05, 0.0, 0.08, 0.9)); d.position = v.pos + Vector3(0, 0.05, 0); _ghosts.push_back({"n": d, "t": 0.9, "shrink": true})
	if top.y > 0.0 and v.me and rm.player != null: rm.player.shake = maxf(rm.player.shake, 0.4)

func _eclipse_pop(v: Realm.Fighter) -> void:
	if rm.en == null: return
	var at := v.pos + Vector3(0, v.H + 0.55, 0)
	var sun := _ball(0.22, "ecl_sun", Color(0.02, 0.0, 0.02, 1.0)); sun.position = at
	var ring := _ball(0.3, "ecl_ring", Color(1.0, 0.45, 0.1, 0.6)); ring.scale = Vector3(0.36, 0.05, 0.36); sun.add_child(ring); ring.scale = Vector3(1.5, 0.22, 1.5)
	_ghosts.push_back({"n": sun, "t": 0.5, "pop": at})

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
		if q.has("pop"): (q.n as Node3D).rotation.y += dt * 6.0; (q.n as Node3D).scale = Vector3.ONE * 0.22 * (1.0 + 0.4 * (0.5 - float(q.t)))
		if float(q.t) <= 0.0:
			if q.has("pop") and rm.fx != null:   # (the black sun bursts)
				var p: Vector3 = q.pop; Snd.play("rd_eclipse_pop", 0.9, p)
				for k in 22: rm.fx.glow(p, Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 3.2, 0.45, 0.18, 0.04, Color(0.04, 0.01, 0.04, 0.95) if k % 2 else Color(1.0, 0.45, 0.1, 0.9), 1.0, 3.0)
			(q.n as Node).queue_free(); _ghosts.remove_at(i)
	# the demon's beam
	for f: Realm.Fighter in rm.all:
		if f.alive and f.beam_on and rm.fx != null: rm.fx.streak(view_muzzle(f), f.beam_end, Color(0.75, 0.1, 0.45, 0.6), 0.035 if f.me else 0.06, 0.05)
