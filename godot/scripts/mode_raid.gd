class_name ModeRaid
extends RealmMode
## 6-A, 타락한 마탑 토벌전 (the raid on the fallen tower): a party of four, one of each people. You are one of them; the
## other three are played by the realm's minds (RealmAI), and Tab (or 1 to 4, or the touch button) puts you into another
## one's shoes: the one you were goes on by himself. The road (DemonRoad) is five sections: the camp (the rune altar, the
## blessing circle, the supply crates), the ruined gate, the chain bridge over the lava, the tower's spiral stair (Karnok,
## the chain executioner) and the sky altar (Baal, lord of the abyss). A section's red seal lifts only when every demon in
## it is down. The party has ten comebacks between them: a fallen one is back at the last checkpoint 8 s later while any
## are left. All four down and nobody coming back: the raid is lost; so is it when Baal's eclipse of doom is completed.
## Baal down: the raid is won, and ranked S to C by the time, the party's falls and how well the bosses' tricks were met.

const REVIVES := 10                 # the party's comebacks, shared (the paper's Normal)
const BACK := 8.0                   # a fallen one is back at the last checkpoint this long after
const SWITCH_CD := 0.5              # (a key held down: not a blur of bodies)
const AUTO_SWITCH := 1.5            # you fell for good: this long after, into one of the others still standing
const BLESS := {"r": 3.6, "mul": 1.15, "t": 90.0}   # the camp's circle: 15% more from whoever stepped in it, for a minute and a half
const CRATE := {"r": 2.4, "cd": 20.0}              # a supply crate: the weapon loaded and the bombs back (each of you once every 20 s)
const SHARDS := {"start": 600, "kill": 30, "imp": 10, "elite": 250, "core": 400}   # each of the party's (a demon down: everyone's)
const STAND := {"elf": 18.0, "demon": 11.0, "dwarf": 4.0, "orc": 1.8}   # how near the others close in on what they fight
const LAVA_Y := DemonRoad.LAVA + 1.2   # below this: in the lava, and done for
const CORE_R := 2.0                 # the corrupted core: how near to take it
const ALTAR_R := 4.5                # how near a rune altar opens
const ALTAR_B := Vector3(DemonRoad.TC.x + 11.0, DemonRoad.T_TOP, 4.0)   # the altar on the tower's top that wakes with the core
const LIFT := {"hall": 17.0, "pad": 26.0, "r": 2.2, "cd": 1.6}   # the gravity circles: how hard they throw you up
const COOL_R := 2.4
const RANK := {"S": {"t": 720.0, "deaths": 2}, "A": {"t": 960.0, "deaths": 5, "eclipse": 8.0}, "B": {"t": 1200.0, "deaths": 9}}
const RANK_N := {"C": 1, "B": 2, "A": 3, "S": 4}
const OVER := 4.0
const SECTIONS := ["숲속 캠프", "무너진 외성문", "용암 사슬 다리", "탑 내부 나선 계단", "심연의 제단"]
const AIMS := ["룬 제단에서 각인하고 축복의 마법진을 밟은 뒤 동쪽 외성문으로", "잔해 뒤의 악마 경비병을 모두 쓰러뜨리면 동쪽 봉인이 풀립니다",
	"기둥 위의 저격병과 용암 거수를 쓰러뜨리면 탑의 문이 열립니다", "나선 계단을 올라 카르녹을 쓰러뜨리세요", "심연의 대군주 바알을 쓰러뜨리세요"]

var road: DemonRoad = null
var fiends: Fiends = null
var cp := 0                         # the last checkpoint reached (its section)
var revives := REVIVES
var deaths := 0                     # the party's falls
var clock := 0.0                    # seconds since the party set off
var cleared := {}                   # section -> true, once its seal is gone
var karnok: Realm.Fighter = null; var baal: Realm.Fighter = null
var core := {}                      # the corrupted core, once Karnok is down: {pos, node}
var core_taken := false
var altar_b: Node3D = null
var parries := 0                    # Karnok's javelins turned back into him
var cores_first := false            # Baal's wing cores broken in his sun's first charge
var eclipse_t0 := -1.0; var eclipse_kill := -1.0
var bless := {}                     # fighter id -> seconds of blessing left
var crate_t := {}; var lift_t := {}; var cool_t := {}
var gone := {}                      # fighter id -> seconds till a fallen demon is off the field
var outcome := ""; var rank := ""
var boss_up: Realm.Fighter = null   # the lord whose bar is at the top of the screen
var _switch_t := 0.0; var _auto_t := 0.0
var _said := {}                     # what a lord said last, and when (said once in a while, not every frame)
var _cp_said := 0

func party() -> Array: return rm.all.filter(func(f: Realm.Fighter) -> bool: return f.team == "us")
func demons() -> Array: return rm.all.filter(func(f: Realm.Fighter) -> bool: return Fiends.is_mon(f))
## the one the others go with: you, while you stand; else the first of the party standing
func leader() -> Realm.Fighter:
	if rm.me != null and rm.me.alive: return rm.me
	for f: Realm.Fighter in party():
		if f.alive: return f
	return rm.me
func left_in(sec: int) -> int:
	var n := 0
	for f: Realm.Fighter in rm.all:
		if f.alive and Fiends.is_mon(f) and int(f.brain.get("sec", -1)) == sec and not f.brain.get("extra", false): n += 1
	return n

func lineup() -> bool: return false     # (the party is made here: one of each people)
func own_graph() -> bool: return true   # (the road's own waypoints)
func clears() -> bool: return true      # (a win is the stage cleared)
func held(_f: Realm.Fighter) -> bool: return phase == "over" or phase == "end"
func rooted() -> bool: return phase == "over" or phase == "end"

# ---------------- the raid ----------------
func build() -> void:
	road = rm.world.road if rm.world != null else null
	fiends = Fiends.new(); fiends.rm = rm; fiends.mode = self; fiends.road = road
	if road != null: road.make_seals()

