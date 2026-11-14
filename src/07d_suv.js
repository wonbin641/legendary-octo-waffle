
/* ============ stage 3: the ranger's open-top off-road SUV ============ */
// He turns up now and then, stops next to you and waits. Climb into the passenger seat and he drives a loop
// while you shoot from the open top. Big animals can ram and wreck it.
const Car = (() => {
  const B = AnimalKit.geoBox, M = AnimalKit.merge;
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const paint = '#5b6b3a', sand = '#c9b98a', black = '#1d1f22', steel = '#6d7278', seatC = '#3a2f26';
  const parts = [
    B(2.0, 0.55, 4.4, 0, 0.9, 0, paint), B(1.96, 0.28, 1.3, 0, 1.3, 1.45, paint), B(2.04, 0.12, 4.42, 0, 0.98, 0, sand),
    B(0.08, 0.45, 2.6, 0.98, 1.4, -0.55, paint), B(0.08, 0.45, 2.6, -0.98, 1.4, -0.55, paint), B(1.96, 0.45, 0.08, 0, 1.4, -1.83, paint),
    B(1.9, 0.5, 0.06, 0, 1.75, 0.78, steel, [-0.25, 0, 0]), B(0.07, 1.5, 0.07, 0.95, 2.1, -0.75, steel), B(0.07, 1.5, 0.07, -0.95, 2.1, -0.75, steel),
    B(1.97, 0.07, 0.07, 0, 2.85, -0.75, steel), B(0.07, 0.07, 1.1, 0.95, 2.85, -1.3, steel), B(0.07, 0.07, 1.1, -0.95, 2.85, -1.3, steel), B(1.97, 0.07, 0.07, 0, 2.85, -1.85, steel),
    B(0.6, 0.5, 0.55, 0.5, 1.35, 0.25, seatC), B(0.6, 0.5, 0.55, -0.5, 1.35, 0.25, seatC), B(0.6, 0.6, 0.12, 0.5, 1.7, -0.02, seatC), B(0.6, 0.6, 0.12, -0.5, 1.7, -0.02, seatC),
    B(1.7, 0.45, 0.5, 0, 1.4, -1.1, seatC), B(0.36, 0.36, 0.06, 0.5, 1.72, 0.62, black, [-0.9, 0, 0]),
    B(2.1, 0.3, 0.2, 0, 0.75, 2.25, black), B(0.12, 0.6, 0.12, 0.6, 1.0, 2.3, black), B(0.12, 0.6, 0.12, -0.6, 1.0, 2.3, black), B(1.4, 0.1, 0.1, 0, 1.28, 2.3, black),
    B(0.9, 0.9, 0.28, 0, 1.25, -2.35, black, null, false, true), B(2.1, 0.3, 0.2, 0, 0.75, -2.25, black),
    B(0.25, 0.14, 0.05, 0.7, 1.05, 2.23, '#fff4c8'), B(0.25, 0.14, 0.05, -0.7, 1.05, 2.23, '#fff4c8'),
  ];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, metalness: 0.2 });
  const body = new THREE.Mesh(M(parts), mat); body.castShadow = true; body.receiveShadow = true; g.add(body);
  // the driver: khaki shirt, bush hat, hands on the wheel
  const drv = new THREE.Mesh(M([B(0.46, 0.55, 0.3, 0.5, 1.95, 0.22, '#b8a06a'), B(0.24, 0.27, 0.25, 0.5, 2.42, 0.25, '#c99a7a'), B(0.5, 0.05, 0.5, 0.5, 2.58, 0.25, '#6b5a36', null, false, true),
    B(0.28, 0.14, 0.28, 0.5, 2.64, 0.25, '#6b5a36'), B(0.12, 0.12, 0.45, 0.32, 1.95, 0.48, '#b8a06a', [-0.4, 0, 0]), B(0.12, 0.12, 0.45, 0.68, 1.95, 0.48, '#b8a06a', [-0.4, 0, 0])]), mat);
  drv.castShadow = true; g.add(drv);
  const wheelGeo = new THREE.CylinderGeometry(0.46, 0.46, 0.36, 16); wheelGeo.rotateZ(Math.PI / 2);
  const wheelMat = new THREE.MeshStandardMaterial({ color: 0x18191b, roughness: 0.9 });
  const wheels = [[0.95, 1.4], [-0.95, 1.4], [0.95, -1.35], [-0.95, -1.35]].map(([x, z]) => { const w = new THREE.Mesh(wheelGeo, wheelMat); w.position.set(x, 0.46, z); w.castShadow = true; g.add(w); return w; });
  g.visible = false; scene.add(g);
  const pos = g.position, vel = new THREE.Vector3();
  const C = { active: false, state: 'off', yaw: 0, speed: 0, hp: 800, timer: 0, nextT: 35, riding: false, path: [], wp: 0, stuckT: 0, revT: 0, smokeT: 0, msgT: 0 };
  const fwdX = () => Math.sin(C.yaw), fwdZ = () => Math.cos(C.yaw);
  function say(t) { HUD.feed('아저씨: ' + t, 0); }
  function reset() { C.active = false; C.state = 'off'; C.riding = false; g.visible = false; C.nextT = 35; C.hp = 800; drv.visible = true; Sound.engine(0, 0); }
  function free(x, z) { return !collideAt(x, 0, z, 1.8, 2); }
  /* he comes in along a clear straight line; if he still gets stuck he tries again from another side */
  function arrive(retry) {
    if (!retry) C.retries = 0;
    const near = retry ? [45, 65] : [80, 105];
    for (let k = 0; k < 60; k++) {
      const a = rand(0, TAU), d = rand(near[0], near[1]), x = clamp(player.pos.x + Math.cos(a) * d, -HALF + 6, HALF - 6), z = clamp(player.pos.z + Math.sin(a) * d, -HALF + 6, HALF - 6);
      if (!free(x, z)) continue;
      const dx = player.pos.x - x, dz = player.pos.z - z, l = Math.hypot(dx, dz) || 1, sx = -dz / l * 1.4, sz = dx / l * 1.4;
      if (k < 50 && (raycastStatic(x + sx, 0.8, z + sz, dx / l, 0, dz / l, l - 6) || raycastStatic(x - sx, 0.8, z - sz, dx / l, 0, dz / l, l - 6))) continue;
      pos.set(x, 0, z); C.yaw = Math.atan2(dx, dz); C.speed = 0; C.active = true; C.state = 'arrive'; C.timer = 25; C.stuckT = 0; C.revT = 0;
      if (!retry) { C.hp = 800; drv.visible = true; g.visible = true; HUD.feed('SUV 엔진 소리가 들립니다', 0); }
      return;
    }
    if (!retry) C.nextT = 10;
  }
  function loopPath() {
    C.path = []; const cx = clamp(pos.x, -HALF + 50, HALF - 50), cz = clamp(pos.z, -HALF + 50, HALF - 50), a0 = Math.atan2(pos.z - cz, pos.x - cx), dir = Math.random() < 0.5 ? 1 : -1;
    for (let i = 1; i <= 12; i++) {
      const a = a0 + dir * (i / 12) * TAU, rr = 40 + Math.sin(i * 1.7) * 8;
      let x = cx + Math.cos(a) * rr, z = cz + Math.sin(a) * rr;
      for (let k = 0; k < 6 && !free(x, z); k++) { x += rand(-6, 6); z += rand(-6, 6); }
      C.path.push({ x, z });
    }
    C.wp = 0;
  }
  function board() {
    if (!canBoard()) return;
    C.riding = true; C.state = 'drive'; C.timer = 55; loopPath(); Sound.horn();
    say(pick(['꽉 잡아! 한 바퀴 돈다', '타라! 맹수들 쏴 버려', '조수석이 명당이지, 마음껏 쏴']));
  }
  function exit(forced) {
    if (!C.riding) return;
    C.riding = false;
    const rx = -Math.cos(C.yaw), rz = Math.sin(C.yaw);
    const spots = [[rx * 2.6, rz * 2.6], [-rx * 2.6, -rz * 2.6], [-fwdX() * 3.6, -fwdZ() * 3.6], [fwdX() * 3.6, fwdZ() * 3.6]];
    let s = spots[0]; for (const t of spots) if (!collideAt(pos.x + t[0], 0, pos.z + t[1], player.r, player.height)) { s = t; break; }
    player.pos.set(pos.x + s[0], 0, pos.z + s[1]); player.vel.set(vel.x * 0.3, 0, vel.z * 0.3); player.grounded = true;
    if (!forced && C.state === 'drive') { C.state = 'wait'; C.timer = 15; say('내리게? 기다릴게'); }
  }
  function canBoard() { return C.active && !C.riding && (C.state === 'wait' || C.state === 'arrive') && Math.hypot(pos.x - player.pos.x, pos.z - player.pos.z) < 10 && player.pos.y < 1.5; }
  function damage(dmg, from) {
    if (!C.active || C.state === 'wreck') return;
    C.hp -= dmg; player.shake = Math.max(player.shake, C.riding ? 0.3 : 0.1);
    FX.sparks({ x: pos.x, y: 1.2, z: pos.z }, 12, [1, 0.8, 0.5], 4); Sound.metal(pos); Sound.thud(pos);
    if (C.hp <= 0) wreck();
  }
  function wreck() {
    C.hp = 0; C.state = 'wreck'; C.timer = 18; C.speed = 0;
    if (C.riding) exit(true);
    drv.visible = false; FX.explode({ x: pos.x, y: 1.2, z: pos.z }, true); Sound.boom(pos, true);
    say('차가 망가졌어! 난 먼저 간다!');
  }
  const _p = { x: 0, y: 0, z: 0 };
  function steerTo(tx, tz, vmax, dt) {
    const dx = tx - pos.x, dz = tz - pos.z, dist = Math.hypot(dx, dz);
    let want = Math.atan2(dx, dz), d = Math.atan2(Math.sin(want - C.yaw), Math.cos(want - C.yaw));
    // look ahead for trees and rocks and swerve around them
    const ox = pos.x + fwdX() * 2.4, oz = pos.z + fwdZ() * 2.4;
    if (raycastStatic(ox, 0.8, oz, fwdX(), 0, fwdZ(), 9) && RH.box) {
      const l = !raycastStatic(ox, 0.8, oz, Math.sin(C.yaw + 0.6), 0, Math.cos(C.yaw + 0.6), 8), rr = !raycastStatic(ox, 0.8, oz, Math.sin(C.yaw - 0.6), 0, Math.cos(C.yaw - 0.6), 8);
      d = l && !rr ? 1 : rr && !l ? -1 : (d >= 0 ? 1 : -1); vmax = Math.min(vmax, 6);
    }
    const target = Math.min(vmax, dist * 1.1) * (1 - Math.min(0.6, Math.abs(d) / 2));
    if (C.revT > 0) { C.revT -= dt; C.speed = lerp(C.speed, -4, 1 - Math.exp(-dt * 4)); C.yaw -= Math.sign(d || 1) * 0.6 * dt; }
    else { C.speed += clamp(target - C.speed, -9 * dt, 5 * dt); C.yaw += clamp(d, -1, 1) * 0.95 * Math.min(1, Math.abs(C.speed) / 4) * dt; }
    return dist;
  }
  function drive(dt) {
    vel.set(fwdX() * C.speed, 0, fwdZ() * C.speed);
    _p.x = pos.x; _p.y = 0; _p.z = pos.z;
    const blocked = moveXZ(_p, vel.x * dt, vel.z * dt, 1.5, 1.8, 0.3);
    _p.x = clamp(_p.x, -HALF + 2, HALF - 2); _p.z = clamp(_p.z, -HALF + 2, HALF - 2);
    pos.x = _p.x; pos.z = _p.z;
    if (blocked && Math.abs(C.speed) > 1) { C.speed *= 0.4; C.stuckT += dt; } else if (Math.abs(C.speed) < 0.8 && C.state !== 'wait') C.stuckT += dt; else C.stuckT = Math.max(0, C.stuckT - dt);
    if (C.stuckT > 1.2 && C.revT <= 0) { C.revT = 1.1; C.stuckT = 0; }
    // run over or shove animals in the way
    for (const e of Enemies.list) {
      if (!e.alive) continue;
      const dx = e.pos.x - pos.x, dz = e.pos.z - pos.z, d = Math.hypot(dx, dz), m = 1.9 + e.R;
      if (d < m && d > 0.01) {
        moveXZ(e.pos, dx / d * (m - d), dz / d * (m - d), e.R, e.H, 0);
        if (Math.abs(C.speed) > 6 && !e.bumped) { e.bumped = 0.6; Enemies.damage(e, Math.abs(C.speed) * 6, e.pos, { x: dx / d, y: 0, z: dz / d }, false); Sound.thud(e.pos); }
      }
      if (e.bumped) e.bumped = Math.max(0, e.bumped - dt) || 0;
    }
    const sp = Math.abs(C.speed);
    g.rotation.set(Math.sin(time * 8.7) * 0.012 * sp / 13, C.yaw, Math.sin(time * 6.1) * 0.018 * sp / 13);
    wheels.forEach((w) => { w.rotation.x += C.speed * dt / 0.46; });
    if (sp > 3 && Math.random() < 0.5) FX.puff({ x: pos.x - fwdX() * 2.2 + rand(-0.8, 0.8), y: 0.3, z: pos.z - fwdZ() * 2.2 }, 1, 0.55, 0.9);
  }
  function update(dt) {
    if (!World.style.safari) return; // the savanna and its ranger are gone; no stage has a safari now
    if (!C.active) { C.nextT -= dt; if (C.nextT <= 0 && !Game.ended) arrive(); Sound.engine(0, 0); return; }
    const pd = Math.hypot(pos.x - player.pos.x, pos.z - player.pos.z);
    if (C.state === 'arrive') {
      const side = 4.5, tx = player.pos.x - fwdX() * 0 + Math.cos(C.yaw) * side, tz = player.pos.z - Math.sin(C.yaw) * side;
      const d = steerTo(tx, tz, 13, dt);
      if (d < 3 || (pd < 7 && Math.abs(C.speed) < 2)) { C.state = 'wait'; C.timer = 25; C.speed = 0; Sound.horn(); say(pick(['타! 한 바퀴 태워 줄게', '어이, 걸어 다니면 위험해! 타라', '조수석 비었다, 얼른 타'])); }
      C.timer -= dt;
      if (C.timer <= 0) { if ((C.retries || 0) < 2) { C.retries = (C.retries || 0) + 1; arrive(true); } else { C.state = 'leave'; C.timer = 30; } }
    } else if (C.state === 'wait') {
      C.speed = lerp(C.speed, 0, 1 - Math.exp(-dt * 5));
      if (pd > 16) { C.state = 'arrive'; C.timer = 30; }
      C.timer -= dt; if (C.timer <= 0) { C.state = 'leave'; C.timer = 30; say('바쁜가 보네, 다음에 보자'); }
    } else if (C.state === 'drive') {
      const w = C.path[C.wp];
      if (steerTo(w.x, w.z, 13, dt) < 7) C.wp = (C.wp + 1) % C.path.length;
      C.timer -= dt;
      if (C.timer <= 0) { C.state = 'drop'; }
    } else if (C.state === 'drop') {
      C.speed = lerp(C.speed, 0, 1 - Math.exp(-dt * 3));
      if (Math.abs(C.speed) < 0.6) { exit(true); say('여기까지야, 조심해!'); C.state = 'leave'; C.timer = 30; }
    } else if (C.state === 'leave') {
      const ax = pos.x - player.pos.x, az = pos.z - player.pos.z, l = Math.hypot(ax, az) || 1;
      steerTo(clamp(pos.x + ax / l * 60, -HALF + 4, HALF - 4), clamp(pos.z + az / l * 60, -HALF + 4, HALF - 4), 14, dt);
      C.timer -= dt; if (pd > 120 || C.timer <= 0) { C.active = false; g.visible = false; C.nextT = rand(70, 110); }
    } else if (C.state === 'wreck') {
      C.speed = 0; C.smokeT -= dt;
      if (C.smokeT <= 0) { C.smokeT = 0.12; FX.puff({ x: pos.x + rand(-0.5, 0.5), y: 1.6, z: pos.z + rand(-0.5, 0.5) }, 1, 0.15, 1.2);
        FX.glow.emit({ x: pos.x + rand(-0.6, 0.6), y: 1.3, z: pos.z + rand(-1, 1), vx: rand(-0.3, 0.3), vy: rand(1, 2.5), vz: rand(-0.3, 0.3), max: 0.6, s0: 0.5, s1: 0.1, r: 1, g: 0.5, b: 0.15, a: 0.8, grav: -1, drag: 1 }); }
      C.timer -= dt; if (C.timer <= 0) { C.active = false; g.visible = false; C.nextT = rand(80, 120); }
    }
    if (C.state !== 'wreck') drive(dt);
    // keep the player out of the bodywork while on foot
    if (!C.riding && C.state !== 'off') {
      const dx = player.pos.x - pos.x, dz = player.pos.z - pos.z, d = Math.hypot(dx, dz), m = 2.0 + player.r;
      if (d < m && d > 0.01 && player.pos.y < 2.2) moveXZ(player.pos, dx / d * (m - d), dz / d * (m - d), player.r, player.height, 0);
    }
    Sound.engine(C.state === 'wreck' ? 0 : clamp(1 - pd / 70, 0, 1) * (C.riding ? 0.6 : 0.45), Math.abs(C.speed));
  }
  /* the passenger seat (right-hand side; the driver sits on the left) */
  function seat(out) {
    const rx = -Math.cos(C.yaw), rz = Math.sin(C.yaw);
    return out.set(pos.x + rx * 0.5 + fwdX() * 0.25, 0.48 + Math.sin(time * 8.7) * 0.02 * Math.abs(C.speed) / 13, pos.z + rz * 0.5 + fwdZ() * 0.25);
  }
  return { update, board, exit, damage, reset, canBoard, seat, vel, pos,
    get riding() { return C.riding; }, get state() { return C.state; }, get active() { return C.active; }, get hpFrac() { return clamp(C.hp / 800, 0, 1); },
    toggle() { if (C.riding) exit(false); else if (canBoard()) board(); }, _next() { if (!C.active) C.nextT = 0; } };
})();
