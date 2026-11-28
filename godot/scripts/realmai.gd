class_name RealmAI
extends RefCounted
## The realm's other nine: where they walk and how they fight. They find their way about the Silverwood by a graph of
## waypoints (the path, the glade, the ravine's bridge and stairs, the hill, the tower's court, its two flights, the
## gallery and the observatory), go where the mode sends them, pick the nearest foe they can see and fight it as their
## people fights: an elf from far off, a demon at mid range minding its heat, a dwarf and an orc going in close.
## Their hands are the same as yours (RealmKit.act): they only decide what to press.

const TC := ElfWood.TC
# [x, y, z]: y is roughly right (each is set on the ground under it when the graph is built)
const NODES := {
	"w_base": [-146, 3, 0], "w_tn": [-140, 3, -10], "w_n": [-128, 0, -10], "w_ts": [-140, 3, 10], "w_s": [-128, 0, 10],
	"p0": [-120, 0, 0], "p1": [-108, 0, -2], "p2": [-90, 0, 2.5], "p3": [-70, 0, -1], "p4": [-44, 0, 0], "p5": [-31, 0, 0],
	"well": [-22, 0.5, 0], "well_n": [-22, 0.3, -5], "well_s": [-22, 0.3, 5], "well_e": [-17, 0.3, 0], "well_w": [-27, 0.3, 0],
	"g0": [-13, 0, 0], "g1": [3, 0, 0], "g2": [20, 0, 1], "g3": [34, 0, 0], "gate_w": [46, 0, 0],
	"br_w": [53, 0, 0], "br_m": [67, 0, 0], "br_e": [81, 0, 0], "gate_e": [88, 0, 0], "e0": [100, 0, -3], "e1": [108, 0, 0],
	"pw0": [48, 0, 15], "pw1": [51.5, 0, 15], "pw2": [63, -6, 15], "pit": [64, -6, 8.5], "pe0": [71, -6, -8], "pe1": [71.5, -6, -15], "pe2": [83, 0, -15], "pe3": [86, 0, -8],
	"h0": [89.5, 0, 5], "h1": [83, 0, 9.5], "h2": [88.7, 3.3, 9.5], "h3": [88.7, 3.3, 13.3], "h4": [93.7, 6.6, 13.3], "h5": [93.7, 6.6, 16.9], "h6": [98.6, 10, 16.9],
	"stone": [102, 10.4, 16.5], "pl0": [105, 10, 10.8], "pl1": [121, 10, 10.8], "pl2": [124.5, 10, 9.0],
	"c_gate": [110, 0, 0], "c_w": [116, 0, 0], "c_nw": [122, 0, -13], "c_n": [134, 0, -17.5], "c_ne": [147, 0, -11], "c_e": [151.5, 0, 0], "c_se": [147, 0, 11], "c_s": [134, 0, 17.5], "c_sw": [126, 0, 13],
	"ward_a": [127, 0, -17], "ward_b": [128.5, 0, 16], "bast": [120.6, 0.5, 13.4], "lib_port": [142.6, 10, 8.6],
}
const EDGES := [
	["w_base", "w_tn"], ["w_tn", "w_n"], ["w_base", "w_ts"], ["w_ts", "w_s"], ["w_n", "p0"], ["w_s", "p0"], ["p0", "p1"], ["p1", "p2"], ["p2", "p3"], ["p3", "p4"], ["p4", "p5"],
	["p5", "well_w"], ["well_w", "well"], ["well", "well_e"], ["well_w", "well_n"], ["well_w", "well_s"], ["well_n", "well_e"], ["well_s", "well_e"], ["well", "well_n"], ["well", "well_s"],
	["well_e", "g0"], ["g0", "g1"], ["g1", "g2"], ["g2", "g3"], ["g3", "gate_w"], ["gate_w", "br_w"], ["br_w", "br_m"], ["br_m", "br_e"], ["br_e", "gate_e"], ["gate_e", "e0"], ["e0", "e1"], ["e1", "c_gate"],
	["g3", "pw0"], ["pw0", "pw1"], ["pw1", "pw2"], ["pw2", "pit"], ["pit", "pe0"], ["pe0", "pe1"], ["pe1", "pe2"], ["pe2", "pe3"], ["pe3", "gate_e"],
	["gate_e", "h0"], ["e0", "h0"], ["h0", "h1"], ["h1", "h2"], ["h2", "h3"], ["h3", "h4"], ["h4", "h5"], ["h5", "h6"], ["h6", "stone"], ["stone", "pl0"], ["pl0", "pl1"], ["pl1", "pl2"],
	["c_gate", "c_w"], ["c_w", "c_nw"], ["c_nw", "c_n"], ["c_n", "c_ne"], ["c_ne", "c_e"], ["c_e", "c_se"], ["c_se", "c_s"], ["c_s", "c_sw"], ["c_sw", "c_w"],
	["c_nw", "ward_a"], ["c_n", "ward_a"], ["c_sw", "ward_b"], ["c_s", "ward_b"], ["c_sw", "bast"], ["c_w", "bast"],
]
# everyone walks in the same body as you do (the wood's ways were made for it): a people's own size is what can be hit
const MOVE_R := Player.R; const MOVE_H := Player.HEIGHT
const PARRY := 0.9          # how readily they put the dagger up at a missile coming in (a chance a second while one is)
const SKILL := {"elf": 0.02, "demon": 0.032, "dwarf": 0.04, "orc": 0.04}   # how far off their aim wanders (radians), by people

