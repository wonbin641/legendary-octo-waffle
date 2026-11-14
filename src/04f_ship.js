/* ============ stage 4: inside a spaceship, laid out after your drawing ============
   from the airlock (시작) a narrow dog-leg passage climbs north into a long corridor (복도, 160 m). the bridge (운전실) is at its west end:
   twice the floor of the old one and twice as tall, with an open gallery round three sides at 7 m and a wide stair up each side.
   the main hall (메인홀) is at its east end, with a stepped dais round the reactor in the middle; 5.18: the 5.15 hall at twice the width and depth.
   both have sliding doors onto the corridor */
const SHIP_ROOMS = [
  // x0, z0, x1, z1, ceiling height, kind
  [-123, -28, -92, 13, 16, 'bridge'],
  [-92, -12.5, 68, -2.5, 6, 'corr'],
  [68, -48, 162, 45, 16, 'hall'], // 5.18: twice as wide and twice as deep as the old 47 x 46.5 m, otherwise as it was
  [-26.5, -2.5, -22, 7, 4.5, 'pass'],
  [-44, 7, -22, 13, 4.5, 'pass'],
  [-44, 13, -39.5, 25, 4.5, 'pass'],
  [-44, 25, -39.5, 29.5, 4.5, 'lock'],
];
const SHIP_START = { x: -41.75, z: 22.6, yaw: 0 };
const SHIP_DOOR_Z = 25;
/* 5.18: the hall as it was before 5.16, laid out twice as wide and deep (every position doubled out from the door; things keep their size) */
const REACTOR = { x: 120, z: -6, r: 1.7, base: 1.35 };
const DAIS = [[96, -28, 144, 16, 0.45], [105, -20, 135, 8, 0.9], [112, -14, 128, 2, 1.35]]; // x0, z0, x1, z1, top
const HALL_PILLARS = [[80, -34], [80, 30], [154, -36], [154, 32]].map(([x, z]) => [x, z, 1.2, 0, 16, true]); // x, z, half-width, foot, top, to the ceiling
/* the bridge's gallery: 7 m up, 5 m deep along the north, south and east walls; the north and south runs start as stairs */
const BRIDGE = { gy: 7, x0: -123, x1: -92, z0: -28, z1: 13, stairX0: -117, stairX1: -107.4, eastX: -97, steps: 16 };
/* the sliding doors where the corridor meets the bridge and the hall, and the hatches in the hall floor that open at the boss's third phase */
const SHIP_DOORS = [{ x: -91.7, z0: -12.5, z1: -2.5, h: 6, name: '운전실', inward: -1, room: 'bridge', who: 'gdrone', title: '황금꿀벌드론', tone: 'bee', needKey: false },
  { x: 67.7, z0: -12.5, z1: -2.5, h: 6, name: '메인홀', inward: 1, room: 'hall', who: 'bdrone', title: '최첨단 감시 드론 보스 B-3', tone: 'boss', needKey: true }];
/* the main hall's key, stuck upright in the commander's console in the middle of the bridge */
const SHIP_KEY = { x: -105, y: 1.6, z: -7.5 };
/* where the save point puts you back: on the bridge, just inside its door, facing out */
const SHIP_SAVE = { x: -98.5, z: -7.5, yaw: -Math.PI / 2 };
/* 5.19: under the hall's floor, round the reactor, an upside-down stepped pyramid: three flights of eight 37.5 cm steps on every side,
   two landings, a floor 9 m down. hidden until the boss's second phase, when the floor over it breaks up and falls in (Ship.breakFloor) */
