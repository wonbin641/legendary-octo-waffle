
/* ============ stage layout: blocks of container stacks with lanes between them ============ */
function buildStage(stage) {
  World.dispose(); Lab.reset(); Ship.reset(); Tower.reset(); Safari.reset(); World.navMask = null; World.menuCam = null; PIT = null;
  const S = STAGE_STYLE[stage]; World.style = S;
  const R = mulberry(S.seed), r = (a, b) => a + R() * (b - a);
  const G = new THREE.Group(); World.group = G; scene.add(G);
  scene.fog.color.setRGB(S.fog[0], S.fog[1], S.fog[2]); scene.fog.density = S.density;
  World.sky.material.uniforms.zenith.value.setRGB(S.zenith[0], S.zenith[1], S.zenith[2]);
  World.sky.material.uniforms.glow.value.setRGB(S.glow[0], S.glow[1], S.glow[2]);
  World.hemi.color.setHex(S.hemi[0]); World.hemi.groundColor.setHex(S.hemi[1]); World.hemi.intensity = S.hemi[2];
  World.moon.color.setHex(S.moon[0]); World.moon.intensity = S.moon[1];
  World.lights.forEach((L) => { L.color.setHex(S.lamp[0]); L.intensity = 0; L.userData.on = false; });
  World.lampT = 0;
  World.night.visible = !S.day; World.sun.visible = !!S.day;
  renderer.toneMappingExposure = S.exposure || 1.15;
  // the harbour skyline and ship only belong to the docks; the village gets the stars and a bigger moon
  World.port.forEach((p) => { p.visible = isYard(stage); });
  World.moonSpr.scale.setScalar(stage === 2 ? 92 : 62);
  World.night.visible = !S.day && !S.indoor;
  if (!isYard(stage)) World.blink.length = 0;
  if (stage === 3 || stage === 8) { setWorldSize(LAB_HALF + 1); setNav(2 * LAB_HALF + 8, 1); return buildLab(G, S, R, r); }
  if (stage === 4) { setWorldSize(166); setNav(334, 1); return buildShip(G, S, R, r); } // 5.16: the bigger main hall reaches x = 162
  if (stage === 7) { setWorldSize(178); setNav(180, 2); return buildSavanna(G, S, R, r); }
  setWorldSize(66); setNav(140, 1);
  if (stage === 2) return buildVillage(G, S, R, r);

  const ground = new THREE.Mesh(new THREE.PlaneGeometry(240, 240), new THREE.MeshStandardMaterial({ map: World.asphalt, roughness: 0.93, color: stage === 2 ? 0xb3bfae : 0xffffff }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; G.add(ground);

  /* perimeter: concrete walls on three sides, the quay edge to the east */
  const E = 67;
  const wallTex = World.keep(World.concreteTex.clone()); wallTex.needsUpdate = true; wallTex.wrapS = wallTex.wrapT = THREE.RepeatWrapping; wallTex.repeat.set(34, 1);
  const wallMat = new THREE.MeshStandardMaterial({ map: wallTex, roughness: 0.95 });
  [[0, -E - 0.6, 2 * E + 2, 1.2], [0, E + 0.6, 2 * E + 2, 1.2], [-E - 0.6, 0, 1.2, 2 * E + 2]].forEach(([x, z, sx, sz]) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(sx, 4.2, sz), wallMat); m.position.set(x, 2.1, z); m.receiveShadow = true; G.add(m);
    addCollider(x - sx / 2, 0, z - sz / 2, x + sx / 2, 10, z + sz / 2, 'concrete');
  });
  const curb = new THREE.Mesh(new THREE.BoxGeometry(1, 0.45, 2 * E + 2), new THREE.MeshStandardMaterial({ map: World.concreteTex, color: 0xc9c6bd, roughness: 0.95 }));
  curb.position.set(E + 0.2, 0.22, 0); curb.receiveShadow = true; G.add(curb);
  addCollider(E - 0.3, 0, -E - 1, E + 1.5, 10, E + 1, 'concrete');
  const bollards = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.22, 0.28, 0.7, 10), new THREE.MeshStandardMaterial({ color: 0x23262b, roughness: 0.6, metalness: 0.5 }), 12);
  const o = new THREE.Object3D();
  for (let i = 0; i < 12; i++) { o.position.set(E - 0.1, 0.8, -60 + i * 11); o.rotation.set(0, 0, 0); o.updateMatrix(); bollards.setMatrixAt(i, o.matrix); }
  bollards.frustumCulled = false; G.add(bollards);

  const occupied = (minx, minz, maxx, maxz, m) => {
    for (const b of colliders) if (maxx + m > b.minx && minx - m < b.maxx && maxz + m > b.minz && minz - m < b.maxz) return true;
    return false;
  };
  const place = [];
  function stack(x, z, long, axis, h) {
    const L = long ? 12.19 : 6.06, hx = axis === 'x' ? L / 2 : 1.22, hz = axis === 'x' ? 1.22 : L / 2;
    if (!h) { const q = R(); h = stage === 2 ? (q < 0.5 ? 1 : q < 0.9 ? 2 : 3) : (q < 0.28 ? 1 : q < 0.74 ? 2 : 3); }
    for (let lv = 0; lv < h; lv++) place.push({ x, z, long, lv, ci: Math.floor(R() * 8), axis });
    addCollider(x - hx, 0, z - hz, x + hx, h * 2.59, z + hz, 'metal');
  }
  for (const bx of [-48, -24, 0, 24, 48]) for (const bz of [-44, -22, 0, 22, 44]) {
    if ((bx === 0 && bz === 0) || R() < S.empty) continue;
    for (let k = 0; k < 4; k++) {
      const z = bz - 3.66 + k * 2.44, p = R();
      if (p < 0.12) continue;
      if (p < 0.34) { if (R() > 0.15) stack(bx - 3.05, z, false, 'x'); if (R() > 0.15) stack(bx + 3.05, z, false, 'x'); }
      else stack(bx, z, true, 'x');
    }
  }

  /* rubber-tyred gantry cranes straddling some blocks */
  const craneMat = new THREE.MeshStandardMaterial({ color: stage === 2 ? 0x8f7f3a : 0xc9a227, roughness: 0.6, metalness: 0.3 });
  const blinkMat = new THREE.MeshBasicMaterial({ color: 0xff3a3a, fog: false });
  (stage === 1 ? [[-24, -22], [24, 22], [-48, 22], [48, -22]] : [[24, 22], [-24, -22], [48, 22]]).forEach(([cx, cz]) => {
    const parts = [];
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) { parts.push([0.9, 21, 0.9, sx * 8.5, 10.5, sz * 6.6]); addCollider(cx + sx * 8.5 - 0.45, 0, cz + sz * 6.6 - 0.45, cx + sx * 8.5 + 0.45, 21, cz + sz * 6.6 + 0.45, 'metal'); }
    parts.push([18.8, 1.3, 1.3, 0, 21, -6.6], [18.8, 1.3, 1.3, 0, 21, 6.6], [1.3, 1.3, 14.5, -8.5, 21, 0], [1.3, 1.3, 14.5, 8.5, 21, 0]);
    parts.push([4, 2, 4, r(-5, 5), 22.6, 0], [2.2, 2.2, 2.2, 8.5, 17.5, -4.8], [1.6, 0.6, 3.6, -8.5, 0.6, 0], [1.6, 0.6, 3.6, 8.5, 0.6, 0]);
    const m = new THREE.Mesh(mergeBoxes(parts), craneMat); m.position.set(cx, 0, cz); m.castShadow = true; m.receiveShadow = true; G.add(m);
    const bl = new THREE.Mesh(new THREE.SphereGeometry(0.4, 8, 6), blinkMat); bl.position.set(cx, 22.3, cz - 6.6); G.add(bl); World.blink.push(bl);
  });

  /* lamp towers: many posts, the six nearest the player get real lights */
  const lampSpots = [];
  for (const x of [-36, -12, 12, 36]) for (const z of [-33, -11, 11, 33]) if (!occupied(x - 0.3, z - 0.3, x + 0.3, z + 0.3, 0.5)) lampSpots.push([x, z]);
  const lit = lampSpots.filter(() => isYard(stage) || R() > 0.3);
  const poles = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.16, 0.22, 16, 8), new THREE.MeshStandardMaterial({ color: 0x3a3f48, roughness: 0.6, metalness: 0.6 }), lampSpots.length);
  const heads = new THREE.InstancedMesh(new THREE.BoxGeometry(1.4, 0.3, 0.7), new THREE.MeshBasicMaterial({ color: stage === 2 ? 0xd8f0c0 : 0xffd08a }), Math.max(1, lit.length));
  const cones = new THREE.InstancedMesh(new THREE.ConeGeometry(6.5, 15, 24, 1, true), new THREE.MeshBasicMaterial({ color: S.lamp[0], map: World.coneTex, transparent: true, opacity: stage === 2 ? 0.07 : 0.1,
    blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }), Math.max(1, lit.length));
  const pools = new THREE.InstancedMesh(new THREE.PlaneGeometry(18, 18), new THREE.MeshBasicMaterial({ map: World.poolTex, color: S.lamp[0], transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }), Math.max(1, lit.length));
  lampSpots.forEach(([x, z], i) => { o.position.set(x, 8, z); o.rotation.set(0, 0, 0); o.updateMatrix(); poles.setMatrixAt(i, o.matrix); addCollider(x - 0.25, 0, z - 0.25, x + 0.25, 16, z + 0.25, 'metal'); });
  lit.forEach(([x, z], i) => {
    o.position.set(x + 0.6, 15.9, z); o.rotation.set(0, 0, 0); o.updateMatrix(); heads.setMatrixAt(i, o.matrix);
    o.position.set(x + 0.6, 8.2, z); o.updateMatrix(); cones.setMatrixAt(i, o.matrix);
    o.position.set(x + 0.6, 0.03, z); o.rotation.set(-Math.PI / 2, 0, 0); o.updateMatrix(); pools.setMatrixAt(i, o.matrix);
    World.lamps.push({ x: x + 0.6, y: 15.2, z, d: 0 });
  });
  heads.count = cones.count = pools.count = lit.length;
  [poles, heads, cones, pools].forEach((m) => { m.frustumCulled = false; G.add(m); }); poles.castShadow = true;

  /* single containers dropped across lanes */
  for (let i = 0, tries = 0; i < S.singles && tries < 300; tries++) {
    const x = r(-58, 58), z = r(-58, 58), axis = R() < 0.5 ? 'z' : 'x';
    const hx = axis === 'x' ? 3.05 : 1.22, hz = axis === 'x' ? 1.22 : 3.05;
    if (Math.hypot(x, z - 6) < 14 || occupied(x - hx, z - hz, x + hx, z + hz, 3)) continue;
    stack(x, z, false, axis, R() < 0.6 ? 1 : 2); i++;
  }
  /* jersey barriers: a ring around the plaza plus some in the lanes */
  const bar = [[-6, -3, 'x'], [6, -3, 'x'], [-9, 6, 'z'], [9, 6, 'z'], [0, 13, 'x'], [-3, -12, 'x'], [4, -14, 'z']];
  for (let i = 0, tries = 0; i < (isYard(stage) ? 16 : 8) && tries < 300; tries++) {
    const x = r(-60, 60), z = r(-60, 60), a = R() < 0.5 ? 'x' : 'z';
    if (occupied(x - 1.6, z - 1.6, x + 1.6, z + 1.6, 1.2)) continue;
    bar.push([x, z, a]); i++;
  }
  const bars = new THREE.InstancedMesh(World.jerseyGeo, World.jerseyMat, bar.length);
  bar.forEach(([x, z, a], i) => {
    o.position.set(x, 0, z); o.rotation.set(0, a === 'x' ? Math.PI / 2 : 0, 0); o.updateMatrix(); bars.setMatrixAt(i, o.matrix);
    if (a === 'x') addCollider(x - 1.5, 0, z - 0.3, x + 1.5, 0.82, z + 0.3, 'concrete'); else addCollider(x - 0.3, 0, z - 1.5, x + 0.3, 0.82, z + 1.5, 'concrete');
  });
  bars.castShadow = bars.receiveShadow = true; bars.frustumCulled = false; G.add(bars);

  /* wooden crates all over the yard: shoot them open for a potion (10% of max HP) */
  placeCrates(G, S.crates, () => [r(-62, 62), r(-62, 62)], (x, z) => Math.hypot(x, z - 6) >= 5 && !occupied(x - 0.6, z - 0.6, x + 0.6, z + 0.6, 0.35));

  /* lane paint */
  const paint = new THREE.MeshStandardMaterial({ color: stage === 2 ? 0x8a7c44 : 0xc9962c, roughness: 0.85 });
  const dash = [];
  for (const z of [-33, -11, 11, 33]) for (let t = -64; t <= 64; t += 4) dash.push([t, z, 0]);
  for (const x of [-36, -12, 12, 36]) for (let t = -64; t <= 64; t += 4) dash.push([x, t, 1]);
  const dashes = new THREE.InstancedMesh(new THREE.PlaneGeometry(2.2, 0.16), paint, dash.length);
  let nd = 0;
  dash.forEach(([x, z, rot]) => { if (occupied(x - 0.1, z - 0.1, x + 0.1, z + 0.1, 0)) return;
    o.position.set(x, 0.012, z); o.rotation.set(-Math.PI / 2, 0, rot ? Math.PI / 2 : 0); o.updateMatrix(); dashes.setMatrixAt(nd++, o.matrix); });
  dashes.count = nd; dashes.receiveShadow = true; dashes.frustumCulled = false; G.add(dashes);
  const t07 = World.keep(canvasTex(256, 128, (g, w, h) => { g.fillStyle = 'rgba(201,150,44,0.9)'; g.font = '96px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('07', w / 2, h / 2 + 4); }));
  const lbl = new THREE.Mesh(new THREE.PlaneGeometry(10, 5), new THREE.MeshStandardMaterial({ map: t07, transparent: true, roughness: 0.85, depthWrite: false, opacity: stage === 2 ? 0.6 : 1 }));
  lbl.rotation.x = -Math.PI / 2; lbl.position.set(0, 0.014, 1); lbl.receiveShadow = true; G.add(lbl);

  /* containers, instanced per colour and length */
  const groups = {};
  place.forEach((p) => { const k = p.ci + '_' + (p.long ? 1 : 0); (groups[k] = groups[k] || []).push(p); });
  const doorM = {}, topM = {};
  let serial = 418203 + stage * 1111;
  Object.keys(groups).forEach((k) => {
    const list = groups[k], ci = list[0].ci, long = list[0].long, color = CONT_COLORS[ci];
    serial = (serial * 7 + 1301) % 1000000;
    const code = isoCode(OWNERS[(ci * 3 + (long ? 1 : 0)) % OWNERS.length], serial);
    const side = new THREE.MeshStandardMaterial({ map: World.sideTex(color, code, long), roughness: 0.62, metalness: 0.3 });
    const door = doorM[ci] || (doorM[ci] = new THREE.MeshStandardMaterial({ map: World.doorTex(color), roughness: 0.62, metalness: 0.3 }));
    const top = topM[ci] || (topM[ci] = new THREE.MeshStandardMaterial({ color: shade(color, 0.75), roughness: 0.75, metalness: 0.25 }));
    const im = new THREE.InstancedMesh(new THREE.BoxGeometry(long ? 12.19 : 6.06, 2.59, 2.44), [door, door, top, top, side, side], list.length);
    list.forEach((p, i) => { o.position.set(p.x, 1.295 + p.lv * 2.59, p.z); o.rotation.set(0, p.axis === 'z' ? Math.PI / 2 : 0, 0); o.updateMatrix(); im.setMatrixAt(i, o.matrix); });
    im.castShadow = im.receiveShadow = true; im.frustumCulled = false; G.add(im);
  });

  indexColliders(); buildNav();
  const spawns = [];
  for (const x of [-61, -36, -12, 12, 36, 61]) for (const z of [-61, -33, -11, 11, 33, 61]) {
    const [i, j] = navCell(x, z);
    if (!NAV.blocked[j * NAV.n + i] && Math.hypot(x, z) > 14) spawns.push({ x, z });
  }
  return { start: { x: 0, z: 6, yaw: 0 }, spawns };
}

function updateWorld(dt, t, px, pz) {
  World.lampT -= dt;
  if (World.lampT <= 0) {
    World.lampT = 0.35;
    const L = World.lamps; L.forEach((l) => { l.d = (l.x - px) * (l.x - px) + (l.z - pz) * (l.z - pz); });
    const near = L.slice().sort((a, b) => a.d - b.d);
    World.lights.forEach((light, i) => { const s = near[i]; light.userData.on = !!s; if (s) light.position.set(s.x, s.y, s.z); });
  }
  const S = World.style;
  World.lights.forEach((light, i) => {
    let k = light.userData.on ? S.lamp[1] : 0;
    if (S.flicker && k) k *= (Math.sin(t * 17 + i * 5.3) > 0.94 ? 0.2 : 1) * (0.85 + 0.15 * Math.sin(t * 2.7 + i));
    if (S.fire && k) k *= 0.72 + 0.18 * Math.sin(t * 13 + i * 2.1) + 0.1 * Math.sin(t * 29 + i * 5.7);
    light.intensity = k;
  });
  const texel = 80 / World.moon.shadow.mapSize.x, sx = Math.round(px / texel) * texel, sz = Math.round(pz / texel) * texel;
  const off = S.sunOff || [-30, 50, -20];
  World.moon.position.set(sx + off[0], off[1], sz + off[2]); World.moon.target.position.set(sx, 0, sz);
  if (S.day) { const l = Math.hypot(off[0], off[1], off[2]); World.sun.position.set(camera.position.x + off[0] / l * 330, camera.position.y + off[1] / l * 330, camera.position.z + off[2] / l * 330); }
  World.blink.forEach((b, i) => { b.visible = ((t + i * 0.3) % 1.8) < 0.25; });
  if (World.fireMats) for (const m of World.fireMats) m.uniforms.t.value = t;
  if (S.lab) Lab.anim(dt, t);
  if (S.ship) Ship.anim(dt, t);
}

/* crates share one instanced mesh; a broken crate's instance is collapsed */
function placeCrates(G, count, cand, fits) {
  const o = new THREE.Object3D(), im = new THREE.InstancedMesh(World.crateGeo, World.crateMat, Math.max(1, count));
  for (let i = 0, tries = 0; i < count && tries < count * 40; tries++) {
    const [x, z, y0] = cand(), y = y0 || 0; if (!fits(x, z, y)) continue;
    o.position.set(x, y + 0.6, z); o.rotation.set(0, rand(-0.2, 0.2), 0); o.updateMatrix(); im.setMatrixAt(i, o.matrix);
    const c = { idx: i, hp: 45, x, z, y, dead: false };
    c.b = addCollider(x - 0.6, y, z - 0.6, x + 0.6, y + 1.2, z + 0.6, 'wood', c); crates.push(c); i++;
  }
  im.count = crates.length; im.castShadow = im.receiveShadow = true; im.frustumCulled = false; G.add(im); World.crateIM = im;
}
const _crateZero = new THREE.Matrix4();
function damageCrate(c, dmg, p) {
  if (c.dead) return;
  c.hp -= dmg;
  FX.sparks(p, 4, [0.85, 0.65, 0.4], 2.5);
  if (c.hp > 0) return;
  c.dead = true;
  const im = World.crateIM; _crateZero.makeScale(0, 0, 0); im.setMatrixAt(c.idx, _crateZero); im.instanceMatrix.needsUpdate = true;
  removeCollider(c.b); navPatch(c.b.minx, c.b.minz, c.b.maxx, c.b.maxz); // 5.20: just round it, not the whole grid
  const at = { x: c.x, y: (c.y || 0) + 0.6, z: c.z };
  FX.chunks(at, 9, 0.28, 'wood'); FX.puff(at, 4, 0.35, 0.6); Sound.crack(at);
  Game.onCrate(c);
}
