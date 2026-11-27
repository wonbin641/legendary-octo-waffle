extends Node
## Sound effects. The browser game's own are made by its own WebAudio code (tools/render_sounds.js runs src/03_core.js's
## Sound in an offline context): the same recipes to the letter, four takes of each that the browser game would vary (its
## noise and a few pitches are drawn afresh every time), one of which plays each time, at its own pitch. A sound with a
## place is panned as the browser game's StereoPanner pans it and quietened with distance as there, and everything goes
## through the browser game's master compressor (as measured: +0.74 dB below about -8 dB, a little held back above).
## Stage 5's toys (tools/make_sounds.py) play as they always have. Stage 5's music (scripts/music.gd) has a bus of its own,
## straight to the master, with a low-pass for under the bed.
## The web build plays each sound as a sample of the browser's own Web Audio, where Godot's buses carry no effects: there
## the browser game's own nodes go into the mix instead (WEB_MIX), so the pan and the compressor are the browser game's to the letter.

const SCALE := 0.5   # the takes are stored at half level (tools/render_sounds.js)
var _streams := {}   # name: its takes
var _players: Array[AudioStreamPlayer] = []
var _panners: Array[AudioEffectPanner] = []
var _voice_bus: Array[int] = []
var _web: JavaScriptObject = null   # the web build's mix (WEB_MIX), when the sounds are the browser's samples there
var music_bus := -1
var _music_lp: AudioEffectLowPassFilter
var _lp_hz := -1.0
var _next := 0
var volume := 0.7
var listener := Vector3.ZERO
var listener_yaw := 0.0   # the camera's turn, for the pan
var keep_log := false   # the tests listen in
var played: Array = []

func _ready() -> void:
	# the mix and a bus for each voice, all made at once (the web build's own list of them, in the browser, keeps Godot's order so;
	# added one by one with add_bus() each new one goes in there before the last, the sends then join the wrong buses and the
	# sound feeds round on itself)
	var mix := AudioServer.bus_count; AudioServer.bus_count = mix + 14
	AudioServer.set_bus_name(mix, "Mix"); AudioServer.set_bus_send(mix, "Master")
	# the browser game's master compressor (threshold -14 dB, ratio 6, Web Audio's soft knee), fitted to what it measures
	var comp := AudioEffectCompressor.new(); comp.threshold = -5.6; comp.ratio = 1.3; comp.gain = 0.74; comp.attack_us = 3000.0; comp.release_ms = 250.0
	AudioServer.add_bus_effect(mix, comp)
	for i in 12:
		var b := mix + 1 + i; AudioServer.set_bus_name(b, "Voice%d" % i); AudioServer.set_bus_send(b, "Mix")
		var pn := AudioEffectPanner.new(); AudioServer.add_bus_effect(b, pn); _panners.push_back(pn); _voice_bus.push_back(b)
		var p := AudioStreamPlayer.new(); p.bus = "Voice%d" % i; add_child(p); _players.push_back(p)
	music_bus = mix + 13; AudioServer.set_bus_name(music_bus, "Music"); AudioServer.set_bus_send(music_bus, "Master")
	_music_lp = AudioEffectLowPassFilter.new(); _music_lp.cutoff_hz = 20000.0; _music_lp.resonance = 0.5
	AudioServer.add_bus_effect(music_bus, _music_lp); AudioServer.set_bus_effect_enabled(music_bus, 0, false)
	# the web build (single-threaded) plays sounds as samples ("audio/general/default_playback_type" 1 there), its buses bare
	if OS.has_feature("web") and int(ProjectSettings.get_setting_with_override("audio/general/default_playback_type")) == 1:
		JavaScriptBridge.eval(WEB_MIX, false)   # (in the engine's own context, where its audio is: GodotAudio)
		_web = JavaScriptBridge.get_interface("__yarrSnd")
		if _web != null: _web.setup(mix)

