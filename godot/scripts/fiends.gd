class_name Fiends
extends RefCounted
## 6-A's demons: the party's foes on the road to the fallen tower. Each is one of the realm's fighters on the far side
## ("them"), so what the four peoples carry works on them as it does on each other (the dagger turns their missiles back,
## the bombs, shoves, slows and ultimates, the elements); their minds are their own (ModeRaid gives them their turns):
##   악마 경비병 (guard)       the gate's soldiers: a fire halberd close by, a thrown fire spear from afar
##   심연 저격병 (sniper)      on the pillars by the bridge: a red line on you while it aims, then a lance that knocks you back
##   용암 거수 (beast)         the bridge's elite: charges along the planks and throws whoever it meets aside (over the edge)
##   탑 수비대 (defender)      up the tower's stair: lobs fire down on whoever climbs
##   흑요석 임프 (imp)         small, flying, quick: fire bolts (Baal calls them)
##   카르녹 (karnok)            the chain executioner on the tower's stair (two phases: Karnok's part below)
##   바알 (baal)                the lord of the abyss on the sky altar (three phases: Baal's part below)

const KINDS := {
	"guard": {"name": "악마 경비병", "hp": 420.0, "r": 0.42, "h": 2.15, "head": 0.36, "speed": 4.4, "sight": 36.0, "leash": 16.0, "pay": 2400},
	"sniper": {"name": "심연 저격병", "hp": 260.0, "r": 0.38, "h": 2.0, "head": 0.32, "speed": 0.0, "sight": 90.0, "leash": 0.0, "pay": 3000},
	"beast": {"name": "용암 거수", "hp": 3600.0, "r": 1.25, "h": 3.4, "head": 0.8, "speed": 4.2, "sight": 70.0, "leash": 90.0, "pay": 16000, "elite": true},
	"defender": {"name": "탑 수비대", "hp": 320.0, "r": 0.4, "h": 2.05, "head": 0.34, "speed": 0.0, "sight": 46.0, "leash": 0.0, "pay": 2600},
	"imp": {"name": "흑요석 임프", "hp": 170.0, "r": 0.34, "h": 1.15, "head": 0.3, "speed": 7.0, "sight": 50.0, "leash": 40.0, "pay": 1200},
	"karnok": {"name": "심연의 사슬 집행관 카르녹", "hp": 8000.0, "shield": 2000.0, "r": 0.95, "h": 3.5, "head": 0.6, "speed": 4.6, "sight": 80.0, "leash": 0.0, "pay": 60000, "boss": true},
	"baal": {"name": "심연의 대군주 바알", "hp": 22000.0, "shield": 3000.0, "r": 1.5, "h": 5.4, "head": 0.9, "speed": 3.6, "sight": 100.0, "leash": 0.0, "pay": 150000, "boss": true},
}
# what they throw and swing
const HALBERD := {"dmg": 32.0, "reach": 2.7, "arc": 0.9, "wind": 0.4, "cd": 1.4}
const SPEAR := {"dmg": 26.0, "speed": 38.0, "cd": [3.6, 5.0], "near": 7.0, "far": 34.0}
const LANCE := {"dmg": 55.0, "speed": 130.0, "aim": 1.5, "cd": 3.6, "shove": 3.0}
const CHARGE := {"dmg": 55.0, "speed": 15.0, "t": 2.8, "warn": 1.0, "cd": 7.5, "shove": 6.0, "side": 0.7, "near": 9.0, "far": 50.0}
const SLAM := {"dmg": 45.0, "r": 4.2, "wind": 0.8, "cd": 2.8, "shove": 3.2}
const LOB := {"dmg": 28.0, "r": 2.4, "cd": [3.8, 4.8], "burn": 4.0, "burn_t": 3.0}
const BOLT := {"dmg": 9.0, "speed": 46.0, "cd": [1.1, 1.6]}
# Karnok (the boss paper's numbers where it gives them; ours where it does not)
const KARNOK := {"jav": 85.0, "jav_speed": 42.0, "jav_cd": 3.2, "jav_back": 450.0, "jav_cut": 1000.0, "jav_shove": 4.0,
	"wave": 60.0, "wave_cd": 14.0, "wave_speed": 55.0, "wave_h": 0.75, "wave_wind": 1.2, "wave_burn": 12.0,
	"anchor_hp": 1100.0, "anchor_regen": 200.0, "phase2": 0.5, "roar": 2.0,
	"spin_r": 7.0, "spin_dmg": 28.0, "spin_t": 4.0, "spin_cd": 13.0, "spin_speed": 5.5,
	"hook_range": 30.0, "hook_cd": 17.0, "hook_warn": 0.7, "hook_wind": 2.2, "hook_axe": 420.0, "hook_cancel": 700.0, "hook_bomb_r": 4.5, "stagger": 2.0,
	"behind": 1.5, "core_ult": 1000.0, "core_shards": 400}
# Baal
const BAAL := {"barrier_regen": 80.0, "barrier_wait": 4.0, "turned_cut": 400.0, "phase2": 0.65, "phase3": 0.30, "eclipse_at": 0.10,
	"fan_cd": 9.0, "fan_n": 7, "fan_arc": 120.0, "fan_speed": 24.0, "fan_dmg": 34.0, "fan_waves": 3, "fan_gap": 0.5,
	"bind_cd": 22.0, "bind_first": 12.0, "bind_hp": 360.0, "bind_t": 4.0, "bind_slow": 0.6,
	"rift_cd": 15.0, "rift_cover": 0.40, "rift_max": 16, "rift_r": 5.0, "rift_warn": 1.8, "rift_dmg": 60.0, "rift_burn": 8.0, "rift_burn_t": 6.0,
	"claw_dmg": 55.0, "claw_reach": 6.0, "claw_arc": 1.05, "claw_wind": 0.6, "claw_cd": 3.0,
	"hover": 15.0, "meteor_cd": 20.0, "meteor_t": 5.0, "meteor_every": 0.4, "meteor_r": 3.2, "meteor_dmg": 70.0, "meteor_warn": 1.1,
	"drain_cd": 16.0, "drain_t": 6.0, "drain_dps": 26.0, "drain_heal": 150.0,
	"sun_cd": 45.0, "sun_t": 16.0, "sun_dmg": 200.0, "core_hp": 900.0, "core_out": 3.6, "imps": 4, "crash_t": 5.0, "crash_mul": 1.5, "pad_up": 26.0,
	"aura_r": 9.0, "aura_dps": 14.0, "heal_cut": 0.5, "rage": 1.25,
	"sword_cd": 10.0, "sword_dmg": 60.0, "sword_reach": 7.0, "wave_dmg": 90.0, "wave_speed": 14.0, "wave_h": 0.9, "wave_max": 22.0,
	"eclipse_t": 12.0, "eclipse_mul": 2.0, "eclipse_bomb": 2.5, "eclipse_bomb_r": 6.0}

var rm: Realm; var mode; var road: DemonRoad
var lines: Array = []      # what is shown before a blow: {a, b, t, node, col}
var rings: Array = []      # circles on the ground about to burst: {at, r, t, node}
var waves: Array = []      # Karnok's fire wave down the stair, Baal's ring of lava: {kind, ...}
var _mats := {}; var _root_n: Node3D = null

func _root() -> Node3D:
	if _root_n == null or not is_instance_valid(_root_n):
		_root_n = Node3D.new(); _root_n.name = "Fiends"; _root_n.set_meta("shadow", false)
		if rm.en != null: rm.en.add_child(_root_n)
	return _root_n

func clear() -> void:
	if _root_n != null and is_instance_valid(_root_n): _root_n.queue_free()
	_root_n = null; lines.clear(); rings.clear(); waves.clear()

func _mat(key: String, col: Color, add := true) -> Material:
	if not _mats.has(key):
		var m := Gfx.unlit(col, false); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mats[key] = Gfx.see_through(m)
	return _mats[key]

static func is_mon(f) -> bool: return f != null and f is Realm.Fighter and (f as Realm.Fighter).brain.has("mon")
static func kind_of(f: Realm.Fighter) -> String: return str(f.brain.get("mon", ""))

# ---------------- who they are ----------------
## a demon takes the field: its body, its numbers, where it stands (post), asleep till the party comes
func make(kind: String, at: Vector3, sec: int, more := {}) -> Realm.Fighter:
	var T: Dictionary = KINDS[kind]
	var f := Realm.Fighter.new(); rm._id += 1; f.id = rm._id; f.team = "them"; f.race = kind; f.me = false
	f.name = str(T.name); f.R = float(T.r); f.H = float(T.h); f.eye = float(T.h) * 0.9; f.head = float(T.head)
	f.max_hp = float(T.hp) * float(more.get("hp_mul", 1.0)); f.hp = f.max_hp; f.shield = float(T.get("shield", 0.0)); f.pos = at; f.yaw = float(more.get("yaw", PI / 2.0))
	f.aim = Vector3(-sin(f.yaw), 0, -cos(f.yaw))
	f.brain = {"mon": kind, "sec": sec, "post": at, "awake": false, "t": randf() * 1.5, "cd": randf_range(0.5, 2.0), "cd2": randf_range(2.0, 4.0), "state": "idle", "st": 0.0, "tgt": null, "fly": kind == "imp"}
	f.brain.merge(more, true)
	rm.all.push_back(f)
	_body(f)
	return f

