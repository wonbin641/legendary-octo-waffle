class_name ToyMatch
extends RefCounted
## Stage 5's team modes, the part they share: two sides of toys. Ours are the player and a squad of blue plastic soldiers;
## theirs are the room's own toys (green and tan soldiers, action figures, brick figures). Whoever falls comes back at his
## side's base a little later, the player too. The toys find their way round the room by a graph of waypoints (the floor,
## the dark crawl space under the bed, the desk, the block bridge, the mattress and the stairs between them), pick the
## nearest enemy they can see, and shoot at him; the mode (ModeRush, ModeEscort, ModeFreeze) says where each should be going.

const MODES := ["sweep", "rush", "escort", "freeze"]
const NAMES := {"sweep": "소탕 작전", "rush": "AA 배터리 쟁탈전", "escort": "장난감 기차 호위전", "freeze": "취침 시간 술래잡기"}
const SHORT := {"sweep": "소탕", "rush": "배터리 쟁탈전", "escort": "기차 호위전", "freeze": "취침 시간 술래잡기"}
const SIGHT := 42.0          # how far a toy picks out an enemy (a sniper 95 m)
const KILL_PAY := 0.5        # a toy you shoot pays half what it pays in the sweep (they keep coming back)
const BACK := {"us": 11.0, "them": 9.0}   # seconds before someone who fell is back at his base
const PLAYER_BACK := 5.0
const ALLY_HP := 130.0
# how each kind shoots: [burst from, burst to, gap, pause from, pause to, bullet speed, damage, spread, spread a metre, pellets, range, sound]
const GUNS := {
	"ally": [3, 4, 0.12, 1.3, 2.0, 80.0, 9.0, 0.34, 0.027, 1, 45.0, "toy_shot_smg"],
	"trooper": [3, 4, 0.12, 1.4, 2.2, 80.0, 10.0, 0.35, 0.028, 1, 45.0, "toy_shot_smg"],
	"sniper": [1, 1, 0.1, 3.4, 4.6, 140.0, 30.0, 0.2, 0.005, 1, 100.0, "toy_shot_sniper"],
	"smg": [6, 9, 0.08, 1.2, 1.9, 80.0, 6.0, 0.55, 0.03, 1, 34.0, "toy_shot_smg"],
	"shotgun": [1, 1, 0.1, 1.6, 2.2, 70.0, 6.0, 0.9, 0.05, 6, 14.0, "toy_shot_shotgun"],
	"brick": [2, 3, 0.16, 1.2, 2.0, 75.0, 9.0, 0.4, 0.03, 1, 40.0, "toy_shot_pistol"],
}

