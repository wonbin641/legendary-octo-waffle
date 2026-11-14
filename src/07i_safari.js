/* ============ stage 3-1: the safari. five minutes of the animals living wild, then every one of them comes for the watchtower ============ */
// (the stampede comes at five minutes.) before the stampede an animal only turns on you if you come close, shoot near it or hit it; then it fights like the lab's (07g).
// the zebras never fight and never run: at the stampede they come to the tower too and just stand about.
const SAFARI_T = 300; // five minutes
const SAFARI_ROSTER = [['zebra', 12], ['buffalo', 13], ['hippo', 12], ['rhino', 12], ['cheetah', 12], ['tiger', 12], ['lionM', 14], ['giraffe', 3], ['elephant', 4], ['gorilla', 6]];
/* the safari's lowland gorillas: the lab's gorilla build and fists (punch 62, charge 37 and a 1 s stun, half like every other animal here) */
const SAFARI_GORILLA = { kong: true, hp: 1000, scale: 1.15, dmgMul: 0.5, name: '로랜드고릴라' };
const Safari = {
  active: false, t: 0, stampede: false, warned: 0,
  reset() { this.active = false; this.t = 0; this.stampede = false; this.warned = 0; },
  begin() { this.active = true; this.t = 0; this.stampede = false; this.warned = 0; },
  left() { return Math.max(0, SAFARI_T - this.t); },
  update(dt) {
    if (!this.active) return;
    Tower.update(dt);
    if (this.stampede || Game.ended) return;
    this.t += dt;
    const left = SAFARI_T - this.t;
    if (this.warned < 1 && left <= 60) { this.warned = 1; Sound.alarm(); HUD.banner('1분 뒤 습격', '감시탑 위로 올라가 준비하세요', 2.8); }
    if (this.warned < 2 && left <= 10) { this.warned = 2; Sound.alarm(); HUD.banner('10초 뒤 습격', '땅이 울리기 시작합니다', 2.2); player.shake = Math.max(player.shake, 0.15); }
    if (left <= 0) this.go();
  },
  /* the stampede: every animal still alive (and not tamed) is set off at once and heads for you, and the tower you stand on */
  go() {
    if (this.stampede) return;
    this.stampede = true; this.t = SAFARI_T;
    let roars = 0;
    for (const e of Enemies.list) {
      if (!e.alive || !e.wild || e.tamed) continue;
      e.angry = true; e.alert = true; e.awake = true;
      if (!e.fury) { e.fury = true; e.state = 'chase'; Beast.wake(e); }
      if (e.type !== 'zebra' && roars < 8 && Math.random() < 0.25) { roars++; Sound.roar(e.pos, e.T.roar); }
    }
    Sound.quake(player.pos); Sound.siren(); player.shake = Math.max(player.shake, 0.45); buzz(220);
    HUD.banner('동물들이 몰려옵니다!', Tower.holds() ? '탑 위에 있으면 동물들은 탑부터 칩니다 · 기린은 목으로 탑 위까지 칩니다' : '감시탑으로 올라가세요!', 3.4);
    HUD.feed('습격 시작 · 모든 동물이 감시탑으로', 0, 'hs');
  },
};

/* the animals spread over the plain as they always are for this stage: herds of zebra, buffalo and giraffe, hippos round the waterhole,
   the big cats and the elephants further out */
function populateSafari(game, put, find, rand, randi) {
  const W = game.info.water;
  for (const [t, total] of SAFARI_ROSTER) {
    let c = total;
    for (let guard = 0; c > 0 && guard < 400; guard++) {
      if (t === 'zebra' || t === 'buffalo' || t === 'giraffe') {
        const center = find(70, 10, 2); if (!center) break;
        if (put(t, center)) c--;
        for (let i = 1, herd = t === 'giraffe' ? 3 : randi(3, 5); i < herd && c > 0; i++) { if (put(t, find(60, 2.6, 1.3, center, 8))) c--; }
      } else if (t === 'gorilla') {
        // two troops of three
        const center = find(85, 12, 2); if (!center) break;
        if (put(t, center, SAFARI_GORILLA)) c--;
        for (let i = 1; i < 3 && c > 0; i++) { if (put(t, find(80, 3, 1.3, center, 7), SAFARI_GORILLA)) c--; }
      } else if (t === 'hippo') {
        const a = rand(0, TAU);
        if (put(t, find(60, 3, 1.5, { x: W.x + Math.cos(a) * (W.r + 2.5), z: W.z + Math.sin(a) * (W.r + 2.5) }, 4) || find(70, 6, 2))) c--;
      } else if (put(t, find(t === 'elephant' ? 90 : 80, t === 'elephant' ? 14 : 8, t === 'elephant' ? 2.4 : 1.4))) c--;
    }
  }
  for (const e of Enemies.list) {
    e.wild = true;
    if (e.type === 'zebra') { e.fury = true; Beast.wake(e); e.bs = 'graze'; e.bt = rand(0.5, 4); } // zebras just live their quiet life (zebraAI), and never bolt here
  }
}

