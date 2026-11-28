class_name Realm
extends RefCounted
## Stage 6's team battles: five against five, each one of the four peoples (Races), on the Silverwood. You are one of
## them, with that people's weapon, passive, Shift and ultimate, the rune dagger and the alchemical bombs everyone carries.
## This is the part every mode shares: who is on the field, what hurts whom and by how much (the elements, the passives,
## the shields), what is on someone (burning, slowed, marked), the ultimates' gauge, the shards and the runes, falling
## and coming back. RealmKit is the weapons and what they throw; RealmAI is the others' minds and their ways about the
## wood; RealmLook is what is seen of it all; the mode (ModeSanctum, ModeSiege) is the rules of the match.

const MODES := ["solo", "sanctum", "siege"]
const NAMES := {"solo": "은빛 경계림 돌파", "sanctum": "성소 각인전", "siege": "비전 핵 공성전", "plain": "네 깃발 평원", "raid": "타락한 마탑 토벌전"}
const SIDE := 5
const SPAWN_SAFE := 2.0            # ours: nothing hurts someone this long after he is back
const SPAWN_HASTE := 1.25          # ours: the base circle's speed for the first four seconds (the papers give the seconds)
const SPAWN_HASTE_T := 4.0
const WELL_HEAL := 15.0; const WELL_HEAL_UP := 25.0
const PORT_CD := 15.0; const PORT_CD_UP := 8.0
const AMP := {"speed": 1.3, "splash": 1.6, "splash_dmg": 0.3}   # the amplifying circle: a shot through it is 30% faster and bursts a little (ours: the burst's size)
const WIND := 1.3

class Fighter extends RefCounted:
	var id := 0; var team := "us"; var race := "elf"; var me := false; var name := ""
	var pos := Vector3.ZERO; var vel := Vector3.ZERO; var vy := 0.0; var grounded := true; var yaw := 0.0; var aim := Vector3(0, 0, -1)
	var R := 0.36; var H := 1.7; var eye := 1.6; var head := 0.3
	var hp := 100.0; var max_hp := 100.0; var shield := 0.0; var over := 0.0   # over: the warlord's extra health
	var alive := true; var back_t := 0.0; var inv := 0.0
	# the weapon
	var ammo := 0; var reload_t := 0.0; var fire_t := 0.0; var charge := 0.0; var charged := false; var sight_done := false
	var heat := 0.0; var seal_t := 0.0; var idle_t := 9.0; var beam_on := false; var beam_acc := 0.0; var beam_end := Vector3.ZERO
	var combo := 0; var swing_t := 0.0; var swing_len := 0.0; var swing_hit := true; var since_swing := 9.0; var quick := false; var hold_t := 0.0
	var alt_cd := 0.0; var vent_done := true
	# Shift, the dagger, the bombs
	var skill_n := 1; var skill_t := 0.0; var skill_gap := 0.0; var steady_t := 0.0
	var dash_t := 0.0; var dash_v := Vector3.ZERO; var dash_kind := ""; var dash_hit := {}; var dash_from := Vector3.ZERO; var leaping := false
	var dag_t := 0.0; var parry_t := 0.0; var parry_cd := 0.0
	var bombs := 1; var bomb_t := 0.0; var bomb_kinds: Array = ["oil"]; var bomb_i := 0
	# what is on him
	var stacks := 0; var stack_t := 0.0
	var burn := 0.0; var burn_t := 0.0; var burn_by: Fighter = null; var burn_src := ""; var burn_acc := 0.0
	var slows := {}                 # why -> [how much, seconds left]
	var haste := 1.0; var haste_t := 0.0; var ley_t := 0.0
	var mark_t := 0.0; var stun_t := 0.0; var phased_t := 0.0; var delay_t := 0.0; var fired_t := 9.0; var port_t := 0.0; var well_t := 0.0; var push := Vector3.ZERO
	# the ultimate
	var gauge := 0.0; var ult_t := 0.0; var ult_more := 0; var cast_t := 0.0
	# the altar
	var runes := {"a": "", "b": "", "c": ""}; var shards := 0; var bonus := 0
	# 6-A's legendary relics: the eclipse overload (seconds left, its wait), the chain axe's hold on him (when, by whom)
	var relic_t := 0.0; var relic_cd := 0.0; var chain_at := -99.0; var chain_by := 0
	var kills := 0; var deaths := 0; var assists := 0; var dealt := 0.0
	var hits := {}                  # who hurt him and when (for the assists)
	var carrying := false           # the siege's bomb on his back
	var brain := {}                 # his own mind (not yours)
	var body := {}                  # what is seen of him (RealmLook)
	func rune(id: String) -> bool: return Races.has(runes, race, id)
	func feet_mid() -> Vector3: return pos + Vector3(0, H * 0.55, 0)
	func eye_at() -> Vector3: return pos + Vector3(0, eye, 0)

