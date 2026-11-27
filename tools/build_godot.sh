#!/bin/bash
# Godot판(godot/)을 웹용으로 내보냅니다. 필요한 것: Godot 4.7 (GODOT 환경 변수나 PATH의 godot)과 그 웹 내보내기 템플릿.
#   build/godot-web/       내보낸 그대로 (GitHub Pages의 godot-web/ 폴더로 복사됩니다)
#   build/godot-artifact/  claude.ai 아티팩트용: 엔진은 gzip으로 눌러 engine.wasm, 게임 데이터도 gzip으로 눌러
#                          12 MB씩 나눠 game.wasm, game2.wasm … 이라는 이름으로 (아티팩트는 파일 하나에 15 MB까지,
#                          .pck 형식은 받지 않습니다). 페이지가 받으면서 이어 붙이고 풀어 Godot에 넘깁니다.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); G=${GODOT:-godot}
OUT=$ROOT/build/godot-web; ART=$ROOT/build/godot-artifact; SITE=$ROOT/godot-web
rm -rf "$OUT" "$ART"; mkdir -p "$OUT" "$ART" "$SITE"
"$G" --headless --path "$ROOT/godot" --import > /dev/null 2>&1 || true
"$G" --headless --path "$ROOT/godot" --export-release Web "$OUT/index.html" > "$ROOT/build/godot-export.log" 2>&1
[ -s "$OUT/index.pck" ] && [ -s "$OUT/index.wasm" ] || { echo "export failed, see build/godot-export.log"; exit 1; }
# GitHub Pages: the engine file only changes with the Godot version, so it is copied only when it differs
# (index.png is the page's icon: the page asks for it, and without it every visit logged a 404)
for f in index.html index.js index.pck index.png index.audio.worklet.js index.audio.position.worklet.js index.wasm; do cmp -s "$OUT/$f" "$SITE/$f" || cp "$OUT/$f" "$SITE/$f"; done
# the artifact
cp "$OUT/index.js" "$OUT/index.audio.worklet.js" "$OUT/index.audio.position.worklet.js" "$ART/"
gzip -9 -n -c "$OUT/index.wasm" > "$ART/engine.wasm"
# the game data outgrew one artifact file at 1.9.0: gzipped too, and cut in parts (game.wasm, game2.wasm, ...)
gzip -9 -n -c "$OUT/index.pck" > "$ART/game.gz"; split -b 12000000 -d -a 2 "$ART/game.gz" "$ART/part"; rm "$ART/game.gz"
PARTS=""; n=0
for p in "$ART"/part*; do n=$((n+1)); name=game.wasm; [ $n -gt 1 ] && name=game$n.wasm; mv "$p" "$ART/$name"; PARTS="$PARTS${PARTS:+, }'$name'"; done
CFG=$(grep -o 'const GODOT_CONFIG = {.*};' "$OUT/index.html" || true)
[ -n "$CFG" ] || { echo "no GODOT_CONFIG in $OUT/index.html (has Godot's web page changed?): the artifact cannot be made"; exit 1; }
cat > "$ART/index.html" <<HTML
<title>Yarr 07 Godot</title>
<style>
:root { --night: #0d1220; --ink: #ece6d8; --sodium: #f2a33a; color-scheme: dark; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --night: #0d1220; --ink: #ece6d8; --sodium: #f2a33a; } }
:root[data-theme="dark"] { --night: #0d1220; --ink: #ece6d8; --sodium: #f2a33a; }
html, body { margin: 0; height: 100%; background: var(--night); color: var(--ink); font: 14px system-ui, sans-serif; overflow: hidden; }
canvas { display: block; width: 100vw; height: 100vh; outline: none; }
#st { position: fixed; left: 16px; right: 16px; bottom: 16px; color: var(--sodium); }
</style>
<canvas id="canvas" tabindex="0"></canvas><div id="st">불러오는 중</div>
<script>
// the engine and the game data are stored gzipped under other names, the game data cut in parts (an artifact's file
// holds at most 15 MB): hand Godot the files it asks for, joined and unpacked as they arrive
const realFetch = window.fetch.bind(window);
const PARTS = [$PARTS];
const unzip = (body) => body.pipeThrough(new DecompressionStream('gzip'));
window.fetch = async (u, o) => {
  const url = typeof u === 'string' ? u : u.url;
  if (/index\\.wasm(\\?|\$)/.test(url)) {
    const r = await realFetch('engine.wasm'); if (!r.ok) throw new Error('engine ' + r.status);
    return new Response(unzip(r.body), { headers: { 'Content-Type': 'application/wasm' } });
  }
  if (/index\\.pck(\\?|\$)/.test(url)) {
    const got = PARTS.map((p) => realFetch(p));
    let i = 0, rd = null;
    const joined = new ReadableStream({ async pull(c) {
      for (;;) {
        if (rd === null) {
          if (i === got.length) { c.close(); return; }
          const r = await got[i++]; if (!r.ok) throw new Error('game ' + r.status);
          rd = r.body.getReader();
        }
        const { done, value } = await rd.read();
        if (!done) { c.enqueue(value); return; }
        rd = null;
      }
    } });
    return new Response(unzip(joined));
  }
  return realFetch(u, o);
};
</script>
<script src="index.js"></script>
<script>
$CFG
const st = document.getElementById('st');
let started = false;
new Engine(GODOT_CONFIG).startGame({ onProgress: (c, t) => { if (!started) st.textContent = '불러오는 중 ' + (t ? Math.round(c / t * 100) + '%' : ''); } })
  .then(() => { started = true; st.remove(); }, (e) => { st.textContent = '시작하지 못했습니다: ' + e; });
</script>
HTML
ls -la "$ART" | awk '{print $5, $9}'
