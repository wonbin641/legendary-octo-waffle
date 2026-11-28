class_name Caldera
extends RefCounted
## 6-B, the obsidian altar of the abyss (the map paper's first part, 심연의 흑요석 제단): a caldera of boiling lava, and over
## it three rings of black glass, one above another round its middle (the paper's three tiers):
##   up      the inquisitor's gallery (고문관의 감시 회랑): two half rings of terrace along the cliff, looking down on the
##           middle; at their ends the brimstone watch-spires (유황 감시 첨탑): a stair inside each from the middle ring
##           up past the gallery's door to a lookout on top; on the gallery's edge the hellfire braziers' rings (지옥불
##           증폭 화로: a shot through one burns, and hits a fifth harder)
##   middle  the blood-moon sanctum (혈월의 심연 제단): an octagon of obsidian hung on four great chains in the middle, four
##           horned pillars at its corners, the cooling circle at its heart (냉각의 흑요석 진: weapons cool half as fast
##           again on it); round it the middle ring in four arcs (six metres of lava between them), each joined to the
##           sanctum by a chained titan's bridge (구속된 거인의 사슬 다리, 3.5 m wide, nothing under it); the two soul
##           foundries (흑요석 영혼 용광로) across the west and east arcs, a narrow way under a low roof through each, a quench
##           trough at their inner doors (연금술 냉각 수조: what burns on you is put out)
##   down    the sulphur rift trench (유황 균열 협곡): stepping stones just over the lava, round between the sanctum and the
##           ring; soul-forged chains to climb up to the ring (영혼 포집 쇠사슬: hold jump; nothing fires while you climb);
##           the blood-pact gates (혈약의 차원문: 35 of your health and you stand on the gallery above)
## The magma tide (용암 조석): the lava rises over the stones, and four floating slabs of obsidian come up out of it on the
## diagonals between the sanctum and the ring. Over it all the colossal ribs of a demon lord (거대 심연 군주의 늑골 아치) and
## burning rune chains (타오르는 룬 쇠사슬, beating faster as the fight goes on); braziers that spill fire when struck
## (불안정한 유황 화로), scrying slabs of black glass to hide behind (흑요석 점술 방패); ash-spore caps (잿빛 포자 화산버섯: a
## cloud of ash for four seconds, in which no demon far off sees you), sanguine briars (흡혈 가시 덩굴: slow you, cut you,
## feed the demons by them), vitrified glass-cacti (유리화 수정 선인장: shattered, they cut whoever is by them for 40).
## Everything stood on is boxes (round things are many of them, row by row); the floor under it all is the lava (Phys.PIT)

const HALF := 66.0
const LAVA_Y := 0.0; const TIDE_Y := 1.85; const PIT_Y := -0.6     # the lava's face, risen, and the pit's floor under it
const LOW_Y := 1.2                                                  # the trench's stones
const MID_Y := 7.0                                                  # the sanctum and the middle ring
const GAL_Y := 14.0                                                 # the gallery
const LOOK_Y := 22.0                                                # the spires' lookouts
const DAIS_A := 12.0                                                # the sanctum's octagon: from its middle to a side
const RING_R0 := 30.0; const RING_R1 := 42.0                        # the middle ring
const GAL_R0 := 47.0; const GAL_R1 := 55.6                          # the gallery
const RIM_R := 55.5                                                 # the caldera's wall
const BRIDGE_W := 3.5
const STONE_R := 21.5                                               # the trench's ring of stones
const GAP_DEG := 9.55                                               # six metres of lava between two arcs of the ring (at its middle)
const ARCS := {"e": 0.0, "n": 90.0, "w": 180.0, "s": 270.0}         # the middle ring's arcs, by their middles (deg)
const GALLERY := {"n": [44.0, 136.0], "s": [224.0, 316.0]}          # the gallery's two halves (deg)
const SPIRES := [36.0, 144.0, 216.0, 324.0]; const SPIRE_R := 51.0  # the watch-spires, just past the gallery's ends
const SP_H := 4.0; const SP_WT := 0.5; const SP_COL := 2.2           # a spire: its half width, its walls, its stair's middle column
const CHAINS_AT := [20.0, 160.0, 200.0, 340.0]                      # where a soul chain hangs from the ring's inner edge (deg)
const GATES := {"n": Vector3(0.0, LOW_Y, STONE_R), "s": Vector3(0.0, LOW_Y, -STONE_R)}   # the blood-pact gates...
const GATE_TO := {"n": Vector3(0.0, GAL_Y, 51.0), "s": Vector3(0.0, GAL_Y, -51.0)}       # ...and where they take you
const GATE_COST := 35.0
const COOL_R := 3.2; const COOL_K := 1.5                             # the cooling circle, and how much faster it cools a gun
const AMPS := [70.0, 110.0, 250.0, 290.0]                           # the hellfire braziers' rings on the gallery's edge (deg)
const AMP_R := 1.5; const AMP_K := 1.2
const FLOATS := [45.0, 135.0, 225.0, 315.0]                         # the tide's floating slabs, on the diagonals...
const FLOAT_IN := 13.5; const FLOAT_OUT := 28.5; const FLOAT_W := 5.0   # ...from beside the sanctum out to beside the ring
const FOUNDRY := {"w": Vector3(-37.0, MID_Y, 0.0), "e": Vector3(37.0, MID_Y, 0.0)}
const BRAZIER := {"r": 4.0, "t": 5.0, "burn": 18.0, "back": 20.0}  # a brazier knocked over: its fire on the ground, how long, how hot; stood up again after
const CAP := {"r": 5.0, "t": 4.0, "back": 18.0}                    # an ash-spore cap burst: its cloud, how long; grown again after
const BRIAR := {"slow": 0.85, "dps": 5.0, "heal": 4.0, "heal_r": 6.0}
const CACTUS := {"dmg": 40.0, "r": 1.6}
const LAVA := {"hit": 90.0, "every": 0.35, "rise": 2.3}            # in the lava: what each scald costs, how often, how high it throws you

const C_OBS := Color("15121a"); const C_OBS2 := Color("231c26"); const C_ROCK := Color("2e2626"); const C_ROCK2 := Color("3a302c"); const C_BASALT := Color("1f1a1c")
const C_IRON := Color("3a3c40"); const C_IRON2 := Color("55575c"); const C_BONE := Color("cfc2a4")
const C_LAVA := Color("ff6a1a"); const C_LAVA2 := Color("ffb347"); const C_EMBER := Color("ff3a12"); const C_RUNE := Color("ff2a3a"); const C_COLD := Color("6ad8ff"); const C_GLASS := Color("2a1f30")

var world: World; var G: Node3D
var kits: Array = []          # what is lit (the art shader's obsidian, iron, bone): a mesh for each quarter of the map
var glow := MeshKit.new()     # what shines by itself: lava falls, veins of fire
var clear := MeshKit.new()    # what is seen through: the scrying slabs' glass, the gates' air
var mat: ShaderMaterial; var _mat_glow: StandardMaterial3D; var _mat_clear: StandardMaterial3D
var posts: Array = []         # where the demons stand: {type, x, y, z, yaw, perch, fly, boss}
var perches: Array = []       # where the inquisitor can stand above the fight (Vector3)
var braziers: Array = []      # {at, node, flame, down, t, box}
var fires: Array = []         # fire on the ground: {at, r, t}
var caps: Array = []          # {at, node, t}
var clouds: Array = []        # ash in the air: {at, r, t}
var briars: Array = []        # {a, b, r}: a stretch of the thorny vines (a segment, its reach)
var cacti: Array = []         # {at, node, t}
var troughs: Array = []       # Vector3
var slabs: Array = []         # the scrying slabs: {at, yaw}
var chains: Array = []        # the soul chains: {at (where you hold it), top, deg}
var floats: Array = []        # the tide's slabs: {deg, node, up}
var amps: Array = []          # {at, n (the ring's face, inward)}
var stones: Array = []        # the trench's stones: {at, r, top}
var spires: Array = []        # {c, box (its outline: x0, z0, x1, z1)}
var openings: Array = []      # where the ring's parapet is open (a causeway out): {x0, z0, x1, z1}
var lamps_at: Array = []
var lava_n: MeshInstance3D = null; var _lava_mat: ShaderMaterial = null
var rune_mat: ShaderMaterial = null   # the rune chains' glow (its beat follows the fight: pulse)
var player: Player; var game; var enemies: Enemies; var fx: Fx; var proj: Proj
var rm = null                 # a realm battle here (Realm): it moves its own fighters about the place
var t := 0.0
var tide := 0.0               # 0: the lava at rest; 1: risen over the stones (the floating slabs up)
var tide_on := false
var lava_y := LAVA_Y
var pulse := 0.0              # how far the fight has gone (0..1): the rune chains beat faster with it
var _gate_cd := 0.0; var _told := {}; var _climb := false; var _scald := 0.0; var _vine_t := 0.0

# ---------------- building helpers ----------------
func _k(x: float, z: float) -> ArtKit: return kits[(1 if x > 0.0 else 0) + (2 if z > 0.0 else 0)]

## boxes covering whatever `inside(x, z)` says is inside, in the box x0..x1, z0..z1: row by row (z, `cz` apart), each run
## along x (sampled `cx` apart) one box, from y0 to y1
func _raster(inside: Callable, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, cz := 0.5, cx := 0.3, kind := "concrete") -> Array:
	var out: Array = []; var z := z0 + cz * 0.5
	while z < z1:
		var run = null; var x := x0
		while x <= x1 + cx:
			var ins: bool = x <= x1 and inside.call(x, z)
			if ins and run == null: run = x - cx * 0.5
			elif not ins and run != null: out.push_back(Phys.add_collider(run, y0, z - cz * 0.5, x - cx * 0.5, y1, z + cz * 0.5, kind)); run = null
			x += cx
		z += cz
	return out

static func in_ring(x: float, z: float, r0: float, r1: float, a0d: float, a1d: float) -> bool:
	var r := sqrt(x * x + z * z)
	if r < r0 or r > r1: return false
	if a1d - a0d >= 359.9: return true
	return fposmod(rad_to_deg(atan2(z, x)) - a0d, 360.0) <= a1d - a0d
static func in_octagon(x: float, z: float, a: float) -> bool:
	var ax := absf(x); var az := absf(z)
	return ax <= a and az <= a and (ax + az) <= a * 1.4142
static func in_box(x: float, z: float, b: Dictionary, grow := 0.0) -> bool:
	return x >= float(b.x0) - grow and x <= float(b.x1) + grow and z >= float(b.z0) - grow and z <= float(b.z1) + grow
## inside a strip from a to b (its middle line), w wide
static func in_band(x: float, z: float, a: Vector3, b: Vector3, w: float) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z); var L := d.length(); var u := d / L; var q := Vector2(x - a.x, z - a.z); var s := q.dot(u)
	return s >= 0.0 and s <= L and absf(q.dot(Vector2(-u.y, u.x))) <= w * 0.5

func solid_ring(r0: float, r1: float, a0d: float, a1d: float, y0: float, y1: float, except: Array = []) -> void:
	var inside := func(x: float, z: float) -> bool:
		if not in_ring(x, z, r0, r1, a0d, a1d): return false
		for b: Dictionary in except:
			if in_box(x, z, b, 0.15): return false
		return true
	var bb := Rect2(Vector2(cos(deg_to_rad(a0d)), sin(deg_to_rad(a0d))) * r0, Vector2.ZERO)   # (only the box round the arc is looked at)
	if a1d - a0d >= 359.9: bb = Rect2(-r1, -r1, r1 * 2.0, r1 * 2.0)
	else:
		for i in 25:
			var a := deg_to_rad(lerpf(a0d, a1d, i / 24.0)); var d := Vector2(cos(a), sin(a))
			bb = bb.expand(d * r0).expand(d * r1)
	_raster(inside, bb.position.x - 0.3, bb.end.x + 0.3, bb.position.y - 0.3, bb.end.y + 0.3, y0, y1)
