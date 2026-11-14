const __EXPECT = [["stage 4 in app -> \\{\"state\":\"playing\"", "stage 4 runs in the app"], ["codex in app -> \\{\"open\":true", "codex opens"], ["\\nexternal 0", "nothing fetched from the internet"], ["ERRORS:\\s*$", "no page errors"]];
// pass or fail: the lines this test prints are checked against what they should say when it runs to the end
const __lines = [], __log = console.log; console.log = (...a) => { __lines.push(a.join(' ')); __log(...a); };
process.on('exit', () => { const t = '\n' + __lines.join('\n'); const bad = __EXPECT.filter(([re]) => !new RegExp(re).test(t)).map(([, n]) => n);
  __log(bad.length ? 'FAILED: ' + bad.join(', ') : 'ALL OK'); if (bad.length) process.exitCode = 1; });
const { chromium, devices } = require('playwright');
(async () => {
  const S = require('path').resolve(__dirname, '..'); require('fs').mkdirSync(S + '/tests/shots', { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const dev = Object.assign({}, devices['Pixel 7'], { viewport: { width: 915, height: 412 } });
  const ctx = await browser.newContext({ ...dev, userAgent: dev.userAgent + ' Yard07App/1.0' });
  const page = await ctx.newPage();
  const errs = [], external = [];
  await page.route('**/*', (r) => { const u = r.request().url(); if (u.startsWith('http://127.0.0.1:8765/')) return r.continue(); external.push(u); return r.abort(); });
  page.on('pageerror', (e) => errs.push('PAGEERROR: ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errs.push('console: ' + m.text()); });
  await page.goto('http://127.0.0.1:8765/index.html');
  await page.waitForTimeout(3500);
  const q = () => page.evaluate(() => ({ state: window.__yard.state, brief: !document.getElementById('brief').hidden, map: !document.getElementById('mapscreen').hidden, menu: !document.getElementById('menu').hidden }));
  await page.tap('#st1btn'); await page.waitForTimeout(400);
  console.log('tap stage 1 ->', JSON.stringify(await q()));
  await page.screenshot({ path: S + '/tests/shots/a6_brief.png' });
  console.log('back on brief ->', await page.evaluate(() => window.yardBack()), JSON.stringify(await q()));
  await page.tap('#st1btn'); await page.waitForTimeout(300);
  await page.tap('#deploybtn'); await page.waitForTimeout(300);
  console.log('deploy ->', JSON.stringify(await q()));
  await page.touchscreen.tap(200, 300); await page.waitForTimeout(400);
  console.log('tap to skip ->', JSON.stringify(await q()));
  await page.tap('#t-map'); await page.waitForTimeout(400);
  console.log('map button ->', JSON.stringify(await q()));
  await page.screenshot({ path: S + '/tests/shots/a6_map.png' });
  console.log('back on map ->', await page.evaluate(() => window.yardBack()), JSON.stringify(await q()));
  // the village, offline: developer mode opens it on a fresh install
  await page.evaluate(() => { window.yardBack(); });
  await page.evaluate(() => { window.__yard.Game.forfeit(); document.getElementById('quitbtn').click(); });
  await page.waitForTimeout(300);
  await page.evaluate(() => document.getElementById('devbtn').click());
  // the password is not kept in the repository: give it as YARD_DEV_PW to test the dialog, or the test switches developer mode on itself
  if (process.env.YARD_DEV_PW) { await page.waitForTimeout(200); await page.fill('#codein', process.env.YARD_DEV_PW); await page.tap('#dlgok'); await page.waitForTimeout(200); }
  else await page.evaluate(() => { document.getElementById('dlgcancel').click(); const y = window.__yard; y.settings.dev = true; y.refreshMenu(); });
  console.log('dev mode with password ->', await page.evaluate(() => window.__yard.settings.dev));
  await page.evaluate(() => { const y = window.__yard; y.startStage(2); document.getElementById('deploybtn').click(); for (let i = 0; i < 600 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); y.player.invuln = 1e9; y.sim(1); });
  await page.waitForTimeout(800);
  console.log('village in app ->', JSON.stringify(await page.evaluate(() => ({ state: window.__yard.state, stage: window.__yard.Game.stage, fires: window.__yard.Game.info.map.fires.length, enemies: window.__yard.Enemies.list.length }))));
  await page.screenshot({ path: S + '/tests/shots/a7_village.png' });
  await page.evaluate(() => { const y = window.__yard; y.Game.forfeit(); window.yardBack(); document.getElementById('quitbtn').click(); });
  await page.waitForTimeout(300);
  for (const st of [6, 5, 7, 8, 3, 4]) {
    await page.evaluate((st) => { const y = window.__yard; y.Game.forfeit(); y.startStage(st); document.getElementById('deploybtn').click(); for (let i = 0; i < 600 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); y.player.invuln = 1e9; y.sim(2); }, st);
    await page.waitForTimeout(800);
    console.log('stage ' + st + ' in app ->', JSON.stringify(await page.evaluate(() => ({ state: window.__yard.state, stage: window.__yard.Game.stage, enemies: window.__yard.Enemies.list.length }))));
    if (st === 7) console.log('touch kill text ->', JSON.stringify(await page.evaluate(() => { const y = window.__yard, e = y.Enemies.list.find((o) => o.type === 'buffalo'); const m0 = y.save.money;
      y.Enemies.damage(e, 1e6, e.pos, { x: 0, y: 0, z: 1 }, true); return { feedLines: document.getElementById('feed').children.length, feedText: document.getElementById('feed').textContent, pops: document.getElementById('moneypop').children.length, paid: y.save.money - m0 }; })));
    await page.screenshot({ path: S + '/tests/shots/a7_stage' + st + '.png' });
    await page.evaluate(() => { window.yardBack(); document.getElementById('quitbtn').click(); });
    await page.waitForTimeout(300);
  }
  // the encyclopaedias, by touch, then the back button
  await page.tap('#cxbtn'); await page.waitForTimeout(300);
  const cg = await page.evaluate(() => ({ open: !document.getElementById('codex').hidden, cards: document.querySelectorAll('#cxlist .cxcard').length, wide: document.documentElement.scrollWidth > innerWidth }));
  await page.screenshot({ path: S + '/tests/shots/a8_codex_guns.png' });
  await page.tap('#cxtabe'); await page.waitForTimeout(200);
  const ce = await page.evaluate(() => document.querySelectorAll('#cxlist .cxcard').length);
  await page.screenshot({ path: S + '/tests/shots/a8_codex_foes.png' });
  const back = await page.evaluate(() => window.yardBack());
  console.log('codex in app ->', JSON.stringify(cg), 'foes', ce, 'back', back, JSON.stringify(await q()));
  console.log('external', external.length, external.slice(0, 3).join(' '));
  console.log('ERRORS:\n' + errs.join('\n'));
  await browser.close();
})();
