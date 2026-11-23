class_name Game
extends RefCounted
## One run of a stage: who stands where, what a kill pays, the boss's chest, clearing and falling. Ported from Game in src/08b_game.js.

const STAGES := {
	1: {"name": "컨테이너 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "밀수 조직원 100명 · 총소리를 들으면 몰려옵니다"},
	6: {"name": "헬멧 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "오토바이 헬멧 쓴 조직원 100명 · 헬멧은 머리를 한 번 맞히면 벗겨집니다"},
	5: {"name": "무장 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "단검 20 · 파란 광선검 10 · 쌍광선검 5 · 야구방망이 15 · 자폭맨 10 · 저격 5 · 보스는 기관총"},
	2: {"name": "불타는 마을", "enemy": "zombie", "goal": 100, "unit": "마리", "label": "좀비", "intro": "좀비 100마리 · 체력은 없고 감염과 중독뿐 · 해독약은 오두막 안의 나무 상자에서 · 좀비는 총소리를 멀리서도 듣습니다"},
	3: {"name": "동물 연구소", "enemy": "animal", "goal": 84, "unit": "마리", "label": "동물", "intro": "우리 10개 · 10초 뒤 첫 우리가 열리고 15초마다 하나씩 · 얼룩말 → 기린 → 코끼리 순서로 올라탈 수 있음 · 보스 고릴라는 방탄유리 우리에"},
	7: {"name": "사파리 감시탑", "enemy": "animal", "goal": 93, "unit": "마리", "label": "동물", "intro": "넓은 사파리의 동물 93마리 · 5분 뒤 모두 가운데 감시탑으로 습격 · 탑 체력 10,000 · 기린은 긴 목으로 탑 위까지 칩니다"},
	8: {"name": "차례 연구소", "enemy": "animal", "goal": 84, "unit": "마리", "label": "동물", "intro": "우리 10개를 하나씩 · 앞 우리의 동물을 다 잡아야 원숭이 박사가 다음 우리를 엽니다 · 모든 우리가 방탄유리 · 마지막은 거대 고릴라"},
	9: {"name": "장난감 방", "enemy": "toy", "goal": 100, "unit": "개", "label": "장난감", "intro": "아이 방 전체가 싸움터 · 침대, 책상, 블록 다리, 책장 꼭대기 · 플라스틱 군인 30, 액션 피규어 22, 태엽·RC 유닛 24, 조립 블록 피규어 24"},
	4: {"name": "우주선", "enemy": "robot", "goal": 100, "unit": "대", "label": "로봇", "intro": "에어록 → 통로 → 160 m 복도의 드론 떼 · 서쪽 2층 운전실에 황금 꿀벌 드론 · 동쪽 넓은 메인홀에 3페이즈 보스 드론 · 보스 드론을 잡으면 끝 · 바닥의 스파이더 마인 조심"},
}
const BOSS := {
	1: {"type": "thug", "name": "조직 두목", "josa": "이", "scale": 1.35, "hp": 1600, "dmgMul": 1.6},
	6: {"type": "thug", "name": "헬멧 두목", "josa": "이", "scale": 1.35, "hp": 1600, "dmgMul": 1.6, "helmet": true},
	2: {"type": "zombie", "name": "거대 좀비", "josa": "가", "scale": 1.7, "hp": 2200, "dmgMul": 1.0},
	3: {"type": "gorilla", "name": "거대 로랜드고릴라", "josa": "가", "scale": 3.0, "hp": 5200, "dmgMul": 1.0, "kong": true},
	8: {"type": "gorilla", "name": "거대 로랜드고릴라", "josa": "가", "scale": 3.0, "hp": 5200, "dmgMul": 1.0, "kong": true},
	4: {"type": "bdrone", "name": "최첨단 감시 드론 B-3", "josa": "이", "scale": 1.0, "hp": 9000, "dmgMul": 1.0},
	5: {"type": "thug", "name": "무장 두목", "josa": "이", "scale": 1.4, "hp": 2600, "dmgMul": 1.0, "kit": "lmg"},
}

var world: World; var player: Player; var enemies: Enemies; var guns: Guns; var proj: Proj; var loot: Loot; var fx: Fx
var banner: Callable = Callable(); var feed: Callable = Callable(); var on_result: Callable = Callable()   # on_result(kind) shows the result sheet
var stage := 1
var goal := 100
var kills := 0
var ended := false
var result := ""
var replay := false
var boss: Enemies.Foe = null
var boss_msg := ""
var stats := {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "earned": 0, "time": 0.0}
var bonus_guns: Array = []
var _result_t := -1.0
var _result_kind := ""
var _chest_wait := false
var flow_t := 0.0
var mid: Enemies.Foe = null   # the gold commander drone
var sp = null                 # stage 4's save point
var deployed := false         # out of the briefing into the stage (or back at the save point): rented guns go back only then
var spawned := 0
var clock := 0.0
var calm := 0   # animals you have ridden: tamed, and counted as dealt with
# stage 2: a bite infects (5 s), a dash poisons (8 s); an antidote, a moment to inject, clears both
var infected := false
var infect_t := 0.0
var poison_t := 0.0
var antidotes := 0
var inject_on := false
var inject_t := 0.0
var _inject_cured := false
var _inject_snd := false
const INJECT_DUR := 1.35
const CURE_AT := 0.82
var hint: Callable = Callable()
var on_flash: Callable = Callable()   # (amount, from): the red flash and the direction of a bite
var on_pay: Callable = Callable()     # (money): it pops out under the box at the top
var tm: ToyMatch = null               # stage 5's team modes (battery rush, train escort, bedtime): the two sides and the rules

func _say(c: Callable, a: Array) -> void:
	if c.is_valid(): c.callv(a)
func say_banner(title: String, sub: String, sec: float) -> void: _say(banner, [title, sub, sec])
func say_feed(text: String) -> void: _say(feed, [text, 0])
func say_hint(text: String, sec: float) -> void: _say(hint, [text, sec])

func layout() -> Array:
	if stage == 9: return (Store.save.toy_order as Array).duplicate()   # every toy gun in hand (keys 1-9), in the order you put them
	return (Store.save.loadout as Array).map(func(id): return id if (id != null and Store.gun_available(id, bonus_guns)) else null)

func begin(stage_: int) -> void:
	stage = stage_
	var an := enemies.animals; an.player = player; an.game = self; an.world = world; an.fx = fx; player.rider = an; player.on_toss_land = an.toss_land
	var tf := enemies.toys; tf.player = player; tf.game = self; tf.world = world; tf.fx = fx; tf.proj = proj
	var rb := enemies.robots; rb.player = player; rb.game = self; rb.world = world; rb.fx = fx; rb.proj = proj
	if tm != null: tm.clear()
	tm = null
	enemies.clear(); proj.clear(); loot.clear(); fx.clear()
	if stage == 9 and ToyMatch.picked() != "sweep":   # a team mode in the toy room: its things are built with the room
		tm = ToyMatch.create(ToyMatch.picked()); tm.game = self; tm.world = world; tm.en = enemies; tm.toys = tf; tm.player = player; tm.guns = guns; tm.proj = proj; tm.fx = fx
	world.toy_tm = tm; tf.tm = tm; proj.tm = tm; enemies.vis_r = 160.0 if tm != null else 0.0
	world.build_stage(stage); calm = 0; sp = null; mid = null
	if tm != null: tm.room = world.toy
	if world.ship != null: world.ship.player = player; world.ship.game = self; world.ship.enemies = enemies; world.ship.fx = fx
	player.toss_ceil = Lab.CEIL if world.lab != null else INF
	if world.lab != null: world.lab.player = player; world.lab.game = self
	if world.safari != null: world.safari.player = player; world.safari.game = self; world.safari.enemies = enemies; world.safari.fx = fx
	bonus_guns = []; replay = Store.save.best.has(tm.mode.record_key()) if tm != null else Store.save.cleared.has(stage)   # (a team mode: once won, it pays no more)
	guns.reset(layout()); guns.stage = stage; enemies.stage = stage; enemies.down_hint = false; proj.stage = stage; guns.toy = stage == 9
	stats = {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "earned": 0, "time": 0.0}
	Store.money_lock = Store.save.money; Store.ivory_lock = Store.save.items.ivory; Store.own_lock = (Store.save.owned as Array).duplicate()
	player.reset(world.start.x, world.start.z, world.start.yaw); player.invuln = 1.5
	if stage == 9: player.pos.y = 42.0; player.grounded = false; player.chute = true   # you come down into the room under a parachute
	infected = false; infect_t = 0.0; poison_t = 0.0; antidotes = 1 if stage == 2 else 0; inject_on = false; inject_t = 0.0; player.stun_t = 0.0; player.no_hp = stage == 2
	kills = 0; ended = false; result = ""; _result_t = -1.0; _chest_wait = false; deployed = false
	# 1-2 crowds the middle of the docks: its enemies stand where they stand for a drop at the south edge, and you always come
	# down in the corner at the bottom left of the map (the west and south ends), facing in
	if stage == 5:
		var d = open_spot(0.0, 58.0)
		if d != null: world.start = d; player.reset(d.x, d.z, d.yaw); player.invuln = 1.5
	populate()
	if world.village != null: world.village.drop_ghosts()   # (stage 2: the crates out in the village only kept the zombies where the browser game puts them)
	if stage == 5:
		var c = open_spot(-(Phys.HALF - 6.0), Phys.HALF - 6.0)
		if c != null: set_drop(c)
	var B: Dictionary = BOSS.get(stage, {})
	boss_msg = ("보스 " + B.name + B.josa + (" 10번 우리에 있습니다" if world.lab != null else " 어딘가에 있습니다") + (" · 다시 하기라 보상은 없습니다" if replay else " · " + Store.won(boss_pay(B)))) if not B.is_empty() else ""
	if tm != null: boss_msg = tm.mode.brief_line() + (" · 다시 하기라 보상은 없습니다" if replay else "")
	Phys.update_flow(player.pos.x, player.pos.z); flow_t = 0.3

## what the stage's boss pays: twenty times one of its kind (a man, a zombie: 1,000), and then twice that, as all pay here
static func boss_pay(B: Dictionary) -> int:
	var t: String = B.type; var base := 1000
	if Animals.ANIMALS.has(t): base = int(Animals.ANIMALS[t].money)
	elif Robots.ROBOTS.has(t): base = int(Robots.ROBOTS[t].get("money", 1000))
	return base * 20 * Store.PAY

## the nearest open ground to a point on the map: room to land, not on a container, inside the fence; you face the middle of the docks
func open_spot(x: float, z: float):
	var rr := 0.0
	while rr <= 9.0:
		var n := maxi(8, roundi(rr * 6.0)) if rr > 0.0 else 1
		for i in n:
			var a := (float(i) / n) * TAU; var px := x + cos(a) * rr; var pz := z + sin(a) * rr
			if absf(px) > Phys.HALF - 4 or absf(pz) > Phys.HALF - 4 or Phys.collide_at(px, 0.05, pz, 1.1, 2) != null or Phys.ground_at(px, 0.3, pz, 0.5) > 0.1: continue
			return {"x": px, "z": pz, "yaw": atan2(px, pz) if Vector2(px, pz).length() > 3.0 else 0.0}
		rr += 0.5
	return null

func set_drop(d: Dictionary) -> void:
	world.start = {"x": d.x, "z": d.z, "yaw": d.yaw}; player.pos = Vector3(d.x, 0, d.z); player.yaw = d.yaw; player.pitch = 0.0; Phys.update_flow(d.x, d.z)

## the same stage always puts the same enemies in the same places
func populate() -> void:
	enemies.helmet_hint = false
	var SR := World.Rng.new(5150 + stage * 101); var st := world.start; var placed: Array = []; var half := Phys.HALF
	var ok := func(x: float, z: float, min_start: float, gap: float, rad: float) -> bool:
		if absf(x) > half - 4 or absf(z) > half - 4 or Vector2(x - st.x, z - st.z).length() < min_start or Phys.collide_at(x, 0, z, rad, 2) != null: return false
		for p in placed:
			if Vector2(p.x - x, p.z - z).length() < gap: return false
		return true
	var find := func(min_start: float, gap: float, rad: float, near = null, spread := 0.0):
		for k in 300:
			var x: float = near.x + SR.rng(-spread, spread) if near != null else SR.rng(-half + 6, half - 6)
			var z: float = near.z + SR.rng(-spread, spread) if near != null else SR.rng(-half + 6, half - 6)
			if ok.call(x, z, min_start, gap, rad): var p := {"x": x, "z": z}; placed.push_back(p); return p
		return null
	var n := [0]; var cap := 140 if world.lab != null else 100
	var put := func(type: String, p, opts: Dictionary):
		if p != null and n[0] < cap:
			var o := {"yaw": SR.rng(0, TAU), "y": p.get("y", 0.0)}; o.merge(opts, true)
			var e := enemies.spawn(type, p.x, p.z, o); e.sid = n[0]; n[0] += 1; return e
		return null
	if world.lab != null or world.safari != null or world.ship != null or world.toy != null:
		if world.lab != null: world.lab.populate(put, SR, BOSS[stage])
		elif world.ship != null: world.ship.populate(put, SR, BOSS[stage])
		elif world.toy != null and tm != null: tm.mode.populate()   # (a team mode: the two sides, not the hundred toys)
		elif world.toy != null: enemies.toys.populate(put, SR)
		else:
			world.safari.populate(put, find, SR)
			for e in enemies.list:
				e.wild = true
				if e.type == "zebra": e.fury = true; enemies.animals.wake(e); e.bs = "graze"; e.bt = SR.rng(0.5, 4)   # zebras just live their quiet life, and never bolt here
		goal = enemies.list.size() if tm == null else 0; boss = null; spawned = n[0]
		for e in enemies.list:
			if e.boss: boss = e
			if e.T.get("mid", false): mid = e
		return
	var B: Dictionary = BOSS.get(stage, {})
	if stage == 5: _populate_armed(SR, ok, find, put, placed, n)
	elif not B.is_empty():
		var bp = find.call(55.0, 8.0, 2.5)
		if bp == null: bp = find.call(30.0, 4.0, 1.5)
		var bo := B.duplicate(); bo.boss = true; put.call(B.type, bp, bo)
	# guard posts of 2-4 people, or packs of 2-6 zombies
	var helmet := stage == 6; var yard := stage != 2; var kind: String = STAGES[stage].enemy
	while n[0] < 100 and stage != 5:
		var center = find.call(36.0 if yard else 22.0, 5.0, 0.8)
		if center == null: break
		put.call(kind, center, {"helmet": helmet})
		var grp := int(floor(SR.rng(2, 5))) if yard else int(floor(SR.rng(2, 7)))
		for i in range(1, grp): put.call(kind, find.call(33.0 if yard else 20.0, 1.6, 0.6, center, 5.0), {"helmet": helmet})
	while n[0] < 100 and stage != 5:   # anyone still missing goes wherever there is room
		var p = find.call(18.0, 1.2, 0.6)
		if p == null: break
		put.call(kind, p, {"helmet": helmet})
	goal = enemies.list.size(); boss = null
	for e in enemies.list:
		if e.boss: boss = e

## 1-2: 5 snipers up on container stacks, 9 gold desert eagles, 10 suicide bombers, 3 flamethrowers, 12 rifles, 20 knives, 10 blue lightsabers,
## 5 with a lightsaber in each hand, 10 grenade throwers, 15 aluminium bats, and the boss with a machine gun: 100 in all.
## 70 of them, the boss among them, are packed into the middle nine blocks; the other 30 are spread round the outside
func _populate_armed(SR: World.Rng, ok: Callable, find: Callable, put: Callable, placed: Array, n: Array) -> void:
	var half := Phys.HALF; var B: Dictionary = BOSS[5]
	var inside := func(x: float, z: float) -> bool: return absf(x) < 36.0 and absf(z) < 33.0
	var find_r := func(want_in: bool, min_start: float, gap: float, rad: float, near = null, spread := 0.0):
		for k in 400:
			var x: float = near.x + SR.rng(-spread, spread) if near != null else (SR.rng(-35, 35) if want_in else SR.rng(-half + 6, half - 6))
			var z: float = near.z + SR.rng(-spread, spread) if near != null else (SR.rng(-32, 32) if want_in else SR.rng(-half + 6, half - 6))
			if inside.call(x, z) != want_in or not ok.call(x, z, min_start, gap, rad): continue
			var p := {"x": x, "z": z}; placed.push_back(p); return p
		return null
	var inner := [0]
	var put_n := func(p, opts: Dictionary) -> bool:   # returns whether someone was placed
		var before: int = n[0]; put.call("thug", p, opts); return n[0] > before
	var bp = find_r.call(true, 20.0, 8.0, 2.5)
	if bp == null: bp = find.call(30.0, 4.0, 1.5)
	var bo := B.duplicate(); bo.boss = true
	if put_n.call(bp, bo): inner[0] += 1
	var kits := []
	for r in [["sniper", 5], ["deagle", 9], ["bomber", 10], ["flame", 3], ["rifle", 12], ["dagger", 20], ["saber", 10], ["saber2", 5], ["nade", 10], ["bat", 15]]:
		for i in r[1]: kits.push_back(r[0])
	for i in range(kits.size() - 1, 0, -1): var j := int(floor(SR.next() * (i + 1))); var t = kits[i]; kits[i] = kits[j]; kits[j] = t
	# the snipers on stacks in the middle, looking out over the rest
	var tops: Array = Phys.colliders.filter(func(b): return b.kind == "metal" and b.maxy > 2 and b.maxy < 9 and (b.maxx - b.minx) * (b.maxz - b.minz) > 10 and inside.call((b.minx + b.maxx) / 2, (b.minz + b.maxz) / 2))
	var snipers: int = kits.count("sniper"); var left: Array = kits.filter(func(k): return k != "sniper")
	for i in snipers:
		var spot = null; var k := 0
		while k < 40 and not tops.is_empty() and spot == null:
			k += 1; var b: Phys.Box = tops.pop_at(int(floor(SR.next() * tops.size()))); var q := {"x": (b.minx + b.maxx) / 2, "z": (b.minz + b.maxz) / 2, "y": b.maxy}
			if placed.all(func(o): return Vector2(o.x - q.x, o.z - q.z).length() > 6.0): spot = q
		if spot != null:
			placed.push_back(spot)
			if put_n.call(spot, {"kit": "sniper", "y": spot.y}): inner[0] += 1
		else: left.push_back("sniper")
	# posts of 2-5 in the middle until it holds 70, then posts of 2-3 outside for the rest
	var guard := 0
	while inner[0] < 70 and not left.is_empty() and guard < 200:
		guard += 1; var center = find_r.call(true, 20.0, 4.5, 0.8)
		if center == null: break
		if put_n.call(center, {"kit": left.pop_front()}): inner[0] += 1
		var grp := int(floor(SR.rng(2, 6)))
		for i in range(1, grp):
			if left.is_empty() or inner[0] >= 70: break
			if put_n.call(find_r.call(true, 18.0, 1.6, 0.6, center, 5.0), {"kit": left[0]}): left.pop_front(); inner[0] += 1
	guard = 0
	while n[0] < 100 and not left.is_empty() and guard < 200:
		guard += 1; var center = find_r.call(false, 26.0, 5.0, 0.8)
		if center == null: break
		put.call("thug", center, {"kit": left.pop_front()})
		var grp := int(floor(SR.rng(2, 4)))
		for i in range(1, grp):
			if left.is_empty(): break
			if put_n.call(find_r.call(false, 24.0, 1.6, 0.6, center, 5.0), {"kit": left[0]}): left.pop_front()

func update(dt: float) -> void:
	if not ended: stats.time += dt
	# the enemies' way to you, every 0.3 s as the browser game's: at most 3 ms of the search a frame (a fast computer does it
	# all at once, as there; a slow one over a few frames, the enemies keeping the last way meanwhile), the next once it is done
	flow_t -= dt
	if flow_t <= 0.0 and not Phys.flow_busy: flow_t = 0.3; Phys.flow_start(player.pos.x, player.pos.z)
	if Phys.flow_busy: Phys.flow_step(3000)
	stats.shots = guns.shots; stats.hits = guns.hits
	if _chest_wait and loot.pending() == null: _chest_wait = false; finish()
	if _result_t > 0.0:
		_result_t -= dt
		if _result_t <= 0.0: _say(on_result, [_result_kind])
	if not ended and player.hp <= 0.0:
		if tm != null: tm.player_down()   # (a team mode: you are back at your base in a few seconds)
		else: over("dead")
	clock += dt
	if tm != null and not ended: tm.update(dt)
	if world.lab != null: world.lab.update(dt)
	if world.ship != null: world.ship.update(dt, clock)
	if world.safari != null: world.safari.update(dt)
	enemies.animals.bleed_update(dt); enemies.animals.roar_cd -= dt
	# the needle: lower the gun, in it goes, and at 0.82 s the antidote takes
	if inject_on:
		inject_t += dt; guns.busy = maxf(0.0, INJECT_DUR - inject_t)
		if not _inject_snd and inject_t >= 0.3: _inject_snd = true; Snd.play("inject")
		if not _inject_cured and inject_t >= CURE_AT: _inject_cured = true; cure(); Snd.play("cured")
		if inject_t >= INJECT_DUR: inject_on = false; guns.busy = 0.0
	# a bite and poison both count down to the end, and both hold while the needle is in
	if not ended and infected and not inject_on:
		infect_t -= dt
		if infect_t <= 0.0: infect_t = 0.0; over("zombie")
	if not ended and poison_t > 0.0 and not inject_on:
		poison_t = maxf(0.0, poison_t - dt)
		if poison_t <= 0.0: over("poison")

func _god() -> bool:
	return Store.settings.dev and Store.settings.god

func bitten(e: Enemies.Foe) -> void:
	if ended or _god(): return
	player.shake = maxf(player.shake, 0.35); _say(on_flash, [30.0, e.pos]); Snd.buzz(90)
	var d := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var l := maxf(d.length(), 0.001)
	player.vel.x += d.x / l * 6.0; player.vel.z += d.y / l * 6.0
	Snd.play("bite")
	if infected: infect_t = maxf(0.6, infect_t - 1.0); return
	infected = true; infect_t = 5.0
	_say(feed, ["좀비에게 물렸습니다 · 5초", 0])

## stage 2 has no health: a zombie's dash poisons, and the poison kills in 8 seconds unless an antidote goes in, just like a bite
func poison(e: Enemies.Foe) -> void:
	if ended or _god(): return
	Snd.play("bite"); Snd.buzz(120); _say(on_flash, [30.0, e.pos]); player.shake = maxf(player.shake, 0.35)
	if poison_t > 0.0: poison_t = maxf(0.6, poison_t - 1.5); _say(feed, ["또 중독 · 남은 시간이 줄었습니다", 0, true]); return
	poison_t = 8.0
	_say(feed, ["중독 · 8초 안에 해독약을 주사하세요", 0, true])

## a charge that connects knocks you out: the enraged zombie boss for 2 s
## an animal you have ridden is tamed: it never fights you again and counts as dealt with, like a kill (but pays nothing)
func tame(e: Enemies.Foe) -> void:
	calm += 1; say_feed(e.T.name + " 길들임 · 처치한 것으로 칩니다")
	if kills + calm >= goal: finish()

## the boss drone's laser: touching the beam is the end
func laser(_e: Enemies.Foe) -> void:
	if ended or player.invuln > 0.0 or _god(): return
	player.hp = 0.0; Snd.play("hurt"); over("laser")

## stage 4's save point, taken when you pull the key out: who is dead by then, the kills and the bag, your ammo, the crates you have
## broken. dying after it, '다시 도전' puts you back on the bridge with all of that as it was
func take_save() -> void:
	var alive := {}
	for e in enemies.list:
		if e.alive and e.sid >= 0: alive[e.sid] = true
	var dead := []
	for i in spawned:
		if not alive.has(i): dead.push_back(i)
	var ammo := []
	for id in Weapons.ORDER: ammo.push_back([id, guns.wstate[id].mag, guns.wstate[id].reserve])
	sp = {"stage": stage, "dead": dead, "kills": kills, "goal": goal, "money": Store.save.money, "money0": Store.money_lock, "stats": stats.duplicate(), "ammo": ammo, "cur": guns.cur, "key": world.ship.key,
		"crates": world.crates.filter(func(c): return c.dead).map(func(c): return c.idx)}

func from_save() -> void:
	var s = sp
	if s == null: begin(stage); return
	begin(s.stage); sp = s; deployed = true; boss_msg = ""
	for e in enemies.list.duplicate():
		if e.sid >= 0 and (s.dead as Array).has(e.sid): enemies.vanish(e)
	for e in enemies.dying: e.g.queue_free(); e.bar.queue_free()
	enemies.dying.clear()
	var broke := false
	for c in world.crates:
		if not c.dead and (s.crates as Array).has(c.idx):
			c.dead = true; broke = true; Phys.remove_collider(c.b)
			world.hide_crate(c)
	if broke: Phys.build_nav()
	kills = s.kills; goal = s.goal; stats = (s.stats as Dictionary).duplicate(); guns.shots = int(stats.shots); guns.hits = int(stats.hits)
	Store.save.money = s.money; Store.money_lock = s.money0; Store.persist()
	for a in s.ammo: guns.wstate[a[0]].mag = a[1]; guns.wstate[a[0]].reserve = a[2]
	if guns.slots.has(s.cur): guns.switch_to(s.cur)
	boss = null; mid = null
	for e in enemies.list:
		if e.boss: boss = e
	world.ship.restore(s)
	player.reset(Ship.SAVE.x, Ship.SAVE.z, Ship.SAVE.yaw); player.invuln = 1.5
	Phys.update_flow(player.pos.x, player.pos.z)

## the giant gorilla's leap: coming down on you is the end
func slam(_e: Enemies.Foe) -> void:
	if ended or player.invuln > 0.0 or _god(): return
	player.hp = 0.0; Snd.play("hurt"); over("slam")

func stun(e: Enemies.Foe, secs := 2.0, dmg := -1.0) -> void:
	if ended or player.invuln > 0.0 or _god(): return
	player.hurt(90.0 * e.dmg_mul if dmg < 0.0 else dmg, e.pos, "body")
	if ended or player.hp <= 0.0: return
	player.stun_t = maxf(player.stun_t, secs); guns.trigger = false; guns.ads_held = false; guns.reload_t = 0.0
	var d := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var l := maxf(d.length(), 0.001)
	player.vel.x += d.x / l * 11.0; player.vel.z += d.y / l * 11.0
	player.shake = maxf(player.shake, 0.6); Snd.play("ring"); Snd.buzz(220)
	_say(feed, ["돌진에 맞아 기절 · %d초" % int(secs), 0, true])

func cure() -> void:
	var inf := infected; var poi := poison_t > 0.0
	infected = false; infect_t = 0.0; poison_t = 0.0
	_say(feed, ["해독 완료 · " + ("감염과 중독" if (inf and poi) else ("감염" if inf else "중독")) + " 치료", 0])

## the antidote is a syringe: a moment to inject (no shooting), then infection and poison are gone
func use_antidote() -> void:
	if ended or inject_on or player.stun_t > 0.0: return
	if not infected and poison_t <= 0.0:
		if stage == 2: _say(hint, ["감염되지도 중독되지도 않았습니다 · 해독약 %d개" % antidotes, 1.2])
		return
	if antidotes <= 0: _say(hint, ["해독약이 없습니다 · 상자를 부수세요", 1.4]); return
	antidotes -= 1; inject_on = true; inject_t = 0.0; _inject_cured = false; _inject_snd = false
	guns.busy = INJECT_DUR; guns.trigger = false; guns.ads_held = false; guns.reload_t = 0.0

func take_antidote() -> bool:
	if antidotes >= 5: return false
	antidotes += 1; Snd.play("pickup_hp"); _say(feed, ["해독약 획득 · %d개" % antidotes, 0]); return true

func on_kill(e: Enemies.Foe, weak: bool) -> void:
	if ended or e.extra: return
	if tm != null: tm.on_kill(e, weak); return
	kills += 1; stats.kills += 1
	if e.tamed: calm = maxi(0, calm - 1)   # it was already counted
	var base := int(e.T.get("money", 1000)) if ((e.animal and not e.minion) or e.robot or e.toy) else 1000
	if weak: stats.heads += 1
	# a kill with a shot to the head pays 1.5 times; a boss twenty times; a stage you have already cleared pays nothing
	# so does a zombie finished off before it ever got back up (the two multiply)
	var fresh := e.type == "zombie" and not e.revived
	var pay := 0 if (replay or e.self_det or e.no_pay) else roundi((base * 20 if e.boss else (base * 10 if e.T.get("mid", false) else base)) * (1.5 if weak else 1.0) * (1.5 if fresh else 1.0)) * Store.PAY
	Store.save.money += pay; stats.earned += pay; Store.persist()
	Snd.play("kill")
	if pay > 0: Snd.play("coin"); _say(on_pay, [pay])
	# an elephant leaves its tusks: ivory, which the shop buys for a lot (not on a replay, like the money), as the browser game's
	if e.type == "elephant" and pay > 0:
		Store.save.items.ivory = mini(63, int(Store.save.items.ivory) + 1); Store.persist()
		_say(banner, ["상아 획득", "상점에서 " + Store.won(Meta.ivory_price()) + "에 팔 수 있습니다", 2.6])
	if e.boss:
		_say(feed, ["보스 " + e.name + " 처치", pay, true])
		_say(banner, ["보스 처치" + (" · +" + Store.won(pay) if pay > 0 else ""), "보물상자가 떨어졌습니다", 3.0])
		loot.chest(e.pos.x, e.pos.z, 0.0 if e.kong else e.pos.y); boss = null
		if e.kong: enemies.animals.unwarn()
		if world.lab != null: world.lab.monkey_mode = "panic"
		if e.type == "bdrone":   # its leftover mines and drones go dead with it; the hall door opens
			enemies.robots.aim_off()
			for o in enemies.list.duplicate():
				if o.extra: enemies.vanish(o)
			world.ship.on_down(e)
		if stage == 4: finish()   # the ship is won with its boss drone: open its chest and you are out (the owner's rule)
	elif e.T.get("mid", false):
		_say(feed, ["중간 보스 " + e.name + " 처치", pay, true])
		_say(banner, ["중간 보스 처치" + (" · +" + Store.won(pay) if pay > 0 else ""), "운전실을 장악했습니다", 2.4]); mid = null
		# the drones it called fall with it (they count, but pay nothing), the bridge door opens
		var fell := 0
		for o in enemies.list.duplicate():
			if o.alive and o.from_bee: o.no_pay = true; o.bee_fall = true; enemies.damage(o, 1e6, o.pos, Vector3(0, -1, 0), false, true); fell += 1
		if fell > 0: say_feed("불러낸 드론 %d대도 함께 떨어졌습니다" % fell)
		if world.ship != null: world.ship.on_down(e)
	elif e.bee_fall: pass   # counted in one line above
	elif e.self_det: _say(feed, ["스파이더 마인이 터졌습니다" if e.type == "mine" else "자폭맨이 터졌습니다", 0, true])
	elif e.no_pay and e.animal: _say(feed, ["타고 있던 " + str(e.T.name) + ("이" if Animals.batchim(str(e.T.name)) else "가") + " 쓰러졌습니다", 0, true])
	else: _say(feed, [(str(e.T.name) if e.animal else STAGES[stage].label) + (" · 머리 명중" if weak else " 처치"), pay, weak])
	var left := goal - kills - calm; var S: Dictionary = STAGES[stage]
	if not e.boss and (left == 50 or left == 25 or left == 10): _say(banner, ["%d%s 남음" % [left, S.unit], "화살표가 남은 적 쪽을 가리킵니다" if (left == 10 and stage != 4) else "가방 " + Store.won(Store.save.money), 1.8])
	if kills + calm >= goal and goal > 0: finish()

## a broken crate: a health potion (10% of max health); in the zombie village, where there is no health, always an antidote instead
func on_crate(c: Dictionary) -> void:
	if str(c.get("trap", "")) != "" and tm != null: tm.mode.trap_broken(c); return   # (the train escort: a trap on the track, shot to bits)
	if c.get("wall", false): return   # a brick figure's little wall: nothing inside
	loot.drop("anti" if stage == 2 else "hp", c.x, c.z, c.y)

func take_loot(kind: String) -> bool:
	if kind == "anti": return take_antidote()
	if kind == "hp":
		var an := enemies.animals
		if player.hp >= Player.MAX_HP and an.bleed_n == 0: return false
		var heal := minf(roundf(Player.MAX_HP * 0.1), Player.MAX_HP - player.hp); player.hp += heal
		var stopped := an.bleed_n > 0; an.bleed_stop()   # the potion also stops bleeding
		Snd.play("pickup_hp"); _say(feed, ["회복 물약 · 체력 +%d (최대 체력의 10%%)" % int(heal) + (" · 출혈 멎음" if stopped else ""), 0]); return true
	return false

## the boss's chest: a gun you do not own yet, yours for good (once you are out alive), and every gun's ammo filled
func open_chest() -> void:
	for id in guns.slots: guns.wstate[id].mag = Weapons.LIST[id].mag; guns.wstate[id].reserve = Weapons.LIST[id].reserve
	var pool: Array = Weapons.ORDER.filter(func(id): return id != "pistol" and not Store.save.owned.has(id))
	if pool.is_empty():
		Snd.play("pickup_ammo"); _say(banner, ["보물상자", "모든 총을 이미 가지고 있습니다 · 모든 총 탄약 가득", 3.2]); return
	var id: String = pool[randi() % pool.size()]; var W: Dictionary = Weapons.LIST[id]
	Store.save.owned.push_back(id)
	if not Store.save.loadout.has(id):
		var slot: int = Store.save.loadout.find(null)
		Store.save.loadout[slot if slot >= 0 else 6] = id
	Store.persist()
	guns.wstate[id].mag = W.mag; guns.wstate[id].reserve = W.reserve
	guns.loadout = layout(); guns.slots = guns.loadout.filter(func(x): return x != null); guns.none = guns.slots.is_empty(); guns.switch_to(id)
	Snd.play("buy"); Snd.play("pickup_ammo")
	_say(banner, ["보물상자 · " + W.name, W.model + " " + W.name + " 획득 · 이제 영구히 내 총입니다(살아서 나가면) · 모든 총 탄약 가득", 3.6])

func finish() -> void:
	if ended: return
	if loot.pending() != null:   # the way out waits for the chest
		if not _chest_wait: _chest_wait = true; player.invuln = 1e9; enemies.animals.bleed_stop(true); player.fear_t = 0.0; infected = false; infect_t = 0.0; poison_t = 0.0; _say(banner, ["보물상자를 여세요", "상자를 열면 우주선을 빠져나갑니다" if stage == 4 else "상자를 열어야 헬기가 옵니다", 3.0])
		return
	_leave_animals()
	ended = true; player.invuln = 1e9; infected = false; infect_t = 0.0; poison_t = 0.0; Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
	if not Store.save.cleared.has(stage): Store.save.cleared.push_back(stage); Store.save.cleared.sort()
	return_rentals()
	var key := "t%d" % stage; var t := int(stats.time)
	if not Store.save.best.has(key) or t < int(Store.save.best[key]): Store.save.best[key] = t
	Store.persist(); Snd.play("clear")
	_say(banner, ["스테이지 " + Store.STAGE_TAG[stage] + " 클리어", "헬기가 데리러 옵니다 · " + ("다시 하기라 보상 없음" if replay else "가방 " + Store.won(Store.save.money)), 2.5])
	result = "clear"; _result_kind = "clear"; _result_t = 1.7

## a team mode won: the record, the first win's bonus, and the result sheet (no helicopter: you are already home)
func win_match() -> void:
	if ended: return
	ended = true; player.invuln = 1e9; Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
	var key: String = tm.mode.record_key(); var first: bool = not Store.save.best.has(key); var t := int(stats.time)
	var extra: int = tm.mode.bonus() if first else 0
	Store.save.money += extra; stats.earned += extra
	if first or t < int(Store.save.best[key]): Store.save.best[key] = t
	return_rentals(); Store.persist(); Snd.play("clear")
	_say(banner, [tm.mode.win_title(), ("첫 승리 보너스 +" + Store.won(extra) if extra > 0 else "다시 하기라 보상 없음") + " · 가방 " + Store.won(Store.save.money), 2.6])
	result = "clear"; _result_kind = "clear"; _result_t = 2.2

## a team mode lost: what you earned in it is gone, as when you fall anywhere else
func lose_match() -> void:
	if ended: return
	ended = true; player.invuln = 1e9; forfeit(); _leave_animals(); return_rentals()
	_say(banner, [tm.mode.lose_stamp, tm.mode.lose_title, 2.6]); Snd.play("hurt")
	result = "lost"; _result_kind = "lost"; _result_t = 2.2

func _leave_animals() -> void:
	var an := enemies.animals
	if an.m != null: an.ride_off(true)
	an.bleed_stop(true); player.fear_t = 0.0
	if player.toss_on: player.toss_on = false; player.pos.y = Phys.ground_at(player.pos.x, player.pos.y, player.pos.z, Player.R); player.vel.y = 0.0

## rented guns go back when the stage ends, however it ends; a stage never deployed into (the briefing left, the app
## started again) keeps them for the next one, as the browser game's
func return_rentals() -> void:
	if not deployed: return
	deployed = false
	if (Store.save.rented as Array).is_empty(): return
	Store.save.rented = []; Store.persist()

## not getting out means not keeping what you earned in there
func forfeit() -> void:
	if Store.own_lock != null: var keep: Array = Store.own_lock; Store.save.owned = Store.save.owned.filter(func(id): return keep.has(id)); Store.own_lock = null
	if Store.ivory_lock != null: Store.save.items.ivory = maxi(0, mini(Store.save.items.ivory, Store.ivory_lock)); Store.ivory_lock = null
	if Store.money_lock != null: Store.save.money = maxi(0, mini(Store.save.money, Store.money_lock)); Store.money_lock = null
	Store.fix_save(); Store.persist()

func over(reason: String) -> void:
	if ended: return
	if Store.settings.dev and Store.settings.god: infected = false; infect_t = 0.0; poison_t = 0.0; player.hp = maxf(player.hp, 1.0); return   # developer mode's invincibility
	ended = true; forfeit(); _leave_animals()
	if sp == null: return_rentals()
	result = reason; _result_kind = reason; _result_t = 1.0
