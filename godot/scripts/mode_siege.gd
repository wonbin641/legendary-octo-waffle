class_name ModeSiege
extends RealmMode
## 비전 핵 공성전 (the siege of the arcane nucleus): the Archmage's tower is held by one side and stormed by the other;
## then they change places, and whoever broke the nucleus (or broke it faster, or came nearer to it) wins.
## A half: 25 s in the bases; then four minutes for the stormers to carry the alchemical bomb from where they start to
## one of the two ward altars in the court, set it (4 s) and see it go off (35 s); the holders can unset it (5 s, half
## of that kept once 2.5 s are done). The first ward down unseals the observatory, moves the stormers' base into the
## court and adds 3 min 30 s; both down and the amplifying circle is the stormers'. Up there the nucleus (3,500, under
## a shield of 1,000 that comes back) is broken with weapons. The holders lay two summoning traps before each part.

const PREP := 25.0; const TIME1 := 240.0; const TIME2 := 210.0; const TURN := 10.0; const OVER := 5.0
const PLANT := 4.0; const FUSE := 35.0; const DEFUSE := 5.0; const DEFUSE_HALF := 2.5; const SET_R := 2.3; const TAKE_R := 1.7
const NUC_HP := 3500.0; const NUC_SHIELD := 1000.0; const NUC_REGEN := 150.0; const NUC_WAIT := 5.0
const BACK_ATT := 6.0; const BACK_DEF := 9.0
const BOMB_BACK := 5.0             # ours: a new bomb is at the stormers' base this long after the last went off or was unset
const BLAST := {"r": 6.0, "dmg": 150.0}   # ours: what the bomb does to whoever stands by it
const TRAP := {"r": 1.5, "wait": 2.0, "hp": 150.0}
const TC := ElfWood.TC
const SITES := {"a": Vector3(127.0, 0.0, -17.0), "b": Vector3(120.6, 0.5, 13.4)}
const ATT1 := Vector3(94.0, 0.0, -2.0); const ATT2 := Vector3(116.0, 0.0, 0.0)
const DEF1 := Vector3(150.5, 0.0, 0.0)
const NUC := Vector3(134.0, 20.7, 0.0)
const GATE := Vector3(110.0, 0.0, 0.0)   # the tower's lower entrance: where a trap sends whoever steps in it
# the rune slots a trap can be laid in: [name, x, y, z]
const SLOTS := [["결계 A 앞", 127.0, 0.0, -13.6], ["결계 B 앞", 123.6, 0.0, 9.6], ["1층 계단 입구", 124.0, 0.0, 0.0], ["1층 계단 중간", 144.0, 5.0, 0.3],
	["서고 서쪽", 122.0, 10.0, 0.6], ["서고 남쪽", 134.0, 10.0, 12.0], ["2층 계단 입구", 143.3, 10.2, -1.0], ["천문대 입구", 142.6, 20.0, -1.6]]

var attackers := "us"
var half := 1
var stage := 1                 # 1: the wards; 2: the nucleus
var time_left := TIME1
var elapsed := 0.0
var turn_t := 0.0
var wards := {"a": true, "b": true}
var bomb := {"state": "none", "pos": Vector3.ZERO, "by": null, "site": "", "t": 0.0, "fuse": 0.0, "cut": 0.0, "saved": false, "wait": 0.0, "plan": "a"}
var nucleus := {}
var traps: Array = []          # {slot, pos, thing, by, wait, who}
var trap_pick := [0, 1]        # the two slots you lay yours in, when you hold the tower
var results: Array = []        # each half: {team, done, t, dmg, wards}
var nodes := {}                # what stands on the map: altars, the bomb, the seal
var _seal: Phys.Box = null
var _fuse_snd := 0.0

func defenders() -> String: return rm.other(attackers)
func base_of(team: String) -> Vector3:
	if team == attackers: return ATT1 if stage == 1 else ATT2
	return DEF1
