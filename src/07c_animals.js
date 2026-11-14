
/* ============ stage 3 animals: models, provocation, behaviour ============ */
// mode: prey flees, cat hunts on sight inside aggroR, herd charges together once provoked,
// gorilla only reacts to being shot (then charges hard), territorial charges when you come close
const ANIMALS = {
  zebra: { name: '얼룩말', hp: 150, speed: 3.5, run: 15, r: 0.55, h: 1.5, dmg: 0, money: 1000, mode: 'prey', aggroR: 0, reach: 1.9, turn: 5, roar: 'bray' },
  puma: { name: '퓨마', hp: 170, speed: 3.5, run: 13.5, r: 0.45, h: 0.95, dmg: 24, money: 1500, mode: 'cat', aggroR: 36, reach: 1.7, turn: 8, roar: 'cat', pounce: true },
  lion: { name: '사자', hp: 280, speed: 3.5, run: 14.5, r: 0.6, h: 1.25, dmg: 32, money: 2000, mode: 'cat', aggroR: 75, reach: 2, turn: 7, roar: 'cat', pounce: true },
  tiger: { name: '호랑이', hp: 320, speed: 3.5, run: 15, r: 0.62, h: 1.2, dmg: 120, money: 2200, mode: 'cat', aggroR: 75, reach: 2.1, turn: 7, roar: 'cat', pounce: true },
  buffalo: { name: '물소', hp: 440, speed: 2.4, run: 12.5, r: 0.85, h: 1.7, dmg: 50, money: 2000, mode: 'herd', aggroR: 9, reach: 2.4, turn: 3, roar: 'grunt', charge: true },
  gorilla: { name: '로랜드고릴라', hp: 400, speed: 1.4, run: 13.5, r: 0.7, h: 1.75, dmg: 62, money: 2500, mode: 'gorilla', aggroR: 0, reach: 2.1, turn: 7, roar: 'beat' },
  hippo: { name: '하마', hp: 620, speed: 2, run: 10.5, r: 1.1, h: 1.6, dmg: 50, money: 2500, mode: 'territorial', aggroR: 26, reach: 2.6, turn: 2.6, roar: 'grunt', charge: true },
  rhino: { name: '코뿔소', hp: 720, speed: 2, run: 13.5, r: 1.0, h: 1.9, dmg: 100, money: 3000, mode: 'territorial', aggroR: 30, reach: 2.6, turn: 2.4, roar: 'grunt', charge: true },
  elephant: { name: '코끼리', hp: 12000, speed: 2, run: 10.5, r: 1.7, h: 3.4, dmg: 72, money: 4000, mode: 'territorial', aggroR: 15, reach: 3.4, turn: 1.8, roar: 'trumpet', charge: true },
  // the lab adds three more: the fastest cat, the tallest kicker, and a lion that always has his mane
  cheetah: { name: '치타', hp: 160, speed: 4, run: 19, r: 0.45, h: 1.0, dmg: 120, money: 1800, mode: 'cat', aggroR: 60, reach: 1.8, turn: 9, roar: 'cat', pounce: true },
  giraffe: { name: '기린', hp: 5200, speed: 2.5, run: 11.5, r: 0.75, h: 4.6, dmg: 48, money: 2200, mode: 'territorial', aggroR: 20, reach: 2.6, turn: 3, roar: 'grunt', headX: 10 }, // ten times the others' health, ten times the damage to the head
  lionM: { name: '숫사자', hp: 340, speed: 3.5, run: 15, r: 0.64, h: 1.35, dmg: 50, money: 2400, mode: 'cat', aggroR: 75, reach: 2.1, turn: 7, roar: 'cat', pounce: true },
};
const GIRAFFE_NECK = [2.55, 0.38]; // where a giraffe's neck pivots (height, forward)
const ANIMAL_MIX = [['zebra', 22], ['puma', 13], ['lion', 14], ['tiger', 10], ['buffalo', 13], ['gorilla', 8], ['hippo', 7], ['rhino', 8], ['elephant', 5]];

