class_name Animals
extends RefCounted
## The animals of stages 3 and 3-1: what each kind is, how it fights, what it does to you (bleeding, fear, being tossed), riding them,
## the giant gorilla and its minions, and the siege of the watchtower. Ported from src/07c_animals.js, 07g_beasts.js, 07f_kong.js and 07i_safari.js.

# mode: prey flees, cat hunts on sight inside aggroR, herd charges together once provoked, territorial charges when you come close
const ANIMALS := {
	"zebra": {"name": "얼룩말", "hp": 150, "speed": 3.5, "run": 15.0, "r": 0.55, "h": 1.5, "dmg": 0.0, "money": 1000, "mode": "prey", "aggroR": 0.0, "reach": 1.9, "turn": 5.0, "roar": "bray"},
	"puma": {"name": "퓨마", "hp": 170, "speed": 3.5, "run": 13.5, "r": 0.45, "h": 0.95, "dmg": 24.0, "money": 1500, "mode": "cat", "aggroR": 36.0, "reach": 1.7, "turn": 8.0, "roar": "cat", "pounce": true},
	"lion": {"name": "사자", "hp": 280, "speed": 3.5, "run": 14.5, "r": 0.6, "h": 1.25, "dmg": 32.0, "money": 2000, "mode": "cat", "aggroR": 75.0, "reach": 2.0, "turn": 7.0, "roar": "cat", "pounce": true},
	"tiger": {"name": "호랑이", "hp": 320, "speed": 3.5, "run": 15.0, "r": 0.62, "h": 1.2, "dmg": 120.0, "money": 2200, "mode": "cat", "aggroR": 75.0, "reach": 2.1, "turn": 7.0, "roar": "cat", "pounce": true},
	"buffalo": {"name": "물소", "hp": 440, "speed": 2.4, "run": 12.5, "r": 0.85, "h": 1.7, "dmg": 50.0, "money": 2000, "mode": "herd", "aggroR": 9.0, "reach": 2.4, "turn": 3.0, "roar": "grunt", "charge": true},
	"gorilla": {"name": "로랜드고릴라", "hp": 400, "speed": 1.4, "run": 13.5, "r": 0.7, "h": 1.75, "dmg": 62.0, "money": 2500, "mode": "gorilla", "aggroR": 0.0, "reach": 2.1, "turn": 7.0, "roar": "beat"},
	"hippo": {"name": "하마", "hp": 620, "speed": 2.0, "run": 10.5, "r": 1.1, "h": 1.6, "dmg": 50.0, "money": 2500, "mode": "territorial", "aggroR": 26.0, "reach": 2.6, "turn": 2.6, "roar": "grunt", "charge": true},
	"rhino": {"name": "코뿔소", "hp": 720, "speed": 2.0, "run": 13.5, "r": 1.0, "h": 1.9, "dmg": 100.0, "money": 3000, "mode": "territorial", "aggroR": 30.0, "reach": 2.6, "turn": 2.4, "roar": "grunt", "charge": true},
	"elephant": {"name": "코끼리", "hp": 12000, "speed": 2.0, "run": 10.5, "r": 1.7, "h": 3.4, "dmg": 72.0, "money": 4000, "mode": "territorial", "aggroR": 15.0, "reach": 3.4, "turn": 1.8, "roar": "trumpet", "charge": true},
	"cheetah": {"name": "치타", "hp": 160, "speed": 4.0, "run": 19.0, "r": 0.45, "h": 1.0, "dmg": 120.0, "money": 1800, "mode": "cat", "aggroR": 60.0, "reach": 1.8, "turn": 9.0, "roar": "cat", "pounce": true},
	"giraffe": {"name": "기린", "hp": 5200, "speed": 2.5, "run": 11.5, "r": 0.75, "h": 4.6, "dmg": 48.0, "money": 2200, "mode": "territorial", "aggroR": 20.0, "reach": 2.6, "turn": 3.0, "roar": "grunt", "headX": 10.0},
	"lionM": {"name": "숫사자", "hp": 340, "speed": 3.5, "run": 15.0, "r": 0.64, "h": 1.35, "dmg": 50.0, "money": 2400, "mode": "cat", "aggroR": 75.0, "reach": 2.1, "turn": 7.0, "roar": "cat", "pounce": true},
}
const NECK := [2.55, 0.38]   # where a giraffe's neck pivots (height, forward)
# the outline of each body from above at scale 1 (x0, x1, z0, z1), measured in the browser game, and how hard it shoves
const FEET := {"zebra": [-0.371726, 0.371726, -1.184722, 1.679817], "buffalo": [-0.71378, 0.71378, -1.344457, 1.61], "hippo": [-0.73245, 0.73245, -1.255375, 2.43], "rhino": [-0.638, 0.638, -1.255375, 2.180825],
	"cheetah": [-0.283983, 0.283983, -1.86, 1.36], "giraffe": [-0.469219, 0.469219, -1.192092, 2.16], "tiger": [-0.380696, 0.380696, -1.860446, 1.5234], "lionM": [-0.527715, 0.527715, -1.94, 1.5512],
	"elephant": [-1.02435, 1.02435, -1.871198, 2.778967], "gorilla": [-0.93, 0.93, -0.528778, 1.198176], "puma": [-0.3, 0.3, -1.3, 1.1], "lion": [-0.45, 0.45, -1.8, 1.45]}
const MASS := {"zebra": 2.5, "puma": 1.4, "lion": 2.2, "tiger": 2.4, "buffalo": 4.0, "gorilla": 3.0, "hippo": 7.0, "rhino": 7.0, "elephant": 12.0, "cheetah": 1.5, "giraffe": 5.0, "lionM": 2.5}
# where bullets land: [x, y, z, radius, weak, multiplier]
const HITS := {
	"zebra": [[0, 1.85, 1.35, 0.25, true], [0, 1.1, 0.5, 0.45], [0, 1.1, -0.5, 0.45], [0, 0.45, 0, 0.4, false, 0.7]],
	"cheetah": [[0, 1.06, 1.0, 0.22, true], [0, 0.88, 0.4, 0.34], [0, 0.88, -0.45, 0.34], [0, 0.38, 0, 0.3, false, 0.7]],
	"giraffe": [[0, 4.6, 1.6, 0.32, true], [0, 3.55, 1.0, 0.36], [0, 2.4, 0.5, 0.55], [0, 2.35, -0.5, 0.55], [0, 1.0, 0, 0.45, false, 0.7]],
	"buffalo": [[0, 1.15, 1.3, 0.34, true], [0, 1.25, 0.55, 0.6], [0, 1.2, -0.6, 0.58], [0, 0.45, 0, 0.45, false, 0.7]],
	"hippo": [[0, 1.0, 1.55, 0.45, true], [0, 1.05, 0.55, 0.72], [0, 1.0, -0.6, 0.72], [0, 0.4, 0, 0.5, false, 0.7]],
	"rhino": [[0, 1.1, 1.6, 0.38, true], [0, 1.3, 0.5, 0.7], [0, 1.25, -0.6, 0.68], [0, 0.45, 0, 0.5, false, 0.7]],
	"elephant": [[0, 2.9, 1.9, 0.6, true], [0, 2.4, 0.7, 1.1], [0, 2.4, -0.8, 1.1], [0, 0.8, 0, 0.8, false, 0.7]],
	"gorilla": [[0, 1.42, 0.55, 0.27, true], [0, 1.15, 0.25, 0.6], [0, 0.82, -0.12, 0.5], [0, 0.36, -0.1, 0.38, false, 0.7]],
}
const CAT_S := {"puma": 0.72, "lion": 1.0, "lionM": 1.08, "tiger": 1.06}
# seat: where you sit, how fast it goes walking and running, how quickly it turns
const SEAT := {"zebra": {"tier": 1, "y": 1.62, "z": -0.35, "walk": 6.0, "run": 12.5, "turn": 7.0, "name": "얼룩말"},
	"giraffe": {"tier": 2, "y": 4.35, "z": 0.8, "walk": 5.0, "run": 10.0, "turn": 4.5, "name": "기린"},
	"elephant": {"tier": 3, "y": 3.45, "z": 1.05, "walk": 4.5, "run": 8.2, "turn": 3.0, "name": "코끼리"}}
const BEAST_DMG := 0.5   # the animals hit half as hard as they used to; the giant gorilla and its minions are left as they were
const BLEED_DPS := 5.0
const KONG := {"boss": {"run": 7.6, "charge": 24.0, "chargeT": 1.15, "windup": 0.32, "recover": 0.12, "punch": 500.0, "chargeDmg": 300.0, "stun": 3.0, "swing": 0.62, "chargeCd": [2.2, 3.6], "reach": 1.9},
	"minion": {"run": 6.0, "charge": 12.0, "chargeT": 1.4, "windup": 0.8, "recover": 1.7, "punch": 125.0, "chargeDmg": 75.0, "stun": 1.0, "swing": 0.72, "chargeCd": [5.0, 8.0], "reach": 0.75}}
const SLAM_R := 5.5
const SUMMON_MAX := 4
const MINIONS_AT := 7

var en: Enemies
var player: Player
var game = null          # Game
var world: World
var fx: Fx = null
# bleeding: every wound takes 5 a second for 10 seconds; a fresh wound adds one more and restarts the clock
var bleed_n := 0; var bleed_t := 0.0; var bleed_acc := 0.0; var bleed_beasts: Array = []
# a tiger's roar: for one second your legs carry you away from it
var roar_cd := 0.0       # the lions take turns
# riding
var m: Enemies.Foe = null   # the animal under you
var tier := 0
var rvx := 0.0; var rvz := 0.0; var ease := 1.0; var ride_from := Vector3.ZERO
var target: Enemies.Foe = null; var find_t := 0.0
# a rhino's toss
var toss_v := 0.0; var toss_n := 0
var ring: MeshInstance3D = null; var ring_on := false

func rnd(a: float, b: float) -> float: return randf_range(a, b)
func _feed(text: String) -> void:
	if game: game.say_feed(text)

func reset() -> void:
	bleed_n = 0; bleed_t = 0.0; bleed_acc = 0.0; bleed_beasts.clear(); roar_cd = 0.0
	m = null; tier = 0; rvx = 0.0; rvz = 0.0; ease = 1.0; target = null; toss_v = 0.0; toss_n = 0
	player.fear_t = 0.0; player.toss_on = false
	unwarn()

# ---------------- building one ----------------
func _mesh(parent: Node3D, at: Vector3, parts: Array, key: String) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	if parts.is_empty(): return n
	var mi := MeshInstance3D.new(); mi.mesh = en._box_mesh(key, parts); mi.material_override = en._mat; n.add_child(mi); return n   # one mesh per kind and part, shared

# ---------------- the browser game's AnimalKit: pictures, parts, pivots, legs ----------------
static var _tx := {}
static func _corners(img: Image) -> void:   # the white corners plain parts take their colour from
	Gfx.frect(img, 242, 114, 14, 14, Color.WHITE); Gfx.frect(img, 242, 0, 14, 14, Color.WHITE)
## stripes: wobbly ink bands across a base (tiger, zebra)
static func _stripe_tex(base: String, ink: String, wobble: float) -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8); img.fill(Color(base)); var x := 6.0
	while x < 246.0:
		var pts := PackedVector2Array([Vector2(x, 0)]); var y := 0.0
		while y <= 128.0: pts.push_back(Vector2(x + sin(y * 0.08 + x) * wobble, y)); y += 16.0
		y = 128.0
		while y >= 0.0: pts.push_back(Vector2(x + randf_range(3, 6) + sin(y * 0.08 + x) * wobble, y)); y -= 16.0
		Gfx.fpoly(img, pts, Color(ink)); x += randf_range(10, 17)
	_corners(img); return Gfx.tex(img)
## spots (cheetah)
static func _spots_tex(base: String, ink: String) -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8); img.fill(Color(base))
	for i in 280: Gfx.fellipse(img, randf() * 240, randf() * 128, randf_range(2, 4.5), randf_range(2, 4), randf_range(0, 3), Color(ink))
	_corners(img); return Gfx.tex(img)
## patches parted by pale lines (giraffe)
static func _patches_tex(base: String, line: String) -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8); img.fill(Color(line)); var x := 0.0
	while x < 240.0:
		var y := 0.0
		while y < 128.0:
			var ox := randf_range(-3, 3); var oy := randf_range(-3, 3)
			Gfx.fpoly(img, PackedVector2Array([Vector2(x + 3 + ox, y + 3 + oy), Vector2(x + 19 + ox, y + 2 + oy), Vector2(x + 20 + ox, y + 17 + oy), Vector2(x + 2 + ox, y + 18 + oy)]), Color(base)); y += 20.0
		x += 22.0
	_corners(img); return Gfx.tex(img)
static func kit_tex(type: String) -> ImageTexture:
	if not _tx.has(type):
		match type:
			"tiger": _tx[type] = _stripe_tex("d9822b", "1c1410", 4)
			"zebra": _tx[type] = _stripe_tex("f0ede4", "151515", 6)
			"cheetah": _tx[type] = _spots_tex("d9a85a", "1a1510")
			"giraffe": _tx[type] = _patches_tex("b8692a", "efe2c4")
			_: return null
	return _tx[type]

## [sx, sy, sz, x, y, z, colour, (rotation), (sphere), (striped)] as AnimalKit's add() takes them, to a kit part
static func _p(a: Array, plain: bool) -> Array:
	return [a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7] if a.size() > 7 else null, plain and not (a.size() > 9 and a[9]), a.size() > 8 and a[8]]
