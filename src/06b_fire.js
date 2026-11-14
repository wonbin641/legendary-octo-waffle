
/* ============ weapons: firing, reload, switching ============ */
const _fwd = new THREE.Vector3(), _right = new THREE.Vector3(), _up = new THREE.Vector3(), _dir = new THREE.Vector3(), _hitP = new THREE.Vector3(), _muz = new THREE.Vector3();
function curW() { return WEAPONS[Gun.cur]; }
function muzzleWorld(out) {
  camera.getWorldDirection(_fwd); _right.set(1, 0, 0).applyQuaternion(camera.quaternion); _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
  const a = Gun.ads;
  out.copy(camera.position).addScaledVector(_fwd, 0.7).addScaledVector(_right, 0.16 * (1 - a)).addScaledVector(_up, -0.12 * (1 - a) - 0.03 - 0.06 * a);
  return out;
}
function currentSpread() {
  const w = curW(), mv = clamp(player.speedXZ / 6, 0, 1.4);
  let s = lerp(w.spread, w.adsSpread, Gun.ads) + Gun.bloom + w.moveSpread * mv * (1 - Gun.ads * 0.6);
  if (!player.grounded) s += 0.03;
  return s;
}
/* ---------- the rocket launcher's lock: the living enemy nearest the middle of the screen, within about 10 degrees, 200 m and in sight ---------- */
const _lk = new THREE.Vector3(), _lf = new THREE.Vector3();
function rocketLock() {
  camera.getWorldDirection(_lf); const o = camera.position; let best = null, bestA = 0.18;
  for (const e of Enemies.list) {
    if (!e.alive || e.ridden || e.caged || !e.g.visible || (e.T && e.T.mode === 'mine' && (e.bs === 'hidden' || !e.bs))) continue;
    Proj.rocketCentre(e, _lk); const dx = _lk.x - o.x, dy = _lk.y - o.y, dz = _lk.z - o.z, d = Math.hypot(dx, dy, dz);
    if (d < 2.5 || d > 200) continue;
    const a = Math.acos(clamp((dx * _lf.x + dy * _lf.y + dz * _lf.z) / d, -1, 1));
    if (a >= bestA || !lineOfSight(o, _lk)) continue;
    best = e; bestA = a;
  }
  return best;
}
/* ---------- melee: V or the mouse's back button (on a touch screen the 근접 button). a quick jab with the gun at whatever is within
   arm's reach. 5.20: in the Android app a wooden crate that comes within that reach in front of you is jabbed by itself ---------- */
