# 야르 07

브라우저에서 하는 1인칭 슈팅 게임입니다. 같은 게임이 세 곳에서 돌아갑니다.

- 웹: 이 저장소의 GitHub Pages (`index.html`, `game.js`)
- claude.ai 아티팩트: 한 파일짜리 페이지 (`tools/build.sh`가 만드는 `build/yard07.html`)
- 안드로이드 앱: `android/` (인터넷 없이 돌아가는 가로 전용 앱, 설명은 [android/README.md](android/README.md))

## 폴더

| 폴더 | 내용 |
|---|---|
| `src/` | 게임 원본. `01_head.html`(CSS), `02_body.html`(화면 HTML), 그리고 기능별 자바스크립트 조각 31개. `three.min.js`는 앱에 넣는 three.js r128 |
| `tools/` | `build.sh`(조각을 하나로), `build_site.sh`(이 저장소 맨 위의 사이트 파일), `build_app.sh`(앱 파일), `subset_fonts.py` |
| `tests/` | Playwright로 돌리는 시험. `tests/run_all.sh`가 전부 만들고 모두 돌립니다 |
| `android/` | 안드로이드 앱 프로젝트와 글꼴 원본. 서명 키는 저장소에 없습니다 |

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
