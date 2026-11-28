#!/usr/bin/env python3
"""종족 전투(다섯 대 다섯)와 6-2(네 깃발 평원)의 적응형 배경 음악(godot/music/rf_1..4.ogg, rt_1..4.ogg, rp_1..4.ogg)을 만듭니다. 필요한 것: python3, numpy, ffmpeg(libvorbis).

세 벌, 벌마다 네 층(스템): 모두 90 BPM 4/4 16마디(42.67초)로 길이가 같아, 한 벌의 네 층을 한 번에 같이 돌리고 게임이 층의 크기만 바꿉니다.
층은 쌓아서 듣습니다(1, 1+2, 1+2+3, 넷 모두).
  rf  엘프의 숲 "은빛 경계림의 노래", D 도리아: 켈틱 하프, 글래스 하모니카, 나무 플루트, 프레임 드럼과 셰이커
  rt  대마법사의 탑 "마법사의 시계", D 단조에 프리지아의 빛깔(E♭): 파이프 오르간, 콘트라베이스, 태엽 타악기(째깍 소리, 톱니, 작은 종)
  rp  네 깃발 평원 "네 깃발의 행진", A 단조(딸림화음은 장조 E): 콘트라베이스, 멀리서 부는 호른, 행진 피리와 작은북, 전쟁 북
      (나중에 넣은 벌이라 앞의 두 벌을 다 만든 뒤에 만듭니다: 앞의 두 벌은 그대로입니다)
  1  탐색          잔잔한 바탕: 하프 아르페지오와 글래스 하모니카 / 오르간 플루트와 느린 베이스 드론 (혼자서도 들을 만하게)
  2  소규모 교전    선율(플루트 / 오르간 리드)과 가벼운 타악기 (숲에는 짧게 뜯는 현의 오스티나토도)
  3  거점 난전      16분음표로 몰아가는 타악기(셋·셋·둘로 치는 강세: 90 위에 120쯤의 박이 얹혀 빨라진 듯 들립니다), 베이스 오스티나토, 대선율
  4  클라이맥스    금관과 합창('아')의 긴 화음, 큰 북 (추가 시간): 금관은 선율의 긴 음도 한 옥타브 아래에서 냅니다
악기 소리는 make_music.py의 방식대로 numpy로 만들고, 그 도구(음높이, sines, band, burst, Loop, wet, write)와 악기 몇(피치카토, 시계의 째깍 소리와 톱니, 작은 종)을 빌려 씁니다.
make_music.py는 건드리지 않습니다.
층과 고리(loop)는 모두 끝이 처음으로 이어집니다: 음의 꼬리와 울림이 다시 처음에 더해집니다.
난수는 이 스크립트 자신의 것(씨앗 고정)이라 장난감 방의 음악은 그대로이고, 몇 번을 돌려도 같은 소리가 나옵니다.
한 벌의 네 층은 같은 배율로 줄입니다: 넷을 다 합친 가장 큰 순간이 0.89에 닿게.
  python3 tools/make_realm_music.py
"""
import sys
import numpy as np
sys.dont_write_bytecode = True    # (no __pycache__ left beside the tools)
import make_music as mm

SR = mm.SR
BPM = 90.0; SPB = 60.0 / BPM; BARS = 16
SEC = BARS * 4 * SPB              # 42.67 s
LOOP = int(round(SEC * SR))       # every stem is this long, to the sample
RNG = np.random.default_rng(6102)
mm.RNG = RNG                      # the tools borrowed from make_music draw from this generator too (its own music, made in its own run, keeps its own)
midi, hz, t_of, band, burst, add, sines = mm.midi, mm.hz, mm.t_of, mm.band, mm.burst, mm.add, mm.sines

# ---------------- the forest: "the Silverwood air", D dorian ----------------
# 16 bars of 4/4, four phrases of four; (note, beats), 'r' a rest
F_TUNE = [
    [('D5', 1.5), ('E5', .5), ('F5', 1), ('A5', 1)],
    [('G5', 1.5), ('A5', .5), ('B5', 1), ('G5', 1)],
    [('A5', 1), ('F5', .5), ('E5', .5), ('D5', 1), ('F5', 1)],
    [('E5', 1.5), ('D5', .5), ('C5', 1.5), ('r', .5)],
    [('D5', 1.5), ('E5', .5), ('F5', 1), ('A5', 1)],
    [('B5', 1.5), ('A5', .5), ('G5', 1), ('B5', 1)],
    [('C6', 1), ('A5', .5), ('G5', .5), ('F5', 1), ('E5', 1)],
    [('E5', .5), ('D5', .5), ('C5', 1), ('D5', 2)],
    [('F5', 1), ('A5', 1), ('C6', 1.5), ('A5', .5)],
    [('C6', 1), ('G5', 1), ('E5', 1.5), ('G5', .5)],
    [('B5', 1), ('G5', .5), ('A5', .5), ('B5', 1), ('D6', 1)],
    [('A5', 2), ('F5', .5), ('E5', .5), ('D5', 1)],
    [('F5', 1), ('A5', 1), ('C6', 1), ('D6', 1)],
    [('E6', 1.5), ('D6', .5), ('C6', 1), ('G5', 1)],
    [('A5', 1), ('C6', .5), ('B5', .5), ('A5', 1), ('E5', 1)],
    [('G5', 1), ('E5', .5), ('D5', .5), ('C5', 1), ('E5', 1)],
]
# the line under it: mostly a sixth below, going its own way where the tune holds or rests
F_UNDER = [
    [('A4', 1.5), ('G4', .5), ('A4', 1), ('F4', 1)],
    [('B4', 1.5), ('C5', .5), ('D5', 1), ('B4', 1)],
    [('A4', 2), ('F4', 1), ('A4', 1)],
    [('G4', 1.5), ('F4', .5), ('E4', 1), ('G4', .5), ('C5', .5)],
    [('A4', 1.5), ('G4', .5), ('A4', 1), ('F4', 1)],
    [('D5', 1.5), ('C5', .5), ('B4', 1), ('D5', 1)],
    [('A4', 1), ('C5', 1), ('A4', 1), ('G4', 1)],
    [('G4', 1), ('E4', 1), ('F4', .5), ('G4', .5), ('A4', 1)],
    [('A4', 1), ('C5', 1), ('A4', 1.5), ('F4', .5)],
    [('G4', 1), ('C5', 1), ('G4', 1.5), ('E4', .5)],
    [('D5', 1), ('B4', 1), ('D5', 1), ('B4', 1)],
    [('F4', .5), ('A4', .5), ('D5', 1), ('A4', 1), ('F4', 1)],
    [('A4', 1), ('C5', 1), ('A4', 1), ('F4', 1)],
    [('G4', 1.5), ('F4', .5), ('E4', 1), ('C5', 1)],
    [('C5', 1), ('E5', 1), ('C5', 1), ('A4', 1)],
    [('E4', 1), ('G4', 1), ('E4', 1), ('G4', 1)],
]
# the tune's long notes, two a bar: the glass harmonica's far-off echo of it (the first of each), the horns' broad way with it
F_LONG = ['D5 F5', 'G5 B5', 'A5 D5', 'E5 C5', 'D5 F5', 'B5 G5', 'C6 F5', 'E5 D5', 'F5 C6', 'C6 E5', 'B5 B5', 'A5 F5', 'F5 C6', 'E6 C6', 'A5 A5', 'G5 C5']
F_BARS = ['Dm', 'G', 'Dm', 'C', 'Dm', 'G', 'F', ('C', 'Dm'), 'F', 'C', 'G', 'Dm', 'F', 'C', 'Am', 'C']   # the major IV (G) is the mode's light
F_HARP = {'Dm': ['D3', 'A3', 'D4', 'F4', 'A4', 'D5'], 'G': ['G3', 'D4', 'G4', 'B4', 'D5', 'G5'], 'C': ['C3', 'G3', 'C4', 'E4', 'G4', 'C5'], 'F': ['F3', 'C4', 'F4', 'A4', 'C5', 'F5'],
          'Am': ['A3', 'E4', 'A4', 'C5', 'E5', 'A5']}
