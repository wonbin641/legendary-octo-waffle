class_name ModeRush
extends ToyMode
## AA 배터리 쟁탈전: wake your giant robot before the power runs out. Giant AA batteries come down in the middle of the room
## (on the block bridge, or on the round rug under it) every twenty seconds; pull one free (a second beside it), carry it
## home and plug it into your robot's chest. Three in, and the robot wakes: its eyes light, it raises its arms and burns the
## other side's toy fortress down with lasers and foam missiles. A battery is the size of a toy soldier: whoever carries one
## has only the dart pistol and the ruler, and goes a little slower. The way home is the open floor, the dark crawl space
## under the bed, or the desk and its stairs over the block bridge. Ours: the carpet, south. Theirs: the nook between the
## bookshelf and the wardrobe, north.

const POWER := 480.0          # 8 minutes before the room's power goes
const NEED := 3
const FIRST_DROP := 7.0
const DROP_EVERY := 24.0
const MAX_FREE := 2           # batteries lying about (or coming down) at once
const PICK_T := 1.0           # a second beside it to pull it free
const PICK_R := 2.2
const FIZZLE := 35.0          # one nobody touches for this long goes flat and is gone
const FALL_Y := 26.0
const ZONE_R := 4.5
const CARRY_MUL := 0.8        # you, carrying
const DELIVER_PAY := 5000
const ZONE := {"us": Vector3(0, 0, 51), "them": Vector3(0, 0, -51)}
const ROBOT := {"us": Vector3(0, 0, 58), "them": Vector3(0, 0, -58)}
const GATE_Z := {"us": 44.0, "them": -44.0}   # the fortress's front wall (its gate 6 m wide in the middle)
const DROPS := [[Vector3(-14, 9, 0), "블록 다리 위"], [Vector3(-6, 0, 10), "가운데 러그 남쪽"], [Vector3(-14, 9, 0), "블록 다리 위"], [Vector3(-6, 0, -10), "가운데 러그 북쪽"]]
const SPAWNS := {"us": [Vector3(-5, 0, 52), Vector3(5, 0, 52), Vector3(-6, 0, 48), Vector3(6, 0, 48), Vector3(-3, 0, 54), Vector3(3, 0, 54)],
	"them": [Vector3(-5, 0, -52), Vector3(5, 0, -52), Vector3(-6, 0, -48), Vector3(6, 0, -48), Vector3(-3, 0, -54), Vector3(3, 0, -54)]}
const GUARD := {"us": [Vector3(-5, 0, 41), Vector3(5, 0, 41), Vector3(0, 0, 47)], "them": [Vector3(-5, 0, -41), Vector3(5, 0, -41), Vector3(0, 0, -47)]}
const PUSH := {"us": [Vector3(-10, 0, 16), Vector3(2, 0, 16), Vector3(-16, 9, 1.5), Vector3(13, 6, 6), Vector3(-33, 9, 8), Vector3(-4, 0, 24)],
	"them": [Vector3(-10, 0, -16), Vector3(2, 0, -16), Vector3(-12, 9, -1.5), Vector3(13, 6, -6), Vector3(-33, 9, -8), Vector3(-4, 0, -24)]}
const STYLES := [{"bed": 0.45, "high": 1.3}, {"high": 0.55, "bed": 1.4}, {"mid": 0.7}]
const ENEMY_SQUAD := [["soldier", "trooper", "guard"], ["brick", "brick", "guard"], ["soldier", "trooper", "push"], ["soldier", "trooper", "push"], ["soldier", "trooper", "push"],
	["soldier", "trooper", "push"], ["soldier", "trooper", "push"], ["figure", "smg", "push"], ["figure", "shotgun", "push"], ["figure", "smg", "push"], ["brick", "brick", "push"], ["brick", "brick", "push"]]

var room: ToyRoom
var batteries: Array = []    # {pos, state: fall/ground/carried/fly/slot/gone, by, node, chute, beacon, idle, pull, pull_team, fly_t, from, team}
var drop_t := FIRST_DROP
var drops := 0
var slots := {"us": 0, "them": 0}
var phase := "play"          # play, then wake (a robot powering up), then done
var wake_team := ""
var wake_t := 0.0
var robots := {}             # team: {node, eyes: [mesh], eye_mat, cells: [node], lamps: [mesh], key, arm_l, arm_r, ant}
var forts := {}              # team: {node, boxes: [Phys.Box], rubble, towers: [Vector3]}
var carry = null             # the battery in your arms
var pull := 0.0              # your pull on a battery beside you (0..1)
var prev_gun := ""
var missiles: Array = []     # the finale's foam missiles: {node, from, to, t, dur}
var _plan_t := 0.0
var _beep_t := 0.0
var _cell_mat: StandardMaterial3D

func _init() -> void:
	time_left = POWER; lose_title = "상대 로봇이 먼저 깨어났습니다"

func skips(what: String) -> bool:
	return what in ["tacks_mid", "block_-8_58", "block_8_40"]

# ---------------- the room ----------------
func extra_nodes() -> Dictionary:
	return {"bs_n": Vector3(-19, 0, -32), "st_n": Vector3(-39.6, 8.93, -30.5), "dk_n2": Vector3(-39.6, 9, -26.5), "g_s": Vector3(0, 0, 40), "g_n": Vector3(0, 0, -40)}

func extra_edges() -> Array:
	return [["dk_n15", "dk_n2", false, "high"], ["dk_n2", "st_n", false, "high"], ["st_n", "bs_n", false, "high"], ["bs_n", "m_n", false, ""],
		["g_s", "z_s", false, ""], ["g_n", "z_n", false, ""], ["w_s", "g_s", false, ""], ["e_far_s", "g_s", false, ""], ["w_n", "g_n", false, ""], ["e_far_n", "g_n", false, ""]]

func cut_edges() -> Array: return [["e_far_s", "z_s"], ["w_n", "z_n"], ["e_far_n", "z_n"]]

