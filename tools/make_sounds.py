#!/usr/bin/env python3
"""Godot판의 효과음(godot/sounds/*.wav)을 만듭니다. 브라우저판은 WebAudio로 그때그때 합성하는데(src/03_core.js의 Sound),
같은 조합법(걸러 낸 잡음 + 미끄러지는 음)을 여기서 미리 계산해 파일로 둡니다. 파이썬 표준 라이브러리만 씁니다."""
import math, os, random, struct, sys, wave
SR = 22050
random.seed(7)

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
SOUNDS = {
    'shot_pistol': [N(0.16, 'bandpass', 2600, 700, 1.2, 0.9), T('triangle', 180, 60, 0.12, 0.6)],
    'shot_smg': [N(0.1, 'bandpass', 3600, 1200, 1, 0.7), T('square', 160, 70, 0.06, 0.25)],
    'shot_rifle': [N(0.035, 'highpass', 5200, 3000, 0.7, 1.1), N(0.17, 'bandpass', 2100, 520, 0.9, 1.35), T('sine', 95, 34, 0.22, 1.05), T('square', 210, 70, 0.06, 0.32),
                   N(0.9, 'lowpass', 1500, 90, 0.5, 0.42, 0.035), N(0.25, 'bandpass', 900, 380, 1.2, 0.22, 0.14)],
    'shot_lmg': [N(0.03, 'highpass', 4200, 2600, 0.8, 0.95), N(0.15, 'bandpass', 1500, 380, 0.8, 1.35), T('sine', 78, 30, 0.2, 1.15), T('square', 140, 55, 0.07, 0.38),
                 T('square', 2300, 1700, 0.018, 0.09, 0.028), N(0.45, 'lowpass', 900, 110, 0.5, 0.4, 0.02)],
    'shot_sniper': [N(0.22, 'bandpass', 3800, 600, 0.7, 1.4), T('sine', 90, 35, 0.35, 0.9), N(1.3, 'lowpass', 1400, 90, 0.4, 0.35, 0.08)],
    'shot_gl': [T('sine', 150, 55, 0.22, 0.9), N(0.2, 'lowpass', 1400, 200, 0.8, 0.6)],
    'shot_rocket': [T('sine', 120, 45, 0.3, 1.0), N(0.12, 'lowpass', 1600, 300, 0.8, 0.9), N(0.9, 'bandpass', 700, 2600, 0.9, 0.7, 0.03), N(1.1, 'lowpass', 900, 150, 0.6, 0.35, 0.1)],
    'shot_shotgun': [N(0.38, 'lowpass', 4200, 300, 0.7, 1.4), T('sine', 110, 38, 0.3, 0.9), N(0.6, 'lowpass', 1200, 120, 0.3, 0.3, 0.05)],
    'empty': [T('square', 1400, 900, 0.03, 0.12)],
    'reload0': [N(0.05, 'highpass', 3000, 2000, 1, 0.35), T('square', 600, 400, 0.04, 0.08)],
    'reload1': [N(0.06, 'highpass', 2200, 1600, 1, 0.45), T('square', 900, 500, 0.05, 0.1, 0.02)],
    'pump': [N(0.08, 'bandpass', 1500, 900, 2, 0.4), N(0.08, 'bandpass', 1100, 700, 2, 0.4, 0.12)],
    'hit': [T('sine', 1700, 1300, 0.07, 0.22)],
    'swing': [N(0.16, 'bandpass', 700, 2300, 1.3, 0.55)],
    'melee': [N(0.14, 'lowpass', 1100, 160, 0.9, 1.0), T('sine', 150, 55, 0.16, 0.7), N(0.08, 'bandpass', 1800, 700, 1.5, 0.4)],
    'boom': [N(1.1, 'lowpass', 2200, 60, 0.6, 1.6), T('sine', 90, 30, 0.8, 0.9)],
    'metal': [T('square', 3000, 1800, 0.04, 0.06)],
    'hurt': [T('sine', 140, 60, 0.22, 0.7), N(0.18, 'lowpass', 800, 200, 0.6, 0.5)],
    'step': [N(0.07, 'lowpass', 600, 150, 0.8, 0.18)],
    'land': [N(0.12, 'lowpass', 500, 90, 0.7, 0.45)],
    'crack': [N(0.18, 'bandpass', 1100, 500, 1.4, 0.9), N(0.3, 'lowpass', 700, 150, 0.6, 0.4, 0.03), T('triangle', 240, 90, 0.12, 0.3)],
    'hiss': [N(1.4, 'highpass', 2600, 5200, 0.7, 0.42), N(0.5, 'bandpass', 900, 300, 1.2, 0.3)],
}
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'sounds'); os.makedirs(out_dir, exist_ok=True)
for name, layers in SOUNDS.items():
    n = max(int(d * SR) + len(s) for d, s in layers); mix = [0.0] * n
    for d, s in layers:
        o = int(d * SR)
        for i, v in enumerate(s): mix[o + i] += v
    # the browser game runs everything through a compressor; here a soft limit keeps the loud ones from clipping
    data = b''.join(struct.pack('<h', int(max(-1.0, min(1.0, math.tanh(v * 0.55))) * 32000)) for v in mix)
    with wave.open(os.path.join(out_dir, name + '.wav'), 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)
print(len(SOUNDS), 'sounds')