## On the web: the browser game's master DynamicsCompressor (threshold -14 dB, ratio 6, the rest Web Audio's defaults) on the
## mix's bus, and a StereoPanner on each voice's bus, taking the sound as one channel (equal power) as the browser game's
## panners take its mono sounds, or passing it whole for a sound without a place. Each goes in right after its bus's own
## volume (the sends and the solo come after), the first time a sound needs it, and again should Godot make that bus anew.
const WEB_MIX := """window.__yarrSnd = (function (A) {
	const o = { A: A, mix: -1 };
	const put = (bus, nodes) => { bus._gainNode.disconnect(); let at = bus._gainNode; for (const n of nodes) { at.connect(n); at = n; } at.connect(bus._soloNode); bus.__yarr = nodes[nodes.length - 1]; return bus.__yarr; };
	o.setup = (mix) => { o.mix = mix; };
	o.ready = () => {   // the mix's compressor in place
		const m = A.ctx && A.buses ? A.buses[o.mix] : null;
		if (!m) return false;
		if (!m.__yarr) { const c = put(m, [A.ctx.createDynamicsCompressor()]); c.threshold.value = -14; c.ratio.value = 6; }
		return true;
	};
	o.pan = (bus, pan, placed) => {
		const b = o.ready() ? A.buses[bus] : null;
		if (!b) return false;
		let p = b.__yarr;
		if (!p) {   // the bus carries Godot's six channels: down to the two first, to one for a sound with a place, then the panner
			const two = A.ctx.createGain(); two.channelCount = 2; two.channelCountMode = 'explicit';
			const one = A.ctx.createGain(); one.channelCountMode = 'explicit';
			p = put(b, [two, one, A.ctx.createStereoPanner()]); p.__one = one;   // (the panner keeps its own channel settings, as every browser takes them)
		}
		p.__one.channelCount = placed ? 1 : 2; p.pan.value = placed ? pan : 0;
		return true;
	};
	o.now = () => (A.ctx ? A.ctx.currentTime : 0);   // the browser's audio clock
	o.musicIds = new Set();
	o.loopMusic = (ids) => {   // the music's samples loop in the browser's own audio, to the sample (Godot's web runtime starts a loop
		for (const id of String(ids).split(',')) if (id) o.musicIds.add(id);   // over when it hears it has ended: the layers would drift apart)
		const P = A.SampleNode && A.SampleNode.prototype;
		if (!P) return false;
		if (!P.__yarrLoop) {
			const add = P._addEndedListener;
			P._addEndedListener = function () {
				add.call(this);
				if (this._source && o.musicIds.has(String(this.streamObjectId))) { this._source.loop = true; this._source.loopStart = 0; this._source.loopEnd = 0; }
			};
			P.__yarrLoop = true;
		}
		return true;
	};
	o.lowpass = (bus, hz) => {   // the music's bus: a low-pass, gliding to its new frequency
		const b = A.ctx && A.buses ? A.buses[bus] : null;
		if (!b) return false;
		let f = b.__yarr;
		if (!f) { f = put(b, [A.ctx.createBiquadFilter()]); f.type = 'lowpass'; f.Q.value = 0.7; f.frequency.value = hz; }
		f.frequency.setTargetAtTime(hz, A.ctx.currentTime, 0.05);
		return true;
	};
	return o;
})(GodotAudio);"""

## the audio's clock, in seconds: the browser's own on the web (it runs whatever the frame rate, and stands still while the
## page's audio sleeps), the wall clock elsewhere
func audio_clock() -> float:
	if _web != null: return float(_web.now())
	return Time.get_ticks_usec() / 1000000.0

## the music's loops, on the web: looped by the browser itself (see WEB_MIX), so the layers stay together
func music_loops(streams: Array) -> void:
	if _web == null: return
	var ids := PackedStringArray()
	for st: AudioStream in streams: ids.push_back(str(st.get_instance_id()))
	_web.loopMusic(",".join(ids))

## the music's low-pass (under the bed): Godot's filter on the bus, the browser's own on the web (where the bus carries none)
func music_lowpass(hz: float) -> void:
	if absf(hz - _lp_hz) < maxf(1.0, _lp_hz * 0.01): return
	_lp_hz = hz
	if _web != null:
		if not _web.lowpass(music_bus, hz): _lp_hz = -1.0   # (the browser's audio not up yet: again next time)
		return
	_music_lp.cutoff_hz = hz; AudioServer.set_bus_effect_enabled(music_bus, 0, hz < 18000.0)

## a sound's takes: name.wav and name__1..3.wav
func takes(name: String) -> Array:
	if not _streams.has(name):
		var t := []
		for k in 4:
			var path := "res://sounds/%s.wav" % (name if k == 0 else "%s__%d" % [name, k])
			if ResourceLoader.exists(path): t.push_back(load(path))
		_streams[name] = t
	return _streams[name]

## the browser game's spatial(): quieter with distance, and panned by where it is beside the camera (at most 0.8 either way)
func place(at: Vector3) -> Vector2:
	var d := at - listener; var dist := d.length()
	var k := clampf(1.6 / (1.0 + dist * 0.09), 0.04, 1.0)
	var rx := cos(listener_yaw) * d.x - sin(listener_yaw) * d.z
	return Vector2(k, clampf(rx / (dist + 2.0), -0.8, 0.8))

