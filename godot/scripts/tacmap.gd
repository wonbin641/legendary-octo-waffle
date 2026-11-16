class_name TacMap
extends RefCounted
## The tactical map (src/08e_map.js): the stage from above, the enemies, the drop point and where you face. One drawing serves the
## briefing (where 1-2's drop point is picked) and the map screen opened with M, the pause's map button or the touch map button.
## Sizes follow the browser game: what it drew into its 1024-pixel base picture scales with the map, the markers with a 600-pixel unit.

const PAD := 4.0
const THEME := {
	1: {"bg": "1d2230", "grid": [236, 230, 216, 0.06], "block": "59606e", "blockHi": "7a8292", "wall": "8a8f99", "label": "컨테이너 부두"},
	6: {"bg": "1e2330", "grid": [236, 230, 216, 0.06], "block": "5a5f6c", "blockHi": "7b8190", "wall": "8a8f99", "label": "헬멧 부두"},
	5: {"bg": "20222e", "grid": [236, 230, 216, 0.06], "block": "5c6170", "blockHi": "7c8294", "wall": "8a8f99", "label": "무장 부두"},
	4: {"bg": "141a26", "grid": [140, 200, 255, 0.08], "block": "3f4b62", "blockHi": "6c7c9c", "wall": "8ea0c4", "label": "우주선"},
	2: {"bg": "1a2118", "grid": [200, 236, 200, 0.06], "block": "6b5741", "blockHi": "7f6a50", "wall": "4a3a28", "label": "불타는 마을"},
	3: {"bg": "2a3138", "grid": [200, 230, 235, 0.08], "block": "55606a", "blockHi": "76828c", "wall": "9aa6ae", "label": "동물 연구소"},
	8: {"bg": "262d36", "grid": [200, 220, 240, 0.08], "block": "525d68", "blockHi": "73808b", "wall": "96a2ad", "label": "차례 연구소"},
	7: {"bg": "3b3a24", "grid": [240, 230, 190, 0.07], "block": "857560", "blockHi": "9a8a70", "wall": "6a5a3a", "label": "사파리 감시탑"},
	# stage 5 is the Godot version's own: a wooden floor, the furniture lighter the higher its top
	9: {"bg": "2e261f", "grid": [255, 235, 205, 0.06], "block": "6f5d49", "blockHi": "9b8466", "wall": "c9b48f", "label": "장난감 방"},
}
## what each dot colour means, per stage; the legend under the map is built from the same table
const KINDS := {
	1: [["thug", "ff5260", "조직원"]],
	5: [["thug", "ff5260", "총 · 수류탄 · 화염"], ["dagger", "ff9a3a", "단검"], ["saber", "4f8cff", "파란 광선검"], ["saber2", "ff5ad8", "쌍광선검"], ["bat", "cfd4dc", "야구방망이"], ["bomber", "ffd23a", "자폭맨"]],
	2: [["zombie", "9be88f", "좀비"]],
	4: [["cctv", "ffd23a", "CCTV 포탑"], ["patrol", "b8ff4a", "순찰 로봇"], ["droneA", "c58bff", "드론"], ["mine", "ff5a3a", "스파이더 마인 (움직일 때만)"], ["midboss", "ffb020", "황금 지휘 드론 · 중간 보스"]],
	6: [["thug", "ff5260", "오토바이 헬멧 조직원"]],
	3: [["cat", "ff7a3a", "치타 · 호랑이 · 숫사자"], ["big", "ffc061", "물소 · 하마 · 코뿔소 · 기린 · 코끼리"], ["prey", "f0ede4", "얼룩말"], ["gorilla", "c58bff", "고릴라 졸개"], ["tame", "5ed6b0", "길들인 동물"]],
	8: [["cat", "ff7a3a", "치타 · 호랑이 · 숫사자"], ["big", "ffc061", "물소 · 하마 · 코뿔소 · 기린 · 코끼리"], ["prey", "f0ede4", "얼룩말"], ["gorilla", "c58bff", "고릴라 졸개"], ["tame", "5ed6b0", "길들인 동물"]],
	7: [["cat", "ff7a3a", "치타 · 호랑이 · 숫사자"], ["big", "ffc061", "물소 · 하마 · 코뿔소 · 기린 · 코끼리"], ["prey", "f0ede4", "얼룩말"], ["gorilla", "c58bff", "로랜드고릴라"], ["tame", "5ed6b0", "길들인 동물"]],
	9: [["soldier", "7fc96b", "플라스틱 군인"], ["figure", "ff7a3a", "액션 피규어"], ["rc", "4f8cff", "태엽·RC 유닛"], ["brick", "ffd23a", "조립 블록 피규어"]],
}
const MAP_KIND := {"cctv": "cctv", "patrol": "patrol", "droneA": "droneA", "mine": "mine", "gdrone": "midboss", "bdrone": "boss"}
const MELEE_KITS := ["saber", "saber2", "bat", "bomber", "dagger"]
const ME := Color("5ed6b0"); const SODIUM := Color("f2a33a"); const CHIP := Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.78); const INKC := Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.95)

