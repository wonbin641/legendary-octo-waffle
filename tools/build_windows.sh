#!/bin/bash
# Godot판(godot/)의 Windows 데스크톱판과 설치 파일을 만듭니다.
# 필요한 것: Godot 4.7(GODOT 환경 변수나 PATH의 godot)과 그 Windows 내보내기 템플릿, NSIS(makensis), python3 + Pillow, zip
#   build/windows/Yarr07.exe          게임 하나(데이터를 안에 담은 실행 파일)
#   build/windows/Yarr07-Setup.exe    설치 파일(사용자 폴더에 설치, 시작 메뉴·바탕 화면 바로 가기, 제거 프로그램)
#   build/windows/Yarr07-windows.zip  설치 없이 풀어서 바로 실행하는 판
# 시험: godot/의 내보내기 설정 "Linux"로 같은 데이터를 내보내 '-- --smoke'로 돌려 보면 모든 스테이지를 시작해 보고 끝납니다.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); G=${GODOT:-godot}; OUT=$ROOT/build/windows; VERSION=${VERSION:-1.0.0}
rm -rf "$OUT"; mkdir -p "$OUT"
"$G" --headless --path "$ROOT/godot" --import > /dev/null 2>&1 || true
"$G" --headless --path "$ROOT/godot" --export-release "Windows Desktop" "$OUT/Yarr07.exe" > "$ROOT/build/godot-windows-export.log" 2>&1
[ -s "$OUT/Yarr07.exe" ] || { echo "export failed, see build/godot-windows-export.log"; exit 1; }
# the game's own icon (the app's, godot/icon.png) at the sizes Windows asks for
python3 -c "from PIL import Image; Image.open('$ROOT/godot/icon.png').convert('RGBA').save('$OUT/icon.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(192,192)])"
SIZE_KB=$(( $(stat -c %s "$OUT/Yarr07.exe") / 1024 ))
makensis -V2 -DOUTDIR="$OUT" -DVERSION="$VERSION" -DSIZE_KB="$SIZE_KB" "$ROOT/tools/windows_installer.nsi"
(cd "$OUT" && rm -f Yarr07-windows.zip && zip -q -9 Yarr07-windows.zip Yarr07.exe)
ls -la "$OUT" | awk 'NR > 1 {print $5, $9}'
