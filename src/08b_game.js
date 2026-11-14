
/* ============ game flow: stages, money, infection, shop, screens ============ */
const STAGES = {
  1: { name: '컨테이너 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '밀수 조직원 100명 · 총소리를 들으면 몰려옵니다' },
  6: { name: '헬멧 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '오토바이 헬멧 쓴 조직원 100명 · 헬멧은 머리를 한 번 맞히면 벗겨집니다' },
  5: { name: '무장 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '단검 20 · 파란 광선검 10 · 쌍광선검 5 · 야구방망이 15 · 자폭맨 10 · 저격 5 · 보스는 기관총' },
  4: { name: '우주선', enemy: 'robot', goal: 100, unit: '대', label: '로봇', intro: '에어록 → 통로 → 160 m 복도의 드론 떼 · 서쪽 2층 운전실에 황금 꿀벌 드론 · 동쪽 넓은 메인홀에 3페이즈 보스 드론 · 바닥의 스파이더 마인 조심' },
  2: { name: '불타는 마을', enemy: 'zombie', goal: 100, unit: '마리', label: '좀비', intro: '좀비 100마리 · 체력은 없고 감염과 중독뿐 · 해독약은 나무 상자에서' },
  7: { name: '사파리 감시탑', enemy: 'animal', goal: 100, unit: '마리', label: '동물', intro: '넓은 사파리의 동물 100마리 · 5분 뒤 모두 가운데 감시탑으로 습격 · 탑 체력 10,000 · 기린은 긴 목으로 탑 위까지 칩니다' },
  8: { name: '차례 연구소', enemy: 'animal', goal: 90, unit: '마리', label: '동물', intro: '우리 10개를 하나씩 · 앞 우리의 동물을 다 잡아야 원숭이 박사가 다음 우리를 엽니다 · 모든 우리가 방탄유리 · 마지막은 거대 고릴라' },
  3: { name: '동물 연구소', enemy: 'animal', goal: 90, unit: '마리', label: '동물', intro: '우리 10개 · 10초 뒤 첫 우리가 열리고 15초마다 하나씩 · 얼룩말 → 기린 → 코끼리 순서로 올라탈 수 있음 · 보스 고릴라는 방탄유리 우리에' },
};
function pickWeighted(list) { let t = 0; for (const [, w] of list) t += w; let x = Math.random() * t; for (const [k, w] of list) { x -= w; if (x <= 0) return k; } return list[0][0]; }
const BOSS = {
  1: { type: 'thug', name: '조직 두목', josa: '이', scale: 1.35, hp: 1600, dmgMul: 1.6 },
  6: { type: 'thug', name: '헬멧 두목', josa: '이', scale: 1.35, hp: 1600, dmgMul: 1.6, helmet: true },
  5: { type: 'thug', name: '무장 두목', josa: '이', scale: 1.4, hp: 2600, dmgMul: 1, kit: 'lmg' },
  4: { type: 'bdrone', name: '최첨단 감시 드론 B-3', josa: '이', scale: 1, hp: 9000, dmgMul: 1 },
  2: { type: 'zombie', name: '거대 좀비', josa: '가', scale: 1.7, hp: 2200, dmgMul: 1 },
  3: { type: 'gorilla', name: '거대 로랜드고릴라', josa: '가', scale: 3, hp: 5200, dmgMul: 1, kong: true },
  8: { type: 'gorilla', name: '거대 로랜드고릴라', josa: '가', scale: 3, hp: 5200, dmgMul: 1, kong: true },
};
/* money for one kill of a kind: animals and robots carry their own price, people and zombies 1,000 */
function unitPay(type) { return ANIMALS[type] ? ANIMALS[type].money : typeof ROBOTS !== 'undefined' && ROBOTS[type] ? ROBOTS[type].money : 1000; }
const Game = {
  stage: 1, goal: 100, kills: 0, built: 0, info: null, spawnT: 0, infected: false, infectT: 0, antidotes: 0, ended: false, result: null,
  bonusGuns: [], deployed: false, replay: false,
  begin(stage) {
    this.stage = stage; const S = STAGES[stage];
    Enemies.clear(); Proj.clear(); Rockets.clear(); ShipFX.clear(); Loot.clear(); FX.clear(); HUD.reset(); Car.reset(); Kong.reset();
    this.info = buildStage(stage); this.built = stage; TacMap.build(stage, this.info);
    this.bonusGuns = []; this.deployed = false; this.replay = save.cleared.includes(stage);
    resetGuns();
    Object.assign(stats, { shots: 0, hits: 0, kills: 0, heads: 0, earned: 0, time: 0 });
    moneyLock = save.money; ivoryLock = save.items.ivory; ownLock = save.owned.slice();
    Object.assign(player, { hp: 1000, maxHp: 1000, yaw: this.info.start.yaw, pitch: 0, recoilPitch: 0, shake: 0, landDip: 0, grounded: true, sprintBlend: 0, invuln: 1.5, sinceHurt: 10 });
    player.pos.set(this.info.start.x, 0, this.info.start.z); player.vel.set(0, 0, 0);
    camera.fov = baseFov; camera.updateProjectionMatrix(); FX.resize();
    // 1-2 crowds the middle of the docks, so unless you pick somewhere else you come down at the south edge, facing in
    if (stage === 5) { const d = this.openSpot(0, 58); if (d) { this.info.start = d; player.pos.set(d.x, 0, d.z); player.yaw = d.yaw; } }
    this.goal = S.goal; this.kills = 0; this.spawnT = 2; this.infected = false; this.infectT = 0; this.ended = false; this.chestWait = false; this.chestOk = false; this.chestT = 0; this.sp = null;
    this.antidotes = stage === 2 ? 1 : 0; this.poisonT = 0; this.poisonAcc = 0; player.stunT = 0; Inject.cancel(); jetEnd(); HUD.items();
    this.calm = 0; Bleed.stop(true); Fear.t = 0; Toss.on = false; Toss.v = 0; Ride.reset(); Beast.reset();
    document.body.classList.toggle('s2', stage === 2);
    this.populate(stage);
    // 1-2 lets you choose where to be put down; the last choice is kept for another go (enemies stay where they always are)
    if (stage === 5 && this.dropPick) this.setDrop(this.dropPick);
    Gfx.stage(stage);
    const B = BOSS[stage], pay = B ? 20 * unitPay(B.type) : 0;
    this.bossMsg = B ? '보스 ' + B.name + B.josa + (Lab.active ? ' 10번 우리에 있습니다' : ' 어딘가에 있습니다') + (this.replay ? ' · 다시 하기라 보상은 없습니다' : ' · ' + won(pay))
      : '감시탑 체력 10,000 · 5분 뒤 모든 동물이 탑으로 몰려옵니다' + (this.replay ? ' · 다시 하기라 보상은 없습니다' : '');
    if (stage === 7) Safari.begin();
    updateFlow(player.pos.x, player.pos.z);
  },
  /* the nearest open ground to a point on the map: room to land, not on a container, inside the fence; you face the middle of the docks */
  pickDrop(x, z) {
    const d = this.openSpot(x, z); if (!d) return null;
    this.dropPick = d; this.setDrop(d); return d;
  },
  openSpot(x, z) {
    for (let rr = 0; rr <= 9; rr += 0.5) for (let i = 0, n = rr ? Math.max(8, Math.round(rr * 6)) : 1; i < n; i++) {
      const a = (i / n) * TAU, px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr;
      if (Math.abs(px) > HALF - 4 || Math.abs(pz) > HALF - 4 || collideAt(px, 0.05, pz, 1.1, 2) || groundAt(px, 0.3, pz, 0.5) > 0.1) continue;
      return { x: px, z: pz, yaw: Math.hypot(px, pz) > 3 ? Math.atan2(px, pz) : 0 };
    }
    return null;
  },
  setDrop(d) { this.info.start = { x: d.x, z: d.z, yaw: d.yaw }; player.pos.set(d.x, 0, d.z); player.yaw = d.yaw; player.pitch = 0; updateFlow(d.x, d.z); },
  /* every stage starts with exactly 100 enemies already in place, one of them the boss; nobody else ever shows up */
  populate(stage) {
    // the same stage always puts the same enemies in the same places
    const SR = mulberry(5150 + stage * 101), rand = (a, b) => a + SR() * (b - a), randi = (a, b) => Math.floor(rand(a, b + 1));
    const S = STAGES[stage], st = this.info.start, placed = [], B = BOSS[stage];
    const ok = (x, z, minStart, gap, rad) => {
      if (Math.abs(x) > HALF - 4 || Math.abs(z) > HALF - 4 || Math.hypot(x - st.x, z - st.z) < minStart || collideAt(x, 0, z, rad, 2)) return false;
      for (const p of placed) if (Math.hypot(p.x - x, p.z - z) < gap) return false;
      return true;
    };
    const find = (minStart, gap, rad, near, spread) => {
      for (let k = 0; k < 300; k++) {
        const x = near ? near.x + rand(-spread, spread) : rand(-HALF + 6, HALF - 6), z = near ? near.z + rand(-spread, spread) : rand(-HALF + 6, HALF - 6);
        if (ok(x, z, minStart, gap, rad)) { const p = { x, z }; placed.push(p); return p; }
      }
      return null;
    };
    let n = 0;
    const cap = stage === 3 || stage === 8 ? 140 : 100;
    const put = (type, p, opts) => { if (p && n < cap) { const e = Enemies.spawn(type, p.x, p.z, Object.assign({ yaw: rand(0, TAU), y: p.y || 0 }, opts)); if (e) e.sid = n; n++; return e; } return null; };
    if (B && stage !== 3 && stage !== 8 && stage !== 4 && stage !== 5) put(B.type, find(55, 8, 2.5) || find(30, 4, 1.5), Object.assign({ boss: true }, B));
    if (stage === 5) {
      // 1-2: 5 snipers up on container stacks, 9 gold desert eagles, 10 suicide bombers, 3 flamethrowers, 12 rifles, 20 knives, 10 blue lightsabers,
      // 5 with a lightsaber in each hand, 10 grenade throwers, 15 aluminium bats, and the boss with a machine gun: 100 in all.
      // 70 of them, the boss among them, are packed into the middle nine blocks of the 5 x 5 grid; the other 30 are spread round the outside
      const IN = (x, z) => Math.abs(x) < 36 && Math.abs(z) < 33;
      const findR = (inside, minStart, gap, rad, near, spread) => {
        for (let k = 0; k < 400; k++) {
          const x = near ? near.x + rand(-spread, spread) : inside ? rand(-35, 35) : rand(-HALF + 6, HALF - 6);
          const z = near ? near.z + rand(-spread, spread) : inside ? rand(-32, 32) : rand(-HALF + 6, HALF - 6);
          if (IN(x, z) !== inside || !ok(x, z, minStart, gap, rad)) continue;
          const p = { x, z }; placed.push(p); return p;
        }
        return null;
      };
      let inner = 0;
      if (put(B.type, findR(true, 20, 8, 2.5) || find(30, 4, 1.5), Object.assign({ boss: true }, B))) inner++;
      const kits = [], ROSTER = [['sniper', 5], ['deagle', 9], ['bomber', 10], ['flame', 3], ['rifle', 12], ['dagger', 20], ['saber', 10], ['saber2', 5], ['nade', 10], ['bat', 15]];
      for (const [k, c] of ROSTER) for (let i = 0; i < c; i++) kits.push(k);
      for (let i = kits.length - 1; i > 0; i--) { const j = Math.floor(SR() * (i + 1)); [kits[i], kits[j]] = [kits[j], kits[i]]; }
      // the snipers on stacks in the middle, looking out over the rest
      const tops = colliders.filter((b) => b.kind === 'metal' && b.maxy > 2 && b.maxy < 9 && (b.maxx - b.minx) * (b.maxz - b.minz) > 10 && IN((b.minx + b.maxx) / 2, (b.minz + b.maxz) / 2));
      const snipers = kits.filter((k) => k === 'sniper').length; let left = kits.filter((k) => k !== 'sniper');
      for (let i = 0; i < snipers; i++) {
        let spot = null;
        for (let k = 0; k < 40 && tops.length && !spot; k++) { const b = tops.splice(Math.floor(SR() * tops.length), 1)[0]; const q = { x: (b.minx + b.maxx) / 2, z: (b.minz + b.maxz) / 2, y: b.maxy };
          if (placed.every((o) => Math.hypot(o.x - q.x, o.z - q.z) > 6)) spot = q; }
        if (spot) { placed.push(spot); if (put('thug', spot, { kit: 'sniper' })) inner++; } else left.push('sniper');
      }
      // posts of 2-5 in the middle until it holds 70, then posts of 2-3 outside for the rest
      for (let guard = 0; inner < 70 && left.length && guard < 200; guard++) {
        const center = findR(true, 20, 4.5, 0.8); if (!center) break;
        if (put('thug', center, { kit: left.shift() })) inner++;
        for (let i = 1, grp = randi(2, 5); i < grp && left.length && inner < 70; i++) { if (put('thug', findR(true, 18, 1.6, 0.6, center, 5), { kit: left[0] })) { left.shift(); inner++; } }
      }
      for (let guard = 0; n < 100 && left.length && guard < 200; guard++) {
        const center = findR(false, 26, 5, 0.8); if (!center) break;
        put('thug', center, { kit: left.shift() });
        for (let i = 1, grp = randi(2, 3); i < grp && left.length; i++) { if (put('thug', findR(false, 24, 1.6, 0.6, center, 5), { kit: left[0] })) left.shift(); }
      }
    } else if (stage === 4) {
      populateShip(this, put, find, rand, randi, SR, placed);
    } else if (stage === 3 || stage === 8) {
      populateLab(this, put, SR);
    } else if (stage === 7) {
      populateSafari(this, put, find, rand, randi);
    } else {
      // guard posts of 2-4 people, or packs of 2-6 zombies
      const yard = isYard(stage), helmet = stage === 6;
      while (n < 100) {
        const center = find(yard ? 36 : 22, 5, 0.8); if (!center) break;
        put(S.enemy, center, { helmet });
        for (let i = 1, grp = yard ? randi(2, 4) : randi(2, 6); i < grp; i++) put(S.enemy, find(yard ? 33 : 20, 1.6, 0.6, center, 5), { helmet });
      }
    }
    if (stage !== 3 && stage !== 8 && stage !== 4 && stage !== 7) while (n < 100) { const p = find(18, 1.2, 0.6); if (!p) break; put(stage === 4 ? 'trooper' : S.enemy, p, { helmet: stage === 6, kit: stage === 5 ? 'rifle' : undefined }); }
    this.goal = Enemies.list.length; this.spawned = n;
    this.boss = Enemies.list.find((e) => e.boss) || null;
    this.mid = Enemies.list.find((e) => e.T && e.T.mid) || null; // the gold commander drone
  },
  update(dt) {
    if (this.ended) return;
    if (this.chestWait && !Loot.pending() && (this.chestT += dt) > 2.4) { this.chestWait = false; this.chestOk = true; this.finish(); return; } // opened: give its banner a moment, then out
    Lab.update(dt); Safari.update(dt); Bleed.update(dt); Beast.roarCd -= dt;
    // the countdown holds while the needle is in
    if (this.infected && !Inject.active) { this.infectT -= dt; if (this.infectT <= 0) { this.infectT = 0; this.over('zombie'); } }
    // poison counts down like a bite, and like a bite it holds while the needle is in
    if (this.poisonT > 0 && !Inject.active) { this.poisonT = Math.max(0, this.poisonT - dt); if (this.poisonT <= 0) this.over('poison'); }
  },
  /* a charge that connects knocks you out: the enraged zombie boss for 2 s, the giant gorilla for 3 s (300 damage), its minions for 1 s */
  stun(e, dmg, secs) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    secs = secs || 2;
    player.hurt(dmg === undefined ? 90 * (e.dmgMul || 1) : dmg, e.pos, 'body');
    if (this.ended) return;
    player.stunT = Math.max(player.stunT, secs); Gun.trigger = false; Gun.adsHeld = false; Gun.reloadT = 0;
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    player.vel.x += dx / d * 11; player.vel.z += dz / d * 11;
    player.shake = Math.max(player.shake, 0.6); Sound.ring(); buzz(220);
    HUD.feed('돌진에 맞아 기절 · ' + secs + '초', 0, 'hs');
  },
  /* the boss drone's laser: touching the beam is the end */
  laser(e) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    player.hp = 0; Sound.hurt(); HUD.hurt(999, e.pos); this.over('laser');
  },
  /* the giant gorilla's leap: coming down on you is the end */
  slam(e) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    player.hp = 0; Sound.hurt(); HUD.hurt(999, e.pos); this.over('slam');
  },
  /* stage 2 has no health: a zombie's dash poisons, and the poison kills in 8 seconds unless an antidote goes in, just like a bite */
  poison(e) {
    if (state !== 'playing' || this.ended || godMode()) return;
    Sound.bite(); buzz(120); HUD.hurt(30, e.pos); player.shake = Math.max(player.shake, 0.35);
    if (this.poisonT > 0) { this.poisonT = Math.max(0.6, this.poisonT - 1.5); HUD.feed('또 중독 · 남은 시간이 줄었습니다', 0, 'hs'); return; }
    this.poisonT = 8;
    HUD.feed('중독 · 8초 안에 해독약을 주사하세요', 0, 'hs');
  },
  cure() {
    const inf = this.infected, poi = this.poisonT > 0;
    this.infected = false; this.infectT = 0; this.poisonT = 0; this.poisonAcc = 0;
    HUD.feed('해독 완료 · ' + (inf && poi ? '감염과 중독' : inf ? '감염' : '중독') + ' 치료', 0);
  },
  /* the boss's treasure chest: a gun you do not own yet (a rented one can come out too), yours for good once you get out alive,
     and full ammo for everything. owning every gun already, it is just the ammo */
  openChest() {
    const pool = ORDER.filter((id) => id !== 'pistol' && !save.owned.includes(id));
    Gun.slots.forEach((g) => { wstate[g].mag = WEAPONS[g].mag; wstate[g].reserve = WEAPONS[g].reserve; });
    if (!pool.length) { Sound.pickup('ammo'); HUD.banner('보물상자', '모든 총을 이미 가지고 있습니다 · 모든 총 탄약 가득', 3.2); HUD.feed('보물상자 · 탄약 보충', 0); return; }
    const id = pick(pool), w = WEAPONS[id];
    save.owned.push(id); persist();
    if (!save.loadout.includes(id)) { const slot = Loadout.place(id); if (!slot) { const i = save.loadout.length - 1; save.loadout[i] = id; persist(); } }
    gainGun(id); switchTo(id); Sound.buy(); Sound.pickup('ammo');
    HUD.banner('보물상자 · ' + w.name, w.model + ' ' + w.name + ' 획득 · 이제 영구히 내 총입니다(살아서 나가면) · 모든 총 탄약 가득', 3.6);
    HUD.feed('보물상자 · ' + w.name + ' 영구 소유 · 탄약 보충', 0);
  },
  /* an animal you have ridden is tamed: it never fights you again and counts as dealt with, like a kill (but pays nothing) */
  calm: 0,
  tame(e) {
    this.calm++;
    HUD.feed(e.T.name + ' 길들임 · 처치한 것으로 칩니다', 0);
    if (this.kills + this.calm >= this.goal) this.finish();
  },
  onKill(e, weak) {
    if (this.ended) return;
    if (e.extra) return; // a mine the boss threw out: not one of the hundred, no money
    this.kills++; stats.kills++; if (weak) stats.heads++;
    if (e.tamed) this.calm = Math.max(0, this.calm - 1); // it was already counted
    const base = e.minion ? 1000 : e.animal || e.robot ? e.T.money : 1000;
    // a kill with a shot to the head pays 1.5 times; so does a zombie finished off before it ever got back up (the two multiply).
    // a stage you have already cleared can be played again, but pays nothing; a bomber who blows himself up pays nothing either
    const fresh = e.type === 'zombie' && !e.revived;
    const pay = this.replay || e.selfDet || e.noPay ? 0 : Math.round((e.boss ? base * 20 : e.T && e.T.mid ? base * 10 : base) * (weak ? 1.5 : 1) * (fresh ? 1.5 : 1)); // noPay: your mount, killed by the others; a mid-boss pays ten times
    save.money += pay; stats.earned += pay; persist();
    // on a phone the kill lines and the +money pop are left out: the bag total at the top still counts up
    Sound.kill(); if (pay) { Sound.coin(); if (!isTouch) HUD.moneyPop(pay); }
    if (e.boss) {
      if (!isTouch) HUD.feed('보스 ' + e.name + ' 처치', pay, 'hs'); HUD.banner('보스 처치' + (pay ? ' · +' + won(pay) : ''), '보물상자가 떨어졌습니다', 3);
      // the chest comes down where the boss fell, unless that is up on something: then on the nearest open floor, where you can walk to it
      let cx = e.pos.x, cz = e.pos.z, cy = e.kong ? 0 : e.pos.y; const gy = groundAt(cx, cy + 0.6, cz, 0.6);
      if (gy > 1.0) { const d = this.openSpot(cx, cz); if (d) { cx = d.x; cz = d.z; cy = 0; } }
      Loot.chest(cx, cz, cy); this.boss = null; if (e.kong) Kong.unwarn();
      if (Lab.active) Lab.monkeyMode('panic');
      if (e.type === 'bdrone') { ShipFX.aimOff(); for (const m of Enemies.list.slice()) if (m.extra) Enemies.vanish(m); Ship.onDown(e); } // its leftover mines go dead with it; the hall door opens
    } else if (e.T && e.T.mid) {
      if (!isTouch) HUD.feed('중간 보스 ' + e.name + ' 처치', pay, 'hs'); HUD.banner('중간 보스 처치' + (pay ? ' · +' + won(pay) : ''), '운전실을 장악했습니다', 2.4);
      // the drones it called fall with it (they count, but pay nothing), the bridge door opens, and this is the save point
      let fell = 0; for (const m of Enemies.list.slice()) if (m.alive && m.fromBee) { m.noPay = true; m.beeFall = true; Enemies.damage(m, 1e6, m.pos, { x: 0, y: -1, z: 0 }, false, true); fell++; }
      if (fell) HUD.feed('불러낸 드론 ' + fell + '대도 함께 떨어졌습니다', 0);
      if (World.style.ship) Ship.onDown(e); // the save point comes when you pull the key out (Ship.takeKey)
    }
    else if (e.selfDet) HUD.feed(e.T && e.T.mode === 'mine' ? '스파이더 마인이 터졌습니다' : '자폭맨이 터졌습니다', 0, 'hs');
    else if (e.beeFall) { /* counted in one line above */ }
    else if (e.noPay) HUD.feed('타고 있던 ' + e.T.name + (hasBatchim(e.T.name) ? '이' : '가') + ' 쓰러졌습니다', 0, 'hs');
    else if (!isTouch) HUD.feed((e.animal ? e.T.name : STAGES[this.stage].label) + (weak ? ' · 머리 명중' : ' 처치'), pay, weak ? 'hs' : '');
    // an elephant leaves its tusks: ivory, which the shop buys for a lot (not on a replay, like the money)
    if (e.type === 'elephant' && pay > 0) { save.items.ivory = Math.min(63, (save.items.ivory | 0) + 1); persist(); HUD.items(); HUD.banner('상아 획득', '상점에서 ' + won(IVORY_PRICE) + '에 팔 수 있습니다', 2.6); }
    const left = this.goal - this.kills - this.calm, S = STAGES[this.stage];
    if (!e.boss && (left === 50 || left === 25 || left === 10)) HUD.banner(left + S.unit + ' 남음', left === 10 && this.stage !== 4 ? '화살표가 남은 적 쪽을 가리킵니다' : '가방 ' + won(save.money), 1.8);
    if (this.kills + this.calm >= this.goal) this.finish();
  },
  /* a broken crate: a health potion (10% of max health); in the zombie village, where there is no health, always an antidote instead */
  onCrate(c) { Loot.drop(this.stage === 2 ? 'anti' : 'hp', c.x, c.z, c.y || 0); },
  takeLoot(kind) {
    if (kind === 'anti') return this.takeAntidote();
    if (kind === 'hp') {
      if (player.hp >= player.maxHp && !Bleed.n) return false;
      const heal = Math.min(Math.round(player.maxHp * 0.1), player.maxHp - player.hp); player.hp += heal;
      const stopped = Bleed.n > 0; Bleed.stop(); // the potion also stops bleeding
      Sound.pickup('hp'); HUD.feed('회복 물약 · 체력 +' + Math.round(heal) + ' (최대 체력의 10%)' + (stopped ? ' · 출혈 멎음' : ''), 0); return true;
    }
    const id = WEAPONS[Gun.cur].reserve !== Infinity ? Gun.cur : Gun.slots.find((g) => WEAPONS[g].reserve !== Infinity);
    if (!id || ammoRoom(id) < 1) return false;
    wstate[id].reserve += ammoPack(id); Sound.pickup('ammo'); HUD.feed((WEAPONS[id].rocket ? '로켓 +1 · ' : '총알 +100 · ') + WEAPONS[id].name, 0); return true;
  },
  bitten(e) {
    if (state !== 'playing' || this.ended || godMode()) return;
    player.shake = Math.max(player.shake, 0.35); HUD.hurt(30, e.pos); buzz(90);
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    player.vel.x += dx / d * 6; player.vel.z += dz / d * 6;
    Sound.bite();
    if (this.infected) { this.infectT = Math.max(0.6, this.infectT - 1); return; }
    this.infected = true; this.infectT = 5;
    HUD.feed('좀비에게 물렸습니다 · 5초', 0, 'hs');
  },
  /* the antidote is a syringe: a moment to inject (no shooting), then infection and poison are gone */
  useAntidote() {
    if (state !== 'playing' || Inject.active || player.stunT > 0) return;
    if (!this.infected && this.poisonT <= 0) { if (this.stage === 2) HUD.hint('감염되지도 중독되지도 않았습니다 · 해독약 ' + this.antidotes + '개', 1.2); return; }
    if (this.antidotes <= 0) { HUD.hint('해독약이 없습니다 · 상자를 부수세요', 1.4); return; }
    this.antidotes--; Inject.start();
  },
  takeAntidote() {
    if (this.antidotes >= 5) return false;
    this.antidotes++; Sound.pickup('hp'); HUD.feed('해독약 획득 · ' + this.antidotes + '개', 0); return true;
  },
  /* rented guns and the chest's gun go back when a stage you went into ends, however it ends */
  returnRentals() { if (!this.deployed) return; this.deployed = false; save.rented = []; this.bonusGuns = []; persist(); },
  /* 5.13: the last one down while the boss's chest is still lying there (or the boss was the last): no pick-up until it is opened.
     you can't be hurt any more, an arrow points at the chest, and the way out comes a moment after you open it */
  waitChest() {
    if (this.chestWait) return;
    this.chestWait = true; this.chestT = 0; player.invuln = 1e9; Bleed.stop(true); Fear.t = 0; this.infected = false; this.infectT = 0; this.poisonT = 0;
    const how = World.style.lab ? '출입문이 열립니다' : World.style.ship ? '에어록으로 빠져나갑니다' : '헬기가 옵니다';
    HUD.banner('보물상자를 챙기세요', '화살표를 따라가 보물상자를 열면 ' + how, 3.4);
    HUD.feed('모두 처치 · 보물상자를 열어야 탈출합니다', 0, 'hs');
  },
  finish() {
    if (!this.chestOk && Loot.pending()) { this.waitChest(); return; }
    this.ended = true; player.invuln = 1e9; moneyLock = null; ivoryLock = null; ownLock = null;
    if (Ride.m) Ride.off(true); Bleed.stop(true); Fear.t = 0;
    if (Toss.on) { Toss.on = false; player.pos.y = groundAt(player.pos.x, player.pos.y, player.pos.z, player.r); player.vel.y = 0; }
    // still in the air when the last one falls: come down for the pick-up
    if (Jet.on) { jetEnd(); player.pos.y = groundAt(player.pos.x, player.pos.y, player.pos.z, player.r); player.vel.y = 0; }
    this.opened = settings.dev ? [] : (NEXT[this.stage] || []).filter((s) => !stageOpen(s)); this.sp = null;
    if (!save.cleared.includes(this.stage)) save.cleared.push(this.stage);
    this.returnRentals();
    const key = 't' + this.stage, t = Math.floor(stats.time);
    if (!save.best[key] || t < save.best[key]) save.best[key] = t;
    persist(); Sound.clear();
    HUD.banner('스테이지 ' + stageTag(this.stage) + ' 클리어', (World.style.lab ? '출입문이 열립니다 · ' : World.style.ship ? '에어록으로 빠져나갑니다 · ' : '헬기가 데리러 옵니다 · ') + (this.replay ? '다시 하기라 보상 없음' : '가방 ' + won(save.money)), 2.5);
    setTimeout(() => {
      if (state === 'playing') { state = 'cutscene'; Gun.trigger = false; Gun.adsHeld = false; Cut.startOutro(() => showResult('clear')); }
      else showResult('clear');
    }, 1700);
  },
  /* stage 4's save point (5.13), taken the moment the gold bee falls: who is dead by then, the kills and the bag, your ammo, the crates
     you have broken and whether you hold the key. dying after it, '다시 하기' puts you back on the bridge with all of that as it was */
  takeSave() {
    const alive = new Set(); for (const e of Enemies.list) if (e.alive && e.sid !== undefined) alive.add(e.sid);
    const dead = []; for (let i = 0; i < this.spawned; i++) if (!alive.has(i)) dead.push(i);
    this.sp = { stage: this.stage, dead, kills: this.kills, goal: this.goal, money: save.money, money0: moneyLock, stats: Object.assign({}, stats),
      ammo: ORDER.map((id) => [id, wstate[id].mag, wstate[id].reserve]), cur: Gun.cur, key: Ship.key, crates: crates.filter((c) => c.dead).map((c) => c.idx) };
  },
  fromSave() {
    const sp = this.sp; if (!sp) { startStage(this.stage); return; }
    $('over').hidden = true;
    this.begin(sp.stage); this.sp = sp; this.deployed = true; this.bossMsg = null;
    const dead = new Set(sp.dead);
    for (const e of Enemies.list.slice()) if (e.sid !== undefined && dead.has(e.sid)) { Enemies.vanish(e); }
    Enemies.updateDying(10); // gone at once, no puffs hanging about
    let broke = false; for (const c of crates) if (!c.dead && sp.crates.includes(c.idx)) { c.dead = true; _crateZero.makeScale(0, 0, 0); World.crateIM.setMatrixAt(c.idx, _crateZero); World.crateIM.instanceMatrix.needsUpdate = true; removeCollider(c.b); broke = true; }
    if (broke) buildNav();
    this.kills = sp.kills; this.goal = sp.goal; Object.assign(stats, sp.stats);
    save.money = sp.money; moneyLock = sp.money0; persist();
    for (const [id, m, r] of sp.ammo) { wstate[id].mag = m; wstate[id].reserve = r; }
    if (Gun.slots.includes(sp.cur)) switchTo(sp.cur);
    this.boss = Enemies.list.find((e) => e.boss) || null; this.mid = null;
    Ship.restore(sp);
    player.pos.set(SHIP_SAVE.x, 0, SHIP_SAVE.z); player.vel.set(0, 0, 0); player.yaw = SHIP_SAVE.yaw; player.pitch = 0; player.hp = player.maxHp;
    updateFlow(player.pos.x, player.pos.z);
    enterPlay(false);
    HUD.banner('세이브 포인트', '운전실에서 다시 시작합니다 · 처치 ' + this.kills + ' / ' + this.goal + ' · 가방 ' + won(save.money), 2.8);
  },
  /* not getting out means not keeping what you earned in there */
  forfeit() {
    if (ownLock !== null) { const keep = ownLock; save.owned = save.owned.filter((id) => keep.includes(id)); ownLock = null; persist(); } // a chest gun is only yours once you are out
    if (ivoryLock !== null) { save.items.ivory = Math.max(0, Math.min(save.items.ivory, ivoryLock)); ivoryLock = null; persist(); }
    if (moneyLock !== null) { save.money = Math.max(0, Math.min(save.money, moneyLock)); moneyLock = null; persist(); }
  },
  over(reason) {
    if (this.ended) return;
    if (godMode()) { this.infected = false; this.infectT = 0; this.poisonT = 0; player.hp = Math.max(player.hp, 1); return; } // invincible: whatever it was, you live
    this.ended = true; state = 'gameover'; Gun.trigger = false; Gun.adsHeld = false; this.forfeit(); if (!this.sp) this.returnRentals(); jetEnd(); Ride.reset(); Toss.on = false;
    if (document.pointerLockElement) document.exitPointerLock();
    $('touch').hidden = true; player.shake = 0.4;
    setTimeout(() => showResult(reason), 1000);
  },
};

