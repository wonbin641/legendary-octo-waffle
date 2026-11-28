class_name RealmKit
extends RefCounted
## What the realm's fighters do with their hands: the four weapons, Shift, the rune dagger, the alchemical bombs, the
## ultimates; and what comes of it in the world: what flies (shots), what lies or hangs about (fields), the made things
## that can be struck (a turret, the nucleus, an altar's crystal). The numbers are Races'; who is hurt how much is Realm's.
## A fighter's hands are a dictionary each frame, yours from the keys and theirs from RealmAI:
##   fire, alt (held), reload, skill, bomb, ult, slash, parry (pressed), move (the way Shift should carry you)

var rm: Realm
var shots: Array = []
var fields: Array = []
var things: Array = []
var decoys: Array = []
var _tid := 0

func clear() -> void:
	for s: Dictionary in shots: rm.look.shot_gone(s)
	for f: Dictionary in fields: rm.look.field_gone(f)
	for t: Dictionary in things: rm.look.thing_gone(t)
	for d: Dictionary in decoys: rm.look.decoy_gone(d)
	shots.clear(); fields.clear(); things.clear(); decoys.clear()

# ---------------- sums ----------------
func mag(f: Realm.Fighter) -> int:
	match f.race:
		"elf": return int(Races.RUNE.rapid_mag) if f.rune("elf_rapid") else int(Races.XBOW.mag)
		"dwarf": return int(Races.CANNON.mag)
	return 0

func skill_cd(f: Realm.Fighter) -> float:
	if f.race == "orc" and f.ult_t > 0.0: return float(Races.ULT.orc.leap_cd)
	return float(Races.SKILL[f.race].cd)

func parry_len(f: Realm.Fighter) -> float: return float(Races.RUNE.mirror) if f.rune("c_mirror") else float(Races.DAGGER.parry)

## the first place along a ray (from o, the way d, no farther than far) within r of an upright post at c, h tall; -1: none
static func ray_cyl(o: Vector3, d: Vector3, far: float, c: Vector3, r: float, h: float) -> float:
	var ox := o.x - c.x; var oz := o.z - c.z
	var a := d.x * d.x + d.z * d.z; var t0 := 0.0; var t1 := far
	if a < 1e-9:
		if ox * ox + oz * oz > r * r: return -1.0
	else:
		var b := ox * d.x + oz * d.z; var disc := b * b - a * (ox * ox + oz * oz - r * r)
		if disc < 0.0: return -1.0
		var sq := sqrt(disc); t0 = maxf(0.0, (-b - sq) / a); t1 = minf(far, (-b + sq) / a)
		if t0 > t1: return -1.0
	if absf(d.y) < 1e-9:
		return t0 if (o.y >= c.y and o.y <= c.y + h) else -1.0
	var ta := (c.y - o.y) / d.y; var tb := (c.y + h - o.y) / d.y
	t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
	return t0 if t0 <= t1 else -1.0

