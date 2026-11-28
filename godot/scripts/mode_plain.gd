class_name ModePlain
extends RealmMode
## 6-2, 네 깃발 평원 (the plain of the four banners), on your own: you are one of the four peoples (picked on the
## briefing), and so is the landmark in your corner (BannerPlain), which summons your people to fight beside you. The other
## three landmarks summon theirs against you. Break those three and fell every one of theirs still standing, and the plain
## is yours. Your own landmark falling is no defeat in itself; but while it stands you come back at it when you fall, and
## once it is down a fall is the end.
## Each landmark summons one of its people on a clock (no more than three of a landmark's standing at once). Theirs: the
## first two of a landmark's to stand at home keep watch over it, the third goes raiding to your landmark (or, once it is
## down, after you), and back home when his own is struck. Yours: one keeps watch, the rest go to whichever of theirs stands
## nearest you. Those summoned later come with more runes cut. A landmark is walls, not flesh: what the summoned do to it is
## a fifth of what you do, and one left alone for a while mends. It falls when its 4,000 is gone: its people summon no more,
## and those of them still standing come for you. You are the plain's hero: the summoned are a little less hardy than one of
## their people in a battle of five, and strike you a little less hard.

const PREP := 10.0                 # at your landmark before the summoning begins (the altar open)
const HP := 4000.0                 # a landmark's
const TROOPS := 0.2                # what the summoned do to a landmark, of what they would do to it (you: all of it)
const HARDY := 0.75                # the summoned's health, of their people's
const HERO := 0.55                 # what theirs do to you, of what they would (one of them alone, not five: the battle of five's quick falls would leave you none)
const SUMMON := 20.0               # seconds between a landmark's summonings
const FIRST := {"them": 3.0, "us": 1.0}
const SQUAD := {"them": 1, "us": 1}
const CAP := {"them": 3, "us": 3}  # a landmark's own standing at once
const HOME_R := 55.0               # a raider this near home goes back when his landmark is struck
const GUARDS := {"them": 2, "us": 1}   # of a landmark's three, how many keep watch at home
const MEND := 10.0; const MEND_WAIT := 8.0   # a landmark unstruck this long mends so much a second
const BACK := 8.0                  # you, at your landmark, while it stands
const GONE := 2.5                  # a fallen summoned one is gone from the field this long after
const OVER := 3.0
const ALTAR_R := 10.0              # how near your landmark the altar opens in the fight
const SHARDS := {"start": 300, "kill": 50, "hall": 250}
const RUNES_AT := {"start": 200, "step": 120, "every": 60.0, "max": 1100}   # shards a summoned one cuts runes with: more the longer the battle has gone
const STAND := {"elf": 15.0, "demon": 10.0, "dwarf": 3.0, "orc": 2.2}   # how far out from a landmark's middle each people strikes it from (past its body)

var mine := "elf"                  # your people, and your landmark's
var halls := {}                    # race -> its landmark as a thing (kit.things): {kind "hall", race, pos, r, h, team, hp, max, ...}
var fight_clock := 0.0             # seconds since the summoning began
var next := {}                     # race -> seconds till it summons again
var waves := {}                    # race -> how many times it has summoned
var role := {}                     # fighter id -> "guard", "raid" (theirs to your landmark, yours to theirs) or "hunt" (after the other side's people)
var home := {}                     # fighter id -> the people whose landmark summoned him
var gone := {}                     # fighter id -> seconds till a fallen summoned one is taken off the field
var plain: BannerPlain = null
var outcome := ""                  # "won" / "lost", once it is decided
var _last_hp := {}
var _hit_t := {}                   # race -> seconds since its landmark was last struck

static func record_of(race: String) -> String: return "t11" + race
## which peoples have taken the plain (each its best time, in seconds)
static func cleared_by() -> Dictionary:
	var out := {}
	for r: String in Races.ORDER:
		var k := record_of(r)
		if Store.save.best.has(k): out[r] = int(Store.save.best[k])
	return out

func lineup() -> bool: return false     # (no five a side: you alone at first, and what the landmarks summon)
func own_graph() -> bool: return true   # (the plain's own waypoints, not the wood's)
func clears() -> bool: return true      # (a win is the stage cleared, as any stage's)
func standing(race: String) -> bool: return halls.has(race) and float((halls[race] as Dictionary).hp) > 0.0
func foes_left() -> int:
	var n := 0
	for f: Realm.Fighter in rm.all:
		if f.team == "them" and f.alive: n += 1
	return n
