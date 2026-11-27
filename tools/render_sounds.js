#!/usr/bin/env node
/* Godot판의 효과음(godot/sounds/*.wav)을 브라우저판 자신의 WebAudio 코드로 만듭니다.
   src/03_core.js의 Sound 모듈을 그대로 떼어 와 헤드리스 크로미엄의 OfflineAudioContext에서 돌리고, 나온 소리를 파일로 둡니다.
   - 조합법(잡음·필터·음의 미끄러짐·엔벨로프)이 브라우저판과 한 글자도 다르지 않습니다.
   - 브라우저판은 부를 때마다 잡음의 시작 위치와 속도, 몇몇 음높이(금속음, 신음, 고양이과의 울음, 쇳소리, 원숭이 웃음)를 새로 뽑습니다.
     그래서 같은 소리를 네 번 따로 만들어 둡니다(name.wav, name__1.wav, name__2.wav, name__3.wav). 늘 같은 소리는 하나만 둡니다.
   - 마스터의 압축기(DynamicsCompressor)와 좌우 패닝은 게임이 소리를 섞을 때 하므로 여기서는 빼고, 소리 하나만 모노로 만듭니다.
   - 16비트에 담으려고 SCALE배로 줄여 적고, 게임이 그만큼 되돌립니다(godot/scripts/snd.gd의 SCALE).
   - 브라우저판에 없는 Godot판만의 소리는 GODOT_OWN에 브라우저판과 같은 재료(noise, tone)로 적어 두고 같은 방법으로 만듭니다.
     기관총(shot_lmg)은 1.6.1부터 Godot판만의 소리입니다(주인의 요청: 브라우저판의 것이 크고 시끄러워서, 더 낮고 둔탁하게).
   - 소리가 비어 나오면(조합이 깨졌을 때) 빈 파일을 쓰지 않고 멈춥니다. 네 번 모두 만들어 견주고, 넷이 다 같을 때만 하나를 둡니다.
   쓰는 법: node tools/render_sounds.js            모두 다시 (Playwright와 그 크로미엄이 필요합니다)
           node tools/render_sounds.js shot_lmg   이름을 준 것만
           RENDER_OUT=/tmp/x node tools/render_sounds.js   다른 곳에 (견주어 볼 때) */
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const ROOT = path.join(__dirname, '..'); const OUT = process.env.RENDER_OUT || path.join(ROOT, 'godot', 'sounds');
fs.mkdirSync(OUT, { recursive: true });
const SR = 44100, SCALE = 0.5, VARIANTS = 4;
const src = fs.readFileSync(path.join(ROOT, 'src', '03_core.js'), 'utf8');
const a = src.indexOf('const Sound = (() => {'); const b = src.indexOf('\n})();', a);
if (a < 0 || b < 0) throw new Error('Sound module not found in src/03_core.js');
/* Godot's own sounds, made of the browser game's own parts: put into the module's api (src/ itself is not changed) */
const GODOT_OWN = `
    // the machine gun as the Godot version has it (1.6.1): lower and duller than the browser game's. No bright crack, no
    // clack of the belt: a muffled body with a dull knock in it, a deep thump with a low growl, and a short low rumble after
    godotLmg() { if (!ctx) return; const d = out();
      noise(0.12, 'lowpass', 1400, 220, 0.7, 1.1, d); noise(0.09, 'bandpass', 520, 300, 1, 0.6, d); tone('sine', 62, 28, 0.22, 1.0, d);
      tone('triangle', 110, 45, 0.08, 0.3, d); noise(0.28, 'lowpass', 450, 70, 0.5, 0.28, d, 0.015); },`;
const MODULE = src.slice(a, b + 6).replace('const api = {', 'const api = {' + GODOT_OWN);
if (!MODULE.includes('godotLmg()')) throw new Error("the browser game's Sound api has changed: Godot's own sounds have nowhere to go");