F_PAD = {'Dm': ['F4', 'A4', 'D5'], 'G': ['G4', 'B4', 'D5'], 'C': ['E4', 'G4', 'C5'], 'F': ['F4', 'A4', 'C5'], 'Am': ['E4', 'A4', 'C5']}
F_PLUCK = {'Dm': ['D4', 'A4', 'F4'], 'G': ['G3', 'D4', 'B3'], 'C': ['C4', 'G4', 'E4'], 'F': ['F3', 'C4', 'A3'], 'Am': ['A3', 'E4', 'C4']}
F_BASS = {'Dm': ['D2', 'A2'], 'G': ['G2', 'D3'], 'C': ['C3', 'G2'], 'F': ['F2', 'C3'], 'Am': ['A2', 'E3']}
F_HORNS = {'Dm': ['D3', 'A3', 'D4', 'F4'], 'G': ['G3', 'B3', 'D4', 'G4'], 'C': ['C3', 'G3', 'C4', 'E4'], 'F': ['F3', 'A3', 'C4', 'F4'], 'Am': ['A2', 'A3', 'C4', 'E4']}
F_CHOIR = {'Dm': ['D3', 'A3', 'F4', 'A4'], 'G': ['G3', 'B3', 'G4', 'B4'], 'C': ['C3', 'G3', 'E4', 'G4'], 'F': ['F3', 'C4', 'F4', 'A4'], 'Am': ['A2', 'C4', 'E4', 'A4']}   # bass, tenor, alto, soprano
DORIAN = (2, 4, 5, 7, 9, 11, 0)
# the harp's broken chord, a bar: (beat, which string of the chord, how hard); odd bars and even
HARP = [[(0, 0, .9), (.5, 1, .6), (1, 2, .66), (1.5, 3, .7), (2, 4, .8), (3, 3, .62)], [(0, 0, .85), (.5, 2, .6), (1, 3, .66), (1.5, 4, .72), (2, 5, .8), (3, 4, .62)]]

# ---------------- the tower: "the mage's clock", D minor with the phrygian's E flat ----------------
T_TUNE = [
    [('D5', 1.5), ('A4', .5), ('D5', .5), ('E5', .5), ('F5', 1)],
    [('G5', 1.5), ('F5', .5), ('D5', 1), ('Bb4', 1)],
    [('Eb5', 1.5), ('G5', .5), ('Bb5', 1), ('G5', 1)],
    [('A5', 1), ('F5', .5), ('Eb5', .5), ('D5', 2)],
    [('D5', 1.5), ('A4', .5), ('D5', .5), ('E5', .5), ('F5', .5), ('A5', .5)],
    [('G5', 1.5), ('A5', .5), ('Bb5', 1), ('D6', 1)],
    [('Eb6', 1), ('D6', .5), ('Bb5', .5), ('G5', 1), ('Eb5', 1)],
    [('E5', 1.5), ('F5', .5), ('E5', 1), ('C#5', 1)],
    [('D5', 1), ('F5', 1), ('Bb5', 1.5), ('A5', .5)],
    [('A5', 1), ('F5', .5), ('G5', .5), ('A5', 1), ('C6', 1)],
    [('Bb5', 1.5), ('A5', .5), ('G5', 1), ('D5', 1)],
    [('F5', 1), ('Eb5', .5), ('D5', .5), ('A4', 2)],
    [('D5', 1), ('F5', 1), ('Bb5', 1.5), ('C6', .5)],
    [('Eb6', 1.5), ('D6', .5), ('C6', 1), ('G5', 1)],
    [('Bb5', 1), ('G5', .5), ('Eb5', .5), ('G5', 1), ('Eb5', 1)],
    [('E5', 1.5), ('D5', .5), ('C#5', 2)],
]
# the tenor running under it in eighths, against the tune's motion where it can
T_TENOR = ['D4 C4 Bb3 A3 F3 A3 D4 A3', 'G3 A3 Bb3 C4 D4 Bb3 G3 Bb3', 'Eb4 Bb3 C4 Bb3 G3 Bb3 Eb4 Bb3', 'D3 F3 A3 G3 F3 A3 D4 A3',
           'D4 C4 Bb3 A3 F3 A3 D4 A3', 'D4 C4 Bb3 A3 G3 Bb3 D4 Bb3', 'Eb3 G3 Bb3 Eb4 G4 Eb4 Bb3 G3', 'A3 C#4 E4 C#4 A3 G3 F3 E3',
           'Bb3 A3 G3 F3 D3 F3 Bb3 D4', 'F3 A3 C4 F4 C4 A3 F3 A3', 'G3 Bb3 D4 Bb3 G3 A3 Bb3 G3', 'D4 A3 F3 A3 D3 F3 A3 D4',
           'Bb3 D4 F4 D4 Bb3 D4 Bb3 F3', 'C4 Bb3 G3 Bb3 Eb3 G3 C4 Eb4', 'Eb4 Bb3 G3 Bb3 Eb3 G3 Bb3 Eb4', 'A3 C#4 E4 A3 C#4 E4 G4 E4']
T_LONG = ['D5 F5', 'G5 D5', 'Eb5 Bb5', 'A5 D5', 'D5 F5', 'G5 Bb5', 'Eb6 G5', 'E5 C#5', 'D5 Bb5', 'A5 A5', 'Bb5 G5', 'F5 A4', 'D5 Bb5', 'Eb6 C6', 'Bb5 G5', 'E5 C#5']
T_BARS = ['Dm', 'Gm', 'Eb', 'Dm', 'Dm', 'Gm', 'Eb', 'A', 'Bb', 'F', 'Gm', 'Dm', 'Bb', 'Cm', 'Eb', 'A']   # E flat to A to D minor: the Neapolitan way home
# (the flutes under the tune's octave: its passing E flat and D are not to rub against a held D or C sharp right beside them)
T_PAD = {'Dm': ['D4', 'F4', 'A4'], 'Gm': ['D4', 'G4', 'Bb4'], 'Eb': ['Eb4', 'G4', 'Bb4'], 'A': ['C#4', 'E4', 'A4'], 'Bb': ['D4', 'F4', 'Bb4'], 'F': ['C4', 'F4', 'A4'], 'Cm': ['C4', 'Eb4', 'G4']}
T_CHIME = {'Dm': ['D6', 'A5'], 'Gm': ['D6', 'Bb5'], 'Eb': ['Eb6', 'Bb5'], 'A': ['E6', 'A5'], 'Bb': ['D6', 'Bb5'], 'F': ['C6', 'A5'], 'Cm': ['Eb6', 'G5']}
# the drone, (beat, beats, note): D held under D minor and G minor alike, a step up under E flat (the fight's bass is on that root), then the roots, slowly
T_DRONE = [(0, 8, 'D2'), (8, 4, 'Eb2'), (12, 12, 'D2'), (24, 4, 'Eb2'), (28, 4, 'A2'), (32, 4, 'Bb2'), (36, 4, 'F2'), (40, 4, 'G2'), (44, 4, 'D2'), (48, 4, 'Bb2'), (52, 4, 'C3'),
           (56, 4, 'Eb2'), (60, 4, 'A2')]
