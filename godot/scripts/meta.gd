class_name Meta
## What happens between stages: the shop (items, rentals, ammunition, ivory), the weapon layout, and the recommended
## kit for each stage. Ported from src/08f_meta.js; the recommended kit is new in the Godot version.

const ITEMS := {
	"helmet": {"name": "오토바이 헬멧", "tag": "머리", "price": 10000, "desc": "머리로 오는 공격을 한 번 막아 줍니다. 막으면 부서집니다."},
	"vest": {"name": "방탄조끼", "tag": "몸", "price": 50000, "desc": "몸으로 오는 공격을 50% 줄여 줍니다. 10번 막으면 닳아 없어집니다. 불은 못 막습니다."},
	"jet": {"name": "제트백팩", "tag": "비행", "price": 100000, "desc": "점프(Space)를 두 번 누르면 날아오릅니다. Space는 위로, Ctrl 또는 C는 아래로. 최대 10초, 한 번 쓰면 끝입니다.",
		"desc_touch": "점프 버튼을 두 번 누르면 날아오릅니다. 점프는 위로, 내려가기 버튼은 아래로. 최대 10초, 한 번 쓰면 끝입니다."},
}
const IVORY_PRICE := 50000
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
	refund(n * IVORY_PRICE); Snd.play("buy"); Snd.play("coin")
	return "상아 %d개를 팔았습니다 · +%s" % [n, Store.won(n * IVORY_PRICE)]

## a freshly rented gun goes into the first empty slot; returns the slot number (1-7), or 0 when the layout is full
static func place(id: String) -> int:
	var at: int = Store.save.loadout.find(id)
	if at >= 0: return at + 1
	var i: int = Store.save.loadout.find(null)
	if i < 0: return 0
	Store.save.loadout[i] = id; Store.persist(); return i + 1

static func rent(id: String, mid: bool) -> String:
	var W: Dictionary = Weapons.LIST[id]; var fee := Weapons.rent(id)
	if Store.save.money < fee: return Store.won(fee - Store.save.money) + " 더 필요합니다"
	spend(fee); Store.save.rented.push_back(id)
	var slot := place(id); Store.persist(); Snd.play("buy")
	return W.name + " 대여 · " + ("이번 스테이지가 끝나면 반납" if mid else "다음 스테이지 한 번 쓰고 반납") + (" · %d번 칸에 넣었습니다" % slot if slot > 0 else " · 빈 칸이 없어 무기 편성에서 넣어 주세요")

static func cancel_rent(id: String) -> String:
	Store.save.rented.erase(id); refund(Weapons.rent(id)); Snd.play("reload0")
	return Weapons.LIST[id].name + " 대여를 취소했습니다 · " + Store.won(Weapons.rent(id)) + " 돌려받음"

## 100 more rounds (one rocket) for a gun in the middle of a stage
static func buy_ammo(id: String, guns: Guns) -> String:
	var W: Dictionary = Weapons.LIST[id]; var c: int = 0 if Store.settings.dev else Weapons.AMMO100[id]; var st: Dictionary = guns.wstate[id]
	var room: float = maxf(0.0, W.reserve + W.mag - st.mag - st.reserve) if W.get("rocket", false) else INF
	if Store.save.money < c: return Store.won(c - Store.save.money) + " 더 필요합니다"
	if room < 1.0: return W.name + " · 더 들 수 없습니다"
	spend(c); st.reserve += 1 if W.get("rocket", false) else 100; Snd.play("reload1")
	return W.name + (" 로켓 1발 · %d/12" % int(st.mag + st.reserve) if W.get("rocket", false) else " 총알 100발 · %d발" % int(st.reserve))

## put a gun in a slot (or empty it); a gun sits in one slot only
static func set_slot(slot: int, id) -> void:
	if id != null:
		var j: int = Store.save.loadout.find(id)
		if j >= 0 and j != slot: Store.save.loadout[j] = null
	Store.save.loadout[slot] = id; Store.persist()
