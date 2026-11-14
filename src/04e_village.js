
/* ============ stage 2: a village of log huts at night, several of them burning, under a big moon ============ */
function buildVillage(G, S, R, r) {
  const keep = World.keep, B = AnimalKit.geoBox, M = AnimalKit.merge, o = new THREE.Object3D();
  const pickR = (a) => a[Math.floor(R() * a.length)];
  const LOG = ['#5b4532', '#4f3b2a', '#664d36', '#563f2d'], CHAR = ['#1d1712', '#261d16', '#16120e', '#2e231a'];
  const ROOF = ['#46382a', '#3d3124', '#4b3c2b'];
  const occupied = (minx, minz, maxx, maxz, m) => {
    for (const b of colliders) if (maxx + m > b.minx && minx - m < b.maxx && maxz + m > b.minz && minz - m < b.maxz) return true;
    return false;
  };

  /* ground: trampled earth and dark grass */
  const dirt = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#25261b'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 9000, ['#2e2d21', '#201f16', '#2a3121', '#1c2317', '#33301f'], 2.2);
    for (let i = 0; i < 18; i++) { g.fillStyle = 'rgba(' + (i % 2 ? '38,52,30' : '60,48,32') + ',' + rand(0.15, 0.35) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(20, 80), rand(10, 50), rand(0, 3), 0, TAU); g.fill(); }
    g.lineWidth = 1;
    for (let i = 0; i < 1600; i++) { const x = Math.random() * w, y = Math.random() * h; g.strokeStyle = pick(['rgba(45,64,32,0.55)', 'rgba(72,82,46,0.4)', 'rgba(28,38,20,0.6)']); g.beginPath(); g.moveTo(x, y); g.lineTo(x + rand(-2, 2), y - rand(3, 7)); g.stroke(); }
  }, 24, 24));
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(260, 260), new THREE.MeshStandardMaterial({ map: dirt, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; G.add(ground);

  /* the edge of the village: a palisade of sharpened logs */
  const E = 67;
  [[0, -E - 0.6, 2 * E + 2, 1.2], [0, E + 0.6, 2 * E + 2, 1.2], [-E - 0.6, 0, 1.2, 2 * E + 2], [E + 0.6, 0, 1.2, 2 * E + 2]].forEach(([x, z, sx, sz]) => addCollider(x - sx / 2, 0, z - sz / 2, x + sx / 2, 10, z + sz / 2, 'wood'));
  const stakes = [];
  for (let t = -E; t <= E; t += 0.52) stakes.push([t, -E - 0.3], [t, E + 0.3], [-E - 0.3, t], [E + 0.3, t]);
  const stakeIM = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.05, 0.21, 1, 7), new THREE.MeshStandardMaterial({ color: 0x3a2b1d, roughness: 0.95 }), stakes.length);
  stakes.forEach(([x, z], i) => { const h = r(2.7, 3.5); o.position.set(x, h / 2, z); o.scale.set(1, h, 1); o.rotation.set(r(-0.05, 0.05), r(0, 3), r(-0.05, 0.05)); o.updateMatrix(); stakeIM.setMatrixAt(i, o.matrix); });
  o.scale.set(1, 1, 1);
  stakeIM.castShadow = stakeIM.receiveShadow = true; stakeIM.frustumCulled = false; G.add(stakeIM);

  /* black forest on the horizon instead of the harbour skyline */
  const sil = [];
  for (let i = 0; i < 170; i++) {
    const a = (i / 170) * TAU + r(-0.02, 0.02), d = r(140, 190), h = r(16, 34), cg = new THREE.ConeGeometry(h * 0.32, h, 6);
    cg.translate(Math.cos(a) * d, h / 2 - 1, Math.sin(a) * d); sil.push(cg);
  }
  const silM = new THREE.Mesh(mergeGeos(sil), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.006, 0.008, 0.012), fog: false }));
  silM.frustumCulled = false; G.add(silM);

  /* huts. built in their own frame (door on the +z wall, ridge along x), then turned to face the plaza */
  const hutParts = [], fires = [], inside = [], hutList = [];
  function hut(cx, cz, yaw, W, D, kind) {
    const P = [], T = 0.22, H = 2.6, ridge = 1.35, ov = 0.4, Wd = 1.7;
    const burning = kind === 'burn', ruin = kind === 'ruin';
    const fireSide = R() < 0.5 ? -1 : 1;                     // which half of the roof burns
    const wallTop = (x0, x1) => (ruin ? r(0.9, 2.1) : H);
    const boxes = [];                                         // collider boxes in hut space: [x0, x1, z0, z1, y0, y1]
    function wall(x0, x1, z0, z1, top, charFrom) {
      for (let y = 0, k = 0; y < top - 0.02; y += 0.32, k++) {
        const hh = Math.min(0.32, top - y);
        const burnt = ruin || (charFrom !== undefined && y > charFrom);
        P.push(B(x1 - x0, hh * 0.95, z1 - z0, (x0 + x1) / 2, y + hh / 2, (z0 + z1) / 2, burnt ? pickR(CHAR) : LOG[(k + Math.floor(R() * 2)) % LOG.length]));
      }
      boxes.push([x0, x1, z0, z1, 0, top]);
    }
    const hw = W / 2, hd = D / 2, chX = burning ? fireSide * hw * 0.5 : 99;
    // back and side walls, front wall split by the doorway; a burning hut is charred near the flames
    wall(-hw, hw, -hd, -hd + T, wallTop(), burning ? 1.3 : undefined);
    wall(-hw, -hw + T, -hd + T, hd - T, wallTop(), burning && fireSide < 0 ? 1.0 : undefined);
    wall(hw - T, hw, -hd + T, hd - T, wallTop(), burning && fireSide > 0 ? 1.0 : undefined);
    wall(-hw, -Wd / 2, hd - T, hd, wallTop(), burning && fireSide < 0 ? 1.4 : undefined);
    wall(Wd / 2, hw, hd - T, hd, wallTop(), burning && fireSide > 0 ? 1.4 : undefined);
    // corner posts and the door frame
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) P.push(B(0.3, ruin ? 1.6 : H + 0.1, 0.3, sx * (hw - 0.05), (ruin ? 1.6 : H + 0.1) / 2, sz * (hd - 0.05), ruin ? pickR(CHAR) : '#3b2b1d'));
    if (!ruin) {
      P.push(B(0.16, 2.12, 0.3, -Wd / 2 - 0.02, 1.06, hd - T / 2, '#35271a'), B(0.16, 2.12, 0.3, Wd / 2 + 0.02, 1.06, hd - T / 2, '#35271a'));
      P.push(B(Wd + 0.3, H - 2.1, T, 0, 2.1 + (H - 2.1) / 2, hd - T / 2, LOG[1])); boxes.push([-Wd / 2, Wd / 2, hd - T, hd, 2.1, H]);
      // floor boards, a table, a bench
      P.push(B(W - 0.5, 0.06, D - 0.5, 0, 0.03, 0, '#33281d'));
      if (W >= 6) { P.push(B(1.3, 0.08, 0.8, -hw + 1.3, 0.78, -hd + 0.9, '#5a4330'), B(0.08, 0.74, 0.08, -hw + 0.75, 0.37, -hd + 0.6, '#3b2b1d'), B(0.08, 0.74, 0.08, -hw + 1.85, 0.37, -hd + 0.6, '#3b2b1d'),
        B(0.08, 0.74, 0.08, -hw + 0.75, 0.37, -hd + 1.2, '#3b2b1d'), B(0.08, 0.74, 0.08, -hw + 1.85, 0.37, -hd + 1.2, '#3b2b1d')); boxes.push([-hw + 0.6, -hw + 2, -hd + 0.45, -hd + 1.35, 0, 0.82]); }
      // gable roof: two sloped panels; a burning hut has a hole torn in one of them
      const a = Math.atan2(ridge, hd + 0.05), L = (hd + ov) / Math.cos(a) + 0.1;
      for (const s of [-1, 1]) {
        const col = pickR(ROOF), y = H + ridge / 2 - 0.05, z = s * (hd + ov) / 2 - s * 0.05;
        if (burning && s === 1) {
          // the front panel is half gone: keep the side away from the fire, charred edge, a few loose boards
          const keepW = W + 2 * ov, half = keepW / 2;
          P.push(B(half, 0.13, L, -fireSide * half / 2, y, z, col, [-s * a, 0, 0]));
          P.push(B(0.25, 0.14, L * 0.9, -fireSide * 0.05, y, z, pickR(CHAR), [-s * a, 0, 0]));
          for (let k = 0; k < 3; k++) P.push(B(r(0.6, 1.2), 0.07, 0.25, fireSide * r(0.4, half - 0.4), y + r(-0.2, 0.2), z + r(-0.6, 0.6), pickR(CHAR), [r(-0.4, 0.4), r(0, 3), r(-0.4, 0.4)]));
        } else P.push(B(W + 2 * ov, 0.13, L, 0, y, z, col, [-s * a, 0, 0]));
      }
      P.push(B(W + 2 * ov + 0.1, 0.16, 0.22, 0, H + ridge + 0.02, 0, '#2f2418'));
      // gables at both ends, stepped
      for (const sx of [-1, 1]) for (let k = 0; k < 4; k++) {
        const t0 = k / 4, wz = D * (1 - t0 - 0.125) + 0.1, yy = H + ridge * (t0 + 0.125);
        P.push(B(T, ridge / 4 + 0.02, wz, sx * (hw - T / 2), yy, 0, burning && sx === fireSide ? pickR(CHAR) : LOG[k % LOG.length]));
      }
      boxes.push([-hw, hw, -hd, hd, H - 0.12, H + 0.06]); // ceiling: you cannot jump out through the roof
    } else {
      // a burnt-out shell: fallen beams inside
      for (let k = 0; k < 3; k++) P.push(B(r(1.6, W - 0.6), 0.2, 0.22, r(-0.6, 0.6), 0.12 + k * 0.08, r(-hd + 0.6, hd - 0.6), pickR(CHAR), [0, r(-0.6, 0.6), r(-0.15, 0.15)]));
    }
    // into world space
    const m = new THREE.Matrix4().makeRotationY(yaw).setPosition(cx, 0, cz), g = M(P); g.applyMatrix4(m); hutParts.push(g);
    const c = Math.cos(yaw), s = Math.sin(yaw), tw = (x, z) => [cx + x * c + z * s, cz - x * s + z * c];
    for (const [x0, x1, z0, z1, y0, y1] of boxes) {
      const p = [tw(x0, z0), tw(x1, z0), tw(x0, z1), tw(x1, z1)];
      addCollider(Math.min(...p.map((q) => q[0])), y0, Math.min(...p.map((q) => q[1])), Math.max(...p.map((q) => q[0])), y1, Math.max(...p.map((q) => q[1])), 'wood');
    }
    // flames: on the torn roof, licking up a wall corner, small ones in a ruin
    if (burning) {
      const [fx, fz] = tw(fireSide * hw * 0.45, hd * 0.35); fires.push([fx, H + 0.8, fz, 1.9]);
      const [hx, hz] = tw(fireSide * hw * 0.15, hd * 0.1); fires.push([hx, H + ridge * 0.7, hz, 1.1]);
      const [gx, gz] = tw(fireSide * (hw - 0.3), hd - 0.3); fires.push([gx, 0.2, gz, 1.0]);
    } else if (ruin && R() < 0.8) { const [fx, fz] = tw(r(-hw + 1, hw - 1), r(-hd + 1, hd - 1)); fires.push([fx, 0.15, fz, 0.6]); }
    // every hut keeps two crates: the back corner away from the table, and a front corner beside the door, away from any fire on the floor
    const e = hw - T - 0.68, f = hd - T - 0.68;
    inside.push(tw(e, -f), tw(burning && fireSide < 0 ? e : -e, f));
  }
  // where the huts go: an inner ring round the plaza and an outer ring, doors turned towards the middle, some burning, two in ruins
  const spots = [];
  for (let i = 0; i < 6; i++) { const a = (i / 6) * TAU + 0.35 + r(-0.12, 0.12), d = r(23, 28); spots.push([Math.cos(a) * d, Math.sin(a) * d]); }
  for (let i = 0; i < 9; i++) { const a = (i / 9) * TAU + r(-0.1, 0.1), d = r(44, 52); spots.push([Math.cos(a) * d, Math.sin(a) * d]); }
  const kinds = spots.map(() => 'ok'); [1, 4, 7, 9, 12, 13].forEach((k) => { kinds[k] = 'burn'; }); kinds[3] = 'ruin'; kinds[10] = 'ruin';
  spots.forEach(([x, z], i) => {
    if (Math.hypot(x, z - 6) < 15) return;
    const fx = -x, fz = -z, yaw = Math.abs(fx) > Math.abs(fz) ? (fx > 0 ? Math.PI / 2 : -Math.PI / 2) : (fz > 0 ? 0 : Math.PI);
    const W = pickR([5.4, 6.2, 7]), D = pickR([4.4, 5]);
    // line the doorway up with the walking grid so zombies can find their way in and out
    let cx = x, cz = z; const across = Math.abs(Math.sin(yaw)) < 0.5;
    if (across) cx = Math.round(cx - 0.5) + 0.5; else cz = Math.round(cz - 0.5) + 0.5;
    const ex = across ? W / 2 + 1 : D / 2 + 1, ez = across ? D / 2 + 1 : W / 2 + 1;
    if (Math.abs(cx) > 60 || Math.abs(cz) > 60 || occupied(cx - ex, cz - ez, cx + ex, cz + ez, 2)) return;
    hut(cx, cz, yaw, W, D, kinds[i]); hutList.push({ x: cx, z: cz, yaw, W, D, kind: kinds[i] });
  });
  const hutMat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.92 });
  const huts = new THREE.Mesh(mergeGeos(hutParts.map((g) => { g.userData.col = g.attributes.color.array; return g; })), hutMat);
  { const cols = []; hutParts.forEach((g) => { for (let i = 0; i < g.userData.col.length; i++) cols.push(g.userData.col[i]); }); huts.geometry.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3)); }
  huts.castShadow = huts.receiveShadow = true; G.add(huts);

  /* the plaza: a bonfire in a ring of stones, logs to sit on */
  const P = [];
  const BX = 0, BZ = -5;
  for (let i = 0; i < 10; i++) { const a = (i / 10) * TAU; P.push(B(0.45, 0.32, 0.4, BX + Math.cos(a) * 1.05, 0.16, BZ + Math.sin(a) * 1.05, i % 2 ? '#5d5c59' : '#4d4c4a', [0, a, 0])); }
  for (let i = 0; i < 4; i++) { const a = (i / 4) * TAU + 0.4; P.push(B(1.5, 0.2, 0.2, BX + Math.cos(a) * 0.3, 0.25, BZ + Math.sin(a) * 0.3, '#2a2018', [0, a, 0.35])); }
  addCollider(BX - 1.3, 0, BZ - 1.3, BX + 1.3, 0.7, BZ + 1.3, 'concrete');
  fires.push([BX, 0.3, BZ, 2.0]);
  [[-4.6, -5, 0.2], [4.6, -5.5, -0.2], [0, -9.8, 1.57]].forEach(([x, z, a]) => { P.push(B(2.4, 0.42, 0.42, x, 0.21, z, '#4a3826', [0, a, 0])); const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a)); addCollider(x - 1.2 * c - 0.21 * s, 0, z - 1.2 * s - 0.21 * c, x + 1.2 * c + 0.21 * s, 0.42, z + 1.2 * s + 0.21 * c, 'wood'); });

  /* cover in between: hay bales, barrels, carts, log piles, bits of fence */
  const prop = (x, z) => {
    const k = R();
    if (k < 0.3) { const a = R() < 0.5 ? 0 : Math.PI / 2, w = 1.3, d = 0.85; P.push(B(w, 0.9, d, x, 0.45, z, R() < 0.5 ? '#7d6e36' : '#6e6230', [0, a, 0]));
      if (a) addCollider(x - d / 2, 0, z - w / 2, x + d / 2, 0.9, z + w / 2, 'wood'); else addCollider(x - w / 2, 0, z - d / 2, x + w / 2, 0.9, z + d / 2, 'wood'); }
    else if (k < 0.5) { for (let b = 0; b < 3; b++) { const bx = x + (b - 1) * 0.65; P.push(B(0.58, 0.95, 0.58, bx, 0.475, z, '#4b3523'), B(0.62, 0.06, 0.62, bx, 0.25, z, '#2b2b2b'), B(0.62, 0.06, 0.62, bx, 0.75, z, '#2b2b2b')); }
      addCollider(x - 1.0, 0, z - 0.3, x + 1.0, 0.95, z + 0.3, 'wood'); }
    else if (k < 0.68) { P.push(B(2.6, 0.5, 1.4, x, 0.8, z, '#4e3a27'), B(2.6, 0.5, 0.08, x, 1.2, z - 0.66, '#3e2e1f'), B(2.6, 0.5, 0.08, x, 1.2, z + 0.66, '#3e2e1f'),
      B(0.12, 0.9, 0.9, x - 0.7, 0.45, z - 0.78, '#2c2219'), B(0.12, 0.9, 0.9, x - 0.7, 0.45, z + 0.78, '#2c2219'), B(1.6, 0.08, 0.08, x + 2.0, 0.6, z, '#3e2e1f', [0, 0, 0.3]));
      addCollider(x - 1.3, 0, z - 0.85, x + 1.3, 1.45, z + 0.85, 'wood'); }
    else if (k < 0.84) { for (let b = 0; b < 3; b++) for (let c = 0; c < 3 - b; c++) P.push(B(2.8, 0.36, 0.36, x, 0.2 + b * 0.32, z - 0.38 + c * 0.38 + b * 0.19, LOG[(b + c) % 4]));
      addCollider(x - 1.4, 0, z - 0.6, x + 1.4, 1.0, z + 0.6, 'wood'); }
    else { const a = R() < 0.5, L = r(3, 5); for (let t = 0; t <= L + 0.01; t += L / 3) P.push(a ? B(0.14, 1.2, 0.14, x - L / 2 + t, 0.6, z, '#3b2b1d') : B(0.14, 1.2, 0.14, x, 0.6, z - L / 2 + t, '#3b2b1d'));
      for (const y of [0.45, 0.95]) P.push(a ? B(L, 0.1, 0.07, x, y, z, '#4a3826') : B(0.07, 0.1, L, x, y, z, '#4a3826'));
      if (a) addCollider(x - L / 2, 0, z - 0.1, x + L / 2, 1.2, z + 0.1, 'wood'); else addCollider(x - 0.1, 0, z - L / 2, x + 0.1, 1.2, z + L / 2, 'wood'); }
  };
  for (let i = 0, tries = 0; i < 34 && tries < 600; tries++) {
    const x = r(-60, 60), z = r(-60, 60);
    if (Math.hypot(x, z - 3) < 14 || occupied(x - 2.6, z - 2.6, x + 2.6, z + 2.6, 1.5)) continue;
    prop(x, z); i++;
  }
  const props = new THREE.Mesh(M(P), hutMat); props.castShadow = props.receiveShadow = true; G.add(props);

  /* pines between the huts and outside the fence */
  const pines = [];
  for (let i = 0, tries = 0; i < 95 && tries < 2000; tries++) {
    const x = r(-64, 64), z = r(-64, 64);
    if (Math.hypot(x, z - 3) < 17 || occupied(x - 1.6, z - 1.6, x + 1.6, z + 1.6, 0.6)) continue;
    const h = r(7, 13), cr = r(1.8, 2.8); pines.push([x, z, h, cr]); addCollider(x - 0.28, 0, z - 0.28, x + 0.28, h, z + 0.28, 'wood'); i++;
  }
  const outer = [];
  for (let i = 0; i < 150; i++) { const a = R() * TAU, d = r(70, 96); outer.push([Math.cos(a) * d, Math.sin(a) * d, r(9, 16), r(2.2, 3.4)]); }
  const all = pines.concat(outer);
  const crownGeo = mergeGeos([new THREE.ConeGeometry(1, 0.62, 7).translate(0, 0.42, 0), new THREE.ConeGeometry(0.78, 0.5, 7).translate(0, 0.7, 0), new THREE.ConeGeometry(0.5, 0.36, 7).translate(0, 0.92, 0)]);
  const trunks = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.16, 0.28, 1, 6), new THREE.MeshStandardMaterial({ color: 0x3a2a1c, roughness: 0.95 }), all.length);
  const crowns = new THREE.InstancedMesh(crownGeo, new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.9 }), all.length);
  const tc = new THREE.Color();
  all.forEach(([x, z, h, cr], i) => {
    o.position.set(x, h * 0.2, z); o.scale.set(1, h * 0.4, 1); o.rotation.set(0, 0, 0); o.updateMatrix(); trunks.setMatrixAt(i, o.matrix);
    o.position.set(x, h * 0.1, z); o.scale.set(cr, h * 0.95, cr); o.rotation.set(0, R() * 3, 0); o.updateMatrix(); crowns.setMatrixAt(i, o.matrix);
    tc.setHSL(0.36 + r(-0.03, 0.03), 0.35, r(0.09, 0.14)).convertSRGBToLinear(); crowns.setColorAt(i, tc);
  });
  o.scale.set(1, 1, 1);
  [trunks, crowns].forEach((m) => { m.castShadow = true; m.receiveShadow = true; m.frustumCulled = false; G.add(m); });

  /* crates: two in every hut first, then the rest out in the village */
  let hc = 0, inHut = false;
  placeCrates(G, Math.max(S.crates, inside.length + 16), () => { inHut = hc < inside.length; return inHut ? inside[hc++] : [r(-62, 62), r(-62, 62)]; },
    (x, z) => (inHut ? !boxAt(x, z, 0.58, 0.05, 1.15) : Math.hypot(x, z - 6) >= 6 && !occupied(x - 0.6, z - 0.6, x + 0.6, z + 0.6, 0.3)));

  /* fire: flames, sparks and smoke drawn as camera-facing cards, each fire also lends one of the six flickering lights */
  buildFires(G, fires);
  fires.forEach(([x, y, z, p]) => World.lamps.push({ x, y: y + 0.9 + p * 0.3, z, d: 0 }));

  indexColliders(); buildNav();
  return { start: { x: 0, z: 8, yaw: 0 }, spawns: [], huts: hutList, map: { trees: pines, fires: fires.map(([x, , z, p]) => [x, z, p]) } };
}

