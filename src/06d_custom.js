/* ============ 5.14: gun customisation. three slots of parts (sight, muzzle, underbarrel), each a small trade rather than a plain upgrade,
   and a paint colour, set gun by gun and kept on this device (settings.gunCustom). WEAPONS holds the base numbers times whatever the parts
   do, so everything that reads a gun (firing, the shop, the codex) sees it as you have built it ============ */
const PARTS = {
  sight: { name: '조준기', list: [
    { id: 'iron', name: '기본 가늠쇠', desc: '그대로' },
    { id: 'dot', name: '레드닷', desc: '정조준 속도 +25% · 정조준 퍼짐 -15%', mod: { adsSpeed: 1.25, adsSpread: 0.85 } },
    { id: 'holo', name: '홀로그램', desc: '정조준 퍼짐 -30% · 정조준 속도 +10%', mod: { adsSpread: 0.7, adsSpeed: 1.1 } },
    { id: 'x2', name: '2배율 조준경', desc: '정조준하면 더 크게 확대 · 정조준 퍼짐 -40% · 정조준 속도 -20%', mod: { adsFov: 0.55, adsSpread: 0.6, adsSpeed: 0.8 } }] },
  muzzle: { name: '총구', list: [
    { id: 'none', name: '없음', desc: '그대로' },
    { id: 'sup', name: '소음기', desc: '총소리가 들리는 거리 -60% · 섬광 작게 · 데미지 -8%', mod: { noise: 0.4, flash: 0.35, dmg: 0.92 } },
    { id: 'comp', name: '보정기', desc: '반동 -25% · 총소리가 들리는 거리 +15%', mod: { recoil: 0.75, kick: 0.8, noise: 1.15 } },
    { id: 'hider', name: '소염기', desc: '섬광 -70% · 반동 -10%', mod: { flash: 0.3, recoil: 0.9 } }] },
  under: { name: '하부', list: [
    { id: 'none', name: '없음', desc: '그대로' },
    { id: 'vgrip', name: '수직 손잡이', desc: '반동 -20% · 연사할 때 퍼짐 -25%', mod: { recoil: 0.8, bloom: 0.75 } },
    { id: 'agrip', name: '앵글 손잡이', desc: '정조준 속도 +20% · 움직이며 쏠 때 퍼짐 -20%', mod: { adsSpeed: 1.2, moveSpread: 0.8 } },
    { id: 'laser', name: '레이저', desc: '정조준 없이 쏠 때 퍼짐 -25% · 조준한 곳에 빨간 점', mod: { spread: 0.75 } }] },
};
const PAINTS = [
  { id: 'base', name: '기본' }, { id: 'black', name: '검정', c: 0x1b1c1f }, { id: 'gray', name: '회색', c: 0x7d838c }, { id: 'tan', name: '사막', c: 0xb39466 },
  { id: 'olive', name: '올리브', c: 0x59633f }, { id: 'silver', name: '은색', c: 0xc9ced6, metal: 0.85, rough: 0.25 }, { id: 'gold', name: '금색', c: 0xd8a531, metal: 0.95, rough: 0.2 },
  { id: 'red', name: '빨강', c: 0xa8231d }, { id: 'blue', name: '파랑', c: 0x2a58a8 }, { id: 'pink', name: '분홍', c: 0xe27aa8 },
];
/* where parts go on each gun, in the gun's own space: the rail top for a sight, the barrel's thickness for the muzzle, the spot under the
   barrel. the sniper keeps its scope; the grenade and rocket launchers have no muzzle to fit; on a pistol or the grenade launcher only a laser */
