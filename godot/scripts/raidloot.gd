class_name RaidLoot
extends RefCounted
## 6-A's spoils (the boss raid paper's second part, 「클리어 보상 및 성장 시스템」): what a won raid gives by its rank and
## its difficulty, what is kept of it (Store.save.raid), and what the tower's alchemy workshop makes of it.
##   materials   바알의 흑요석 심장 · 카르녹의 룬 사슬 파편 · 심연의 유황 결정, and 명성 주화 (renown coins)
##   relics      four legendary rune relics, cut into the rune altar's slots in the raid only (PvE): RealmKit does what they do
##   looks       four mythic weapon skins, the eclipse elimination, the obsidian HUD frame, Karnok's miniature mace (a charm);
##               worn in every battle of the four peoples (they change nothing of the fight)
##   titles      「일식을 부순 자」 (the first S), 「심연을 길들인 대마법사」 (an S on the Abyssal)
## The party is all yours (you play each of the four by turns), so what the paper gives "each of the party" is yours four
## times over where it is something each of them carries (a relic is his people's), once where it is the party's (the materials).

const MATS := ["heart", "shard", "sulfur"]
const MAT_NAME := {"heart": "바알의 흑요석 심장", "shard": "카르녹의 룬 사슬 파편", "sulfur": "심연의 유황 결정"}
const MAT_SHORT := {"heart": "흑요석 심장", "shard": "룬 사슬 파편", "sulfur": "유황 결정"}
const MAT_COL := {"heart": "ff4a3a", "shard": "b8c0cc", "sulfur": "f2d14e"}
const COIN_NAME := "명성 주화"
## by rank (the paper's table): the materials sure to come, each of the party's chance at his people's relic, the coins
const RANK := {
	"S": {"heart": 2, "shard": 4, "sulfur": 15, "relic": 0.35, "coins": 500},
	"A": {"heart": 1, "shard": 3, "sulfur": 10, "relic": 0.18, "coins": 350},
	"B": {"heart": 0, "shard": 2, "sulfur": 6, "relic": 0.08, "coins": 220},
	"C": {"heart": 0, "shard": 0, "sulfur": 4, "relic": 0.02, "coins": 120},
}
const DUP_SULFUR := 10      # ours: a relic you have already, come again, is ten sulfur crystals
## the difficulties (the paper's): the lords' health and blows, their moves the quicker, the party's comebacks, Baal's
## eclipse, what the materials are worth and the relics' chance the more. The Abyssal's moves are as quick as the
## Nightmare's (ours: the paper gives the Abyssal no number of its own for it)
const DIFF := {
	"normal": {"name": "일반", "hp": 1.0, "dmg": 1.0, "speed": 1.0, "revives": 10, "eclipse": 12.0, "mats": 1.0, "relic": 0.0, "suffix": ""},
	"nightmare": {"name": "악몽", "hp": 1.45, "dmg": 1.25, "speed": 1.15, "revives": 5, "eclipse": 12.0, "mats": 1.5, "relic": 0.15, "suffix": "n"},
	"abyss": {"name": "심연", "hp": 1.9, "dmg": 1.5, "speed": 1.15, "revives": 0, "eclipse": 9.0, "mats": 1.0, "relic": 0.0, "suffix": "a"},
}
const DIFF_ORDER := ["normal", "nightmare", "abyss"]
## the relics: the altar's slot, the people that can carry it ("": any), whose drop it is (the one of the party that rolls it)
const RELICS := {
	"rl_eclipse": {"slot": "a", "race": "demon", "of": "demon", "name": "바알의 일식 화로 코어", "short": "일식 화로 코어",
		"text": "열기 80% 이상에서 4초 동안 일식 과부하: 열기 95%로 고정(과열 봉인 없음) · 불씨가 적을 꿰뚫음 · 불씨 피해 +25% · 재사용 12초"},
	"rl_chain": {"slot": "a", "race": "orc", "of": "orc", "name": "카르녹의 연쇄 집행 도끼", "short": "연쇄 집행 도끼",
		"text": "사슬 도끼가 적을 셋까지 꿰뚫고 모두 내 앞 2 m로 끌어옴 · 묶인 적을 3초 안에 대검으로 처치하면 도끼 재사용 대기 초기화"},
	"rl_wing": {"slot": "b", "race": "elf", "of": "elf", "name": "심연 날개의 성좌 각인", "short": "심연 날개 각인",
		"text": "바람 걸음 도약(이단 점프 + 대시)을 착지 전까지 두 번씩 · 공중에서 맞힌 석궁 헤드샷 배율 2.0 → 2.5"},
	"rl_ward": {"slot": "c", "race": "", "of": "dwarf", "name": "흑요석 결계 성물", "short": "흑요석 결계 성물",
		"text": "튕겨내기에 성공할 때마다 6 m 안 아군 모두에게 보호막 50 · 튕겨낸 투사체가 닿은 곳에서 4 m 용암 폭발(화염 180)"},
}
const RELIC := {"eclipse_at": 80.0, "eclipse_t": 4.0, "eclipse_heat": 95.0, "eclipse_cd": 12.0, "eclipse_mul": 1.25,
	"chain_n": 3, "chain_to": 2.0, "chain_t": 3.0, "wing_air": 2, "wing_dash": 2, "wing_head": 2.5,
	"ward_r": 6.0, "ward_shield": 50.0, "ward_cap": 100.0, "ward_boom_r": 4.0, "ward_boom": 180.0}
