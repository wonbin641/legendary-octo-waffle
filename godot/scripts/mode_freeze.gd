class_name ModeFreeze
extends ToyMode
## 취침 시간 술래잡기 (주인님의 발소리): a team deathmatch with the room's owner in it. Every minute or so there are
## heavy footsteps in the hall, the doorknob turns and an alarm goes: three seconds later the door in the south wall
## swings open and a giant shadow leans in and looks the room over for five to seven seconds. Every toy must keep stock
## still, playing a toy. Whoever moves or shoots while it looks is picked up by a giant hand and dropped in a toy box
## (out of the fight for a long while; a point to the other side). Push someone, or burst a fizzy soda can under them, as the
## footsteps come, and they are still sliding when the door opens. First side to 30 points (a point a toy shot or boxed).

const TARGET := 30
const TIME := 420.0
const FIRST_VISIT := 38.0
const EVERY := [50.0, 70.0]
const WARN := 3.0
const OPEN := 1.0
const LOOK := [5.0, 7.0]
const CLOSE := 1.0
const GRACE := 0.5            # the first moment of the look nobody is caught (it is still turning its head to the room)
const MOVE_TOL := 0.35        # metres you may drift while it looks
const BOX_BACK := 15.0        # a toy in the box is back in the fight after this long; you after BOX_BACK_YOU
const BOX_BACK_YOU := 12.0
const CANS := 3               # soda cans each life
const PUDDLE_R := 4.0
const PUDDLE_T := 7.0
const BINS := [Vector3(-47, 4.4, 52), Vector3(47, 4.4, 52)]
const GIANT_Y := 6.0          # the owner crouches out in the hall (hips this high), this far back, and comes this much nearer as it leans in
const GIANT_FAR := 40.0
const GIANT_IN := 12.0
const GIANT_LEAN := 0.7
const SPAWN_US := [Vector3(-30, 0, 44), Vector3(-24, 0, 48), Vector3(-34, 0, 52), Vector3(-20, 0, 56), Vector3(-28, 0, 58), Vector3(-36, 0, 40)]
const SPAWN_THEM := [Vector3(28, 0, -40), Vector3(34, 0, -44), Vector3(22, 0, -46), Vector3(38, 0, -38), Vector3(30, 0, -48), Vector3(24, 0, -36)]
const HOT := [Vector3(-6, 0, 10), Vector3(-6, 0, -10), Vector3(-14, 9, 1.0), Vector3(13, 6, 6), Vector3(13, 6, -10), Vector3(-33, 9, 6), Vector3(-10, 0, 30),
	Vector3(20, 0, 40), Vector3(-30, 0, -40), Vector3(20, 0, -40), Vector3(-34, 0, 40), Vector3(0, 0, 46), Vector3(14, 0, 0), Vector3(-33, 9, -8)]
const SQUAD := [["soldier", "trooper"], ["soldier", "trooper"], ["soldier", "trooper"], ["soldier", "trooper"], ["soldier", "trooper"], ["soldier", "trooper"], ["soldier", "trooper"], ["figure", "smg"], ["figure", "shotgun"], ["brick", "brick"], ["brick", "brick"]]

var room: ToyRoom
var phase := "calm"           # calm, warn (footsteps), open (the door swings), look, close
var phase_t := 0.0
var next_t := FIRST_VISIT
var look_len := 6.0
var visit_t := 0.0            # seconds since the footsteps began (who has noticed by now)
var visits := 0
var door: Node3D = null; var knob: Node3D = null
var giant: Node3D = null; var head: Node3D = null; var eyes: Array = []
var hand: Node3D = null; var fingers: Array = []
var hall_light: OmniLight3D = null; var spill: SpotLight3D = null
var caught: Array = []        # waiting for the hand: {who, at}
var grab = null               # the one in the hand now: {who, t, from, bin, kind, nodes}
var ref := {}                 # where each was when the look began: who -> Vector3
var ref_shots := 0
var cans := CANS
var flying: Array = []        # soda cans in the air: {node, pos, vel, team}
var puddles: Array = []       # {pos, t, node}
var boxed := {"us": 0, "them": 0}
var _step_t := 0.0
var _steps := 0

func _init() -> void:
	time_left = TIME; lose_title = "상대 팀이 먼저 %d점을 냈습니다" % TARGET

func skips(what: String) -> bool: return what == "south_wall"

func keep_off(x: float, z: float, _y: float) -> bool:
	for L in [SPAWN_US, SPAWN_THEM]:
		for p: Vector3 in L:
			if Vector2(x - p.x, z - p.z).length() < 4.0: return true
	return z > 60.0 and absf(x) < 16.0   # in front of the door