// 120 to the body, twice that to the head; it makes no noise, cuts a reload short, and breaks crates too
const MELEE_DMG = 120, MELEE_REACH = 2.3, MELEE_T = 0.42, CRATE_AUTO_RANGE = 12;
const Melee = {
  t: 0, cd: 0, on: false, hit: false, target: null,
  start(target) {
    if (state !== 'playing' || this.cd > 0 || Gun.none || Gun.busy > 0 || player.stunT > 0 || Gun.switchT > 0) return;
    this.on = true; this.t = 0; this.cd = 0.62; this.hit = false; this.target = target || null;
    Gun.reloadT = 0; Gun.trigger = false; Gun.adsHeld = false;
    Sound.swing();
  },
  reset() { this.on = false; this.t = 0; this.cd = 0; this.target = null; },
  /* the app only: a crate within the jab's reach (2.3 m from your eyes to the nearest point of the crate) and not behind you, and you
     are not busy with anything else (shooting, aiming, reloading, switching, injecting, riding, in the air): the jab goes at it.
     one jab breaks a crate */
  autoCrate() {
    if (!isApp || this.on || this.cd > 0 || state !== 'playing' || Gun.none || Gun.busy > 0 || Gun.reloadT > 0 || Gun.switchT > 0 || Gun.trigger || Gun.adsHeld || Gun.ads > 0.05) return;
    if (player.stunT > 0 || !player.grounded || Car.riding || Ride.m || Toss.on || Jet.on) return;
    const o = camera.position, fx = -Math.sin(player.yaw), fz = -Math.cos(player.yaw); let best = null, bd = MELEE_REACH;
    for (const c of crates) {
      if (c.dead) continue;
      const b = c.b, qx = clamp(o.x, b.minx, b.maxx), qy = clamp(o.y, b.miny, b.maxy), qz = clamp(o.z, b.minz, b.maxz), d = Math.hypot(qx - o.x, qy - o.y, qz - o.z);
      const dx = c.x - player.pos.x, dz = c.z - player.pos.z, h = Math.hypot(dx, dz) || 1;
      if (d < bd && (dx * fx + dz * fz) / h > 0.35) { best = c; bd = d; } // within about 70 degrees of straight ahead
    }
    if (best) this.start(best);
  },
  update(dt) {
    this.cd = Math.max(0, this.cd - dt);
    if (!this.on) return;
    this.t += dt;
    if (!this.hit && this.t >= 0.11) { this.hit = true; this.strike(); }
    if (this.t >= MELEE_T) this.on = false;
  },
  /* a fan of short rays: the nearest body in reach wins (a head over a body at the same distance), else a crate */
  strike() {
    if (this.target) { const c = this.target; this.target = null; if (c.dead) return; // sent at a crate: it is hit, whatever the rays say
      _hitP.set(c.x, (c.y || 0) + 0.6, c.z); damageCrate(c, 60, _hitP); Sound.melee(_hitP, false); buzz(20); return; }
    camera.getWorldDirection(_fwd); _right.set(1, 0, 0).applyQuaternion(camera.quaternion); _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
    const o = camera.position; let best = null;
    for (const [a, b] of [[0, 0], [0.16, 0], [-0.16, 0], [0, -0.15], [0, 0.12], [0.3, -0.12], [-0.3, -0.12], [0, -0.32]]) {
      _dir.copy(_fwd).addScaledVector(_right, a).addScaledVector(_up, b).normalize();
      raycastStatic(o.x, o.y, o.z, _dir.x, _dir.y, _dir.z, MELEE_REACH);
      const sT = RH.t, sBox = RH.box, eh = Enemies.raycast(o, _dir, sT);
      if (eh) { if (!best || best.crate || eh.t < best.t - 0.15 || (eh.weak && !best.weak && eh.t < best.t + 0.15)) best = { e: eh.enemy, t: eh.t, weak: eh.weak, mult: eh.mult, bomb: eh.bomb, d: _dir.clone() }; }
      else if (!best && sBox && sBox.kind === 'wood' && sBox.ref && sT < MELEE_REACH) best = { crate: sBox.ref, t: sT, d: _dir.clone() };
    }
    if (!best) return;
    _hitP.copy(o).addScaledVector(best.d, best.t);
    if (best.crate) { damageCrate(best.crate, 60, _hitP); Sound.melee(_hitP, false); return; }
    const e = best.e;
    let killed = false;
    if (best.bomb && e.alive) { Enemies.blowVest(e, best.d); killed = true; }
    else killed = Enemies.damage(e, MELEE_DMG * (best.weak ? 2 : best.mult || 1), _hitP, best.d, best.weak);
    if (e.alive && !e.boss && !e.kong && !e.robot) { e.vel.x += best.d.x * 4; e.vel.z += best.d.z * 4; } // and a shove
    HUD.hitmark(killed, best.weak); Sound.melee(_hitP, !!e.robot); player.shake = Math.max(player.shake, 0.12); buzz(30);
  },
  /* the jab: the gun thrusts forward and turns on its side, then comes back */
  pose(root) {
    if (!this.on) return;
    const u = this.t / MELEE_T, k = u < 0.28 ? u / 0.28 : Math.max(0, 1 - (u - 0.28) / 0.72), j = k * k * (3 - 2 * k);
    root.position.x -= j * 0.12; root.position.y += j * 0.03; root.position.z -= j * 0.3;
    root.rotation.x += j * 0.15; root.rotation.y += j * 0.9; root.rotation.z += j * 0.35;
  },
};
/* 5.14: the machine gun's heat. every shot adds 1/240; once you stop for a moment it cools by a fifth a second. empty a full box in one
   go and it overheats: it glows red, smokes off the barrel, and will not reload until you have swapped to another gun */
