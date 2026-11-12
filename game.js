(function () {
'use strict';
/* ============ core: renderer, utils, storage, audio ============ */
const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b + 1));
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const TAU = Math.PI * 2;
const isTouch = (window.matchMedia && matchMedia('(pointer: coarse)').matches) || ('ontouchstart' in window && navigator.maxTouchPoints > 0);
const isApp = /Yard07App/.test(navigator.userAgent);
function buzz(ms) { try { if (isTouch && navigator.vibrate) navigator.vibrate(ms); } catch (e) {} }

function store(key, val) {
  try { if (val === undefined) { const s = localStorage.getItem(key); return s ? JSON.parse(s) : null; }
    localStorage.setItem(key, JSON.stringify(val)); } catch (e) { return null; }
  return val;
}

/* ISO 6346 container codes with real check digits */
const ISO_VAL = (() => { const m = {}; let v = 10;
  for (const ch of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') { if (v % 11 === 0) v++; m[ch] = v; v++; }
  for (let d = 0; d < 10; d++) m[String(d)] = d; return m; })();
function isoCode(owner, serial) {
  const body = owner + 'U' + String(serial).padStart(6, '0');
  let sum = 0; for (let i = 0; i < 10; i++) sum += ISO_VAL[body[i]] * Math.pow(2, i);
  const check = (sum % 11) % 10;
  return { owner: owner + 'U', serial: body.slice(4), check, text: owner + 'U ' + body.slice(4) + ' ' + check };
}

const renderer = new THREE.WebGLRenderer({ antialias: !isTouch, powerPreference: 'high-performance' });
const MAX_PR = Math.min(window.devicePixelRatio || 1, isTouch ? 1.25 : 1.6);
renderer.setPixelRatio(MAX_PR);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false; // updated once per frame, right before the world is drawn
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;
renderer.autoClear = false;
renderer.info.autoReset = false;
$('stage').appendChild(renderer.domElement);

const scene = new THREE.Scene();
// fog colour is given in linear space; the sky dome runs the same tone mapping so the horizon matches it
renderer.setClearColor(0x0b0f1a);
scene.fog = new THREE.FogExp2(new THREE.Color(0.026, 0.033, 0.052), 0.021);
const BASE_FOV = 74;
const camera = new THREE.PerspectiveCamera(BASE_FOV, window.innerWidth / window.innerHeight, 0.05, 460);
camera.rotation.order = 'YXZ';
scene.add(camera);

const viewScene = new THREE.Scene();
const viewCam = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.01, 10);
viewScene.add(new THREE.HemisphereLight(0x9fb2d8, 0x2a2018, 0.75));
const viewKey = new THREE.DirectionalLight(0xffd2a0, 0.8); viewKey.position.set(1, 2, 1.5); viewScene.add(viewKey);
const viewFlash = new THREE.PointLight(0xffb060, 0, 3); viewFlash.position.set(0.2, -0.1, -0.8); viewScene.add(viewFlash);

/* layout: on portrait phones the 3D view takes the top of the screen and a control deck the bottom */
let viewW = window.innerWidth, viewH = window.innerHeight, portrait = false, baseFov = BASE_FOV, hipScale = 1, cinema = false;
function fovFor(aspect) {
  if (aspect >= 1.25) return BASE_FOV;
  const v = THREE.MathUtils.radToDeg(2 * Math.atan(Math.tan(THREE.MathUtils.degToRad(33)) / aspect));
  return clamp(v, BASE_FOV, 86);
}
function onResize() {
  const w = window.innerWidth, h = window.innerHeight;
  portrait = isTouch && h > w * 1.1;
  document.body.classList.toggle('portrait', portrait);
  const deck = portrait && !cinema ? Math.round(clamp(h * 0.37, 300, 350)) : 0;
  viewW = w; viewH = Math.max(160, h - deck);
  document.documentElement.style.setProperty('--view-h', viewH + 'px');
  renderer.setSize(viewW, viewH);
  const aspect = viewW / viewH;
  baseFov = fovFor(aspect); hipScale = clamp(aspect / 1.5, 0.55, 1);
  camera.aspect = aspect; camera.fov = baseFov; camera.updateProjectionMatrix();
  viewCam.aspect = aspect; viewCam.updateProjectionMatrix();
  if (typeof FX !== 'undefined') FX.resize();
}
window.addEventListener('resize', onResize);

/* settings */
const settings = Object.assign({ sens: 1, vol: 0.7, autoFire: isTouch, gfx: 'auto', fps: false, dev: false, cross: 'cross' }, store('yard07.settings') || {});
/* progress: money, the stages opened and cleared, best times, the weapon layout for keys 1-7, and guns rented for the next stage */
/* stages: 1, 2, 3, 4 are the main line; 1-1 (id 6) and 1-2 (id 5) hang off stage 1, 3-1 (id 7, the safari) and 3-2 (id 8, the lab
   one cage at a time) off stage 3. ids stay stable for saves (id 7 was listed as 2-1 for a while).
   a stage opens when the one it hangs off is cleared (or it was cleared itself); STAGE_ORDER is the order they are listed in */
const STAGE_ORDER = [1, 6, 5, 2, 3, 7, 8, 4], STAGE_TAG = { 1: '1', 6: '1-1', 5: '1-2', 2: '2', 3: '3', 7: '3-1', 8: '3-2', 4: '4' };
const PREREQ = { 1: 0, 6: 1, 5: 6, 2: 1, 3: 2, 7: 3, 8: 7, 4: 3 }, NEXT = { 1: [2, 6], 6: [5], 5: [2], 2: [3], 3: [4, 7], 7: [8], 8: [4], 4: [] };
const stageTag = (n) => STAGE_TAG[n] || String(n), isYard = (n) => n === 1 || n === 5 || n === 6;
/* Korean particles after a stage number: 일·삼·육·영 take 을, the rest 를; 삼·육·영 take 으로 (일 ends in ㄹ, so 로) */
const eul = (tag) => (/[0136]$/.test(tag) ? '을' : '를'), euro = (tag) => (/[036]$/.test(tag) ? '으로' : '로');
const SAVE0 = () => ({ v: 4, money: 0, cleared: [], best: {}, loadout: ['pistol', null, null, null, null, null, null], rented: [], owned: [], items: { helmet: 0, vest: 0, jet: 0, ivory: 0 } });
const save = Object.assign(SAVE0(), { v: 1 }, store('yard07.save') || {}); // a stored save without v is from before rentals
const stageOpen = (n) => !!STAGE_TAG[n] && (settings.dev || !PREREQ[n] || save.cleared.includes(PREREQ[n]) || save.cleared.includes(n));
/* the stages worth suggesting after clearing n: what it opens, as long as it is open */
const nextStages = (n) => (NEXT[n] || []).filter((s) => stageOpen(s));
/* money earned inside a stage only counts once you get out: until then storage keeps the amount you came in with */
/* inside a stage, what you earned there (money, ivory) is only yours once you get out: the save keeps what you came in with */
let moneyLock = null, ivoryLock = null, ownLock = null; // ownLock: the guns you owned when the stage began
function persist() {
  if (moneyLock === null && ivoryLock === null && ownLock === null) { store('yard07.save', save); return; }
  const o = Object.assign({}, save, { items: Object.assign({}, save.items) });
  if (moneyLock !== null) o.money = Math.max(0, Math.min(save.money, moneyLock));
  if (ivoryLock !== null) o.items.ivory = Math.max(0, Math.min(save.items.ivory, ivoryLock));
  if (ownLock !== null) o.owned = save.owned.filter((id) => ownLock.includes(id));
  store('yard07.save', o);
}
const hot = window.claude && window.claude.hot;
if (hot && hot.snapshot) { try { hot.snapshot(() => ({ settings, save })); } catch (e) {} }

/* ---------- audio (all synthesized) ---------- */
const Sound = (() => {
  let ctx = null, master = null, noiseBuf = null, comp = null;
  function init() {
    if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    ctx = new AC();
    comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 6;
    master = ctx.createGain(); master.gain.value = settings.vol;
    master.connect(comp); comp.connect(ctx.destination);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 1.5, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  function setVol(v) { if (master) master.gain.value = v; }
  function suspend() { try { if (ctx && ctx.state === 'running') ctx.suspend(); } catch (e) {} }
  /* back from another tab or app: the context was suspended on the way out, start it again (a tap or key also does) */
  function wake() { try { if (ctx && ctx.state !== 'running' && ctx.state !== 'closed') { const p = ctx.resume(); if (p && p.catch) p.catch(() => {}); } } catch (e) {} }
  function out(pan) {
    if (!ctx) return null;
    if (pan !== undefined && ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = clamp(pan, -1, 1); p.connect(master); return p; }
    return master;
  }
  function noise(dur, type, f0, f1, q, gain, dest, delay) {
    const t = ctx.currentTime + (delay || 0);
    const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.playbackRate.value = rand(0.9, 1.1);
    const flt = ctx.createBiquadFilter(); flt.type = type; flt.Q.value = q;
    flt.frequency.setValueAtTime(f0, t); flt.frequency.exponentialRampToValueAtTime(Math.max(30, f1), t + dur);
    const g = ctx.createGain(); g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    src.connect(flt); flt.connect(g); g.connect(dest);
    src.start(t, Math.random() * 0.5); src.stop(t + dur + 0.05);
  }
  function tone(type, f0, f1, dur, gain, dest, delay) {
    const t = ctx.currentTime + (delay || 0);
    const o = ctx.createOscillator(); o.type = type;
    o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(gain, t + 0.006);
    g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    o.connect(g); g.connect(dest); o.start(t); o.stop(t + dur + 0.05);
  }
  // distance attenuation for world sounds
  function spatial(pos) {
    if (!pos) return { dest: out(), k: 1 };
    const dx = pos.x - camera.position.x, dz = pos.z - camera.position.z;
    const dist = Math.hypot(dx, dz, pos.y - camera.position.y);
    const k = clamp(1.6 / (1 + dist * 0.09), 0.04, 1);
    const yaw = camera.rotation.y;
    const rx = Math.cos(yaw) * dx - Math.sin(yaw) * dz;
    return { dest: out(clamp(rx / (dist + 2), -0.8, 0.8)), k };
  }
  const api = {
    init, setVol, suspend, wake,
    shot(kind) { if (!ctx) return; const d = out();
      if (kind === 'pistol') { noise(0.16, 'bandpass', 2600, 700, 1.2, 0.9, d); tone('triangle', 180, 60, 0.12, 0.6, d); }
      else if (kind === 'smg') { noise(0.1, 'bandpass', 3600, 1200, 1, 0.7, d); tone('square', 160, 70, 0.06, 0.25, d); }
      // the rifle: a hard battle-rifle crack, a punchy body, a deep thump and a rolling echo
      else if (kind === 'rifle') { noise(0.035, 'highpass', 5200, 3000, 0.7, 1.1, d); noise(0.17, 'bandpass', 2100, 520, 0.9, 1.35, d); tone('sine', 95, 34, 0.22, 1.05, d);
        tone('square', 210, 70, 0.06, 0.32, d); noise(0.9, 'lowpass', 1500, 90, 0.5, 0.42, d, 0.035); noise(0.25, 'bandpass', 900, 380, 1.2, 0.22, d, 0.14); }
      // the machine gun: heavy and loud, a thick boom and the clack of the belt feeding, at 1,200 rounds a minute
      else if (kind === 'lmg') { noise(0.03, 'highpass', 4200, 2600, 0.8, 0.95, d); noise(0.15, 'bandpass', 1500, 380, 0.8, 1.35, d); tone('sine', 78, 30, 0.2, 1.15, d);
        tone('square', 140, 55, 0.07, 0.38, d); tone('square', 2300, 1700, 0.018, 0.09, d, 0.028); noise(0.45, 'lowpass', 900, 110, 0.5, 0.4, d, 0.02); }
      else if (kind === 'sniper') { noise(0.22, 'bandpass', 3800, 600, 0.7, 1.4, d); tone('sine', 90, 35, 0.35, 0.9, d); noise(1.3, 'lowpass', 1400, 90, 0.4, 0.35, d, 0.08); }
      else if (kind === 'gl') { tone('sine', 150, 55, 0.22, 0.9, d); noise(0.2, 'lowpass', 1400, 200, 0.8, 0.6, d); }
      // the rocket leaving the tube: a hard thump and a long rushing hiss
      else if (kind === 'rocket') { tone('sine', 120, 45, 0.3, 1.0, d); noise(0.12, 'lowpass', 1600, 300, 0.8, 0.9, d); noise(0.9, 'bandpass', 700, 2600, 0.9, 0.7, d, 0.03); noise(1.1, 'lowpass', 900, 150, 0.6, 0.35, d, 0.1); }
      else { noise(0.38, 'lowpass', 4200, 300, 0.7, 1.4, d); tone('sine', 110, 38, 0.3, 0.9, d); noise(0.6, 'lowpass', 1200, 120, 0.3, 0.3, d, 0.05); }
    },
    empty() { if (!ctx) return; tone('square', 1400, 900, 0.03, 0.12, out()); },
    reload(stage) { if (!ctx) return; const d = out();
      if (stage === 0) { noise(0.05, 'highpass', 3000, 2000, 1, 0.35, d); tone('square', 600, 400, 0.04, 0.08, d); }
      else { noise(0.06, 'highpass', 2200, 1600, 1, 0.45, d); tone('square', 900, 500, 0.05, 0.1, d, 0.02); }
    },
    pump() { if (!ctx) return; const d = out(); noise(0.08, 'bandpass', 1500, 900, 2, 0.4, d); noise(0.08, 'bandpass', 1100, 700, 2, 0.4, d, 0.12); },
    hit(head) { if (!ctx) return; const d = out(); tone('sine', head ? 2400 : 1700, head ? 1800 : 1300, 0.07, head ? 0.32 : 0.22, d); },
    // a shot to the head: a crunchy pop and a bright, ringing ding nobody can miss; a kill to the head adds a rising two-note chime
    headshot(kill) { if (!ctx) return; const d = out();
      noise(0.06, 'bandpass', 3600, 1400, 1.4, 0.95, d); tone('triangle', 2960, 2800, 0.32, 0.5, d); tone('sine', 4440, 4200, 0.26, 0.24, d, 0.004); tone('square', 680, 1500, 0.07, 0.16, d);
      if (kill) { tone('triangle', 1568, 1568, 0.12, 0.34, d, 0.1); tone('triangle', 2349, 2349, 0.24, 0.34, d, 0.17); noise(0.12, 'highpass', 6000, 8000, 1, 0.12, d, 0.17); } },
    // melee: the gun swung through the air, and what it lands on
    swing() { if (!ctx) return; const d = out(); noise(0.16, 'bandpass', 700, 2300, 1.3, 0.55, d); },
    melee(pos, metal) { if (!ctx) return; const s = spatial(pos); noise(0.14, 'lowpass', 1100, 160, 0.9, 1.0 * s.k, s.dest); tone('sine', 150, 55, 0.16, 0.7 * s.k, s.dest);
      if (metal) tone('square', 2600, 1700, 0.05, 0.1 * s.k, s.dest); else noise(0.08, 'bandpass', 1800, 700, 1.5, 0.4 * s.k, s.dest); },
    kill() { if (!ctx) return; const d = out(); tone('triangle', 900, 1400, 0.09, 0.25, d); tone('triangle', 1400, 1900, 0.12, 0.2, d, 0.06); },
    enemyShot(pos, kind) { if (!ctx) return; const s = spatial(pos);
      if (kind === 2) { tone('sawtooth', 220, 70, 0.4, 0.35 * s.k, s.dest); noise(0.3, 'lowpass', 1500, 200, 1, 0.3 * s.k, s.dest); }
      else { tone('sawtooth', kind === 0 ? 1500 : 1100, kind === 0 ? 500 : 300, 0.12, 0.22 * s.k, s.dest); }
    },
    boom(pos, big) { if (!ctx) return; const s = spatial(pos);
      noise(big ? 1.1 : 0.7, 'lowpass', big ? 2200 : 2800, 60, 0.6, (big ? 1.6 : 1.1) * s.k, s.dest);
      tone('sine', big ? 90 : 120, 30, big ? 0.8 : 0.5, 0.9 * s.k, s.dest);
    },
    metal(pos) { if (!ctx) return; const s = spatial(pos); tone('square', rand(2600, 3400), 1800, 0.04, 0.06 * s.k, s.dest); },
    hurt() { if (!ctx) return; const d = out(); tone('sine', 140, 60, 0.22, 0.7, d); noise(0.18, 'lowpass', 800, 200, 0.6, 0.5, d); },
    charge(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 90, 420, 0.7, 0.3 * s.k, s.dest); },
    spawn(pos) { if (!ctx) return; const s = spatial(pos); tone('sine', 300, 1200, 0.35, 0.16 * s.k, s.dest); noise(0.3, 'highpass', 4000, 1500, 0.8, 0.12 * s.k, s.dest); },
    pickup(kind) { if (!ctx) return; const d = out(); const b = kind === 'hp' ? 520 : 400;
      tone('triangle', b, b, 0.08, 0.25, d); tone('triangle', b * 1.25, b * 1.25, 0.08, 0.25, d, 0.07); tone('triangle', b * 1.5, b * 1.5, 0.14, 0.25, d, 0.14); },
    step() { if (!ctx) return; noise(0.07, 'lowpass', 600, 150, 0.8, 0.18, out()); },
    land() { if (!ctx) return; noise(0.12, 'lowpass', 500, 90, 0.7, 0.45, out()); },
    alarm() { if (!ctx) return; const d = out(); for (let i = 0; i < 3; i++) { tone('square', 660, 660, 0.18, 0.12, d, i * 0.42); tone('square', 520, 520, 0.18, 0.12, d, i * 0.42 + 0.2); } },
    clear() { if (!ctx) return; const d = out(); [523, 659, 784, 1046].forEach((f, i) => tone('triangle', f, f, 0.3, 0.2, d, i * 0.1)); },
    pistolFar(pos) { if (!ctx) return; const s = spatial(pos); noise(0.14, 'bandpass', 2200, 600, 1, 0.75 * s.k, s.dest); tone('triangle', 170, 60, 0.1, 0.35 * s.k, s.dest); },
    moan(pos) { if (!ctx) return; const s = spatial(pos), t = ctx.currentTime, f = rand(75, 115);
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(f, t); o.frequency.linearRampToValueAtTime(f * rand(0.7, 0.85), t + 0.9);
      const lfo = ctx.createOscillator(); lfo.frequency.value = rand(5, 8); const lg = ctx.createGain(); lg.gain.value = 9; lfo.connect(lg); lg.connect(o.frequency);
      const fl = ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = 650; fl.Q.value = 3;
      const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.32 * s.k, t + 0.15); g.gain.exponentialRampToValueAtTime(0.0008, t + 1.0);
      o.connect(fl); fl.connect(g); g.connect(s.dest); o.start(t); lfo.start(t); o.stop(t + 1.05); lfo.stop(t + 1.05); },
    bite() { if (!ctx) return; const d = out(); noise(0.25, 'bandpass', 900, 300, 1.5, 1.1, d); tone('sawtooth', 220, 60, 0.3, 0.5, d); },
    crack(pos) { if (!ctx) return; const s = spatial(pos); noise(0.18, 'bandpass', 1100, 500, 1.4, 0.9 * s.k, s.dest); noise(0.3, 'lowpass', 700, 150, 0.6, 0.4 * s.k, s.dest, 0.03); tone('triangle', 240, 90, 0.12, 0.3 * s.k, s.dest); },
    thud(pos) { if (!ctx) return; const s = spatial(pos); noise(0.2, 'lowpass', 420, 90, 0.7, 0.45 * s.k, s.dest); },
    coin() { if (!ctx) return; const d = out(); tone('triangle', 1760, 1760, 0.07, 0.18, d); tone('triangle', 2350, 2350, 0.16, 0.16, d, 0.06); },
    gulp() { if (!ctx) return; const d = out(); tone('sine', 300, 900, 0.35, 0.3, d); noise(0.2, 'highpass', 3000, 2000, 1, 0.15, d, 0.1); tone('triangle', 660, 990, 0.25, 0.2, d, 0.3); },
    heart() { if (!ctx) return; const d = out(); tone('sine', 70, 45, 0.12, 0.7, d); tone('sine', 65, 40, 0.12, 0.55, d, 0.18); },
    // syringe: cap off, needle in, plunger hiss
    inject() { if (!ctx) return; const d = out(); tone('square', 2200, 1500, 0.03, 0.06, d); noise(0.05, 'highpass', 5000, 3000, 1, 0.2, d, 0.02);
      noise(0.08, 'bandpass', 1200, 700, 2, 0.35, d, 0.32); noise(0.55, 'bandpass', 2800, 1700, 3, 0.2, d, 0.42); },
    // the antidote takes: a rising chime with a shimmer
    cured() { if (!ctx) return; const d = out(); [523, 659, 784, 1047].forEach((f, i) => tone('sine', f, f, 0.38, 0.17, d, i * 0.085));
      tone('triangle', 1568, 2093, 0.55, 0.08, d, 0.34); noise(0.7, 'highpass', 6500, 9000, 1, 0.05, d, 0.12); },
    scream(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 260, 880, 0.38, 0.32 * s.k, s.dest); noise(0.45, 'bandpass', 1500, 2600, 2, 0.35 * s.k, s.dest); },
    rage(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 95, 42, 1.3, 0.5 * s.k, s.dest); noise(1.2, 'lowpass', 520, 110, 1.5, 0.6 * s.k, s.dest); tone('square', 190, 70, 0.9, 0.14 * s.k, s.dest, 0.1); },
    ring() { if (!ctx) return; const d = out(); tone('sine', 3400, 3300, 2.0, 0.06, d); tone('sine', 3560, 3480, 1.8, 0.04, d, 0.05); noise(0.3, 'lowpass', 300, 80, 1, 0.5, d); },
    revive(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 65, 150, 0.8, 0.3 * s.k, s.dest); noise(0.6, 'lowpass', 300, 800, 1, 0.3 * s.k, s.dest); },
    zap(pos, kind) { if (!ctx) return; const s = spatial(pos), d = s.dest, k = s.k;
      const f = kind === 'mech' ? [520, 110, 0.2] : kind === 'drone' ? [1900, 650, 0.08] : kind === 'turret' ? [980, 240, 0.14] : kind === 'crawler' ? [2400, 900, 0.07] : [1300, 300, 0.12];
      tone('square', f[0], f[1], f[2], 0.16 * k, d); tone('sawtooth', f[0] * 0.5, f[1] * 0.5, f[2], 0.1 * k, d); noise(0.05, 'highpass', 4000, 3000, 1, 0.12 * k, d); },
    ping(pos) { if (!ctx) return; const s = spatial(pos); tone('triangle', 2600, 2400, 0.35, 0.22 * s.k, s.dest); tone('sine', 3900, 3600, 0.25, 0.12 * s.k, s.dest, 0.01); noise(0.05, 'highpass', 5000, 4000, 1, 0.3 * s.k, s.dest); },
    thump(pos) { if (!ctx) return; const s = spatial(pos); tone('sine', 140, 60, 0.18, 0.45 * s.k, s.dest); noise(0.12, 'lowpass', 600, 200, 1, 0.35 * s.k, s.dest); },
    beep(pos) { if (!ctx) return; const s = spatial(pos); for (let i = 0; i < 3; i++) tone('square', 1900, 1900, 0.05, 0.12 * s.k, s.dest, i * 0.09); },
    // enemy guns at a distance, each with its own voice
    farShot(pos, kind) { if (!ctx) return; const s = spatial(pos), d = s.dest, k = s.k;
      if (kind === 'deagle') { noise(0.22, 'lowpass', 1800, 300, 1, 1.0 * k, d); tone('sine', 120, 45, 0.22, 0.6 * k, d); }
      else if (kind === 'smg') { noise(0.07, 'bandpass', 2600, 900, 1.2, 0.55 * k, d); }
      else if (kind === 'rifle' || kind === 'lmg') { noise(0.11, 'bandpass', 2000, 500, 1, 0.75 * k, d); tone('triangle', 200, 70, 0.08, 0.3 * k, d); }
      else if (kind === 'sniper') { noise(0.35, 'lowpass', 2400, 250, 0.8, 1.1 * k, d); tone('sine', 90, 40, 0.4, 0.5 * k, d); noise(0.6, 'bandpass', 700, 300, 1, 0.25 * k, d, 0.12); }
      else if (kind === 'shotgun') { noise(0.3, 'lowpass', 1400, 200, 0.8, 1.0 * k, d); tone('sine', 100, 40, 0.25, 0.5 * k, d); }
      else { noise(0.14, 'bandpass', 2200, 600, 1, 0.75 * k, d); tone('triangle', 170, 60, 0.1, 0.35 * k, d); } },
    flame(pos) { if (!ctx) return; const s = spatial(pos); noise(0.22, 'lowpass', 900, 500, 0.7, 0.4 * s.k, s.dest); noise(0.2, 'bandpass', 300, 200, 1, 0.3 * s.k, s.dest); },
    saberHum(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 92, 96, 0.9, 0.08 * s.k, s.dest); tone('sine', 184, 190, 0.9, 0.07 * s.k, s.dest); },
    saberSwing(pos) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 120, 260, 0.25, 0.2 * s.k, s.dest); tone('sine', 300, 140, 0.25, 0.15 * s.k, s.dest); },
    // an aluminium bat connecting: a bright metallic crack over a dull thud
    batHit(pos) { if (!ctx) return; const s = spatial(pos); tone('triangle', 2100, 1700, 0.18, 0.28 * s.k, s.dest); tone('square', 950, 600, 0.08, 0.1 * s.k, s.dest); noise(0.16, 'lowpass', 900, 200, 1, 0.6 * s.k, s.dest); },
    saberHit(pos) { if (!ctx) return; const s = spatial(pos); noise(0.3, 'bandpass', 1800, 900, 2, 0.5 * s.k, s.dest); tone('sawtooth', 260, 80, 0.3, 0.3 * s.k, s.dest); },
    squelch(pos) { if (!ctx) return; const s = spatial(pos); noise(0.28, 'lowpass', 900, 160, 1, 0.65 * s.k, s.dest); tone('sine', 170, 45, 0.22, 0.4 * s.k, s.dest); },
    buy() { if (!ctx) return; const d = out(); [880, 1175, 1568].forEach((f, i) => tone('triangle', f, f, 0.14, 0.18, d, i * 0.07)); noise(0.06, 'highpass', 3000, 2000, 1, 0.15, d); },
    roar(pos, kind) { if (!ctx) return; const s = spatial(pos), d = s.dest, k = s.k;
      if (kind === 'cat') { tone('sawtooth', rand(95, 130), 60, 0.9, 0.38 * k, d); noise(0.9, 'lowpass', 520, 160, 2, 0.5 * k, d); }
      else if (kind === 'trumpet') { tone('sawtooth', 300, 720, 0.45, 0.32 * k, d); tone('sawtooth', 720, 480, 0.8, 0.28 * k, d, 0.4); noise(0.6, 'bandpass', 1400, 700, 3, 0.25 * k, d, 0.3); }
      else if (kind === 'beat') { for (let i = 0; i < 7; i++) { tone('sine', 95, 60, 0.09, 0.55 * k, d, i * 0.09); noise(0.06, 'lowpass', 500, 200, 1, 0.4 * k, d, i * 0.09); }
        tone('sawtooth', 140, 80, 0.7, 0.3 * k, d, 0.7); noise(0.7, 'lowpass', 700, 200, 1.5, 0.4 * k, d, 0.7); }
      else if (kind === 'bray') { for (let i = 0; i < 3; i++) tone('square', 620 + i * 60, 880, 0.16, 0.12 * k, d, i * 0.2); }
      else { tone('sine', 75, 45, 0.55, 0.6 * k, d); noise(0.5, 'lowpass', 380, 90, 1.2, 0.5 * k, d); }
    },
    rotor(level) { if (!ctx) return;
      if (!api._rot) { if (level <= 0) return;
        const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
        const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 420; f.Q.value = 0.8;
        const chop = ctx.createGain(); chop.gain.value = 0.5; const lfo = ctx.createOscillator(); lfo.frequency.value = 11.5; const depth = ctx.createGain(); depth.gain.value = 0.5;
        lfo.connect(depth); depth.connect(chop.gain);
        const whine = ctx.createOscillator(); whine.type = 'sine'; whine.frequency.value = 1650; const wg = ctx.createGain(); wg.gain.value = 0.015;
        const g = ctx.createGain(); g.gain.value = 0;
        src.connect(f); f.connect(chop); chop.connect(g); whine.connect(wg); wg.connect(g); g.connect(master);
        src.start(); lfo.start(); whine.start(); api._rot = { g }; }
      api._rot.g.gain.setTargetAtTime(level * 0.55, ctx.currentTime, 0.25);
    },
    // the jetpack: a roaring hiss that swells with thrust
    jet(level) { if (!ctx) return;
      if (!api._jet) { if (level <= 0) return;
        const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
        const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 900; f.Q.value = 0.7;
        const g = ctx.createGain(); g.gain.value = 0; src.connect(f); f.connect(g); g.connect(master); src.start(); api._jet = { g, f }; }
      const t = ctx.currentTime; api._jet.g.gain.setTargetAtTime(level * 0.32, t, 0.08); api._jet.f.frequency.setTargetAtTime(700 + level * 900, t, 0.1);
    },
    horn() { if (!ctx) return; const d = out(); [0, 0.42].forEach((t) => { tone('square', 415, 415, 0.3, 0.12, d, t); tone('square', 523, 523, 0.3, 0.1, d, t); }); },
    engine(level, speed) { if (!ctx) return;
      if (!api._eng) { if (level <= 0) return; const o = ctx.createOscillator(); o.type = 'sawtooth'; const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.Q.value = 2;
        const g = ctx.createGain(); g.gain.value = 0; o.connect(f); f.connect(g); g.connect(master); o.start(); api._eng = { o, f, g }; }
      const t = ctx.currentTime, e = api._eng;
      e.o.frequency.setTargetAtTime(34 + speed * 4.2, t, 0.15); e.f.frequency.setTargetAtTime(220 + speed * 28, t, 0.15); e.g.gain.setTargetAtTime(level * 0.13, t, 0.2);
    },
    whiz(pos) { if (!ctx) return; const s = spatial(pos); noise(0.15, 'bandpass', 3000, 1200, 4, 0.25 * s.k, s.dest); },
    // cage bars: an animal slamming into them, and a whole wall slapping down on the floor
    clank(pos) { if (!ctx) return; const s = spatial(pos); tone('square', rand(380, 520), 300, 0.12, 0.08 * s.k, s.dest); tone('triangle', rand(1300, 1700), 900, 0.18, 0.07 * s.k, s.dest); noise(0.12, 'bandpass', 2200, 1200, 3, 0.25 * s.k, s.dest); },
    clang(pos) { if (!ctx) return; const s = spatial(pos), d = s.dest, k = s.k;
      noise(0.5, 'lowpass', 1600, 80, 0.7, 1.2 * k, d); tone('sine', 85, 40, 0.5, 0.8 * k, d);
      [523, 787, 1123, 1597].forEach((f, i) => tone('triangle', f, f * 0.97, 1.1 - i * 0.15, 0.09 * k, d, 0.01 * i)); noise(0.9, 'bandpass', 3000, 1800, 6, 0.18 * k, d, 0.05); },
    // the big red button, then the room's alarm siren
    press() { if (!ctx) return; const d = out(); tone('square', 180, 90, 0.08, 0.25, d); noise(0.06, 'lowpass', 900, 300, 1, 0.4, d); },
    /* 5.14: the boss's laser lock: an emergency wail rising and falling under twice a second, loud, for as long as the red line hunts you */
    hiss() { if (!ctx) return; const d = out(); noise(1.4, 'highpass', 2600, 5200, 0.7, 0.42, d); noise(0.5, 'bandpass', 900, 300, 1.2, 0.3, d); },
    siren2(dur) {
      if (!ctx) return; const d = out(), t = ctx.currentTime, end = t + Math.max(0.5, dur);
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 3400; lp.Q.value = 0.8;
      const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.85, t + 0.05); g.gain.setValueAtTime(0.85, end - 0.12); g.gain.exponentialRampToValueAtTime(0.0008, end);
      lp.connect(g); g.connect(d);
      const lfo = ctx.createOscillator(); lfo.type = 'sine'; lfo.frequency.value = 1.8; lfo.start(t); lfo.stop(end + 0.05);
      for (const [type, f, a] of [['sawtooth', 860, 0.5], ['square', 430, 0.22], ['sawtooth', 1290, 0.12]]) {
        const o = ctx.createOscillator(); o.type = type; o.frequency.value = f;
        const dep = ctx.createGain(); dep.gain.value = f * 0.36; lfo.connect(dep); dep.connect(o.frequency);
        const og = ctx.createGain(); og.gain.value = a; o.connect(og); og.connect(lp); o.start(t); o.stop(end + 0.05);
      }
    },
    siren() { if (!ctx) return; const d = out(); for (let i = 0; i < 3; i++) { tone('sawtooth', 520, 880, 0.5, 0.11, d, i * 0.6); tone('sawtooth', 880, 520, 0.1, 0.06, d, i * 0.6 + 0.5); } },
    // the monkey: a high chattering cackle
    cackle(pos) { if (!ctx) return; const s = spatial(pos); for (let i = 0; i < 7; i++) { tone('square', rand(900, 1300), rand(600, 800), 0.07, 0.07 * s.k, s.dest, i * 0.085); } noise(0.6, 'bandpass', 2600, 1900, 4, 0.08 * s.k, s.dest); },
    // a big fist through the air, and the slam that shakes the floor
    swoosh(pos) { if (!ctx) return; const s = spatial(pos); noise(0.28, 'bandpass', 500, 1400, 1.5, 0.45 * s.k, s.dest); },
    // the boss drone's laser: a whine that climbs for as long as it aims (dur), then the crack of the beam
    charge(pos, dur) { if (!ctx) return; const s = spatial(pos); tone('sawtooth', 180, 1400, dur, 0.1 * s.k, s.dest); tone('sine', 360, 2800, dur, 0.08 * s.k, s.dest); },
    beam(pos) { if (!ctx) return; const s = spatial(pos); noise(0.5, 'bandpass', 2400, 600, 1.2, 0.6 * s.k, s.dest); tone('sawtooth', 900, 120, 0.45, 0.22 * s.k, s.dest); tone('square', 3000, 400, 0.3, 0.1 * s.k, s.dest); },
    // a homing rocket leaving its pod
    rocket(pos) { if (!ctx) return; const s = spatial(pos); noise(0.35, 'bandpass', 700, 2200, 1.2, 0.32 * s.k, s.dest); tone('sawtooth', 160, 420, 0.3, 0.06 * s.k, s.dest); },
    // a spider mine waking up under your feet
    chirp(pos) { if (!ctx) return; const s = spatial(pos); for (let i = 0; i < 2; i++) tone('square', 2600, 3400, 0.06, 0.14 * s.k, s.dest, i * 0.08); },
    quake(pos) { if (!ctx) return; const s = spatial(pos), d = s.dest; noise(1.4, 'lowpass', 900, 40, 0.6, 1.8 * s.k, d); tone('sine', 60, 25, 1.2, 1.0 * s.k, d); noise(0.5, 'bandpass', 1500, 400, 1, 0.6 * s.k, d, 0.03); },
  };
  return api;
})();

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

/* ============ physics: colliders, spatial index, rays, navigation ============ */
let HALF = 66;
const colliders = [];
const SPC = 8;
let SPN = 20, SPO = 80;
let spatialCells = [];
/* playable half-size of the current stage; the spatial index is sized to it and starts empty, and every box added
   from then on goes straight into it, so queries made while the stage is still being built see this stage, not the last one */
function setWorldSize(half) {
  HALF = half; SPO = half + 14; SPN = Math.ceil((2 * SPO) / SPC);
  spatialCells = new Array(SPN * SPN); for (let i = 0; i < spatialCells.length; i++) spatialCells[i] = [];
}
let qstamp = 1;
/* 5.16: ground below the ground. the ship's main hall has a stepped pit sunk in its floor: inside the pit's outline the base ground is
   its bottom (the steps are boxes standing on it, flagged 'step'); everywhere else it is y = 0, as it always was */
let PIT = null;
function floorY(x, z) { return PIT !== null && x > PIT.x0 && x < PIT.x1 && z > PIT.z0 && z < PIT.z1 ? PIT.y : 0; }
function addCollider(minx, miny, minz, maxx, maxy, maxz, kind, ref) {
  const b = { minx, miny, minz, maxx, maxy, maxz, kind: kind || 'concrete', ref: ref || null, _q: 0 };
  colliders.push(b);
  if (spatialCells.length === SPN * SPN) { const [i0, j0, i1, j1] = cellRange(minx, minz, maxx, maxz); for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) spatialCells[j * SPN + i].push(b); }
  return b;
}
function cellRange(minx, minz, maxx, maxz) {
  return [clamp(Math.floor((minx + SPO) / SPC), 0, SPN - 1), clamp(Math.floor((minz + SPO) / SPC), 0, SPN - 1),
    clamp(Math.floor((maxx + SPO) / SPC), 0, SPN - 1), clamp(Math.floor((maxz + SPO) / SPC), 0, SPN - 1)];
}
function indexColliders() {
  spatialCells = new Array(SPN * SPN); for (let i = 0; i < spatialCells.length; i++) spatialCells[i] = [];
  for (const b of colliders) {
    const [i0, j0, i1, j1] = cellRange(b.minx, b.minz, b.maxx, b.maxz);
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) spatialCells[j * SPN + i].push(b);
  }
}
/* while a stage is being built the spatial index is not ready yet: check the boxes themselves */
function boxAt(x, z, r, y0, y1) {
  for (const b of colliders) if (x + r > b.minx && x - r < b.maxx && z + r > b.minz && z - r < b.maxz && y1 > b.miny && y0 < b.maxy) return b;
  return null;
}
function removeCollider(b) {
  const k = colliders.indexOf(b); if (k >= 0) colliders.splice(k, 1);
  const [i0, j0, i1, j1] = cellRange(b.minx, b.minz, b.maxx, b.maxz);
  for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) { const c = spatialCells[j * SPN + i], n = c.indexOf(b); if (n >= 0) c.splice(n, 1); }
}
const nearList = [];
function queryNear(minx, minz, maxx, maxz) {
  nearList.length = 0; qstamp++;
  const [i0, j0, i1, j1] = cellRange(minx, minz, maxx, maxz);
  for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) {
    const c = spatialCells[j * SPN + i];
    for (let k = 0; k < c.length; k++) { const b = c[k]; if (b._q !== qstamp) { b._q = qstamp; nearList.push(b); } }
  }
  return nearList;
}
function collideAt(x, y, z, r, h) {
  const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (y + h <= b.miny || y >= b.maxy - 0.001) continue;
    return b; }
  return null;
}
function moveXZ(p, dx, dz, r, h, stepH) {
  let blocked = false;
  for (let axis = 0; axis < 2; axis++) {
    const d = axis === 0 ? dx : dz; if (d === 0) continue;
    const nx = axis === 0 ? p.x + d : p.x, nz = axis === 1 ? p.z + d : p.z;
    const b = collideAt(nx, p.y, nz, r, h);
    if (!b) { p.x = nx; p.z = nz; continue; }
    if (stepH > 0 && b.maxy - p.y <= stepH && !collideAt(nx, b.maxy + 0.002, nz, r, h)) { p.x = nx; p.z = nz; p.y = b.maxy + 0.001; continue; }
    blocked = true;
    if (axis === 0) p.x = d > 0 ? Math.min(p.x, b.minx - r - 0.001) : Math.max(p.x, b.maxx + r + 0.001);
    else p.z = d > 0 ? Math.min(p.z, b.minz - r - 0.001) : Math.max(p.z, b.maxz + r + 0.001);
  }
  return blocked;
}
function groundAt(x, y, z, r) {
  let g = floorY(x, z); const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (b.maxy <= y + 0.06 && b.maxy > g) g = b.maxy; }
  return g;
}
function ceilAt(x, y, z, r, h) {
  let c = Infinity; const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (b.miny >= y + h - 0.05 && b.miny < c) c = b.miny; }
  return c;
}
/* ray vs static boxes and the ground; result in RH */
const RH = { t: 0, nx: 0, ny: 0, nz: 0, box: null };
function raycastStatic(ox, oy, oz, dx, dy, dz, maxT) {
  let best = maxT, hit = false;
  if (dy < -1e-6) {
    // the ground plane, or the bottom of the pit for a ray that goes down into it (or starts in it)
    let fy = 0; if (PIT !== null) { const t0 = -oy / dy, hx = ox + dx * t0, hz = oz + dz * t0; if (oy < 0 || (hx > PIT.x0 && hx < PIT.x1 && hz > PIT.z0 && hz < PIT.z1)) fy = PIT.y; }
    const tg = (fy - oy) / dy; if (tg >= 0 && tg < best) { best = tg; RH.nx = 0; RH.ny = 1; RH.nz = 0; RH.box = null; hit = true; }
  }
  const ex = ox + dx * best, ez = oz + dz * best;
  const L = queryNear(Math.min(ox, ex), Math.min(oz, ez), Math.max(ox, ex), Math.max(oz, ez));
  for (let i = 0; i < L.length; i++) {
    const b = L[i]; if (b.grate && !b.glass) continue; // cage bars: you can see and shoot through them (not the boss's, lined with glass)
    let t0 = 0, t1 = best, ax = -1, sg = 0, ta, tb, s;
    if (Math.abs(dx) < 1e-9) { if (ox < b.minx || ox > b.maxx) continue; }
    else { ta = (b.minx - ox) / dx; tb = (b.maxx - ox) / dx; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 0; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (Math.abs(dy) < 1e-9) { if (oy < b.miny || oy > b.maxy) continue; }
    else { ta = (b.miny - oy) / dy; tb = (b.maxy - oy) / dy; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 1; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (Math.abs(dz) < 1e-9) { if (oz < b.minz || oz > b.maxz) continue; }
    else { ta = (b.minz - oz) / dz; tb = (b.maxz - oz) / dz; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 2; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (t0 < best) { best = t0; hit = true; RH.box = b; RH.nx = ax === 0 ? sg : 0; RH.ny = ax === 1 ? sg : 0; RH.nz = ax === 2 ? sg : 0; }
  }
  RH.t = best; return hit;
}
function lineOfSight(a, b) {
  const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z, d = Math.hypot(dx, dy, dz);
  if (d < 0.01) return true;
  return !raycastStatic(a.x, a.y, a.z, dx / d, dy / d, dz / d, d - 0.05);
}

/* ---------- navigation: 1 m grid flow field toward the player ---------- */
const NAV = { n: 140, off: 70, cs: 1, blocked: null, dist: null };
let bfsQ = new Int32Array(140 * 140);
/* n cells of cs metres per side, centred on the origin */
function setNav(n, cs) { NAV.n = n; NAV.cs = cs; NAV.off = (n * cs) / 2; bfsQ = new Int32Array(n * n); }
const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
function navCell(x, z) { return [clamp(Math.floor((x + NAV.off) / NAV.cs), 0, NAV.n - 1), clamp(Math.floor((z + NAV.off) / NAV.cs), 0, NAV.n - 1)]; }
function buildNav() {
  const n = NAV.n; NAV.blocked = new Uint8Array(n * n); NAV.dist = new Int32Array(n * n).fill(-1);
  for (const b of colliders) {
    if (b.miny >= 1.6 || b.door || b.step) continue; // a sliding door is a way through, open or not; so are the pit's steps
    const pad = 0.5, cs = NAV.cs;
    const x0 = Math.max(0, Math.floor((b.minx - pad + NAV.off) / cs)), x1 = Math.min(n - 1, Math.floor((b.maxx + pad + NAV.off) / cs));
    const z0 = Math.max(0, Math.floor((b.minz - pad + NAV.off) / cs)), z1 = Math.min(n - 1, Math.floor((b.maxz + pad + NAV.off) / cs));
    for (let i = x0; i <= x1; i++) for (let j = z0; j <= z1; j++) {
      const cx = (i + 0.5) * cs - NAV.off, cz = (j + 0.5) * cs - NAV.off;
      const ex = Math.max(b.minx - cx, 0, cx - b.maxx), ez = Math.max(b.minz - cz, 0, cz - b.maxz);
      if (Math.hypot(ex, ez) < pad + 0.15 * cs) NAV.blocked[j * n + i] = 1;
    }
  }
  // a level made of rooms (the ship) also shuts off everything outside them, so the flow field does not flood the void
  if (World.navMask) for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (!World.navMask((i + 0.5) * NAV.cs - NAV.off, (j + 0.5) * NAV.cs - NAV.off)) NAV.blocked[j * n + i] = 1;
}
function updateFlow(px, pz) {
  const n = NAV.n, dist = NAV.dist, blk = NAV.blocked; dist.fill(-1);
  const [ci, cj] = navCell(px, pz); const s = cj * n + ci;
  let head = 0, tail = 0; bfsQ[tail++] = s; dist[s] = 0;
  while (head < tail) {
    const c = bfsQ[head++], i = c % n, j = (c / n) | 0, d = dist[c] + 1;
    for (let k = 0; k < 8; k++) {
      const di = DIRS[k][0], dj = DIRS[k][1], ni = i + di, nj = j + dj;
      if (ni < 0 || nj < 0 || ni >= n || nj >= n) continue;
      const nc = nj * n + ni;
      if (dist[nc] !== -1 || blk[nc]) continue;
      if (di && dj && (blk[j * n + ni] || blk[nj * n + i])) continue;
      dist[nc] = d; bfsQ[tail++] = nc;
    }
  }
}
function flowDir(x, z, out) {
  const n = NAV.n, [i, j] = navCell(x, z), dist = NAV.dist, blk = NAV.blocked;
  let bd = dist[j * n + i]; if (bd < 0) bd = 1e9;
  let bi = -1, bj = -1;
  for (let k = 0; k < 8; k++) {
    const di = DIRS[k][0], dj = DIRS[k][1], ni = i + di, nj = j + dj;
    if (ni < 0 || nj < 0 || ni >= n || nj >= n) continue;
    const d = dist[nj * n + ni];
    if (d < 0 || d >= bd) continue;
    if (di && dj && (blk[j * n + ni] || blk[nj * n + i])) continue;
    bd = d; bi = ni; bj = nj;
  }
  if (bi < 0) return false;
  out.x = (bi + 0.5) * NAV.cs - NAV.off - x; out.z = (bj + 0.5) * NAV.cs - NAV.off - z;
  const l = Math.hypot(out.x, out.z) || 1; out.x /= l; out.z /= l; return true;
}

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
  removeCollider(c.b); buildNav();
  const at = { x: c.x, y: (c.y || 0) + 0.6, z: c.z };
  FX.chunks(at, 9, 0.28, 'wood'); FX.puff(at, 4, 0.35, 0.6); Sound.crack(at);
  Game.onCrate(c);
}

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
/* ============ stage 4: inside a spaceship, laid out after your drawing ============
   from the airlock (시작) a narrow dog-leg passage climbs north into a long corridor (복도, 160 m). the bridge (운전실) is at its west end:
   twice the floor of the old one and twice as tall, with an open gallery round three sides at 7 m and a wide stair up each side.
   the main hall (메인홀) is at its east end: 94 x 93 m, an upside-down stepped pyramid sunk in its floor and a pyramid roof over it (5.16).
   both have sliding doors onto the corridor */
const SHIP_ROOMS = [
  // x0, z0, x1, z1, ceiling height (the hall's: the top of its walls, where the roof starts), kind
  [-123, -28, -92, 13, 16, 'bridge'],
  [-92, -12.5, 68, -2.5, 6, 'corr'],
  [68, -48.5, 162, 44.5, 20, 'hall'], // 5.16: twice as wide and twice as deep as the old 47 x 46.5 m
  [-26.5, -2.5, -22, 7, 4.5, 'pass'],
  [-44, 7, -22, 13, 4.5, 'pass'],
  [-44, 13, -39.5, 25, 4.5, 'pass'],
  [-44, 25, -39.5, 29.5, 4.5, 'lock'],
];
const SHIP_START = { x: -41.75, z: 22.6, yaw: 0 };
const SHIP_DOOR_Z = 25;
/* 5.16, after your drawing: sunk in the middle of the main hall is an upside-down stepped pyramid. four flights of eight 37.5 cm steps
   run down all four sides, with a landing after each of the first three, to a floor 12 m below with the reactor standing in it. square
   pillars stand on the corners of the first and the third landing, 32 m tall (twice the old ones). over the hall a pyramid roof rises
   from the top of the 20 m walls to a point 46 m up, so from the side the hall is a diamond: a pyramid on top, a pyramid upside down below */
const PYR = (() => {
  const R = SHIP_ROOMS[2], cx = (R[0] + R[2]) / 2, cz = (R[1] + R[3]) / 2, hx = (R[2] - R[0]) / 2, hz = (R[3] - R[1]) / 2;
  const ox = 38.5, oz = 38, rise = 0.375, run = 0.55, per = 8, land = [4, 3, 3.5]; // the rim's half-size, each step, the three landings
  const steps = []; let ax = ox, az = oz; // each step a ring: its outer half-size, its top, its width
  for (let k = 1; k < 4 * per; k++) { const L = k % per ? 0 : land[k / per - 1], w = run + L; steps.push({ k, ax, az, y: -rise * k, w, land: L ? k / per : 0 }); ax -= w; az -= w; }
  return { cx, cz, hx, hz, ox, oz, rise, run, per, steps, bottom: -rise * 4 * per, bx: ax, bz: az, wall: R[4], apex: 46 };
})();
/* the underside of the hall's roof over a point */
function hallRoof(x, z) { const u = Math.min(1, Math.max(Math.abs(x - PYR.cx) / PYR.hx, Math.abs(z - PYR.cz) / PYR.hz)); return PYR.wall + (PYR.apex - PYR.wall) * (1 - u); }
function inPit(x, z, m) { return Math.abs(x - PYR.cx) < PYR.ox + (m || 0) && Math.abs(z - PYR.cz) < PYR.oz + (m || 0); }
const REACTOR = { x: PYR.cx, z: PYR.cz, r: 1.7, base: PYR.bottom + 0.35, dais: 3.5 };
/* the pillars: x, z, half-width, foot, top, and whether it holds up the roof (the outer four) or ends in a light 32 m up (the inner four) */
const HALL_PILLARS = [];
for (const [L, half, roof] of [[PYR.steps[PYR.per - 1], 1.5, true], [PYR.steps[3 * PYR.per - 1], 1.25, false]]) {
  const mx = L.ax - L.w / 2, mz = L.az - L.w / 2;
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const x = PYR.cx + sx * mx, z = PYR.cz + sz * mz;
    HALL_PILLARS.push([x, z, half, L.y, roof ? hallRoof(x - sx * half, z - sz * half) + 0.3 : L.y + 32, roof]);
  }
}
/* the bridge's gallery: 7 m up, 5 m deep along the north, south and east walls; the north and south runs start as stairs */
const BRIDGE = { gy: 7, x0: -123, x1: -92, z0: -28, z1: 13, stairX0: -117, stairX1: -107.4, eastX: -97, steps: 16 };
/* the sliding doors where the corridor meets the bridge and the hall, and the hatches in the hall floor that open at the boss's third phase */
const SHIP_DOORS = [{ x: -91.7, z0: -12.5, z1: -2.5, h: 6, name: '운전실', inward: -1, room: 'bridge', who: 'gdrone', title: '황금꿀벌드론', tone: 'bee', needKey: false },
  { x: 67.7, z0: -12.5, z1: -2.5, h: 6, name: '메인홀', inward: 1, room: 'hall', who: 'bdrone', title: '최첨단 감시 드론 보스 B-3', tone: 'boss', needKey: true }];
/* the main hall's key, stuck upright in the commander's console in the middle of the bridge */
const SHIP_KEY = { x: -105, y: 1.6, z: -7.5 };
/* where the save point puts you back: on the bridge, just inside its door, facing out */
const SHIP_SAVE = { x: -98.5, z: -7.5, yaw: -Math.PI / 2 };
/* x, z and the floor they are in: four round the walkway, four round the reactor at the bottom of the pit */
const HATCHES = (() => { const R = SHIP_ROOMS[2], P = PYR, d = 6.5;
  return [[P.cx, (R[1] + P.cz - P.oz) / 2, 0], [P.cx, (P.cz + P.oz + R[3]) / 2, 0], [(P.cx + P.ox + R[2]) / 2, P.cz, 0], [(R[0] + P.cx - P.ox) / 2, 22, 0],
    [P.cx - d, P.cz - d, P.bottom], [P.cx + d, P.cz - d, P.bottom], [P.cx - d, P.cz + d, P.bottom], [P.cx + d, P.cz + d, P.bottom]]; })();
/* the room a point is in (the airlock does not count: you never get in there) */
function shipRoom(x, z) { for (const R of SHIP_ROOMS) if (R[5] !== 'lock' && x >= R[0] && x <= R[2] && z >= R[1] && z <= R[3]) return R; return null; }
function shipCeil(x, z) { const R = shipRoom(x, z); return R ? (R[5] === 'hall' ? hallRoof(x, z) - 1 : R[4]) : 30; } // under the hall's roof: a metre short of it
const Ship = {
  active: false, door: null, doorOpen: 0, closing: false, coreMat: null, ring: null, ring2: null, screens: null, doors: [], hatches: [], hatchQ: [], hatchWait: 0,
  key: false, keyObj: null, keyGlow: null, keyHintT: 0, saveT: 0,
  reset() { this.active = false; this.door = null; this.doorOpen = 0; this.closing = false; this.coreMat = null; this.ring = null; this.ring2 = null; this.screens = null; this.doors = []; this.hatches = []; this.hatchQ = []; this.hatchWait = 0;
    this.key = false; this.keyObj = null; this.keyGlow = null; this.keyHintT = 0; this.saveT = 0; },
  /* the gold bee on the bridge and the boss in the hall (5.13): each sits behind its door and takes no notice of anything until you come through it */
  drone(D) { return Enemies.list.find((o) => o.alive && o.type === D.who) || null; },
  enter(D) {
    const e = this.drone(D);
    if (!e) { D.mode = 'open'; return; } // nothing left in there: just a door
    D.mode = 'cut'; state = 'cutscene'; Gun.trigger = false; Gun.adsHeld = false; keys.clear(); jetEnd(); Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
    Cut.startBossIntro(D, e, () => this.lockIn(D));
  },
  /* after the look inside: you are just through the door, it slides shut behind you and locks until the thing in there is dead */
  lockIn(D) {
    const cz = (D.z0 + D.z1) / 2, e = this.drone(D);
    // nobody follows you in: anything standing in the doorway goes back out into the corridor
    for (const o of Enemies.list) if (o.alive && o !== e && !o.fly && Math.abs(o.pos.z - cz) < 6) { const inside = (o.pos.x - D.x) * D.inward; if (inside > -0.6 && inside < 0.6) o.pos.x = D.x - D.inward * 2.5; else if (inside >= 0.6 && inside < 4) o.pos.x = D.x + D.inward * 5; }
    player.pos.set(D.x + D.inward * 2.4, 0, cz); player.vel.set(0, 0, 0); player.yaw = D.inward < 0 ? Math.PI / 2 : -Math.PI / 2; player.pitch = 0;
    D.mode = 'locked';
    if (e) { e.sealed = false; Enemies.alarm(e); }
    for (const o of Enemies.list) if (o.alive && o.sealed && shipRoom(o.pos.x, o.pos.z) === shipRoom(player.pos.x, player.pos.z)) o.sealed = false; // the hall's patrols too
    HUD.banner('문이 잠겼습니다', D.room === 'bridge' ? '황금꿀벌드론을 쓰러뜨려야 문이 열립니다' : '눈이 빨개지고 3초 뒤 빨간 조준선이 쫓아옵니다 · 레이저에 맞으면 즉사 · 벽 뒤로 숨으세요', 2.6);
    backToPlay();
  },
  /* the thing behind a door is dead: that door opens for good. the bee's also makes the save point (Game.takeSave) */
  onDown(e) {
    const D = this.doors.find((d) => d.who === e.type); if (!D) return;
    D.mode = 'open'; Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
    if (D.room === 'bridge') this.saveT = 2.4; // the 'go and get the key' banner, once the kill banner has had its moment
  },
  keyNear() { return !!this.keyObj && !this.key && !Enemies.list.some((o) => o.alive && o.type === 'gdrone') && Math.hypot(player.pos.x - SHIP_KEY.x, player.pos.z - SHIP_KEY.z) < 2.6 && player.pos.y < 2.5; }, // only once the bee is down
  takeKey() {
    if (state !== 'playing' || !this.keyNear()) return false;
    this.key = true; this.keyObj.visible = false; Sound.pickup('ammo'); Sound.buy(); Sound.pickup('hp');
    Game.takeSave(); // the save point: from here on, with the key in your pocket
    HUD.banner('세이브 포인트', '메인홀 열쇠 획득 · 이제 쓰러져도 열쇠를 가진 채 여기서 다시 시작합니다', 3.6); HUD.feed('메인홀 열쇠 획득 · 세이브 포인트', 0);
    return true;
  },
  /* back from the save point: the bridge door stands open and the key is where it was (or in your pocket) */
  restore(sp) {
    const D = this.doors.find((d) => d.room === 'bridge'); if (D) { D.mode = 'open'; D.open = 1; if (D.col) { removeCollider(D.col); D.col = null; } this.slide(D); }
    if (sp.key) { this.key = true; if (this.keyObj) this.keyObj.visible = false; }
  },
  slide(D) { const w = (D.z1 - D.z0) / 2, k = D.open * D.open * (3 - 2 * D.open); D.a.position.z = D.z0 + w / 2 - k * w; D.b.position.z = D.z1 - w / 2 + k * w; },
  /* the two doors: shut until you stand right against one from the corridor side (the hall's also wants the key); then they slide open
     for the look inside, shut and lock behind you, and open for good once what is inside is dead. shut, they stop bullets */
  doorTick(dt) {
    this.keyHintT -= dt;
    for (const D of this.doors) {
      if (D.mode === 'shut' && state === 'playing' && !Game.ended) {
        const out = (player.pos.x - D.x) * -D.inward; // how far out in the corridor
        if (out > 0 && out < 1.3 && player.pos.z > D.z0 + 0.3 && player.pos.z < D.z1 - 0.3 && player.pos.y < 2.5) {
          if (D.needKey && !this.key) { if (this.keyHintT <= 0) { this.keyHintT = 3.5; HUD.hint('메인홀 문이 잠겨 있습니다 · 운전실 조종석에 꽂힌 열쇠가 필요합니다', 3); Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 }); } }
          else this.enter(D);
        }
      }
      const want = D.mode === 'cut' || D.mode === 'open';
      const o0 = D.open; D.open = clamp(D.open + (want ? dt * 2.6 : -dt * 2.4), 0, 1);
      if (D.open > 0.55 && D.col) { removeCollider(D.col); D.col = null; }
      if (D.open < 0.45 && !D.col) { D.col = addCollider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, 'metal'); D.col.door = true; }
      if ((o0 === 0 && D.open > 0) || (o0 === 1 && D.open < 1)) Sound.clank({ x: D.x, y: 2, z: (D.z0 + D.z1) / 2 });
      if (D.open !== o0) this.slide(D);
    }
  },
  /* the boss's third phase: every hatch in the hall floor slides open and drones come up out of them, a few at a time */
  openHatches() {
    if (this.hatchQ.length || !this.hatches.length || this.hatches[0].open) return;
    for (const H of this.hatches) H.open = true;
    for (let i = 0; i < 32; i++) { const H = this.hatches[i % this.hatches.length]; this.hatchQ.push({ x: H.x, z: H.z, y: H.y, t: 1.2 + Math.floor(i / this.hatches.length) * 2.2 + rand(0, 0.8) }); }
    Sound.alarm(); HUD.banner('해치 개방', '메인홀 바닥에서 드론 수십 대가 출격합니다', 2.6);
  },
  /* the airlock door, the reactor's pulse, the slow ring over it */
  anim(dt, t) {
    if (!this.active) return;
    this.doorTick(dt);
    for (const H of this.hatches) { H.k = Math.min(1, H.k + (H.open ? dt * 1.5 : 0)); H.lidA.position.x = H.x - 0.6 - H.k * 1.15; H.lidB.position.x = H.x + 0.6 + H.k * 1.15; H.glow.visible = H.shaft.visible = H.k > 0.05; if (H.glow.visible) { H.glow.material.opacity = 0.75 + 0.2 * Math.sin(t * 8 + H.x); H.shaft.scale.y = H.k * (0.9 + 0.1 * Math.sin(t * 5 + H.z)); H.shaft.position.y = H.y + 1.7 * H.shaft.scale.y; } }
    if (this.closing) { this.doorOpen = Math.max(0, this.doorOpen - dt * 0.9); if (this.doorOpen === 0) this.closing = false; }
    if (this.door) this.door.position.y = 2.25 + this.doorOpen * 4.3;
    if (this.coreMat) { const k = 0.82 + 0.14 * Math.sin(t * 2.6) + 0.04 * Math.sin(t * 19); this.coreMat.color.setRGB(0.45 * k, 0.82 * k, 1.0 * k); }
    if (this.ring) this.ring.rotation.z += dt * 0.35;
    if (this.ring2) this.ring2.rotation.z -= dt * 0.6;
    if (this.screens) this.screens.material.color.setScalar(0.85 + 0.15 * Math.sin(t * 4.3));
    if (this.keyObj && this.keyObj.visible) { this.keyObj.rotation.y += dt * 1.2; this.keyGlow.material.opacity = 0.55 + 0.3 * Math.sin(t * 4); }
    if (this.saveT > 0 && (this.saveT -= dt) <= 0 && !this.key) { HUD.banner('운전실 문이 열렸습니다', '조종석에 꽂힌 메인홀 열쇠를 뽑으세요 · 뽑으면 세이브 포인트', 3.4); }
  },
};
/* a box whose texture keeps its size in metres on every face (s metres per tile) */
function uvBox(x0, y0, z0, x1, y1, z1, s) {
  const g = new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0); g.translate((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    if (Math.abs(n.getX(i)) > 0.5) uv.setXY(i, z / s, y / s); else if (Math.abs(n.getY(i)) > 0.5) uv.setXY(i, x / s, z / s); else uv.setXY(i, x / s, y / s);
  }
  return g;
}
function buildShip(G, S, R, r) {
  const keep = World.keep, B = AnimalKit.geoBox, M = AnimalKit.merge;
  Ship.active = true;
  /* ---- textures ---- */
  const plate = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#2b3039'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 5000, ['#30353f', '#262a32', '#343a45'], 1.6);
    g.strokeStyle = 'rgba(12,14,18,0.9)'; g.lineWidth = 3; for (let k = 0; k <= 4; k++) { g.beginPath(); g.moveTo(k * w / 4, 0); g.lineTo(k * w / 4, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 4); g.lineTo(w, k * h / 4); g.stroke(); }
    g.fillStyle = 'rgba(160,170,190,0.35)'; for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) for (const [dx, dy] of [[10, 10], [w / 4 - 10, 10], [10, h / 4 - 10], [w / 4 - 10, h / 4 - 10]]) { g.beginPath(); g.arc(i * w / 4 + dx, j * h / 4 + dy, 2.5, 0, TAU); g.fill(); }
    for (let i = 0; i < 10; i++) { g.fillStyle = 'rgba(8,10,14,' + rand(0.1, 0.25) + ')'; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(15, 60), rand(6, 25), rand(0, 3), 0, TAU); g.fill(); }
  }, 1, 1));
  const hallTex = keep(canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#1f242d'; g.fillRect(0, 0, w, h); speckle(g, w, h, 4000, ['#232832', '#1b1f27', '#272d38'], 1.6);
    g.strokeStyle = 'rgba(8,10,14,0.95)'; g.lineWidth = 4; for (let k = 0; k <= 2; k++) { g.beginPath(); g.moveTo(k * w / 2, 0); g.lineTo(k * w / 2, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 2); g.lineTo(w, k * h / 2); g.stroke(); }
    g.strokeStyle = 'rgba(90,200,255,0.35)'; g.lineWidth = 2; g.strokeRect(26, 26, w / 2 - 52, h / 2 - 52); g.strokeRect(w / 2 + 26, h / 2 + 26, w / 2 - 52, h / 2 - 52);
  }, 1, 1));
  const panel = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#3a404d'; g.fillRect(0, 0, w, h);
    for (let x = 0; x < w; x += 64) { g.fillStyle = (x / 64) % 2 ? '#353a46' : '#3f4653'; g.fillRect(x + 2, 2, 60, h - 4); }
    g.fillStyle = 'rgba(10,12,16,0.8)'; g.fillRect(0, h / 2 - 2, w, 4);
    g.fillStyle = 'rgba(200,170,60,0.5)'; g.fillRect(0, h - 10, w, 6);
    speckle(g, w, h, 1200, ['rgba(0,0,0,0.25)', 'rgba(255,255,255,0.05)'], 1.5);
  }, 1, 1));
  const grate = keep(canvasTex(128, 128, (g, w, h) => {
    g.fillStyle = '#1c2027'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#4a5260'; for (let i = 0; i < w; i += 8) { g.fillRect(i, 0, 3, h); g.fillRect(0, i, w, 3); }
  }, 1, 1));
  const carpet = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#1a2233'; g.fillRect(0, 0, w, h); speckle(g, w, h, 3000, ['#1d2639', '#161d2b', '#202a3f'], 1.4);
    g.strokeStyle = 'rgba(120,170,255,0.18)'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, h / 2); g.lineTo(w, h / 2); g.stroke();
  }, 1, 1));
  const ceilTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#22262e'; g.fillRect(0, 0, w, h);
    g.strokeStyle = '#15181d'; g.lineWidth = 4; for (let k = 0; k <= 2; k++) { g.beginPath(); g.moveTo(k * w / 2, 0); g.lineTo(k * w / 2, h); g.stroke(); g.beginPath(); g.moveTo(0, k * h / 2); g.lineTo(w, k * h / 2); g.stroke(); }
    speckle(g, w, h, 800, ['rgba(255,255,255,0.04)', 'rgba(0,0,0,0.2)'], 1.5);
  }, 1, 1));
  const space = (planetX) => keep(canvasTex(1024, 256, (g, w, h) => {
    g.fillStyle = '#02040a'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 700; i++) { g.fillStyle = 'rgba(220,230,255,' + rand(0.25, 1) + ')'; g.fillRect(rand(0, w), rand(0, h), rand(1, 2.4), rand(1, 2.4)); }
    const gr = g.createRadialGradient(w * planetX, h * 1.25, 20, w * planetX, h * 1.25, h * 1.15); gr.addColorStop(0, '#9fd0ff'); gr.addColorStop(0.55, '#3a6aa8'); gr.addColorStop(0.9, '#0e1c38'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.strokeStyle = 'rgba(30,36,48,1)'; g.lineWidth = 10; for (let x = 0; x <= w; x += w / 5) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); } // the frame between the panes
  }));
  /* 5.14, after your drawing: a worn dark plate in a thick frame, the name in heavy old-style letters, and a big block arrow at the end it
     points to (left or right at the corridor junction; up, 'straight on', on the signs hung before the doors). bridge orange, hall green */
  const sign = (text, dir, col) => keep(canvasTex(1024, 320, (g, w, h) => {
    g.fillStyle = '#0e1219'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 1400; i++) { g.fillStyle = 'rgba(255,255,255,' + (Math.random() * 0.035).toFixed(3) + ')'; g.fillRect(Math.random() * w, Math.random() * h, 1 + Math.random() * 3, 1 + Math.random() * 3); }
    g.strokeStyle = col; g.lineWidth = 16; g.strokeRect(16, 16, w - 32, h - 32);
    const aw = 280, left = dir === 'left', ax = left ? 48 : w - 48 - aw, cy = h / 2;
    g.fillStyle = col; g.beginPath();
    if (dir === 'up') { // a tall arrow: head on top, shaft below
      const cx = ax + aw / 2, top = 46, bot = h - 46, hw = 118, sw = 46, neck = top + 120;
      g.moveTo(cx, top); g.lineTo(cx + hw, neck); g.lineTo(cx + sw, neck); g.lineTo(cx + sw, bot); g.lineTo(cx - sw, bot); g.lineTo(cx - sw, neck); g.lineTo(cx - hw, neck);
    } else { // a long arrow: shaft, then a broad head; mirrored for the left
      const s = left ? -1 : 1, x0 = left ? ax + aw : ax, tip = x0 + s * aw, neck = x0 + s * aw * 0.5, hh = 112, sh = 44;
      g.moveTo(x0, cy - sh); g.lineTo(neck, cy - sh); g.lineTo(neck, cy - hh); g.lineTo(tip, cy); g.lineTo(neck, cy + hh); g.lineTo(neck, cy + sh); g.lineTo(x0, cy + sh);
    }
    g.closePath(); g.fill();
    g.font = '900 176px "YardSign", "Black Han Sans", serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    const tx = left ? (ax + aw + w - 48) / 2 + 10 : (48 + ax) / 2 - 10;
    g.lineJoin = 'round'; g.lineWidth = 10; g.strokeStyle = '#0e1219'; g.strokeText(text, tx, cy + 10); g.fillText(text, tx, cy + 10);
  }));
  const BRIDGE_C = '#f2a33a', HALL_C = '#5ed6b0';
  const wallMat = new THREE.MeshStandardMaterial({ map: panel, roughness: 0.8, metalness: 0.2 });
  const ceilMat = new THREE.MeshStandardMaterial({ map: ceilTex, roughness: 0.8, metalness: 0.2 });
  const floorMat = { corr: new THREE.MeshStandardMaterial({ map: plate, roughness: 0.55, metalness: 0.45 }), hall: new THREE.MeshStandardMaterial({ map: hallTex, roughness: 0.5, metalness: 0.5 }),
    pass: new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 }), lock: new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 }),
    bridge: new THREE.MeshStandardMaterial({ map: carpet, roughness: 0.9, metalness: 0.05 }) };
  const kitMat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.5, metalness: 0.45 });
  const glowMat = new THREE.MeshBasicMaterial({ vertexColors: true });
  const solid = [], glow = [], pipes = [];
  const box = (x0, y0, z0, x1, y1, z1, col, kind) => { addCollider(x0, y0, z0, x1, y1, z1, kind || 'metal'); solid.push(B(x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, col)); };

  /* ---- 1. the floor plan into a half-metre grid: every cell knows the ceiling over it (0 = outside the ship) ---- */
  const CS = 0.5, GX = -126, GZ = -50, NX = 580, NZ = 192, hAt = new Float32Array(NX * NZ); // x -126..164, z -50..46
  for (const Rm of SHIP_ROOMS) {
    const i0 = Math.round((Rm[0] - GX) / CS), i1 = Math.round((Rm[2] - GX) / CS), j0 = Math.round((Rm[1] - GZ) / CS), j1 = Math.round((Rm[3] - GZ) / CS);
    for (let i = i0; i < i1; i++) for (let j = j0; j < j1; j++) hAt[j * NX + i] = Math.max(hAt[j * NX + i], Rm[4]);
  }
  const H = (i, j) => (i < 0 || j < 0 || i >= NX || j >= NZ ? 0 : hAt[j * NX + i]);
  /* ---- 2. walls wherever a cell meets the outside, and lintels above an opening into a lower room ---- */
  const T = 0.6, walls = [];
  const run2 = (n, m, get, emit) => {
    for (let a = 0; a < n; a++) {
      let cur = null;
      const flush = () => { if (cur) { emit(a, cur); cur = null; } };
      for (let b = 0; b < m; b++) {
        const [h, hn] = get(a, b);
        if (h > 0 && hn < h) { const y0 = hn > 0 ? hn : 0; if (cur && cur.y0 === y0 && cur.y1 === h && cur.b1 === b) cur.b1 = b + 1; else { flush(); cur = { b0: b, b1: b + 1, y0, y1: h }; } }
        else flush();
      }
      flush();
    }
  };
  for (const d of [-1, 1]) {
    run2(NZ, NX, (j, i) => [H(i, j), H(i, j + d)], (j, c) => { const zb = GZ + (d < 0 ? j : j + 1) * CS; walls.push([GX + c.b0 * CS, c.y0, d < 0 ? zb - T : zb, GX + c.b1 * CS, c.y1 + 0.4, d < 0 ? zb : zb + T]); });
    run2(NX, NZ, (i, j) => [H(i, j), H(i + d, j)], (i, c) => { const xb = GX + (d < 0 ? i : i + 1) * CS; walls.push([d < 0 ? xb - T : xb, c.y0, GZ + c.b0 * CS, d < 0 ? xb : xb + T, c.y1 + 0.4, GZ + c.b1 * CS]); });
  }
  const wallGeos = [];
  for (const [x0, y0, z0, x1, y1, z1] of walls) { addCollider(x0, y0, z0, x1, y1, z1, 'metal'); wallGeos.push(uvBox(x0, y0, z0, x1, y1, z1, 3)); }
  const wallMesh = new THREE.Mesh(mergeGeos(wallGeos), wallMat); wallMesh.receiveShadow = true; G.add(wallMesh);
  /* ---- 3. ceilings and floors ---- */
  const ceilGeos = [];
  for (const [x0, z0, x1, z1, h, kind] of SHIP_ROOMS) {
    if (kind === 'hall') continue; // the hall has a pyramid roof and a floor with a pit in it (section 7)
    addCollider(x0, h, z0, x1, h + 0.4, z1, 'metal'); ceilGeos.push(uvBox(x0, h, z0, x1, h + 0.4, z1, 4));
    const fg = new THREE.PlaneGeometry(x1 - x0, z1 - z0), uv = fg.attributes.uv, s = kind === 'pass' || kind === 'lock' ? 1.5 : kind === 'bridge' ? 3 : 6;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * (x1 - x0) / s, uv.getY(i) * (z1 - z0) / s);
    const f = new THREE.Mesh(fg, floorMat[kind]); f.rotation.x = -Math.PI / 2; f.position.set((x0 + x1) / 2, 0.002, (z0 + z1) / 2); f.receiveShadow = true; G.add(f);
  }
  G.add(new THREE.Mesh(mergeGeos(ceilGeos), ceilMat));

  /* ---- 4. the passage from the airlock: pipes overhead, red warning lamps, hazard stripes at the turns ---- */
  const pipeZ = (x, y, z0, z1, rr) => { const g = new THREE.CylinderGeometry(rr, rr, z1 - z0, 8); g.rotateX(Math.PI / 2); g.translate(x, y, (z0 + z1) / 2); pipes.push(g); };
  const pipeX = (z, y, x0, x1, rr) => { const g = new THREE.CylinderGeometry(rr, rr, x1 - x0, 8); g.rotateZ(Math.PI / 2); g.translate((x0 + x1) / 2, y, z); pipes.push(g); };
  pipeZ(-43.7, 3.9, 13, 25, 0.12); pipeZ(-39.8, 3.7, 13, 25, 0.09); pipeX(7.3, 3.9, -44, -22, 0.12); pipeX(12.7, 3.7, -44, -22, 0.09); pipeZ(-26.2, 3.9, -2.5, 7, 0.12); pipeZ(-22.3, 3.7, -2.5, 7, 0.09);
  for (const [x, z] of [[-41.75, 16], [-41.75, 20], [-38, 10], [-30, 10], [-24.25, 4], [-24.25, 0]]) glow.push(B(1.2, 0.05, 0.4, x, 4.46, z, '#cfe6ff'));
  for (const [x, z] of [[-43.95, 18], [-39.55, 14], [-33, 7.05], [-27, 12.95], [-26.45, 2]]) {
    const b = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 0.25), new THREE.MeshBasicMaterial({ color: 0xff2a2a })); b.position.set(x, 3.4, z); G.add(b); World.blink.push(b);
  }
  for (const [x0, z0, x1, z1] of [[-44, 7, -39.5, 13], [-26.5, 7, -22, 13], [-26.5, -2.5, -22, -1.6]]) {
    const n = Math.round((x1 - x0) / 0.5);
    for (let i = 0; i < n; i += 2) glow.push(B(0.5, 0.01, 0.12, x0 + 0.25 + i * 0.5, 0.012, z0 + 0.1, '#e8b040'), B(0.5, 0.01, 0.12, x0 + 0.25 + i * 0.5, 0.012, z1 - 0.1, '#e8b040'));
  }
  // the airlock: a heavy sliding door with a striped frame; you came in through it and it shuts behind you
  addCollider(-44, 0, SHIP_DOOR_Z - 0.2, -39.5, 4.5, SHIP_DOOR_Z + 0.2, 'metal');
  const doorTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#4a5162'; g.fillRect(0, 0, w, h); g.fillStyle = '#3a4050'; g.fillRect(16, 16, w - 32, h - 32);
    for (let i = -h; i < w; i += 40) { g.fillStyle = '#e8b040'; g.beginPath(); g.moveTo(i, h); g.lineTo(i + 20, h); g.lineTo(i + 20 + 30, h - 30); g.lineTo(i + 30, h - 30); g.fill(); }
    g.fillStyle = '#ff3a2a'; g.font = '40px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.fillText('에어록', w / 2, h * 0.42); g.font = '600 18px "IBM Plex Mono", monospace'; g.fillStyle = '#cfd6e2'; g.fillText('AIRLOCK B-07', w / 2, h * 0.58);
  }));
  const door = new THREE.Mesh(new THREE.BoxGeometry(4.5, 4.5, 0.3), new THREE.MeshStandardMaterial({ map: doorTex, roughness: 0.5, metalness: 0.5 })); door.position.set(-41.75, 2.25, SHIP_DOOR_Z); G.add(door); Ship.door = door;
  solid.push(B(0.35, 4.5, 0.5, -44 + 0.17, 2.25, SHIP_DOOR_Z, '#2a2f3a'), B(0.35, 4.5, 0.5, -39.5 - 0.17, 2.25, SHIP_DOOR_Z, '#2a2f3a'));
  // inside the airlock: the outer hatch, a round window full of stars
  const hatch = new THREE.Mesh(new THREE.CircleGeometry(1.3, 32), new THREE.MeshBasicMaterial({ map: space(0.3) })); hatch.position.set(-41.75, 2.2, 29.45); hatch.rotation.y = Math.PI; G.add(hatch);
  solid.push(B(3.2, 3.2, 0.2, -41.75, 2.2, 29.5, '#2a2f3a'));
  World.lamps.push({ x: -41.75, y: 3.6, z: 27.5, d: 0 });

  /* ---- 5. the corridor (160 m): pipes, a light strip on each wall, panels in the ceiling, low barricades to hide behind ---- */
  pipeX(-12.2, 5.2, -92, 68, 0.16); pipeX(-12.25, 4.7, -92, 68, 0.1); pipeX(-2.8, 5.2, -92, -26.5, 0.16); pipeX(-2.8, 5.2, -22, 68, 0.16);
  for (const z of [-12.46, -2.54]) glow.push(B(160, 0.06, 0.04, -12, 2.4, z, '#3a9cff'));
  for (let x = -88; x <= 64; x += 6) glow.push(B(3.2, 0.06, 1.2, x, 5.97, -7.5, '#dfeeff'));
  for (let i = 0, x = -84; x <= 60; x += 12, i++) { const z = i % 2 ? -4.2 : -10.8, w = 3, d = 0.7;
    if (Math.abs(x + 24.25) < 4) continue; // keep the mouth of the passage clear
    box(x - w / 2, 0, z - d / 2, x + w / 2, 1.15, z + d / 2, '#454d60'); solid.push(B(w + 0.04, 0.08, d + 0.04, x, 1.16, z, '#e8b040')); }
  // sealed side doors along the corridor walls
  for (const x of [-80, -55, -40, -15, 8, 33, 52]) { solid.push(B(2.4, 3.2, 0.12, x, 1.6, -12.44, '#2c313c'), B(2.4, 3.2, 0.12, x + 6, 1.6, -2.56, '#2c313c')); glow.push(B(0.3, 0.12, 0.05, x + 1.5, 1.7, -12.36, '#ff3a2a'), B(0.3, 0.12, 0.05, x + 4.5, 1.7, -2.64, '#ff3a2a')); }
  // signs: the bridge to the west, the main hall to the east
  const signMesh = (tex, x, y, z, ry, w) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * 0.3125), new THREE.MeshBasicMaterial({ map: tex })); m.position.set(x, y, z); m.rotation.y = ry; G.add(m); };
  signMesh(sign('운전실', 'left', BRIDGE_C), -24.9, 3.3, -12.43, 0, 4.3);
  signMesh(sign('메인홀', 'right', HALL_C), -18.1, 3.3, -12.43, 0, 4.3);
  for (let x = -86; x <= 64; x += 12) World.lamps.push({ x, y: 5.2, z: -7.5, d: 0 });
  World.lamps.push({ x: -41.75, y: 3.9, z: 18, d: 0 }, { x: -33, y: 3.9, z: 10, d: 0 }, { x: -24.25, y: 3.9, z: 2.5, d: 0 });

  /* ---- 5b. the sliding doors onto the bridge and the hall: two leaves that part into the wall ---- */
  const dTex = keep(canvasTex(256, 256, (g, w, h) => {
    g.fillStyle = '#434a5a'; g.fillRect(0, 0, w, h); g.fillStyle = '#373d4b'; g.fillRect(12, 12, w - 24, h - 24);
    for (let i = -h; i < w; i += 36) { g.fillStyle = 'rgba(232,176,64,0.85)'; g.beginPath(); g.moveTo(i, h); g.lineTo(i + 16, h); g.lineTo(i + 16 + 26, h - 26); g.lineTo(i + 26, h - 26); g.fill(); }
    g.fillStyle = 'rgba(80,190,255,0.8)'; g.fillRect(w - 18, h * 0.3, 6, h * 0.4);
  }));
  const dMat = new THREE.MeshStandardMaterial({ map: dTex, roughness: 0.5, metalness: 0.55 });
  for (const D of SHIP_DOORS) {
    const w = (D.z1 - D.z0) / 2, leaf = () => { const m = new THREE.Mesh(new THREE.BoxGeometry(0.3, D.h, w), dMat); m.position.set(D.x, D.h / 2, 0); m.castShadow = true; G.add(m); return m; };
    const d = Object.assign({}, D, { open: 0, mode: 'shut', a: leaf(), b: leaf(), col: addCollider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, 'metal') });
    d.col.door = true; d.a.position.z = D.z0 + w / 2; d.b.position.z = D.z1 - w / 2; Ship.doors.push(d);
    // a sign hung from the ceiling a few metres before the door, facing you as you come down the corridor: the name and 'straight on'
    const out = -D.inward, hx = D.x + out * 4.5, col = D.room === 'bridge' ? BRIDGE_C : HALL_C;
    signMesh(sign(D.name, 'up', col), hx, 4.5, -7.5, out > 0 ? Math.PI / 2 : -Math.PI / 2, 4.4);
    solid.push(B(0.04, 0.95, 0.04, hx, 5.52, -9.2, '#2a2f3a'), B(0.04, 0.95, 0.04, hx, 5.52, -5.8, '#2a2f3a'));
    glow.push(B(0.06, 0.1, D.z1 - D.z0 + 0.4, D.x + (D.x < 0 ? 0.32 : -0.32), D.h + 0.15, -7.5, '#e8b040'));
  }

  /* ---- 6. the bridge (운전실): 31 x 41 m and 16 m high. a two-storey wall of windows onto space, rows of consoles facing it,
     the commander's platform behind them, and an open gallery at 7 m round the other three sides, a wide stair up the north and south walls ---- */
  const BR = BRIDGE, GY = BR.gy;
  const win = new THREE.Mesh(new THREE.PlaneGeometry(27, 11), new THREE.MeshBasicMaterial({ map: space(0.62) })); win.position.set(BR.x0 + 0.03, 8, -7.5); win.rotation.y = Math.PI / 2; G.add(win);
  solid.push(B(0.2, 0.3, 27.4, BR.x0 + 0.1, 2.4, -7.5, '#2a2f3a'), B(0.2, 0.3, 27.4, BR.x0 + 0.1, 13.6, -7.5, '#2a2f3a'), B(0.2, 11.4, 0.3, BR.x0 + 0.1, 8, -7.5, '#2a2f3a'));
  // the gallery floor, in three runs, with a blue light along its edge
  const gal = [[BR.stairX1, BR.z0, BR.x1, BR.z0 + 5], [BR.stairX1, BR.z1 - 5, BR.x1, BR.z1], [BR.eastX, BR.z0 + 5, BR.x1, BR.z1 - 5]];
  for (const [x0, z0, x1, z1] of gal) { box(x0, GY - 0.4, z0, x1, GY, z1, '#2f3542'); }
  glow.push(B(BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z0 + 5.02, '#4fb8ff'), B(BR.eastX - BR.stairX1, 0.05, 0.05, (BR.stairX1 + BR.eastX) / 2, GY - 0.2, BR.z1 - 5.02, '#4fb8ff'),
    B(0.05, 0.05, BR.z1 - BR.z0 - 10, BR.eastX - 0.02, GY - 0.2, (BR.z0 + BR.z1) / 2, '#4fb8ff'));
  // railings on its open edges (bullets and eyes go through them)
  const rails = [], railC = (x0, z0, x1, z1) => { const b = addCollider(x0, GY, z0, x1, GY + 1.1, z1, 'metal'); b.grate = true; };
  const railRun = (x0, z0, x1, z1) => { railC(x0, z0, x1, z1);
    const L = Math.max(x1 - x0, z1 - z0), along = x1 - x0 > z1 - z0, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    rails.push(along ? [L, 0.07, 0.07, cx, GY + 1.05, cz] : [0.07, 0.07, L, cx, GY + 1.05, cz], along ? [L, 0.05, 0.05, cx, GY + 0.55, cz] : [0.05, 0.05, L, cx, GY + 0.55, cz]);
    for (let t = 0; t <= L; t += 2.5) rails.push([0.08, 1.1, 0.08, along ? x0 + t : cx, GY + 0.55, along ? cz : z0 + t]); };
  railRun(BR.stairX1, BR.z0 + 4.95, BR.eastX, BR.z0 + 5.05); railRun(BR.stairX1, BR.z1 - 5.05, BR.eastX, BR.z1 - 4.95); railRun(BR.eastX - 0.05, BR.z0 + 5, BR.eastX + 0.05, BR.z1 - 5);
  // the stairs: sixteen steps of 0.44 m (people and robots both climb them), solid down to the floor
  const stepRun = (BR.stairX1 - BR.stairX0) / BR.steps, stairs = [];
  for (const [z0, z1] of [[BR.z0, BR.z0 + 5], [BR.z1 - 5, BR.z1]]) for (let k = 1; k <= BR.steps; k++) {
    const x0 = BR.stairX0 + (k - 1) * stepRun, h = (k / BR.steps) * GY; addCollider(x0, 0, z0, x0 + stepRun, h, z1, 'metal'); stairs.push([stepRun, h, z1 - z0, x0 + stepRun / 2, h / 2, (z0 + z1) / 2]);
    glow.push(B(stepRun * 0.9, 0.02, 0.06, x0 + stepRun / 2, h + 0.011, z0 === BR.z0 ? z1 - 0.1 : z0 + 0.1, '#e8b040'));
  }
  const stairMesh = new THREE.Mesh(mergeBoxes(stairs), new THREE.MeshStandardMaterial({ map: grate, roughness: 0.5, metalness: 0.6 })); stairMesh.castShadow = stairMesh.receiveShadow = true; G.add(stairMesh);
  pipes.push(...rails.map((p) => { const g = new THREE.BoxGeometry(p[0], p[1], p[2]); g.translate(p[3], p[4], p[5]); return g; }));
  // ground floor: two rows of consoles facing the windows, the commander's platform behind them, and screens on the walls under the gallery
  const screens = [];
  for (const x of [-118.5, -113.5]) for (const z of [-19, -13.5, -1.5, 4]) {
    box(x - 0.5, 0, z - 1.3, x + 0.5, 1.05, z + 1.3, '#2c3240');
    screens.push(B(0.06, 0.55, 2.2, x - 0.3, 1.45, z, '#3fd0ff', [0, 0, 0.35]));
    glow.push(B(0.05, 0.03, 2.4, x + 0.48, 1.06, z, '#3a9cff'));
  }
  box(-108, 0, -11, -102, 0.45, -4, '#2a2f3a'); glow.push(B(6.04, 0.04, 0.04, -105, 0.46, -11, '#e8b040'), B(6.04, 0.04, 0.04, -105, 0.46, -4, '#e8b040'));
  box(-105.5, 0.45, -8.1, -104.5, 1.6, -6.9, '#3b4252'); solid.push(B(1.1, 0.12, 1.1, -105, 0.95, -7.5, '#5a6378'));
  // the main hall's key, stuck upright in the commander's console: a gold bow and collar over a short shaft, glowing so you can find it
  {
    const km = new THREE.MeshStandardMaterial({ color: 0xffc83a, metalness: 0.85, roughness: 0.25, emissive: 0x7a4c00, emissiveIntensity: 0.9 });
    const kg = new THREE.Group(); kg.position.set(SHIP_KEY.x, SHIP_KEY.y, SHIP_KEY.z);
    const part = (geo, y, x) => { const m = new THREE.Mesh(geo, km); m.position.set(x || 0, y, 0); m.castShadow = true; kg.add(m); return m; };
    part(new THREE.TorusGeometry(0.17, 0.05, 10, 24), 0.5); part(new THREE.BoxGeometry(0.16, 0.05, 0.09), 0.3); part(new THREE.BoxGeometry(0.065, 0.3, 0.065), 0.15);
    part(new THREE.BoxGeometry(0.08, 0.05, 0.05), 0.08, 0.06);
    const gl = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex('rgba(255,220,120,0.95)', 'rgba(255,170,40,0.2)'), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.7 }));
    gl.scale.setScalar(1.4); gl.position.y = 0.38; kg.add(gl);
    G.add(kg); Ship.keyObj = kg; Ship.keyGlow = gl;
  }
  for (const z of [BR.z0 + 0.4, BR.z1 - 0.4]) for (const x of [-104, -99]) { box(x - 1.4, 0, z - 0.3, x + 1.4, 1.1, z + 0.3, '#2c3240'); screens.push(B(2.4, 0.9, 0.05, x, 2.1, z + (z < 0 ? 0.3 : -0.3), '#3fd0ff')); }
  // up on the gallery: consoles against the walls, and a big status board high on the east wall
  for (const x of [-104, -98]) for (const z of [BR.z0 + 0.4, BR.z1 - 0.4]) { box(x - 1.4, GY, z - 0.3, x + 1.4, GY + 1.1, z + 0.3, '#2c3240'); screens.push(B(2.4, 0.9, 0.05, x, GY + 2.1, z + (z < 0 ? 0.3 : -0.3), '#3fd0ff')); }
  for (const z of [-19, -11, -4, 4]) { box(BR.x1 - 0.7, GY, z - 1.4, BR.x1 - 0.1, GY + 1.1, z + 1.4, '#2c3240'); screens.push(B(0.05, 0.9, 2.4, BR.x1 - 0.4, GY + 2.1, z, '#3fd0ff')); }
  screens.push(B(0.06, 2.6, 9, BR.x1 - 0.05, 12, -7.5, '#3fd0ff'));
  const scr = new THREE.Mesh(M(screens), new THREE.MeshBasicMaterial({ vertexColors: true })); G.add(scr); Ship.screens = scr;
  for (let x = -120; x <= -95; x += 6) for (const z of [-22, -14, -7.5, -1, 7]) glow.push(B(2.4, 0.05, 1.0, x, 15.97, z, '#dfeeff'));
  for (const [x0, z0, x1, z1] of gal) for (let x = x0 + 2; x < x1 - 1; x += 5) glow.push(B(1.6, 0.04, 0.6, x, GY - 0.42, (z0 + z1) / 2, '#cfe6ff'));
  World.lamps.push({ x: -115, y: 13, z: -16, d: 0 }, { x: -115, y: 13, z: 1, d: 0 }, { x: -104, y: 13, z: -7.5, d: 0 }, { x: -100, y: 5.6, z: -25.5, d: 0 }, { x: -100, y: 5.6, z: 10.5, d: 0 },
    { x: -100, y: GY + 3.5, z: -25.5, d: 0 }, { x: -100, y: GY + 3.5, z: 10.5, d: 0 }, { x: -94.5, y: GY + 3.5, z: -7.5, d: 0 });

  /* ---- 7. the main hall (메인홀), 5.16: 94 x 93 m. an upside-down stepped pyramid sunk in the middle of the floor with a line of light on
     every step, eight tall pillars on its landings, the reactor's light column from the bottom of the pit to the top of a pyramid roof,
     windows onto space on three sides, and cargo round the walkway to hide behind ---- */
  {
    const HR = SHIP_ROOMS[2], P = PYR, cx = P.cx, cz = P.cz, BOT = P.bottom, W = P.wall, A = P.apex, x0 = HR[0], x1 = HR[2], z0 = HR[1], z1 = HR[3];
    PIT = { x0: cx - P.ox, x1: cx + P.ox, z0: cz - P.oz, z1: cz + P.oz, y: BOT };
    const stepTex = keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#262b34'; g.fillRect(0, 0, w, h); speckle(g, w, h, 2600, ['#2a3039', '#21252d', '#2e343f'], 1.4);
      g.strokeStyle = 'rgba(8,10,14,0.9)'; g.lineWidth = 3; for (let k = 0; k <= 4; k++) { g.beginPath(); g.moveTo(k * w / 4, 0); g.lineTo(k * w / 4, h); g.stroke(); }
      g.fillStyle = 'rgba(150,175,210,0.10)'; for (let y = 6; y < h; y += 14) g.fillRect(0, y, w, 2); // ribs against slipping
    }, 1, 1));
    const roofTex = keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#343c4c'; g.fillRect(0, 0, w, h); speckle(g, w, h, 900, ['rgba(255,255,255,0.05)', 'rgba(0,0,0,0.25)'], 1.6);
      g.fillStyle = '#2b3240'; g.fillRect(8, 8, w / 2 - 16, h / 2 - 16); g.fillRect(w / 2 + 8, h / 2 + 8, w / 2 - 16, h / 2 - 16);
      g.strokeStyle = '#11141a'; g.lineWidth = 5; g.strokeRect(0, 0, w, h); g.lineWidth = 2; g.beginPath(); g.moveTo(w / 2, 0); g.lineTo(w / 2, h); g.moveTo(0, h / 2); g.lineTo(w, h / 2); g.stroke();
      g.fillStyle = 'rgba(120,180,255,0.16)'; for (const [x, y] of [[12, 12], [w - 12, 12], [12, h - 12], [w - 12, h - 12]]) { g.beginPath(); g.arc(x, y, 3, 0, TAU); g.fill(); }
    }, 1, 1));
    // the walkway round the pit, in four strips (texture laid in world metres so the strips meet), and the floor at the bottom
    const strip = (xa, za, xb, zb, y, s) => { const fg = new THREE.PlaneGeometry(xb - xa, zb - za), uv = fg.attributes.uv;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, (xa + uv.getX(i) * (xb - xa)) / s, (zb - uv.getY(i) * (zb - za)) / s);
      const f = new THREE.Mesh(fg, floorMat.hall); f.rotation.x = -Math.PI / 2; f.position.set((xa + xb) / 2, y, (za + zb) / 2); f.receiveShadow = true; G.add(f); };
    strip(x0, z0, x1, cz - P.oz, 0.002, 6); strip(x0, cz + P.oz, x1, z1, 0.002, 6); strip(x0, cz - P.oz, cx - P.ox, cz + P.oz, 0.002, 6); strip(cx + P.ox, cz - P.oz, x1, cz + P.oz, 0.002, 6);
    strip(cx - P.bx, cz - P.bz, cx + P.bx, cz + P.bz, BOT + 0.002, 6);
    /* the steps: each a ring of four boxes from the bottom of the pit up to its tread (the walls of the pit too); people and robots both
       climb them (37.5 cm). flagged 'step' so the robots' way-finding walks over them */
    const stepGeos = [], landGeos = [];
    const band = (xa, za, xb, zb, top, list) => { const c = addCollider(xa, BOT, za, xb, top, zb, 'metal'); c.step = true; list.push(uvBox(xa, BOT, za, xb, top, zb, list === landGeos ? 6 : 2)); };
    const T2 = 0.3; // the pit's own wall, just outside the rim, from the bottom up to the walkway
    band(cx - P.ox - T2, cz - P.oz - T2, cx + P.ox + T2, cz - P.oz, 0, stepGeos); band(cx - P.ox - T2, cz + P.oz, cx + P.ox + T2, cz + P.oz + T2, 0, stepGeos);
    band(cx - P.ox - T2, cz - P.oz, cx - P.ox, cz + P.oz, 0, stepGeos); band(cx + P.ox, cz - P.oz, cx + P.ox + T2, cz + P.oz, 0, stepGeos);
    for (const st of P.steps) {
      const ix = st.ax - st.w, iz = st.az - st.w, list = st.land ? landGeos : stepGeos;
      band(cx - st.ax, cz - st.az, cx + st.ax, cz - iz, st.y, list); band(cx - st.ax, cz + iz, cx + st.ax, cz + st.az, st.y, list);
      band(cx - st.ax, cz - iz, cx - ix, cz + iz, st.y, list); band(cx + ix, cz - iz, cx + st.ax, cz + iz, st.y, list);
      // a line of light round the nose of every step, over the edge so it shows from above and from below; brighter at the edge of a
      // landing and round the floor at the bottom
      const col = st.land || st.k === P.steps.length ? '#6fd2ff' : '#3a8ee6', y = st.y - 0.035, e = 0.01, t = 0.09, hh = 0.1;
      glow.push(B(2 * ix + 2 * t, hh, t, cx, y, cz - iz - e, col), B(2 * ix + 2 * t, hh, t, cx, y, cz + iz + e, col),
        B(t, hh, 2 * iz + 2 * t, cx - ix - e, y, cz, col), B(t, hh, 2 * iz + 2 * t, cx + ix + e, y, cz, col));
    }
    const stepMesh = new THREE.Mesh(mergeGeos(stepGeos), new THREE.MeshStandardMaterial({ map: stepTex, roughness: 0.55, metalness: 0.5 })); stepMesh.castShadow = stepMesh.receiveShadow = true; G.add(stepMesh);
    const landMesh = new THREE.Mesh(mergeGeos(landGeos), floorMat.hall); landMesh.castShadow = landMesh.receiveShadow = true; G.add(landMesh);
    // round the rim: a hazard line on the walkway
    const rw = 0.16;
    glow.push(B(2 * P.ox + 2 * rw, 0.02, rw, cx, 0.012, cz - P.oz - rw / 2, '#e8b040'), B(2 * P.ox + 2 * rw, 0.02, rw, cx, 0.012, cz + P.oz + rw / 2, '#e8b040'),
      B(rw, 0.02, 2 * P.oz, cx - P.ox - rw / 2, 0.012, cz, '#e8b040'), B(rw, 0.02, 2 * P.oz, cx + P.ox + rw / 2, 0.012, cz, '#e8b040'));
    // the reactor: a low square dais at the bottom, a column of light from it to the top of the roof, rods and rings round it
    const RD = REACTOR.dais; box(cx - RD, BOT, cz - RD, cx + RD, REACTOR.base, cz + RD, '#3d4454');
    for (const [a1, b1, c1, d1] of [[-RD, -RD, RD, -RD], [-RD, RD, RD, RD], [-RD, -RD, -RD, RD], [RD, -RD, RD, RD]]) glow.push(B(Math.max(0.05, Math.abs(c1 - a1)), 0.03, Math.max(0.05, Math.abs(d1 - b1)), cx + (a1 + c1) / 2, REACTOR.base + 0.01, cz + (b1 + d1) / 2, '#5ec8ff'));
    const coreTop = A - 1.6, coreH = coreTop - REACTOR.base;
    addCollider(REACTOR.x - REACTOR.r, REACTOR.base, REACTOR.z - REACTOR.r, REACTOR.x + REACTOR.r, A, REACTOR.z + REACTOR.r, 'metal');
    const coreMat = new THREE.MeshBasicMaterial({ color: 0x8fd8ff }); Ship.coreMat = coreMat;
    const core = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, coreH, 24), coreMat); core.position.set(cx, REACTOR.base + coreH / 2, cz); G.add(core);
    for (let i = 0; i < 8; i++) { const a = (i / 8) * TAU; solid.push(B(0.22, coreH, 0.22, cx + Math.cos(a) * 1.55, REACTOR.base + coreH / 2, cz + Math.sin(a) * 1.55, '#3a4150')); }
    for (let y = REACTOR.base + 2.5; y < coreTop - 1; y += 4.5) { const g = new THREE.TorusGeometry(1.62, 0.12, 6, 28); g.rotateX(Math.PI / 2); g.translate(cx, y, cz); pipes.push(g); }
    box(cx - 2.1, REACTOR.base, cz - 2.1, cx + 2.1, REACTOR.base + 0.9, cz + 2.1, '#353b48'); solid.push(B(3.6, 1.6, 3.6, cx, coreTop + 0.8, cz, '#353b48')); // the housings at its foot and its head
    for (const [a1, b1, c1, d1] of [[-2.1, -2.1, 2.1, -2.1], [-2.1, 2.1, 2.1, 2.1], [-2.1, -2.1, -2.1, 2.1], [2.1, -2.1, 2.1, 2.1]]) glow.push(B(Math.max(0.08, Math.abs(c1 - a1) + 0.08), 0.08, Math.max(0.08, Math.abs(d1 - b1) + 0.08), cx + (a1 + c1) / 2, REACTOR.base + 0.9, cz + (b1 + d1) / 2, '#8fe0ff'));
    // two rings of light turning over it, the big one at the height of the roof's middle and a small one near the top; lamps on each so you see them turn
    const ringAt = (R0, y, n) => { const m = new THREE.Mesh(new THREE.TorusGeometry(R0, 0.2, 6, 64), new THREE.MeshBasicMaterial({ color: 0x4fb8ff })); m.rotation.x = Math.PI / 2; m.position.set(cx, y, cz);
      for (let i = 0; i < n; i++) { const a = (i / n) * TAU, l = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.7, 0.7), new THREE.MeshBasicMaterial({ color: 0xe8f6ff })); l.position.set(Math.cos(a) * R0, Math.sin(a) * R0, 0); m.add(l); }
      G.add(m); return m; };
    Ship.ring = ringAt(9, W + (A - W) * 0.45, 12); Ship.ring2 = ringAt(3.6, A - 5, 6);
    /* the pillars: square, dark, light up the corners, amber bands every 6 m, a plinth and a capital; the outer four meet the roof, the
       inner four end in a lamp */
    for (const [x, z, h, y0, y1, roof] of HALL_PILLARS) {
      box(x - h, y0, z - h, x + h, y1, z + h, '#2f3542'); box(x - h - 0.35, y0, z - h - 0.35, x + h + 0.35, y0 + 0.9, z + h + 0.35, '#3d4454');
      solid.push(B(2 * h + 0.6, 0.8, 2 * h + 0.6, x, roof ? y1 - 2.4 : y1 - 0.6, z, '#3d4454'));
      for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) glow.push(B(0.1, y1 - y0 - 3.2, 0.1, x + sx * (h + 0.02), (y0 + 0.9 + y1 - 2.3) / 2, z + sz * (h + 0.02), '#4fb8ff'));
      for (let y = y0 + 6; y < y1 - 3.5; y += 6) glow.push(B(2 * h + 0.08, 0.14, 2 * h + 0.08, x, y, z, '#e8b040'));
      if (!roof) { glow.push(B(2 * h - 0.2, 0.6, 2 * h - 0.2, x, y1 + 0.3, z, '#bfeaff')); solid.push(B(2 * h + 0.2, 0.15, 2 * h + 0.2, x, y1 + 0.68, z, '#3d4454')); }
    }
    /* the roof: four faces from the top of the walls to the point, panels in world metres, a light along each hip and in rings up it */
    {
      const C4 = [[x0, z0], [x1, z0], [x1, z1], [x0, z1]], pos = [], uvs = [];
      for (let i = 0; i < 4; i++) {
        const [ax, az] = C4[i], [bx, bz] = C4[(i + 1) % 4], L = Math.hypot(bx - ax, bz - az), ex = (bx - ax) / L, ez = (bz - az) / L;
        const along = (cx - ax) * ex + (cz - az) * ez, up = Math.hypot(Math.hypot(cx - (ax + ex * along), cz - (az + ez * along)), A - W);
        pos.push(ax, W, az, bx, W, bz, cx, A, cz); uvs.push(0, 0, L / 5, 0, along / 5, up / 5);
      }
      const rg = new THREE.BufferGeometry(); rg.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); rg.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2)); rg.computeVertexNormals();
      G.add(new THREE.Mesh(rg, new THREE.MeshStandardMaterial({ map: roofTex, roughness: 0.75, metalness: 0.3, side: THREE.DoubleSide })));
      // a light from foot to point: along each hip, and up each face from every pilaster, so the faces fan in to the top
      const rib = (ax, az, wd, col) => { const dx = cx - ax, dy = A - W, dz = cz - az, L = Math.hypot(dx, dy, dz);
        glow.push(B(wd, wd, L, (ax + cx) / 2, (W + A) / 2 - 0.35 - wd, (az + cz) / 2, col, [-Math.asin(dy / L), Math.atan2(dx, dz), 0])); };
      for (const [ax, az] of C4) rib(ax, az, 0.32, '#5ec8ff');
      for (let i = 1; i < 8; i++) { const fx = x0 + i * (x1 - x0) / 8, fz = z0 + i * (z1 - z0) / 8; rib(fx, z0, 0.18, '#2f86d8'); rib(fx, z1, 0.18, '#2f86d8'); rib(x0, fz, 0.18, '#2f86d8'); rib(x1, fz, 0.18, '#2f86d8'); }
      for (const t of [0.2, 0.4, 0.6, 0.8]) { const y = W + (A - W) * t - 0.3, ax = P.hx * (1 - t), az = P.hz * (1 - t), o = 0.25;
        glow.push(B(2 * ax, 0.1, 0.1, cx, y, cz - az + o, '#2f86d8'), B(2 * ax, 0.1, 0.1, cx, y, cz + az - o, '#2f86d8'), B(0.1, 0.1, 2 * az, cx - ax + o, y, cz, '#2f86d8'), B(0.1, 0.1, 2 * az, cx + ax - o, y, cz, '#2f86d8')); }
      // what stops bullets and jetpacks: rings of boxes stepping up under the faces (each at most a metre below the real roof)
      const n = 26;
      for (let i = 0; i < n; i++) {
        const t0 = i / n, t1 = (i + 1) / n, oxr = P.hx * (1 - t0), ozr = P.hz * (1 - t0), ixr = P.hx * (1 - t1), izr = P.hz * (1 - t1), ya = W + (A - W) * t0, yb = W + (A - W) * t1 + 0.3;
        for (const [xa, za, xb, zb] of [[-oxr, -ozr, oxr, -izr], [-oxr, izr, oxr, ozr], [-oxr, -izr, -ixr, izr], [ixr, -izr, oxr, izr]]) addCollider(cx + xa, ya, cz + za, cx + xb, yb, cz + zb, 'metal');
      }
    }
    /* the walls: pilasters every 11.75 m with a light down each, light lines low and high, and three windows onto space */
    for (let i = 1; i < 8; i++) { const x = x0 + i * (x1 - x0) / 8;
      for (const [z, s2] of [[z0, 1], [z1, -1]]) { box(x - 0.55, 0, z + (s2 > 0 ? 0 : -0.55), x + 0.55, W, z + (s2 > 0 ? 0.55 : 0), '#2a2f3a'); glow.push(B(0.08, W - 1, 0.04, x, W / 2, z + s2 * 0.57, '#3a9cff')); } }
    for (let i = 1; i < 8; i++) { const z = z0 + i * (z1 - z0) / 8;
      for (const [x, s2] of [[x0, 1], [x1, -1]]) { if (s2 > 0 && z > -15 && z < 0) continue; // clear of the door
        box(x + (s2 > 0 ? 0 : -0.55), 0, z - 0.55, x + (s2 > 0 ? 0.55 : 0), W, z + 0.55, '#2a2f3a'); glow.push(B(0.04, W - 1, 0.08, x + s2 * 0.57, W / 2, z, '#3a9cff')); } }
    for (const y of [2.4, W - 1.2]) {
      glow.push(B(x1 - x0, 0.1, 0.04, cx, y, z0 + 0.04, '#3a9cff'), B(x1 - x0, 0.1, 0.04, cx, y, z1 - 0.04, '#3a9cff'), B(0.04, 0.1, z1 - z0, x1 - 0.04, y, cz, '#3a9cff'));
      if (y > 7) glow.push(B(0.04, 0.1, z1 - z0, x0 + 0.04, y, cz, '#3a9cff')); else glow.push(B(0.04, 0.1, -12.5 - z0, x0 + 0.04, y, (z0 - 12.5) / 2, '#3a9cff'), B(0.04, 0.1, z1 + 2.5, x0 + 0.04, y, (z1 - 2.5) / 2, '#3a9cff'));
    }
    const view = (w, h, x, y, z, ry, planet) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: space(planet) })); m.position.set(x, y, z); m.rotation.y = ry; G.add(m); };
    view(46, 10, x1 - 0.03, 11, cz, -Math.PI / 2, 0.4); view(40, 7, cx, 10.5, z0 + 0.03, 0, 0.75); view(40, 7, cx, 10.5, z1 - 0.03, Math.PI, 0.2);
    solid.push(B(0.2, 0.4, 46.4, x1 - 0.1, 5.9, cz, '#2a2f3a'), B(0.2, 0.4, 46.4, x1 - 0.1, 16.1, cz, '#2a2f3a'));
    for (const z of [z0, z1]) solid.push(B(40.4, 0.4, 0.2, cx, 6.9, z + (z < 0 ? 0.1 : -0.1), '#2a2f3a'), B(40.4, 0.4, 0.2, cx, 14.1, z + (z < 0 ? 0.1 : -0.1), '#2a2f3a'));
    // cargo along the walkway, tall enough to hide behind from the boss's laser
    const pickC = () => ['#4b5568', '#5a4a3a', '#3e5a52', '#5a3e44', '#41495c'][Math.floor(R() * 5)];
    for (const [x, z, w, d] of [[86, -44.6, 5.2, 2.6], [101, -45.4, 5.2, 2.6], [129, -44.6, 5.2, 2.6], [144, -45.4, 5.2, 2.6], [86, 40.6, 5.2, 2.6], [101, 41.4, 5.2, 2.6],
      [129, 40.6, 5.2, 2.6], [144, 41.4, 5.2, 2.6], [157.6, -24, 2.6, 5.2], [157.6, 20, 2.6, 5.2], [72.4, -32, 2.6, 5.2], [72.4, 34, 2.6, 5.2]]) {
      const h = r(5.0, 5.8), c = pickC(); box(x - w / 2, 0, z - d / 2, x + w / 2, h, z + d / 2, c);
      solid.push(B(w + 0.06, 0.18, d + 0.06, x, h * 0.36, z, '#e8b040'), B(w + 0.06, 0.18, d + 0.06, x, h * 0.86, z, '#e8b040'), B(w + 0.04, 0.08, d + 0.04, x, h * 0.5, z, '#1c2028'));
    }
    // lamps: round the walkway, over each landing, at the bottom, and on top of the inner pillars
    const L1 = P.steps[P.per - 1], L2 = P.steps[2 * P.per - 1], L3 = P.steps[3 * P.per - 1], mid = (S2) => [S2.ax - S2.w / 2, S2.az - S2.w / 2];
    const [m1x, m1z] = mid(L1), [m2x, m2z] = mid(L2), [m3x, m3z] = mid(L3);
    [[80, 12, -44], [115, 12, -44], [150, 12, -44], [80, 12, 40], [115, 12, 40], [150, 12, 40], [158, 12, -2], [72, 12, 22],
      [cx, L1.y + 4, cz - m1z], [cx, L1.y + 4, cz + m1z], [cx - m1x, L1.y + 4, cz], [cx + m1x, L1.y + 4, cz],
      [cx - m2x * 0.7, L2.y + 4, cz - m2z * 0.7], [cx + m2x * 0.7, L2.y + 4, cz - m2z * 0.7], [cx - m2x * 0.7, L2.y + 4, cz + m2z * 0.7], [cx + m2x * 0.7, L2.y + 4, cz + m2z * 0.7],
      [cx, L3.y + 4, cz - m3z], [cx, L3.y + 4, cz + m3z], [cx - m3x, L3.y + 4, cz], [cx + m3x, L3.y + 4, cz], [cx - 7, BOT + 4, cz - 7], [cx + 7, BOT + 4, cz + 7]].forEach(([x, y, z]) => World.lamps.push({ x, y, z, d: 0 }));
    for (const [x, z, , , y1, roof] of HALL_PILLARS) if (!roof) World.lamps.push({ x, y: y1 + 1.4, z, d: 0 });
    // eight hatches, shut and dark until the boss's third phase (then two leaves slide apart over a red glow): four round the walkway, four at the bottom
    const hatchLid = new THREE.MeshStandardMaterial({ color: 0x2a2f38, roughness: 0.45, metalness: 0.7 });
    // a column of red light standing up out of each open hatch, bright at the floor and gone by head height
    const shaftTex = (() => { const c = document.createElement('canvas'); c.width = 4; c.height = 64; const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 64);
      gr.addColorStop(0, '#000'); gr.addColorStop(0.55, '#2a0800'); gr.addColorStop(1, '#ff5a22'); g.fillStyle = gr; g.fillRect(0, 0, 4, 64); return new THREE.CanvasTexture(c); })();
    const shaftMat = new THREE.MeshBasicMaterial({ map: shaftTex, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false });
    for (const [x, z, y] of HATCHES) {
      glow.push(B(2.7, 0.01, 0.14, x, y + 0.011, z - 1.28, '#e8b040'), B(2.7, 0.01, 0.14, x, y + 0.011, z + 1.28, '#e8b040'), B(0.14, 0.01, 2.7, x - 1.28, y + 0.011, z, '#e8b040'), B(0.14, 0.01, 2.7, x + 1.28, y + 0.011, z, '#e8b040'));
      const lidA = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.06, 2.4), hatchLid), lidB = lidA.clone(); lidA.position.set(x - 0.6, y + 0.035, z); lidB.position.set(x + 0.6, y + 0.035, z); G.add(lidA, lidB);
      const gl = new THREE.Mesh(new THREE.PlaneGeometry(2.3, 2.3), new THREE.MeshBasicMaterial({ color: 0xff4a1e, transparent: true, opacity: 0.9, toneMapped: false }));
      gl.rotation.x = -Math.PI / 2; gl.position.set(x, y + 0.012, z); gl.visible = false; G.add(gl);
      const sh = new THREE.Mesh(new THREE.CylinderGeometry(1.15, 1.25, 3.4, 16, 1, true), shaftMat); sh.position.set(x, y + 1.7, z); sh.visible = false; G.add(sh);
      Ship.hatches.push({ x, z, y, lidA, lidB, glow: gl, shaft: sh, open: false, k: 0 });
    }
  }

  /* ---- light and draw ---- */
  const pipeMesh = new THREE.Mesh(mergeGeos(pipes), new THREE.MeshStandardMaterial({ color: 0x59627a, roughness: 0.45, metalness: 0.6 })); G.add(pipeMesh);
  const solidMesh = new THREE.Mesh(M(solid), kitMat); solidMesh.castShadow = solidMesh.receiveShadow = true; G.add(solidMesh);
  G.add(new THREE.Mesh(M(glow), glowMat));

  /* walking grid: only inside the ship */
  World.navMask = (x, z) => !!shipRoom(x, z);
  /* supply crates along the corridor, in the bridge and round the hall */
  const fits = (x, z) => { const Rm = shipRoom(x, z); if (!Rm || Rm[5] === 'pass') return false;
    if (inPit(x, z, 1.4) || boxAt(x, z, 1.3, 0.05, 1.25)) return false; // in the hall: on the walkway only
    return x > Rm[0] + 1.2 && x < Rm[2] - 1.2 && z > Rm[1] + 1.2 && z < Rm[3] - 1.2; };
  const onGallery = (x, z) => x >= BRIDGE.stairX0 - 1 && x <= BRIDGE.x1 && (z <= BRIDGE.z0 + 6.2 || z >= BRIDGE.z1 - 6.2 || x >= BRIDGE.eastX - 1.2);
  placeCrates(G, S.crates, () => { const k = R(); return k < 0.45 ? [r(-90, 66), r(-11.8, -3.2)] : k < 0.65 ? [r(-122, -98), r(-22, 7)] : [r(69, 161), r(-47.5, 43.5)]; },
    (x, z) => fits(x, z) && !onGallery(x, z) && !HATCHES.some(([hx, hz]) => Math.hypot(hx - x, hz - z) < 2.6) && Math.abs(x - SHIP_DOORS[0].x) > 3 && Math.abs(x - SHIP_DOORS[1].x) > 3);
  World.menuCam = { x: REACTOR.x, z: REACTOR.z, r: 27, h: 7, look: -6 }; // round the pit, looking down into it

  indexColliders(); buildNav();
  return { start: { x: SHIP_START.x, z: SHIP_START.z, yaw: SHIP_START.yaw }, spawns: [], map: {} };
}
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
/* ============ stage 3-1: the watchtower in the middle of the safari ============ */
// a log tower on a solid plank skirt, so nothing gets underneath it. the skirt reaches out further than the platform above,
// so from the railing you can see (and shoot) whatever is at its foot. 10,000 to knock down; while you stand up there
// the animals go for the tower first (all but the giraffes, whose necks reach you over the railing).
// the steps are 0.48 m: you climb them, no animal can (they only step up 0.45 m).
const TOWER = { hp: 10000, ph: 3.84, half: 2.6, base: 3.2, step: 0.48, steps: 8 };
const Tower = (() => {
  const T = { active: false, standing: false, hp: 0, maxHp: TOWER.hp, x: 0, z: 0, group: null, inner: null, cols: [], fallT: -1, fallDir: 1, shake: 0,
    marks: {}, on: false, crackT: 0, hintT: 0, sinkT: 0 };
  const _q = { x: 0, z: 0 };
  function reset() { Object.assign(T, { active: false, standing: false, hp: 0, group: null, inner: null, cols: [], slots: [], fallT: -1, shake: 0, marks: {}, on: false, crackT: 0, hintT: 0, landed: false }); }
  function build(G, x, z) {
    reset(); T.active = true; T.standing = true; T.hp = T.maxHp = TOWER.hp; T.x = x; T.z = z;
    const keep = World.keep, PH = TOWER.ph, H = TOWER.half, Bh = TOWER.base;
    const plankTex = keep(canvasTex(256, 256, (g, w, h) => {
      g.fillStyle = '#7d5b3a'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 8; i++) { g.fillStyle = pick(['#86613e', '#74533a', '#8c6943', '#6e4f33']); g.fillRect(i * 32 + 1, 0, 30, h); g.fillStyle = 'rgba(30,18,8,0.55)'; g.fillRect(i * 32, 0, 2, h); }
      speckle(g, w, h, 1400, ['rgba(60,40,20,0.35)', 'rgba(150,110,70,0.25)'], 2);
      for (let i = 0; i < 16; i++) { g.fillStyle = 'rgba(40,26,12,0.6)'; g.beginPath(); g.arc(rand(0, w), rand(0, h), rand(1.5, 3), 0, TAU); g.fill(); }
    }, 1, 1));
    plankTex.wrapS = plankTex.wrapT = THREE.RepeatWrapping;
    const plank = new THREE.MeshStandardMaterial({ map: plankTex, roughness: 0.9 });
    const beam = new THREE.MeshStandardMaterial({ color: 0x5a3f28, roughness: 0.92 });
    const tin = new THREE.MeshStandardMaterial({ color: 0x8b8f92, roughness: 0.55, metalness: 0.55, side: THREE.DoubleSide });
    const outer = new THREE.Group(); outer.position.set(x, 0, z); G.add(outer);
    const inner = new THREE.Group(); outer.add(inner);
    T.group = outer; T.inner = inner;
    const mesh = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = true; m.receiveShadow = true; inner.add(m); return m; };
    // the skirt: four plank walls, a sill and a cap
    const skirt = new THREE.BoxGeometry(2 * Bh, 2.0, 2 * Bh); skirt.translate(0, 1.0, 0);
    const uv = skirt.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 2.5, uv.getY(i) * 0.8);
    mesh(skirt, plank);
    // the frame above it: corner legs, cross braces, the platform, joists
    const parts = [];
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) parts.push([0.42, PH - 1.9, 0.42, sx * (H - 0.2), 1.9 + (PH - 1.9) / 2 - 0.12, sz * (H - 0.2)]);
    parts.push([2 * Bh + 0.12, 0.16, 0.16, 0, 2.06, Bh], [2 * Bh + 0.12, 0.16, 0.16, 0, 2.06, -Bh], [0.16, 0.16, 2 * Bh + 0.12, Bh, 2.06, 0], [0.16, 0.16, 2 * Bh + 0.12, -Bh, 2.06, 0]);
    parts.push([2 * H + 0.2, 0.22, 0.22, 0, PH - 0.35, H], [2 * H + 0.2, 0.22, 0.22, 0, PH - 0.35, -H], [0.22, 0.22, 2 * H + 0.2, H, PH - 0.35, 0], [0.22, 0.22, 2 * H + 0.2, -H, PH - 0.35, 0]);
    mesh(mergeBoxes(parts), beam);
    // diagonal braces on each side of the open frame
    const braces = [];
    const brace = (ax, az, bx, bz, y0, y1) => { const len = Math.hypot(bx - ax, bz - az, y1 - y0), g = new THREE.BoxGeometry(0.14, len, 0.14);
      const o = new THREE.Object3D(); o.position.set((ax + bx) / 2, (y0 + y1) / 2, (az + bz) / 2); o.lookAt(bx, y1, bz); o.rotateX(Math.PI / 2); o.updateMatrix(); g.applyMatrix4(o.matrix); braces.push(g); };
    const e = H - 0.2;
    for (const s of [-1, 1]) { brace(-e, s * e, e, s * e, 2.1, PH - 0.4); brace(e, s * e, -e, s * e, 2.1, PH - 0.4); brace(s * e, -e, s * e, e, 2.1, PH - 0.4); brace(s * e, e, s * e, -e, 2.1, PH - 0.4); }
    mesh(mergeGeos(braces), beam);
    const floor = new THREE.BoxGeometry(2 * H, 0.24, 2 * H); floor.translate(0, PH - 0.12, 0);
    const fuv = floor.attributes.uv; for (let i = 0; i < fuv.count; i++) fuv.setXY(i, fuv.getX(i) * 2, fuv.getY(i) * 2);
    mesh(floor, plank);
    // railing: posts and two rails, open on the south side where the steps come up
    const rail = [], top = PH + 1.05, mid = PH + 0.55;
    for (const [px, pz] of [[-H, -H], [H, -H], [-H, H], [H, H], [0, -H], [-H, 0], [H, 0], [-0.8, H], [0.8, H]]) rail.push([0.12, 1.1, 0.12, px, PH + 0.55, pz]);
    for (const y of [mid, top]) {
      rail.push([2 * H, 0.08, 0.08, 0, y, -H], [0.08, 0.08, 2 * H, -H, y, 0], [0.08, 0.08, 2 * H, H, y, 0]);
      rail.push([H - 0.8, 0.08, 0.08, -(H + 0.8) / 2, y, H], [H - 0.8, 0.08, 0.08, (H + 0.8) / 2, y, H]);
    }
    // the roof: four poles and a tin pyramid
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) rail.push([0.14, 6.7 - PH, 0.14, sx * (H - 0.12), PH + (6.7 - PH) / 2, sz * (H - 0.12)]);
    mesh(mergeBoxes(rail), beam);
    const roof = new THREE.ConeGeometry(H * 1.55, 1.3, 4, 1, true); roof.rotateY(Math.PI / 4); roof.translate(0, 6.7 + 0.65, 0);
    mesh(roof, tin);
    // the steps: solid blocks from the ground, with stringers and a handrail each side
    const steps = [], side = [];
    for (let k = 1; k <= TOWER.steps; k++) { const h = k * TOWER.step, z0 = H + 0.5 * (TOWER.steps - k); steps.push([1.4, h, 0.5, 0, h / 2, z0 + 0.25]); }
    const run = 0.5 * TOWER.steps, ang = Math.atan2(PH, run), len = Math.hypot(PH, run);
    for (const sx of [-0.78, 0.78]) {
      const s1 = new THREE.BoxGeometry(0.1, 0.3, len); s1.rotateX(ang); s1.translate(sx, PH / 2 - 0.05, H + run / 2); side.push(s1);
      const s2 = new THREE.BoxGeometry(0.07, 0.07, len); s2.rotateX(ang); s2.translate(sx, PH / 2 + 1.0, H + run / 2); side.push(s2);
      for (let k = 0; k <= 2; k++) { const zz = H + run - k * run / 2 - 0.1, yy = PH * (k / 2); const p = new THREE.BoxGeometry(0.08, 1.0, 0.08); p.translate(sx, yy + 0.5, zz); side.push(p); }
    }
    const stepGeo = mergeBoxes(steps), suv = stepGeo.attributes.uv; for (let i = 0; i < suv.count; i++) suv.setXY(i, suv.getX(i) * 0.6, suv.getY(i) * 1.4);
    mesh(stepGeo, plank); mesh(mergeGeos(side), beam);
    // a sign on the railing
    const signTex = keep(canvasTex(256, 96, (g, w, h) => { g.fillStyle = '#e6d6a6'; g.fillRect(0, 0, w, h); g.fillStyle = '#6a3a1e'; g.fillRect(0, 0, w, 8); g.fillRect(0, h - 8, w, 8);
      g.fillStyle = '#3a2412'; g.font = '46px "Black Han Sans", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('감시탑', w / 2, h / 2 + 2); }));
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 0.56), new THREE.MeshStandardMaterial({ map: signTex, roughness: 0.8 }));
    sign.position.set(-1.7, PH + 0.8, H + 0.07); inner.add(sign);
    // colliders: the skirt and the steps are solid; the platform; the railing and poles let bullets and eyes through (grate)
    const add = (minx, miny, minz, maxx, maxy, maxz, grate) => { const b = addCollider(x + minx, miny, z + minz, x + maxx, maxy, z + maxz, 'wood'); b.tower = true; if (grate) b.grate = true; T.cols.push(b); return b; };
    add(-Bh, 0, -Bh, Bh, 2.0, Bh);
    add(-H, PH - 0.24, -H, H, PH, H);
    for (let k = 1; k <= TOWER.steps; k++) { const h = k * TOWER.step, z0 = H + 0.5 * (TOWER.steps - k); add(-0.7, 0, z0, 0.7, h, z0 + 0.5); }
    add(-H, PH, -H - 0.06, H, PH + 1.1, -H + 0.06, true); add(-H - 0.06, PH, -H, -H + 0.06, PH + 1.1, H, true); add(H - 0.06, PH, -H, H + 0.06, PH + 1.1, H, true);
    add(-H, PH, H - 0.06, -0.75, PH + 1.1, H + 0.06, true); add(0.75, PH, H - 0.06, H, PH + 1.1, H + 0.06, true);
    add(-H - 0.1, 6.7, -H - 0.1, H + 0.1, 7.0, H + 0.1);
    // the places along its foot where an animal can get at it: about one every 1.9 m round the skirt and the steps.
    // only that many hit it at once; the rest wait their turn a little way off
    T.slots = [];
    const sEnd = H + 0.5 * TOWER.steps;
    const along = (x0, z0, x1, z1, nx, nz) => { const L = Math.hypot(x1 - x0, z1 - z0), n = Math.max(1, Math.round(L / 1.9));
      for (let i = 0; i < n; i++) { const t = (i + 0.5) / n; T.slots.push({ x: x + x0 + (x1 - x0) * t, z: z + z0 + (z1 - z0) * t, nx, nz, owner: null, t: -9 }); } };
    along(-Bh, -Bh, Bh, -Bh, 0, -1); along(-Bh, -Bh, -Bh, Bh, -1, 0); along(Bh, -Bh, Bh, Bh, 1, 0);
    along(-Bh, Bh, -0.7, Bh, 0, 1); along(0.7, Bh, Bh, Bh, 0, 1);
    along(-0.7, Bh, -0.7, sEnd, -1, 0); along(0.7, Bh, 0.7, sEnd, 1, 0); along(-0.7, sEnd, 0.7, sEnd, 0, 1);
    return T;
  }
  /* a place at the tower for this animal: the one it already has, or the free one nearest to it. null: all taken, wait */
  function claim(e) {
    const s0 = e.slot;
    if (s0 && s0.owner === e) { s0.t = time; return s0; }
    let best = null, bd = Infinity;
    for (const s of T.slots) {
      if (s.owner && s.owner !== e && s.owner.alive && time - s.t < 0.6) continue;
      const d = Math.hypot(s.x - e.pos.x, s.z - e.pos.z); if (d < bd) { bd = d; best = s; }
    }
    if (best) { best.owner = e; best.t = time; e.slot = best; }
    return best;
  }
  /* where you are: up on the platform, or high enough on the steps that nothing but a giraffe reaches you */
  function playerOn() {
    if (!T.standing) return false;
    const px = player.pos.x - T.x, pz = player.pos.z - T.z, py = player.pos.y;
    if (py > TOWER.ph - 0.6 && Math.abs(px) < TOWER.half + 0.1 && Math.abs(pz) < TOWER.half + 0.1) return true;
    return py > 2.3 && Math.abs(px) < 0.8 && pz > TOWER.half - 0.1 && pz < TOWER.half + 0.5 * TOWER.steps + 0.1;
  }
  /* the closest point of the tower's foot (skirt or steps) to a spot on the ground */
  function nearest(x, z, out) {
    const lx = x - T.x, lz = z - T.z, B = TOWER.base;
    let ax = clamp(lx, -B, B), az = clamp(lz, -B, B);
    const sz0 = TOWER.half, sz1 = TOWER.half + 0.5 * TOWER.steps;
    const bx = clamp(lx, -0.7, 0.7), bz = clamp(lz, sz0, sz1);
    if (Math.hypot(lx - bx, lz - bz) < Math.hypot(lx - ax, lz - az)) { ax = bx; az = bz; }
    out.x = T.x + ax; out.z = T.z + az; return out;
  }
  function hurt(dmg, e, at) {
    if (!T.standing || Game.ended || !(dmg > 0)) return;
    T.hp = Math.max(0, T.hp - dmg); T.shake = Math.min(1, T.shake + 0.2 + dmg / 60);
    if (at) { FX.chunks(at, dmg >= 40 ? 4 : 2, 0.12, 'wood'); FX.puff(at, dmg >= 40 ? 3 : 1, 0.55, 0.5); }
    if (T.crackT <= 0) { T.crackT = 0.12; Sound.crack(at || T.group.position); if (dmg >= 40) Sound.thud(at || T.group.position); }
    if (T.on) { player.shake = Math.max(player.shake, 0.05 + dmg / 500); if (dmg >= 40) buzz(40); }
    const f = T.hp / T.maxHp;
    for (const m of [0.75, 0.5, 0.25, 0.1]) if (f <= m && !T.marks[m]) { T.marks[m] = true; HUD.banner('감시탑 체력 ' + Math.round(m * 100) + '%', m <= 0.25 ? '곧 무너집니다! 탑을 치는 동물부터 잡으세요' : '탑을 공격하는 동물을 쏘세요', 2); }
    if (T.hp <= 0) collapse();
  }
  /* down it comes: the colliders go at once, the frame topples away from the steps and sinks into a heap of dust */
  function collapse() {
    if (!T.standing) return;
    const was = playerOn();
    T.standing = false; T.on = false; T.fallT = 0; T.fallDir = Math.random() < 0.5 ? 1 : -1;
    for (const b of T.cols) removeCollider(b);
    T.cols = []; buildNav(); updateFlow(player.pos.x, player.pos.z);
    const c = { x: T.x, y: 1.5, z: T.z };
    Sound.crack(c); Sound.quake(c); Sound.boom(c, false);
    for (let i = 0; i < 14; i++) { const a = (i / 14) * TAU; FX.puff({ x: T.x + Math.cos(a) * 3.5, y: 0.5, z: T.z + Math.sin(a) * 3.5 }, 2, 0.6, 1.4); }
    FX.chunks({ x: T.x, y: 3, z: T.z }, 18, 0.3, 'wood');
    player.shake = Math.max(player.shake, 0.7); buzz(260);
    if (was) {
      // you come down with it: thrown clear, a second to get your bearings
      player.grounded = false; player.vel.y = 2.5; player.vel.x += T.fallDir * 2; player.stunT = Math.max(player.stunT, 1);
      Gun.trigger = false; Gun.adsHeld = false;
      HUD.banner('감시탑이 무너졌습니다', '땅으로 떨어졌습니다 · 이제 동물들이 나를 노립니다', 3);
    } else HUD.banner('감시탑이 무너졌습니다', '이제 숨을 곳이 없습니다', 2.6);
    HUD.feed('감시탑 붕괴', 0, 'hs');
  }
  function update(dt) {
    if (!T.active) return;
    T.crackT -= dt;
    T.on = playerOn();
    if (T.on && T.hintT <= 0 && !Game.ended) { T.hintT = 1e9; HUD.hint('감시탑 위 · 동물들은 탑부터 공격합니다 (기린은 목으로 탑 위까지 칩니다)', 3.2); }
    if (T.standing) {
      T.shake = Math.max(0, T.shake - dt * 2.2);
      const lean = (1 - T.hp / T.maxHp) * 0.035, s = T.shake * 0.06;
      T.inner.position.set(rand(-1, 1) * s, 0, rand(-1, 1) * s); T.inner.rotation.set(lean * 0.6, 0, lean);
    } else if (T.fallT >= 0) {
      T.fallT += dt;
      const t = T.fallT, k = Math.min(1, t / 1.5), a = k * k * 1.45;
      T.inner.rotation.set(0, 0, T.fallDir * a); T.inner.position.set(T.fallDir * Math.sin(a) * 1.6, -Math.max(0, t - 1.5) * 1.2, 0);
      if (t > 1.5 && !T.landed) { T.landed = true; const p = { x: T.x + T.fallDir * 5, y: 0.5, z: T.z }; Sound.quake(p); for (let i = 0; i < 10; i++) FX.puff({ x: p.x + rand(-3, 3), y: 0.4, z: p.z + rand(-3, 3) }, 2, 0.6, 1.6); }
      if (t > 4) { T.group.visible = false; T.fallT = -1; }
    }
  }
  return Object.assign(T, { build, reset, playerOn, nearest, claim, hurt, collapse, update, holds() { return T.standing && T.on; } });
})();

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

/* ============ weapons: catalogue and view models ============ */
// price = game price in won (real street price / 100); real = approximate real-world price in won
const WEAPONS = {
  pistol: { name: '권총', model: 'P9', short: '권총', tab: '권총', cls: '9mm 반자동 권총', price: 0, real: 770000, dmg: 34, rate: 0.15, auto: false, mag: 12, reserve: Infinity, reload: 1.1,
    spread: 0.01, adsSpread: 0.002, moveSpread: 0.018, pellets: 1, recoil: 0.024, kick: 0.07, range: 90, adsFov: 60, sound: 'pistol', flash: 2.2, head: 2.5, bloom: 0.012, ammoCost: 0, moveMul: 1 },
  // 5.8: pellets hit 1.5x as hard (13 -> 19.5) and carry twice as far (falloff 7-24 m -> 14-48 m, reach 40 -> 80 m)
  shotgun: { name: '산탄총', model: 'S-12', short: '산탄총', tab: '산탄', cls: '12게이지 펌프액션 산탄총', price: 7000, real: 700000, dmg: 19.5, rate: 0.8, auto: false, mag: 6, reserve: 480, reload: 2.3,
    spread: 0.14, adsSpread: 0.10, moveSpread: 0.012, pellets: 9, recoil: 0.06, kick: 0.13, range: 40, adsFov: 64, sound: 'shotgun', flash: 3.6, head: 1.6, bloom: 0, falloff: [7, 24], ammoCost: 360, moveMul: 1 },
  // 5.11: the rifle and the SMG pulled further apart. the rifle hits hard and dead straight when you aim and stand still, but kicks and wanders on the move;
  // the SMG sprays fast, reloads fast and runs fast, accurate on the move, but its 9 mm falls off quickly with distance
  rifle: { name: '돌격소총', model: 'AR-7', short: '소총', tab: '소총', cls: '5.56mm 돌격소총', price: 17000, real: 1700000, dmg: 42, rate: 0.11, auto: true, mag: 30, reserve: 480, reload: 2.0,
    spread: 0.012, adsSpread: 0.0008, moveSpread: 0.042, pellets: 1, recoil: 0.021, kick: 0.05, range: 240, adsFov: 42, sound: 'rifle', flash: 3.0, head: 2.5, bloom: 0.0045, ammoCost: 1400, moveMul: 0.96, adsSpeed: 6,
    note: '한 발이 세고 정확함 · 움직이며 쏘면 많이 퍼짐' },
  smg: { name: '기관단총', model: 'V-9', short: '기관단총', tab: 'SMG', cls: '9mm 기관단총', price: 28000, real: 2800000, dmg: 19, rate: 0.045, auto: true, mag: 40, reserve: 960, reload: 1.0,
    spread: 0.03, adsSpread: 0.012, moveSpread: 0.006, pellets: 1, recoil: 0.0085, kick: 0.022, range: 60, adsFov: 60, sound: 'smg', flash: 2, head: 2, bloom: 0.0035, falloff: [10, 38], ammoCost: 1050, moveMul: 1.12, adsSpeed: 12,
    note: '아주 빠른 연사·재장전·이동 · 움직여도 정확 · 멀면 약해짐' },
  sniper: { name: '저격총', model: 'L-308', short: '저격총', tab: '저격', cls: '7.62mm 볼트액션 저격총', price: 42000, real: 4200000, dmg: 125, rate: 1.3, auto: false, mag: 5, reserve: 100, reload: 2.6,
    spread: 0.06, adsSpread: 0, moveSpread: 0.04, pellets: 1, recoil: 0.07, kick: 0.16, range: 320, adsFov: 16, scope: true, sound: 'sniper', flash: 3.2, head: 2.5, bloom: 0, ammoCost: 600, moveMul: 0.92 },
  gl: { name: '유탄발사기', model: 'G-40', short: '유탄', tab: '유탄', cls: '40mm 6연발 유탄발사기', price: 70000, real: 7000000, dmg: 170, splash: 5, grenade: true, rate: 0.85, auto: false, mag: 6, reserve: 42, reload: 3.6,
    spread: 0.01, adsSpread: 0.004, moveSpread: 0.01, pellets: 1, recoil: 0.05, kick: 0.12, range: 120, adsFov: 60, sound: 'gl', flash: 2.4, head: 1, bloom: 0, ammoCost: 18000, moveMul: 0.95 },
  // 5.14: a 240-round box. it heats up as you fire (the gun goes red); empty a full box in one go and it overheats: smoke, glowing red,
  // and no reloading until you have swapped to another gun. 10% slower on your feet while it is in your hands
  lmg: { name: '기관총', model: 'M-200', short: '기관총', tab: '기관총', cls: '5.56mm 분대지원 기관총', price: 110000, real: 11000000, dmg: 28, rate: 0.05, auto: true, mag: 240, reserve: 1200, reload: 5.2,
    spread: 0.03, adsSpread: 0.012, moveSpread: 0.03, pellets: 1, recoil: 0.009, kick: 0.03, range: 150, adsFov: 52, sound: 'lmg', flash: 3.2, head: 2, bloom: 0.0025, ammoCost: 2400, moveMul: 0.9, adsSpeed: 4.5,
    heavy: true, heat: true, note: '탄창 240발 · 쏠수록 총이 빨갛게 달아오름 · 한 탄창을 쉬지 않고 다 쏘면 과열(연기) · 과열되면 다른 총으로 바꿔야 재장전 · 이동속도 10% 감소' },
  // 5.12: a guided rocket launcher. one rocket at a time (reload after every shot), twelve carried in all; 1,000 on a direct hit and a 6 m blast.
  // the rocket goes for the enemy nearest the crosshair when it is fired (a red diamond marks it) and steers after it. dear to rent, 10,000 a rocket
  rocket: { name: '유도로켓발사기', model: 'R-12', short: '유도로켓', tab: '로켓', cls: '유도 로켓발사기 · 한 발씩 장전', price: 300000, real: 30000000, dmg: 1000, splash: 6, splashDmg: 500, rocket: true,
    rate: 0.6, auto: false, mag: 1, reserve: 11, reload: 2.2, spread: 0.004, adsSpread: 0.002, moveSpread: 0.012, pellets: 1, recoil: 0.06, kick: 0.16, range: 200, adsFov: 50, sound: 'rocket',
    flash: 3.4, head: 1, bloom: 0, ammoCost: 0, moveMul: 0.88, adsSpeed: 5, note: '쏠 때 조준선에 가장 가까운 적을 쫓아감 · 직격 1,000 · 폭발 반경 6 m (나도 맞음) · 한 발마다 재장전 · 최대 12발' },
};
const ORDER = ['pistol', 'shotgun', 'rifle', 'smg', 'sniper', 'gl', 'lmg', 'rocket'];
/* guns are rented for one stage now: the fee is 30% of the old price (real price / 100), the pistol is free */
ORDER.forEach((id) => { WEAPONS[id].rent = id === 'pistol' ? 0 : Math.round(WEAPONS[id].price * 0.3 / 100) * 100; });
function fixSave() {
  const lo = Array.isArray(save.loadout) ? save.loadout : [];
  save.loadout = Array.from({ length: 7 }, (_, i) => (WEAPONS[lo[i]] ? lo[i] : null));
  save.loadout.forEach((id, i) => { if (id && save.loadout.indexOf(id) !== i) save.loadout[i] = null; }); // one slot per gun
  save.rented = (Array.isArray(save.rented) ? save.rented : []).filter((id, i, a) => WEAPONS[id] && id !== 'pistol' && a.indexOf(id) === i);
  // guns from boss chests are yours for good
  save.owned = (Array.isArray(save.owned) ? save.owned : []).filter((id, i, a) => WEAPONS[id] && id !== 'pistol' && a.indexOf(id) === i);
  save.cleared = [...new Set((Array.isArray(save.cleared) ? save.cleared : []).map(Number).filter((n) => STAGE_ORDER.includes(n)))].sort();
  delete save.unlocked; // what is open now follows from what is cleared
  // things you bought and have not used up yet: a helmet (one head hit), a vest (durability 0-10), a jetpack (one flight)
  const it = save.items && typeof save.items === 'object' ? save.items : {};
  save.items = { helmet: it.helmet ? 1 : 0, vest: clamp(Math.round(+it.vest || 0), 0, 10), jet: it.jet ? 1 : 0, ivory: clamp(Math.round(+it.ivory || 0), 0, 63) }; // ivory: elephant tusks, for selling
  save.money = Math.max(0, Math.floor(+save.money || 0));
  if (!save.best || typeof save.best !== 'object') save.best = {};
  save.v = 4;
}
/* saves from before rentals: guns that were bought outright are refunded, and stages already passed count as cleared */
(function migrate() {
  if (save.v < 2) {
    if (Array.isArray(save.owned)) for (const id of save.owned) if (WEAPONS[id] && id !== 'pistol') save.money += WEAPONS[id].price;
    save.cleared = [1, 2, 3].filter((n) => save.unlocked > n || (save.best && save.best['t' + n]));
    save.loadout = ['pistol', null, null, null, null, null, null]; save.rented = [];
    delete save.owned; delete save.equip;
  }
  // 5.6: the old dock is stage 1 again, with 1-1 (helmets) and 1-2 hanging off it. a cleared 1-2 means its helmet stage was beaten too
  if (save.v < 4 && Array.isArray(save.cleared) && save.cleared.map(Number).includes(5) && !save.cleared.map(Number).includes(6)) save.cleared.push(6);
  fixSave(); persist();
})();
// shop price for 100 more rounds (about 1/100 of the real cost per round)
const AMMO100 = { shotgun: 1000, rifle: 800, smg: 500, sniper: 2000, gl: 100000, lmg: 800, rocket: 10000 };
/* what one purchase (or an ammo box) adds: 100 rounds, or a single rocket (and never more rockets than you can carry) */
const ammoPack = (id) => (WEAPONS[id].rocket ? 1 : 100);
const ammoRoom = (id) => (WEAPONS[id].rocket ? Math.max(0, WEAPONS[id].reserve + WEAPONS[id].mag - wstate[id].mag - wstate[id].reserve) : Infinity);
const wstate = {};
ORDER.forEach((id) => { wstate[id] = { mag: WEAPONS[id].mag, reserve: WEAPONS[id].reserve }; });
const Gun = { cur: 'pistol', slots: ['pistol'], loadout: ['pistol', null, null, null, null, null, null], none: false, busy: 0, cooldown: 0, reloadT: 0, switchT: 0, pending: null, ads: 0, adsHeld: false, bloom: 0,
  kickZ: 0, kickRot: 0, swayX: 0, swayY: 0, flashT: 0, trigger: false, triggerEdge: false, reloadHalf: false };

const viewRoot = new THREE.Group(); viewScene.add(viewRoot);
const gunModels = {};
const HIP = {}, ADSP = {};
(function buildGuns() {
  const metal = new THREE.MeshStandardMaterial({ color: 0x3b4048, roughness: 0.45, metalness: 0.35 });
  const dark = new THREE.MeshStandardMaterial({ color: 0x23262b, roughness: 0.5, metalness: 0.4 });
  const poly = new THREE.MeshStandardMaterial({ color: 0x24272c, roughness: 0.8 });
  const olive = new THREE.MeshStandardMaterial({ color: 0x4a5236, roughness: 0.85 });
  const accent = new THREE.MeshStandardMaterial({ color: 0xb8701c, roughness: 0.5, metalness: 0.4, emissive: 0x2a1500 });
  const wood = new THREE.MeshStandardMaterial({ color: 0x6b4528, roughness: 0.7 });
  const glove = new THREE.MeshStandardMaterial({ color: 0x26292e, roughness: 0.9 });
  const sleeve = new THREE.MeshStandardMaterial({ color: 0x222a37, roughness: 0.95 });
  const lens = new THREE.MeshStandardMaterial({ color: 0x1b3550, roughness: 0.1, metalness: 0.6, emissive: 0x06121e });
  const sightMat = new THREE.MeshBasicMaterial({ color: 0xff5a3a });
  for (const m of [metal, poly, olive, wood]) m.userData.paint = true;
  for (const m of [metal, dark]) m.userData.hot = true;
  sightMat.userData.iron = true; // the front sight posts: hidden when an optic goes on
  const box = (g, w, h, d, m, x, y, z, rx) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); if (rx) o.rotation.x = rx; g.add(o); return o; };
  const cyl = (g, r, l, m, x, y, z) => { const o = new THREE.Mesh(new THREE.CylinderGeometry(r, r, l, 12), m); o.rotation.x = Math.PI / 2; o.position.set(x, y, z); g.add(o); return o; };
  const flashTex = canvasTex(64, 64, (g) => { g.translate(32, 32); for (let i = 0; i < 6; i++) { g.rotate(Math.PI / 3);
    const gr = g.createLinearGradient(0, 0, 30, 0); gr.addColorStop(0, 'rgba(255,240,200,1)'); gr.addColorStop(1, 'rgba(255,140,40,0)');
    g.fillStyle = gr; g.beginPath(); g.moveTo(0, -4); g.lineTo(30, 0); g.lineTo(0, 4); g.fill(); }
    const r = g.createRadialGradient(0, 0, 0, 0, 0, 16); r.addColorStop(0, 'rgba(255,250,230,1)'); r.addColorStop(1, 'rgba(255,160,60,0)'); g.fillStyle = r; g.fillRect(-16, -16, 32, 32); });
  const flashMat = new THREE.MeshBasicMaterial({ map: flashTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  function hands(g, gx, gy, gz, fx, fy, fz) {
    const hs = [box(g, 0.05, 0.075, 0.06, glove, gx, gy, gz), box(g, 0.075, 0.075, 0.32, sleeve, gx + 0.04, gy - 0.07, gz + 0.2, 0.35)];
    if (fx !== undefined) { hs.push(box(g, 0.055, 0.04, 0.09, glove, fx, fy, fz)); const b = box(g, 0.07, 0.07, 0.34, sleeve, fx - 0.07, fy - 0.08, fz + 0.18, 0.3); b.rotation.y = -0.45; hs.push(b); }
    for (const h of hs) h.userData.hand = true;
  }
  function finish(id, g, muzzleZ, muzzleY, sightY, hip) {
    const fl = new THREE.Mesh(new THREE.PlaneGeometry(0.22, 0.22), flashMat); fl.position.set(0, muzzleY, muzzleZ); fl.visible = false; g.add(fl);
    g.userData.flash = fl; g.userData.sightY = sightY; g.userData.mz = { y: muzzleY, z: muzzleZ };
    g.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
    g.visible = false; viewRoot.add(g); gunModels[id] = g;
    HIP[id] = new THREE.Vector3(hip[0], hip[1], hip[2]); ADSP[id] = new THREE.Vector3(0, -sightY, hip[3]);
  }
  let g = new THREE.Group();                                   // P9 pistol
  box(g, 0.034, 0.04, 0.2, metal, 0, 0.012, -0.05); box(g, 0.03, 0.026, 0.17, poly, 0, -0.018, -0.04);
  box(g, 0.03, 0.1, 0.045, poly, 0, -0.065, 0.025, 0.25); box(g, 0.036, 0.006, 0.05, accent, 0, 0.034, -0.12);
  box(g, 0.006, 0.012, 0.006, sightMat, 0, 0.038, -0.145); box(g, 0.022, 0.012, 0.006, metal, 0, 0.038, 0.04);
  hands(g, 0, -0.07, 0.03, 0, -0.06, -0.01); finish('pistol', g, -0.16, 0.012, 0.05, [0.16, -0.165, -0.4, -0.3]);
  g = new THREE.Group();                                       // S-12 shotgun
  box(g, 0.05, 0.065, 0.24, metal, 0, 0, 0); cyl(g, 0.016, 0.5, metal, 0, 0.012, -0.36); cyl(g, 0.013, 0.42, metal, 0, -0.022, -0.31);
  box(g, 0.05, 0.045, 0.14, wood, 0, -0.024, -0.3); box(g, 0.034, 0.09, 0.045, wood, 0, -0.07, 0.11, 0.35); box(g, 0.045, 0.07, 0.26, wood, 0, -0.03, 0.27);
  box(g, 0.006, 0.01, 0.006, sightMat, 0, 0.034, -0.6); box(g, 0.052, 0.01, 0.06, accent, 0, 0.034, 0.02);
  hands(g, 0, -0.08, 0.12, 0, -0.06, -0.3); finish('shotgun', g, -0.62, 0.012, 0.044, [0.19, -0.17, -0.47, -0.34]);
  g = new THREE.Group();                                       // AR-7 rifle
  box(g, 0.05, 0.07, 0.34, metal, 0, 0, 0); box(g, 0.056, 0.06, 0.2, poly, 0, -0.004, -0.25); cyl(g, 0.011, 0.22, metal, 0, 0.004, -0.44);
  box(g, 0.036, 0.13, 0.06, poly, 0, -0.1, -0.06, -0.22); box(g, 0.034, 0.09, 0.04, poly, 0, -0.07, 0.09, 0.3); box(g, 0.04, 0.06, 0.22, poly, 0, -0.012, 0.27);
  box(g, 0.02, 0.012, 0.3, metal, 0, 0.042, -0.05); box(g, 0.03, 0.014, 0.06, metal, 0, 0.055, 0.03); box(g, 0.008, 0.008, 0.004, sightMat, 0, 0.066, -0.2);
  box(g, 0.058, 0.012, 0.12, accent, 0, 0, -0.27);
  hands(g, 0, -0.08, 0.1, 0, -0.045, -0.26); finish('rifle', g, -0.56, 0.004, 0.074, [0.19, -0.18, -0.46, -0.27]);
  g = new THREE.Group();                                       // V-9 submachine gun
  box(g, 0.048, 0.062, 0.26, metal, 0, 0, 0); cyl(g, 0.01, 0.12, metal, 0, 0.006, -0.19);
  box(g, 0.03, 0.15, 0.045, poly, 0, -0.1, -0.05, -0.12); box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.08, 0.3);
  box(g, 0.008, 0.008, 0.18, dark, 0.018, -0.005, 0.22); box(g, 0.008, 0.008, 0.18, dark, -0.018, -0.005, 0.22); box(g, 0.05, 0.06, 0.012, poly, 0, -0.01, 0.31);
  box(g, 0.03, 0.03, 0.05, dark, 0, 0.045, -0.01); box(g, 0.006, 0.006, 0.004, sightMat, 0, 0.058, -0.03); box(g, 0.05, 0.01, 0.08, accent, 0, -0.025, -0.1);
  hands(g, 0, -0.08, 0.08, 0, -0.1, -0.05); finish('smg', g, -0.26, 0.006, 0.068, [0.17, -0.17, -0.42, -0.27]);
  g = new THREE.Group();                                       // L-308 bolt-action sniper rifle
  box(g, 0.05, 0.06, 0.3, metal, 0, 0, 0); cyl(g, 0.011, 0.55, metal, 0, 0.006, -0.42); box(g, 0.045, 0.085, 0.32, olive, 0, -0.025, 0.26);
  box(g, 0.05, 0.05, 0.3, olive, 0, -0.035, -0.2); cyl(g, 0.022, 0.3, dark, 0, 0.065, -0.02); cyl(g, 0.029, 0.06, dark, 0, 0.065, -0.17); cyl(g, 0.026, 0.05, dark, 0, 0.065, 0.13);
  cyl(g, 0.02, 0.004, lens, 0, 0.065, -0.201); box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, -0.06); box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, 0.05);
  const bolt = cyl(g, 0.008, 0.06, metal, 0.035, 0.015, 0.06); bolt.rotation.set(0, 0, Math.PI / 2);
  box(g, 0.034, 0.09, 0.04, olive, 0, -0.08, 0.1, 0.3);
  hands(g, 0, -0.085, 0.11, 0, -0.06, -0.24); finish('sniper', g, -0.7, 0.006, 0.065, [0.19, -0.18, -0.48, -0.26]);
  g = new THREE.Group();                                       // G-40 six-shot grenade launcher
  cyl(g, 0.06, 0.14, dark, 0, -0.01, -0.03); cyl(g, 0.024, 0.3, metal, 0, 0.03, -0.24); box(g, 0.04, 0.035, 0.26, metal, 0, 0.055, -0.02);
  box(g, 0.032, 0.09, 0.04, poly, 0, -0.08, -0.22, -0.1); box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.1, 0.3); box(g, 0.04, 0.06, 0.24, poly, 0, -0.005, 0.27);
  box(g, 0.03, 0.04, 0.006, dark, 0, 0.085, -0.12); box(g, 0.007, 0.007, 0.004, sightMat, 0, 0.075, -0.125); box(g, 0.064, 0.012, 0.05, accent, 0, 0.05, 0.05);
  hands(g, 0, -0.085, 0.11, 0, -0.085, -0.22); finish('gl', g, -0.4, 0.03, 0.112, [0.19, -0.17, -0.45, -0.3]);
  g = new THREE.Group();                                       // M-200 light machine gun
  box(g, 0.07, 0.09, 0.42, metal, 0, 0, 0); cyl(g, 0.013, 0.4, metal, 0, 0.01, -0.4); box(g, 0.045, 0.03, 0.26, dark, 0, 0.035, -0.32);
  box(g, 0.075, 0.1, 0.13, olive, -0.025, -0.095, -0.02); box(g, 0.02, 0.02, 0.14, dark, 0, 0.075, -0.06); box(g, 0.06, 0.02, 0.18, dark, 0, 0.055, 0.04);
  box(g, 0.05, 0.08, 0.26, poly, 0, -0.015, 0.33); box(g, 0.034, 0.09, 0.04, poly, 0, -0.08, 0.13, 0.3); box(g, 0.006, 0.006, 0.005, sightMat, 0, 0.068, 0.12);
  box(g, 0.01, 0.01, 0.2, dark, 0.02, -0.01, -0.42); box(g, 0.01, 0.01, 0.2, dark, -0.02, -0.01, -0.42);
  hands(g, 0, -0.085, 0.14, 0, -0.05, -0.27); finish('lmg', g, -0.62, 0.01, 0.092, [0.2, -0.19, -0.5, -0.3]);
  g = new THREE.Group();                                       // R-12 guided rocket launcher, carried on the shoulder
  cyl(g, 0.05, 0.85, olive, 0, 0.02, -0.2); cyl(g, 0.058, 0.07, dark, 0, 0.02, -0.6); cyl(g, 0.058, 0.05, dark, 0, 0.02, 0.2); cyl(g, 0.054, 0.04, dark, 0, 0.02, -0.02);
  box(g, 0.04, 0.04, 0.12, dark, 0, 0.088, -0.18); box(g, 0.032, 0.032, 0.008, lens, 0, 0.088, -0.245); box(g, 0.006, 0.006, 0.004, sightMat, 0, 0.112, -0.22);
  box(g, 0.03, 0.085, 0.038, poly, 0, -0.055, -0.08, 0.2); box(g, 0.03, 0.075, 0.038, poly, 0, -0.05, -0.36, -0.1); box(g, 0.05, 0.008, 0.06, accent, 0, 0.072, 0.1);
  const tip = new THREE.Mesh(new THREE.ConeGeometry(0.04, 0.12, 10), new THREE.MeshStandardMaterial({ color: 0x8a2a1c, roughness: 0.5, metalness: 0.3 }));
  tip.rotation.x = -Math.PI / 2; tip.position.set(0, 0.02, -0.68); g.add(tip); g.userData.tip = tip; // the loaded rocket's nose
  hands(g, 0, -0.09, -0.08, 0, -0.09, -0.36); finish('rocket', g, -0.72, 0.02, 0.112, [0.22, -0.15, -0.6, -0.36]);
})();
gunModels.pistol.visible = true;
/* 5.14: every gun gets its own copies of its materials, so one gun can be painted (or glow with heat) without the others.
   body: where paint goes (receiver and furniture); hot: what glows when the machine gun overheats; the hands keep theirs */
const GUN_MATS = {};
(function ownMaterials() {
  ORDER.forEach((id) => {
    const g = gunModels[id], own = new Map();
    g.traverse((o) => {
      if (!o.isMesh || !o.material || o.userData.hand) return;
      let m = own.get(o.material);
      if (!m) { m = o.material.clone(); m.userData = Object.assign({}, o.material.userData, { color: o.material.color ? o.material.color.getHex() : 0, metal: o.material.metalness, rough: o.material.roughness }); own.set(o.material, m); }
      o.material = m;
    });
    const all = [...own.values()];
    GUN_MATS[id] = { all, body: all.filter((m) => m.userData.paint), hot: all.filter((m) => m.userData.hot) };
  });
})();

/* ============ weapons: firing, reload, switching ============ */
const _fwd = new THREE.Vector3(), _right = new THREE.Vector3(), _up = new THREE.Vector3(), _dir = new THREE.Vector3(), _hitP = new THREE.Vector3(), _muz = new THREE.Vector3();
function curW() { return WEAPONS[Gun.cur]; }
function muzzleWorld(out) {
  camera.getWorldDirection(_fwd); _right.set(1, 0, 0).applyQuaternion(camera.quaternion); _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
  const a = Gun.ads;
  out.copy(camera.position).addScaledVector(_fwd, 0.7).addScaledVector(_right, 0.16 * (1 - a)).addScaledVector(_up, -0.12 * (1 - a) - 0.03 - 0.06 * a);
  return out;
}
function currentSpread() {
  const w = curW(), mv = clamp(player.speedXZ / 6, 0, 1.4);
  let s = lerp(w.spread, w.adsSpread, Gun.ads) + Gun.bloom + w.moveSpread * mv * (1 - Gun.ads * 0.6);
  if (!player.grounded) s += 0.03;
  return s;
}
/* ---------- the rocket launcher's lock: the living enemy nearest the middle of the screen, within about 10 degrees, 200 m and in sight ---------- */
const _lk = new THREE.Vector3(), _lf = new THREE.Vector3();
function rocketLock() {
  camera.getWorldDirection(_lf); const o = camera.position; let best = null, bestA = 0.18;
  for (const e of Enemies.list) {
    if (!e.alive || e.ridden || e.caged || !e.g.visible || (e.T && e.T.mode === 'mine' && (e.bs === 'hidden' || !e.bs))) continue;
    Proj.rocketCentre(e, _lk); const dx = _lk.x - o.x, dy = _lk.y - o.y, dz = _lk.z - o.z, d = Math.hypot(dx, dy, dz);
    if (d < 2.5 || d > 200) continue;
    const a = Math.acos(clamp((dx * _lf.x + dy * _lf.y + dz * _lf.z) / d, -1, 1));
    if (a >= bestA || !lineOfSight(o, _lk)) continue;
    best = e; bestA = a;
  }
  return best;
}
/* ---------- melee: V or the mouse's back button (on a touch screen the 근접 button). a quick jab with the gun at whatever is within
   arm's reach. 5.17: walk up to a wooden crate and the jab goes at it by itself ---------- */
// 120 to the body, twice that to the head; it makes no noise, cuts a reload short, and breaks crates too
const MELEE_DMG = 120, MELEE_REACH = 2.3, MELEE_T = 0.42;
const Melee = {
  t: 0, cd: 0, on: false, hit: false, target: null,
  start(target) {
    if (state !== 'playing' || this.cd > 0 || Gun.none || Gun.busy > 0 || player.stunT > 0 || Gun.switchT > 0) return;
    this.on = true; this.t = 0; this.cd = 0.62; this.hit = false; this.target = target || null;
    Gun.reloadT = 0; Gun.trigger = false; Gun.adsHeld = false;
    Sound.swing();
  },
  reset() { this.on = false; this.t = 0; this.cd = 0; this.target = null; },
  /* a crate within reach in front of you, on your level, and you are not busy with anything else (shooting, aiming, reloading,
     switching, injecting, riding, in the air): the jab goes at it. one jab breaks a crate */
  autoCrate() {
    if (this.on || this.cd > 0 || state !== 'playing' || Gun.none || Gun.busy > 0 || Gun.reloadT > 0 || Gun.switchT > 0 || Gun.trigger || Gun.adsHeld || Gun.ads > 0.05) return;
    if (player.stunT > 0 || !player.grounded || Car.riding || Ride.m || Toss.on || Jet.on) return;
    const fx = -Math.sin(player.yaw), fz = -Math.cos(player.yaw); let best = null, bd = 1.7;
    for (const c of crates) {
      if (c.dead || Math.abs((c.y || 0) - player.pos.y) > 1.1) continue;
      const dx = c.x - player.pos.x, dz = c.z - player.pos.z, d = Math.hypot(dx, dz);
      if (d < bd && (dx * fx + dz * fz) / (d || 1) > 0.4) { best = c; bd = d; } // within about 65 degrees of straight ahead
    }
    if (best) this.start(best);
  },
  update(dt) {
    this.cd = Math.max(0, this.cd - dt);
    if (!this.on) return;
    this.t += dt;
    if (!this.hit && this.t >= 0.11) { this.hit = true; this.strike(); }
    if (this.t >= MELEE_T) this.on = false;
  },
  /* a fan of short rays: the nearest body in reach wins (a head over a body at the same distance), else a crate */
  strike() {
    if (this.target) { const c = this.target; this.target = null; if (c.dead) return; // sent at a crate: it is hit, whatever the rays say
      _hitP.set(c.x, (c.y || 0) + 0.6, c.z); damageCrate(c, 60, _hitP); Sound.melee(_hitP, false); buzz(20); return; }
    camera.getWorldDirection(_fwd); _right.set(1, 0, 0).applyQuaternion(camera.quaternion); _up.set(0, 1, 0).applyQuaternion(camera.quaternion);
    const o = camera.position; let best = null;
    for (const [a, b] of [[0, 0], [0.16, 0], [-0.16, 0], [0, -0.15], [0, 0.12], [0.3, -0.12], [-0.3, -0.12], [0, -0.32]]) {
      _dir.copy(_fwd).addScaledVector(_right, a).addScaledVector(_up, b).normalize();
      raycastStatic(o.x, o.y, o.z, _dir.x, _dir.y, _dir.z, MELEE_REACH);
      const sT = RH.t, sBox = RH.box, eh = Enemies.raycast(o, _dir, sT);
      if (eh) { if (!best || best.crate || eh.t < best.t - 0.15 || (eh.weak && !best.weak && eh.t < best.t + 0.15)) best = { e: eh.enemy, t: eh.t, weak: eh.weak, mult: eh.mult, bomb: eh.bomb, d: _dir.clone() }; }
      else if (!best && sBox && sBox.kind === 'wood' && sBox.ref && sT < MELEE_REACH) best = { crate: sBox.ref, t: sT, d: _dir.clone() };
    }
    if (!best) return;
    _hitP.copy(o).addScaledVector(best.d, best.t);
    if (best.crate) { damageCrate(best.crate, 60, _hitP); Sound.melee(_hitP, false); return; }
    const e = best.e;
    let killed = false;
    if (best.bomb && e.alive) { Enemies.blowVest(e, best.d); killed = true; }
    else killed = Enemies.damage(e, MELEE_DMG * (best.weak ? 2 : best.mult || 1), _hitP, best.d, best.weak);
    if (e.alive && !e.boss && !e.kong && !e.robot) { e.vel.x += best.d.x * 4; e.vel.z += best.d.z * 4; } // and a shove
    HUD.hitmark(killed, best.weak); Sound.melee(_hitP, !!e.robot); player.shake = Math.max(player.shake, 0.12); buzz(30);
  },
  /* the jab: the gun thrusts forward and turns on its side, then comes back */
  pose(root) {
    if (!this.on) return;
    const u = this.t / MELEE_T, k = u < 0.28 ? u / 0.28 : Math.max(0, 1 - (u - 0.28) / 0.72), j = k * k * (3 - 2 * k);
    root.position.x -= j * 0.12; root.position.y += j * 0.03; root.position.z -= j * 0.3;
    root.rotation.x += j * 0.15; root.rotation.y += j * 0.9; root.rotation.z += j * 0.35;
  },
};
/* 5.14: the machine gun's heat. every shot adds 1/240; once you stop for a moment it cools by a fifth a second. empty a full box in one
   go and it overheats: it glows red, smokes off the barrel, and will not reload until you have swapped to another gun */
const _hotRed = new THREE.Color(0x8a0d06);
const Heat = (() => {
  let smokeMat = null; const parts = []; let spawnT = 0; const _p = new THREE.Vector3();
  function ensure() {
    if (smokeMat) return;
    const tex = canvasTex(64, 64, (g) => { const r = g.createRadialGradient(32, 32, 0, 32, 32, 32); r.addColorStop(0, 'rgba(235,235,235,0.9)'); r.addColorStop(0.5, 'rgba(205,205,205,0.35)'); r.addColorStop(1, 'rgba(180,180,180,0)'); g.fillStyle = r; g.fillRect(0, 0, 64, 64); });
    smokeMat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, opacity: 0 });
    for (let i = 0; i < 20; i++) { const s = new THREE.Sprite(smokeMat.clone()); s.visible = false; viewScene.add(s); parts.push({ s, t: 1, life: 1, vx: 0, vy: 0 }); }
  }
  function overheat(st) {
    st.hot = true; st.hotT = 0; Sound.hiss(); buzz(120);
    HUD.banner('기관총 과열', '연기가 납니다 · 다른 총으로 바꾼 뒤에 재장전할 수 있습니다', 2.6);
  }
  function shot(w, st) { st.heat = Math.min(1, (st.heat || 0) + 1 / w.mag); st.coolT = 0.3; if (st.mag === 0 && st.heat >= 0.97) overheat(st); }
  function update(dt) {
    const st = wstate.lmg; if (!st) return;
    st.heat = st.heat || 0;
    if (st.hot) {
      st.hotT = (st.hotT || 0) + dt;
      // swapping away is what lets it be reloaded again; with nothing to swap to, it gives in by itself after a while
      if ((Gun.cur !== 'lmg' && !Gun.pending) || (Gun.slots.length < 2 && st.hotT > 6)) st.hot = false;
    } else if ((st.coolT = (st.coolT || 0) - dt) <= 0) st.heat = Math.max(0, st.heat - dt * 0.2);
    const k = st.hot ? 0.9 + 0.1 * Math.sin(time * 18) : Math.pow(st.heat, 1.6);
    if (Math.abs(k - (st.glowK === undefined ? -1 : st.glowK)) > 0.004) { st.glowK = k; for (const m of GUN_MATS.lmg.hot) { m.color.setHex(m.userData.paintColor !== undefined ? m.userData.paintColor : m.userData.color).lerp(_hotRed, k * 0.85); m.emissive.setRGB(0.42 * k, 0.012 * k, 0.004 * k); } }
    // smoke off the barrel while it is overheated, and for a little while after
    st.smokeT = st.hot ? 2.5 : Math.max(0, (st.smokeT || 0) - dt);
    const g = gunModels.lmg;
    if (st.smokeT > 0 && g.visible && (spawnT -= dt) <= 0) {
      ensure(); spawnT = 0.06;
      const P = parts.find((q) => q.t >= q.life);
      if (P) { g.updateMatrixWorld(true); _p.set(rand(-0.012, 0.012), 0.03, rand(-0.58, -0.28)); g.localToWorld(_p); P.s.position.copy(_p); P.t = 0; P.life = rand(0.8, 1.2); P.vx = rand(-0.025, 0.025); P.vy = rand(0.05, 0.1); P.s.visible = true; }
    }
    for (const P of parts) {
      if (P.t >= P.life) continue;
      P.t += dt; const u = Math.min(1, P.t / P.life);
      P.s.position.x += P.vx * dt; P.s.position.y += P.vy * dt; P.s.scale.setScalar(0.03 + u * 0.085); P.s.material.opacity = 0.55 * (1 - u) * Math.min(1, u * 6);
      if (P.t >= P.life) P.s.visible = false;
    }
  }
  function reset() { const st = wstate.lmg; if (st) { st.heat = 0; st.hot = false; st.smokeT = 0; st.coolT = 0; st.glowK = undefined; } for (const P of parts) { P.t = P.life = 1; P.s.visible = false; } }
  return { shot, update, reset };
})();
function fireWeapon() {
  const w = curW(), st = wstate[Gun.cur];
  if (Gun.none || Gun.busy > 0 || Melee.on || player.stunT > 0 || Gun.switchT > 0 || Gun.reloadT > 0 || Gun.cooldown > 0) return;
  if (player.sprinting) player.sprintLock = 0.25;
  if (st.mag <= 0) { Sound.empty(); Gun.cooldown = 0.3; if (st.reserve > 0) startReload(); else HUD.hint('탄약 없음 · 상점에서 채우거나 다른 총으로', 2); return; }
  st.mag--; Gun.cooldown = w.rate; stats.shots++;
  if (w.heat) Heat.shot(w, st);
  Enemies.noise(camera.position, (Game.stage === 2 ? 30 : Game.stage === 3 || Game.stage === 8 ? 55 : Game.stage === 7 ? 45 : 42) * (w.noise || 1)); // a suppressor carries less far
  const spr = currentSpread();
  muzzleWorld(_muz);
  if (lookMode === 'touch' && !w.grenade && !w.rocket) {
    const ad = Enemies.assist(camera.position, _fwd, Gun.ads > 0.5 ? 0.03 : 0.045, w.range);
    if (ad) _fwd.copy(ad);
  }
  let hitAny = false, killed = false, head = false;
  if (w.grenade) {
    const a = rand(0, TAU), rr = Math.sqrt(Math.random()) * spr;
    _dir.copy(_fwd).addScaledVector(_right, Math.cos(a) * rr).addScaledVector(_up, Math.sin(a) * rr + 0.05).normalize();
    Proj.grenade(_muz, _dir, w);
  } else if (w.rocket) {
    // the rocket takes the enemy nearest the crosshair with it (the red diamond); with nothing marked it flies straight
    const tgt = rocketLock();
    _dir.copy(_fwd).addScaledVector(_up, 0.01).normalize();
    Proj.rocket(_muz, _dir, w, tgt);
  } else for (let k = 0; k < w.pellets; k++) {
    const a = rand(0, TAU), rr = Math.sqrt(Math.random()) * spr;
    _dir.copy(_fwd).addScaledVector(_right, Math.cos(a) * rr).addScaledVector(_up, Math.sin(a) * rr).normalize();
    const o = camera.position;
    const sHit = raycastStatic(o.x, o.y, o.z, _dir.x, _dir.y, _dir.z, w.range);
    const sT = RH.t, nx = RH.nx, ny = RH.ny, nz = RH.nz, sBox = RH.box;
    const eh = Enemies.raycast(o, _dir, sT);
    if (eh) {
      _hitP.copy(o).addScaledVector(_dir, eh.t);
      let dmg = w.dmg * (eh.weak ? (eh.enemy.T.headX || w.head) : eh.mult); // a giraffe's head takes ten times
      if (w.falloff) dmg *= lerp(1, 0.35, clamp((eh.t - w.falloff[0]) / (w.falloff[1] - w.falloff[0]), 0, 1));
      const weak = eh.weak;
      if (eh.bomb && eh.enemy.alive) { Enemies.blowVest(eh.enemy, _dir); killed = true; } // the chest bomb: one hit sets it off
      else if (Enemies.damage(eh.enemy, dmg, _hitP, _dir, weak)) killed = true;
      hitAny = true; if (weak) head = true;
      if (k < 3) FX.tracer(_muz, _hitP);
    } else {
      _hitP.copy(o).addScaledVector(_dir, sT);
      if (sHit) {
        if (sBox && sBox.kind === 'wood' && sBox.ref) damageCrate(sBox.ref, w.dmg, _hitP);
        if (k < 4) {
          FX.sparks(_hitP, sBox && sBox.kind === 'metal' ? 6 : 3, sBox && sBox.kind === 'wood' ? [0.9, 0.7, 0.45] : [1, 0.78, 0.45], 3.2);
          FX.puff(_hitP, 1, sBox && sBox.kind === 'concrete' ? 0.5 : 0.3, 0.25);
          if (sBox && sBox.kind === 'metal' && Math.random() < 0.5) Sound.metal(_hitP);
        }
        FX.decal(_hitP, { x: nx, y: ny, z: nz });
      }
      if (k < 3) FX.tracer(_muz, _hitP);
    }
  }
  if (hitAny) { stats.hits++; HUD.hitmark(killed, head); }
  const rk = w.recoil * (1 - Gun.ads * 0.35);
  player.recoilPitch += rk; player.pitch += rk * 0.55; player.yaw += rand(-1, 1) * rk * 0.35;
  Gun.kickZ += w.kick; Gun.kickRot += w.kick * 1.6; Gun.bloom = Math.min(Gun.bloom + w.bloom, 0.05);
  Gun.flashT = 0.045; FX.muzzle(_muz, w.flash); viewFlash.intensity = 1.4;
  // aiming down sights: no flash card or smoke on the line of sight, so the target stays visible
  const fl = gunModels[Gun.cur].userData.flash; fl.visible = Gun.ads < 0.5; fl.rotation.z = rand(0, TAU); fl.scale.setScalar(rand(0.8, 1.25) * (w.pellets > 1 ? 1.5 : 1));
  if (Gun.ads < 0.5) FX.glow.emit({ x: _muz.x, y: _muz.y, z: _muz.z, vx: _fwd.x * 2, vy: _fwd.y * 2 + 0.4, vz: _fwd.z * 2, max: 0.5, s0: 0.05, s1: 0.18, r: 0.35, g: 0.33, b: 0.32, a: 0.35, grav: -0.5, drag: 3 });
  Sound.shot(w.sound);
  if (w.pellets > 1 || w.scope) setTimeout(() => { if (state === 'playing') Sound.pump(); }, w.scope ? 520 : 280);
  if (st.mag === 0 && st.reserve > 0) setTimeout(() => { if (state === 'playing' && wstate[Gun.cur] === st && st.mag === 0) startReload(); }, 260);
  player.shake = Math.max(player.shake, w.pellets > 1 || w.scope ? 0.18 : 0.05);
}
function startReload() {
  const w = curW(), st = wstate[Gun.cur];
  if (w.heat && st.hot) { HUD.hint('기관총이 과열됐습니다 · 다른 총으로 바꾼 뒤에 재장전하세요', 2); return; }
  if (Gun.none || Gun.busy > 0 || Melee.on || player.stunT > 0 || Gun.reloadT > 0 || Gun.switchT > 0 || st.mag >= w.mag || st.reserve <= 0) return;
  Gun.reloadT = w.reload; Gun.reloadHalf = false; Sound.reload(0);
}
function finishReload() {
  const w = curW(), st = wstate[Gun.cur];
  const take = Math.min(w.mag - st.mag, st.reserve);
  st.mag += take; if (st.reserve !== Infinity) st.reserve -= take;
}
function switchTo(id) {
  if (!Gun.slots.includes(id) || id === Gun.cur || Gun.switchT > 0 || Gun.busy > 0 || player.stunT > 0) return;
  Gun.reloadT = 0; Gun.pending = id; Gun.switchT = 0.36; Sound.reload(0);
}
function switchWeapon(i) { const id = Gun.loadout[i]; if (id) switchTo(id); }
function cycleWeapon(step) {
  const n = Gun.slots.length; if (n < 2) return;
  const at = Gun.slots.indexOf(Gun.pending || Gun.cur);
  switchTo(Gun.slots[(at + step + n) % n]);
}
const scopeEl = $('scope');
function updateGun(dt, mdx, mdy) {
  const w = curW();
  Melee.autoCrate(); Melee.update(dt); Heat.update(dt); if (typeof LaserDot !== 'undefined') LaserDot.update();
  Gun.cooldown = Math.max(0, Gun.cooldown - dt);
  Gun.bloom = Math.max(0, Gun.bloom - dt * (Gun.trigger && w.auto ? 0.02 : 0.09));
  if (lookMode === 'touch' && settings.autoFire && !w.grenade && !w.rocket && !Gun.trigger && Gun.cooldown <= 0 && Gun.reloadT <= 0 && Gun.switchT <= 0 && wstate[Gun.cur].mag > 0 && !player.sprinting) {
    camera.getWorldDirection(_fwd);
    const o = camera.position, reach = w.falloff ? w.falloff[1] : Math.min(w.range, 70);
    raycastStatic(o.x, o.y, o.z, _fwd.x, _fwd.y, _fwd.z, reach);
    // auto-fire leaves alone what never fights you: the lab's zebras and animals you have tamed (you can still shoot them yourself)
    Enemies.skipCalm = true; const sees = Enemies.raycast(o, _fwd, RH.t) || Enemies.assist(o, _fwd, 0.035, reach); Enemies.skipCalm = false;
    if (sees) fireWeapon();
  }
  if (Gun.trigger && (w.auto || Gun.triggerEdge)) { fireWeapon(); Gun.triggerEdge = false; }
  if (Gun.reloadT > 0) {
    Gun.reloadT -= dt;
    if (!Gun.reloadHalf && Gun.reloadT < w.reload * 0.45) { Gun.reloadHalf = true; Sound.reload(1); }
    if (Gun.reloadT <= 0) { Gun.reloadT = 0; finishReload(); }
  }
  if (Gun.switchT > 0) {
    const before = Gun.switchT; Gun.switchT -= dt;
    if (before > 0.18 && Gun.switchT <= 0.18 && Gun.pending) {
      gunModels[Gun.cur].visible = false; Gun.cur = Gun.pending; Gun.pending = null; gunModels[Gun.cur].visible = true; Gun.cooldown = 0.1;
    }
    if (Gun.switchT < 0) Gun.switchT = 0;
  }
  const W = curW();
  const wantAds = Gun.adsHeld && Gun.reloadT <= 0 && Gun.switchT <= 0 && !player.sprinting && Gun.busy <= 0 && !Melee.on && !(player.stunT > 0);
  const as = W.adsSpeed || 7; // a light SMG comes up to the eye fast, the heavy machine gun slowly
  Gun.ads = clamp(Gun.ads + (wantAds ? dt * as : -dt * as), 0, 1);
  const a = Gun.ads * Gun.ads * (3 - 2 * Gun.ads);
  const fov = lerp(baseFov, W.adsFov * (W.scope ? 1 : baseFov / BASE_FOV), a);
  if (Math.abs(camera.fov - fov) > 0.01) { camera.fov = fov; camera.updateProjectionMatrix(); FX.resize(); }
  const scoped = W.scope && Gun.ads > 0.6;
  scopeEl.style.opacity = scoped ? String(clamp((Gun.ads - 0.6) * 4, 0, 1)) : '0';
  const g = gunModels[Gun.cur];
  g.visible = !scoped && !Gun.none;
  Gun.kickZ *= Math.exp(-dt * 14); Gun.kickRot *= Math.exp(-dt * 12);
  Gun.swayX = clamp(lerp(Gun.swayX, -mdx * 0.0006, 1 - Math.exp(-dt * 10)), -0.04, 0.04);
  Gun.swayY = clamp(lerp(Gun.swayY, mdy * 0.0006, 1 - Math.exp(-dt * 10)), -0.04, 0.04);
  const bobAmt = clamp(player.speedXZ / 6, 0, 1.4) * (player.grounded ? 1 : 0.2) * (1 - a * 0.85);
  const ph = player.stepPhase, sprint = player.sprintBlend;
  viewRoot.position.lerpVectors(HIP[Gun.cur], ADSP[Gun.cur], a);
  viewRoot.position.x *= lerp(hipScale, 1, a);
  viewRoot.position.x += Math.sin(ph) * 0.012 * bobAmt + Gun.swayX * (1 - a * 0.7) + sprint * 0.04;
  viewRoot.position.y += -Math.abs(Math.cos(ph)) * 0.012 * bobAmt + Gun.swayY * (1 - a * 0.7) - sprint * 0.05 + player.landDip * 0.4;
  viewRoot.position.z += Gun.kickZ * (1 - a * 0.5);
  viewRoot.rotation.set(Gun.kickRot * (1 - a * 0.5) - sprint * 0.35, sprint * 0.55 + Gun.swayX * 2, Math.sin(ph) * 0.01 * bobAmt);
  if (Gun.reloadT > 0) { const t = 1 - Gun.reloadT / W.reload, c = Math.sin(t * Math.PI); viewRoot.rotation.x -= c * 0.5; viewRoot.rotation.z += c * 0.6; viewRoot.position.y -= c * 0.06; }
  if (Gun.switchT > 0) { const t = Gun.switchT / 0.36, c = Math.sin(t * Math.PI); viewRoot.position.y -= c * 0.3; viewRoot.rotation.x -= c * 0.6; }
  Melee.pose(viewRoot);
  if (g.userData.tip) g.userData.tip.visible = wstate[Gun.cur].mag > 0; // the rocket's nose shows while one is loaded
  const low = Inject.lower; if (low > 0) { viewRoot.position.y -= low * 0.42; viewRoot.position.x += low * 0.08; viewRoot.rotation.x -= low * 0.8; } // gun out of the way for the needle
  if (Gun.flashT > 0) { Gun.flashT -= dt; if (Gun.flashT <= 0) g.userData.flash.visible = false; }
  viewFlash.intensity *= Math.exp(-dt * 30);
  // the world zooms when aiming, the gun in your hands does not, so it covers less of the target
  viewCam.fov = portrait ? 70 : 60; viewCam.updateProjectionMatrix();
}
/* which guns you may carry this stage: the pistol, guns you own for good (from boss chests), what you rented, or everything in developer mode */
function gunAvailable(id) { return id === 'pistol' || settings.dev || save.owned.includes(id) || save.rented.includes(id) || (typeof Game !== 'undefined' && Game.bonusGuns.includes(id)); }
/* keys 1-7 follow your layout; a slot whose gun you do not have this stage stays empty */
function applyLoadout() {
  Gun.loadout = save.loadout.map((id) => (id && gunAvailable(id) ? id : null));
  Gun.slots = Gun.loadout.filter(Boolean);
  Gun.none = Gun.slots.length === 0;
  if (!Gun.none && !Gun.slots.includes(Gun.cur)) {
    gunModels[Gun.cur].visible = false; Gun.cur = Gun.slots[0]; Gun.pending = null; Gun.switchT = 0; Gun.reloadT = 0;
    gunModels[Gun.cur].visible = state === 'playing' || state === 'paused';
  }
  HUD.buildSlots();
}
/* refill every gun and take the first one in your layout at the start of a stage */
function resetGuns() {
  ORDER.forEach((id) => { wstate[id].mag = WEAPONS[id].mag; wstate[id].reserve = WEAPONS[id].reserve; });
  Object.keys(gunModels).forEach((id) => { gunModels[id].visible = false; gunModels[id].userData.flash.visible = false; });
  Object.assign(Gun, { cooldown: 0, reloadT: 0, switchT: 0, pending: null, ads: 0, adsHeld: false, bloom: 0, kickZ: 0, kickRot: 0, flashT: 0, trigger: false, triggerEdge: false }); Melee.reset(); Heat.reset();
  Gun.loadout = save.loadout.map((id) => (id && gunAvailable(id) ? id : null));
  Gun.slots = Gun.loadout.filter(Boolean); Gun.none = Gun.slots.length === 0;
  Gun.cur = Gun.slots[0] || 'pistol';
  gunModels[Gun.cur].visible = !Gun.none; scopeEl.style.opacity = '0';
  HUD.buildSlots();
}
/* a gun rented (or found) in the middle of a stage joins with full ammo */
function gainGun(id) {
  wstate[id].mag = WEAPONS[id].mag; wstate[id].reserve = WEAPONS[id].reserve;
  const wasNone = Gun.none;
  applyLoadout();
  if (wasNone && !Gun.none) gunModels[Gun.cur].visible = true;
}

/* ============ antidote injection: lower the gun, needle into the forearm, push the plunger; no shooting meanwhile ============ */
const Inject = (() => {
  const DUR = 1.35, CURE_AT = 0.82;
  const root = new THREE.Group(); root.visible = false; viewScene.add(root);
  const sleeve = new THREE.MeshStandardMaterial({ color: 0x222a37, roughness: 0.95 });
  const glove = new THREE.MeshStandardMaterial({ color: 0x26292e, roughness: 0.9 });
  const skin = new THREE.MeshStandardMaterial({ color: 0xc99a7a, roughness: 0.8 });
  const glass = new THREE.MeshStandardMaterial({ color: 0xdfe8ee, roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.45 });
  const juice = new THREE.MeshBasicMaterial({ color: 0x58ff7a });
  const steel = new THREE.MeshStandardMaterial({ color: 0xc9ced6, roughness: 0.25, metalness: 0.8 });
  const white = new THREE.MeshStandardMaterial({ color: 0xf0f0ea, roughness: 0.6 });
  const box = (p, w, h, d, m, x, y, z) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); p.add(o); return o; };
  const cyl = (p, r, l, m, x, y, z) => { const o = new THREE.Mesh(new THREE.CylinderGeometry(r, r, l, 14), m); o.rotation.z = Math.PI / 2; o.position.set(x, y, z); p.add(o); return o; };
  // the left forearm, held across the bottom of the view with the sleeve pushed up
  const arm = new THREE.Group(); root.add(arm);
  box(arm, 0.24, 0.058, 0.062, sleeve, -0.13, 0, 0); box(arm, 0.13, 0.048, 0.052, skin, 0.055, 0.001, 0); box(arm, 0.055, 0.06, 0.066, glove, 0.145, 0, 0);
  box(arm, 0.012, 0.062, 0.066, sleeve, -0.006, 0, 0); // rolled-up cuff
  // the syringe in the right hand, needle pointing left at the bare forearm
  const syr = new THREE.Group(); root.add(syr);
  cyl(syr, 0.016, 0.13, glass, 0, 0, 0);
  const liquid = cyl(syr, 0.012, 0.12, juice, 0.002, 0, 0);
  cyl(syr, 0.0025, 0.06, steel, -0.095, 0, 0); cyl(syr, 0.02, 0.008, white, 0.066, 0, 0);
  const plunger = new THREE.Group(); syr.add(plunger);
  cyl(plunger, 0.005, 0.09, white, 0.11, 0, 0); cyl(plunger, 0.018, 0.008, white, 0.156, 0, 0);
  box(syr, 0.06, 0.07, 0.07, glove, 0.05, -0.04, 0.01);
  root.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
  let t = 0, active = false, cured = false;
  const smooth = (a, b, x) => { const k = clamp((x - a) / (b - a), 0, 1); return k * k * (3 - 2 * k); };
  return {
    get active() { return active; },
    /* how far the gun is lowered, 0..1 */
    get lower() { return active ? smooth(0, 0.28, t) * (1 - smooth(DUR - 0.3, DUR, t)) : 0; },
    start() {
      active = true; t = 0; cured = false; root.visible = true;
      Gun.busy = DUR; Gun.trigger = false; Gun.adsHeld = false; Gun.reloadT = 0;
      setTimeout(() => { if (active) Sound.inject(); }, 300);
    },
    cancel() { active = false; root.visible = false; Gun.busy = 0; },
    update(dt) {
      if (!active) return;
      t += dt; Gun.busy = Math.max(0, DUR - t);
      if (!cured && t >= CURE_AT) { cured = true; Game.cure(); Sound.cured(); }
      if (t >= DUR) { active = false; root.visible = false; Gun.busy = 0; return; }
      const up = smooth(0.05, 0.35, t) * (1 - smooth(DUR - 0.28, DUR, t)); // both hands come up, then go back down
      const wide = portrait ? 0.8 : 1, low = (1 - up) * 0.2;
      // left forearm across the lower middle, wrist towards the right, inner side up
      arm.position.set(-0.035 * wide, -0.17 - low, -0.5); arm.rotation.set(0.55, 0.42, 0.2);
      const stab = smooth(0.36, 0.48, t) * (1 - smooth(0.92, 1.05, t)); // needle goes in, comes back out
      const push = smooth(0.5, 0.82, t);                                 // plunger goes down
      // right hand comes in from the right, needle angled down onto the bare forearm
      syr.position.set((0.135 - stab * 0.03) * wide, -0.1 - low - stab * 0.022, -0.47); syr.rotation.set(0.1, 0.35, -0.62);
      plunger.position.x = -push * 0.062;
      liquid.scale.y = Math.max(0.04, 1 - push); liquid.position.x = 0.002 - push * 0.058;
    },
  };
})();
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

/* ============ enemies: people with pistols (stage 1) and zombies (stage 2); animals live in 07c ============ */
const ETYPES = {
  thug: { hp: 100, speed: 3.6, r: 0.35, h: 1.8, name: '조직원' },
  zombie: { hp: 180, speed: 1.6, r: 0.35, h: 1.8, name: '좀비' },
};
/* far away an enemy is drawn as one baked mesh in its rest pose instead of five moving parts */
function bakeFar(e) {
  e.g.updateMatrixWorld(true);
  const geos = [];
  e.g.traverse((o) => { if (o.isMesh && o.geometry.attributes.color) { const c = o.geometry.clone(); c.applyMatrix4(o.matrixWorld); geos.push(c); } });
  e.far = new THREE.Mesh(AnimalKit.merge(geos), e.mats[0]); e.far.visible = false; e.g.add(e.far); e.isFar = false;
}
function setFar(e, far) {
  e.isFar = far;
  for (const c of e.g.children) c.visible = c === e.far ? far : !far;
}
/* what an armed man carries: the gun in his right hand (boxes laid along the arm, so it points forward when he aims) and how he fights.
   range: starts a fight inside it; near/far: the distance he tries to keep; end: how far the muzzle sits from the shoulder */
const KITS = {
  pistol: { name: '권총', gun: [[0.045, 0.1, 0.18, 0, -0.66, 0.06, '#1d2024']], range: 32, near: 8, far: 20, end: 0.62 },
  // a gold-plated desert eagle (drawn with a gleaming gold material, not just a yellow tint)
  deagle: { name: '데저트 이글', gun: [[0.06, 0.3, 0.12, 0, -0.78, 0.02, '#d9a531'], [0.05, 0.08, 0.07, 0, -0.64, -0.04, '#b8861e']], range: 34, near: 7, far: 18, end: 0.95, gold: true },
  // a combat knife: grip, guard and a short steel blade; he runs you down and stabs, fast
  dagger: { name: '단검', gun: [[0.04, 0.13, 0.045, 0, -0.66, 0.03, '#2a1e16'], [0.035, 0.035, 0.11, 0, -0.73, 0.03, '#8a8f98'], [0.018, 0.27, 0.05, 0, -0.88, 0.03, '#d6dbe3']], range: 60, near: 0, far: 0, end: 0.8, melee: true, knife: true, run: 5.2 },
  // nothing in his hands, only the bomb on his chest: he runs at you, lights the fuse when close, and the vest also goes off if he is shot
  bomber: { name: '자폭맨', gun: [], range: 80, near: 0, far: 0, end: 0.6, melee: true, vest: true, bomber: true, run: 6.2 },
  // a lightsaber in each hand, swinging one after the other
  saber2: { name: '쌍광선검', gun: [[0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc']], range: 60, near: 0, far: 0, end: 0.8, melee: true, blade: true, dual: true, run: 4.6 },
  // an aluminium baseball bat: grip, taper, barrel
  bat: { name: '야구방망이', gun: [[0.036, 0.26, 0.036, 0, -0.75, 0.03, '#26262a'], [0.05, 0.3, 0.05, 0, -1.03, 0.03, '#b9bec6'], [0.066, 0.34, 0.066, 0, -1.34, 0.03, '#d3d7dd'], [0.07, 0.03, 0.07, 0, -1.52, 0.03, '#9ea3ab']], range: 50, near: 0, far: 0, end: 0.8, melee: true, bat: true, run: 4.5 },
  smg: { name: '기관단총', gun: [[0.06, 0.46, 0.12, 0, -0.84, 0.03, '#24272c'], [0.04, 0.06, 0.16, 0, -0.8, -0.08, '#1b1d20']], range: 30, near: 6, far: 14, end: 1.07 },
  rifle: { name: '돌격소총', gun: [[0.06, 0.8, 0.12, 0, -0.98, 0.03, '#2b2f26'], [0.05, 0.06, 0.18, 0, -0.86, -0.09, '#1b1d20']], range: 40, near: 8, far: 22, end: 1.38 },
  sniper: { name: '저격총', gun: [[0.05, 1.12, 0.09, 0, -1.12, 0.03, '#2a2e24'], [0.06, 0.26, 0.06, 0, -0.86, -0.07, '#111111']], range: 95, near: 0, far: 0, end: 1.68, still: true },
  shotgun: { name: '샷건', gun: [[0.07, 0.84, 0.11, 0, -1.0, 0.03, '#4a3424'], [0.06, 0.2, 0.07, 0, -1.05, 0.09, '#2a2a2a']], range: 18, near: 4, far: 9, end: 1.42 },
  gl: { name: '유탄발사기', gun: [[0.12, 0.58, 0.13, 0, -0.9, 0.03, '#3d4430'], [0.13, 0.2, 0.13, 0, -1.25, 0.03, '#2a2e24']], range: 45, near: 10, far: 28, end: 1.35 },
  nade: { name: '수류탄', gun: [[0.08, 0.1, 0.08, 0, -0.68, 0.03, '#3d4430']], range: 26, near: 9, far: 20, end: 0.62, belt: true },
  flame: { name: '화염방사기', gun: [[0.07, 0.74, 0.09, 0, -0.98, 0.03, '#3a3a3a'], [0.05, 0.1, 0.05, 0, -1.38, 0.03, '#8a5a2a']], range: 30, near: 2.5, far: 6.5, end: 1.45, tank: true },
  saber: { name: '광선검', gun: [[0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc']], range: 60, near: 0, far: 0, end: 0.8, melee: true, blade: true, run: 4.3 },
  lmg: { name: '기관총', gun: [[0.1, 0.98, 0.16, 0, -1.06, 0.03, '#2c2f28'], [0.14, 0.16, 0.12, 0, -0.8, -0.1, '#3d4430']], range: 45, near: 8, far: 24, end: 1.55 },
};
const saberMat = new THREE.MeshBasicMaterial({ color: 0xa8d4ff }), saberGlow = new THREE.MeshBasicMaterial({ color: 0x2a62ff, transparent: true, opacity: 0.42, blending: THREE.AdditiveBlending, depthWrite: false }); // blue
const goldGunMat = new THREE.MeshStandardMaterial({ color: 0xe2b23c, roughness: 0.22, metalness: 0.9, emissive: 0x4a3300, emissiveIntensity: 0.55 });
const saberMat2 = new THREE.MeshBasicMaterial({ color: 0xff8a8a }), saberGlow2 = new THREE.MeshBasicMaterial({ color: 0xff2a3a, transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false });
const vestLightMat = new THREE.MeshBasicMaterial({ color: 0xff2a1a });
/* 1-1's full-face motorcycle helmet: a glossy black shell, chin bar, a smoked visor; one shared model (geometry is marked shared so nobody disposes it) */
const MotoHelmet = (() => {
  let geo = null, mat = null;
  return {
    get geo() {
      if (!geo) {
        const B = AnimalKit.geoBox, blk = '#0d0e10', dk = '#1b1d21';
        geo = AnimalKit.merge([B(0.34, 0.31, 0.36, 0, 0.83, -0.005, blk), B(0.3, 0.07, 0.31, 0, 1.0, -0.015, blk), B(0.26, 0.04, 0.26, 0, 1.04, -0.02, blk),
          B(0.33, 0.12, 0.12, 0, 0.67, -0.12, blk), B(0.3, 0.11, 0.11, 0, 0.7, 0.14, blk), B(0.06, 0.04, 0.03, 0, 0.7, 0.2, dk),
          B(0.28, 0.13, 0.03, 0, 0.825, 0.18, '#3a4d60'), B(0.26, 0.018, 0.034, 0, 0.885, 0.183, '#c2d2e2'), B(0.2, 0.012, 0.034, -0.02, 0.79, 0.183, '#7f94a8'), B(0.3, 0.03, 0.05, 0, 0.9, 0.17, blk),
          B(0.02, 0.06, 0.06, -0.173, 0.83, 0.07, '#3a3d42'), B(0.02, 0.06, 0.06, 0.173, 0.83, 0.07, '#3a3d42'), B(0.09, 0.03, 0.07, 0, 1.06, 0.07, dk),
          B(0.3, 0.05, 0.3, 0, 0.655, 0, '#121316')]);
        geo.userData.shared = true;
      }
      return geo;
    },
    get mat() { return mat || (mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.18, metalness: 0.35, emissive: 0x000000 })); },
  };
})();
const Enemies = (() => {
  const list = [], dying = [];
  const JACKETS = ['#2b3440', '#3d4a33', '#4a3b30', '#2e2e34', '#5a5248', '#283a4a', '#47302e'];
  const SKIN = ['#c99a7a', '#a8775a', '#e0b895', '#7d5a44'];
  const ROT = ['#7d8f6a', '#6f7f63', '#8a9a7a', '#75806a'];
  const RAGS = ['#3b3a35', '#4a4038', '#2f3536', '#534a3f', '#3e4a4c'];
  const barBg = new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.7 });
  const barGeo = new THREE.PlaneGeometry(1, 1);
  const shadows = !isTouch;
  /* one person = 5 draws: merged torso and head, two arms (gun in the right hand), two legs */
  function build(type, opts) {
    opts = opts || {};
    const B = AnimalKit.geoBox, M = AnimalKit.merge, zombie = type === 'zombie', kit = !zombie ? KITS[opts.kit] || KITS.pistol : null;
    const body = zombie ? pick(RAGS) : pick(JACKETS), skin = zombie ? pick(ROT) : pick(SKIN), pants = zombie ? '#2c2c2a' : '#22252b';
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85, emissive: 0x000000 });
    const g = new THREE.Group(); g.rotation.order = 'YXZ';
    const e = { type, T: ETYPES[type], g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(0.2, 1.42, 0.62) };
    const mesh = (parent, geo) => { const m = new THREE.Mesh(geo, mat); m.castShadow = shadows; parent.add(m); return m; };
    e.legL = new THREE.Group(); e.legL.position.set(-0.11, 0.92, 0); g.add(e.legL); mesh(e.legL, M([B(0.15, 0.9, 0.17, 0, -0.45, 0, pants), B(0.16, 0.09, 0.27, 0, -0.88, 0.05, '#161616')]));
    e.legR = new THREE.Group(); e.legR.position.set(0.11, 0.92, 0); g.add(e.legR); mesh(e.legR, M([B(0.15, 0.9, 0.17, 0, -0.45, 0, pants), B(0.16, 0.09, 0.27, 0, -0.88, 0.05, '#161616')]));
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.92, 0); g.add(e.upper);
    const up = [B(0.44, 0.62, 0.26, 0, 0.36, 0, body), B(0.22, 0.25, 0.24, 0, 0.8, 0.01, skin)];
    if (zombie) up.push(B(0.035, 0.025, 0.01, -0.05, 0.82, 0.13, '#fff0a0'), B(0.035, 0.025, 0.01, 0.05, 0.82, 0.13, '#fff0a0'));
    else up.push(B(0.24, 0.08, 0.26, 0, 0.94, 0, pants));
    if (kit && kit.vest) up.push(B(0.42, 0.28, 0.07, 0, 0.42, 0.15, '#5b4a2c'), B(0.07, 0.22, 0.05, -0.13, 0.42, 0.2, '#8a3a24'), B(0.07, 0.22, 0.05, 0, 0.42, 0.2, '#8a3a24'), B(0.07, 0.22, 0.05, 0.13, 0.42, 0.2, '#8a3a24'), B(0.36, 0.02, 0.02, 0, 0.53, 0.21, '#d8c040'));
    if (kit && kit.tank) up.push(B(0.13, 0.46, 0.13, -0.09, 0.42, -0.21, '#8a2a1e'), B(0.13, 0.46, 0.13, 0.09, 0.42, -0.21, '#8a2a1e'), B(0.03, 0.3, 0.03, 0.2, 0.3, -0.12, '#2a2a2a'));
    if (kit && kit.belt) for (let i = 0; i < 4; i++) up.push(B(0.07, 0.08, 0.07, -0.15 + i * 0.1, 0.06, 0.15, '#3d4430'));
    mesh(e.upper, M(up));
    if (opts.helmet) {
      // a full-face motorcycle helmet: the first shot to the head knocks it off
      const hm = new THREE.Mesh(MotoHelmet.geo, MotoHelmet.mat); hm.castShadow = shadows; e.upper.add(hm); e.helmetMesh = hm; e.helmet = true;
    }
    e.armL = new THREE.Group(); e.armL.position.set(-0.29, 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)]));
    e.armR = new THREE.Group(); e.armR.position.set(0.29, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M(zombie || (kit && kit.gold) ? [B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)] : [B(0.12, 0.62, 0.13, 0, -0.29, 0, body), B(0.1, 0.1, 0.1, 0, -0.62, 0, skin)].concat(kit.gun.map((q) => B(q[0], q[1], q[2], q[3], q[4], q[5], q[6])))));
    if (kit && kit.gold) { const gm = new THREE.Mesh(M(kit.gun.map((q) => B(q[0], q[1], q[2], q[3], q[4], q[5], q[6]))), goldGunMat); gm.castShadow = shadows; e.armR.add(gm); }
    if (kit) { e.kit = opts.kit && KITS[opts.kit] ? opts.kit : 'pistol'; e.K = kit; e.muzzle.set(0.2, 1.42, kit.end); }
    if (kit && kit.blade) {
      // a glowing blade on the hilt, with a soft halo round it; two red ones for the dual wielders
      const arms = kit.dual ? [e.armR, e.armL] : [e.armR], bm = kit.dual ? saberMat2 : saberMat, gm = kit.dual ? saberGlow2 : saberGlow;
      if (kit.dual) mesh(e.armL, M([B(0.05, 0.2, 0.05, 0, -0.7, 0.03, '#bfc4cc')]));
      for (const a of arms) {
        const blade = new THREE.Mesh(new THREE.BoxGeometry(0.035, 1.15, 0.035), bm); blade.position.set(0, -1.38, 0.03); a.add(blade);
        const halo = new THREE.Mesh(new THREE.BoxGeometry(0.09, 1.22, 0.09), gm); halo.position.copy(blade.position); a.add(halo); if (!e.blade) e.blade = blade;
      }
    }
    if (kit && kit.vest) { const l = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.05, 0.03), vestLightMat); l.position.set(0.11, 0.53 + 0.92, 0.215); g.add(l); e.vestLight = l; }
    e.parts = [
      { o: new THREE.Vector3(0, 1.72, 0.01), r: 0.15, mult: 1, weak: true },
      { o: new THREE.Vector3(0, 1.3, 0), r: 0.3, mult: 1 },
      { o: new THREE.Vector3(0, 0.95, 0), r: 0.22, mult: 0.9 },
      { o: new THREE.Vector3(0, 0.48, 0), r: 0.24, mult: 0.7 },
    ];
    // the bomb strapped to a bomber's chest: one bullet in it and it goes off
    if (kit && kit.vest) e.parts.splice(1, 0, { o: new THREE.Vector3(0, 1.34, 0.18), r: 0.2, mult: 1, bomb: true });
    const bar = new THREE.Group(); const bg = new THREE.Mesh(barGeo, barBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
    const fill = new THREE.Mesh(barGeo, new THREE.MeshBasicMaterial({ color: zombie ? 0x9be88f : 0xff5260 })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
    bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
    bakeFar(e);
    return e;
  }
  /* boss: same kind, built fresh, scaled up and much tougher */
  /* how hard each body shoves when you are pressed together; heavy animals push you, people give way */
  const MASS = { thug: 1, zombie: 1.3, zebra: 2.5, puma: 1.4, lion: 2.2, tiger: 2.4, buffalo: 4, gorilla: 3, hippo: 7, rhino: 7, elephant: 12, cheetah: 1.5, giraffe: 5, lionM: 2.5,
    trooper: 1.5, heavy: 4, crawler: 1.2, drone: 0.5, turret: 60, mech: 25 };
  const _fb = new THREE.Box3();
  /* the body's outline seen from above, in its own frame (x = right, z = forward), measured from the mesh */
  function footprint(e, sc) {
    e.g.position.set(0, 0, 0); e.g.rotation.set(0, 0, 0); e.g.scale.setScalar(1); e.g.updateMatrixWorld(true);
    _fb.setFromObject(e.g);
    const pad = 0.05;
    e.foot = { x0: (_fb.min.x - pad) * sc, x1: (_fb.max.x + pad) * sc, z0: (_fb.min.z - pad) * sc, z1: (_fb.max.z + pad) * sc };
    if (!e.animal) e.foot.z1 = Math.max(e.foot.z1, 0.52 * sc); // people and zombies reach out with their arms
    e.footR = Math.hypot(Math.max(-e.foot.x0, e.foot.x1), Math.max(-e.foot.z0, e.foot.z1));
  }
  function spawn(type, x, z, opts) {
    opts = opts || {};
    const e = ANIMALS[type] ? buildAnimal(type, opts) : typeof ROBOTS !== 'undefined' && ROBOTS[type] ? buildRobot(type, opts) : build(type, opts);
    const T = e.T, sc = opts.scale || 1;
    footprint(e, sc); e.mass = opts.kong && opts.boss ? 40 : (MASS[type] || 1) * (opts.boss ? 2 : 1) * (sc > 1.05 ? sc : 1);
    e.boss = !!opts.boss; e.name = opts.name || T.name; e.scale = sc; e.R = T.r * sc; e.H = T.h * sc;
    e.hp = e.maxHp = Math.round(opts.hp || T.hp); e.diff = opts.diff || 0; e.dmgMul = opts.dmgMul || 1;
    e.speed = type === 'zombie' ? (opts.boss ? 1.7 : rand(1.25, 2.0)) : T.speed * rand(0.9, 1.1) * (opts.boss ? 0.9 : 1);
    e.alive = true; e.flashT = 0; e.deadT = 0; e.pos = e.g.position; e.pos.set(x, opts.y || 0, z); e.vel.set(0, 0, 0); e.vy = 0;
    e.yaw = opts.yaw !== undefined ? opts.yaw : rand(0, TAU); e.alert = false; e.lod = Math.random() * 0.5; e.awake = false; e.dist = 999;
    e.state = 'move'; e.stateT = 0; e.los = false; e.losT = Math.random() * 0.3; e.noLos = 0; e.react = 0;
    e.fireT = rand(0.8, 1.6); e.burst = 0; e.burstT = 0; e.strafe = Math.random() < 0.5 ? 1 : -1; e.strafeT = rand(1, 2.5);
    e.walk = rand(0, TAU); e.attackCd = 0; e.moanT = rand(1, 5); e.flinch = 0;
    e.g.rotation.set(0, e.yaw, 0); e.g.scale.setScalar(sc); if (e.upper) e.upper.rotation.set(type === 'zombie' ? 0.28 : 0, 0, 0);
    e.mats.forEach((m) => m.emissive && m.emissive.setRGB(0, 0, 0));
    if (e.animal) initAnimal(e);
    if (e.K && e.K.run) e.speed = Math.max(e.speed, e.K.run * 0.9); // melee men close the distance quickly even before they see you
    if (e.boss) { e.bar.scale.setScalar(1.6); }
    scene.add(e.g); list.push(e);
    return e;
  }
  const _c = new THREE.Vector3();
  function partCenter(e, p, out) {
    const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw), s = e.scale || 1;
    return out.set(e.pos.x + (p.o.x * cy + p.o.z * sy) * s, e.pos.y + p.o.y * s, e.pos.z + (-p.o.x * sy + p.o.z * cy) * s);
  }
  const RES = { enemy: null, t: 0, mult: 1, weak: false, bomb: false };
  function raycast(o, d, maxT) {
    let best = maxT, hit = null;
    for (const e of list) {
      if (!e.alive || e.ridden || (api.skipCalm && calm(e))) continue; // your own mount: shots go past it
      const dx = e.pos.x - o.x, dz = e.pos.z - o.z;
      if (dx * d.x + dz * d.z < -2 * (e.scale || 1)) continue;
      const s = e.scale || 1;
      for (const p of (e.downed ? e.downParts : e.parts)) {
        partCenter(e, p, _c);
        const ox = o.x - _c.x, oy = o.y - _c.y, oz = o.z - _c.z, pr = p.r * s;
        const b = ox * d.x + oy * d.y + oz * d.z, c = ox * ox + oy * oy + oz * oz - pr * pr, disc = b * b - c;
        if (disc < 0) continue;
        let t = -b - Math.sqrt(disc); if (t < 0) t = -b + Math.sqrt(disc);
        if (t > 0 && (t < best - 0.02 || (t < best + 0.02 && p.weak && hit === e && !RES.weak))) { best = t; hit = e; RES.mult = p.mult; RES.weak = !!p.weak; RES.bomb = !!p.bomb; }
      }
    }
    if (!hit) return null;
    RES.enemy = hit; RES.t = best; return RES;
  }
  const _best = new THREE.Vector3(), _ad = new THREE.Vector3();
  function assist(o, d, maxAng, maxDist) {
    let bestScore = Infinity, found = false;
    for (const e of list) {
      if (!e.alive || !e.g.visible || e.ridden || (api.skipCalm && calm(e))) continue;
      const s = e.scale || 1;
      for (const p of (e.downed ? e.downParts : e.parts)) {
        partCenter(e, p, _c);
        const dx = _c.x - o.x, dy = _c.y - o.y, dz = _c.z - o.z, dist = Math.hypot(dx, dy, dz);
        if (dist < 0.5 || dist > maxDist) continue;
        const cos = (dx * d.x + dy * d.y + dz * d.z) / dist;
        if (cos < 0.9) continue;
        const score = Math.acos(Math.min(1, cos)) - Math.atan(p.r * s / dist);
        if (score > maxAng || score >= bestScore) continue;
        if (score <= 0) return null;
        if (lineOfSight(o, _c)) { bestScore = score; _best.set(dx / dist, dy / dist, dz / dist); found = true; }
      }
    }
    return found ? _ad.copy(_best) : null;
  }
  /* wake an enemy up: it starts hunting you */
  function alarm(e) {
    if (e.alert || !e.alive || e.downed || e.sealed) return;
    e.alert = true;
    if (e.type === 'thug' || e.robot) { e.state = 'move'; e.react = Math.max(e.react, rand(0.4, 0.8)); }
    else if (e.type === 'zombie') { e.state = 'move'; if (e.dist < 30) Sound.moan(e.pos); }
  }
  /* gunfire carries: people and zombies within earshot come for you, animals react in their own way */
  function noise(p, r) {
    for (const e of list) {
      if (!e.alive) continue;
      const d = Math.hypot(e.pos.x - p.x, e.pos.z - p.z);
      if (d > r) continue;
      if (e.animal) hearAnimal(e, d); else alarm(e);
    }
  }
  function damage(e, dmg, point, dir, weak, quiet) {
    if (!e.alive) return false;
    // some take no damage for a moment, or only up to a point (the boss drone sheds a shell at each third of its health)
    if (e.guard) { dmg = e.guard(e, dmg); if (!(dmg > 0)) { FX.sparks(point, 6, [0.6, 0.85, 1], 3); Sound.metal(point); if (e.robot) alarm(e); return false; } }
    // a helmet takes the first shot to the head and flies off
    if (weak && e.helmet) { knockHelmet(e, point, dir); return false; }
    // a zombie lying on the ground: one more hit and the body is gone for good
    if (e.downed) { FX.puff(point, 6, 0.9, 0.6); FX.sparks(point, 10, [0.55, 0.85, 0.4], 3); Sound.squelch(e.pos); e.vanish = true; kill(e, weak, dir); return true; }
    e.hp -= dmg;
    if (quiet) { if (e.hp <= 0) { kill(e, false, dir); return true; } return false; } // bleeding: no spark, no sound, no flinch
    e.flashT = 0.08; e.flinch = 1;
    FX.sparks(point, weak ? 8 : 4, e.type === 'zombie' ? [0.6, 0.8, 0.45] : e.robot ? [1, 0.85, 0.45] : [0.9, 0.8, 0.7], e.robot ? 4 : 2.5);
    FX.puff(point, 1, e.type === 'zombie' ? 0.25 : 0.4, 0.25);
    if (weak) Sound.headshot(e.hp <= 0); else Sound.hit(false); if (e.robot) Sound.metal(point);
    if (!e.boss && !e.ridden) { e.vel.x += dir.x * 0.9; e.vel.z += dir.z * 0.9; }
    if (e.type === 'thug') { alarm(e); e.los = true; e.react = Math.min(e.react, 0.3); for (const o of list) if (o.type === 'thug' && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 18) alarm(o); }
    else if (e.type === 'zombie') alarm(e);
    else if (e.robot) { alarm(e); e.los = true; for (const o of list) if (o.robot && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 18) alarm(o); }
    if (e.animal) provokeAnimal(e);
    if (e.hp <= 0) { if (e.type === 'zombie') { down(e, dir); return false; } kill(e, weak, dir); return true; }
    return false;
  }
  const flying = [];
  const _hp = new THREE.Vector3();
  function knockHelmet(e, point, dir) {
    e.helmet = false;
    // the helmet leaves the head as a whole: same model, same place, then it tumbles away
    const hm = e.helmetMesh; hm.updateMatrixWorld(true); _hp.set(0, 0.84, 0).applyMatrix4(hm.matrixWorld); // the middle of the helmet, in the world
    e.upper.remove(hm); e.helmetMesh = null;
    if (e.far) { e.g.remove(e.far); e.far.geometry.dispose(); e.far = null; } bakeFar(e); setFar(e, !!e.isFar);
    // a pivot at its middle so it spins about itself as it tumbles
    const piv = new THREE.Group(); piv.position.copy(_hp); piv.rotation.set(0, e.yaw, 0); piv.scale.setScalar(e.scale || 1);
    const h = new THREE.Mesh(MotoHelmet.geo, MotoHelmet.mat); h.position.set(0, -0.84, 0); h.castShadow = !isTouch; piv.add(h); scene.add(piv);
    flying.push({ m: piv, vx: dir.x * 3 + rand(-1, 1), vy: rand(3, 4.5), vz: dir.z * 3 + rand(-1, 1), spin: rand(8, 14), t: 0, floor: 0.2 * (e.scale || 1) });
    FX.sparks(point, 10, [1, 0.9, 0.6], 3.5); Sound.ping(point); e.flinch = 1; e.flashT = 0.05;
    HUD.hitmark(false, false);
    if (!Game.helmetHint) { Game.helmetHint = true; HUD.hint('헬멧이 벗겨졌습니다 · 한 번 더 머리를 쏘세요', 2.6); }
    alarm(e);
  }
  /* zombies do not stay dead: they drop, and unless shot again within 3 seconds they get back up at full health */
  const REVIVE = 3;
  function down(e, dir) {
    e.downed = true; e.downT = 0; e.hp = 0; e.state = 'down'; e.vel.set(0, 0, 0); e.flinch = 0;
    e.fallDir = 1; if (dir) { const f = Math.sin(e.yaw) * dir.x + Math.cos(e.yaw) * dir.z; e.fallDir = f > 0 ? 1 : -1; }
    // where the body is once it lies flat, for bullets: along the fall direction, just off the ground
    e.downParts = e.parts.map((p) => ({ o: new THREE.Vector3(p.o.x, Math.max(0.16, p.o.y * 0.12 + 0.08), e.fallDir * p.o.y * 0.99), r: p.r * 1.05, mult: 1, weak: p.weak }));
    e.fill.material.color.setHex(0xf2a33a);
    Sound.thud(e.pos); Sound.moan(e.pos);
    if (!Game.downHint) { Game.downHint = true; HUD.hint('쓰러진 좀비는 3초 안에 한 번 더 쏴야 사라집니다 · 안 그러면 다시 일어납니다', 3.5); }
  }
  function updateDowned(e, dt) {
    e.downT += dt;
    const t = e.downT;
    if (t < REVIVE) {
      const k = Math.min(1, t / 0.45), ease = k * k * (3 - 2 * k);
      e.g.rotation.set(e.fallDir * ease * 1.45, e.yaw, t > REVIVE - 1 ? Math.sin(t * 38) * 0.06 : 0); // twitches before it rises
      e.legL.rotation.x = e.legR.rotation.x = 0; e.upper.rotation.x = 0;
    } else if (t < REVIVE + 0.7) {
      if (!e.rising) { e.rising = true; Sound.revive(e.pos); }
      const k = (t - REVIVE) / 0.7, ease = k * k * (3 - 2 * k);
      e.g.rotation.set(e.fallDir * (1 - ease) * 1.45, e.yaw, 0);
    } else {
      e.downed = false; e.rising = false; e.hp = e.maxHp; e.dashUsed = false; e.revived = true; // too late for the bonus e.state = 'move'; e.alert = true; e.chargeCd = 3;
      e.g.rotation.set(0, e.yaw, 0); e.fill.material.color.setHex(0x9be88f); e.bar.visible = false;
      if (e.boss) HUD.banner(e.name + ' 부활', '쓰러지면 3초 안에 한 번 더 쏘세요', 2.2);
      return;
    }
    // the bar above the body counts down to the moment it gets back up
    e.bar.visible = e.g.visible; e.bar.position.set(e.pos.x, e.pos.y + 0.7 * (e.scale || 1), e.pos.z); e.bar.quaternion.copy(camera.quaternion);
    const f = clamp(1 - t / REVIVE, 0, 1); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1 - f);
  }
  function kill(e, weak, dir) {
    e.alive = false; e.deadT = 0; e.bar.visible = false; e.g.visible = true; e.downed = false;
    if (e.laser) e.laser.visible = false;
    if (e.K && e.K.vest) { const now = e.selfDet || e.vestShot; Proj.bomb(e.pos, now ? 0.02 : 0.3); if (now) e.vanish = true; } // the vest goes off (at once if the bomb itself was hit)
    if (e.T && e.T.mode === 'mine') ShipFX.mineBlast(e.pos, e.selfDet ? 0 : 0.06); // a spider mine goes off: 100 to anyone close, other mines go with it
    if (e.robot) { const c = { x: e.pos.x, y: e.pos.y + (e.fly ? 0 : e.H * 0.5), z: e.pos.z }; FX.explode(c, !!e.boss, [0.6, 0.85, 1]); FX.chunks(c, e.boss ? 18 : 8, 0.16 * (e.scale || 1), 'metal'); Sound.boom(c, !!e.boss); e.vanish = true; }
    e.fallDir = e.type === 'zombie' ? 1 : -1; e.side = Math.random() < 0.5 ? 1 : -1;
    if (dir) { const f = Math.sin(e.yaw) * dir.x + Math.cos(e.yaw) * dir.z; e.fallDir = f > 0 ? 1 : -1; }
    const i = list.indexOf(e); if (i >= 0) list.splice(i, 1);
    dying.push(e);
    Sound.thud(e.pos); if (e.boss) Sound.boom(e.pos, false);
    Game.onKill(e, weak);
  }
  function splash(c, radius, dmg, skip) {
    for (const e of list.slice()) {
      if (e.ridden || e === skip) continue;
      const d = Math.hypot(e.pos.x - c.x, e.pos.y + 1 - c.y, e.pos.z - c.z);
      if (d > radius + e.R) continue;
      _c.set(e.pos.x, e.pos.y + e.H * 0.6, e.pos.z);
      if (!lineOfSight(c, _c)) continue;
      const k = 1 - Math.min(1, d / (radius + e.R));
      if (damage(e, dmg * (0.35 + 0.65 * k), _c, { x: (e.pos.x - c.x) / (d || 1), y: 0, z: (e.pos.z - c.z) / (d || 1) }, false)) HUD.hitmark(true, false);
    }
  }
  function updateDying(dt) {
    for (let i = flying.length - 1; i >= 0; i--) {
      const f = flying[i]; f.t += dt; f.vy -= 12 * dt;
      const fl = f.floor || 0.08;
      f.m.position.x += f.vx * dt; f.m.position.y = Math.max(fl, f.m.position.y + f.vy * dt); f.m.position.z += f.vz * dt; f.m.rotation.x += f.spin * dt; f.m.rotation.z += f.spin * 0.6 * dt;
      if (f.m.position.y <= fl) { f.vx *= 0.6; f.vz *= 0.6; f.vy = Math.abs(f.vy) * 0.25; f.spin *= 0.5; }
      if (f.t > 4) { scene.remove(f.m); flying.splice(i, 1); }
    }
    for (let i = dying.length - 1; i >= 0; i--) {
      const e = dying[i]; e.deadT += dt;
      const t = Math.min(1, e.deadT / 0.5), ease = t * t * (3 - 2 * t);
      if (e.vanish) { const s = Math.max(0.001, 1 - e.deadT / 0.45) * (e.scale || 1); e.g.scale.set(s, s * 0.6, s); e.pos.y -= dt * 0.8; if (e.deadT > 0.45) e.deadT = 99; }
      else if (e.animal) { e.g.rotation.set(0, e.yaw, e.side * ease * 1.5); if (e.deadT < 4.5) e.pos.y = Math.max(e.pos.y - dt * 2, 0); else e.pos.y -= dt * 0.5 * e.H; }
      else { e.g.rotation.set(e.fallDir * ease * 1.45, e.yaw, 0); if (e.deadT > 2.6) e.pos.y -= dt * 0.6; }
      if (e.deadT > (e.animal ? 6.5 : 3.4)) { scene.remove(e.g); dying.splice(i, 1); disposeEnemy(e); }
    }
  }
  /* a bomber who reaches you: his own vest, no money for you, but he counts as gone */
  function detonate(e) { if (!e.alive) return; e.selfDet = true; kill(e, false, null); }
  /* gone without a kill: the boss's leftover mines when it dies */
  function vanish(e) { if (!e.alive) return; e.alive = false; e.vanish = true; e.deadT = 0; e.bar.visible = false; const i = list.indexOf(e); if (i >= 0) list.splice(i, 1); dying.push(e); FX.puff(e.pos, 3, 0.3, 0.4); }
  function disposeEnemy(e) {
    if (e.laser) { scene.remove(e.laser); e.laser.geometry.dispose(); }
    e.g.traverse((o) => { if (o.isMesh && !o.geometry.userData.shared) o.geometry.dispose(); });
    e.mats.forEach((m) => m.dispose()); scene.remove(e.bar); e.fill.material.dispose();
  }
  function clear() {
    for (const e of list) { scene.remove(e.g); disposeEnemy(e); }
    for (const e of dying) { scene.remove(e.g); disposeEnemy(e); }
    for (const f of flying) scene.remove(f.m);
    list.length = 0; dying.length = 0; flying.length = 0;
  }
  /* never fights you: a loose zebra in the lab, or an animal you have ridden */
  function calm(e) { return e.tamed || (e.type === 'zebra' && e.fury); }
  /* a bullet in a bomber's chest bomb: it goes off there and then, and the kill is yours */
  function blowVest(e, dir) { if (!e.alive) return; e.vestShot = true; e.hp = 0; HUD.feed('자폭 조끼 명중 · 폭탄이 터졌습니다', 0, 'hs'); kill(e, false, dir); }
  const api = { list, spawn, raycast, assist, damage, splash, updateDying, updateDowned, clear, partCenter, alarm, noise, detonate, vanish, calm, blowVest, skipCalm: false };
  return api;
})();

/* ============ enemy AI, bullets and grenades, antidote pickups ============ */
const Proj = (() => {
  const list = [];
  const geo = new THREE.SphereGeometry(1, 8, 6);
  const bulletMat = new THREE.MeshBasicMaterial({ color: 0xffd9a0, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  const boltMat = new THREE.MeshBasicMaterial({ color: 0x6fe4ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
  const grenMat = new THREE.MeshStandardMaterial({ color: 0x3d4430, roughness: 0.6, metalness: 0.3 });
  const pool = [];
  function make(mat) { const p = pool.pop() || { m: new THREE.Mesh(geo, mat), vel: new THREE.Vector3(), src: new THREE.Vector3() }; p.m.material = mat; return p; }
  /* enemy pistol round: fast, visible tracer */
  function bullet(from, target, speed, dmg, spreadR, quiet, look) {
    const p = make(look === 'bolt' ? boltMat : bulletMat);
    p.kind = 'bullet'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.vel.set(target.x + rand(-1, 1) * spreadR - from.x, target.y + rand(-0.7, 0.7) * spreadR - from.y, target.z + rand(-1, 1) * spreadR - from.z).normalize().multiplyScalar(speed);
    p.dmg = dmg; p.life = 2; p.whiz = false;
    if (look === 'bolt') p.m.scale.set(0.06, 0.06, 0.9); else p.m.scale.set(0.03, 0.03, 0.55); p.m.lookAt(p.pos.x + p.vel.x, p.pos.y + p.vel.y, p.pos.z + p.vel.z);
    scene.add(p.m); list.push(p);
    if (!quiet) Sound.pistolFar(from);
    FX.glow.emit({ x: from.x, y: from.y, z: from.z, vx: 0, vy: 0, vz: 0, max: 0.08, s0: 0.45, s1: 0.1, r: 1, g: 0.8, b: 0.5, a: 0.9, grav: 0, drag: 0 });
  }
  /* enemy grenades: 'gl' rounds burst on impact, thrown 'nade's bounce and go off after a fuse; 'bomb' is a vest going off where a man fell */
  const eGrenMat = new THREE.MeshStandardMaterial({ color: 0x4a5236, roughness: 0.55, metalness: 0.35, emissive: 0x1a0a00 });
  function egrenade(from, target, mode) {
    const p = make(eGrenMat);
    p.kind = 'egren'; p.mode = mode; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    const dx = target.x - from.x, dz = target.z - from.z, d = Math.hypot(dx, dz), T = mode === 'gl' ? 0.55 + d / 30 : 0.8 + d / 20;
    p.vel.set(dx / T, (target.y - from.y + 0.5 * 9.8 * T * T) / T, dz / T);
    p.life = mode === 'gl' ? 6 : 2.7; p.fuse = 2.6; p.beeps = 0; p.m.scale.setScalar(mode === 'gl' ? 0.07 : 0.09); scene.add(p.m); list.push(p);
    Sound.thump(from);
  }
  function bomb(at, delay) {
    const p = make(eGrenMat); p.kind = 'bomb'; p.pos = p.m.position; p.pos.set(at.x, at.y + 1.0, at.z); p.src.copy(p.pos); p.life = delay; p.m.visible = false; p.vel.set(0, 0, 0);
    scene.add(p.m); list.push(p); Sound.beep(p.pos);
  }
  /* a blast from the enemy side: hurts you by distance, wrecks crates; the vest also takes other men with it */
  function blast(c, radius, dmg, hitsEnemies) {
    FX.explode(c, true); if (radius > 6) { FX.explode({ x: c.x + 0.8, y: c.y + 0.3, z: c.z - 0.5 }, true); FX.chunks(c, 10, 0.2, 'metal'); }
    Sound.boom(c, true); Enemies.noise(c, 50);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.9 - d * 0.04, 0, 0.9));
    if (d < radius && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 1.2, player.pos.z))) player.hurt(dmg * (1 - d / radius), c, 'body');
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    if (hitsEnemies) Enemies.splash(c, radius, dmg);
  }
  /* player's 40 mm grenade: arcs, arms after a few metres, explodes on impact */
  function grenade(from, dir, w) {
    const p = make(grenMat);
    p.kind = 'grenade'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.vel.copy(dir).multiplyScalar(40); p.dmg = w.dmg; p.radius = w.splash; p.life = 6; p.bounced = false;
    p.m.scale.setScalar(0.05); scene.add(p.m); list.push(p);
  }
  /* the player's guided rocket: a short straight boost, then it steers after the enemy it locked when fired (at most 3 rad a second),
     and bursts on whatever it touches: 1,000 to what it hit, and a 6 m blast (up to 500, less further out) round it */
  const rocketMat = new THREE.MeshStandardMaterial({ color: 0x59603f, roughness: 0.5, metalness: 0.4, emissive: 0x2a0d00 });
  function rocket(from, dir, w, target) {
    const p = make(rocketMat);
    p.kind = 'rocket'; p.pos = p.m.position; p.pos.copy(from); p.src.copy(from);
    p.speed = 24; p.vel.copy(dir).multiplyScalar(p.speed); p.dmg = w.dmg; p.radius = w.splash; p.splashDmg = w.splashDmg || w.dmg * 0.5; p.life = 7; p.age = 0; p.target = target || null;
    p.m.scale.set(0.055, 0.055, 0.32); p.m.lookAt(p.pos.x + dir.x, p.pos.y + dir.y, p.pos.z + dir.z); scene.add(p.m); list.push(p);
  }
  const _rc = new THREE.Vector3(), _rd = new THREE.Vector3();
  function rocketHit(p, e) {
    const c = p.pos;
    FX.explode(c, true); FX.explode({ x: c.x + 0.5, y: c.y + 0.4, z: c.z - 0.4 }, true); Sound.boom(c, true); Enemies.noise(c, 70);
    player.shake = Math.max(player.shake, clamp(0.7 - c.distanceTo(player.pos) * 0.02, 0, 0.7));
    if (e && e.alive) { _rd.copy(p.vel).normalize(); if (Enemies.damage(e, p.dmg, c, _rd, false)) HUD.hitmark(true, false); else HUD.hitmark(false, false); }
    Enemies.splash(c, p.radius, p.splashDmg, e);
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < p.radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    // 5.13: the blast does not spare you either. the same splash an enemy would take: 35-100% of 500 inside 6 m, nothing through a wall
    const pd = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z), pr = p.radius + player.r;
    if (pd < pr && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 0.9, player.pos.z))) player.hurt(Math.round(p.splashDmg * (0.35 + 0.65 * (1 - pd / pr))), c, 'body');
  }
  function rocketCentre(e, out) { return out.set(e.pos.x, e.pos.y + (e.fly ? 0 : e.H * 0.55), e.pos.z); }
  function explode(p) {
    const c = p.pos;
    FX.explode(c, true); Sound.boom(c, true); Enemies.noise(c, 60);
    player.shake = Math.max(player.shake, clamp(0.5 - c.distanceTo(player.pos) * 0.02, 0, 0.5));
    Enemies.splash(c, p.radius, p.dmg);
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < p.radius) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    if (d < p.radius && Game.stage === 1) player.hurt(p.dmg * 0.35 * (1 - d / p.radius), c, 'body');
  }
  const _t = new THREE.Vector3();
  function update(dt) {
    const hx = player.pos.x, hz = player.pos.z, hy0 = player.pos.y + 0.1, hy1 = player.pos.y + player.height;
    for (let i = list.length - 1; i >= 0; i--) {
      const p = list[i]; p.life -= dt;
      let dead = false;
      if (p.kind === 'bomb') { if (p.life <= 0) { blast(p.pos, 7, 300, true); dead = true; } }
      else if (p.kind === 'egren') {
        p.vel.y -= 9.8 * dt;
        for (let s = 0; s < 3 && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / 3);
          const near = Math.hypot(p.pos.x - hx, p.pos.y - (hy0 + 0.8), p.pos.z - hz) < 0.7;
          const hit = p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.06 || !!collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.06, 0.1) || near;
          if (hit && p.mode === 'gl') { blast(p.pos, 5.5, 120, false); dead = true; }
          else if (hit) { // a thrown grenade bounces and rolls
            const g = groundAt(p.pos.x, p.pos.y + 0.3, p.pos.z, 0.05); p.pos.y = Math.max(p.pos.y, g + 0.06);
            if (Math.abs(p.vel.y) > 1.2) Sound.metal(p.pos);
            p.vel.x *= 0.45; p.vel.z *= 0.45; p.vel.y = Math.abs(p.vel.y) * 0.3;
          }
        }
        if (!dead && p.mode === 'nade') {
          // three beeps, each with a red flash, then it goes off
          p.fuse -= dt; if (Math.random() < dt * 6) FX.sparks(p.pos, 1, [1, 0.4, 0.2], 0.6);
          if (p.beeps < 3 && p.fuse <= 1.5 - p.beeps * 0.5) { p.beeps++; Sound.beep(p.pos); FX.glow.emit({ x: p.pos.x, y: p.pos.y + 0.05, z: p.pos.z, vx: 0, vy: 0, vz: 0, max: 0.18, s0: 0.5, s1: 0.2, r: 1, g: 0.12, b: 0.08, a: 1, grav: 0, drag: 0 }); }
          if (p.fuse <= 0) { blast(p.pos, 5.5, 100, false); dead = true; }
        }
        else if (!dead && Math.random() < 0.6) FX.puff(p.pos, 1, 0.5, 0.15);
        if (p.life <= 0 && !dead) { blast(p.pos, 5.5, p.mode === 'gl' ? 120 : 100, false); dead = true; }
      }
      else if (p.kind === 'rocket') {
        p.age += dt; p.speed = Math.min(58, p.speed + 70 * dt);
        _rd.copy(p.vel).normalize();
        const t = p.target;
        if (t && t.alive && p.age > 0.1) {
          rocketCentre(t, _rc).sub(p.pos).normalize();
          const ang = _rd.angleTo(_rc), maxA = 3.0 * dt;
          if (ang > 1e-4) _rd.lerp(_rc, Math.min(1, maxA / ang)).normalize();
        }
        p.vel.copy(_rd).multiplyScalar(p.speed);
        p.m.lookAt(p.pos.x + _rd.x, p.pos.y + _rd.y, p.pos.z + _rd.z);
        const steps = Math.max(2, Math.ceil(p.speed * dt / 0.35));
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          let hitE = null;
          for (const e of Enemies.list) {
            if (!e.alive || e.ridden) continue;
            if (e.fly) { if (Math.hypot(e.pos.x - p.pos.x, e.pos.y - p.pos.y, e.pos.z - p.pos.z) < e.R + 0.3) { hitE = e; break; } continue; }
            if (p.pos.y < e.pos.y - 0.1 || p.pos.y > e.pos.y + e.H + 0.2) continue;
            if (Math.hypot(e.pos.x - p.pos.x, e.pos.z - p.pos.z) < e.R * 0.95 + 0.25) { hitE = e; break; }
          }
          if (hitE || p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.05 || collideAt(p.pos.x, p.pos.y - 0.06, p.pos.z, 0.06, 0.12)) { rocketHit(p, hitE); dead = true; }
        }
        if (!dead) { FX.puff(p.pos, 1, 0.75, 0.32); FX.glow.emit({ x: p.pos.x - _rd.x * 0.3, y: p.pos.y - _rd.y * 0.3, z: p.pos.z - _rd.z * 0.3, vx: 0, vy: 0, vz: 0, max: 0.07, s0: 0.35, s1: 0.1, r: 1, g: 0.6, b: 0.25, a: 0.9, grav: 0, drag: 0 }); }
        if (!dead && p.life <= 0) { rocketHit(p, null); dead = true; }
      }
      else if (p.kind === 'grenade') {
        p.vel.y -= 9.8 * dt;
        const steps = 3;
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          const armed = p.pos.distanceTo(p.src) > 8;
          let impact = p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.05 || !!collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1);
          if (!impact) for (const e of Enemies.list) { _t.set(e.pos.x, e.pos.y + 1.1, e.pos.z); if (_t.distanceTo(p.pos) < 0.55) { impact = true; break; } }
          if (impact) {
            if (armed) { explode(p); dead = true; }
            else if (!p.bounced) { p.bounced = true; p.vel.multiplyScalar(-0.25); p.vel.y = Math.abs(p.vel.y) + 1; p.pos.y = Math.max(p.pos.y, 0.06); FX.puff(p.pos, 2, 0.4, 0.3); Sound.metal(p.pos); }
            else { FX.puff(p.pos, 3, 0.4, 0.35); dead = true; }
          }
        }
        if (Math.random() < 0.6) FX.puff(p.pos, 1, 0.55, 0.18);
      } else {
        // small steps so fast rounds cannot skip past you between checks
        const steps = Math.max(3, Math.ceil(p.vel.length() * dt / 0.3));
        for (let s = 0; s < steps && !dead; s++) {
          p.pos.addScaledVector(p.vel, dt / steps);
          const py = clamp(p.pos.y, hy0, hy1), dd = Math.hypot(p.pos.x - hx, p.pos.y - py, p.pos.z - hz);
          // where it struck you: above the shoulders is the head
          if (dd < 0.4 && state === 'playing') { player.hurt(p.dmg, p.src, py - player.pos.y > 1.42 ? 'head' : 'body'); dead = true; break; }
          if (!p.whiz && dd < 1.5) { p.whiz = true; Sound.whiz(p.pos); }
          if (p.pos.y <= floorY(p.pos.x, p.pos.z) + 0.02 || collideAt(p.pos.x, p.pos.y - 0.05, p.pos.z, 0.05, 0.1)) { FX.sparks(p.pos, 3, [1, 0.8, 0.5], 2); dead = true; }
        }
      }
      if (dead || p.life <= 0) { scene.remove(p.m); list.splice(i, 1); pool.push(p); }
    }
  }
  function clear() { for (const p of list) { scene.remove(p.m); pool.push(p); } list.length = 0; }
  return { bullet, grenade, rocket, egrenade, bomb, blast, update, clear, list, rocketCentre, rocketHit };
})();

const Loot = (() => {
  const list = [];
  const vialGeo = new THREE.CylinderGeometry(0.07, 0.07, 0.34, 10);
  const capGeo = new THREE.CylinderGeometry(0.075, 0.075, 0.08, 10);
  const vialMat = new THREE.MeshStandardMaterial({ color: 0x5ed6b0, emissive: 0x1d6b52, roughness: 0.2, metalness: 0.1, transparent: true, opacity: 0.9 });
  const capMat = new THREE.MeshStandardMaterial({ color: 0xece6d8, roughness: 0.5 });
  const glowT = { anti: glowTex('rgba(94,214,176,0.9)', 'rgba(94,214,176,0.2)'), hp: glowTex('rgba(255,90,90,0.9)', 'rgba(255,70,70,0.22)'), ammo: glowTex('rgba(242,163,58,0.9)', 'rgba(242,163,58,0.22)') };
  const potionMat = new THREE.MeshStandardMaterial({ color: 0xd8262e, emissive: 0x5a0a0e, roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.92 });
  const corkMat = new THREE.MeshStandardMaterial({ color: 0x8a6a45, roughness: 0.9 });
  const ammoTex = canvasTex(64, 64, (g) => { g.fillStyle = '#4a5434'; g.fillRect(0, 0, 64, 64); g.fillStyle = '#d6a12e'; g.fillRect(0, 26, 64, 12);
    g.fillStyle = '#1b1d18'; g.font = '600 13px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.fillText('100', 32, 37); });
  const ammoMat = new THREE.MeshStandardMaterial({ map: ammoTex, roughness: 0.7, emissive: 0x1a1606 });
  const flaskGeo = new THREE.SphereGeometry(0.15, 14, 10), neckGeo = new THREE.CylinderGeometry(0.05, 0.06, 0.14, 10), corkGeo = new THREE.CylinderGeometry(0.055, 0.05, 0.06, 10);
  const boxGeo = new THREE.BoxGeometry(0.46, 0.26, 0.28);
  /* kind: 'anti' antidote, 'hp' health potion (+100), 'ammo' box of 100 rounds */
  function drop(kind, x, z, yHint) {
    const g = new THREE.Group();
    if (kind === 'anti') { g.add(new THREE.Mesh(vialGeo, vialMat)); const c = new THREE.Mesh(capGeo, capMat); c.position.y = 0.2; g.add(c); g.rotation.z = 0.35; }
    else if (kind === 'hp') { g.add(new THREE.Mesh(flaskGeo, potionMat)); const n = new THREE.Mesh(neckGeo, potionMat); n.position.y = 0.18; g.add(n); const c = new THREE.Mesh(corkGeo, corkMat); c.position.y = 0.27; g.add(c); }
    else { const b = new THREE.Mesh(boxGeo, ammoMat); b.castShadow = true; g.add(b); }
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowT[kind], blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.75 })); s.scale.setScalar(1.4); g.add(s);
    const y = groundAt(x, yHint !== undefined ? yHint + 0.6 : 20, z, 0.2) + 0.5;
    g.position.set(x, y, z); scene.add(g);
    list.push({ g, kind, t: rand(0, TAU), life: kind === 'anti' ? 60 : Infinity, baseY: y });
  }
  /* the boss's treasure chest: opens when you walk up to it */
  const chests = [];
  const woodM = new THREE.MeshStandardMaterial({ color: 0x6b4423, roughness: 0.8 });
  const goldM = new THREE.MeshStandardMaterial({ color: 0xd9a531, roughness: 0.35, metalness: 0.8, emissive: 0x3a2400 });
  const goldT = glowTex('rgba(255,214,120,0.95)', 'rgba(255,180,60,0.25)');
  function chest(x, z, yHint) {
    const g = new THREE.Group();
    const add = (geo, m, px, py, pz, parent) => { const o = new THREE.Mesh(geo, m); o.position.set(px, py, pz); o.castShadow = true; (parent || g).add(o); return o; };
    add(new THREE.BoxGeometry(1.1, 0.6, 0.75), woodM, 0, 0.3, 0);
    add(new THREE.BoxGeometry(1.14, 0.62, 0.08), goldM, 0, 0.3, 0.2); add(new THREE.BoxGeometry(1.14, 0.62, 0.08), goldM, 0, 0.3, -0.2);
    const lid = new THREE.Group(); lid.position.set(0, 0.6, -0.375); g.add(lid);
    add(new THREE.BoxGeometry(1.1, 0.28, 0.75), woodM, 0, 0.14, 0.375, lid); add(new THREE.BoxGeometry(1.14, 0.3, 0.08), goldM, 0, 0.14, 0.575, lid);
    add(new THREE.BoxGeometry(0.16, 0.2, 0.06), goldM, 0, 0.02, 0.77, lid);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: goldT, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.8 })); s.scale.setScalar(2.6); s.position.y = 0.6; g.add(s);
    const y = groundAt(x, yHint !== undefined ? yHint + 0.6 : 20, z, 0.6);
    g.position.set(x, y, z); g.rotation.y = rand(0, TAU); scene.add(g);
    chests.push({ g, lid, glow: s, open: false, t: 0, x, z, y });
    FX.sparks({ x, y: y + 0.6, z }, 30, [1, 0.85, 0.4], 4);
  }
  function update(dt) {
    for (let i = chests.length - 1; i >= 0; i--) {
      const c = chests[i]; c.t += dt;
      c.glow.material.opacity = 0.55 + Math.sin(c.t * 4) * 0.25;
      if (!c.open && Math.hypot(c.x - player.pos.x, c.z - player.pos.z) < 1.9 && Math.abs(player.pos.y - c.y) < 1.8) {
        c.open = true; c.t = 0; Game.openChest();
        for (let k = 0; k < 3; k++) FX.sparks({ x: c.x, y: c.y + 0.8, z: c.z }, 20, [1, 0.85, 0.4], 5);
      }
      if (c.open) { c.lid.rotation.x = -Math.min(1, c.t / 0.6) * 1.9; if (c.t > 8) { scene.remove(c.g); chests.splice(i, 1); } }
    }
    for (let i = list.length - 1; i >= 0; i--) {
      const L = list[i]; L.t += dt; L.life -= dt;
      L.g.position.y = L.baseY + Math.sin(L.t * 2.5) * 0.1; L.g.rotation.y += dt * 1.6;
      if (L.life < 6) L.g.visible = Math.sin(L.life * 18) > -0.3;
      const dx = L.g.position.x - player.pos.x, dz = L.g.position.z - player.pos.z;
      let taken = false;
      if (dx * dx + dz * dz < 1.8 && Math.abs(L.baseY - player.pos.y - 0.5) < 1.8) taken = Game.takeLoot(L.kind);
      if (taken || L.life <= 0) { scene.remove(L.g); list.splice(i, 1); }
    }
  }
  function clear() { for (const L of list) scene.remove(L.g); list.length = 0; for (const c of chests) scene.remove(c.g); chests.length = 0; }
  /* a boss chest nobody has opened yet (the way out waits for it) */
  function pending() { for (const c of chests) if (!c.open) return c; return null; }
  return { drop, chest, update, clear, pending };
})();

const _to = new THREE.Vector3(), _eye = new THREE.Vector3(), _aim = new THREE.Vector3(), _fd = { x: 0, z: 0 }, _mz = new THREE.Vector3();
function turnToward(e, yaw, rate, dt) {
  let d = yaw - e.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
  e.yaw += clamp(d, -rate * dt, rate * dt); e.g.rotation.y = e.yaw;
}
function muzzleOf(e, out) {
  const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw), m = e.muzzle, s = e.scale || 1;
  return out.set(e.pos.x + (m.x * cy + m.z * sy) * s, e.pos.y + m.y * s, e.pos.z + (-m.x * sy + m.z * cy) * s);
}
function groundMove(e, vx, vz, dt) {
  const r = e.R;
  const blocked = moveXZ(e.pos, vx * dt, vz * dt, r, e.H, 0.45);
  const gy = groundAt(e.pos.x, e.pos.y, e.pos.z, r);
  if (e.pos.y > gy) { e.vy -= 18 * dt; e.pos.y = Math.max(gy, e.pos.y + e.vy * dt); } else { e.pos.y = gy; e.vy = 0; }
  e.pos.x = clamp(e.pos.x, -HALF + r, HALF - r); e.pos.z = clamp(e.pos.z, -HALF + r, HALF - r);
  return blocked;
}
/* how each kit fights once it has you in sight. returns true while it is busy shooting (and moves slower) */
const _lz = new THREE.Vector3(), _ld = new THREE.Vector3();
const laserMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a, transparent: true, opacity: 0.75, blending: THREE.AdditiveBlending, depthWrite: false });
function fightKit(e, dt, dist) {
  const kit = e.kit || 'pistol', m = e.dmgMul;
  e.fireT -= dt;
  const aimAt = (lead, up) => _aim.set(player.pos.x + player.vel.x * dist / lead, player.pos.y + (up || 1.25), player.pos.z + player.vel.z * dist / lead);
  const spread = (base) => base + dist * 0.028 + player.speedXZ * 0.08 - (e.boss ? 0.15 : 0);
  if (kit === 'saber' || kit === 'saber2') {
    // runs you down and swings; one cut is 300. with a blade in each hand the cuts come twice as often, left and right in turn
    const dual = kit === 'saber2';
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const arm = e.swingL ? e.armL : e.armR, side = e.swingL ? 1 : -1;
      arm.rotation.set(-2.6 + (0.28 - e.swingT) * 9, 0, 0.4 * side);
      if (e.swingT <= 0 && dist < sd + 1.3 && Math.abs(player.pos.y - e.pos.y) < 1.8) { player.hurt(300 * m, e.pos, 'head'); Sound.saberHit(e.pos); } // an overhead chop
      return true;
    }
    if (dist < sd + 0.9 && e.swingCd <= 0) { e.swingT = 0.28; e.swingCd = dual ? 0.62 : 1.25; e.swingL = dual && !e.swingL; Sound.saberSwing(e.pos); }
    if (e.fireT <= 0) { e.fireT = rand(1.2, 2); if (dist < 25) Sound.saberHum(e.pos); }
    return false;
  }
  if (kit === 'dagger') {
    // a knife: arm back, then a quick thrust; 70 a stab, nearly two a second once he is on you
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const u = 1 - e.swingT / 0.32;
      e.armR.rotation.set(u < 0.45 ? -0.7 + u * 1.2 : -0.16 - (u - 0.45) / 0.55 * 1.5, 0, -0.12);
      if (!e.stabbed && u >= 0.6) {
        e.stabbed = true; Sound.swoosh(e.pos);
        if (dist < sd + 1.0 && Math.abs(player.pos.y - e.pos.y) < 1.7) { player.hurt(70 * m, e.pos, 'body'); Sound.squelch(e.pos); }
      }
      return true;
    }
    if (dist < sd + 0.8 && e.swingCd <= 0) { e.swingT = 0.32; e.swingCd = 0.55; e.stabbed = false; }
    return false;
  }
  if (kit === 'bat') {
    // the bat goes up over the shoulder, then comes round flat: 150 and a shove
    e.swingCd = (e.swingCd || 0) - dt; const sd = stopDist(e);
    if (e.swingT > 0) {
      e.swingT -= dt; const u = 1 - e.swingT / 0.55;
      if (u < 0.55) { const w = u / 0.55; e.armR.rotation.set(-1.2 - w * 1.5, 0, -0.2 - w * 0.6); }
      else { const w = (u - 0.55) / 0.45; e.armR.rotation.set(-2.7 + w * 1.4, 0, -0.8 + w * 1.6); }
      if (!e.batHit && u >= 0.75) {
        e.batHit = true; Sound.swoosh(e.pos);
        if (dist < sd + 1.25 && Math.abs(player.pos.y - e.pos.y) < 1.8) {
          player.hurt(150 * m, e.pos, 'head'); Sound.batHit(e.pos); // swung at head height
          const tx = (player.pos.x - e.pos.x) / (dist || 1), tz = (player.pos.z - e.pos.z) / (dist || 1); player.vel.x += tx * 6; player.vel.z += tz * 6;
        }
      }
      return true;
    }
    if (dist < sd + 0.9 && e.swingCd <= 0) { e.swingT = 0.55; e.swingCd = 1.4; e.batHit = false; }
    return false;
  }
  if (kit === 'bomber') {
    // close enough: arms up, the vest beeps fast, and after a moment it all goes
    const sd = stopDist(e);
    if (e.fuse > 0) {
      e.fuse -= dt; e.armL.rotation.set(-2.9, 0, 0.35); e.armR.rotation.set(-2.9, 0, -0.35);
      if (!e.beep2 && e.fuse < 0.3) { e.beep2 = true; Sound.beep(e.pos); }
      if (e.fuse <= 0) Enemies.detonate(e);
      return true;
    }
    if (dist < sd + 1.4 && Math.abs(player.pos.y - e.pos.y) < 2) { e.fuse = 0.6; e.beep2 = false; Sound.beep(e.pos); Sound.scream(e.pos); }
    return false;
  }
  if (kit === 'flame') {
    if (e.flameOn > 0) {
      e.flameOn -= dt; muzzleOf(e, _mz);
      const fx = Math.sin(e.yaw), fz = Math.cos(e.yaw);
      for (let k = 0; k < 3; k++) FX.glow.emit({ x: _mz.x, y: _mz.y, z: _mz.z, vx: fx * rand(8, 11) + rand(-1, 1), vy: rand(-0.3, 0.8), vz: fz * rand(8, 11) + rand(-1, 1), max: rand(0.45, 0.7), s0: 0.15, s1: rand(0.9, 1.4), r: 1, g: rand(0.35, 0.6), b: 0.1, a: 0.8, grav: -2, drag: 2.2 });
      // you are in the cone: inside 9.5 m and within ~20 degrees of where the nozzle points
      const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, cos = (dx * fx + dz * fz) / (dist || 1);
      if (dist < 9.5 && cos > 0.94 && Math.abs(player.pos.y - e.pos.y) < 2.2) { e.flameAcc = (e.flameAcc || 0) + 75 * m * dt; if (e.flameAcc >= 15) { e.flameAcc -= 15; player.hurt(15, e.pos, 'fire'); } }
      if ((e.flameSnd = (e.flameSnd || 0) - dt) <= 0) { e.flameSnd = 0.18; Sound.flame(_mz); }
      return true;
    }
    if (dist < 9 && e.fireT <= 0) { e.flameOn = rand(1.6, 2.4); e.fireT = e.flameOn + rand(0.9, 1.5); }
    return false;
  }
  if (kit === 'sniper') {
    // a red laser shows where he is aiming for a moment before the shot
    if (!e.laser) { e.laser = new THREE.Mesh(new THREE.BoxGeometry(0.018, 0.018, 1), laserMat); e.laser.frustumCulled = false; scene.add(e.laser); }
    if (e.aimT > 0) {
      e.aimT -= dt; muzzleOf(e, _mz); aimAt(400, 1.58); // snipers go for the head
      _ld.copy(_aim).sub(_mz); const L = _ld.length(); e.laser.position.copy(_mz).addScaledVector(_ld, 0.5); e.laser.scale.set(1, 1, L); e.laser.lookAt(_aim); e.laser.visible = true;
      if (e.aimT <= 0) { e.laser.visible = false; Proj.bullet(_mz, _aim, 160, 140 * m, 0.05 + player.speedXZ * 0.12); Sound.farShot(_mz, 'sniper'); e.fireT = rand(2.4, 3.4); }
      return true;
    }
    if (e.fireT <= 0) e.aimT = 1.3;
    return false;
  }
  if (kit === 'gl' || kit === 'nade') {
    if (e.fireT <= 0) {
      muzzleOf(e, _mz); aimAt(kit === 'gl' ? 60 : 45, 0.3);
      if (kit === 'nade') { e.armR.rotation.set(-2.8, 0, 0); _mz.y += 0.4; }
      Proj.egrenade(_mz, _aim, kit === 'gl' ? 'gl' : 'nade'); e.fireT = kit === 'gl' ? rand(2.6, 3.6) : rand(2.4, 3.6);
    }
    return false;
  }
  // guns that fire bullets: shots per burst, gap between shots, damage, pause between bursts
  const G = { pistol: [1, 3, 0.32, 9, 1.1, 2.3], deagle: [1, 1, 0.3, 45, 1.3, 2.2], smg: [6, 9, 0.08, 7, 1.3, 2.1], rifle: [3, 5, 0.11, 11, 1.2, 2.0],
    lmg: [12, 18, 0.075, 10, 1.0, 1.6], shotgun: [1, 1, 0.3, 11, 1.2, 1.8] }[kit] || [1, 3, 0.32, 9, 1.1, 2.3];
  if (kit === 'shotgun' && dist > 18) return false;
  if (e.burst > 0) {
    e.burstT -= dt;
    if (e.burstT <= 0) {
      e.burst--; e.burstT = G[2] * (e.boss && kit === 'pistol' ? 0.62 : 1);
      muzzleOf(e, _mz);
      if (kit === 'shotgun') { aimAt(120); for (let k = 0; k < 7; k++) Proj.bullet(_mz, _aim, 70, G[3] * m, 0.9 + dist * 0.05, true); Sound.farShot(_mz, 'shotgun'); }
      else { aimAt(150); Proj.bullet(_mz, _aim, kit === 'deagle' ? 95 : 80, G[3] * m, spread(kit === 'deagle' ? 0.2 : kit === 'smg' ? 0.55 : 0.35), true); Sound.farShot(_mz, kit); }
    }
    return true;
  }
  if (e.fireT <= 0) { e.burst = e.boss && kit === 'pistol' ? 4 : randi(G[0], G[1]); e.burstT = 0; e.fireT = rand(G[4], G[5]) * (e.boss ? 0.7 : 1); }
  return false;
}
function animateWalk(e, sp, dt, aim) {
  e.walk += dt * sp * (e.type === 'zombie' ? 3.2 : 2.6);
  const s = Math.sin(e.walk) * Math.min(1, sp / 2) * (e.type === 'zombie' ? 0.45 : 0.6);
  e.legL.rotation.x = s; e.legR.rotation.x = -s;
  if (e.type === 'zombie') {
    const sway = Math.sin(e.walk * 0.5) * 0.12;
    e.armL.rotation.set(-1.35 + sway, 0, 0.08); e.armR.rotation.set(-1.4 - sway, 0, -0.08);
    e.upper.rotation.z = Math.sin(e.walk * 0.5) * 0.06;
  } else if (e.kit === 'saber') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -1.15 : -0.5 - s * 0.3, 0, -0.25); // blade held up and forward
    e.armL.rotation.set(aim ? -0.6 : s * 0.8, 0, 0.2);
  } else if (e.kit === 'saber2') {
    // both blades up and out; the one not swinging stays on guard
    if (!(e.swingT > 0 && !e.swingL)) e.armR.rotation.set(aim ? -1.15 : -0.5 - s * 0.3, 0, -0.3);
    if (!(e.swingT > 0 && e.swingL)) e.armL.rotation.set(aim ? -1.15 : -0.5 + s * 0.3, 0, 0.3);
  } else if (e.kit === 'dagger') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -0.9 : -0.55 - s * 0.3, 0, -0.12); // knife held low and forward
    e.armL.rotation.set(s * 0.9, 0, 0.12);
  } else if (e.kit === 'bat') {
    if (!(e.swingT > 0)) e.armR.rotation.set(aim ? -2.3 : -2.0 - s * 0.15, 0, -0.35); // bat up on the shoulder
    e.armL.rotation.set(s * 0.8, 0, 0.1);
  } else if (e.kit === 'bomber') {
    if (!(e.fuse > 0)) { e.armR.rotation.set(-s * 1.1, 0, -0.15); e.armL.rotation.set(s * 1.1, 0, 0.15); } // arms pumping as he runs
  } else if (aim) {
    e.armR.rotation.set(-Math.PI / 2 + 0.05, 0, 0); e.armL.rotation.set(-1.25, 0, 0.5);
  } else { e.armR.rotation.set(-s * 0.8, 0, 0); e.armL.rotation.set(s * 0.8, 0, 0); }
  e.flinch = Math.max(0, e.flinch - dt * 5);
  e.upper.rotation.x = (e.type === 'zombie' ? 0.28 : 0) - e.flinch * 0.25;
}
const ACT_R = { 1: 55, 6: 55, 5: 55, 2: 45, 3: 95, 8: 95, 4: 55, 7: 95 }, VIS_R = { 1: 85, 6: 85, 5: 85, 2: 72, 3: 165, 8: 165, 4: 90, 7: 150 };
function updateEnemies(dt, time) {
  const L = Enemies.list, act = ACT_R[Game.stage] || 60, vis = (VIS_R[Game.stage] || 90) * (isTouch ? 0.75 : 1);
  for (const e of L) {
    if (!e.alive) continue;
    // with all 100 placed at once, only the ones near you think; far ones sleep and are not drawn
    e.lod -= dt;
    if (e.lod <= 0) {
      e.lod = 0.3 + Math.random() * 0.2; e.dist = Math.hypot(player.pos.x - e.pos.x, player.pos.z - e.pos.z);
      e.g.visible = e.dist < vis * (e.boss ? 1.6 : 1); e.awake = e.alert || e.angry || e.dist < act;
      if (!e.g.visible) e.bar.visible = false;
      const far = e.dist > (World.style.lab ? (isTouch ? 18 : 46) : e.animal ? 45 : 28) * (e.boss ? 1.5 : 1); if (!e.noFar && e.isFar !== far) setFar(e, far);
      if (!isTouch) { const sh = e.dist < Gfx.esh; if (e.castsShadow !== sh) { e.castsShadow = sh; e.g.traverse((o) => { if (o.isMesh) o.castShadow = sh; }); } }
    }
    if (e.downed) { Enemies.updateDowned(e, dt); continue; }
    if (e.ridden) { // you are on it: Ride steers it; just the hit flash here
      if (e.flashT > 0) { e.flashT -= dt; e.mats[0].emissive.setRGB(0.6, 0.35, 0.2); } else e.mats[0].emissive.setRGB(0, 0, 0);
      e.bar.visible = false; continue;
    }
    if (!e.awake) continue;
    _eye.set(e.pos.x, e.pos.y + (e.eyeH !== undefined ? e.eyeH : 1.65) * (e.scale || 1), e.pos.z);
    _to.set(player.pos.x - e.pos.x, 0, player.pos.z - e.pos.z);
    const dist = Math.hypot(_to.x, _to.z) || 0.001;
    e.losT -= dt;
    if (e.losT <= 0) { e.losT = 0.2 + Math.random() * 0.1; e.los = dist < 70 && lineOfSight(_eye, camera.position); }
    e.noLos = e.los ? 0 : e.noLos + dt;
    const faceYaw = Math.atan2(_to.x, _to.z);
    let mvx = 0, mvz = 0;
    if (!e.animal && !e.robot && !e.alert) {
      // on guard (people) or milling about (zombies) until they see or hear you
      const sees = e.los && dist < (e.type === 'thug' ? 30 : 16);
      if (sees || dist < (e.type === 'thug' ? 7 : 5) || (e.boss && dist < 24)) {
        Enemies.alarm(e);
        if (e.type === 'thug') for (const o of L) if (o.type === 'thug' && !o.alert && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 15) Enemies.alarm(o);
      } else {
        e.idleT = (e.idleT || rand(2, 6)) - dt;
        if (e.idleT <= 0) { e.idleT = rand(3, 7); e.idleYaw = e.yaw + rand(-1.3, 1.3); }
        let sp = 0;
        if (e.type === 'zombie' && e.idleT > 3) { sp = 0.5; groundMove(e, Math.sin(e.yaw) * sp, Math.cos(e.yaw) * sp, dt); }
        turnToward(e, e.idleYaw === undefined ? e.yaw : e.idleYaw, 1.2, dt);
        animateWalk(e, sp, dt, false);
        continue;
      }
    }
    if (e.animal) updateAnimal(e, dt, time, dist, faceYaw);
    else if (e.robot) updateRobot(e, dt, dist, faceYaw);
    else if (e.type === 'thug') {
      if (e.state === 'move') {
        if (flowDir(e.pos.x, e.pos.z, _fd)) { mvx = _fd.x * e.speed; mvz = _fd.z * e.speed; } else { mvx = _to.x / dist * e.speed; mvz = _to.z / dist * e.speed; }
        turnToward(e, e.los && dist < 34 ? faceYaw : Math.atan2(mvx, mvz), 6, dt);
        const K = e.K || KITS.pistol;
        if (e.los && dist < K.range * (e.boss ? 1.2 : 1)) { e.state = 'engage'; e.react = (K.melee ? 0.15 : rand(0.45, 0.9)) * (1 - e.diff * 0.35); }
      } else {
        const K = e.K || KITS.pistol;
        e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(0.9, 2.4); }
        const fx = _to.x / dist, fz = _to.z / dist;
        if (K.melee) { const sd = stopDist(e), sp = (K.run || 4.3) * (dist > sd + 0.2 ? 1 : 0); mvx = fx * sp; mvz = fz * sp; }
        else if (K.still) { mvx = 0; mvz = 0; }
        else {
          const fwd = dist > K.far ? 1 : dist < K.near ? -0.8 : 0;
          mvx = (fx * fwd - fz * e.strafe * 0.6) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * 0.6) * e.speed * 0.55;
        }
        turnToward(e, faceYaw, K.melee ? 9 : 7, dt);
        e.react -= dt;
        if (e.noLos > 1.6 || dist > K.range + 6) { e.state = 'move'; if (e.laser) e.laser.visible = false; e.flameOn = 0; }
        if (e.react <= 0 && (e.los || K.melee)) { const slow = fightKit(e, dt, dist); if (slow) { mvx *= 0.4; mvz *= 0.4; } }
      }
      if (e.vestLight) e.vestLight.visible = (time * (e.fuse > 0 ? 14 : 3) + e.walk) % 1 < 0.45;
      e.vel.multiplyScalar(Math.exp(-dt * 6));
      const blocked = groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
      if (blocked && e.state === 'engage') e.strafe *= -1;
      animateWalk(e, Math.hypot(mvx, mvz), dt, e.state === 'engage');
    } else if (zombieSkill(e, dt, dist)) {
      // a dash, a wind-up or a charge moved it this frame
    } else {
      // zombie: shamble straight for the player once close, otherwise follow the flow field
      if (dist < 9 && e.los) { mvx = _to.x / dist; mvz = _to.z / dist; }
      else if (flowDir(e.pos.x, e.pos.z, _fd)) { mvx = _fd.x; mvz = _fd.z; } else { mvx = _to.x / dist; mvz = _to.z / dist; }
      let sp = e.speed;
      e.attackCd -= dt;
      const sd = stopDist(e);
      if (e.state === 'lunge') { e.stateT -= dt; sp *= 0.2; if (e.stateT <= 0) { e.state = 'move'; if (dist < Math.max(1.75, sd + 0.6) && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) Game.bitten(e); } }
      else if (dist < Math.max(1.35, sd + 0.25) && e.attackCd <= 0 && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) { e.state = 'lunge'; e.stateT = 0.35; e.attackCd = 1.4; }
      if (dist < sd + 0.05 && e.state !== 'lunge') sp = 0; // pressed against you: stop pushing, just claw
      mvx *= sp; mvz *= sp;
      turnToward(e, dist < 9 ? faceYaw : Math.atan2(mvx, mvz), 3.5, dt);
      e.vel.multiplyScalar(Math.exp(-dt * 5));
      groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
      animateWalk(e, sp, dt, false);
      if (e.state === 'lunge') { e.armL.rotation.x = -1.75; e.armR.rotation.x = -1.8; e.upper.rotation.x = 0.45; }
      e.moanT -= dt; if (e.moanT <= 0) { e.moanT = rand(3, 8); if (dist < 28) Sound.moan(e.pos); }
    }
    if (e.flashT > 0) { e.flashT -= dt; e.mats[0].emissive.setRGB(0.6, 0.35, 0.2); } else if (e.rage) e.mats[0].emissive.setRGB(0.3 + Math.sin(time * 9) * 0.14, 0.02, 0.01); else e.mats[0].emissive.setRGB(0, 0, 0);
    if (e.hp < e.maxHp) {
      e.bar.visible = e.g.visible; e.bar.position.set(e.pos.x, e.pos.y + (e.barY !== undefined ? e.barY * (e.scale || 1) : e.H + 0.4 * (e.scale || 1)), e.pos.z); e.bar.quaternion.copy(camera.quaternion);
      const f = clamp(e.hp / e.maxHp, 0, 1); e.fill.scale.x = 0.66 * f; e.fill.position.x = -0.33 * (1 - f);
    }
  }
  for (let i = 0; i < L.length; i++) for (let j = i + 1; j < L.length; j++) {
    const a = L[i], b = L[j]; if ((!a.awake && !b.awake) || a.downed || b.downed || a.fly || b.fly) continue;
    const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z; if (Math.abs(dx) > 5 || Math.abs(dz) > 5) continue;
    const d = Math.hypot(dx, dz), m = a.R + b.R + 0.1;
    if (d < m && d > 0.001) { const push = (m - d) * 0.5; moveXZ(a.pos, -dx / d * push, -dz / d * push, a.R, a.H, 0); moveXZ(b.pos, dx / d * push, dz / d * push, b.R, b.H, 0); }
  }
  /* nobody walks into you: your body, and the camera with it, stays outside every enemy's footprint */
  if (!Ride.m) for (const e of L) if (e.alive && e.awake && e.foot && !e.downed) keepOut(e); // riding, the animal under you does the shoving
  Enemies.updateDying(dt);
}
/* zombie skills. ordinary zombies dash once when down to 30% health, and that dash poisons;
   the boss enrages at half health (red, much faster) and every few seconds rears up and charges, which stuns you */
function zombieSkill(e, dt, dist) {
  if (e.boss && !e.rage && e.hp <= e.maxHp * 0.5) {
    e.rage = true; e.speed *= 1.9; e.chargeCd = 1.6; e.mats[0].color.setRGB(1, 0.4, 0.36);
    Sound.rage(e.pos); player.shake = Math.max(player.shake, 0.25);
    HUD.banner(e.name + ' 폭주', '빨라지고 가끔 돌진합니다 · 맞으면 2초 기절', 2.4);
  }
  if (!e.boss && !e.dashUsed && e.hp > 0 && e.hp <= e.maxHp * 0.3 && e.state !== 'lunge') {
    e.dashUsed = true; e.state = 'dash'; e.stateT = 1.1; e.hitDone = false;
    e.cx = _to.x / dist; e.cz = _to.z / dist; e.yaw = Math.atan2(e.cx, e.cz); e.g.rotation.y = e.yaw;
    Sound.scream(e.pos);
  }
  if (e.boss && e.rage && e.state === 'move') {
    e.chargeCd -= dt;
    if (e.chargeCd <= 0 && dist > 3.5 && dist < 26 && e.los) { e.state = 'windup'; e.stateT = 0.65; Sound.rage(e.pos); }
  }
  if (e.state === 'windup') {
    e.stateT -= dt; turnToward(e, Math.atan2(_to.x, _to.z), 7, dt);
    e.upper.rotation.x = -0.32; e.armL.rotation.x = -2.6; e.armR.rotation.x = -2.6; e.legL.rotation.x = 0.35; e.legR.rotation.x = -0.35;
    if (e.stateT <= 0) { e.state = 'charge'; e.stateT = 1.4; e.hitDone = false; e.cx = Math.sin(e.yaw); e.cz = Math.cos(e.yaw); }
    return true;
  }
  if (e.state === 'dash' || e.state === 'charge') {
    const charge = e.state === 'charge', sp = charge ? 13 : 8.5;
    e.stateT -= dt;
    const blocked = groundMove(e, e.cx * sp, e.cz * sp, dt);
    animateWalk(e, sp, dt, false);
    e.armL.rotation.x = -1.6; e.armR.rotation.x = -1.65; e.upper.rotation.x = 0.5;
    if (!e.hitDone && dist < stopDist(e) + 0.55 && Math.abs(player.pos.y - e.pos.y) < 1.6 * (e.scale || 1)) {
      e.hitDone = true; if (charge) Game.stun(e); else Game.poison(e);
    }
    if (charge && Math.random() < dt * 18) FX.puff({ x: e.pos.x, y: 0.25, z: e.pos.z }, 1, 0.55, 0.35);
    if (e.stateT <= 0 || blocked || e.hitDone) { e.state = 'move'; e.chargeCd = rand(5, 8); }
    return true;
  }
  return false;
}
const KEEP_PAD = 0.14;
/* distance from an enemy's centre at which it stops in front of you */
function stopDist(e) { return e.foot ? e.foot.z1 + player.r + KEEP_PAD : 1; }
function keepOut(e) {
  if (e.ghostT > 0) return; // a buffalo that has just run you down goes on past you
  const p = player.pos;
  if (p.y > e.pos.y + e.H * 0.92 || e.pos.y > p.y + player.height) return; // one is standing above the other
  const dx = p.x - e.pos.x, dz = p.z - e.pos.z, rr = e.footR + player.r + KEEP_PAD;
  if (dx * dx + dz * dz > rr * rr) return;
  const yaw = e.g.rotation.y, c = Math.cos(yaw), s = Math.sin(yaw), r = player.r + KEEP_PAD, F = e.foot;
  const lx = dx * c - dz * s, lz = dx * s + dz * c; // you, in the enemy's frame
  const pl = lx - (F.x0 - r), pr = F.x1 + r - lx, pb = lz - (F.z0 - r), pf = F.z1 + r - lz;
  if (pl <= 0 || pr <= 0 || pb <= 0 || pf <= 0) return;
  const m = Math.min(pl, pr, pb, pf);
  let ox = 0, oz = 0;
  if (m === pf) oz = pf; else if (m === pb) oz = -pb; else if (m === pl) ox = -pl; else ox = pr;
  const wx = ox * c + oz * s, wz = -ox * s + oz * c; // the way out for you, in world space
  let movedX = 0, movedZ = 0;
  if (!Car.riding) {
    const k = e.mass / (e.mass + 1), bx = p.x, bz = p.z;
    moveXZ(p, wx * k, wz * k, player.r, player.height, 0);
    movedX = p.x - bx; movedZ = p.z - bz;
  }
  // whatever you could not give (a wall behind you, or the car), the enemy gives
  moveXZ(e.pos, movedX - wx, movedZ - wz, e.R, e.H, 0);
}

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

/* ============ stage 3: the ranger's open-top off-road SUV ============ */
// He turns up now and then, stops next to you and waits. Climb into the passenger seat and he drives a loop
// while you shoot from the open top. Big animals can ram and wreck it.
const Car = (() => {
  const B = AnimalKit.geoBox, M = AnimalKit.merge;
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const paint = '#5b6b3a', sand = '#c9b98a', black = '#1d1f22', steel = '#6d7278', seatC = '#3a2f26';
  const parts = [
    B(2.0, 0.55, 4.4, 0, 0.9, 0, paint), B(1.96, 0.28, 1.3, 0, 1.3, 1.45, paint), B(2.04, 0.12, 4.42, 0, 0.98, 0, sand),
    B(0.08, 0.45, 2.6, 0.98, 1.4, -0.55, paint), B(0.08, 0.45, 2.6, -0.98, 1.4, -0.55, paint), B(1.96, 0.45, 0.08, 0, 1.4, -1.83, paint),
    B(1.9, 0.5, 0.06, 0, 1.75, 0.78, steel, [-0.25, 0, 0]), B(0.07, 1.5, 0.07, 0.95, 2.1, -0.75, steel), B(0.07, 1.5, 0.07, -0.95, 2.1, -0.75, steel),
    B(1.97, 0.07, 0.07, 0, 2.85, -0.75, steel), B(0.07, 0.07, 1.1, 0.95, 2.85, -1.3, steel), B(0.07, 0.07, 1.1, -0.95, 2.85, -1.3, steel), B(1.97, 0.07, 0.07, 0, 2.85, -1.85, steel),
    B(0.6, 0.5, 0.55, 0.5, 1.35, 0.25, seatC), B(0.6, 0.5, 0.55, -0.5, 1.35, 0.25, seatC), B(0.6, 0.6, 0.12, 0.5, 1.7, -0.02, seatC), B(0.6, 0.6, 0.12, -0.5, 1.7, -0.02, seatC),
    B(1.7, 0.45, 0.5, 0, 1.4, -1.1, seatC), B(0.36, 0.36, 0.06, 0.5, 1.72, 0.62, black, [-0.9, 0, 0]),
    B(2.1, 0.3, 0.2, 0, 0.75, 2.25, black), B(0.12, 0.6, 0.12, 0.6, 1.0, 2.3, black), B(0.12, 0.6, 0.12, -0.6, 1.0, 2.3, black), B(1.4, 0.1, 0.1, 0, 1.28, 2.3, black),
    B(0.9, 0.9, 0.28, 0, 1.25, -2.35, black, null, false, true), B(2.1, 0.3, 0.2, 0, 0.75, -2.25, black),
    B(0.25, 0.14, 0.05, 0.7, 1.05, 2.23, '#fff4c8'), B(0.25, 0.14, 0.05, -0.7, 1.05, 2.23, '#fff4c8'),
  ];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, metalness: 0.2 });
  const body = new THREE.Mesh(M(parts), mat); body.castShadow = true; body.receiveShadow = true; g.add(body);
  // the driver: khaki shirt, bush hat, hands on the wheel
  const drv = new THREE.Mesh(M([B(0.46, 0.55, 0.3, 0.5, 1.95, 0.22, '#b8a06a'), B(0.24, 0.27, 0.25, 0.5, 2.42, 0.25, '#c99a7a'), B(0.5, 0.05, 0.5, 0.5, 2.58, 0.25, '#6b5a36', null, false, true),
    B(0.28, 0.14, 0.28, 0.5, 2.64, 0.25, '#6b5a36'), B(0.12, 0.12, 0.45, 0.32, 1.95, 0.48, '#b8a06a', [-0.4, 0, 0]), B(0.12, 0.12, 0.45, 0.68, 1.95, 0.48, '#b8a06a', [-0.4, 0, 0])]), mat);
  drv.castShadow = true; g.add(drv);
  const wheelGeo = new THREE.CylinderGeometry(0.46, 0.46, 0.36, 16); wheelGeo.rotateZ(Math.PI / 2);
  const wheelMat = new THREE.MeshStandardMaterial({ color: 0x18191b, roughness: 0.9 });
  const wheels = [[0.95, 1.4], [-0.95, 1.4], [0.95, -1.35], [-0.95, -1.35]].map(([x, z]) => { const w = new THREE.Mesh(wheelGeo, wheelMat); w.position.set(x, 0.46, z); w.castShadow = true; g.add(w); return w; });
  g.visible = false; scene.add(g);
  const pos = g.position, vel = new THREE.Vector3();
  const C = { active: false, state: 'off', yaw: 0, speed: 0, hp: 800, timer: 0, nextT: 35, riding: false, path: [], wp: 0, stuckT: 0, revT: 0, smokeT: 0, msgT: 0 };
  const fwdX = () => Math.sin(C.yaw), fwdZ = () => Math.cos(C.yaw);
  function say(t) { HUD.feed('아저씨: ' + t, 0); }
  function reset() { C.active = false; C.state = 'off'; C.riding = false; g.visible = false; C.nextT = 35; C.hp = 800; drv.visible = true; Sound.engine(0, 0); }
  function free(x, z) { return !collideAt(x, 0, z, 1.8, 2); }
  /* he comes in along a clear straight line; if he still gets stuck he tries again from another side */
  function arrive(retry) {
    if (!retry) C.retries = 0;
    const near = retry ? [45, 65] : [80, 105];
    for (let k = 0; k < 60; k++) {
      const a = rand(0, TAU), d = rand(near[0], near[1]), x = clamp(player.pos.x + Math.cos(a) * d, -HALF + 6, HALF - 6), z = clamp(player.pos.z + Math.sin(a) * d, -HALF + 6, HALF - 6);
      if (!free(x, z)) continue;
      const dx = player.pos.x - x, dz = player.pos.z - z, l = Math.hypot(dx, dz) || 1, sx = -dz / l * 1.4, sz = dx / l * 1.4;
      if (k < 50 && (raycastStatic(x + sx, 0.8, z + sz, dx / l, 0, dz / l, l - 6) || raycastStatic(x - sx, 0.8, z - sz, dx / l, 0, dz / l, l - 6))) continue;
      pos.set(x, 0, z); C.yaw = Math.atan2(dx, dz); C.speed = 0; C.active = true; C.state = 'arrive'; C.timer = 25; C.stuckT = 0; C.revT = 0;
      if (!retry) { C.hp = 800; drv.visible = true; g.visible = true; HUD.feed('SUV 엔진 소리가 들립니다', 0); }
      return;
    }
    if (!retry) C.nextT = 10;
  }
  function loopPath() {
    C.path = []; const cx = clamp(pos.x, -HALF + 50, HALF - 50), cz = clamp(pos.z, -HALF + 50, HALF - 50), a0 = Math.atan2(pos.z - cz, pos.x - cx), dir = Math.random() < 0.5 ? 1 : -1;
    for (let i = 1; i <= 12; i++) {
      const a = a0 + dir * (i / 12) * TAU, rr = 40 + Math.sin(i * 1.7) * 8;
      let x = cx + Math.cos(a) * rr, z = cz + Math.sin(a) * rr;
      for (let k = 0; k < 6 && !free(x, z); k++) { x += rand(-6, 6); z += rand(-6, 6); }
      C.path.push({ x, z });
    }
    C.wp = 0;
  }
  function board() {
    if (!canBoard()) return;
    C.riding = true; C.state = 'drive'; C.timer = 55; loopPath(); Sound.horn();
    say(pick(['꽉 잡아! 한 바퀴 돈다', '타라! 맹수들 쏴 버려', '조수석이 명당이지, 마음껏 쏴']));
  }
  function exit(forced) {
    if (!C.riding) return;
    C.riding = false;
    const rx = -Math.cos(C.yaw), rz = Math.sin(C.yaw);
    const spots = [[rx * 2.6, rz * 2.6], [-rx * 2.6, -rz * 2.6], [-fwdX() * 3.6, -fwdZ() * 3.6], [fwdX() * 3.6, fwdZ() * 3.6]];
    let s = spots[0]; for (const t of spots) if (!collideAt(pos.x + t[0], 0, pos.z + t[1], player.r, player.height)) { s = t; break; }
    player.pos.set(pos.x + s[0], 0, pos.z + s[1]); player.vel.set(vel.x * 0.3, 0, vel.z * 0.3); player.grounded = true;
    if (!forced && C.state === 'drive') { C.state = 'wait'; C.timer = 15; say('내리게? 기다릴게'); }
  }
  function canBoard() { return C.active && !C.riding && (C.state === 'wait' || C.state === 'arrive') && Math.hypot(pos.x - player.pos.x, pos.z - player.pos.z) < 10 && player.pos.y < 1.5; }
  function damage(dmg, from) {
    if (!C.active || C.state === 'wreck') return;
    C.hp -= dmg; player.shake = Math.max(player.shake, C.riding ? 0.3 : 0.1);
    FX.sparks({ x: pos.x, y: 1.2, z: pos.z }, 12, [1, 0.8, 0.5], 4); Sound.metal(pos); Sound.thud(pos);
    if (C.hp <= 0) wreck();
  }
  function wreck() {
    C.hp = 0; C.state = 'wreck'; C.timer = 18; C.speed = 0;
    if (C.riding) exit(true);
    drv.visible = false; FX.explode({ x: pos.x, y: 1.2, z: pos.z }, true); Sound.boom(pos, true);
    say('차가 망가졌어! 난 먼저 간다!');
  }
  const _p = { x: 0, y: 0, z: 0 };
  function steerTo(tx, tz, vmax, dt) {
    const dx = tx - pos.x, dz = tz - pos.z, dist = Math.hypot(dx, dz);
    let want = Math.atan2(dx, dz), d = Math.atan2(Math.sin(want - C.yaw), Math.cos(want - C.yaw));
    // look ahead for trees and rocks and swerve around them
    const ox = pos.x + fwdX() * 2.4, oz = pos.z + fwdZ() * 2.4;
    if (raycastStatic(ox, 0.8, oz, fwdX(), 0, fwdZ(), 9) && RH.box) {
      const l = !raycastStatic(ox, 0.8, oz, Math.sin(C.yaw + 0.6), 0, Math.cos(C.yaw + 0.6), 8), rr = !raycastStatic(ox, 0.8, oz, Math.sin(C.yaw - 0.6), 0, Math.cos(C.yaw - 0.6), 8);
      d = l && !rr ? 1 : rr && !l ? -1 : (d >= 0 ? 1 : -1); vmax = Math.min(vmax, 6);
    }
    const target = Math.min(vmax, dist * 1.1) * (1 - Math.min(0.6, Math.abs(d) / 2));
    if (C.revT > 0) { C.revT -= dt; C.speed = lerp(C.speed, -4, 1 - Math.exp(-dt * 4)); C.yaw -= Math.sign(d || 1) * 0.6 * dt; }
    else { C.speed += clamp(target - C.speed, -9 * dt, 5 * dt); C.yaw += clamp(d, -1, 1) * 0.95 * Math.min(1, Math.abs(C.speed) / 4) * dt; }
    return dist;
  }
  function drive(dt) {
    vel.set(fwdX() * C.speed, 0, fwdZ() * C.speed);
    _p.x = pos.x; _p.y = 0; _p.z = pos.z;
    const blocked = moveXZ(_p, vel.x * dt, vel.z * dt, 1.5, 1.8, 0.3);
    _p.x = clamp(_p.x, -HALF + 2, HALF - 2); _p.z = clamp(_p.z, -HALF + 2, HALF - 2);
    pos.x = _p.x; pos.z = _p.z;
    if (blocked && Math.abs(C.speed) > 1) { C.speed *= 0.4; C.stuckT += dt; } else if (Math.abs(C.speed) < 0.8 && C.state !== 'wait') C.stuckT += dt; else C.stuckT = Math.max(0, C.stuckT - dt);
    if (C.stuckT > 1.2 && C.revT <= 0) { C.revT = 1.1; C.stuckT = 0; }
    // run over or shove animals in the way
    for (const e of Enemies.list) {
      if (!e.alive) continue;
      const dx = e.pos.x - pos.x, dz = e.pos.z - pos.z, d = Math.hypot(dx, dz), m = 1.9 + e.R;
      if (d < m && d > 0.01) {
        moveXZ(e.pos, dx / d * (m - d), dz / d * (m - d), e.R, e.H, 0);
        if (Math.abs(C.speed) > 6 && !e.bumped) { e.bumped = 0.6; Enemies.damage(e, Math.abs(C.speed) * 6, e.pos, { x: dx / d, y: 0, z: dz / d }, false); Sound.thud(e.pos); }
      }
      if (e.bumped) e.bumped = Math.max(0, e.bumped - dt) || 0;
    }
    const sp = Math.abs(C.speed);
    g.rotation.set(Math.sin(time * 8.7) * 0.012 * sp / 13, C.yaw, Math.sin(time * 6.1) * 0.018 * sp / 13);
    wheels.forEach((w) => { w.rotation.x += C.speed * dt / 0.46; });
    if (sp > 3 && Math.random() < 0.5) FX.puff({ x: pos.x - fwdX() * 2.2 + rand(-0.8, 0.8), y: 0.3, z: pos.z - fwdZ() * 2.2 }, 1, 0.55, 0.9);
  }
  function update(dt) {
    if (!World.style.safari) return; // the savanna and its ranger are gone; no stage has a safari now
    if (!C.active) { C.nextT -= dt; if (C.nextT <= 0 && !Game.ended) arrive(); Sound.engine(0, 0); return; }
    const pd = Math.hypot(pos.x - player.pos.x, pos.z - player.pos.z);
    if (C.state === 'arrive') {
      const side = 4.5, tx = player.pos.x - fwdX() * 0 + Math.cos(C.yaw) * side, tz = player.pos.z - Math.sin(C.yaw) * side;
      const d = steerTo(tx, tz, 13, dt);
      if (d < 3 || (pd < 7 && Math.abs(C.speed) < 2)) { C.state = 'wait'; C.timer = 25; C.speed = 0; Sound.horn(); say(pick(['타! 한 바퀴 태워 줄게', '어이, 걸어 다니면 위험해! 타라', '조수석 비었다, 얼른 타'])); }
      C.timer -= dt;
      if (C.timer <= 0) { if ((C.retries || 0) < 2) { C.retries = (C.retries || 0) + 1; arrive(true); } else { C.state = 'leave'; C.timer = 30; } }
    } else if (C.state === 'wait') {
      C.speed = lerp(C.speed, 0, 1 - Math.exp(-dt * 5));
      if (pd > 16) { C.state = 'arrive'; C.timer = 30; }
      C.timer -= dt; if (C.timer <= 0) { C.state = 'leave'; C.timer = 30; say('바쁜가 보네, 다음에 보자'); }
    } else if (C.state === 'drive') {
      const w = C.path[C.wp];
      if (steerTo(w.x, w.z, 13, dt) < 7) C.wp = (C.wp + 1) % C.path.length;
      C.timer -= dt;
      if (C.timer <= 0) { C.state = 'drop'; }
    } else if (C.state === 'drop') {
      C.speed = lerp(C.speed, 0, 1 - Math.exp(-dt * 3));
      if (Math.abs(C.speed) < 0.6) { exit(true); say('여기까지야, 조심해!'); C.state = 'leave'; C.timer = 30; }
    } else if (C.state === 'leave') {
      const ax = pos.x - player.pos.x, az = pos.z - player.pos.z, l = Math.hypot(ax, az) || 1;
      steerTo(clamp(pos.x + ax / l * 60, -HALF + 4, HALF - 4), clamp(pos.z + az / l * 60, -HALF + 4, HALF - 4), 14, dt);
      C.timer -= dt; if (pd > 120 || C.timer <= 0) { C.active = false; g.visible = false; C.nextT = rand(70, 110); }
    } else if (C.state === 'wreck') {
      C.speed = 0; C.smokeT -= dt;
      if (C.smokeT <= 0) { C.smokeT = 0.12; FX.puff({ x: pos.x + rand(-0.5, 0.5), y: 1.6, z: pos.z + rand(-0.5, 0.5) }, 1, 0.15, 1.2);
        FX.glow.emit({ x: pos.x + rand(-0.6, 0.6), y: 1.3, z: pos.z + rand(-1, 1), vx: rand(-0.3, 0.3), vy: rand(1, 2.5), vz: rand(-0.3, 0.3), max: 0.6, s0: 0.5, s1: 0.1, r: 1, g: 0.5, b: 0.15, a: 0.8, grav: -1, drag: 1 }); }
      C.timer -= dt; if (C.timer <= 0) { C.active = false; g.visible = false; C.nextT = rand(80, 120); }
    }
    if (C.state !== 'wreck') drive(dt);
    // keep the player out of the bodywork while on foot
    if (!C.riding && C.state !== 'off') {
      const dx = player.pos.x - pos.x, dz = player.pos.z - pos.z, d = Math.hypot(dx, dz), m = 2.0 + player.r;
      if (d < m && d > 0.01 && player.pos.y < 2.2) moveXZ(player.pos, dx / d * (m - d), dz / d * (m - d), player.r, player.height, 0);
    }
    Sound.engine(C.state === 'wreck' ? 0 : clamp(1 - pd / 70, 0, 1) * (C.riding ? 0.6 : 0.45), Math.abs(C.speed));
  }
  /* the passenger seat (right-hand side; the driver sits on the left) */
  function seat(out) {
    const rx = -Math.cos(C.yaw), rz = Math.sin(C.yaw);
    return out.set(pos.x + rx * 0.5 + fwdX() * 0.25, 0.48 + Math.sin(time * 8.7) * 0.02 * Math.abs(C.speed) / 13, pos.z + rz * 0.5 + fwdZ() * 0.25);
  }
  return { update, board, exit, damage, reset, canBoard, seat, vel, pos,
    get riding() { return C.riding; }, get state() { return C.state; }, get active() { return C.active; }, get hpFrac() { return clamp(C.hp / 800, 0, 1); },
    toggle() { if (C.riding) exit(false); else if (canBoard()) board(); }, _next() { if (!C.active) C.nextT = 0; } };
})();

/* ============ robots of the ship: walkers, heavies, spider crawlers, drones, turrets and the giant mech ============ */
/* shot: [min burst, max burst, seconds between bolts, damage, min pause, max pause] */
const ROBOTS = {
  trooper: { name: '전투 로봇', hp: 170, speed: 2.4, r: 0.4, h: 1.95, money: 1000, mode: 'gunner', sight: 34, range: 42, near: 8, far: 22, shot: [3, 4, 0.12, 10, 1.2, 2.1], mapKind: 'gunner' },
  heavy: { name: '중장갑 로봇', hp: 650, speed: 1.6, r: 0.4, h: 1.95, money: 2000, mode: 'gunner', sight: 34, range: 44, near: 10, far: 26, shot: [8, 12, 0.08, 8, 1.5, 2.3], mapKind: 'heavy' },
  crawler: { name: '거미 로봇', hp: 130, speed: 7.2, r: 0.55, h: 0.8, money: 1200, mode: 'crawler', sight: 26, dmg: 40, mapKind: 'crawler' },
  drone: { name: '드론', hp: 90, speed: 6, r: 0.45, h: 0.5, money: 1500, mode: 'drone', sight: 40, range: 46, shot: [2, 3, 0.15, 7, 1.0, 1.8], mapKind: 'drone' },
  turret: { name: '포탑', hp: 260, speed: 0, r: 0.55, h: 1.4, money: 1500, mode: 'turret', sight: 55, range: 62, shot: [3, 3, 0.16, 13, 1.6, 2.5], mapKind: 'turret' },
  mech: { name: '거대 전투 로봇', hp: 6500, speed: 1.9, r: 0.4, h: 1.95, money: 2000, mode: 'mech', sight: 60, range: 60, near: 10, far: 30, shot: [14, 20, 0.07, 10, 1.1, 1.7], mapKind: 'boss' },
};
const RGLOW = { trooper: 0x5fe0ff, heavy: 0xff4a3a, crawler: 0xff9a3a, drone: 0xc58bff, turret: 0xff3a3a, mech: 0x5fe0ff };
const rGlowMats = {}; for (const k in RGLOW) rGlowMats[k] = new THREE.MeshBasicMaterial({ color: RGLOW[k] });
const rBarGeo = new THREE.PlaneGeometry(1, 1), rBarBg = new THREE.MeshBasicMaterial({ color: 0x0d1220, transparent: true, opacity: 0.7 });
function buildRobot(type, opts) {
  if (SHIPBOT[ROBOTS[type].mode]) return buildShipBot(type, opts); // the ship's new crew (07h)
  const B = AnimalKit.geoBox, M = AnimalKit.merge, T = ROBOTS[type], gm = rGlowMats[type];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.42, metalness: 0.55, emissive: 0x000000 });
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const e = { type, T, robot: true, g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(0.25, 1.48, 1.15), seed: Math.random() * 10 };
  const mesh = (parent, geo) => { const m = new THREE.Mesh(geo, mat); m.castShadow = !isTouch; parent.add(m); return m; };
  const glow = (parent, sx, sy, sz, x, y, z) => { const m = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), gm); m.position.set(x, y, z); parent.add(m); return m; };
  if (T.mode === 'gunner' || T.mode === 'mech') {
    const heavy = type !== 'trooper', mech = type === 'mech';
    const c1 = mech ? '#8a90a2' : heavy ? '#8a6a66' : '#7c89a3', c2 = mech ? '#5c6170' : heavy ? '#5e4a48' : '#56607a', c3 = '#33384a';
    for (const sx of [-1, 1]) {
      const leg = new THREE.Group(); leg.position.set(sx * 0.14, 0.95, 0); g.add(leg);
      mesh(leg, M([B(0.18, 0.92, 0.2, 0, -0.46, 0, c2), B(0.22, 0.12, 0.34, 0, -0.9, 0.06, c3), B(0.2, 0.14, 0.22, 0, -0.42, 0.02, mech ? '#c9a227' : c1)]));
      if (sx < 0) e.legL = leg; else e.legR = leg;
    }
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.95, 0); g.add(e.upper);
    const up = [B(heavy ? 0.62 : 0.52, 0.62, heavy ? 0.4 : 0.32, 0, 0.36, 0, c1), B(0.44, 0.3, 0.06, 0, 0.42, heavy ? 0.21 : 0.17, mech ? '#c9a227' : '#66748c'),
      B(heavy ? 0.28 : 0.2, 0.14, 0.3, -(heavy ? 0.42 : 0.34), 0.66, 0, c2), B(heavy ? 0.28 : 0.2, 0.14, 0.3, heavy ? 0.42 : 0.34, 0.66, 0, c2),
      B(0.12, 0.08, 0.12, 0, 0.71, 0, c3), B(0.3, 0.24, 0.3, 0, 0.86, 0, c1), B(0.03, 0.22, 0.03, 0.1, 1.06, -0.05, c3)];
    if (mech) up.push(B(0.36, 0.34, 0.5, -0.55, 0.78, -0.02, '#3a3e48'), B(0.3, 0.06, 0.06, -0.55, 0.9, 0.24, '#1c2028'), B(0.3, 0.06, 0.06, -0.55, 0.78, 0.24, '#1c2028'), B(0.3, 0.06, 0.06, -0.55, 0.66, 0.24, '#1c2028'));
    mesh(e.upper, M(up));
    glow(e.upper, 0.24, 0.05, 0.02, 0, 0.88, 0.155); if (heavy) glow(e.upper, 0.12, 0.12, 0.02, 0, 0.42, heavy ? 0.245 : 0.205);
    e.armL = new THREE.Group(); e.armL.position.set(-(heavy ? 0.42 : 0.34), 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3)]));
    e.armR = new THREE.Group(); e.armR.position.set(heavy ? 0.42 : 0.34, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(heavy ? 0.16 : 0.1, 0.52, heavy ? 0.16 : 0.12, 0, -0.86, 0.03, c3)].concat(heavy ? [B(0.05, 0.3, 0.05, 0.05, -1.22, 0.05, '#1c2028'), B(0.05, 0.3, 0.05, -0.05, -1.22, 0.05, '#1c2028')] : [])));
    glow(e.armR, 0.07, 0.05, 0.07, 0, heavy ? -1.38 : -1.14, 0.03);
    e.muzzle.set(heavy ? 0.32 : 0.25, 1.48, heavy ? 1.42 : 1.15);
    e.parts = [{ o: new THREE.Vector3(0, 1.81, 0), r: 0.17, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.33, 0), r: heavy ? 0.4 : 0.33, mult: 1 },
      { o: new THREE.Vector3(0, 0.98, 0), r: 0.25, mult: 0.9 }, { o: new THREE.Vector3(0, 0.5, 0), r: 0.26, mult: 0.7 }];
    e.eyeH = 1.82;
  } else if (T.mode === 'turret') {
    mesh(g, M([B(1.0, 0.25, 1.0, 0, 0.125, 0, '#3e4454'), B(0.5, 0.62, 0.5, 0, 0.56, 0, '#56607a'), B(0.9, 0.06, 0.06, 0, 0.27, 0.47, '#c9a227')]));
    e.head = new THREE.Group(); e.head.position.set(0, 0.95, 0); g.add(e.head);
    mesh(e.head, M([B(0.76, 0.38, 0.8, 0, 0.1, 0, '#7c89a3'), B(0.08, 0.08, 0.72, -0.15, 0.08, 0.62, '#1c2028'), B(0.08, 0.08, 0.72, 0.15, 0.08, 0.62, '#1c2028'), B(0.5, 0.1, 0.5, 0, 0.32, -0.05, '#3a4150')]));
    glow(e.head, 0.2, 0.08, 0.02, 0, 0.18, 0.41);
    e.muzzle.set(0, 1.03, 1.0);
    e.parts = [{ o: new THREE.Vector3(0, 1.13, 0.4), r: 0.16, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.05, 0), r: 0.46, mult: 1 }, { o: new THREE.Vector3(0, 0.4, 0), r: 0.46, mult: 0.6 }];
    e.eyeH = 1.13;
  } else if (T.mode === 'crawler') {
    e.body = new THREE.Group(); g.add(e.body);
    mesh(e.body, M([B(0.8, 0.3, 0.9, 0, 0.5, 0, '#6a7690'), B(0.5, 0.18, 0.5, 0, 0.7, -0.05, '#8a96ae'), B(0.42, 0.24, 0.32, 0, 0.52, 0.55, '#454c60'), B(0.6, 0.05, 0.05, 0, 0.66, 0.2, '#c9a227')]));
    glow(e.body, 0.08, 0.06, 0.02, -0.1, 0.56, 0.72); glow(e.body, 0.08, 0.06, 0.02, 0.1, 0.56, 0.72);
    e.cl = [];
    for (const [x, z] of [[-0.42, 0.3], [0.42, 0.3], [-0.42, -0.3], [0.42, -0.3]]) {
      const p = new THREE.Group(); p.position.set(x, 0.5, z); g.add(p); const sd = Math.sign(x);
      mesh(p, M([B(0.5, 0.07, 0.08, sd * 0.24, 0.05, 0, '#2a2f3a', [0, 0, sd * 0.35]), B(0.07, 0.55, 0.08, sd * 0.5, -0.22, 0, '#3a4150', [0, 0, -sd * 0.25])]));
      e.cl.push(p);
    }
    e.parts = [{ o: new THREE.Vector3(0, 0.5, 0), r: 0.48, mult: 1 }, { o: new THREE.Vector3(0, 0.52, 0.55), r: 0.24, mult: 1, weak: true }];
    e.eyeH = 0.56;
  } else { // drone
    mesh(g, M([B(0.62, 0.16, 0.62, 0, 0, 0, '#7c89a3'), B(0.3, 0.12, 0.3, 0, -0.13, 0.05, '#2a2f3a'), B(0.9, 0.05, 0.07, 0, 0.02, 0, '#3a4150', [0, Math.PI / 4, 0]), B(0.9, 0.05, 0.07, 0, 0.02, 0, '#3a4150', [0, -Math.PI / 4, 0]),
      B(0.06, 0.1, 0.34, 0, -0.2, 0.2, '#1c2028')]));
    glow(g, 0.14, 0.06, 0.04, 0, -0.12, 0.21);
    e.rotors = [];
    for (const [x, z] of [[0.32, 0.32], [-0.32, 0.32], [0.32, -0.32], [-0.32, -0.32]]) {
      const ro = new THREE.Group(); ro.position.set(x, 0.07, z); g.add(ro); mesh(ro, M([B(0.42, 0.015, 0.06, 0, 0, 0, '#202430'), B(0.06, 0.015, 0.42, 0, 0, 0, '#202430')])); e.rotors.push(ro);
    }
    e.muzzle.set(0, -0.2, 0.4);
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 0.42, mult: 1 }, { o: new THREE.Vector3(0, -0.12, 0.22), r: 0.13, mult: 1, weak: true }];
    e.eyeH = 0;
  }
  const bar = new THREE.Group(); const bg = new THREE.Mesh(rBarGeo, rBarBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
  const fill = new THREE.Mesh(rBarGeo, new THREE.MeshBasicMaterial({ color: 0x8ec8ff })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
  bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
  bakeFar(e);
  return e;
}

/* bolts in bursts at you */
function robotFire(e, dt, dist) {
  const T = e.T, S = T.shot;
  e.fireT -= dt;
  if (e.burst > 0) {
    e.burstT -= dt;
    if (e.burstT <= 0) {
      e.burst--; e.burstT = S[2];
      muzzleOf(e, _mz);
      _aim.set(player.pos.x + player.vel.x * dist / 110, player.pos.y + 1.25, player.pos.z + player.vel.z * dist / 110);
      Proj.bullet(_mz, _aim, 62, S[3] * e.dmgMul, 0.3 + dist * 0.024 + player.speedXZ * 0.07 - (e.boss ? 0.12 : 0), true, 'bolt');
      Sound.zap(_mz, T.mode);
    }
    return true;
  }
  if (e.fireT <= 0) { e.burst = randi(S[0], S[1]); e.burstT = 0; e.fireT = rand(S[4], S[5]); }
  return false;
}
function robotWalk(e, sp, dt, aim) {
  e.walk = (e.walk || 0) + dt * sp * 2.4;
  const s = Math.sin(e.walk) * Math.min(1, sp / 2) * 0.55;
  if (e.legL) { e.legL.rotation.x = s; e.legR.rotation.x = -s; }
  if (e.armR) {
    if (aim) { e.armR.rotation.set(-Math.PI / 2 + 0.05, 0, 0); e.armL.rotation.set(-0.9, 0, 0.35); }
    else { e.armR.rotation.set(-s * 0.6, 0, 0); e.armL.rotation.set(s * 0.6, 0, 0); }
  }
  e.flinch = Math.max(0, (e.flinch || 0) - dt * 5); if (e.upper) e.upper.rotation.x = -e.flinch * 0.2;
}
function updateRobot(e, dt, dist, faceYaw) {
  if (SHIPBOT[e.T.mode]) { updateShipBot(e, dt, dist, faceYaw); return; }
  const T = e.T; e.spin = (e.spin || 0) + dt;
  if (e.rotors) for (const ro of e.rotors) ro.rotation.y += dt * 38;
  let mvx = 0, mvz = 0;
  // on watch until it sees or hears you; one that spots you calls the others near it
  if (!e.alert) {
    if ((e.los && dist < T.sight) || dist < 7 || (e.boss && dist < 28)) {
      Enemies.alarm(e);
      for (const o of Enemies.list) if (o.robot && !o.alert && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 16) Enemies.alarm(o);
    } else {
      if (T.mode === 'turret') { e.yaw += Math.sin(e.spin * 0.4 + e.seed) * dt * 0.5; e.g.rotation.y = e.yaw; }
      if (T.mode === 'drone') e.pos.y += Math.sin(e.spin * 1.6 + e.seed) * dt * 0.25;
      if (T.mode === 'gunner' || T.mode === 'mech') robotWalk(e, 0, dt, false);
      return;
    }
  }
  if (T.mode === 'turret') {
    turnToward(e, faceYaw, 2.6, dt);
    if (e.los && dist < T.range) { e.react -= dt; if (e.react <= 0) robotFire(e, dt, dist); } else e.react = Math.max(e.react, 0.4);
    return;
  }
  if (T.mode === 'drone') {
    const ty = clamp(player.pos.y + 4 + Math.sin(e.spin * 1.3 + e.seed) * 1.2, 2.4, 22);
    e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.4));
    e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.4, 3); }
    const fx = _to.x / dist, fz = _to.z / dist, fwd = !e.los || dist > 15 ? 1 : dist < 9 ? -0.7 : 0;
    mvx = (fx * fwd - fz * e.strafe * 0.8) * T.speed; mvz = (fz * fwd + fx * e.strafe * 0.8) * T.speed;
    e.vel.multiplyScalar(Math.exp(-dt * 3));
    if (moveXZ(e.pos, (mvx + e.vel.x) * dt, (mvz + e.vel.z) * dt, e.R, e.H, 0)) e.strafe *= -1;
    e.pos.x = clamp(e.pos.x, -HALF + 1, HALF - 1); e.pos.z = clamp(e.pos.z, -HALF + 1, HALF - 1);
    turnToward(e, faceYaw, 4, dt); e.g.rotation.x = clamp(fwd * 0.18, -0.2, 0.2);
    e.react -= dt;
    if (e.los && dist < T.range && e.react <= 0) robotFire(e, dt, dist);
    return;
  }
  if (T.mode === 'crawler') {
    // rushes you and leaps; one bite of steel is 40
    let dx, dz;
    if (dist < 14 && e.los) { dx = _to.x / dist; dz = _to.z / dist; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { dx = _fd.x; dz = _fd.z; } else { dx = _to.x / dist; dz = _to.z / dist; }
    let sp = e.speed; const sd = stopDist(e);
    e.atkCd = (e.atkCd || 0) - dt;
    if (e.leapT > 0) { e.leapT -= dt; sp *= 0.3; if (e.leapT <= 0 && dist < sd + 0.9 && Math.abs(player.pos.y - e.pos.y) < 1.5) { player.hurt(T.dmg * e.dmgMul, e.pos, 'body'); Sound.thud(e.pos); Sound.metal(e.pos); } }
    else if (dist < sd + 0.6 && e.atkCd <= 0) { e.leapT = 0.22; e.atkCd = 0.95; Sound.zap(e.pos, 'crawler'); }
    if (dist < sd + 0.05) sp = 0;
    turnToward(e, Math.atan2(dx, dz), 8, dt);
    e.vel.multiplyScalar(Math.exp(-dt * 5));
    groundMove(e, dx * sp + e.vel.x, dz * sp + e.vel.z, dt);
    e.walk = (e.walk || 0) + dt * sp * 3.2;
    e.cl.forEach((p, i) => { p.rotation.y = Math.sin(e.walk + i * 1.6) * 0.45; p.rotation.z = Math.max(0, Math.sin(e.walk + i * 1.6)) * 0.25 * Math.sign(p.position.x); });
    e.body.position.y = Math.abs(Math.sin(e.walk * 2)) * 0.04 + (e.leapT > 0 ? 0.25 : 0);
    return;
  }
  // walkers: troopers, heavies and the mech
  const onDeck = e.pos.y > 1.5, sameLevel = Math.abs(e.pos.y - player.pos.y) < 1.5;
  if (e.state === 'move') {
    if (onDeck && !sameLevel) { mvx = 0; mvz = 0; } // up on a deck: hold the high ground
    else if (flowDir(e.pos.x, e.pos.z, _fd) && !onDeck) { mvx = _fd.x * e.speed; mvz = _fd.z * e.speed; } else { mvx = _to.x / dist * e.speed; mvz = _to.z / dist * e.speed; }
    turnToward(e, e.los && dist < 34 ? faceYaw : (mvx || mvz ? Math.atan2(mvx, mvz) : faceYaw), 5, dt);
    if (e.los && dist < T.range) { e.state = 'engage'; e.react = rand(0.4, 0.8) * (e.boss ? 0.6 : 1); }
  } else {
    e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1, 2.6); }
    const fx = _to.x / dist, fz = _to.z / dist, fwd = onDeck && !sameLevel ? 0 : dist > T.far ? 1 : dist < T.near ? -0.8 : 0;
    const st = onDeck && !sameLevel ? 0.25 : 0.6;
    mvx = (fx * fwd - fz * e.strafe * st) * e.speed * 0.55; mvz = (fz * fwd + fx * e.strafe * st) * e.speed * 0.55;
    turnToward(e, faceYaw, 6, dt);
    e.react -= dt;
    if (e.noLos > 1.6 || dist > T.range + 6) e.state = 'move';
    if (e.react <= 0 && e.los && robotFire(e, dt, dist)) { mvx *= 0.4; mvz *= 0.4; }
    if (T.mode === 'mech') {
      // shoulder rockets, two at a time, arcing over cover
      e.rocketT = (e.rocketT === undefined ? 3 : e.rocketT) - dt;
      if (e.rocketT <= 0 && e.los && dist > 8) {
        e.rocketT = rand(4.5, 6.5);
        for (const off of [-1.6, 1.6]) { muzzleOf(e, _mz); _mz.y += 1.2; _aim.set(player.pos.x + rand(-1, 1) * 1.5 + off * 0.4, player.pos.y + 0.3, player.pos.z + rand(-1, 1) * 1.5); Proj.egrenade(_mz, _aim, 'gl'); }
      }
    }
  }
  e.vel.multiplyScalar(Math.exp(-dt * 6));
  const blocked = groundMove(e, mvx + e.vel.x, mvz + e.vel.z, dt);
  if (blocked && e.state === 'engage') e.strafe *= -1;
  robotWalk(e, Math.hypot(mvx, mvz), dt, e.state === 'engage');
}
/* ============ the lab's boss: a giant lowland gorilla, and the smaller gorillas it calls down ============ */
// boss: huge and fast. big alternating haymakers (500 a hit), frequent straight-line charges (300 and a 3 s stun, almost no recovery),
// now and then a huge leap that lands where you stood (instant death inside the red ring), and a chest-beating roar that calls 7 gorillas.
// minions: a quarter of the boss's health and damage, the same punches and charges, but the charge is slow with a long recovery,
// it stuns for 1 s, and they never leap.
const KONG = {
  boss: { run: 7.6, charge: 24, chargeT: 1.15, windup: 0.32, recover: 0.12, punch: 500, chargeDmg: 300, stun: 3, swing: 0.62, chargeCd: [2.2, 3.6], reach: 1.9 },
  minion: { run: 6.0, charge: 12, chargeT: 1.4, windup: 0.8, recover: 1.7, punch: 125, chargeDmg: 75, stun: 1, swing: 0.72, chargeCd: [5, 8], reach: 0.75 },
  slamR: 5.5, summonMax: 4, minionsAt: 7,
};
const KNUCKLE = { lean: 0.6, twist: 0, head: -0.35, aLx: -1.1, aLy: 0, aRx: -1.1, aRy: 0, fL: 0.15, fR: 0.15, lL: 0, lR: 0, sL: 0, sR: 0, y: 0 };
const KONG_HIP = 0.62;
function kongPose(rig, P, k) {
  const c = rig.pose || (rig.pose = Object.assign({}, P));
  for (const key in P) c[key] += (P[key] - c[key]) * k;
  rig.torso.rotation.x = c.lean; rig.torso.rotation.y = c.twist; rig.head.rotation.x = c.head;
  rig.armL.rotation.x = c.aLx; rig.armL.rotation.y = c.aLy; rig.armR.rotation.x = c.aRx; rig.armR.rotation.y = c.aRy;
  rig.foreL.rotation.x = c.fL; rig.foreR.rotation.x = c.fR;
  rig.legL.rotation.x = c.lL; rig.legR.rotation.x = c.lR; rig.shinL.rotation.x = c.sL; rig.shinR.rotation.x = c.sR;
  rig.hips.position.y = KONG_HIP + c.y;
}
/* big animals do not stop for a wooden crate: they smash it */
function smashAhead(e, dx, dz) {
  const b = collideAt(e.pos.x + dx * 0.45, e.pos.y + 0.05, e.pos.z + dz * 0.45, e.R, Math.min(e.H, 2));
  if (b && b.ref && b.kind === 'wood' && crates.includes(b.ref)) { damageCrate(b.ref, 999, { x: b.ref.x, y: (b.ref.y || 0) + 0.6, z: b.ref.z }); return true; }
  return false;
}
const KongKit = (() => {
  const B = AnimalKit.geoBox, M = AnimalKit.merge;
  function build(boss) {
    const fur = '#1d1c1e', dark = '#141315', skin = '#37312e', silver = boss ? '#9a9a9c' : '#4b4a4c', eye = boss ? '#d33a1a' : '#c08a2a';
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.88, emissive: 0x000000 });
    const g = new THREE.Group(); g.rotation.order = 'YXZ';
    const mesh = (parent, list) => { const m = new THREE.Mesh(M(list), mat); m.castShadow = !isTouch; parent.add(m); return m; };
    // a gorilla's build: a huge chest and shoulders, a silver saddle, long thick arms, short legs, the head sunk between the shoulders
    const hips = new THREE.Group(); hips.position.set(0, KONG_HIP, -0.1); g.add(hips);
    const torso = new THREE.Group(); torso.rotation.order = 'YXZ'; hips.add(torso);
    const body = mesh(torso, [B(1.12, 0.86, 0.72, 0, 0.5, 0.05, fur), B(0.86, 0.46, 0.62, 0, 0.1, 0.07, fur), B(1.3, 0.38, 0.7, 0, 0.84, 0.02, fur),
      B(0.82, 0.56, 0.08, 0, 0.46, -0.33, silver), B(0.66, 0.4, 0.06, 0, 0.54, 0.43, skin), B(0.5, 0.3, 0.06, 0, 0.12, 0.39, skin)]);
    const chest = new THREE.Object3D(); chest.position.set(0, 0.5, 0.1); torso.add(chest);
    const head = new THREE.Group(); head.position.set(0, 0.95, 0.26); torso.add(head);
    mesh(head, [B(0.48, 0.46, 0.46, 0, 0.1, 0, fur), B(0.22, 0.18, 0.34, 0, 0.37, -0.05, fur), B(0.46, 0.1, 0.11, 0, 0.21, 0.22, dark),
      B(0.34, 0.26, 0.17, 0, -0.02, 0.24, skin), B(0.32, 0.1, 0.19, 0, -0.16, 0.19, skin), B(0.06, 0.04, 0.02, -0.1, 0.12, 0.282, eye), B(0.06, 0.04, 0.02, 0.1, 0.12, 0.282, eye),
      B(0.12, 0.05, 0.03, 0, 0.0, 0.33, '#201c1b')]);
    const headC = new THREE.Object3D(); headC.position.set(0, 0.1, 0.05); head.add(headC);
    const arm = (sx) => {
      const a = new THREE.Group(); a.rotation.order = 'YXZ'; a.position.set(sx * 0.68, 0.74, 0.08); torso.add(a);
      mesh(a, [B(0.38, 0.66, 0.38, 0, -0.3, 0, fur)]);
      const f = new THREE.Group(); f.position.set(0, -0.6, 0); a.add(f);
      mesh(f, [B(0.33, 0.6, 0.33, 0, -0.28, 0, fur), B(0.4, 0.28, 0.42, 0, -0.62, 0.02, skin)]);
      return { a, f };
    };
    const L = arm(-1), R = arm(1);
    const leg = (sx) => {
      const l = new THREE.Group(); l.position.set(sx * 0.3, 0, -0.02); hips.add(l);
      mesh(l, [B(0.36, 0.38, 0.38, 0, -0.16, 0.02, fur)]);
      const sh = new THREE.Group(); sh.position.set(0, -0.32, 0.05); l.add(sh);
      mesh(sh, [B(0.32, 0.26, 0.32, 0, -0.12, 0, fur), B(0.36, 0.08, 0.48, 0, -0.27, 0.1, skin)]);
      return { l, sh };
    };
    const LL = leg(-1), LR = leg(1);
    const rig = { hips, torso, head, chest, armL: L.a, foreL: L.f, armR: R.a, foreR: R.f, legL: LL.l, shinL: LL.sh, legR: LR.l, shinR: LR.sh, pose: null };
    kongPose(rig, KNUCKLE, 1); // the footprint and the far model are taken in this pose
    const parts = [{ o: new THREE.Vector3(0, 1.42, 0.55), r: 0.27, mult: 1, weak: true, node: headC }, { o: new THREE.Vector3(0, 1.15, 0.25), r: 0.6, mult: 1, node: chest },
      { o: new THREE.Vector3(0, 0.82, -0.12), r: 0.5, mult: 1 }, { o: new THREE.Vector3(0, 0.36, -0.1), r: 0.38, mult: 0.7 }];
    return { g, body, mat, legs: [], parts, rig };
  }
  return { build };
})();
/* the red ring on the floor where the boss will come down */
const Kong = (() => {
  let ring = null, fill = null, on = false, R = 1, t0 = 0;
  function ensure() {
    if (ring) return;
    ring = new THREE.Mesh(new THREE.RingGeometry(0.9, 1, 64), new THREE.MeshBasicMaterial({ color: 0xff2020, transparent: true, opacity: 0.9, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }));
    fill = new THREE.Mesh(new THREE.CircleGeometry(0.9, 48), new THREE.MeshBasicMaterial({ color: 0xff2020, transparent: true, opacity: 0.18, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }));
    [ring, fill].forEach((m) => { m.rotation.x = -Math.PI / 2; m.visible = false; m.renderOrder = 2; scene.add(m); });
  }
  return {
    warn(x, z, r) { ensure(); R = r; on = true; t0 = time; [ring, fill].forEach((m) => { m.position.set(x, 0.05, z); m.scale.setScalar(r); m.visible = true; }); },
    unwarn() { on = false; if (ring) { ring.visible = fill.visible = false; } },
    tick() { if (!on || !ring) return; const k = time - t0; ring.material.opacity = 0.55 + 0.4 * Math.abs(Math.sin(k * 9)); fill.material.opacity = 0.12 + 0.12 * Math.min(1, k / 1.8); },
    reset() { this.unwarn(); },
  };
})();
const _kv = new THREE.Vector3();
function kongFree(x, z, r, h) {
  for (let rr = 0; rr <= 9; rr += 0.75) for (let i = 0, n = rr ? 12 : 1; i < n; i++) {
    const a = (i / n) * TAU, px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr;
    if (Math.abs(px) < HALF - r - 0.4 && Math.abs(pz) < HALF - r - 0.4 && !collideAt(px, 0.05, pz, r, h)) return { x: px, z: pz };
  }
  return null;
}
const kongMinions = () => Enemies.list.reduce((n, o) => n + (o.alive && o.minion ? 1 : 0), 0);
/* the boss's roar calls seven gorillas down from the roof trusses around it */
function kongSummon(e) {
  const k = e.k; k.summons++; let made = 0;
  for (let i = 0; i < KONG.minionsAt; i++) {
    const a = (i / KONG.minionsAt) * TAU + rand(-0.25, 0.25), r = rand(5, 8), p = kongFree(e.pos.x + Math.cos(a) * r, e.pos.z + Math.sin(a) * r, 0.9, 2.2);
    if (!p) continue;
    const m = Enemies.spawn('gorilla', p.x, p.z, { kong: true, minion: true, hp: Math.round(e.maxHp / 4), scale: 1.15, dmgMul: e.dmgMul, y: rand(9, 12), name: '고릴라 졸개',
      yaw: Math.atan2(player.pos.x - p.x, player.pos.z - p.z) });
    m.fury = true; m.angry = true; m.alert = true; m.awake = true; m.lod = 0;
    m.k = { mode: 'drop', t: 0, combo: 0, arm: 1, hit: false, chargeCd: rand(2, 4), jumpCd: 99, summonCd: 99, summons: 0, phase: rand(0, 6), engaged: 0 };
    made++;
  }
  if (!made) return;
  Game.goal += made;
  HUD.banner('고릴라 ' + made + '마리 소환', '보스가 가슴을 두드려 동료를 불렀습니다', 2.2);
  HUD.feed('고릴라 졸개 ' + made + '마리가 내려옵니다', 0, 'hs');
}
function updateKong(e, dt, time, dist, faceYaw) {
  const K = e.boss ? KONG.boss : KONG.minion, sc = e.scale || 1;
  const k = e.k || (e.k = { mode: e.caged ? 'cidle' : 'chase', t: rand(0, 2), combo: 0, arm: 1, hit: false, chargeCd: rand(1.2, 2.5), jumpCd: rand(5, 8), summonCd: 0, summons: 0, phase: 0, engaged: 0 });
  const P = Object.assign({}, KNUCKLE), tx = (player.pos.x - e.pos.x) / dist, tz = (player.pos.z - e.pos.z) / dist;
  const set = (m) => { k.mode = m; k.t = 0; k.hit = false; };
  const reachP = stopDist(e) + K.reach, upright = Math.abs(player.pos.y - e.pos.y) < 2.6 * sc;
  let sp = 0, dirx = 0, dirz = 0, rate = 12, turn = 6, gallop = false, move = true;
  k.t += dt;
  if (!e.caged) { k.chargeCd -= dt; k.jumpCd -= dt; k.summonCd -= dt; k.engaged += dt; }
  // 3-1's lowland gorillas live wild until something sets them off (you close by, a shot, a hit, the stampede);
  // then, while you hold the watchtower, they go for the tower with their fists like the rest
  if (e.wild) {
    if (!e.angry && (dist < 22 || e.hp < e.maxHp)) { e.angry = true; e.alert = true; }
    if (!e.angry) { if (k.mode !== 'wander') set('wander'); }
    else if (k.mode === 'wander') { e.fury = true; set('roar'); }
    else if (Tower.holds()) { if (k.mode !== 'roar' && k.mode !== 'sgo' && k.mode !== 'swait' && k.mode !== 'spunch') set('sgo'); }
    else if (k.mode === 'sgo' || k.mode === 'swait' || k.mode === 'spunch') set('chase');
  }
  // just let out: rear up and roar
  if (e.releaseT > 0) { e.releaseT -= dt; if (e.releaseT <= 0) { set('roar'); e.fury = true; e.angry = true; e.alert = true; } }
  switch (k.mode) {
    /* ---- 3-1: out on the plain ---- */
    case 'wander':
      if (k.wx === undefined || Math.hypot(k.wx - e.pos.x, k.wz - e.pos.z) < 1.5 || k.t > 14) {
        const a = rand(0, TAU), r = rand(5, 16); k.wx = clamp(e.pos.x + Math.cos(a) * r, -HALF + 4, HALF - 4); k.wz = clamp(e.pos.z + Math.sin(a) * r, -HALF + 4, HALF - 4); k.t = 0; k.sit = Math.random() < 0.45 ? rand(2, 6) : 0;
      }
      if (k.sit > 0) { k.sit -= dt; move = false; P.lean = 0.15; P.head = -0.15 + Math.sin(time * 0.7 + e.walk) * 0.25; P.aLx = P.aRx = -0.6; }
      else { const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz) || 1; dirx = dx / l; dirz = dz / l; sp = 1.4; turn = 3; }
      break;
    case 'sgo': case 'swait': case 'spunch': {
      // at the watchtower: a place along its foot, or a wait a little way off; then fists into the planks
      k.claimT = (k.claimT || 0) - dt;
      let slot = e.slot && e.slot.owner === e ? Tower.claim(e) : null;
      if (!slot && k.claimT <= 0) { k.claimT = rand(0.4, 0.7); slot = Tower.claim(e); }
      if (!slot) {
        if (k.mode !== 'swait') { set('swait'); const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.4, 0.4), r = rand(9.5, 13); k.wx = Tower.x + Math.cos(a) * r; k.wz = Tower.z + Math.sin(a) * r; }
        const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz);
        if (l > 1.2) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = dx / l; dirz = dz / l; } sp = l > 16 ? K.run : 2; }
        else { move = false; turnToward(e, Math.atan2(Tower.x - e.pos.x, Tower.z - e.pos.z), 3, dt); if ((k.t % 6) < 1.6) beatPose(P, k); }
        break;
      }
      const gx = slot.x + slot.nx * (stopDist(e) + 0.25), gz = slot.z + slot.nz * (stopDist(e) + 0.25), inFace = Math.atan2(-slot.nx, -slot.nz);
      if (k.mode === 'spunch') {
        const S = K.swing, u = k.t / S, side = k.arm, A = side > 0 ? 'aR' : 'aL', O = side > 0 ? 'aL' : 'aR';
        move = false; turnToward(e, inFace, 6, dt); P.lean = 0.32; P.head = -0.25; P[O + 'x'] = -1.15;
        if (u < 0.38) { P[A + 'x'] = -2.0; P[A + 'y'] = side * 1.7; P.twist = -side * 0.45; rate = 16; }
        else if (u < 0.62) { const w = (u - 0.38) / 0.24; P[A + 'x'] = -1.55; P[A + 'y'] = side * (1.7 - 2.3 * w); P.twist = side * (-0.45 + 0.9 * w); rate = 40;
          if (!k.hit && u >= 0.5) { k.hit = true; _kv.set(slot.x, 1.6, slot.z); Tower.hurt(SIEGE.gorilla.dmg, e, _kv); Sound.thud(_kv); } }
        else { P[A + 'x'] = -1.3; P[A + 'y'] = -side * 0.5; P.twist = side * 0.4; }
        if (k.t >= S) { k.combo--; k.arm = -k.arm; if (k.combo > 0) { k.t = 0; k.hit = false; } else { set('sgo'); k.rest = rand(SIEGE.gorilla.cd[0], SIEGE.gorilla.cd[1]); } }
        break;
      }
      if (k.mode !== 'sgo') set('sgo');
      const dx = gx - e.pos.x, dz = gz - e.pos.z, l = Math.hypot(dx, dz);
      k.rest = (k.rest || 0) - dt;
      if (l > 0.6) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = dx / l; dirz = dz / l; } sp = l > 4 ? K.run : 2.2; }
      else { move = false; turnToward(e, inFace, 6, dt); if (k.rest <= 0 && k.t > 0.3) { set('spunch'); k.combo = randi(2, 3); if (Math.random() < 0.4) Sound.roar(e.pos, 'grunt'); } }
      break;
    }
    /* ---- inside the cage ---- */
    case 'cidle':
      if (dist < 26) turnToward(e, faceYaw, 2, dt);
      if (k.t > 2.5) { const r = Math.random(); set(r < 0.3 ? 'cbeat' : r < 0.6 && dist < 26 ? 'clunge' : 'cpace'); k.cx = tx; k.cz = tz;
        const c = e.cage, ix = c.w / 2 - 0.5 - e.R, iz = c.d / 2 - 0.5 - e.R; k.wx = c.x + rand(-ix, ix); k.wz = c.z + rand(-iz, iz); }
      break;
    case 'cpace': {
      const dx = k.wx - e.pos.x, dz = k.wz - e.pos.z, l = Math.hypot(dx, dz);
      if (l < 0.8 || k.t > 4) set('cidle'); else { dirx = dx / l; dirz = dz / l; sp = 2.2; turn = 3; }
      break;
    }
    case 'clunge': dirx = k.cx; dirz = k.cz; sp = 6; turn = 4; if (k.t > 1.2) set('cidle'); break;
    case 'cbeat': beatPose(P, k); move = false; if (k.t > 0.15 && !k.hit) { k.hit = true; Sound.roar(e.pos, 'beat'); } if (k.t > 1.8) set('cidle'); break;
    /* ---- loose ---- */
    case 'roar':
      move = false; P.lean = -0.1; P.aLx = -2.2; P.aLy = -0.8; P.aRx = -2.2; P.aRy = 0.8; P.head = -0.7; P.lL = P.lR = -0.2; P.sL = P.sR = 0.35; P.y = -0.05;
      turnToward(e, faceYaw, 4, dt);
      if (!k.hit && k.t > 0.1) { k.hit = true; Sound.roar(e.pos, 'beat'); Sound.rage(e.pos); player.shake = Math.max(player.shake, 0.35); }
      if (k.t > 1.4) { set('chase'); k.engaged = 0; }
      break;
    case 'drop': // minions coming down from the roof
      move = false; P.lean = 0.3; P.aLx = P.aRx = -2.4; P.lL = P.lR = -0.5; P.sL = P.sR = 0.8;
      groundMove(e, 0, 0, dt);
      if (e.pos.y <= groundAt(e.pos.x, e.pos.y, e.pos.z, e.R) + 0.01) { FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 6, 0.8, 0.8); Sound.thud(e.pos); set('chase'); }
      break;
    case 'chase':
      if (dist < 40 && e.los) { dirx = tx; dirz = tz; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { dirx = _fd.x; dirz = _fd.z; } else { dirx = tx; dirz = tz; }
      sp = dist > reachP * 0.9 ? K.run : 0; turn = 7;
      if (dist < reachP && (upright || Ride.m)) { set('punch'); k.combo = randi(2, 4); }
      else if (k.chargeCd <= 0 && dist > (e.boss ? 7 : 5) && dist < 34 && e.los) { set('windup'); Sound.roar(e.pos, 'grunt'); }
      else if (e.boss && k.jumpCd <= 0 && dist > 8 && dist < 30 && e.los) { set('crouch'); k.tgx = player.pos.x; k.tgz = player.pos.z; Kong.warn(k.tgx, k.tgz, KONG.slamR); }
      else if (e.boss && k.summons < KONG.summonMax && k.summonCd <= 0 && (e.hp < e.maxHp * 0.85 || k.engaged > 14) && kongMinions() < KONG.minionsAt) set('beat');
      break;
    case 'punch': {
      // big haymakers, left and right in turn
      const S = K.swing, u = k.t / S, side = k.arm, A = side > 0 ? 'aR' : 'aL', O = side > 0 ? 'aL' : 'aR';
      turnToward(e, faceYaw, 5, dt); sp = dist > reachP * 0.7 ? 1.6 * sc : 0; dirx = tx; dirz = tz;
      P.lean = 0.32; P.head = -0.25; P[O + 'x'] = -1.15; P[O + 'y'] = 0;
      if (u < 0.38) { P[A + 'x'] = -2.0; P[A + 'y'] = side * 1.7; P.twist = -side * 0.45; rate = 16; }
      else if (u < 0.62) {
        const w = (u - 0.38) / 0.24; P[A + 'x'] = -1.55; P[A + 'y'] = side * (1.7 - 2.3 * w); P.twist = side * (-0.45 + 0.9 * w); rate = 40;
        if (!k.hit && u >= 0.5) {
          k.hit = true; Sound.swoosh(e.pos);
          let d = faceYaw - e.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
          if (dist < reachP + 0.5 && Math.abs(d) < 1.3 && Ride.m) { Ride.hurtMount(K.punch * (e.dmgMul || 1), e); Sound.thud(player.pos); } // up on any animal: the one under you takes it
          else if (dist < reachP + 0.5 && Math.abs(d) < 1.3 && upright) {
            player.hurt(K.punch * (e.dmgMul || 1), e.pos, 'head'); Sound.thud(player.pos); // haymakers to the head
            if (!e.boss && !Game.ended) Bleed.add(); // a minion's blows open wounds; the boss's do not
            player.vel.x += (Math.cos(e.yaw) * -side + tx * 0.5) * (e.boss ? 9 : 5); player.vel.z += (-Math.sin(e.yaw) * -side + tz * 0.5) * (e.boss ? 9 : 5);
            player.shake = Math.max(player.shake, e.boss ? 0.55 : 0.3);
          }
        }
      } else { P[A + 'x'] = -1.3; P[A + 'y'] = -side * 0.5; P.twist = side * 0.4; }
      if (k.t >= S) { k.combo--; k.arm = -k.arm; if (k.combo > 0 && dist < reachP + 1) { k.t = 0; k.hit = false; } else set('chase'); }
      break;
    }
    case 'windup':
      move = false; P.lean = 1.05; P.head = -0.7; P.aLx = P.aRx = -1.3; P.lL = P.lR = -0.35; P.sL = P.sR = 0.6; P.y = -0.08;
      turnToward(e, faceYaw, 10, dt);
      if (k.t >= K.windup) { set('charge'); k.cx = Math.sin(e.yaw); k.cz = Math.cos(e.yaw); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 3, 0.6 * sc, 0.6); }
      break;
    case 'charge':
      dirx = k.cx; dirz = k.cz; sp = K.charge; turn = 0; gallop = true;
      if (Math.random() < dt * 14) FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 1, 0.5 * sc, 0.4);
      if (!k.hit && dist < stopDist(e) + 0.7 && (upright || Ride.m)) {
        k.hit = true;
        if (Ride.m) Ride.hurtMount(K.chargeDmg * (e.dmgMul || 1), e);
        else { Game.stun(e, K.chargeDmg * (e.dmgMul || 1), K.stun); if (!e.boss && !Game.ended) Bleed.add(); }
        set('recover'); k.rec = K.recover;
      }
      else if (k.t >= K.chargeT) { set('recover'); k.rec = K.recover; }
      break;
    case 'stagger': move = false; P.lean = 0.5; P.head = 0.2 + Math.sin(k.t * 10) * 0.15; if (k.t >= k.rec) { set('chase'); k.chargeCd = rand(K.chargeCd[0], K.chargeCd[1]); } break;
    case 'recover':
      sp = 0; P.lean = e.boss ? 0.7 : 0.55; if (!e.boss) { P.head = -0.1 + Math.sin(k.t * 9) * 0.12; P.aLx = P.aRx = -0.7; }
      if (k.t >= k.rec) { set('chase'); k.chargeCd = rand(K.chargeCd[0], K.chargeCd[1]); }
      break;
    case 'crouch': // gathering for the leap
      move = false; P.lean = 0.85; P.lL = P.lR = -1.0; P.sL = P.sR = 1.5; P.y = -0.25; P.aLx = P.aRx = 0.3; P.head = -0.6;
      turnToward(e, Math.atan2(k.tgx - e.pos.x, k.tgz - e.pos.z), 8, dt);
      if (k.t >= 0.5) {
        const T = 1.9; k.vx = (k.tgx - e.pos.x) / T; k.vz = (k.tgz - e.pos.z) / T; k.vy = 15 * T / 2; k.air = T;
        set('air'); Sound.roar(e.pos, 'grunt'); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 8, 1.2 * sc, 1);
      }
      break;
    case 'air': {
      move = false; e.pos.x += k.vx * dt; e.pos.z += k.vz * dt; k.vy -= 15 * dt; e.pos.y = Math.max(0, e.pos.y + k.vy * dt);
      const u = k.t / k.air; P.lean = u < 0.62 ? -0.1 : 0.5; P.aLx = P.aRx = u < 0.62 ? -2.9 : -0.9; P.lL = P.lR = -0.6; P.sL = P.sR = 0.9; P.head = -0.4; rate = u < 0.62 ? 8 : 22;
      if (e.pos.y <= 0 && k.vy < 0) {
        // the slam: inside the ring you are dead, near it you are thrown
        e.pos.y = 0; Kong.unwarn();
        const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 0.01;
        for (let i = 0; i < 16; i++) { const a = (i / 16) * TAU; FX.puff({ x: e.pos.x + Math.cos(a) * KONG.slamR * 0.8, y: 0.3, z: e.pos.z + Math.sin(a) * KONG.slamR * 0.8 }, 2, 1.2, 1); }
        FX.chunks({ x: e.pos.x, y: 0.3, z: e.pos.z }, 10, 0.25, 'wood'); Sound.quake(e.pos);
        player.shake = Math.max(player.shake, d < 30 ? 0.25 + 0.6 * (1 - d / 30) : 0); buzz(200);
        if (d < KONG.slamR && (Ride.m || player.pos.y < 2.2 + groundAt(player.pos.x, player.pos.y, player.pos.z, player.r))) Game.slam(e); // riding does not save you from this one
        else if (d < KONG.slamR * 1.9) { player.vel.x += dx / d * 10; player.vel.z += dz / d * 10; player.vel.y = 4; player.grounded = false; }
        const p = kongFree(e.pos.x, e.pos.z, e.R, e.H); if (p) { e.pos.x = p.x; e.pos.z = p.z; }
        set('land'); k.jumpCd = rand(9, 13);
      }
      break;
    }
    case 'land': move = false; P.lean = 0.95; P.aLx = P.aRx = -1.25; P.lL = P.lR = -0.5; P.sL = P.sR = 0.8; P.y = -0.15; if (k.t >= 0.6) set('chase'); break;
    case 'beat': // chest-beating roar: seven gorillas come down
      move = false; beatPose(P, k); turnToward(e, faceYaw, 3, dt);
      if (!k.hit && k.t > 0.15) { k.hit = true; Sound.roar(e.pos, 'beat'); }
      if (k.t > 1.5 && !k.called) { k.called = true; kongSummon(e); }
      if (k.t > 1.8) { set('chase'); k.called = false; k.summonCd = rand(22, 28); }
      break;
  }
  if (k.mode === 'crouch' || k.mode === 'air') Kong.tick();
  // movement
  if (move && k.mode !== 'air') {
    e.vel.multiplyScalar(Math.exp(-dt * 4));
    const walking = k.mode === 'chase' || k.mode === 'sgo' || k.mode === 'swait' || k.mode === 'wander';
    if (e.detourT > 0) { e.detourT -= dt; if (walking) { dirx = e.dx2; dirz = e.dz2; } }
    const x0 = e.pos.x, z0 = e.pos.z;
    let blocked = groundMove(e, dirx * sp + e.vel.x, dirz * sp + e.vel.z, dt);
    if (walking && sp > 0.5) unstick(e, x0, z0, dirx, dirz, sp, dt);
    if (blocked && (k.mode === 'charge' || (e.boss && k.mode === 'chase')) && smashAhead(e, dirx, dirz)) blocked = false;
    if (blocked && k.mode === 'charge') { set('stagger'); k.rec = e.boss ? 0.45 : 2.2; FX.puff({ x: e.pos.x + k.cx * e.R, y: 1, z: e.pos.z + k.cz * e.R }, 6, 0.6 * sc, 0.8); Sound.thud(e.pos); }
    if (blocked && k.mode === 'clunge') { set('cidle'); Lab.rattle(e.cage, e.pos.x + dirx * e.R, e.pos.z + dirz * e.R); }
    if (sp > 0.1 && turn > 0) turnToward(e, k.mode === 'chase' && dist < 14 ? faceYaw : Math.atan2(dirx, dirz), turn, dt);
  }
  if (sp > 0.1) kongGait(P, k, sp, dt, gallop, sc);
  kongPose(e.rig, P, 1 - Math.exp(-dt * rate));
  // keep the head and chest hit spheres on the moving body
  const cy = Math.cos(e.yaw), sy = Math.sin(e.yaw);
  for (const p of e.parts) if (p.node) {
    p.node.getWorldPosition(_kv); const dx = _kv.x - e.pos.x, dy = _kv.y - e.pos.y, dz = _kv.z - e.pos.z;
    p.o.set((dx * cy - dz * sy) / sc, dy / sc, (dx * sy + dz * cy) / sc);
  }
  e.roarT = (e.roarT || rand(4, 9)) - dt; if (e.roarT <= 0) { e.roarT = rand(6, 12); if (dist < 40) Sound.roar(e.pos, 'grunt'); }
}
function beatPose(P, k) {
  const L = Math.sin(k.t * 40) > 0;
  P.lean = -0.05; P.head = -0.35; P.lL = P.lR = -0.25; P.sL = P.sR = 0.4; P.y = -0.06;
  P.aLx = -0.9; P.aLy = L ? 1.1 : 0.55; P.fL = L ? -1.85 : -1.3;
  P.aRx = -0.9; P.aRy = L ? -0.55 : -1.1; P.fR = L ? -1.3 : -1.85;
}
function kongGait(P, k, sp, dt, gallop, sc) {
  const g = Math.min(1, sp / 5);
  k.phase += dt * (1.6 + sp * (gallop ? 1.0 : 0.85) / Math.sqrt(sc));
  const s = Math.sin(k.phase), c = Math.cos(k.phase), amp = gallop ? 0.75 : 0.55;
  P.aLx += s * amp * g; P.aRx -= s * amp * g; P.lL = -s * 0.5 * g; P.lR = s * 0.5 * g;
  P.sL = Math.max(0, c) * 0.6 * g; P.sR = Math.max(0, -c) * 0.6 * g; P.y = Math.abs(s) * 0.05 * g; P.twist = s * 0.08 * g;
}
/* ============ the lab's beasts each fight their own way; what they do to you (bleeding, fear, being tossed); riding them ============ */

/* ---------- the animals hit half as hard as they used to, bleeding included. the giant gorilla and its minions are left as they were ---------- */
const BEAST_DMG = 0.5, BLEED_DPS = 5;
/* ---------- bleeding: every wound takes 5 a second for 10 seconds. a fresh wound adds one more and restarts the clock for all of them.
   the animal you ride bleeds the same way when the others get at it ---------- */
const Bleed = {
  n: 0, t: 0, acc: 0, beasts: new Set(),
  add() {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return;
    this.n++; this.t = 10;
    HUD.feed('출혈' + (this.n > 1 ? ' ' + this.n + '중첩' : '') + ' · 10초 동안 초당 ' + BLEED_DPS * this.n, 0, 'hs');
  },
  addTo(m) {
    if (!m || !m.alive || Game.ended) return;
    m.bleedN = (m.bleedN || 0) + 1; m.bleedT = 10; m.bleedAcc = m.bleedAcc || 0; this.beasts.add(m);
    if (m.ridden) HUD.feed(m.T.name + ' 출혈' + (m.bleedN > 1 ? ' ' + m.bleedN + '중첩' : '') + ' · 10초 동안 초당 ' + BLEED_DPS * m.bleedN, 0, 'hs');
  },
  /* a potion stops yours; leaving the stage stops everyone's */
  stop(all) {
    this.n = 0; this.t = 0; this.acc = 0;
    if (all) { for (const m of this.beasts) { m.bleedN = 0; m.bleedT = 0; m.bleedAcc = 0; } this.beasts.clear(); }
  },
  update(dt) {
    for (const m of this.beasts) {
      if (!m.alive) { this.beasts.delete(m); continue; }
      m.bleedT -= dt; m.bleedAcc += BLEED_DPS * m.bleedN * dt;
      const d = Math.floor(m.bleedAcc);
      if (d > 0) { m.bleedAcc -= d; Ride.bleedOut(m, d); }
      if (m.bleedT <= 0 || !m.alive) { m.bleedN = 0; m.bleedT = 0; m.bleedAcc = 0; this.beasts.delete(m); }
    }
    if (this.t <= 0) return;
    this.t -= dt; this.acc += BLEED_DPS * this.n * dt;
    const d = Math.floor(this.acc);
    if (d > 0) {
      this.acc -= d;
      if (player.invuln <= 0 && !Game.ended) { player.hp -= d; if (player.hp <= 0) { player.hp = 0; this.stop(); Game.over('bleed'); return; } }
    }
    if (this.t <= 0) { this.stop(); HUD.feed('출혈이 멎었습니다', 0); }
  },
};

/* ---------- a tiger's roar: for one second your legs carry you away from it, whatever you press. up on a giraffe or an elephant you keep your nerve ---------- */
const Fear = {
  t: 0, x: 0, z: 0,
  apply(e) {
    if (state !== 'playing' || Game.ended || player.invuln > 0 || Ride.brave() || Toss.on) return false;
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    this.x = dx / d; this.z = dz / d; this.t = 1;
    player.shake = Math.max(player.shake, 0.25); buzz(80);
    HUD.feed('호랑이 포효 · 겁에 질려 1초 동안 도망칩니다', 0, 'hs');
    return true;
  },
};

/* ---------- a rhino's horn: straight up into the air (no sideways drift). caught again on the way down, you go higher than the time before ---------- */
const _tp = new THREE.Vector3(), _td = new THREE.Vector3();
const Toss = {
  on: false, v: 0, n: 0,
  launch(e) {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return;
    if (Ride.m) { Ride.hurtMount(e.T.dmg * (e.dmgMul || 1) * BEAST_DMG, e); return; } // up on any animal: it takes the horn, you stay on
    jetEnd(); Fear.t = 0;
    this.v = this.on ? Math.min(this.v + 3.6, 26) : 13; this.n = this.on ? this.n + 1 : 1;
    this.on = true; player.vel.set(0, this.v, 0); player.grounded = false; player.pos.y += 0.05;
    player.shake = Math.max(player.shake, 0.45); buzz(140); Sound.thud(player.pos);
    HUD.feed(this.n > 1 ? '떨어지다 또 받혔습니다 · 더 높이 (' + this.n + '번째)' : '코뿔소 뿔에 받혀 하늘로 날아갑니다', 0, 'hs');
  },
  /* coming down: 50 and a bleeding wound for you. whatever you land on takes 30% of its health (the boss 15%) */
  land() {
    this.on = false; this.v = 0; this.n = 0;
    const p = player.pos;
    FX.puff({ x: p.x, y: p.y + 0.2, z: p.z }, 8, 0.9, 0.8); Sound.thud(p); Sound.land(); player.shake = Math.max(player.shake, 0.6); buzz(160);
    let n = 0;
    for (const e of Enemies.list.slice()) {
      if (!e.alive || e.ridden || e.caged || e.downed) continue;
      const d = Math.hypot(e.pos.x - p.x, e.pos.z - p.z);
      if (d > (e.footR || e.R) * 0.85 + player.r + 0.3 || p.y - e.pos.y > e.H + 1.5 || e.pos.y - p.y > 1) continue;
      _tp.set(e.pos.x, e.pos.y + e.H * 0.7, e.pos.z); _td.set(e.pos.x - p.x, -1, e.pos.z - p.z).normalize();
      Enemies.damage(e, Math.round(e.maxHp * (e.boss ? 0.15 : 0.3)), _tp, _td, false); n++;
    }
    if (n) HUD.feed('떨어지며 ' + n + '마리를 덮쳤습니다 · 최대 체력의 30%', 0, 'hs');
    player.hurt(100 * BEAST_DMG, p, 'fall'); if (!Game.ended) Bleed.add();
  },
};

/* ---------- who the beasts go for: you, or the animal you are sitting on ---------- */
const Q = { x: 0, y: 0, z: 0, r: 0.36 };
function quarry() {
  const m = Ride.m;
  if (m) { Q.x = m.pos.x; Q.y = m.pos.y; Q.z = m.pos.z; Q.r = m.R; } else { Q.x = player.pos.x; Q.y = player.pos.y; Q.z = player.pos.z; Q.r = player.r; }
  return Q;
}
/* within reach and in front of the head (and not high above it) */
function inFront(e, q, reach, cosMin) {
  const dx = q.x - e.pos.x, dz = q.z - e.pos.z, d = Math.hypot(dx, dz);
  if (d > reach || q.y > e.pos.y + e.H + 0.3) return false;
  return d < 0.5 || (dx * Math.sin(e.yaw) + dz * Math.cos(e.yaw)) / d >= cosMin;
}
function feetUp() { return player.pos.y - groundAt(player.pos.x, player.pos.y + 0.05, player.pos.z, player.r); }
const noseOf = (e) => (e.foot ? e.foot.z1 : e.R);

const Beast = {
  roarCd: 0, // the lions take turns: one king's roar every 8 seconds at most
  reset() { this.roarCd = 0; },
  /* a blow that lands. gore: a buffalo's charge (25, out cold for 3 s); bite: hippo or lion (25); maul: cheetah or tiger in passing (60).
     every one of them opens a bleeding wound. up on any animal, the one under you takes it instead (and bleeds) */
  hit(e, kind) {
    if (state !== 'playing' || Game.ended || player.invuln > 0) return false;
    const dmg = e.T.dmg * (e.dmgMul || 1) * BEAST_DMG;
    if (Ride.m) { Ride.hurtMount(dmg, e); return true; }
    if (kind === 'gore') {
      Game.stun(e, dmg, 3);
      // thrown aside, out of its line: it runs on past you instead of carrying you along to the wall
      const cx = e.cx || Math.sin(e.yaw), cz = e.cz || Math.cos(e.yaw), rx = player.pos.x - e.pos.x, rz = player.pos.z - e.pos.z;
      const side = Math.sign(rx * cz - rz * cx) || (Math.random() < 0.5 ? 1 : -1);
      if (!Ride.m) { player.vel.x = cz * side * 12 + cx * 3; player.vel.z = -cx * side * 12 + cz * 3; }
      e.ghostT = 0.7;
    } else if (kind === 'neck') { player.hurt(dmg, e.pos, 'body'); Sound.thud(player.pos); Sound.bite(); player.shake = Math.max(player.shake, 0.5); } // a giraffe's head, swung like a club
    else { player.hurt(dmg, e.pos, 'body'); Sound.bite(); player.shake = Math.max(player.shake, kind === 'maul' ? 0.45 : 0.3); }
    if (!Game.ended && !(Tower.active && Tower.on)) Bleed.add(); // up on the watchtower a blow still hurts, but opens no wound
    return true;
  },
  /* the male lion's roar: every animal but the tigers kneels for a moment, gets back a third of its health, and from then on moves and strikes faster */
  kingRoar(e) {
    this.roarCd = 8; Sound.roar(e.pos, 'cat'); Sound.roar(e.pos, 'grunt'); player.shake = Math.max(player.shake, 0.3);
    let n = 0;
    for (const o of Enemies.list) {
      if (!o.alive || !o.animal || o.kong || o.caged || o.releaseT > 0 || o.type === 'tiger') continue;
      if (Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) > 32) continue;
      o.hp = Math.min(o.maxHp, o.hp + o.maxHp * 0.35); if (o.hp >= o.maxHp) o.bar.visible = false;
      o.buff = Math.min(1.5, (o.buff || 1) + 0.1); // 10% faster per roar, up to half as fast again
      if (o !== e && !o.ridden) { o.kneelT = 1.2; o.bs = null; if (o.state === 'charge') o.state = 'chase'; o.windup = 0; o.airborne = false; restPose(o); }
      n++;
    }
    HUD.feed('숫사자 포효 · 동물 ' + n + '마리가 무릎 꿇고 체력 회복 · 더 빠르고 사나워집니다', 0, 'hs');
  },
  /* let out of the cage */
  wake(e) { e.bs = null; e.bt = 0; e.chargeCd = rand(0.4, 2.2); e.roarCd = rand(3, 10); e.attackT = rand(0, 0.6); e.buff = 1; },
};
function restPose(e) { if (e.jaw) e.jaw.rotation.x = 0; if (e.head) e.head.rotation.x = 0; e.body.rotation.x = 0; }
/* kneeling at the lion's roar: forelegs folded under, the chest low */
function kneelPose(e, dt) {
  e.kneelT -= dt;
  const k = e.kneelT > 0 ? clamp(Math.min((1.2 - e.kneelT) / 0.22, e.kneelT / 0.22), 0, 1) : 0;
  e.body.rotation.x = 0.24 * k;
  if (e.legs.length === 4) { e.legs[0].rotation.x = e.legs[1].rotation.x = 1.25 * k; e.legs[2].rotation.x = e.legs[3].rotation.x = 0; }
  e.vel.multiplyScalar(Math.exp(-dt * 6)); groundMove(e, e.vel.x, e.vel.z, dt);
  if (e.kneelT <= 0) restPose(e);
}

/* ---------- moving about ---------- */
const _pd = { x: 0, z: 0 };
/* the way to you: straight when it can see you, along the walking grid otherwise, round the side when it is wedged */
function pursue(e, dist, tx, tz, dt) {
  if (e.detourT > 0) { e.detourT -= dt; _pd.x = e.dx2; _pd.z = e.dz2; return _pd; }
  if (dist < 40 && e.los) { _pd.x = tx; _pd.z = tz; } else if (flowDir(e.pos.x, e.pos.z, _fd)) { _pd.x = _fd.x; _pd.z = _fd.z; } else { _pd.x = tx; _pd.z = tz; }
  return _pd;
}
/* every lion's roar it has heard makes it a little faster */
function beastMove(e, dx, dz, sp, dt) {
  e.vel.multiplyScalar(Math.exp(-dt * 4)); e.bx0 = e.pos.x; e.bz0 = e.pos.z;
  const B = e.buff || 1;
  return groundMove(e, dx * sp * B + e.vel.x, dz * sp * B + e.vel.z, dt);
}
/* somewhere to amble to: open floor inside the lab, not too far */
function labSpot(e, r) {
  for (let k = 0; k < 14; k++) {
    const x = e.pos.x + rand(-r, r), z = e.pos.z + rand(-r, r);
    if (Math.abs(x) > HALF - 3 || Math.abs(z) > HALF - 3 || collideAt(x, 0.05, z, e.R + 0.3, Math.min(e.H, 2))) continue;
    return { x, z };
  }
  return { x: e.pos.x, z: e.pos.z };
}
/* the way out for a frightened zebra: away from you, towards open floor, a little off the last way it went */
function fleeDir(e, ax, az) {
  let best = _pd, bs = -Infinity; const h = Math.min(e.H, 1.6);
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * TAU, x = Math.sin(a), z = Math.cos(a);
    let free = 0;
    for (const d of [1.6, 3.4, 6]) {
      const px = e.pos.x + x * d, pz = e.pos.z + z * d;
      if (Math.abs(px) > HALF - 1.5 || Math.abs(pz) > HALF - 1.5 || collideAt(px, e.pos.y + 0.05, pz, e.R, h)) break;
      free++;
    }
    const sc = (x * ax + z * az) * 1.3 + free * 0.75 + (x * (e.fx || 0) + z * (e.fz || 0)) * 0.35 + rand(-0.5, 0.5);
    if (sc > bs) { bs = sc; best = { x, z }; }
  }
  return best;
}
/* shot: a zebra bolts, and so do the ones right beside it */
function spook(e) {
  for (const o of Enemies.list) {
    if (!o.alive || o.type !== 'zebra' || o.ridden || o.caged || o.releaseT > 0 || o.wild) continue;
    if (o !== e && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) > 7) continue;
    if (o.bs !== 'flee') { o.zigT = 0; if (Math.random() < 0.5) Sound.roar(o.pos, 'bray'); }
    o.bs = 'flee'; o.bt = rand(3.5, 5);
  }
}

/* ---------- the kinds ---------- */
/* zebras never fight: they amble about and graze. shot, they bolt, zig-zagging fast, for a few seconds. tamed animals live the same quiet life */
function zebraAI(e, dt, dist, tx, tz) {
  const T = e.T; e.bt -= dt;
  let sp = 0, dx = 0, dz = 0, turn = T.turn;
  if (e.bs === 'flee') {
    e.zigT -= dt;
    if (e.zigT <= 0) { e.zigT = rand(0.3, 0.65); const d = fleeDir(e, -tx, -tz); e.fx = d.x; e.fz = d.z; }
    dx = e.fx; dz = e.fz; sp = T.run * 0.86; turn = 11;
    if (e.bt <= 0) { e.bs = 'graze'; e.bt = rand(1.5, 3.5); }
  } else if (e.bs === 'walk') {
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l < 1.2 || e.bt <= 0) { e.bs = 'graze'; e.bt = rand(1.5, 4); } else { dx = wx / l; dz = wz / l; sp = T.speed * (e.type === 'zebra' ? 1 : 0.8); }
  } else {
    if (e.bs !== 'graze') { e.bs = 'graze'; e.bt = rand(0.5, 2.5); }
    if (e.bt <= 0) { e.bs = 'walk'; e.bt = rand(3, 7); const p = labSpot(e, 14); e.wx = p.x; e.wz = p.z; }
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && e.bs === 'walk') e.bt = 0;
  if (blocked && e.bs === 'flee') e.zigT = Math.min(e.zigT, 0.05);
  if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), turn, dt);
  animalGait(e, sp, dt);
  e.body.rotation.x = lerp(e.body.rotation.x, e.bs === 'graze' ? 0.1 : 0, 1 - Math.exp(-dt * 4)); // nose down to the straw
}

/* buffalo: stops, paws the floor, then runs dead straight. a wall met at a slant turns the run along the wall; only a wall met head-on,
   or a corner, stops it. whoever is in the way takes 50, is out cold for 3 seconds and bleeds */
function buffaloAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1; e.bt -= dt * B; e.chargeCd -= dt * B;
  let sp = 0, dx = 0, dz = 0, turn = T.turn, pitch = 0;
  if (e.bs === 'aim') {
    turnToward(e, faceYaw, 5, dt); pitch = 0.12;
    if (e.bt <= 0) {
      e.bs = 'rush'; e.bt = 6; e.cx = tx; e.cz = tz; e.yaw = Math.atan2(tx, tz); e.g.rotation.y = e.yaw; e.hitDone = false;
      Sound.roar(e.pos, T.roar); FX.puff({ x: e.pos.x, y: 0.3, z: e.pos.z }, 3, 0.6, 0.6);
    }
  } else if (e.bs === 'rush') {
    dx = e.cx; dz = e.cz; sp = T.run * 1.15; turn = 16; pitch = 0.14;
    // real headway since last time (something pressed against its head, like you against a wall, stops it too)
    const net = e.lastX === undefined ? 1 : Math.hypot(e.pos.x - e.lastX, e.pos.z - e.lastZ);
    e.pinT = net < sp * B * dt * 0.3 ? (e.pinT || 0) + dt : 0; if (e.pinT > 0.3) { e.bs = 'daze'; e.bt = 1.3; e.pinT = 0; }
    const q = quarry(), rx = q.x - e.pos.x, rz = q.z - e.pos.z, f = rx * dx + rz * dz, l = Math.abs(rx * dz - rz * dx);
    if (!e.hitDone && f > -e.R && f < noseOf(e) + q.r + 0.25 && l < e.R + q.r + 0.3 && q.y < e.pos.y + e.H + 0.2) { e.hitDone = true; Beast.hit(e, 'gore'); }
    if (Math.random() < dt * 12) FX.puff({ x: e.pos.x - dx, y: 0.2, z: e.pos.z - dz }, 1, 0.5, 0.35);
    if (e.bt <= 0) { e.bs = 'daze'; e.bt = 0.8; }
  } else if (e.bs === 'daze') {
    pitch = 0.18; e.g.rotation.y = e.yaw + Math.sin(e.bt * 16) * 0.12;
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(0.8, 2); e.g.rotation.y = e.yaw; }
  } else {
    if (e.bs !== 'seek') e.bs = 'seek';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z; sp = T.run * 0.42;
    if (e.chargeCd <= 0 && e.los && dist > 4 && dist < 42) { e.bs = 'aim'; e.bt = 0.75; sp = 0; }
  }
  e.lastX = e.pos.x; e.lastZ = e.pos.z; if (e.ghostT > 0) e.ghostT -= dt;
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'rush') {
    // how far it really got: short of the step means something solid. head-on (or a corner) stops it; a slant sends it along the wall
    const want = sp * B * dt, mx = e.pos.x - e.bx0, mz = e.pos.z - e.bz0, got = Math.hypot(mx, mz);
    if (got < want * 0.94 && !smashAhead(e, e.cx, e.cz)) {
      if (got < want * 0.3) {
        e.bs = 'daze'; e.bt = 1.3; Sound.thud(e.pos); FX.puff({ x: e.pos.x + e.cx * e.R, y: 1, z: e.pos.z + e.cz * e.R }, 6, 0.5, 0.8);
        if (dist < 20) player.shake = Math.max(player.shake, 0.12);
      } else { e.cx = mx / got; e.cz = mz / got; }
    }
    turnToward(e, Math.atan2(e.cx, e.cz), turn, dt);
  } else if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), turn, dt); }
  animalGait(e, sp, dt);
  if (e.bs === 'aim' && e.legs[0]) e.legs[0].rotation.x = Math.sin(e.bt * 22) * 0.55; // pawing the floor
  e.body.rotation.x = lerp(e.body.rotation.x, pitch, 1 - Math.exp(-dt * 8));
}

/* hippo, and the male lion who bites the same way: come close, open wide, and clamp shut. 50 and a bleeding wound.
   the lion also roars now and then (see Beast.kingRoar) */
function biterAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, lion = e.type === 'lionM'; e.bt -= dt * B; e.attackT -= dt * B; e.roarCd -= dt;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), reach = noseOf(e) + q.r + 0.45;
  let sp = 0, dx = 0, dz = 0, open = 0, look = 0;
  if (e.bs === 'gape') {
    open = clamp(1 - e.bt / e.btMax, 0, 1); turnToward(e, faceYaw, 6, dt);
    if (qd > reach * 0.85) { dx = tx; dz = tz; sp = 1.8; }
    if (e.bt <= 0) { e.bs = 'snap'; e.bt = 0.13; e.bit = false; }
  } else if (e.bs === 'snap') {
    open = clamp(e.bt / 0.13, 0, 1);
    if (!e.bit) { e.bit = true; Sound.thud(e.pos); if (inFront(e, q, reach + 0.4, 0.5)) Beast.hit(e, 'bite'); }
    if (e.bt <= 0) { e.bs = 'chase'; e.attackT = rand(0.6, 0.95); }
  } else if (e.bs === 'roar') {
    open = 1; look = 1; turnToward(e, faceYaw, 3, dt);
    if (!e.roared && e.bt < 1.0) { e.roared = true; Beast.kingRoar(e); }
    if (e.bt <= 0) { e.bs = 'chase'; e.roarCd = rand(16, 24); }
  } else {
    if (e.bs !== 'chase') e.bs = 'chase';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z;
    sp = qd > reach - 0.15 ? T.run * (lion ? 0.62 : 0.78) : 0;
    if (qd < reach && e.attackT <= 0) { e.bs = 'gape'; e.bt = e.btMax = lion ? 0.42 : 0.6; Sound.roar(e.pos, lion ? 'cat' : 'grunt'); }
    else if (lion && e.roarCd <= 0 && Beast.roarCd <= 0 && dist < 30 && e.los) { e.bs = 'roar'; e.bt = 1.4; e.roared = false; Beast.roarCd = 2; }
  }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'chase') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); turnToward(e, qd < 8 ? faceYaw : Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  // the hippo's whole head tips back as the jaw drops; the lion just opens wide (and lifts his chin to roar)
  if (e.head) e.head.rotation.x = -0.95 * open;
  if (e.jaw) e.jaw.rotation.x = (lion ? 0.85 : 0.55) * open;
  e.body.rotation.x = lerp(e.body.rotation.x, lion ? -0.12 * look : 0, 1 - Math.exp(-dt * 8));
}

/* rhino: a charge that slows as it closes, then the horn comes up and you go straight up into the air.
   coming down within its reach, you get thrown again, higher each time */
function rhinoAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1; e.bt -= dt * B; e.chargeCd -= dt * B;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), reach = noseOf(e) + q.r + 0.5;
  let sp = 0, dx = 0, dz = 0, head = 0;
  // you are falling towards it: up goes the horn, timed so it meets you about a horn's height up
  if (Toss.on && player.vel.y < 0 && qd < reach + 0.5 && e.bs !== 'flick' && feetUp() + player.vel.y * 0.13 - 0.15 < 2.6) { e.bs = 'flick'; e.bt = 0.3; e.tossed = false; }
  if (e.bs === 'rush') {
    turnToward(e, faceYaw, 1.8, dt); dx = Math.sin(e.yaw); dz = Math.cos(e.yaw); sp = T.run * 1.05; head = 0.3;
    if (Math.random() < dt * 10) FX.puff({ x: e.pos.x - dx, y: 0.2, z: e.pos.z - dz }, 1, 0.5, 0.35);
    if (qd < reach + 2.6) { e.bs = 'brake'; e.bt = e.btMax = 0.4; e.v0 = sp; }
    else if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(1, 2); }
  } else if (e.bs === 'brake') {
    const u = clamp(e.bt / e.btMax, 0, 1); sp = lerp(1.2, e.v0, u); head = 0.3 + 0.18 * (1 - u);
    turnToward(e, faceYaw, 4.5, dt); dx = Math.sin(e.yaw); dz = Math.cos(e.yaw);
    if (e.bt <= 0) { e.bs = 'flick'; e.bt = 0.3; e.tossed = false; }
  } else if (e.bs === 'flick') {
    const u = 1 - clamp(e.bt / 0.3, 0, 1); head = u < 0.4 ? 0.48 - u * 3.3 : -0.85; turnToward(e, faceYaw, 6, dt);
    if (!e.tossed && u >= 0.4) {
      e.tossed = true; Sound.swoosh(e.pos);
      const dx = q.x - e.pos.x, dz = q.z - e.pos.z, d = Math.hypot(dx, dz), facing = d < 0.5 || (dx * Math.sin(e.yaw) + dz * Math.cos(e.yaw)) / d >= 0.3;
      if (d < reach + 0.35 && facing && (Ride.m || feetUp() < 3.0)) Toss.launch(e); // the horn reaches about 3 m up
    }
    if (e.bt <= 0) { e.bs = 'recover'; e.bt = 0.9; }
  } else if (e.bs === 'recover') {
    head = -0.85 * clamp(e.bt / 0.9, 0, 1);
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(0.8, 2); }
  } else if (e.bs === 'stun') {
    head = 0.2 + Math.sin(e.bt * 14) * 0.12;
    if (e.bt <= 0) { e.bs = 'seek'; e.chargeCd = rand(1, 2); }
  } else {
    if (e.bs !== 'seek') e.bs = 'seek';
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z; sp = T.run * 0.4;
    if (qd < reach + 1.2 && !Toss.on) { e.bs = 'brake'; e.bt = e.btMax = 0.25; e.v0 = sp; }
    else if (e.chargeCd <= 0 && e.los && dist > 6 && dist < 40 && !Toss.on) { e.bs = 'rush'; e.bt = 4; Sound.roar(e.pos, T.roar); }
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && (e.bs === 'rush' || e.bs === 'brake') && !smashAhead(e, dx, dz)) {
    e.bs = 'stun'; e.bt = 1.1; Sound.thud(e.pos); FX.puff({ x: e.pos.x + dx * e.R, y: 1, z: e.pos.z + dz * e.R }, 6, 0.5, 0.8);
  }
  if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  if (e.head) e.head.rotation.x = lerp(e.head.rotation.x, head, 1 - Math.exp(-dt * (e.bs === 'flick' ? 40 : 10)));
}

/* cheetah (the fastest thing in here), and the tiger who hunts the same way: a dead-straight sprint along a line that passes just beside you,
   a bite in passing at the closest point (120 and a bleeding wound), and a stop a few metres behind you. then round for another go.
   the tiger also roars: whoever is not up on a giraffe or an elephant runs away for a second */
function startRun(e, q) {
  const rx = q.x - e.pos.x, rz = q.z - e.pos.z, d = Math.hypot(rx, rz) || 1, ux = rx / d, uz = rz / d, side = Math.random() < 0.5 ? 1 : -1;
  const ax = q.x - uz * side * 1.1, az = q.z + ux * side * 1.1, ad = Math.hypot(ax - e.pos.x, az - e.pos.z) || 1; // a point just off your shoulder
  e.cx = (ax - e.pos.x) / ad; e.cz = (az - e.pos.z) / ad; e.bs = 'run'; e.bt = 3; e.bit = false;
  Sound.roar(e.pos, 'cat');
}
function runnerAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, tiger = e.type === 'tiger'; e.bt -= dt * B; e.chargeCd -= dt * B; e.roarCd -= dt;
  const q = quarry();
  let sp = 0, dx = 0, dz = 0, open = 0, turn = T.turn, lift = 0;
  if (e.bs === 'run') {
    dx = e.cx; dz = e.cz; sp = T.run; turn = 24;
    const rx = q.x - e.pos.x, rz = q.z - e.pos.z, f = rx * dx + rz * dz, l = Math.abs(rx * dz - rz * dx), nose = noseOf(e);
    open = clamp(1 - (f - nose) / 5, 0, 1); // the mouth opens as it draws level
    if (!e.bit && f <= nose * 0.8) {
      e.bit = true;
      if (l < q.r + 1.2 && Math.abs(q.y - e.pos.y) < e.H + 0.4) Beast.hit(e, 'maul');
      e.bs = 'pass'; e.passV = sp;
    } else if (e.bt <= 0) { e.bs = 'pass'; e.passV = sp; }
  } else if (e.bs === 'pass') {
    // keeps going past you, slowing to a stop in about three metres
    e.passV = Math.max(0, e.passV - (T.run * T.run / 6) * dt * B); sp = e.passV / B; dx = e.cx; dz = e.cz; turn = 2;
    open = clamp(e.passV / T.run, 0, 1) * 0.5;
    if (e.passV <= 0.4) { e.bs = 'turn'; e.bt = 0.5; }
  } else if (e.bs === 'turn') {
    turnToward(e, faceYaw, 8, dt);
    if (e.bt <= 0) { e.bs = 'stalk'; e.chargeCd = rand(0.2, 0.8); }
  } else if (e.bs === 'roar') {
    open = 1; lift = 1; turnToward(e, faceYaw, 4, dt);
    if (!e.roared && e.bt < 0.75) { e.roared = true; Sound.roar(e.pos, 'cat'); Sound.roar(e.pos, 'cat'); if (dist < 24 && e.los) Fear.apply(e); }
    if (e.bt <= 0) { e.bs = 'stalk'; e.roarCd = rand(9, 14); }
  } else {
    if (e.bs !== 'stalk') e.bs = 'stalk';
    const d = pursue(e, dist, tx, tz, dt);
    if (dist < 6) { dx = -tx; dz = -tz; sp = T.speed * 2.2; } // too close for a run: open the distance first
    else { dx = d.x; dz = d.z; sp = dist > 30 ? T.run * 0.5 : T.speed * 1.4; }
    if (tiger && e.roarCd <= 0 && dist < 24 && e.los) { e.bs = 'roar'; e.bt = 1.15; e.roared = false; sp = 0; }
    else if (e.chargeCd <= 0 && e.los && dist >= 6 && dist < 34) startRun(e, q);
  }
  const blocked = beastMove(e, dx, dz, sp, dt);
  if (blocked && (e.bs === 'run' || e.bs === 'pass')) { e.bs = 'turn'; e.bt = 0.6; }
  if (e.bs === 'stalk') unstick(e, e.bx0, e.bz0, dx, dz, sp, dt);
  if (sp > 0.1 && e.bs !== 'turn' && e.bs !== 'roar') turnToward(e, e.bs === 'stalk' && dist < 6 ? faceYaw : Math.atan2(dx, dz), turn, dt);
  animalGait(e, sp, dt);
  if (e.jaw) e.jaw.rotation.x = 0.75 * open;
  e.body.rotation.x = lerp(e.body.rotation.x, -0.1 * lift, 1 - Math.exp(-dt * 8));
}
/* giraffe: walks up to you and swings its long neck down like a club (24 and a bleeding wound). the neck reaches a long way,
   up over a watchtower's railing too: on the safari it is the one animal that goes for you up there instead of the tower */
function neckPose(e, a, dt) {
  if (!e.head) return;
  const r = e.head.rotation.x = lerp(e.head.rotation.x, a, 1 - Math.exp(-dt * 16));
  // the head and neck hit spheres swing with it
  if (!e.neckBase) e.neckBase = [0, 1].map((i) => [e.parts[i].o.y, e.parts[i].o.z]);
  const c = Math.cos(r), s = Math.sin(r), py = GIRAFFE_NECK[0], pz = GIRAFFE_NECK[1];
  for (let i = 0; i < 2; i++) { const [y, z] = e.neckBase[i], ly = y - py, lz = z - pz; e.parts[i].o.y = py + ly * c - lz * s; e.parts[i].o.z = pz + ly * s + lz * c; }
}
function giraffeAI(e, dt, dist, tx, tz, faceYaw) {
  const T = e.T, B = e.buff || 1, sc = e.scale || 1; e.bt -= dt * B; e.attackT -= dt * B;
  const q = quarry(), qd = Math.hypot(q.x - e.pos.x, q.z - e.pos.z), high = q.y - e.pos.y;
  const reach = (high > 2 ? 4.3 : 3.4) * sc + q.r, inReach = qd < reach && high < 5.4 * sc && high > -1.5;
  const toQ = Math.atan2(q.x - e.pos.x, q.z - e.pos.z);
  let sp = 0, dx = 0, dz = 0, neck = 0;
  if (e.bs === 'rear') {
    neck = -0.5 * (1 - clamp(e.bt / 0.45, 0, 1)); turnToward(e, toQ, 5, dt);
    if (e.bt <= 0) { e.bs = 'swing'; e.bt = 0.16; e.hitDone = false; Sound.swoosh(e.pos); }
  } else if (e.bs === 'swing') {
    const u = 1 - clamp(e.bt / 0.16, 0, 1); neck = -0.5 + 1.1 * u;
    if (!e.hitDone && u >= 0.6) {
      e.hitDone = true;
      const f = qd < 0.5 || ((q.x - e.pos.x) * Math.sin(e.yaw) + (q.z - e.pos.z) * Math.cos(e.yaw)) / qd >= 0.35;
      if (qd < reach + 0.4 && high < 5.6 * sc && high > -1.5 && f) Beast.hit(e, 'neck');
    }
    if (e.bt <= 0) { e.bs = 'recover'; e.bt = 0.55; }
  } else if (e.bs === 'recover') {
    neck = 0.6 * clamp(e.bt / 0.55, 0, 1);
    if (e.bt <= 0) { e.bs = 'seek'; e.attackT = high > 2 ? rand(1.8, 2.6) : rand(0.7, 1.2); } // reaching up over a railing takes it longer to gather itself
  } else {
    if (e.bs !== 'seek') { e.bs = 'seek'; e.attackT = Math.max(e.attackT || 0, 0.3); }
    const d = pursue(e, dist, tx, tz, dt); dx = d.x; dz = d.z;
    sp = qd > reach - 0.6 ? T.run * (dist > 30 ? 0.55 : 0.42) : 0;
    if (inReach && e.attackT <= 0) { e.bs = 'rear'; e.bt = 0.45; sp = 0; if (Math.random() < 0.5) Sound.roar(e.pos, 'grunt'); }
  }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'seek') { unstick(e, e.bx0, e.bz0, dx, dz, sp, dt); if (sp > 0.1 || qd < 10) turnToward(e, qd < 10 ? toQ : Math.atan2(dx, dz), T.turn, dt); }
  animalGait(e, sp, dt);
  neckPose(e, neck, dt);
}
const BEASTS = { zebra: zebraAI, buffalo: buffaloAI, hippo: biterAI, lionM: biterAI, rhino: rhinoAI, cheetah: runnerAI, tiger: runnerAI, giraffe: giraffeAI };

/* ---------- riding: a zebra from the floor, a giraffe from a zebra, an elephant from a giraffe ---------- */
/* seat: where you sit (above the ground, and forward of the middle), how fast it goes walking and running, how quickly it turns */
const SEAT = {
  zebra: { tier: 1, y: 1.62, z: -0.35, walk: 6, run: 12.5, turn: 7, name: '얼룩말' },
  giraffe: { tier: 2, y: 4.35, z: 0.8, walk: 5, run: 10, turn: 4.5, name: '기린' }, // high on the neck, behind the head
  elephant: { tier: 3, y: 3.45, z: 1.05, walk: 4.5, run: 8.2, turn: 3, name: '코끼리' },
};
const Ride = {
  m: null, tier: 0, vx: 0, vz: 0, ease: 1, from: new THREE.Vector3(), target: null, findT: 0,
  /* up on a giraffe or an elephant: no fear, and blows land on the animal, not on you */
  brave() { return !!this.m && this.tier >= 2; },
  ok(e) {
    if (!e.alive || !e.animal || e.kong || e.caged || e.releaseT > 0 || e === this.m || !SEAT[e.type]) return false;
    if (e.tamed) return true; // one you have ridden before lets you straight back on, from the ground or from another animal
    return SEAT[e.type].tier <= this.tier + 1;
  },
  /* what you could get onto right now: in reach, roughly in front of you; the closest to where you look wins */
  find() {
    if (!World.style.ride || state !== 'playing' || Game.ended || player.stunT > 0 || Toss.on || Fear.t > 0 || Jet.on) return null;
    if (!this.m && !player.grounded) return null;
    const fx = -Math.sin(player.yaw), fz = -Math.cos(player.yaw), from = this.m ? this.m.R : player.r;
    let best = null, bs = Infinity;
    for (const e of Enemies.list) {
      if (!this.ok(e)) continue;
      const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z, d = Math.hypot(dx, dz), near = e.R + from + 1.6;
      if (d > near) continue;
      const cos = (dx * fx + dz * fz) / (d || 1);
      if (cos < 0.15 && d > e.R + from + 0.4) continue;
      const sc = d * (1.7 - cos);
      if (sc < bs) { bs = sc; best = e; }
    }
    return best;
  },
  /* E (or the button): get on what is in front of you; on one already with nothing new in reach, get off */
  toggle() { const t = this.find(); if (t) this.on(t); else if (this.m) this.off(false); },
  on(e) {
    const prev = this.m;
    if (prev) this.free(prev);
    this.m = e; this.tier = SEAT[e.type].tier; e.ridden = true; e.vel.set(0, 0, 0); e.kneelT = 0; e.bs = 'ride'; e.state = 'wander'; e.windup = 0; restPose(e);
    e.bar.visible = false;
    if (!e.tamed) { e.tamed = true; Game.tame(e); }
    jetEnd(); Fear.t = 0;
    this.vx = this.vz = 0; this.ease = 0; this.from.copy(camera.position); player.vel.set(0, 0, 0);
    Sound.roar(e.pos, e.T.roar);
    const S = SEAT[e.type], next = e.type === 'zebra' ? ' · 공격은 얼룩말이 대신 맞습니다 · 이대로 기린에게 다가가면 옮겨 탈 수 있습니다' : e.type === 'giraffe' ? ' · 공포에 걸리지 않고 공격은 기린이 대신 맞습니다 · 코끼리로 옮겨 탈 수 있습니다' : ' · 공격은 코끼리가 대신 맞습니다';
    HUD.feed(S.name + (prev ? euroK(S.name) + ' 옮겨 탔습니다' : '에 탔습니다') + ' · 위에서도 총을 쏩니다', 0);
    HUD.hint(S.name + ' 탑승' + next, 3.2);
  },
  free(m) { m.ridden = false; m.bs = 'graze'; m.bt = rand(1, 3); m.vel.set(0, 0, 0); },
  /* step down beside it: right, left, behind or in front, wherever there is room */
  off(forced, msg) {
    const m = this.m; if (!m) return;
    this.m = null; this.tier = 0;
    if (m.alive) this.free(m);
    const gap = m.R + player.r + 0.35, cy = Math.cos(m.yaw), sy = Math.sin(m.yaw);
    let x = m.pos.x, z = m.pos.z;
    for (const [ox, oz] of [[cy, -sy], [-cy, sy], [-sy, -cy], [sy, cy]]) {
      const px = m.pos.x + ox * gap, pz = m.pos.z + oz * gap;
      if (Math.abs(px) < HALF - 1 && Math.abs(pz) < HALF - 1 && !collideAt(px, m.pos.y + 0.05, pz, player.r, player.height)) { x = px; z = pz; break; }
    }
    player.pos.set(x, groundAt(x, m.pos.y + 0.6, z, player.r), z); player.vel.set(0, 0, 0); player.grounded = true;
    if (msg) HUD.feed(msg, 0, 'hs'); else if (!forced) HUD.feed('내렸습니다', 0);
  },
  /* steering: it goes where you push, relative to where you look, and turns its body that way. you keep looking (and shooting) wherever you like */
  update(dt, f, s, run, stunned) {
    const m = this.m, S = SEAT[m.type];
    if (!m.alive) { this.off(true, S.name + (hasBatchim(S.name) ? '이' : '가') + ' 쓰러졌습니다 · 땅에 내려섰습니다'); return false; }
    let wx = 0, wz = 0, sp = 0;
    if (!stunned) {
      if (Fear.t > 0) { wx = Fear.x; wz = Fear.z; sp = S.run; }
      else if (f || s) {
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw); wx = -sy * f + cy * s; wz = -cy * f - sy * s;
        const l = Math.hypot(wx, wz) || 1; wx /= l; wz /= l; sp = (run ? S.run : S.walk) * Math.min(1, Math.hypot(f, s));
      }
    }
    const k = 1 - Math.exp(-dt * 5); this.vx += (wx * sp - this.vx) * k; this.vz += (wz * sp - this.vz) * k;
    const B = m.buff || 1, x0 = m.pos.x, z0 = m.pos.z;
    if (groundMove(m, this.vx * B, this.vz * B, dt)) {
      if (m.type === 'elephant' && sp > 0) smashAhead(m, wx, wz); // an elephant walks through crates
      this.vx = (m.pos.x - x0) / dt / B; this.vz = (m.pos.z - z0) / dt / B;
    }
    const v = Math.hypot(this.vx, this.vz);
    if (v > 0.4) turnToward(m, Math.atan2(this.vx, this.vz), S.turn, dt);
    animalGait(m, v, dt);
    this.seat();
    return true;
  },
  seat() {
    const m = this.m, S = SEAT[m.type], sc = m.scale || 1;
    player.pos.set(m.pos.x + Math.sin(m.yaw) * S.z * sc, m.pos.y + S.y * sc - 0.7, m.pos.z + Math.cos(m.yaw) * S.z * sc);
  },
  /* the camera glides up onto the seat over a third of a second, then rides with a little sway */
  cam(out, dt) {
    const m = this.m, v = Math.hypot(this.vx, this.vz), sway = Math.sin(m.walk * 2) * 0.035 * clamp(v / 6, 0, 1);
    this.ease = Math.min(1, this.ease + dt / 0.35); const k = this.ease * this.ease * (3 - 2 * this.ease);
    out.set(lerp(this.from.x, player.pos.x, k), lerp(this.from.y, player.pos.y + player.eye + sway, k), lerp(this.from.z, player.pos.z, k));
  },
  /* the rest of the herd shoves the animal you sit on about: stay in the saddle */
  post() {
    if (!this.m || !this.m.alive) return;
    const ox = player.pos.x, oy = player.pos.y, oz = player.pos.z; this.seat();
    if (this.ease >= 1) { camera.position.x += player.pos.x - ox; camera.position.y += player.pos.y - oy; camera.position.z += player.pos.z - oz; }
  },
  /* a blow meant for you lands on the animal you are sitting on, and opens a wound in it (the giant gorilla's do not). the beasts killing it pays you nothing */
  hurtMount(dmg, from) {
    const m = this.m; if (!m || !m.alive) return;
    m.noPay = true;
    _tp.set(m.pos.x, m.pos.y + m.H * 0.5, m.pos.z); _td.set(m.pos.x - from.pos.x, 0, m.pos.z - from.pos.z); if (_td.lengthSq() < 1e-6) _td.set(0, 0, 1); _td.normalize();
    Enemies.damage(m, dmg, _tp, _td, false);
    if (m.alive) { m.noPay = false; if (!from.boss) Bleed.addTo(m); }
    player.shake = Math.max(player.shake, 0.15); HUD.hurt(6, from.pos);
  },
  /* a wound ticking away: quiet damage, and bleeding to death pays nobody */
  bleedOut(m, d) {
    m.noPay = true; _tp.set(m.pos.x, m.pos.y + m.H * 0.5, m.pos.z); _td.set(0, 0, 1);
    Enemies.damage(m, d, _tp, _td, false, true);
    if (m.alive) m.noPay = false;
  },
  reset() { if (this.m) { this.m.ridden = false; this.m = null; } this.tier = 0; this.vx = this.vz = 0; this.ease = 1; this.target = null; },
};
function hasBatchim(w) { const c = w.charCodeAt(w.length - 1) - 0xac00; return c >= 0 && c <= 11171 && c % 28 !== 0; }
/* "으로" after a closing consonant other than ㄹ, "로" otherwise */
function euroK(w) { const c = w.charCodeAt(w.length - 1) - 0xac00; return c >= 0 && c <= 11171 && c % 28 !== 0 && c % 28 !== 8 ? '으로' : '로'; }
/* ============ the ship's crew (stage 4): CCTV turrets on the ceiling, patrol bots with glow batons, little quad drones,
   spider mines hidden in the floor, the gold commander drone on the bridge, and the three-shell boss drone in the main hall ============ */
Object.assign(ROBOTS, {
  cctv: { name: 'CCTV 포탑', hp: 45, speed: 0, r: 0.3, h: 0.45, money: 500, mode: 'cctv', sight: 30, range: 32, shot: [1, 1, 0.1, 4, 1.0, 1.6], mapKind: 'cctv' },
  patrol: { name: '순찰 로봇', hp: 160, speed: 1.6, r: 0.4, h: 1.95, money: 1000, mode: 'patrol', sight: 26, dmg: 60, mapKind: 'patrol' },
  droneA: { name: '드론', hp: 1, speed: 5.5, r: 0.45, h: 0.35, money: 800, mode: 'droneA', sight: 36, range: 40, shot: [2, 3, 0.16, 5, 1.1, 1.9], mapKind: 'droneA' },
  mine: { name: '스파이더 마인', hp: 1, speed: 8.5, r: 0.35, h: 0.32, money: 500, mode: 'mine', sight: 7.5, dmg: 100, mapKind: 'mine' },
  gdrone: { name: '황금꿀벌드론', hp: 3200, speed: 3.2, r: 1.3, h: 1.6, money: 1500, mode: 'gdrone', sight: 34, range: 42, shot: [5, 7, 0.09, 9, 1.3, 2.0], mapKind: 'midboss', mid: true },
  bdrone: { name: '보스 드론', hp: 9000, speed: 5, r: 2.5, h: 5, money: 2000, mode: 'bdrone', sight: 60, range: 70, mapKind: 'boss' },
});
const SHIPBOT = { cctv: 1, patrol: 1, droneA: 1, mine: 1, gdrone: 1, bdrone: 1 };
/* a soft studio sky for things that should shine: the gold drone, the boss's white shell */
const ShineEnv = (() => {
  let tex = null, tried = false;
  return { get() {
    if (tried) return tex; tried = true;
    try {
      const pm = new THREE.PMREMGenerator(renderer), es = new THREE.Scene();
      const geo = new THREE.SphereGeometry(10, 24, 12), pos = geo.attributes.position, col = [], c = new THREE.Color();
      const top = new THREE.Color(0x9ab4dc), mid = new THREE.Color(0x3a4356), bot = new THREE.Color(0x101318);
      for (let i = 0; i < pos.count; i++) { const y = pos.getY(i) / 10; if (y >= 0) c.copy(mid).lerp(top, Math.pow(y, 0.7)); else c.copy(mid).lerp(bot, Math.pow(-y, 0.5)); col.push(c.r, c.g, c.b); }
      geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
      es.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide })));
      for (const [x, y, z, w, hx] of [[5, 6, 2, 6, 0xffffff], [-6, 4, -3, 4, 0xffe2b0], [0, 8, -6, 8, 0xffffff], [3, -2, 7, 5, 0x9fc8ff]]) {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * 0.4), new THREE.MeshBasicMaterial({ color: hx, side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); es.add(m);
      }
      tex = pm.fromScene(es, 0.02).texture; pm.dispose();
    } catch (err) { tex = null; }
    return tex;
  } };
})();
const camLensMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a }), visorMat = new THREE.MeshBasicMaterial({ color: 0xffd23a });
const batonMat = new THREE.MeshBasicMaterial({ color: 0xd8ff7a }), batonGlow = new THREE.MeshBasicMaterial({ color: 0x8aff3a, transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false });
const thrustMat = new THREE.MeshBasicMaterial({ color: 0x6fc8ff }), gVisorMat = new THREE.MeshBasicMaterial({ color: 0xff3a2a });
let bossShellTex = null;
function shellTex() {
  if (bossShellTex) return bossShellTex;
  bossShellTex = canvasTex(1024, 512, (g, w, h) => {
    g.fillStyle = '#eef1f6'; g.fillRect(0, 0, w, h);
    g.strokeStyle = 'rgba(70,80,96,0.75)'; g.lineWidth = 3;
    for (const v of [0.18, 0.36, 0.5, 0.64, 0.82]) { g.beginPath(); g.moveTo(0, v * h); g.lineTo(w, v * h); g.stroke(); }
    for (let i = 0; i < 12; i++) { const x = (i / 12) * w + (i % 2 ? 18 : 0); g.beginPath(); g.moveTo(x, 0.18 * h); g.lineTo(x, 0.36 * h); g.moveTo(x + 30, 0.5 * h); g.lineTo(x + 30, 0.64 * h); g.moveTo(x - 20, 0.64 * h); g.lineTo(x - 20, 0.82 * h); g.stroke(); }
    g.fillStyle = 'rgba(40,46,58,0.8)'; for (let i = 0; i < 14; i++) { const x = rand(0, w), y = rand(0.2, 0.8) * h; g.fillRect(x, y, rand(10, 26), rand(4, 8)); }
    speckle(g, w, h, 1500, ['rgba(0,0,0,0.06)', 'rgba(255,255,255,0.3)'], 1.5);
  });
  return bossShellTex;
}
const BLUE = 0x1478ff, RED = 0xff1a10;
/* 5.14: the boss's iris: a grey radial drawing (the material tints it blue, or red when it is about to fire), rings and spokes like a lens */
const BossIris = (() => { let t = null; return () => t || (t = canvasTex(256, 256, (g, w) => {
  const c = w / 2, gr = g.createRadialGradient(c, c, 0, c, c, c);
  gr.addColorStop(0, '#ffffff'); gr.addColorStop(0.2, '#ffffff'); gr.addColorStop(0.36, '#d4e6ff'); gr.addColorStop(0.62, '#8fb4ec'); gr.addColorStop(0.86, '#5579bd'); gr.addColorStop(1, '#2a3f73');
  g.fillStyle = gr; g.beginPath(); g.arc(c, c, c, 0, TAU); g.fill();
  g.strokeStyle = 'rgba(255,255,255,0.45)'; g.lineWidth = 4; for (const r of [0.44, 0.66, 0.84]) { g.beginPath(); g.arc(c, c, c * r, 0, TAU); g.stroke(); }
  g.strokeStyle = 'rgba(255,255,255,0.28)'; g.lineWidth = 3; for (let i = 0; i < 20; i++) { const a = (i / 20) * TAU; g.beginPath(); g.moveTo(c + Math.cos(a) * c * 0.5, c + Math.sin(a) * c * 0.5); g.lineTo(c + Math.cos(a) * c * 0.92, c + Math.sin(a) * c * 0.92); g.stroke(); }
})); })();

function buildShipBot(type, opts) {
  opts = opts || {};
  const B = AnimalKit.geoBox, M = AnimalKit.merge, T = ROBOTS[type];
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.42, metalness: 0.55, emissive: 0x000000 });
  const g = new THREE.Group(); g.rotation.order = 'YXZ';
  const e = { type, T, robot: true, g, mats: [mat], parts: [], vel: new THREE.Vector3(), muzzle: new THREE.Vector3(), seed: Math.random() * 10, spin: 0 };
  const mesh = (parent, geo, m) => { const x = new THREE.Mesh(geo, m || mat); x.castShadow = !isTouch; parent.add(x); return x; };
  const add = (parent, geo, m, x, y, z) => { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); parent.add(o); return o; };
  if (T.mode === 'cctv') {
    // a white camera on a short arm from the ceiling, a red eye in the lens and a small gun under it; it turns to follow you
    mesh(g, M([B(0.26, 0.04, 0.26, 0, 0.44, 0, '#2a2f3a'), B(0.06, 0.36, 0.06, 0, 0.26, 0, '#3a4150')]));
    e.cam = new THREE.Group(); g.add(e.cam);
    mesh(e.cam, M([B(0.2, 0.16, 0.34, 0, 0, 0.02, '#d5d9e0'), B(0.25, 0.03, 0.42, 0, 0.095, 0.05, '#bfc4cc'), B(0.13, 0.13, 0.04, 0, 0, 0.2, '#1c2028'), B(0.045, 0.045, 0.24, 0, -0.105, 0.17, '#1c2028')]));
    add(e.cam, new THREE.BoxGeometry(0.06, 0.06, 0.02), camLensMat, 0, 0, 0.225);
    e.muzzle.set(0, -0.105, 0.3); e.eyeH = 0; e.fly = true; e.barY = -0.45;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0.04), r: 0.21, mult: 1 }, { o: new THREE.Vector3(0, 0, 0.21), r: 0.075, mult: 1, weak: true }];
  } else if (T.mode === 'patrol') {
    // a security robot in white with orange bands, a yellow visor, and a long glow baton in its right hand
    const c1 = '#d8dce4', c2 = '#5a6170', c3 = '#2a2f3a', band = '#e8902a';
    for (const sx of [-1, 1]) {
      const leg = new THREE.Group(); leg.position.set(sx * 0.14, 0.95, 0); g.add(leg);
      mesh(leg, M([B(0.18, 0.92, 0.2, 0, -0.46, 0, c2), B(0.22, 0.12, 0.34, 0, -0.9, 0.06, c3), B(0.2, 0.07, 0.22, 0, -0.42, 0.02, band)]));
      if (sx < 0) e.legL = leg; else e.legR = leg;
    }
    e.upper = new THREE.Group(); e.upper.position.set(0, 0.95, 0); g.add(e.upper);
    mesh(e.upper, M([B(0.52, 0.6, 0.32, 0, 0.36, 0, c1), B(0.54, 0.08, 0.34, 0, 0.5, 0, band), B(0.2, 0.14, 0.3, -0.34, 0.66, 0, c2), B(0.2, 0.14, 0.3, 0.34, 0.66, 0, c2),
      B(0.12, 0.08, 0.12, 0, 0.71, 0, c3), B(0.3, 0.26, 0.3, 0, 0.87, 0, c1), B(0.32, 0.05, 0.32, 0, 1.0, 0, band), B(0.03, 0.22, 0.03, 0.1, 1.08, -0.05, c3)]));
    add(e.upper, new THREE.BoxGeometry(0.24, 0.06, 0.02), visorMat, 0, 0.88, 0.155);
    e.armL = new THREE.Group(); e.armL.position.set(-0.34, 0.6, 0); e.upper.add(e.armL); mesh(e.armL, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3)]));
    e.armR = new THREE.Group(); e.armR.position.set(0.34, 0.6, 0); e.upper.add(e.armR);
    mesh(e.armR, M([B(0.13, 0.6, 0.15, 0, -0.29, 0, c2), B(0.12, 0.12, 0.12, 0, -0.62, 0, c3), B(0.05, 0.16, 0.05, 0, -0.74, 0.03, '#2a2a2a')]));
    add(e.armR, new THREE.CylinderGeometry(0.035, 0.035, 0.66, 8), batonMat, 0, -1.14, 0.03);
    add(e.armR, new THREE.CylinderGeometry(0.085, 0.085, 0.72, 8), batonGlow, 0, -1.14, 0.03);
    e.parts = [{ o: new THREE.Vector3(0, 1.81, 0), r: 0.17, mult: 1, weak: true }, { o: new THREE.Vector3(0, 1.33, 0), r: 0.33, mult: 1 },
      { o: new THREE.Vector3(0, 0.98, 0), r: 0.25, mult: 0.9 }, { o: new THREE.Vector3(0, 0.5, 0), r: 0.26, mult: 0.7 }];
    e.eyeH = 1.82;
  } else if (T.mode === 'droneA') {
    // a little quadcopter: a flat body, arms out to the four corners with a propeller on each, a red eye under the nose
    mesh(g, M([B(0.42, 0.12, 0.42, 0, 0, 0, '#cfd4dc'), B(0.3, 0.1, 0.3, 0, -0.1, 0.02, '#2a2f3a'), B(0.84, 0.04, 0.06, 0, 0.02, 0, '#3a4150', [0, Math.PI / 4, 0]),
      B(0.84, 0.04, 0.06, 0, 0.02, 0, '#3a4150', [0, -Math.PI / 4, 0]), B(0.05, 0.08, 0.18, 0, -0.16, 0.16, '#1c2028')]));
    e.rotors = [];
    for (const [x, z] of [[0.3, 0.3], [-0.3, 0.3], [0.3, -0.3], [-0.3, -0.3]]) {
      mesh(g, M([B(0.08, 0.07, 0.08, x, 0.05, z, '#2a2f3a')]));
      const ro = new THREE.Group(); ro.position.set(x, 0.1, z); g.add(ro); mesh(ro, M([B(0.42, 0.012, 0.05, 0, 0, 0, '#1c2028'), B(0.05, 0.012, 0.42, 0, 0, 0, '#1c2028')])); e.rotors.push(ro);
    }
    add(g, new THREE.BoxGeometry(0.08, 0.05, 0.03), camLensMat, 0, -0.13, 0.25);
    e.muzzle.set(0, -0.16, 0.28); e.eyeH = 0; e.fly = true; e.barY = 0.5;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 0.34, mult: 1 }, { o: new THREE.Vector3(0, -0.12, 0.2), r: 0.1, mult: 1, weak: true }];
  } else if (T.mode === 'mine') {
    // a squat dark disc with six folded legs and a dim red eye; it lies buried flush with the floor until something comes close
    e.body = new THREE.Group(); g.add(e.body);
    mesh(e.body, M([B(0.56, 0.14, 0.56, 0, 0.1, 0, '#24282f', null, false, true), B(0.4, 0.08, 0.4, 0, 0.19, 0, '#30353e', null, false, true), B(0.62, 0.03, 0.62, 0, 0.06, 0, '#1a1d22')]));
    const lm = new THREE.MeshBasicMaterial({ color: 0x401010 }); e.mats.push(lm);
    e.light = add(e.body, new THREE.BoxGeometry(0.07, 0.03, 0.07), lm, 0, 0.235, 0.06);
    e.cl = [];
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * TAU + 0.5, p = new THREE.Group(); p.position.set(Math.cos(a) * 0.24, 0.1, Math.sin(a) * 0.24); p.rotation.order = 'YXZ'; p.rotation.y = -a; g.add(p);
      mesh(p, M([B(0.3, 0.04, 0.05, 0.15, 0, 0, '#3a4150'), B(0.04, 0.22, 0.04, 0.3, -0.1, 0, '#2a2f3a')])); e.cl.push(p);
    }
    e.parts = [{ o: new THREE.Vector3(0, 0.12, 0), r: 0.3, mult: 1 }]; e.eyeH = 0.3; e.barY = 0.7;
  } else if (T.mode === 'gdrone') {
    // the commander: a heavy hull plated in polished gold, a red visor, two engines, twin cannons and a crest on top
    const gold = new THREE.MeshStandardMaterial({ color: 0xd99a1e, metalness: 1, roughness: 0.14, envMap: ShineEnv.get(), envMapIntensity: 1.25, emissive: 0x3a2000, emissiveIntensity: 0.35 });
    e.mats.push(gold);
    const gm = (geo, x, y, z) => { const m = new THREE.Mesh(geo, gold); m.position.set(x, y, z); m.castShadow = !isTouch; g.add(m); return m; };
    gm(new THREE.SphereGeometry(1, 28, 16), 0, 0, 0).scale.set(1.25, 0.62, 1.05);
    gm(new THREE.SphereGeometry(0.55, 20, 10, 0, TAU, 0, Math.PI / 2), 0, 0.32, -0.1);
    gm(new THREE.BoxGeometry(0.07, 0.42, 0.9), 0, 0.78, -0.15);
    for (const sx of [-1, 1]) { const n = gm(new THREE.CylinderGeometry(0.3, 0.24, 1.35, 16), sx * 1.3, -0.05, -0.05); n.rotation.x = Math.PI / 2;
      add(g, new THREE.CircleGeometry(0.2, 16), thrustMat, sx * 1.3, -0.05, -0.74).rotation.y = Math.PI; }
    mesh(g, M([B(0.13, 0.13, 0.95, -0.38, -0.46, 0.55, '#1c2028'), B(0.13, 0.13, 0.95, 0.38, -0.46, 0.55, '#1c2028'), B(0.9, 0.12, 0.3, 0, -0.4, 0.15, '#2a2f3a'),
      B(0.03, 0.6, 0.03, -0.35, 0.75, -0.4, '#2a2f3a'), B(0.03, 0.45, 0.03, 0.35, 0.68, -0.4, '#2a2f3a')]));
    add(g, new THREE.BoxGeometry(0.95, 0.12, 0.05), gVisorMat, 0, 0.06, 1.02);
    // a golden bee: big glossy compound eyes, feelers, a striped abdomen with a sting, and four see-through wings that beat
    const eyeM = new THREE.MeshStandardMaterial({ color: 0x1c0d06, metalness: 0.4, roughness: 0.12, emissive: 0x3a0a00, envMap: ShineEnv.get(), envMapIntensity: 1.4 }); e.mats.push(eyeM); e.beeEye = eyeM;
    for (const sx of [-1, 1]) { const ey = new THREE.Mesh(new THREE.SphereGeometry(0.36, 18, 12), eyeM); ey.scale.set(0.75, 1.15, 0.85); ey.position.set(sx * 0.55, 0.16, 0.78); g.add(ey);
      const an = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.85, 6), new THREE.MeshStandardMaterial({ color: 0x241a0c, roughness: 0.6 })); an.position.set(sx * 0.22, 0.86, 0.86); an.rotation.set(0.7, 0, -sx * 0.35); g.add(an);
      gm(new THREE.SphereGeometry(0.07, 8, 6), sx * 0.36, 1.2, 1.12); }
    gm(new THREE.SphereGeometry(1, 24, 14), 0, -0.04, -1.3).scale.set(0.95, 0.8, 1.25);
    const band = new THREE.MeshStandardMaterial({ color: 0x15100a, roughness: 0.35, metalness: 0.5 });
    for (const [z, rr] of [[-0.95, 0.88], [-1.35, 0.95], [-1.78, 0.78]]) { const b = new THREE.Mesh(new THREE.CylinderGeometry(rr, rr, 0.2, 24, 1, true), band); b.rotation.x = Math.PI / 2; b.scale.set(1.01, 1, 0.85); b.position.set(0, -0.04, z); g.add(b); }
    const sting = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.6, 10), band); sting.rotation.x = -Math.PI / 2; sting.position.set(0, -0.08, -2.75); g.add(sting);
    const wingM = new THREE.MeshBasicMaterial({ color: 0xdcecff, transparent: true, opacity: 0.38, side: THREE.DoubleSide, depthWrite: false });
    const wingGeo = new THREE.CircleGeometry(1, 20); wingGeo.scale(1.25, 0.42, 1); wingGeo.rotateX(-Math.PI / 2); wingGeo.translate(1.15, 0, -0.15);
    e.wings = [];
    for (const sx of [-1, 1]) for (const [dz, sc] of [[0.15, 1], [-0.45, 0.78]]) {
      const w = new THREE.Group(); w.position.set(sx * 0.4, 0.62, dz); const m = new THREE.Mesh(wingGeo, wingM); m.scale.set(sx * sc, 1, sc); w.add(m); g.add(w); e.wings.push({ g: w, sx });
    }
    e.muzzle.set(0.38, -0.46, 1.08); e.eyeH = 0; e.fly = true; e.barY = 1.8;
    e.parts = [{ o: new THREE.Vector3(0, 0, 0), r: 1.12, mult: 1 }, { o: new THREE.Vector3(0, 0.06, 0.98), r: 0.24, mult: 1, weak: true }, { o: new THREE.Vector3(0, 0, -1.3), r: 0.95, mult: 1 }];
  } else {
    // the boss: three shells, one inside the other. 5 m armoured, 3 m armoured, and the 1.5 m white core with the eye;
    // the eye looks out of every one of them
    const env = ShineEnv.get();
    const white = new THREE.MeshStandardMaterial({ color: 0xeef1f6, map: shellTex(), roughness: 0.22, metalness: 0.3, envMap: env, envMapIntensity: 1.2 });
    const armor = new THREE.MeshStandardMaterial({ color: 0x9aa4b6, roughness: 0.33, metalness: 0.65, envMap: env, envMapIntensity: 1.0 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x1a1f28, roughness: 0.4, metalness: 0.5 });
    const eyeMat = new THREE.MeshBasicMaterial({ color: BLUE, map: BossIris(), toneMapped: false }), pupil = new THREE.MeshBasicMaterial({ color: 0xd8ecff, toneMapped: false }), lights = new THREE.MeshBasicMaterial({ color: 0x3a9cff });
    const glowS = new THREE.SpriteMaterial({ map: World.poolTex || null, color: 0x2f8cff, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.34 });
    const lensM = new THREE.MeshStandardMaterial({ color: 0x0a1428, roughness: 0.12, metalness: 0.7, envMap: env, envMapIntensity: 1.1 });
    const sockM = new THREE.MeshStandardMaterial({ color: 0x10141c, roughness: 0.6, metalness: 0.4, side: THREE.DoubleSide });
    e.mats.push(white, armor, dark, eyeMat, pupil, lights, lensM, sockM); e.eyeMat = eyeMat; e.eyeGlow = glowS; e.lightMat = lights;
    e.shells = [];
    [5, 3, 1.5].forEach((D, k) => {
      const s = new THREE.Group(), R = D / 2; g.add(s);
      // the shell is a sphere with a round opening at the front (a sphere missing its top cap, turned to face forward)
      const HOLE = Math.asin(0.46), sg = new THREE.SphereGeometry(R, 44, 26, 0, TAU, HOLE, Math.PI - HOLE); sg.rotateX(Math.PI / 2);
      const ball = new THREE.Mesh(sg, white); ball.castShadow = !isTouch; s.add(ball);
      // in the opening: a dark socket, a white rim, a dark lens ring, the iris (blue, open) and a bright core, all set back a little
      const eye = new THREE.Group(); eye.position.z = R * 0.9; s.add(eye);
      const rimZ = Math.cos(HOLE) * R - R * 0.9;
      const sock = new THREE.Mesh(new THREE.CylinderGeometry(R * 0.46, R * 0.46, R * 0.16, 40, 1, true), sockM); sock.rotation.x = Math.PI / 2; sock.position.z = rimZ - R * 0.08; eye.add(sock);
      add(eye, new THREE.CircleGeometry(R * 0.46, 40), dark, 0, 0, rimZ - R * 0.16);
      add(eye, new THREE.TorusGeometry(R * 0.455, R * 0.04, 10, 44), white, 0, 0, rimZ);
      add(eye, new THREE.CircleGeometry(R * 0.4, 40), lensM, 0, 0, rimZ - R * 0.12);
      add(eye, new THREE.TorusGeometry(R * 0.36, R * 0.028, 8, 40), dark, 0, 0, rimZ - R * 0.11);
      add(eye, new THREE.CircleGeometry(R * 0.33, 40), eyeMat, 0, 0, rimZ - R * 0.1);
      add(eye, new THREE.CircleGeometry(R * 0.085, 24), pupil, 0, 0, rimZ - R * 0.095);
      const sp = new THREE.Sprite(glowS); sp.position.z = rimZ + R * 0.05; sp.scale.setScalar(R * 1.15); eye.add(sp);
      // light strips round the middle and under the belly
      for (const a of [-2.5, -1.8, -1.05, 1.05, 1.8, 2.5]) { const b = add(s, new THREE.BoxGeometry(R * 0.36, R * 0.05, R * 0.04), lights, Math.sin(a) * R * 1.0, 0, Math.cos(a) * R * 1.0); b.rotation.y = a + Math.PI / 2; }
      for (const a of [-0.6, 0, 0.6]) { const b = add(s, new THREE.BoxGeometry(R * 0.32, R * 0.04, R * 0.05), lights, Math.sin(a) * R * 0.62, -R * 0.78, Math.cos(a) * R * 0.62); b.rotation.set(0.9, a, 0); }
      if (k < 2) {
        // armour: plates over the shell (never over the eye), rocket pods on both flanks, fins on top of the big one
        for (let i = 0; i < (k === 0 ? 10 : 6); i++) {
          const th = (i / (k === 0 ? 10 : 6)) * TAU + 0.3, ph = i % 2 ? 0.55 : -0.45, x = Math.sin(th) * Math.cos(ph), y = Math.sin(ph), z = Math.cos(th) * Math.cos(ph);
          if (z > 0.55 && Math.abs(y) < 0.6) continue;
          const p = new THREE.Mesh(new THREE.BoxGeometry(R * 0.62, R * 0.46, R * 0.1), armor); p.position.set(x * R * 0.98, y * R * 0.98, z * R * 0.98); p.lookAt(x * R * 3, y * R * 3, z * R * 3); p.castShadow = !isTouch; s.add(p);
        }
        for (const sx of [-1, 1]) {
          const pod = new THREE.Mesh(new THREE.BoxGeometry(R * 0.3, R * 0.5, R * 0.7), armor); pod.position.set(sx * R * 1.02, 0.05 * R, 0); s.add(pod);
          for (let j = 0; j < 4; j++) add(s, new THREE.CircleGeometry(R * 0.06, 12), dark, sx * R * 1.02, (j < 2 ? 0.17 : -0.12) * R, R * 0.36 + 0.002).position.x += (j % 2 ? 0.07 : -0.07) * R;
        }
        if (k === 0) for (const sx of [-1, 1]) { const fin = new THREE.Mesh(new THREE.BoxGeometry(R * 0.05, R * 0.4, R * 0.6), armor); fin.position.set(sx * R * 0.25, R * 0.98, -R * 0.1); s.add(fin); }
      }
      s.visible = k === 0;
      e.shells.push({ g: s, R, eye });
    });
    e.noFar = true; e.fly = true; e.eyeH = 0; e.barY = 3.2;
    e.parts = shellParts(2.5);
  }
  const bar = new THREE.Group(); const bg = new THREE.Mesh(rBarGeo, rBarBg); bg.scale.set(0.7, 0.07, 1); bar.add(bg);
  const fill = new THREE.Mesh(rBarGeo, new THREE.MeshBasicMaterial({ color: T.mode === 'gdrone' ? 0xffc040 : 0x8ec8ff })); fill.scale.set(0.66, 0.045, 1); fill.position.z = 0.001; bar.add(fill);
  bar.visible = false; scene.add(bar); e.bar = bar; e.fill = fill;
  if (!e.noFar) bakeFar(e);
  return e;
}
function shellParts(R) { return [{ o: new THREE.Vector3(0, 0, 0), r: R, mult: 1 }, { o: new THREE.Vector3(0, 0, R * 0.9), r: R * 0.3, mult: 1, weak: true }]; }

/* ---------- small helpers ---------- */
function callNear(e, r) { for (const o of Enemies.list) if (o.robot && !o.alert && o !== e && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < r) Enemies.alarm(o); }
const _sv = new THREE.Vector3(), _sw = new THREE.Vector3(), _sx = new THREE.Vector3();
/* the way towards you on foot: straight when it sees you, along the walking grid when it does not */
function shipDir(e, dist, near) {
  if (dist < near && e.los) { _fd.x = _to.x / dist; _fd.z = _to.z / dist; return _fd; }
  if (flowDir(e.pos.x, e.pos.z, _fd)) return _fd;
  _fd.x = _to.x / dist; _fd.z = _to.z / dist; return _fd;
}

/* ---------- CCTV: watches and sweeps; once it has you it follows you and shoots weak single bolts ---------- */
function cctvAI(e, dt, dist, faceYaw) {
  e.spin += dt;
  const seen = e.los && dist < e.T.sight;
  if (!e.alert && seen) { Enemies.alarm(e); callNear(e, 22); }
  if (e.alert && seen) {
    turnToward(e, faceYaw, 3, dt);
    const dy = player.pos.y + 1.3 - e.pos.y; e.cam.rotation.x = lerp(e.cam.rotation.x, clamp(-Math.atan2(dy, dist), -0.3, 1.3), 1 - Math.exp(-dt * 6));
    e.react -= dt; if (e.react <= 0) robotFire(e, dt, dist);
  } else {
    e.yaw += Math.sin(e.spin * 0.5 + e.seed) * dt * 0.6; e.g.rotation.y = e.yaw; e.cam.rotation.x = lerp(e.cam.rotation.x, 0.45, 1 - Math.exp(-dt));
    if (e.alert) e.react = Math.max(e.react, 0.4);
  }
}
/* ---------- patrol bot: walks its beat; seen, it runs you down and swings the baton (60) ---------- */
function patrolAI(e, dt, dist, faceYaw) {
  const T = e.T;
  if (!e.alert && e.los && dist < T.sight) {
    let a = faceYaw - e.yaw; a = Math.atan2(Math.sin(a), Math.cos(a));
    if (Math.abs(a) < 1.3 || dist < 6) { Enemies.alarm(e); callNear(e, 16); Sound.zap(e.pos, 'turret'); }
  }
  if (!e.alert) {
    let sp = 0;
    const w = e.wp ? e.wp[e.wi] : null;
    if (w) {
      const dx = w.x - e.pos.x, dz = w.z - e.pos.z, l = Math.hypot(dx, dz);
      if (e.waitT > 0) { e.waitT -= dt; turnToward(e, e.yaw + Math.sin(e.waitT * 2.2) * 0.6, 1.4, dt); }
      else if (l < 0.6) { e.wi ^= 1; e.waitT = rand(1.2, 2.4); }
      else { sp = T.speed; turnToward(e, Math.atan2(dx, dz), 3, dt); groundMove(e, dx / l * sp, dz / l * sp, dt); }
    }
    robotWalk(e, sp, dt, false); e.armR.rotation.set(-0.35 - Math.sin(e.walk || 0) * 0.1, 0, -0.1);
    return;
  }
  const sd = stopDist(e), d = shipDir(e, dist, 22);
  e.swingCd = (e.swingCd || 0) - dt;
  let sp = dist > sd + 0.15 ? 5.8 : 0;
  if (e.swingT > 0) {
    e.swingT -= dt; sp *= 0.3; const u = 1 - e.swingT / 0.5;
    e.armR.rotation.set(u < 0.5 ? -0.6 - u * 4.6 : -2.9 + (u - 0.5) * 4.4, 0, -0.15); // up over its head, then down hard
    if (!e.hitDone && u >= 0.62) {
      e.hitDone = true; Sound.swoosh(e.pos);
      if (dist < sd + 1.2 && Math.abs(player.pos.y - e.pos.y) < 1.8) { player.hurt(T.dmg * e.dmgMul, e.pos, 'body'); Sound.batHit(e.pos); player.vel.x += _to.x / dist * 4; player.vel.z += _to.z / dist * 4; }
    }
  } else if (dist < sd + 0.8 && e.swingCd <= 0) { e.swingT = 0.5; e.swingCd = 1.15; e.hitDone = false; }
  turnToward(e, dist < 10 ? faceYaw : Math.atan2(d.x, d.z), 7, dt);
  e.vel.multiplyScalar(Math.exp(-dt * 6));
  groundMove(e, d.x * sp + e.vel.x, d.z * sp + e.vel.z, dt);
  robotWalk(e, sp, dt, false);
  if (!(e.swingT > 0)) e.armR.rotation.set(-0.95, 0, -0.15); // baton up and ready
}
/* ---------- drone A: drifts about the hall; once it has seen you it hangs over you, slides about and shoots small bolts ---------- */
function droneAAI(e, dt, dist, faceYaw) {
  const T = e.T; e.spin += dt;
  for (const ro of e.rotors) ro.rotation.y += dt * 42;
  const ceil = (World.style.ship ? shipCeil(e.pos.x, e.pos.z) : 30) - 0.9;
  if (!e.alert) {
    if ((e.los && dist < T.sight) || dist < 8) { Enemies.alarm(e); callNear(e, 18); }
    else {
      e.goalT = (e.goalT || 0) - dt;
      if (!e.goal || e.goalT <= 0 || Math.hypot(e.goal.x - e.pos.x, e.goal.z - e.pos.z) < 1.5) {
        const Rm = shipRoom(e.pos.x, e.pos.z) || SHIP_ROOMS[2]; e.goalT = rand(3, 7);
        e.goal = { x: rand(Rm[0] + 3, Rm[2] - 3), z: rand(Rm[1] + 3, Rm[3] - 3), y: rand(3.5, Math.min(10, Rm[4] - 1.5)) };
      }
      const dx = e.goal.x - e.pos.x, dz = e.goal.z - e.pos.z, l = Math.hypot(dx, dz) || 1;
      if (moveXZ(e.pos, dx / l * 2.2 * dt, dz / l * 2.2 * dt, e.R, e.H, 0.8)) e.goalT = 0;
      e.pos.y += (Math.min(e.goal.y, ceil) - e.pos.y) * (1 - Math.exp(-dt));
      turnToward(e, Math.atan2(dx, dz), 2, dt); e.g.rotation.x = 0.08;
      return;
    }
  }
  // 5.16: no lower than 1.8 m over the floor under it (down in the hall's pit too), no higher than 22 m
  const lo = PIT === null ? 2.4 : groundAt(e.pos.x, e.pos.y + 0.3, e.pos.z, e.R) + 1.8;
  const ty = Math.min(clamp(player.pos.y + 4 + Math.sin(e.spin * 1.3 + e.seed) * 1.2, lo, 22), ceil);
  e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.4));
  e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.4, 3); }
  let fx = _to.x / dist, fz = _to.z / dist;
  if (!e.los && flowDir(e.pos.x, e.pos.z, _fd)) { fx = _fd.x; fz = _fd.z; }
  const fwd = !e.los || dist > 15 ? 1 : dist < 8 ? -0.7 : 0, side = e.los ? 0.8 : 0;
  const mvx = (fx * fwd - fz * e.strafe * side) * T.speed, mvz = (fz * fwd + fx * e.strafe * side) * T.speed;
  e.vel.multiplyScalar(Math.exp(-dt * 3));
  if (moveXZ(e.pos, (mvx + e.vel.x) * dt, (mvz + e.vel.z) * dt, e.R, e.H, PIT === null ? 0 : 0.8)) e.strafe *= -1;
  turnToward(e, faceYaw, 4, dt); e.g.rotation.x = clamp(fwd * 0.18, -0.2, 0.2);
  e.react -= dt; if (e.los && dist < T.range && e.react <= 0) robotFire(e, dt, dist);
}
/* ---------- spider mine: buried in the floor; you come within reach and it springs up, scuttles at you and goes off (100).
   one bullet sets it off too ---------- */
function mineLegs(e, dt, sp) {
  e.walk = (e.walk || 0) + dt * (4 + sp * 3);
  const up = e.bs === 'hidden' || e.bs === 'arm' || e.bs === 'fall' ? 0 : 1;
  e.cl.forEach((p, i) => { p.rotation.z = up ? -0.15 + Math.sin(e.walk + i * 1.7) * 0.35 * Math.min(1, sp / 4) : -0.75; });
  e.body.position.y = up ? Math.abs(Math.sin(e.walk * 2)) * 0.03 : 0;
}
function mineAI(e, dt, dist) {
  const T = e.T;
  if (e.bs === 'fall') { // thrown out by the boss: arcing down to the floor
    e.vy -= 18 * dt; e.pos.x += e.vel.x * dt; e.pos.z += e.vel.z * dt; e.pos.y += e.vy * dt;
    const gy = groundAt(e.pos.x, e.pos.y + 0.3, e.pos.z, 0.2);
    if (e.pos.y <= gy && e.vy < 0) { e.pos.y = gy; e.baseY = gy; e.bs = 'arm'; e.bt = 1.0; e.vel.set(0, 0, 0); FX.puff(e.pos, 2, 0.3, 0.3); Sound.metal(e.pos); }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'arm') { // landed: blinking while it arms itself
    e.bt -= dt; e.light.material.color.setHex(Math.sin(e.bt * 30) > 0 ? 0xff3020 : 0x401010);
    if (e.bt <= 0) { if (dist < 9) { e.bs = 'wake'; e.bt = 0.3; Sound.chirp(e.pos); } else { e.bs = 'hidden'; e.light.material.color.setHex(0x401010); } }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'hidden') {
    e.pos.y = e.baseY - 0.16;
    if (dist < T.sight && (e.los || dist < 3.5) && Math.abs(player.pos.y - e.baseY) < 2.5) { e.bs = 'wake'; e.bt = 0.3; Sound.chirp(e.pos); }
    mineLegs(e, dt, 0); return;
  }
  if (e.bs === 'wake') {
    e.bt -= dt; e.pos.y = e.baseY - 0.16 * Math.max(0, e.bt / 0.3); e.light.material.color.setHex(0xff2a1a);
    if (e.bt <= 0) { e.bs = 'run'; e.bt = 7; e.alert = true; }
    turnToward(e, Math.atan2(_to.x, _to.z), 10, dt); mineLegs(e, dt, 2); return;
  }
  // running at you
  e.bt -= dt;
  const d = shipDir(e, dist, 12);
  groundMove(e, d.x * T.speed, d.z * T.speed, dt); turnToward(e, Math.atan2(d.x, d.z), 12, dt);
  e.light.material.color.setHex((e.bt * 8) % 1 < 0.5 ? 0xff2a1a : 0x601010);
  mineLegs(e, dt, T.speed);
  if ((dist < 1.25 && Math.abs(player.pos.y - e.pos.y) < 1.6) || e.bt <= 0) Enemies.detonate(e);
}
/* ---------- the gold commander drone, a golden bee: wakes the whole corridor when it sees you, shoots its twin cannons,
   and between bursts either calls little quad drones out of its belly or winds up and rams you (160 and a hard shove) ---------- */
function gdroneDrones(e) {
  let live = 0; for (const o of Enemies.list) if (o.alive && o.fromBee) live++;
  const n = Math.min(e.rage ? 5 : 4, 12 - live); if (n <= 0) return 0;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU + rand(-0.3, 0.3), m = Enemies.spawn('droneA', e.pos.x + Math.cos(a) * 1.6, e.pos.z + Math.sin(a) * 1.6, { y: e.pos.y - 0.6, yaw: e.yaw });
    if (!m) continue; m.fromBee = true; m.alert = true; m.awake = true; m.lod = 0; m.vel.set(Math.cos(a) * 4, 0, Math.sin(a) * 4);
  }
  Game.goal += n; FX.puff({ x: e.pos.x, y: e.pos.y - 0.5, z: e.pos.z }, 6, 0.7, 0.6); Sound.spawn(e.pos);
  HUD.feed('황금꿀벌드론이 드론 ' + n + '대를 불러냈습니다', 0, 'hs');
  return n;
}
function gdroneAI(e, dt, dist, faceYaw) {
  const T = e.T; e.spin += dt;
  if (e.baseY === undefined) e.baseY = e.pos.y;
  // wings beating all the time, faster when it is roused
  if (e.wings) { const f = Math.sin(e.spin * (e.alert ? 46 : 30)); for (const W of e.wings) W.g.rotation.z = W.sx * (0.18 + f * 0.42); }
  if (e.sealed) { e.pos.y = e.baseY + Math.sin(e.spin * 1.2) * 0.15; e.g.rotation.z = Math.sin(e.spin * 0.8) * 0.03; return; } // behind its shut door: deaf and blind to you
  if (!e.alert) {
    e.pos.y = e.baseY + Math.sin(e.spin * 1.2) * 0.15; e.g.rotation.z = Math.sin(e.spin * 0.8) * 0.03;
    if ((e.los && dist < T.sight) || dist < 10) {
      Enemies.alarm(e); Sound.alarm(); let n = 0;
      for (const o of Enemies.list) if (o.robot && !o.alert && o !== e && !o.boss && o.T.mode !== 'mine' && Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z) < 75) { Enemies.alarm(o); n++; }
      HUD.feed('황금꿀벌드론이 경보를 울렸습니다 · 로봇 ' + n + '대가 몰려옵니다', 0, 'hs');
    } else return;
  }
  const Rm = SHIP_ROOMS[0];
  if (!e.rage && e.hp < e.maxHp * 0.4) { e.rage = true; HUD.feed('황금꿀벌드론이 분노했습니다 · 더 빠르고 자주 돌진합니다', 0, 'hs'); }
  // the charge: a wind-up (shaking, eyes glowing), then straight at where you stood; a wall or a hit ends it, and it hangs there a second
  if (e.dash) {
    const D = e.dash; D.t += dt;
    if (D.mode === 'wind') {
      e.pos.x += rand(-1, 1) * 0.04; e.pos.y += rand(-1, 1) * 0.03; turnToward(e, Math.atan2(D.tx - e.pos.x, D.tz - e.pos.z), 6, dt);
      if (e.beeEye) e.beeEye.emissive.setRGB(1.2 * D.t, 0.2 * D.t, 0);
      if (D.t >= 0.75) { D.mode = 'go'; D.t = 0; const dx = D.tx - e.pos.x, dy = D.ty - e.pos.y, dz = D.tz - e.pos.z, l = Math.hypot(dx, dy, dz) || 1; D.vx = dx / l; D.vy = dy / l; D.vz = dz / l; Sound.swoosh(e.pos); }
      return;
    }
    if (D.mode === 'go') {
      const sp = e.rage ? 27 : 22;
      const blocked = moveXZ(e.pos, D.vx * sp * dt, D.vz * sp * dt, e.R * 0.8, 1, 0); e.pos.y = clamp(e.pos.y + D.vy * sp * dt, 1.6, shipCeil(e.pos.x, e.pos.z) - 1.4);
      e.g.rotation.x = 0.25;
      const pdx = player.pos.x - e.pos.x, pdz = player.pos.z - e.pos.z, py = clamp(e.pos.y, player.pos.y + 0.3, player.pos.y + player.height - 0.2);
      if (!D.hit && Math.hypot(pdx, e.pos.y - py, pdz) < e.R + 0.7 && state === 'playing') {
        D.hit = true; player.hurt(160, e.pos, 'body'); Sound.thud(player.pos); Sound.metal(player.pos);
        const l = Math.hypot(pdx, pdz) || 1; player.vel.x += pdx / l * 13; player.vel.z += pdz / l * 13; player.vel.y = 4.5; player.grounded = false; player.shake = Math.max(player.shake, 0.7); buzz(160);
      }
      if (blocked || D.hit || D.t > 1.5) { D.mode = 'rest'; D.t = 0; if (blocked) { FX.sparks(e.pos, 14, [1, 0.8, 0.4], 4); Sound.thud(e.pos); player.shake = Math.max(player.shake, dist < 20 ? 0.25 : 0); } }
      return;
    }
    // resting after the charge: a sitting target
    e.g.rotation.x = lerp(e.g.rotation.x, 0, 1 - Math.exp(-dt * 4)); if (e.beeEye) e.beeEye.emissive.setRGB(0.23, 0.04, 0);
    if (D.t > 1.0) e.dash = null; else return;
  }
  e.strafeT -= dt; if (e.strafeT <= 0) { e.strafe *= -1; e.strafeT = rand(1.6, 3.2); }
  const fx = _to.x / dist, fz = _to.z / dist, fwd = !e.los ? 0.6 : dist > 16 ? 0.8 : dist < 9 ? -0.8 : 0, sp = T.speed * (e.rage ? 1.4 : 1);
  moveXZ(e.pos, (fx * fwd - fz * e.strafe * 0.9) * sp * dt, (fz * fwd + fx * e.strafe * 0.9) * sp * dt, e.R, 1, 0);
  e.pos.x = clamp(e.pos.x, Rm[0] + 2.2, Rm[2] + 5); e.pos.z = clamp(e.pos.z, Rm[1] + 2.2, Rm[3] - 2.2);
  if (e.pos.x > Rm[2] - 1) e.pos.z = clamp(e.pos.z, -11, -4); // only out into the corridor mouth, not through its walls
  const ty = clamp(player.pos.y + 3.2 + Math.sin(e.spin * 0.9) * 0.6, 2.8, (e.pos.x > Rm[2] ? 6 : Rm[4]) - 1.7);
  e.pos.y += (ty - e.pos.y) * (1 - Math.exp(-dt * 1.5));
  turnToward(e, faceYaw, 3, dt); e.g.rotation.z = lerp(e.g.rotation.z, -e.strafe * 0.1, 1 - Math.exp(-dt * 3));
  e.react -= dt;
  if (e.los && dist < T.range && e.react <= 0) { const b0 = e.burst; robotFire(e, dt * (e.rage ? 1.6 : 1), dist); if (e.burst !== b0) e.muzzle.x = -e.muzzle.x; }
  e.skillT = (e.skillT === undefined ? 4 : e.skillT) - dt;
  if (e.skillT <= 0 && dist < 45) {
    e.skillT = e.rage ? rand(3.4, 4.4) : rand(5.5, 7);
    const want = e.lastSkill === 'call' || !e.los ? 'dash' : e.lastSkill === 'dash' ? 'call' : Math.random() < 0.5 ? 'call' : 'dash';
    if (want === 'call' && gdroneDrones(e)) e.lastSkill = 'call';
    else if (e.los && dist > 4) { e.lastSkill = 'dash'; e.dash = { mode: 'wind', t: 0, tx: player.pos.x, ty: player.pos.y + 1.2, tz: player.pos.z, hit: false }; Sound.charge(e.pos, 0.75); }
  }
}

/* ---------- the boss drone ---------- */
const BPH = [
  { sp: 5, y: [8, 11], dist: [16, 24], charge: 3, track: 7, rockets: 1, win: 0, mines: 5, gap: [4.2, 5.4] },
  { sp: 8, y: [6, 9.5], dist: [12, 20], charge: 2, track: 9, rockets: 10, win: 1.0, mines: 10, gap: [3.2, 4.2] },
  { sp: 12, y: [3.2, 7], dist: [8, 16], charge: 1, track: 12, rockets: 100, win: 2.5, mines: 20, gap: [2.4, 3.2] },
];
const HALL = SHIP_ROOMS[2];
const LASER_WARN = 3; // seconds of red eye before the aim starts: the shot comes 6, 5 and 4 s after the eye turns red
function bossEye(e, out) { const s = e.shells[e.k ? e.k.phase : 0]; e.g.updateMatrixWorld(true); return out.setFromMatrixPosition(s.eye.matrixWorld); }
/* closest distance between segment a-b and segment c-d */
function segDist(a, b, c, d) {
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z, vx = d.x - c.x, vy = d.y - c.y, vz = d.z - c.z, wx = a.x - c.x, wy = a.y - c.y, wz = a.z - c.z;
  const A = ux * ux + uy * uy + uz * uz, Bb = ux * vx + uy * vy + uz * vz, Cc = vx * vx + vy * vy + vz * vz, D = ux * wx + uy * wy + uz * wz, E = vx * wx + vy * wy + vz * wz;
  const den = A * Cc - Bb * Bb; let s = den > 1e-9 ? clamp((Bb * E - Cc * D) / den, 0, 1) : 0, t = Cc > 1e-9 ? (Bb * s + E) / Cc : 0;
  if (t < 0) { t = 0; s = A > 1e-9 ? clamp(-D / A, 0, 1) : 0; } else if (t > 1) { t = 1; s = A > 1e-9 ? clamp((Bb - D) / A, 0, 1) : 0; }
  return Math.hypot(wx + ux * s - vx * t, wy + uy * s - vy * t, wz + uz * s - vz * t);
}
function bossGuard(e, dmg) {
  const k = e.k; if (!k) return dmg;
  if (k.mode === 'shed') return 0; // the shell is coming apart: nothing gets through
  const floor = k.phase === 0 ? e.maxHp * 2 / 3 : k.phase === 1 ? e.maxHp / 3 : -Infinity;
  if (e.hp - dmg <= floor) { e.hp = floor; bossShed(e); return 0; }
  return dmg;
}
/* a third of its health gone: the outer shell blows apart and a smaller, faster drone comes out of it */
function bossShed(e) {
  const k = e.k; if (k.phase >= 2) return;
  k.mode = 'shed'; k.t = 0; k.salvo = 0; ShipFX.aimOff();
  const old = e.shells[k.phase]; k.phase++; const nw = e.shells[k.phase];
  FX.explode(e.pos, true); FX.explode({ x: e.pos.x + old.R * 0.5, y: e.pos.y, z: e.pos.z - old.R * 0.3 }, true); FX.explode({ x: e.pos.x - old.R * 0.4, y: e.pos.y + old.R * 0.4, z: e.pos.z }, true);
  FX.chunks(e.pos, 26, 0.18 * old.R, 'metal'); Sound.boom(e.pos, true); player.shake = Math.max(player.shake, 0.5);
  old.g.visible = false; nw.g.visible = true;
  e.R = nw.R; e.H = nw.R * 2; e.barY = nw.R + 0.7; e.parts = shellParts(nw.R); e.eyeMat.color.setHex(BLUE); e.eyeGlow.color.setHex(0x2f8cff);
  HUD.banner('B-3 · ' + (k.phase + 1) + '페이즈', k.phase === 2 ? '껍데기가 모두 벗겨지고 핵이 드러났습니다 · 가장 작고 빠릅니다' : '바깥 껍데기가 부서졌습니다 · 더 작고 빨라졌습니다', 2.6);
  if (k.phase === 2) Ship.hatchWait = 2.6; // and, once the banner has gone, the floor opens: drones by the dozen
}
function bossDropMines(e, n) {
  const live = Enemies.list.filter((o) => o.extra && o.alive).length; n = Math.min(n, 45 - live);
  for (let i = 0; i < n; i++) {
    let tx = 0, tz = 0;
    // straight down out of its belly, spreading a little round the spot under it
    let ty = 0;
    for (let tries = 0; tries < 8; tries++) { const a = rand(0, TAU), rr = rand(0.2, 1.2 + n * 0.12); tx = e.pos.x + Math.cos(a) * rr; tz = e.pos.z + Math.sin(a) * rr; ty = groundAt(tx, e.pos.y, tz, 0.2); if (shipRoom(tx, tz) && !collideAt(tx, ty + 0.05, tz, 0.4, 0.5)) break; }
    const m = Enemies.spawn('mine', e.pos.x, e.pos.z, { y: e.pos.y - e.R * 0.5, yaw: rand(0, TAU) });
    if (!m) continue;
    const T = rand(0.45, 0.75); m.extra = true; m.bs = 'fall'; m.vel.set((tx - e.pos.x) / T, 0, (tz - e.pos.z) / T); m.vy = (ty - m.pos.y + 0.5 * 18 * T * T) / T; m.baseY = ty; m.alert = true; m.awake = true; m.lod = 0;
  }
  Sound.clank(e.pos);
}
function bossFireLaser(e) {
  const k = e.k; bossEye(e, _sv); _sw.copy(k.aim).sub(_sv).normalize();
  const hit = raycastStatic(_sv.x, _sv.y, _sv.z, _sw.x, _sw.y, _sw.z, 160), L = hit ? RH.t : 160;
  _sx.copy(_sv).addScaledVector(_sw, L);
  if (hit && RH.box && RH.box.kind === 'wood' && RH.box.ref) damageCrate(RH.box.ref, 999, _sx);
  ShipFX.beam(_sv, _sx); Sound.beam(_sv); FX.sparks(_sx, 14, [1, 0.3, 0.2], 4);
  // touching the beam anywhere along its length is the end
  const a = { x: player.pos.x, y: player.pos.y + 0.2, z: player.pos.z }, b = { x: player.pos.x, y: player.pos.y + player.height, z: player.pos.z };
  if (state === 'playing' && player.invuln <= 0 && segDist(_sv, _sx, a, b) < 0.55) Game.laser(e);
}
function bossLaunch(e) {
  const k = e.k, sx = k.salvo % 2 ? 1 : -1, cy = Math.cos(e.yaw), syaw = Math.sin(e.yaw);
  _sv.set(e.pos.x + cy * sx * e.R * 0.95, e.pos.y + e.R * 0.2, e.pos.z - syaw * sx * e.R * 0.95);
  _sw.set(cy * sx * 0.7 + syaw * 0.5 + rand(-0.4, 0.4), 0.5 + rand(0, 0.6), -syaw * sx * 0.7 + cy * 0.5 + rand(-0.4, 0.4));
  Rockets.fire(_sv, _sw, 100, k.phase === 2 ? 13 : 15, 0);
  if (k.salvo % 6 === 0) Sound.rocket(e.pos);
}
function bdroneAI(e, dt, dist, faceYaw) {
  const k = e.k || (e.k = { phase: 0, mode: 'idle', t: 0, cd: 2.5, last: '', goal: null, goalT: 0, v: new THREE.Vector3(), aim: new THREE.Vector3(), salvo: 0, salvoT: 0, gapT: 0, wake: 0 });
  if (!e.guard) e.guard = bossGuard;
  const P = BPH[k.phase]; k.t += dt;
  e.spin += dt;
  if (k.mode === 'idle') {
    e.pos.y += Math.sin(e.spin * 1.1) * dt * 0.3;
    if (e.sealed) { e.yaw += dt * 0.25; e.g.rotation.y = e.yaw; return; } // behind its shut door: turning slowly, aware of nothing
    if ((e.los && dist < 45) || e.alert || dist < 20) { k.mode = 'move'; k.cd = 2; e.alert = true; Sound.alarm(); }
    else { turnToward(e, faceYaw, 0.6, dt); return; }
  }
  // where to be: round you at its own distance and height, inside the hall, clear of the reactor
  if (k.mode !== 'shed') {
    k.goalT -= dt;
    if (!k.goal || k.goalT <= 0) {
      // 5.16: a spot at its distance from you that is inside the hall (with you by a wall, a random one is often outside it, and clamped
      // back it would sit right over you); a few tries, then the last one, clamped
      let gx = 0, gz = 0;
      for (let t = 0; t < 10; t++) { const a = rand(0, TAU), rr = rand(P.dist[0], P.dist[1]); gx = player.pos.x + Math.cos(a) * rr; gz = player.pos.z + Math.sin(a) * rr;
        if (gx > HALL[0] + e.R + 2 && gx < HALL[2] - e.R - 2 && gz > HALL[1] + e.R + 2 && gz < HALL[3] - e.R - 2) break; }
      k.goal = { x: gx, y: Math.min(player.pos.y, 6) + rand(P.y[0], P.y[1]), z: gz }; k.goalT = rand(1.6, 3);
    }
    const dx = k.goal.x - e.pos.x, dy = k.goal.y - e.pos.y, dz = k.goal.z - e.pos.z, l = Math.hypot(dx, dy, dz), sp = P.sp * (k.mode === 'charge' ? 0.4 : 1);
    _sv.set(l > 0.4 ? dx / l * sp : 0, l > 0.4 ? dy / l * sp : 0, l > 0.4 ? dz / l * sp : 0);
    k.v.lerp(_sv, 1 - Math.exp(-dt * 2)); e.pos.addScaledVector(k.v, dt);
  } else { e.pos.y += Math.sin(k.t * 9) * dt * 0.6; }
  const R = e.R;
  e.pos.x = clamp(e.pos.x, HALL[0] + R + 0.6, HALL[2] - R - 0.6); e.pos.z = clamp(e.pos.z, HALL[1] + R + 0.6, HALL[3] - R - 0.6);
  e.pos.y = clamp(e.pos.y, groundAt(e.pos.x, e.pos.y, e.pos.z, R * 0.5) + R + 0.4, shipCeil(e.pos.x, e.pos.z) - R);
  const rx = e.pos.x - REACTOR.x, rz = e.pos.z - REACTOR.z, rd = Math.hypot(rx, rz), need = REACTOR.r + R + 0.8;
  if (rd < need) { e.pos.x = REACTOR.x + rx / (rd || 1) * need; e.pos.z = REACTOR.z + rz / (rd || 1) * need; }
  for (const [px, pz, ph, , ptop] of HALL_PILLARS) { if (e.pos.y - R > ptop + 0.5) continue; // over the top of an inner pillar is open
    const qx = e.pos.x - px, qz = e.pos.z - pz, q = Math.hypot(qx, qz), nd = ph * 1.42 + R + 0.3; if (q < nd) { e.pos.x = px + qx / (q || 1) * nd; e.pos.z = pz + qz / (q || 1) * nd; } }
  // face you, eye first
  turnToward(e, faceYaw, k.phase === 2 ? 6 : 3, dt);
  e.g.rotation.x = lerp(e.g.rotation.x, clamp(Math.atan2(e.pos.y - (player.pos.y + 1.2), dist), -0.6, 1.1), 1 - Math.exp(-dt * 4));
  if (k.phase === 2) e.g.rotation.z = Math.sin(e.spin * 3) * 0.12;
  if (k.mode === 'shed') { if (k.t >= 1.4) { k.mode = 'move'; k.cd = 1.2; } return; }
  // rockets already ordered keep leaving while it flies
  if (k.salvo > 0) { k.salvoT -= dt; while (k.salvo > 0 && k.salvoT <= 0) { k.salvo--; k.salvoT += k.gapT; bossLaunch(e); } }
  if (k.mode === 'warn') { // the eye is red and it keeps moving; in three seconds the red line comes out, with the siren
    if (k.t >= LASER_WARN) { k.mode = 'charge'; k.t = 0; k.aim.set(player.pos.x, player.pos.y + 1.1, player.pos.z); Sound.siren2(P.charge + 0.25); }
    return;
  }
  if (k.mode === 'charge') {
    // the eye is red; the aim drifts after you and holds still for the last quarter second
    const left = P.charge - k.t;
    if (left > 0.25) { _sw.set(player.pos.x, player.pos.y + 1.1, player.pos.z).sub(k.aim); const L = _sw.length(), step = P.track * dt; if (L > step) _sw.multiplyScalar(step / L); k.aim.add(_sw); }
    bossEye(e, _sv); _sw.copy(k.aim).sub(_sv).normalize();
    const hit = raycastStatic(_sv.x, _sv.y, _sv.z, _sw.x, _sw.y, _sw.z, 160); _sx.copy(_sv).addScaledVector(_sw, hit ? RH.t : 160);
    ShipFX.aim(_sv, _sx, left);
    if (k.t >= P.charge) { ShipFX.aimOff(); bossFireLaser(e); k.mode = 'cool'; k.t = 0; }
    return;
  }
  if (k.mode === 'cool') { if (k.t > 0.35) { e.eyeMat.color.setHex(BLUE); e.eyeGlow.color.setHex(0x2f8cff); k.mode = 'move'; } return; }
  k.cd -= dt;
  if (k.cd <= 0) {
    const opts = ['laser', 'rockets', 'mines'].filter((s) => s !== k.last && (s === 'mines' || e.los));
    const s = opts.length ? pick(opts) : 'mines'; k.last = s;
    if (s === 'laser') { k.mode = 'warn'; k.t = 0; e.eyeMat.color.setHex(RED); e.eyeGlow.color.setHex(0xff3a2a); } // red eye first: 3 s, then the aim
    else if (s === 'rockets') { k.salvo = P.rockets; k.gapT = P.rockets > 1 ? P.win / P.rockets : 0; k.salvoT = 0; Sound.rocket(e.pos); }
    else bossDropMines(e, P.mines);
    k.cd = rand(P.gap[0], P.gap[1]) + (s === 'laser' ? P.charge + LASER_WARN : 0);
  }
}
function updateShipBot(e, dt, dist, faceYaw) {
  const m = e.T.mode;
  if (m === 'cctv') cctvAI(e, dt, dist, faceYaw);
  else if (m === 'patrol') patrolAI(e, dt, dist, faceYaw);
  else if (m === 'droneA') droneAAI(e, dt, dist, faceYaw);
  else if (m === 'mine') mineAI(e, dt, dist);
  else if (m === 'gdrone') gdroneAI(e, dt, dist, faceYaw);
  else bdroneAI(e, dt, dist, faceYaw);
}

/* ---------- homing rockets: drawn as one instanced mesh; each one turns towards you a little at a time while it can see you
   (behind a wall it loses you and flies straight on into the wall) and bursts on a wall, the floor, or you ---------- */
const Rockets = (() => {
  const MAX = 220, list = [], o = new THREE.Object3D(), zero = new THREE.Matrix4().makeScale(0, 0, 0), _d = new THREE.Vector3(), _v = new THREE.Vector3(), _t = new THREE.Vector3();
  let im = null;
  function ensure() {
    if (im) return;
    const geo = new THREE.CylinderGeometry(0.07, 0.1, 0.6, 8); geo.rotateX(Math.PI / 2);
    im = new THREE.InstancedMesh(geo, new THREE.MeshStandardMaterial({ color: 0xc8ced8, metalness: 0.6, roughness: 0.35, emissive: 0x331000 }), MAX);
    im.frustumCulled = false; for (let i = 0; i < MAX; i++) im.setMatrixAt(i, zero); scene.add(im);
  }
  function fire(from, dir, dmg, speed, delay) {
    ensure(); if (list.length >= MAX) return;
    list.push({ p: from.clone(), v: dir.clone().normalize().multiplyScalar(speed || 15), dmg, life: 8, trail: 0, wait: delay || 0, seeT: Math.random() * 0.15, sees: true });
  }
  function blast(c, dmg, loud) {
    FX.explode(c, false); if (loud) Sound.boom(c, false);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.4 - d * 0.03, 0, 0.4));
    if (d < 3 && state === 'playing' && lineOfSight(c, _t.set(player.pos.x, player.pos.y + 1.2, player.pos.z))) player.hurt(d < 1.2 ? dmg : dmg * (1 - (d - 1.2) / 1.8 * 0.7), c, 'body');
  }
  function update(dt) {
    if (!im) return;
    const tx = player.pos.x, ty = player.pos.y + 1.0, tz = player.pos.z; let loud = 0;
    for (let i = list.length - 1; i >= 0; i--) {
      const R = list[i];
      if (R.wait > 0) { R.wait -= dt; continue; }
      R.life -= dt;
      _d.set(tx - R.p.x, ty - R.p.y, tz - R.p.z); const dl = _d.length() || 1; _d.divideScalar(dl);
      R.seeT -= dt; if (R.seeT <= 0) { R.seeT = 0.15; R.sees = lineOfSight(R.p, _t.set(tx, ty, tz)); }
      const sp = R.v.length(); _v.copy(R.v).divideScalar(sp); if (R.sees) _v.lerp(_d, Math.min(1, 1.5 * dt)).normalize(); R.v.copy(_v).multiplyScalar(sp);
      const step = sp * dt, hit = raycastStatic(R.p.x, R.p.y, R.p.z, _v.x, _v.y, _v.z, step);
      R.p.addScaledVector(_v, hit ? RH.t : step);
      if (hit || dl < 1.0 || R.life <= 0 || R.p.y < floorY(R.p.x, R.p.z) + 0.05) { blast(R.p, R.dmg, loud++ < 4); list.splice(i, 1); continue; }
      R.trail -= dt; if (R.trail <= 0) { R.trail = list.length > 40 ? 0.1 : 0.04; FX.glow.emit({ x: R.p.x, y: R.p.y, z: R.p.z, vx: 0, vy: 0, vz: 0, max: 0.35, s0: 0.28, s1: 0.06, r: 1, g: 0.55, b: 0.25, a: 0.8, grav: 0, drag: 0 }); }
    }
    let n = 0;
    for (const R of list) { if (R.wait > 0) continue; o.position.copy(R.p); o.lookAt(R.p.x + R.v.x, R.p.y + R.v.y, R.p.z + R.v.z); o.updateMatrix(); im.setMatrixAt(n++, o.matrix); }
    for (let i = n; i < MAX; i++) im.setMatrixAt(i, zero);
    im.instanceMatrix.needsUpdate = true;
  }
  function clear() { list.length = 0; if (im) { for (let i = 0; i < MAX; i++) im.setMatrixAt(i, zero); im.instanceMatrix.needsUpdate = true; } }
  return { fire, update, clear, get count() { return list.length; } };
})();

/* ---------- the boss's laser (a thin red aiming line, then the beam) and the spider mines' blasts ---------- */
const ShipFX = (() => {
  const queue = [];
  let aimLine = null, beam = null, core = null, beamT = 0;
  const aimMat = new THREE.MeshBasicMaterial({ color: 0xff2a2a, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false });
  const beamMat = new THREE.MeshBasicMaterial({ color: 0xff3a2a, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false });
  const coreMat = new THREE.MeshBasicMaterial({ color: 0xffd8d0, transparent: true, opacity: 1, blending: THREE.AdditiveBlending, depthWrite: false });
  const _m = new THREE.Vector3(), _q = new THREE.Vector3();
  function make() {
    if (aimLine) return;
    aimLine = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.03, 1), aimMat); aimLine.frustumCulled = false; aimLine.visible = false; scene.add(aimLine);
    const g = new THREE.CylinderGeometry(1, 1, 1, 10, 1, true); g.rotateX(Math.PI / 2);
    beam = new THREE.Mesh(g, beamMat); beam.frustumCulled = false; beam.visible = false; scene.add(beam);
    core = new THREE.Mesh(g, coreMat); core.frustumCulled = false; core.visible = false; scene.add(core);
  }
  function lay(m, a, b, w) { _m.copy(a).add(b).multiplyScalar(0.5); m.position.copy(_m); m.lookAt(b); m.scale.set(w, w, a.distanceTo(b)); }
  function aim(a, b, left) { make(); aimLine.visible = true; lay(aimLine, a, b, 1 + (left < 0.25 ? 2 : 0)); aimMat.opacity = left < 0.25 ? 1 : 0.45 + 0.3 * Math.sin(time * 30); }
  function aimOff() { if (aimLine) aimLine.visible = false; }
  function fireBeam(a, b) { make(); beamT = 0.4; beam.visible = core.visible = true; lay(beam, a, b, 0.28); lay(core, a, b, 0.09); }
  function mineBlast(c, delay) { queue.push({ x: c.x, y: c.y + 0.25, z: c.z, t: delay || 0 }); }
  function blast(c) {
    FX.explode(c, false); Sound.boom(c, false); Enemies.noise(c, 30);
    const d = Math.hypot(c.x - player.pos.x, c.y - (player.pos.y + 0.9), c.z - player.pos.z);
    player.shake = Math.max(player.shake, clamp(0.6 - d * 0.05, 0, 0.6));
    if (d < 3.5 && state === 'playing' && lineOfSight(c, _q.set(player.pos.x, player.pos.y + 1.0, player.pos.z))) player.hurt(d < 2 ? 100 : Math.round(100 * (1 - (d - 2) / 1.5)), c, 'body');
    for (const cr of crates.slice()) if (!cr.dead && Math.hypot(cr.x - c.x, (cr.y || 0) + 0.6 - c.y, cr.z - c.z) < 2.6) damageCrate(cr, 100, { x: cr.x, y: (cr.y || 0) + 0.6, z: cr.z });
    Enemies.splash(c, 3, 100); // other mines go off in a chain
  }
  function update(dt) {
    // drones coming up out of the hall's hatches: not among the hundred, gone with the boss
    if (Ship.hatchWait > 0 && (Ship.hatchWait -= dt) <= 0) { Ship.hatchWait = 0; if (Game.boss && Game.boss.alive) Ship.openHatches(); }
    const hq = Ship.hatchQ;
    for (let i = hq.length - 1; i >= 0; i--) { const q = hq[i]; q.t -= dt; if (q.t > 0) continue; hq.splice(i, 1);
      if (!Game.boss || !Game.boss.alive) continue;
      const m = Enemies.spawn('droneA', q.x + rand(-0.4, 0.4), q.z + rand(-0.4, 0.4), { y: (q.y || 0) + 0.3, yaw: rand(0, TAU) });
      if (m) { m.extra = true; m.alert = true; m.awake = true; m.lod = 0; FX.puff({ x: q.x, y: (q.y || 0) + 0.4, z: q.z }, 2, 0.4, 0.5); Sound.zap(m.pos, 'drone'); } }
    for (let i = queue.length - 1; i >= 0; i--) { const q = queue[i]; q.t -= dt; if (q.t <= 0) { queue.splice(i, 1); blast(q); } }
    if (beamT > 0) { beamT -= dt; const k = clamp(beamT / 0.4, 0, 1); beamMat.opacity = 0.85 * k; coreMat.opacity = k; if (beamT <= 0) beam.visible = core.visible = false; }
  }
  function clear() { queue.length = 0; beamT = 0; Ship.hatchQ.length = 0; Ship.hatchWait = 0; if (aimLine) aimLine.visible = beam.visible = core.visible = false; }
  return { aim, aimOff, beam: fireBeam, mineBlast, update, clear };
})();

/* ---------- stage 4's hundred: the boss over the hall, the gold bee alone on the bridge, cameras up the passage and along the corridor,
   patrols and little drones along the corridor, and mines in the floor of the corridor and the hall ---------- */
function populateShip(G, put, find, rand, randi, SR) {
  // the boss over the hall and the bee on the bridge, each sealed behind its door until you come through it (5.13)
  const boss = put('bdrone', { x: 96, z: -7.5, y: 9.5 }, Object.assign({ boss: true, yaw: -Math.PI / 2 }, BOSS[4])); if (boss) boss.sealed = true; // over the near side of the pit
  const bee = put('gdrone', { x: -108, z: -7.5, y: 9.5 }, { scale: 1.25, yaw: Math.PI / 2 }); if (bee) bee.sealed = true;
  // cameras: two in the last leg from the airlock, two along the jog, two up into the corridor, twelve along the corridor's ceiling corners
  const cams = [[-43.4, 18, Math.PI / 2], [-39.9, 14.2, -Math.PI / 2], [-35, 7.45, 0], [-28, 12.55, Math.PI], [-26.1, 4, Math.PI / 2], [-22.4, 0, -Math.PI / 2]];
  for (const [x, z, yaw] of cams) put('cctv', { x, z, y: 4.05 }, { yaw });
  for (let i = 0; i < 12; i++) { const x = -86 + i * 13.3, north = i % 2 === 0; put('cctv', { x, z: north ? -12.05 : -2.95, y: 5.55 }, { yaw: north ? 0 : Math.PI }); }
  // patrols: twelve walking beats along the corridor in two lanes (none on the bridge, where the bee is alone)
  for (let i = 0; i < 12; i++) {
    const z = i % 2 ? -5.2 : -9.8, x0 = -86 + i * 12.5, x1 = Math.min(64, x0 + rand(7, 10)), e = put('patrol', { x: x0 + rand(0.5, 2), z }, { yaw: Math.PI / 2 });
    if (e) { e.wp = [{ x: x0, z }, { x: x1, z }]; e.wi = 1; e.waitT = rand(0, 2); }
  }
  // 5.14: and eight in the main hall, sealed in with the boss: they walk their beats but notice nothing until its door opens.
  // 5.16: three round the walkway, three on the first landing, one on the second, one at the bottom of the pit by the reactor
  const P = PYR, mid = (st) => [st.ax - st.w / 2, st.az - st.w / 2], L1 = P.steps[P.per - 1], L2 = P.steps[2 * P.per - 1], [m1x, m1z] = mid(L1), [m2x] = mid(L2);
  for (const [x0, z0, x1, z1, y] of [[84, P.cz - P.oz - 1.5, 146, P.cz - P.oz - 1.5, 0], [84, P.cz + P.oz + 1.5, 146, P.cz + P.oz + 1.5, 0], [P.cx + P.ox + 1.5, -28, P.cx + P.ox + 1.5, 24, 0],
    [P.cx - 24, P.cz - m1z, P.cx + 24, P.cz - m1z, L1.y], [P.cx - 24, P.cz + m1z, P.cx + 24, P.cz + m1z, L1.y], [P.cx + m1x, P.cz - 22, P.cx + m1x, P.cz + 18, L1.y],
    [P.cx - m2x, P.cz - 16, P.cx - m2x, P.cz + 12, L2.y], [P.cx - 9, P.cz + P.bz - 1.3, P.cx + 9, P.cz + P.bz - 1.3, P.bottom]]) {
    const e = put('patrol', { x: x0, z: z0, y }, { yaw: Math.atan2(x1 - x0, z1 - z0) });
    if (e) { e.wp = [{ x: x0, z: z0 }, { x: x1, z: z1 }]; e.wi = 1; e.waitT = rand(0, 2); e.sealed = true; }
  }
  // little drones: two dozen along the corridor (none in the hall until the boss calls them up through the floor)
  for (let i = 0; i < 24; i++) put('droneA', { x: -86 + i * 6.3 + rand(-1.5, 1.5), z: rand(-11, -4), y: rand(3, 4.6) }, { yaw: rand(0, TAU) });
  // spider mines, buried: sixteen in the corridor, twenty in the hall, a few metres apart, off the reactor's dais and the hatches.
  // 5.16: in the hall only on flat floor (the walkway, a landing, the bottom of the pit), never on a flight of steps
  const mines = [];
  const flat = (x, z) => { const y = groundAt(x, 1, z, 0.05); for (const [dx, dz] of [[0.8, 0], [-0.8, 0], [0, 0.8], [0, -0.8]]) if (Math.abs(groundAt(x + dx, 1, z + dz, 0.05) - y) > 0.01) return null; return y; };
  const lay = (n, x0, x1, z0, z1) => {
    for (let i = 0, tries = 0; i < n && tries < 900; tries++) {
      const x = rand(x0, x1), z = rand(z0, z1), y = flat(x, z);
      if (y === null || collideAt(x, y + 0.05, z, 0.5, 0.6) || Math.hypot(x + 24.25, z + 2.5) < 6 || mines.some((m) => Math.hypot(m.x - x, m.z - z) < 3)) continue;
      if (Math.abs(x - REACTOR.x) < REACTOR.dais + 0.8 && Math.abs(z - REACTOR.z) < REACTOR.dais + 0.8) continue;
      if (HATCHES.some(([hx, hz]) => Math.hypot(hx - x, hz - z) < 2.2) || SHIP_DOORS.some((D) => Math.abs(D.x - x) < 4)) continue;
      const e = put('mine', { x, z, y: y - 0.16 }, { yaw: rand(0, TAU) }); if (e) { e.bs = 'hidden'; e.baseY = y; mines.push({ x, z }); i++; }
    }
  };
  lay(16, -88, 64, -11.6, -3.4);
  lay(20, HALL[0] + 1.5, HALL[2] - 1.5, HALL[1] + 1.5, HALL[3] - 1.5);
}
/* ============ stage 3-1: the safari. five minutes of the animals living wild, then every one of them comes for the watchtower ============ */
// (the stampede comes at five minutes.) before the stampede an animal only turns on you if you come close, shoot near it or hit it; then it fights like the lab's (07g).
// the zebras never fight and never run: at the stampede they come to the tower too and just stand about.
const SAFARI_T = 300; // five minutes
const SAFARI_ROSTER = [['zebra', 12], ['buffalo', 13], ['hippo', 12], ['rhino', 12], ['cheetah', 12], ['tiger', 12], ['lionM', 14], ['giraffe', 3], ['elephant', 4], ['gorilla', 6]];
/* the safari's lowland gorillas: the lab's gorilla build and fists (punch 62, charge 37 and a 1 s stun, half like every other animal here) */
const SAFARI_GORILLA = { kong: true, hp: 1000, scale: 1.15, dmgMul: 0.5, name: '로랜드고릴라' };
const Safari = {
  active: false, t: 0, stampede: false, warned: 0,
  reset() { this.active = false; this.t = 0; this.stampede = false; this.warned = 0; },
  begin() { this.active = true; this.t = 0; this.stampede = false; this.warned = 0; },
  left() { return Math.max(0, SAFARI_T - this.t); },
  update(dt) {
    if (!this.active) return;
    Tower.update(dt);
    if (this.stampede || Game.ended) return;
    this.t += dt;
    const left = SAFARI_T - this.t;
    if (this.warned < 1 && left <= 60) { this.warned = 1; Sound.alarm(); HUD.banner('1분 뒤 습격', '감시탑 위로 올라가 준비하세요', 2.8); }
    if (this.warned < 2 && left <= 10) { this.warned = 2; Sound.alarm(); HUD.banner('10초 뒤 습격', '땅이 울리기 시작합니다', 2.2); player.shake = Math.max(player.shake, 0.15); }
    if (left <= 0) this.go();
  },
  /* the stampede: every animal still alive (and not tamed) is set off at once and heads for you, and the tower you stand on */
  go() {
    if (this.stampede) return;
    this.stampede = true; this.t = SAFARI_T;
    let roars = 0;
    for (const e of Enemies.list) {
      if (!e.alive || !e.wild || e.tamed) continue;
      e.angry = true; e.alert = true; e.awake = true;
      if (!e.fury) { e.fury = true; e.state = 'chase'; Beast.wake(e); }
      if (e.type !== 'zebra' && roars < 8 && Math.random() < 0.25) { roars++; Sound.roar(e.pos, e.T.roar); }
    }
    Sound.quake(player.pos); Sound.siren(); player.shake = Math.max(player.shake, 0.45); buzz(220);
    HUD.banner('동물들이 몰려옵니다!', Tower.holds() ? '탑 위에 있으면 동물들은 탑부터 칩니다 · 기린은 목으로 탑 위까지 칩니다' : '감시탑으로 올라가세요!', 3.4);
    HUD.feed('습격 시작 · 모든 동물이 감시탑으로', 0, 'hs');
  },
};

/* the animals spread over the plain as they always are for this stage: herds of zebra, buffalo and giraffe, hippos round the waterhole,
   the big cats and the elephants further out */
function populateSafari(game, put, find, rand, randi) {
  const W = game.info.water;
  for (const [t, total] of SAFARI_ROSTER) {
    let c = total;
    for (let guard = 0; c > 0 && guard < 400; guard++) {
      if (t === 'zebra' || t === 'buffalo' || t === 'giraffe') {
        const center = find(70, 10, 2); if (!center) break;
        if (put(t, center)) c--;
        for (let i = 1, herd = t === 'giraffe' ? 3 : randi(3, 5); i < herd && c > 0; i++) { if (put(t, find(60, 2.6, 1.3, center, 8))) c--; }
      } else if (t === 'gorilla') {
        // two troops of three
        const center = find(85, 12, 2); if (!center) break;
        if (put(t, center, SAFARI_GORILLA)) c--;
        for (let i = 1; i < 3 && c > 0; i++) { if (put(t, find(80, 3, 1.3, center, 7), SAFARI_GORILLA)) c--; }
      } else if (t === 'hippo') {
        const a = rand(0, TAU);
        if (put(t, find(60, 3, 1.5, { x: W.x + Math.cos(a) * (W.r + 2.5), z: W.z + Math.sin(a) * (W.r + 2.5) }, 4) || find(70, 6, 2))) c--;
      } else if (put(t, find(t === 'elephant' ? 90 : 80, t === 'elephant' ? 14 : 8, t === 'elephant' ? 2.4 : 1.4))) c--;
    }
  }
  for (const e of Enemies.list) {
    e.wild = true;
    if (e.type === 'zebra') { e.fury = true; Beast.wake(e); e.bs = 'graze'; e.bt = rand(0.5, 4); } // zebras just live their quiet life (zebraAI), and never bolt here
  }
}

/* ---------- at the tower: what each kind does to it, and how often ---------- */
// rams back off and run at it (buffalo, rhino, elephant); the rest bite and claw at the planks. about 4 a second each (an elephant 8),
// and only one animal per place along its foot (16 places): with every place taken and nobody shooting it lasts about two and a half minutes
const SIEGE = { buffalo: { dmg: 20, cd: [1.6, 2.2], ram: true }, rhino: { dmg: 24, cd: [1.8, 2.4], ram: true }, elephant: { dmg: 52, cd: [2.2, 2.8], ram: true },
  hippo: { dmg: 14, cd: [1.6, 2.2] }, lionM: { dmg: 10, cd: [1.2, 1.6] }, tiger: { dmg: 10, cd: [1.1, 1.5] }, cheetah: { dmg: 8, cd: [1.0, 1.3] },
  gorilla: { dmg: 9, cd: [1.4, 2.0] } }; // gorillas: two or three haymakers into the planks, then a breather
const _sh = new THREE.Vector3();
function siegeAI(e, dt, dist) {
  const T = e.T, S = SIEGE[e.type] || { dmg: 5, cd: [1.4, 2] }, B = e.buff || 1, nose = noseOf(e);
  e.bt -= dt * B; e.sgCd = (e.sgCd === undefined ? rand(0.2, 1) : e.sgCd) - dt * B; e.claimT = (e.claimT || 0) - dt;
  // a place at the tower: kept while it is ours, looked for again every half second while waiting
  let slot = e.slot && e.slot.owner === e ? Tower.claim(e) : null;
  if (!slot && e.claimT <= 0) { e.claimT = rand(0.4, 0.7); slot = Tower.claim(e); }
  let sp = 0, mx = 0, mz = 0, pitch = 0, open = 0, face = null, turn = T.turn * 1.5;
  if (!slot) {
    // all taken: wait a little way off, on its own side of the tower, pacing and roaring
    if (e.bs !== 'swait') { e.bs = 'swait'; const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.4, 0.4), r = rand(9.5, 13); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; e.bt = rand(2, 5); }
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l > 1.2) { if (l > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { mx = _fd.x; mz = _fd.z; } else { mx = wx / l; mz = wz / l; } sp = l > 16 ? T.run * 0.6 : T.speed * 1.2; }
    else { face = Math.atan2(Tower.x - e.pos.x, Tower.z - e.pos.z); if (e.bt <= 0) { e.bt = rand(3, 6); const a = Math.atan2(e.pos.z - Tower.z, e.pos.x - Tower.x) + rand(-0.5, 0.5), r = rand(9.5, 13); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; if (Math.random() < 0.35) Sound.roar(e.pos, T.roar); } }
  } else {
    // its place: stand with the nose to the planks; rams start further back
    const gx = slot.x + slot.nx * (nose + 0.15), gz = slot.z + slot.nz * (nose + 0.15);
    const vx = gx - e.pos.x, vz = gz - e.pos.z, d = Math.hypot(vx, vz) || 0.001, inFace = Math.atan2(-slot.nx, -slot.nz);
    const strike = (big) => {
      _sh.set(slot.x, Math.min(e.H * 0.6, 2.0), slot.z); Tower.hurt(S.dmg, e, _sh);
      if (big) { Sound.thud(_sh); FX.puff({ x: slot.x, y: 0.4, z: slot.z }, 3, 0.55, 0.9); }
    };
    if (e.bs === 'sback') {
      // backing off straight out from the wall for another run at it, still facing it
      mx = slot.nx; mz = slot.nz; sp = T.speed * 1.4; face = inFace;
      if (e.bt <= 0) { e.bs = 'sram'; e.bt = 2; if (Math.random() < 0.5) Sound.roar(e.pos, T.roar); }
    } else if (e.bs === 'sram') {
      mx = -slot.nx; mz = -slot.nz; sp = T.run * 0.7; pitch = 0.16; turn = 12; face = inFace;
      if (Math.random() < dt * 10) FX.puff({ x: e.pos.x + slot.nx, y: 0.2, z: e.pos.z + slot.nz }, 1, 0.55, 0.35);
      const gap = (e.pos.x - slot.x) * slot.nx + (e.pos.z - slot.z) * slot.nz - nose; // how far its nose is from the planks
      if (gap < 0.35) { strike(true); e.bs = 'sgo'; e.sgCd = rand(S.cd[0], S.cd[1]); }
      else if (e.bt <= 0) e.bs = 'sgo';
    } else if (e.bs === 'sbite') {
      const u = 1 - clamp(e.bt / 0.45, 0, 1); open = u < 0.6 ? u / 0.6 : 1 - (u - 0.6) / 0.4; pitch = 0.1 * open; face = inFace;
      if (!e.hitDone && u >= 0.6) { e.hitDone = true; strike(false); Sound.thud(e.pos); }
      if (e.bt <= 0) e.bs = 'sgo';
    } else {
      if (e.bs !== 'sgo') { e.bs = 'sgo'; e.hitDone = false; }
      if (d > 0.7) {
        // on its way: along the walking grid while far off, then straight to its place
        if (d > 16 && flowDir(e.pos.x, e.pos.z, _fd)) { mx = _fd.x; mz = _fd.z; } else { mx = vx / d; mz = vz / d; }
        sp = d > 30 ? T.run * 0.6 : d > 4 ? T.run * 0.45 : T.speed * 1.2;
      } else {
        face = inFace;
        if (e.sgCd <= 0) {
          if (S.ram) { e.bs = 'sback'; e.bt = rand(0.7, 1.0); } else { e.bs = 'sbite'; e.bt = 0.45; e.hitDone = false; if (Math.random() < 0.4) Sound.roar(e.pos, T.roar); }
        }
      }
    }
  }
  beastMove(e, mx, mz, sp, dt);
  if (sp > 0 && (e.bs === 'sgo' || e.bs === 'swait')) unstick(e, e.bx0, e.bz0, mx, mz, sp, dt);
  turnToward(e, face !== null ? face : Math.atan2(mx, mz), turn, dt);
  animalGait(e, sp, dt);
  if (e.jaw) e.jaw.rotation.x = 0.7 * open;
  if (e.head && e.type === 'rhino') e.head.rotation.x = lerp(e.head.rotation.x, e.bs === 'sram' ? 0.4 : 0, 1 - Math.exp(-dt * 10));
  e.body.rotation.x = lerp(e.body.rotation.x, pitch, 1 - Math.exp(-dt * 8));
}

/* the safari's zebras once the stampede starts: they come to the tower with the rest, and just stand about it */
function zebraMill(e, dt) {
  const T = e.T; e.bt -= dt;
  const pickSpot = () => { const a = rand(0, TAU), r = rand(8.5, 14); e.wx = Tower.x + Math.cos(a) * r; e.wz = Tower.z + Math.sin(a) * r; };
  if (e.bs !== 'mwalk' && e.bs !== 'mgraze') { e.bs = 'mwalk'; e.bt = 40; pickSpot(); }
  let sp = 0, dx = 0, dz = 0;
  if (e.bs === 'mwalk') {
    const wx = e.wx - e.pos.x, wz = e.wz - e.pos.z, l = Math.hypot(wx, wz);
    if (l < 1.5 || e.bt <= 0) { e.bs = 'mgraze'; e.bt = rand(2, 6); }
    else {
      if (l > 20 && flowDir(e.pos.x, e.pos.z, _fd) && Tower.standing) { dx = _fd.x; dz = _fd.z; } else { dx = wx / l; dz = wz / l; }
      sp = T.speed * (l > 25 ? 2.4 : 1);
    }
  } else if (e.bt <= 0) { e.bs = 'mwalk'; e.bt = 25; pickSpot(); }
  beastMove(e, dx, dz, sp, dt);
  if (e.bs === 'mwalk') unstick(e, e.bx0, e.bz0, dx, dz, sp, dt);
  if (sp > 0.1) turnToward(e, Math.atan2(dx, dz), T.turn, dt);
  animalGait(e, sp, dt);
  e.body.rotation.x = lerp(e.body.rotation.x, e.bs === 'mgraze' ? 0.1 : 0, 1 - Math.exp(-dt * 4));
}

/* ============ player, input, HUD ============ */
let state = 'menu', time = 0;
const stats = { shots: 0, hits: 0, kills: 0, heads: 0, earned: 0, time: 0 };
const player = {
  pos: new THREE.Vector3(0, 0, 4), vel: new THREE.Vector3(), yaw: 0, pitch: 0, height: 1.7, eye: 1.62, r: 0.36,
  hp: 1000, maxHp: 1000, stunT: 0, grounded: true, speedXZ: 0, sprinting: false, sprintBlend: 0, sprintLock: 0, stepPhase: 0, stepDist: 0,
  recoilPitch: 0, shake: 0, landDip: 0, jumpBuf: 0, invuln: 0, sinceHurt: 0,
  /* zone: 'head' (shots to the head, overhead blows), 'body' (everything else that hits you), 'fire' (flames) */
  hurt(dmg, from, zone) {
    if (godMode()) return; // developer mode's invincibility
    if (state !== 'playing' || this.invuln > 0) return;
    // the zombie village has no health at all: only bites (infection) and dashes (poison) can finish you, and only on a timer
    if (Game.stage === 2) { this.shake = Math.max(this.shake, 0.2); Sound.hurt(); HUD.hurt(20, from); return; }
    // a motorcycle helmet takes one blow to the head for you, then it is gone
    if (zone === 'head' && save.items.helmet) { // (a fall or a wound bleeding has no zone the helmet or vest can stop)
      save.items.helmet = 0; persist(); HUD.items(); this.shake = Math.max(this.shake, 0.3); HUD.hurt(8, from); Sound.ping(camera.position); buzz(60);
      HUD.feed('오토바이 헬멧이 머리 공격을 막았습니다 · 헬멧이 부서졌습니다', 0, 'hs'); return;
    }
    // a vest takes half of a hit to the body, ten times
    if (zone === 'body' && save.items.vest > 0) {
      dmg *= 0.5; save.items.vest--; persist(); HUD.items(); Sound.metal(camera.position);
      if (!save.items.vest) HUD.feed('방탄조끼가 다 닳았습니다', 0, 'hs');
    }
    dmg = Math.max(1, Math.round(dmg));
    this.hp -= dmg; this.sinceHurt = 0; this.shake = Math.max(this.shake, 0.1 + dmg * 0.008);
    Sound.hurt(); HUD.hurt(dmg, from); buzz(Math.min(90, 25 + dmg * 2));
    if (this.hp <= 0) { this.hp = 0; Game.over('dead'); }
  },
};

/* ---------- input ---------- */
const keys = new Set();
let mdx = 0, mdy = 0, locked = false, everLocked = false, lockedAt = 0;
let lookMode = isTouch ? 'touch' : 'lock';
const canvas = renderer.domElement;
const joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 }, look = { id: null, x: 0, y: 0 };

function requestLock() {
  if (lookMode !== 'lock') return;
  try { const r = canvas.requestPointerLock(); if (r && r.catch) r.catch(onLockFail); } catch (e) { onLockFail(); }
  if (!everLocked) setTimeout(() => { if (!everLocked && !locked && state === 'playing' && lookMode === 'lock') onLockFail(); }, 1400);
}
function onLockFail() {
  if (lookMode !== 'lock') return;
  if (!everLocked) {
    lookMode = 'drag';
    HUD.hint('마우스 잠금이 막혀 있어 마우스 이동으로 조준합니다 · Q/E로 회전', 5);
  } else if (state === 'playing' && !locked) {
    pauseGame('마우스 잠금을 다시 켜지 못했습니다. 잠시 후 계속하기를 눌러 주세요.');
  }
}
document.addEventListener('pointerlockchange', () => {
  locked = document.pointerLockElement === canvas;
  if (locked) { everLocked = true; lockedAt = performance.now(); }
  if (!locked && state === 'playing' && lookMode === 'lock') pauseGame();
});
document.addEventListener('pointerlockerror', onLockFail);
document.addEventListener('mousemove', (e) => {
  if (state !== 'playing') return;
  if (lookMode === 'lock' && !locked) return;
  if (lookMode === 'touch') return;
  // browsers sometimes report one huge jump right after the pointer locks; drop it
  const mx = e.movementX || 0, my = e.movementY || 0;
  if (performance.now() - lockedAt < 150 || Math.abs(mx) > 450 || Math.abs(my) > 450) return;
  mdx += mx; mdy += my;
});
canvas.addEventListener('mousedown', (e) => {
  if (state === 'cutscene') { Cut.skip(); return; }
  if (state !== 'playing' || lookMode === 'touch') return;
  if (lookMode === 'lock' && !locked) { requestLock(); return; }
  if (e.button === 0) { Gun.trigger = true; Gun.triggerEdge = true; }
  if (e.button === 2) Gun.adsHeld = true;
  if (e.button === 3) { e.preventDefault(); Melee.start(); } // the mouse's back side button (XButton1): melee
});
window.addEventListener('mouseup', (e) => { if (e.button === 0) Gun.trigger = false; if (e.button === 2) Gun.adsHeld = false; if ((e.button === 3 || e.button === 4) && state === 'playing') e.preventDefault(); }); // no page back/forward mid-fight
window.addEventListener('auxclick', (e) => { if ((e.button === 3 || e.button === 4) && state === 'playing') e.preventDefault(); });
window.addEventListener('contextmenu', (e) => { if (state === 'playing' || e.target === canvas) e.preventDefault(); });
window.addEventListener('wheel', (e) => {
  if (state !== 'playing') return;
  cycleWeapon(e.deltaY > 0 ? 1 : -1);
}, { passive: true });
window.addEventListener('keydown', (e) => {
  if (e.code === 'F3') { e.preventDefault(); settings.fps = !settings.fps; Perf.show(settings.fps); syncSettingsUI(); store('yard07.settings', settings); return; }
  if (state === 'cutscene') { if (['Space', 'Escape', 'Enter', 'KeyE'].includes(e.code)) { e.preventDefault(); Cut.skip(); } return; }
  if (state === 'playing') {
    if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.code)) e.preventDefault();
    if (e.repeat) return;
    keys.add(e.code);
    if (e.code === 'Space' && !e.repeat) { player.jumpBuf = 0.15; jetTap(e.timeStamp); }
    if (e.code === 'ControlLeft' || e.code === 'ControlRight') e.preventDefault();
    if (e.code === 'KeyR') startReload();
    if (e.code === 'KeyV') Melee.start();
    const dg = /^Digit([1-7])$/.exec(e.code); if (dg) switchWeapon(+dg[1] - 1);
    if (e.code === 'KeyF') Game.useAntidote();
    if (e.code === 'KeyE' && lookMode !== 'drag' && !Ship.takeKey()) Ride.toggle();
    if (e.code === 'KeyG') Ride.toggle();
    if (e.code === 'KeyX' && Ride.m) Ride.off(false);
    if (e.code === 'KeyM') { openMap('play'); return; }
    if ((e.code === 'Escape' || e.code === 'KeyP') && (lookMode !== 'lock' || !locked)) pauseGame();
    else if (e.code === 'KeyP' && locked) document.exitPointerLock && document.exitPointerLock();
  } else if (!$('codex').hidden && e.code === 'Escape') { Codex.close(); }
  else if (!$('custom').hidden && e.code === 'Escape') { Custom.close(); }
  else if (state === 'paused' && !$('mapscreen').hidden && (e.code === 'KeyM' || e.code === 'Escape')) { closeMap(); }
  else if (state === 'paused' && !$('pause').hidden && e.code === 'KeyM') { openMap('pause'); }
  else if (state === 'brief' && e.code === 'Escape') { $('briefback').click(); }
  else if (state === 'paused' && (e.code === 'Escape' || e.code === 'KeyP') && lookMode !== 'lock') { resumeGame(); }
});
window.addEventListener('keyup', (e) => keys.delete(e.code));
window.addEventListener('blur', () => { keys.clear(); Gun.trigger = false; Gun.adsHeld = false; });
document.addEventListener('visibilitychange', () => { if (document.hidden) { if (state === 'playing') pauseGame(); Sound.suspend(); } else Sound.wake(); });
window.addEventListener('focus', () => Sound.wake());
['pointerdown', 'touchstart', 'keydown'].forEach((ev) => window.addEventListener(ev, () => Sound.wake(), { passive: true, capture: true }));

/* touch */
function tbtn(id, down, up) {
  const el = $(id);
  el.addEventListener('touchstart', (e) => { e.preventDefault(); e.stopPropagation(); if (state !== 'playing' && id !== 't-pause') return; el.classList.add('on'); down(e); }, { passive: false });
  el.addEventListener('touchend', (e) => { e.preventDefault(); e.stopPropagation(); el.classList.remove('on'); if (up) up(e); }, { passive: false });
  el.addEventListener('touchcancel', () => { el.classList.remove('on'); if (up) up(); });
}
if (isTouch) {
  document.body.classList.add('touch');
  tbtn('t-fire', (e) => { Gun.trigger = true; Gun.triggerEdge = true; const t = e.changedTouches[0]; look.id = t.identifier; look.x = t.clientX; look.y = t.clientY; }, () => { Gun.trigger = false; });
  tbtn('t-ads', () => { Gun.adsHeld = !Gun.adsHeld; $('t-ads').classList.toggle('on', Gun.adsHeld); }, () => $('t-ads').classList.toggle('on', Gun.adsHeld));
  tbtn('t-jump', (e) => { player.jumpBuf = 0.15; jetTap(e.timeStamp); Jet.upT = true; }, () => { Jet.upT = false; });
  tbtn('t-down', () => { Jet.downT = true; }, () => { Jet.downT = false; });
  tbtn('t-reload', () => startReload());
  tbtn('t-melee', () => Melee.start());
  tbtn('t-swap', () => cycleWeapon(1));
  tbtn('t-anti', () => Game.useAntidote());
  tbtn('t-car', () => (Ship.takeKey() ? 0 : Lab.active ? Ride.toggle() : Car.toggle()));
  tbtn('t-off', () => Ride.off(false));
  tbtn('t-map', () => openMap('play'));
  tbtn('t-pause', () => { if (state === 'playing') pauseGame(); });
  /* the D-pad at the left middle of the screen: four arrows, slide the thumb between two for a diagonal,
     tap ▲ twice and keep holding it to sprint. it steers by where the thumb is relative to its centre, even past its edge */
  const pad = $('t-dpad'), dp = { sprint: false, lastUp: -9, cls: '' };
  const onPad = (t) => { const r = pad.getBoundingClientRect(), m = 12; return t.clientX > r.left - m && t.clientX < r.right + m && t.clientY > r.top - m && t.clientY < r.bottom + m; };
  function padSteer(t) {
    const r = pad.getBoundingClientRect(), dx = t.clientX - (r.left + r.width / 2), dy = t.clientY - (r.top + r.height / 2);
    let x = 0, y = 0;
    if (Math.hypot(dx, dy) > r.width * 0.12) {
      // cardinals get 60 degrees each, diagonals the 30 between them, so a straight push stays straight
      const a = Math.atan2(dy, dx), q = Math.round(a / (Math.PI / 2)), off = Math.abs(a - q * Math.PI / 2);
      if (off < Math.PI / 6) { x = Math.round(Math.cos(q * Math.PI / 2)); y = Math.round(Math.sin(q * Math.PI / 2)); }
      else { x = Math.sign(dx); y = Math.sign(dy); }
    }
    joy.x = x; joy.y = y;
    const cls = (y < 0 ? ' u' : '') + (y > 0 ? ' d' : '') + (x < 0 ? ' l' : '') + (x > 0 ? ' r' : '');
    if (cls !== dp.cls) { dp.cls = cls; pad.className = cls.trim() + (dp.sprint ? ' run' : ''); }
  }
  function padRelease() {
    if (joy.y < 0 && joy.x === 0) dp.lastUp = performance.now();
    joy.id = null; joy.x = joy.y = 0; dp.sprint = false; dp.cls = ''; pad.className = '';
  }
  joy.pad = dp;
  window.addEventListener('touchstart', (e) => {
    if (state === 'cutscene') { Cut.skip(); e.preventDefault(); return; }
    if (state !== 'playing') return;
    for (const t of e.changedTouches) {
      if (joy.id === null && onPad(t)) {
        joy.id = t.identifier; padSteer(t);
        // a second tap on ▲ right after the first one, held down: run
        dp.sprint = joy.y < 0 && joy.x === 0 && performance.now() - dp.lastUp < 320; pad.classList.toggle('run', dp.sprint);
      } else if (look.id === null) { look.id = t.identifier; look.x = t.clientX; look.y = t.clientY; }
    }
    e.preventDefault();
  }, { passive: false });
  window.addEventListener('touchmove', (e) => {
    if (state !== 'playing') return;
    for (const t of e.changedTouches) {
      if (t.identifier === joy.id) padSteer(t);
      else if (t.identifier === look.id) {
        mdx += (t.clientX - look.x) * 1.7; mdy += (t.clientY - look.y) * 1.7; look.x = t.clientX; look.y = t.clientY;
      }
    }
    e.preventDefault();
  }, { passive: false });
  const endTouch = (e) => {
    for (const t of e.changedTouches) {
      if (t.identifier === joy.id) padRelease();
      if (t.identifier === look.id) look.id = null;
    }
  };
  window.addEventListener('touchend', endTouch); window.addEventListener('touchcancel', endTouch);
}

/* ---------- jetpack: double-tap jump to lift off; jump goes up, Ctrl (or C) goes down; 10 seconds, one use ---------- */
const Jet = { on: false, t: 0, lastTap: -9, upT: false, downT: false, puffT: 0 };
function jetTap(ts) {
  // timed by when the presses happened, not when a busy frame got round to them
  const now = (ts || performance.now()) / 1000, dbl = now - Jet.lastTap < 0.35; Jet.lastTap = now;
  if (!dbl || Jet.on || state !== 'playing' || !save.items.jet || player.stunT > 0 || Car.riding || Ride.m || Toss.on) return;
  Jet.on = true; Jet.t = 10; save.items.jet = 0; persist(); HUD.items();
  player.vel.y = Math.max(player.vel.y, 3); player.grounded = false; Jet.lastTap = -9;
  if (isTouch) $('t-down').hidden = false;
  HUD.hint(isTouch ? '제트백팩 · 점프 버튼 위로 · 내려가기 버튼 아래로' : '제트백팩 · Space 위로 · Ctrl 또는 C 아래로', 2.4); Sound.jet(0.8);
}
function jetEnd(msg) {
  if (!Jet.on) return;
  Jet.on = false; Jet.upT = Jet.downT = false; Sound.jet(0); if (isTouch) $('t-down').hidden = true;
  if (msg) HUD.feed(msg, 0);
}
/* how high you may fly: under the lab's ceiling and the ship's roof, and not into the clouds anywhere else */
function jetTop() { return World.style.lab ? LAB_CEIL - 2.4 : World.style.indoor ? 26 : 30; }
/* ---------- player movement ---------- */
function updatePlayer(dt) {
  const W = WEAPONS[Gun.cur];
  // knocked out: legs gone, hands slack, the view swims
  if (player.stunT > 0) { player.stunT = Math.max(0, player.stunT - dt); if (player.stunT === 0) HUD.feed('정신이 들었습니다', 0); }
  const stunned = player.stunT > 0;
  const sens = settings.sens * 0.0021 * (Gun.ads > 0.5 ? (W.scope ? camera.fov / baseFov : 0.62) : 1) * (stunned ? 0.12 : 1);
  let turn = 0;
  if (keys.has('ArrowLeft') || (lookMode === 'drag' && keys.has('KeyQ'))) turn += 1;
  if (keys.has('ArrowRight') || (lookMode === 'drag' && keys.has('KeyE'))) turn -= 1;
  player.yaw += turn * 2.4 * dt - mdx * sens;
  player.pitch -= mdy * sens;
  if (keys.has('ArrowUp')) player.pitch += 1.6 * dt; if (keys.has('ArrowDown')) player.pitch -= 1.6 * dt;
  player.pitch = clamp(player.pitch, -1.5, 1.5);
  player.recoilPitch *= Math.exp(-dt * 9);
  let f = (keys.has('KeyW') ? 1 : 0) - (keys.has('KeyS') ? 1 : 0) - joy.y;
  let s = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0) + joy.x;
  if (stunned) { f = 0; s = 0; player.jumpBuf = 0; }
  const m = Math.hypot(f, s); if (m > 1) { f /= m; s /= m; }
  const touchSprint = lookMode === 'touch' && !!(joy.pad && joy.pad.sprint), runKey = keys.has('ShiftLeft') || keys.has('ShiftRight') || touchSprint;
  if (Fear.t > 0) Fear.t = Math.max(0, Fear.t - dt);
  if (Ride.m && Ride.update(dt, f, s, runKey, stunned)) {
    // on an animal's back: it carries you where you steer it; you look and shoot freely
    player.vel.set(0, 0, 0); player.grounded = true; player.speedXZ = Math.hypot(Ride.vx, Ride.vz) * 0.35; player.sprinting = false; player.jumpBuf = 0;
    player.sprintBlend = lerp(player.sprintBlend, 0, 1 - Math.exp(-dt * 8)); player.landDip *= Math.exp(-dt * 8);
    player.invuln = Math.max(0, player.invuln - dt); player.sinceHurt += dt;
    const rs = player.shake; player.shake *= Math.exp(-dt * 7);
    Ride.cam(camera.position, dt);
    const sw = stunned ? clamp(player.stunT, 0, 1) : 0;
    camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * rs * 0.05 - 0.12 * sw, player.yaw + rand(-1, 1) * rs * 0.05, Math.sin(time * 3.1) * 0.09 * sw);
    return;
  }
  if (Car.riding) {
    // in the passenger seat: no walking, the seat carries you; aim stays steady in world space
    Car.seat(player.pos); player.vel.copy(Car.vel); player.grounded = true; player.speedXZ = 0; player.sprinting = false;
    player.sprintBlend = lerp(player.sprintBlend, 0, 1 - Math.exp(-dt * 8)); player.landDip *= Math.exp(-dt * 8);
    player.invuln = Math.max(0, player.invuln - dt); player.sinceHurt += dt;
    const rs = player.shake; player.shake *= Math.exp(-dt * 7);
    camera.position.set(player.pos.x, player.pos.y + player.eye, player.pos.z);
    camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * rs * 0.05, player.yaw + rand(-1, 1) * rs * 0.05, 0);
    return;
  }

  // thrown by a rhino: straight up and straight down, no steering, no jumping
  if (Toss.on) { f = 0; s = 0; player.jumpBuf = 0; }
  player.sprintLock = Math.max(0, player.sprintLock - dt);
  player.sprinting = runKey && f > 0.3 && !Gun.adsHeld && !Gun.trigger && player.sprintLock <= 0 && Gun.reloadT <= 0;
  let speed = (player.sprinting ? 8.2 : 5.4) * W.moveMul; if (Gun.ads > 0.5) speed *= W.scope ? 0.4 : 0.6;
  const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
  let tx = (-sy * f + cy * s) * speed, tz = (-cy * f - sy * s) * speed;
  // a tiger's roar: your legs carry you away from it for a second, whatever you press
  if (Fear.t > 0 && !stunned && !Toss.on) { tx = Fear.x * 8.2; tz = Fear.z * 8.2; player.jumpBuf = 0; }
  const acc = 1 - Math.exp(-dt * (player.grounded || Fear.t > 0 ? 11 : 2.2));
  player.vel.x += (tx - player.vel.x) * acc; player.vel.z += (tz - player.vel.z) * acc;
  if (Toss.on) { player.vel.x = 0; player.vel.z = 0; }
  player.jumpBuf -= dt;
  const p = player.pos;
  if (Jet.on) {
    // flying: no gravity; hold jump to rise, Ctrl or C to sink, nothing to hover. it sputters out after 10 seconds
    Jet.t -= dt;
    const up = keys.has('Space') || Jet.upT, down = keys.has('ControlLeft') || keys.has('ControlRight') || keys.has('KeyC') || Jet.downT;
    const want = stunned ? 0 : up && !down ? 5 : down && !up ? -5 : 0;
    player.vel.y += (want - player.vel.y) * (1 - Math.exp(-dt * 6)); player.jumpBuf = 0;
    if (p.y > jetTop() && player.vel.y > 0) player.vel.y = 0;
    Sound.jet(0.45 + (up ? 0.4 : 0));
    Jet.puffT -= dt; if (Jet.puffT <= 0) { Jet.puffT = 0.05; FX.puff({ x: p.x - Math.sin(player.yaw) * -0.35, y: p.y + 0.6, z: p.z - Math.cos(player.yaw) * -0.35 }, 1, 0.35, 0.35);
      FX.glow.emit({ x: p.x + Math.sin(player.yaw) * 0.3, y: p.y + 0.7, z: p.z + Math.cos(player.yaw) * 0.3, vx: 0, vy: -4, vz: 0, max: 0.25, s0: 0.25, s1: 0.05, r: 1, g: 0.6, b: 0.25, a: 0.8, grav: 0, drag: 1 }); }
    if (Jet.t <= 0) jetEnd('제트백팩 연료가 다 떨어졌습니다');
  } else {
    if (player.jumpBuf > 0 && player.grounded) { player.vel.y = 6.6; player.grounded = false; player.jumpBuf = 0; }
    player.vel.y -= 19 * dt;
  }
  moveXZ(p, player.vel.x * dt, player.vel.z * dt, player.r, player.height, player.grounded ? 0.5 : 0.2);
  p.x = clamp(p.x, -HALF + player.r, HALF - player.r); p.z = clamp(p.z, -HALF + player.r, HALF - player.r);
  const gy = groundAt(p.x, p.y, p.z, player.r);
  p.y += player.vel.y * dt;
  if (player.vel.y > 0) { const c = ceilAt(p.x, p.y - player.vel.y * dt, p.z, player.r, player.height); if (p.y + player.height > c) { p.y = c - player.height; player.vel.y = 0; } }
  if (Toss.on && World.style.lab && p.y + player.height > LAB_CEIL - 0.15) { p.y = LAB_CEIL - 0.15 - player.height; if (player.vel.y > 0) { player.vel.y = 0; Sound.thud(p); } } // the lab's ceiling
  if (p.y <= gy) {
    if (Toss.on && player.vel.y <= 0) { p.y = gy; Toss.land(); }
    if (!player.grounded && player.vel.y < -5) { player.landDip = clamp(-player.vel.y * 0.012, 0, 0.12); Sound.land(); }
    // sinking onto the ground ends the flight (not in the first moment after lift-off)
    if (Jet.on && Jet.t < 9.6 && player.vel.y <= 0.05) jetEnd('제트백팩 착지');
    p.y = gy; player.vel.y = 0; player.grounded = true;
  } else if (p.y > gy + 0.05) player.grounded = false;
  player.speedXZ = Math.hypot(player.vel.x, player.vel.z);
  if (player.grounded && player.speedXZ > 0.5) {
    player.stepPhase += player.speedXZ * dt * 1.7; player.stepDist += player.speedXZ * dt;
    if (player.stepDist > (player.sprinting ? 2.6 : 2.1)) { player.stepDist = 0; Sound.step(); }
  }
  player.sprintBlend = lerp(player.sprintBlend, player.sprinting ? 1 : 0, 1 - Math.exp(-dt * 8));
  player.landDip *= Math.exp(-dt * 8);
  player.invuln = Math.max(0, player.invuln - dt);
  player.sinceHurt += dt;
  const bob = player.grounded ? Math.abs(Math.sin(player.stepPhase)) * 0.045 * clamp(player.speedXZ / 6, 0, 1.3) * (1 - Gun.ads * 0.7) : 0;
  const sh = player.shake; player.shake *= Math.exp(-dt * 7);
  camera.position.set(p.x, p.y + player.eye - bob - player.landDip, p.z);
  const sw = stunned ? clamp(player.stunT, 0, 1) : 0;
  camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * sh * 0.05 + Math.sin(time * 2.3) * 0.07 * sw - 0.12 * sw,
    player.yaw + rand(-1, 1) * sh * 0.05 + Math.sin(time * 1.7) * 0.05 * sw, Math.sin(player.stepPhase * 0.5) * 0.004 * clamp(player.speedXZ / 6, 0, 1) + Math.sin(time * 3.1) * 0.09 * sw);
}


/* ---------- HUD ---------- */
const won = (n) => Math.round(n).toLocaleString('ko-KR') + '원';
/* 5.14: running with the SMG (12% faster on your feet) shows as green wind: streaks rushing out past the edges of your view and a faint
   green round the rim, stronger the faster you go. drawn on its own canvas in the game view; nothing is drawn while it is idle */
const Wind = (() => {
  let cv = null, g = null, k = 0, drawn = false, w = 0, h = 0;
  const P = []; for (let i = 0; i < 40; i++) P.push({ a: Math.random() * Math.PI * 2, r: 0.5 + Math.random() * 0.6, v: 0.7 + Math.random() * 0.6, l: 0.08 + Math.random() * 0.14, wd: 1.6 + Math.random() * 2.2 });
  function update(dt) {
    if (!cv) { cv = document.getElementById('windfx'); if (!cv) return; g = cv.getContext('2d'); }
    const sp = player.speedXZ || 0, want = state === 'playing' && Gun.cur === 'smg' && !Gun.none && sp > 0.8 ? Math.min(1, Math.max(0.3, (sp - 0.8) / 7)) : 0;
    k += (want - k) * (1 - Math.exp(-dt * 6));
    if (k < 0.012) { if (drawn) { g.clearRect(0, 0, w, h); drawn = false; } return; }
    const cw = Math.round(cv.clientWidth), ch = Math.round(cv.clientHeight);
    if (cw !== w || ch !== h) { w = cv.width = cw; h = cv.height = ch; }
    if (!w || !h) return;
    drawn = true; g.clearRect(0, 0, w, h);
    const cx = w / 2, cy = h / 2, R = Math.hypot(cx, cy);
    const rim = g.createRadialGradient(cx, cy, R * 0.5, cx, cy, R); rim.addColorStop(0, 'rgba(70,255,150,0)'); rim.addColorStop(1, 'rgba(70,255,150,' + (0.24 * k).toFixed(3) + ')');
    g.fillStyle = rim; g.fillRect(0, 0, w, h); g.lineCap = 'round';
    for (const p of P) {
      p.r += p.v * dt * (0.8 + k * 1.6);
      if (p.r > 1.15) { p.r = 0.46 + Math.random() * 0.22; p.a = Math.random() * Math.PI * 2; p.v = 0.7 + Math.random() * 0.6; p.l = 0.08 + Math.random() * 0.14; }
      const fade = Math.min(1, Math.max(0, (p.r - 0.44) / 0.18)) * Math.min(1, Math.max(0, (1.15 - p.r) / 0.25));
      if (fade <= 0) continue;
      const c = Math.cos(p.a), s = Math.sin(p.a), x0 = cx + c * p.r * R, y0 = cy + s * p.r * R, x1 = cx + c * (p.r + p.l) * R, y1 = cy + s * (p.r + p.l) * R;
      const lg = g.createLinearGradient(x0, y0, x1, y1); lg.addColorStop(0, 'rgba(140,255,180,0)'); lg.addColorStop(1, 'rgba(140,255,180,' + (0.85 * k * fade).toFixed(3) + ')');
      g.strokeStyle = lg; g.lineWidth = p.wd * (0.7 + k * 0.7); g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke();
    }
  }
  return { update };
})();
const HUD = (() => {
  const el = {};
  ['hpnum', 'hpfill', 'hpghost', 'mag', 'reserve', 'wname', 'stagenum', 'kills', 'killfill', 'money', 'moneypop', 'reload', 'reloadfill', 'hint', 'banner', 'bannerbig', 'bannersmall',
    'feed', 'hit', 'hurt', 'lowhp', 'toxic', 'stunfx', 'status', 'infect', 'infectT', 'infectMsg', 'anticount', 'dmgdir', 'ch-l', 'ch-r', 'ch-t', 'ch-b', 'slots', 't-anti', 't-car', 't-off', 'carbar', 'carfill', 'carlbl', 'bleedtag', 'bossbar', 'bossname', 'bossfill', 'tgtdir', 'cagebar', 'cagelbl', 'cagetxt', 'cagesec', 'itemrow', 'ch-ring', 'vbarT', 'vnumT', 'vfillT', 'vlblT', 'vbarM', 'vnumM', 'vfillM', 'vlblM', 'lockbox'].forEach((k) => (el[k] = $(k)));
  const cache = {}, crossEl = $('cross');
  const set = (k, v, prop) => { if (cache[k] !== v) { cache[k] = v; if (prop) el[k].style[prop] = v; else el[k].textContent = v; } };
  let hitT = 0, hurtT = 0, hintT = 0, bannerT = 0, heartT = 0, lockT = 0, lockE = null;
  const _lp = new THREE.Vector3();
  const arcs = [];
  for (let i = 0; i < 4; i++) { const a = document.createElement('div'); a.className = 'arc'; el.dmgdir.appendChild(a); arcs.push({ a, life: 0, from: null }); }
  let arcI = 0, slotEls = [];
  const tgts = [];
  for (let i = 0; i < 3; i++) { const t = document.createElement('div'); t.className = 'tgt'; el.tgtdir.appendChild(t); tgts.push(t); }
  return {
    hitmark(kill, head) { hitT = kill ? 0.35 : head ? 0.26 : 0.16; el.hit.style.setProperty('--hitc', kill ? '#ff5260' : head ? '#f2a33a' : '#ffffff'); el.hit.style.transform = kill ? (head ? 'scale(1.75)' : 'scale(1.35)') : head ? 'scale(1.3)' : 'scale(1)'; },
    hurt(dmg, from) {
      hurtT = Math.min(0.6, 0.2 + dmg * 0.012);
      if (from) { const A = arcs[arcI]; arcI = (arcI + 1) % arcs.length; A.life = 1.2; A.from = { x: from.x, z: from.z }; }
    },
    hint(t, dur) { el.hint.textContent = t; hintT = dur || 1.6; },
    banner(big, small, dur) { el.bannerbig.textContent = big; el.bannersmall.textContent = small; bannerT = dur || 2.5; },
    feed(text, money, cls) {
      const d = document.createElement('div'); if (cls) d.className = cls;
      d.textContent = text; if (money) { const b = document.createElement('b'); b.textContent = '+' + won(money); d.appendChild(b); }
      el.feed.prepend(d); while (el.feed.children.length > 4) el.feed.lastChild.remove();
      setTimeout(() => { d.style.opacity = 0; setTimeout(() => d.remove(), 450); }, 2400);
    },
    moneyPop(n) {
      const d = document.createElement('div'); d.className = 'mp'; d.textContent = '+' + won(n);
      el.moneypop.appendChild(d); setTimeout(() => d.remove(), 1250);
    },
    buildSlots() {
      el.slots.textContent = ''; slotEls = []; el.slots.classList.toggle('many', Gun.slots.length > 4);
      Gun.loadout.forEach((id, i) => {
        if (!id) return;
        const s = document.createElement('span'); const n = document.createElement('i'); n.textContent = (i + 1) + ' ';
        s.append(n, Gun.slots.length > 4 && portrait ? WEAPONS[id].tab : WEAPONS[id].short);
        s.addEventListener('touchstart', (e) => { e.preventDefault(); e.stopPropagation(); if (state === 'playing') switchWeapon(i); }, { passive: false });
        el.slots.appendChild(s); slotEls.push(s);
      });
      delete cache.slot;
    },
    /* what you carry: chips under your health */
    items() {
      const it = save.items, chips = [];
      if (it.helmet) chips.push(['헬멧', '']); if (it.vest) chips.push(['조끼 ' + it.vest + '/10', it.vest <= 3 ? 'low' : '']); if (it.jet) chips.push([isTouch ? '제트팩 · 점프 두 번' : '제트팩 · Space 두 번', 'jet']); if (it.ivory) chips.push(['상아 ' + it.ivory, '']);
      el.itemrow.textContent = ''; el.itemrow.hidden = !chips.length;
      for (const [t, c] of chips) { const s = document.createElement('span'); s.textContent = t; if (c) s.className = c; el.itemrow.appendChild(s); }
    },
    reset() { el.feed.textContent = ''; el.moneypop.textContent = ''; hitT = hurtT = hintT = bannerT = 0; arcs.forEach((A) => (A.life = 0)); for (const k in cache) delete cache[k]; },
    update(dt) {
      Wind.update(dt);
      const hp = Math.ceil(player.hp), pct = Math.round(100 * player.hp / (player.maxHp || 100));
      set('hpnum', String(hp)); set('hpfill', pct + '%', 'width'); set('hpghost', pct + '%', 'width');
      const hc = pct > 50 ? '#5ed6b0' : pct > 25 ? '#f2a33a' : '#ff5260';
      if (cache.hc !== hc) { cache.hc = hc; el.hpfill.style.backgroundColor = hc; }
      set('anticount', String(Game.antidotes));
      const w = WEAPONS[Gun.cur], st = wstate[Gun.cur];
      set('mag', String(st.mag)); set('reserve', '/ ' + (st.reserve === Infinity ? '∞' : st.reserve)); set('wname', w.model + ' ' + w.name + (w.heavy ? ' · 이동 -' + Math.round((1 - w.moveMul) * 100) + '%' : '') + (w.heat && st.hot ? ' · 과열' : ''));
      el.mag.classList.toggle('low', st.mag <= Math.ceil(w.mag * 0.25));
      const sel = Gun.pending || Gun.cur;
      if (cache.slot !== sel) { cache.slot = sel; slotEls.forEach((s, i) => s.classList.toggle('on', Gun.slots[i] === sel)); }
      set('stagenum', stageTag(Game.stage)); const done = Game.kills + (Game.calm || 0); set('kills', done + ' / ' + Game.goal); set('killfill', (100 * done / Game.goal) + '%', 'width');
      set('money', won(save.money));
      if (Gun.reloadT > 0) { el.reload.style.opacity = 1; el.reloadfill.style.width = (100 * (1 - Gun.reloadT / w.reload)) + '%'; } else el.reload.style.opacity = 0;
      if (st.mag === 0 && st.reserve > 0 && Gun.reloadT <= 0 && hintT <= 0) { el.hint.textContent = lookMode === 'touch' ? '장전 버튼을 누르세요' : 'R 키로 재장전'; el.hint.style.opacity = 1; }
      else if (hintT > 0) { hintT -= dt; el.hint.style.opacity = hintT > 0 ? 1 : 0; } else el.hint.style.opacity = 0;
      const spr = currentSpread(), fovR = THREE.MathUtils.degToRad(camera.fov) / 2;
      const gap = Math.round(Math.tan(spr) / Math.tan(fovR) * viewH / 2 + 4);
      set('ch-l', (-gap - 9) + 'px', 'left'); set('ch-r', gap + 'px', 'left'); set('ch-t', (-gap - 9) + 'px', 'top'); set('ch-b', gap + 'px', 'top');
      const co = String(w.scope && Gun.ads > 0.6 ? 0 : Math.round((1 - Gun.ads) * (1 - player.sprintBlend) * 100) / 100);
      if (cache.co !== co) { cache.co = co; ['ch-l', 'ch-r', 'ch-t', 'ch-b', 'ch-ring'].forEach((k) => (el[k].style.opacity = co)); }
      // the circles: the small one is the spread itself, the big one sits well outside it
      const ring = settings.cross === 'big' ? 2 * Math.max(gap + 24, 40) : 2 * Math.max(gap + 2, 9);
      if (cache.ring !== ring) { cache.ring = ring; el['ch-ring'].style.width = el['ch-ring'].style.height = ring + 'px'; }
      const adsDot = Gun.ads > 0.6 && !w.scope; if (cache.ads !== adsDot) { cache.ads = adsDot; crossEl.classList.toggle('ads', adsDot); }
      // the rocket launcher's lock: which enemy the next rocket would chase, marked where it stands on screen
      let lockOn = false;
      if (w.rocket && state === 'playing' && wstate[Gun.cur].mag > 0 && Gun.reloadT <= 0) {
        if ((lockT -= dt) <= 0) { lockT = 0.1; lockE = rocketLock(); }
        if (lockE && lockE.alive) { Proj.rocketCentre(lockE, _lp).project(camera);
          if (_lp.z < 1 && Math.abs(_lp.x) < 1.05 && Math.abs(_lp.y) < 1.05) { lockOn = true; el.lockbox.style.left = ((_lp.x + 1) * 50).toFixed(2) + '%'; el.lockbox.style.top = ((1 - _lp.y) * 50).toFixed(2) + '%'; } }
      } else lockE = null;
      if (el.lockbox.hidden === lockOn) el.lockbox.hidden = !lockOn;
      if (hitT > 0) { hitT -= dt; el.hit.style.opacity = clamp(hitT * 6, 0, 1); } else el.hit.style.opacity = 0;
      if (hurtT > 0) { hurtT -= dt; el.hurt.style.opacity = clamp(hurtT * 2.2, 0, 1); } else el.hurt.style.opacity = 0;
      el.lowhp.style.opacity = Game.stage !== 2 && pct < 35 ? (0.55 + Math.sin(time * 6) * 0.25) * (1 - pct / 35) + 0.2 : 0;
      // infection (a bite) and poison (a dash): both count down to the end unless an antidote goes in
      const inf = Game.infected, pois = Game.poisonT > 0, danger = inf || pois;
      if (el.infect.hidden === danger) el.infect.hidden = !danger;
      if (danger) {
        const T = inf && pois ? Math.min(Game.infectT, Game.poisonT) : inf ? Game.infectT : Game.poisonT, what = inf && pois ? '감염 + 중독' : inf ? '감염됨' : '중독됨';
        set('infectT', Math.max(0, T).toFixed(1));
        const msg = Game.antidotes > 0 ? what + (lookMode === 'touch' ? ' · 해독약 버튼을 누르세요' : ' · F 키로 해독약 사용') : what + ' · 해독약이 없습니다! 상자를 부수세요';
        set('infectMsg', msg);
        el.toxic.style.opacity = String(0.55 + Math.sin(time * 9) * 0.25 + Math.max(0, 5 - T) * 0.06);
        heartT -= dt; if (heartT <= 0) { heartT = 0.45 + T * 0.12; Sound.heart(); buzz(25); }
      } else { el.toxic.style.opacity = '0'; heartT = 0; }
      // stun and injection read-outs
      const stun = player.stunT > 0, inj = Inject.active;
      const stText = stun ? '기절 ' + player.stunT.toFixed(1) : Fear.t > 0 ? '공포 ' + Fear.t.toFixed(1) : Toss.on ? '공중으로 날아가는 중' : inj ? '해독약 주사 중' : Jet.on ? '제트백팩 ' + Math.max(0, Jet.t).toFixed(1) + '초' + (isTouch ? '' : ' · Space 위로 · Ctrl(C) 아래로') : '';
      // bleeding: how many wounds and how long they keep going
      const bl = Bleed.t > 0 ? Bleed.n + '|' + Math.ceil(Bleed.t) : '';
      if (cache.bl !== bl) { cache.bl = bl; el.bleedtag.hidden = !bl; if (bl) el.bleedtag.innerHTML = '<b>출혈 ×' + Bleed.n + '</b>' + Math.ceil(Bleed.t) + '초 · 초당 ' + BLEED_DPS * Bleed.n; }
      if (cache.st !== stText) { cache.st = stText; el.status.textContent = stText; el.status.hidden = !stText; el.status.classList.toggle('stun', stun); }
      el.stunfx.style.opacity = stun ? String(clamp(player.stunT, 0, 1) * (0.75 + Math.sin(time * 7) * 0.15)) : '0';
      const showAnti = isTouch && (inf || pois) && !inj;
      if (el['t-anti'].hidden === showAnti) el['t-anti'].hidden = !showAnti;
      if (showAnti) set('t-anti', Game.antidotes > 0 ? '해독약 사용 (' + Game.antidotes + ')' : '해독약 없음');
      // riding in the lab: the animal's health under yours, and what E (or the button) would do now
      const M = Ride.m;
      if ((Ride.findT -= dt) <= 0) { Ride.findT = 0.15; Ride.target = Ride.find(); }
      const tg = Ride.target && Ride.target.alive ? Ride.target : null;
      // the animal under you: a tall red bar on the right, its health in big numbers, and whether it is bleeding
      if (!el.carbar.hidden) el.carbar.hidden = true;
      if (el.vbarM.hidden === !!M) el.vbarM.hidden = !M;
      if (M) { const f = clamp(M.hp / M.maxHp, 0, 1); set('vnumM', Math.max(0, Math.ceil(M.hp)).toLocaleString('ko-KR')); set('vfillM', 'calc(' + (100 * f).toFixed(1) + '% - 6px)', 'height');
        set('vlblM', SEAT[M.type].name + (M.bleedT > 0 ? '\n출혈 ×' + M.bleedN : '')); const lowM = f < 0.25; if (cache.lowM !== lowM) { cache.lowM = lowM; el.vbarM.classList.toggle('low', lowM); } }
      const keyNear = Ship.active && Ship.keyNear(); // stage 4: the main hall's key in the bridge console
      const act = keyNear ? '메인홀 열쇠 줍기' : tg ? SEAT[tg.type].name + (M ? euroK(SEAT[tg.type].name) + ' 옮겨 타기' : ' 타기') : M ? '내리기' : '';
      const showRide = isTouch && !!act;
      if (el['t-car'].hidden === showRide) el['t-car'].hidden = !showRide;
      if (showRide) set('t-car', act);
      const showOff = isTouch && !!(M && tg);
      if (el['t-off'].hidden === showOff) el['t-off'].hidden = !showOff;
      if (!isTouch && hintT <= 0 && (keyNear || (st.mag > 0 && (tg || M)))) { el.hint.textContent = keyNear ? 'E 키로 메인홀 열쇠 줍기' : tg ? 'E 키로 ' + act + (M ? ' · X 키로 내리기' : '') : 'E 키로 내리기'; el.hint.style.opacity = 1; }
      // the lab: the next cage and its countdown. the safari: the time to the stampede, then how many are left
      const nc = Lab.active && Lab.running ? Lab.next() : null, sf = Safari.active && !Game.ended;
      if (el.cagebar.hidden === !!(nc || sf)) el.cagebar.hidden = !(nc || sf);
      set('cagelbl', sf ? (Safari.stampede ? '습격 중' : '습격까지') : '다음 우리');
      if (sf) {
        const L = Safari.left(), m = Math.floor(Math.ceil(L) / 60), s2 = Math.ceil(L) % 60;
        set('cagetxt', Safari.stampede ? '남은 동물' : '동물 100마리가 감시탑으로');
        set('cagesec', Safari.stampede ? (Game.goal - Game.kills - (Game.calm || 0)) + '마리' : m + ':' + String(s2).padStart(2, '0'));
        const soon = !Safari.stampede && L <= 30; if (cache.soon !== soon) { cache.soon = soon; el.cagebar.classList.toggle('soon', soon); }
      } else if (nc) {
        const left = Math.max(0, nc.openAt - Lab.t), A = ANIMALS[nc.type];
        set('cagetxt', nc.n + '번 · ' + (nc.boss ? '보스 ' + BOSS[3].name : A.name + ' ' + nc.animals.filter((e) => e.alive).length + '마리'));
        set('cagesec', nc.held ? (Lab.reach === nc ? '버튼을 누르는 중' : '앞 우리 ' + Math.min(99, Lab.waitLeft(nc)) + '마리 남음') : Math.ceil(left) + '초');
        const soon = !nc.held && left <= 3; if (cache.soon !== soon) { cache.soon = soon; el.cagebar.classList.toggle('soon', soon); }
      }
      // boss health once it has noticed you; arrows to the last ten enemies
      // the boss once it has noticed you; on the ship, the gold commander instead while it is the nearer fight
      let B = Game.boss, mid = false;
      const MB = Game.mid; if (MB && MB.alive && MB.alert && (!B || !B.alive || !B.alert || MB.dist < B.dist)) { B = MB; mid = true; }
      // 3-1's watchtower: the same tall red bar as a mount, on the right, while it stands
      const TW = Tower.active && Tower.standing && !Game.ended;
      if (el.vbarT.hidden === TW) el.vbarT.hidden = !TW;
      if (TW) { const f = clamp(Tower.hp / Tower.maxHp, 0, 1); set('vnumT', Math.ceil(Tower.hp).toLocaleString('ko-KR')); set('vfillT', 'calc(' + (100 * f).toFixed(1) + '% - 6px)', 'height');
        set('vlblT', Tower.on ? '감시탑\n탑 위' : '감시탑'); const lowT = f < 0.25; if (cache.lowT !== lowT) { cache.lowT = lowT; el.vbarT.classList.toggle('low', lowT); } }
      const showBoss = !!(B && B.alive && (B.alert || B.angry || B.hp < B.maxHp) && B.dist < 110);
      if (el.bossbar.hidden === showBoss) { el.bossbar.hidden = !showBoss; document.body.classList.toggle('bossbar-on', showBoss); }
      if (showBoss) { set('bossname', (mid ? '중간 보스 · ' : '보스 · ') + B.name + (B.k && B.k.phase !== undefined && B.type === 'bdrone' ? ' · ' + (B.k.phase + 1) + '페이즈' : '')); set('bossfill', Math.round(100 * clamp(B.hp / B.maxHp, 0, 1)) + '%', 'width'); }
      const left = Game.goal - Game.kills - (Game.calm || 0), chest = Game.chestWait ? Loot.pending() : null;
      if (chest) {
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw), dx = chest.x - player.pos.x, dz = chest.z - player.pos.z;
        tgts.forEach((t, i) => { if (i) { t.style.opacity = 0; return; } t.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; t.style.opacity = 0.95; });
      } else if (left > 0 && left <= 10 && !Game.ended && Game.stage !== 4) {
        const near = Enemies.list.filter((e) => e.alive && !e.tamed && !e.extra).sort((a, b) => a.dist - b.dist).slice(0, 3);
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
        tgts.forEach((t, i) => { const e = near[i]; if (!e) { t.style.opacity = 0; return; }
          const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z;
          t.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; t.style.opacity = i === 0 ? 0.95 : 0.55; });
      } else tgts.forEach((t) => { t.style.opacity = 0; });
      for (const A of arcs) {
        if (A.life <= 0) { A.a.style.opacity = 0; continue; }
        A.life -= dt;
        const dx = A.from.x - player.pos.x, dz = A.from.z - player.pos.z, sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
        A.a.style.transform = 'rotate(' + Math.atan2(dx * cy - dz * sy, -dx * sy - dz * cy) + 'rad)'; A.a.style.opacity = clamp(A.life, 0, 1);
      }
      if (bannerT > 0) { bannerT -= dt; el.banner.style.opacity = bannerT > 0.35 ? 1 : 0; } else el.banner.style.opacity = 0;
    },
  };
})();

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

/* ============ tactical map: the stage from above, enemies, the drop point and where you face ============ */
const TacMap = (() => {
  let base = null, H = 68, stage = 1, CX = 0, CZ = 0; // the half-size of the square shown, and its middle (the ship's runs east of 0)
  const PAD = 4;
  const THEME = {
    1: { bg: '#1d2230', grid: 'rgba(236,230,216,0.06)', block: '#59606e', blockHi: '#7a8292', wall: '#8a8f99', label: '컨테이너 부두' },
    6: { bg: '#1e2330', grid: 'rgba(236,230,216,0.06)', block: '#5a5f6c', blockHi: '#7b8190', wall: '#8a8f99', label: '헬멧 부두' },
    5: { bg: '#20222e', grid: 'rgba(236,230,216,0.06)', block: '#5c6170', blockHi: '#7c8294', wall: '#8a8f99', label: '무장 부두' },
    4: { bg: '#141a26', grid: 'rgba(140,200,255,0.08)', block: '#3f4b62', blockHi: '#6c7c9c', wall: '#8ea0c4', label: '우주선' },
    2: { bg: '#1a2118', grid: 'rgba(200,236,200,0.06)', block: '#6b5741', blockHi: '#7f6a50', wall: '#4a3a28', label: '불타는 마을' },
    3: { bg: '#2a3138', grid: 'rgba(200,230,235,0.08)', block: '#55606a', blockHi: '#76828c', wall: '#9aa6ae', label: '동물 연구소' },
    8: { bg: '#262d36', grid: 'rgba(200,220,240,0.08)', block: '#525d68', blockHi: '#73808b', wall: '#96a2ad', label: '차례 연구소' },
    7: { bg: '#3b3a24', grid: 'rgba(240,230,190,0.07)', block: '#857560', blockHi: '#9a8a70', wall: '#6a5a3a', label: '사파리 감시탑' },
  };
  /* the parts that never move are drawn once per stage into an offscreen canvas */
  function build(st, info) {
    stage = st; H = st === 3 || st === 8 ? LAB_HALF + 2 : st === 4 ? 146 : st === 7 ? 180 : 68; CX = st === 4 ? 19 : 0; CZ = 0; // 5.16: the ship, -127..165 east to west
    const T = THEME[st], N = 1024, k = N / (2 * (H + PAD)), c = document.createElement('canvas'); c.width = c.height = N;
    const g = c.getContext('2d'), X = (x) => (x - CX + H + PAD) * k, Z = (z) => (z - CZ + H + PAD) * k;
    g.fillStyle = T.bg; g.fillRect(0, 0, N, N);
    const m = info.map || {};
    if (m.water) { g.fillStyle = '#4a6a7a'; g.beginPath(); g.arc(X(m.water.x), Z(m.water.z), m.water.r * k, 0, TAU); g.fill(); g.strokeStyle = '#6a4a30'; g.lineWidth = 6 * k; g.stroke(); }
    if (m.roads) { g.strokeStyle = 'rgba(138,106,69,0.9)'; g.lineWidth = 6 * k; g.lineJoin = 'round';
      for (const line of m.roads) { g.beginPath(); line.forEach(([x, z], i) => (i ? g.lineTo(X(x), Z(z)) : g.moveTo(X(x), Z(z)))); g.stroke(); } }
    if (isYard(st)) { g.fillStyle = 'rgba(201,150,44,0.25)'; for (const z of [-33, -11, 11, 33]) g.fillRect(X(-64), Z(z) - 1, 128 * k, 2); for (const x of [-36, -12, 12, 36]) g.fillRect(X(x) - 1, Z(-64), 2, 128 * k); }
    g.strokeStyle = T.grid; g.lineWidth = 1;
    const step = st === 3 || st === 8 ? 10 : st === 7 ? 40 : 20;
    for (let v = Math.ceil((CX - H) / step) * step; v <= CX + H; v += step) { g.beginPath(); g.moveTo(X(v), Z(CZ - H)); g.lineTo(X(v), Z(CZ + H)); g.stroke(); }
    for (let v = Math.ceil((CZ - H) / step) * step; v <= CZ + H; v += step) { g.beginPath(); g.moveTo(X(CX - H), Z(v)); g.lineTo(X(CX + H), Z(v)); g.stroke(); }
    // 5.16: the main hall's sunken pyramid: each flight a band a shade darker than the one above, the landings picked out, the depth on each
    if (st === 4 && PIT !== null) {
      const P = PYR, rect = (ax, az) => [X(P.cx - ax), Z(P.cz - az), 2 * ax * k, 2 * az * k];
      g.fillStyle = '#1b2232'; g.fillRect(...rect(P.ox, P.oz));
      for (const s2 of P.steps) { const f = -s2.y / -P.bottom; g.fillStyle = s2.land ? 'rgba(94,200,255,' + (0.16 - f * 0.06).toFixed(3) + ')' : 'rgba(8,12,22,' + (0.05 + f * 0.04).toFixed(3) + ')'; g.fillRect(...rect(s2.ax, s2.az)); }
      g.fillStyle = '#0c111c'; g.fillRect(...rect(P.bx, P.bz));
      g.lineWidth = 1.5; for (const s2 of P.steps) if (s2.land || s2.k === P.steps.length) { g.strokeStyle = 'rgba(94,200,255,0.55)'; g.strokeRect(...rect(s2.ax - s2.w, s2.az - s2.w)); }
      g.strokeStyle = '#e8b040'; g.lineWidth = 2; g.strokeRect(...rect(P.ox, P.oz));
      g.font = '700 ' + Math.round(9 * N / 1024 * 1.4) + 'px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = 'rgba(160,210,255,0.8)';
      for (const s2 of P.steps) if (s2.land) g.fillText(Math.round(s2.y) + 'm', X(P.cx), Z(P.cz - s2.az + s2.w / 2));
      g.fillText(Math.round(P.bottom) + 'm', X(P.cx), Z(P.cz - P.bz + 3));
    }
    for (const b of colliders) {
      if (b.kind === 'wood' && b.ref) continue; // crates are drawn live so broken ones disappear
      if (b.grate || b.tower || b.door || b.step) continue; // cage walls and the watchtower are drawn live too: walls fall, the tower can come down; the pit is drawn above
      if (b.miny > 3) continue; // ceilings and lintels: overhead, not in the way
      const w = b.maxx - b.minx, d = b.maxz - b.minz;
      if (w * d < 0.5) continue;
      if (b.maxy >= 10 && (w > 40 || d > 40)) { g.fillStyle = T.wall; } // perimeter
      else g.fillStyle = b.maxy > 5 ? T.blockHi : T.block;
      g.fillRect(X(b.minx), Z(b.minz), Math.max(1.5, w * k), Math.max(1.5, d * k));
    }
    if (m.trees) { g.fillStyle = 'rgba(58,74,34,0.85)'; for (const [x, z, , cr] of m.trees) { g.beginPath(); g.arc(X(x), Z(z), cr * k, 0, TAU); g.fill(); } }
    if (m.fires) for (const [x, z, p] of m.fires) { const gr = g.createRadialGradient(X(x), Z(z), 0, X(x), Z(z), (2 + p * 2.5) * k);
      gr.addColorStop(0, 'rgba(255,170,60,0.95)'); gr.addColorStop(0.4, 'rgba(255,90,20,0.6)'); gr.addColorStop(1, 'rgba(255,60,10,0)'); g.fillStyle = gr; g.beginPath(); g.arc(X(x), Z(z), (2 + p * 2.5) * k, 0, TAU); g.fill(); }
    g.strokeStyle = 'rgba(236,230,216,0.5)'; g.lineWidth = 2; g.strokeRect(X(CX - H), Z(CZ - H), 2 * H * k, 2 * H * k);
    base = c;
  }
  /* what each dot colour means, per stage; the legend under the map is built from the same table */
  const KINDS = {
    1: [['thug', '#ff5260', '조직원']],
    5: [['thug', '#ff5260', '총 · 수류탄 · 화염'], ['dagger', '#ff9a3a', '단검'], ['saber', '#4f8cff', '파란 광선검'], ['saber2', '#ff5ad8', '쌍광선검'], ['bat', '#cfd4dc', '야구방망이'], ['bomber', '#ffd23a', '자폭맨']],
    2: [['zombie', '#9be88f', '좀비']],
    4: [['cctv', '#ffd23a', 'CCTV 포탑'], ['patrol', '#b8ff4a', '순찰 로봇'], ['droneA', '#c58bff', '드론'], ['mine', '#ff5a3a', '스파이더 마인 (움직일 때만)'], ['midboss', '#ffb020', '황금 지휘 드론 · 중간 보스']],
    6: [['thug', '#ff5260', '오토바이 헬멧 조직원']],
    3: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '고릴라 졸개'], ['tame', '#5ed6b0', '길들인 동물']],
    8: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '고릴라 졸개'], ['tame', '#5ed6b0', '길들인 동물']],
    7: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '로랜드고릴라'], ['tame', '#5ed6b0', '길들인 동물']],
  };
  const COLOR = {}; for (const k in KINDS) for (const [id, c] of KINDS[k]) COLOR[id] = c;
  const ENEMY_COLOR = (e) => e.animal ? COLOR[e.tamed ? 'tame' : e.kong && !e.boss ? 'gorilla' : e.T.mode === 'cat' || e.T.mode === 'prey' ? e.T.mode : 'big']
    : e.robot ? COLOR[e.T.mapKind] || '#8ec8ff' : e.kit === 'saber' || e.kit === 'saber2' || e.kit === 'bat' || e.kit === 'bomber' || e.kit === 'dagger' ? COLOR[e.kit] : COLOR[e.type] || '#ff5260';
  function legend(el, live) {
    const item = (cls, txt, style, inner) => '<span><i class="lg ' + cls + '"' + (style ? ' style="' + style + '"' : '') + '>' + (inner || '') + '</i>' + txt + '</span>';
    const lab = stage === 3 || stage === 8;
    el.innerHTML = item('me', '나 · 바라보는 방향') + item('lz', lab ? '출입문 · 시작하는 곳' : stage === 4 ? '에어록 · 시작하는 곳' : stage === 5 && !live ? '내리는 곳 · 지도를 눌러 바꾸기' : '헬기에서 내리는 곳', '', lab ? '문' : stage === 4 ? 'A' : 'H') +
      KINDS[stage].map(([, c, n]) => item('en', n, 'background:' + c)).join('') +
      (stage === 7 ? item('tw', '감시탑 · 체력') : item('bo', '보스')) + item('cr', '나무 상자') + (lab ? item('cg', '우리 · 번호와 열리는 시간') : '') + (live ? item('al', '흰 테두리 · 나를 쫓는 중') : '');
  }
  /* draw the map into a visible canvas; size follows the element */
  function draw(cv) {
    if (!base) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1), size = cv.clientWidth;
    if (cv.width !== Math.round(size * dpr)) { cv.width = cv.height = Math.round(size * dpr); }
    const g = cv.getContext('2d'), N = cv.width, k = N / (2 * (H + PAD)), X = (x) => (x - CX + H + PAD) * k, Z = (z) => (z - CZ + H + PAD) * k;
    g.drawImage(base, 0, 0, N, N);
    const u = N / 600; // marker size unit
    // north and scale first, on small dark chips inside the border, so every marker draws over them
    const edge = (PAD * k) + 8 * u, bar = stage === 3 || stage === 8 ? 10 : stage === 7 ? 50 : 20;
    g.fillStyle = 'rgba(13,18,32,0.78)'; g.fillRect(edge, edge, 40 * u, 22 * u);
    g.fillStyle = 'rgba(236,230,216,0.95)'; g.font = '600 ' + Math.round(13 * u) + 'px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('N ↑', edge + 20 * u, edge + 11.5 * u);
    const bw = bar * k + 16 * u;
    g.fillStyle = 'rgba(13,18,32,0.78)'; g.fillRect(N - edge - bw, N - edge - 30 * u, bw, 30 * u);
    g.fillStyle = 'rgba(236,230,216,0.95)'; g.fillRect(N - edge - 8 * u - bar * k, N - edge - 9 * u, bar * k, 2.5 * u);
    g.font = Math.round(11 * u) + 'px "IBM Plex Mono", monospace'; g.textAlign = 'right'; g.fillText(bar + 'm', N - edge - 8 * u, N - edge - 19 * u);
    // the lab's cages: shut ones as bars with the number and seconds left, open ones as the walls lying flat
    for (const c of (Lab.active ? Lab.cages : [])) {
      const x0 = X(c.x - c.w / 2), z0 = Z(c.z - c.d / 2), w = c.w * k, d = c.d * k;
      if (c.open) { g.fillStyle = 'rgba(141,148,156,0.18)'; g.fillRect(X(c.x - c.w / 2 - c.h), z0, (c.w + 2 * c.h) * k, d); g.fillRect(x0, Z(c.z - c.d / 2 - c.h), w, (c.d + 2 * c.h) * k); }
      g.strokeStyle = c.open ? 'rgba(141,148,156,0.45)' : '#c9d2da'; g.lineWidth = (c.open ? 1.2 : 2.4) * u; g.setLineDash(c.open ? [4 * u, 4 * u] : []); g.strokeRect(x0, z0, w, d); g.setLineDash([]);
      const remain = Lab.running ? c.openAt - Lab.t : c.openAt, A = ANIMALS[c.type];
      // number and animal above the cage, seconds below it, so the dots inside stay clear
      tag(g, c.n + ' ' + (c.boss ? '보스' : A.name), X(c.x), z0 - 7 * u, u, c.open ? '#8d949c' : '#ece6d8');
      tag(g, c.open ? '열림' : c.held ? '앞 우리를 비우면' : Math.ceil(remain) + '초', X(c.x), z0 + d + 7 * u, u, c.open ? '#5ed6b0' : c.held ? '#8fb8ff' : remain <= 5 ? '#ff5260' : '#f2a33a');
    }
    // the safari's watchtower: its foot, the steps, and how much it has left; a dashed outline once it is down
    if (Tower.active) {
      const B = TOWER.base, x0 = X(Tower.x - B), z0 = Z(Tower.z - B), w = 2 * B * k;
      if (Tower.standing) {
        g.fillStyle = '#8a6440'; g.fillRect(x0, z0, w, w); g.fillRect(X(Tower.x - 0.7), Z(Tower.z + B), 1.4 * k, (TOWER.half + 0.5 * TOWER.steps - B) * k);
        g.strokeStyle = '#f2e6c8'; g.lineWidth = 2 * u; g.strokeRect(x0, z0, w, w);
      } else { g.strokeStyle = 'rgba(242,230,200,0.6)'; g.lineWidth = 1.5 * u; g.setLineDash([4 * u, 4 * u]); g.strokeRect(x0, z0, w, w); g.setLineDash([]); }
      tag(g, Tower.standing ? '감시탑 ' + Math.round(100 * Tower.hp / Tower.maxHp) + '%' : '감시탑 무너짐', X(Tower.x), z0 - 9 * u, u, Tower.standing ? '#f2e6c8' : '#ff8a7a');
    }
    g.fillStyle = '#a7804e';
    for (const c of crates) if (!c.dead) g.fillRect(X(c.x) - 2.2 * u, Z(c.z) - 2.2 * u, 4.4 * u, 4.4 * u);
    // the drop point: a helipad mark
    const s = Game.info.start;
    g.strokeStyle = '#f2a33a'; g.fillStyle = 'rgba(242,163,58,0.18)'; g.lineWidth = 2 * u;
    g.beginPath(); g.arc(X(s.x), Z(s.z), 11 * u, 0, TAU); g.fill(); g.stroke();
    const lab = stage === 3 || stage === 8;
    g.fillStyle = '#f2a33a'; g.font = (lab ? '700 ' + Math.round(11 * u) + 'px "IBM Plex Sans KR", sans-serif' : '600 ' + Math.round(12 * u) + 'px "IBM Plex Mono", monospace'); g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(lab ? '문' : stage === 4 ? 'A' : 'H', X(s.x), Z(s.z) + 0.5 * u);
    tag(g, lab ? '출입문' : stage === 4 ? '에어록' : '내리는 곳', X(s.x) + 15 * u, Z(s.z) + 0.5 * u, u, '#f2a33a', 'left');
    for (const e of Enemies.list) {
      if (!e.alive || e.ridden) continue; // the one you ride is under your arrow
      if (e.T && e.T.mode === 'mine' && (e.bs === 'hidden' || !e.bs)) continue; // buried mines stay hidden, even here
      const x = X(e.pos.x), z = Z(e.pos.z);
      if (e.boss) {
        g.fillStyle = '#ff2d3d'; g.beginPath(); g.arc(x, z, 7 * u, 0, TAU); g.fill();
        g.strokeStyle = '#fff'; g.lineWidth = 1.6 * u; g.stroke();
        tag(g, '보스', x, z - 13 * u, u, '#ffffff');
      } else {
        const rr = (e.T && e.T.mid ? 5.5 : e.animal && e.R > 0.9 ? 4.2 : 3.2) * u;
        g.fillStyle = ENEMY_COLOR(e); g.beginPath(); g.arc(x, z, rr, 0, TAU); g.fill();
        if (e.alert || e.angry) { g.strokeStyle = '#ffffff'; g.lineWidth = 1.2 * u; g.beginPath(); g.arc(x, z, rr + 2 * u, 0, TAU); g.stroke(); }
      }
    }
    // you: position, facing arrow and view cone (map north is world -z)
    const px = X(player.pos.x), pz = Z(player.pos.z), ang = Math.atan2(-Math.cos(player.yaw), -Math.sin(player.yaw));
    g.save(); g.translate(px, pz); g.rotate(ang);
    const fov = THREE.MathUtils.degToRad(camera.fov) * 0.6;
    const cone = g.createRadialGradient(0, 0, 0, 0, 0, 60 * u); cone.addColorStop(0, 'rgba(94,214,176,0.45)'); cone.addColorStop(1, 'rgba(94,214,176,0)');
    g.fillStyle = cone; g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, 60 * u, -fov / 2, fov / 2); g.closePath(); g.fill();
    g.fillStyle = '#5ed6b0'; g.strokeStyle = '#0d1220'; g.lineWidth = 1.5 * u;
    g.beginPath(); g.moveTo(11 * u, 0); g.lineTo(-7 * u, 7 * u); g.lineTo(-3 * u, 0); g.lineTo(-7 * u, -7 * u); g.closePath(); g.fill(); g.stroke();
    g.restore();
  }
  function tag(g, text, x, y, u, color, align) {
    g.font = '700 ' + Math.round(11 * u) + 'px "IBM Plex Sans KR", sans-serif'; g.textAlign = align || 'center'; g.textBaseline = 'middle';
    g.lineJoin = 'round'; g.strokeStyle = 'rgba(13,18,32,0.9)'; g.lineWidth = 3.5 * u; g.strokeText(text, x, y); g.fillStyle = color; g.fillText(text, x, y);
  }
  /* a point on a drawn map back to the ground it shows */
  function toWorld(cv, cx, cy) {
    const r = cv.getBoundingClientRect(), N = cv.width, k = N / (2 * (H + PAD));
    return { x: ((cx - r.left) * (N / r.width)) / k - H - PAD + CX, z: ((cy - r.top) * (N / r.height)) / k - H - PAD + CZ };
  }
  return { build, draw, legend, toWorld, get title() { return THEME[stage].label; } };
})();

/* ============ between stages: weapon rental, weapon layout, save codes, reset, developer mode ============ */
/* money spent inside a stage also comes off what you would walk away with if you fall */
function spend(c) { save.money -= c; if (moneyLock !== null) moneyLock -= c; persist(); }
function refund(c) { save.money += c; if (moneyLock !== null) moneyLock += c; persist(); }
const SIDE_SCREENS = ['menu', 'over', 'pause', 'shop', 'loadout', 'dlg', 'brief', 'codex', 'custom'];
function showOnly(id) { SIDE_SCREENS.forEach((s) => { $(s).hidden = s !== id; }); }
function backTo(from) { showOnly(from); if (from === 'menu') refreshMenu(); if (from === 'brief') briefGear(); if (from === 'loadout') Loadout.render(); }

/* ---------- items: bought once, kept until used up ---------- */
const ITEMS = {
  helmet: { name: '오토바이 헬멧', tag: '머리', price: 10000, desc: '머리로 오는 공격을 한 번 막아 줍니다. 막으면 부서집니다.' },
  vest: { name: '방탄조끼', tag: '몸', price: 50000, desc: '몸으로 오는 공격을 50% 줄여 줍니다. 10번 막으면 닳아 없어집니다. 불은 못 막습니다.' },
  jet: { name: '제트백팩', tag: '비행', price: 100000, desc: isTouch ? '점프 버튼을 두 번 누르면 날아오릅니다. 점프는 위로, 내려가기 버튼은 아래로. 최대 10초, 한 번 쓰면 끝입니다.'
    : '점프(Space)를 두 번 누르면 날아오릅니다. Space는 위로, Ctrl 또는 C는 아래로. 최대 10초, 한 번 쓰면 끝입니다.' },
};
/* elephant tusks: the shop buys each pair for this */
const IVORY_PRICE = 50000;
const itemState = (id) => { const v = save.items[id]; return !v ? '없음' : id === 'vest' ? '착용 중 · 내구 ' + v + '/10' : id === 'helmet' ? '착용 중' : '가지고 있음'; };
/* ---------- rental ---------- */
const Shop = {
  from: 'menu',
  get mid() { return this.from === 'pause' || (this.from === 'loadout' && Loadout.from === 'pause'); },
  open(from) { this.from = from; showOnly('shop'); $('shopmsg').textContent = ''; this.render(); setTimeout(() => $('shopclose').focus(), 0); },
  close() { $('shop').hidden = true; backTo(this.from); },
  msg(t) { $('shopmsg').textContent = t; },
  render() {
    $('shopmoney').textContent = '가방 ' + won(save.money);
    $('shophead').textContent = settings.dev ? '상점 · 개발자 모드: 모두 무료' : this.mid ? '상점 · 대여는 이번 스테이지 동안' : '상점 · 아이템과 무기 대여';
    const list = $('shoplist'); list.textContent = '';
    const head = (t) => { const h = document.createElement('div'); h.className = 'shophd'; h.textContent = t; list.appendChild(h); };
    head('아이템 · 다 쓸 때까지 가지고 다닙니다');
    ['helmet', 'vest', 'jet'].forEach((id) => {
      const I = ITEMS[id], have = !!save.items[id], price = settings.dev ? 0 : I.price;
      const row = document.createElement('div'); row.className = 'wrow item' + (have ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = I.name + ' '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = I.tag; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = I.desc; title.append(b, c);
      const st = document.createElement('div'); st.className = 'istate' + (have ? ' on' : ''); st.textContent = itemState(id);
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const pr = document.createElement('span'); pr.className = 'price'; pr.textContent = price ? won(price) : '무료 · 개발자 모드';
      const btns = document.createElement('div'); btns.className = 'btns';
      const x = document.createElement('button'); x.className = 'sbtn'; x.textContent = have ? '보유 중' : '구매'; x.disabled = have || save.money < price; x.addEventListener('click', () => this.buyItem(id)); btns.appendChild(x);
      buy.append(pr, btns); row.append(title, st, buy); list.appendChild(row);
    });
    // ivory from the lab's elephants: sell it here. inside a stage only what you brought in can go (what you got in there is not yours until you are out)
    {
      const have = save.items.ivory | 0, can = ivoryLock === null ? have : Math.min(have, ivoryLock), price = IVORY_PRICE;
      const row = document.createElement('div'); row.className = 'wrow item' + (have ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = '상아 '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = '팔기'; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = '스테이지 3의 코끼리를 잡으면 얻습니다(다시 하기에서는 안 나옴). 1개에 ' + won(price) + '에 삽니다.' + (can < have ? ' 이번 스테이지에서 얻은 것은 나간 뒤에 팔 수 있습니다.' : ''); title.append(b, c);
      const st = document.createElement('div'); st.className = 'istate' + (have ? ' on' : ''); st.textContent = have ? have + '개 가지고 있음' : '없음';
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const pr = document.createElement('span'); pr.className = 'price'; pr.textContent = '1개 ' + won(price);
      const btns = document.createElement('div'); btns.className = 'btns';
      const sell = (n, label) => { const x = document.createElement('button'); x.className = 'sbtn' + (n > 1 ? ' alt' : ''); x.textContent = label; x.disabled = can < 1; x.addEventListener('click', () => this.sellIvory(n)); btns.appendChild(x); };
      sell(1, '1개 팔기'); if (can > 1) sell(can, '모두 팔기 · ' + won(price * can));
      buy.append(pr, btns); row.append(title, st, buy); list.appendChild(row);
    }
    head(this.mid ? '무기 대여 · 이번 스테이지 동안' : '무기 대여 · 다음 스테이지 한 번');
    ORDER.forEach((id) => {
      const w = WEAPONS[id], rented = save.rented.includes(id), owned = save.owned.includes(id), free = id === 'pistol' || settings.dev;
      const has = free || rented || owned;
      const row = document.createElement('div'); row.className = 'wrow' + (has ? ' own' : '');
      const title = document.createElement('div'); title.className = 'wtitle';
      const b = document.createElement('b'); b.textContent = w.name + ' '; const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = w.model; b.appendChild(tag);
      const c = document.createElement('span'); c.textContent = w.cls + ' · 총알 ' + (w.reserve === Infinity ? '무제한' : w.reserve.toLocaleString('ko-KR') + '발') + (w.note ? ' · ' + w.note : ''); title.append(b, c);
      const st = document.createElement('div'); st.className = 'wstats';
      [['피해', (w.dmg * w.pellets) / 170], ['연사', (1 / w.rate) / 22.2], ['탄창', Math.log(w.mag) / Math.log(1200)]].forEach(([k, v]) => {
        const l = document.createElement('span'); l.textContent = k; const bar = document.createElement('i'); const f = document.createElement('b');
        f.style.width = Math.round(clamp(v, 0.04, 1) * 100) + '%'; bar.appendChild(f); st.append(l, bar);
      });
      const buy = document.createElement('div'); buy.className = 'wbuy';
      const price = document.createElement('span'); price.className = 'price';
      price.textContent = id === 'pistol' ? '무료' : settings.dev ? '무료 · 개발자 모드' : owned ? '보유 · 영구 (보물상자)' : rented ? '대여 중' : '대여료 ' + won(w.rent);
      const real = document.createElement('span'); real.className = 'real'; real.textContent = '실제 시세 약 ' + Math.round(w.real / 10000).toLocaleString('ko-KR') + '만 원';
      const btns = document.createElement('div'); btns.className = 'btns';
      const btn = (label, alt, fn, dis) => { const x = document.createElement('button'); x.className = 'sbtn' + (alt ? ' alt' : ''); x.textContent = label; x.disabled = !!dis; x.addEventListener('click', fn); btns.appendChild(x); };
      if (!has) btn('대여', false, () => this.rent(id), save.money < w.rent);
      else if (rented && !owned && !this.mid && !settings.dev) btn('대여 취소', true, () => this.cancel(id));
      if (has && this.mid && AMMO100[id]) { const c100 = settings.dev ? 0 : AMMO100[id], rk = WEAPONS[id].rocket;
        btn((rk ? '로켓 +1 · ' : '총알 +100 · ') + (c100 ? won(c100) : '무료') + (rk ? ' (' + (wstate[id].mag + wstate[id].reserve) + '/12)' : ''), true, () => this.ammo(id), save.money < c100 || ammoRoom(id) < 1); }
      buy.append(price, real, btns);
      row.append(title, st, buy); list.appendChild(row);
    });
  },
  buyItem(id) {
    const I = ITEMS[id], price = settings.dev ? 0 : I.price;
    if (save.items[id]) { this.msg(I.name + '은(는) 이미 가지고 있습니다'); return; }
    if (save.money < price) { this.msg(won(price - save.money) + ' 더 필요합니다'); return; }
    spend(price); save.items[id] = id === 'vest' ? 10 : 1; persist(); Sound.buy();
    this.msg(I.name + ' 구매' + (id === 'jet' ? ' · 싸우는 중에 점프를 두 번 누르면 날아오릅니다' : ' · 바로 착용했습니다'));
    this.render(); HUD.items();
  },
  sellIvory(n) {
    const have = save.items.ivory | 0, can = ivoryLock === null ? have : Math.min(have, ivoryLock); n = Math.min(n, can);
    if (n < 1) { this.msg('팔 수 있는 상아가 없습니다'); return; }
    save.items.ivory = have - n; if (ivoryLock !== null) ivoryLock -= n;
    refund(n * IVORY_PRICE); persist(); Sound.buy(); Sound.coin();
    this.msg('상아 ' + n + '개를 팔았습니다 · +' + won(n * IVORY_PRICE)); this.render(); HUD.items();
  },
  rent(id) {
    const w = WEAPONS[id];
    if (save.money < w.rent) { this.msg(won(w.rent - save.money) + ' 더 필요합니다'); return; }
    spend(w.rent); save.rented.push(id);
    const slot = Loadout.place(id); persist(); Sound.buy();
    if (this.mid) gainGun(id);
    this.msg(w.name + ' 대여 · ' + (this.mid ? '이번 스테이지가 끝나면 반납' : '다음 스테이지 한 번 쓰고 반납') + (slot ? ' · ' + slot + '번 칸에 넣었습니다' : ' · 빈 칸이 없어 무기 편성에서 넣어 주세요'));
    this.render();
  },
  cancel(id) {
    const w = WEAPONS[id];
    save.rented = save.rented.filter((x) => x !== id); refund(w.rent); Sound.reload(0);
    this.msg(w.name + ' 대여를 취소했습니다 · ' + won(w.rent) + ' 돌려받음'); this.render();
  },
  ammo(id) {
    const w = WEAPONS[id], c = settings.dev ? 0 : AMMO100[id];
    if (save.money < c) { this.msg(won(c - save.money) + ' 더 필요합니다'); return; }
    if (ammoRoom(id) < 1) { this.msg(w.name + ' · 더 들 수 없습니다'); return; }
    spend(c); wstate[id].reserve += ammoPack(id); Sound.reload(1);
    this.msg(w.name + (w.rocket ? ' 로켓 1발 · ' + (wstate[id].mag + wstate[id].reserve) + '/12' : ' 총알 100발 · ' + wstate[id].reserve + '발')); this.render();
  },
};

/* ---------- weapon layout: which gun sits on keys 1-7, any slot can be left empty ---------- */
const Loadout = {
  from: 'menu',
  open(from) { this.from = from; $('locustom').hidden = state === 'paused' || state === 'playing'; showOnly('loadout'); this.msg(''); this.render(); setTimeout(() => $('loclose').focus(), 0); },
  close() {
    if (this.from === 'pause') { applyLoadout(); if (Gun.none) { this.msg('싸우는 중에는 무기를 하나 이상 넣어야 합니다'); return; } }
    $('loadout').hidden = true; backTo(this.from);
  },
  msg(t) { $('lomsg').textContent = t; },
  /* a freshly rented gun goes into the first empty slot */
  place(id) {
    const at = save.loadout.indexOf(id); if (at >= 0) return at + 1;
    const i = save.loadout.indexOf(null); if (i < 0) return 0;
    save.loadout[i] = id; persist(); return i + 1;
  },
  set(slot, id) {
    if (id) { const j = save.loadout.indexOf(id); if (j >= 0 && j !== slot) save.loadout[j] = null; }
    save.loadout[slot] = id || null; persist();
    if (this.from === 'pause') applyLoadout();
    this.render();
  },
  render() {
    const box = $('lolist'); box.textContent = '';
    save.loadout.forEach((cur, i) => {
      const row = document.createElement('label'); row.className = 'lorow'; row.htmlFor = 'lo' + i;
      const k = document.createElement('kbd'); k.textContent = String(i + 1);
      const sel = document.createElement('select'); sel.id = 'lo' + i;
      const opt = (v, t) => { const o = document.createElement('option'); o.value = v; o.textContent = t; sel.appendChild(o); return o; };
      opt('', '비어 있음');
      ORDER.forEach((id) => {
        const ok = gunAvailable(id);
        if (!ok && id !== cur) return;
        const w = WEAPONS[id], at = save.loadout.indexOf(id);
        opt(id, w.name + ' ' + w.model + (!ok ? ' (대여 필요)' : save.owned.includes(id) ? ' · 보유' + (at >= 0 && at !== i ? ' (' + (at + 1) + '번에서 옮기기)' : '') : at >= 0 && at !== i ? ' (' + (at + 1) + '번에서 옮기기)' : ''));
      });
      sel.value = cur || '';
      sel.addEventListener('change', () => this.set(i, sel.value || null));
      const note = document.createElement('span'); note.className = 'lonote';
      note.textContent = !cur ? '' : !gunAvailable(cur) ? '이번에는 빈 칸' : cur === 'pistol' ? '무료' : settings.dev ? '개발자 모드' : save.owned.includes(cur) ? '보유' : '대여 중';
      row.append(k, sel, note); box.appendChild(row);
    });
    const ready = save.loadout.filter((id) => id && gunAvailable(id));
    $('losum').textContent = ready.length ? '출동하면 쓸 무기 · ' + save.loadout.map((id, i) => (id && gunAvailable(id) ? (i + 1) + ' ' + WEAPONS[id].short : '')).filter(Boolean).join(' · ')
      : '넣은 무기가 없습니다 · 무기를 하나 이상 넣어야 출동할 수 있습니다';
    $('losum').classList.toggle('warn', !ready.length);
  },
};

/* ---------- save codes: progress packed into 41 letters with a check, typed back in to restore ---------- */
const SaveCode = (() => {
  const AL = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  // version 1 (22 letters, stages 1-3) and version 2 (28 letters, five stages) still load; version 3 (30 letters) knows all six
  const F1 = [['ver', 4], ['money', 27], ['unlocked', 2], ['cleared', 3], ['t1', 13], ['t2', 13], ['t3', 13], ['lo', 21]];
  const F2 = [['ver', 4], ['money', 27], ['unlocked', 3], ['cleared', 5], ['t1', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['lo', 21]];
  const F3 = [['ver', 4], ['money', 27], ['cleared', 6], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['lo', 21]];
  // version 4 (31 letters) also carries the items you have not used up: helmet, vest durability, jetpack
  const F4 = F3.concat([['ih', 1], ['iv', 4], ['ij', 1]]);
  // version 5 (32 letters) adds the ivory you have not sold (up to 63)
  const F5 = F4.concat([['ivory', 6]]);
  // version 6 (34 letters) adds the guns you own for good (one bit each for the six that are not the pistol)
  const F6 = F5.concat([['own', 6]]), OWN = ['shotgun', 'rifle', 'smg', 'sniper', 'gl', 'lmg'];
  // version 7 (36 letters) knows stage 2-1 too: one more cleared bit and its best time
  const F7 = [['ver', 4], ['money', 27], ['cleared', 7], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['t7', 13], ['lo', 21], ['ih', 1], ['iv', 4], ['ij', 1], ['ivory', 6], ['own', 6]];
  // version 8 (41 letters) adds stage 3-2 (cleared bit and best time), the rocket launcher (a 7th owned-gun bit),
  // and a 4-bit slot in the weapon layout (eight guns no longer fit in three bits)
  const F8 = [['ver', 4], ['money', 27], ['cleared', 8], ['t1', 13], ['t6', 13], ['t5', 13], ['t2', 13], ['t3', 13], ['t4', 13], ['t7', 13], ['t8', 13], ['lo', 28], ['ih', 1], ['iv', 4], ['ij', 1], ['ivory', 6], ['own', 7]];
  const LEN = new Map([[22, F1], [28, F2], [30, F3], [31, F4], [32, F5], [34, F6], [36, F7], [41, F8]]), ORDER2 = [1, 5, 2, 3, 4];
  // which bit is which stage, as each version wrote them (the list on screen can change; these never do)
  const ORDER6 = [1, 6, 5, 2, 3, 4], ORDER7 = [1, 6, 5, 2, 3, 4, 7], ORDER8 = [1, 6, 5, 2, 3, 4, 7, 8], OWN7 = OWN.concat(['rocket']);
  const check = (n) => { let h = 0x811c9dc5; const s = n.toString(16); for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return BigInt((h ^ (h >>> 12)) & 0xfff); };
  const loPack = () => save.loadout.reduce((m, id, i) => m + (id ? ORDER.indexOf(id) + 1 : 0) * 16 ** i, 0);
  const loUnpack = (x, base) => { const lo = []; for (let i = 0; i < 7; i++) { const c = x % base; x = Math.floor(x / base); lo.push(c ? ORDER[c - 1] || null : null); } return lo; };
  function encode() {
    const t = (k) => Math.min(save.best[k] || 0, 8191);
    const v = { ver: 8, money: Math.min(Math.max(0, moneyLock === null ? save.money : Math.min(save.money, moneyLock)), 2 ** 27 - 1),
      cleared: ORDER8.reduce((m, s, i) => m | (save.cleared.includes(s) ? 1 << i : 0), 0), t1: t('t1'), t6: t('t6'), t5: t('t5'), t2: t('t2'), t3: t('t3'), t4: t('t4'), t7: t('t7'), t8: t('t8'), lo: loPack(),
      ih: save.items.helmet ? 1 : 0, iv: clamp(save.items.vest | 0, 0, 10), ij: save.items.jet ? 1 : 0,
      ivory: clamp(ivoryLock === null ? save.items.ivory | 0 : Math.min(save.items.ivory | 0, ivoryLock), 0, 63),
      own: OWN7.reduce((m, id, i) => m | ((ownLock === null ? save.owned : ownLock).includes(id) ? 1 << i : 0), 0) };
    let n = 0n; for (const [k, b] of F8) n = (n << BigInt(b)) | BigInt(v[k]);
    n = (n << 12n) | check(n);
    let s = ''; for (let i = 0; i < 41; i++) { s = AL[Number(n & 31n)] + s; n >>= 5n; }
    return s.match(/.{1,5}/g).join('-');
  }
  function decode(text) {
    const clean = String(text || '').toUpperCase().replace(/[\s-]/g, '').replace(/O/g, '0').replace(/[IL]/g, '1');
    const F = LEN.get(clean.length); if (!F) return null;
    let n = 0n; for (const ch of clean) { const k = AL.indexOf(ch); if (k < 0) return null; n = (n << 5n) | BigInt(k); }
    const ck = n & 0xfffn; let p = n >> 12n;
    if (check(p) !== ck) return null;
    const o = {}; for (let i = F.length - 1; i >= 0; i--) { const [k, b] = F[i]; o[k] = Number(p & ((1n << BigInt(b)) - 1n)); p >>= BigInt(b); }
    if (p !== 0n) return null;
    const best = {}; ['t1', 't6', 't5', 't2', 't3', 't4', 't7', 't8'].forEach((k) => { if (o[k]) best[k] = o[k]; });
    let cleared;
    if (F === F1) { if (o.ver !== 1 || o.unlocked < 1 || o.unlocked > 3) return null; cleared = [1, 2, 3].filter((s) => o.cleared & (1 << (s - 1))); }
    else if (F === F2) { if (o.ver !== 2 || o.unlocked < 1 || o.unlocked > 5) return null; cleared = ORDER2.filter((s, i) => o.cleared & (1 << i)); if (cleared.includes(5)) cleared.push(6); }
    else if (F === F3) { if (o.ver !== 3) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F4) { if (o.ver !== 4 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F5) { if (o.ver !== 5 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F6) { if (o.ver !== 6 || o.iv > 10) return null; cleared = ORDER6.filter((s, i) => o.cleared & (1 << i)); }
    else if (F === F7) { if (o.ver !== 7 || o.iv > 10) return null; cleared = ORDER7.filter((s, i) => o.cleared & (1 << i)); }
    else { if (o.ver !== 8 || o.iv > 10) return null; cleared = ORDER8.filter((s, i) => o.cleared & (1 << i)); }
    return { v: 4, money: o.money, cleared, best, loadout: loUnpack(o.lo, F === F8 ? 16 : 8), rented: [], owned: OWN7.filter((id, i) => (o.own || 0) & (1 << i)),
      items: { helmet: o.ih || 0, vest: o.iv || 0, jet: o.ij || 0, ivory: o.ivory || 0 } };
  }
  return { encode, decode };
})();

/* ---------- one small dialog for save, load and reset ---------- */
/* 5.15: the save code by email. the mail is written for you (code, date, what it holds, how to load it); the address you send it to
   is remembered on this device only. a mail app, Gmail on the web, or a plain copy for when neither opens */
const SaveMail = {
  text() {
    const code = SaveCode.encode(), d = new Date(), pad = (n) => String(n).padStart(2, '0');
    const when = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    const done = STAGE_ORDER.filter((s) => save.cleared.includes(s)).map(stageTag);
    const subject = '야르 07 저장 코드 · ' + when;
    const body = ['야르 07 저장 코드', '', code, '', '저장한 때: ' + when, '깬 스테이지: ' + (done.length ? done.join(', ') : '없음'), '가방: ' + won(save.money), '',
      "게임 처음 화면의 '불러오기'에 위 코드를 넣으면 이 진행 상황으로 돌아갑니다."].join('\r\n');
    return { subject, body };
  },
  addr() { const a = ($('mailto').value || '').trim(); return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(a) ? a : ''; },
  refresh() {
    const { subject, body } = this.text(), a = this.addr();
    $('mailbtn').href = 'mailto:' + encodeURIComponent(a).replace(/%40/g, '@') + '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
    $('gmailbtn').href = 'https://mail.google.com/mail/?view=cm&fs=1' + (a ? '&to=' + encodeURIComponent(a) : '') + '&su=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
  },
  copy() {
    const { subject, body } = this.text(), all = subject + '\n\n' + body.replace(/\r\n/g, '\n'), done = () => { $('dlgmsg').textContent = '메일 내용을 복사했습니다 · 메일에 붙여 넣어 보내세요'; };
    const fallback = () => { const t = document.createElement('textarea'); t.value = all; t.setAttribute('readonly', ''); t.style.position = 'fixed'; t.style.opacity = '0'; document.body.appendChild(t); t.select();
      let ok = false; try { ok = document.execCommand('copy'); } catch (e) {} t.remove(); if (ok) done(); else $('dlgmsg').textContent = '복사가 막혀 있습니다 · 위 코드를 길게 눌러 복사해 주세요'; };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(all).then(done, fallback); else fallback();
  },
};
$('mailto').addEventListener('input', () => { settings.mailTo = ($('mailto').value || '').trim(); store('yard07.settings', settings); SaveMail.refresh(); });
for (const id of ['mailbtn', 'gmailbtn']) $(id).addEventListener('click', () => { SaveMail.refresh(); $('dlgmsg').textContent = id === 'mailbtn' ? '메일 앱을 엽니다 · 열리지 않으면 Gmail이나 메일 내용 복사를 써 주세요' : 'Gmail 쓰기 창을 엽니다'; });
$('mailcopy').addEventListener('click', () => SaveMail.copy());
const Dialog = {
  mode: null,
  open(mode) {
    this.mode = mode; showOnly('dlg'); $('dlgmsg').textContent = '';
    const code = $('codebox'), inp = $('codein'), ok = $('dlgok');
    code.hidden = mode !== 'save'; inp.hidden = mode !== 'load' && mode !== 'dev'; ok.classList.toggle('danger', mode === 'reset');
    $('mailrow').hidden = mode !== 'save'; if (mode === 'save') { $('mailto').value = settings.mailTo || ''; }
    inp.type = mode === 'dev' ? 'password' : 'text'; inp.inputMode = mode === 'dev' ? 'numeric' : 'text';
    if (mode === 'save') {
      $('dlghead').textContent = '진행 상황 저장'; $('dlgtitle').textContent = '저장 코드';
      $('dlgtext').textContent = '이 코드를 적어 두거나 복사해 두세요. 처음 화면의 불러오기에 넣으면 지금의 돈, 열린 스테이지, 깬 스테이지, 최단 기록, 무기 편성, 가진 총, 아이템과 상아로 돌아갑니다. 대여 중인 무기는 코드에 들어가지 않습니다.';
      code.textContent = SaveCode.encode(); ok.textContent = '코드 복사'; $('dlgcancel').textContent = '닫기'; SaveMail.refresh();
    } else if (mode === 'load') {
      $('dlghead').textContent = '진행 상황 불러오기'; $('dlgtitle').textContent = '불러오기';
      $('dlgtext').textContent = '저장할 때 받은 코드를 넣으세요. 지금 진행 상황은 코드의 내용으로 바뀌고, 대여 중인 무기는 반납됩니다(대여료는 돌려받지 않습니다).';
      inp.value = ''; ok.textContent = '불러오기'; $('dlgcancel').textContent = '취소'; inp.placeholder = 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXX';
    } else if (mode === 'dev') {
      $('dlghead').textContent = '개발자 모드'; $('dlgtitle').textContent = '비밀번호';
      $('dlgtext').textContent = '개발자 모드를 켜려면 비밀번호를 넣으세요. 켜면 모든 스테이지와 모든 총, 아이템을 무료로 쓸 수 있습니다.';
      inp.value = ''; inp.placeholder = '비밀번호'; ok.textContent = '켜기'; $('dlgcancel').textContent = '취소';
    } else {
      $('dlghead').textContent = '진행 상황 초기화'; $('dlgtitle').textContent = '모두 지울까요?';
      $('dlgtext').textContent = '돈, 열린 스테이지, 깬 기록, 최단 기록, 무기 편성, 대여 중인 무기, 가진 총, 아이템과 상아를 모두 지우고 처음 상태로 돌아갑니다. 되돌릴 수 없으니 필요하면 먼저 저장 코드를 받아 두세요. 설정(감도, 음량, 그래픽, 개발자 모드)은 그대로입니다.';
      ok.textContent = '초기화'; $('dlgcancel').textContent = '취소';
    }
    setTimeout(() => (mode === 'load' || mode === 'dev' ? inp : $('dlgcancel')).focus(), 0);
  },
  close() { $('dlg').hidden = true; backTo('menu'); },
  ok() {
    if (this.mode === 'save') {
      const text = $('codebox').textContent, done = () => { $('dlgmsg').textContent = '복사했습니다'; };
      const fallback = () => { const r = document.createRange(); r.selectNodeContents($('codebox')); const s = getSelection(); s.removeAllRanges(); s.addRange(r);
        try { if (document.execCommand('copy')) { done(); return; } } catch (e) {} $('dlgmsg').textContent = '코드를 길게 눌러 직접 복사해 주세요'; };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
    } else if (this.mode === 'dev') {
      // only a hash of the password lives in the game, not the password itself
      if (devHash($('codein').value.trim()) !== 0x87114c2b) { $('dlgmsg').textContent = '비밀번호가 틀렸습니다'; $('codein').select(); Sound.empty(); return; }
      this.close(); setDev(true);
    } else if (this.mode === 'load') {
      const d = SaveCode.decode($('codein').value);
      if (!d) { $('dlgmsg').textContent = '코드가 맞지 않습니다. 글자를 다시 확인해 주세요.'; return; }
      Object.keys(save).forEach((k) => delete save[k]); Object.assign(save, d); fixSave(); moneyLock = null; ivoryLock = null; ownLock = null; persist(); Sound.buy();
      const done = STAGE_ORDER.filter((s) => save.cleared.includes(s)).map(stageTag);
      this.close(); $('menumsg').textContent = '불러왔습니다 · 가방 ' + won(save.money) + ' · 깬 스테이지 ' + (done.length ? done.join(', ') : '없음');
    } else {
      Object.keys(save).forEach((k) => delete save[k]); Object.assign(save, SAVE0()); fixSave(); moneyLock = null; ivoryLock = null; ownLock = null; persist(); Sound.reload(0);
      this.close(); $('menumsg').textContent = '모든 진행 상황을 지웠습니다';
    }
  },
};
function devHash(t) { let h = 0x811c9dc5; const s = 'yard07-dev:' + t; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h >>> 0; }
function setDev(on) {
  settings.dev = !!on; store('yard07.settings', settings);
  $('menumsg').textContent = on ? '개발자 모드 · 모든 스테이지와 모든 총을 쓸 수 있습니다' : '개발자 모드를 껐습니다';
  refreshMenu();
}
$('savebtn').addEventListener('click', () => Dialog.open('save'));
$('loadbtn').addEventListener('click', () => Dialog.open('load'));
$('resetbtn').addEventListener('click', () => Dialog.open('reset'));
$('devbtn').addEventListener('click', () => (settings.dev ? setDev(false) : Dialog.open('dev')));
/* 5.14: developer mode's invincibility: no damage and no deaths of any kind (laser, slam, infection, poison, bleeding) */
const godMode = () => !!(settings.dev && settings.god);
function godButtons() {
  for (const id of ['godbtn', 'pgodbtn']) { const b = $(id); b.hidden = !settings.dev; b.textContent = settings.god ? '무적 켜짐' : '무적 꺼짐'; b.classList.toggle('on', !!settings.god); }
  $('godtag').hidden = !godMode();
}
for (const id of ['godbtn', 'pgodbtn']) $(id).addEventListener('click', () => { settings.god = !settings.god; store('yard07.settings', settings); godButtons(); });
$('dlgok').addEventListener('click', () => Dialog.ok());
$('dlgcancel').addEventListener('click', () => Dialog.close());
$('codein').addEventListener('keydown', (e) => { if (e.key === 'Enter') Dialog.ok(); });
$('lobtn').addEventListener('click', () => Loadout.open('menu'));
$('cubtn').addEventListener('click', () => Custom.open('menu'));
$('locustom').addEventListener('click', () => { if (state === 'menu' || state === 'brief') { $('loadout').hidden = true; Custom.open('loadout'); } });
$('loclose').addEventListener('click', () => Loadout.close());
$('lorent').addEventListener('click', () => Shop.open('loadout'));
/* ============ the encyclopaedias (5.12): the gun book (rate, damage, dps, magazine, range...) and the enemy book
   (name, health, speed, traits, what it carries, damage, skills). the numbers are read from the same tables the game runs on
   wherever there is a table; the rest (kit damage, skills) is written out by hand from the fighting code ============ */
const Codex = (() => {
  const n = (x) => Math.round(x).toLocaleString('ko-KR');
  const f1 = (x) => String(Math.round(x * 10) / 10);
  const ms = (x) => f1(x) + ' m/s';
  const el = (tag, cls, text) => { const d = document.createElement(tag); if (cls) d.className = cls; if (text !== undefined) d.textContent = text; return d; };
  const BLEED = '출혈 (초당 ' + BLEED_DPS + ', 10초, 상처마다 쌓임)';
  const beast = (t, mul) => n(ANIMALS[t].dmg * BEAST_DMG * (mul || 1)); // the animals hit half as hard as their table says

  /* ---------- guns ---------- */
  function guns() {
    const list = ORDER.map((id) => {
      const w = WEAPONS[id], shot = w.dmg * w.pellets, rpm = 60 / w.rate;
      // a one-round magazine reloads between every shot, so its "rate" is really shot + reload
      const dps = w.mag > 1 ? shot / w.rate : shot / (w.rate + w.reload);
      const sus = (w.mag * shot) / (w.mag * w.rate + w.reload);
      return { id, w, shot, rpm, dps, sus };
    });
    const top = { rpm: 0, shot: 0, dps: 0, range: 0 };
    for (const g of list) { top.rpm = Math.max(top.rpm, g.rpm); top.shot = Math.max(top.shot, g.shot); top.dps = Math.max(top.dps, g.dps); top.range = Math.max(top.range, g.w.range); }
    return list.map(({ id, w, shot, rpm, dps, sus }) => {
      const free = id === 'pistol', owned = save.owned.includes(id);
      const price = free ? '무료 · 총알 무한' : (owned ? '영구 소유' : '대여 ' + won(w.rent)) + ' · ' + (w.rocket ? '로켓 1발 ' : '총알 100발 ') + won(AMMO100[id]);
      const dmg = w.pellets > 1 ? w.dmg + ' × ' + w.pellets + '발 = ' + n(shot)
        : w.rocket ? '직격 ' + n(w.dmg) + ' · 폭발 최대 ' + n(w.splashDmg) + ' (반경 ' + w.splash + ' m)'
          : w.grenade ? '폭발 ' + n(w.dmg) + ' (반경 ' + w.splash + ' m, 멀수록 약함)' : n(w.dmg);
      const move = w.moveMul === 1 ? '100%' : Math.round(w.moveMul * 100) + '% (' + (w.moveMul > 1 ? '+' : '') + Math.round((w.moveMul - 1) * 100) + '%)';
      return {
        name: w.name, sub: w.model + ' · ' + w.cls, tag: price, cls: owned ? 'own' : '',
        rows: [
          ['연사속도', n(rpm) + '발/분 · ' + (w.auto ? '자동' : '단발'), rpm / top.rpm],
          ['데미지', dmg + (w.head > 1 ? ' · 머리 ×' + w.head : ''), Math.sqrt(shot / top.shot)],
          ['DPS', n(dps) + ' · 재장전 포함 ' + n(sus), Math.sqrt(dps / top.dps)],
          ['탄창', n(w.mag) + '발 · 예비 ' + (w.reserve === Infinity ? '무한' : n(w.reserve) + '발') + (w.rocket ? ' (최대 ' + (w.mag + w.reserve) + '발)' : '')],
          ['재장전', f1(w.reload) + '초'],
          ['사거리', w.range + ' m' + (w.falloff ? ' · ' + w.falloff[0] + '~' + w.falloff[1] + ' m에서 35%까지 약해짐' : ''), w.range / top.range],
          ['이동속도', move],
        ].concat(w.parts && (w.parts.sight !== 'iron' || w.parts.muzzle !== 'none' || w.parts.under !== 'none' || w.parts.paint !== 'base')
          ? [['부속', SLOTS.map((k) => partOf(k, w.parts[k])).filter((p) => p.id !== 'iron' && p.id !== 'none').map((p) => p.name).concat(w.parts.paint !== 'base' ? [(PAINTS.find((q) => q.id === w.parts.paint) || {}).name + ' 도색'] : []).join(' · ') + ' (수치에 반영됨)']] : []),
        note: w.note || '',
      };
    }).concat([{
      name: '근접 공격', sub: 'PC 전용 · V 키 또는 마우스 뒤로 버튼', tag: '무료', cls: '',
      rows: [['데미지', MELEE_DMG + ' · 머리 ×2'], ['공격 시간', f1(MELEE_T) + '초'], ['사거리', MELEE_REACH + ' m'], ['이동속도', '100%']],
      note: '총을 든 채로 바로 휘두릅니다. 나무 상자도 부술 수 있습니다.',
    }]);
  }

  /* ---------- enemies ---------- */
  function foes() {
    const T = ETYPES.thug, Z = ETYPES.zombie, A = ANIMALS, R = ROBOTS, KB = KONG.boss, KM = KONG.minion, SG = SAFARI_GORILLA;
    const B1 = BOSS[1], B5 = BOSS[5], B2 = BOSS[2], B3 = BOSS[3], B4 = BOSS[4];
    const thug = ms(T.speed), slow = ms(T.speed * 0.9);
    const LAB = ['3', '3-2'], ALL3 = ['3', '3-1', '3-2'];
    const siege = (t) => (SIEGE[t] ? ' · 3-1에서 감시탑 공격 ' + SIEGE[t].dmg : '');
    const animal = (t, st, o) => {
      const a = A[t];
      return Object.assign({ st, name: a.name, hp: n(a.hp), speed: '걷기 ' + ms(a.speed) + ' · 달리기 ' + ms(a.run), arms: '없음', pay: a.money }, o);
    };
    const bot = (t, o) => Object.assign({ st: ['4'], name: R[t].name, hp: n(R[t].hp), pay: R[t].money }, o);
    const shot = (S) => '한 발 ' + S[3] + ' · ' + (S[0] === S[1] ? S[0] : S[0] + '~' + S[1]) + '발씩, ' + S[4] + '~' + S[5] + '초마다';
    return [
      // stage 1 and 1-1: men with pistols
      { st: ['1'], name: T.name, hp: n(T.hp), speed: thug, arms: '권총', dmg: '한 발 9 · 1~3발씩 끊어 쏨', trait: '부두 곳곳에 미리 자리 잡고 있음 · 보거나 총소리를 들으면 공격', skill: '없음', pay: 1000 },
      { st: ['1'], boss: 1, name: B1.name, hp: n(B1.hp), speed: slow, arms: '권총', dmg: '한 발 ' + n(9 * B1.dmgMul) + ' · 4발 연사, 쉬는 시간이 짧음', trait: '보스 · 크고 단단함 · 처치하면 보물상자 (총을 영구 소유)', skill: '4연발 사격', pay: 20000 },
      { st: ['1-1'], name: '헬멧 ' + T.name, hp: n(T.hp), speed: thug, arms: '권총 · 오토바이 헬멧', dmg: '한 발 9 · 1~3발씩', trait: '검은 풀페이스 헬멧이 첫 헤드샷을 한 번 막고 벗겨짐', skill: '없음', pay: 1000 },
      { st: ['1-1'], boss: 1, name: BOSS[6].name, hp: n(BOSS[6].hp), speed: slow, arms: '권총 · 오토바이 헬멧', dmg: '한 발 ' + n(9 * BOSS[6].dmgMul) + ' · 4발 연사', trait: '보스 · 헬멧이 첫 헤드샷을 막음 · 보물상자', skill: '4연발 사격', pay: 20000 },
      // stage 1-2: ten kits and the machine-gun boss
      { st: ['1-2'], name: '저격수', hp: n(T.hp), speed: '제자리 (컨테이너 위)', arms: '저격총', dmg: '한 발 140 · 머리를 노림', trait: '가운데 높은 컨테이너 위에 5명', skill: '빨간 레이저로 1.3초 조준한 뒤 사격', pay: 1000 },
      { st: ['1-2'], name: '황금 ' + KITS.deagle.name, hp: n(T.hp), speed: thug, arms: '황금 데저트 이글', dmg: '한 발 45 · 정확함', trait: '9명 · 한 발씩 묵직하게', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.bomber.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.bomber.run), arms: '폭탄 조끼', dmg: '폭발 300 (반경 7 m, 멀수록 약함) · 주변 적도 휘말림', trait: '10명 · 조끼를 쏘면 그 자리에서 터짐 · 스스로 터지면 돈 없음', skill: '가까이 오면 팔을 들고 0.6초 뒤 자폭', pay: 1000 },
      { st: ['1-2'], name: KITS.flame.name, hp: n(T.hp), speed: thug, arms: '화염방사기', dmg: '초당 75 (9.5 m 원뿔) · 방탄조끼로 못 막음', trait: '3명', skill: '1.6~2.4초씩 불을 뿜음', pay: 1000 },
      { st: ['1-2'], name: KITS.rifle.name, hp: n(T.hp), speed: thug, arms: '돌격소총', dmg: '한 발 11 · 3~5발 점사', trait: '12명 · 8~22 m 거리를 유지', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.dagger.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.dagger.run), arms: '단검', dmg: '찌르기 70 · 초당 약 2번', trait: '20명 · 곧장 달려듦', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.saber.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.saber.run), arms: '파란 광선검', dmg: '내려베기 300 · 1.25초마다', trait: '10명', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.saber2.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.saber2.run), arms: '광선검 두 자루', dmg: '내려베기 300 · 양손 번갈아 0.62초마다', trait: '5명', skill: '없음', pay: 1000 },
      { st: ['1-2'], name: KITS.nade.name + '병', hp: n(T.hp), speed: thug, arms: '수류탄', dmg: '폭발 100 (반경 5.5 m)', trait: '10명 · 9~20 m 거리를 유지', skill: '삑삑 소리가 나는 수류탄을 2.4~3.6초마다 던짐', pay: 1000 },
      { st: ['1-2'], name: KITS.bat.name, hp: n(T.hp), speed: '달리기 ' + ms(KITS.bat.run), arms: '알루미늄 방망이', dmg: '머리 높이 휘두르기 150 + 밀쳐냄', trait: '15명', skill: '없음', pay: 1000 },
      { st: ['1-2'], boss: 1, name: B5.name, hp: n(B5.hp), speed: slow, arms: '기관총', dmg: '한 발 10 · 12~18발 연사', trait: '보스 · 처치하면 보물상자', skill: '긴 연사', pay: 20000 },
      // stage 2: zombies (no health there: a bite infects, a dash poisons)
      { st: ['2'], name: Z.name, hp: n(Z.hp), speed: '1.3~2.0 m/s · 돌진 8.5 m/s', arms: '없음', dmg: '스테이지 2는 체력 대신 · 물리면 감염 (5초 안에 해독약)', trait: '쓰러져도 3초 안에 한 번 더 쏘지 않으면 다시 일어남 · 일어나기 전에 처치하면 돈 1.5배', skill: '체력 30% 이하에서 한 번 돌진 · 맞으면 중독 (8초 안에 해독약)', pay: 1000 },
      { st: ['2'], boss: 1, name: B2.name, hp: n(B2.hp), speed: '1.7 m/s · 폭주 ×1.9 · 돌진 13 m/s', arms: '없음', dmg: '물리면 감염 · 돌진에 맞으면 2초 기절', trait: '보스 · 보물상자', skill: '체력 절반에서 폭주 (빨갛게 변하고 빨라짐) · 5~8초마다 돌진', pay: 20000 },
      // stage 3, 3-1 and 3-2: animals
      animal('zebra', ALL3, { dmg: '없음', trait: '싸우지 않음 · 맞으면 옆 얼룩말과 함께 지그재그로 달아남 · 3-1에서는 감시탑 둘레를 맴돌며 방해', skill: '바닥에서 바로 올라탈 수 있음 (탈것 1단계)' }),
      animal('buffalo', ALL3, { dmg: '들이받기 ' + beast('buffalo') + ' + 3초 기절 + ' + BLEED, trait: '무리 지어 다님' + siege('buffalo'), skill: '발을 구른 뒤 일직선 돌진 · 비스듬한 벽은 타고 미끄러짐' }),
      animal('hippo', ALL3, { dmg: '물기 ' + beast('hippo') + ' + ' + BLEED, trait: '가까이 가면 덤빔' + siege('hippo'), skill: '입을 크게 벌렸다가 꽉 다묾' }),
      animal('rhino', ALL3, { dmg: '떨어질 때 ' + n(100 * BEAST_DMG) + ' + ' + BLEED + ' · 탈것 위면 탈것이 뿔 ' + beast('rhino'), trait: '가까이 가면 덤빔' + siege('rhino'), skill: '돌진 끝에 뿔로 하늘 높이 띄움 · 떨어질 때 또 받히면 더 높이 · 떨어지며 동물을 덮치면 그 동물 최대 체력의 30%' }),
      animal('cheetah', ALL3, { dmg: '스치며 물기 ' + beast('cheetah') + ' + ' + BLEED, trait: '가장 빠른 동물' + siege('cheetah'), skill: '바로 옆을 스치는 직선 질주 중에 물고 지나감' }),
      animal('tiger', ALL3, { dmg: '스치며 물기 ' + beast('tiger') + ' + ' + BLEED, trait: '치타처럼 사냥' + siege('tiger'), skill: '포효: 1초 동안 저절로 도망침 (기린·코끼리 위에서는 버팀)' }),
      animal('lionM', ALL3, { dmg: '물기 ' + beast('lionM') + ' + ' + BLEED, trait: '갈기가 있는 숫사자' + siege('lionM'), skill: '왕의 포효: 호랑이 빼고 모든 동물이 무릎 꿇고 체력 1/3 회복, 포효마다 10%씩 빨라짐 (최대 1.5배)' }),
      animal('giraffe', ALL3, { dmg: '목 휘두르기 ' + beast('giraffe') + ' + ' + BLEED, trait: '머리를 맞히면 데미지 ' + A.giraffe.headX + '배 · 3-1에서는 감시탑 위의 나를 노림', skill: '긴 목을 곤봉처럼 내려침 (감시탑 난간 위까지 닿음) · 길들이면 얼룩말 위에서 올라탈 수 있음 (2단계)' }),
      animal('elephant', ALL3, { dmg: '엄니 ' + beast('elephant') + ' · 돌진 ' + beast('elephant', 1.2) + ' + ' + BLEED, trait: '처치하면 상아 (상점에서 ' + won(IVORY_PRICE) + ')' + siege('elephant'), skill: '돌진 · 나무 상자를 부수며 지나감 · 기린 위에서 올라탈 수 있음 (3단계)' }),
      { st: ['3-1'], name: SG.name, hp: n(SG.hp), speed: '달리기 ' + ms(KM.run) + ' · 돌진 ' + ms(KM.charge), arms: '없음', dmg: '주먹 ' + n(KM.punch * SG.dmgMul) + ' · 돌진 ' + n(KM.chargeDmg * SG.dmgMul) + ' + ' + KM.stun + '초 기절 + ' + BLEED, trait: '6마리 · 평소엔 어슬렁거리다가 가까이 가거나 총소리를 듣거나 맞으면 덤빔 · 감시탑 공격 ' + SIEGE.gorilla.dmg, skill: '번갈아 휘두르는 주먹 · 느린 돌진', pay: A.gorilla.money },
      { st: LAB, name: '고릴라 졸개', hp: n(B3.hp / 4), speed: '달리기 ' + ms(KM.run) + ' · 돌진 ' + ms(KM.charge), arms: '없음', dmg: '주먹 ' + n(KM.punch) + ' · 돌진 ' + n(KM.chargeDmg) + ' + ' + KM.stun + '초 기절 + ' + BLEED, trait: '보스가 가슴을 두드리면 ' + KONG.minionsAt + '마리가 위에서 떨어짐 · 보스 체력의 1/4', skill: '주먹 · 느린 돌진 (회복이 김) · 점프는 안 함', pay: 1000 },
      { st: LAB, boss: 1, name: B3.name, hp: n(B3.hp), speed: '달리기 ' + ms(KB.run) + ' · 돌진 ' + ms(KB.charge), arms: '없음', dmg: '주먹 ' + n(KB.punch) + ' · 돌진 ' + n(KB.chargeDmg) + ' + ' + KB.stun + '초 기절 · 내려찍기 즉사 · 출혈 없음', trait: '보스 · 방탄유리 우리 (3: 9번 우리가 열리고 15초 뒤 · 3-2: 마지막 차례)', skill: '번갈아 훅 · 잦은 돌진 · 내가 선 자리로 큰 점프 (빨간 원 ' + KONG.slamR + ' m 안이면 즉사) · 가슴 치기로 졸개 소환 (최대 ' + KONG.summonMax + '번)', pay: A.gorilla.money * 20 },
      // stage 4: the ship's crew
      bot('cctv', { speed: '고정 (천장)', arms: '볼트 포', dmg: shot(R.cctv.shot), trait: '통로와 복도 천장 모서리 · 시야 ' + R.cctv.sight + ' m', skill: '없음' }),
      bot('patrol', { speed: ms(R.patrol.speed), arms: '전기 곤봉', dmg: '곤봉 ' + R.patrol.dmg + ' + 밀쳐냄', trait: '복도 12대, 메인홀 8대 (메인홀 문이 열려야 깨어남) · 정해진 길을 왕복 순찰 · 머리가 약점', skill: '없음' }),
      bot('droneA', { name: '드론 A', speed: ms(R.droneA.speed), arms: '볼트 포', dmg: shot(R.droneA.shot), trait: '복도에 많음 · 메인홀엔 없음 · 총 한 방에 터짐', skill: '없음' }),
      bot('mine', { speed: '튀어나오면 ' + ms(R.mine.speed), arms: '폭약', dmg: '폭발 ' + R.mine.dmg + ' (반경 3.5 m) · 옆 마인도 연쇄 폭발', trait: '복도와 메인홀 바닥에 묻혀 있음', skill: R.mine.sight + ' m 안에 오면 튀어나와 달려들어 터짐' }),
      bot('gdrone', { boss: 2, name: R.gdrone.name, speed: ms(R.gdrone.speed) + ' · 돌진 22 m/s', arms: '쌍포', dmg: shot(R.gdrone.shot) + ' · 돌진 160 + 크게 밀쳐냄', trait: '중간보스 · 운전실에 혼자 · 황금 꿀벌 모양 · 운전실 문이 열린 뒤에야 나를 알아챔 (들어가면 문이 잠김) · 경보로 75 m 안의 로봇을 깨움 · 체력 40% 이하에서 분노 · 쓰러지면 문이 열리고 세이브 포인트', skill: '드론 A 4~5대 소환 (동시에 최대 12대, 소환된 드론도 처치 수에 들어감) · 날갯짓 후 돌진', pay: R.gdrone.money * 10 }),
      { st: ['4'], boss: 1, name: B4.name, hp: n(B4.hp) + ' (3페이즈)', speed: BPH.map((p) => p.sp).join(' → ') + ' m/s', arms: '레이저 · 유도 로켓 · 스파이더 마인', dmg: '레이저 닿으면 즉사 · 로켓 100 (반경 3 m) · 마인 ' + R.mine.dmg, trait: '보스 · 메인홀 (운전실 조종석의 열쇠가 있어야 문이 열리고, 들어가면 잠김) · 문이 열린 뒤에야 나를 알아챔 · 체력 1/3마다 껍데기가 벗겨지며 작고 빨라짐', skill: '레이저 (조준 ' + BPH.map((p) => p.charge).join('/') + '초) · 로켓 ' + BPH.map((p) => p.rockets).join('/') + '발 · 마인 ' + BPH.map((p) => p.mines).join('/') + '개를 자기 아래로 떨굼 · 3페이즈에 해치 ' + HATCHES.length + '곳에서 드론 32대 출격 (처치 수와 돈에 안 들어가고 보스가 죽으면 사라짐)', pay: R.bdrone.money * 20 },
    ];
  }

  const TAGNUM = {}; for (const k in STAGE_TAG) TAGNUM[STAGE_TAG[k]] = +k;
  const seen = (tags) => !!settings.dev || tags.some((t) => save.cleared.includes(TAGNUM[t]));
  const CHIPS = [['all', '전체'], ['1', '1'], ['1-1', '1-1'], ['1-2', '1-2'], ['2', '2'], ['3', '3'], ['3-1', '3-1'], ['3-2', '3-2'], ['4', '4']];
  function card(c, stage) {
    if (c.locked) {
      const a = el('article', 'cxcard locked'), top = el('div', 'cxtop'); top.append(el('b', null, '???'));
      const tags = el('span', 'cxtags'); for (const s of c.st) tags.append(el('span', 'cxst', s)); top.append(tags); a.append(top);
      a.append(el('p', 'cxnote', '스테이지 ' + c.st.join(' · ') + (c.st.length > 1 ? ' 중 하나를' : eul(c.st[0])) + ' 깨면 열립니다'));
      return a;
    }
    const a = el('article', 'cxcard' + (c.cls ? ' ' + c.cls : '') + (c.boss === 1 ? ' boss' : c.boss === 2 ? ' mid' : ''));
    const top = el('div', 'cxtop'); top.append(el('b', null, c.name));
    const tags = el('span', 'cxtags');
    if (c.boss) tags.append(el('em', 'cxbadge', c.boss === 1 ? '보스' : '중간보스'));
    if (stage) for (const s of c.st) tags.append(el('span', 'cxst', s));
    top.append(tags); a.append(top);
    if (c.sub) a.append(el('div', 'cxsub', c.sub));
    if (c.tag) a.append(el('div', 'cxprice', c.tag));
    const dl = el('dl', 'cxstats');
    for (const [k, v, bar] of c.rows) {
      dl.append(el('dt', null, k)); const dd = el('dd', null, v);
      if (bar !== undefined) { const i = el('i', 'cxbar'), b = el('b'); b.style.width = Math.round(clamp(bar, 0.03, 1) * 100) + '%'; i.append(b); dd.append(i); }
      dl.append(dd);
    }
    a.append(dl);
    if (c.note) a.append(el('p', 'cxnote', c.note));
    return a;
  }
  const C = {
    from: 'menu', tab: 'gun', st: 'all',
    /* the book opens with your first clear (always in developer mode) */
    get ready() { return !!settings.dev || save.cleared.length > 0; },
    open(from) { if (!this.ready) return; this.from = from; showOnly('codex'); this.render(); $('codex').scrollTop = 0; setTimeout(() => $(this.tab === 'gun' ? 'cxtabg' : 'cxtabe').focus({ preventScroll: true }), 0); },
    close() { $('codex').hidden = true; backTo(this.from); },
    show(tab) { this.tab = tab; this.render(); },
    render() {
      const gun = this.tab === 'gun';
      $('cxtabg').setAttribute('aria-selected', gun ? 'true' : 'false'); $('cxtabe').setAttribute('aria-selected', gun ? 'false' : 'true');
      const chips = $('cxchips'); chips.textContent = ''; chips.hidden = gun;
      if (!gun) for (const [k, label] of CHIPS) {
        const b = el('button', k === this.st ? 'on' : '', k === 'all' ? label : '스테이지 ' + label); b.type = 'button'; b.setAttribute('aria-pressed', k === this.st ? 'true' : 'false');
        b.addEventListener('click', () => { this.st = k; this.render(); }); chips.append(b);
      }
      const list = $('cxlist'); list.textContent = '';
      if (gun) { const every = foes(); $('cxtabe').textContent = '적 도감 ' + every.filter((e) => seen(e.st)).length + '/' + every.length; for (const g of guns()) list.append(card(g, false)); $('cxinfo').textContent = 'DPS는 탄창을 쏘는 동안의 초당 데미지, 재장전 포함은 탄창 하나를 쏘고 다시 넣기까지 평균입니다. 막대는 무기끼리 비교한 값입니다.'; return; }
      const every = foes(), open = every.filter((e) => seen(e.st)).length;
      $('cxtabe').textContent = '적 도감 ' + open + '/' + every.length;
      const all = every.filter((e) => this.st === 'all' || e.st.includes(this.st));
      for (const e of all) {
        if (!seen(e.st)) { list.append(card({ locked: true, st: e.st }, true)); continue; }
        const rows = [['체력', e.hp], ['이동속도', e.speed], ['무장', e.arms], ['데미지', e.dmg], ['특징', e.trait], ['스킬', e.skill]];
        if (e.pay) rows.push(['처치 보상', won(e.pay)]);
        list.append(card({ name: e.name, st: e.st, boss: e.boss, rows }, true));
      }
      $('cxinfo').textContent = '동물 데미지는 절반으로 줄어든 실제 값입니다 (보스 고릴라와 졸개는 그대로). 탈것 위에서는 동물의 공격을 탈것이 대신 맞습니다. 처치 보상은 기본값이고, 머리로 잡으면 1.5배, 이미 깬 스테이지는 0원입니다.';
    },
  };
  return C;
})();
$('cxbtn').addEventListener('click', () => Codex.open('menu'));
$('pcxbtn').addEventListener('click', () => Codex.open('pause'));
/* the buttons say when the book is still shut */
function codexButtons() { const r = Codex.ready; for (const id of ['cxbtn', 'pcxbtn']) { const b = $(id); b.disabled = !r; b.textContent = r ? '도감' : '도감 · 첫 클리어 후'; } }
$('cxclose').addEventListener('click', () => Codex.close());
$('cxtabg').addEventListener('click', () => Codex.show('gun'));
$('cxtabe').addEventListener('click', () => Codex.show('foe'));

/* ============ game flow: stages, money, infection, shop, screens ============ */
const STAGES = {
  1: { name: '컨테이너 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '밀수 조직원 100명 · 총소리를 들으면 몰려옵니다' },
  6: { name: '헬멧 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '오토바이 헬멧 쓴 조직원 100명 · 헬멧은 머리를 한 번 맞히면 벗겨집니다' },
  5: { name: '무장 부두', enemy: 'thug', goal: 100, unit: '명', label: '조직원', intro: '단검 20 · 파란 광선검 10 · 쌍광선검 5 · 야구방망이 15 · 자폭맨 10 · 저격 5 · 보스는 기관총' },
  4: { name: '우주선', enemy: 'robot', goal: 100, unit: '대', label: '로봇', intro: '에어록 → 통로 → 160 m 복도의 드론 떼 · 서쪽 2층 운전실에 황금 꿀벌 드론 · 동쪽 거대한 메인홀(가운데 12 m 역피라미드 계단)에 3페이즈 보스 드론 · 바닥의 스파이더 마인 조심' },
  2: { name: '불타는 마을', enemy: 'zombie', goal: 100, unit: '마리', label: '좀비', intro: '좀비 100마리 · 체력은 없고 감염과 중독뿐 · 해독약은 나무 상자에서' },
  7: { name: '사파리 감시탑', enemy: 'animal', goal: 100, unit: '마리', label: '동물', intro: '넓은 사파리의 동물 100마리 · 5분 뒤 모두 가운데 감시탑으로 습격 · 탑 체력 10,000 · 기린은 긴 목으로 탑 위까지 칩니다' },
  8: { name: '차례 연구소', enemy: 'animal', goal: 90, unit: '마리', label: '동물', intro: '우리 10개를 하나씩 · 앞 우리의 동물을 다 잡아야 원숭이 박사가 다음 우리를 엽니다 · 모든 우리가 방탄유리 · 마지막은 거대 고릴라' },
  3: { name: '동물 연구소', enemy: 'animal', goal: 90, unit: '마리', label: '동물', intro: '우리 10개 · 10초 뒤 첫 우리가 열리고 15초마다 하나씩 · 얼룩말 → 기린 → 코끼리 순서로 올라탈 수 있음 · 보스 고릴라는 방탄유리 우리에' },
};
function pickWeighted(list) { let t = 0; for (const [, w] of list) t += w; let x = Math.random() * t; for (const [k, w] of list) { x -= w; if (x <= 0) return k; } return list[0][0]; }
const BOSS = {
  1: { type: 'thug', name: '조직 두목', josa: '이', scale: 1.35, hp: 1600, dmgMul: 1.6 },
  6: { type: 'thug', name: '헬멧 두목', josa: '이', scale: 1.35, hp: 1600, dmgMul: 1.6, helmet: true },
  5: { type: 'thug', name: '무장 두목', josa: '이', scale: 1.4, hp: 2600, dmgMul: 1, kit: 'lmg' },
  4: { type: 'bdrone', name: '최첨단 감시 드론 B-3', josa: '이', scale: 1, hp: 9000, dmgMul: 1 },
  2: { type: 'zombie', name: '거대 좀비', josa: '가', scale: 1.7, hp: 2200, dmgMul: 1 },
  3: { type: 'gorilla', name: '거대 로랜드고릴라', josa: '가', scale: 3, hp: 5200, dmgMul: 1, kong: true },
  8: { type: 'gorilla', name: '거대 로랜드고릴라', josa: '가', scale: 3, hp: 5200, dmgMul: 1, kong: true },
};
/* money for one kill of a kind: animals and robots carry their own price, people and zombies 1,000 */
function unitPay(type) { return ANIMALS[type] ? ANIMALS[type].money : typeof ROBOTS !== 'undefined' && ROBOTS[type] ? ROBOTS[type].money : 1000; }
const Game = {
  stage: 1, goal: 100, kills: 0, built: 0, info: null, spawnT: 0, infected: false, infectT: 0, antidotes: 0, ended: false, result: null,
  bonusGuns: [], deployed: false, replay: false,
  begin(stage) {
    this.stage = stage; const S = STAGES[stage];
    Enemies.clear(); Proj.clear(); Rockets.clear(); ShipFX.clear(); Loot.clear(); FX.clear(); HUD.reset(); Car.reset(); Kong.reset();
    this.info = buildStage(stage); this.built = stage; TacMap.build(stage, this.info);
    this.bonusGuns = []; this.deployed = false; this.replay = save.cleared.includes(stage);
    resetGuns();
    Object.assign(stats, { shots: 0, hits: 0, kills: 0, heads: 0, earned: 0, time: 0 });
    moneyLock = save.money; ivoryLock = save.items.ivory; ownLock = save.owned.slice();
    Object.assign(player, { hp: 1000, maxHp: 1000, yaw: this.info.start.yaw, pitch: 0, recoilPitch: 0, shake: 0, landDip: 0, grounded: true, sprintBlend: 0, invuln: 1.5, sinceHurt: 10 });
    player.pos.set(this.info.start.x, 0, this.info.start.z); player.vel.set(0, 0, 0);
    camera.fov = baseFov; camera.updateProjectionMatrix(); FX.resize();
    // 1-2 crowds the middle of the docks, so unless you pick somewhere else you come down at the south edge, facing in
    if (stage === 5) { const d = this.openSpot(0, 58); if (d) { this.info.start = d; player.pos.set(d.x, 0, d.z); player.yaw = d.yaw; } }
    this.goal = S.goal; this.kills = 0; this.spawnT = 2; this.infected = false; this.infectT = 0; this.ended = false; this.chestWait = false; this.chestOk = false; this.chestT = 0; this.sp = null;
    this.antidotes = stage === 2 ? 1 : 0; this.poisonT = 0; this.poisonAcc = 0; player.stunT = 0; Inject.cancel(); jetEnd(); HUD.items();
    this.calm = 0; Bleed.stop(true); Fear.t = 0; Toss.on = false; Toss.v = 0; Ride.reset(); Beast.reset();
    document.body.classList.toggle('s2', stage === 2);
    this.populate(stage);
    // 1-2 lets you choose where to be put down; the last choice is kept for another go (enemies stay where they always are)
    if (stage === 5 && this.dropPick) this.setDrop(this.dropPick);
    Gfx.stage(stage);
    const B = BOSS[stage], pay = B ? 20 * unitPay(B.type) : 0;
    this.bossMsg = B ? '보스 ' + B.name + B.josa + (Lab.active ? ' 10번 우리에 있습니다' : ' 어딘가에 있습니다') + (this.replay ? ' · 다시 하기라 보상은 없습니다' : ' · ' + won(pay))
      : '감시탑 체력 10,000 · 5분 뒤 모든 동물이 탑으로 몰려옵니다' + (this.replay ? ' · 다시 하기라 보상은 없습니다' : '');
    if (stage === 7) Safari.begin();
    updateFlow(player.pos.x, player.pos.z);
  },
  /* the nearest open ground to a point on the map: room to land, not on a container, inside the fence; you face the middle of the docks */
  pickDrop(x, z) {
    const d = this.openSpot(x, z); if (!d) return null;
    this.dropPick = d; this.setDrop(d); return d;
  },
  openSpot(x, z) {
    for (let rr = 0; rr <= 9; rr += 0.5) for (let i = 0, n = rr ? Math.max(8, Math.round(rr * 6)) : 1; i < n; i++) {
      const a = (i / n) * TAU, px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr;
      if (Math.abs(px) > HALF - 4 || Math.abs(pz) > HALF - 4 || collideAt(px, 0.05, pz, 1.1, 2) || groundAt(px, 0.3, pz, 0.5) > 0.1) continue;
      return { x: px, z: pz, yaw: Math.hypot(px, pz) > 3 ? Math.atan2(px, pz) : 0 };
    }
    return null;
  },
  setDrop(d) { this.info.start = { x: d.x, z: d.z, yaw: d.yaw }; player.pos.set(d.x, 0, d.z); player.yaw = d.yaw; player.pitch = 0; updateFlow(d.x, d.z); },
  /* every stage starts with exactly 100 enemies already in place, one of them the boss; nobody else ever shows up */
  populate(stage) {
    // the same stage always puts the same enemies in the same places
    const SR = mulberry(5150 + stage * 101), rand = (a, b) => a + SR() * (b - a), randi = (a, b) => Math.floor(rand(a, b + 1));
    const S = STAGES[stage], st = this.info.start, placed = [], B = BOSS[stage];
    const ok = (x, z, minStart, gap, rad) => {
      if (Math.abs(x) > HALF - 4 || Math.abs(z) > HALF - 4 || Math.hypot(x - st.x, z - st.z) < minStart || collideAt(x, 0, z, rad, 2)) return false;
      for (const p of placed) if (Math.hypot(p.x - x, p.z - z) < gap) return false;
      return true;
    };
    const find = (minStart, gap, rad, near, spread) => {
      for (let k = 0; k < 300; k++) {
        const x = near ? near.x + rand(-spread, spread) : rand(-HALF + 6, HALF - 6), z = near ? near.z + rand(-spread, spread) : rand(-HALF + 6, HALF - 6);
        if (ok(x, z, minStart, gap, rad)) { const p = { x, z }; placed.push(p); return p; }
      }
      return null;
    };
    let n = 0;
    const cap = stage === 3 || stage === 8 ? 140 : 100;
    const put = (type, p, opts) => { if (p && n < cap) { const e = Enemies.spawn(type, p.x, p.z, Object.assign({ yaw: rand(0, TAU), y: p.y || 0 }, opts)); if (e) e.sid = n; n++; return e; } return null; };
    if (B && stage !== 3 && stage !== 8 && stage !== 4 && stage !== 5) put(B.type, find(55, 8, 2.5) || find(30, 4, 1.5), Object.assign({ boss: true }, B));
    if (stage === 5) {
      // 1-2: 5 snipers up on container stacks, 9 gold desert eagles, 10 suicide bombers, 3 flamethrowers, 12 rifles, 20 knives, 10 blue lightsabers,
      // 5 with a lightsaber in each hand, 10 grenade throwers, 15 aluminium bats, and the boss with a machine gun: 100 in all.
      // 70 of them, the boss among them, are packed into the middle nine blocks of the 5 x 5 grid; the other 30 are spread round the outside
      const IN = (x, z) => Math.abs(x) < 36 && Math.abs(z) < 33;
      const findR = (inside, minStart, gap, rad, near, spread) => {
        for (let k = 0; k < 400; k++) {
          const x = near ? near.x + rand(-spread, spread) : inside ? rand(-35, 35) : rand(-HALF + 6, HALF - 6);
          const z = near ? near.z + rand(-spread, spread) : inside ? rand(-32, 32) : rand(-HALF + 6, HALF - 6);
          if (IN(x, z) !== inside || !ok(x, z, minStart, gap, rad)) continue;
          const p = { x, z }; placed.push(p); return p;
        }
        return null;
      };
      let inner = 0;
      if (put(B.type, findR(true, 20, 8, 2.5) || find(30, 4, 1.5), Object.assign({ boss: true }, B))) inner++;
      const kits = [], ROSTER = [['sniper', 5], ['deagle', 9], ['bomber', 10], ['flame', 3], ['rifle', 12], ['dagger', 20], ['saber', 10], ['saber2', 5], ['nade', 10], ['bat', 15]];
      for (const [k, c] of ROSTER) for (let i = 0; i < c; i++) kits.push(k);
      for (let i = kits.length - 1; i > 0; i--) { const j = Math.floor(SR() * (i + 1)); [kits[i], kits[j]] = [kits[j], kits[i]]; }
      // the snipers on stacks in the middle, looking out over the rest
      const tops = colliders.filter((b) => b.kind === 'metal' && b.maxy > 2 && b.maxy < 9 && (b.maxx - b.minx) * (b.maxz - b.minz) > 10 && IN((b.minx + b.maxx) / 2, (b.minz + b.maxz) / 2));
      const snipers = kits.filter((k) => k === 'sniper').length; let left = kits.filter((k) => k !== 'sniper');
      for (let i = 0; i < snipers; i++) {
        let spot = null;
        for (let k = 0; k < 40 && tops.length && !spot; k++) { const b = tops.splice(Math.floor(SR() * tops.length), 1)[0]; const q = { x: (b.minx + b.maxx) / 2, z: (b.minz + b.maxz) / 2, y: b.maxy };
          if (placed.every((o) => Math.hypot(o.x - q.x, o.z - q.z) > 6)) spot = q; }
        if (spot) { placed.push(spot); if (put('thug', spot, { kit: 'sniper' })) inner++; } else left.push('sniper');
      }
      // posts of 2-5 in the middle until it holds 70, then posts of 2-3 outside for the rest
      for (let guard = 0; inner < 70 && left.length && guard < 200; guard++) {
        const center = findR(true, 20, 4.5, 0.8); if (!center) break;
        if (put('thug', center, { kit: left.shift() })) inner++;
        for (let i = 1, grp = randi(2, 5); i < grp && left.length && inner < 70; i++) { if (put('thug', findR(true, 18, 1.6, 0.6, center, 5), { kit: left[0] })) { left.shift(); inner++; } }
      }
      for (let guard = 0; n < 100 && left.length && guard < 200; guard++) {
        const center = findR(false, 26, 5, 0.8); if (!center) break;
        put('thug', center, { kit: left.shift() });
        for (let i = 1, grp = randi(2, 3); i < grp && left.length; i++) { if (put('thug', findR(false, 24, 1.6, 0.6, center, 5), { kit: left[0] })) left.shift(); }
      }
    } else if (stage === 4) {
      populateShip(this, put, find, rand, randi, SR, placed);
    } else if (stage === 3 || stage === 8) {
      populateLab(this, put, SR);
    } else if (stage === 7) {
      populateSafari(this, put, find, rand, randi);
    } else {
      // guard posts of 2-4 people, or packs of 2-6 zombies
      const yard = isYard(stage), helmet = stage === 6;
      while (n < 100) {
        const center = find(yard ? 36 : 22, 5, 0.8); if (!center) break;
        put(S.enemy, center, { helmet });
        for (let i = 1, grp = yard ? randi(2, 4) : randi(2, 6); i < grp; i++) put(S.enemy, find(yard ? 33 : 20, 1.6, 0.6, center, 5), { helmet });
      }
    }
    if (stage !== 3 && stage !== 8 && stage !== 4 && stage !== 7) while (n < 100) { const p = find(18, 1.2, 0.6); if (!p) break; put(stage === 4 ? 'trooper' : S.enemy, p, { helmet: stage === 6, kit: stage === 5 ? 'rifle' : undefined }); }
    this.goal = Enemies.list.length; this.spawned = n;
    this.boss = Enemies.list.find((e) => e.boss) || null;
    this.mid = Enemies.list.find((e) => e.T && e.T.mid) || null; // the gold commander drone
  },
  update(dt) {
    if (this.ended) return;
    if (this.chestWait && !Loot.pending() && (this.chestT += dt) > 2.4) { this.chestWait = false; this.chestOk = true; this.finish(); return; } // opened: give its banner a moment, then out
    Lab.update(dt); Safari.update(dt); Bleed.update(dt); Beast.roarCd -= dt;
    // the countdown holds while the needle is in
    if (this.infected && !Inject.active) { this.infectT -= dt; if (this.infectT <= 0) { this.infectT = 0; this.over('zombie'); } }
    // poison counts down like a bite, and like a bite it holds while the needle is in
    if (this.poisonT > 0 && !Inject.active) { this.poisonT = Math.max(0, this.poisonT - dt); if (this.poisonT <= 0) this.over('poison'); }
  },
  /* a charge that connects knocks you out: the enraged zombie boss for 2 s, the giant gorilla for 3 s (300 damage), its minions for 1 s */
  stun(e, dmg, secs) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    secs = secs || 2;
    player.hurt(dmg === undefined ? 90 * (e.dmgMul || 1) : dmg, e.pos, 'body');
    if (this.ended) return;
    player.stunT = Math.max(player.stunT, secs); Gun.trigger = false; Gun.adsHeld = false; Gun.reloadT = 0;
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    player.vel.x += dx / d * 11; player.vel.z += dz / d * 11;
    player.shake = Math.max(player.shake, 0.6); Sound.ring(); buzz(220);
    HUD.feed('돌진에 맞아 기절 · ' + secs + '초', 0, 'hs');
  },
  /* the boss drone's laser: touching the beam is the end */
  laser(e) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    player.hp = 0; Sound.hurt(); HUD.hurt(999, e.pos); this.over('laser');
  },
  /* the giant gorilla's leap: coming down on you is the end */
  slam(e) {
    if (state !== 'playing' || this.ended || player.invuln > 0 || godMode()) return;
    player.hp = 0; Sound.hurt(); HUD.hurt(999, e.pos); this.over('slam');
  },
  /* stage 2 has no health: a zombie's dash poisons, and the poison kills in 8 seconds unless an antidote goes in, just like a bite */
  poison(e) {
    if (state !== 'playing' || this.ended || godMode()) return;
    Sound.bite(); buzz(120); HUD.hurt(30, e.pos); player.shake = Math.max(player.shake, 0.35);
    if (this.poisonT > 0) { this.poisonT = Math.max(0.6, this.poisonT - 1.5); HUD.feed('또 중독 · 남은 시간이 줄었습니다', 0, 'hs'); return; }
    this.poisonT = 8;
    HUD.feed('중독 · 8초 안에 해독약을 주사하세요', 0, 'hs');
  },
  cure() {
    const inf = this.infected, poi = this.poisonT > 0;
    this.infected = false; this.infectT = 0; this.poisonT = 0; this.poisonAcc = 0;
    HUD.feed('해독 완료 · ' + (inf && poi ? '감염과 중독' : inf ? '감염' : '중독') + ' 치료', 0);
  },
  /* the boss's treasure chest: a gun you do not own yet (a rented one can come out too), yours for good once you get out alive,
     and full ammo for everything. owning every gun already, it is just the ammo */
  openChest() {
    const pool = ORDER.filter((id) => id !== 'pistol' && !save.owned.includes(id));
    Gun.slots.forEach((g) => { wstate[g].mag = WEAPONS[g].mag; wstate[g].reserve = WEAPONS[g].reserve; });
    if (!pool.length) { Sound.pickup('ammo'); HUD.banner('보물상자', '모든 총을 이미 가지고 있습니다 · 모든 총 탄약 가득', 3.2); HUD.feed('보물상자 · 탄약 보충', 0); return; }
    const id = pick(pool), w = WEAPONS[id];
    save.owned.push(id); persist();
    if (!save.loadout.includes(id)) { const slot = Loadout.place(id); if (!slot) { const i = save.loadout.length - 1; save.loadout[i] = id; persist(); } }
    gainGun(id); switchTo(id); Sound.buy(); Sound.pickup('ammo');
    HUD.banner('보물상자 · ' + w.name, w.model + ' ' + w.name + ' 획득 · 이제 영구히 내 총입니다(살아서 나가면) · 모든 총 탄약 가득', 3.6);
    HUD.feed('보물상자 · ' + w.name + ' 영구 소유 · 탄약 보충', 0);
  },
  /* an animal you have ridden is tamed: it never fights you again and counts as dealt with, like a kill (but pays nothing) */
  calm: 0,
  tame(e) {
    this.calm++;
    HUD.feed(e.T.name + ' 길들임 · 처치한 것으로 칩니다', 0);
    if (this.kills + this.calm >= this.goal) this.finish();
  },
  onKill(e, weak) {
    if (this.ended) return;
    if (e.extra) return; // a mine the boss threw out: not one of the hundred, no money
    this.kills++; stats.kills++; if (weak) stats.heads++;
    if (e.tamed) this.calm = Math.max(0, this.calm - 1); // it was already counted
    const base = e.minion ? 1000 : e.animal || e.robot ? e.T.money : 1000;
    // a kill with a shot to the head pays 1.5 times; so does a zombie finished off before it ever got back up (the two multiply).
    // a stage you have already cleared can be played again, but pays nothing; a bomber who blows himself up pays nothing either
    const fresh = e.type === 'zombie' && !e.revived;
    const pay = this.replay || e.selfDet || e.noPay ? 0 : Math.round((e.boss ? base * 20 : e.T && e.T.mid ? base * 10 : base) * (weak ? 1.5 : 1) * (fresh ? 1.5 : 1)); // noPay: your mount, killed by the others; a mid-boss pays ten times
    save.money += pay; stats.earned += pay; persist();
    // on a phone the kill lines and the +money pop are left out: the bag total at the top still counts up
    Sound.kill(); if (pay) { Sound.coin(); if (!isTouch) HUD.moneyPop(pay); }
    if (e.boss) {
      if (!isTouch) HUD.feed('보스 ' + e.name + ' 처치', pay, 'hs'); HUD.banner('보스 처치' + (pay ? ' · +' + won(pay) : ''), '보물상자가 떨어졌습니다', 3);
      // the chest comes down where the boss fell, unless that is up on something: then on the nearest open floor, where you can walk to it
      let cx = e.pos.x, cz = e.pos.z, cy = e.kong ? 0 : e.pos.y; const gy = groundAt(cx, cy + 0.6, cz, 0.6);
      if (gy > 1.0) { const d = this.openSpot(cx, cz); if (d) { cx = d.x; cz = d.z; cy = 0; } }
      Loot.chest(cx, cz, cy); this.boss = null; if (e.kong) Kong.unwarn();
      if (Lab.active) Lab.monkeyMode('panic');
      if (e.type === 'bdrone') { ShipFX.aimOff(); for (const m of Enemies.list.slice()) if (m.extra) Enemies.vanish(m); Ship.onDown(e); } // its leftover mines go dead with it; the hall door opens
    } else if (e.T && e.T.mid) {
      if (!isTouch) HUD.feed('중간 보스 ' + e.name + ' 처치', pay, 'hs'); HUD.banner('중간 보스 처치' + (pay ? ' · +' + won(pay) : ''), '운전실을 장악했습니다', 2.4);
      // the drones it called fall with it (they count, but pay nothing), the bridge door opens, and this is the save point
      let fell = 0; for (const m of Enemies.list.slice()) if (m.alive && m.fromBee) { m.noPay = true; m.beeFall = true; Enemies.damage(m, 1e6, m.pos, { x: 0, y: -1, z: 0 }, false, true); fell++; }
      if (fell) HUD.feed('불러낸 드론 ' + fell + '대도 함께 떨어졌습니다', 0);
      if (World.style.ship) Ship.onDown(e); // the save point comes when you pull the key out (Ship.takeKey)
    }
    else if (e.selfDet) HUD.feed(e.T && e.T.mode === 'mine' ? '스파이더 마인이 터졌습니다' : '자폭맨이 터졌습니다', 0, 'hs');
    else if (e.beeFall) { /* counted in one line above */ }
    else if (e.noPay) HUD.feed('타고 있던 ' + e.T.name + (hasBatchim(e.T.name) ? '이' : '가') + ' 쓰러졌습니다', 0, 'hs');
    else if (!isTouch) HUD.feed((e.animal ? e.T.name : STAGES[this.stage].label) + (weak ? ' · 머리 명중' : ' 처치'), pay, weak ? 'hs' : '');
    // an elephant leaves its tusks: ivory, which the shop buys for a lot (not on a replay, like the money)
    if (e.type === 'elephant' && pay > 0) { save.items.ivory = Math.min(63, (save.items.ivory | 0) + 1); persist(); HUD.items(); HUD.banner('상아 획득', '상점에서 ' + won(IVORY_PRICE) + '에 팔 수 있습니다', 2.6); }
    const left = this.goal - this.kills - this.calm, S = STAGES[this.stage];
    if (!e.boss && (left === 50 || left === 25 || left === 10)) HUD.banner(left + S.unit + ' 남음', left === 10 && this.stage !== 4 ? '화살표가 남은 적 쪽을 가리킵니다' : '가방 ' + won(save.money), 1.8);
    if (this.kills + this.calm >= this.goal) this.finish();
  },
  /* a broken crate: a health potion (10% of max health); in the zombie village, where there is no health, always an antidote instead */
  onCrate(c) { Loot.drop(this.stage === 2 ? 'anti' : 'hp', c.x, c.z, c.y || 0); },
  takeLoot(kind) {
    if (kind === 'anti') return this.takeAntidote();
    if (kind === 'hp') {
      if (player.hp >= player.maxHp && !Bleed.n) return false;
      const heal = Math.min(Math.round(player.maxHp * 0.1), player.maxHp - player.hp); player.hp += heal;
      const stopped = Bleed.n > 0; Bleed.stop(); // the potion also stops bleeding
      Sound.pickup('hp'); HUD.feed('회복 물약 · 체력 +' + Math.round(heal) + ' (최대 체력의 10%)' + (stopped ? ' · 출혈 멎음' : ''), 0); return true;
    }
    const id = WEAPONS[Gun.cur].reserve !== Infinity ? Gun.cur : Gun.slots.find((g) => WEAPONS[g].reserve !== Infinity);
    if (!id || ammoRoom(id) < 1) return false;
    wstate[id].reserve += ammoPack(id); Sound.pickup('ammo'); HUD.feed((WEAPONS[id].rocket ? '로켓 +1 · ' : '총알 +100 · ') + WEAPONS[id].name, 0); return true;
  },
  bitten(e) {
    if (state !== 'playing' || this.ended || godMode()) return;
    player.shake = Math.max(player.shake, 0.35); HUD.hurt(30, e.pos); buzz(90);
    const dx = player.pos.x - e.pos.x, dz = player.pos.z - e.pos.z, d = Math.hypot(dx, dz) || 1;
    player.vel.x += dx / d * 6; player.vel.z += dz / d * 6;
    Sound.bite();
    if (this.infected) { this.infectT = Math.max(0.6, this.infectT - 1); return; }
    this.infected = true; this.infectT = 5;
    HUD.feed('좀비에게 물렸습니다 · 5초', 0, 'hs');
  },
  /* the antidote is a syringe: a moment to inject (no shooting), then infection and poison are gone */
  useAntidote() {
    if (state !== 'playing' || Inject.active || player.stunT > 0) return;
    if (!this.infected && this.poisonT <= 0) { if (this.stage === 2) HUD.hint('감염되지도 중독되지도 않았습니다 · 해독약 ' + this.antidotes + '개', 1.2); return; }
    if (this.antidotes <= 0) { HUD.hint('해독약이 없습니다 · 상자를 부수세요', 1.4); return; }
    this.antidotes--; Inject.start();
  },
  takeAntidote() {
    if (this.antidotes >= 5) return false;
    this.antidotes++; Sound.pickup('hp'); HUD.feed('해독약 획득 · ' + this.antidotes + '개', 0); return true;
  },
  /* rented guns and the chest's gun go back when a stage you went into ends, however it ends */
  returnRentals() { if (!this.deployed) return; this.deployed = false; save.rented = []; this.bonusGuns = []; persist(); },
  /* 5.13: the last one down while the boss's chest is still lying there (or the boss was the last): no pick-up until it is opened.
     you can't be hurt any more, an arrow points at the chest, and the way out comes a moment after you open it */
  waitChest() {
    if (this.chestWait) return;
    this.chestWait = true; this.chestT = 0; player.invuln = 1e9; Bleed.stop(true); Fear.t = 0; this.infected = false; this.infectT = 0; this.poisonT = 0;
    const how = World.style.lab ? '출입문이 열립니다' : World.style.ship ? '에어록으로 빠져나갑니다' : '헬기가 옵니다';
    HUD.banner('보물상자를 챙기세요', '화살표를 따라가 보물상자를 열면 ' + how, 3.4);
    HUD.feed('모두 처치 · 보물상자를 열어야 탈출합니다', 0, 'hs');
  },
  finish() {
    if (!this.chestOk && Loot.pending()) { this.waitChest(); return; }
    this.ended = true; player.invuln = 1e9; moneyLock = null; ivoryLock = null; ownLock = null;
    if (Ride.m) Ride.off(true); Bleed.stop(true); Fear.t = 0;
    if (Toss.on) { Toss.on = false; player.pos.y = groundAt(player.pos.x, player.pos.y, player.pos.z, player.r); player.vel.y = 0; }
    // still in the air when the last one falls: come down for the pick-up
    if (Jet.on) { jetEnd(); player.pos.y = groundAt(player.pos.x, player.pos.y, player.pos.z, player.r); player.vel.y = 0; }
    this.opened = settings.dev ? [] : (NEXT[this.stage] || []).filter((s) => !stageOpen(s)); this.sp = null;
    if (!save.cleared.includes(this.stage)) save.cleared.push(this.stage);
    this.returnRentals();
    const key = 't' + this.stage, t = Math.floor(stats.time);
    if (!save.best[key] || t < save.best[key]) save.best[key] = t;
    persist(); Sound.clear();
    HUD.banner('스테이지 ' + stageTag(this.stage) + ' 클리어', (World.style.lab ? '출입문이 열립니다 · ' : World.style.ship ? '에어록으로 빠져나갑니다 · ' : '헬기가 데리러 옵니다 · ') + (this.replay ? '다시 하기라 보상 없음' : '가방 ' + won(save.money)), 2.5);
    setTimeout(() => {
      if (state === 'playing') { state = 'cutscene'; Gun.trigger = false; Gun.adsHeld = false; Cut.startOutro(() => showResult('clear')); }
      else showResult('clear');
    }, 1700);
  },
  /* stage 4's save point (5.13), taken the moment the gold bee falls: who is dead by then, the kills and the bag, your ammo, the crates
     you have broken and whether you hold the key. dying after it, '다시 하기' puts you back on the bridge with all of that as it was */
  takeSave() {
    const alive = new Set(); for (const e of Enemies.list) if (e.alive && e.sid !== undefined) alive.add(e.sid);
    const dead = []; for (let i = 0; i < this.spawned; i++) if (!alive.has(i)) dead.push(i);
    this.sp = { stage: this.stage, dead, kills: this.kills, goal: this.goal, money: save.money, money0: moneyLock, stats: Object.assign({}, stats),
      ammo: ORDER.map((id) => [id, wstate[id].mag, wstate[id].reserve]), cur: Gun.cur, key: Ship.key, crates: crates.filter((c) => c.dead).map((c) => c.idx) };
  },
  fromSave() {
    const sp = this.sp; if (!sp) { startStage(this.stage); return; }
    $('over').hidden = true;
    this.begin(sp.stage); this.sp = sp; this.deployed = true; this.bossMsg = null;
    const dead = new Set(sp.dead);
    for (const e of Enemies.list.slice()) if (e.sid !== undefined && dead.has(e.sid)) { Enemies.vanish(e); }
    Enemies.updateDying(10); // gone at once, no puffs hanging about
    let broke = false; for (const c of crates) if (!c.dead && sp.crates.includes(c.idx)) { c.dead = true; _crateZero.makeScale(0, 0, 0); World.crateIM.setMatrixAt(c.idx, _crateZero); World.crateIM.instanceMatrix.needsUpdate = true; removeCollider(c.b); broke = true; }
    if (broke) buildNav();
    this.kills = sp.kills; this.goal = sp.goal; Object.assign(stats, sp.stats);
    save.money = sp.money; moneyLock = sp.money0; persist();
    for (const [id, m, r] of sp.ammo) { wstate[id].mag = m; wstate[id].reserve = r; }
    if (Gun.slots.includes(sp.cur)) switchTo(sp.cur);
    this.boss = Enemies.list.find((e) => e.boss) || null; this.mid = null;
    Ship.restore(sp);
    player.pos.set(SHIP_SAVE.x, 0, SHIP_SAVE.z); player.vel.set(0, 0, 0); player.yaw = SHIP_SAVE.yaw; player.pitch = 0; player.hp = player.maxHp;
    updateFlow(player.pos.x, player.pos.z);
    enterPlay(false);
    HUD.banner('세이브 포인트', '운전실에서 다시 시작합니다 · 처치 ' + this.kills + ' / ' + this.goal + ' · 가방 ' + won(save.money), 2.8);
  },
  /* not getting out means not keeping what you earned in there */
  forfeit() {
    if (ownLock !== null) { const keep = ownLock; save.owned = save.owned.filter((id) => keep.includes(id)); ownLock = null; persist(); } // a chest gun is only yours once you are out
    if (ivoryLock !== null) { save.items.ivory = Math.max(0, Math.min(save.items.ivory, ivoryLock)); ivoryLock = null; persist(); }
    if (moneyLock !== null) { save.money = Math.max(0, Math.min(save.money, moneyLock)); moneyLock = null; persist(); }
  },
  over(reason) {
    if (this.ended) return;
    if (godMode()) { this.infected = false; this.infectT = 0; this.poisonT = 0; player.hp = Math.max(player.hp, 1); return; } // invincible: whatever it was, you live
    this.ended = true; state = 'gameover'; Gun.trigger = false; Gun.adsHeld = false; this.forfeit(); if (!this.sp) this.returnRentals(); jetEnd(); Ride.reset(); Toss.on = false;
    if (document.pointerLockElement) document.exitPointerLock();
    $('touch').hidden = true; player.shake = 0.4;
    setTimeout(() => showResult(reason), 1000);
  },
};

/* ---------- screens ---------- */
const fmtTime = (t) => Math.floor(t / 60) + ':' + String(Math.floor(t) % 60).padStart(2, '0');
function refreshMenu() {
  $('bagmoney').textContent = won(save.money);
  const dev = !!settings.dev;
  const NOTE = { 1: '밀수 조직원 100명 · 총소리를 들으면 몰려옵니다', 6: '오토바이 헬멧 쓴 조직원 100명 · 헬멧은 헤드샷 한 번에 벗겨짐', 5: '단검 20 · 파란 광선검 10 · 쌍광선검 · 야구방망이 · 자폭맨 · 저격 · 보스는 기관총 · 내릴 곳을 고름',
    2: '불타는 오두막 마을 · 좀비 100마리 · 체력 없이 감염과 중독만', 7: '넓은 사파리 · 5분 뒤 동물 100마리가 가운데 감시탑으로 습격 · 탑 체력 10,000', 8: '우리를 하나씩 · 앞 우리 동물을 다 잡아야 원숭이 박사가 다음 우리를 엶 · 모든 우리 방탄유리', 3: '우리 10개가 차례로 열리는 연구소 · 얼룩말·기린·코끼리를 타고 싸움 · 보스 고릴라는 방탄유리 우리에', 4: '우주선 복도 · 운전실의 황금 드론 · 메인홀의 3페이즈 보스 드론 · 숨은 스파이더 마인' };
  STAGE_ORDER.forEach((s) => {
    const open = stageOpen(s), done = save.cleared.includes(s), btn = $('st' + s + 'btn'), pre = stageTag(PREREQ[s]), best = save.best['t' + s];
    btn.disabled = !open; btn.classList.toggle('done', done);
    $('st' + s + 'note').textContent = open ? NOTE[s] + (done ? ' · 다시 하면 보상 없음' + (best ? ' · 최단 ' + fmtTime(best) : '') : '') : '스테이지 ' + pre + eul(pre) + ' 깨면 열립니다';
    $('st' + s + 'stat').textContent = !open ? '잠김' : done ? '클리어' + (best ? ' ' + fmtTime(best) : '') : '도전 가능';
  });
  $('devbtn').textContent = dev ? '개발자 모드 켜짐' : '개발자 모드'; codexButtons(); godButtons();
  $('devbtn').classList.toggle('on', dev); document.body.classList.toggle('devmode', dev);
  $('lobtn').textContent = '무기 편성 · ' + save.loadout.filter((id) => id && gunAvailable(id)).length + '자루';
  $('shopbtn').textContent = save.rented.length ? '상점 · ' + save.rented.length + '자루 대여 중' : '상점';
  const bt = STAGE_ORDER.map((n) => save.best['t' + n] ? stageTag(n) + ' ' + fmtTime(save.best['t' + n]) : '').filter(Boolean);
  $('bestline').textContent = bt.length ? '최단 클리어 ' + bt.join(' · ') : '';
}
const CH_COLORS = { white: '#ece6d8', green: '#3dff6a', red: '#ff4b4b', yellow: '#ffe23a', cyan: '#3ad8ff', pink: '#ff5ad2', orange: '#ff9a2a' };
function syncSettingsUI() {
  ['', '2'].forEach((sfx) => {
    $('sens' + sfx).value = settings.sens; $('sensout' + sfx).textContent = Number(settings.sens).toFixed(1);
    $('vol' + sfx).value = settings.vol; $('volout' + sfx).textContent = Math.round(settings.vol * 100);
    $('autofire' + sfx).checked = !!settings.autoFire;
    $('gfx' + sfx).value = settings.gfx; $('fps' + sfx).checked = !!settings.fps;
    $('chsel' + sfx).value = settings.cross || 'cross';
    $('chcol' + sfx).value = CH_COLORS[settings.chcol] ? settings.chcol : 'white';
  });
  document.body.dataset.ch = settings.cross || 'cross';
  // the crosshair colour: white is the old ink colour; any other colour also takes over the red aiming dot
  const cc = CH_COLORS[settings.chcol] ? settings.chcol : 'white', bs = document.body.style;
  if (cc === 'white') { bs.removeProperty('--ch'); bs.removeProperty('--chads'); } else { bs.setProperty('--ch', CH_COLORS[cc]); bs.setProperty('--chads', CH_COLORS[cc]); }
}
['', '2'].forEach((sfx) => {
  $('sens' + sfx).addEventListener('input', (e) => { settings.sens = parseFloat(e.target.value); syncSettingsUI(); store('yard07.settings', settings); });
  $('vol' + sfx).addEventListener('input', (e) => { settings.vol = parseFloat(e.target.value); Sound.setVol(settings.vol); syncSettingsUI(); store('yard07.settings', settings); });
  $('autofire' + sfx).addEventListener('change', (e) => { settings.autoFire = e.target.checked; syncSettingsUI(); store('yard07.settings', settings); });
  $('gfx' + sfx).addEventListener('change', (e) => { settings.gfx = e.target.value; Gfx.mode(); syncSettingsUI(); store('yard07.settings', settings); });
  $('fps' + sfx).addEventListener('change', (e) => { settings.fps = e.target.checked; Perf.show(settings.fps); syncSettingsUI(); store('yard07.settings', settings); });
  $('chsel' + sfx).addEventListener('change', (e) => { settings.cross = e.target.value; syncSettingsUI(); store('yard07.settings', settings); });
  $('chcol' + sfx).addEventListener('change', (e) => { settings.chcol = e.target.value; syncSettingsUI(); store('yard07.settings', settings); });
});
let wentFullscreen = false;
function tryFullscreen() {
  if (!isTouch || isApp || document.fullscreenElement) return;
  try {
    const el = document.documentElement, p = el.requestFullscreen ? el.requestFullscreen({ navigationUI: 'hide' }) : null;
    if (p && p.then) p.then(() => {
      wentFullscreen = true;
      try { const o = screen.orientation && screen.orientation.lock ? screen.orientation.lock(window.innerHeight > window.innerWidth ? 'portrait' : 'landscape') : null; if (o && o.catch) o.catch(() => {}); } catch (e) {}
    }).catch(() => {});
  } catch (e) {}
}
document.addEventListener('fullscreenchange', () => { if (!document.fullscreenElement && wentFullscreen) { wentFullscreen = false; if (state === 'playing') pauseGame(); } });
function enterPlay(intro) {
  Sound.init(); Sound.setVol(settings.vol); tryFullscreen();
  ['menu', 'over', 'pause', 'shop'].forEach((id) => { $(id).hidden = true; });
  requestLock();
  const go = () => {
    $('hud').hidden = false; if (isTouch) $('touch').hidden = false;
    state = 'playing'; player.invuln = Math.max(player.invuln, 1.5);
    if (Game.bossMsg) { HUD.feed(Game.bossMsg, 0, 'hs'); Game.bossMsg = null; }
    HUD.hint(Lab.active ? '1번 우리가 10초 뒤에 열립니다 · 창살 사이로 쏠 수 있습니다' : lookMode === 'drag' ? '마우스 이동으로 조준 · Q/E로 회전 · M 키로 지도' : lookMode === 'touch' ? '오른쪽 위 지도 버튼으로 적 위치를 볼 수 있습니다' : 'M 키로 작전 지도를 볼 수 있습니다', 3.5);
  };
  if (intro) { state = 'cutscene'; Cut.startIntro(Game.stage, go); } else go();
}
/* back into play after the short look through a ship door; if the mouse lock went with it, the pause screen gets it back with a click */
function backToPlay() {
  $('hud').hidden = false; if (isTouch) $('touch').hidden = false;
  state = 'playing'; player.invuln = Math.max(player.invuln, 1); keys.clear();
  if (lookMode === 'lock' && !locked) pauseGame();
}
function startStage(n) { if (!n || !stageOpen(n)) return; Game.begin(n); showBrief(); }
/* before the drop: the stage from above with every enemy, the boss, the drop point and the way you'll face */
function showBrief() {
  state = 'brief';
  if (document.pointerLockElement) document.exitPointerLock(); // the map and buttons need the pointer back
  showOnly('brief');
  $('hud').hidden = true; $('touch').hidden = true;
  $('briefcode').textContent = '스테이지 ' + stageTag(Game.stage); $('brieftitle').textContent = STAGES[Game.stage].name;
  $('briefnote').textContent = (Lab.active ? (Lab.seq ? '우리 10개 · 12마리씩(기린 3, 코끼리 2), 마지막 우리에 보스 · 5초 뒤 1번이 열리고, 그 뒤로는 앞 우리의 동물을 모두 잡거나 길들여야 원숭이 박사가 손을 뻗어 다음 우리를 엽니다 · 모든 우리가 방탄유리라 열리기 전엔 맞힐 수 없습니다 · '
      : '우리 10개 · 12마리씩(기린 3, 코끼리 2), 마지막 우리에 보스 · 10초 뒤 1번, 그 뒤 15초마다 하나씩 열립니다 · 보스 우리는 방탄유리 · ') + '얼룩말 → 기린 → 코끼리 순서로 올라탈 수 있고, 한 번 길들인 동물은 바로 다시 탈 수 있습니다 · ' : '') +
    (Game.stage === 7 ? '5분 동안은 동물들이 흩어져 지냅니다(가까이 가거나 쏘면 덤빔) · 5분이 지나면 모두 가운데 감시탑으로 몰려옵니다 · 탑 위에 있으면 기린 말고는 탑부터 공격합니다 · 얼룩말은 와도 공격하지 않습니다 · ' : '') +
    (Game.stage === 7 ? '동물 ' + Game.goal + '마리 · 감시탑 체력 10,000' : '적 ' + Game.goal + (STAGES[Game.stage].unit) + ' · 보스 1') + ' · 나무 상자 ' + crates.length + '개' + (Game.stage === 2 ? ' (모두 해독약)' : '') + (Game.replay ? ' · 깬 스테이지라 이번에는 돈을 받지 않습니다' : '');
  $('briefnote').classList.toggle('warn', Game.replay);
  $('briefmap').classList.toggle('pick', Game.stage === 5);
  if (Game.stage === 5) dropNote();
  TacMap.legend($('brieflegend'), false);
  briefGear();
  requestAnimationFrame(() => TacMap.draw($('briefmap')));
  setTimeout(() => $('deploybtn').focus(), 0);
}
/* 1-2: tap or click the briefing map to choose the drop point */
function dropNote(bad) {
  const s = Game.info.start; let near = Infinity; for (const e of Enemies.list) near = Math.min(near, Math.hypot(e.pos.x - s.x, e.pos.z - s.z));
  $('briefnote').textContent = (bad ? '그곳에는 내릴 수 없습니다 · ' : '지도를 눌러 내릴 곳을 고르세요 · ') + '가장 가까운 적 ' + Math.round(near) + 'm · 적 ' + Game.goal + '명 · 나무 상자 ' + crates.length + '개' + (Game.replay ? ' · 깬 스테이지라 돈은 받지 않습니다' : '');
  $('briefnote').classList.toggle('warn', !!bad || near < 15 || Game.replay);
}
$('briefmap').addEventListener('click', (ev) => {
  if (state !== 'brief' || Game.stage !== 5) return;
  const w = TacMap.toWorld($('briefmap'), ev.clientX, ev.clientY), d = Game.pickDrop(w.x, w.z);
  if (d) { Sound.init(); Sound.reload(1); } dropNote(!d);
  TacMap.draw($('briefmap'));
});
let mapFrom = null;
function openMap(from) {
  if (from === 'play' && state !== 'playing') return;
  mapFrom = from; state = 'paused'; Gun.trigger = false; keys.clear();
  if (document.pointerLockElement) document.exitPointerLock();
  $('pause').hidden = true; $('touch').hidden = true; $('mapscreen').hidden = false;
  $('mapcode').textContent = '스테이지 ' + stageTag(Game.stage) + ' · 처치 ' + Game.kills + ' / ' + Game.goal;
  $('mapkeyhint').textContent = lookMode === 'touch' ? '게임 중 오른쪽 위 지도 버튼으로 다시 열 수 있습니다' : 'M 키로 열고 닫기';
  TacMap.legend($('livelegend'), true);
  requestAnimationFrame(() => TacMap.draw($('livemap')));
  setTimeout(() => $('mapclose').focus(), 0);
}
function closeMap() {
  if ($('mapscreen').hidden) return;
  $('mapscreen').hidden = true;
  if (mapFrom === 'pause') { $('pause').hidden = false; } else resumeGame();
  mapFrom = null;
}
/* what you will carry: your layout, minus guns you have not rented */
function briefGear() {
  const lo = save.loadout.map((id, i) => (id && gunAvailable(id) ? (i + 1) + ' ' + WEAPONS[id].short : '')).filter(Boolean);
  $('briefgear').textContent = lo.length ? '무기 · ' + lo.join(' · ') : '무기가 없습니다 · 무기 편성에서 하나 이상 넣으세요';
  $('briefgear').classList.toggle('warn', !lo.length);
}
$('deploybtn').addEventListener('click', () => {
  resetGuns();
  if (Gun.none) { briefGear(); Loadout.open('brief'); Loadout.msg('무기를 하나 이상 넣어야 출동할 수 있습니다'); return; }
  Game.deployed = true; $('brief').hidden = true; enterPlay(true);
});
$('briefshop').addEventListener('click', () => Shop.open('brief'));
$('brieflobtn').addEventListener('click', () => Loadout.open('brief'));
$('plobtn').addEventListener('click', () => Loadout.open('pause'));
$('briefback').addEventListener('click', () => { Game.forfeit(); $('brief').hidden = true; toMenu(); });
$('mapclose').addEventListener('click', closeMap);
$('pmapbtn').addEventListener('click', () => openMap('pause'));
window.addEventListener('resize', () => { if (!$('brief').hidden) TacMap.draw($('briefmap')); if (!$('mapscreen').hidden) TacMap.draw($('livemap')); });
function showResult(kind) {
  state = 'gameover'; Gun.trigger = false; Gun.adsHeld = false;
  if (document.pointerLockElement) document.exitPointerLock();
  const S = STAGES[Game.stage], clear = kind === 'clear';
  Game.result = kind;
  $('stamp').textContent = clear ? '임무 완료' : kind === 'zombie' ? '감염' : kind === 'poison' ? '중독' : kind === 'bleed' ? '출혈' : kind === 'laser' ? '레이저' : '작전 실패';
  $('stamp').classList.toggle('ok', clear);
  $('overtitle').textContent = clear ? '스테이지 ' + stageTag(Game.stage) + ' 클리어' : kind === 'zombie' ? '좀비가 되었습니다' : kind === 'poison' ? '독이 퍼져 쓰러졌습니다' : kind === 'slam' ? '고릴라에게 짓눌렸습니다' : kind === 'bleed' ? '피를 너무 많이 흘렸습니다' : kind === 'laser' ? '보스 드론의 레이저에 맞았습니다' : '스테이지 ' + stageTag(Game.stage) + ' · 쓰러짐';
  $('st-kills').textContent = stats.kills + (Game.calm ? ' + 길들임 ' + Game.calm : '') + ' / ' + Game.goal; $('st-earn').textContent = won(stats.earned); $('st-hs').textContent = stats.heads;
  $('st-earn').classList.toggle('lost', !clear && stats.earned > 0); $('fade').style.opacity = '0';
  $('st-acc').textContent = (stats.shots ? Math.round(100 * stats.hits / stats.shots) : 0) + '%'; $('st-time').textContent = fmtTime(stats.time);
  $('overcode').textContent = '보고 번호 ' + isoCode('YRD', (Game.stage * 100000 + stats.kills * 997) % 1000000).text;
  const fromSP = !clear && !!Game.sp;
  $('againbtn').textContent = clear ? '다시 하기' : fromSP ? '세이브 포인트에서 다시' : '다시 도전';
  // after a clear: buttons for what it opens (stage 1 opens both 2 and 1-1)
  const nx = clear ? nextStages(Game.stage) : [], all = STAGE_ORDER.every((s) => save.cleared.includes(s));
  $('againbtn').className = nx.length ? 'ghost' : 'btn';
  ['nextbtn', 'nextbtn2'].forEach((id, i) => { const b = $(id), st = nx[i]; b.hidden = !st; if (st) { b.dataset.st = st; b.textContent = '스테이지 ' + stageTag(st) + euro(stageTag(st)); } });
  const opened = clear && Game.opened && Game.opened.length ? '새로 열림 · 스테이지 ' + Game.opened.map(stageTag).join(', ') + ' · ' : '';
  $('bestline2').textContent = (clear ? opened + (all ? '모든 스테이지를 깼습니다 · ' : World.style.lab ? '연구소를 빠져나와 번 돈을 챙겼습니다 · ' : '헬기로 탈출해 번 돈을 챙겼습니다 · ')
    : fromSP ? '세이브 포인트에서 다시 하면 그때까지의 처치 수(' + Game.sp.kills + ')와 번 돈(' + won(Game.sp.stats.earned) + ')이 그대로입니다 · ' : stats.earned > 0 ? '탈출하지 못해 이번에 번 ' + won(stats.earned) + '을 잃었습니다 · ' : '') + '가방 ' + won(save.money);
  $('hud').hidden = true; $('touch').hidden = true; $('over').hidden = false;
  setTimeout(() => ($('nextbtn').hidden ? $('againbtn') : $('nextbtn')).focus(), 0);
}
function pauseGame(msg) {
  if (state !== 'playing') return;
  state = 'paused'; Gun.trigger = false; keys.clear();
  $('pausecode').textContent = '스테이지 ' + stageTag(Game.stage) + ' · 처치 ' + Game.kills + ' / ' + Game.goal;
  $('pausemsg').textContent = msg || ''; codexButtons(); godButtons();
  $('pause').hidden = false; $('touch').hidden = true;
  setTimeout(() => $('resumebtn').focus(), 0);
}
function resumeGame() {
  if (state !== 'paused') return;
  Sound.init(); Sound.wake();
  $('pause').hidden = true; $('shop').hidden = true; $('pausemsg').textContent = '';
  if (isTouch) $('touch').hidden = false;
  state = 'playing'; requestLock();
}
function toMenu() {
  Game.returnRentals(); Game.sp = null; // leaving for the menu ends the run, save point and rentals with it
  state = 'menu'; jetEnd(); Ride.reset(); Bleed.stop(true); Fear.t = 0; Toss.on = false; Enemies.clear(); Proj.clear(); Rockets.clear(); ShipFX.clear(); Loot.clear(); Car.reset(); Game.infected = false;
  camera.fov = baseFov; camera.updateProjectionMatrix(); FX.resize();
  ['hud', 'touch', 'mapscreen'].forEach((id) => { $(id).hidden = true; });
  showOnly('menu'); refreshMenu();
}
STAGE_ORDER.forEach((s) => $('st' + s + 'btn').addEventListener('click', () => startStage(s)));
$('shopbtn').addEventListener('click', () => Shop.open('menu'));
$('pshopbtn').addEventListener('click', () => Shop.open('pause'));
$('oshopbtn').addEventListener('click', () => Shop.open('over'));
$('shopclose').addEventListener('click', () => Shop.close());
$('againbtn').addEventListener('click', () => { if (Game.result !== 'clear' && Game.sp) Game.fromSave(); else startStage(Game.stage); });
['nextbtn', 'nextbtn2'].forEach((id) => $(id).addEventListener('click', () => startStage(+$(id).dataset.st)));
$('resumebtn').addEventListener('click', resumeGame);
$('quitbtn').addEventListener('click', () => { Game.forfeit(); Game.returnRentals(); toMenu(); });
$('menubtn').addEventListener('click', toMenu);
/* hooks for the Android app shell: back button and app switching */
window.yardBack = () => {
  if (state === 'cutscene') { Cut.skip(); return true; }
  if (!$('mapscreen').hidden) { closeMap(); return true; }
  if (!$('dlg').hidden) { Dialog.close(); return true; }
  if (!$('codex').hidden) { Codex.close(); return true; }
  if (!$('custom').hidden) { Custom.close(); return true; }
  if (!$('shop').hidden) { Shop.close(); return true; }
  if (!$('loadout').hidden) { Loadout.close(); return true; }
  if (state === 'brief') { Game.forfeit(); $('brief').hidden = true; toMenu(); return true; }
  if (state === 'playing') { pauseGame(); return true; }
  if (state === 'paused') { resumeGame(); return true; }
  if (state === 'gameover') { toMenu(); return true; }
  return false;
};
window.yardPause = () => { if (state === 'playing') pauseGame(); Sound.suspend(); };

/* ---------- loop ---------- */
let last = performance.now(), flowT = 0, menuT = 0, perfAcc = 0, perfN = 0, perfGood = 0;
const dbg = { freeze: false }; // tests step the game themselves
function tick(dt) {
  time += dt; stats.time += dt;
  updatePlayer(dt);
  flowT -= dt; if (flowT <= 0) { flowT = 0.3; updateFlow(player.pos.x, player.pos.z); }
  updateGun(dt, mdx, mdy); Inject.update(dt); mdx = 0; mdy = 0;
  updateEnemies(dt, time); Ride.post();
  Car.update(dt);
  Proj.update(dt); Rockets.update(dt); ShipFX.update(dt); Loot.update(dt); Game.update(dt); updateWorld(dt, time, player.pos.x, player.pos.z); FX.update(dt); HUD.update(dt);
}
function frame(now) {
  requestAnimationFrame(frame);
  const cpu0 = performance.now();
  const rawDt = Math.max(0, (now - last) / 1000), dt = Math.min(0.05, rawDt); last = now;
  if (state === 'playing') { if (!dbg.freeze) tick(dt); }
  else if (state === 'cutscene') { if (dbg.freeze) { /* stepped by the test */ } else {
    time += dt; Cut.update(dt); FX.update(dt); Enemies.updateDying(dt); Loot.update(dt); updateWorld(dt, time, camera.position.x, camera.position.z); }
  } else if (state === 'gameover') {
    time += dt; FX.update(dt); Enemies.updateDying(dt); updateWorld(dt, time, player.pos.x, player.pos.z);
    if (Game.result !== 'clear') { camera.position.y = lerp(camera.position.y, player.pos.y + 0.4, 1 - Math.exp(-dt * 3)); camera.rotation.z = lerp(camera.rotation.z, 0.5, 1 - Math.exp(-dt * 3)); }
  } else if (state === 'menu' || state === 'brief') {
    time += dt; menuT += dt * 0.04;
    // behind the menu the camera circles the stage; inside the small lab it stays under the ceiling and inside the walls
    const MC = World.menuCam, mr = MC ? MC.r : 42, mh = MC ? MC.h : 16; // the lab and the ship set their own orbit, under their ceilings
    const cx = MC ? MC.x : 0, cz = MC ? MC.z : 0;
    camera.position.set(cx + Math.cos(menuT) * mr, mh + Math.sin(menuT * 2) * (MC ? 0.8 : 2), cz + Math.sin(menuT) * mr);
    camera.rotation.set(0, 0, 0); camera.lookAt(cx, MC ? MC.look : 3, cz); FX.update(dt); updateWorld(dt, time, camera.position.x * 0.5, camera.position.z * 0.5);
  }
  mdx = 0; mdy = 0;
  if (state === 'playing' && !isTouch) Gfx.govern(dt);
  else if (state === 'playing') {
    perfAcc += dt; perfN++;
    if (perfAcc > 2) {
      const avg = perfAcc / perfN, pr = renderer.getPixelRatio(); perfAcc = 0; perfN = 0;
      if (avg > 1 / 42 && pr > 0.7) { renderer.setPixelRatio(Math.max(0.7, pr - 0.15)); onResize(); perfGood = 0; }
      else if (avg < 1 / 57 && pr < MAX_PR - 0.01) { if (++perfGood >= 3) { renderer.setPixelRatio(Math.min(MAX_PR, pr + 0.1)); onResize(); perfGood = 0; } }
      else perfGood = 0;
    }
  }
  World.sky.position.copy(camera.position);
  renderer.info.reset();
  const post = Gfx.post;
  if (post) Post.begin();
  renderer.shadowMap.needsUpdate = true;
  renderer.clear(); renderer.render(scene, camera);
  if (post) Post.afterScene(Gfx.ao);
  if (state === 'playing' || state === 'paused') { renderer.clearDepth(); renderer.render(viewScene, viewCam); }
  if (post) Post.end();
  if (Custom.on && (state === 'menu' || state === 'brief')) Custom.draw(rawDt);
  Perf.frame(rawDt, performance.now() - cpu0);
}

/* ---------- boot ---------- */
let booted = false;
function start(data) {
  if (booted) return; booted = true;
  onResize();
  if (data && data.settings) Object.assign(settings, data.settings);
  Gfx.init(); Perf.show(settings.fps);
  Game.info = buildStage(1); Game.built = 1; Gfx.stage(1);
  syncSettingsUI(); refreshMenu();
  $('menucode').textContent = isoCode('YRD', 70707).text;
  // the browser is drawing on the CPU: say so up front, it explains a low frame rate better than any setting
  if (!isTouch && GPU.soft) { $('menumsg').textContent = '그래픽 가속이 꺼져 있어 화면을 CPU로 그리는 중이라 느립니다 · 브라우저 설정의 "가능한 경우 그래픽 가속 사용"을 켜고 브라우저를 다시 시작하세요'; $('menumsg').classList.add('warn'); }
  if (isTouch) {
    document.querySelectorAll('.senslbl').forEach((el) => { el.textContent = '조준 감도'; });
    const rows = [['이동 버튼', '왼쪽 가운데 ▲▼◀▶ · 두 버튼 사이로 밀면 대각선 · ▲를 두 번 눌러 누르고 있으면 달리기'], ['오른쪽 엄지', '화면을 끌어서 조준'], ['사격', '누른 채 끌면 조준도 됩니다'],
      ['자동 사격', '조준선이 적에 닿으면 저절로 쏩니다'], ['조준 · 점프', '정조준 전환, 점프'], ['장전 · 무기 칸', '재장전, 무기 교체'], ['근접', '총으로 가까운 적을 칩니다 (소리 없음) · 나무 상자는 다가가면 저절로 부숩니다'],
      ['해독약', '감염되면 화면 가운데 버튼'], [isApp ? 'II · 뒤로 가기' : 'II', '일시정지 · 상점']];
    const k = $('keys'); k.textContent = '';
    rows.forEach(([a, b]) => { const kb = document.createElement('kbd'); kb.textContent = a; const sp = document.createElement('span'); sp.textContent = b; k.append(kb, sp); });
  }
  requestAnimationFrame(frame);
  window.__yard = { Game, player, Enemies, Gun, stats, save, Shop, Car, Loot, crates, wstate, TacMap, los: lineOfSight, stopDist, Proj, collideAt, Gfx, Post, Perf, renderer, scene, Inject, colliders, Lab, Kong, KONG, dbg, SaveCode, settings, refreshMenu, camera,
    Bleed, Fear, Toss, Ride, Beast, SEAT, ANIMALS, WEAPONS, HUD, Sound, Rockets, ShipFX, Ship, BPH, gdroneDrones, gunModels, GUN_MATS, Heat, bossDropMines, Safari, Tower, TOWER, rocketLock, Melee, groundAt, addCollider, removeCollider, persistNow: persist, get HALF() { return HALF; }, get NAV() { return NAV; }, get ivoryLock() { return ivoryLock; }, keyDown(c) { keys.add(c); }, keyUp(c) { keys.delete(c); }, damageCrate, startStage, get state() { return state; }, get calls() { return renderer.info.render.calls; },
    sim(sec) { const n = Math.round(sec * 30); for (let i = 0; i < n && state === 'playing'; i++) tick(1 / 30); },
    cutStep(dt) { if (state === 'cutscene') { time += dt; Cut.update(dt); FX.update(dt); updateWorld(dt, time, camera.position.x, camera.position.z); } } };
}
const canvasFonts = ['34px "Black Han Sans"', '600 14px "IBM Plex Mono"', '400 14px "IBM Plex Sans KR"', '900 64px "YardSign"'];
const fontsReady = document.fonts && document.fonts.load
  ? Promise.race([Promise.all(canvasFonts.map((f) => document.fonts.load(f).catch(() => null))).then(() => document.fonts.ready), new Promise((r) => setTimeout(r, 2500))])
  : Promise.resolve();
fontsReady.then(() => {
  if (hot && hot.ready) { try { hot.ready(start); } catch (e) { start({}); } setTimeout(() => start((hot && hot.data) || {}), 1500); }
  else start((hot && hot.data) || {});
});
})();
