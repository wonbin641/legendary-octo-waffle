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

## dmg from a point; the zone ('head', 'body', 'fire') matters once helmets and vests are in
func hurt(dmg: float, from: Vector3, _zone := "body") -> void:
	if invuln > 0.0 or hp <= 0.0: return
	dmg = maxf(1.0, roundf(dmg)); hp = maxf(0.0, hp - dmg); since_hurt = 0.0; shake = maxf(shake, 0.1 + dmg * 0.008)
	if on_hurt.is_valid(): on_hurt.call(dmg, from)

func reset(x: float, z: float, yaw_: float) -> void:
	pos = Vector3(x, 0, z); vel = Vector3.ZERO; yaw = yaw_; pitch = 0.0; grounded = true
	jump_buf = 0.0; sprint_lock = 0.0; shake = 0.0; land_dip = 0.0; recoil_pitch = 0.0; look_dx = 0.0; look_dy = 0.0
	hp = MAX_HP; invuln = 0.0; ads = 0.0

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
	var speed := (8.2 if sprinting else 5.4) * move_mul * ads_slow
	var sy := sin(yaw); var cy := cos(yaw)
	var tx := (-sy * f + cy * sd) * speed; var tz := (-cy * f - sy * sd) * speed
	var acc := 1.0 - exp(-dt * (11.0 if grounded else 2.2))
	vel.x += (tx - vel.x) * acc; vel.z += (tz - vel.z) * acc
	jump_buf -= dt
	if jump_buf > 0.0 and grounded: vel.y = 6.6; grounded = false; jump_buf = 0.0
	vel.y -= 19.0 * dt
	pos = Phys.move_xz(pos, vel.x * dt, vel.z * dt, R, HEIGHT, 0.5 if grounded else 0.2)[0]
	pos.x = clampf(pos.x, -Phys.HALF + R, Phys.HALF - R); pos.z = clampf(pos.z, -Phys.HALF + R, Phys.HALF - R)
	var gy := Phys.ground_at(pos.x, pos.y, pos.z, R)
	pos.y += vel.y * dt
	if vel.y > 0.0:
		var c := Phys.ceil_at(pos.x, pos.y - vel.y * dt, pos.z, R, HEIGHT)
		if pos.y + HEIGHT > c: pos.y = c - HEIGHT; vel.y = 0.0
	if pos.y <= gy:
		if not grounded and vel.y < -5.0: land_dip = clampf(-vel.y * 0.012, 0.0, 0.12)
		pos.y = gy; vel.y = 0.0; grounded = true
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
