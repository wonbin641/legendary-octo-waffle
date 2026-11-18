class_name Guns
extends RefCounted
## Firing, reloading, switching, the jab and the machine gun's heat: ported from src/06b_fire.js.

var player: Player
var cam: Camera3D
var world: World
var enemies: Enemies
var fx: Fx
var proj: Proj
var look_mode := "lock"
var auto_fire := false       # touch: the gun fires by itself when the crosshair is on an enemy or a crate within 12 m
var auto_jab := false        # touch: a crate that comes within the jab's reach is jabbed by itself
var stage := 1
var base_fov := 74.0
var time := 0.0
var hint: Callable = Callable(); var banner: Callable = Callable(); var hitmark: Callable = Callable()

var cur := "pistol"
var slots: Array = ["pistol"]
var loadout: Array = ["pistol", null, null, null, null, null, null]
var none := false
var busy := 0.0
var cooldown := 0.0
var reload_t := 0.0
var reload_half := false
var switch_t := 0.0
var pending = null
var ads := 0.0
var ads_held := false
var bloom := 0.0
var kick_z := 0.0
var kick_rot := 0.0
var flash_t := 0.0
var trigger := false
var trigger_edge := false
var wstate := {}
var shots := 0
var hits := 0
var _pump_t := -1.0
var _auto_reload_t := -1.0
var _auto_reload_for = null
var toy := false           # stage 5: the guns are toys (their own sounds and effects)
var since_shot := 9.0
var _reload_f := 0.0
var auto_reload := true   # an emptied gun reloads by itself a quarter of a second later
var lock_to := ""         # stage 5's battery in your arms: only this gun (the dart pistol) and the jab
# the jab
var melee_on := false
var melee_t := 0.0
var melee_cd := 0.0
var _melee_hit := false
var _melee_target = null

func _init() -> void:
	for id in Weapons.all_ids(): wstate[id] = {"mag": Custom.weapon(id).mag, "reserve": Custom.weapon(id).reserve, "heat": 0.0, "hot": false, "hot_t": 0.0, "cool_t": 0.0, "smoke_t": 0.0}

func w() -> Dictionary: return Custom.weapon(cur)   # the gun as you have built it (parts change its numbers)
func st() -> Dictionary: return wstate[cur]
func _say(c: Callable, a: Array) -> void:
	if c.is_valid(): c.callv(a)

## refill every gun and take the first one in the layout, at the start of a stage
func reset(layout: Array) -> void:
	for id in Weapons.all_ids():
		wstate[id].mag = Custom.weapon(id).mag; wstate[id].reserve = Custom.weapon(id).reserve
		wstate[id].heat = 0.0; wstate[id].hot = false; wstate[id].smoke_t = 0.0; wstate[id].cool_t = 0.0
	since_shot = 9.0; _reload_f = 0.0; shots = 0; hits = 0   # the result sheet's accuracy is this stage's alone, as the browser game's
	cooldown = 0.0; reload_t = 0.0; switch_t = 0.0; pending = null; ads = 0.0; ads_held = false; bloom = 0.0; kick_z = 0.0; kick_rot = 0.0; flash_t = 0.0
	trigger = false; trigger_edge = false; melee_on = false; melee_t = 0.0; melee_cd = 0.0; _melee_target = null; _pump_t = -1.0; _auto_reload_t = -1.0
	loadout = layout.duplicate(); slots = loadout.filter(func(x): return x != null); none = slots.is_empty(); lock_to = ""
	cur = slots[0] if not none else "pistol"

func muzzle() -> Vector3:
	var b := cam.global_basis
	return cam.global_position + (-b.z) * 0.7 + b.x * 0.16 * (1.0 - ads) + b.y * (-0.12 * (1.0 - ads) - 0.03 - 0.06 * ads)

func current_spread() -> float:
	var W := w(); var mv := clampf(player.speed_xz / 6.0, 0.0, 1.4)
	var s: float = lerpf(W.spread, W.adsSpread, ads) + bloom + W.moveSpread * mv * (1.0 - ads * 0.6)
	if not player.grounded: s += 0.03
	return s

## the rocket's lock: the living enemy nearest the middle of the screen, within about 10 degrees, 200 m and in sight
func rocket_lock():
	var f := -cam.global_basis.z; var o := cam.global_position; var best = null; var best_a := 0.18
	for e in enemies.list:
		if not e.alive: continue
		var c: Vector3 = proj.rocket_centre(e); var v := c - o; var d := v.length()
		if d < 2.5 or d > 200.0: continue
		var a := acos(clampf(v.dot(f) / d, -1.0, 1.0))
		if a >= best_a or not Phys.line_of_sight(o, c): continue
		best = e; best_a = a
	return best