const MOUNTS = {
  pistol: { sight: { y: 0.032, z: -0.035 }, muzzle: { r: 0.012, len: 0.08 }, under: { y: -0.031, z: -0.095, laserOnly: true } },
  shotgun: { sight: { y: 0.0325, z: -0.02 }, muzzle: { r: 0.018, len: 0.12 }, under: { y: -0.047, z: -0.33 } },
  rifle: { sight: { y: 0.048, z: -0.07 }, muzzle: { r: 0.012, len: 0.13 }, under: { y: -0.034, z: -0.29 } },
  smg: { sight: { y: 0.031, z: -0.075 }, muzzle: { r: 0.011, len: 0.11 }, under: { y: -0.031, z: -0.12 } },
  sniper: { sight: null, muzzle: { r: 0.012, len: 0.15 }, under: { y: -0.06, z: -0.3 } },
  gl: { sight: { y: 0.0725, z: 0.04 }, muzzle: null, under: { y: -0.045, z: -0.1, laserOnly: true } },
  lmg: { sight: { y: 0.085, z: 0.02 }, muzzle: { r: 0.014, len: 0.14 }, under: { y: -0.045, z: -0.3 } },
  rocket: { sight: null, muzzle: null, under: null },
};
const SLOTS = ['sight', 'muzzle', 'under'];
const WBASE = {}; ORDER.forEach((id) => { WBASE[id] = Object.assign({}, WEAPONS[id]); });
const MOD_KEYS = ['dmg', 'spread', 'adsSpread', 'moveSpread', 'recoil', 'kick', 'bloom', 'adsFov', 'adsSpeed', 'flash'];
const partOf = (slot, pid) => PARTS[slot].list.find((p) => p.id === pid) || PARTS[slot].list[0];
/* what fits: a slot the gun does not have is empty, and where only a laser goes underneath anything else falls back to nothing */
function fits(id, slot, pid) { const M = MOUNTS[id][slot]; if (!M) return pid === PARTS[slot].list[0].id; if (slot === 'under' && M.laserOnly) return pid === 'none' || pid === 'laser'; return true; }
function gunSetup(id) {
  const c = (settings.gunCustom && settings.gunCustom[id]) || {}, s = {};
  for (const slot of SLOTS) { const pid = c[slot] || PARTS[slot].list[0].id; s[slot] = fits(id, slot, pid) ? pid : PARTS[slot].list[0].id; }
  s.paint = PAINTS.some((p) => p.id === c.paint) ? c.paint : 'base';
  return s;
}
/* the multipliers the chosen parts give, all three together */
function gunMods(s) { const mul = {}; for (const slot of SLOTS) { const m = partOf(slot, s[slot]).mod || {}; for (const k in m) mul[k] = (mul[k] || 1) * m[k]; } return mul; }

