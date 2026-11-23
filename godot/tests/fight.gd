extends Node
## Auto-play: in each of the browser game's eight stages a bot fights as a person would, with no invincibility and nothing
## switched on in developer mode, through the game's own input handling only: the keyboard (W A S D, space, R, F, through
## Godot's Input as a real key press) and the mouse (movement to aim, the left button to fire, through the game's
## _unhandled_input). It turns onto the nearest enemy it can see at a hand's speed and fires once it is on it, side-steps
## while it fights, reloads when the magazine runs dry, injects an antidote when infected, and with nothing in sight walks
## the walking grid towards the nearest enemy. A stage passes when the bot has hit and killed and the enemies have hurt it.
## Run: godot --headless --path godot res://tests/fight.tscn

const STAGES := [1, 6, 5, 2, 3, 7, 8, 4]
const SECONDS := {8: 200.0}   # 3-2 lets its animals out one at a time, the first ones tame: it takes longer to be bitten
const SECONDS_ELSE := 80.0
const DT := 1.0 / 30.0
var fails := 0
var main
var keys := {}   # keycode -> held

func check(name: String, ok: bool, info = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ((" " + str(info)) if str(info) != "" else ""))
	if not ok: fails += 1

func _ready() -> void:
	main = load("res://main.tscn").instantiate(); add_child(main)
	# a player a few stages in: an AR-7 bought, a helmet and a whole vest. Nothing from developer mode, no invincibility
	Store.save = Store.save0(); Store.save.owned = ["rifle"]; Store.save.loadout = ["rifle", "pistol", null, null, null, null, null]
	Store.save.items.helmet = 1; Store.save.items.vest = 10; Store.fix_save()
	Store.settings.dev = false; Store.settings.god = false
	for st in STAGES: _fight(st)
	_toy_flame()
	print("ALL OK" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# ---- the hands: walking keys through Input (as the keyboard would; the game reads them each frame), the other keys and the
# mouse through the game's own input handler ----
const WALK := [KEY_W, KEY_A, KEY_S, KEY_D]
func _key(code: Key, down: bool) -> void:
	if keys.get(code, false) == down: return
	keys[code] = down
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = down
	if code in WALK: Input.parse_input_event(e); Input.flush_buffered_events()   # no frame passes between steps here, so let it through now
	else: main._unhandled_input(e)

func _tap(code: Key) -> void:
	_key(code, true); _key(code, false)

func _mouse_move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new(); e.relative = Vector2(dx, dy); main._unhandled_input(e)

var _held := false
func _fire(on: bool) -> void:
	if on == _held: return
	_held = on
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = on; main._unhandled_input(e)

func _let_go() -> void:
	for k in keys.keys(): _key(k, false)
	_fire(false)

# ---- one stage ----
func _fight(st: int) -> void:
	seed(7000 + st)   # the same fight every run
	main.command("start %d" % st); cur = null
	var pl = main.player; var g = main.game; var en = main.enemies
	if st == 7: main.command("stampede")   # 3-1: the siege, the fight that stage is for
	var hp0: float = pl.hp; var kills0: int = g.kills; var shots0: int = 0; var hits0: int = 0   # the stage starts its counts from nothing
	var hurt := false; var walked := 0.0; var last := Vector3(pl.pos); var stuck_t := 0.0; var path_t := 0.0; var path := Vector2.ZERO
	var side := KEY_A; var side_t := 0.0; var ticks := 0; var aim_err := 0.0; var aim_n := 0; var gave_up := ""
	for i in int(SECONDS.get(st, SECONDS_ELSE) / DT):
		if g.ended or main.state != "playing": break
		ticks += 1
		var eye: Vector3 = main.cam.global_position
		var t = _target(en, eye)
		if g.infected or g.poison_t > 0.0:
			if g.antidotes > 0 and not g.inject_on: _tap(KEY_F)
		if int(main.guns.st().mag) == 0: _tap(KEY_R)
		if t != null:
			var to: Vector3 = _aim_at(t) - eye
			var want_yaw := atan2(-to.x, -to.z); var want_pitch := asin(clampf(to.y / maxf(to.length(), 0.001), -1.0, 1.0))
			var dy: float = wrapf(want_yaw - pl.yaw, -PI, PI); var dp: float = want_pitch - pl.pitch
			_turn(pl, dy, dp)
			var err := Vector2(dy, dp).length(); aim_err += err; aim_n += 1
			_fire(err < clampf(0.7 * float(t.R) / maxf(to.length(), 0.5), 0.004, 0.05))   # only when the sight is on the body
			_key(KEY_W, to.length() > 26.0)   # close in on far ones
			side_t -= DT
			if side_t <= 0.0: side_t = 1.4; _key(side, false); side = KEY_D if side == KEY_A else KEY_A
			_key(side, true)
		else:
			_fire(false); _key(KEY_A, false); _key(KEY_D, false)
			path_t -= DT
			if path_t <= 0.0: path_t = 0.5; path = _path_to_nearest(en, pl)
			if path != Vector2.ZERO:
				var want := atan2(-path.x, -path.y); _turn(pl, wrapf(want - pl.yaw, -PI, PI), -pl.pitch)
				_key(KEY_W, true)
			else: _key(KEY_W, false)
		# stuck against something: jump
		if (pl.pos as Vector3).distance_to(last) < 0.02 and keys.get(KEY_W, false): stuck_t += DT
		else: stuck_t = 0.0
		if stuck_t > 0.6: _tap(KEY_SPACE); stuck_t = 0.0
		walked += Vector2(pl.pos.x - last.x, pl.pos.z - last.z).length(); last = Vector3(pl.pos)
		main.tick(DT)
		if pl.hp < hp0 - 0.5 or g.infected or g.poison_t > 0.0 or g.ended: hurt = true
	_let_go()
	var kills: int = g.kills - kills0; var shots: int = g.stats.shots - shots0; var hits: int = g.stats.hits - hits0
	var tag: String = Store.STAGE_TAG[st]
	check("stage %s: the bot walks, aims, fires and kills through the game's own input, and the enemies hurt it (no invincibility)" % tag,
		walked > 1.0 and shots > 0 and hits > 0 and kills > 0 and hurt and not Store.settings.god,
		{"seconds": snappedf(ticks * DT, 0.1), "walked": snappedf(walked, 0.1), "shots": shots, "hits": hits, "kills": kills, "hurt": hurt, "hp": snappedf(pl.hp, 1.0),
			"aim_error": snappedf(aim_err / maxi(aim_n, 1), 0.001), "ended": g.result if g.ended else ""})
	main.command("menu")

## stage 5's spray-can flamethrower (key 9) in hand: drawn, and no other toy gun (it once stopped the gun's posing every
## frame on a missing table entry, and the dart pistol stayed in your hands)
func _toy_flame() -> void:
	main.command("start 9")
	var g = main.guns; g.switch_slot(g.slots.find("flame"))
	for i in 30: main.tick(DT); main._pose_gun(DT)
	var others: Array = main.toy_models.keys().filter(func(k): return k != "flame" and (main.toy_models[k] as Node3D).visible)
	check("stage 5: the spray-can flamethrower in hand is the toy drawn, and no other", g.cur == "flame" and (main.toy_models.flame as Node3D).visible and others.is_empty(), [g.cur, others])
	main.command("menu")

## at a hand's speed: no more than about 6 radians a second, as mouse movement in pixels
func _turn(pl, dyaw: float, dpitch: float) -> void:
	var s: float = pl.sens * 0.0021 * pl.sens_mul
	var lim := 6.0 * DT
	_mouse_move(-clampf(dyaw, -lim, lim) / s, -clampf(dpitch, -lim, lim) / s)

## what to shoot: the one it is on already while it lives and is in sight, else of those in sight within 70 m the one
## nearest, an enemy's toughness counting as distance (an elephant is left until the smaller ones are down)
var cur = null
func _target(en, eye: Vector3):
	if cur != null and cur.alive and not cur.ridden and not cur.tamed and not cur.caged and eye.distance_to(_aim_at(cur)) < 70.0 and Phys.line_of_sight(eye, _aim_at(cur)): return cur
	var best = null; var bs := INF
	for e in en.list:
		if not e.alive or e.ridden or e.tamed or e.caged: continue   # nothing still shut in a cage
		var p := _aim_at(e); var d := eye.distance_to(p)
		var sc: float = d + float(e.hp) / 60.0 - (30.0 if e.downed else 0.0)   # a dropped zombie first, before it rises
		if d < 70.0 and sc < bs and Phys.line_of_sight(eye, p): best = e; bs = sc
	cur = best
	return best

## where a person would aim: the middle of the body; a zombie that has dropped, at the body lying on the ground (it has to be
## shot again within 3 seconds or it gets back up)
func _aim_at(e) -> Vector3:
	if e.fly: return Vector3(e.pos)
	if e.downed: return Vector3(e.pos) + Vector3(sin(e.yaw), 0, cos(e.yaw)) * float(e.fall_dir) * 0.9 + Vector3(0, 0.25, 0)
	return Vector3(e.pos.x, e.pos.y + e.H * 0.6, e.pos.z)

## which way to walk to reach the nearest living enemy: the walking grid's flow from that enemy, read where the bot stands
## (the grid is put back to flow towards the player straight after, as the enemies use it)
func _path_to_nearest(en, pl) -> Vector2:
	var best = null; var bd := INF
	for e in en.list:
		if not e.alive or e.ridden or e.tamed or e.caged: continue
		var d: float = Vector2(e.pos.x - pl.pos.x, e.pos.z - pl.pos.z).length()
		if d < bd: best = e; bd = d
	if best == null: return Vector2.ZERO
	Phys.update_flow(best.pos.x, best.pos.z); var f: Vector2 = Phys.flow_dir(pl.pos.x, pl.pos.z); Phys.update_flow(pl.pos.x, pl.pos.z)
	if f == Vector2.ZERO: f = Vector2(best.pos.x - pl.pos.x, best.pos.z - pl.pos.z).normalized()
	return f
