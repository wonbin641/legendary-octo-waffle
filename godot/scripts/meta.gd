class_name Meta
## What happens between stages: the shop (items, rentals, ammunition, ivory), the weapon layout, and the recommended
## kit for each stage. Ported from src/08f_meta.js; the recommended kit is new in the Godot version.

const ITEMS := {
	"helmet": {"name": "오토바이 헬멧", "tag": "머리", "price": 1000, "desc": "머리로 오는 공격을 한 번 막아 줍니다. 막으면 부서집니다."},
	"vest": {"name": "방탄조끼", "tag": "몸", "price": 5000, "desc": "몸으로 오는 공격을 50% 줄여 줍니다. 10번 막으면 닳아 없어집니다. 불은 못 막습니다."},
	"jet": {"name": "제트백팩", "tag": "비행", "price": 100000, "desc": "점프(Space)를 두 번 누르면 날아오릅니다. Space는 위로, Ctrl 또는 C는 아래로. 최대 10초, 한 번 쓰면 끝입니다.",
		"desc_touch": "점프 버튼을 두 번 누르면 날아오릅니다. 점프는 위로, 내려가기 버튼은 아래로. 최대 10초, 한 번 쓰면 끝입니다."},
}
const IVORY_PRICE := 50000
static func ivory_price() -> int: return IVORY_PRICE * Store.PAY   # what one sells for (twice the browser game's, as all income here)
const ITEM_ORDER := ["helmet", "vest", "jet"]

# ---------- the recommended kit: every 'all' is needed, and one of each 'any' group ----------
const _EVERYTHING := ["pistol", "shotgun", "rifle", "smg", "sniper", "gl", "lmg", "rocket", "helmet", "vest", "jet"]
static func _all_but(skip: Array) -> Array:
	return _EVERYTHING.filter(func(id): return not skip.has(id))
static func spec(stage: int) -> Dictionary:
	match stage:
		1: return {"all": ["pistol"], "any": []}
		2, 6: return {"all": ["gl"], "any": [["rifle", "smg", "lmg"]]}
		5: return {"all": _all_but(["jet", "rocket", "shotgun", "pistol"]), "any": []}
		3: return {"all": _all_but(["jet", "shotgun", "pistol"]), "any": []}
		7, 8: return {"all": _all_but(["pistol"]), "any": []}
		4: return {"all": _all_but(["pistol", "jet", "shotgun"]), "any": []}
		9: return {"all": [], "any": []}
		10: return {"all": ["sniper", "vest"], "any": [["rifle", "smg", "lmg"]]}   # (6-1: bows in the boughs to answer, no potions on the way)
	return {"all": [], "any": []}

## a gun counts when it is in the layout and yours to carry (owned, rented, the pistol); an item when you have it
static func has(id: String) -> bool:
	if ITEMS.has(id): return int(Store.save.items.get(id, 0)) > 0
	return Store.save.loadout.has(id) and Store.gun_available(id)

## what the stage's recommended kit still lacks (for an 'any' group: all its candidates)
static func missing(stage: int) -> Array:
	var s := spec(stage); var out := []
	for id in s.all:
		if not has(id): out.push_back(id)
	for grp: Array in s.any:
		if not grp.any(func(id): return has(id)): out.append_array(grp)
	return out

static func fits(stage: int) -> bool:
	return missing(stage).is_empty()

static func spec_text(stage: int) -> String:
	var s := spec(stage); var names: Array = s.all.map(func(id): return name_of(id))
	for grp: Array in s.any: names.push_back(" 또는 ".join(grp.map(func(id): return name_of(id))))
	return " · ".join(names)

static func name_of(id: String) -> String:
	return ITEMS[id].name if ITEMS.has(id) else Weapons.LIST[id].name

# ---------- money ----------
static func spend(c: int) -> void:
	Store.save.money -= c
	if Store.money_lock != null: Store.money_lock -= c
	Store.persist()