func halls_left() -> int:
	var n := 0
	for r: String in halls:
		if r != mine and standing(r): n += 1
	return n
func of(race: String) -> Array:   # a landmark's summoned still standing
	return rm.all.filter(func(f: Realm.Fighter) -> bool: return f.alive and not f.me and str(home.get(f.id, "")) == race)

# ---------------- the battle ----------------
func build() -> void:
	plain = rm.world.plain if rm.world != null else null
	mine = Realm.picked_race()
	for r: String in Races.ORDER:
		var B: Array = BannerPlain.BODY[r]
		var th := {"kind": "hall", "race": r, "pos": BannerPlain.at(r), "r": float(B[0]), "h": float(B[1]), "team": "us" if r == mine else "them", "by": null,
			"hp": HP, "max": HP, "since": 99.0, "keep": true, "prize": true, "bldg": true, "made": false, "troops": TROOPS, "snd": "rm_hall_hit", "dead": func(by) -> void: _fell(r, by)}   # (stone and timber: no element bites it the harder)
		if plain != null: th.node = plain.halls[r].node
		halls[r] = rm.kit.add_thing(th)
		_last_hp[r] = HP; _hit_t[r] = 99.0
		if plain != null:
			for b: Phys.Box in plain.halls[r].boxes: b.ref = halls[r]   # (a shot meeting the landmark's boxes meets the landmark)

func start() -> void:
	won = ""; outcome = ""; fight_clock = 0.0
	for r: String in Races.ORDER: next[r] = float(FIRST["us" if r == mine else "them"]) + Races.ORDER.find(r) * 1.5; waves[r] = 0
	rm.me.shards = int(SHARDS.start)
	rm.back(rm.me)
	set_phase("prep", PREP)
	if rm.game != null: rm.game.say_banner("네 깃발 평원 · " + str(Races.R[mine].name), "B: 룬 제단 · %d초 뒤 건물들이 소환을 시작합니다" % int(PREP), 3.0); Snd.play("rm_prep")

func update(dt: float) -> void:
	if phase_t > 0.0 and not (phase == "prep" and rm.altar_open):
		phase_t -= dt
		if phase_t <= 0.0:
			if phase == "prep":
				set_phase("fight"); Snd.play("rm_bell")
				if rm.game != null: rm.game.say_banner("소환 시작", "적 건물 셋을 부수고 남은 적을 모두 쓰러뜨리세요", 2.4)
			elif phase == "over": set_phase("end"); rm.finish(outcome == "won"); return
	# the fallen summoned leave the field a moment after (their bodies have gone to dust by then)
	for id in gone.keys():
		gone[id] = float(gone[id]) - dt
		if float(gone[id]) <= 0.0:
			var f := rm.by_id(int(id)); gone.erase(id); role.erase(id); home.erase(id)
			if f != null: rm.drop(f)
	for r: String in halls:
		var th: Dictionary = halls[r]; _hit_t[r] = float(_hit_t[r]) + dt
		if float(th.hp) < float(_last_hp[r]) - 0.01:
			if r == mine and float(_hit_t[r]) > 12.0 and rm.game != null: rm.game.say_feed("우리 건물이 공격받고 있습니다 · %d%%" % ceili(100.0 * float(th.hp) / HP)); Snd.play("rm_hall_alarm")   # (told again only after a quiet spell)
			_hit_t[r] = 0.0
		elif phase == "fight" and float(th.hp) > 0.0 and float(_hit_t[r]) > MEND_WAIT: th.hp = minf(HP, float(th.hp) + MEND * dt)
		_last_hp[r] = float(th.hp)
		if plain != null: plain.set_hurt(r, 1.0 - float(th.hp) / HP)
	if phase != "fight": return
	fight_clock += dt
	for r: String in Races.ORDER:
		if not standing(r): continue
		next[r] = float(next[r]) - dt
		if float(next[r]) <= 0.0: next[r] = SUMMON; summon(r)
	# a decision
	if outcome == "":
		if halls_left() == 0 and foes_left() == 0: _decide("won")
		elif not rm.me.alive and not standing(mine): _decide("lost")

func _decide(how: String) -> void:
	outcome = how; won = "us" if how == "won" else "them"; set_phase("over", OVER)
	Snd.play("rm_round_win" if how == "won" else "rm_round_lose")
	if rm.game != null:
		if how == "won": rm.game.say_banner("평원 제패", "%s로 네 깃발 평원을 깼습니다" % str(Races.R[mine].name), 2.8)
		else: rm.game.say_banner("패배", "우리 건물이 무너진 뒤 쓰러졌습니다", 2.8)
	rm.note(["plain", how])

