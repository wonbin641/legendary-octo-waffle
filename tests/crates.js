// 5.20: crates and auto attacks. on a touch screen auto-fire shoots a crate under the crosshair only within 12 m; in the Android app a
// crate within the jab's reach in front of you is jabbed (no shot); a phone browser does not jab by itself; a PC does neither
const { chromium, ARGS, open, play, check, done } = require('./lib');
(async () => {
  const browser = await chromium.launch({ args: ARGS }), pages = [];
  for (const kind of ['phone', 'app', 'pc']) {
    const page = await open(browser, kind); pages.push(page); await play(page, 1);
    const r = await page.evaluate(() => {
      const y = window.__yard, p = y.player, G = y.Gun, M = y.Melee, out = {}; p.invuln = 1e9;
      for (const e of y.Enemies.list) { e.sealed = true; e.alert = false; e.pos.y = -50; } // nobody about
      // crates on the ground with 22 m of open floor south of them and no other crate near
      const free = y.crates.filter((c) => !c.dead && !(c.y > 0.1) && !y.crates.some((o) => o !== c && Math.hypot(o.x - c.x, o.z - c.z) < 6) && [2, 6, 10, 14, 18, 21].every((d) => !y.collideAt(c.x, 0.05, c.z + d, 0.45, 1.7)));
      let k = 0; const mag = () => y.wstate[G.cur].mag;
      const at = (c, d, look, pitch) => { G.trigger = false; G.adsHeld = false; G.reloadT = 0; M.reset(); p.pos.set(c.x, 0, c.z + d); p.vel.set(0, 0, 0); p.yaw = look ? 0 : Math.PI; p.pitch = pitch; };
      const hold = (secs, c, d, look, pitch) => { const m0 = mag(); let jab = false; for (let i = 0; i < secs * 30; i++) { y.sim(1 / 30); p.pos.set(c.x, 0, c.z + d); p.yaw = look ? 0 : Math.PI; p.pitch = pitch; jab = jab || M.on; } return { broke: c.dead, shots: m0 - mag(), jab }; };
      const aim = (d) => -Math.atan2(p.height - 0.1 - 0.6, d); // the crosshair on the crate's middle
      let c = free[k++]; at(c, 8, true, aim(8)); out.aimed8 = hold(1.5, c, 8, true, aim(8));
      c = free[k++]; at(c, 20, true, aim(20)); out.aimed20 = hold(1.5, c, 20, true, aim(20));
      c = free[k++]; at(c, 1.6, true, 0.9); out.near_lookingUp = hold(1, c, 1.6, true, 0.9);
      c = free[k++]; at(c, 1.6, false, 0); out.near_behind = hold(1, c, 1.6, false, 0);
      c = free[k++]; at(c, 1.6, true, 0.9); G.trigger = true; let j = false; for (let i = 0; i < 20; i++) { y.sim(1 / 30); G.trigger = true; p.pos.set(c.x, 0, c.z + 1.6); j = j || M.on; } G.trigger = false; out.near_shooting = { jab: j, broke: c.dead };
      c = free[k++]; at(c, 1.6, true, aim(1.6)); out.near_aimedAt = hold(1, c, 1.6, true, aim(1.6));
      out.freeCrates = free.length; return out; });
    console.log(kind, JSON.stringify(r));
    if (kind === 'pc') { check('pc: no auto-fire at a crate', !r.aimed8.broke && r.aimed8.shots === 0); check('pc: no auto jab', !r.near_lookingUp.broke && !r.near_lookingUp.jab); }
    else {
      check(kind + ': crate in the crosshair at 8 m is shot', r.aimed8.broke && r.aimed8.shots > 0, r.aimed8);
      check(kind + ': not at 20 m', !r.aimed20.broke && r.aimed20.shots === 0, r.aimed20);
      check(kind + ': nothing at a crate behind you', !r.near_behind.broke, r.near_behind);
    }
    if (kind === 'app') {
      check('app: crate in reach is jabbed (looking past it)', r.near_lookingUp.broke && r.near_lookingUp.jab && r.near_lookingUp.shots === 0, r.near_lookingUp);
      check('app: crate in reach and in the crosshair: jab, not a shot', r.near_aimedAt.broke && r.near_aimedAt.jab && r.near_aimedAt.shots === 0, r.near_aimedAt);
      check('app: no jab while the trigger is held', !r.near_shooting.jab, r.near_shooting);
    }
    if (kind === 'phone') check('phone browser: no auto jab', !r.near_lookingUp.broke && !r.near_lookingUp.jab, r.near_lookingUp);
  }
  done(pages); await browser.close();
})();
