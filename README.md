# 야르 07 (Yarr! 07)

브라우저에서 하는 1인칭 슈팅 게임입니다. 한국어 이름은 야르 07, 영어 이름은 Yarr! 07입니다. 같은 게임이 세 곳에서 돌아갑니다.

- 웹: 이 저장소의 GitHub Pages (`index.html`, `game.js`)
- claude.ai 아티팩트: 한 파일짜리 페이지 (`tools/build.sh`가 만드는 `build/yard07.html`)
- 안드로이드 앱: `android/` (인터넷 없이 돌아가는 가로 전용 앱, 설명은 [android/README.md](android/README.md))
- Windows 데스크톱판(Godot판, 완성판): [설치 파일 내려받기](https://wonbin641.github.io/legendary-octo-waffle/download/Yarr07-Setup.exe) (`download/Yarr07-Setup.exe`, Windows 10/11 64비트, Forward+ 렌더러: Vulkan 또는 Direct3D 12). Godot 웹판은 가볍게 맛보는 판입니다
- 안드로이드 앱(Godot판, 완성판): [APK 내려받기](https://wonbin641.github.io/legendary-octo-waffle/download/Yarr07.apk) (`download/Yarr07.apk`, 안드로이드 7.0 이상, 가로 전용). 휴대폰에서 이 링크를 눌러 받은 뒤 파일을 열어 설치합니다(처음에는 브라우저나 파일 앱에 "출처를 알 수 없는 앱 설치"를 허용해야 합니다). 예전 앱(`app.yard07.game`)이 깔려 있으면 그 위에 업데이트로 깔립니다

Godot 4로 옮긴 판이 따로 있습니다: [godot/](godot/README.md) (소스), `godot-web/` (웹 내보내기, GitHub Pages의 `/godot-web/`). 브라우저판과 같은 스테이지 8개, 같은 수치, 같은 저장 코드를 쓰고, Godot판에만 있는 스테이지 5(장난감 방)가 더 있습니다.

## 폴더

| 폴더 | 내용 |
|---|---|
| `download/` | Godot판의 Windows 설치 파일(`tools/build_windows.sh`가 만드는 `Yarr07-Setup.exe`)과 안드로이드 앱(`tools/build_android.sh`가 만드는 `Yarr07.apk`)을 옮겨 둔 것. GitHub Pages에서 바로 내려받습니다 |
| `src/` | 게임 원본. `01_head.html`(CSS), `02_body.html`(화면 HTML), 그리고 기능별 자바스크립트 조각 31개. `three.min.js`는 앱에 넣는 three.js r128 |
| `tools/` | `build.sh`(조각을 하나로), `build_site.sh`(이 저장소 맨 위의 사이트 파일), `build_app.sh`(앱 파일), `subset_fonts.py` |
| `tests/` | Playwright로 돌리는 시험. `tests/run_all.sh`가 전부 만들고 모두 돌립니다 |
| `android/` | 안드로이드 앱 프로젝트와 글꼴 원본. 서명 키는 저장소에 없습니다 |
| `server/` | Godot판의 계정 서버(아이디 로그인, 진행 상황 저장): Cloudflare Workers + D1. 설명은 [server/README.md](server/README.md). 비밀값은 저장소에 없습니다 |

맨 위의 `index.html`, `game.js`, `minigame-claim.txt`는 `tools/build_site.sh`가 만든 결과물이고, GitHub Pages가 이 파일들을 보여 줍니다. 직접 고치지 말고 `src/`를 고친 뒤 다시 만드세요.

## 만들기와 시험

```bash
./tools/build.sh
```

```bash
./tools/build_site.sh
```

```bash
./tests/run_all.sh
```

시험에는 node와 playwright(크로미움 포함), 앱 파일을 만들 때는 python3과 `fonttools`, `brotli`가 필요합니다. 조각 파일은 `tools/build.sh`에 적힌 순서대로 이어 붙습니다.