const PYR = (() => {
  const cx = REACTOR.x, cz = REACTOR.z, ox = 27, oz = 25, rise = 0.375, run = 0.55, per = 8, land = [3, 2.5];
  const steps = []; let ax = ox, az = oz;
  for (let k = 1; k < 3 * per; k++) { const L = k % per ? 0 : land[k / per - 1], w = run + L; steps.push({ k, ax, az, y: -rise * k, w, land: L ? k / per : 0 }); ax -= w; az -= w; }
  return { cx, cz, ox, oz, steps, bottom: -rise * 3 * per, bx: ax, bz: az };
})();
function inPit(x, z, m) { return Math.abs(x - PYR.cx) < PYR.ox + (m || 0) && Math.abs(z - PYR.cz) < PYR.oz + (m || 0); }
const HATCHES = [[75.2, -16], [75.2, 22], [90, 40], [118, 40.8], [150, 20], [150, -28], [118, -42.8], [86, -38]].map(([x, z]) => [x, z, 0]); // x, z, floor
/* the room a point is in (the airlock does not count: you never get in there) */
function shipRoom(x, z) { for (const R of SHIP_ROOMS) if (R[5] !== 'lock' && x >= R[0] && x <= R[2] && z >= R[1] && z <= R[3]) return R; return null; }
function shipCeil(x, z) { const R = shipRoom(x, z); return R ? R[4] : 30; }
const Ship = {
  active: false, door: null, doorOpen: 0, closing: false, coreMat: null, ring: null, screens: null, doors: [], hatches: [], hatchQ: [], hatchWait: 0,
  key: false, keyObj: null, keyGlow: null, keyHintT: 0, saveT: 0, pit: null, broken: false, breakT: 0,
  reset() { this.active = false; this.door = null; this.doorOpen = 0; this.closing = false; this.coreMat = null; this.ring = null; this.screens = null; this.doors = []; this.hatches = []; this.hatchQ = []; this.hatchWait = 0;
    this.key = false; this.keyObj = null; this.keyGlow = null; this.keyHintT = 0; this.saveT = 0; this.pit = null; this.broken = false; this.breakT = 0; },
  /* 5.19, the boss's second phase: the floor round the reactor breaks up and falls into the stepped pit under it. the dais goes with it;
     whatever stood there drops onto the steps (buried mines too, which land and arm again) */
  breakFloor() {
    if (this.broken || !this.pit) return; this.broken = true; const P = PYR, Q = this.pit;
    PIT = { x0: P.cx - P.ox, x1: P.cx + P.ox, z0: P.cz - P.oz, z1: P.cz + P.oz, y: P.bottom };
    for (const c of Q.cols) removeCollider(c);
    Q.dais.visible = Q.daisGlow.visible = false; for (const m of Q.show) m.visible = true;
    for (const t of Q.tiles) { t.userData.d = rand(0, 0.9) * (0.4 + 0.6 * Math.hypot(t.position.x - P.cx, t.position.z - P.cz) / P.ox); t.userData.vy = 0; t.userData.spin = [rand(-1.6, 1.6), rand(-1.6, 1.6)]; }
    for (const o of Enemies.list) if (o.alive && o.T && o.T.mode === 'mine' && inPit(o.pos.x, o.pos.z) && (o.bs === 'hidden' || o.bs === 'arm')) { o.bs = 'fall'; o.vy = 0; o.vel.set(0, 0, 0); }
    buildNav(); updateFlow(player.pos.x, player.pos.z);
    for (let i = 0; i < 7; i++) FX.explode({ x: P.cx + rand(-P.ox, P.ox) * 0.8, y: 0.3, z: P.cz + rand(-P.oz, P.oz) * 0.8 }, i < 2);
    FX.chunks({ x: P.cx, y: 0.5, z: P.cz }, 40, 0.5, 'metal'); Sound.boom({ x: P.cx, y: 0, z: P.cz }, true); Sound.alarm();
    player.shake = Math.max(player.shake, 0.9); buzz(260);
    HUD.banner('바닥 붕괴', '메인홀 바닥이 무너져 지하의 역피라미드 계단이 드러났습니다', 3);
    if (typeof TacMap !== 'undefined' && Game.info) TacMap.build(4, Game.info);
  },
  /* the gold bee on the bridge and the boss in the hall (5.13): each sits behind its door and takes no notice of anything until you come through it */
  drone(D) { return Enemies.list.find((o) => o.alive && o.type === D.who) || null; },
  enter(D) {
    const e = this.drone(D);
    if (!e) { D.mode = 'open'; return; } // nothing left in there: just a door
    D.mode = 'cut'; state = 'cutscene'; Gun.trigger = false; Gun.adsHeld = false; keys.clear(); jetEnd(); Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
    Cut.startBossIntro(D, e, () => this.lockIn(D));
  },
  /* after the look inside: you are just through the door, it slides shut behind you and locks until the thing in there is dead */
  lockIn(D) {
    const cz = (D.z0 + D.z1) / 2, e = this.drone(D);
    // nobody follows you in: anything standing in the doorway goes back out into the corridor
    for (const o of Enemies.list) if (o.alive && o !== e && !o.fly && Math.abs(o.pos.z - cz) < 6) { const inside = (o.pos.x - D.x) * D.inward; if (inside > -0.6 && inside < 0.6) o.pos.x = D.x - D.inward * 2.5; else if (inside >= 0.6 && inside < 4) o.pos.x = D.x + D.inward * 5; }
    player.pos.set(D.x + D.inward * 2.4, 0, cz); player.vel.set(0, 0, 0); player.yaw = D.inward < 0 ? Math.PI / 2 : -Math.PI / 2; player.pitch = 0;
    D.mode = 'locked';
    if (e) { e.sealed = false; Enemies.alarm(e); }
    for (const o of Enemies.list) if (o.alive && o.sealed && shipRoom(o.pos.x, o.pos.z) === shipRoom(player.pos.x, player.pos.z)) o.sealed = false; // the hall's patrols too
    HUD.banner('문이 잠겼습니다', D.room === 'bridge' ? '황금꿀벌드론을 쓰러뜨려야 문이 열립니다' : '눈이 빨개지고 3초 뒤 빨간 조준선이 쫓아옵니다 · 레이저에 맞으면 즉사 · 벽 뒤로 숨으세요', 2.6);
    backToPlay();
  },
  /* the thing behind a door is dead: that door opens for good. the bee's also makes the save point (Game.takeSave) */
  onDown(e) {
    const D = this.doors.find((d) => d.who === e.type); if (!D) return;
    D.mode = 'open'; Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
    if (D.room === 'bridge') this.saveT = 2.4; // the 'go and get the key' banner, once the kill banner has had its moment
  },
  keyNear() { return !!this.keyObj && !this.key && !Enemies.list.some((o) => o.alive && o.type === 'gdrone') && Math.hypot(player.pos.x - SHIP_KEY.x, player.pos.z - SHIP_KEY.z) < 2.6 && player.pos.y < 2.5; }, // only once the bee is down
  takeKey() {
    if (state !== 'playing' || !this.keyNear()) return false;
    this.key = true; this.keyObj.visible = false; Sound.pickup('ammo'); Sound.buy(); Sound.pickup('hp');
    Game.takeSave(); // the save point: from here on, with the key in your pocket
    HUD.banner('세이브 포인트', '메인홀 열쇠 획득 · 이제 쓰러져도 열쇠를 가진 채 여기서 다시 시작합니다', 3.6); HUD.feed('메인홀 열쇠 획득 · 세이브 포인트', 0);
    return true;
  },
  /* back from the save point: the bridge door stands open and the key is where it was (or in your pocket) */
  restore(sp) {
    const D = this.doors.find((d) => d.room === 'bridge'); if (D) { D.mode = 'open'; D.open = 1; if (D.col) { removeCollider(D.col); D.col = null; } this.slide(D); }
    if (sp.key) { this.key = true; if (this.keyObj) this.keyObj.visible = false; }
  },
  slide(D) { const w = (D.z1 - D.z0) / 2, k = D.open * D.open * (3 - 2 * D.open); D.a.position.z = D.z0 + w / 2 - k * w; D.b.position.z = D.z1 - w / 2 + k * w; },
  /* the two doors: shut until you stand right against one from the corridor side (the hall's also wants the key); then they slide open
     for the look inside, shut and lock behind you, and open for good once what is inside is dead. shut, they stop bullets */
  doorTick(dt) {
    this.keyHintT -= dt;
    for (const D of this.doors) {
      if (D.mode === 'shut' && state === 'playing' && !Game.ended) {
        const out = (player.pos.x - D.x) * -D.inward; // how far out in the corridor
        if (out > 0 && out < 1.3 && player.pos.z > D.z0 + 0.3 && player.pos.z < D.z1 - 0.3 && player.pos.y < 2.5) {
          if (D.needKey && !this.key) { if (this.keyHintT <= 0) { this.keyHintT = 3.5; HUD.hint('메인홀 문이 잠겨 있습니다 · 운전실 조종석에 꽂힌 열쇠가 필요합니다', 3); Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 }); } }
          else this.enter(D);
        }
      }
      const want = D.mode === 'cut' || D.mode === 'open';
      const o0 = D.open; D.open = clamp(D.open + (want ? dt * 2.6 : -dt * 2.4), 0, 1);
      if (D.open > 0.55 && D.col) { removeCollider(D.col); D.col = null; }
      if (D.open < 0.45 && !D.col) { D.col = addCollider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, 'metal'); D.col.door = true; }
      if ((o0 === 0 && D.open > 0) || (o0 === 1 && D.open < 1)) Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
      if (D.open !== o0) this.slide(D);
    }
  },
  /* the boss's third phase: every hatch in the hall floor slides open and drones come up out of them, a few at a time */
  openHatches() {
    if (this.hatchQ.length || !this.hatches.length || this.hatches[0].open) return;
    for (const H of this.hatches) H.open = true;
    for (let i = 0; i < 32; i++) { const H = this.hatches[i % this.hatches.length]; this.hatchQ.push({ x: H.x, z: H.z, y: H.y, t: 1.2 + Math.floor(i / this.hatches.length) * 2.2 + rand(0, 0.8) }); }
    Sound.alarm(); HUD.banner('해치 개방', '메인홀 바닥에서 드론 수십 대가 출격합니다', 2.6);
  },
  /* the airlock door, the reactor's pulse, the slow ring over it */
  anim(dt, t) {
    if (!this.active) return;
    if (this.breakT > 0 && (this.breakT -= dt) <= 0) this.breakFloor();
    if (this.broken && this.pit) for (const T of this.pit.tiles) { const u = T.userData; if (!T.visible) continue; if ((u.d -= dt) > 0) { T.position.y = Math.sin(u.d * 60) * 0.03; continue; }
      u.vy -= 18 * dt; T.position.y += u.vy * dt; T.rotation.x += u.spin[0] * dt; T.rotation.z += u.spin[1] * dt; if (T.position.y < PYR.bottom - 2) T.visible = false; }
    this.doorTick(dt);
    for (const H of this.hatches) { H.k = Math.min(1, H.k + (H.open ? dt * 1.5 : 0)); H.lidA.position.x = H.x - 0.6 - H.k * 1.15; H.lidB.position.x = H.x + 0.6 + H.k * 1.15; H.glow.visible = H.shaft.visible = H.k > 0.05; if (H.glow.visible) { H.glow.material.opacity = 0.75 + 0.2 * Math.sin(t * 8 + H.x); H.shaft.scale.y = H.k * (0.9 + 0.1 * Math.sin(t * 5 + H.z)); H.shaft.position.y = H.y + 1.7 * H.shaft.scale.y; } }
    if (this.closing) { this.doorOpen = Math.max(0, this.doorOpen - dt * 0.9); if (this.doorOpen === 0) this.closing = false; }
    if (this.door) this.door.position.y = 2.25 + this.doorOpen * 4.3;
    if (this.coreMat) { const k = 0.82 + 0.14 * Math.sin(t * 2.6) + 0.04 * Math.sin(t * 19); this.coreMat.color.setRGB(0.45 * k, 0.82 * k, 1.0 * k); }
    if (this.ring) this.ring.rotation.z += dt * 0.35;
    if (this.screens) this.screens.material.color.setScalar(0.85 + 0.15 * Math.sin(t * 4.3));
    if (this.keyObj && this.keyObj.visible) { this.keyObj.rotation.y += dt * 1.2; this.keyGlow.material.opacity = 0.55 + 0.3 * Math.sin(t * 4); }
    if (this.saveT > 0 && (this.saveT -= dt) <= 0 && !this.key) { HUD.banner('운전실 문이 열렸습니다', '조종석에 꽂힌 메인홀 열쇠를 뽑으세요 · 뽑으면 세이브 포인트', 3.4); }
  },
};
/* a box whose texture keeps its size in metres on every face (s metres per tile) */
function uvBox(x0, y0, z0, x1, y1, z1, s) {
  const g = new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0); g.translate((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    if (Math.abs(n.getX(i)) > 0.5) uv.setXY(i, z / s, y / s); else if (Math.abs(n.getY(i)) > 0.5) uv.setXY(i, x / s, z / s); else uv.setXY(i, x / s, y / s);
  }
  return g;
}
function buildShip(G, S, R, r) {
  const keep = World.keep, B = AnimalKit.geoBox, M = AnimalKit.merge;
  Ship.active = true;
  /* ---- textures ---- */
  const plate = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#2b3039'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 5000, ['#30353f', '#262a32', '#343a45'], 1.6);
    g.strokeStyle = 'rgba(12,14,18,0.9)'; g.lineWidth = 3; for (let k = 0; k <= 4; k++) { g.beginPath(); g.moveTo(k * w / 4, 0); g.lineTo(k * w / 4, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 4); g.lineTo(w, k * h / 4); g.stroke(); }
    g.fillStyle = 'rgba(160,170,190,0.35)'; for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) for (const [dx, dy] of [[10, 10], [w / 4 - 10, 10], [10, h / 4 - 10], [w / 4 - 10, h / 4 - 10]]) { g.beginPath(); g.arc(i * w / 4 + dx, j * h / 4 + dy, 2.5, 0, TAU); g.fill(); }
    for (let i = 0; i < 10; i++) { g.fillStyle = 'rgba(8,10,14,' + rand(0.1, 0.25) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(15, 60), rand(6, 25), rand(0, 3), 0, TAU); g.fill(); }
  }, 1, 1));
  const hallTex = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#1f242d'; g.fillRect(0, 0, w, h); speckle(g, w, h, 4000, ['#232832', '#1b1f27', '#272d38'], 1.6);
    g.strokeStyle = 'rgba(8,10,14,0.95)'; g.lineWidth = 4; for (let k = 0; k <= 2; k++) { g.beginPath(); g.moveTo(k * w / 2, 0); g.lineTo(k * w / 2, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 2); g.lineTo(w, k * h / 2); g.stroke(); }
    g.strokeStyle = 'rgba(90,200,255,0.35)'; g.lineWidth = 2; g.strokeRect(26, 26, w / 2 - 52, h / 2 - 52); g.strokeRect(w / 2 + 26, h / 2 + 26, w / 2 - 52, h / 2 - 52);
  }, 1, 1));
  const panel = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#3a404d'; g.fillRect(0, 0, w, h);
    for (let x = 0; x < w; x += 64) { g.fillStyle = (x / 64) % 2 ? '#353a46' : '#3f4653'; g.fillRect(x + 2, 2, 60, h - 4); }
    g.fillStyle = 'rgba(10,12,16,0.8)'; g.fillRect(0, h / 2 - 2, w, 4);
    g.fillStyle = 'rgba(200,170,60,0.5)'; g.fillRect(0, h - 10, w, 6);
    speckle(g, w, h, 1200, ['rgba(0,0,0,0.25)', 'rgba(255,255,255,0.05)'], 1.5);
  }, 1, 1));
  const grate = keep(canvasTex(128, 128, (g, w, h) => {
    g.fillStyle = '#1c2027'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#4a5260'; for (let i = 0; i < w; i += 8) { g.fillRect(i, 0, 3, h); g.fillRect(0, i, w, 3); }
  }, 1, 1));
  const carpet = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#1a2233'; g.fillRect(0, 0, w, h); speckle(g, w, h, 3000, ['#1d2639', '#161d2b', '#202a3f'], 1.4);
    g.strokeStyle = 'rgba(120,170,255,0.18)'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, h / 2); g.lineTo(w, h / 2); g.stroke();
  }, 1, 1));
  const ceilTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#22262e'; g.fillRect(0, 0, w, h);
    g.strokeStyle = '#15181d'; g.lineWidth = 4; for (let k = 0; k <= 2; k++) { g.beginPath(); g.moveTo(k * w / 2, 0); g.lineTo(k * w / 2, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 2); g.lineTo(w, k * h / 2); g.stroke(); }
    speckle(g, w, h, 800, ['rgba(255,255,255,0.04)', 'rgba(0,0,0,0.2)'], 1.5);
  }, 1, 1));
  const space = (planetX) => keep(canvasTex(1024, 256, (g, w, h) => {
    g.fillStyle = '#02040a'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 700; i++) { g.fillStyle = 'rgba(220,230,255,' + rand(0.25, 1) + ')'; g.fillRect(rand(0, w), rand(0, h), rand(1, 2.4), rand(1, 2.4)); }
    const gr = g.createRadialGradient(w * planetX, h * 1.25, 20, w * planetX, h * 1.25, h * 1.15); gr.addColorStop(0, '#9fd0ff'); gr.addColorStop(0.55, '#3a6aa8'); gr.addColorStop(0.9, '#0e1c38'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.strokeStyle = 'rgba(30,36,48,1)'; g.lineWidth = 10; for (let x = 0; x <= w; x += w / 5) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); } // the frame between the panes
  }));
  /* 5.14, after your drawing: a worn dark plate in a thick frame, the name in heavy old-style letters, and a big block arrow at the end it
     points to (left or right at the corridor junction; up, 'straight on', on the signs hung before the doors). bridge orange, hall green */
  const sign = (text, dir, col) => keep(canvasTex(1024, 320, (g, w, h) => {
    g.fillStyle = '#0e1219'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 1400; i++) { g.fillStyle = 'rgba(255,255,255,' + (Math.random() * 0.035).toFixed(3) + ')'; g.fillRect(Math.random() * w, Math.random() * h, 1 + Math.random() * 3, 1 + Math.random() * 3); }
    g.strokeStyle = col; g.lineWidth = 16; g.strokeRect(16, 16, w - 32, h - 32);
    const aw = 280, left = dir === 'left', ax = left ? 48 : w - 48 - aw, cy = h / 2;
    g.fillStyle = col; g.beginPath();
    if (dir === 'up') { // a tall arrow: head on top, shaft below
      const cx = ax + aw / 2, top = 46, bot = h - 46, hw = 118, sw = 46, neck = top + 120;
      g.moveTo(cx, top); g.lineTo(cx + hw, neck); g.lineTo(cx + sw, neck); g.lineTo(cx + sw, bot); g.lineTo(cx - sw, bot); g.lineTo(cx - sw, neck); g.lineTo(cx - hw, neck);
    } else { // a long arrow: shaft, then a broad head; mirrored for the left
      const s = left ? -1 : 1, x0 = left ? ax + aw : ax, tip = x0 + s * aw, neck = x0 + s * aw * 0.5, hh = 112, sh = 44;
      g.moveTo(x0, cy - sh); g.lineTo(neck, cy - sh); g.lineTo(neck, cy - hh); g.lineTo(tip, cy); g.lineTo(neck, cy + hh); g.lineTo(neck, cy + sh); g.lineTo(x0, cy + sh);
    }
    g.closePath(); g.fill();
    g.font = '900 176px "YardSign", "Black Han Sans", serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    const tx = left ? (ax + aw + w - 48) / 2 + 10 : (48 + ax) / 2 - 10;
    g.lineJoin = 'round'; g.lineWidth = 10; g.strokeStyle = '#0e1219'; g.strokeText(text, tx, cy + 10); g.fillText(text, tx, cy + 10);
  }));
  const BRIDGE_C = '#f2a33a', HALL_C = '#5ed6b0';
  const wallMat = new THREE.MeshStandardMaterial({ map: panel, roughness: 0.8, metalness: 0.2 });
  const ceilMat = new THREE.MeshStandardMaterial({ map: ceilTex, roughness: 0.8, metalness: 0.2 });
  const floorMat = { corr: new THREE.MeshStandardMaterial({ map: plate, roughness: 0.55, metalness: 0.45 }), hall: new THREE.MeshStandardMaterial({ map: hallTex, roughness: 0.5, metalness: 0.5 }),
    pass: new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 }), lock: new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 }),
    bridge: new THREE.MeshStandardMaterial({ map: carpet, roughness: 0.9, metalness: 0.05 }) };
  const kitMat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.5, metalness: 0.45 });
  const glowMat = new THREE.MeshBasicMaterial({ vertexColors: true });
  const solid = [], glow = [], pipes = [];
  const box = (x0, y0, z0, x1, y1, z1, col, kind) => { addCollider(x0, y0, z0, x1, y1, z1, kind || 'metal'); solid.push(B(x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, col)); };

  /* ---- 1. the floor plan into a half-metre grid: every cell knows the ceiling over it (0 = outside the ship) ---- */
  const CS = 0.5, GX = -126, GZ = -50, NX = 580, NZ = 192, hAt = new Float32Array(NX * NZ); // x -126..164, z -50..46
  for (const Rm of SHIP_ROOMS) {
    const i0 = Math.round((Rm[0] - GX) / CS), i1 = Math.round((Rm[2] - GX) / CS), j0 = Math.round((Rm[1] - GZ) / CS), j1 = Math.round((Rm[3] - GZ) / CS);
    for (let i = i0; i < i1; i++) for (let j = j0; j < j1; j++) hAt[j * NX + i] = Math.max(hAt[j * NX + i], Rm[4]);
  }
  const H = (i, j) => (i < 0 || j < 0 || i >= NX || j >= NZ ? 0 : hAt[j * NX + i]);
  /* ---- 2. walls wherever a cell meets the outside, and lintels above an opening into a lower room ---- */
  const T = 0.6, walls = [];
  const run2 = (n, m, get, emit) => {
    for (let a = 0; a < n; a++) {
      let cur = null;
      const flush = () => { if (cur) { emit(a, cur); cur = null; } };
      for (let b = 0; b < m; b++) {
        const [h, hn] = get(a, b);
        if (h > 0 && hn < h) { const y0 = hn > 0 ? hn : 0; if (cur && cur.y0 === y0 && cur.y1 === h && cur.b1 === b) cur.b1 = b + 1; else { flush(); cur = { b0: b, b1: b + 1, y0, y1: h }; } }
        else flush();
      }
      flush();
    }
  };
  for (const d of [-1, 1]) {
    run2(NZ, NX, (j, i) => [H(i, j), H(i, j + d)], (j, c) => { const zb = GZ + (d < 0 ? j : j + 1) * CS; walls.push([GX + c.b0 * CS, c.y0, d < 0 ? zb - T : zb, GX + c.b1 * CS, c.y1 + 0.4, d < 0 ? zb : zb + T]); });
    run2(NX, NZ, (i, j) => [H(i, j), H(i + d, j)], (i, c) => { const xb = GX + (d < 0 ? i : i + 1) * CS; walls.push([d < 0 ? xb - T : xb, c.y0, GZ + c.b0 * CS, d < 0 ? xb : xb + T, c.y1 + 0.4, GZ + c.b1 * CS]); });
  }
  const wallGeos = [];
  for (const [x0, y0, z0, x1, y1, z1] of walls) { addCollider(x0, y0, z0, x1, y1, z1, 'metal'); wallGeos.push(uvBox(x0, y0, z0, x1, y1, z1, 3)); }
  const wallMesh = new THREE.Mesh(mergeGeos(wallGeos), wallMat); wallMesh.receiveShadow = true; G.add(wallMesh);
  /* ---- 3. ceilings and floors ---- */
  const ceilGeos = [];
  for (const [x0, z0, x1, z1, h, kind] of SHIP_ROOMS) {
    addCollider(x0, h, z0, x1, h + 0.4, z1, 'metal'); ceilGeos.push(uvBox(x0, h, z0, x1, h + 0.4, z1, 4));
    if (kind === 'hall') continue; // the hall's floor is laid round its hidden pit (section 7)
    const fg = new THREE.PlaneGeometry(x1 - x0, z1 - z0), uv = fg.attributes.uv, s = kind === 'pass' || kind === 'lock' ? 1.5 : kind === 'bridge' ? 3 : 6;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * (x1 - x0) / s, uv.getY(i) * (z1 - z0) / s);
    const f = new THREE.Mesh(fg, floorMat[kind]); f.rotation.x = -Math.PI / 2; f.position.set((x0 + x1) / 2, 0.002, (z0 + z1) / 2); f.receiveShadow = true; G.add(f);
  }
  G.add(new THREE.Mesh(mergeGeos(ceilGeos), ceilMat));

  /* ---- 4. the passage from the airlock: pipes overhead, red warning lamps, hazard stripes at the turns ---- */
  const pipeZ = (x, y, z0, z1, rr) => { const g = new THREE.CylinderGeometry(rr, rr, z1 - z0, 8); g.rotateX(Math.PI / 2); g.translate(x, y, (z0 + z1) / 2); pipes.push(g); };
  const pipeX = (z, y, x0, x1, rr) => { const g = new THREE.CylinderGeometry(rr, rr, x1 - x0, 8); g.rotateZ(Math.PI / 2); g.translate((x0 + x1) / 2, y, z); pipes.push(g); };
  pipeZ(-43.7, 3.9, 13, 25, 0.12); pipeZ(-39.8, 3.7, 13, 25, 0.09); pipeX(7.3, 3.9, -44, -22, 0.12); pipeX(12.7, 3.7, -44, -22, 0.09); pipeZ(-26.2, 3.9, -2.5, 7, 0.12); pipeZ(-22.3, 3.7, -2.5, 7, 0.09);
  for (const [x, z] of [[-41.75, 16], [-41.75, 20], [-38, 10], [-30, 10], [-24.25, 4], [-24.25, 0]]) glow.push(B(1.2, 0.05, 0.4, x, 4.46, z, '#cfe6ff'));
  for (const [x, z] of [[-43.95, 18], [-39.55, 14], [-33, 7.05], [-27, 12.95], [-26.45, 2]]) {
    const b = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 0.25), new THREE.MeshBasicMaterial({ color: 0xff2a2a })); b.position.set(x, 3.4, z); G.add(b); World.blink.push(b);
  }
  for (const [x0, z0, x1, z1] of [[-44, 7, -39.5, 13], [-26.5, 7, -22, 13], [-26.5, -2.5, -22, -1.6]]) {
    const n = Math.round((x1 - x0) / 0.5);
    for (let i = 0; i < n; i += 2) glow.push(B(0.5, 0.01, 0.12, x0 + 0.25 + i * 0.5, 0.012, z0 + 0.1, '#e8b040'), B(0.5, 0.01, 0.12, x0 + 0.25 + i * 0.5, 0.012, z1 - 0.1, '#e8b040'));
  }
  // the airlock: a heavy sliding door with a striped frame; you came in through it and it shuts behind you
  addCollider(-44, 0, SHIP_DOOR_Z - 0.2, -39.5, 4.5, SHIP_DOOR_Z + 0.2, 'metal');
  const doorTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#4a5162'; g.fillRect(0, 0, w, h); g.fillStyle = '#3a4050'; g.fillRect(16, 16, w - 32, h - 32);
    for (let i = -h; i < w; i += 40) { g.fillStyle = '#e8b040'; g.beginPath(); g.moveTo(i, h); g.lineTo(i + 20, h); g.lineTo(i + 20 + 30, h - 30); g.lineTo(i + 30, h - 30); g.fill(); }
    g.fillStyle = '#ff3a2a'; g.font = '40px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.fillText('에어록', w / 2, h * 0.42); g.font = '600 18px "IBM Plex Mono", monospace'; g.fillStyle = '#cfd6e2'; g.fillText('AIRLOCK B-07', w / 2, h * 0.58);
  }));
  const door = new THREE.Mesh(new THREE.BoxGeometry(4.5, 4.5, 0.3), new THREE.MeshStandardMaterial({ map: doorTex, roughness: 0.5, metalness: 0.5 })); door.position.set(-41.75, 2.25, SHIP_DOOR_Z); G.add(door); Ship.door = door;
  solid.push(B(0.35, 4.5, 0.5, -44 + 0.17, 2.25, SHIP_DOOR_Z, '#2a2f3a'), B(0.35, 4.5, 0.5, -39.5 - 0.17, 2.25, SHIP_DOOR_Z, '#2a2f3a'));
  // inside the airlock: the outer hatch, a round window full of stars
  const hatch = new THREE.Mesh(new THREE.CircleGeometry(1.3, 32), new THREE.MeshBasicMaterial({ map: space(0.3) })); hatch.position.set(-41.75, 2.2, 29.45); hatch.rotation.y = Math.PI; G.add(hatch);
  solid.push(B(3.2, 3.2, 0.2, -41.75, 2.2, 29.5, '#2a2f3a'));
  World.lamps.push({ x: -41.75, y: 3.6, z: 27.5, d: 0 });

  /* ---- 5. the corridor (160 m): pipes, a light strip on each wall, panels in the ceiling, low barricades to hide behind ---- */
  pipeX(-12.2, 5.2, -92, 68, 0.16); pipeX(-12.25, 4.7, -92, 68, 0.1); pipeX(-2.8, 5.2, -92, -26.5, 0.16); pipeX(-2.8, 5.2, -22, 68, 0.16);
  for (const z of [-12.46, -2.54]) glow.push(B(160, 0.06, 0.04, -12, 2.4, z, '#3a9cff'));
  for (let x = -88; x <= 64; x += 6) glow.push(B(3.2, 0.06, 1.2, x, 5.97, -7.5, '#dfeeff'));
  for (let i = 0, x = -84; x <= 60; x += 12, i++) { const z = i % 2 ? -4.2 : -10.8, w = 3, d = 0.7;
    if (Math.abs(x + 24.25) < 4) continue; // keep the mouth of the passage clear
    box(x - w / 2, 0, z - d / 2, x + w / 2, 1.15, z + d / 2, '#454d60'); solid.push(B(w + 0.04, 0.08, d + 0.04, x, 1.16, z, '#e8b040')); }
  // sealed side doors along the corridor walls
  for (const x of [-80, -55, -40, -15, 8, 33, 52]) { solid.push(B(2.4, 3.2, 0.12, x, 1.6, -12.44, '#2c313c'), B(2.4, 3.2, 0.12, x + 6, 1.6, -2.56, '#2c313c')); glow.push(B(0.3, 0.12, 0.05, x + 1.5, 1.7, -12.36, '#ff3a2a'), B(0.3, 0.12, 0.05, x + 4.5, 1.7, -2.64, '#ff3a2a')); }
  // signs: the bridge to the west, the main hall to the east
  const signMesh = (tex, x, y, z, ry, w) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * 0.3125), new THREE.MeshBasicMaterial({ map: tex })); m.position.set(x, y, z); m.rotation.y = ry; G.add(m); };
  signMesh(sign('운전실', 'left', BRIDGE_C), -24.9, 3.3, -12.43, 0, 4.3);
  signMesh(sign('메인홀', 'right', HALL_C), -18.1, 3.3, -12.43, 0, 4.3);
  for (let x = -86; x <= 64; x += 12) World.lamps.push({ x, y: 5.2, z: -7.5, d: 0 });
  World.lamps.push({ x: -41.75, y: 3.9, z: 18, d: 0 }, { x: -33, y: 3.9, z: 10, d: 0 }, { x: -24.25, y: 3.9, z: 2.5, d: 0 });

  /* ---- 5b. the sliding doors onto the bridge and the hall: two leaves that part into the wall ---- */
  const dTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#434a5a'; g.fillRect(0, 0, w, h); g.fillStyle = '#373d4b'; g.fillRect(12, 12, w - 24, h - 24);
    for (let i = -h; i < w; i += 36) { g.fillStyle = 'rgba(232,176,64,0.85)'; g.beginPath(); g.moveTo(i, h); g.lineTo(i + 16, h); g.lineTo(i + 16 + 26, h - 26); g.lineTo(i + 26, h - 26); g.fill(); }
    g.fillStyle = 'rgba(80,190,255,0.8)'; g.fillRect(w - 18, h * 0.3, 6, h * 0.4);
  }));
  const dMat = new THREE.MeshStandardMaterial({ map: dTex, roughness: 0.5, metalness: 0.55 });
  for (const D of SHIP_DOORS) {
    const w = (D.z1 - D.z0) / 2, leaf = () => { const m = new THREE.Mesh(new THREE.BoxGeometry(0.3, D.h, w), dMat); m.position.set(D.x, D.h / 2, 0); m.castShadow = true; G.add(m); return m; };
    const d = Object.assign({}, D, { open: 0, mode: 'shut', a: leaf(), b: leaf(), col: addCollider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, 'metal') });
    d.col.door = true; d.a.position.z = D.z0 + w / 2; d.b.position.z = D.z1 - w / 2; Ship.doors.push(d);
    // a sign hung from the ceiling a few metres before the door, facing you as you come down the corridor: the name and 'straight on'
    const out = -D.inward, hx = D.x + out * 4.5, col = D.room === 'bridge' ? BRIDGE_C : HALL_C;
    signMesh(sign(D.name, 'up', col), hx, 4.5, -7.5, out > 0 ? Math.PI / 2 : -Math.PI / 2, 4.4);
    solid.push(B(0.04, 0.95, 0.04, hx, 5.52, -9.2, '#2a2f3a'), B(0.04, 0.95, 0.04, hx, 5.52, -5.8, '#2a2f3a'));
    glow.push(B(0.06, 0.1, D.z1 - D.z0 + 0.4, D.x + (D.x < 0 ? 0.32 : -0.32), D.h + 0.15, -7.5, '#e8b040'));
  }

  /* ---- 6. the bridge (운전실): 31 x 41 m and 16 m high. a two-storey wall of windows onto space, rows of consoles facing it,
     the commander's platform behind them, and an open gallery at 7 m round the other three sides, a wide stair up the north and south walls ---- */
  const BR = BRIDGE, GY = BR.gy;
  const win = new THREE.Mesh(new THREE.PlaneGeometry(27, 11), new THREE.MeshBasicMaterial({ map: space(0.62) })); win.position.set(BR.x0 + 0.03, 8, -7.5); win.rotation.y = Math.PI / 2; G.add(win);
  solid.push(B(0.2, 0.3, 27.4, BR.x0 + 0.1, 2.4, -7.5, '#2a2f3a'), B(0.2, 0.3, 27.4, BR.x0 + 0.1, 13.6, -7.5, '#2a2f3a'), B(0.2, 11.4, 0.3, BR.x0 + 0.1, 8, -7.5, '#2a2f3a'));
  // the gallery floor, in three runs, with a blue light along its edge
  const gal = [[BR.stairX1, BR.z0, BR.x1, BR.z0 + 5], [BR.stairX1, BR.z1 - 5, BR.x1, BR.z1], [BR.eastX, BR.z0 + 5, BR.x1, BR.z1 - 5]];
  for (const [x0, z0, x1, z1] of gal) { box(x0, GY - 0.4, z0, x1, GY, z1, '#2f3542'); }
  glow.push(B(BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z0 + 5.02, '#4fb8ff'), B(BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z1 - 5.02, '#4fb8ff'),
    B(0.05, 0.05, BR.z1 - BR.z0 - 10, BR.eastX - 0.02, GY - 0.2, (BR.z0 + BR.z1) / 2, '#4fb8ff'));
  // railings on its open edges (bullets and eyes go through them)
  const rails = [], railC = (x0, z0, x1, z1) => { const b = addCollider(x0, GY, z0, x1, GY + 1.1, z1, 'metal'); b.grate = true; };
  const railRun = (x0, z0, x1, z1) => { railC(x0, z0, x1, z1);
    const L = Math.max(x1 - x0, z1 - z0), along = x1 - x0 > z1 - z0, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    rails.push(along ? [L, 0.07, 0.07, cx, GY + 1.05, cz] : [0.07, 0.07, L, cx, GY + 1.05, cz], along ? [L, 0.05, 0.05, cx, GY + 0.55, cz] : [0.05, 0.05, L, cx, GY + 0.55, cz]);
    for (let t = 0; t <= L; t += 2.5) rails.push([0.08, 1.1, 0.08, along ? x0 + t : cx, GY + 0.55, along ? cz : z0 + t]); };
  railRun(BR.stairX1, BR.z0 + 4.95, BR.eastX, BR.z0 + 5.05); railRun(BR.stairX1, BR.z1 - 5.05, BR.eastX, BR.z1 - 4.95); railRun(BR.eastX - 0.05, BR.z0 + 5, BR.eastX + 0.05, BR.z1 - 5);
  // the stairs: sixteen steps of 0.44 m (people and robots both climb them), solid down to the floor
  const stepRun = (BR.stairX1 - BR.stairX0) / BR.steps, stairs = [];
  for (const [z0, z1] of [[BR.z0, BR.z0 + 5], [BR.z1 - 5, BR.z1]]) for (let k = 1; k <= BR.steps; k++) {
    const x0 = BR.stairX0 + (k - 1) * stepRun, h = (k / BR.steps) * GY; addCollider(x0, 0, z0, x0 + stepRun, h, z1, 'metal'); stairs.push([stepRun, h, z1 - z0, x0 + stepRun / 2, h / 2, (z0 + z1) / 2]);
    glow.push(B(stepRun * 0.9, 0.02, 0.06, x0 + stepRun / 2, h + 0.011, z0 === BR.z0 ? z1 - 0.1 : z0 + 0.1, '#e8b040'));
  }
  const stairMesh = new THREE.Mesh(mergeBoxes(stairs), new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 })); stairMesh.castShadow = stairMesh.receiveShadow = true; G.add(stairMesh);
  pipes.push(...rails.map((p) => { const g = new THREE.BoxGeometry(p[0], p[1], p[2]); g.translate(p[3], p[4], p[5]); return g; }));
  // ground floor: two rows of consoles facing the windows, the commander's platform behind them, and screens on the walls under the gallery
  const screens = [];
  for (const x of [-118.5, -113.5]) for (const z of [-19, -13.5, -1.5, 4]) {
    box(x - 0.5, 0, z - 1.3, x + 0.5, 1.05, z + 1.3, '#2c3240');
    screens.push(B(0.06, 0.55, 2.2, x - 0.3, 1.45, z, '#3fd0ff', [0, 0, 0.35]));
    glow.push(B(0.05, 0.03, 2.4, x + 0.48, 1.06, z, '#3a9cff'));
  }
  box(-108, 0, -11, -102, 0.45, -4, '#2a2f3a'); glow.push(B(6.04, 0.04, 0.04, -105, 0.46, -11, '#e8b040'), B(6.04, 0.04, 0.04, -105, 0.46, -4, '#e8b040'));
  box(-105.5, 0.45, -8.1, -104.5, 1.6, -6.9, '#3b4252'); solid.push(B(1.1, 0.12, 1.1, -105, 0.95, -7.5, '#5a6378'));
  // the main hall's key, stuck upright in the commander's console: a gold bow and collar over a short shaft, glowing so you can find it
  {
    const km = new THREE.MeshStandardMaterial({ color: 0xffc83a, metalness: 0.85, roughness: 0.25, emissive: 0x7a4c00, emissiveIntensity: 0.9 });
    const kg = new THREE.Group(); kg.position.set(SHIP_KEY.x, SHIP_KEY.y, SHIP_KEY.z);
    const part = (geo, y, x) => { const m = new THREE.Mesh(geo, km); m.position.set(x || 0, y, 0); m.castShadow = true; kg.add(m); return m; };
    part(new THREE.TorusGeometry(0.17, 0.05, 10, 24), 0.5); part(new THREE.BoxGeometry(0.16, 0.05, 0.09), 0.3); part(new THREE.BoxGeometry(0.065, 0.3, 0.065), 0.15);
    part(new THREE.BoxGeometry(0.08, 0.05, 0.05), 0.08, 0.06);
    const gl = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex('rgba(255,220,120,0.95)', 'rgba(255,170,40,0.2)'), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.7 }));
    gl.scale.setScalar(1.4); gl.position.y = 0.38; kg.add(gl);
    G.add(kg); Ship.keyObj = kg; Ship.keyGlow = gl;
  }
  for (const z of [BR.z0 + 0.4, BR.z1 - 0.4]) for (const x of [-104, -99]) { box(x - 1.4, 0, z - 0.3, x + 1.4, 1.1, z + 0.3, '#2c3240'); screens.push(B(2.4, 0.9, 0.05, x, 2.1, z + (z < 0 ? 0.3 : -0.3), '#3fd0ff')); }
  // up on the gallery: consoles against the walls, and a big status board high on the east wall
  for (const x of [-104, -98]) for (const z of [BR.z0 + 0.4, BR.z1 - 0.4]) { box(x - 1.4, GY, z - 0.3, x + 1.4, GY + 1.1, z + 0.3, '#2c3240'); screens.push(B(2.4, 0.9, 0.05, x, GY + 2.1, z + (z < 0 ? 0.3 : -0.3), '#3fd0ff')); }
  for (const z of [-19, -11, -4, 4]) { box(BR.x1 - 0.7, GY, z - 1.4, BR.x1 - 0.1, GY + 1.1, z + 1.4, '#2c3240'); screens.push(B(0.05, 0.9, 2.4, BR.x1 - 0.4, GY + 2.1, z, '#3fd0ff')); }
  screens.push(B(0.06, 2.6, 9, BR.x1 - 0.05, 12, -7.5, '#3fd0ff'));
  const scr = new THREE.Mesh(M(screens), new THREE.MeshBasicMaterial({ vertexColors: true })); G.add(scr); Ship.screens = scr;
  for (let x = -120; x <= -95; x += 6) for (const z of [-22, -14, -7.5, -1, 7]) glow.push(B(2.4, 0.05, 1.0, x, 15.97, z, '#dfeeff'));
  for (const [x0, z0, x1, z1] of gal) for (let x = x0 + 2; x < x1 - 1; x += 5) glow.push(B(1.6, 0.04, 0.6, x, GY - 0.42, (z0 + z1) / 2, '#cfe6ff'));
  World.lamps.push({ x: -115, y: 13, z: -16, d: 0 }, { x: -115, y: 13, z: 1, d: 0 }, { x: -104, y: 13, z: -7.5, d: 0 }, { x: -100, y: 5.6, z: -25.5, d: 0 }, { x: -100, y: 5.6, z: 10.5, d: 0 },
    { x: -100, y: GY + 3.5, z: -25.5, d: 0 }, { x: -100, y: GY + 3.5, z: 10.5, d: 0 }, { x: -94.5, y: GY + 3.5, z: -7.5, d: 0 });

  /* ---- 7. the main hall (메인홀): a stepped dais round the reactor, four pillars, tall cargo to hide behind, windows to the east ---- */
  /* 5.19: the hall's floor: solid round the walkway, and over the pit a grid of panels that break up and fall in at the boss's second
     phase; under them the stepped pit (drawn and solid all along, but out of sight and out of reach until then) */
  {
    const HR = SHIP_ROOMS[2], P = PYR, cx = P.cx, cz = P.cz, BOT = P.bottom, rx0 = cx - P.ox, rx1 = cx + P.ox, rz0 = cz - P.oz, rz1 = cz + P.oz;
    const strip = (xa, za, xb, zb, y) => { const fg = new THREE.PlaneGeometry(xb - xa, zb - za), uv = fg.attributes.uv;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, (xa + uv.getX(i) * (xb - xa)) / 6, (zb - uv.getY(i) * (zb - za)) / 6);
      const f = new THREE.Mesh(fg, floorMat.hall); f.rotation.x = -Math.PI / 2; f.position.set((xa + xb) / 2, y, (za + zb) / 2); f.receiveShadow = true; G.add(f); return f; };
    strip(HR[0], HR[1], HR[2], rz0, 0.002); strip(HR[0], rz1, HR[2], HR[3], 0.002); strip(HR[0], rz0, rx0, rz1, 0.002); strip(rx1, rz0, HR[2], rz1, 0.002);
    const bottom = strip(cx - P.bx, cz - P.bz, cx + P.bx, cz + P.bz, BOT + 0.002); bottom.visible = false;
    const NX = 8, NZ = 8, tw = 2 * P.ox / NX, td = 2 * P.oz / NZ, tiles = [], tg = new THREE.BoxGeometry(tw - 0.04, 0.14, td - 0.04);
    for (let i = 0; i < NX; i++) for (let k = 0; k < NZ; k++) { const t = new THREE.Mesh(tg, floorMat.hall); t.position.set(rx0 + (i + 0.5) * tw, -0.068, rz0 + (k + 0.5) * td); t.receiveShadow = true; G.add(t); tiles.push(t); }
    const stepTex = keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#262b34'; g.fillRect(0, 0, w, h); speckle(g, w, h, 2600, ['#2a3039', '#21252d', '#2e343f'], 1.4);
      g.strokeStyle = 'rgba(8,10,14,0.9)'; g.lineWidth = 3; for (let k = 0; k <= 4; k++) { g.beginPath(); g.moveTo(k * w / 4, 0); g.lineTo(k * w / 4, h); g.stroke(); }
      g.fillStyle = 'rgba(150,175,210,0.10)'; for (let y = 6; y < h; y += 14) g.fillRect(0, y, w, 2);
    }, 1, 1));
    const stepGeos = [], landGeos = [], pglow = [];
    const band = (xa, za, xb, zb, top, list) => { const c = addCollider(xa, BOT, za, xb, top, zb, 'metal'); c.step = true; list.push(uvBox(xa, BOT, za, xb, top, zb, list === landGeos ? 6 : 2)); };
    const T2 = 0.3; // the pit's own wall, just outside the rim
    band(rx0 - T2, rz0 - T2, rx1 + T2, rz0, 0, stepGeos); band(rx0 - T2, rz1, rx1 + T2, rz1 + T2, 0, stepGeos); band(rx0 - T2, rz0, rx0, rz1, 0, stepGeos); band(rx1, rz0, rx1 + T2, rz1, 0, stepGeos);
    for (const st of P.steps) {
      const ix = st.ax - st.w, iz = st.az - st.w, list = st.land ? landGeos : stepGeos;
      band(cx - st.ax, cz - st.az, cx + st.ax, cz - iz, st.y, list); band(cx - st.ax, cz + iz, cx + st.ax, cz + st.az, st.y, list);
      band(cx - st.ax, cz - iz, cx - ix, cz + iz, st.y, list); band(cx + ix, cz - iz, cx + st.ax, cz + iz, st.y, list);
      const col = st.land || st.k === P.steps.length ? '#6fd2ff' : '#3a8ee6', y = st.y - 0.035, e = 0.01, t = 0.09, hh = 0.1;
      pglow.push(B(2 * ix + 2 * t, hh, t, cx, y, cz - iz - e, col), B(2 * ix + 2 * t, hh, t, cx, y, cz + iz + e, col), B(t, hh, 2 * iz + 2 * t, cx - ix - e, y, cz, col), B(t, hh, 2 * iz + 2 * t, cx + ix + e, y, cz, col));
    }
    const rw = 0.16;
    pglow.push(B(2 * P.ox + 2 * rw, 0.02, rw, cx, 0.012, rz0 - rw / 2, '#e8b040'), B(2 * P.ox + 2 * rw, 0.02, rw, cx, 0.012, rz1 + rw / 2, '#e8b040'), B(rw, 0.02, 2 * P.oz, rx0 - rw / 2, 0.012, cz, '#e8b040'), B(rw, 0.02, 2 * P.oz, rx1 + rw / 2, 0.012, cz, '#e8b040'));
    pglow.push(B(4.2, 0.9, 4.2, cx, BOT + 0.45, cz, '#353b48'));
    const stepMesh = new THREE.Mesh(mergeGeos(stepGeos), new THREE.MeshStandardMaterial({ map: stepTex, roughness: 0.55, metalness: 0.5 })); stepMesh.castShadow = stepMesh.receiveShadow = true;
    const landMesh = new THREE.Mesh(mergeGeos(landGeos), floorMat.hall); landMesh.castShadow = landMesh.receiveShadow = true;
    const pitGlow = new THREE.Mesh(M(pglow), glowMat);
    for (const m of [stepMesh, landMesh, pitGlow]) { m.visible = false; G.add(m); }
    // the dais round the reactor stands on the panels: its own mesh and colliders, so it can go with them
    const dsol = [], dglow = [], cols = [];
    DAIS.forEach(([x0, z0, x1, z1, y], k) => { cols.push(addCollider(x0, 0, z0, x1, y, z1, 'metal')); dsol.push(B(x1 - x0, y, z1 - z0, (x0 + x1) / 2, y / 2, (z0 + z1) / 2, k === 2 ? '#3d4454' : k === 1 ? '#353b48' : '#2f3542'));
      for (const [a, b, c, d] of [[x0, z0, x1, z0], [x0, z1, x1, z1], [x0, z0, x0, z1], [x1, z0, x1, z1]]) dglow.push(B(Math.max(0.04, Math.abs(c - a)), 0.03, Math.max(0.04, Math.abs(d - b)), (a + c) / 2, y + 0.01, (b + d) / 2, '#4fb8ff')); });
    const dais = new THREE.Mesh(M(dsol), kitMat); dais.castShadow = dais.receiveShadow = true; const daisGlow = new THREE.Mesh(M(dglow), glowMat); G.add(dais, daisGlow);
    Ship.pit = { tiles, cols, dais, daisGlow, show: [stepMesh, landMesh, pitGlow, bottom] };
  }
  addCollider(REACTOR.x - REACTOR.r, PYR.bottom, REACTOR.z - REACTOR.r, REACTOR.x + REACTOR.r, 16, REACTOR.z + REACTOR.r, 'metal'); // 5.19: from the pit's floor
  const coreMat = new THREE.MeshBasicMaterial({ color: 0x8fd8ff }); Ship.coreMat = coreMat;
  const coreH = 16 - PYR.bottom; const core = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, coreH, 24), coreMat); core.position.set(REACTOR.x, PYR.bottom + coreH / 2, REACTOR.z); G.add(core);
  for (let i = 0; i < 8; i++) { const a = (i / 8) * TAU; solid.push(B(0.22, coreH, 0.22, REACTOR.x + Math.cos(a) * 1.55, PYR.bottom + coreH / 2, REACTOR.z + Math.sin(a) * 1.55, '#3a4150')); }
  for (const y of [-7, -4, -1, 2.4, 5.5, 9, 12.5]) { const g = new THREE.TorusGeometry(1.6, 0.12, 6, 28); g.rotateX(Math.PI / 2); g.translate(REACTOR.x, y, REACTOR.z); pipes.push(g); }
  const ring = new THREE.Mesh(new THREE.TorusGeometry(12, 0.22, 6, 64), new THREE.MeshBasicMaterial({ color: 0x4fb8ff })); ring.rotation.x = Math.PI / 2; ring.position.set(REACTOR.x, 15.6, REACTOR.z); G.add(ring); Ship.ring = ring;
  for (const [x, z] of HALL_PILLARS) { box(x - 1.2, 0, z - 1.2, x + 1.2, 16, z + 1.2, '#353b48'); glow.push(B(2.44, 0.1, 0.04, x, 3, z - 1.22, '#3a9cff'), B(2.44, 0.1, 0.04, x, 3, z + 1.22, '#3a9cff')); }
  const pickC = () => ['#4b5568', '#5a4a3a', '#3e5a52', '#5a3e44', '#41495c'][Math.floor(R() * 5)];
  for (const [x, z, w, d] of [[78, 9, 2.6, 5.2], [100, 37, 5.2, 2.6], [134, 37, 5.2, 2.6], [156, -6, 2.6, 5.2], [96, -41, 5.2, 2.6], [132, -41, 5.2, 2.6],
    [86, 22, 5.2, 2.6], [86, -26, 5.2, 2.6], [78, -22, 2.6, 5.2]]) { // the old six, and three more for the bigger floor
    const h = r(5.0, 5.8), c = pickC(); box(x - w / 2, 0, z - d / 2, x + w / 2, h, z + d / 2, c);
    solid.push(B(w + 0.06, 0.18, d + 0.06, x, h * 0.36, z, '#e8b040'), B(w + 0.06, 0.18, d + 0.06, x, h * 0.86, z, '#e8b040'), B(w + 0.04, 0.08, d + 0.04, x, h * 0.5, z, '#1c2028'));
  }
  const hw = new THREE.Mesh(new THREE.PlaneGeometry(56, 7), new THREE.MeshBasicMaterial({ map: space(0.4) })); hw.position.set(161.97, 9, -1.5); hw.rotation.y = -Math.PI / 2; G.add(hw);
  for (let x = 80; x <= 152; x += 9) for (let z = -38; z <= 34; z += 9) if (Math.hypot(x - REACTOR.x, z - REACTOR.z) > 14) glow.push(B(3, 0.06, 1.2, x, 15.97, z, '#dfeeff'));
  for (const y of [2.4, 9]) glow.push(B(0.04, 0.1, 93, 161.96, y, -1.5, '#3a9cff'), B(94, 0.1, 0.04, 115, y, -47.96, '#3a9cff'), B(94, 0.1, 0.04, 115, y, 44.96, '#3a9cff'));
  [[84, 12, -34], [84, 12, 26], [152, 12, -30], [152, 12, 26], [120, 13, -6], [100, 6, -6], [140, 6, -6], [120, 6, 26], [120, 6, -36], [76, 8, -2], [160, 8, -2]].forEach(([x, y, z]) => World.lamps.push({ x, y, z, d: 0 }));
  // eight hatches in the floor, shut and dark until the boss's third phase (then two leaves slide apart over a red glow)
  const hatchLid = new THREE.MeshStandardMaterial({ color: 0x2a2f38, roughness: 0.45, metalness: 0.7 });
  // a column of red light standing up out of each open hatch, bright at the floor and gone by head height
  const shaftTex = (() => { const c = document.createElement('canvas'); c.width = 4; c.height = 64; const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 64);
    gr.addColorStop(0, '#000'); gr.addColorStop(0.55, '#2a0800'); gr.addColorStop(1, '#ff5a22'); g.fillStyle = gr; g.fillRect(0, 0, 4, 64); return new THREE.CanvasTexture(c); })();
  const shaftMat = new THREE.MeshBasicMaterial({ map: shaftTex, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false });
  for (const [x, z, y] of HATCHES) {
    glow.push(B(2.7, 0.01, 0.14, x, 0.011, z - 1.28, '#e8b040'), B(2.7, 0.01, 0.14, x, 0.011, z + 1.28, '#e8b040'), B(0.14, 0.01, 2.7, x - 1.28, 0.011, z, '#e8b040'), B(0.14, 0.01, 2.7, x + 1.28, 0.011, z, '#e8b040'));
    const lidA = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.06, 2.4), hatchLid), lidB = lidA.clone(); lidA.position.set(x - 0.6, 0.035, z); lidB.position.set(x + 0.6, 0.035, z); G.add(lidA, lidB);
    const gl = new THREE.Mesh(new THREE.PlaneGeometry(2.3, 2.3), new THREE.MeshBasicMaterial({ color: 0xff4a1e, transparent: true, opacity: 0.9, toneMapped: false }));
    gl.rotation.x = -Math.PI / 2; gl.position.set(x, 0.012, z); gl.visible = false; G.add(gl);
    const sh = new THREE.Mesh(new THREE.CylinderGeometry(1.15, 1.25, 3.4, 16, 1, true), shaftMat); sh.position.set(x, 1.7, z); sh.visible = false; G.add(sh);
    Ship.hatches.push({ x, z, y, lidA, lidB, glow: gl, shaft: sh, open: false, k: 0 });
  }

  /* ---- light and draw ---- */
  const pipeMesh = new THREE.Mesh(mergeGeos(pipes), new THREE.MeshStandardMaterial({ color: 0x59627a, roughness: 0.45, metalness: 0.6 })); G.add(pipeMesh);
  const solidMesh = new THREE.Mesh(M(solid), kitMat); solidMesh.castShadow = solidMesh.receiveShadow = true; G.add(solidMesh);
  G.add(new THREE.Mesh(M(glow), glowMat));

  /* walking grid: only inside the ship */
  World.navMask = (x, z) => !!shipRoom(x, z);
  /* supply crates along the corridor, in the bridge and round the hall */
  const fits = (x, z) => { const Rm = shipRoom(x, z); if (!Rm || Rm[5] === 'pass') return false;
    if (inPit(x, z, 1.4) || boxAt(x, z, 1.3, 0.05, 1.25)) return false; // never on the floor over the pit
    return x > Rm[0] + 1.2 && x < Rm[2] - 1.2 && z > Rm[1] + 1.2 && z < Rm[3] - 1.2; };
  const onGallery = (x, z) => x >= BRIDGE.stairX0 - 1 && x <= BRIDGE.x1 && (z <= BRIDGE.z0 + 6.2 || z >= BRIDGE.z1 - 6.2 || x >= BRIDGE.eastX - 1.2);
  placeCrates(G, S.crates, () => { const k = R(); return k < 0.45 ? [r(-90, 66), r(-11.8, -3.2)] : k < 0.65 ? [r(-122, -98), r(-22, 7)] : [r(69, 161), r(-47.5, 43.5)]; },
    (x, z) => fits(x, z) && !onGallery(x, z) && !HATCHES.some(([hx, hz]) => Math.hypot(hx - x, hz - z) < 2.6) && Math.abs(x - SHIP_DOORS[0].x) > 3 && Math.abs(x - SHIP_DOORS[1].x) > 3);
  World.menuCam = { x: REACTOR.x, z: REACTOR.z, r: 22, h: 8, look: 4 };

  indexColliders(); buildNav();
  return { start: { x: SHIP_START.x, z: SHIP_START.z, yaw: SHIP_START.yaw }, spawns: [], map: {} };
}
