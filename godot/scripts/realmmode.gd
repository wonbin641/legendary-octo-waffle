class_name RealmMode
extends RefCounted
## A realm battle's rules: what the two sides are after, the rounds and their parts, where each comes back and how soon,
## and what the screens say of it. ModeSanctum and ModeSiege are the two there are.

var rm: Realm
var key := ""
var phase := "fight"         # prep (in the base, the altar open), wait (out, the goal still shut), fight, over (a round done), end
var phase_t := 0.0           # seconds of this part left (0: it has no clock)
var round_n := 1
var wins := {"us": 0, "them": 0}
var won := ""                # the match's winner, once there is one
var lose_stamp := "패배"; var lose_title := "전투에서 졌습니다"

func build() -> void: pass                 # its own things on the map, made with it
func start() -> void: pass                 # the two sides step out: the first round
func update(_dt: float) -> void: pass
func cleanup() -> void: pass

## whether blows land now (not in the base before a round, nor once it is decided)
func fighting() -> bool: return phase == "wait" or phase == "fight"
## whether someone is kept from acting (the preparation: nobody strikes; a round just over)
func held(_f: Realm.Fighter) -> bool: return phase == "prep" or phase == "over" or phase == "end"
## whether the held stand still as well (a round just over), or may walk about inside the base's shield (the preparation)
func rooted() -> bool: return phase == "over" or phase == "end"
## whether the rune altar can be opened now, and what you are told when it cannot
func altar_ok() -> bool: return phase == "prep"
func altar_why() -> String: return "룬 제단은 준비 시간에만 열 수 있습니다"
## whether the match is five a side from the start (6-2 has you alone and what its landmarks summon)
func lineup() -> bool: return true
## whether the mode brings its own waypoints only (RealmAI: not the Silverwood's)
func own_graph() -> bool: return false
## whether a win is the stage cleared too (6-2; 6-1's battles are its own records beside the stage)
func clears() -> bool: return false
## what a blow is worth, by who strikes whom (6-2: the summoned against you, its hero, a little less)
func dmg_mul(_by: Realm.Fighter, _v: Realm.Fighter) -> float: return 1.0
## what you are told when you fall, and where you come back
func down_line(f: Realm.Fighter) -> String: return "%d초 뒤 본진 마법진에서 다시 일어납니다" % ceili(f.back_t)
func back_line() -> String: return "본진 마법진"
func base_of(_team: String) -> Vector3: return Vector3.ZERO
func spawn_at(f: Realm.Fighter) -> Vector3:
	var b := base_of(f.team); var i := rm.team_of(f.team).find(f); var a := i * TAU / 5.0
	var p := b + Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
	p.y = Phys.ground_at(p.x, b.y + 0.6, p.z, 0.3)
	return p
## the way someone faces as he comes back (the player's turn: 0 looks along -z)
func face_at(f: Realm.Fighter, p: Vector3) -> float:
	var to := aim_point(f.team) - p
	return atan2(-to.x, -to.z)
func aim_point(_team: String) -> Vector3: return Vector3.ZERO
func back_time(_f: Realm.Fighter) -> float: return 7.0
func on_down(_v: Realm.Fighter, _by: Realm.Fighter) -> void: pass
func on_back(_f: Realm.Fighter) -> void: pass
## where one of the others should be going: {at, near, hurry} (hurry: he does not stop to fight on the way)
func goal(_f: Realm.Fighter) -> Dictionary: return {}
## places a side has made its own (a dwarf's shield fills by them)
func works(_team: String) -> Array: return []
func amp_owner() -> String: return ""
func extra_nodes() -> Dictionary: return {}   # the mode's own waypoints and ways (RealmAI's graph)
func extra_edges() -> Array: return []
## something of the mode's the others should strike rather than a person (the nucleus), or null
func prize(_f: Realm.Fighter): return null
## what one of the others should strike before anyone else, whatever is nearer (6-A: a boss's crystal, a chain, a core), or null
func focus(_f: Realm.Fighter): return null
## whether one of the others should jump now (6-A: a wave of fire coming at his feet)
func jump(_f: Realm.Fighter) -> bool: return false

# ---------------- fighters the mode moves itself (6-A's demons) ----------------
func turn(_f: Realm.Fighter, _dt: float) -> void: pass      # its turn, in the realm's frame (for a fighter whose brain has "mon")
func place(_f: Realm.Fighter, _dt: float) -> bool: return false   # its body, each frame (true: seen to)
func fell(_f: Realm.Fighter) -> bool: return false          # its fall (true: seen to)
func struck(_s: Dictionary, _who: Realm.Fighter) -> void: pass   # a missile has just struck someone
func bomb_burst(_at: Vector3) -> void: pass                  # an alchemical bomb has just burst there
func furnace(_f: Realm.Fighter) -> bool: return false        # whether someone stands in a fire that halves what mends him
func heavy(_f: Realm.Fighter) -> bool: return false          # whether a shove only slows him (a lord of 6-A)

# ---------------- the screens ----------------
func hud() -> Dictionary: return {}        # what the top of the screen shows: {title, left, right, clock, bars...}
func brief_line() -> String: return ""
func brief() -> Array: return []
func win_title() -> String: return "승리"
func pause_line() -> String: return str(Realm.NAMES.get(key, ""))
func record_key() -> String: return "t10" + key.substr(0, 2)   # (t10sa, t10si: beside the stages' own best times)
func bonus() -> int: return 0
func tac() -> Array: return []             # marks for the map: [{x, z, c, r, label}]
func marks() -> Array: return []           # marks over the view: [{at, c, label}]
func music_set() -> String: return "rf"    # the music (Music): the set, how far the match has come (1..4), the overtime's semitones
func music_stage() -> int: return 1
func music_semis() -> int: return 0
func state() -> Dictionary: return {"phase": phase, "round": round_n, "wins": wins}
## the result sheet's score for a side: the foes its fighters felled, unless the mode counts something else (the sanctum: rounds)
func score(team: String) -> int:
	var n := 0
	for f: Realm.Fighter in rm.all:
		if f.team == team: n += f.kills
	return n

# ---------------- the rounds' parts, shared ----------------
func set_phase(p: String, t := 0.0) -> void:
	phase = p; phase_t = t
	rm.note(["phase", p, round_n])

## everyone back in his base, whole, as a round begins (the dead too)
func muster() -> void:
	rm.kit.clear()
	for f: Realm.Fighter in rm.all: rm.mend(f); rm.back(f); f.inv = 0.0; f.haste_t = 0.0

## the others spend what shards they have: the dearest rune they can pay for in each empty slot
func shop_ai() -> void:
	for f: Realm.Fighter in rm.all:
		if f.me: continue
		for slot in ["a", "b", "c"]:
			if str(f.runes[slot]) != "": continue
			var best := ""; var cost := 0
			for id: String in Races.runes_for(f.race, slot):
				var c := int(Races.RUNES[id].cost)
				if c <= f.shards and c > cost: best = id; cost = c
			if best != "": rm.buy(f, best)
