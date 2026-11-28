class_name CalderaField
extends RefCounted
## 6-B's team battles on the caldera (Caldera, 심연의 흑요석 제단): the others' ways about it, and what the place does
## to everyone in the fight.
##   The ways (RealmAI's graph): waypoints over its three tiers. The sanctum and its four bridges; the ring's arcs, the
##   foundries' narrow ways and the bases' terraces behind them; each spire's causeway, its stair round the column (a
##   landing at each corner) to the gallery's door and on up to the lookout; the gallery's two halves; the trench's
##   stones and the two stairs down to them. Waypoints in the open are joined to their neighbours wherever the way
##   between can be walked. The stones are jumped between (RealmMode.jump: at a stone's edge, the lava ahead). What is
##   neither walked nor jumped: a soul chain climbed (foot to top) or slid down (top to foot), and a blood-pact gate stepped
##   into (to the gallery over it, for 35 of one's health). Once the magma tide is up the stones are gone from it and the
##   four floating slabs are in it; when it ebbs (a new round), the other way about.
##   The place, in the realm's frame (Realm._circles): the lava takes whoever falls in (the paper's falls to the death);
##   the gates carry; the chains are climbed (by you: hold jump; nothing but the dagger meanwhile); the quench troughs
##   put out what burns; the briars slow and cut, and mend the demons by them; a glass-cactus shatters on one shoved into
##   it. A brazier, a cap or a cactus a shot strikes (or a burst reaches) goes off: the brazier's fire on the ground is a
##   fire field laid by whoever knocked it over (the demons' kinship with fire feeds on it). The cooling circle under a
##   demon's staff and the hellfire rings a missile flies through are RealmKit's to see to; the ash clouds hide in its
##   sight too.

const CLIMB := 4.2           # up a soul chain, m/s (as you climb it in the hunt)
const SLIDE := 7.0           # down one
const GATE_CD := 2.5         # a gate carries one again only this long after
const LAVA_GRACE := 0.05     # (in the lava: the feet this far under its face)
const JUMP_GAP := 3.1        # the widest stretch of lava the others leap
const TRENCH := [12.6, 30.0] # the trench's reach out from the middle (where the lava between the stones is no wall to them)