func start() -> Dictionary: return {"x": -28.0, "z": 50.0, "yaw": ToyMatch.face_in(Vector3(-28, 0, 50))}

# ---------------- the room's door, the hall behind it, the owner ----------------
func build_room(r: ToyRoom) -> void:
	room = r; var H := ToyRoom.HALF
	# the south wall with the door in it: 24 m wide, 40 m high, in the middle
	r.box(-H, 0, H, -12.0, 46.0, H + 1.0, "cfe3ea"); r.box(12.0, 0, H, H, 46.0, H + 1.0, "cfe3ea"); r.box(-12.0, 40.0, H, 12.0, 46.0, H + 1.0, "cfe3ea")
	r.box(-H, 0, H - 0.3, -12.0, 2.2, H, "f4f1e8", "concrete", false); r.box(12.0, 0, H - 0.3, H, 2.2, H, "f4f1e8", "concrete", false)
	r.box(-13.2, 0, H - 0.4, -12.0, 41.2, H, "e9dcc6", "concrete", false); r.box(12.0, 0, H - 0.4, 13.2, 41.2, H, "e9dcc6", "concrete", false); r.box(-13.2, 40.0, H - 0.4, 13.2, 41.2, H, "e9dcc6", "concrete", false)   # the frame
	Phys.add_collider(-12.0, 0.0, H, 12.0, 40.0, H + 0.8, "wood")   # (the doorway stops bullets, open or shut)
	# the hall outside: a floor, walls, a warm light that comes on with the door
	for q in [[-34.0, -0.4, H + 1.0, 34.0, 0.0, H + 50.0, "8d6e4b"], [-34.0, 0.0, H + 50.0, 34.0, 70.0, H + 51.0, "e8d9b8"], [-35.0, 0.0, H + 1.0, -34.0, 70.0, H + 51.0, "e2d2b0"], [34.0, 0.0, H + 1.0, 35.0, 70.0, H + 51.0, "e2d2b0"]]:
		r.box(q[0], q[1], q[2], q[3], q[4], q[5], q[6], "concrete", false)
	hall_light = OmniLight3D.new(); hall_light.light_color = Color("ffd9a0"); hall_light.omni_range = 80.0; hall_light.light_energy = 0.0; hall_light.position = Vector3(0, 40, H + 34.0); r.G.add_child(hall_light)
	spill = SpotLight3D.new(); spill.light_color = Color("ffe2b0"); spill.spot_range = 120.0; spill.spot_angle = 38.0; spill.light_energy = 0.0; spill.position = Vector3(0, 34, H + 6.0); r.G.add_child(spill); spill.look_at(Vector3(0, 0, 0), Vector3.UP)
	# the door: hinged on its west side, it swings out into the hall; its brass knob turns before it opens
	door = Node3D.new(); door.position = Vector3(-12.0, 0.0, H + 0.4); r.G.add_child(door)
	var dm := MeshInstance3D.new(); dm.mesh = Gfx.merge_boxes([[24.0, 40.0, 0.8, 12.0, 20.0, 0.0, "f1e3c8"], [9.0, 14.0, 0.3, 6.4, 29.0, -0.45, "e6d3b0"], [9.0, 14.0, 0.3, 17.6, 29.0, -0.45, "e6d3b0"],
		[9.0, 14.0, 0.3, 6.4, 10.0, -0.45, "e6d3b0"], [9.0, 14.0, 0.3, 17.6, 10.0, -0.45, "e6d3b0"], [1.0, 40.0, 0.9, 23.5, 20.0, 0.0, "e0cfae"]], true)
	var dmat := StandardMaterial3D.new(); dmat.vertex_color_use_as_albedo = true; dmat.roughness = 0.7; dm.material_override = dmat; door.add_child(dm)
	knob = Node3D.new(); knob.position = Vector3(21.0, 17.0, -0.7); door.add_child(knob)
	var rose := MeshInstance3D.new(); var rc := CylinderMesh.new(); rc.top_radius = 1.0; rc.bottom_radius = 1.0; rc.height = 0.3; rose.mesh = rc; rose.rotation.x = PI / 2; rose.material_override = Gfx.std(Color("d4a72c"), 0.35, 0.3); knob.add_child(rose)
	var kb := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 1.25; ks.height = 2.5; kb.mesh = ks; kb.position = Vector3(0.6, 0, -1.1); kb.material_override = rose.material_override; knob.add_child(kb)
	var bar := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.3, 0.3, 1.2); bar.mesh = bb; bar.position = Vector3(0, 0, -0.6); bar.material_override = rose.material_override; knob.add_child(bar)
	_build_giant(); _build_hand()