var rm: Realm
var nodes := {}
var adj := {}
var ports: Array = []        # [from node, to node]: a portal's two ends (a one-way step)

# ---------------- the wood's ways ----------------
func build_graph() -> void:
	nodes = {}; adj = {}; ports = []
	if rm.mode.own_graph():   # (a mode on a map of its own: only its waypoints and ways)
		var mine: Array = rm.mode.extra_edges(); nodes.merge(rm.mode.extra_nodes(), true)
		_link(mine); return
	for k: String in NODES: nodes[k] = Vector3(NODES[k][0], NODES[k][1], NODES[k][2])
	var edges: Array = EDGES.duplicate()
	# the tower's first flight (round from the west foot to the gallery), the gallery, the second flight, the observatory
	var f1 := 13
	for i in f1:
		var a := deg_to_rad(180.0 - 358.0 * i / (f1 - 1)); nodes["f1_%d" % i] = Vector3(TC.x + cos(a) * 10.0, ElfWood.T_F2 * i / float(f1 - 1), TC.y + sin(a) * 10.0)
		if i > 0: edges.push_back(["f1_%d" % (i - 1), "f1_%d" % i])
	edges.push_back(["c_w", "f1_0"])
	for i in 10:   # the gallery: from the west (180) by the south and the east to the north (-82)
		var deg := 180.0 - 30.0 * i if i < 9 else -78.0
		nodes["ga_%d" % i] = Vector3(TC.x + cos(deg_to_rad(deg)) * 12.0, ElfWood.T_F2, TC.y + sin(deg_to_rad(deg)) * 12.0)
		if i > 0: edges.push_back(["ga_%d" % (i - 1), "ga_%d" % i])
	edges.push_back(["f1_%d" % (f1 - 1), "ga_0"]); edges.push_back(["pl2", "ga_1"]); edges.push_back(["pl2", "ga_2"]); edges.push_back(["lib_port", "ga_4"]); edges.push_back(["lib_port", "ga_5"])
	for i in f1:
		var a := deg_to_rad(-360.0 * i / (f1 - 1)); nodes["f2_%d" % i] = Vector3(TC.x + cos(a) * 9.3, ElfWood.T_F2 + (ElfWood.T_F3 - ElfWood.T_F2) * i / float(f1 - 1), TC.y + sin(a) * 9.3)
		if i > 0: edges.push_back(["f2_%d" % (i - 1), "f2_%d" % i])
	edges.push_back(["ga_6", "f2_0"])
	var tops := {"top_e": [5.0, 0.0], "top_n": [0.0, -4.6], "top_w": [-4.6, 0.0], "top_s": [0.0, 4.6]}
	for k: String in tops: nodes[k] = Vector3(TC.x + float(tops[k][0]), ElfWood.T_F3, TC.y + float(tops[k][1]))
	edges.append_array([["f2_%d" % (f1 - 1), "top_e"], ["top_e", "top_n"], ["top_n", "top_w"], ["top_w", "top_s"], ["top_s", "top_e"]])
	edges.append_array(rm.mode.extra_edges()); nodes.merge(rm.mode.extra_nodes(), true)
	_link(edges)
	ports = [["bast", "lib_port"]]
	for q: Array in ports: (adj[q[0]] as Array).push_back([q[1], 3.0, "port"])

