class_name Hellfolk
extends RefCounted
## 6-B's demons, for one who comes with guns (the solo fight on the obsidian altar). They stand where the caldera puts
## them (Caldera.posts) and fight from there, none of them walking the whole map after you; their shots, lines and
## burning seals fly as Folk's do (fk):
##   흑요석 임프 (dm_imp)        small and quick on bat's wings: it circles over its post, then darts about you, fire bolts
##                               two at a time
##   악마 경비병 (dm_guard)      a fire halberd: a sweep close by that throws you back, a burning spear thrown from afar
##   혈월 주술사 (dm_adept)      a staff of hellfire: a burning seal drawn under you that bursts a moment later, a slow ember
##                               that follows you; come too close and it steps away in a burst of flame
##   유황 저격병 (dm_sniper)     up on the gallery and the spires: a red line on you while it aims, then a brimstone lance
##                               that knocks you back
##   사슬 감시자 (dm_warden)     the elite: heavy plates of obsidian (a shot to the body does three quarters), a hook on a
##                               chain that drags you in to it, then the slam of its mace
##   심연의 고문관 (inquisitor)  the master of the place (see _inquisitor)
## Every kind is the demon body of the art paper (RaceArt.body), at its own size, with its own arms and gear.

## each kind's size (the body is 2.1 m at 1) and what it carries
const LOOK := {"dm_imp": {"s": 0.58, "arm": "claws"}, "dm_guard": {"s": 1.06, "arm": "halberd"}, "dm_adept": {"s": 1.0, "arm": "staff"},
	"dm_sniper": {"s": 1.0, "arm": "lance"}, "dm_warden": {"s": 1.38, "arm": "mace"}, "inquisitor": {"s": 1.34, "arm": "brand"}}
const IMP := {"speed": 42.0, "dmg": 7.0, "cd": [2.4, 3.2], "leash": 30.0, "ring": [7.0, 12.0], "high": [2.0, 3.8], "range": 34.0, "hang": 0.9}
const HALBERD := {"dmg": 34.0, "reach": 2.9, "wind": 0.45, "cd": 1.5, "shove": 4.5, "leash": 12.0}
const SPEAR := {"speed": 34.0, "dmg": 26.0, "cd": [3.6, 5.0], "near": 7.0, "far": 36.0, "burn": 3.0, "grav": 6.0, "wind": 0.5}
const SEAL := {"r": 2.4, "fuse": 1.2, "dmg": 40.0, "cd": [6.0, 8.0], "burn": 3.0, "range": 32.0}
const EMBER := {"speed": 11.0, "dmg": 28.0, "cd": [4.5, 6.0], "burn": 3.0, "range": 40.0}
const LANCE := {"speed": 125.0, "dmg": 50.0, "aim": 1.8, "rest": 3.6, "shove": 4.0, "near": 9.0, "quick": 1.0, "near_dmg": 30.0}
const HOOK := {"near": 7.0, "far": 26.0, "warn": 0.75, "speed": 38.0, "dmg": 30.0, "pull": 15.0, "cd": [7.0, 9.0], "leash": 16.0}
const SLAM := {"dmg": 55.0, "r": 4.0, "wind": 0.7, "cd": 2.6, "shove": 6.0}
const ARMOUR := 0.75   # what a warden's plates let through of a shot to the body
## the inquisitor: three parts by his health; his numbers
const INQ := {"p2": 0.6, "p3": 0.3, "act": [3.2, 2.6, 2.0], "lance": 40.0, "lance_aim": 0.8, "lance_speed": 120.0, "brand": 50.0, "brand_fuse": 1.3, "brand_r": 2.6,
	"fan_n": 7, "fan_arc": 0.11, "fan_dmg": 16.0, "fan_speed": 34.0, "fan_waves": 3, "port": [0.0, 8.0, 0.0], "imps": [2, 3, 2], "call": [22.0, 20.0, 15.0],
	"sweep_r": 5.0, "sweep_dmg": 45.0, "sweep_cd": 3.0, "hold": 10.0, "rage": 1.4, "rouse": 26.0}
const C_FIRE := Color(1.0, 0.5, 0.12, 0.95); const C_LANCE := Color(1.0, 0.28, 0.1, 0.95); const C_SEAL := Color(1.0, 0.25, 0.12, 0.9); const C_AIM := Color(1.0, 0.12, 0.08, 0.7)

var fk: Folk
var altar: Caldera = null
var boss: Enemies.Foe = null
var clock := 0.0   # (their own time: the imps' circling, their bobbing)

func clear() -> void: boss = null
func tick(dt: float) -> void: clock += dt

static func size_of(type: String) -> float: return float((LOOK.get(type, {"s": 1.0}) as Dictionary).s)