const AnimalKit = (() => {
  const C = new THREE.Color();
  function geoBox(sx, sy, sz, x, y, z, color, rot, plainUV, sphere) {
    const g = sphere ? new THREE.SphereGeometry(0.5, 10, 7) : new THREE.BoxGeometry(1, 1, 1);
    g.scale(sx, sy, sz); if (rot) g.rotateX(rot[0] || 0).rotateY(rot[1] || 0).rotateZ(rot[2] || 0); g.translate(x, y, z);
    if (sphere) g.setIndex(g.index); // keep indexed for merging
    C.set(color).convertSRGBToLinear(); const n = g.attributes.position.count, col = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { col[i * 3] = C.r; col[i * 3 + 1] = C.g; col[i * 3 + 2] = C.b; }
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    if (plainUV) { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, 0.98, 0.98); }
    return g;
  }
  function merge(list) {
    const m = mergeGeos(list.map((g) => { const c = g.attributes.color; g.userData.col = c.array; return g; }));
    const cols = []; list.forEach((g) => { for (let i = 0; i < g.userData.col.length; i++) cols.push(g.userData.col[i]); });
    m.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3)); return m;
  }
  const stripe = (base, ink, wobble) => canvasTex(256, 128, (g, w, h) => {
    g.fillStyle = base; g.fillRect(0, 0, w, h);
    g.fillStyle = ink;
    for (let x = 6; x < w - 10; x += rand(10, 17)) { g.beginPath(); g.moveTo(x, 0); for (let y = 0; y <= h; y += 16) g.lineTo(x + Math.sin(y * 0.08 + x) * wobble, y);
      for (let y = h; y >= 0; y -= 16) g.lineTo(x + rand(3, 6) + Math.sin(y * 0.08 + x) * wobble, y); g.fill(); }
    g.fillStyle = '#ffffff'; g.fillRect(w - 14, h - 14, 14, 14);
    g.fillRect(w - 14, 0, 14, 14);
  });
  const corners = (g, w, h) => { g.fillStyle = '#ffffff'; g.fillRect(w - 14, h - 14, 14, 14); g.fillRect(w - 14, 0, 14, 14); };
  const spots = (base, ink) => canvasTex(256, 128, (g, w, h) => { g.fillStyle = base; g.fillRect(0, 0, w, h); g.fillStyle = ink;
    for (let i = 0; i < 280; i++) { g.beginPath(); g.ellipse(rand(0, w - 16), rand(0, h), rand(2, 4.5), rand(2, 4), rand(0, 3), 0, TAU); g.fill(); } corners(g, w, h); });
  const patches = (base, line) => canvasTex(256, 128, (g, w, h) => { g.fillStyle = line; g.fillRect(0, 0, w, h);
    for (let x = 0; x < w - 16; x += 22) for (let y = 0; y < h; y += 20) { g.fillStyle = base; const ox = rand(-3, 3), oy = rand(-3, 3);
      g.beginPath(); g.moveTo(x + 3 + ox, y + 3 + oy); g.lineTo(x + 19 + ox, y + 2 + oy); g.lineTo(x + 20 + ox, y + 17 + oy); g.lineTo(x + 2 + ox, y + 18 + oy); g.closePath(); g.fill(); }
    corners(g, w, h); });
  const tex = { tiger: stripe('#d9822b', '#1c1410', 4), zebra: stripe('#f0ede4', '#151515', 6), cheetah: spots('#d9a85a', '#1a1510'), giraffe: patches('#b8692a', '#efe2c4') };
  /* legs: [x, z, length, thickness, color, hoofColor]; body parts merged into one mesh */
  function quad(type) {
    const P = [], legs = [], plain = !!tex[type];
    const add = (sx, sy, sz, x, y, z, color, rot, sphere, striped) => P.push(geoBox(sx, sy, sz, x, y, z, color, rot, plain && !striped, sphere));
    // parts that move on their own (a hippo's head and jaw, a rhino's head, a cat's jaw): built around a pivot, in its frame
    const subs = [], sub = (name, x, y, z) => { const S = { name, at: [x, y, z], P: [] }; subs.push(S);
      return (sx, sy, sz, lx, ly, lz, color, rot, sphere, striped) => S.P.push(geoBox(sx, sy, sz, lx, ly, lz, color, rot, plain && !striped, sphere)); };
    let legSpec = [], hits = [];
    if (type === 'zebra') {
      add(0.66, 0.84, 1.95, 0, 1.08, 0, '#ffffff', null, true, true); add(0.26, 0.75, 0.32, 0, 1.55, 0.95, '#ffffff', [-0.6, 0, 0], false, true);
      add(0.26, 0.28, 0.6, 0, 1.85, 1.3, '#ffffff', [0.35, 0, 0], false, true); add(0.08, 0.5, 0.5, 0, 1.75, 1.0, '#151515', [-0.6, 0, 0]);
      add(0.06, 0.55, 0.06, 0, 1.0, -1.0, '#151515', [0.4, 0, 0]); add(0.07, 0.16, 0.06, -0.1, 2.05, 1.2, '#151515'); add(0.07, 0.16, 0.06, 0.1, 2.05, 1.2, '#151515');
      legSpec = [[0.2, 0.75, 0.75, 0.13, '#f0ede4'], [-0.2, 0.75, 0.75, 0.13, '#f0ede4'], [0.2, -0.75, 0.75, 0.13, '#f0ede4'], [-0.2, -0.75, 0.75, 0.13, '#f0ede4']];
      hits = [[0, 1.85, 1.35, 0.25, true], [0, 1.1, 0.5, 0.45], [0, 1.1, -0.5, 0.45], [0, 0.45, 0, 0.4, false, 0.7]];
    } else if (type === 'cheetah') {
      // slender, long-legged, spotted, black tear marks down the face
      const col = '#ffffff';
      add(0.48, 0.56, 1.7, 0, 0.88, 0, col, null, true, true); add(0.34, 0.32, 0.38, 0, 1.06, 0.98, col, null, true, true);
      add(0.18, 0.12, 0.14, 0, 0.98, 1.2, '#e8d2a8'); add(0.03, 0.16, 0.02, -0.07, 1.0, 1.17, '#151515'); add(0.03, 0.16, 0.02, 0.07, 1.0, 1.17, '#151515');
      { const J = sub('jaw', 0, 0.95, 1.08); J(0.15, 0.05, 0.22, 0, -0.03, 0.12, '#e8d2a8'); J(0.13, 0.02, 0.2, 0, 0.0, 0.11, '#7a2626'); J(0.025, 0.05, 0.025, -0.05, 0.02, 0.21, '#f4efe2'); J(0.025, 0.05, 0.025, 0.05, 0.02, 0.21, '#f4efe2'); }
      add(0.08, 0.08, 0.05, -0.12, 1.24, 0.94, col, null, false, true); add(0.08, 0.08, 0.05, 0.12, 1.24, 0.94, col, null, false, true);
      add(0.06, 0.06, 1.1, 0, 0.8, -1.25, col, [-0.45, 0, 0], false, true); add(0.07, 0.07, 0.14, 0, 0.42, -1.74, '#151515');
      const L = 0.74, th = 0.11;
      legSpec = [[0.17, 0.62, L, th, '#d8a55c'], [-0.17, 0.62, L, th, '#d8a55c'], [0.17, -0.62, L, th, '#d8a55c'], [-0.17, -0.62, L, th, '#d8a55c']];
      hits = [[0, 1.06, 1.0, 0.22, true], [0, 0.88, 0.4, 0.34], [0, 0.88, -0.45, 0.34], [0, 0.38, 0, 0.3, false, 0.7]];
    } else if (type === 'giraffe') {
      // patched hide, a long neck reaching up and forward, ossicones on the head
      const col = '#ffffff';
      add(0.86, 0.95, 1.85, 0, 2.35, 0, col, [0.12, 0, 0], true, true);
      // the neck and head hang from a pivot where the neck meets the shoulders, so the neck can be drawn back and swung like a club
      const N = sub('head', 0, GIRAFFE_NECK[0], GIRAFFE_NECK[1]), nk = (sx, sy, sz, x, y, z, c, rot, sph, str) => N(sx, sy, sz, x, y - GIRAFFE_NECK[0], z - GIRAFFE_NECK[1], c, rot, sph, str);
      nk(0.34, 2.3, 0.42, 0, 3.55, 0.95, col, [0.52, 0, 0], false, true);
      nk(0.1, 2.0, 0.08, 0, 3.62, 0.74, '#6a3a18', [0.52, 0, 0]); nk(0.3, 0.32, 0.7, 0, 4.62, 1.62, col, [0.25, 0, 0], false, true);
      nk(0.2, 0.2, 0.26, 0, 4.5, 1.98, '#d8c4a0'); nk(0.05, 0.22, 0.05, -0.08, 4.88, 1.45, '#5a3a20'); nk(0.05, 0.22, 0.05, 0.08, 4.88, 1.45, '#5a3a20');
      nk(0.12, 0.06, 0.18, -0.2, 4.75, 1.45, col, null, false, true); nk(0.12, 0.06, 0.18, 0.2, 4.75, 1.45, col, null, false, true);
      add(0.05, 0.8, 0.05, 0, 2.1, -1.0, '#6a3a18', [0.3, 0, 0]);
      const L = 1.95, th = 0.15;
      legSpec = [[0.26, 0.68, L, th, '#e9d9b8'], [-0.26, 0.68, L, th, '#e9d9b8'], [0.26, -0.68, L * 0.95, th, '#e9d9b8'], [-0.26, -0.68, L * 0.95, th, '#e9d9b8']];
      hits = [[0, 4.6, 1.6, 0.32, true], [0, 3.55, 1.0, 0.36], [0, 2.4, 0.5, 0.55], [0, 2.35, -0.5, 0.55], [0, 1.0, 0, 0.45, false, 0.7]];
    } else if (type === 'puma' || type === 'lion' || type === 'tiger' || type === 'lionM') {
      const s = type === 'puma' ? 0.72 : type === 'lion' ? 1 : type === 'lionM' ? 1.08 : 1.06, col = type === 'puma' ? '#a0784a' : type === 'tiger' ? '#ffffff' : '#c49a5c';
      const striped = type === 'tiger';
      add(0.64 * s, 0.72 * s, 1.85 * s, 0, 0.9 * s, 0, col, null, true, striped);
      add(0.46 * s, 0.44 * s, 0.5 * s, 0, 1.1 * s, 1.0 * s, col, null, true, striped);
      add(0.22 * s, 0.15 * s, 0.16 * s, 0, 1.0 * s, 1.27 * s, type === 'tiger' ? '#efe3cf' : '#d8b98a');
      add(0.03 * s, 0.08 * s, 0.03 * s, -0.07 * s, 0.9 * s, 1.31 * s, '#f4efe2'); add(0.03 * s, 0.08 * s, 0.03 * s, 0.07 * s, 0.9 * s, 1.31 * s, '#f4efe2'); // fangs
      { const J = sub('jaw', 0, 0.97 * s, 1.08 * s), mc = type === 'tiger' ? '#efe3cf' : '#d8b98a';
        J(0.2 * s, 0.07 * s, 0.3 * s, 0, -0.04 * s, 0.16 * s, mc); J(0.17 * s, 0.025 * s, 0.26 * s, 0, 0, 0.14 * s, '#7a2626');
        J(0.03 * s, 0.07 * s, 0.03 * s, -0.07 * s, 0.03 * s, 0.27 * s, '#f4efe2'); J(0.03 * s, 0.07 * s, 0.03 * s, 0.07 * s, 0.03 * s, 0.27 * s, '#f4efe2'); }
      add(0.1 * s, 0.1 * s, 0.05 * s, -0.14 * s, 1.32 * s, 0.98 * s, col, null, false, striped); add(0.1 * s, 0.1 * s, 0.05 * s, 0.14 * s, 1.32 * s, 0.98 * s, col, null, false, striped);
      add(0.08 * s, 0.08 * s, 1.0 * s, 0, 0.85 * s, -1.25 * s, col, [-0.5, 0, 0], false, striped);
      if (type === 'lion' && Math.random() < 0.55) { add(0.78, 0.8, 0.5, 0, 1.1, 0.82, '#5a3a1e', null, true); add(0.14, 0.14, 0.18, 0, 0.6, -1.7, '#3a2412'); }
      if (type === 'lionM') { add(0.98, 1.0, 0.66, 0, 1.18 * s, 0.84 * s, '#4e3018', null, true); add(0.5, 0.4, 0.3, 0, 0.82 * s, 0.9 * s, '#4e3018', null, true); add(0.14, 0.14, 0.18, 0, 0.62, -1.8, '#3a2412'); }
      if (type === 'tiger') add(0.3, 0.2, 1.4, 0, 0.6, 0, '#efe3cf');
      const L = 0.62 * s, th = 0.17 * s;
      legSpec = [[0.2 * s, 0.62 * s, L, th, col], [-0.2 * s, 0.62 * s, L, th, col], [0.2 * s, -0.62 * s, L, th, col], [-0.2 * s, -0.62 * s, L, th, col]];
      hits = [[0, 1.08 * s, 1.05 * s, 0.26 * s, true], [0, 0.9 * s, 0.4 * s, 0.4 * s], [0, 0.9 * s, -0.45 * s, 0.4 * s], [0, 0.35 * s, 0, 0.35 * s, false, 0.7]];
    } else if (type === 'buffalo') {
      add(0.95, 1.05, 2.2, 0, 1.2, 0, '#2a2622', null, true); add(0.5, 0.55, 0.62, 0, 1.15, 1.25, '#24201c');
      add(0.95, 0.16, 0.22, 0, 1.52, 1.18, '#8a8070'); add(0.16, 0.36, 0.16, -0.52, 1.38, 1.18, '#8a8070', [0, 0, 0.4]); add(0.16, 0.36, 0.16, 0.52, 1.38, 1.18, '#8a8070', [0, 0, -0.4]);
      add(0.06, 0.6, 0.06, 0, 1.25, -1.15, '#1a1714', [0.4, 0, 0]);
      legSpec = [[0.3, 0.75, 0.78, 0.2, '#24201c'], [-0.3, 0.75, 0.78, 0.2, '#24201c'], [0.3, -0.75, 0.78, 0.2, '#24201c'], [-0.3, -0.75, 0.78, 0.2, '#24201c']];
      hits = [[0, 1.15, 1.3, 0.34, true], [0, 1.25, 0.55, 0.6], [0, 1.2, -0.6, 0.58], [0, 0.45, 0, 0.45, false, 0.7]];
    } else if (type === 'hippo') {
      // the head swings up and the jaw drops for the gape: pink inside, four big tusks
      add(1.4, 1.2, 2.6, 0, 1.0, 0, '#5e5457', null, true); add(0.78, 0.64, 0.6, 0, 1.02, 1.08, '#5a5053', null, true);
      const H = sub('head', 0, 1.0, 1.15), J = sub('jaw', 0, 0.86, 1.2);
      H(0.95, 0.62, 0.95, 0, 0.1, 0.32, '#5a5053', null, true); H(0.92, 0.3, 0.66, 0, 0.02, 0.86, '#6f6064'); H(0.8, 0.04, 0.56, 0, -0.13, 0.84, '#b8606a');
      H(0.1, 0.24, 0.1, -0.3, -0.2, 1.08, '#efe8d8'); H(0.1, 0.24, 0.1, 0.3, -0.2, 1.08, '#efe8d8');
      H(0.12, 0.14, 0.1, -0.3, 0.44, 0.12, '#5a4a52'); H(0.12, 0.14, 0.1, 0.3, 0.44, 0.12, '#5a4a52'); H(0.14, 0.1, 0.12, -0.24, 0.36, 0.42, '#4a3e44'); H(0.14, 0.1, 0.12, 0.24, 0.36, 0.42, '#4a3e44');
      H(0.1, 0.06, 0.06, -0.18, 0.18, 1.2, '#3a3036'); H(0.1, 0.06, 0.06, 0.18, 0.18, 1.2, '#3a3036');
      J(0.9, 0.3, 0.98, 0, -0.1, 0.55, '#6a5c60'); J(0.76, 0.04, 0.8, 0, 0.06, 0.52, '#c0707a'); J(0.11, 0.34, 0.11, -0.32, 0.16, 0.94, '#efe8d8'); J(0.11, 0.34, 0.11, 0.32, 0.16, 0.94, '#efe8d8');
      legSpec = [[0.45, 0.85, 0.55, 0.34, '#5f4f57'], [-0.45, 0.85, 0.55, 0.34, '#5f4f57'], [0.45, -0.85, 0.55, 0.34, '#5f4f57'], [-0.45, -0.85, 0.55, 0.34, '#5f4f57']];
      hits = [[0, 1.0, 1.55, 0.45, true], [0, 1.05, 0.55, 0.72], [0, 1.0, -0.6, 0.72], [0, 0.4, 0, 0.5, false, 0.7]];
    } else if (type === 'rhino') {
      // the head (with both horns) hangs from the neck so it can drop for the charge and flick up
      add(1.2, 1.25, 2.6, 0, 1.25, 0, '#7a7774', null, true);
      const H = sub('head', 0, 1.18, 1.05);
      H(0.62, 0.62, 0.95, 0, -0.13, 0.45, '#73716d'); H(0.18, 0.55, 0.18, 0, 0.27, 0.87, '#c9c2b2', [0.5, 0, 0]); H(0.13, 0.32, 0.13, 0, 0.22, 0.57, '#c9c2b2', [0.3, 0, 0]);
      H(0.1, 0.18, 0.08, -0.22, 0.24, 0.07, '#7a7873'); H(0.1, 0.18, 0.08, 0.22, 0.24, 0.07, '#7a7873');
      legSpec = [[0.42, 0.85, 0.75, 0.32, '#7d7b77'], [-0.42, 0.85, 0.75, 0.32, '#7d7b77'], [0.42, -0.85, 0.75, 0.32, '#7d7b77'], [-0.42, -0.85, 0.75, 0.32, '#7d7b77']];
      hits = [[0, 1.1, 1.6, 0.38, true], [0, 1.3, 0.5, 0.7], [0, 1.25, -0.6, 0.68], [0, 0.45, 0, 0.5, false, 0.7]];
    } else if (type === 'elephant') {
      add(1.9, 2.1, 3.2, 0, 2.4, 0, '#77746f', null, true); add(1.2, 1.25, 1.1, 0, 2.85, 1.75, '#72706b', null, true);
      add(0.14, 1.3, 1.1, -0.72, 2.7, 1.45, '#6a6863', [0, -0.35, 0]); add(0.14, 1.3, 1.1, 0.72, 2.7, 1.45, '#6a6863', [0, 0.35, 0]);
      add(0.34, 0.8, 0.34, 0, 2.15, 2.3, '#6f6c68', [0.25, 0, 0]); add(0.28, 0.7, 0.28, 0, 1.45, 2.45, '#6f6c68'); add(0.22, 0.5, 0.22, 0, 0.95, 2.55, '#6f6c68', [-0.3, 0, 0]);
      add(0.12, 0.12, 0.75, -0.32, 2.2, 2.35, '#efe8d8', [0.5, 0, 0]); add(0.12, 0.12, 0.75, 0.32, 2.2, 2.35, '#efe8d8', [0.5, 0, 0]);
      add(0.08, 0.9, 0.08, 0, 2.3, -1.65, '#7a7773', [0.3, 0, 0]);
      legSpec = [[0.6, 1.1, 1.45, 0.58, '#6f6c68'], [-0.6, 1.1, 1.45, 0.58, '#6f6c68'], [0.6, -1.1, 1.45, 0.58, '#6f6c68'], [-0.6, -1.1, 1.45, 0.58, '#6f6c68']];
      hits = [[0, 2.9, 1.9, 0.6, true], [0, 2.4, 0.7, 1.1], [0, 2.4, -0.8, 1.1], [0, 0.8, 0, 0.8, false, 0.7]];
    } else { // gorilla: knuckle-walking, long arms in front, silver back
      add(0.9, 1.0, 1.05, 0, 1.15, 0, '#1e1d1f', [-0.55, 0, 0], true); add(0.7, 0.35, 0.6, 0, 1.45, -0.15, '#8f8f8f', [-0.55, 0, 0]);
      add(0.42, 0.44, 0.4, 0, 1.7, 0.55, '#1e1d1f'); add(0.3, 0.22, 0.12, 0, 1.64, 0.76, '#3a3532'); add(0.36, 0.1, 0.12, 0, 1.86, 0.62, '#151416');
      legSpec = [[0.42, 0.42, 1.05, 0.26, '#1e1d1f'], [-0.42, 0.42, 1.05, 0.26, '#1e1d1f'], [0.25, -0.35, 0.62, 0.26, '#1e1d1f'], [-0.25, -0.35, 0.62, 0.26, '#1e1d1f']];
      hits = [[0, 1.72, 0.58, 0.24, true], [0, 1.2, 0.1, 0.55], [0, 0.85, -0.3, 0.45], [0, 0.4, 0.2, 0.4, false, 0.7]];
    }
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, map: tex[type] || null, roughness: 0.85, emissive: 0x000000 });
    const g = new THREE.Group(); g.rotation.order = 'YXZ';
    const body = new THREE.Mesh(merge(P), mat); body.castShadow = !isTouch; g.add(body);
    const piv = {};
    for (const S of subs) { const o = new THREE.Group(); o.position.set(S.at[0], S.at[1], S.at[2]); body.add(o); const m = new THREE.Mesh(merge(S.P), mat); m.castShadow = !isTouch; o.add(m); piv[S.name] = o; }
    for (const [x, z, Ln, th, col] of legSpec) {
      const pivot = new THREE.Group(); pivot.position.set(x, Ln, z); g.add(pivot);
      const leg = new THREE.Mesh(merge([geoBox(th, Ln, th * 1.1, 0, -Ln / 2, 0, col, null, false), geoBox(th * 1.05, Ln * 0.12, th * 1.25, 0, -Ln + Ln * 0.06, th * 0.08, type === 'elephant' ? '#6f6c68' : '#2a2420', null, plain)]), mat);
      leg.castShadow = !isTouch; pivot.add(leg); legs.push(pivot);
    }
    return { g, body, mat, legs, head: piv.head || null, jaw: piv.jaw || null, parts: hits.map(([x, y, z, rr, weak, mult]) => ({ o: new THREE.Vector3(x, y, z), r: rr, mult: mult || 1, weak: !!weak })) };
  }
  return { quad, geoBox, merge };
})();