## a kind's model, part for part as the browser game's AnimalKit.quad: the body, parts on pivots of their own (a head, a jaw),
## and the legs [x, z, length, thickness, colour]
static func quad_spec(type: String, mane := false) -> Dictionary:
	var plain: bool = type in ["tiger", "zebra", "cheetah", "giraffe"]
	var P := []; var subs := []; var legs := []
	match type:
		"zebra":
			P = [[0.66, 0.84, 1.95, 0, 1.08, 0, "ffffff", null, true, true], [0.26, 0.75, 0.32, 0, 1.55, 0.95, "ffffff", [-0.6, 0, 0], false, true],
				[0.26, 0.28, 0.6, 0, 1.85, 1.3, "ffffff", [0.35, 0, 0], false, true], [0.08, 0.5, 0.5, 0, 1.75, 1.0, "151515", [-0.6, 0, 0]],
				[0.06, 0.55, 0.06, 0, 1.0, -1.0, "151515", [0.4, 0, 0]], [0.07, 0.16, 0.06, -0.1, 2.05, 1.2, "151515"], [0.07, 0.16, 0.06, 0.1, 2.05, 1.2, "151515"]]
			for q in [[0.2, 0.75], [-0.2, 0.75], [0.2, -0.75], [-0.2, -0.75]]: legs.push_back([q[0], q[1], 0.75, 0.13, "f0ede4"])
		"cheetah":
			P = [[0.48, 0.56, 1.7, 0, 0.88, 0, "ffffff", null, true, true], [0.34, 0.32, 0.38, 0, 1.06, 0.98, "ffffff", null, true, true], [0.18, 0.12, 0.14, 0, 0.98, 1.2, "e8d2a8"],
				[0.03, 0.16, 0.02, -0.07, 1.0, 1.17, "151515"], [0.03, 0.16, 0.02, 0.07, 1.0, 1.17, "151515"],
				[0.08, 0.08, 0.05, -0.12, 1.24, 0.94, "ffffff", null, false, true], [0.08, 0.08, 0.05, 0.12, 1.24, 0.94, "ffffff", null, false, true],
				[0.06, 0.06, 1.1, 0, 0.8, -1.25, "ffffff", [-0.45, 0, 0], false, true], [0.07, 0.07, 0.14, 0, 0.42, -1.74, "151515"]]
			subs.push_back({"name": "jaw", "at": Vector3(0, 0.95, 1.08), "P": [[0.15, 0.05, 0.22, 0, -0.03, 0.12, "e8d2a8"], [0.13, 0.02, 0.2, 0, 0.0, 0.11, "7a2626"], [0.025, 0.05, 0.025, -0.05, 0.02, 0.21, "f4efe2"], [0.025, 0.05, 0.025, 0.05, 0.02, 0.21, "f4efe2"]]})
			for q in [[0.17, 0.62], [-0.17, 0.62], [0.17, -0.62], [-0.17, -0.62]]: legs.push_back([q[0], q[1], 0.74, 0.11, "d8a55c"])
		"giraffe":   # the neck and head hang from a pivot where the neck meets the shoulders
			P = [[0.86, 0.95, 1.85, 0, 2.35, 0, "ffffff", [0.12, 0, 0], true, true], [0.05, 0.8, 0.05, 0, 2.1, -1.0, "6a3a18", [0.3, 0, 0]]]
			var NY: float = NECK[0]; var NZ: float = NECK[1]
			var nk := [[0.34, 2.3, 0.42, 0, 3.55, 0.95, "ffffff", [0.52, 0, 0], false, true], [0.1, 2.0, 0.08, 0, 3.62, 0.74, "6a3a18", [0.52, 0, 0]],
				[0.3, 0.32, 0.7, 0, 4.62, 1.62, "ffffff", [0.25, 0, 0], false, true], [0.2, 0.2, 0.26, 0, 4.5, 1.98, "d8c4a0"],
				[0.05, 0.22, 0.05, -0.08, 4.88, 1.45, "5a3a20"], [0.05, 0.22, 0.05, 0.08, 4.88, 1.45, "5a3a20"],
				[0.12, 0.06, 0.18, -0.2, 4.75, 1.45, "ffffff", null, false, true], [0.12, 0.06, 0.18, 0.2, 4.75, 1.45, "ffffff", null, false, true]]
			for q in nk: q[4] -= NY; q[5] -= NZ
			subs.push_back({"name": "head", "at": Vector3(0, NY, NZ), "P": nk})
			for q in [[0.26, 0.68, 1.95], [-0.26, 0.68, 1.95], [0.26, -0.68, 1.95 * 0.95], [-0.26, -0.68, 1.95 * 0.95]]: legs.push_back([q[0], q[1], q[2], 0.15, "e9d9b8"])
		"puma", "lion", "tiger", "lionM":
			var sc: float = {"puma": 0.72, "lion": 1.0, "lionM": 1.08, "tiger": 1.06}[type]; var col := "a0784a" if type == "puma" else ("ffffff" if type == "tiger" else "c49a5c")
			var st := type == "tiger"; var mc := "efe3cf" if st else "d8b98a"
			P = [[0.64 * sc, 0.72 * sc, 1.85 * sc, 0, 0.9 * sc, 0, col, null, true, st], [0.46 * sc, 0.44 * sc, 0.5 * sc, 0, 1.1 * sc, 1.0 * sc, col, null, true, st],
				[0.22 * sc, 0.15 * sc, 0.16 * sc, 0, 1.0 * sc, 1.27 * sc, mc], [0.03 * sc, 0.08 * sc, 0.03 * sc, -0.07 * sc, 0.9 * sc, 1.31 * sc, "f4efe2"], [0.03 * sc, 0.08 * sc, 0.03 * sc, 0.07 * sc, 0.9 * sc, 1.31 * sc, "f4efe2"],
				[0.1 * sc, 0.1 * sc, 0.05 * sc, -0.14 * sc, 1.32 * sc, 0.98 * sc, col, null, false, st], [0.1 * sc, 0.1 * sc, 0.05 * sc, 0.14 * sc, 1.32 * sc, 0.98 * sc, col, null, false, st],
				[0.08 * sc, 0.08 * sc, 1.0 * sc, 0, 0.85 * sc, -1.25 * sc, col, [-0.5, 0, 0], false, st]]
			subs.push_back({"name": "jaw", "at": Vector3(0, 0.97 * sc, 1.08 * sc), "P": [[0.2 * sc, 0.07 * sc, 0.3 * sc, 0, -0.04 * sc, 0.16 * sc, mc], [0.17 * sc, 0.025 * sc, 0.26 * sc, 0, 0, 0.14 * sc, "7a2626"],
				[0.03 * sc, 0.07 * sc, 0.03 * sc, -0.07 * sc, 0.03 * sc, 0.27 * sc, "f4efe2"], [0.03 * sc, 0.07 * sc, 0.03 * sc, 0.07 * sc, 0.03 * sc, 0.27 * sc, "f4efe2"]]})
			if type == "lion" and mane: P.append_array([[0.78, 0.8, 0.5, 0, 1.1, 0.82, "5a3a1e", null, true], [0.14, 0.14, 0.18, 0, 0.6, -1.7, "3a2412"]])
			if type == "lionM": P.append_array([[0.98, 1.0, 0.66, 0, 1.18 * sc, 0.84 * sc, "4e3018", null, true], [0.5, 0.4, 0.3, 0, 0.82 * sc, 0.9 * sc, "4e3018", null, true], [0.14, 0.14, 0.18, 0, 0.62, -1.8, "3a2412"]])
			if st: P.push_back([0.3, 0.2, 1.4, 0, 0.6, 0, "efe3cf"])   # the pale belly
			for q in [[0.2, 0.62], [-0.2, 0.62], [0.2, -0.62], [-0.2, -0.62]]: legs.push_back([q[0] * sc, q[1] * sc, 0.62 * sc, 0.17 * sc, col])
		"buffalo":
			P = [[0.95, 1.05, 2.2, 0, 1.2, 0, "2a2622", null, true], [0.5, 0.55, 0.62, 0, 1.15, 1.25, "24201c"], [0.95, 0.16, 0.22, 0, 1.52, 1.18, "8a8070"],
				[0.16, 0.36, 0.16, -0.52, 1.38, 1.18, "8a8070", [0, 0, 0.4]], [0.16, 0.36, 0.16, 0.52, 1.38, 1.18, "8a8070", [0, 0, -0.4]], [0.06, 0.6, 0.06, 0, 1.25, -1.15, "1a1714", [0.4, 0, 0]]]
			for q in [[0.3, 0.75], [-0.3, 0.75], [0.3, -0.75], [-0.3, -0.75]]: legs.push_back([q[0], q[1], 0.78, 0.2, "24201c"])
		"hippo":   # the head swings up and the jaw drops for the gape: pink inside, four big tusks
			P = [[1.4, 1.2, 2.6, 0, 1.0, 0, "5e5457", null, true], [0.78, 0.64, 0.6, 0, 1.02, 1.08, "5a5053", null, true]]
			subs.push_back({"name": "head", "at": Vector3(0, 1.0, 1.15), "P": [[0.95, 0.62, 0.95, 0, 0.1, 0.32, "5a5053", null, true], [0.92, 0.3, 0.66, 0, 0.02, 0.86, "6f6064"], [0.8, 0.04, 0.56, 0, -0.13, 0.84, "b8606a"],
				[0.1, 0.24, 0.1, -0.3, -0.2, 1.08, "efe8d8"], [0.1, 0.24, 0.1, 0.3, -0.2, 1.08, "efe8d8"], [0.12, 0.14, 0.1, -0.3, 0.44, 0.12, "5a4a52"], [0.12, 0.14, 0.1, 0.3, 0.44, 0.12, "5a4a52"],
				[0.14, 0.1, 0.12, -0.24, 0.36, 0.42, "4a3e44"], [0.14, 0.1, 0.12, 0.24, 0.36, 0.42, "4a3e44"], [0.1, 0.06, 0.06, -0.18, 0.18, 1.2, "3a3036"], [0.1, 0.06, 0.06, 0.18, 0.18, 1.2, "3a3036"]]})
			subs.push_back({"name": "jaw", "at": Vector3(0, 0.86, 1.2), "P": [[0.9, 0.3, 0.98, 0, -0.1, 0.55, "6a5c60"], [0.76, 0.04, 0.8, 0, 0.06, 0.52, "c0707a"], [0.11, 0.34, 0.11, -0.32, 0.16, 0.94, "efe8d8"], [0.11, 0.34, 0.11, 0.32, 0.16, 0.94, "efe8d8"]]})
			for q in [[0.45, 0.85], [-0.45, 0.85], [0.45, -0.85], [-0.45, -0.85]]: legs.push_back([q[0], q[1], 0.55, 0.34, "5f4f57"])
		"rhino":   # the head, both horns on it, hangs from the neck so it can drop for the charge and flick up
			P = [[1.2, 1.25, 2.6, 0, 1.25, 0, "7a7774", null, true]]
			subs.push_back({"name": "head", "at": Vector3(0, 1.18, 1.05), "P": [[0.62, 0.62, 0.95, 0, -0.13, 0.45, "73716d"], [0.18, 0.55, 0.18, 0, 0.27, 0.87, "c9c2b2", [0.5, 0, 0]],
				[0.13, 0.32, 0.13, 0, 0.22, 0.57, "c9c2b2", [0.3, 0, 0]], [0.1, 0.18, 0.08, -0.22, 0.24, 0.07, "7a7873"], [0.1, 0.18, 0.08, 0.22, 0.24, 0.07, "7a7873"]]})
			for q in [[0.42, 0.85], [-0.42, 0.85], [0.42, -0.85], [-0.42, -0.85]]: legs.push_back([q[0], q[1], 0.75, 0.32, "7d7b77"])
		"elephant":
			P = [[1.9, 2.1, 3.2, 0, 2.4, 0, "77746f", null, true], [1.2, 1.25, 1.1, 0, 2.85, 1.75, "72706b", null, true],
				[0.14, 1.3, 1.1, -0.72, 2.7, 1.45, "6a6863", [0, -0.35, 0]], [0.14, 1.3, 1.1, 0.72, 2.7, 1.45, "6a6863", [0, 0.35, 0]],
				[0.34, 0.8, 0.34, 0, 2.15, 2.3, "6f6c68", [0.25, 0, 0]], [0.28, 0.7, 0.28, 0, 1.45, 2.45, "6f6c68"], [0.22, 0.5, 0.22, 0, 0.95, 2.55, "6f6c68", [-0.3, 0, 0]],
				[0.12, 0.12, 0.75, -0.32, 2.2, 2.35, "efe8d8", [0.5, 0, 0]], [0.12, 0.12, 0.75, 0.32, 2.2, 2.35, "efe8d8", [0.5, 0, 0]], [0.08, 0.9, 0.08, 0, 2.3, -1.65, "7a7773", [0.3, 0, 0]]]
			for q in [[0.6, 1.1], [-0.6, 1.1], [0.6, -1.1], [-0.6, -1.1]]: legs.push_back([q[0], q[1], 1.45, 0.58, "6f6c68"])
		_:   # gorilla: knuckle-walking, long arms in front, a silver back
			P = [[0.9, 1.0, 1.05, 0, 1.15, 0, "1e1d1f", [-0.55, 0, 0], true], [0.7, 0.35, 0.6, 0, 1.45, -0.15, "8f8f8f", [-0.55, 0, 0]],
				[0.42, 0.44, 0.4, 0, 1.7, 0.55, "1e1d1f"], [0.3, 0.22, 0.12, 0, 1.64, 0.76, "3a3532"], [0.36, 0.1, 0.12, 0, 1.86, 0.62, "151416"]]
			legs = [[0.42, 0.42, 1.05, 0.26, "1e1d1f"], [-0.42, 0.42, 1.05, 0.26, "1e1d1f"], [0.25, -0.35, 0.62, 0.26, "1e1d1f"], [-0.25, -0.35, 0.62, 0.26, "1e1d1f"]]
	var conv := func(list: Array) -> Array: return list.map(func(a): return _p(a, plain))
	for sb in subs: sb.P = conv.call(sb.P)
	return {"P": conv.call(P), "subs": subs, "legs": legs, "plain": plain, "hoof": "6f6c68" if type == "elephant" else "2a2420"}

# ---------------- the browser game's KongKit: a gorilla on a rig of joints, posed every frame ----------------
const KNUCKLE := {"lean": 0.6, "twist": 0.0, "head": -0.35, "aLx": -1.1, "aLy": 0.0, "aRx": -1.1, "aRy": 0.0, "fL": 0.15, "fR": 0.15, "lL": 0.0, "lR": 0.0, "sL": 0.0, "sR": 0.0, "y": 0.0}
const KONG_HIP := 0.62
var _kong_mat: StandardMaterial3D = null
## a gorilla's build: a huge chest and shoulders, a silver saddle, long thick arms, short legs, the head sunk between the shoulders
func kong_build(e: Enemies.Foe, boss: bool) -> void:
	var fur := "1d1c1e"; var dark := "141315"; var skin := "37312e"; var silver := "9a9a9c" if boss else "4b4a4c"; var eye := "d33a1a" if boss else "c08a2a"
	if _kong_mat == null: _kong_mat = StandardMaterial3D.new(); _kong_mat.vertex_color_use_as_albedo = true; _kong_mat.roughness = 0.88
	var key := "kong_" + ("boss" if boss else "small")
	var mesh := func(parent: Node3D, k2: String, list: Array) -> void:
		var mi := MeshInstance3D.new(); var kk := key + "_" + k2
		if not en._meshes.has(kk): en._meshes[kk] = Gfx.kit_mesh(list)
		mi.mesh = en._meshes[kk]; mi.material_override = _kong_mat; parent.add_child(mi)
	var grp := func(parent: Node3D, at: Vector3, yxz := false) -> Node3D:
		var n := Node3D.new(); n.position = at; parent.add_child(n)
		if yxz: n.rotation_order = EULER_ORDER_YXZ
		return n
	var hips: Node3D = grp.call(e.g, Vector3(0, KONG_HIP, -0.1)); var torso: Node3D = grp.call(hips, Vector3.ZERO, true)
	var body: Node3D = grp.call(torso, Vector3.ZERO)
	mesh.call(body, "body", [[1.12, 0.86, 0.72, 0, 0.5, 0.05, fur], [0.86, 0.46, 0.62, 0, 0.1, 0.07, fur], [1.3, 0.38, 0.7, 0, 0.84, 0.02, fur],
		[0.82, 0.56, 0.08, 0, 0.46, -0.33, silver], [0.66, 0.4, 0.06, 0, 0.54, 0.43, skin], [0.5, 0.3, 0.06, 0, 0.12, 0.39, skin]])
	var chest: Node3D = grp.call(torso, Vector3(0, 0.5, 0.1))
	var head: Node3D = grp.call(torso, Vector3(0, 0.95, 0.26))
	mesh.call(head, "head", [[0.48, 0.46, 0.46, 0, 0.1, 0, fur], [0.22, 0.18, 0.34, 0, 0.37, -0.05, fur], [0.46, 0.1, 0.11, 0, 0.21, 0.22, dark],
		[0.34, 0.26, 0.17, 0, -0.02, 0.24, skin], [0.32, 0.1, 0.19, 0, -0.16, 0.19, skin], [0.06, 0.04, 0.02, -0.1, 0.12, 0.282, eye], [0.06, 0.04, 0.02, 0.1, 0.12, 0.282, eye],
		[0.12, 0.05, 0.03, 0, 0.0, 0.33, "201c1b"]])
	var head_c: Node3D = grp.call(head, Vector3(0, 0.1, 0.05))
	var rig := {"hips": hips, "torso": torso, "head": head, "chest": chest}
	for sx in [-1.0, 1.0]:
		var a: Node3D = grp.call(torso, Vector3(sx * 0.68, 0.74, 0.08), true); mesh.call(a, "arm", [[0.38, 0.66, 0.38, 0, -0.3, 0, fur]])
		var f: Node3D = grp.call(a, Vector3(0, -0.6, 0)); mesh.call(f, "fore", [[0.33, 0.6, 0.33, 0, -0.28, 0, fur], [0.4, 0.28, 0.42, 0, -0.62, 0.02, skin]])
		var l: Node3D = grp.call(hips, Vector3(sx * 0.3, 0, -0.02)); mesh.call(l, "leg", [[0.36, 0.38, 0.38, 0, -0.16, 0.02, fur]])
		var sh: Node3D = grp.call(l, Vector3(0, -0.32, 0.05)); mesh.call(sh, "shin", [[0.32, 0.26, 0.32, 0, -0.12, 0, fur], [0.36, 0.08, 0.48, 0, -0.27, 0.1, skin]])
		var sd := "L" if sx < 0 else "R"; rig["arm" + sd] = a; rig["fore" + sd] = f; rig["leg" + sd] = l; rig["shin" + sd] = sh
	e.rig = rig; e.body = body; e.legs.clear(); kong_pose(e, KNUCKLE, 1.0)   # (the footprint is taken in this pose)
	# the head and chest hit spheres ride on the body (the browser game moves them with the pose every frame)
	e.parts = [{"o": Vector3(0, 1.42, 0.55), "r": 0.27, "mult": 1.0, "weak": true, "bomb": false, "node": head_c}, {"o": Vector3(0, 1.15, 0.25), "r": 0.6, "mult": 1.0, "weak": false, "bomb": false, "node": chest},
		{"o": Vector3(0, 0.82, -0.12), "r": 0.5, "mult": 1.0, "weak": false, "bomb": false}, {"o": Vector3(0, 0.36, -0.1), "r": 0.38, "mult": 0.7, "weak": false, "bomb": false}]

