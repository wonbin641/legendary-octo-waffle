extends Node
## What is kept between sessions: the save (money, cleared stages, guns, items) and the settings. In the browser it lives in
## localStorage; elsewhere in a file. The Godot trial keeps its own keys, apart from the browser game's (a save code carries progress over).

const ST_ARMED := 5   # the inner number of stage 1-2 (the armed docks)
const ST_TOY := 9     # the inner number of stage 5 (the toy room)
const ST_ELF := 10    # the inner number of stage 6-1 (the elves' Silverwood); 6-2 and 6-3 are 11 and 12, 6-A and 6-B 13 and 16
const ST_PLAIN := 11  # the inner number of stage 6-2 (the plain of the four banners)
const ST_ROAD := 13   # the inner number of stage 6-A (the road to the fallen tower, the demons': alone, to their lord)
const ST_ALTAR := 16  # the inner number of stage 6-B (the obsidian altar of the abyss, the demons' caldera: alone, or a battle)
const STAGE_ORDER := [1, 6, 5, 2, 3, 7, 8, 4, 14, 15, 9, 10, 11, 12, 13, 16]   # 4, 14, 15 are stage 4 (4-1 to 4-3); 9 is stage 5, the toy room; 10 to 13 and 16 are stage 6 (6-1, 6-2, 6-3, 6-A, 6-B)
const STAGE_TAG := {1: "1", 6: "1-1", 5: "1-2", 2: "2", 3: "3", 7: "3-1", 8: "3-2", 4: "4-1", 14: "4-2", 15: "4-3", 9: "5", 10: "6-1", 11: "6-2", 12: "6-3", 13: "6-A", 16: "6-B"}
const NEXT := {1: [2, 6], 6: [5], 5: [2], 2: [3], 3: [4, 7], 7: [8], 8: [4], 4: [14], 14: [15], 15: [9], 9: [10], 10: [11], 11: [13, 12], 12: [], 13: [16], 16: []}
## stage 4 is the ship, played in three parts on the one ship: 4-1 the airlock, the passage and the long corridor (cleared when
## every robot there is down), 4-2 the bridge at its west end (the gold bee), 4-3 the main hall at its east end (the boss drone
## and its chest). "Stage 4" means all three; 4-1 keeps stage 4's inner number, so a stage 4 cleared before the split is 4-1's
const SHIP := {4: "corr", 14: "bridge", 15: "hall"}
static func ship(n: int) -> String: return str(SHIP.get(n, ""))
## the stage whose place (map, look, tables) a stage is played on: 4-2 and 4-3 are on 4-1's ship
static func map_of(n: int) -> int: return 4 if SHIP.has(n) else n
## stage 6 is the places of the peoples' world: the elves' wood (6-1), the plain where all four peoples meet (6-2), the orcs'
## (6-3, to come) and the demons' two (6-A the road up to their lord's altar, 6-B their caldera, where the battles are fought
## too). "Stage 6" means all of them. No crate there holds a health potion
const REALM := {10: "elf", 11: "plain", 12: "orc", 13: "demon", 16: "demon"}
const SOON := [12]   # named on the stage board, not made yet (its map is to come)
static func realm(n: int) -> String: return str(REALM.get(n, ""))
## the stages there are to play (those only named so far are left out)
static func playable() -> Array: return STAGE_ORDER.filter(func(s): return not SOON.has(s))

signal saved   # the save has just been written on the device (the account, Cloud, sends it on)

var save := {}
var settings := {}
# the checks: everything written is kept in memory only, never on this machine's disk (nor its browser storage), so running
# them leaves whoever plays here their own save and settings
var ephemeral := false
var _mem := {}
# inside a stage, what you earned there is only yours once you get out: storage keeps what you came in with
var money_lock = null
var ivory_lock = null
var own_lock = null

static func save0() -> Dictionary:
	return {"v": 4, "money": 0, "cleared": [], "best": {}, "loadout": ["pistol", null, null, null, null, null, null], "rented": [], "owned": [], "items": {"helmet": 0, "vest": 0, "jet": 0, "ivory": 0}, "custom": {}, "toy_order": Toys.ORDER.duplicate()}

func _ready() -> void:
	var touch: bool = OS.has_feature("mobile") or OS.has_feature("web") and bool(JavaScriptBridge.eval("(window.matchMedia && matchMedia('(pointer: coarse)').matches) || ('ontouchstart' in window && navigator.maxTouchPoints > 0)"))
	settings = settings0(touch)
	var s = _read("settings")
	if s is Dictionary: settings.merge(s, true)
	save = save0()
	var d = _read("save")
	if d is Dictionary: save.merge(d, true)
	fix_save()

## the settings a new player starts with (touch: a phone or a touch screen). corpseShot: stage 2's zombie corpse shot (Guns,
## touch only), on until you turn it off
static func settings0(touch: bool) -> Dictionary:
	return {"sens": 1.0, "vol": 0.7, "music": 0.7, "autoFire": touch, "corpseShot": true, "gfx": "auto", "fps": false, "dev": false, "god": false, "cross": "cross", "crossColor": "ece6d8", "mailTo": ""}

## where the computer's quality ladder last settled (the browser game keeps it as yard07.gfxlvl); -1 when never
func level_saved() -> int:
	var v = _read("gfxlvl")
	return int(v) if (v is float or v is int) else -1
func save_level(l: int) -> void:
	_write("gfxlvl", l)