func aim_point(team: String) -> Vector3: return Vector3(TC.x, 0, TC.y) if team == attackers else Vector3(100.0, 0, 0)
func back_time(f: Realm.Fighter) -> float: return BACK_ATT if f.team == attackers else BACK_DEF
func altar_ok() -> bool: return phase == "prep" or (phase == "fight" and turn_t > 0.0)   # (the ten seconds before the nucleus too: the new shards)
func amp_owner() -> String: return attackers if (not wards.a and not wards.b) else defenders()
func brief_line() -> String: return "전반은 공격, 후반은 수비 · 결계를 폭파하고 탑 꼭대기의 비전 핵을 부수세요"
func brief() -> Array:
	return ["전반은 우리가 공격, 후반은 수비 · 핵을 부순 편(둘 다면 더 빨리 부순 편)이 이깁니다", "1단계 4분: 시작 지점의 파괴의 연금술 폭탄을 결계 제단 A나 B에 설치(4초) · 35초 뒤 폭발",
		"수비는 5초 동안 해체합니다 · 2.5초를 넘기면 절반이 저장됩니다", "결계 하나가 터지면 천문대 봉인이 풀리고 3분 30초가 더해집니다 · 둘 다 터지면 비전 증폭 진이 공격 편 것",
		"2단계: 무기로 비전 핵(체력 3,500 + 보호막 1,000)을 직접 부숩니다", "부활: 공격 6초 · 수비 9초 · 수비는 준비 시간마다 역소환 함정진 2개"]
func win_title() -> String: return "비전 핵 공성전 승리"
func bonus() -> int: return 80000
func works(team: String) -> Array:
	var out: Array = [base_of(team)]
	if team == defenders():
		for t: Dictionary in traps: out.push_back(t.pos)
	if team == amp_owner(): out.push_back(ElfWood.AMP)
	return out
func prize(f: Realm.Fighter): return nucleus if (stage == 2 and f.team == attackers and not nucleus.is_empty() and float(nucleus.hp) > 0.0) else null

## the holders come back on the second flight, three quarters of the way up, once the fight is for the nucleus
func spawn_at(f: Realm.Fighter) -> Vector3:
	if f.team == attackers or stage == 1: return super.spawn_at(f)
	var i := rm.team_of(f.team).find(f); var a := deg_to_rad(-270.0 + (i - 2) * 5.0)
	var p := Vector3(TC.x + cos(a) * 9.3, ElfWood.T_F2 + (ElfWood.T_F3 - ElfWood.T_F2) * 0.75 + 1.0, TC.y + sin(a) * 9.3)
	p.y = Phys.ground_at(p.x, p.y, p.z, 0.3)
	return p

func build() -> void:
	for k: String in SITES: nodes["altar_" + k] = rm.look.prop("altar", SITES[k], k.to_upper())
	nodes["bomb"] = rm.look.prop("bomb", Vector3.ZERO, "")
	nodes["nucleus"] = rm.look.prop("nucleus", NUC, "")

func cleanup() -> void:
	_unseal()
	for k in nodes:
		if is_instance_valid(nodes[k]): (nodes[k] as Node).queue_free()
	nodes.clear()
	for t: Dictionary in traps:
		if t.has("node") and is_instance_valid(t.node): (t.node as Node).queue_free()
	traps.clear()

func start() -> void:
	half = 1; attackers = "us"; results = []; won = ""
	for f: Realm.Fighter in rm.all: f.shards = int(Races.SHARDS.siege)
	_half()

func _half() -> void:
	stage = 1; time_left = TIME1; elapsed = 0.0; turn_t = 0.0; wards = {"a": true, "b": true}
	for k: String in SITES: rm.look.prop_state(nodes.get("altar_" + k), "whole")
	_new_bomb(0.0)
	muster()
	rm.kit.things.clear()
	nucleus = rm.kit.add_thing({"kind": "nucleus", "pos": NUC, "r": 1.3, "h": 2.6, "team": defenders(), "by": null, "hp": NUC_HP, "max": NUC_HP, "shield": NUC_SHIELD, "shield_max": NUC_SHIELD, "since": 99.0, "keep": true, "prize": true,
		"open": func() -> bool: return stage == 2, "dead": _nucleus_down, "node": nodes.get("nucleus")})
	_seal_up()
	shop_ai(); _lay_traps()
	set_phase("prep", PREP); rm.look.base_shield(true)
	if rm.game != null:
		var mine := attackers == "us"
		rm.game.say_banner(("전반" if half == 1 else "후반") + (" · 공격" if mine else " · 수비"), "B: 룬 제단" + ("" if mine else " · 함정진 자리 고르기"), 2.6); Snd.play("rm_prep")