## ease the rig toward a pose (k: how far this frame)
func kong_pose(e: Enemies.Foe, P: Dictionary, kk: float) -> void:
	var R: Dictionary = e.rig
	if not R.has("pose"): R.pose = P.duplicate()
	var c: Dictionary = R.pose
	for key in P: c[key] += (P[key] - c[key]) * kk
	R.torso.rotation.x = c.lean; R.torso.rotation.y = c.twist; R.head.rotation.x = c.head
	R.armL.rotation.x = c.aLx; R.armL.rotation.y = c.aLy; R.armR.rotation.x = c.aRx; R.armR.rotation.y = c.aRy
	R.foreL.rotation.x = c.fL; R.foreR.rotation.x = c.fR
	R.legL.rotation.x = c.lL; R.legR.rotation.x = c.lR; R.shinL.rotation.x = c.sL; R.shinR.rotation.x = c.sR
	R.hips.position.y = KONG_HIP + c.y

## the knuckle-walk: arms and legs swinging against each other, faster at a gallop
static func kong_gait(P: Dictionary, k: Dictionary, sp: float, dt: float, gallop: bool, sc: float) -> void:
	var g := minf(1.0, sp / 5.0)
	k.phase = float(k.get("phase", 0.0)) + dt * (1.6 + sp * (1.0 if gallop else 0.85) / sqrt(sc))
	var s := sin(k.phase); var c := cos(k.phase); var amp := 0.75 if gallop else 0.55
	P.aLx += s * amp * g; P.aRx -= s * amp * g; P.lL = -s * 0.5 * g; P.lR = s * 0.5 * g
	P.sL = maxf(0.0, c) * 0.6 * g; P.sR = maxf(0.0, -c) * 0.6 * g; P.y = absf(s) * 0.05 * g; P.twist = s * 0.08 * g

## beating the chest, fists in turn
static func beat_pose(P: Dictionary, k: Dictionary) -> void:
	var L := sin(float(k.t) * 40.0) > 0.0
	P.lean = -0.05; P.head = -0.35; P.lL = -0.25; P.lR = -0.25; P.sL = 0.4; P.sR = 0.4; P.y = -0.06
	P.aLx = -0.9; P.aLy = 1.1 if L else 0.55; P.fL = -1.85 if L else -1.3
	P.aRx = -0.9; P.aRy = -0.55 if L else -1.1; P.fR = -1.3 if L else -1.85

## a haymaker's pose, side 1 the right arm (the browser game's punch and spunch)
static func punch_pose(P: Dictionary, side: int, u: float) -> float:
	var A := "aR" if side > 0 else "aL"; var O := "aL" if side > 0 else "aR"
	P.lean = 0.32; P.head = -0.25; P[O + "x"] = -1.15; P[O + "y"] = 0.0
	if u < 0.38: P[A + "x"] = -2.0; P[A + "y"] = side * 1.7; P.twist = -side * 0.45; return 16.0
	if u < 0.62: var w := (u - 0.38) / 0.24; P[A + "x"] = -1.55; P[A + "y"] = side * (1.7 - 2.3 * w); P.twist = side * (-0.45 + 0.9 * w); return 40.0
	P[A + "x"] = -1.3; P[A + "y"] = -side * 0.5; P.twist = side * 0.4; return 12.0

var _kit_mats := {}
func _kit(parent: Node3D, at: Vector3, parts: Array, key: String, mat: Material) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	if not en._meshes.has(key): en._meshes[key] = Gfx.kit_mesh(parts)
	var mi := MeshInstance3D.new(); mi.mesh = en._meshes[key]; mi.material_override = mat; n.add_child(mi); return n

func build(e: Enemies.Foe, type: String, opts: Dictionary) -> void:
	e.animal = true; e.kong = opts.get("kong", false); e.minion = opts.get("minion", false)
	e.g = Node3D.new(); e.g.rotation_order = EULER_ORDER_YXZ; en.add_child(e.g)
	if opts.get("kong", false): kong_build(e, opts.get("boss", false)); _bar(e); return
	var mane := type == "lion" and randf() < 0.55   # (some lions have a mane)
	var spec := quad_spec(type, mane); var tex := kit_tex(type)
	var mat: Material = en._mat
	if tex != null:   # (vertex colours times the picture)
		if not _kit_mats.has(type): var km := Gfx.std(Color.WHITE, 0.85, 0.0, tex); km.vertex_color_use_as_albedo = true; _kit_mats[type] = km
		mat = _kit_mats[type]
	e.body = _kit(e.g, Vector3.ZERO, spec.P, "kit_%s%s" % [type, "_mane" if mane else ""], mat)
	for sb in spec.subs:
		var piv := _kit(e.body, sb.at, sb.P, "kit_%s_%s" % [type, sb.name], mat)
		if sb.name == "head": e.head = piv
		else: e.jaw = piv
	e.legs.clear()
	for q in spec.legs:   # each leg on a pivot at the hip, its hoof at the foot
		var L: float = q[2]; var th: float = q[3]
		e.legs.push_back(_kit(e.g, Vector3(q[0], L, q[1]), [[th, L, th * 1.1, 0, -L / 2, 0, q[4], null, false, false], [th * 1.05, L * 0.12, th * 1.25, 0, -L + L * 0.06, th * 0.08, spec.hoof, null, spec.plain, false]],
			"kit_%s_leg_%.3f_%.3f_%s" % [type, L, th, q[4]], mat))
	var hits: Array = HITS.get(type, [])
	if type in CAT_S: var s2: float = CAT_S[type]; hits = [[0, 1.08 * s2, 1.05 * s2, 0.26 * s2, true], [0, 0.9 * s2, 0.4 * s2, 0.4 * s2], [0, 0.9 * s2, -0.45 * s2, 0.4 * s2], [0, 0.35 * s2, 0, 0.35 * s2, false, 0.7]]
	e.parts = hits.map(func(h): return {"o": Vector3(h[0], h[1], h[2]), "r": h[3], "mult": h[5] if h.size() > 5 else 1.0, "weak": h.size() > 4 and h[4], "bomb": false})
	e.head_x = ANIMALS[type].get("headX", 0.0)
	_bar(e)

func _bar(e: Enemies.Foe) -> void:   # the health bar above it
	e.bar = Node3D.new(); e.bar.visible = false; en.add_child(e.bar)
	var bg := MeshInstance3D.new(); bg.mesh = en._bar_mesh; bg.material_override = en._bar_bg; bg.scale = Vector3(0.9, 0.08, 1); e.bar.add_child(bg)
	e.fill = MeshInstance3D.new(); e.fill.mesh = en._bar_mesh; e.fill.material_override = en._bar_amber; e.fill.scale = Vector3(0.86, 0.05, 1); e.bar.add_child(e.fill)

func init(e: Enemies.Foe) -> void:
	e.angry = false; e.state = "wander"; e.state_t = rnd(2, 6); e.home = Vector2(e.pos.x, e.pos.z); e.wx = e.pos.x; e.wz = e.pos.z
	e.charge_cd = rnd(1, 3); e.attack_t = 0.0; e.pounce_cd = 0.0; e.roar_t = rnd(2, 8); e.airborne = false

func wake(e: Enemies.Foe) -> void:   # let out of the cage
	e.bs = ""; e.bt = 0.0; e.charge_cd = rnd(0.4, 2.2); e.roar_cd = rnd(3, 10); e.attack_t = rnd(0, 0.6); e.buff = 1.0

# ---------------- shot at, heard ----------------
## shot: everyone reacts; buffalo herds turn together, gorillas go berserk
func provoke(e: Enemies.Foe) -> void:
	var T := e.T
	if e.fury and e.type == "zebra" and not e.ridden:   # zebras never fight back: in the lab, shot, they bolt; on the safari they do not even run
		if not e.wild: _spook(e)
		return
	if e.caged or e.fury or e.kong:
		if e.kong and not e.caged: e.angry = true
		return
	if T.mode == "prey": e.state = "flee"; e.state_t = rnd(3, 5); return
	if not e.angry:
		e.angry = true
		if T.mode == "gorilla": e.state = "roar"; e.state_t = 0.8; Snd.play("roar_beat", 1.0, e.pos); _feed("고릴라가 화났습니다!")
		else: e.state = "chase"; Snd.play("roar_" + T.roar, 1.0, e.pos)
	if T.mode == "herd":
		for o in en.list:
			if o != e and o.type == e.type and not o.angry and o.pos.distance_to(e.pos) < 60.0: o.angry = true; o.state = "chase"

## gunfire nearby: prey bolts, predators and territorial animals come at you
func hear(e: Enemies.Foe, d: float) -> void:
	var T := e.T
	if e.kong and e.wild and not e.angry and d < 30.0: e.angry = true; e.alert = true; return
	if e.caged or e.fury or e.kong: return
	if T.mode == "prey":
		if e.state != "flee": e.state = "flee"; e.state_t = rnd(3, 5)
		return
	if e.angry: return
	if (T.mode == "cat" and d < 55.0) or ((T.mode == "herd" or T.mode == "territorial") and d < 30.0) or (e.boss and d < 50.0): provoke(e)

func _spook(e: Enemies.Foe) -> void:   # shot: a zebra bolts, and so do the ones right beside it
	for o in en.list:
		if not o.alive or o.type != "zebra" or o.ridden or o.caged or o.release_t > 0.0 or o.wild: continue
		if o != e and Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() > 7.0: continue
		if o.bs != "flee":
			o.zig_t = 0.0
			if randf() < 0.5: Snd.play("roar_bray", 1.0, o.pos)
		o.bs = "flee"; o.bt = rnd(3.5, 5)

# ---------------- what they do to you ----------------
func bleed_add() -> void:
	if game.ended or player.invuln > 0.0: return
	bleed_n += 1; bleed_t = 10.0
	_feed("출혈" + (" %d중첩" % bleed_n if bleed_n > 1 else "") + " · 10초 동안 초당 %d" % int(BLEED_DPS * bleed_n))

func bleed_add_to(a: Enemies.Foe) -> void:
	if a == null or not a.alive or game.ended: return
	a.bleed_n += 1; a.bleed_t = 10.0
	if not bleed_beasts.has(a): bleed_beasts.push_back(a)
	if a.ridden: _feed(a.T.name + " 출혈" + (" %d중첩" % a.bleed_n if a.bleed_n > 1 else "") + " · 10초 동안 초당 %d" % int(BLEED_DPS * a.bleed_n))

## a potion stops yours; leaving the stage stops everyone's
func bleed_stop(all := false) -> void:
	bleed_n = 0; bleed_t = 0.0; bleed_acc = 0.0
	if all:
		for a in bleed_beasts: a.bleed_n = 0; a.bleed_t = 0.0; a.bleed_acc = 0.0
		bleed_beasts.clear()

func bleed_update(dt: float) -> void:
	for i in range(bleed_beasts.size() - 1, -1, -1):
		var a: Enemies.Foe = bleed_beasts[i]
		if not a.alive: bleed_beasts.remove_at(i); continue
		a.bleed_t -= dt; a.bleed_acc += BLEED_DPS * a.bleed_n * dt
		var d := floorf(a.bleed_acc)
		if d > 0.0:   # a wound ticking away: quiet damage, and bleeding to death pays nobody
			a.bleed_acc -= d; a.no_pay = true; en.damage(a, d, Vector3(a.pos.x, a.pos.y + a.H * 0.5, a.pos.z), Vector3(0, 0, 1), false, true)
			if a.alive: a.no_pay = false
		if a.bleed_t <= 0.0 or not a.alive: a.bleed_n = 0; a.bleed_t = 0.0; a.bleed_acc = 0.0; bleed_beasts.remove_at(i)
	if bleed_t <= 0.0: return
	bleed_t -= dt; bleed_acc += BLEED_DPS * bleed_n * dt
	var d2 := floorf(bleed_acc)
	if d2 > 0.0:
		bleed_acc -= d2
		if player.invuln <= 0.0 and not game.ended and not game._god():
			player.hp -= d2
			if player.hp <= 0.0: player.hp = 0.0; bleed_stop(); game.over("bleed"); return
	if bleed_t <= 0.0: bleed_stop(); _feed("출혈이 멎었습니다")

func brave() -> bool: return m != null and tier >= 2

func fear(e: Enemies.Foe) -> bool:
	if game.ended or player.invuln > 0.0 or brave() or player.toss_on or game._god(): return false
	var d := Vector2(player.pos.x - e.pos.x, player.pos.z - e.pos.z); var l := maxf(d.length(), 0.001)
	player.fear_x = d.x / l; player.fear_z = d.y / l; player.fear_t = 1.0; player.shake = maxf(player.shake, 0.25); Snd.buzz(80)
	_feed("호랑이 포효 · 겁에 질려 1초 동안 도망칩니다"); return true

## a rhino's horn: straight up into the air. caught again on the way down, you go higher than the time before
func toss(e: Enemies.Foe) -> void:
	if game.ended or player.invuln > 0.0 or game._god(): return
	if m != null: hurt_mount(e.T.dmg * e.dmg_mul * BEAST_DMG, e); return   # up on any animal: it takes the horn, you stay on
	player.jet_end(); player.fear_t = 0.0
	toss_v = minf(toss_v + 3.6, 26.0) if player.toss_on else 13.0; toss_n = toss_n + 1 if player.toss_on else 1
	player.toss_on = true; player.vel = Vector3(0, toss_v, 0); player.grounded = false; player.pos.y += 0.05
	player.shake = maxf(player.shake, 0.45); Snd.buzz(140); Snd.play("thud", 1.0, player.pos)
	_feed("떨어지다 또 받혔습니다 · 더 높이 (%d번째)" % toss_n if toss_n > 1 else "코뿔소 뿔에 받혀 하늘로 날아갑니다")

## coming down: 50 and a bleeding wound for you. whatever you land on takes 30% of its health (the boss 15%)
func toss_land() -> void:
	player.toss_on = false; toss_v = 0.0; toss_n = 0
	var p := player.pos; Snd.play("thud", 1.0, p); Snd.play("land"); player.shake = maxf(player.shake, 0.6); Snd.buzz(160)
	if fx: fx.puff(p + Vector3(0, 0.2, 0), 8, 0.9, 0.8)
	var n := 0
	for e in en.list.duplicate():
		if not e.alive or e.ridden or e.caged or e.downed: continue
		var d := Vector2(e.pos.x - p.x, e.pos.z - p.z).length()
		if d > (e.foot_r if e.foot_r > 0.0 else e.R) * 0.85 + Player.R + 0.3 or p.y - e.pos.y > e.H + 1.5 or e.pos.y - p.y > 1.0: continue
		en.damage(e, roundf(e.max_hp * (0.15 if e.boss else 0.3)), Vector3(e.pos.x, e.pos.y + e.H * 0.7, e.pos.z), Vector3(e.pos.x - p.x, -1, e.pos.z - p.z).normalized(), false); n += 1
	if n > 0: _feed("떨어지며 %d마리를 덮쳤습니다 · 최대 체력의 30%%" % n)
	player.hurt(100.0 * BEAST_DMG, p, "fall")
	if not game.ended: bleed_add()

## who the beasts go for: you, or the animal you are sitting on
func quarry() -> Dictionary:
	if m != null: return {"x": m.pos.x, "y": m.pos.y, "z": m.pos.z, "r": m.R}
	return {"x": player.pos.x, "y": player.pos.y, "z": player.pos.z, "r": Player.R}

func _in_front(e: Enemies.Foe, q: Dictionary, reach: float, cos_min: float) -> bool:
	var dx: float = q.x - e.pos.x; var dz: float = q.z - e.pos.z; var d := sqrt(dx * dx + dz * dz)
	if d > reach or q.y > e.pos.y + e.H + 0.3: return false
	return d < 0.5 or (dx * sin(e.yaw) + dz * cos(e.yaw)) / d >= cos_min