const _hotRed = new THREE.Color(0x8a0d06);
const Heat = (() => {
  let smokeMat = null; const parts = []; let spawnT = 0; const _p = new THREE.Vector3();
  function ensure() {
    if (smokeMat) return;
    const tex = canvasTex(64, 64, (g) => { const r = g.createRadialGradient(32, 32, 0, 32, 32, 32); r.addColorStop(0, 'rgba(235,235,235,0.9)'); r.addColorStop(0.5, 'rgba(205,205,205,0.35)'); r.addColorStop(1, 'rgba(180,180,180,0)'); g.fillStyle = r; g.fillRect(0, 0, 64, 64); });
    smokeMat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, opacity: 0 });
    for (let i = 0; i < 20; i++) { const s = new THREE.Sprite(smokeMat.clone()); s.visible = false; viewScene.add(s); parts.push({ s, t: 1, life: 1, vx: 0, vy: 0 }); }
  }
  function overheat(st) {
    st.hot = true; st.hotT = 0; Sound.hiss(); buzz(120);
    HUD.banner('기관총 과열', '연기가 납니다 · 다른 총으로 바꾼 뒤에 재장전할 수 있습니다', 2.6);
  }
  function shot(w, st) { st.heat = Math.min(1, (st.heat || 0) + 1 / w.mag); st.coolT = 0.3; if (st.mag === 0 && st.heat >= 0.97) overheat(st); }
  function update(dt) {
    const st = wstate.lmg; if (!st) return;
    st.heat = st.heat || 0;
    if (st.hot) {
      st.hotT = (st.hotT || 0) + dt;
      // swapping away is what lets it be reloaded again; with nothing to swap to, it gives in by itself after a while
      if ((Gun.cur !== 'lmg' && !Gun.pending) || (Gun.slots.length < 2 && st.hotT > 6)) st.hot = false;
    } else if ((st.coolT = (st.coolT || 0) - dt) <= 0) st.heat = Math.max(0, st.heat - dt * 0.2);
    const k = st.hot ? 0.9 + 0.1 * Math.sin(time * 18) : Math.pow(st.heat, 1.6);
    if (Math.abs(k - (st.glowK === undefined ? -1 : st.glowK)) > 0.004) { st.glowK = k; for (const m of GUN_MATS.lmg.hot) { m.color.setHex(m.userData.paintColor !== undefined ? m.userData.paintColor : m.userData.color).lerp(_hotRed, k * 0.85); m.emissive.setRGB(0.42 * k, 0.012 * k, 0.004 * k); } }
    // smoke off the barrel while it is overheated, and for a little while after
    st.smokeT = st.hot ? 2.5 : Math.max(0, (st.smokeT || 0) - dt);
    const g = gunModels.lmg;
    if (st.smokeT > 0 && g.visible && (spawnT -= dt) <= 0) {
      ensure(); spawnT = 0.06;
      const P = parts.find((q) => q.t >= q.life);
      if (P) { g.updateMatrixWorld(true); _p.set(rand(-0.012, 0.012), 0.03, rand(-0.58, -0.28)); g.localToWorld(_p); P.s.position.copy(_p); P.t = 0; P.life = rand(0.8, 1.2); P.vx = rand(-0.025, 0.025); P.vy = rand(0.05, 0.1); P.s.visible = true; }
    }
    for (const P of parts) {
      if (P.t >= P.life) continue;
      P.t += dt; const u = Math.min(1, P.t / P.life);
      P.s.position.x += P.vx * dt; P.s.position.y += P.vy * dt; P.s.scale.setScalar(0.03 + u * 0.085); P.s.material.opacity = 0.55 * (1 - u) * Math.min(1, u * 6);
      if (P.t >= P.life) P.s.visible = false;
    }
  }
  function reset() { const st = wstate.lmg; if (st) { st.heat = 0; st.hot = false; st.smokeT = 0; st.coolT = 0; st.glowK = undefined; } for (const P of parts) { P.t = P.life = 1; P.s.visible = false; } }
  return { shot, update, reset };
})();
function fireWeapon() {
  const w = curW(), st = wstate[Gun.cur];
  if (Gun.none || Gun.busy > 0 || Melee.on || player.stunT > 0 || Gun.switchT > 0 || Gun.reloadT > 0 || Gun.cooldown > 0) return;
  if (player.sprinting) player.sprintLock = 0.25;
  if (st.mag <= 0) { Sound.empty(); Gun.cooldown = 0.3; if (st.reserve > 0) startReload(); else HUD.hint('탄약 없음 · 상점에서 채우거나 다른 총으로', 2); return; }
  st.mag--; Gun.cooldown = w.rate; stats.shots++;
  if (w.heat) Heat.shot(w, st);
  Enemies.noise(camera.position, (Game.stage === 2 ? 30 : Game.stage === 3 || Game.stage === 8 ? 55 : Game.stage === 7 ? 45 : 42) * (w.noise || 1)); // a suppressor carries less far
  const spr = currentSpread();
  muzzleWorld(_muz);
  if (lookMode === 'touch' && !w.grenade && !w.rocket) {
    const ad = Enemies.assist(camera.position, _fwd, Gun.ads > 0.5 ? 0.03 : 0.045, w.range);
    if (ad) _fwd.copy(ad);
  }
  let hitAny = false, killed = false, head = false;
  if (w.grenade) {
    const a = rand(0, TAU), rr = Math.sqrt(Math.random()) * spr;
    _dir.copy(_fwd).addScaledVector(_right, Math.cos(a) * rr).addScaledVector(_up, Math.sin(a) * rr + 0.05).normalize();
    Proj.grenade(_muz, _dir, w);
  } else if (w.rocket) {
    // the rocket takes the enemy nearest the crosshair with it (the red diamond); with nothing marked it flies straight
    const tgt = rocketLock();
    _dir.copy(_fwd).addScaledVector(_up, 0.01).normalize();
    Proj.rocket(_muz, _dir, w, tgt);
  } else for (let k = 0; k < w.pellets; k++) {
    const a = rand(0, TAU), rr = Math.sqrt(Math.random()) * spr;
    _dir.copy(_fwd).addScaledVector(_right, Math.cos(a) * rr).addScaledVector(_up, Math.sin(a) * rr).normalize();
    const o = camera.position;
    const sHit = raycastStatic(o.x, o.y, o.z, _dir.x, _dir.y, _dir.z, w.range);
    const sT = RH.t, nx = RH.nx, ny = RH.ny, nz = RH.nz, sBox = RH.box;
    const eh = Enemies.raycast(o, _dir, sT);
    if (eh) {
      _hitP.copy(o).addScaledVector(_dir, eh.t);
      let dmg = w.dmg * (eh.weak ? (eh.enemy.T.headX || w.head) : eh.mult); // a giraffe's head takes ten times
      if (w.falloff) dmg *= lerp(1, 0.35, clamp((eh.t - w.falloff[0]) / (w.falloff[1] - w.falloff[0]), 0, 1));
      const weak = eh.weak;
      if (eh.bomb && eh.enemy.alive) { Enemies.blowVest(eh.enemy, _dir); killed = true; } // the chest bomb: one hit sets it off
      else if (Enemies.damage(eh.enemy, dmg, _hitP, _dir, weak)) killed = true;
      hitAny = true; if (weak) head = true;
      if (k < 3) FX.tracer(_muz, _hitP);
    } else {
      _hitP.copy(o).addScaledVector(_dir, sT);
      if (sHit) {
        if (sBox && sBox.kind === 'wood' && sBox.ref) damageCrate(sBox.ref, w.dmg, _hitP);
        if (k < 4) {
          FX.sparks(_hitP, sBox && sBox.kind === 'metal' ? 6 : 3, sBox && sBox.kind === 'wood' ? [0.9, 0.7, 0.45] : [1, 0.78, 0.45], 3.2);
          FX.puff(_hitP, 1, sBox && sBox.kind === 'concrete' ? 0.5 : 0.3, 0.25);
          if (sBox && sBox.kind === 'metal' && Math.random() < 0.5) Sound.metal(_hitP);
        }
        FX.decal(_hitP, { x: nx, y: ny, z: nz });
      }
      if (k < 3) FX.tracer(_muz, _hitP);
    }
  }
  if (hitAny) { stats.hits++; HUD.hitmark(killed, head); }
  const rk = w.recoil * (1 - Gun.ads * 0.35);
  player.recoilPitch += rk; player.pitch += rk * 0.55; player.yaw += rand(-1, 1) * rk * 0.35;
  Gun.kickZ += w.kick; Gun.kickRot += w.kick * 1.6; Gun.bloom = Math.min(Gun.bloom + w.bloom, 0.05);
  Gun.flashT = 0.045; FX.muzzle(_muz, w.flash); viewFlash.intensity = 1.4;
  // aiming down sights: no flash card or smoke on the line of sight, so the target stays visible
  const fl = gunModels[Gun.cur].userData.flash; fl.visible = Gun.ads < 0.5; fl.rotation.z = rand(0, TAU); fl.scale.setScalar(rand(0.8, 1.25) * (w.pellets > 1 ? 1.5 : 1));
  if (Gun.ads < 0.5) FX.glow.emit({ x: _muz.x, y: _muz.y, z: _muz.z, vx: _fwd.x * 2, vy: _fwd.y * 2 + 0.4, vz: _fwd.z * 2, max: 0.5, s0: 0.05, s1: 0.18, r: 0.35, g: 0.33, b: 0.32, a: 0.35, grav: -0.5, drag: 3 });
  Sound.shot(w.sound);
  if (w.pellets > 1 || w.scope) setTimeout(() => { if (state === 'playing') Sound.pump(); }, w.scope ? 520 : 280);
  if (st.mag === 0 && st.reserve > 0) setTimeout(() => { if (state === 'playing' && wstate[Gun.cur] === st && st.mag === 0) startReload(); }, 260);
  player.shake = Math.max(player.shake, w.pellets > 1 || w.scope ? 0.18 : 0.05);
}
function startReload() {
  const w = curW(), st = wstate[Gun.cur];
  if (w.heat && st.hot) { HUD.hint('기관총이 과열됐습니다 · 다른 총으로 바꾼 뒤에 재장전하세요', 2); return; }
  if (Gun.none || Gun.busy > 0 || Melee.on || player.stunT > 0 || Gun.reloadT > 0 || Gun.switchT > 0 || st.mag >= w.mag || st.reserve <= 0) return;
  Gun.reloadT = w.reload; Gun.reloadHalf = false; Sound.reload(0);
}
function finishReload() {
  const w = curW(), st = wstate[Gun.cur];
  const take = Math.min(w.mag - st.mag, st.reserve);
  st.mag += take; if (st.reserve !== Infinity) st.reserve -= take;
}
function switchTo(id) {
  if (!Gun.slots.includes(id) || id === Gun.cur || Gun.switchT > 0 || Gun.busy > 0 || player.stunT > 0) return;
  Gun.reloadT = 0; Gun.pending = id; Gun.switchT = 0.36; Sound.reload(0);
}
function switchWeapon(i) { const id = Gun.loadout[i]; if (id) switchTo(id); }
function cycleWeapon(step) {
  const n = Gun.slots.length; if (n < 2) return;
  const at = Gun.slots.indexOf(Gun.pending || Gun.cur);
  switchTo(Gun.slots[(at + step + n) % n]);
}
const scopeEl = $('scope');
function updateGun(dt, mdx, mdy) {
  const w = curW();
  Melee.autoCrate(); Melee.update(dt); Heat.update(dt); if (typeof LaserDot !== 'undefined') LaserDot.update();
  Gun.cooldown = Math.max(0, Gun.cooldown - dt);
  Gun.bloom = Math.max(0, Gun.bloom - dt * (Gun.trigger && w.auto ? 0.02 : 0.09));
  if (lookMode === 'touch' && settings.autoFire && !w.grenade && !w.rocket && !Gun.trigger && Gun.cooldown <= 0 && Gun.reloadT <= 0 && Gun.switchT <= 0 && wstate[Gun.cur].mag > 0 && !player.sprinting) {
    camera.getWorldDirection(_fwd);
    const o = camera.position, reach = w.falloff ? w.falloff[1] : Math.min(w.range, 70);
    // 5.18: a wooden crate under the crosshair too; 5.20: only within 12 m (farther off, the shots woke the area and used rented ammo)
    const wall = raycastStatic(o.x, o.y, o.z, _fwd.x, _fwd.y, _fwd.z, reach), crate = wall && RH.box && RH.box.kind === 'wood' && RH.box.ref && !RH.box.ref.dead && RH.t <= CRATE_AUTO_RANGE;
    // auto-fire leaves alone what never fights you: the lab's zebras and animals you have tamed (you can still shoot them yourself)
    Enemies.skipCalm = true; const sees = Enemies.raycast(o, _fwd, RH.t) || Enemies.assist(o, _fwd, 0.035, reach); Enemies.skipCalm = false;
    if (sees || crate) fireWeapon();
  }
  if (Gun.trigger && (w.auto || Gun.triggerEdge)) { fireWeapon(); Gun.triggerEdge = false; }
  if (Gun.reloadT > 0) {
    Gun.reloadT -= dt;
    if (!Gun.reloadHalf && Gun.reloadT < w.reload * 0.45) { Gun.reloadHalf = true; Sound.reload(1); }
    if (Gun.reloadT <= 0) { Gun.reloadT = 0; finishReload(); }
  }
  if (Gun.switchT > 0) {
    const before = Gun.switchT; Gun.switchT -= dt;
    if (before > 0.18 && Gun.switchT <= 0.18 && Gun.pending) {
      gunModels[Gun.cur].visible = false; Gun.cur = Gun.pending; Gun.pending = null; gunModels[Gun.cur].visible = true; Gun.cooldown = 0.1;
    }
    if (Gun.switchT < 0) Gun.switchT = 0;
  }
  const W = curW();
  const wantAds = Gun.adsHeld && Gun.reloadT <= 0 && Gun.switchT <= 0 && !player.sprinting && Gun.busy <= 0 && !Melee.on && !(player.stunT > 0);
  const as = W.adsSpeed || 7; // a light SMG comes up to the eye fast, the heavy machine gun slowly
  Gun.ads = clamp(Gun.ads + (wantAds ? dt * as : -dt * as), 0, 1);
  const a = Gun.ads * Gun.ads * (3 - 2 * Gun.ads);
  const fov = lerp(baseFov, W.adsFov * (W.scope ? 1 : baseFov / BASE_FOV), a);
  if (Math.abs(camera.fov - fov) > 0.01) { camera.fov = fov; camera.updateProjectionMatrix(); FX.resize(); }
  const scoped = W.scope && Gun.ads > 0.6;
  scopeEl.style.opacity = scoped ? String(clamp((Gun.ads - 0.6) * 4, 0, 1)) : '0';
  const g = gunModels[Gun.cur];
  g.visible = !scoped && !Gun.none;
  Gun.kickZ *= Math.exp(-dt * 14); Gun.kickRot *= Math.exp(-dt * 12);
  Gun.swayX = clamp(lerp(Gun.swayX, -mdx * 0.0006, 1 - Math.exp(-dt * 10)), -0.04, 0.04);
  Gun.swayY = clamp(lerp(Gun.swayY, mdy * 0.0006, 1 - Math.exp(-dt * 10)), -0.04, 0.04);
  const bobAmt = clamp(player.speedXZ / 6, 0, 1.4) * (player.grounded ? 1 : 0.2) * (1 - a * 0.85);
  const ph = player.stepPhase, sprint = player.sprintBlend;
  viewRoot.position.lerpVectors(HIP[Gun.cur], ADSP[Gun.cur], a);
  viewRoot.position.x *= lerp(hipScale, 1, a);
  viewRoot.position.x += Math.sin(ph) * 0.012 * bobAmt + Gun.swayX * (1 - a * 0.7) + sprint * 0.04;
  viewRoot.position.y += -Math.abs(Math.cos(ph)) * 0.012 * bobAmt + Gun.swayY * (1 - a * 0.7) - sprint * 0.05 + player.landDip * 0.4;
  viewRoot.position.z += Gun.kickZ * (1 - a * 0.5);
  viewRoot.rotation.set(Gun.kickRot * (1 - a * 0.5) - sprint * 0.35, sprint * 0.55 + Gun.swayX * 2, Math.sin(ph) * 0.01 * bobAmt);
  if (Gun.reloadT > 0) { const t = 1 - Gun.reloadT / W.reload, c = Math.sin(t * Math.PI); viewRoot.rotation.x -= c * 0.5; viewRoot.rotation.z += c * 0.6; viewRoot.position.y -= c * 0.06; }
  if (Gun.switchT > 0) { const t = Gun.switchT / 0.36, c = Math.sin(t * Math.PI); viewRoot.position.y -= c * 0.3; viewRoot.rotation.x -= c * 0.6; }
  Melee.pose(viewRoot);
  if (g.userData.tip) g.userData.tip.visible = wstate[Gun.cur].mag > 0; // the rocket's nose shows while one is loaded
  const low = Inject.lower; if (low > 0) { viewRoot.position.y -= low * 0.42; viewRoot.position.x += low * 0.08; viewRoot.rotation.x -= low * 0.8; } // gun out of the way for the needle
  if (Gun.flashT > 0) { Gun.flashT -= dt; if (Gun.flashT <= 0) g.userData.flash.visible = false; }
  viewFlash.intensity *= Math.exp(-dt * 30);
  // the world zooms when aiming, the gun in your hands does not, so it covers less of the target
  viewCam.fov = portrait ? 70 : 60; viewCam.updateProjectionMatrix();
}
/* which guns you may carry this stage: the pistol, guns you own for good (from boss chests), what you rented, or everything in developer mode */
function gunAvailable(id) { return id === 'pistol' || settings.dev || save.owned.includes(id) || save.rented.includes(id) || (typeof Game !== 'undefined' && Game.bonusGuns.includes(id)); }
/* keys 1-7 follow your layout; a slot whose gun you do not have this stage stays empty */
function applyLoadout() {
  Gun.loadout = save.loadout.map((id) => (id && gunAvailable(id) ? id : null));
  Gun.slots = Gun.loadout.filter(Boolean);
  Gun.none = Gun.slots.length === 0;
  if (!Gun.none && !Gun.slots.includes(Gun.cur)) {
    gunModels[Gun.cur].visible = false; Gun.cur = Gun.slots[0]; Gun.pending = null; Gun.switchT = 0; Gun.reloadT = 0;
    gunModels[Gun.cur].visible = state === 'playing' || state === 'paused';
  }
  HUD.buildSlots();
}
/* refill every gun and take the first one in your layout at the start of a stage */
function resetGuns() {
  ORDER.forEach((id) => { wstate[id].mag = WEAPONS[id].mag; wstate[id].reserve = WEAPONS[id].reserve; });
  Object.keys(gunModels).forEach((id) => { gunModels[id].visible = false; gunModels[id].userData.flash.visible = false; });
  Object.assign(Gun, { cooldown: 0, reloadT: 0, switchT: 0, pending: null, ads: 0, adsHeld: false, bloom: 0, kickZ: 0, kickRot: 0, flashT: 0, trigger: false, triggerEdge: false }); Melee.reset(); Heat.reset();
  Gun.loadout = save.loadout.map((id) => (id && gunAvailable(id) ? id : null));
  Gun.slots = Gun.loadout.filter(Boolean); Gun.none = Gun.slots.length === 0;
  Gun.cur = Gun.slots[0] || 'pistol';
  gunModels[Gun.cur].visible = !Gun.none; scopeEl.style.opacity = '0';
  HUD.buildSlots();
}
/* a gun rented (or found) in the middle of a stage joins with full ammo */
function gainGun(id) {
  wstate[id].mag = WEAPONS[id].mag; wstate[id].reserve = WEAPONS[id].reserve;
  const wasNone = Gun.none;
  applyLoadout();
  if (wasNone && !Gun.none) gunModels[Gun.cur].visible = true;
}