## the owner: a dark shape out in the hall, too big for the door; it leans down and looks in, its eyes catching the light
func _build_giant() -> void:
	var H := ToyRoom.HALF
	giant = Node3D.new(); giant.position = Vector3(0, GIANT_Y, H + GIANT_FAR); room.G.add_child(giant)
	var dark := Gfx.std(Color("262b38"), 1.0)
	var body := MeshInstance3D.new(); body.mesh = Gfx.merge_boxes([[24.0, 24.0, 11.0, 0, 12.0, 0, "262b38"], [7.0, 22.0, 7.0, -6.0, -9.0, 0, "1f2330"], [7.0, 22.0, 7.0, 6.0, -9.0, 0, "1f2330"], [6.0, 22.0, 6.0, -15.0, 8.0, 0, "262b38"], [6.0, 22.0, 6.0, 15.0, 8.0, 0, "262b38"]], true)
	var bm := StandardMaterial3D.new(); bm.vertex_color_use_as_albedo = true; bm.roughness = 1.0; body.material_override = bm; giant.add_child(body)
	head = Node3D.new(); head.position = Vector3(0, 31.0, 0); giant.add_child(head)
	var hm := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 7.0; hs.height = 14.0; hm.mesh = hs; hm.material_override = dark; head.add_child(hm)
	var hair := MeshInstance3D.new(); var hh := SphereMesh.new(); hh.radius = 7.4; hh.height = 9.0; hh.is_hemisphere = true; hair.mesh = hh; hair.position.y = 0.6; hair.material_override = Gfx.std(Color("15171f"), 1.0); head.add_child(hair)
	var ew := StandardMaterial3D.new(); ew.albedo_color = Color("e8e6dc"); ew.emission_enabled = true; ew.emission = Color("fff6d8"); ew.emission_energy_multiplier = 0.0; ew.roughness = 0.3
	for ex in [-2.4, 2.4]:
		var e := MeshInstance3D.new(); var es := SphereMesh.new(); es.radius = 1.1; es.height = 2.2; e.mesh = es; e.material_override = ew; e.position = Vector3(ex, 0.8, -6.3); head.add_child(e)
		var pu := MeshInstance3D.new(); var ps := SphereMesh.new(); ps.radius = 0.5; ps.height = 1.0; pu.mesh = ps; pu.material_override = Gfx.std(Color("0d0f14"), 0.5); pu.position = Vector3(0, 0, -0.85); e.add_child(pu)
		eyes.push_back(e)
	giant.set_meta("eye_mat", ew)

## the hand that comes down out of the sky for a toy that moved
func _build_hand() -> void:
	hand = Node3D.new(); hand.visible = false; room.G.add_child(hand)
	var skin := Gfx.std(Color("f1c27d"), 0.75)
	var palm := MeshInstance3D.new(); palm.mesh = Gfx.merge_boxes([[8.0, 2.4, 8.5, 0, 0, 0, "f1c27d"], [6.0, 60.0, 6.0, 0, 31.0, 1.0, "f1c27d"], [6.6, 3.0, 6.6, 0, 3.0, 1.0, "9ec5ff"]], true)
	var pm := StandardMaterial3D.new(); pm.vertex_color_use_as_albedo = true; pm.roughness = 0.75; palm.material_override = pm; hand.add_child(palm)
	for i in 4:
		var f := Node3D.new(); f.position = Vector3(-2.7 + i * 1.8, -0.4, -4.1); hand.add_child(f)
		var fm := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = Vector3(1.6, 1.6, 6.0 + (1.0 if i in [1, 2] else 0.0)); fm.mesh = fb; fm.position = Vector3(0, 0, -fb.size.z / 2.0); fm.material_override = skin; f.add_child(fm)
		fingers.push_back(f)
	var th := Node3D.new(); th.position = Vector3(4.2, -0.4, 0.5); hand.add_child(th)
	var tm_ := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(5.0, 1.8, 1.9); tm_.mesh = tb; tm_.position = Vector3(2.0, 0, -1.0); tm_.rotation.y = 0.5; tm_.material_override = skin; th.add_child(tm_)
	fingers.push_back(th)

# ---------------- the two sides ----------------
func populate() -> void:
	for i in 5: m.add_unit("us", "soldier", SPAWN_US[i + 1], {"job": "push", "idx": i})
	for i in SQUAD.size(): m.add_unit("them", SQUAD[i][0], SPAWN_THEM[i % 6] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), {"gun": SQUAD[i][1], "job": "push", "idx": i, "tint": i % 4})