# ---------------- the ways ----------------
## the graph: {"nodes": {name: Vector3}, "edges": [[a, b]], "climbs": [[foot, top]], "slides": [[top, foot]], "ports":
## [[gate, landing]]}. Three states of it, by the lava (state_of): at rest; rising (the trench's ways only lead out of it:
## its stairs up only, no slides down); risen (no trench; the floating slabs). And while the siege's seals stand (sealed),
## no way over the bridges on to the sanctum. What never changes (all but the trench, the slabs and the bridges' heads) is
## worked out once and kept (graph_base): laying the ways out again as the lava moves is then quick
static func state_of(a: Caldera) -> int: return 0 if not a.tide_on else (1 if a.tide < 1.0 else 2)
static func key_of(a: Caldera) -> int: return state_of(a) * 2 + (1 if a.sealed else 0)
static func graph(a: Caldera) -> Dictionary:
	if a.graph_base.is_empty(): a.graph_base = _base(a)
	var B: Dictionary = a.graph_base; var rising := state_of(a) == 1
	var N: Dictionary = (B.nodes as Dictionary).duplicate(); var E: Array = (B.edges as Array).duplicate(); var mid: Array = B.mid
	var climbs: Array = []; var slides: Array = []; var ports: Array = []; var low: Array = []; var extra: Array = []
	var Y := Caldera.MID_Y
	if not a.sealed:   # the bridges' heads on to the sanctum
		for side: String in Caldera.ARCS:
			if N.has("dc_" + side) and N.has("br_%s_0" % side): E.push_back(["dc_" + side, "br_%s_0" % side])
	# the trench, while the lava is not over it: its stones; the stairs down to them; the chains; the gates
	if state_of(a) < 2:
		for i in a.stones.size():
			var st: Dictionary = a.stones[i]; var at: Vector3 = st.at
			N["st_%d" % i] = Vector3(at.x, float(st.top), at.z); low.push_back("st_%d" % i)
		for s: float in [1.0, -1.0]:
			var x := -9.0 * s; var zt := sqrt(Caldera.RING_R0 * Caldera.RING_R0 - x * x) * s; var nm := "tx_%d" % (0 if s > 0.0 else 1)
			_put(N, extra, nm + "_top", Vector3(x, Y, zt + 1.0 * s))
			N[nm + "_mid"] = Vector3(x, (Y + Caldera.LOW_Y) * 0.5, zt + 0.4 * s - 3.1 * s)
			var foot := _stone_at(a, Vector3(x, Caldera.LOW_Y, zt - 7.2 * s))
			if rising: E.append_array([[foot, nm + "_mid", true], [nm + "_mid", nm + "_top", true]])   # (up only)
			else: E.append_array([[nm + "_top", nm + "_mid"], [nm + "_mid", foot]])
		for i in a.chains.size():
			var ch: Dictionary = a.chains[i]; var top: Vector3 = ch.top
			_put(N, extra, "ch_%d" % i, top)
			var foot := _stone_at(a, Caldera.at_deg(float(ch.deg), Caldera.RING_R0 - 1.4, Caldera.LOW_Y))
			climbs.push_back([foot, "ch_%d" % i])
			if not rising: slides.push_back(["ch_%d" % i, foot])
		for side: String in Caldera.GATES: ports.push_back([_stone_at(a, Caldera.GATES[side]), "gt_" + side])
		for i in low.size():   # the stones jumped between (or walked, where they touch)
			var p: Vector3 = N[low[i]]
			for j in range(i + 1, low.size()):
				var q: Vector3 = N[low[j]]
				if p.distance_to(q) < 6.6 and (walk_ok(p, q) or jump_ok(a, p, q)): E.push_back([low[i], low[j]])
	else:   # the four floating slabs, out from the sanctum to the ring (a short leap on to each end)
		for f: Dictionary in a.floats:
			for k in 3: _put(N, extra, "fl_%d_%d" % [int(f.deg), k], Caldera.at_deg(float(f.deg), [15.0, 21.0, 27.0][k], Y))
			for sd: float in [-9.0, 9.0]: _put(N, extra, "fe_%d_%d" % [int(f.deg), int(sd)], Caldera.at_deg(float(f.deg) + sd, 10.6, Y))   # (the sanctum's edge by it, clear of the pillar)
			E.append_array([["fl_%d_0" % int(f.deg), "fl_%d_1" % int(f.deg)], ["fl_%d_1" % int(f.deg), "fl_%d_2" % int(f.deg)]])
	# what came and went joined to its neighbours among the rest, walked or (on to the slabs) leapt
	for nx: String in extra:
		var p: Vector3 = N[nx]
		for nm: String in mid + extra:
			if nm == nx: continue
			var q: Vector3 = N[nm]
			if p.distance_to(q) < 6.6 and (walk_ok(p, q) or (nx.begins_with("fl") and jump_ok(a, p, q))): E.push_back([nx, nm])
	return {"nodes": N, "edges": E, "climbs": climbs, "slides": slides, "ports": ports}