# the room's waypoints, shared by every mode: [x, y, z]. f = floor, u = under the bed, d = the desk, b = the bridge, m = the mattress
const NODES := {
	"c_s": Vector3(-6, 0, 10), "c_n": Vector3(-6, 0, -10), "u_c": Vector3(-11, 0, 0),
	"m_s": Vector3(-10, 0, 30), "m_n": Vector3(-10, 0, -30), "z_s": Vector3(0, 0, 46), "z_n": Vector3(0, 0, -46),
	"bs_s": Vector3(-19, 0, 24), "bl_s": Vector3(-2, 0, 20), "e_s": Vector3(6, 0, 13), "e_n": Vector3(6, 0, -13),
	"ub_s": Vector3(14, 0, 12), "ub_n": Vector3(14, 0, -12), "ub_se": Vector3(14, 0, 27), "ub_ne": Vector3(16, 0, -27),
	"x_s": Vector3(14, 0, 34), "x_n": Vector3(16, 0, -36), "sd_n": Vector3(12, 0, -38),
	"w_s": Vector3(-32, 0, 38), "w_n": Vector3(-30, 0, -44), "e_far_s": Vector3(34, 0, 42), "e_far_n": Vector3(34, 0, -44),
	"br": Vector3(-14, 9, 0), "br_w": Vector3(-21, 9, 0), "br_e": Vector3(1, 7.5, 0), "br_sj": Vector3(-8, 9, 3), "br_nj": Vector3(-8, 9, -3),
	"dk_e": Vector3(-26, 9, 0), "dk_s1": Vector3(-33, 9, 3), "dk_s2": Vector3(-39.6, 9, 17.5), "st_s": Vector3(-39.6, 8.93, 22.0),
	"dk_n1": Vector3(-33, 9, -4), "dk_n15": Vector3(-40, 9, -14), "dk_w": Vector3(-46, 9, -14),
	"bd_w": Vector3(13, 6, 0), "bd_s": Vector3(13, 6, 20), "bd_n": Vector3(14, 6, -27), "stool": Vector3(13, 6, -32.5),
}
# [a, b, one way, kind]: kinds pick the way a toy prefers (under the bed, up high, or the middle)
const EDGES := [
	["c_s", "u_c", false, "mid"], ["c_n", "u_c", false, "mid"], ["c_s", "m_s", false, "mid"], ["c_n", "m_n", false, "mid"],
	["m_s", "z_s", false, "mid"], ["m_n", "z_n", false, "mid"], ["m_s", "bs_s", false, ""], ["c_s", "bl_s", false, "mid"], ["bl_s", "z_s", false, "mid"],
	["c_s", "e_s", false, ""], ["c_n", "e_n", false, ""], ["e_s", "ub_s", false, "bed"], ["e_n", "ub_n", false, "bed"], ["ub_s", "ub_n", false, "bed"],
	["ub_s", "ub_se", false, "bed"], ["ub_n", "ub_ne", false, "bed"], ["ub_se", "x_s", false, "bed"], ["ub_ne", "x_n", false, "bed"],
	["x_s", "z_s", false, ""], ["x_n", "z_n", false, ""], ["sd_n", "z_n", false, ""], ["x_n", "sd_n", false, ""],
	["m_s", "w_s", false, ""], ["m_n", "w_n", false, ""], ["w_n", "z_n", false, ""],
	["x_s", "e_far_s", false, ""], ["e_far_s", "z_s", false, ""], ["x_n", "e_far_n", false, ""], ["e_far_n", "z_n", false, ""],
	["br", "br_w", false, "high"], ["br_w", "dk_e", false, "high"], ["dk_e", "dk_s1", false, "high"], ["dk_s1", "dk_s2", false, "high"], ["dk_s2", "st_s", false, "high"],
	["st_s", "bs_s", false, "high"], ["dk_e", "dk_n1", false, "high"], ["dk_n1", "dk_n15", false, "high"], ["dk_n15", "dk_w", false, "high"],
	["br", "br_e", false, "high"], ["br_e", "bd_w", false, "high"], ["bd_w", "bd_s", false, "high"], ["bd_s", "bl_s", false, "high"], ["bd_w", "bd_n", false, "high"], ["bd_n", "stool", false, "high"],
	["stool", "sd_n", true, "high"], ["br", "br_sj", false, "high"], ["br", "br_nj", false, "high"], ["br_sj", "c_s", true, "mid"], ["br_nj", "c_n", true, "mid"],
]

var game   # Game
var world: World
var en: Enemies
var toys: ToyFoes
var player: Player
var guns: Guns
var proj: Proj
var fx: Fx
var room: ToyRoom
var mode: ToyMode
var key := ""

var allies: Array = []         # our blue soldiers (not in the enemy list: nothing of yours hits them)
var queue: Array = []          # who comes back, and when: {team, type, opts, t}
var down_t := 0.0              # you are down: back at the base in this long
var down_why := ""
var clock := 0.0
var score := {"us": 0, "them": 0}
var nodes := {}
var adj := {}
var lost_t := -1.0             # the match is over: the result in this long
var _blue_bar: StandardMaterial3D
var _ally_gun: StandardMaterial3D
var _plan_t := 0.0

static func create(k: String) -> ToyMatch:
	var mt := ToyMatch.new(); mt.key = k
	match k:
		"rush": mt.mode = ModeRush.new()
		"escort": mt.mode = ModeEscort.new()
		_: mt.mode = ModeFreeze.new()
	mt.mode.m = mt; mt.mode.key = k
	return mt