func start() -> void:
	won = ""; outcome = ""; rank = ""; clock = 0.0; cp = 0; revives = REVIVES; deaths = 0; cleared = {}; core = {}; core_taken = false
	parries = 0; cores_first = false; eclipse_t0 = -1.0; eclipse_kill = -1.0; boss_up = null
	var first := rm.me
	for r: String in Races.ORDER:
		if r == first.race: continue
		var f := rm.add("us", r); f.bomb_kinds = [Races.BOMBS[randi() % 3]]; rm.refit(f)
	rm.all.sort_custom(func(a: Realm.Fighter, b: Realm.Fighter) -> bool: return Races.ORDER.find(a.race) < Races.ORDER.find(b.race))   # (the party in the four peoples' order: the keys 1 to 4)
	for f: Realm.Fighter in party(): f.shards = int(SHARDS.start); f.name = str(Races.R[f.race].name)
	shop_ai()
	for f: Realm.Fighter in party(): rm.back(f); f.inv = 0.0; f.haste_t = 0.0
	if road != null:
		for p: Dictionary in road.posts: fiends.make(str(p.type), Vector3(float(p.x), float(p.y), float(p.z)), int(p.sec), {"perch": p.get("perch", false), "yaw": float(p.get("yaw", PI / 2.0))})
		var kp := road.balcony_at(120.0); var kd := Vector3(DemonRoad.TC.x - kp.x, 0, DemonRoad.TC.y - kp.z)
		karnok = fiends.make("karnok", kp, 3, {"yaw": atan2(-kd.x, -kd.z)})
		baal = fiends.make("baal", Vector3(DemonRoad.AC.x, DemonRoad.A_Y, DemonRoad.AC.y), 4, {"yaw": PI / 2.0})
	set_phase("fight")
	if rm.game != null: rm.game.say_banner("타락한 마탑 토벌전", "Tab: 동료로 교대 · B: 캠프의 룬 제단 · 봉인은 구간의 악마를 모두 쓰러뜨리면 풀립니다", 3.4); Snd.play("rm_prep")

func update(dt: float) -> void:
	if fiends != null: fiends.tick(dt)
	if phase == "over":
		phase_t -= dt
		if phase_t <= 0.0: set_phase("end"); rm.finish(outcome == "won")
		return
	if phase != "fight": return
	clock += dt; _switch_t = maxf(0.0, _switch_t - dt)
	_keys(dt)
	for id in gone.keys():   # (a fallen demon's body is gone a moment after: off the field)
		gone[id] = float(gone[id]) - dt
		if float(gone[id]) <= 0.0:
			var f := rm.by_id(int(id)); gone.erase(id)
			if f != null: rm.drop(f)
	_where()
	if road != null: _camp(dt); _circles(dt); _core(dt)
	_seals()
	if outcome == "": _decide()

## Tab: the next of the party standing; 1 to 4: that one (the four peoples' order); fallen for good: the next, by itself
func _keys(dt: float) -> void:
	if rm.press.has("switch"): switch_next()
	for i in 4:
		if rm.press.has("switch_%d" % i):
			var p := party()
			if i < p.size(): switch_to(p[i])
	if rm.me != null and not rm.me.alive and rm.me.back_t <= 0.0:
		_auto_t += dt
		if _auto_t >= AUTO_SWITCH: _auto_t = 0.0; switch_next()
	else: _auto_t = 0.0

func switch_next() -> bool:
	var p := party(); var i := p.find(rm.me)
	for k in range(1, p.size()):
		var f: Realm.Fighter = p[(i + k) % p.size()]
		if f.alive: return switch_to(f)
	return false

func switch_to(f: Realm.Fighter) -> bool:
	if f == null or _switch_t > 0.0 or f == rm.me or not f.alive: return false
	if not rm.switch_me(f): return false
	_switch_t = SWITCH_CD; Snd.play("rd_switch", 0.9)
	if rm.game != null: rm.game.say_feed("교대 · " + str(Races.R[f.race].name) + " (" + str(Races.R[f.race].weapon) + ")")
	return true

## where the party has got to (the checkpoint moves on with whoever is farthest along); the lava takes whoever is in it
func _where() -> void:
	for f: Realm.Fighter in rm.all:
		if not f.alive: continue
		if f.pos.y < LAVA_Y: _lava(f); continue
		if Fiends.is_mon(f): continue
		var s := DemonRoad.section_of(f.pos)
		if s > cp:
			cp = s; Snd.play("rd_checkpoint", 0.8)
			if rm.game != null and s > _cp_said: _cp_said = s; rm.game.say_feed("거점 갱신 · " + str(SECTIONS[s]) + " (쓰러지면 여기서 다시 일어납니다)")

func _lava(f: Realm.Fighter) -> void:
	if f.me and Store.settings.dev and Store.settings.god:   # (developer mode's invincibility: back at the checkpoint instead)
		var p := spawn_at(f); f.pos = p
		if rm.player != null: rm.player.pos = p; rm.player.vel = Vector3.ZERO
		return
	f.inv = 0.0; f.phased_t = 0.0
	rm.slay(f, null, {"src": "lava"})
	Snd.play("rd_lava", 1.0, f.feet_mid())
	if rm.game != null and not Fiends.is_mon(f): rm.game.say_feed(str(Races.R[f.race].name) + "이(가) 용암에 떨어졌습니다")

## the camp: its blessing circle, its supply crates
func _camp(dt: float) -> void:
	for f: Realm.Fighter in party():
		bless[f.id] = maxf(0.0, float(bless.get(f.id, 0.0)) - dt); crate_t[f.id] = maxf(0.0, float(crate_t.get(f.id, 0.0)) - dt)
		if not f.alive: continue
		if Vector2(f.pos.x - road.bless_at.x, f.pos.z - road.bless_at.z).length() < float(BLESS.r) and f.pos.y < 1.5:
			if float(bless[f.id]) < float(BLESS.t) - 2.0:
				Snd.play("rd_bless", 0.8, f.feet_mid())
				if f.me and rm.game != null: rm.game.say_feed("축복의 마법진 · %d초 동안 주는 피해 +%d%%" % [int(BLESS.t), roundi((float(BLESS.mul) - 1.0) * 100.0)])
			bless[f.id] = float(BLESS.t)
		if float(crate_t[f.id]) <= 0.0:
			for c: Vector3 in road.crates:
				if f.pos.distance_to(c) < float(CRATE.r):
					crate_t[f.id] = float(CRATE.cd); f.ammo = rm.kit.mag(f); f.reload_t = 0.0; f.bombs = f.bomb_kinds.size(); f.bomb_t = 0.0
					Snd.play("rd_supply", 0.9, c)
					if f.me and rm.game != null: rm.game.say_feed("보급 상자 · 탄과 연금술 폭탄을 채웠습니다")
					break

