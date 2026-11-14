/* ============ the lab's beasts each fight their own way; what they do to you (bleeding, fear, being tossed); riding them ============ */

/* ---------- the animals hit half as hard as they used to, bleeding included. the giant gorilla and its minions are left as they were ---------- */
const BEAST_DMG = 0.5, BLEED_DPS = 5;
/* ---------- bleeding: every wound takes 5 a second for 10 seconds. a fresh wound adds one more and restarts the clock for all of them.
   the animal you ride bleeds the same way when the others get at it ---------- */
const Bleed = {
  n: 0, t: 0, acc: 0, beasts: new Set(),
  add() {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return;
    this.n++; this.t = 10;
    HUD.feed('출혈' + (this.n > 1 ? ' ' + this.n + '중첩' : '') + ' · 10초 동안 초당 ' + BLEED_DPS * this.n, 0, 'hs');
  },
  addTo(m) {
    if (!m || !m.alive || Game.ended) return;
    m.bleedN = (m.bleedN || 0) + 1; m.bleedT = 10; m.bleedAcc = m.bleedAcc || 0; this.beasts.add(m);
    if (m.ridden) HUD.feed(m.T.name + ' 출혈' + (m.bleedN > 1 ? ' ' + m.bleedN + '중첩' : '') + ' · 10초 동안 초당 ' + BLEED_DPS * m.bleedN, 0, 'hs');
  },
  /* a potion stops yours; leaving the stage stops everyone's */
  stop(all) {
    this.n = 0; this.t = 0; this.acc = 0;
    if (all) { for (const m of this.beasts) { m.bleedN = 0; m.bleedT = 0; m.bleedAcc = 0; } this.beasts.clear(); }
  },
  update(dt) {
    for (const m of this.beasts) {
      if (!m.alive) { this.beasts.delete(m); continue; }
      m.bleedT -= dt; m.bleedAcc += BLEED_DPS * m.bleedN * dt;
      const d = Math.floor(m.bleedAcc);
      if (d > 0) { m.bleedAcc -= d; Ride.bleedOut(m, d); }
      if (m.bleedT <= 0 || !m.alive) { m.bleedN = 0; m.bleedT = 0; m.bleedAcc = 0; this.beasts.delete(m); }
    }
    if (this.t <= 0) return;
    this.t -= dt; this.acc += BLEED_DPS * this.n * dt;
    const d = Math.floor(this.acc);
    if (d > 0) {
      this.acc -= d;
      if (player.invuln <= 0 && !Game.ended) { player.hp -= d; if (player.hp <= 0) { player.hp = 0; this.stop(); Game.over('bleed'); return; } }
    }
    if (this.t <= 0) { this.stop(); HUD.feed('출혈이 멎었습니다', 0); }
  },
};

/* ---------- a tiger's roar: for one second your legs carry you away from it, whatever you press. up on a giraffe or an elephant you keep your nerve ---------- */
const Fear = {
  t: 0, x: 0, z: 0,
  apply(e) {
    if (state !== 'playing' || Game.ended || player.invuln > 0 || Ride.brave() || Toss.on) return false;
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    this.x = dx / d; this.z = dz / d; this.t = 1;
    player.shake = Math.max(player.shake, 0.25); buzz(80);
    HUD.feed('호랑이 포효 · 겁에 질려 1초 동안 도망칩니다', 0, 'hs');
    return true;
  },
};

/* ---------- a rhino's horn: straight up into the air (no sideways drift). caught again on the way down, you go higher than the time before ---------- */
const _tp = new THREE.Vector3(), _td = new THREE.Vector3();
const Toss = {
  on: false, v: 0, n: 0,
  launch(e) {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return;
    if (Ride.m) { Ride.hurtMount(e.T.dmg * (e.dmgMul || 1) * BEAST_DMG, e); return; } // up on any animal: it takes the horn, you stay on
    jetEnd(); Fear.t = 0;
    this.v = this.on ? Math.min(this.v + 3.6, 26) : 13; this.n = this.on ? this.n + 1 : 1;
    this.on = true; player.vel.set(0, this.v, 0); player.grounded = false; player.pos.y += 0.05;
    player.shake = Math.max(player.shake, 0.45); buzz(140); Sound.thud(player.pos);
    HUD.feed(this.n > 1 ? '떨어지다 또 받혔습니다 · 더 높이 (' + this.n + '번째)' : '코뿔소 뿔에 받혀 하늘로 날아갑니다', 0, 'hs');
  },
  /* coming down: 50 and a bleeding wound for you. whatever you land on takes 30% of its health (the boss 15%) */
  land() {
    this.on = false; this.v = 0; this.n = 0;
    const p = player.pos;
    FX.puff({ x: p.x, y: p.y + 0.2, z: p.z }, 8, 0.9, 0.8); Sound.thud(p); Sound.land(); player.shake = Math.max(player.shake, 0.6); buzz(160);
    let n = 0;
    for (const e of Enemies.list.slice()) {
      if (!e.alive || e.ridden || e.caged || e.downed) continue;
      const d = Math.hypot(e.pos.x - p.x, e.pos.z - p.z);
      if (d > (e.footR || e.R) * 0.85 + player.r + 0.3 || p.y - e.pos.y > e.H + 1.5 || e.pos.y - p.y > 1) continue;
      _tp.set(e.pos.x, e.pos.y + e.H * 0.7, e.pos.z); _td.set(e.pos.x - p.x, -1, e.pos.z - p.z).normalize();
      Enemies.damage(e, Math.round(e.maxHp * (e.boss ? 0.15 : 0.3)), _tp, _td, false); n++;
    }
    if (n) HUD.feed('떨어지며 ' + n + '마리를 덮쳤습니다 · 최대 체력의 30%', 0, 'hs');
    player.hurt(100 * BEAST_DMG, p, 'fall'); if (!Game.ended) Bleed.add();
  },
};