T_BASS = {'Dm': ['D2', 'A2', 'D3'], 'Gm': ['G2', 'D3', 'Bb2'], 'Eb': ['Eb2', 'Bb2', 'Eb3'], 'A': ['A2', 'E2', 'C#3'], 'Bb': ['Bb2', 'F2', 'D3'], 'F': ['F2', 'C3', 'A2'], 'Cm': ['C3', 'G2', 'Eb3']}
T_BRASS = {'Dm': ['D3', 'A3', 'D4', 'F4'], 'Gm': ['G3', 'Bb3', 'D4', 'G4'], 'Eb': ['Eb3', 'Bb3', 'Eb4', 'G4'], 'A': ['A2', 'A3', 'C#4', 'E4'], 'Bb': ['Bb2', 'Bb3', 'D4', 'F4'],
           'F': ['F3', 'A3', 'C4', 'F4'], 'Cm': ['C3', 'G3', 'C4', 'Eb4']}
T_CHOIR = {'Dm': ['D3', 'A3', 'F4', 'A4'], 'Gm': ['G3', 'Bb3', 'G4', 'Bb4'], 'Eb': ['Eb3', 'Bb3', 'G4', 'Bb4'], 'A': ['A2', 'C#4', 'E4', 'A4'], 'Bb': ['Bb2', 'D4', 'F4', 'Bb4'],
           'F': ['F3', 'C4', 'F4', 'A4'], 'Cm': ['C3', 'G3', 'Eb4', 'C5']}
T_DRUM = {'Dm': 'D2', 'Gm': 'G2', 'Eb': 'Eb2', 'A': 'A2', 'Bb': 'Bb2', 'F': 'F2', 'Cm': 'G2'}

# ---------------- the plain: "the four banners' march", A minor with the major E for its cadences ----------------
P_TUNE = [
    [('A4', 1.5), ('E5', .5), ('E5', 1), ('D5', .5), ('C5', .5)],
    [('C5', 1.5), ('B4', .5), ('A4', 1), ('E4', 1)],
    [('F4', 1.5), ('A4', .5), ('C5', 1), ('F5', 1)],
    [('E5', 2.5), ('D5', .5), ('B4', 1)],
    [('A4', 1.5), ('E5', .5), ('E5', 1), ('A5', 1)],
    [('G5', 1.5), ('E5', .5), ('C5', 1), ('E5', 1)],
    [('F5', 1.5), ('E5', .5), ('D5', 1), ('F5', 1)],
    [('E5', 1), ('B4', 1), ('A4', 2)],
    [('C5', 1), ('F5', 1), ('A5', 1.5), ('G5', .5)],
    [('G5', 1), ('D5', 1), ('B4', 1.5), ('D5', .5)],
    [('E5', 1), ('G5', 1), ('C6', 1.5), ('B5', .5)],
    [('B5', 2), ('G#5', 1), ('E5', 1)],
    [('A5', 1.5), ('E5', .5), ('C5', 1), ('A5', 1)],
    [('F5', 1.5), ('C5', .5), ('A4', 1), ('C5', 1)],
    [('D5', 1), ('F5', .5), ('E5', .5), ('D5', 1), ('B4', 1)],
    [('A4', 2.5), ('E4', .5), ('A4', 1)],
]
# a second fife under it, in quarters, a third or a sixth below where it can
P_UNDER = [
    [('E4', 1), ('C4', 1), ('E4', 1), ('A4', 1)], [('C4', 1), ('E4', 1), ('A3', 1), ('C4', 1)], [('A3', 1), ('C4', 1), ('F4', 1), ('A4', 1)], [('G#4', 1), ('B4', 1), ('G#4', 1), ('E4', 1)],
    [('C4', 1), ('E4', 1), ('A4', 1), ('E4', 1)], [('E4', 1), ('G4', 1), ('E4', 1), ('C4', 1)], [('D4', 1), ('A4', 1), ('F4', 1), ('D4', 1)], [('G#4', 1), ('E4', 1), ('C4', 1), ('A3', 1)],
    [('A4', 1), ('C5', 1), ('F4', 1), ('A4', 1)], [('B4', 1), ('G4', 1), ('D4', 1), ('G4', 1)], [('C5', 1), ('E4', 1), ('G4', 1), ('E4', 1)], [('E4', 1), ('G#4', 1), ('B4', 1), ('G#4', 1)],
    [('C5', 1), ('A4', 1), ('E4', 1), ('C4', 1)], [('A4', 1), ('F4', 1), ('C4', 1), ('F4', 1)], [('F4', 1), ('A4', 1), ('G#4', 1), ('E4', 1)], [('E4', 1), ('C4', 1), ('A3', 2)],
]
P_LONG = ['A4 E5', 'C5 A4', 'F4 C5', 'E5 E5', 'A4 E5', 'G5 C5', 'F5 D5', 'E5 A4', 'C5 A5', 'G5 B4', 'E5 C6', 'B5 E5', 'A5 C5', 'F5 A4', 'D5 D5', 'A4 A4']
P_BARS = ['Am', 'Am', 'F', 'E', 'Am', 'C', 'Dm', ('E', 'Am'), 'F', 'G', 'C', 'E', 'Am', 'F', ('Dm', 'E'), 'Am']
P_PAD = {'Am': ['E4', 'A4', 'C5'], 'F': ['F4', 'A4', 'C5'], 'E': ['E4', 'G#4', 'B4'], 'C': ['E4', 'G4', 'C5'], 'Dm': ['F4', 'A4', 'D5'], 'G': ['D4', 'G4', 'B4']}
P_PLUCK = {'Am': ['A3', 'E4', 'C4'], 'F': ['F3', 'C4', 'A3'], 'E': ['E3', 'B3', 'G#3'], 'C': ['C4', 'G4', 'E4'], 'Dm': ['D4', 'A4', 'F4'], 'G': ['G3', 'D4', 'B3']}
P_BASS = {'Am': ['A2', 'E2'], 'F': ['F2', 'C3'], 'E': ['E2', 'B2'], 'C': ['C3', 'G2'], 'Dm': ['D2', 'A2'], 'G': ['G2', 'D3']}
P_HORNS = {'Am': ['A2', 'E3', 'A3', 'C4'], 'F': ['F2', 'C3', 'F3', 'A3'], 'E': ['E2', 'B2', 'E3', 'G#3'], 'C': ['C3', 'G3', 'C4', 'E4'], 'Dm': ['D3', 'A3', 'D4', 'F4'], 'G': ['G2', 'D3', 'G3', 'B3']}
P_CHOIR = {'Am': ['A2', 'E3', 'C4', 'A4'], 'F': ['F2', 'C3', 'A3', 'F4'], 'E': ['E2', 'B2', 'G#3', 'E4'], 'C': ['C3', 'G3', 'E4', 'C5'], 'Dm': ['D3', 'A3', 'F4', 'D5'], 'G': ['G2', 'D3', 'B3', 'G4']}
# the far horn call, every other bar: the tune's opening leap (beat, beats, note)
P_CALL = [(0.0, 1.5, 'A3'), (1.5, 0.5, 'E4'), (2.0, 2.0, 'E4')]