## the mode the toy room is set to play (sweep: the hundred toys of the room on their own)
static func picked() -> String:
	var k := str(Store.settings.get("toyMode", "sweep"))
	return k if MODES.has(k) else "sweep"

# ---------------- the room's ways ----------------
func build_graph() -> void:
	nodes = NODES.duplicate(); nodes.merge(mode.extra_nodes(), true); adj = {}
	for n in mode.cut_nodes(): nodes.erase(n)
	for n in nodes: adj[n] = []
	var cut: Array = mode.cut_edges().map(func(c): return str(c[0]) + "|" + str(c[1]))
	for e: Array in EDGES + mode.extra_edges():
		var a: String = e[0]; var b: String = e[1]
		if not nodes.has(a) or not nodes.has(b) or cut.has(a + "|" + b) or cut.has(b + "|" + a): continue
		var d: float = (nodes[a] as Vector3).distance_to(nodes[b]); var kind: String = e[3] if e.size() > 3 else ""
		(adj[a] as Array).push_back([b, d, kind])
		if not (e.size() > 2 and e[2]): (adj[b] as Array).push_back([a, d, kind])

## no crate on a way the toys walk, nor where anyone comes back
func keep_off(x: float, z: float, y: float) -> bool:
	if mode.keep_off(x, z, y): return true
	for a in adj:
		var pa: Vector3 = nodes[a]
		for ed: Array in adj[a]:
			var pb: Vector3 = nodes[ed[0]]
			if absf(y - pa.y) > 2.0 and absf(y - pb.y) > 2.0: continue
			if _seg_d(Vector2(x, z), Vector2(pa.x, pa.z), Vector2(pb.x, pb.z)) < 2.6: return true
	return false

static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a; var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.0001 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## the waypoint nearest a place that can be walked to straight from it (on the same level, nothing in the way)
func nearest_node(p: Vector3) -> String:
	var any := ""; var ad := INF; var near: Array = []
	for n in nodes:
		var q: Vector3 = nodes[n]; var d := p.distance_to(q) + absf(p.y - q.y) * 4.0
		if d < ad: ad = d; any = n
		if absf(p.y - q.y) <= 1.7 and d <= 40.0: near.push_back([d, n])
	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for c: Array in near:
		var q: Vector3 = nodes[c[1]]
		if Phys.line_of_sight(p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0)): return c[1]
	return any

## a straight walk with nothing in the way, on one level
func walkable(a: Vector3, b: Vector3) -> bool:
	if absf(a.y - b.y) > 1.0: return false
	return Phys.line_of_sight(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0)) and Phys.line_of_sight(a + Vector3(0, 0.35, 0), b + Vector3(0, 0.35, 0))

## the way from one place to another: the waypoints, then the place. bias makes some kinds of way dearer or cheaper
## ({"bed": 0.5} likes the crawl space under the bed); {"@node": metres} puts a price on passing a waypoint (someone waits there)
func route(from: Vector3, to: Vector3, bias := {}) -> Array:
	if from.distance_to(to) < 26.0 and walkable(from, to): return [to]
	var s := nearest_node(from); var g := nearest_node(to)
	if s == "" or g == "" or s == g: return [to]
	var dist := {s: 0.0}; var prev := {}; var open: Array = [s]; var done := {}
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[bi]]): bi = i
		var c: String = open[bi]; open.remove_at(bi)
		if done.has(c): continue
		done[c] = true
		if c == g: break
		for ed: Array in adj[c]:
			var nb: String = ed[0]; var w: float = float(ed[1]) * float(bias.get(ed[2], 1.0)) + float(bias.get("@" + nb, 0.0))
			var nd: float = float(dist[c]) + w
			if not dist.has(nb) or nd < float(dist[nb]): dist[nb] = nd; prev[nb] = c; open.push_back(nb)
	if not dist.has(g): return [to]
	var path: Array = [to]; var c2 := g
	while c2 != s: path.push_front(nodes[c2]); c2 = prev[c2]
	path.push_front(nodes[s])
	# no walking back to a waypoint behind you: straight on to the next one when nothing is in the way
	for i in 2:
		if path.size() >= 2 and walkable(from, path[1]): path.pop_front()
	return path

