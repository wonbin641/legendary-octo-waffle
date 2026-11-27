#!/usr/bin/env python3
"""스테이지 5(Godot판에만 있는 장난감 방)의 효과음(godot/sounds/toy_*.wav)을 만듭니다. 파이썬 표준 라이브러리만 씁니다.
브라우저판에 있는 소리는 브라우저판 자신의 코드로 tools/render_sounds.js가 만듭니다(예전에 손으로 옮겨 두었던 브라우저판 소리의 조합은 지웠습니다).
- 잡음은 처음 만들 때와 같은 난수를 씁니다(시드 7, 예전에 앞에서 만들던 브라우저판 소리들이 쓰던 만큼 건너뛰고): 소리가 바뀌지 않습니다.
- render_sounds.js와 같이 SCALE배(절반)로 줄여 적고, 게임이 그만큼 되돌립니다(godot/scripts/snd.gd의 SCALE).
  python3 tools/make_sounds.py            # 장난감 소리 모두
  python3 tools/make_sounds.py toy_boom   # 이름을 주면 그것만"""
import math, os, random, struct, sys, wave
SR = 22050
SCALE = 0.5   # as tools/render_sounds.js stores the browser game's: half level, the game turns it back up
SEED = 7
SKIP = 475057   # the draws the browser game's hand-copied sounds took before these, when they were still made here (and dropped)

def noise(dur, kind, f0, f1, q, gain, delay=0.0):
    """white noise through a filter whose frequency slides from f0 to f1, fading out"""
    n = int(dur * SR); out = [0.0] * n; f1 = max(30.0, f1)
    x1 = x2 = y1 = y2 = 0.0; b0 = b1 = b2 = a1 = a2 = 0.0
    for i in range(n):
        u = i / n
        if i % 32 == 0:
            f = min(f0 * (f1 / f0) ** u, SR * 0.45); w = 2 * math.pi * f / SR; al = math.sin(w) / (2 * max(q, 0.05)); c = math.cos(w); a0 = 1 + al
            if kind == 'lowpass': b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
            elif kind == 'highpass': b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
            else: b0, b1, b2 = al, 0.0, -al
            b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, -2 * c / a0, (1 - al) / a0
        x = random.uniform(-1, 1); y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out[i] = y * gain * (0.0008 / gain) ** u
    return delay, out

def tone(kind, f0, f1, dur, gain, delay=0.0):
    """an oscillator sliding from f0 to f1, a 6 ms attack, fading out"""
    n = int(dur * SR); out = [0.0] * n; ph = 0.0; f1 = max(20.0, f1)
    for i in range(n):
        u = i / n; t = i / SR; ph += (f0 * (f1 / f0) ** u) / SR; p = ph % 1.0
        if kind == 'sine': v = math.sin(2 * math.pi * p)
        elif kind == 'square': v = 1.0 if p < 0.5 else -1.0
        elif kind == 'sawtooth': v = 2 * p - 1
        else: v = 4 * abs(p - 0.5) - 1
        env = gain * min(1.0, t / 0.006) * (0.0008 / gain) ** u
        out[i] = v * env * (0.5 if kind in ('square', 'sawtooth') else 1.0)
    return delay, out

