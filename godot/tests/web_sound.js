// The web build's sound mix (run after tools/build_godot.sh): node godot/tests/web_sound.js
// Godot's web build plays sounds as samples of the browser's own Web Audio, and its buses carry no effects there, so the
// game puts the browser game's own nodes into the mix (scripts/snd.gd, WEB_MIX). This plays sounds in the built game and
// listens to both ears at Godot's master output: a sound on the right is heard on the right as the browser game's
// StereoPanner pans it, a sound without a place is heard alike in both, and the master compressor is the browser game's.
// Then stage 5's music (scripts/music.gd): its bus, its layers looped by the browser itself and started together, the
// overtime's set taking over, the low-pass under the bed, the tape's sag after a blast.
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const DIR = path.resolve(__dirname, '..', '..', 'build', 'godot-web');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
let fails = 0;
const check = (name, ok, info) => { console.log((ok ? 'ok   ' : 'FAIL ') + name + (info !== undefined ? ' ' + JSON.stringify(info) : '')); if (!ok) fails++; };

(async () => {
  if (!fs.existsSync(path.join(DIR, 'index.pck'))) { console.log('FAIL no web build in build/godot-web (run tools/build_godot.sh)'); process.exit(1); }
  const server = http.createServer((q, r) => {
    const f = path.join(DIR, decodeURIComponent(q.url.split('?')[0]).replace(/^\/+/, '') || 'index.html');
    if (!f.startsWith(DIR) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; }
    r.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r);
  });
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const p = await (await b.newContext({ viewport: { width: 1280, height: 720 } })).newPage(); const errs = [];
  p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text().slice(0, 300)); }); p.on('pageerror', (e) => errs.push('' + e));
  await p.goto(`http://127.0.0.1:${server.address().port}/index.html`);
  await p.waitForFunction(() => window.__godotReady, null, { timeout: 240000 });
  const y = (c) => p.evaluate((c) => window.__yarr(c), c);
  // waiting is for a state the page or the game reports, not for a set time: until(what, test) polls it (a FAIL if it never comes)
  const until = async (what, test, ms = 30000) => {
    const t0 = Date.now();
    for (;;) { if (await test()) return true; if (Date.now() - t0 > ms) { check('waited for ' + what, false, { ms }); return false; } await p.waitForTimeout(100); }
  };
  // the page's errors, looked at after each part (and only the new ones: one error is told once, where it came)
  let seen = 0; const noErrors = (where) => { const fresh = errs.slice(seen); seen = errs.length; check('no page errors ' + where, fresh.length === 0, fresh.slice(0, 4)); };
  const playing = () => p.evaluate(() => window.__yarrSnd.A.sampleNodes.size);
  await p.mouse.click(640, 360);   // (a click wakes the page's audio, as a player's would)
  await until('the page\'s audio to wake on the click', () => p.evaluate(() => { const S = window.__yarrSnd; return !!(S && S.A && S.A.ctx && S.A.ctx.state === 'running'); }));
  await y('start 1'); await until('stage 1 to be under way', async () => (await y('state')).state === 'playing');
  const first = await y('sound coin'); await until('the coin to be heard to its end', async () => (await playing()) === 0);
  check('the web build plays sounds as samples, with the browser game\'s own nodes in its mix', first.web_mix === true && first.playback === 1, first);
  noErrors('starting a stage and playing a sound');
  await y('hold 1');   // (the game's clock stands still: nothing else makes a sound)
  // both ears at Godot's master output (after the voices' panners and the mix's compressor), summed on the audio thread
  await p.evaluate(async () => {
    const A = window.__yarrSnd.A, ctx = A.ctx;
    const code = 'class Ears extends AudioWorkletProcessor { constructor() { super(); this.e = [0, 0]; this.port.onmessage = () => { this.port.postMessage(this.e); this.e = [0, 0]; }; } ' +
      'process(ins) { const x = ins[0]; for (let k = 0; k < 2 && k < x.length; k++) for (const v of x[k]) this.e[k] += v * v; return true; } } registerProcessor("yarr-ears", Ears);';
    await ctx.audioWorklet.addModule(URL.createObjectURL(new Blob([code], { type: 'text/javascript' })));
    const n = new AudioWorkletNode(ctx, 'yarr-ears', { channelCount: 2, channelCountMode: 'explicit' }), hush = ctx.createGain(); hush.gain.value = 0;
    A.buses[0].getOutputNode().connect(n); n.connect(hush); hush.connect(ctx.destination);
    window.__ears = () => new Promise((ok) => { n.port.onmessage = (m) => ok(m.data); n.port.postMessage('get'); });
    window.__started = 0; const make = A.SampleNode.create;   // (counting the sounds Godot starts)
    A.SampleNode.create = function (...args) { window.__started++; return make.apply(this, args); };
  });
  const idle = async () => { for (let t = 0; t < 100 && (await playing()) > 0; t++) await p.waitForTimeout(100); };
  const hear = async (cmd) => {   // the energy reaching each ear from that one sound: from before it starts (on the game's next frame) to after it ends
    await idle(); const n0 = await p.evaluate(() => window.__started); await p.evaluate(() => window.__ears()); const out = await y(cmd);
    for (let t = 0; t < 150 && (await p.evaluate(() => window.__started)) === n0; t++) await p.waitForTimeout(100);
    await idle(); await p.waitForTimeout(300);
    const [left, right] = await p.evaluate(() => window.__ears()); return { out, left, right };
  };
  const routes = await p.evaluate(() => { const S = window.__yarrSnd, A = S.A; return { mix: S.mix, to: A.buses.map((b) => A.buses.indexOf(b._send)) }; });
  check('the web build\'s buses in Godot\'s order, each sending where Godot sends it (Master out, Mix to Master, the twelve voices to Mix, the music to Master)',
    routes.to.length === routes.mix + 14 && routes.to[0] === -1 && routes.to[routes.mix] === 0 && routes.to.slice(routes.mix + 1, routes.mix + 13).every((t) => t === routes.mix) && routes.to[routes.mix + 13] === 0, routes);
  const right = await hear('sound spawn 6 0'), left = await hear('sound spawn -6 0'), mid = await hear('sound coin');
  await idle(); await p.evaluate(() => window.__ears()); await p.waitForTimeout(1500); const [qL, qR] = await p.evaluate(() => window.__ears());
  const want = Math.pow(Math.tan(((0.75 + 1) / 2) * Math.PI / 2), 2);   // the browser game's pan at 6 m to the side: 6 / (6 + 2) = 0.75
  check('a sound 6 m to the right is heard on the right as the browser game pans it (equal power, pan 0.75)',
    right.right > 0 && Math.abs(right.right / right.left / want - 1) < 0.2 && Math.abs(right.out.pan - 0.75) < 1e-4, { ratio: right.right / right.left, want, pan: right.out.pan });
  check('and one 6 m to the left on the left', left.left > 0 && Math.abs(left.left / left.right / want - 1) < 0.2, { ratio: left.left / left.right, left: left.left, right: left.right, pan: left.out.pan });
  check('a sound without a place is heard alike in both ears', mid.left > 0 && Math.abs(mid.left / mid.right - 1) < 0.01, { ratio: mid.left / mid.right, left: mid.left, right: mid.right });
  check('and after them nothing: the mix does not feed round on itself', qL + qR < 1e-3, { left: qL, right: qR });
  // a sound that keeps going: the whole of it loops, and a new level while it plays reaches it (the jetpack eases between two)
  const loudness = async () => { await p.evaluate(() => window.__ears()); await p.waitForTimeout(1500); const [l, r] = await p.evaluate(() => window.__ears()); return l + r; };
  const n0 = await p.evaluate(() => window.__started); await y('loop rotor 0.6');
  for (let t = 0; t < 150 && (await p.evaluate(() => window.__started)) === n0; t++) await p.waitForTimeout(100);
  await p.waitForTimeout(500); const loud = await loudness(); await y('loop rotor 0.15'); await p.waitForTimeout(800); const soft = await loudness();
  const looped = await p.evaluate(() => { const A = window.__yarrSnd.A; for (const s of A.samples.values()) if (s.loopMode !== 'disabled') return { mode: s.loopMode, begin: s.loopBegin, end: s.loopEnd, frames: s._audioBuffer.length, rate: s.sampleRate }; return null; });
  await y('loop rotor 0'); await p.waitForTimeout(1200); const after = await loudness();
  check('a loop (the rotor) goes round all its 6 s, a lower level while it plays reaches it, and it stops',
    looped !== null && looped.mode === 'forward' && looped.begin === 0 && Math.abs(looped.end / looped.rate - 6) < 0.01 && loud > 0 && loud / soft > 6 && after < 1e-3, { looped, loud, soft, after });
  const mix = await p.evaluate(() => {
    const S = window.__yarrSnd, c = S.A.buses[S.mix].__yarr;
    return c instanceof DynamicsCompressorNode ? { threshold: c.threshold.value, ratio: c.ratio.value, knee: c.knee.value, attack: c.attack.value, release: c.release.value } : null;
  });
  check('the browser game\'s master compressor on the mix (threshold -14 dB, ratio 6, Web Audio\'s knee, attack and release)',
    mix !== null && mix.threshold === -14 && mix.ratio === 6 && mix.knee === 30 && Math.abs(mix.attack - 0.003) < 1e-6 && mix.release === 0.25, mix);
  noErrors('panning, looping and the compressor');
  // stage 5's music
  await y('hold 0');
  const music = () => p.evaluate(() => { const S = window.__yarrSnd, A = S.A, out = []; for (const n of A.sampleNodes.values()) { if (!S.musicIds.has(String(n.streamObjectId))) continue;
    out.push({ dur: +n.getSample()._audioBuffer.duration.toFixed(2), loop: n._source.loop, at: n._sourceStartTime, rate: n._source.playbackRate.value, bus: [...n._sampleNodeBuses.keys()].map((b) => A.buses.indexOf(b)) }); } return out; });
  const mbus = routes.mix + 13;
  await y('brief 9'); await until('the briefing\'s music box to play', async () => (await music()).some((n) => n.dur === 24)); const lob = await music(); const lobLoud = await loudness();
  check('stage 5\'s briefing: its music box plays on the music\'s bus, looped by the browser itself', lob.length === 1 && lob[0].loop && lob[0].dur === 24 && lob[0].bus[0] === mbus && lobLoud > 0, { lob, lobLoud });
  await y('toymode escort'); await y('dev 1 1'); await y('start 9');
  await until('the march (after the drum)', async () => (await y('music')).what === 'march' && (await music()).filter((n) => n.dur === 32).length === 6, 40000); await y('hold 1');
  const mar = (await music()).filter((n) => n.dur === 32); const spread = mar.length ? Math.max(...mar.map((n) => n.at)) - Math.min(...mar.map((n) => n.at)) : 99;
  const marLoud = await loudness(); const st = await y('music');
  check('the match: after the drum the march\'s six layers, started in the one moment and each looped by the browser (they go round together)',
    mar.length === 6 && mar.every((n) => n.loop && n.bus[0] === mbus) && spread < 0.003 && st.what === 'march' && marLoud > 0, { n: mar.length, spread, what: st.what, marLoud });
  await y('at 30 0 0');
  const lpOf = () => p.evaluate((b) => { const f = window.__yarrSnd.A.buses[b].__yarr; return f instanceof BiquadFilterNode ? { type: f.type, hz: f.frequency.value } : null; }, mbus);
  await until('the music to settle under the bed', async () => { const l = await lpOf(); return (await y('music')).state === 'bed' && l !== null && Math.abs(l.hz - 900) < 30; }, 40000);
  const lp = await p.evaluate((b) => { const f = window.__yarrSnd.A.buses[b].__yarr; return f instanceof BiquadFilterNode ? { type: f.type, hz: f.frequency.value } : null; }, mbus);
  check('under the bed: the music\'s bus through the browser\'s own low-pass, at 900 Hz', lp !== null && lp.type === 'lowpass' && Math.abs(lp.hz - 900) < 30 && (await y('music')).state === 'bed', lp);
  await y('music blast'); let sag = [];
  await until('the tape to sag after the blast', async () => { sag = (await music()).map((n) => n.rate); return sag.length >= 6 && sag.every((r) => r < 0.8); }, 5000);
  let up = []; await until('the tape to come back', async () => { up = (await music()).map((n) => n.rate); return up.length >= 6 && up.every((r) => r === 1); }, 10000);
  check('a blast by you: the music\'s tape sags (its layers slower together) and comes back', sag.length >= 6 && sag.every((r) => r < 0.8 && Math.abs(r - sag[0]) < 1e-6) && up.every((r) => r === 1), { sag, up });
  await y('tmc time 25');
  await until('the overtime\'s set to take over', async () => { const m = await music(); return m.filter((n) => n.dur === 25.6).length === 7 && m.every((n) => n.dur !== 32); }, 20000);
  const ot = await music(); const ots = ot.filter((n) => n.dur === 25.6); const ospread = ots.length ? Math.max(...ots.map((n) => n.at)) - Math.min(...ots.map((n) => n.at)) : 99;
  check('the last 30 seconds: the overtime\'s seven layers take over, started together and looped by the browser, the march\'s stopped',
    ots.length === 7 && ots.every((n) => n.loop) && ospread < 0.003 && ot.every((n) => n.dur !== 32) && (await y('music')).ot === true, { n: ots.length, ospread, all: ot.length });
  noErrors('in stage 5\'s music');
  await y('menu'); await until('the music to stop at the menu', async () => (await music()).length === 0, 20000);
  check('back at the menu: no music', (await music()).length === 0, await music());
  noErrors('back at the menu');
  await b.close(); server.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK'); process.exitCode = fails ? 1 : 0;
})();