## the ways that never change: the sanctum, the bridges, the ring's arcs, the foundries and terraces, the spires, the
## gallery; each waypoint in the open joined to its neighbours where the way between can be walked
static func _base(a: Caldera) -> Dictionary:
	var N := {}; var E: Array = []; var mid: Array = []; var gal: Array = []
	var Y := Caldera.MID_Y; var G := Caldera.GAL_Y
	# the sanctum: its middle, four toward the bridges, eight between the pillars and the slabs
	_put(N, mid, "d0", Vector3(0, Y, 0))
	for side: String in Caldera.ARCS: _put(N, mid, "dc_" + side, Caldera.at_deg(float(Caldera.ARCS[side]), 9.6, Y))
	for j in 8: _put(N, mid, "dm_%d" % j, Caldera.at_deg(22.5 + 45.0 * j, 6.0, Y))
	# the bridges, three along each (their heads on to the sanctum are graph()'s: the siege seals them)
	for side: String in Caldera.ARCS:
		var m := float(Caldera.ARCS[side])
		for i in 3: _put(N, mid, "br_%s_%d" % [side, i], Caldera.at_deg(m, [13.4, 21.0, 28.8][i], Y))
		E.append_array([["br_%s_0" % side, "br_%s_1" % side], ["br_%s_1" % side, "br_%s_2" % side]])
	# the ring's arcs: three rows along each
	for side: String in Caldera.ARCS:
		var m := float(Caldera.ARCS[side]); var a0 := m - 45.0 + Caldera.GAP_DEG * 0.5 + 2.4; var a1 := m + 45.0 - Caldera.GAP_DEG * 0.5 - 2.4
		for r: float in [31.6, 36.4, 40.4]:
			var n := int(ceil((a1 - a0) * PI / 180.0 * r / 4.2))
			for i in n + 1: _put(N, mid, "ra_%s_%d_%d" % [side, int(r), i], Caldera.at_deg(lerpf(a0, a1, float(i) / n), r, Y))
	# the foundries' narrow ways, the terraces behind them
	for side: String in Caldera.FOUNDRY:
		var s := 1.0 if side == "e" else -1.0
		for q: Array in [["in", 31.4], ["mid", 37.0], ["out", 42.2]]: _put(N, mid, "fd_%s_%s" % [side, q[0]], Vector3(s * float(q[1]), Y, 0.0))
		for xi in 3:
			for zi in 3: _put(N, mid, "tr_%s_%d_%d" % [side, xi, zi], Vector3(s * [44.2, 48.5, 52.8][xi], Y, [-4.6, 0.0, 4.6][zi]))
	# the spires: the causeway, the door, the stair's landings, the gallery's door and its bridge, the lookout
	for i in a.spires.size():
		var sp: Dictionary = a.spires[i]; var c: Vector3 = sp.c; var sx: float = sp.sx; var sz: float = sp.sz; var cw: Dictionary = sp.cw; var br: Dictionary = sp.br
		var zc := (float(cw.z0) + float(cw.z1)) * 0.5; var xr := sx * sqrt(maxf(0.0, Caldera.RING_R1 * Caldera.RING_R1 - zc * zc))
		_put(N, mid, "sp%d_ce" % i, Vector3(xr - sx * 0.6, Y, zc))
		_put(N, mid, "sp%d_cw" % i, Vector3((float(cw.x0) + float(cw.x1)) * 0.5, Y, zc))
		N["sp%d_dr" % i] = Vector3(c.x - sx * (Caldera.SP_H + 0.7), Y, zc)
		var band := (Caldera.SP_COL + Caldera.SP_H - Caldera.SP_WT) * 0.5
		var corners := [Vector2(-sx, sz), Vector2(sx, sz), Vector2(sx, -sz), Vector2(-sx, -sz)]
		var y := Y; var names: Array = ["sp%d_g" % i]
		N["sp%d_g" % i] = Vector3(c.x + float(corners[0].x) * band, Y, c.z + float(corners[0].y) * band)
		for f in Caldera.SP_FLIGHTS.size():
			y += float(Caldera.SP_FLIGHTS[f][0]) * float(Caldera.SP_FLIGHTS[f][1])
			var cn: Vector2 = corners[(f + 1) % 4]; var nm := "sp%d_s%d" % [i, f]
			if f == 3: nm = "sp%d_gd" % i
			if f == 7: nm = "sp%d_top" % i
			N[nm] = Vector3(c.x + cn.x * band, y, c.z + cn.y * band); names.push_back(nm)
		for k in names.size() - 1: E.push_back([names[k], names[k + 1]])
		E.append_array([["sp%d_cw" % i, "sp%d_dr" % i], ["sp%d_dr" % i, "sp%d_g" % i], ["sp%d_ce" % i, "sp%d_cw" % i]])
		var xm := (float(br.x0) + float(br.x1)) * 0.5; var zfar := float(br.z1) if sz > 0.0 else float(br.z0)
		N["sp%d_ud" % i] = Vector3(xm, G, c.z + sz * (Caldera.SP_H + 0.7))
		_put(N, gal, "sp%d_up" % i, Vector3(xm, G, zfar - sz * 0.5))
		E.append_array([["sp%d_gd" % i, "sp%d_ud" % i], ["sp%d_ud" % i, "sp%d_up" % i]])
		N["sp%d_look" % i] = Vector3(c.x, Caldera.LOOK_Y, c.z + sz * band)
		E.push_back(["sp%d_top" % i, "sp%d_look" % i])
	# the gallery's two halves, two rows along each; where the gates set one down
	for side: String in Caldera.GALLERY:
		var a0: float = Caldera.GALLERY[side][0]; var a1: float = Caldera.GALLERY[side][1]
		for r: float in [49.0, 53.0]:
			var n := int(ceil((a1 - a0 - 4.0) * PI / 180.0 * r / 4.4))
			for i in n + 1: _put(N, gal, "ga_%s_%d_%d" % [side, int(r), i], Caldera.at_deg(lerpf(a0 + 2.0, a1 - 2.0, float(i) / n), r, G))
	for side: String in Caldera.GATE_TO: _put(N, gal, "gt_" + side, Caldera.GATE_TO[side])
	for tier: Array in [mid, gal]:
		for i in tier.size():
			var p: Vector3 = N[tier[i]]
			for j in range(i + 1, tier.size()):
				var q: Vector3 = N[tier[j]]
				var pair := str(tier[i]) + str(tier[j])
				if pair.begins_with("dc_") and pair.find("br_") >= 0: continue   # (a bridge's head: graph()'s, by the seals)
				if str(tier[i]).begins_with("br_") and str(tier[j]).begins_with("dc_"): continue
				if p.distance_to(q) < 6.8 and walk_ok(p, q): E.push_back([tier[i], tier[j]])
	return {"nodes": N, "edges": E, "mid": mid, "gal": gal}