func _feet_up() -> float: return player.pos.y - Phys.ground_at(player.pos.x, player.pos.y + 0.05, player.pos.z, Player.R)
func nose(e: Enemies.Foe) -> float: return e.foot.z1 if not e.foot.is_empty() else e.R

## a blow that lands. gore: a buffalo's charge (out cold for 3 s); bite: hippo or lion; maul: cheetah or tiger in passing; neck: a giraffe.
## every one of them opens a bleeding wound. up on any animal, the one under you takes it instead (and bleeds)
func hit(e: Enemies.Foe, kind: String) -> bool:
	if game.ended or player.invuln > 0.0 or game._god(): return false
	var dmg: float = e.T.dmg * e.dmg_mul * BEAST_DMG
	if m != null: hurt_mount(dmg, e); return true
	if kind == "gore":
		game.stun(e, 3.0, dmg)
		# thrown aside, out of its line: it runs on past you instead of carrying you along to the wall
		var cx := e.cx if (e.cx != 0.0 or e.cz != 0.0) else sin(e.yaw); var cz := e.cz if (e.cx != 0.0 or e.cz != 0.0) else cos(e.yaw)
		var rx := player.pos.x - e.pos.x; var rz := player.pos.z - e.pos.z; var side := signf(rx * cz - rz * cx)
		if side == 0.0: side = 1.0 if randf() < 0.5 else -1.0
		player.vel.x = cz * side * 12.0 + cx * 3.0; player.vel.z = -cx * side * 12.0 + cz * 3.0; e.ghost_t = 0.7
	elif kind == "neck": player.hurt(dmg, e.pos, "body"); Snd.play("thud", 1.0, player.pos); Snd.play("bite"); player.shake = maxf(player.shake, 0.5)
	else: player.hurt(dmg, e.pos, "body"); Snd.play("bite"); player.shake = maxf(player.shake, 0.45 if kind == "maul" else 0.3)
	if not game.ended and not (world.safari != null and world.safari.on): bleed_add()   # up on the watchtower a blow still hurts, but opens no wound
	return true

## the old way of hitting (animals that are not in a rage: the safari's before they are set off)
func strike(e: Enemies.Foe, dmg: float, kx: float, kz: float, kick: float) -> void:
	dmg *= e.dmg_mul * (1.0 if e.kong else BEAST_DMG)
	if dmg <= 0.0: return
	if m != null: hurt_mount(dmg, e); return
	if player.pos.y > e.pos.y + e.H + 0.3: return
	player.hurt(dmg, e.pos, "body")
	if not e.boss and not game.ended: bleed_add()
	player.vel.x += kx * kick; player.vel.z += kz * kick
	if kick > 8.0: player.vel.y = 5.0; player.grounded = false

## the male lion's roar: every animal but the tigers kneels for a moment, gets back a third of its health, and from then on is faster
func king_roar(e: Enemies.Foe) -> void:
	roar_cd = 8.0; Snd.play("roar_cat", 1.0, e.pos); Snd.play("roar_grunt", 1.0, e.pos); player.shake = maxf(player.shake, 0.3); var n := 0
	for o in en.list:
		if not o.alive or not o.animal or o.kong or o.caged or o.release_t > 0.0 or o.type == "tiger": continue
		if Vector2(o.pos.x - e.pos.x, o.pos.z - e.pos.z).length() > 32.0: continue
		o.hp = minf(o.max_hp, o.hp + o.max_hp * 0.35)
		if o.hp >= o.max_hp: o.bar.visible = false
		o.buff = minf(1.5, o.buff + 0.1)
		if o != e and not o.ridden:
			o.kneel_t = 1.2; o.bs = ""; o.windup = 0.0; o.airborne = false; _rest(o)
			if o.state == "charge": o.state = "chase"
		n += 1
	_feed("숫사자 포효 · 동물 %d마리가 무릎 꿇고 체력 회복 · 더 빠르고 사나워집니다" % n)

func _rest(e: Enemies.Foe) -> void:
	if e.head: e.head.rotation.x = 0.0
	if e.jaw: e.jaw.rotation.x = 0.0
	e.body.rotation.x = 0.0

func _kneel(e: Enemies.Foe, dt: float) -> void:
	e.kneel_t -= dt
	var k := clampf(minf((1.2 - e.kneel_t) / 0.22, e.kneel_t / 0.22), 0.0, 1.0) if e.kneel_t > 0.0 else 0.0
	e.body.rotation.x = 0.24 * k
	if e.legs.size() == 4: e.legs[0].rotation.x = 1.25 * k; e.legs[1].rotation.x = 1.25 * k; e.legs[2].rotation.x = 0.0; e.legs[3].rotation.x = 0.0
	e.vel *= exp(-dt * 6.0); en._ground_move(e, e.vel.x, e.vel.z, dt)
	if e.kneel_t <= 0.0: _rest(e)

# ---------------- moving about ----------------
func _turn(e: Enemies.Foe, yaw: float, rate: float, dt: float) -> void: en._turn_toward(e, yaw, rate, dt)

## the way to you: straight when it can see you, along the walking grid otherwise, round the side when it is wedged
func _pursue(e: Enemies.Foe, dist: float, tx: float, tz: float, dt: float) -> Vector2:
	if e.detour_t > 0.0: e.detour_t -= dt; return Vector2(e.dx2, e.dz2)
	if dist < 40.0 and e.los: return Vector2(tx, tz)
	var fd := Phys.flow_dir(e.pos.x, e.pos.z)
	return fd if fd != Vector2.ZERO else Vector2(tx, tz)

func _move(e: Enemies.Foe, dx: float, dz: float, sp: float, dt: float) -> bool:
	e.vel *= exp(-dt * 4.0); e.bx0 = e.pos.x; e.bz0 = e.pos.z
	return en._ground_move(e, dx * sp * e.buff + e.vel.x, dz * sp * e.buff + e.vel.z, dt)

## a big body on a 1 m walking grid can wedge itself against a tank or a bench: when it makes no headway it steps round to one side
func _unstick(e: Enemies.Foe, x0: float, z0: float, dirx: float, dirz: float, sp: float, dt: float) -> void:
	var moved := Vector2(e.pos.x - x0, e.pos.z - z0).length()
	if sp > 1.0 and moved < sp * dt * 0.3: e.stuck_t += dt
	else: e.stuck_t = maxf(0.0, e.stuck_t - dt * 2.0)
	if e.stuck_t < 0.35 or e.detour_t > 0.0: return
	var px := -dirz; var pz := dirx; var L := e.R * 2.0 + 1.0; var h := minf(e.H, 2.5)
	var a := Phys.collide_at(e.pos.x + px * L, e.pos.y + 0.05, e.pos.z + pz * L, e.R, h) == null; var b := Phys.collide_at(e.pos.x - px * L, e.pos.y + 0.05, e.pos.z - pz * L, e.R, h) == null
	var s := (1.0 if randf() < 0.5 else -1.0) if a == b else (1.0 if a else -1.0)
	var v := Vector2(px * s * 0.9 - dirx * 0.2, pz * s * 0.9 - dirz * 0.2).normalized()
	e.dx2 = v.x; e.dz2 = v.y; e.detour_t = rnd(0.55, 0.95); e.stuck_t = 0.0

func _gait(e: Enemies.Foe, sp: float, dt: float) -> void:
	var gait := minf(1.0, sp / 6.0) * (0.2 if e.airborne else 1.0)
	e.walk += dt * (2.0 + sp * 0.9); var sw := sin(e.walk) * 0.55 * gait
	if e.legs.size() == 4: e.legs[0].rotation.x = sw; e.legs[3].rotation.x = sw; e.legs[1].rotation.x = -sw; e.legs[2].rotation.x = -sw
	e.body.position.y = absf(sin(e.walk)) * 0.05 * gait * e.T.h

## a charging buffalo, hippo, rhino or elephant goes straight through a crate
func smash(e: Enemies.Foe, dx: float, dz: float) -> bool:
	var b := Phys.collide_at(e.pos.x + dx * 0.45, e.pos.y + 0.05, e.pos.z + dz * 0.45, e.R, minf(e.H, 2.0))
	if b != null and b.ref != null and b.kind == "wood" and b.ref is Dictionary and world.crates.has(b.ref):
		world.damage_crate(b.ref, 999.0, Vector3(b.ref.x, b.ref.y + 0.6, b.ref.z)); return true
	return false

func _spot(e: Enemies.Foe, r: float) -> Vector2:   # somewhere to amble to: open floor, not too far
	for k in 14:
		var x := e.pos.x + rnd(-r, r); var z := e.pos.z + rnd(-r, r)
		if absf(x) > Phys.HALF - 3 or absf(z) > Phys.HALF - 3 or Phys.collide_at(x, 0.05, z, e.R + 0.3, minf(e.H, 2.0)) != null: continue
		return Vector2(x, z)
	return Vector2(e.pos.x, e.pos.z)

func _flee_dir(e: Enemies.Foe, ax: float, az: float) -> Vector2:   # away from you, towards open floor, a little off the last way it went
	var best := Vector2(ax, az); var bs := -INF; var h := minf(e.H, 1.6)
	for i in 16:
		var a := (i / 16.0) * TAU; var x := sin(a); var z := cos(a); var free := 0
		for d: float in [1.6, 3.4, 6.0]:
			var px := e.pos.x + x * d; var pz := e.pos.z + z * d
			if absf(px) > Phys.HALF - 1.5 or absf(pz) > Phys.HALF - 1.5 or Phys.collide_at(px, e.pos.y + 0.05, pz, e.R, h) != null: break
			free += 1
		var sc := (x * ax + z * az) * 1.3 + free * 0.75 + (x * e.fx_ + z * e.fz_) * 0.35 + rnd(-0.5, 0.5)
		if sc > bs: bs = sc; best = Vector2(x, z)
	return best

# ---------------- behind bars ----------------
func _caged(e: Enemies.Foe, dt: float, dist: float, face_yaw: float) -> void:
	var T := e.T; var c: Dictionary = e.cage; var ix := maxf(0.2, c.w / 2 - 0.45 - e.R); var iz := maxf(0.2, c.d / 2 - 0.45 - e.R)
	e.state_t -= dt; e.roar_t -= dt; var sp := 0.0; var dirx := 0.0; var dirz := 0.0
	if e.cstate == "": e.cstate = "idle"; e.state_t = rnd(0.3, 3)
	if e.cstate == "idle":
		if e.state_t <= 0.0:
			if dist < 24.0 and randf() < 0.4: e.cstate = "lunge"; e.state_t = 1.1; e.cx = (player.pos.x - e.pos.x) / dist; e.cz = (player.pos.z - e.pos.z) / dist
			else: e.cstate = "pace"; e.state_t = rnd(2, 4); e.wx = c.x + rnd(-ix, ix); e.wz = c.z + rnd(-iz, iz)
		if dist < 22.0: _turn(e, face_yaw, T.turn * 0.5, dt)
	elif e.cstate == "pace":
		var dx := e.wx - e.pos.x; var dz := e.wz - e.pos.z; var l := sqrt(dx * dx + dz * dz)
		if l < 0.6 or e.state_t <= 0.0: e.cstate = "idle"; e.state_t = rnd(0.8, 3)
		else: dirx = dx / l; dirz = dz / l; sp = T.speed * 1.25
	else:
		dirx = e.cx; dirz = e.cz; sp = minf(T.run * 0.5, 7.0)
		if e.state_t <= 0.0: e.cstate = "idle"; e.state_t = rnd(1, 3)
	e.vel *= exp(-dt * 4.0)
	var blocked := en._ground_move(e, dirx * sp + e.vel.x, dirz * sp + e.vel.z, dt)
	if blocked and e.cstate == "lunge":
		e.cstate = "idle"; e.state_t = rnd(1.2, 3.5); world.lab.rattle(c, e.pos.x + dirx * e.R, e.pos.z + dirz * e.R)
		if randf() < 0.5: Snd.play("roar_" + T.roar, 1.0, e.pos)
	elif blocked and e.cstate == "pace": e.cstate = "idle"; e.state_t = rnd(0.5, 1.5)
	if sp > 0.1: _turn(e, atan2(dirx, dirz), T.turn, dt)
	_gait(e, sp, dt)
	if e.roar_t <= 0.0:
		e.roar_t = rnd(6, 14)
		if dist < 34.0 and randf() < 0.45: Snd.play("roar_" + T.roar, 1.0, e.pos)