/* ---------- who the beasts go for: you, or the animal you are sitting on ---------- */
const Q = { x: 0, y: 0, z: 0, r: 0.36 };
function quarry() {
  const m = Ride.m;
  if (m) { Q.x = m.pos.x; Q.y = m.pos.y; Q.z = m.pos.z; Q.r = m.R; } else { Q.x = player.pos.x; Q.y = player.pos.y; Q.z = player.pos.z; Q.r = player.r; }
  return Q;
}
/* within reach and in front of the head (and not high above it) */
function inFront(e, q, reach, cosMin) {
  const dx = q.x - e.pos.x, dz = q.z - e.pos.z, d = Math.hypot(dx, dz);
  if (d > reach || q.y > e.pos.y + e.H + 0.3) return false;
  return d < 0.5 || (dx * Math.sin(e.yaw) + dz * Math.cos(e.yaw)) / d >= cosMin;
}
function feetUp() { return player.pos.y - groundAt(player.pos.x, player.pos.y + 0.05, player.pos.z, player.r); }
const noseOf = (e) => (e.foot ? e.foot.z1 : e.R);

const Beast = {
  roarCd: 0, // the lions take turns: one king's roar every 8 seconds at most
  reset() { this.roarCd = 0; },
  /* a blow that lands. gore: a buffalo's charge (25, out cold for 3 s); bite: hippo or lion (25); maul: cheetah or tiger in passing (60).
     every one of them opens a bleeding wound. up on any animal, the one under you takes it instead (and bleeds) */
  hit(e, kind) {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return false;
    const dmg = e.T.dmg * (e.dmgMul || 1) * BEAST_DMG;
    if (Ride.m) { Ride.hurtMount(dmg, e); return true; }
    if (kind === 'gore') {
      Game.stun(e, dmg, 3);
      // thrown aside, out of its line: it runs on past you instead of carrying you along to the wall
      const cx = e.cx || Math.sin(e.yaw), cz = e.cz || Math.cos(e.yaw), rx = player.pos.x - e.pos.x, rz = player.pos.z - e.pos.z;
      const side = Math.sign(rx * cz - rz * cx) || (Math.random() < 0.5 ? 1 : -1);
      if (!Ride.m) { player.vel.x = cz * side * 12 + cx * 3; player.vel.z = -cx * side * 12 + cz * 3; }
      e.ghostT = 0.7;
    } else if (kind === 'neck') { player.hurt(dmg, e.pos, 'body'); Sound.thud(player.pos); Sound.bite(); player.shake = Math.max(player.shake, 0.5); } // a giraffe's head, swung like a club
    else { player.hurt(dmg, e.pos, 'body'); Sound.bite(); player.shake = Math.max(player.shake, kind === 'maul' ? 0.45 : 0.3); }
    if (!Game.ended && !(Tower.active && Tower.on)) Bleed.add(); // up on the watchtower a blow still hurts, but opens no wound
    return true;
  },
  /* the male lion's roar: every animal but the tigers kneels for a moment, gets back a third of its health, and from then on moves and strikes faster */
  kingRoar(e) {
    this.roarCd = 8; Sound.roar(e.pos, 'cat'); Sound.roar(e.pos, 'grunt'); player.shake = Math.max(player.shake, 0.3);
    let n = 0;
    for (const o of Enemies.list) {
      if (!o.alive || !o.animal || o.kong || o.caged || o.releaseT > 0 || o.type === 'tiger') continue;
      if (Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) > 32) continue;
      o.hp = Math.min(o.maxHp, o.hp + o.maxHp * 0.35); if (o.hp >= o.maxHp) o.bar.visible = false;
      o.buff = Math.min(1.5, (o.buff || 1) + 0.1); // 10% faster per roar, up to half as fast again
      if (o !== e && !o.ridden) { o.kneelT = 1.2; o.bs = null; if (o.state === 'charge') o.state = 'chase'; o.windup = 0; o.airborne = false; restPose(o); }
      n++;
    }
    HUD.feed('숫사자 포효 · 동물 ' + n + '마리가 무릎 꿇고 체력 회복 · 더 빠르고 사나워집니다', 0, 'hs');
  },
  /* let out of the cage */
  wake(e) { e.bs = null; e.bt = 0; e.chargeCd = rand(0.4, 2.2); e.roarCd = rand(3, 10); e.attackT = rand(0, 0.6); e.buff = 1; },
};
function restPose(e) { if (e.jaw) e.jaw.rotation.x = 0; if (e.head) e.head.rotation.x = 0; e.body.rotation.x = 0; }
/* kneeling at the lion's roar: forelegs folded under, the chest low */
function kneelPose(e, dt) {
  e.kneelT -= dt;
  const k = e.kneelT > 0 ? clamp(Math.min((1.2 - e.kneelT) / 0.22, e.kneelT / 0.22), 0, 1) : 0;
  e.body.rotation.x = 0.24 * k;
  if (e.legs.length === 4) { e.legs[0].rotation.x = e.legs[1].rotation.x = 1.25 * k; e.legs[2].rotation.x = e.legs[3].rotation.x = 0; }
  e.vel.multiplyScalar(Math.exp(-dt * 6)); groundMove(e, e.vel.x, e.vel.z, dt);
  if (e.kneelT <= 0) restPose(e);
}