## the looks: what each is, whose weapon (a skin) or what it is for
const LOOKS := {
	"skin_orc": {"kind": "skin", "race": "orc", "name": "대군주의 마그마 대검", "text": "검신에 용암맥이 흐르고, 셋째 일격의 검기가 검은 일식과 용암 파동으로 · 맞히면 묵직한 쇠사슬 마찰음"},
	"skin_demon": {"kind": "skin", "race": "demon", "name": "연옥의 흑요석 지팡이", "text": "끝의 수정 구슬이 불타는 작은 행성(일식)으로 · 열기 80%를 넘으면 흑요석 파편이 지팡이 둘레를 돕니다"},
	"skin_elf": {"kind": "skin", "race": "elf", "name": "타락한 별빛의 비전 석궁", "text": "흰 대리석 틀이 자수정과 흑철로 · 튕기는 차징 사격이 지나간 자리에 보라색 성좌 균열"},
	"skin_dwarf": {"kind": "skin", "race": "dwarf", "name": "심연 용광로 증기포", "text": "흰 증기 대신 붉은 유황 연기와 불티 · 장전할 때 보일러 압력계가 용암빛으로 깜빡입니다"},
	"vfx_eclipse": {"kind": "vfx", "race": "", "name": "심연의 일식 소멸", "text": "내가 쓰러뜨리거나 단검으로 처형한 적 머리 위에 작은 검은 일식이 0.5초 떴다 터지고, 몸은 흑요석 재가 되어 바닥 균열로"},
	"frame_obsidian": {"kind": "frame", "race": "", "name": "마탑 정복자의 흑요석 프레임", "text": "왼쪽·오른쪽 아래 상태 막대 테두리에 황금과 흑요석의 마탑 룬 장식"},
	"charm_mace": {"kind": "charm", "race": "", "name": "카르녹의 미니어처 철퇴", "text": "들고 있는 무기에 매달린 작은 철퇴 장식(악몽 난이도 전용)"},
}
const SKINS := ["skin_orc", "skin_demon", "skin_elf", "skin_dwarf"]
## how the looks that are not made are had (the paper: "업적 달성"; which deed is ours)
const FEATS := {"vfx_eclipse": "종말의 일식을 8초 안에 끝내기", "frame_obsidian": "악몽 이상에서 토벌 성공", "charm_mace": "악몽에서 처음 토벌 성공"}
const TITLES := {"eclipse_breaker": "일식을 부순 자", "abyss_tamer": "심연을 길들인 대마법사"}
## the workshop's sure makings (the paper's prices)
const CRAFT := {"relic": {"heart": 5, "sulfur": 30, "coins": 0}, "skin": {"heart": 12, "shard": 20, "coins": 2000}}

# ---------------- what is kept ----------------
static func blank() -> Dictionary:
	return {"mat": {"heart": 0, "shard": 0, "sulfur": 0}, "coins": 0, "relics": [], "looks": [], "wear": [], "boxes": 0, "titles": [], "title": "",
		"ward": "dwarf", "cleared": [], "feats": [], "runs": 0}