# ---------------- one animal, one frame ----------------
func update(e: Enemies.Foe, dt: float, time: float, dist: float, face_yaw: float) -> void:
	e.yaw_off = 0.0
	if e.kong: _kong(e, dt, time, dist, face_yaw); return
	if e.caged: _caged(e, dt, dist, face_yaw); return
	if e.ridden: return
	if e.kneel_t > 0.0: _kneel(e, dt); return
	# just let out: a moment to take it in, then everything in the cage comes for you
	if e.release_t > 0.0:
		e.release_t -= dt; _turn(e, face_yaw, e.T.turn, dt); _gait(e, 0.0, dt)
		if e.release_t > 0.0: return
		e.fury = true; e.angry = true; e.state = "chase"; wake(e); e.charge_cd = rnd(0.6, 2.2); e.pounce_cd = rnd(0.3, 1.5)
		if randf() < 0.5 and e.type != "zebra": Snd.play("roar_" + e.T.roar, 1.0, e.pos)
	var T := e.T; var tx := (player.pos.x - e.pos.x) / dist; var tz := (player.pos.z - e.pos.z) / dist
	var reach := maxf(T.reach * e.scale, e.foot.z1 + 0.3)
	# 3-1: wild until something sets it off; then it fights the lab's way. while you stand on the watchtower everything but a giraffe
	# goes for the tower first; after the stampede the zebras just come and stand about it
	if e.wild and not e.tamed:
		if e.angry and not e.fury: e.fury = true; e.state = "chase"; wake(e)
		if e.fury:
			if e.type == "zebra":
				if world.safari.stampede: _zebra_mill(e, dt); return
			elif e.type != "giraffe" and world.safari.holds(): _siege(e, dt, dist); return
	if e.fury and (e.tamed or e.type in ["zebra", "buffalo", "hippo", "lionM", "rhino", "cheetah", "tiger", "giraffe"]):
		if e.tamed or e.type == "zebra": _zebra(e, dt, dist, tx, tz)
		else:
			match e.type:
				"buffalo": _buffalo(e, dt, dist, tx, tz, face_yaw)
				"hippo", "lionM": _biter(e, dt, dist, tx, tz, face_yaw)
				"rhino": _rhino(e, dt, dist, tx, tz, face_yaw)
				"cheetah", "tiger": _runner(e, dt, dist, tx, tz, face_yaw)
				"giraffe": _giraffe(e, dt, dist, tx, tz, face_yaw)
		e.roar_t -= dt
		if e.roar_t <= 0.0:
			e.roar_t = rnd(6, 14)
			if dist < 40.0 and not e.tamed and e.type != "zebra" and randf() < 0.5: Snd.play("roar_" + T.roar, 1.0, e.pos)
		return
	# living wild: wandering, grazing, and turning on you when you come too close
	var B := e.buff; var sp := 0.0; var dirx := 0.0; var dirz := 0.0; var turn: float = T.turn
	e.state_t -= dt; e.charge_cd -= dt * B; e.pounce_cd -= dt * B; e.attack_t -= dt * B
	if not e.angry and e.boss and dist < 40.0: provoke(e)
	var aggro: float = minf(T.aggroR, 28.0) if e.wild else T.aggroR   # out on the safari they let you get closer, and a cat has to see you
	if not e.angry and ((T.mode == "cat" and dist < aggro and (not e.wild or e.los or dist < 12.0)) or ((T.mode == "territorial" or T.mode == "herd") and dist < aggro)):
		e.angry = true; e.state = "chase"; Snd.play("roar_" + T.roar, 1.0, e.pos)
		if T.mode == "herd": provoke(e)
	if T.mode == "prey" and not e.fury and e.state != "flee" and dist < 26.0: e.state = "flee"; e.state_t = rnd(3, 5)
	match e.state:
		"wander":
			if e.state_t <= 0.0 or Vector2(e.wx - e.pos.x, e.wz - e.pos.z).length() < 2.0:
				e.state_t = rnd(4, 9); var a := rnd(0, TAU); var d := rnd(6, 28)
				e.wx = clampf(e.home.x + cos(a) * d, -Phys.HALF + 3, Phys.HALF - 3); e.wz = clampf(e.home.y + sin(a) * d, -Phys.HALF + 3, Phys.HALF - 3)
				e.graze = rnd(1.5, 4) if randf() < 0.35 else 0.0
			if e.graze > 0.0: e.graze -= dt
			else: var v := Vector2(e.wx - e.pos.x, e.wz - e.pos.z).normalized(); dirx = v.x; dirz = v.y; sp = T.speed
		"flee":
			dirx = -tx; dirz = -tz; sp = T.run
			if e.state_t <= 0.0 and dist > 40.0: e.state = "wander"; e.home = Vector2(e.pos.x, e.pos.z)
		"roar":
			turn = 9.0
			if e.state_t <= 0.0: e.state = "chase"
		"chase":
			var d2 := _pursue(e, dist, tx, tz, 0.0); dirx = d2.x; dirz = d2.y
			sp = T.run * 0.6 if (T.mode == "cat" and dist > 30.0) else (T.run * 0.7 if T.get("charge", false) else T.run)
			if T.get("charge", false) and e.charge_cd <= 0.0 and dist > 7.0 and dist < 45.0 and e.los: e.state = "charge"; e.state_t = 2.6; e.cx = tx; e.cz = tz; e.hit_done = false; Snd.play("roar_" + T.roar, 1.0, e.pos)
			if T.get("pounce", false) and e.pounce_cd <= 0.0 and dist < 7.5 and dist > 2.5 and e.los and not e.airborne:
				e.airborne = true; e.vy = 4.6; e.vel.x = tx * T.run * 1.05; e.vel.z = tz * T.run * 1.05; e.pounce_cd = rnd(2.5, 4); e.hit_done = false; Snd.play("roar_cat", 1.0, e.pos)
			if dist < reach + Player.R and e.attack_t <= 0.0: e.attack_t = 1.05 if T.mode == "gorilla" else (0.9 if T.mode == "cat" else 1.3); e.windup = 0.22
		"charge":
			dirx = e.cx; dirz = e.cz; sp = T.run * 1.25; turn = 0.4
			if not e.hit_done and dist < reach + Player.R + 0.4: e.hit_done = true; strike(e, T.dmg * 1.2, e.cx, e.cz, 14.0)
			if e.state_t <= 0.0 or (e.hit_done and e.state_t < 1.6): e.state = "recover"; e.state_t = 1.0
		_:   # recover, stun
			sp = T.run * 0.3 if e.state == "recover" else 0.0; dirx = e.cx; dirz = e.cz
			if e.state_t <= 0.0: e.state = "chase"; e.charge_cd = rnd(2.5, 4.5)
	if e.windup > 0.0:
		e.windup -= dt
		if e.windup <= 0.0 and dist < reach + Player.R + 0.8: strike(e, T.dmg, tx, tz, 13.0 if T.mode == "gorilla" else (10.0 if T.dmg > 40.0 else 5.0))
	if e.airborne:
		e.vy -= 16.0 * dt; e.pos.y += e.vy * dt
		e.pos = Phys.move_xz(e.pos, e.vel.x * dt, e.vel.z * dt, e.R, e.H, 0.45)[0]
		if not e.hit_done and dist < reach + Player.R + 0.5: e.hit_done = true; strike(e, T.dmg * 1.15, tx, tz, 9.0)
		var gy := Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R)
		if e.pos.y <= gy: e.pos.y = gy; e.airborne = false; e.vy = 0.0; e.vel = Vector3.ZERO
	else:
		e.vel *= exp(-dt * 4.0)
		if e.detour_t > 0.0:
			e.detour_t -= dt
			if e.state == "chase": dirx = e.dx2; dirz = e.dz2
		var x0 := e.pos.x; var z0 := e.pos.z
		var blocked := en._ground_move(e, dirx * sp * B + e.vel.x, dirz * sp * B + e.vel.z, dt)
		if e.state == "chase": _unstick(e, x0, z0, dirx, dirz, sp, dt)
		if blocked and e.state == "charge" and smash(e, e.cx, e.cz): blocked = false
		if blocked and e.state == "charge": e.state = "stun"; e.state_t = 1.1; Snd.play("thud", 1.0, e.pos); _puff_front(e, 6, 0.4, 0.8)
		if blocked and e.state == "wander": e.state_t = 0.0
	if sp > 0.1 and e.state != "roar": _turn(e, face_yaw if (e.state == "chase" and dist < 12.0) else atan2(dirx, dirz), turn, dt)
	elif e.state == "roar" or (e.angry and dist < 14.0): _turn(e, face_yaw, turn, dt)
	_gait(e, sp, dt)
	e.roar_t -= dt
	if e.roar_t <= 0.0:
		e.roar_t = rnd(6, 14)
		if dist < 45.0 and (e.angry or randf() < 0.3): Snd.play("roar_" + T.roar, 1.0, e.pos)

# ---------------- the kinds ----------------
## zebras never fight: they amble about and graze. shot, they bolt, zig-zagging fast. tamed animals live the same quiet life
func _zebra(e: Enemies.Foe, dt: float, _dist: float, tx: float, tz: float) -> void:
	var T := e.T; e.bt -= dt; var sp := 0.0; var dx := 0.0; var dz := 0.0; var turn: float = T.turn
	if e.bs == "flee":
		e.zig_t -= dt
		if e.zig_t <= 0.0: e.zig_t = rnd(0.3, 0.65); var d := _flee_dir(e, -tx, -tz); e.fx_ = d.x; e.fz_ = d.y
		dx = e.fx_; dz = e.fz_; sp = T.run * 0.86; turn = 11.0
		if e.bt <= 0.0: e.bs = "graze"; e.bt = rnd(1.5, 3.5)
	elif e.bs == "walk":
		var wx := e.wx - e.pos.x; var wz := e.wz - e.pos.z; var l := sqrt(wx * wx + wz * wz)
		if l < 1.2 or e.bt <= 0.0: e.bs = "graze"; e.bt = rnd(1.5, 4)
		else: dx = wx / l; dz = wz / l; sp = T.speed * (1.0 if e.type == "zebra" else 0.8)
	else:
		if e.bs != "graze": e.bs = "graze"; e.bt = rnd(0.5, 2.5)
		if e.bt <= 0.0: e.bs = "walk"; e.bt = rnd(3, 7); var p := _spot(e, 14.0); e.wx = p.x; e.wz = p.y
	var blocked := _move(e, dx, dz, sp, dt)
	if blocked and e.bs == "walk": e.bt = 0.0
	if blocked and e.bs == "flee": e.zig_t = minf(e.zig_t, 0.05)
	if sp > 0.1: _turn(e, atan2(dx, dz), turn, dt)
	_gait(e, sp, dt)
	e.body.rotation.x = lerpf(e.body.rotation.x, 0.1 if e.bs == "graze" else 0.0, 1.0 - exp(-dt * 4.0))

## buffalo: stops, paws the floor, then runs dead straight. a wall met at a slant turns the run along the wall; only a wall met head-on,
## or a corner, stops it. whoever is in the way is out cold for 3 seconds and bleeds
func _buffalo(e: Enemies.Foe, dt: float, dist: float, tx: float, tz: float, face_yaw: float) -> void:
	var T := e.T; var B := e.buff; e.bt -= dt * B; e.charge_cd -= dt * B
	var sp := 0.0; var dx := 0.0; var dz := 0.0; var turn: float = T.turn; var pitch := 0.0
	if e.bs == "aim":
		_turn(e, face_yaw, 5.0, dt); pitch = 0.12
		if e.bt <= 0.0: e.bs = "rush"; e.bt = 6.0; e.cx = tx; e.cz = tz; e.yaw = atan2(tx, tz); e.hit_done = false; Snd.play("roar_" + T.roar, 1.0, e.pos); _puff_at(e.pos, 3, 0.6, 0.6)
	elif e.bs == "rush":
		dx = e.cx; dz = e.cz; sp = T.run * 1.15; turn = 16.0; pitch = 0.14
		var net := Vector2(e.pos.x - e.last_x, e.pos.z - e.last_z).length() if e.has_last else 1.0
		e.pin_t = e.pin_t + dt if net < sp * B * dt * 0.3 else 0.0
		if e.pin_t > 0.3: e.bs = "daze"; e.bt = 1.3; e.pin_t = 0.0
		var q := quarry(); var rx: float = q.x - e.pos.x; var rz: float = q.z - e.pos.z; var f := rx * dx + rz * dz; var l := absf(rx * dz - rz * dx)
		if not e.hit_done and f > -e.R and f < nose(e) + q.r + 0.25 and l < e.R + q.r + 0.3 and q.y < e.pos.y + e.H + 0.2: e.hit_done = true; hit(e, "gore")
		if fx and randf() < dt * 12.0: fx.puff(Vector3(e.pos.x - dx, 0.2, e.pos.z - dz), 1, 0.5, 0.35)
		if e.bt <= 0.0: e.bs = "daze"; e.bt = 0.8
	elif e.bs == "daze":
		pitch = 0.18; e.yaw_off = sin(e.bt * 16.0) * 0.12
		if e.bt <= 0.0: e.bs = "seek"; e.charge_cd = rnd(0.8, 2)
	else:
		e.bs = "seek"; var d := _pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.y; sp = T.run * 0.42
		if e.charge_cd <= 0.0 and e.los and dist > 4.0 and dist < 42.0: e.bs = "aim"; e.bt = 0.75; sp = 0.0
	e.last_x = e.pos.x; e.last_z = e.pos.z; e.has_last = true
	if e.ghost_t > 0.0: e.ghost_t -= dt
	_move(e, dx, dz, sp, dt)
	if e.bs == "rush":
		# how far it really got: short of the step means something solid. head-on (or a corner) stops it; a slant sends it along the wall
		var want := sp * B * dt; var mx := e.pos.x - e.bx0; var mz := e.pos.z - e.bz0; var got := sqrt(mx * mx + mz * mz)
		if got < want * 0.94 and not smash(e, e.cx, e.cz):
			if got < want * 0.3:
				e.bs = "daze"; e.bt = 1.3; Snd.play("thud", 1.0, e.pos); _puff_front(e, 6, 0.5, 0.8)
				if dist < 20.0: player.shake = maxf(player.shake, 0.12)
			else: e.cx = mx / got; e.cz = mz / got
		_turn(e, atan2(e.cx, e.cz), turn, dt)
	elif e.bs == "seek":
		_unstick(e, e.bx0, e.bz0, dx, dz, sp, dt)
		if sp > 0.1: _turn(e, atan2(dx, dz), turn, dt)
	_gait(e, sp, dt)
	if e.bs == "aim" and e.legs.size() > 0: e.legs[0].rotation.x = sin(e.bt * 22.0) * 0.55   # pawing the floor
	e.body.rotation.x = lerpf(e.body.rotation.x, pitch, 1.0 - exp(-dt * 8.0))

## hippo, and the male lion who bites the same way: come close, open wide, and clamp shut. the lion also roars now and then
func _biter(e: Enemies.Foe, dt: float, dist: float, tx: float, tz: float, face_yaw: float) -> void:
	var T := e.T; var B := e.buff; var lion := e.type == "lionM"; e.bt -= dt * B; e.attack_t -= dt * B; e.roar_cd -= dt
	var q := quarry(); var qd := Vector2(q.x - e.pos.x, q.z - e.pos.z).length(); var reach: float = nose(e) + q.r + 0.45
	var sp := 0.0; var dx := 0.0; var dz := 0.0; var open := 0.0; var look := 0.0
	if e.bs == "gape":
		open = clampf(1.0 - e.bt / e.bt_max, 0.0, 1.0); _turn(e, face_yaw, 6.0, dt)
		if qd > reach * 0.85: dx = tx; dz = tz; sp = 1.8
		if e.bt <= 0.0: e.bs = "snap"; e.bt = 0.13; e.bit = false
	elif e.bs == "snap":
		open = clampf(e.bt / 0.13, 0.0, 1.0)
		if not e.bit:
			e.bit = true; Snd.play("thud", 1.0, e.pos)
			if _in_front(e, q, reach + 0.4, 0.5): hit(e, "bite")
		if e.bt <= 0.0: e.bs = "chase"; e.attack_t = rnd(0.6, 0.95)
	elif e.bs == "roar":
		open = 1.0; look = 1.0; _turn(e, face_yaw, 3.0, dt)
		if not e.roared and e.bt < 1.0: e.roared = true; king_roar(e)
		if e.bt <= 0.0: e.bs = "chase"; e.roar_cd = rnd(16, 24)
	else:
		e.bs = "chase"; var d := _pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.y
		sp = T.run * (0.62 if lion else 0.78) if qd > reach - 0.15 else 0.0
		if qd < reach and e.attack_t <= 0.0: e.bs = "gape"; e.bt = 0.42 if lion else 0.6; e.bt_max = e.bt; Snd.play("roar_cat" if lion else "roar_grunt", 1.0, e.pos)
		elif lion and e.roar_cd <= 0.0 and roar_cd <= 0.0 and dist < 30.0 and e.los: e.bs = "roar"; e.bt = 1.4; e.roared = false; roar_cd = 2.0
	_move(e, dx, dz, sp, dt)
	if e.bs == "chase": _unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); _turn(e, face_yaw if qd < 8.0 else atan2(dx, dz), T.turn, dt)
	_gait(e, sp, dt)
	if e.head: e.head.rotation.x = -0.95 * open   # the hippo's whole head tips back as the jaw drops
	if e.jaw: e.jaw.rotation.x = (0.85 if lion else 0.55) * open
	e.body.rotation.x = lerpf(e.body.rotation.x, -0.12 * look if lion else 0.0, 1.0 - exp(-dt * 8.0))

## rhino: a charge that slows as it closes, then the horn comes up and you go straight up into the air.
## coming down within its reach, you get thrown again, higher each time
func _rhino(e: Enemies.Foe, dt: float, dist: float, tx: float, tz: float, face_yaw: float) -> void:
	var T := e.T; var B := e.buff; e.bt -= dt * B; e.charge_cd -= dt * B
	var q := quarry(); var qd := Vector2(q.x - e.pos.x, q.z - e.pos.z).length(); var reach: float = nose(e) + q.r + 0.5
	var sp := 0.0; var dx := 0.0; var dz := 0.0; var head := 0.0
	# you are falling towards it: up goes the horn, timed so it meets you about a horn's height up
	if player.toss_on and player.vel.y < 0.0 and qd < reach + 0.5 and e.bs != "flick" and _feet_up() + player.vel.y * 0.13 - 0.15 < 2.6: e.bs = "flick"; e.bt = 0.3; e.tossed = false
	match e.bs:
		"rush":
			_turn(e, face_yaw, 1.8, dt); dx = sin(e.yaw); dz = cos(e.yaw); sp = T.run * 1.05; head = 0.3
			if fx and randf() < dt * 10.0: fx.puff(Vector3(e.pos.x - dx, 0.2, e.pos.z - dz), 1, 0.5, 0.35)
			if qd < reach + 2.6: e.bs = "brake"; e.bt = 0.4; e.bt_max = 0.4; e.v0 = sp
			elif e.bt <= 0.0: e.bs = "seek"; e.charge_cd = rnd(1, 2)
		"brake":
			var u := clampf(e.bt / e.bt_max, 0.0, 1.0); sp = lerpf(1.2, e.v0, u); head = 0.3 + 0.18 * (1.0 - u)
			_turn(e, face_yaw, 4.5, dt); dx = sin(e.yaw); dz = cos(e.yaw)
			if e.bt <= 0.0: e.bs = "flick"; e.bt = 0.3; e.tossed = false
		"flick":
			var u2 := 1.0 - clampf(e.bt / 0.3, 0.0, 1.0); head = 0.48 - u2 * 3.3 if u2 < 0.4 else -0.85; _turn(e, face_yaw, 6.0, dt)
			if not e.tossed and u2 >= 0.4:
				e.tossed = true; Snd.play("swoosh", 1.0, e.pos)
				var ddx: float = q.x - e.pos.x; var ddz: float = q.z - e.pos.z; var d := sqrt(ddx * ddx + ddz * ddz); var facing := d < 0.5 or (ddx * sin(e.yaw) + ddz * cos(e.yaw)) / d >= 0.3
				if d < reach + 0.35 and facing and (m != null or _feet_up() < 3.0): toss(e)   # the horn reaches about 3 m up
			if e.bt <= 0.0: e.bs = "recover"; e.bt = 0.9
		"recover":
			head = -0.85 * clampf(e.bt / 0.9, 0.0, 1.0)
			if e.bt <= 0.0: e.bs = "seek"; e.charge_cd = rnd(0.8, 2)
		"stun":
			head = 0.2 + sin(e.bt * 14.0) * 0.12
			if e.bt <= 0.0: e.bs = "seek"; e.charge_cd = rnd(1, 2)
		_:
			e.bs = "seek"; var p := _pursue(e, dist, tx, tz, dt); dx = p.x; dz = p.y; sp = T.run * 0.4
			if qd < reach + 1.2 and not player.toss_on: e.bs = "brake"; e.bt = 0.25; e.bt_max = 0.25; e.v0 = sp
			elif e.charge_cd <= 0.0 and e.los and dist > 6.0 and dist < 40.0 and not player.toss_on: e.bs = "rush"; e.bt = 4.0; Snd.play("roar_" + T.roar, 1.0, e.pos)
	var blocked := _move(e, dx, dz, sp, dt)
	if blocked and (e.bs == "rush" or e.bs == "brake") and not smash(e, dx, dz): e.bs = "stun"; e.bt = 1.1; Snd.play("thud", 1.0, e.pos); _puff_front(e, 6, 0.5, 0.8)
	if e.bs == "seek":
		_unstick(e, e.bx0, e.bz0, dx, dz, sp, dt)
		if sp > 0.1: _turn(e, atan2(dx, dz), T.turn, dt)
	_gait(e, sp, dt)
	if e.head: e.head.rotation.x = lerpf(e.head.rotation.x, head, 1.0 - exp(-dt * (40.0 if e.bs == "flick" else 10.0)))

