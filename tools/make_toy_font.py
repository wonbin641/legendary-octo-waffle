#!/usr/bin/env python3
"""스테이지 5(장난감 방) 화면의 손글씨 글꼴을 만듭니다: 주아체(Jua, SIL OFL 1.1)에서 게임이 실제로 쓰는 글자만 남깁니다.

    python3 tools/make_toy_font.py        (fonttools가 필요합니다: pip install fonttools)

- 원본: tools/fonts/Jua-Regular.ttf (https://github.com/google/fonts 의 ofl/jua, 2.1 MB, 한글 2,350자)
- 결과: godot/fonts/jua_Jua-Regular.ttf (godot/scripts/*.gd 에 나오는 글자와 ASCII만, 0.6 MB쯤)
- godot/scripts 의 글에 새 한글 글자가 생기면 다시 돌립니다. tests/run.gd 가 빠진 글자를 알려 줍니다
  (빠진 글자는 본문 글꼴로 대신 그려지므로 게임이 깨지지는 않습니다).
"""
import glob, os, sys
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'fonts', 'Jua-Regular.ttf')
OUT = os.path.join(ROOT, 'godot', 'fonts', 'jua_Jua-Regular.ttf')

def used_chars():
    chars = set(chr(c) for c in range(0x20, 0x7f))
    for path in sorted(glob.glob(os.path.join(ROOT, 'godot', 'scripts', '*.gd'))):
        chars |= set(ch for ch in open(path, encoding='utf-8').read() if ord(ch) > 0x7f)
    return chars

def main():
    chars = used_chars()
    opts = subset.Options(); opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True; opts.hinting = False
    font = subset.load_font(SRC, opts)
    have = font.getBestCmap()
    s = subset.Subsetter(opts); s.populate(unicodes=[ord(c) for c in chars]); s.subset(font)
    subset.save_font(font, OUT, opts)
    missing = ''.join(sorted(c for c in chars if ord(c) not in have))
    print('%s: %d bytes, %d of %d characters (not in Jua, drawn by the body font: %s)' % (os.path.relpath(OUT, ROOT), os.path.getsize(OUT), len(chars) - len(missing), len(chars), missing or 'none'))

if __name__ == '__main__':
    sys.exit(main())
