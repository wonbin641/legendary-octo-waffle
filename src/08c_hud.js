
/* ---------- HUD ---------- */
const won = (n) => Math.round(n).toLocaleString('ko-KR') + '원';
/* 5.14: running with the SMG (12% faster on your feet) shows as green wind: streaks rushing out past the edges of your view and a faint
   green round the rim, stronger the faster you go. drawn on its own canvas in the game view; nothing is drawn while it is idle */
const Wind = (() => {
  let cv = null, g = null, k = 0, drawn = false, w = 0, h = 0;
  const P = []; for (let i = 0; i < 40; i++) P.push({ a: Math.random() * Math.PI * 2, r: 0.5 + Math.random() * 0.6, v: 0.7 + Math.random() * 0.6, l: 0.08 + Math.random() * 0.14, wd: 1.6 + Math.random() * 2.2 });
  function update(dt) {
    if (!cv) { cv = document.getElementById('windfx'); if (!cv) return; g = cv.getContext('2d'); }
    const sp = player.speedXZ || 0, want = state === 'playing' && Gun.cur === 'smg' && !Gun.none && sp > 0.8 ? Math.min(1, Math.max(0.3, (sp - 0.8) / 7)) : 0;
    k += (want - k) * (1 - Math.exp(-dt * 6));
    if (k < 0.012) { if (drawn) { g.clearRect(0, 0, w, h); drawn = false; } return; }
    const cw = Math.round(cv.clientWidth), ch = Math.round(cv.clientHeight);
    if (cw !== w || ch !== h) { w = cv.width = cw; h = cv.height = ch; }
    if (!w || !h) return;
    drawn = true; g.clearRect(0, 0, w, h);
    const cx = w / 2, cy = h / 2, R = Math.hypot(cx, cy);
    const rim = g.createRadialGradient(cx, cy, R * 0.5, cx, cy, R); rim.addColorStop(0, 'rgba(70,255,150,0)'); rim.addColorStop(1, 'rgba(70,255,150,' + (0.24 * k).toFixed(3) + ')');
    g.fillStyle = rim; g.fillRect(0, 0, w, h); g.lineCap = 'round';
    for (const p of P) {
      p.r += p.v * dt * (0.8 + k * 1.6);
      if (p.r > 1.15) { p.r = 0.46 + Math.random() * 0.22; p.a = Math.random() * Math.PI * 2; p.v = 0.7 + Math.random() * 0.6; p.l = 0.08 + Math.random() * 0.14; }
      const fade = Math.min(1, Math.max(0, (p.r - 0.44) / 0.18)) * Math.min(1, Math.max(0, (1.15 - p.r) / 0.25));
      if (fade <= 0) continue;
      const c = Math.cos(p.a), s = Math.sin(p.a), x0 = cx + c * p.r * R, y0 = cy + s * p.r * R, x1 = cx + c * (p.r + p.l) * R, y1 = cy + s * (p.r + p.l) * R;
      const lg = g.createLinearGradient(x0, y0, x1, y1); lg.addColorStop(0, 'rgba(140,255,180,0)'); lg.addColorStop(1, 'rgba(140,255,180,' + (0.85 * k * fade).toFixed(3) + ')');
      g.strokeStyle = lg; g.lineWidth = p.wd * (0.7 + k * 0.7); g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke();
    }
  }
  return { update };
})();
const HUD = (() => {
  const el = {};
  ['hpnum', 'hpfill', 'hpghost', 'mag', 'reserve', 'wname', 'stagenum', 'kills', 'killfill', 'money', 'moneypop', 'reload', 'reloadfill', 'hint', 'banner', 'bannerbig', 'bannersmall',
    'feed', 'hit', 'hurt', 'lowhp', 'toxic', 'stunfx', 'status', 'infect', 'infectT', 'infectMsg', 'anticount', 'dmgdir', 'ch-l', 'ch-r', 'ch-t', 'ch-b', 'slots', 't-anti', 't-car', 't-off', 'carbar', 'carfill', 'carlbl', 'bleedtag', 'bossbar', 'bossname', 'bossfill', 'tgtdir', 'cagebar', 'cagelbl', 'cagetxt', 'cagesec', 'itemrow', 'ch-ring', 'vbarT', 'vnumT', 'vfillT', 'vlblT', 'vbarM', 'vnumM', 'vfillM', 'vlblM', 'lockbox'].forEach((k) => (el[k] = $(k)));
  const cache = {}, crossEl = $('cross');
  const set = (k, v, prop) => { if (cache[k] !== v) { cache[k] = v; if (prop) el[k].style[prop] = v; else el[k].textContent = v; } };
  let hitT = 0, hurtT = 0, hintT = 0, bannerT = 0, heartT = 0, lockT = 0, lockE = null;
  const _lp = new THREE.Vector3();
  const arcs = [];
  for (let i = 0; i < 4; i++) { const a = document.createElement('div'); a.className = 'arc'; el.dmgdir.appendChild(a); arcs.push({ a, life: 0, from: null }); }
  let arcI = 0, slotEls = [];
  const tgts = [];
  for (let i = 0; i < 3; i++) { const t = document.createElement('div'); t.className = 'tgt'; el.tgtdir.appendChild(t); tgts.push(t); }
  return {
    hitmark(kill, head) { hitT = kill ? 0.35 : head ? 0.26 : 0.16; el.hit.style.setProperty('--hitc', kill ? '#ff5260' : head ? '#f2a33a' : '#ffffff'); el.hit.style.transform = kill ? (head ? 'scale(1.75)' : 'scale(1.35)') : head ? 'scale(1.3)' : 'scale(1)'; },
    hurt(dmg, from) {
      hurtT = Math.min(0.6, 0.2 + dmg * 0.012);
      if (from) { const A = arcs[arcI]; arcI = (arcI + 1) % arcs.length; A.life = 1.2; A.from = { x: from.x, z: from.z }; }
    },
    hint(t, dur) { el.hint.textContent = t; hintT = dur || 1.6; },
    banner(big, small, dur) { el.bannerbig.textContent = big; el.bannersmall.textContent = small; bannerT = dur || 2.5; },
    feed(text, money, cls) {
      const d = document.createElement('div'); if (cls) d.className = cls;
      d.textContent = text; if (money) { const b = document.createElement('b'); b.textContent = '+' + won(money); d.appendChild(b); }
      el.feed.prepend(d); while (el.feed.children.length > 4) el.feed.lastChild.remove();
      setTimeout(() => { d.style.opacity = 0; setTimeout(() => d.remove(), 450); }, 2400);
    },
    moneyPop(n) {
      const d = document.createElement('div'); d.className = 'mp'; d.textContent = '+' + won(n);
      el.moneypop.appendChild(d); setTimeout(() => d.remove(), 1250);
    },
    buildSlots() {
      el.slots.textContent = ''; slotEls = []; el.slots.classList.toggle('many', Gun.slots.length > 4);
      Gun.loadout.forEach((id, i) => {
        if (!id) return;
        const s = document.createElement('span'); const n = document.createElement('i'); n.textContent = (i + 1) + ' ';
        s.append(n, Gun.slots.length > 4 && portrait ? WEAPONS[id].tab : WEAPONS[id].short);
        s.addEventListener('touchstart', (e) => { e.preventDefault(); e.stopPropagation(); if (state === 'playing') switchWeapon(i); }, { passive: false });
        el.slots.appendChild(s); slotEls.push(s);
      });
      delete cache.slot;
    },
    /* what you carry: chips under your health */
    items() {
      const it = save.items, chips = [];
      if (it.helmet) chips.push(['헬멧', '']); if (it.vest) chips.push(['조끼 ' + it.vest + '/10', it.vest <= 3 ? 'low' : '']); if (it.jet) chips.push([isTouch ? '제트팩 · 점프 두 번' : '제트팩 · Space 두 번', 'jet']); if (it.ivory) chips.push(['상아 ' + it.ivory, '']);
      el.itemrow.textContent = ''; el.itemrow.hidden = !chips.length;
      for (const [t, c] of chips) { const s = document.createElement('span'); s.textContent = t; if (c) s.className = c; el.itemrow.appendChild(s); }
    },
    reset() { el.feed.textContent = ''; el.moneypop.textContent = ''; hitT = hurtT = hintT = bannerT = 0; arcs.forEach((A) => (A.life = 0)); for (const k in cache) delete cache[k]; },
    update(dt) {
      Wind.update(dt);
      const hp = Math.ceil(player.hp), pct = Math.round(100 * player.hp / (player.maxHp || 100));
      set('hpnum', String(hp)); set('hpfill', pct + '%', 'width'); set('hpghost', pct + '%', 'width');
      const hc = pct > 50 ? '#5ed6b0' : pct > 25 ? '#f2a33a' : '#ff5260';
      if (cache.hc !== hc) { cache.hc = hc; el.hpfill.style.backgroundColor = hc; }
      set('anticount', String(Game.antidotes));
      const w = WEAPONS[Gun.cur], st = wstate[Gun.cur];
      set('mag', String(st.mag)); set('reserve', '/ ' + (st.reserve === Infinity ? '∞' : st.reserve)); set('wname', w.model + ' ' + w.name + (w.heavy ? ' · 이동 -' + Math.round((1 - w.moveMul) * 100) + '%' : '') + (w.heat && st.hot ? ' · 과열' : ''));
      el.mag.classList.toggle('low', st.mag <= Math.ceil(w.mag * 0.25));
      const sel = Gun.pending || Gun.cur;
      if (cache.slot !== sel) { cache.slot = sel; slotEls.forEach((s, i) => s.classList.toggle('on', Gun.slots[i] === sel)); }
      set('stagenum', stageTag(Game.stage)); const done = Game.kills + (Game.calm || 0); set('kills', done + ' / ' + Game.goal); set('killfill', (100 * done / Game.goal) + '%', 'width');
      set('money', won(save.money));
      if (Gun.reloadT > 0) { el.reload.style.opacity = 1; el.reloadfill.style.width = (100 * (1 - Gun.reloadT / w.reload)) + '%'; } else el.reload.style.opacity = 0;
      if (st.mag === 0 && st.reserve > 0 && Gun.reloadT <= 0 && hintT <= 0) { el.hint.textContent = lookMode === 'touch' ? '장전 버튼을 누르세요' : 'R 키로 재장전'; el.hint.style.opacity = 1; }
      else if (hintT > 0) { hintT -= dt; el.hint.style.opacity = hintT > 0 ? 1 : 0; } else el.hint.style.opacity = 0;
      const spr = currentSpread(), fovR = THREE.MathUtils.degToRad(camera.fov) / 2;
      const gap = Math.round(Math.tan(spr) / Math.tan(fovR) * viewH / 2 + 4);
      set('ch-l', (-gap - 9) + 'px', 'left'); set('ch-r', gap + 'px', 'left'); set('ch-t', (-gap - 9) + 'px', 'top'); set('ch-b', gap + 'px', 'top');
      const co = String(w.scope && Gun.ads > 0.6 ? 0 : Math.round((1 - Gun.ads) * (1 - player.sprintBlend) * 100) / 100);
      if (cache.co !== co) { cache.co = co; ['ch-l', 'ch-r', 'ch-t', 'ch-b', 'ch-ring'].forEach((k) => (el[k].style.opacity = co)); }
      // the circles: the small one is the spread itself, the big one sits well outside it
      const ring = settings.cross === 'big' ? 2 * Math.max(gap + 24, 40) : 2 * Math.max(gap + 2, 9);
      if (cache.ring !== ring) { cache.ring = ring; el['ch-ring'].style.width = el['ch-ring'].style.height = ring + 'px'; }
      const adsDot = Gun.ads > 0.6 && !w.scope; if (cache.ads !== adsDot) { cache.ads = adsDot; crossEl.classList.toggle('ads', adsDot); }
      // the rocket launcher's lock: which enemy the next rocket would chase, marked where it stands on screen
      let lockOn = false;
      if (w.rocket && state === 'playing' && wstate[Gun.cur].mag > 0 && Gun.reloadT <= 0) {
        if ((lockT -= dt) <= 0) { lockT = 0.1; lockE = rocketLock(); }
        if (lockE && lockE.alive) { Proj.rocketCentre(lockE, _lp).project(camera);
          if (_lp.z < 1 && Math.abs(_lp.x) < 1.05 && Math.abs(_lp.y) < 1.05) { lockOn = true; el.lockbox.style.left = ((_lp.x + 1) * 50).toFixed(2) + '%'; el.lockbox.style.top = ((1 - _lp.y) * 50).toFixed(2) + '%'; } }
      } else lockE = null;
      if (el.lockbox.hidden === lockOn) el.lockbox.hidden = !lockOn;
      if (hitT > 0) { hitT -= dt; el.hit.style.opacity = clamp(hitT * 6, 0, 1); } else el.hit.style.opacity = 0;
      if (hurtT > 0) { hurtT -= dt; el.hurt.style.opacity = clamp(hurtT * 2.2, 0, 1); } else el.hurt.style.opacity = 0;
      el.lowhp.style.opacity = Game.stage !== 2 && pct < 35 ? (0.55 + Math.sin(time * 6) * 0.25) * (1 - pct / 35) + 0.2 : 0;
      // infection (a bite) and poison (a dash): both count down to the end unless an antidote goes in
      const inf = Game.infected, pois = Game.poisonT > 0, danger = inf || pois;
      if (el.infect.hidden === danger) el.infect.hidden = !danger;
      if (danger) {
        const T = inf && pois ? Math.min(Game.infectT, Game.poisonT) : inf ? Game.infectT : Game.poisonT, what = inf && pois ? '감염 + 중독' : inf ? '감염됨' : '중독됨';
        set('infectT', Math.max(0, T).toFixed(1));
        const msg = Game.antidotes > 0 ? what + (lookMode === 'touch' ? ' · 해독약 버튼을 누르세요' : ' · F 키로 해독약 사용') : what + ' · 해독약이 없습니다! 상자를 부수세요';
        set('infectMsg', msg);
        el.toxic.style.opacity = String(0.55 + Math.sin(time * 9) * 0.25 + Math.max(0, 5 - T) * 0.06);
        heartT -= dt; if (heartT <= 0) { heartT = 0.45 + T * 0.12; Sound.heart(); buzz(25); }
      } else { el.toxic.style.opacity = '0'; heartT = 0; }
      // stun and injection read-outs
      const stun = player.stunT > 0, inj = Inject.active;
      const stText = stun ? '기절 ' + player.stunT.toFixed(1) : Fear.t > 0 ? '공포 ' + Fear.t.toFixed(1) : Toss.on ? '공중으로 날아가는 중' : inj ? '해독약 주사 중' : Jet.on ? '제트백팩 ' + Math.max(0, Jet.t).toFixed(1) + '초' + (isTouch ? '' : ' · Space 위로 · Ctrl(C) 아래로') : '';
      // bleeding: how many wounds and how long they keep going
      const bl = Bleed.t > 0 ? Bleed.n + '|' + Math.ceil(Bleed.t) : '';
      if (cache.bl !== bl) { cache.bl = bl; el.bleedtag.hidden = !bl; if (bl) el.bleedtag.innerHTML = '<b>출혈 ×' + Bleed.n + '</b>' + Math.ceil(Bleed.t) + '초 · 초당 ' + BLEED_DPS * Bleed.n; }
      if (cache.st !== stText) { cache.st = stText; el.status.textContent = stText; el.status.hidden = !stText; el.status.classList.toggle('stun', stun); }
      el.stunfx.style.opacity = stun ? String(clamp(player.stunT, 0, 1) * (0.75 + Math.sin(time * 7) * 0.15)) : '0';
      const showAnti = isTouch && (inf || pois) && !inj;
      if (el['t-anti'].hidden === showAnti) el['t-anti'].hidden = !showAnti;
      if (showAnti) set('t-anti', Game.antidotes > 0 ? '해독약 사용 (' + Game.antidotes + ')' : '해독약 없음');
      // riding in the lab: the animal's health under yours, and what E (or the button) would do now
      const M = Ride.m;
      if ((Ride.findT -= dt) <= 0) { Ride.findT = 0.15; Ride.target = Ride.find(); }
      const tg = Ride.target && Ride.target.alive ? Ride.target : null;
      // the animal under you: a tall red bar on the right, its health in big numbers, and whether it is bleeding
      if (!el.carbar.hidden) el.carbar.hidden = true;
      if (el.vbarM.hidden === !!M) el.vbarM.hidden = !M;
      if (M) { const f = clamp(M.hp / M.maxHp, 0, 1); set('vnumM', Math.max(0, Math.ceil(M.hp)).toLocaleString('ko-KR')); set('vfillM', 'calc(' + (100 * f).toFixed(1) + '% - 6px)', 'height');
        set('vlblM', SEAT[M.type].name + (M.bleedT > 0 ? '\n출혈 ×' + M.bleedN : '')); const lowM = f < 0.25; if (cache.lowM !== lowM) { cache.lowM = lowM; el.vbarM.classList.toggle('low', lowM); } }
      const keyNear = Ship.active && Ship.keyNear(); // stage 4: the main hall's key in the bridge console
      const act = keyNear ? '메인홀 열쇠 줍기' : tg ? SEAT[tg.type].name + (M ? euroK(SEAT[tg.type].name) + ' 옮겨 타기' : ' 타기') : M ? '내리기' : '';
      const showRide = isTouch && !!act;
      if (el['t-car'].hidden === showRide) el['t-car'].hidden = !showRide;
      if (showRide) set('t-car', act);
      const showOff = isTouch && !!(M && tg);
      if (el['t-off'].hidden === showOff) el['t-off'].hidden = !showOff;
      if (!isTouch && hintT <= 0 && (keyNear || (st.mag > 0 && (tg || M)))) { el.hint.textContent = keyNear ? 'E 키로 메인홀 열쇠 줍기' : tg ? 'E 키로 ' + act + (M ? ' · X 키로 내리기' : '') : 'E 키로 내리기'; el.hint.style.opacity = 1; }
      // the lab: the next cage and its countdown. the safari: the time to the stampede, then how many are left
      const nc = Lab.active && Lab.running ? Lab.next() : null, sf = Safari.active && !Game.ended;
      if (el.cagebar.hidden === !!(nc || sf)) el.cagebar.hidden = !(nc || sf);
      set('cagelbl', sf ? (Safari.stampede ? '습격 중' : '습격까지') : '다음 우리');
      if (sf) {
        const L = Safari.left(), m = Math.floor(Math.ceil(L) / 60), s2 = Math.ceil(L) % 60;
        set('cagetxt', Safari.stampede ? '남은 동물' : '동물 100마리가 감시탑으로');
        set('cagesec', Safari.stampede ? (Game.goal - Game.kills - (Game.calm || 0)) + '마리' : m + ':' + String(s2).padStart(2, '0'));
        const soon = !Safari.stampede && L <= 30; if (cache.soon !== soon) { cache.soon = soon; el.cagebar.classList.toggle('soon', soon); }
      } else if (nc) {
        const left = Math.max(0, nc.openAt - Lab.t), A = ANIMALS[nc.type];
        set('cagetxt', nc.n + '번 · ' + (nc.boss ? '보스 ' + BOSS[3].name : A.name + ' ' + nc.animals.filter((e) => e.alive).length + '마리'));
        set('cagesec', nc.held ? (Lab.reach === nc ? '버튼을 누르는 중' : '앞 우리 ' + Math.min(99, Lab.waitLeft(nc)) + '마리 남음') : Math.ceil(left) + '초');
        const soon = !nc.held && left <= 3; if (cache.soon !== soon) { cache.soon = soon; el.cagebar.classList.toggle('soon', soon); }
      }
      // boss health once it has noticed you; arrows to the last ten enemies
      // the boss once it has noticed you; on the ship, the gold commander instead while it is the nearer fight
      let B = Game.boss, mid = false;
      const MB = Game.mid; if (MB && MB.alive && MB.alert && (!B || !B.alive || !B.alert || MB.dist < B.dist)) { B = MB; mid = true; }
      // 3-1's watchtower: the same tall red bar as a mount, on the right, while it stands
      const TW = Tower.active && Tower.standing && !Game.ended;
      if (el.vbarT.hidden === TW) el.vbarT.hidden = !TW;
      if (TW) { const f = clamp(Tower.hp / Tower.maxHp, 0, 1); set('vnumT', Math.ceil(Tower.hp).toLocaleString('ko-KR')); set('vfillT', 'calc(' + (100 * f).toFixed(1) + '% - 6px)', 'height');
        set('vlblT', Tower.on ? '감시탑\n탑 위' : '감시탑'); const lowT = f < 0.25; if (cache.lowT !== lowT) { cache.lowT = lowT; el.vbarT.classList.toggle('low', lowT); } }
      const showBoss = !!(B && B.alive && (B.alert || B.angry || B.hp < B.maxHp) && B.dist < 110);
      if (el.bossbar.hidden === showBoss) { el.bossbar.hidden = !showBoss; document.body.classList.toggle('bossbar-on', showBoss); }
      if (showBoss) { set('bossname', (mid ? '중간 보스 · ' : '보스 · ') + B.name + (B.k && B.k.phase !== undefined && B.type === 'bdrone' ? ' · ' + (B.k.phase + 1) + '페이즈' : '')); set('bossfill', Math.round(100 * clamp(B.hp / B.maxHp, 0, 1)) + '%', 'width'); }
      const left = Game.goal - Game.kills - (Game.calm || 0), chest = Game.chestWait ? Loot.pending() : null;
      if (chest) {
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw), dx = chest.x - player.pos.x, dz = chest.z - player.pos.z;
        tgts.forEach((t, i) => { if (i) { t.style.opacity = 0; return; } t.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; t.style.opacity = 0.95; });
      } else if (left > 0 && left <= 10 && !Game.ended && Game.stage !== 4) {
        const near = Enemies.list.filter((e) => e.alive && !e.tamed && !e.extra).sort((a, b) => a.dist - b.dist).slice(0, 3);
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
        tgts.forEach((t, i) => { const e = near[i]; if (!e) { t.style.opacity = 0; return; }
          const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z;
          t.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; t.style.opacity = i === 0 ? 0.95 : 0.55; });
      } else tgts.forEach((t) => { t.style.opacity = 0; });
      for (const A of arcs) {
        if (A.life <= 0) { A.a.style.opacity = 0; continue; }
        A.life -= dt;
        const dx = A.from.x - player.pos.x, dz = A.from.z - player.pos.z, sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
        A.a.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; A.a.style.opacity = clamp(A.life, 0, 1);
      }
      if (bannerT > 0) { bannerT -= dt; el.banner.style.opacity = bannerT > 0.35 ? 1 : 0; } else el.banner.style.opacity = 0;
    },
  };
})();