func on_respawn(u, _team: String) -> void:
	if u is Player:
		# back at your base, perhaps in the middle of a look: seen standing there now (not where you fell), and your shots counted
		# from now (the guns start over), so only a move or a shot after you are back gets you caught
		cans = CANS; ref[m.player] = m.player.pos; ref_shots = m.guns.shots; return
	u.k.hot = HOT[randi() % HOT.size()]; u.k.hot_t = randf_range(14.0, 24.0); u.k.freeze_at = 0.0; u.k.slip = Vector2.ZERO; u.k.slip_t = 0.0

func spawn_at(team: String, _who := "") -> Vector3:
	var L: Array = SPAWN_US if team == "us" else SPAWN_THEM
	for k in 8:
		var p: Vector3 = L[randi() % L.size()] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		if Phys.collide_at(p.x, 0.05, p.z, 0.5, 1.8) == null: return p
	return L[0]

func goal(u: Enemies.Foe) -> Dictionary:
	var k := u.k; k.hot_t = float(k.get("hot_t", 0.0)) - 0.35
	if float(k.hot_t) <= 0.0 or k.get("hot") == null: k.hot = HOT[randi() % HOT.size()]; k.hot_t = randf_range(14.0, 24.0)
	return {"at": k.hot, "near": 3.0}

## who must keep still: everyone who has heard the footsteps, until the door is shut again
func hold(u: Enemies.Foe) -> bool:
	if phase == "calm": return false
	return visit_t >= float(u.k.get("freeze_at", 0.0))

func on_shot(who) -> void:
	if phase == "look" and phase_t > GRACE and not _is_caught(who): _catch(who)

# ---------------- the turn ----------------
func update(dt: float) -> void:
	if time_left <= 0.0: return
	time_left = maxf(0.0, time_left - dt)
	if time_left <= 0.0: _time_up(); return
	_visit(dt)
	_grabs(dt)
	_cans(dt)
	_puddles(dt)
	if int(m.score.us) >= TARGET: time_left = 0.0; m.game.win_match()
	elif int(m.score.them) >= TARGET: time_left = 0.0; lose_stamp = "패배"; m.game.lose_match()

func _time_up() -> void:
	if int(m.score.us) > int(m.score.them): m.game.win_match()
	else:
		lose_stamp = "무승부" if int(m.score.us) == int(m.score.them) else "패배"
		lose_title = "시간 종료 · %d 대 %d" % [m.score.us, m.score.them]; m.game.lose_match()

func _visit(dt: float) -> void:
	phase_t += dt
	if phase != "calm": visit_t += dt
	match phase:
		"calm":
			next_t -= dt
			if next_t <= 0.0: _warn()
		"warn":
			_step_t -= dt
			if _step_t <= 0.0 and _steps < 4:
				_steps += 1; _step_t = 0.62; Snd.play("thump"); m.player.shake = maxf(m.player.shake, 0.12 + _steps * 0.04)
				if _steps == 4: Snd.play("quake")
			if phase_t > 1.9: knob.rotation.z = -minf(1.0, (phase_t - 1.9) / 0.5) * 0.9
			if phase_t >= WARN: phase = "open"; phase_t = 0.0; Snd.play("toy_slide"); Snd.play("press")
		"open":
			var f := clampf(phase_t / OPEN, 0.0, 1.0); var e := f * f * (3.0 - 2.0 * f)
			door.rotation.y = -e * 1.75; hall_light.light_energy = e * 3.0; spill.light_energy = e * 2.5
			giant.position.z = ToyRoom.HALF + GIANT_FAR - e * GIANT_IN; giant.rotation.x = -e * GIANT_LEAN
			(giant.get_meta("eye_mat") as StandardMaterial3D).emission_energy_multiplier = e * 1.6
			if phase_t >= OPEN: phase = "look"; phase_t = 0.0; _start_look()
		"look":
			head.rotation.y = sin(phase_t * 0.9) * 0.5; head.rotation.x = 0.25 + sin(phase_t * 0.55) * 0.12
			for e2: Node3D in eyes: e2.get_child(0).position = Vector3(sin(phase_t * 0.9) * 0.3, 0, -0.85)
			if phase_t > GRACE: _watch()
			if phase_t >= look_len and grab == null and caught.is_empty(): phase = "close"; phase_t = 0.0; Snd.play("toy_slide")
		"close":
			var f := 1.0 - clampf(phase_t / CLOSE, 0.0, 1.0); var e := f * f * (3.0 - 2.0 * f)
			door.rotation.y = -e * 1.75; hall_light.light_energy = e * 3.0; spill.light_energy = e * 2.5
			giant.position.z = ToyRoom.HALF + GIANT_FAR - e * GIANT_IN; giant.rotation.x = -e * GIANT_LEAN; knob.rotation.z = 0.0
			(giant.get_meta("eye_mat") as StandardMaterial3D).emission_energy_multiplier = e * 1.6
			if phase_t >= CLOSE:
				phase = "calm"; phase_t = 0.0; next_t = randf_range(EVERY[0], EVERY[1]); visit_t = 0.0; room.train_hold = false
				Snd.play("thud"); m.game.say_feed("문이 닫혔습니다 · 다시 싸우세요")