/* flames, embers and smoke as instanced billboards; one draw each, animated entirely on the GPU */
function buildFires(G, fires) {
  const VS = `attribute vec3 offset; attribute vec2 sz; attribute float seed;
    uniform float t, rise, life, spread, fogD; varying vec2 vUv; varying float vSeed, vK, vFog;
    void main() {
      vUv = uv; vSeed = seed;
      float k = rise > 0.0 ? fract(t / life + seed) : 0.0; vK = k;
      vec3 p = offset + vec3(sin(seed * 41.0 + t * 1.3) * spread * k, k * rise, cos(seed * 23.0 + t * 1.1) * spread * k);
      vec4 mv = modelViewMatrix * vec4(p, 1.0);
      float s = rise > 0.0 ? (0.6 + k * 1.6) : 1.0;
      mv.xy += position.xy * sz * s; mv.y += sz.y * 0.5 * (rise > 0.0 ? 0.0 : 1.0);
      vFog = exp(-pow(fogD * length(mv.xyz), 2.0));
      gl_Position = projectionMatrix * mv;
    }`;
  const flameFS = `uniform float t; varying vec2 vUv; varying float vSeed, vFog;
    void main() {
      vec2 p = vUv; float w = sin(p.y * 7.0 + t * 9.0 + vSeed * 6.28) * 0.07 * p.y;
      float x = (p.x - 0.5 + w) / (0.44 * (1.0 - p.y * 0.8) + 0.03);
      float tip = 1.0 - smoothstep(0.5 + 0.28 * sin(t * 6.0 + vSeed * 9.0), 1.0, p.y);
      float a = (1.0 - smoothstep(0.55, 1.0, abs(x))) * tip * smoothstep(0.0, 0.1, p.y);
      if (a < 0.02) discard;
      float core = (1.0 - abs(x)) * (1.0 - p.y);
      vec3 c = mix(vec3(0.9, 0.18, 0.03), vec3(1.0, 0.62, 0.16), smoothstep(0.05, 0.5, core));
      c = mix(c, vec3(1.0, 0.92, 0.7), smoothstep(0.55, 0.95, core));
      gl_FragColor = vec4(c * a * 1.5 * vFog, a);
    }`;
  const emberFS = `varying vec2 vUv; varying float vK, vFog;
    void main() { float d = length(vUv - 0.5) * 2.0; float a = (1.0 - smoothstep(0.2, 1.0, d)) * (1.0 - vK);
      if (a < 0.02) discard; gl_FragColor = vec4(vec3(1.0, 0.55, 0.15) * a * 1.6 * vFog, a); }`;
  const smokeFS = `varying vec2 vUv; varying float vK, vSeed, vFog;
    void main() { float d = length(vUv - 0.5) * 2.0; float a = (1.0 - smoothstep(0.3, 1.0, d)) * smoothstep(0.0, 0.15, vK) * (1.0 - vK) * 0.42;
      if (a < 0.01) discard; gl_FragColor = vec4(vec3(0.07, 0.07, 0.075) * (0.6 + 0.4 * vFog), a * (0.4 + 0.6 * vFog)); }`;
  const mats = [];
  function layer(fs, list, opts) {
    const n = list.length, geo = new THREE.InstancedBufferGeometry(), q = new THREE.PlaneGeometry(1, 1);
    geo.index = q.index; geo.setAttribute('position', q.attributes.position); geo.setAttribute('uv', q.attributes.uv);
    const off = new Float32Array(n * 3), sz = new Float32Array(n * 2), sd = new Float32Array(n);
    list.forEach((it, i) => { off.set([it[0], it[1], it[2]], i * 3); sz.set([it[3], it[4]], i * 2); sd[i] = it[5]; });
    geo.setAttribute('offset', new THREE.InstancedBufferAttribute(off, 3)); geo.setAttribute('sz', new THREE.InstancedBufferAttribute(sz, 2)); geo.setAttribute('seed', new THREE.InstancedBufferAttribute(sd, 1));
    geo.instanceCount = n;
    const mat = new THREE.ShaderMaterial({ vertexShader: VS, fragmentShader: fs, transparent: true, depthWrite: false,
      blending: opts.add ? THREE.AdditiveBlending : THREE.NormalBlending,
      uniforms: { t: { value: 0 }, rise: { value: opts.rise || 0 }, life: { value: opts.life || 1 }, spread: { value: opts.spread || 0 }, fogD: { value: scene.fog.density } } });
    const mesh = new THREE.Mesh(geo, mat); mesh.frustumCulled = false; mesh.renderOrder = opts.order || 0; G.add(mesh); mats.push(mat);
  }
  const flames = [], embers = [], smoke = [];
  fires.forEach(([x, y, z, p]) => {
    for (let i = 0; i < Math.round(4 + p * 4); i++) { const s = rand(0.6, 1.1) * p; flames.push([x + rand(-0.45, 0.45) * p, y - 0.1, z + rand(-0.45, 0.45) * p, s * 0.7, s * 1.25, Math.random()]); }
    for (let i = 0; i < Math.round(6 + p * 8); i++) embers.push([x + rand(-0.4, 0.4) * p, y + 0.2, z + rand(-0.4, 0.4) * p, 0.07, 0.07, Math.random()]);
    for (let i = 0; i < Math.round(5 + p * 5); i++) smoke.push([x + rand(-0.3, 0.3), y + 0.8 * p, z + rand(-0.3, 0.3), 1.4 * p, 1.4 * p, Math.random()]);
  });
  layer(smokeFS, smoke, { rise: 9, life: 6.5, spread: 2.2, order: 2 });
  layer(flameFS, flames, { add: true, order: 3 });
  layer(emberFS, embers, { add: true, rise: 5, life: 2.2, spread: 1.4, order: 4 });
  World.fireMats = mats;
}