## the altar's cooling circles (the burn put out), the gravity circles (the hall's once Karnok is down off the balcony; the
## altar's two while Baal is in the air): they throw whoever steps on them up
func _circles(dt: float) -> void:
	var hall := karnok != null and (not karnok.alive or int(karnok.brain.get("phase", 1)) >= 2)
	var pads := baal != null and baal.alive and int(baal.brain.get("phase", 1)) == 2
	for f: Realm.Fighter in party():
		lift_t[f.id] = maxf(0.0, float(lift_t.get(f.id, 0.0)) - dt); cool_t[f.id] = maxf(0.0, float(cool_t.get(f.id, 0.0)) - dt)
		if not f.alive: continue
		for c: Vector3 in road.cools:
			if Vector2(f.pos.x - c.x, f.pos.z - c.z).length() < COOL_R and absf(f.pos.y - c.y) < 1.5 and f.burn_t > 0.0:
				f.burn_t = 0.0; f.burn = 0.0; f.burn_by = null
				if float(cool_t[f.id]) <= 0.0: cool_t[f.id] = 1.0; Snd.play("rd_cool", 0.8, f.feet_mid())
		if float(lift_t[f.id]) > 0.0: continue
		if hall and Vector2(f.pos.x - DemonRoad.CORE_AT.x, f.pos.z - DemonRoad.CORE_AT.z).length() < float(LIFT.r) and f.pos.y < 0.6: _lift(f, float(LIFT.hall))
		if pads:
			for p: Vector3 in road.pads:
				if Vector2(f.pos.x - p.x, f.pos.z - p.z).length() < float(LIFT.r) and absf(f.pos.y - p.y) < 0.6: _lift(f, float(LIFT.pad), _pad_aim(f))

func _lift(f: Realm.Fighter, up: float, toward = null) -> void:
	lift_t[f.id] = float(LIFT.cd); Snd.play("rd_lift", 1.0, f.feet_mid())
	var side := Vector3.ZERO   # (toward something: so far across as to be over it at the top of the throw)
	if toward is Vector3:
		var gap := Vector3((toward as Vector3).x - f.pos.x, 0, (toward as Vector3).z - f.pos.z)
		side = gap.normalized() * minf(12.0, gap.length() / (up / 19.0)) if gap.length() > 0.5 else Vector3.ZERO
	if f.me and rm.player != null: rm.player.launch(Vector3(side.x if toward is Vector3 else rm.player.vel.x, up, side.z if toward is Vector3 else rm.player.vel.z))
	else:
		f.vy = up; f.pos.y += 0.06; f.grounded = false
		if toward is Vector3: f.leaping = true; f.vel = side; f.brain.fling = true   # (one of the others: carried across by the throw, as an orc's bound)
	if rm.fx != null:
		for i in 12: rm.fx.glow(f.pos + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6)), Vector3(0, up * 0.5, 0), 0.6, 0.2, 0.03, Color(0.7, 0.3, 1.0, 0.8))

## where an altar's gravity circle throws you: under his sun, at the nearer of his wing cores still whole; else at him
func _pad_aim(f: Realm.Fighter) -> Vector3:
	var best := baal.pos; var bd := INF
	for c: Dictionary in baal.brain.get("cores", []):
		if float(c.hp) > 0.0 and (c.pos as Vector3).distance_to(f.pos) < bd: bd = (c.pos as Vector3).distance_to(f.pos); best = c.pos
	return best

## the corrupted core Karnok leaves on the tower's top: taken, the whole party's ultimates are ready and each has 400 shards
## more, and the rune altar beside it wakes (the last before Baal)
func _core(_dt: float) -> void:
	if core.is_empty() or core_taken: return
	var at: Vector3 = core.pos
	if core.has("node") and is_instance_valid(core.node): (core.node as Node3D).position = at + Vector3(0, 1.2 + sin(clock * 2.0) * 0.15, 0); (core.node as Node3D).rotation.y = clock * 1.4
	for f: Realm.Fighter in party():
		if f.alive and Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < CORE_R and absf(f.pos.y - at.y) < 2.5: _take_core(f); return

func _take_core(by: Realm.Fighter) -> void:
	core_taken = true
	if core.has("node") and is_instance_valid(core.node): (core.node as Node).queue_free()
	for f: Realm.Fighter in party(): f.gauge = float(Races.GAUGE.max); f.shards += int(SHARDS.core)
	shop_ai()
	if rm.look != null: rm.look.burst(ALTAR_B + Vector3(0, 1.0, 0), 3.0, "arcane")
	Snd.play("rd_core", 1.2, ALTAR_B)
	if rm.game != null: rm.game.say_banner("타락한 마력 핵", "%s이(가) 챙겼습니다 · 파티 전원 비기 게이지 100%% · 마력 파편 +%d · 곁의 룬 제단이 깨어났습니다 (B)" % [str(Races.R[by.race].name), int(SHARDS.core)], 3.2)
	rm.note(["core", by.id])

## a section won: whoever of the party stands is whole again, the fire on him out (the comebacks are for the fallen)
func _breather() -> void:
	for f: Realm.Fighter in party():
		if not f.alive: continue
		f.hp = f.max_hp; f.burn_t = 0.0; f.burn = 0.0; f.slows.clear()
		if rm.look != null: rm.look.came_back(f)

## a section's demons all down: its seal lifts (the tower's with Karnok)
func _seals() -> void:
	for s in [1, 2]:
		if cleared.has(s) or left_in(s) > 0: continue
		cleared[s] = true
		if road != null: road.open_seal(s)
		_breather()
		Snd.play("rd_seal", 1.0); rm.duck_t = maxf(rm.duck_t, 1.0); rm.music_break += 1
		if rm.game != null: rm.game.say_banner(str(SECTIONS[s]) + " 제압", "봉인이 풀렸습니다 · 다음: " + str(SECTIONS[s + 1]), 2.6)
		rm.note(["sealed", s])

func _decide() -> void:
	var up := 0; var coming := 0
	for f: Realm.Fighter in party():
		if f.alive: up += 1
		elif f.back_t > 0.0: coming += 1
	if up == 0 and coming == 0: _end("lost")

func _end(how: String) -> void:
	if outcome != "": return
	outcome = how; won = "us" if how == "won" else "them"
	if how == "won":
		rank = rank_now()
		var best := int(Store.save.best.get("r13", 0))
		if int(RANK_N[rank]) > best: Store.save.best["r13"] = int(RANK_N[rank])
	set_phase("over", OVER)
	Snd.play("rm_round_win" if how == "won" else "rm_round_lose")
	if rm.game != null:
		if how == "won": rm.game.say_banner("토벌 성공 · 등급 " + rank, "심연의 대군주 바알이 쓰러졌습니다 · %s · 쓰러짐 %d" % [Store.fmt_time(clock), deaths], 3.4)
		else: rm.game.say_banner("토벌 실패", "파티가 모두 쓰러졌습니다" if eclipse_kill != -2.0 else "종말의 일식이 완성되었습니다", 3.0)
	rm.note(["raid", how, rank])

