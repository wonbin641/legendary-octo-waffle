class_name Races
extends RefCounted
## Stage 6's four peoples as sides you can fight on (the realm's team battles): what each is, what it carries and what it
## can do, in numbers. Everything here is a table or a sum; the fight itself is in Realm and RealmKit.
## The numbers are the design papers' (종합 기획서, 궁극기·룬 기획서); where the papers give none, the number is marked "ours".

const ORDER := ["elf", "dwarf", "orc", "demon"]
const ELEMENTS := {"arcane": "비전", "fire": "화염", "physical": "물리", "alchemy": "연금술"}

# r, h: the body that can be hit; head: the top of it that counts as the head (a dwarf's is narrow, an orc's big)
const R := {
	"elf": {"name": "엘프", "role": "기동형 정찰·저격수", "hp": 175.0, "speed": 6.2, "r": 0.3, "h": 1.72, "eye": 1.58, "head": 0.27, "elem": "arcane",
		"weapon": "비전 연발 석궁", "passive": "비전 감각", "skill": "바람 걸음 도약", "ult": "별빛 유성우", "range": "25~50 m", "col": "63d8c2", "sight": 70.0},
	"dwarf": {"name": "드워프", "role": "중장갑 거점 수호자", "hp": 225.0, "speed": 5.3, "r": 0.4, "h": 1.3, "eye": 1.16, "head": 0.2, "elem": "physical",
		"weapon": "룬 증기 산탄포", "passive": "룬 대장장이의 맷집", "skill": "증기 추진 돌진", "ult": "고대 룬 파수탑", "range": "0~10 m", "col": "d99a4a", "sight": 45.0},
	"orc": {"name": "오크", "role": "광전사 돌격대장", "hp": 275.0, "speed": 5.7, "r": 0.5, "h": 2.1, "eye": 1.88, "head": 0.36, "elem": "physical",
		"weapon": "피의 룬 대검 · 사슬 도끼", "passive": "피의 갈증", "skill": "야수의 도약", "ult": "피의 광폭화", "range": "0~6 m", "col": "7fae4a", "sight": 45.0},
	"demon": {"name": "악마", "role": "과열 제어형 화력가", "hp": 200.0, "speed": 5.8, "r": 0.38, "h": 1.86, "eye": 1.7, "head": 0.3, "elem": "fire",
		"weapon": "지옥불 마법 스태프", "passive": "지옥불 동화", "skill": "그림자 균열 이동", "ult": "연옥의 화로", "range": "10~25 m", "col": "c8503a", "sight": 50.0},
}

# ---------------- the four weapons ----------------
# the elves' arcane repeater: quick arrows, a charged one that glances off the ground or a wall once and goes through people
const XBOW := {"dmg": 34.0, "head": 2.0, "rate": 3.5, "mag": 12, "reload": 1.4, "speed": 150.0, "life": 1.2,
	"charge": 0.9, "big": 95.0, "big_speed": 170.0, "bounces": 1, "air_spread": 0.03,   # (ours: the arrows' speeds, the sway in the air)
	"sight_at": 0.8, "sight_r": 35.0, "sight_t": 1.5, "sight_recent": 3.0}             # arcane sight: who fired or used a circle within the last 3 s (ours)
# the dwarves' rune steam scatter-cannon: ten shards a shot, deadly close by; a grenade under it
const CANNON := {"pellets": 10, "dmg": 14.0, "head": 1.5, "rate": 1.1, "mag": 5, "reload": 1.8, "spread": 0.07, "full": 9.0, "far": 24.0, "far_mul": 0.3,   # (ours: spread, the fall-off)
	"kick": 3.5, "push": 2.2, "vent_at": 0.45, "vent_r": 2.6, "vent": 15.0,                                                                                   # (ours: the vent's reach and burn)
	"gren": 45.0, "gren_boom": 40.0, "gren_r": 3.6, "gren_speed": 26.0, "gren_cd": 6.0, "oil_r": 3.2, "oil_t": 8.0}
# the orcs' rune great sword: three blows, a wave from the third; a chain axe to throw and follow
const SWORD := {"dmg": [65.0, 65.0, 80.0], "step": 0.75, "lands": 0.3, "reach": 3.1, "arc": 0.95, "combo_keep": 1.1,   # (ours: when a blow lands, its reach and arc)
	"wave": 45.0, "wave_range": 12.0, "wave_speed": 34.0, "wave_r": 1.3,
	"axe": 55.0, "axe_speed": 46.0, "axe_range": 30.0, "axe_cd": 6.0, "axe_dash": 32.0, "stop_ms": [30.0, 30.0, 55.0]}