func _warn() -> void:
	phase = "warn"; phase_t = 0.0; visit_t = 0.0; _steps = 0; _step_t = 0.0; visits += 1; look_len = randf_range(LOOK[0], LOOK[1])
	Snd.play("alarm"); m.game.say_banner("발소리!", "방 주인이 옵니다 · 문이 열리면 절대 움직이지 마세요", 2.6)
	for u in m.units("us") + m.units("them"):   # most stop in time; now and then one is slow to notice
		u.k.freeze_at = randf_range(0.4, 2.8) if randf() < 0.88 else randf_range(WARN + OPEN + GRACE + 0.2, WARN + OPEN + 2.5)
	# a soda can or two, thrown just before the door opens, at someone who will still be sliding when it does
	for team in ["us", "them"]:
		if randf() < 0.55:
			var mine: Array = m.units(team)
			if not mine.is_empty(): var u = mine[randi() % mine.size()]; u.k.can_at = randf_range(0.6, 2.0)

func _start_look() -> void:
	room.train_hold = true; ref.clear(); ref_shots = m.guns.shots
	ref[m.player] = m.player.pos
	for u in m.units("us") + m.units("them"): ref[u] = u.pos
	Snd.play("quake")

## anyone who has moved since the look began, or fires: caught
func _watch() -> void:
	if m.player_in() and not _is_caught(m.player):
		var p0: Vector3 = ref.get(m.player, m.player.pos); var p: Vector3 = m.player.pos
		if Vector2(p.x - p0.x, p.z - p0.z).length() > MOVE_TOL or absf(p.y - p0.y) > 0.6 or m.guns.shots > ref_shots or m.guns.melee_on: _catch(m.player)
	for u in m.units("us") + m.units("them"):
		if _is_caught(u): continue
		if not ref.has(u): ref[u] = u.pos; continue
		var p0: Vector3 = ref[u]
		if Vector2(u.pos.x - p0.x, u.pos.z - p0.z).length() > MOVE_TOL + 0.1 or absf(u.pos.y - p0.y) > 0.6: _catch(u)

func _is_caught(who) -> bool:
	if grab != null and grab.who == who: return true
	for c in caught:
		if c.who == who: return true
	return false

func _catch(who) -> void:
	caught.push_back({"who": who})
	if who is Player: m.game.say_banner("들켰습니다!", "방 주인이 당신을 집어 듭니다", 1.8)
	else:
		var nm := str(who.T.name)
		m.game.say_feed(("아군 병정이" if who.k.team == "us" else "상대 " + nm + ("이" if Animals.batchim(nm) else "가")) + " 움직이다 들켰습니다")

## the hand: down over the one that moved, the fingers close, up, across to a toy box, and in it goes
func _grabs(dt: float) -> void:
	if grab == null:
		if caught.is_empty(): return
		var c: Dictionary = caught.pop_front(); var who = c.who
		if not m.alive(who): return
		var at: Vector3 = m.feet(who); var bin: Vector3 = BINS[0] if at.x < 0.0 else BINS[1]
		grab = {"who": who, "t": 0.0, "at": at, "bin": bin, "held": false}
		hand.visible = true; hand.position = at + Vector3(0, 60, 0); hand.rotation = Vector3.ZERO
		for f: Node3D in fingers: f.rotation = Vector3.ZERO
		Snd.play("swoosh")
		if who is Player: m.player_down("box", BOX_BACK_YOU + 4.0); m.player.held = true
		else: _take(who)
		return
	grab.t = float(grab.t) + dt; var t: float = grab.t; var at: Vector3 = grab.at; var bin: Vector3 = grab.bin
	var p := at + Vector3(0, 3.2, 0)
	if t < 0.9: var f := t / 0.9; hand.position = (at + Vector3(0, 60, 0)).lerp(p, f * f * (3.0 - 2.0 * f))
	elif t < 1.25:
		hand.position = p
		for f2: Node3D in fingers: f2.rotation.x = minf(1.0, (t - 0.9) / 0.35) * (-1.0 if f2 == fingers[4] else 1.3)
		if not bool(grab.held): grab.held = true; Snd.play("toy_click", 1.0, at); Snd.play("thud", 1.0, at)
	elif t < 2.2: var f := (t - 1.25) / 0.95; hand.position = p.lerp(Vector3(at.x, 46.0, at.z), f * f * (3.0 - 2.0 * f))
	elif t < 3.0: var f := (t - 2.2) / 0.8; hand.position = Vector3(at.x, 46.0, at.z).lerp(Vector3(bin.x, 24.0, bin.z), f * f * (3.0 - 2.0 * f))
	elif t < 3.3:
		hand.position = Vector3(bin.x, 24.0, bin.z)
		for f2: Node3D in fingers: f2.rotation.x = 0.0
	else:
		_drop_in(grab); hand.position.y += dt * 40.0
		if t > 3.8: hand.visible = false; grab = null
		return
	# what it holds goes with it
	var held_at: Vector3 = hand.position - Vector3(0, 3.4, 0)
	if bool(grab.held) or t >= 0.9:
		var who = grab.who
		if who is Player: m.player.pos = held_at; m.player.vel = Vector3.ZERO
		elif grab.has("nodes"):
			for n: Node3D in grab.nodes: n.position = held_at

