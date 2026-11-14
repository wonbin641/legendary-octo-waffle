# Yarr! 07 (야르 07) · Godot 4판

브라우저판(`../src`, Three.js)을 Godot 4.7로 옮기는 중입니다. 다 옮길 때까지 브라우저판이 그대로 배포됩니다.

- 엔진: Godot 4.7, GDScript, Compatibility 렌더러(웹용).
- 충돌과 길 찾기는 Godot의 물리 엔진이 아니라 브라우저판의 코드를 그대로 옮긴 것입니다(`scripts/phys.gd`). 조작 느낌과 적의 움직임이 같아야 하기 때문입니다.
- 지도는 브라우저판과 같은 난수를 같은 순서로 써서 만듭니다(`scripts/world.gd`). 컨테이너, 상자, 가로등이 같은 자리에 섭니다.

## 지금까지 (3단계)

- 스테이지 1 지도, 걷기·달리기·점프, 마우스(잠금, 잠금이 막히면 마우스 이동 + Q/E)와 터치 조작, 일시정지.
- 무기 8종: 발사, 퍼짐과 반동, 정조준(저격총 조준경), 재장전, 무기 교체, 근접 공격, 유탄, 유도 로켓, 기관총 과열.
- 나무 상자가 부서집니다. 터치에서는 12 m 안의 상자를 조준하면 저절로 쏘고, 닿는 거리에 들어오면 저절로 칩니다.
- 효과음은 `tools/make_sounds.py`가 브라우저판의 조합법으로 미리 만들어 둔 파일(`sounds/`)입니다.
- 적, 상점, 진짜 메뉴는 아직 없습니다. 시험판은 무기 8종을 모두 쥐여 줍니다(1-8 키).

## 만들기와 시험

```bash
GODOT=/path/to/godot ./tools/build_godot.sh     # build/godot-web, build/godot-artifact, 그리고 ../godot-web(GitHub Pages)
godot --headless --path godot res://tests/run.tscn   # 브라우저판에서 뽑은 기준 자료와 비교
node tests/dump_reference.js                    # 기준 자료(godot/tests/reference_stage1.json)를 브라우저판에서 다시 뽑기
```

시험은 충돌 상자 195개와 상자 40개의 위치, 길 찾기 격자, 같은 키 입력의 이동 결과, 무기 8종의 모든 수치, 방아쇠를 누르고 있을 때 남는 탄 수가 브라우저판과 같은지 확인합니다.