## the waypoints set on the ground under them, and the ways between them both ways (one way, where an edge says so)
func _link(edges: Array) -> void:
	for k: String in nodes:
		var p: Vector3 = nodes[k]; p.y = Phys.ground_at(p.x, p.y + 0.45, p.z, 0.3); nodes[k] = p; adj[k] = []
	for e: Array in edges:
		var a: String = e[0]; var b: String = e[1]
		if not nodes.has(a) or not nodes.has(b): continue
		var d: float = (nodes[a] as Vector3).distance_to(nodes[b])
		(adj[a] as Array).push_back([b, d])
		if not (e.size() > 2 and e[2]): (adj[b] as Array).push_back([a, d])

func nearest_node(p: Vector3) -> String:
	var any := ""; var ad := INF; var near: Array = []
	for n: String in nodes:
		var q: Vector3 = nodes[n]; var d := p.distance_to(q) + absf(p.y - q.y) * 4.0
		if d < ad: ad = d; any = n
		if absf(p.y - q.y) <= 1.9 and d <= 34.0: near.push_back([d, n])
	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in mini(4, near.size()):
		var q: Vector3 = nodes[near[i][1]]
		if Phys.line_of_sight(p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0)): return near[i][1]
	return any

func walkable(a: Vector3, b: Vector3) -> bool:
	if absf(a.y - b.y) > 0.8 or a.distance_to(b) > 22.0: return false
	if not (Phys.line_of_sight(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0)) and Phys.line_of_sight(a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0))): return false
	# no walking off an edge: the ground under the middle of the way is the ground at its ends
	var m := (a + b) * 0.5
	return absf(Phys.ground_at(m.x, m.y + 0.5, m.z, 0.3) - m.y) < 0.7

## the way from one place to another: waypoints, then the place itself
func route(from: Vector3, to: Vector3, port_ok := true) -> Array:
	if walkable(from, to): return [to]
	var s := nearest_node(from); var g := nearest_node(to)
	if s == "" or g == "": return [to]
	if s == g: return [nodes[s], to]
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
			if ed.size() > 2 and not port_ok: continue
			var nb: String = ed[0]; var nd: float = float(dist[c]) + float(ed[1])
			if not dist.has(nb) or nd < float(dist[nb]): dist[nb] = nd; prev[nb] = c; open.push_back(nb)
	if not dist.has(g): return [to]
	var path: Array = [to]; var c2 := g
	while c2 != s: path.push_front(nodes[c2]); c2 = prev[c2]
	path.push_front(nodes[s])
	for i in 2:
		if path.size() >= 2 and walkable(from, path[1]): path.pop_front()
	return path

# ---------------- a fighter's turn ----------------
func _mind(f: Realm.Fighter) -> Dictionary:
	var b := f.brain
	if b.is_empty():
		b.merge({"think": randf() * 0.3, "tgt": null, "path": [], "pi": 0, "gat": null, "near": 1.2, "hurry": false, "repath": 0.0, "stuck": 0.0, "sx": f.pos.x, "sz": f.pos.z, "dodge": 0.0, "dodge_dir": Vector2.ZERO,
			"side": 1.0 if randf() < 0.5 else -1.0, "side_t": 1.0, "react": 0.4, "err": Vector3.ZERO, "err_t": 0.0, "head": false, "cool": false, "draw": false, "hp": f.hp, "hit_t": 9.0, "role": "", "seen": 0.0})
	return b

