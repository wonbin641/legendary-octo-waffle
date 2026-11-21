#!/usr/bin/env python3
"""스테이지 5(장난감 방)의 배경 음악(godot/music/*.ogg)을 만듭니다. 필요한 것: python3, numpy, ffmpeg(libvorbis).

"장난감 병정의 행진곡": 웅장한 행진곡의 문법을 아이 악기와 방 안의 물건으로. F장조 120 BPM 4/4, 16마디(A 8 + B 8, 32초)를
한 번에 같이 도는 여섯 층으로 만들어, 게임이 상황에 따라 층의 크기만 바꿉니다(godot/scripts/music.gd).
  box   오르골 선율과 가벼운 나무 블록       (스폰·대기)
  xylo  실로폰 선율과 피치카토 화음          (이동·탐색)
  beat  나무 블록, 캐스터네츠, 태엽 감는 소리 (이동·탐색, 난전)
  bass  봄웨커 베이스                        (침대 밑, 이동·탐색, 난전)
  tick  시계 째깍 소리                       (침대 밑, 스폰)
  war   카주, 리코더, 토이 피아노 아르페지오, 글로켄슈필, 양철 북 (난전)
오버타임(경기 끝 30초 전)은 같은 곡을 1.25배 빠르게(150 BPM), 반음 높게(F#장조) 따로 만든 여섯 층과 탁상시계 초침(alarm)입니다.
로비(스테이지 5 브리핑)는 오르골 혼자 80 BPM, 시작은 빨라지는 양철 북 두 마디(leadin), 오버타임에 들어설 때 알람 벨(ot_bell),
두 편의 장난감 나팔(trumpet_us, trumpet_them).
층과 고리(loop)는 모두 끝이 처음으로 이어지게 만듭니다: 음의 꼬리와 울림이 다시 처음에 더해집니다.
같은 난수 씨앗을 쓰므로 몇 번을 돌려도 같은 소리가 나옵니다.
"""
import os, subprocess, sys, wave
import numpy as np

SR = 32000
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'godot', 'music'))
TMP = os.path.normpath(os.path.join(HERE, '..', 'build', 'music'))
RNG = np.random.default_rng(5150)

# ---------------- pitch ----------------
_N = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
def midi(s):
    n = _N[s[0]]; i = 1
    while s[i] in '#b': n += 1 if s[i] == '#' else -1; i += 1
    return 12 * (int(s[i:]) + 1) + n
def hz(m): return 440.0 * 2.0 ** ((m - 69) / 12.0)