# the demons' hellfire staff: embers by heat, not by a magazine; a beam that costs its own health
const STAFF := {"dmg": 15.0, "head": 1.5, "rate": 9.0, "speed": 75.0, "life": 0.8, "heat": 1.6, "cool": 28.0, "cool_wait": 0.5,   # (ours: heat a shot, so that 80% to 100% is twelve shots, room for the papers' 1.15 s at critical heat; how it cools)
	"crit": 80.0, "burn": 18.0, "burn_t": 1.0, "seal": 2.0, "seal_to": 55.0,
	"beam": 70.0, "beam_cost": 14.0, "beam_range": 30.0, "beam_floor": 30.0}                                                     # (ours: the beam's numbers)
const WEAPON := {"elf": XBOW, "dwarf": CANNON, "orc": SWORD, "demon": STAFF}

# ---------------- what everyone carries ----------------
const DAGGER := {"dmg": 45.0, "reach": 2.5, "arc": 0.8, "cd": 0.7, "execute": 40.0, "parry": 0.4, "parry_cd": 10.0, "parry_r": 1.9}
const BOMBS := ["oil", "gravity", "smoke"]
const BOMB := {
	"oil": {"name": "기름 & 점화 플라스크", "r": 4.0, "t": 10.0, "slow": 0.75, "fire": 45.0, "fire_t": 5.0, "text": "기름이 발을 늦춥니다 · 불씨나 증기 탄환이 닿으면 5초 동안 초당 45의 불바다"},
	"gravity": {"name": "중력 붕괴 구체", "r": 5.0, "t": 1.5, "dmg": 30.0, "pull": 3.4, "text": "피해 30 · 반경 5 m 안의 모두와 투사체를 1.5초 동안 한가운데로"},
	"smoke": {"name": "비전 연막탄", "r": 5.5, "t": 9.0, "text": "보라색 안개가 시야를 가립니다 · 안에서는 엘프의 투시가 통하지 않습니다"},
}
const BOMB_CD := 16.0      # ours: a thrown bomb is back in the pouch this long after
const BOMB_SPEED := 17.0
const FROST := {"r": 3.6, "t": 4.0, "slow": 0.7}
const SLOW_HIT := 1.5      # alchemy on a demon at critical heat: this long slowed
const SLOW_HIT_MUL := 0.7

# ---------------- what each can do: the passive and Shift ----------------
const SKILL := {
	"elf": {"cd": 8.0, "dist": 6.0, "t": 0.22, "steady": 1.2, "refund": 4.0, "charges": 1},
	"dwarf": {"cd": 10.0, "dist": 7.0, "t": 0.28, "dmg": 20.0, "r": 2.0, "push": 3.0, "refund": 2.0, "charges": 1},
	"orc": {"cd": 7.0, "dist": 10.0, "up": 7.0, "slow": 0.8, "slow_t": 1.0, "r": 2.5, "quick": 0.7, "charges": 1},
	"demon": {"cd": 9.0, "dist": 6.5, "t": 0.35, "gap": 1.5, "cool": 25.0, "charges": 2, "phys_cut": 1.0},
}
const THICK := {"push": 0.5, "aoe": 0.75, "near": 4.0, "shield": 5.0, "cap": 25.0}                  # the dwarf's resilience
const LUST := {"max": 3, "t": 4.0, "speed": 0.08, "front": 0.05}                                   # the orc's bloodlust
const KIN := {"steal": 0.15, "speed": 1.12}                                                        # the demon's hellfire kinship (6.5 m/s at critical heat)

