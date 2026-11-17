// The web build's sound mix (run after tools/build_godot.sh): node godot/tests/web_sound.js
// Godot's web build plays sounds as samples of the browser's own Web Audio, and its buses carry no effects there, so the
// game puts the browser game's own nodes into the mix (scripts/snd.gd, WEB_MIX). This plays sounds in the built game and
// listens to both ears at Godot's master output: a sound on the right is heard on the right as the browser game's
// StereoPanner pans it, a sound without a place is heard alike in both, and the master compressor is the browser game's.
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
  await p.mouse.click(640, 360); await p.waitForTimeout(1500);   // (a click wakes the page's audio, as a player's would)
  const y = (c) => p.evaluate((c) => window.__yarr(c), c);
  await y('start 1'); await p.waitForTimeout(1500);
  const first = await y('sound coin'); await p.waitForTimeout(600);
  check('the web build plays sounds as samples, with the browser game\'s own nodes in its mix', first.web_mix === true && first.playback === 1, first);
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
  const playing = () => p.evaluate(() => window.__yarrSnd.A.sampleNodes.size);
  const idle = async () => { for (let t = 0; t < 100 && (await playing()) > 0; t++) await p.waitForTimeout(100); };
  const hear = async (cmd) => {   // the energy reaching each ear from that one sound: from before it starts (on the game's next frame) to after it ends
    await idle(); const n0 = await p.evaluate(() => window.__started); await p.evaluate(() => window.__ears()); const out = await y(cmd);
    for (let t = 0; t < 150 && (await p.evaluate(() => window.__started)) === n0; t++) await p.waitForTimeout(100);
    await idle(); await p.waitForTimeout(300);
    const [left, right] = await p.evaluate(() => window.__ears()); return { out, left, right };
  };
  const routes = await p.evaluate(() => { const S = window.__yarrSnd, A = S.A; return { mix: S.mix, to: A.buses.map((b) => A.buses.indexOf(b._send)) }; });
  check('the web build\'s buses in Godot\'s order, each sending where Godot sends it (Master out, Mix to Master, the twelve voices to Mix)',
    routes.to.length === routes.mix + 13 && routes.to[0] === -1 && routes.to[routes.mix] === 0 && routes.to.slice(routes.mix + 1).every((t) => t === routes.mix), routes);
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
  check('no page errors', errs.length === 0, errs.slice(0, 4));
  await b.close(); server.close();
  console.log(fails ? fails + ' FAILED' : 'ALL OK'); process.exitCode = fails ? 1 : 0;
})();