## a landmark calls its people: as many as it may have standing, one or two at a time, at the spots before its door
func summon(race: String) -> int:
	var team := "us" if race == mine else "them"
	var n := mini(int(SQUAD[team]), int(CAP[team]) - of(race).size())
	if n <= 0: return 0
	waves[race] = int(waves[race]) + 1
	var shards := mini(int(RUNES_AT.max), int(RUNES_AT.start) + int(RUNES_AT.step) * int(fight_clock / float(RUNES_AT.every)))
	for i in n:
		var f := rm.add(team, race); home[f.id] = race; f.max_hp *= HARDY
		f.bomb_kinds = [Races.BOMBS[randi() % 3]]; f.shards = shards; _cut(f)
		var guards := of(race).filter(func(o: Realm.Fighter) -> bool: return str(role.get(o.id, "")) == "guard").size()
		role[f.id] = "guard" if guards < int(GUARDS[team]) else "raid"
		rm.back(f)
	if rm.look != null: rm.look.summoned(BannerPlain.at(race) + BannerPlain.front(race) * (float(BannerPlain.BODY[race][0]) + 5.0), race)
	Snd.play("rm_summon_" + race, 1.0, BannerPlain.at(race))
	rm.note(["summon", race, n])
	return n

## a summoned one spends his shards: the dearest rune he can pay for in each empty slot
func _cut(f: Realm.Fighter) -> void:
	for slot in ["a", "b", "c"]:
		var best := ""; var cost := 0
		for id: String in Races.runes_for(f.race, slot):
			var c := int(Races.RUNES[id].cost)
			if c <= f.shards and c > cost: best = id; cost = c
		if best != "": rm.buy(f, best)

## a landmark broken
func _fell(race: String, by) -> void:
	if plain != null: plain.fall(race)
	Snd.play("rm_hall_fall", 1.0, BannerPlain.at(race)); rm.duck_t = maxf(rm.duck_t, 1.2); rm.music_break += 1
	for f: Realm.Fighter in of(race): role[f.id] = "hunt"   # (what it had summoned comes for you)
	if race == mine:
		if rm.game != null: rm.game.say_banner("우리 건물이 무너졌습니다", "이제 쓰러지면 다시 일어날 수 없습니다", 2.8)
	else:
		rm.me.shards += int(SHARDS.hall)
		if rm.game != null: rm.game.say_banner(str(BannerPlain.NAMES[race]) + " 붕괴", ("남은 적 건물 %d · 마력 파편 +%d" % [halls_left(), int(SHARDS.hall)]) if halls_left() > 0 else "마지막 건물입니다 · 남은 적을 모두 쓰러뜨리세요", 2.6)
		if halls_left() == 0:
			for f: Realm.Fighter in rm.all:
				if f.team == "them": role[f.id] = "hunt"
	rm.note(["hall", race, (by as Realm.Fighter).id if by != null else 0])

# ---------------- falling and coming back ----------------
func held(_f: Realm.Fighter) -> bool: return phase == "prep" or phase == "over" or phase == "end"
func rooted() -> bool: return phase == "over" or phase == "end"
func altar_ok() -> bool:
	if phase == "prep": return true
	return phase == "fight" and rm.me != null and rm.me.alive and standing(mine) and Vector2(rm.me.pos.x - BannerPlain.at(mine).x, rm.me.pos.z - BannerPlain.at(mine).z).length() < float(BannerPlain.BODY[mine][0]) + ALTAR_R
func altar_why() -> String: return "룬 제단은 준비 시간이나 우리 건물 곁(%d m 안)에서 열 수 있습니다" % int(ALTAR_R)
func base_of(team: String) -> Vector3: return BannerPlain.at(mine) if team == "us" else Vector3.ZERO
func aim_point(_team: String) -> Vector3: return Vector3.ZERO
func back_time(f: Realm.Fighter) -> float:
	if f.me: return BACK if standing(mine) else -1.0
	return -1.0   # (the summoned never come back: the landmark summons others)
func down_line(f: Realm.Fighter) -> String:
	return ("%d초 뒤 우리 건물 앞에서 다시 일어납니다" % ceili(f.back_t)) if f.back_t > 0.0 else "우리 건물이 무너져 다시 일어날 수 없습니다"