func turn(f: Realm.Fighter, dt: float) -> void:
	var b := _mind(f); var held := rm.mode.held(f)
	b.hit_t = float(b.hit_t) + dt
	if f.hp < float(b.hp) - 0.5: b.hit_t = 0.0
	b.hp = f.hp
	b.think = float(b.think) - dt
	if float(b.think) <= 0.0:
		b.think = randf_range(0.25, 0.4)
		var was = b.tgt
		b.tgt = null if held else target(f)
		if b.tgt != null and not _same(was, b.tgt): b.react = randf_range(0.25, 0.5); b.head = f.race == "elf" and randf() < 0.3
		_set_goal(f, {} if held else _goal(f))
	var tg = b.tgt
	if tg != null and not _alive(tg): tg = null; b.tgt = null
	var I := {"move": Vector3.ZERO}; var want := Vector2.ZERO; var pace := 1.0
	if not held and f.stun_t <= 0.0 and f.cast_t <= 0.0:
		want = _steer(f)
		if tg != null:
			var r := _fight(f, tg, want, I, dt); want = r[0]; pace = r[1]
		else:
			if f.ammo < rm.kit.mag(f) and f.reload_t <= 0.0 and (f.race == "elf" or f.race == "dwarf"): I.reload = true
			if want.length() > 0.1: _aim_to(f, Vector3(want.x, 0, want.y), dt, 6.0)
			b.cool = false; b.draw = false
		if float(b.dodge) > 0.0: b.dodge = float(b.dodge) - dt; want = b.dodge_dir
		if want.length() > 0.1 and rm.mode.deadly(f.pos + Vector3(want.x, 0.0, want.y) * 1.2): want = Vector2.ZERO; b.dodge = 0.0   # (6-A: not a step off the bridge)
	rm.kit.act(f, I, dt)
	if (f.grounded or f.pos.y - Phys.ground_at(f.pos.x, f.pos.y + 0.1, f.pos.z, 0.3) < 0.35) and f.vy <= 0.5 and not f.leaping and f.dash_t <= 0.0 and not held and f.stun_t <= 0.0 and rm.mode.jump(f): f.vy = 7.2; f.pos.y += 0.05; f.grounded = false   # (6-A: over a wave of fire; a step down is no reason not to)
	# feet
	var sp := rm.speed_of(f) * pace
	if f.leaping: _fall(f, dt)
	elif f.dash_t > 0.0: pass
	elif f.stun_t > 0.0 or held or f.cast_t > 0.0: _walk(f, Vector2.ZERO, 0.0, dt)
	else:
		var blocked := _walk(f, want, sp, dt)
		b.stuck = float(b.stuck) + dt
		if float(b.stuck) > 1.2:
			if want.length() > 0.1 and Vector2(f.pos.x - float(b.sx), f.pos.z - float(b.sz)).length() < 0.45:
				var side := Vector2(-want.y, want.x) * (1.0 if randf() < 0.5 else -1.0); b.dodge = 0.6; b.dodge_dir = (side - want * 0.3).normalized(); b.repath = 0.0; b.think = 0.5
			b.stuck = 0.0; b.sx = f.pos.x; b.sz = f.pos.z
		if blocked and float(b.dodge) <= 0.0 and want.length() > 0.1: b.side = -float(b.side)
	f.vel = Vector3(want.x * sp, 0, want.y * sp) if not f.leaping else f.vel
	f.yaw = atan2(-f.aim.x, -f.aim.z)

func _same(a, b) -> bool:
	if a == null or b == null: return a == null and b == null
	if a is Realm.Fighter and b is Realm.Fighter: return a == b
	if a is Dictionary and b is Dictionary: return a.get("id", 0) == b.get("id", 1)
	return false

func _alive(t) -> bool:
	if t is Realm.Fighter: return t.alive
	return float((t as Dictionary).get("hp", 1.0)) > 0.0 and float((t as Dictionary).get("t", 1.0)) > 0.0

func _at(t) -> Vector3: return t.pos if t is Realm.Fighter else (t as Dictionary).pos
func _mid(t) -> Vector3: return t.feet_mid() if t is Realm.Fighter else (t as Dictionary).pos + Vector3(0, float((t as Dictionary).get("h", (t as Dictionary).get("H", 1.6))) * 0.55, 0)

func _walk(f: Realm.Fighter, want: Vector2, sp: float, dt: float) -> bool:
	var res := Phys.move_xz(f.pos, want.x * sp * dt, want.y * sp * dt, MOVE_R, MOVE_H, 0.5); f.pos = res[0]
	var gy := Phys.ground_at(f.pos.x, f.pos.y, f.pos.z, MOVE_R)
	if f.pos.y > gy + 0.001: f.vy -= 19.0 * dt; f.pos.y = maxf(gy, f.pos.y + f.vy * dt); f.grounded = f.pos.y <= gy + 0.001
	else: f.pos.y = gy; f.vy = 0.0; f.grounded = true
	f.pos.x = clampf(f.pos.x, -Phys.HALF + MOVE_R, Phys.HALF - MOVE_R); f.pos.z = clampf(f.pos.z, -Phys.HALF + MOVE_R, Phys.HALF - MOVE_R)
	return res[1]