## cheetah, and the tiger who hunts the same way: a dead-straight sprint along a line that passes just beside you, a bite in passing
## at the closest point, and a stop a few metres behind you. then round for another go. the tiger also roars: you run away for a second
func _runner(e: Enemies.Foe, dt: float, dist: float, tx: float, tz: float, face_yaw: float) -> void:
	var T := e.T; var B := e.buff; var tiger := e.type == "tiger"; e.bt -= dt * B; e.charge_cd -= dt * B; e.roar_cd -= dt
	var q := quarry(); var sp := 0.0; var dx := 0.0; var dz := 0.0; var turn: float = T.turn; var lift := 0.0; var open := 0.0
	match e.bs:
		"run":
			dx = e.cx; dz = e.cz; sp = T.run; turn = 24.0
			var rx: float = q.x - e.pos.x; var rz: float = q.z - e.pos.z; var f := rx * dx + rz * dz; var l := absf(rx * dz - rz * dx); var ns := nose(e)
			open = clampf(1.0 - (f - ns) / 5.0, 0.0, 1.0)   # the mouth opens as it draws level
			if not e.bit and f <= ns * 0.8:
				e.bit = true
				if l < q.r + 1.2 and absf(q.y - e.pos.y) < e.H + 0.4: hit(e, "maul")
				e.bs = "pass"; e.pass_v = sp
			elif e.bt <= 0.0: e.bs = "pass"; e.pass_v = sp
		"pass":   # keeps going past you, slowing to a stop in about three metres
			e.pass_v = maxf(0.0, e.pass_v - (T.run * T.run / 6.0) * dt * B); sp = e.pass_v / B; dx = e.cx; dz = e.cz; turn = 2.0; open = clampf(e.pass_v / T.run, 0.0, 1.0) * 0.5
			if e.pass_v <= 0.4: e.bs = "turn"; e.bt = 0.5
		"turn":
			_turn(e, face_yaw, 8.0, dt)
			if e.bt <= 0.0: e.bs = "stalk"; e.charge_cd = rnd(0.2, 0.8)
		"roar":
			lift = 1.0; open = 1.0; _turn(e, face_yaw, 4.0, dt)
			if not e.roared and e.bt < 0.75:
				e.roared = true; Snd.play("roar_cat", 1.0, e.pos)
				if dist < 24.0 and e.los: fear(e)
			if e.bt <= 0.0: e.bs = "stalk"; e.roar_cd = rnd(9, 14)
		_:
			e.bs = "stalk"; var d := _pursue(e, dist, tx, tz, dt)
			if dist < 6.0: dx = -tx; dz = -tz; sp = T.speed * 2.2   # too close for a run: open the distance first
			else: dx = d.x; dz = d.y; sp = T.run * 0.5 if dist > 30.0 else T.speed * 1.4
			if tiger and e.roar_cd <= 0.0 and dist < 24.0 and e.los: e.bs = "roar"; e.bt = 1.15; e.roared = false; sp = 0.0
			elif e.charge_cd <= 0.0 and e.los and dist >= 6.0 and dist < 34.0:   # a run along a line just off your shoulder
				var rx2: float = q.x - e.pos.x; var rz2: float = q.z - e.pos.z; var dd := maxf(sqrt(rx2 * rx2 + rz2 * rz2), 0.001); var side := 1.0 if randf() < 0.5 else -1.0
				var ax: float = q.x - rz2 / dd * side * 1.1; var az: float = q.z + rx2 / dd * side * 1.1; var v := Vector2(ax - e.pos.x, az - e.pos.z).normalized()
				e.cx = v.x; e.cz = v.y; e.bs = "run"; e.bt = 3.0; e.bit = false; Snd.play("roar_cat", 1.0, e.pos)
	var blocked := _move(e, dx, dz, sp, dt)
	if blocked and (e.bs == "run" or e.bs == "pass"): e.bs = "turn"; e.bt = 0.6
	if e.bs == "stalk": _unstick(e, e.bx0, e.bz0, dx, dz, sp, dt)
	if sp > 0.1 and e.bs != "turn" and e.bs != "roar": _turn(e, face_yaw if (e.bs == "stalk" and dist < 6.0) else atan2(dx, dz), turn, dt)
	_gait(e, sp, dt)
	if e.jaw: e.jaw.rotation.x = 0.75 * open
	e.body.rotation.x = lerpf(e.body.rotation.x, -0.1 * lift, 1.0 - exp(-dt * 8.0))

## giraffe: walks up to you and swings its long neck down like a club. the neck reaches a long way, up over a watchtower's railing too
func _neck(e: Enemies.Foe, a: float, dt: float) -> void:
	if e.head == null: return
	e.head.rotation.x = lerpf(e.head.rotation.x, a, 1.0 - exp(-dt * 16.0)); var r := e.head.rotation.x
	if e.neck_base.is_empty(): e.neck_base = [Vector2(e.parts[0].o.y, e.parts[0].o.z), Vector2(e.parts[1].o.y, e.parts[1].o.z)]
	var c := cos(r); var s := sin(r)   # the head and neck hit spheres swing with it
	for i in 2:
		var ly: float = e.neck_base[i].x - NECK[0]; var lz: float = e.neck_base[i].y - NECK[1]
		e.parts[i].o = Vector3(0, NECK[0] + ly * c - lz * s, NECK[1] + ly * s + lz * c)

func _giraffe(e: Enemies.Foe, dt: float, dist: float, tx: float, tz: float, _face_yaw: float) -> void:
	var T := e.T; var B := e.buff; var sc := e.scale; e.bt -= dt * B; e.attack_t -= dt * B
	var q := quarry(); var qd := Vector2(q.x - e.pos.x, q.z - e.pos.z).length(); var high: float = q.y - e.pos.y
	var reach: float = (4.3 if high > 2.0 else 3.4) * sc + q.r; var in_reach := qd < reach and high < 5.4 * sc and high > -1.5
	var to_q := atan2(q.x - e.pos.x, q.z - e.pos.z); var sp := 0.0; var dx := 0.0; var dz := 0.0; var neck := 0.0
	match e.bs:
		"rear":
			neck = -0.5 * (1.0 - clampf(e.bt / 0.45, 0.0, 1.0)); _turn(e, to_q, 5.0, dt)
			if e.bt <= 0.0: e.bs = "swing"; e.bt = 0.16; e.hit_done = false; Snd.play("swoosh", 1.0, e.pos)
		"swing":
			var u := 1.0 - clampf(e.bt / 0.16, 0.0, 1.0); neck = -0.5 + 1.1 * u
			if not e.hit_done and u >= 0.6:
				e.hit_done = true
				var f: bool = qd < 0.5 or ((q.x - e.pos.x) * sin(e.yaw) + (q.z - e.pos.z) * cos(e.yaw)) / qd >= 0.35
				if qd < reach + 0.4 and high < 5.6 * sc and high > -1.5 and f: hit(e, "neck")
			if e.bt <= 0.0: e.bs = "recover"; e.bt = 0.55
		"recover":
			neck = 0.6 * clampf(e.bt / 0.55, 0.0, 1.0)
			if e.bt <= 0.0: e.bs = "seek"; e.attack_t = rnd(1.8, 2.6) if high > 2.0 else rnd(0.7, 1.2)   # reaching up over a railing takes it longer
		_:
			if e.bs != "seek": e.bs = "seek"; e.attack_t = maxf(e.attack_t, 0.3)
			var d := _pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.y
			sp = T.run * (0.55 if dist > 30.0 else 0.42) if qd > reach - 0.6 else 0.0
			if in_reach and e.attack_t <= 0.0:
				e.bs = "rear"; e.bt = 0.45; sp = 0.0
				if randf() < 0.5: Snd.play("roar_grunt", 1.0, e.pos)
	_move(e, dx, dz, sp, dt)
	if e.bs == "seek":
		_unstick(e, e.bx0, e.bz0, dx, dz, sp, dt)
		if sp > 0.1 or qd < 10.0: _turn(e, to_q if qd < 10.0 else atan2(dx, dz), T.turn, dt)
	_gait(e, sp, dt); _neck(e, neck, dt)

# ---------------- 3-1: at the watchtower ----------------
func _siege(e: Enemies.Foe, dt: float, _dist: float) -> void:
	var T := e.T; var S: Dictionary = Safari.SIEGE.get(e.type, {"dmg": 5.0, "cd": [1.4, 2.0]}); var B := e.buff; var ns := nose(e); var tw: Safari = world.safari
	var twx := tw.outer.position.x; var twz := tw.outer.position.z
	e.bt -= dt * B; e.sg_cd -= dt * B; e.claim_t -= dt
	# a place at the tower: kept while it is ours, looked for again every half second while waiting
	var slot = tw.claim(e) if (e.slot != null and e.slot.owner == e) else null
	if slot == null and e.claim_t <= 0.0: e.claim_t = rnd(0.4, 0.7); slot = tw.claim(e)
	var sp := 0.0; var mx := 0.0; var mz := 0.0; var pitch := 0.0; var has_face := false; var face := 0.0; var turn: float = T.turn * 1.5; var open := 0.0
	if slot == null:
		# all taken: wait a little way off, on its own side of the tower, pacing and roaring
		if e.bs != "swait": e.bs = "swait"; var a := atan2(e.pos.z - twz, e.pos.x - twx) + rnd(-0.4, 0.4); var r := rnd(9.5, 13); e.wx = twx + cos(a) * r; e.wz = twz + sin(a) * r; e.bt = rnd(2, 5)
		var wx := e.wx - e.pos.x; var wz := e.wz - e.pos.z; var l := sqrt(wx * wx + wz * wz)
		if l > 1.2:
			var fd := Phys.flow_dir(e.pos.x, e.pos.z)
			if l > 16.0 and fd != Vector2.ZERO: mx = fd.x; mz = fd.y
			else: mx = wx / l; mz = wz / l
			sp = T.run * 0.6 if l > 16.0 else T.speed * 1.2
		else:
			has_face = true; face = atan2(twx - e.pos.x, twz - e.pos.z)
			if e.bt <= 0.0:
				e.bt = rnd(3, 6); var a2 := atan2(e.pos.z - twz, e.pos.x - twx) + rnd(-0.5, 0.5); var r2 := rnd(9.5, 13); e.wx = twx + cos(a2) * r2; e.wz = twz + sin(a2) * r2
				if randf() < 0.35: Snd.play("roar_" + T.roar, 1.0, e.pos)
	else:
		# its place: stand with the nose to the planks; rams start further back
		var gx: float = slot.x + slot.nx * (ns + 0.15); var gz: float = slot.z + slot.nz * (ns + 0.15)
		var vx := gx - e.pos.x; var vz := gz - e.pos.z; var d := maxf(sqrt(vx * vx + vz * vz), 0.001); var in_face := atan2(-slot.nx, -slot.nz)
		var at := Vector3(slot.x, minf(e.H * 0.6, 2.0), slot.z)
		if e.bs == "sback":   # backing off straight out from the wall for another run at it, still facing it
			mx = slot.nx; mz = slot.nz; sp = T.speed * 1.4; has_face = true; face = in_face
			if e.bt <= 0.0: e.bs = "sram"; e.bt = 2.0
		elif e.bs == "sram":
			mx = -slot.nx; mz = -slot.nz; sp = T.run * 0.7; pitch = 0.16; turn = 12.0; has_face = true; face = in_face
			if fx and randf() < dt * 10.0: fx.puff(Vector3(e.pos.x + slot.nx, 0.2, e.pos.z + slot.nz), 1, 0.55, 0.35)
			var gap: float = (e.pos.x - slot.x) * slot.nx + (e.pos.z - slot.z) * slot.nz - ns   # how far its nose is from the planks
			if gap < 0.35:
				tw.hurt(S.dmg, at); Snd.play("thud", 1.0, at); e.bs = "sgo"; e.sg_cd = rnd(S.cd[0], S.cd[1])
				if fx: fx.puff(Vector3(slot.x, 0.4, slot.z), 3, 0.55, 0.9)
			elif e.bt <= 0.0: e.bs = "sgo"
		elif e.bs == "sbite":
			var u := 1.0 - clampf(e.bt / 0.45, 0.0, 1.0); open = u / 0.6 if u < 0.6 else 1.0 - (u - 0.6) / 0.4; pitch = 0.1 * open; has_face = true; face = in_face
			if not e.hit_done and u >= 0.6: e.hit_done = true; tw.hurt(S.dmg, at); Snd.play("thud", 1.0, e.pos)
			if e.bt <= 0.0: e.bs = "sgo"; e.sg_cd = rnd(S.cd[0], S.cd[1])
		else:
			if e.bs != "sgo": e.bs = "sgo"; e.hit_done = false
			if d > 0.7:   # on its way: along the walking grid while far off, then straight to its place
				var fd2 := Phys.flow_dir(e.pos.x, e.pos.z)
				if d > 16.0 and fd2 != Vector2.ZERO: mx = fd2.x; mz = fd2.y
				else: mx = vx / d; mz = vz / d
				sp = T.run * 0.6 if d > 30.0 else (T.run * 0.45 if d > 4.0 else T.speed * 1.2)
			else:
				has_face = true; face = in_face
				if e.sg_cd <= 0.0:
					if S.get("ram", false): e.bs = "sback"; e.bt = rnd(0.7, 1.0)
					else: e.bs = "sbite"; e.bt = 0.45; e.hit_done = false
	_move(e, mx, mz, sp, dt)
	if sp > 0.0 and (e.bs == "sgo" or e.bs == "swait"): _unstick(e, e.bx0, e.bz0, mx, mz, sp, dt)
	if has_face or sp > 0.0: _turn(e, face if has_face else atan2(mx, mz), turn, dt)
	_gait(e, sp, dt)
	if e.jaw: e.jaw.rotation.x = 0.7 * open
	if e.head and e.type == "rhino": e.head.rotation.x = lerpf(e.head.rotation.x, 0.4 if e.bs == "sram" else 0.0, 1.0 - exp(-dt * 10.0))   # the horn down to ram
	e.body.rotation.x = lerpf(e.body.rotation.x, pitch, 1.0 - exp(-dt * 8.0))