# ---------------- the toys ----------------
## a toy for either side, at a place: put on the list it belongs on (ours are kept apart from the enemies' list)
func add_unit(team: String, type: String, at: Vector3, opts := {}) -> Enemies.Foe:
	var o := {"role": "sniper" if str(opts.get("gun", "")) == "sniper" else "trooper", "tint": 2 if team == "us" else int(opts.get("tint", 0)), "yaw": float(opts.get("yaw", 0.0 if team == "them" else PI)), "y": at.y}
	o.merge(opts, true)
	if team == "us": o.tint = 2
	var e := en.spawn(type, at.x, at.z, o)
	e.k.team = team; e.k.job = str(opts.get("job", "push")); e.k.base_job = e.k.job; e.k.gun = str(opts.get("gun", "ally" if team == "us" else "trooper"))
	e.k.path = []; e.k.pi = 0; e.k.gat = null; e.k.near = 1.0; e.k.think_t = randf() * 0.3; e.k.tgt = null; e.k.hurry = false; e.k.bias = {}
	e.k.stuck_t = 0.0; e.k.sx = e.pos.x; e.k.sz = e.pos.z; e.k.dodge = 0.0; e.k.dodge_dir = Vector2.ZERO; e.k.repath_t = 0.0; e.k.carrying = null
	e.k.sight = 95.0 if e.k.gun == "sniper" else SIGHT; e.k.spawn_opts = opts.duplicate(); e.k.type0 = type; e.k.post = at
	e.alert = true; e.awake = true; e.react = 0.4; e.pos.y = at.y; e.g.position = e.pos
	if team == "us":
		en.list.erase(e); allies.push_back(e); e.hp = ALLY_HP; e.max_hp = ALLY_HP; e.speed = 3.6 * randf_range(0.95, 1.05)
		if _blue_bar == null: _blue_bar = (en._bar_fill as StandardMaterial3D).duplicate(); _blue_bar.albedo_color = Color("5f9cff")
		e.fill.material_override = _blue_bar
	mode.on_respawn(e, team)
	return e

func units(team: String) -> Array:
	if team == "us": return allies.filter(func(a): return a.alive and not bool(a.k.get("gone", false)))
	return en.list.filter(func(e): return e.alive and e.k.has("team") and not bool(e.k.get("gone", false)))

func player_in() -> bool: return player.out == false and down_t <= 0.0 and not bool(game.ended)

## who or what a toy can be after: the player or a toy, alive and in play
func alive(t) -> bool:
	if t == null: return false
	if t is Player: return player_in()
	return t.alive and not bool(t.k.get("gone", false))

func feet(t) -> Vector3: return player.pos if t is Player else t.pos
func eye_of(t) -> Vector3: return player.pos + Vector3(0, Player.EYE, 0) if t is Player else t.pos + Vector3(0, t.eye_h * t.scale, 0)
func vel_of(t) -> Vector3: return player.vel if t is Player else t.vel

## the nearest enemy in sight (one carrying something the mode cares about counts as 10 m nearer)
func _target(u: Enemies.Foe):
	var team: String = u.k.team; var eye := u.pos + Vector3(0, u.eye_h * u.scale, 0); var sight: float = u.k.sight
	var cands: Array = []
	if team == "them":
		if player_in(): cands.push_back([u.pos.distance_to(player.pos) - (10.0 if carrying(player) else 0.0), player])
		for a in allies:
			if a.alive and not bool(a.k.get("gone", false)): cands.push_back([u.pos.distance_to(a.pos) - (10.0 if a.k.carrying != null else 0.0), a])
	else:
		for e in en.list:
			if e.alive and e.k.has("team") and not bool(e.k.get("gone", false)): cands.push_back([u.pos.distance_to(e.pos) - (10.0 if e.k.carrying != null else 0.0), e])
	cands = cands.filter(func(c): return float(c[0]) < sight)
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in mini(3, cands.size()):
		if Phys.line_of_sight(eye, eye_of(cands[i][1])): return cands[i][1]
	return null

