/* ============ stage 3-1: the watchtower in the middle of the safari ============ */
// a log tower on a solid plank skirt, so nothing gets underneath it. the skirt reaches out further than the platform above,
// so from the railing you can see (and shoot) whatever is at its foot. 10,000 to knock down; while you stand up there
// the animals go for the tower first (all but the giraffes, whose necks reach you over the railing).
// the steps are 0.48 m: you climb them, no animal can (they only step up 0.45 m).
const TOWER = { hp: 10000, ph: 3.84, half: 2.6, base: 3.2, step: 0.48, steps: 8 };
const Tower = (() => {
  const T = { active: false, standing: false, hp: 0, maxHp: TOWER.hp, x: 0, z: 0, group: null, inner: null, cols: [], fallT: -1, fallDir: 1, shake: 0,
    marks: {}, on: false, crackT: 0, hintT: 0, sinkT: 0 };
  const _q = { x: 0, z: 0 };
  function reset() { Object.assign(T, { active: false, standing: false, hp: 0, group: null, inner: null, cols: [], slots: [], fallT: -1, shake: 0, marks: {}, on: false, crackT: 0, hintT: 0, landed: false }); }
  function build(G, x, z) {
    reset(); T.active = true; T.standing = true; T.hp = T.maxHp = TOWER.hp; T.x = x; T.z = z;
    const keep = World.keep, PH = TOWER.ph, H = TOWER.half, Bh = TOWER.base;
    const plankTex = keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#7d5b3a'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 8; i++) { g.fillStyle = pick(['#86613e', '#74533a', '#8c6943', '#6e4f33']); g.fillRect(i * 32 + 1, 0, 30, h); g.fillStyle = 'rgba(30,18,8,0.55)'; g.fillRect(i * 32, 0, 2, h); }
      speckle(g, w, h, 1400, ['rgba(60,40,20,0.35)', 'rgba(150,110,70,0.25)'], 2);
      for (let i = 0; i < 16; i++) { g.fillStyle = 'rgba(40,26,12,0.6)'; g.beginPath(); g.arc(rand(0, w), rand(0, h), rand(1.5, 3), 0, TAU); g.fill(); }
    }, 1, 1));
    plankTex.wrapS = plankTex.wrapT = THREE.RepeatWrapping;
    const plank = new THREE.MeshStandardMaterial({ map: plankTex, roughness: 0.9 });
    const beam = new THREE.MeshStandardMaterial({ color: 0x5a3f28, roughness: 0.92 });
    const tin = new THREE.MeshStandardMaterial({ color: 0x8b8f92, roughness: 0.55, metalness: 0.55, side: THREE.DoubleSide });
    const outer = new THREE.Group(); outer.position.set(x, 0, z); G.add(outer);
    const inner = new THREE.Group(); outer.add(inner);
    T.group = outer; T.inner = inner;
    const mesh = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = true; m.receiveShadow = true; inner.add(m); return m; };
    // the skirt: four plank walls, a sill and a cap
    const skirt = new THREE.BoxGeometry(2 * Bh, 2.0, 2 * Bh); skirt.translate(0, 1.0, 0);
    const uv = skirt.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 2.5, uv.getY(i) * 0.8);
    mesh(skirt, plank);
    // the frame above it: corner legs, cross braces, the platform, joists
    const parts = [];
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) parts.push([0.42, PH - 1.9, 0.42, sx * (H - 0.2), 1.9 + (PH - 1.9) / 2 - 0.12, sz * (H - 0.2)]);
    parts.push([2 * Bh + 0.12, 0.16, 0.16, 0, 2.06, Bh], [2 * Bh + 0.12, 0.16, 0.16, 0, 2.06, -Bh], [0.16, 0.16, 2 * Bh + 0.12, Bh, 2.06, 0], [0.16, 0.16, 2 * Bh + 0.12, -Bh, 2.06, 0]);
    parts.push([2 * H + 0.2, 0.22, 0.22, 0, PH - 0.35, H], [2 * H + 0.2, 0.22, 0.22, 0, PH - 0.35, -H], [0.22, 0.22, 2 * H + 0.2, H, PH - 0.35, 0], [0.22, 0.22, 2 * H + 0.2, -H, PH - 0.35, 0]);
    mesh(mergeBoxes(parts), beam);
    // diagonal braces on each side of the open frame
    const braces = [];
    const brace = (ax, az, bx, bz, y0, y1) => { const len = Math.hypot(bx - ax, bz - az, y1 - y0), g = new THREE.BoxGeometry(0.14, len, 0.14);
      const o = new THREE.Object3D(); o.position.set((ax + bx) / 2, (y0 + y1) / 2, (az + bz) / 2); o.lookAt(bx, y1, bz); o.rotateX(Math.PI / 2); o.updateMatrix(); g.applyMatrix4(o.matrix); braces.push(g); };
    const e = H - 0.2;
    for (const s of [-1, 1]) { brace(-e, s * e, e, s * e, 2.1, PH - 0.4); brace(e, s * e, -e, s * e, 2.1, PH - 0.4); brace(s * e, -e, s * e, e, 2.1, PH - 0.4); brace(s * e, e, s * e, -e, 2.1, PH - 0.4); }
    mesh(mergeGeos(braces), beam);
    const floor = new THREE.BoxGeometry(2 * H, 0.24, 2 * H); floor.translate(0, PH - 0.12, 0);
    const fuv = floor.attributes.uv; for (let i = 0; i < fuv.count; i++) fuv.setXY(i, fuv.getX(i) * 2, fuv.getY(i) * 2);
    mesh(floor, plank);
    // railing: posts and two rails, open on the south side where the steps come up
    const rail = [], top = PH + 1.05, mid = PH + 0.55;
    for (const [px, pz] of [[-H, -H], [H, -H], [-H, H], [H, H], [0, -H], [-H, 0], [H, 0], [-0.8, H], [0.8, H]]) rail.push([0.12, 1.1, 0.12, px, PH + 0.55, pz]);
    for (const y of [mid, top]) {
      rail.push([2 * H, 0.08, 0.08, 0, y, -H], [0.08, 0.08, 2 * H, -H, y, 0], [0.08, 0.08, 2 * H, H, y, 0]);
      rail.push([H - 0.8, 0.08, 0.08, -(H + 0.8) / 2, y, H], [H - 0.8, 0.08, 0.08, (H + 0.8) / 2, y, H]);
    }
    // the roof: four poles and a tin pyramid
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) rail.push([0.14, 6.7 - PH, 0.14, sx * (H - 0.12), PH + (6.7 - PH) / 2, sz * (H - 0.12)]);
    mesh(mergeBoxes(rail), beam);
    const roof = new THREE.ConeGeometry(H * 1.55, 1.3, 4, 1, true); roof.rotateY(Math.PI / 4); roof.translate(0, 6.7 + 0.65, 0);
    mesh(roof, tin);
    // the steps: solid blocks from the ground, with stringers and a handrail each side
    const steps = [], side = [];
    for (let k = 1; k <= TOWER.steps; k++) { const h = k * TOWER.step, z0 = H + 0.5 * (TOWER.steps - k); steps.push([1.4, h, 0.5, 0, h / 2, z0 + 0.25]); }
    const run = 0.5 * TOWER.steps, ang = Math.atan2(PH, run), len = Math.hypot(PH, run);
    for (const sx of [-0.78, 0.78]) {
      const s1 = new THREE.BoxGeometry(0.1, 0.3, len); s1.rotateX(ang); s1.translate(sx, PH / 2 - 0.05, H + run / 2); side.push(s1);
      const s2 = new THREE.BoxGeometry(0.07, 0.07, len); s2.rotateX(ang); s2.translate(sx, PH / 2 + 1.0, H + run / 2); side.push(s2);
      for (let k = 0; k <= 2; k++) { const zz = H + run - k * run / 2 - 0.1, yy = PH * (k / 2); const p = new THREE.BoxGeometry(0.08, 1.0, 0.08); p.translate(sx, yy + 0.5, zz); side.push(p); }
    }
    const stepGeo = mergeBoxes(steps), suv = stepGeo.attributes.uv; for (let i = 0; i < suv.count; i++) suv.setXY(i, suv.getX(i) * 0.6, suv.getY(i) * 1.4);
    mesh(stepGeo, plank); mesh(mergeGeos(side), beam);
    // a sign on the railing
    const signTex = keep(canvasTex(256, 96, (g, w, h) => { g.fillStyle = '#e6d6a6'; g.fillRect(0, 0, w, h); g.fillStyle = '#6a3a1e'; g.fillRect(0, 0, w, 8); g.fillRect(0, h - 8, w, 8);
      g.fillStyle = '#3a2412'; g.font = '46px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('감시탑', w / 2, h / 2 + 2); }));
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 0.56), new THREE.MeshStandardMaterial({ map: signTex, roughness: 0.8 }));
    sign.position.set(-1.7, PH + 0.8, H + 0.07); inner.add(sign);
    // colliders: the skirt and the steps are solid; the platform; the railing and poles let bullets and eyes through (grate)
    const add = (minx, miny, minz, maxx, maxy, maxz, grate) => { const b = addCollider(x + minx, miny, z + minz, x + maxx, maxy, z + maxz, 'wood'); b.tower = true; if (grate) b.grate = true; T.cols.push(b); return b; };
    add(-Bh, 0, -Bh, Bh, 2.0, Bh);
    add(-H, PH - 0.24, -H, H, PH, H);
    for (let k = 1; k <= TOWER.steps; k++) { const h = k * TOWER.step, z0 = H + 0.5 * (TOWER.steps - k); add(-0.7, 0, z0, 0.7, h, z0 + 0.5); }
    add(-H, PH, -H - 0.06, H, PH + 1.1, -H + 0.06, true); add(-H - 0.06, PH, -H, -H + 0.06, PH + 1.1, H, true); add(H - 0.06, PH, -H, H + 0.06, PH + 1.1, H, true);
    add(-H, PH, H - 0.06, -0.75, PH + 1.1, H + 0.06, true); add(0.75, PH, H - 0.06, H, PH + 1.1, H + 0.06, true);
    add(-H - 0.1, 6.7, -H - 0.1, H + 0.1, 7.0, H + 0.1);
    // the places along its foot where an animal can get at it: about one every 1.9 m round the skirt and the steps.
    // only that many hit it at once; the rest wait their turn a little way off
    T.slots = [];
    const sEnd = H + 0.5 * TOWER.steps;
    const along = (x0, z0, x1, z1, nx, nz) => { const L = Math.hypot(x1 - x0, z1 - z0), n = Math.max(1, Math.round(L / 1.9));
      for (let i = 0; i < n; i++) { const t = (i + 0.5) / n; T.slots.push({ x: x + x0 + (x1 - x0) * t, z: z + z0 + (z1 - z0) * t, nx, nz, owner: null, t: -9 }); } };
    along(-Bh, -Bh, Bh, -Bh, 0, -1); along(-Bh, -Bh, -Bh, Bh, -1, 0); along(Bh, -Bh, Bh, Bh, 1, 0);
    along(-Bh, Bh, -0.7, Bh, 0, 1); along(0.7, Bh, Bh, Bh, 0, 1);
    along(-0.7, Bh, -0.7, sEnd, -1, 0); along(0.7, Bh, 0.7, sEnd, 1, 0); along(-0.7, sEnd, 0.7, sEnd, 0, 1);
    return T;
  }
  /* a place at the tower for this animal: the one it already has, or the free one nearest to it. null: all taken, wait */
  function claim(e) {
    const s0 = e.slot;
    if (s0 && s0.owner === e) { s0.t = time; return s0; }
    let best = null, bd = Infinity;
    for (const s of T.slots) {
      if (s.owner && s.owner !== e && s.owner.alive && time - s.t < 0.6) continue;
      const d = Math.hypot(s.x - e.pos.x, s.z - e.pos.z); if (d < bd) { bd = d; best = s; }
    }
    if (best) { best.owner = e; best.t = time; e.slot = best; }
    return best;
  }
  /* where you are: up on the platform, or high enough on the steps that nothing but a giraffe reaches you */
  function playerOn() {
    if (!T.standing) return false;
    const px = player.pos.x - T.x, pz = player.pos.z - T.z, py = player.pos.y;
    if (py > TOWER.ph - 0.6 && Math.abs(px) < TOWER.half + 0.1 && Math.abs(pz) < TOWER.half + 0.1) return true;
    return py > 2.3 && Math.abs(px) < 0.8 && pz > TOWER.half - 0.1 && pz < TOWER.half + 0.5 * TOWER.steps + 0.1;
  }
  /* the closest point of the tower's foot (skirt or steps) to a spot on the ground */
  function nearest(x, z, out) {
    const lx = x - T.x, lz = z - T.z, B = TOWER.base;
    let ax = clamp(lx, -B, B), az = clamp(lz, -B, B);
    const sz0 = TOWER.half, sz1 = TOWER.half + 0.5 * TOWER.steps;
    const bx = clamp(lx, -0.7, 0.7), bz = clamp(lz, sz0, sz1);
    if (Math.hypot(lx - bx, lz - bz) < Math.hypot(lx - ax, lz - az)) { ax = bx; az = bz; }
    out.x = T.x + ax; out.z = T.z + az; return out;
  }
  function hurt(dmg, e, at) {
    if (!T.standing || Game.ended || !(dmg > 0)) return;
    T.hp = Math.max(0, T.hp - dmg); T.shake = Math.min(1, T.shake + 0.2 + dmg / 60);
    if (at) { FX.chunks(at, dmg >= 40 ? 4 : 2, 0.12, 'wood'); FX.puff(at, dmg >= 40 ? 3 : 1, 0.55, 0.5); }
    if (T.crackT <= 0) { T.crackT = 0.12; Sound.crack(at || T.group.position); if (dmg >= 40) Sound.thud(at || T.group.position); }
    if (T.on) { player.shake = Math.max(player.shake, 0.05 + dmg / 500); if (dmg >= 40) buzz(40); }
    const f = T.hp / T.maxHp;
    for (const m of [0.75, 0.5, 0.25, 0.1]) if (f <= m && !T.marks[m]) { T.marks[m] = true; HUD.banner('감시탑 체력 ' + Math.round(m * 100) + '%', m <= 0.25 ? '곧 무너집니다! 탑을 치는 동물부터 잡으세요' : '탑을 공격하는 동물을 쏘세요', 2); }
    if (T.hp <= 0) collapse();
  }
  /* down it comes: the colliders go at once, the frame topples away from the steps and sinks into a heap of dust */
  function collapse() {
    if (!T.standing) return;
    const was = playerOn();
    T.standing = false; T.on = false; T.fallT = 0; T.fallDir = Math.random() < 0.5 ? 1 : -1;
    for (const b of T.cols) removeCollider(b);
    T.cols = []; buildNav(); updateFlow(player.pos.x, player.pos.z);
    const c = { x: T.x, y: 1.5, z: T.z };
    Sound.crack(c); Sound.quake(c); Sound.boom(c, false);
    for (let i = 0; i < 14; i++) { const a = (i / 14) * TAU; FX.puff({ x: T.x + Math.cos(a) * 3.5, y: 0.5, z: T.z + Math.sin(a) * 3.5 }, 2, 0.6, 1.4); }
    FX.chunks({ x: T.x, y: 3, z: T.z }, 18, 0.3, 'wood');
    player.shake = Math.max(player.shake, 0.7); buzz(260);
    if (was) {
      // you come down with it: thrown clear, a second to get your bearings
      player.grounded = false; player.vel.y = 2.5; player.vel.x += T.fallDir * 2; player.stunT = Math.max(player.stunT, 1);
      Gun.trigger = false; Gun.adsHeld = false;
      HUD.banner('감시탑이 무너졌습니다', '땅으로 떨어졌습니다 · 이제 동물들이 나를 노립니다', 3);
    } else HUD.banner('감시탑이 무너졌습니다', '이제 숨을 곳이 없습니다', 2.6);
    HUD.feed('감시탑 붕괴', 0, 'hs');
  }
  function update(dt) {
    if (!T.active) return;
    T.crackT -= dt;
    T.on = playerOn();
    if (T.on && T.hintT <= 0 && !Game.ended) { T.hintT = 1e9; HUD.hint('감시탑 위 · 동물들은 탑부터 공격합니다 (기린은 목으로 탑 위까지 칩니다)', 3.2); }
    if (T.standing) {
      T.shake = Math.max(0, T.shake - dt * 2.2);
      const lean = (1 - T.hp / T.maxHp) * 0.035, s = T.shake * 0.06;
      T.inner.position.set(rand(-1, 1) * s, 0, rand(-1, 1) * s); T.inner.rotation.set(lean * 0.6, 0, lean);
    } else if (T.fallT >= 0) {
      T.fallT += dt;
      const t = T.fallT, k = Math.min(1, t / 1.5), a = k * k * 1.45;
      T.inner.rotation.set(0, 0, T.fallDir * a); T.inner.position.set(T.fallDir * Math.sin(a) * 1.6, -Math.max(0, t - 1.5) * 1.2, 0);
      if (t > 1.5 && !T.landed) { T.landed = true; const p = { x: T.x + T.fallDir * 5, y: 0.5, z: T.z }; Sound.quake(p); for (let i = 0; i < 10; i++) FX.puff({ x: p.x + rand(-3, 3), y: 0.4, z: p.z + rand(-3, 3) }, 2, 0.6, 1.6); }
      if (t > 4) { T.group.visible = false; T.fallT = -1; }
    }
  }
  return Object.assign(T, { build, reset, playerOn, nearest, claim, hurt, collapse, update, holds() { return T.standing && T.on; } });
})();