## a kept raid's spoils brought into shape (known things only, whole numbers, nothing below nothing)
static func fix(d) -> Dictionary:
	var o := blank()
	if not (d is Dictionary): return o
	var m = d.get("mat", {})
	if m is Dictionary:
		for k: String in MATS: o.mat[k] = clampi(int(m.get(k, 0)), 0, 99999)
	o.coins = clampi(int(d.get("coins", 0)), 0, 9999999); o.boxes = clampi(int(d.get("boxes", 0)), 0, 99); o.runs = maxi(0, int(d.get("runs", 0)))
	for key: String in ["relics", "looks", "wear", "titles", "cleared", "feats"]:
		var src = d.get(key, [])
		if not (src is Array): continue
		for id in src:
			var s := str(id)
			var ok := false
			match key:
				"relics": ok = RELICS.has(s)
				"looks", "wear": ok = LOOKS.has(s)
				"titles": ok = TITLES.has(s)
				"cleared": ok = DIFF.has(s)
				"feats": ok = FEATS.has(s) or TITLES.has(s)
			if ok and not (o[key] as Array).has(s): (o[key] as Array).push_back(s)
	o.wear = (o.wear as Array).filter(func(id): return (o.looks as Array).has(id))   # (what is worn is what you have)
	var t := str(d.get("title", ""))
	o.title = t if (o.titles as Array).has(t) else ""
	var w := str(d.get("ward", "dwarf"))
	o.ward = w if Races.ORDER.has(w) else "dwarf"
	return o

## the spoils kept, in shape (made the first time)
static func data() -> Dictionary:
	if not (Store.save.get("raid") is Dictionary): Store.save.raid = blank()
	return Store.save.raid

static func has_relic(id: String) -> bool: return (data().relics as Array).has(id)
static func has_look(id: String) -> bool: return (data().looks as Array).has(id)
## a look on (had, and put on in the workshop)
static func wearing(id: String) -> bool: return (data().wear as Array).has(id)
static func wear(id: String, on: bool) -> void:
	var w: Array = data().wear
	if on and has_look(id) and not w.has(id): w.push_back(id)
	if not on: w.erase(id)
## the skin on a people's weapon now, or ""
static func skin_of(race: String) -> String:
	var id := "skin_" + race
	return id if (LOOKS.has(id) and wearing(id)) else ""

## which difficulties are open: the Normal always; each of the others once the one before it is won
static func diff_open(k: String) -> bool:
	if not DIFF.has(k): return false
	var i := DIFF_ORDER.find(k)
	if i == 0 or bool(Store.settings.get("dev", false)): return true
	return (data().cleared as Array).has(DIFF_ORDER[i - 1])
## the difficulty picked on the briefing (an open one)
static func picked() -> String:
	var k := str(Store.settings.get("raidDiff", "normal"))
	return k if diff_open(k) else "normal"
## the records' keys for a difficulty: the best time and the best rank (the Normal's as they were)
static func time_key(k: String) -> String: return "t13" + str(DIFF[k].suffix)
static func rank_key(k: String) -> String: return "r13" + str(DIFF[k].suffix)

## the relic each of the party carries into the raid (his people's, if you have it; the obsidian ward with whoever you
## gave it to in the workshop)
static func relics_for(race: String) -> Array:
	var out: Array = []
	for id: String in RELICS:
		var q: Dictionary = RELICS[id]
		if not has_relic(id): continue
		if str(q.race) == race or (str(q.race) == "" and str(data().ward) == race): out.push_back(id)
	return out

