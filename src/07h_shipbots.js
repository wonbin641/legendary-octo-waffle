/* ============ the ship's crew (stage 4): CCTV turrets on the ceiling, patrol bots with glow batons, little quad drones,
   spider mines hidden in the floor, the gold commander drone on the bridge, and the three-shell boss drone in the main hall ============ */
Object.assign(ROBOTS, {
  cctv: { name: 'CCTV 포탑', hp: 45, speed: 0, r: 0.3, h: 0.45, money: 500, mode: 'cctv', sight: 30, range: 32, shot: [1, 1, 0.1, 4, 1.0, 1.6], mapKind: 'cctv' },
  patrol: { name: '순찰 로봇', hp: 160, speed: 1.6, r: 0.4, h: 1.95, money: 1000, mode: 'patrol', sight: 26, dmg: 60, mapKind: 'patrol' },
  droneA: { name: '드론', hp: 1, speed: 5.5, r: 0.45, h: 0.35, money: 800, mode: 'droneA', sight: 36, range: 40, shot: [2, 3, 0.16, 5, 1.1, 1.9], mapKind: 'droneA' },
  mine: { name: '스파이더 마인', hp: 1, speed: 8.5, r: 0.35, h: 0.32, money: 500, mode: 'mine', sight: 7.5, dmg: 100, mapKind: 'mine' },
  gdrone: { name: '황금꿀벌드론', hp: 5000, speed: 4.2, r: 1.3, h: 1.6, money: 1500, mode: 'gdrone', sight: 34, range: 42, shot: [7, 9, 0.08, 13, 1.0, 1.6], mapKind: 'midboss', mid: true }, // 5.19: stronger (was 3,200 hp, 5-7 bolts of 9)
  bdrone: { name: '보스 드론', hp: 9000, speed: 5, r: 2.5, h: 5, money: 2000, mode: 'bdrone', sight: 60, range: 70, mapKind: 'boss' },
});
const SHIPBOT = { cctv: 1, patrol: 1, droneA: 1, mine: 1, gdrone: 1, bdrone: 1 };
/* a soft studio sky for things that should shine: the gold drone, the boss's white shell */
const ShineEnv = (() => {
  let tex = null, tried = false;
  return { get() {
    if (tried) return tex; tried = true;
    try {
      const pm = new THREE.PMREMGenerator(renderer), es = new THREE.Scene();
      const geo = new THREE.SphereGeometry(10, 24, 12), pos = geo.attributes.position, col = [], c = new THREE.Color();
      const top = new THREE.Color(0x9ab4dc), mid = new THREE.Color(0x3a4356), bot = new THREE.Color(0x101318);
      for (let i = 0; i < pos.count; i++) { const y = pos.getY(i) / 10; if (y >= 0) c.copy(mid).lerp(top, Math.pow(y, 0.7)); else c.copy(mid).lerp(bot, Math.pow(-y, 0.5)); col.push(c.r, c.g, c.b); }
      geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
      es.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide })));
      for (const [x, y, z, w, hx] of [[5, 6, 2, 6, 0xffffff], [-6, 4, -3, 4, 0xffe2b0], [0, 8, -6, 8, 0xffffff], [3, -2, 7, 5, 0x9fc8ff]]) {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * 0.4), new THREE.MeshBasicMaterial({ color: hx, side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); es.add(m);
      }
      tex = pm.fromScene(es, 0.02).texture; pm.dispose();
    } catch (err) { tex = null; }
    return tex;
  } };
})();
const camLensMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a }), visorMat = new THREE.MeshBasicMaterial({ color: 0xffd23a });
const batonMat = new THREE.MeshBasicMaterial({ color: 0xd8ff7a }), batonGlow = new THREE.MeshBasicMaterial({ color: 0x8aff3a, transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false });
const thrustMat = new THREE.MeshBasicMaterial({ color: 0x6fc8ff }), gVisorMat = new THREE.MeshBasicMaterial({ color: 0xff3a2a });
let bossShellTex = null;
function shellTex() {
  if (bossShellTex) return bossShellTex;
  bossShellTex = canvasTex(1024, 512, (g, w, h) => {
    g.fillStyle = '#eef1f6'; g.fillRect(0, 0, w, h);
    g.strokeStyle = 'rgba(70,80,96,0.75)'; g.lineWidth = 3;
    for (const v of [0.18, 0.36, 0.5, 0.64, 0.82]) { g.beginPath(); g.moveTo(0, v * h); g.lineTo(w, v * h); g.stroke(); }
    for (let i = 0; i < 12; i++) { const x = (i / 12) * w + (i % 2 ? 18 : 0); g.beginPath(); g.moveTo(x, 0.18 * h); g.lineTo(x, 0.36 * h); g.moveTo(x + 30, 0.5 * h); g.lineTo(x + 30, 0.64 * h); g.moveTo(x - 20, 0.64 * h); g.lineTo(x - 20, 0.82 * h); g.stroke(); }
    g.fillStyle = 'rgba(40,46,58,0.8)'; for (let i = 0; i < 14; i++) { const x = rand(0, w), y = rand(0.2, 0.8) * h; g.fillRect(x, y, rand(10, 26), rand(4, 8)); }
    speckle(g, w, h, 1500, ['rgba(0,0,0,0.06)', 'rgba(255,255,255,0.3)'], 1.5);
  });
  return bossShellTex;
}
const BLUE = 0x1478ff, RED = 0xff1a10;
/* 5.14: the boss's iris: a grey radial drawing (the material tints it blue, or red when it is about to fire), rings and spokes like a lens */
const BossIris = (() => { let t = null; return () => t || (t = canvasTex(256, 256, (g, w) => {
  const c = w / 2, gr = g.createRadialGradient(c, c, 0, c, c, c);
  gr.addColorStop(0, '#ffffff'); gr.addColorStop(0.2, '#ffffff'); gr.addColorStop(0.36, '#d4e6ff'); gr.addColorStop(0.62, '#8fb4ec'); gr.addColorStop(0.86, '#5579bd'); gr.addColorStop(1, '#2a3f73');
  g.fillStyle = gr; g.beginPath(); g.arc(c, c, c, 0, TAU); g.fill();
  g.strokeStyle = 'rgba(255,255,255,0.45)'; g.lineWidth = 4; for (const r of [0.44, 0.66, 0.84]) { g.beginPath(); g.arc(c, c, c * r, 0, TAU); g.stroke(); }
  g.strokeStyle = 'rgba(255,255,255,0.28)'; g.lineWidth = 3; for (let i = 0; i < 20; i++) { const a = (i / 20) * TAU; g.beginPath(); g.moveTo(c + Math.cos(a) * c * 0.5, c + Math.sin(a) * c * 0.5); g.lineTo(c + Math.cos(a) * c * 0.92, c + Math.sin(a) * c * 0.92); g.stroke(); }
})); })();