func _body(f: Realm.Fighter) -> void:
	if rm.en == null: return
	var en := rm.en; var k := kind_of(f)
	var g := Node3D.new(); g.rotation_order = EULER_ORDER_YXZ; _root().add_child(g)
	var b := {"g": g, "mon": true, "ph": randf() * TAU}
	var skin := "8a2a22"; var dark := "1e1418"; var horn := "d8c8a8"; var ember := "ff6a1a"
	match k:
		"guard":
			b.leg_l = en._part(g, Vector3(-0.13, 1.0, 0), "fd_guard_leg", [[0.18, 1.0, 0.2, 0, -0.5, 0, dark], [0.2, 0.1, 0.32, 0, -0.98, 0.06, "120c0e"]])
			b.leg_r = en._part(g, Vector3(0.13, 1.0, 0), "fd_guard_leg", [[0.18, 1.0, 0.2, 0, -0.5, 0, dark], [0.2, 0.1, 0.32, 0, -0.98, 0.06, "120c0e"]])
			b.upper = en._part(g, Vector3(0, 1.0, 0), "fd_guard_up", [[0.5, 0.7, 0.3, 0, 0.4, 0, "2b2733"], [0.54, 0.12, 0.32, 0, 0.72, 0, "3a3442"], [0.26, 0.28, 0.26, 0, 0.92, 0.01, skin],
				[0.06, 0.26, 0.06, -0.1, 1.15, 0, horn, [0, 0, 0.35]], [0.06, 0.26, 0.06, 0.1, 1.15, 0, horn, [0, 0, -0.35]], [0.2, 0.05, 0.02, 0, 0.95, 0.14, ember]])
			b.arm_r = en._part(b.upper, Vector3(0.34, 0.66, 0), "fd_guard_ar", [[0.14, 0.66, 0.15, 0, -0.32, 0, "2b2733"], [0.05, 0.05, 2.2, 0, -0.66, 0.5, "4c4a50"], [0.06, 0.32, 0.36, 0, -0.66, 1.55, ember]])
			b.arm_l = en._part(b.upper, Vector3(-0.34, 0.66, 0), "fd_guard_al", [[0.14, 0.66, 0.15, 0, -0.32, 0, "2b2733"], [0.5, 0.7, 0.06, 0, -0.5, 0.18, "3a3442"]])
		"sniper":
			b.leg_l = en._part(g, Vector3(-0.11, 0.95, 0), "fd_snp_leg", [[0.15, 0.95, 0.17, 0, -0.47, 0, dark]])
			b.leg_r = en._part(g, Vector3(0.11, 0.95, 0), "fd_snp_leg", [[0.15, 0.95, 0.17, 0, -0.47, 0, dark]])
			b.upper = en._part(g, Vector3(0, 0.95, 0), "fd_snp_up", [[0.42, 0.66, 0.26, 0, 0.38, 0, "3a1a20"], [0.6, 0.5, 0.05, 0, 0.42, -0.16, "200c10"], [0.22, 0.25, 0.24, 0, 0.86, 0.01, skin], [0.3, 0.14, 0.3, 0, 1.0, -0.02, "200c10"], [0.16, 0.04, 0.02, 0, 0.88, 0.13, ember]])
			b.arm_r = en._part(b.upper, Vector3(0.28, 0.62, 0), "fd_snp_ar", [[0.12, 0.6, 0.13, 0, -0.3, 0, "3a1a20"], [0.06, 0.06, 1.8, 0, -0.62, 0.55, "6d6a72"], [0.12, 0.12, 0.12, 0, -0.62, 1.45, ember]])
			b.arm_l = en._part(b.upper, Vector3(-0.28, 0.62, 0), "fd_snp_al", [[0.12, 0.6, 0.13, 0, -0.3, 0, "3a1a20"]])
		"beast":
			b.leg_l = en._part(g, Vector3(-0.7, 1.4, 0.6), "fd_bst_leg", [[0.55, 1.4, 0.6, 0, -0.7, 0, "3b2420"], [0.6, 0.2, 0.75, 0, -1.35, 0.1, "1e1418"]])
			b.leg_r = en._part(g, Vector3(0.7, 1.4, 0.6), "fd_bst_leg", [[0.55, 1.4, 0.6, 0, -0.7, 0, "3b2420"], [0.6, 0.2, 0.75, 0, -1.35, 0.1, "1e1418"]])
			b.leg_bl = en._part(g, Vector3(-0.7, 1.4, -1.0), "fd_bst_leg", [[0.55, 1.4, 0.6, 0, -0.7, 0, "3b2420"], [0.6, 0.2, 0.75, 0, -1.35, 0.1, "1e1418"]])
			b.leg_br = en._part(g, Vector3(0.7, 1.4, -1.0), "fd_bst_leg", [[0.55, 1.4, 0.6, 0, -0.7, 0, "3b2420"], [0.6, 0.2, 0.75, 0, -1.35, 0.1, "1e1418"]])
			b.upper = en._part(g, Vector3(0, 1.4, 0), "fd_bst_up", [[2.0, 1.5, 3.0, 0, 0.75, -0.2, "4a2a22"], [1.7, 0.5, 2.6, 0, 1.6, -0.3, "2a1a18"], [1.2, 1.1, 1.2, 0, 1.1, 1.7, "5a2e24"],
				[0.5, 0.18, 0.18, -0.35, 1.25, 2.3, ember], [0.5, 0.18, 0.18, 0.35, 1.25, 2.3, ember], [0.2, 0.8, 0.2, -0.6, 1.9, 1.6, horn, [0.6, 0, 0.4]], [0.2, 0.8, 0.2, 0.6, 1.9, 1.6, horn, [0.6, 0, -0.4]],
				[1.6, 0.06, 2.2, 0, 2.05, -0.3, ember]])
		"defender":
			b.leg_l = en._part(g, Vector3(-0.12, 0.98, 0), "fd_def_leg", [[0.17, 0.98, 0.19, 0, -0.49, 0, dark]])
			b.leg_r = en._part(g, Vector3(0.12, 0.98, 0), "fd_def_leg", [[0.17, 0.98, 0.19, 0, -0.49, 0, dark]])
			b.upper = en._part(g, Vector3(0, 0.98, 0), "fd_def_up", [[0.48, 0.68, 0.3, 0, 0.38, 0, "3a2a1a"], [0.56, 0.14, 0.34, 0, 0.7, 0, "6d5a3a"], [0.25, 0.27, 0.25, 0, 0.9, 0.01, skin], [0.32, 0.1, 0.32, 0, 1.06, 0, "6d5a3a"]])
			b.arm_r = en._part(b.upper, Vector3(0.32, 0.64, 0), "fd_def_ar", [[0.13, 0.64, 0.14, 0, -0.32, 0, "3a2a1a"], [0.3, 0.3, 0.3, 0, -0.7, 0.12, ember]])
			b.arm_l = en._part(b.upper, Vector3(-0.32, 0.64, 0), "fd_def_al", [[0.13, 0.64, 0.14, 0, -0.32, 0, "3a2a1a"]])
		"imp":
			b.upper = en._part(g, Vector3(0, 0.55, 0), "fd_imp_up", [[0.36, 0.42, 0.3, 0, 0.0, 0, "141018"], [0.26, 0.24, 0.24, 0, 0.34, 0.02, "2b2733"], [0.06, 0.16, 0.06, -0.08, 0.5, 0, horn, [0, 0, 0.4]], [0.06, 0.16, 0.06, 0.08, 0.5, 0, horn, [0, 0, -0.4]],
				[0.14, 0.04, 0.02, 0, 0.36, 0.13, Color("b04aff").to_html(false)], [0.1, 0.5, 0.1, 0, -0.42, -0.1, "141018"]])
			b.wing_l = en._part(g, Vector3(-0.15, 0.7, -0.08), "fd_imp_wing", [[0.9, 0.04, 0.5, -0.45, 0, 0, "2a1030"]]); b.wing_r = en._part(g, Vector3(0.15, 0.7, -0.08), "fd_imp_wing_r", [[0.9, 0.04, 0.5, 0.45, 0, 0, "2a1030"]])
		"karnok":
			b.leg_l = en._part(g, Vector3(-0.32, 1.6, 0), "fd_krn_leg", [[0.42, 1.6, 0.46, 0, -0.8, 0, "2a2028"], [0.46, 0.18, 0.6, 0, -1.55, 0.08, "141014"]])
			b.leg_r = en._part(g, Vector3(0.32, 1.6, 0), "fd_krn_leg", [[0.42, 1.6, 0.46, 0, -0.8, 0, "2a2028"], [0.46, 0.18, 0.6, 0, -1.55, 0.08, "141014"]])
			b.upper = en._part(g, Vector3(0, 1.6, 0), "fd_krn_up", [[1.2, 1.3, 0.75, 0, 0.65, 0, "3a2e30"], [1.3, 0.24, 0.8, 0, 1.2, 0, "4c4a50"], [0.5, 0.5, 0.5, 0, 1.55, 0.02, skin],
				[0.12, 0.5, 0.12, -0.2, 1.95, 0, horn, [0, 0, 0.3]], [0.12, 0.5, 0.12, 0.2, 1.95, 0, horn, [0, 0, -0.3]], [0.36, 0.08, 0.03, 0, 1.6, 0.26, ember],
				[0.08, 0.08, 1.4, -0.4, 0.4, 0.4, "6d6a72", [0.4, 0, 0]], [0.08, 0.08, 1.4, 0.4, 0.4, 0.4, "6d6a72", [-0.4, 0, 0]]])
			b.core = en._part(b.upper, Vector3(0, 0.78, 0.4), "fd_krn_core", [[0.34, 0.34, 0.1, 0, 0, 0, "ff2a3a"]])
			b.arm_r = en._part(b.upper, Vector3(0.78, 1.15, 0), "fd_krn_ar", [[0.32, 1.1, 0.34, 0, -0.55, 0, "3a2e30"], [0.1, 0.1, 1.6, 0, -1.1, 0.6, "4c4a50"], [0.7, 0.7, 0.7, 0, -1.1, 1.5, "2a2028"]])
			b.arm_l = en._part(b.upper, Vector3(-0.78, 1.15, 0), "fd_krn_al", [[0.32, 1.1, 0.34, 0, -0.55, 0, "3a2e30"], [0.14, 0.14, 2.4, 0, -1.1, 0.9, "6d6a72"]])
		"baal":
			b.leg_l = en._part(g, Vector3(-0.55, 2.3, 0), "fd_baal_leg", [[0.7, 2.3, 0.8, 0, -1.15, 0, "3a0e10"], [0.8, 0.3, 1.1, 0, -2.2, 0.2, "120608"]])
			b.leg_r = en._part(g, Vector3(0.55, 2.3, 0), "fd_baal_leg", [[0.7, 2.3, 0.8, 0, -1.15, 0, "3a0e10"], [0.8, 0.3, 1.1, 0, -2.2, 0.2, "120608"]])
			b.upper = en._part(g, Vector3(0, 2.3, 0), "fd_baal_up", [[1.9, 1.9, 1.1, 0, 0.95, 0, "6a1612"], [2.1, 0.36, 1.2, 0, 1.75, 0, "1e1418"], [0.8, 0.8, 0.8, 0, 2.3, 0.05, "8a2a22"],
				[0.2, 1.1, 0.2, -0.42, 2.9, -0.1, horn, [0.4, 0, 0.5]], [0.2, 1.1, 0.2, 0.42, 2.9, -0.1, horn, [0.4, 0, -0.5]], [0.5, 0.12, 0.04, 0, 2.35, 0.42, ember],
				[1.4, 0.08, 0.9, 0, 1.0, 0.56, ember]])
			b.wing_l = en._part(b.upper, Vector3(-0.8, 1.6, -0.5), "fd_baal_wing", [[3.4, 0.08, 2.2, -1.7, 0.3, -0.6, "2a0a10"], [0.2, 0.2, 3.0, -1.6, 0.3, -0.1, "120608", [0, 0.6, 0]]])
			b.wing_r = en._part(b.upper, Vector3(0.8, 1.6, -0.5), "fd_baal_wing_r", [[3.4, 0.08, 2.2, 1.7, 0.3, -0.6, "2a0a10"], [0.2, 0.2, 3.0, 1.6, 0.3, -0.1, "120608", [0, -0.6, 0]]])
			b.arm_r = en._part(b.upper, Vector3(1.2, 1.7, 0), "fd_baal_ar", [[0.5, 1.7, 0.5, 0, -0.85, 0, "6a1612"], [0.14, 0.14, 3.4, 0, -1.7, 1.4, "1e1418"], [0.3, 0.5, 2.6, 0, -1.7, 1.9, ember]])
			b.arm_l = en._part(b.upper, Vector3(-1.2, 1.7, 0), "fd_baal_al", [[0.5, 1.7, 0.5, 0, -0.85, 0, "6a1612"], [0.12, 0.12, 3.0, 0, -1.7, 0.9, "3a2a1a"], [0.6, 0.6, 0.6, 0, -1.7, 2.4, ember]])
	var sc := float(f.brain.get("scale", 1.0))
	if k == "guard" or k == "sniper" or k == "defender": g.scale = Vector3.ONE * (f.H / 2.0)
	elif k == "karnok": g.scale = Vector3.ONE * (f.H / 3.6)
	elif k == "baal": g.scale = Vector3.ONE * (f.H / 5.4)
	g.scale *= sc
	var bar := Node3D.new(); bar.visible = false; _root().add_child(bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.84, 0.08, 1); bar.add_child(bg)
	var fill := MeshInstance3D.new(); fill.mesh = en._bar_mesh; fill.material_override = en._bar_fill; fill.scale = Vector3(0.8, 0.05, 1); bar.add_child(fill)
	if bool(KINDS[k].get("boss", false)) or bool(KINDS[k].get("elite", false)): bar.scale = Vector3.ONE * 1.8
	b.bar = bar; b.fill = fill
	f.body = b
	g.position = f.pos; g.rotation.y = atan2(f.aim.x, f.aim.z)