static var COLOR := {}

var game: Game
var cam: Camera3D
var f_mono: Font; var f_bold: Font
var stage := 1
var H := 68.0; var CX := 0.0; var CZ := 0.0

static func _colors() -> Dictionary:
	if COLOR.is_empty():
		for st in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
			for k: Array in KINDS[st]: COLOR[k[0]] = Color(str(k[1]))
	return COLOR

static func half_of(st: int) -> float:
	return Lab.HALF + 2.0 if (st == 3 or st == 8) else (146.0 if st == 4 else (180.0 if st == 7 else (ToyRoom.HALF + 2.0 if st == 9 else 68.0)))

func setup(st: int) -> void:
	stage = st; H = half_of(st); CX = 19.0 if st == 4 else 0.0; CZ = 0.0   # the ship runs east of 0

func title() -> String: return THEME[stage].label

static func enemy_color(e: Enemies.Foe) -> Color:
	var C := _colors()
	if e.animal: return C["tame" if e.tamed else ("gorilla" if (e.kong and not e.boss) else (str(e.T.get("mode", "")) if str(e.T.get("mode", "")) in ["cat", "prey"] else "big"))]
	if e.robot: return C.get(MAP_KIND.get(e.type, ""), Color("8ec8ff"))
	if e.toy: return C.get(e.type, Color("ff5260"))
	if e.kit in MELEE_KITS: return C[e.kit]
	return C.get(e.type, Color("ff5260"))

## the square the map takes inside a control: centred across, at the top
static func square(size: Vector2) -> Rect2:
	var s := minf(size.x, size.y); return Rect2(Vector2((size.x - s) / 2.0, 0.0), Vector2(s, s))

## a point on a drawn map back to the ground it shows
func to_world(size: Vector2, p: Vector2) -> Vector2:
	var r := square(size); var k := r.size.x / (2.0 * (H + PAD))
	return Vector2((p.x - r.position.x) / k - H - PAD + CX, (p.y - r.position.y) / k - H - PAD + CZ)

