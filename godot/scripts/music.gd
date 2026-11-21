extends Node
## Stage 5's music (made by tools/make_music.py): "the toy soldiers' march", a march's grammar played on children's
## instruments. Six layers of one 16-bar loop go round together, and only their levels change with what is happening:
##   spawn   at your base, or down and waiting to come back: the music box and a light wood block, a clock far off
##   explore on the move: the xylophone and pizzicato over the wood block and castanets, the boomwhackers lightly
##   bed     under the bed: only the boomwhackers and the clock's tick-tock, through a low-pass (close, stuffy air)
##   battle  a big fight: everything, the kazoos and recorders, the tin drum, the toy piano's arpeggios
## The briefing plays the music box alone. Going in: a tin drum speeding up for two bars into the march, which comes in
## whole for its first four bars. The last 30 seconds of a timed mode: the same march 1.25 times as fast and a semitone up
## (rendered so, the layers as before), an alarm clock's second hand hurrying, the two sides' toy trumpets now and then.
## A blast close by: the tape stretches (the pitch sags and comes back over 1.5 s) instead of the ears ringing.
## The music keeps its own time by the audio's clock (the browser's on the web, where a slow page can draw few frames a
## second), and what has to meet a bar line is started early and silent, so it meets it in the audio itself: the march's
## layers start with the drum, two bars before their first bar; the overtime's set starts before the bar line it takes over at.

const DIR := "res://music/"
const BPM := 120.0; const OT_BPM := 150.0; const BARS := 16
const BAR := 240.0 / BPM; const OT_BAR := 240.0 / OT_BPM
const LOOP := BAR * BARS; const OT_LOOP := OT_BAR * BARS
const LAYERS := ["box", "xylo", "beat", "bass", "tick", "war"]
const MIX := {   # each state's level for each layer
	"spawn": {"box": 1.0, "tick": 0.45},
	"explore": {"xylo": 1.0, "beat": 0.85, "bass": 0.55},
	"bed": {"bass": 1.0, "tick": 1.0},
	"battle": {"war": 1.0, "xylo": 0.75, "beat": 1.0, "bass": 1.0},
}
const GAIN := 0.25           # the music under the sounds (stage 5's toys are quiet: the fight's mix about 7 dB under a toy's shot), 음량 and 음악 on top
const LOBBY := 2.0           # the briefing's music box, with nothing else to hear, louder
const LEADIN := 4.0          # the tin drum's two bars before the march
const KICKOFF := 4.0 * BAR   # the march's first four bars, whole
const EASE := 0.7            # a layer follows its level this quickly (seconds to 63%)
const XFADE := 0.06          # the change of set at a bar line
const LP_OPEN := 20000.0; const LP_BED := 900.0
const TAPE := 1.5; const TAPE_LOW := 0.62
const OT_AT := 30.0          # the last 30 seconds are the overtime
const HEAT_ON := 0.6; const HEAT_OFF := 0.3; const HEAT_T := 3.0
const SPAWN_T := 5.0         # back at your base: the spawn's music this long (unless a fight starts)

var volume := 0.7            # the 음악 setting
var what := ""               # "", "lobby", "leadin", "march"
var state := "spawn"
var ot := false              # the overtime's set is the one heard
var heat := 0.0; var battle := false
var level := {}              # layer -> its level now
var pitch := 1.0
var t := 0.0                 # where the set heard is: seconds into its loop
var kick := 0.0              # the kickoff's time left
var tape_t := TAPE
var lp := LP_OPEN
var fade := 0.0              # the whole march's level (in and out)
var lobby_fade := 0.0
var w_ot := 0.0              # how much of the overtime's set is heard (0 the march's, 1 the overtime's)
var switching := false; var switch_in := 0.0; var t_next := 0.0   # a change of set on its way: music-seconds to the bar line, where the other set will be
var since_spawn := 99.0
var horn_t := 6.0; var horn_us := true
var _shots := -1; var _hp := -1.0; var _out := false
var _n := {}; var _o := {}   # layer -> its player, the march's and the overtime's ("alarm" in the overtime only)
var _lobby: AudioStreamPlayer; var _leadin: AudioStreamPlayer; var _shot: Array[AudioStreamPlayer] = []; var _next_shot := 0
var _streams := {}
var _db := {}                # player -> the volume last set (fewer calls into the web's audio)
var _pitch_set := 1.0
var _pending: Array = []     # the web: streams to register as samples, one at a time while nothing much is going on
var _warm_t := 0.0
var _clock := -1.0           # the audio's clock at the last frame
var keep_log := false; var log: Array = []