func keep_off(x: float, z: float, _y: float) -> bool:
	for t in ["us", "them"]:
		var zc: Vector3 = ZONE[t]
		if absf(x) < 13.0 and absf(z - zc.z) < 17.0: return true   # the fortress and what is in front of its gate
	return Vector2(x + 6.0, z).length() < 14.0   # the round rug in the middle

func start() -> Dictionary: return {"x": 0.0, "z": 50.0, "yaw": 0.0}

func build_room(r: ToyRoom) -> void:
	room = r
	# stacked school books on the north side too: the desk's other way down, to the bookshelf's side of the room
	r.stairs(-22.0, 0, -32.0, "-x", 19, 0.47, 0.95, 8.0, "f4d35e", "5fbf8f")
	# the round rug in the middle, under the bridge: where the batteries come down
	for q in [[13.0, "f2c14e"], [10.0, "e76f51"], [6.5, "2a9d8f"], [3.0, "f4f1e8"]]: r.cyl(Vector3(-6, 0.02 + (13.0 - q[0]) * 0.002, 0), q[0], 0.04, q[1], false)
	for t in ["us", "them"]: _fort(t); _robot(t)
	_cell_mat = Gfx.std(Color("1c1c1c"), 0.4, 0.2)

## a toy fortress of building blocks round each robot: a front wall with a gate, side walls, towers with flags at its corners
func _fort(team: String) -> void:
	var s := 1.0 if team == "us" else -1.0; var gz: float = GATE_Z[team]; var col := "3d6fd1" if team == "us" else "d62828"; var c2 := "f4d35e" if team == "us" else "2b2d42"
	var back_w := 60.0 if team == "us" else -55.6; var back_e := 60.0 if team == "us" else -53.6   # (the north one backs onto the bookshelf and the wardrobe)
	var parts: Array = []; var boxes: Array = []
	var add := func(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, c: String) -> void:
		var za := minf(z0, z1); var zb := maxf(z0, z1)
		parts.push_back([x1 - x0, y1 - y0, zb - za, (x0 + x1) / 2.0, (y0 + y1) / 2.0, (za + zb) / 2.0, c]); boxes.push_back(Phys.add_collider(x0, y0, za, x1, y1, zb, "concrete"))
	var f0 := gz - 0.5 * s; var f1 := gz + 0.5 * s
	add.call(-10.0, 0.0, f0, -3.0, 4.0, f1, col); add.call(3.0, 0.0, f0, 10.0, 4.0, f1, col)
	add.call(-3.0, 3.0, f0, 3.0, 4.0, f1, c2)                                                       # the gate's lintel
	add.call(-10.0, 0.0, f1, -9.0, 4.0, back_w, col); add.call(9.0, 0.0, f1, 10.0, 4.0, back_e, col)     # the side walls
	for i in 7:   # battlements along the front
		var x := -9.5 + i * 3.0
		if absf(x) > 3.2: add.call(x - 0.5, 4.0, f0, x + 0.5, 5.0, f1, c2)
	var towers: Array = []
	for tx in [-9.5, 9.5]:
		add.call(tx - 1.3, 0.0, gz - 1.3, tx + 1.3, 7.0, gz + 1.3, c2 if team == "us" else col); towers.push_back(Vector3(tx, 7.0, gz))
		var roof := room.cyl(Vector3(tx, 8.2, gz), 1.8, 2.4, col if team == "us" else "f2f2f2", false, 0.0)
		var pole := room.cyl(Vector3(tx, 10.4, gz), 0.07, 2.4, "c9ced6", false)
		var flag := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = Vector3(1.4, 0.8, 0.04); flag.mesh = fb; flag.material_override = Gfx.std(Color("5f9cff" if team == "us" else "ff5260"), 0.6); flag.position = Vector3(tx + 0.75, 11.1, gz); room.G.add_child(flag)
		roof.set_meta("fort", team); pole.set_meta("fort", team); flag.set_meta("fort", team)
	var mi := MeshInstance3D.new(); mi.mesh = Gfx.merge_boxes(parts, true); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.6; mi.material_override = mat; room.G.add_child(mi)
	forts[team] = {"node": mi, "boxes": boxes, "towers": towers, "down": false}