func _new_bomb(wait: float) -> void:
	if bomb.by != null: (bomb.by as Realm.Fighter).carrying = false
	bomb = {"state": "none" if wait > 0.0 else "home", "pos": base_of(attackers) + Vector3(0, 0, 3.0), "by": null, "site": "", "t": 0.0, "fuse": 0.0, "cut": 0.0, "saved": false, "wait": wait, "plan": "a" if randf() < 0.5 else "b"}
	if not wards[bomb.plan]: bomb.plan = "b" if bomb.plan == "a" else "a"

func _seal_up() -> void:
	_unseal()
	_seal = Phys.add_collider(TC.x + 7.8, ElfWood.T_F2, TC.y - 1.9, TC.x + 10.9, ElfWood.T_F2 + 4.6, TC.y - 1.5, "concrete")
	nodes["seal"] = rm.look.prop("seal", Vector3(TC.x + 9.35, ElfWood.T_F2, TC.y - 1.7), "")

func _unseal() -> void:
	if _seal != null: Phys.remove_collider(_seal); _seal = null
	if nodes.has("seal") and is_instance_valid(nodes.seal): (nodes.seal as Node).queue_free()
	nodes.erase("seal")

## the holders' two traps, laid again before each part: yours where you chose, theirs by the part of the fight
func _lay_traps() -> void:
	for t: Dictionary in traps:
		if float((t.thing as Dictionary).hp) > 0.0: (t.thing as Dictionary).hp = 0.0
		if t.has("node") and is_instance_valid(t.node): (t.node as Node).queue_free()
	traps.clear()
	var team := defenders()
	var picks: Array = trap_pick.duplicate() if team == "us" else ([0, 1] if stage == 1 else [6, [3, 4, 5, 7][randi() % 4]])
	for s in picks:
		var q: Array = SLOTS[clampi(int(s), 0, SLOTS.size() - 1)]; var at := Vector3(q[1], q[2], q[3]); at.y = Phys.ground_at(at.x, at.y + 0.9, at.z, 0.3)
		var th := rm.kit.add_thing({"kind": "trap", "pos": at, "r": 1.1, "h": 0.5, "team": team, "by": null, "hp": float(TRAP.hp), "max": float(TRAP.hp)})
		traps.push_back({"slot": int(s), "pos": at, "thing": th, "wait": 0.0, "who": null, "node": rm.look.prop("trap", at, "")})

func update(dt: float) -> void:
	if phase == "prep" or phase == "over":
		if not (phase == "prep" and rm.altar_open): phase_t -= dt
		if phase == "prep": _keep_in()
		if phase_t <= 0.0: _next()
		return
	if phase != "fight": return
	elapsed += dt
	if turn_t > 0.0:   # the ten seconds between the wards and the nucleus: the clock waits
		turn_t -= dt
		if turn_t <= 0.0 and rm.game != null: rm.game.say_banner("2단계 · 비전 핵 파괴전", "천문대의 비전 핵을 부수세요" if attackers == "us" else "천문대의 비전 핵을 지키세요", 2.2)
	else: time_left = maxf(0.0, time_left - dt)
	_bomb(dt); _traps(dt)
	if not nucleus.is_empty() and float(nucleus.hp) > 0.0:   # the nucleus' shield comes back when it has not been struck for a while
		nucleus.since = float(nucleus.since) + dt
		if float(nucleus.since) >= NUC_WAIT and float(nucleus.shield) < NUC_SHIELD: nucleus.shield = minf(NUC_SHIELD, float(nucleus.shield) + NUC_REGEN * dt)
	if time_left <= 0.0 and bomb.state != "set": _half_over(false)

func _keep_in() -> void:
	for f: Realm.Fighter in rm.all:
		var b := base_of(f.team); var gap := Vector2(f.pos.x - b.x, f.pos.z - b.z)
		if gap.length() > 6.5:
			var q := b + Vector3(gap.x, 0, gap.y).normalized() * 6.4; f.pos = Vector3(q.x, f.pos.y, q.z)
			if f.me and rm.player != null: rm.player.pos = f.pos; rm.player.vel = Vector3.ZERO

