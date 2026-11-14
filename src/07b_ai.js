
/* ============ enemy AI, bullets and grenades, antidote pickups ============ */
const Proj = (() => {
  const list = [];
  const geo = new THREE.SphereGeometry(1, 8, 6);
  const bulletMat = new THREE.MeshBasicMaterial({ color: 0xffd9a0, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  const boltMat = new THREE.MeshBasicMaterial({ color: 0x6fe4ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  const grenMat = new THREE.MeshStandardMaterial({ color: 0x3d4430, roughness: 0.6, metalness: 0.3 });
  const pool = [];
  function make(mat) { const p = pool.pop() || { m: new THREE.Mesh(geo, mat), vel: new THREE.Vector3(), src: new THREE.Vector3() }; p.m.material = mat; return p; }
  /* enemy pistol round: fast, visible tracer */
  function bullet(from, target, speed, dmg, spreadR, quiet, look) {
    const p = make(look === 'bolt' ? boltMat : bulletMat);
    p.kind = 'bullet'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.vel.set(target.x + rand(-1, 1) * spreadR - from.x, target.y + rand(-0.7, 0.7) * spreadR - from.y, target.z + rand(-1, 1) * spreadR - from.z).normalize().multiplyScalar(speed);
    p.dmg = dmg; p.life = 2; p.whiz = false;
    if (look === 'bolt') p.m.scale.set(0.06, 0.06, 0.9); else p.m.scale.set(0.03, 0.03, 0.55); p.m.lookAt(p.pos.x + p.vel.x, p.pos.y + p.vel.y, p.pos.z + p.vel.z);
    scene.add(p.m); list.push(p);
    if (!quiet) Sound.pistolFar(from);
    FX.glow.emit({ x: from.x, y: from.y, z: from.z, vx: 0, vy: 0, vz: 0, max: 0.08, s0: 0.45, s1: 0.1, r: 1, g: 0.8, b: 0.5, a: 0.9, grav: 0, drag: 0 });
  }
  /* enemy grenades: 'gl' rounds burst on impact, thrown 'nade's bounce and go off after a fuse; 'bomb' is a vest going off where a man fell */
  const eGrenMat = new THREE.MeshStandardMaterial({ color: 0x4a5236, roughness: 0.55, metalness: 0.35, emissive: 0x1a0a00 });
  function egrenade(from, target, mode) {
    const p = make(eGrenMat);
    p.kind = 'egren'; p.mode = mode; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    const dx = target.x - from.x, dz = target.z - from.z, d = Math.hypot(dx, dz), T = mode === 'gl' ? 0.55 + d / 30 : 0.8 + d / 20;
    p.vel.set(dx / T, (target.y - from.y + 0.5 * 9.8 * T * T) / T, dz / T);
    p.life = mode === 'gl' ? 6 : 2.7; p.fuse = 2.6; p.beeps = 0; p.m.scale.setScalar(mode === 'gl' ? 0.07 : 0.09); scene.add(p.m); list.push(p);
    Sound.thump(from);
  }
  function bomb(at, delay) {
    const p = make(eGrenMat); p.kind = 'bomb'; p.pos = p.m.position; p.pos.set(at.x, at.y + 1.0, at.z); p.src.copy(p.pos); p.life = delay; p.m.visible = false; p.vel.set(0, 0, 0);
    scene.add(p.m); list.push(p); Sound.beep(p.pos);
  }
  /* a blast from the enemy side: hurts you by distance, wrecks crates; the vest also takes other men with it */
  function blast(c, radius, dmg, hitsEnemies) {
    FX.explode(c, true); if (radius > 6) { FX.explode({ x: c.x + 0.8, y: c.y + 0.3, z: c.z - 0.5 }, true); FX.chunks(c, 10, 0.2, 'metal'); }
    Sound.boom(c, true); Enemies.noise(c, 50);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.9 - d * 0.04, 0, 0.9));
    if (d < radius && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 1.2, player.pos.z))) player.hurt(dmg * (1 - d / radius), c, 'body');
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    if (hitsEnemies) Enemies.splash(c, radius, dmg);
  }
  /* player's 40 mm grenade: arcs, arms after a few metres, explodes on impact */
  function grenade(from, dir, w) {
    const p = make(grenMat);
    p.kind = 'grenade'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.vel.copy(dir).multiplyScalar(40); p.dmg = w.dmg; p.radius = w.splash; p.life = 6; p.bounced = false;
    p.m.scale.setScalar(0.05); scene.add(p.m); list.push(p);
  }
  /* the player's guided rocket: a short straight boost, then it steers after the enemy it locked when fired (at most 3 rad a second),
     and bursts on whatever it touches: 1,000 to what it hit, and a 6 m blast (up to 500, less further out) round it */
  const rocketMat = new THREE.MeshStandardMaterial({ color: 0x59603f, roughness: 0.5, metalness: 0.4, emissive: 0x2a0d00 });
  function rocket(from, dir, w, target) {
    const p = make(rocketMat);
    p.kind = 'rocket'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.speed = 24; p.vel.copy(dir).multiplyScalar(p.speed); p.dmg = w.dmg; p.radius = w.splash; p.splashDmg = w.splashDmg || w.dmg * 0.5; p.life = 7; p.age = 0; p.target = target || null;
    p.m.scale.set(0.055, 0.055, 0.32); p.m.lookAt(p.pos.x + dir.x, p.pos.y + dir.y, p.pos.z + dir.z); scene.add(p.m); list.push(p);
  }
  const _rc = new THREE.Vector3(), _rd = new THREE.Vector3();
  function rocketHit(p, e) {
    const c = p.pos;
    FX.explode(c, true); FX.explode({ x: c.x + 0.5, y: c.y + 0.4, z: c.z - 0.4 }, true); Sound.boom(c, true); Enemies.noise(c, 70);
    player.shake = Math.max(player.shake, clamp(0.7 - c.distanceTo(player.pos) * 0.02, 0, 0.7));
    if (e && e.alive) { _rd.copy(p.vel).normalize(); if (Enemies.damage(e, p.dmg, c, _rd, false)) HUD.hitmark(true, false); else HUD.hitmark(false, false); }
    Enemies.splash(c, p.radius, p.splashDmg, e);
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < p.radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    // 5.13: the blast does not spare you either. the same splash an enemy would take: 35-100% of 500 inside 6 m, nothing through a wall
    const pd = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z), pr = p.radius + player.r;
    if (pd < pr && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 0.9, player.pos.z))) player.hurt(Math.round(p.splashDmg * (0.35 + 0.65 * (1 - pd / pr))), c, 'body');
  }
  function rocketCentre(e, out) { return out.set(e.pos.x, e.pos.y + (e.fly ? 0 : e.H * 0.55), e.pos.z); }
  function explode(p) {
    const c = p.pos;
    FX.explode(c, true); Sound.boom(c, true); Enemies.noise(c, 60);
    player.shake = Math.max(player.shake, clamp(0.5 - c.distanceTo(player.pos) * 0.02, 0, 0.5));
    Enemies.splash(c, p.radius, p.dmg);
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < p.radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    if (d < p.radius && Game.stage === 1) player.hurt(p.dmg * 0.35 * (1 - d / p.radius), c, 'body');
  }
  const _t = new THREE.Vector3();
  function update(dt) {
    const hx = player.pos.x, hz = player.pos.z, hy0 = player.pos.y + 0.1, hy1 = player.pos.y + player.height;
    for (let i = list.length - 1; i >= 0; i--) {
      const p = list[i]; p.life -= dt;
      let dead = false;
      if (p.kind === 'bomb') { if (p.life <= 0) { blast(p.pos, 7, 300, true); dead = true; } }
      else if (p.kind === 'egren') {
        p.vel.y -= 9.8 * dt;
        for (let s = 0; s < 3 && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / 3);
          const near = Math.hypot(p.pos.x - hx, p.pos.y - (hy0 + 0.8), p.pos.z - hz) < 0.7;
          const hit = p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.06 || !!collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.06, 0.1) || near;
          if (hit && p.mode === 'gl') { blast(p.pos, 5.5, 120, false); dead = true; }
          else if (hit) { // a thrown grenade bounces and rolls
            const g = groundAt(p.pos.x, p.pos.y + 0.3, p.pos.z, 0.05); p.pos.y = Math.max(p.pos.y, g + 0.06);
            if (Math.abs(p.vel.y) > 1.2) Sound.metal(p.pos);
            p.vel.x *= 0.45; p.vel.z *= 0.45; p.vel.y = Math.abs(p.vel.y) * 0.3;
          }
        }
        if (!dead && p.mode === 'nade') {
          // three beeps, each with a red flash, then it goes off
          p.fuse -= dt; if (Math.random() < dt * 6) FX.sparks(p.pos, 1, [1, 0.4, 0.2], 0.6);
          if (p.beeps < 3 && p.fuse <= 1.5 - p.beeps * 0.5) { p.beeps++; Sound.beep(p.pos); FX.glow.emit({ x: p.pos.x, y: p.pos.y + 0.05, z: p.pos.z, vx: 0, vy: 0, vz: 0, max: 0.18, s0: 0.5, s1: 0.2, r: 1, g: 0.12, b: 0.08, a: 1, grav: 0, drag: 0 }); }
          if (p.fuse <= 0) { blast(p.pos, 5.5, 100, false); dead = true; }
        }
        else if (!dead && Math.random() < 0.6) FX.puff(p.pos, 1, 0.5, 0.15);
        if (p.life <= 0 && !dead) { blast(p.pos, 5.5, p.mode === 'gl' ? 120 : 100, false); dead = true; }
      }
      else if (p.kind === 'rocket') {
        p.age += dt; p.speed = Math.min(58, p.speed + 70 * dt);
        _rd.copy(p.vel).normalize();
        const t = p.target;
        if (t && t.alive && p.age > 0.1) {
          rocketCentre(t, _rc).sub(p.pos).normalize();
          const ang = _rd.angleTo(_rc), maxA = 3.0 * dt;
          if (ang > 1e-4) _rd.lerp(_rc, Math.min(1, maxA / ang)).normalize();
        }
        p.vel.copy(_rd).multiplyScalar(p.speed);
        p.m.lookAt(p.pos.x + _rd.x, p.pos.y + _rd.y, p.pos.z + _rd.z);
        const steps = Math.max(2, Math.ceil(p.speed * dt / 0.35));
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          let hitE = null;
          for (const e of Enemies.list) {
            if (!e.alive || e.ridden) continue;
            if (e.fly) { if (Math.hypot(e.pos.x - p.pos.x, e.pos.y - p.pos.y, e.pos.z - p.pos.z) < e.R + 0.3) { hitE = e; break; } continue; }
            if (p.pos.y < e.pos.y - 0.1 || p.pos.y > e.pos.y + e.H + 0.2) continue;
            if (Math.hypot(e.pos.x - p.pos.x, e.pos.z - p.pos.z) < e.R * 0.95 + 0.25) { hitE = e; break; }
          }
          if (hitE || p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.05 || collideAt(p.pos.x, p.pos.y - 0.06, p.pos.z, 0.06, 0.12)) { rocketHit(p, hitE); dead = true; }
        }
        if (!dead) { FX.puff(p.pos, 1, 0.75, 0.32); FX.glow.emit({ x: p.pos.x - _rd.x * 0.3, y: p.pos.y - _rd.y * 0.3, z: p.pos.z - _rd.z * 0.3, vx: 0, vy: 0, vz: 0, max: 0.07, s0: 0.35, s1: 0.1, r: 1, g: 0.6, b: 0.25, a: 0.9, grav: 0, drag: 0 }); }
        if (!dead && p.life <= 0) { rocketHit(p, null); dead = true; }
      }
      else if (p.kind === 'grenade') {
        p.vel.y -= 9.8 * dt;
        const steps = 3;
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          const armed = p.pos.distanceTo(p.src) > 8;
          let impact = p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.05 || !!collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1);
          if (!impact) for (const e of Enemies.list) { _t.set(e.pos.x, e.pos.y + 1.1, e.pos.z); if (_t.distanceTo(p.pos) < 0.55) { impact = true; break; } }
          if (impact) {
            if (armed) { explode(p); dead = true; }
            else if (!p.bounced) { p.bounced = true; p.vel.multiplyScalar(-0.25); p.vel.y = Math.abs(p.vel.y) + 1; p.pos.y = Math.max(p.pos.y, 0.06); FX.puff(p.pos, 2, 0.4, 0.3); Sound.metal(p.pos); }
            else { FX.puff(p.pos, 3, 0.4, 0.35); dead = true; }
          }
        }
        if (Math.random() < 0.6) FX.puff(p.pos, 1, 0.55, 0.18);
      } else {
        // small steps so fast rounds cannot skip past you between checks
        const steps = Math.max(3, Math.ceil(p.vel.length() * dt / 0.3));
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          const py = clamp(p.pos.y, hy0, hy1), dd = Math.hypot(p.pos.x - hx, p.pos.y - py, p.pos.z - hz);
          // where it struck you: above the shoulders is the head
          if (dd < 0.4 && state === 'playing') { player.hurt(p.dmg, p.src, py - player.pos.y > 1.42 ? 'head' : 'body'); dead = true; break; }
          if (!p.whiz && dd < 1.5) { p.whiz = true; Sound.whiz(p.pos); }
          if (p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.02 || collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1)) { FX.sparks(p.pos, 3, [1, 0.8, 0.5], 2); dead = true; }
        }
      }
      if (dead || p.life <= 0) { scene.remove(p.m); list.splice(i, 1); pool.push(p); }
    }
  }
  function clear() { for (const p of list) { scene.remove(p.m); pool.push(p); } list.length = 0; }
  return { bullet, grenade, rocket, egrenade, bomb, blast, update, clear, list, rocketCentre, rocketHit };
})();