/* the game's sound names and the browser game's call that makes each (world sounds called without a place: no pan, full level) */
const SOUNDS = {
  shot_pistol: "shot('pistol')", shot_smg: "shot('smg')", shot_rifle: "shot('rifle')", shot_lmg: 'godotLmg()', shot_sniper: "shot('sniper')",
  shot_gl: "shot('gl')", shot_rocket: "shot('rocket')", shot_shotgun: "shot('shotgun')",
  empty: 'empty()', reload0: 'reload(0)', reload1: 'reload(1)', pump: 'pump()',
  hit: 'hit(false)', headshot: 'headshot(false)', headshot_kill: 'headshot(true)', swing: 'swing()',
  melee: 'melee(null, false)', melee_metal: 'melee(null, true)', kill: 'kill()',
  enemy_shot0: 'enemyShot(null, 0)', enemy_shot1: 'enemyShot(null, 1)', enemy_shot2: 'enemyShot(null, 2)',
  boom: 'boom(null, true)', boom_small: 'boom(null, false)', metal: 'metal(null)', hurt: 'hurt()', spawn: 'spawn(null)',
  pickup_hp: "pickup('hp')", pickup_ammo: "pickup('ammo')", step: 'step()', land: 'land()', alarm: 'alarm()', clear: 'clear()',
  pistol_far: 'pistolFar(null)', moan: 'moan(null)', bite: 'bite()', crack: 'crack(null)', thud: 'thud(null)', coin: 'coin()', gulp: 'gulp()',
  heart: 'heart()', inject: 'inject()', cured: 'cured()', scream: 'scream(null)', rage: 'rage(null)', ring: 'ring()', revive: 'revive(null)',
  zap: 'zap(null)', zap_mech: "zap(null, 'mech')", zap_drone: "zap(null, 'drone')", zap_turret: "zap(null, 'turret')", zap_crawler: "zap(null, 'crawler')",
  ping: 'ping(null)', thump: 'thump(null)', beep: 'beep(null)',
  shot_far: 'farShot(null)', far_deagle: "farShot(null, 'deagle')", far_smg: "farShot(null, 'smg')", far_rifle: "farShot(null, 'rifle')",
  far_sniper: "farShot(null, 'sniper')", far_shotgun: "farShot(null, 'shotgun')",
  flame: 'flame(null)', saber_hum: 'saberHum(null)', saber_swing: 'saberSwing(null)', bat_hit: 'batHit(null)', saber_hit: 'saberHit(null)', squelch: 'squelch(null)',
  buy: 'buy()', roar_cat: "roar(null, 'cat')", roar_trumpet: "roar(null, 'trumpet')", roar_beat: "roar(null, 'beat')", roar_bray: "roar(null, 'bray')", roar_grunt: "roar(null, 'grunt')",
  horn: 'horn()', whiz: 'whiz(null)', clank: 'clank(null)', clang: 'clang(null)', press: 'press()', hiss: 'hiss()', siren: 'siren()',
  cackle: 'cackle(null)', swoosh: 'swoosh(null)', beam: 'beam(null)', rocket_pod: 'rocket(null)', chirp: 'chirp(null)', quake: 'quake(null)',
  charge: 'charge(null, 0.75)',   // the gold bee winding up its charge (07h_shipbots.js), the only caller
  laser_siren1: 'siren2(3.25)', laser_siren2: 'siren2(2.25)', laser_siren3: 'siren2(1.25)',   // the boss's laser lock, its phase's charge + 0.25 s
};
/* the loops, made seamless: [name, call that starts it, seconds to let it settle, loop length (whole periods of all its parts)] */
const LOOPS = { rotor: ['rotor(1)', 2.5, 6.0], jet_lo: ['jet(0.45)', 1.5, 3.0], jet_hi: ['jet(0.85)', 1.5, 3.0] };   // the jetpack hovering, and pushing up

/* a mono 16-bit WAV around the samples (little-endian bytes, as the page hands them over) */
function wav(pcm, file) {
  const n = pcm.length / 2, buf = Buffer.alloc(44);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22); buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  fs.writeFileSync(file, Buffer.concat([buf, pcm]));
}