# ---------------- the tune ----------------
# 16 bars of 4/4: A (1-8), B (9-16); (note, beats), 'r' a rest. Written pitch: each instrument plays it in its own octave
TUNE = [
    [('C5', .75), ('A4', .25), ('C5', .5), ('F5', .5), ('A5', 1), ('F5', 1)],
    [('G5', .75), ('E5', .25), ('C5', .5), ('E5', .5), ('G5', 1), ('Bb5', 1)],
    [('A5', .5), ('G5', .5), ('F5', .5), ('E5', .5), ('D5', 1), ('C5', 1)],
    [('F5', 1), ('C5', .5), ('A4', .5), ('F4', 1), ('r', 1)],
    [('C5', .75), ('A4', .25), ('C5', .5), ('F5', .5), ('A5', 1), ('C6', 1)],
    [('D6', .75), ('C6', .25), ('Bb5', .5), ('A5', .5), ('G5', 1), ('Bb5', 1)],
    [('A5', .5), ('G5', .5), ('F5', .5), ('G5', .5), ('A5', .5), ('G5', .5), ('E5', 1)],
    [('F5', 1), ('A5', .5), ('G5', .5), ('F5', 1), ('r', 1)],
    [('D5', .5), ('F5', .5), ('Bb5', 1), ('A5', .5), ('G5', .5), ('F5', 1)],
    [('C5', .5), ('F5', .5), ('A5', 1), ('G5', .5), ('F5', .5), ('E5', 1)],
    [('D5', .5), ('G5', .5), ('Bb5', 1), ('A5', .5), ('G5', .5), ('F5', .5), ('E5', .5)],
    [('F5', 1), ('E5', .5), ('D5', .5), ('C5', 2)],
    [('D6', .75), ('C6', .25), ('Bb5', 1), ('D6', .75), ('C6', .25), ('Bb5', 1)],
    [('C6', .75), ('A5', .25), ('F5', 1), ('C6', .75), ('A5', .25), ('F5', 1)],
    [('G5', .5), ('A5', .5), ('Bb5', .5), ('G5', .5), ('E5', .5), ('F5', .5), ('G5', 1)],
    [('C6', 1.5), ('r', .5), ('G5', .5), ('E5', .5), ('D5', .5), ('E5', .5)],
]
CHORDS = ['F', 'C7', 'C7', 'F', 'F', 'Bb', 'C7', 'F', 'Bb', 'F', 'Gm', 'C7', 'Bb', 'F', 'C7', 'C7']
PIZZ = {'F': ['A3', 'C4', 'F4'], 'C7': ['G3', 'Bb3', 'E4'], 'Bb': ['Bb3', 'D4', 'F4'], 'Gm': ['G3', 'Bb3', 'D4']}
ARP = {'F': ['F4', 'A4', 'C5', 'F5'], 'C7': ['E4', 'G4', 'Bb4', 'C5'], 'Bb': ['F4', 'Bb4', 'D5', 'F5'], 'Gm': ['G4', 'Bb4', 'D5', 'G5']}
ROOT = {'F': 'F4', 'C7': 'C4', 'Bb': 'Bb3', 'Gm': 'G3'}
BASS = [
    [('F2', 1), ('r', 1), ('C3', 1), ('r', 1)], [('C3', 1), ('r', 1), ('G2', 1), ('r', 1)],
    [('C3', 1), ('r', 1), ('G2', 1), ('Bb2', 1)], [('F2', 1), ('r', 1), ('C3', 1), ('E2', 1)],
    [('F2', 1), ('r', 1), ('C3', 1), ('r', 1)], [('Bb2', 1), ('r', 1), ('F2', 1), ('r', 1)],
    [('C3', 1), ('r', 1), ('G2', 1), ('E2', 1)], [('F2', 1), ('r', 1), ('C3', 1), ('A2', 1)],
    [('Bb2', 1), ('r', 1), ('F2', 1), ('r', 1)], [('F2', 1), ('r', 1), ('C3', 1), ('r', 1)],
    [('G2', 1), ('r', 1), ('D3', 1), ('r', 1)], [('C3', 1), ('r', 1), ('G2', 1), ('r', 1)],
    [('Bb2', 1), ('r', 1), ('F2', 1), ('r', 1)], [('F2', 1), ('r', 1), ('C3', 1), ('A2', 1)],
    [('C3', 1), ('r', 1), ('G2', 1), ('r', 1)], [('C3', 1), ('G2', 1), ('C3', .5), ('D3', .5), ('E3', 1)],
]
BARS = len(TUNE)

def seq(bars):
    """bars of (note, beats) -> [(beat, beats, midi)]"""
    ev = []; b = 0.0
    for bar in bars:
        assert abs(sum(d for _, d in bar) - 4.0) < 1e-9, bar
        for note, d in bar:
            if note != 'r': ev.append((b, d, midi(note)))
            b += d
    return ev

def accent(b):
    """a march's weight: the bar's first beat, then the third, the others, the off-beats"""
    p = b % 4.0
    if abs(p) < 1e-6: return 1.0
    if abs(p - 2.0) < 1e-6: return 0.9
    if abs(p - round(p)) < 1e-6: return 0.8
    return 0.7

# ---------------- little tools ----------------
def t_of(n): return np.arange(n) / SR