# ---------- the jab: V or the mouse's back button; 120 to the body, twice that to the head; it breaks crates ----------
func melee_start(target = null) -> void:
	if melee_cd > 0.0 or none or busy > 0.0 or switch_t > 0.0 or player.out: return
	melee_on = true; melee_t = 0.0; melee_cd = 0.62; _melee_hit = false; _melee_target = target
	reload_t = 0.0; trigger = false; ads_held = false
	Snd.play("swing")

## touch: a crate within the jab's reach and not behind you, while you are not busy with anything else, is jabbed by itself
func _auto_crate() -> void:
	if not auto_jab or melee_on or melee_cd > 0.0 or none or busy > 0.0 or reload_t > 0.0 or switch_t > 0.0 or trigger or ads_held or ads > 0.05: return
	if not player.grounded or player.jet_on: return
	var o := cam.global_position; var fx_ := -sin(player.yaw); var fz := -cos(player.yaw); var best = null; var bd := Weapons.MELEE_REACH
	for c in world.crates:
		if c.dead or c.get("wall", false): continue   # crates only, not a brick figure's wall
		var b: Phys.Box = c.b
		var q := Vector3(clampf(o.x, b.minx, b.maxx), clampf(o.y, b.miny, b.maxy), clampf(o.z, b.minz, b.maxz)); var d := q.distance_to(o)
		var dx: float = c.x - player.pos.x; var dz: float = c.z - player.pos.z; var h := maxf(sqrt(dx * dx + dz * dz), 0.0001)
		if d < bd and (dx * fx_ + dz * fz) / h > 0.35: best = c; bd = d  # within about 70 degrees of straight ahead
	if best != null: melee_start(best)

func _melee_update(dt: float) -> void:
	melee_cd = maxf(0.0, melee_cd - dt)
	if not melee_on: return
	melee_t += dt
	if not _melee_hit and melee_t >= 0.11: _melee_hit = true; _melee_strike()
	if melee_t >= Weapons.MELEE_T: melee_on = false

## a fan of short rays: the nearest body in reach wins (a head over a body at the same distance), else a crate
func _melee_strike() -> void:
	if _melee_target != null:
		var c = _melee_target; _melee_target = null
		if c.dead: return
		var at := Vector3(c.x, c.y + 0.6, c.z); world.damage_crate(c, 60, at); Snd.play("toy_ruler" if toy else "melee", 1.0, at); Snd.buzz(20); return
	var b := cam.global_basis; var f := -b.z; var o := cam.global_position; var best = null
	for ab in [[0, 0], [0.16, 0], [-0.16, 0], [0, -0.15], [0, 0.12], [0.3, -0.12], [-0.3, -0.12], [0, -0.32]]:
		var d: Vector3 = (f + b.x * ab[0] + b.y * ab[1]).normalized()
		Phys.raycast_static(o, d, Weapons.MELEE_REACH)
		var s_t := Phys.rh_t; var s_box := Phys.rh_box; var eh = enemies.raycast(o, d, s_t)
		if eh != null:
			if best == null or best.has("crate") or eh.t < best.t - 0.15 or (eh.weak and not best.weak and eh.t < best.t + 0.15):
				best = {"e": eh.enemy, "t": eh.t, "weak": eh.weak, "mult": eh.mult, "bomb": eh.get("bomb", false), "d": d}
		elif best == null and s_box != null and s_box.kind == "wood" and s_box.ref != null and s_t < Weapons.MELEE_REACH: best = {"crate": s_box.ref, "t": s_t, "d": d}
	if best == null: return
	var hit: Vector3 = o + best.d * best.t
	if best.has("crate"): world.damage_crate(best.crate, 60, hit); Snd.play("toy_ruler" if toy else "melee", 1.0, hit); Snd.buzz(20); return
	var e = best.e; var killed := false
	if best.bomb and e.alive: enemies.blow_vest(e, best.d); killed = true
	else: killed = enemies.damage(e, Weapons.MELEE_DMG * (2.0 if best.weak else float(best.mult)), hit, best.d, best.weak)
	if e.alive and not e.boss: e.vel.x += best.d.x * 4.0; e.vel.z += best.d.z * 4.0   # and a shove
	_say(hitmark, [killed, best.weak]); Snd.play("melee_metal" if e.robot else "melee", 1.0, hit); player.shake = maxf(player.shake, 0.12); Snd.buzz(30)