static func refund(c: int) -> void:
	Store.save.money += c
	if Store.money_lock != null: Store.money_lock += c
	Store.persist()

# ---------- the shop: each returns the line to show ----------
static func item_state(id: String) -> String:
	var v := int(Store.save.items.get(id, 0))
	return "없음" if v == 0 else ("착용 중 · 내구 %d/10" % v if id == "vest" else ("착용 중" if id == "helmet" else "가지고 있음"))

static func buy_item(id: String) -> String:
	var I: Dictionary = ITEMS[id]; var price: int = 0 if Store.settings.dev else I.price
	if int(Store.save.items[id]) > 0: return I.name + "은(는) 이미 가지고 있습니다"
	if Store.save.money < price: return Store.won(price - Store.save.money) + " 더 필요합니다"
	spend(price); Store.save.items[id] = 10 if id == "vest" else 1; Store.persist(); Snd.play("buy")
	return I.name + " 구매" + (" · 싸우는 중에 점프를 두 번 누르면 날아오릅니다" if id == "jet" else " · 바로 착용했습니다")

static func sell_ivory(n: int) -> String:
	var have := int(Store.save.items.ivory); var can: int = have if Store.ivory_lock == null else mini(have, Store.ivory_lock); n = mini(n, can)
	if n < 1: return "팔 수 있는 상아가 없습니다"
	Store.save.items.ivory = have - n
	if Store.ivory_lock != null: Store.ivory_lock -= n
	refund(n * ivory_price()); Snd.play("buy"); Snd.play("coin")
	return "상아 %d개를 팔았습니다 · +%s" % [n, Store.won(n * ivory_price())]

## a freshly rented gun goes into the first empty slot; returns the slot number (1-7), or 0 when the layout is full
static func place(id: String) -> int:
	var at: int = Store.save.loadout.find(id)
	if at >= 0: return at + 1
	var i: int = Store.save.loadout.find(null)
	if i < 0: return 0
	Store.save.loadout[i] = id; Store.persist(); return i + 1

static func rent(id: String, mid: bool) -> String:
	var W: Dictionary = Weapons.LIST[id]; var fee := 0 if Store.settings.dev else Weapons.rent(id)   # (developer mode: everything free)
	if id == "pistol" or Store.save.owned.has(id): return W.name + " · 이미 가진 무기입니다"   # (the shop shows no rent button then: a second press, or a stale one, does nothing)
	if Store.save.rented.has(id): return W.name + " · 이미 대여 중입니다"
	if Store.save.money < fee: return Store.won(fee - Store.save.money) + " 더 필요합니다"
	spend(fee); Store.save.rented.push_back(id)
	var slot := place(id); Store.persist(); Snd.play("buy")
	return W.name + " 대여 · " + ("이번 스테이지가 끝나면 반납" if mid else "다음 스테이지 한 번 쓰고 반납") + (" · %d번 칸에 넣었습니다" % slot if slot > 0 else " · 빈 칸이 없어 무기 편성에서 넣어 주세요")

static func cancel_rent(id: String) -> String:
	if not Store.save.rented.has(id): return ""   # (nothing rented: nothing to give back)
	var fee := 0 if Store.settings.dev else Weapons.rent(id)   # (what renting costs now: nothing in developer mode, as rent() takes)
	Store.save.rented.erase(id); refund(fee); Snd.play("reload0")
	return Weapons.LIST[id].name + " 대여를 취소했습니다 · " + Store.won(fee) + " 돌려받음"

## how many more rounds a gun can take in the middle of a stage: a rocket up to its 12 (in the tube and carried), the other guns
## up to their full reserve (the browser game sells them without end; this port stops at the reserve: the owner's rule, 1.6.2)
static func ammo_room(id: String, guns: Guns) -> int:
	var W: Dictionary = Weapons.LIST[id]; var st: Dictionary = guns.wstate[id]
	if W.get("rocket", false): return int(maxf(0.0, W.reserve + W.mag - st.mag - st.reserve))
	if W.reserve == INF or st.reserve == INF: return 0   # (the pistol's rounds never run out: none to buy)
	return int(maxf(0.0, W.reserve - st.reserve))
