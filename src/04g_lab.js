/* ============ stage 3: a sealed animal lab. ten cages open one after another while a mad scientist monkey watches from his booth ============ */
// 108 x 108 m inside the walls (2.25 times the first lab). cages line the west and east walls, the elephants and the boss sit under the booth.
// every wall of a cage is hinged at its foot and falls flat outwards when it opens, so an open cage is no obstacle at all;
// the gaps between cages are wide enough that a falling wall never cuts into a neighbour that is still shut.
const LAB_HALF = 54, LAB_CEIL = 15, LAB_FIRST = 10, LAB_STEP = 15;
/* the window in the north wall the scientist watches through: 8 m wide, from 5 m to 10 m up, his room 5 m deep behind it */
const WIN = { w: 8, y0: 5, y1: 10, depth: 5 };
const LAB_CAGES = [
  { n: 1, type: 'zebra', x: -37.5, z: 33.3, w: 11, d: 11, h: 3.6 },
  { n: 2, type: 'buffalo', x: 37.5, z: 33.3, w: 11, d: 11, h: 3.6 },
  { n: 3, type: 'hippo', x: -37.5, z: 11.1, w: 11, d: 11, h: 3.6 },
  { n: 4, type: 'rhino', x: 37.5, z: 11.1, w: 11, d: 11, h: 3.6 },
  { n: 5, type: 'cheetah', x: -37.5, z: -11.1, w: 11, d: 11, h: 3.6 },
  { n: 6, type: 'giraffe', x: 37.5, z: -11.1, w: 11, d: 11, h: 3.6, count: 3 },
  { n: 7, type: 'tiger', x: -37.5, z: -33.3, w: 11, d: 11, h: 3.6 },
  { n: 8, type: 'lionM', x: 37.5, z: -33.3, w: 11, d: 11, h: 3.6 },
  { n: 9, type: 'elephant', x: -12.45, z: -33.6, w: 15, d: 15, h: 4.2, scale: 0.9, count: 2 },
  { n: 10, type: 'gorilla', x: 14.7, z: -35.85, w: 12, d: 12, h: 6, boss: true },
];

