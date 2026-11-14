# Subset the bundled fonts to the characters the game actually uses.
import sys, os, re
from fontTools import subset
html_path, src_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(html_path, encoding='utf-8').read()
chars = set(ch for ch in text if ord(ch) > 0x7f)
chars |= set(chr(c) for c in range(0x20, 0x7f))
chars |= set('∞·—–…×%')
os.makedirs(out_dir, exist_ok=True)
jobs = [
    ('blackhansans_BlackHanSans-Regular.ttf', 'BlackHanSans.woff2'),
    ('ibmplexsanskr_IBMPlexSansKR-Regular.ttf', 'PlexSansKR-400.woff2'),
    ('ibmplexsanskr_IBMPlexSansKR-SemiBold.ttf', 'PlexSansKR-600.woff2'),
    ('ibmplexsanskr_IBMPlexSansKR-Bold.ttf', 'PlexSansKR-700.woff2'),
    ('ibmplexmono_IBMPlexMono-Regular.ttf', 'PlexMono-400.woff2'),
    ('ibmplexmono_IBMPlexMono-SemiBold.ttf', 'PlexMono-600.woff2'),
]
uni = ','.join('U+%04X' % ord(c) for c in sorted(chars))
for src, dst in jobs:
    opts = subset.Options(); opts.flavor = 'woff2'; opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.notdef_outline = True
    font = subset.load_font(os.path.join(src_dir, src), opts)
    s = subset.Subsetter(opts); s.populate(unicodes=[ord(c) for c in chars]); s.subset(font)
    subset.save_font(font, os.path.join(out_dir, dst), opts)
    print(dst, os.path.getsize(os.path.join(out_dir, dst)))
print('glyph chars:', len(chars))