## a way a little off another, anywhere within a cone
static func cone(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0: return dir
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := dir.cross(up).normalized(); var y := x.cross(dir); var a := randf() * TAU; var r := sqrt(randf()) * spread
	return (dir + x * (cos(a) * r) + y * (sin(a) * r)).normalized()

func muzzle(f: Realm.Fighter) -> Vector3:
	if f.me and rm.cam != null: return rm.cam.global_position
	return f.eye_at()

func flat(v: Vector3) -> Vector3:
	var q := Vector3(v.x, 0, v.z)
	return q.normalized() if q.length() > 0.001 else Vector3.ZERO

func inside(fd: Dictionary, p: Vector3, more := 0.0) -> bool:
	var c: Vector3 = fd.pos
	return Vector2(p.x - c.x, p.z - c.z).length() < float(fd.r) + more and p.y > c.y - 2.5 and p.y < c.y + float(fd.get("h", 4.0))

## whether someone stands in a steam wall of his own side while what strikes him comes from outside it
func domed(v: Realm.Fighter, from: Vector3) -> bool:
	for fd: Dictionary in fields:
		if fd.kind == "dome" and fd.team == v.team and inside(fd, v.pos) and not inside(fd, from): return true
	return false

func in_furnace(f: Realm.Fighter) -> bool:
	for fd: Dictionary in fields:
		if fd.kind == "furnace" and fd.team != f.team and inside(fd, f.pos): return true
	return false

## a dwarf by something his side has laid or built (within four metres of it): his shield fills
func near_own_work(f: Realm.Fighter) -> bool:
	var near := float(Races.THICK.near)
	for fd: Dictionary in fields:
		if fd.team == f.team and fd.kind != "star" and inside(fd, f.pos, near - minf(near, float(fd.r))): return true
	for at: Vector3 in rm.mode.works(f.team):
		if Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < near and absf(f.pos.y - at.y) < 3.0: return true
	return false

## whether smoke hangs between two places
func smoked(a: Vector3, b: Vector3) -> bool:
	for fd: Dictionary in fields:
		if fd.kind != "smoke": continue
		var c: Vector3 = fd.pos + Vector3(0, 1.2, 0); var ab := b - a; var l2 := ab.length_squared()
		var t := 0.0 if l2 < 0.0001 else clampf((c - a).dot(ab) / l2, 0.0, 1.0)
		if (a + ab * t).distance_to(c) < float(fd.r): return true
	return false

func in_smoke(p: Vector3) -> bool:
	for fd: Dictionary in fields:
		if fd.kind == "smoke" and (fd.pos as Vector3 + Vector3(0, 1.2, 0)).distance_to(p) < float(fd.r): return true
	return false

## whether one sees another: near enough, nothing in the way, no smoke between; someone marked is seen whatever
func sees(a: Realm.Fighter, b: Realm.Fighter, sight := -1.0) -> bool:
	if not b.alive: return false
	if b.mark_t > 0.0: return true
	var ea := a.eye_at(); var eb := b.feet_mid(); var d := ea.distance_to(eb)
	if d > (sight if sight > 0.0 else float(Races.R[a.race].sight)): return false
	if b.me and rm.wood != null and rm.player != null and rm.wood.hides(rm.player, d): return false
	if smoked(ea, eb): return false
	return Phys.line_of_sight(ea, eb)

## the foes a blow reaches: within reach, within its arc of where he looks, nothing between; the nearest first
func arc(f: Realm.Fighter, reach: float, half: float) -> Array:
	var out: Array = []; var eye := f.eye_at(); var fw := Vector2(f.aim.x, f.aim.z)
	if fw.length() < 0.01: fw = Vector2(-sin(f.yaw), -cos(f.yaw))
	fw = fw.normalized()
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or e.inv > 0.0: continue
		var to := Vector2(e.pos.x - f.pos.x, e.pos.z - f.pos.z); var dist := to.length() - e.R
		if dist > reach or e.pos.y > f.pos.y + f.H + 0.6 or e.pos.y + e.H < f.pos.y - 0.6: continue
		if to.length() > 0.5 and acos(clampf(fw.dot(to.normalized()), -1.0, 1.0)) > half: continue
		if not Phys.line_of_sight(eye, e.feet_mid()): continue
		out.push_back([dist, e])
	out.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	return out.map(func(p): return p[1])

## the landmark a box belongs to, if it is a landmark of the other side still standing (6-2: its boxes are its body, and
## what meets them meets it)
func bldg_of(b, team: String):
	if b == null or not ((b as Phys.Box).ref is Dictionary): return null
	var th: Dictionary = (b as Phys.Box).ref
	if not th.get("bldg", false) or th.team == team or float(th.hp) <= 0.0: return null
	return th

## whether someone has a clear shot at a made thing within so far: nothing in the way but the thing's own boxes
func sees_thing(f: Realm.Fighter, th: Dictionary, far := 40.0) -> bool:
	var eye := f.eye_at(); var at: Vector3 = (th.pos as Vector3) + Vector3(0, minf(float(th.h) * 0.4, 3.5), 0)
	var to := at - eye; var d := to.length()
	if d < 0.01: return true
	if d > far + float(th.r) or smoked(eye, at): return false
	if not Phys.raycast_static(eye, to / d, d): return true
	return Phys.rh_box != null and is_same(Phys.rh_box.ref, th)

func arc_things(f: Realm.Fighter, reach: float, half: float) -> Array:
	var out: Array = []; var fw := Vector2(f.aim.x, f.aim.z).normalized()
	for th: Dictionary in things:
		if th.team == f.team or float(th.hp) <= 0.0: continue
		var c: Vector3 = th.pos; var to := Vector2(c.x - f.pos.x, c.z - f.pos.z)
		if to.length() - float(th.r) > reach or c.y > f.pos.y + f.H + 1.0 or c.y + float(th.h) < f.pos.y - 0.6: continue
		if to.length() > 0.8 and acos(clampf(fw.dot(to.normalized()), -1.0, 1.0)) > half: continue
		out.push_back(th)
	return out

# ---------------- a fighter's frame ----------------
func act(f: Realm.Fighter, I: Dictionary, dt: float) -> void:
	# (what is left over of a frame counts toward the next shot: a weapon's rate is its own at any frame rate)
	f.fire_t = maxf(-dt, f.fire_t - dt); f.alt_cd = maxf(0.0, f.alt_cd - dt); f.dag_t = maxf(0.0, f.dag_t - dt); f.parry_cd = maxf(0.0, f.parry_cd - dt); f.parry_t = maxf(0.0, f.parry_t - dt)
	f.skill_gap = maxf(0.0, f.skill_gap - dt); f.steady_t = maxf(0.0, f.steady_t - dt); f.since_swing += dt; f.idle_t += dt
	var S: Dictionary = Races.SKILL[f.race]
	if f.skill_n < int(S.charges):
		f.skill_t -= dt
		if f.skill_t <= 0.0: f.skill_n += 1; f.skill_t = skill_cd(f) if f.skill_n < int(S.charges) else 0.0
	if f.bombs < f.bomb_kinds.size():
		f.bomb_t -= dt
		if f.bomb_t <= 0.0: f.bombs += 1; f.bomb_t = Races.BOMB_CD
	_dash(f, dt)
	if f.ult_t > 0.0:
		f.ult_t -= dt
		if f.ult_t <= 0.0: ult_end(f)
	if f.cast_t > 0.0: f.cast_t -= dt; return
	if f.stun_t > 0.0: f.charge = 0.0; f.charged = false; f.beam_on = false; return
	if I.get("ult", false): ult(f)
	if I.get("skill", false): skill(f, I.get("move", Vector3.ZERO))
	if I.get("bomb", false): bomb(f)
	if I.get("parry", false): parry(f)
	if I.get("slash", false): slash(f)
	match f.race:
		"elf": _xbow(f, I, dt)
		"dwarf": _cannon(f, I, dt)
		"orc": _sword(f, I, dt)
		"demon": _staff(f, I, dt)

func _say(f: Realm.Fighter, name: String, gain := 1.0) -> void:
	if f.me: Snd.play(name, gain)
	else: Snd.play(name, gain, f.eye_at())

# ---------------- the elves' repeater ----------------
func _xbow(f: Realm.Fighter, I: Dictionary, dt: float) -> void:
	var W: Dictionary = Races.XBOW
	if f.reload_t > 0.0:
		f.reload_t -= dt; f.charge = 0.0; f.charged = false
		if f.reload_t <= 0.0: f.ammo = mag(f)
		return
	if (I.get("reload", false) and f.ammo < mag(f)) or f.ammo <= 0:
		f.reload_t = float(W.reload); f.charge = 0.0; f.charged = false; _say(f, "rm_xbow_reload", 0.8); rm.look.reload(f); return
	if I.get("alt", false):
		if f.charge <= 0.0: f.sight_done = false; _say(f, "rm_xbow_charge", 0.7)
		f.charge += dt
		if not f.charged and f.charge >= float(W.charge): f.charged = true; _say(f, "rm_xbow_full", 0.8)
		if not f.sight_done and f.charge >= float(W.sight_at): f.sight_done = true; arcane_sight(f)
		return
	if f.charge > 0.0:   # let go: the heavy shot, if it was drawn full
		if f.charged:
			f.ammo -= 1; f.fire_t += 1.0 / float(W.rate); f.fired_t = 0.0
			var prism := f.rune("elf_prism")
			shoot({"kind": "big", "pos": muzzle(f), "vel": f.aim * float(W.big_speed), "life": 1.6, "team": f.team, "by": f, "r": 0.1, "dmg": float(W.big) * (float(Races.RUNE.rapid_big) if f.rune("elf_rapid") else 1.0),
				"head": float(W.head), "elem": "arcane", "pierce": true, "bounces": int(W.bounces) + (1 if prism else 0), "split": prism})
			_say(f, "rm_xbow_big"); rm.look.fired(f, "big")
		f.charge = 0.0; f.charged = false
		return
	if I.get("fire", false) and f.fire_t <= 0.0:
		f.ammo -= 1; f.fire_t += 1.0 / (float(W.rate) * (float(Races.RUNE.rapid_rate) if f.rune("elf_rapid") else 1.0)); f.fired_t = 0.0
		var d := cone(f.aim, float(W.air_spread) if (not f.grounded and f.steady_t <= 0.0) else 0.0)
		shoot({"kind": "arrow", "pos": muzzle(f), "vel": d * float(W.speed), "life": float(W.life), "team": f.team, "by": f, "r": 0.08, "dmg": float(W.dmg), "head": float(W.head), "elem": "arcane"})
		_say(f, "rm_xbow", 0.8); rm.look.fired(f, "arrow")

## the elf's arcane sight: drawing the heavy shot shows, for a moment, the foes near by who lately fired or used a circle
## (not those in smoke)
func arcane_sight(f: Realm.Fighter) -> int:
	var W: Dictionary = Races.XBOW; var n := 0
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or e.fired_t > float(W.sight_recent) or e.pos.distance_to(f.pos) > float(W.sight_r) or in_smoke(e.feet_mid()): continue
		e.mark_t = maxf(e.mark_t, float(W.sight_t)); n += 1
	rm.note(["sight", f.id, n])
	return n

# ---------------- the dwarves' scatter-cannon ----------------
func _cannon(f: Realm.Fighter, I: Dictionary, dt: float) -> void:
	var W: Dictionary = Races.CANNON
	if f.reload_t > 0.0:
		f.reload_t -= dt
		if not f.vent_done and f.reload_t <= float(W.reload) - float(W.vent_at): f.vent_done = true; vent(f)
		if f.reload_t <= 0.0: f.ammo = mag(f)
	elif (I.get("reload", false) and f.ammo < mag(f)) or f.ammo <= 0:
		f.reload_t = float(W.reload); f.vent_done = false; _say(f, "rm_cannon_reload", 0.8); rm.look.reload(f)
	elif I.get("fire", false) and f.fire_t <= 0.0: blast(f)
	if I.get("alt", false) and f.alt_cd <= 0.0:
		f.alt_cd = float(W.gren_cd); f.fired_t = 0.0
		shoot({"kind": "gren", "pos": muzzle(f) + f.aim * 0.3, "vel": (f.aim + Vector3(0, 0.1, 0)).normalized() * float(W.gren_speed), "g": 12.0, "life": 3.0, "team": f.team, "by": f, "r": 0.14, "dmg": float(W.gren), "elem": "alchemy"})
		_say(f, "rm_gren"); rm.look.fired(f, "gren")

## the cannon's blast: ten shards, each its own way in a cone; what each meets is hurt less the farther off
func blast(f: Realm.Fighter) -> Dictionary:
	var W: Dictionary = Races.CANNON; var o := muzzle(f); var got := {}; var obj := {}; var ends: Array = []
	f.ammo -= 1; f.fire_t += 1.0 / float(W.rate); f.fired_t = 0.0
	for i in int(W.pellets):
		var d := cone(f.aim, float(W.spread)); var far := float(W.far); var wb = null
		if Phys.raycast_static(o, d, far): far = Phys.rh_t; wb = Phys.rh_box
		var who: Realm.Fighter = null; var what = null; var tb := far
		for e: Realm.Fighter in rm.all:
			if not e.alive or e.team == f.team or e.inv > 0.0: continue
			var t := ray_cyl(o, d, tb, e.pos, e.R, e.H)
			if t >= 0.0 and t < tb: tb = t; who = e
		for th: Dictionary in things:
			if th.team == f.team or float(th.hp) <= 0.0: continue
			var t := ray_cyl(o, d, tb, th.pos, float(th.r), float(th.h))
			if t >= 0.0 and t < tb: tb = t; what = th; who = null
		if who == null and what == null: what = bldg_of(wb, f.team)
		var at := o + d * tb; ends.push_back(at)
		_light_oil(at, f)   # (steam shards set oil alight)
		var fall := 1.0 if tb <= float(W.full) else lerpf(1.0, float(W.far_mul), (tb - float(W.full)) / (float(W.far) - float(W.full)))
		if who != null:
			var head := at.y > who.pos.y + who.H - who.head
			var q: Array = got.get(who, [0.0, 0, tb]); q[0] = float(q[0]) + float(W.dmg) * fall * (float(W.head) if head else 1.0); q[1] = int(q[1]) + 1; q[2] = minf(float(q[2]), tb); got[who] = q
		elif what != null: obj[int(what.id)] = float(obj.get(int(what.id), 0.0)) + float(W.dmg) * fall
	var wave := f.rune("dw_wave"); var all_close := false
	for v: Realm.Fighter in got:
		var q: Array = got[v]
		rm.hurt(v, float(q[0]), "physical", f, {"ranged": true, "src": "cannon", "from": o})
		if float(q[2]) < 7.0:
			v.delay_t = maxf(v.delay_t, 0.3)   # (a blast close by: a bomb's setting or unsetting loses a moment)
			if int(q[1]) >= int(W.pellets): all_close = true
			var slam := rm.shove(v, f.aim, float(W.push) * int(q[1]) / float(W.pellets) * (float(Races.RUNE.wave_push) if wave else 1.0))
			if slam and wave and v.alive: rm.hurt(v, float(Races.RUNE.wave_wall), "physical", f, {"src": "slam", "from": o}); v.stun_t = maxf(v.stun_t, float(Races.RUNE.wave_stun))
	for th: Dictionary in things.duplicate():
		if obj.has(int(th.id)): hurt_thing(th, float(obj[int(th.id)]), "physical", f)
	_say(f, "rm_cannon"); rm.look.cannon(f, ends, all_close)
	if f.me and rm.player != null: rm.player.recoil_pitch += deg_to_rad(float(W.kick) * 2.0 if all_close else 2.4)   # (every shard home, close by: the view kicks up 3.5 degrees)
	rm.note(["blast", f.id, got.size()])
	return got

## the cannon's steam let out as it is loaded: it scalds whoever is right by
func vent(f: Realm.Fighter) -> int:
	var W: Dictionary = Races.CANNON; var n := 0
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or e.feet_mid().distance_to(f.feet_mid()) > float(W.vent_r) + e.R: continue
		if rm.hurt(e, float(W.vent), "fire", f, {"aoe": true, "src": "vent", "from": f.feet_mid()}) > 0.0: n += 1; rm.chill(e)
	if n > 0: f.skill_t = maxf(0.0, f.skill_t - float(Races.SKILL.dwarf.refund))
	_say(f, "rm_vent", 0.7); rm.look.steam(f.feet_mid(), float(W.vent_r))
	for fd: Dictionary in fields:
		if fd.kind == "oil" and inside(fd, f.pos, float(W.vent_r)): ignite(fd, f)
	return n

# ---------------- the orcs' great sword ----------------
func _sword(f: Realm.Fighter, I: Dictionary, dt: float) -> void:
	var W: Dictionary = Races.SWORD
	if f.swing_t > 0.0:
		if f.hold_t > 0.0: f.hold_t -= dt; return   # (the blow bit: it holds a moment)
		f.swing_t -= dt
		if not f.swing_hit and f.swing_t <= f.swing_len * (1.0 - float(W.lands)): f.swing_hit = true; sword_lands(f)
		if f.swing_t <= 0.0: f.combo = (f.combo + 1) % 3; f.since_swing = 0.0
		return
	if f.since_swing > float(W.combo_keep): f.combo = 0
	if I.get("fire", false) and f.dash_t <= 0.0:
		var len := float(W.step)
		if f.ult_t > 0.0: len /= float(Races.ULT.orc.haste)
		if f.quick: len *= float(Races.SKILL.orc.quick); f.quick = false
		f.swing_len = len; f.swing_t = len; f.swing_hit = false
		_say(f, "rm_swing_big" if f.combo == 2 else "rm_swing", 0.9); rm.look.swing(f, "sword", f.combo)
	elif I.get("alt", false) and f.alt_cd <= 0.0 and f.dash_t <= 0.0:
		f.alt_cd = float(W.axe_cd); f.fired_t = 0.0
		shoot({"kind": "axe", "pos": muzzle(f) + f.aim * 0.4, "vel": f.aim * float(W.axe_speed), "life": float(W.axe_range) / float(W.axe_speed), "team": f.team, "by": f, "r": 0.25, "dmg": float(W.axe), "elem": "physical"})
		_say(f, "rm_axe"); rm.look.swing(f, "axe", 0)

func sword_lands(f: Realm.Fighter) -> int:
	var W: Dictionary = Races.SWORD; var i := f.combo; var got := arc(f, float(W.reach), float(W.arc)); var n := 0
	var stop := float(W.stop_ms[i]) / 1000.0
	for v: Realm.Fighter in got:
		if rm.hurt(v, float(W.dmg[i]), "physical", f, {"melee": true, "src": "sword%d" % (i + 1)}) > 0.0:
			n += 1; v.stun_t = maxf(v.stun_t, stop)
			if i == 2: v.delay_t = maxf(v.delay_t, 0.3)
	for th: Dictionary in arc_things(f, float(W.reach), float(W.arc)): hurt_thing(th, float(W.dmg[i]), "physical", f); n += 1
	if n > 0:
		rm.add_stack(f); f.hold_t = stop; _say(f, "rm_blade_hit")
		if f.me: rm.stop_t = stop
	if i == 2 or f.ult_t > 0.0:
		var giant := f.rune("orc_giant"); var far := float(Races.RUNE.giant_range) if giant else float(W.wave_range)
		var d := f.aim
		shoot({"kind": "wave", "pos": f.eye_at() - Vector3(0, 0.35, 0) + d * 0.9, "vel": d * float(W.wave_speed), "life": far / float(W.wave_speed), "team": f.team, "by": f, "r": float(W.wave_r), "dmg": float(W.wave), "elem": "physical", "pierce": true, "giant": giant})
		if f.me: rm.flash["wave"] = 0.18
	rm.note(["swing", f.id, i, n])
	return n

# ---------------- the demons' staff ----------------
func _staff(f: Realm.Fighter, I: Dictionary, dt: float) -> void:
	var W: Dictionary = Races.STAFF; var lit := f.ult_t > 0.0
	if lit: f.heat = float(Races.ULT.demon.heat); f.seal_t = 0.0
	if f.seal_t > 0.0:
		f.seal_t -= dt; f.beam_on = false
		if f.seal_t <= 0.0: f.heat = float(W.seal_to)
		return
	f.beam_on = bool(I.get("alt", false)) and f.hp > float(W.beam_floor)
	if f.beam_on: _beam(f, dt)
	elif I.get("fire", false) and f.fire_t <= 0.0:
		var hot := rm.critical(f); var burst := f.rune("dm_burst")
		f.fire_t += 1.0 / float(W.rate); f.idle_t = 0.0; f.fired_t = 0.0
		shoot({"kind": "ember", "pos": muzzle(f), "vel": cone(f.aim, 0.012) * float(W.speed), "life": float(W.life), "team": f.team, "by": f, "r": 0.1, "dmg": float(W.dmg), "head": float(W.head), "elem": "fire", "hot": hot, "burst": hot and burst})
		Snd.toy("rm_ember_hot" if hot else "rm_ember", 0.7, null if f.me else f.eye_at(), 0.85 + 0.45 * minf(1.0, f.heat / float(W.crit)))   # (its pitch climbs with the heat)
		rm.look.fired(f, "ember")
		if not lit:
			f.heat += float(W.heat) * (float(Races.RUNE.burst_heat) if burst else 1.0)
			if f.heat > 100.0: f.heat = 100.0; f.seal_t = float(W.seal); _say(f, "rm_seal"); rm.look.sealed(f)
	if f.idle_t > float(W.cool_wait) and not lit: f.heat = maxf(0.0, f.heat - float(W.cool) * (float(Races.RUNE.core_cool) if f.rune("dm_core") else 1.0) * dt)

## the soul-drain beam: it eats at whoever it rests on, and at the demon's own health while it is held
func _beam(f: Realm.Fighter, dt: float) -> void:
	var W: Dictionary = Races.STAFF; var o := muzzle(f); var d := f.aim; var far := float(W.beam_range)
	f.hp = maxf(1.0, f.hp - float(W.beam_cost) * dt); f.fired_t = 0.0; var wb = null
	if Phys.raycast_static(o, d, far): far = Phys.rh_t; wb = Phys.rh_box
	var who: Realm.Fighter = null; var what = null; var tb := far
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or e.inv > 0.0: continue
		var t := ray_cyl(o, d, tb, e.pos, e.R + 0.15, e.H)
		if t >= 0.0 and t < tb: tb = t; who = e
	for th: Dictionary in things:
		if th.team == f.team or float(th.hp) <= 0.0: continue
		var t := ray_cyl(o, d, tb, th.pos, float(th.r) + 0.15, float(th.h))
		if t >= 0.0 and t < tb: tb = t; what = th; who = null
	if who == null and what == null: what = bldg_of(wb, f.team)
	f.beam_end = o + d * tb; f.beam_acc += dt
	if f.beam_acc >= 0.1:
		var n := f.beam_acc; f.beam_acc = 0.0
		if who != null: rm.hurt(who, float(W.beam) * n, "fire", f, {"ranged": true, "dot": true, "src": "beam", "from": o})
		elif what != null: hurt_thing(what, float(W.beam) * n, "fire", f)
		if fmod(rm.clock, 0.45) < 0.1: _say(f, "rm_drain", 0.6)

# ---------------- Shift ----------------
func skill(f: Realm.Fighter, mv: Vector3) -> bool:
	var S: Dictionary = Races.SKILL[f.race]
	if f.skill_n <= 0 or f.skill_gap > 0.0 or f.dash_t > 0.0 or f.leaping or f.cast_t > 0.0: return false
	var dir := flat(mv)
	if dir == Vector3.ZERO or f.race == "orc": dir = flat(f.aim)
	if dir == Vector3.ZERO: dir = Vector3(-sin(f.yaw), 0, -cos(f.yaw))
	f.skill_n -= 1
	if f.skill_t <= 0.0: f.skill_t = skill_cd(f)
	match f.race:
		"elf":
			if f.rune("elf_echo"): decoys.push_back(rm.look.decoy({"pos": f.pos, "yaw": f.yaw, "team": f.team, "by": f, "t": float(Races.RUNE.echo_t), "R": f.R, "H": f.H}))
			dash(f, dir * (float(S.dist) / float(S.t)), float(S.t), "wind"); f.steady_t = float(S.t) + float(S.steady); _say(f, "rm_windstep")
		"dwarf":
			dash(f, dir * (float(S.dist) / float(S.t)), float(S.t), "steam"); _say(f, "rm_steamdash")
		"orc":
			var air := 2.0 * float(S.up) / 19.0; var v := dir * (float(S.dist) / air) + Vector3(0, float(S.up), 0)
			f.leaping = true; f.quick = true
			if f.me and rm.player != null: rm.player.launch(v)
			else: f.vel = Vector3(v.x, 0, v.z); f.vy = v.y; f.grounded = false; f.pos.y += 0.06
			_say(f, "rm_leap")
		"demon":
			dash(f, dir * (float(S.dist) / 0.12), 0.12, "rift"); f.inv = maxf(f.inv, float(S.t)); f.skill_gap = float(S.gap); f.phased_t = float(S.t) + float(S.phys_cut)
			if f.ult_t <= 0.0: f.heat = maxf(0.0, f.heat - float(S.cool))
			_say(f, "rm_rift")
	rm.look.skilled(f)
	rm.note(["skill", f.id, f.race])
	return true

func dash(f: Realm.Fighter, v: Vector3, t: float, kind: String) -> void:
	f.dash_t = t; f.dash_v = v; f.dash_kind = kind; f.dash_hit = {}; f.dash_from = f.pos
	if f.me and rm.player != null: rm.player.dash_t = t; rm.player.dash_v = v

func _dash(f: Realm.Fighter, dt: float) -> void:
	if f.dash_t <= 0.0: return
	if not f.me:
		var step := f.dash_v * minf(dt, f.dash_t)
		f.pos = Phys.move_xz(f.pos, step.x, step.z, f.R, f.H, 0.5)[0]; f.vy = 0.0
		if absf(step.y) > 0.0001: f.pos.y = maxf(Phys.ground_at(f.pos.x, f.pos.y + maxf(step.y, 0.0) + 0.5, f.pos.z, f.R), f.pos.y + step.y)
	f.dash_t -= dt
	if f.dash_kind == "steam": _steam_hits(f, 1.1)
	if f.dash_t <= 0.0:
		match f.dash_kind:
			"steam": _steam_hits(f, float(Races.SKILL.dwarf.r)); rm.look.steam(f.feet_mid(), 2.0)
			"rift":
				if f.rune("dm_trail"): fields.push_back(rm.look.field({"kind": "trail", "pos": (f.dash_from + f.pos) * 0.5, "a": f.dash_from, "b": f.pos, "r": f.dash_from.distance_to(f.pos) * 0.5 + 1.2, "t": float(Races.RUNE.trail_t), "team": f.team, "by": f}))
		f.dash_kind = ""

func _steam_hits(f: Realm.Fighter, r: float) -> void:
	var S: Dictionary = Races.SKILL.dwarf; var wave := f.rune("dw_wave")
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == f.team or f.dash_hit.has(e.id) or e.feet_mid().distance_to(f.feet_mid()) > r + e.R + f.R: continue
		f.dash_hit[e.id] = true
		rm.hurt(e, float(S.dmg), "alchemy", f, {"aoe": true, "src": "steam", "from": f.feet_mid()}); rm.chill(e)
		var away := flat(e.pos - f.pos)
		if away == Vector3.ZERO: away = flat(f.dash_v)
		var slam := rm.shove(e, away, float(S.push) * (float(Races.RUNE.wave_push) if wave else 1.0))
		if slam and wave and e.alive: rm.hurt(e, float(Races.RUNE.wave_wall), "physical", f, {"src": "slam"}); e.stun_t = maxf(e.stun_t, float(Races.RUNE.wave_stun))

## an orc's bound comes down: those about him are slowed
func landed(f: Realm.Fighter) -> void:
	var S: Dictionary = Races.SKILL.orc
	for e: Realm.Fighter in rm.all:
		if e.alive and e.team != f.team and e.pos.distance_to(f.pos) < float(S.r) + e.R: rm.slow(e, "bound", float(S.slow), float(S.slow_t))
	_say(f, "rm_land"); rm.look.landed(f)
	rm.note(["land", f.id])

# ---------------- the rune dagger ----------------
func slash(f: Realm.Fighter) -> bool:
	var D: Dictionary = Races.DAGGER
	if f.dag_t > 0.0 or (f.swing_t > 0.0 and not f.swing_hit): return false
	f.dag_t = float(D.cd); _say(f, "rm_dagger", 0.8); rm.look.swing(f, "dagger", 0)
	var got := arc(f, float(D.reach), float(D.arc))
	if got.is_empty():
		for th: Dictionary in arc_things(f, float(D.reach), float(D.arc)): hurt_thing(th, float(D.dmg), "physical", f); break
		return true
	var v: Realm.Fighter = got[0]
	if v.hp <= float(D.execute):
		rm.slay(v, f, {"melee": true, "execute": true, "src": "dagger"}); _say(f, "rm_execute"); rm.look.executed(v, f)
		if f.me: rm.flash["execute"] = 0.15
	else: rm.hurt(v, float(D.dmg), "physical", f, {"melee": true, "src": "dagger"})
	rm.add_stack(f)
	return true

func parry(f: Realm.Fighter) -> bool:
	if f.parry_cd > 0.0: return false
	f.parry_t = parry_len(f); f.parry_cd = float(Races.DAGGER.parry_cd); _say(f, "rm_parry_up", 0.8); rm.look.swing(f, "parry", 0)
	return true

# ---------------- the alchemical bombs ----------------
func bomb(f: Realm.Fighter) -> bool:
	if f.bombs <= 0 or f.bomb_kinds.is_empty(): return false
	var kind: String = f.bomb_kinds[f.bomb_i % f.bomb_kinds.size()]; f.bomb_i += 1
	if f.bombs == f.bomb_kinds.size(): f.bomb_t = Races.BOMB_CD
	f.bombs -= 1
	shoot({"kind": "flask", "bomb": kind, "pos": muzzle(f) + f.aim * 0.4, "vel": (f.aim + Vector3(0, 0.22, 0)).normalized() * Races.BOMB_SPEED + Vector3(f.vel.x, 0, f.vel.z) * 0.5, "g": 14.0, "life": 4.0, "team": f.team, "by": f, "r": 0.14, "dmg": 0.0, "elem": "alchemy"})
	_say(f, "rm_throw"); rm.look.swing(f, "throw", 0)
	rm.note(["bomb", f.id, kind])
	return true

## on the moonwell's water what alchemy lays does not last: half as long
func _well_cut(at: Vector3) -> float:
	return 0.5 if Vector2(at.x - ElfWood.WELL.x, at.z - ElfWood.WELL.z).length() < ElfWood.WELL_R + 1.0 else 1.0

func lay(kind: String, at: Vector3, by: Realm.Fighter, r: float, t: float, more := {}) -> Dictionary:
	var gy := Phys.ground_at(at.x, at.y + 0.3, at.z, 0.2)
	var fd := {"kind": kind, "pos": Vector3(at.x, gy if at.y - gy < 3.0 else at.y, at.z), "r": r, "t": t * (_well_cut(at) if kind in ["oil", "fire", "frost", "smoke"] else 1.0), "team": by.team, "by": by}
	fd.merge(more, true)
	fields.push_back(rm.look.field(fd))
	return fd

func flask_burst(s: Dictionary, at: Vector3) -> void:
	var kind: String = s.bomb; var B: Dictionary = Races.BOMB[kind]; var by: Realm.Fighter = s.by
	match kind:
		"oil": lay("oil", at, by, float(B.r), float(B.t)); Snd.play("rm_oil", 1.0, at)
		"smoke": lay("smoke", at, by, float(B.r), float(B.t)); Snd.play("rm_smoke", 1.0, at)
		"gravity":
			for e: Realm.Fighter in rm.all:
				if e.alive and e.team != by.team and e.feet_mid().distance_to(at) < float(B.r) + e.R and Phys.line_of_sight(at + Vector3(0, 0.3, 0), e.feet_mid()):
					rm.hurt(e, float(B.dmg), "alchemy", by, {"fixed": true, "aoe": true, "src": "gravity", "from": at})
			lay("gravity", at, by, float(B.r), float(B.t)); Snd.play("rm_gravity", 1.0, at)
	rm.note(["burst", kind, at])

func ignite(fd: Dictionary, by: Realm.Fighter) -> void:
	if fd.kind != "oil": return
	fd.kind = "fire"; fd.t = float(Races.BOMB.oil.fire_t) * _well_cut(fd.pos); fd.by = by; fd.team = by.team
	Snd.play("rm_ignite", 1.0, fd.pos); rm.look.field_changed(fd)
	rm.note(["ignite", by.id])

func _light_oil(at: Vector3, by: Realm.Fighter) -> void:
	for fd: Dictionary in fields:
		if fd.kind == "oil" and Vector2(at.x - (fd.pos as Vector3).x, at.z - (fd.pos as Vector3).z).length() < float(fd.r) and absf(at.y - (fd.pos as Vector3).y) < 1.6: ignite(fd, by)

## a burst: everyone of the other side within r, nothing between
func boom(at: Vector3, r: float, dmg: float, elem: String, by: Realm.Fighter, o := {}, skip: Realm.Fighter = null) -> int:
	var n := 0; var q := o.duplicate(); q.aoe = true; q.from = at
	for e: Realm.Fighter in rm.all:
		if not e.alive or e == skip or e.team == by.team or e.feet_mid().distance_to(at) > r + e.R: continue
		if not Phys.line_of_sight(at + Vector3(0, 0.25, 0), e.feet_mid()): continue
		if rm.hurt(e, dmg, elem, by, q) > 0.0: n += 1
	for th: Dictionary in things:
		if th.team != by.team and float(th.hp) > 0.0 and (th.pos as Vector3 + Vector3(0, float(th.h) * 0.5, 0)).distance_to(at) < r + float(th.r): hurt_thing(th, dmg, elem, by)
	return n

# ---------------- the ultimates ----------------
func ult(f: Realm.Fighter) -> bool:
	if f.gauge < float(Races.GAUGE.max) or f.ult_t > 0.0 or f.cast_t > 0.0: return false
	var U: Dictionary = Races.ULT[f.race]
	match f.race:
		"elf":
			var o := muzzle(f); var far := float(U.range); var at := o + f.aim * far
			if Phys.raycast_static(o, f.aim, far): at = o + f.aim * maxf(0.0, Phys.rh_t - 0.2)
			if not f.me and f.brain.has("ult_at"): at = f.brain.ult_at   # (the others call it down on whom they see)
			at.y = Phys.ground_at(at.x, at.y + 0.5, at.z, 0.2)
			lay("star", at, f, float(U.r), float(U.warn) + float(U.t), {"n": int(U.arrows), "acc": 0.0, "h": 14.0})
			Snd.play("rm_ult_elf", 1.0, at); f.ult_t = float(U.warn) + float(U.t)
		"dwarf":
			var fw := flat(f.aim); var at := f.pos + fw * 2.2; at.y = Phys.ground_at(at.x, f.pos.y + 0.6, at.z, 0.4)
			var th := add_thing({"kind": "turret", "pos": at, "r": 0.75, "h": 1.7, "team": f.team, "by": f, "hp": float(U.hp), "max": float(U.hp)})
			lay("dome", at, f, float(U.r), float(U.t), {"thing": th, "bolt_t": float(U.every), "h": 7.0})
			Snd.play("rm_ult_dwarf", 1.0, at); f.ult_t = float(U.t)
		"orc":
			f.cast_t = float(U.cast); f.stacks = maxi(f.stacks, int(Races.LUST.max)); f.stack_t = float(Races.LUST.t); f.over = float(U.hp); f.ult_t = float(U.t) + float(U.cast); f.ult_more = 0; f.slows.clear(); f.stun_t = 0.0
			_say(f, "rm_ult_orc")
		"demon":
			f.ult_t = float(U.t); f.seal_t = 0.0; f.heat = float(U.heat)
			lay("furnace", f.pos, f, float(U.r), float(U.t), {"h": 6.0})
			_say(f, "rm_ult_demon")
	f.gauge = 0.0
	rm.look.ulted(f)
	rm.note(["ult", f.id, f.race])
	if rm.game != null: rm.game.say_feed(f.name + (" " if f.name != "" else "") + "비전 비기 · " + str(U.name))
	return true

func ult_end(f: Realm.Fighter) -> void:
	f.ult_t = 0.0
	match f.race:
		"orc": f.over = 0.0; f.stack_t = float(Races.LUST.t)
		"demon":
			for fd: Dictionary in fields:
				if fd.kind == "furnace" and fd.by == f: fd.t = 0.0
	rm.look.ult_over(f)

# ---------------- made things ----------------
func add_thing(th: Dictionary) -> Dictionary:
	if not th.has("made"): th.made = true
	_tid -= 1; th.id = _tid
	things.push_back(rm.look.thing(th)); return th

## a blow on a made thing: its shield first (arcane bites that the harder), then its body (physical bites that the harder)
func hurt_thing(th: Dictionary, dmg: float, elem: String, by: Realm.Fighter, at = null) -> float:
	if float(th.hp) <= 0.0 or dmg <= 0.0 or (by != null and by.team == th.team) or not rm.mode.fighting(): return 0.0
	if th.has("open") and not (th.open as Callable).call(): return 0.0
	if by != null and not by.me: dmg *= float(th.get("troops", 1.0))   # (6-2's landmarks: walls the summoned barely dent)
	var left := dmg; var done := 0.0
	if float(th.get("shield", 0.0)) > 0.0:
		var m := Races.SHIELD_ARCANE if elem == "arcane" else 1.0
		var take := minf(float(th.shield), left * m); th.shield = float(th.shield) - take; left -= take / m; done += take
		th.since = 0.0
	if left > 0.0:
		var d := left * Races.affinity(elem, {"made": th.made})
		th.hp = float(th.hp) - d; done += d; th.since = 0.0
	if by != null:
		rm.gain(by, done * float(Races.GAUGE.object)); by.dealt += done
		if by.me: rm.marks.push_back({"t": 0.0, "head": false, "dmg": done, "thing": true})
	rm.look.thing_hit(th, elem, at if at != null else (th.pos as Vector3) + Vector3(0, float(th.h) * 0.6, 0))
	rm.note(["thing", str(th.kind), done, elem, str(th.team)])
	if float(th.hp) <= 0.0:
		th.hp = 0.0
		if th.has("dead"): (th.dead as Callable).call(by)
	return done

# ---------------- what flies ----------------
func shoot(s: Dictionary) -> Dictionary:
	s.hit = {}
	if not s.has("g"): s.g = 0.0
	s.from = s.pos
	shots.push_back(rm.look.shot(s))
	return s

func step(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		if not _fly(s, dt): rm.look.shot_gone(s); shots.remove_at(i)
	for i in range(fields.size() - 1, -1, -1):
		var fd: Dictionary = fields[i]
		_field(fd, dt)
		if float(fd.t) <= 0.0: rm.look.field_gone(fd); fields.remove_at(i)
	for i in range(things.size() - 1, -1, -1):
		var th: Dictionary = things[i]
		if float(th.hp) <= 0.0 and not th.get("keep", false): rm.look.thing_gone(th); things.remove_at(i)
	for i in range(decoys.size() - 1, -1, -1):
		var dc: Dictionary = decoys[i]; dc.t = float(dc.t) - dt
		if float(dc.t) <= 0.0: rm.look.decoy_gone(dc); decoys.remove_at(i)

func _fly(s: Dictionary, dt: float) -> bool:
	s.life = float(s.life) - dt
	var v: Vector3 = s.vel
	if float(s.g) != 0.0: v.y -= float(s.g) * dt
	for fd: Dictionary in fields:   # a gravity sphere takes what flies by
		if fd.kind == "gravity" and (s.pos as Vector3).distance_to(fd.pos as Vector3 + Vector3(0, 1.0, 0)) < float(fd.r):
			v = v.lerp(((fd.pos as Vector3 + Vector3(0, 1.0, 0)) - (s.pos as Vector3)).normalized() * v.length(), minf(1.0, dt * 7.0))
	if s.has("seek"):   # a turret's bolt follows what it was sent at
		var q: Realm.Fighter = s.seek
		if q.alive: v = (q.feet_mid() - (s.pos as Vector3)).normalized() * v.length()
	s.vel = v
	var p0: Vector3 = s.pos; var mv := v * dt; var L := mv.length()
	if L < 1e-6: return float(s.life) > 0.0
	var d := mv / L
	_through(s, p0)
	if _parried(s, p0, d, L): return true
	var wall := Phys.raycast_static(p0, d, L); var tb := Phys.rh_t if wall else L; var n := Phys.rh_n; var wb = Phys.rh_box if wall else null
	var who: Realm.Fighter = null; var what = null; var fake = null
	for e: Realm.Fighter in rm.all:
		if not e.alive or e.team == s.team or s.hit.has(e.id) or e.inv > 0.0: continue
		var t := ray_cyl(p0, d, tb, e.pos, e.R + float(s.r), e.H)
		if t >= 0.0 and t < tb: tb = t; who = e
	for th: Dictionary in things:
		if th.team == s.team or float(th.hp) <= 0.0 or s.hit.has(int(th.id)): continue
		var t := ray_cyl(p0, d, tb, th.pos, float(th.r) + float(s.r), float(th.h))
		if t >= 0.0 and t < tb: tb = t; what = th; who = null
	for dc: Dictionary in decoys:
		if dc.team == s.team: continue
		var t := ray_cyl(p0, d, tb, dc.pos, float(dc.R) + float(s.r), float(dc.H))
		if t >= 0.0 and t < tb: tb = t; fake = dc; who = null; what = null
	if who == null and what == null and fake == null:
		var hb = bldg_of(wb, s.team)
		if hb != null and not s.hit.has(int(hb.id)): what = hb   # (a landmark's wall: the landmark)
	var at := p0 + d * tb
	if fake != null:   # an elf's echo: whoever shot it is shown to the elf's side
		var by: Realm.Fighter = s.by
		if by != null: by.mark_t = maxf(by.mark_t, float(Races.RUNE.echo_reveal)); rm.note(["echo", by.id])
		fake.t = 0.0
		return false
	if who != null or what != null:
		_strike(s, who, what, at, d)
		if s.get("pierce", false):
			if who != null: s.hit[who.id] = true
			else: s.hit[int(what.id)] = true
			s.pos = p0 + mv; return float(s.life) > 0.0
		return false
	if wall: return _wall(s, at, n, d)
	s.pos = p0 + mv
	if float(s.life) <= 0.0:
		if s.kind == "flask": flask_burst(s, s.pos)
		elif s.kind == "gren": gren_burst(s, s.pos, null)
		return false
	return true

## what a shot passes on its way: the amplifying circle, fog and frost (arcane is the worse for them), oil (an ember lights it)
func _through(s: Dictionary, p: Vector3) -> void:
	if not s.get("amp", false) and Vector2(p.x - ElfWood.AMP.x, p.z - ElfWood.AMP.z).length() < ElfWood.AMP_R and p.y < 6.0 and rm.wood != null:
		var own := rm.mode.amp_owner()
		if own == "" or own == s.team: s.amp = true; s.vel = (s.vel as Vector3) * float(Realm.AMP.speed); Snd.play("rm_amp", 0.7, p); rm.look.amped(p)
	if s.elem == "arcane" and not s.get("fog", false):
		for fd: Dictionary in fields:
			if (fd.kind == "smoke" or fd.kind == "frost") and (fd.pos as Vector3 + Vector3(0, 1.2, 0)).distance_to(p) < float(fd.r): s.fog = true; break
	if s.kind == "ember": _light_oil(p, s.by)

## a shot met by someone's dagger held up: it goes back the way he looks, his now
func _parried(s: Dictionary, p0: Vector3, d: Vector3, L: float) -> bool:
	for v: Realm.Fighter in rm.all:
		if not v.alive or v.team == s.team or v.parry_t <= 0.0: continue
		var c := v.pos + Vector3(0, v.H * 0.6, 0); var t := clampf((c - p0).dot(d), 0.0, L)
		if (p0 + d * t).distance_to(c) > float(Races.DAGGER.parry_r) or d.dot(v.aim) > 0.2: continue
		var sp := (s.vel as Vector3).length()
		s.team = v.team; s.by = v; s.hit = {}; s.vel = v.aim * sp; s.pos = c + v.aim * 0.7; s.life = maxf(float(s.life), 1.0); s.erase("seek")
		if v.rune("c_mirror"): s.dmg = float(s.dmg) * float(Races.RUNE.mirror_mul)
		Snd.play("rm_parry", 1.0, c); rm.look.parried(v, c); rm.look.shot_turned(s)
		rm.note(["parry", v.id, str(s.kind)])
		return true
	return false

func _strike(s: Dictionary, who: Realm.Fighter, what, at: Vector3, d: Vector3) -> void:
	var by: Realm.Fighter = s.by
	if what != null:
		if s.kind == "flask": flask_burst(s, at); return
		hurt_thing(what, float(s.dmg), s.elem, by, at)
		if s.kind == "gren": gren_burst(s, at, null)
		if s.kind == "axe": _axe_end(s, null, at)
		return
	match s.kind:
		"flask": flask_burst(s, at); return
		"gren":
			rm.hurt(who, float(s.dmg), "alchemy", by, {"ranged": true, "at": at, "from": s.from, "src": "gren"}); gren_burst(s, at, null); return
	var o := {"ranged": true, "at": at, "from": s.from, "src": str(s.kind), "fog": s.get("fog", false)}
	if s.has("head") and at.y > who.pos.y + who.H - who.head: o.head = float(s.head)
	if s.get("giant", false): who.shield = 0.0   # (the giant's wave breaks a shield before it bites)
	rm.hurt(who, float(s.dmg), s.elem, by, o)
	if s.get("hot", false): rm.burn(who, float(Races.STAFF.burn), float(Races.STAFF.burn_t), by, "hot")
	if s.get("burst", false): boom(at, float(Races.RUNE.burst_r), float(Races.RUNE.burst), "fire", by, {"src": "burst"})
	if s.get("amp", false): boom(at, float(Realm.AMP.splash), float(s.dmg) * float(Realm.AMP.splash_dmg), s.elem, by, {"src": "amp"}, who)
	if s.kind == "axe": _axe_end(s, who, at)

## a shot meets the ground or a wall. true: it flies on (glanced off, or went through)
func _wall(s: Dictionary, at: Vector3, n: Vector3, d: Vector3) -> bool:
	var by: Realm.Fighter = s.by
	if n.length_squared() < 0.25: n = -d   # (met from inside a corner: straight back)
	match s.kind:
		"flask": flask_burst(s, at + n * 0.1); return false
		"gren": gren_burst(s, at + n * 0.1, null); return false
		"axe": _axe_end(s, null, at); return false
		"big":
			if int(s.get("bounces", 0)) > 0:
				var first: bool = not s.get("bounced", false)
				s.bounces = int(s.bounces) - 1; s.bounced = true; s.vel = (s.vel as Vector3).bounce(n); s.pos = at + n * 0.04; s.life = maxf(float(s.life), 0.9); s.hit = {}
				Snd.play("rm_rico1" if first else "rm_rico2", 0.9, at); rm.look.impact("arcane", at, n)
				if first and s.get("split", false):   # the prism: two arrows from the one, each the less
					s.dmg = float(s.dmg) * float(Races.RUNE.prism_split)
					var twin := s.duplicate(); twin.erase("node"); twin.vel = (s.vel as Vector3).rotated(n, 0.16); s.vel = (s.vel as Vector3).rotated(n, -0.16); twin.hit = {}
					shots.push_back(rm.look.shot(twin))
				rm.note(["glance", by.id, int(s.bounces)])
				return true
		"wave":
			if s.get("giant", false) and not s.get("through", false) and Phys.collide_at(at.x + d.x * 1.3, at.y + d.y * 1.3 - 0.2, at.z + d.z * 1.3, 0.1, 0.4) == null:
				s.through = true; s.pos = at + d * 1.3; return true   # (the giant's wave goes through thin cover, once)
	if s.get("burst", false): boom(at, float(Races.RUNE.burst_r), float(Races.RUNE.burst), "fire", by, {"src": "burst"})
	if s.get("amp", false): boom(at, float(Realm.AMP.splash), float(s.dmg) * float(Realm.AMP.splash_dmg), s.elem, by, {"src": "amp"})
	rm.look.impact(s.elem, at, n)
	return false

## the dwarf's grenade goes off: everyone by it, and what it leaves on the ground (oil; frost by the rune)
func gren_burst(s: Dictionary, at: Vector3, _who) -> void:
	var W: Dictionary = Races.CANNON; var by: Realm.Fighter = s.by
	boom(at, float(W.gren_r), float(W.gren_boom), "alchemy", by, {"blast": true, "src": "gren_boom"})
	Snd.play("rm_gren_boom", 1.0, at); rm.look.burst(at, float(W.gren_r), "alchemy")
	if by.rune("dw_frost"):
		lay("frost", at, by, float(Races.FROST.r), float(Races.RUNE.frost_t)); Snd.play("rm_frost", 0.9, at)
		for e: Realm.Fighter in rm.all:
			if e.alive and e.team != by.team and e.feet_mid().distance_to(at) < float(Races.FROST.r) + e.R: rm.chill(e)
	else: lay("oil", at, by, float(W.oil_r), float(W.oil_t))

## the chain axe lodges: the orc is hauled to it (or, by the hook rune, whoever it bit is hauled to him)
func _axe_end(s: Dictionary, who: Realm.Fighter, at: Vector3) -> void:
	var f: Realm.Fighter = s.by; var W: Dictionary = Races.SWORD
	Snd.play("rm_axe_hit", 1.0, at)
	if f == null or not f.alive: return
	if who != null and who.alive and f.rune("orc_hook"):
		var to := f.pos + flat(f.aim) * float(Races.RUNE.hook_to); var gap := to - who.pos
		if rm.unstoppable(who): return
		var far := gap.length() * (float(Races.THICK.push) if who.race == "dwarf" else 1.0); var dir := flat(gap)
		var q := who.pos
		for i in 8: q = Phys.move_xz(q, dir.x * far / 8.0, dir.z * far / 8.0, who.R, who.H, 0.6)[0]
		q.y = Phys.ground_at(q.x, maxf(q.y, to.y) + 0.6, q.z, who.R); who.pos = q; who.vel = Vector3.ZERO; who.vy = 0.0
		rm.astray(who)
		_say(f, "rm_chain"); rm.note(["hook", f.id, who.id]); return
	var gap2 := at - f.eye_at(); var dist := gap2.length() - (1.3 if who != null else 0.9)
	if dist < 1.0: return
	dash(f, gap2.normalized() * float(W.axe_dash), dist / float(W.axe_dash), "chain"); _say(f, "rm_chain")
	rm.note(["chain", f.id, dist])

# ---------------- what lies or hangs about ----------------
func _field(fd: Dictionary, dt: float) -> void:
	fd.t = float(fd.t) - dt
	var by: Realm.Fighter = fd.by
	match fd.kind:
		"oil":
			for e: Realm.Fighter in rm.all:
				if e.alive and e.team != fd.team and inside(fd, e.pos): rm.slow(e, "oil", float(Races.BOMB.oil.slow), 0.3)
		"fire":
			for e: Realm.Fighter in rm.all:
				if not e.alive or e.team == fd.team or not inside(fd, e.pos): continue
				var d := rm.hurt(e, float(Races.BOMB.oil.fire) * dt, "fire", by, {"dot": true, "aoe": true, "src": "oil", "from": fd.pos})
				rm.burn(e, 0.0, 0.4, by, "oil")
				if d > 0.0 and by != null and by.alive and by.race == "demon": rm.heal(by, d * (float(Races.ULT.demon.steal) if by.ult_t > 0.0 else float(Races.KIN.steal)), by)
			fd.snd = float(fd.get("snd", 0.0)) - dt
			if float(fd.snd) <= 0.0: fd.snd = randf_range(0.5, 0.9); Snd.play("rm_fire", 0.6, fd.pos)
		"frost":
			for e: Realm.Fighter in rm.all:
				if e.alive and e.team != fd.team and inside(fd, e.pos): rm.slow(e, "frost", float(Races.FROST.slow), 0.3); rm.chill(e)
		"gravity":
			var c: Vector3 = fd.pos
			for e: Realm.Fighter in rm.all:
				if not e.alive or e.team == fd.team or rm.unstoppable(e) or e.inv > 0.0: continue
				var gap := Vector3(c.x - e.pos.x, 0, c.z - e.pos.z); var far := gap.length()
				if far > float(fd.r) or far < 0.5 or absf(e.pos.y - c.y) > 4.0: continue
				var pull := float(Races.BOMB.gravity.pull) * (float(Races.THICK.push) if e.race == "dwarf" else 1.0) * dt
				e.pos = Phys.move_xz(e.pos, gap.x / far * pull, gap.z / far * pull, e.R, e.H, 0.5)[0]
		"furnace":
			if by == null or not by.alive or by.ult_t <= 0.0: fd.t = 0.0; return
			fd.pos = by.pos
			for e: Realm.Fighter in rm.all:
				if not e.alive or e.team == fd.team or not inside(fd, e.pos): continue
				var d := rm.hurt(e, float(Races.ULT.demon.burn) * dt, "fire", by, {"dot": true, "aoe": true, "src": "furnace", "from": fd.pos})
				rm.burn(e, 0.0, 0.4, by, "furnace")
				if d > 0.0 and by.alive: rm.heal(by, d * float(Races.ULT.demon.steal), by)
		"trail":
			var a: Vector3 = fd.a; var b: Vector3 = fd.b; var ab := b - a; var l2 := ab.length_squared()
			for e: Realm.Fighter in rm.all:
				if not e.alive or e.team == fd.team: continue
				var t := 0.0 if l2 < 0.0001 else clampf((e.pos - a).dot(ab) / l2, 0.0, 1.0)
				if (a + ab * t).distance_to(e.pos) < 1.2 + e.R: rm.burn(e, float(Races.RUNE.trail_burn), 0.5, by, "hot")
		"dome": _dome(fd, dt)
		"star": _star(fd, dt)

## the dwarf's watchtower and its wall of steam
func _dome(fd: Dictionary, dt: float) -> void:
	var U: Dictionary = Races.ULT.dwarf; var th: Dictionary = fd.thing; var by: Realm.Fighter = fd.by
	if float(th.hp) <= 0.0:
		fd.t = 0.0
		if by != null and by.ult_t > 0.0: by.ult_t = 0.0
		return
	if float(fd.t) <= 0.0: th.hp = 0.0; return
	var near: Realm.Fighter = null; var best := INF; var top: Vector3 = th.pos + Vector3(0, 1.5, 0)
	for e: Realm.Fighter in rm.all:
		if not e.alive: continue
		var within := inside(fd, e.pos)
		if e.team == fd.team:
			if within: rm.shield(e, float(U.shield) * dt, float(U.cap), by)
			continue
		if within:
			rm.slow(e, "dome", float(U.slow), 0.3)
			rm.hurt(e, float(U.burn) * dt, "alchemy", by, {"dot": true, "aoe": true, "src": "steam", "from": fd.pos}); rm.chill(e)
		var far := e.feet_mid().distance_to(top) - (100.0 if within else 0.0)   # (someone inside the wall first)
		if far < best and (within or (far < float(U.reach) and Phys.line_of_sight(top, e.feet_mid()))): best = far; near = e
	fd.bolt_t = float(fd.bolt_t) - dt
	if float(fd.bolt_t) <= 0.0:
		fd.bolt_t = float(U.every)
		if near != null:
			shoot({"kind": "bolt", "pos": top, "vel": (near.feet_mid() - top).normalized() * 60.0, "life": 0.9, "team": fd.team, "by": by, "r": 0.12, "dmg": float(U.bolt), "elem": "physical", "seek": near})
			Snd.play("rm_turret", 0.8, top)

## the elf's rain of star arrows: a warning, then one arrow after another on whoever of the other side is in the ring
func _star(fd: Dictionary, dt: float) -> void:
	var U: Dictionary = Races.ULT.elf; var by: Realm.Fighter = fd.by
	if float(fd.t) > float(U.t): return
	fd.acc = float(fd.acc) + dt; var every := float(U.t) / int(U.arrows)
	while float(fd.acc) >= every and int(fd.n) > 0:
		fd.acc = float(fd.acc) - every; fd.n = int(fd.n) - 1
		var inn: Array = []
		for e: Realm.Fighter in rm.all:
			if e.alive and e.team != fd.team and e.inv <= 0.0 and inside(fd, e.pos): inn.push_back(e)
		var c: Vector3 = fd.pos
		if inn.is_empty():
			var a := randf() * TAU; var r := sqrt(randf()) * float(fd.r)
			rm.look.star(Vector3(c.x + cos(a) * r, c.y, c.z + sin(a) * r), false)
			continue
		var v: Realm.Fighter = inn[int(fd.n) % inn.size()]
		rm.look.star(v.pos, true)
		if v.parry_t > 0.0: Snd.play("rm_parry", 0.8, v.feet_mid()); rm.look.parried(v, v.feet_mid()); rm.note(["parry", v.id, "star"]); continue   # (a dagger held up turns a falling arrow)
		rm.hurt(v, float(U.dmg), "arcane", by, {"ranged": true, "src": "star", "from": v.pos + Vector3(0, 12, 0)})
		v.mark_t = maxf(v.mark_t, float(U.mark))
		Snd.play("rm_meteor", 0.7, v.pos)