func _next() -> void:
	match phase:
		"prep":
			set_phase("fight"); rm.look.base_shield(false)
			if rm.game != null: rm.game.say_banner("1단계 · 결계 돌파전", "폭탄을 결계 제단에 설치하세요" if attackers == "us" else "결계 제단을 지키세요", 2.2)
		"over":
			if half == 1:
				half = 2; attackers = "them"
				for f: Realm.Fighter in rm.all: f.runes = {"a": "", "b": "", "c": ""}; f.shards = int(Races.SHARDS.siege_swap); f.bonus = 0; rm.refit(f)   # (the second half: everyone builds anew)
				_half()
			else: _decide()

# ---------------- the bomb and the wards ----------------
func _bomb(dt: float) -> void:
	var st: String = bomb.state
	if st == "none":
		bomb.wait = float(bomb.wait) - dt
		if float(bomb.wait) <= 0.0 and (wards.a or wards.b): _new_bomb(0.0)
		return
	if st == "home" or st == "down":
		for f: Realm.Fighter in rm.all:
			if f.alive and f.team == attackers and f.pos.distance_to(bomb.pos) < TAKE_R + f.R:
				bomb.state = "held"; bomb.by = f; f.carrying = true; bomb.t = 0.0
				if not wards[bomb.plan]: bomb.plan = "b" if bomb.plan == "a" else "a"
				if rm.game != null: rm.game.say_feed((f.name if not f.me else "당신") + (" " if f.me else "") + "· 파괴의 연금술 폭탄 수령")
				Snd.play("rm_plant", 0.8, f.pos); rm.note(["take", f.id]); break
		return
	if st == "held":
		var f: Realm.Fighter = bomb.by
		if f == null or not f.alive: return
		bomb.pos = f.pos; var site := ""
		for k: String in SITES:
			if wards[k] and f.pos.distance_to(SITES[k]) < SET_R + f.R: site = k
		if site == "": bomb.t = 0.0; return
		if f.delay_t <= 0.0: bomb.t = float(bomb.t) + dt
		_fuse_snd -= dt
		if _fuse_snd <= 0.0: _fuse_snd = 0.5; Snd.play("rm_plant", 0.8, f.pos)
		if float(bomb.t) >= PLANT:
			bomb.state = "set"; bomb.site = site; bomb.fuse = FUSE; bomb.cut = 0.0; bomb.saved = false; bomb.pos = SITES[site]; bomb.by = null; f.carrying = false
			rm.gain(f, float(Races.GAUGE.bomb)); f.bonus = mini(3, f.bonus + 1)
			if rm.game != null: rm.game.say_banner("폭탄 설치 · 결계 " + site.to_upper(), "35초 뒤 폭발합니다", 2.0)
			rm.note(["set", site, f.id])
		return
	# set: the fuse runs; the holders unset it
	bomb.fuse = float(bomb.fuse) - dt
	_fuse_snd -= dt
	if _fuse_snd <= 0.0: _fuse_snd = 1.0 if float(bomb.fuse) > 10.0 else 0.4; Snd.play("rm_fuse", 0.9, bomb.pos)
	var at: Vector3 = SITES[bomb.site]; var who: Realm.Fighter = null; var best := INF
	for f: Realm.Fighter in rm.all:
		if f.alive and f.team != attackers and f.pos.distance_to(at) < SET_R + f.R and f.pos.distance_to(at) < best: best = f.pos.distance_to(at); who = f
	if who != null:
		if who.delay_t <= 0.0: bomb.cut = float(bomb.cut) + dt
		if float(bomb.cut) >= DEFUSE_HALF: bomb.saved = true
		if float(bomb.cut) >= DEFUSE:
			rm.gain(who, float(Races.GAUGE.bomb)); who.bonus = mini(3, who.bonus + 1); Snd.play("rm_defuse", 1.0, at)
			if rm.game != null: rm.game.say_banner("폭탄 해체", "결계 " + str(bomb.site).to_upper() + "를 지켰습니다" if attackers != "us" else "새 폭탄이 시작 지점에 놓입니다", 2.0)
			rm.note(["unset", str(bomb.site), who.id]); _new_bomb(BOMB_BACK); return
	else: bomb.cut = DEFUSE_HALF if bool(bomb.saved) else 0.0
	if float(bomb.fuse) <= 0.0: _ward_down(str(bomb.site))

