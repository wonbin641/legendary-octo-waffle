#!/usr/bin/env python3
"""다른 AI(또는 사람)에게 코드 리뷰를 맡길 묶음을 build/review/ 에 만듭니다. 파이썬 표준 라이브러리만 씁니다.
  00_REVIEW.md               안내 (godot/REVIEW.md: 세 버전이 한 코드라는 것, 버전마다 다른 곳, 읽는 법, 부탁할 점)
  part0_....md ~ part8_....md 분야별 코드 묶음 (파일마다 경로와 코드 블록; AI에게 하나씩 올리기 좋은 크기)
  yarr07-code-review.zip     위의 것들과 소스 트리 (godot/의 코드·장면·설정·시험, tools/의 빌드·소리 도구; 소리·음악·글꼴 같은 바이너리는 뺌)
godot/scripts/의 .gd 파일이 어느 묶음에도 없으면 멈춥니다(새 파일을 빠뜨리지 않게). 비밀이 섞이지 않았는지도 봅니다:
android/app/keystore.properties의 비밀번호(있으면), 환경 변수 YARD_DEV_PW(개발자 비밀번호, 있으면)."""
import glob, os, sys, zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(ROOT, 'build', 'review')
S = 'godot/scripts/'
PARTS = [
    ('part0_platform_build_save_audio', '0 · 플랫폼·빌드·저장·소리',
     '세 버전(웹·다운로드·앱)이 갈리는 곳: 프로젝트와 내보내기 설정, 빌드 스크립트 넷. 그리고 설정·저장(Store), 계정(Cloud와 server/의 계정 서버), 저장 코드, 상점 규칙, 총 수치, 효과음(Snd, 웹판의 WEB_MIX 포함)과 스테이지 5 음악(Music).',
     ['godot/project.godot', 'godot/export_presets.cfg', 'godot/main.tscn', 'tools/build_godot.sh', 'tools/build_windows.sh', 'tools/windows_installer.nsi',
      'tools/build_android.sh', 'server/src/index.js', 'server/schema.sql', 'server/wrangler.toml', S + 'store.gd', S + 'cloud.gd', S + 'savecode.gd', S + 'meta.gd', S + 'weapons.gd', S + 'custom.gd', S + 'snd.gd', S + 'music.gd']),
    ('part1_loop_combat', '1 · 게임 루프와 전투',
     '화면 상태·입력·터치·프레임(main.gd, 앱판의 뒤로 버튼과 안전 영역 포함), 스테이지 진행과 처치·돈·결과(game.gd), 플레이어, 총, 날아가는 것, 전리품, 충돌과 길 찾기, 3D 뷰포트.',
     [S + 'main.gd', S + 'game.gd', S + 'player.gd', S + 'guns.gd', S + 'proj.gd', S + 'loot.gd', S + 'phys.gd', S + 'picture.gd']),
    ('part2_world_stages', '2 · 맵과 스테이지',
     '스테이지를 짓는 world.gd(조명·품질, 웹판과 Forward+의 갈림 포함)와 스테이지 2(마을), 3·3-2(연구소), 3-1(사파리), 4(우주선).',
     [S + 'world.gd', S + 'village.gd', S + 'lab.gd', S + 'safari.gd', S + 'ship.gd']),
    ('part3_enemies_ai', '3 · 적과 AI',
     '사람·좀비와 적 공통 처리, 동물·고릴라·탈것, 우주선 로봇과 보스 드론, 로봇 모양.',
     [S + 'enemies.gd', S + 'animals.gd', S + 'robots.gd', S + 'botlook.gd']),
    ('part4_stage5_toyroom_teams', '4 · 스테이지 5: 장난감 방과 팀 모드',
     '장난감 방, 장난감 적과 장난감 총, 팀전의 뼈대와 모드 세 가지(AA 배터리 쟁탈전, 장난감 기차 호위전, 취침 시간 술래잡기).',
     [S + 'toyroom.gd', S + 'toyfoes.gd', S + 'toys.gd', S + 'match.gd', S + 'toymode.gd', S + 'mode_rush.gd', S + 'mode_escort.gd', S + 'mode_freeze.gd']),
    ('part5_ui_hud', '5 · 화면: 메뉴와 HUD',
     '메뉴·상점·편성·도감·설정·브리핑·결과(ui.gd), 싸울 때의 화면 표시, 작전 지도, 도감 자료, 컷신.',
     [S + 'ui.gd', S + 'hud.gd', S + 'tacmap.gd', S + 'codex.gd', S + 'cutscene.gd']),
    ('part6_graphics', '6 · 그래픽',
     '메시·재질 도우미와 톤 매핑, 마무리 효과, 달빛 그림자, AO, 입자, 손에 든 총 모델.',
     [S + 'gfx.gd', S + 'grade.gd', S + 'moonshadow.gd', S + 'aoview.gd', S + 'fx.gd', S + 'gunmodels.gd']),
    ('part7_tests', '7 · 시험',
     '자동 시험(run.gd, 브라우저판에서 뽑은 기준 자료와 비교하는 것 포함), 스테이지마다 봇이 싸우는 자동 플레이(fight.gd), 휴대폰 크기 창에서 손가락으로 메뉴를 써 보는 시험(touch.gd), 정조준한 총이 조준점을 가리지 않는지 보는 시험(aim.gd), 빌드된 웹판의 소리·음악 시험(web_sound.js).',
     ['godot/tests/run.gd', 'godot/tests/fight.gd', 'godot/tests/touch.gd', 'godot/tests/aim.gd', 'godot/tests/web_sound.js', 'godot/tests/cloud.gd', 'server/test/server.test.mjs', 'server/test/game.test.mjs', 'server/test/web.test.mjs', 'server/test/live.py']),
    ('part8_audio_tools', '8 · 소리·음악을 만드는 도구',
     '스테이지 5의 배경 음악(make_music.py), 장난감 효과음(make_sounds.py), 브라우저판 Sound 코드로 효과음을 굽는 도구(render_sounds.js).',
     ['tools/make_music.py', 'tools/make_sounds.py', 'tools/render_sounds.js']),
]
EXTRA = ['godot/README.md', 'godot/REVIEW.md', 'godot/tests/run.tscn', 'godot/tests/fight.tscn', 'godot/tests/touch.tscn', 'godot/tests/aim.tscn', 'godot/tests/cloud.tscn', 'godot/tests/reference_stage1.json', 'server/README.md', 'server/package.json']
LANG = {'.gd': 'gdscript', '.py': 'python', '.js': 'javascript', '.mjs': 'javascript', '.sql': 'sql', '.toml': 'toml', '.sh': 'bash', '.nsi': 'nsis', '.cfg': 'ini', '.godot': 'ini', '.tscn': 'ini', '.md': 'markdown', '.json': 'json'}