## the player counts as carrying when the mode gives him something to carry
func carrying(t) -> bool:
	if t is Player: return mode.has_method("player_carrying") and mode.player_carrying()
	return t.k.carrying != null

func _set_goal(u: Enemies.Foe, g: Dictionary) -> void:
	var k := u.k
	if g.is_empty(): k.path = []; k.gat = null; return
	var at: Vector3 = g.at; k.near = float(g.get("near", 1.2)); k.hurry = bool(g.get("hurry", false))
	var b: Dictionary = g.get("bias", {}); k.repath_t = float(k.repath_t) - 0.35
	var old = k.gat
	if old == null or (old as Vector3).distance_to(at) > 6.0 or bool(k.get("repath", false)) or float(k.repath_t) <= 0.0 or (k.path as Array).is_empty() or b != k.bias:
		k.gat = at; k.bias = b; k.path = route(u.pos, at, b); k.pi = 0; k.repath = false; k.repath_t = 6.0
	elif (old as Vector3).distance_to(at) > 0.3:   # it has moved a little (the train, someone you follow): the last leg goes to where it is now
		k.gat = at; (k.path as Array)[(k.path as Array).size() - 1] = at

## the way to walk now along the path; zero when there (or nowhere to go)
func _steer(u: Enemies.Foe) -> Vector2:
	var k := u.k; var path: Array = k.path
	for guard in 3:
		if path.is_empty() or int(k.pi) >= path.size(): return Vector2.ZERO
		var p: Vector3 = path[k.pi]; var last := int(k.pi) >= path.size() - 1
		var d := Vector2(p.x - u.pos.x, p.z - u.pos.z)
		var reach: float = float(k.near) if last else 0.9
		if d.length() < reach and (last or absf(p.y - u.pos.y) < 1.6):
			if last: return Vector2.ZERO
			k.pi = int(k.pi) + 1; continue
		return d.normalized()
	return Vector2.ZERO

func _move(u: Enemies.Foe, vx: float, vz: float, dt: float) -> bool:
	var res := Phys.move_xz(u.pos, vx * dt, vz * dt, u.R, u.H, 0.5); u.pos = res[0]
	var gy := Phys.ground_at(u.pos.x, u.pos.y, u.pos.z, u.R)
	if u.pos.y > gy + 0.001: u.vy -= 19.0 * dt; u.pos.y = maxf(gy, u.pos.y + u.vy * dt)
	else: u.pos.y = gy; u.vy = 0.0
	u.pos.x = clampf(u.pos.x, -Phys.HALF + u.R, Phys.HALF - u.R); u.pos.z = clampf(u.pos.z, -Phys.HALF + u.R, Phys.HALF - u.R)
	return res[1]