func solid_disc(c: Vector3, r: float, y0: float, y1: float) -> void:
	_raster(func(x: float, z: float) -> bool: return Vector2(x - c.x, z - c.z).length() <= r, c.x - r, c.x + r, c.z - r, c.z + r, y0, y1, 0.4, 0.25)
func solid_band(a: Vector3, b: Vector3, w: float, y0: float, y1: float, kind := "concrete") -> Array:
	return _raster(func(x: float, z: float) -> bool: return in_band(x, z, a, b, w), minf(a.x, b.x) - w, maxf(a.x, b.x) + w, minf(a.z, b.z) - w, maxf(a.z, b.z) + w, y0, y1, 0.4, 0.25, kind)

static func at_deg(deg: float, r: float, y: float) -> Vector3:
	var a := deg_to_rad(deg); return Vector3(cos(a) * r, y, sin(a) * r)

func post(type: String, p: Vector3, yaw: float, more := {}) -> void:
	var q := {"type": type, "x": p.x, "y": p.y, "z": p.z, "yaw": yaw}; q.merge(more); posts.push_back(q)
## the way from p to the middle, as a yaw (what a demon faces at its post)
static func yaw_in(p: Vector3) -> float: return atan2(-p.x, -p.z)

## the pieces of an arc a0..a1 (deg) at radius r that are not in an opening (for the parapet's mesh)
func _arc_open(a0: float, a1: float, r: float) -> Array:
	var cuts: Array = []
	for o: Dictionary in openings:
		var c := Vector3((float(o.x0) + float(o.x1)) * 0.5, 0, (float(o.z0) + float(o.z1)) * 0.5)
		if absf(Vector2(c.x, c.z).length() - r) > 10.0: continue
		var hit := false; var lo := INF; var hi := -INF
		for i in 121:   # (where the arc runs through the opening's box)
			var a := lerpf(a0, a1, i / 120.0); var p := at_deg(a, r, 0.0)
			if in_box(p.x, p.z, o, 0.2): hit = true; lo = minf(lo, a); hi = maxf(hi, a)
		if hit: cuts.push_back([lo - 0.6, hi + 0.6])
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var out: Array = []; var s := a0
	for c: Array in cuts:
		if float(c[0]) > s: out.push_back([s, minf(float(c[0]), a1)])
		s = maxf(s, float(c[1]))
	if s < a1: out.push_back([s, a1])
	return out

## the pieces of the ring's inner edge a0..a1 (deg) that have a lip: not where a bridge, a stair down or a chain meets it
func _arc_inner(a0: float, a1: float) -> Array:
	var cuts: Array = []
	for m: float in [0.0, 90.0, 180.0, 270.0]: cuts.push_back([m - 4.5, m + 4.5])   # (the bridges, 3.5 m wide)
	for c: float in CHAINS_AT: cuts.push_back([c - 2.5, c + 2.5])
	for x: float in [-9.0, 9.0]:   # (the stairs down: the north one at x = -9, the south at +9)
		var z := sqrt(RING_R0 * RING_R0 - x * x) * (1.0 if x < 0.0 else -1.0); var a := rad_to_deg(atan2(z, x)); cuts.push_back([a - 3.2, a + 3.2])
	var out: Array = []; var s := a0
	var list: Array = []
	for c: Array in cuts:   # (each cut brought into the arc's own turn of the circle)
		var lo := float(c[0]); var hi := float(c[1])
		while lo < a0 - 180.0: lo += 360.0; hi += 360.0
		while lo > a0 + 180.0: lo -= 360.0; hi -= 360.0
		if hi > a0 and lo < a1: list.push_back([lo, hi])
	list.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for c: Array in list:
		if float(c[0]) > s: out.push_back([s, minf(float(c[0]), a1)])
		s = maxf(s, float(c[1]))
	if s < a1: out.push_back([s, a1])
	return out

# ---------------- the map ----------------
func build(w: World, group: Node3D) -> void:
	world = w; G = group
	Phys.set_world_size(HALF); Phys.set_nav(int(HALF * 2.0) + 4, 1.0)
	Phys.PIT = {"x0": -HALF - 10.0, "x1": HALF + 10.0, "z0": -HALF - 10.0, "z1": HALF + 10.0, "y": PIT_Y}
	for i in 4: var k := ArtKit.new(); k.detail = 0.8; kits.push_back(k)
	mat = RaceArt.mat(false, {1: [C_LAVA, 2.2], 2: [C_RUNE, 2.4], 3: [C_LAVA, 0.55], 4: [C_COLD, 1.8], 5: [C_LAVA2, 2.0]})
	_tune(mat)
	_spires()   # (first: the ring's parapet and the gallery leave room for them)
	_rim(); _dais(); _bridges(); _ring(); _gallery(); _trench(); _ribs(); _floats(); _lava()
	_posts()
	_meshes()
	world.start = {"x": FOUNDRY.w.x - 2.0, "z": 0.0, "yaw": -PI / 2.0, "y": MID_Y}; world.spawns.clear()
	for l: Vector3 in lamps_at: world.lamps.push_back({"x": l.x, "y": l.y, "z": l.z})
	Phys.index_colliders(); Phys.build_nav()

## the art shader for the place: big tiles of pattern, the studio's light leaning to the lava's
static func _tune(m: ShaderMaterial) -> void:
	m.set_shader_parameter("pscale", 1.6); m.set_shader_parameter("far", 40.0); m.set_shader_parameter("env_k", 0.28); m.set_shader_parameter("tint", Vector3(0.78, 0.46, 0.36))

func _meshes() -> void:
	for k: ArtKit in kits:
		if not k.is_empty(): k.node(mat, G, "Caldera")
	_mat_glow = Gfx.unlit(Color.WHITE, false); _mat_glow.vertex_color_use_as_albedo = true
	if not glow.is_empty(): var gn := glow.node(_mat_glow, G); gn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; gn.name = "CalderaGlow"
	_mat_clear = Gfx.unlit(Color.WHITE, false); _mat_clear.vertex_color_use_as_albedo = true; _mat_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _mat_clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not clear.is_empty(): var cn := clear.node(Gfx.see_through(_mat_clear), G); cn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; cn.name = "CalderaGlass"

## the caldera's wall: a ring of black basalt round it all, ledges on it, lava falling down it in threads
func _rim() -> void:
	for q in 4:
		var a0 := q * 90.0; var mid := at_deg(a0 + 45.0, 50.0, 0.0); var k := _k(mid.x, mid.z)
		k.paint(C_BASALT, 0.1, 0.8, ArtKit.IRON)
		k.ring_sector(0, 0, RIM_R, RIM_R + 8.0, deg_to_rad(a0), deg_to_rad(a0 + 90.0), PIT_Y - 1.0, 36.0, 24, false)
		k.paint(C_ROCK, 0.1, 0.85, ArtKit.IRON)
		for j in 6:   # (ledges and buttresses of rock along it)
			var a := a0 + 7.0 + j * 14.0; var y := 3.0 + fposmod(j * 7.3 + q * 3.1, 20.0)
			k.ring_sector(0, 0, RIM_R - 1.2, RIM_R + 0.2, deg_to_rad(a), deg_to_rad(a + 6.0), y, y + 1.4, 3)
	solid_ring(RIM_R, RIM_R + 4.0, 0.0, 360.0, PIT_Y - 1.0, 60.0)
	for i in 14:   # threads of lava down the wall
		var a := deg_to_rad(i * 25.7 + 9.0); var p := Vector3(cos(a), 0, sin(a)) * (RIM_R - 0.05)
		glow.ribbon(p + Vector3(0, 30.0 - fposmod(i * 3.7, 12.0), 0), p + Vector3(0, LAVA_Y + 0.2, 0), 0.5 + fposmod(i * 0.37, 0.6), C_LAVA.lerp(C_LAVA2, fposmod(i * 0.41, 1.0)), -p.normalized())

