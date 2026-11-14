
/* ============ fx: particles, tracers, decals, debris ============ */
const FX = (() => {
  function makeSystem(max, blending) {
    const pos = new Float32Array(max * 3), col = new Float32Array(max * 4), size = new Float32Array(max);
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    geo.setAttribute('pcolor', new THREE.BufferAttribute(col, 4));
    geo.setAttribute('size', new THREE.BufferAttribute(size, 1));
    const mat = new THREE.ShaderMaterial({
      uniforms: { uScale: { value: 400 } },
      vertexShader: 'attribute float size; attribute vec4 pcolor; varying vec4 vC; uniform float uScale;' +
        'void main(){ vC = pcolor; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = size * uScale / max(0.1, -mv.z); gl_Position = projectionMatrix * mv; }',
      fragmentShader: 'varying vec4 vC; void main(){ vec2 c = gl_PointCoord - 0.5; float d = length(c); if (d > 0.5) discard;' +
        'float a = smoothstep(0.5, 0.05, d); gl_FragColor = vec4(vC.rgb, vC.a * a); }',
      transparent: true, depthWrite: false, blending,
    });
    const pts = new THREE.Points(geo, mat); pts.frustumCulled = false; scene.add(pts);
    const P = [];
    for (let i = 0; i < max; i++) P.push({ life: 0, max: 1, x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, s0: 0, s1: 0, r: 1, g: 1, b: 1, a: 1, grav: 0, drag: 0 });
    let cursor = 0;
    return {
      mat, emit(o) { const p = P[cursor]; cursor = (cursor + 1) % max; Object.assign(p, o); p.life = p.max; return p; },
      update(dt) {
        for (let i = 0; i < max; i++) {
          const p = P[i];
          if (p.life <= 0) { size[i] = 0; continue; }
          p.life -= dt; const k = 1 - p.life / p.max;
          p.vy -= p.grav * dt; const dr = Math.exp(-p.drag * dt); p.vx *= dr; p.vy *= dr; p.vz *= dr;
          p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
          const fy = PIT === null ? 0 : floorY(p.x, p.z); if (p.y < fy + 0.02) { p.y = fy + 0.02; p.vy *= -0.35; p.vx *= 0.6; p.vz *= 0.6; }
          pos[i * 3] = p.x; pos[i * 3 + 1] = p.y; pos[i * 3 + 2] = p.z;
          col[i * 4] = p.r; col[i * 4 + 1] = p.g; col[i * 4 + 2] = p.b; col[i * 4 + 3] = p.a * (1 - k * k);
          size[i] = lerp(p.s0, p.s1, k);
        }
        geo.attributes.position.needsUpdate = true; geo.attributes.pcolor.needsUpdate = true; geo.attributes.size.needsUpdate = true;
      },
      clear() { for (const p of P) p.life = 0; },
    };
  }
  const glow = makeSystem(900, THREE.AdditiveBlending);
  const smoke = makeSystem(260, THREE.NormalBlending);

  /* tracers */
  const tracerGeo = new THREE.CylinderGeometry(0.012, 0.012, 1, 4, 1, true); tracerGeo.rotateX(Math.PI / 2); tracerGeo.translate(0, 0, 0.5);
  const tracers = [];
  for (let i = 0; i < 24; i++) {
    const m = new THREE.Mesh(tracerGeo, new THREE.MeshBasicMaterial({ color: 0xffd9a0, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false }));
    m.visible = false; m.frustumCulled = false; scene.add(m); tracers.push({ m, life: 0 });
  }
  let tc = 0;
  const _v = new THREE.Vector3();
  function tracer(from, to) {
    const t = tracers[tc]; tc = (tc + 1) % tracers.length;
    const len = from.distanceTo(to); if (len < 0.5) return;
    t.m.position.copy(from); t.m.lookAt(to); t.m.scale.set(1, 1, len); t.m.visible = true; t.life = 0.06; t.m.material.opacity = 0.9;
  }
  /* decals */
  const decalTex = glowTex('rgba(8,8,10,0.95)', 'rgba(20,20,24,0.6)');
  const decalMat = new THREE.MeshBasicMaterial({ map: decalTex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 });
  const decalGeo = new THREE.PlaneGeometry(0.16, 0.16);
  // bullet holes share one instanced mesh, recycled as a ring buffer
  const DECALS = 64, decalIM = new THREE.InstancedMesh(decalGeo, decalMat, DECALS), _dm = new THREE.Object3D();
  decalIM.count = 0; decalIM.frustumCulled = false; scene.add(decalIM);
  let dc = 0;
  function decal(p, n) {
    _dm.position.set(p.x + n.x * 0.01, p.y + n.y * 0.01, p.z + n.z * 0.01); _dm.rotation.set(0, 0, 0); _dm.scale.setScalar(1);
    _v.set(p.x + n.x, p.y + n.y, p.z + n.z); _dm.lookAt(_v); _dm.rotateZ(rand(0, TAU)); _dm.scale.setScalar(rand(0.7, 1.3)); _dm.updateMatrix();
    decalIM.setMatrixAt(dc % DECALS, _dm.matrix); dc++; decalIM.count = Math.min(DECALS, dc); decalIM.instanceMatrix.needsUpdate = true;
  }
  /* debris chunks from destroyed robots */
  const debGeo = new THREE.BoxGeometry(1, 1, 1);
  const debMat = new THREE.MeshStandardMaterial({ color: 0x3b4049, roughness: 0.5, metalness: 0.7 });
  const woodMat = new THREE.MeshStandardMaterial({ color: 0x7a5a36, roughness: 0.9 });
  const debris = [];
  for (let i = 0; i < 48; i++) { const m = new THREE.Mesh(debGeo, debMat); m.visible = false; m.castShadow = true; scene.add(m); debris.push({ m, life: 0, v: new THREE.Vector3(), w: new THREE.Vector3() }); }
  let dbc = 0;
  /* world flash light (muzzle, explosions) */
  const flash = new THREE.PointLight(0xffb060, 0, 9, 2); scene.add(flash);
  let flashT = 0, flashMax = 0;
  const boomLight = new THREE.PointLight(0xff8a3a, 0, 16, 2); scene.add(boomLight);
  let boomT = 0;

  return {
    glow, smoke,
    resize() { const s = viewH * renderer.getPixelRatio() / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2)); glow.mat.uniforms.uScale.value = s; smoke.mat.uniforms.uScale.value = s; },
    tracer, decal,
    muzzle(pos, strength) { flash.position.copy(pos); flashMax = strength; flashT = 0.05; flash.intensity = strength; },
    sparks(p, n, color, speed) {
      const c = color || [1, 0.75, 0.4];
      for (let i = 0; i < n; i++) glow.emit({ x: p.x, y: p.y, z: p.z, vx: rand(-1, 1) * speed, vy: rand(-0.3, 1.2) * speed, vz: rand(-1, 1) * speed,
        max: rand(0.18, 0.45), s0: rand(0.05, 0.1), s1: 0.01, r: c[0], g: c[1], b: c[2], a: 1, grav: 9, drag: 2.5 });
    },
    puff(p, n, shadeV, size) {
      for (let i = 0; i < n; i++) smoke.emit({ x: p.x + rand(-0.1, 0.1), y: p.y + rand(-0.1, 0.1), z: p.z + rand(-0.1, 0.1), vx: rand(-0.6, 0.6), vy: rand(0.2, 1.1), vz: rand(-0.6, 0.6),
        max: rand(0.6, 1.4), s0: size * 0.5, s1: size * rand(1.3, 2), r: shadeV, g: shadeV, b: shadeV * 1.08, a: 0.5, grav: -0.4, drag: 1.5 });
    },
    explode(p, big, color) {
      const c = color || [1, 0.55, 0.2];
      const n = big ? 70 : 40;
      for (let i = 0; i < n; i++) { const a = rand(0, TAU), e = rand(-0.4, 1.2), s = rand(2, big ? 11 : 8);
        glow.emit({ x: p.x, y: p.y, z: p.z, vx: Math.cos(a) * Math.cos(e) * s, vy: Math.sin(e) * s, vz: Math.sin(a) * Math.cos(e) * s,
          max: rand(0.3, 0.8), s0: rand(0.08, 0.2), s1: 0.02, r: c[0], g: c[1], b: c[2], a: 1, grav: 8, drag: 1.8 }); }
      for (let i = 0; i < (big ? 14 : 8); i++) glow.emit({ x: p.x + rand(-0.3, 0.3), y: p.y + rand(-0.3, 0.3), z: p.z + rand(-0.3, 0.3), vx: rand(-1, 1), vy: rand(0, 1.5), vz: rand(-1, 1),
        max: rand(0.25, 0.45), s0: big ? 1.6 : 1.0, s1: big ? 3.2 : 2.0, r: 1, g: 0.6, b: 0.25, a: 0.55, grav: 0, drag: 2 });
      this.puff(p, big ? 16 : 9, 0.12, big ? 1.4 : 0.9);
      boomLight.position.copy(p); boomLight.position.y += 0.5; boomLight.intensity = big ? 4 : 2.6; boomT = 0.35;
    },
    chunks(p, n, size, kind) {
      for (let i = 0; i < n; i++) {
        const d = debris[dbc]; dbc = (dbc + 1) % debris.length;
        d.m.material = kind === 'wood' ? woodMat : debMat;
        d.m.position.set(p.x + rand(-0.3, 0.3), p.y + rand(-0.2, 0.3), p.z + rand(-0.3, 0.3));
        const s = size * rand(0.5, 1.2); d.m.scale.set(s, s * rand(0.4, 1), s * rand(0.6, 1.4));
        d.v.set(rand(-4, 4), rand(3, 8), rand(-4, 4)); d.w.set(rand(-10, 10), rand(-10, 10), rand(-10, 10));
        d.life = rand(2.5, 4); d.m.visible = true;
      }
    },
    update(dt) {
      glow.update(dt); smoke.update(dt);
      for (const t of tracers) if (t.life > 0) { t.life -= dt; t.m.material.opacity = Math.max(0, t.life / 0.06) * 0.9; if (t.life <= 0) t.m.visible = false; }
      for (const d of debris) {
        if (d.life <= 0) continue;
        d.life -= dt; d.v.y -= 16 * dt;
        d.m.position.addScaledVector(d.v, dt);
        d.m.rotation.x += d.w.x * dt; d.m.rotation.y += d.w.y * dt; d.m.rotation.z += d.w.z * dt;
        const floor = d.m.scale.y * 0.5;
        if (d.m.position.y < floor) { d.m.position.y = floor; d.v.y *= -0.3; d.v.x *= 0.6; d.v.z *= 0.6; d.w.multiplyScalar(0.6); }
        if (d.life < 0.5) d.m.scale.multiplyScalar(1 - dt * 3);
        if (d.life <= 0) d.m.visible = false;
      }
      if (flashT > 0) { flashT -= dt; flash.intensity = Math.max(0, flashT / 0.05) * flashMax; } else flash.intensity = 0;
      if (boomT > 0) { boomT -= dt; boomLight.intensity *= Math.exp(-dt * 9); } else boomLight.intensity = 0;
    },
    clear() { glow.clear(); smoke.clear(); for (const d of debris) { d.life = 0; d.m.visible = false; } decalIM.count = 0; dc = 0; },
  };
})();
FX.resize();