/* ---------- at the tower: what each kind does to it, and how often ---------- */
// rams back off and run at it (buffalo, rhino, elephant); the rest bite and claw at the planks. about 4 a second each (an elephant 8),
// and only one animal per place along its foot (16 places): with every place taken and nobody shooting it lasts about two and a half minutes
const SIEGE = { buffalo: { dmg: 20, cd: [1.6, 2.2], ram: true }, rhino: { dmg: 24, cd: [1.8, 2.4], ram: true }, elephant: { dmg: 52, cd: [2.2, 2.8], ram: true },
  hippo: { dmg: 14, cd: [1.6, 2.2] }, lionM: { dmg: 10, cd: [1.2, 1.6] }, tiger: { dmg: 10, cd: [1.1, 1.5] }, cheetah: { dmg: 8, cd: [1.0, 1.3] },
  gorilla: { dmg: 9, cd: [1.4, 2.0] } }; // gorillas: two or three haymakers into the planks, then a breather
const _sh = new THREE.Vector3();
function siegeAI(e, dt, dist) {
  const T = e.T, S = SIEGE[e.type] || { dmg: 5, cd: [1.4, 2] }, B = e.buff || 1, nose = noseOf(e);
  e.bt -= dt * B; e.sgCd = (e.sgCd === undefined ? rand(0.2, 1) : e.sgCd) - dt * B; e.claimT = (e.claimT || 0) - dt;
  // a place at the tower: kept while it is ours, looked for again every half second while waiting
  let slot = e.slot && e.slot.owner === e ? Tower.claim(e) : null;
  if (!slot && e.claimT <= 0) { e.claimT = rand(0.4, 0.7); slot = Tower.claim(e); }
  let sp = 0, mx = 0, mz = 0, pitch = 0, open = 0, face = null, turn = T.turn * 1.5;
  if (!slot) {
    // all taken: wait a little way off, on its own side of the tower, pacing and roaring
    if (e.bs !== 'swait') { e.bs = 'swait'; const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.4, 0.4), r = rand(9.5, 13); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; e.bt = rand(2, 5); }
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l > 1.2) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { mx = _fd.x; mz = _fd.z; } else { mx = wx / l; mz = wz / l; } sp = l > 16 ? T.run * 0.6 : T.speed * 1.2; }
    else { face = Math.atan2(Tower.x - e.pos.x, Tower.z - e.pos.z); if (e.bt <= 0) { e.bt = rand(3, 6); const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.5, 0.5), r = rand(9.5, 13); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; if (Math.random() < 0.35) Sound.roar(e.pos, T.roar); } }
  } else {
    // its place: stand with the nose to the planks; rams start further back
    const gx = slot.x + slot.nx * (nose + 0.15), gz = slot.z + slot.nz * (nose + 0.15);
    const vx = gx - e.pos.x, vz = gz - e.pos.z, d = Math.hypot(vx, vz) || 0.001, inFace = Math.atan2(-slot.nx, -slot.nz);
    const strike = (big) => {
      _sh.set(slot.x, Math.min(e.H * 0.6, 2.0), slot.z); Tower.hurt(S.dmg, e, _sh);
      if (big) { Sound.thud(_sh); FX.puff({ x: slot.x, y: 0.4, z: slot.z }, 3, 0.55, 0.9); }
    };
    if (e.bs === 'sback') {
      // backing off straight out from the wall for another run at it, still facing it
      mx = slot.nx; mz = slot.nz; sp = T.speed * 1.4; face = inFace;
      if (e.bt <= 0) { e.bs = 'sram'; e.bt = 2; if (Math.random() < 0.5) Sound.roar(e.pos, T.roar); }
    } else if (e.bs === 'sram') {
      mx = -slot.nx; mz = -slot.nz; sp = T.run * 0.7; pitch = 0.16; turn = 12; face = inFace;
      if (Math.random() < dt * 10) FX.puff({ x: e.pos.x + slot.nx, y: 0.2, z: e.pos.z + slot.nz }, 1, 0.55, 0.35);
      const gap = (e.pos.x - slot.x) * slot.nx + (e.pos.z - slot.z) * slot.nz - nose; // how far its nose is from the planks
      if (gap < 0.35) { strike(true); e.bs = 'sgo'; e.sgCd = rand(S.cd[0], S.cd[1]); }
      else if (e.bt <= 0) e.bs = 'sgo';
    } else if (e.bs === 'sbite') {
      const u = 1 - clamp(e.bt / 0.45, 0, 1); open = u < 0.6 ? u / 0.6 : 1 - (u - 0.6) / 0.4; pitch = 0.1 * open; face = inFace;
      if (!e.hitDone && u >= 0.6) { e.hitDone = true; strike(false); Sound.thud(e.pos); }
      if (e.bt <= 0) e.bs = 'sgo';
    } else {
      if (e.bs !== 'sgo') { e.bs = 'sgo'; e.hitDone = false; }
      if (d > 0.7) {
        // on its way: along the walking grid while far off, then straight to its place
        if (d > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { mx = _fd.x; mz = _fd.z; } else { mx = vx / d; mz = vz / d; }
        sp = d > 30 ? T.run * 0.6 : d > 4 ? T.run * 0.45 : T.speed * 1.2;
      } else {
        face = inFace;
        if (e.sgCd <= 0) {
          if (S.ram) { e.bs = 'sback'; e.bt = rand(0.7, 1.0); } else { e.bs = 'sbite'; e.bt = 0.45; e.hitDone = false; if (Math.random() < 0.4) Sound.roar(e.pos, T.roar); }
        }
      }
    }
  }
  beastMove(e, mx, mz, sp, dt);
  if (sp > 0 && (e.bs === 'sgo' || e.bs === 'swait')) unstick(e, e.bx0, e.bz0, mx, mz, sp, dt);
  turnToward(e, face !== null ? face : Math.atan2(mx, mz), turn, dt);
  animalGait(e, sp, dt);
  if (e.jaw) e.jaw.rotation.x = 0.7 * open;
  if (e.head && e.type === 'rhino') e.head.rotation.x = lerp(e.head.rotation.x, e.bs === 'sram' ? 0.4 : 0, 1 - Math.exp(-dt * 10));
  e.body.rotation.x = lerp(e.body.rotation.x, pitch, 1 - Math.exp(-dt * 8));
}