# ---------------- drawing ----------------
## ci is the control being drawn (or anything with the same draw_* calls: the checks count what a map would show)
func draw(ci, size: Vector2) -> void:
	var r := square(size); var S := r.size.x
	if S < 8.0: return
	var o := r.position; var k := S / (2.0 * (H + PAD)); var kb := S / 1024.0; var u := S / 600.0
	var X := func(x: float) -> float: return o.x + (x - CX + H + PAD) * k
	var Z := func(z: float) -> float: return o.y + (z - CZ + H + PAD) * k
	var T: Dictionary = THEME[stage]; var w: World = game.world
	ci.draw_rect(r, Color(str(T.bg)))
	# the ground: the safari's waterhole and tracks, the yard's painted lines, a grid
	if stage == 7 and w.safari != null:
		var W := Safari.WATER
		ci.draw_circle(Vector2(X.call(W.x), Z.call(W.z)), W.r * k, Color("4a6a7a")); ci.draw_arc(Vector2(X.call(W.x), Z.call(W.z)), W.r * k, 0, TAU, 64, Color("6a4a30"), 6.0 * k)
		for line: Array in w.safari.roads:
			var pts := PackedVector2Array()
			for p: Vector2 in line: pts.push_back(Vector2(X.call(p.x), Z.call(p.y)))
			ci.draw_polyline(pts, Color(138 / 255.0, 106 / 255.0, 69 / 255.0, 0.9), 6.0 * k)
			for q in pts: ci.draw_circle(q, 3.0 * k, Color(138 / 255.0, 106 / 255.0, 69 / 255.0, 0.9))   # round joins
	if stage in [1, 5, 6]:
		var yl := Color(201 / 255.0, 150 / 255.0, 44 / 255.0, 0.25)
		for z in [-33.0, -11.0, 11.0, 33.0]: ci.draw_rect(Rect2(X.call(-64.0), Z.call(z) - kb, 128.0 * k, 2.0 * kb), yl)
		for x in [-36.0, -12.0, 12.0, 36.0]: ci.draw_rect(Rect2(X.call(x) - kb, Z.call(-64.0), 2.0 * kb, 128.0 * k), yl)
	var g: Array = T.grid; var gc := Color(g[0] / 255.0, g[1] / 255.0, g[2] / 255.0, g[3]); var gw := maxf(1.0, kb)
	var step := 10.0 if (stage == 3 or stage == 8) else (40.0 if stage == 7 else 20.0)
	var v := ceilf((CX - H) / step) * step
	while v <= CX + H: ci.draw_line(Vector2(X.call(v), Z.call(CZ - H)), Vector2(X.call(v), Z.call(CZ + H)), gc, gw); v += step
	v = ceilf((CZ - H) / step) * step
	while v <= CZ + H: ci.draw_line(Vector2(X.call(CX - H), Z.call(v)), Vector2(X.call(CX + H), Z.call(v)), gc, gw); v += step
	# the ship: once the hall's floor has fallen in, its stepped pit, each step a shade darker, the landings picked out, the depths marked
	if stage == 4 and w.ship != null and w.ship.broken:
		var cx: float = Ship.REACTOR.x; var cz: float = Ship.REACTOR.z
		var rect := func(ax: float, az: float) -> Rect2: return Rect2(X.call(cx - ax), Z.call(cz - az), 2.0 * ax * k, 2.0 * az * k)
		ci.draw_rect(rect.call(Ship.PYR_OX, Ship.PYR_OZ), Color("1b2232"))
		for s2: Dictionary in w.ship.steps:
			var f: float = float(s2.y) / Ship.PYR_BOTTOM
			ci.draw_rect(rect.call(s2.ax, s2.az), Color(94 / 255.0, 200 / 255.0, 1.0, 0.16 - f * 0.06) if s2.land else Color(8 / 255.0, 12 / 255.0, 22 / 255.0, 0.05 + f * 0.04))
		ci.draw_rect(rect.call(w.ship.pyr_bx, w.ship.pyr_bz), Color("0c111c"))
		ci.draw_rect(rect.call(Ship.PYR_OX, Ship.PYR_OZ), Color("e8b040"), false, 2.0 * kb)
		var pc := Color(160 / 255.0, 210 / 255.0, 1.0, 0.85); var fs := maxi(6, roundi(13.0 * kb))
		for s2: Dictionary in w.ship.steps:
			if s2.land: _text(ci, f_mono, "%dm" % roundi(s2.y), X.call(cx), Z.call(cz - float(s2.az) + float(s2.w) / 2.0), fs, pc)
		_text(ci, f_mono, "%dm" % roundi(Ship.PYR_BOTTOM), X.call(cx), Z.call(cz - w.ship.pyr_bz + 2.0), fs, pc)
	# what stands in the way. crates, cage walls, the watchtower and doors are drawn live; ceilings and lintels are overhead
	var toy := stage == 9; var list: Array = Phys.colliders
	if toy:   # the toy room: the floor and the room's walls left out, the furniture in the order of its height so the tops show
		list = Phys.colliders.filter(func(b: Phys.Box) -> bool: return b.maxy > 0.05 and b.maxy - b.miny <= 30.0)
		list.sort_custom(func(a: Phys.Box, b: Phys.Box) -> bool: return a.maxy < b.maxy)
	for b: Phys.Box in list:
		if b.kind == "wood" and b.ref != null: continue
		if not toy and (b.grate or b.tower or b.door or b.step or b.miny > 3.0): continue
		var bw := b.maxx - b.minx; var bd := b.maxz - b.minz
		if bw * bd < 0.5: continue
		var col: String = T.blockHi if b.maxy > 5.0 else T.block
		if toy: col = T.wall if b.maxy > 12.0 else col
		elif b.maxy >= 10.0 and (bw > 40.0 or bd > 40.0): col = T.wall   # the perimeter
		ci.draw_rect(Rect2(X.call(b.minx), Z.call(b.minz), maxf(1.5 * kb, bw * k), maxf(1.5 * kb, bd * k)), Color(col))
	if stage == 2 and w.village != null:
		for q: Array in w.village.pines: ci.draw_circle(Vector2(X.call(q[0]), Z.call(q[1])), float(q[3]) * k, Color(58 / 255.0, 74 / 255.0, 34 / 255.0, 0.85))
		for q: Array in w.village.fires:
			var rr := (2.0 + float(q[3]) * 2.5) * k
			_radial(ci, Vector2(X.call(q[0]), Z.call(q[2])), rr, [[0.0, Color(1.0, 170 / 255.0, 60 / 255.0, 0.95)], [0.4, Color(1.0, 90 / 255.0, 20 / 255.0, 0.6)], [1.0, Color(1.0, 60 / 255.0, 10 / 255.0, 0.0)]])
	if stage == 7 and w.safari != null:
		for q: Array in w.safari.trees: ci.draw_circle(Vector2(X.call(q[0]), Z.call(q[1])), float(q[3]) * k, Color(58 / 255.0, 74 / 255.0, 34 / 255.0, 0.85))
	ci.draw_rect(Rect2(X.call(CX - H), Z.call(CZ - H), 2.0 * H * k, 2.0 * H * k), Color(236 / 255.0, 230 / 255.0, 216 / 255.0, 0.5), false, 2.0 * kb)
	# ---- what moves ----
	# north and the scale first, on small dark chips inside the border, so every marker draws over them
	var edge := PAD * k + 8.0 * u; var bar := 10.0 if (stage == 3 or stage == 8) else (50.0 if stage == 7 else 20.0)
	ci.draw_rect(Rect2(o.x + edge, o.y + edge, 40.0 * u, 22.0 * u), CHIP)
	_text(ci, f_mono, "N ↑", o.x + edge + 20.0 * u, o.y + edge + 11.5 * u, roundi(13.0 * u), INKC)
	var bw2 := bar * k + 16.0 * u
	ci.draw_rect(Rect2(o.x + S - edge - bw2, o.y + S - edge - 30.0 * u, bw2, 30.0 * u), CHIP)
	ci.draw_rect(Rect2(o.x + S - edge - 8.0 * u - bar * k, o.y + S - edge - 9.0 * u, bar * k, 2.5 * u), INKC)
	_text(ci, f_mono, "%dm" % int(bar), o.x + S - edge - 8.0 * u, o.y + S - edge - 19.0 * u, roundi(11.0 * u), INKC, "right")
	# the lab's cages: shut ones as bars with the number and the seconds left, open ones as the walls lying flat
	if w.lab != null:
		var L: Lab = w.lab
		for c: Dictionary in L.cages:
			var x0: float = X.call(c.x - c.w / 2.0); var z0: float = Z.call(c.z - c.d / 2.0); var cw: float = c.w * k; var cd: float = c.d * k
			if c.open:
				var fl := Color(141 / 255.0, 148 / 255.0, 156 / 255.0, 0.18)
				ci.draw_rect(Rect2(X.call(c.x - c.w / 2.0 - c.h), z0, (c.w + 2.0 * c.h) * k, cd), fl); ci.draw_rect(Rect2(x0, Z.call(c.z - c.d / 2.0 - c.h), cw, (c.d + 2.0 * c.h) * k), fl)
				_dashed_rect(ci, Rect2(x0, z0, cw, cd), Color(141 / 255.0, 148 / 255.0, 156 / 255.0, 0.45), 1.2 * u, 4.0 * u)
			else: ci.draw_rect(Rect2(x0, z0, cw, cd), Color("c9d2da"), false, 2.4 * u)
			var remain: float = (c.open_at - L.t) if L.running else c.open_at
			var A: Dictionary = Animals.ANIMALS.get(c.type, {"name": ""})
			# the number and the animal above the cage, the seconds under it, so the dots inside stay clear
			_tag(ci, "%d %s" % [int(c.n), "보스" if c.boss else str(A.name)], X.call(c.x), z0 - 7.0 * u, u, Color("8d949c") if c.open else Color("ece6d8"))
			_tag(ci, "열림" if c.open else ("앞 우리를 비우면" if c.held else "%d초" % ceili(remain)), X.call(c.x), z0 + cd + 7.0 * u, u,
				Color("5ed6b0") if c.open else (Color("8fb8ff") if c.held else (Color("ff5260") if remain <= 5.0 else SODIUM)))
	# the safari's watchtower: its foot, the steps and how much it has left; a dashed outline once it is down
	if w.safari != null:
		var sf: Safari = w.safari; var B: float = Safari.TOWER.base; var x0 := X.call(-B) as float; var z0 := Z.call(-B) as float; var tw := 2.0 * B * k
		if sf.standing:
			ci.draw_rect(Rect2(x0, z0, tw, tw), Color("8a6440")); ci.draw_rect(Rect2(X.call(-0.7), Z.call(B), 1.4 * k, (Safari.TOWER.half + 0.5 * Safari.TOWER.steps - B) * k), Color("8a6440"))
			ci.draw_rect(Rect2(x0, z0, tw, tw), Color("f2e6c8"), false, 2.0 * u)
		else: _dashed_rect(ci, Rect2(x0, z0, tw, tw), Color(242 / 255.0, 230 / 255.0, 200 / 255.0, 0.6), 1.5 * u, 4.0 * u)
		_tag(ci, ("감시탑 %d%%" % roundi(100.0 * sf.hp / Safari.TOWER.hp)) if sf.standing else "감시탑 무너짐", X.call(0.0), z0 - 9.0 * u, u, Color("f2e6c8") if sf.standing else Color("ff8a7a"))
	for c: Dictionary in w.crates:
		if not c.dead and not c.get("wall", false): ci.draw_rect(Rect2(X.call(c.x) - 2.2 * u, Z.call(c.z) - 2.2 * u, 4.4 * u, 4.4 * u), Color("a7804e"))
	# the drop point: a helipad mark (the lab's door, the ship's airlock)
	var s0: Dictionary = w.start; var lab := stage == 3 or stage == 8; var sp := Vector2(X.call(s0.x), Z.call(s0.z))
	ci.draw_circle(sp, 11.0 * u, Color(242 / 255.0, 163 / 255.0, 58 / 255.0, 0.18)); ci.draw_arc(sp, 11.0 * u, 0, TAU, 40, SODIUM, 2.0 * u)
	if not toy: _text(ci, f_bold if lab else f_mono, "문" if lab else ("A" if stage == 4 else "H"), sp.x, sp.y + 0.5 * u, roundi((11.0 if lab else 12.0) * u), SODIUM)
	_tag(ci, "출입문" if lab else ("에어록" if stage == 4 else "내리는 곳"), sp.x + 15.0 * u, sp.y + 0.5 * u, u, SODIUM, "left")
	for e: Enemies.Foe in game.enemies.list:
		if not e.alive or e.ridden: continue   # the one you ride is under your arrow
		if e.type == "mine" and (e.bs == "hidden" or e.bs == ""): continue   # buried mines stay hidden, even here
		var ep := Vector2(X.call(e.pos.x), Z.call(e.pos.z))
		if e.boss:
			ci.draw_circle(ep, 7.0 * u, Color("ff2d3d")); ci.draw_arc(ep, 7.0 * u, 0, TAU, 28, Color.WHITE, 1.6 * u)
			_tag(ci, "보스", ep.x, ep.y - 13.0 * u, u, Color.WHITE)
		else:
			var rr := (5.5 if e.T.get("mid", false) else (4.2 if (e.animal and e.R > 0.9) else 3.2)) * u
			var col := enemy_color(e)
			if e.toy and game.enemies.toys != null and game.enemies.toys.camo(e): col.a = 0.45   # a soldier gone still: fainter
			ci.draw_circle(ep, rr, col)
			if e.alert or e.angry: ci.draw_arc(ep, rr + 2.0 * u, 0, TAU, 24, Color.WHITE, 1.2 * u)
	# you: where you stand, the way you face and a cone of what you see (north on the map is -z)
	var pl: Player = game.player; var pp := Vector2(X.call(pl.pos.x), Z.call(pl.pos.z)); var ang := atan2(-cos(pl.yaw), -sin(pl.yaw))
	var fov := deg_to_rad(cam.fov if cam != null else 75.0) * 0.6; var cone := PackedVector2Array([pp]); var cc := PackedColorArray([Color(ME, 0.45)])
	for i in 17:
		var a := ang - fov / 2.0 + fov * i / 16.0; cone.push_back(pp + Vector2(cos(a), sin(a)) * 60.0 * u); cc.push_back(Color(ME, 0.0))
	ci.draw_polygon(cone, cc)
	var rot := func(p: Vector2) -> Vector2: return pp + p.rotated(ang) * u
	var arrow := PackedVector2Array([rot.call(Vector2(11, 0)), rot.call(Vector2(-7, 7)), rot.call(Vector2(-3, 0)), rot.call(Vector2(-7, -7))])
	ci.draw_colored_polygon(arrow, ME); arrow.push_back(arrow[0]); ci.draw_polyline(arrow, Color("0d1220"), 1.5 * u)