(async () => {
  const browser = await chromium.launch(); const page = await browser.newPage();
  await page.goto('about:blank');
  await page.evaluate(({ MODULE, SR, SCALE }) => {
    /* one fresh Sound per render, on an offline context of its own: as the browser game's, but no compressor (the game's mixer has it) */
    window.__render = async (call, seconds, from, len) => {
      let ctx = null;
      window.AudioContext = function () {
        ctx = new OfflineAudioContext(1, Math.ceil(SR * seconds), SR);
        ctx.createDynamicsCompressor = function () {   // a plain pass-through that takes the compressor's settings
          const g = this.createGain(); for (const k of ['threshold', 'knee', 'ratio', 'attack', 'release']) g[k] = { value: 0 }; return g;
        };
        return ctx;
      };
      const settings = { vol: 1 }, camera = { position: { x: 0, y: 0, z: 0 }, rotation: { y: 0 } }, state = 'playing';
      const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v)), rand = (a, b) => a + Math.random() * (b - a);
      const Sound = eval(MODULE + '\nSound'); Sound.init(); eval('Sound.' + call);
      const data = (await ctx.startRendering()).getChannelData(0);
      const s = Math.floor((from || 0) * SR), e = len ? s + Math.round(len * SR) : data.length;
      let end = e; if (!len) { while (end > s && Math.abs(data[end - 1]) < 1e-4) end--; end = Math.min(e, end + Math.round(0.01 * SR)); }
      // the samples as 16-bit numbers, SCALE times the level, sent back as the bytes themselves (base64), not a list of numbers
      let peak = 0; const q = new Int16Array(end - s);
      for (let i = s; i < end; i++) { q[i - s] = Math.max(-32767, Math.min(32767, Math.round(data[i] * SCALE * 32767))); peak = Math.max(peak, Math.abs(data[i])); }
      const bytes = new Uint8Array(q.buffer); let bin = '';
      for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
      return { pcm: btoa(bin), peak, n: q.length };
    };
  }, { MODULE, SR, SCALE });
  let worst = 0; const made = [];
  const save = (name, r) => {
    if (r.peak < 1e-4 || r.n === 0) throw new Error(name + ' came out silent: its call in the browser game\'s Sound has changed or broken');
    if (r.peak * SCALE > 1) throw new Error(name + ' is too loud for SCALE (peak ' + r.peak.toFixed(3) + '): nothing written for it');   // (before its file, not after: no clipped file left behind)
    worst = Math.max(worst, r.peak);
    wav(Buffer.from(r.pcm, 'base64'), path.join(OUT, name + '.wav')); made.push(name);
  };
  const only = process.argv.slice(2);   // (names given: only those)
  for (const n of only) if (!(n in SOUNDS) && !(n in LOOPS)) throw new Error('no such sound: ' + n);
  for (const [name, call] of Object.entries(SOUNDS)) {
    if (only.length && !only.includes(name)) continue;
    let takes = [];
    for (let k = 0; k < VARIANTS; k++) takes.push(await page.evaluate(([c]) => window.__render(c, 4.0), [call]));
    if (takes.every((r) => r.pcm === takes[0].pcm)) takes = takes.slice(0, 1);   // the same all four times: one is enough (a sound picked from a few at random can come out the same twice)
    takes.forEach((r, k) => save(k === 0 ? name : `${name}__${k}`, r));
    for (let k = takes.length; k < VARIANTS; k++) { const f = path.join(OUT, `${name}__${k}.wav`); if (fs.existsSync(f)) fs.unlinkSync(f); }
  }
  for (const [name, [call, settle, len]] of Object.entries(LOOPS)) if (!only.length || only.includes(name)) save(name, await page.evaluate(([c, s, l]) => window.__render(c, s + l + 0.5, s, l), [call, settle, len]));
  await browser.close();
  console.log(made.length, 'files from', only.length || Object.keys(SOUNDS).length + Object.keys(LOOPS).length, 'sounds; loudest peak', worst.toFixed(3), '(stored at', (worst * SCALE).toFixed(3) + ')');
})();