DRIVE = (0, 3, 6, 8, 11, 14)   # the fight's accents, in sixteenths of the bar: three and three and two, twice (a pulse of 120 over the 90)

# ---------------- little tools ----------------
def at(beat): return int(round(beat * SPB * SR))

def put(loop, beat, z, jit=0.004):
    """a sound into the loop at a beat, a little off it as hands are"""
    loop.put(z, at(beat) + int(round(RNG.normal(0.0, jit) * SR)))

def halves(bars):
    """the chord of every half bar"""
    return [c for b in bars for c in (b if isinstance(b, tuple) else (b, b))]

def held(half, voicing, k, bars=False):
    """voice k of the chords as notes (beat, beats, midi): a tone that stays is held, not struck again (bars: struck again at every bar line)"""
    ev = []
    for j, c in enumerate(half):
        m = midi(voicing[c][k])
        if ev and ev[-1][2] == m and not (bars and j % 2 == 0): ev[-1] = (ev[-1][0], ev[-1][1] + 2.0, m)
        else: ev.append((j * 2.0, 2.0, m))
    return ev

def arc(b):
    """a phrase's rise and fall: four bars"""
    return 0.9 + 0.1 * np.sin(np.pi * ((b / 16.0) % 1.0))

def roll_at(i):
    """the sixteenth of bar i where the drums' roll into the next bar begins (16: none): the last beat of every fourth bar, the last two of the sixteenth"""
    return 8 if i == BARS - 1 else 12 if i % 4 == 3 else 16

def unit(a): return a / np.sqrt(np.sum(a * a))

def rounded(x, top):
    """a track with its tallest peaks rounded off towards top: the drums' strokes fall together now and then, and everything
    else would have to be turned down for those moments"""
    return x / (1.0 + (np.abs(x) / top) ** 4) ** 0.25