# ---------- the machine gun's heat: every shot adds 1/240; empty a full box in one go and it overheats ----------
func _heat_shot(W: Dictionary, s: Dictionary) -> void:
	s.heat = minf(1.0, s.heat + 1.0 / W.mag); s.cool_t = 0.3
	if s.mag == 0 and s.heat >= 0.97:
		s.hot = true; s.hot_t = 0.0; Snd.play("hiss"); Snd.buzz(120)
		_say(banner, ["기관총 과열", "연기가 납니다 · 다른 총으로 바꾼 뒤에 재장전할 수 있습니다", 2.6])

func _heat_update(dt: float) -> void:
	var s: Dictionary = wstate.lmg
	if s.hot:
		s.hot_t += dt
		# swapping away is what lets it be reloaded again; with nothing to swap to, it gives in by itself after a while
		if (cur != "lmg" and pending == null) or (slots.size() < 2 and s.hot_t > 6.0): s.hot = false
	else:
		s.cool_t -= dt
		if s.cool_t <= 0.0: s.heat = maxf(0.0, s.heat - dt * 0.2)
	s.smoke_t = 2.5 if s.hot else maxf(0.0, s.smoke_t - dt)

# ---------- firing ----------
func fire() -> void:
	var W := w(); var s := st()
	if none or busy > 0.0 or melee_on or switch_t > 0.0 or reload_t > 0.0 or cooldown > 0.0 or player.out: return
	if player.sprinting: player.sprint_lock = 0.25
	if s.mag <= 0:
		Snd.play("empty"); cooldown = 0.3
		if s.reserve > 0: start_reload()
		else: _say(hint, ["탄약 없음 · 상점에서 채우거나 다른 총으로", 2.0])
		return
	s.mag -= 1; cooldown = W.rate; shots += 1; since_shot = 0.0; var hit_snd := false
	if W.get("heat", false): _heat_shot(W, s)
	enemies.noise(cam.global_position, 42.0 * float(W.get("noise", 1.0)))   # a suppressor carries less far
	var spr := current_spread(); var muz := muzzle()
	var b := cam.global_basis; var f := -b.z; var right := b.x; var up := b.y; var o := cam.global_position
	if look_mode == "touch" and not W.get("grenade", false) and not W.get("rocket", false):
		var ad = enemies.assist(o, f, 0.03 if ads > 0.5 else 0.045, W.range)
		if ad != null: f = ad
	var hit_any := false; var killed := false; var head := false
	if W.get("grenade", false):
		var a := randf() * TAU; var rr := sqrt(randf()) * spr
		proj.grenade(muz, (f + right * cos(a) * rr + up * (sin(a) * rr + 0.05)).normalized(), W)
	elif W.get("rocket", false):
		# the rocket takes the enemy nearest the crosshair with it; with nothing marked it flies straight
		proj.rocket(muz, (f + up * 0.01).normalized(), W, rocket_lock())
	else:
		for k in int(W.pellets):
			var a := randf() * TAU; var rr := sqrt(randf()) * spr
			var d := (f + right * cos(a) * rr + up * sin(a) * rr).normalized()
			var s_hit := Phys.raycast_static(o, d, W.range)
			var s_t := Phys.rh_t; var s_box := Phys.rh_box; var s_n := Phys.rh_n
			var eh = enemies.raycast(o, d, s_t)
			if eh != null:
				var at: Vector3 = o + d * eh.t
				var dmg: float = W.dmg * ((eh.enemy.head_x if eh.enemy.head_x > 0.0 else float(W.head)) if eh.weak else float(eh.mult))
				if W.has("falloff"): dmg *= lerpf(1.0, 0.35, clampf((eh.t - W.falloff[0]) / (W.falloff[1] - W.falloff[0]), 0.0, 1.0))
				if eh.get("bomb", false) and eh.enemy.alive: enemies.blow_vest(eh.enemy, d); killed = true
				elif enemies.damage(eh.enemy, dmg, at, d, eh.weak): killed = true
				hit_any = true
				if eh.weak: head = true
				if toy: hit_snd = _toy_hit(muz, at, k, hit_snd)
				elif k < 3 and fx: fx.tracer(muz, at)
			else:
				var at := o + d * s_t
				if s_hit and s_box != null and s_box.kind == "wood" and s_box.ref != null: world.damage_crate(s_box.ref, W.dmg, at)
				if s_hit and k < 4 and s_box != null and s_box.kind == "metal" and randf() < 0.5: Snd.play("metal", 1.0, at)
				if s_hit and k < 4 and fx and not toy:   # where it struck: sparks (more off metal), a little dust (more off concrete)
					fx.sparks(at, 6 if (s_box != null and s_box.kind == "metal") else 3, [0.9, 0.7, 0.45] if (s_box != null and s_box.kind == "wood") else [1.0, 0.78, 0.45], 3.2)
					fx.puff(at, 1, 0.5 if (s_box != null and s_box.kind == "concrete") else 0.3, 0.25)
				if s_hit and fx and not toy: fx.decal(at, s_n)
				if toy:
					if W.get("flame", false):
						if k == 0 and fx: fx.flame(muz, d)
					else: hit_snd = _toy_hit(muz, at, k, hit_snd if s_hit else true)
				elif k < 3 and fx: fx.tracer(muz, at)
	if hit_any: hits += 1; _say(hitmark, [killed, head])
	var rk: float = W.recoil * (1.0 - ads * 0.35)
	player.recoil_pitch += rk; player.pitch += rk * 0.55; player.yaw += randf_range(-1, 1) * rk * 0.35
	kick_z += W.kick; kick_rot += W.kick * 1.6; bloom = minf(bloom + W.bloom, 0.05); flash_t = 0.045
	Snd.play(("toy_shot_" + cur) if toy else ("shot_" + W.sound))
	if not toy and fx and ads < 0.5: fx.glow(muz, f * 2.0 + Vector3(0, 0.4, 0), 0.5, 0.05, 0.18, Color(0.35, 0.33, 0.32, 0.35), -0.5, 3.0)   # gun smoke (none down the sights)
	if toy and fx:
		if cur == "smg": fx.smoke(muz)
		if cur == "rocket": for i in 6: fx.spark(muz)
	if W.pellets > 1 or W.get("scope", false): _pump_t = 0.52 if W.get("scope", false) else 0.28
	if auto_reload and s.mag == 0 and s.reserve > 0: _auto_reload_t = 0.26; _auto_reload_for = cur
	player.shake = maxf(player.shake, 0.18 if (W.pellets > 1 or W.get("scope", false)) else 0.05)