## a giant tin wind-up robot: three battery slots in its chest, a key in its back; it faces the room from its fortress
func _robot(team: String) -> void:
	var us := team == "us"; var at: Vector3 = ROBOT[team]; var col := "3d6fd1" if us else "d62828"; var trim := "f4d35e" if us else "2b2d42"; var tin := "c9ced6"
	var n := Node3D.new(); n.position = at; n.rotation.y = PI if us else 0.0; room.G.add_child(n)
	var body := MeshInstance3D.new(); body.mesh = Gfx.merge_boxes([
		[1.6, 0.8, 2.6, -1.3, 0.4, 0.3, trim], [1.6, 0.8, 2.6, 1.3, 0.4, 0.3, trim], [1.1, 2.6, 1.1, -1.3, 2.1, 0, tin], [1.1, 2.6, 1.1, 1.3, 2.1, 0, tin],
		[3.6, 0.8, 1.8, 0, 3.6, 0, col], [4.6, 3.8, 3.0, 0, 5.9, 0, col], [3.7, 2.9, 0.16, 0, 5.9, 1.52, "2b2d42"],
		[0.16, 2.9, 0.3, -0.55, 5.9, 1.5, tin], [0.16, 2.9, 0.3, 0.55, 5.9, 1.5, tin], [4.8, 0.3, 3.2, 0, 7.9, 0, trim],
		[2.8, 2.0, 2.4, 0, 8.95, 0, tin], [2.6, 0.75, 0.1, 0, 9.1, 1.22, "1c1c1c"], [1.4, 0.3, 0.1, 0, 8.35, 1.22, "8d99ae"],
		[0.6, 0.6, 0.6, -1.7, 9.0, 0, trim], [0.6, 0.6, 0.6, 1.7, 9.0, 0, trim], [0.14, 1.4, 0.14, 0, 10.6, 0, tin],
		[1.2, 1.1, 1.7, -2.95, 7.25, 0, trim], [1.2, 1.1, 1.7, 2.95, 7.25, 0, trim]], true)
	var bm := StandardMaterial3D.new(); bm.vertex_color_use_as_albedo = true; bm.roughness = 0.35; bm.metallic = 0.35; body.material_override = bm; n.add_child(body)
	# foam missiles in the shoulder pods, their orange tips looking out
	for sx in [-2.95, 2.95]:
		for oy in [-0.25, 0.25]:
			var tip := MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.0; tc.bottom_radius = 0.2; tc.height = 0.4; tip.mesh = tc; tip.material_override = Gfx.std(Color("f77f00"), 0.7)
			tip.rotation.x = PI / 2; tip.position = Vector3(sx, 7.25 + oy, 0.95); n.add_child(tip)
	# the eyes: dark now, lit when it wakes
	var eye_mat := StandardMaterial3D.new(); eye_mat.albedo_color = Color("30343b"); eye_mat.roughness = 0.3; eye_mat.emission_enabled = true; eye_mat.emission = Color("ffe066"); eye_mat.emission_energy_multiplier = 0.0
	var eyes: Array = []
	for ex in [-0.65, 0.65]:
		var e := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.64; e.mesh = sm; e.material_override = eye_mat; e.position = Vector3(ex, 9.12, 1.25); n.add_child(e); eyes.push_back(e)
	var ant := MeshInstance3D.new(); var asp := SphereMesh.new(); asp.radius = 0.3; asp.height = 0.6; ant.mesh = asp; var am := eye_mat.duplicate(); am.albedo_color = Color("e63946"); am.emission = Color("ff3b30"); ant.material_override = am; ant.position = Vector3(0, 11.45, 0); n.add_child(ant)
	# the three slots: a cell shows in each as it goes in, the lamp over it turns from red to green
	var cells: Array = []; var lamps: Array = []
	for i in 3:
		var sx := -1.12 + i * 1.12
		var cell := battery_node(); cell.position = Vector3(sx, 5.05, 1.35); cell.scale = Vector3.ONE * 0.95; cell.visible = false; n.add_child(cell); cells.push_back(cell)
		var lamp := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.5, 0.18, 0.08); lamp.mesh = lb; var lm := StandardMaterial3D.new(); lm.albedo_color = Color("5a1010"); lm.emission_enabled = true; lm.emission = Color("ff3b30"); lm.emission_energy_multiplier = 0.6
		lamp.material_override = lm; lamp.position = Vector3(sx, 7.52, 1.62); n.add_child(lamp); lamps.push_back(lamp)
	var key := Node3D.new(); key.position = Vector3(0, 6.2, -1.7); n.add_child(key)
	var km := MeshInstance3D.new(); km.mesh = Gfx.merge_boxes([[0.3, 0.3, 1.2, 0, 0, -0.5, tin], [2.4, 0.9, 0.18, 0, 0, -1.15, trim]], true); km.material_override = bm; key.add_child(km)
	var arms: Array = []
	for sx in [-2.75, 2.75]:
		var arm := Node3D.new(); arm.position = Vector3(sx * 1.08, 7.2, 0); n.add_child(arm)
		var aw := MeshInstance3D.new(); aw.mesh = Gfx.merge_boxes([[0.9, 3.0, 0.9, 0, -1.6, 0, tin], [1.2, 0.9, 1.2, 0, -3.3, 0, col]], true); aw.material_override = bm; arm.add_child(aw); arms.push_back(arm)
	var cz: float = at.z
	Phys.add_collider(at.x - 3.6, 0.0, cz - 1.8, at.x + 3.6, 10.0, cz + 1.8, "metal")
	robots[team] = {"node": n, "eyes": eyes, "eye_mat": eye_mat, "ant": ant, "ant_mat": am, "cells": cells, "lamps": lamps, "key": key, "arms": arms}

## an AA cell standing on its end, 1.7 m (a toy soldier's height): black, a copper top, the silver button
static func battery_node() -> Node3D:
	var n := Node3D.new()
	for p in [[0.42, 1.2, 0.62, "1c1c1c", 0.45, 0.2], [0.425, 0.44, 1.42, "c87533", 0.3, 0.7], [0.43, 0.06, 1.2, "f4d35e", 0.3, 0.6], [0.15, 0.1, 1.69, "c9ced6", 0.25, 0.9], [0.4, 0.05, 0.03, "c9ced6", 0.25, 0.9]]:
		var mi := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = p[0]; c.bottom_radius = p[0]; c.height = p[1]; c.radial_segments = 18; mi.mesh = c
		mi.material_override = Gfx.std(Color(p[3]), p[4], p[5]); mi.position.y = p[2]; n.add_child(mi)
	return n

# ---------------- the two sides ----------------
func populate() -> void:
	for i in 6: m.add_unit("us", "soldier", SPAWNS.us[i], {"job": "guard" if i == 0 else "push", "idx": i})
	for i in ENEMY_SQUAD.size():
		var q: Array = ENEMY_SQUAD[i]; var at: Vector3 = SPAWNS.them[i % 6] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
		m.add_unit("them", q[0], at, {"gun": q[1], "job": q[2], "idx": i, "tint": i % 4})

func on_respawn(u, _team: String) -> void:
	if u is Player: return
	u.k.bat = null; u.k.prey = null; u.k.buddy = null; u.k.style = {}; u.k.look = Vector3(0, 0, 0)

func spawn_at(team: String, who := "") -> Vector3:
	if who == "player": return Vector3(0, 0, 50) if team == "us" else Vector3(0, 0, -50)
	var L: Array = SPAWNS[team]
	for k in 8:
		var p: Vector3 = L[randi() % L.size()] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		if Phys.collide_at(p.x, 0.05, p.z, 0.5, 1.8) == null: return p
	return L[0]