## a waypoint where there is room to stand (none in a wall, none over the lava)
static func _put(N: Dictionary, tier: Array, name: String, p: Vector3) -> void:
	var gy := Phys.ground_at(p.x, p.y + 0.6, p.z, 0.3)
	if absf(gy - p.y) > 0.7 or Phys.collide_at(p.x, gy + 0.15, p.z, 0.45, 1.6) != null: return
	N[name] = Vector3(p.x, gy, p.z); tier.push_back(name)

## the trench's stone nearest a place (its waypoint's name)
static func _stone_at(a: Caldera, p: Vector3) -> String:
	var best := 0; var bd := INF
	for i in a.stones.size():
		var d := Vector2((a.stones[i].at as Vector3).x - p.x, (a.stones[i].at as Vector3).z - p.z).length()
		if d < bd: bd = d; best = i
	return "st_%d" % best

## whether the way from a to b can be walked: nothing in the way at the knee or the chest, and ground all along it at
## its own height (no step off an edge, no stretch of lava)
static func walk_ok(a: Vector3, b: Vector3) -> bool:
	if absf(a.y - b.y) > 0.8: return false
	if not (Phys.line_of_sight(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0)) and Phys.line_of_sight(a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0))): return false
	var n := maxi(2, int(a.distance_to(b) / 0.6))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if absf(Phys.ground_at(p.x, p.y + 0.5, p.z, 0.3) - p.y) > 0.6: return false
	return true

## whether one leaps from a to b: no wall between, solid at both ends, no more than JUMP_GAP of lava between, level
static func jump_ok(a: Caldera, p: Vector3, q: Vector3) -> bool:
	if absf(p.y - q.y) > 0.6 or lava_under(a, p) or lava_under(a, q): return false
	if not (Phys.line_of_sight(p + Vector3(0, 0.9, 0), q + Vector3(0, 0.9, 0)) and Phys.line_of_sight(p + Vector3(0, 1.6, 0), q + Vector3(0, 1.6, 0))): return false
	var n := maxi(4, int(p.distance_to(q) / 0.25)); var lava := 0
	for i in range(1, n):
		if lava_under(a, p.lerp(q, float(i) / n)): lava += 1
	return lava > 0 and lava * p.distance_to(q) / n <= JUMP_GAP

## whether the lava is under p (a step there is a fall into it)
static func lava_under(a: Caldera, p: Vector3) -> bool:
	return Phys.ground_at(p.x, p.y + 0.6, p.z, 0.3) < a.lava_y + 0.3