## the safari's zebras once the stampede starts: they come to the tower with the rest, and just stand about it
func _zebra_mill(e: Enemies.Foe, dt: float) -> void:
	var T := e.T; e.bt -= dt; var tw: Safari = world.safari; var twx := tw.outer.position.x; var twz := tw.outer.position.z
	if e.bs != "mwalk" and e.bs != "mgraze": e.bs = "mwalk"; e.bt = 40.0; var a := rnd(0, TAU); var r := rnd(8.5, 14); e.wx = twx + cos(a) * r; e.wz = twz + sin(a) * r
	var sp := 0.0; var dx := 0.0; var dz := 0.0
	if e.bs == "mwalk":
		var wx := e.wx - e.pos.x; var wz := e.wz - e.pos.z; var l := sqrt(wx * wx + wz * wz)
		if l < 1.5 or e.bt <= 0.0: e.bs = "mgraze"; e.bt = rnd(2, 6)
		else:
			var fd := Phys.flow_dir(e.pos.x, e.pos.z)
			if l > 20.0 and fd != Vector2.ZERO and tw.standing: dx = fd.x; dz = fd.y
			else: dx = wx / l; dz = wz / l
			sp = T.speed * (2.4 if l > 25.0 else 1.0)
	elif e.bt <= 0.0: e.bs = "mwalk"; e.bt = 25.0; var a2 := rnd(0, TAU); var r2 := rnd(8.5, 14); e.wx = twx + cos(a2) * r2; e.wz = twz + sin(a2) * r2
	_move(e, dx, dz, sp, dt)
	if e.bs == "mwalk": _unstick(e, e.bx0, e.bz0, dx, dz, sp, dt)
	if sp > 0.1: _turn(e, atan2(dx, dz), T.turn, dt)
	_gait(e, sp, dt)

# ---------------- the giant gorilla and its minions ----------------
func warn(x: float, z: float, r: float) -> void:
	if ring == null:
		ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.92; tm.outer_radius = 1.0; tm.rings = 48; tm.ring_segments = 4; ring.mesh = tm
		var rm := Gfx.unlit(Color(1, 0.13, 0.13), false); ring.material_override = rm; en.add_child(ring)
	ring.position = Vector3(x, 0.06, z); ring.scale = Vector3(r, 0.05, r); ring.visible = true; ring_on = true
func unwarn() -> void:
	ring_on = false
	if ring != null and is_instance_valid(ring): ring.visible = false

func _kong_free(x: float, z: float, r: float, h: float):
	var rr := 0.0
	while rr <= 9.0:
		var n := 12 if rr > 0.0 else 1
		for i in n:
			var a := (float(i) / n) * TAU; var px := x + cos(a) * rr; var pz := z + sin(a) * rr
			if absf(px) < Phys.HALF - r - 0.4 and absf(pz) < Phys.HALF - r - 0.4 and Phys.collide_at(px, 0.05, pz, r, h) == null: return Vector2(px, pz)
		rr += 0.75
	return null

func minions() -> int:
	var n := 0
	for o in en.list:
		if o.alive and o.minion: n += 1
	return n

## the boss's roar calls seven gorillas down from the roof trusses around it
func _summon(e: Enemies.Foe) -> void:
	e.k.summons += 1; var made := 0
	for i in MINIONS_AT:
		var a := (float(i) / MINIONS_AT) * TAU + rnd(-0.25, 0.25); var r := rnd(5, 8); var p = _kong_free(e.pos.x + cos(a) * r, e.pos.z + sin(a) * r, 0.9, 2.2)
		if p == null: continue
		var mn := en.spawn("gorilla", p.x, p.y, {"kong": true, "minion": true, "hp": roundf(e.max_hp / 4.0), "scale": 1.15, "dmgMul": e.dmg_mul, "y": rnd(9, 12), "name": "고릴라 졸개", "yaw": atan2(player.pos.x - p.x, player.pos.z - p.y)})
		mn.fury = true; mn.angry = true; mn.alert = true; mn.awake = true; mn.lod = 0.0
		mn.k = {"mode": "drop", "t": 0.0, "combo": 0, "arm": 1, "hit": false, "chargeCd": rnd(2, 4), "jumpCd": 99.0, "summonCd": 99.0, "summons": 0, "engaged": 0.0, "called": false}
		made += 1
	if made == 0: return
	game.goal += made
	game.say_banner("고릴라 %d마리 소환" % made, "보스가 가슴을 두드려 동료를 불렀습니다", 2.2); _feed("고릴라 졸개 %d마리가 내려옵니다" % made)

