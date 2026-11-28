#!/usr/bin/env python3
"""Godot판에만 있는 스테이지의 효과음을 만듭니다: 스테이지 5 장난감 방(godot/sounds/toy_*.wav)과 스테이지 6-1 엘프의 숲(elf_*.wav), 그리고 종족 전투의 소리(rm_*.wav). 파이썬 표준 라이브러리만 씁니다.
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
# a brick figure falling apart: each brick's pitch, loudness and moment (thick at first, the last few rolling on)
CRUMBLE = [(2300, 0.8, 0.0), (1700, 0.7, 0.018), (2700, 0.6, 0.04), (1500, 0.75, 0.062), (2100, 0.65, 0.09), (3000, 0.5, 0.11), (1800, 0.7, 0.14), (2400, 0.55, 0.17),
           (1600, 0.6, 0.21), (2600, 0.45, 0.25), (1900, 0.5, 0.3), (2200, 0.4, 0.37), (1650, 0.4, 0.45), (2500, 0.3, 0.55)]
# ---- the race battle's tools (rm_*) ----
def held(kind, f0, f1, dur, gain, delay=0.0, rise=0.05, fall=0.05):
    """tone() without its fading: it swells in over rise, holds, and is let go over fall"""
    d, s = tone(kind, f0, f1, dur, gain, delay); n = len(s)
    return d, [v * (gain / 0.0008) ** (i / n) * min(1.0, i / (rise * SR), (n - i) / (fall * SR)) for i, v in enumerate(s)]
H = held
BACK = lambda layer: (layer[0], layer[1][::-1])          # a layer played backwards: it swells, and stops short
NOTE = lambda m: 440.0 * 2.0 ** ((m - 69) / 12.0)        # a note's pitch (69 is the A above middle C)
GLISS = (74, 76, 79, 81, 84, 86, 88, 91, 93, 96, 98)     # a harp's run up, from D5 to D7
PORTAL = [(1.0, 0.36, 1.2), (2.0, 0.14, 0.9), (2.76, 0.11, 0.6), (5.4, 0.05, 0.3), (0.5, 0.09, 1.2)]   # the portal bell's partials: ratio, loudness, length
PLATES = [(520, 0.8, 0.0), (810, 0.6, 0.05), (430, 0.7, 0.11), (960, 0.5, 0.17), (640, 0.55, 0.25), (380, 0.5, 0.35), (720, 0.35, 0.47)]   # armour falling: each plate's pitch, loudness and moment
# crystal breaking: each piece's pitch, loudness and moment
SHARDS = [(5200, 0.8, 0.0), (3900, 0.7, 0.02), (6100, 0.6, 0.05), (4500, 0.65, 0.085), (3400, 0.55, 0.13), (5600, 0.5, 0.18), (4100, 0.45, 0.24), (6400, 0.35, 0.31), (3700, 0.35, 0.4), (5000, 0.25, 0.5)]
def ping(f, gain, d=0.0, ring=1.0):
    """a glassy ping at f: a glass's overtones over it, the tick of the strike"""
    return [T('sine', f, f * 0.997, 0.3 * ring, gain, d), T('sine', f * 2.76, f * 2.75, 0.16 * ring, gain * 0.4, d), T('sine', f * 5.4, f * 5.38, 0.07 * ring, gain * 0.18, d), N(0.012, 'highpass', 6000, 4000, 1, gain * 0.7, d)]
def pluck(f, gain, d=0.0, dur=0.5):
    """a harp's string plucked"""
    return [T('triangle', f, f * 0.998, dur, gain, d), T('sine', f * 2, f * 1.996, dur * 0.6, gain * 0.3, d), T('sine', f * 3, f * 2.99, dur * 0.3, gain * 0.12, d)]
def clank(f, gain, d=0.0):
    """iron on iron: the knock and a short ring"""
    return [N(0.04, 'bandpass', f * 2.6, f * 1.5, 2, gain, d), T('square', f, f * 0.97, 0.06, gain * 0.25, d), T('sine', f * 1.47, f * 1.46, 0.22, gain * 0.35, d), T('sine', f * 2.09, f * 2.08, 0.15, gain * 0.22, d)]
def horn(f, gain, d, dur):
    """a war horn's note: its overtones, the high ones the last to come"""
    return [H('sine', f * h, f * h, dur, gain / h ** 1.2, d, 0.03 + 0.012 * h, 0.12) for h in range(1, 8)] + [H('sawtooth', f * 1.004, f * 1.004, dur, gain * 0.25, d, 0.1, 0.12)]
def shatter(k, gain, d=0.0):
    """crystal breaking, its pieces k times as far apart"""
    return [N(0.02, 'highpass', f * 1.3, f * 0.8, 1, g * gain, d + t * k) for f, g, t in SHARDS] + [T('sine', f, f * 0.985, 0.09, g * gain * 0.25, d + t * k) for f, g, t in SHARDS]