## in the trench, between the stones (where the gaps are jumped, not walked round)
static func in_trench(p: Vector3) -> bool:
	var r := Vector2(p.x, p.z).length()
	return r > float(TRENCH[0]) and r < float(TRENCH[1]) and p.y < Caldera.LOW_Y + 1.6

const LEAP := {"up": 7.6, "at": 0.5, "v_min": 2.5, "v_max": 7.5, "far": 5.8}   # one of the others' leap across a gap: how fast up, how near the edge he leaves it, how fast on (as fast as lands him on the waypoint)
## one of the others (or you, playing yourself), his feet at the edge of the lava and the waypoint he is making for across
## it: he leaps, as hard as sets him down on it (true)
static func leap(a: Caldera, rm, f) -> bool:
	if (f.me and not rm.auto) or not f.grounded or f.leaping: return false
	var b: Dictionary = f.brain; var path: Array = b.get("path", []); var pi := int(b.get("pi", 0))
	if pi >= path.size(): return false
	var to: Vector3 = path[pi]; var d := Vector2(to.x - f.pos.x, to.z - f.pos.z)
	if d.length() < 0.6 or d.length() > float(LEAP.far) or absf(to.y - f.pos.y) > 0.8: return false
	var dir := Vector3(d.x, 0, d.y).normalized()
	if not lava_under(a, f.pos + dir * float(LEAP.at)) or lava_under(a, to): return false
	var air := 2.0 * float(LEAP.up) / 19.0 + maxf(0.0, f.pos.y - to.y) * 0.08   # (the time in the air, a little more for a drop)
	f.leaping = true; f.brain["fling"] = true; f.vel = dir * clampf(d.length() / air, float(LEAP.v_min), float(LEAP.v_max)); f.vy = float(LEAP.up); f.pos.y += 0.05; f.grounded = false
	rm.note(["leap", f.id])
	return true

## whether a step toward `want` is on the way he is going (a gap ahead of him on it is to be leapt, not shied from)
static func on_way(a: Caldera, f, want: Vector2) -> bool:
	var b: Dictionary = f.brain; var path: Array = b.get("path", []); var pi := int(b.get("pi", 0))
	if pi >= path.size(): return false
	var to: Vector3 = path[pi]; var d := Vector2(to.x - f.pos.x, to.z - f.pos.z)
	if absf(to.y - f.pos.y) > 0.8: return false   # (a chain's top or foot: climbed or slid, never walked off toward)
	return d.length() > 0.1 and d.length() < JUMP_GAP + 3.4 and want.normalized().dot(d.normalized()) > 0.85 and not lava_under(a, to)

## one of the others on a chain, or setting out on one (its foot, the next waypoint its top; or the other way): moved
## up it or down it this frame (true: his feet are seen to)
static func carry(a: Caldera, rm, f, dt: float) -> bool:
	var b: Dictionary = f.brain
	if b.has("chain"):
		var c: Dictionary = a.chains[int(b.chain)]; var hold: Vector3 = c.at; var top: Vector3 = c.top
		var foot := Caldera.at_deg(float(c.deg), Caldera.RING_R0 - 1.4, Caldera.LOW_Y)
		f.vel = Vector3.ZERO; f.vy = 0.0; f.grounded = false
		f.pos.x = move_toward(f.pos.x, hold.x, 4.0 * dt); f.pos.z = move_toward(f.pos.z, hold.z, 4.0 * dt)
		if bool(b.chain_up):
			f.pos.y += CLIMB * dt
			if f.pos.y >= Caldera.MID_Y - 0.35: f.pos = top; f.grounded = true; b.erase("chain"); b.repath = 0.0
		else:
			f.pos.y -= SLIDE * dt
			var gy := Phys.ground_at(foot.x, Caldera.LOW_Y + 0.6, foot.z, 0.3)
			if f.pos.y <= gy + 0.05: f.pos = Vector3(foot.x, gy, foot.z); f.grounded = true; b.erase("chain"); b.repath = 0.0
		if fmod(rm.clock, 0.4) < dt: Snd.play("rd_chain", 0.5, f.pos)
		return true
	var path: Array = b.get("path", []); var pi := int(b.get("pi", 0))
	if pi >= path.size() or not f.grounded or a.tide >= 1.0: return false   # (the chains climbed while the lava rises: the way out)
	var nxt: Vector3 = path[pi]
	for i in a.chains.size():
		var c: Dictionary = a.chains[i]; var hold: Vector3 = c.at; var top: Vector3 = c.top
		if f.pos.y < Caldera.LOW_Y + 1.0 and _xz(f.pos, hold) < 1.7 and nxt.y > Caldera.MID_Y - 1.0 and _xz(nxt, top) < 2.0:
			b.chain = i; b.chain_up = true; rm.note(["chain", f.id, i, "up"]); return true
		if not a.tide_on and f.pos.y > Caldera.MID_Y - 0.5 and _xz(f.pos, top) < 1.3 and nxt.y < Caldera.LOW_Y + 1.0 and _xz(nxt, hold) < 2.6:
			b.chain = i; b.chain_up = false; rm.note(["chain", f.id, i, "down"]); return true
	return false