N, T = noise, tone
BELL = (2090.0, 2480.0)                                  # the alarm clock's two bells
RING = lambda i: 1.0 if i < 24 else (32 - i) / 8.0       # ...its last strokes fading
SOUNDS = {
    # ---- stage 5, the toy room: plastic, springs, rubber bands, water. no real gunfire ----
    # foam-dart blaster: a puff of compressed air and the trigger spring; the dart bounces off with a soft 'tong'
    'toy_shot_rifle': lambda: [N(0.09, 'lowpass', 2600, 500, 0.8, 0.9), N(0.05, 'bandpass', 900, 400, 2, 0.5), T('square', 950, 320, 0.035, 0.14, 0.012), T('sine', 240, 120, 0.06, 0.35)],
    'toy_hit_rifle': lambda: [T('sine', 430, 170, 0.09, 0.5), N(0.03, 'bandpass', 900, 500, 1.5, 0.25)],
    'toy_mag_out': lambda: [N(0.03, 'bandpass', 1900, 1200, 2, 0.5), T('square', 720, 480, 0.025, 0.12), T('sine', 300, 180, 0.05, 0.25, 0.16), N(0.03, 'lowpass', 900, 300, 1, 0.3, 0.16)],
    'toy_mag_in': lambda: [N(0.025, 'bandpass', 1500, 900, 2, 0.5), T('square', 520, 380, 0.03, 0.14), N(0.03, 'bandpass', 2400, 1500, 2, 0.55, 0.07), T('square', 900, 600, 0.025, 0.14, 0.07)],
    'toy_slide': lambda: [N(0.07, 'highpass', 1800, 3200, 1, 0.4), T('square', 600, 420, 0.03, 0.1), N(0.05, 'highpass', 3200, 1700, 1, 0.5, 0.13), T('square', 820, 520, 0.03, 0.14, 0.13)],
    # pump water gun: a jet of water, a splash; the stopper pops, the tank gurgles full, three squeaky pumps
    'toy_shot_shotgun': lambda: [N(0.34, 'bandpass', 2600, 900, 0.7, 0.9), N(0.3, 'highpass', 4200, 2600, 0.6, 0.45), N(0.2, 'lowpass', 700, 200, 0.6, 0.4, 0.04)],
    'toy_hit_shotgun': lambda: [N(0.2, 'lowpass', 1100, 180, 0.7, 0.75), T('sine', 320, 110, 0.12, 0.35), N(0.12, 'highpass', 3600, 2200, 0.8, 0.22, 0.03)],
    'toy_cork': lambda: [T('sine', 280, 980, 0.05, 0.6), N(0.03, 'bandpass', 1400, 800, 2, 0.35)],
    'toy_glug': lambda: [T('sine', 170, 250, 0.09, 0.55), T('sine', 190, 280, 0.09, 0.55, 0.16), T('sine', 210, 310, 0.09, 0.55, 0.32), T('sine', 235, 340, 0.09, 0.5, 0.48), T('sine', 260, 380, 0.09, 0.45, 0.64),
                 N(0.8, 'lowpass', 500, 900, 0.8, 0.22)],
    'toy_pump': lambda: [N(0.09, 'highpass', 2200, 4200, 0.8, 0.45), T('sine', 900, 1500, 0.07, 0.16, 0.03)],
    # the tack crossbow with a laser pointer: the band creaks tight, sings 'ping', and the tack sticks with a 'tak'
    'toy_shot_sniper': lambda: [T('triangle', 1900, 620, 0.13, 0.6), T('sine', 3200, 1400, 0.07, 0.25), N(0.03, 'highpass', 5200, 3000, 0.8, 0.5)],
    'toy_hit_sniper': lambda: [N(0.03, 'bandpass', 2600, 1500, 2, 0.9), T('square', 520, 190, 0.04, 0.3), T('sine', 180, 90, 0.07, 0.4)],
    'toy_stretch': lambda: [T('sawtooth', 210, 540, 0.62, 0.2), T('sine', 420, 1080, 0.62, 0.1), N(0.6, 'bandpass', 700, 1700, 4, 0.2), N(0.03, 'bandpass', 2200, 1400, 2, 0.5, 0.64)],
    'toy_tack': lambda: [T('square', 2600, 1900, 0.02, 0.1), N(0.02, 'highpass', 4000, 3000, 1, 0.3)],
    # cap gun: a sharp crack every shot; the cylinder swings out, the spent ring is flicked off, a new one clicks on
    'toy_shot_smg': lambda: [N(0.03, 'highpass', 5200, 2600, 0.7, 1.2), N(0.05, 'bandpass', 2200, 1200, 1.2, 0.8), T('square', 1300, 420, 0.02, 0.2)],
    'toy_hit_smg': lambda: [N(0.02, 'bandpass', 2000, 1200, 2, 0.4), T('sine', 600, 300, 0.03, 0.2)],
    'toy_cyl_open': lambda: [N(0.03, 'bandpass', 2400, 1500, 2, 0.5), T('square', 1100, 700, 0.02, 0.1)],
    'toy_ring_off': lambda: [T('square', 1500, 900, 0.02, 0.14), N(0.02, 'highpass', 3600, 2400, 1, 0.3), T('sine', 2200, 1500, 0.04, 0.1, 0.12)],
    'toy_ring_on': lambda: [N(0.025, 'bandpass', 1800, 1200, 2, 0.5), T('square', 800, 600, 0.02, 0.12), N(0.02, 'bandpass', 2600, 1900, 2, 0.4, 0.06)],
    'toy_cyl_shut': lambda: [N(0.035, 'bandpass', 1600, 800, 1.5, 0.75), T('square', 520, 300, 0.03, 0.2)],
    # bottle rocket: the fuse fizzes, then a long whistle away, and a pop with crackles
    'toy_shot_rocket': lambda: [N(0.22, 'highpass', 6500, 4200, 0.6, 0.5), N(0.9, 'bandpass', 1100, 3800, 1.2, 0.7, 0.2), T('sine', 1500, 2700, 0.85, 0.2, 0.22), N(0.5, 'lowpass', 900, 250, 0.6, 0.3, 0.2)],
    'toy_boom': lambda: [N(0.22, 'lowpass', 3200, 200, 0.7, 1.5), T('sine', 210, 70, 0.22, 0.8), N(0.03, 'highpass', 6000, 3500, 0.8, 0.5, 0.18), N(0.03, 'highpass', 5500, 3200, 0.8, 0.45, 0.27),
                 N(0.03, 'highpass', 6500, 3800, 0.8, 0.4, 0.35), N(0.03, 'highpass', 5800, 3400, 0.8, 0.35, 0.46), N(0.03, 'highpass', 6200, 3600, 0.8, 0.28, 0.58), N(0.5, 'bandpass', 2400, 900, 0.8, 0.25, 0.1)],
    'toy_fuse': lambda: [N(0.55, 'highpass', 6800, 4600, 0.6, 0.45), N(0.06, 'bandpass', 2600, 1800, 2, 0.5), T('square', 1800, 1200, 0.02, 0.1)],
    'toy_tube': lambda: [N(0.2, 'lowpass', 800, 300, 0.8, 0.5), T('sine', 240, 150, 0.12, 0.3, 0.14)],
    # the rest of the toy box
    'toy_shot_pistol': lambda: [T('sine', 520, 210, 0.07, 0.6), N(0.04, 'lowpass', 1800, 500, 0.8, 0.5)],
    'toy_hit_pistol': lambda: [T('sine', 380, 200, 0.06, 0.4), N(0.03, 'bandpass', 1200, 700, 1.5, 0.3)],
    'toy_shot_gl': lambda: [T('triangle', 260, 110, 0.16, 0.8), T('sine', 520, 260, 0.1, 0.3), N(0.04, 'bandpass', 1500, 600, 1.5, 0.4)],
    'toy_shot_lmg': lambda: [T('triangle', 620, 250, 0.05, 0.55), N(0.025, 'highpass', 3800, 2200, 0.8, 0.5), T('sine', 1300, 700, 0.03, 0.15)],
    'toy_hit_lmg': lambda: [N(0.025, 'bandpass', 1700, 900, 2, 0.4), T('sine', 500, 260, 0.03, 0.2)],
    'toy_shot_flame': lambda: [N(0.16, 'bandpass', 1800, 2600, 0.6, 0.45), N(0.16, 'lowpass', 600, 400, 0.6, 0.3)],
    'toy_ruler': lambda: [N(0.03, 'bandpass', 2200, 1300, 1.5, 0.9), T('square', 900, 420, 0.04, 0.25), T('sine', 260, 150, 0.06, 0.3)],
    'toy_click': lambda: [N(0.03, 'bandpass', 1900, 1200, 2, 0.5), T('square', 720, 480, 0.025, 0.12)],
    # ---- the toy room's screens (new sounds go here, at the end: the ones above keep their noise) ----
    # the twin-bell alarm clock of the last 30 seconds: its hammer between two bells, 23 strokes a second, dying away
    'toy_alarm': lambda: [T('sine', BELL[i % 2], BELL[i % 2] * 0.996, 0.07, 0.85 * RING(i), i * 0.043) for i in range(32)]
        + [T('sine', BELL[i % 2] * 2.76, BELL[i % 2] * 2.74, 0.04, 0.3 * RING(i), i * 0.043) for i in range(32)]
        + [N(0.012, 'highpass', 5200, 3600, 1, 0.4 * RING(i), i * 0.043) for i in range(32)],
    # a package torn open at the toy shop's shelf: the card ripping in a stutter that rises, then the bubble's pop
    'toy_rip': lambda: [N(0.022, 'bandpass', 2200 + i * 90, 3000 + i * 90, 1.2, 0.85, i * 0.0125) for i in range(22)]
        + [N(0.3, 'highpass', 3000, 5200, 0.7, 0.45), T('sine', 720, 300, 0.06, 0.7, 0.3), N(0.04, 'lowpass', 1500, 400, 0.8, 0.4, 0.3)],
}
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'sounds'); os.makedirs(out_dir, exist_ok=True)
only = sys.argv[1:]
for name in only:
    if name not in SOUNDS: sys.exit('no such sound: ' + name)
# every sound is worked out in this order whatever is asked for (each takes its noise after the one before), so each keeps
# the noise it has had since it was made
random.seed(SEED)
for _ in range(SKIP): random.random()
worked = [(name, recipe()) for name, recipe in SOUNDS.items()]
made = 0
for name, layers in worked:
    if only and name not in only: continue
    n = max(int(d * SR) + len(s) for d, s in layers); mix = [0.0] * n
    for d, s in layers:
        o = int(d * SR)
        for i, v in enumerate(s): mix[o + i] += v
    # the browser game runs everything through a compressor; here a soft limit keeps the loud ones from clipping
    data = b''.join(struct.pack('<h', int(round(max(-1.0, min(1.0, math.tanh(v * 0.55))) * SCALE * 32767))) for v in mix)
    with wave.open(os.path.join(out_dir, name + '.wav'), 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)
    made += 1
print(made, 'toy sounds, stored at', SCALE, 'of full level')
