#!/bin/bash
# GitHub Pages용 사이트: 저장소 맨 위의 index.html(256 KB 안, minigame.kr 소유 확인 태그 포함), game.js, minigame-claim.txt
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); SRC=$ROOT/src
CLAIM=mgc_9LCwxJsBMlEyBeGlZD9t2nv5t4XbpNLOWbaHZZr5bK4
"$ROOT/tools/build.sh" > /dev/null
{
  echo '<!doctype html>'
  echo '<html lang="ko">'
  echo '<head>'
  echo '<meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">'
  echo "<meta name=\"minigame-claim\" content=\"$CLAIM\">"
  echo '<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui}img{max-width:100%}[hidden]{display:none!important}</style>'
  grep -v -e 'claude:viewport-fit-sides' "$SRC/01_head.html"
  echo '</head>'
  echo '<body>'
  cat "$SRC/02_body.html"
  echo '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
  echo '<script src="game.js"></script>'
  echo '</body>'
  echo '</html>'
} > "$ROOT/index.html"
cp "$ROOT/build/game.js" "$ROOT/game.js"
printf '%s' "$CLAIM" > "$ROOT/minigame-claim.txt"
wc -c "$ROOT/index.html" "$ROOT/game.js"