## the next pack for a gun: [rounds, price] (100 rounds, or what still fits for its share of the price; one rocket)
static func ammo_pack(id: String, guns: Guns) -> Array:
	var n := 1 if Weapons.LIST[id].get("rocket", false) else mini(100, ammo_room(id, guns))
	var full: int = 0 if Store.settings.dev else Weapons.AMMO100[id]
	return [n, full if (n >= 100 or Weapons.LIST[id].get("rocket", false)) else ceili(full * n / 100.0)]

## 100 more rounds (one rocket) for a gun in the middle of a stage
static func buy_ammo(id: String, guns: Guns) -> String:
	var W: Dictionary = Weapons.LIST[id]; var st: Dictionary = guns.wstate[id]
	if ammo_room(id, guns) < 1: return W.name + " · 더 들 수 없습니다"
	var pk := ammo_pack(id, guns); var n: int = pk[0]; var c: int = pk[1]
	if Store.save.money < c: return Store.won(c - Store.save.money) + " 더 필요합니다"
	spend(c); st.reserve += n; Snd.play("reload1")
	return W.name + (" 로켓 1발 · %d/12" % int(st.mag + st.reserve) if W.get("rocket", false) else " 총알 %d발 · %d발" % [n, int(st.reserve)])

## put a gun in a slot (or empty it); a gun sits in one slot only
## the weapon order, changed in the middle of a stage too: a gun swaps places with the next gun before it (step -1) or after it
## (step 1) in your hands, keeping the empty slots where they are. In the toy room the toy guns' order (keys 1-9): the toys of
## your weapon layout come first in its order, so two of them swap their slots in the layout itself; the others keep their own
## order after them (Store.save.toy_order); one of each kind never passes the other
static func move_gun(id: String, step: int, toys := false) -> bool:
	if toys:
		if not can_move_toy(id, step): return false
		var cur := Toys.order_for(Store.save.loadout, Store.save.toy_order); var i := cur.find(id); var other: String = cur[i + step]
		if i < Toys.lead(Store.save.loadout):
			var lo2: Array = Store.save.loadout; var a := lo2.find(id); var b := lo2.find(other); lo2[a] = other; lo2[b] = id
		else:
			cur[i] = other; cur[i + step] = id; Store.save.toy_order = cur
		Store.persist(); return true
	var lo: Array = Store.save.loadout
	var i := lo.find(id)
	if i < 0: return false
	var j := i + step
	while j >= 0 and j < lo.size() and (lo[j] == null or not Store.gun_available(lo[j])): j += step
	if j < 0 or j >= lo.size(): return false
	lo[i] = lo[j]; lo[j] = id; Store.persist(); return true
## whether a toy gun can make that move: within your layout's own toys or within the others (see move_gun)
static func can_move_toy(id: String, step: int) -> bool:
	var cur := Toys.order_for(Store.save.loadout, Store.save.toy_order); var i := cur.find(id); var j := i + step; var n := Toys.lead(Store.save.loadout)
	return i >= 0 and j >= 0 and j < cur.size() and (i < n) == (j < n)
## the loadout screen's arrows: a slot swaps with the slot next to it, empty or not
static func swap_slots(i: int, j: int) -> void:
	var lo: Array = Store.save.loadout
	if i < 0 or j < 0 or i >= lo.size() or j >= lo.size(): return
	var t = lo[i]; lo[i] = lo[j]; lo[j] = t; Store.persist()

static func set_slot(slot: int, id) -> void:
	if id != null:
		var j: int = Store.save.loadout.find(id)
		if j >= 0 and j != slot: Store.save.loadout[j] = null
	Store.save.loadout[slot] = id; Store.persist()