func _ward_down(site: String) -> void:
	var at: Vector3 = SITES[site]
	wards[site] = false; rm.look.prop_state(nodes.get("altar_" + site), "broken")
	Snd.play("rm_ward", 1.0, at); rm.look.burst(at, float(BLAST.r), "alchemy")
	for f: Realm.Fighter in rm.all:
		if f.alive and f.feet_mid().distance_to(at) < float(BLAST.r): rm.hurt(f, float(BLAST.dmg), "alchemy", null, {"fixed": true, "aoe": true, "src": "bomb", "from": at})
	rm.note(["ward", site])
	if stage == 1:   # the first ward down: the observatory unsealed, the stormers' base in the court, more time, new traps
		stage = 2; turn_t = TURN; time_left += TIME2; _unseal()
		for f: Realm.Fighter in rm.all: f.shards += int(Races.SHARDS.siege_att) if f.team == attackers else int(Races.SHARDS.siege_def)
		shop_ai(); _lay_traps()
		if rm.game != null: rm.game.say_banner("결계 " + site.to_upper() + " 파괴", "천문대 봉인 해제 · 제한 시간 +3분 30초", 2.6)
	elif rm.game != null: rm.game.say_banner("결계 " + site.to_upper() + " 파괴", "비전 증폭 진이 " + ("우리" if attackers == "us" else "적") + " 편 것이 되었습니다", 2.6)
	_new_bomb(BOMB_BACK)

func on_down(v: Realm.Fighter, _by: Realm.Fighter) -> void:
	if bomb.by == v:   # the bomb falls where its carrier fell
		bomb.state = "down"; bomb.by = null; bomb.t = 0.0; bomb.pos = Vector3(v.pos.x, Phys.ground_at(v.pos.x, v.pos.y + 0.5, v.pos.z, 0.3), v.pos.z); v.carrying = false
		if rm.game != null: rm.game.say_feed("폭탄이 떨어졌습니다")

func _nucleus_down(by) -> void:
	Snd.play("rm_nucleus", 1.0, NUC); rm.look.burst(NUC, 9.0, "arcane"); rm.look.prop_state(nodes.get("nucleus"), "broken")
	if by != null: rm.gain(by, float(Races.GAUGE.bomb))
	_half_over(true)

func _half_over(done: bool) -> void:
	if phase != "fight": return
	results.push_back({"team": attackers, "done": done, "t": elapsed, "dmg": (NUC_HP - float(nucleus.hp)) if not nucleus.is_empty() else 0.0, "wards": (0 if wards.a else 1) + (0 if wards.b else 1)})
	set_phase("over", OVER)
	var mine := attackers == "us"
	Snd.play("rm_round_win" if done == mine else "rm_round_lose")
	if rm.game != null: rm.game.say_banner(("비전 핵 파괴" if done else "시간 종료"), ("공격 성공" if done else "공격 실패") if mine else ("수비 실패" if done else "수비 성공"), 2.8)
	rm.note(["half", attackers, done, elapsed])

## after both halves: who broke the nucleus; both, who broke it sooner; neither, who hurt it more, then who blew more wards
func _decide() -> void:
	var a: Dictionary = results[0]; var b: Dictionary = results[1]; var win := decide(a, b)
	won = win; set_phase("end")
	if win == "": lose_stamp = "무승부"; lose_title = "두 편의 기록이 같습니다"
	rm.finish(win == "us")

static func decide(a: Dictionary, b: Dictionary) -> String:
	if bool(a.done) != bool(b.done): return str(a.team) if bool(a.done) else str(b.team)
	if bool(a.done) and absf(float(a.t) - float(b.t)) > 0.001: return str(a.team) if float(a.t) < float(b.t) else str(b.team)
	if absf(float(a.dmg) - float(b.dmg)) > 0.5: return str(a.team) if float(a.dmg) > float(b.dmg) else str(b.team)
	if int(a.wards) != int(b.wards): return str(a.team) if int(a.wards) > int(b.wards) else str(b.team)
	return ""