## an orc in the air on his bound: where his leap carries him, till he lands
func _fall(f: Realm.Fighter, dt: float) -> void:
	f.pos = Phys.move_xz(f.pos, f.vel.x * dt, f.vel.z * dt, MOVE_R, MOVE_H, 0.2)[0]
	f.vy -= 19.0 * dt; f.pos.y += f.vy * dt
	var gy := Phys.ground_at(f.pos.x, f.pos.y + 0.5, f.pos.z, MOVE_R)
	if f.pos.y <= gy and f.vy <= 0.0: f.pos.y = gy; f.vy = 0.0; f.grounded = true; f.leaping = false; f.vel = Vector3.ZERO; rm.kit.landed(f)

func _aim_to(f: Realm.Fighter, dir: Vector3, dt: float, rate: float) -> void:
	if dir.length() < 0.001: return
	var d := dir.normalized()
	if f.aim.dot(d) > 0.9999: f.aim = d; return
	f.aim = f.aim.slerp(d, minf(1.0, dt * rate)).normalized()

# ---------------- whom to fight ----------------
## the nearest foe in sight (one carrying the bomb counts as nearer); failing that, a made thing of theirs in sight, or
## what the mode wants struck
func target(f: Realm.Fighter):
	var fz = rm.mode.focus(f)   # (6-A: a boss's crystal, a chain on a friend, the cores: before anyone)
	if fz != null: return fz
	var cands: Array = []
	for e: Realm.Fighter in rm.all:
		if e.alive and e.team != f.team: cands.push_back([f.pos.distance_to(e.pos) - (10.0 if e.carrying else 0.0) - (6.0 if e.mark_t > 0.0 else 0.0), e])
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in mini(4, cands.size()):
		var e: Realm.Fighter = cands[i][1]
		if rm.kit.sees(f, e):
			for dc: Dictionary in rm.kit.decoys:   # an elf's echo standing nearer takes the eye
				if dc.by == e and f.pos.distance_to(dc.pos) < f.pos.distance_to(e.pos) and Phys.line_of_sight(f.eye_at(), (dc.pos as Vector3) + Vector3(0, 1.0, 0)): return dc
			return e
	var eye := f.eye_at()
	for th: Dictionary in rm.kit.things:
		if th.team != f.team and float(th.hp) > 0.0 and not th.get("prize", false) and eye.distance_to(th.pos) < 30.0 and Phys.line_of_sight(eye, (th.pos as Vector3) + Vector3(0, float(th.h) * 0.6, 0)): return th
	var pz = rm.mode.prize(f)
	if pz != null and (pz as Dictionary).get("bldg", false): return pz if rm.kit.sees_thing(f, pz, 40.0) else null   # (a landmark: its own boxes are what a shot at it meets)
	if pz != null and eye.distance_to((pz as Dictionary).pos) < 40.0 and Phys.line_of_sight(eye, ((pz as Dictionary).pos as Vector3) + Vector3(0, float((pz as Dictionary).h) * 0.6, 0)): return pz
	return null

func _goal(f: Realm.Fighter) -> Dictionary:
	var g := rm.mode.goal(f); var b := f.brain; var tg = b.tgt
	if g.get("hurry", false) or tg == null or (tg is Dictionary and (tg as Dictionary).get("bldg", false)): return g   # (a landmark: where the mode sends him to strike it from)
	# those who fight close go for whoever they see near by (the others keep to where the mode sends them)
	if (f.race == "orc" or f.race == "dwarf") and f.pos.distance_to(_at(tg)) < (26.0 if f.race == "orc" else 16.0) and absf(f.pos.y - _at(tg).y) < 5.0 and not g.get("stay", false):
		return {"at": _at(tg), "near": 1.6 if f.race == "orc" else 4.0}
	return g

func _set_goal(f: Realm.Fighter, g: Dictionary) -> void:
	var b := f.brain
	if g.is_empty(): b.path = []; b.gat = null; return
	var at: Vector3 = g.at; b.near = float(g.get("near", 1.2)); b.hurry = bool(g.get("hurry", false)); b.repath = float(b.repath) - 0.35; b.need_y = bool(g.get("y", false))   # (y: he is there only at its height too)
	var old = b.gat
	if old == null or (old as Vector3).distance_to(at) > 5.0 or float(b.repath) <= 0.0 or (b.path as Array).is_empty():
		b.gat = at; b.path = route(f.pos, at, f.port_t <= 0.0); b.pi = 0; b.repath = 5.0
	elif (old as Vector3).distance_to(at) > 0.3: b.gat = at; (b.path as Array)[(b.path as Array).size() - 1] = at

