const __EXPECT = [["915x412 \\{[^\\n]*\"overlaps\":\\[\\],\"offscreen\":\\[\\]", "915x412 buttons clear"], ["780x360 \\{[^\\n]*\"overlaps\":\\[\\],\"offscreen\":\\[\\]", "780x360 buttons clear"], ["732x320 \\{[^\\n]*\"overlaps\":\\[\\],\"offscreen\":\\[\\]", "732x320 buttons clear"], ["melee button \\{\"on\":true", "melee button jabs"], ["\\nerrors none", "no page errors"]];
// pass or fail: the lines this test prints are checked against what they should say when it runs to the end
const __lines = [], __log = console.log; console.log = (...a) => { __lines.push(a.join(' ')); __log(...a); };
process.on('exit', () => { const t = '\n' + __lines.join('\n'); const bad = __EXPECT.filter(([re]) => !new RegExp(re).test(t)).map(([, n]) => n);
  __log(bad.length ? 'FAILED: ' + bad.join(', ') : 'ALL OK'); if (bad.length) process.exitCode = 1; });
const { chromium, devices } = require('playwright');
(async () => {
  const S = require('path').resolve(__dirname, '..'), O = S + '/tests/shots/'; require('fs').mkdirSync(O, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const errs = [];
  for (const sz of (process.argv[2] || '915x412,780x360,732x320').split(',')) {
    const [w, h] = sz.split('x').map(Number), dev = devices['Pixel 7'];
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, userAgent: dev.userAgent + ' Yard07App/1.0' });
    const page = await ctx.newPage(); page.on('pageerror', (e) => errs.push(sz + ': ' + e.message));
    await page.goto(process.env.URL || ('file://' + S + '/build/test.html')); await page.waitForTimeout(3500);
    const shot = async (n) => { await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)))); await page.screenshot({ path: O + 'l517_' + n + '_' + sz + '.png', timeout: 120000 }); };
    await page.evaluate(() => { const y = window.__yard; y.dbg.freeze = true; y.startStage(1); document.getElementById('deploybtn').click(); for (let i = 0; i < 900 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
    await page.waitForTimeout(200); await page.evaluate(() => { if (window.__yard.state === 'paused') document.getElementById('resumebtn').click(); }); await page.waitForTimeout(200);
    await page.evaluate(() => window.__yard.sim(3));
    const lay = await page.evaluate(() => { const r = {}, list = [];
      for (const el of document.querySelectorAll('#touch .tbtn, #t-dpad')) { if (el.hidden || getComputedStyle(el).display === 'none') continue; const b = el.getBoundingClientRect(); r[el.id] = [b.left, b.top, b.width, b.height].map(Math.round); list.push([el.id, b]); }
      const hits = []; for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) { const a = list[i][1], b = list[j][1]; if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) hits.push(list[i][0] + '/' + list[j][0]); }
      const am = document.querySelector('.ammo'), ab = am ? am.getBoundingClientRect() : null, mb = document.getElementById('t-melee').getBoundingClientRect();
      const offscreen = list.filter(([, b]) => b.left < 0 || b.top < 0 || b.right > innerWidth || b.bottom > innerHeight).map(([id]) => id);
      return { r, overlaps: hits, offscreen, meleeVsAmmo: ab ? (mb.left < ab.right && ab.left < mb.right && mb.top < ab.bottom && ab.top < mb.bottom) : null, portrait: document.body.classList.contains('portrait') }; });
    console.log(sz, JSON.stringify(lay));
    // the 근접 button: a touch on it starts the jab
    const jab = await page.evaluate(() => { const y = window.__yard, b = document.getElementById('t-melee'), r = b.getBoundingClientRect(), x = r.left + r.width / 2, yy = r.top + r.height / 2;
      const t = new Touch({ identifier: 7, target: b, clientX: x, clientY: yy }); b.dispatchEvent(new TouchEvent('touchstart', { bubbles: true, cancelable: true, touches: [t], targetTouches: [t], changedTouches: [t] }));
      const on = y.Melee.on; b.dispatchEvent(new TouchEvent('touchend', { bubbles: true, cancelable: true, touches: [], targetTouches: [], changedTouches: [t] })); y.sim(0.6); return { on, after: y.Melee.on }; });
    console.log(sz, 'melee button', JSON.stringify(jab));
    await shot('play');
    if (sz === '780x360') {
      await page.evaluate(() => { document.getElementById('t-pause').dispatchEvent(new TouchEvent('touchstart', { bubbles: true, cancelable: true })); }); await page.waitForTimeout(250);
      await page.evaluate(() => document.getElementById('quitbtn').click()); await page.waitForTimeout(500);
      await page.evaluate(() => document.getElementById('cubtn').click()); await page.waitForTimeout(600);
      console.log(sz, 'custom', JSON.stringify(await page.evaluate(() => { const v = document.getElementById('cuview').getBoundingClientRect(), s = document.querySelector('#custom .cusheet').getBoundingClientRect();
        return { view: [v.left, v.top, v.width, v.height].map(Math.round), sheet: [s.left, s.top, s.width, s.height].map(Math.round) }; })));
      await shot('custom');
    }
    await ctx.close();
  }
  console.log('errors', errs.join('\n') || 'none'); await browser.close();
})();