function buildShipBot(type, opts) {
  opts = opts || {};
  const B = AnimalKit.geoBox, M = AnimalKit.merge, T = ROBOTS[type];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.42, metalness: 0.55, emissive: 0x000000 });
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const e = { type, T, robot: true, g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(), seed: Math.random() * 10, spin: 0 };
  const mesh = (parent, geo, m) => { const x = new THREE.Mesh(geo, m || mat); x.castShadow = !isTouch; parent.add(x); return x; };
  const add = (parent, geo, m, x, y, z) => { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); parent.add(o); return o; };
  if (T.mode === 'cctv') {
    // a white camera on a short arm from the ceiling, a red eye in the lens and a small gun under it; it turns to follow you
    mesh(g, M([B(0.26, 0.04, 0.26, 0, 0.44, 0, '#2a2f3a'), B(0.06, 0.36, 0.06, 0, 0.26, 0, '#3a4150')]));
    e.cam = new THREE.Group(); g.add(e.cam);
    mesh(e.cam, M([B(0.2, 0.16, 0.34, 0, 0, 0.02, '#d5d9e0'), B(0.25, 0.03, 0.42, 0, 0.095, 0.05, '#bfc4cc'), B(0.13, 0.13, 0.04, 0, 0, 0.2, '#1c2028'), B(0.045, 0.045, 0.24, 0, -0.105, 0.17, '#1c2028')]));
    add(e.cam, new THREE.BoxGeometry(0.06, 0.06, 0.02), camLensMat, 0, 0, 0.225);
    e.muzzle.set(0, -0.105, 0.3); e.eyeH = 0; e.fly = true; e.barY = -0.45;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0.04), r: 0.21, mult: 1 }, { o: new THREE.Vector3(0, 0, 0.21), r: 0.075, mult: 1, weak: true }];
  } else if (T.mode === 'patrol') {
    // a security robot in white with orange bands, a yellow visor, and a long glow baton in its right hand
    const c1 = '#d8dce4', c2 = '#5a6170', c3 = '#2a2f3a', band = '#e8902a';
    for (const sx of [-1, 1]) {
      const leg = new THREE.Group(); leg.position.set(sx * 0.14, 0.95, 0); g.add(leg);
      mesh(leg, M([B(0.18, 0.92, 0.2, 0, -0.46, 0, c2), B(0.22, 0.12, 0.34, 0, -0.9, 0.06, c3), B(0.2, 0.07, 0.22, 0, -0.42, 0.02, band)]));
      if (sx < 0) e.legL = leg; else e.legR = leg;
    }
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.95, 0); g.add(e.upper);
    mesh(e.upper, M([B(0.52, 0.6, 0.32, 0, 0.36, 0, c1), B(0.54, 0.08, 0.34, 0, 0.5, 0, band), B(0.2, 0.14, 0.3, -0.34, 0.66, 0, c2), B(0.2, 0.14, 0.3, 0.34, 0.66, 0, c2),
      B(0.12, 0.08, 0.12, 0, 0.71, 0, c3), B(0.3, 0.26, 0.3, 0, 0.87, 0, c1), B(0.32, 0.05, 0.32, 0, 1.0, 0, band), B(0.03, 0.22, 0.03, 0.1, 1.08, -0.05, c3)]));
    add(e.upper, new THREE.BoxGeometry(0.24, 0.06, 0.02), visorMat, 0, 0.88, 0.155);
    e.armL = new THREE.Group(); e.armL.position.set(-0.34, 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3)]));
    e.armR = new THREE.Group(); e.armR.position.set(0.34, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3), B(0.05, 0.16, 0.05, 0, -0.74, 0.03, '#2a2a2a')]));
    add(e.armR, new THREE.CylinderGeometry(0.035, 0.035, 0.66, 8), batonMat, 0, -1.14, 0.03);
    add(e.armR, new THREE.CylinderGeometry(0.085, 0.085, 0.72, 8), batonGlow, 0, -1.14, 0.03);
    e.parts = [{ o: new THREE.Vector3(0, 1.81, 0), r: 0.17, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.33, 0), r: 0.33, mult: 1 },
      { o: new THREE.Vector3(0, 0.98, 0), r: 0.25, mult: 0.9 }, { o: new THREE.Vector3(0, 0.5, 0), r: 0.26, mult: 0.7 }];
    e.eyeH = 1.82;
  } else if (T.mode === 'droneA') {
    // a little quadcopter: a flat body, arms out to the four corners with a propeller on each, a red eye under the nose
    mesh(g, M([B(0.42, 0.12, 0.42, 0, 0, 0, '#cfd4dc'), B(0.3, 0.1, 0.3, 0, -0.1, 0.02, '#2a2f3a'), B(0.84, 0.04, 0.06, 0, 0.02, 0, '#3a4150', [0, Math.PI / 4, 0]),
      B(0.84, 0.04, 0.06, 0, 0.02, 0, '#3a4150', [0, -Math.PI / 4, 0]), B(0.05, 0.08, 0.18, 0, -0.16, 0.16, '#1c2028')]));
    e.rotors = [];
    for (const [x, z] of [[0.3, 0.3], [-0.3, 0.3], [0.3, -0.3], [-0.3, -0.3]]) {
      mesh(g, M([B(0.08, 0.07, 0.08, x, 0.05, z, '#2a2f3a')]));
      const ro = new THREE.Group(); ro.position.set(x, 0.1, z); g.add(ro); mesh(ro, M([B(0.42, 0.012, 0.05, 0, 0, 0, '#1c2028'), B(0.05, 0.012, 0.42, 0, 0, 0, '#1c2028')])); e.rotors.push(ro);
    }
    add(g, new THREE.BoxGeometry(0.08, 0.05, 0.03), camLensMat, 0, -0.13, 0.25);
    e.muzzle.set(0, -0.16, 0.28); e.eyeH = 0; e.fly = true; e.barY = 0.5;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 0.34, mult: 1 }, { o: new THREE.Vector3(0, -0.12, 0.2), r: 0.1, mult: 1, weak: true }];
  } else if (T.mode === 'mine') {
    // a squat dark disc with six folded legs and a dim red eye; it lies buried flush with the floor until something comes close
    e.body = new THREE.Group(); g.add(e.body);
    mesh(e.body, M([B(0.56, 0.14, 0.56, 0, 0.1, 0, '#24282f', null, false, true), B(0.4, 0.08, 0.4, 0, 0.19, 0, '#30353e', null, false, true), B(0.62, 0.03, 0.62, 0, 0.06, 0, '#1a1d22')]));
    const lm = new THREE.MeshBasicMaterial({ color: 0x401010 }); e.mats.push(lm);
    e.light = add(e.body, new THREE.BoxGeometry(0.07, 0.03, 0.07), lm, 0, 0.235, 0.06);
    e.cl = [];
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * TAU + 0.5, p = new THREE.Group(); p.position.set(Math.cos(a) * 0.24, 0.1, Math.sin(a) * 0.24); p.rotation.order = 'YXZ'; p.rotation.y = -a; g.add(p);
      mesh(p, M([B(0.3, 0.04, 0.05, 0.15, 0, 0, '#3a4150'), B(0.04, 0.22, 0.04, 0.3, -0.1, 0, '#2a2f3a')])); e.cl.push(p);
    }
    e.parts = [{ o: new THREE.Vector3(0, 0.12, 0), r: 0.3, mult: 1 }]; e.eyeH = 0.3; e.barY = 0.7;
  } else if (T.mode === 'gdrone') {
    // the commander: a heavy hull plated in polished gold, a red visor, two engines, twin cannons and a crest on top
    const gold = new THREE.MeshStandardMaterial({ color: 0xd99a1e, metalness: 1, roughness: 0.14, envMap: ShineEnv.get(), envMapIntensity: 1.25, emissive: 0x3a2000, emissiveIntensity: 0.35 });
    e.mats.push(gold);
    const gm = (geo, x, y, z) => { const m = new THREE.Mesh(geo, gold); m.position.set(x, y, z); m.castShadow = !isTouch; g.add(m); return m; };
    gm(new THREE.SphereGeometry(1, 28, 16), 0, 0, 0).scale.set(1.25, 0.62, 1.05);
    gm(new THREE.SphereGeometry(0.55, 20, 10, 0, TAU, 0, Math.PI / 2), 0, 0.32, -0.1);
    gm(new THREE.BoxGeometry(0.07, 0.42, 0.9), 0, 0.78, -0.15);
    for (const sx of [-1, 1]) { const n = gm(new THREE.CylinderGeometry(0.3, 0.24, 1.35, 16), sx * 1.3, -0.05, -0.05); n.rotation.x = Math.PI / 2;
      add(g, new THREE.CircleGeometry(0.2, 16), thrustMat, sx * 1.3, -0.05, -0.74).rotation.y = Math.PI; }
    mesh(g, M([B(0.13, 0.13, 0.95, -0.38, -0.46, 0.55, '#1c2028'), B(0.13, 0.13, 0.95, 0.38, -0.46, 0.55, '#1c2028'), B(0.9, 0.12, 0.3, 0, -0.4, 0.15, '#2a2f3a'),
      B(0.03, 0.6, 0.03, -0.35, 0.75, -0.4, '#2a2f3a'), B(0.03, 0.45, 0.03, 0.35, 0.68, -0.4, '#2a2f3a')]));
    add(g, new THREE.BoxGeometry(0.95, 0.12, 0.05), gVisorMat, 0, 0.06, 1.02);
    // a golden bee: big glossy compound eyes, feelers, a striped abdomen with a sting, and four see-through wings that beat
    const eyeM = new THREE.MeshStandardMaterial({ color: 0x1c0d06, metalness: 0.4, roughness: 0.12, emissive: 0x3a0a00, envMap: ShineEnv.get(), envMapIntensity: 1.4 }); e.mats.push(eyeM); e.beeEye = eyeM;
    for (const sx of [-1, 1]) { const ey = new THREE.Mesh(new THREE.SphereGeometry(0.36, 18, 12), eyeM); ey.scale.set(0.75, 1.15, 0.85); ey.position.set(sx * 0.55, 0.16, 0.78); g.add(ey);
      const an = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.85, 6), new THREE.MeshStandardMaterial({ color: 0x241a0c, roughness: 0.6 })); an.position.set(sx * 0.22, 0.86, 0.86); an.rotation.set(0.7, 0, -sx * 0.35); g.add(an);
      gm(new THREE.SphereGeometry(0.07, 8, 6), sx * 0.36, 1.2, 1.12); }
    gm(new THREE.SphereGeometry(1, 24, 14), 0, -0.04, -1.3).scale.set(0.95, 0.8, 1.25);
    const band = new THREE.MeshStandardMaterial({ color: 0x15100a, roughness: 0.35, metalness: 0.5 });
    for (const [z, rr] of [[-0.95, 0.88], [-1.35, 0.95], [-1.78, 0.78]]) { const b = new THREE.Mesh(new THREE.CylinderGeometry(rr, rr, 0.2, 24, 1, true), band); b.rotation.x = Math.PI / 2; b.scale.set(1.01, 1, 0.85); b.position.set(0, -0.04, z); g.add(b); }
    const sting = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.6, 10), band); sting.rotation.x = -Math.PI / 2; sting.position.set(0, -0.08, -2.75); g.add(sting);
    const wingM = new THREE.MeshBasicMaterial({ color: 0xdcecff, transparent: true, opacity: 0.38, side: THREE.DoubleSide, depthWrite: false });
    const wingGeo = new THREE.CircleGeometry(1, 20); wingGeo.scale(1.25, 0.42, 1); wingGeo.rotateX(-Math.PI / 2); wingGeo.translate(1.15, 0, -0.15);
    e.wings = [];
    for (const sx of [-1, 1]) for (const [dz, sc] of [[0.15, 1], [-0.45, 0.78]]) {
      const w = new THREE.Group(); w.position.set(sx * 0.4, 0.62, dz); const m = new THREE.Mesh(wingGeo, wingM); m.scale.set(sx * sc, 1, sc); w.add(m); g.add(w); e.wings.push({ g: w, sx });
    }
    e.muzzle.set(0.38, -0.46, 1.08); e.eyeH = 0; e.fly = true; e.barY = 1.8;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 1.12, mult: 1 }, { o: new THREE.Vector3(0, 0.06, 0.98), r: 0.24, mult: 1, weak: true }, { o: new THREE.Vector3(0, 0, -1.3), r: 0.95, mult: 1 }];
  } else {
    // the boss: three shells, one inside the other. 5 m armoured, 3 m armoured, and the 1.5 m white core with the eye;
    // the eye looks out of every one of them
    const env = ShineEnv.get();
    const white = new THREE.MeshStandardMaterial({ color: 0xeef1f6, map: shellTex(), roughness: 0.22, metalness: 0.3, envMap: env, envMapIntensity: 1.2 });
    const armor = new THREE.MeshStandardMaterial({ color: 0x9aa4b6, roughness: 0.33, metalness: 0.65, envMap: env, envMapIntensity: 1.0 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x1a1f28, roughness: 0.4, metalness: 0.5 });
    const eyeMat = new THREE.MeshBasicMaterial({ color: BLUE, map: BossIris(), toneMapped: false }), pupil = new THREE.MeshBasicMaterial({ color: 0xd8ecff, toneMapped: false }), lights = new THREE.MeshBasicMaterial({ color: 0x3a9cff });
    const glowS = new THREE.SpriteMaterial({ map: World.poolTex || null, color: 0x2f8cff, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.34 });
    const lensM = new THREE.MeshStandardMaterial({ color: 0x0a1428, roughness: 0.12, metalness: 0.7, envMap: env, envMapIntensity: 1.1 });
    const sockM = new THREE.MeshStandardMaterial({ color: 0x10141c, roughness: 0.6, metalness: 0.4, side: THREE.DoubleSide });
    e.mats.push(white, armor, dark, eyeMat, pupil, lights, lensM, sockM); e.eyeMat = eyeMat; e.eyeGlow = glowS; e.lightMat = lights;
    e.shells = [];
    [5, 3, 1.5].forEach((D, k) => {
      const s = new THREE.Group(), R = D / 2; g.add(s);
      // the shell is a sphere with a round opening at the front (a sphere missing its top cap, turned to face forward)
      const HOLE = Math.asin(0.46), sg = new THREE.SphereGeometry(R, 44, 26, 0, TAU, HOLE, Math.PI - HOLE); sg.rotateX(Math.PI / 2);
      const ball = new THREE.Mesh(sg, white); ball.castShadow = !isTouch; s.add(ball);
      // in the opening: a dark socket, a white rim, a dark lens ring, the iris (blue, open) and a bright core, all set back a little
      const eye = new THREE.Group(); eye.position.z = R * 0.9; s.add(eye);
      const rimZ = Math.cos(HOLE) * R - R * 0.9;
      const sock = new THREE.Mesh(new THREE.CylinderGeometry(R * 0.46, R * 0.46, R * 0.16, 40, 1, true), sockM); sock.rotation.x = Math.PI / 2; sock.position.z = rimZ - R * 0.08; eye.add(sock);
      add(eye, new THREE.CircleGeometry(R * 0.46, 40), dark, 0, 0, rimZ - R * 0.16);
      add(eye, new THREE.TorusGeometry(R * 0.455, R * 0.04, 10, 44), white, 0, 0, rimZ);
      add(eye, new THREE.CircleGeometry(R * 0.4, 40), lensM, 0, 0, rimZ - R * 0.12);
      add(eye, new THREE.TorusGeometry(R * 0.36, R * 0.028, 8, 40), dark, 0, 0, rimZ - R * 0.11);
      add(eye, new THREE.CircleGeometry(R * 0.33, 40), eyeMat, 0, 0, rimZ - R * 0.1);
      add(eye, new THREE.CircleGeometry(R * 0.085, 24), pupil, 0, 0, rimZ - R * 0.095);
      const sp = new THREE.Sprite(glowS); sp.position.z = rimZ + R * 0.05; sp.scale.setScalar(R * 1.15); eye.add(sp);
      // light strips round the middle and under the belly
      for (const a of [-2.5, -1.8, -1.05, 1.05, 1.8, 2.5]) { const b = add(s, new THREE.BoxGeometry(R * 0.36, R * 0.05, R * 0.04), lights, Math.sin(a) * R * 1.0, 0, Math.cos(a) * R * 1.0); b.rotation.y = a + Math.PI / 2; }
      for (const a of [-0.6, 0, 0.6]) { const b = add(s, new THREE.BoxGeometry(R * 0.32, R * 0.04, R * 0.05), lights, Math.sin(a) * R * 0.62, -R * 0.78, Math.cos(a) * R * 0.62); b.rotation.set(0.9, a, 0); }
      if (k < 2) {
        // armour: plates over the shell (never over the eye), rocket pods on both flanks, fins on top of the big one
        for (let i = 0; i < (k === 0 ? 10 : 6); i++) {
          const th = (i / (k === 0 ? 10 : 6)) * TAU + 0.3, ph = i % 2 ? 0.55 : -0.45, x = Math.sin(th) * Math.cos(ph), y = Math.sin(ph), z = Math.cos(th) * Math.cos(ph);
          if (z > 0.55 && Math.abs(y) < 0.6) continue;
          const p = new THREE.Mesh(new THREE.BoxGeometry(R * 0.62, R * 0.46, R * 0.1), armor); p.position.set(x * R * 0.98, y * R * 0.98, z * R * 0.98); p.lookAt(x * R * 3, y * R * 3, z * R * 3); p.castShadow = !isTouch; s.add(p);
        }
        for (const sx of [-1, 1]) {
          const pod = new THREE.Mesh(new THREE.BoxGeometry(R * 0.3, R * 0.5, R * 0.7), armor); pod.position.set(sx * R * 1.02, 0.05 * R, 0); s.add(pod);
          for (let j = 0; j < 4; j++) add(s, new THREE.CircleGeometry(R * 0.06, 12), dark, sx * R * 1.02, (j < 2 ? 0.17 : -0.12) * R, R * 0.36 + 0.002).position.x += (j % 2 ? 0.07 : -0.07) * R;
        }
        if (k === 0) for (const sx of [-1, 1]) { const fin = new THREE.Mesh(new THREE.BoxGeometry(R * 0.05, R * 0.4, R * 0.6), armor); fin.position.set(sx * R * 0.25, R * 0.98, -R * 0.1); s.add(fin); }
      }
      s.visible = k === 0;
      e.shells.push({ g: s, R, eye });
    });
    e.noFar = true; e.fly = true; e.eyeH = 0; e.barY = 3.2;
    e.parts = shellParts(2.5);
  }
  const bar = new THREE.Group(); const bg = new THREE.Mesh(rBarGeo, rBarBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
  const fill = new THREE.Mesh(rBarGeo, new THREE.MeshBasicMaterial({ color: T.mode === 'gdrone' ? 0xffc040 : 0x8ec8ff })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
  bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
  if (!e.noFar) bakeFar(e);
  return e;
}
function shellParts(R) { return [{ o: new THREE.Vector3(0, 0, 0), r: R, mult: 1 }, { o: new THREE.Vector3(0, 0, R * 0.9), r: R * 0.3, mult: 1, weak: true }]; }

/* ---------- small helpers ---------- */
function callNear(e, r) { for (const o of Enemies.list) if (o.robot && !o.alert && o !== e && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < r) Enemies.alarm(o); }
const _sv = new THREE.Vector3(), _sw = new THREE.Vector3(), _sx = new THREE.Vector3();
/* the way towards you on foot: straight when it sees you, along the walking grid when it does not */
function shipDir(e, dist, near) {
  if (dist < near && e.los) { _fd.x = _to.x / dist; _fd.z = _to.z / dist; return _fd; }
  if (flowDir(e.pos.x, e.pos.z, _fd)) return _fd;
  _fd.x = _to.x / dist; _fd.z = _to.z / dist; return _fd;
}

/* ---------- CCTV: watches and sweeps; once it has you it follows you and shoots weak single bolts ---------- */
function cctvAI(e, dt, dist, faceYaw) {
  e.spin += dt;
  const seen = e.los && dist < e.T.sight;
  if (!e.alert && seen) { Enemies.alarm(e); callNear(e, 22); }
  if (e.alert && seen) {
    turnToward(e, faceYaw, 3, dt);
    const dy = player.pos.y + 1.3 - e.pos.y; e.cam.rotation.x = lerp(e.cam.rotation.x, clamp(-Math.atan2(dy, dist), -0.3, 1.3), 1 - Math.exp(-dt * 6));
    e.react -= dt; if (e.react <= 0) robotFire(e, dt, dist);
  } else {
    e.yaw += Math.sin(e.spin * 0.5 + e.seed) * dt * 0.6; e.g.rotation.y = e.yaw; e.cam.rotation.x = lerp(e.cam.rotation.x, 0.45, 1 - Math.exp(-dt));
    if (e.alert) e.react = Math.max(e.react, 0.4);
  }
}
/* ---------- patrol bot: walks its beat; seen, it runs you down and swings the baton (60) ---------- */
function patrolAI(e, dt, dist, faceYaw) {
  const T = e.T;
  if (!e.alert && e.los && dist < T.sight) {
    let a = faceYaw - e.yaw; a = Math.atan2(Math.sin(a), Math.cos(a));
    if (Math.abs(a) < 1.3 || dist < 6) { Enemies.alarm(e); callNear(e, 16); Sound.zap(e.pos, 'turret'); }
  }
  if (!e.alert) {
    let sp = 0;
    const w = e.wp ? e.wp[e.wi] : null;
    if (w) {
      const dx = w.x - e.pos.x, dz = w.z - e.pos.z, l = Math.hypot(dx, dz);
      if (e.waitT > 0) { e.waitT -= dt; turnToward(e, e.yaw + Math.sin(e.waitT * 2.2) * 0.6, 1.4, dt); }
      else if (l < 0.6) { e.wi ^= 1; e.waitT = rand(1.2, 2.4); }
      else { sp = T.speed; turnToward(e, Math.atan2(dx, dz), 3, dt); groundMove(e, dx / l * sp, dz / l * sp, dt); }
    }
    robotWalk(e, sp, dt, false); e.armR.rotation.set(-0.35 - Math.sin(e.walk || 0) * 0.1, 0, -0.1);
    return;
  }
  const sd = stopDist(e), d = shipDir(e, dist, 22);
  e.swingCd = (e.swingCd || 0) - dt;
  let sp = dist > sd + 0.15 ? 5.8 : 0;
  if (e.swingT > 0) {
    e.swingT -= dt; sp *= 0.3; const u = 1 - e.swingT / 0.5;
    e.armR.rotation.set(u < 0.5 ? -0.6 - u * 4.6 : -2.9 + (u - 0.5) * 4.4, 0, -0.15); // up over its head, then down hard
    if (!e.hitDone && u >= 0.62) {
      e.hitDone = true; Sound.swoosh(e.pos);
      if (dist < sd + 1.2 && Math.abs(player.pos.y - e.pos.y) < 1.8) { player.hurt(T.dmg * e.dmgMul, e.pos, 'body'); Sound.batHit(e.pos); player.vel.x += _to.x / dist * 4; player.vel.z += _to.z / dist * 4; }
    }
  } else if (dist < sd + 0.8 && e.swingCd <= 0) { e.swingT = 0.5; e.swingCd = 1.15; e.hitDone = false; }
  turnToward(e, dist < 10 ? faceYaw : Math.atan2(d.x, d.z), 7, dt);
  e.vel.multiplyScalar(Math.exp(-dt * 6));
  groundMove(e, d.x * sp + e.vel.x, d.z * sp + e.vel.z, dt);
  robotWalk(e, sp, dt, false);
  if (!(e.swingT > 0)) e.armR.rotation.set(-0.95, 0, -0.15); // baton up and ready
}
/* ---------- drone A: drifts about the hall; once it has seen you it hangs over you, slides about and shoots small bolts ---------- */
function droneAAI(e, dt, dist, faceYaw) {
  const T = e.T; e.spin += dt;
  for (const ro of e.rotors) ro.rotation.y += dt * 42;
  const ceil = (World.style.ship ? shipCeil(e.pos.x, e.pos.z) : 30) - 0.9;
  if (!e.alert) {
    if ((e.los && dist < T.sight) || dist < 8) { Enemies.alarm(e); callNear(e, 18); }
    else {
      e.goalT = (e.goalT || 0) - dt;
      if (!e.goal || e.goalT <= 0 || Math.hypot(e.goal.x - e.pos.x, e.goal.z - e.pos.z) < 1.5) {
        const Rm = shipRoom(e.pos.x, e.pos.z) || SHIP_ROOMS[2]; e.goalT = rand(3, 7);
        e.goal = { x: rand(Rm[0] + 3, Rm[2] - 3), z: rand(Rm[1] + 3, Rm[3] - 3), y: rand(3.5, Math.min(10, Rm[4] - 1.5)) };
      }
      const dx = e.goal.x - e.pos.x, dz = e.goal.z - e.pos.z, l = Math.hypot(dx, dz) || 1;
      if (moveXZ(e.pos, dx / l * 2.2 * dt, dz / l * 2.2 * dt, e.R, e.H, 0.8)) e.goalT = 0;
      e.pos.y += (Math.min(e.goal.y, ceil) - e.pos.y) * (1 - Math.exp(-dt));
      turnToward(e, Math.atan2(dx, dz), 2, dt); e.g.rotation.x = 0.08;
      return;
    }
  }
  // 5.16: no lower than 1.8 m over the floor under it (down in the hall's pit too), no higher than 22 m
  const lo = PIT === null ? 2.4 : groundAt(e.pos.x, e.pos.y + 0.3, e.pos.z, e.R) + 1.8;
  const ty = Math.min(clamp(player.pos.y + 4 + Math.sin(e.spin * 1.3 + e.seed) * 1.2, lo, 22), ceil);
  e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.4));
  e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.4, 3); }
  let fx = _to.x / dist, fz = _to.z / dist;
  if (!e.los && flowDir(e.pos.x, e.pos.z, _fd)) { fx = _fd.x; fz = _fd.z; }
  const fwd = !e.los || dist > 15 ? 1 : dist < 8 ? -0.7 : 0, side = e.los ? 0.8 : 0;
  const mvx = (fx * fwd - fz * e.strafe * side) * T.speed, mvz = (fz * fwd + fx * e.strafe * side) * T.speed;
  e.vel.multiplyScalar(Math.exp(-dt * 3));
  if (moveXZ(e.pos, (mvx + e.vel.x) * dt, (mvz + e.vel.z) * dt, e.R, e.H, PIT === null ? 0 : 0.8)) e.strafe *= -1;
  turnToward(e, faceYaw, 4, dt); e.g.rotation.x = clamp(fwd * 0.18, -0.2, 0.2);
  e.react -= dt; if (e.los && dist < T.range && e.react <= 0) robotFire(e, dt, dist);
}
/* ---------- spider mine: buried in the floor; you come within reach and it springs up, scuttles at you and goes off (100).
   one bullet sets it off too ---------- */