## one toy's turn: what to be after, where to go, walking there, shooting what it sees
func unit(u: Enemies.Foe, dt: float) -> void:
	var k := u.k
	if bool(k.get("gone", false)): return
	var held := mode.hold(u)
	k.think_t = float(k.think_t) - dt
	if float(k.think_t) <= 0.0:
		k.think_t = randf_range(0.3, 0.42)
		k.tgt = null if held else _target(u)
		_set_goal(u, mode.goal(u))
	var tg = k.tgt
	if tg != null and not alive(tg): tg = null; k.tgt = null
	var shoot: bool = tg != null and not held and k.carrying == null
	var want := Vector2.ZERO if held else _steer(u)
	if float(k.dodge) > 0.0: k.dodge = float(k.dodge) - dt; want = k.dodge_dir
	var sp: float = u.speed * (0.85 if k.carrying != null else 1.0)
	if shoot and not bool(k.hurry):   # in a fight: slower, sidestepping
		u.strafe_t -= dt
		if u.strafe_t <= 0.0: u.strafe *= -1.0; u.strafe_t = randf_range(0.9, 2.2)
		var to := Vector2(feet(tg).x - u.pos.x, feet(tg).z - u.pos.z).normalized()
		want = (want * 0.6 + Vector2(-to.y, to.x) * u.strafe * 0.5); sp *= 0.5
	var slip: Vector2 = k.get("slip", Vector2.ZERO)
	var mv := want * sp + slip
	var before := u.pos
	var blocked := _move(u, mv.x + u.vel.x, mv.y + u.vel.z, dt); u.vel *= exp(-dt * 6.0)
	k.moved = before.distance_to(u.pos) / maxf(dt, 0.0001)
	# stuck against something: a step aside, then a new way
	k.stuck_t = float(k.stuck_t) + dt
	if float(k.stuck_t) > 1.4:
		if want.length() > 0.1 and Vector2(u.pos.x - float(k.sx), u.pos.z - float(k.sz)).length() < 0.5:
			var side := Vector2(-want.y, want.x) * (1.0 if randf() < 0.5 else -1.0); k.dodge = 0.7; k.dodge_dir = (side + want * -0.3).normalized(); k.repath = true; k.think_t = 0.7
		k.stuck_t = 0.0; k.sx = u.pos.x; k.sz = u.pos.z
	if blocked and float(k.dodge) <= 0.0 and want.length() > 0.1: u.strafe *= -1.0
	# facing: the enemy it fights, else the way it walks, else where the mode wants it to look
	if shoot: var tp := feet(tg); en._turn_toward(u, atan2(tp.x - u.pos.x, tp.z - u.pos.z), 7.0, dt)
	elif mv.length() > 0.3: en._turn_toward(u, atan2(mv.x, mv.y), 7.0, dt)
	elif k.has("look"): var lk: Vector3 = k.look; en._turn_toward(u, atan2(lk.x - u.pos.x, lk.z - u.pos.z), 3.0, dt)
	if shoot:
		u.react -= dt
		var d := u.pos.distance_to(feet(tg))
		if u.react <= 0.0 and d < float(GUNS[k.gun][10]): _burst(u, tg, dt)
	else:
		u.react = maxf(u.react, 0.35); u.burst = 0
		var st = null if held else mode.spare_target(u)   # nothing to fight: the mode's things to shoot (traps on the track)
		if st != null:
			en._turn_toward(u, atan2((st as Vector3).x - u.pos.x, (st as Vector3).z - u.pos.z), 7.0, dt)
			u.fire_t -= dt
			if u.fire_t <= 0.0: u.fire_t = randf_range(0.5, 0.8); _shot_at(u, st, GUNS[k.gun])
	if not held or float(k.get("slip_t", 0.0)) > 0.0: toys._walk(u, minf(sp, (mv.length())), dt, shoot)
	if k.carrying != null: u.arm_l.rotation = Vector3(-2.7, 0, 0.25); u.arm_r.rotation = Vector3(-2.7, 0, -0.25)   # held up over its head

func _burst(u: Enemies.Foe, t, dt: float) -> void:
	var G: Array = GUNS[u.k.gun]
	u.fire_t -= dt
	if u.burst > 0:
		u.burst_t -= dt
		if u.burst_t <= 0.0: u.burst -= 1; u.burst_t = G[2]; _shot(u, t, G)
	elif u.fire_t <= 0.0: u.burst = randi_range(G[0], G[1]); u.burst_t = 0.0; u.fire_t = randf_range(G[3], G[4])

func _shot(u: Enemies.Foe, t, G: Array) -> void:
	var mz := en.muzzle_of(u); var tp := feet(t); var d := mz.distance_to(tp); var lead: Vector3 = vel_of(t) * d / (float(G[5]) * 1.3)
	var aim := Vector3(tp.x + lead.x, tp.y + (1.25 if t is Player else 1.0 * t.scale), tp.z + lead.z)
	for i in int(G[9]): proj.bullet(mz, aim, G[5], float(G[6]) * u.dmg_mul, float(G[7]) + d * float(G[8]), u.k.team)
	Snd.play(G[11], 1.0, mz); u.k.reveal = 1.5; mode.on_shot(u)

func _shot_at(u: Enemies.Foe, at: Vector3, G: Array) -> void:
	var mz := en.muzzle_of(u)
	proj.bullet(mz, at, G[5], float(G[6]) * u.dmg_mul, 0.08, u.k.team)
	Snd.play(G[11], 1.0, mz); mode.on_shot(u)