func back_line() -> String: return "우리 건물 앞"
func spawn_at(f: Realm.Fighter) -> Vector3:
	var race := mine if f.me else str(home.get(f.id, mine))
	var S: Array = BannerPlain.spots(race); var start := 1 if f.me else (int(waves.get(race, 0)) * 2 + of(race).size()) % S.size()
	for k in S.size():   # the first spot nobody stands on
		var p: Vector3 = S[(start + k) % S.size()]
		var taken := false
		for o: Realm.Fighter in rm.all:
			if o != f and o.alive and Vector2(o.pos.x - p.x, o.pos.z - p.z).length() < 1.2: taken = true; break
		if not taken: p.y = Phys.ground_at(p.x, 0.6, p.z, 0.3); return p
	var q: Vector3 = S[start]; q.y = Phys.ground_at(q.x, 0.6, q.z, 0.3)
	return q
func face_at(_f: Realm.Fighter, p: Vector3) -> float: return atan2(p.x, p.z)   # (toward the plain's middle)
func on_down(v: Realm.Fighter, by: Realm.Fighter) -> void:
	if by != null and by.me and v.team != by.team: by.shards += int(SHARDS.kill)
	if not v.me: gone[v.id] = GONE
func works(team: String) -> Array: return [BannerPlain.at(mine)] if team == "us" and standing(mine) else []
func dmg_mul(by: Realm.Fighter, v: Realm.Fighter) -> float: return HERO if (v.me and by != null and not by.me) else 1.0

# ---------------- where the others go ----------------
## the plain's waypoints (BannerPlain's grid over the open ground) and the ways between neighbours that can be walked
func extra_nodes() -> Dictionary:
	var out := {}
	if plain == null: return out
	var g := plain.graph_nodes()
	for k: String in g: out[k] = Vector3(float(g[k][0]), float(g[k][1]), float(g[k][2]))
	return out
func extra_edges() -> Array:
	var out: Array = []; var nd := extra_nodes()
	for k: String in nd:
		var ij := k.substr(1).split("_"); var i := int(ij[0]); var j := int(ij[1])
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other := "g%d_%d" % [i + d.x, j + d.y]
			if nd.has(other) and rm.ai.walkable(nd[k], nd[other]): out.push_back([k, other])
	return out

## the landmark a fighter of ours or theirs is set against: theirs raid yours; ours, theirs nearest you
func _against(f: Realm.Fighter) -> String:
	var r := str(role.get(f.id, "raid"))
	if r == "hunt" or r == "guard": return ""
	if f.team == "them": return mine if standing(mine) else ""
	var best := ""; var bd := INF; var from := rm.me.pos if rm.me != null else f.pos
	for race: String in halls:
		if race == mine or not standing(race): continue
		var d := from.distance_to(BannerPlain.at(race))
		if d < bd: bd = d; best = race
	return best

func goal(f: Realm.Fighter) -> Dictionary:
	if phase != "fight": return {}
	var r := str(role.get(f.id, "raid")); var h := str(home.get(f.id, mine))
	if r == "raid" and f.team == "them" and standing(h) and float(_hit_t.get(h, 99.0)) < 4.0 and f.pos.distance_to(BannerPlain.at(h)) < HOME_R: r = "guard"   # (home, to his landmark struck)
	if r == "guard" and standing(h):   # about his landmark, each at his own place round it
		var c := BannerPlain.at(h); var a := atan2(BannerPlain.front(h).z, BannerPlain.front(h).x) + (f.id % 5 - 2) * 0.5
		return {"at": c + Vector3(cos(a), 0, sin(a)) * (float(BannerPlain.BODY[h][0]) + 6.0), "near": 2.5}
	var target := _against(f)
	if target != "":   # to strike the landmark from his people's distance, on the side he comes from
		var c := BannerPlain.at(target); var from := f.pos - c; from.y = 0.0
		if from.length() < 0.1: from = BannerPlain.front(target)
		var reach := float(BannerPlain.BODY[target][0]) + float(STAND[f.race])
		return {"at": c + from.normalized() * reach, "near": 2.0}
	# after the other side's people: you, for theirs (or whoever of ours is nearest); theirs nearest, for ours
	var near_: Realm.Fighter = null; var nd := INF
	for o: Realm.Fighter in rm.all:
		if o.team == f.team or not o.alive: continue
		var d := f.pos.distance_to(o.pos) - (12.0 if o.me else 0.0)
		if d < nd: nd = d; near_ = o
	if near_ == null: return {"at": BannerPlain.at(h) if standing(h) else Vector3.ZERO, "near": 4.0}
	return {"at": near_.pos, "near": 1.6 if (f.race == "orc" or f.race == "dwarf") else 8.0}

func prize(f: Realm.Fighter):
	if phase != "fight": return null
	var target := _against(f)
	return halls[target] if target != "" else null