/* the safari's zebras once the stampede starts: they come to the tower with the rest, and just stand about it */
function zebraMill(e, dt) {
  const T = e.T; e.bt -= dt;
  const pickSpot = () => { const a = rand(0, TAU), r = rand(8.5, 14); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; };
  if (e.bs !== 'mwalk' && e.bs !== 'mgraze') { e.bs = 'mwalk'; e.bt = 40; pickSpot(); }
  let sp = 0, dx = 0, dz = 0;
  if (e.bs === 'mwalk') {
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l < 1.5 || e.bt <= 0) { e.bs = 'mgraze'; e.bt = rand(2, 6); }
    else {
      if (l > 20 && flowDir(e.pos.x, e.pos.z, _fd) && Tower.standing) { dx = _fd.x; dz = _fd.z; } else { dx = wx / l; dz = wz / l; }
      sp = T.speed * (l > 25 ? 2.4 : 1);
    }
  } else if (e.bt <= 0) { e.bs = 'mwalk'; e.bt = 25; pickSpot(); }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'mwalk') unstick(e, e.bx0, e.bz0, dx, dz, sp, dt);
  if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), T.turn, dt);
  animalGait(e, sp, dt);
  e.body.rotation.x = lerp(e.body.rotation.x, e.bs === 'mgraze' ? 0.1 : 0, 1 - Math.exp(-dt * 4));
}