# ---------------- the ultimates (X) ----------------
const GAUGE := {"max": 1000.0, "sec": 5.0, "dmg": 1.0, "object": 0.3, "heal": 0.8, "kill": 100.0, "assist": 50.0, "capture": 12.0, "bomb": 150.0}
const ULT := {
	"elf": {"name": "별빛 유성우: 비전 화살비", "range": 45.0, "r": 9.0, "warn": 0.8, "t": 3.0, "arrows": 24, "dmg": 22.0, "mark": 4.0},
	"dwarf": {"name": "고대 룬 파수탑 & 증기 방벽", "hp": 450.0, "r": 6.0, "t": 12.0, "bolt": 28.0, "every": 0.6, "shield": 15.0, "cap": 50.0, "cut": 0.8, "slow": 0.8, "burn": 10.0, "reach": 26.0},
	"orc": {"name": "전쟁군주의 피의 광폭화", "cast": 0.6, "hp": 125.0, "t": 9.0, "haste": 1.35, "wave": 45.0, "leap_cd": 3.5, "more": 2.5, "more_n": 2},
	"demon": {"name": "심연의 지옥불 영역: 연옥의 화로", "r": 10.0, "t": 8.0, "heat": 90.0, "burn": 25.0, "heal_cut": 0.5, "steal": 0.2},
}
const ASSIST_T := 8.0      # ours: whoever hurt him within this long of his fall has a part in it
const DUCK := {"db": -6.0, "t": 1.5}

# ---------------- the rune altar (B, between rounds) ----------------
# slot a: the weapon; b: the passive and Shift; c: for everyone
const RUNES := {
	"elf_prism": {"slot": "a", "race": "elf", "cost": 450, "name": "프리즘 분열 각인", "text": "차징 사격의 도탄 2회 · 첫 도탄에서 화살이 둘로 갈라집니다(각 60%)"},
	"elf_rapid": {"slot": "a", "race": "elf", "cost": 250, "name": "속사 마력 현", "text": "연사 +20%(초당 4.2발) · 탄창 16발 · 차징 사격 피해 −15%"},
	"dw_wave": {"slot": "a", "race": "dwarf", "cost": 450, "name": "고압 증기 파동포", "text": "산탄포와 돌진의 밀쳐내기 +60% · 벽에 부딪힌 적에게 피해 35와 0.6초 경직"},
	"dw_frost": {"slot": "a", "race": "dwarf", "cost": 300, "name": "빙결 연금술 약실", "text": "유탄이 4초 동안 서리 장판을 남깁니다 · 이동 −30% · 악마의 열기를 0%로"},
	"orc_giant": {"slot": "a", "race": "orc", "cost": 450, "name": "거인의 진동 검기", "text": "검기 사거리 18 m · 얇은 엄폐물을 뚫고 임시 보호막을 깨뜨립니다"},
	"orc_hook": {"slot": "a", "race": "orc", "cost": 300, "name": "쌍날 사슬 갈고리", "text": "사슬 도끼에 맞은 적을 내 앞 2 m로 끌어옵니다"},
	"dm_core": {"slot": "a", "race": "demon", "cost": 450, "name": "심연의 방열 코어", "text": "열기 냉각 +40% · 임계 구간이 75~99%로 넓어집니다"},
	"dm_burst": {"slot": "a", "race": "demon", "cost": 300, "name": "과부하 폭렬 불씨", "text": "임계 상태의 불씨가 반경 2.5 m로 터집니다(+6) · 열기 상승 +15%"},
	"elf_echo": {"slot": "b", "race": "elf", "cost": 300, "name": "산들바람 잔상", "text": "바람 걸음 자리에 2.5초 동안 환영을 남깁니다 · 환영을 쏜 적은 2초 동안 드러납니다"},
	"dw_plate": {"slot": "b", "race": "dwarf", "cost": 400, "name": "룬 강철 장갑판", "text": "임시 보호막 상한 50 · 보호막이 있는 동안 머리 피해 배율 1.5배"},
	"orc_roar": {"slot": "b", "race": "orc", "cost": 250, "name": "피의 포효 가속", "text": "피의 갈증 4중첩(이동 +32%) · 처치하면 체력 45 회복"},
	"dm_trail": {"slot": "b", "race": "demon", "cost": 350, "name": "균열의 불꽃 자취", "text": "그림자 균열이 지난 길에 3초 동안 불길이 남습니다"},
	"c_pouch": {"slot": "c", "race": "", "cost": 400, "name": "이중 연금술 주머니", "text": "연금술 폭탄 2개 · 서로 다른 폭탄을 잇달아 던집니다"},
	"c_mirror": {"slot": "c", "race": "", "cost": 300, "name": "거울 룬 단검", "text": "튕겨내기 판정 0.65초 · 튕겨낸 투사체 피해 +30%"},
	"c_ley": {"slot": "c", "race": "", "cost": 250, "name": "지맥 동조 각인", "text": "마법진 재사용 대기 −35% · 마법진을 쓴 뒤 3초 동안 이동 +15%"},
}
const SLOTS := {"a": "주무기 각인", "b": "기동 · 패시브 각인", "c": "공용 전술 각인"}
const RUNE := {"prism_split": 0.6, "rapid_rate": 1.2, "rapid_mag": 16, "rapid_big": 0.85, "wave_push": 1.6, "wave_wall": 35.0, "wave_stun": 0.6, "frost_t": 4.0,
	"giant_range": 18.0, "hook_to": 2.0, "core_cool": 1.4, "core_crit": 75.0, "burst_r": 2.5, "burst": 6.0, "burst_heat": 1.15,
	"echo_t": 2.5, "echo_reveal": 2.0, "plate_cap": 50.0, "plate_head": 1.5, "roar_max": 4, "roar_heal": 45.0, "trail_t": 3.0, "trail_burn": 18.0,
	"mirror": 0.65, "mirror_mul": 1.3, "ley_cd": 0.65, "ley_speed": 1.15, "ley_t": 3.0}