var game; var world: World; var wood: ElfWood; var en: Enemies; var player: Player; var guns: Guns; var fx: Fx; var cam: Camera3D
var mode: RealmMode; var key := ""
var kit: RealmKit; var ai: RealmAI; var look: RealmLook
var all: Array = []                # the ten
var me: Fighter = null
var clock := 0.0
var press := {}                    # what you pressed since the last frame: skill, bomb, ult, slash, parry, reload
var stop_t := 0.0                  # a great sword's blow landing: the blow and the struck one hold still this long
var resonant := ""                 # the sanctum's resonance: the side behind (its portals wait less; the well mends more)
var marks: Array = []              # what you were shown on your screen: hits, heads ({t, head, dmg})
var flash := {}                    # the screen's own moments: {"execute": seconds left, "head": .., "wave": ..}
var altar_open := false           # you are at the rune altar: the preparation's clock waits for you
var duck_t := 0.0                  # an ultimate just called: the music steps back this long
var music_break := 0               # the resonances so far: the music holds its breath a bar for each (Music takes this)
var fight_t := 99.0                # seconds since there was a fight about you (a foe in sight near by, you shooting or hurt)
var _fight_look := 0.0
var auto := false                  # your fighter plays itself, as the others do (the checks' matches, a match left to run)
var ai_off := false                # the others stand where they are and press nothing (the checks set a fight up by hand)
var prof := {}                     # (with prof_on: microseconds spent in each part of the frame, for the speed checks)
var prof_on := false
var _id := 0
var _was_grounded := true
var log_on := false; var log: Array = []   # the checks read what happened: [what, ...]

static func create(k: String) -> Realm:
	var rm := Realm.new(); rm.key = k
	rm.mode = ModeSiege.new() if k == "siege" else (ModePlain.new() if k == "plain" else (ModeRaid.new() if k == "raid" else ModeSanctum.new()))
	rm.mode.rm = rm; rm.mode.key = k
	rm.kit = RealmKit.new(); rm.kit.rm = rm; rm.ai = RealmAI.new(); rm.ai.rm = rm; rm.look = RealmLook.new(); rm.look.rm = rm
	return rm

## the mode stage 6-1 is set to play (solo: the elves' wood on your own, as it was)
static func picked() -> String:
	var k := str(Store.settings.get("realmMode", "solo"))
	return k if MODES.has(k) else "solo"

static func picked_race() -> String:
	var k := str(Store.settings.get("realmRace", "elf"))
	return k if Races.ORDER.has(k) else "elf"

static func picked_bomb() -> String:
	var k := str(Store.settings.get("realmBomb", "oil"))
	return k if Races.BOMBS.has(k) else "oil"

func note(what: Array) -> void:
	if log_on: log.push_back(what)

# ---------------- the match ----------------
## the two sides take the field: you and four others (one of each people), and five of theirs (one of each, and one more)
func setup() -> void:
	wood = world.wood if world != null else null
	if wood != null: wood.rm = self
	if player != null: player.realm = true
	mode.build()
	ai.build_graph()
	add("us", picked_race(), true)
	if mode.lineup():
		for r: String in Races.ORDER: add("us", r)
		for r: String in Races.ORDER: add("them", r)
		add("them", Races.ORDER[randi() % Races.ORDER.size()])
	me.bomb_kinds = [picked_bomb()]
	for f: Fighter in all:
		if not f.me: f.bomb_kinds = [Races.BOMBS[randi() % 3]]
		refit(f)
	mode.start()

## the match is decided
func finish(win: bool) -> void:
	if game == null: return
	if win: game.win_match()
	else: game.lose_match()

# ---------------- who is on the field ----------------
func add(team: String, race: String, is_me := false) -> Fighter:
	var f := Fighter.new(); _id += 1; f.id = _id; f.team = team; f.me = is_me
	all.push_back(f)
	if is_me: me = f
	become(f, race); f.gauge = 0.0
	f.name = ("" if is_me else ("아군 " if team == "us" else "적 ")) + str(Races.R[race].name)
	if not is_me: look.build(f)
	return f

## someone off the field for good (6-2's summoned, a while after they fall): his body and his bar go too
func drop(f: Fighter) -> void:
	if f == null or f.me: return
	if f.ult_t > 0.0: kit.ult_end(f)
	look.drop(f); all.erase(f)

## someone takes a people's shape (at the start, or changing between rounds): its body, its health, its weapon full
func become(f: Fighter, race: String) -> void:
	var changed := f.race != race
	f.race = race; var T: Dictionary = Races.R[race]
	f.R = T.r; f.H = T.h; f.eye = T.eye; f.head = T.head; f.max_hp = T.hp; f.hp = f.max_hp
	if changed:   # (another people's runes are nothing to him: what they cost comes back)
		for s in ["a", "b"]:
			var id := str(f.runes[s])
			if id != "" and str(Races.rune_def(id).race) != race: f.shards += cost_of(id); f.runes[s] = ""
	refit(f)
	if f.me and player != null: player.max_hp = f.max_hp; player.hp = f.hp; player.eye = f.eye; player.air_max = air_jumps(f)
	if changed and not f.me and not f.body.is_empty(): look.build(f)

