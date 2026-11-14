
/* ============ robots of the ship: walkers, heavies, spider crawlers, drones, turrets and the giant mech ============ */
/* shot: [min burst, max burst, seconds between bolts, damage, min pause, max pause] */
const ROBOTS = {
  trooper: { name: '전투 로봇', hp: 170, speed: 2.4, r: 0.4, h: 1.95, money: 1000, mode: 'gunner', sight: 34, range: 42, near: 8, far: 22, shot: [3, 4, 0.12, 10, 1.2, 2.1], mapKind: 'gunner' },
  heavy: { name: '중장갑 로봇', hp: 650, speed: 1.6, r: 0.4, h: 1.95, money: 2000, mode: 'gunner', sight: 34, range: 44, near: 10, far: 26, shot: [8, 12, 0.08, 8, 1.5, 2.3], mapKind: 'heavy' },
  crawler: { name: '거미 로봇', hp: 130, speed: 7.2, r: 0.55, h: 0.8, money: 1200, mode: 'crawler', sight: 26, dmg: 40, mapKind: 'crawler' },
  drone: { name: '드론', hp: 90, speed: 6, r: 0.45, h: 0.5, money: 1500, mode: 'drone', sight: 40, range: 46, shot: [2, 3, 0.15, 7, 1.0, 1.8], mapKind: 'drone' },
  turret: { name: '포탑', hp: 260, speed: 0, r: 0.55, h: 1.4, money: 1500, mode: 'turret', sight: 55, range: 62, shot: [3, 3, 0.16, 13, 1.6, 2.5], mapKind: 'turret' },
  mech: { name: '거대 전투 로봇', hp: 6500, speed: 1.9, r: 0.4, h: 1.95, money: 2000, mode: 'mech', sight: 60, range: 60, near: 10, far: 30, shot: [14, 20, 0.07, 10, 1.1, 1.7], mapKind: 'boss' },
};
const RGLOW = { trooper: 0x5fe0ff, heavy: 0xff4a3a, crawler: 0xff9a3a, drone: 0xc58bff, turret: 0xff3a3a, mech: 0x5fe0ff };
const rGlowMats = {}; for (const k in RGLOW) rGlowMats[k] = new THREE.MeshBasicMaterial({ color: RGLOW[k] });
const rBarGeo = new THREE.PlaneGeometry(1, 1), rBarBg = new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.7 });
function buildRobot(type, opts) {
  if (SHIPBOT[ROBOTS[type].mode]) return buildShipBot(type, opts); // the ship's new crew (07h)
  const B = AnimalKit.geoBox, M = AnimalKit.merge, T = ROBOTS[type], gm = rGlowMats[type];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.42, metalness: 0.55, emissive: 0x000000 });
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const e = { type, T, robot: true, g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(0.25, 1.48, 1.15), seed: Math.random() * 10 };
  const mesh = (parent, geo) => { const m = new THREE.Mesh(geo, mat); m.castShadow = !isTouch; parent.add(m); return m; };
  const glow = (parent, sx, sy, sz, x, y, z) => { const m = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), gm); m.position.set(x, y, z); parent.add(m); return m; };
  if (T.mode === 'gunner' || T.mode === 'mech') {
    const heavy = type !== 'trooper', mech = type === 'mech';
    const c1 = mech ? '#8a90a2' : heavy ? '#8a6a66' : '#7c89a3', c2 = mech ? '#5c6170' : heavy ? '#5e4a48' : '#56607a', c3 = '#33384a';
    for (const sx of [-1, 1]) {
      const leg = new THREE.Group(); leg.position.set(sx * 0.14, 0.95, 0); g.add(leg);
      mesh(leg, M([B(0.18, 0.92, 0.2, 0, -0.46, 0, c2), B(0.22, 0.12, 0.34, 0, -0.9, 0.06, c3), B(0.2, 0.14, 0.22, 0, -0.42, 0.02, mech ? '#c9a227' : c1)]));
      if (sx < 0) e.legL = leg; else e.legR = leg;
    }
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.95, 0); g.add(e.upper);
    const up = [B(heavy ? 0.62 : 0.52, 0.62, heavy ? 0.4 : 0.32, 0, 0.36, 0, c1), B(0.44, 0.3, 0.06, 0, 0.42, heavy ? 0.21 : 0.17, mech ? '#c9a227' : '#66748c'),
      B(heavy ? 0.28 : 0.2, 0.14, 0.3, -(heavy ? 0.42 : 0.34), 0.66, 0, c2), B(heavy ? 0.28 : 0.2, 0.14, 0.3, heavy ? 0.42 : 0.34, 0.66, 0, c2),
      B(0.12, 0.08, 0.12, 0, 0.71, 0, c3), B(0.3, 0.24, 0.3, 0, 0.86, 0, c1), B(0.03, 0.22, 0.03, 0.1, 1.06, -0.05, c3)];
    if (mech) up.push(B(0.36, 0.34, 0.5, -0.55, 0.78, -0.02, '#3a3e48'), B(0.3, 0.06, 0.06, -0.55, 0.9, 0.24, '#1c2028'), B(0.3, 0.06, 0.06, -0.55, 0.78, 0.24, '#1c2028'), B(0.3, 0.06, 0.06, -0.55, 0.66, 0.24, '#1c2028'));
    mesh(e.upper, M(up));
    glow(e.upper, 0.24, 0.05, 0.02, 0, 0.88, 0.155); if (heavy) glow(e.upper, 0.12, 0.12, 0.02, 0, 0.42, heavy ? 0.245 : 0.205);
    e.armL = new THREE.Group(); e.armL.position.set(-(heavy ? 0.42 : 0.34), 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3)]));
    e.armR = new THREE.Group(); e.armR.position.set(heavy ? 0.42 : 0.34, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(heavy ? 0.16 : 0.1, 0.52, heavy ? 0.16 : 0.12, 0, -0.86, 0.03, c3)].concat(heavy ? [B(0.05, 0.3, 0.05, 0.05, -1.22, 0.05, '#1c2028'), B(0.05, 0.3, 0.05, -0.05, -1.22, 0.05, '#1c2028')] : [])));
    glow(e.armR, 0.07, 0.05, 0.07, 0, heavy ? -1.38 : -1.14, 0.03);
    e.muzzle.set(heavy ? 0.32 : 0.25, 1.48, heavy ? 1.42 : 1.15);
    e.parts = [{ o: new THREE.Vector3(0, 1.81, 0), r: 0.17, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.33, 0), r: heavy ? 0.4 : 0.33, mult: 1 },
      { o: new THREE.Vector3(0, 0.98, 0), r: 0.25, mult: 0.9 }, { o: new THREE.Vector3(0, 0.5, 0), r: 0.26, mult: 0.7 }];
    e.eyeH = 1.82;
  } else if (T.mode === 'turret') {
    mesh(g, M([B(1.0, 0.25, 1.0, 0, 0.125, 0, '#3e4454'), B(0.5, 0.62, 0.5, 0, 0.56, 0, '#56607a'), B(0.9, 0.06, 0.06, 0, 0.27, 0.47, '#c9a227')]));
    e.head = new THREE.Group(); e.head.position.set(0, 0.95, 0); g.add(e.head);
    mesh(e.head, M([B(0.76, 0.38, 0.8, 0, 0.1, 0, '#7c89a3'), B(0.08, 0.08, 0.72, -0.15, 0.08, 0.62, '#1c2028'), B(0.08, 0.08, 0.72, 0.15, 0.08, 0.62, '#1c2028'), B(0.5, 0.1, 0.5, 0, 0.32, -0.05, '#3a4150')]));
    glow(e.head, 0.2, 0.08, 0.02, 0, 0.18, 0.41);
    e.muzzle.set(0, 1.03, 1.0);
    e.parts = [{ o: new THREE.Vector3(0, 1.13, 0.4), r: 0.16, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.05, 0), r: 0.46, mult: 1 }, { o: new THREE.Vector3(0, 0.4, 0), r: 0.46, mult: 0.6 }];
    e.eyeH = 1.13;
  } else if (T.mode === 'crawler') {
    e.body = new THREE.Group(); g.add(e.body);
    mesh(e.body, M([B(0.8, 0.3, 0.9, 0, 0.5, 0, '#6a7690'), B(0.5, 0.18, 0.5, 0, 0.7, -0.05, '#8a96ae'), B(0.42, 0.24, 0.32, 0, 0.52, 0.55, '#454c60'), B(0.6, 0.05, 0.05, 0, 0.66, 0.2, '#c9a227')]));
    glow(e.body, 0.08, 0.06, 0.02, -0.1, 0.56, 0.72); glow(e.body, 0.08, 0.06, 0.02, 0.1, 0.56, 0.72);
    e.cl = [];
    for (const [x, z] of [[-0.42, 0.3], [0.42, 0.3], [-0.42, -0.3], [0.42, -0.3]]) {
      const p = new THREE.Group(); p.position.set(x, 0.5, z); g.add(p); const sd = Math.sign(x);
      mesh(p, M([B(0.5, 0.07, 0.08, sd * 0.24, 0.05, 0, '#2a2f3a', [0, 0, sd * 0.35]), B(0.07, 0.55, 0.08, sd * 0.5, -0.22, 0, '#3a4150', [0, 0, -sd * 0.25])]));
      e.cl.push(p);
    }
    e.parts = [{ o: new THREE.Vector3(0, 0.5, 0), r: 0.48, mult: 1 }, { o: new THREE.Vector3(0, 0.52, 0.55), r: 0.24, mult: 1, weak: true }];
    e.eyeH = 0.56;
  } else { // drone
    mesh(g, M([B(0.62, 0.16, 0.62, 0, 0, 0, '#7c89a3'), B(0.3, 0.12, 0.3, 0, -0.13, 0.05, '#2a2f3a'), B(0.9, 0.05, 0.07, 0, 0.02, 0, '#3a4150', [0, Math.PI / 4, 0]), B(0.9, 0.05, 0.07, 0, 0.02, 0, '#3a4150', [0, -Math.PI / 4, 0]),
      B(0.06, 0.1, 0.34, 0, -0.2, 0.2, '#1c2028')]));
    glow(g, 0.14, 0.06, 0.04, 0, -0.12, 0.21);
    e.rotors = [];
    for (const [x, z] of [[0.32, 0.32], [-0.32, 0.32], [0.32, -0.32], [-0.32, -0.32]]) {
      const ro = new THREE.Group(); ro.position.set(x, 0.07, z); g.add(ro); mesh(ro, M([B(0.42, 0.015, 0.06, 0, 0, 0, '#202430'), B(0.06, 0.015, 0.42, 0, 0, 0, '#202430')])); e.rotors.push(ro);
    }
    e.muzzle.set(0, -0.2, 0.4);
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 0.42, mult: 1 }, { o: new THREE.Vector3(0, -0.12, 0.22), r: 0.13, mult: 1, weak: true }];
    e.eyeH = 0;
  }
  const bar = new THREE.Group(); const bg = new THREE.Mesh(rBarGeo, rBarBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
  const fill = new THREE.Mesh(rBarGeo, new THREE.MeshBasicMaterial({ color: 0x8ec8ff })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
  bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
  bakeFar(e);
  return e;
}

/* bolts in bursts at you */
function robotFire(e, dt, dist) {
  const T = e.T, S = T.shot;
  e.fireT -= dt;
  if (e.burst > 0) {
    e.burstT -= dt;
    if (e.burstT <= 0) {
      e.burst--; e.burstT = S[2];
      muzzleOf(e, _mz);
      _aim.set(player.pos.x + player.vel.x * dist / 110, player.pos.y + 1.25, player.pos.z + player.vel.z * dist / 110);
      Proj.bullet(_mz, _aim, 62, S[3] * e.dmgMul, 0.3 + dist * 0.024 + player.speedXZ * 0.07 - (e.boss ? 0.12 : 0), true, 'bolt');
      Sound.zap(_mz, T.mode);
    }
    return true;
  }
  if (e.fireT <= 0) { e.burst = randi(S[0], S[1]); e.burstT = 0; e.fireT = rand(S[4], S[5]); }
  return false;
}
function robotWalk(e, sp, dt, aim) {
  e.walk = (e.walk || 0) + dt * sp * 2.4;
  const s = Math.sin(e.walk) * Math.min(1, sp / 2) * 0.55;
  if (e.legL) { e.legL.rotation.x = s; e.legR.rotation.x = -s; }
  if (e.armR) {
    if (aim) { e.armR.rotation.set(-Math.PI / 2 + 0.05, 0, 0); e.armL.rotation.set(-0.9, 0, 0.35); }
    else { e.armR.rotation.set(-s * 0.6, 0, 0); e.armL.rotation.set(s * 0.6, 0, 0); }
  }
  e.flinch = Math.max(0, (e.flinch || 0) - dt * 5); if (e.upper) e.upper.rotation.x = -e.flinch * 0.2;
}
function updateRobot(e, dt, dist, faceYaw) {
  if (SHIPBOT[e.T.mode]) { updateShipBot(e, dt, dist, faceYaw); return; }
  const T = e.T; e.spin = (e.spin || 0) + dt;
  if (e.rotors) for (const ro of e.rotors) ro.rotation.y += dt * 38;
  let mvx = 0, mvz = 0;
  // on watch until it sees or hears you; one that spots you calls the others near it
  if (!e.alert) {
    if ((e.los && dist < T.sight) || dist < 7 || (e.boss && dist < 28)) {
      Enemies.alarm(e);
      for (const o of Enemies.list) if (o.robot && !o.alert && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 16) Enemies.alarm(o);
    } else {
      if (T.mode === 'turret') { e.yaw += Math.sin(e.spin * 0.4 + e.seed) * dt * 0.5; e.g.rotation.y = e.yaw; }
      if (T.mode === 'drone') e.pos.y += Math.sin(e.spin * 1.6 + e.seed) * dt * 0.25;
      if (T.mode === 'gunner' || T.mode === 'mech') robotWalk(e, 0, dt, false);
      return;
    }
  }
  if (T.mode === 'turret') {
    turnToward(e, faceYaw, 2.6, dt);
    if (e.los && dist < T.range) { e.react -= dt; if (e.react <= 0) robotFire(e, dt, dist); } else e.react = Math.max(e.react, 0.4);
    return;
  }
  if (T.mode === 'drone') {
    const ty = clamp(player.pos.y + 4 + Math.sin(e.spin * 1.3 + e.seed) * 1.2, 2.4, 22);
    e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.4));
    e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.4, 3); }
    const fx = _to.x / dist, fz = _to.z / dist, fwd = !e.los || dist > 15 ? 1 : dist < 9 ? -0.7 : 0;
    mvx = (fx * fwd - fz * e.strafe * 0.8) * T.speed; mvz = (fz * fwd + fx * e.strafe * 0.8) * T.speed;
    e.vel.multiplyScalar(Math.exp(-dt * 3));
    if (moveXZ(e.pos, (mvx + e.vel.x) * dt, (mvz + e.vel.z) * dt, e.R, e.H, 0)) e.strafe *= -1;
    e.pos.x = clamp(e.pos.x, -HALF + 1, HALF - 1); e.pos.z = clamp(e.pos.z, -HALF + 1, HALF - 1);
    turnToward(e, faceYaw, 4, dt); e.g.rotation.x = clamp(fwd * 0.18, -0.2, 0.2);
    e.react -= dt;
    if (e.los && dist < T.range && e.react <= 0) robotFire(e, dt, dist);
    return;
  }
  if (T.mode === 'crawler') {
    // rushes you and leaps; one bite of steel is 40
    let dx, dz;
    if (dist < 14 && e.los) { dx = _to.x / dist; dz = _to.z / dist; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { dx = _fd.x; dz = _fd.z; } else { dx = _to.x / dist; dz = _to.z / dist; }
    let sp = e.speed; const sd = stopDist(e);
    e.atkCd = (e.atkCd || 0) - dt;
    if (e.leapT > 0) { e.leapT -= dt; sp *= 0.3; if (e.leapT <= 0 && dist < sd + 0.9 && Math.abs(player.pos.y - e.pos.y) < 1.5) { player.hurt(T.dmg * e.dmgMul, e.pos, 'body'); Sound.thud(e.pos); Sound.metal(e.pos); } }
    else if (dist < sd + 0.6 && e.atkCd <= 0) { e.leapT = 0.22; e.atkCd = 0.95; Sound.zap(e.pos, 'crawler'); }
    if (dist < sd + 0.05) sp = 0;
    turnToward(e, Math.atan2(dx, dz), 8, dt);
    e.vel.multiplyScalar(Math.exp(-dt * 5));
    groundMove(e, dx * sp + e.vel.x, dz * sp + e.vel.z, dt);
    e.walk = (e.walk || 0) + dt * sp * 3.2;
    e.cl.forEach((p, i) => { p.rotation.y = Math.sin(e.walk + i * 1.6) * 0.45; p.rotation.z = Math.max(0, Math.sin(e.walk + i * 1.6)) * 0.25 * Math.sign(p.position.x); });
    e.body.position.y = Math.abs(Math.sin(e.walk * 2)) * 0.04 + (e.leapT > 0 ? 0.25 : 0);
    return;
  }
  // walkers: troopers, heavies and the mech
  const onDeck = e.pos.y > 1.5, sameLevel = Math.abs(e.pos.y - player.pos.y) < 1.5;
  if (e.state === 'move') {
    if (onDeck && !sameLevel) { mvx = 0; mvz = 0; } // up on a deck: hold the high ground
    else if (flowDir(e.pos.x, e.pos.z, _fd) && !onDeck) { mvx = _fd.x * e.speed; mvz = _fd.z * e.speed; } else { mvx = _to.x / dist * e.speed; mvz = _to.z / dist * e.speed; }
    turnToward(e, e.los && dist < 34 ? faceYaw : (mvx || mvz ? Math.atan2(mvx, mvz) : faceYaw), 5, dt);
    if (e.los && dist < T.range) { e.state = 'engage'; e.react = rand(0.4, 0.8) * (e.boss ? 0.6 : 1); }
  } else {
    e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1, 2.6); }
    const fx = _to.x / dist, fz = _to.z / dist, fwd = onDeck && !sameLevel ? 0 : dist > T.far ? 1 : dist < T.near ? -0.8 : 0;
    const st = onDeck && !sameLevel ? 0.25 : 0.6;
    mvx = (fx * fwd - fz * e.strafe * st) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * st) * e.speed * 0.55;
    turnToward(e, faceYaw, 6, dt);
    e.react -= dt;
    if (e.noLos > 1.6 || dist > T.range + 6) e.state = 'move';
    if (e.react <= 0 && e.los && robotFire(e, dt, dist)) { mvx *= 0.4; mvz *= 0.4; }
    if (T.mode === 'mech') {
      // shoulder rockets, two at a time, arcing over cover
      e.rocketT = (e.rocketT === undefined ? 3 : e.rocketT) - dt;
      if (e.rocketT <= 0 && e.los && dist > 8) {
        e.rocketT = rand(4.5, 6.5);
        for (const off of [-1.6, 1.6]) { muzzleOf(e, _mz); _mz.y += 1.2; _aim.set(player.pos.x + rand(-1, 1) * 1.5 + off * 0.4, player.pos.y + 0.3, player.pos.z + rand(-1, 1) * 1.5); Proj.egrenade(_mz, _aim, 'gl'); }
      }
    }
  }
  e.vel.multiplyScalar(Math.exp(-dt * 6));
  const blocked = groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
  if (blocked && e.state === 'engage') e.strafe *= -1;
  robotWalk(e, Math.hypot(mvx, mvz), dt, e.state === 'engage');
}
