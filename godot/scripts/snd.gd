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

## a sound that keeps going (the helicopter's rotor): started at a level, held there while it is called again, stopped at 0
var _loops := {}
func loop(name: String, gain: float) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if gain <= 0.0 or volume <= 0.0:
		if p != null and p.playing: p.stop()
		return
	if p == null:
		var path := "res://sounds/%s.wav" % name
		if not ResourceLoader.exists(path): return
		var w := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = w.data.size() / 2   # sixteen-bit, one channel
		p = AudioStreamPlayer.new(); p.stream = w; add_child(p); _loops[name] = p
	p.volume_db = linear_to_db(maxf(0.0001, gain * volume))
	if not p.playing:
		p.play()
		if keep_log: played.push_back(name)

## a short buzz of the phone, where the browser game has one (only with the touch controls; nothing elsewhere)
var touch := false
func buzz(ms: int) -> void:
	if touch: Input.vibrate_handheld(ms)