## the weapon full and cold, Shift and the bombs ready: at the start, on coming back, after the altar
func refit(f: Fighter) -> void:
	f.ammo = kit.mag(f); f.reload_t = 0.0; f.fire_t = 0.0; f.charge = 0.0; f.charged = false; f.heat = 0.0; f.seal_t = 0.0; f.combo = 0; f.swing_t = 0.0; f.swing_hit = true
	f.beam_on = false; f.vent_done = true; f.dash_t = 0.0; f.leaping = false
	f.skill_n = kit.charges(f); f.skill_t = 0.0; f.skill_gap = 0.0; f.relic_t = 0.0; f.relic_cd = 0.0
	if f.me and player != null: player.air_max = air_jumps(f)
	var two := f.rune("c_pouch")
	if f.bomb_kinds.is_empty(): f.bomb_kinds = [picked_bomb()]
	if two and f.bomb_kinds.size() < 2: f.bomb_kinds.push_back(Races.BOMBS[(Races.BOMBS.find(f.bomb_kinds[0]) + 1) % 3])
	if not two and f.bomb_kinds.size() > 1: f.bomb_kinds.resize(1)
	f.bombs = f.bomb_kinds.size(); f.bomb_t = 0.0; f.bomb_i = 0

func team_of(team: String) -> Array: return all.filter(func(f): return f.team == team)
## the match's score for the result sheet (its "N 대 M"): what the mode counts
func score(team: String) -> int: return mode.score(team)
func foes_of(f: Fighter) -> Array: return all.filter(func(o): return o.team != f.team and o.alive)
func other(team: String) -> String: return "them" if team == "us" else "us"
func in_play(f: Fighter) -> bool: return f != null and f.alive

# ---------------- what hurts, what mends ----------------
func critical(f: Fighter) -> bool:
	return f.race == "demon" and f.alive and f.heat >= (float(Races.RUNE.core_crit) if f.rune("dm_core") else float(Races.STAFF.crit)) and f.seal_t <= 0.0

## whether someone faces a place (an orc's bloodlust turns shots from the front only)
func faces(f: Fighter, at: Vector3) -> bool:
	var to := Vector2(at.x - f.pos.x, at.z - f.pos.z)
	if to.length() < 0.01: return true
	return Vector2(f.aim.x, f.aim.z).normalized().dot(to.normalized()) > 0.25

## a hit. o: head (a multiplier), ranged, aoe, blast, melee, dot (a burn's or a field's tick), fixed (no sums done on it),
## fog (it came through fog or frost), from (where it came from), src (what did it)
func hurt(v: Fighter, dmg: float, elem: String, by: Fighter, o := {}) -> float:
	if v == null or not v.alive or dmg <= 0.0 or (game != null and bool(game.ended)) or not mode.fighting(): return 0.0
	if by != null and by.team == v.team and by != v: return 0.0
	if v.inv > 0.0: return 0.0
	if v.me and Store.settings.dev and Store.settings.god: return 0.0
	var from: Vector3 = o.get("from", by.eye_at() if by != null else v.pos)
	var d := dmg
	if not o.get("fixed", false):
		var front: bool = v.race == "orc" and v.stacks > 0 and bool(o.get("ranged", false)) and faces(v, from)
		var m := Races.affinity(elem, {"shield": v.shield > 0.0 or front, "fog": o.get("fog", false), "dwarf": v.race == "dwarf", "phased": v.phased_t > 0.0, "critical": critical(v)})
		var hm := float(o.get("head", 1.0))
		if hm > float(Races.RUNE.plate_head) and v.shield > 0.0 and v.rune("dw_plate"): hm = float(Races.RUNE.plate_head)
		m *= hm
		if v.race == "dwarf" and bool(o.get("aoe", false)) and (elem == "fire" or bool(o.get("blast", false))): m *= float(Races.THICK.aoe)
		if front: m *= 1.0 - float(Races.LUST.front) * v.stacks
		if bool(o.get("ranged", false)) and kit.domed(v, from): m *= float(Races.ULT.dwarf.cut)
		d = dmg * m * mode.dmg_mul(by, v)
	# the shield first, then the warlord's extra health, then his own
	var left := d
	if v.shield > 0.0:
		var s := minf(v.shield, left); v.shield -= s; left -= s
		if not o.get("dot", false): look.shield_hit(v, elem, o.get("at", v.feet_mid()))
	if v.over > 0.0 and left > 0.0: var ov := minf(v.over, left); v.over -= ov; left -= ov
	v.hp -= left
	if by != null and by != v:
		by.dealt += d; gain(by, d * float(Races.GAUGE.dmg)); v.hits[by.id] = clock
		if by.me and not o.get("dot", false): marks.push_back({"t": 0.0, "head": float(o.get("head", 1.0)) > 1.0, "dmg": d}); Snd.play("rm_head" if float(o.get("head", 1.0)) > 1.0 else "rm_hit", 0.7)
	if not o.get("dot", false): look.struck(v, elem, o.get("at", v.feet_mid()), from, d)
	if v.me and player != null:
		player.since_hurt = 0.0
		if not o.get("dot", false): player.shake = maxf(player.shake, 0.1 + d * 0.004)
		if player.on_hurt.is_valid(): player.on_hurt.call(d, from)
	note(["hurt", v.id, by.id if by != null else 0, d, elem, str(o.get("src", ""))])
	if v.hp <= 0.0: down(v, by, o)
	return d

