
/* ============ helicopter cutscenes: fast-rope in at the start, rope ladder out after a clear ============ */
const Cut = (() => {
  const B = AnimalKit.geoBox, M = AnimalKit.merge;
  const olive = '#4a5236', dark = '#2a2d31', glass = '#1d3448', stripe = '#d6a12e', floor = '#3a3d38';
  /* utility helicopter: open door on the right, built from panels so the cabin reads from inside too */
  const heli = new THREE.Group(); heli.rotation.order = 'YXZ';
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.65, metalness: 0.25 });
  const body = new THREE.Mesh(M([
    B(2.3, 0.12, 4.2, 0, 0.75, 0, floor), B(2.3, 0.12, 4.2, 0, 2.75, 0, olive), B(0.1, 2.0, 4.2, -1.12, 1.75, 0, olive),
    B(2.3, 2.0, 0.1, 0, 1.75, -2.1, olive), B(0.1, 0.5, 4.2, 1.12, 0.95, 0, olive), B(0.1, 0.45, 4.2, 1.12, 2.55, 0, olive),
    B(2.2, 1.9, 1.9, 0, 1.75, 2.9, olive, null, false, true), B(1.9, 1.1, 1.2, 0, 2.15, 3.35, glass, null, false, true),
    B(0.62, 0.62, 5.8, 0, 2.25, -4.9, olive), B(0.16, 1.7, 1.1, 0, 3.0, -7.6, olive), B(2.2, 0.1, 0.65, 0, 2.3, -7.0, olive),
    B(0.2, 0.62, 0.9, 0, 2.25, -6.3, stripe), B(1.4, 0.7, 2.6, 0, 3.15, -0.3, dark), B(0.18, 0.6, 0.18, 0, 3.75, 0, dark),
    B(0.12, 0.12, 4.6, -1.25, 0.08, 0.2, dark), B(0.12, 0.12, 4.6, 1.25, 0.08, 0.2, dark),
    B(0.1, 0.7, 0.1, -1.2, 0.4, 1.4, dark), B(0.1, 0.7, 0.1, 1.2, 0.4, 1.4, dark), B(0.1, 0.7, 0.1, -1.2, 0.4, -1.2, dark), B(0.1, 0.7, 0.1, 1.2, 0.4, -1.2, dark),
    B(0.55, 0.5, 0.5, -0.5, 1.05, -1.6, '#24262a'), B(0.55, 0.5, 0.5, 0.5, 1.05, -1.6, '#24262a'), B(1.6, 0.7, 0.12, 0, 1.45, -1.95, '#24262a'),
    B(0.3, 0.2, 0.4, 0.75, 0.35, 3.4, '#cfcfcf'),
  ]), mat);
  body.castShadow = true; heli.add(body);
  const bladeMat = new THREE.MeshStandardMaterial({ color: 0x1c1e21, roughness: 0.6 });
  const rotor = new THREE.Group(); rotor.position.set(0, 4.08, 0); heli.add(rotor);
  for (let i = 0; i < 4; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.05, 7.2), bladeMat); b.position.z = 3.6; const arm = new THREE.Group(); arm.rotation.y = (i * Math.PI) / 2; arm.add(b); rotor.add(arm); }
  const disc = new THREE.Mesh(new THREE.CircleGeometry(7.2, 32), new THREE.MeshBasicMaterial({ color: 0x9aa4b4, transparent: true, opacity: 0.1, depthWrite: false, side: THREE.DoubleSide }));
  disc.rotation.x = -Math.PI / 2; disc.position.y = 4.08; heli.add(disc);
  const tail = new THREE.Group(); tail.position.set(0.2, 3.0, -7.6); heli.add(tail);
  for (let i = 0; i < 2; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.04, 1.5, 0.16), bladeMat); b.rotation.x = i * Math.PI / 2; tail.add(b); }
  const beamMat = new THREE.MeshBasicMaterial({ color: 0xfff2d0, map: World.coneTex, transparent: true, opacity: 0.12, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false });
  const beam = new THREE.Mesh(new THREE.ConeGeometry(5, 18, 20, 1, true), beamMat); beam.position.set(0, -8, 3.5); beam.rotation.x = 0.35; heli.add(beam);
  heli.visible = false; scene.add(heli);
  const pool = new THREE.Mesh(new THREE.PlaneGeometry(14, 14), new THREE.MeshBasicMaterial({ map: World.poolTex, color: 0xfff2d0, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  pool.rotation.x = -Math.PI / 2; pool.visible = false; scene.add(pool);
  const rope = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 1, 6).translate(0, -0.5, 0), new THREE.MeshStandardMaterial({ color: 0x6b5a3a, roughness: 0.9 }));
  rope.visible = false; scene.add(rope);
  /* the player as seen from outside: dark tactical kit, helmet, rifle across the back */
  const fig = new THREE.Group(); fig.rotation.order = 'YXZ';
  const fmat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85 });
  fig.add(new THREE.Mesh(M([B(0.46, 0.64, 0.28, 0, 1.28, 0, '#2f3a2a'), B(0.36, 0.3, 0.12, 0, 1.3, 0.16, '#3d4a33'), B(0.23, 0.25, 0.24, 0, 1.72, 0.01, '#c99a7a'),
    B(0.28, 0.16, 0.3, 0, 1.86, 0, '#3a4430', null, false, true), B(0.08, 0.08, 0.9, 0.12, 1.3, -0.2, '#1d2024', [0.9, 0, 0]),
    B(0.16, 0.9, 0.18, -0.11, 0.47, 0, '#2a3326'), B(0.16, 0.9, 0.18, 0.11, 0.47, 0, '#2a3326'), B(0.17, 0.1, 0.28, -0.11, 0.04, 0.05, '#161616'), B(0.17, 0.1, 0.28, 0.11, 0.04, 0.05, '#161616')]), fmat));
  const armL = new THREE.Group(); armL.position.set(-0.3, 1.52, 0); fig.add(armL); armL.add(new THREE.Mesh(M([B(0.12, 0.6, 0.13, 0, -0.28, 0, '#2f3a2a'), B(0.1, 0.1, 0.1, 0, -0.6, 0, '#2a2a2a')]), fmat));
  const armR = new THREE.Group(); armR.position.set(0.3, 1.52, 0); fig.add(armR); armR.add(new THREE.Mesh(M([B(0.12, 0.6, 0.13, 0, -0.28, 0, '#2f3a2a'), B(0.1, 0.1, 0.1, 0, -0.6, 0, '#2a2a2a')]), fmat));
  fig.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  fig.visible = false; scene.add(fig);

  const el = { bars: $('cutbars'), title: $('cuttitle'), sub: $('cutsub'), skip: $('cutskip'), fade: $('fade'), card: $('bosscard') };
  let C = null;
  const ease = (t) => t * t * (3 - 2 * t);
  const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _look = new THREE.Vector3(), _door = new THREE.Vector3();
  function hoverHeight(x, z) {
    // thin things (lamp posts, crane legs) don't count; the rotor clears container stacks, rocks and trees
    let top = 0; for (const b of queryNear(x - 9, z - 9, x + 9, z + 9)) if (b.maxy < 30 && (b.maxx - b.minx) * (b.maxz - b.minz) > 3) top = Math.max(top, b.maxy);
    return Math.max(7, top + 4.5);
  }
  function show(title, sub) {
    cinema = true; onResize(); $('hud').hidden = true; $('touch').hidden = true;
    el.bars.hidden = false; el.title.textContent = title; el.sub.textContent = sub;
    el.skip.textContent = isTouch ? '화면을 누르면 건너뜁니다' : '클릭 · Space 키로 건너뛰기';
  }
  /* heli pose along a straight approach: from far and high to a hover over (hx, hy, hz) */
  function place(px, py, pz, yaw, pitch, roll) { heli.position.set(px, py, pz); heli.rotation.set(pitch || 0, yaw, roll || 0); }
  function doorWorld(out, down, reach) {
    // the open door is on the right side (local -x), just behind the cockpit
    const s = Math.sin(heli.rotation.y), c = Math.cos(heli.rotation.y), k = reach || 1.05;
    return out.set(heli.position.x - c * k, heli.position.y + 1.6 - (down || 0), heli.position.z + s * k);
  }
  /* 5.13, the ship's boss doors: a second and a half just inside the door. the drone hangs in the middle of the frame doing what it does
     (the bee beating its wings, the boss turning its shell), turns to look at you at the end, and its name stands big in the bottom right:
     yellow for the bee, green for the boss. the camera drifts a little way in towards it */
  function startBossIntro(D, e, onDone) {
    const cz = (D.z0 + D.z1) / 2, cam0 = new THREE.Vector3(D.x + D.inward * 2, 2.6, cz), at = e.pos.clone();
    C = { kind: 'boss', t: 0, dur: 1.5, onDone, D, e, cam0, cam1: cam0.clone().lerp(at, Math.min(0.4, 9 / Math.max(1, cam0.distanceTo(at)))), base: at.clone(), yaw0: e.yaw }; // 5.16: at most 9 m in, the hall is big now
    heli.visible = rope.visible = fig.visible = beam.visible = pool.visible = false;
    e.g.visible = true; e.bar.visible = false; if (e.isFar) setFar(e, false); // it may still be culled as far away
    show('', '');
    el.card.textContent = D.title; el.card.className = 'bosscard ' + D.tone; el.card.hidden = false;
    Sound.alarm();
  }
  function bossIntro(dt, t) {
    const e = C.e, k = ease(clamp(t / C.dur, 0, 1));
    e.spin = (e.spin || 0) + dt;
    // moving: a slow drift and bob over where it hangs, then it swings round to face the door
    e.pos.set(C.base.x + Math.sin(t * 2.2) * 0.5, C.base.y + Math.sin(t * 3.4) * 0.3, C.base.z + Math.cos(t * 1.7) * 0.4);
    const face = Math.atan2(camera.position.x - e.pos.x, camera.position.z - e.pos.z);
    let dy = face - C.yaw0; dy = Math.atan2(Math.sin(dy), Math.cos(dy)); e.yaw = C.yaw0 + dy * ease(clamp((t - 0.5) / 0.8, 0, 1)); e.g.rotation.y = e.yaw;
    if (e.wings) { const f = Math.sin(e.spin * 48); for (const W of e.wings) W.g.rotation.z = W.sx * (0.18 + f * 0.42); e.g.rotation.z = Math.sin(t * 2.6) * 0.06; }
    if (e.beeEye) e.beeEye.emissive.setRGB(0.25 + 0.9 * k, 0.05 + 0.15 * k, 0);
    if (e.shells) e.g.rotation.z = Math.sin(t * 2) * 0.05;
    camera.position.lerpVectors(C.cam0, C.cam1, k); camera.position.y += Math.sin(t * 9) * 0.01;
    _look.copy(e.pos); camera.lookAt(_look);
    if (t >= C.dur) finish();
  }
  /* the lab: no helicopter. a look over the cages, the monkey in his booth slams the red button, every cage starts counting, and you are on */
  function startLabIntro(stage, onDone) {
    C = { kind: 'lab', t: 0, dur: 10.6, onDone, beat: 0 };
    heli.visible = false; rope.visible = false; fig.visible = false; beam.visible = pool.visible = false;
    show('스테이지 ' + stageTag(stage) + ' · ' + STAGES[stage].name, STAGES[stage].intro);
    el.fade.style.opacity = '1'; requestAnimationFrame(() => { el.fade.style.opacity = '0'; });
  }
  function labIntro(dt, t) {
    const st = Game.info.start;
    if (t < 2.6) {
      const k = ease(t / 2.6);
      camera.position.set(lerp(-46.5, -18, k), lerp(12.5, 10.5, k), lerp(49.5, 45, k)); _look.set(lerp(-9, 6, k), 2, -15); camera.lookAt(_look);
    } else if (t < 6.4) {
      if (C.beat === 0) { C.beat = 1; Lab.monkeyMode('press', 1.5); Sound.cackle({ x: 0, y: WIN.y0 + 1.5, z: -LAB_HALF - 3 }); el.sub.textContent = '미친 원숭이 박사가 버튼을 누릅니다'; }
      // right up to his window in the north wall, looking in at him and his console
      const k = ease((t - 2.6) / 3.8);
      camera.position.set(lerp(-1.7, -0.9, k), lerp(WIN.y0 + 2.6, WIN.y0 + 2.2, k), lerp(-LAB_HALF + 4.6, -LAB_HALF + 2.0, k)); _look.set(0.25, WIN.y0 + 1.3, -LAB_HALF - 3.2); camera.lookAt(_look);
      if (C.beat === 1 && t > 4.1) { C.beat = 2; Lab.press(); Sound.press(); Sound.siren(); buzz(80); }
      if (C.beat === 2 && t > 4.6) { C.beat = 3; Sound.cackle({ x: 0, y: WIN.y0 + 1.5, z: -LAB_HALF - 3 });
        el.sub.textContent = Lab.seq ? '첫 우리가 5초 뒤 열립니다 · 다음 우리는 앞 우리의 동물을 다 잡아야 원숭이 박사가 엽니다' : '우리 10개에 카운트다운이 시작됐습니다 · 10초 뒤 첫 우리가 열립니다'; }
    } else if (t < 8.9) {
      // along the west cages: their boards now count down
      if (C.beat === 3) { C.beat = 4; Sound.alarm(); Lab.monkeyMode('cackle'); }
      const k = ease((t - 6.4) / 2.5);
      camera.position.set(-19.5, lerp(8, 6, k), lerp(-21, 18, k)); _look.set(-37.5, 4.2, lerp(-30, 24, k)); camera.lookAt(_look);
      if (Math.random() < dt * 1.5) { const a = pick(Enemies.list); if (a && a.animal) Sound.roar(a.pos, a.T.roar); }
    } else {
      const k = ease(clamp((t - 8.9) / 1.5, 0, 1));
      camera.position.set(st.x, lerp(6, player.eye, k), lerp(st.z - 8, st.z, k)); _look.set(st.x, lerp(2, player.eye, k), st.z - 30); camera.lookAt(_look);
      if (t >= C.dur) { finish(); return; }
    }
  }
  /* out of the lab: the alarm stops, the sealed door rolls up, and you walk out into the light */
  function startLabOutro(onDone) {
    C = { kind: 'labout', t: 0, dur: 7.4, onDone, cam: new THREE.Vector3(5.5, 2.6, LAB_HALF - 9.5) };
    Lab.alarm = false; heli.visible = false; fig.visible = true; fig.position.set(0, 0, LAB_HALF - 10.5); fig.rotation.set(0, 0, 0);
    show('탈출', '스테이지 ' + stageTag(Game.stage) + ' 클리어 · 비상 출입문이 열립니다');
    Sound.siren();
  }
  function labOutro(dt, t) {
    Lab.doorOpen = ease(clamp((t - 0.4) / 2.4, 0, 1));
    if (t > 0.4 && !C.rumble) { C.rumble = true; Sound.quake({ x: 0, y: 3, z: LAB_HALF - 1 }); }
    const k = clamp((t - 1.8) / 4.6, 0, 1), walk = t > 1.8 && k < 1;
    fig.position.set(0, walk ? Math.abs(Math.sin(t * 8)) * 0.05 : 0, lerp(LAB_HALF - 10.5, LAB_HALF + 5, k)); fig.rotation.set(0, 0, 0);
    armL.rotation.x = walk ? Math.sin(t * 8) * 0.5 : 0; armR.rotation.x = walk ? -Math.sin(t * 8) * 0.5 : 0;
    camera.position.copy(C.cam); _look.set(0, 2.2, lerp(LAB_HALF - 6, LAB_HALF + 2, ease(clamp(t / 6, 0, 1)))); camera.lookAt(_look);
    if (t > C.dur - 1.1 && !C.faded) { C.faded = true; el.fade.style.opacity = '1'; }
    if (t >= C.dur) finish();
  }
  /* the ship: no helicopter either. the shuttle has docked; inside the airlock the light turns green, the inner door slides up
     and you step out into the passage. behind you it shuts again */
  function startShipIntro(stage, onDone) {
    C = { kind: 'ship', t: 0, dur: 6.4, onDone, beat: 0 };
    heli.visible = false; rope.visible = false; fig.visible = false; beam.visible = pool.visible = false;
    Ship.doorOpen = 0; Ship.closing = false;
    show('스테이지 ' + stageTag(stage) + ' · ' + STAGES[stage].name, '도킹 완료 · 에어록 압력을 맞추는 중');
    el.fade.style.opacity = '1'; requestAnimationFrame(() => { el.fade.style.opacity = '0'; });
  }
  function shipIntro(dt, t) {
    const st = Game.info.start;
    if (t < 2.2) {
      camera.position.set(st.x + 1.1, 1.72 + Math.sin(t * 1.3) * 0.02, 28.7); _look.set(st.x, 2.1, SHIP_DOOR_Z); camera.lookAt(_look);
      if (C.beat === 0 && t > 0.9) { C.beat = 1; Sound.press(); el.sub.textContent = STAGES[Game.stage].intro; }
    } else if (t < 3.7) {
      if (C.beat === 1) { C.beat = 2; Sound.clank({ x: st.x, y: 2, z: SHIP_DOOR_Z }); Sound.swoosh({ x: st.x, y: 2, z: SHIP_DOOR_Z }); }
      Ship.doorOpen = ease((t - 2.2) / 1.5);
      camera.position.set(st.x + 1.1 - (t - 2.2) * 0.4, 1.72, 28.7 - (t - 2.2) * 0.3); _look.set(st.x, 2.1 + Ship.doorOpen, SHIP_DOOR_Z - 4); camera.lookAt(_look);
    } else {
      const k = ease(clamp((t - 3.7) / 2.4, 0, 1));
      camera.position.set(lerp(st.x + 0.5, st.x, k), lerp(1.72, player.eye, k), lerp(28.2, st.z, k)); _look.set(st.x, lerp(2.1, player.eye, k), st.z - 20); camera.lookAt(_look);
      if (t >= C.dur) { finish(); return; }
    }
  }
  /* out of the ship: back down the passage to the airlock, the door rolls up, you step in and it shuts */
  function startShipOutro(onDone) {
    const st = Game.info.start;
    C = { kind: 'shipout', t: 0, dur: 7, onDone, cam: new THREE.Vector3(st.x + 1.5, 2.6, 15.2) };
    heli.visible = false; fig.visible = true; fig.position.set(st.x, 0, 18.5); fig.rotation.set(0, 0, 0);
    show('탈출', '스테이지 ' + stageTag(Game.stage) + ' 클리어 · 에어록으로 빠져나갑니다');
    Sound.press();
  }
  function shipOutro(dt, t) {
    const st = Game.info.start;
    Ship.doorOpen = t < 5.2 ? ease(clamp((t - 0.3) / 1.6, 0, 1)) : ease(clamp(1 - (t - 5.2) / 1.2, 0, 1));
    if (t > 0.3 && !C.hiss) { C.hiss = true; Sound.swoosh({ x: st.x, y: 2, z: SHIP_DOOR_Z }); }
    const k = clamp((t - 1.2) / 3.8, 0, 1), walk = t > 1.2 && k < 1;
    fig.position.set(st.x, walk ? Math.abs(Math.sin(t * 8)) * 0.05 : 0, lerp(18.5, 28, k)); fig.rotation.set(0, 0, 0);
    armL.rotation.x = walk ? Math.sin(t * 8) * 0.5 : 0; armR.rotation.x = walk ? -Math.sin(t * 8) * 0.5 : 0;
    if (k >= 1) fig.visible = false;
    camera.position.copy(C.cam); _look.set(st.x, 1.8, lerp(21, 26, ease(clamp(t / 6, 0, 1)))); camera.lookAt(_look);
    if (t > C.dur - 1.1 && !C.faded) { C.faded = true; el.fade.style.opacity = '1'; }
    if (t >= C.dur) finish();
  }
  function startIntro(stage, onDone) {
    if (World.style.lab) { startLabIntro(stage, onDone); return; }
    if (World.style.ship) { startShipIntro(stage, onDone); return; }
    const st = Game.info.start, hy = hoverHeight(st.x, st.z), yaw = st.yaw + Math.PI;  // the heli faces the way you will face
    const fx = -Math.sin(st.yaw), fz = -Math.cos(st.yaw);
    // hover so that the door hangs over the start point
    const rx = -Math.cos(yaw), rz = Math.sin(yaw);
    const hx = st.x - rx * 1.05, hz = st.z - rz * 1.05;
    C = { kind: 'in', t: 0, dur: 7.2, onDone, hx, hy, hz, yaw, fx, fz, sx: hx - fx * 95, sz: hz - fz * 95 };
    heli.visible = true; rope.visible = false; fig.visible = false;
    beam.visible = pool.visible = !World.style.day;
    show('스테이지 ' + stageTag(stage) + ' · ' + STAGES[stage].name, STAGES[stage].intro);
    el.fade.style.opacity = '1'; requestAnimationFrame(() => { el.fade.style.opacity = '0'; });
  }
  function startOutro(onDone) {
    if (World.style.lab) { startLabOutro(onDone); return; }
    if (World.style.ship) { startShipOutro(onDone); return; }
    const p = player.pos, hy = hoverHeight(p.x, p.z), yaw = player.yaw + Math.PI;
    const rx = -Math.cos(yaw), rz = Math.sin(yaw), hx = p.x - rx * 1.05, hz = p.z - rz * 1.05;
    let fx = -Math.sin(player.yaw), fz = -Math.cos(player.yaw);
    // inside the ship the way out is the bay door to the south
    if (World.style.indoor) { const dx = 0 - p.x, dz = 75 - p.z, dl = Math.hypot(dx, dz) || 1; fx = dx / dl; fz = dz / dl; }
    // third-person camera: behind you, a little to the side, looking up at the pick-up
    C = { kind: 'out', t: 0, dur: 8.6, onDone, hx, hy, hz, yaw, fx, fz, sx: hx - fx * 95, sz: hz - fz * 95, px: p.x, py: p.y, pz: p.z,
      cam: new THREE.Vector3(p.x - fx * 15 + fz * 6, p.y + 4 + hy * 0.35, p.z - fz * 15 - fx * 6) };
    // keep the camera out of containers and rocks
    for (let k = 0; k < 10 && (collideAt(C.cam.x, C.cam.y - 1.5, C.cam.z, 0.4, 2) || !lineOfSight(C.cam, _a.set(p.x, p.y + 1.2, p.z))); k++) C.cam.lerp(_a.set(p.x, p.y + 4 + hy * 0.35, p.z), 0.25);
    heli.visible = true; fig.visible = true; fig.position.set(p.x, p.y, p.z); fig.rotation.set(0, player.yaw + Math.PI, 0);
    beam.visible = pool.visible = !World.style.day;
    show('탈출', '스테이지 ' + stageTag(Game.stage) + ' 클리어 · 헬기가 데리러 왔습니다');
  }
  function finish() {
    const done = C && C.onDone; const kind = C && C.kind;
    C = null; heli.visible = rope.visible = fig.visible = pool.visible = false; el.bars.hidden = true; el.card.hidden = true; Sound.rotor(0);
    cinema = false; onResize();
    if (kind === 'in' || kind === 'lab' || kind === 'ship') el.fade.style.opacity = '0';
    if (kind === 'ship') { Ship.doorOpen = Math.max(Ship.doorOpen, 1); Ship.closing = true; } // the airlock shuts behind you
    if (kind === 'lab') { if (!Lab.pressed) { Lab.press(); Sound.siren(); } Lab.monkeyMode('idle'); }
    if (done) done();
  }
  function approach(t, t0, t1) {
    // fly in nose-down, flare and settle into the hover between t0 and t1
    const k = ease(clamp((t - t0) / (t1 - t0), 0, 1));
    const lift = World.style.indoor ? 3.5 : 28; // inside the ship it comes in low through the bay door
    const x = lerp(C.sx, C.hx, k), z = lerp(C.sz, C.hz, k), y = lerp(C.hy + lift, C.hy, k) + Math.sin(time * 2.1) * 0.15;
    place(x, y, z, C.yaw, lerp(0.18, -0.06, k) + (k > 0.85 ? (1 - k) * 0.4 : 0), Math.sin(time * 1.3) * 0.02);
    return k;
  }
  function depart(t, t0) {
    const k = clamp((t - t0) / 3, 0, 1), kk = k * k;
    const up = World.style.indoor ? 2 : 26;
    place(C.hx + C.fx * kk * 70, C.hy + kk * up + k * (World.style.indoor ? 0.5 : 3), C.hz + C.fz * kk * 70, C.yaw, 0.22 * Math.min(1, k * 3), 0);
  }
  function update(dt) {
    if (!C) return;
    C.t += dt; const t = C.t;
    if (C.kind === 'boss') { bossIntro(dt, t); return; }
    if (C.kind === 'lab') { labIntro(dt, t); if (C) updateEnemies(dt, time); return; }
    if (C.kind === 'labout') { labOutro(dt, t); return; }
    if (C.kind === 'ship') { shipIntro(dt, t); return; }
    if (C.kind === 'shipout') { shipOutro(dt, t); return; }
    rotor.rotation.y += dt * 26; tail.rotation.x += dt * 40;
    if (C.kind === 'in') {
      if (t < 3.6) {
        approach(t, 0, 3.4);
        // sitting in the open door, looking out and down at the landing zone
        // sitting in the open door with your legs out: the yard slides by below
        doorWorld(camera.position, 0.15, 1.4); camera.position.y += Math.sin(time * 9) * 0.02;
        const s = Math.sin(heli.rotation.y), c = Math.cos(heli.rotation.y);
        _look.set(camera.position.x - c * 9 + C.fx * 14, 0, camera.position.z + s * 9 + C.fz * 14);
        camera.lookAt(_look);
      } else if (t < 5.4) {
        approach(4, 0, 3.4);
        // fast-rope down beside the heli
        const k = ease((t - 3.6) / 1.8);
        doorWorld(_door, 0.1); rope.visible = true; rope.position.copy(_door); rope.scale.set(1, _door.y, 1);
        camera.position.set(lerp(_door.x, Game.info.start.x, k), lerp(_door.y, player.eye, k), lerp(_door.z, Game.info.start.z, k));
        _look.set(Game.info.start.x + C.fx * 10, lerp(0, player.eye, k), Game.info.start.z + C.fz * 10);
        camera.lookAt(_look);
        if (k > 0.98 && !C.landed) { C.landed = true; Sound.land(); }
      } else {
        rope.visible = false; depart(t, 5.4);
        // on the ground: watch it pull away, then settle into the playing view
        const k = ease(clamp((t - 6.2) / 1.0, 0, 1));
        camera.position.set(Game.info.start.x, player.eye, Game.info.start.z);
        _a.copy(heli.position); _b.set(Game.info.start.x + C.fx * 20, player.eye, Game.info.start.z + C.fz * 20);
        camera.lookAt(_look.lerpVectors(_a, _b, k));
        if (t >= C.dur) { finish(); return; }
      }
    } else {
      if (t < 3.6) approach(t, 0, 3.4);
      else if (t < 6.2) {
        approach(4, 0, 3.4);
        // the rope ladder drops and you climb up into the door
        doorWorld(_door, 0); rope.visible = true; rope.position.copy(_door); rope.scale.set(1, Math.max(0.1, _door.y - C.py), 1);
        const k = ease(clamp((t - 3.9) / 2.1, 0, 1));
        fig.position.set(lerp(C.px, _door.x, k), lerp(C.py, _door.y - 1.7, k), lerp(C.pz, _door.z, k));
        const climb = Math.sin(t * 9) * (k > 0 && k < 1 ? 1 : 0);
        armL.rotation.x = -2.6 + climb * 0.5; armR.rotation.x = -2.6 - climb * 0.5;
        if (k >= 1) fig.visible = false;
      } else {
        rope.visible = false; fig.visible = false; depart(t, 6.2);
        if (t > C.dur - 1.1 && !C.faded) { C.faded = true; el.fade.style.opacity = '1'; }
        if (t >= C.dur) { finish(); return; }
      }
      camera.position.copy(C.cam);
      // frame you and the hovering heli together; follow the heli once you're aboard
      if (fig.visible) _look.copy(fig.position).add(_a.set(0, 1, 0)).lerp(heli.position, 0.38); else _look.copy(heli.position);
      if (!C.lookAt) C.lookAt = _look.clone(); else C.lookAt.lerp(_look, 1 - Math.exp(-dt * 4));
      camera.lookAt(C.lookAt);
    }
    // downwash and the searchlight pool under the heli
    const agl = heli.position.y - groundAt(heli.position.x, 50, heli.position.z, 1);
    if (agl < 16 && Math.random() < 0.8) { const a = rand(0, TAU), rr = rand(2, 7); FX.puff({ x: heli.position.x + Math.cos(a) * rr, y: 0.3, z: heli.position.z + Math.sin(a) * rr }, 1, World.style.day ? 0.6 : 0.4, 1.2); }
    if (pool.visible) { pool.position.set(heli.position.x + C.fx * 3, 0.04, heli.position.z + C.fz * 3); pool.material.opacity = clamp(1 - agl / 40, 0, 1); }
    Sound.rotor(clamp(1 - heli.position.distanceTo(camera.position) / 140, 0.05, 1));
  }
  return { startIntro, startOutro, startBossIntro, update, skip() { if (C) finish(); }, get active() { return !!C; } };
})();
