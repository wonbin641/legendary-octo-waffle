#!/bin/bash
# 게임 조각 파일(src/)을 하나로 합칩니다.
#   build/game.js     합친 게임 코드
#   build/yard07.html claude.ai 아티팩트로 올리는 한 파일짜리 페이지 (three.js는 cdnjs에서)
#   build/test.html   tests/의 시험이 여는 페이지
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); SRC=$ROOT/src; OUT=$ROOT/build
mkdir -p "$OUT"
ORDER="03_core 03b_gfx 04a_world 04b_physics 04c_stage 04e_village 04f_ship 04g_lab 04h_tower 04d_savanna 05_fx 06a_guns 06b_fire 06c_inject 06d_custom 07a_enemies 07b_ai 07c_animals 07d_suv 07e_robots 07f_kong 07g_beasts 07h_shipbots 07i_safari 08a_player 08c_hud 08d_cutscene 08e_map 08f_meta 08g_codex 08b_game"
for f in $ORDER; do cat "$SRC/$f.js"; done > "$OUT/game.js"
node --check "$OUT/game.js"
{ cat "$SRC/01_head.html"; cat "$SRC/02_body.html"; echo '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'; echo '<script>'; cat "$OUT/game.js"; echo '</script>'; } > "$OUT/yard07.html"
{ echo '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom)}body{margin:0;font:14px system-ui}img{max-width:100%}[hidden]{display:none!important}</style></head><body>'; cat "$OUT/yard07.html"; echo '</body></html>'; } > "$OUT/test.html"
wc -c "$OUT/yard07.html"