## a label with a dark edge round it, so it reads over anything
func _tag(ci, text: String, x: float, y: float, u: float, color: Color, align := "center") -> void:
	_text(ci, f_bold, text, x, y, roundi(11.0 * u), color, align, 3.5 * u, Color(13 / 255.0, 18 / 255.0, 32 / 255.0, 0.9))

## text placed like the canvas's: x by the alignment, y through the middle of the letters
static func _text(ci, font: Font, text: String, x: float, y: float, fs: int, color: Color, align := "center", outline := 0.0, ocolor := Color.BLACK) -> void:
	fs = maxi(fs, 4); var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var px := x - w / 2.0 if align == "center" else (x if align == "left" else x - w)
	var py := y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	if outline > 0.0: ci.draw_string_outline(font, Vector2(px, py), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, roundi(outline)), ocolor)
	ci.draw_string(font, Vector2(px, py), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

static func _dashed_rect(ci, r: Rect2, color: Color, width: float, dash: float) -> void:
	var a := r.position; var b := a + Vector2(r.size.x, 0); var c := r.end; var d := a + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]: ci.draw_dashed_line(seg[0], seg[1], color, width, dash)

## a round glow: rings of colour from the middle out, as the canvas's radial gradient
static func _radial(ci, c: Vector2, r: float, stops: Array) -> void:
	var n := 20
	for si in stops.size() - 1:
		var r0: float = r * float(stops[si][0]); var r1: float = r * float(stops[si + 1][0]); var c0: Color = stops[si][1]; var c1: Color = stops[si + 1][1]
		for i in n:
			var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
			var pts := PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r0, c + Vector2(cos(a0), sin(a0)) * r1, c + Vector2(cos(a1), sin(a1)) * r1, c + Vector2(cos(a1), sin(a1)) * r0])
			if r0 <= 0.0: ci.draw_polygon(PackedVector2Array([c, pts[1], pts[2]]), PackedColorArray([c0, c1, c1]))
			else: ci.draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))