/* ---------- moving about ---------- */
const _pd = { x: 0, z: 0 };
/* the way to you: straight when it can see you, along the walking grid otherwise, round the side when it is wedged */
function pursue(e, dist, tx, tz, dt) {
  if (e.detourT > 0) { e.detourT -= dt; _pd.x = e.dx2; _pd.z = e.dz2; return _pd; }
  if (dist < 40 && e.los) { _pd.x = tx; _pd.z = tz; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { _pd.x = _fd.x; _pd.z = _fd.z; } else { _pd.x = tx; _pd.z = tz; }
  return _pd;
}
/* every lion's roar it has heard makes it a little faster */
function beastMove(e, dx, dz, sp, dt) {
  e.vel.multiplyScalar(Math.exp(-dt * 4)); e.bx0 = e.pos.x; e.bz0 = e.pos.z;
  const B = e.buff || 1;
  return groundMove(e, dx * sp * B + e.vel.x, dz * sp * B + e.vel.z, dt);
}
/* somewhere to amble to: open floor inside the lab, not too far */
function labSpot(e, r) {
  for (let k = 0; k < 14; k++) {
    const x = e.pos.x + rand(-r, r), z = e.pos.z + rand(-r, r);
    if (Math.abs(x) > HALF - 3 || Math.abs(z) > HALF - 3 || collideAt(x, 0.05, z, e.R + 0.3, Math.min(e.H, 2))) continue;
    return { x, z };
  }
  return { x: e.pos.x, z: e.pos.z };
}
/* the way out for a frightened zebra: away from you, towards open floor, a little off the last way it went */
function fleeDir(e, ax, az) {
  let best = _pd, bs = -Infinity; const h = Math.min(e.H, 1.6);
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * TAU, x = Math.sin(a), z = Math.cos(a);
    let free = 0;
    for (const d of [1.6, 3.4, 6]) {
      const px = e.pos.x + x * d, pz = e.pos.z + z * d;
      if (Math.abs(px) > HALF - 1.5 || Math.abs(pz) > HALF - 1.5 || collideAt(px, e.pos.y + 0.05, pz, e.R, h)) break;
      free++;
    }
    const sc = (x * ax + z * az) * 1.3 + free * 0.75 + (x * (e.fx || 0) + z * (e.fz || 0)) * 0.35 + rand(-0.5, 0.5);
    if (sc > bs) { bs = sc; best = { x, z }; }
  }
  return best;
}
/* shot: a zebra bolts, and so do the ones right beside it */
function spook(e) {
  for (const o of Enemies.list) {
    if (!o.alive || o.type !== 'zebra' || o.ridden || o.caged || o.releaseT > 0 || o.wild) continue;
    if (o !== e && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) > 7) continue;
    if (o.bs !== 'flee') { o.zigT = 0; if (Math.random() < 0.5) Sound.roar(o.pos, 'bray'); }
    o.bs = 'flee'; o.bt = rand(3.5, 5);
  }
}

/* ---------- the kinds ---------- */
/* zebras never fight: they amble about and graze. shot, they bolt, zig-zagging fast, for a few seconds. tamed animals live the same quiet life */
function zebraAI(e, dt, dist, tx, tz) {
  const T = e.T; e.bt -= dt;
  let sp = 0, dx = 0, dz = 0, turn = T.turn;
  if (e.bs === 'flee') {
    e.zigT -= dt;
    if (e.zigT <= 0) { e.zigT = rand(0.3, 0.65); const d = fleeDir(e, -tx, -tz); e.fx = d.x; e.fz = d.z; }
    dx = e.fx; dz = e.fz; sp = T.run * 0.86; turn = 11;
    if (e.bt <= 0) { e.bs = 'graze'; e.bt = rand(1.5, 3.5); }
  } else if (e.bs === 'walk') {
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l < 1.2 || e.bt <= 0) { e.bs = 'graze'; e.bt = rand(1.5, 4); } else { dx = wx / l; dz = wz / l; sp = T.speed * (e.type === 'zebra' ? 1 : 0.8); }
  } else {
    if (e.bs !== 'graze') { e.bs = 'graze'; e.bt = rand(0.5, 2.5); }
    if (e.bt <= 0) { e.bs = 'walk'; e.bt = rand(3, 7); const p = labSpot(e, 14); e.wx = p.x; e.wz = p.z; }
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && e.bs === 'walk') e.bt = 0;
  if (blocked && e.bs === 'flee') e.zigT = Math.min(e.zigT, 0.05);
  if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), turn, dt);
  animalGait(e, sp, dt);
  e.body.rotation.x = lerp(e.body.rotation.x, e.bs === 'graze' ? 0.1 : 0, 1 - Math.exp(-dt * 4)); // nose down to the straw
}

/* buffalo: stops, paws the floor, then runs dead straight. a wall met at a slant turns the run along the wall; only a wall met head-on,
   or a corner, stops it. whoever is in the way takes 50, is out cold for 3 seconds and bleeds */
function buffaloAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1; e.bt -= dt * B; e.chargeCd -= dt * B;
  let sp = 0, dx = 0, dz = 0, turn = T.turn, pitch = 0;
  if (e.bs === 'aim') {
    turnToward(e, faceYaw, 5, dt); pitch = 0.12;
    if (e.bt <= 0) {
      e.bs = 'rush'; e.bt = 6; e.cx = tx; e.cz = tz; e.yaw = Math.atan2(tx, tz); e.g.rotation.y = e.yaw; e.hitDone = false;
      Sound.roar(e.pos, T.roar); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 3, 0.6, 0.6);
    }
  } else if (e.bs === 'rush') {
    dx = e.cx; dz = e.cz; sp = T.run * 1.15; turn = 16; pitch = 0.14;
    // real headway since last time (something pressed against its head, like you against a wall, stops it too)
    const net = e.lastX === undefined ? 1 : Math.hypot(e.pos.x - e.lastX, e.pos.z - e.lastZ);
    e.pinT = net < sp * B * dt * 0.3 ? (e.pinT || 0) + dt : 0; if (e.pinT > 0.3) { e.bs = 'daze'; e.bt = 1.3; e.pinT = 0; }
    const q = quarry(), rx = q.x - e.pos.x, rz = q.z - e.pos.z, f = rx * dx + rz * dz, l = Math.abs(rx * dz - rz * dx);
    if (!e.hitDone && f > -e.R && f < noseOf(e) + q.r + 0.25 && l < e.R + q.r + 0.3 && q.y < e.pos.y + e.H + 0.2) { e.hitDone = true; Beast.hit(e, 'gore'); }
    if (Math.random() < dt * 12) FX.puff({ x: e.pos.x - dx, y: 0.2, z: e.pos.z - dz }, 1, 0.5, 0.35);
    if (e.bt <= 0) { e.bs = 'daze'; e.bt = 0.8; }
  } else if (e.bs === 'daze') {
    pitch = 0.18; e.g.rotation.y = e.yaw + Math.sin(e.bt * 16) * 0.12;
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(0.8, 2); e.g.rotation.y = e.yaw; }
  } else {
    if (e.bs !== 'seek') e.bs = 'seek';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z; sp = T.run * 0.42;
    if (e.chargeCd <= 0 && e.los && dist > 4 && dist < 42) { e.bs = 'aim'; e.bt = 0.75; sp = 0; }
  }
  e.lastX = e.pos.x; e.lastZ = e.pos.z; if (e.ghostT > 0) e.ghostT -= dt;
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'rush') {
    // how far it really got: short of the step means something solid. head-on (or a corner) stops it; a slant sends it along the wall
    const want = sp * B * dt, mx = e.pos.x - e.bx0, mz = e.pos.z - e.bz0, got = Math.hypot(mx, mz);
    if (got < want * 0.94 && !smashAhead(e, e.cx, e.cz)) {
      if (got < want * 0.3) {
        e.bs = 'daze'; e.bt = 1.3; Sound.thud(e.pos); FX.puff({ x: e.pos.x + e.cx * e.R, y: 1, z: e.pos.z + e.cz * e.R }, 6, 0.5, 0.8);
        if (dist < 20) player.shake = Math.max(player.shake, 0.12);
      } else { e.cx = mx / got; e.cz = mz / got; }
    }
    turnToward(e, Math.atan2(e.cx, e.cz), turn, dt);
  } else if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), turn, dt); }
  animalGait(e, sp, dt);
  if (e.bs === 'aim' && e.legs[0]) e.legs[0].rotation.x = Math.sin(e.bt * 22) * 0.55; // pawing the floor
  e.body.rotation.x = lerp(e.body.rotation.x, pitch, 1 - Math.exp(-dt * 8));
}

/* hippo, and the male lion who bites the same way: come close, open wide, and clamp shut. 50 and a bleeding wound.
   the lion also roars now and then (see Beast.kingRoar) */
function biterAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, lion = e.type === 'lionM'; e.bt -= dt * B; e.attackT -= dt * B; e.roarCd -= dt;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), reach = noseOf(e) + q.r + 0.45;
  let sp = 0, dx = 0, dz = 0, open = 0, look = 0;
  if (e.bs === 'gape') {
    open = clamp(1 - e.bt / e.btMax, 0, 1); turnToward(e, faceYaw, 6, dt);
    if (qd > reach * 0.85) { dx = tx; dz = tz; sp = 1.8; }
    if (e.bt <= 0) { e.bs = 'snap'; e.bt = 0.13; e.bit = false; }
  } else if (e.bs === 'snap') {
    open = clamp(e.bt / 0.13, 0, 1);
    if (!e.bit) { e.bit = true; Sound.thud(e.pos); if (inFront(e, q, reach + 0.4, 0.5)) Beast.hit(e, 'bite'); }
    if (e.bt <= 0) { e.bs = 'chase'; e.attackT = rand(0.6, 0.95); }
  } else if (e.bs === 'roar') {
    open = 1; look = 1; turnToward(e, faceYaw, 3, dt);
    if (!e.roared && e.bt < 1.0) { e.roared = true; Beast.kingRoar(e); }
    if (e.bt <= 0) { e.bs = 'chase'; e.roarCd = rand(16, 24); }
  } else {
    if (e.bs !== 'chase') e.bs = 'chase';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z;
    sp = qd > reach - 0.15 ? T.run * (lion ? 0.62 : 0.78) : 0;
    if (qd < reach && e.attackT <= 0) { e.bs = 'gape'; e.bt = e.btMax = lion ? 0.42 : 0.6; Sound.roar(e.pos, lion ? 'cat' : 'grunt'); }
    else if (lion && e.roarCd <= 0 && Beast.roarCd <= 0 && dist < 30 && e.los) { e.bs = 'roar'; e.bt = 1.4; e.roared = false; Beast.roarCd = 2; }
  }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'chase') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); turnToward(e, qd < 8 ? faceYaw : Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  // the hippo's whole head tips back as the jaw drops; the lion just opens wide (and lifts his chin to roar)
  if (e.head) e.head.rotation.x = -0.95 * open;
  if (e.jaw) e.jaw.rotation.x = (lion ? 0.85 : 0.55) * open;
  e.body.rotation.x = lerp(e.body.rotation.x, lion ? -0.12 * look : 0, 1 - Math.exp(-dt * 8));
}

