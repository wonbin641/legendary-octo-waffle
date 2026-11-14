
/* ============ world: textures and the yard for each stage ============ */
const MAX_ANISO = Math.min(isTouch ? 8 : 16, renderer.capabilities.getMaxAnisotropy ? renderer.capabilities.getMaxAnisotropy() : 1);
function canvasTex(w, h, draw, rx, ry) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; t.anisotropy = MAX_ANISO;
  if (rx) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rx, ry || rx); }
  return t;
}
function speckle(g, w, h, n, colors, size) {
  for (let i = 0; i < n; i++) { g.fillStyle = pick(colors); const s = rand(size * 0.5, size * 1.5); g.fillRect(Math.random() * w, Math.random() * h, s, s); }
}
function shade(hex, f) { const c = new THREE.Color(hex); c.multiplyScalar(f); return '#' + c.getHexString(); }
function glowTex(inner, outer) {
  return canvasTex(128, 128, (g) => { const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    gr.addColorStop(0, inner); gr.addColorStop(0.35, outer); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 128, 128); });
}
/* the moon: a pale disk with darker seas and a soft halo around it */
function moonTex() {
  return canvasTex(256, 256, (g, w, h) => {
    const c = w / 2, R = w * 0.2;
    const halo = g.createRadialGradient(c, c, R * 0.9, c, c, c); halo.addColorStop(0, 'rgba(180,198,255,0.42)'); halo.addColorStop(0.35, 'rgba(140,160,230,0.12)'); halo.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = halo; g.fillRect(0, 0, w, h);
    const disk = g.createRadialGradient(c - R * 0.25, c - R * 0.25, R * 0.1, c, c, R); disk.addColorStop(0, '#f6f8ff'); disk.addColorStop(0.85, '#dfe5f2'); disk.addColorStop(1, '#c4cbe0');
    g.fillStyle = disk; g.beginPath(); g.arc(c, c, R, 0, TAU); g.fill();
    g.save(); g.beginPath(); g.arc(c, c, R, 0, TAU); g.clip();
    [[-0.3, -0.2, 0.32, 0.22], [0.25, -0.35, 0.2, 0.15], [0.1, 0.25, 0.3, 0.2], [-0.35, 0.35, 0.18, 0.12], [0.42, 0.1, 0.14, 0.2]].forEach(([x, y, a, b]) => {
      g.fillStyle = 'rgba(150,160,188,0.38)'; g.beginPath(); g.ellipse(c + x * R, c + y * R, a * R, b * R, 0.4, 0, TAU); g.fill(); });
    for (let i = 0; i < 14; i++) { g.strokeStyle = 'rgba(160,170,195,0.35)'; g.lineWidth = 1; g.beginPath(); g.arc(c + rand(-0.8, 0.8) * R, c + rand(-0.8, 0.8) * R, rand(1.5, 4), 0, TAU); g.stroke(); }
    g.restore();
  });
}
function mulberry(seed) { return function () { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function mergeBoxes(parts) {
  return mergeGeos(parts.map((p) => { const g = new THREE.BoxGeometry(p[0], p[1], p[2]); g.translate(p[3], p[4], p[5]); return g; }));
}
function mergeGeos(list) {
  const pos = [], nor = [], uv = [], idx = []; let off = 0;
  for (const g of list) {
    const a = g.attributes;
    for (let i = 0; i < a.position.array.length; i++) { pos.push(a.position.array[i]); nor.push(a.normal.array[i]); }
    for (let i = 0; i < a.uv.array.length; i++) uv.push(a.uv.array[i]);
    for (let i = 0; i < g.index.array.length; i++) idx.push(g.index.array[i] + off);
    off += a.position.count; g.dispose();
  }
  const m = new THREE.BufferGeometry();
  m.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); m.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
  m.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); m.setIndex(idx); return m;
}
const CONT_COLORS = ['#8c3a2b', '#2c4f7c', '#356b45', '#c4682a', '#7b8288', '#2f7a7a', '#6a2a35', '#b8ab8a'];
const OWNERS = ['YRD', 'KJT', 'HWS', 'SLV', 'PRC', 'DGN', 'TRV', 'BNK'];
const crates = [];
const STAGE_STYLE = {
  1: { fog: [0.026, 0.033, 0.052], density: 0.016, zenith: [0.006, 0.008, 0.017], glow: [0.06, 0.036, 0.022], hemi: [0x5d6f96, 0x2b2420, 0.62], moon: [0xa8bcff, 0.42], lamp: [0xffa548, 1.8], seed: 7, crates: 40, singles: 12, empty: 0.1 },
  // the village: deep blue night, a big moon whose light falls from where it hangs in the sky, fires flickering orange
  2: { fog: [0.018, 0.024, 0.04], density: 0.019, zenith: [0.004, 0.007, 0.02], glow: [0.07, 0.03, 0.008], hemi: [0x4c5c86, 0x1a1914, 0.42], moon: [0xc4d6ff, 0.62], lamp: [0xff7a30, 2.6],
    seed: 23, crates: 46, fire: true, sunOff: [-40, 49, -49] },
  // 1-2: the same docks later that night, a little colder, laid out differently
  5: { fog: [0.024, 0.031, 0.052], density: 0.016, zenith: [0.005, 0.008, 0.019], glow: [0.05, 0.03, 0.03], hemi: [0x5a6c98, 0x2a2422, 0.6], moon: [0xa8bcff, 0.44], lamp: [0xffb060, 1.8], seed: 11, crates: 40, singles: 14, empty: 0.12 },
  // inside the ship: no sky, cold white light, red alarm strips
  4: { indoor: true, ship: true, fog: [0.012, 0.016, 0.026], density: 0.011, zenith: [0.004, 0.006, 0.012], glow: [0.02, 0.03, 0.05], hemi: [0x8aa0d0, 0x34363e, 0.85], moon: [0xe2ecff, 0.75], lamp: [0x9fd4ff, 1.5],
    seed: 61, crates: 24, sunOff: [-18, 70, 22], exposure: 1.12 },
  // the sealed lab: cold fluorescent light from above, a pale tiled floor, red beacons once the alarm goes
  3: { indoor: true, lab: true, ride: true, fog: [0.02, 0.026, 0.032], density: 0.008, zenith: [0.004, 0.006, 0.01], glow: [0.02, 0.03, 0.04], hemi: [0xdfe8f0, 0x5a6066, 0.95], moon: [0xf4f8ff, 0.95], lamp: [0xe6f2ff, 2.2],
    seed: 41, crates: 40, sunOff: [-12, 70, 18], exposure: 1.08 },
  // 3-2: the same lab on the night shift: a little cooler and dimmer, another layout of crates
  8: { indoor: true, lab: true, ride: true, seq: true, fog: [0.016, 0.022, 0.03], density: 0.009, zenith: [0.004, 0.006, 0.01], glow: [0.02, 0.03, 0.04], hemi: [0xd4e0f0, 0x4e5660, 0.85], moon: [0xe8f0ff, 0.85], lamp: [0xd8e8ff, 2.0],
    seed: 43, crates: 40, sunOff: [-12, 70, 18], exposure: 1.02 },
  // 3-1: the old safari at golden hour, a low sun, warm haze over the grass
  7: { day: true, savanna: true, ride: true, fog: [0.30, 0.25, 0.17], density: 0.0058, zenith: [0.10, 0.20, 0.42], glow: [0.55, 0.28, 0.08], hemi: [0xb0c4e0, 0x6b5a3a, 0.62], moon: [0xffd7a8, 1.0], exposure: 0.82,
    lamp: [0xffffff, 0], seed: 41, sunOff: [-70, 38, 25], crates: 46 },
  // 1-1: the docks again, another night, another layout, mist over the water
  6: { fog: [0.03, 0.034, 0.05], density: 0.018, zenith: [0.007, 0.008, 0.016], glow: [0.07, 0.04, 0.024], hemi: [0x5f6f92, 0x2b2420, 0.6], moon: [0xb0c0ff, 0.42], lamp: [0xffa040, 1.85], seed: 19, crates: 40, singles: 12, empty: 0.1 },
};