## the dagger's finishing blow, or anything else nothing turns aside
func slay(v: Fighter, by: Fighter, o := {}) -> void:
	var q := o.duplicate(); q.fixed = true
	hurt(v, v.hp + v.shield + v.over + 1.0, "physical", by, q)

func heal(f: Fighter, amount: float, by: Fighter = null) -> float:
	if f == null or not f.alive or amount <= 0.0: return 0.0
	var m := 1.0   # (burning: 30% less of it; in a demon's furnace, or Baal's: half, the worse of the two and not both)
	if kit.in_furnace(f) or mode.furnace(f): m = float(Races.ULT.demon.heal_cut)
	elif f.burn_t > 0.0: m = Races.BURN_HEAL
	var a := minf(amount * m, f.max_hp - f.hp)
	if a <= 0.0: return 0.0
	f.hp += a
	if by != null: gain(by, a * float(Races.GAUGE.heal))
	return a

## a temporary shield, up to a cap (a dwarf's by his runes, the steam wall's)
func shield(f: Fighter, amount: float, cap: float, by: Fighter = null) -> float:
	if f == null or not f.alive or f.shield >= cap: return 0.0
	var m := float(Races.ULT.demon.heal_cut) if (kit.in_furnace(f) or mode.furnace(f)) else 1.0
	var a := minf(amount * m, cap - f.shield); f.shield += a
	if by != null: gain(by, a * float(Races.GAUGE.heal))
	return a

func gain(f: Fighter, pts: float) -> void:
	if f == null or f.ult_t > 0.0 or pts <= 0.0: return
	var full := float(Races.GAUGE.max); var was := f.gauge
	f.gauge = minf(full, f.gauge + pts)
	if f.me and was < full and f.gauge >= full: Snd.play("rm_ult_ready"); game.say_feed("비전 비기 준비 완료 · X")

## fire on someone: so much a second for so long (the stronger and the longer of what is already on him and this)
func burn(v: Fighter, dps: float, t: float, by: Fighter, src := "") -> void:
	if v == null or not v.alive or (by != null and by.team == v.team): return
	if dps >= v.burn or v.burn_t <= 0.0: v.burn = dps; v.burn_by = by; v.burn_src = src
	v.burn_t = maxf(v.burn_t, t)

func slow(v: Fighter, why: String, mul: float, t: float) -> void:
	if v == null or not v.alive or unstoppable(v): return
	v.slows[why] = [mul, t]

func unstoppable(f: Fighter) -> bool: return f.race == "orc" and f.ult_t > 0.0

## shoved or pulled: so far, that way (a dwarf half as far; the warlord not at all). true: a wall stopped him short
func shove(v: Fighter, dir: Vector3, dist: float) -> bool:
	if v == null or not v.alive or unstoppable(v) or dist <= 0.0: return false
	if mode.heavy(v): slow(v, "shove", 0.55, 1.2); return false   # (6-A's lords: not moved, only slowed)
	if v.race == "dwarf": dist *= float(Races.THICK.push)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.001: return false
	d = d.normalized()
	var wall := Phys.raycast_static(v.pos + Vector3(0, v.H * 0.5, 0), d, dist + v.R)
	v.push += d * dist * 6.0   # (a speed that dies away at 6 a second carries him that far)
	return wall

## alchemy's cold on a demon at critical heat: the staff goes cold and he is slowed
func chill(v: Fighter) -> void:
	if v.race != "demon" or v.ult_t > 0.0: return
	if critical(v): slow(v, "chill", Races.SLOW_HIT_MUL, Races.SLOW_HIT)
	v.heat = 0.0

func add_stack(f: Fighter) -> void:
	if f.race != "orc" or not f.alive: return
	f.stacks = mini(max_stacks(f), f.stacks + 1); f.stack_t = float(Races.LUST.t)

func max_stacks(f: Fighter) -> int: return int(Races.RUNE.roar_max) if f.rune("orc_roar") else int(Races.LUST.max)

## how fast his feet are now
func speed_of(f: Fighter) -> float:
	var s := float(Races.R[f.race].speed)
	if f.race == "orc": s *= 1.0 + float(Races.LUST.speed) * f.stacks
	if critical(f): s *= float(Races.KIN.speed)
	if f.haste_t > 0.0: s *= f.haste
	if f.ley_t > 0.0: s *= float(Races.RUNE.ley_speed)
	if not unstoppable(f):
		var m := 1.0
		for k in f.slows: m = minf(m, float(f.slows[k][0]))
		s *= m
	if f.carrying: s *= 0.9
	return s