# the shards each is given: the sanctum's three rounds, the siege's two phases and its second half
const SHARDS := {"sanctum": [300, 0, 700], "sanctum_win": 550, "sanctum_lose": 650, "bonus": 50, "bonus_max": 150,
	"siege": 350, "siege_att": 600, "siege_def": 650, "siege_swap": 850}

# ---------------- the elements ----------------
const EDGE := 0.15         # a hit's swing either way, no more (aim counts for more than the element)
const SHIELD_ARCANE := 1.2 # arcane on the nucleus' shield
const BURN_HEAL := 0.7     # while burning: what mends you, by this much

static func runes_for(race: String, slot: String) -> Array:
	var out: Array = []
	for id: String in RUNES:
		var q: Dictionary = RUNES[id]
		if q.slot == slot and (q.race == "" or q.race == race): out.push_back(id)
	return out

## whether someone has a rune cut (a rune of another people's is nothing to him)
static func has(runes: Dictionary, race: String, id: String) -> bool:
	var q: Dictionary = RUNES[id]
	return str(runes.get(q.slot, "")) == id and (q.race == "" or q.race == race)

## a hit's element against what it meets. what: the struck one's state, each key there or not:
##   shield   a temporary shield up, or an orc's bloodlust turning shots from the front (heavy armour: arcane goes through some)
##   fog      the shot went through alchemical fog or frost (arcane is the worse for it)
##   dwarf    a dwarf (fire: his resistance to burning)
##   plant    oil or plants (fire)
##   made     an arcane made thing: an altar's crystal, a trap circle, the nucleus' body, a turret (physical)
##   phased   a demon within a second of his shadow step (physical is the worse for it)
##   critical a demon at critical heat (alchemy)
static func affinity(elem: String, what: Dictionary) -> float:
	var m := 1.0
	match elem:
		"arcane":
			if what.get("shield", false): m += EDGE
			if what.get("fog", false): m -= EDGE
		"fire":
			if what.get("plant", false): m += EDGE
			if what.get("dwarf", false): m -= EDGE
		"physical":
			if what.get("made", false): m += EDGE
			if what.get("phased", false): m -= EDGE
		"alchemy":
			if what.get("critical", false): m += EDGE
	return m

## a weapon's damage a second as it is held down (the papers' "실전 지속 DPS"): the crossbow with its reloads, the cannon
## with its, the sword's three blows and the wave, the staff at critical heat with its burn
static func dps(race: String) -> float:
	match race:
		"elf": return float(XBOW.dmg) * int(XBOW.mag) / (int(XBOW.mag) / float(XBOW.rate) + float(XBOW.reload))
		"dwarf": return float(CANNON.dmg) * int(CANNON.pellets) * int(CANNON.mag) / (int(CANNON.mag) / float(CANNON.rate) + float(CANNON.reload))
		"orc": return (float(SWORD.dmg[0]) + float(SWORD.dmg[1]) + float(SWORD.dmg[2]) + float(SWORD.wave)) / (3.0 * float(SWORD.step))
		_: return float(STAFF.dmg) * float(STAFF.rate) + float(STAFF.burn)