const World = (() => {
  const hemi = new THREE.HemisphereLight(0x5d6f96, 0x2b2420, 0.62); scene.add(hemi);
  const moon = new THREE.DirectionalLight(0xa8bcff, 0.42);
  moon.castShadow = true; moon.shadow.mapSize.set(isTouch ? 1024 : 2048, isTouch ? 1024 : 2048);
  const sc = moon.shadow.camera; sc.left = -40; sc.right = 40; sc.top = 40; sc.bottom = -40; sc.near = 1; sc.far = 160;
  moon.shadow.bias = -0.0006; moon.shadow.normalBias = 0.03; scene.add(moon); scene.add(moon.target);
  const lights = [];
  for (let i = 0; i < 6; i++) { const L = new THREE.PointLight(0xffa548, 0, 30, 2); scene.add(L); lights.push(L); }
  let group = null, disposables = [], lamps = [], lampT = 0, blink = [], style = STAGE_STYLE[1], sky = null, moonSpr = null, fireMats = null;
  const port = []; // the harbour backdrop: skyline, water, the ship (hidden in the village)
  const keep = (x) => { disposables.push(x); return x; };

  const night = new THREE.Group(); scene.add(night);
  const sun = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex('rgba(255,244,214,1)', 'rgba(255,190,110,0.35)'), fog: false, depthWrite: false }));
  sun.scale.set(70, 70, 1); sun.visible = false; scene.add(sun);
  /* ---- sky, skyline, the ship at the quay: built once ---- */
  (function persistent() {
    sky = new THREE.Mesh(new THREE.SphereGeometry(380, 32, 16), new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false,
      uniforms: { horizon: { value: scene.fog.color }, zenith: { value: new THREE.Color() }, glow: { value: new THREE.Color() } },
      vertexShader: 'varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
      fragmentShader: 'uniform vec3 horizon; uniform vec3 zenith; uniform vec3 glow; varying vec3 vP;\nvoid main(){ float h = normalize(vP).y; vec3 c = mix(horizon, zenith, smoothstep(0.0, 0.6, h));' +
        ' c += glow * exp(-max(h, 0.0) * 12.0) * smoothstep(-0.08, 0.0, h); gl_FragColor = vec4(c, 1.0);\n#include <tonemapping_fragment>\n#include <encodings_fragment>\n}',
    }));
    sky.renderOrder = -10; sky.frustumCulled = false; scene.add(sky);
    const sil = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.007, 0.009, 0.017), fog: false });
    const sil2 = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.011, 0.014, 0.026), fog: false });
    const win = [], skyA = [], skyB = [], b = new THREE.Object3D();
    for (let i = 0; i < 52; i++) {
      const a = (i / 52) * TAU, r = rand(200, 235), h = rand(10, 50), w = rand(10, 24);
      if (Math.cos(a) > 0.55) continue; // the sea side stays open
      const geo = new THREE.BoxGeometry(w, h, rand(10, 20));
      b.position.set(Math.cos(a) * r, h / 2 - 2, Math.sin(a) * r); b.lookAt(0, h / 2, 0); b.updateMatrix(); geo.applyMatrix4(b.matrix);
      (i % 3 ? skyB : skyA).push(geo);
      for (let k = 0; k < h / 4; k++) if (Math.random() < 0.3) win.push(b.position.x + rand(-w / 2, w / 2) * 0.8, rand(1, h - 2), b.position.z + rand(-3, 3));
    }
    const skA = new THREE.Mesh(mergeGeos(skyA), sil), skB = new THREE.Mesh(mergeGeos(skyB), sil2); night.add(skA, skB); port.push(skA, skB);
    const wg = new THREE.BufferGeometry(); wg.setAttribute('position', new THREE.Float32BufferAttribute(win, 3));
    const wins = new THREE.Points(wg, new THREE.PointsMaterial({ color: 0xffc27a, size: 2, sizeAttenuation: false, fog: false })); night.add(wins); port.push(wins);
    const st = [];
    for (let i = 0; i < 600; i++) { const a = rand(0, TAU), e = rand(0.12, 1.4), r = 300; st.push(Math.cos(a) * Math.cos(e) * r, Math.sin(e) * r, Math.sin(a) * Math.cos(e) * r); }
    const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.Float32BufferAttribute(st, 3));
    night.add(new THREE.Points(sg, new THREE.PointsMaterial({ color: 0x8090b8, size: 1.3, sizeAttenuation: false, fog: false, transparent: true, opacity: 0.7 })));
    moonSpr = new THREE.Sprite(new THREE.SpriteMaterial({ map: moonTex(), fog: false, depthWrite: false }));
    moonSpr.position.set(-130, 160, -160); moonSpr.scale.set(55, 55, 1); night.add(moonSpr);
    // water and a container ship moored beyond the quay (east side)
    const water = new THREE.Mesh(new THREE.PlaneGeometry(260, 420), new THREE.MeshStandardMaterial({ color: 0x0a1626, roughness: 0.25, metalness: 0.2 }));
    water.rotation.x = -Math.PI / 2; water.position.set(67 + 130, -2.4, 0); night.add(water); port.push(water);
    const hullMat = new THREE.MeshStandardMaterial({ color: 0x2a1f22, roughness: 0.8, metalness: 0.3 });
    const hull = new THREE.Mesh(mergeBoxes([[32, 15, 230, 0, 5, 0], [26, 4, 20, 0, 4, 118], [24, 26, 18, 0, 25, 88], [18, 8, 12, 0, 42, 88]]), hullMat);
    hull.position.set(96, 0, 0); night.add(hull); port.push(hull);
    const boxMat = new THREE.MeshStandardMaterial({ color: 0x5a3a34, roughness: 0.7 });
    const deck = new THREE.InstancedMesh(new THREE.BoxGeometry(2.44, 2.59, 12.19), boxMat, 360);
    const o = new THREE.Object3D(), cc = new THREE.Color(); let n = 0;
    for (let z = -100; z < 75 && n < 360; z += 12.6) for (let x = -13; x <= 13 && n < 360; x += 2.5) {
      const hgt = 2 + Math.floor(Math.random() * 4);
      for (let k = 0; k < hgt && n < 360; k++) { o.position.set(96 + x, 13.8 + k * 2.6, z); o.updateMatrix(); deck.setMatrixAt(n, o.matrix);
        cc.set(pick(CONT_COLORS)).multiplyScalar(0.7); deck.setColorAt(n, cc); n++; }
    }
    deck.count = n; deck.frustumCulled = false; night.add(deck); port.push(deck);
    const bridgeWin = [];
    for (let i = 0; i < 80; i++) bridgeWin.push(96 + rand(-12, 12), rand(14, 36), 79 - rand(0, 0.5));
    const bw = new THREE.BufferGeometry(); bw.setAttribute('position', new THREE.Float32BufferAttribute(bridgeWin, 3));
    const bwp = new THREE.Points(bw, new THREE.PointsMaterial({ color: 0xfff0c8, size: 2.2, sizeAttenuation: false })); night.add(bwp); port.push(bwp);
    const mast = new THREE.Mesh(new THREE.SphereGeometry(0.7, 8, 6), new THREE.MeshBasicMaterial({ color: 0xff3a3a, fog: false }));
    mast.position.set(96, 47, 88); night.add(mast); blink.push(mast); port.push(mast);
  })();
  const persistentBlink = blink.slice();

  /* ---- textures shared by both stages ---- */
  const asphalt = canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#2a2e35'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 9000, ['#33373f', '#24272d', '#3a3e46', '#1f2227'], 2);
    for (let i = 0; i < 14; i++) { g.fillStyle = 'rgba(10,12,16,' + rand(0.08, 0.2) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(20, 90), rand(10, 50), rand(0, 3), 0, TAU); g.fill(); }
    g.strokeStyle = 'rgba(12,13,16,0.7)'; g.lineWidth = 1.2;
    for (let i = 0; i < 8; i++) { g.beginPath(); let x = rand(0, w), y = rand(0, h); g.moveTo(x, y); for (let k = 0; k < 8; k++) { x += rand(-25, 25); y += rand(-25, 25); g.lineTo(x, y); } g.stroke(); }
  }, 22, 22);
  const concreteTex = canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#7d8088'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 5000, ['#868991', '#73767e', '#8e9199', '#6b6e75'], 2);
    for (let i = 0; i < 10; i++) { const x = rand(0, w), gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(40,40,45,0.35)'); gr.addColorStop(1, 'rgba(40,40,45,0)'); g.fillStyle = gr; g.fillRect(x, 0, rand(3, 14), h); }
  });
  const crateTex = canvasTex(128, 128, (g, w, h) => {
    g.fillStyle = '#7a5a36'; g.fillRect(0, 0, w, h);
    for (let y = 0; y < h; y += 16) { g.fillStyle = y % 32 ? '#6d5030' : '#82603a'; g.fillRect(0, y, w, 15); g.fillStyle = 'rgba(0,0,0,0.35)'; g.fillRect(0, y + 15, w, 1); }
    g.fillStyle = '#5a4026'; g.fillRect(0, 0, w, 10); g.fillRect(0, h - 10, w, 10); g.fillRect(0, 0, 10, h); g.fillRect(w - 10, 0, 10, h);
    g.save(); g.translate(w / 2, h / 2); g.rotate(Math.PI / 4); g.fillRect(-90, -5, 180, 10); g.restore();
    speckle(g, w, h, 300, ['rgba(0,0,0,0.2)', 'rgba(255,220,160,0.08)'], 2);
  });
  const crateMat = new THREE.MeshStandardMaterial({ map: crateTex, roughness: 0.9 });
  const crateGeo = new THREE.BoxGeometry(1.2, 1.2, 1.2);
  const prof = new THREE.Shape();
  prof.moveTo(-0.32, 0); prof.lineTo(0.32, 0); prof.lineTo(0.3, 0.08); prof.lineTo(0.12, 0.3); prof.lineTo(0.1, 0.82); prof.lineTo(-0.1, 0.82); prof.lineTo(-0.12, 0.3); prof.lineTo(-0.3, 0.08); prof.closePath();
  const jerseyGeo = new THREE.ExtrudeGeometry(prof, { depth: 3, bevelEnabled: false }); jerseyGeo.translate(0, 0, -1.5);
  const jerseyMat = new THREE.MeshStandardMaterial({ map: concreteTex, color: 0xd8d6cf, roughness: 0.95 });
  const poolTex = glowTex('rgba(255,200,140,0.5)', 'rgba(255,160,80,0.16)');
  const coneTex = canvasTex(4, 64, (g, w, h) => { const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#ffffff'); gr.addColorStop(0.5, '#555555'); gr.addColorStop(1, '#000000'); g.fillStyle = gr; g.fillRect(0, 0, w, h); });

  function sideTex(color, code, long) {
    const w = long ? 512 : 256, h = 128;
    return keep(canvasTex(w, h, (g) => {
      g.fillStyle = color; g.fillRect(0, 0, w, h);
      for (let x = 0, k = 0; x < w; x += 7, k++) { g.fillStyle = k % 2 ? shade(color, 0.76) : shade(color, 1.14); g.fillRect(x, 6, 3.5, h - 12); }
      g.fillStyle = shade(color, 0.55); g.fillRect(0, 0, w, 6); g.fillRect(0, h - 7, w, 7); g.fillRect(0, 0, 5, h); g.fillRect(w - 5, 0, 5, h);
      for (let i = 0; i < (long ? 14 : 7); i++) { const x = rand(5, w - 5), gr = g.createLinearGradient(0, 6, 0, rand(40, 120));
        gr.addColorStop(0, 'rgba(90,40,20,0.55)'); gr.addColorStop(1, 'rgba(90,40,20,0)'); g.fillStyle = gr; g.fillRect(x, 6, rand(2, 6), 116); }
      speckle(g, w, h, long ? 700 : 350, ['rgba(0,0,0,0.18)', 'rgba(255,255,255,0.06)', 'rgba(80,40,20,0.25)'], 2);
      g.fillStyle = 'rgba(240,236,226,0.92)'; g.textAlign = 'right'; g.font = '600 14px "IBM Plex Mono", monospace';
      g.fillText(code.text, w - 14, 26); g.font = '600 11px "IBM Plex Mono", monospace'; g.fillText(long ? '42G1' : '22G1', w - 14, 41);
      g.textAlign = 'left'; g.font = '34px "Black Han Sans", sans-serif'; g.fillStyle = 'rgba(240,236,226,0.7)'; g.fillText(code.owner.slice(0, 3), 18, 86);
    }));
  }
  function doorTex(color) {
    return keep(canvasTex(128, 128, (g, w, h) => {
      g.fillStyle = color; g.fillRect(0, 0, w, h);
      g.fillStyle = shade(color, 0.6); g.fillRect(0, 0, w, 6); g.fillRect(0, h - 6, w, 6); g.fillRect(0, 0, 6, h); g.fillRect(w - 6, 0, 6, h); g.fillRect(w / 2 - 1.5, 6, 3, h - 12);
      [20, 46, 82, 108].forEach((x) => { g.fillStyle = '#8f949a'; g.fillRect(x - 2, 8, 4, h - 16); g.fillStyle = '#5c6167'; g.fillRect(x - 5, 42, 10, 6); g.fillRect(x - 5, 84, 10, 6); });
      speckle(g, w, h, 220, ['rgba(0,0,0,0.2)', 'rgba(80,40,20,0.3)'], 2);
    }));
  }
  function dispose() {
    if (group) {
      group.traverse((o) => { if (o.geometry && o.geometry !== crateGeo && o.geometry !== jerseyGeo) o.geometry.dispose();
        const m = o.material; if (m) (Array.isArray(m) ? m : [m]).forEach((x) => { if (x !== crateMat && x !== jerseyMat) x.dispose(); }); });
      scene.remove(group);
    }
    disposables.forEach((t) => t.dispose()); disposables = [];
    colliders.length = 0; crates.length = 0; lamps = []; blink = persistentBlink.slice(); fireMats = null;
  }
  return { crateIM: null, night, sun, hemi, moon, lights, crateGeo, crateMat, jerseyGeo, jerseyMat, poolTex, coneTex, asphalt, concreteTex, sideTex, doorTex, dispose, keep,
    get group() { return group; }, set group(g) { group = g; }, get lamps() { return lamps; }, get blink() { return blink; }, get sky() { return sky; },
    get style() { return style; }, set style(s) { style = s; }, get lampT() { return lampT; }, set lampT(v) { lampT = v; },
    port, get moonSpr() { return moonSpr; }, get fireMats() { return fireMats; }, set fireMats(m) { fireMats = m; } };
})();
