
/* ============ stage 3-1: the old safari, a very wide savanna at golden hour, with a watchtower in the middle ============ */
function buildSavanna(G, S, R, r) {
  const o = new THREE.Object3D();
  const keep = World.keep;
  const grassTex = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#8c874a'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 9000, ['#9a9352', '#7f7b42', '#a39a58', '#75723e', '#8a7a48', '#6f7a3e'], 2.2);
    g.lineWidth = 1;
    for (let i = 0; i < 1400; i++) { const x = Math.random() * w, y = Math.random() * h; g.strokeStyle = pick(['rgba(70,64,30,0.5)', 'rgba(190,175,110,0.45)', 'rgba(95,110,50,0.45)']);
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + rand(-3, 3), y - rand(4, 9)); g.stroke(); }
    for (let i = 0; i < 16; i++) { g.fillStyle = 'rgba(110,85,50,' + rand(0.08, 0.2) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(20, 70), rand(10, 40), rand(0, 3), 0, TAU); g.fill(); }
  }, 110, 110));
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(1200, 1200), new THREE.MeshStandardMaterial({ map: grassTex, roughness: 0.97 }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; G.add(ground);

  const colliderFree = (x, z, rad) => {
    for (const b of colliders) if (x + rad > b.minx && x - rad < b.maxx && z + rad > b.minz && z - rad < b.maxz) return false;
    return true;
  };
  const WATER = { x: 62, z: -48, r: 22 };
  /* dirt tracks: a wobbly loop and a cross road */
  const road = [];
  for (let i = 0; i <= 72; i++) { const a = (i / 72) * TAU, rr = 98 + Math.sin(a * 3) * 12; road.push([Math.cos(a) * rr, Math.sin(a) * rr]); }
  const roadB = []; for (let i = 0; i <= 24; i++) roadB.push([Math.sin(i * 0.5) * 8, -170 + i * 14.2]);
  const dirtTex = keep(canvasTex(128, 256, (g, w, h) => {
    g.fillStyle = '#8a6a45'; g.fillRect(0, 0, w, h); speckle(g, w, h, 2500, ['#94744c', '#7c5e3c', '#a07e55', '#6f5435'], 2);
    g.fillStyle = 'rgba(60,44,28,0.35)'; g.fillRect(28, 0, 14, h); g.fillRect(86, 0, 14, h);
  }));
  dirtTex.wrapS = dirtTex.wrapT = THREE.RepeatWrapping;
  const segs = [];
  [road, roadB].forEach((line) => { for (let i = 0; i < line.length - 1; i++) {
    const [x0, z0] = line[i], [x1, z1] = line[i + 1], len = Math.hypot(x1 - x0, z1 - z0);
    const q = new THREE.PlaneGeometry(6, len + 0.6); const uv = q.attributes.uv; for (let k = 0; k < uv.count; k++) uv.setY(k, uv.getY(k) * len / 12);
    o.position.set((x0 + x1) / 2, 0.015, (z0 + z1) / 2); o.rotation.set(-Math.PI / 2, 0, -Math.atan2(x1 - x0, z1 - z0)); o.scale.set(1, 1, 1); o.updateMatrix();
    q.applyMatrix4(o.matrix); segs.push(q); } });
  const roads = new THREE.Mesh(mergeGeos(segs), new THREE.MeshStandardMaterial({ map: dirtTex, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -1 }));
  roads.receiveShadow = true; G.add(roads);
  const nearRoad = (x, z, d) => { for (const line of [road, roadB]) for (const [rx, rz] of line) if (Math.hypot(rx - x, rz - z) < d) return true; return false; };

  /* the waterhole where hippos wallow */
  const water = new THREE.Mesh(new THREE.CircleGeometry(WATER.r, 48), new THREE.MeshStandardMaterial({ color: 0x4a6457, roughness: 0.12, metalness: 0.15 }));
  water.rotation.x = -Math.PI / 2; water.position.set(WATER.x, 0.05, WATER.z); G.add(water);
  const mud = new THREE.Mesh(new THREE.RingGeometry(WATER.r - 1, WATER.r + 7, 48), new THREE.MeshStandardMaterial({ color: 0x6a4a30, roughness: 0.9 }));
  mud.rotation.x = -Math.PI / 2; mud.position.set(WATER.x, 0.03, WATER.z); mud.receiveShadow = true; G.add(mud);

  /* perimeter fence of the safari park */
  const E = 178;
  [[0, -E - 0.5, 2 * E + 2, 1], [0, E + 0.5, 2 * E + 2, 1], [-E - 0.5, 0, 1, 2 * E + 2], [E + 0.5, 0, 1, 2 * E + 2]].forEach(([x, z, sx, sz]) => addCollider(x - sx / 2, 0, z - sz / 2, x + sx / 2, 12, z + sz / 2, 'wood'));
  const posts = [], wire = [];
  for (let t = -E; t <= E; t += 6) posts.push([t, -E], [t, E], [-E, t], [E, t]);
  const postIM = new THREE.InstancedMesh(new THREE.BoxGeometry(0.16, 1.7, 0.16), new THREE.MeshStandardMaterial({ color: 0x5a4636, roughness: 0.9 }), posts.length);
  posts.forEach(([x, z], i) => { o.position.set(x, 0.85, z); o.rotation.set(0, 0, 0); o.scale.set(1, 1, 1); o.updateMatrix(); postIM.setMatrixAt(i, o.matrix); });
  postIM.frustumCulled = false; G.add(postIM);
  for (const y of [0.7, 1.4]) wire.push([2 * E, 0.03, 0.03, 0, y, -E], [2 * E, 0.03, 0.03, 0, y, E], [0.03, 0.03, 2 * E, -E, y, 0], [0.03, 0.03, 2 * E, E, y, 0]);
  G.add(new THREE.Mesh(mergeBoxes(wire), new THREE.MeshBasicMaterial({ color: 0x3a3a36 })));

  /* the watchtower in the middle: 10,000 to knock down (04h) */
  Tower.build(G, 0, 0);
  const wood = new THREE.MeshStandardMaterial({ color: 0x7a5a3a, roughness: 0.9 });
  const signTex = keep(canvasTex(512, 256, (g, w, h) => {
    g.fillStyle = '#e8d9a8'; g.fillRect(0, 0, w, h); g.fillStyle = '#6a3a1e'; g.fillRect(0, 0, w, 16); g.fillRect(0, h - 16, w, 16);
    g.fillStyle = '#3a2412'; g.textAlign = 'center'; g.font = '62px "Black Han Sans", sans-serif'; g.fillText('제3구역 맹수 사파리', w / 2, 112);
    g.font = '600 30px "IBM Plex Sans KR", sans-serif'; g.fillStyle = '#8a1e14'; g.fillText('차량 밖으로 나가지 마세요', w / 2, 186);
  }));
  const sign = new THREE.Mesh(new THREE.BoxGeometry(3.2, 1.6, 0.1), [wood, wood, wood, wood, new THREE.MeshStandardMaterial({ map: signTex, roughness: 0.8 }), wood]);
  sign.position.set(-9, 2.2, 13); sign.rotation.y = 0.35; sign.castShadow = true; G.add(sign);
  const sp = new THREE.Mesh(mergeBoxes([[0.14, 2.2, 0.14, -1.3, 1.1, 0], [0.14, 2.2, 0.14, 1.3, 1.1, 0]]), wood); sp.position.set(-9, 0, 13); sp.rotation.y = 0.35; G.add(sp);

  /* acacia trees, kopje boulders, termite mounds, bushes */
  const trees = [];
  for (let tries = 0; trees.length < 120 && tries < 2000; tries++) {
    const x = r(-170, 170), z = r(-170, 170);
    if (Math.hypot(x, z - 10) < 16 || Math.hypot(x - WATER.x, z - WATER.z) < WATER.r + 8 || nearRoad(x, z, 5) || !colliderFree(x, z, 3)) continue;
    const h = r(3.6, 6.2), cr = r(3.2, 5.5); trees.push([x, z, h, cr]); addCollider(x - 0.3, 0, z - 0.3, x + 0.3, h, z + 0.3, 'wood');
  }
  const trunkIM = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.18, 0.3, 1, 6).translate(0, 0.5, 0), new THREE.MeshStandardMaterial({ color: 0x5a4636, roughness: 0.95 }), trees.length);
  const crownIM = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 12, 6), new THREE.MeshStandardMaterial({ color: 0x4b5a2c, roughness: 0.9 }), trees.length);
  trees.forEach(([x, z, h, cr], i) => {
    o.position.set(x, 0, z); o.rotation.set(0, R() * TAU, 0); o.scale.set(1, h, 1); o.updateMatrix(); trunkIM.setMatrixAt(i, o.matrix);
    o.position.set(x, h, z); o.scale.set(cr, cr * 0.26, cr); o.updateMatrix(); crownIM.setMatrixAt(i, o.matrix);
  });
  [trunkIM, crownIM].forEach((m) => { m.castShadow = true; m.receiveShadow = true; m.frustumCulled = false; G.add(m); });
  const rocks = [];
  for (let c = 0, tries = 0; c < 26 && tries < 600; tries++) {
    const cx = r(-165, 165), cz = r(-165, 165);
    if (Math.hypot(cx, cz - 10) < 22 || Math.hypot(cx - WATER.x, cz - WATER.z) < WATER.r + 12 || nearRoad(cx, cz, 8) || !colliderFree(cx, cz, 6)) continue;
    c++;
    for (let k = 0, n = 2 + Math.floor(R() * 3); k < n; k++) {
      const x = cx + r(-4, 4), z = cz + r(-4, 4), s = r(1.2, 3.4), sy = s * r(0.6, 1);
      rocks.push([x, z, s, sy]); addCollider(x - s * 0.78, 0, z - s * 0.78, x + s * 0.78, sy * 0.95, z + s * 0.78, 'concrete');
    }
  }
  const rockIM = new THREE.InstancedMesh(new THREE.DodecahedronGeometry(1, 0), new THREE.MeshStandardMaterial({ color: 0x8f8374, roughness: 0.92, flatShading: true }), rocks.length);
  rocks.forEach(([x, z, s, sy], i) => { o.position.set(x, sy * 0.45, z); o.rotation.set(R(), R() * TAU, R()); o.scale.set(s, sy, s); o.updateMatrix(); rockIM.setMatrixAt(i, o.matrix); });
  rockIM.castShadow = rockIM.receiveShadow = true; rockIM.frustumCulled = false; G.add(rockIM);
  const mounds = [];
  for (let tries = 0; mounds.length < 34 && tries < 800; tries++) {
    const x = r(-170, 170), z = r(-170, 170);
    if (Math.hypot(x, z - 10) < 14 || nearRoad(x, z, 4) || Math.hypot(x - WATER.x, z - WATER.z) < WATER.r + 6 || !colliderFree(x, z, 2)) continue;
    const h = r(1.8, 3.2); mounds.push([x, z, h]); addCollider(x - 0.7, 0, z - 0.7, x + 0.7, h, z + 0.7, 'concrete');
  }
  const moundIM = new THREE.InstancedMesh(new THREE.ConeGeometry(1, 1, 7).translate(0, 0.5, 0), new THREE.MeshStandardMaterial({ color: 0x9a5a3a, roughness: 0.95, flatShading: true }), mounds.length);
  mounds.forEach(([x, z, h], i) => { o.position.set(x, 0, z); o.rotation.set(0, R() * TAU, 0); o.scale.set(0.95, h, 0.95); o.updateMatrix(); moundIM.setMatrixAt(i, o.matrix); });
  moundIM.castShadow = moundIM.receiveShadow = true; moundIM.frustumCulled = false; G.add(moundIM);
  const bushIM = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 8, 5), new THREE.MeshStandardMaterial({ color: 0x55632f, roughness: 0.95 }), 260);
  for (let i = 0; i < 260; i++) { const x = r(-172, 172), z = r(-172, 172), s = r(0.6, 1.5); o.position.set(x, s * 0.35, z); o.rotation.set(0, R() * TAU, 0); o.scale.set(s * 1.4, s * 0.75, s * 1.2); o.updateMatrix(); bushIM.setMatrixAt(i, o.matrix); }
  bushIM.receiveShadow = true; bushIM.frustumCulled = false; G.add(bushIM);
  /* tall dry grass tufts: three crossed cards each */
  const bladeTex = keep(canvasTex(128, 128, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    for (let i = 0; i < 46; i++) { const x = rand(8, w - 8), top = rand(10, 60); g.strokeStyle = pick(['#c7b46a', '#a99b55', '#d8c47c', '#8f8a48', '#b8a35e']); g.lineWidth = rand(1.5, 3);
      g.beginPath(); g.moveTo(x, h); g.quadraticCurveTo(x + rand(-6, 6), (h + top) / 2, x + rand(-14, 14), top); g.stroke(); }
  }));
  const cards = [0, 1, 2].map((k) => { const q = new THREE.PlaneGeometry(1.4, 1.0); q.translate(0, 0.5, 0); q.rotateY((k * Math.PI) / 3); return q; });
  const tuftIM = new THREE.InstancedMesh(mergeGeos(cards), new THREE.MeshStandardMaterial({ map: bladeTex, alphaTest: isTouch ? 0.5 : 0.3, alphaToCoverage: !isTouch, side: THREE.DoubleSide, roughness: 0.95 }), 3200);
  for (let i = 0; i < 3200; i++) { const x = r(-176, 176), z = r(-176, 176), s = r(0.7, 1.5); o.position.set(x, 0, z); o.rotation.set(0, R() * TAU, 0); o.scale.set(s, s * r(0.8, 1.3), s); o.updateMatrix(); tuftIM.setMatrixAt(i, o.matrix); }
  tuftIM.frustumCulled = false; G.add(tuftIM);
  /* far hills fading into the haze */
  const hills = [];
  for (let i = 0; i < 30; i++) { const a = (i / 30) * TAU + rand(-0.08, 0.08), rr = rand(290, 350), hr = rand(50, 110), hh = rand(18, 52);
    const c = new THREE.ConeGeometry(hr, hh, 9); o.position.set(Math.cos(a) * rr, hh / 2 - 2, Math.sin(a) * rr); o.rotation.set(0, rand(0, TAU), 0); o.scale.set(1, 1, rand(0.6, 1)); o.updateMatrix(); c.applyMatrix4(o.matrix); hills.push(c); }
  G.add(new THREE.Mesh(mergeGeos(hills), new THREE.MeshStandardMaterial({ color: 0x75683f, roughness: 1, flatShading: true })));

  /* supply crates scattered over the plain */
  // three of them up on the watchtower's platform, in its corners (each one a health potion, which also stops bleeding)
  const up = [[-1.85, -1.85], [1.85, -1.85], [-1.85, 1.85]];
  placeCrates(G, (S.crates || 46) + up.length, () => (up.length ? [...up.shift(), TOWER.ph] : [r(-170, 170), r(-170, 170)]),
    (x, z, y) => y > 0 || (Math.hypot(x, z) > 11 && Math.hypot(x, z - 20) > 6 && colliderFree(x, z, 1.2) && Math.hypot(x - WATER.x, z - WATER.z) > WATER.r + 3));
  indexColliders(); buildNav();
  World.menuCam = { x: 0, z: 2, r: 30, h: 11, look: 4 };
  return { start: { x: 0, z: 20, yaw: 0 }, spawns: [], wide: true, water: WATER, map: { roads: [road, roadB], trees, water: WATER, tower: { x: 0, z: 0 } } };
}