def osc(ph, amps, together=False):
    """harmonics (amps[0] the fundamental) read from one cycle's table at the running phase ph. together: all in step, as a bowed
    string's or a reed's are (else each where it likes)"""
    N = 4096; K = len(amps); spec = np.zeros(N // 2 + 1, complex)
    spec[1:K + 1] = amps * (N / 2) * (-1j if together else np.exp(1j * RNG.uniform(0, 2 * np.pi, K)))
    tab = np.fft.irfft(spec, N); tab = np.append(tab, tab[0])
    x = (ph / (2 * np.pi)) % 1.0 * N; i = np.minimum(x.astype(np.int64), N - 1); fr = x - i
    return tab[i] * (1.0 - fr) + tab[i + 1] * fr

def harmonics(f, tilt, table, floor, top):
    """a note's harmonics at f: a source falling off as 1/h^tilt, through the formants of what it sounds in, none above top"""
    h = np.arange(1, max(1, int(min(top, SR * 0.45) / f)) + 1.0)
    return unit(mm.formant(h * f, table, floor) / h ** tilt)

# ---------------- the instruments ----------------
def v_harp(f, dur, vel):       # a Celtic harp's string: plucked a quarter of the way along and left to ring, the high overtones going first
    tau = float(np.clip(1.5 * (220.0 / f) ** 0.4, 0.5, 2.4)); n = int(min(4.0, 4.5 * tau) * SR); t = t_of(n); y = np.zeros(n)
    for h in range(1, min(24, int(SR * 0.45 / f)) + 1):
        a = abs(np.sin(np.pi * h * 0.23)) / h ** (1.3 - 0.25 * vel)
        y += a * np.sin(2 * np.pi * f * h * np.sqrt(1.0 + 0.00015 * h * h) * t + RNG.uniform(0, 6.28)) * np.exp(-t * (1.0 + 0.22 * (h - 1) ** 1.3) / tau)
    y *= np.minimum(1.0, t / 0.003)
    y = add(y, 0.08 * burst(0.012, 1000, 7000, 0.004))
    return vel * y / np.max(np.abs(y))

def v_glass(f, dur, vel):      # a glass harmonica: a wet finger on a turning bowl; slow to speak, all but pure, never quite still
    n = int((dur + 1.1) * SR); t = t_of(n)
    env = np.minimum(1.0, t / 0.45) ** 1.5 * np.clip(1.0 - (t - dur) / 1.0, 0.0, 1.0) ** 2 * (1.0 + 0.12 * mm.slow_noise(n, 2.5))
    ph = mm.glide_phase(f, n, 0.0006 * mm.slow_noise(n, 1.5))
    y = np.sin(ph + RNG.uniform(0, 6.28)) + 0.25 * np.sin(1.0019 * ph + RNG.uniform(0, 6.28))   # two modes of the bowl a hair apart: a slow beat
    y += 0.04 * np.sin(2 * ph + RNG.uniform(0, 6.28)) + 0.015 * np.sin(3 * ph + RNG.uniform(0, 6.28)) + 0.025 * np.sin(2.32 * ph + RNG.uniform(0, 6.28))
    y = (y + 0.012 * band(RNG.standard_normal(n), f * 3.0, f * 9.0)) * env    # (the finger's rub)
    return vel * y / 1.25

def v_flute(f, dur, vel, cut=0):   # a wooden flute: breath in the tone, a soft octave and twelfth over it, vibrato on the long notes. cut: a flick of the note that many semitones above, as it starts
    d = max(0.12, dur * 0.97); n = int((d + 0.1) * SR); t = t_of(n)
    vib = np.sin(2 * np.pi * 5.1 * t + RNG.uniform(0, 6.28)) * np.clip((t - 0.28) / 0.35, 0.0, 1.0)
    wob = 0.0045 * vib + 0.0012 * mm.slow_noise(n, 7) - 0.01 * np.exp(-t / 0.02)
    if cut: wob = wob + (2.0 ** (cut / 12.0) - 1.0) * np.clip((0.055 - t) / 0.012, 0.0, 1.0)
    ph = mm.glide_phase(f, n, wob); br = (0.55 + 0.45 * vel) * min(1.0, (700.0 / f) ** 0.5)
    y = np.sin(ph) + br * (0.40 * np.sin(2 * ph + 1.1) + 0.18 * np.sin(3 * ph + 0.4) + 0.08 * np.sin(4 * ph + 2.0) + 0.035 * np.sin(5 * ph + 0.7))
    air = 0.06 * band(RNG.standard_normal(n), 1800.0, 8000.0) + 0.09 * band(RNG.standard_normal(n), f * 0.8, f * 2.6)
    y = (y + air * (1.0 + 2.0 * np.exp(-t / 0.05))) * mm.env_note(n, d, 0.035, 0.09) * (1.0 + 0.07 * vib)
    return vel * y / 1.5

def v_pluck(f, dur, vel):      # a low string plucked with the flesh of the finger: round and short
    n = int(1.0 * SR); t = t_of(n); y = np.zeros(n)
    for h in range(1, 13):
        y += (1.0 / h ** 1.05) * np.sin(2 * np.pi * f * h * t + RNG.uniform(0, 6.28)) * np.exp(-t * (3.0 + 1.0 * h))
    y *= np.minimum(1.0, t / 0.004)
    y = add(y, 0.2 * burst(0.03, 60, 500, 0.008))
    return vel * y / np.max(np.abs(y))

SKIN = [(1.0, 1.0), (1.59, 0.5), (2.14, 0.28), (2.30, 0.2), (2.65, 0.12), (2.92, 0.1), (3.16, 0.07)]   # a round skin's modes: ratio, loudness
KETTLE = [(1.0, 1.0), (1.5, 0.6), (1.99, 0.4), (2.44, 0.22), (2.89, 0.12)]                           # ...over a kettle, pulled nearly into tune
def skin(f, sec, tau, bend, modes=SKIN):
    """a drum skin's ring at f: its modes, the high ones shorter, the pitch falling a little as the skin settles"""
    n = int(sec * SR); t = t_of(n); y = np.zeros(n); tt = t + bend * 0.03 * (1.0 - np.exp(-t / 0.03))
    for r, a in modes: y += a * np.sin(2 * np.pi * f * r * tt + RNG.uniform(0, 6.28)) * np.exp(-t * r ** 0.8 / tau)
    return y / np.max(np.abs(y))

def struck(y, vel, att=0.0015): return vel * y * np.minimum(1.0, t_of(len(y)) / att)

def v_frame(kind, vel):        # a frame drum under the hand: 'd' the open stroke in the middle, 't' a fingertip at the edge, 'k' a muffled slap
    if kind == 'd': return struck(add(skin(88.0, 0.5, 0.16, 0.25), 0.6 * burst(0.05, 120, 1800, 0.012)), vel)
    if kind == 't': return struck(add(0.6 * skin(330.0, 0.2, 0.035, 0.05), 0.7 * burst(0.03, 1200, 7000, 0.007)), vel)
    return struck(add(0.5 * skin(190.0, 0.15, 0.03, 0.1), 0.8 * burst(0.03, 500, 3500, 0.006)), vel)

def v_tom(vel):                # a deeper drum beside it, for the weight of the bar
    return struck(add(skin(64.0, 0.8, 0.26, 0.2), 0.45 * burst(0.06, 80, 900, 0.015)), vel, 0.002)

def v_bigdrum(vel, f=60.0, modes=SKIN, tau=0.32):   # a great drum: a wide skin, a soft heavy beater, the air in the shell booming on
    y = add(skin(f, 1.5, tau, 0.12, modes), 0.7 * burst(0.09, 60, 900, 0.022))
    return struck(add(y, 0.2 * burst(0.02, 800, 4000, 0.004)), vel, 0.003)

def v_shaker(vel):             # a shaker: the seeds gather, then land together (0.018 s after it starts)
    n = int(0.11 * SR); t = t_of(n); y = band(RNG.standard_normal(n), 4500.0, 12000.0)
    return vel * y / np.max(np.abs(y)) * np.where(t < 0.018, (t / 0.018) ** 2, np.exp(-(t - 0.018) / 0.02))

def v_jingle(vel):             # the little brass jingles in a drum's rim
    y = 0.6 * burst(0.25, 5000, 14000, 0.05)
    return vel * (y + sines(1.0, 0.25, [(4310, 0.3, 0.07), (5220, 0.3, 0.06), (6170, 0.25, 0.06), (7350, 0.25, 0.05), (8730, 0.2, 0.05), (10120, 0.15, 0.04)], att=0.0005))

def v_clank(vel, f=620.0):     # a tooth of the great wheel falling home: iron, short
    y = sines(f, 0.3, [(1, 1.0, 0.05), (1.52, 0.7, 0.06), (2.41, 0.5, 0.04), (3.18, 0.4, 0.03), (4.87, 0.25, 0.02)], att=0.0004)
    return vel * add(y, 0.5 * burst(0.02, 1500, 8000, 0.004))

def v_thud(vel):               # the clock's weight taking up its chain: a dull heavy knock in the tower's timber
    n = int(0.5 * SR); t = t_of(n); y = np.sin(2 * np.pi * 72.0 * (t + 0.3 * 0.025 * (1.0 - np.exp(-t / 0.025)))) * np.exp(-t / 0.11)
    return struck(add(y, 0.6 * burst(0.06, 60, 600, 0.015)), vel, 0.002)

GEDACKT = unit(np.array([1.0, 0.03, 0.2, 0.012, 0.06, 0.006, 0.022, 0.003, 0.009]))   # a stopped wooden pipe: the odd harmonics, few of them
PRINCIPAL = unit(1.0 / np.arange(1, 21) ** 1.2)                                       # an open metal pipe: all of them, falling off steadily
REED = [(1150.0, 0.5, 1.0), (2300.0, 0.45, 0.6), (3300.0, 0.4, 0.25)]                  # a reed pipe's resonator: its formants
def pipe(f, dur, vel, amps, att=0.04, chiff=0.1, wind=0.012, together=False):
    """an organ pipe: it speaks with a chiff, a shade sharp, then stands quite still until the key is let go"""
    f = f * 2.0 ** (RNG.uniform(-4, 4) / 1200.0); n = int((dur + 0.1) * SR); t = t_of(n); env = mm.env_note(n, dur, att, 0.08)
    y = osc(mm.glide_phase(f, n, 0.005 * np.exp(-t / 0.035)), amps[:max(1, int(SR * 0.45 / f))], together) * env
    y += wind * band(RNG.standard_normal(n), f * 2.0, f * 7.0) * env
    return vel * add(y, chiff * burst(0.05, f * 2.0, f * 8.0, 0.015))

def v_flutes(f, dur, vel):     # the organ's quiet flutes: a stopped eight-foot, a four-foot over it
    return add(pipe(f, dur, vel, GEDACKT), pipe(2 * f, dur, 0.3 * vel, GEDACKT))

def v_reed(f, dur, vel):       # the organ's reed, a stopped flute drawn with it: a brass tongue beating in a narrow pipe; edged, steady, a little nasal
    d = max(0.1, dur * 0.94)
    return add(pipe(f, d, vel, harmonics(f, 1.1, REED, 0.08, 5000.0), att=0.025, chiff=0.03, wind=0.004, together=True), pipe(f, d, 0.4 * vel, GEDACKT))

BODY = [(95.0, 0.6, 1.0), (190.0, 0.5, 0.8), (420.0, 0.6, 0.6), (850.0, 0.7, 0.4)]     # a contrabass's body
def v_bass(f, dur, vel, att=0.09, rel=0.14, bite=0.0, tilt=1.0):   # a contrabass under the bow. bite: the bow's catch at the start of a short stroke; tilt: how soft the bowing
    n = int((dur + rel + 0.02) * SR); env = mm.env_note(n, dur, att, rel) * (1.0 + 0.08 * mm.slow_noise(n, 5))
    y = osc(mm.glide_phase(f, n, 0.0015 * mm.slow_noise(n, 4)) + RNG.uniform(0, 6.28), harmonics(f, tilt, BODY, 0.15, 3200.0), True) * env
    y += 0.03 * band(RNG.standard_normal(n), 250.0, 2600.0) * env   # (rosin on the string)
    return vel * (add(y, bite * burst(0.04, 150.0, 1800.0, 0.012)) if bite else y)

BELL = [(450.0, 0.8, 1.0), (1200.0, 0.7, 0.7), (2500.0, 0.6, 0.42), (3600.0, 0.5, 0.2)]   # a horn's bell: its formants
def v_brass(f, dur, vel, players=3):   # horns and trombones together: each a little off the others, the tone brightening as it swells
    n = int((dur + 0.2) * SR); t = t_of(n); y = np.zeros(n)
    soft = harmonics(f, 2.0, BELL, 0.06, 6000.0); hard = harmonics(f, 1.0, BELL, 0.06, 6000.0)
    b = np.clip(vel * (0.25 + 0.75 * np.minimum(1.0, t / 0.25)), 0.0, 1.0)
    for _ in range(players):
        ph = mm.glide_phase(f * 2.0 ** (RNG.uniform(-7, 7) / 1200.0), n, 0.0015 * mm.slow_noise(n, 4) - 0.008 * np.exp(-t / 0.03)) + RNG.uniform(0, 6.28)   # (no two start in step)
        y += ((1.0 - b) * osc(ph, soft, True) + b * osc(ph, hard, True)) * mm.env_note(n, dur, RNG.uniform(0.06, 0.1), 0.16)
    return vel * y * (0.85 + 0.15 * np.minimum(1.0, t / max(dur, 0.1))) / players

AH_MEN = [(680.0, 0.28, 1.0), (1090.0, 0.25, 0.6), (2550.0, 0.25, 0.6), (3300.0, 0.3, 0.35)]      # 'ah' in a man's mouth: its formants
AH_WOMEN = [(830.0, 0.28, 1.0), (1220.0, 0.25, 0.6), (2850.0, 0.25, 0.6), (3900.0, 0.3, 0.3)]    # ...and in a woman's
def v_choir(f, dur, vel, men, singers=4):   # a choir on 'ah': several voices to the note, each with a vibrato of its own, none quite together
    n = int((dur + 0.45) * SR); t = t_of(n); y = np.zeros(n); amps = harmonics(f, 1.5, AH_MEN if men else AH_WOMEN, 0.02, 6500.0)
    for _ in range(singers):
        vib = 0.006 * np.sin(2 * np.pi * RNG.uniform(4.8, 5.9) * t + RNG.uniform(0, 6.28)) * np.clip((t - RNG.uniform(0.15, 0.4)) / 0.4, 0.0, 1.0)
        ph = mm.glide_phase(f * 2.0 ** (RNG.uniform(-9, 9) / 1200.0), n, vib + 0.003 * mm.slow_noise(n, 3)) + RNG.uniform(0, 6.28)
        y += osc(ph, amps, True) * mm.env_note(n, dur, RNG.uniform(0.18, 0.3), RNG.uniform(0.3, 0.42))
    return vel * (y / singers + 0.015 * band(RNG.standard_normal(n), 1500.0, 7000.0) * mm.env_note(n, dur, 0.25, 0.35))

# ---------------- the two pieces ----------------
def stems(L, ir, plan):
    """the four stems from their tracks: for each (track, level, how much of the place's echo), and for the drums where their peaks are rounded off"""
    return [sum(mm.wet(rounded(g * L[k].y, top[0]) if top else g * L[k].y, amt, True, ir) for k, g, amt, *top in row) for row in plan]

def climax(L, half, brass, choir, long_notes):
    """the fourth stem's sustained chords, the same way in both: horns on the chords and on the tune's long notes an octave down, a choir on 'ah'"""
    for k in range(4):
        for b, d, m in held(half, brass, k, bars=True): put(L['brass'], b, (1.0 if k == 0 else 0.8) * v_brass(hz(m), d * SPB * 0.96, 0.7 * arc(b)), 0.01)
        for b, d, m in held(half, choir, k, bars=True): put(L['choir'], b, v_choir(hz(m), d * SPB * 0.97, arc(b), men=k < 2), 0.02)
    for i, pair in enumerate(long_notes):
        a, c = (midi(x) - 12 for x in pair.split())
        for b, d, m in ([(i * 4.0, 4.0, a)] if a == c else [(i * 4.0, 2.0, a), (i * 4.0 + 2.0, 2.0, c)]): put(L['brass'], b, 1.3 * v_brass(hz(m), d * SPB * 0.95, arc(b)), 0.01)

def forest():
    """the elves' wood, "the Silverwood air": its four stems"""
    L = {k: mm.Loop(SEC) for k in ('harp', 'glass', 'flute', 'pluck', 'hand', 'shake', 'drums', 'bass', 'under', 'brass', 'choir', 'big')}
    half = halves(F_BARS)
    # 1 exploring: the harp's broken chords (its lowest strings left alone: steps and circles are to be heard), a glass harmonica
    # holding the chords, and far off the tune's long notes
    for i in range(BARS):
        for q, k, v in HARP[i % 2]: put(L['harp'], i * 4.0 + q, v_harp(hz(midi(F_HARP[half[2 * i + (q >= 2)]][k])), 1.0, v), 0.007)
        put(L['glass'], i * 4.0, 0.8 * v_glass(hz(midi(F_LONG[i].split()[0])), 2.0 * SPB, 1.0), 0.02)
    for k in range(3):
        for b, d, m in held(half, F_PAD, k): put(L['glass'], b, v_glass(hz(m), d * SPB, 1.0), 0.02)
    # 2 a skirmish: the tune on the wooden flute, a cut on its long notes and where a note comes twice; strings plucked short,
    # three and three and two; a frame drum and a shaker, lightly
    last = None
    for b, d, m in mm.seq(F_TUNE):
        cut = (1 if (m + 1) % 12 in DORIAN else 2) if (d >= 1.5 or m == last) else 0; last = m
        put(L['flute'], b, v_flute(hz(m), d * SPB, (0.8 + 0.12 * (b % 4.0 == 0) + 0.06 * (b % 2.0 == 0)) * arc(b), cut), 0.006)
    for i in range(BARS):
        for e in range(8):
            k = (0, 1, 2, 0, 1, 2, 0, 1)[e]
            put(L['pluck'], i * 4.0 + e * 0.5, mm.v_pizz(hz(midi(F_PLUCK[half[2 * i + (e >= 4)]][k])), 0.3, 0.95 if k == 0 else 0.6), 0.005)
            put(L['shake'], i * 4.0 + e * 0.5 - 0.018 / SPB, v_shaker(1.0 if e % 2 else 0.6), 0.003)
        for e, kind, v in ((0, 'd', 0.8), (3, 't', 0.45), (4, 'd', 0.55), (6, 't', 0.5)) + (((7, 't', 0.3),) if i % 2 else ()):
            put(L['hand'], i * 4.0 + e * 0.5, v_frame(kind, v))
    # 3 the fight over the objective: the frame drums in sixteenths, the open strokes on the fight's accents, a deeper drum under
    # the bar, jingles between the beats, a roll into every fourth bar line; a low string plucked on the accents; the line under the tune
    for i in range(BARS):
        roll = roll_at(i)
        for s in range(16):
            b = i * 4.0 + s * 0.25
            if s >= roll: put(L['drums'], b, v_frame('d', 0.45 + 0.55 * (s - roll + 1) / (16 - roll)), 0.003)
            elif s in DRIVE: put(L['drums'], b, v_frame('d', 1.0 if s % 8 == 0 else 0.78), 0.003)
            else: put(L['drums'], b, v_frame('t' if s % 2 else 'k', 0.34 + 0.14 * RNG.random()), 0.004)
            put(L['drums'], b - 0.018 / SPB, v_shaker(0.7 if s % 4 == 0 else 0.35 if s % 2 else 0.5), 0.003)
            if s % 4 == 2 and s < roll: put(L['drums'], b, 0.6 * v_jingle(1.0 if s % 8 == 6 else 0.7), 0.003)
        for s, v in ((0, 1.0), (8, 0.85), (14, 0.7)):
            if s < roll: put(L['drums'], i * 4.0 + s * 0.25, 0.9 * v_tom(v), 0.003)
        for s, k in zip(DRIVE, (0, 0, 1, 0, 0, 1)):
            put(L['bass'], i * 4.0 + s * 0.25, v_pluck(hz(midi(F_BASS[half[2 * i + (s >= 8)]][k])), 0.5, 1.0 if s % 8 == 0 else 0.8), 0.004)
    for b, d, m in mm.seq(F_UNDER): put(L['under'], b, v_flute(hz(m), d * SPB, 0.85 * arc(b)), 0.008)
    # 4 the climax: horns and a choir holding the chords, the great drums on the bar and its half, rolling with the frame drums
    climax(L, half, F_HORNS, F_CHOIR, F_LONG)
    for i in range(BARS):
        roll = roll_at(i)
        for s, v in ((0, 1.0), (6, 0.5), (8, 0.85), (14, 0.6)):
            if s < roll: put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(v), 0.004)
        for s in range(roll, 16): put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(0.4 + 0.5 * (s - roll + 1) / (16 - roll)), 0.003)
    return stems(L, mm.room_ir(1.9, 3200.0), [   # (the wood's own echo: long and soft)
        [('harp', 0.5, 0.3), ('glass', 0.15, 0.4)],
        [('flute', 0.7, 0.3), ('pluck', 0.35, 0.2), ('hand', 0.6, 0.15), ('shake', 0.5, 0.1)],
        [('drums', 0.88, 0.14, 1.2), ('bass', 0.8, 0.08), ('under', 0.36, 0.3)],
        [('brass', 0.45, 0.3), ('choir', 0.28, 0.4), ('big', 0.8, 0.2, 1.1)]])