/* ---------- the parts, built once for every gun and shown or hidden as chosen ---------- */
(function buildParts() {
  const dk = new THREE.MeshStandardMaterial({ color: 0x1c1f24, roughness: 0.45, metalness: 0.55 });
  const dk2 = new THREE.MeshStandardMaterial({ color: 0x2a2e35, roughness: 0.6, metalness: 0.35 });
  const glass = new THREE.MeshBasicMaterial({ color: 0x9fd8ff, transparent: true, opacity: 0.16, depthWrite: false, side: THREE.DoubleSide });
  const redM = new THREE.MeshBasicMaterial({ color: 0xff2a1a, toneMapped: false });
  const beamM = new THREE.MeshBasicMaterial({ color: 0xff2a1a, transparent: true, opacity: 0.45, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
  const tubeM = new THREE.MeshStandardMaterial({ color: 0x1c1f24, roughness: 0.45, metalness: 0.55, side: THREE.DoubleSide });
  const mesh = (grp, geo, m, x, y, z, rx) => { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); if (rx) o.rotation.x = rx; o.frustumCulled = false; grp.add(o); return o; };
  const bx = (grp, w, h, d, m, x, y, z, rx) => mesh(grp, new THREE.BoxGeometry(w, h, d), m, x, y, z, rx);
  const tube = (grp, r, len, m, y, z, open) => { const o = mesh(grp, new THREE.CylinderGeometry(r, r, len, 18, 1, !!open), m, 0, y, z); o.rotation.x = Math.PI / 2; return o; };
  ORDER.forEach((id) => {
    const g = gunModels[id], M = MOUNTS[id], ys = g.userData.sightY, mz = g.userData.mz, parts = { sight: {}, muzzle: {}, under: {} };
    const iron = []; g.traverse((o) => { if (o.isMesh && o.material && o.material.userData && o.material.userData.iron) iron.push(o); }); g.userData.iron = iron;
    const add = (slot, pid) => { const p = new THREE.Group(); p.visible = false; g.add(p); parts[slot][pid] = p; return p; };
    if (M.sight) {
      const y0 = M.sight.y, z0 = M.sight.z;
      // red dot: a short open tube on a riser, a faint lens at the front and the dot itself on the eye line
      let p = add('sight', 'dot'); bx(p, 0.022, Math.max(0.004, ys - y0 - 0.012), 0.03, dk, 0, (y0 + ys - 0.012) / 2, z0);
      tube(p, 0.0135, 0.04, tubeM, ys, z0, true); mesh(p, new THREE.CircleGeometry(0.0128, 18), glass, 0, ys, z0 - 0.02);
      mesh(p, new THREE.SphereGeometry(0.0011, 8, 6), redM, 0, ys, z0 - 0.019);
      // holographic: a square window in a frame, a red ring and dot floating in it
      p = add('sight', 'holo'); bx(p, 0.03, Math.max(0.004, ys - y0 - 0.017), 0.045, dk, 0, (y0 + ys - 0.017) / 2, z0);
      bx(p, 0.042, 0.005, 0.016, dk, 0, ys + 0.017, z0 - 0.012); for (const sx of [-1, 1]) bx(p, 0.005, 0.036, 0.016, dk, sx * 0.0205, ys, z0 - 0.012);
      mesh(p, new THREE.PlaneGeometry(0.036, 0.03), glass, 0, ys, z0 - 0.014);
      const ring = mesh(p, new THREE.TorusGeometry(0.0042, 0.0005, 6, 24), redM, 0, ys, z0 - 0.0145); ring.rotation.set(0, 0, 0);
      mesh(p, new THREE.SphereGeometry(0.0008, 8, 6), redM, 0, ys, z0 - 0.0145);
      // 2x: a longer tube with flared ends on two rings, a dark crosshair on the front lens
      p = add('sight', 'x2'); for (const dz of [0.02, -0.02]) bx(p, 0.012, Math.max(0.004, ys - y0 - 0.014), 0.012, dk, 0, (y0 + ys - 0.014) / 2, z0 + dz);
      tube(p, 0.0155, 0.075, tubeM, ys, z0, true); tube(p, 0.0185, 0.014, tubeM, ys, z0 + 0.04, true); tube(p, 0.0185, 0.014, tubeM, ys, z0 - 0.04, true);
      mesh(p, new THREE.CircleGeometry(0.015, 20), glass, 0, ys, z0 - 0.0375);
      bx(p, 0.028, 0.0006, 0.0006, dk, 0, ys, z0 - 0.037); bx(p, 0.0006, 0.028, 0.0006, dk, 0, ys, z0 - 0.037); mesh(p, new THREE.SphereGeometry(0.0007, 8, 6), redM, 0, ys, z0 - 0.0368);
    }
    if (M.muzzle) {
      const r = M.muzzle.r, L = M.muzzle.len;
      let p = add('muzzle', 'sup'); tube(p, r * 1.5, L, dk, mz.y, mz.z - L / 2); tube(p, r * 1.55, 0.006, dk2, mz.y, mz.z - L + 0.004);
      p = add('muzzle', 'comp'); tube(p, r * 1.35, 0.04, dk, mz.y, mz.z - 0.02); for (const dz of [-0.012, -0.026]) bx(p, r * 1.6, 0.004, 0.006, dk2, 0, mz.y + r * 1.3, mz.z + dz);
      p = add('muzzle', 'hider'); tube(p, r * 1.2, 0.02, dk, mz.y, mz.z - 0.01);
      for (let i = 0; i < 3; i++) { const a = (i / 3) * Math.PI * 2 + 0.5, pr = bx(p, 0.004, 0.004, 0.034, dk, Math.cos(a) * r * 1.05, mz.y + Math.sin(a) * r * 1.05, mz.z - 0.035); pr.rotation.z = a; }
    }
    if (M.under) {
      const uy = M.under.y, uz = M.under.z;
      if (!M.under.laserOnly) {
        let p = add('under', 'vgrip'); bx(p, 0.024, 0.085, 0.028, dk2, 0, uy - 0.044, uz); bx(p, 0.028, 0.008, 0.032, dk, 0, uy - 0.003, uz); bx(p, 0.028, 0.006, 0.032, dk, 0, uy - 0.087, uz);
        p = add('under', 'agrip'); bx(p, 0.026, 0.008, 0.06, dk, 0, uy - 0.003, uz); const w = bx(p, 0.024, 0.032, 0.07, dk2, 0, uy - 0.022, uz + 0.004); w.rotation.x = -0.55;
      }
      const p = add('under', 'laser'); bx(p, 0.02, 0.018, 0.05, dk, 0, uy - 0.012, uz); mesh(p, new THREE.SphereGeometry(0.0028, 8, 6), redM, 0, uy - 0.012, uz - 0.026);
      bx(p, 0.0016, 0.0016, 0.9, beamM, 0, uy - 0.012, uz - 0.026 - 0.45); // a faint beam out ahead of the gun
    }
    g.userData.parts = parts;
  });
})();
/* the gun's look: which parts show, the iron sights under an optic, the muzzle flash at the end of whatever is on the muzzle, and the paint
   (the receiver takes the colour, the furniture a darker shade of it; silver and gold are shinier) */
function applyLook(id, s) {
  const g = gunModels[id], P = g.userData.parts; if (!P) return;
  for (const slot of SLOTS) for (const k in P[slot]) P[slot][k].visible = s[slot] === k;
  for (const m of g.userData.iron) m.visible = s.sight === 'iron';
  const M = MOUNTS[id], ext = !M.muzzle ? 0 : s.muzzle === 'sup' ? M.muzzle.len : s.muzzle === 'comp' ? 0.04 : s.muzzle === 'hider' ? 0.05 : 0;
  g.userData.flash.position.z = g.userData.mz.z - ext;
  const p = PAINTS.find((q) => q.id === s.paint) || PAINTS[0], tint = new THREE.Color();
  for (const m of GUN_MATS[id].body) {
    const u = m.userData, recv = u.metal !== undefined && u.metal >= 0.3; // the receiver is the metallic one
    if (p.c === undefined) { m.color.setHex(u.color); m.metalness = u.metal; m.roughness = u.rough; u.paintColor = undefined; continue; }
    tint.setHex(p.c); if (!recv) tint.multiplyScalar(0.68);
    m.color.copy(tint); u.paintColor = tint.getHex();
    m.metalness = p.metal !== undefined ? (recv ? p.metal : p.metal * 0.6) : u.metal; m.roughness = p.rough !== undefined ? (recv ? p.rough : p.rough + 0.2) : u.rough;
  }
  if (id === 'lmg' && wstate.lmg) wstate.lmg.glowK = undefined; // the heat tint goes over the new colour
}
/* the numbers: base times the parts, and the look to match */
function applyCustom(id) {
  const s = gunSetup(id), W = WEAPONS[id], B = WBASE[id], mul = gunMods(s);
  for (const k of MOD_KEYS) { const b = B[k] !== undefined ? B[k] : k === 'adsSpeed' ? 7 : undefined; if (b !== undefined) W[k] = b * (mul[k] || 1); }
  W.noise = mul.noise || 1; W.parts = s;
  applyLook(id, s);
}
ORDER.forEach(applyCustom);

/* the laser's red dot, out in the world where the crosshair falls */
const LaserDot = (() => {
  let s = null; const _f = new THREE.Vector3();
  function update() {
    const W = WEAPONS[Gun.cur], on = state === 'playing' && !Gun.none && W.parts && W.parts.under === 'laser' && Gun.switchT <= 0 && Gun.reloadT <= 0;
    if (!on) { if (s) s.visible = false; return; }
    if (!s) { s = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex('rgba(255,90,70,1)', 'rgba(255,20,10,0)'), color: 0xff3a2a, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false })); s.renderOrder = 5; scene.add(s); }
    camera.getWorldDirection(_f); const o = camera.position;
    if (!raycastStatic(o.x, o.y, o.z, _f.x, _f.y, _f.z, 90)) { s.visible = false; return; }
    const t = RH.t - 0.04; s.position.set(o.x + _f.x * t, o.y + _f.y * t, o.z + _f.z * t); s.scale.setScalar(0.035 + t * 0.0035); s.visible = true;
  }
  return { update };
})();