## each frame: where its body is, how its legs and arms go, its bar
func place(f: Realm.Fighter, dt: float) -> void:
	var b := f.body
	if b.is_empty() or not is_instance_valid(b.g): return
	var g: Node3D = b.g
	g.visible = f.alive
	if not f.alive: (b.bar as Node3D).visible = false; return
	g.position = f.pos; g.rotation.y = atan2(f.aim.x, f.aim.z)
	var sp := Vector2(f.vel.x, f.vel.z).length(); var amt := clampf(sp / 4.0, 0.0, 1.0)
	b.ph = float(b.ph) + (sp * 1.6 + 1.0) * dt
	var sw := sin(float(b.ph)) * 0.6 * amt
	for q in [["leg_l", 1.0], ["leg_r", -1.0], ["leg_bl", -1.0], ["leg_br", 1.0]]:
		if b.has(q[0]): (b[q[0]] as Node3D).rotation.x = sw * float(q[1])
	var st := str(f.brain.get("state", "idle"))
	if b.has("arm_r"):
		var ar := -0.4
		match st:
			"wind", "swing": ar = -2.4 if st == "wind" else -0.3
			"aim", "throw": ar = -1.5
			"spin": ar = -1.57; (b.upper as Node3D).rotation.y = float(f.brain.get("spin_a", 0.0))
			"cast", "eclipse": ar = -2.6
		(b.arm_r as Node3D).rotation.x = lerpf((b.arm_r as Node3D).rotation.x, ar, minf(1.0, dt * 12.0))
	if b.has("arm_l"): (b.arm_l as Node3D).rotation.x = lerpf((b.arm_l as Node3D).rotation.x, -0.6 if st != "eclipse" else -2.6, minf(1.0, dt * 8.0))
	if st != "spin" and b.has("upper"): (b.upper as Node3D).rotation.y = 0.0
	if b.has("wing_l"):
		var fl := 0.25 + sin(rm.clock * (14.0 if kind_of(f) == "imp" else 3.0)) * (0.6 if kind_of(f) == "imp" else 0.25)
		var open := 1.0 if (kind_of(f) == "imp" or f.brain.get("air", false)) else 0.35
		(b.wing_l as Node3D).rotation = Vector3(0, 0, fl * open); (b.wing_r as Node3D).rotation = Vector3(0, 0, -fl * open)
	if st == "eclipse" and b.has("upper"): (b.upper as Node3D).rotation.x = 0.5
	if b.has("core"): (b.core as Node3D).visible = st == "hook_wind" or float(f.brain.get("stagger", 0.0)) > 0.0
	var bar: Node3D = b.bar
	var boss := bool(KINDS[kind_of(f)].get("boss", false))
	bar.visible = f.hp < f.max_hp and not boss   # (a boss's health is on the screen's top, not over his head)
	if bar.visible:
		bar.position = f.pos + Vector3(0, f.H + 0.5, 0)
		if rm.cam != null: bar.global_transform.basis = rm.cam.global_transform.basis
		var ff := clampf(f.hp / f.max_hp, 0.0, 1.0); (b.fill as Node3D).scale.x = 0.8 * ff; (b.fill as Node3D).position.x = -0.4 * (1.0 - ff)

## a demon falls: ash and embers, drawn down into a crack
func fell(f: Realm.Fighter) -> void:
	Snd.play("rd_fall_big" if bool(KINDS[kind_of(f)].get("boss", false)) or kind_of(f) == "beast" else "rd_fall", 1.0, f.feet_mid())
	if rm.fx == null: return
	var n := 16 + int(f.H * 6.0)
	for i in n: rm.fx.glow(f.pos + Vector3(randf_range(-f.R, f.R), randf_range(0.2, f.H), randf_range(-f.R, f.R)), Vector3(randf_range(-0.6, 0.6), randf_range(-2.5, 1.5), randf_range(-0.6, 0.6)), randf_range(0.5, 1.0), 0.2 + f.R * 0.12, 0.03, Color(0.06, 0.03, 0.05, 0.95) if i % 2 == 0 else Color(1.0, 0.36, 0.08, 0.9))

# ---------------- what they see ----------------
func _sees(f: Realm.Fighter, e: Realm.Fighter, far: float) -> bool:
	if e.pos.distance_to(f.pos) > far: return false
	return Phys.line_of_sight(f.eye_at(), e.feet_mid() + Vector3(0, 0.3, 0)) and not rm.kit.smoked(f.eye_at(), e.feet_mid())

func _target(f: Realm.Fighter, far: float) -> Realm.Fighter:
	var best: Realm.Fighter = null; var bd := INF
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or is_mon(e): continue
		var d := e.pos.distance_to(f.pos)
		if d < bd and _sees(f, e, far): best = e; bd = d
	return best

func _walk(f: Realm.Fighter, dir: Vector2, sp: float, dt: float) -> void:
	var res := Phys.move_xz(f.pos, dir.x * sp * dt, dir.y * sp * dt, f.R * 0.8, minf(f.H, 2.4), 0.5); f.pos = res[0]
	var gy := Phys.ground_at(f.pos.x, f.pos.y, f.pos.z, f.R * 0.6)
	if f.pos.y > gy + 0.001: f.vy -= 19.0 * dt; f.pos.y = maxf(gy, f.pos.y + f.vy * dt)
	else: f.pos.y = gy; f.vy = 0.0
	f.vel = Vector3(dir.x * sp, 0, dir.y * sp)

func _face(f: Realm.Fighter, to: Vector3, dt: float, rate := 6.0) -> void:
	var d := to - f.eye_at()
	if d.length() < 0.01: return
	f.aim = f.aim.slerp(d.normalized(), minf(1.0, dt * rate)).normalized()

## a missile of theirs (the dagger can turn it back: RealmKit's own flight and parry)
func _throw(f: Realm.Fighter, kind: String, to: Vector3, speed: float, dmg: float, more := {}) -> Dictionary:
	var from := f.eye_at() + f.aim.normalized() * (f.R + 0.4)
	var s := {"kind": kind, "pos": from, "vel": (to - from).normalized() * speed, "dmg": dmg, "elem": "fire", "team": f.team, "by": f, "r": 0.18, "life": 3.0}
	s.merge(more, true)
	return rm.kit.shoot(s)

## a lobbed fire pot: its flight drawn to come down on the place
func _lob(f: Realm.Fighter, to: Vector3) -> void:
	var from := f.eye_at() + f.aim.normalized() * 0.6; var d := to - from; var flat := Vector2(d.x, d.z).length()
	var T := clampf(flat / 18.0, 0.7, 2.2); var g := 12.0
	var v := Vector3(d.x / T, (d.y + 0.5 * g * T * T) / T, d.z / T)
	rm.kit.shoot({"kind": "fball", "pos": from, "vel": v, "g": g, "dmg": LOB.dmg * 0.35, "elem": "fire", "team": f.team, "by": f, "r": 0.28, "life": T + 1.5,
		"boom": float(LOB.dmg), "boom_r": float(LOB.r), "burn": float(LOB.burn), "burn_t": float(LOB.burn_t), "size": Vector3(0.36, 0.36, 0.36), "col": Color(1.0, 0.45, 0.1, 1.0)})
	Snd.play("rd_lob", 0.8, from)

## a red line from one place to another, shown for so long (an aim; a hook)
func line(a: Vector3, b: Vector3, t: float, col := Color(1.0, 0.1, 0.1, 0.7), w := 0.05) -> Dictionary:
	var q := {"a": a, "b": b, "t": t, "col": col, "w": w, "node": null}
	if rm.en != null:
		var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w, w, 1.0); m.mesh = bm; m.material_override = _mat("line_%s" % col.to_html(), col); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root().add_child(m); q.node = m; _line_place(q)
	lines.push_back(q); return q

func _line_place(q: Dictionary) -> void:
	var m: MeshInstance3D = q.node
	if m == null or not is_instance_valid(m): return
	var a: Vector3 = q.a; var b: Vector3 = q.b; var L := maxf(0.01, a.distance_to(b))
	m.position = (a + b) * 0.5; m.scale = Vector3(1, 1, L)
	if (b - a).normalized().abs().y < 0.999: m.look_at(b, Vector3.UP)
	else: m.look_at(b, Vector3.FORWARD)

## a circle on the ground about to burst (a rift, a meteor): shown, then what it does (done: a Callable at the end)
func ring(at: Vector3, r: float, t: float, col: Color, done: Callable) -> Dictionary:
	var q := {"at": at, "r": r, "t": t, "t0": t, "done": done, "node": null}
	if rm.en != null:
		var m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.04; cm.radial_segments = 24; m.mesh = cm
		m.material_override = _mat("ring_%s" % col.to_html(), col); m.position = at + Vector3(0, 0.07, 0); m.scale = Vector3(r * 0.2, 1, r * 0.2); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root().add_child(m); q.node = m
	rings.push_back(q); return q

