
/* ============ PC graphics: multisampled frame, bloom and grading, a quality ladder that adjusts itself; FPS readout ============ */
/* post: the frame is drawn into a 4x multisampled target (already tone mapped and sRGB encoded by the materials),
   bright parts are blurred down a mip chain and added back, then a vignette, a touch of saturation and dither go to screen */
const Post = (() => {
  const can = !isTouch && renderer.capabilities.isWebGL2 && !!THREE.WebGLMultisampleRenderTarget;
  const N_MIP = 5, _v = new THREE.Vector2();
  let rt = null, mips = [], w = 0, h = 0;
  const cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1), pscene = new THREE.Scene();
  const tri = new THREE.BufferGeometry();
  tri.setAttribute('position', new THREE.Float32BufferAttribute([-1, -1, 0, 3, -1, 0, -1, 3, 0], 3));
  tri.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, 2, 0, 0, 2], 2));
  const quad = new THREE.Mesh(tri); quad.frustumCulled = false; pscene.add(quad);
  const VS = 'varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }';
  const mk = (fs, uniforms, blending) => new THREE.ShaderMaterial({ vertexShader: VS, fragmentShader: fs, uniforms, depthTest: false, depthWrite: false,
    blending: blending || THREE.NoBlending, transparent: !!blending, toneMapped: false });
  const texel = () => ({ value: new THREE.Vector2() });
  const bright = mk(`uniform sampler2D tex; uniform vec2 texel; uniform float threshold, knee; varying vec2 vUv;
    vec3 tap(vec2 o) { return texture2D(tex, vUv + o * texel).rgb; }
    void main() {
      vec3 c = (tap(vec2(-1.0, -1.0)) + tap(vec2(1.0, -1.0)) + tap(vec2(-1.0, 1.0)) + tap(vec2(1.0, 1.0))) * 0.25;
      float br = max(c.r, max(c.g, c.b));
      float s = clamp(br - threshold + knee, 0.0, 2.0 * knee); s = s * s / (4.0 * knee + 1e-4);
      gl_FragColor = vec4(c * max(s, br - threshold) / max(br, 1e-4), 1.0);
    }`, { tex: { value: null }, texel: texel(), threshold: { value: 0.7 }, knee: { value: 0.2 } });
  const down = mk(`uniform sampler2D tex; uniform vec2 texel; varying vec2 vUv;
    void main() {
      vec3 s = texture2D(tex, vUv).rgb * 4.0;
      s += texture2D(tex, vUv - texel).rgb + texture2D(tex, vUv + texel).rgb;
      s += texture2D(tex, vUv + vec2(texel.x, -texel.y)).rgb + texture2D(tex, vUv + vec2(-texel.x, texel.y)).rgb;
      gl_FragColor = vec4(s * 0.125, 1.0);
    }`, { tex: { value: null }, texel: texel() });
  const up = mk(`uniform sampler2D tex; uniform vec2 texel; varying vec2 vUv;
    void main() {
      vec3 s = texture2D(tex, vUv + vec2(-2.0 * texel.x, 0.0)).rgb + texture2D(tex, vUv + vec2(2.0 * texel.x, 0.0)).rgb
             + texture2D(tex, vUv + vec2(0.0, -2.0 * texel.y)).rgb + texture2D(tex, vUv + vec2(0.0, 2.0 * texel.y)).rgb;
      s += (texture2D(tex, vUv - texel).rgb + texture2D(tex, vUv + texel).rgb
          + texture2D(tex, vUv + vec2(texel.x, -texel.y)).rgb + texture2D(tex, vUv + vec2(-texel.x, texel.y)).rgb) * 2.0;
      gl_FragColor = vec4(s / 12.0, 1.0);
    }`, { tex: { value: null }, texel: texel() }, THREE.AdditiveBlending);
  const final = mk(`uniform sampler2D scene, bloom; uniform float strength, vig, sat; varying vec2 vUv;
    void main() {
      vec3 c = texture2D(scene, vUv).rgb + texture2D(bloom, vUv).rgb * strength;
      float l = dot(c, vec3(0.299, 0.587, 0.114)); c = mix(vec3(l), c, sat);
      vec2 q = vUv - 0.5; c *= clamp(1.0 - dot(q, q) * vig, 0.0, 1.0);
      c += (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
      gl_FragColor = vec4(c, 1.0);
    }`, { scene: { value: null }, bloom: { value: null }, strength: { value: 0.5 }, vig: { value: 0.5 }, sat: { value: 1.06 } });
  /* ambient occlusion (top levels): a half-size depth pass of the solid world, AO from that depth, a depth-aware blur,
     then the frame is multiplied by it before the gun is drawn, so the gun itself is never darkened */
  let dRT = null, aoA = null, aoB = null, aoW = 0, aoH = 0;
  /* depth-only stand-ins; r128 cannot share one material between instanced meshes with and without instance colours, so one per kind */
  const depthMats = {}, solid = [], _cc = new THREE.Color();
  const depthFor = (o) => {
    const k = (o.isInstancedMesh ? (o.instanceColor ? 'c' : 'i') : 'p') + ((Array.isArray(o.material) ? o.material[0] : o.material).side || 0);
    return depthMats[k] || (depthMats[k] = new THREE.MeshBasicMaterial({ color: 0x000000, fog: false, toneMapped: false, side: (Array.isArray(o.material) ? o.material[0] : o.material).side }));
  };
  const LIN = `uniform float cNear, cFar; uniform sampler2D tDepth;
    float viewZ(vec2 uv) { float d = texture2D(tDepth, uv).x; return (cNear * cFar) / ((cFar - cNear) * d - cFar); }`;
  const aoMat = mk(LIN + `
    uniform sampler2D tMask; uniform mat4 projInv; uniform vec2 texel; uniform float radius, intensity, bias, maxDist, pxPerM, maxPx; varying vec2 vUv;
    vec3 vpos(vec2 uv) { float d = texture2D(tDepth, uv).x; vec4 c = projInv * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0); return c.xyz / c.w; }
    void main() {
      float d0 = texture2D(tDepth, vUv).x;
      if (d0 >= 0.99999 || texture2D(tMask, vUv).r > 0.02) { gl_FragColor = vec4(1.0); return; }
      vec3 P = vpos(vUv); float dist = -P.z;
      if (dist > maxDist) { gl_FragColor = vec4(1.0); return; }
      vec3 pr = vpos(vUv + vec2(texel.x, 0.0)) - P, pl = P - vpos(vUv - vec2(texel.x, 0.0));
      vec3 pu = vpos(vUv + vec2(0.0, texel.y)) - P, pd = P - vpos(vUv - vec2(0.0, texel.y));
      vec3 N = normalize(cross(abs(pr.z) < abs(pl.z) ? pr : pl, abs(pu.z) < abs(pd.z) ? pu : pd));
      float rpx = min(maxPx, radius * pxPerM / dist), r2 = radius * radius, sum = 0.0;
      float phi = 6.2831853 * fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
      for (int i = 0; i < 12; i++) {
        float a = (float(i) + 0.5) / 12.0, ang = a * 6.2831853 * 7.0 + phi;
        vec2 uv = vUv + vec2(cos(ang), sin(ang)) * (a * rpx) * texel;
        if (texture2D(tDepth, uv).x >= 0.99999) continue;
        vec3 v = vpos(uv) - P; float vv = dot(v, v), vn = dot(v, N);
        float f = max(r2 - vv, 0.0), g = texture2D(tMask, uv).r > 0.02 ? 0.3 : 1.0; // thin grass only shades a little
        sum += g * f * f * f * max((vn - bias) / (0.01 + vv), 0.0);
      }
      float A = max(0.0, 1.0 - sum * intensity / pow(radius, 6.0) * (5.0 / 12.0));
      gl_FragColor = vec4(mix(1.0, A, smoothstep(maxDist, maxDist * 0.6, dist)), 1.0, 1.0, 1.0);
    }`, { tMask: { value: null }, tDepth: { value: null }, cNear: { value: 0.05 }, cFar: { value: 460 }, projInv: { value: new THREE.Matrix4() }, texel: texel(),
    radius: { value: 0.75 }, intensity: { value: 1.0 }, bias: { value: 0.012 }, maxDist: { value: 42 }, pxPerM: { value: 300 }, maxPx: { value: 48 } });
  const aoBlur = mk(LIN + `
    uniform sampler2D tAO; uniform vec2 dir; varying vec2 vUv;
    void main() {
      float zc = viewZ(vUv), sum = 0.0, wsum = 0.0;
      for (int i = -3; i <= 3; i++) {
        vec2 uv = vUv + dir * float(i); float z = viewZ(uv);
        float w = exp(-float(i * i) / 8.0) * max(0.0, 1.0 - abs(z - zc) / (0.04 * abs(zc) + 0.08));
        sum += texture2D(tAO, uv).r * w; wsum += w;
      }
      gl_FragColor = vec4(wsum > 0.0 ? sum / wsum : 1.0, 1.0, 1.0, 1.0);
    }`, { tDepth: { value: null }, tAO: { value: null }, cNear: { value: 0.05 }, cFar: { value: 460 }, dir: { value: new THREE.Vector2() } });
  const aoMul = new THREE.ShaderMaterial({ vertexShader: VS, fragmentShader: `uniform sampler2D tAO; uniform float strength; varying vec2 vUv;
      void main() { gl_FragColor = vec4(vec3(mix(1.0, texture2D(tAO, vUv).r, strength)), 1.0); }`,
    uniforms: { tAO: { value: null }, strength: { value: 0.85 } }, depthTest: false, depthWrite: false, transparent: true, toneMapped: false,
    blending: THREE.CustomBlending, blendEquation: THREE.AddEquation, blendSrc: THREE.ZeroFactor, blendDst: THREE.SrcColorFactor });
  function aoTargets() {
    const hw = Math.max(1, w >> 1), hh = Math.max(1, h >> 1);
    if (dRT && hw === aoW && hh === aoH) return;
    aoW = hw; aoH = hh;
    if (dRT) { dRT.depthTexture.dispose(); dRT.dispose(); aoA.dispose(); aoB.dispose(); }
    dRT = new THREE.WebGLRenderTarget(hw, hh, { depthBuffer: true, stencilBuffer: false });
    dRT.depthTexture = new THREE.DepthTexture(hw, hh); dRT.depthTexture.type = THREE.UnsignedIntType;
    const o = { depthBuffer: false, stencilBuffer: false, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter };
    aoA = new THREE.WebGLRenderTarget(hw, hh, o); aoB = new THREE.WebGLRenderTarget(hw, hh, o);
  }
  function occlusion() {
    aoTargets();
    // the solid world only: sky, glass, grass cards, light cones and particles live on layer 1
    camera.layers.set(0);
    for (const s of solid) { s.m = s.o.material; s.o.material = s.d; }
    renderer.getClearColor(_cc); const ca = renderer.getClearAlpha();
    renderer.setClearColor(0x000000, 1); renderer.setRenderTarget(dRT); renderer.clear(); renderer.render(scene, camera);
    renderer.setClearColor(_cc, ca);
    for (const s of solid) s.o.material = s.m;
    camera.layers.enable(1);
    const U = aoMat.uniforms, dt = dRT.depthTexture;
    U.tMask.value = dRT.texture; U.tDepth.value = dt; U.cNear.value = camera.near; U.cFar.value = camera.far; U.projInv.value.copy(camera.projectionMatrixInverse);
    U.texel.value.set(1 / aoW, 1 / aoH); U.pxPerM.value = camera.projectionMatrix.elements[5] * 0.5 * aoH;
    pass(aoMat, aoA);
    const B = aoBlur.uniforms; B.tDepth.value = dt; B.cNear.value = camera.near; B.cFar.value = camera.far;
    B.tAO.value = aoA.texture; B.dir.value.set(1 / aoW, 0); pass(aoBlur, aoB);
    B.tAO.value = aoB.texture; B.dir.value.set(0, 1 / aoH); pass(aoBlur, aoA);
    aoMul.uniforms.tAO.value = aoA.texture; pass(aoMul, rt);
  }
  function size() {
    rt.setSize(w, h);
    let mw = w, mh = h;
    for (const m of mips) { mw = Math.max(1, mw >> 1); mh = Math.max(1, mh >> 1); m.setSize(mw, mh); }
  }
  function ensure() {
    renderer.getDrawingBufferSize(_v);
    if (!rt) {
      w = _v.x; h = _v.y;
      rt = new THREE.WebGLMultisampleRenderTarget(w, h, { format: THREE.RGBAFormat, encoding: THREE.sRGBEncoding, stencilBuffer: false });
      rt.samples = 4;
      for (let i = 0; i < N_MIP; i++) mips.push(new THREE.WebGLRenderTarget(1, 1, { format: THREE.RGBAFormat, depthBuffer: false, stencilBuffer: false, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter }));
      size();
    } else if (_v.x !== w || _v.y !== h) { w = _v.x; h = _v.y; size(); }
  }
  function pass(mat, target) { quad.material = mat; renderer.setRenderTarget(target); renderer.render(pscene, cam); }
  return {
    can,
    /* night yards bloom the sodium lamps and muzzle flashes; the bright savanna only blooms the sun and fire */
    tune(stage) {
      const S = STAGE_STYLE[stage] || {}, day = !!S.day || !!S.lab; // the white lab grades like daylight: higher bloom threshold, lighter vignette
      bright.uniforms.threshold.value = day ? 0.9 : 0.76; bright.uniforms.knee.value = day ? 0.08 : 0.14;
      final.uniforms.strength.value = day ? 0.3 : 0.55; final.uniforms.vig.value = day ? 0.4 : 0.6; final.uniforms.sat.value = day ? 1.04 : 1.07;
      aoMat.uniforms.radius.value = day ? 1.0 : 0.85; aoMat.uniforms.intensity.value = day ? 1.2 : 1.3; aoMul.uniforms.strength.value = day ? 0.85 : 0.9;
    },
    begin() { ensure(); renderer.setRenderTarget(rt); },
    /* after the world, before the gun */
    afterScene(useAO) { if (useAO) { occlusion(); renderer.setRenderTarget(rt); } },
    /* keep see-through things out of the AO depth pass */
    tag(root) {
      camera.layers.enable(1); solid.length = 0;
      root.traverse((o) => {
        const m = o.material;
        const see = o.isSprite || o.isPoints || o.isLine || (m && (Array.isArray(m) ? m.some((x) => x.transparent || x.alphaTest > 0) : (m.transparent || m.isShaderMaterial)));
        if (see) o.layers.set(1);
        else if (o.isMesh && m && m.alphaTest > 0) {
          // grass cards: cut out by their own texture so the blades, not the cards, shade the ground
          // and they mark themselves white in the colour buffer, so the blades themselves are left unshaded
          solid.push({ o, m: null, d: new THREE.MeshBasicMaterial({ color: 0xffffff, map: m.map, alphaTest: m.alphaTest, side: m.side, fog: false, toneMapped: false }) });
        } else if (o.isMesh && m) solid.push({ o, m: null, d: depthFor(o) });
      });
    },
    end() {
      bright.uniforms.tex.value = rt.texture; bright.uniforms.texel.value.set(1 / w, 1 / h); pass(bright, mips[0]);
      for (let i = 1; i < N_MIP; i++) { const s = mips[i - 1]; down.uniforms.tex.value = s.texture; down.uniforms.texel.value.set(1 / s.width, 1 / s.height); pass(down, mips[i]); }
      for (let i = N_MIP - 1; i > 0; i--) { const s = mips[i]; up.uniforms.tex.value = s.texture; up.uniforms.texel.value.set(0.5 / s.width, 0.5 / s.height); pass(up, mips[i - 1]); }
      final.uniforms.scene.value = rt.texture; final.uniforms.bloom.value = mips[0].texture; pass(final, null);
    },
    release() {
      if (rt) { rt.dispose(); mips.forEach((m) => m.dispose()); rt = null; mips = []; }
      if (dRT) { dRT.depthTexture.dispose(); dRT.dispose(); aoA.dispose(); aoB.dispose(); dRT = null; aoW = aoH = 0; }
    },
  };
})();