func _steer(f: Realm.Fighter) -> Vector2:
	var b := f.brain; var path: Array = b.path
	for guard in 3:
		if path.is_empty() or int(b.pi) >= path.size(): return Vector2.ZERO
		var p: Vector3 = path[b.pi]; var last := int(b.pi) >= path.size() - 1
		var d := Vector2(p.x - f.pos.x, p.z - f.pos.z)
		if d.length() < (float(b.near) if last else 0.8) and ((last and not b.get("need_y", false)) or absf(p.y - f.pos.y) < (2.5 if last else 1.7)):
			if last: return Vector2.ZERO
			b.pi = int(b.pi) + 1; continue
		return d.normalized()
	return Vector2.ZERO

# ---------------- the fight ----------------
## aim, press, and step as his people fights. [the way to walk, how fast (a part of his speed)]
func _fight(f: Realm.Fighter, tg, want: Vector2, I: Dictionary, dt: float) -> Array:
	var b := f.brain; var kit := rm.kit; var person := tg is Realm.Fighter
	var tp := _at(tg); var d := f.pos.distance_to(tp); var eye := f.eye_at(); var pace := 1.0
	var tv: Vector3 = (tg as Realm.Fighter).vel if person else Vector3.ZERO
	var speed := 150.0 if f.race == "elf" else (75.0 if f.race == "demon" else 1e9)
	var th: float = float(tg.H) if person else float((tg as Dictionary).get("h", (tg as Dictionary).get("H", 1.6)))
	var at := tp + Vector3(0, th * (0.9 if b.head else 0.56), 0) + tv * (d / speed)
	b.err_t = float(b.err_t) - dt
	if float(b.err_t) <= 0.0:
		b.err_t = randf_range(0.2, 0.45); var s := float(SKILL[f.race]) * d * (1.0 + minf(1.5, tv.length() / 6.0)) * (0.35 if not person else 1.0)
		b.err = Vector3(randfn(0.0, s), randfn(0.0, s * 0.6), randfn(0.0, s))
	var dir := (at + (b.err as Vector3) - eye).normalized()
	_aim_to(f, dir, dt, 10.0)
	b.react = float(b.react) - dt
	var ready := float(b.react) <= 0.0 and f.aim.dot(dir) > 0.99
	var to := Vector2(tp.x - f.pos.x, tp.z - f.pos.z); var away := -to.normalized() if to.length() > 0.01 else Vector2.ZERO
	b.side_t = float(b.side_t) - dt
	if float(b.side_t) <= 0.0: b.side = -float(b.side); b.side_t = randf_range(0.8, 2.0)
	var strafe := Vector2(-to.y, to.x).normalized() * float(b.side) if to.length() > 0.01 else Vector2.ZERO
	var hurry: bool = b.hurry; var level := absf(tp.y - f.pos.y) < 2.5
	match f.race:
		"elf":
			if person and d < 9.0 and not hurry: want = away; pace = 1.0
			elif d < 30.0 and not hurry: want = strafe; pace = 0.55
			# the heavy shot now and then, from far off or at someone standing still
			if not bool(b.draw) and f.charge <= 0.0 and f.ammo > 2 and d > 18.0 and randf() < dt * 0.35: b.draw = true
			if bool(b.draw):
				I.alt = not f.charged or not ready
				if f.charged and ready: b.draw = false
				if f.charge > 2.5: b.draw = false
			else: I.fire = ready and d < 90.0
		"demon":
			if person and d < 7.0 and not hurry: want = away
			elif d < 20.0 and not hurry: want = strafe; pace = 0.6
			elif d > 26.0 and level and not hurry: want = to.normalized()
			if f.heat >= 95.0: b.cool = true
			elif f.heat < 84.0: b.cool = false
			var beam: bool = person and (tg as Realm.Fighter).hp < 55.0 and f.hp > 110.0 and d < 26.0 and bool(b.cool)
			I.alt = beam and ready
			I.fire = ready and d < 55.0 and not bool(b.cool) and not beam
		"dwarf":
			if d > 4.0 and level and not hurry and kit_walk(f, tp): want = to.normalized()
			elif d < 2.2 and not hurry: want = strafe; pace = 0.6
			I.fire = ready and d < 14.0
			I.alt = ready and d > 7.0 and d < 24.0 and f.alt_cd <= 0.0 and person
		"orc":
			if d > 1.9 and level and kit_walk(f, tp) and not hurry: want = to.normalized()
			var reach := float(Races.SWORD.reach) + (float(tg.R) if person else float((tg as Dictionary).get("r", 0.5)))
			I.fire = d < reach - 0.2 and f.aim.dot(dir) > 0.8
			I.alt = ready and d > 7.0 and d < 27.0 and f.alt_cd <= 0.0 and f.swing_t <= 0.0
	# the dagger: someone weak within its reach is finished; a blade while the weapon is being loaded
	if person and d < float(Races.DAGGER.reach) + float(tg.R) - 0.3 and f.dag_t <= 0.0 and f.aim.dot(dir) > 0.8:
		if (tg as Realm.Fighter).hp <= float(Races.DAGGER.execute) or f.reload_t > 0.0 or f.seal_t > 0.0 or (f.race != "orc" and f.race != "dwarf" and f.fire_t > 0.0 and randf() < dt * 3.0): I.slash = true
	# a missile coming at him: the dagger up, sometimes
	if f.parry_cd <= 0.0:
		for s: Dictionary in kit.shots:
			if s.team == f.team or s.kind == "flask": continue
			var gap: Vector3 = f.feet_mid() - (s.pos as Vector3); var far := gap.length()
			if far < 9.0 and far > 0.5 and (s.vel as Vector3).normalized().dot(gap / far) > 0.985 and randf() < dt * PARRY: I.parry = true; break
	_shift(f, tg, d, to, away, strafe, I, person, level)
	# a bomb at whoever stands about within a throw
	if person and f.bombs > 0 and d > 6.0 and d < 17.0 and ready and randf() < dt * 0.3: I.bomb = true
	# the ultimate
	if f.gauge >= float(Races.GAUGE.max) and person and float(b.react) <= 0.0:
		match f.race:
			"elf":
				if d < float(Races.ULT.elf.range): b.ult_at = tp; I.ult = true
			"dwarf":
				if d < 12.0: I.ult = true
			"orc":
				if d < 11.0: I.ult = true
			"demon":
				if d < 8.5: I.ult = true
	return [want, pace]

