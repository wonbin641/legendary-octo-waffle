class_name Player
extends RefCounted
## The player's body and view: ported from updatePlayer in src/08a_player.js (walking, sprinting, jumping, steps, landing).
## Riding, the jetpack, stuns and the gun's effect on speed join in later stages of the port.

var pos := Vector3(0, 0, 4)
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
const HEIGHT := 1.7
const EYE := 1.62
const R := 0.36
var grounded := true
var speed_xz := 0.0
var sprinting := false
var sprint_blend := 0.0
var sprint_lock := 0.0
var step_phase := 0.0
var step_dist := 0.0
var recoil_pitch := 0.0
var shake := 0.0
var land_dip := 0.0
var jump_buf := 0.0

# what the input code sets each frame
var in_f := 0.0        # forward (+1) / back (-1)
var in_s := 0.0        # right (+1) / left (-1)
var in_run := false
var in_turn := 0.0     # arrow keys / Q E: +1 left, -1 right
var in_pitch := 0.0    # arrow up / down
var look_dx := 0.0     # mouse or finger movement since the last frame, in pixels
var look_dy := 0.0
var sens := 1.0
var move_mul := 1.0    # the weapon in hand (WEAPONS[..].moveMul)
var ads := 0.0         # 0 at the hip .. 1 aiming down the sights
var ads_slow := 1.0    # walking speed while aiming (0.6, or 0.4 through a scope)
var sens_mul := 1.0    # the mouse is slower while aiming
var no_sprint := false # aiming, shooting or reloading: no running
var hp := 1000.0
const MAX_HP := 1000.0
var invuln := 0.0
var since_hurt := 0.0
var on_hurt: Callable = Callable()
var on_step: Callable = Callable()

var jump_mul := 1.0     # a mattress gives a little more
var slow_mul := 1.0     # thumbtacks underfoot
var launched := false   # thrown by a catapult: no steering until you land
var since_zip := 9.0
var chute := false      # coming down under a parachute at the start
var say: Callable = Callable()       # a line for the feed (helmet broken, vest worn out, jetpack)
# the jetpack: double-tap jump to lift off; jump goes up, Ctrl or C down; 10 seconds, one use
var jet_on := false
var jet_t := 0.0
var jet_last_tap := -9.0
var in_up := false
var in_down := false

## dmg from a point; zone: 'head' (shots to the head, overhead blows), 'body' (everything else that hits you), 'fire' (flames)
func hurt(dmg: float, from: Vector3, zone := "body") -> void:
	if Store.settings.dev and Store.settings.god: return   # developer mode's invincibility
	if invuln > 0.0 or hp <= 0.0: return
	var items: Dictionary = Store.save.items
	# a motorcycle helmet takes one blow to the head for you, then it is gone
	if zone == "head" and int(items.helmet) > 0:
		items.helmet = 0; Store.persist(); shake = maxf(shake, 0.3); Snd.play("metal")
		if say.is_valid(): say.call("오토바이 헬멧이 머리 공격을 막았습니다 · 헬멧이 부서졌습니다")
		if on_hurt.is_valid(): on_hurt.call(8.0, from)
		return
	# a vest takes half of a hit to the body, ten times
	if zone == "body" and int(items.vest) > 0:
		dmg *= 0.5; items.vest = int(items.vest) - 1; Store.persist(); Snd.play("metal")
		if int(items.vest) == 0 and say.is_valid(): say.call("방탄조끼가 다 닳았습니다")
	dmg = maxf(1.0, roundf(dmg)); hp = maxf(0.0, hp - dmg); since_hurt = 0.0; shake = maxf(shake, 0.1 + dmg * 0.008)
	if on_hurt.is_valid(): on_hurt.call(dmg, from)

## thrown through the air: the given velocity, and no steering until you come down
func launch(v: Vector3) -> void:
	vel = v; grounded = false; launched = true; jump_buf = 0.0

## a press of jump at time now (seconds): the second within 0.35 s lights the jetpack, if you have one
func jet_tap(now: float) -> void:
	var dbl := now - jet_last_tap < 0.35; jet_last_tap = now
	if not dbl or jet_on or int(Store.save.items.jet) == 0: return
	jet_on = true; jet_t = 10.0; Store.save.items.jet = 0; Store.persist()
	vel.y = maxf(vel.y, 3.0); grounded = false; jet_last_tap = -9.0
	if say.is_valid(): say.call("제트백팩 · 점프 위로 · 내려가기 아래로")

func jet_end(msg := "") -> void:
	if not jet_on: return
	jet_on = false
	if msg != "" and say.is_valid(): say.call(msg)