# ---------------- the turn ----------------
func update(dt: float) -> void:
	if phase == "wake": _wake(dt); return
	if phase != "play": return
	time_left = maxf(0.0, time_left - dt)
	if time_left <= 0.0:
		lose_stamp = "전원 꺼짐"; lose_title = "전원이 꺼졌습니다 · 로봇을 깨우지 못했습니다"; phase = "done"
		for r in robots.values(): (r.ant_mat as StandardMaterial3D).emission_energy_multiplier = 0.0
		m.game.lose_match(); return
	if time_left < 60.0:   # the last minute: a beep every ten seconds, then every second
		_beep_t -= dt
		if _beep_t <= 0.0: _beep_t = 1.0 if time_left < 10.0 else 10.0; Snd.play("beep")
	drop_t -= dt
	var free := batteries.filter(func(b): return b.state == "fall" or b.state == "ground").size()
	if drop_t <= 0.0:
		if free < MAX_FREE: _drop(); drop_t = DROP_EVERY
		else: drop_t = 3.0
	for b in batteries: _battery(b, dt)
	_you(dt)
	_plan_t -= dt
	if _plan_t <= 0.0: _plan_t = 0.8; _plan()
	for t in robots: (robots[t].key as Node3D).rotation.z += dt * (0.4 + slots[t] * 0.6)   # the key turns faster as it fills

func _drop() -> void:
	var d: Array = DROPS[drops % DROPS.size()]; drops += 1
	var p: Vector3 = d[0] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0) if d[0].y > 0.0 else randf_range(-2.0, 2.0))
	var n := battery_node(); n.position = Vector3(p.x, FALL_Y, p.z); room.G.add_child(n)
	var chute := Node3D.new(); n.add_child(chute); chute.position.y = 4.6
	var cm := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 2.2; sm.height = 2.2; sm.is_hemisphere = true; cm.mesh = sm; cm.material_override = Gfx.std(Color("e63946"), 0.8); chute.add_child(cm)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var line := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.04, 3.2, 0.04); line.mesh = lb; line.material_override = Gfx.std(Color("f2f2f2"), 0.8)
			line.position = Vector3(sx * 0.9, -1.4, sz * 0.9); line.rotation = Vector3(-sz * 0.5, 0, sx * 0.5); chute.add_child(line)
	var beacon := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.22; bc.bottom_radius = 0.22; bc.height = 16.0; beacon.mesh = bc
	var bmat := StandardMaterial3D.new(); bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bmat.albedo_color = Color(1.0, 0.85, 0.2, 0.32); bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon.material_override = Gfx.see_through(bmat); beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; beacon.visible = false; room.G.add_child(beacon)
	var land := Vector3(p.x, Phys.ground_at(p.x, FALL_Y, p.z, 0.45), p.z)
	batteries.push_back({"pos": Vector3(p.x, FALL_Y, p.z), "land": land, "state": "fall", "by": null, "node": n, "chute": chute, "beacon": beacon, "idle": 0.0, "pull": 0.0, "pull_team": "", "spot": d[1], "fly_t": 0.0, "from": Vector3.ZERO, "team": "", "cell": 0})
	Snd.play("swoosh"); m.game.say_banner("건전지 투하", str(d[1]) + "에 떨어집니다", 2.0)

func _battery(b: Dictionary, dt: float) -> void:
	if b.state == "slot" or b.state == "gone": return   # (its node is gone: the robot shows its own cell)
	var n: Node3D = b.node
	match b.state:
		"fall":
			var gy := Phys.ground_at(b.pos.x, b.pos.y, b.pos.z, 0.45)
			b.pos.y = maxf(gy, b.pos.y - 6.5 * dt); n.position = b.pos; n.rotation.y += dt * 0.8
			if b.pos.y <= gy + 0.001: _land(b, gy)
		"ground":
			b.idle = float(b.idle) + dt
			if float(b.idle) > FIZZLE and float(b.pull) <= 0.0:   # flat: a puff, and it is gone
				b.state = "gone"; n.queue_free(); (b.beacon as Node3D).queue_free()
				if fx(): fx().puff(b.pos + Vector3(0, 0.5, 0), 6, 0.5, 0.6)
				m.game.say_feed("건전지가 방전되어 사라졌습니다"); return
			_pulls(b, dt)
		"carried":
			var c = b.by
			if c is Player: b.pos = m.player.pos + Vector3(0, 1.0, 0); n.visible = false
			else: b.pos = c.pos + Vector3(0, c.H + 0.45, 0); n.visible = true; n.position = b.pos; n.rotation = Vector3(0, c.yaw + PI / 2, PI / 2)
		"fly":
			b.fly_t = float(b.fly_t) + dt; var f := clampf(float(b.fly_t) / 0.6, 0.0, 1.0)
			var r: Dictionary = robots[b.team]; var cell: Node3D = r.cells[int(b.cell)]
			var to := cell.global_position; var arc := sin(f * PI) * 2.5
			n.position = (b.from as Vector3).lerp(to, f) + Vector3(0, arc, 0); n.rotation = Vector3(0, 0, PI / 2 * (1.0 - f))
			if f >= 1.0: b.state = "slot"; n.queue_free(); cell.visible = true; _lit(b.team)

func fx() -> Fx: return m.fx

func _land(b: Dictionary, gy: float) -> void:
	b.state = "ground"; b.pos.y = gy; b.idle = 0.0; (b.chute as Node3D).queue_free(); b.chute = null
	var n: Node3D = b.node; n.position = b.pos + Vector3(0, 0.42, 0); n.rotation = Vector3(0, n.rotation.y, PI / 2)
	var bc: Node3D = b.beacon; bc.visible = true; bc.position = b.pos + Vector3(0, 8.0, 0)
	Snd.play("thump", 1.0, b.pos); if fx(): fx().puff(b.pos + Vector3(0, 0.3, 0), 5, 0.6, 0.5)

