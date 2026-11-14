#!/bin/bash
# 안드로이드 앱의 assets(인터넷 없이 도는 게임 파일)를 만듭니다: 게임 코드, three.js, 쓰는 글자만 추린 글꼴, 라이선스.
# 그다음 android/ 에서 gradle assembleRelease 로 APK를 만듭니다(README 참고). fontTools(pip install fonttools brotli)가 필요합니다.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); SRC=$ROOT/src; F=$ROOT/android/fonts_src; A=$ROOT/android/app/src/main/assets
"$ROOT/tools/build.sh" > /dev/null
rm -rf "$A" && mkdir -p "$A/fonts" "$A/licenses"
python3 "$ROOT/tools/subset_fonts.py" "$ROOT/build/yard07.html" "$F" "$A/fonts" > "$ROOT/build/subset.log"
cp "$SRC/three.min.js" "$A/three.min.js"
cp "$F/three.js-LICENSE.txt" "$A/licenses/three.js-LICENSE.txt"
cp "$F/blackhansans_OFL.txt" "$A/licenses/BlackHanSans-OFL.txt"
cp "$F/hahmlet_OFL.txt" "$A/licenses/Hahmlet-OFL.txt"
cp "$F/ibmplexsanskr_OFL.txt" "$A/licenses/IBMPlexSansKR-OFL.txt"
cp "$F/ibmplexmono_OFL.txt" "$A/licenses/IBMPlexMono-OFL.txt"
{
  echo '<!doctype html>'
  echo '<html lang="ko">'
  echo '<head>'
  echo '<meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">'
  echo '<style>'
  echo ':root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui}img{max-width:100%}[hidden]{display:none!important}'
  echo '@font-face{font-family:"Black Han Sans";src:url(fonts/BlackHanSans.woff2) format("woff2");font-weight:400;font-display:block}'
  for w in 400 600 700; do echo "@font-face{font-family:\"IBM Plex Sans KR\";src:url(fonts/PlexSansKR-$w.woff2) format(\"woff2\");font-weight:$w;font-display:block}"; done
  for w in 400 600; do echo "@font-face{font-family:\"IBM Plex Mono\";src:url(fonts/PlexMono-$w.woff2) format(\"woff2\");font-weight:$w;font-display:block}"; done
  echo '</style>'
  grep -v -e 'fonts.googleapis.com' -e 'fonts.gstatic.com' -e 'claude:viewport-fit-sides' "$SRC/01_head.html"
  echo '</head>'
  echo '<body>'
  cat "$SRC/02_body.html"
  echo '<script src="three.min.js"></script>'
  echo '<script>'
  cat "$ROOT/build/game.js"
  echo '</script>'
  echo '</body>'
  echo '</html>'
} > "$A/index.html"
echo "assets: $(du -sh "$A" | cut -f1)"; cat "$ROOT/build/subset.log"