## the lava: a disc as wide as the caldera, boiling (its own shader: crusts drifting over a bright flow)
const LAVA_SH := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float heat = 1.0;
%s
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz; vec2 p = wp.xz * 0.075;
	float n1 = texture(noise_tex, p * 0.6 + vec2(TIME * 0.011, TIME * 0.006)).b;
	float n2 = texture(noise_tex, p * 1.7 - vec2(TIME * 0.019, -TIME * 0.013)).r;
	float cell = texture(noise_tex, p + vec2(-TIME * 0.004, TIME * 0.003)).a;
	float crust = max(smoothstep(0.015, 0.11, cell), smoothstep(0.5, 0.72, n1) * 0.7);   // (dark plates of cooled rock drifting on it)
	vec3 hot = mix(vec3(0.92, 0.2, 0.02), vec3(1.0, 0.58, 0.1), n2 * n2) * (1.05 + 0.25 * heat);
	vec3 dark = mix(vec3(0.045, 0.012, 0.01), vec3(0.16, 0.035, 0.015), n2);
	ALBEDO = albedo_of(mix(hot, dark, crust));
}
"""
func _lava() -> void:
	var sh := Shader.new(); sh.code = LAVA_SH % Gfx.ALBEDO_GLSL
	_lava_mat = ShaderMaterial.new(); _lava_mat.shader = sh; _lava_mat.set_shader_parameter("noise_tex", RaceArt.noise_tex())
	var k := MeshKit.new(); k.disc(0, LAVA_Y, 0, RIM_R + 1.0, Color.WHITE, 64)
	lava_n = k.node(_lava_mat, G); lava_n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; lava_n.name = "Lava"
	for i in 8: lamps_at.push_back(at_deg(i * 45.0 + 22.5, 25.0, 2.0))

## the sanctum: the octagon of obsidian in the middle; its four horned pillars, the cooling circle at its heart, scrying
## slabs round it, braziers by the bridges' heads, veins of fire running in to its middle
func _dais() -> void:
	var R := DAIS_A / cos(PI / 8.0); var top := Vector3(0, MID_Y, 0)
	for j in 8:
		var a0 := deg_to_rad(22.5 + j * 45.0); var a1 := a0 + PI / 4.0
		var p0 := Vector3(cos(a0) * R, 0, sin(a0) * R); var p1 := Vector3(cos(a1) * R, 0, sin(a1) * R); var nm := ((p0 + p1) * 0.5).normalized(); var k := _k(nm.x, nm.z)
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.quad(top, p1 + top, p0 + top, top, Vector3.UP)
		k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
		k.quad(p0 + Vector3(0, MID_Y - 1.6, 0), p1 + Vector3(0, MID_Y - 1.6, 0), p1 + top, p0 + top, nm)
		k.quad(p0 * 0.55 + Vector3(0, MID_Y - 4.5, 0), p1 * 0.55 + Vector3(0, MID_Y - 4.5, 0), p1 + Vector3(0, MID_Y - 1.6, 0), p0 + Vector3(0, MID_Y - 1.6, 0), (nm + Vector3.DOWN * 0.8).normalized())
	_raster(func(x: float, z: float) -> bool: return in_octagon(x, z, DAIS_A), -DAIS_A, DAIS_A, -DAIS_A, DAIS_A, MID_Y - 1.6, MID_Y)
	for j in 8:   # the veins of fire, in from its corners to the cooling circle
		var d := at_deg(22.5 + j * 45.0, 1.0, 0.0)
		glow.strip(d * (COOL_R + 0.4) + Vector3(0, MID_Y + 0.02, 0), d * (R - 0.6) + Vector3(0, MID_Y + 0.02, 0), 0.22, C_EMBER, true)
	# the cooling circle: a disc of blue-black glass ringed in frost-light, runes round it
	var kc: ArtKit = kits[0]
	kc.paint(Color("10202c"), 0.4, 0.05, ArtKit.OBSIDIAN, 4, 0.2); kc.ring_sector(0, 0, 0.0, COOL_R, 0.0, TAU, MID_Y, MID_Y + 0.04, 24, false)
	kc.paint(C_COLD, 0.0, 0.4, ArtKit.PLAIN, 4, 1.0); kc.ring_sector(0, 0, COOL_R - 0.18, COOL_R, 0.0, TAU, MID_Y + 0.04, MID_Y + 0.06, 32, false)
	for i in 6:
		var a := i * TAU / 6.0; kc.toward(Vector3(cos(a) * (COOL_R - 0.9), MID_Y + 0.05, sin(a) * (COOL_R - 0.9)), Vector3.DOWN, Vector3(cos(a), 0, sin(a))); kc.rune(400 + i, 0.6, 0.08, 0.0); kc.pop()
	# the four horned pillars at its corners (cover, a little), their runes
	for j in 4:
		var a := deg_to_rad(45.0 + j * 90.0); var dd := Vector3(cos(a), 0, sin(a)); var c := dd * 9.6 + top; var k := _k(c.x, c.z)
		k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
		var path := ArtKit.spline([c, c + Vector3(0, 2.5, 0), c - dd * 0.6 + Vector3(0, 4.6, 0), c - dd * 1.8 + Vector3(0, 6.0, 0)], 5)
		var rr := PackedFloat32Array()
		for i in path.size(): var u := float(i) / (path.size() - 1); rr.push_back(lerpf(0.75, 0.06, pow(u, 0.9)))
		k.tube(path, rr, 8)
		Phys.add_collider(c.x - 0.62, MID_Y, c.z - 0.62, c.x + 0.62, MID_Y + 4.0, c.z + 0.62, "concrete")
		k.paint(C_RUNE, 0.0, 0.5, ArtKit.PLAIN, 2, 1.0)
		for i in 3: k.toward(c - dd * 0.7 + Vector3(0, 1.0 + i * 1.0, 0), dd); k.rune(410 + j * 3 + i, 0.4, 0.07, 0.0); k.pop()
		lamps_at.push_back(c + Vector3(0, 3.0, 0))
	for j in 4: var a := 45.0 + j * 90.0; _slab(at_deg(a, 6.6, MID_Y), deg_to_rad(a) + PI / 2.0)   # scrying slabs, inside the pillars
	for j in 4:   # braziers by the bridges' heads
		var d := at_deg(j * 90.0, 1.0, 0.0); var tn := Vector3(-d.z, 0, d.x)
		for s: float in [1.0, -1.0]: _brazier(d * (DAIS_A - 1.2) + tn * s * 3.0 + top)

## a scrying slab: a leaning sheet of black glass, waist-high cover
func _slab(c: Vector3, yaw: float) -> void:
	var u := Vector3(cos(yaw), 0, sin(yaw)); var h := 1.25; var nrm := Vector3(-u.z, 0, u.x)
	clear.quad(c - u * 1.3, c + u * 1.3, c + u * 1.2 + Vector3(0, h, 0), c - u * 1.2 + Vector3(0, h, 0), Color(0.16, 0.1, 0.2, 0.55), nrm)
	var k := _k(c.x, c.z); k.paint(C_IRON2, 0.8, 0.45, ArtKit.IRON)
	for s: float in [1.0, -1.0]: k.tube(PackedVector3Array([c + u * s * 1.3, c + u * s * 1.2 + Vector3(0, h, 0)]), 0.06, 6)
	k.tube(PackedVector3Array([c - u * 1.3 + Vector3(0, 0.03, 0), c + u * 1.3 + Vector3(0, 0.03, 0)]), 0.05, 5)
	solid_band(c - u * 1.3, c + u * 1.3, 0.22, c.y, c.y + h)
	slabs.push_back({"at": c, "yaw": yaw})

## a brazier of iron on three legs, burning: struck, it goes over and spills its fire
func _brazier(at: Vector3) -> void:
	var n := Node3D.new(); n.position = at; n.name = "Brazier"; G.add_child(n)
	RaceArt.piece(n, "cd_brazier", func(k: ArtKit) -> void: _brazier_mesh(k), mat)
	var fl := RaceArt.sprite(Color(1.0, 0.5, 0.15, 0.75), 1.4, n); fl.position = Vector3(0, 1.5, 0)
	braziers.push_back({"at": at, "node": n, "flame": fl, "down": false, "t": 0.0, "box": Phys.add_collider(at.x - 0.45, at.y, at.z - 0.45, at.x + 0.45, at.y + 1.2, at.z + 0.45, "metal")})
	lamps_at.push_back(at + Vector3(0, 1.6, 0))
static func _brazier_mesh(k: ArtKit) -> void:
	k.paint(C_IRON, 0.85, 0.5, ArtKit.IRON)
	for i in 3: var a := i * TAU / 3.0; k.tube(PackedVector3Array([Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), Vector3(cos(a) * 0.32, 0.9, sin(a) * 0.32)]), 0.05, 6)
	k.lathe(PackedVector2Array([Vector2(0.05, 0.82), Vector2(0.3, 0.85), Vector2(0.55, 1.05), Vector2(0.6, 1.2), Vector2(0.52, 1.18)]), 14)
	k.paint(C_LAVA2, 0.0, 0.4, ArtKit.PLAIN, 5, 1.0); k.ball(Vector3(0, 1.12, 0), Vector3(0.45, 0.12, 0.45), 10, 4)

## the chained titans' bridges: from the sanctum's four sides out to the ring's arcs, iron plates between two great chains
func _bridges() -> void:
	for side: String in ARCS:
		var d := at_deg(float(ARCS[side]), 1.0, 0.0); var tn := Vector3(-d.z, 0, d.x)
		var p0 := d * (DAIS_A - 0.3); var p1 := d * (RING_R0 + 0.6); var hw := BRIDGE_W * 0.5; var k := _k(d.x * 20.0 + 0.01, d.z * 20.0 + 0.01)
		var n := int(p0.distance_to(p1) / 1.1)
		for i in n:   # the plates, each a little apart
			var u0 := float(i) / n; var u1 := (i + 0.92) / n
			var a0 := p0.lerp(p1, u0) + Vector3(0, MID_Y, 0); var a1 := p0.lerp(p1, u1) + Vector3(0, MID_Y, 0)
			k.paint(C_IRON if i % 2 == 0 else C_IRON2.darkened(0.2), 0.8, 0.55, ArtKit.IRON)
			k.quad(a0 - tn * hw, a1 - tn * hw, a1 + tn * hw, a0 + tn * hw, Vector3.UP)
			k.quad(a0 - tn * hw - Vector3(0, 0.15, 0), a1 - tn * hw - Vector3(0, 0.15, 0), a1 + tn * hw - Vector3(0, 0.15, 0), a0 + tn * hw - Vector3(0, 0.15, 0), Vector3.DOWN)
			k.quad(a0 + tn * hw - Vector3(0, 0.15, 0), a1 + tn * hw - Vector3(0, 0.15, 0), a1 + tn * hw, a0 + tn * hw, tn)
			k.quad(a0 - tn * hw - Vector3(0, 0.15, 0), a1 - tn * hw - Vector3(0, 0.15, 0), a1 - tn * hw, a0 - tn * hw, -tn)
		for s: float in [1.0, -1.0]:   # the two great chains along its sides, sagging, and posts up to them
			var pts := PackedVector3Array()
			for i in 13: var u := i / 12.0; pts.push_back(p0.lerp(p1, u) + tn * s * (hw + 0.2) + Vector3(0, MID_Y + 1.1 - 0.45 * sin(PI * u), 0))
			k.paint(C_IRON, 0.9, 0.45, ArtKit.IRON)
			for i in 12:
				var q0 := pts[i]; var q1 := pts[i + 1]
				k.toward((q0 + q1) * 0.5, (q1 - q0).normalized()); k.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)), Vector3.ZERO)); k.link((q1 - q0).length() * 1.05, 0.34, 0.07, 5); k.pop(); k.pop()
			k.paint(C_IRON2, 0.85, 0.5, ArtKit.IRON)
			for i in 5: var u := (i + 0.5) / 5.0; var q := p0.lerp(p1, u) + tn * s * (hw + 0.2); k.tube(PackedVector3Array([q + Vector3(0, MID_Y, 0), q + Vector3(0, MID_Y + 1.1 - 0.45 * sin(PI * u), 0)]), 0.05, 5)
		var ax := Vector3(absf(tn.x), 0, absf(tn.z))
		var lo := Vector3(minf(p0.x, p1.x), 0, minf(p0.z, p1.z)) - ax * hw; var hi := Vector3(maxf(p0.x, p1.x), 0, maxf(p0.z, p1.z)) + ax * hw
		Phys.add_collider(lo.x, MID_Y - 1.0, lo.z, hi.x, MID_Y, hi.z, "metal")
		for s: float in [1.0, -1.0]:   # (the chains as rails: knee-high, so nobody walks off by mistake)
			var r0 := Vector3(minf(p0.x, p1.x), 0, minf(p0.z, p1.z)) + tn * s * (hw + 0.2) - ax * 0.1; var r1 := Vector3(maxf(p0.x, p1.x), 0, maxf(p0.z, p1.z)) + tn * s * (hw + 0.2) + ax * 0.1
			Phys.add_collider(minf(r0.x, r1.x), MID_Y, minf(r0.z, r1.z), maxf(r0.x, r1.x), MID_Y + 0.7, maxf(r0.z, r1.z), "metal")

## the middle ring: four arcs of obsidian round the sanctum, a low parapet on their outer edge (open where a causeway goes
## out to a spire); the soul foundries on the west and east arcs; the stairs down to the trench
func _ring() -> void:
	for side: String in ARCS:
		var m := float(ARCS[side]); var a0 := m - 45.0 + GAP_DEG * 0.5; var a1 := m + 45.0 - GAP_DEG * 0.5
		for q in 2:   # (an arc in two halves, each in its quarter's mesh)
			var b0 := a0 + q * (a1 - a0) * 0.5; var b1 := b0 + (a1 - a0) * 0.5; var mid := at_deg((b0 + b1) * 0.5, 36.0, 0.0); var k := _k(mid.x, mid.z)
			k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.ring_sector(0, 0, RING_R0, RING_R1, deg_to_rad(b0), deg_to_rad(b1), MID_Y - 2.5, MID_Y, 14, false, true)
			k.paint(C_ROCK, 0.1, 0.8, ArtKit.IRON); k.ring_sector(0, 0, RING_R0 + 2.0, RING_R1 - 2.0, deg_to_rad(b0), deg_to_rad(b1), PIT_Y, MID_Y - 2.5, 8, false)
			k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
			for piece: Array in _arc_open(b0, b1, RING_R1 - 0.3): k.ring_sector(0, 0, RING_R1 - 0.6, RING_R1, deg_to_rad(float(piece[0])), deg_to_rad(float(piece[1])), MID_Y, MID_Y + 0.85, maxi(1, int((float(piece[1]) - float(piece[0])) / 3.0)), true)
		for e: Array in [[a0, -1.0], [a1, 1.0]]:   # (its ends: faces of rock down into the lava)
			var d := at_deg(float(e[0]), 1.0, 0.0); var k := _k(d.x * 36.0, d.z * 36.0); var tn := Vector3(-d.z, 0, d.x) * float(e[1])
			k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.quad(d * RING_R0 + Vector3(0, PIT_Y, 0), d * RING_R1 + Vector3(0, PIT_Y, 0), d * RING_R1 + Vector3(0, MID_Y, 0), d * RING_R0 + Vector3(0, MID_Y, 0), tn)
		solid_ring(RING_R0, RING_R1, a0, a1, MID_Y - 2.5, MID_Y)
		solid_ring(RING_R1 - 0.6, RING_R1, a0, a1, MID_Y, MID_Y + 0.85, openings)
		# a knee-high lip on its inner edge too (open where a bridge, a stair or a chain meets it)
		for piece: Array in _arc_inner(a0, a1):
			var b0: float = piece[0]; var b1: float = piece[1]; var mid := at_deg((b0 + b1) * 0.5, 36.0, 0.0)
			_k(mid.x, mid.z).paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); _k(mid.x, mid.z).ring_sector(0, 0, RING_R0, RING_R0 + 0.45, deg_to_rad(b0), deg_to_rad(b1), MID_Y, MID_Y + 0.7, maxi(1, int((b1 - b0) / 3.0)), true)
			solid_ring(RING_R0, RING_R0 + 0.45, b0, b1, MID_Y, MID_Y + 0.7)
		for i in 5:   # veins of fire across it, running in toward the sanctum
			var a := lerpf(a0 + 4.0, a1 - 4.0, i / 4.0)
			glow.strip(at_deg(a, RING_R0 + 0.4, MID_Y + 0.02), at_deg(a + 3.0 * sin(i * 1.3), RING_R1 - 0.8, MID_Y + 0.02), 0.16, C_EMBER.darkened(0.15), true)
	_foundry("w"); _foundry("e")
	# the stairs down to the trench, from the north and south arcs' inner edges
	for s: float in [1.0, -1.0]:
		var x := -9.0 * s; var z_top := sqrt(RING_R0 * RING_R0 - x * x) * s; var run := 6.2
		var n := int(ceil((MID_Y - LOW_Y) / 0.28)); var k := _k(x, z_top)
		for i in n:
			var y1 := MID_Y - (i + 1) * (MID_Y - LOW_Y) / (n + 1); var za := z_top + 0.4 * s - (i * run / n) * s; var zb := z_top + 0.4 * s - ((i + 1) * run / n) * s
			k.paint(C_ROCK2 if i % 2 == 0 else C_ROCK, 0.1, 0.8, ArtKit.IRON); k.slab(x - 1.3, PIT_Y, minf(za, zb), x + 1.3, y1, maxf(za, zb))
			Phys.add_collider(x - 1.3, PIT_Y, minf(za, zb), x + 1.3, y1, maxf(za, zb), "concrete")
		_stone(Vector3(x, LOW_Y, z_top + 0.4 * s - run * s - 1.4 * s), 1.8)

## a soul foundry: a squat furnace-hall of obsidian across the arc, a narrow way through it under a low roof (the last
## line a side holds), the fire inside; a quench trough sunk in the floor at its inner door; sanguine briars on its walls
func _foundry(side: String) -> void:
	var c: Vector3 = FOUNDRY[side]; var s := 1.0 if side == "e" else -1.0; var k := _k(c.x, c.z + 0.01)
	var x0 := c.x - 4.5; var x1 := c.x + 4.5; var z0 := c.z - 6.5; var z1 := c.z + 6.5; var y0 := MID_Y; var y1 := MID_Y + 5.0
	k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
	for zz: Array in [[z0, c.z - 1.3], [c.z + 1.3, z1]]:   # its two halves, the way between them
		k.slab(x0, y0, float(zz[0]), x1, y1, float(zz[1])); Phys.add_collider(x0, y0, float(zz[0]), x1, y1, float(zz[1]), "concrete")
	k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(x0, y0 + 2.6, c.z - 1.3, x1, y1, c.z + 1.3, true); Phys.add_collider(x0, y0 + 2.6, c.z - 1.3, x1, y1, c.z + 1.3, "concrete")   # (the low roof over the way)
	k.paint(C_ROCK, 0.1, 0.8, ArtKit.IRON); k.slab(x0 - 0.3, y1, z0 - 0.3, x1 + 0.3, y1 + 0.5, z1 + 0.3)
	for zc: float in [z0 + 2.0, z1 - 2.0]:   # its chimneys, glowing at the top
		k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.at(Vector3(c.x, y1 + 0.5, zc)); k.cyl(1.2, 0.8, 4.5, 10, false); k.pop()
		glow.disc(c.x, y1 + 4.95, zc, 0.75, C_LAVA, 10); lamps_at.push_back(Vector3(c.x, y1 + 5.5, zc))
	for zz: float in [c.z - 1.15, c.z + 1.15]: glow.strip(Vector3(x0 + 0.5, y0 + 0.03, zz), Vector3(x1 - 0.5, y0 + 0.03, zz), 0.25, C_LAVA2, true)   # molten iron along the way's sides
	# the quench trough at the inner door: blue alchemy in an iron rim, sunk level with the floor (you wade through it)
	var tq := c - Vector3(s * 5.7, 0, 0)
	k.paint(C_IRON, 0.85, 0.5, ArtKit.IRON)
	for b: Array in [[-0.6, -1.7, 0.6, -1.5], [-0.6, 1.5, 0.6, 1.7], [-0.6, -1.5, -0.45, 1.5], [0.45, -1.5, 0.6, 1.5]]: k.slab(tq.x + float(b[0]), y0, tq.z + float(b[1]), tq.x + float(b[2]), y0 + 0.1, tq.z + float(b[3]))
	glow.slab(tq.x - 0.45, y0 - 0.02, tq.z - 1.5, tq.x + 0.45, y0 + 0.03, tq.z + 1.5, Color("3ad0ff"))
	troughs.push_back(tq); lamps_at.push_back(tq + Vector3(0, 1.0, 0))
	for zz: float in [z0 - 0.08, z1 + 0.08]: _briar(Vector3(x0 + 0.8, y0 + 0.2, zz), Vector3(x1 - 0.8, y0 + 3.2, zz), 1.2)   # briars up its walls

## sanguine briars: thorny red vines along a wall from a to b (touching them slows and cuts; they feed the demons near)
func _briar(a: Vector3, b: Vector3, reach: float) -> void:
	var k := _k(a.x, a.z + 0.01); var rng := RandomNumberGenerator.new(); rng.seed = int(absf(a.x) * 13.0 + absf(a.z) * 7.0 + a.y)
	var off := Vector3(0, 0, signf(a.z) * 0.12)
	for v in 4:
		var pts: Array = []
		for i in 7: var u := i / 6.0; pts.push_back(a.lerp(b, u) + off + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.8, 0.8) + (v - 1.5) * 0.5 - (b.y - a.y) * (u - 0.5) * 0.6, 0.0))
		k.paint(Color("6a1018"), 0.0, 0.6, ArtKit.SKIN); k.tube(ArtKit.spline(pts, 4), 0.06, 5)
		k.paint(Color("b0202a"), 0.0, 0.5, ArtKit.PLAIN, 4, 0.35)
		for i in 10: var q: Vector3 = pts[mini(6, i * 6 / 10)]; k.ball(q + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), 0), Vector3.ONE * 0.09, 5, 3)
	briars.push_back({"a": a, "b": b, "r": reach})

## the inquisitor's gallery: two half rings of terrace along the wall, a parapet along their inner edge; the hellfire
## braziers' rings on it; ash banners on the wall behind
func _gallery() -> void:
	var holes: Array = []
	for sp: Dictionary in spires: holes.push_back(sp.box)
	for side: String in GALLERY:
		var a0: float = GALLERY[side][0]; var a1: float = GALLERY[side][1]
		for q in 2:
			var b0 := a0 + q * (a1 - a0) * 0.5; var b1 := b0 + (a1 - a0) * 0.5; var mid := at_deg((b0 + b1) * 0.5, 50.0, 0.0); var k := _k(mid.x, mid.z)
			k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.ring_sector(0, 0, GAL_R0, GAL_R1, deg_to_rad(b0), deg_to_rad(b1), GAL_Y - 1.8, GAL_Y, 18, true, true)
			k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.ring_sector(0, 0, GAL_R0, GAL_R0 + 0.5, deg_to_rad(b0), deg_to_rad(b1), GAL_Y, GAL_Y + 0.95, 18, true)
			k.paint(C_ROCK, 0.1, 0.8, ArtKit.IRON)
			for j in 3: var p := at_deg(lerpf(b0, b1, (j + 0.5) / 3.0), (GAL_R0 + GAL_R1) * 0.5, 0.0); k.at(Vector3(p.x, PIT_Y, p.z)); k.cyl(1.6, 1.1, GAL_Y - 1.8 - PIT_Y, 8, false); k.pop()   # (its piers, down into the lava)
		solid_ring(GAL_R0, GAL_R1, a0, a1, GAL_Y - 1.8, GAL_Y, holes)
		solid_ring(GAL_R0, GAL_R0 + 0.5, a0, a1, GAL_Y, GAL_Y + 0.95, holes)
		for i in 9:   # ash banners on the wall behind it
			var a := lerpf(a0 + 6.0, a1 - 6.0, i / 8.0); var p := at_deg(a, RIM_R - 0.1, 0.0); var tn := at_deg(a + 90.0, 1.0, 0.0); var inw := -p.normalized()
			var rows: Array = []
			for j in 5: var u := j / 4.0; rows.push_back(PackedVector3Array([p - tn * 0.9 + Vector3(0, GAL_Y + 9.0 - u * 6.5, 0) + inw * u * 0.3, p + tn * 0.9 + Vector3(0, GAL_Y + 9.0 - u * 6.5, 0) + inw * u * 0.3]))
			var kb := _k(p.x, p.z); kb.paint(Color("3a3436"), 0.0, 0.9, ArtKit.CLOTH); kb.sheet(rows, inw)
			kb.paint(C_RUNE, 0.0, 0.5, ArtKit.PLAIN, 2, 0.8); kb.toward(p + inw * 0.25 + Vector3(0, GAL_Y + 6.4, 0), -inw); kb.rune(470 + i, 0.8, 0.09, 0.0); kb.pop()
	for deg: float in AMPS:   # the hellfire braziers' rings: an iron hoop on the parapet, embers round it, facing the middle (shoot down through it, over the parapet)
		var p := at_deg(deg, GAL_R0 + 0.25, GAL_Y + 0.95 + AMP_R + 0.1); var d := Vector3(-p.x, 0, -p.z).normalized(); var k := _k(p.x, p.z)
		k.paint(C_IRON, 0.85, 0.45, ArtKit.IRON); k.toward(p, d); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(AMP_R, 0.12, 28, 6); k.pop(); k.pop()
		k.paint(C_LAVA2, 0.0, 0.4, ArtKit.PLAIN, 5, 1.0); k.toward(p, d)
		for i in 8: var a := i * TAU / 8.0; k.ball(Vector3(cos(a) * AMP_R, sin(a) * AMP_R, 0), Vector3.ONE * 0.16, 6, 4)
		k.pop()
		for sd: float in [1.0, -1.0]: var tn := Vector3(-d.z, 0, d.x) * sd; k.paint(C_IRON2, 0.85, 0.5, ArtKit.IRON); k.tube(PackedVector3Array([p + tn * AMP_R * 0.7 - Vector3(0, AMP_R * 0.7, 0), p + tn * (AMP_R + 0.2) - Vector3(0, AMP_R + 0.1, 0)]), 0.07, 6)   # (its two feet on the parapet)
		_vdisc(clear, p, AMP_R - 0.1, d, Color(1.0, 0.35, 0.08, 0.22))   # (the heat shimmering in it)
		amps.push_back({"at": p, "n": d}); lamps_at.push_back(p)
		perches.push_back(at_deg(deg + 5.0, 51.0, GAL_Y))

## the brimstone watch-spires: a square tower of obsidian standing in the lava just past each end of the gallery; a door
## at the ring's height (a causeway out to it from the ring), a door at the gallery's (a short bridge on to it), the
## lookout on top under four leaning horns. Inside, a stair goes round a middle column along the walls, a flight a wall,
## two turns: the first up to the gallery's door, the second to the lookout (open over its last two flights)
func _spires() -> void:
	for deg: float in SPIRES:
		var c := at_deg(deg, SPIRE_R, 0.0); var sx := signf(c.x); var sz := signf(c.z); var h := SP_H; var wt := SP_WT; var ih := h - wt
		var box := {"x0": c.x - h, "z0": c.z - h, "x1": c.x + h, "z1": c.z + h}
		spires.push_back({"c": c, "box": box})
		var k := _k(c.x, c.z)
		# the corner the stair starts and turns at (both doors are by it): toward the middle in x, toward the gallery in z
		var cx0 := c.x - sx * ih; var cx1 := c.x - sx * SP_COL; var cz0 := c.z + sz * SP_COL; var cz1 := c.z + sz * ih
		var lower := {"x": c.x - sx * (h - wt * 0.5), "z0": minf(cz0, cz1), "z1": maxf(cz0, cz1)}    # the door to the ring, in the wall facing the middle
		var upper := {"z": c.z + sz * (h - wt * 0.5), "x0": minf(cx0, cx1), "x1": maxf(cx0, cx1)}   # the door to the gallery
		var top := LOOK_Y + 1.0
		for wx: float in [c.x - h + wt * 0.5, c.x + h - wt * 0.5]:   # the walls, each with its door cut out
			var door := absf(wx - float(lower.x)) < 0.01
			_wall_x(k, wx, wt, c.z - h, c.z + h, PIT_Y, top, [float(lower.z0), float(lower.z1), MID_Y, MID_Y + 2.6] if door else [])
		for wz: float in [c.z - h + wt * 0.5, c.z + h - wt * 0.5]:
			var door := absf(wz - float(upper.z)) < 0.01
			_wall_z(k, wz, wt, c.x - h + wt, c.x + h - wt, PIT_Y, top, [float(upper.x0), float(upper.x1), GAL_Y, GAL_Y + 2.6] if door else [])
		# the ground floor at the ring's height, the middle column, the stair
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(c.x - ih, MID_Y - 0.6, c.z - ih, c.x + ih, MID_Y, c.z + ih); Phys.add_collider(c.x - ih, MID_Y - 0.6, c.z - ih, c.x + ih, MID_Y, c.z + ih, "concrete")
		k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(c.x - SP_COL, MID_Y, c.z - SP_COL, c.x + SP_COL, LOOK_Y, c.z + SP_COL); Phys.add_collider(c.x - SP_COL, MID_Y, c.z - SP_COL, c.x + SP_COL, LOOK_Y, c.z + SP_COL, "concrete")
		_spire_stair(k, c, sx, sz)
		for i in 4:   # the horns over the lookout
			var cxx := c.x + (h - 0.35) * (1.0 if i % 2 == 0 else -1.0); var czz := c.z + (h - 0.35) * (1.0 if i < 2 else -1.0)
			var path := ArtKit.spline([Vector3(cxx, top, czz), Vector3(cxx, top + 3.0, czz), Vector3(lerpf(cxx, c.x, 0.6), top + 7.0, lerpf(czz, c.z, 0.6)), Vector3(c.x, top + 10.0, c.z)], 4)
			var rr := PackedFloat32Array()
			for j in path.size(): var u := float(j) / (path.size() - 1); rr.push_back(lerpf(0.45, 0.04, u))
			k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.tube(path, rr, 6)
		glow.cyl(c.x, LOOK_Y, c.z, 0.5, 0.3, 0.5, C_LAVA2, 8, true); lamps_at.push_back(Vector3(c.x, LOOK_Y + 1.5, c.z)); lamps_at.push_back(Vector3(c.x - sx * 2.85, GAL_Y + 1.5, c.z + sz * 2.85))
		for n4: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:   # arrow slits lit from inside, two rows up each wall
			var fc := c + n4 * (h + 0.02); var tn := n4.cross(Vector3.UP)
			for hy: float in [10.8, 18.6]:
				for off: float in [-1.7, 1.7]: glow.ribbon(fc + tn * off + Vector3(0, hy - 0.7, 0), fc + tn * off + Vector3(0, hy + 0.7, 0), 0.2, C_LAVA.darkened(0.15), n4)
		# the causeway from the ring out to the lower door: straight along x, its far end on the ring
		var zc := (float(lower.z0) + float(lower.z1)) * 0.5; var xr := sx * sqrt(maxf(0.0, RING_R1 * RING_R1 - zc * zc)); var xd := c.x - sx * h
		var cw := {"x0": minf(xr - sx * 1.2, xd), "z0": zc - 1.25, "x1": maxf(xr - sx * 1.2, xd), "z1": zc + 1.25}
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(float(cw.x0), MID_Y - 1.0, float(cw.z0), float(cw.x1), MID_Y, float(cw.z1), true)
		Phys.add_collider(float(cw.x0), MID_Y - 1.0, float(cw.z0), float(cw.x1), MID_Y, float(cw.z1), "concrete")
		k.paint(C_ROCK, 0.1, 0.8, ArtKit.IRON); k.at(Vector3((xr + xd) * 0.5, PIT_Y, zc)); k.cyl(1.4, 1.0, MID_Y - 1.0 - PIT_Y, 8, false); k.pop()
		openings.push_back(cw)
		# the short bridge from the upper door on to the gallery's end
		var xm := (float(upper.x0) + float(upper.x1)) * 0.5; var zd := c.z + sz * h; var zf := zd
		var gal: Array = GALLERY.n if sz > 0.0 else GALLERY.s
		for i in 80:
			zf += sz * 0.1
			if in_ring(xm, zf, GAL_R0 + 0.8, GAL_R1 - 0.8, float(gal[0]), float(gal[1])): break
		zf += sz * 1.0
		var br := {"x0": xm - 0.85, "z0": minf(zd, zf), "x1": xm + 0.85, "z1": maxf(zd, zf)}
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(float(br.x0), GAL_Y - 0.6, float(br.z0), float(br.x1), GAL_Y, float(br.z1), true)
		Phys.add_collider(float(br.x0), GAL_Y - 0.6, float(br.z0), float(br.x1), GAL_Y, float(br.z1), "concrete")
		perches.push_back(Vector3(c.x, LOOK_Y, c.z))

## a wall facing along x at x = wx (wt thick), from z0 to z1 and y0 to y1; door: [za, zb, ya, yb] cut out of it, or empty
func _wall_x(k: ArtKit, wx: float, wt: float, z0: float, z1: float, y0: float, y1: float, door: Array) -> void:
	var x0 := wx - wt * 0.5; var x1 := wx + wt * 0.5; var parts: Array = []
	if door.is_empty(): parts = [[z0, y0, z1, y1]]
	else:
		var za: float = door[0]; var zb: float = door[1]; var ya: float = door[2]; var yb: float = door[3]
		parts = [[z0, y0, z1, ya], [z0, yb, z1, y1], [z0, ya, za, yb], [zb, ya, z1, yb]]
	k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
	for p: Array in parts:
		if float(p[2]) - float(p[0]) < 0.01 or float(p[3]) - float(p[1]) < 0.01: continue
		k.slab(x0, float(p[1]), float(p[0]), x1, float(p[3]), float(p[2])); Phys.add_collider(x0, float(p[1]), float(p[0]), x1, float(p[3]), float(p[2]), "concrete")
func _wall_z(k: ArtKit, wz: float, wt: float, x0: float, x1: float, y0: float, y1: float, door: Array) -> void:
	var z0 := wz - wt * 0.5; var z1 := wz + wt * 0.5; var parts: Array = []
	if door.is_empty(): parts = [[x0, y0, x1, y1]]
	else:
		var xa: float = door[0]; var xb: float = door[1]; var ya: float = door[2]; var yb: float = door[3]
		parts = [[x0, y0, x1, ya], [x0, yb, x1, y1], [x0, ya, xa, yb], [xb, ya, x1, yb]]
	k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
	for p: Array in parts:
		if float(p[2]) - float(p[0]) < 0.01 or float(p[3]) - float(p[1]) < 0.01: continue
		k.slab(float(p[0]), float(p[1]), z0, float(p[2]), float(p[3]), z1); Phys.add_collider(float(p[0]), float(p[1]), z0, float(p[2]), float(p[3]), z1, "concrete")

## the stair in a spire: eight flights round the column, one along each wall, a landing at each corner. It starts at
## the doors' corner (C0) on the ground floor (7 m), is back there at 14 m (the gallery's door), and ends there at 22 m
## on the lookout. The lookout's floor covers the column and the first two flights' walls; over the last two it is open
const SP_FLIGHTS := [[7, 0.25], [7, 0.25], [7, 0.25], [7, 0.25], [8, 0.25], [8, 0.25], [8, 0.25], [8, 0.25]]   # steps, rise of each
func _spire_stair(k: ArtKit, c: Vector3, sx: float, sz: float) -> void:
	var band := (SP_COL + SP_H - SP_WT) * 0.5; var bw := (SP_H - SP_WT) - SP_COL
	var corners := [Vector2(-sx, sz), Vector2(sx, sz), Vector2(sx, -sz), Vector2(-sx, -sz)]   # C0..C3 round the column
	var y := MID_Y
	for f in SP_FLIGHTS.size():
		var a: Vector2 = corners[f % 4]; var b: Vector2 = corners[(f + 1) % 4]; var n: int = SP_FLIGHTS[f][0]; var rise: float = SP_FLIGHTS[f][1]
		var along := (b - a) * 0.5   # (unit along the wall, from a's corner to b's)
		var side := (a + b) * 0.5 * band   # (the wall's middle, out from the column)
		var nrm := Vector2(absf(along.y), absf(along.x)) * bw * 0.5
		for j in n:
			y += rise
			var u0 := -SP_COL + 2.0 * SP_COL * float(j) / n; var u1 := -SP_COL + 2.0 * SP_COL * float(j + 1) / n
			var p0 := side + along * u0; var p1 := side + along * u1
			var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - nrm; var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + nrm
			k.paint(C_ROCK2 if j % 2 == 0 else C_ROCK, 0.1, 0.8, ArtKit.IRON); k.slab(c.x + lo.x, y - 0.35, c.z + lo.y, c.x + hi.x, y, c.z + hi.y, true)
			Phys.add_collider(c.x + lo.x, y - 0.35, c.z + lo.y, c.x + hi.x, y, c.z + hi.y, "concrete")
		var lc := b * band; var hb := bw * 0.5   # the landing at the corner it reaches
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(c.x + lc.x - hb, y - 0.35, c.z + lc.y - hb, c.x + lc.x + hb, y, c.z + lc.y + hb, true)
		Phys.add_collider(c.x + lc.x - hb, y - 0.35, c.z + lc.y - hb, c.x + lc.x + hb, y, c.z + lc.y + hb, "concrete")
	for f in 2:   # the lookout's floor: over the first two flights' walls and their corners
		var a: Vector2 = corners[f]; var b: Vector2 = corners[f + 1]; var side := (a + b) * 0.5 * band; var along := (b - a) * 0.5; var nrm := Vector2(absf(along.y), absf(along.x)) * bw * 0.5
		var p0 := side - along * (SP_COL + bw); var p1 := side + along * (SP_COL + bw)
		var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - nrm; var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + nrm
		k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(c.x + lo.x, LOOK_Y - 0.4, c.z + lo.y, c.x + hi.x, LOOK_Y, c.z + hi.y, true)
		Phys.add_collider(c.x + lo.x, LOOK_Y - 0.4, c.z + lo.y, c.x + hi.x, LOOK_Y, c.z + hi.y, "concrete")

## the sulphur rift trench: stepping stones in a ring between the sanctum and the middle ring, spurs out to the soul chains
## and the blood-pact gates; glass-cacti in their cracks, ash-spore caps
func _trench() -> void:
	var n := 36
	for i in n:
		var a := i * 360.0 / n + 3.0 * sin(i * 1.7); var r := STONE_R + 1.2 * sin(i * 2.3)
		_stone(at_deg(a, r, LOW_Y + 0.12 * sin(i * 3.1)), 1.25 + 0.25 * fposmod(i * 0.37, 1.0))
	for deg: float in CHAINS_AT:   # spurs out to the chains, and the chains up to the ring's edge
		for r: float in [STONE_R + 3.0, STONE_R + 5.6]: _stone(at_deg(deg + 1.5, r, LOW_Y), 1.2)
		var foot := at_deg(deg, RING_R0 - 1.4, LOW_Y); _stone(foot, 1.3)
		var hold := at_deg(deg, RING_R0 - 0.5, LOW_Y); var top := at_deg(deg, RING_R0 + 0.8, MID_Y)
		var k := _k(foot.x, foot.z); k.paint(C_IRON, 0.9, 0.45, ArtKit.IRON, 3, 0.0)
		for j in 18:
			var p := Vector3(hold.x, LOW_Y - 0.4 + j * 0.42, hold.z)
			k.toward(p, Vector3.UP, Vector3(hold.x, 0, hold.z).normalized()); k.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (j % 2)), Vector3.ZERO)); k.link(0.5, 0.26, 0.055, 5); k.pop(); k.pop()
		k.paint(C_RUNE, 0.0, 0.5, ArtKit.PLAIN, 2, 0.9); k.at(Vector3(hold.x, MID_Y - 0.4, hold.z)); k.torus(0.2, 0.04, 12, 4); k.pop()
		chains.push_back({"at": hold, "top": top, "deg": deg})
	for side: String in GATES:   # the blood-pact gates: a ring of bone on a broad stone, blood-red air in it
		var g: Vector3 = GATES[side]; _stone(g, 2.4)
		var k := _k(g.x + 0.01, g.z)
		k.paint(C_BONE, 0.0, 0.6, ArtKit.BONE); k.toward(g + Vector3(0, 1.75, 0), Vector3(0, 0, 1)); k.push(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)); k.torus(1.45, 0.18, 24, 6); k.pop(); k.pop()
		k.paint(C_BONE.darkened(0.2), 0.0, 0.6, ArtKit.BONE)
		for s: float in [1.0, -1.0]: k.tube(PackedVector3Array([g + Vector3(s * 1.3, 0.0, 0), g + Vector3(s * 1.35, 0.9, 0)]), 0.16, 6)
		k.paint(C_RUNE, 0.0, 0.5, ArtKit.PLAIN, 2, 1.0)
		for i in 8: var a := i * TAU / 8.0; k.toward(g + Vector3(cos(a) * 1.45, 1.75 + sin(a) * 1.45, 0.22), Vector3(0, 0, -1)); k.rune(430 + i, 0.3, 0.05, 0.0); k.pop()
		_vdisc(clear, g + Vector3(0, 1.75, 0), 1.3, Vector3(0, 0, 1), Color(0.8, 0.05, 0.08, 0.38))
		lamps_at.push_back(g + Vector3(0, 1.75, 0))
	for i in stones.size():   # glass-cacti and ash-spore caps on the stones
		var s: Dictionary = stones[i]
		if i % 5 == 2: _cactus((s.at as Vector3) + Vector3(0.35, 0, 0.2))
		if i % 7 == 4: _cap((s.at as Vector3) + Vector3(-0.3, 0, -0.25))
	for deg: float in [30.0, 75.0, 150.0, 205.0, 255.0, 330.0]: _cap(at_deg(deg, RING_R0 + 3.0, MID_Y))
	for deg: float in [100.0, 280.0]: _cap(at_deg(deg, 6.0, MID_Y))
	for deg: float in [60.0, 120.0, 240.0, 300.0]: _cactus(at_deg(deg, RING_R0 + 1.6, MID_Y))

## a disc standing up (a gate's air), facing n both ways
static func _vdisc(m: MeshKit, c: Vector3, r: float, n: Vector3, col: Color, sides := 20) -> void:
	var u := n.cross(Vector3.UP).normalized(); var v := Vector3.UP
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		m.quad(c, c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, c, col, n)

## a stepping stone: a pillar of black rock out of the lava, its top flat, the lava glowing round its foot
func _stone(at: Vector3, r: float) -> void:
	var k := _k(at.x, at.z + 0.01); var top := at.y
	k.paint(C_BASALT, 0.15, 0.7, ArtKit.OBSIDIAN, 3, 0.0); k.at(Vector3(at.x, PIT_Y, at.z)); k.lathe(PackedVector2Array([Vector2(r * 1.2, 0.0), Vector2(r * 1.05, top - PIT_Y - 0.6), Vector2(r, top - PIT_Y - 0.05), Vector2(r * 0.9, top - PIT_Y), Vector2(0.0, top - PIT_Y)]), 12, 0.0, TAU, false); k.pop()
	glow.disc(at.x, LAVA_Y + 0.03, at.z, r * 1.5, Color(0.12, 0.035, 0.025), 12, r * 1.1)   # (a ring of cooled crust round its foot)
	solid_disc(at, r * 0.92, PIT_Y, top)
	stones.push_back({"at": at, "r": r, "top": top})

## a vitrified glass-cactus: black crystal blades out of a crack
func _cactus(at: Vector3) -> void:
	var n := Node3D.new(); n.position = at; n.name = "Cactus"; G.add_child(n)
	RaceArt.piece(n, "cd_cactus", func(k: ArtKit) -> void: _cactus_mesh(k), mat)
	cacti.push_back({"at": at, "node": n, "t": 0.0})
static func _cactus_mesh(k: ArtKit) -> void:
	for i in 6:
		var a := i * 1.1; var h := 0.7 + fposmod(i * 0.53, 0.6)
		k.paint(C_GLASS.lightened(0.1 * (i % 3)), 0.4, 0.05, ArtKit.CRYSTAL, 2, 0.15); k.at(Vector3(cos(a) * 0.18, 0, sin(a) * 0.18), Vector3(0.3 * sin(a), a, 0.3 * cos(a))); k.gem(0.09, h, 0.05, 5); k.pop()

## an ash-spore cap: a black mushroom fat with ash
func _cap(at: Vector3) -> void:
	var n := Node3D.new(); n.position = at; n.name = "AshCap"; G.add_child(n)
	RaceArt.piece(n, "cd_cap", func(k: ArtKit) -> void: _cap_mesh(k), mat)
	caps.push_back({"at": at, "node": n, "t": 0.0})
static func _cap_mesh(k: ArtKit) -> void:
	for i in 3:
		var o := Vector3(cos(i * 2.1) * 0.35, 0, sin(i * 2.1) * 0.35) * (0.0 if i == 0 else 1.0); var s := 1.0 - i * 0.25
		k.paint(Color("2a2420"), 0.0, 0.85, ArtKit.SKIN); k.at(o); k.cyl(0.08 * s, 0.06 * s, 0.4 * s, 8); k.pop()
		k.paint(Color("1c1818"), 0.1, 0.6, ArtKit.SKIN); k.ball(o + Vector3(0, 0.4 * s, 0), Vector3(0.32, 0.17, 0.32) * s, 10, 5)
		k.paint(C_EMBER, 0.0, 0.5, ArtKit.PLAIN, 5, 0.6)
		for j in 5: var b := j * TAU / 5.0; k.ball(o + Vector3(cos(b) * 0.22 * s, 0.46 * s, sin(b) * 0.22 * s), Vector3.ONE * 0.035 * s, 5, 3)

## the colossal ribs of a demon lord across the sky over the sanctum; the four great chains it hangs from; burning rune
## chains hung down from the ribs (their runes beat faster as the fight goes on)
func _ribs() -> void:
	var spine: Array = []
	for i in 11: var x := lerpf(-RIM_R - 2.0, RIM_R + 2.0, i / 10.0); spine.push_back(Vector3(x, 37.0 + 3.0 * cos(x / RIM_R * PI * 0.5), 0.0))
	var sp := ArtKit.spline(spine, 4); var ks: ArtKit = kits[0]
	ks.paint(C_BONE, 0.0, 0.65, ArtKit.BONE); ks.tube(sp, 1.4, 10)
	for i in 10: var p: Vector3 = sp[i * 4 + 2]; ks.ball(p + Vector3(0, 1.2, 0), Vector3(1.0, 1.6, 0.9), 8, 4)   # (its vertebrae)
	for i in 9:   # the ribs, each side, curving down to the rim
		var x := lerpf(-40.0, 40.0, i / 8.0); var top := Vector3(x, 36.5 + 3.0 * cos(x / RIM_R * PI * 0.5), 0.0)
		for s: float in [1.0, -1.0]:
			var zr := sqrt(maxf(0.0, RIM_R * RIM_R - x * x)) - 1.0
			var path := ArtKit.spline([top, top + Vector3(0, 4.0, s * zr * 0.35), Vector3(x * 1.02, 34.0, s * zr * 0.82), Vector3(x * 1.03, 24.0, s * (zr + 0.5))], 6)
			var rr := PackedFloat32Array()
			for j in path.size(): var u := float(j) / (path.size() - 1); rr.push_back(lerpf(0.95, 0.45, u))
			var k := _k(x, s); k.paint(C_BONE.darkened(0.05 * (i % 3)), 0.0, 0.65, ArtKit.BONE); k.tube(path, rr, 8)
	for j in 4:   # the four great chains the sanctum hangs from, up to the spine
		var a := deg_to_rad(45.0 + j * 90.0); var foot := Vector3(cos(a) * 11.0, MID_Y + 0.2, sin(a) * 11.0); var head := Vector3(cos(a) * 6.0, 38.0, sin(a) * 1.5)
		var k := _k(foot.x, foot.z); var n := int(foot.distance_to(head) / 1.6)
		k.paint(C_IRON, 0.9, 0.4, ArtKit.IRON)
		for i in n: var p := foot.lerp(head, (i + 0.5) / n); k.toward(p, (head - foot).normalized()); k.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)), Vector3.ZERO)); k.link(1.9, 0.9, 0.16, 6); k.pop(); k.pop()
		k.paint(C_IRON2, 0.85, 0.5, ArtKit.IRON); k.at(foot); k.cyl(0.9, 0.6, 0.7, 10); k.pop()
	var rk := ArtKit.new(); rk.detail = 0.8
	for i in 8:   # the rune chains: their own mesh, so their runes' beat can follow the fight
		var x := lerpf(-36.0, 36.0, i / 7.0); var z := 12.0 * (1.0 if i % 2 == 0 else -1.0); var top := Vector3(x, 37.0, z * 0.6); var bot := Vector3(x, 19.0 + fposmod(i * 3.7, 5.0), z)
		var n := int(top.distance_to(bot) / 0.9)
		for j in n:
			var p := top.lerp(bot, (j + 0.5) / n)
			rk.paint(C_IRON, 0.9, 0.45, ArtKit.IRON); rk.toward(p, (bot - top).normalized()); rk.push(Transform3D(Basis(Vector3.FORWARD, PI / 2.0 * (j % 2)), Vector3.ZERO)); rk.link(1.0, 0.5, 0.08, 5); rk.pop(); rk.pop()
			if j % 3 == 1: rk.paint(C_RUNE, 0.0, 0.5, ArtKit.PLAIN, 2, 1.0); rk.toward(p + Vector3(0.0, 0, 0.3), Vector3(0, 0, -1)); rk.rune(460 + i * 7 + j, 0.32, 0.06, 0.0); rk.pop()
	rune_mat = RaceArt.mat(false, {1: [C_LAVA, 2.0], 2: [C_RUNE, 2.4]}); _tune(rune_mat)
	var rn := rk.node(rune_mat, G, "RuneChains"); rn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## the four floating slabs of obsidian the tide brings up out of the lava on the diagonals (sunk under it till then)
func _floats() -> void:
	for deg: float in FLOATS:
		var mid := at_deg(deg, (FLOAT_IN + FLOAT_OUT) * 0.5, 0.0)
		var n := Node3D.new(); n.position = Vector3(mid.x, -6.0, mid.z); n.rotation.y = -deg_to_rad(deg); n.visible = false; n.name = "Float"; G.add_child(n)
		RaceArt.piece(n, "cd_float", func(k: ArtKit) -> void: _float_mesh(k), mat)
		floats.push_back({"deg": deg, "node": n, "up": false})
static func _float_mesh(k: ArtKit) -> void:
	var hl := (FLOAT_OUT - FLOAT_IN) * 0.5; var hw := FLOAT_W * 0.5
	k.paint(C_OBS, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0); k.slab(-hl, -0.8, -hw, hl, 0.0, hw, true)
	k.paint(C_OBS2, 0.2, 0.55, ArtKit.OBSIDIAN, 3, 0.0)
	for s: float in [-0.5, 0.5]: k.at(Vector3(s * hl, -0.8, 0), Vector3(PI, 0, 0)); k.cyl(hw * 0.9, 0.3, 2.6, 6, false); k.pop()
	k.paint(C_LAVA, 0.0, 0.5, ArtKit.PLAIN, 1, 0.9)
	for i in 5: var x := lerpf(-hl * 0.8, hl * 0.8, i / 4.0); k.tube(PackedVector3Array([Vector3(x, 0.01, -hw * 0.9), Vector3(x + 0.6 * sin(i * 2.0), 0.01, hw * 0.9)]), 0.07, 4, false)

# ---------------- where the demons stand (the solo fight's) ----------------
func _posts() -> void:
	# the sanctum: adepts on its east side, a warden by its middle, imps over it
	for a: float in [45.0, 315.0]: var p := at_deg(a, 7.8, MID_Y); post("dm_adept", p, yaw_in(p) + PI)
	post("dm_warden", Vector3(4.0, MID_Y, 0.0), -PI / 2.0)
	for a: float in [60.0, 300.0]: post("dm_imp", at_deg(a, 5.0, MID_Y + 2.5), 0.0, {"fly": true})
	# the bridges: a guard at each one's sanctum end (the west's meets you first), an imp over the lava by the north and south
	for side: String in ARCS:
		var a := float(ARCS[side]); var p := at_deg(a, DAIS_A + 1.5, MID_Y); post("dm_guard", p, yaw_in(p) + PI)
		if side == "n" or side == "s": post("dm_imp", at_deg(a + 18.0, 22.0, MID_Y + 1.5), 0.0, {"fly": true})
	# the ring's arcs: a guard and an adept on each but the west's; the east foundry held
	for side: String in ["n", "s", "e"]:
		var a := float(ARCS[side])
		for k in 2: var p := at_deg(a + (k - 0.5) * 34.0, 36.0, MID_Y); post("dm_guard" if k == 0 else "dm_adept", p, yaw_in(p))
	post("dm_warden", FOUNDRY.e + Vector3(-5.2, 0, 3.0), -PI / 2.0)
	post("dm_adept", FOUNDRY.e + Vector3(-5.5, 0, -3.4), -PI / 2.0)
	for k in 2: post("dm_guard", FOUNDRY.e + Vector3(1.5 * (k * 2 - 1), 0, 0.0), -PI / 2.0)
	# the trench: imps over the stones, a guard by each gate
	for j in 4: post("dm_imp", at_deg(j * 90.0 + 45.0, STONE_R, LOW_Y + 2.0), 0.0, {"fly": true})
	for side: String in GATES: var g: Vector3 = GATES[side]; post("dm_guard", g + Vector3(1.6, 0, 0), yaw_in(g))
	# the gallery: snipers along it and up on the spires' lookouts
	for side: String in GALLERY:
		var a0: float = GALLERY[side][0]; var a1: float = GALLERY[side][1]
		for k in 3: var p := at_deg(lerpf(a0 + 14.0, a1 - 14.0, k / 2.0) + (6.0 if k == 1 else 0.0), 49.5, GAL_Y); post("dm_sniper", p, yaw_in(p), {"perch": true})
	for deg: float in SPIRES: var c := at_deg(deg, SPIRE_R, LOOK_Y); post("dm_sniper", c, yaw_in(c), {"perch": true})
	# the inquisitor: on the north gallery (north is the map's top: -z), over the middle
	var b := at_deg(270.0, 50.5, GAL_Y); post("inquisitor", b, yaw_in(b), {"boss": true, "perch": true})

func populate(put: Callable) -> void:
	for i in posts.size():
		var p: Dictionary = posts[i]; var fly := bool(p.get("fly", false))
		var y := float(p.y) if fly else Phys.ground_at(p.x, float(p.y) + 0.7, p.z, 0.3)
		var o := {"yaw": p.yaw, "v": i, "y": y, "scale": Hellfolk.size_of(str(p.type)), "post": {"x": p.x, "y": y, "z": p.z, "perch": p.get("perch", false), "fly": fly}}
		if p.get("boss", false): o.boss = true
		put.call(p.type, {"x": p.x, "z": p.z, "y": y}, o)

# ---------------- what the place does ----------------
func _tell(key: String, text: String) -> void:
	if _told.has(key) or game == null: return
	_told[key] = true; game.say_hint(text, 3.5)

## the lava rises (the magma tide): the stones go under, the floating slabs come up on the diagonals
func rise() -> void:
	if tide_on: return
	tide_on = true
	if game != null: game.say_banner("용암 조석", "지진과 함께 용암이 차오릅니다 · 하층 징검다리가 잠기고 대각선에 흑요석 발판 넷이 떠오릅니다", 3.5)
	Snd.play("quake", 1.0); Snd.play("rd_lava", 1.0)
	if player != null: player.shake = maxf(player.shake, 0.8)
	for f: Dictionary in floats: (f.node as Node3D).visible = true
	if enemies != null:   # the demons down in the trench step up through the gates, out of its way
		for e in enemies.list:
			if e.alive and e.folk and e.pos.y < LOW_Y + 1.0 and not bool(e.k.get("fly", false)):
				var g: Vector3 = GATE_TO.n if e.pos.z > 0.0 else GATE_TO.s; var at := g + Vector3(randf_range(-2.0, 2.0), 0, 0)
				if fx != null: fx.sparks(e.pos + Vector3(0, 1, 0), 12, [1.0, 0.2, 0.15], 3.0)
				e.pos = at; e.k.post = at; e.vel = Vector3.ZERO
## whether the cooling circle is under p (weapons cool half as fast again)
func cooling(p: Vector3) -> bool: return absf(p.y - MID_Y) < 1.5 and Vector2(p.x, p.z).length() < COOL_R
## a shot from o along d, as far as reach: how much harder it hits for going through a hellfire ring (1: it went through none)
func amp_ray(o: Vector3, d: Vector3, reach: float) -> float:
	for q: Dictionary in amps:
		var c: Vector3 = q.at; var n: Vector3 = q.n; var dn := d.dot(n)
		if absf(dn) < 0.05: continue
		var tt := (c - o).dot(n) / dn
		if tt < 0.0 or tt > reach: continue
		if (o + d * tt).distance_to(c) <= AMP_R: return AMP_K
	return 1.0
## where nobody far off sees you: in an ash cloud
func hides(p: Player, dist: float) -> bool:
	if dist < 4.0: return false
	for c: Dictionary in clouds:
		if (c.at as Vector3).distance_to(p.pos + Vector3(0, 1.0, 0)) < float(c.r): return true
	return false
## a shot that missed the demons: what it struck on its way (a brazier goes over, a cap bursts, a cactus shatters)
func shot_by(o: Vector3, d: Vector3, reach: float) -> void:
	for b: Dictionary in braziers:
		if not bool(b.down) and _ray_near(o, d, reach, (b.at as Vector3) + Vector3(0, 0.9, 0), 0.6): knock(b)
	for c: Dictionary in caps:
		if float(c.t) <= 0.0 and _ray_near(o, d, reach, (c.at as Vector3) + Vector3(0, 0.35, 0), 0.5): burst(c)
	for c: Dictionary in cacti:
		if float(c.t) <= 0.0 and _ray_near(o, d, reach, (c.at as Vector3) + Vector3(0, 0.5, 0), 0.45): shatter(c)
static func _ray_near(o: Vector3, d: Vector3, reach: float, c: Vector3, r: float) -> bool:
	var tt := clampf((c - o).dot(d), 0.0, reach); return (o + d * tt).distance_to(c) <= r
## an explosion at c: what it sets off round it
func puffed(c: Vector3, r := 3.0) -> void:
	for b: Dictionary in braziers:
		if not bool(b.down) and (b.at as Vector3).distance_to(c) < r + 1.0: knock(b)
	for q: Dictionary in caps:
		if float(q.t) <= 0.0 and (q.at as Vector3).distance_to(c) < r + 0.8: burst(q)
	for q: Dictionary in cacti:
		if float(q.t) <= 0.0 and (q.at as Vector3).distance_to(c) < r + 0.6: shatter(q)

## a brazier knocked over: it lies on its side, its fire out on the ground four metres round for five seconds
func knock(b: Dictionary) -> void:
	b.down = true; b.t = 0.0; var n: Node3D = b.node; n.rotation = Vector3(0, randf() * TAU, 1.35); n.position.y += 0.25
	(b.flame as Node3D).visible = false; Phys.remove_collider(b.box)
	fires.push_back({"at": b.at, "r": float(BRAZIER.r), "t": float(BRAZIER.t)})
	Snd.play("rm_ignite", 1.0, b.at); Snd.play("metal", 0.8, b.at)
	if fx != null: fx.sparks((b.at as Vector3) + Vector3(0, 0.6, 0), 14, [1.0, 0.6, 0.2], 5.0)
func burst(c: Dictionary) -> void:
	c.t = float(CAP.back); (c.node as Node3D).visible = false
	clouds.push_back({"at": (c.at as Vector3) + Vector3(0, 1.2, 0), "r": float(CAP.r), "t": float(CAP.t)})
	Snd.play("rm_smoke", 0.9, c.at)
	if fx != null:
		for i in 26: fx.glow((c.at as Vector3) + Vector3(randf_range(-1, 1), randf_range(0.2, 2.4), randf_range(-1, 1)), Vector3(randf_range(-1.5, 1.5), randf_range(0.3, 1.2), randf_range(-1.5, 1.5)), 3.6, 1.0, 2.2, Color(0.22, 0.2, 0.2, 0.55), 0.0, 1.2)
func shatter(c: Dictionary) -> void:
	c.t = 999.0; (c.node as Node3D).visible = false
	Snd.play("rd_shatter", 0.9, c.at)
	if fx != null: fx.sparks((c.at as Vector3) + Vector3(0, 0.6, 0), 16, [0.6, 0.4, 0.9], 4.0)
	if enemies != null:   # (its shards: whoever stands by it)
		for e in enemies.list.duplicate():
			if e.alive and e.folk and e.pos.distance_to(c.at) < float(CACTUS.r): enemies.damage(e, float(CACTUS.dmg), e.pos + Vector3(0, 1.0, 0), Vector3.UP, false)
	if player != null and rm == null and player.pos.distance_to(c.at) < float(CACTUS.r): player.hurt(float(CACTUS.dmg), c.at)

## the place's own turn: the lava and the tide, the fires and the ash, and what it does to you
func update(dt: float, p: Player) -> void:
	t += dt; _gate_cd = maxf(0.0, _gate_cd - dt)
	if tide_on and tide < 1.0: tide = minf(1.0, tide + dt / 4.0)
	lava_y = lerpf(LAVA_Y, TIDE_Y, smoothstep(0.0, 1.0, tide))
	if lava_n != null and is_instance_valid(lava_n): lava_n.position.y = lava_y - LAVA_Y + sin(t * 0.6) * 0.06
	for f: Dictionary in floats:
		var n: Node3D = f.node
		if not n.visible or bool(f.up): continue
		n.position.y = lerpf(-6.0, MID_Y, smoothstep(0.0, 1.0, tide))
		if tide >= 1.0:
			f.up = true; var deg: float = f.deg
			solid_band(at_deg(deg, FLOAT_IN, 0.0), at_deg(deg, FLOAT_OUT, 0.0), FLOAT_W, MID_Y - 0.8, MID_Y)
	if rune_mat != null: RaceArt.set_glow(rune_mat, 2, C_RUNE, 1.4 + 1.6 * (0.5 + 0.5 * sin(t * (1.6 + 8.0 * pulse))))
	for i in range(fires.size() - 1, -1, -1):   # fire on the ground from braziers
		var f: Dictionary = fires[i]; f.t = float(f.t) - dt
		if fx != null and randf() < dt * 30.0:
			var a := randf() * TAU; var q := sqrt(randf()) * float(f.r)
			fx.glow((f.at as Vector3) + Vector3(cos(a) * q, 0.1, sin(a) * q), Vector3(0, randf_range(1.5, 3.0), 0), 0.5, 0.45, 0.05, Color(1.0, randf_range(0.3, 0.6), 0.08, 0.8), 0.0, 0.5)
		if float(f.t) <= 0.0: fires.remove_at(i)
	for i in range(clouds.size() - 1, -1, -1):   # ash in the air
		var c: Dictionary = clouds[i]; c.t = float(c.t) - dt
		if fx != null and randf() < dt * 10.0: fx.glow((c.at as Vector3) + Vector3(randf_range(-3, 3), randf_range(-1.0, 1.5), randf_range(-3, 3)), Vector3(0, 0.2, 0), 1.8, 1.4, 2.4, Color(0.2, 0.18, 0.18, 0.4), 0.0, 1.0)
		if float(c.t) <= 0.0: clouds.remove_at(i)
	for c: Dictionary in caps:   # the caps growing back
		if float(c.t) > 0.0:
			c.t = float(c.t) - dt
			if float(c.t) <= 0.0: (c.node as Node3D).visible = true
	for b: Dictionary in braziers:   # a brazier stood up again a while after
		if not bool(b.down): continue
		b.t = float(b.t) + dt
		if float(b.t) > float(BRAZIER.back):
			var at: Vector3 = b.at; var n: Node3D = b.node; b.down = false; n.rotation = Vector3.ZERO; n.position = at; (b.flame as Node3D).visible = true
			b.box = Phys.add_collider(at.x - 0.45, at.y, at.z - 0.45, at.x + 0.45, at.y + 1.2, at.z + 0.45, "metal")
	if p == null or rm != null: return
	_you(dt, p)

## what the place does to you: the lava, the gates, the chains, the troughs, the briars, the fires, the caps underfoot
func _you(dt: float, p: Player) -> void:
	var feet := p.pos; _scald = maxf(0.0, _scald - dt)
	# the lava: each touch scalds you and throws you up out of it (out on to a stone, if one is near)
	if feet.y < lava_y + 0.05 and p.hp > 0.0:
		if _scald <= 0.0:
			_scald = float(LAVA.every); p.hurt(float(LAVA.hit), feet + Vector3(0, -1, 0), "fire")
			p.vel.y = sqrt(2.0 * 19.0 * maxf(0.2, lava_y + float(LAVA.rise) - feet.y)); p.grounded = false
			Snd.play("rd_lava", 1.0); _tell("lava", "용암 · 닿을 때마다 90 피해 · 튀어 오를 때 가까운 돌로")
			if game != null and game.has_method("set_burn"): game.set_burn(4.0)
		if fx != null: fx.glow(feet + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)), Vector3(0, 2.5, 0), 0.4, 0.4, 0.05, Color(1.0, 0.45, 0.1, 0.9))
	# the blood-pact gates: into one, 35 of your health given, and you stand on the gallery above it
	for side: String in GATES:
		var g: Vector3 = GATES[side]
		if _gate_cd > 0.0 or Vector2(feet.x - g.x, feet.z - g.z).length() > 1.1 or absf(feet.y - g.y) > 1.2: continue
		var god: bool = Store.settings.dev and Store.settings.god
		if p.hp > GATE_COST + 0.5 or god:
			if not god: p.hp -= GATE_COST
			if fx != null:
				for i in 16: fx.glow(feet + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.8), randf_range(-0.6, 0.6)), Vector3(0, 2.0, 0), 0.6, 0.3, 0.04, Color(0.9, 0.08, 0.1, 0.85))
			p.pos = GATE_TO[side]; p.vel = Vector3.ZERO; _gate_cd = 2.5; Snd.play("elf_portal", 1.0)
			if game != null: game.say_hint("혈약의 차원문 · 체력 35를 바치고 감시 회랑으로", 2.4)
		else: _gate_cd = 1.0; _tell("gate_low", "혈약의 차원문은 체력 35를 받아야 열립니다")
	# the soul chains: hold jump by one to climb it (nothing in your hands fires while you climb)
	_climb = false
	for c: Dictionary in chains:
		var at: Vector3 = c.at; var top: Vector3 = c.top
		if Vector2(feet.x - at.x, feet.z - at.z).length() > 0.95 or feet.y < LOW_Y - 0.4 or feet.y > MID_Y + 0.3: continue
		_tell("chain", "영혼 포집 쇠사슬 · 곁에서 점프를 누르고 있으면 타고 오릅니다 (오르는 동안은 쏠 수 없음)")
		if not p.in_up: continue
		_climb = true; p.vel = Vector3(0.0, 4.2, 0.0); p.grounded = false
		if fmod(t, 0.4) < dt: Snd.play("rd_chain", 0.6)
		if feet.y > MID_Y - 0.35: p.pos = Vector3(top.x, MID_Y + 0.05, top.z); p.vel = Vector3.ZERO; p.grounded = true
	# the quench troughs: through one, and what burns on you is out
	for q: Vector3 in troughs:
		if Vector2(feet.x - q.x, feet.z - q.z).length() < 1.7 and absf(feet.y - q.y) < 1.0 and game != null and game.has_method("quench"): game.quench()
	# the briars: they slow and cut whoever brushes them
	p.slow_mul = float(BRIAR.slow) if _in_briar(feet) else 1.0
	if p.slow_mul < 1.0:
		_vine_t -= dt
		if _vine_t <= 0.0: _vine_t = 0.5; p.hurt(float(BRIAR.dps) * 0.5, feet + Vector3(0, 1, 0)); _tell("briar", "흡혈 가시 덩굴 · 느려지고 피가 납니다 · 곁의 악마는 생명력을 얻습니다")
	for f: Dictionary in fires:   # fire on the ground
		if (f.at as Vector3).distance_to(feet) < float(f.r) and absf(feet.y - (f.at as Vector3).y) < 1.5:
			p.hurt(float(BRAZIER.burn) * dt, f.at, "fire")
			if game != null and game.has_method("set_burn"): game.set_burn(3.0)
	for c: Dictionary in caps:   # a cap underfoot bursts
		if float(c.t) <= 0.0 and (c.at as Vector3).distance_to(feet) < 0.8:
			burst(c); _tell("cap", "잿빛 포자 화산버섯 · 4초 동안 화산재 연막 · 그 안에서는 멀리 있는 악마가 나를 보지 못합니다")
	for c: Dictionary in cacti:   # thrown into a cactus: it shatters on you
		if float(c.t) <= 0.0 and (c.at as Vector3).distance_to(feet) < 0.9 and Vector2(p.vel.x, p.vel.z).length() > 7.5: shatter(c)

## whether you can fire (not while you climb a chain)
func climbing() -> bool: return _climb

func _in_briar(p: Vector3) -> bool:
	for b: Dictionary in briars:
		var a: Vector3 = b.a; var c: Vector3 = b.b
		if p.x < minf(a.x, c.x) - float(b.r) or p.x > maxf(a.x, c.x) + float(b.r) or absf(p.z - a.z) > float(b.r): continue
		if p.y > minf(a.y, c.y) - 1.5 and p.y < maxf(a.y, c.y) + 0.5: return true
	return false

## whether a demon stands by the briars (they feed it)
func by_briar(p: Vector3) -> bool:
	for b: Dictionary in briars:
		var a: Vector3 = b.a; var c: Vector3 = b.b
		var q := Vector3(clampf(p.x, minf(a.x, c.x), maxf(a.x, c.x)), clampf(p.y, minf(a.y, c.y), maxf(a.y, c.y)), a.z)
		if q.distance_to(p) < float(BRIAR.heal_r): return true
	return false

## the nearest perch to `to` that is not near `from` (where the inquisitor steps to)
func perch_away(from: Vector3, to: Vector3):
	var best = null; var bd := INF
	for q: Vector3 in perches:
		if q.distance_to(from) < 8.0: continue
		var d := q.distance_to(to) + randf() * 20.0
		if d < bd: bd = d; best = q
	return best