## who is pulling it free: a second beside it, by one side only (with both sides beside it, nobody gets anywhere)
func _pulls(b: Dictionary, dt: float) -> void:
	var near := {"us": [], "them": []}
	if m.player_in() and _beside(m.player.pos, b.pos) and carry == null: near.us.push_back(m.player)
	for t in ["us", "them"]:
		for u in m.units(t):
			if u.k.carrying == null and _beside(u.pos, b.pos): near[t].push_back(u)
	var side := ""
	if not near.us.is_empty() and near.them.is_empty(): side = "us"
	elif not near.them.is_empty() and near.us.is_empty(): side = "them"
	if side == "" or (b.pull_team != "" and b.pull_team != side): b.pull = maxf(0.0, float(b.pull) - dt * 2.0); b.pull_team = side if float(b.pull) <= 0.0 else b.pull_team; return
	b.pull_team = side; b.pull = float(b.pull) + dt / PICK_T
	if float(b.pull) >= 1.0:
		var who = near[side][0]
		if side == "us" and near.us.has(m.player): who = m.player
		_take(b, who)

func _beside(p: Vector3, q: Vector3) -> bool: return Vector2(p.x - q.x, p.z - q.z).length() < PICK_R and absf(p.y - q.y) < 1.8

func _take(b: Dictionary, who) -> void:
	b.state = "carried"; b.by = who; b.pull = 0.0; b.pull_team = ""; (b.beacon as Node3D).visible = false
	Snd.play("pickup_ammo", 1.0, b.pos)
	if who is Player:
		carry = b; prev_gun = m.guns.cur; m.guns.lock_to = "pistol"; m.guns.force_to("pistol"); m.player.carry_mul = CARRY_MUL
		m.game.say_banner("건전지 확보", "아군 로봇으로 가져가세요 · 다트 권총과 30cm 자만 쓸 수 있습니다", 2.4)
	else:
		who.k.carrying = b; who.k.job = "carry"; who.k.style = STYLES[randi() % STYLES.size()].duplicate()
		if who.k.team == "them":   # their carrier keeps clear of where you stand
			for nname in m.nodes:
				if (m.nodes[nname] as Vector3).distance_to(m.player.pos) < 14.0: who.k.style["@" + nname] = 40.0
		who.k.repath = true; who.k.think_t = 0.0
		m.game.say_feed("아군이 건전지를 확보했습니다" if who.k.team == "us" else "상대가 건전지를 가져갑니다!")

## it falls where its carrier fell
func _drop_from(b: Dictionary, at: Vector3) -> void:
	var gy := Phys.ground_at(at.x, at.y + 1.0, at.z, 0.45)
	b.state = "ground"; b.by = null; b.pos = Vector3(at.x, gy, at.z); b.idle = 0.0; b.pull = 0.0; b.pull_team = ""
	var n: Node3D = b.node; n.visible = true; n.position = b.pos + Vector3(0, 0.42, 0); n.rotation = Vector3(0, randf() * TAU, PI / 2)
	var bc: Node3D = b.beacon; bc.visible = true; bc.position = b.pos + Vector3(0, 8.0, 0)
	Snd.play("thud", 1.0, b.pos)

func _deliver(b: Dictionary, team: String) -> void:
	var c = b.by
	b.from = (m.player.pos + Vector3(0, 1.2, 0)) if c is Player else (b.node as Node3D).position
	b.state = "fly"; b.fly_t = 0.0; b.team = team; b.by = null; (b.node as Node3D).visible = true
	slots[team] = mini(NEED, int(slots[team]) + 1); b.cell = int(slots[team]) - 1
	Snd.play("toy_mag_in", 1.0, ROBOT[team]); Snd.play("charge", 1.0, ROBOT[team])
	if c is Player:
		carry = null; _unlock()
		var pay := 0 if m.game.replay else DELIVER_PAY
		if pay > 0: Store.save.money += pay; m.game.stats.earned += pay; Store.persist(); Snd.play("coin"); m.game._say(m.game.on_pay, [pay])
		m.game._say(m.game.feed, ["건전지 충전 · 아군 로봇 %d/%d" % [slots[team], NEED], pay, false])
	elif c != null:
		c.k.carrying = null; c.k.job = c.k.base_job; c.k.repath = true
		m.game.say_feed(("아군 로봇 충전 %d/%d" if team == "us" else "상대 로봇 충전 %d/%d") % [slots[team], NEED])
	if team == "them": Snd.play("alarm"); m.game.say_banner("상대 로봇 %d/%d" % [slots.them, NEED], "상대가 건전지를 꽂았습니다", 1.8)
	elif not (c is Player): m.game.say_banner("아군 로봇 %d/%d" % [slots.us, NEED], "아군 병정이 건전지를 꽂았습니다", 1.6)

func _lit(team: String) -> void:
	var r: Dictionary = robots[team]
	for i in 3:
		var lm: StandardMaterial3D = (r.lamps[i] as MeshInstance3D).material_override
		var on := i < int(slots[team]); lm.emission = Color("3dff6e") if on else Color("ff3b30"); lm.albedo_color = Color("0f4a1c") if on else Color("5a1010"); lm.emission_energy_multiplier = 1.4 if on else 0.6
	if int(slots[team]) >= NEED and phase == "play": _start_wake(team)

func _unlock() -> void:
	m.guns.lock_to = ""; m.player.carry_mul = 1.0
	if prev_gun != "" and prev_gun != "pistol": m.guns.switch_to(prev_gun)