# ---------------- the traps ----------------
func _traps(dt: float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var t: Dictionary = traps[i]
		if float((t.thing as Dictionary).hp) <= 0.0:
			if is_instance_valid(t.node): (t.node as Node).queue_free()
			traps.remove_at(i); continue
		if t.who == null:
			for f: Realm.Fighter in rm.all:
				if f.alive and f.team == attackers and f.inv <= 0.0 and f.pos.distance_to(t.pos) < float(TRAP.r) + f.R:
					t.who = f; t.wait = float(TRAP.wait); Snd.play("rm_trap", 1.0, t.pos); rm.note(["trap", f.id, int(t.slot)])
					if f.me and rm.game != null: rm.game.say_feed("역소환 함정진 · 2초 뒤 탑 아래 입구로 보내집니다")
					break
			continue
		t.wait = float(t.wait) - dt
		if float(t.wait) > 0.0: continue
		var f: Realm.Fighter = t.who
		if f.alive:   # sent back down to the tower's lower entrance
			var to := GATE + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)); to.y = Phys.ground_at(to.x, 1.0, to.z, 0.3)
			rm.look.ported(f, f.pos, to); f.pos = to; f.vel = Vector3.ZERO; f.vy = 0.0
			if f.me and rm.player != null: rm.player.pos = to; rm.player.vel = Vector3.ZERO
			rm.astray(f)
			Snd.play("elf_portal", 1.0, to)
		(t.thing as Dictionary).hp = 0.0

# ---------------- where the others go ----------------
func goal(f: Realm.Fighter) -> Dictionary:
	if phase != "fight": return {}
	var team := rm.team_of(f.team); var i := team.find(f); var att := f.team == attackers
	if att:
		if bomb.by == f:
			var k: String = bomb.plan
			if not wards[k]: k = "b" if k == "a" else "a"
			return {"at": SITES[k], "near": 1.0, "hurry": true}
		if (bomb.state == "home" or bomb.state == "down") and _fetcher() == f: return {"at": bomb.pos, "near": 0.6, "hurry": true}
		if stage == 2 and bomb.state != "set":
			var a := i * TAU / 5.0
			return {"at": Vector3(NUC.x + cos(a) * 4.6, ElfWood.T_F3, NUC.z + sin(a) * 4.6), "near": 1.5}
		var site: String = str(bomb.site) if bomb.state == "set" else _site_now()
		var s: Vector3 = SITES[site]; var a2 := i * TAU / 5.0
		return {"at": s + Vector3(cos(a2) * 4.5, 0, sin(a2) * 4.5), "near": 2.0}
	# the holders
	if bomb.state == "set":
		var s2: Vector3 = SITES[str(bomb.site)]; var order := team.filter(func(q): return q.alive)
		order.sort_custom(func(p, q): return p.pos.distance_to(s2) < q.pos.distance_to(s2))
		if order.find(f) < 2: return {"at": s2, "near": 1.0, "hurry": order.find(f) == 0}
		return {"at": s2 + Vector3(cos(i * 1.3) * 5.0, 0, sin(i * 1.3) * 5.0), "near": 2.0}
	if stage == 2:
		var a3 := i * TAU / 5.0 + 0.6
		return {"at": Vector3(NUC.x + cos(a3) * 5.6, ElfWood.T_F3, NUC.z + sin(a3) * 5.6), "near": 1.5}
	var k2 := "a" if i % 2 == 0 else "b"
	if not wards[k2]: k2 = "b" if k2 == "a" else "a"
	var w: Vector3 = SITES[k2]
	return {"at": w + Vector3(cos(i * 1.7) * 4.0, 0, sin(i * 1.7) * 4.0), "near": 2.0}

## the one of the stormers' others who goes for a bomb lying about: the nearest to it (you, if you are nearer, are left to it)
func _fetcher() -> Realm.Fighter:
	var best: Realm.Fighter = null; var bd := INF
	for f: Realm.Fighter in rm.all:
		if f.alive and f.team == attackers and f.pos.distance_to(bomb.pos) < bd: bd = f.pos.distance_to(bomb.pos); best = f
	return best if (best != null and not best.me) else null

