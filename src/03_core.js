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