func _read(key: String):
	var text := ""
	if ephemeral: text = str(_mem.get(key, ""))
	elif OS.has_feature("web"): text = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('yarr07.godot.%s')||''}catch(e){return ''}})()" % key))
	elif FileAccess.file_exists("user://%s.json" % key): text = FileAccess.get_file_as_string("user://%s.json" % key)
	return JSON.parse_string(text) if text != "" else null

func _write(key: String, value) -> void:
	var text := JSON.stringify(value)
	if ephemeral: _mem[key] = text; return
	if OS.has_feature("web"): JavaScriptBridge.eval("try{localStorage.setItem('yarr07.godot.%s', %s)}catch(e){}" % [key, JSON.stringify(text)])
	else:
		var f := FileAccess.open("user://%s.json" % key, FileAccess.WRITE)
		if f: f.store_string(text)

## bring a save into shape: 7 slots, one slot per gun, known guns and stages only, whole numbers
func fix_save() -> void:
	var lo: Array = save.loadout if save.get("loadout") is Array else []
	var out := []
	for i in 7:
		var id = lo[i] if i < lo.size() else null
		out.push_back(id if (id is String and Weapons.LIST.has(id) and not out.has(id)) else null)
	save.loadout = out
	for k in ["rented", "owned"]:
		var u := []
		for id in (save[k] if save.get(k) is Array else []):
			if id is String and Weapons.LIST.has(id) and id != "pistol" and not u.has(id): u.push_back(id)
		save[k] = u
	var cl := []
	for n in (save.cleared if save.get("cleared") is Array else []):
		if STAGE_ORDER.has(int(n)) and not cl.has(int(n)): cl.push_back(int(n))
	cl.sort(); save.cleared = cl
	var it: Dictionary = save.items if save.get("items") is Dictionary else {}
	save.items = {"helmet": 1 if int(it.get("helmet", 0)) else 0, "vest": clampi(int(it.get("vest", 0)), 0, 10), "jet": 1 if int(it.get("jet", 0)) else 0, "ivory": clampi(int(it.get("ivory", 0)), 0, 63)}
	save.money = maxi(0, int(save.get("money", 0)))
	if not (save.get("best") is Dictionary): save.best = {}
	var cu := {}
	if save.get("custom") is Dictionary:
		for id in save.custom:
			if Weapons.LIST.has(id) and save.custom[id] is Dictionary: cu[id] = save.custom[id]
	save.custom = cu
	for id in cu.keys(): cu[id] = Custom.setup(id)   # only parts that fit the gun
	# the toy room's nine toy guns in the order you put them (keys 1-9); not in the save code
	var to: Array = save.toy_order if save.get("toy_order") is Array else []
	save.toy_order = to.duplicate() if (to.size() == Toys.ORDER.size() and Toys.ORDER.all(func(id): return to.has(id))) else Toys.ORDER.duplicate()
	save.v = 4

## the save as it is kept (inside a stage: with what you came in with, not what you have picked up there)
func stored() -> Dictionary:
	if money_lock == null and ivory_lock == null and own_lock == null: return save
	var o: Dictionary = save.duplicate(true)
	if money_lock != null: o.money = maxi(0, mini(save.money, money_lock))
	if ivory_lock != null: o.items.ivory = maxi(0, mini(save.items.ivory, ivory_lock))
	if own_lock != null: o.owned = save.owned.filter(func(id): return own_lock.has(id))
	return o

func persist() -> void:
	_write("save", stored()); saved.emit()

func persist_settings() -> void:
	_write("settings", settings)

## the five main stages (1, 2, 3, 4 and 5) are open from the start; a side stage opens once the one before it on its branch is
## cleared: 1-1 after 1, 1-2 after 1-1, 3-1 after 3, 3-2 after 3-1. New side stages follow the same rule. Developer mode opens
## them all, and a stage once cleared stays open (every stage used to be open from the start). NEXT only says which stages follow
## on the stage tree
const NEEDS := {6: 1, 5: 6, 7: 3, 8: 7, 14: 4, 15: 14, 11: 10, 12: 11, 13: 11, 16: 13}   # (stages 4 and 6: the first part open as a main stage is, each of the rest after the one before)
const PAY := 2   # every way of earning pays twice what the browser game pays (kills, bosses, ivory, stage 5's team modes): the owner's rule
func stage_open(n: int) -> bool:
	if not STAGE_TAG.has(n) or SOON.has(n): return false
	if bool(settings.get("dev", false)) or not NEEDS.has(n): return true
	var cl: Array = save.get("cleared", [])
	return cl.has(NEEDS[n]) or cl.has(n)

func next_stages(n: int) -> Array:
	return (NEXT.get(n, []) as Array).filter(func(s): return stage_open(s))

## which guns you may carry this stage: the pistol, guns you own for good, what you rented, or everything in developer mode
func gun_available(id: String, bonus := []) -> bool:
	return id == "pistol" or settings.dev or save.owned.has(id) or save.rented.has(id) or bonus.has(id)

static func won(n) -> String:
	var s := str(int(n)); var out := ""
	while s.length() > 3: out = "," + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
	return s + out + "원"

static func fmt_time(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]

## the ISO 6346 container code with its real check digit, as on the result sheet
static func iso_code(owner: String, serial: int) -> String:
	var val := {}; var v := 10
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		if v % 11 == 0: v += 1
		val[ch] = v; v += 1
	for d in 10: val[str(d)] = d
	var body := owner + "U" + ("%06d" % serial); var sum := 0
	for i in 10: sum += val[body[i]] * (1 << i)
	return owner + "U " + body.substr(4) + " " + str((sum % 11) % 10)