## where a toy and its health bar are drawn (the enemies' own loop does this for theirs)
func place(u: Enemies.Foe) -> void:
	u.g.position = u.pos; u.g.rotation.y = u.yaw
	if u.hp < u.max_hp and u.g.visible and not bool(u.k.get("gone", false)):
		u.bar.visible = true; u.bar.position = Vector3(u.pos.x, u.pos.y + u.H + 0.4 * u.scale, u.pos.z)
		var f := clampf(u.hp / u.max_hp, 0.0, 1.0); u.fill.scale.x = 0.66 * f; u.fill.position.x = -0.33 * (1.0 - f)
	else: u.bar.visible = false

# ---------------- hits ----------------
## the toys a bullet could meet this frame, near the way it goes: ours for theirs, theirs for ours
func bullet_cands(from: Vector3, to: Vector3, team: String) -> Array:
	var out: Array = []; var lo := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z)) - Vector3(1.2, 2.2, 1.2); var hi := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z)) + Vector3(1.2, 0.5, 1.2)
	var pool: Array = allies if team == "them" else en.list
	for u in pool:
		if not u.alive or bool(u.k.get("gone", false)) or not u.k.has("team"): continue
		var p: Vector3 = u.pos
		if p.x < lo.x or p.x > hi.x or p.z < lo.z or p.z > hi.z or p.y < lo.y or p.y > hi.y: continue
		out.push_back(u)
	return out

func bullet_hits(u: Enemies.Foe, p: Vector3) -> bool:
	var r := u.R + 0.12
	if absf(p.x - u.pos.x) > r or absf(p.z - u.pos.z) > r: return false
	if Vector2(p.x - u.pos.x, p.z - u.pos.z).length() > r: return false
	return p.y > u.pos.y + 0.05 and p.y < u.pos.y + u.H + 0.1

## a bullet reached a toy: theirs is hurt as the player's shots hurt it (but pays nothing); ours loses health
func bullet_hit(u: Enemies.Foe, p: Vector3, dmg: float, vel: Vector3, src: Vector3) -> void:
	var weak := p.y > u.pos.y + u.H - 0.34
	if u.k.team == "them":
		u.k.by_ally = true; en.damage(u, dmg * (1.5 if weak else 1.0), p, vel.normalized(), weak); u.k.by_ally = false
	else: hurt_ally(u, dmg * (1.5 if weak else 1.0), src)

func hurt_ally(a: Enemies.Foe, dmg: float, from: Vector3) -> void:
	if not a.alive or bool(a.k.get("gone", false)): return
	a.hp -= dmg; a.flinch = 1.0
	if fx: fx.sparks(a.pos + Vector3(0, 1.1, 0), 3, [0.6, 0.75, 1.0], 2.5)
	if a.hp <= 0.0: ally_down(a, "them", from)

## one of ours falls: he tips over where he stood, drops what he carried, and is back at the base later
func ally_down(a: Enemies.Foe, by: String, from := Vector3.ZERO) -> void:
	if not a.alive: return
	a.alive = false; a.dead_t = 0.0; a.bar.visible = false; a.g.visible = true
	var dir := (a.pos - from).normalized() if from != Vector3.ZERO else Vector3(0, 0, 1)
	a.fall_dir = 1.0 if sin(a.yaw) * dir.x + cos(a.yaw) * dir.z > 0.0 else -1.0
	allies.erase(a); en.dying.push_back(a); Snd.play("thud", 1.0, a.pos)
	mode.on_ally_down(a, by)
	if by != "box": queue.push_back({"team": "us", "type": "soldier", "opts": a.k.spawn_opts, "t": BACK.us})
	if by == "them": score.them = int(score.them) + 1
	game.say_feed("아군 병정이 쓰러졌습니다")