## a toy of either side taken out of the fight: off its side's list, its picture carried by the hand
func _take(u: Enemies.Foe) -> void:
	u.k.gone = true; u.alive = false; u.bar.visible = false
	if u.k.team == "us": m.allies.erase(u)
	else: m.en.list.erase(u)
	grab.nodes = [u.g]; grab.unit = u
	Snd.play("toy_click", 1.0, u.pos)

func _drop_in(g: Dictionary) -> void:
	if bool(g.get("dropped", false)): return
	g.dropped = true
	var who = g.who; var bin: Vector3 = g.bin
	Snd.play("thud", 1.0, bin); if m.fx: m.fx.puff(bin + Vector3(0, 1.0, 0), 5, 0.6, 0.6)
	if who is Player:
		m.player.held = false; m.player.pos = bin + Vector3(randf_range(-2.0, 2.0), 0.05, randf_range(-2.0, 2.0)); boxed.us += 1
		m.score.them = int(m.score.them) + 1
		m.game.say_banner("장난감 상자 안", "%d초 뒤 기지에서 다시 출동합니다" % ceili(m.down_t), 2.0)
		return
	var u: Enemies.Foe = g.unit; var team: String = u.k.team
	if is_instance_valid(u.g): u.g.queue_free()
	if is_instance_valid(u.bar): u.bar.queue_free()
	boxed[team] = int(boxed[team]) + 1
	if team == "us": m.score.them = int(m.score.them) + 1
	else: m.score.us = int(m.score.us) + 1
	m.queue.push_back({"team": team, "type": str(u.k.type0), "opts": u.k.spawn_opts, "t": BOX_BACK})
	m.game.say_feed(("아군이 장난감 상자에 갇혔습니다 · 상대 +1" if team == "us" else "상대가 장난감 상자에 갇혔습니다 · 아군 +1"))

# ---------------- soda cans ----------------
## G (or the touch button): a fizzy soda can thrown ahead of you; it bursts where it lands and the floor there gets slippery
func throw_can() -> bool:
	if cans <= 0 or not m.player_in(): return false
	cans -= 1
	var cam: Camera3D = m.guns.cam; var f: Vector3 = -cam.global_basis.z
	_can(cam.global_position + f * 0.6, f * 17.0 + Vector3(0, 5.0, 0), "us")
	if phase == "look" and phase_t > GRACE: _catch(m.player)   # (throwing is moving)
	return true

func _can(from: Vector3, vel: Vector3, team: String) -> void:
	var n := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.22; c.bottom_radius = 0.22; c.height = 0.6; n.mesh = c; n.material_override = Gfx.std(Color("e63946"), 0.3, 0.6); n.position = from; room.G.add_child(n)
	flying.push_back({"node": n, "pos": from, "vel": vel, "team": team}); Snd.play("swing", 1.0, from)

func _cans(dt: float) -> void:
	# an AI that was told to throw one this visit does, at the nearest enemy it can see
	for u in m.units("us") + m.units("them"):
		if not u.k.has("can_at"): continue
		if visit_t < float(u.k.can_at) or phase == "calm": continue
		u.k.erase("can_at")
		var tg = m._target(u)
		if tg == null: continue
		var to: Vector3 = m.feet(tg); var from: Vector3 = u.pos + Vector3(0, 1.6, 0); var dd := Vector2(to.x - from.x, to.z - from.z)
		if dd.length() > 26.0: continue
		var tt := clampf(dd.length() / 14.0, 0.5, 1.8)
		_can(from, Vector3(dd.x / tt, (to.y - from.y + 0.5 * 15.0 * tt * tt) / tt, dd.y / tt), u.k.team)
	for i in range(flying.size() - 1, -1, -1):
		var q: Dictionary = flying[i]; q.vel.y -= 15.0 * dt; var np: Vector3 = q.pos + q.vel * dt
		var hit: bool = np.y <= Phys.ground_at(np.x, q.pos.y, np.z, 0.1) + 0.05 or Phys.collide_at(np.x, np.y, np.z, 0.15, 0.3) != null
		q.pos = np; (q.node as Node3D).position = np; (q.node as Node3D).rotation.x += dt * 12.0
		if hit or np.y < -2.0:
			(q.node as Node3D).queue_free(); flying.remove_at(i)
			var gy := Phys.ground_at(np.x, np.y + 1.0, np.z, 0.3); _burst(Vector3(np.x, gy, np.z))