## the rank, as it stands: S, A, B or C (the paper's Normal)
func rank_now() -> String:
	var ecl_ok := eclipse_t0 < 0.0 or (eclipse_kill >= 0.0 and eclipse_kill <= float(RANK.A.eclipse))
	if clock <= float(RANK.S.t) and deaths <= int(RANK.S.deaths) and parries >= 2 and cores_first: return "S"
	if clock <= float(RANK.A.t) and deaths <= int(RANK.A.deaths) and ecl_ok: return "A"
	if clock <= float(RANK.B.t) and deaths <= int(RANK.B.deaths): return "B"
	return "C"

# ---------------- the lords' moments (Fiends tells) ----------------
func boss_awake(f: Realm.Fighter) -> void:
	boss_up = f; rm.duck_t = maxf(rm.duck_t, 1.6); rm.music_break += 1
	Snd.play("rd_boss", 1.2)
	if rm.game != null: rm.game.say_banner(str(f.name), "탑의 나선 계단을 지키는 사슬 집행관 · 결계 수정이 보호막을 채웁니다" if Fiends.kind_of(f) == "karnok" else "심연의 제단의 주인 · 석주 뒤에 숨고, 냉각진에서 화상을 끄세요", 3.0)
	rm.note(["boss", Fiends.kind_of(f)])

## what a lord's move asks of you, on the screen (the same words not again within six seconds)
func boss_says(f: Realm.Fighter, text: String) -> void:
	if float(_said.get(text, -99.0)) > clock - 6.0: return
	_said[text] = clock
	if rm.game != null: rm.game.say_banner(str(f.name) if f != null else "", text, 2.4)

func boss_phase(_n: int) -> void: rm.duck_t = maxf(rm.duck_t, 1.4); rm.music_break += 1
func karnok_phase2() -> void: rm.duck_t = maxf(rm.duck_t, 1.4); rm.music_break += 1; Snd.play("rd_lift", 0.6, DemonRoad.CORE_AT)
func eclipse_start() -> void: eclipse_t0 = clock; rm.duck_t = maxf(rm.duck_t, 2.0); rm.music_break += 1

## the eclipse completed: the top of the tower is gone, and the party with it
func eclipse_done() -> void:
	eclipse_kill = -2.0; revives = 0
	for f: Realm.Fighter in party():
		if f.alive: f.inv = 0.0; f.phased_t = 0.0; rm.slay(f, baal, {"src": "eclipse"})
		f.back_t = -1.0
	if rm.look != null and baal != null: rm.look.burst(baal.pos + Vector3(0, 2.0, 0), DemonRoad.AR, "fire")
	_end("lost")

func gimmick(what: String) -> void:
	match what:
		"cores_down":
			if baal != null and int(baal.brain.get("suns", 0)) == 1: cores_first = true
	rm.note(["gimmick", what])

func struck(s: Dictionary, who: Realm.Fighter) -> void:
	if who == karnok and karnok != null and s.get("turned", false) and str(s.kind) == "jav":
		parries += 1; Snd.play("rd_parry_hit", 1.0, who.feet_mid())
		if rm.game != null: rm.game.say_feed("카르녹의 투창을 되돌려 맞혔습니다 · 고정 피해 %d · 보호막 -%d (%d번째)" % [int(Fiends.KARNOK.jav_back), int(Fiends.KARNOK.jav_cut), parries])

func bomb_burst(at: Vector3) -> void:
	if fiends != null: fiends.bomb_burst(at)

# ---------------- falling and coming back ----------------
func back_time(f: Realm.Fighter) -> float:
	if Fiends.is_mon(f): return -1.0
	if outcome == "" and revives > 0: revives -= 1; return BACK
	return -1.0
func on_down(v: Realm.Fighter, _by: Realm.Fighter) -> void:
	if Fiends.is_mon(v):
		gone[v.id] = 2.5
		var k := Fiends.kind_of(v)
		var n := int(SHARDS.elite) if k == "beast" else (int(SHARDS.imp) if k == "imp" else int(SHARDS.kill))
		for f: Realm.Fighter in party(): f.shards += n
		if k == "karnok": _karnok_down(v)
		elif k == "baal": _baal_down(v)
		return
	deaths += 1
	if v.me and rm.game != null and v.back_t <= 0.0 and party().any(func(o: Realm.Fighter) -> bool: return o.alive): rm.game.say_feed("부활 기회가 없습니다 · 남은 동료로 교대합니다")
func down_line(f: Realm.Fighter) -> String:
	if f.back_t > 0.0: return "%d초 뒤 %s 거점에서 다시 일어납니다 · 남은 부활 %d · Tab: 동료로 교대" % [ceili(f.back_t), str(SECTIONS[cp]), revives]
	return "부활 기회가 없습니다 · Tab: 남은 동료로 교대"
func back_line() -> String: return str(SECTIONS[cp]) + " 거점"
func base_of(_team: String) -> Vector3: return DemonRoad.CHECK[cp]
func spawn_at(f: Realm.Fighter) -> Vector3:
	var c: Vector3 = DemonRoad.CHECK[cp]; var i := maxi(0, party().find(f))
	var off: Vector3 = [Vector3(0, 0, -1.6), Vector3(0, 0, 1.6), Vector3(-1.8, 0, -0.6), Vector3(-1.8, 0, 0.6)][i % 4]
	var p := c + off
	p.y = Phys.ground_at(p.x, c.y + 1.0, p.z, 0.3)
	return p
func face_at(_f: Realm.Fighter, _p: Vector3) -> float: return -PI / 2.0   # (east, the way on)
func aim_point(_team: String) -> Vector3: return DemonRoad.CHECK[mini(cp + 1, 4)]