/* rhino: a charge that slows as it closes, then the horn comes up and you go straight up into the air.
   coming down within its reach, you get thrown again, higher each time */
function rhinoAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1; e.bt -= dt * B; e.chargeCd -= dt * B;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), reach = noseOf(e) + q.r + 0.5;
  let sp = 0, dx = 0, dz = 0, head = 0;
  // you are falling towards it: up goes the horn, timed so it meets you about a horn's height up
  if (Toss.on && player.vel.y < 0 && qd < reach + 0.5 && e.bs !== 'flick' && feetUp() + player.vel.y * 0.13 - 0.15 < 2.6) { e.bs = 'flick'; e.bt = 0.3; e.tossed = false; }
  if (e.bs === 'rush') {
    turnToward(e, faceYaw, 1.8, dt); dx = Math.sin(e.yaw); dz = Math.cos(e.yaw); sp = T.run * 1.05; head = 0.3;
    if (Math.random() < dt * 10) FX.puff({ x: e.pos.x - dx, y: 0.2, z: e.pos.z - dz }, 1, 0.5, 0.35);
    if (qd < reach + 2.6) { e.bs = 'brake'; e.bt = e.btMax = 0.4; e.v0 = sp; }
    else if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(1, 2); }
  } else if (e.bs === 'brake') {
    const u = clamp(e.bt / e.btMax, 0, 1); sp = lerp(1.2, e.v0, u); head = 0.3 + 0.18 * (1 - u);
    turnToward(e, faceYaw, 4.5, dt); dx = Math.sin(e.yaw); dz = Math.cos(e.yaw);
    if (e.bt <= 0) { e.bs = 'flick'; e.bt = 0.3; e.tossed = false; }
  } else if (e.bs === 'flick') {
    const u = 1 - clamp(e.bt / 0.3, 0, 1); head = u < 0.4 ? 0.48 - u * 3.3 : -0.85; turnToward(e, faceYaw, 6, dt);
    if (!e.tossed && u >= 0.4) {
      e.tossed = true; Sound.swoosh(e.pos);
      const dx = q.x - e.pos.x, dz = q.z - e.pos.z, d = Math.hypot(dx, dz), facing = d < 0.5 || (dx * Math.sin(e.yaw) + dz * Math.cos(e.yaw)) / d >= 0.3;
      if (d < reach + 0.35 && facing && (Ride.m || feetUp() < 3.0)) Toss.launch(e); // the horn reaches about 3 m up
    }
    if (e.bt <= 0) { e.bs = 'recover'; e.bt = 0.9; }
  } else if (e.bs === 'recover') {
    head = -0.85 * clamp(e.bt / 0.9, 0, 1);
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(0.8, 2); }
  } else if (e.bs === 'stun') {
    head = 0.2 + Math.sin(e.bt * 14) * 0.12;
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(1, 2); }
  } else {
    if (e.bs !== 'seek') e.bs = 'seek';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z; sp = T.run * 0.4;
    if (qd < reach + 1.2 && !Toss.on) { e.bs = 'brake'; e.bt = e.btMax = 0.25; e.v0 = sp; }
    else if (e.chargeCd <= 0 && e.los && dist > 6 && dist < 40 && !Toss.on) { e.bs = 'rush'; e.bt = 4; Sound.roar(e.pos, T.roar); }
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && (e.bs === 'rush' || e.bs === 'brake') && !smashAhead(e, dx, dz)) {
    e.bs = 'stun'; e.bt = 1.1; Sound.thud(e.pos); FX.puff({ x: e.pos.x + dx * e.R, y: 1, z: e.pos.z + dz * e.R }, 6, 0.5, 0.8);
  }
  if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  if (e.head) e.head.rotation.x = lerp(e.head.rotation.x, head, 1 - Math.exp(-dt * (e.bs === 'flick' ? 40 : 10)));
}

/* cheetah (the fastest thing in here), and the tiger who hunts the same way: a dead-straight sprint along a line that passes just beside you,
   a bite in passing at the closest point (120 and a bleeding wound), and a stop a few metres behind you. then round for another go.
   the tiger also roars: whoever is not up on a giraffe or an elephant runs away for a second */