/* quality ladder for PC. auto starts at the top and steps down (bloom and shadow detail before resolution) when the frame rate sags,
   then creeps back up once it holds. phones keep their own resolution governor in the frame loop */
/* which GPU the browser draws with. a software renderer means hardware acceleration is off (or the driver is blocked)
   and every pixel is drawn by the CPU, which is the usual reason for a very low frame rate on a PC */
const GPU = (() => {
  let name = '';
  try { const gl = renderer.getContext(), ext = gl.getExtension('WEBGL_debug_renderer_info'); name = String((ext && gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)) || gl.getParameter(gl.RENDERER) || ''); } catch (e) {}
  // "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)" reads better as "NVIDIA GeForce RTX 3060"
  let short = name; const m = /ANGLE \(([^,]*),\s*(.*?)(?:\s+Direct3D|\s+OpenGL|\s+Vulkan|,|\)$)/i.exec(name); if (m) short = m[2];
  short = short.replace(/\s*\(0x[0-9a-f]+\)/ig, '').trim();
  return { name, short: short || '알 수 없음', soft: /swiftshader|llvmpipe|softpipe|software|basic render/i.test(name) };
})();
const Gfx = (() => {
  const LEVELS = [
    { name: '낮음', pr: 0.85, post: false, shadow: 1024, esh: 0 },
    { name: '보통', pr: 1, post: false, shadow: 2048, esh: 28 },
    { name: '높음', pr: 1, post: true, shadow: 2048, esh: 28 },
    { name: '매우 높음', pr: 1.5, post: true, shadow: 4096, esh: 45, ao: true },
    { name: '최고', pr: 2, post: true, shadow: 4096, esh: 45, ao: true },
  ];
  const TOP = LEVELS.length - 1, dpr = Math.max(1, window.devicePixelRatio || 1);
  let level = TOP, L = LEVELS[TOP], acc = 0, n = 0, good = 0, t = 0, upAt = -1e9, holdUntil = 0;
  let pmrem = null, envRT = null, envStage = 0;
  // drawn by the CPU: the lightest level unless you insist on the top one
  const maxLevel = () => (settings.gfx === 'high' ? TOP : GPU.soft ? 0 : settings.gfx === 'fast' ? 1 : TOP);
  function shadowSize(s) {
    const sh = World.moon.shadow;
    if (sh.mapSize.x === s) return;
    sh.mapSize.set(s, s); if (sh.map) { sh.map.dispose(); sh.map = null; }
  }
  function apply(l) {
    if (isTouch) return;
    level = clamp(l, 0, maxLevel()); L = LEVELS[level];
    renderer.setPixelRatio(Math.min(L.pr, dpr));
    onResize();
    if (typeof World !== 'undefined' && World.moon) shadowSize(L.shadow);
    if (!(L.post && Post.can)) Post.release();
    store('yard07.gfxlvl', level);
  }
  /* metal on the guns reflects a soft sky with two light panels, dim at night and bright by day */
  function gunEnv(stage) {
    if (isTouch || envStage === stage) return;
    envStage = stage;
    try {
      if (!pmrem) pmrem = new THREE.PMREMGenerator(renderer);
      const S = STAGE_STYLE[stage] || {}, day = !!S.day, ship = !!S.indoor, es = new THREE.Scene();
      const geo = new THREE.SphereGeometry(10, 32, 16), pos = geo.attributes.position, col = [];
      const top = new THREE.Color(day ? 0x9cc3ea : 0x111a30).convertSRGBToLinear(), mid = new THREE.Color(day ? 0xf0dfba : 0x2a241a).convertSRGBToLinear(),
        bot = new THREE.Color(day ? 0x6d5b3c : 0x07090e).convertSRGBToLinear(), c = new THREE.Color();
      for (let i = 0; i < pos.count; i++) { const y = pos.getY(i) / 10; if (y >= 0) c.copy(mid).lerp(top, Math.pow(y, 0.6)); else c.copy(mid).lerp(bot, Math.pow(-y, 0.4)); col.push(c.r, c.g, c.b); }
      geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
      es.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide })));
      const panel = (hex, x, y, z, s) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(s, s * 0.55), new THREE.MeshBasicMaterial({ color: new THREE.Color(hex).convertSRGBToLinear(), side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); es.add(m); };
      panel(day ? 0xffffff : ship ? 0x9fdcff : 0xa06a30, 4, 6, 3, 5); panel(day ? 0xdfe9ff : ship ? 0x3a5a9a : 0x33497a, -6, 3, -2, 4);
      const next = pmrem.fromScene(es, 0.02);
      if (envRT) envRT.dispose();
      envRT = next; viewScene.environment = envRT.texture;
      es.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
    } catch (e) { viewScene.environment = null; }
  }
  return {
    LEVELS,
    get level() { return level; }, get name() { return L.name; },
    get post() { return !isTouch && L.post && Post.can; },
    get ao() { return !isTouch && !!L.ao && Post.can; },
    /* how far away enemies still cast shadows */
    get esh() { return isTouch ? 0 : L.esh; },
    init() {
      if (isTouch) return;
      const saved = store('yard07.gfxlvl');
      apply(settings.gfx === 'high' ? TOP : GPU.soft ? 0 : typeof saved === 'number' ? saved : TOP);
    },
    force(l) { apply(l); },
    mode() { if (isTouch) return; good = 0; acc = 0; n = 0; holdUntil = 0; apply(settings.gfx === 'high' ? TOP : settings.gfx === 'fast' ? Math.min(level, 1) : TOP); },
    /* once per stage: grading, gun reflections, lamp lights only where there are lamps, and shaders compiled up front */
    stage(stage) {
      Post.tune(stage);
      World.lights.forEach((Lt) => { Lt.visible = !(STAGE_STYLE[stage] || {}).day; });
      if (!isTouch) Post.tag(scene);
      gunEnv(stage);
      try { renderer.compile(scene, camera); renderer.compile(viewScene, viewCam); } catch (e) {}
    },
    govern(dt) {
      if (isTouch || settings.gfx === 'high') return;
      t += dt; acc += dt; n++;
      if (acc < 2) return;
      const avg = acc / n; acc = 0; n = 0;
      if (avg > 1 / 50 && level > 0) {
        if (t - upAt < 10) holdUntil = t + 60; // the last step up did not hold: stay put for a while
        apply(level - (avg > 1 / 30 && level > 1 ? 2 : 1)); good = 0;
      } else if (avg < 1 / 57 && level < maxLevel()) {
        if (++good >= 3 && t > holdUntil) { apply(level + 1); good = 0; upAt = t; }
      } else good = 0;
    },
  };
})();