## one of theirs fell (to your shot or one of ours): the pay, the line in the feed, the point, and he comes back
func on_kill(e: Enemies.Foe, weak: bool) -> void:
	var by := "ally" if bool(e.k.get("by_ally", false)) else "player"
	if by == "player": game.kills += 1; game.stats.kills += 1
	if weak and by == "player": game.stats.heads += 1
	var pay := 0 if (game.replay or by != "player") else roundi(float(e.T.get("money", 1000)) * KILL_PAY * (1.5 if weak else 1.0))
	Store.save.money += pay; game.stats.earned += pay; Store.persist()
	Snd.play("kill")
	if pay > 0: Snd.play("coin"); game._say(game.on_pay, [pay])
	game._say(game.feed, [(str(e.T.name) + (" · 머리 명중" if weak else " 처치")) if by == "player" else "아군이 " + str(e.T.name) + " 처치", pay, weak])
	score.us = int(score.us) + 1
	mode.on_kill(e, by)
	queue.push_back({"team": "them", "type": str(e.k.type0), "opts": e.k.spawn_opts, "t": BACK.them})

## you fell: the mode takes what you had, and you are back at your base in a few seconds
func player_down(why := "dead", wait := PLAYER_BACK) -> void:
	if player.out: return
	player.out = true; player.hp = 0.0; player.vel = Vector3.ZERO; player.jet_end(); down_t = wait; down_why = why
	if room != null: room.riding = null
	guns.trigger = false; guns.ads_held = false; guns.reload_t = 0.0
	if why == "dead": score.them = int(score.them) + 1
	mode.on_player_down()
	if why == "dead": game.say_banner("쓰러졌습니다", "%d초 뒤 아군 기지에서 다시 출동합니다" % ceili(wait), 2.0); Snd.play("thud")

func _player_back() -> void:
	var p := mode.spawn_at("us", "player")
	player.reset(p.x, p.z, face_in(p)); player.pos.y = p.y; player.out = false; player.invuln = 2.0; down_t = 0.0
	guns.reset(game.layout()); guns.lock_to = ""
	mode.on_respawn(player, "us"); Snd.play("spawn")
	game.say_banner("다시 출동", "아군 기지", 1.4)

# ---------------- the match's turn ----------------
func update(dt: float) -> void:
	clock += dt
	if down_t > 0.0 and not bool(game.ended):
		down_t -= dt
		if down_t <= 0.0: _player_back()
	for i in range(queue.size() - 1, -1, -1):
		var q: Dictionary = queue[i]; q.t = float(q.t) - dt
		if float(q.t) > 0.0 or bool(game.ended): continue
		queue.remove_at(i)
		var at := mode.spawn_at(q.team, str(q.opts.get("job", q.type)))
		add_unit(q.team, q.type, at, q.opts)
		if fx: fx.spark(at + Vector3(0, 1.0, 0))
	for a in allies.duplicate():
		if not a.alive: continue
		unit(a, dt); place(a)
		if a.alive and not bool(a.k.get("gone", false)) and en.animals.m == null: en._keep_out(a)
	_part_allies()
	mode.update(dt)

## our soldiers do not stand inside one another
func _part_allies() -> void:
	for i in allies.size():
		var a: Enemies.Foe = allies[i]
		if not a.alive: continue
		for j in range(i + 1, allies.size()):
			var b: Enemies.Foe = allies[j]
			if not b.alive or absf(a.pos.y - b.pos.y) > 1.2: continue
			var d := Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z); var l := d.length(); var r := a.R + b.R + 0.1
			if l < r and l > 0.001:
				var push := d / l * (r - l) * 0.5
				a.pos = Phys.move_xz(a.pos, -push.x, -push.y, a.R, a.H, 0.0)[0]; b.pos = Phys.move_xz(b.pos, push.x, push.y, b.R, b.H, 0.0)[0]

func clear() -> void:
	mode.cleanup()
	for a in allies:
		if is_instance_valid(a.g): a.g.queue_free()
		if is_instance_valid(a.bar): a.bar.queue_free()
	allies.clear(); queue.clear()

## the way to face from a place to look at the middle of the room (your turn: 0 looks north, along -z)
static func face_in(p: Vector3) -> float:
	if Vector2(p.x, p.z).length() < 1.0: return 0.0
	return atan2(p.x, p.z)

## the line in the pause screen and the map's heading
func summary() -> String: return mode.pause_line()