func _karnok_down(v: Realm.Fighter) -> void:
	for f: Realm.Fighter in rm.all:   # (the tower's guard breaks with him)
		if f.alive and Fiends.is_mon(f) and int(f.brain.get("sec", -1)) == 3: f.inv = 0.0; rm.slay(f, null, {"src": "lord"})
	cleared[3] = true
	if road != null: road.open_seal(3)
	_breather()
	core = {"pos": ALTAR_B}
	if rm.en != null:
		var n := fiends.gem("anchor", ALTAR_B + Vector3(0, 1.2, 0))
		if n != null:
			for c in n.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).material_override is StandardMaterial3D:
					var m := ((c as MeshInstance3D).material_override as StandardMaterial3D).duplicate() as StandardMaterial3D; m.emission = Color("b04aff"); m.emission_energy_multiplier = 1.2; (c as MeshInstance3D).material_override = m
			core.node = n
		altar_b = _altar_mesh(ALTAR_B + Vector3(1.8, 0, 2.2))
	rm.duck_t = maxf(rm.duck_t, 2.0); rm.music_break += 1; boss_up = null
	Snd.play("rd_boss_down", 1.2, v.feet_mid())
	if rm.game != null: rm.game.say_banner("카르녹 처치", "탑 꼭대기의 문이 열렸습니다 · 꼭대기에 남은 타락한 마력 핵을 챙기세요", 3.0)

func _baal_down(v: Realm.Fighter) -> void:
	if eclipse_t0 >= 0.0: eclipse_kill = clock - eclipse_t0
	cleared[4] = true; boss_up = null
	for f: Realm.Fighter in rm.all:   # (what he called goes with him)
		if f.alive and Fiends.is_mon(f): f.inv = 0.0; rm.slay(f, null, {"src": "lord"})
	if rm.look != null: rm.look.burst(v.pos + Vector3(0, 2.0, 0), 8.0, "fire")
	Snd.play("rd_boss_down", 1.4, v.feet_mid())
	_end("won")

## a stone table with glowing runes (the altar on the tower's top)
func _altar_mesh(at: Vector3) -> Node3D:
	if rm.en == null: return null
	return rm.en._part(fiends._root(), at, "rd_altar_b", [[2.4, 1.0, 1.6, 0, 0.5, 0, "3a3442"], [2.5, 0.08, 1.7, 0, 1.04, 0, "2b2733"], [0.5, 0.04, 0.5, -0.7, 1.1, 0, "6ad8ff"], [0.5, 0.04, 0.5, 0.0, 1.1, 0, "6ad8ff"], [0.5, 0.04, 0.5, 0.7, 1.1, 0, "6ad8ff"]])

func altar_ok() -> bool:
	if phase != "fight" or rm.me == null or not rm.me.alive or road == null: return false
	if rm.me.pos.distance_to(road.altar_at) < ALTAR_R: return true
	return core_taken and rm.me.pos.distance_to(ALTAR_B + Vector3(1.8, 0, 2.2)) < ALTAR_R
func altar_why() -> String: return "룬 제단은 숲속 캠프의 제단 곁에서, 그리고 카르녹을 쓰러뜨린 뒤 탑 꼭대기의 제단 곁에서 열 수 있습니다"

# ---------------- what hurts how much ----------------
func dmg_mul(by: Realm.Fighter, v: Realm.Fighter) -> float:
	var m := 1.0
	if by != null and not Fiends.is_mon(by) and float(bless.get(by.id, 0.0)) > 0.0: m *= float(BLESS.mul)
	if Fiends.is_mon(v) and fiends != null: m *= fiends.dmg_mul(by, v)
	return m
func furnace(f: Realm.Fighter) -> bool: return fiends != null and not Fiends.is_mon(f) and fiends.in_furnace(f)
func heavy(f: Realm.Fighter) -> bool: return Fiends.is_mon(f) and Fiends.kind_of(f) in ["karnok", "baal", "beast"]

# ---------------- the demons are Fiends' ----------------
func turn(f: Realm.Fighter, dt: float) -> void:
	if fiends != null and phase == "fight": fiends.turn(f, dt)
	else: f.vel = Vector3.ZERO
func place(f: Realm.Fighter, dt: float) -> bool:
	if not Fiends.is_mon(f): return false
	if fiends != null: fiends.place(f, dt)
	return true
func fell(f: Realm.Fighter) -> bool:
	if not Fiends.is_mon(f): return false
	if fiends != null: fiends.fell(f)
	return true
func cleanup() -> void:
	if fiends != null: fiends.clear()
	if altar_b != null and is_instance_valid(altar_b): altar_b.queue_free()

# ---------------- where the others go ----------------
func extra_nodes() -> Dictionary: return road.graph_nodes() if road != null else {}
func extra_edges() -> Array: return road.graph_edges() if road != null else []

## what one of ours strikes before anyone: a chain on one of us; the obsidian crystals while Karnok is up on the balcony
## (the elf and the dwarf: arcane and physical); Karnok himself while his axe is up; the wing cores (the elf and the demon)
## and the imps (the dwarf and the orc) while Baal's sun charges; Baal during the eclipse
func focus(f: Realm.Fighter):
	if Fiends.is_mon(f) or phase != "fight": return null
	var eye := f.eye_at()
	for th: Dictionary in rm.kit.things:
		if float(th.hp) <= 0.0 or th.team == f.team: continue
		match str(th.kind):
			"chain":
				if eye.distance_to(th.pos) < 28.0 and rm.kit.sees_thing(f, th, 28.0): return th
			"anchor":
				if (f.race == "elf" or f.race == "dwarf") and eye.distance_to(th.pos) < (40.0 if f.race == "elf" else 14.0) and rm.kit.sees_thing(f, th, 40.0): return th
			"wcore":
				if (f.race == "elf" or f.race == "demon") and rm.kit.sees_thing(f, th, 50.0): return th
	if karnok != null and karnok.alive and str(karnok.brain.get("state", "")) == "hook_wind" and rm.kit.sees(f, karnok, 40.0): return karnok
	if baal != null and baal.alive:
		if str(baal.brain.get("state", "")) == "eclipse" and rm.kit.sees(f, baal, 60.0): return baal
		if baal.brain.has("sun") and (f.race == "dwarf" or f.race == "orc"):
			# thrown up by a gravity circle: the wing core he is passing; on the floor, the imps
			for th: Dictionary in rm.kit.things:
				if str(th.kind) == "wcore" and float(th.hp) > 0.0 and eye.distance_to(th.pos) < 9.0: return th
			var best: Realm.Fighter = null; var bd := INF
			for e: Realm.Fighter in rm.all:
				if e.alive and Fiends.kind_of(e) == "imp" and e.pos.distance_to(f.pos) < bd and rm.kit.sees(f, e, 40.0): bd = e.pos.distance_to(f.pos); best = e
			if best != null: return best
	return null