function startRun(e, q) {
  const rx = q.x - e.pos.x, rz = q.z - e.pos.z, d = Math.hypot(rx, rz) || 1, ux = rx / d, uz = rz / d, side = Math.random() < 0.5 ? 1 : -1;
  const ax = q.x - uz * side * 1.1, az = q.z + ux * side * 1.1, ad = Math.hypot(ax - e.pos.x, az - e.pos.z) || 1; // a point just off your shoulder
  e.cx = (ax - e.pos.x) / ad; e.cz = (az - e.pos.z) / ad; e.bs = 'run'; e.bt = 3; e.bit = false;
  Sound.roar(e.pos, 'cat');
}
function runnerAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, tiger = e.type === 'tiger'; e.bt -= dt * B; e.chargeCd -= dt * B; e.roarCd -= dt;
  const q = quarry();
  let sp = 0, dx = 0, dz = 0, open = 0, turn = T.turn, lift = 0;
  if (e.bs === 'run') {
    dx = e.cx; dz = e.cz; sp = T.run; turn = 24;
    const rx = q.x - e.pos.x, rz = q.z - e.pos.z, f = rx * dx + rz * dz, l = Math.abs(rx * dz - rz * dx), nose = noseOf(e);
    open = clamp(1 - (f - nose) / 5, 0, 1); // the mouth opens as it draws level
    if (!e.bit && f <= nose * 0.8) {
      e.bit = true;
      if (l < q.r + 1.2 && Math.abs(q.y - e.pos.y) < e.H + 0.4) Beast.hit(e, 'maul');
      e.bs = 'pass'; e.passV = sp;
    } else if (e.bt <= 0) { e.bs = 'pass'; e.passV = sp; }
  } else if (e.bs === 'pass') {
    // keeps going past you, slowing to a stop in about three metres
    e.passV = Math.max(0, e.passV - (T.run * T.run / 6) * dt * B); sp = e.passV / B; dx = e.cx; dz = e.cz; turn = 2;
    open = clamp(e.passV / T.run, 0, 1) * 0.5;
    if (e.passV <= 0.4) { e.bs = 'turn'; e.bt = 0.5; }
  } else if (e.bs === 'turn') {
    turnToward(e, faceYaw, 8, dt);
    if (e.bt <= 0) { e.bs = 'stalk'; e.chargeCd = rand(0.2, 0.8); }
  } else if (e.bs === 'roar') {
    open = 1; lift = 1; turnToward(e, faceYaw, 4, dt);
    if (!e.roared && e.bt < 0.75) { e.roared = true; Sound.roar(e.pos, 'cat'); Sound.roar(e.pos, 'cat'); if (dist < 24 && e.los) Fear.apply(e); }
    if (e.bt <= 0) { e.bs = 'stalk'; e.roarCd = rand(9, 14); }
  } else {
    if (e.bs !== 'stalk') e.bs = 'stalk';
    const d = pursue(e, dist, tx, tz, dt);
    if (dist < 6) { dx = -tx; dz = -tz; sp = T.speed * 2.2; } // too close for a run: open the distance first
    else { dx = d.x; dz = d.z; sp = dist > 30 ? T.run * 0.5 : T.speed * 1.4; }
    if (tiger && e.roarCd <= 0 && dist < 24 && e.los) { e.bs = 'roar'; e.bt = 1.15; e.roared = false; sp = 0; }
    else if (e.chargeCd <= 0 && e.los && dist >= 6 && dist < 34) startRun(e, q);
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && (e.bs === 'run' || e.bs === 'pass')) { e.bs = 'turn'; e.bt = 0.6; }
  if (e.bs === 'stalk') unstick(e, e.bx0, e.bz0, dx, dz, sp, dt);
  if (sp > 0.1 && e.bs !== 'turn' && e.bs !== 'roar') turnToward(e, e.bs === 'stalk' && dist < 6 ? faceYaw : Math.atan2(dx, dz), turn, dt);
  animalGait(e, sp, dt);
  if (e.jaw) e.jaw.rotation.x = 0.75 * open;
  e.body.rotation.x = lerp(e.body.rotation.x, -0.1 * lift, 1 - Math.exp(-dt * 8));
}
/* giraffe: walks up to you and swings its long neck down like a club (24 and a bleeding wound). the neck reaches a long way,
   up over a watchtower's railing too: on the safari it is the one animal that goes for you up there instead of the tower */
function neckPose(e, a, dt) {
  if (!e.head) return;
  const r = e.head.rotation.x = lerp(e.head.rotation.x, a, 1 - Math.exp(-dt * 16));
  // the head and neck hit spheres swing with it
  if (!e.neckBase) e.neckBase = [0, 1].map((i) => [e.parts[i].o.y, e.parts[i].o.z]);
  const c = Math.cos(r), s = Math.sin(r), py = GIRAFFE_NECK[0], pz = GIRAFFE_NECK[1];
  for (let i = 0; i < 2; i++) { const [y, z] = e.neckBase[i], ly = y - py, lz = z - pz; e.parts[i].o.y = py + ly * c - lz * s; e.parts[i].o.z = pz + ly * s + lz * c; }
}
function giraffeAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, sc = e.scale || 1; e.bt -= dt * B; e.attackT -= dt * B;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), high = q.y - e.pos.y;
  const reach = (high > 2 ? 4.3 : 3.4) * sc + q.r, inReach = qd < reach && high < 5.4 * sc && high > -1.5;
  const toQ = Math.atan2(q.x - e.pos.x, q.z - e.pos.z);
  let sp = 0, dx = 0, dz = 0, neck = 0;
  if (e.bs === 'rear') {
    neck = -0.5 * (1 - clamp(e.bt / 0.45, 0, 1)); turnToward(e, toQ, 5, dt);
    if (e.bt <= 0) { e.bs = 'swing'; e.bt = 0.16; e.hitDone = false; Sound.swoosh(e.pos); }
  } else if (e.bs === 'swing') {
    const u = 1 - clamp(e.bt / 0.16, 0, 1); neck = -0.5 + 1.1 * u;
    if (!e.hitDone && u >= 0.6) {
      e.hitDone = true;
      const f = qd < 0.5 || ((q.x - e.pos.x) * Math.sin(e.yaw) + (q.z - e.pos.z) * Math.cos(e.yaw)) / qd >= 0.35;
      if (qd < reach + 0.4 && high < 5.6 * sc && high > -1.5 && f) Beast.hit(e, 'neck');
    }
    if (e.bt <= 0) { e.bs = 'recover'; e.bt = 0.55; }
  } else if (e.bs === 'recover') {
    neck = 0.6 * clamp(e.bt / 0.55, 0, 1);
    if (e.bt <= 0) { e.bs = 'seek'; e.attackT = high > 2 ? rand(1.8, 2.6) : rand(0.7, 1.2); } // reaching up over a railing takes it longer to gather itself
  } else {
    if (e.bs !== 'seek') { e.bs = 'seek'; e.attackT = Math.max(e.attackT || 0, 0.3); }
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z;
    sp = qd > reach - 0.6 ? T.run * (dist > 30 ? 0.55 : 0.42) : 0;
    if (inReach && e.attackT <= 0) { e.bs = 'rear'; e.bt = 0.45; sp = 0; if (Math.random() < 0.5) Sound.roar(e.pos, 'grunt'); }
  }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1 || qd < 10) turnToward(e, qd < 10 ? toQ : Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  neckPose(e, neck, dt);
}
const BEASTS = { zebra: zebraAI, buffalo: buffaloAI, hippo: biterAI, lionM: biterAI, rhino: rhinoAI, cheetah: runnerAI, tiger: runnerAI, giraffe: giraffeAI };

