
/* ============ between stages: weapon rental, weapon layout, save codes, reset, developer mode ============ */
/* money spent inside a stage also comes off what you would walk away with if you fall */
function spend(c) { save.money -= c; if (moneyLock !== null) moneyLock -= c; persist(); }
function refund(c) { save.money += c; if (moneyLock !== null) moneyLock += c; persist(); }
const SIDE_SCREENS = ['menu', 'over', 'pause', 'shop', 'loadout', 'dlg', 'brief', 'codex', 'custom'];
function showOnly(id) { SIDE_SCREENS.forEach((s) => { $(s).hidden = s !== id; }); }
function backTo(from) { showOnly(from); if (from === 'menu') refreshMenu(); if (from === 'brief') briefGear(); if (from === 'loadout') Loadout.render(); }

/* ---------- items: bought once, kept until used up ---------- */
const ITEMS = {
  helmet: { name: '오토바이 헬멧', tag: '머리', price: 10000, desc: '머리로 오는 공격을 한 번 막아 줍니다. 막으면 부서집니다.' },
  vest: { name: '방탄조끼', tag: '몸', price: 50000, desc: '몸으로 오는 공격을 50% 줄여 줍니다. 10번 막으면 닳아 없어집니다. 불은 못 막습니다.' },
  jet: { name: '제트백팩', tag: '비행', price: 100000, desc: isTouch ? '점프 버튼을 두 번 누르면 날아오릅니다. 점프는 위로, 내려가기 버튼은 아래로. 최대 10초, 한 번 쓰면 끝입니다.'
    : '점프(Space)를 두 번 누르면 날아오릅니다. Space는 위로, Ctrl 또는 C는 아래로. 최대 10초, 한 번 쓰면 끝입니다.' },
};
/* elephant tusks: the shop buys each pair for this */
const IVORY_PRICE = 50000;
const itemState = (id) => { const v = save.items[id]; return !v ? '없음' : id === 'vest' ? '착용 중 · 내구 ' + v + '/10' : id === 'helmet' ? '착용 중' : '가지고 있음'; };
/* ---------- rental ---------- */
const Shop = {
  from: 'menu',
  get mid() { return this.from === 'pause' || (this.from === 'loadout' && Loadout.from === 'pause'); },
  open(from) { this.from = from; showOnly('shop'); $('shopmsg').textContent = ''; this.render(); setTimeout(() => $('shopclose').focus(), 0); },
  close() { $('shop').hidden = true; backTo(this.from); },
  msg(t) { $('shopmsg').textContent = t; },
  render() {
    $('shopmoney').textContent = '가방 ' + won(save.money);
    $('shophead').textContent = settings.dev ? '상점 · 개발자 모드: 모두 무료' : this.mid ? '상점 · 대여는 이번 스테이지 동안' : '상점 · 아이템과 무기 대여';
    const list = $('shoplist'); list.textContent = '';
    const head = (t) => { const h = document.createElement('div'); h.className = 'shophd'; h.textContent = t; list.appendChild(h); };
    head('아이템 · 다 쓸 때까지 가지고 다닙니다');
    ['helmet', 'vest', 'jet'].forEach((id) => {
      const I = ITEMS[id], have = !!save.items[id], price = settings.dev ? 0 : I.price;
      const row = document.createElement('div'); row.className = 'wrow item' + (have ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = I.name + ' '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = I.tag; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = I.desc; title.append(b, c);
      const st = document.createElement('div'); st.className = 'istate' + (have ? ' on' : ''); st.textContent = itemState(id);
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const pr = document.createElement('span'); pr.className = 'price'; pr.textContent = price ? won(price) : '무료 · 개발자 모드';
      const btns = document.createElement('div'); btns.className = 'btns';
      const x = document.createElement('button'); x.className = 'sbtn'; x.textContent = have ? '보유 중' : '구매'; x.disabled = have || save.money < price; x.addEventListener('click', () => this.buyItem(id)); btns.appendChild(x);
      buy.append(pr, btns); row.append(title, st, buy); list.appendChild(row);
    });
    // ivory from the lab's elephants: sell it here. inside a stage only what you brought in can go (what you got in there is not yours until you are out)
    {
      const have = save.items.ivory | 0, can = ivoryLock === null ? have : Math.min(have, ivoryLock), price = IVORY_PRICE;
      const row = document.createElement('div'); row.className = 'wrow item' + (have ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = '상아 '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = '팔기'; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = '스테이지 3의 코끼리를 잡으면 얻습니다(다시 하기에서는 안 나옴). 1개에 ' + won(price) + '에 삽니다.' + (can < have ? ' 이번 스테이지에서 얻은 것은 나간 뒤에 팔 수 있습니다.' : ''); title.append(b, c);
      const st = document.createElement('div'); st.className = 'istate' + (have ? ' on' : ''); st.textContent = have ? have + '개 가지고 있음' : '없음';
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const pr = document.createElement('span'); pr.className = 'price'; pr.textContent = '1개 ' + won(price);
      const btns = document.createElement('div'); btns.className = 'btns';
      const sell = (n, label) => { const x = document.createElement('button'); x.className = 'sbtn' + (n > 1 ? ' alt' : ''); x.textContent = label; x.disabled = can < 1; x.addEventListener('click', () => this.sellIvory(n)); btns.appendChild(x); };
      sell(1, '1개 팔기'); if (can > 1) sell(can, '모두 팔기 · ' + won(price * can));
      buy.append(pr, btns); row.append(title, st, buy); list.appendChild(row);
    }
    head(this.mid ? '무기 대여 · 이번 스테이지 동안' : '무기 대여 · 다음 스테이지 한 번');
    ORDER.forEach((id) => {
      const w = WEAPONS[id], rented = save.rented.includes(id), owned = save.owned.includes(id), free = id === 'pistol' || settings.dev;
      const has = free || rented || owned;
      const row = document.createElement('div'); row.className = 'wrow' + (has ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = w.name + ' '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = w.model; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = w.cls + ' · 총알 ' + (w.reserve === Infinity ? '무제한' : w.reserve.toLocaleString('ko-KR') + '발') + (w.note ? ' · ' + w.note : ''); title.append(b, c);
      const st = document.createElement('div'); st.className = 'wstats';
      [['피해', (w.dmg * w.pellets) / 170], ['연사', (1 / w.rate) / 22.2], ['탄창', Math.log(w.mag) / Math.log(1200)]].forEach(([k, v]) => {
        const l = document.createElement('span'); l.textContent = k; const bar = document.createElement('i'); const f = document.createElement('b');
        f.style.width = Math.round(clamp(v, 0.04, 1) * 100) + '%'; bar.appendChild(f); st.append(l, bar);
      });
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const price = document.createElement('span'); price.className = 'price';
      price.textContent = id === 'pistol' ? '무료' : settings.dev ? '무료 · 개발자 모드' : owned ? '보유 · 영구 (보물상자)' : rented ? '대여 중' : '대여료 ' + won(w.rent);
      const real = document.createElement('span'); real.className = 'real'; real.textContent = '실제 시세 약 ' + Math.round(w.real / 10000).toLocaleString('ko-KR') + '만 원';
      const btns = document.createElement('div'); btns.className = 'btns';
      const btn = (label, alt, fn, dis) => { const x = document.createElement('button'); x.className = 'sbtn' + (alt ? ' alt' : ''); x.textContent = label; x.disabled = !!dis; x.addEventListener('click', fn); btns.appendChild(x); };
      if (!has) btn('대여', false, () => this.rent(id), save.money < w.rent);
      else if (rented && !owned && !this.mid && !settings.dev) btn('대여 취소', true, () => this.cancel(id));
      if (has && this.mid && AMMO100[id]) { const c100 = settings.dev ? 0 : AMMO100[id], rk = WEAPONS[id].rocket;
        btn((rk ? '로켓 +1 · ' : '총알 +100 · ') + (c100 ? won(c100) : '무료') + (rk ? ' (' + (wstate[id].mag + wstate[id].reserve) + '/12)' : ''), true, () => this.ammo(id), save.money < c100 || ammoRoom(id) < 1); }
      buy.append(price, real, btns);
      row.append(title, st, buy); list.appendChild(row);
    });
  },
  buyItem(id) {
    const I = ITEMS[id], price = settings.dev ? 0 : I.price;
    if (save.items[id]) { this.msg(I.name + '은(는) 이미 가지고 있습니다'); return; }
    if (save.money < price) { this.msg(won(price - save.money) + ' 더 필요합니다'); return; }
    spend(price); save.items[id] = id === 'vest' ? 10 : 1; persist(); Sound.buy();
    this.msg(I.name + ' 구매' + (id === 'jet' ? ' · 싸우는 중에 점프를 두 번 누르면 날아오릅니다' : ' · 바로 착용했습니다'));
    this.render(); HUD.items();
  },
  sellIvory(n) {
    const have = save.items.ivory | 0, can = ivoryLock === null ? have : Math.min(have, ivoryLock); n = Math.min(n, can);
    if (n < 1) { this.msg('팔 수 있는 상아가 없습니다'); return; }
    save.items.ivory = have - n; if (ivoryLock !== null) ivoryLock -= n;
    refund(n * IVORY_PRICE); persist(); Sound.buy(); Sound.coin();
    this.msg('상아 ' + n + '개를 팔았습니다 · +' + won(n * IVORY_PRICE)); this.render(); HUD.items();
  },
  rent(id) {
    const w = WEAPONS[id];
    if (save.money < w.rent) { this.msg(won(w.rent - save.money) + ' 더 필요합니다'); return; }
    spend(w.rent); save.rented.push(id);
    const slot = Loadout.place(id); persist(); Sound.buy();
    if (this.mid) gainGun(id);
    this.msg(w.name + ' 대여 · ' + (this.mid ? '이번 스테이지가 끝나면 반납' : '다음 스테이지 한 번 쓰고 반납') + (slot ? ' · ' + slot + '번 칸에 넣었습니다' : ' · 빈 칸이 없어 무기 편성에서 넣어 주세요'));
    this.render();
  },
  cancel(id) {
    const w = WEAPONS[id];
    save.rented = save.rented.filter((x) => x !== id); refund(w.rent); Sound.reload(0);
    this.msg(w.name + ' 대여를 취소했습니다 · ' + won(w.rent) + ' 돌려받음'); this.render();
  },
  ammo(id) {
    const w = WEAPONS[id], c = settings.dev ? 0 : AMMO100[id];
    if (save.money < c) { this.msg(won(c - save.money) + ' 더 필요합니다'); return; }
    if (ammoRoom(id) < 1) { this.msg(w.name + ' · 더 들 수 없습니다'); return; }
    spend(c); wstate[id].reserve += ammoPack(id); Sound.reload(1);
    this.msg(w.name + (w.rocket ? ' 로켓 1발 · ' + (wstate[id].mag + wstate[id].reserve) + '/12' : ' 총알 100발 · ' + wstate[id].reserve + '발')); this.render();
  },
};

/* ---------- weapon layout: which gun sits on keys 1-7, any slot can be left empty ---------- */
const Loadout = {
  from: 'menu',
  open(from) { this.from = from; $('locustom').hidden = state === 'paused' || state === 'playing'; showOnly('loadout'); this.msg(''); this.render(); setTimeout(() => $('loclose').focus(), 0); },
  close() {
    if (this.from === 'pause') { applyLoadout(); if (Gun.none) { this.msg('싸우는 중에는 무기를 하나 이상 넣어야 합니다'); return; } }
    $('loadout').hidden = true; backTo(this.from);
  },
  msg(t) { $('lomsg').textContent = t; },
  /* a freshly rented gun goes into the first empty slot */
  place(id) {
    const at = save.loadout.indexOf(id); if (at >= 0) return at + 1;
    const i = save.loadout.indexOf(null); if (i < 0) return 0;
    save.loadout[i] = id; persist(); return i + 1;
  },
  set(slot, id) {
    if (id) { const j = save.loadout.indexOf(id); if (j >= 0 && j !== slot) save.loadout[j] = null; }
    save.loadout[slot] = id || null; persist();
    if (this.from === 'pause') applyLoadout();
    this.render();
  },
  render() {
    const box = $('lolist'); box.textContent = '';
    save.loadout.forEach((cur, i) => {
      const row = document.createElement('label'); row.className = 'lorow'; row.htmlFor = 'lo' + i;
      const k = document.createElement('kbd'); k.textContent = String(i + 1);
      const sel = document.createElement('select'); sel.id = 'lo' + i;
      const opt = (v, t) => { const o = document.createElement('option'); o.value = v; o.textContent = t; sel.appendChild(o); return o; };
      opt('', '비어 있음');
      ORDER.forEach((id) => {
        const ok = gunAvailable(id);
        if (!ok && id !== cur) return;
        const w = WEAPONS[id], at = save.loadout.indexOf(id);
        opt(id, w.name + ' ' + w.model + (!ok ? ' (대여 필요)' : save.owned.includes(id) ? ' · 보유' + (at >= 0 && at !== i ? ' (' + (at + 1) + '번에서 옮기기)' : '') : at >= 0 && at !== i ? ' (' + (at + 1) + '번에서 옮기기)' : ''));
      });
      sel.value = cur || '';
      sel.addEventListener('change', () => this.set(i, sel.value || null));
      const note = document.createElement('span'); note.className = 'lonote';
      note.textContent = !cur ? '' : !gunAvailable(cur) ? '이번에는 빈 칸' : cur === 'pistol' ? '무료' : settings.dev ? '개발자 모드' : save.owned.includes(cur) ? '보유' : '대여 중';
      row.append(k, sel, note); box.appendChild(row);
    });
    const ready = save.loadout.filter((id) => id && gunAvailable(id));
    $('losum').textContent = ready.length ? '출동하면 쓸 무기 · ' + save.loadout.map((id, i) => (id && gunAvailable(id) ? (i + 1) + ' ' + WEAPONS[id].short : '')).filter(Boolean).join(' · ')
      : '넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다';
    $('losum').classList.toggle('warn', !ready.length);
  },
};

/* ---------- save codes: progress packed into 41 letters with a check, typed back in to restore ---------- */
const SaveCode = (() => {
  const AL = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  // version 1 (22 letters, stages 1-3) and version 2 (28 letters, five stages) still load; version 3 (30 letters) knows all six
  const F1 = [['ver', 4], ['money', 27], ['unlocked', 2], ['cleared', 3], ['t1', 13], ['t2', 13], ['t3', 13], ['lo', 21]];
  const F2 = [['ver', 4], ['money', 27], ['unlocked', 3], ['cleared', 5], ['t1', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['lo', 21]];
  const F3 = [['ver', 4], ['money', 27], ['cleared', 6], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['lo', 21]];
  // version 4 (31 letters) also carries the items you have not used up: helmet, vest durability, jetpack
  const F4 = F3.concat([['ih', 1], ['iv', 4], ['ij', 1]]);
  // version 5 (32 letters) adds the ivory you have not sold (up to 63)
  const F5 = F4.concat([['ivory', 6]]);
  // version 6 (34 letters) adds the guns you own for good (one bit each for the six that are not the pistol)
  const F6 = F5.concat([['own', 6]]), OWN = ['shotgun', 'rifle', 'smg', 'sniper', 'gl', 'lmg'];
  // version 7 (36 letters) knows stage 2-1 too: one more cleared bit and its best time
  const F7 = [['ver', 4], ['money', 27], ['cleared', 7], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['t7', 13], ['lo', 21], ['ih', 1], ['iv', 4], ['ij', 1], ['ivory', 6], ['own', 6]];
  // version 8 (41 letters) adds stage 3-2 (cleared bit and best time), the rocket launcher (a 7th owned-gun bit),
  // and a 4-bit slot in the weapon layout (eight guns no longer fit in three bits)
  const F8 = [['ver', 4], ['money', 27], ['cleared', 8], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['t7', 13], ['t8', 13], ['lo', 28], ['ih', 1], ['iv', 4], ['ij', 1], ['ivory', 6], ['own', 7]];
  const LEN = new Map([[22, F1], [28, F2], [30, F3], [31, F4], [32, F5], [34, F6], [36, F7], [41, F8]]), ORDER2 = [1, 5, 2, 3, 4];
  // which bit is which stage, as each version wrote them (the list on screen can change; these never do)
  const ORDER6 = [1, 6, 5, 2, 3, 4], ORDER7 = [1, 6, 5, 2, 3, 4, 7], ORDER8 = [1, 6, 5, 2, 3, 4, 7, 8], OWN7 = OWN.concat(['rocket']);
  const check = (n) => { let h = 0x811c9dc5; const s = n.toString(16); for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return BigInt((h ^ (h >>> 12)) & 0xfff); };
  const loPack = () => save.loadout.reduce((m, id, i) => m + (id ? ORDER.indexOf(id) + 1 : 0) * 16 ** i, 0);
  const loUnpack = (x, base) => { const lo = []; for (let i = 0; i < 7; i++) { const c = x % base; x = Math.floor(x / base); lo.push(c ? ORDER[c - 1] || null : null); } return lo; };
  function encode() {
    const t = (k) => Math.min(save.best[k] || 0, 8191);
    const v = { ver: 8, money: Math.min(Math.max(0, moneyLock === null ? save.money : Math.min(save.money, moneyLock)), 2 ** 27 - 1),
      cleared: ORDER8.reduce((m, s, i) => m | (save.cleared.includes(s) ? 1 << i : 0), 0), t1: t('t1'), t6: t('t6'), t5: t('t5'), t2: t('t2'), t3: t('t3'), t4: t('t4'), t7: t('t7'), t8: t('t8'), lo: loPack(),
      ih: save.items.helmet ? 1 : 0, iv: clamp(save.items.vest | 0, 0, 10), ij: save.items.jet ? 1 : 0,
      ivory: clamp(ivoryLock === null ? save.items.ivory | 0 : Math.min(save.items.ivory | 0, ivoryLock), 0, 63),
      own: OWN7.reduce((m, id, i) => m | ((ownLock === null ? save.owned : ownLock).includes(id) ? 1 << i : 0), 0) };
    let n = 0n; for (const [k, b] of F8) n = (n << BigInt(b)) | BigInt(v[k]);
    n = (n << 12n) | check(n);
    let s = ''; for (let i = 0; i < 41; i++) { s = AL[Number(n & 31n)] + s; n >>= 5n; }
    return s.match(/.{1,5}/g).join('-');
  }
  function decode(text) {
    const clean = String(text || '').toUpperCase().replace(/[\s-]/g, '').replace(/O/g, '0').replace(/[IL]/g, '1');
    const F = LEN.get(clean.length); if (!F) return null;
    let n = 0n; for (const ch of clean) { const k = AL.indexOf(ch); if (k < 0) return null; n = (n << 5n) | BigInt(k); }
    const ck = n & 0xfffn; let p = n >> 12n;
    if (check(p) !== ck) return null;
    const o = {}; for (let i = F.length - 1; i >= 0; i--) { const [k, b] = F[i]; o[k] = Number(p & ((1n << BigInt(b)) - 1n)); p >>= BigInt(b); }
    if (p !== 0n) return null;
    const best = {}; ['t1', 't6', 't5', 't2', 't3', 't4', 't7', 't8'].forEach((k) => { if (o[k]) best[k] = o[k]; });
    let cleared;
    if (F === F1) { if (o.ver !== 1 || o.unlocked < 1 || o.unlocked > 3) return null; cleared = [1, 2, 3].filter((s) => o.cleared & (1 << (s - 1))); }
    else if (F === F2) { if (o.ver !== 2 || o.unlocked < 1 || o.unlocked > 5) return null; cleared = ORDER2.filter((s, i) => o.cleared & (1 << i)); if (cleared.includes(5)) cleared.push(6); }
    else if (F === F3) { if (o.ver !== 3) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F4) { if (o.ver !== 4 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F5) { if (o.ver !== 5 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F6) { if (o.ver !== 6 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F7) { if (o.ver !== 7 || o.iv > 10) return null; cleared = ORDER7.filter((s, i) => o.cleared & (1 << i)); }
    else { if (o.ver !== 8 || o.iv > 10) return null; cleared = ORDER8.filter((s, i) => o.cleared & (1 << i)); }
    return { v: 4, money: o.money, cleared, best, loadout: loUnpack(o.lo, F === F8 ? 16 : 8), rented: [], owned: OWN7.filter((id, i) => (o.own || 0) & (1 << i)),
      items: { helmet: o.ih || 0, vest: o.iv || 0, jet: o.ij || 0, ivory: o.ivory || 0 } };
  }
  return { encode, decode };
})();

/* ---------- one small dialog for save, load and reset ---------- */
/* 5.15: the save code by email. the mail is written for you (code, date, what it holds, how to load it); the address you send it to
   is remembered on this device only. a mail app, Gmail on the web, or a plain copy for when neither opens */
const SaveMail = {
  text() {
    const code = SaveCode.encode(), d = new Date(), pad = (n) => String(n).padStart(2, '0');
    const when = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    const done = STAGE_ORDER.filter((s) => save.cleared.includes(s)).map(stageTag);
    const subject = '야르 07 저장 코드 · ' + when;
    const body = ['야르 07 저장 코드', '', code, '', '저장한 때: ' + when, '깬 스테이지: ' + (done.length ? done.join(', ') : '없음'), '가방: ' + won(save.money), '',
      "게임 처음 화면의 '불러오기'에 위 코드를 넣으면 이 진행 상황으로 돌아갑니다."].join('\r\n');
    return { subject, body };
  },
  addr() { const a = ($('mailto').value || '').trim(); return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(a) ? a : ''; },
  refresh() {
    const { subject, body } = this.text(), a = this.addr();
    $('mailbtn').href = 'mailto:' + encodeURIComponent(a).replace(/%40/g, '@') + '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
    $('gmailbtn').href = 'https://mail.google.com/mail/?view=cm&fs=1' + (a ? '&to=' + encodeURIComponent(a) : '') + '&su=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
  },
  copy() {
    const { subject, body } = this.text(), all = subject + '\n\n' + body.replace(/\r\n/g, '\n'), done = () => { $('dlgmsg').textContent = '메일 내용을 복사했습니다 · 메일에 붙여 넣어 보내세요'; };
    const fallback = () => { const t = document.createElement('textarea'); t.value = all; t.setAttribute('readonly', ''); t.style.position = 'fixed'; t.style.opacity = '0'; document.body.appendChild(t); t.select();
      let ok = false; try { ok = document.execCommand('copy'); } catch (e) {} t.remove(); if (ok) done(); else $('dlgmsg').textContent = '복사가 막혀 있습니다 · 위 코드를 길게 눌러 복사해 주세요'; };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(all).then(done, fallback); else fallback();
  },
};
$('mailto').addEventListener('input', () => { settings.mailTo = ($('mailto').value || '').trim(); store('yard07.settings', settings); SaveMail.refresh(); });
for (const id of ['mailbtn', 'gmailbtn']) $(id).addEventListener('click', () => { SaveMail.refresh(); $('dlgmsg').textContent = id === 'mailbtn' ? '메일 앱을 엽니다 · 열리지 않으면 Gmail이나 메일 내용 복사를 써 주세요' : 'Gmail 쓰기 창을 엽니다'; });
$('mailcopy').addEventListener('click', () => SaveMail.copy());
const Dialog = {
  mode: null,
  open(mode) {
    this.mode = mode; showOnly('dlg'); $('dlgmsg').textContent = '';
    const code = $('codebox'), inp = $('codein'), ok = $('dlgok');
    code.hidden = mode !== 'save'; inp.hidden = mode !== 'load' && mode !== 'dev'; ok.classList.toggle('danger', mode === 'reset');
    $('mailrow').hidden = mode !== 'save'; if (mode === 'save') { $('mailto').value = settings.mailTo || ''; }
    inp.type = mode === 'dev' ? 'password' : 'text'; inp.inputMode = mode === 'dev' ? 'numeric' : 'text';
    if (mode === 'save') {
      $('dlghead').textContent = '진행 상황 저장'; $('dlgtitle').textContent = '저장 코드';
      $('dlgtext').textContent = '이 코드를 적어 두거나 복사해 두세요. 처음 화면의 불러오기에 넣으면 지금의 돈, 열린 스테이지, 깬 스테이지, 최단 기록, 무기 편성, 가진 총, 아이템과 상아로 돌아갑니다. 대여 중인 무기는 코드에 들어가지 않습니다.';
      code.textContent = SaveCode.encode(); ok.textContent = '코드 복사'; $('dlgcancel').textContent = '닫기'; SaveMail.refresh();
    } else if (mode === 'load') {
      $('dlghead').textContent = '진행 상황 불러오기'; $('dlgtitle').textContent = '불러오기';
      $('dlgtext').textContent = '저장할 때 받은 코드를 넣으세요. 지금 진행 상황은 코드의 내용으로 바뀌고, 대여 중인 무기는 반납됩니다(대여료는 돌려받지 않습니다).';
      inp.value = ''; ok.textContent = '불러오기'; $('dlgcancel').textContent = '취소'; inp.placeholder = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXX';
    } else if (mode === 'dev') {
      $('dlghead').textContent = '개발자 모드'; $('dlgtitle').textContent = '비밀번호';
      $('dlgtext').textContent = '개발자 모드를 켜려면 비밀번호를 넣으세요. 켜면 모든 스테이지와 모든 총, 아이템을 무료로 쓸 수 있습니다.';
      inp.value = ''; inp.placeholder = '비밀번호'; ok.textContent = '켜기'; $('dlgcancel').textContent = '취소';
    } else {
      $('dlghead').textContent = '진행 상황 초기화'; $('dlgtitle').textContent = '모두 지울까요?';
      $('dlgtext').textContent = '돈, 열린 스테이지, 깬 기록, 최단 기록, 무기 편성, 대여 중인 무기, 가진 총, 아이템과 상아를 모두 지우고 처음 상태로 돌아갑니다. 되돌릴 수 없으니 필요하면 먼저 저장 코드를 받아 두세요. 설정(감도, 음량, 그래픽, 개발자 모드)은 그대로입니다.';
      ok.textContent = '초기화'; $('dlgcancel').textContent = '취소';
    }
    setTimeout(() => (mode === 'load' || mode === 'dev' ? inp : $('dlgcancel')).focus(), 0);
  },
  close() { $('dlg').hidden = true; backTo('menu'); },
  ok() {
    if (this.mode === 'save') {
      const text = $('codebox').textContent, done = () => { $('dlgmsg').textContent = '복사했습니다'; };
      const fallback = () => { const r = document.createRange(); r.selectNodeContents($('codebox')); const s = getSelection(); s.removeAllRanges(); s.addRange(r);
        try { if (document.execCommand('copy')) { done(); return; } } catch (e) {} $('dlgmsg').textContent = '코드를 길게 눌러 직접 복사해 주세요'; };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
    } else if (this.mode === 'dev') {
      // only a hash of the password lives in the game, not the password itself
      if (devHash($('codein').value.trim()) !== 0x87114c2b) { $('dlgmsg').textContent = '비밀번호가 틀렸습니다'; $('codein').select(); Sound.empty(); return; }
      this.close(); setDev(true);
    } else if (this.mode === 'load') {
      const d = SaveCode.decode($('codein').value);
      if (!d) { $('dlgmsg').textContent = '코드가 맞지 않습니다. 글자를 다시 확인해 주세요.'; return; }
      Object.keys(save).forEach((k) => delete save[k]); Object.assign(save, d); fixSave(); moneyLock = null; ivoryLock = null; ownLock = null; persist(); Sound.buy();
      const done = STAGE_ORDER.filter((s) => save.cleared.includes(s)).map(stageTag);
      this.close(); $('menumsg').textContent = '불러왔습니다 · 가방 ' + won(save.money) + ' · 깬 스테이지 ' + (done.length ? done.join(', ') : '없음');
    } else {
      Object.keys(save).forEach((k) => delete save[k]); Object.assign(save, SAVE0()); fixSave(); moneyLock = null; ivoryLock = null; ownLock = null; persist(); Sound.reload(0);
      this.close(); $('menumsg').textContent = '모든 진행 상황을 지웠습니다';
    }
  },
};
function devHash(t) { let h = 0x811c9dc5; const s = 'yard07-dev:' + t; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h >>> 0; }
function setDev(on) {
  settings.dev = !!on; store('yard07.settings', settings);
  $('menumsg').textContent = on ? '개발자 모드 · 모든 스테이지와 모든 총을 쓸 수 있습니다' : '개발자 모드를 껐습니다';
  refreshMenu();
}
$('savebtn').addEventListener('click', () => Dialog.open('save'));
$('loadbtn').addEventListener('click', () => Dialog.open('load'));
$('resetbtn').addEventListener('click', () => Dialog.open('reset'));
$('devbtn').addEventListener('click', () => (settings.dev ? setDev(false) : Dialog.open('dev')));
/* 5.14: developer mode's invincibility: no damage and no deaths of any kind (laser, slam, infection, poison, bleeding) */
const godMode = () => !!(settings.dev && settings.god);
function godButtons() {
  for (const id of ['godbtn', 'pgodbtn']) { const b = $(id); b.hidden = !settings.dev; b.textContent = settings.god ? '무적 켜짐' : '무적 꺼짐'; b.classList.toggle('on', !!settings.god); }
  $('godtag').hidden = !godMode();
}
for (const id of ['godbtn', 'pgodbtn']) $(id).addEventListener('click', () => { settings.god = !settings.god; store('yard07.settings', settings); godButtons(); });
$('dlgok').addEventListener('click', () => Dialog.ok());
$('dlgcancel').addEventListener('click', () => Dialog.close());
$('codein').addEventListener('keydown', (e) => { if (e.key === 'Enter') Dialog.ok(); });
$('lobtn').addEventListener('click', () => Loadout.open('menu'));
$('cubtn').addEventListener('click', () => Custom.open('menu'));
$('locustom').addEventListener('click', () => { if (state === 'menu' || state === 'brief') { $('loadout').hidden = true; Custom.open('loadout'); } });
$('loclose').addEventListener('click', () => Loadout.close());
$('lorent').addEventListener('click', () => Shop.open('loadout'));