function mineLegs(e, dt, sp) {
  e.walk = (e.walk || 0) + dt * (4 + sp * 3);
  const up = e.bs === 'hidden' || e.bs === 'arm' || e.bs === 'fall' ? 0 : 1;
  e.cl.forEach((p, i) => { p.rotation.z = up ? -0.15 + Math.sin(e.walk + i * 1.7) * 0.35 * Math.min(1, sp / 4) : -0.75; });
  e.body.position.y = up ? Math.abs(Math.sin(e.walk * 2)) * 0.03 : 0;
}
function mineAI(e, dt, dist) {
  const T = e.T;
  if (e.bs === 'fall') { // thrown out by the boss: arcing down to the floor
    e.vy -= 18 * dt; e.pos.x += e.vel.x * dt; e.pos.z += e.vel.z * dt; e.pos.y += e.vy * dt;
    const gy = groundAt(e.pos.x, e.pos.y + 0.3, e.pos.z, 0.2);
    if (e.pos.y <= gy && e.vy < 0) { e.pos.y = gy; e.baseY = gy; e.bs = 'arm'; e.bt = 1.0; e.vel.set(0, 0, 0); FX.puff(e.pos, 2, 0.3, 0.3); Sound.metal(e.pos); }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'arm') { // landed: blinking while it arms itself
    e.bt -= dt; e.light.material.color.setHex(Math.sin(e.bt * 30) > 0 ? 0xff3020 : 0x401010);
    if (e.bt <= 0) { if (dist < 9) { e.bs = 'wake'; e.bt = 0.3; Sound.chirp(e.pos); } else { e.bs = 'hidden'; e.light.material.color.setHex(0x401010); } }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'hidden') {
    e.pos.y = e.baseY - 0.16;
    if (dist < T.sight && (e.los || dist < 3.5) && Math.abs(player.pos.y - e.baseY) < 2.5) { e.bs = 'wake'; e.bt = 0.3; Sound.chirp(e.pos); }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'wake') {
    e.bt -= dt; e.pos.y = e.baseY - 0.16 * Math.max(0, e.bt / 0.3); e.light.material.color.setHex(0xff2a1a);
    if (e.bt <= 0) { e.bs = 'run'; e.bt = 7; e.alert = true; }
    turnToward(e, Math.atan2(_to.x, _to.z), 10, dt); mineLegs(e, dt, 2); return;
  }
  // running at you
  e.bt -= dt;
  const d = shipDir(e, dist, 12);
  groundMove(e, d.x * T.speed, d.z * T.speed, dt); turnToward(e, Math.atan2(d.x, d.z), 12, dt);
  e.light.material.color.setHex((e.bt * 8) % 1 < 0.5 ? 0xff2a1a : 0x601010);
  mineLegs(e, dt, T.speed);
  if ((dist < 1.25 && Math.abs(player.pos.y - e.pos.y) < 1.6) || e.bt <= 0) Enemies.detonate(e);
}
/* ---------- the gold commander drone, a golden bee: wakes the whole corridor when it sees you, shoots its twin cannons,
   and between bursts either calls little quad drones out of its belly or winds up and rams you (160 and a hard shove) ---------- */