def sines(f0, dur, parts, att=0.002):
    """decaying partials: (ratio, amplitude, decay time) of f0"""
    n = max(1, int(dur * SR)); t = t_of(n); y = np.zeros(n)
    for r, a, tau in parts:
        f = f0 * r
        if f >= SR * 0.46: continue
        y += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 2 * np.pi)) * np.exp(-t / tau)
    return y * np.minimum(1.0, t / att)

def band(x, lo, hi):
    """a soft band-pass through the spectrum"""
    n = len(x); X = np.fft.rfft(x); f = np.fft.rfftfreq(n, 1.0 / SR) + 1e-3
    H = (1.0 / (1.0 + (f / hi) ** 4)) * (1.0 - 1.0 / (1.0 + (f / lo) ** 4)) if lo > 0 else 1.0 / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(X * H, n)

def burst(dur, lo, hi, tau, att=0.0004):
    """a burst of filtered noise, fading out"""
    n = max(8, int(dur * SR)); y = band(RNG.standard_normal(n), lo, hi); t = t_of(n)
    y = y * np.exp(-t / tau) * np.minimum(1.0, t / att)
    return y / (np.max(np.abs(y)) + 1e-12)

def add(y, z, at=0):
    """z into y from sample at (growing y if need be)"""
    if at + len(z) > len(y): y = np.concatenate([y, np.zeros(at + len(z) - len(y))])
    y[at:at + len(z)] += z
    return y

def env_note(n, dur, att, rel):
    """attack, hold for the note, release"""
    t = t_of(n); e = np.minimum(1.0, t / att)
    return e * np.clip(1.0 - (t - dur) / rel, 0.0, 1.0)

def glide_phase(f, n, wobble):
    """the phase of a voice at f with a pitch curve (wobble: fractions of f, per sample)"""
    return 2 * np.pi * np.cumsum(f * (1.0 + wobble)) / SR

def slow_noise(n, rate):
    """a smooth random wiggle about 0 (±1), changing rate times a second"""
    k = max(2, int(n / SR * rate) + 2); pts = RNG.uniform(-1, 1, k)
    return np.interp(np.linspace(0, k - 1, n), np.arange(k), pts)

# ---------------- the instruments ----------------
def v_box(f, dur, vel):        # a music box's steel comb: a tine plucked by a pin
    k = (880.0 / f) ** 0.3
    y = sines(f, 2.4, [(1, 1.0, 1.25 * k), (2.0, 0.05, 0.5), (6.27, 0.16, 0.07), (17.55, 0.04, 0.018)], att=0.0012)
    y = add(y, 0.05 * burst(0.006, 3500, 11000, 0.0012))
    return vel * y

def v_xylo(f, dur, vel):       # a rosewood bar over its tube: the overtone tuned to the twelfth, a hard mallet
    k = (880.0 / f) ** 0.5
    y = sines(f, 1.0, [(1, 1.0, 0.30 * k), (3.0, 0.30, 0.09 * k), (6.2, 0.09, 0.03 * k)], att=0.0008)
    y = add(y, 0.22 * burst(0.02, 250, 2200, 0.004))
    return vel * y

def v_glock(f, dur, vel):      # steel bars, bright and long
    y = sines(f, 2.6, [(1, 1.0, 1.5), (2.76, 0.33, 0.42), (5.40, 0.14, 0.14), (8.93, 0.05, 0.05)], att=0.0006)
    y = add(y, 0.12 * burst(0.008, 4500, 13000, 0.0015))
    return vel * y

def v_toypiano(f, dur, vel):   # struck metal rods: a little out of tune, a wooden clunk
    det = 2.0 ** (RNG.uniform(-9, 9) / 1200.0)
    p = [(1, 1.0, 0.7), (2.0, 0.10, 0.35), (6.27, 0.30, 0.05), (17.55, 0.05, 0.012)]
    y = sines(f * det, 1.5, p, att=0.0008) + 0.3 * sines(f * det * 2.0 ** (7 / 1200.0), 1.5, p[:2], att=0.0008)
    y = add(y, 0.28 * burst(0.015, 150, 1400, 0.004))
    return vel * y

