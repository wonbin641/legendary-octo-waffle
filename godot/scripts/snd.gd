extends Node
## Sound effects: the files tools/make_sounds.py made from the browser game's recipes, played through a small pool.

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var volume := 0.7
var listener := Vector3.ZERO
var keep_log := false   # the tests listen in
var played: Array = []

func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new(); add_child(p); _players.push_back(p)

func play(name: String, gain := 1.0, at = null) -> void:
	if keep_log: played.push_back(name)
	if not _streams.has(name):
		var path := "res://sounds/%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	var s = _streams[name]
	if s == null or volume <= 0.0: return
	if at != null: gain *= clampf(1.6 / (1.0 + (at as Vector3).distance_to(listener) * 0.09), 0.04, 1.0)  # farther is quieter
	var p := _players[_next]; _next = (_next + 1) % _players.size()
	p.stream = s; p.volume_db = linear_to_db(maxf(0.0001, gain * volume)); p.pitch_scale = randf_range(0.96, 1.04); p.play()
