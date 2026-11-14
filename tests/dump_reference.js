// Writes godot/tests/reference_stage1.json from the browser game: stage 1's colliders, crates, navigation grid and a few movement runs.
// The Godot port's tests (godot/tests/run.gd) must reproduce these numbers.
const fs = require('fs'), path = require('path');
const { chromium, ARGS, ROOT, open, play } = require('./lib');
(async () => {
  const browser = await chromium.launch({ args: ARGS }); const page = await open(browser, 'pc');
  await play(page, 1);
  const ref = await page.evaluate(() => {
    const y = window.__yard, r6 = (v) => Math.round(v * 1e6) / 1e6;
    const out = { half: y.HALF, nav: { n: y.NAV.n, cs: y.NAV.cs } };
    out.colliders = y.colliders.map((b) => [b.minx, b.miny, b.minz, b.maxx, b.maxy, b.maxz].map(r6).concat(b.kind));
    out.crates = y.crates.map((c) => [r6(c.x), r6(c.z)]);
    let h = 0, blocked = 0; for (let i = 0; i < y.NAV.blocked.length; i++) { if (y.NAV.blocked[i]) { blocked++; h = (h * 31 + i) % 1000000007; } }
    out.navBlocked = blocked; out.navHash = h;
    const runs = [
      { name: 'walk forward 2 s', at: [0, 0, 6], yaw: 0, keys: ['KeyW'], sec: 2 },
      { name: 'sprint forward 2 s', at: [0, 0, 6], yaw: 0, keys: ['KeyW', 'ShiftLeft'], sec: 2 },
      { name: 'walk diagonally into the containers 4 s', at: [0, 0, 6], yaw: 0.9, keys: ['KeyW', 'KeyD'], sec: 4 },
      { name: 'back and left 3 s', at: [10, 0, -10], yaw: 2.2, keys: ['KeyS', 'KeyA'], sec: 3 },
      { name: 'jump while walking 1 s', at: [0, 0, 6], yaw: 3.0, keys: ['KeyW'], jump: true, sec: 1 },
      { name: 'walk over a barrier 3 s', at: [-6, 0, 0], yaw: 0, keys: ['KeyW'], sec: 3 },
    ];
    out.runs = runs.map((r) => {
      y.player.pos.set(r.at[0], r.at[1], r.at[2]); y.player.vel.set(0, 0, 0); y.player.yaw = r.yaw; y.player.pitch = 0; y.player.grounded = true; y.player.jumpBuf = 0; y.player.sprintLock = 0;
      r.keys.forEach((k) => y.keyDown(k)); if (r.jump) y.player.jumpBuf = 0.15;
      y.sim(r.sec); r.keys.forEach((k) => y.keyUp(k));
      return Object.assign(r, { end: [r6(y.player.pos.x), r6(y.player.pos.y), r6(y.player.pos.z)], grounded: y.player.grounded });
    });
    return out;
  });
  fs.writeFileSync(path.join(ROOT, 'godot', 'tests', 'reference_stage1.json'), JSON.stringify(ref));
  console.log('colliders', ref.colliders.length, 'crates', ref.crates.length, 'nav blocked', ref.navBlocked, ref.navHash);
  ref.runs.forEach((r) => console.log(r.name, r.end, r.grounded)); console.log('errors', page.errs);
  await browser.close();
})();