def v_pizz(f, dur, vel):       # plucked strings: the high harmonics go first
    n = int(0.55 * SR); t = t_of(n); y = np.zeros(n)
    for h in range(1, 14):
        if f * h >= SR * 0.45: break
        y += (1.0 / h ** 1.15) * np.sin(2 * np.pi * f * h * t + RNG.uniform(0, 6.28)) * np.exp(-t * (7.0 + 3.2 * h))
    y *= np.minimum(1.0, t / 0.002)
    y = add(y, 0.08 * burst(0.006, 1200, 6000, 0.0015))
    return vel * y

def v_boom(f, dur, vel):       # a boomwhacker: a plastic tube slapped, its air ringing, a little bend down
    n = int(0.75 * SR); t = t_of(n)
    ph = glide_phase(f, n, 0.035 * np.exp(-t / 0.02))
    y = np.sin(ph) + 0.6 * np.sin(2 * ph) * np.exp(-t / 0.16) + 0.3 * np.sin(3 * ph) * np.exp(-t / 0.09) + 0.12 * np.sin(4 * ph) * np.exp(-t / 0.05)
    y *= np.exp(-t / 0.30) * np.minimum(1.0, t / 0.0015)
    y = add(y, 0.32 * burst(0.03, 300, 2600, 0.006))
    return vel * y

FORMANT_KAZOO = [(560, 0.55, 1.0), (1250, 0.45, 0.9), (2600, 0.5, 0.6), (3900, 0.4, 0.3)]
FORMANT_TRUMPET = [(1100, 0.45, 1.0), (2400, 0.5, 0.7), (3600, 0.4, 0.35)]
def formant(fr, table, floor=0.22):
    lf = np.log2(np.maximum(fr, 20.0)); g = np.full_like(lf, floor)
    for fc, bw, a in table: g += a * np.exp(-0.5 * ((lf - np.log2(fc)) / bw) ** 2)
    return g

def buzzy(f, dur, vel, table, tilt, att, vib, scoop, noise_amt, rel=0.06):
    """a buzzing reed or membrane: all the harmonics, shaped by its formants, with vibrato and a scoop up to the note"""
    n = int((dur + rel) * SR); t = t_of(n)
    wob = vib * np.sin(2 * np.pi * 5.7 * t) * np.minimum(1.0, t / 0.18) + 0.0025 * slow_noise(n, 9) - scoop * np.exp(-t / 0.03)
    ph = glide_phase(f, n, wob); K = int(SR * 0.45 / f)
    hs = np.arange(1, K + 1); amps = (1.0 / hs ** tilt) * formant(hs * f, table)
    y = np.zeros(n)
    for h, a in zip(hs, amps): y += a * np.sin(h * ph)
    flutter = 1.0 + 0.12 * slow_noise(n, 140)
    y = y / (np.max(np.abs(y)) + 1e-12) * flutter
    y += noise_amt * band(RNG.standard_normal(n), 1500, 5000)
    return vel * y * env_note(n, dur, att, rel)

def v_kazoo(f, dur, vel):      # a kazoo: a hummed tune made brassy by a paper membrane
    return buzzy(f, max(0.08, dur * 0.92), vel, FORMANT_KAZOO, 0.55, 0.025, 0.006, 0.03, 0.05)

def v_trumpet(f, dur, vel):    # a plastic toy trumpet: nasal and bright
    return buzzy(f, dur, vel, FORMANT_TRUMPET, 0.42, 0.018, 0.005, 0.05, 0.03, rel=0.08)

def v_recorder(f, dur, vel):   # a school recorder: nearly pure, a chiff of breath at the start
    d = max(0.08, dur * 0.9); n = int((d + 0.05) * SR); t = t_of(n)
    ph = glide_phase(f, n, 0.003 * np.sin(2 * np.pi * 4.6 * t) * np.minimum(1.0, t / 0.25))
    y = np.sin(ph) + 0.09 * np.sin(2 * ph) + 0.03 * np.sin(3 * ph)
    y = y * env_note(n, d, 0.035, 0.05)
    y += 0.06 * band(RNG.standard_normal(n), f * 1.5, f * 4.0) * env_note(n, d, 0.03, 0.05)
    y = add(y, 0.12 * burst(0.03, 1500, 6000, 0.01))
    return vel * y