# ---------------- the screens ----------------
func hud() -> Dictionary:
	var sub := ""
	match phase:
		"prep": sub = "준비 %d초 · B 룬 제단" % ceili(phase_t)
		"fight":
			var nxt := INF
			for r: String in halls:
				if r != mine and standing(r): nxt = minf(nxt, float(next[r]))
			sub = ("남은 적 건물 %d · 다음 소환 %d초" % [halls_left(), ceili(nxt)]) if halls_left() > 0 else "남은 적 %d" % foes_left()
		_: sub = "평원 제패" if outcome == "won" else ("패배" if outcome == "lost" else "")
	var hs: Array = []
	for r: String in Races.ORDER:
		var th: Dictionary = halls[r]
		hs.push_back({"race": r, "q": float(th.hp) / HP, "mine": r == mine, "hit": float(_hit_t[r]) < 1.0})
	return {"title": "네 깃발 평원 · " + str(Races.R[mine].name), "sub": sub, "halls": hs, "foes": foes_left(), "roster": false}

func brief_line() -> String: return "적 건물 셋을 부수고 남은 적을 모두 쓰러뜨리세요 · " + str(Races.R[Realm.picked_race()].name) + "로 출전"
func brief() -> Array:
	return ["정사각형 평원의 네 모서리에 엘프 달빛 첨탑 · 드워프 룬 대장간 · 오크 전쟁 토템 · 악마 지옥 균열문", "고른 종족의 건물은 우리 편: %d초마다 아군 1명(최대 %d명)을 소환합니다" % [int(SUMMON), int(CAP.us)],
		"다른 세 건물은 %d초마다 적을 %d명씩(건물마다 최대 %d명) · 건물 체력 %s(소환된 병사의 공격은 20%%만 들어가고, 8초 동안 안 맞으면 회복) · 부수면 더 소환하지 않습니다" % [int(SUMMON), int(SQUAD.them), int(CAP.them), Store.won(int(HP)).replace("원", "")],
		"적 건물 셋을 부수고 남은 적까지 모두 쓰러뜨리면 클리어 · 깬 종족은 메뉴에 표시됩니다", "쓰러지면 %d초 뒤 우리 건물 앞에서 다시 일어납니다 · 우리 건물이 무너진 뒤 쓰러지면 끝" % int(BACK),
		"B: 룬 제단(준비 시간, 또는 우리 건물 곁) · 처치 +%d · 건물 +%d 마력 파편" % [int(SHARDS.kill), int(SHARDS.hall)]]
func win_title() -> String: return "네 깃발 평원 제패"
func pause_line() -> String: return "네 깃발 평원 · 남은 적 건물 %d · 남은 적 %d" % [halls_left(), foes_left()]
func record_key() -> String: return record_of(mine)
func bonus() -> int: return 50000 * Store.PAY
func tac() -> Array:
	var out: Array = []
	for r: String in Races.ORDER:
		var c := BannerPlain.at(r); var up := standing(r)
		out.push_back({"x": c.x, "z": c.z, "c": ("5f9cff" if r == mine else str(Races.R[r].col)) if up else "8d949c", "r": float(BannerPlain.BODY[r][0]) + 1.5,
			"label": str(Races.R[r].name) + (" (우리)" if r == mine else "") + ("" if up else " 무너짐")})
	return out
func marks() -> Array:
	var out: Array = []
	if phase != "fight": return out
	for r: String in Races.ORDER:
		if r == mine or not standing(r): continue
		out.push_back({"at": BannerPlain.at(r) + Vector3(0, float(BannerPlain.BODY[r][1]) + 2.0, 0), "c": str(Races.R[r].col), "label": str(BannerPlain.NAMES[r])})
	return out
## the music: the plain's own set (the four banners' march); how far it has come by the landmarks fallen
func music_set() -> String: return "rp"
func music_stage() -> int:
	if phase != "fight": return 1
	var down := 3 - halls_left()
	if down >= 3 or (standing(mine) and float((halls[mine] as Dictionary).hp) < HP * 0.3): return 4
	return 3 if down >= 1 else 2
func state() -> Dictionary:
	var hp := {}
	for r: String in halls: hp[r] = float((halls[r] as Dictionary).hp)
	return {"phase": phase, "halls": hp, "foes": foes_left(), "allies": rm.all.filter(func(f: Realm.Fighter) -> bool: return f.team == "us" and f.alive and not f.me).size(), "clock": fight_clock, "outcome": outcome, "waves": waves.duplicate()}