## what a toy's shot looks and sounds like where it lands; returns whether the landing sound has been played for this shot
func _toy_hit(muz: Vector3, at: Vector3, k: int, played: bool) -> bool:
	if fx:
		match cur:
			"rifle": fx.streak(muz, at, Color(1.0, 0.55, 0.1, 0.9), 0.03, 0.09); fx.tap(at, Color(1.0, 0.6, 0.2, 0.7))
			"shotgun":
				fx.streak(muz, at, Color(0.5, 0.75, 1.0, 0.55), 0.035, 0.12)
				if k < 4: fx.splash(at)
			"sniper": fx.streak(muz, at, Color(1, 1, 1, 0.8), 0.012, 0.1); fx.tap(at, Color(1, 0.3, 0.3, 0.8))
			"smg": fx.streak(muz, at, Color(1.0, 0.9, 0.6, 0.6), 0.012, 0.05)
			"lmg": fx.streak(muz, at, Color(1.0, 0.85, 0.3, 0.9), 0.016, 0.07)
			"pistol": fx.streak(muz, at, Color(1.0, 0.4, 0.3, 0.9), 0.025, 0.1); fx.tap(at, Color(1, 0.4, 0.3, 0.7))
	if not played and ResourceLoader.exists("res://sounds/toy_hit_%s.wav" % cur): Snd.play("toy_hit_" + cur, 1.0, at)
	return true

func start_reload() -> void:
	var W := w(); var s := st()
	if W.get("heat", false) and s.hot: _say(hint, ["기관총이 과열됐습니다 · 다른 총으로 바꾼 뒤에 재장전하세요", 2.0]); return
	if none or busy > 0.0 or melee_on or reload_t > 0.0 or switch_t > 0.0 or s.mag >= W.mag or s.reserve <= 0: return
	reload_t = W.reload; reload_half = false; _reload_f = 0.0
	if not toy: Snd.play("reload0")

func _finish_reload() -> void:
	var W := w(); var s := st()
	var take: float = minf(W.mag - s.mag, s.reserve)
	s.mag += int(take)
	if s.reserve != INF: s.reserve -= int(take)

func switch_to(id) -> void:
	if lock_to != "" and id != lock_to and id != null:
		_say(hint, ["건전지를 든 동안은 다트 권총과 30cm 자만 쓸 수 있습니다", 1.6]); return
	if id == null or not slots.has(id) or id == cur or switch_t > 0.0 or busy > 0.0: return
	reload_t = 0.0; pending = id; switch_t = 0.36; Snd.play("reload0")