# ---------------- their turns ----------------
func turn(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	b.cd = float(b.cd) - dt; b.cd2 = float(b.get("cd2", 0.0)) - dt; b.st = float(b.st) + dt; b.t = float(b.t) + dt
	b.stagger = maxf(0.0, float(b.get("stagger", 0.0)) - dt)
	if not b.awake:
		f.vel = Vector3.ZERO
		if _waken(f): b.awake = true; b.cd = randf_range(0.6, 1.4); Snd.play("rd_wake", 0.7, f.feet_mid())
		return
	if bool(KINDS[kind_of(f)].get("boss", false)) or kind_of(f) == "beast": f.stun_t = 0.0   # (a blow's jolt does not hold the great ones; only a stagger does)
	if f.stun_t > 0.0 or float(b.stagger) > 0.0: f.vel = Vector3.ZERO; b.state = "idle"; return
	match kind_of(f):
		"guard": _guard(f, dt)
		"sniper": _sniper(f, dt)
		"beast": _beast(f, dt)
		"defender": _defender(f, dt)
		"imp": _imp(f, dt)
		"karnok": _karnok(f, dt)
		"baal": _baal(f, dt)

## asleep till one of the party is in its section, or near and seen
func _waken(f: Realm.Fighter) -> bool:
	if bool(f.brain.get("woken", false)): return true
	if f.hp < f.max_hp - 0.5 or f.shield < float(KINDS[kind_of(f)].get("shield", 0.0)) - 0.5: return true   # (struck: awake, whoever struck from wherever)
	var sec := int(f.brain.sec); var k := kind_of(f)
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or is_mon(e): continue
		if k == "karnok":   # (inside the tower)
			if Vector2(e.pos.x - DemonRoad.TC.x, e.pos.z - DemonRoad.TC.y).length() < DemonRoad.T_IN and e.pos.y > -1.0: return true
			continue
		if k == "baal":   # (up on the altar's floor)
			if Vector2(e.pos.x - DemonRoad.AC.x, e.pos.z - DemonRoad.AC.y).length() < DemonRoad.AR - 1.0 and e.pos.y > DemonRoad.A_Y - 1.5: return true
			continue
		if DemonRoad.section_of(e.pos) == sec: return true
		if e.pos.distance_to(f.pos) < 24.0 and _sees(f, e, 24.0): return true
	return false

func _slowed(f: Realm.Fighter) -> float:
	var m := 1.0
	for k in f.slows: m = minf(m, float(f.slows[k][0]))
	return m

func _guard(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain; var tg := _target(f, float(KINDS.guard.sight))
	if tg == null:   # back to its post
		var home: Vector3 = b.post; var d := Vector2(home.x - f.pos.x, home.z - f.pos.z)
		if d.length() > 1.0: _walk(f, d.normalized(), float(KINDS.guard.speed) * 0.7, dt); _face(f, Vector3(home.x, f.eye_at().y, home.z), dt)
		else: f.vel = Vector3.ZERO
		b.state = "idle"; return
	_face(f, tg.feet_mid(), dt, 8.0)
	var dist := tg.pos.distance_to(f.pos)
	match str(b.state):
		"wind":   # the halberd raised: it comes down
			f.vel = Vector3.ZERO
			if float(b.st) >= float(HALBERD.wind):
				b.state = "swing"; b.st = 0.0; Snd.play("rd_swing", 0.9, f.feet_mid())
				for e: Realm.Fighter in rm.kit.arc(f, float(HALBERD.reach), float(HALBERD.arc)): rm.hurt(e, float(HALBERD.dmg), "fire", f, {"melee": true, "src": "halberd"})
			return
		"swing":
			if float(b.st) > 0.35: b.state = "idle"
			return
	if dist < float(HALBERD.reach) + tg.R and float(b.cd) <= 0.0:
		b.state = "wind"; b.st = 0.0; b.cd = float(HALBERD.cd); return
	if dist > float(SPEAR.near) and dist < float(SPEAR.far) and float(b.cd2) <= 0.0:
		_throw(f, "fspear", tg.feet_mid() + tg.vel * (dist / float(SPEAR.speed)) * 0.6, float(SPEAR.speed), float(SPEAR.dmg), {"size": Vector3(0.08, 0.08, 1.4), "col": Color(1.0, 0.5, 0.15, 1.0)})
		b.cd2 = randf_range(SPEAR.cd[0], SPEAR.cd[1]); Snd.play("rd_throw", 0.8, f.feet_mid())
	# close in, but not past its leash
	var home: Vector3 = b.post
	var want := Vector2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z)
	if dist < float(HALBERD.reach) * 0.8: f.vel = Vector3.ZERO; return
	var next := f.pos + Vector3(want.normalized().x, 0, want.normalized().y)
	if Vector2(next.x - home.x, next.z - home.z).length() > float(KINDS.guard.leash): f.vel = Vector3.ZERO; return
	_walk(f, want.normalized(), float(KINDS.guard.speed) * _slowed(f), dt)

func _sniper(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if str(b.state) == "aim":
		var tg: Realm.Fighter = b.tgt
		if tg == null or not tg.alive or not _sees(f, tg, float(KINDS.sniper.sight)):
			b.state = "idle"; _drop_line(b); return
		_face(f, tg.feet_mid(), dt, 10.0)
		var q: Dictionary = b.line; q.a = f.eye_at(); q.b = tg.feet_mid(); q.t = 0.2; _line_place(q)
		if float(b.st) >= float(LANCE.aim):
			_throw(f, "lance", tg.feet_mid(), float(LANCE.speed), float(LANCE.dmg), {"shove": float(LANCE.shove), "size": Vector3(0.1, 0.1, 2.0), "col": Color(1.0, 0.2, 0.1, 1.0), "r": 0.12})
			Snd.play("rd_lance", 1.0, f.eye_at()); b.state = "idle"; b.cd = float(LANCE.cd); _drop_line(b)
		return
	if float(b.cd) > 0.0: return
	var tg2 := _target(f, float(KINDS.sniper.sight))
	if tg2 == null: return
	b.state = "aim"; b.st = 0.0; b.tgt = tg2; b.line = line(f.eye_at(), tg2.feet_mid(), 0.2, Color(1.0, 0.12, 0.1, 0.75), 0.04)
	Snd.play("rd_aim", 0.7, f.eye_at())

func _drop_line(b: Dictionary) -> void:
	if b.has("line"): (b.line as Dictionary).t = 0.0
	b.erase("line")

func _defender(f: Realm.Fighter, _dt: float) -> void:
	var b := f.brain
	var tg := _target(f, float(KINDS.defender.sight))
	if tg == null: b.state = "idle"; return
	_face(f, tg.feet_mid(), _dt, 6.0)
	if float(b.cd) <= 0.0:
		b.state = "throw"; b.st = 0.0
		_lob(f, tg.pos + tg.vel * 0.6)
		b.cd = randf_range(LOB.cd[0], LOB.cd[1])
	elif float(b.st) > 0.4: b.state = "idle"

## the bridge's beast: it roars, then charges along the planks; whoever it meets is thrown aside
func _beast(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain; var tg := _target(f, float(KINDS.beast.sight))
	match str(b.state):
		"warn":
			f.vel = Vector3.ZERO
			if tg != null: _face(f, tg.feet_mid(), dt, 4.0)
			if float(b.st) >= float(CHARGE.warn):
				b.state = "charge"; b.st = 0.0; b.hit = {}
				var d := Vector3(f.aim.x, 0, f.aim.z).normalized(); b.dir = d; Snd.play("rd_charge", 1.0, f.feet_mid())
			return
		"charge":
			var d: Vector3 = b.dir; var before := f.pos
			_walk(f, Vector2(d.x, d.z), float(CHARGE.speed) * _slowed(f), dt)
			for e: Realm.Fighter in rm.all:
				if not e.alive or e.team == f.team or is_mon(e) or (b.hit as Dictionary).has(e.id): continue
				if Vector2(e.pos.x - f.pos.x, e.pos.z - f.pos.z).length() < f.R + e.R + 0.8 and absf(e.pos.y - f.pos.y) < 2.0:
					(b.hit as Dictionary)[e.id] = true
					rm.hurt(e, float(CHARGE.dmg), "physical", f, {"melee": true, "src": "charge"})
					var side := Vector3(-d.z, 0, d.x) * (1.0 if (e.pos - f.pos).dot(Vector3(-d.z, 0, d.x)) >= 0.0 else -1.0)
					rm.shove(e, (d + side * float(CHARGE.side)).normalized(), float(CHARGE.shove)); Snd.play("rd_thud", 1.0, e.feet_mid())
			if float(b.st) >= float(CHARGE.t) or before.distance_to(f.pos) < float(CHARGE.speed) * dt * 0.2:
				b.state = "rest"; b.st = 0.0; b.cd2 = float(CHARGE.cd)
			return
		"rest":
			f.vel = Vector3.ZERO
			if float(b.st) > 1.4: b.state = "idle"
			return
		"wind":
			f.vel = Vector3.ZERO
			if float(b.st) >= float(SLAM.wind):
				b.state = "rest"; b.st = 0.6; Snd.play("rd_slam", 1.0, f.feet_mid())
				for e: Realm.Fighter in rm.all:
					if not e.alive or e.team == f.team or is_mon(e): continue
					if e.pos.distance_to(f.pos) < float(SLAM.r) + e.R and absf(e.pos.y - f.pos.y) < 2.5:
						rm.hurt(e, float(SLAM.dmg), "physical", f, {"aoe": true, "src": "slam"}); rm.shove(e, e.pos - f.pos, float(SLAM.shove))
				if rm.look != null: rm.look.burst(f.pos + Vector3(0, 0.2, 0), float(SLAM.r), "fire")
			return
	if tg == null: f.vel = Vector3.ZERO; return
	_face(f, tg.feet_mid(), dt, 3.0)
	var dist := Vector2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z).length()
	if dist < float(SLAM.r) and float(b.cd) <= 0.0: b.state = "wind"; b.st = 0.0; b.cd = float(SLAM.cd); return
	if dist > float(CHARGE.near) and dist < float(CHARGE.far) and float(b.cd2) <= 0.0: b.state = "warn"; b.st = 0.0; Snd.play("rd_roar", 1.0, f.feet_mid()); return
	var want := Vector2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z).normalized()
	_walk(f, want, float(KINDS.beast.speed) * _slowed(f), dt)

## an imp: in the air a few metres up, darting about whoever it hunts, fire bolts
func _imp(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain; var tg := _target(f, float(KINDS.imp.sight))
	var gy := Phys.ground_at(f.pos.x, f.pos.y + 0.2, f.pos.z, 0.3)
	var want_y := gy + 2.6 + sin(float(b.t) * 1.7) * 0.6
	var mv := Vector3.ZERO
	if tg != null:
		_face(f, tg.feet_mid(), dt, 8.0)
		var to := Vector3(tg.pos.x - f.pos.x, 0, tg.pos.z - f.pos.z); var d := to.length()
		var side := Vector3(-to.z, 0, to.x).normalized() * (1.0 if int(b.t / 1.6) % 2 == 0 else -1.0)
		mv = (to.normalized() * (1.0 if d > 9.0 else (-0.6 if d < 5.0 else 0.0)) + side * 0.8).normalized()
		if float(b.cd) <= 0.0 and _sees(f, tg, float(KINDS.imp.sight)):
			_throw(f, "fbolt", tg.feet_mid(), float(BOLT.speed), float(BOLT.dmg), {"size": Vector3(0.12, 0.12, 0.5), "col": Color(0.7, 0.3, 1.0, 1.0)})
			b.cd = randf_range(BOLT.cd[0], BOLT.cd[1]); Snd.play("rd_bolt", 0.6, f.eye_at())
	var sp := float(KINDS.imp.speed) * _slowed(f)
	var q := Phys.move_xz(f.pos, mv.x * sp * dt, mv.z * sp * dt, f.R, f.H, 1.5); f.pos = q[0]
	f.pos.y = lerpf(f.pos.y, want_y, minf(1.0, dt * 3.0))
	f.vel = mv * sp

# ---------------- Karnok, the chain executioner (④ the tower's stair) ----------------
## phase 1 (100%..50%): on the balcony over the well, bombarding the stair: chain javelins (turned back by a dagger: 450
## and much of his shield), the fire wave rolling down the spiral, two obsidian anchors in the well mending his shield.
## phase 2 (50%..0): down onto the stair, after you: the chain whirlwind, the hook and the execution.
func _karnok(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain; var K := KARNOK
	if not b.has("phase"):
		b.phase = 1; b.jav_t = 2.0; b.wave_t = 8.0; b.spin_t = 6.0; b.hook_t = 9.0; b.anchors = []
		mode.boss_awake(f)
	var ph := int(b.phase)
	if ph == 1:
		_anchors_tick(f, dt)
		if f.hp <= f.max_hp * float(K.phase2) and str(b.state) != "roar":
			b.state = "roar"; b.st = 0.0; f.inv = float(K.roar) + 0.5; Snd.play("rd_roar_big", 1.2, f.feet_mid()); mode.boss_says(f, "카르녹이 난간을 부수고 뛰어내립니다!")
		if str(b.state) == "roar":
			f.vel = Vector3.ZERO
			if float(b.st) >= float(K.roar): _karnok_down(f)
			return
		var tg := _target(f, 70.0)
		if tg != null: _face(f, tg.feet_mid(), dt, 5.0)
		b.jav_t = float(b.jav_t) - dt; b.wave_t = float(b.wave_t) - dt
		if str(b.state) == "slam":
			if float(b.st) >= float(K.wave_wind): b.state = "idle"; _fire_wave(f)
			return
		if float(b.wave_t) <= 0.0:
			b.state = "slam"; b.st = 0.0; b.wave_t = float(K.wave_cd); Snd.play("rd_slam_big", 1.2, f.feet_mid()); return
		if tg != null and float(b.jav_t) <= 0.0:
			b.state = "throw"; b.st = 0.0; b.jav_t = float(K.jav_cd)
			var lead := tg.vel * (tg.pos.distance_to(f.pos) / float(K.jav_speed)) * 0.5
			_throw(f, "jav", tg.feet_mid() + lead, float(K.jav_speed), float(K.jav), {"shove": float(K.jav_shove), "turned_dmg": float(K.jav_back), "turned_cut": float(K.jav_cut),
				"size": Vector3(0.14, 0.14, 2.4), "col": Color(1.0, 0.3, 0.12, 1.0), "r": 0.22, "life": 4.0})
			Snd.play("rd_jav", 1.0, f.eye_at())
		elif float(b.st) > 0.5 and str(b.state) == "throw": b.state = "idle"
		return
	# phase 2: on the stair, after you
	b.spin_t = float(b.spin_t) - dt; b.hook_t = float(b.hook_t) - dt
	match str(b.state):
		"spin":
			b.spin_a = float(b.get("spin_a", 0.0)) + dt * 14.0
			var tg := _target(f, 60.0)
			if tg != null: _walk(f, Vector2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z).normalized(), float(K.spin_speed) * _slowed(f), dt)
			b.tick = float(b.get("tick", 0.0)) - dt
			if float(b.tick) <= 0.0:
				b.tick = 0.5
				for e: Realm.Fighter in rm.all:
					if e.alive and e.team != f.team and not is_mon(e) and e.pos.distance_to(f.pos) < float(K.spin_r) + e.R and absf(e.pos.y - f.pos.y) < 3.0:
						rm.hurt(e, float(K.spin_dmg), "fire", f, {"aoe": true, "src": "spin"})
				Snd.play("rd_chain_spin", 0.8, f.feet_mid())
			if float(b.st) >= float(K.spin_t): b.state = "idle"; b.spin_t = float(K.spin_cd)
			return
		"hook_warn":
			f.vel = Vector3.ZERO
			var v: Realm.Fighter = b.victim
			if v == null or not v.alive: b.state = "idle"; return
			var q: Dictionary = b.line; q.a = f.eye_at(); q.b = v.feet_mid(); q.t = 0.2; _line_place(q)
			if float(b.st) >= float(K.hook_warn):
				# the hook bites: he hauls whoever it caught to his feet (on the steps, not over the well), then the axe goes up
				var gap := Vector3(v.pos.x - f.pos.x, 0, v.pos.z - f.pos.z)
				var to := f.pos + (gap.normalized() if gap.length() > 0.1 else Vector3(f.aim.x, 0, f.aim.z).normalized()) * (f.R + 1.4)
				to.y = Phys.ground_at(to.x, f.pos.y + 1.0, to.z, 0.3)
				var mine := DemonRoad.on_stair(f.pos)
				if to.y < f.pos.y - 1.5 and not mine.is_empty():
					var vs := DemonRoad.on_stair(v.pos)
					var side := signf(float(vs[0]) - float(mine[0])) if not vs.is_empty() and absf(float(vs[0]) - float(mine[0])) > 0.5 else 1.0
					to = DemonRoad.stair_point(clampf(float(mine[0]) + side * 9.0, 1.0, DemonRoad.SPIRAL - 1.0), 13.0)
				v.pos = to; v.vel = Vector3.ZERO; v.push = Vector3.ZERO
				if v.me and rm.player != null: rm.player.pos = to; rm.player.vel = Vector3.ZERO
				rm.astray(v); v.stun_t = maxf(v.stun_t, float(K.hook_wind))
				b.state = "hook_wind"; b.st = 0.0; b.taken = 0.0; b.hp0 = f.hp + f.shield; Snd.play("rd_hook", 1.0, v.feet_mid()); mode.boss_says(f, "%s이(가) 갈고리에 끌려갔습니다 · 붉은 영혼 코어를 쏘거나 폭탄을 던지세요!" % Races.R.get(v.race, {"name": v.name}).name if not is_mon(v) else v.name)
				_drop_line(b)
			return
		"hook_wind":
			f.vel = Vector3.ZERO
			var v2: Realm.Fighter = b.victim
			if v2 == null or not v2.alive: b.state = "idle"; return
			v2.stun_t = maxf(v2.stun_t, 0.1)
			b.taken = float(b.hp0) - (f.hp + f.shield)
			if float(b.taken) >= float(K.hook_cancel): _karnok_cancel(f, "core"); return
			if float(b.st) >= float(K.hook_wind):
				Snd.play("rd_axe", 1.2, v2.feet_mid()); rm.hurt(v2, float(K.hook_axe), "physical", f, {"fixed": true, "melee": true, "src": "execute"})
				b.state = "idle"; b.hook_t = float(K.hook_cd); mode.boss_says(f, "처형 도끼가 내려쳤습니다")
			return
	var tg2 := _target(f, 60.0)
	if tg2 == null: f.vel = Vector3.ZERO; return
	_face(f, tg2.feet_mid(), dt, 6.0)
	if float(b.hook_t) <= 0.0:
		var cands: Array = rm.all.filter(func(e): return e.alive and e.team != f.team and not is_mon(e) and e.pos.distance_to(f.pos) < float(K.hook_range) and _sees(f, e, float(K.hook_range)))
		if not cands.is_empty():
			var v3: Realm.Fighter = cands[randi() % cands.size()]
			b.victim = v3; b.state = "hook_warn"; b.st = 0.0; b.line = line(f.eye_at(), v3.feet_mid(), 0.2, Color(1.0, 0.25, 0.1, 0.85), 0.07)
			Snd.play("rd_chain", 1.0, f.eye_at()); return
	if float(b.spin_t) <= 0.0: b.state = "spin"; b.st = 0.0; b.tick = 0.0; Snd.play("rd_roar", 1.0, f.feet_mid()); return
	var dist := tg2.pos.distance_to(f.pos)
	if dist < 3.2 and float(b.cd) <= 0.0:
		b.cd = 1.6; Snd.play("rd_swing", 1.0, f.feet_mid())
		for e: Realm.Fighter in rm.kit.arc(f, 3.4, 1.0): rm.hurt(e, 48.0, "physical", f, {"melee": true, "src": "axe"})
	if dist > 2.4: _stalk(f, tg2, float(KINDS.karnok.speed) * _slowed(f), dt)
	else: f.vel = Vector3.ZERO

## along the stair toward someone (round it, up or down, as the steps go), or straight at him off it
func _stalk(f: Realm.Fighter, tg: Realm.Fighter, sp: float, dt: float) -> void:
	var me_on := DemonRoad.on_stair(f.pos); var him := DemonRoad.on_stair(tg.pos)
	var to := tg.pos
	if not me_on.is_empty() and not him.is_empty() and absf(float(him[0]) - float(me_on[0])) > 10.0:
		var u := float(me_on[0]) + signf(float(him[0]) - float(me_on[0])) * 14.0
		to = DemonRoad.stair_point(clampf(u, 1.0, DemonRoad.SPIRAL - 1.0), 13.0)
	elif not me_on.is_empty() and him.is_empty() and tg.pos.y < f.pos.y - 3.0:
		to = DemonRoad.stair_point(maxf(1.0, float(me_on[0]) - 14.0), 13.0)   # (he is below: down the steps)
	_walk(f, Vector2(to.x - f.pos.x, to.z - f.pos.z).normalized(), sp, dt)

## the hook's execution stopped: his core shot through or a bomb burst on him. He reels
func _karnok_cancel(f: Realm.Fighter, why: String) -> void:
	var b := f.brain
	var v: Realm.Fighter = b.get("victim")
	if v != null: v.stun_t = 0.0
	b.state = "idle"; b.stagger = float(KARNOK.stagger); b.hook_t = float(KARNOK.hook_cd)
	Snd.play("rd_stagger", 1.1, f.feet_mid()); mode.boss_says(f, "처형을 막았습니다 · 카르녹이 비틀거립니다" if why == "core" else "폭탄에 처형이 끊겼습니다 · 카르녹이 비틀거립니다")
	mode.gimmick("hook_cancel")

## a bomb of the party's burst: Karnok's execution, Baal's eclipse (ModeRaid tells: RealmKit's flask burst)
func bomb_burst(at: Vector3) -> void:
	for f: Realm.Fighter in rm.all:
		if not f.alive or not is_mon(f): continue
		var b := f.brain
		if kind_of(f) == "karnok" and str(b.state) == "hook_wind" and f.pos.distance_to(at) < float(KARNOK.hook_bomb_r) + f.R: _karnok_cancel(f, "bomb")
		if kind_of(f) == "baal" and str(b.state) == "eclipse" and f.pos.distance_to(at) < float(BAAL.eclipse_bomb_r) + f.R:
			b.cast = float(b.cast) + float(BAAL.eclipse_bomb); Snd.play("rd_cool", 1.0, f.feet_mid()); mode.boss_says(f, "연금술 폭탄이 과열을 식힙니다 · 영창 +2.5초"); mode.gimmick("eclipse_delay")

## what happens when someone hurts a lord: Karnok's core during the axe, his back in phase 2; Baal's crash
func dmg_mul(by: Realm.Fighter, v: Realm.Fighter) -> float:
	var m := 1.0
	if not is_mon(v) or by == null: return m
	var b := v.brain
	match kind_of(v):
		"karnok":
			if int(b.get("phase", 1)) == 2 and by.pos.distance_to(v.pos) < 12.0:
				var to := Vector3(by.pos.x - v.pos.x, 0, by.pos.z - v.pos.z).normalized()
				if to.dot(Vector3(v.aim.x, 0, v.aim.z).normalized()) < -0.4: m *= float(KARNOK.behind)   # (his back, where a blink takes a demon)
			if float(b.get("stagger", 0.0)) > 0.0: m *= 1.3
		"baal":
			if float(b.get("crash", 0.0)) > 0.0: m *= float(BAAL.crash_mul)
			if str(b.state) == "eclipse": m *= float(BAAL.eclipse_mul)
	return m

func _karnok_down(f: Realm.Fighter) -> void:
	var b := f.brain
	b.phase = 2; b.state = "leap"; b.st = 0.0
	for th: Dictionary in b.anchors: th.hp = 0.0
	b.anchors = []
	var to := DemonRoad.stair_point(DemonRoad.SPIRAL * 0.5, 13.0)
	f.pos = to; f.vel = Vector3.ZERO; f.inv = 0.6
	b.state = "idle"; b.cd = 1.0; b.spin_t = 5.0; b.hook_t = 8.0
	Snd.play("rd_land_big", 1.3, to)
	if rm.look != null: rm.look.burst(to + Vector3(0, 0.2, 0), 5.0, "fire")
	mode.karnok_phase2()

## the two obsidian anchors floating in the well: while one stands his shield mends 200 a second; only arcane and
## physical blows break them (fire and alchemy do nothing)
func _anchors_tick(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if not b.has("anchored"):
		b.anchored = true
		var made := []
		for q: Array in [[DemonRoad.TC.x - 2.4, 9.0, DemonRoad.TC.y + 0.0], [DemonRoad.TC.x + 2.4, 15.0, DemonRoad.TC.y + 0.0]]:
			var th := rm.kit.add_thing({"kind": "anchor", "team": "them", "pos": Vector3(q[0], q[1], q[2]), "r": 0.7, "h": 1.6, "hp": float(KARNOK.anchor_hp), "max": float(KARNOK.anchor_hp), "made": true, "node": gem("anchor", Vector3(q[0], q[1], q[2])),
				"elems": ["arcane", "physical"], "label": "흑요석 결계 수정", "dead": func(_by): Snd.play("rd_shatter", 1.2, Vector3(q[0], q[1], q[2])); mode.boss_says(f, "결계 수정이 부서졌습니다")})
			made.push_back(th)
		b.anchors = made
	var up := 0
	for th: Dictionary in b.anchors:
		if float(th.hp) > 0.0:
			up += 1; var p: Vector3 = th.pos; th.pos = Vector3(p.x, p.y + sin(rm.clock * 1.3 + p.x) * 0.004, p.z)
	if up > 0: f.shield = minf(float(KINDS.karnok.shield), f.shield + float(KARNOK.anchor_regen) * dt)

## the slam sends a wave of lava rolling down the spiral from its top: whoever's feet are on the steps as it passes burns
func _fire_wave(f: Realm.Fighter) -> void:
	var w := {"kind": "spiral", "u": DemonRoad.SPIRAL, "hit": {}, "by": f, "node": null}
	if rm.en != null:
		var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(3.6, 0.75, 1.4); m.mesh = bm; m.material_override = _mat("wave", Color(1.0, 0.4, 0.05, 0.85)); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root().add_child(m); w.node = m
	waves.push_back(w); Snd.play("rd_wave", 1.0, f.feet_mid())
	mode.boss_says(f, "나선 화염 파동 · 점프하거나 벽의 석조 장식 위로!")

# ---------------- Baal, lord of the abyss (⑤ the sky altar) ----------------
## phase 1 (100%..65%): in the altar's middle; his fire barrier (turned fireballs strip it); the triple fan, the binding
## chains, the sulfur rifts. phase 2 (65%..30%): wings, three pillars broken, in the air 15 m up: meteors, the soul drain,
## the abyssal sun with its two wing cores and four imps. phase 3 (30%..0): the rim falls, no cover, the furnace about
## him, the triple magma sword; at 10% the eclipse of doom (12 s to kill him, or the tower's top is gone)
func _baal(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain; var B := BAAL
	if not b.has("phase"):
		b.phase = 1; b.fan_t = 4.0; b.bind_t = float(B.bind_first); b.rift_t = 7.0; b.claw_t = 2.0; b.calm = 9.0
		b.meteor_t = 4.0; b.drain_t = 9.0; b.sun_t = 2.0; b.sword_t = 5.0; b.binds = []; b.cores = []; b.suns = 0; b.ecl = false
		mode.boss_awake(f)
	b.calm = float(b.calm) + dt
	if f.hp + f.shield < float(b.get("last", INF)) - 0.01: b.calm = 0.0   # (struck: his barrier waits before it mends)
	b.last = f.hp + f.shield
	b.crash = maxf(0.0, float(b.get("crash", 0.0)) - dt)
	var ph := int(b.phase); var fr := f.hp / f.max_hp
	# the barrier (phase 1) mends when he is left alone a while
	if ph == 1 and float(b.calm) > float(B.barrier_wait): f.shield = minf(float(KINDS.baal.shield), f.shield + float(B.barrier_regen) * dt)
	_binds_tick(f, dt)
	if ph == 1 and fr <= float(B.phase2): _baal_rise(f); return
	if ph == 2 and fr <= float(B.phase3): _baal_fall(f); return
	if ph == 3 and fr <= float(B.eclipse_at) and not bool(b.ecl): _eclipse(f); return
	match str(b.state):
		"rise", "slam":
			f.vel = Vector3.ZERO
			if str(b.state) == "rise": f.pos.y = lerpf(f.pos.y, DemonRoad.A_Y + float(B.hover), minf(1.0, dt * 2.0))
			if float(b.st) >= 2.2: b.state = "idle"
			return
		"eclipse":
			f.vel = Vector3.ZERO
			b.cast = float(b.cast) - dt
			if float(b.cast) <= 0.0: mode.eclipse_done(); b.state = "idle"
			return
	var rage := float(B.rage) if ph == 3 else 1.0
	var tg := _target(f, float(KINDS.baal.sight))
	if tg != null: _face(f, tg.feet_mid(), dt, 4.0)
	if ph == 2:
		_air(f, dt)
		b.meteor_t = float(b.meteor_t) - dt; b.drain_t = float(b.drain_t) - dt; b.sun_t = float(b.sun_t) - dt
		_meteors(f, dt); _drain(f, dt); _sun(f, dt)
		if b.has("sun"): return   # (the sun takes all of him while it charges: no meteors, no drain)
		if float(b.meteor_t) <= 0.0 and not b.has("shower"): b.shower = float(B.meteor_t); b.mt = 0.0; b.meteor_t = float(B.meteor_cd); mode.boss_says(f, "연옥의 유성우 · 남은 석주 뒤로!")
		if float(b.drain_t) <= 0.0 and not b.has("drain"): _drain_start(f)
		if float(b.sun_t) <= 0.0 and not b.has("sun"): _sun_start(f)
		return
	# phases 1 and 3 on the floor
	b.fan_t = float(b.fan_t) - dt * rage; b.claw_t = float(b.claw_t) - dt * rage
	if ph == 1: b.bind_t = float(b.bind_t) - dt; b.rift_t = float(b.rift_t) - dt
	if ph == 3: b.sword_t = float(b.sword_t) - dt * rage; _aura(f, dt)
	match str(b.state):
		"fan":
			f.vel = Vector3.ZERO
			if float(b.st) >= float(b.get("next", 0.0)):
				_fan(f); b.waves_left = int(b.waves_left) - 1; b.next = float(b.st) + float(B.fan_gap) / rage
				if int(b.waves_left) <= 0: b.state = "idle"
			return
		"claw":
			f.vel = Vector3.ZERO
			if float(b.st) >= float(B.claw_wind) / rage:
				b.state = "idle"; Snd.play("rd_swing_big", 1.1, f.feet_mid())
				for e: Realm.Fighter in rm.kit.arc(f, float(B.claw_reach), float(B.claw_arc)): rm.hurt(e, float(B.claw_dmg), "physical", f, {"melee": true, "src": "claw"})
			return
		"sword":
			f.vel = Vector3.ZERO
			var n := int(b.swings)
			if float(b.st) >= float(b.next):
				if n < 2:
					Snd.play("rd_swing_big", 1.2, f.feet_mid())
					for e: Realm.Fighter in rm.kit.arc(f, float(B.sword_reach), 1.3): rm.hurt(e, float(B.sword_dmg), "fire", f, {"melee": true, "src": "magma"})
					b.swings = n + 1; b.next = float(b.st) + (0.7 if n == 0 else 0.9) / rage
				else:
					_magma_ring(f); b.state = "idle"
			return
	if ph == 1 and float(b.bind_t) <= 0.0: _bind(f); b.bind_t = float(B.bind_cd); return
	if ph == 1 and float(b.rift_t) <= 0.0: _rifts(f); b.rift_t = float(B.rift_cd); return
	if ph == 3 and float(b.sword_t) <= 0.0: b.state = "sword"; b.st = 0.0; b.swings = 0; b.next = 0.5; b.sword_t = float(B.sword_cd); mode.boss_says(f, "대군주의 3연격 마그마 검기 · 세 번째는 제단 전체 · 점프!"); return
	if tg != null and tg.pos.distance_to(f.pos) < float(B.claw_reach) and float(b.claw_t) <= 0.0: b.state = "claw"; b.st = 0.0; b.claw_t = float(B.claw_cd); return
	if tg != null and float(b.fan_t) <= 0.0: b.state = "fan"; b.st = 0.0; b.waves_left = int(B.fan_waves); b.next = 0.3; b.fan_t = float(B.fan_cd); Snd.play("rd_charge_fire", 1.0, f.eye_at()); return
	# about the middle, never far
	var home := Vector3(DemonRoad.AC.x, DemonRoad.A_Y, DemonRoad.AC.y)
	if tg != null and tg.pos.distance_to(f.pos) > 8.0 and Vector2(f.pos.x - home.x, f.pos.z - home.z).length() < 8.0:
		_walk(f, Vector2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z).normalized(), float(KINDS.baal.speed) * _slowed(f) * rage, dt)
	elif Vector2(f.pos.x - home.x, f.pos.z - home.z).length() > 3.0: _walk(f, Vector2(home.x - f.pos.x, home.z - f.pos.z).normalized(), float(KINDS.baal.speed), dt)
	else: f.vel = Vector3.ZERO

## the triple fan: a spread of fireballs over 120 degrees before him (a dagger turns one back: it strips 400 of his barrier)
func _fan(f: Realm.Fighter) -> void:
	var B := BAAL; var n := int(B.fan_n); var fwd := Vector3(f.aim.x, 0, f.aim.z).normalized()
	for i in n:
		var a := deg_to_rad(-float(B.fan_arc) * 0.5 + float(B.fan_arc) * i / maxf(1.0, n - 1.0))
		var d := fwd.rotated(Vector3.UP, a)
		var from := f.pos + Vector3(0, f.H * 0.55, 0) + d * (f.R + 0.6)
		rm.kit.shoot({"kind": "hfire", "pos": from, "vel": (d + Vector3(0, -0.12, 0)).normalized() * float(B.fan_speed), "dmg": float(B.fan_dmg), "elem": "fire", "team": f.team, "by": f, "r": 0.3, "life": 2.4,
			"turned_dmg": float(B.fan_dmg) * 2.0, "turned_cut": float(B.turned_cut), "size": Vector3(0.5, 0.5, 0.5), "col": Color(1.0, 0.35, 0.08, 1.0)})
	Snd.play("rd_fan", 1.0, f.eye_at())

## the binding chains: two of the party tied to the stakes at the edge; four seconds to break each, or be dragged over
func _bind(f: Realm.Fighter) -> void:
	var b := f.brain; var B := BAAL
	var cands: Array = rm.all.filter(func(e): return e.alive and e.team != f.team and not is_mon(e))
	cands.shuffle()
	for v: Realm.Fighter in cands.slice(0, 2):
		var stake: Vector3 = road.stakes[0]
		for s: Vector3 in road.stakes:
			if s.distance_to(v.pos) < stake.distance_to(v.pos): stake = s
		var mid := (v.pos + stake) * 0.5 + Vector3(0, 1.0, 0)
		var th := rm.kit.add_thing({"kind": "chain", "team": "them", "pos": mid - Vector3(0, 0.6, 0), "r": 0.9, "h": 1.4, "hp": float(B.bind_hp), "max": float(B.bind_hp), "made": true, "label": "구속의 혈약 사슬", "node": gem("chain", mid)})
		var q := {"v": v, "stake": stake, "t": float(B.bind_t), "thing": th, "line": line(v.feet_mid(), stake + Vector3(0, 1.0, 0), float(B.bind_t) + 0.5, Color(0.9, 0.1, 0.2, 0.9), 0.12)}
		(b.binds as Array).push_back(q)
		Snd.play("rd_chain", 1.0, v.feet_mid())
	mode.boss_says(f, "구속의 혈약 사슬 · 4초 안에 사슬을 끊으세요 (물리 공격이 잘 듭니다)")

func _binds_tick(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if not b.has("binds"): return
	for i in range((b.binds as Array).size() - 1, -1, -1):
		var q: Dictionary = b.binds[i]; var v: Realm.Fighter = q.v; var th: Dictionary = q.thing
		q.t = float(q.t) - dt
		var ln: Dictionary = q.line; ln.a = v.feet_mid(); ln.t = 0.3; _line_place(ln)
		if float(th.hp) <= 0.0 or not v.alive:
			ln.t = 0.0; b.binds.remove_at(i)
			if v.alive: Snd.play("rd_shatter", 0.9, v.feet_mid()); mode.gimmick("chain_break")
			continue
		th.pos = (v.pos + (q.stake as Vector3)) * 0.5 + Vector3(0, 0.4, 0)
		rm.slow(v, "bind", float(BAAL.bind_slow), 0.2)
		if float(q.t) <= 0.0:   # dragged over the edge, into the lava
			ln.t = 0.0; th.hp = 0.0; b.binds.remove_at(i)
			var out := Vector3(v.pos.x - DemonRoad.AC.x, 0, v.pos.z - DemonRoad.AC.y).normalized()
			rm.slay(v, f, {"src": "bind"}); mode.boss_says(f, "%s이(가) 사슬에 끌려 용암 심연으로 떨어졌습니다" % (Races.R[v.race].name if Races.R.has(v.race) else v.name))
			if rm.fx != null: rm.fx.puff(v.pos + out * 3.0, 6, 1.0, 1.2)

## the sulfur rifts: red cracks over four tenths of the floor (the paper's); 1.8 s later they burst. They keep off the
## cooling circles, where the burn they leave goes out. The floor is counted in cells a metre square: one rift after
## another goes where it covers the most not yet covered (of a few tried), till four tenths of the cells are under them
func _rifts(f: Realm.Fighter) -> void:
	var B := BAAL; var R := float(B.rift_r)
	var reach := DemonRoad.AR_SMALL if road.rim_down else DemonRoad.AR
	var n_cells := 0; var k := int(reach)
	for ix in range(-k, k + 1):
		for iz in range(-k, k + 1):
			if ix * ix + iz * iz <= reach * reach: n_cells += 1
	var hit := {}; var placed: Array = []
	while float(hit.size()) < float(B.rift_cover) * n_cells and placed.size() < int(B.rift_max):
		var best := Vector2.INF; var gain := 0; var best_cells: Array = []
		for t in 10:
			var a := randf() * TAU; var r := sqrt(randf()) * (reach - R * 0.6)
			var c := Vector2(cos(a) * r, sin(a) * r)
			var bad := false
			for q: Vector3 in road.cools:
				if Vector2(q.x - DemonRoad.AC.x, q.z - DemonRoad.AC.y).distance_to(c) < R + 2.6: bad = true
			if bad: continue
			var mine: Array = []
			for ix in range(floori(c.x - R), ceili(c.x + R) + 1):
				for iz in range(floori(c.y - R), ceili(c.y + R) + 1):
					var cell := Vector2i(ix, iz)
					if ix * ix + iz * iz <= reach * reach and not hit.has(cell) and Vector2(ix, iz).distance_to(c) < R: mine.push_back(cell)
			if mine.size() > gain: gain = mine.size(); best = c; best_cells = mine
		if best == Vector2.INF or gain < 8: break
		for cell: Vector2i in best_cells: hit[cell] = true
		placed.push_back(Vector3(DemonRoad.AC.x + best.x, DemonRoad.A_Y, DemonRoad.AC.y + best.y))
	for p: Vector3 in placed:
		var at := p
		ring(at, float(B.rift_r), float(B.rift_warn), Color(1.0, 0.15, 0.05, 0.55), func() -> void:
			Snd.play("rd_rift", 0.9, at)
			if rm.look != null: rm.look.burst(at + Vector3(0, 0.2, 0), float(B.rift_r), "fire")
			for e: Realm.Fighter in rm.all:
				if e.alive and e.team != f.team and not is_mon(e) and Vector2(e.pos.x - at.x, e.pos.z - at.z).length() < float(B.rift_r) and absf(e.pos.y - at.y) < 1.6:
					rm.hurt(e, float(B.rift_dmg), "fire", f, {"aoe": true, "src": "rift"}); rm.burn(e, float(B.rift_burn), float(B.rift_burn_t), f, "rift"))
	Snd.play("rd_crack", 1.0, f.feet_mid()); mode.boss_says(f, "유황 균열 · 붉은 금 밖으로! 화상은 냉각의 흑요석 진에서 꺼집니다")

## phase 2 begins: wings out, up into the air, three of the six pillars broken
func _baal_rise(f: Realm.Fighter) -> void:
	var b := f.brain
	b.phase = 2; b.state = "rise"; b.st = 0.0; b.air = true; f.inv = 2.6; f.shield = 0.0
	for q: Dictionary in b.binds: (q.thing as Dictionary).hp = 0.0; (q.line as Dictionary).t = 0.0
	b.binds = []
	for p: Dictionary in road.pillars:
		if int(p.i) % 2 == 0: road.break_pillar(p); if rm.look != null: rm.look.burst(p.at + Vector3(0, 2.0, 0), 3.0, "fire")
	Snd.play("rd_roar_big", 1.3, f.feet_mid()); mode.boss_says(f, "바알이 날개를 펼치고 솟아오릅니다 · 석주 셋이 무너졌습니다"); mode.boss_phase(2)

## phase 3 begins: down onto the floor with a slam; the rest of the pillars and the rim are gone
func _baal_fall(f: Realm.Fighter) -> void:
	var b := f.brain
	b.phase = 3; b.state = "slam"; b.st = 0.0; b.air = false; f.inv = 2.4
	for c: Dictionary in b.cores: c.hp = 0.0
	b.cores = []; b.erase("sun"); b.erase("drain"); b.erase("shower")
	f.pos = Vector3(DemonRoad.AC.x, DemonRoad.A_Y, DemonRoad.AC.y)
	for p: Dictionary in road.pillars: road.break_pillar(p)
	road.collapse()
	# whoever stood on the rim goes down with it
	for e: Realm.Fighter in rm.all:
		if e.alive and not is_mon(e) and Vector2(e.pos.x - DemonRoad.AC.x, e.pos.z - DemonRoad.AC.y).length() > DemonRoad.AR_SMALL - 0.4 and e.pos.y > DemonRoad.A_Y - 1.0 and e.pos.y < DemonRoad.A_Y + 3.0:
			rm.shove(e, Vector3(DemonRoad.AC.x - e.pos.x, 0, DemonRoad.AC.y - e.pos.z), 3.0)
	if rm.look != null: rm.look.burst(f.pos + Vector3(0, 0.3, 0), 12.0, "fire")
	Snd.play("rd_collapse", 1.4, f.feet_mid()); mode.boss_says(f, "제단 외곽이 무너집니다 · 바알이 임계 과열 상태에 들어섭니다"); mode.boss_phase(3)

## the eclipse of doom: he kneels in the middle; twelve seconds (more for each bomb that cools him) to bring him down
func _eclipse(f: Realm.Fighter) -> void:
	var b := f.brain
	b.ecl = true; b.state = "eclipse"; b.cast = float(BAAL.eclipse_t); b.st = 0.0
	f.pos = Vector3(DemonRoad.AC.x, DemonRoad.A_Y, DemonRoad.AC.y)
	Snd.play("rd_eclipse", 1.4, f.feet_mid()); mode.boss_says(f, "종말의 일식 · 12초 안에 쓰러뜨리세요! 모든 공격 2배, 연금술 폭탄은 영창을 늦춥니다"); mode.eclipse_start()
	rm.note(["eclipse", f.id])

## in the air: a slow circle about the altar's middle, 15 m up
func _air(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if float(b.get("crash", 0.0)) > 0.0:   # brought down: on the floor, reeling
		f.pos.y = maxf(DemonRoad.A_Y, f.pos.y - dt * 18.0); f.vel = Vector3.ZERO; return
	b.orbit = float(b.get("orbit", 0.0)) + dt * 0.25
	var want := Vector3(DemonRoad.AC.x + cos(float(b.orbit)) * 4.0, DemonRoad.A_Y + float(BAAL.hover), DemonRoad.AC.y + sin(float(b.orbit)) * 4.0)
	f.pos = f.pos.lerp(want, minf(1.0, dt * 1.5)); f.vel = Vector3.ZERO

func _meteors(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if not b.has("shower"): return
	b.shower = float(b.shower) - dt; b.mt = float(b.mt) - dt
	if float(b.shower) <= 0.0: b.erase("shower"); return
	if float(b.mt) > 0.0: return
	b.mt = float(BAAL.meteor_every)
	var at := Vector3.ZERO
	var us: Array = rm.all.filter(func(e): return e.alive and not is_mon(e) and e.team != f.team)
	if not us.is_empty() and randf() < 0.5: var v: Realm.Fighter = us[randi() % us.size()]; at = Vector3(v.pos.x, DemonRoad.A_Y, v.pos.z)
	else:
		var a := randf() * TAU; var r := sqrt(randf()) * (DemonRoad.AR - 2.0)
		at = Vector3(DemonRoad.AC.x + cos(a) * r, DemonRoad.A_Y, DemonRoad.AC.y + sin(a) * r)
	var from := f.pos + Vector3(0, f.H * 0.6, 0)
	ring(at, float(BAAL.meteor_r), float(BAAL.meteor_warn), Color(1.0, 0.4, 0.05, 0.5), func() -> void:
		Snd.play("rd_meteor", 0.9, at)
		if rm.look != null: rm.look.burst(at + Vector3(0, 0.2, 0), float(BAAL.meteor_r), "fire")
		for e: Realm.Fighter in rm.all:
			if not e.alive or is_mon(e) or e.team == f.team: continue
			if Vector2(e.pos.x - at.x, e.pos.z - at.z).length() > float(BAAL.meteor_r) or absf(e.pos.y - at.y) > 2.0: continue
			if not Phys.line_of_sight(from, e.feet_mid()) or rm.kit.domed(e, from): continue   # (a pillar between, or a dwarf's dome)
			rm.hurt(e, float(BAAL.meteor_dmg), "fire", f, {"aoe": true, "ranged": true, "src": "meteor", "from": from}))

## the soul drain: a red beam onto whoever has hurt him most of late; a pillar between, or arcane smoke, breaks it
func _drain_start(f: Realm.Fighter) -> void:
	var b := f.brain; var best: Realm.Fighter = null; var most := -1.0
	for e: Realm.Fighter in rm.all:
		if e.alive and not is_mon(e) and e.team != f.team and e.dealt > most: best = e; most = e.dealt
	if best == null: b.drain_t = 3.0; return
	b.drain = {"v": best, "t": float(BAAL.drain_t), "line": line(f.eye_at(), best.feet_mid(), float(BAAL.drain_t), Color(1.0, 0.05, 0.15, 0.9), 0.14)}
	b.drain_t = float(BAAL.drain_cd); Snd.play("rd_drain", 1.0, best.feet_mid())
	mode.boss_says(f, "영혼 흡수 광선 · %s, 석주 뒤로 숨거나 연막탄 속으로!" % (Races.R[best.race].name if Races.R.has(best.race) else best.name))

func _drain(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if not b.has("drain"): return
	var q: Dictionary = b.drain; var v: Realm.Fighter = q.v; var ln: Dictionary = q.line
	q.t = float(q.t) - dt
	var from := f.eye_at()
	var broken: bool = not v.alive or not Phys.line_of_sight(from, v.feet_mid()) or rm.kit.smoked(from, v.feet_mid()) or rm.kit.in_smoke(v.feet_mid())
	if broken or float(q.t) <= 0.0:
		ln.t = 0.0; b.erase("drain")
		if broken and v.alive: Snd.play("rd_break", 0.9, v.feet_mid()); mode.gimmick("drain_break")
		return
	ln.a = from; ln.b = v.feet_mid(); ln.t = 0.3; _line_place(ln)
	rm.hurt(v, float(BAAL.drain_dps) * dt, "fire", f, {"dot": true, "fixed": true, "src": "drain"})
	f.shield = minf(float(KINDS.baal.shield), f.shield + float(BAAL.drain_heal) * dt)

## the abyssal sun: he charges a great ball of fire over his head and calls four imps; break the two cores on his wings in
## time and he crashes onto the floor, reeling (half as much again from every blow); else the sun comes down on you all
func _sun_start(f: Realm.Fighter) -> void:
	var b := f.brain; var B := BAAL
	b.sun = float(B.sun_t); b.suns = int(b.suns) + 1
	b.erase("shower")
	if b.has("drain"): ((b.drain as Dictionary).line as Dictionary).t = 0.0; b.erase("drain")
	var made := []
	for s: float in [-1.0, 1.0]:
		var th := rm.kit.add_thing({"kind": "wcore", "team": "them", "pos": f.pos + Vector3(s * float(B.core_out), f.H * 0.7, 0), "r": 0.8, "h": 1.2, "hp": float(B.core_hp), "max": float(B.core_hp), "made": false, "label": "보라색 비전 코어", "side": s, "node": gem("wcore", f.pos)})
		made.push_back(th)
	b.cores = made
	for i in int(B.imps):
		var a := i * TAU / float(B.imps) + 0.4
		var p := Vector3(DemonRoad.AC.x + cos(a) * 12.0, DemonRoad.A_Y + 2.5, DemonRoad.AC.y + sin(a) * 12.0)
		var imp := make("imp", p, 4, {"woken": true, "awake": true, "extra": true}); imp.brain.awake = true
		if rm.look != null: rm.look.summoned(p - Vector3(0, 2.5, 0), "demon")
	b.sun_t = float(B.sun_cd)
	Snd.play("rd_sun", 1.2, f.eye_at()); mode.boss_says(f, "심연의 태양 충전 · 날개의 보라색 코어 두 개를 부수세요! 중력 진이 띄워 줍니다")

func _sun(f: Realm.Fighter, dt: float) -> void:
	var b := f.brain
	if not b.has("sun"): return
	for c: Dictionary in b.cores:   # (the cores ride on his wings)
		c.pos = f.pos + Vector3(float(c.side) * float(BAAL.core_out), f.H * 0.7, 0)
	var up := (b.cores as Array).filter(func(c): return float(c.hp) > 0.0).size()
	if up == 0:   # both broken: he comes down
		b.erase("sun"); b.cores = []; b.crash = float(BAAL.crash_t)
		Snd.play("rd_crash", 1.3, f.feet_mid()); mode.boss_says(f, "코어 파괴! 바알이 추락합니다 · 5초 동안 받는 피해 +50%")
		mode.gimmick("cores_down")
		return
	b.sun = float(b.sun) - dt
	if float(b.sun) <= 0.0:   # the sun comes down
		b.erase("sun")
		for c: Dictionary in b.cores: c.hp = 0.0
		b.cores = []
		var from := f.pos + Vector3(0, f.H + 2.0, 0)
		Snd.play("rd_sun_fall", 1.4, from)
		if rm.look != null: rm.look.burst(Vector3(DemonRoad.AC.x, DemonRoad.A_Y + 0.3, DemonRoad.AC.y), DemonRoad.AR, "fire")
		for e: Realm.Fighter in rm.all:
			if e.alive and not is_mon(e) and e.team != f.team and not rm.kit.domed(e, from): rm.hurt(e, float(BAAL.sun_dmg), "fire", f, {"aoe": true, "src": "sun", "from": from})
		mode.boss_says(f, "심연의 태양이 떨어졌습니다")
		mode.gimmick("sun_fell")

## phase 3: the furnace about him (9 m): it burns, and what mends there mends half as much (Realm.heal asks ModeRaid)
func _aura(f: Realm.Fighter, dt: float) -> void:
	for e: Realm.Fighter in rm.all:
		if e.alive and not is_mon(e) and e.team != f.team and e.pos.distance_to(f.pos) < float(BAAL.aura_r):
			rm.hurt(e, float(BAAL.aura_dps) * dt, "fire", f, {"dot": true, "aoe": true, "src": "furnace"})
	if rm.fx != null and randf() < 0.5:
		var a := randf() * TAU; var r := randf() * float(BAAL.aura_r)
		rm.fx.glow(f.pos + Vector3(cos(a) * r, 0.2, sin(a) * r), Vector3(0, randf_range(1.0, 2.5), 0), 0.6, 0.3, 0.04, Color(1.0, 0.35, 0.08, 0.7))

func in_furnace(v: Realm.Fighter) -> bool:
	for f: Realm.Fighter in rm.all:
		if f.alive and kind_of(f) == "baal" and int(f.brain.get("phase", 1)) == 3 and f.pos.distance_to(v.pos) < float(BAAL.aura_r): return true
	return false

## the third blow: a ring of lava running out over the whole altar, knee high; over it with a jump, or through it in a blink
func _magma_ring(f: Realm.Fighter) -> void:
	var w := {"kind": "ring", "r": 2.0, "at": Vector3(f.pos.x, DemonRoad.A_Y, f.pos.z), "hit": {}, "by": f, "node": null}
	if rm.en != null:
		var m := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.9; tm.outer_radius = 1.0; tm.rings = 48; tm.ring_segments = 6; m.mesh = tm
		m.material_override = _mat("mring", Color(1.0, 0.4, 0.05, 0.9)); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _root().add_child(m); w.node = m
	waves.push_back(w); Snd.play("rd_wave_big", 1.3, f.feet_mid())

# ---------------- what is in the air and on the ground, each frame ----------------
## what a lord's made thing looks like (it follows th.pos: tick): an obsidian crystal, a chain's lock, a violet core
func gem(kind: String, at: Vector3) -> Node3D:
	if rm.en == null: return null
	var g := Node3D.new(); _root().add_child(g); g.position = at
	match kind:
		"anchor":
			var c := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.9, 1.6, 0.9); c.mesh = bm; c.rotation = Vector3(0.5, 0.6, 0.3); c.position.y = 0.8
			var m := StandardMaterial3D.new(); m.albedo_color = Color("1d1a22"); m.roughness = 0.25; m.metallic = 0.4; m.emission_enabled = true; m.emission = Color("ff2a3a"); m.emission_energy_multiplier = 0.35; c.material_override = m; g.add_child(c)
			var core := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.64; core.mesh = sm; core.material_override = _mat("anchor_core", Color(1.0, 0.2, 0.25, 0.9)); core.position.y = 0.8; g.add_child(core)
		"chain":
			var c2 := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.28; tm.outer_radius = 0.5; c2.mesh = tm; c2.material_override = _mat("chain_lock", Color(0.95, 0.12, 0.2, 0.9)); c2.position.y = 0.7; c2.rotation.x = PI / 2.0; g.add_child(c2)
		"wcore":
			var o := MeshInstance3D.new(); var sm2 := SphereMesh.new(); sm2.radius = 0.75; sm2.height = 1.5; o.mesh = sm2; o.material_override = _mat("wcore", Color(0.7, 0.3, 1.0, 0.85)); o.position.y = 0.6; g.add_child(o)
	return g

func tick(dt: float) -> void:
	for th: Dictionary in rm.kit.things:   # (the lords' things go where they are)
		if th.has("node") and th.kind in ["anchor", "chain", "wcore"] and is_instance_valid(th.node):
			var n: Node3D = th.node; n.position = th.pos; n.rotation.y += dt * (1.6 if th.kind == "anchor" else 0.8)
	for i in range(lines.size() - 1, -1, -1):
		var q: Dictionary = lines[i]; q.t = float(q.t) - dt
		if float(q.t) <= 0.0:
			if q.node != null and is_instance_valid(q.node): (q.node as Node).queue_free()
			lines.remove_at(i)
	for i in range(rings.size() - 1, -1, -1):
		var q: Dictionary = rings[i]; q.t = float(q.t) - dt
		if q.node != null and is_instance_valid(q.node):
			var u := 1.0 - float(q.t) / maxf(0.01, float(q.t0))
			(q.node as Node3D).scale = Vector3(float(q.r) * lerpf(0.25, 1.0, u), 1, float(q.r) * lerpf(0.25, 1.0, u))
		if float(q.t) <= 0.0:
			if q.node != null and is_instance_valid(q.node): (q.node as Node).queue_free()
			rings.remove_at(i)
			if (q.done as Callable).is_valid(): (q.done as Callable).call()
	for i in range(waves.size() - 1, -1, -1):
		var w: Dictionary = waves[i]
		var live := _wave_spiral(w, dt) if w.kind == "spiral" else _wave_ring(w, dt)
		if not live:
			if w.node != null and is_instance_valid(w.node): (w.node as Node).queue_free()
			waves.remove_at(i)

## the fire wave down the stair: from the top it comes down the steps; feet on the steps as it passes burn
func _wave_spiral(w: Dictionary, dt: float) -> bool:
	w.u = float(w.u) - float(KARNOK.wave_speed) * dt
	if float(w.u) <= 0.0: return false
	var p := DemonRoad.stair_point(float(w.u), 13.0)
	if w.node != null and is_instance_valid(w.node):
		var n: Node3D = w.node; n.position = p + Vector3(0, 0.37, 0); n.rotation.y = -deg_to_rad(DemonRoad.ST_A0 + float(w.u))
	if rm.fx != null and randf() < 0.6: rm.fx.glow(p + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5)), Vector3(0, 2.0, 0), 0.5, 0.3, 0.04, Color(1.0, 0.45, 0.08, 0.8))
	for e: Realm.Fighter in rm.all:
		if not e.alive or is_mon(e) or (w.hit as Dictionary).has(e.id): continue
		var st := DemonRoad.on_stair(e.pos)
		if st.is_empty() or absf(float(st[0]) - float(w.u)) > 6.0: continue
		if e.pos.y - float(st[1]) > float(KARNOK.wave_h) or e.inv > 0.0: continue   # (on a shelf, or in the air over it)
		(w.hit as Dictionary)[e.id] = true
		rm.hurt(e, float(KARNOK.wave), "fire", w.by, {"aoe": true, "src": "wave"}); rm.burn(e, float(KARNOK.wave_burn), 3.0, w.by, "wave")
	return true

## Baal's ring of lava: out from him over the floor; feet below its top as it passes burn
func _wave_ring(w: Dictionary, dt: float) -> bool:
	w.r = float(w.r) + float(BAAL.wave_speed) * dt
	if float(w.r) > float(BAAL.wave_max): return false
	var c: Vector3 = w.at
	if w.node != null and is_instance_valid(w.node):
		var n: Node3D = w.node; n.position = c + Vector3(0, 0.45, 0); n.scale = Vector3(float(w.r), 6.0, float(w.r))
	for e: Realm.Fighter in rm.all:
		if not e.alive or is_mon(e) or (w.hit as Dictionary).has(e.id): continue
		var d := Vector2(e.pos.x - c.x, e.pos.z - c.z).length()
		if absf(d - float(w.r)) > 0.9: continue
		(w.hit as Dictionary)[e.id] = true
		if e.pos.y - c.y > float(BAAL.wave_h) or e.inv > 0.0 or e.phased_t > 0.0: continue
		rm.hurt(e, float(BAAL.wave_dmg), "fire", w.by, {"aoe": true, "src": "magma"})
	return true

## for the others' minds (ModeRaid's goals): a wave coming at someone, so that he jumps (a jump of theirs is 0.76 s in the
## air and over the wave's top from 0.14 s to 0.62 s after it starts: so when the wave is that far off)
func wave_near(e: Realm.Fighter) -> bool:
	for w: Dictionary in waves:
		if w.kind == "spiral":
			var st := DemonRoad.on_stair(e.pos)
			var ahead := float(w.u) - float(st[0]) if not st.is_empty() else -1.0
			if ahead > 13.0 and ahead < 26.0 and e.pos.y - float(st[1]) < float(KARNOK.wave_h): return true
		else:
			var c: Vector3 = w.at; var d := Vector2(e.pos.x - c.x, e.pos.z - c.z).length()
			if d - float(w.r) > 3.4 and d - float(w.r) < 6.2: return true
	return false

## a rift or a meteor's circle under someone (for the others' minds: step out)
func danger_at(p: Vector3) -> Vector3:
	for q: Dictionary in rings:
		var at: Vector3 = q.at
		if Vector2(p.x - at.x, p.z - at.z).length() < float(q.r) + 0.6 and absf(p.y - at.y) < 2.0: return at
	return Vector3.INF