# ---------------- falling and coming back ----------------
func down(v: Fighter, by: Fighter, o := {}) -> void:
	if not v.alive: return
	v.alive = false; v.hp = 0.0; v.deaths += 1; v.back_t = mode.back_time(v)
	v.burn_t = 0.0; v.burn = 0.0; v.slows.clear(); v.stacks = 0; v.shield = 0.0; v.over = 0.0; v.charge = 0.0; v.charged = false; v.beam_on = false; v.dash_t = 0.0; v.parry_t = 0.0; v.mark_t = 0.0; v.push = Vector3.ZERO
	if v.ult_t > 0.0: kit.ult_end(v)
	var helpers: Array = []
	for id in v.hits:
		var h := by_id(int(id))
		if h != null and h != by and h.alive and by != null and h.team == by.team and clock - float(v.hits[id]) <= Races.ASSIST_T: helpers.push_back(h)
	v.hits.clear()
	if by != null and by != v:
		by.kills += 1; by.bonus = mini(3, by.bonus + 1)
		gain(by, float(Races.GAUGE.kill) if helpers.is_empty() else float(Races.GAUGE.assist))
		add_stack(by)
		if by.race == "elf" and float(o.get("head", 1.0)) > 1.0: by.skill_t = maxf(0.0, by.skill_t - float(Races.SKILL.elf.refund))
		if by.race == "orc" and bool(o.get("melee", false)): by.skill_t = 0.0; by.skill_n = 1
		if by.race == "orc" and by.ult_t > 0.0 and by.ult_more < int(Races.ULT.orc.more_n): by.ult_more += 1; by.ult_t += float(Races.ULT.orc.more)
		if by.rune("orc_roar"): heal(by, float(Races.RUNE.roar_heal), by)
		if by.rune("rl_chain") and v.chain_by == by.id and clock - v.chain_at <= float(RaidLoot.RELIC.chain_t) and str(o.get("src", "")).begins_with("sword"):   # (Karnok's axe: one it held felled by the sword, the axe again at once)
			by.alt_cd = 0.0; Snd.play("rd_relic_chain", 0.9, by.eye_at()); note(["chain_reset", by.id])
	for h: Fighter in helpers: h.assists += 1; gain(h, float(Races.GAUGE.assist)); add_stack(h)
	look.fell(v, by, o)
	mode.on_down(v, by)
	note(["down", v.id, by.id if by != null else 0, helpers.size(), str(o.get("src", ""))])
	if game != null:
		var how := " 처형" if o.get("execute", false) else (" · 머리 명중" if float(o.get("head", 1.0)) > 1.0 else " 처치")
		if by != null and by.me: game.say_feed(v.name + how); Snd.play("kill"); game.stats.kills += 1; game.kills += 1
		elif v.me: game.say_feed((by.name if by != null else "전장") + "에게 쓰러졌습니다")
		elif by != null: game.say_feed(by.name + " → " + v.name)
	if v.me and player != null:
		player.out = true; player.hp = 0.0; player.vel = Vector3.ZERO; player.dash_t = 0.0; guns.trigger = false; guns.ads_held = false
		if game != null: game.say_banner("쓰러졌습니다", mode.down_line(v), 2.0); Snd.play("thud")

## moved by something other than his own feet (a portal, a hook, a trap): the way he was walking is no good now
func astray(f: Fighter) -> void:
	if f.brain.has("path"): f.brain["path"] = []; f.brain["gat"] = null; f.brain["repath"] = 0.0; f.brain["think"] = 0.0

## you take over another of your side (6-A's party: Tab): the one you were goes on by himself, seen again, and you see
## through the other's eyes from where he stands, as he is (his health, his weapon, Shift, the bombs, the gauge)
func switch_me(to: Fighter) -> bool:
	if to == null or to == me or not to.alive or me == null or to.team != me.team or to.brain.has("mon"): return false
	var old := me
	if player != null:
		old.pos = player.pos; old.vel = Vector3(player.vel.x, 0.0, player.vel.z); old.vy = player.vel.y; old.grounded = player.grounded
		if not old.grounded and not old.leaping and old.alive: old.vy = minf(old.vy, 0.0)
	old.me = false; old.brain.clear(); old.charge = 0.0; old.charged = false; old.beam_on = false
	if old.dash_t > 0.0: old.dash_t = 0.0; old.dash_kind = ""
	to.me = true; me = to; to.brain.clear()
	look.build(old); look.drop(to)
	if player != null:
		player.reset(to.pos.x, to.pos.z, to.yaw); player.pos.y = to.pos.y; player.out = false
		player.max_hp = to.max_hp; player.hp = to.hp; player.eye = to.eye; player.air_max = air_jumps(to)
		_was_grounded = true
	if guns != null: guns.trigger = false; guns.ads_held = false
	if to.leaping and player != null: player.launch(Vector3(to.vel.x, maxf(to.vy, 0.0), to.vel.z))
	to.vel = Vector3.ZERO
	note(["switch", old.id, to.id])
	return true

func by_id(id: int) -> Fighter:
	for f: Fighter in all:
		if f.id == id: return f
	return null