/* ---------- screens ---------- */
const fmtTime = (t) => Math.floor(t / 60) + ':' + String(Math.floor(t) % 60).padStart(2, '0');
function refreshMenu() {
  $('bagmoney').textContent = won(save.money);
  const dev = !!settings.dev;
  const NOTE = { 1: '밀수 조직원 100명 · 총소리를 들으면 몰려옵니다', 6: '오토바이 헬멧 쓴 조직원 100명 · 헬멧은 헤드샷 한 번에 벗겨짐', 5: '단검 20 · 파란 광선검 10 · 쌍광선검 · 야구방망이 · 자폭맨 · 저격 · 보스는 기관총 · 내릴 곳을 고름',
    2: '불타는 오두막 마을 · 좀비 100마리 · 체력 없이 감염과 중독만', 7: '넓은 사파리 · 5분 뒤 동물 100마리가 가운데 감시탑으로 습격 · 탑 체력 10,000', 8: '우리를 하나씩 · 앞 우리 동물을 다 잡아야 원숭이 박사가 다음 우리를 엶 · 모든 우리 방탄유리', 3: '우리 10개가 차례로 열리는 연구소 · 얼룩말·기린·코끼리를 타고 싸움 · 보스 고릴라는 방탄유리 우리에', 4: '우주선 복도 · 운전실의 황금 드론 · 메인홀의 3페이즈 보스 드론 · 숨은 스파이더 마인' };
  STAGE_ORDER.forEach((s) => {
    const open = stageOpen(s), done = save.cleared.includes(s), btn = $('st' + s + 'btn'), pre = stageTag(PREREQ[s]), best = save.best['t' + s];
    btn.disabled = !open; btn.classList.toggle('done', done);
    $('st' + s + 'note').textContent = open ? NOTE[s] + (done ? ' · 다시 하면 보상 없음' + (best ? ' · 최단 ' + fmtTime(best) : '') : '') : '스테이지 ' + pre + eul(pre) + ' 깨면 열립니다';
    $('st' + s + 'stat').textContent = !open ? '잠김' : done ? '클리어' + (best ? ' ' + fmtTime(best) : '') : '도전 가능';
  });
  $('devbtn').textContent = dev ? '개발자 모드 켜짐' : '개발자 모드'; codexButtons(); godButtons();
  $('devbtn').classList.toggle('on', dev); document.body.classList.toggle('devmode', dev);
  $('lobtn').textContent = '무기 편성 · ' + save.loadout.filter((id) => id && gunAvailable(id)).length + '자루';
  $('shopbtn').textContent = save.rented.length ? '상점 · ' + save.rented.length + '자루 대여 중' : '상점';
  const bt = STAGE_ORDER.map((n) => save.best['t' + n] ? stageTag(n) + ' ' + fmtTime(save.best['t' + n]) : '').filter(Boolean);
  $('bestline').textContent = bt.length ? '최단 클리어 ' + bt.join(' · ') : '';
}
const CH_COLORS = { white: '#ece6d8', green: '#3dff6a', red: '#ff4b4b', yellow: '#ffe23a', cyan: '#3ad8ff', pink: '#ff5ad2', orange: '#ff9a2a' };
function syncSettingsUI() {
  ['', '2'].forEach((sfx) => {
    $('sens' + sfx).value = settings.sens; $('sensout' + sfx).textContent = Number(settings.sens).toFixed(1);
    $('vol' + sfx).value = settings.vol; $('volout' + sfx).textContent = Math.round(settings.vol * 100);
    $('autofire' + sfx).checked = !!settings.autoFire;
    $('gfx' + sfx).value = settings.gfx; $('fps' + sfx).checked = !!settings.fps;
    $('chsel' + sfx).value = settings.cross || 'cross';
    $('chcol' + sfx).value = CH_COLORS[settings.chcol] ? settings.chcol : 'white';
  });
  document.body.dataset.ch = settings.cross || 'cross';
  // the crosshair colour: white is the old ink colour; any other colour also takes over the red aiming dot
  const cc = CH_COLORS[settings.chcol] ? settings.chcol : 'white', bs = document.body.style;
  if (cc === 'white') { bs.removeProperty('--ch'); bs.removeProperty('--chads'); } else { bs.setProperty('--ch', CH_COLORS[cc]); bs.setProperty('--chads', CH_COLORS[cc]); }
}
['', '2'].forEach((sfx) => {
  $('sens' + sfx).addEventListener('input', (e) => { settings.sens = parseFloat(e.target.value); syncSettingsUI(); store('yard07.settings', settings); });
  $('vol' + sfx).addEventListener('input', (e) => { settings.vol = parseFloat(e.target.value); Sound.setVol(settings.vol); syncSettingsUI(); store('yard07.settings', settings); });
  $('autofire' + sfx).addEventListener('change', (e) => { settings.autoFire = e.target.checked; syncSettingsUI(); store('yard07.settings', settings); });
  $('gfx' + sfx).addEventListener('change', (e) => { settings.gfx = e.target.value; Gfx.mode(); syncSettingsUI(); store('yard07.settings', settings); });
  $('fps' + sfx).addEventListener('change', (e) => { settings.fps = e.target.checked; Perf.show(settings.fps); syncSettingsUI(); store('yard07.settings', settings); });
  $('chsel' + sfx).addEventListener('change', (e) => { settings.cross = e.target.value; syncSettingsUI(); store('yard07.settings', settings); });
  $('chcol' + sfx).addEventListener('change', (e) => { settings.chcol = e.target.value; syncSettingsUI(); store('yard07.settings', settings); });
});
let wentFullscreen = false;
function tryFullscreen() {
  if (!isTouch || isApp || document.fullscreenElement) return;
  try {
    const el = document.documentElement, p = el.requestFullscreen ? el.requestFullscreen({ navigationUI: 'hide' }) : null;
    if (p && p.then) p.then(() => {
      wentFullscreen = true;
      try { const o = screen.orientation && screen.orientation.lock ? screen.orientation.lock(window.innerHeight > window.innerWidth ? 'portrait' : 'landscape') : null; if (o && o.catch) o.catch(() => {}); } catch (e) {}
    }).catch(() => {});
  } catch (e) {}
}
document.addEventListener('fullscreenchange', () => { if (!document.fullscreenElement && wentFullscreen) { wentFullscreen = false; if (state === 'playing') pauseGame(); } });
function enterPlay(intro) {
  Sound.init(); Sound.setVol(settings.vol); tryFullscreen();
  ['menu', 'over', 'pause', 'shop'].forEach((id) => { $(id).hidden = true; });
  requestLock();
  const go = () => {
    $('hud').hidden = false; if (isTouch) $('touch').hidden = false;
    state = 'playing'; player.invuln = Math.max(player.invuln, 1.5);
    if (Game.bossMsg) { HUD.feed(Game.bossMsg, 0, 'hs'); Game.bossMsg = null; }
    HUD.hint(Lab.active ? '1번 우리가 10초 뒤에 열립니다 · 창살 사이로 쏠 수 있습니다' : lookMode === 'drag' ? '마우스 이동으로 조준 · Q/E로 회전 · M 키로 지도' : lookMode === 'touch' ? '오른쪽 위 지도 버튼으로 적 위치를 볼 수 있습니다' : 'M 키로 작전 지도를 볼 수 있습니다', 3.5);
  };
  if (intro) { state = 'cutscene'; Cut.startIntro(Game.stage, go); } else go();
}
/* back into play after the short look through a ship door; if the mouse lock went with it, the pause screen gets it back with a click */
function backToPlay() {
  $('hud').hidden = false; if (isTouch) $('touch').hidden = false;
  state = 'playing'; player.invuln = Math.max(player.invuln, 1); keys.clear();
  if (lookMode === 'lock' && !locked) pauseGame();
}
function startStage(n) { if (!n || !stageOpen(n)) return; Game.begin(n); showBrief(); }
/* before the drop: the stage from above with every enemy, the boss, the drop point and the way you'll face */
function showBrief() {
  state = 'brief';
  if (document.pointerLockElement) document.exitPointerLock(); // the map and buttons need the pointer back
  showOnly('brief');
  $('hud').hidden = true; $('touch').hidden = true;
  $('briefcode').textContent = '스테이지 ' + stageTag(Game.stage); $('brieftitle').textContent = STAGES[Game.stage].name;
  $('briefnote').textContent = (Lab.active ? (Lab.seq ? '우리 10개 · 12마리씩(기린 3, 코끼리 2), 마지막 우리에 보스 · 5초 뒤 1번이 열리고, 그 뒤로는 앞 우리의 동물을 모두 잡거나 길들여야 원숭이 박사가 손을 뻗어 다음 우리를 엽니다 · 모든 우리가 방탄유리라 열리기 전엔 맞힐 수 없습니다 · '
      : '우리 10개 · 12마리씩(기린 3, 코끼리 2), 마지막 우리에 보스 · 10초 뒤 1번, 그 뒤 15초마다 하나씩 열립니다 · 보스 우리는 방탄유리 · ') + '얼룩말 → 기린 → 코끼리 순서로 올라탈 수 있고, 한 번 길들인 동물은 바로 다시 탈 수 있습니다 · ' : '') +
    (Game.stage === 7 ? '5분 동안은 동물들이 흩어져 지냅니다(가까이 가거나 쏘면 덤빔) · 5분이 지나면 모두 가운데 감시탑으로 몰려옵니다 · 탑 위에 있으면 기린 말고는 탑부터 공격합니다 · 얼룩말은 와도 공격하지 않습니다 · ' : '') +
    (Game.stage === 7 ? '동물 ' + Game.goal + '마리 · 감시탑 체력 10,000' : '적 ' + Game.goal + (STAGES[Game.stage].unit) + ' · 보스 1') + ' · 나무 상자 ' + crates.length + '개' + (Game.stage === 2 ? ' (모두 해독약)' : '') + (Game.replay ? ' · 깬 스테이지라 이번에는 돈을 받지 않습니다' : '');
  $('briefnote').classList.toggle('warn', Game.replay);
  $('briefmap').classList.toggle('pick', Game.stage === 5);
  if (Game.stage === 5) dropNote();
  TacMap.legend($('brieflegend'), false);
  briefGear();
  requestAnimationFrame(() => TacMap.draw($('briefmap')));
  setTimeout(() => $('deploybtn').focus(), 0);
}
/* 1-2: tap or click the briefing map to choose the drop point */
function dropNote(bad) {
  const s = Game.info.start; let near = Infinity; for (const e of Enemies.list) near = Math.min(near, Math.hypot(e.pos.x - s.x, e.pos.z - s.z));
  $('briefnote').textContent = (bad ? '그곳에는 내릴 수 없습니다 · ' : '지도를 눌러 내릴 곳을 고르세요 · ') + '가장 가까운 적 ' + Math.round(near) + 'm · 적 ' + Game.goal + '명 · 나무 상자 ' + crates.length + '개' + (Game.replay ? ' · 깬 스테이지라 돈은 받지 않습니다' : '');
  $('briefnote').classList.toggle('warn', !!bad || near < 15 || Game.replay);
}
$('briefmap').addEventListener('click', (ev) => {
  if (state !== 'brief' || Game.stage !== 5) return;
  const w = TacMap.toWorld($('briefmap'), ev.clientX, ev.clientY), d = Game.pickDrop(w.x, w.z);
  if (d) { Sound.init(); Sound.reload(1); } dropNote(!d);
  TacMap.draw($('briefmap'));
});
let mapFrom = null;
function openMap(from) {
  if (from === 'play' && state !== 'playing') return;
  mapFrom = from; state = 'paused'; Gun.trigger = false; keys.clear();
  if (document.pointerLockElement) document.exitPointerLock();
  $('pause').hidden = true; $('touch').hidden = true; $('mapscreen').hidden = false;
  $('mapcode').textContent = '스테이지 ' + stageTag(Game.stage) + ' · 처치 ' + Game.kills + ' / ' + Game.goal;
  $('mapkeyhint').textContent = lookMode === 'touch' ? '게임 중 오른쪽 위 지도 버튼으로 다시 열 수 있습니다' : 'M 키로 열고 닫기';
  TacMap.legend($('livelegend'), true);
  requestAnimationFrame(() => TacMap.draw($('livemap')));
  setTimeout(() => $('mapclose').focus(), 0);
}
function closeMap() {
  if ($('mapscreen').hidden) return;
  $('mapscreen').hidden = true;
  if (mapFrom === 'pause') { $('pause').hidden = false; } else resumeGame();
  mapFrom = null;
}
/* what you will carry: your layout, minus guns you have not rented */
function briefGear() {
  const lo = save.loadout.map((id, i) => (id && gunAvailable(id) ? (i + 1) + ' ' + WEAPONS[id].short : '')).filter(Boolean);
  $('briefgear').textContent = lo.length ? '무기 · ' + lo.join(' · ') : '무기가 없습니다 · 무기 편성에서 하나 이상 넣으세요';
  $('briefgear').classList.toggle('warn', !lo.length);
}
$('deploybtn').addEventListener('click', () => {
  resetGuns();
  if (Gun.none) { briefGear(); Loadout.open('brief'); Loadout.msg('무기를 하나 이상 넣어야 출동할 수 있습니다'); return; }
  Game.deployed = true; $('brief').hidden = true; enterPlay(true);
});
$('briefshop').addEventListener('click', () => Shop.open('brief'));
$('brieflobtn').addEventListener('click', () => Loadout.open('brief'));
$('plobtn').addEventListener('click', () => Loadout.open('pause'));
$('briefback').addEventListener('click', () => { Game.forfeit(); $('brief').hidden = true; toMenu(); });
$('mapclose').addEventListener('click', closeMap);
$('pmapbtn').addEventListener('click', () => openMap('pause'));
window.addEventListener('resize', () => { if (!$('brief').hidden) TacMap.draw($('briefmap')); if (!$('mapscreen').hidden) TacMap.draw($('livemap')); });
function showResult(kind) {
  state = 'gameover'; Gun.trigger = false; Gun.adsHeld = false;
  if (document.pointerLockElement) document.exitPointerLock();
  const S = STAGES[Game.stage], clear = kind === 'clear';
  Game.result = kind;
  $('stamp').textContent = clear ? '임무 완료' : kind === 'zombie' ? '감염' : kind === 'poison' ? '중독' : kind === 'bleed' ? '출혈' : kind === 'laser' ? '레이저' : '작전 실패';
  $('stamp').classList.toggle('ok', clear);
  $('overtitle').textContent = clear ? '스테이지 ' + stageTag(Game.stage) + ' 클리어' : kind === 'zombie' ? '좀비가 되었습니다' : kind === 'poison' ? '독이 퍼져 쓰러졌습니다' : kind === 'slam' ? '고릴라에게 짓눌렸습니다' : kind === 'bleed' ? '피를 너무 많이 흘렸습니다' : kind === 'laser' ? '보스 드론의 레이저에 맞았습니다' : '스테이지 ' + stageTag(Game.stage) + ' · 쓰러짐';
  $('st-kills').textContent = stats.kills + (Game.calm ? ' + 길들임 ' + Game.calm : '') + ' / ' + Game.goal; $('st-earn').textContent = won(stats.earned); $('st-hs').textContent = stats.heads;
  $('st-earn').classList.toggle('lost', !clear && stats.earned > 0); $('fade').style.opacity = '0';
  $('st-acc').textContent = (stats.shots ? Math.round(100 * stats.hits / stats.shots) : 0) + '%'; $('st-time').textContent = fmtTime(stats.time);
  $('overcode').textContent = '보고 번호 ' + isoCode('YRD', (Game.stage * 100000 + stats.kills * 997) % 1000000).text;
  const fromSP = !clear && !!Game.sp;
  $('againbtn').textContent = clear ? '다시 하기' : fromSP ? '세이브 포인트에서 다시' : '다시 도전';
  // after a clear: buttons for what it opens (stage 1 opens both 2 and 1-1)
  const nx = clear ? nextStages(Game.stage) : [], all = STAGE_ORDER.every((s) => save.cleared.includes(s));
  $('againbtn').className = nx.length ? 'ghost' : 'btn';
  ['nextbtn', 'nextbtn2'].forEach((id, i) => { const b = $(id), st = nx[i]; b.hidden = !st; if (st) { b.dataset.st = st; b.textContent = '스테이지 ' + stageTag(st) + euro(stageTag(st)); } });
  const opened = clear && Game.opened && Game.opened.length ? '새로 열림 · 스테이지 ' + Game.opened.map(stageTag).join(', ') + ' · ' : '';
  $('bestline2').textContent = (clear ? opened + (all ? '모든 스테이지를 깼습니다 · ' : World.style.lab ? '연구소를 빠져나와 번 돈을 챙겼습니다 · ' : '헬기로 탈출해 번 돈을 챙겼습니다 · ')
    : fromSP ? '세이브 포인트에서 다시 하면 그때까지의 처치 수(' + Game.sp.kills + ')와 번 돈(' + won(Game.sp.stats.earned) + ')이 그대로입니다 · ' : stats.earned > 0 ? '탈출하지 못해 이번에 번 ' + won(stats.earned) + '을 잃었습니다 · ' : '') + '가방 ' + won(save.money);
  $('hud').hidden = true; $('touch').hidden = true; $('over').hidden = false;
  setTimeout(() => ($('nextbtn').hidden ? $('againbtn') : $('nextbtn')).focus(), 0);
}
function pauseGame(msg) {
  if (state !== 'playing') return;
  state = 'paused'; Gun.trigger = false; keys.clear();
  $('pausecode').textContent = '스테이지 ' + stageTag(Game.stage) + ' · 처치 ' + Game.kills + ' / ' + Game.goal;
  $('pausemsg').textContent = msg || ''; codexButtons(); godButtons();
  $('pause').hidden = false; $('touch').hidden = true;
  setTimeout(() => $('resumebtn').focus(), 0);
}
function resumeGame() {
  if (state !== 'paused') return;
  Sound.init(); Sound.wake();
  $('pause').hidden = true; $('shop').hidden = true; $('pausemsg').textContent = '';
  if (isTouch) $('touch').hidden = false;
  state = 'playing'; requestLock();
}
function toMenu() {
  Game.returnRentals(); Game.sp = null; // leaving for the menu ends the run, save point and rentals with it
  state = 'menu'; jetEnd(); Ride.reset(); Bleed.stop(true); Fear.t = 0; Toss.on = false; Enemies.clear(); Proj.clear(); Rockets.clear(); ShipFX.clear(); Loot.clear(); Car.reset(); Game.infected = false;
  camera.fov = baseFov; camera.updateProjectionMatrix(); FX.resize();
  ['hud', 'touch', 'mapscreen'].forEach((id) => { $(id).hidden = true; });
  showOnly('menu'); refreshMenu();
}
STAGE_ORDER.forEach((s) => $('st' + s + 'btn').addEventListener('click', () => startStage(s)));
$('shopbtn').addEventListener('click', () => Shop.open('menu'));
$('pshopbtn').addEventListener('click', () => Shop.open('pause'));
$('oshopbtn').addEventListener('click', () => Shop.open('over'));
$('shopclose').addEventListener('click', () => Shop.close());
$('againbtn').addEventListener('click', () => { if (Game.result !== 'clear' && Game.sp) Game.fromSave(); else startStage(Game.stage); });
['nextbtn', 'nextbtn2'].forEach((id) => $(id).addEventListener('click', () => startStage(+$(id).dataset.st)));
$('resumebtn').addEventListener('click', resumeGame);
$('quitbtn').addEventListener('click', () => { Game.forfeit(); Game.returnRentals(); toMenu(); });
$('menubtn').addEventListener('click', toMenu);
/* hooks for the Android app shell: back button and app switching */
window.yardBack = () => {
  if (state === 'cutscene') { Cut.skip(); return true; }
  if (!$('mapscreen').hidden) { closeMap(); return true; }
  if (!$('dlg').hidden) { Dialog.close(); return true; }
  if (!$('codex').hidden) { Codex.close(); return true; }
  if (!$('custom').hidden) { Custom.close(); return true; }
  if (!$('shop').hidden) { Shop.close(); return true; }
  if (!$('loadout').hidden) { Loadout.close(); return true; }
  if (state === 'brief') { Game.forfeit(); $('brief').hidden = true; toMenu(); return true; }
  if (state === 'playing') { pauseGame(); return true; }
  if (state === 'paused') { resumeGame(); return true; }
  if (state === 'gameover') { toMenu(); return true; }
  return false;
};
window.yardPause = () => { if (state === 'playing') pauseGame(); Sound.suspend(); };

