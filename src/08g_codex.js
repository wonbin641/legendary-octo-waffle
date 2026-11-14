/* ============ the encyclopaedias (5.12): the gun book (rate, damage, dps, magazine, range...) and the enemy book
   (name, health, speed, traits, what it carries, damage, skills). the numbers are read from the same tables the game runs on
   wherever there is a table; the rest (kit damage, skills) is written out by hand from the fighting code ============ */
const Codex = (() => {
  const n = (x) => Math.round(x).toLocaleString('ko-KR');
  const f1 = (x) => String(Math.round(x * 10) / 10);
  const ms = (x) => f1(x) + ' m/s';
  const el = (tag, cls, text) => { const d = document.createElement(tag); if (cls) d.className = cls; if (text !== undefined) d.textContent = text; return d; };
  const BLEED = '출혈 (초당 ' + BLEED_DPS + ', 10초, 상처마다 쌓임)';
  const beast = (t, mul) => n(ANIMALS[t].dmg * BEAST_DMG * (mul || 1)); // the animals hit half as hard as their table says

  /* ---------- guns ---------- */
  function guns() {
    const list = ORDER.map((id) => {
      const w = WEAPONS[id], shot = w.dmg * w.pellets, rpm = 60 / w.rate;
      // a one-round magazine reloads between every shot, so its "rate" is really shot + reload
      const dps = w.mag > 1 ? shot / w.rate : shot / (w.rate + w.reload);
      const sus = (w.mag * shot) / (w.mag * w.rate + w.reload);
      return { id, w, shot, rpm, dps, sus };
    });
    const top = { rpm: 0, shot: 0, dps: 0, range: 0 };
    for (const g of list) { top.rpm = Math.max(top.rpm, g.rpm); top.shot = Math.max(top.shot, g.shot); top.dps = Math.max(top.dps, g.dps); top.range = Math.max(top.range, g.w.range); }
    return list.map(({ id, w, shot, rpm, dps, sus }) => {
      const free = id === 'pistol', owned = save.owned.includes(id);
      const price = free ? '무료 · 총알 무한' : (owned ? '영구 소유' : '대여 ' + won(w.rent)) + ' · ' + (w.rocket ? '로켓 1발 ' : '총알 100발 ') + won(AMMO100[id]);
      const dmg = w.pellets > 1 ? w.dmg + ' × ' + w.pellets + '발 = ' + n(shot)
        : w.rocket ? '직격 ' + n(w.dmg) + ' · 폭발 최대 ' + n(w.splashDmg) + ' (반경 ' + w.splash + ' m)'
          : w.grenade ? '폭발 ' + n(w.dmg) + ' (반경 ' + w.splash + ' m, 멀수록 약함)' : n(w.dmg);
      const move = w.moveMul === 1 ? '100%' : Math.round(w.moveMul * 100) + '% (' + (w.moveMul > 1 ? '+' : '') + Math.round((w.moveMul - 1) * 100) + '%)';
      return {
        name: w.name, sub: w.model + ' · ' + w.cls, tag: price, cls: owned ? 'own' : '',
        rows: [
          ['연사속도', n(rpm) + '발/분 · ' + (w.auto ? '자동' : '단발'), rpm / top.rpm],
          ['데미지', dmg + (w.head > 1 ? ' · 머리 ×' + w.head : ''), Math.sqrt(shot / top.shot)],
          ['DPS', n(dps) + ' · 재장전 포함 ' + n(sus), Math.sqrt(dps / top.dps)],
          ['탄창', n(w.mag) + '발 · 예비 ' + (w.reserve === Infinity ? '무한' : n(w.reserve) + '발') + (w.rocket ? ' (최대 ' + (w.mag + w.reserve) + '발)' : '')],
          ['재장전', f1(w.reload) + '초'],
          ['사거리', w.range + ' m' + (w.falloff ? ' · ' + w.falloff[0] + '~' + w.falloff[1] + ' m에서 35%까지 약해짐' : ''), w.range / top.range],
          ['이동속도', move],
        ].concat(w.parts && (w.parts.sight !== 'iron' || w.parts.muzzle !== 'none' || w.parts.under !== 'none' || w.parts.paint !== 'base')
          ? [['부속', SLOTS.map((k) => partOf(k, w.parts[k])).filter((p) => p.id !== 'iron' && p.id !== 'none').map((p) => p.name).concat(w.parts.paint !== 'base' ? [(PAINTS.find((q) => q.id === w.parts.paint) || {}).name + ' 도색'] : []).join(' · ') + ' (수치에 반영됨)']] : []),
        note: w.note || '',
      };
    }).concat([{
      name: '근접 공격', sub: 'PC 전용 · V 키 또는 마우스 뒤로 버튼', tag: '무료', cls: '',
      rows: [['데미지', MELEE_DMG + ' · 머리 ×2'], ['공격 시간', f1(MELEE_T) + '초'], ['사거리', MELEE_REACH + ' m'], ['이동속도', '100%']],
      note: '총을 든 채로 바로 휘두릅니다. 나무 상자도 부술 수 있습니다.',
    }]);
  }

  /* ---------- enemies ---------- */
  function foes() {
    const T = ETYPES.thug, Z = ETYPES.zombie, A = ANIMALS, R = ROBOTS, KB = KONG.boss, KM = KONG.minion, SG = SAFARI_GORILLA;
    const B1 = BOSS[1], B5 = BOSS[5], B2 = BOSS[2], B3 = BOSS[3], B4 = BOSS[4];
    const thug = ms(T.speed), slow = ms(T.speed * 0.9);
    const LAB = ['3', '3-2'], ALL3 = ['3', '3-1', '3-2'];
    const siege = (t) => (SIEGE[t] ? ' · 3-1에서 감시탑 공격 ' + SIEGE[t].dmg : '');
    const animal = (t, st, o) => {
      const a = A[t];
      return Object.assign({ st, name: a.name, hp: n(a.hp), speed: '걷기 ' + ms(a.speed) + ' · 달리기 ' + ms(a.run), arms: '없음', pay: a.money }, o);
    };
    const bot = (t, o) => Object.assign({ st: ['4'], name: R[t].name, hp: n(R[t].hp), pay: R[t].money }, o);
    const shot = (S) => '한 발 ' + S[3] + ' · ' + (S[0] === S[1] ? S[0] : S[0] + '~' + S[1]) + '발씩, ' + S[4] + '~' + S[5] + '초마다';
    return [
      // stage 1 and 1-1: men with pistols
      { st: ['1'], name: T.name, hp: n(T.hp), speed: thug, arms: '권총', dmg: '한 발 9 · 1~3발씩 끊어 쏨', trait: '부두 곳곳에 미리 자리 잡고 있음 · 보거나 총소리를 들으면 공격', skill: '없음', pay: 1000 },
      { st: ['1'], boss: 1, name: B1.name, hp: n(B1.hp), speed: slow, arms: '권총', dmg: '한 발 ' + n(9 * B1.dmgMul) + ' · 4발 연사, 쉬는 시간이 짧음', trait: '보스 · 크고 단단함 · 처치하면 보물상자 (총을 영구 소유)', skill: '4연발 사격', pay: 20000 },
      { st: ['1-1'], name: '헬멧 ' + T.name, hp: n(T.hp), speed: thug, arms: '권총 · 오토바이 헬멧', dmg: '한 발 9 · 1~3발씩', trait: '검은 풀페이스 헬멧이 첫 헤드샷을 한 번 막고 벗겨짐', skill: '없음', pay: 1000 },
      { st: ['1-1'], boss: 1, name: BOSS[6].name, hp: n(BOSS[6].hp), speed: slow, arms: '권총 · 오토바이 헬멧', dmg: '한 발 ' + n(9 * BOSS[6].dmgMul) + ' · 4발 연사', trait: '보스 · 헬멧이 첫 헤드샷을 막음 · 보물상자', skill: '4연발 사격', pay: 20000 },
      // stage 1-2: ten kits and the machine-gun boss
      { st: ['1-2'], name: '저격수', hp: n(T.hp), speed: '제자리 (컨테이너 위)', arms: '저격총', dmg: '한 발 140 · 머리를 노림', trait: '가운데 높은 컨테이너 위에 5명', skill: '빨간 레이저로 1.3초 조준한 뒤 사격', pay: 1000 },
      { st: ['1-2'], name: '황금 ' + KITS.deagle.name, hp: n(T.hp), speed: thug, arms: '황금 데저트 이글', dmg: '한 발 45 · 정확함', trait: '9명 · 한 발씩 묵직하게', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.bomber.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.bomber.run), arms: '폭탄 조끼', dmg: '폭발 300 (반경 7 m, 멀수록 약함) · 주변 적도 휘말림', trait: '10명 · 조끼를 쏘면 그 자리에서 터짐 · 스스로 터지면 돈 없음', skill: '가까이 오면 팔을 들고 0.6초 뒤 자폭', pay: 1000 },
      { st: ['1-2'], name: KITS.flame.name, hp: n(T.hp), speed: thug, arms: '화염방사기', dmg: '초당 75 (9.5 m 원뿔) · 방탄조끼로 못 막음', trait: '3명', skill: '1.6~2.4초씩 불을 뿜음', pay: 1000 },
      { st: ['1-2'], name: KITS.rifle.name, hp: n(T.hp), speed: thug, arms: '돌격소총', dmg: '한 발 11 · 3~5발 점사', trait: '12명 · 8~22 m 거리를 유지', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.dagger.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.dagger.run), arms: '단검', dmg: '찌르기 70 · 초당 약 2번', trait: '20명 · 곧장 달려듦', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.saber.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.saber.run), arms: '파란 광선검', dmg: '내려베기 300 · 1.25초마다', trait: '10명', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.saber2.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.saber2.run), arms: '광선검 두 자루', dmg: '내려베기 300 · 양손 번갈아 0.62초마다', trait: '5명', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.nade.name + '병', hp: n(T.hp), speed: thug, arms: '수류탄', dmg: '폭발 100 (반경 5.5 m)', trait: '10명 · 9~20 m 거리를 유지', skill: '삑삑 소리가 나는 수류탄을 2.4~3.6초마다 던짐', pay: 1000 },
      { st: ['1-2'], name: KITS.bat.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.bat.run), arms: '알루미늄 방망이', dmg: '머리 높이 휘두르기 150 + 밀쳐냄', trait: '15명', skill: '없음', pay: 1000 },
      { st: ['1-2'], boss: 1, name: B5.name, hp: n(B5.hp), speed: slow, arms: '기관총', dmg: '한 발 10 · 12~18발 연사', trait: '보스 · 처치하면 보물상자', skill: '긴 연사', pay: 20000 },
      // stage 2: zombies (no health there: a bite infects, a dash poisons)
      { st: ['2'], name: Z.name, hp: n(Z.hp), speed: '1.3~2.0 m/s · 돌진 8.5 m/s', arms: '없음', dmg: '스테이지 2는 체력 대신 · 물리면 감염 (5초 안에 해독약)', trait: '쓰러져도 3초 안에 한 번 더 쏘지 않으면 다시 일어남 · 일어나기 전에 처치하면 돈 1.5배', skill: '체력 30% 이하에서 한 번 돌진 · 맞으면 중독 (8초 안에 해독약)', pay: 1000 },
      { st: ['2'], boss: 1, name: B2.name, hp: n(B2.hp), speed: '1.7 m/s · 폭주 ×1.9 · 돌진 13 m/s', arms: '없음', dmg: '물리면 감염 · 돌진에 맞으면 2초 기절', trait: '보스 · 보물상자', skill: '체력 절반에서 폭주 (빨갛게 변하고 빨라짐) · 5~8초마다 돌진', pay: 20000 },
      // stage 3, 3-1 and 3-2: animals
      animal('zebra', ALL3, { dmg: '없음', trait: '싸우지 않음 · 맞으면 옆 얼룩말과 함께 지그재그로 달아남 · 3-1에서는 감시탑 둘레를 맴돌며 방해', skill: '바닥에서 바로 올라탈 수 있음 (탈것 1단계)' }),
      animal('buffalo', ALL3, { dmg: '들이받기 ' + beast('buffalo') + ' + 3초 기절 + ' + BLEED, trait: '무리 지어 다님' + siege('buffalo'), skill: '발을 구른 뒤 일직선 돌진 · 비스듬한 벽은 타고 미끄러짐' }),
      animal('hippo', ALL3, { dmg: '물기 ' + beast('hippo') + ' + ' + BLEED, trait: '가까이 가면 덤빔' + siege('hippo'), skill: '입을 크게 벌렸다가 꽉 다묾' }),
      animal('rhino', ALL3, { dmg: '떨어질 때 ' + n(100 * BEAST_DMG) + ' + ' + BLEED + ' · 탈것 위면 탈것이 뿔 ' + beast('rhino'), trait: '가까이 가면 덤빔' + siege('rhino'), skill: '돌진 끝에 뿔로 하늘 높이 띄움 · 떨어질 때 또 받히면 더 높이 · 떨어지며 동물을 덮치면 그 동물 최대 체력의 30%' }),
      animal('cheetah', ALL3, { dmg: '스치며 물기 ' + beast('cheetah') + ' + ' + BLEED, trait: '가장 빠른 동물' + siege('cheetah'), skill: '바로 옆을 스치는 직선 질주 중에 물고 지나감' }),
      animal('tiger', ALL3, { dmg: '스치며 물기 ' + beast('tiger') + ' + ' + BLEED, trait: '치타처럼 사냥' + siege('tiger'), skill: '포효: 1초 동안 저절로 도망침 (기린·코끼리 위에서는 버팀)' }),
      animal('lionM', ALL3, { dmg: '물기 ' + beast('lionM') + ' + ' + BLEED, trait: '갈기가 있는 숫사자' + siege('lionM'), skill: '왕의 포효: 호랑이 빼고 모든 동물이 무릎 꿇고 체력 1/3 회복, 포효마다 10%씩 빨라짐 (최대 1.5배)' }),
      animal('giraffe', ALL3, { dmg: '목 휘두르기 ' + beast('giraffe') + ' + ' + BLEED, trait: '머리를 맞히면 데미지 ' + A.giraffe.headX + '배 · 3-1에서는 감시탑 위의 나를 노림', skill: '긴 목을 곤봉처럼 내려침 (감시탑 난간 위까지 닿음) · 길들이면 얼룩말 위에서 올라탈 수 있음 (2단계)' }),
      animal('elephant', ALL3, { dmg: '엄니 ' + beast('elephant') + ' · 돌진 ' + beast('elephant', 1.2) + ' + ' + BLEED, trait: '처치하면 상아 (상점에서 ' + won(IVORY_PRICE) + ')' + siege('elephant'), skill: '돌진 · 나무 상자를 부수며 지나감 · 기린 위에서 올라탈 수 있음 (3단계)' }),
      { st: ['3-1'], name: SG.name, hp: n(SG.hp), speed: '달리기 ' + ms(KM.run) + ' · 돌진 ' + ms(KM.charge), arms: '없음', dmg: '주먹 ' + n(KM.punch * SG.dmgMul) + ' · 돌진 ' + n(KM.chargeDmg * SG.dmgMul) + ' + ' + KM.stun + '초 기절 + ' + BLEED, trait: '6마리 · 평소엔 어슬렁거리다가 가까이 가거나 총소리를 듣거나 맞으면 덤빔 · 감시탑 공격 ' + SIEGE.gorilla.dmg, skill: '번갈아 휘두르는 주먹 · 느린 돌진', pay: A.gorilla.money },
      { st: LAB, name: '고릴라 졸개', hp: n(B3.hp / 4), speed: '달리기 ' + ms(KM.run) + ' · 돌진 ' + ms(KM.charge), arms: '없음', dmg: '주먹 ' + n(KM.punch) + ' · 돌진 ' + n(KM.chargeDmg) + ' + ' + KM.stun + '초 기절 + ' + BLEED, trait: '보스가 가슴을 두드리면 ' + KONG.minionsAt + '마리가 위에서 떨어짐 · 보스 체력의 1/4', skill: '주먹 · 느린 돌진 (회복이 김) · 점프는 안 함', pay: 1000 },
      { st: LAB, boss: 1, name: B3.name, hp: n(B3.hp), speed: '달리기 ' + ms(KB.run) + ' · 돌진 ' + ms(KB.charge), arms: '없음', dmg: '주먹 ' + n(KB.punch) + ' · 돌진 ' + n(KB.chargeDmg) + ' + ' + KB.stun + '초 기절 · 내려찍기 즉사 · 출혈 없음', trait: '보스 · 방탄유리 우리 (3: 9번 우리가 열리고 15초 뒤 · 3-2: 마지막 차례)', skill: '번갈아 훅 · 잦은 돌진 · 내가 선 자리로 큰 점프 (빨간 원 ' + KONG.slamR + ' m 안이면 즉사) · 가슴 치기로 졸개 소환 (최대 ' + KONG.summonMax + '번)', pay: A.gorilla.money * 20 },
      // stage 4: the ship's crew
      bot('cctv', { speed: '고정 (천장)', arms: '볼트 포', dmg: shot(R.cctv.shot), trait: '통로와 복도 천장 모서리 · 시야 ' + R.cctv.sight + ' m', skill: '없음' }),
      bot('patrol', { speed: ms(R.patrol.speed), arms: '전기 곤봉', dmg: '곤봉 ' + R.patrol.dmg + ' + 밀쳐냄', trait: '복도 12대, 메인홀 8대 (메인홀 문이 열려야 깨어남) · 정해진 길을 왕복 순찰 · 머리가 약점', skill: '없음' }),
      bot('droneA', { name: '드론 A', speed: ms(R.droneA.speed), arms: '볼트 포', dmg: shot(R.droneA.shot), trait: '복도에 많음 · 메인홀엔 없음 · 총 한 방에 터짐', skill: '없음' }),
      bot('mine', { speed: '튀어나오면 ' + ms(R.mine.speed), arms: '폭약', dmg: '폭발 ' + R.mine.dmg + ' (반경 3.5 m) · 옆 마인도 연쇄 폭발', trait: '복도와 메인홀 바닥에 묻혀 있음', skill: R.mine.sight + ' m 안에 오면 튀어나와 달려들어 터짐' }),
      bot('gdrone', { boss: 2, name: R.gdrone.name, speed: ms(R.gdrone.speed) + ' · 돌진 26 m/s (분노 32)', arms: '쌍포', dmg: shot(R.gdrone.shot) + ' · 돌진 220 + 크게 밀쳐냄', trait: '중간보스 · 운전실에 혼자 · 황금 꿀벌 모양 · 운전실 문이 열린 뒤에야 나를 알아챔 (들어가면 문이 잠김) · 경보로 75 m 안의 로봇을 깨움 · 체력 50% 이하에서 분노 · 쓰러지면 문이 열리고 세이브 포인트', skill: '드론 A 6~8대 소환 (동시에 최대 18대, 소환된 드론도 처치 수에 들어감) · 날갯짓 후 돌진', pay: R.gdrone.money * 10 }),
      { st: ['4'], boss: 1, name: B4.name, hp: n(B4.hp) + ' (3페이즈)', speed: BPH.map((p) => p.sp).join(' → ') + ' m/s', arms: '레이저 · 유도 로켓 · 스파이더 마인', dmg: '레이저 닿으면 즉사 · 로켓 100 (반경 3 m) · 마인 ' + R.mine.dmg, trait: '보스 · 메인홀 (운전실 조종석의 열쇠가 있어야 문이 열리고, 들어가면 잠김) · 문이 열린 뒤에야 나를 알아챔 · 체력 1/3마다 껍데기가 벗겨지며 작고 빨라짐', skill: '레이저 (조준 ' + BPH.map((p) => p.charge).join('/') + '초) · 로켓 ' + BPH.map((p) => p.rockets).join('/') + '발 · 마인 ' + BPH.map((p) => p.mines).join('/') + '개를 자기 아래로 떨굼 · 3페이즈에 해치 ' + HATCHES.length + '곳에서 드론 32대 출격 (처치 수와 돈에 안 들어가고 보스가 죽으면 사라짐)', pay: R.bdrone.money * 20 },
    ];
  }

  const TAGNUM = {}; for (const k in STAGE_TAG) TAGNUM[STAGE_TAG[k]] = +k;
  const seen = (tags) => !!settings.dev || tags.some((t) => save.cleared.includes(TAGNUM[t]));
  const CHIPS = [['all', '전체'], ['1', '1'], ['1-1', '1-1'], ['1-2', '1-2'], ['2', '2'], ['3', '3'], ['3-1', '3-1'], ['3-2', '3-2'], ['4', '4']];
  function card(c, stage) {
    if (c.locked) {
      const a = el('article', 'cxcard locked'), top = el('div', 'cxtop'); top.append(el('b', null, '???'));
      const tags = el('span', 'cxtags'); for (const s of c.st) tags.append(el('span', 'cxst', s)); top.append(tags); a.append(top);
      a.append(el('p', 'cxnote', '스테이지 ' + c.st.join(' · ') + (c.st.length > 1 ? ' 중 하나를' : eul(c.st[0])) + ' 깨면 열립니다'));
      return a;
    }
    const a = el('article', 'cxcard' + (c.cls ? ' ' + c.cls : '') + (c.boss === 1 ? ' boss' : c.boss === 2 ? ' mid' : ''));
    const top = el('div', 'cxtop'); top.append(el('b', null, c.name));
    const tags = el('span', 'cxtags');
    if (c.boss) tags.append(el('em', 'cxbadge', c.boss === 1 ? '보스' : '중간보스'));
    if (stage) for (const s of c.st) tags.append(el('span', 'cxst', s));
    top.append(tags); a.append(top);
    if (c.sub) a.append(el('div', 'cxsub', c.sub));
    if (c.tag) a.append(el('div', 'cxprice', c.tag));
    const dl = el('dl', 'cxstats');
    for (const [k, v, bar] of c.rows) {
      dl.append(el('dt', null, k)); const dd = el('dd', null, v);
      if (bar !== undefined) { const i = el('i', 'cxbar'), b = el('b'); b.style.width = Math.round(clamp(bar, 0.03, 1) * 100) + '%'; i.append(b); dd.append(i); }
      dl.append(dd);
    }
    a.append(dl);
    if (c.note) a.append(el('p', 'cxnote', c.note));
    return a;
  }
  const C = {
    from: 'menu', tab: 'gun', st: 'all',
    /* the book opens with your first clear (always in developer mode) */
    get ready() { return !!settings.dev || save.cleared.length > 0; },
    open(from) { if (!this.ready) return; this.from = from; showOnly('codex'); this.render(); $('codex').scrollTop = 0; setTimeout(() => $(this.tab === 'gun' ? 'cxtabg' : 'cxtabe').focus({ preventScroll: true }), 0); },
    close() { $('codex').hidden = true; backTo(this.from); },
    show(tab) { this.tab = tab; this.render(); },
    render() {
      const gun = this.tab === 'gun';
      $('cxtabg').setAttribute('aria-selected', gun ? 'true' : 'false'); $('cxtabe').setAttribute('aria-selected', gun ? 'false' : 'true');
      const chips = $('cxchips'); chips.textContent = ''; chips.hidden = gun;
      if (!gun) for (const [k, label] of CHIPS) {
        const b = el('button', k === this.st ? 'on' : '', k === 'all' ? label : '스테이지 ' + label); b.type = 'button'; b.setAttribute('aria-pressed', k === this.st ? 'true' : 'false');
        b.addEventListener('click', () => { this.st = k; this.render(); }); chips.append(b);
      }
      const list = $('cxlist'); list.textContent = '';
      if (gun) { const every = foes(); $('cxtabe').textContent = '적 도감 ' + every.filter((e) => seen(e.st)).length + '/' + every.length; for (const g of guns()) list.append(card(g, false)); $('cxinfo').textContent = 'DPS는 탄창을 쏘는 동안의 초당 데미지, 재장전 포함은 탄창 하나를 쏘고 다시 넣기까지 평균입니다. 막대는 무기끼리 비교한 값입니다.'; return; }
      const every = foes(), open = every.filter((e) => seen(e.st)).length;
      $('cxtabe').textContent = '적 도감 ' + open + '/' + every.length;
      const all = every.filter((e) => this.st === 'all' || e.st.includes(this.st));
      for (const e of all) {
        if (!seen(e.st)) { list.append(card({ locked: true, st: e.st }, true)); continue; }
        const rows = [['체력', e.hp], ['이동속도', e.speed], ['무장', e.arms], ['데미지', e.dmg], ['특징', e.trait], ['스킬', e.skill]];
        if (e.pay) rows.push(['처치 보상', won(e.pay)]);
        list.append(card({ name: e.name, st: e.st, boss: e.boss, rows }, true));
      }
      $('cxinfo').textContent = '동물 데미지는 절반으로 줄어든 실제 값입니다 (보스 고릴라와 졸개는 그대로). 탈것 위에서는 동물의 공격을 탈것이 대신 맞습니다. 처치 보상은 기본값이고, 머리로 잡으면 1.5배, 이미 깬 스테이지는 0원입니다.';
    },
  };
  return C;
})();
$('cxbtn').addEventListener('click', () => Codex.open('menu'));
$('pcxbtn').addEventListener('click', () => Codex.open('pause'));
/* the buttons say when the book is still shut */
function codexButtons() { const r = Codex.ready; for (const id of ['cxbtn', 'pcxbtn']) { const b = $(id); b.disabled = !r; b.textContent = r ? '도감' : '도감 · 첫 클리어 후'; } }
$('cxclose').addEventListener('click', () => Codex.close());
$('cxtabg').addEventListener('click', () => Codex.show('gun'));
$('cxtabe').addEventListener('click', () => Codex.show('foe'));