function gdroneDrones(e) {
  let live = 0; for (const o of Enemies.list) if (o.alive && o.fromBee) live++;
  const n = Math.min(e.rage ? 8 : 6, 18 - live); if (n <= 0) return 0;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU + rand(-0.3, 0.3), m = Enemies.spawn('droneA', e.pos.x + Math.cos(a) * 1.6, e.pos.z + Math.sin(a) * 1.6, { y: e.pos.y - 0.6, yaw: e.yaw });
    if (!m) continue; m.fromBee = true; m.alert = true; m.awake = true; m.lod = 0; m.vel.set(Math.cos(a) * 4, 0, Math.sin(a) * 4);
  }
  Game.goal += n; FX.puff({ x: e.pos.x, y: e.pos.y - 0.5, z: e.pos.z }, 6, 0.7, 0.6); Sound.spawn(e.pos);
  HUD.feed('황금꿀벌드론이 드론 ' + n + '대를 불러냈습니다', 0, 'hs');
  return n;
}
function gdroneAI(e, dt, dist, faceYaw) {
  const T = e.T; e.spin += dt;
  if (e.baseY === undefined) e.baseY = e.pos.y;
  // wings beating all the time, faster when it is roused
  if (e.wings) { const f = Math.sin(e.spin * (e.alert ? 46 : 30)); for (const W of e.wings) W.g.rotation.z = W.sx * (0.18 + f * 0.42); }
  if (e.sealed) { e.pos.y = e.baseY + Math.sin(e.spin * 1.2) * 0.15; e.g.rotation.z = Math.sin(e.spin * 0.8) * 0.03; return; } // behind its shut door: deaf and blind to you
  if (!e.alert) {
    e.pos.y = e.baseY + Math.sin(e.spin * 1.2) * 0.15; e.g.rotation.z = Math.sin(e.spin * 0.8) * 0.03;
    if ((e.los && dist < T.sight) || dist < 10) {
      Enemies.alarm(e); Sound.alarm(); let n = 0;
      for (const o of Enemies.list) if (o.robot && !o.alert && o !== e && !o.boss && o.T.mode !== 'mine' && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 75) { Enemies.alarm(o); n++; }
      HUD.feed('황금꿀벌드론이 경보를 울렸습니다 · 로봇 ' + n + '대가 몰려옵니다', 0, 'hs');
    } else return;
  }
  const Rm = SHIP_ROOMS[0];
  if (!e.rage && e.hp < e.maxHp * 0.5) { e.rage = true; HUD.feed('황금꿀벌드론이 분노했습니다 · 더 빠르고 자주 돌진합니다', 0, 'hs'); }
  // the charge: a wind-up (shaking, eyes glowing), then straight at where you stood; a wall or a hit ends it, and it hangs there a second
  if (e.dash) {
    const D = e.dash; D.t += dt;
    if (D.mode === 'wind') {
      e.pos.x += rand(-1, 1) * 0.04; e.pos.y += rand(-1, 1) * 0.03; turnToward(e, Math.atan2(D.tx - e.pos.x, D.tz - e.pos.z), 6, dt);
      if (e.beeEye) e.beeEye.emissive.setRGB(1.2 * D.t, 0.2 * D.t, 0);
      if (D.t >= 0.75) { D.mode = 'go'; D.t = 0; const dx = D.tx - e.pos.x, dy = D.ty - e.pos.y, dz = D.tz - e.pos.z, l = Math.hypot(dx, dy, dz) || 1; D.vx = dx / l; D.vy = dy / l; D.vz = dz / l; Sound.swoosh(e.pos); }
      return;
    }
    if (D.mode === 'go') {
      const sp = e.rage ? 32 : 26;
      const blocked = moveXZ(e.pos, D.vx * sp * dt, D.vz * sp * dt, e.R * 0.8, 1, 0); e.pos.y = clamp(e.pos.y + D.vy * sp * dt, 1.6, shipCeil(e.pos.x, e.pos.z) - 1.4);
      e.g.rotation.x = 0.25;
      const pdx = player.pos.x - e.pos.x, pdz = player.pos.z - e.pos.z, py = clamp(e.pos.y, player.pos.y + 0.3, player.pos.y + player.height - 0.2);
      if (!D.hit && Math.hypot(pdx, e.pos.y - py, pdz) < e.R + 0.7 && state === 'playing') {
        D.hit = true; player.hurt(220, e.pos, 'body'); Sound.thud(player.pos); Sound.metal(player.pos);
        const l = Math.hypot(pdx, pdz) || 1; player.vel.x += pdx / l * 13; player.vel.z += pdz / l * 13; player.vel.y = 4.5; player.grounded = false; player.shake = Math.max(player.shake, 0.7); buzz(160);
      }
      if (blocked || D.hit || D.t > 1.5) { D.mode = 'rest'; D.t = 0; if (blocked) { FX.sparks(e.pos, 14, [1, 0.8, 0.4], 4); Sound.thud(e.pos); player.shake = Math.max(player.shake, dist < 20 ? 0.25 : 0); } }
      return;
    }
    // resting after the charge: a sitting target
    e.g.rotation.x = lerp(e.g.rotation.x, 0, 1 - Math.exp(-dt * 4)); if (e.beeEye) e.beeEye.emissive.setRGB(0.23, 0.04, 0);
    if (D.t > 1.0) e.dash = null; else return;
  }
  e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.6, 3.2); }
  const fx = _to.x / dist, fz = _to.z / dist, fwd = !e.los ? 0.6 : dist > 16 ? 0.8 : dist < 9 ? -0.8 : 0, sp = T.speed * (e.rage ? 1.4 : 1);
  moveXZ(e.pos, (fx * fwd - fz * e.strafe * 0.9) * sp * dt, (fz * fwd + fx * e.strafe * 0.9) * sp * dt, e.R, 1, 0);
  e.pos.x = clamp(e.pos.x, Rm[0] + 2.2, Rm[2] + 5); e.pos.z = clamp(e.pos.z, Rm[1] + 2.2, Rm[3] - 2.2);
  if (e.pos.x > Rm[2] - 1) e.pos.z = clamp(e.pos.z, -11, -4); // only out into the corridor mouth, not through its walls
  const ty = clamp(player.pos.y + 3.2 + Math.sin(e.spin * 0.9) * 0.6, 2.8, (e.pos.x > Rm[2] ? 6 : Rm[4]) - 1.7);
  e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.5));
  turnToward(e, faceYaw, 3, dt); e.g.rotation.z = lerp(e.g.rotation.z, -e.strafe * 0.1, 1 - Math.exp(-dt * 3));
  e.react -= dt;
  if (e.los && dist < T.range && e.react <= 0) { const b0 = e.burst; robotFire(e, dt * (e.rage ? 1.6 : 1), dist); if (e.burst !== b0) e.muzzle.x = -e.muzzle.x; }
  e.skillT = (e.skillT === undefined ? 4 : e.skillT) - dt;
  if (e.skillT <= 0 && dist < 45) {
    e.skillT = e.rage ? rand(2.6, 3.4) : rand(4, 5.5);
    const want = e.lastSkill === 'call' || !e.los ? 'dash' : e.lastSkill === 'dash' ? 'call' : Math.random() < 0.5 ? 'call' : 'dash';
    if (want === 'call' && gdroneDrones(e)) e.lastSkill = 'call';
    else if (e.los && dist > 4) { e.lastSkill = 'dash'; e.dash = { mode: 'wind', t: 0, tx: player.pos.x, ty: player.pos.y + 1.2, tz: player.pos.z, hit: false }; Sound.charge(e.pos, 0.75); }
  }
}