/* ---------- loop ---------- */
let last = performance.now(), flowT = 0, menuT = 0, perfAcc = 0, perfN = 0, perfGood = 0;
const dbg = { freeze: false }; // tests step the game themselves
function tick(dt) {
  time += dt; stats.time += dt;
  updatePlayer(dt);
  flowT -= dt; if (flowT <= 0) { flowT = 0.3; updateFlow(player.pos.x, player.pos.z); }
  updateGun(dt, mdx, mdy); Inject.update(dt); mdx = 0; mdy = 0;
  updateEnemies(dt, time); Ride.post();
  Car.update(dt);
  Proj.update(dt); Rockets.update(dt); ShipFX.update(dt); Loot.update(dt); Game.update(dt); updateWorld(dt, time, player.pos.x, player.pos.z); FX.update(dt); HUD.update(dt);
}
function frame(now) {
  requestAnimationFrame(frame);
  const cpu0 = performance.now();
  const rawDt = Math.max(0, (now - last) / 1000), dt = Math.min(0.05, rawDt); last = now;
  if (state === 'playing') { if (!dbg.freeze) tick(dt); }
  else if (state === 'cutscene') { if (dbg.freeze) { /* stepped by the test */ } else {
    time += dt; Cut.update(dt); FX.update(dt); Enemies.updateDying(dt); Loot.update(dt); updateWorld(dt, time, camera.position.x, camera.position.z); }
  } else if (state === 'gameover') {
    time += dt; FX.update(dt); Enemies.updateDying(dt); updateWorld(dt, time, player.pos.x, player.pos.z);
    if (Game.result !== 'clear') { camera.position.y = lerp(camera.position.y, player.pos.y + 0.4, 1 - Math.exp(-dt * 3)); camera.rotation.z = lerp(camera.rotation.z, 0.5, 1 - Math.exp(-dt * 3)); }
  } else if (state === 'menu' || state === 'brief') {
    time += dt; menuT += dt * 0.04;
    // behind the menu the camera circles the stage; inside the small lab it stays under the ceiling and inside the walls
    const MC = World.menuCam, mr = MC ? MC.r : 42, mh = MC ? MC.h : 16; // the lab and the ship set their own orbit, under their ceilings
    const cx = MC ? MC.x : 0, cz = MC ? MC.z : 0;
    camera.position.set(cx + Math.cos(menuT) * mr, mh + Math.sin(menuT * 2) * (MC ? 0.8 : 2), cz + Math.sin(menuT) * mr);
    camera.rotation.set(0, 0, 0); camera.lookAt(cx, MC ? MC.look : 3, cz); FX.update(dt); updateWorld(dt, time, camera.position.x * 0.5, camera.position.z * 0.5);
  }
  mdx = 0; mdy = 0;
  if (state === 'playing' && !isTouch) Gfx.govern(dt);
  else if (state === 'playing') {
    perfAcc += dt; perfN++;
    if (perfAcc > 2) {
      const avg = perfAcc / perfN, pr = renderer.getPixelRatio(); perfAcc = 0; perfN = 0;
      if (avg > 1 / 42 && pr > 0.7) { renderer.setPixelRatio(Math.max(0.7, pr - 0.15)); onResize(); perfGood = 0; }
      else if (avg < 1 / 57 && pr < MAX_PR - 0.01) { if (++perfGood >= 3) { renderer.setPixelRatio(Math.min(MAX_PR, pr + 0.1)); onResize(); perfGood = 0; } }
      else perfGood = 0;
    }
  }
  World.sky.position.copy(camera.position);
  renderer.info.reset();
  const post = Gfx.post;
  if (post) Post.begin();
  renderer.shadowMap.needsUpdate = true;
  renderer.clear(); renderer.render(scene, camera);
  if (post) Post.afterScene(Gfx.ao);
  if (state === 'playing' || state === 'paused') { renderer.clearDepth(); renderer.render(viewScene, viewCam); }
  if (post) Post.end();
  if (Custom.on && (state === 'menu' || state === 'brief')) Custom.draw(rawDt);
  Perf.frame(rawDt, performance.now() - cpu0);
}