func jump(f: Realm.Fighter) -> bool: return fiends != null and not Fiends.is_mon(f) and fiends.wave_near(f)
func deadly(p: Vector3) -> bool: return p.x > DemonRoad.CLIFF and Phys.ground_at(p.x, p.y + 0.6, p.z, 0.25) < DemonRoad.LAVA + 2.0

## the nearest spot out of every circle about to burst (the rifts lie close together): along the way away first, then
## turning further from it; on the same floor, not over the edge, not in a wall. None: six metres away
func _clear_of(f: Realm.Fighter, away: Vector3) -> Vector3:
	for d: float in [3.5, 5.5, 7.5, 10.0]:
		for i in 12:
			var turn := ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0) * PI / 6.0
			var p := f.pos + away.rotated(Vector3.UP, turn) * d
			p.y = Phys.ground_at(p.x, f.pos.y + 1.0, p.z, 0.3)
			if absf(p.y - f.pos.y) > 1.2 or deadly(p) or fiends.danger_at(p) != Vector3.INF: continue
			if Phys.collide_at(p.x, p.y + 0.05, p.z, f.R, f.H) != null: continue
			return p
	return f.pos + away * 6.0

func goal(f: Realm.Fighter) -> Dictionary:
	if phase != "fight" or Fiends.is_mon(f) or fiends == null: return {}
	# a circle on the ground about to burst under him: out of it
	var dz := fiends.danger_at(f.pos)
	if dz != Vector3.INF:
		var away := Vector3(f.pos.x - dz.x, 0, f.pos.z - dz.z)
		if away.length() < 0.2: away = Vector3(cos(f.id), 0, sin(f.id))
		return {"at": _clear_of(f, away.normalized()), "near": 0.8, "hurry": true}
	# a sniper's red line on him, about to loose: a quick step aside (along the bridge, never off it)
	for e: Realm.Fighter in rm.all:
		if e.alive and Fiends.kind_of(e) == "sniper" and str(e.brain.get("state", "")) == "aim" and e.brain.get("tgt") == f and float(e.brain.get("st", 0.0)) > 0.8:
			var gap := Vector3(f.pos.x - e.pos.x, 0, f.pos.z - e.pos.z); var side := Vector3(-gap.z, 0, gap.x).normalized() * (1.0 if f.id % 2 == 0 else -1.0)
			return {"at": f.pos + side * 3.0, "near": 0.5, "hurry": true}
	var sec := DemonRoad.section_of(f.pos)
	if sec == 4 and baal != null and baal.alive and baal.brain.get("awake", false): return _at_baal(f)
	if sec == 3 and karnok != null and karnok.alive and karnok.brain.get("awake", false): return _at_karnok(f)
	var foe := _foe_for(f)
	if foe != null:
		if Fiends.kind_of(foe) == "sniper": return {"at": foe.pos, "near": maxf(10.0, float(STAND[f.race]))}   # (up on its pillar over the lava: shot at from the bridge)
		if Fiends.kind_of(foe) == "defender": return {"at": foe.pos, "near": 3.0, "y": true}   # (up the stair: there, at its height)
		return {"at": foe.pos, "near": float(STAND[f.race])}
	var lead := leader()
	if lead == null or lead == f or rm.auto and f.me: return _ahead(f)
	# with the leader, a little behind him, each at his own place
	var i := party().find(f); var a := PI + (i - 1.5) * 0.7
	var p := lead.pos + Vector3(cos(a) * 3.2, 0, sin(a) * 3.2)
	if lead.pos.distance_to(f.pos) < 5.0: return {}
	return {"at": p, "near": 2.2, "y": true, "hurry": lead.pos.distance_to(f.pos) > 10.0}

## the nearest demon still up where the party is (awake, or in a section the party has come into)
func _foe_for(f: Realm.Fighter) -> Realm.Fighter:
	var lead := leader(); var here := maxi(DemonRoad.section_of(f.pos), DemonRoad.section_of(lead.pos) if lead != null else 0)
	var best: Realm.Fighter = null; var bd := INF
	for e: Realm.Fighter in rm.all:
		if not e.alive or not Fiends.is_mon(e) or e == karnok or e == baal: continue
		var s := int(e.brain.get("sec", -1))
		if s != here and not (e.brain.get("awake", false) and s <= here): continue
		var d := e.pos.distance_to(f.pos)
		if d < bd: bd = d; best = e
	return best

## the way on, for whoever leads by himself (your fighter playing itself): the next section's checkpoint once this one is done
func _ahead(f: Realm.Fighter) -> Dictionary:
	var s := DemonRoad.section_of(f.pos)
	if not core.is_empty() and not core_taken: return {"at": core.pos, "near": 0.8, "y": true, "hurry": true}   # (the corrupted core first)
	if s == 0 or cleared.has(s): return {"at": DemonRoad.CHECK[mini(s + 1, 4)] + Vector3(4.0, 0, 0), "near": 2.5, "y": true, "hurry": true}
	if s == 3: return {"at": DemonRoad.stair_point(DemonRoad.SPIRAL - 4.0, 13.0), "near": 2.0, "y": true, "hurry": true}
	if s == 4: return {"at": DemonRoad.altar_point(180.0, 14.0), "near": 2.5, "y": true, "hurry": true}   # (down onto the altar: Baal wakes)
	return {}

## up against Karnok: on the balcony (his first phase) the close fighters go up the stair and round the top to him, the
## others climb high on the far side of the well and shoot across it; on the stair (his second) the close ones at him, the
## others some way off along the steps
func _at_karnok(f: Realm.Fighter) -> Dictionary:
	var kb := karnok.brain; var close := f.race == "orc" or f.race == "dwarf"
	if int(kb.get("phase", 1)) == 1:
		if close:   # (up the stair and round the top floor to him)
			var a := atan2(karnok.pos.z - DemonRoad.TC.y, karnok.pos.x - DemonRoad.TC.x) + (0.12 if party().find(f) % 2 == 0 else -0.12)
			return {"at": Vector3(DemonRoad.TC.x + cos(a) * 11.8, DemonRoad.T_TOP, DemonRoad.TC.y + sin(a) * 11.8), "near": 1.2, "y": true, "hurry": true}
		# (across the well from him, on the stair's first turn, where nothing is overhead: he is seen, and so are the crystals)
		var across := fposmod(rad_to_deg(atan2(karnok.pos.z - DemonRoad.TC.y, karnok.pos.x - DemonRoad.TC.x)) + 180.0 - DemonRoad.ST_A0, 360.0)
		var u := clampf(across + (12.0 if party().find(f) % 2 == 0 else -12.0), 10.0, 330.0)
		return {"at": DemonRoad.stair_point(u, 13.0), "near": 2.5, "stay": true, "y": true, "hurry": true}
	var spin := str(kb.get("state", "")) == "spin"
	var on := DemonRoad.on_stair(karnok.pos)
	if close and not spin: return {"at": karnok.pos, "near": 1.8, "y": true}
	if on.is_empty(): return {"at": karnok.pos, "near": 9.0}
	var side := -1.0 if party().find(f) % 2 == 0 else 1.0
	var u2 := clampf(float(on[0]) + side * (70.0 if f.race == "elf" else 52.0), 4.0, DemonRoad.SPIRAL - 4.0)
	var spot := DemonRoad.stair_point(u2, 13.0)
	return {"at": spot, "near": 2.5, "hurry": spin or spot.distance_to(f.pos) > 6.0, "y": true}