# ---------------- the legend ----------------
## the legend's items: [kind, text, colour, letter]; drawn by legend_icon
func legend(live: bool) -> Array:
	var lab := stage == 3 or stage == 8; var out := []
	out.push_back(["me", "나 · 바라보는 방향", ME, ""])
	var lz := "출입문 · 시작하는 곳" if lab else ("에어록 · 시작하는 곳" if stage == 4 else ("내리는 곳 · 지도를 눌러 바꾸기" if (stage == 5 and not live) else ("내리는 곳" if stage == 9 else "헬기에서 내리는 곳")))
	out.push_back(["lz", lz, SODIUM, "" if stage == 9 else ("문" if lab else ("A" if stage == 4 else "H"))])
	for kd: Array in KINDS[stage]: out.push_back(["en", kd[2], Color(str(kd[1])), ""])
	if stage == 7: out.push_back(["tw", "감시탑 · 체력", Color("8a6440"), ""])
	elif stage != 9: out.push_back(["bo", "보스", Color("ff2d3d"), ""])
	out.push_back(["cr", "나무 상자", Color("a7804e"), ""])
	if lab: out.push_back(["cg", "우리 · 번호와 열리는 시간", Color("c9d2da"), ""])
	if live: out.push_back(["al", "흰 테두리 · 나를 쫓는 중", Color.WHITE, ""])
	return out