## you: pulling one beside you, carrying one home
func _you(dt: float) -> void:
	pull = 0.0
	if carry != null:
		if not m.player_in(): return
		if Vector2(m.player.pos.x - ZONE.us.x, m.player.pos.z - ZONE.us.z).length() < ZONE_R and absf(m.player.pos.y) < 2.0: _deliver(carry, "us")
		return
	for b in batteries:
		if b.state == "ground" and b.pull_team == "us" and _beside(m.player.pos, b.pos): pull = float(b.pull)
	# their carriers, at their gate
	for u in m.units("them") + m.units("us"):
		var b = u.k.carrying
		if b == null: continue
		var z: Vector3 = ZONE[u.k.team]
		if Vector2(u.pos.x - z.x, u.pos.z - z.z).length() < ZONE_R and absf(u.pos.y - z.y) < 2.0: _deliver(b, u.k.team)

func player_carrying() -> bool: return carry != null

func on_player_down() -> void:
	if carry != null: var b = carry; carry = null; _unlock(); _drop_from(b, m.player.pos); m.game.say_feed("건전지를 떨어뜨렸습니다")

func on_kill(e: Enemies.Foe, _by: String) -> void:
	if e.k.carrying != null: var b = e.k.carrying; e.k.carrying = null; _drop_from(b, e.pos); m.game.say_feed("상대가 건전지를 떨어뜨렸습니다")

func on_ally_down(a: Enemies.Foe, _by: String) -> void:
	if a.k.carrying != null: var b = a.k.carrying; a.k.carrying = null; _drop_from(b, a.pos)

## who does what: a runner for each battery lying free (two at most a side), hunters after the other side's carriers,
## two to see each of our own carriers home, the rest at their posts (guards at the gate, the others in the middle)
func _plan() -> void:
	var free := batteries.filter(func(b): return b.state == "ground" or b.state == "fall")
	for team in ["us", "them"]:
		var mine: Array = m.units(team)
		for u in mine:
			if u.k.carrying != null: u.k.job = "carry"; continue
			if u.k.job == "run" and not free.has(u.k.bat): u.k.job = u.k.base_job; u.k.bat = null
			if u.k.job == "hunt" or u.k.job == "escort": u.k.job = u.k.base_job
		var runners: Array = mine.filter(func(u): return u.k.job == "run")
		for b in free:
			if runners.size() >= (1 if team == "us" else 2): break   # (ours send one: the other battery is yours)
			if runners.any(func(r): return r.k.bat == b): continue
			if team == "us" and m.player_in() and m.player.pos.distance_to(b.pos) < 16.0 and carry == null: continue   # yours: they leave it to you
			var best = null; var bd := INF
			for u in mine:
				if u.k.job == "carry" or u.k.job == "run": continue
				var d: float = u.pos.distance_to(b.pos) + (25.0 if u.k.base_job == "guard" else 0.0)
				if d < bd: bd = d; best = u
			if best != null: best.k.job = "run"; best.k.bat = b; runners.push_back(best)
		var theirs: Array = m.units("us" if team == "them" else "them").filter(func(u): return u.k.carrying != null)
		if team == "them" and carry != null and m.player_in(): theirs.push_back(m.player)
		for c in theirs:
			var free_u: Array = mine.filter(func(u): return u.k.job in ["push", "guard"])
			free_u.sort_custom(func(a, b2): return a.pos.distance_to(m.feet(c)) < b2.pos.distance_to(m.feet(c)))
			for i in mini(3, free_u.size()): free_u[i].k.job = "hunt"; free_u[i].k.prey = c
		var own: Array = mine.filter(func(u): return u.k.carrying != null)
		if team == "us" and carry != null and m.player_in(): own.push_back(m.player)
		for c in own:
			var free_u: Array = mine.filter(func(u): return u.k.job in ["push", "guard"] and u.k.base_job != "guard")
			free_u.sort_custom(func(a, b2): return a.pos.distance_to(m.feet(c)) < b2.pos.distance_to(m.feet(c)))
			for i in mini(2, free_u.size()): free_u[i].k.job = "escort"; free_u[i].k.buddy = c

func goal(u: Enemies.Foe) -> Dictionary:
	var team: String = u.k.team; var idx := int(u.k.spawn_opts.get("idx", 0))
	match str(u.k.job):
		"carry": return {"at": ZONE[team], "near": 1.5, "hurry": true, "bias": u.k.style}
		"run":
			var b = u.k.bat
			if b == null: return {}
			return {"at": b.land if b.state == "fall" else b.pos, "near": 1.0, "hurry": true}
		"hunt":
			if not m.alive(u.k.prey): return {"at": PUSH[team][idx % 6], "near": 2.0}
			return {"at": m.feet(u.k.prey), "near": 9.0}
		"escort":
			if not m.alive(u.k.buddy): return {"at": PUSH[team][idx % 6], "near": 2.0}
			var bp: Vector3 = m.feet(u.k.buddy); var side := Vector3(3.0 if idx % 2 else -3.0, 0, 2.5 if team == "us" else -2.5)
			return {"at": bp + side, "near": 2.5}
		"guard":
			u.k.look = Vector3(0, 0, 0); return {"at": GUARD[team][idx % 3], "near": 1.2}
	u.k.look = Vector3(0, 0, 0)
	return {"at": PUSH[team][idx % 6], "near": 2.5}

func hold(_u: Enemies.Foe) -> bool: return phase != "play"

# ---------------- the finale ----------------
func _start_wake(team: String) -> void:
	phase = "wake"; wake_team = team; wake_t = 0.0; m.player.invuln = 1e9
	Snd.play("charge"); Snd.play("revive")
	m.game.say_banner("아군 로봇 가동!" if team == "us" else "상대 로봇 가동!", "전원 100% · 거대 로봇이 깨어납니다", 3.0)
	if carry != null: var b = carry; carry = null; _unlock(); _drop_from(b, m.player.pos)

