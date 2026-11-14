const __EXPECT = [["crew \\{\"total\":100,\"patrols\":20,\"hall\":8,\"hallSealed\":true", "100 robots, 8 sealed in the hall"], ["\"spAfterKey\":true", "save point at the key"], ["restored \\{\"state\":\"playing\",\"key\":true", "restored with the key"], ["\"shown\":0", "no arrows on stage 4"], ["\\nerrors none", "no page errors"]];
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
  await ctx.addInitScript(() => { localStorage.setItem('yard07.settings', JSON.stringify({ gfx: 'high', dev: true })); });
  const page = await ctx.newPage(); page.on('pageerror', (e) => errs.push(e.message + ' ' + String(e.stack || '').split('\n').slice(1, 3).join(' | ')));
  await page.goto('file://' + S + '/build/test.html'); await page.waitForTimeout(3500);
  const shot = async (n) => { await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)))); await page.screenshot({ path: O + n + '.png', timeout: 180000 }); };
  const resume = async () => { await page.waitForTimeout(150); await page.evaluate(() => { if (window.__yard.state === 'paused') document.getElementById('resumebtn').click(); }); await page.waitForTimeout(150); };
  const cut = async () => { await page.evaluate(() => { const y = window.__yard; for (let i = 0; i < 90 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); }); await resume(); };
  await page.evaluate(() => { const y = window.__yard; y.dbg.freeze = true; y.startStage(4); document.getElementById('deploybtn').click(); for (let i = 0; i < 900 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
  await resume();
  console.log('crew', JSON.stringify(await page.evaluate(() => { const y = window.__yard, L = y.Enemies.list.filter((e) => e.alive), H = y.Ship;
    const pat = L.filter((e) => e.type === 'patrol'), hall = pat.filter((e) => e.pos.x > 68);
    return { total: L.length, patrols: pat.length, hall: hall.length, hallSealed: hall.every((e) => e.sealed), beats: hall.map((e) => [Math.round(e.wp[0].x), Math.round(e.wp[0].z), Math.round(e.wp[1].x), Math.round(e.wp[1].z)]) }; })));
  // the junction signs, from the passage
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.invuln = 1e9; p.pos.set(-21.5, 0, 1.5); p.vel.set(0, 0, 0); p.yaw = 0.0; p.pitch = 0.12; y.sim(1 / 30); p.yaw = 0; p.pitch = 0.12; });
  await shot('v514_signs');
  // the sign hung before the bridge door
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(-75, 0, -7.5); p.vel.set(0, 0, 0); p.yaw = Math.PI / 2; p.pitch = 0.14; y.sim(1 / 30); p.yaw = Math.PI / 2; p.pitch = 0.14; });
  await shot('v514_doorsign');
  // in to the bee, down it: no save point yet; pull the key: save point
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(-90.7, 0, -7.5); p.vel.set(0, 0, 0); y.sim(0.1); });
  await cut();
  console.log('bee', JSON.stringify(await page.evaluate(() => { const y = window.__yard, p = y.player, bee = y.Enemies.list.find((e) => e.type === 'gdrone');
    p.pos.set(-103.2, 0.45, -7.5); y.sim(0.3); const nearWhileAlive = y.Ship.keyNear();
    y.Enemies.damage(bee, 1e6, bee.pos, { x: 0, y: 0, z: 1 }, false); y.sim(3); const spAfterBee = !!y.Game.sp; const banner1 = document.querySelector('#banner .big').textContent;
    const took = y.Ship.takeKey(); y.sim(0.2);
    return { nearWhileAlive, spAfterBee, banner1, took, spAfterKey: !!y.Game.sp, spKey: y.Game.sp && y.Game.sp.key, banner2: document.querySelector('#banner .big').textContent }; })));
  // into the hall: the patrols wake with the boss
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(60, 0, -7.5); y.sim(0.6); p.pos.set(66.6, 0, -7.5); p.vel.set(0, 0, 0); y.sim(0.1); });
  await cut();
  console.log('hall', JSON.stringify(await page.evaluate(() => { const y = window.__yard, L = y.Enemies.list.filter((e) => e.alive && e.type === 'patrol' && e.pos.x > 68); y.sim(1);
    return { sealed: L.filter((e) => e.sealed).length, n: L.length, door: y.Ship.doors[1].mode }; })));
  // die, come back: with the key, on the bridge
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.invuln = 0; p.hurt(5000, p.pos, 'body'); });
  await page.waitForTimeout(1500); await page.click('#againbtn'); await page.waitForTimeout(400); await resume();
  console.log('restored', JSON.stringify(await page.evaluate(() => { const y = window.__yard; return { state: y.state, key: y.Ship.key, keyVisible: y.Ship.keyObj.visible, doors: y.Ship.doors.map((d) => d.mode),
    hallSealed: y.Enemies.list.filter((e) => e.alive && e.type === 'patrol' && e.pos.x > 68 && e.sealed).length }; })));
  // stage 4 with ten left: no arrows
  console.log('arrows', JSON.stringify(await page.evaluate(() => { const y = window.__yard; let n = 0; for (const e of y.Enemies.list.slice()) if (e.alive && !e.boss && e.type !== 'gdrone' && y.Game.goal - y.Game.kills > 10) { y.Enemies.damage(e, 1e6, e.pos, { x: 0, y: 0, z: 1 }, false); n++; }
    y.sim(0.5); return { left: y.Game.goal - y.Game.kills, shown: [...document.querySelectorAll('.tgt')].filter((t) => +t.style.opacity > 0).length }; })));
  console.log('errors', errs.length ? errs.join('\n') : 'none');
  await browser.close();
})();