/* ---------- the boss drone ---------- */
const BPH = [
  { sp: 5, y: [8, 11], dist: [16, 24], charge: 3, track: 7, rockets: 1, win: 0, mines: 5, gap: [4.2, 5.4] },
  { sp: 8, y: [6, 9.5], dist: [12, 20], charge: 2, track: 9, rockets: 10, win: 1.0, mines: 10, gap: [3.2, 4.2] },
  { sp: 12, y: [3.2, 7], dist: [8, 16], charge: 1, track: 12, rockets: 100, win: 2.5, mines: 20, gap: [2.4, 3.2] },
];
const HALL = SHIP_ROOMS[2];
const LASER_WARN = 3; // seconds of red eye before the aim starts: the shot comes 6, 5 and 4 s after the eye turns red
function bossEye(e, out) { const s = e.shells[e.k ? e.k.phase : 0]; e.g.updateMatrixWorld(true); return out.setFromMatrixPosition(s.eye.matrixWorld); }
/* closest distance between segment a-b and segment c-d */
function segDist(a, b, c, d) {
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z, vx = d.x - c.x, vy = d.y - c.y, vz = d.z - c.z, wx = a.x - c.x, wy = a.y - c.y, wz = a.z - c.z;
  const A = ux * ux + uy * uy + uz * uz, Bb = ux * vx + uy * vy + uz * vz, Cc = vx * vx + vy * vy + vz * vz, D = ux * wx + uy * wy + uz * wz, E = vx * wx + vy * wy + vz * wz;
  const den = A * Cc - Bb * Bb; let s = den > 1e-9 ? clamp((Bb * E - Cc * D) / den, 0, 1) : 0, t = Cc > 1e-9 ? (Bb * s + E) / Cc : 0;
  if (t < 0) { t = 0; s = A > 1e-9 ? clamp(-D / A, 0, 1) : 0; } else if (t > 1) { t = 1; s = A > 1e-9 ? clamp((Bb - D) / A, 0, 1) : 0; }
  return Math.hypot(wx + ux * s - vx * t, wy + uy * s - vy * t, wz + uz * s - vz * t);
}
function bossGuard(e, dmg) {
  const k = e.k; if (!k) return dmg;
  if (k.mode === 'shed') return 0; // the shell is coming apart: nothing gets through
  const floor = k.phase === 0 ? e.maxHp * 2 / 3 : k.phase === 1 ? e.maxHp / 3 : -Infinity;
  if (e.hp - dmg <= floor) { e.hp = floor; bossShed(e); return 0; }
  return dmg;
}
/* a third of its health gone: the outer shell blows apart and a smaller, faster drone comes out of it */
function bossShed(e) {
  const k = e.k; if (k.phase >= 2) return;
  k.mode = 'shed'; k.t = 0; k.salvo = 0; ShipFX.aimOff();
  const old = e.shells[k.phase]; k.phase++; const nw = e.shells[k.phase];
  FX.explode(e.pos, true); FX.explode({ x: e.pos.x + old.R * 0.5, y: e.pos.y, z: e.pos.z - old.R * 0.3 }, true); FX.explode({ x: e.pos.x - old.R * 0.4, y: e.pos.y + old.R * 0.4, z: e.pos.z }, true);
  FX.chunks(e.pos, 26, 0.18 * old.R, 'metal'); Sound.boom(e.pos, true); player.shake = Math.max(player.shake, 0.5);
  old.g.visible = false; nw.g.visible = true;
  e.R = nw.R; e.H = nw.R * 2; e.barY = nw.R + 0.7; e.parts = shellParts(nw.R); e.eyeMat.color.setHex(BLUE); e.eyeGlow.color.setHex(0x2f8cff);
  HUD.banner('B-3 · ' + (k.phase + 1) + '페이즈', k.phase === 2 ? '껍데기가 모두 벗겨지고 핵이 드러났습니다 · 가장 작고 빠릅니다' : '바깥 껍데기가 부서졌습니다 · 더 작고 빨라졌습니다', 2.6);
  if (k.phase === 2) Ship.hatchWait = 2.6; // and, once the banner has gone, the floor opens: drones by the dozen
  if (k.phase === 1) Ship.breakT = 1.8; // 5.19: and in the second the hall's floor breaks up and falls into the pit under it
}
function bossDropMines(e, n) {
  const live = Enemies.list.filter((o) => o.extra && o.alive).length; n = Math.min(n, 45 - live);
  for (let i = 0; i < n; i++) {
    let tx = 0, tz = 0;
    // straight down out of its belly, spreading a little round the spot under it
    let ty = 0;
    for (let tries = 0; tries < 8; tries++) { const a = rand(0, TAU), rr = rand(0.2, 1.2 + n * 0.12); tx = e.pos.x + Math.cos(a) * rr; tz = e.pos.z + Math.sin(a) * rr; ty = groundAt(tx, e.pos.y, tz, 0.2); if (shipRoom(tx, tz) && !collideAt(tx, ty + 0.05, tz, 0.4, 0.5)) break; }
    const m = Enemies.spawn('mine', e.pos.x, e.pos.z, { y: e.pos.y - e.R * 0.5, yaw: rand(0, TAU) });
    if (!m) continue;
    const T = rand(0.45, 0.75); m.extra = true; m.bs = 'fall'; m.vel.set((tx - e.pos.x) / T, 0, (tz - e.pos.z) / T); m.vy = (ty - m.pos.y + 0.5 * 18 * T * T) / T; m.baseY = ty; m.alert = true; m.awake = true; m.lod = 0;
  }
  Sound.clank(e.pos);
}
function bossFireLaser(e) {
  const k = e.k; bossEye(e, _sv); _sw.copy(k.aim).sub(_sv).normalize();
  const hit = raycastStatic(_sv.x, _sv.y, _sv.z, _sw.x, _sw.y, _sw.z, 160), L = hit ? RH.t : 160;
  _sx.copy(_sv).addScaledVector(_sw, L);
  if (hit && RH.box && RH.box.kind === 'wood' && RH.box.ref) damageCrate(RH.box.ref, 999, _sx);
  ShipFX.beam(_sv, _sx); Sound.beam(_sv); FX.sparks(_sx, 14, [1, 0.3, 0.2], 4);
  // touching the beam anywhere along its length is the end
  const a = { x: player.pos.x, y: player.pos.y + 0.2, z: player.pos.z }, b = { x: player.pos.x, y: player.pos.y + player.height, z: player.pos.z };
  if (state === 'playing' && player.invuln <= 0 && segDist(_sv, _sx, a, b) < 0.55) Game.laser(e);
}
function bossLaunch(e) {
  const k = e.k, sx = k.salvo % 2 ? 1 : -1, cy = Math.cos(e.yaw), syaw = Math.sin(e.yaw);
  _sv.set(e.pos.x + cy * sx * e.R * 0.95, e.pos.y + e.R * 0.2, e.pos.z - syaw * sx * e.R * 0.95);
  _sw.set(cy * sx * 0.7 + syaw * 0.5 + rand(-0.4, 0.4), 0.5 + rand(0, 0.6), -syaw * sx * 0.7 + cy * 0.5 + rand(-0.4, 0.4));
  Rockets.fire(_sv, _sw, 100, k.phase === 2 ? 13 : 15, 0);
  if (k.salvo % 6 === 0) Sound.rocket(e.pos);
}
function bdroneAI(e, dt, dist, faceYaw) {
  const k = e.k || (e.k = { phase: 0, mode: 'idle', t: 0, cd: 2.5, last: '', goal: null, goalT: 0, v: new THREE.Vector3(), aim: new THREE.Vector3(), salvo: 0, salvoT: 0, gapT: 0, wake: 0 });
  if (!e.guard) e.guard = bossGuard;
  const P = BPH[k.phase]; k.t += dt;
  e.spin += dt;
  if (k.mode === 'idle') {
    e.pos.y += Math.sin(e.spin * 1.1) * dt * 0.3;
    if (e.sealed) { e.yaw += dt * 0.25; e.g.rotation.y = e.yaw; return; } // behind its shut door: turning slowly, aware of nothing
    if ((e.los && dist < 45) || e.alert || dist < 20) { k.mode = 'move'; k.cd = 2; e.alert = true; Sound.alarm(); }
    else { turnToward(e, faceYaw, 0.6, dt); return; }
  }
  // where to be: round you at its own distance and height, inside the hall, clear of the reactor
  if (k.mode !== 'shed') {
    k.goalT -= dt;
    if (!k.goal || k.goalT <= 0) {
      // 5.16: a spot at its distance from you that is inside the hall (with you by a wall, a random one is often outside it, and clamped
      // back it would sit right over you); a few tries, then the last one, clamped
      let gx = 0, gz = 0;
      for (let t = 0; t < 10; t++) { const a = rand(0, TAU), rr = rand(P.dist[0], P.dist[1]); gx = player.pos.x + Math.cos(a) * rr; gz = player.pos.z + Math.sin(a) * rr;
        if (gx > HALL[0] + e.R + 2 && gx < HALL[2] - e.R - 2 && gz > HALL[1] + e.R + 2 && gz < HALL[3] - e.R - 2) break; }
      k.goal = { x: gx, y: Math.min(player.pos.y, 6) + rand(P.y[0], P.y[1]), z: gz }; k.goalT = rand(1.6, 3);
    }
    const dx = k.goal.x - e.pos.x, dy = k.goal.y - e.pos.y, dz = k.goal.z - e.pos.z, l = Math.hypot(dx, dy, dz), sp = P.sp * (k.mode === 'charge' ? 0.4 : 1);
    _sv.set(l > 0.4 ? dx / l * sp : 0, l > 0.4 ? dy / l * sp : 0, l > 0.4 ? dz / l * sp : 0);
    k.v.lerp(_sv, 1 - Math.exp(-dt * 2)); e.pos.addScaledVector(k.v, dt);
  } else { e.pos.y += Math.sin(k.t * 9) * dt * 0.6; }
  const R = e.R;
  e.pos.x = clamp(e.pos.x, HALL[0] + R + 0.6, HALL[2] - R - 0.6); e.pos.z = clamp(e.pos.z, HALL[1] + R + 0.6, HALL[3] - R - 0.6);
  e.pos.y = clamp(e.pos.y, groundAt(e.pos.x, e.pos.y, e.pos.z, R * 0.5) + R + 0.4, shipCeil(e.pos.x, e.pos.z) - R);
  const rx = e.pos.x - REACTOR.x, rz = e.pos.z - REACTOR.z, rd = Math.hypot(rx, rz), need = REACTOR.r + R + 0.8;
  if (rd < need) { e.pos.x = REACTOR.x + rx / (rd || 1) * need; e.pos.z = REACTOR.z + rz / (rd || 1) * need; }
  for (const [px, pz, ph, , ptop] of HALL_PILLARS) { if (e.pos.y - R > ptop + 0.5) continue; // over the top of an inner pillar is open
    const qx = e.pos.x - px, qz = e.pos.z - pz, q = Math.hypot(qx, qz), nd = ph * 1.42 + R + 0.3; if (q < nd) { e.pos.x = px + qx / (q || 1) * nd; e.pos.z = pz + qz / (q || 1) * nd; } }
  // face you, eye first
  turnToward(e, faceYaw, k.phase === 2 ? 6 : 3, dt);
  e.g.rotation.x = lerp(e.g.rotation.x, clamp(Math.atan2(e.pos.y - (player.pos.y + 1.2), dist), -0.6, 1.1), 1 - Math.exp(-dt * 4));
  if (k.phase === 2) e.g.rotation.z = Math.sin(e.spin * 3) * 0.12;
  if (k.mode === 'shed') { if (k.t >= 1.4) { k.mode = 'move'; k.cd = 1.2; } return; }
  // rockets already ordered keep leaving while it flies
  if (k.salvo > 0) { k.salvoT -= dt; while (k.salvo > 0 && k.salvoT <= 0) { k.salvo--; k.salvoT += k.gapT; bossLaunch(e); } }
  if (k.mode === 'warn') { // the eye is red and it keeps moving; in three seconds the red line comes out, with the siren
    if (k.t >= LASER_WARN) { k.mode = 'charge'; k.t = 0; k.aim.set(player.pos.x, player.pos.y + 1.1, player.pos.z); Sound.siren2(P.charge + 0.25); }
    return;
  }
  if (k.mode === 'charge') {
    // the eye is red; the aim drifts after you and holds still for the last quarter second
    const left = P.charge - k.t;
    if (left > 0.25) { _sw.set(player.pos.x, player.pos.y + 1.1, player.pos.z).sub(k.aim); const L = _sw.length(), step = P.track * dt; if (L > step) _sw.multiplyScalar(step / L); k.aim.add(_sw); }
    bossEye(e, _sv); _sw.copy(k.aim).sub(_sv).normalize();
    const hit = raycastStatic(_sv.x, _sv.y, _sv.z, _sw.x, _sw.y, _sw.z, 160); _sx.copy(_sv).addScaledVector(_sw, hit ? RH.t : 160);
    ShipFX.aim(_sv, _sx, left);
    if (k.t >= P.charge) { ShipFX.aimOff(); bossFireLaser(e); k.mode = 'cool'; k.t = 0; }
    return;
  }
  if (k.mode === 'cool') { if (k.t > 0.35) { e.eyeMat.color.setHex(BLUE); e.eyeGlow.color.setHex(0x2f8cff); k.mode = 'move'; } return; }
  k.cd -= dt;
  if (k.cd <= 0) {
    const opts = ['laser', 'rockets', 'mines'].filter((s) => s !== k.last && (s === 'mines' || e.los));
    const s = opts.length ? pick(opts) : 'mines'; k.last = s;
    if (s === 'laser') { k.mode = 'warn'; k.t = 0; e.eyeMat.color.setHex(RED); e.eyeGlow.color.setHex(0xff3a2a); } // red eye first: 3 s, then the aim
    else if (s === 'rockets') { k.salvo = P.rockets; k.gapT = P.rockets > 1 ? P.win / P.rockets : 0; k.salvoT = 0; Sound.rocket(e.pos); }
    else bossDropMines(e, P.mines);
    k.cd = rand(P.gap[0], P.gap[1]) + (s === 'laser' ? P.charge + LASER_WARN : 0);
  }
}
function updateShipBot(e, dt, dist, faceYaw) {
  const m = e.T.mode;
  if (m === 'cctv') cctvAI(e, dt, dist, faceYaw);
  else if (m === 'patrol') patrolAI(e, dt, dist, faceYaw);
  else if (m === 'droneA') droneAAI(e, dt, dist, faceYaw);
  else if (m === 'mine') mineAI(e, dt, dist);
  else if (m === 'gdrone') gdroneAI(e, dt, dist, faceYaw);
  else bdroneAI(e, dt, dist, faceYaw);
}