func _burst(at: Vector3) -> void:
	Snd.play("toy_glug", 1.0, at); Snd.play("hiss", 1.0, at); Music.blast(at)   # (a can bursting by you: the music's tape stretches)
	if m.fx: m.fx.puff(at + Vector3(0, 0.4, 0), 10, 0.95, 0.9); m.fx.sparks(at + Vector3(0, 0.3, 0), 12, [0.85, 0.6, 0.3], 3.0)
	var n := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = PUDDLE_R; c.bottom_radius = PUDDLE_R; c.height = 0.04; n.mesh = c
	var fl := ToyBreak.flavour(at)   # cola or grape: the syrup's colour, on the floor and on whoever is in it
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.55, 0.3, 0.12, 0.6) if fl == "cola" else Color(0.46, 0.22, 0.6, 0.6); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.roughness = 0.05; mat.metallic = 0.2
	n.material_override = Gfx.see_through(mat); n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; n.position = at + Vector3(0, 0.05, 0); room.G.add_child(n)
	puddles.push_back({"pos": at, "t": PUDDLE_T, "node": n, "fl": fl})
	m.toys.brk.soda(at, PUDDLE_R, m.units("us") + m.units("them"))

## the sticky, slippery floor: whoever is in it slides about, whether or not it means to
func _puddles(dt: float) -> void:
	for u in m.units("us") + m.units("them"):
		u.k.slip_t = maxf(0.0, float(u.k.get("slip_t", 0.0)) - dt)
		if float(u.k.slip_t) <= 0.0: u.k.slip = (u.k.get("slip", Vector2.ZERO) as Vector2) * exp(-dt * 4.0)
	for i in range(puddles.size() - 1, -1, -1):
		var q: Dictionary = puddles[i]; q.t = float(q.t) - dt; var c: Vector3 = q.pos
		if m.fx and randf() < dt * 6.0: m.fx.puff(c + Vector3(randf_range(-3, 3), 0.15, randf_range(-3, 3)), 1, 0.9, 0.25)
		for u in m.units("us") + m.units("them"):
			if Vector2(u.pos.x - c.x, u.pos.z - c.z).length() < PUDDLE_R and absf(u.pos.y - c.y) < 1.2:
				if float(u.k.slip_t) <= 0.0: var a := randf() * TAU; u.k.slip = Vector2(cos(a), sin(a)) * 3.2
				u.k.slip_t = 0.7; m.toys.brk.goo(u, str(q.fl))   # (and the syrup is on it)
		if m.player_in() and Vector2(m.player.pos.x - c.x, m.player.pos.z - c.z).length() < PUDDLE_R and absf(m.player.pos.y - c.y) < 1.2:
			var a2 := fposmod(m.clock * 1.3 + c.x, TAU); m.player.vel.x += cos(a2) * 22.0 * dt; m.player.vel.z += sin(a2) * 22.0 * dt
			m.toys.brk.goo_feet(m.player.pos, str(q.fl), dt)
		if float(q.t) <= 0.0: (q.node as Node3D).queue_free(); puddles.remove_at(i)

func player_carrying() -> bool: return false

## the hand's catch, if a stage ends while it holds one
func cleanup() -> void:
	if grab != null and grab.has("nodes"):
		for n in grab.nodes:
			if is_instance_valid(n): (n as Node3D).queue_free()
		var u = grab.get("unit")
		if u != null and is_instance_valid(u.bar): u.bar.queue_free()
	grab = null

# ---------------- what you see ----------------
func hud_cells() -> Array:
	var cs := ceili(time_left)
	return [["스테이지", "5", Color("f2a33a")], ["남은 시간", "%d:%02d" % [cs / 60, cs % 60], Color("ece6d8")], ["아군", str(m.score.us), Color("5f9cff")], ["상대", str(m.score.them), Color("ff5260")],
		["목표", str(TARGET), Color("ece6d8")], ["가방", Store.won(Store.save.money), Color("ece6d8")]]

func hud_bar() -> Array: return [float(m.score.us) / TARGET, Color("5f9cff")]