def v_snare(vel, size=1.0):    # a tin toy drum: snares, the tin's ring, a little head
    d = 0.35
    y = 0.7 * burst(d, 1800, 9000, 0.055 * size)
    y += sines(1.0, d, [(830, 0.45, 0.06), (1420, 0.30, 0.045), (2210, 0.22, 0.035), (3120, 0.12, 0.02)], att=0.0004)
    y += sines(205, d, [(1, 0.6, 0.035)], att=0.0006)
    return vel * y

def v_cymbal(vel):             # a toy cymbal: thin and splashy
    d = 1.0; y = burst(d, 3000, 14000, 0.25)
    y += sines(1.0, d, [(3170, 0.25, 0.3), (4430, 0.2, 0.25), (6120, 0.15, 0.2)], att=0.0005)
    return vel * y

def v_wood(f, vel):            # a wood block
    y = sines(f, 0.14, [(1, 1.0, 0.032), (2.72, 0.35, 0.012), (4.9, 0.1, 0.006)], att=0.0004)
    return vel * add(y, 0.2 * burst(0.01, 2000, 8000, 0.0015))

def v_cast(vel):               # castanets: two little clacks
    y = burst(0.025, 1800, 8000, 0.0035) + sines(2600, 0.025, [(1, 0.5, 0.006)], att=0.0003)
    y = add(y, 0.6 * (burst(0.02, 1800, 8000, 0.003) + sines(2750, 0.02, [(1, 0.4, 0.005)], att=0.0003)), int(0.018 * SR))
    return vel * y

def v_click(f, vel, tau=0.004):  # one tooth of a ratchet, one tick of a clock
    y = sines(f, 0.05, [(1, 1.0, tau), (1.83, 0.4, tau * 0.6)], att=0.0003)
    return vel * add(y, 0.3 * burst(0.004, 3000, 10000, 0.0008))

def v_ratchet(dur, r0, r1, vel):  # winding a clockwork key: clicks faster and faster
    y = np.zeros(int((dur + 0.06) * SR)); t = 0.0; i = 0
    while t < dur:
        g = vel * (0.6 + 0.4 * (i % 3 == 0)) * (0.7 + 0.3 * t / dur)
        y = add(y, v_click(3400 + 300 * (i % 2), g, 0.003), int(t * SR))
        r = r0 + (r1 - r0) * (t / dur); t += 1.0 / r; i += 1
    return y

def v_bell(dur, vel):          # an alarm clock's bells, the hammer going between them
    y = np.zeros(int((dur + 0.5) * SR)); t = 0.0; i = 0
    while t < dur:
        f = 2150 if i % 2 == 0 else 2380
        g = vel * (1.0 - 0.5 * t / dur)
        y = add(y, g * sines(f, 0.5, [(1, 1.0, 0.22), (1.52, 0.5, 0.16), (2.43, 0.35, 0.1), (3.56, 0.2, 0.06)], att=0.0004), int(t * SR))
        t += 1.0 / 24.0; i += 1
    return y

# ---------------- the room's sound ----------------
def room_ir(rt, dark=2600.0):
    """a small room's tail: noise dying away (the top faster), a few early reflections"""
    n = int(rt * SR); t = t_of(n); x = RNG.standard_normal(n)
    lo = band(x, 0, dark); hi = x - lo
    h = lo * np.exp(-6.9 * t / rt) + 0.5 * hi * np.exp(-6.9 * t / (rt * 0.4))
    h *= np.minimum(1.0, t / 0.006)
    for d, a in [(0.009, 0.6), (0.014, 0.45), (0.021, 0.35), (0.029, 0.3), (0.037, 0.22)]:
        h[int(d * SR)] += a * np.sqrt(np.sum(h ** 2) / n) * 40
    return h / np.sqrt(np.sum(h ** 2))