## whole again and nothing on him: health, the weapon, Shift and the bombs; no fire, slows, marks, shields or stacks
func mend(f: Fighter) -> void:
	f.alive = true; f.back_t = 0.0; f.hp = f.max_hp; f.burn_t = 0.0; f.burn = 0.0; f.burn_by = null; f.slows.clear(); f.stacks = 0; f.stack_t = 0.0; f.shield = 0.0; f.over = 0.0; f.ult_t = 0.0; f.ult_more = 0; f.cast_t = 0.0
	f.stun_t = 0.0; f.mark_t = 0.0; f.carrying = false; f.push = Vector3.ZERO; f.inv = 0.0; f.haste_t = 0.0; f.ley_t = 0.0; f.phased_t = 0.0; f.delay_t = 0.0; f.port_t = 0.0; f.parry_t = 0.0; f.parry_cd = 0.0; f.dag_t = 0.0; f.alt_cd = 0.0
	f.hold_t = 0.0; f.quick = false; f.since_swing = 9.0; f.idle_t = 9.0; f.fired_t = 9.0; f.hits.clear()
	refit(f)

## back at the base circle: whole, the weapon full, and quick on his feet for a few seconds
func back(f: Fighter) -> void:
	var p := mode.spawn_at(f)
	f.alive = true; f.hp = f.max_hp; f.pos = p; f.vel = Vector3.ZERO; f.vy = 0.0; f.grounded = true; f.inv = SPAWN_SAFE; f.back_t = 0.0
	f.haste = SPAWN_HASTE; f.haste_t = SPAWN_HASTE_T; f.brain.clear()
	refit(f)
	var face := mode.face_at(f, p); f.yaw = face; f.aim = Vector3(-sin(face), 0, -cos(face))
	if f.me and player != null:
		player.reset(p.x, p.z, face); player.pos.y = p.y; player.out = false; player.hp = f.hp; Snd.play("rm_spawn")
		if game != null: game.say_banner("다시 출전", mode.back_line(), 1.2)
	else: Snd.play("rm_spawn", 0.6, p)
	look.came_back(f)
	mode.on_back(f)

# ---------------- the frame ----------------
func update(dt: float) -> void:
	clock += dt
	stop_t = maxf(0.0, stop_t - dt); duck_t = maxf(0.0, duck_t - dt); fight_t += dt
	for k in flash.keys():
		flash[k] = float(flash[k]) - dt
		if float(flash[k]) <= 0.0: flash.erase(k)
	for i in range(marks.size() - 1, -1, -1):
		marks[i].t = float(marks[i].t) + dt
		if float(marks[i].t) > 0.6: marks.remove_at(i)
	var t0 := Time.get_ticks_usec() if prof_on else 0
	_you_in()
	mode.update(dt)
	for f: Fighter in all:
		if not f.alive:
			if f.back_t > 0.0 and not (game != null and bool(game.ended)):
				f.back_t -= dt
				if f.back_t <= 0.0: back(f)
			continue
		_state(f, dt)
		if f.brain.has("mon"): mode.turn(f, dt)   # (6-A's demons: their minds are the mode's)
		elif f.me and not auto: kit.act(f, _hands(), dt)
		elif ai_off: kit.act(f, {}, dt)
		else: ai.turn(f, dt)
	press.clear()
	var t1 := Time.get_ticks_usec() if prof_on else 0
	kit.step(dt)
	var t2 := Time.get_ticks_usec() if prof_on else 0
	_circles(dt)
	_you_out(dt)
	_heat(dt)
	var t3 := Time.get_ticks_usec() if prof_on else 0
	look.update(dt)
	if prof_on:
		var t4 := Time.get_ticks_usec()
		for q: Array in [["minds", t1 - t0], ["flying", t2 - t1], ["circles", t3 - t2], ["look", t4 - t3]]: prof[q[0]] = int(prof.get(q[0], 0)) + int(q[1])
		prof.frames = int(prof.get("frames", 0)) + 1

## a fight about you, for the music: you shooting, you hurt, or a foe in sight within 35 m (looked for three times a second)
func _heat(dt: float) -> void:
	if me == null or not me.alive: return
	if me.fired_t < 0.3 or player != null and player.since_hurt < 0.3: fight_t = 0.0
	_fight_look -= dt
	if _fight_look > 0.0: return
	_fight_look = 0.33
	for e: Fighter in all:
		if e.alive and e.team != me.team and e.pos.distance_to(me.pos) < 35.0 and kit.sees(me, e, 35.0): fight_t = 0.0; return

## what the music should follow (Music): the set, how far the match has come, a fight about you, the resonances, an
## ultimate near you, the overtime's climb
func music() -> Dictionary:
	return {"what": "realm", "set": mode.music_set(), "stage": mode.music_stage(), "fight": fight_t < 2.0, "breaks": music_break, "duck": duck_t > 0.0, "semis": mode.music_semis()}