# ---------------- how they look ----------------
func _mesh(key: String, make: Callable) -> ArrayMesh: return RaceArt.built("hf_" + key, make, 0.62)
func _piece(parent: Node3D, mesh: ArrayMesh, at := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = RaceArt.body_mat(); mi.position = at; mi.rotation = rot; mi.set_meta("body", true); parent.add_child(mi)
	return mi

func build(e: Enemies.Foe, type: String, opts: Dictionary) -> void:
	var en := fk.en; var L: Dictionary = LOOK[type]; var B := RaceArt.body("demon", "them"); var P := RaceArt.pal("demon")
	e.folk = true; e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; en.add_child(e.g)
	var hip: float = B.hip; var lx: float = B.leg_x; var sho: Vector2 = B.sho
	var oy := -1.15 if type == "dm_imp" else 0.0   # (a flier's place is its middle, as the drones': its body hangs round it)
	e.leg_l = Node3D.new(); e.leg_l.position = Vector3(-lx, hip + oy, 0); e.g.add_child(e.leg_l); _piece(e.leg_l, B.leg)
	e.leg_r = Node3D.new(); e.leg_r.position = Vector3(lx, hip + oy, 0); e.g.add_child(e.leg_r); _piece(e.leg_r, B.leg)
	e.upper = Node3D.new(); e.upper.position = Vector3(0, hip + oy, 0); e.g.add_child(e.upper); _piece(e.upper, B.up)
	e.arm_l = Node3D.new(); e.arm_l.position = Vector3(-sho.x, sho.y, 0); e.upper.add_child(e.arm_l); _piece(e.arm_l, B.al)
	e.arm_r = Node3D.new(); e.arm_r.position = Vector3(sho.x, sho.y, 0); e.upper.add_child(e.arm_r)
	var arm: String = L.arm
	_piece(e.arm_r, B.ar if arm == "staff" or arm == "brand" else _mesh("ar_bare", func(k: ArtKit) -> void: _bare_right(k, P)))
	var wa: Vector3 = B.wing_at; var big_wings := type == "dm_imp" or type == "inquisitor"
	var wl := Node3D.new(); wl.position = Vector3(-wa.x, wa.y, wa.z); e.upper.add_child(wl); _piece(wl, B.wing_l, Vector3.ZERO).scale = Vector3.ONE * (1.5 if big_wings else 1.0)
	var wr := Node3D.new(); wr.position = wa; e.upper.add_child(wr); _piece(wr, B.wing, Vector3.ZERO).scale = Vector3.ONE * (1.5 if big_wings else 1.0)
	_piece(e.upper, B.tail, B.tail_at)
	# what each carries, and what it wears over the body
	var hand := Vector3(0, -0.6, 0.04)
	match arm:
		"halberd": _piece(e.arm_r, _mesh("halberd", func(k: ArtKit) -> void: _halberd(k)), hand); _piece(e.upper, _mesh("guard_plate", func(k: ArtKit) -> void: _plates(k, false)))
		"lance": _piece(e.arm_r, _mesh("lance", func(k: ArtKit) -> void: _lance(k)), hand); _piece(e.upper, _mesh("hood", func(k: ArtKit) -> void: _hood(k)))
		"mace":
			_piece(e.arm_r, _mesh("mace", func(k: ArtKit) -> void: _mace(k)), hand); _piece(e.arm_l, _mesh("hook", func(k: ArtKit) -> void: _hook(k)), hand)
			_piece(e.upper, _mesh("warden_plate", func(k: ArtKit) -> void: _plates(k, true)))
		"staff": _piece(e.upper, _mesh("sigil", func(k: ArtKit) -> void: _sigil(k)))
		"brand":
			_piece(e.upper, _mesh("crown", func(k: ArtKit) -> void: _crown(k))); _piece(e.upper, _mesh("robe", func(k: ArtKit) -> void: _robe(k)))
			_piece(e.arm_l, _mesh("censer", func(k: ArtKit) -> void: _censer(k)), hand)
	var S := 1.0   # (the parts are in the body's own measure: Enemies scales them by e.scale)
	e.parts = [_part(Vector3(0, 1.67 * S, 0.03 * S), 0.13 * S, 1.0, true), _part(Vector3(0, 1.37 * S, 0.02 * S), 0.25 * S, ARMOUR if arm == "mace" else 1.0),
		_part(Vector3(0, 1.05 * S, 0), 0.2 * S, 0.9 * (ARMOUR if arm == "mace" else 1.0)), _part(Vector3(0, 0.5 * S, 0), 0.22 * S, 0.7)]
	if arm == "brand": e.parts.push_back(_part(Vector3(0, 0.75, 0.02), 0.32, 0.8))   # (the robe: it is hit where it hangs)
	e.muzzle = Vector3(sho.x, 1.48, 0.62); e.eye_h = 1.7
	if arm == "staff" or arm == "brand": e.muzzle = Vector3(sho.x, 1.9, 0.45)
	elif arm == "lance": e.muzzle = Vector3(sho.x, 1.5, 1.3)
	elif arm == "claws": e.muzzle = Vector3(0, 1.4, 0.4)
	if oy != 0.0:
		for q: Dictionary in e.parts: q.o = (q.o as Vector3) + Vector3(0, oy, 0)
		e.muzzle.y += oy; e.eye_h += oy
	e.bar = Node3D.new(); e.bar.visible = false; en.add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.7, 0.07, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = en._bar_mesh; e.fill.material_override = en._bar_fill; e.fill.scale = Vector3(0.66, 0.045, 1); e.bar.add_child(e.fill)
	var Pp: Dictionary = opts.get("post", {}); var fly := bool(Pp.get("fly", false)) or type == "dm_imp"
	e.fly = fly
	e.k = {"dm": true, "post": Vector3(float(Pp.get("x", 0.0)), float(Pp.get("y", 0.0)), float(Pp.get("z", 0.0))), "perch": bool(Pp.get("perch", false)), "fly": fly,
		"cd": randf_range(0.8, 2.0), "cd2": randf_range(1.5, 3.5), "aim": 0.0, "wind": 0.0, "act": 2.0, "phase": 1, "port": 6.0, "call": 14.0, "side": 1.0 if randf() < 0.5 else -1.0, "side_t": randf_range(1.0, 2.5),
		"seen_t": 0.0, "dart": randf() * TAU, "dart_t": 0.0, "burst": 0, "burst_t": 0.0, "blink": randf_range(3.0, 6.0), "wings": [wl, wr], "ph": randf() * TAU, "down": false, "sweep": 0.0, "fan": 0}

static func _part(o: Vector3, r: float, mult := 1.0, weak := false) -> Dictionary: return {"o": o, "r": r, "mult": mult, "weak": weak, "bomb": false}

## a right arm with nothing in its hand (the left arm, mirrored in its corners)
static func _bare_right(k: ArtKit, P: Dictionary) -> void:
	k.push(Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)); RaceArt._demon_arm(k, false, P); k.pop()
## a fire halberd: a black shaft, a crescent axe-head with a burning edge, a spike (built along -z, as carried)
static func _halberd(k: ArtKit) -> void:
	RaceArt._in_hand(k, Vector3.ZERO)
	k.paint("231a20", 0.3, 0.3, ArtKit.OBSIDIAN, 3, 0.0); k.tube(PackedVector3Array([Vector3(0, 0, 0.55), Vector3(0, 0, -1.55)]), 0.022, 6)
	k.paint("3a3c40", 0.9, 0.4, ArtKit.IRON); k.at(Vector3(0, 0, -1.55)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.extrude(ArtKit.crescent(0.2, 0.32, 0.05), 0.012, 0.004, 1); k.pop(); k.pop()
	k.paint("ff6a1a", 0.0, 0.5, ArtKit.PLAIN, 3, 1.0); k.at(Vector3(0, 0.0, -1.55)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, 0))); k.relief(PackedVector2Array([Vector2(-0.18, 0.28), Vector2(-0.3, 0.1), Vector2(-0.32, -0.08), Vector2(-0.2, -0.28)]), 0.012, 0.014, 4); k.pop(); k.pop()
	k.paint("3a3c40", 0.9, 0.4, ArtKit.IRON); k.tube(PackedVector3Array([Vector3(0, 0, -1.6), Vector3(0, 0, -2.0)]), PackedFloat32Array([0.03, 0.002]), 6)
	k.pop()