/* ---------- the customisation screen: the gun turning slowly on one side (drag to turn it yourself), the choices on the other ---------- */
const Custom = (() => {
  const C = { on: false, id: 'rifle', from: 'menu', ang: 0.6, drag: null, idleT: 0 };
  const cam = new THREE.PerspectiveCamera(28, 1, 0.01, 10), _sz = new THREE.Vector2(), _b = new THREE.Box3(), _c = new THREE.Vector3(), _s = new THREE.Vector3();
  // 5.17: on a touch screen a dark veil behind the gun so it stands out from the busy scene behind it (the gun itself stays bright);
  // it is in the first-person scene, so it is only switched on for the moment the preview is drawn
  const veil = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.72, depthWrite: false }));
  veil.visible = false; veil.scale.setScalar(40); viewScene.add(veil);
  const LBL = { adsSpeed: '정조준 속도', adsSpread: '정조준 퍼짐', spread: '정조준 없이 퍼짐', moveSpread: '움직일 때 퍼짐', recoil: '반동', bloom: '연사 퍼짐', flash: '섬광', noise: '총소리 거리', dmg: '데미지' };
  const el = (tag, cls, text) => { const d = document.createElement(tag); if (cls) d.className = cls; if (text !== undefined) d.textContent = text; return d; };
  function frame(id) {
    // the gun's size without the hands, to fit it in the view
    const g = gunModels[id]; viewRoot.position.set(0, 0, 0); viewRoot.rotation.set(0, 0, 0); viewRoot.updateMatrixWorld(true); _b.makeEmpty();
    g.traverse((o) => { if (o.isMesh && !o.userData.hand && o !== g.userData.flash && o.visible !== false && (!o.parent || o.parent.visible !== false)) { o.geometry.computeBoundingBox(); _b.union(o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld)); } });
    _b.getCenter(_c); _b.getSize(_s); C.c = _c.clone(); C.size = Math.max(_s.z, _s.y * 2.2, 0.25);
  }
  function show(id) {
    for (const k of ORDER) { const g = gunModels[k]; g.visible = k === id; g.traverse((o) => { if (o.userData.hand) o.visible = !C.on; }); g.userData.flash.visible = false; }
    frame(id);
  }
  function setPart(slot, pid) { const c = settings.gunCustom || (settings.gunCustom = {}); const cur = Object.assign({}, gunSetup(C.id)); cur[slot] = pid; c[C.id] = cur; store('yard07.settings', settings); applyCustom(C.id); show(C.id); render(); }
  function render() {
    const id = C.id, W = WEAPONS[id], s = gunSetup(id), M = MOUNTS[id];
    const tabs = $('cutabs'); tabs.textContent = '';
    for (const k of ORDER) { const b = el('button', k === id ? 'on' : '', WEAPONS[k].tab); b.type = 'button'; b.setAttribute('aria-pressed', k === id ? 'true' : 'false'); b.addEventListener('click', () => { C.id = k; show(k); render(); }); tabs.append(b); }
    $('cuname').textContent = W.model + ' ' + W.name; $('cusub').textContent = W.cls + (gunAvailable(id) ? '' : ' · 지금은 가지고 있지 않은 총 (꾸민 대로 대여하면 씁니다)');
    const box = $('cuslots'); box.textContent = '';
    for (const slot of SLOTS) {
      const row = el('div', 'curow'); row.append(el('h3', null, PARTS[slot].name));
      if (!M[slot]) { row.append(el('p', 'note', id === 'sniper' && slot === 'sight' ? '저격총은 자기 조준경을 씁니다' : '이 총에는 달 수 없습니다')); box.append(row); continue; }
      const chips = el('div', 'cuchips');
      for (const p of PARTS[slot].list) {
        if (!fits(id, slot, p.id)) continue;
        const b = el('button', s[slot] === p.id ? 'on' : '', p.name); b.type = 'button'; b.setAttribute('aria-pressed', s[slot] === p.id ? 'true' : 'false');
        b.addEventListener('click', () => setPart(slot, p.id)); chips.append(b);
      }
      row.append(chips, el('p', 'cudesc', partOf(slot, s[slot]).desc)); box.append(row);
    }
    const pb = $('cupaint'); pb.textContent = '';
    for (const p of PAINTS) {
      const b = el('button', 'swatch' + (s.paint === p.id ? ' on' : '')); b.type = 'button'; b.title = p.name; b.setAttribute('aria-label', p.name + ' 색'); b.setAttribute('aria-pressed', s.paint === p.id ? 'true' : 'false');
      b.style.background = p.c === undefined ? 'linear-gradient(135deg, #3b4048 50%, #24272c 50%)' : '#' + p.c.toString(16).padStart(6, '0');
      b.append(el('span', null, p.name)); b.addEventListener('click', () => setPart('paint', p.id)); pb.append(b);
    }
    // all three parts together, in plain numbers
    const mul = gunMods(s), out = [];
    for (const k in LBL) if (mul[k] && Math.abs(mul[k] - 1) > 0.001) out.push(LBL[k] + ' ' + (mul[k] > 1 ? '+' : '') + Math.round((mul[k] - 1) * 100) + '%');
    if (mul.adsFov && mul.adsFov < 1) out.unshift('정조준 확대 ×' + (1 / mul.adsFov).toFixed(1));
    $('cueffect').textContent = out.length ? '이 조합: ' + out.join(' · ') : '부속 효과 없음 · 기본 상태';
  }
  function open(from) {
    C.from = from; C.on = true; C.idleT = 0; if (!ORDER.includes(C.id)) C.id = 'rifle';
    showOnly('custom'); show(C.id); render(); $('custom').scrollTop = 0; setTimeout(() => $('cuclose').focus({ preventScroll: true }), 0);
  }
  function close() {
    C.on = false; $('custom').hidden = true;
    for (const k of ORDER) { const g = gunModels[k]; g.visible = false; g.traverse((o) => { if (o.userData.hand) o.visible = true; }); }
    viewRoot.position.set(0, 0, 0); viewRoot.rotation.set(0, 0, 0);
    backTo(C.from);
  }
  /* drawn over the menu scene, into the empty part of the screen beside the sheet */
  function draw(dt) {
    if (!C.on) return;
    const r = $('cuview').getBoundingClientRect(), cr = renderer.domElement.getBoundingClientRect();
    const x = r.left - cr.left, y = cr.bottom - r.bottom, w = Math.min(r.width, cr.width - x), h = Math.min(r.height, cr.bottom - r.top);
    if (w < 40 || h < 40) return;
    if (!C.drag) { C.idleT += dt; if (C.idleT > 1.5) C.ang += dt * 0.45; }
    const a = C.ang, cx = C.c.x, cy = C.c.y, cz = C.c.z, co = Math.cos(a), si = Math.sin(a);
    viewRoot.rotation.set(0, a, 0); viewRoot.position.set(-(cx * co + cz * si), -cy, -(-cx * si + cz * co));
    cam.aspect = w / h; const fh = 2 * Math.tan((cam.fov * Math.PI) / 360), d = (C.size / Math.min(fh * cam.aspect, fh * 1.6)) * 1.25;
    cam.position.set(d, d * 0.16, 0.0001); cam.lookAt(0, 0, 0); cam.updateProjectionMatrix();
    renderer.getSize(_sz);
    renderer.setRenderTarget(null); renderer.setScissorTest(true); renderer.setScissor(x, y, w, h); renderer.setViewport(x, y, w, h);
    if (isTouch) { veil.position.copy(cam.position).multiplyScalar(-1.1); veil.lookAt(cam.position); veil.visible = true; }
    renderer.clearDepth(); renderer.render(viewScene, cam); veil.visible = false;
    renderer.setScissorTest(false); renderer.setViewport(0, 0, _sz.x, _sz.y);
  }
  const view = $('cuview');
  view.addEventListener('pointerdown', (e) => { C.drag = { x: e.clientX, a: C.ang }; C.idleT = 0; view.setPointerCapture(e.pointerId); });
  view.addEventListener('pointermove', (e) => { if (C.drag) C.ang = C.drag.a + (e.clientX - C.drag.x) * 0.012; });
  const up = () => { C.drag = null; C.idleT = 0; }; view.addEventListener('pointerup', up); view.addEventListener('pointercancel', up);
  $('cuclose').addEventListener('click', () => close());
  $('cureset').addEventListener('click', () => { if (settings.gunCustom) delete settings.gunCustom[C.id]; store('yard07.settings', settings); applyCustom(C.id); show(C.id); render(); });
  return Object.assign(C, { open, close, draw, render });
})();