IR = None
def wet(x, amt, circular):
    """x with the room added (circularly for a loop: the tail of the end comes round to the start)"""
    if amt <= 0: return x
    n = len(x)
    if circular:
        H = np.fft.rfft(IR, n); r = np.fft.irfft(np.fft.rfft(x) * H, n)
    else:
        m = n + len(IR); H = np.fft.rfft(IR, m); r = np.fft.irfft(np.fft.rfft(np.concatenate([x, np.zeros(len(IR))])) * H, m)
        x = np.concatenate([x, np.zeros(len(IR))])
    return x + amt * r

# ---------------- writing it down ----------------
class Loop:
    """a buffer the length of the loop: what runs past the end comes round to the start"""
    def __init__(self, seconds): self.n = int(round(seconds * SR)); self.y = np.zeros(self.n)
    def put(self, z, at):
        at %= self.n; z = z[:self.n]; k = min(len(z), self.n - at)
        self.y[at:at + k] += z[:k]
        if k < len(z): self.y[:len(z) - k] += z[k:]

def part(loop, events, voice, bpm, tr, gain, jit=0.0015, vel_of=accent):
    spb = 60.0 / bpm
    for b, beats, m in events:
        at = int(round((b * spb + RNG.normal(0, jit)) * SR)) if jit > 0 else int(round(b * spb * SR))
        loop.put(gain * voice(hz(m + tr), beats * spb, vel_of(b)), at)   # (a note pushed before the start comes in at the end)

