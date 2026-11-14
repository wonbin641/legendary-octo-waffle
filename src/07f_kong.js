/* ============ the lab's boss: a giant lowland gorilla, and the smaller gorillas it calls down ============ */
// boss: huge and fast. big alternating haymakers (500 a hit), frequent straight-line charges (300 and a 3 s stun, almost no recovery),
// now and then a huge leap that lands where you stood (instant death inside the red ring), and a chest-beating roar that calls 7 gorillas.
// minions: a quarter of the boss's health and damage, the same punches and charges, but the charge is slow with a long recovery,
// it stuns for 1 s, and they never leap.
const KONG = {
  boss: { run: 7.6, charge: 24, chargeT: 1.15, windup: 0.32, recover: 0.12, punch: 500, chargeDmg: 300, stun: 3, swing: 0.62, chargeCd: [2.2, 3.6], reach: 1.9 },
  minion: { run: 6.0, charge: 12, chargeT: 1.4, windup: 0.8, recover: 1.7, punch: 125, chargeDmg: 75, stun: 1, swing: 0.72, chargeCd: [5, 8], reach: 0.75 },
  slamR: 5.5, summonMax: 4, minionsAt: 7,
};
const KNUCKLE = { lean: 0.6, twist: 0, head: -0.35, aLx: -1.1, aLy: 0, aRx: -1.1, aRy: 0, fL: 0.15, fR: 0.15, lL: 0, lR: 0, sL: 0, sR: 0, y: 0 };
const KONG_HIP = 0.62;
function kongPose(rig, P, k) {
  const c = rig.pose || (rig.pose = Object.assign({}, P));
  for (const key in P) c[key] += (P[key] - c[key]) * k;
  rig.torso.rotation.x = c.lean; rig.torso.rotation.y = c.twist; rig.head.rotation.x = c.head;
  rig.armL.rotation.x = c.aLx; rig.armL.rotation.y = c.aLy; rig.armR.rotation.x = c.aRx; rig.armR.rotation.y = c.aRy;
  rig.foreL.rotation.x = c.fL; rig.foreR.rotation.x = c.fR;
  rig.legL.rotation.x = c.lL; rig.legR.rotation.x = c.lR; rig.shinL.rotation.x = c.sL; rig.shinR.rotation.x = c.sR;
  rig.hips.position.y = KONG_HIP + c.y;
}
/* big animals do not stop for a wooden crate: they smash it */
function smashAhead(e, dx, dz) {
  const b = collideAt(e.pos.x + dx * 0.45, e.pos.y + 0.05, e.pos.z + dz * 0.45, e.R, Math.min(e.H, 2));
  if (b && b.ref && b.kind === 'wood' && crates.includes(b.ref)) { damageCrate(b.ref, 999, { x: b.ref.x, y: (b.ref.y || 0) + 0.6, z: b.ref.z }); return true; }
  return false;
}
const KongKit = (() => {
  const B = AnimalKit.geoBox, M = AnimalKit.merge;
  function build(boss) {
    const fur = '#1d1c1e', dark = '#141315', skin = '#37312e', silver = boss ? '#9a9a9c' : '#4b4a4c', eye = boss ? '#d33a1a' : '#c08a2a';
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.88, emissive: 0x000000 });
    const g = new THREE.Group(); g.rotation.order = 'YXZ';
    const mesh = (parent, list) => { const m = new THREE.Mesh(M(list), mat); m.castShadow = !isTouch; parent.add(m); return m; };
    // a gorilla's build: a huge chest and shoulders, a silver saddle, long thick arms, short legs, the head sunk between the shoulders
    const hips = new THREE.Group(); hips.position.set(0, KONG_HIP, -0.1); g.add(hips);
    const torso = new THREE.Group(); torso.rotation.order = 'YXZ'; hips.add(torso);
    const body = mesh(torso, [B(1.12, 0.86, 0.72, 0, 0.5, 0.05, fur), B(0.86, 0.46, 0.62, 0, 0.1, 0.07, fur), B(1.3, 0.38, 0.7, 0, 0.84, 0.02, fur),
      B(0.82, 0.56, 0.08, 0, 0.46, -0.33, silver), B(0.66, 0.4, 0.06, 0, 0.54, 0.43, skin), B(0.5, 0.3, 0.06, 0, 0.12, 0.39, skin)]);
    const chest = new THREE.Object3D(); chest.position.set(0, 0.5, 0.1); torso.add(chest);
    const head = new THREE.Group(); head.position.set(0, 0.95, 0.26); torso.add(head);
    mesh(head, [B(0.48, 0.46, 0.46, 0, 0.1, 0, fur), B(0.22, 0.18, 0.34, 0, 0.37, -0.05, fur), B(0.46, 0.1, 0.11, 0, 0.21, 0.22, dark),
      B(0.34, 0.26, 0.17, 0, -0.02, 0.24, skin), B(0.32, 0.1, 0.19, 0, -0.16, 0.19, skin), B(0.06, 0.04, 0.02, -0.1, 0.12, 0.282, eye), B(0.06, 0.04, 0.02, 0.1, 0.12, 0.282, eye),
      B(0.12, 0.05, 0.03, 0, 0.0, 0.33, '#201c1b')]);
    const headC = new THREE.Object3D(); headC.position.set(0, 0.1, 0.05); head.add(headC);
    const arm = (sx) => {
      const a = new THREE.Group(); a.rotation.order = 'YXZ'; a.position.set(sx * 0.68, 0.74, 0.08); torso.add(a);
      mesh(a, [B(0.38, 0.66, 0.38, 0, -0.3, 0, fur)]);
      const f = new THREE.Group(); f.position.set(0, -0.6, 0); a.add(f);
      mesh(f, [B(0.33, 0.6, 0.33, 0, -0.28, 0, fur), B(0.4, 0.28, 0.42, 0, -0.62, 0.02, skin)]);
      return { a, f };
    };
    const L = arm(-1), R = arm(1);
    const leg = (sx) => {
      const l = new THREE.Group(); l.position.set(sx * 0.3, 0, -0.02); hips.add(l);
      mesh(l, [B(0.36, 0.38, 0.38, 0, -0.16, 0.02, fur)]);
      const sh = new THREE.Group(); sh.position.set(0, -0.32, 0.05); l.add(sh);
      mesh(sh, [B(0.32, 0.26, 0.32, 0, -0.12, 0, fur), B(0.36, 0.08, 0.48, 0, -0.27, 0.1, skin)]);
      return { l, sh };
    };
    const LL = leg(-1), LR = leg(1);
    const rig = { hips, torso, head, chest, armL: L.a, foreL: L.f, armR: R.a, foreR: R.f, legL: LL.l, shinL: LL.sh, legR: LR.l, shinR: LR.sh, pose: null };
    kongPose(rig, KNUCKLE, 1); // the footprint and the far model are taken in this pose
    const parts = [{ o: new THREE.Vector3(0, 1.42, 0.55), r: 0.27, mult: 1, weak: true, node: headC }, { o: new THREE.Vector3(0, 1.15, 0.25), r: 0.6, mult: 1, node: chest },
      { o: new THREE.Vector3(0, 0.82, -0.12), r: 0.5, mult: 1 }, { o: new THREE.Vector3(0, 0.36, -0.1), r: 0.38, mult: 0.7 }];
    return { g, body, mat, legs: [], parts, rig };
  }
  return { build };
})();
/* the red ring on the floor where the boss will come down */
const Kong = (() => {
  let ring = null, fill = null, on = false, R = 1, t0 = 0;
  function ensure() {
    if (ring) return;
    ring = new THREE.Mesh(new THREE.RingGeometry(0.9, 1, 64), new THREE.MeshBasicMaterial({ color: 0xff2020, transparent: true, opacity: 0.9, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }));
    fill = new THREE.Mesh(new THREE.CircleGeometry(0.9, 48), new THREE.MeshBasicMaterial({ color: 0xff2020, transparent: true, opacity: 0.18, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }));
    [ring, fill].forEach((m) => { m.rotation.x = -Math.PI / 2; m.visible = false; m.renderOrder = 2; scene.add(m); });
  }
  return {
    warn(x, z, r) { ensure(); R = r; on = true; t0 = time; [ring, fill].forEach((m) => { m.position.set(x, 0.05, z); m.scale.setScalar(r); m.visible = true; }); },
    unwarn() { on = false; if (ring) { ring.visible = fill.visible = false; } },
    tick() { if (!on || !ring) return; const k = time - t0; ring.material.opacity = 0.55 + 0.4 * Math.abs(Math.sin(k * 9)); fill.material.opacity = 0.12 + 0.12 * Math.min(1, k / 1.8); },
    reset() { this.unwarn(); },
  };
})();
const _kv = new THREE.Vector3();
function kongFree(x, z, r, h) {
  for (let rr = 0; rr <= 9; rr += 0.75) for (let i = 0, n = rr ? 12 : 1; i < n; i++) {
    const a = (i / n) * TAU, px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr;
    if (Math.abs(px) < HALF - r - 0.4 && Math.abs(pz) < HALF - r - 0.4 && !collideAt(px, 0.05, pz, r, h)) return { x: px, z: pz };
  }
  return null;
}
const kongMinions = () => Enemies.list.reduce((n, o) => n + (o.alive && o.minion ? 1 : 0), 0);
/* the boss's roar calls seven gorillas down from the roof trusses around it */
function kongSummon(e) {
  const k = e.k; k.summons++; let made = 0;
  for (let i = 0; i < KONG.minionsAt; i++) {
    const a = (i / KONG.minionsAt) * TAU + rand(-0.25, 0.25), r = rand(5, 8), p = kongFree(e.pos.x + Math.cos(a) * r, e.pos.z + Math.sin(a) * r, 0.9, 2.2);
    if (!p) continue;
    const m = Enemies.spawn('gorilla', p.x, p.z, { kong: true, minion: true, hp: Math.round(e.maxHp / 4), scale: 1.15, dmgMul: e.dmgMul, y: rand(9, 12), name: '고릴라 졸개',
      yaw: Math.atan2(player.pos.x - p.x, player.pos.z - p.z) });
    m.fury = true; m.angry = true; m.alert = true; m.awake = true; m.lod = 0;
    m.k = { mode: 'drop', t: 0, combo: 0, arm: 1, hit: false, chargeCd: rand(2, 4), jumpCd: 99, summonCd: 99, summons: 0, phase: rand(0, 6), engaged: 0 };
    made++;
  }
  if (!made) return;
  Game.goal += made;
  HUD.banner('고릴라 ' + made + '마리 소환', '보스가 가슴을 두드려 동료를 불렀습니다', 2.2);
  HUD.feed('고릴라 졸개 ' + made + '마리가 내려옵니다', 0, 'hs');
}
function updateKong(e, dt, time, dist, faceYaw) {
  const K = e.boss ? KONG.boss : KONG.minion, sc = e.scale || 1;
  const k = e.k || (e.k = { mode: e.caged ? 'cidle' : 'chase', t: rand(0, 2), combo: 0, arm: 1, hit: false, chargeCd: rand(1.2, 2.5), jumpCd: rand(5, 8), summonCd: 0, summons: 0, phase: 0, engaged: 0 });
  const P = Object.assign({}, KNUCKLE), tx = (player.pos.x - e.pos.x) / dist, tz = (player.pos.z - e.pos.z) / dist;
  const set = (m) => { k.mode = m; k.t = 0; k.hit = false; };
  const reachP = stopDist(e) + K.reach, upright = Math.abs(player.pos.y - e.pos.y) < 2.6 * sc;
  let sp = 0, dirx = 0, dirz = 0, rate = 12, turn = 6, gallop = false, move = true;
  k.t += dt;
  if (!e.caged) { k.chargeCd -= dt; k.jumpCd -= dt; k.summonCd -= dt; k.engaged += dt; }
  // 3-1's lowland gorillas live wild until something sets them off (you close by, a shot, a hit, the stampede);
  // then, while you hold the watchtower, they go for the tower with their fists like the rest
  if (e.wild) {
    if (!e.angry && (dist < 22 || e.hp < e.maxHp)) { e.angry = true; e.alert = true; }
    if (!e.angry) { if (k.mode !== 'wander') set('wander'); }
    else if (k.mode === 'wander') { e.fury = true; set('roar'); }
    else if (Tower.holds()) { if (k.mode !== 'roar' && k.mode !== 'sgo' && k.mode !== 'swait' && k.mode !== 'spunch') set('sgo'); }
    else if (k.mode === 'sgo' || k.mode === 'swait' || k.mode === 'spunch') set('chase');
  }
  // just let out: rear up and roar
  if (e.releaseT > 0) { e.releaseT -= dt; if (e.releaseT <= 0) { set('roar'); e.fury = true; e.angry = true; e.alert = true; } }
  switch (k.mode) {
    /* ---- 3-1: out on the plain ---- */
    case 'wander':
      if (k.wx === undefined || Math.hypot(k.wx - e.pos.x, k.wz - e.pos.z) < 1.5 || k.t > 14) {
        const a = rand(0, TAU), r = rand(5, 16); k.wx = clamp(e.pos.x + Math.cos(a) * r, -HALF + 4, HALF - 4); k.wz = clamp(e.pos.z + Math.sin(a) * r, -HALF + 4, HALF - 4); k.t = 0; k.sit = Math.random() < 0.45 ? rand(2, 6) : 0;
      }
      if (k.sit > 0) { k.sit -= dt; move = false; P.lean = 0.15; P.head = -0.15 + Math.sin(time * 0.7 + e.walk) * 0.25; P.aLx = P.aRx = -0.6; }
      else { const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz) || 1; dirx = dx / l; dirz = dz / l; sp = 1.4; turn = 3; }
      break;
    case 'sgo': case 'swait': case 'spunch': {
      // at the watchtower: a place along its foot, or a wait a little way off; then fists into the planks
      k.claimT = (k.claimT || 0) - dt;
      let slot = e.slot && e.slot.owner === e ? Tower.claim(e) : null;
      if (!slot && k.claimT <= 0) { k.claimT = rand(0.4, 0.7); slot = Tower.claim(e); }
      if (!slot) {
        if (k.mode !== 'swait') { set('swait'); const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.4, 0.4), r = rand(9.5, 13); k.wx = Tower.x + Math.cos(a) * r; k.wz = Tower.z + Math.sin(a) * r; }
        const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz);
        if (l > 1.2) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = dx / l; dirz = dz / l; } sp = l > 16 ? K.run : 2; }
        else { move = false; turnToward(e, Math.atan2(Tower.x - e.pos.x, Tower.z - e.pos.z), 3, dt); if ((k.t % 6) < 1.6) beatPose(P, k); }
        break;
      }
      const gx = slot.x + slot.nx * (stopDist(e) + 0.25), gz = slot.z + slot.nz * (stopDist(e) + 0.25), inFace = Math.atan2(-slot.nx, -slot.nz);
      if (k.mode === 'spunch') {
        const S = K.swing, u = k.t / S, side = k.arm, A = side > 0 ? 'aR' : 'aL', O = side > 0 ? 'aL' : 'aR';
        move = false; turnToward(e, inFace, 6, dt); P.lean = 0.32; P.head = -0.25; P[O + 'x'] = -1.15;
        if (u < 0.38) { P[A + 'x'] = -2.0; P[A + 'y'] = side * 1.7; P.twist = -side * 0.45; rate = 16; }
        else if (u < 0.62) { const w = (u - 0.38) / 0.24; P[A + 'x'] = -1.55; P[A + 'y'] = side * (1.7 - 2.3 * w); P.twist = side * (-0.45 + 0.9 * w); rate = 40;
          if (!k.hit && u >= 0.5) { k.hit = true; _kv.set(slot.x, 1.6, slot.z); Tower.hurt(SIEGE.gorilla.dmg, e, _kv); Sound.thud(_kv); } }
        else { P[A + 'x'] = -1.3; P[A + 'y'] = -side * 0.5; P.twist = side * 0.4; }
        if (k.t >= S) { k.combo--; k.arm = -k.arm; if (k.combo > 0) { k.t = 0; k.hit = false; } else { set('sgo'); k.rest = rand(SIEGE.gorilla.cd[0], SIEGE.gorilla.cd[1]); } }
        break;
      }
      if (k.mode !== 'sgo') set('sgo');
      const dx = gx - e.pos.x, dz = gz - e.pos.z, l = Math.hypot(dx, dz);
      k.rest = (k.rest || 0) - dt;
      if (l > 0.6) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = dx / l; dirz = dz / l; } sp = l > 4 ? K.run : 2.2; }
      else { move = false; turnToward(e, inFace, 6, dt); if (k.rest <= 0 && k.t > 0.3) { set('spunch'); k.combo = randi(2, 3); if (Math.random() < 0.4) Sound.roar(e.pos, 'grunt'); } }
      break;
    }
    /* ---- inside the cage ---- */
    case 'cidle':
      if (dist < 26) turnToward(e, faceYaw, 2, dt);
      if (k.t > 2.5) { const r = Math.random(); set(r < 0.3 ? 'cbeat' : r < 0.6 && dist < 26 ? 'clunge' : 'cpace'); k.cx = tx; k.cz = tz;
        const c = e.cage, ix = c.w / 2 - 0.5 - e.R, iz = c.d / 2 - 0.5 - e.R; k.wx = c.x + rand(-ix, ix); k.wz = c.z + rand(-iz, iz); }
      break;
    case 'cpace': {
      const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz);
      if (l < 0.8 || k.t > 4) set('cidle'); else { dirx = dx / l; dirz = dz / l; sp = 2.2; turn = 3; }
      break;
    }
    case 'clunge': dirx = k.cx; dirz = k.cz; sp = 6; turn = 4; if (k.t > 1.2) set('cidle'); break;
    case 'cbeat': beatPose(P, k); move = false; if (k.t > 0.15 && !k.hit) { k.hit = true; Sound.roar(e.pos, 'beat'); } if (k.t > 1.8) set('cidle'); break;
    /* ---- loose ---- */
    case 'roar':
      move = false; P.lean = -0.1; P.aLx = -2.2; P.aLy = -0.8; P.aRx = -2.2; P.aRy = 0.8; P.head = -0.7; P.lL = P.lR = -0.2; P.sL = P.sR = 0.35; P.y = -0.05;
      turnToward(e, faceYaw, 4, dt);
      if (!k.hit && k.t > 0.1) { k.hit = true; Sound.roar(e.pos, 'beat'); Sound.rage(e.pos); player.shake = Math.max(player.shake, 0.35); }
      if (k.t > 1.4) { set('chase'); k.engaged = 0; }
      break;
    case 'drop': // minions coming down from the roof
      move = false; P.lean = 0.3; P.aLx = P.aRx = -2.4; P.lL = P.lR = -0.5; P.sL = P.sR = 0.8;
      groundMove(e, 0, 0, dt);
      if (e.pos.y <= groundAt(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.01) { FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 6, 0.8, 0.8); Sound.thud(e.pos); set('chase'); }
      break;
    case 'chase':
      if (dist < 40 && e.los) { dirx = tx; dirz = tz; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = tx; dirz = tz; }
      sp = dist > reachP * 0.9 ? K.run : 0; turn = 7;
      if (dist < reachP && (upright || Ride.m)) { set('punch'); k.combo = randi(2, 4); }
      else if (k.chargeCd <= 0 && dist > (e.boss ? 7 : 5) && dist < 34 && e.los) { set('windup'); Sound.roar(e.pos, 'grunt'); }
      else if (e.boss && k.jumpCd <= 0 && dist > 8 && dist < 30 && e.los) { set('crouch'); k.tgx = player.pos.x; k.tgz = player.pos.z; Kong.warn(k.tgx, k.tgz, KONG.slamR); }
      else if (e.boss && k.summons < KONG.summonMax && k.summonCd <= 0 && (e.hp < e.maxHp * 0.85 || k.engaged > 14) && kongMinions() < KONG.minionsAt) set('beat');
      break;
    case 'punch': {
      // big haymakers, left and right in turn
      const S = K.swing, u = k.t / S, side = k.arm, A = side > 0 ? 'aR' : 'aL', O = side > 0 ? 'aL' : 'aR';
      turnToward(e, faceYaw, 5, dt); sp = dist > reachP * 0.7 ? 1.6 * sc : 0; dirx = tx; dirz = tz;
      P.lean = 0.32; P.head = -0.25; P[O + 'x'] = -1.15; P[O + 'y'] = 0;
      if (u < 0.38) { P[A + 'x'] = -2.0; P[A + 'y'] = side * 1.7; P.twist = -side * 0.45; rate = 16; }
      else if (u < 0.62) {
        const w = (u - 0.38) / 0.24; P[A + 'x'] = -1.55; P[A + 'y'] = side * (1.7 - 2.3 * w); P.twist = side * (-0.45 + 0.9 * w); rate = 40;
        if (!k.hit && u >= 0.5) {
          k.hit = true; Sound.swoosh(e.pos);
          let d = faceYaw - e.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
          if (dist < reachP + 0.5 && Math.abs(d) < 1.3 && Ride.m) { Ride.hurtMount(K.punch * (e.dmgMul || 1), e); Sound.thud(player.pos); } // up on any animal: the one under you takes it
          else if (dist < reachP + 0.5 && Math.abs(d) < 1.3 && upright) {
            player.hurt(K.punch * (e.dmgMul || 1), e.pos, 'head'); Sound.thud(player.pos); // haymakers to the head
            if (!e.boss && !Game.ended) Bleed.add(); // a minion's blows open wounds; the boss's do not
            player.vel.x += (Math.cos(e.yaw) * -side + tx * 0.5) * (e.boss ? 9 : 5); player.vel.z += (-Math.sin(e.yaw) * -side + tz * 0.5) * (e.boss ? 9 : 5);
            player.shake = Math.max(player.shake, e.boss ? 0.55 : 0.3);
          }
        }
      } else { P[A + 'x'] = -1.3; P[A + 'y'] = -side * 0.5; P.twist = side * 0.4; }
      if (k.t >= S) { k.combo--; k.arm = -k.arm; if (k.combo > 0 && dist < reachP + 1) { k.t = 0; k.hit = false; } else set('chase'); }
      break;
    }
    case 'windup':
      move = false; P.lean = 1.05; P.head = -0.7; P.aLx = P.aRx = -1.3; P.lL = P.lR = -0.35; P.sL = P.sR = 0.6; P.y = -0.08;
      turnToward(e, faceYaw, 10, dt);
      if (k.t >= K.windup) { set('charge'); k.cx = Math.sin(e.yaw); k.cz = Math.cos(e.yaw); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 3, 0.6 * sc, 0.6); }
      break;
    case 'charge':
      dirx = k.cx; dirz = k.cz; sp = K.charge; turn = 0; gallop = true;
      if (Math.random() < dt * 14) FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 1, 0.5 * sc, 0.4);
      if (!k.hit && dist < stopDist(e) + 0.7 && (upright || Ride.m)) {
        k.hit = true;
        if (Ride.m) Ride.hurtMount(K.chargeDmg * (e.dmgMul || 1), e);
        else { Game.stun(e, K.chargeDmg * (e.dmgMul || 1), K.stun); if (!e.boss && !Game.ended) Bleed.add(); }
        set('recover'); k.rec = K.recover;
      }
      else if (k.t >= K.chargeT) { set('recover'); k.rec = K.recover; }
      break;
    case 'stagger': move = false; P.lean = 0.5; P.head = 0.2 + Math.sin(k.t * 10) * 0.15; if (k.t >= k.rec) { set('chase'); k.chargeCd = rand(K.chargeCd[0], K.chargeCd[1]); } break;
    case 'recover':
      sp = 0; P.lean = e.boss ? 0.7 : 0.55; if (!e.boss) { P.head = -0.1 + Math.sin(k.t * 9) * 0.12; P.aLx = P.aRx = -0.7; }
      if (k.t >= k.rec) { set('chase'); k.chargeCd = rand(K.chargeCd[0], K.chargeCd[1]); }
      break;
    case 'crouch': // gathering for the leap
      move = false; P.lean = 0.85; P.lL = P.lR = -1.0; P.sL = P.sR = 1.5; P.y = -0.25; P.aLx = P.aRx = 0.3; P.head = -0.6;
      turnToward(e, Math.atan2(k.tgx - e.pos.x, k.tgz - e.pos.z), 8, dt);
      if (k.t >= 0.5) {
        const T = 1.9; k.vx = (k.tgx - e.pos.x) / T; k.vz = (k.tgz - e.pos.z) / T; k.vy = 15 * T / 2; k.air = T;
        set('air'); Sound.roar(e.pos, 'grunt'); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 8, 1.2 * sc, 1);
      }
      break;
    case 'air': {
      move = false; e.pos.x += k.vx * dt; e.pos.z += k.vz * dt; k.vy -= 15 * dt; e.pos.y = Math.max(0, e.pos.y + k.vy * dt);
      const u = k.t / k.air; P.lean = u < 0.62 ? -0.1 : 0.5; P.aLx = P.aRx = u < 0.62 ? -2.9 : -0.9; P.lL = P.lR = -0.6; P.sL = P.sR = 0.9; P.head = -0.4; rate = u < 0.62 ? 8 : 22;
      if (e.pos.y <= 0 && k.vy < 0) {
        // the slam: inside the ring you are dead, near it you are thrown
        e.pos.y = 0; Kong.unwarn();
        const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 0.01;
        for (let i = 0; i < 16; i++) { const a = (i / 16) * TAU; FX.puff({ x: e.pos.x + Math.cos(a) * KONG.slamR * 0.8, y: 0.3, z: e.pos.z + Math.sin(a) * KONG.slamR * 0.8 }, 2, 1.2, 1); }
        FX.chunks({ x: e.pos.x, y: 0.3, z: e.pos.z }, 10, 0.25, 'wood'); Sound.quake(e.pos);
        player.shake = Math.max(player.shake, d < 30 ? 0.25 + 0.6 * (1 - d / 30) : 0); buzz(200);
        if (d < KONG.slamR && (Ride.m || player.pos.y < 2.2 + groundAt(player.pos.x, player.pos.y, player.pos.z, player.r))) Game.slam(e); // riding does not save you from this one
        else if (d < KONG.slamR * 1.9) { player.vel.x += dx / d * 10; player.vel.z += dz / d * 10; player.vel.y = 4; player.grounded = false; }
        const p = kongFree(e.pos.x, e.pos.z, e.R, e.H); if (p) { e.pos.x = p.x; e.pos.z = p.z; }
        set('land'); k.jumpCd = rand(9, 13);
      }
      break;
    }
    case 'land': move = false; P.lean = 0.95; P.aLx = P.aRx = -1.25; P.lL = P.lR = -0.5; P.sL = P.sR = 0.8; P.y = -0.15; if (k.t >= 0.6) set('chase'); break;
    case 'beat': // chest-beating roar: seven gorillas come down
      move = false; beatPose(P, k); turnToward(e, faceYaw, 3, dt);
      if (!k.hit && k.t > 0.15) { k.hit = true; Sound.roar(e.pos, 'beat'); }
      if (k.t > 1.5 && !k.called) { k.called = true; kongSummon(e); }
      if (k.t > 1.8) { set('chase'); k.called = false; k.summonCd = rand(22, 28); }
      break;
  }
  if (k.mode === 'crouch' || k.mode === 'air') Kong.tick();
  // movement
  if (move && k.mode !== 'air') {
    e.vel.multiplyScalar(Math.exp(-dt * 4));
    const walking = k.mode === 'chase' || k.mode === 'sgo' || k.mode === 'swait' || k.mode === 'wander';
    if (e.detourT > 0) { e.detourT -= dt; if (walking) { dirx = e.dx2; dirz = e.dz2; } }
    const x0 = e.pos.x, z0 = e.pos.z;
    let blocked = groundMove(e, dirx * sp + e.vel.x, dirz * sp + e.vel.z, dt);
    if (walking && sp > 0.5) unstick(e, x0, z0, dirx, dirz, sp, dt);
    if (blocked && (k.mode === 'charge' || (e.boss && k.mode === 'chase')) && smashAhead(e, dirx, dirz)) blocked = false;
    if (blocked && k.mode === 'charge') { set('stagger'); k.rec = e.boss ? 0.45 : 2.2; FX.puff({ x: e.pos.x + k.cx * e.R, y: 1, z: e.pos.z + k.cz * e.R }, 6, 0.6 * sc, 0.8); Sound.thud(e.pos); }
    if (blocked && k.mode === 'clunge') { set('cidle'); Lab.rattle(e.cage, e.pos.x + dirx * e.R, e.pos.z + dirz * e.R); }
    if (sp > 0.1 && turn > 0) turnToward(e, k.mode === 'chase' && dist < 14 ? faceYaw : Math.atan2(dirx, dirz), turn, dt);
  }
  if (sp > 0.1) kongGait(P, k, sp, dt, gallop, sc);
  kongPose(e.rig, P, 1 - Math.exp(-dt * rate));
  // keep the head and chest hit spheres on the moving body
  const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw);
  for (const p of e.parts) if (p.node) {
    p.node.getWorldPosition(_kv); const dx = _kv.x - e.pos.x, dy = _kv.y - e.pos.y, dz = _kv.z - e.pos.z;
    p.o.set((dx * cy - dz * sy) / sc, dy / sc, (dx * sy + dz * cy) / sc);
  }
  e.roarT = (e.roarT || rand(4, 9)) - dt; if (e.roarT <= 0) { e.roarT = rand(6, 12); if (dist < 40) Sound.roar(e.pos, 'grunt'); }
}
function beatPose(P, k) {
  const L = Math.sin(k.t * 40) > 0;
  P.lean = -0.05; P.head = -0.35; P.lL = P.lR = -0.25; P.sL = P.sR = 0.4; P.y = -0.06;
  P.aLx = -0.9; P.aLy = L ? 1.1 : 0.55; P.fL = L ? -1.85 : -1.3;
  P.aRx = -0.9; P.aRy = L ? -0.55 : -1.1; P.fR = L ? -1.3 : -1.85;
}
function kongGait(P, k, sp, dt, gallop, sc) {
  const g = Math.min(1, sp / 5);
  k.phase += dt * (1.6 + sp * (gallop ? 1.0 : 0.85) / Math.sqrt(sc));
  const s = Math.sin(k.phase), c = Math.cos(k.phase), amp = gallop ? 0.75 : 0.55;
  P.aLx += s * amp * g; P.aRx -= s * amp * g; P.lL = -s * 0.5 * g; P.lR = s * 0.5 * g;
  P.sL = Math.max(0, c) * 0.6 * g; P.sR = Math.max(0, -c) * 0.6 * g; P.y = Math.abs(s) * 0.05 * g; P.twist = s * 0.08 * g;
}