/* ---------- riding: a zebra from the floor, a giraffe from a zebra, an elephant from a giraffe ---------- */
/* seat: where you sit (above the ground, and forward of the middle), how fast it goes walking and running, how quickly it turns */
const SEAT = {
  zebra: { tier: 1, y: 1.62, z: -0.35, walk: 6, run: 12.5, turn: 7, name: '얼룩말' },
  giraffe: { tier: 2, y: 4.35, z: 0.8, walk: 5, run: 10, turn: 4.5, name: '기린' }, // high on the neck, behind the head
  elephant: { tier: 3, y: 3.45, z: 1.05, walk: 4.5, run: 8.2, turn: 3, name: '코끼리' },
};
const Ride = {
  m: null, tier: 0, vx: 0, vz: 0, ease: 1, from: new THREE.Vector3(), target: null, findT: 0,
  /* up on a giraffe or an elephant: no fear, and blows land on the animal, not on you */
  brave() { return !!this.m && this.tier >= 2; },
  ok(e) {
    if (!e.alive || !e.animal || e.kong || e.caged || e.releaseT > 0 || e === this.m || !SEAT[e.type]) return false;
    if (e.tamed) return true; // one you have ridden before lets you straight back on, from the ground or from another animal
    return SEAT[e.type].tier <= this.tier + 1;
  },
  /* what you could get onto right now: in reach, roughly in front of you; the closest to where you look wins */
  find() {
    if (!World.style.ride || state !== 'playing' || Game.ended || player.stunT > 0 || Toss.on || Fear.t > 0 || Jet.on) return null;
    if (!this.m && !player.grounded) return null;
    const fx = -Math.sin(player.yaw), fz = -Math.cos(player.yaw), from = this.m ? this.m.R : player.r;
    let best = null, bs = Infinity;
    for (const e of Enemies.list) {
      if (!this.ok(e)) continue;
      const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z, d = Math.hypot(dx, dz), near = e.R + from + 1.6;
      if (d > near) continue;
      const cos = (dx * fx + dz * fz) / (d || 1);
      if (cos < 0.15 && d > e.R + from + 0.4) continue;
      const sc = d * (1.7 - cos);
      if (sc < bs) { bs = sc; best = e; }
    }
    return best;
  },
  /* E (or the button): get on what is in front of you; on one already with nothing new in reach, get off */
  toggle() { const t = this.find(); if (t) this.on(t); else if (this.m) this.off(false); },
  on(e) {
    const prev = this.m;
    if (prev) this.free(prev);
    this.m = e; this.tier = SEAT[e.type].tier; e.ridden = true; e.vel.set(0, 0, 0); e.kneelT = 0; e.bs = 'ride'; e.state = 'wander'; e.windup = 0; restPose(e);
    e.bar.visible = false;
    if (!e.tamed) { e.tamed = true; Game.tame(e); }
    jetEnd(); Fear.t = 0;
    this.vx = this.vz = 0; this.ease = 0; this.from.copy(camera.position); player.vel.set(0, 0, 0);
    Sound.roar(e.pos, e.T.roar);
    const S = SEAT[e.type], next = e.type === 'zebra' ? ' · 공격은 얼룩말이 대신 맞습니다 · 이대로 기린에게 다가가면 옮겨 탈 수 있습니다' : e.type === 'giraffe' ? ' · 공포에 걸리지 않고 공격은 기린이 대신 맞습니다 · 코끼리로 옮겨 탈 수 있습니다' : ' · 공격은 코끼리가 대신 맞습니다';
    HUD.feed(S.name + (prev ? euroK(S.name) + ' 옮겨 탔습니다' : '에 탔습니다') + ' · 위에서도 총을 쏩니다', 0);
    HUD.hint(S.name + ' 탑승' + next, 3.2);
  },
  free(m) { m.ridden = false; m.bs = 'graze'; m.bt = rand(1, 3); m.vel.set(0, 0, 0); },
  /* step down beside it: right, left, behind or in front, wherever there is room */
  off(forced, msg) {
    const m = this.m; if (!m) return;
    this.m = null; this.tier = 0;
    if (m.alive) this.free(m);
    const gap = m.R + player.r + 0.35, cy = Math.cos(m.yaw), sy = Math.sin(m.yaw);
    let x = m.pos.x, z = m.pos.z;
    for (const [ox, oz] of [[cy, -sy], [-cy, sy], [-sy, -cy], [sy, cy]]) {
      const px = m.pos.x + ox * gap, pz = m.pos.z + oz * gap;
      if (Math.abs(px) < HALF - 1 && Math.abs(pz) < HALF - 1 && !collideAt(px, m.pos.y + 0.05, pz, player.r, player.height)) { x = px; z = pz; break; }
    }
    player.pos.set(x, groundAt(x, m.pos.y + 0.6, z, player.r), z); player.vel.set(0, 0, 0); player.grounded = true;
    if (msg) HUD.feed(msg, 0, 'hs'); else if (!forced) HUD.feed('내렸습니다', 0);
  },
  /* steering: it goes where you push, relative to where you look, and turns its body that way. you keep looking (and shooting) wherever you like */
  update(dt, f, s, run, stunned) {
    const m = this.m, S = SEAT[m.type];
    if (!m.alive) { this.off(true, S.name + (hasBatchim(S.name) ? '이' : '가') + ' 쓰러졌습니다 · 땅에 내려섰습니다'); return false; }
    let wx = 0, wz = 0, sp = 0;
    if (!stunned) {
      if (Fear.t > 0) { wx = Fear.x; wz = Fear.z; sp = S.run; }
      else if (f || s) {
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw); wx = -sy * f + cy * s; wz = -cy * f - sy * s;
        const l = Math.hypot(wx, wz) || 1; wx /= l; wz /= l; sp = (run ? S.run : S.walk) * Math.min(1, Math.hypot(f, s));
      }
    }
    const k = 1 - Math.exp(-dt * 5); this.vx += (wx * sp - this.vx) * k; this.vz += (wz * sp - this.vz) * k;
    const B = m.buff || 1, x0 = m.pos.x, z0 = m.pos.z;
    if (groundMove(m, this.vx * B, this.vz * B, dt)) {
      if (m.type === 'elephant' && sp > 0) smashAhead(m, wx, wz); // an elephant walks through crates
      this.vx = (m.pos.x - x0) / dt / B; this.vz = (m.pos.z - z0) / dt / B;
    }
    const v = Math.hypot(this.vx, this.vz);
    if (v > 0.4) turnToward(m, Math.atan2(this.vx, this.vz), S.turn, dt);
    animalGait(m, v, dt);
    this.seat();
    return true;
  },
  seat() {
    const m = this.m, S = SEAT[m.type], sc = m.scale || 1;
    player.pos.set(m.pos.x + Math.sin(m.yaw) * S.z * sc, m.pos.y + S.y * sc - 0.7, m.pos.z + Math.cos(m.yaw) * S.z * sc);
  },
  /* the camera glides up onto the seat over a third of a second, then rides with a little sway */
  cam(out, dt) {
    const m = this.m, v = Math.hypot(this.vx, this.vz), sway = Math.sin(m.walk * 2) * 0.035 * clamp(v / 6, 0, 1);
    this.ease = Math.min(1, this.ease + dt / 0.35); const k = this.ease * this.ease * (3 - 2 * this.ease);
    out.set(lerp(this.from.x, player.pos.x, k), lerp(this.from.y, player.pos.y + player.eye + sway, k), lerp(this.from.z, player.pos.z, k));
  },
  /* the rest of the herd shoves the animal you sit on about: stay in the saddle */
  post() {
    if (!this.m || !this.m.alive) return;
    const ox = player.pos.x, oy = player.pos.y, oz = player.pos.z; this.seat();
    if (this.ease >= 1) { camera.position.x += player.pos.x - ox; camera.position.y += player.pos.y - oy; camera.position.z += player.pos.z - oz; }
  },
  /* a blow meant for you lands on the animal you are sitting on, and opens a wound in it (the giant gorilla's do not). the beasts killing it pays you nothing */
  hurtMount(dmg, from) {
    const m = this.m; if (!m || !m.alive) return;
    m.noPay = true;
    _tp.set(m.pos.x, m.pos.y + m.H * 0.5, m.pos.z); _td.set(m.pos.x - from.pos.x, 0, m.pos.z - from.pos.z); if (_td.lengthSq() < 1e-6) _td.set(0, 0, 1); _td.normalize();
    Enemies.damage(m, dmg, _tp, _td, false);
    if (m.alive) { m.noPay = false; if (!from.boss) Bleed.addTo(m); }
    player.shake = Math.max(player.shake, 0.15); HUD.hurt(6, from.pos);
  },
  /* a wound ticking away: quiet damage, and bleeding to death pays nobody */
  bleedOut(m, d) {
    m.noPay = true; _tp.set(m.pos.x, m.pos.y + m.H * 0.5, m.pos.z); _td.set(0, 0, 1);
    Enemies.damage(m, d, _tp, _td, false, true);
    if (m.alive) m.noPay = false;
  },
  reset() { if (this.m) { this.m.ridden = false; this.m = null; } this.tier = 0; this.vx = this.vz = 0; this.ease = 1; this.target = null; },
};
function hasBatchim(w) { const c = w.charCodeAt(w.length - 1) - 0xac00; return c >= 0 && c <= 11171 && c % 28 !== 0; }
/* "으로" after a closing consonant other than ㄹ, "로" otherwise */
function euroK(w) { const c = w.charCodeAt(w.length - 1) - 0xac00; return c >= 0 && c <= 11171 && c % 28 !== 0 && c % 28 !== 8 ? '으로' : '로'; }
