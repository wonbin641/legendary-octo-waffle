# 야르 07 · Godot판 코드 리뷰 안내

다른 AI(또는 사람)에게 코드 리뷰를 맡길 때 함께 주는 안내입니다. 코드는 GitHub에 공개되어 있고
(<https://github.com/wonbin641/legendary-octo-waffle/tree/main/godot>), `python3 tools/make_review_bundle.py`로
올리기 좋은 묶음(이 안내, 분야별 코드 묶음 9개, 압축 파일 하나)을 `build/review/`에 만듭니다.

## 한눈에

- 브라우저 1인칭 슈팅 게임 「야르 07」(three.js, 저장소의 `src/`)을 Godot 4.7(GDScript)로 옮긴 판입니다. 스테이지 1~4와
  곁가지 스테이지는 브라우저판과 같게 맞췄고(시험이 브라우저판에서 뽑은 기준 자료와 비교합니다), 스테이지 5(장난감 방과
  팀 모드 세 가지)와 그 배경 음악은 Godot판에만 있습니다.
- **웹판, 다운로드판(Windows), 앱판(Android)은 코드가 하나입니다.** 셋 다 `godot/`의 같은 GDScript를 Godot의 내보내기
  설정(`godot/export_presets.cfg`)만 바꿔 만듭니다. 버전마다 다른 것은 렌더러, 빌드 스크립트, 그리고
  `OS.has_feature(...)`와 `Gfx.fplus`로 갈리는 몇 군데뿐입니다(아래 표).
- 크기: GDScript 약 16,000줄(1.2 MB), 시험 약 2,000줄. 한 번에 다 넣기 어려우면 아래 묶음 0~8을 차례로 봅니다.

## 세 버전

| | 웹판 | 다운로드판 (Windows) | 앱판 (Android) |
|---|---|---|---|
| 받는 곳 | GitHub Pages `/godot-web/` | Pages `download/Yarr07-Setup.exe` | APK (예전 앱 `app.yard07.game` 위에 업데이트) |
| 내보내기 설정 | "Web" (스레드 없음, 소리는 브라우저 샘플) | "Windows Desktop" | "Android" (Gradle 없이 템플릿 APK, arm64·armv7) |
| 렌더러 | Compatibility (WebGL2) | Forward+ (D3D12/Vulkan) | Compatibility (GLES3) |
| 만드는 법 | `tools/build_godot.sh` | `tools/build_windows.sh`, `tools/windows_installer.nsi` (NSIS) | `tools/build_android.sh` (서명 키는 저장소 밖, 환경 변수로만 건넴) |
| 이 버전에서만 도는 코드 | `OS.has_feature("web")`: `main.gd`(화면 배율·터치 감지, 시험용 `window.__yarr` 다리), `store.gd`(localStorage), `snd.gd`의 `WEB_MIX`(브라우저 Web Audio 노드를 Godot 웹 런타임의 버스에 끼움: 패너, 압축기, 음악의 저역 통과, 음악 고리를 브라우저가 직접 돌리게 하는 패치), `ui.gd`(메일·클립보드), `world.gd`(웹판만의 낮은 품질 단계), `music.gd`(샘플 미리 만들기) | `Gfx.fplus`(Forward+일 때): `world.gd`(달 그림자 지도, 화질 사다리), `gfx.gd`, `moonshadow.gd`, `botlook.gd` | `OS.has_feature("mobile")`: `main.gd`(처음부터 터치, 화면 단위 `phone_ratio`, 뒤로 버튼 `back_action`, 백그라운드에서 일시정지, 카메라 구멍을 피하는 `insets_of`·`touch_rects_for`·`touch_buttons_for`), `store.gd`(자동 사격 기본값) |
| 버전에 맞춘 시험 | `tests/web_sound.js` (빌드된 웹판을 크로미엄에서) | 리눅스판의 `--smoke` (같은 데스크톱 코드) | `tests/run.gd`의 `_mobile()` |

터치 조작(가상 방향 패드, 버튼, 자동 사격·근접)은 휴대폰 브라우저와 앱이 같은 코드(`look_mode == "touch"`)를 씁니다.
`project.godot`의 `display/window/handheld/orientation`(가로), `application/config/quit_on_go_back`(뒤로 버튼은 게임이 받음),
`rendering/textures/vram_compression/import_etc2_astc`(안드로이드 내보내기가 요구)는 앱판에만 영향이 있습니다.

## 코드 묶음

0. **플랫폼·빌드·저장·소리**: `project.godot`, `export_presets.cfg`, `main.tscn`, 빌드 스크립트 넷, `store.gd`(설정·저장),
   `savecode.gd`(저장 코드), `meta.gd`(상점·대여·권장 스펙), `weapons.gd`, `custom.gd`(총 꾸미기), `snd.gd`(효과음과 버스),
   `music.gd`(스테이지 5 음악)
1. **게임 루프와 전투**: `main.gd`(화면 상태, 입력, 터치, 프레임), `game.gd`(스테이지 진행, 처치·돈·결과), `player.gd`,
   `guns.gd`, `proj.gd`(유탄·로켓·적의 탄), `loot.gd`, `phys.gd`(충돌 상자·길 찾기 격자·광선), `picture.gd`(3D를 따로 그리는 뷰포트)
2. **맵과 스테이지**: `world.gd`(스테이지 짓기, 조명, 품질), `village.gd`(2), `lab.gd`(3, 3-2), `safari.gd`(3-1), `ship.gd`(4)
3. **적과 AI**: `enemies.gd`(사람·좀비와 공통 처리), `animals.gd`(동물·고릴라·탈것), `robots.gd`(우주선 로봇·보스 드론), `botlook.gd`
4. **스테이지 5**: `toyroom.gd`(방), `toyfoes.gd`·`toys.gd`(장난감 적과 장난감 총), `match.gd`(팀전 뼈대), `toymode.gd`(모드의 바탕),
   `mode_rush.gd`, `mode_escort.gd`, `mode_freeze.gd`
5. **화면**: `ui.gd`(메뉴·상점·편성·도감·설정·브리핑·결과), `hud.gd`, `tacmap.gd`(작전 지도), `codex.gd`(도감 자료), `cutscene.gd`
6. **그래픽**: `gfx.gd`(메시·재질 도우미, 톤 매핑), `grade.gd`(마무리 효과), `moonshadow.gd`(달빛 그림자), `aoview.gd`(AO),
   `fx.gd`(입자), `gunmodels.gd`
7. **시험**: `tests/run.gd`(자동 시험), `tests/fight.gd`(스테이지마다 봇이 싸우는 자동 플레이), `tests/web_sound.js`(웹판의 소리·음악)
8. **소리·음악을 만드는 도구**: `tools/make_music.py`, `tools/make_sounds.py`, `tools/render_sounds.js`

## 읽을 때 알아 둘 것

- 자동 로드: `Phys`(충돌·길 찾기), `Snd`(효과음), `Store`(설정·저장), `Music`(스테이지 5 음악).
- 한 프레임: `main.gd`의 `_process` → `tick` → player, guns, enemies, proj, loot, game, fx, world 순서로 `update`.
  화면 상태는 `main.state`(menu, brief, playing, paused, cutscene, gameover)입니다.
- 단위는 미터와 초, y가 위입니다. 스테이지는 안쪽 번호(1, 6 = 1-1, 5 = 1-2, 2, 3, 7 = 3-1, 8 = 3-2, 4, 9 = 스테이지 5)로 다루고
  화면에는 `Store.STAGE_TAG`로 나옵니다.
- 브라우저판과 같게 맞춘 수치와 순서가 많습니다(같은 난수를 같은 순서로 써서 맵과 적 자리를 만드는 것 등). 일부러 다르게 한
  것은 `godot/README.md`의 "브라우저판과 다른 것"에 있고, 소유자가 정한 규칙(모든 수입 2배 `Store.PAY`, 사자의 수와 크기,
  스테이지 4는 보스 드론을 잡으면 끝 등)도 의도된 것입니다.
- 코드 주석은 영어, 화면 글자는 한국어입니다.
- 묶음에 없는 것: 소리(`sounds/*.wav`)·음악(`music/*.ogg`)·글꼴·아이콘 같은 바이너리(만드는 도구는 묶음 8), 브라우저판 원본(`src/`),
  예전 웹뷰 앱(`android/`), 서명 키(저장소에도 없음). 시험의 기준 자료 `tests/reference_stage1.json`은 압축 파일에만 있습니다.
- 돌려 보기: `godot --headless --path godot res://tests/run.tscn`(자동 시험), `godot --headless --path godot res://tests/fight.tscn`
  (자동 플레이), 웹 빌드 뒤 `node godot/tests/web_sound.js`. 전체 프로젝트(바이너리 포함)는 GitHub에 있습니다.

## 리뷰를 부탁할 점 (제안)

1. 정확성 버그: 화면 상태 전환(일시정지, 결과, 다시 하기), 세이브 포인트, 팀 모드의 다시 나옴과 점수, 경계 값.
2. 버전마다의 위험: 웹(샘플 재생과 `WEB_MIX` 패치가 Godot 웹 런타임이 바뀔 때 깨질 수 있는지, 메모리), Windows(Forward+ 화질 사다리),
   Android(뒤로 버튼, 안전 영역, 화면 단위, 발열·배터리, 저장 위치).
3. 성능: 적 100마리와 팀전의 프레임당 GDScript 비용, 길 찾기, 매 프레임의 할당과 노드 만들기·지우기, 휴대폰의 그리기 호출.
4. 견고성: 저장 자료와 저장 코드(바깥에서 들어오는 문자열) 읽기, 리소스 누수, 지워진 노드나 널 참조.
5. 보안: 저장 코드 해독, 개발자 모드(비밀번호는 해시로만 있음), 빌드 스크립트의 비밀 다루기.
6. 시험이 놓친 곳.