func _kong(e: Enemies.Foe, dt: float, _time: float, dist: float, face_yaw: float) -> void:
	var K: Dictionary = KONG.boss if e.boss else KONG.minion; var sc := e.scale
	if e.k.is_empty(): e.k = {"mode": "cidle" if e.caged else "chase", "t": rnd(0, 2), "combo": 0, "arm": 1, "hit": false, "chargeCd": rnd(1.2, 2.5), "jumpCd": rnd(5, 8), "summonCd": 0.0, "summons": 0, "engaged": 0.0, "called": false}
	var k := e.k; var tx := (player.pos.x - e.pos.x) / dist; var tz := (player.pos.z - e.pos.z) / dist
	var set_mode := func(md: String) -> void: k.mode = md; k.t = 0.0; k.hit = false
	var reach_p: float = en.stop_dist(e) + K.reach; var upright := absf(player.pos.y - e.pos.y) < 2.6 * sc
	var sp := 0.0; var dirx := 0.0; var dirz := 0.0; var turn := 6.0; var move := true; var lean := 0.0
	var P := KNUCKLE.duplicate(); var rate := 12.0; var gallop := false   # the pose it eases toward (KongKit's)
	var tw: Safari = world.safari
	k.t += dt
	if not e.caged: k.chargeCd -= dt; k.jumpCd -= dt; k.summonCd -= dt; k.engaged += dt
	# 3-1's lowland gorillas live wild until something sets them off; then, while you hold the watchtower, they go for the tower with their fists
	if e.wild:
		if not e.angry and (dist < 22.0 or e.hp < e.max_hp): e.angry = true; e.alert = true
		if not e.angry:
			if k.mode != "wander": set_mode.call("wander")
		elif k.mode == "wander": e.fury = true; set_mode.call("roar")
		elif tw != null and tw.holds():
			if not (k.mode in ["roar", "sgo", "swait", "spunch"]): set_mode.call("sgo")
		elif k.mode in ["sgo", "swait", "spunch"]: set_mode.call("chase")
	if e.release_t > 0.0:   # just let out: rear up and roar
		e.release_t -= dt
		if e.release_t <= 0.0: set_mode.call("roar"); e.fury = true; e.angry = true; e.alert = true
	match k.mode:
		"wander":
			if not k.has("wx") or Vector2(k.wx - e.pos.x, k.wz - e.pos.z).length() < 1.5 or k.t > 14.0:
				var a := rnd(0, TAU); var r := rnd(5, 16); k.wx = clampf(e.pos.x + cos(a) * r, -Phys.HALF + 4, Phys.HALF - 4); k.wz = clampf(e.pos.z + sin(a) * r, -Phys.HALF + 4, Phys.HALF - 4); k.t = 0.0; k.sit = rnd(2, 6) if randf() < 0.45 else 0.0
			if k.sit > 0.0: k.sit -= dt; move = false; P.lean = 0.15; P.head = -0.15 + sin(_time * 0.7 + e.walk) * 0.25; P.aLx = -0.6; P.aRx = -0.6
			else: var v := Vector2(k.wx - e.pos.x, k.wz - e.pos.z).normalized(); dirx = v.x; dirz = v.y; sp = 1.4; turn = 3.0
		"sgo", "swait", "spunch":
			# at the watchtower: a place along its foot, or a wait a little way off; then fists into the planks
			var twx := tw.outer.position.x; var twz := tw.outer.position.z
			e.claim_t -= dt
			var slot = tw.claim(e) if (e.slot != null and e.slot.owner == e) else null
			if slot == null and e.claim_t <= 0.0: e.claim_t = rnd(0.4, 0.7); slot = tw.claim(e)
			if slot == null:
				if k.mode != "swait": set_mode.call("swait"); var a2 := atan2(e.pos.z - twz, e.pos.x - twx) + rnd(-0.4, 0.4); var r2 := rnd(9.5, 13); k.wx = twx + cos(a2) * r2; k.wz = twz + sin(a2) * r2
				var dx := float(k.wx) - e.pos.x; var dz := float(k.wz) - e.pos.z; var l := sqrt(dx * dx + dz * dz)
				if l > 1.2:
					var fd := Phys.flow_dir(e.pos.x, e.pos.z)
					if l > 16.0 and fd != Vector2.ZERO: dirx = fd.x; dirz = fd.y
					else: dirx = dx / l; dirz = dz / l
					sp = K.run if l > 16.0 else 2.0
				else:   # waiting its turn: faces the tower, beating its chest now and then
					move = false; _turn(e, atan2(twx - e.pos.x, twz - e.pos.z), 3.0, dt)
					if fmod(k.t, 6.0) < 1.6: beat_pose(P, k)
			else:
				var gx: float = slot.x + slot.nx * (en.stop_dist(e) + 0.25); var gz: float = slot.z + slot.nz * (en.stop_dist(e) + 0.25); var in_face := atan2(-slot.nx, -slot.nz)
				if k.mode == "spunch":
					var u: float = k.t / K.swing; move = false; _turn(e, in_face, 6.0, dt); lean = 0.32; rate = punch_pose(P, k.arm, u)
					if not k.hit and u >= 0.5: k.hit = true; var at := Vector3(slot.x, 1.6, slot.z); tw.hurt(Safari.SIEGE.gorilla.dmg, at); Snd.play("thud", 1.0, at)
					if k.t >= K.swing:
						k.combo -= 1; k.arm = -k.arm
						if k.combo > 0: k.t = 0.0; k.hit = false
						else: set_mode.call("sgo"); k.rest = rnd(1.4, 2.0)
				else:
					if k.mode != "sgo": set_mode.call("sgo")
					var dx2 := gx - e.pos.x; var dz2 := gz - e.pos.z; var l2 := sqrt(dx2 * dx2 + dz2 * dz2)
					k.rest = float(k.get("rest", 0.0)) - dt
					if l2 > 0.6:
						var fd2 := Phys.flow_dir(e.pos.x, e.pos.z)
						if l2 > 16.0 and fd2 != Vector2.ZERO: dirx = fd2.x; dirz = fd2.y
						else: dirx = dx2 / l2; dirz = dz2 / l2
						sp = K.run if l2 > 4.0 else 2.2
					else:
						move = false; _turn(e, in_face, 6.0, dt)
						if k.rest <= 0.0 and k.t > 0.3: set_mode.call("spunch"); k.combo = randi_range(2, 3)
		"cidle":
			if dist < 26.0: _turn(e, face_yaw, 2.0, dt)
			if k.t > 2.5:
				var r3 := randf(); set_mode.call("cbeat" if r3 < 0.3 else ("clunge" if (r3 < 0.6 and dist < 26.0) else "cpace")); k.cx = tx; k.cz = tz
				var c: Dictionary = e.cage; var ix: float = c.w / 2 - 0.5 - e.R; var iz: float = c.d / 2 - 0.5 - e.R; k.wx = c.x + rnd(-ix, ix); k.wz = c.z + rnd(-iz, iz)
		"cbeat":
			move = false; lean = -0.1; beat_pose(P, k)
			if not k.hit and k.t > 0.15: k.hit = true; Snd.play("roar_beat", 1.0, e.pos)
			if k.t > 1.8: set_mode.call("cidle")
		"cpace":
			var dx3 := float(k.wx) - e.pos.x; var dz3 := float(k.wz) - e.pos.z; var l3 := sqrt(dx3 * dx3 + dz3 * dz3)
			if l3 < 0.8 or k.t > 4.0: set_mode.call("cidle")
			else: dirx = dx3 / l3; dirz = dz3 / l3; sp = 2.2; turn = 3.0
		"clunge":
			dirx = k.cx; dirz = k.cz; sp = 6.0; turn = 4.0
			if k.t > 1.2: set_mode.call("cidle")
		"roar":
			move = false; lean = -0.1; _turn(e, face_yaw, 4.0, dt)
			P.lean = -0.1; P.aLx = -2.2; P.aLy = -0.8; P.aRx = -2.2; P.aRy = 0.8; P.head = -0.7; P.lL = -0.2; P.lR = -0.2; P.sL = 0.35; P.sR = 0.35; P.y = -0.05   # rears up and roars
			if not k.hit and k.t > 0.1: k.hit = true; Snd.play("roar_beat", 1.0, e.pos); Snd.play("rage", 1.0, e.pos); player.shake = maxf(player.shake, 0.35)
			if k.t > 1.4: set_mode.call("chase"); k.engaged = 0.0
		"drop":   # minions coming down from the roof
			move = false; lean = 0.3; en._ground_move(e, 0.0, 0.0, dt); P.lean = 0.3; P.aLx = -2.4; P.aRx = -2.4; P.lL = -0.5; P.lR = -0.5; P.sL = 0.8; P.sR = 0.8
			if e.pos.y <= Phys.ground_at(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.01: Snd.play("thud", 1.0, e.pos); set_mode.call("chase"); _puff_at(e.pos, 6, 0.8, 0.8)
		"chase":
			var fd3 := Phys.flow_dir(e.pos.x, e.pos.z)
			if dist < 40.0 and e.los: dirx = tx; dirz = tz
			elif fd3 != Vector2.ZERO: dirx = fd3.x; dirz = fd3.y
			else: dirx = tx; dirz = tz
			sp = K.run if dist > reach_p * 0.9 else 0.0; turn = 7.0
			if dist < reach_p and (upright or m != null): set_mode.call("punch"); k.combo = randi_range(2, 4)
			elif k.chargeCd <= 0.0 and dist > (7.0 if e.boss else 5.0) and dist < 34.0 and e.los: set_mode.call("windup"); Snd.play("roar_grunt", 1.0, e.pos)
			elif e.boss and k.jumpCd <= 0.0 and dist > 8.0 and dist < 30.0 and e.los: set_mode.call("crouch"); k.tgx = player.pos.x; k.tgz = player.pos.z; warn(k.tgx, k.tgz, SLAM_R)
			elif e.boss and k.summons < SUMMON_MAX and k.summonCd <= 0.0 and (e.hp < e.max_hp * 0.85 or k.engaged > 14.0) and minions() < MINIONS_AT: set_mode.call("beat")
		"punch":   # big haymakers, left and right in turn
			var S: float = K.swing; var u2: float = k.t / S; var side: int = k.arm
			_turn(e, face_yaw, 5.0, dt); sp = 1.6 * sc if dist > reach_p * 0.7 else 0.0; dirx = tx; dirz = tz; lean = 0.2; rate = punch_pose(P, side, u2)
			if u2 >= 0.38 and u2 < 0.62 and not k.hit and u2 >= 0.5:
				k.hit = true; Snd.play("swoosh", 1.0, e.pos)
				var d := face_yaw - e.yaw; d = atan2(sin(d), cos(d))
				if dist < reach_p + 0.5 and absf(d) < 1.3 and m != null: hurt_mount(K.punch * e.dmg_mul, e); Snd.play("thud", 1.0, player.pos)   # up on any animal: the one under you takes it
				elif dist < reach_p + 0.5 and absf(d) < 1.3 and upright:
					player.hurt(K.punch * e.dmg_mul, e.pos, "head"); Snd.play("thud", 1.0, player.pos)   # haymakers to the head
					if not e.boss and not game.ended: bleed_add()   # a minion's blows open wounds; the boss's do not
					var kv := 9.0 if e.boss else 5.0
					player.vel.x += (cos(e.yaw) * -side + tx * 0.5) * kv; player.vel.z += (-sin(e.yaw) * -side + tz * 0.5) * kv; player.shake = maxf(player.shake, 0.55 if e.boss else 0.3)
			if k.t >= S:
				k.combo -= 1; k.arm = -k.arm
				if k.combo > 0 and dist < reach_p + 1.0: k.t = 0.0; k.hit = false
				else: set_mode.call("chase")
		"windup":
			move = false; lean = 1.05; _turn(e, face_yaw, 10.0, dt); P.lean = 1.05; P.head = -0.7; P.aLx = -1.3; P.aRx = -1.3; P.lL = -0.35; P.lR = -0.35; P.sL = 0.6; P.sR = 0.6; P.y = -0.08
			if k.t >= K.windup: set_mode.call("charge"); k.cx = sin(e.yaw); k.cz = cos(e.yaw); _puff_at(e.pos, 3, 0.6 * e.scale, 0.6)
		"charge":
			dirx = k.cx; dirz = k.cz; sp = K.charge; turn = 0.0; lean = 0.8; gallop = true
			if randf() < dt * 14.0: _puff_at(e.pos, 1, 0.5 * e.scale, 0.4)
			if not k.hit and dist < en.stop_dist(e) + 0.7 and (upright or m != null):
				k.hit = true
				if m != null: hurt_mount(K.chargeDmg * e.dmg_mul, e)
				else:
					game.stun(e, K.stun, K.chargeDmg * e.dmg_mul)
					if not e.boss and not game.ended: bleed_add()
				set_mode.call("recover"); k.rec = K.recover
			elif k.t >= K.chargeT: set_mode.call("recover"); k.rec = K.recover
		"stagger":
			move = false; lean = 0.5; P.lean = 0.5; P.head = 0.2 + sin(k.t * 10.0) * 0.15
			if k.t >= k.rec: set_mode.call("chase"); k.chargeCd = rnd(K.chargeCd[0], K.chargeCd[1])
		"recover":
			lean = 0.7 if e.boss else 0.55; P.lean = lean
			if not e.boss: P.head = -0.1 + sin(k.t * 9.0) * 0.12; P.aLx = -0.7; P.aRx = -0.7
			if k.t >= k.rec: set_mode.call("chase"); k.chargeCd = rnd(K.chargeCd[0], K.chargeCd[1])
		"crouch":   # gathering for the leap
			move = false; lean = 0.85; _turn(e, atan2(k.tgx - e.pos.x, k.tgz - e.pos.z), 8.0, dt)
			P.lean = 0.85; P.lL = -1.0; P.lR = -1.0; P.sL = 1.5; P.sR = 1.5; P.y = -0.25; P.aLx = 0.3; P.aRx = 0.3; P.head = -0.6
			if k.t >= 0.5: var TT := 1.9; k.vx = (k.tgx - e.pos.x) / TT; k.vz = (k.tgz - e.pos.z) / TT; k.vy = 15.0 * TT / 2.0; k.air = TT; set_mode.call("air"); Snd.play("roar_grunt", 1.0, e.pos); _puff_at(e.pos, 8, 1.2 * e.scale, 1.0)
		"air":
			move = false; e.pos.x += k.vx * dt; e.pos.z += k.vz * dt; k.vy -= 15.0 * dt; e.pos.y = maxf(0.0, e.pos.y + k.vy * dt); lean = -0.1 if k.t / k.air < 0.62 else 0.5
			var ua: float = k.t / k.air; P.lean = -0.1 if ua < 0.62 else 0.5; P.aLx = -2.9 if ua < 0.62 else -0.9; P.aRx = P.aLx; P.lL = -0.6; P.lR = -0.6; P.sL = 0.9; P.sR = 0.9; P.head = -0.4; rate = 8.0 if ua < 0.62 else 22.0
			if e.pos.y <= 0.0 and k.vy < 0.0:
				# the slam: inside the ring you are dead, near it you are thrown
				e.pos.y = 0.0; unwarn()
				var dx4 := player.pos.x - e.pos.x; var dz4 := player.pos.z - e.pos.z; var d4 := maxf(sqrt(dx4 * dx4 + dz4 * dz4), 0.01)
				Snd.play("quake", 1.0, e.pos); player.shake = maxf(player.shake, 0.25 + 0.6 * (1.0 - d4 / 30.0) if d4 < 30.0 else 0.0); Snd.buzz(200)
				if fx:   # a ring of dust round the slam, and splinters
					for i in 16: var a := i / 16.0 * TAU; fx.puff(Vector3(e.pos.x + cos(a) * SLAM_R * 0.8, 0.3, e.pos.z + sin(a) * SLAM_R * 0.8), 2, 1.2, 1.0)
					fx.chunks(Vector3(e.pos.x, 0.3, e.pos.z), 10, 0.25, "wood")
				if d4 < SLAM_R and (m != null or player.pos.y < 2.2 + Phys.ground_at(player.pos.x, player.pos.y, player.pos.z, Player.R)): game.slam(e)   # riding does not save you from this one
				elif d4 < SLAM_R * 1.9: player.vel.x += dx4 / d4 * 10.0; player.vel.z += dz4 / d4 * 10.0; player.vel.y = 4.0; player.grounded = false
				var p2 = _kong_free(e.pos.x, e.pos.z, e.R, e.H)
				if p2 != null: e.pos.x = p2.x; e.pos.z = p2.y
				set_mode.call("land"); k.jumpCd = rnd(9, 13)
		"land":
			move = false; lean = 0.95; P.lean = 0.95; P.aLx = -1.25; P.aRx = -1.25; P.lL = -0.5; P.lR = -0.5; P.sL = 0.8; P.sR = 0.8; P.y = -0.15
			if k.t >= 0.6: set_mode.call("chase")
		"beat":   # chest-beating roar: seven gorillas come down
			lean = -0.15; move = false; beat_pose(P, k); _turn(e, face_yaw, 3.0, dt)
			if not k.hit and k.t > 0.15: k.hit = true; Snd.play("roar_beat", 1.0, e.pos)
			if k.t > 1.5 and not k.called: k.called = true; _summon(e)
			if k.t > 1.8: set_mode.call("chase"); k.called = false; k.summonCd = rnd(22, 28)
	if ring_on and ring != null: ring.visible = fmod(k.t * 4.5, 1.0) < 0.75
	if move and k.mode != "air":
		e.vel *= exp(-dt * 4.0)
		var walking: bool = k.mode in ["chase", "sgo", "swait", "wander"]
		if e.detour_t > 0.0:
			e.detour_t -= dt
			if walking: dirx = e.dx2; dirz = e.dz2
		var x0 := e.pos.x; var z0 := e.pos.z
		var blocked := en._ground_move(e, dirx * sp + e.vel.x, dirz * sp + e.vel.z, dt)
		if walking and sp > 0.5: _unstick(e, x0, z0, dirx, dirz, sp, dt)
		if blocked and (k.mode == "charge" or (e.boss and k.mode == "chase")) and smash(e, dirx, dirz): blocked = false
		if blocked and k.mode == "charge": set_mode.call("stagger"); k.rec = 0.45 if e.boss else 2.2; Snd.play("thud", 1.0, e.pos); _puff_front(e, 6, 0.6 * e.scale, 0.8)
		if blocked and k.mode == "clunge": set_mode.call("cidle"); world.lab.rattle(e.cage, e.pos.x + dirx * e.R, e.pos.z + dirz * e.R)
		if sp > 0.1 and turn > 0.0: _turn(e, face_yaw if (k.mode == "chase" and dist < 14.0) else atan2(dirx, dirz), turn, dt)
	if e.rig.is_empty():   # (a gorilla built without the rig: lean the body, swing a front leg)
		_gait(e, sp, dt); e.body.rotation.x = lerpf(e.body.rotation.x, lean - 0.3, 1.0 - exp(-dt * 12.0))
		if k.mode == "punch" and e.legs.size() == 4: e.legs[0 if k.arm < 0 else 1].rotation.x = -2.0 + 2.2 * clampf(k.t / K.swing, 0.0, 1.0)
	else:
		if sp > 0.1: kong_gait(P, k, sp, dt, gallop, sc)
		kong_pose(e, P, 1.0 - exp(-dt * rate))
		# keep the head and chest hit spheres on the moving body
		var cy := cos(e.yaw); var sy := sin(e.yaw)
		for pp in e.parts:
			if pp.has("node"):
				var wp: Vector3 = (pp.node as Node3D).global_position; var dx5 := wp.x - e.pos.x; var dy5 := wp.y - e.pos.y; var dz5 := wp.z - e.pos.z
				pp.o = Vector3((dx5 * cy - dz5 * sy) / sc, dy5 / sc, (dx5 * sy + dz5 * cy) / sc)
	e.roar_t -= dt
	if e.roar_t <= 0.0:
		e.roar_t = rnd(6, 12)
		if dist < 40.0: Snd.play("roar_grunt", 1.0, e.pos)

# ---------------- riding: a zebra from the floor, a giraffe from a zebra, an elephant from a giraffe ----------------
func ride_ok(e: Enemies.Foe) -> bool:
	if not e.alive or not e.animal or e.kong or e.caged or e.release_t > 0.0 or e == m or not SEAT.has(e.type): return false
	if e.tamed: return true   # one you have ridden before lets you straight back on
	return SEAT[e.type].tier <= tier + 1

## what you could get onto right now: in reach, roughly in front of you; the closest to where you look wins
func ride_find() -> Enemies.Foe:
	if not world.style.get("ride", false) or game.ended or player.stun_t > 0.0 or player.toss_on or player.fear_t > 0.0 or player.jet_on: return null
	if m == null and not player.grounded: return null
	var fx_ := -sin(player.yaw); var fz := -cos(player.yaw); var from := m.R if m != null else Player.R
	var best: Enemies.Foe = null; var bs := INF
	for e in en.list:
		if not ride_ok(e): continue
		var dx := e.pos.x - player.pos.x; var dz := e.pos.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
		if d > e.R + from + 1.6: continue
		var c := (dx * fx_ + dz * fz) / maxf(d, 0.001)
		if c < 0.15 and d > e.R + from + 0.4: continue
		var sc := d * (1.7 - c)
		if sc < bs: bs = sc; best = e
	return best

## E (or the button): get on what is in front of you; on one already with nothing new in reach, get off
func ride_toggle() -> void:
	var t := ride_find()
	if t != null: ride_on(t)
	elif m != null: ride_off(false)

func ride_on(e: Enemies.Foe) -> void:
	var prev := m
	if prev != null: _free(prev)
	m = e; tier = SEAT[e.type].tier; e.ridden = true; e.vel = Vector3.ZERO; e.kneel_t = 0.0; e.bs = "ride"; e.state = "wander"; e.windup = 0.0; _rest(e); e.bar.visible = false
	if not e.tamed: e.tamed = true; game.tame(e)
	player.jet_end(); player.fear_t = 0.0
	rvx = 0.0; rvz = 0.0; ease = 0.0; ride_from = Vector3(player.pos.x, player.pos.y + Player.EYE, player.pos.z); player.vel = Vector3.ZERO
	Snd.play("roar_" + e.T.roar, 1.0, e.pos)
	var S: Dictionary = SEAT[e.type]
	var nxt := " · 공격은 얼룩말이 대신 맞습니다 · 이대로 기린에게 다가가면 옮겨 탈 수 있습니다" if e.type == "zebra" else (" · 공포에 걸리지 않고 공격은 기린이 대신 맞습니다 · 코끼리로 옮겨 탈 수 있습니다" if e.type == "giraffe" else " · 공격은 코끼리가 대신 맞습니다")
	_feed(S.name + ((euro(S.name) + " 옮겨 탔습니다") if prev != null else "에 탔습니다") + " · 위에서도 총을 쏩니다")
	game.say_hint(S.name + " 탑승" + nxt, 3.2)

func _free(a: Enemies.Foe) -> void: a.ridden = false; a.bs = "graze"; a.bt = rnd(1, 3); a.vel = Vector3.ZERO

## step down beside it: right, left, behind or in front, wherever there is room
func ride_off(forced: bool, msg := "") -> void:
	var a := m
	if a == null: return
	m = null; tier = 0
	if a.alive: _free(a)
	var gap := a.R + Player.R + 0.35; var cy := cos(a.yaw); var sy := sin(a.yaw); var x := a.pos.x; var z := a.pos.z
	for o in [[cy, -sy], [-cy, sy], [-sy, -cy], [sy, cy]]:
		var px: float = a.pos.x + o[0] * gap; var pz: float = a.pos.z + o[1] * gap
		if absf(px) < Phys.HALF - 1 and absf(pz) < Phys.HALF - 1 and Phys.collide_at(px, a.pos.y + 0.05, pz, Player.R, Player.HEIGHT) == null: x = px; z = pz; break
	player.pos = Vector3(x, Phys.ground_at(x, a.pos.y + 0.6, z, Player.R), z); player.vel = Vector3.ZERO; player.grounded = true
	if msg != "": _feed(msg)
	elif not forced: _feed("내렸습니다")

## steering: it goes where you push, relative to where you look, and turns its body that way. you keep looking (and shooting) wherever you like
func ride_update(dt: float, f: float, s: float, run: bool, stunned: bool) -> bool:
	if m == null: return false
	var S: Dictionary = SEAT[m.type]
	if not m.alive: ride_off(true, S.name + ("이" if batchim(S.name) else "가") + " 쓰러졌습니다 · 땅에 내려섰습니다"); return false
	var wx := 0.0; var wz := 0.0; var sp := 0.0
	if not stunned:
		if player.fear_t > 0.0: wx = player.fear_x; wz = player.fear_z; sp = S.run
		elif f != 0.0 or s != 0.0:
			var sy := sin(player.yaw); var cy := cos(player.yaw); var v := Vector2(-sy * f + cy * s, -cy * f - sy * s).normalized(); wx = v.x; wz = v.y
			sp = (S.run if run else S.walk) * minf(1.0, sqrt(f * f + s * s))
	var k := 1.0 - exp(-dt * 5.0); rvx += (wx * sp - rvx) * k; rvz += (wz * sp - rvz) * k
	var B := m.buff; var x0 := m.pos.x; var z0 := m.pos.z
	if en._ground_move(m, rvx * B, rvz * B, dt):
		if m.type == "elephant" and sp > 0.0: smash(m, wx, wz)   # an elephant walks through crates
		rvx = (m.pos.x - x0) / dt / B; rvz = (m.pos.z - z0) / dt / B
	var v2 := sqrt(rvx * rvx + rvz * rvz)
	if v2 > 0.4: _turn(m, atan2(rvx, rvz), S.turn, dt)
	_gait(m, v2, dt); m.g.position = m.pos; m.g.rotation.y = m.yaw
	seat(); return true

func seat() -> void:
	var S: Dictionary = SEAT[m.type]; var sc := m.scale
	player.pos = Vector3(m.pos.x + sin(m.yaw) * S.z * sc, m.pos.y + S.y * sc - 0.7, m.pos.z + cos(m.yaw) * S.z * sc)

## the camera glides up onto the seat over a third of a second, then rides with a little sway
func ride_cam(dt: float) -> Vector3:
	var v := sqrt(rvx * rvx + rvz * rvz); var sway := sin(m.walk * 2.0) * 0.035 * clampf(v / 6.0, 0.0, 1.0)
	ease = minf(1.0, ease + dt / 0.35); var k := ease * ease * (3.0 - 2.0 * ease)
	return ride_from.lerp(Vector3(player.pos.x, player.pos.y + Player.EYE + sway, player.pos.z), k)

## a blow meant for you lands on the animal you are sitting on, and opens a wound in it (the giant gorilla's do not)
func hurt_mount(dmg: float, from: Enemies.Foe) -> void:
	var a := m
	if a == null or not a.alive: return
	a.no_pay = true   # the beasts killing it pays you nothing
	var dir := Vector3(a.pos.x - from.pos.x, 0, a.pos.z - from.pos.z); dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector3(0, 0, 1)
	en.damage(a, dmg, Vector3(a.pos.x, a.pos.y + a.H * 0.5, a.pos.z), dir, false)
	if a.alive:
		a.no_pay = false
		if not from.boss: bleed_add_to(a)
	player.shake = maxf(player.shake, 0.15)
	if player.on_hurt.is_valid(): player.on_hurt.call(6.0, from.pos)

static func batchim(w: String) -> bool:
	var c := w.unicode_at(w.length() - 1) - 0xac00; return c >= 0 and c <= 11171 and c % 28 != 0
## "으로" after a closing consonant other than ㄹ, "로" otherwise
static func euro(w: String) -> String:
	var c := w.unicode_at(w.length() - 1) - 0xac00; return "으로" if (c >= 0 and c <= 11171 and c % 28 != 0 and c % 28 != 8) else "로"

## dust where an animal hits something head on, or lands (src/07c_animals.js, 07g_beasts.js, 07f_kong.js)
func _puff_front(e: Enemies.Foe, n: int, shade: float, size: float) -> void:
	if fx: fx.puff(Vector3(e.pos.x + sin(e.yaw) * e.R, 1.0, e.pos.z + cos(e.yaw) * e.R), n, shade, size)
func _puff_at(p: Vector3, n: int, shade: float, size: float) -> void:
	if fx: fx.puff(Vector3(p.x, 0.3, p.z), n, shade, size)