def tower():
    """a mage's stone tower, "the mage's clock": its four stems"""
    L = {k: mm.Loop(SEC) for k in ('flutes', 'drone', 'reed', 'clock', 'bell', 'works', 'cb', 'tenor', 'brass', 'choir', 'big')}
    half = halves(T_BARS)
    # 1 exploring: the organ's quiet flutes holding the chords, two soft notes a bar high over them like a clock's chime, and
    # two contrabasses on the drone, changing bow in turn
    for k in range(3):
        for b, d, m in held(half, T_PAD, k): put(L['flutes'], b, v_flutes(hz(m), d * SPB * 0.985, 1.0), 0.008)
    for i in range(BARS):
        for q in (0, 1): put(L['flutes'], i * 4.0 + 2 * q, 0.55 * pipe(hz(midi(T_CHIME[T_BARS[i]][q])), 0.9 * SPB, 1.0 - 0.2 * q, GEDACKT, chiff=0.14), 0.006)
    for p in (0, 1):
        for b, d, name in T_DRONE:
            cuts = [b] + [x for x in np.arange(b + 4.0 * p, b + d, 8.0) if b < x < b + d] + [b + d]   # (a bow lasts two bars)
            for x0, x1 in zip(cuts[:-1], cuts[1:]): put(L['drone'], x0, v_bass(hz(midi(name)) * (1.002 if p else 0.998), (x1 - x0) * SPB, 1.0, att=0.5, rel=0.6, tilt=1.5), 0.03)
    # 2 a skirmish: the tune on the organ's reed; the clock itself, tick on the beat and tock between, a small bell at the head
    # of every other bar, its ratchet wound at the end of every fourth
    for b, d, m in mm.seq(T_TUNE): put(L['reed'], b, v_reed(hz(m), d * SPB, (0.85 + 0.15 * (b % 4.0 == 0)) * arc(b)), 0.004)
    for i in range(BARS):
        for q in range(4):
            put(L['clock'], i * 4.0 + q, mm.v_click(2900.0, 0.6, 0.011), 0.002); put(L['clock'], i * 4.0 + q + 0.5, mm.v_click(1750.0, 0.4, 0.011), 0.002)
        if i % 2 == 0: put(L['bell'], i * 4.0, mm.v_glock(hz(midi('G6' if i % 4 else 'D7')), 1.0, 0.6 if i % 4 else 1.0), 0.003)
        if i % 4 == 3: put(L['clock'], i * 4.0 + 3.0, mm.v_ratchet(SPB * 0.9, 20, 44, 0.32), 0.0)
    # 3 the fight over the objective: the escapement in sixteenths, iron teeth falling on the fight's accents, the weight's knock
    # under the bar and its half, a bell on the second and fourth beats, the ratchet into every fourth bar line; the
    # contrabass's short strokes on the accents; the organ's principal running in eighths under the tune
    for i in range(BARS):
        roll = roll_at(i)
        for s in range(16):
            b = i * 4.0 + s * 0.25
            put(L['works'], b, mm.v_click(3400.0 if s % 2 == 0 else 3000.0, 0.7 + 0.3 * (s % 4 == 0), 0.004), 0.0015)
            if s in DRIVE and s < roll: put(L['works'], b, v_clank(1.0 if s % 8 == 0 else 0.7, 587.0 if s % 8 == 0 else 880.0), 0.002)
            if s % 8 == 4: put(L['bell'], b, 0.5 * mm.v_glock(hz(midi(T_CHIME[T_BARS[i]][s == 4]) + 12), 0.5, 0.7), 0.003)   # (the chime's two notes, an octave up)
        for s, v in ((0, 1.0), (8, 0.8)):
            if s < roll: put(L['works'], i * 4.0 + s * 0.25, 1.1 * v_thud(v), 0.002)
        if roll < 16: put(L['works'], i * 4.0 + roll * 0.25, mm.v_ratchet((16 - roll) * 0.25 * SPB * 0.95, 22, 50, 0.8), 0.0)
        for s, k in zip(DRIVE, (0, 0, 1, 0, 0, 2)):
            put(L['cb'], i * 4.0 + s * 0.25, v_bass(hz(midi(T_BASS[half[2 * i + (s >= 8)]][k])), 0.5 * SPB, 1.0 if s % 8 == 0 else 0.82, att=0.02, rel=0.1, bite=0.3), 0.004)
        for e, name in enumerate(T_TENOR[i].split()):
            put(L['tenor'], i * 4.0 + e * 0.5, pipe(hz(midi(name)), 0.45 * SPB, 0.85 + 0.15 * (e % 2 == 0), PRINCIPAL, att=0.02, chiff=0.08), 0.004)
    # 4 the climax: low brass and a choir holding the chords, kettledrums on the bass's notes, a great drum on every bar,
    # the kettledrums rolling into every fourth bar line
    climax(L, half, T_BRASS, T_CHOIR, T_LONG)
    for i in range(BARS):
        roll = roll_at(i)
        f = hz(midi(T_DRUM[T_BARS[i]]))
        put(L['big'], i * 4.0, 0.9 * v_bigdrum(1.0, 50.0), 0.004)
        for s, v in ((0, 1.0), (8, 0.85), (14, 0.6)):
            if s < roll: put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(v, f, KETTLE, 0.45), 0.004)
        for s in np.arange(roll, 16, 0.5): put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(0.3 + 0.5 * (s - roll + 0.5) / (16 - roll), f, KETTLE, 0.45), 0.003)
    return stems(L, mm.room_ir(3.0, 2000.0), [   # (the tower's stone: a long dark echo)
        [('flutes', 0.17, 0.35), ('drone', 0.3, 0.2)],
        [('reed', 0.6, 0.3), ('clock', 0.75, 0.3), ('bell', 0.3, 0.3)],
        [('works', 0.6, 0.18, 1.2), ('cb', 0.5, 0.1), ('tenor', 0.38, 0.28)],
        [('brass', 0.56, 0.3), ('choir', 0.4, 0.4), ('big', 0.8, 0.2, 1.1)]])