## you: where the player is, into your fighter
func _you_in() -> void:
	if me == null or player == null: return
	me.pos = player.pos
	if auto: return
	me.vel = player.vel; me.grounded = player.grounded; me.yaw = player.yaw
	if cam != null: me.aim = -cam.global_basis.z
	else: me.aim = Vector3(-sin(player.yaw) * cos(player.pitch), sin(player.pitch), -cos(player.yaw) * cos(player.pitch))
	# an orc's bound ends where he lands
	if me.leaping and player.grounded and not _was_grounded:   # (he comes down where the bound ends: no sliding on)
		me.leaping = false; player.vel.x = 0.0; player.vel.z = 0.0
		if me.brain.has("fling"): me.brain.erase("fling")   # (6-A: one of the others thrown up by a gravity circle, and you took his place in the air)
		else: kit.landed(me)
	_was_grounded = player.grounded

func _hands() -> Dictionary:
	var held: bool = mode.held(me) or player.out or bool(game.ended) if game != null else false
	var mv := Vector3.ZERO
	if player != null:
		var sy := sin(player.yaw); var cy := cos(player.yaw)
		mv = Vector3(-sy * player.in_f + cy * player.in_s, 0, -cy * player.in_f - sy * player.in_s)
	return {"fire": guns.trigger and not held, "alt": guns.ads_held and not held, "reload": press.has("reload"), "skill": press.has("skill") and not held, "bomb": press.has("bomb") and not held,
		"ult": press.has("ult") and not held, "slash": press.has("slash") and not held, "parry": press.has("parry") and not held, "move": mv}

## your fighter, back into the player: health, speed, the push of a shove, a dash
func _you_out(dt: float) -> void:
	if me == null or player == null: return
	guns.none = true
	player.hp = maxf(0.0, me.hp); player.max_hp = me.max_hp + me.over
	if me.alive and player.pos != me.pos: player.pos = me.pos; player.vel = Vector3.ZERO if auto else me.vel   # (a portal, a pull: the fight moved you)
	if auto: player.yaw = atan2(-me.aim.x, -me.aim.z); player.pitch = asin(clampf(me.aim.y, -1.0, 1.0)); player.grounded = true; player.vel = Vector3.ZERO
	player.move_mul = speed_of(me) / 5.4 * (0.0 if (mode.held(me) and mode.rooted()) else 1.0); player.no_sprint = true; player.ads = 0.0; player.ads_slow = 1.0; player.sens_mul = 1.0
	guns.ads = 0.0   # (the right button is your people's own: no gun comes up to the eye)
	if cam != null: cam.fov = guns.base_fov + 2.0 * clampf(float(flash.get("wave", 0.0)) / 0.18, 0.0, 1.0)   # (the orc's wave: the view opens 2 degrees and comes back)
	if me.push.length() > 0.05:
		var q := Phys.move_xz(player.pos, me.push.x * dt, me.push.z * dt, Player.R, Player.HEIGHT, 0.5); player.pos = q[0]; me.pos = player.pos
	me.push *= exp(-dt * 6.0)
	if me.stun_t > 0.0: player.move_mul = 0.0

## what is on someone, a frame of it: fire, slows, the passives, the gauge by the clock
func _state(f: Fighter, dt: float) -> void:
	f.inv = maxf(0.0, f.inv - dt); f.haste_t = maxf(0.0, f.haste_t - dt); f.ley_t = maxf(0.0, f.ley_t - dt); f.mark_t = maxf(0.0, f.mark_t - dt); f.stun_t = maxf(0.0, f.stun_t - dt)
	f.phased_t = maxf(0.0, f.phased_t - dt); f.delay_t = maxf(0.0, f.delay_t - dt); f.fired_t += dt; f.port_t = maxf(0.0, f.port_t - dt)
	for k in f.slows.keys():
		f.slows[k][1] = float(f.slows[k][1]) - dt
		if float(f.slows[k][1]) <= 0.0: f.slows.erase(k)
	if f.burn_t > 0.0:
		f.burn_t -= dt
		var by := f.burn_by; var src := f.burn_src
		var d := hurt(f, f.burn * dt, "fire", by, {"dot": true, "src": "burn"})
		if d > 0.0 and by != null and by.alive and by.race == "demon" and (src == "hot" or src == "oil"):   # the demon's kinship with fire: a part of it mends him
			heal(by, d * (float(Races.ULT.demon.steal) if by.ult_t > 0.0 else float(Races.KIN.steal)), by)
		f.burn_acc += dt
		if f.burn_acc > 0.4 and f.alive: f.burn_acc = 0.0; look.burning(f)
		if f.burn_t <= 0.0: f.burn = 0.0; f.burn_by = null
	if not f.alive: return
	if f.stacks > 0:
		f.stack_t -= dt
		if f.stack_t <= 0.0 and f.ult_t <= 0.0: f.stacks = 0
	if f.race == "dwarf" and kit.near_own_work(f): shield(f, float(Races.THICK.shield) * dt, float(Races.RUNE.plate_cap) if f.rune("dw_plate") else float(Races.THICK.cap), f)
	if mode.fighting(): gain(f, float(Races.GAUGE.sec) * dt)
	# the non-player's push dies away as it carries him (yours is done with the player's own body)
	if not f.me and f.push.length() > 0.05:
		f.pos = Phys.move_xz(f.pos, f.push.x * dt, f.push.z * dt, f.R, f.H, 0.5)[0]
	if not f.me: f.push *= exp(-dt * 6.0)