const Loot = (() => {
  const list = [];
  const vialGeo = new THREE.CylinderGeometry(0.07, 0.07, 0.34, 10);
  const capGeo = new THREE.CylinderGeometry(0.075, 0.075, 0.08, 10);
  const vialMat = new THREE.MeshStandardMaterial({ color: 0x5ed6b0, emissive: 0x1d6b52, roughness: 0.2, metalness: 0.1, transparent: true, opacity: 0.9 });
  const capMat = new THREE.MeshStandardMaterial({ color: 0xece6d8, roughness: 0.5 });
  const glowT = { anti: glowTex('rgba(94,214,176,0.9)', 'rgba(94,214,176,0.2)'), hp: glowTex('rgba(255,90,90,0.9)', 'rgba(255,70,70,0.22)'), ammo: glowTex('rgba(242,163,58,0.9)', 'rgba(242,163,58,0.22)') };
  const potionMat = new THREE.MeshStandardMaterial({ color: 0xd8262e, emissive: 0x5a0a0e, roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.92 });
  const corkMat = new THREE.MeshStandardMaterial({ color: 0x8a6a45, roughness: 0.9 });
  const ammoTex = canvasTex(64, 64, (g) => { g.fillStyle = '#4a5434'; g.fillRect(0, 0, 64, 64); g.fillStyle = '#d6a12e'; g.fillRect(0, 26, 64, 12);
    g.fillStyle = '#1b1d18'; g.font = '600 13px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.fillText('100', 32, 37); });
  const ammoMat = new THREE.MeshStandardMaterial({ map: ammoTex, roughness: 0.7, emissive: 0x1a1606 });
  const flaskGeo = new THREE.SphereGeometry(0.15, 14, 10), neckGeo = new THREE.CylinderGeometry(0.05, 0.06, 0.14, 10), corkGeo = new THREE.CylinderGeometry(0.055, 0.05, 0.06, 10);
  const boxGeo = new THREE.BoxGeometry(0.46, 0.26, 0.28);
  /* kind: 'anti' antidote, 'hp' health potion (+100), 'ammo' box of 100 rounds */
  function drop(kind, x, z, yHint) {
    const g = new THREE.Group();
    if (kind === 'anti') { g.add(new THREE.Mesh(vialGeo, vialMat)); const c = new THREE.Mesh(capGeo, capMat); c.position.y = 0.2; g.add(c); g.rotation.z = 0.35; }
    else if (kind === 'hp') { g.add(new THREE.Mesh(flaskGeo, potionMat)); const n = new THREE.Mesh(neckGeo, potionMat); n.position.y = 0.18; g.add(n); const c = new THREE.Mesh(corkGeo, corkMat); c.position.y = 0.27; g.add(c); }
    else { const b = new THREE.Mesh(boxGeo, ammoMat); b.castShadow = true; g.add(b); }
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowT[kind], blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.75 })); s.scale.setScalar(1.4); g.add(s);
    const y = groundAt(x, yHint !== undefined ? yHint + 0.6 : 20, z, 0.2) + 0.5;
    g.position.set(x, y, z); scene.add(g);
    list.push({ g, kind, t: rand(0, TAU), life: kind === 'anti' ? 60 : Infinity, baseY: y });
  }
  /* the boss's treasure chest: opens when you walk up to it */
  const chests = [];
  const woodM = new THREE.MeshStandardMaterial({ color: 0x6b4423, roughness: 0.8 });
  const goldM = new THREE.MeshStandardMaterial({ color: 0xd9a531, roughness: 0.35, metalness: 0.8, emissive: 0x3a2400 });
  const goldT = glowTex('rgba(255,214,120,0.95)', 'rgba(255,180,60,0.25)');
  function chest(x, z, yHint) {
    const g = new THREE.Group();
    const add = (geo, m, px, py, pz, parent) => { const o = new THREE.Mesh(geo, m); o.position.set(px, py, pz); o.castShadow = true; (parent || g).add(o); return o; };
    add(new THREE.BoxGeometry(1.1, 0.6, 0.75), woodM, 0, 0.3, 0);
    add(new THREE.BoxGeometry(1.14, 0.62, 0.08), goldM, 0, 0.3, 0.2); add(new THREE.BoxGeometry(1.14, 0.62, 0.08), goldM, 0, 0.3, -0.2);
    const lid = new THREE.Group(); lid.position.set(0, 0.6, -0.375); g.add(lid);
    add(new THREE.BoxGeometry(1.1, 0.28, 0.75), woodM, 0, 0.14, 0.375, lid); add(new THREE.BoxGeometry(1.14, 0.3, 0.08), goldM, 0, 0.14, 0.575, lid);
    add(new THREE.BoxGeometry(0.16, 0.2, 0.06), goldM, 0, 0.02, 0.77, lid);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: goldT, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.8 })); s.scale.setScalar(2.6); s.position.y = 0.6; g.add(s);
    const y = groundAt(x, yHint !== undefined ? yHint + 0.6 : 20, z, 0.6);
    g.position.set(x, y, z); g.rotation.y = rand(0, TAU); scene.add(g);
    chests.push({ g, lid, glow: s, open: false, t: 0, x, z, y });
    FX.sparks({ x, y: y + 0.6, z }, 30, [1, 0.85, 0.4], 4);
  }
  function update(dt) {
    for (let i = chests.length - 1; i >= 0; i--) {
      const c = chests[i]; c.t += dt;
      c.glow.material.opacity = 0.55 + Math.sin(c.t * 4) * 0.25;
      if (!c.open && Math.hypot(c.x - player.pos.x, c.z - player.pos.z) < 1.9 && Math.abs(player.pos.y - c.y) < 1.8) {
        c.open = true; c.t = 0; Game.openChest();
        for (let k = 0; k < 3; k++) FX.sparks({ x: c.x, y: c.y + 0.8, z: c.z }, 20, [1, 0.85, 0.4], 5);
      }
      if (c.open) { c.lid.rotation.x = -Math.min(1, c.t / 0.6) * 1.9; if (c.t > 8) { scene.remove(c.g); chests.splice(i, 1); } }
    }
    for (let i = list.length - 1; i >= 0; i--) {
      const L = list[i]; L.t += dt; L.life -= dt;
      L.g.position.y = L.baseY + Math.sin(L.t * 2.5) * 0.1; L.g.rotation.y += dt * 1.6;
      if (L.life < 6) L.g.visible = Math.sin(L.life * 18) > -0.3;
      const dx = L.g.position.x - player.pos.x, dz = L.g.position.z - player.pos.z;
      let taken = false;
      if (dx * dx + dz * dz < 1.8 && Math.abs(L.baseY - player.pos.y - 0.5) < 1.8) taken = Game.takeLoot(L.kind);
      if (taken || L.life <= 0) { scene.remove(L.g); list.splice(i, 1); }
    }
  }
  function clear() { for (const L of list) scene.remove(L.g); list.length = 0; for (const c of chests) scene.remove(c.g); chests.length = 0; }
  /* a boss chest nobody has opened yet (the way out waits for it) */
  function pending() { for (const c of chests) if (!c.open) return c; return null; }
  return { drop, chest, update, clear, pending };
})();