/* ---------- boot ---------- */
let booted = false;
function start(data) {
  if (booted) return; booted = true;
  onResize();
  if (data && data.settings) Object.assign(settings, data.settings);
  Gfx.init(); Perf.show(settings.fps);
  Game.info = buildStage(1); Game.built = 1; Gfx.stage(1);
  syncSettingsUI(); refreshMenu();
  $('menucode').textContent = isoCode('YRD', 70707).text;
  // the browser is drawing on the CPU: say so up front, it explains a low frame rate better than any setting
  if (!isTouch && GPU.soft) { $('menumsg').textContent = '그래픽 가속이 꺼져 있어 화면을 CPU로 그리는 중이라 느립니다 · 브라우저 설정의 "가능한 경우 그래픽 가속 사용"을 켜고 브라우저를 다시 시작하세요'; $('menumsg').classList.add('warn'); }
  if (isTouch) {
    document.querySelectorAll('.senslbl').forEach((el) => { el.textContent = '조준 감도'; });
    const rows = [['이동 버튼', '왼쪽 가운데 ▲▼◀▶ · 두 버튼 사이로 밀면 대각선 · ▲를 두 번 눌러 누르고 있으면 달리기'], ['오른쪽 엄지', '화면을 끌어서 조준'], ['사격', '누른 채 끌면 조준도 됩니다'],
      ['자동 사격', '조준선이 적이나 12 m 안의 나무 상자에 닿으면 저절로 쏩니다'], ['조준 · 점프', '정조준 전환, 점프'], ['장전 · 무기 칸', '재장전, 무기 교체'], ['근접', isApp ? '총으로 가까운 적이나 상자를 칩니다 (소리 없음) · 나무 상자는 닿는 거리에 들어오면 저절로 칩니다' : '총으로 가까운 적이나 상자를 칩니다 (소리 없음)'],
      ['해독약', '감염되면 화면 가운데 버튼'], [isApp ? 'II · 뒤로 가기' : 'II', '일시정지 · 상점']];
    const k = $('keys'); k.textContent = '';
    rows.forEach(([a, b]) => { const kb = document.createElement('kbd'); kb.textContent = a; const sp = document.createElement('span'); sp.textContent = b; k.append(kb, sp); });
  }
  requestAnimationFrame(frame);
  window.__yard = { Game, player, Enemies, Gun, stats, save, Shop, Car, Loot, crates, wstate, TacMap, los: lineOfSight, stopDist, Proj, collideAt, Gfx, Post, Perf, renderer, scene, Inject, colliders, Lab, Kong, KONG, dbg, SaveCode, settings, refreshMenu, camera,
    Bleed, Fear, Toss, Ride, Beast, SEAT, ANIMALS, WEAPONS, HUD, Sound, Rockets, ShipFX, Ship, BPH, gdroneDrones, gunModels, GUN_MATS, Heat, bossDropMines, Safari, Tower, TOWER, rocketLock, Melee, groundAt, addCollider, removeCollider, buildNav, navPatch, damageCrate, persistNow: persist, get HALF() { return HALF; }, get NAV() { return NAV; }, get ivoryLock() { return ivoryLock; }, keyDown(c) { keys.add(c); }, keyUp(c) { keys.delete(c); }, damageCrate, startStage, get state() { return state; }, get calls() { return renderer.info.render.calls; },
    sim(sec) { const n = Math.round(sec * 30); for (let i = 0; i < n && state === 'playing'; i++) tick(1 / 30); },
    cutStep(dt) { if (state === 'cutscene') { time += dt; Cut.update(dt); FX.update(dt); updateWorld(dt, time, camera.position.x, camera.position.z); } } };
}
const canvasFonts = ['34px "Black Han Sans"', '600 14px "IBM Plex Mono"', '400 14px "IBM Plex Sans KR"', '900 64px "YardSign"'];
const fontsReady = document.fonts && document.fonts.load
  ? Promise.race([Promise.all(canvasFonts.map((f) => document.fonts.load(f).catch(() => null))).then(() => document.fonts.ready), new Promise((r) => setTimeout(r, 2500))])
  : Promise.resolve();
fontsReady.then(() => {
  if (hot && hot.ready) { try { hot.ready(start); } catch (e) { start({}); } setTimeout(() => start((hot && hot.data) || {}), 1500); }
  else start((hot && hot.data) || {});
});
})();