## the wood's circles, for everyone: the moonwell mends, the portals carry, the wind path hastens
func _circles(dt: float) -> void:
	if wood == null: return
	var up := resonant != ""
	for f: Fighter in all:
		if not f.alive: continue
		var in_well := Vector2(f.pos.x - ElfWood.WELL.x, f.pos.z - ElfWood.WELL.z).length() < ElfWood.WELL_R and f.pos.y < ElfWood.WELL.y + 1.2 and f.pos.y > -0.2
		if in_well and mode.fighting():
			var a := heal(f, (WELL_HEAL_UP if up else WELL_HEAL) * dt, f)
			if a > 0.0 and f.me:
				f.well_t -= dt
				if f.well_t <= 0.0: f.well_t = 1.4; Snd.play("elf_well", 0.6)
		if f.port_t <= 0.0 and mode.fighting():
			for q: Dictionary in wood.portals:
				var a: Vector3 = q.a
				if Vector2(f.pos.x - a.x, f.pos.z - a.z).length() < float(q.r) and absf(f.pos.y - a.y) < 0.9: _port(f, q); break
		# (your own feet on the wind path are the wood's doing: ElfWood.update)
		if not f.me and f.pos.x > ElfWood.WIND[0] and f.pos.x < ElfWood.WIND[1] and absf(f.pos.z) < ElfWood.WIND[2] and f.pos.y < 1.0:
			f.haste = maxf(f.haste if f.haste_t > 0.0 else 1.0, WIND); f.haste_t = maxf(f.haste_t, 0.3)

func _port(f: Fighter, q: Dictionary) -> void:
	var b: Vector3 = q.b
	var cd := PORT_CD_UP if (resonant == f.team) else PORT_CD
	if f.rune("c_ley"): cd *= float(Races.RUNE.ley_cd); f.ley_t = float(Races.RUNE.ley_t)
	f.port_t = cd; f.fired_t = 0.0
	Snd.play("rm_bell", 1.0, q.a); Snd.play("rm_bell_pre", 0.8, b)
	f.pos = b + Vector3(0, 0.05, 0); f.vel = Vector3.ZERO; f.vy = 0.0
	if f.me and player != null: player.pos = f.pos; player.vel = Vector3.ZERO; player.shake = maxf(player.shake, 0.2)
	astray(f)
	look.ported(f, q.a, b)

# ---------------- the shards and the runes ----------------
func cost_of(id: String) -> int: return int(Races.rune_def(id).get("cost", 0))
## the jumps someone may take in the air: an elf one (two with the abyss wings' relic)
func air_jumps(f: Fighter) -> int:
	if f.race != "elf": return 0
	return int(RaidLoot.RELIC.wing_air) if f.rune("rl_wing") else 1

## cut a rune at the altar: what was in its slot is given back for what it cost. false: not enough shards, or not his people's
func buy(f: Fighter, id: String) -> bool:
	if RaidLoot.RELICS.has(id): return fit_relic(f, id)
	if not Races.RUNES.has(id): return false
	var q: Dictionary = Races.RUNES[id]; var slot: String = q.slot
	if str(q.race) != "" and str(q.race) != f.race: return false
	if str(f.runes[slot]) == id: return true
	var back := cost_of(str(f.runes[slot])) if str(f.runes[slot]) != "" else 0
	if f.shards + back < int(q.cost): return false
	f.shards += back - int(q.cost); f.runes[slot] = id
	refit(f)
	return true

## a legendary relic into its slot: only in the raid (mode.relics), only one you have, only your people's (the ward: anyone's),
## and only one of the party carries each; what was in the slot is given back
func fit_relic(f: Fighter, id: String) -> bool:
	var q: Dictionary = RaidLoot.RELICS[id]; var slot: String = q.slot
	if not mode.relics() or not RaidLoot.has_relic(id): return false
	if str(q.race) != "" and str(q.race) != f.race: return false
	for o: Fighter in all:
		if o != f and o.team == f.team and o.rune(id): return false
	if str(f.runes[slot]) == id: return true
	var back := cost_of(str(f.runes[slot])) if str(f.runes[slot]) != "" else 0
	f.shards += back; f.runes[slot] = id
	refit(f)
	return true

func sell(f: Fighter, slot: String) -> void:
	var id := str(f.runes[slot])
	if id == "": return
	f.shards += cost_of(id); f.runes[slot] = ""; refit(f)

func clear() -> void:
	if wood != null: wood.rm = null
	mode.cleanup(); kit.clear(); look.clear()
	if player != null: player.max_hp = Player.MAX_HP; player.eye = Player.EYE; player.air_max = 0; player.realm = false; player.out = false
	all.clear(); me = null