const Lab = (() => {
  const L = { active: false, t: 0, running: false, clock: false, alarm: false, cages: [], monkey: null, beacons: [], door: null, doorOpen: 0, pressed: false };
  const metal = () => new THREE.MeshStandardMaterial({ color: 0x8d949c, roughness: 0.38, metalness: 0.75 });
  let barMat = null, kickMat = null, dispCase = null, glassMat = null;
  const hazard = () => World.keep(canvasTex(128, 32, (g, w, h) => {
    g.fillStyle = '#e3b21c'; g.fillRect(0, 0, w, h); g.fillStyle = '#16181b';
    for (let x = -h; x < w + h; x += 24) { g.beginPath(); g.moveTo(x, h); g.lineTo(x + 12, h); g.lineTo(x + 12 + h, 0); g.lineTo(x + h, 0); g.fill(); }
  }));
  /* one wall of a cage: posts, rails and bars merged, standing on its hinge line; it falls about local x, outwards (+z) */
  function panel(G, c, side) {
    const along = side === 'n' || side === 's', W = along ? c.w : c.d - 0.3, H = c.h, t = 0.16, off = (c.n % 2) * 0.15;
    const parts = [[t, H, t, -W / 2 + t / 2, H / 2, -t / 2], [t, H, t, W / 2 - t / 2, H / 2, -t / 2],
      [W, 0.14, t, 0, H - 0.07, -t / 2], [W, 0.16, t, 0, 0.08, -t / 2], [W, 0.07, 0.07, 0, H * 0.52, -t / 2]];
    for (let x = -W / 2 + 0.3 + off; x < W / 2 - 0.2; x += 0.3) parts.push([0.05, H - 0.2, 0.05, x, H / 2, -t / 2]);
    const P = new THREE.Group(), F = new THREE.Group(); P.add(F);
    const m = new THREE.Mesh(mergeBoxes(parts), barMat); m.castShadow = true; m.receiveShadow = true; F.add(m);
    const kick = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.3, 0.42), kickMat); kick.position.set(0, 0.42, 0.005); F.add(kick);
    // the boss's cage is lined with bulletproof glass (in 3-2 every cage is): nothing gets through until it is let out
    if (c.boss || L.seq) { const gl = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.3, H - 0.3), glassMat); gl.position.set(0, H / 2, -t - 0.03); F.add(gl); }
    const hy = 0.03 + (c.n % 4) * 0.012; // fallen walls of neighbours lie at slightly different heights, never in the same plane
    const hw = c.w / 2, hd = c.d / 2;
    if (side === 'n') { P.position.set(c.x, hy, c.z - hd); P.rotation.y = Math.PI; }
    else if (side === 's') { P.position.set(c.x, hy, c.z + hd); P.rotation.y = 0; }
    else if (side === 'e') { P.position.set(c.x + hw, hy, c.z); P.rotation.y = Math.PI / 2; }
    else { P.position.set(c.x - hw, hy, c.z); P.rotation.y = -Math.PI / 2; }
    G.add(P);
    const T = 0.25;
    const col = side === 'n' ? addCollider(c.x - hw, 0, c.z - hd, c.x + hw, H, c.z - hd + T, 'metal')
      : side === 's' ? addCollider(c.x - hw, 0, c.z + hd - T, c.x + hw, H, c.z + hd, 'metal')
        : side === 'e' ? addCollider(c.x + hw - T, 0, c.z - hd, c.x + hw, H, c.z + hd, 'metal')
          : addCollider(c.x - hw, 0, c.z - hd, c.x - hw + T, H, c.z + hd, 'metal');
    col.grate = true; col.cage = c; // bullets and eyes pass between the bars
    if (c.boss || L.seq) col.glass = true; // ...except where there is glass behind them: shots stop on it
    return { side, P, F, col, fallT: -1, wob: 0, W, H };
  }
  /* the countdown board hanging over each cage: number, animal, seconds */
  function display(G, c) {
    const cv = document.createElement('canvas'); cv.width = 256; cv.height = 128;
    const tex = World.keep(new THREE.CanvasTexture(cv)); tex.encoding = THREE.sRGBEncoding; tex.anisotropy = MAX_ANISO;
    const face = new THREE.MeshBasicMaterial({ map: tex, toneMapped: false });
    const s = c.boss ? 3.2 : 2.4, y = c.h + (c.boss ? 2.6 : 2.1);
    const box = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.5, s), [face, face, dispCase, dispCase, face, face]);
    box.position.set(c.x, y, c.z); G.add(box);
    const cab = new THREE.Mesh(mergeBoxes([[0.05, LAB_CEIL - y, 0.05, -s * 0.35, (LAB_CEIL - y) / 2 + s * 0.25, 0], [0.05, LAB_CEIL - y, 0.05, s * 0.35, (LAB_CEIL - y) / 2 + s * 0.25, 0]]), dispCase);
    cab.position.set(c.x, y, c.z); G.add(cab);
    c.disp = { cv, g: cv.getContext('2d'), tex, box, shown: null };
  }
  const NAMES = () => ANIMALS;
  function drawDisplay(c) {
    const D = c.disp, remain = L.clock ? Math.max(0, c.openAt - L.t) : -1, sec = Math.ceil(remain);
    const key = c.open ? (L.t - c.openedT < 4 ? 'open' : 'done') : c.held ? 'held' : remain < 0 ? 'off' : sec;
    if (D.shown === key) return; D.shown = key;
    const g = D.g, w = 256, h = 128, A = NAMES()[c.type];
    const col = c.open ? '#5ed6b0' : c.held ? '#8fb8ff' : remain < 0 ? '#3a4250' : sec <= 3 ? '#ff4b4b' : '#f2a33a';
    g.fillStyle = '#0a0d12'; g.fillRect(0, 0, w, h);
    g.strokeStyle = c.open ? 'rgba(94,214,176,0.6)' : sec <= 3 && remain >= 0 ? 'rgba(255,75,75,0.8)' : 'rgba(242,163,58,0.35)'; g.lineWidth = 6; g.strokeRect(3, 3, w - 6, h - 6);
    g.fillStyle = 'rgba(236,230,216,0.85)'; g.font = '600 20px "IBM Plex Mono", monospace'; g.textBaseline = 'top'; g.textAlign = 'left';
    g.fillText(String(c.n).padStart(2, '0'), 14, 12);
    g.textAlign = 'right'; g.font = '700 20px "IBM Plex Sans KR", sans-serif'; g.fillText(c.boss ? '보스 · ' + A.name : A.name + ' ×12', w - 14, 12);
    g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = col;
    if (key === 'open' || key === 'done') { g.font = '58px "Black Han Sans", sans-serif'; g.fillText(key === 'open' ? '열림' : '—', w / 2, 80); }
    else if (key === 'off') { g.font = '64px "Black Han Sans", sans-serif'; g.fillText('- -', w / 2, 80); }
    else if (key === 'held') { g.font = '50px "Black Han Sans", sans-serif'; g.fillText('잠김', w / 2, 66); g.font = '600 17px "IBM Plex Sans KR", sans-serif'; g.fillText('앞 우리를 비우면 열림', w / 2, 106); }
    else { g.font = '76px "Black Han Sans", sans-serif'; g.fillText(sec >= 60 ? Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0') : String(sec), w / 2, 82); }
    D.tex.needsUpdate = true;
  }
  /* the mad scientist: a chimp in a lab coat with goggles and wild white hair */
  function buildMonkey(G) {
    const B = AnimalKit.geoBox, M = AnimalKit.merge, fur = '#4a3122', skin = '#c9a183', coat = '#eef0ec';
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8 });
    const lens = new THREE.MeshBasicMaterial({ color: 0x8ff0ff, toneMapped: false });
    const g = new THREE.Group(), body = new THREE.Group(); body.position.y = 0.5; g.add(body);
    const mesh = (parent, list, m) => { const x = new THREE.Mesh(M(list), m || mat); parent.add(x); return x; };
    mesh(body, [B(0.34, 0.46, 0.26, 0, 0.26, 0, fur), B(0.4, 0.5, 0.3, 0, 0.24, 0.005, coat), B(0.42, 0.3, 0.31, 0, -0.06, 0, coat),
      B(0.12, 0.34, 0.02, 0, 0.3, 0.16, '#ffffff'), B(0.08, 0.06, 0.02, 0.1, 0.36, 0.16, '#3a6fb0')]);
    const head = new THREE.Group(); head.position.set(0, 0.62, 0.02); body.add(head);
    mesh(head, [B(0.3, 0.28, 0.27, 0, 0.1, 0, fur), B(0.23, 0.2, 0.07, 0, 0.07, 0.13, skin), B(0.15, 0.09, 0.08, 0, 0.0, 0.17, '#b48466'),
      B(0.08, 0.11, 0.04, -0.18, 0.1, 0, skin), B(0.08, 0.11, 0.04, 0.18, 0.1, 0, skin), B(0.32, 0.045, 0.3, 0, 0.14, 0, '#1d1f22'),
      B(0.05, 0.13, 0.05, -0.09, 0.3, -0.02, '#f4f4f0', [0, 0, 0.5]), B(0.05, 0.15, 0.05, 0.08, 0.31, 0.0, '#f4f4f0', [0.2, 0, -0.5]),
      B(0.05, 0.12, 0.05, 0, 0.32, -0.08, '#f4f4f0', [-0.5, 0, 0]), B(0.05, 0.11, 0.05, -0.16, 0.26, -0.04, '#f4f4f0', [0, 0, 1.0]), B(0.05, 0.11, 0.05, 0.16, 0.26, -0.04, '#f4f4f0', [0, 0, -1.0]),
      B(0.1, 0.02, 0.02, 0, -0.04, 0.2, '#2a1a12')]);
    mesh(head, [B(0.08, 0.065, 0.03, -0.065, 0.14, 0.15, '#8ff0ff'), B(0.08, 0.065, 0.03, 0.065, 0.14, 0.15, '#8ff0ff')], lens);
    const arm = (sx) => { const a = new THREE.Group(); a.rotation.order = 'YXZ'; a.position.set(sx * 0.24, 0.46, 0); body.add(a);
      mesh(a, [B(0.13, 0.3, 0.13, 0, -0.14, 0, coat), B(0.09, 0.3, 0.09, 0, -0.42, 0, fur), B(0.1, 0.1, 0.12, 0, -0.6, 0.02, skin)]); return a; };
    const armL = arm(-1), armR = arm(1);
    const leg = (sx) => { const l = new THREE.Group(); l.position.set(sx * 0.1, 0.5, 0); g.add(l); mesh(l, [B(0.12, 0.42, 0.13, 0, -0.24, 0, fur), B(0.12, 0.06, 0.2, 0, -0.48, 0.04, skin)]); return l; };
    const legL = leg(-1), legR = leg(1);
    g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
    const at = L.monkeyAt; g.scale.setScalar(1.6); g.position.set(at.x, at.y, at.z); G.add(g);
    return { g, body, head, armL, armR, legL, legR, mode: 'idle', modeT: 3, t: 0, pressAt: -1, baseY: at.y };
  }
  /* the monkey's mood: rocking about, cackling with arms up, clapping, and the big press in the cutscene */
  function animMonkey(dt, t) {
    const m = L.monkey; if (!m) return;
    m.modeT -= dt; m.t += dt;
    if (m.mode !== 'press' && m.mode !== 'panic' && m.mode !== 'reach' && m.modeT <= 0) { m.mode = pick(['idle', 'idle', 'cackle', 'clap']); m.modeT = rand(2, 4.5); }
    let bx = 0, by = 0, aL = [0, 0, 0.15], aR = [0, 0, -0.15], hx = 0, hz = 0, jump = 0;
    if (m.mode === 'idle') { const s = Math.sin(m.t * 2.2); bx = s * 0.06; hz = s * 0.12; aL = [-0.3 + s * 0.1, 0, 0.2]; aR = [-0.8, -0.6, -0.3]; hx = -0.05; }
    else if (m.mode === 'cackle') { const s = Math.sin(m.t * 18); aL = [-2.7 + s * 0.25, 0, 0.5]; aR = [-2.7 - s * 0.25, 0, -0.5]; hx = -0.35 + s * 0.08; jump = Math.abs(Math.sin(m.t * 7)) * 0.12; }
    else if (m.mode === 'clap') { const s = Math.sin(m.t * 16); aL = [-1.3, 0.9 + s * 0.35, 0]; aR = [-1.3, -0.9 - s * 0.35, 0]; hx = -0.15; jump = Math.abs(s) * 0.03; }
    else if (m.mode === 'panic') { const s = Math.sin(m.t * 24); aL = [-2.9, 0, 0.9 + s * 0.4]; aR = [-2.9, 0, -0.9 - s * 0.4]; hz = s * 0.3; jump = Math.abs(Math.sin(m.t * 10)) * 0.25; bx = Math.sin(m.t * 3) * 2.2; }
    else if (m.mode === 'press') {
      // wind up high with the right fist, then bring it down on the button
      const k = m.t - m.pressAt;
      if (k < 0) { aR = [-3.0, 0, -0.2]; aL = [-1.2, 0.5, 0.3]; hx = -0.3; jump = Math.abs(Math.sin(m.t * 9)) * 0.05; }
      else if (k < 0.12) { const e = k / 0.12; aR = [-3.0 + e * 1.85, 0, -0.2]; hx = 0.2; }
      else { aR = [-1.15, 0, -0.2]; hx = 0.25; aL = [-2.6, 0, 0.6]; if (k > 0.5) { const s = Math.sin(m.t * 18); aL = [-2.7 + s * 0.25, 0, 0.5]; aR = [-2.7 - s * 0.25, 0, -0.5]; hx = -0.35; jump = Math.abs(Math.sin(m.t * 7)) * 0.12; } }
    }
    else if (m.mode === 'reach') {
      // 3-2: a long arm out over the console, a push on the button, then a cackle
      const k = m.t;
      if (k < 0.45) { const e = k / 0.45; aR = [-1.55 * e, 0, -0.1]; aL = [-0.4, 0, 0.2]; hx = 0.25 * e; }
      else if (k < 0.62) { aR = [-1.05, 0, -0.1]; hx = 0.3; if (!m.pushed) { m.pushed = true; if (L.onPush) L.onPush(); } }
      else { const s = Math.sin(m.t * 18); aL = [-2.7 + s * 0.25, 0, 0.5]; aR = [-2.7 - s * 0.25, 0, -0.5]; hx = -0.35; jump = Math.abs(Math.sin(m.t * 7)) * 0.12; if (k > 1.8) { m.mode = 'idle'; m.modeT = 2; } }
    }
    const f = 1 - Math.exp(-dt * 14), lr = (o, v) => { o.rotation.x = lerp(o.rotation.x, v[0], f); o.rotation.y = lerp(o.rotation.y, v[1], f); o.rotation.z = lerp(o.rotation.z, v[2], f); };
    lr(m.armL, aL); lr(m.armR, aR);
    m.head.rotation.x = lerp(m.head.rotation.x, hx, f); m.head.rotation.z = lerp(m.head.rotation.z, hz, f);
    m.g.position.x = lerp(m.g.position.x, bx, f * 0.5); m.g.position.y = m.baseY + jump + by;
    m.legL.rotation.x = -jump * 2; m.legR.rotation.x = -jump * 2;
  }
  function build(G, S, R, r) {
    L.active = true; L.t = 0; L.running = false; L.clock = false; L.alarm = false; L.cages = []; L.beacons = []; L.pressed = false; L.doorOpen = 0;
    L.seq = !!S.seq; L.reach = null; L.onPush = null; L.btnT = 0; // 3-2: one cage at a time, each opened by the monkey once the one before is empty
    barMat = metal(); kickMat = new THREE.MeshStandardMaterial({ map: hazard(), roughness: 0.7, side: THREE.DoubleSide });
    kickMat.map.wrapS = THREE.RepeatWrapping; kickMat.map.repeat.set(6, 1);
    dispCase = new THREE.MeshStandardMaterial({ color: 0x1c2026, roughness: 0.5, metalness: 0.6 });
    glassMat = new THREE.MeshStandardMaterial({ color: 0xa8dcff, transparent: true, opacity: 0.2, roughness: 0.05, metalness: 0.3, side: THREE.DoubleSide, depthWrite: false });
    const E = LAB_HALF, o = new THREE.Object3D();
    /* floor: pale lab tiles */
    const tiles = World.keep(canvasTex(512, 512, (g, w, h) => {
      g.fillStyle = '#b8bfc5'; g.fillRect(0, 0, w, h);
      speckle(g, w, h, 6000, ['#c0c7cd', '#aeb5bb', '#c6ccd1', '#a8afb5'], 2);
      for (let i = 0; i < 10; i++) { g.fillStyle = 'rgba(70,80,90,' + rand(0.04, 0.1) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(20, 70), rand(10, 40), rand(0, 3), 0, TAU); g.fill(); }
      g.fillStyle = '#8a9299'; for (let k = 0; k <= 4; k++) { g.fillRect(k * 128 - 2, 0, 4, h); g.fillRect(0, k * 128 - 2, w, 4); }
    }, 27, 27));
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(2 * E, 2 * E), new THREE.MeshStandardMaterial({ map: tiles, roughness: 0.55, metalness: 0.05 }));
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; G.add(floor);
    /* walls: white panels, a teal band, dark skirting; big stencilled signs */
    const wallTex = World.keep(canvasTex(512, 256, (g, w, h) => {
      g.fillStyle = '#d3d9de'; g.fillRect(0, 0, w, h);
      speckle(g, w, h, 2500, ['#dbe0e4', '#cbd1d6'], 2);
      g.fillStyle = '#a9b1b8'; for (let x = 0; x <= w; x += 128) g.fillRect(x - 1.5, 0, 3, h); g.fillRect(0, 84, w, 3);
      g.fillStyle = '#2f7f86'; g.fillRect(0, 150, w, 22); g.fillStyle = '#27323a'; g.fillRect(0, h - 26, w, 26);
      g.fillStyle = '#9aa3aa'; for (let x = 32; x < w; x += 128) for (let k = 0; k < 6; k++) g.fillRect(x + k * 9, 40, 5, 24);
    }));
    wallTex.wrapS = wallTex.wrapT = THREE.RepeatWrapping; wallTex.repeat.set(13.5, 1);
    const wallMat = new THREE.MeshStandardMaterial({ map: wallTex, roughness: 0.7 });
    [[-E - 1, 0, 2, 2 * E + 4], [E + 1, 0, 2, 2 * E + 4]].forEach(([x, z, sx, sz]) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(sx, LAB_CEIL, sz), wallMat); m.position.set(x, LAB_CEIL / 2, z); m.receiveShadow = true; G.add(m);
      addCollider(x - sx / 2, 0, z - sz / 2, x + sx / 2, 40, z + sz / 2, 'concrete');
    });
    // the north wall is flat, with a square window in it: the scientist's control room is behind it (see below).
    // four pieces round the opening, each with the wall texture cut to match, so the panels and the teal band carry straight across
    {
      const WX = WIN.w / 2, W0 = 2 * E + 4, piece = (x0, x1, y0, y1) => {
        const t = World.keep(wallTex.clone()); t.needsUpdate = true; t.repeat.set((x1 - x0) / W0 * 13.5, (y1 - y0) / LAB_CEIL); t.offset.set((x0 + W0 / 2) / W0 * 13.5, y0 / LAB_CEIL);
        const m = new THREE.Mesh(new THREE.BoxGeometry(x1 - x0, y1 - y0, 2), new THREE.MeshStandardMaterial({ map: t, roughness: 0.7 }));
        m.position.set((x0 + x1) / 2, (y0 + y1) / 2, -E - 1); m.receiveShadow = true; G.add(m);
        addCollider(x0, y0, -E - 2, x1, y1 >= LAB_CEIL ? 40 : y1, -E, 'concrete');
      };
      piece(-W0 / 2, -WX, 0, LAB_CEIL); piece(WX, W0 / 2, 0, LAB_CEIL); piece(-WX, WX, 0, WIN.y0); piece(-WX, WX, WIN.y1, LAB_CEIL);
    }
    // the south wall has the doorway in it: two long pieces and a lintel, and a short bright corridor behind the door
    const DW = 4.2, side = World.keep(wallTex.clone()); side.needsUpdate = true; side.repeat.set(6, 1);
    const top = World.keep(wallTex.clone()); top.needsUpdate = true; top.repeat.set(1, 8 / LAB_CEIL); top.offset.set(0, 7 / LAB_CEIL);
    const sideMat = new THREE.MeshStandardMaterial({ map: side, roughness: 0.7 }), topWallMat = new THREE.MeshStandardMaterial({ map: top, roughness: 0.7 });
    for (const sx of [-1, 1]) {
      const w = E + 2 - DW, m = new THREE.Mesh(new THREE.BoxGeometry(w, LAB_CEIL, 2), sideMat); m.position.set(sx * (DW + w / 2), LAB_CEIL / 2, E + 1); m.receiveShadow = true; G.add(m);
      addCollider(sx > 0 ? DW : -E - 2, 0, E, sx > 0 ? E + 2 : -DW, 40, E + 2, 'concrete');
    }
    const lintel = new THREE.Mesh(new THREE.BoxGeometry(2 * DW, LAB_CEIL - 7, 2), topWallMat); lintel.position.set(0, 7 + (LAB_CEIL - 7) / 2, E + 1); G.add(lintel);
    addCollider(-DW, 7, E, DW, 40, E + 2, 'concrete'); addCollider(-DW, 0, E - 0.4, DW, 7, E + 2, 'metal'); // the door: shut for good while you are inside
    const corr = new THREE.MeshStandardMaterial({ color: 0x4a525a, roughness: 0.7 });
    const cor = new THREE.Mesh(mergeBoxes([[0.4, 7, 13, -DW - 0.2, 3.5, E + 6.5], [0.4, 7, 13, DW + 0.2, 3.5, E + 6.5], [2 * DW + 0.8, 0.4, 13, 0, 7.2, E + 6.5], [2 * DW, 0.1, 13, 0, -0.04, E + 6.5]]), corr); G.add(cor);
    const day = new THREE.Mesh(new THREE.PlaneGeometry(2 * DW, 7), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.2, 2.2, 2.1), toneMapped: false }));
    day.position.set(0, 3.5, E + 12.5); day.rotation.y = Math.PI; G.add(day);
    const sign = (text, sub, w, h) => World.keep(canvasTex(512, 160, (g, cw, ch) => {
      g.fillStyle = 'rgba(0,0,0,0)'; g.clearRect(0, 0, cw, ch); g.fillStyle = 'rgba(39,50,58,0.92)'; g.font = '92px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(text, cw / 2, 66);
      g.font = '600 26px "IBM Plex Mono", monospace'; g.fillStyle = 'rgba(47,127,134,0.95)'; g.fillText(sub, cw / 2, 134);
    }));
    const signMat = (t) => new THREE.MeshStandardMaterial({ map: t, transparent: true, roughness: 0.8, depthWrite: false });
    const s1 = new THREE.Mesh(new THREE.PlaneGeometry(16, 5), signMat(sign('격리동 B-07', 'ANIMAL CONTAINMENT · DO NOT OPEN')));
    s1.position.set(-E + 0.02, 9.5, 0); s1.rotation.y = Math.PI / 2; G.add(s1);
    const s2 = s1.clone(); s2.position.set(E - 0.02, 9.5, 0); s2.rotation.y = -Math.PI / 2; G.add(s2);
    const s3 = new THREE.Mesh(new THREE.PlaneGeometry(14, 4.4), signMat(sign('출입 통제', 'BIOLAB 07 · SEALED')));
    s3.position.set(0, 9.8, E - 0.02); s3.rotation.y = Math.PI; G.add(s3);
    /* ceiling, trusses, light panels */
    const ceil = new THREE.Mesh(new THREE.PlaneGeometry(2 * E, 2 * E), new THREE.MeshStandardMaterial({ color: 0x2b3038, roughness: 0.9 }));
    ceil.rotation.x = Math.PI / 2; ceil.position.y = LAB_CEIL; G.add(ceil);
    const truss = []; for (let x = -45; x <= 45; x += 10) truss.push([0.4, 0.7, 2 * E, x, LAB_CEIL - 0.6, 0]);
    for (let z = -40.5; z <= 40.5; z += 27) truss.push([2 * E, 0.3, 0.3, 0, LAB_CEIL - 1.0, z]);
    const tm = new THREE.Mesh(mergeBoxes(truss), new THREE.MeshStandardMaterial({ color: 0x4a5058, roughness: 0.6, metalness: 0.5 })); G.add(tm);
    const panelMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(1.6, 1.7, 1.8), toneMapped: false });
    const lightsIM = new THREE.InstancedMesh(new THREE.BoxGeometry(4.2, 0.12, 1.4), panelMat, 36);
    let li = 0;
    for (const x of [-45, -27, -9, 9, 27, 45]) for (const z of [-45, -27, -9, 9, 27, 45]) {
      o.position.set(x, LAB_CEIL - 1.25, z); o.rotation.set(0, 0, 0); o.updateMatrix(); lightsIM.setMatrixAt(li++, o.matrix);
      World.lamps.push({ x, y: LAB_CEIL - 1.6, z, d: 0 });
    }
    lightsIM.frustumCulled = false; G.add(lightsIM);
    /* red alarm beacons on the walls: dark until the button is pressed */
    const beaconMat = new THREE.MeshBasicMaterial({ color: 0x401010, toneMapped: false });
    const glowMat = new THREE.SpriteMaterial({ map: World.keep(glowTex('rgba(255,60,50,0.95)', 'rgba(255,30,20,0.3)')), color: 0xffffff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false });
    [[-E + 0.3, 6, -27, 1], [-E + 0.3, 6, 27, 1], [E - 0.3, 6, -27, -1], [E - 0.3, 6, 27, -1], [-21, 6, -E + 0.3, 0], [21, 6, -E + 0.3, 0], [-15, 7, E - 0.3, 0], [15, 7, E - 0.3, 0],
      [-E + 0.3, 6, 0, 1], [E - 0.3, 6, 0, -1]].forEach(([x, y, z]) => {
      const b = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.32, 0.5, 12), beaconMat.clone()); b.position.set(x, y, z); G.add(b);
      const s = new THREE.Sprite(glowMat.clone()); s.position.set(x, y, z); s.scale.setScalar(4); s.visible = false; G.add(s);
      L.beacons.push({ b, s });
    });
    /* the sealed entrance door behind you, to the south */
    const doorTex = World.keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#5c646c'; g.fillRect(0, 0, w, h); speckle(g, w, h, 1200, ['#656d75', '#545b63'], 2);
      g.fillStyle = '#e3b21c'; for (let x = -h; x < w; x += 40) { g.beginPath(); g.moveTo(x, h); g.lineTo(x + 20, h); g.lineTo(x + 20 + 40, h - 40); g.lineTo(x + 40, h - 40); g.fill(); }
      g.fillStyle = '#3b4249'; g.fillRect(0, h / 2 - 3, w, 6); g.fillStyle = '#e8e2d0'; g.font = '700 30px "IBM Plex Sans KR", sans-serif'; g.textAlign = 'center'; g.fillText('비상 출입문', w / 2, 70);
    }));
    const frame = new THREE.Mesh(mergeBoxes([[10, 0.8, 0.8, 0, 7.4, 0], [0.8, 7.4, 0.8, -4.6, 3.7, 0], [0.8, 7.4, 0.8, 4.6, 3.7, 0]]), new THREE.MeshStandardMaterial({ color: 0x30363c, roughness: 0.5, metalness: 0.6 }));
    frame.position.set(0, 0, E - 0.3); G.add(frame);
    const door = new THREE.Mesh(new THREE.BoxGeometry(8.4, 7, 0.4), new THREE.MeshStandardMaterial({ map: doorTex, roughness: 0.55, metalness: 0.5 }));
    door.position.set(0, 3.5, E - 0.15); G.add(door); L.door = door;
    /* the scientist's control room behind a square window in the flat north wall: a bright little room, the monkey at his console */
    const steel = new THREE.MeshStandardMaterial({ color: 0x3a4148, roughness: 0.5, metalness: 0.6 });
    const roomMat = new THREE.MeshStandardMaterial({ color: 0x3b4652, roughness: 0.85 }), floorMat = new THREE.MeshStandardMaterial({ color: 0x252b31, roughness: 0.9 });
    const RZ = -E - 2, RD = WIN.depth, WX = WIN.w / 2, RX = WX + 1.2;
    G.add(new THREE.Mesh(mergeBoxes([[2 * RX, 0.3, RD, 0, WIN.y0 - 0.15, RZ - RD / 2], [2 * RX, 0.3, RD, 0, WIN.y1 + 0.55, RZ - RD / 2]]), floorMat));
    const room = new THREE.Mesh(mergeBoxes([[2 * RX, WIN.y1 - WIN.y0 + 0.7, 0.3, 0, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD], [0.3, WIN.y1 - WIN.y0 + 0.7, RD, -RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2],
      [0.3, WIN.y1 - WIN.y0 + 0.7, RD, RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2]]), roomMat); G.add(room);
    const lit = new THREE.MeshBasicMaterial({ color: new THREE.Color(1.5, 1.6, 1.55), toneMapped: false });
    G.add(new THREE.Mesh(mergeBoxes([[2 * RX - 1, 0.08, 0.7, 0, WIN.y1 + 0.38, RZ - 1.2], [2 * RX - 1, 0.08, 0.7, 0, WIN.y1 + 0.38, RZ - RD + 1.2]]), lit));
    // a strip of hazard paint and a steel frame round the window, on the lab side
    const fr = 0.3;
    G.add(new THREE.Mesh(mergeBoxes([[WIN.w + 2 * fr, fr, 0.3, 0, WIN.y0 - fr / 2, -E + 0.12], [WIN.w + 2 * fr, fr, 0.3, 0, WIN.y1 + fr / 2, -E + 0.12], [fr, WIN.y1 - WIN.y0, 0.3, -WX - fr / 2, (WIN.y0 + WIN.y1) / 2, -E + 0.12],
      [fr, WIN.y1 - WIN.y0, 0.3, WX + fr / 2, (WIN.y0 + WIN.y1) / 2, -E + 0.12]]), steel));
    const hz = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w + 2 * fr, 0.35), new THREE.MeshStandardMaterial({ map: hazard(), roughness: 0.7 })); hz.material.map.wrapS = THREE.RepeatWrapping; hz.material.map.repeat.set(5, 1);
    hz.position.set(0, WIN.y0 - fr - 0.2, -E + 0.03); G.add(hz);
    // console with screens and the big red button, just behind the glass
    const consoleM = new THREE.Mesh(mergeBoxes([[6, 0.8, 0.8, 0, WIN.y0 + 0.4, RZ - 0.55], [6, 0.12, 0.95, 0, WIN.y0 + 0.85, RZ - 0.55]]), steel); G.add(consoleM);
    const scr = World.keep(canvasTex(256, 128, (g, w, h) => {
      g.fillStyle = '#04140e'; g.fillRect(0, 0, w, h); g.strokeStyle = '#3bff9a'; g.lineWidth = 2; g.beginPath();
      for (let x = 0; x < w; x += 4) g.lineTo(x, 64 + Math.sin(x * 0.07) * 22 + Math.sin(x * 0.23) * 8); g.stroke();
      g.fillStyle = '#3bff9a'; g.font = '600 16px "IBM Plex Mono", monospace'; g.fillText('SUBJECT 01-10', 10, 20); g.fillText('AGGRESSION 98%', 10, 118);
    }));
    const scrMat = new THREE.MeshBasicMaterial({ map: scr, toneMapped: false });
    // a wall of monitors behind him, lighting him up from behind
    [-3.4, -1.15, 1.15, 3.4].forEach((x, i) => { const sm = new THREE.Mesh(new THREE.PlaneGeometry(2.0, 1.15), scrMat); sm.position.set(x, WIN.y0 + 2.5 + (i % 2) * 0.2, RZ - RD + 0.17); G.add(sm); });
    L.buttonY = WIN.y0 + 0.95;
    const btnBase = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.24, 0.06, 20), new THREE.MeshStandardMaterial({ color: 0xe3b21c, roughness: 0.5 })); btnBase.position.set(0.55, L.buttonY - 0.06, RZ - 0.45); G.add(btnBase);
    const btn = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.16, 0.12, 20), new THREE.MeshStandardMaterial({ color: 0xd11c1c, emissive: 0x500000, roughness: 0.35 })); btn.position.set(0.55, L.buttonY, RZ - 0.45); G.add(btn); L.button = btn;
    // the glass itself, flush with the wall: clear, faintly blue, and it stops everything
    const glass = new THREE.Mesh(new THREE.PlaneGeometry(WIN.w, WIN.y1 - WIN.y0), new THREE.MeshStandardMaterial({ color: 0xbfe6ff, transparent: true, opacity: 0.12, roughness: 0.03, metalness: 0.6, depthWrite: false }));
    glass.position.set(0, (WIN.y0 + WIN.y1) / 2, -E - 0.02); G.add(glass);
    addCollider(-WX, WIN.y0, -E - 0.3, WX, WIN.y1, -E, 'metal'); // bulletproof
    L.monkeyAt = { x: 0, y: WIN.y0, z: RZ - 1.35 };
    L.monkey = buildMonkey(G);
    /* cages, their floor markings and countdown boards */
    const strawTex = World.keep(canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#6d6a58'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 900; i++) { g.strokeStyle = pick(['rgba(190,160,80,0.55)', 'rgba(150,120,60,0.5)', 'rgba(90,80,60,0.4)']); g.lineWidth = rand(1, 2); const x = rand(0, w), y = rand(0, h), a = rand(0, TAU), l = rand(6, 18); g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke(); } }, 3, 3));
    const strawMat = new THREE.MeshStandardMaterial({ map: strawTex, roughness: 0.95 });
    const stripeMat = new THREE.MeshStandardMaterial({ map: hazard(), roughness: 0.8, transparent: false });
    stripeMat.map.wrapS = THREE.RepeatWrapping;
    const numTex = (n) => World.keep(canvasTex(128, 128, (g, w, h) => { g.clearRect(0, 0, w, h); g.fillStyle = 'rgba(227,178,28,0.85)'; g.font = '92px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(String(n).padStart(2, '0'), w / 2, h / 2 + 4); }));
    for (const def of LAB_CAGES) {
      const c = Object.assign({}, def, { open: false, openAt: LAB_FIRST + LAB_STEP * (def.n - 1), openedT: 0, panels: [], animals: [], fallDone: false, clang: false });
      if (L.seq) { if (def.n === 1) c.openAt = 5; else { c.held = true; c.openAt = Infinity; } } // 3-2: the first opens 5 s in, every other one waits for the one before it to be emptied
      const st = new THREE.Mesh(new THREE.PlaneGeometry(c.w - 0.4, c.d - 0.4), strawMat); st.rotation.x = -Math.PI / 2; st.position.set(c.x, 0.012, c.z); st.receiveShadow = true; G.add(st);
      // hazard stripes just outside the bars
      [[c.x, c.z - c.d / 2 - 0.35, c.w + 1.4, 0.6, 0], [c.x, c.z + c.d / 2 + 0.35, c.w + 1.4, 0.6, 0], [c.x - c.w / 2 - 0.35, c.z, c.d, 0.6, 1], [c.x + c.w / 2 + 0.35, c.z, c.d, 0.6, 1]].forEach(([x, z, a, b, rot]) => {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(a, b), stripeMat); m.rotation.set(-Math.PI / 2, 0, rot ? Math.PI / 2 : 0); m.position.set(x, 0.014, z); m.receiveShadow = true; G.add(m);
      });
      // the cage number painted on the floor on the side facing the middle of the room
      const nm = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 2.6), new THREE.MeshStandardMaterial({ map: numTex(c.n), transparent: true, depthWrite: false, roughness: 0.8 }));
      nm.rotation.x = -Math.PI / 2;
      if (Math.abs(c.x) > 20) { nm.position.set(c.x - Math.sign(c.x) * (c.w / 2 + 2.2), 0.016, c.z); nm.rotation.z = Math.sign(c.x) * Math.PI / 2; } else { nm.position.set(c.x, 0.016, c.z + c.d / 2 + 2.2); }
      G.add(nm);
      for (const side of ['n', 's', 'e', 'w']) c.panels.push(panel(G, c, side));
      display(G, c);
      L.cages.push(c);
    }
    /* lab furniture in the middle: cover that stays put (outside every cage's fall zone) */
    const benchMat = new THREE.MeshStandardMaterial({ color: 0xdfe3e6, roughness: 0.5, metalness: 0.2 }), topMat = new THREE.MeshStandardMaterial({ color: 0x2c3339, roughness: 0.4, metalness: 0.3 });
    const screenMat = new THREE.MeshBasicMaterial({ map: scr, toneMapped: false });
    const bench = (x, z, rot) => {
      const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = rot;
      const b = new THREE.Mesh(mergeBoxes([[4.2, 0.85, 1.2, 0, 0.425, 0]]), benchMat); b.castShadow = b.receiveShadow = true; g.add(b);
      const t = new THREE.Mesh(new THREE.BoxGeometry(4.3, 0.08, 1.3), topMat); t.position.y = 0.89; g.add(t);
      for (const sx of [-1.2, 0.3]) { const mo = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.5, 0.06), topMat); mo.position.set(sx, 1.25, -0.2); g.add(mo); const sc = new THREE.Mesh(new THREE.PlaneGeometry(0.72, 0.42), screenMat); sc.position.set(sx, 1.25, -0.165); g.add(sc); }
      const fl = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.16, 0.36, 10), new THREE.MeshStandardMaterial({ color: 0x9fe0c8, transparent: true, opacity: 0.6, roughness: 0.1 })); fl.position.set(1.4, 1.11, 0.1); g.add(fl);
      G.add(g);
      const hx = rot ? 0.6 : 2.1, hz = rot ? 2.1 : 0.6; addCollider(x - hx, 0, z - hz, x + hx, 0.93, z + hz, 'metal');
    };
    bench(-10.5, 31.5, 0); bench(10.5, 31.5, 0); bench(-15.75, 9, Math.PI / 2); bench(15.75, 9, Math.PI / 2);
    bench(-15.75, -14, Math.PI / 2); bench(15.75, -14, Math.PI / 2); bench(0, 38, 0); bench(-22, 22, 0); bench(22, 22, 0);
    // specimen tanks: glass cylinders of glowing green liquid with something curled up inside
    const tankGlass = new THREE.MeshStandardMaterial({ color: 0xbfefff, transparent: true, opacity: 0.22, roughness: 0.05, metalness: 0.3, depthWrite: false });
    const liquid = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.25, 0.9, 0.45), transparent: true, opacity: 0.5, toneMapped: false, depthWrite: false });
    const shadowy = new THREE.MeshStandardMaterial({ color: 0x1d2a1f, roughness: 0.9 });
    [[0, 18], [-9.75, -3], [9.75, -3], [0, -17], [-22, 2], [22, 2]].forEach(([x, z]) => {
      const base = new THREE.Mesh(new THREE.CylinderGeometry(1.0, 1.05, 0.5, 20), steel); base.position.set(x, 0.25, z); G.add(base);
      const cap = base.clone(); cap.position.y = 3.35; G.add(cap);
      const gl = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 2.6, 24, 1, true), tankGlass); gl.position.set(x, 1.8, z); G.add(gl);
      const lq = new THREE.Mesh(new THREE.CylinderGeometry(0.85, 0.85, 2.4, 20), liquid); lq.position.set(x, 1.72, z); G.add(lq);
      const thing = new THREE.Mesh(new THREE.SphereGeometry(0.45, 12, 8), shadowy); thing.scale.set(1, 1.3, 0.8); thing.position.set(x, 1.7, z); G.add(thing);
      addCollider(x - 1.0, 0, z - 1.0, x + 1.0, 3.6, z + 1.0, 'metal');
    });
    // server racks with blinking lights
    const rackTex = World.keep(canvasTex(128, 256, (g, w, h) => { g.fillStyle = '#15191e'; g.fillRect(0, 0, w, h);
      for (let y = 8; y < h - 8; y += 14) { g.fillStyle = '#232a31'; g.fillRect(6, y, w - 12, 11); for (let k = 0; k < 5; k++) { g.fillStyle = pick(['#3bff9a', '#2b6b4a', '#ffb340', '#3a9dff', '#1c2a24']); g.fillRect(12 + k * 7, y + 4, 4, 3); } } }));
    const rackMat = new THREE.MeshStandardMaterial({ map: rackTex, roughness: 0.6, metalness: 0.4, emissive: 0xffffff, emissiveMap: rackTex, emissiveIntensity: 0.6 });
    [[-18, -9.75], [18, -9.75], [-18, 24], [18, 24], [-26, -18], [26, -18], [0, 28]].forEach(([x, z]) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(1.2, 2.4, 2.6), rackMat); m.position.set(x, 1.2, z); m.castShadow = m.receiveShadow = true; G.add(m);
      addCollider(x - 0.6, 0, z - 1.3, x + 0.6, 2.4, z + 1.3, 'metal');
    });
    // shelves of supplies along the south wall, either side of the door
    const shelfMat = new THREE.MeshStandardMaterial({ color: 0x59626b, roughness: 0.6, metalness: 0.5 });
    [[-18, E - 0.9], [18, E - 0.9], [-32, E - 0.9], [32, E - 0.9]].forEach(([x, z]) => {
      const parts = [[6, 0.08, 1.2, 0, 0.3, 0], [6, 0.08, 1.2, 0, 1.2, 0], [6, 0.08, 1.2, 0, 2.1, 0], [0.08, 2.6, 1.2, -2.96, 1.3, 0], [0.08, 2.6, 1.2, 2.96, 1.3, 0]];
      const m = new THREE.Mesh(mergeBoxes(parts), shelfMat); m.position.set(x, 0, z); G.add(m);
      for (let k = 0; k < 9; k++) { const bx = new THREE.Mesh(new THREE.BoxGeometry(rand(0.4, 0.8), rand(0.3, 0.6), rand(0.5, 0.9)), new THREE.MeshStandardMaterial({ color: pick([0xc9b48a, 0x8fa3b8, 0xe8e8e0, 0x6f8a6a]), roughness: 0.8 }));
        bx.position.set(x + rand(-2.6, 2.6), 0.34 + Math.floor(k / 3) * 0.9 + 0.2, z + rand(-0.2, 0.2)); G.add(bx); }
      addCollider(x - 3, 0, z - 0.6, x + 3, 2.6, z + 0.6, 'metal');
    });
    /* wooden crates: in the middle and the aisles, never where a cage wall will land */
    const inFall = (x, z, m) => L.cages.some((c) => Math.abs(x - c.x) < c.w / 2 + c.h + m && Math.abs(z - c.z) < c.d / 2 + c.h + m);
    placeCrates(G, S.crates, () => [r(-E + 2, E - 2), r(-E + 2, E - 2)], (x, z) => Math.hypot(x, z - (E - 4.5)) > 6 && !inFall(x, z, 0.9) && !boxAt(x, z, 1.2, 0.05, 1.25));
    indexColliders(); buildNav();
    World.menuCam = { x: 0, z: 0, r: 40, h: 9, look: 3 };
    const map = { lab: true };
    return { start: { x: 0, z: E - 4.5, yaw: 0 }, spawns: [], map };
  }
  /* a cage opens: its walls stop blocking at once and start to fall, and the animals inside are let loose */
  function open(c) {
    c.open = true; c.openedT = L.t;
    for (const p of c.panels) { removeCollider(p.col); p.fallT = 0; p.wob = 0; }
    buildNav(); updateFlow(player.pos.x, player.pos.z);
    for (const e of c.animals) if (e.alive) { e.caged = false; e.releaseT = rand(0.15, 0.9); e.alert = true; e.awake = true; } // awake however far away you are, so they really come out
    const at = { x: c.x, y: c.h, z: c.z };
    Sound.alarm(); Sound.clank(at); buzz(60);
    const A = ANIMALS[c.type], left = c.animals.filter((e) => e.alive).length;
    if (c.boss) HUD.banner('10번 우리 열림', '보스 ' + (BOSS[3].name) + ' · 조심하세요', 2.8);
    else HUD.banner(c.n + '번 우리 열림', A.name + ' ' + left + '마리', 1.8);
    HUD.feed(c.n + '번 우리 열림 · ' + A.name + (c.boss ? '' : ' ' + left + '마리'), 0, 'hs');
  }
  function fall(c, dt) {
    let busy = false;
    for (const p of c.panels) {
      if (p.fallT >= 0 && p.fallT < 1.6) {
        p.fallT += dt; busy = true;
        const t = p.fallT, T = 0.72;
        let a = t < T ? (Math.PI / 2) * (t / T) * (t / T) : Math.PI / 2 - 0.13 * Math.abs(Math.sin((t - T) * 13)) * Math.exp(-(t - T) * 7);
        if (t >= 1.6) a = Math.PI / 2;
        p.F.rotation.x = a;
        if (t >= T && !c.clang) {
          c.clang = true; const at = { x: c.x, y: 0.4, z: c.z }; Sound.clang(at);
          const d = Math.hypot(player.pos.x - c.x, player.pos.z - c.z); if (d < 30) player.shake = Math.max(player.shake, 0.22 * (1 - d / 30));
        }
        if (t >= T && !p.dust) {
          p.dust = true;
          // dust along the far edge where the wall slapped down
          const yaw = p.P.rotation.y, ox = Math.sin(yaw), oz = Math.cos(yaw), tx = Math.cos(yaw), tz = -Math.sin(yaw);
          for (let k = -2; k <= 2; k++) FX.puff({ x: p.P.position.x + ox * p.H * 0.8 + tx * k * p.W * 0.22, y: 0.3, z: p.P.position.z + oz * p.H * 0.8 + tz * k * p.W * 0.22 }, 2, 0.75, 0.9);
        }
      } else if (p.fallT < 0 && p.wob > 0) { p.wob = Math.max(0, p.wob - dt * 2.2); p.F.rotation.x = Math.sin(L.t * 40) * 0.025 * p.wob; }
    }
    return busy;
  }
  /* an animal hit the bars from inside: that wall shakes */
  function rattle(c, x, z) {
    let best = null, bd = 1e9;
    for (const p of c.panels) { const d = Math.hypot(p.P.position.x - x, p.P.position.z - z); if (d < bd) { bd = d; best = p; } }
    if (best && best.fallT < 0) { best.wob = 1; Sound.clank({ x, y: 1, z }); }
  }
  function update(dt) {
    if (!L.active) return;
    if (!L.running) { L.running = true; L.clock = true; L.alarm = true; }
    L.t += dt;
    for (const c of L.cages) {
      if (c.held) {
        // 3-2: shut until the cage before it is empty (every animal dead or tamed); then the monkey reaches out and pushes his button
        const prev = L.cages[c.n - 2];
        if (!L.reach && prev && prev.open && !waitLeft(c)) {
          L.reach = c;
          L.onPush = () => { c.held = false; c.openAt = L.t + 0.5; L.btnT = 0.4; L.reach = null; L.onPush = null; Sound.press(); buzz(40); };
          if (L.monkey) { Lab.monkeyMode('reach'); Sound.cackle({ x: 0, y: WIN.y0 + 1.5, z: -LAB_HALF - 3 }); } else L.onPush();
          HUD.banner(prev.n + '번 우리를 비웠습니다', '원숭이 박사가 ' + c.n + '번 우리 버튼을 누릅니다 · ' + ANIMALS[c.type].name + (c.boss ? ' (보스)' : ''), 2.4);
        }
      } else if (!c.open) {
        const remain = c.openAt - L.t, s = Math.ceil(remain);
        if (s <= 3 && s >= 1 && c.lastBeep !== s) { c.lastBeep = s; Sound.beep({ x: c.x, y: c.h + 2, z: c.z }); }
        if (remain <= 0) open(c);
      }
      fall(c, dt);
      drawDisplay(c);
    }
  }
  /* things that move whatever the game state is: the monkey, the beacons, the door */
  function anim(dt, t) {
    if (!L.active) return;
    animMonkey(dt, t);
    L.beacons.forEach((B, i) => { const on = L.alarm && ((t * 1.6 + i * 0.25) % 1) < 0.5; B.s.visible = on; B.b.material.color.setHex(on ? 0xff2a20 : 0x401010); });
    if (L.door) L.door.position.y = 3.5 + L.doorOpen * 6.6;
    if (L.button) { L.btnT = Math.max(0, (L.btnT || 0) - dt); L.button.position.y = L.buttonY - (L.pressed && (!L.seq || L.btnT > 0) ? 0.05 : 0); }
    if (!L.running) for (const c of L.cages) drawDisplay(c);
  }
  /* 3-2: how many of the animals let out of the cage before this one are still loose and wild */
  function waitLeft(c) { const prev = L.cages[c.n - 2]; if (!prev) return 0; let n = 0; for (const e of prev.animals) if (e.alive && !e.tamed) n++; return n + (prev.open ? 0 : 99); }
  /* the next cage to open, for the HUD */
  function next() { let best = null; for (const c of L.cages) if (!c.open && (!best || c.openAt < best.openAt)) best = c; return best; }
  function reset() { L.active = false; L.cages = []; L.monkey = null; L.beacons = []; L.door = null; L.button = null; L.running = false; L.clock = false; L.alarm = false; }
  return Object.assign(L, { build, update, anim, open, rattle, next, reset, drawDisplay, waitLeft,
    press() { L.pressed = true; L.alarm = true; L.clock = true; for (const c of L.cages) drawDisplay(c); },
    monkeyMode(m, extra) { if (!L.monkey) return; L.monkey.mode = m; L.monkey.modeT = 99; if (m === 'press') { L.monkey.t = 0; L.monkey.pressAt = extra || 1; } if (m === 'reach') { L.monkey.t = 0; L.monkey.pushed = false; } if (m === 'idle') L.monkey.modeT = 2; } });
})();
function buildLab(G, S, R, r) { return Lab.build(G, S, R, r); }
/* the animals go in their cages: twelve of each kind in a loose grid, the boss alone in the last one */
function populateLab(game, put, SR) {
  for (const c of Lab.cages) {
    if (c.boss) {
      const e = put('gorilla', { x: c.x, z: c.z }, Object.assign({ boss: true, yaw: 0 }, BOSS[3]));
      if (e) { e.cage = c; e.caged = true; c.animals.push(e); e.guard = (o, dmg) => (o.caged ? 0 : dmg); } // behind its glass nothing hurts it
      continue;
    }
    // twelve to a cage, but only three giraffes and two elephants
    const T = ANIMALS[c.type], sc = c.scale || 1, count = c.count || 12, cols = Math.min(4, count), rows = Math.ceil(count / cols), iw = c.w - 1.2, id = c.d - 1.2, cw = iw / cols, ch = id / rows;
    for (let k = 0; k < count; k++) {
      const i = k % cols, j = Math.floor(k / cols), jx = Math.max(0, cw / 2 - T.r * sc - 0.2), jz = Math.max(0, ch / 2 - T.r * sc - 0.2);
      const x = c.x - iw / 2 + cw * (i + 0.5) + (SR() * 2 - 1) * jx, z = c.z - id / 2 + ch * (j + 0.5) + (SR() * 2 - 1) * jz;
      const e = put(c.type, { x, z }, { yaw: SR() * TAU, scale: sc });
      if (e) { e.cage = c; e.caged = true; c.animals.push(e); if (Lab.seq) e.guard = (o, dmg) => (o.caged ? 0 : dmg); } // 3-2: every cage is glass
    }
  }
}
