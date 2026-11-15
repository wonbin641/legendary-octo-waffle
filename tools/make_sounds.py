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
    # zombies: a low moan, a bite, the growl of one getting back up, the boss's roar; your ears ringing after a charge; the syringe and the cure
    'moan': [T('sawtooth', 95, 74, 0.95, 0.22), T('sawtooth', 97, 70, 0.95, 0.12, 0.03), N(0.9, 'lowpass', 650, 400, 3, 0.12)],
    'bite': [N(0.25, 'bandpass', 900, 300, 1.5, 1.1), T('sawtooth', 220, 60, 0.3, 0.5)],
    'revive': [T('sawtooth', 65, 150, 0.8, 0.3), N(0.6, 'lowpass', 300, 800, 1, 0.3)],
    'rage': [T('sawtooth', 95, 42, 1.3, 0.5), N(1.2, 'lowpass', 520, 110, 1.5, 0.6), T('square', 190, 70, 0.9, 0.14, 0.1)],
    'ring': [T('sine', 3400, 3300, 2.0, 0.06), T('sine', 3560, 3480, 1.8, 0.04, 0.05), N(0.3, 'lowpass', 300, 80, 1, 0.5)],
    'inject': [T('square', 2200, 1500, 0.03, 0.06), N(0.05, 'highpass', 5000, 3000, 1, 0.2, 0.02), N(0.08, 'bandpass', 1200, 700, 2, 0.35, 0.32), N(0.55, 'bandpass', 2800, 1700, 3, 0.2, 0.42)],
    'cured': [T('sine', 523, 523, 0.38, 0.17), T('sine', 659, 659, 0.38, 0.17, 0.085), T('sine', 784, 784, 0.38, 0.17, 0.17), T('sine', 1047, 1047, 0.38, 0.17, 0.255), T('triangle', 1568, 2093, 0.55, 0.08, 0.34), N(0.7, 'highpass', 6500, 9000, 1, 0.05, 0.12)],
    # animals: each kind's voice; the lab's alarm, cage bars and the scientist; the ground shaking
    'roar_cat': [T('sawtooth', 112, 60, 0.9, 0.38), N(0.9, 'lowpass', 520, 160, 2, 0.5)],
    'roar_trumpet': [T('sawtooth', 300, 720, 0.45, 0.32), T('sawtooth', 720, 480, 0.8, 0.28, 0.4), N(0.6, 'bandpass', 1400, 700, 3, 0.25, 0.3)],
    'roar_beat': [T('sine', 95, 60, 0.09, 0.55, i * 0.09) for i in range(7)] + [N(0.06, 'lowpass', 500, 200, 1, 0.4, i * 0.09) for i in range(7)] + [T('sawtooth', 140, 80, 0.7, 0.3, 0.7), N(0.7, 'lowpass', 700, 200, 1.5, 0.4, 0.7)],
    'roar_bray': [T('square', 620 + i * 60, 880, 0.16, 0.12, i * 0.2) for i in range(3)],
    'roar_grunt': [T('sine', 75, 45, 0.55, 0.6), N(0.5, 'lowpass', 380, 90, 1.2, 0.5)],
    'alarm': [T('square', 660, 660, 0.18, 0.12, i * 0.42) for i in range(3)] + [T('square', 520, 520, 0.18, 0.12, i * 0.42 + 0.2) for i in range(3)],
    'clank': [T('square', 450, 300, 0.12, 0.08), T('triangle', 1500, 900, 0.18, 0.07), N(0.12, 'bandpass', 2200, 1200, 3, 0.25)],
    'clang': [N(0.5, 'bandpass', 1800, 600, 2, 0.9), T('triangle', 620, 300, 0.6, 0.3), T('square', 240, 120, 0.3, 0.2), N(0.3, 'lowpass', 500, 100, 1, 0.8)],
    'press': [T('square', 180, 90, 0.08, 0.25), N(0.06, 'lowpass', 900, 300, 1, 0.4)],
    'cackle': [T('square', 900 + (i * 137) % 400, 700, 0.07, 0.07, i * 0.085) for i in range(7)] + [N(0.6, 'bandpass', 2600, 1900, 4, 0.08)],
    'quake': [N(1.4, 'lowpass', 900, 40, 0.6, 1.8), T('sine', 60, 25, 1.2, 1.0), N(0.5, 'bandpass', 1500, 400, 1, 0.6, 0.03)],
    'siren': [T('sawtooth', 520, 880, 0.5, 0.11, i * 0.6) for i in range(3)] + [T('sawtooth', 880, 520, 0.1, 0.06, i * 0.6 + 0.5) for i in range(3)],
    'zap': [T('square', 1300, 300, 0.12, 0.16), T('sawtooth', 650, 150, 0.12, 0.1), N(0.05, 'highpass', 4000, 3000, 1, 0.12)],
    'thud': [N(0.2, 'lowpass', 420, 90, 0.7, 0.45)],
    'shot_far': [N(0.14, 'bandpass', 2200, 600, 1, 0.75), T('triangle', 170, 60, 0.1, 0.35)],
    'whiz': [N(0.15, 'bandpass', 3000, 1200, 4, 0.25)],
    'kill': [T('triangle', 900, 1400, 0.09, 0.25), T('triangle', 1400, 1900, 0.12, 0.2, 0.06)],
    'headshot': [T('sine', 2400, 1800, 0.07, 0.32), N(0.05, 'bandpass', 3200, 1800, 1.5, 0.4)],
    'coin': [T('triangle', 1760, 1760, 0.07, 0.18), T('triangle', 2350, 2350, 0.16, 0.16, 0.06)],
    'pickup_hp': [T('triangle', 520, 520, 0.08, 0.25), T('triangle', 650, 650, 0.08, 0.25, 0.07), T('triangle', 780, 780, 0.14, 0.25, 0.14)],
    'pickup_ammo': [T('triangle', 400, 400, 0.08, 0.25), T('triangle', 500, 500, 0.08, 0.25, 0.07), T('triangle', 600, 600, 0.14, 0.25, 0.14)],
    'buy': [T('triangle', 880, 880, 0.14, 0.18), T('triangle', 1175, 1175, 0.14, 0.18, 0.07), T('triangle', 1568, 1568, 0.14, 0.18, 0.14), N(0.06, 'highpass', 3000, 2000, 1, 0.15)],
    'clear': [T('triangle', 523, 523, 0.3, 0.2), T('triangle', 659, 659, 0.3, 0.2, 0.1), T('triangle', 784, 784, 0.3, 0.2, 0.2), T('triangle', 1046, 1046, 0.3, 0.2, 0.3)],
    # ---- stage 5, the toy room: plastic, springs, rubber bands, water. no real gunfire ----
    # foam-dart blaster: a puff of compressed air and the trigger spring; the dart bounces off with a soft 'tong'
    'toy_shot_rifle': [N(0.09, 'lowpass', 2600, 500, 0.8, 0.9), N(0.05, 'bandpass', 900, 400, 2, 0.5), T('square', 950, 320, 0.035, 0.14, 0.012), T('sine', 240, 120, 0.06, 0.35)],
    'toy_hit_rifle': [T('sine', 430, 170, 0.09, 0.5), N(0.03, 'bandpass', 900, 500, 1.5, 0.25)],
    'toy_mag_out': [N(0.03, 'bandpass', 1900, 1200, 2, 0.5), T('square', 720, 480, 0.025, 0.12), T('sine', 300, 180, 0.05, 0.25, 0.16), N(0.03, 'lowpass', 900, 300, 1, 0.3, 0.16)],
    'toy_mag_in': [N(0.025, 'bandpass', 1500, 900, 2, 0.5), T('square', 520, 380, 0.03, 0.14), N(0.03, 'bandpass', 2400, 1500, 2, 0.55, 0.07), T('square', 900, 600, 0.025, 0.14, 0.07)],
    'toy_slide': [N(0.07, 'highpass', 1800, 3200, 1, 0.4), T('square', 600, 420, 0.03, 0.1), N(0.05, 'highpass', 3200, 1700, 1, 0.5, 0.13), T('square', 820, 520, 0.03, 0.14, 0.13)],
    # pump water gun: a jet of water, a splash; the stopper pops, the tank gurgles full, three squeaky pumps
    'toy_shot_shotgun': [N(0.34, 'bandpass', 2600, 900, 0.7, 0.9), N(0.3, 'highpass', 4200, 2600, 0.6, 0.45), N(0.2, 'lowpass', 700, 200, 0.6, 0.4, 0.04)],
    'toy_hit_shotgun': [N(0.2, 'lowpass', 1100, 180, 0.7, 0.75), T('sine', 320, 110, 0.12, 0.35), N(0.12, 'highpass', 3600, 2200, 0.8, 0.22, 0.03)],
    'toy_cork': [T('sine', 280, 980, 0.05, 0.6), N(0.03, 'bandpass', 1400, 800, 2, 0.35)],
    'toy_glug': [T('sine', 170, 250, 0.09, 0.55), T('sine', 190, 280, 0.09, 0.55, 0.16), T('sine', 210, 310, 0.09, 0.55, 0.32), T('sine', 235, 340, 0.09, 0.5, 0.48), T('sine', 260, 380, 0.09, 0.45, 0.64),
                 N(0.8, 'lowpass', 500, 900, 0.8, 0.22)],
    'toy_pump': [N(0.09, 'highpass', 2200, 4200, 0.8, 0.45), T('sine', 900, 1500, 0.07, 0.16, 0.03)],
    # the tack crossbow with a laser pointer: the band creaks tight, sings 'ping', and the tack sticks with a 'tak'
    'toy_shot_sniper': [T('triangle', 1900, 620, 0.13, 0.6), T('sine', 3200, 1400, 0.07, 0.25), N(0.03, 'highpass', 5200, 3000, 0.8, 0.5)],
    'toy_hit_sniper': [N(0.03, 'bandpass', 2600, 1500, 2, 0.9), T('square', 520, 190, 0.04, 0.3), T('sine', 180, 90, 0.07, 0.4)],
    'toy_stretch': [T('sawtooth', 210, 540, 0.62, 0.2), T('sine', 420, 1080, 0.62, 0.1), N(0.6, 'bandpass', 700, 1700, 4, 0.2), N(0.03, 'bandpass', 2200, 1400, 2, 0.5, 0.64)],
    'toy_tack': [T('square', 2600, 1900, 0.02, 0.1), N(0.02, 'highpass', 4000, 3000, 1, 0.3)],
    # cap gun: a sharp crack every shot; the cylinder swings out, the spent ring is flicked off, a new one clicks on
    'toy_shot_smg': [N(0.03, 'highpass', 5200, 2600, 0.7, 1.2), N(0.05, 'bandpass', 2200, 1200, 1.2, 0.8), T('square', 1300, 420, 0.02, 0.2)],
    'toy_hit_smg': [N(0.02, 'bandpass', 2000, 1200, 2, 0.4), T('sine', 600, 300, 0.03, 0.2)],
    'toy_cyl_open': [N(0.03, 'bandpass', 2400, 1500, 2, 0.5), T('square', 1100, 700, 0.02, 0.1)],
    'toy_ring_off': [T('square', 1500, 900, 0.02, 0.14), N(0.02, 'highpass', 3600, 2400, 1, 0.3), T('sine', 2200, 1500, 0.04, 0.1, 0.12)],
    'toy_ring_on': [N(0.025, 'bandpass', 1800, 1200, 2, 0.5), T('square', 800, 600, 0.02, 0.12), N(0.02, 'bandpass', 2600, 1900, 2, 0.4, 0.06)],
    'toy_cyl_shut': [N(0.035, 'bandpass', 1600, 800, 1.5, 0.75), T('square', 520, 300, 0.03, 0.2)],
    # bottle rocket: the fuse fizzes, then a long whistle away, and a pop with crackles
    'toy_shot_rocket': [N(0.22, 'highpass', 6500, 4200, 0.6, 0.5), N(0.9, 'bandpass', 1100, 3800, 1.2, 0.7, 0.2), T('sine', 1500, 2700, 0.85, 0.2, 0.22), N(0.5, 'lowpass', 900, 250, 0.6, 0.3, 0.2)],
    'toy_boom': [N(0.22, 'lowpass', 3200, 200, 0.7, 1.5), T('sine', 210, 70, 0.22, 0.8), N(0.03, 'highpass', 6000, 3500, 0.8, 0.5, 0.18), N(0.03, 'highpass', 5500, 3200, 0.8, 0.45, 0.27),
                 N(0.03, 'highpass', 6500, 3800, 0.8, 0.4, 0.35), N(0.03, 'highpass', 5800, 3400, 0.8, 0.35, 0.46), N(0.03, 'highpass', 6200, 3600, 0.8, 0.28, 0.58), N(0.5, 'bandpass', 2400, 900, 0.8, 0.25, 0.1)],
    'toy_fuse': [N(0.55, 'highpass', 6800, 4600, 0.6, 0.45), N(0.06, 'bandpass', 2600, 1800, 2, 0.5), T('square', 1800, 1200, 0.02, 0.1)],
    'toy_tube': [N(0.2, 'lowpass', 800, 300, 0.8, 0.5), T('sine', 240, 150, 0.12, 0.3, 0.14)],
    # the rest of the toy box
    'toy_shot_pistol': [T('sine', 520, 210, 0.07, 0.6), N(0.04, 'lowpass', 1800, 500, 0.8, 0.5)],
    'toy_hit_pistol': [T('sine', 380, 200, 0.06, 0.4), N(0.03, 'bandpass', 1200, 700, 1.5, 0.3)],
    'toy_shot_gl': [T('triangle', 260, 110, 0.16, 0.8), T('sine', 520, 260, 0.1, 0.3), N(0.04, 'bandpass', 1500, 600, 1.5, 0.4)],
    'toy_shot_lmg': [T('triangle', 620, 250, 0.05, 0.55), N(0.025, 'highpass', 3800, 2200, 0.8, 0.5), T('sine', 1300, 700, 0.03, 0.15)],
    'toy_hit_lmg': [N(0.025, 'bandpass', 1700, 900, 2, 0.4), T('sine', 500, 260, 0.03, 0.2)],
    'toy_shot_flame': [N(0.16, 'bandpass', 1800, 2600, 0.6, 0.45), N(0.16, 'lowpass', 600, 400, 0.6, 0.3)],
    'toy_ruler': [N(0.03, 'bandpass', 2200, 1300, 1.5, 0.9), T('square', 900, 420, 0.04, 0.25), T('sine', 260, 150, 0.06, 0.3)],
    'toy_click': [N(0.03, 'bandpass', 1900, 1200, 2, 0.5), T('square', 720, 480, 0.025, 0.12)],
    # ---- the armed men of 1-2 ----
    'saber_hum': [T('sawtooth', 92, 96, 0.9, 0.08), T('sine', 184, 190, 0.9, 0.07)],
    'saber_swing': [T('sawtooth', 120, 260, 0.25, 0.2), T('sine', 300, 140, 0.25, 0.15)],
    'saber_hit': [N(0.3, 'bandpass', 1800, 900, 2, 0.5), T('sawtooth', 260, 80, 0.3, 0.3)],
    'bat_hit': [T('triangle', 2100, 1700, 0.18, 0.28), T('square', 950, 600, 0.08, 0.1), N(0.16, 'lowpass', 900, 200, 1, 0.6)],
    'squelch': [N(0.28, 'lowpass', 900, 160, 1, 0.65), T('sine', 170, 45, 0.22, 0.4)],
    'swoosh': [N(0.28, 'bandpass', 500, 1400, 1.5, 0.45)],
    'scream': [T('sawtooth', 260, 880, 0.38, 0.32), N(0.45, 'bandpass', 1500, 2600, 2, 0.35)],
    'beep': [T('square', 1900, 1900, 0.05, 0.12), T('square', 1900, 1900, 0.05, 0.12, 0.09), T('square', 1900, 1900, 0.05, 0.12, 0.18)],
    'flame': [N(0.22, 'lowpass', 900, 500, 0.7, 0.4), N(0.2, 'bandpass', 300, 200, 1, 0.3)],
    'thump': [T('sine', 140, 60, 0.18, 0.45), N(0.12, 'lowpass', 600, 200, 1, 0.35)],
    'ping': [T('triangle', 2600, 2400, 0.35, 0.22), T('sine', 3900, 3600, 0.25, 0.12, 0.01), N(0.05, 'highpass', 5000, 4000, 1, 0.3)],
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