def plain():
    """the plain of the four banners, "the four banners' march": its four stems"""
    L = {k: mm.Loop(SEC) for k in ('drone', 'call', 'fife', 'pluck', 'snare', 'drums', 'bass', 'under', 'brass', 'choir', 'big')}
    half = halves(P_BARS)
    # 1 exploring: two contrabasses on the chords' roots, bowed long and soft, a pair of horns holding the chords low, and
    # far off, every other bar, a horn calling the tune's opening leap (wind over open ground: no echo to speak of)
    for p in (0, 1):
        for b, d, m in held(half, P_BASS, 0): put(L['drone'], b, v_bass(hz(m) * (1.002 if p else 0.998), d * SPB * 0.98, 0.9, att=0.45, rel=0.5, tilt=1.4), 0.03)
    for k in range(3):
        for b, d, m in held(half, P_PAD, k): put(L['drone'], b, 0.35 * v_brass(hz(m) / 2.0, d * SPB * 0.97, 0.35, players=2), 0.02)
    for i in range(0, BARS, 2):
        for q, d, name in P_CALL: put(L['call'], i * 4.0 + q, v_brass(hz(midi(name)), d * SPB * 0.92, 0.55 * arc(i * 4.0), players=1), 0.01)
    # 2 a skirmish: the march on a fife, a flick on its long notes; strings plucked on the beat and its half; the side drum's
    # march, its fingertips rolling into the fourth beat
    for b, d, m in mm.seq(P_TUNE):
        put(L['fife'], b, v_flute(hz(m) * 2.0, d * SPB, (0.82 + 0.12 * (b % 4.0 == 0)) * arc(b), 1 if d >= 1.5 else 0), 0.005)
    for i in range(BARS):
        for e in range(8):
            k = (0, 2, 1, 2, 0, 2, 1, 2)[e]
            put(L['pluck'], i * 4.0 + e * 0.5, mm.v_pizz(hz(midi(P_PLUCK[half[2 * i + (e >= 4)]][k])), 0.25, 0.9 if e % 2 == 0 else 0.55), 0.005)
        for s, kind, v in ((0, 'd', 0.75), (4, 't', 0.55), (6, 't', 0.4), (8, 'd', 0.6), (12, 't', 0.55), (13, 't', 0.4), (14, 't', 0.5), (15, 't', 0.6)):
            put(L['snare'], i * 4.0 + s * 0.25, v_frame(kind, v), 0.003)
    # 3 the fight for the landmarks: the war drums in sixteenths with the fight's accents, toms under the bar, a roll into every
    # fourth bar line; the bass plucked on the accents; the second fife under the tune
    for i in range(BARS):
        roll = roll_at(i)
        for s in range(16):
            b = i * 4.0 + s * 0.25
            if s >= roll: put(L['drums'], b, v_frame('d', 0.45 + 0.55 * (s - roll + 1) / (16 - roll)), 0.003)
            elif s in DRIVE: put(L['drums'], b, v_frame('d', 1.0 if s % 8 == 0 else 0.8), 0.003)
            else: put(L['drums'], b, v_frame('t' if s % 2 else 'k', 0.32 + 0.14 * RNG.random()), 0.004)
        for s, v in ((0, 1.0), (6, 0.6), (8, 0.9), (14, 0.7)):
            if s < roll: put(L['drums'], i * 4.0 + s * 0.25, 0.95 * v_tom(v), 0.003)
        for s, k in zip(DRIVE, (0, 0, 1, 0, 0, 1)):
            put(L['bass'], i * 4.0 + s * 0.25, v_pluck(hz(midi(P_BASS[half[2 * i + (s >= 8)]][k])), 0.5, 1.0 if s % 8 == 0 else 0.8), 0.004)
    for b, d, m in mm.seq(P_UNDER): put(L['under'], b, v_flute(hz(m) * 2.0, d * SPB * 0.9, 0.8 * arc(b)), 0.007)
    # 4 the climax: the horns and a choir on the chords and the tune's long notes, the great war drums on every beat, heavier
    # on the bar, rolling into every fourth bar line
    climax(L, half, P_HORNS, P_CHOIR, P_LONG)
    for i in range(BARS):
        roll = roll_at(i)
        for s, v in ((0, 1.0), (4, 0.6), (8, 0.85), (12, 0.6)):
            if s < roll: put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(v, 55.0), 0.004)
        for s in range(roll, 16): put(L['big'], i * 4.0 + s * 0.25, v_bigdrum(0.4 + 0.5 * (s - roll + 1) / (16 - roll), 55.0), 0.003)
    return stems(L, mm.room_ir(1.3, 4200.0), [   # (the open plain: a short bright echo off the cliffs)
        [('drone', 0.32, 0.15), ('call', 0.3, 0.35)],
        [('fife', 0.55, 0.25), ('pluck', 0.35, 0.15), ('snare', 0.6, 0.12)],
        [('drums', 0.88, 0.12, 1.2), ('bass', 0.8, 0.06), ('under', 0.32, 0.25)],
        [('brass', 0.5, 0.3), ('choir', 0.3, 0.35), ('big', 0.85, 0.18, 1.1)]])

# ---------------- out ----------------
def main():
    said = []
    for name, piece in (('rf', forest), ('rt', tower), ('rp', plain)):   # (in this order: each set takes its noise after the one before, so the first two stay as they were)
        S = piece()
        # one level for the four stems: the loudest of the ways they are heard (1, 1+2, 1+2+3, all four) just under full scale
        g = 0.89 / max(np.max(np.abs(np.sum(S[:k], axis=0))) for k in (1, 2, 3, 4))
        for k in range(4): mm.write('%s_%d' % (name, k + 1), S[k] * g, LOOP)
        db = lambda y: 20 * np.log10(np.sqrt(np.mean((y * g) ** 2)))
        said.append('%s: stem 1 alone rms %.1f dBFS, all four together rms %.1f dBFS' % (name, db(S[0]), db(np.sum(S, axis=0))))
    for s in said: print(s)

if __name__ == '__main__':
    main()
