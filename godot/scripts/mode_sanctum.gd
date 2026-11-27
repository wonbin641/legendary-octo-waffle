class_name ModeSanctum
extends RealmMode
## 성소 각인전 (the sanctum's inscription): the Moonwell's pavilion is the sanctum. Stand in it alone and your side's
## gauge fills, 1.25% a second however many of you there are; the first to 100% takes the round, two rounds the match.
## Each round: 15 s in the base (the altar open, the people and the bombs chosen), 30 s out with the sanctum shut, then
## the fight for it. At 50% the sanctum's mana resounds: a shockwave, and from then the side behind waits less at the
## portals and the well mends more. A leader at 99% with a foe still standing in the sanctum is held there: overtime,
## which ends when the sanctum has been clear of foes for three seconds (half that for each 15 s it has gone on).

const PREP := 15.0; const WAIT := 30.0; const OVER := 4.0
const RATE := 1.25
const BACK := 7.0
const ZONE := 7.0                  # the pavilion's floor
const AT := ElfWood.WELL
const BASE := {"us": Vector3(-146.0, 3.0, 0.0), "them": Vector3(100.0, 0.0, -1.0)}
const HOLD := 3.0; const HOLD_STEP := 15.0
const WAVE := 11.0                 # the resonance's shockwave: who is this near is pushed back (ours)

var gauge := {"us": 0.0, "them": 0.0}
var inside := {"us": 0, "them": 0}
var resonated := false
var overtime := false; var ot_t := 0.0; var clear_t := 0.0
var _marks := {"us": 0, "them": 0}   # the quarters of the gauge a side has passed (those standing in the sanctum have a part in it)
var _tick := 0.0
var shield_n: Array = []

func base_of(team: String) -> Vector3: return BASE[team]
func aim_point(_team: String) -> Vector3: return AT
func back_time(_f: Realm.Fighter) -> float: return BACK
func brief_line() -> String: return "달샘 정자(성소)를 차지해 각인 게이지 100% · 3판 2선승"
func brief() -> Array:
	return ["성소(달샘 정자) 안에 우리 편만 서 있으면 각인 게이지가 초당 1.25% 오릅니다", "먼저 100%를 채운 편이 라운드를 가져갑니다 · 3판 2선승",
		"쓰러지면 7초 뒤 본진 마법진에서 다시 일어납니다", "50%에서 마력 공명: 뒤처진 편의 포탈 대기가 줄고 달샘 회복이 늘어납니다", "라운드 사이 15초: B 키로 룬 제단 · 종족과 폭탄 교체"]
func win_title() -> String: return "성소 각인 완료"
func bonus() -> int: return 30000 * Store.PAY
func works(team: String) -> Array: return [BASE[team]]

func start() -> void:
	round_n = 1; wins = {"us": 0, "them": 0}; won = ""
	for f: Realm.Fighter in rm.all: f.shards = int(Races.SHARDS.sanctum[0])
	_round()

func _round() -> void:
	gauge = {"us": 0.0, "them": 0.0}; resonated = false; overtime = false; ot_t = 0.0; clear_t = 0.0; rm.resonant = ""; _marks = {"us": 0, "them": 0}
	muster(); shop_ai(); set_phase("prep", PREP)
	rm.look.base_shield(true)
	if rm.game != null: rm.game.say_banner("%d라운드 준비" % round_n, "B: 룬 제단 · 종족과 폭탄을 고르세요", 2.4); Snd.play("rm_prep")