func reset(x: float, z: float, yaw_: float) -> void:
	pos = Vector3(x, 0, z); vel = Vector3.ZERO; yaw = yaw_; pitch = 0.0; grounded = true
	jump_buf = 0.0; sprint_lock = 0.0; shake = 0.0; land_dip = 0.0; recoil_pitch = 0.0; look_dx = 0.0; look_dy = 0.0
	jump_mul = 1.0; slow_mul = 1.0; launched = false; chute = false; since_zip = 9.0
	hp = MAX_HP; invuln = 0.0; ads = 0.0; jet_on = false; jet_t = 0.0; jet_last_tap = -9.0

func update(dt: float, cam: Camera3D, time: float) -> void:
	var s := sens * 0.0021 * sens_mul
	yaw += in_turn * 2.4 * dt - look_dx * s
	pitch -= look_dy * s
	look_dx = 0.0; look_dy = 0.0
	pitch = clampf(pitch + in_pitch * 1.6 * dt, -1.5, 1.5)
	recoil_pitch *= exp(-dt * 9)
	var f := in_f; var sd := in_s
	var m := sqrt(f * f + sd * sd)
	if m > 1.0: f /= m; sd /= m
	sprint_lock = maxf(0.0, sprint_lock - dt)
	sprinting = in_run and f > 0.3 and sprint_lock <= 0.0 and not no_sprint
	var speed := (8.2 if sprinting else 5.4) * move_mul * ads_slow * slow_mul
	var sy := sin(yaw); var cy := cos(yaw)
	var tx := (-sy * f + cy * sd) * speed; var tz := (-cy * f - sy * sd) * speed
	var acc := 1.0 - exp(-dt * (11.0 if grounded else 2.2))
	if not launched: vel.x += (tx - vel.x) * acc; vel.z += (tz - vel.z) * acc
	jump_buf -= dt
	if jet_on:
		# flying: no gravity; hold jump to rise, Ctrl or C to sink, nothing to hover. it sputters out after 10 seconds
		jet_t -= dt
		var want := 5.0 if (in_up and not in_down) else (-5.0 if (in_down and not in_up) else 0.0)
		vel.y += (want - vel.y) * (1.0 - exp(-dt * 6.0)); jump_buf = 0.0
		if pos.y > 30.0 and vel.y > 0.0: vel.y = 0.0
		if jet_t <= 0.0: jet_end("제트백팩 연료가 다 떨어졌습니다")
	else:
		if jump_buf > 0.0 and grounded: vel.y = 6.6 * jump_mul; grounded = false; jump_buf = 0.0
		vel.y -= 19.0 * dt
		if chute and vel.y < -7.0: vel.y = -7.0   # the parachute holds the fall
	pos = Phys.move_xz(pos, vel.x * dt, vel.z * dt, R, HEIGHT, 0.5 if grounded else 0.2)[0]
	pos.x = clampf(pos.x, -Phys.HALF + R, Phys.HALF - R); pos.z = clampf(pos.z, -Phys.HALF + R, Phys.HALF - R)
	var gy := Phys.ground_at(pos.x, pos.y, pos.z, R)
	pos.y += vel.y * dt
	if vel.y > 0.0:
		var c := Phys.ceil_at(pos.x, pos.y - vel.y * dt, pos.z, R, HEIGHT)
		if pos.y + HEIGHT > c: pos.y = c - HEIGHT; vel.y = 0.0
	if pos.y <= gy:
		if not grounded and vel.y < -5.0: land_dip = clampf(-vel.y * 0.012, 0.0, 0.12)
		if jet_on and jet_t < 9.6 and vel.y <= 0.05: jet_end("제트백팩 착지")   # sinking onto the ground ends the flight
		pos.y = gy; vel.y = 0.0; grounded = true; launched = false; chute = false
	elif pos.y > gy + 0.05: grounded = false
	speed_xz = sqrt(vel.x * vel.x + vel.z * vel.z)
	if grounded and speed_xz > 0.5:
		step_phase += speed_xz * dt * 1.7; step_dist += speed_xz * dt
		if step_dist > (2.6 if sprinting else 2.1):
			step_dist = 0.0
			if on_step.is_valid(): on_step.call()
	sprint_blend = lerpf(sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-dt * 8))
	land_dip *= exp(-dt * 8)
	invuln = maxf(0.0, invuln - dt); since_hurt += dt
	if cam == null: return
	var bob := absf(sin(step_phase)) * 0.045 * clampf(speed_xz / 6.0, 0.0, 1.3) * (1.0 - ads * 0.7) if grounded else 0.0
	var sh := shake; shake *= exp(-dt * 7)
	cam.position = Vector3(pos.x, pos.y + EYE - bob - land_dip, pos.z)
	cam.rotation = Vector3(pitch + recoil_pitch * 0.5 + randf_range(-1, 1) * sh * 0.05, yaw + randf_range(-1, 1) * sh * 0.05, sin(step_phase * 0.5) * 0.004 * clampf(speed_xz / 6.0, 0.0, 1.0))
