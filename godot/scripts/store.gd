extends Node
## What is kept between sessions: the save (money, cleared stages, guns, items) and the settings. In the browser it lives in
## localStorage; elsewhere in a file. The Godot trial keeps its own keys, apart from the browser game's (a save code carries progress over).

const STAGE_ORDER := [1, 6, 5, 2, 3, 7, 8, 4, 9]   # 9 is stage 5, the toy room
const STAGE_TAG := {1: "1", 6: "1-1", 5: "1-2", 2: "2", 3: "3", 7: "3-1", 8: "3-2", 4: "4", 9: "5"}
const NEXT := {1: [2, 6], 6: [5], 5: [2], 2: [3], 3: [4, 7], 7: [8], 8: [4], 4: [9], 9: []}

var save := {}
var settings := {}
# inside a stage, what you earned there is only yours once you get out: storage keeps what you came in with
var money_lock = null
var ivory_lock = null
var own_lock = null

static func save0() -> Dictionary:
	return {"v": 4, "money": 0, "cleared": [], "best": {}, "loadout": ["pistol", null, null, null, null, null, null], "rented": [], "owned": [], "items": {"helmet": 0, "vest": 0, "jet": 0, "ivory": 0}, "custom": {}}

func _ready() -> void:
	var touch: bool = OS.has_feature("web") and bool(JavaScriptBridge.eval("(window.matchMedia && matchMedia('(pointer: coarse)').matches) || ('ontouchstart' in window && navigator.maxTouchPoints > 0)"))
	settings = {"sens": 1.0, "vol": 0.7, "autoFire": touch, "gfx": "auto", "fps": false, "dev": false, "god": false, "cross": "cross", "crossColor": "ece6d8", "mailTo": ""}
	var s = _read("settings")
	if s is Dictionary: settings.merge(s, true)
	save = save0()
	var d = _read("save")
	if d is Dictionary: save.merge(d, true)
	fix_save()

## where the computer's quality ladder last settled (the browser game keeps it as yard07.gfxlvl); -1 when never
func level_saved() -> int:
	var v = _read("gfxlvl")
	return int(v) if (v is float or v is int) else -1
func save_level(l: int) -> void:
	_write("gfxlvl", l)

func _read(key: String):
	var text := ""
	if OS.has_feature("web"): text = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('yarr07.godot.%s')||''}catch(e){return ''}})()" % key))
	elif FileAccess.file_exists("user://%s.json" % key): text = FileAccess.get_file_as_string("user://%s.json" % key)
	return JSON.parse_string(text) if text != "" else null

func _write(key: String, value) -> void:
	var text := JSON.stringify(value)
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
	save.v = 4

func persist() -> void:
	if money_lock == null and ivory_lock == null and own_lock == null: _write("save", save); return
	var o: Dictionary = save.duplicate(true)
	if money_lock != null: o.money = maxi(0, mini(save.money, money_lock))
	if ivory_lock != null: o.items.ivory = maxi(0, mini(save.items.ivory, ivory_lock))
	if own_lock != null: o.owned = save.owned.filter(func(id): return own_lock.has(id))
	_write("save", o)

func persist_settings() -> void:
	_write("settings", settings)

## every stage can be played from the start; NEXT only says which stages follow on the stage tree (the browser game opens them in turn)
func stage_open(n: int) -> bool:
	return STAGE_TAG.has(n)

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