const _to = new THREE.Vector3(), _eye = new THREE.Vector3(), _aim = new THREE.Vector3(), _fd = { x: 0, z: 0 }, _mz = new THREE.Vector3();
function turnToward(e, yaw, rate, dt) {
  let d = yaw - e.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
  e.yaw += clamp(d, -rate * dt, rate * dt); e.g.rotation.y = e.yaw;
}
function muzzleOf(e, out) {
  const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw), m = e.muzzle, s = e.scale || 1;
  return out.set(e.pos.x + (m.x * cy + m.z * sy) * s, e.pos.y + m.y * s, e.pos.z + (-m.x * sy + m.z * cy) * s);
}
function groundMove(e, vx, vz, dt) {
  const r = e.R;
  const blocked = moveXZ(e.pos, vx * dt, vz * dt, r, e.H, 0.45);
  const gy = groundAt(e.pos.x, e.pos.y, e.pos.z, r);
  if (e.pos.y > gy) { e.vy -= 18 * dt; e.pos.y = Math.max(gy, e.pos.y + e.vy * dt); } else { e.pos.y = gy; e.vy = 0; }
  e.pos.x = clamp(e.pos.x, -HALF + r, HALF - r); e.pos.z = clamp(e.pos.z, -HALF + r, HALF - r);
  return blocked;
}
/* how each kit fights once it has you in sight. returns true while it is busy shooting (and moves slower) */
const _lz = new THREE.Vector3(), _ld = new THREE.Vector3();
const laserMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a, transparent: true, opacity: 0.75, blending: THREE.AdditiveBlending, depthWrite: false });
function fightKit(e, dt, dist) {
  const kit = e.kit || 'pistol', m = e.dmgMul;
  e.fireT -= dt;
  const aimAt = (lead, up) => _aim.set(player.pos.x + player.vel.x * dist / lead, player.pos.y + (up || 1.25), player.pos.z + player.vel.z * dist / lead);
  const spread = (base) => base + dist * 0.028 + player.speedXZ * 0.08 - (e.boss ? 0.15 : 0);
  if (kit === 'saber' || kit === 'saber2') {
    // runs you down and swings; one cut is 300. with a blade in each hand the cuts come twice as often, left and right in turn
    const dual = kit === 'saber2';
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const arm = e.swingL ? e.armL : e.armR, side = e.swingL ? 1 : -1;
      arm.rotation.set(-2.6 + (0.28 - e.swingT) * 9, 0, 0.4 * side);
      if (e.swingT <= 0 && dist < sd + 1.3 && Math.abs(player.pos.y - e.pos.y) < 1.8) { player.hurt(300 * m, e.pos, 'head'); Sound.saberHit(e.pos); } // an overhead chop
      return true;
    }
    if (dist < sd + 0.9 && e.swingCd <= 0) { e.swingT = 0.28; e.swingCd = dual ? 0.62 : 1.25; e.swingL = dual && !e.swingL; Sound.saberSwing(e.pos); }
    if (e.fireT <= 0) { e.fireT = rand(1.2, 2); if (dist < 25) Sound.saberHum(e.pos); }
    return false;
  }
  if (kit === 'dagger') {
    // a knife: arm back, then a quick thrust; 70 a stab, nearly two a second once he is on you
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const u = 1 - e.swingT / 0.32;
      e.armR.rotation.set(u < 0.45 ? -0.7 + u * 1.2 : -0.16 - (u - 0.45) / 0.55 * 1.5, 0, -0.12);
      if (!e.stabbed && u >= 0.6) {
        e.stabbed = true; Sound.swoosh(e.pos);
        if (dist < sd + 1.0 && Math.abs(player.pos.y - e.pos.y) < 1.7) { player.hurt(70 * m, e.pos, 'body'); Sound.squelch(e.pos); }
      }
      return true;
    }
    if (dist < sd + 0.8 && e.swingCd <= 0) { e.swingT = 0.32; e.swingCd = 0.55; e.stabbed = false; }
    return false;
  }
  if (kit === 'bat') {
    // the bat goes up over the shoulder, then comes round flat: 150 and a shove
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const u = 1 - e.swingT / 0.55;
      if (u < 0.55) { const w = u / 0.55; e.armR.rotation.set(-1.2 - w * 1.5, 0, -0.2 - w * 0.6); }
      else { const w = (u - 0.55) / 0.45; e.armR.rotation.set(-2.7 + w * 1.4, 0, -0.8 + w * 1.6); }
      if (!e.batHit && u >= 0.75) {
        e.batHit = true; Sound.swoosh(e.pos);
        if (dist < sd + 1.25 && Math.abs(player.pos.y - e.pos.y) < 1.8) {
          player.hurt(150 * m, e.pos, 'head'); Sound.batHit(e.pos); // swung at head height
          const tx = (player.pos.x - e.pos.x) / (dist || 1), tz = (player.pos.z - e.pos.z) / (dist || 1); player.vel.x += tx * 6; player.vel.z += tz * 6;
        }
      }
      return true;
    }
    if (dist < sd + 0.9 && e.swingCd <= 0) { e.swingT = 0.55; e.swingCd = 1.4; e.batHit = false; }
    return false;
  }
  if (kit === 'bomber') {
    // close enough: arms up, the vest beeps fast, and after a moment it all goes
    const sd = stopDist(e);
    if (e.fuse > 0) {
      e.fuse -= dt; e.armL.rotation.set(-2.9, 0, 0.35); e.armR.rotation.set(-2.9, 0, -0.35);
      if (!e.beep2 && e.fuse < 0.3) { e.beep2 = true; Sound.beep(e.pos); }
      if (e.fuse <= 0) Enemies.detonate(e);
      return true;
    }
    if (dist < sd + 1.4 && Math.abs(player.pos.y - e.pos.y) < 2) { e.fuse = 0.6; e.beep2 = false; Sound.beep(e.pos); Sound.scream(e.pos); }
    return false;
  }
  if (kit === 'flame') {
    if (e.flameOn > 0) {
      e.flameOn -= dt; muzzleOf(e, _mz);
      const fx = Math.sin(e.yaw), fz = Math.cos(e.yaw);
      for (let k = 0; k < 3; k++) FX.glow.emit({ x: _mz.x, y: _mz.y, z: _mz.z, vx: fx * rand(8, 11) + rand(-1, 1), vy: rand(-0.3, 0.8), vz: fz * rand(8, 11) + rand(-1, 1), max: rand(0.45, 0.7), s0: 0.15, s1: rand(0.9, 1.4), r: 1, g: rand(0.35, 0.6), b: 0.1, a: 0.8, grav: -2, drag: 2.2 });
      // you are in the cone: inside 9.5 m and within ~20 degrees of where the nozzle points
      const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, cos = (dx * fx + dz * fz) / (dist || 1);
      if (dist < 9.5 && cos > 0.94 && Math.abs(player.pos.y - e.pos.y) < 2.2) { e.flameAcc = (e.flameAcc || 0) + 75 * m * dt; if (e.flameAcc >= 15) { e.flameAcc -= 15; player.hurt(15, e.pos, 'fire'); } }
      if ((e.flameSnd = (e.flameSnd || 0) - dt) <= 0) { e.flameSnd = 0.18; Sound.flame(_mz); }
      return true;
    }
    if (dist < 9 && e.fireT <= 0) { e.flameOn = rand(1.6, 2.4); e.fireT = e.flameOn + rand(0.9, 1.5); }
    return false;
  }
  if (kit === 'sniper') {
    // a red laser shows where he is aiming for a moment before the shot
    if (!e.laser) { e.laser = new THREE.Mesh(new THREE.BoxGeometry(0.018, 0.018, 1), laserMat); e.laser.frustumCulled = false; scene.add(e.laser); }
    if (e.aimT > 0) {
      e.aimT -= dt; muzzleOf(e, _mz); aimAt(400, 1.58); // snipers go for the head
      _ld.copy(_aim).sub(_mz); const L = _ld.length(); e.laser.position.copy(_mz).addScaledVector(_ld, 0.5); e.laser.scale.set(1, 1, L); e.laser.lookAt(_aim); e.laser.visible = true;
      if (e.aimT <= 0) { e.laser.visible = false; Proj.bullet(_mz, _aim, 160, 140 * m, 0.05 + player.speedXZ * 0.12); Sound.farShot(_mz, 'sniper'); e.fireT = rand(2.4, 3.4); }
      return true;
    }
    if (e.fireT <= 0) e.aimT = 1.3;
    return false;
  }
  if (kit === 'gl' || kit === 'nade') {
    if (e.fireT <= 0) {
      muzzleOf(e, _mz); aimAt(kit === 'gl' ? 60 : 45, 0.3);
      if (kit === 'nade') { e.armR.rotation.set(-2.8, 0, 0); _mz.y += 0.4; }
      Proj.egrenade(_mz, _aim, kit === 'gl' ? 'gl' : 'nade'); e.fireT = kit === 'gl' ? rand(2.6, 3.6) : rand(2.4, 3.6);
    }
    return false;
  }
  // guns that fire bullets: shots per burst, gap between shots, damage, pause between bursts
  const G = { pistol: [1, 3, 0.32, 9, 1.1, 2.3], deagle: [1, 1, 0.3, 45, 1.3, 2.2], smg: [6, 9, 0.08, 7, 1.3, 2.1], rifle: [3, 5, 0.11, 11, 1.2, 2.0],
    lmg: [12, 18, 0.075, 10, 1.0, 1.6], shotgun: [1, 1, 0.3, 11, 1.2, 1.8] }[kit] || [1, 3, 0.32, 9, 1.1, 2.3];
  if (kit === 'shotgun' && dist > 18) return false;
  if (e.burst > 0) {
    e.burstT -= dt;
    if (e.burstT <= 0) {
      e.burst--; e.burstT = G[2] * (e.boss && kit === 'pistol' ? 0.62 : 1);
      muzzleOf(e, _mz);
      if (kit === 'shotgun') { aimAt(120); for (let k = 0; k < 7; k++) Proj.bullet(_mz, _aim, 70, G[3] * m, 0.9 + dist * 0.05, true); Sound.farShot(_mz, 'shotgun'); }
      else { aimAt(150); Proj.bullet(_mz, _aim, kit === 'deagle' ? 95 : 80, G[3] * m, spread(kit === 'deagle' ? 0.2 : kit === 'smg' ? 0.55 : 0.35), true); Sound.farShot(_mz, kit); }
    }
    return true;
  }
  if (e.fireT <= 0) { e.burst = e.boss && kit === 'pistol' ? 4 : randi(G[0], G[1]); e.burstT = 0; e.fireT = rand(G[4], G[5]) * (e.boss ? 0.7 : 1); }
  return false;
}
function animateWalk(e, sp, dt, aim) {
  e.walk += dt * sp * (e.type === 'zombie' ? 3.2 : 2.6);
  const s = Math.sin(e.walk) * Math.min(1, sp / 2) * (e.type === 'zombie' ? 0.45 : 0.6);
  e.legL.rotation.x = s; e.legR.rotation.x = -s;
  if (e.type === 'zombie') {
    const sway = Math.sin(e.walk * 0.5) * 0.12;
    e.armL.rotation.set(-1.35 + sway, 0, 0.08); e.armR.rotation.set(-1.4 - sway, 0, -0.08);
    e.upper.rotation.z = Math.sin(e.walk * 0.5) * 0.06;
  } else if (e.kit === 'saber') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -1.15 : -0.5 - s * 0.3, 0, -0.25); // blade held up and forward
    e.armL.rotation.set(aim ? -0.6 : s * 0.8, 0, 0.2);
  } else if (e.kit === 'saber2') {
    // both blades up and out; the one not swinging stays on guard
    if (!(e.swingT > 0 && !e.swingL)) e.armR.rotation.set(aim ? -1.15 : -0.5 - s * 0.3, 0, -0.3);
    if (!(e.swingT > 0 && e.swingL)) e.armL.rotation.set(aim ? -1.15 : -0.5 + s * 0.3, 0, 0.3);
  } else if (e.kit === 'dagger') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -0.9 : -0.55 - s * 0.3, 0, -0.12); // knife held low and forward
    e.armL.rotation.set(s * 0.9, 0, 0.12);
  } else if (e.kit === 'bat') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -2.3 : -2.0 - s * 0.15, 0, -0.35); // bat up on the shoulder
    e.armL.rotation.set(s * 0.8, 0, 0.1);
  } else if (e.kit === 'bomber') {
    if (!(e.fuse > 0)) { e.armR.rotation.set(-s * 1.1, 0, -0.15); e.armL.rotation.set(s * 1.1, 0, 0.15); } // arms pumping as he runs
  } else if (aim) {
    e.armR.rotation.set(-Math.PI / 2 + 0.05, 0, 0); e.armL.rotation.set(-1.25, 0, 0.5);
  } else { e.armR.rotation.set(-s * 0.8, 0, 0); e.armL.rotation.set(s * 0.8, 0, 0); }
  e.flinch = Math.max(0, e.flinch - dt * 5);
  e.upper.rotation.x = (e.type === 'zombie' ? 0.28 : 0) - e.flinch * 0.25;
}
const ACT_R = { 1: 55, 6: 55, 5: 55, 2: 45, 3: 95, 8: 95, 4: 55, 7: 95 }, VIS_R = { 1: 85, 6: 85, 5: 85, 2: 72, 3: 165, 8: 165, 4: 90, 7: 150 };
function updateEnemies(dt, time) {
  const L = Enemies.list, act = ACT_R[Game.stage] || 60, vis = (VIS_R[Game.stage] || 90) * (isTouch ? 0.75 : 1);
  for (const e of L) {
    if (!e.alive) continue;
    // with all 100 placed at once, only the ones near you think; far ones sleep and are not drawn
    e.lod -= dt;
    if (e.lod <= 0) {
      e.lod = 0.3 + Math.random() * 0.2; e.dist = Math.hypot(player.pos.x - e.pos.x, player.pos.z - e.pos.z);
      e.g.visible = e.dist < vis * (e.boss ? 1.6 : 1); e.awake = e.alert || e.angry || e.dist < act;
      if (!e.g.visible) e.bar.visible = false;
      const far = e.dist > (World.style.lab ? (isTouch ? 18 : 46) : e.animal ? 45 : 28) * (e.boss ? 1.5 : 1); if (!e.noFar && e.isFar !== far) setFar(e, far);
      if (!isTouch) { const sh = e.dist < Gfx.esh; if (e.castsShadow !== sh) { e.castsShadow = sh; e.g.traverse((o) => { if (o.isMesh) o.castShadow = sh; }); } }
    }
    if (e.downed) { Enemies.updateDowned(e, dt); continue; }
    if (e.ridden) { // you are on it: Ride steers it; just the hit flash here
      if (e.flashT > 0) { e.flashT -= dt; e.mats[0].emissive.setRGB(0.6, 0.35, 0.2); } else e.mats[0].emissive.setRGB(0, 0, 0);
      e.bar.visible = false; continue;
    }
    if (!e.awake) continue;
    _eye.set(e.pos.x, e.pos.y + (e.eyeH !== undefined ? e.eyeH : 1.65) * (e.scale || 1), e.pos.z);
    _to.set(player.pos.x - e.pos.x, 0, player.pos.z - e.pos.z);
    const dist = Math.hypot(_to.x, _to.z) || 0.001;
    e.losT -= dt;
    if (e.losT <= 0) { e.losT = 0.2 + Math.random() * 0.1; e.los = dist < 70 && lineOfSight(_eye, camera.position); }
    e.noLos = e.los ? 0 : e.noLos + dt;
    const faceYaw = Math.atan2(_to.x, _to.z);
    let mvx = 0, mvz = 0;
    if (!e.animal && !e.robot && !e.alert) {
      // on guard (people) or milling about (zombies) until they see or hear you
      const sees = e.los && dist < (e.type === 'thug' ? 30 : 16);
      if (sees || dist < (e.type === 'thug' ? 7 : 5) || (e.boss && dist < 24)) {
        Enemies.alarm(e);
        if (e.type === 'thug') for (const o of L) if (o.type === 'thug' && !o.alert && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 15) Enemies.alarm(o);
      } else {
        e.idleT = (e.idleT || rand(2, 6)) - dt;
        if (e.idleT <= 0) { e.idleT = rand(3, 7); e.idleYaw = e.yaw + rand(-1.3, 1.3); }
        let sp = 0;
        if (e.type === 'zombie' && e.idleT > 3) { sp = 0.5; groundMove(e, Math.sin(e.yaw) * sp, Math.cos(e.yaw) * sp, dt); }
        turnToward(e, e.idleYaw === undefined ? e.yaw : e.idleYaw, 1.2, dt);
        animateWalk(e, sp, dt, false);
        continue;
      }
    }
    if (e.animal) updateAnimal(e, dt, time, dist, faceYaw);
    else if (e.robot) updateRobot(e, dt, dist, faceYaw);
    else if (e.type === 'thug') {
      if (e.state === 'move') {
        if (flowDir(e.pos.x, e.pos.z, _fd)) { mvx = _fd.x * e.speed; mvz = _fd.z * e.speed; } else { mvx = _to.x / dist * e.speed; mvz = _to.z / dist * e.speed; }
        turnToward(e, e.los && dist < 34 ? faceYaw : Math.atan2(mvx, mvz), 6, dt);
        const K = e.K || KITS.pistol;
        if (e.los && dist < K.range * (e.boss ? 1.2 : 1)) { e.state = 'engage'; e.react = (K.melee ? 0.15 : rand(0.45, 0.9)) * (1 - e.diff * 0.35); }
      } else {
        const K = e.K || KITS.pistol;
        e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(0.9, 2.4); }
        const fx = _to.x / dist, fz = _to.z / dist;
        if (K.melee) { const sd = stopDist(e), sp = (K.run || 4.3) * (dist > sd + 0.2 ? 1 : 0); mvx = fx * sp; mvz = fz * sp; }
        else if (K.still) { mvx = 0; mvz = 0; }
        else {
          const fwd = dist > K.far ? 1 : dist < K.near ? -0.8 : 0;
          mvx = (fx * fwd - fz * e.strafe * 0.6) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * 0.6) * e.speed * 0.55;
        }
        turnToward(e, faceYaw, K.melee ? 9 : 7, dt);
        e.react -= dt;
        if (e.noLos > 1.6 || dist > K.range + 6) { e.state = 'move'; if (e.laser) e.laser.visible = false; e.flameOn = 0; }
        if (e.react <= 0 && (e.los || K.melee)) { const slow = fightKit(e, dt, dist); if (slow) { mvx *= 0.4; mvz *= 0.4; } }
      }
      if (e.vestLight) e.vestLight.visible = (time * (e.fuse > 0 ? 14 : 3) + e.walk) % 1 < 0.45;
      e.vel.multiplyScalar(Math.exp(-dt * 6));
      const blocked = groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
      if (blocked && e.state === 'engage') e.strafe *= -1;
      animateWalk(e, Math.hypot(mvx, mvz), dt, e.state === 'engage');
    } else if (zombieSkill(e, dt, dist)) {
      // a dash, a wind-up or a charge moved it this frame
    } else {
      // zombie: shamble straight for the player once close, otherwise follow the flow field
      if (dist < 9 && e.los) { mvx = _to.x / dist; mvz = _to.z / dist; }
      else if (flowDir(e.pos.x, e.pos.z, _fd)) { mvx = _fd.x; mvz = _fd.z; } else { mvx = _to.x / dist; mvz = _to.z / dist; }
      let sp = e.speed;
      e.attackCd -= dt;
      const sd = stopDist(e);
      if (e.state === 'lunge') { e.stateT -= dt; sp *= 0.2; if (e.stateT <= 0) { e.state = 'move'; if (dist < Math.max(1.75, sd + 0.6) && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) Game.bitten(e); } }
      else if (dist < Math.max(1.35, sd + 0.25) && e.attackCd <= 0 && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) { e.state = 'lunge'; e.stateT = 0.35; e.attackCd = 1.4; }
      if (dist < sd + 0.05 && e.state !== 'lunge') sp = 0; // pressed against you: stop pushing, just claw
      mvx *= sp; mvz *= sp;
      turnToward(e, dist < 9 ? faceYaw : Math.atan2(mvx, mvz), 3.5, dt);
      e.vel.multiplyScalar(Math.exp(-dt * 5));
      groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
      animateWalk(e, sp, dt, false);
      if (e.state === 'lunge') { e.armL.rotation.x = -1.75; e.armR.rotation.x = -1.8; e.upper.rotation.x = 0.45; }
      e.moanT -= dt; if (e.moanT <= 0) { e.moanT = rand(3, 8); if (dist < 28) Sound.moan(e.pos); }
    }
    if (e.flashT > 0) { e.flashT -= dt; e.mats[0].emissive.setRGB(0.6, 0.35, 0.2); } else if (e.rage) e.mats[0].emissive.setRGB(0.3 + Math.sin(time * 9) * 0.14, 0.02, 0.01); else e.mats[0].emissive.setRGB(0, 0, 0);
    if (e.hp < e.maxHp) {
      e.bar.visible = e.g.visible; e.bar.position.set(e.pos.x, e.pos.y + (e.barY !== undefined ? e.barY * (e.scale || 1) : e.H + 0.4 * (e.scale || 1)), e.pos.z); e.bar.quaternion.copy(camera.quaternion);
      const f = clamp(e.hp / e.maxHp, 0, 1); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1 - f);
    }
  }
  for (let i = 0; i < L.length; i++) for (let j = i + 1; j < L.length; j++) {
    const a = L[i], b = L[j]; if ((!a.awake && !b.awake) || a.downed || b.downed || a.fly || b.fly) continue;
    const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z; if (Math.abs(dx) > 5 || Math.abs(dz) > 5) continue;
    const d = Math.hypot(dx, dz), m = a.R + b.R + 0.1;
    if (d < m && d > 0.001) { const push = (m - d) * 0.5; moveXZ(a.pos, -dx / d * push, -dz / d * push, a.R, a.H, 0); moveXZ(b.pos, dx / d * push, dz / d * push, b.R, b.H, 0); }
  }
  /* nobody walks into you: your body, and the camera with it, stays outside every enemy's footprint */
  if (!Ride.m) for (const e of L) if (e.alive && e.awake && e.foot && !e.downed) keepOut(e); // riding, the animal under you does the shoving
  Enemies.updateDying(dt);
}
/* zombie skills. ordinary zombies dash once when down to 30% health, and that dash poisons;
   the boss enrages at half health (red, much faster) and every few seconds rears up and charges, which stuns you */