# ---------------- a won raid's spoils ----------------
## what a raid won at this rank and difficulty gives, put in the keeping, and said back: [{kind, id, n, name}] in the
## order shown. rng: the dice (the game's own are not drawn). eclipse_s: how long the eclipse took to end (-1: none)
static func grant(rank: String, diff: String, rng: RandomNumberGenerator, eclipse_s := -1.0) -> Array:
	var d := data(); var R: Dictionary = RANK.get(rank, RANK.C); var D: Dictionary = DIFF.get(diff, DIFF.normal); var out: Array = []
	d.runs = int(d.runs) + 1
	for k: String in MATS:   # the materials sure to come (the Nightmare's half as many again)
		var n := int(floor(float(R[k]) * float(D.mats)))
		if n > 0: d.mat[k] = int(d.mat[k]) + n; out.push_back({"kind": "mat", "id": k, "n": n, "name": MAT_NAME[k]})
	d.coins = int(d.coins) + int(R.coins); out.push_back({"kind": "coins", "id": "coins", "n": int(R.coins), "name": COIN_NAME})
	# each of the party rolls for his people's relic; at S the party is sure of one (one that is not yours yet, if any is)
	var chance := float(R.relic) + float(D.relic); var won: Array = []
	for race: String in Races.ORDER:
		if rng.randf() < chance: won.push_back(_relic_of(race))
	if rank == "S" and won.is_empty():
		var fresh: Array = RELICS.keys().filter(func(id): return not has_relic(id))
		var pool: Array = fresh if not fresh.is_empty() else RELICS.keys()
		won.push_back(pool[rng.randi() % pool.size()])
	for id: String in won:
		if has_relic(id):
			d.mat.sulfur = int(d.mat.sulfur) + DUP_SULFUR; out.push_back({"kind": "dup", "id": id, "n": DUP_SULFUR, "name": str(RELICS[id].name)})
		else:
			(d.relics as Array).push_back(id); out.push_back({"kind": "relic", "id": id, "n": 1, "name": str(RELICS[id].name)})
	# the deeds and the titles
	var first_here: bool = not (d.cleared as Array).has(diff)
	if first_here: (d.cleared as Array).push_back(diff)
	if rank == "S" and not (d.titles as Array).has("eclipse_breaker"): _title(d, "eclipse_breaker", out)
	if diff == "abyss" and rank == "S":
		if not (d.titles as Array).has("abyss_tamer"): _title(d, "abyss_tamer", out)
		if SKINS.all(func(id): return has_look(id)): d.coins = int(d.coins) + int(CRAFT.skin.coins); out.push_back({"kind": "coins", "id": "box_coins", "n": int(CRAFT.skin.coins), "name": COIN_NAME + " (신화 스킨을 모두 가져서 선택 상자 대신)"})
		else: d.boxes = int(d.boxes) + 1; out.push_back({"kind": "box", "id": "box", "n": 1, "name": "신화 무기 스킨 선택 상자"})
	if eclipse_s >= 0.0 and eclipse_s <= 8.0: _feat(d, "vfx_eclipse", out)
	if diff != "normal": _feat(d, "frame_obsidian", out)
	if diff == "nightmare" and first_here: _feat(d, "charm_mace", out)
	return out

static func _relic_of(race: String) -> String:
	for id: String in RELICS:
		if str(RELICS[id].of) == race: return id
	return ""

static func _title(d: Dictionary, id: String, out: Array) -> void:
	(d.titles as Array).push_back(id); out.push_back({"kind": "title", "id": id, "n": 1, "name": "칭호 「%s」" % TITLES[id]})

## a deed done: its look is yours (and on, the first time)
static func _feat(d: Dictionary, look: String, out: Array) -> void:
	if (d.looks as Array).has(look): return
	(d.looks as Array).push_back(look); (d.wear as Array).push_back(look)
	if not (d.feats as Array).has(look): (d.feats as Array).push_back(look)
	out.push_back({"kind": "look", "id": look, "n": 1, "name": str(LOOKS[look].name)})

## a line of the spoils, as the result sheet says it
static func line(it: Dictionary) -> String:
	match str(it.kind):
		"mat": return "%s ×%d" % [str(it.name), int(it.n)]
		"coins": return "%s +%d" % [str(it.name), int(it.n)]
		"relic": return "전설 룬 유물 · %s" % str(it.name)
		"dup": return "%s (이미 있음 → 유황 결정 +%d)" % [str(it.name), int(it.n)]
		"box": return str(it.name)
		"title": return str(it.name)
		"look": return "외형 · %s" % str(it.name)
	return str(it.get("name", ""))

# ---------------- the workshop ----------------
static func can_pay(what: String) -> bool:
	var c: Dictionary = CRAFT[what]; var d := data()
	for k: String in MATS:
		if int(c.get(k, 0)) > int(d.mat[k]): return false
	return int(c.get("coins", 0)) <= int(d.coins)

static func _pay(what: String) -> void:
	var c: Dictionary = CRAFT[what]; var d := data()
	for k: String in MATS: d.mat[k] = int(d.mat[k]) - int(c.get(k, 0))
	d.coins = int(d.coins) - int(c.get("coins", 0))

## a relic made for sure, the one you pick (not one you have). false: not enough, or you have it
static func craft_relic(id: String) -> bool:
	if not RELICS.has(id) or has_relic(id) or not can_pay("relic"): return false
	_pay("relic"); (data().relics as Array).push_back(id)
	return true

## a mythic skin smelted for sure, or taken from a choice box (free)
static func craft_skin(id: String, from_box := false) -> bool:
	if not SKINS.has(id) or has_look(id): return false
	var d := data()
	if from_box:
		if int(d.boxes) <= 0: return false
		d.boxes = int(d.boxes) - 1
	else:
		if not can_pay("skin"): return false
		_pay("skin")
	(d.looks as Array).push_back(id); (d.wear as Array).push_back(id)
	return true