function buildAnimal(type, opts) {
  const T = ANIMALS[type], kong = !!(opts && opts.kong), k = kong ? KongKit.build(!!opts.boss) : AnimalKit.quad(type);
  const e = { type, T, animal: true, g: k.g, body: k.body, legs: k.legs, head: k.head || null, jaw: k.jaw || null, mats: [k.mat], parts: k.parts, vel: new THREE.Vector3(), muzzle: new THREE.Vector3(), rig: k.rig || null, kong, minion: !!(opts && opts.minion) };
  const bar = new THREE.Group(); const bg = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.7 }));
  bg.scale.set(0.9, 0.08, 1); bar.add(bg);
  const fill = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ color: 0xf2a33a })); fill.scale.set(0.86, 0.05, 1); fill.position.z = 0.001; bar.add(fill);
  bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
  bakeFar(e);
  return e;
}
function initAnimal(e) {
  e.angry = false; e.state = 'wander'; e.stateT = rand(2, 6); e.home = { x: e.pos.x, z: e.pos.z }; e.wx = e.pos.x; e.wz = e.pos.z;
  e.chargeCd = rand(1, 3); e.attackT = 0; e.pounceCd = 0; e.roarT = rand(2, 8); e.airborne = false;
}
/* shot: everyone reacts; buffalo herds turn together, gorillas go berserk */
function provokeAnimal(e) {
  const T = e.T;
  if (e.fury && e.type === 'zebra' && !e.ridden) { if (!e.wild) spook(e); return; } // zebras never fight back: in the lab, shot, they bolt; on the safari they do not even run
  if (e.caged || e.fury || e.kong) { if (e.kong && !e.caged) e.angry = true; return; } // the lab's animals are already furious; behind bars they can only rage
  if (T.mode === 'prey') { e.state = 'flee'; e.stateT = rand(3, 5); return; }
  if (!e.angry) {
    e.angry = true;
    if (T.mode === 'gorilla') { e.state = 'roar'; e.stateT = 0.8; Sound.roar(e.pos, 'beat'); HUD.feed('고릴라가 화났습니다!', 0, 'hs'); }
    else { e.state = 'chase'; Sound.roar(e.pos, T.roar); }
  }
  if (T.mode === 'herd') for (const o of Enemies.list) if (o !== e && o.type === e.type && !o.angry && o.pos.distanceTo(e.pos) < 60) { o.angry = true; o.state = 'chase'; }
}
/* gunfire nearby: prey bolts, predators and territorial animals come at you */
function hearAnimal(e, d) {
  const T = e.T;
  if (e.kong && e.wild && !e.angry && d < 30) { e.angry = true; e.alert = true; return; } // a shot near a wild gorilla sets it off
  if (e.caged || e.fury || e.kong) return;
  if (T.mode === 'prey') { if (e.state !== 'flee') { e.state = 'flee'; e.stateT = rand(3, 5); } return; }
  if (e.angry) return;
  if ((T.mode === 'cat' && d < 55) || ((T.mode === 'herd' || T.mode === 'territorial') && d < 30) || (e.boss && d < 50)) provokeAnimal(e);
}
function animalStrike(e, dmg, kx, kz, kick) {
  dmg *= (e.dmgMul || 1) * (e.kong ? 1 : BEAST_DMG);
  if (!(dmg > 0)) return; // a zebra bumping past
  if (Ride.m) { Ride.hurtMount(dmg, e); return; } // up on any animal: the one under you takes it
  if (Car.riding) { Car.damage(dmg * 2.2, e.pos); player.hurt(dmg * 0.4, e.pos, 'body'); return; }
  if (player.pos.y > e.pos.y + e.H + 0.3) return; // you are flying over it
  player.hurt(dmg, e.pos, 'body');
  if (!e.boss && !Game.ended) Bleed.add(); // every animal's blow opens a wound (a giraffe's kick, an elephant's tusks too)
  player.vel.x += kx * kick; player.vel.z += kz * kick; if (kick > 8) { player.vel.y = 5; player.grounded = false; }
}
/* behind bars: pace, turn to face you, and now and then throw themselves at the bars (the wall shakes) */
function cagedAnimal(e, dt, time, dist, faceYaw) {
  const T = e.T, c = e.cage, R = e.R, ix = Math.max(0.2, c.w / 2 - 0.45 - R), iz = Math.max(0.2, c.d / 2 - 0.45 - R);
  e.stateT -= dt; e.roarT -= dt;
  let sp = 0, dirx = 0, dirz = 0;
  if (e.cstate === undefined) { e.cstate = 'idle'; e.stateT = rand(0.3, 3); }
  if (e.cstate === 'idle') {
    if (e.stateT <= 0) {
      if (dist < 24 && Math.random() < 0.4) { e.cstate = 'lunge'; e.stateT = 1.1; e.cx = (player.pos.x - e.pos.x) / dist; e.cz = (player.pos.z - e.pos.z) / dist; }
      else { e.cstate = 'pace'; e.stateT = rand(2, 4); e.wx = c.x + rand(-ix, ix); e.wz = c.z + rand(-iz, iz); }
    }
    if (dist < 22) turnToward(e, faceYaw, T.turn * 0.5, dt);
  } else if (e.cstate === 'pace') {
    const dx = e.wx - e.pos.x, dz = e.wz - e.pos.z, l = Math.hypot(dx, dz);
    if (l < 0.6 || e.stateT <= 0) { e.cstate = 'idle'; e.stateT = rand(0.8, 3); } else { dirx = dx / l; dirz = dz / l; sp = T.speed * 1.25; }
  } else if (e.cstate === 'lunge') { dirx = e.cx; dirz = e.cz; sp = Math.min(T.run * 0.5, 7); if (e.stateT <= 0) { e.cstate = 'idle'; e.stateT = rand(1, 3); } }
  e.vel.multiplyScalar(Math.exp(-dt * 4));
  const blocked = groundMove(e, dirx * sp + e.vel.x, dirz * sp + e.vel.z, dt);
  if (blocked && e.cstate === 'lunge') { e.cstate = 'idle'; e.stateT = rand(1.2, 3.5); Lab.rattle(c, e.pos.x + dirx * R, e.pos.z + dirz * R); if (Math.random() < 0.5) Sound.roar(e.pos, T.roar); }
  else if (blocked && e.cstate === 'pace') { e.cstate = 'idle'; e.stateT = rand(0.5, 1.5); }
  if (sp > 0.1) turnToward(e, Math.atan2(dirx, dirz), T.turn, dt);
  animalGait(e, sp, dt);
  if (e.roarT <= 0) { e.roarT = rand(6, 14); if (dist < 34 && Math.random() < 0.45) Sound.roar(e.pos, T.roar); }
}
/* a big body on a 1 m walking grid can wedge itself against a tank or a bench: when it makes no headway it steps round to one side */
function unstick(e, x0, z0, dirx, dirz, sp, dt) {
  const moved = Math.hypot(e.pos.x - x0, e.pos.z - z0);
  if (sp > 1 && moved < sp * dt * 0.3) e.stuckT = (e.stuckT || 0) + dt; else e.stuckT = Math.max(0, (e.stuckT || 0) - dt * 2);
  if (e.stuckT < 0.35 || e.detourT > 0) return;
  const px = -dirz, pz = dirx, L = e.R * 2 + 1, h = Math.min(e.H, 2.5);
  const free = (s) => !collideAt(e.pos.x + px * s * L, e.pos.y + 0.05, e.pos.z + pz * s * L, e.R, h);
  const a = free(1), b = free(-1), s = a && b ? (Math.random() < 0.5 ? 1 : -1) : a ? 1 : b ? -1 : (Math.random() < 0.5 ? 1 : -1);
  const x = px * s * 0.9 - dirx * 0.2, z = pz * s * 0.9 - dirz * 0.2, l = Math.hypot(x, z) || 1;
  e.dx2 = x / l; e.dz2 = z / l; e.detourT = rand(0.55, 0.95); e.stuckT = 0;
}
function animalGait(e, sp, dt) {
  const gait = Math.min(1, sp / 6) * (e.airborne ? 0.2 : 1);
  e.walk += dt * (2 + sp * 0.9);
  const sw = Math.sin(e.walk) * 0.55 * gait;
  if (e.legs.length === 4) { e.legs[0].rotation.x = sw; e.legs[3].rotation.x = sw; e.legs[1].rotation.x = -sw; e.legs[2].rotation.x = -sw; }
  e.body.position.y = Math.abs(Math.sin(e.walk)) * 0.05 * gait * e.T.h;
}
function updateAnimal(e, dt, time, dist, faceYaw) {
  if (e.kong) { updateKong(e, dt, time, dist, faceYaw); return; }
  if (e.caged) { cagedAnimal(e, dt, time, dist, faceYaw); return; }
  if (e.ridden) return; // you are steering it (Ride.update)
  if (e.kneelT > 0) { kneelPose(e, dt); return; } // a male lion roared
  // just let out: a moment to take it in, then everything in the cage comes for you
  if (e.releaseT > 0) {
    e.releaseT -= dt; turnToward(e, faceYaw, e.T.turn, dt); animalGait(e, 0, dt);
    if (e.releaseT > 0) return;
    e.fury = true; e.angry = true; e.state = 'chase'; e.chargeCd = rand(0.6, 2.2); e.pounceCd = rand(0.3, 1.5); if (Math.random() < 0.5 && e.type !== 'zebra') Sound.roar(e.pos, e.T.roar);
    Beast.wake(e);
  }
  const T = e.T, px = player.pos.x, pz = player.pos.z, reach = Math.max(T.reach * (e.scale || 1), e.foot ? e.foot.z1 + 0.3 : 0);
  const tx = (px - e.pos.x) / dist, tz = (pz - e.pos.z) / dist;
  // 3-1: wild until something sets it off (you close by, a shot nearby, a hit, the stampede); then it fights the lab's way.
  // while you stand on the watchtower everything but a giraffe goes for the tower first; after the stampede the zebras just come and stand about it
  if (e.wild && !e.tamed) {
    if (e.angry && !e.fury) { e.fury = true; e.state = 'chase'; Beast.wake(e); }
    if (e.fury) {
      if (e.type === 'zebra') { if (Safari.stampede) { zebraMill(e, dt); return; } }
      else if (e.type !== 'giraffe' && Tower.holds()) { siegeAI(e, dt, dist); return; }
    }
  }
  // the lab's kinds each fight their own way (07g); tamed ones just amble about
  if (e.fury && (e.tamed || BEASTS[e.type])) {
    (e.tamed ? zebraAI : BEASTS[e.type])(e, dt, dist, tx, tz, faceYaw);
    e.roarT -= dt; if (e.roarT <= 0) { e.roarT = rand(6, 14); if (dist < 40 && !e.tamed && e.type !== 'zebra' && Math.random() < 0.5) Sound.roar(e.pos, T.roar); }
    return;
  }
  const B = e.buff || 1; // faster after every lion's roar
  let sp = 0, dirx = 0, dirz = 0, turn = T.turn;
  e.stateT -= dt; e.chargeCd -= dt * B; e.pounceCd -= dt * B; e.attackT -= dt * B;
  // who notices you: lions and tigers hunt on sight, territorial animals when you come close
  if (!e.angry && e.boss && dist < 40) provokeAnimal(e);
  const aggroR = e.wild ? Math.min(T.aggroR, 28) : T.aggroR; // out on the safari they let you get closer, and a cat has to see you
  if (!e.angry && ((T.mode === 'cat' && dist < aggroR && (!e.wild || e.los || dist < 12)) || ((T.mode === 'territorial' || T.mode === 'herd') && dist < aggroR))) {
    e.angry = true; e.state = 'chase'; Sound.roar(e.pos, T.roar);
    if (T.mode === 'herd') provokeAnimal(e);
  }
  if (T.mode === 'prey' && !e.fury && e.state !== 'flee' && dist < 26) { e.state = 'flee'; e.stateT = rand(3, 5); }
  if (e.state === 'wander') {
    if (e.stateT <= 0 || Math.hypot(e.wx - e.pos.x, e.wz - e.pos.z) < 2) {
      e.stateT = rand(4, 9); const a = rand(0, TAU), d = rand(6, 28);
      e.wx = clamp(e.home.x + Math.cos(a) * d, -HALF + 3, HALF - 3); e.wz = clamp(e.home.z + Math.sin(a) * d, -HALF + 3, HALF - 3);
      e.graze = Math.random() < 0.35 ? rand(1.5, 4) : 0;
    }
    if (e.graze > 0) e.graze -= dt;
    else { const dx = e.wx - e.pos.x, dz = e.wz - e.pos.z, l = Math.hypot(dx, dz) || 1; dirx = dx / l; dirz = dz / l; sp = T.speed; }
  } else if (e.state === 'flee') {
    dirx = -tx; dirz = -tz; sp = T.run;
    if (e.stateT <= 0 && dist > 40) { e.state = 'wander'; e.home = { x: e.pos.x, z: e.pos.z }; }
    if (dist < reach + 0.6 && e.attackT <= 0) { e.attackT = 1.4; animalStrike(e, T.dmg, -tx, -tz, 7); Sound.roar(e.pos, 'bray'); }
  } else if (e.state === 'roar') {
    turn = 9; if (e.stateT <= 0) e.state = 'chase';
  } else if (e.state === 'chase') {
    if (dist < 40 && e.los) { dirx = tx; dirz = tz; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = tx; dirz = tz; }
    sp = T.mode === 'cat' && dist > 30 ? T.run * 0.6 : T.charge ? T.run * 0.7 : T.run;
    if (T.charge && e.chargeCd <= 0 && dist > 7 && dist < 45 && e.los) { e.state = 'charge'; e.stateT = 2.6; e.cx = tx; e.cz = tz; e.hitDone = false; Sound.roar(e.pos, T.roar); }
    if (T.pounce && e.pounceCd <= 0 && dist < 7.5 && dist > 2.5 && e.los && !e.airborne) {
      e.airborne = true; e.vy = 4.6; e.vel.x = tx * T.run * 1.05; e.vel.z = tz * T.run * 1.05; e.pounceCd = rand(2.5, 4); e.hitDone = false; Sound.roar(e.pos, 'cat');
    }
    if (dist < reach + player.r && e.attackT <= 0) { e.attackT = T.mode === 'gorilla' ? 1.05 : T.mode === 'cat' ? 0.9 : 1.3; e.windup = 0.22; }
  } else if (e.state === 'charge') {
    dirx = e.cx; dirz = e.cz; sp = T.run * 1.25; turn = 0.4;
    if (!e.hitDone && dist < reach + player.r + 0.4) { e.hitDone = true; animalStrike(e, T.dmg * 1.2, e.cx, e.cz, 14); }
    if (e.stateT <= 0 || (e.hitDone && e.stateT < 1.6)) { e.state = 'recover'; e.stateT = 1.0; }
  } else if (e.state === 'recover' || e.state === 'stun') {
    sp = e.state === 'recover' ? T.run * 0.3 : 0; dirx = e.cx || tx; dirz = e.cz || tz;
    if (e.stateT <= 0) { e.state = 'chase'; e.chargeCd = rand(2.5, 4.5); }
  }
  if (e.windup > 0) { e.windup -= dt; if (e.windup <= 0 && dist < reach + player.r + 0.8) animalStrike(e, T.dmg, tx, tz, T.mode === 'gorilla' ? 13 : T.dmg > 40 ? 10 : 5); }
  // movement and facing
  if (e.airborne) {
    e.vy -= 16 * dt; e.pos.y += e.vy * dt;
    moveXZ(e.pos, e.vel.x * dt, e.vel.z * dt, e.R, e.H, 0.45);
    if (!e.hitDone && dist < reach + player.r + 0.5) { e.hitDone = true; animalStrike(e, T.dmg * 1.15, tx, tz, 9); }
    if (e.pos.y <= groundAt(e.pos.x, e.pos.y, e.pos.z, e.R)) { e.pos.y = groundAt(e.pos.x, e.pos.y, e.pos.z, e.R); e.airborne = false; e.vy = 0; e.vel.set(0, 0, 0); }
  } else {
    e.vel.multiplyScalar(Math.exp(-dt * 4));
    if (e.detourT > 0) { e.detourT -= dt; if (e.state === 'chase') { dirx = e.dx2; dirz = e.dz2; } }
    const x0 = e.pos.x, z0 = e.pos.z;
    let blocked = groundMove(e, dirx * sp * B + e.vel.x, dirz * sp * B + e.vel.z, dt);
    if (e.state === 'chase') unstick(e, x0, z0, dirx, dirz, sp, dt);
    if (blocked && e.state === 'charge' && smashAhead(e, e.cx, e.cz)) blocked = false; // a charging buffalo, hippo, rhino or elephant goes straight through a crate
    if (blocked && e.state === 'charge') { e.state = 'stun'; e.stateT = 1.1; FX.puff({ x: e.pos.x + e.cx * e.R, y: 1, z: e.pos.z + e.cz * e.R }, 6, 0.4, 0.8); Sound.thud(e.pos); }
    if (blocked && e.state === 'wander') e.stateT = 0;
  }
  if (sp > 0.1 && e.state !== 'roar') turnToward(e, e.state === 'chase' && dist < 12 ? faceYaw : Math.atan2(dirx, dirz), turn, dt);
  else if (e.state === 'roar' || (e.angry && dist < 14)) turnToward(e, faceYaw, turn, dt);
  // gait: diagonal pairs swing together, faster with speed
  animalGait(e, sp, dt);
  e.roarT -= dt; if (e.roarT <= 0) { e.roarT = rand(6, 14); if (dist < 45 && (e.angry || Math.random() < 0.3)) Sound.roar(e.pos, T.roar); }
}