func _site_now() -> String:
	if bomb.by != null:   # where its carrier is heading: the nearer standing altar to him (yours, if you carry it)
		var c: Realm.Fighter = bomb.by
		if not c.me: return str(bomb.plan) if wards[bomb.plan] else ("b" if bomb.plan == "a" else "a")
		var k := "a" if c.pos.distance_to(SITES.a) < c.pos.distance_to(SITES.b) else "b"
		return k if wards[k] else ("b" if k == "a" else "a")
	return str(bomb.plan) if wards[bomb.plan] else ("b" if bomb.plan == "a" else "a")

# ---------------- the screens ----------------
func hud() -> Dictionary:
	var mine := attackers == "us"; var sub := ""
	if phase == "prep": sub = "준비 %d초 · B 룬 제단" % ceili(phase_t)
	elif phase == "over": sub = "공수 교대" if half == 1 else "판정"
	elif stage == 1:
		match str(bomb.state):
			"set": sub = "결계 %s 폭발까지 %d초" % [str(bomb.site).to_upper(), ceili(float(bomb.fuse))]
			"held": sub = ("폭탄 설치 중 %d%%" % int(float(bomb.t) / PLANT * 100.0)) if float(bomb.t) > 0.0 else ("폭탄을 결계 제단 A나 B로" if mine else "적이 폭탄을 들고 옵니다")
			_: sub = "시작 지점의 폭탄을 드세요" if mine else "결계 제단을 지키세요"
	else: sub = "비전 핵을 부수세요" if mine else "비전 핵을 지키세요"
	var out := {"title": "비전 핵 공성전 · " + ("전반" if half == 1 else "후반") + (" 공격" if mine else " 수비"), "sub": sub, "clock": time_left, "wards": wards, "stage": stage, "bomb": str(bomb.state),
		"carrying": rm.me != null and bomb.by == rm.me, "plant": float(bomb.t) / PLANT if bomb.state == "held" else 0.0, "fuse": float(bomb.fuse) if bomb.state == "set" else 0.0, "cut": float(bomb.cut) / DEFUSE if bomb.state == "set" else 0.0}
	if stage == 2 and not nucleus.is_empty(): out["nuc"] = float(nucleus.hp) / NUC_HP; out["nuc_shield"] = float(nucleus.shield) / NUC_SHIELD
	return out

func tac() -> Array:
	var out: Array = [{"x": base_of("us").x, "z": base_of("us").z, "c": "5f9cff", "r": 6.5, "label": "우리 본진"}, {"x": base_of("them").x, "z": base_of("them").z, "c": "ff5260", "r": 6.5, "label": "적 본진"}]
	for k: String in SITES:
		if wards[k]: out.push_back({"x": SITES[k].x, "z": SITES[k].z, "c": "ffd66b", "r": 3.0, "label": "결계 " + k.to_upper()})
	out.push_back({"x": NUC.x, "z": NUC.z, "c": "b892ff", "r": 2.5, "label": "비전 핵"})
	if bomb.state != "none": out.push_back({"x": (bomb.pos as Vector3).x, "z": (bomb.pos as Vector3).z, "c": "ff9a3a", "r": 1.6, "label": "폭탄"})
	if defenders() == "us":
		for t: Dictionary in traps: out.push_back({"x": (t.pos as Vector3).x, "z": (t.pos as Vector3).z, "c": "8ff7ea", "r": 1.5, "label": "함정"})
	return out

func marks() -> Array:
	var out: Array = []
	if phase != "fight": return out
	for k: String in SITES:
		if wards[k]: out.push_back({"at": SITES[k] + Vector3(0, 3.4, 0), "c": "ffd66b", "label": "결계 " + k.to_upper()})
	if bomb.state == "home" or bomb.state == "down": out.push_back({"at": (bomb.pos as Vector3) + Vector3(0, 1.4, 0), "c": "ff9a3a", "label": "폭탄"})
	if stage == 2: out.push_back({"at": NUC + Vector3(0, 3.4, 0), "c": "b892ff", "label": "비전 핵"})
	return out

func state() -> Dictionary: return {"phase": phase, "half": half, "stage": stage, "attackers": attackers, "time": time_left, "wards": wards, "bomb": str(bomb.state), "nucleus": float(nucleus.get("hp", 0.0)), "shield": float(nucleus.get("shield", 0.0)), "results": results}