## a voice for a new sound: the first one free from where the last went, or (all twelve playing) the next in turn
func _free_voice() -> int:
	var n := _players.size(); var i := _next
	for j in n:
		var c := (_next + j) % n
		if not _players[c].playing: i = c; break
	_next = (i + 1) % n
	return i

## WebAudio's StereoPanner on one channel (equal power) as Godot's panner (left 1 - p, right 1 + p) and a level: [p, level]
static func pan_as_web(pan: float) -> Vector2:
	var x := (pan + 1.0) * 0.5; var gl := cos(x * PI * 0.5); var gr := sin(x * PI * 0.5)
	return Vector2((gr - gl) / (gr + gl), (gl + gr) * 0.5)

func play(name: String, gain := 1.0, at = null) -> void:
	if keep_log: played.push_back(name)
	var t := takes(name)
	if t.is_empty() or volume <= 0.0: return
	var i := _free_voice(); var p := _players[i]
	p.stream = t[randi() % t.size()]
	if name.begins_with("toy_"):   # stage 5's own sounds: as they always were (stored at half level as the rest: tools/make_sounds.py)
		if at != null: gain *= clampf(1.6 / (1.0 + (at as Vector3).distance_to(listener) * 0.09), 0.04, 1.0)
		p.bus = "Master"; p.volume_db = linear_to_db(maxf(0.0001, gain * volume / SCALE)); p.pitch_scale = randf_range(0.96, 1.04); p.play(); return
	var level := gain * volume / SCALE; var pn := 0.0; var kp := place(at) if at != null else Vector2(1.0, 0.0)
	# a sound with a place goes through the panner (a sound without one reaches both ears whole, as there)
	if _web != null and _web.pan(_voice_bus[i], kp.y, at != null): level *= kp.x   # (the browser's own panner, on the web)
	elif at != null: var w := pan_as_web(kp.y); level *= kp.x * w.y; pn = w.x
	_panners[i].pan = pn; p.bus = "Voice%d" % i
	p.volume_db = linear_to_db(maxf(0.0001, level)); p.pitch_scale = 1.0; p.play()

## one of stage 5's sounds at a pitch the caller picks, its first take: nothing is drawn from the game's random numbers
## (the breakages' sounds: ToyBreak, which keeps the fights as they were)
func toy(name: String, gain := 1.0, at = null, pitch := 1.0) -> void:
	if keep_log: played.push_back(name)
	var t := takes(name)
	if t.is_empty() or volume <= 0.0: return
	var p := _players[_free_voice()]; p.stream = t[0]
	if at != null: gain *= clampf(1.6 / (1.0 + (at as Vector3).distance_to(listener) * 0.09), 0.04, 1.0)
	p.bus = "Master"; p.volume_db = linear_to_db(maxf(0.0001, gain * volume / SCALE)); p.pitch_scale = pitch; p.play()

## a sound that keeps going (the helicopter's rotor, the jetpack): started at a level, held there while it is called again, stopped at 0
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
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = roundi(w.get_length() * w.mix_rate)   # all of it (in frames, whatever it is stored as: QOA here)
		p = AudioStreamPlayer.new(); p.stream = w; p.bus = "Mix"; add_child(p); _loops[name] = p
	p.volume_db = linear_to_db(maxf(0.0001, gain * volume / SCALE))
	if not p.playing:
		if _web != null: _web.ready()   # (through the browser game's compressor on the web too, even before any other sound)
		p.play()
		if keep_log: played.push_back(name)

## the jetpack (the browser game's jet: band-passed noise, louder and brighter with thrust: 0.8 as it lights, 0.45 hovering,
## 0.85 climbing, 0 off), made of its two takes at those levels and eased as there (a tenth of a second)
var _jet := Vector2.ZERO
func jet(level: float, dt := 0.0) -> void:
	var want := Vector2.ZERO
	if level > 0.0: want = Vector2(0.0, level / 0.85) if level >= 0.65 else Vector2(level / 0.45, 0.0)
	_jet = want if (level <= 0.0 or dt <= 0.0) else _jet + (want - _jet) * (1.0 - exp(-dt / 0.08))
	loop("jet_lo", _jet.x); loop("jet_hi", _jet.y)

## a short buzz of the phone, where the browser game has one (only with the touch controls; nothing elsewhere)
var touch := false
func buzz(ms: int) -> void:
	if touch: Input.vibrate_handheld(ms)
