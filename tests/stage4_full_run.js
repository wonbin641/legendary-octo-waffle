const __EXPECT = [["result .*\"title\":\"스테이지 4 클리어\"", "stage 4 cleared"], ["chest \\{\"opened\":true", "boss chest opened"], ["\\nerrors none", "no page errors"]];
// pass or fail: the lines this test prints are checked against what they should say when it runs to the end
const __lines = [], __log = console.log; console.log = (...a) => { __lines.push(a.join(' ')); __log(...a); };
process.on('exit', () => { const t = '\n' + __lines.join('\n'); const bad = __EXPECT.filter(([re]) => !new RegExp(re).test(t)).map(([, n]) => n);
  __log(bad.length ? 'FAILED: ' + bad.join(', ') : 'ALL OK'); if (bad.length) process.exitCode = 1; });
const { chromium } = require('playwright');
(async () => {
  const S = require('path').resolve(__dirname, '..'), O = S + '/tests/shots/'; require('fs').mkdirSync(O, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const errs = [];
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await ctx.addInitScript(() => { localStorage.setItem('yard07.settings', JSON.stringify({ gfx: 'fast', dev: true })); });
  const page = await ctx.newPage(); page.on('pageerror', (e) => errs.push(e.message + ' ' + String(e.stack || '').split('\n').slice(1, 3).join(' | ')));
  await page.goto('file://' + S + '/build/test.html'); await page.waitForTimeout(3500);
  const resume = async () => { await page.waitForTimeout(150); await page.evaluate(() => { if (window.__yard.state === 'paused') document.getElementById('resumebtn').click(); }); await page.waitForTimeout(150); };
  const cut = async () => { await page.evaluate(() => { const y = window.__yard; for (let i = 0; i < 90 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); }); await resume(); };
  await page.evaluate(() => { const y = window.__yard; y.dbg.freeze = true; y.startStage(4); document.getElementById('deploybtn').click(); for (let i = 0; i < 900 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
  await resume();
  console.log('cleanup', JSON.stringify(await page.evaluate(() => { const y = window.__yard, p = y.player; p.invuln = 1e9;
    for (const e of y.Enemies.list.slice()) if (e.alive && e.type !== 'gdrone' && e.type !== 'bdrone') y.Enemies.damage(e, 1e6, e.pos, { x: 0, y: 0, z: 1 }, false);
    y.sim(0.5); return { kills: y.Game.kills, goal: y.Game.goal, ended: y.Game.ended, left: y.Enemies.list.filter((e) => e.alive).map((e) => e.type) }; })));
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(-90.7, 0, -7.5); p.vel.set(0, 0, 0); y.sim(0.1); });
  await cut();
  console.log('bee', JSON.stringify(await page.evaluate(() => { const y = window.__yard, bee = y.Enemies.list.find((e) => e.type === 'gdrone'); y.sim(0.5);
    y.Enemies.damage(bee, 1e6, bee.pos, { x: 0, y: 0, z: 1 }, false); y.sim(3); const p = y.player; p.pos.set(-103.2, 0.45, -7.5); y.sim(0.2); const took = y.Ship.takeKey();
    return { door: y.Ship.doors[0].mode, sp: !!y.Game.sp, took, ended: y.Game.ended }; })));
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(66.6, 0, -7.5); p.vel.set(0, 0, 0); y.sim(0.1); });
  await cut();
  console.log('boss', JSON.stringify(await page.evaluate(() => { const y = window.__yard, b = y.Enemies.list.find((e) => e.boss); y.sim(1);
    y.Enemies.damage(b, 1e5, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(1.6); y.Enemies.damage(b, 1e5, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(5);
    const phase = b.k.phase, hatch = y.Enemies.list.filter((e) => e.alive && e.extra && e.type === 'droneA').length, hallDoor = y.Ship.doors[1].mode;
    b.hp = 1; y.Enemies.damage(b, 50, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(1);
    return { phase, hatch, hallDoorDuring: hallDoor, bossDead: !b.alive, hallDoorAfter: y.Ship.doors[1].mode, extras: y.Enemies.list.filter((e) => e.alive && e.extra).length,
      kills: y.Game.kills, goal: y.Game.goal, chestWait: y.Game.chestWait, ended: y.Game.ended, chest: !!y.Loot.pending() }; })));
  console.log('chest', JSON.stringify(await page.evaluate(() => { const y = window.__yard, p = y.player, c = y.Loot.pending(); if (!c) return 'none';
    p.pos.set(c.x + 0.5, c.y, c.z); p.vel.set(0, 0, 0); y.sim(3); return { opened: !y.Loot.pending(), ended: y.Game.ended, owned: y.save.owned.length }; })));
  // the way out starts on a real-time timer after the clear: wait for it to begin, step the outro to its end, then for the result screen
  await page.waitForFunction(() => window.__yard.state === 'cutscene', null, { timeout: 15000 }).catch(() => {});
  await page.evaluate(() => { const y = window.__yard; for (let i = 0; i < 1800 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
  await page.waitForFunction(() => !document.getElementById('over').hidden, null, { timeout: 15000 }).catch(() => {});
  console.log('result', JSON.stringify(await page.evaluate(() => ({ state: window.__yard.state, over: !document.getElementById('over').hidden, title: document.getElementById('overtitle').textContent, sp: !!window.__yard.Game.sp }))));
  console.log('errors', errs.length ? errs.join('\n') : 'none');
  await browser.close();
})();
