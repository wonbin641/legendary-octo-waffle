// 5.20: breaking a crate re-works only the walking grid round it; the result must be the same as rebuilding the whole grid
const { chromium, ARGS, open, play, check, done } = require('./lib');
(async () => {
  const browser = await chromium.launch({ args: ARGS }), page = await open(browser, 'pc');
  for (const st of [1, 2, 4, 3]) {
    await play(page, st);
    const r = await page.evaluate(() => { const y = window.__yard, out = { n: y.NAV.n, crates: 0, diff: 0, patchMs: 0, fullMs: 0 };
      for (const c of y.crates.filter((c) => !c.dead).slice(0, 12)) {
        const t0 = performance.now(); y.damageCrate(c, 999, { x: c.x, y: 0.6, z: c.z }); out.patchMs += performance.now() - t0;
        const patched = y.NAV.blocked.slice(); const t1 = performance.now(); y.buildNav(); out.fullMs += performance.now() - t1;
        const full = y.NAV.blocked; for (let i = 0; i < full.length; i++) if (full[i] !== patched[i]) out.diff++;
        out.crates++; }
      out.patchMs = +(out.patchMs / Math.max(1, out.crates)).toFixed(2); out.fullMs = +(out.fullMs / Math.max(1, out.crates)).toFixed(2); return out; });
    check('stage ' + st + ': patched grid = rebuilt grid after ' + r.crates + ' crates', r.crates > 0 && r.diff === 0, r);
    await page.evaluate(() => { const y = window.__yard; y.Game.forfeit && y.Game.forfeit(); });
  }
  done([page]); await browser.close();
})();