## up against Baal: the close fighters at him (not inside his furnace once he burns), the others round the ring each at
## his own angle; behind a pillar from the meteors and the drain; to a cooling circle when burning hard
func _at_baal(f: Realm.Fighter) -> Dictionary:
	var bb := baal.brain; var ph := int(bb.get("phase", 1)); var close := f.race == "orc" or f.race == "dwarf"
	var c := Vector3(DemonRoad.AC.x, DemonRoad.A_Y, DemonRoad.AC.y)
	var dr: Dictionary = bb.get("drain", {})
	if (bb.has("shower") or (not dr.is_empty() and dr.v == f)) and ph == 2:
		var hide := _behind_pillar(f)
		if hide != Vector3.INF: return {"at": hide, "near": 0.7, "hurry": true}
	if f.burn_t > 2.0 and f.burn > 6.0:
		var cool := Vector3.INF
		for q: Vector3 in road.cools:
			if q.distance_to(f.pos) < 14.0 and (cool == Vector3.INF or q.distance_to(f.pos) < cool.distance_to(f.pos)): cool = q
		if cool != Vector3.INF: return {"at": cool, "near": 0.9, "hurry": true}
	if str(bb.get("state", "")) == "eclipse": return {"at": baal.pos, "near": 2.5 if close else 8.0}
	# his sun charging: the dwarf and the orc onto the nearer gravity circle, that throws them up at his wing cores
	if close and bb.has("sun") and ph == 2 and not road.pads.is_empty():
		var pad: Vector3 = road.pads[0]
		for q: Vector3 in road.pads:
			if q.distance_to(f.pos) < pad.distance_to(f.pos): pad = q
		return {"at": pad, "near": 0.6, "hurry": true}
	if close and ph != 2: return {"at": baal.pos, "near": float(Fiends.BAAL.aura_r) + 0.5 if (ph == 3 and f.hp < f.max_hp * 0.4) else 2.4}
	var i := party().find(f); var a := deg_to_rad(150.0 + i * 55.0)
	var r := (DemonRoad.AR_SMALL - 4.0) if road.rim_down else 15.0
	return {"at": c + Vector3(cos(a) * r, 0, sin(a) * r), "near": 2.0}

## the place behind the nearest pillar still standing, away from Baal
func _behind_pillar(f: Realm.Fighter) -> Vector3:
	var best := Vector3.INF
	for p: Dictionary in road.pillars:
		if not p.up: continue
		var at: Vector3 = p.at; var away := Vector3(at.x - baal.pos.x, 0, at.z - baal.pos.z).normalized()
		var spot := at + away * 2.2; spot.y = DemonRoad.A_Y
		if best == Vector3.INF or spot.distance_to(f.pos) < best.distance_to(f.pos): best = spot
	return best

# ---------------- the screens ----------------
func hud() -> Dictionary:
	var ps: Array = []
	for f: Realm.Fighter in party():
		ps.push_back({"race": f.race, "q": clampf(f.hp / f.max_hp, 0.0, 1.0), "sh": f.shield, "alive": f.alive, "back": f.back_t, "me": f.me, "ult": f.gauge >= float(Races.GAUGE.max), "bless": float(bless.get(f.id, 0.0)) > 0.0})
	var out := {"title": "타락한 마탑 토벌전 · " + str(SECTIONS[cp]), "party": ps, "revives": revives, "clock": clock, "roster": false, "deaths": deaths}
	var B := boss_up
	if B != null and B.alive:
		var T: Dictionary = Fiends.KINDS[Fiends.kind_of(B)]
		out.boss = {"name": str(B.name), "q": clampf(B.hp / B.max_hp, 0.0, 1.0), "sh": clampf(B.shield / maxf(1.0, float(T.get("shield", 1.0))), 0.0, 1.0), "phase": int(B.brain.get("phase", 1)), "phases": 2 if Fiends.kind_of(B) == "karnok" else 3,
			"stagger": float(B.brain.get("stagger", 0.0)) > 0.0 or float(B.brain.get("crash", 0.0)) > 0.0}
		if str(B.brain.get("state", "")) == "eclipse": out.eclipse = float(B.brain.get("cast", 0.0))
	out.sub = _aim_line()
	if outcome == "won": out.sub = "토벌 성공 · 등급 " + rank
	elif outcome == "lost": out.sub = "토벌 실패"
	return out

func _aim_line() -> String:
	if karnok != null and karnok.alive and karnok.brain.get("awake", false):
		var a := 0
		for th: Dictionary in rm.kit.things:
			if th.kind == "anchor" and float(th.hp) > 0.0: a += 1
		if int(karnok.brain.get("phase", 1)) == 1 and a > 0: return "결계 수정 %d개가 보호막을 채웁니다 · 비전·물리로 부수기" % a
		if str(karnok.brain.get("state", "")) == "hook_wind": return "처형 직전 · 가슴의 붉은 코어를 쏘거나 폭탄을!"
		return "투창은 F로 튕겨내기 · 화염 파동은 점프나 석조 장식 위로"
	if not core.is_empty() and not core_taken: return "탑 꼭대기의 타락한 마력 핵을 챙기세요"
	if baal != null and baal.alive and baal.brain.get("awake", false):
		match int(baal.brain.get("phase", 1)):
			1: return "화염은 석주 뒤로 · 사슬은 4초 안에 · 화상은 냉각진"
			2: return "보라색 날개 코어를 부수면 추락 · 중력진으로 위로" if baal.brain.has("sun") else "유성우는 석주 뒤로 · 흡수 광선은 시야를 끊기"
			3: return "세 번째 검기는 점프 · 화로 안에선 치유 절반"
	var s := cp
	if s < 4 and (s == 0 or cleared.has(s)): return AIMS[0] if s == 0 else "봉인이 풀렸습니다 · 다음: " + str(SECTIONS[s + 1])
	var n := left_in(s)
	return str(AIMS[s]) + (" · 남은 악마 %d" % n if n > 0 else "")