/* ---------- homing rockets: drawn as one instanced mesh; each one turns towards you a little at a time while it can see you
   (behind a wall it loses you and flies straight on into the wall) and bursts on a wall, the floor, or you ---------- */
const Rockets = (() => {
  const MAX = 220, list = [], o = new THREE.Object3D(), zero = new THREE.Matrix4().makeScale(0, 0, 0), _d = new THREE.Vector3(), _v = new THREE.Vector3(), _t = new THREE.Vector3();
  let im = null;
  function ensure() {
    if (im) return;
    const geo = new THREE.CylinderGeometry(0.07, 0.1, 0.6, 8); geo.rotateX(Math.PI / 2);
    im = new THREE.InstancedMesh(geo, new THREE.MeshStandardMaterial({ color: 0xc8ced8, metalness: 0.6, roughness: 0.35, emissive: 0x331000 }), MAX);
    im.frustumCulled = false; for (let i = 0; i < MAX; i++) im.setMatrixAt(i, zero); scene.add(im);
  }
  function fire(from, dir, dmg, speed, delay) {
    ensure(); if (list.length >= MAX) return;
    list.push({ p: from.clone(), v: dir.clone().normalize().multiplyScalar(speed || 15), dmg, life: 8, trail: 0, wait: delay || 0, seeT: Math.random() * 0.15, sees: true });
  }
  function blast(c, dmg, loud) {
    FX.explode(c, false); if (loud) Sound.boom(c, false);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.4 - d * 0.03, 0, 0.4));
    if (d < 3 && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 1.2, player.pos.z))) player.hurt(d < 1.2 ? dmg : dmg * (1 - (d - 1.2) / 1.8 * 0.7), c, 'body');
  }
  function update(dt) {
    if (!im) return;
    const tx = player.pos.x, ty = player.pos.y + 1.0, tz = player.pos.z; let loud = 0;
    for (let i = list.length - 1; i >= 0; i--) {
      const R = list[i];
      if (R.wait > 0) { R.wait -= dt; continue; }
      R.life -= dt;
      _d.set(tx - R.p.x, ty - R.p.y, tz - R.p.z); const dl = _d.length() || 1; _d.divideScalar(dl);
      R.seeT -= dt; if (R.seeT <= 0) { R.seeT = 0.15; R.sees = lineOfSight(R.p, _t.set(tx, ty, tz)); }
      const sp = R.v.length(); _v.copy(R.v).divideScalar(sp); if (R.sees) _v.lerp(_d, Math.min(1, 1.5 * dt)).normalize(); R.v.copy(_v).multiplyScalar(sp);
      const step = sp * dt, hit = raycastStatic(R.p.x, R.p.y, R.p.z, _v.x, _v.y, _v.z, step);
      R.p.addScaledVector(_v, hit ? RH.t : step);
      if (hit || dl < 1.0 || R.life <= 0 || R.p.y < floorY(R.p.x, R.p.z) + 0.05) { blast(R.p, R.dmg, loud++ < 4); list.splice(i, 1); continue; }
      R.trail -= dt; if (R.trail <= 0) { R.trail = list.length > 40 ? 0.1 : 0.04; FX.glow.emit({ x: R.p.x, y: R.p.y, z: R.p.z, vx: 0, vy: 0, vz: 0, max: 0.35, s0: 0.28, s1: 0.06, r: 1, g: 0.55, b: 0.25, a: 0.8, grav: 0, drag: 0 }); }
    }
    let n = 0;
    for (const R of list) { if (R.wait > 0) continue; o.position.copy(R.p); o.lookAt(R.p.x + R.v.x, R.p.y + R.v.y, R.p.z + R.v.z); o.updateMatrix(); im.setMatrixAt(n++, o.matrix); }
    for (let i = n; i < MAX; i++) im.setMatrixAt(i, zero);
    im.instanceMatrix.needsUpdate = true;
  }
  function clear() { list.length = 0; if (im) { for (let i = 0; i < MAX; i++) im.setMatrixAt(i, zero); im.instanceMatrix.needsUpdate = true; } }
  return { fire, update, clear, get count() { return list.length; } };
})();