static func _xz(p: Vector3, q: Vector3) -> float: return Vector2(p.x - q.x, p.z - q.z).length()

## where one of the others in the trench goes when the lava is rising: the nearest way up (a stair's top, a chain's top)
static func escape(a: Caldera, f) -> Dictionary:
	if not a.tide_on or a.tide >= 1.0 or f.pos.y > Caldera.LOW_Y + 1.6: return {}
	var best = null; var bd := INF
	for s: float in [1.0, -1.0]:
		var x := -9.0 * s; var p := Vector3(x, Caldera.MID_Y, sqrt(Caldera.RING_R0 * Caldera.RING_R0 - x * x) * s + 1.0 * s)
		if _xz(f.pos, p) < bd: bd = _xz(f.pos, p); best = p
	for c: Dictionary in a.chains:
		if _xz(f.pos, c.top) + 3.0 < bd: bd = _xz(f.pos, c.top) + 3.0; best = c.top
	return {"at": best, "near": 1.2, "hurry": true, "y": true} if best != null else {}

# ---------------- what the place does ----------------
## the realm's frame: the lava, the gates, the troughs, the briars, the cacti; your climbing
static func turn(a: Caldera, rm, dt: float) -> void:
	if key_of(a) != a.graph_state:   # the lava rising, risen or down again, the seals up or gone: the others' ways laid out anew
		a.graph_state = key_of(a); rm.ai.build_graph()
		for f in rm.all: rm.astray(f)
	for f in rm.all:
		if not f.alive: continue
		var p: Vector3 = f.pos
		if p.y < a.lava_y - LAVA_GRACE and not f.brain.has("chain"): _lava(a, rm, f); continue
		if not a.tide_on and f.port_t <= 0.0 and rm.mode.fighting():
			for side: String in Caldera.GATES:
				var g: Vector3 = Caldera.GATES[side]
				if _xz(p, g) < 1.1 and absf(p.y - g.y) < 1.2: _gate(a, rm, f, side); break
		for q: Vector3 in a.troughs:
			if f.burn_t > 0.0 and _xz(p, q) < 1.7 and absf(p.y - q.y) < 1.0:
				f.burn_t = 0.0; f.burn = 0.0; f.burn_by = null
				if f.me:
					Snd.play("rm_frost", 0.5)
					if rm.game != null: rm.game.say_feed("냉각 수조 · 화상이 꺼졌습니다")
		if a.in_briar(p):
			rm.slow(f, "briar", float(Caldera.BRIAR.slow), 0.3)
			rm.hurt(f, float(Caldera.BRIAR.dps) * dt, "fire", null, {"dot": true, "src": "briar"})
		if f.race == "demon" and a.by_briar(p): rm.heal(f, float(Caldera.BRIAR.heal) * dt, f)
		var fast: bool = f.push.length() > 3.0 or (f.me and rm.player != null and Vector2(rm.player.vel.x, rm.player.vel.z).length() > 7.5) or f.dash_t > 0.0
		if fast:
			for c: Dictionary in a.cacti:
				if float(c.t) <= 0.0 and _xz(p, c.at) < 0.9 and absf(p.y - (c.at as Vector3).y) < 1.5: a.shatter(c, _shover(rm, f))
	if rm.me != null and rm.me.alive and rm.player != null: _you(a, rm, dt)

