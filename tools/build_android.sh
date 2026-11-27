#!/bin/bash
# 안드로이드 앱(APK)을 만듭니다: Godot판(godot/)을 Godot의 안드로이드 내보내기(GLES3, arm64-v8a와 armeabi-v7a)로.
# 예전 앱(브라우저판을 담던 app.yard07.game, 마지막 5.20)과 같은 패키지 이름과 같은 서명 키라서 그 위에 업데이트로 깔립니다.
# 필요한 것: Godot 4.7과 그 안드로이드 내보내기 템플릿, Android SDK(build-tools의 apksigner·aapt2; Godot 편집기 설정의
# export/android/android_sdk_path), JDK 17 이상, 서명 키 android/app/yard07-release.jks와 android/app/keystore.properties(저장소에 없음).
#   GODOT=/path/to/godot VERSION=1.5.0 ./tools/build_android.sh   →  build/android/Yarr07.apk
# 내놓을 때는 그 파일을 download/Yarr07.apk로 옮겨 둡니다(GitHub Pages에서 바로 내려받는 주소; Windows 설치 파일과 같은 자리).
# 버전 코드는 버전에서 셉니다(1.5.0 → 10500, 늘 커짐; 예전 앱의 마지막은 29). 비밀번호는 환경 변수로만 Godot에 건네고 어디에도 찍지 않습니다.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); G=${GODOT:-godot}; VERSION=${VERSION:-1.0.0}
SDK=${ANDROID_HOME:-$(grep -o 'android_sdk_path = "[^"]*"' "$HOME/.config/godot/editor_settings-4.7.tres" 2>/dev/null | cut -d'"' -f2)}
KP=$ROOT/android/app/keystore.properties
[ -f "$KP" ] || { echo "no signing key: android/app/keystore.properties"; exit 1; }
prop() { grep "^$1=" "$KP" | head -1 | cut -d= -f2-; }
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROOT/android/app/$(prop storeFile)"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(prop keyAlias)"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(prop storePassword)"
IFS=. read -r MA MI PA <<< "$VERSION"; PA=${PA%%-*}; PA=${PA%%+*}   # (a pre-release or build tag, 1.6.2-rc1 or 1.6.2+7, counts as 1.6.2)
[[ "$MA" =~ ^[0-9]+$ && "$MI" =~ ^[0-9]+$ && "${PA:-0}" =~ ^[0-9]+$ ]] || { echo "VERSION must be major.minor[.patch], not $VERSION"; exit 1; }
CODE=$((10#$MA * 10000 + 10#$MI * 100 + 10#${PA:-0}))
sed -i -e "s|^version/code=.*|version/code=$CODE|" -e "s|^version/name=.*|version/name=\"$VERSION\"|" "$ROOT/godot/export_presets.cfg"
OUT=$ROOT/build/android; mkdir -p "$OUT"; rm -f "$OUT/Yarr07.apk"
"$G" --headless --path "$ROOT/godot" --import > /dev/null 2>&1 || true
"$G" --headless --path "$ROOT/godot" --export-release "Android" "$OUT/Yarr07.apk" > "$ROOT/build/android-export.log" 2>&1 || true
[ -s "$OUT/Yarr07.apk" ] || { echo "export failed, see build/android-export.log"; grep -iE "error|fail" "$ROOT/build/android-export.log" | grep -vi password | head -20; exit 1; }
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify --print-certs "$OUT/Yarr07.apk" | grep -E "Signer #1 certificate (DN|SHA-256)"
"$BT/aapt2" dump badging "$OUT/Yarr07.apk" | grep -E "^package:|^sdkVersion|^targetSdkVersion|^uses-permission|^application-label:|^native-code" || true
echo "apk: $(du -h "$OUT/Yarr07.apk" | cut -f1)  version $VERSION (code $CODE)"
