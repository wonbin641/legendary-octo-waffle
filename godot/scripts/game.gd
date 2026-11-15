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
const BOSS := {1: {"type": "thug", "name": "조직 두목", "josa": "이", "scale": 1.35, "hp": 1600, "dmgMul": 1.6}}

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
	guns.reset(layout()); guns.stage = stage; proj.stage = stage
	stats = {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "earned": 0, "time": 0.0}
	Store.money_lock = Store.save.money; Store.ivory_lock = Store.save.items.ivory; Store.own_lock = (Store.save.owned as Array).duplicate()
	player.reset(world.start.x, world.start.z, world.start.yaw); player.invuln = 1.5
	if stage == 9: player.pos.y = 42.0; player.grounded = false; player.chute = true   # you come down into the room under a parachute
	kills = 0; ended = false; result = ""; _result_t = -1.0; _chest_wait = false; opened = []
	populate()
	var B: Dictionary = BOSS.get(stage, {})
	boss_msg = ("보스 " + B.name + B.josa + " 어딘가에 있습니다" + (" · 다시 하기라 보상은 없습니다" if replay else " · " + Store.won(20000))) if not B.is_empty() else ""
	Phys.update_flow(player.pos.x, player.pos.z); flow_t = 0.3

## the same stage always puts the same enemies in the same places
func populate() -> void:
	if stage == 9: goal = 0; boss = null; return   # nobody in the toy room yet
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
	if not B.is_empty():
		var bp = find.call(55.0, 8.0, 2.5)
		if bp == null: bp = find.call(30.0, 4.0, 1.5)
		var bo := B.duplicate(); bo.boss = true; put.call(B.type, bp, bo)
	# guard posts of 2-4 people
	while n[0] < 100:
		var center = find.call(36.0, 5.0, 0.8)
		if center == null: break
		put.call("thug", center, {})
		var grp := int(floor(SR.rng(2, 5)))
		for i in range(1, grp): put.call("thug", find.call(33.0, 1.6, 0.6, center, 5.0), {})
	goal = enemies.list.size(); boss = null
	for e in enemies.list:
		if e.boss: boss = e

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

func on_kill(e: Enemies.Foe, weak: bool) -> void:
	if ended or e.extra: return
	kills += 1; stats.kills += 1
	if weak: stats.heads += 1
	# a kill with a shot to the head pays 1.5 times; a boss twenty times; a stage you have already cleared pays nothing
	var pay := 0 if (replay or e.self_det or e.no_pay) else roundi((1000 * 20 if e.boss else 1000) * (1.5 if weak else 1.0))
	Store.save.money += pay; stats.earned += pay; Store.persist()
	Snd.play("kill")
	if pay > 0: Snd.play("coin")
	if e.boss:
		_say(banner, ["보스 처치" + (" · +" + Store.won(pay) if pay > 0 else ""), "보물상자가 떨어졌습니다", 3.0])
		loot.chest(e.pos.x, e.pos.z, e.pos.y); boss = null
	else: _say(feed, [STAGES[stage].label + (" · 머리 명중" if weak else " 처치"), pay])
	var left := goal - kills; var S: Dictionary = STAGES[stage]
	if not e.boss and (left == 50 or left == 25 or left == 10): _say(banner, ["%d%s 남음" % [left, S.unit], "가방 " + Store.won(Store.save.money), 1.8])
	if kills >= goal and goal > 0: finish()

## a broken crate: a health potion (10% of max health)
func on_crate(c: Dictionary) -> void:
	loot.drop("hp", c.x, c.z, c.y)

func take_loot(kind: String) -> bool:
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
		if not _chest_wait: _chest_wait = true; _say(banner, ["보물상자를 여세요", "상자를 열어야 헬기가 옵니다", 3.0])
		return
	ended = true; player.invuln = 1e9; Store.money_lock = null; Store.ivory_lock = null; Store.own_lock = null
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
	if Store.settings.dev and Store.settings.god: player.hp = maxf(player.hp, 1.0); return   # developer mode's invincibility
	ended = true; forfeit(); return_rentals()
	result = reason; _result_kind = reason; _result_t = 1.0
