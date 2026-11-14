
/* ============ enemies: people with pistols (stage 1) and zombies (stage 2); animals live in 07c ============ */
const ETYPES = {
  thug: { hp: 100, speed: 3.6, r: 0.35, h: 1.8, name: '조직원' },
  zombie: { hp: 180, speed: 1.6, r: 0.35, h: 1.8, name: '좀비' },
};
/* far away an enemy is drawn as one baked mesh in its rest pose instead of five moving parts */
function bakeFar(e) {
  e.g.updateMatrixWorld(true);
  const geos = [];
  e.g.traverse((o) => { if (o.isMesh && o.geometry.attributes.color) { const c = o.geometry.clone(); c.applyMatrix4(o.matrixWorld); geos.push(c); } });
  e.far = new THREE.Mesh(AnimalKit.merge(geos), e.mats[0]); e.far.visible = false; e.g.add(e.far); e.isFar = false;
}
function setFar(e, far) {
  e.isFar = far;
  for (const c of e.g.children) c.visible = c === e.far ? far : !far;
}
/* what an armed man carries: the gun in his right hand (boxes laid along the arm, so it points forward when he aims) and how he fights.
   range: starts a fight inside it; near/far: the distance he tries to keep; end: how far the muzzle sits from the shoulder */
const KITS = {
  pistol: { name: '권총', gun: [[0.045, 0.1, 0.18, 0, -0.66, 0.06, '#1d2024']], range: 32, near: 8, far: 20, end: 0.62 },
  // a gold-plated desert eagle (drawn with a gleaming gold material, not just a yellow tint)
  deagle: { name: '데저트 이글', gun: [[0.06, 0.3, 0.12, 0, -0.78, 0.02, '#d9a531'], [0.05, 0.08, 0.07, 0, -0.64, -0.04, '#b8861e']], range: 34, near: 7, far: 18, end: 0.95, gold: true },
  // a combat knife: grip, guard and a short steel blade; he runs you down and stabs, fast
  dagger: { name: '단검', gun: [[0.04, 0.13, 0.045, 0, -0.66, 0.03, '#2a1e16'], [0.035, 0.035, 0.11, 0, -0.73, 0.03, '#8a8f98'], [0.018, 0.27, 0.05, 0, -0.88, 0.03, '#d6dbe3']], range: 60, near: 0, far: 0, end: 0.8, melee: true, knife: true, run: 5.2 },
  // nothing in his hands, only the bomb on his chest: he runs at you, lights the fuse when close, and the vest also goes off if he is shot
  bomber: { name: '자폭맨', gun: [], range: 80, near: 0, far: 0, end: 0.6, melee: true, vest: true, bomber: true, run: 6.2 },
  // a lightsaber in each hand, swinging one after the other
  saber2: { name: '쌍광선검', gun: [[0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc']], range: 60, near: 0, far: 0, end: 0.8, melee: true, blade: true, dual: true, run: 4.6 },
  // an aluminium baseball bat: grip, taper, barrel
  bat: { name: '야구방망이', gun: [[0.036, 0.26, 0.036, 0, -0.75, 0.03, '#26262a'], [0.05, 0.3, 0.05, 0, -1.03, 0.03, '#b9bec6'], [0.066, 0.34, 0.066, 0, -1.34, 0.03, '#d3d7dd'], [0.07, 0.03, 0.07, 0, -1.52, 0.03, '#9ea3ab']], range: 50, near: 0, far: 0, end: 0.8, melee: true, bat: true, run: 4.5 },
  smg: { name: '기관단총', gun: [[0.06, 0.46, 0.12, 0, -0.84, 0.03, '#24272c'], [0.04, 0.06, 0.16, 0, -0.8, -0.08, '#1b1d20']], range: 30, near: 6, far: 14, end: 1.07 },
  rifle: { name: '돌격소총', gun: [[0.06, 0.8, 0.12, 0, -0.98, 0.03, '#2b2f26'], [0.05, 0.06, 0.18, 0, -0.86, -0.09, '#1b1d20']], range: 40, near: 8, far: 22, end: 1.38 },
  sniper: { name: '저격총', gun: [[0.05, 1.12, 0.09, 0, -1.12, 0.03, '#2a2e24'], [0.06, 0.26, 0.06, 0, -0.86, -0.07, '#111111']], range: 95, near: 0, far: 0, end: 1.68, still: true },
  shotgun: { name: '샷건', gun: [[0.07, 0.84, 0.11, 0, -1.0, 0.03, '#4a3424'], [0.06, 0.2, 0.07, 0, -1.05, 0.09, '#2a2a2a']], range: 18, near: 4, far: 9, end: 1.42 },
  gl: { name: '유탄발사기', gun: [[0.12, 0.58, 0.13, 0, -0.9, 0.03, '#3d4430'], [0.13, 0.2, 0.13, 0, -1.25, 0.03, '#2a2e24']], range: 45, near: 10, far: 28, end: 1.35 },
  nade: { name: '수류탄', gun: [[0.08, 0.1, 0.08, 0, -0.68, 0.03, '#3d4430']], range: 26, near: 9, far: 20, end: 0.62, belt: true },
  flame: { name: '화염방사기', gun: [[0.07, 0.74, 0.09, 0, -0.98, 0.03, '#3a3a3a'], [0.05, 0.1, 0.05, 0, -1.38, 0.03, '#8a5a2a']], range: 30, near: 2.5, far: 6.5, end: 1.45, tank: true },
  saber: { name: '광선검', gun: [[0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc']], range: 60, near: 0, far: 0, end: 0.8, melee: true, blade: true, run: 4.3 },
  lmg: { name: '기관총', gun: [[0.1, 0.98, 0.16, 0, -1.06, 0.03, '#2c2f28'], [0.14, 0.16, 0.12, 0, -0.8, -0.1, '#3d4430']], range: 45, near: 8, far: 24, end: 1.55 },
};
const saberMat = new THREE.MeshBasicMaterial({ color: 0xa8d4ff }), saberGlow = new THREE.MeshBasicMaterial({ color: 0x2a62ff, transparent: true, opacity: 0.42, blending: THREE.AdditiveBlending, depthWrite: false }); // blue
const goldGunMat = new THREE.MeshStandardMaterial({ color: 0xe2b23c, roughness: 0.22, metalness: 0.9, emissive: 0x4a3300, emissiveIntensity: 0.55 });
const saberMat2 = new THREE.MeshBasicMaterial({ color: 0xff8a8a }), saberGlow2 = new THREE.MeshBasicMaterial({ color: 0xff2a3a, transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false });
const vestLightMat = new THREE.MeshBasicMaterial({ color: 0xff2a1a });
/* 1-1's full-face motorcycle helmet: a glossy black shell, chin bar, a smoked visor; one shared model (geometry is marked shared so nobody disposes it) */
const MotoHelmet = (() => {
  let geo = null, mat = null;
  return {
    get geo() {
      if (!geo) {
        const B = AnimalKit.geoBox, blk = '#0d0e10', dk = '#1b1d21';
        geo = AnimalKit.merge([B(0.34, 0.31, 0.36, 0, 0.83, -0.005, blk), B(0.3, 0.07, 0.31, 0, 1.0, -0.015, blk), B(0.26, 0.04, 0.26, 0, 1.04, -0.02, blk),
          B(0.33, 0.12, 0.12, 0, 0.67, -0.12, blk), B(0.3, 0.11, 0.11, 0, 0.7, 0.14, blk), B(0.06, 0.04, 0.03, 0, 0.7, 0.2, dk),
          B(0.28, 0.13, 0.03, 0, 0.825, 0.18, '#3a4d60'), B(0.26, 0.018, 0.034, 0, 0.885, 0.183, '#c2d2e2'), B(0.2, 0.012, 0.034, -0.02, 0.79, 0.183, '#7f94a8'), B(0.3, 0.03, 0.05, 0, 0.9, 0.17, blk),
          B(0.02, 0.06, 0.06, -0.173, 0.83, 0.07, '#3a3d42'), B(0.02, 0.06, 0.06, 0.173, 0.83, 0.07, '#3a3d42'), B(0.09, 0.03, 0.07, 0, 1.06, 0.07, dk),
          B(0.3, 0.05, 0.3, 0, 0.655, 0, '#121316')]);
        geo.userData.shared = true;
      }
      return geo;
    },
    get mat() { return mat || (mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.18, metalness: 0.35, emissive: 0x000000 })); },
  };
})();
const Enemies = (() => {
  const list = [], dying = [];
  const JACKETS = ['#2b3440', '#3d4a33', '#4a3b30', '#2e2e34', '#5a5248', '#283a4a', '#47302e'];
  const SKIN = ['#c99a7a', '#a8775a', '#e0b895', '#7d5a44'];
  const ROT = ['#7d8f6a', '#6f7f63', '#8a9a7a', '#75806a'];
  const RAGS = ['#3b3a35', '#4a4038', '#2f3536', '#534a3f', '#3e4a4c'];
  const barBg = new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.7 });
  const barGeo = new THREE.PlaneGeometry(1, 1);
  const shadows = !isTouch;
  /* one person = 5 draws: merged torso and head, two arms (gun in the right hand), two legs */
  function build(type, opts) {
    opts = opts || {};
    const B = AnimalKit.geoBox, M = AnimalKit.merge, zombie = type === 'zombie', kit = !zombie ? KITS[opts.kit] || KITS.pistol : null;
    const body = zombie ? pick(RAGS) : pick(JACKETS), skin = zombie ? pick(ROT) : pick(SKIN), pants = zombie ? '#2c2c2a' : '#22252b';
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85, emissive: 0x000000 });
    const g = new THREE.Group(); g.rotation.order = 'YXZ';
    const e = { type, T: ETYPES[type], g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(0.2, 1.42, 0.62) };
    const mesh = (parent, geo) => { const m = new THREE.Mesh(geo, mat); m.castShadow = shadows; parent.add(m); return m; };
    e.legL = new THREE.Group(); e.legL.position.set(-0.11, 0.92, 0); g.add(e.legL); mesh(e.legL, M([B(0.15, 0.9, 0.17, 0, -0.45, 0, pants), B(0.16, 0.09, 0.27, 0, -0.88, 0.05, '#161616')]));
    e.legR = new THREE.Group(); e.legR.position.set(0.11, 0.92, 0); g.add(e.legR); mesh(e.legR, M([B(0.15, 0.9, 0.17, 0, -0.45, 0, pants), B(0.16, 0.09, 0.27, 0, -0.88, 0.05, '#161616')]));
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.92, 0); g.add(e.upper);
    const up = [B(0.44, 0.62, 0.26, 0, 0.36, 0, body), B(0.22, 0.25, 0.24, 0, 0.8, 0.01, skin)];
    if (zombie) up.push(B(0.035, 0.025, 0.01, -0.05, 0.82, 0.13, '#fff0a0'), B(0.035, 0.025, 0.01, 0.05, 0.82, 0.13, '#fff0a0'));
    else up.push(B(0.24, 0.08, 0.26, 0, 0.94, 0, pants));
    if (kit && kit.vest) up.push(B(0.42, 0.28, 0.07, 0, 0.42, 0.15, '#5b4a2c'), B(0.07, 0.22, 0.05, -0.13, 0.42, 0.2, '#8a3a24'), B(0.07, 0.22, 0.05, 0, 0.42, 0.2, '#8a3a24'), B(0.07, 0.22, 0.05, 0.13, 0.42, 0.2, '#8a3a24'), B(0.36, 0.02, 0.02, 0, 0.53, 0.21, '#d8c040'));
    if (kit && kit.tank) up.push(B(0.13, 0.46, 0.13, -0.09, 0.42, -0.21, '#8a2a1e'), B(0.13, 0.46, 0.13, 0.09, 0.42, -0.21, '#8a2a1e'), B(0.03, 0.3, 0.03, 0.2, 0.3, -0.12, '#2a2a2a'));
    if (kit && kit.belt) for (let i = 0; i < 4; i++) up.push(B(0.07, 0.08, 0.07, -0.15 + i * 0.1, 0.06, 0.15, '#3d4430'));
    mesh(e.upper, M(up));
    if (opts.helmet) {
      // a full-face motorcycle helmet: the first shot to the head knocks it off
      const hm = new THREE.Mesh(MotoHelmet.geo, MotoHelmet.mat); hm.castShadow = shadows; e.upper.add(hm); e.helmetMesh = hm; e.helmet = true;
    }
    e.armL = new THREE.Group(); e.armL.position.set(-0.29, 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)]));
    e.armR = new THREE.Group(); e.armR.position.set(0.29, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M(zombie || (kit && kit.gold) ? [B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)] : [B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)].concat(kit.gun.map((q) => B(q[0], q[1], q[2], q[3], q[4], q[5], q[6])))));
    if (kit && kit.gold) { const gm = new THREE.Mesh(M(kit.gun.map((q) => B(q[0], q[1], q[2], q[3], q[4], q[5], q[6]))), goldGunMat); gm.castShadow = shadows; e.armR.add(gm); }
    if (kit) { e.kit = opts.kit && KITS[opts.kit] ? opts.kit : 'pistol'; e.K = kit; e.muzzle.set(0.2, 1.42, kit.end); }
    if (kit && kit.blade) {
      // a glowing blade on the hilt, with a soft halo round it; two red ones for the dual wielders
      const arms = kit.dual ? [e.armR, e.armL] : [e.armR], bm = kit.dual ? saberMat2 : saberMat, gm = kit.dual ? saberGlow2 : saberGlow;
      if (kit.dual) mesh(e.armL, M([B(0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc')]));
      for (const a of arms) {
        const blade = new THREE.Mesh(new THREE.BoxGeometry(0.035, 1.15, 0.035), bm); blade.position.set(0, -1.38, 0.03); a.add(blade);
        const halo = new THREE.Mesh(new THREE.BoxGeometry(0.09, 1.22, 0.09), gm); halo.position.copy(blade.position); a.add(halo); if (!e.blade) e.blade = blade;
      }
    }
    if (kit && kit.vest) { const l = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.05, 0.03), vestLightMat); l.position.set(0.11, 0.53 + 0.92, 0.215); g.add(l); e.vestLight = l; }
    e.parts = [
      { o: new THREE.Vector3(0, 1.72, 0.01), r: 0.15, mult: 1, weak: true },
      { o: new THREE.Vector3(0, 1.3, 0), r: 0.3, mult: 1 },
      { o: new THREE.Vector3(0, 0.95, 0), r: 0.22, mult: 0.9 },
      { o: new THREE.Vector3(0, 0.48, 0), r: 0.24, mult: 0.7 },
    ];
    // the bomb strapped to a bomber's chest: one bullet in it and it goes off
    if (kit && kit.vest) e.parts.splice(1, 0, { o: new THREE.Vector3(0, 1.34, 0.18), r: 0.2, mult: 1, bomb: true });
    const bar = new THREE.Group(); const bg = new THREE.Mesh(barGeo, barBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
    const fill = new THREE.Mesh(barGeo, new THREE.MeshBasicMaterial({ color: zombie ? 0x9be88f : 0xff5260 })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
    bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
    bakeFar(e);
    return e;
  }
  /* boss: same kind, built fresh, scaled up and much tougher */
  /* how hard each body shoves when you are pressed together; heavy animals push you, people give way */
  const MASS = { thug: 1, zombie: 1.3, zebra: 2.5, puma: 1.4, lion: 2.2, tiger: 2.4, buffalo: 4, gorilla: 3, hippo: 7, rhino: 7, elephant: 12, cheetah: 1.5, giraffe: 5, lionM: 2.5,
    trooper: 1.5, heavy: 4, crawler: 1.2, drone: 0.5, turret: 60, mech: 25 };
  const _fb = new THREE.Box3();
  /* the body's outline seen from above, in its own frame (x = right, z = forward), measured from the mesh */
  function footprint(e, sc) {
    e.g.position.set(0, 0, 0); e.g.rotation.set(0, 0, 0); e.g.scale.setScalar(1); e.g.updateMatrixWorld(true);
    _fb.setFromObject(e.g);
    const pad = 0.05;
    e.foot = { x0: (_fb.min.x - pad) * sc, x1: (_fb.max.x + pad) * sc, z0: (_fb.min.z - pad) * sc, z1: (_fb.max.z + pad) * sc };
    if (!e.animal) e.foot.z1 = Math.max(e.foot.z1, 0.52 * sc); // people and zombies reach out with their arms
    e.footR = Math.hypot(Math.max(-e.foot.x0, e.foot.x1), Math.max(-e.foot.z0, e.foot.z1));
  }
  function spawn(type, x, z, opts) {
    opts = opts || {};
    const e = ANIMALS[type] ? buildAnimal(type, opts) : typeof ROBOTS !== 'undefined' && ROBOTS[type] ? buildRobot(type, opts) : build(type, opts);
    const T = e.T, sc = opts.scale || 1;
    footprint(e, sc); e.mass = opts.kong && opts.boss ? 40 : (MASS[type] || 1) * (opts.boss ? 2 : 1) * (sc > 1.05 ? sc : 1);
    e.boss = !!opts.boss; e.name = opts.name || T.name; e.scale = sc; e.R = T.r * sc; e.H = T.h * sc;
    e.hp = e.maxHp = Math.round(opts.hp || T.hp); e.diff = opts.diff || 0; e.dmgMul = opts.dmgMul || 1;
    e.speed = type === 'zombie' ? (opts.boss ? 1.7 : rand(1.25, 2.0)) : T.speed * rand(0.9, 1.1) * (opts.boss ? 0.9 : 1);
    e.alive = true; e.flashT = 0; e.deadT = 0; e.pos = e.g.position; e.pos.set(x, opts.y || 0, z); e.vel.set(0, 0, 0); e.vy = 0;
    e.yaw = opts.yaw !== undefined ? opts.yaw : rand(0, TAU); e.alert = false; e.lod = Math.random() * 0.5; e.awake = false; e.dist = 999;
    e.state = 'move'; e.stateT = 0; e.los = false; e.losT = Math.random() * 0.3; e.noLos = 0; e.react = 0;
    e.fireT = rand(0.8, 1.6); e.burst = 0; e.burstT = 0; e.strafe = Math.random() < 0.5 ? 1 : -1; e.strafeT = rand(1, 2.5);
    e.walk = rand(0, TAU); e.attackCd = 0; e.moanT = rand(1, 5); e.flinch = 0;
    e.g.rotation.set(0, e.yaw, 0); e.g.scale.setScalar(sc); if (e.upper) e.upper.rotation.set(type === 'zombie' ? 0.28 : 0, 0, 0);
    e.mats.forEach((m) => m.emissive && m.emissive.setRGB(0, 0, 0));
    if (e.animal) initAnimal(e);
    if (e.K && e.K.run) e.speed = Math.max(e.speed, e.K.run * 0.9); // melee men close the distance quickly even before they see you
    if (e.boss) { e.bar.scale.setScalar(1.6); }
    scene.add(e.g); list.push(e);
    return e;
  }
  const _c = new THREE.Vector3();
  function partCenter(e, p, out) {
    const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw), s = e.scale || 1;
    return out.set(e.pos.x + (p.o.x * cy + p.o.z * sy) * s, e.pos.y + p.o.y * s, e.pos.z + (-p.o.x * sy + p.o.z * cy) * s);
  }
  const RES = { enemy: null, t: 0, mult: 1, weak: false, bomb: false };
  function raycast(o, d, maxT) {
    let best = maxT, hit = null;
    for (const e of list) {
      if (!e.alive || e.ridden || (api.skipCalm && calm(e))) continue; // your own mount: shots go past it
      const dx = e.pos.x - o.x, dz = e.pos.z - o.z;
      if (dx * d.x + dz * d.z < -2 * (e.scale || 1)) continue;
      const s = e.scale || 1;
      for (const p of (e.downed ? e.downParts : e.parts)) {
        partCenter(e, p, _c);
        const ox = o.x - _c.x, oy = o.y - _c.y, oz = o.z - _c.z, pr = p.r * s;
        const b = ox * d.x + oy * d.y + oz * d.z, c = ox * ox + oy * oy + oz * oz - pr * pr, disc = b * b - c;
        if (disc < 0) continue;
        let t = -b - Math.sqrt(disc); if (t < 0) t = -b + Math.sqrt(disc);
        if (t > 0 && (t < best - 0.02 || (t < best + 0.02 && p.weak && hit === e && !RES.weak))) { best = t; hit = e; RES.mult = p.mult; RES.weak = !!p.weak; RES.bomb = !!p.bomb; }
      }
    }
    if (!hit) return null;
    RES.enemy = hit; RES.t = best; return RES;
  }
  const _best = new THREE.Vector3(), _ad = new THREE.Vector3();
  function assist(o, d, maxAng, maxDist) {
    let bestScore = Infinity, found = false;
    for (const e of list) {
      if (!e.alive || !e.g.visible || e.ridden || (api.skipCalm && calm(e))) continue;
      const s = e.scale || 1;
      for (const p of (e.downed ? e.downParts : e.parts)) {
        partCenter(e, p, _c);
        const dx = _c.x - o.x, dy = _c.y - o.y, dz = _c.z - o.z, dist = Math.hypot(dx, dy, dz);
        if (dist < 0.5 || dist > maxDist) continue;
        const cos = (dx * d.x + dy * d.y + dz * d.z) / dist;
        if (cos < 0.9) continue;
        const score = Math.acos(Math.min(1, cos)) - Math.atan(p.r * s / dist);
        if (score > maxAng || score >= bestScore) continue;
        if (score <= 0) return null;
        if (lineOfSight(o, _c)) { bestScore = score; _best.set(dx / dist, dy / dist, dz / dist); found = true; }
      }
    }
    return found ? _ad.copy(_best) : null;
  }
  /* wake an enemy up: it starts hunting you */
  function alarm(e) {
    if (e.alert || !e.alive || e.downed || e.sealed) return;
    e.alert = true;
    if (e.type === 'thug' || e.robot) { e.state = 'move'; e.react = Math.max(e.react, rand(0.4, 0.8)); }
    else if (e.type === 'zombie') { e.state = 'move'; if (e.dist < 30) Sound.moan(e.pos); }
  }
  /* gunfire carries: people and zombies within earshot come for you, animals react in their own way */
  function noise(p, r) {
    for (const e of list) {
      if (!e.alive) continue;
      const d = Math.hypot(e.pos.x - p.x, e.pos.z - p.z);
      if (d > r) continue;
      if (e.animal) hearAnimal(e, d); else alarm(e);
    }
  }
  function damage(e, dmg, point, dir, weak, quiet) {
    if (!e.alive) return false;
    // some take no damage for a moment, or only up to a point (the boss drone sheds a shell at each third of its health)
    if (e.guard) { dmg = e.guard(e, dmg); if (!(dmg > 0)) { FX.sparks(point, 6, [0.6, 0.85, 1], 3); Sound.metal(point); if (e.robot) alarm(e); return false; } }
    // a helmet takes the first shot to the head and flies off
    if (weak && e.helmet) { knockHelmet(e, point, dir); return false; }
    // a zombie lying on the ground: one more hit and the body is gone for good
    if (e.downed) { FX.puff(point, 6, 0.9, 0.6); FX.sparks(point, 10, [0.55, 0.85, 0.4], 3); Sound.squelch(e.pos); e.vanish = true; kill(e, weak, dir); return true; }
    e.hp -= dmg;
    if (quiet) { if (e.hp <= 0) { kill(e, false, dir); return true; } return false; } // bleeding: no spark, no sound, no flinch
    e.flashT = 0.08; e.flinch = 1;
    FX.sparks(point, weak ? 8 : 4, e.type === 'zombie' ? [0.6, 0.8, 0.45] : e.robot ? [1, 0.85, 0.45] : [0.9, 0.8, 0.7], e.robot ? 4 : 2.5);
    FX.puff(point, 1, e.type === 'zombie' ? 0.25 : 0.4, 0.25);
    if (weak) Sound.headshot(e.hp <= 0); else Sound.hit(false); if (e.robot) Sound.metal(point);
    if (!e.boss && !e.ridden) { e.vel.x += dir.x * 0.9; e.vel.z += dir.z * 0.9; }
    if (e.type === 'thug') { alarm(e); e.los = true; e.react = Math.min(e.react, 0.3); for (const o of list) if (o.type === 'thug' && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 18) alarm(o); }
    else if (e.type === 'zombie') alarm(e);
    else if (e.robot) { alarm(e); e.los = true; for (const o of list) if (o.robot && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 18) alarm(o); }
    if (e.animal) provokeAnimal(e);
    if (e.hp <= 0) { if (e.type === 'zombie') { down(e, dir); return false; } kill(e, weak, dir); return true; }
    return false;
  }
  const flying = [];
  const _hp = new THREE.Vector3();
  function knockHelmet(e, point, dir) {
    e.helmet = false;
    // the helmet leaves the head as a whole: same model, same place, then it tumbles away
    const hm = e.helmetMesh; hm.updateMatrixWorld(true); _hp.set(0, 0.84, 0).applyMatrix4(hm.matrixWorld); // the middle of the helmet, in the world
    e.upper.remove(hm); e.helmetMesh = null;
    if (e.far) { e.g.remove(e.far); e.far.geometry.dispose(); e.far = null; } bakeFar(e); setFar(e, !!e.isFar);
    // a pivot at its middle so it spins about itself as it tumbles
    const piv = new THREE.Group(); piv.position.copy(_hp); piv.rotation.set(0, e.yaw, 0); piv.scale.setScalar(e.scale || 1);
    const h = new THREE.Mesh(MotoHelmet.geo, MotoHelmet.mat); h.position.set(0, -0.84, 0); h.castShadow = !isTouch; piv.add(h); scene.add(piv);
    flying.push({ m: piv, vx: dir.x * 3 + rand(-1, 1), vy: rand(3, 4.5), vz: dir.z * 3 + rand(-1, 1), spin: rand(8, 14), t: 0, floor: 0.2 * (e.scale || 1) });
    FX.sparks(point, 10, [1, 0.9, 0.6], 3.5); Sound.ping(point); e.flinch = 1; e.flashT = 0.05;
    HUD.hitmark(false, false);
    if (!Game.helmetHint) { Game.helmetHint = true; HUD.hint('헬멧이 벗겨졌습니다 · 한 번 더 머리를 쏘세요', 2.6); }
    alarm(e);
  }
  /* zombies do not stay dead: they drop, and unless shot again within 3 seconds they get back up at full health */
  const REVIVE = 3;
  function down(e, dir) {
    e.downed = true; e.downT = 0; e.hp = 0; e.state = 'down'; e.vel.set(0, 0, 0); e.flinch = 0;
    e.fallDir = 1; if (dir) { const f = Math.sin(e.yaw) * dir.x + Math.cos(e.yaw) * dir.z; e.fallDir = f > 0 ? 1 : -1; }
    // where the body is once it lies flat, for bullets: along the fall direction, just off the ground
    e.downParts = e.parts.map((p) => ({ o: new THREE.Vector3(p.o.x, Math.max(0.16, p.o.y * 0.12 + 0.08), e.fallDir * p.o.y * 0.99), r: p.r * 1.05, mult: 1, weak: p.weak }));
    e.fill.material.color.setHex(0xf2a33a);
    Sound.thud(e.pos); Sound.moan(e.pos);
    if (!Game.downHint) { Game.downHint = true; HUD.hint('쓰러진 좀비는 3초 안에 한 번 더 쏴야 사라집니다 · 안 그러면 다시 일어납니다', 3.5); }
  }
  function updateDowned(e, dt) {
    e.downT += dt;
    const t = e.downT;
    if (t < REVIVE) {
      const k = Math.min(1, t / 0.45), ease = k * k * (3 - 2 * k);
      e.g.rotation.set(e.fallDir * ease * 1.45, e.yaw, t > REVIVE - 1 ? Math.sin(t * 38) * 0.06 : 0); // twitches before it rises
      e.legL.rotation.x = e.legR.rotation.x = 0; e.upper.rotation.x = 0;
    } else if (t < REVIVE + 0.7) {
      if (!e.rising) { e.rising = true; Sound.revive(e.pos); }
      const k = (t - REVIVE) / 0.7, ease = k * k * (3 - 2 * k);
      e.g.rotation.set(e.fallDir * (1 - ease) * 1.45, e.yaw, 0);
    } else {
      e.downed = false; e.rising = false; e.hp = e.maxHp; e.dashUsed = false; e.revived = true; // too late for the bonus e.state = 'move'; e.alert = true; e.chargeCd = 3;
      e.g.rotation.set(0, e.yaw, 0); e.fill.material.color.setHex(0x9be88f); e.bar.visible = false;
      if (e.boss) HUD.banner(e.name + ' 부활', '쓰러지면 3초 안에 한 번 더 쏘세요', 2.2);
      return;
    }
    // the bar above the body counts down to the moment it gets back up
    e.bar.visible = e.g.visible; e.bar.position.set(e.pos.x, e.pos.y + 0.7 * (e.scale || 1), e.pos.z); e.bar.quaternion.copy(camera.quaternion);
    const f = clamp(1 - t / REVIVE, 0, 1); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1 - f);
  }
  function kill(e, weak, dir) {
    e.alive = false; e.deadT = 0; e.bar.visible = false; e.g.visible = true; e.downed = false;
    if (e.laser) e.laser.visible = false;
    if (e.K && e.K.vest) { const now = e.selfDet || e.vestShot; Proj.bomb(e.pos, now ? 0.02 : 0.3); if (now) e.vanish = true; } // the vest goes off (at once if the bomb itself was hit)
    if (e.T && e.T.mode === 'mine') ShipFX.mineBlast(e.pos, e.selfDet ? 0 : 0.06); // a spider mine goes off: 100 to anyone close, other mines go with it
    if (e.robot) { const c = { x: e.pos.x, y: e.pos.y + (e.fly ? 0 : e.H * 0.5), z: e.pos.z }; FX.explode(c, !!e.boss, [0.6, 0.85, 1]); FX.chunks(c, e.boss ? 18 : 8, 0.16 * (e.scale || 1), 'metal'); Sound.boom(c, !!e.boss); e.vanish = true; }
    e.fallDir = e.type === 'zombie' ? 1 : -1; e.side = Math.random() < 0.5 ? 1 : -1;
    if (dir) { const f = Math.sin(e.yaw) * dir.x + Math.cos(e.yaw) * dir.z; e.fallDir = f > 0 ? 1 : -1; }
    const i = list.indexOf(e); if (i >= 0) list.splice(i, 1);
    dying.push(e);
    Sound.thud(e.pos); if (e.boss) Sound.boom(e.pos, false);
    Game.onKill(e, weak);
  }
  function splash(c, radius, dmg, skip) {
    for (const e of list.slice()) {
      if (e.ridden || e === skip) continue;
      const d = Math.hypot(e.pos.x - c.x, e.pos.y + 1 - c.y, e.pos.z - c.z);
      if (d > radius + e.R) continue;
      _c.set(e.pos.x, e.pos.y + e.H * 0.6, e.pos.z);
      if (!lineOfSight(c, _c)) continue;
      const k = 1 - Math.min(1, d / (radius + e.R));
      if (damage(e, dmg * (0.35 + 0.65 * k), _c, { x: (e.pos.x - c.x) / (d || 1), y: 0, z: (e.pos.z - c.z) / (d || 1) }, false)) HUD.hitmark(true, false);
    }
  }
  function updateDying(dt) {
    for (let i = flying.length - 1; i >= 0; i--) {
      const f = flying[i]; f.t += dt; f.vy -= 12 * dt;
      const fl = f.floor || 0.08;
      f.m.position.x += f.vx * dt; f.m.position.y = Math.max(fl, f.m.position.y + f.vy * dt); f.m.position.z += f.vz * dt; f.m.rotation.x += f.spin * dt; f.m.rotation.z += f.spin * 0.6 * dt;
      if (f.m.position.y <= fl) { f.vx *= 0.6; f.vz *= 0.6; f.vy = Math.abs(f.vy) * 0.25; f.spin *= 0.5; }
      if (f.t > 4) { scene.remove(f.m); flying.splice(i, 1); }
    }
    for (let i = dying.length - 1; i >= 0; i--) {
      const e = dying[i]; e.deadT += dt;
      const t = Math.min(1, e.deadT / 0.5), ease = t * t * (3 - 2 * t);
      if (e.vanish) { const s = Math.max(0.001, 1 - e.deadT / 0.45) * (e.scale || 1); e.g.scale.set(s, s * 0.6, s); e.pos.y -= dt * 0.8; if (e.deadT > 0.45) e.deadT = 99; }
      else if (e.animal) { e.g.rotation.set(0, e.yaw, e.side * ease * 1.5); if (e.deadT < 4.5) e.pos.y = Math.max(e.pos.y - dt * 2, 0); else e.pos.y -= dt * 0.5 * e.H; }
      else { e.g.rotation.set(e.fallDir * ease * 1.45, e.yaw, 0); if (e.deadT > 2.6) e.pos.y -= dt * 0.6; }
      if (e.deadT > (e.animal ? 6.5 : 3.4)) { scene.remove(e.g); dying.splice(i, 1); disposeEnemy(e); }
    }
  }
  /* a bomber who reaches you: his own vest, no money for you, but he counts as gone */
  function detonate(e) { if (!e.alive) return; e.selfDet = true; kill(e, false, null); }
  /* gone without a kill: the boss's leftover mines when it dies */
  function vanish(e) { if (!e.alive) return; e.alive = false; e.vanish = true; e.deadT = 0; e.bar.visible = false; const i = list.indexOf(e); if (i >= 0) list.splice(i, 1); dying.push(e); FX.puff(e.pos, 3, 0.3, 0.4); }
  function disposeEnemy(e) {
    if (e.laser) { scene.remove(e.laser); e.laser.geometry.dispose(); }
    e.g.traverse((o) => { if (o.isMesh && !o.geometry.userData.shared) o.geometry.dispose(); });
    e.mats.forEach((m) => m.dispose()); scene.remove(e.bar); e.fill.material.dispose();
  }
  function clear() {
    for (const e of list) { scene.remove(e.g); disposeEnemy(e); }
    for (const e of dying) { scene.remove(e.g); disposeEnemy(e); }
    for (const f of flying) scene.remove(f.m);
    list.length = 0; dying.length = 0; flying.length = 0;
  }
  /* never fights you: a loose zebra in the lab, or an animal you have ridden */
  function calm(e) { return e.tamed || (e.type === 'zebra' && e.fury); }
  /* a bullet in a bomber's chest bomb: it goes off there and then, and the kill is yours */
  function blowVest(e, dir) { if (!e.alive) return; e.vestShot = true; e.hp = 0; HUD.feed('자폭 조끼 명중 · 폭탄이 터졌습니다', 0, 'hs'); kill(e, false, dir); }
  const api = { list, spawn, raycast, assist, damage, splash, updateDying, updateDowned, clear, partCenter, alarm, noise, detonate, vanish, calm, blowVest, skipCalm: false };
  return api;
})();