func brief_line() -> String: return "4종족 파티로 마탑을 올라 심연의 대군주 바알을 쓰러뜨리세요 · " + str(Races.R[Realm.picked_race()].name) + "로 시작"
func brief() -> Array:
	return ["엘프·드워프·오크·악마 넷이 한 파티 · 나는 그중 하나를 맡고 나머지 셋은 인공지능이 싸웁니다 · Tab(또는 1~4, 터치 '교대')으로 언제든 다른 동료로 시점이 바뀝니다",
		"① 숲속 캠프(룬 제단·축복의 마법진·보급 상자) → ② 무너진 외성문 → ③ 용암 사슬 다리 → ④ 탑 나선 계단의 카르녹 → ⑤ 심연의 제단의 바알",
		"구간의 마법 결계는 그 구간의 악마를 모두 쓰러뜨려야 풀리고, 그때 살아 있는 동료는 체력이 모두 찹니다 · 용암에 떨어지면 즉사",
		"파티 공유 부활 %d회: 쓰러지면 %d초 뒤 마지막 거점에서 다시 일어납니다 · 넷이 모두 쓰러지면 실패" % [REVIVES, int(BACK)],
		"카르녹: 투창 튕겨내기(F) · 나선 화염 파동은 점프 · 결계 수정 · 2페이즈 처형 갈고리는 코어 집중 사격이나 폭탄으로 끊기",
		"바알: 석주 뒤 엄폐 · 혈약 사슬 4초 안에 끊기 · 냉각진 · 날개 코어 · 종말의 일식은 12초 안에 처치 (폭탄이 영창을 늦춤)",
		"등급 S: 12분 안·쓰러짐 2번 이하·투창 2번 되돌리기·첫 태양 때 코어 파괴 · A: 16분·5번·일식 8초 안 · B: 20분·9번"]
func win_title() -> String: return "타락한 마탑 토벌 · 등급 " + (rank if rank != "" else "C")
func pause_line() -> String: return "타락한 마탑 토벌전 · %s · 남은 부활 %d · 쓰러짐 %d" % [str(SECTIONS[cp]), revives, deaths]
func record_key() -> String: return "t13"
func bonus() -> int: return 150000 * Store.PAY
static func best_rank() -> String:
	var n := int(Store.save.best.get("r13", 0))
	for k: String in RANK_N:
		if int(RANK_N[k]) == n: return k
	return ""

## the tactical map: the checkpoints, the seals still up, the lords
func tac() -> Array:
	var out: Array = []
	for i in DemonRoad.CHECK.size():
		var c: Vector3 = DemonRoad.CHECK[i]
		out.push_back({"x": c.x, "z": c.z, "c": "5f9cff" if i == cp else ("8d949c" if i < cp else "c9a85a"), "r": 2.0, "label": str(SECTIONS[i])})
	if karnok != null and karnok.alive: out.push_back({"x": karnok.pos.x, "z": karnok.pos.z, "c": "ff5260", "r": 2.6, "label": "카르녹"})
	if baal != null and baal.alive: out.push_back({"x": baal.pos.x, "z": baal.pos.z, "c": "ff5260", "r": 3.2, "label": "바알"})
	return out

## over the view: the crystals, the chains, the cores, the corrupted core, the camp's three things, the way on
func marks() -> Array:
	var out: Array = []
	if phase != "fight": return out
	for th: Dictionary in rm.kit.things:
		if float(th.hp) <= 0.0: continue
		match str(th.kind):
			"anchor": out.push_back({"at": (th.pos as Vector3) + Vector3(0, 2.2, 0), "c": "ff5a6a", "label": "결계 수정"})
			"chain": out.push_back({"at": (th.pos as Vector3) + Vector3(0, 1.8, 0), "c": "ff5a6a", "label": "사슬"})
			"wcore": out.push_back({"at": (th.pos as Vector3) + Vector3(0, 1.6, 0), "c": "c08aff", "label": "코어"})
	if not core.is_empty() and not core_taken: out.push_back({"at": (core.pos as Vector3) + Vector3(0, 2.6, 0), "c": "c08aff", "label": "마력 핵"})
	if road != null and cp == 0 and rm.me != null and rm.me.pos.x < -128.0:
		out.push_back({"at": road.altar_at + Vector3(0, 2.0, 0), "c": "8ff7ea", "label": "룬 제단"})
		out.push_back({"at": road.bless_at + Vector3(0, 1.5, 0), "c": "8ff7ea", "label": "축복진"})
		for c: Vector3 in road.crates: out.push_back({"at": c + Vector3(0, 1.6, 0), "c": "ffd66b", "label": "보급"})
	if cp < 4 and (cp == 0 or cleared.has(cp)) and rm.me != null and DemonRoad.section_of(rm.me.pos) == cp:
		out.push_back({"at": (DemonRoad.CHECK[cp + 1] as Vector3) + Vector3(0, 2.5, 0), "c": "ffd66b", "label": "다음: " + str(SECTIONS[cp + 1])})
	return out

## the music: the wood's set on the road, the tower's against a lord; how far it has come by the section and the phase
func music_set() -> String: return "rt" if boss_up != null and boss_up.alive else "rf"
func music_stage() -> int:
	if phase != "fight": return 1
	if boss_up != null and boss_up.alive: return clampi(int(boss_up.brain.get("phase", 1)) + 1, 2, 4)
	return clampi(cp, 1, 3)
func state() -> Dictionary:
	return {"phase": phase, "cp": cp, "revives": revives, "deaths": deaths, "clock": clock, "cleared": cleared.keys(), "outcome": outcome, "rank": rank,
		"karnok": karnok.hp if karnok != null and karnok.alive else 0.0, "baal": baal.hp if baal != null and baal.alive else 0.0, "parries": parries, "cores_first": cores_first, "demons": demons().filter(func(f): return f.alive).size()}
## the result sheet's "N 대 M": the demons the party felled, the party's falls
func score(team: String) -> int:
	if team == "us":
		var n := 0
		for f: Realm.Fighter in party(): n += f.kills
		return n
	return deaths