func _wake(dt: float) -> void:
	var before := wake_t; wake_t += dt
	var r: Dictionary = robots[wake_team]; var other := "them" if wake_team == "us" else "us"
	var on := clampf(wake_t / 1.2, 0.0, 1.0)
	(r.eye_mat as StandardMaterial3D).emission_energy_multiplier = on * 4.0; (r.eye_mat as StandardMaterial3D).albedo_color = Color("30343b").lerp(Color("fff3a0"), on)
	(r.ant_mat as StandardMaterial3D).emission_energy_multiplier = 3.0 if fmod(wake_t, 0.4) < 0.2 else 0.3
	(r.key as Node3D).rotation.z += dt * 9.0
	var lift := clampf((wake_t - 0.6) / 1.0, 0.0, 1.0); var ease := lift * lift * (3.0 - 2.0 * lift)
	for a: Node3D in r.arms: a.rotation.x = -ease * 2.6   # both arms up over its head
	(r.node as Node3D).position = ROBOT[wake_team] + Vector3(sin(wake_t * 40.0) * 0.04 * (1.0 - lift), 0, 0)
	var F: Dictionary = forts[other]
	if before < 1.8 and wake_t >= 1.8:   # the lasers: from both hands to the towers of the other fortress
		for i in 2:
			var hand: Vector3 = (r.arms[i] as Node3D).global_position + Vector3(0, 3.2, 0)
			var tw: Vector3 = F.towers[i]
			if fx(): fx().streak(hand, tw, Color(1.0, 0.25, 0.3, 0.95) if wake_team == "them" else Color(0.35, 0.85, 1.0, 0.95), 0.55, 1.6); fx().explode(tw, false, [1.0, 0.5, 0.4])
		Snd.play("beam"); Snd.play("zap_mech")
	if before < 2.4 and wake_t >= 2.4:   # foam missiles out of the shoulder pods, up and over, down onto the fortress
		for i in 6:
			var from: Vector3 = (r.node as Node3D).global_transform * Vector3(-2.95 if i % 2 == 0 else 2.95, 7.4, 1.2)
			var to: Vector3 = F.towers[i % 2] + Vector3(randf_range(-5.0, 5.0) * (1 if i > 1 else 0), randf_range(-4.0, 0.0), randf_range(-3.0, 3.0))
			var mm := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.28; cm.height = 1.4; mm.mesh = cm; mm.material_override = Gfx.std(Color("f77f00"), 0.7); room.G.add_child(mm)
			missiles.push_back({"node": mm, "from": from, "to": to, "t": -i * 0.12, "dur": 1.5})
		Snd.play("rocket_pod")
	for i in range(missiles.size() - 1, -1, -1):
		var q: Dictionary = missiles[i]; q.t = float(q.t) + dt
		if float(q.t) < 0.0: continue
		var f := clampf(float(q.t) / float(q.dur), 0.0, 1.0); var p: Vector3 = (q.from as Vector3).lerp(q.to, f) + Vector3(0, sin(f * PI) * 22.0, 0)
		(q.node as Node3D).position = p; (q.node as Node3D).look_at(p + ((q.to as Vector3) - (q.from as Vector3)).normalized() + Vector3(0, cos(f * PI) * 2.0, 0), Vector3.UP)
		if fx() and randf() < 0.5: fx().puff(p, 1, 0.9, 0.4)
		if f >= 1.0:
			if fx(): fx().explode(q.to, false, [1.0, 0.6, 0.2])
			Snd.play("toy_boom", 1.0, q.to); (q.node as Node3D).queue_free(); missiles.remove_at(i)
	if before < 4.1 and wake_t >= 4.1: _crumble(other)
	if wake_t >= 6.6 and phase == "wake":
		phase = "done"
		if wake_team == "us": m.game.win_match()
		else: m.game.lose_match()

## the fortress goes up: blasts all along it, its blocks thrown about, the walls gone
func _crumble(team: String) -> void:
	var F: Dictionary = forts[team]
	if bool(F.down): return
	F.down = true; (F.node as Node3D).visible = false
	for b: Phys.Box in F.boxes:
		Phys.remove_collider(b)
		var c := Vector3((b.minx + b.maxx) / 2.0, (b.miny + b.maxy) / 2.0, (b.minz + b.maxz) / 2.0)
		if fx() and randf() < 0.6: fx().explode(c, true, [1.0, 0.55, 0.3]); fx().chunks(c, 8, 0.5, "wood")
	for n in room.G.get_children():
		if n.has_meta("fort") and str(n.get_meta("fort")) == team: (n as Node3D).visible = false
	Snd.play("boom"); Snd.play("quake"); m.player.shake = maxf(m.player.shake, 0.6)
	m.game.say_banner("상대 요새 붕괴!" if team == "them" else "아군 요새 붕괴", "", 2.0)

# ---------------- what you see ----------------
func hud_cells() -> Array:
	var cs := ceili(time_left)
	return [["스테이지", "5", Color("f2a33a")], ["전원", "%d:%02d" % [cs / 60, cs % 60], Color("ff5260") if time_left < 60.0 else Color("ece6d8")],
		["아군 로봇", "%d / %d" % [slots.us, NEED], Color("5f9cff")], ["상대 로봇", "%d / %d" % [slots.them, NEED], Color("ff5260")], ["가방", Store.won(Store.save.money), Color("ece6d8")]]

func hud_bar() -> Array: return [time_left / POWER, Color("ff5260") if time_left < 60.0 else Color("f2a33a")]

func hud_lines() -> Array:
	if phase != "play": return []
	var spots: Array = batteries.filter(func(b): return b.state == "ground" or b.state == "fall").map(func(b): return str(b.spot))
	if carry != null: return [["운반 중", "아군 로봇까지", "%d m" % roundi(Vector2(m.player.pos.x - ZONE.us.x, m.player.pos.z - ZONE.us.z).length()), false]]
	if not spots.is_empty(): return [["건전지", " · ".join(spots), "%d개" % spots.size(), false]]
	return [["건전지", "다음 투하까지", "%d초" % ceili(drop_t), drop_t <= 3.0]]

func status() -> String:
	if carry != null: return "건전지 운반 중 · 다트 권총과 30cm 자만 · 조금 느려집니다"
	if pull > 0.0: return "건전지 확보 중 %d%%" % roundi(pull * 100.0)
	return ""