/* FPS readout: settings toggle on every device, F3 on PC */
const Perf = (() => {
  let el = null, on = false, frames = 0, acc = 0, cpu = 0, worst = 0, shown = 0;
  function show(v) {
    on = !!v;
    if (on && !el) { el = document.createElement('div'); el.id = 'perf'; document.body.appendChild(el); }
    if (el) el.hidden = !on;
  }
  return {
    show, get on() { return on; },
    frame(dt, cpuMs) {
      if (!on) return;
      frames++; acc += dt; cpu += cpuMs; worst = Math.max(worst, dt);
      if (acc < 0.5) return;
      const fps = frames / acc, info = renderer.info.render, pr = renderer.getPixelRatio();
      const sz = renderer.getDrawingBufferSize(new THREE.Vector2());
      el.textContent = 'FPS ' + Math.round(fps) + ' · ' + (1000 * acc / frames).toFixed(1) + 'ms (최악 ' + Math.round(worst * 1000) + ') · CPU ' + (cpu / frames).toFixed(1) + 'ms\n' +
        (isTouch ? '휴대폰 설정' : '그래픽 ' + Gfx.name + (settings.gfx === 'auto' ? ' (자동)' : settings.gfx === 'high' ? ' (고정)' : ' (프레임 우선)')) +
        ' · 해상도 ' + sz.x + '×' + sz.y + ' (' + pr.toFixed(2) + '배)' + (Gfx.post ? ' · 블룸' : '') + (Gfx.ao ? ' · AO' : '') + ' · 그림자 ' + World.moon.shadow.mapSize.x + '\n드로우콜 ' + info.calls + ' · 삼각형 ' + Math.round(info.triangles / 1000) + 'k' +
        '\nGPU ' + GPU.short + (GPU.soft ? ' · 그래픽 가속 꺼짐: CPU로 그리는 중' : '');
      frames = 0; acc = 0; cpu = 0; worst = 0; shown++;
    },
  };
})();