def march(bpm, tr):
    """the six layers of the march (and the alarm clock, for the overtime), at bpm, tr semitones up"""
    sec = BARS * 4 * 60.0 / bpm
    tune = seq(TUNE); bass = seq(BASS)
    L = {k: Loop(sec) for k in ['box', 'xylo', 'beat', 'bass', 'tick', 'war', 'alarm']}
    # box: the tune on the music box, on the beats only (calmer), the chord's root at each bar, a soft high wood block on 1 and 3
    on_beat = [e for e in tune if abs(e[0] - round(e[0])) < 1e-6]
    part(L['box'], on_beat, v_box, bpm, tr + 12, 0.33)
    part(L['box'], [(i * 4.0, 4.0, midi(ROOT[c]) + 12) for i, c in enumerate(CHORDS)], v_box, bpm, tr, 0.18, vel_of=lambda b: 0.8)
    spb = 60.0 / bpm
    for i in range(BARS):
        for q in (0.0, 2.0): L['box'].put(v_wood(1300, 0.28 if q == 0 else 0.2), int(round((i * 4.0 + q) * spb * SR)))
    # xylo: the whole tune on the xylophone, pizzicato chords on 2 and 4
    part(L['xylo'], tune, v_xylo, bpm, tr + 12, 0.5)
    for i, c in enumerate(CHORDS):
        for q in (1.0, 3.0):
            part(L['xylo'], [(i * 4.0 + q, 0.5, midi(n)) for n in PIZZ[c]], v_pizz, bpm, tr, 0.22, jit=0.004, vel_of=lambda b: 0.8)
    # beat: wood block on 2 and 4, castanets on the off-beats, the clockwork key wound at the end of every other bar
    for i in range(BARS):
        for q in (1.0, 3.0): L['beat'].put(v_wood(850, 0.75), int(round((i * 4.0 + q) * spb * SR)))
        for q in (0.5, 1.5, 2.5) + ((3.5,) if i % 2 == 0 else ()):
            L['beat'].put(v_cast(0.33 if q != 2.5 else 0.4), int(round((i * 4.0 + q) * spb * SR)))
        if i % 2 == 1: L['beat'].put(v_ratchet(spb * 0.9, 26, 52, 0.32), int(round((i * 4.0 + 3.0) * spb * SR)))
    # bass: the boomwhackers' oom on 1 and 3, walking at the ends of the phrases
    part(L['bass'], bass, v_boom, bpm, tr, 0.85, vel_of=lambda b: 1.0 if abs(b % 4.0) < 1e-6 else 0.8)
    # tick: a clock in the room, tick and tock on the beats
    for i in range(BARS):
        for q in range(4): L['tick'].put(v_click(2900 if q % 2 == 0 else 1750, 0.6, 0.011), int(round((i * 4.0 + q) * spb * SR)))
    # war: kazoos on the tune an octave down, recorders on it, a toy piano's arpeggios, a glockenspiel on the strong beats
    # of the second halves, the tin drum, a toy cymbal at the top of A and B
    part(L['war'], tune, v_kazoo, bpm, tr - 12, 0.42)
    part(L['war'], tune, v_recorder, bpm, tr, 0.16)
    for i, c in enumerate(CHORDS):
        a = ARP[c]
        part(L['war'], [(i * 4.0 + 0.5 * j, 0.5, midi(a[p])) for j, p in enumerate([0, 2, 1, 2, 3, 2, 1, 2])], v_toypiano, bpm, tr, 0.2,
             vel_of=lambda b: 0.9 if abs(b - round(b)) < 1e-6 else 0.65)
    strong = [e for e in tune if (4 <= e[0] // 4 < 8 or 12 <= e[0] // 4 < 16) and abs((e[0] % 2.0)) < 1e-6]
    part(L['war'], strong, v_glock, bpm, tr + 12, 0.16)
    for i in range(BARS):
        fill = i % 4 == 3
        steps = {0: 1.0, 4: 0.5, 6: 0.62, 8: 0.85, 12: 0.5, 14: 0.62} if not fill else {0: 1.0, 4: 0.5, 6: 0.62, 8: 0.85}
        for s, g in steps.items():
            at = int(round((i * 4.0 + s * 0.25) * spb * SR))
            if s == 0 and i % 4 == 0: L['war'].put(v_snare(0.35), at - int(0.025 * SR))   # a flam into the phrase
            L['war'].put(v_snare(g), at)
        if fill:   # a roll over the last beat, louder and louder, into the next phrase
            for j in range(8): L['war'].put(v_snare(0.35 + 0.6 * j / 7.0, 0.8), int(round((i * 4.0 + 3.0 + j * 0.125) * spb * SR)))
        if i in (0, 8): L['war'].put(v_cymbal(0.5), int(round(i * 4.0 * spb * SR)))
    # alarm: the bedside alarm clock's second hand, hurrying (the overtime only)
    for i in range(BARS):
        for q in range(8): L['alarm'].put(v_click(3600 if q % 2 == 0 else 3150, 0.55 if q % 2 == 0 else 0.4, 0.02), int(round((i * 4.0 + q * 0.5) * spb * SR)))
    # the room on each
    for k, amt in [('box', 0.32), ('xylo', 0.16), ('beat', 0.14), ('bass', 0.08), ('tick', 0.35), ('war', 0.13), ('alarm', 0.1)]:
        L[k].y = wet(L[k].y, amt, True)
    return {k: v.y for k, v in L.items()}, sec

def lobby():
    """the briefing's music box on its own: the A strain, slower, with its chord tines on the eighths"""
    bpm = 80.0; sec = 8 * 4 * 60.0 / bpm; L = Loop(sec); spb = 60.0 / bpm
    part(L, seq(TUNE[:8]), v_box, bpm, 12, 0.6, jit=0.004)
    for i, c in enumerate(CHORDS[:8]):
        tones = [midi(n) + 12 for n in PIZZ[c]]
        for j in range(8):
            if j % 2 == 0 and j in (0, 4): continue   # (the tune has those)
            L.put(0.22 * v_box(hz(tones[j % 3]), spb, 0.7), int(round((i * 4.0 + 0.5 * j) * spb * SR)))
        L.put(0.3 * v_box(hz(midi(ROOT[c])), 4 * spb, 0.8), int(round(i * 4.0 * spb * SR)))
    return wet(L.y, 0.42, True), sec

def leadin():
    """the match is on: the tin drum, faster and faster, two bars into the march's first beat (4 s), and a clockwork key wound up"""
    T = 4.0; y = np.zeros(int((T + 1.0) * SR)); t = 0.0
    while True:
        r = 2.0 * (28.0 / 2.0) ** (t / T)   # strokes a second, from 2 to 28
        if t > T - 0.04: break
        y = add(y, v_snare(0.3 + 0.7 * (t / T) ** 1.5, 0.9), int(t * SR)); t += 1.0 / r
    y = add(y, v_ratchet(1.4, 18, 60, 0.35), int((T - 1.45) * SR))
    return wet(y, 0.12, False)

def trumpet(notes, scale):
    y = np.zeros(int(2.4 * SR)); t = 0.0
    for m, d, g in notes:
        y = add(y, g * v_trumpet(hz(m) * scale, d * 0.9, 1.0), int(t * SR)); t += d
    return wet(y, 0.2, False)

# ---------------- out ----------------
def norm(y, peak): return y * (peak / (np.max(np.abs(y)) + 1e-12))

def write(name, y, loop_len=None):
    os.makedirs(TMP, exist_ok=True); os.makedirs(OUT, exist_ok=True)
    if loop_len is not None: assert len(y) == loop_len, (name, len(y), loop_len)
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype('<i2')
    wav = os.path.join(TMP, name + '.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    ogg = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', '-fflags', '+bitexact', '-flags:a', '+bitexact', '-map_metadata', '-1', ogg], check=True)
    print('%-14s %6.2f s  peak %.2f  %6.1f KB' % (name, len(y) / SR, np.max(np.abs(y)), os.path.getsize(ogg) / 1024.0))

def main():
    global IR
    IR = room_ir(0.9)
    m, sec = march(120.0, 0); o, osec = march(150.0, 1)
    # one level for all the layers: the loudest way they are put together (the fight: all of them) just under full scale
    def worst(S):
        mixes = [S['war'] + 0.75 * S['xylo'] + S['beat'] + S['bass'], S['xylo'] + 0.85 * S['beat'] + 0.55 * S['bass'], S['box'] + 0.45 * S['tick'], S['bass'] + S['tick'] + S['alarm']]
        return max(np.max(np.abs(x)) for x in mixes)
    g = 0.89 / max(worst(m), worst(o))
    for k in ['box', 'xylo', 'beat', 'bass', 'tick', 'war']: write('m_' + k, m[k] * g, int(round(sec * SR)))
    for k in ['box', 'xylo', 'beat', 'bass', 'tick', 'war', 'alarm']: write('o_' + k, o[k] * g, int(round(osec * SR)))
    rms = np.sqrt(np.mean(((m['war'] + 0.75 * m['xylo'] + m['beat'] + m['bass']) * g) ** 2))
    print('the fight\'s mix: rms %.1f dBFS' % (20 * np.log10(rms)))
    ly, lsec = lobby(); write('lobby', norm(ly, 0.7), int(round(lsec * SR)))
    write('leadin', norm(leadin(), 0.85))
    write('ot_bell', norm(wet(v_bell(0.8, 1.0), 0.2, False), 0.6))
    up = 2.0 ** (1 / 12.0)   # (the overtime's key: F sharp)
    write('trumpet_us', norm(trumpet([(midi('C5'), 0.16, 0.9), (midi('F5'), 0.16, 0.9), (midi('A5'), 0.16, 0.95), (midi('C6'), 0.62, 1.0)], up), 0.6))
    write('trumpet_them', norm(trumpet([(midi('F4'), 0.2, 0.9), (midi('Ab4'), 0.2, 0.9), (midi('C5'), 0.2, 0.95), (midi('Ab4'), 0.2, 0.9), (midi('F4'), 0.55, 1.0)], up), 0.55))

if __name__ == '__main__':
    main()
