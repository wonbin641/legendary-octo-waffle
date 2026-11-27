class_name Proj
extends Node3D
## Things that fly: the player's 40 mm grenades and guided rockets (ported from src/07b_ai.js; the enemies' rounds join in stage 4).

var player: Player
var world: World
var enemies: Enemies
var fx: Fx
var stage := 1
var hitmark: Callable = Callable()
var tm = null   # stage 5's team modes: the ToyMatch (whose toys the enemies' rounds and ours can hit)
var on_wet: Callable = Callable()   # (stage 5: a toy's water gun has hit you: water on the glass)
var list: Array = []

func _mesh(scale_: Vector3, color: String) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.radial_segments = 8; s.rings = 6; m.mesh = s
	m.material_override = Gfx.std(World.lin(color), 0.6, 0.3); m.scale = scale_; add_child(m)
	return m

## the 40 mm grenade: arcs, arms after 8 m, explodes on impact
func grenade(from: Vector3, dir: Vector3, W: Dictionary) -> void:
	list.push_back({"kind": "grenade", "pos": from, "src": from, "vel": dir * 40.0, "dmg": float(W.dmg), "radius": float(W.splash), "life": 6.0, "bounced": false, "m": _mesh(Vector3.ONE * 0.05, "3d4430")})

## the guided rocket: a short straight boost, then it steers after the enemy it locked when fired (at most 3 rad a second)
func rocket(from: Vector3, dir: Vector3, W: Dictionary, target) -> void:
	list.push_back({"kind": "rocket", "pos": from, "src": from, "speed": 24.0, "vel": dir * 24.0, "dmg": float(W.dmg), "radius": float(W.splash), "splash_dmg": float(W.get("splashDmg", W.dmg * 0.5)),
		"life": 7.0, "age": 0.0, "target": target, "m": _mesh(Vector3(0.055, 0.055, 0.32), "59603f")})

