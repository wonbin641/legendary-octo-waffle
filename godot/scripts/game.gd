class_name Game
extends RefCounted
## One run of a stage: who stands where, what a kill pays, the boss's chest, clearing and falling. Ported from Game in src/08b_game.js.

const STAGES := {
	1: {"name": "컨테이너 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "밀수 조직원 100명 · 총소리를 들으면 몰려옵니다"},
	6: {"name": "헬멧 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "오토바이 헬멧 쓴 조직원 100명 · 헬멧은 머리를 한 번 맞히면 벗겨집니다"},
	5: {"name": "무장 부두", "enemy": "thug", "goal": 100, "unit": "명", "label": "조직원", "intro": "단검 20 · 파란 광선검 10 · 쌍광선검 5 · 야구방망이 15 · 자폭맨 10 · 저격 5 · 보스는 기관총"},
	2: {"name": "불타는 마을", "enemy": "zombie", "goal": 100, "unit": "마리", "label": "좀비", "intro": "좀비 100마리 · 체력은 없고 감염과 중독뿐 · 해독약은 나무 상자에서"},
	3: {"name": "동물 연구소", "enemy": "animal", "goal": 100, "unit": "마리", "label": "동물", "intro": ""},
	7: {"name": "사파리 감시탑", "enemy": "animal", "goal": 100, "unit": "마리", "label": "동물", "intro": ""},
	8: {"name": "차례 연구소", "enemy": "animal", "goal": 100, "unit": "마리", "label": "동물", "intro": ""},
	9: {"name": "장난감 방", "enemy": "toy", "goal": 0, "unit": "개", "label": "장난감", "intro": "아이 방 전체가 싸움터 · 침대, 책상, 블록 다리, 책장 꼭대기 · 지금은 맵과 장난감 무기만 둘러볼 수 있습니다"},
	4: {"name": "우주선", "enemy": "robot", "goal": 100, "unit": "대", "label": "로봇", "intro": ""},
}
const BOSS := {
	1: {"type": "thug", "name": "조직 두목", "josa": "이", "scale": 1.35, "hp": 1600, "dmgMul": 1.6},
	6: {"type": "thug", "name": "헬멧 두목", "josa": "이", "scale": 1.35, "hp": 1600, "dmgMul": 1.6, "helmet": true},
	2: {"type": "zombie", "name": "거대 좀비", "josa": "가", "scale": 1.7, "hp": 2200, "dmgMul": 1.0},
	5: {"type": "thug", "name": "무장 두목", "josa": "이", "scale": 1.4, "hp": 2600, "dmgMul": 1.0, "kit": "lmg"},
}
var drop_pick = null   # 1-2: where you chose to be put down (kept for another go)

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
var opened: Array = []
var stats := {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "earned": 0, "time": 0.0}
var bonus_guns: Array = []
var _result_t := -1.0
var _result_kind := ""
var _chest_wait := false
var flow_t := 0.0
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

func _say(c: Callable, a: Array) -> void:
	if c.is_valid(): c.callv(a)

func layout() -> Array:
	if stage == 9: return Toys.ORDER.duplicate()   # the preview hands you every toy gun (keys 1-9)
	return (Store.save.loadout as Array).map(func(id): return id if (id != null and Store.gun_available(id, bonus_guns)) else null)

func begin(stage_: int) -> void:
	stage = stage_
	enemies.clear(); proj.clear(); loot.clear(); fx.clear()
	world.build_stage(stage)
	bonus_guns = []; replay = Store.save.cleared.has(stage)
	guns.reset(layout()); guns.stage = stage; enemies.stage = stage; enemies.down_hint = false; proj.stage = stage; guns.toy = stage == 9
	stats = {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "earned": 0, "time": 0.0}
	Store.money_lock = Store.save.money; Store.ivory_lock = Store.save.items.ivory; Store.own_lock = (Store.save.owned as Array).duplicate()
	player.reset(world.start.x, world.start.z, world.start.yaw); player.invuln = 1.5
	if stage == 9: player.pos.y = 42.0; player.grounded = false; player.chute = true   # you come down into the room under a parachute
	infected = false; infect_t = 0.0; poison_t = 0.0; antidotes = 1 if stage == 2 else 0; inject_on = false; inject_t = 0.0; player.stun_t = 0.0; player.no_hp = stage == 2
	kills = 0; ended = false; result = ""; _result_t = -1.0; _chest_wait = false; opened = []
	# 1-2 crowds the middle of the docks, so unless you pick somewhere else you come down at the south edge, facing in
	if stage == 5:
		var d = open_spot(0.0, 58.0)
		if d != null: world.start = d; player.reset(d.x, d.z, d.yaw); player.invuln = 1.5
	populate()
	if stage == 5 and drop_pick != null: set_drop(drop_pick)
	var B: Dictionary = BOSS.get(stage, {})
	boss_msg = ("보스 " + B.name + B.josa + " 어딘가에 있습니다" + (" · 다시 하기라 보상은 없습니다" if replay else " · " + Store.won(20000))) if not B.is_empty() else ""
	Phys.update_flow(player.pos.x, player.pos.z); flow_t = 0.3

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

func pick_drop(x: float, z: float):
	var d = open_spot(x, z)
	if d == null: return null
	drop_pick = d; set_drop(d); return d

func set_drop(d: Dictionary) -> void:
	world.start = {"x": d.x, "z": d.z, "yaw": d.yaw}; player.pos = Vector3(d.x, 0, d.z); player.yaw = d.yaw; player.pitch = 0.0; Phys.update_flow(d.x, d.z)

## the same stage always puts the same enemies in the same places
func populate() -> void:
	if stage == 9: goal = 0; boss = null; return   # nobody in the toy room yet
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
	var n := [0]
	var put := func(type: String, p, opts: Dictionary) -> void:
		if p != null and n[0] < 100:
			var o := {"yaw": SR.rng(0, TAU)}; o.merge(opts, true)
			var e := enemies.spawn(type, p.x, p.z, o); e.sid = n[0]; n[0] += 1
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
	flow_t -= dt
	if flow_t <= 0.0: flow_t = 0.3; Phys.update_flow(player.pos.x, player.pos.z)
	stats.shots = guns.shots; stats.hits = guns.hits
	if _chest_wait and loot.pending() == null: _chest_wait = false; finish()
	if _result_t > 0.0:
		_result_t -= dt
		if _result_t <= 0.0: _say(on_result, [_result_kind])
	if not ended and player.hp <= 0.0: over("dead")
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
	player.shake = maxf(player.shake, 0.35); _say(on_flash, [30.0, e.pos])
	var d := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var l := maxf(d.length(), 0.001)
	player.vel.x += d.x / l * 6.0; player.vel.z += d.y / l * 6.0
	Snd.play("bite")
	if infected: infect_t = maxf(0.6, infect_t - 1.0); return
	infected = true; infect_t = 5.0
	_say(feed, ["좀비에게 물렸습니다 · 5초", 0])

## stage 2 has no health: a zombie's dash poisons, and the poison kills in 8 seconds unless an antidote goes in, just like a bite
func poison(e: Enemies.Foe) -> void:
	if ended or _god(): return
	Snd.play("bite"); _say(on_flash, [30.0, e.pos]); player.shake = maxf(player.shake, 0.35)
	if poison_t > 0.0: poison_t = maxf(0.6, poison_t - 1.5); _say(feed, ["또 중독 · 남은 시간이 줄었습니다", 0]); return
	poison_t = 8.0
	_say(feed, ["중독 · 8초 안에 해독약을 주사하세요", 0])

## a charge that connects knocks you out: the enraged zombie boss for 2 s
func stun(e: Enemies.Foe, secs := 2.0) -> void:
	if ended or player.invuln > 0.0 or _god(): return
	player.hurt(90.0 * e.dmg_mul, e.pos, "body")
	if ended or player.hp <= 0.0: return
	player.stun_t = maxf(player.stun_t, secs); guns.trigger = false; guns.ads_held = false; guns.reload_t = 0.0
	var d := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var l := maxf(d.length(), 0.001)
	player.vel.x += d.x / l * 11.0; player.vel.z += d.y / l * 11.0
	player.shake = maxf(player.shake, 0.6); Snd.play("ring")
	_say(feed, ["돌진에 맞아 기절 · %d초" % int(secs), 0])

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
	kills += 1; stats.kills += 1
	if weak: stats.heads += 1
	# a kill with a shot to the head pays 1.5 times; a boss twenty times; a stage you have already cleared pays nothing
	# so does a zombie finished off before it ever got back up (the two multiply)
	var fresh := e.type == "zombie" and not e.revived
	var pay := 0 if (replay or e.self_det or e.no_pay) else roundi((1000 * 20 if e.boss else 1000) * (1.5 if weak else 1.0) * (1.5 if fresh else 1.0))
	Store.save.money += pay; stats.earned += pay; Store.persist()
	Snd.play("kill")
	if pay > 0: Snd.play("coin")
	if e.boss:
		_say(banner, ["보스 처치" + (" · +" + Store.won(pay) if pay > 0 else ""), "보물상자가 떨어졌습니다", 3.0])
		loot.chest(e.pos.x, e.pos.z, e.pos.y); boss = null
	elif e.self_det: _say(feed, ["자폭맨이 터졌습니다", 0])
	else: _say(feed, [STAGES[stage].label + (" · 머리 명중" if weak else " 처치"), pay])
	var left := goal - kills; var S: Dictionary = STAGES[stage]
	if not e.boss and (left == 50 or left == 25 or left == 10): _say(banner, ["%d%s 남음" % [left, S.unit], "가방 " + Store.won(Store.save.money), 1.8])
	if kills >= goal and goal > 0: finish()

## a broken crate: a health potion (10% of max health); in the zombie village, where there is no health, always an antidote instead
func on_crate(c: Dictionary) -> void:
	loot.drop("anti" if stage == 2 else "hp", c.x, c.z, c.y)

func take_loot(kind: String) -> bool:
	if kind == "anti": return take_antidote()
	if kind == "hp":
		if player.hp >= Player.MAX_HP: return false
		var heal := minf(roundf(Player.MAX_HP * 0.1), Player.MAX_HP - player.hp); player.hp += heal
		Snd.play("pickup_hp"); _say(feed, ["회복 물약 · 체력 +%d (최대 체력의 10%%)" % int(heal), 0]); return true
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
		if not _chest_wait: _chest_wait = true; player.invuln = 1e9; infected = false; infect_t = 0.0; poison_t = 0.0; _say(banner, ["보물상자를 여세요", "상자를 열어야 헬기가 옵니다", 3.0])
		return
	ended = true; player.invuln = 1e9; infected = false; infect_t = 0.0; poison_t = 0.0; Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
	opened = [] if Store.settings.dev else (Store.NEXT.get(stage, []) as Array).filter(func(s): return not Store.stage_open(s))
	if not Store.save.cleared.has(stage): Store.save.cleared.push_back(stage); Store.save.cleared.sort()
	return_rentals()
	var key := "t%d" % stage; var t := int(stats.time)
	if not Store.save.best.has(key) or t < int(Store.save.best[key]): Store.save.best[key] = t
	Store.persist(); Snd.play("clear")
	_say(banner, ["스테이지 " + Store.STAGE_TAG[stage] + " 클리어", "헬기가 데리러 옵니다 · " + ("다시 하기라 보상 없음" if replay else "가방 " + Store.won(Store.save.money)), 2.5])
	result = "clear"; _result_kind = "clear"; _result_t = 1.7

## rented guns go back when the stage ends, however it ends
func return_rentals() -> void:
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
	ended = true; forfeit(); return_rentals()
	result = reason; _result_kind = reason; _result_t = 1.0