## straight to this gun, whatever you were doing with the one in hand (the battery comes into your arms)
func force_to(id: String) -> void:
	if not slots.has(id): return
	melee_on = false; reload_t = 0.0; trigger = false; ads_held = false
	if cur == id and pending == null: return
	pending = id; switch_t = 0.36; Snd.play("reload0")

func switch_slot(i: int) -> void:
	if i < loadout.size(): switch_to(loadout[i])

func cycle(step: int) -> void:
	var n := slots.size()
	if n < 2: return
	var at := slots.find(pending if pending != null else cur)
	switch_to(slots[(at + step + n) % n])

func update(dt: float) -> void:
	time += dt; since_shot += dt
	var W := w()
	_auto_crate(); _melee_update(dt); _heat_update(dt)
	cooldown = maxf(0.0, cooldown - dt)
	bloom = maxf(0.0, bloom - dt * (0.02 if (trigger and W.auto) else 0.09))
	if _pump_t > 0.0:
		_pump_t -= dt
		if _pump_t <= 0.0: Snd.play(("toy_stretch" if cur == "sniper" else "toy_pump") if toy else "pump")
	if _auto_reload_t > 0.0:
		_auto_reload_t -= dt
		if _auto_reload_t <= 0.0 and _auto_reload_for == cur and st().mag == 0: start_reload()
	if look_mode == "touch" and auto_fire and not W.get("grenade", false) and not W.get("rocket", false) and not trigger and cooldown <= 0.0 and reload_t <= 0.0 and switch_t <= 0.0 and st().mag > 0 and not player.sprinting:
		var f := -cam.global_basis.z; var o := cam.global_position
		var reach: float = W.falloff[1] if W.has("falloff") else minf(W.range, 70.0)
		# a wooden crate under the crosshair too, but only within 12 m (farther off, the shots woke the area and used rented ammo)
		var wall := Phys.raycast_static(o, f, reach)
		var crate: bool = wall and Phys.rh_box != null and Phys.rh_box.kind == "wood" and Phys.rh_box.ref != null and not Phys.rh_box.ref.dead and not Phys.rh_box.ref.get("wall", false) and Phys.rh_t <= Weapons.CRATE_AUTO_RANGE
		enemies.skip_calm = true
		var sees: bool = enemies.raycast(o, f, Phys.rh_t) != null or enemies.assist(o, f, 0.035, reach) != null
		enemies.skip_calm = false
		if sees or crate: fire()
	if trigger and (W.auto or trigger_edge): fire(); trigger_edge = false
	if reload_t > 0.0:
		reload_t -= dt
		if toy:   # each step of a toy's reload has its own sound
			var f: float = 1.0 - reload_t / float(W.reload)
			for st in Toys.RELOAD_SND.get(cur, []):
				if _reload_f <= st[0] and f > st[0]: Snd.play(st[1])
			_reload_f = f
		elif not reload_half and reload_t < W.reload * 0.45: reload_half = true; Snd.play("reload1")
		if reload_t <= 0.0: reload_t = 0.0; _finish_reload()
	if switch_t > 0.0:
		var before := switch_t; switch_t -= dt
		if before > 0.18 and switch_t <= 0.18 and pending != null: cur = pending; pending = null; cooldown = 0.1
		if switch_t < 0.0: switch_t = 0.0
	W = w()
	var want_ads := ads_held and reload_t <= 0.0 and switch_t <= 0.0 and not player.sprinting and busy <= 0.0 and not melee_on
	var sp: float = W.get("adsSpeed", 7.0)  # a light SMG comes up to the eye fast, the heavy machine gun slowly
	ads = clampf(ads + (dt * sp if want_ads else -dt * sp), 0.0, 1.0)
	var a := ads * ads * (3.0 - 2.0 * ads)
	if cam: cam.fov = lerpf(base_fov, W.adsFov * (1.0 if W.get("scope", false) else base_fov / 74.0), a)
	kick_z *= exp(-dt * 14); kick_rot *= exp(-dt * 12)
	if flash_t > 0.0: flash_t -= dt
	# what the player's legs and eyes need to know about the gun
	player.move_mul = W.moveMul; player.ads = ads
	player.ads_slow = (0.4 if W.get("scope", false) else 0.6) if ads > 0.5 else 1.0
	player.sens_mul = ((cam.fov / base_fov if cam else 1.0) if W.get("scope", false) else 0.62) if ads > 0.5 else 1.0
	player.no_sprint = ads_held or trigger or reload_t > 0.0

func scoped() -> bool:
	return w().get("scope", false) and ads > 0.6