func hud_lines() -> Array:
	match phase:
		"warn": return [["발소리!", "곧 문이 열립니다 · 멈출 준비", "%.1f초" % maxf(0.0, WARN + OPEN - phase_t), true]]
		"open": return [["방 주인", "문이 열립니다 · 멈추세요", "", true]]
		"look": return [["방 주인", "움직이거나 쏘면 잡혀갑니다", "%.1f초" % maxf(0.0, look_len - phase_t), true]]
		"close": return [["방 주인", "문이 닫힙니다", "", false]]
	return [["방", "조용합니다 · 탄산 캔 %d개 (G)" % cans, "", false]]

func status() -> String:
	if m.player.out and m.player.held: return "방 주인 손에 잡혔습니다"
	if phase == "look" or phase == "open": return "움직이지 마세요!"
	return ""

func tac(ci, X: Callable, Z: Callable, k: float, u: float) -> void:
	var H := ToyRoom.HALF
	ci.draw_rect(Rect2(X.call(-12.0), Z.call(H) - 3.0 * u, 24.0 * k, 6.0 * u), Color("c98b5a") if phase == "calm" else Color("ffd23a"))
	for b: Vector3 in BINS: ci.draw_rect(Rect2(X.call(b.x - 5.0), Z.call(b.z - 6.0), 10.0 * k, 12.0 * k), Color(0.95, 0.85, 0.3, 0.35), false, 1.6 * u)
	for p in puddles: ci.draw_circle(Vector2(X.call(p.pos.x), Z.call(p.pos.z)), PUDDLE_R * k, Color(0.6, 0.35, 0.15, 0.45) if str(p.get("fl", "cola")) == "cola" else Color(0.5, 0.25, 0.65, 0.45))

func legend() -> Array:
	return [["ally", "5f9cff", "아군 병정"], ["soldier", "7fc96b", "플라스틱 군인"], ["figure", "ff7a3a", "액션 피규어"], ["brick", "ffd23a", "조립 블록 피규어"], ["door", "c98b5a", "방문 · 장난감 상자"]]

func brief() -> String:
	return "방문 손잡이가 돌아가면 절대 움직이지 마! · 팀 데스매치 + 방 주인 기믹\n먼저 %d점(처치 1점, 상대를 장난감 상자에 보내면 1점)을 내는 쪽이 이깁니다\n1분쯤마다 복도에서 발소리와 문고리 소리, 경고음이 납니다 · 3초 뒤 남쪽 방문이 열리고 거대한 그림자가 5~7초 동안 방을 살핍니다\n그동안 움직이거나 쏘면 거대한 손이 내려와 장난감 상자에 넣습니다(오래 기다려야 다시 나옴, 상대 +1)\n발소리가 날 때 상대를 30cm 자로 밀치거나 탄산 캔(G, 목숨마다 3개)을 터뜨려 미끄러지게 하면, 문이 열려도 멈추지 못합니다\n아군 파란 병정 5 · 상대 장난감 11 · 7분" % TARGET

func brief_line() -> String: return "방문 손잡이가 돌아가면 절대 움직이지 마!"
func win_title() -> String: return "술래잡기 승리"
func pause_line() -> String:
	var cs := ceili(time_left)
	return "아군 %d · 상대 %d · 목표 %d · 남은 시간 %d:%02d" % [m.score.us, m.score.them, TARGET, cs / 60, cs % 60]

func state() -> Dictionary:
	return {"phase": phase, "phase_t": phase_t, "next": next_t, "visits": visits, "caught": caught.size(), "grab": grab != null, "boxed": boxed.duplicate(), "cans": cans, "puddles": puddles.size(), "time": time_left, "look": look_len}

## for the tests and pictures: visit (the footsteps now), look (straight to the owner looking in), catch <near|you>, can
func cmd(a: Array) -> Dictionary:
	match str(a[0]) if a.size() > 0 else "":
		"visit": next_t = 0.0; _visit(0.0)
		"look":
			if phase == "calm": _warn()
			phase = "open"; phase_t = OPEN; _visit(0.0)
		"catch":
			if str(a[1]) == "you": _catch(m.player)
			else:
				var best = null; var bd := INF
				for u in m.units("them"):
					if u.pos.distance_to(m.player.pos) < bd: bd = u.pos.distance_to(m.player.pos); best = u
				if best != null: _catch(best)
		"can": throw_can()
		"bring":   # the nearest of theirs, stood at x z (for pictures of the hand)
			var best = null; var bd := INF
			for u in m.units("them"):
				if u.pos.distance_to(m.player.pos) < bd: bd = u.pos.distance_to(m.player.pos); best = u
			if best != null: best.pos = Vector3(float(a[1]), 0.0, float(a[2])); best.g.position = best.pos; best.k.path = []
	return state()