function zombieSkill(e, dt, dist) {
  if (e.boss && !e.rage && e.hp <= e.maxHp * 0.5) {
    e.rage = true; e.speed *= 1.9; e.chargeCd = 1.6; e.mats[0].color.setRGB(1, 0.4, 0.36);
    Sound.rage(e.pos); player.shake = Math.max(player.shake, 0.25);
    HUD.banner(e.name + ' 폭주', '빨라지고 가끔 돌진합니다 · 맞으면 2초 기절', 2.4);
  }
  if (!e.boss && !e.dashUsed && e.hp > 0 && e.hp <= e.maxHp * 0.3 && e.state !== 'lunge') {
    e.dashUsed = true; e.state = 'dash'; e.stateT = 1.1; e.hitDone = false;
    e.cx = _to.x / dist; e.cz = _to.z / dist; e.yaw = Math.atan2(e.cx, e.cz); e.g.rotation.y = e.yaw;
    Sound.scream(e.pos);
  }
  if (e.boss && e.rage && e.state === 'move') {
    e.chargeCd -= dt;
    if (e.chargeCd <= 0 && dist > 3.5 && dist < 26 && e.los) { e.state = 'windup'; e.stateT = 0.65; Sound.rage(e.pos); }
  }
  if (e.state === 'windup') {
    e.stateT -= dt; turnToward(e, Math.atan2(_to.x, _to.z), 7, dt);
    e.upper.rotation.x = -0.32; e.armL.rotation.x = -2.6; e.armR.rotation.x = -2.6; e.legL.rotation.x = 0.35; e.legR.rotation.x = -0.35;
    if (e.stateT <= 0) { e.state = 'charge'; e.stateT = 1.4; e.hitDone = false; e.cx = Math.sin(e.yaw); e.cz = Math.cos(e.yaw); }
    return true;
  }
  if (e.state === 'dash' || e.state === 'charge') {
    const charge = e.state === 'charge', sp = charge ? 13 : 8.5;
    e.stateT -= dt;
    const blocked = groundMove(e, e.cx * sp, e.cz * sp, dt);
    animateWalk(e, sp, dt, false);
    e.armL.rotation.x = -1.6; e.armR.rotation.x = -1.65; e.upper.rotation.x = 0.5;
    if (!e.hitDone && dist < stopDist(e) + 0.55 && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) {
      e.hitDone = true; if (charge) Game.stun(e); else Game.poison(e);
    }
    if (charge && Math.random() < dt * 18) FX.puff({ x: e.pos.x, y: 0.25, z: e.pos.z }, 1, 0.55, 0.35);
    if (e.stateT <= 0 || blocked || e.hitDone) { e.state = 'move'; e.chargeCd = rand(5, 8); }
    return true;
  }
  return false;
}
const KEEP_PAD = 0.14;
/* distance from an enemy's centre at which it stops in front of you */
function stopDist(e) { return e.foot ? e.foot.z1 + player.r + KEEP_PAD : 1; }
function keepOut(e) {
  if (e.ghostT > 0) return; // a buffalo that has just run you down goes on past you
  const p = player.pos;
  if (p.y > e.pos.y + e.H * 0.92 || e.pos.y > p.y + player.height) return; // one is standing above the other
  const dx = p.x - e.pos.x, dz = p.z - e.pos.z, rr = e.footR + player.r + KEEP_PAD;
  if (dx * dx + dz * dz > rr * rr) return;
  const yaw = e.g.rotation.y, c = Math.cos(yaw), s = Math.sin(yaw), r = player.r + KEEP_PAD, F = e.foot;
  const lx = dx * c - dz * s, lz = dx * s + dz * c; // you, in the enemy's frame
  const pl = lx - (F.x0 - r), pr = F.x1 + r - lx, pb = lz - (F.z0 - r), pf = F.z1 + r - lz;
  if (pl <= 0 || pr <= 0 || pb <= 0 || pf <= 0) return;
  const m = Math.min(pl, pr, pb, pf);
  let ox = 0, oz = 0;
  if (m === pf) oz = pf; else if (m === pb) oz = -pb; else if (m === pl) ox = -pl; else ox = pr;
  const wx = ox * c + oz * s, wz = -ox * s + oz * c; // the way out for you, in world space
  let movedX = 0, movedZ = 0;
  if (!Car.riding) {
    const k = e.mass / (e.mass + 1), bx = p.x, bz = p.z;
    moveXZ(p, wx * k, wz * k, player.r, player.height, 0);
    movedX = p.x - bx; movedZ = p.z - bz;
  }
  // whatever you could not give (a wall behind you, or the car), the enemy gives
  moveXZ(e.pos, movedX - wx, movedZ - wz, e.R, e.H, 0);
}