def read(rel): return open(os.path.join(ROOT, rel), encoding='utf-8').read()

def secrets():
    out = []
    kp = os.path.join(ROOT, 'android', 'app', 'keystore.properties')
    if os.path.exists(kp):
        for line in open(kp, encoding='utf-8'):
            k, _, v = line.strip().partition('=')
            if k.strip().lower().endswith('password') and v.strip(): out.append(v.strip())
    if os.environ.get('YARD_DEV_PW'): out.append(os.environ['YARD_DEV_PW'])
    return out

def main():
    listed = {f for _, _, _, fs in PARTS for f in fs}
    missing = sorted(f for f in (S + os.path.basename(p) for p in glob.glob(os.path.join(ROOT, S, '*.gd'))) if f not in listed)
    if missing: sys.exit('scripts in no part: ' + ', '.join(missing))
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, '*')): os.remove(old)
    texts = {'00_REVIEW.md': read('godot/REVIEW.md')}
    n = len(PARTS)
    for i, (name, title, about, files) in enumerate(PARTS):
        lines = ['# 야르 07 Godot판 코드 · 묶음 %s' % title, '',
                 '이 파일은 코드 묶음 %d개 가운데 하나입니다(0~%d). 세 버전(웹·다운로드·앱)이 한 코드라는 것과 읽는 법은 `00_REVIEW.md`를 먼저 봐 주세요.' % (n, n - 1), '',
                 about, '', '이 묶음의 파일:', '']
        lines += ['- `%s` (%d줄)' % (f, read(f).count('\n') + 1) for f in files]
        for f in files:
            body = read(f)
            fence = '````' if '```' in body else '```'
            lines += ['', '---', '', '## `%s`' % f, '', fence + LANG.get(os.path.splitext(f)[1], ''), body.rstrip('\n'), fence]
        texts[name + '.md'] = '\n'.join(lines) + '\n'
    bad = [s for s in secrets() if any(s in t for t in texts.values()) or any(s in read(f) for f in EXTRA)]
    if bad: sys.exit('a secret is in the bundle: stopped')
    for name, t in texts.items():
        open(os.path.join(OUT, name), 'w', encoding='utf-8').write(t)
    z = os.path.join(OUT, 'yarr07-code-review.zip')
    with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in texts: zf.write(os.path.join(OUT, name), 'yarr07-code-review/' + name)
        for f in sorted(listed | set(EXTRA)): zf.write(os.path.join(ROOT, f), 'yarr07-code-review/source/' + f)
    for name, t in texts.items():
        b = len(t.encode('utf-8')); print('%-40s %7.0f KB  ~%3.0fk tokens' % (name, b / 1024, b / 3.6 / 1000))
    print('%-40s %7.0f KB' % ('yarr07-code-review.zip', os.path.getsize(z) / 1024))

if __name__ == '__main__':
    main()