func update(dt: float) -> void:
	if phase_t > 0.0 and not (phase == "prep" and rm.altar_open):
		phase_t -= dt
		if phase_t <= 0.0: _next()
	if phase == "prep": _keep_in()
	if phase != "fight": return
	inside = {"us": 0, "them": 0}
	var within: Array = []
	for f: Realm.Fighter in rm.all:
		if f.alive and in_zone(f.pos): inside[f.team] = int(inside[f.team]) + 1; within.push_back(f)
	for team: String in ["us", "them"]:
		var foe := rm.other(team)
		if int(inside[team]) > 0 and int(inside[foe]) == 0:
			var cap := 99.0 if overtime else 100.0   # (in overtime it is the sanctum staying clear that ends the round)
			gauge[team] = minf(cap, float(gauge[team]) + RATE * dt)
			for f: Realm.Fighter in within: rm.gain(f, float(Races.GAUGE.capture) * dt)
			var q := int(float(gauge[team]) / 25.0)
			if q > int(_marks[team]):   # a quarter of the gauge: those who stood for it have their part (the shards' bonus)
				_marks[team] = q
				for f: Realm.Fighter in within: f.bonus = mini(3, f.bonus + 1)
		# a leader at 99% and a foe in the sanctum: it waits there
		if float(gauge[team]) >= 99.0 and float(gauge[team]) < 100.0 and int(inside[foe]) > 0 and not overtime:
			overtime = true; ot_t = 0.0; clear_t = 0.0; Snd.play("rm_overtime")
			if rm.game != null: rm.game.say_banner("추가 시간", "성소 안의 적을 몰아내야 끝납니다", 1.8)
	if not resonated and (float(gauge.us) >= 50.0 or float(gauge.them) >= 50.0): _resound("us" if float(gauge.us) >= 50.0 else "them")
	if overtime:
		ot_t += dt
		var lead := "us" if float(gauge.us) >= float(gauge.them) else "them"
		if int(inside[rm.other(lead)]) > 0: clear_t = 0.0; gauge[lead] = minf(float(gauge[lead]), 99.0)
		else: clear_t += dt
		if clear_t >= hold_need(): gauge[lead] = 100.0
	for team: String in ["us", "them"]:
		if float(gauge[team]) >= 100.0 and not (overtime and int(inside[rm.other(team)]) > 0): _won_round(team); return

## how long the sanctum must be clear of foes for the overtime to end: three seconds, half that for each 15 s gone
func hold_need() -> float: return HOLD / pow(2.0, floorf(ot_t / HOLD_STEP))

func in_zone(p: Vector3) -> bool: return Vector2(p.x - AT.x, p.z - AT.z).length() < ZONE and p.y < 4.0 and p.y > -1.0

func _next() -> void:
	match phase:
		"prep":
			set_phase("wait", WAIT); rm.look.base_shield(false)
			if rm.game != null: rm.game.say_banner("출전", "성소는 30초 뒤에 열립니다", 1.8)
		"wait":
			set_phase("fight")
			if rm.game != null: rm.game.say_banner("성소 개방", "정자 안을 차지하세요", 1.8); Snd.play("rm_bell")
		"over":
			if won != "": set_phase("end"); rm.finish(won == "us")
			else: round_n += 1; _round()

func _keep_in() -> void:
	for f: Realm.Fighter in rm.all:
		var b: Vector3 = BASE[f.team]; var gap := Vector2(f.pos.x - b.x, f.pos.z - b.z)
		if gap.length() > 6.5:
			var q := b + Vector3(gap.x, 0, gap.y).normalized() * 6.4; f.pos = Vector3(q.x, f.pos.y, q.z)
			if f.me and rm.player != null: rm.player.pos = f.pos; rm.player.vel = Vector3.ZERO

## 50%: the sanctum's mana resounds
func _resound(lead: String) -> void:
	resonated = true; rm.resonant = rm.other(lead)
	for f: Realm.Fighter in rm.all:
		if f.alive and f.pos.distance_to(AT) < WAVE: rm.shove(f, f.pos - AT if f.pos.distance_to(AT) > 0.3 else Vector3(1, 0, 0), 2.5)
	Snd.play("rm_resonance", 1.0, AT); rm.look.resonance(AT, WAVE); rm.music_break += 1
	if rm.game != null: rm.game.say_banner("마력 공명", ("우리" if rm.resonant == "us" else "적") + " 편의 포탈 대기 8초 · 달샘 회복 초당 25", 2.4)
	rm.note(["resonance", lead])