## the lava: whoever is in it is gone (in developer mode's invincibility, you are set back at your base instead)
static func _lava(a: Caldera, rm, f) -> void:
	if f.me and Store.settings.dev and Store.settings.god:
		var q: Vector3 = rm.mode.spawn_at(f); f.pos = q
		if rm.player != null: rm.player.pos = q; rm.player.vel = Vector3.ZERO
		return
	f.inv = 0.0; f.phased_t = 0.0
	rm.slay(f, _shover(rm, f), {"src": "lava"})
	Snd.play("rd_lava", 1.0, f.feet_mid())
	if rm.look != null: rm.look.burst(f.pos + Vector3(0, 0.5, 0), 1.6, "fire")
	if rm.game != null: rm.game.say_feed(("당신이" if f.me else Races.josa(str(f.name), "이가")) + " 용암에 떨어졌습니다")
	rm.note(["lava", f.id, f.pos, a.lava_y, f.brain.has("chain")])

## who shoved him lately (the lava's or a cactus's due goes to the one who sent him into it): his last hurt of the other
## side, within the last two seconds
static func _shover(rm, f):
	var best = null; var bt := -INF
	for id in f.hits:
		var h = rm.by_id(int(id))
		if h != null and h.team != f.team and float(f.hits[id]) > bt and rm.clock - float(f.hits[id]) <= 2.0: bt = float(f.hits[id]); best = h
	return best

## a blood-pact gate: 35 of his health given (refused with less), and he stands on the gallery over it
static func _gate(a: Caldera, rm, f, side: String) -> void:
	var god: bool = f.me and Store.settings.dev and Store.settings.god
	if f.hp <= Caldera.GATE_COST + 0.5 and not god:
		f.port_t = 1.0
		if f.me: a._tell("gate_low", "혈약의 차원문은 체력 35를 받아야 열립니다")
		return
	if not god: f.hp -= Caldera.GATE_COST
	var to: Vector3 = Caldera.GATE_TO[side] + Vector3(randf_range(-1.2, 1.2), 0.05, 0.0)
	var from: Vector3 = f.pos
	f.pos = to; f.vel = Vector3.ZERO; f.vy = 0.0; f.port_t = GATE_CD; f.fired_t = 0.0
	if f.me and rm.player != null: rm.player.pos = to; rm.player.vel = Vector3.ZERO; rm.player.shake = maxf(rm.player.shake, 0.2)
	rm.astray(f)
	Snd.play("elf_portal", 1.0, to)
	if rm.look != null: rm.look.ported(f, from, to)
	if f.me and rm.game != null: rm.game.say_hint("혈약의 차원문 · 체력 35를 바치고 감시 회랑으로", 2.4)
	rm.note(["gate", f.id, side])

## your feet: a soul chain climbed while you hold jump by it (nothing fires meanwhile but the dagger)
static func _you(a: Caldera, rm, dt: float) -> void:
	var p = rm.player; var feet: Vector3 = p.pos
	a.climb_on = false
	if a.tide >= 1.0: return
	for c: Dictionary in a.chains:
		var at: Vector3 = c.at; var top: Vector3 = c.top
		if _xz(feet, at) > 0.95 or feet.y < Caldera.LOW_Y - 0.4 or feet.y > Caldera.MID_Y + 0.3: continue
		a._tell("chain", "영혼 포집 쇠사슬 · 곁에서 점프를 누르고 있으면 타고 오릅니다 (오르는 동안은 룬 단검만)")
		if not p.in_up: continue
		a.climb_on = true; p.vel = Vector3(0.0, CLIMB, 0.0); p.grounded = false
		if fmod(rm.clock, 0.4) < dt: Snd.play("rd_chain", 0.6)
		if feet.y > Caldera.MID_Y - 0.35: p.pos = Vector3(top.x, Caldera.MID_Y + 0.05, top.z); p.vel = Vector3.ZERO; p.grounded = true