## a brimstone lance-thrower: a long barrel of iron bound in obsidian, lava glowing through slits along it
static func _lance(k: ArtKit) -> void:
	RaceArt._in_hand(k, Vector3.ZERO)
	k.paint("3a3c40", 0.9, 0.45, ArtKit.IRON); k.tube(PackedVector3Array([Vector3(0, 0.02, 0.25), Vector3(0, 0.02, -1.25)]), 0.045, 8)
	k.paint("231a20", 0.3, 0.2, ArtKit.OBSIDIAN, 3, 0.0)
	for i in 4: k.at(Vector3(0, 0.02, -0.1 - i * 0.32)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.cyl(0.065, 0.065, 0.12, 8); k.pop(); k.pop()
	k.paint("ff6a1a", 0.0, 0.5, ArtKit.PLAIN, 3, 1.0)
	for i in 3: k.ball(Vector3(0, 0.07, -0.26 - i * 0.32), Vector3(0.012, 0.012, 0.09), 5, 3)
	k.at(Vector3(0, 0.02, -1.25)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(0.05, 0.012, 10, 4); k.pop(); k.pop()
	k.pop()
## a warden's mace: a short haft, a great head of spiked obsidian, lava in its cracks
static func _mace(k: ArtKit) -> void:
	RaceArt._in_hand(k, Vector3.ZERO)
	k.paint("3a3c40", 0.9, 0.45, ArtKit.IRON); k.tube(PackedVector3Array([Vector3(0, 0, 0.15), Vector3(0, 0, -0.62)]), 0.03, 6)
	k.paint("231a20", 0.35, 0.15, ArtKit.OBSIDIAN, 3, 0.0); k.ball(Vector3(0, 0, -0.75), Vector3(0.15, 0.15, 0.18), 10, 6)
	for i in 8:
		var a := i * TAU / 8.0; var d := Vector3(cos(a), sin(a), 0.0)
		k.tube(PackedVector3Array([Vector3(0, 0, -0.75) + d * 0.12, Vector3(0, 0, -0.75) + d * 0.27]), PackedFloat32Array([0.035, 0.002]), 5)
	k.pop()
## a warden's hook: a coil of chain round its left fist, the iron hook hanging from it
static func _hook(k: ArtKit) -> void:
	k.paint("3a3c40", 0.9, 0.45, ArtKit.IRON)
	for i in 3: k.at(Vector3(0, 0.04 - i * 0.05, 0.0)); k.torus(0.075, 0.014, 12, 4); k.pop()
	for i in 4: k.at(Vector3(0.0, -0.12 - i * 0.08, 0.03), Vector3(0, PI / 2.0 * (i % 2), 0)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.link(0.1, 0.06, 0.012, 4); k.pop(); k.pop()
	k.tube(ArtKit.spline([Vector3(0, -0.45, 0.03), Vector3(0, -0.6, 0.03), Vector3(0, -0.66, 0.12), Vector3(0, -0.6, 0.2)], 4), PackedFloat32Array([0.022, 0.022, 0.02, 0.018, 0.016, 0.014, 0.012, 0.01, 0.008, 0.005, 0.003, 0.002, 0.001]), 6)
## plates of obsidian over the chest and shoulders (a warden's heavier, a helm with it)
static func _plates(k: ArtKit, heavy: bool) -> void:
	var w := 1.25 if heavy else 1.0
	k.paint("231a20", 0.4, 0.25, ArtKit.OBSIDIAN, 3, 0.0); k.ball(Vector3(0, 0.42, 0.075), Vector3(0.2, 0.15, 0.08) * w, 12, 6)
	for sx: float in [1.0, -1.0]:
		k.ball(Vector3(sx * 0.23, 0.55, 0.0), Vector3(0.11, 0.06, 0.11) * w, 10, 5)
		if heavy: for i in 3: k.tube(PackedVector3Array([Vector3(sx * (0.26 + i * 0.03), 0.6, -0.04 + i * 0.04), Vector3(sx * (0.33 + i * 0.03), 0.76, -0.04 + i * 0.04)]), PackedFloat32Array([0.022, 0.002]), 5)
	k.paint("ff6a1a", 0.0, 0.5, ArtKit.PLAIN, 3, 0.9); k.ball(Vector3(0, 0.44, 0.16 if heavy else 0.15), Vector3(0.03, 0.03, 0.012), 6, 4)
	if heavy:
		k.paint("231a20", 0.4, 0.25, ArtKit.OBSIDIAN, 3, 0.0); k.ball(Vector3(0, 0.75, 0.02), Vector3(0.1, 0.085, 0.105), 10, 6)
		k.paint("ffd23a", 0.0, 0.4, ArtKit.PLAIN, 6, 1.0); k.ball(Vector3(0, 0.735, 0.12), Vector3(0.05, 0.008, 0.006), 6, 3)
## a sniper's hood and short cape
static func _hood(k: ArtKit) -> void:
	k.paint("2a1418", 0.0, 0.85, ArtKit.CLOTH); k.ball(Vector3(0, 0.73, 0.0), Vector3(0.11, 0.12, 0.12), 10, 6)
	var rows: Array = []
	for j in 5: var u := j / 4.0; rows.push_back(PackedVector3Array([Vector3(-0.2 - u * 0.06, 0.62 - u * 0.5, -0.12 - u * 0.05), Vector3(0, 0.62 - u * 0.52, -0.15 - u * 0.06), Vector3(0.2 + u * 0.06, 0.62 - u * 0.5, -0.12 - u * 0.05)]))
	k.sheet(rows, Vector3(0, 0, -1))
## an adept's blood-moon sigil, burning on its chest
static func _sigil(k: ArtKit) -> void:
	k.paint("ef4444", 0.0, 0.5, ArtKit.PLAIN, 4, 1.0); k.at(Vector3(0, 0.42, 0.145), Vector3(PI / 2.0, 0, 0)); k.torus(0.06, 0.01, 16, 4); k.pop()
	k.ball(Vector3(0.015, 0.42, 0.15), Vector3(0.035, 0.035, 0.006), 8, 4)
## the inquisitor's iron crown of spikes
static func _crown(k: ArtKit) -> void:
	k.paint("3a3c40", 0.9, 0.4, ArtKit.IRON); k.at(Vector3(0, 0.82, 0.02)); k.torus(0.1, 0.016, 16, 4); k.pop()
	for i in 9:
		var a := i * TAU / 9.0; var b := Vector3(cos(a) * 0.1, 0.82, sin(a) * 0.1 + 0.02)
		k.tube(PackedVector3Array([b, b + Vector3(cos(a) * 0.03, 0.12 + 0.05 * (i % 2), sin(a) * 0.03)]), PackedFloat32Array([0.014, 0.001]), 5)
	k.paint("ff2a3a", 0.0, 0.5, ArtKit.PLAIN, 4, 1.0); k.ball(Vector3(0, 0.84, 0.125), Vector3(0.02, 0.02, 0.01), 6, 4)
## the inquisitor's long robe, from the waist to the ankles, slit at the front
static func _robe(k: ArtKit) -> void:
	k.paint("1a0e12", 0.0, 0.85, ArtKit.CLOTH)
	var rows: Array = []
	for j in 6:
		var u := j / 5.0; var row := PackedVector3Array(); var r := lerpf(0.17, 0.34, u); var y := lerpf(0.08, -0.88, u)
		for i in 15: var a := lerpf(PI * 0.6, PI * 2.4, i / 14.0); row.push_back(Vector3(cos(a) * r, y, sin(a) * r * 0.85))
		rows.push_back(row)
	k.grid(rows, false, true, [], PackedFloat32Array(), false)
	k.paint("ff2a3a", 0.0, 0.5, ArtKit.PLAIN, 4, 0.8)
	for i in 7: var a := lerpf(PI * 0.7, PI * 2.3, i / 6.0); k.at(Vector3(cos(a) * 0.34, -0.86, sin(a) * 0.34 * 0.85), Vector3(0, -a + PI / 2.0, 0)); k.rune(480 + i, 0.07, 0.012, 0.004); k.pop()
## the inquisitor's censer: a cage of iron on a chain, embers in it
static func _censer(k: ArtKit) -> void:
	k.paint("3a3c40", 0.9, 0.45, ArtKit.IRON)
	for i in 4: k.at(Vector3(0.0, -0.06 - i * 0.07, 0.03), Vector3(0, PI / 2.0 * (i % 2), 0)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.link(0.09, 0.05, 0.01, 4); k.pop(); k.pop()
	var c := Vector3(0, -0.42, 0.03)
	for i in 6: var a := i * TAU / 6.0; k.tube(ArtKit.spline([c + Vector3(0, 0.08, 0), c + Vector3(cos(a) * 0.07, 0.0, sin(a) * 0.07), c + Vector3(0, -0.08, 0)], 3), 0.006, 4)
	k.paint("ffb347", 0.0, 0.5, ArtKit.PLAIN, 5, 1.0); k.ball(c, Vector3.ONE * 0.04, 8, 5)

# ---------------- seeing ----------------
func sees(e: Enemies.Foe, dist: float) -> bool:
	if not e.los or dist > float(e.T.sight) * (1.3 if e.alert else 1.0): return false
	if altar != null and altar.hides(fk.player, dist): return false
	return true

func on_hurt(e: Enemies.Foe, _dir: Vector3) -> void:
	e.k.seen_t = 2.0
	if e.type == "dm_adept" and float(e.k.blink) <= 2.0: e.k.blink = 0.0
	if e.type == "dm_imp": e.k.dart_t = 0.0   # (struck: off to another place round you)

## a demon falls: embers and ash (and a cry)
func fell(e: Enemies.Foe) -> void:
	Snd.play("rd_fall_big" if e.boss or e.type == "dm_warden" else "rm_die_demon", 1.0, e.pos)
	var fx := fk.fx
	if fx == null: return
	var n := 14 + int(e.H * 5.0)
	for i in n: fx.glow(e.pos + Vector3(randf_range(-e.R, e.R), randf_range(0.2, e.H), randf_range(-e.R, e.R)), Vector3(randf_range(-0.6, 0.6), randf_range(-1.5, 2.0), randf_range(-0.6, 0.6)), randf_range(0.5, 1.0), 0.2 + e.R * 0.15, 0.03, Color(0.06, 0.03, 0.05, 0.95) if i % 2 == 0 else Color(1.0, 0.36, 0.08, 0.9))

# ---------------- their turn ----------------
func update(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float) -> void:
	var k := e.k; var seen := sees(e, dist)
	k.seen_t = maxf(0.0, float(k.seen_t) - dt)
	if seen: k.seen_t = 1.2
	if altar != null and e.hp < e.max_hp and altar.by_briar(e.pos): e.hp = minf(e.max_hp, e.hp + Caldera.BRIAR.heal * dt)   # (the briars feed it)
	_wings(e, dt)
	if not e.alert:
		if (seen and dist < float(e.T.sight)) or dist < 7.0: _wake(e)
		else: _idle(e, dt); return
	match e.type:
		"dm_imp": _imp(e, dt, dist, to, face_yaw, seen)
		"dm_guard": _guard(e, dt, dist, to, face_yaw, seen)
		"dm_adept": _adept(e, dt, dist, to, face_yaw, seen)
		"dm_sniper": _sniper(e, dt, dist, face_yaw, seen)
		"dm_warden": _warden(e, dt, dist, to, face_yaw, seen)
		"inquisitor": _inquisitor(e, dt, dist, to, face_yaw, seen)

func _wake(e: Enemies.Foe) -> void:
	fk.en.alarm(e)
	if e.dist < 30.0: Snd.play("rd_wake", 0.7, e.pos)
	for o in fk.en.list:
		if o != e and o.alive and not o.alert and o.folk and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() < 15.0 and absf(o.pos.y - e.pos.y) < 6.0: fk.en.alarm(o)

func _idle(e: Enemies.Foe, dt: float) -> void:
	if bool(e.k.fly): _hover(e, dt, Vector3(e.k.post) + Vector3(cos(clock * 0.6 + e.sid) * 2.5, 0.4 * sin(clock * 1.3 + e.sid), sin(clock * 0.6 + e.sid) * 2.5), 2.0); fk._pose(e, 0.0, dt, "rest"); return
	if e.idle_t <= 0.0: e.idle_t = randf_range(2.5, 6.0); e.idle_yaw = e.yaw + randf_range(-0.9, 0.9); e.has_idle_yaw = true
	e.idle_t -= dt
	if e.has_idle_yaw: fk.en._turn_toward(e, e.idle_yaw, 1.0, dt)
	fk._pose(e, 0.0, dt, "rest"); fk.en._ground_move(e, 0.0, 0.0, dt)

## the wings: an imp's beat fast, the rest fold them, half open when they leap or fly
func _wings(e: Enemies.Foe, dt: float) -> void:
	if e.is_far: return
	var w: Array = e.k.wings; var fly := bool(e.k.fly)
	e.k.ph = float(e.k.ph) + dt * (16.0 if fly else 2.5)
	var fl := 0.25 + sin(float(e.k.ph)) * (0.65 if fly else 0.12); var open := 1.0 if fly else 0.3
	(w[0] as Node3D).rotation = Vector3(0, -0.3 * (1.0 - open), fl * open); (w[1] as Node3D).rotation = Vector3(0, 0.3 * (1.0 - open), -fl * open)

## through the air to a point (an imp, the inquisitor stepping down): straight there at speed sp, kept out of walls and
## above the lava
func _hover(e: Enemies.Foe, dt: float, want: Vector3, sp: float) -> void:
	var d := want - e.pos; var L := d.length()
	if L > 0.01:
		var step := d / L * minf(L, sp * dt)
		for ax in 3:
			var nxt := e.pos; nxt[ax] += step[ax]
			if Phys.collide_at(nxt.x, nxt.y, nxt.z, e.R, e.H * 0.8) == null: e.pos = nxt
	var floor_y := (altar.lava_y if altar != null else 0.0) + 1.0
	e.pos.y = maxf(e.pos.y, floor_y); e.pos.x = clampf(e.pos.x, -Phys.HALF + e.R, Phys.HALF - e.R); e.pos.z = clampf(e.pos.z, -Phys.HALF + e.R, Phys.HALF - e.R)

func _chest() -> Vector3: return fk._chest()
func _shove(from: Vector3, k: float, up := 3.0) -> void:
	var p := fk.player; var d := Vector3(p.pos.x - from.x, 0, p.pos.z - from.z)
	if d.length() < 0.01: d = Vector3(0, 0, 1)
	d = d.normalized(); p.launch(Vector3(d.x * k, up, d.z * k))
func _burn(t: float) -> void:
	if fk.game != null and fk.game.has_method("set_burn"): fk.game.set_burn(t)

## an imp: about its post till it sees you, then darting round you at a few metres up, fire bolts two at a time
func _imp(e: Enemies.Foe, dt: float, dist: float, _to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; fk.en._turn_toward(e, face_yaw, 9.0, dt)
	k.dart_t = float(k.dart_t) - dt; k.cd = float(k.cd) - dt; k.hang = maxf(0.0, float(k.get("hang", 0.0)) - dt)
	if float(k.dart_t) <= 0.0: k.dart_t = randf_range(1.4, 2.6); k.dart = float(k.dart) + randf_range(0.8, 2.2) * (1.0 if randf() < 0.5 else -1.0); k.ring = randf_range(IMP.ring[0], IMP.ring[1]); k.high = randf_range(IMP.high[0], IMP.high[1])
	var p := fk.player.pos; var post: Vector3 = k.post
	var want := p + Vector3(cos(float(k.dart)) * float(k.get("ring", 9.0)), float(k.get("high", 3.0)), sin(float(k.dart)) * float(k.get("ring", 9.0)))
	if Vector2(want.x - post.x, want.z - post.z).length() > float(IMP.leash): want = post + (want - post).limit_length(float(IMP.leash))
	if float(k.hang) <= 0.0: _hover(e, dt, want + Vector3(0, 0.3 * sin(clock * 4.0 + e.sid), 0), e.speed)   # (still in the air a moment as it fires)
	if int(k.burst) > 0:
		k.burst_t = float(k.burst_t) - dt
		if float(k.burst_t) <= 0.0:
			k.burst = int(k.burst) - 1; k.burst_t = 0.2; _bolt(e, float(IMP.speed), float(IMP.dmg), 0.03)
			if int(k.burst) == 0: k.hang = float(IMP.hang)
	elif seen and dist < float(IMP.range) and float(k.cd) <= 0.0: k.cd = randf_range(IMP.cd[0], IMP.cd[1]); k.burst = 2; k.burst_t = 0.25; k.hang = 0.5
	fk._pose(e, 0.0, dt, "cast" if int(k.burst) > 0 else "rest")

func _bolt(e: Enemies.Foe, speed: float, dmg: float, spread: float) -> void:
	var from := fk.en.muzzle_of(e); var d := (_chest() - from).normalized()
	d = (d + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * spread).normalized()
	fk.shoot("fire", from, d * speed, dmg * e.dmg_mul, 0, "fire"); Snd.play("rd_bolt", 0.8, from)

## a guard: the halberd's sweep when you are near (it steps in to you, but not far from its post); a spear thrown from afar
func _guard(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; fk.en._turn_toward(e, face_yaw, 7.0, dt)
	k.cd = float(k.cd) - dt; k.cd2 = float(k.cd2) - dt; var dy := absf(fk.player.pos.y - e.pos.y)
	if float(k.wind) > 0.0:   # a blow on its way: the halberd up, then down
		k.wind = float(k.wind) - dt; fk.en._ground_move(e, 0.0, 0.0, dt)
		e.arm_r.rotation = Vector3(-2.6 + (1.0 - float(k.wind) / float(HALBERD.wind)) * 2.3, 0, -0.3)
		if float(k.wind) <= 0.0:
			if str(k.get("blow", "")) == "sweep":
				if dist < float(HALBERD.reach) + 0.4 and dy < 1.8: fk._hurt("halberd", float(HALBERD.dmg) * e.dmg_mul, e.pos, "body"); _shove(e.pos, float(HALBERD.shove)); Snd.play("rd_axe", 1.0, e.pos)
				else: Snd.play("rd_swing", 0.8, e.pos)
			else:
				var from := fk.en.muzzle_of(e) + Vector3(0, 0.3, 0); var tgt := _chest() + Vector3(0, 0.2 + dist * 0.012, 0)
				var tfl := dist / float(SPEAR.speed); var v := (tgt - from) / maxf(tfl, 0.05); v.y += 0.5 * float(SPEAR.grav) * tfl
				fk.shoot("spear", from, v, float(SPEAR.dmg) * e.dmg_mul, 0, "spear", {"grav": float(SPEAR.grav), "burn": float(SPEAR.burn)}); Snd.play("rd_jav", 1.0, from)
		return
	var post: Vector3 = k.post; var f := to / maxf(dist, 0.001); var sp := 0.0; var mv := Vector2.ZERO
	var leash := float(HALBERD.leash)
	if dist < 10.0 and dy < 2.0:   # in to you, the halberd ready
		var nxt := Vector2(e.pos.x, e.pos.z) + f * 0.5
		if nxt.distance_to(Vector2(post.x, post.z)) < leash and dist > float(HALBERD.reach) - 0.6: sp = e.speed; mv = f * sp
		if dist < float(HALBERD.reach) and float(k.cd) <= 0.0: k.cd = float(HALBERD.cd); k.wind = float(HALBERD.wind); k.blow = "sweep"; Snd.play("rd_swing", 0.6, e.pos)
	else:
		var home := Vector2(post.x - e.pos.x, post.z - e.pos.z)
		if home.length() > 0.6: sp = e.speed * 0.7; mv = home.normalized() * sp
		if seen and dist > float(SPEAR.near) and dist < float(SPEAR.far) and float(k.cd2) <= 0.0: k.cd2 = randf_range(SPEAR.cd[0], SPEAR.cd[1]); k.wind = float(SPEAR.wind); k.blow = "spear"
	e.vel *= exp(-dt * 6.0)
	fk.en._ground_move(e, mv.x + e.vel.x, mv.y + e.vel.z, dt)
	fk._pose(e, sp, dt, "aim" if dist < 10.0 else "rest")

## an adept: about its post; a burning seal under you, an ember after you; too close, a step away in flame
func _adept(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; fk.en._turn_toward(e, face_yaw, 6.0, dt)
	k.cd = float(k.cd) - dt; k.cd2 = float(k.cd2) - dt; k.blink = float(k.blink) - dt
	if float(k.blink) <= 0.0 and dist < 7.0 and not bool(k.perch): k.blink = randf_range(6.0, 8.0); _flame_step(e, to / maxf(dist, 0.001)); return
	var sp := fk._hold(e, dt, dist, to, 1.6)
	if seen and dist < float(EMBER.range):
		if float(k.cd) <= 0.0 and dist < float(SEAL.range):
			k.cd = randf_range(SEAL.cd[0], SEAL.cd[1])
			fk._rune(fk.player.pos, float(SEAL.r), float(SEAL.fuse), float(SEAL.dmg) * e.dmg_mul, {"col": C_SEAL, "burn": float(SEAL.burn), "snd": "rd_seal"})
		elif float(k.cd2) <= 0.0:
			k.cd2 = randf_range(EMBER.cd[0], EMBER.cd[1]); var from := fk.en.muzzle_of(e)
			fk.shoot("ember", from, (_chest() - from).normalized() * float(EMBER.speed), float(EMBER.dmg) * e.dmg_mul, 0, "ember", {"burn": float(EMBER.burn)}); Snd.play("rm_ember", 1.0, from)
	fk._pose(e, sp, dt, "cast" if float(k.cd) > float(SEAL.cd[0]) - 0.6 or float(k.cd2) > float(EMBER.cd[0]) - 0.5 else "rest")

## a step through fire: gone here in a burst of flame, there a few metres off (back toward its post if it can)
func _flame_step(e: Enemies.Foe, f: Vector2) -> void:
	var post: Vector3 = e.k.post; var p := fk.player.pos
	for i in 12:
		var a := randf() * TAU; var r := randf_range(0.0, 5.0); var x := post.x + cos(a) * r; var z := post.z + sin(a) * r
		if i > 6: x = e.pos.x - f.x * 9.0 + cos(a) * 3.0; z = e.pos.z - f.y * 9.0 + sin(a) * 3.0
		var gy := Phys.ground_at(x, e.pos.y + 1.0, z, e.R)
		if absf(gy - e.pos.y) > 1.2 or Phys.collide_at(x, gy + 0.05, z, e.R, e.H) != null or Vector2(x - p.x, z - p.z).length() < 8.0: continue
		_fire_puff(Vector3(e.pos.x, e.pos.y + 1.0, e.pos.z)); e.pos = Vector3(x, gy, z); e.vel = Vector3.ZERO; _fire_puff(Vector3(x, gy + 1.0, z)); Snd.play("rm_ignite", 1.0, e.pos); return
func _fire_puff(at: Vector3) -> void:
	if fk.fx == null: return
	for i in 10: fk.fx.glow(at + Vector3(randf_range(-0.4, 0.4), randf_range(-0.9, 0.9), randf_range(-0.4, 0.4)), Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.5), randf_range(-1.5, 1.5)), 0.5, 0.45, 0.05, Color(1.0, randf_range(0.25, 0.55), 0.08, 0.85), 0.0, 2.0)

## a sniper: a red line laid on you while it aims, then the lance; close in, a quicker, weaker shot
func _sniper(e: Enemies.Foe, dt: float, dist: float, face_yaw: float, seen: bool) -> void:
	var k := e.k; fk.en._turn_toward(e, face_yaw, 5.0, dt); fk.en._ground_move(e, 0.0, 0.0, dt)
	k.cd = float(k.cd) - dt
	var aim := float(LANCE.aim) if dist > float(LANCE.near) else float(LANCE.quick)
	if seen and float(k.cd) <= 0.0:
		if float(k.aim) <= 0.0: Snd.play("rd_aim", 0.8, e.pos)
		k.aim = float(k.aim) + dt; var f := clampf(float(k.aim) / aim, 0.0, 1.0)
		var from := fk.en.muzzle_of(e); _aim_line(e, from, _chest(), f)
		if float(k.aim) >= aim:
			k.aim = 0.0; k.cd = float(LANCE.rest) if dist > float(LANCE.near) else 1.3; fk._aim_off(e)
			fk.shoot("lance", from, (_chest() - from).normalized() * float(LANCE.speed), float(LANCE.dmg if dist > float(LANCE.near) else LANCE.near_dmg) * e.dmg_mul, 0, "lance", {"shove": float(LANCE.shove)}); Snd.play("rd_lance", 1.0, from)
		fk._pose(e, 0.0, dt, "aim")
	else:
		if float(k.aim) > 0.0: k.aim = maxf(0.0, float(k.aim) - dt * 2.0)
		if float(k.aim) <= 0.0: fk._aim_off(e)
		fk._pose(e, 0.0, dt, "rest")

## the red line of a demon's aim on you: thin and dark, brighter and steadier as the shot is about to go
func _aim_line(e: Enemies.Foe, a: Vector3, b: Vector3, f: float) -> void:
	if e.laser == null:
		e.laser = MeshInstance3D.new(); e.laser.mesh = fk._unit_box(); e.laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; fk._root().add_child(e.laser)
	e.laser.material_override = fk._mat("dm_aim1" if f > 0.75 else "dm_aim0", Color(1.0, 0.55, 0.3, 0.9) if f > 0.75 else C_AIM)
	fk._stretch(e.laser, a, b, 0.02 + 0.035 * f); e.laser.visible = true

## a warden: in to you (not far from its post); its hook from afar (a line on you first) drags you in; the mace's slam
func _warden(e: Enemies.Foe, dt: float, dist: float, to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; fk.en._turn_toward(e, face_yaw, 5.0, dt)
	k.cd = float(k.cd) - dt; k.cd2 = float(k.cd2) - dt; var dy := absf(fk.player.pos.y - e.pos.y)
	if float(k.wind) > 0.0:
		k.wind = float(k.wind) - dt; fk.en._ground_move(e, 0.0, 0.0, dt)
		if str(k.get("blow", "")) == "slam":
			e.arm_r.rotation = Vector3(-2.8 + (1.0 - float(k.wind) / float(SLAM.wind)) * 2.6, 0, -0.2)
			if float(k.wind) <= 0.0: _slam(e)
		else:
			e.arm_l.rotation = Vector3(-1.9, 0, 0.3)
			if float(k.wind) <= 0.0:
				var from := fk.en.muzzle_of(e) + Vector3(-0.5, 0, 0); var tgt := _chest()
				fk.shoot("hook", from, (tgt - from).normalized() * float(HOOK.speed), float(HOOK.dmg) * e.dmg_mul, 0, "hook", {"pull": float(HOOK.pull), "from": e}); Snd.play("rd_hook", 1.0, from)
		return
	var post: Vector3 = k.post; var f := to / maxf(dist, 0.001); var sp := 0.0; var mv := Vector2.ZERO
	if dist < float(SLAM.r) - 0.6 and dy < 2.0 and float(k.cd) <= 0.0:
		k.cd = float(SLAM.cd); k.wind = float(SLAM.wind); k.blow = "slam"; Snd.play("rd_roar", 0.7, e.pos); fk._pose(e, 0.0, dt, "aim"); return
	if seen and dist > float(HOOK.near) and dist < float(HOOK.far) and float(k.cd2) <= 0.0:
		k.cd2 = randf_range(HOOK.cd[0], HOOK.cd[1]); k.wind = float(HOOK.warn); k.blow = "hook"
		fk.line(fk.en.muzzle_of(e), _chest(), float(HOOK.warn) + 0.15, C_AIM); return
	var nxt := Vector2(e.pos.x, e.pos.z) + f * 0.5
	if dist < 22.0 and nxt.distance_to(Vector2(post.x, post.z)) < float(HOOK.leash) and dist > 2.2: sp = e.speed; mv = f * sp
	elif dist >= 22.0:
		var home := Vector2(post.x - e.pos.x, post.z - e.pos.z)
		if home.length() > 0.6: sp = e.speed * 0.7; mv = home.normalized() * sp
	e.vel *= exp(-dt * 6.0)
	fk.en._ground_move(e, mv.x + e.vel.x, mv.y + e.vel.z, dt)
	fk._pose(e, sp, dt, "rest")

## the mace comes down: a ring of fire round it; whoever is in it is hurt and thrown out
func _slam(e: Enemies.Foe) -> void:
	var p := fk.player; Snd.play("rd_slam", 1.0, e.pos)
	if fk.fx != null:
		for i in 18: var a := i * TAU / 18.0; fk.fx.glow(e.pos + Vector3(cos(a) * 1.5, 0.2, sin(a) * 1.5), Vector3(cos(a) * 6.0, randf_range(0.5, 2.0), sin(a) * 6.0), 0.5, 0.5, 0.05, Color(1.0, 0.45, 0.1, 0.9), 0.0, 3.0)
	p.shake = maxf(p.shake, 0.5)
	if Vector2(p.pos.x - e.pos.x, p.pos.z - e.pos.z).length() < float(SLAM.r) and absf(p.pos.y - e.pos.y) < 1.8:
		fk._hurt("slam", float(SLAM.dmg) * e.dmg_mul, e.pos, "body"); _shove(e.pos, float(SLAM.shove), 4.0)

# ---------------- the inquisitor ----------------
## The master of the caldera, on the north gallery looking down. Three parts, by his health:
##   all of it  lances of judgement, three in a row, each after a red line on you; brands burnt under you in threes;
##              imps called to him now and then
##   60%        he steps from perch to perch (the gallery's braziers, the spires' lookouts) and adds a fan of fire
##   30%        he calls the tide (if it has not come) and comes down himself on to the sanctum: everything quicker, and
##              a sweep of his chain when you are near
func _inquisitor(e: Enemies.Foe, dt: float, dist: float, _to: Vector2, face_yaw: float, seen: bool) -> void:
	var k := e.k; boss = e
	if not bool(k.get("roused", false)):   # he looks down on the fight till his time comes: the tide, you close by, or a wound
		if (altar != null and altar.tide_on) or dist < float(INQ.rouse) or e.hp < e.max_hp:
			k.roused = true; k.act = 1.5; k.call = 8.0; Snd.play("rd_roar_big", 1.0, e.pos)
			if fk.game != null: fk.game.say_banner("심연의 고문관", "고문관이 직접 심판에 나섭니다", 2.4)
		else: fk.en._turn_toward(e, face_yaw, 2.0, dt); fk.en._ground_move(e, 0.0, 0.0, dt); fk._pose(e, 0.0, dt, "rest"); return
	var f := e.hp / maxf(e.max_hp, 1.0); var ph := 1 if f > float(INQ.p2) else (2 if f > float(INQ.p3) else 3)
	if ph != int(k.phase):
		k.phase = ph; k.act = 1.4; _fire_puff(e.pos + Vector3(0, 1.4, 0)); Snd.play("rd_roar_big", 1.0, e.pos)
		if fk.game != null: fk.game.say_banner("심연의 고문관", "고문관이 첨탑과 회랑을 오가며 화염 부채를 펼칩니다" if ph == 2 else "고문관이 용암을 불러 올리고 제단으로 내려옵니다", 2.6)
		if ph == 3: _descend(e)
	var quick := float(INQ.rage) if ph == 3 else 1.0
	fk.en._turn_toward(e, face_yaw, 6.0, dt)
	k.act = float(k.act) - dt * quick; k.call = float(k.call) - dt; k.port = float(k.port) - dt
	if ph == 2 and float(k.port) <= 0.0 and altar != null:   # from perch to perch
		k.port = float(INQ.port[1])
		var spot = altar.perch_away(e.pos, fk.player.pos)
		if spot != null: _fire_puff(e.pos + Vector3(0, 1.4, 0)); e.pos = spot; e.vel = Vector3.ZERO; k.post = spot; _fire_puff(spot + Vector3(0, 1.4, 0)); Snd.play("rm_rift", 1.0, e.pos)
	if float(k.call) <= 0.0:   # imps called to him
		k.call = float(INQ.call[ph - 1]); _summon(e, int(INQ.imps[ph - 1]))
	if ph == 3:   # down on the sanctum: toward you, but not off it; the chain's sweep when you are close
		var c := Vector3(0, Caldera.MID_Y, 0); var f2 := _to / maxf(dist, 0.001); var mv := Vector2.ZERO
		var nxt := Vector2(e.pos.x, e.pos.z) + f2 * 0.5
		if dist > 3.5 and nxt.length() < float(INQ.hold): mv = f2 * e.speed
		k.sweep = float(k.sweep) - dt
		if dist < float(INQ.sweep_r) and absf(fk.player.pos.y - e.pos.y) < 2.0 and float(k.sweep) <= 0.0:
			k.sweep = float(INQ.sweep_cd); Snd.play("rd_chain_spin", 1.0, e.pos)
			fk._hurt("sweep", float(INQ.sweep_dmg) * e.dmg_mul, e.pos, "body"); _shove(e.pos, 7.0, 3.5); _burn(3.0)
		fk.en._ground_move(e, mv.x, mv.y, dt)
		if e.pos.y < c.y - 0.5: e.pos = c   # (never down in the lava)
	else: fk.en._ground_move(e, 0.0, 0.0, dt)
	var near: bool = seen or (dist < 30.0 and absf(fk.player.pos.y - e.pos.y) < 8.0)
	if int(k.burst) > 0:   # a run of lances (each its own red line first) or the fan's waves
		k.burst_t = float(k.burst_t) - dt * quick
		if float(k.burst_t) <= 0.0:
			k.burst = int(k.burst) - 1
			if str(k.get("run", "")) == "lance": _judge(e); k.burst_t = float(INQ.lance_aim) + 0.25
			else: _fan(e); k.burst_t = 0.5
	elif near and float(k.act) <= 0.0:
		var pick := randi() % (2 if ph == 1 else 3)
		match pick:
			0: k.run = "lance"; k.burst = 3; k.burst_t = 0.0
			1:
				for i in 3:
					var a := randf() * TAU; var r := 0.0 if i == 0 else randf_range(2.5, 4.5)
					fk._rune(fk.player.pos + Vector3(cos(a) * r, 0, sin(a) * r), float(INQ.brand_r), float(INQ.brand_fuse) + i * 0.15, float(INQ.brand) * e.dmg_mul, {"col": C_SEAL, "burn": 4.0, "snd": "rd_seal"})
			2: k.run = "fan"; k.burst = int(INQ.fan_waves); k.burst_t = 0.0
		k.act = float(INQ.act[ph - 1])
	fk._pose(e, 0.0, dt, "cast" if (int(k.burst) > 0 or float(k.act) > 1.6) else "rest")

## a lance of judgement: a red line on you, and down it a moment later
func _judge(e: Enemies.Foe) -> void:
	var from := fk.en.muzzle_of(e); var tgt := _chest(); var dmg := float(INQ.lance) * e.dmg_mul
	fk.line(from, tgt, float(INQ.lance_aim), C_AIM); Snd.play("rd_aim", 0.9, from)
	fk._later.push_back({"t": float(INQ.lance_aim), "f": func() -> void:
		if e.alive: fk.shoot("lance", from, (tgt - from).normalized() * float(INQ.lance_speed), dmg, 0, "judge", {"burn": 3.0}); Snd.play("rd_lance", 1.0, from)})

## a fan of fire bolts at you
func _fan(e: Enemies.Foe) -> void:
	var from := fk.en.muzzle_of(e); var d := (_chest() - from).normalized(); var side := d.cross(Vector3.UP).normalized(); var n := int(INQ.fan_n)
	for i in n:
		var a := (i - (n - 1) * 0.5) * float(INQ.fan_arc)
		fk.shoot("fire", from, (d * cos(a) + side * sin(a)).normalized() * float(INQ.fan_speed), float(INQ.fan_dmg) * e.dmg_mul, 0, "fan")
	Snd.play("rd_fan", 1.0, from)

## imps called up out of the lava round you (they count for nothing, and go with him)
func _summon(e: Enemies.Foe, n: int) -> void:
	var p := fk.player.pos; Snd.play("rm_summon_demon", 1.0, e.pos)
	for i in n:
		var a := randf() * TAU; var at := p + Vector3(cos(a) * 9.0, 3.0, sin(a) * 9.0)
		at.y = maxf(at.y, (altar.lava_y if altar != null else 0.0) + 2.0)
		var o := {"yaw": randf() * TAU, "y": at.y, "scale": size_of("dm_imp"), "post": {"x": at.x, "y": at.y, "z": at.z, "fly": true}}
		var imp := fk.en.spawn("dm_imp", at.x, at.z, o); imp.extra = true; imp.no_pay = true; fk.en.alarm(imp)
		_fire_puff(at)
	if fk.game != null: fk.game.say_feed("고문관이 임프 %d마리를 불러냈습니다" % n)

## down on to the sanctum: the tide called if it has not come, and he stands in the middle of the altar
func _descend(e: Enemies.Foe) -> void:
	if altar != null: altar.rise()
	_fire_puff(e.pos + Vector3(0, 1.4, 0))
	var at := Vector3(0.0, Caldera.MID_Y, -4.0); e.pos = at; e.k.post = at; e.k.perch = false; e.vel = Vector3.ZERO
	_fire_puff(at + Vector3(0, 1.4, 0)); Snd.play("rd_land_big", 1.0, at)
	if fk.fx != null: fk.fx.explode(at + Vector3(0, 0.5, 0), true, [1.0, 0.4, 0.1])

## he is down: his imps go with him, his brands burn out
func boss_down(e: Enemies.Foe) -> void:
	boss = null
	for o in fk.en.list.duplicate():
		if o.alive and o.extra and o.type == "dm_imp": fk.en.vanish(o)
	for r: Dictionary in fk.runes:
		if is_instance_valid(r.node): (r.node as Node3D).queue_free()
	fk.runes.clear(); _fire_puff(e.pos + Vector3(0, 1.4, 0))