func _won_round(team: String) -> void:
	wins[team] = int(wins[team]) + 1; overtime = false
	var loser := rm.other(team)
	if int(wins[team]) >= 2: won = team
	else:   # the shards for the next round: the round's losers a little more; each his own part on top
		for f: Realm.Fighter in rm.all:
			if round_n == 1: f.shards += (int(Races.SHARDS.sanctum_win) if f.team == team else int(Races.SHARDS.sanctum_lose)) + mini(int(Races.SHARDS.bonus_max), f.bonus * int(Races.SHARDS.bonus))
			else: f.shards += int(Races.SHARDS.sanctum[2])
			f.bonus = 0
	set_phase("over", OVER)
	Snd.play("rm_round_win" if team == "us" else "rm_round_lose")
	if rm.game != null: rm.game.say_banner(("라운드 승리" if team == "us" else "라운드 패배"), "우리 %d : %d 적" % [int(wins.us), int(wins.them)], 2.6)
	rm.note(["round", team, loser])

# ---------------- where the others go ----------------
func goal(f: Realm.Fighter) -> Dictionary:
	var i := rm.team_of(f.team).find(f); var mine: Vector3 = BASE[f.team]; var side := -1.0 if f.team == "us" else 1.0
	if phase == "wait":   # out, toward the sanctum, to wait a little way off on their own side
		return {"at": Vector3(AT.x + side * (16.0 + 3.0 * (i % 3)), 0.0, (i - 2) * 3.2), "near": 2.0}
	if phase != "fight": return {}
	# elves stand off where they see into it; the rest go in, each to his own place on the floor
	if f.race == "elf" and int(inside[f.team]) > 0: return {"at": Vector3(AT.x + side * 13.0, 0.0, (i - 2) * 3.0), "near": 2.0}
	var a := i * TAU / 5.0 + (0.0 if f.team == "us" else 0.6)
	return {"at": Vector3(AT.x + cos(a) * 4.2, AT.y, AT.z + sin(a) * 4.2), "near": 1.2, "stay": int(inside[rm.other(f.team)]) == 0 and in_zone(f.pos)}

# ---------------- the screens ----------------
func hud() -> Dictionary:
	var sub := ""
	match phase:
		"prep": sub = "준비 %d초 · B 룬 제단" % ceili(phase_t)
		"wait": sub = "성소 개방까지 %d초" % ceili(phase_t)
		"fight": sub = "추가 시간" if overtime else ("마력 공명" if resonated else "성소를 차지하세요")
		_: sub = "라운드 종료"
	return {"title": "성소 각인전 · %d라운드" % round_n, "sub": sub, "us": float(gauge.us), "them": float(gauge.them), "wins": wins, "in": inside, "overtime": overtime, "mark": 50.0,
		"in_zone": rm.me != null and rm.me.alive and in_zone(rm.me.pos)}

func tac() -> Array:
	return [{"x": AT.x, "z": AT.z, "c": "ffd66b", "r": ZONE, "label": "성소"}, {"x": float(BASE.us.x), "z": float(BASE.us.z), "c": "5f9cff", "r": 6.5, "label": "우리 본진"}, {"x": float(BASE.them.x), "z": float(BASE.them.z), "c": "ff5260", "r": 6.5, "label": "적 본진"}]

## the music: the wood's set; the fight for the sanctum once it has resounded, the climax at 90% or in overtime (a semitone up
## each time the hold shortens)
func music_set() -> String: return "rf"
func music_stage() -> int:
	if phase != "fight": return 1
	if overtime or maxf(float(gauge.us), float(gauge.them)) >= 90.0: return 4
	return 3 if resonated else 1
func music_semis() -> int: return mini(3, int(floorf(ot_t / HOLD_STEP)) + 1) if overtime else 0

func marks() -> Array: return [{"at": AT + Vector3(0, 3.2, 0), "c": "ffd66b", "label": "성소"}] if phase != "prep" else []

func state() -> Dictionary: return {"phase": phase, "round": round_n, "wins": wins, "gauge": gauge, "overtime": overtime, "resonated": resonated, "t": phase_t}