def ember():
    """the hellfire staff's ember: a dry spit, a crackle"""
    return [N(0.07, 'bandpass', 1500, 650, 1.2, 0.7), T('sine', 340, 170, 0.045, 0.3), N(0.012, 'highpass', 4600, 3000, 1, 0.3, 0.008)]
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
    # ---- toys break (scripts/toybreak.gd) ----
    # a plastic soldier toppling on its base: two hollow knocks and a duller one as it lies
    'toy_clatter': lambda: [N(0.03, 'bandpass', 1300, 800, 3, 0.95), T('sine', 520, 300, 0.05, 0.45), N(0.025, 'bandpass', 1500, 1000, 3, 0.6, 0.09), T('sine', 610, 380, 0.035, 0.28, 0.09),
                    N(0.05, 'lowpass', 700, 220, 0.8, 0.7, 0.19), T('sine', 210, 120, 0.07, 0.45, 0.19)],
    # an action figure's ball joints coming out: three quick pops
    'toy_pop': lambda: [T('sine', 420, 1500, 0.04, 0.8), N(0.02, 'bandpass', 2000, 1200, 2, 0.4), T('sine', 520, 1700, 0.03, 0.5, 0.055), T('sine', 380, 1300, 0.035, 0.45, 0.1), N(0.015, 'bandpass', 2400, 1500, 2, 0.3, 0.1)],
    # a wind-up key running wild: a ratchet rattling down as the spring lets go
    'toy_unwind': lambda: [N(0.012, 'bandpass', 2700 - i * 34, 1900 - i * 26, 2.5, 0.75 - i * 0.008, 0.016 * i + 0.00042 * i * i) for i in range(38)]
        + [T('square', 950 - i * 12, 640 - i * 8, 0.011, 0.11, 0.016 * i + 0.00042 * i * i) for i in range(38)] + [T('sawtooth', 230, 90, 1.1, 0.12)],
    # ...and the puff as it gives out
    'toy_puff': lambda: [N(0.3, 'lowpass', 1900, 280, 0.7, 0.85), N(0.2, 'highpass', 3600, 1800, 0.7, 0.25), T('sine', 170, 70, 0.13, 0.45)],
    # a brick figure coming apart: its bricks scattering over the floor
    'toy_crumble': lambda: [N(0.02, 'bandpass', f, f * 0.7, 2.5, g, d) for f, g, d in CRUMBLE] + [T('square', f * 0.4, f * 0.3, 0.014, g * 0.16, d) for f, g, d in CRUMBLE],
    # a brick underfoot
    'toy_rattle': lambda: [N(0.018, 'bandpass', 2200, 1500, 2.5, 0.65), T('square', 820, 560, 0.02, 0.11), N(0.016, 'bandpass', 1700, 1150, 2.5, 0.45, 0.062), T('square', 640, 450, 0.018, 0.08, 0.062)],
    # a wet shoe on the floor
    'toy_squeak': lambda: [T('sine', 1500, 2500, 0.05, 0.36), T('sine', 2500, 1850, 0.045, 0.3, 0.045), N(0.06, 'bandpass', 3000, 2200, 3, 0.12)],
    # soda: the hiss of it, and bubbles coming up through the syrup
    'toy_fizz': lambda: [N(0.9, 'highpass', 5200, 7000, 0.6, 0.34)] + [T('sine', 480 + i * 70, 900 + i * 90, 0.03, 0.2, 0.05 + i * 0.1) for i in range(8)],
    # a spark across the works of a wind-up car
    'toy_zap': lambda: [N(0.03, 'highpass', 6000, 3000, 0.8, 0.6), T('sawtooth', 112, 92, 0.05, 0.25), N(0.02, 'highpass', 7000, 4000, 0.8, 0.4, 0.04)],
    # a stud popping off a brick
    'toy_stud': lambda: [T('square', 1900, 1400, 0.012, 0.13), N(0.012, 'bandpass', 3000, 2200, 3, 0.38)],
    # the claw's motor running it down its cable, and the clack as it stops
    'toy_crane': lambda: [T('sawtooth', 140, 196, 0.5, 0.2), N(0.5, 'bandpass', 900, 1300, 3, 0.16), N(0.03, 'bandpass', 1500, 900, 2, 0.6, 0.5), T('square', 430, 300, 0.03, 0.14, 0.5)],
    # a broom across the floor: two strokes
    'toy_sweep': lambda: [N(0.5, 'bandpass', 1200, 2800, 0.8, 0.55), N(0.6, 'bandpass', 1000, 2400, 0.8, 0.5, 0.62), N(0.4, 'highpass', 4200, 5600, 0.7, 0.16, 0.1)],
    # ---- stage 6-1, the elves' Silverwood (scripts/folk.gd, scripts/elfwood.gd): glass, wind and bells. no gunfire either ----
    # a repeating crossbow's bolt of light: a short bright note falling, glass over it
    'elf_bolt': lambda: [T('triangle', 1700, 720, 0.08, 0.5), T('sine', 2700, 1350, 0.05, 0.2), N(0.03, 'highpass', 5000, 3000, 0.8, 0.3)],
    # a longbow let go: the string's thrum and the arrow's rush
    'elf_arrow': lambda: [T('sine', 190, 92, 0.17, 0.65), N(0.16, 'bandpass', 1900, 600, 1.0, 0.5), T('triangle', 950, 420, 0.05, 0.2)],
    # a mage's ball of light sent on its way: a hum rising; and its burst
    'elf_orb': lambda: [T('sine', 220, 520, 0.4, 0.34), T('sine', 330, 780, 0.4, 0.2), N(0.3, 'bandpass', 900, 2200, 2, 0.14)],
    'elf_pop': lambda: [T('sine', 300, 80, 0.2, 0.8), N(0.18, 'lowpass', 2600, 300, 0.7, 0.85), T('sine', 1400, 500, 0.1, 0.25)],
    # a blade dancer: the swing through the air, the cut landing, the wind under a leap
    'elf_swish': lambda: [N(0.12, 'bandpass', 1400, 3600, 1.2, 0.6)],
    'elf_cut': lambda: [N(0.05, 'bandpass', 2600, 1200, 1.5, 0.9), T('square', 700, 250, 0.05, 0.22), T('sine', 2400, 1700, 0.08, 0.14, 0.01)],
    'elf_wind': lambda: [N(0.25, 'bandpass', 700, 2400, 0.9, 0.5), N(0.2, 'highpass', 3000, 5000, 0.7, 0.16)],
    # a step through the air: gone with a rising note, there with a falling one
    'elf_blink': lambda: [T('sine', 900, 2400, 0.09, 0.4), T('sine', 2400, 700, 0.14, 0.3, 0.07), N(0.1, 'highpass', 4000, 6000, 0.8, 0.18)],
    # a rune drawn on the floor: three notes stacked, held
    'elf_rune': lambda: [T('sine', 660, 658, 0.3, 0.3), T('sine', 990, 988, 0.3, 0.2, 0.05), T('sine', 1320, 1316, 0.35, 0.16, 0.1)],
    # the great sphere's beam waking
    'elf_beam': lambda: [T('sawtooth', 110, 220, 0.9, 0.28), T('sine', 440, 880, 0.9, 0.24), N(0.8, 'bandpass', 1200, 2600, 2, 0.18)],
    # a wind chime: an obelisk's warning, a bolt off mirror bark, the amplifying circle
    'elf_chime': lambda: [T('sine', 2093, 2089, 0.5, 0.34), T('sine', 2637, 2632, 0.45, 0.24, 0.06), T('sine', 3136, 3130, 0.4, 0.18, 0.13)],
    # a gravity-spore puffball bursting: a soft thump and the spores hissing up
    'elf_puff': lambda: [N(0.3, 'lowpass', 1700, 250, 0.7, 0.9), T('sine', 150, 60, 0.15, 0.5), N(0.5, 'highpass', 3000, 5200, 0.7, 0.2, 0.05)],
    # a portal taking you: a sweep up and a bell where you arrive
    'elf_portal': lambda: [T('sine', 300, 1200, 0.3, 0.4), T('sine', 450, 1800, 0.3, 0.24), N(0.35, 'bandpass', 800, 3000, 1.5, 0.24), T('sine', 1568, 1560, 0.4, 0.2, 0.25)],
    # the moonwell's water as it mends you: three drops, each a little higher
    'elf_well': lambda: [T('sine', 880, 1500, 0.06, 0.3), T('sine', 1040, 1750, 0.06, 0.26, 0.11), T('sine', 1240, 2100, 0.06, 0.22, 0.2), N(0.3, 'lowpass', 900, 500, 0.8, 0.1)],
    # the alchemist's bomb (stage 6's shared throwable): the flask breaking, what was in it going up with a whoosh
    'elf_flask': lambda: [N(0.05, 'highpass', 5200, 2600, 0.8, 1.0), T('square', 2400, 1500, 0.02, 0.14), N(0.3, 'lowpass', 2600, 260, 0.7, 1.1, 0.02), T('sine', 240, 62, 0.28, 0.85, 0.02),
                  N(0.02, 'highpass', 6000, 4000, 0.8, 0.4, 0.12), N(0.02, 'highpass', 6500, 4200, 0.8, 0.3, 0.2), N(0.35, 'bandpass', 900, 2600, 1.2, 0.2, 0.05)],
    # ---- the race battle (five a side, four races): each race's arms in a register of its own, so the ear can tell them apart ----
    # ---- the elves' arcane repeating crossbow: a taut string, glass over it ----
    # its quick shot: the string's snap and a glassy shimmer
    'rm_xbow': lambda: [N(0.02, 'bandpass', 2600, 1500, 2, 0.6), T('triangle', 1150, 520, 0.06, 0.45), T('sine', 3136, 3120, 0.12, 0.14, 0.005), T('sine', 4186, 4160, 0.1, 0.08, 0.012)],
    # the heavy shot charging: a hum climbing for 0.9 s, trembling faster as it goes
    'rm_xbow_charge': lambda: [H('triangle', 220, 587, 0.9, 0.16, 0.0, 0.6, 0.03), H('triangle', 223, 595, 0.9, 0.12, 0.0, 0.6, 0.03), H('sine', 440, 1175, 0.9, 0.07, 0.0, 0.85, 0.03), BACK(N(0.9, 'bandpass', 3600, 1200, 3, 0.25))],
    # ...charged: three strings of a harp, one after another
    'rm_xbow_full': lambda: pluck(NOTE(76), 0.36) + pluck(NOTE(79), 0.32, 0.035) + pluck(NOTE(84), 0.3, 0.07) + [N(0.012, 'highpass', 5000, 3500, 1, 0.2)],
    # ...let go: a deeper thump of the string, the glass ringing longer
    'rm_xbow_big': lambda: [T('sine', 200, 80, 0.2, 0.85), T('triangle', 760, 250, 0.12, 0.5), N(0.05, 'bandpass', 2000, 800, 1.5, 0.7), T('sine', 2637, 2610, 0.4, 0.2, 0.01), T('sine', 3951, 3915, 0.36, 0.13, 0.02), T('sine', 5274, 5220, 0.3, 0.08, 0.03),
                           N(0.3, 'highpass', 6000, 3500, 0.8, 0.14, 0.01)],
    # an arrow glancing off stone: a glassy ping at C5; its second glance, at G5
    'rm_rico1': lambda: ping(NOTE(72), 0.42),
    'rm_rico2': lambda: ping(NOTE(79), 0.42),
    # its core spun round, drawing mana in: a whirr quickening and rising, a click as it locks
    'rm_xbow_reload': lambda: [T('sine', 520 + 34 * i, 640 + 40 * i, 0.035, 0.16 + 0.005 * i, 0.085 * i - 0.00135 * i * i) for i in range(25)]
        + [N(0.02, 'bandpass', 2400 + 70 * i, 1700 + 50 * i, 3, 0.2 + 0.008 * i, 0.085 * i - 0.00135 * i * i) for i in range(25)]
        + [H('triangle', 165, 494, 1.28, 0.14, 0.0, 1.0, 0.03), H('triangle', 168, 503, 1.28, 0.1, 0.0, 1.0, 0.03), BACK(N(1.28, 'bandpass', 4200, 1000, 2, 0.3)), N(0.03, 'bandpass', 2400, 1500, 2, 0.7, 1.3), T('square', 1100, 700, 0.025, 0.16, 1.3),
           T('sine', 1568, 1560, 0.1, 0.14, 1.3)],
    # ---- the dwarves' rune steam scatter-cannon: brass, a boiler, steam ----
    # its blast: the boiler's boom and the bolt's knock, steam bursting out after
    'rm_cannon': lambda: [T('sine', 230, 52, 0.4, 0.8), T('triangle', 115, 46, 0.3, 0.4), N(0.25, 'lowpass', 2600, 180, 0.7, 1.2), N(0.05, 'bandpass', 1400, 650, 1.5, 0.9), T('square', 330, 120, 0.04, 0.25), N(0.5, 'highpass', 3200, 5600, 0.7, 0.4, 0.03)],
    # steam let out at the valve
    'rm_vent': lambda: [N(0.06, 'bandpass', 1500, 700, 1.5, 0.45), T('square', 480, 300, 0.03, 0.1), N(1.0, 'bandpass', 3000, 5200, 0.8, 0.42, 0.02), N(1.0, 'highpass', 5000, 7000, 0.7, 0.2, 0.02), N(0.7, 'bandpass', 3400, 5400, 0.8, 0.16, 0.3)],
    # its breech thrown open, and shut on the new charge: two clanks of brass
    'rm_cannon_reload': lambda: clank(640, 0.8) + [T('sine', 190, 110, 0.07, 0.4)] + clank(500, 0.9, 1.35) + [T('sine', 170, 80, 0.1, 0.6, 1.35), N(0.05, 'lowpass', 800, 250, 0.8, 0.6, 1.35)],
    # an alchemical grenade sent off: a hollow thunk from the tube
    'rm_gren': lambda: [T('sine', 220, 82, 0.16, 0.8), N(0.07, 'bandpass', 620, 380, 4, 0.9), N(0.06, 'lowpass', 1400, 300, 0.8, 0.6), T('triangle', 440, 170, 0.07, 0.25)],
    # ...bursting: its glass, a small sharp bang, what was in it fizzing
    'rm_gren_boom': lambda: [N(0.04, 'highpass', 5600, 2800, 0.8, 0.9), T('square', 2600, 1500, 0.02, 0.12), N(0.2, 'lowpass', 2800, 300, 0.7, 1.1, 0.015), T('sine', 230, 70, 0.2, 0.8, 0.015), N(0.02, 'highpass', 6200, 4200, 0.8, 0.35, 0.1),
                            N(0.3, 'bandpass', 1600, 4200, 2, 0.22, 0.04)],
    # ---- the orcs' great sword and chain axe: low wind, iron, a growl ----
    # the great sword swung: a slab of iron through the air
    'rm_swing': lambda: [BACK(N(0.1, 'bandpass', 760, 300, 1.0, 1.1)), N(0.16, 'bandpass', 760, 230, 1.0, 1.1, 0.1), H('sine', 190, 115, 0.26, 0.22, 0.0, 0.1, 0.15)],
    # the third, heavier swing: a growl as the red wave tears off the blade
    'rm_swing_big': lambda: [BACK(N(0.13, 'bandpass', 700, 240, 1.0, 1.2)), N(0.24, 'bandpass', 700, 180, 1.0, 1.2, 0.13), T('sawtooth', 110, 68, 0.3, 0.45, 0.1), T('sawtooth', 141, 87, 0.3, 0.4, 0.1), N(0.22, 'bandpass', 2200, 600, 1.5, 0.5, 0.13),
                            T('sine', 170, 62, 0.2, 0.5, 0.13)],
    # the sword biting: a meaty thud, an edge of metal
    'rm_blade_hit': lambda: [N(0.09, 'lowpass', 1100, 180, 0.8, 1.1), T('sine', 200, 68, 0.12, 0.7), N(0.035, 'bandpass', 3000, 1600, 2, 0.8), T('square', 1250, 900, 0.04, 0.16), T('sine', 2350, 2310, 0.1, 0.14, 0.004), T('sine', 3540, 3480, 0.06, 0.07, 0.004)],
    # the chain axe thrown: turning over and over, its chain paying out
    'rm_axe': lambda: [N(0.08, 'bandpass', 420 + 60 * i, 1100, 0.8, 1.5 - 0.18 * i, 0.085 * i) for i in range(5)] + [N(0.012, 'bandpass', 3000 + 400 * (i % 3), 2200, 3, 0.7, 0.02 + 0.033 * i) for i in range(11)]
        + [T('square', 1500 + 230 * (i % 3), 1200, 0.01, 0.12, 0.02 + 0.033 * i) for i in range(11)],
    # ...lodging: a thunk, the chain clanking taut
    'rm_axe_hit': lambda: [T('sine', 200, 68, 0.12, 0.9), N(0.07, 'lowpass', 1200, 200, 0.8, 1.0), N(0.03, 'bandpass', 2400, 1300, 2, 0.6)] + clank(900, 0.45, 0.06) + clank(1150, 0.3, 0.13),
    # ...reeling its owner in: the chain's rattle, faster and higher
    'rm_chain': lambda: [N(0.014, 'bandpass', 2000 + 90 * i, 1500 + 70 * i, 3, 0.8 + 0.02 * i, 0.036 * i - 0.0006 * i * i) for i in range(22)]
        + [T('square', 800 + 46 * i, 640 + 36 * i, 0.012, 0.14, 0.036 * i - 0.0006 * i * i) for i in range(22)] + [BACK(N(0.5, 'bandpass', 1800, 600, 1.5, 0.45))],
    # ---- the demons' hellfire staff: dry wood burning, a dark low ----
    # one ember spat out (the game raises its pitch with the heat)
    'rm_ember': lambda: ember(),
    # ...at critical heat: the same, lava boiling low under it
    'rm_ember_hot': lambda: ember() + [T('sine', 180, 88, 0.07, 0.4), N(0.07, 'lowpass', 520, 200, 0.8, 0.7)],
    # the staff sealed, overheated: a chain lock's clang, then two seconds of it cooling
    'rm_seal': lambda: clank(330, 1.0) + clank(495, 0.5, 0.012) + [T('sine', 170, 70, 0.15, 0.6), N(2.0, 'highpass', 6800, 3600, 0.7, 0.4, 0.1), N(1.5, 'bandpass', 3600, 1600, 1, 0.2, 0.1), N(1.2, 'highpass', 5200, 3400, 0.7, 0.1, 0.8)],
    # the soul-draining beam: a dark drone and the pull of it (one after another while the beam is held)
    'rm_drain': lambda: [H('triangle', 146.8, 138.6, 0.5, 0.2, 0.0, 0.04, 0.04), H('sawtooth', 73.4, 69.3, 0.5, 0.2, 0.0, 0.04, 0.04), H('sawtooth', 77.8, 73.4, 0.5, 0.14, 0.0, 0.04, 0.04), BACK(T('sine', 330, 124, 0.5, 0.2)),
                        BACK(N(0.5, 'bandpass', 1500, 320, 2.5, 0.5))],
    # ---- everyone's rune dagger and alchemical flasks ----
    # the dagger: a quick thin slash, a sparkle off the rune
    'rm_dagger': lambda: [N(0.07, 'bandpass', 3000, 5400, 1.5, 0.7), N(0.04, 'highpass', 6000, 4500, 0.8, 0.2, 0.015), T('sine', 4186, 3900, 0.07, 0.1, 0.025), T('sine', 5588, 5300, 0.05, 0.06, 0.04)],
    # ...its finishing blow: a short suck inward, a sharp crack
    'rm_execute': lambda: [BACK(N(0.14, 'bandpass', 2600, 500, 2, 0.8)), BACK(T('sine', 640, 170, 0.14, 0.3)), N(0.035, 'highpass', 4500, 2200, 0.7, 1.1, 0.15), N(0.07, 'bandpass', 1900, 700, 1.2, 0.9, 0.15), T('square', 1500, 480, 0.03, 0.2, 0.15),
                          T('sine', 230, 70, 0.12, 0.8, 0.15)],
    # a missile parried: rune steel ringing clear, then the air drawn back in
    'rm_parry': lambda: [N(0.015, 'highpass', 5000, 3000, 1, 0.7), T('sine', 1760, 1752, 0.45, 0.4), T('sine', 2637, 2628, 0.35, 0.2), T('sine', 4858, 4840, 0.18, 0.1), T('square', 880, 870, 0.04, 0.12), BACK(N(0.38, 'bandpass', 2600, 500, 1.2, 0.6, 0.22)),
                        BACK(N(0.38, 'highpass', 5000, 3000, 0.7, 0.15, 0.22))],
    # the parry stance taken: a small rising 'shing'
    'rm_parry_up': lambda: [T('sine', 2200, 4300, 0.13, 0.2), T('triangle', 1100, 2150, 0.09, 0.14), N(0.11, 'highpass', 5000, 7500, 1, 0.25)],
    # a flask thrown
    'rm_throw': lambda: [BACK(N(0.06, 'bandpass', 1400, 700, 1.2, 0.55)), N(0.14, 'bandpass', 1400, 520, 1.2, 0.55, 0.06)],
    # an oil flask landing: the glass, then the oil spreading
    'rm_oil': lambda: [N(0.05, 'highpass', 5500, 3000, 0.8, 0.9), T('sine', 3300, 3180, 0.06, 0.14), T('sine', 4500, 4350, 0.05, 0.1, 0.02), N(0.02, 'highpass', 6500, 4500, 0.8, 0.35, 0.07), N(0.3, 'lowpass', 1400, 260, 0.8, 0.9, 0.08),
                      N(0.2, 'bandpass', 900, 420, 1.5, 0.5, 0.1), T('sine', 260, 150, 0.07, 0.35, 0.13), T('sine', 205, 120, 0.08, 0.3, 0.21)],
    # the oil catching: the air snatched in, a roar of flame going up
    'rm_ignite': lambda: [BACK(N(0.12, 'bandpass', 520, 200, 1, 1.0)), T('sine', 200, 66, 0.3, 0.6, 0.12), N(0.48, 'lowpass', 1100, 240, 0.7, 1.0, 0.12), N(0.48, 'bandpass', 520, 1700, 0.8, 0.8, 0.12), N(0.02, 'highpass', 5000, 3400, 1, 0.3, 0.3),
                         N(0.02, 'highpass', 4600, 3000, 1, 0.25, 0.43)],
    # a burning patch: its flutter and a few crackles (now and then)
    'rm_fire': lambda: [N(0.3, 'lowpass', 720, 300, 0.7, 0.55), N(0.25, 'bandpass', 1500, 900, 1, 0.2), N(0.012, 'highpass', 4200, 2600, 1, 0.5, 0.02), N(0.01, 'highpass', 5000, 3200, 1, 0.35, 0.09), N(0.012, 'highpass', 3800, 2400, 1, 0.45, 0.16),
                       N(0.01, 'highpass', 4600, 3000, 1, 0.3, 0.24)],
    # a gravity-collapse sphere: a drone pulling inward for 1.5 s, falling and trembling, a soft thump as it shuts
    'rm_gravity': lambda: [H('triangle', 330, 110, 1.5, 0.22, 0.0, 0.3, 0.05), H('triangle', 343, 114.5, 1.5, 0.22, 0.0, 0.3, 0.05), H('sawtooth', 165, 55, 1.5, 0.1, 0.0, 0.3, 0.05), BACK(N(1.5, 'bandpass', 400, 2400, 1.5, 0.5)),
                          T('sine', 150, 50, 0.2, 0.7, 1.5), N(0.1, 'lowpass', 700, 150, 0.7, 0.8, 1.5)],
    # a smoke bomb: a pop, the smoke hissing out
    'rm_smoke': lambda: [T('sine', 380, 110, 0.07, 0.7), N(0.05, 'lowpass', 2200, 500, 0.8, 0.8), N(1.0, 'bandpass', 2600, 1300, 0.7, 0.35, 0.03), N(0.8, 'highpass', 4500, 3000, 0.7, 0.12, 0.05)],
    # frost fog forming: ice crackling, a cold breath
    'rm_frost': lambda: [N(0.008, 'highpass', 7200 - 300 * (i % 4), 5000, 1.5, 0.55 - 0.04 * i, 0.012 + 0.047 * i + 0.011 * (i * 5 % 3)) for i in range(9)]
        + [T('sine', 5200 - 420 * (i * 2 % 5), 5000 - 420 * (i * 2 % 5), 0.03, 0.07, 0.012 + 0.047 * i + 0.011 * (i * 5 % 3)) for i in range(9)] + [N(0.6, 'highpass', 6000, 8200, 0.7, 0.28), N(0.5, 'bandpass', 3200, 5000, 2, 0.14)],
    # ---- the four races' moves ----
    # an elf's wind step: air rushing up, a tiny chime
    'rm_windstep': lambda: [BACK(N(0.07, 'bandpass', 2000, 900, 1, 0.5)), N(0.26, 'bandpass', 2000, 4600, 1.0, 0.5, 0.07), N(0.2, 'highpass', 4200, 6500, 0.7, 0.14, 0.05), T('sine', 2637, 2630, 0.2, 0.12, 0.1), T('sine', 3520, 3510, 0.15, 0.08, 0.14)],
    # a dwarf's steam dash: a sharp jet, a kick low down
    'rm_steamdash': lambda: [N(0.3, 'highpass', 3600, 6200, 0.8, 0.6), N(0.2, 'bandpass', 2200, 3800, 1, 0.45), T('sine', 200, 66, 0.14, 0.7), N(0.06, 'lowpass', 750, 220, 0.8, 0.7)],
    # an orc's bound: a low growl, the air going by
    'rm_leap': lambda: [T('sawtooth', 110, 72, 0.26, 0.55), T('sawtooth', 141, 92, 0.26, 0.45), N(0.2, 'bandpass', 620, 320, 2, 0.7), BACK(N(0.09, 'bandpass', 900, 420, 1, 0.8)), N(0.24, 'bandpass', 900, 1500, 1, 0.7, 0.09)],
    # a heavy landing: the ground's thud, grit falling
    'rm_land': lambda: [T('sine', 180, 52, 0.2, 0.75), N(0.14, 'lowpass', 900, 150, 0.7, 1.0), N(0.05, 'bandpass', 600, 300, 1.2, 0.6), N(0.2, 'bandpass', 900, 480, 0.8, 0.3, 0.04), N(0.02, 'bandpass', 1800, 1100, 2, 0.4, 0.1),
                       N(0.018, 'bandpass', 2400, 1500, 2, 0.3, 0.17), N(0.015, 'bandpass', 1500, 900, 2, 0.25, 0.25)],
    # a demon's shadow step: a dark blip down and up again, the air sucked in after it
    'rm_rift': lambda: [T('sine', 520, 105, 0.1, 0.5), T('sawtooth', 260, 54, 0.1, 0.25), H('sine', 105, 470, 0.12, 0.25, 0.1, 0.04, 0.02), BACK(N(0.22, 'bandpass', 3000, 600, 1.5, 0.5)), N(0.05, 'lowpass', 800, 220, 0.8, 0.5, 0.22)],
    # ---- the secret arts ----
    # an art is ready: three bright notes going up
    'rm_ult_ready': lambda: ping(NOTE(79), 0.3) + ping(NOTE(86), 0.3, 0.1) + ping(NOTE(91), 0.34, 0.2, 2.0),
    # the elf's: a warning chime for 0.8 s, then a harp run up into the stars
    'rm_ult_elf': lambda: ping(NOTE(88), 0.3, 0.0, 2.0) + ping(NOTE(93), 0.26, 0.02, 2.0) + ping(NOTE(88), 0.22, 0.4, 1.4) + ping(NOTE(93), 0.19, 0.42, 1.4)
        + [l for i, m in enumerate(GLISS) for l in pluck(NOTE(m), 0.2 + 0.01 * i, 0.8 + 0.042 * i, 0.3)] + [T('sine', NOTE(98), NOTE(98) * 0.997, 0.5, 0.14, 1.26), T('sine', NOTE(105), NOTE(105) * 0.997, 0.45, 0.09, 1.28)],
    # one star arrow striking: a small glassy knock
    'rm_meteor': lambda: [N(0.025, 'highpass', 5000, 3000, 1, 0.45), T('sine', 2093, 1900, 0.09, 0.24), T('sine', 3136, 2900, 0.06, 0.1), T('sine', 250, 110, 0.05, 0.3), N(0.03, 'lowpass', 900, 300, 0.8, 0.3)],
    # the dwarf's: the anvil struck twice, steam, the engine's hum coming up
    'rm_ult_dwarf': lambda: [l for g, d in ((0.9, 0.0), (0.7, 0.3)) for l in (N(0.03, 'bandpass', 3200, 1600, 1.5, g, d), T('sine', 1180, 1174, 0.5, g * 0.5, d), T('sine', 2930, 2915, 0.35, g * 0.25, d), T('sine', 4120, 4100, 0.2, g * 0.12, d), T('sine', 190, 90, 0.07, g * 0.7, d))]
        + [N(0.7, 'highpass', 3600, 6000, 0.7, 0.4, 0.33), H('sawtooth', 55, 196, 0.95, 0.3, 0.33, 0.6, 0.25), H('sawtooth', 56, 199, 0.95, 0.2, 0.33, 0.6, 0.25), H('sine', 110, 392, 0.95, 0.3, 0.33, 0.6, 0.25)],
    # a rune turret's bolt: a tight zap and a thud
    'rm_turret': lambda: [T('sawtooth', 900, 170, 0.07, 0.5), T('square', 1800, 420, 0.045, 0.18), N(0.035, 'bandpass', 2600, 1200, 1.5, 0.6), T('sine', 200, 66, 0.1, 0.6), N(0.05, 'lowpass', 800, 220, 0.8, 0.6)],
    # the orc's: a war roar, 0.6 s of it
    'rm_ult_orc': lambda: [H('sawtooth', 105, 165, 0.16, 0.6, 0.0, 0.05, 0.05), H('sawtooth', 165, 88, 0.5, 0.6, 0.11, 0.05, 0.3), H('sawtooth', 125, 196, 0.16, 0.5, 0.0, 0.05, 0.05), H('sawtooth', 196, 105, 0.5, 0.5, 0.11, 0.05, 0.3),
                          H('square', 52.5, 82.5, 0.16, 0.3, 0.0, 0.05, 0.05), H('square', 82.5, 44, 0.5, 0.3, 0.11, 0.05, 0.3), BACK(N(0.14, 'bandpass', 950, 700, 2, 1.2)), N(0.47, 'bandpass', 950, 520, 2, 1.2, 0.14), N(0.5, 'bandpass', 2500, 1300, 2, 0.5, 0.05),
                          N(0.6, 'lowpass', 500, 180, 0.7, 0.7)],
    # the demon's: a furnace lit, fire roaring up over a low rumble and an organ's discord
    'rm_ult_demon': lambda: [BACK(N(0.25, 'bandpass', 900, 260, 1, 1.0)), N(0.95, 'bandpass', 900, 420, 0.7, 1.0, 0.25), N(0.95, 'lowpass', 700, 180, 0.7, 1.1, 0.25), T('sawtooth', 82, 55, 1.2, 0.5), T('sawtooth', 87, 58, 1.2, 0.4), T('sine', 110, 62, 1.2, 0.5),
                            H('square', 146.8, 146.8, 0.95, 0.1, 0.25, 0.08, 0.6), H('square', 155.6, 155.6, 0.95, 0.09, 0.25, 0.08, 0.6), H('square', 207.7, 207.7, 0.95, 0.07, 0.25, 0.08, 0.6), N(0.02, 'highpass', 5000, 3200, 1, 0.3, 0.45),
                            N(0.02, 'highpass', 4400, 2800, 1, 0.25, 0.62), N(0.015, 'highpass', 5200, 3400, 1, 0.2, 0.85)],
    # ---- the circles on the ground, the objectives ----
    # a portal's clear bell, struck once
    'rm_bell': lambda: [T('sine', NOTE(84) * r, NOTE(84) * r * 0.998, d, g) for r, g, d in PORTAL] + [N(0.012, 'highpass', 6000, 4000, 1, 0.3)],
    # ...heard at its far end before anyone comes through: the same bell, swelling in over 0.4 s
    'rm_bell_pre': lambda: [BACK(T('sine', NOTE(84) * r * 0.998, NOTE(84) * r, 0.4, g * 0.5)) for r, g, d in PORTAL],
    # a shot through an amplifier circle: static crackling, the shot's note thrown an octave up
    'rm_amp': lambda: [N(0.01, 'highpass', 6500 - 500 * (i % 3), 3500, 1, 0.8 - 0.1 * i, 0.011 * i + 0.003 * (i % 2)) for i in range(6)] + [T('sine', 1250, 2500, 0.09, 0.32, 0.015), T('triangle', 2500, 5000, 0.07, 0.1, 0.03)],
    # a summoning trap closing on someone: a low hum swelling for a second, and the snap
    'rm_trap': lambda: [H('sawtooth', 98, 110, 1.0, 0.17, 0.0, 0.95, 0.03), H('sine', 196, 220, 1.0, 0.24, 0.0, 0.95, 0.03), H('sine', 202, 227, 1.0, 0.18, 0.0, 0.95, 0.03), BACK(N(1.0, 'bandpass', 1800, 500, 2, 0.3)), N(0.03, 'highpass', 4200, 2000, 0.8, 1.0, 1.0),
                       N(0.06, 'bandpass', 1500, 800, 1.5, 0.7, 1.0), T('square', 900, 250, 0.04, 0.25, 1.0), T('sine', 230, 72, 0.1, 0.7, 1.0)],
    # a shockwave of mana from the sanctum: a deep boom, a shimmer climbing out of it
    'rm_resonance': lambda: [T('sine', 230, 40, 0.9, 0.7), T('triangle', 115, 40, 0.7, 0.35), N(0.5, 'lowpass', 1800, 120, 0.7, 1.0), T('sine', 1046.5, 2093, 0.9, 0.2, 0.05), T('sine', 1568, 3136, 0.9, 0.14, 0.25), T('sine', 2093, 4186, 0.8, 0.12, 0.5),
                            T('sine', 3136, 6272, 0.6, 0.08, 0.8), N(1.3, 'bandpass', 2400, 6000, 3, 0.2, 0.1)],
    # overtime: a war horn's two notes, the second higher and longer
    'rm_overtime': lambda: horn(NOTE(50), 0.3, 0.0, 0.4) + horn(NOTE(53), 0.33, 0.36, 0.9),
    # a round won: a harp running up, a bell on top
    'rm_round_win': lambda: pluck(NOTE(74), 0.34, 0.0, 0.4) + pluck(NOTE(79), 0.34, 0.11, 0.4) + pluck(NOTE(83), 0.34, 0.22, 0.4) + pluck(NOTE(86), 0.38, 0.33, 0.8) + ping(NOTE(91), 0.3, 0.44, 2.5) + ping(NOTE(86), 0.16, 0.44, 2.5),
    # a round lost: four notes falling, the last one low
    'rm_round_lose': lambda: pluck(NOTE(81), 0.34, 0.0, 0.5) + pluck(NOTE(77), 0.32, 0.2, 0.5) + pluck(NOTE(74), 0.32, 0.4, 0.5) + pluck(NOTE(62), 0.4, 0.6, 0.7) + [T('sine', NOTE(50), NOTE(50) * 0.99, 0.7, 0.25, 0.6)],
    # the bell before a round: a soft gong
    'rm_prep': lambda: [T('sine', 196 * r, 195.4 * r, d, g) for r, g, d in ((1.0, 0.26, 1.6), (1.48, 0.16, 1.3), (2.1, 0.11, 1.0), (2.63, 0.07, 0.8), (3.42, 0.04, 0.5))] + [N(0.1, 'lowpass', 500, 180, 0.8, 0.3)],
    # a bomb being set: one click of it
    'rm_plant': lambda: [N(0.02, 'bandpass', 2200, 1400, 2.5, 0.8), T('square', 880, 660, 0.02, 0.18), T('sine', 1320, 1300, 0.05, 0.16, 0.004)],
    # ...its fuse: one tick
    'rm_fuse': lambda: [T('sine', 740, 732, 0.07, 0.34), T('sine', 1480, 1470, 0.05, 0.16), T('sine', 185, 120, 0.05, 0.3), N(0.01, 'highpass', 5000, 3500, 1, 0.3)],
    # ...defused: its works running down, a click
    'rm_defuse': lambda: [T('sawtooth', 700, 120, 0.35, 0.36), T('sine', 1400, 240, 0.35, 0.3), N(0.3, 'bandpass', 2400, 500, 3, 0.36), N(0.03, 'bandpass', 2000, 1200, 2, 0.7, 0.36), T('square', 620, 420, 0.025, 0.16, 0.36)],
    # a ward altar blown apart: a big low boom, its crystal flying
    'rm_ward': lambda: [T('sine', 240, 42, 0.8, 0.75), T('triangle', 120, 40, 0.6, 0.4), N(0.5, 'lowpass', 2200, 130, 0.7, 1.1), N(0.1, 'bandpass', 1300, 450, 1, 0.8)] + shatter(1.0, 0.8, 0.02),
    # a magic shield struck: a bright 'tink' and a short ring
    'rm_shield_hit': lambda: [N(0.008, 'highpass', 6500, 4500, 1, 0.5), T('sine', 2794, 2780, 0.16, 0.35), T('sine', 4186, 4170, 0.1, 0.14), T('sine', 7400, 7350, 0.04, 0.06)],
    # the arcane nucleus destroyed: its crystal bursting, falling in on itself, and the last of it breaking: two seconds
    'rm_nucleus': lambda: [T('sine', 250, 40, 1.0, 0.75), T('triangle', 125, 40, 0.8, 0.4), N(0.7, 'lowpass', 2600, 120, 0.7, 1.1), N(0.12, 'bandpass', 1500, 550, 1, 0.9)] + shatter(1.0, 0.9)
        + [T('sine', 1900, 110, 1.5, 0.3, 0.1), T('sawtooth', 640, 55, 1.5, 0.25, 0.1), N(1.2, 'lowpass', 600, 110, 0.7, 0.9, 0.4)] + shatter(2.2, 0.4, 0.5)
        + [BACK(N(0.55, 'bandpass', 500, 2600, 1.5, 0.7, 1.0)), H('sine', 400, 90, 0.55, 0.3, 1.0, 0.5, 0.03), T('sine', 200, 45, 0.35, 0.8, 1.55), N(0.3, 'lowpass', 1500, 140, 0.7, 0.9, 1.55)] + shatter(0.7, 0.5, 1.56),
    # a rune cut at the altar: the chisel's tap, a warm chime
    'rm_shard': lambda: [N(0.02, 'bandpass', 2600, 1600, 2.5, 0.7), T('square', 1500, 1100, 0.015, 0.12), T('sine', NOTE(74), NOTE(74) * 0.998, 0.5, 0.32, 0.05), T('sine', NOTE(81), NOTE(81) * 0.998, 0.45, 0.18, 0.05),
                        T('sine', NOTE(86), NOTE(86) * 0.998, 0.35, 0.1, 0.07)],
    # someone back at a base circle: a soft shimmer rising
    'rm_spawn': lambda: [T('sine', 440, 880, 0.5, 0.2), T('sine', 660, 1320, 0.5, 0.14, 0.05), T('sine', 880, 1760, 0.45, 0.09, 0.1), N(0.5, 'bandpass', 1500, 4500, 2, 0.14), T('sine', 1760, 1752, 0.3, 0.12, 0.3)],
    # ---- hits and falls ----
    # a hit told: a dry tick
    'rm_hit': lambda: [N(0.014, 'bandpass', 2400, 1600, 2, 1.0), T('square', 1050, 800, 0.014, 0.2), T('sine', 1900, 1500, 0.02, 0.18)],
    # a head shot: a gold diamond shattering
    'rm_head': lambda: [T('sine', 2093, 2080, 0.25, 0.25), T('sine', 3136, 3110, 0.2, 0.2, 0.005)] + shatter(0.35, 0.7),
    # burning: one sizzle
    'rm_burn': lambda: [N(0.09, 'highpass', 5000, 7000, 1, 0.4), N(0.05, 'bandpass', 2600, 3600, 2, 0.25), N(0.008, 'highpass', 6000, 4000, 1, 0.3, 0.03)],
    # an elf fading: silver chimes drifting up
    'rm_die_elf': lambda: [T('sine', NOTE(m), NOTE(m) * 1.012, 0.45, 0.28 - 0.03 * i, 0.09 * i) for i, m in enumerate((88, 91, 95, 98, 100, 103))]
        + [T('sine', NOTE(m) * 2.76, NOTE(m) * 2.78, 0.2, 0.07, 0.09 * i) for i, m in enumerate((88, 91, 95, 98, 100, 103))] + [N(0.8, 'highpass', 4200, 7000, 0.7, 0.12)],
    # a dwarf's armour coming apart: plates clattering down, the last of the steam let go
    'rm_die_dwarf': lambda: [l for f, g, d in PLATES for l in clank(f, g, d)] + [N(0.7, 'highpass', 3800, 6500, 0.7, 0.4, 0.18)],
    # an orc falling: a growl dying away, a heavy thud
    'rm_die_orc': lambda: [T('sawtooth', 132, 62, 0.5, 0.5), T('sawtooth', 160, 76, 0.5, 0.4), N(0.4, 'bandpass', 820, 360, 2, 0.6), T('sine', 170, 50, 0.22, 0.9, 0.45), N(0.15, 'lowpass', 800, 150, 0.7, 1.1, 0.45)],
    # a demon turning to ash: a dry hiss, the ash sucked down
    'rm_die_demon': lambda: [N(0.5, 'highpass', 5200, 3000, 0.8, 0.4), N(0.4, 'bandpass', 3000, 1200, 1.5, 0.3), H('sine', 700, 140, 0.45, 0.35, 0.15, 0.4, 0.03), BACK(N(0.45, 'bandpass', 300, 2400, 2, 0.6, 0.15)), T('sine', 130, 52, 0.1, 0.5, 0.6)],
    # ---- 6-2, the plain of the four banners (added last: the sounds before keep their noise) ----
    # the moon spire summons: a harp's run up and a chime from its crystal
    'rm_summon_elf': lambda: [l for i, m in enumerate(GLISS[:8]) for l in pluck(NOTE(m), 0.22, 0.045 * i, 0.4)] + ping(NOTE(98), 0.3, 0.4, 1.6) + [N(0.6, 'highpass', 4800, 8000, 0.7, 0.1, 0.1)],
    # the rune forge summons: three blows on the anvil, a low horn, the steam let out
    'rm_summon_dwarf': lambda: clank(330, 0.8) + clank(330, 0.7, 0.28) + clank(392, 0.9, 0.56) + horn(98, 0.35, 0.62, 0.7) + [N(0.6, 'highpass', 3200, 5600, 0.7, 0.35, 0.7)],
    # the war totem summons: the war horn and two drum beats
    'rm_summon_orc': lambda: horn(87, 0.55, 0.0, 1.0) + [T('sine', 120, 48, 0.25, 0.9, 1.0), N(0.18, 'lowpass', 900, 120, 0.7, 0.8, 1.0), T('sine', 120, 48, 0.25, 0.9, 1.3), N(0.18, 'lowpass', 900, 120, 0.7, 0.8, 1.3)],
    # the rift gate summons: a roar drawn in, a low growl, the crackle of fire
    'rm_summon_demon': lambda: [BACK(N(0.7, 'bandpass', 220, 1800, 1.4, 0.8)), T('sawtooth', 70, 52, 0.9, 0.4, 0.55), T('sawtooth', 104, 78, 0.9, 0.28, 0.55), N(0.5, 'bandpass', 1500, 600, 1.2, 0.4, 0.7)] + [l for k in range(4) for l in [N(0.03, 'highpass', 4000, 2500, 1, 0.3, 0.75 + k * 0.09)]],
    # a landmark struck: a heavy knock on stone or timber, grit falling
    'rm_hall_hit': lambda: [N(0.12, 'lowpass', 1400, 200, 0.8, 0.9), T('sine', 140, 60, 0.12, 0.7), N(0.25, 'highpass', 2600, 4200, 0.7, 0.12, 0.05)],
    # a landmark falling: a long rumble, its walls coming down blow after blow, the last of it settling
    'rm_hall_fall': lambda: [N(2.6, 'lowpass', 500, 60, 0.7, 1.0), T('sine', 62, 36, 2.4, 0.8)] + [l for i, (f, g, d) in enumerate(PLATES) for l in [N(0.2, 'lowpass', f * 1.6, 180, 0.8, g * 0.9, 0.15 + d * 3.0), T('sine', f * 0.25, f * 0.12, 0.2, g * 0.6, 0.15 + d * 3.0)]]
        + shatter(1.8, 0.25, 0.4) + [N(1.4, 'highpass', 2400, 5000, 0.7, 0.14, 1.4)],
    # your landmark under attack: a warning horn, twice
    'rm_hall_alarm': lambda: horn(196, 0.32, 0.0, 0.32) + horn(196, 0.32, 0.42, 0.32) + horn(147, 0.38, 0.84, 0.55),
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
print(made, 'sounds, stored at', SCALE, 'of full level')