func aims() -> Array:
	var out: Array = []
	if phase != "play": return out
	if carry != null: return [[Vector2(ZONE.us.x, ZONE.us.z), 0.95, Color("5ed6b0")]]
	for b in batteries:
		if b.state == "ground" or b.state == "fall": out.push_back([Vector2(b.pos.x, b.pos.z), 0.9, Color("ffd23a")])
		elif b.state == "carried" and b.by != null and not (b.by is Player) and b.by.k.team == "them": out.push_back([Vector2(b.pos.x, b.pos.z), 0.85, Color("ff5260")])
	return out

func tac(ci, X: Callable, Z: Callable, k: float, u: float) -> void:
	for t in ["us", "them"]:
		var col := Color("5f9cff") if t == "us" else Color("ff5260"); var zc: Vector3 = ZONE[t]; var rc: Vector3 = ROBOT[t]
		ci.draw_arc(Vector2(X.call(zc.x), Z.call(zc.z)), ZONE_R * k, 0, TAU, 32, Color(col, 0.8), 1.6 * u)
		ci.draw_rect(Rect2(X.call(rc.x) - 3.6 * k, Z.call(rc.z) - 1.8 * k, 7.2 * k, 3.6 * k), col)
		for i in 3: ci.draw_circle(Vector2(X.call(rc.x - 2.4 + i * 2.4), Z.call(rc.z) - 4.5 * u), 2.4 * u, Color("3dff6e") if i < int(slots[t]) else Color(0.15, 0.17, 0.2, 0.9))
		if bool(forts[t].down): continue
		for bx: Phys.Box in forts[t].boxes: ci.draw_rect(Rect2(X.call(bx.minx), Z.call(bx.minz), maxf(1.0, (bx.maxx - bx.minx) * k), maxf(1.0, (bx.maxz - bx.minz) * k)), Color(col, 0.55))
	for d: Array in [DROPS[0], DROPS[1], DROPS[3]]:
		var p: Vector3 = d[0]; ci.draw_arc(Vector2(X.call(p.x), Z.call(p.z)), 2.6 * k, 0, TAU, 24, Color(1, 0.85, 0.2, 0.45), 1.2 * u)
	for b in batteries:
		if b.state in ["fall", "ground", "carried"]:
			var bp := Vector2(X.call(b.pos.x), Z.call(b.pos.z)); ci.draw_circle(bp, 4.2 * u, Color("ffd23a")); ci.draw_arc(bp, 6.0 * u, 0, TAU, 20, Color(0.05, 0.05, 0.05, 0.8), 1.4 * u)

func legend() -> Array:
	return [["ally", "5f9cff", "아군 병정 · 아군 로봇(남쪽)"], ["soldier", "7fc96b", "플라스틱 군인"], ["figure", "ff7a3a", "액션 피규어"], ["brick", "ffd23a", "조립 블록 피규어 · 건전지"], ["enemybase", "ff5260", "상대 로봇(북쪽)"]]

func brief() -> String:
	return "전원이 꺼지기 전에 거대 로봇을 깨워라! · 점령 & 운반\n방 한가운데(블록 다리 위, 다리 밑 둥근 러그)에 커다란 AA 건전지가 24초마다 떨어집니다 · 곁에서 1초 버티면 뽑아 들고, 남쪽 카펫의 아군 로봇 가슴 슬롯에 꽂으세요 · 3개를 먼저 채운 쪽 로봇이 깨어나 상대 요새를 레이저와 폼 미사일로 무너뜨립니다\n건전지를 든 동안은 다트 권총과 30cm 자만 쓸 수 있고 조금 느려집니다 · 쓰러지면 그 자리에 떨어뜨립니다\n길은 셋: 탁 트인 가운데 바닥, 침대 밑 어두운 통로, 책상 위 블록 다리와 책 계단\n아군 파란 병정 6 · 상대 장난감 12 (쓰러져도 기지에서 다시 나옵니다) · 전원 8분"

func brief_line() -> String: return "전원이 꺼지기 전에 거대 로봇을 깨워라! · 건전지 3개를 아군 로봇에"
func win_title() -> String: return "배터리 쟁탈전 승리"
func pause_line() -> String:
	var cs := ceili(time_left)
	return "아군 로봇 %d/%d · 상대 로봇 %d/%d · 전원 %d:%02d" % [slots.us, NEED, slots.them, NEED, cs / 60, cs % 60]

func state() -> Dictionary:
	return {"slots": slots.duplicate(), "phase": phase, "time": time_left, "drop_t": drop_t, "carry": carry != null, "pull": pull, "drops": drops,
		"bats": batteries.map(func(b): return {"state": b.state, "pos": [b.pos.x, b.pos.y, b.pos.z], "by": ("player" if b.by is Player else (str(b.by.k.team) if b.by != null else "")), "pull": b.pull}),
		"jobs": m.units("us").map(func(u): return str(u.k.job)) + m.units("them").map(func(u): return str(u.k.job))}

## for the tests and pictures: drop (a battery now), land (every one coming down lands), carry (one into your arms),
## give <team> <n> (that many in the robot), wake <team>
func cmd(a: Array) -> Dictionary:
	match str(a[0]) if a.size() > 0 else "":
		"drop": drop_t = 0.0; _drop(); drop_t = DROP_EVERY
		"land":
			for b in batteries:
				if b.state == "fall": b.pos = b.land; _land(b, (b.land as Vector3).y)
		"carry":
			_drop(); var b: Dictionary = batteries[batteries.size() - 1]; _land(b, (b.land as Vector3).y); _take(b, m.player)
		"give":
			var t := str(a[1]); slots[t] = clampi(int(a[2]), 0, NEED)
			for i in 3: (robots[t].cells[i] as Node3D).visible = i < int(slots[t])
			_lit(t)
		"wake": _start_wake(str(a[1]))
	return state()