func _ready() -> void:
	for k in LAYERS: _n[k] = _player("m_" + k, true)
	for k in LAYERS + ["alarm"]: _o[k] = _player("o_" + k, true)
	_lobby = _player("lobby", true); _leadin = _player("leadin", false)
	for i in 2:
		var p := AudioStreamPlayer.new(); p.bus = "Music"; add_child(p); _shot.push_back(p)
	for k in LAYERS: level[k] = 0.0
	var loops := []
	for p: AudioStreamPlayer in _n.values() + _o.values() + [_lobby]:
		if p.stream != null: loops.push_back(p.stream)
	Snd.music_loops(loops)

func _stream(name: String, loop: bool) -> AudioStream:
	if not _streams.has(name):
		var path := DIR + name + ".ogg"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis: (s as AudioStreamOggVorbis).loop = loop
		_streams[name] = s
	return _streams[name]

func _player(name: String, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.stream = _stream(name, loop); p.bus = "Music"; p.volume_db = -80.0; add_child(p)
	return p

func _vol(p: AudioStreamPlayer, lin: float) -> void:
	var db := linear_to_db(maxf(0.00001, lin))
	if absf(float(_db.get(p, 999.0)) - db) > 0.05: p.volume_db = db; _db[p] = db

func _say(s: String) -> void:
	if keep_log: log.push_back(s)

## the web build plays everything as the browser's own samples, each made from its file the first time it plays: made one by
## one beforehand instead (in the briefing, early in a match), so no frame has to wait for six at once
func _warm(list: Array) -> void:
	if not OS.has_feature("web"): return
	for p: AudioStreamPlayer in list:
		if p.stream != null and not _pending.has(p.stream) and not AudioServer.is_stream_registered_as_sample(p.stream): _pending.push_back(p.stream)

func _warm_step() -> void:
	if _pending.is_empty(): return
	var s: AudioStream = _pending.pop_front()
	if not AudioServer.is_stream_registered_as_sample(s): AudioServer.register_stream_as_sample(s)

## seconds of audio since the last frame: the browser's own audio clock on the web (it stands still while the page's audio
## is put to sleep), the wall clock elsewhere; never more than a second at once
func _elapsed() -> float:
	var now := Snd.audio_clock()
	var d := 0.0 if _clock < 0.0 else clampf(now - _clock, 0.0, 1.0)
	_clock = now
	return d

# ---------------- what to play ----------------
## once a frame. ctx (from Main): {} for silence; {"what": "lobby"}; or the march's: what = "march", paused, spawn (waiting
## to come back), bed (under the bed), near (enemies about you), shots and hp (yours, to feel a fight), ot (the overtime is
## on), teams (a team mode: the trumpets). dt, when given, stands in for the audio's clock (the tests)
func update(_frame_dt: float, ctx: Dictionary, dt := -1.0) -> void:
	if dt < 0.0: dt = _elapsed()
	var want: String = ctx.get("what", "")
	if want == "march" and what != "march" and what != "leadin": _start_match()
	elif want == "lobby" and what != "lobby": _start_lobby()
	elif want == "" and what != "": _say("stop"); what = ""
	var master := GAIN * volume * Snd.volume
	# the lobby's music box
	lobby_fade = move_toward(lobby_fade, 1.0 if what == "lobby" else 0.0, dt / (1.0 if what == "lobby" else 0.4))
	_vol(_lobby, LOBBY * master * lobby_fade)
	if lobby_fade <= 0.0 and _lobby.playing: _lobby.stop()
	if what == "lobby": _warm_step()
	# the march: silent under the drum, heard from its first bar
	if what == "leadin":
		t += dt * pitch
		if t >= LOOP - 0.5 * dt: t = maxf(0.0, t - LOOP); _begin_march()
	elif what == "march": _march(dt, ctx)
	if what != "march" and what != "leadin":
		lp = LP_OPEN
		fade = move_toward(fade, 0.0, dt / 2.0)
		if fade <= 0.0: _stop_march()
	var paused: bool = ctx.get("paused", false)
	var m2 := master * fade * (0.4 if paused else 1.0)
	_tape(dt)
	for k in LAYERS:
		_vol(_n[k], level[k] * m2 * (1.0 - w_ot)); _vol(_o[k], level[k] * m2 * w_ot)
	_vol(_o.alarm, 0.8 * m2 * w_ot)
	_vol(_leadin, master * (0.4 if paused else 1.0) * (1.0 if (what == "leadin" or what == "march") else 0.0))
	if pitch != _pitch_set and (absf(pitch - _pitch_set) > 0.0005 or pitch == 1.0):   # (the last step home exactly)
		_pitch_set = pitch
		for p in _all(): p.pitch_scale = pitch
	Snd.music_lowpass(lp)

func _all() -> Array:
	var a: Array = [_leadin]
	for k in _n: a.push_back(_n[k])
	for k in _o: a.push_back(_o[k])
	return a + _shot

func _start_lobby() -> void:
	_say("lobby"); what = "lobby"
	if not _lobby.playing: _vol(_lobby, 0.0); _lobby.play()
	_warm([_leadin] + _n.values())

## the drum, and with it (silent) the march's layers two bars before their first bar: they reach it as the drum ends
func _start_match() -> void:
	_say("leadin"); what = "leadin"; ot = false; w_ot = 0.0; switching = false; heat = 0.0; battle = false; kick = KICKOFF; since_spawn = 0.0
	_shots = -1; _hp = -1.0; _out = false; horn_t = 6.0; tape_t = TAPE; pitch = 1.0; _warm_t = 0.0; fade = 0.0
	for k in LAYERS: level[k] = 0.0
	_stop_march(); _leadin.stop()
	_db.clear(); _vol(_leadin, 0.0)
	for k in LAYERS: _vol(_n[k], 0.0)
	_leadin.play(); t = LOOP - LEADIN
	for k in LAYERS: _n[k].play(t)   # (all in the one frame: they go round together, and with the drum)
	_warm(_n.values())

func _begin_march() -> void:
	_say("march"); what = "march"; fade = 1.0; state = "battle"
	for k in LAYERS: level[k] = float(MIX.battle.get(k, 0.0))

func _stop_march() -> void:
	for p in _n.values() + _o.values() + [_leadin] + _shot:
		if p.playing: p.stop()

## the march's frame: where it is, the state and the layers' levels, the overtime's change of set at a bar line
func _march(dt: float, ctx: Dictionary) -> void:
	var lp_len := OT_LOOP if ot else LOOP
	t += dt * pitch
	if t >= lp_len: t -= lp_len
	kick = maxf(0.0, kick - dt)
	# a fight: your shots, your hurts, enemies about you
	var shots: int = ctx.get("shots", 0); var hp: float = ctx.get("hp", 0.0)
	if _shots >= 0 and shots > _shots and shots - _shots < 60: heat += 0.06 * (shots - _shots)
	if _hp >= 0.0 and hp < _hp - 0.5: heat += 0.3
	_shots = shots; _hp = hp
	heat = minf(1.5, maxf(heat, 0.25 * float(ctx.get("near", 0)))) * exp(-dt / HEAT_T)
	battle = heat >= HEAT_ON or (battle and heat > HEAT_OFF)
	var out: bool = ctx.get("spawn", false)
	if _out and not out: since_spawn = 0.0   # (back at your base)
	_out = out; since_spawn += dt
	var st := "explore"
	if kick > 0.0: st = "battle"
	elif out or (since_spawn < SPAWN_T and not battle): st = "spawn"
	elif ctx.get("bed", false): st = "bed"
	elif battle: st = "battle"
	if st != state: _say("state " + st); state = st
	var k := 1.0 - exp(-dt / EASE)
	for l in LAYERS: level[l] += (float(MIX[state].get(l, 0.0)) - level[l]) * k
	lp = exp(lerpf(log(lp), log(LP_BED if state == "bed" else LP_OPEN), 1.0 - exp(-dt / 0.25)))
	# the overtime: the other set, started silent where it will be at the next bar line, and heard from that bar line
	var want_ot: bool = ctx.get("ot", false)
	if want_ot != ot and not switching: _prepare(want_ot)
	if switching:
		switch_in -= dt * pitch
		if switch_in <= 0.5 * dt * pitch: _switch()
	w_ot = move_toward(w_ot, 1.0 if ot else 0.0, dt / XFADE)
	if w_ot <= 0.0 or w_ot >= 1.0: _quiet_other()
	# (the web: the overtime's layers made ready a while into a timed match, one every second and a half)
	if ctx.get("teams", false) and OS.has_feature("web"):
		if _warm_t == 0.0: _warm(_o.values())
		_warm_t += dt
		if _warm_t > 3.0: _warm_t = 1.5; _warm_step()
	# the overtime's trumpets, one side and then the other
	if ot and ctx.get("teams", false):
		horn_t -= dt
		if horn_t <= 0.0:
			horn_t = randf_range(6.0, 10.0); horn_us = not horn_us
			shot("trumpet_us" if horn_us else "trumpet_them", 0.8)

func _prepare(to_ot: bool) -> void:
	var bar := OT_BAR if ot else BAR
	var b := int(floorf(t / bar + 0.0001)) + 1               # the next bar line
	switch_in = b * bar - t                                   # (in music: both sets keep the one pitch, so they meet in it)
	var nb := BAR if ot else OT_BAR; var nl := LOOP if ot else OT_LOOP
	t_next = b % BARS * nb
	var start := fposmod(t_next - switch_in, nl)
	var to: Dictionary = _n if ot else _o
	for k in to: _vol(to[k], 0.0); to[k].play(start)
	switching = true; _say("prepare " + ("overtime" if to_ot else "march"))

func _switch() -> void:
	switching = false; ot = not ot; t = t_next - switch_in   # (the other set, playing all along, is just there)
	_say("overtime" if ot else "overtime off")
	if ot: shot("ot_bell", 0.9)

func _quiet_other() -> void:
	var other: Dictionary = _n if ot else _o
	if switching: return
	for k in other:
		if other[k].playing: other[k].stop()

## a one-off on the music: the overtime's bell, a toy trumpet
func shot(name: String, gain: float) -> void:
	var s := _stream(name, false)
	if s == null: return
	var p := _shot[_next_shot]; _next_shot = (_next_shot + 1) % _shot.size()
	p.stream = s; p.pitch_scale = pitch; _vol(p, GAIN * volume * Snd.volume * gain); p.play(); _say("shot " + name)

## how it stands (for the tests and the command line)
func status() -> Dictionary:
	var on := []
	for k in _n:
		if _n[k].playing: on.push_back("m_" + k)
	for k in _o:
		if _o[k].playing: on.push_back("o_" + k)
	if _lobby.playing: on.push_back("lobby")
	if _leadin.playing: on.push_back("leadin")
	var lv := {}
	for k in level: lv[k] = snappedf(level[k], 0.001)
	return {"what": what, "state": state, "ot": ot, "w_ot": w_ot, "heat": heat, "battle": battle, "pitch": pitch, "lp": lp, "t": t, "fade": fade, "level": lv,
		"playing": on, "bus": Snd.music_bus, "log": log.slice(-12)}

# ---------------- the tape ----------------
## a blast: close by (6 m) in a match, the music's tape stretches
func blast(at: Vector3) -> void:
	if what != "march" and what != "leadin": return
	if at.distance_to(Snd.listener) > 6.0: return
	tape_t = 0.0; _say("tape")

static func tape_pitch(tt: float) -> float:
	if tt >= TAPE: return 1.0
	if tt < 0.3: return lerpf(1.0, TAPE_LOW, smoothstep(0.0, 0.3, tt))
	if tt < 0.75: return TAPE_LOW
	return lerpf(TAPE_LOW, 1.0, smoothstep(0.75, TAPE, tt))

func _tape(dt: float) -> void:
	tape_t = minf(TAPE, tape_t + dt); pitch = tape_pitch(tape_t)
