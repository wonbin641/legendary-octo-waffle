class_name Custom
## Gun customisation: three slots of parts (sight, muzzle, underbarrel), each a small trade rather than a plain upgrade, and a
## paint colour, set gun by gun. Ported from src/06d_custom.js. The choices live in the save, so a save code carries them.

const SLOTS := ["sight", "muzzle", "under"]
const PARTS := {
	"sight": {"name": "조준기", "list": [
		{"id": "iron", "name": "기본 가늠쇠", "desc": "그대로", "mod": {}},
		{"id": "dot", "name": "레드닷", "desc": "정조준 속도 +25% · 정조준 퍼짐 -15%", "mod": {"adsSpeed": 1.25, "adsSpread": 0.85}},
		{"id": "holo", "name": "홀로그램", "desc": "정조준 퍼짐 -30% · 정조준 속도 +10%", "mod": {"adsSpread": 0.7, "adsSpeed": 1.1}},
		{"id": "x2", "name": "2배율 조준경", "desc": "정조준하면 더 크게 확대 · 정조준 퍼짐 -40% · 정조준 속도 -20%", "mod": {"adsFov": 0.55, "adsSpread": 0.6, "adsSpeed": 0.8}}]},
	"muzzle": {"name": "총구", "list": [
		{"id": "none", "name": "없음", "desc": "그대로", "mod": {}},
		{"id": "sup", "name": "소음기", "desc": "총소리가 들리는 거리 -60% · 섬광 작게 · 데미지 -8%", "mod": {"noise": 0.4, "flash": 0.35, "dmg": 0.92}},
		{"id": "comp", "name": "보정기", "desc": "반동 -25% · 총소리가 들리는 거리 +15%", "mod": {"recoil": 0.75, "kick": 0.8, "noise": 1.15}},
		{"id": "hider", "name": "소염기", "desc": "섬광 -70% · 반동 -10%", "mod": {"flash": 0.3, "recoil": 0.9}}]},
	"under": {"name": "하부", "list": [
		{"id": "none", "name": "없음", "desc": "그대로", "mod": {}},
		{"id": "vgrip", "name": "수직 손잡이", "desc": "반동 -20% · 연사할 때 퍼짐 -25%", "mod": {"recoil": 0.8, "bloom": 0.75}},
		{"id": "agrip", "name": "앵글 손잡이", "desc": "정조준 속도 +20% · 움직이며 쏠 때 퍼짐 -20%", "mod": {"adsSpeed": 1.2, "moveSpread": 0.8}},
		{"id": "laser", "name": "레이저", "desc": "정조준 없이 쏠 때 퍼짐 -25% · 조준한 곳에 빨간 점", "mod": {"spread": 0.75}}]},
}
const PAINTS := [{"id": "base", "name": "기본"}, {"id": "black", "name": "검정", "c": "1b1c1f"}, {"id": "gray", "name": "회색", "c": "7d838c"}, {"id": "tan", "name": "사막", "c": "b39466"},
	{"id": "olive", "name": "올리브", "c": "59633f"}, {"id": "silver", "name": "은색", "c": "c9ced6", "metal": 0.85, "rough": 0.25}, {"id": "gold", "name": "금색", "c": "d8a531", "metal": 0.95, "rough": 0.2},
	{"id": "red", "name": "빨강", "c": "a8231d"}, {"id": "blue", "name": "파랑", "c": "2a58a8"}, {"id": "pink", "name": "분홍", "c": "e27aa8"}]
# which slots each gun has: the sniper keeps its scope; the launchers have no muzzle to fit; on a pistol or the grenade launcher only a laser goes underneath
const MOUNTS := {
	"pistol": {"sight": true, "muzzle": true, "under": "laser"}, "shotgun": {"sight": true, "muzzle": true, "under": true}, "rifle": {"sight": true, "muzzle": true, "under": true},
	"smg": {"sight": true, "muzzle": true, "under": true}, "sniper": {"sight": false, "muzzle": true, "under": true}, "gl": {"sight": true, "muzzle": false, "under": "laser"},
	"lmg": {"sight": true, "muzzle": true, "under": true}, "rocket": {"sight": false, "muzzle": false, "under": false},
}
const MOD_KEYS := ["dmg", "spread", "adsSpread", "moveSpread", "recoil", "kick", "bloom", "adsFov", "adsSpeed", "flash"]

static func part_of(slot: String, pid) -> Dictionary:
	for p in PARTS[slot].list:
		if p.id == pid: return p
	return PARTS[slot].list[0]

static func part_index(slot: String, pid) -> int:
	for i in PARTS[slot].list.size():
		if PARTS[slot].list[i].id == pid: return i
	return 0

static func paint_index(pid) -> int:
	for i in PAINTS.size():
		if PAINTS[i].id == pid: return i
	return 0

## what fits: a slot the gun does not have stays empty, and where only a laser goes anything else falls back to nothing
static func fits(id: String, slot: String, pid: String) -> bool:
	var m = MOUNTS[id][slot]
	if m is bool and not m: return pid == PARTS[slot].list[0].id
	if m is String: return pid == "none" or pid == "laser"
	return true

## the gun as you have built it: {sight, muzzle, under, paint}
static func setup(id: String) -> Dictionary:
	var all = Store.save.get("custom", {}); var c: Dictionary = all.get(id, {}) if all is Dictionary and all.get(id) is Dictionary else {}
	var s := {}
	for slot in SLOTS:
		var pid: String = part_of(slot, c.get(slot)).id
		s[slot] = pid if fits(id, slot, pid) else PARTS[slot].list[0].id
	s.paint = PAINTS[paint_index(c.get("paint"))].id
	return s

static func set_part(id: String, slot: String, pid: String) -> void:
	if not (Store.save.get("custom") is Dictionary): Store.save.custom = {}
	var cur := setup(id); cur[slot] = pid; Store.save.custom[id] = cur; Store.persist()

static func reset(id: String) -> void:
	if Store.save.get("custom") is Dictionary: Store.save.custom.erase(id); Store.persist()

## the multipliers the chosen parts give, all three together
static func mods(s: Dictionary) -> Dictionary:
	var mul := {}
	for slot in SLOTS:
		var m: Dictionary = part_of(slot, s[slot]).mod
		for k in m: mul[k] = float(mul.get(k, 1.0)) * float(m[k])
	return mul

## the weapon's numbers with its parts applied: what firing, the shop and the codex read
static func weapon(id: String) -> Dictionary:
	var base: Dictionary = Weapons.LIST[id]; var mul := mods(setup(id))
	if mul.is_empty(): return base
	var w := base.duplicate()
	for k in MOD_KEYS:
		if mul.has(k): w[k] = float(base.get(k, 7.0 if k == "adsSpeed" else 0.0)) * float(mul[k])
	if mul.has("noise"): w.noise = float(mul.noise)
	return w