## an enemy's pistol round: fast, a visible tracer; it hurts you where it strikes (above the shoulders is the head)
## an enemy's round. team: "them" (the enemies': it hits you, and in stage 5's team modes our blue soldiers too) or "us"
## (one of our soldiers': it hits the room's toys, and a trap on the train's track)
var _bullet_box: BoxMesh = null
## gun: what fired it, where that shows on whom it hits ("shotgun": stage 5's pump water gun soaks them)
func bullet(from: Vector3, target: Vector3, speed: float, dmg: float, spread_r: float, team := "them", gun := "") -> void:
	var v := Vector3(target.x + randf_range(-1, 1) * spread_r - from.x, target.y + randf_range(-0.7, 0.7) * spread_r - from.y, target.z + randf_range(-1, 1) * spread_r - from.z).normalized() * speed
	if _bullet_box == null: _bullet_box = BoxMesh.new(); _bullet_box.size = Vector3(0.03, 0.03, 0.55)   # (one mesh for every bullet)
	var m := MeshInstance3D.new(); m.mesh = _bullet_box; m.material_override = _ally_mat() if team == "us" else _bullet_mat(); m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(m)
	m.look_at_from_position(from, from + v, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
	list.push_back({"kind": "bullet", "pos": from, "src": from, "vel": v, "dmg": dmg, "life": 2.0, "whiz": false, "m": m, "team": team, "gun": gun})
	if fx and stage != Store.ST_TOY: fx.glow(from, Vector3.ZERO, 0.08, 0.45, 0.1, Color(1, 0.8, 0.5, 0.9))   # the flash at his muzzle

var _amat: Material
func _ally_mat() -> Material:   # our soldiers' rounds: blue
	if _amat == null:
		var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.albedo_color = Color(0.45, 0.7, 1.0); mm.disable_fog = true; _amat = mm
	return _amat

var _bmat: Material
func _bullet_mat() -> Material:
	if _bmat == null:
		var m := Gfx.unlit(Color(1.0, 0.85, 0.63), false); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_bmat = Gfx.see_through(m)
	return _bmat

## enemy grenades: 'gl' rounds burst on impact, thrown 'nade's bounce and go off after a fuse
func egrenade(from: Vector3, target: Vector3, mode: String) -> void:
	var dx := target.x - from.x; var dz := target.z - from.z; var d := sqrt(dx * dx + dz * dz); var T := 0.55 + d / 30.0 if mode == "gl" else 0.8 + d / 20.0
	list.push_back({"kind": "egren", "mode": mode, "pos": from, "src": from, "vel": Vector3(dx / T, (target.y - from.y + 0.5 * 9.8 * T * T) / T, dz / T), "life": 6.0 if mode == "gl" else 2.7, "fuse": 2.6, "beeps": 0,
		"m": _mesh(Vector3.ONE * (0.07 if mode == "gl" else 0.09), "4a5236")})
	Snd.play("thump", 1.0, from)

## a vest going off where a man fell, after a moment
func bomb(at: Vector3, delay: float) -> void:
	var m := _mesh(Vector3.ONE * 0.01, "4a5236"); m.visible = false
	list.push_back({"kind": "bomb", "pos": Vector3(at.x, at.y + 1.0, at.z), "src": at, "vel": Vector3.ZERO, "life": delay, "m": m}); Snd.play("beep", 1.0, at)

## a blast from the enemy side: hurts you by distance, wrecks crates; the vest also takes other men with it
func blast(c: Vector3, radius: float, dmg: float, hits_enemies: bool) -> void:
	if fx:
		fx.explode(c, true)
		if radius > 6.0: fx.explode(c + Vector3(0.8, 0.3, -0.5), true); fx.chunks(c, 10, 0.2, "metal")
	Snd.play("boom", 1.0, c); enemies.noise(c, 50)
	var body := Vector3(player.pos.x, player.pos.y + 0.9, player.pos.z); var d := c.distance_to(body)
	player.shake = maxf(player.shake, clampf(0.9 - d * 0.04, 0.0, 0.9))
	if d < radius and Phys.line_of_sight(c, Vector3(player.pos.x, player.pos.y + 1.2, player.pos.z)): player.hurt(dmg * (1.0 - d / radius), c, "body")
	_crates_near(c, radius)
	if hits_enemies: enemies.splash(c, radius, dmg)

func rocket_centre(e) -> Vector3:
	return Vector3(e.pos.x, e.pos.y + (0.0 if e.fly else e.H * 0.55), e.pos.z)

func _crates_near(c: Vector3, radius: float) -> void:
	for cr in world.crates.duplicate():
		if not cr.dead and Vector3(cr.x, cr.y + 0.6, cr.z).distance_to(c) < radius: world.damage_crate(cr, 100, Vector3(cr.x, cr.y + 0.6, cr.z))

func _rocket_hit(p: Dictionary, e) -> void:
	var c: Vector3 = p.pos
	if stage == Store.ST_TOY:   # a bottle rocket: a pop of coloured stars
		if fx: fx.firework(c)
		Snd.play("toy_boom", 1.0, c); Music.blast(c)
	else:
		if fx: fx.explode(c, true); fx.explode(c + Vector3(0.5, 0.4, -0.4), true)
		Snd.play("boom", 1.0, c)
	enemies.noise(c, 70)
	player.shake = maxf(player.shake, clampf(0.7 - c.distance_to(player.pos) * 0.02, 0.0, 0.7))
	if e != null and e.alive and hitmark.is_valid():
		enemies.blast = true; var fell: bool = enemies.damage(e, p.dmg, c, (p.vel as Vector3).normalized(), false); enemies.blast = false   # (the rocket's own hit is a blast's too)
		hitmark.call(fell, false)
	enemies.splash(c, p.radius, p.splash_dmg, e)
	_crates_near(c, p.radius)
	# the blast does not spare you either: 35-100% of 500 inside 6 m, nothing through a wall
	var body := Vector3(player.pos.x, player.pos.y + 0.9, player.pos.z); var pd := c.distance_to(body); var pr: float = p.radius + Player.R
	if pd < pr and Phys.line_of_sight(c, body): player.hurt(roundf(p.splash_dmg * (0.35 + 0.65 * (1.0 - pd / pr))), c, "body")

func _explode(p: Dictionary) -> void:
	var c: Vector3 = p.pos
	if fx: fx.explode(c, true)
	Snd.play("boom", 1.0, c); enemies.noise(c, 60)
	if stage == Store.ST_TOY: Music.blast(c)   # (the toy room's music: the tape stretches)
	player.shake = maxf(player.shake, clampf(0.5 - c.distance_to(player.pos) * 0.02, 0.0, 0.5))
	enemies.splash(c, p.radius, p.dmg)
	_crates_near(c, p.radius)
	var d := c.distance_to(Vector3(player.pos.x, player.pos.y + 0.9, player.pos.z))
	if d < p.radius and stage == 1: player.hurt(p.dmg * 0.35 * (1.0 - d / p.radius), c, "body")

func update(dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]; p.life -= dt; var dead := false
		if p.kind == "rocket":
			p.age += dt; p.speed = minf(58.0, p.speed + 70.0 * dt)
			var rd: Vector3 = (p.vel as Vector3).normalized(); var t = p.target
			if t != null and t.alive and p.age > 0.1:
				var want: Vector3 = (rocket_centre(t) - p.pos).normalized(); var ang := rd.angle_to(want); var max_a := 3.0 * dt
				if ang > 1e-4: rd = rd.lerp(want, minf(1.0, max_a / ang)).normalized()
			p.vel = rd * p.speed
			var steps := maxi(2, ceili(p.speed * dt / 0.35))
			for s in steps:
				if dead: break
				p.pos += p.vel * (dt / steps); var hit_e = null
				for e in enemies.list:
					if not e.alive: continue
					if e.fly:
						if (e.pos as Vector3).distance_to(p.pos) < e.R + 0.3: hit_e = e; break
						continue
					if p.pos.y < e.pos.y - 0.1 or p.pos.y > e.pos.y + e.H + 0.2: continue
					if Vector2(e.pos.x - p.pos.x, e.pos.z - p.pos.z).length() < e.R * 0.95 + 0.25: hit_e = e; break
				if hit_e != null or p.pos.y <= Phys.floor_y(p.pos.x, p.pos.z) + 0.05 or Phys.collide_at(p.pos.x, p.pos.y - 0.06, p.pos.z, 0.06, 0.12) != null: _rocket_hit(p, hit_e); dead = true
			if not dead and stage != Store.ST_TOY and fx: fx.puff(p.pos, 1, 0.75, 0.32); fx.glow(p.pos - rd * 0.3, Vector3.ZERO, 0.07, 0.35, 0.1, Color(1, 0.6, 0.25, 0.9))   # smoke and the tail of fire
			if not dead and p.life <= 0.0: _rocket_hit(p, null); dead = true
			if not dead and stage == Store.ST_TOY and fx: fx.spark(p.pos - rd * 0.3)   # the tail of fire
			if not dead: (p.m as MeshInstance3D).look_at_from_position(p.pos, p.pos + rd, Vector3.UP if absf(rd.y) < 0.99 else Vector3.RIGHT)
		elif p.kind == "bomb":
			if p.life <= 0.0: blast(p.pos, 7.0, 300.0, true); dead = true
		elif p.kind == "egren":
			p.vel.y -= 9.8 * dt; var hy := player.pos.y + 0.9
			for s in 3:
				if dead: break
				p.pos += p.vel * (dt / 3.0)
				var near: bool = Vector3(p.pos.x - player.pos.x, p.pos.y - hy, p.pos.z - player.pos.z).length() < 0.7
				var hit: bool = p.pos.y <= Phys.floor_y(p.pos.x, p.pos.z) + 0.06 or Phys.collide_at(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.06, 0.1) != null or near
				if hit and p.mode == "gl": blast(p.pos, 5.5, 120.0, false); dead = true
				elif hit:   # a thrown grenade bounces and rolls
					var g := Phys.ground_at(p.pos.x, p.pos.y + 0.3, p.pos.z, 0.05); p.pos.y = maxf(p.pos.y, g + 0.06)
					if absf(p.vel.y) > 1.2: Snd.play("metal", 1.0, p.pos)
					p.vel = Vector3(p.vel.x * 0.45, absf(p.vel.y) * 0.3, p.vel.z * 0.45)
			if not dead and p.mode == "nade":   # three beeps, each with a red flash, then it goes off
				p.fuse -= dt
				if fx and randf() < dt * 6.0: fx.sparks(p.pos, 1, [1.0, 0.4, 0.2], 0.6)
				if p.beeps < 3 and p.fuse <= 1.5 - p.beeps * 0.5:
					p.beeps += 1; Snd.play("beep", 1.0, p.pos)
					if fx: fx.glow(p.pos + Vector3(0, 0.05, 0), Vector3.ZERO, 0.18, 0.5, 0.2, Color(1, 0.12, 0.08, 1))
				if p.fuse <= 0.0: blast(p.pos, 5.5, 100.0, false); dead = true
			elif not dead and fx and randf() < 0.6: fx.puff(p.pos, 1, 0.5, 0.15)
			if p.life <= 0.0 and not dead: blast(p.pos, 5.5, 120.0 if p.mode == "gl" else 100.0, false); dead = true
			if not dead: (p.m as MeshInstance3D).position = p.pos
		elif p.kind == "bullet":
			# small steps so fast rounds cannot skip past you between checks
			var hy0 := player.pos.y + 0.1; var hy1 := player.pos.y + Player.HEIGHT
			var steps := maxi(3, ceili((p.vel as Vector3).length() * dt / 0.3))
			var mine: bool = p.team == "us"
			var near: Array = tm.bullet_cands(p.pos, p.pos + p.vel * dt, p.team) if tm != null else []   # (stage 5's team modes: the toys of the other side by its way)
			for s in steps:
				p.pos += p.vel * (dt / steps)
				if not mine:
					var py := clampf(p.pos.y, hy0, hy1); var dd := Vector3(p.pos.x - player.pos.x, p.pos.y - py, p.pos.z - player.pos.z).length()
					if dd < 0.4 and not player.out:
						player.hurt(p.dmg, p.src, "head" if py - player.pos.y > 1.42 else "body"); dead = true
						if p.gun == "shotgun" and on_wet.is_valid(): on_wet.call()
						break
					if not p.whiz and dd < 1.5: p.whiz = true; Snd.play("whiz", 1.0, p.pos)
				for u in near:
					if tm.bullet_hits(u, p.pos): enemies.cause = p.gun; tm.bullet_hit(u, p.pos, p.dmg, p.vel, p.src); enemies.cause = ""; dead = true; break
				if dead: break
				var wall: Phys.Box = Phys.collide_at(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1)
				if p.pos.y <= Phys.floor_y(p.pos.x, p.pos.z) + 0.02 or wall != null:
					if mine and wall != null and wall.ref != null and wall.ref is Dictionary and str(wall.ref.get("trap", "")) != "": world.damage_crate(wall.ref, p.dmg, p.pos)   # our soldiers shoot the traps on the track
					if fx: fx.sparks(p.pos, 3, [0.5, 0.75, 1.0] if mine else [1.0, 0.8, 0.5], 2.0)
					dead = true; break
			if not dead: (p.m as MeshInstance3D).position = p.pos
		else:
			p.vel.y -= 9.8 * dt
			for s in 3:
				if dead: break
				p.pos += p.vel * (dt / 3.0)
				var armed: bool = (p.pos as Vector3).distance_to(p.src) > 8.0
				var impact: bool = p.pos.y <= Phys.floor_y(p.pos.x, p.pos.z) + 0.05 or Phys.collide_at(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1) != null
				if not impact:   # an enemy's body: as the rocket finds it (its height and girth; a flier round its middle), never the one you ride
					for e in enemies.list:
						if not e.alive or e.ridden: continue
						if e.fly:
							if (e.pos as Vector3).distance_to(p.pos) < e.R + 0.3: impact = true; break
							continue
						if p.pos.y >= e.pos.y - 0.1 and p.pos.y <= e.pos.y + e.H + 0.1 and Vector2(e.pos.x - p.pos.x, e.pos.z - p.pos.z).length() < e.R + 0.25: impact = true; break
				if impact:
					if armed: _explode(p); dead = true
					elif not p.bounced:
						p.bounced = true; p.vel *= -0.25; p.vel.y = absf(p.vel.y) + 1.0; p.pos.y = maxf(p.pos.y, 0.06); Snd.play("metal", 1.0, p.pos)
						if fx: fx.puff(p.pos, 2, 0.4, 0.3)
					else:
						if fx: fx.puff(p.pos, 3, 0.4, 0.35)
						dead = true
			if fx and randf() < 0.6: fx.puff(p.pos, 1, 0.55, 0.18)
			if not dead: (p.m as MeshInstance3D).position = p.pos
		if dead or p.life <= 0.0: (p.m as MeshInstance3D).queue_free(); list.remove_at(i)

func clear() -> void:
	for p in list: (p.m as MeshInstance3D).queue_free()
	list.clear()