/* ---------- the boss's laser (a thin red aiming line, then the beam) and the spider mines' blasts ---------- */
const ShipFX = (() => {
  const queue = [];
  let aimLine = null, beam = null, core = null, beamT = 0;
  const aimMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false });
  const beamMat = new THREE.MeshBasicMaterial({ color: 0xff3a2a, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false });
  const coreMat = new THREE.MeshBasicMaterial({ color: 0xffd8d0, transparent: true, opacity: 1, blending: THREE.AdditiveBlending, depthWrite: false });
  const _m = new THREE.Vector3(), _q = new THREE.Vector3();
  function make() {
    if (aimLine) return;
    aimLine = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.03, 1), aimMat); aimLine.frustumCulled = false; aimLine.visible = false; scene.add(aimLine);
    const g = new THREE.CylinderGeometry(1, 1, 1, 10, 1, true); g.rotateX(Math.PI / 2);
    beam = new THREE.Mesh(g, beamMat); beam.frustumCulled = false; beam.visible = false; scene.add(beam);
    core = new THREE.Mesh(g, coreMat); core.frustumCulled = false; core.visible = false; scene.add(core);
  }
  function lay(m, a, b, w) { _m.copy(a).add(b).multiplyScalar(0.5); m.position.copy(_m); m.lookAt(b); m.scale.set(w, w, a.distanceTo(b)); }
  function aim(a, b, left) { make(); aimLine.visible = true; lay(aimLine, a, b, 1 + (left < 0.25 ? 2 : 0)); aimMat.opacity = left < 0.25 ? 1 : 0.45 + 0.3 * Math.sin(time * 30); }
  function aimOff() { if (aimLine) aimLine.visible = false; }
  function fireBeam(a, b) { make(); beamT = 0.4; beam.visible = core.visible = true; lay(beam, a, b, 0.28); lay(core, a, b, 0.09); }
  function mineBlast(c, delay) { queue.push({ x: c.x, y: c.y + 0.25, z: c.z, t: delay || 0 }); }
  function blast(c) {
    FX.explode(c, false); Sound.boom(c, false); Enemies.noise(c, 30);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.6 - d * 0.05, 0, 0.6));
    if (d < 3.5 && state === 'playing' && lineOfSight(c, _q.set(player.pos.x, player.pos.y + 1.0, player.pos.z))) player.hurt(d < 2 ? 100 : Math.round(100 * (1 - (d - 2) / 1.5)), c, 'body');
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < 2.6) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    Enemies.splash(c, 3, 100); // other mines go off in a chain
  }
  function update(dt) {
    // drones coming up out of the hall's hatches: not among the hundred, gone with the boss
    if (Ship.hatchWait > 0 && (Ship.hatchWait -= dt) <= 0) { Ship.hatchWait = 0; if (Game.boss && Game.boss.alive) Ship.openHatches(); }
    const hq = Ship.hatchQ;
    for (let i = hq.length - 1; i >= 0; i--) { const q = hq[i]; q.t -= dt; if (q.t > 0) continue; hq.splice(i, 1);
      if (!Game.boss || !Game.boss.alive) continue;
      const m = Enemies.spawn('droneA', q.x + rand(-0.4, 0.4), q.z + rand(-0.4, 0.4), { y: (q.y || 0) + 0.3, yaw: rand(0, TAU) });
      if (m) { m.extra = true; m.alert = true; m.awake = true; m.lod = 0; FX.puff({ x: q.x, y: (q.y || 0) + 0.4, z: q.z }, 2, 0.4, 0.5); Sound.zap(m.pos, 'drone'); } }
    for (let i = queue.length - 1; i >= 0; i--) { const q = queue[i]; q.t -= dt; if (q.t <= 0) { queue.splice(i, 1); blast(q); } }
    if (beamT > 0) { beamT -= dt; const k = clamp(beamT / 0.4, 0, 1); beamMat.opacity = 0.85 * k; coreMat.opacity = k; if (beamT <= 0) beam.visible = core.visible = false; }
  }
  function clear() { queue.length = 0; beamT = 0; Ship.hatchQ.length = 0; Ship.hatchWait = 0; if (aimLine) aimLine.visible = beam.visible = core.visible = false; }
  return { aim, aimOff, beam: fireBeam, mineBlast, update, clear };
})();

