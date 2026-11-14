# 시험

`build/test.html`(tools/build.sh가 만듦)을 헤드리스 크로미움으로 열고, 게임의 시험용 손잡이(`window.__yard`)로 시간을 직접 흘리며 확인합니다.

```bash
./tests/run_all.sh
```

| 시험 | 확인하는 것 |
|---|---|
| `nav_patch.js` | 상자가 부서질 때 주변만 고친 길찾기 격자가 전체를 다시 만든 것과 같은지 (스테이지 1, 2, 3, 4) |
| `crates.js` | 휴대폰의 상자 자동 사격(12 m 안만), 앱의 상자 자동 근접 공격, PC는 둘 다 없음 |
| `stage4_full_run.js` | 스테이지 4 처음부터 끝까지: 꿀벌, 열쇠, 보스 3페이즈, 해치, 보물상자, 클리어 |
| `stage4_save_point.js` | 로봇 100대 배치, 세이브 포인트, 다시 시작했을 때의 복원 |
| `stage4_floor_collapse.js` | 보스 2페이즈에 메인홀 바닥이 무너지고 계단 구덩이로 걸어 내려갈 수 있는지 |
| `save_mail.js` | 저장 코드 메일 보내기(메일 앱, Gmail, 복사) |
| `landscape_layout.js` | 가로 휴대폰 세 가지 크기에서 터치 버튼이 겹치지 않는지, 근접 버튼, 총기 커스텀 배치 |
| `app_offline.js`, `app_key_button.js` | 앱 파일(`android/app/src/main/assets`)로 인터넷 없이 도는지, 앱의 열쇠 버튼 |

- 개발자 모드 비밀번호는 저장소에 두지 않습니다. 비밀번호 창까지 시험하려면 `YARD_DEV_PW`에 넣어 돌리세요. 없으면 시험이 개발자 모드를 직접 켭니다.
- 스크린샷과 로그는 `tests/shots/`에 남습니다(저장소에는 올리지 않습니다).