## the small picture in front of a legend line, drawn into a control of 18 x 18
func legend_icon(ci, item: Array) -> void:
	var c := Vector2(9, 9); var col: Color = item[2]
	match str(item[0]):
		"me": ci.draw_colored_polygon(PackedVector2Array([Vector2(3.5, 3), Vector2(14.5, 9), Vector2(3.5, 15)]), col)
		"lz":
			ci.draw_rect(Rect2(1.5, 1.5, 15, 15), col, false, 2.0)
			if str(item[3]) != "": _text(ci, f_mono, str(item[3]), 9.0, 9.0, 10, col)
		"en": ci.draw_circle(c, 5.0, col)
		"al": ci.draw_arc(c, 5.0, 0, TAU, 20, col, 2.0)
		"bo": ci.draw_circle(c, 6.5, col); ci.draw_arc(c, 5.5, 0, TAU, 24, Color.WHITE, 2.0)
		"cr": ci.draw_rect(Rect2(4, 4, 10, 10), col)
		"cg": ci.draw_rect(Rect2(4, 4, 11, 11), col, false, 2.0)
		"tw": ci.draw_rect(Rect2(2.5, 2.5, 13, 13), col); ci.draw_rect(Rect2(3.5, 3.5, 11, 11), Color("f2e6c8"), false, 2.0)