## a straight way to someone on his own level, with ground under it
func kit_walk(f: Realm.Fighter, to: Vector3) -> bool:
	return walkable(f.pos, Vector3(to.x, f.pos.y, to.z)) if f.pos.distance_to(to) < 21.0 else false

func _shift(f: Realm.Fighter, tg, d: float, to: Vector2, away: Vector2, strafe: Vector2, I: Dictionary, person: bool, level: bool) -> void:
	if f.skill_n <= 0 or f.skill_gap > 0.0 or f.dash_t > 0.0 or f.leaping or not person: return
	var b := f.brain; var foe: Realm.Fighter = tg
	match f.race:
		"elf":   # away from whoever comes close with a blade or a cannon
			if d < 6.5 and (foe.race == "orc" or foe.race == "dwarf") and _free(f, away, 5.0): I.skill = true; I.move = Vector3(away.x, 0, away.y)
		"dwarf":   # into them
			if d > 4.5 and d < 8.5 and level and kit_walk(f, foe.pos): I.skill = true; I.move = Vector3(to.x, 0, to.y)
		"orc":
			if d > 6.0 and d < 12.5 and level and Phys.line_of_sight(f.eye_at(), foe.feet_mid()) and kit_walk(f, foe.pos): I.skill = true
		"demon":   # hurt just now, or the staff about to seal
			if (float(b.hit_t) < 0.25 or f.heat >= 93.0) and _free(f, strafe, 5.0): I.skill = true; I.move = Vector3(strafe.x, 0, strafe.y)

## whether there is floor a few metres that way (no stepping off a bridge or a deck)
func _free(f: Realm.Fighter, dir: Vector2, far: float) -> bool:
	if dir.length() < 0.01: return false
	var p := f.pos + Vector3(dir.x, 0, dir.y) * far
	return absf(Phys.ground_at(p.x, f.pos.y + 0.6, p.z, 0.3) - f.pos.y) < 0.8 and Phys.line_of_sight(f.pos + Vector3(0, 0.9, 0), p + Vector3(0, 0.9, 0))
