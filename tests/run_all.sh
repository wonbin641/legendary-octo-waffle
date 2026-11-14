#!/bin/bash
# 전부 다시 만들고 시험을 모두 돌립니다. 필요한 것: node, playwright(크로미움 포함), python3 + fonttools(앱 글꼴).
# 개발자 모드 비밀번호 창까지 시험하려면 YARD_DEV_PW 에 비밀번호를 넣고 돌리세요(저장소에는 비밀번호를 두지 않습니다).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT/tests"
"$ROOT/tools/build.sh" > /dev/null || exit 1
fail=0
run() { echo "== $1"; if timeout 900 node "$1" > "shots/$1.log" 2>&1; then tail -1 "shots/$1.log"; else tail -8 "shots/$1.log"; fail=1; fi; }
mkdir -p shots
for t in nav_patch.js crates.js stage4_full_run.js stage4_save_point.js stage4_floor_collapse.js save_mail.js landscape_layout.js; do run $t; done
# the app's own files, served the way the app's WebView reads them (nothing from the internet)
"$ROOT/tools/build_app.sh" > /dev/null 2>&1 || exit 1
( cd "$ROOT/android/app/src/main/assets" && exec python3 -m http.server 8765 > /dev/null 2>&1 ) & SERVER=$!
sleep 1
for t in app_offline.js app_key_button.js; do run $t; done
kill $SERVER
[ $fail = 0 ] && echo "ALL TESTS OK" || { echo "SOME TESTS FAILED (logs in tests/shots/)"; exit 1; }