/* ---------- stage 4's hundred: the boss over the hall, the gold bee alone on the bridge, cameras up the passage and along the corridor,
   patrols and little drones along the corridor, and mines in the floor of the corridor and the hall ---------- */
function populateShip(G, put, find, rand, randi, SR) {
  // the boss over the hall and the bee on the bridge, each sealed behind its door until you come through it (5.13)
  const boss = put('bdrone', { x: 106, z: 22, y: 9.5 }, Object.assign({ boss: true, yaw: -Math.PI / 2 }, BOSS[4])); if (boss) boss.sealed = true;
  const bee = put('gdrone', { x: -108, z: -7.5, y: 9.5 }, { scale: 1.25, yaw: Math.PI / 2 }); if (bee) bee.sealed = true;
  // cameras: two in the last leg from the airlock, two along the jog, two up into the corridor, twelve along the corridor's ceiling corners
  const cams = [[-43.4, 18, Math.PI / 2], [-39.9, 14.2, -Math.PI / 2], [-35, 7.45, 0], [-28, 12.55, Math.PI], [-26.1, 4, Math.PI / 2], [-22.4, 0, -Math.PI / 2]];
  for (const [x, z, yaw] of cams) put('cctv', { x, z, y: 4.05 }, { yaw });
  for (let i = 0; i < 12; i++) { const x = -86 + i * 13.3, north = i % 2 === 0; put('cctv', { x, z: north ? -12.05 : -2.95, y: 5.55 }, { yaw: north ? 0 : Math.PI }); }
  // patrols: twelve walking beats along the corridor in two lanes (none on the bridge, where the bee is alone)
  for (let i = 0; i < 12; i++) {
    const z = i % 2 ? -5.2 : -9.8, x0 = -86 + i * 12.5, x1 = Math.min(64, x0 + rand(7, 10)), e = put('patrol', { x: x0 + rand(0.5, 2), z }, { yaw: Math.PI / 2 });
    if (e) { e.wp = [{ x: x0, z }, { x: x1, z }]; e.wi = 1; e.waitT = rand(0, 2); }
  }
  // 5.14: and eight in the main hall, round the dais, sealed in with the boss: they walk their beats but notice nothing until its door opens
  for (const [x0, z0, x1, z1] of [[88, -45.5, 140, -45.5], [88, 43.3, 140, 43.3], [87, -22, 87, 18], [152, -22, 152, 18], [100, -33.2, 140, -33.2], [100, 21.2, 140, 21.2], [91, -26, 91, 10], [148.4, -26, 148.4, 10]]) {
    const e = put('patrol', { x: x0, z: z0 }, { yaw: Math.atan2(x1 - x0, z1 - z0) });
    if (e) { e.wp = [{ x: x0, z: z0 }, { x: x1, z: z1 }]; e.wi = 1; e.waitT = rand(0, 2); e.sealed = true; }
  }
  // little drones: two dozen along the corridor (none in the hall until the boss calls them up through the floor)
  for (let i = 0; i < 24; i++) put('droneA', { x: -86 + i * 6.3 + rand(-1.5, 1.5), z: rand(-11, -4), y: rand(3, 4.6) }, { yaw: rand(0, TAU) });
  // spider mines, buried: sixteen in the corridor, twenty in the hall, a few metres apart, off the reactor's dais and the hatches.
  // 5.16: in the hall only on flat floor (the walkway, a landing, the bottom of the pit), never on a flight of steps
  const mines = [];
  const flat = (x, z) => { const y = groundAt(x, 1, z, 0.05); for (const [dx, dz] of [[0.8, 0], [-0.8, 0], [0, 0.8], [0, -0.8]]) if (Math.abs(groundAt(x + dx, 1, z + dz, 0.05) - y) > 0.01) return null; return y; };
  const lay = (n, x0, x1, z0, z1) => {
    for (let i = 0, tries = 0; i < n && tries < 900; tries++) {
      const x = rand(x0, x1), z = rand(z0, z1), y = flat(x, z);
      if (y === null || collideAt(x, y + 0.05, z, 0.5, 0.6) || Math.hypot(x + 24.25, z + 2.5) < 6 || mines.some((m) => Math.hypot(m.x - x, m.z - z) < 3)) continue;
      if (x > DAIS[0][0] - 0.8 && x < DAIS[0][2] + 0.8 && z > DAIS[0][1] - 0.8 && z < DAIS[0][3] + 0.8) continue;
      if (HATCHES.some(([hx, hz]) => Math.hypot(hx - x, hz - z) < 2.2) || SHIP_DOORS.some((D) => Math.abs(D.x - x) < 4)) continue;
      const e = put('mine', { x, z, y: y - 0.16 }, { yaw: rand(0, TAU) }); if (e) { e.bs = 'hidden'; e.baseY = y; mines.push({ x, z }); i++; }
    }
  };
  lay(16, -88, 64, -11.6, -3.4);
  lay(20, HALL[0] + 1.5, HALL[2] - 1.5, HALL[1] + 1.5, HALL[3] - 1.5);
}
