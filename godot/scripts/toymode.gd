class_name ToyMode
extends RefCounted
## One of stage 5's team modes: what the two sides are after. ToyMatch runs the toys (who goes where, who shoots whom, who
## comes back after falling); a mode builds its own things into the room, tells each toy where to be, keeps the score and
## says who has won. The player and the blue soldiers are "us", the room's own toys are "them".

var m   # the ToyMatch running it
var key := ""            # rush, escort, freeze
var time_left := 0.0
var lose_stamp := "패배"
var lose_title := ""

## things of its own in the room, built with the room (before the crates are placed and the paths are worked out)
func build_room(_room: ToyRoom) -> void: pass
## a part of the room it builds its own way or leaves out ("south_wall", "train", "tacks_mid", "block_x_z", "sock_x_z")
func skips(_what: String) -> bool: return false
## somewhere no crate may stand (on a way the toys walk, at a base)
func keep_off(_x: float, _z: float, _y: float) -> bool: return false
## the waypoints this mode adds to the room's own: {name: Vector3} and [[a, b, one way?, kind]]
func extra_nodes() -> Dictionary: return {}
func extra_edges() -> Array: return []
func cut_edges() -> Array: return []   # the room's own ways this mode closes ([a, b]: its things stand in the way)
func cut_nodes() -> Array: return []   # ...and waypoints it takes away altogether
## where you come down at the start
func start() -> Dictionary: return {"x": 0.0, "z": 44.0, "yaw": 0.0}
## the two sides at the start (through m.add_unit)
func populate() -> void: pass
## where someone of this side comes back
func spawn_at(_team: String, _who := "") -> Vector3: return Vector3.ZERO
func update(_dt: float) -> void: pass
## where a toy should be going now: {at: Vector3, near: m, hurry: bool, bias: {edge kind: cost}}; empty to stand
func goal(_u: Enemies.Foe) -> Dictionary: return {}
## (bedtime) a toy that must keep still now: it neither walks nor shoots
func hold(_u: Enemies.Foe) -> bool: return false
## (bedtime) a shot was fired, by a toy or by you
func on_shot(_who) -> void: pass
func on_kill(_e: Enemies.Foe, _by: String) -> void: pass
func on_ally_down(_a: Enemies.Foe, _by: String) -> void: pass
func on_player_down() -> void: pass
func on_respawn(_u, _team: String) -> void: pass
## something to shoot at when no enemy is in sight (the train's traps): a point, or null
func spare_target(_u: Enemies.Foe): return null
## the HUD: cells for the box at the top, the bar under it [fraction, colour], lines under that, the line over the crosshair
func hud_cells() -> Array: return []
func hud_bar() -> Array: return [0.0, Color("f2a33a")]
func hud_lines() -> Array: return []
func status() -> String: return ""
## arrows round the crosshair: [Vector2 (x, z), alpha, Color]
func aims() -> Array: return []
## the tactical map: its marks (X and Z turn room metres into the map's pixels; k is pixels a metre, u the marker unit)
func tac(_ci, _X: Callable, _Z: Callable, _k: float, _u: float) -> void: pass
func legend() -> Array: return []
func brief() -> String: return ""
func brief_line() -> String: return ""   # the banner as the fight starts
## (the train escort) a trap on the track has been shot to bits
func trap_broken(_c: Dictionary) -> void: pass
func win_title() -> String: return ""
func pause_line() -> String: return ""
func bonus() -> int: return 30000
func record_key() -> String: return "t9" + key.substr(0, 1)
func state() -> Dictionary: return {}   # for the tests: what the mode holds
func cleanup() -> void: pass           # things of its own to free when the stage goes
func cmd(_a: Array) -> Dictionary: return {}   # the tests' and pictures' commands (main's "tmc ...")
