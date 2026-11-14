const __EXPECT = [["before \\{[^\\n]*\"broken\":false", "floor whole before"], ["after \\{\"phase\":1,\"broken\":true", "floor gone in phase 2"], ["walk \\[[^\\n]*-9\\]", "walk down to the bottom"], ["phase3 \\{\"hatch\":8,\"bossDead\":true,\"chest\":true\\}", "phase 3, boss down, chest"], ["\\nerrors none", "no page errors"]];
// pass or fail: the lines this test prints are checked against what they should say when it runs to the end
const __lines = [], __log = console.log; console.log = (...a) => { __lines.push(a.join(' ')); __log(...a); };
process.on('exit', () => { const t = '\n' + __lines.join('\n'); const bad = __EXPECT.filter(([re]) => !new RegExp(re).test(t)).map(([, n]) => n);
  __log(bad.length ? 'FAILED: ' + bad.join(', ') : 'ALL OK'); if (bad.length) process.exitCode = 1; });
const { chromium } = require('playwright');
(async () => {
  const S = require('path').resolve(__dirname, '..'), O = S + '/tests/shots/'; require('fs').mkdirSync(O, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] }); const errs = [];
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await ctx.addInitScript(() => { localStorage.setItem('yard07.settings', JSON.stringify({ gfx: 'high', dev: true })); });
  const page = await ctx.newPage(); page.on('pageerror', (e) => errs.push(e.message + ' ' + String(e.stack || '').split('\n').slice(1, 3).join(' | ')));
  await page.goto('file://' + S + '/build/test.html'); await page.waitForTimeout(3500);
  const shot = async (n) => { await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)))); await page.screenshot({ path: O + n + '.png', timeout: 180000 }); };
  const resume = async () => { await page.waitForTimeout(150); await page.evaluate(() => { if (window.__yard.state === 'paused') document.getElementById('resumebtn').click(); }); await page.waitForTimeout(150); };
  await page.evaluate(() => { const y = window.__yard; y.dbg.freeze = true; y.startStage(4); document.getElementById('deploybtn').click(); for (let i = 0; i < 900 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
  await resume();
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.invuln = 1e9; y.Ship.key = true; p.pos.set(60, 0, -7.5); y.sim(0.6); p.pos.set(66.6, 0, -7.5); p.vel.set(0, 0, 0); y.sim(0.1); for (let i = 0; i < 90 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); });
  await resume();
  console.log('before', JSON.stringify(await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(104, 0, 12); p.vel.set(0, 0, 0); y.sim(1); const g = y.groundAt(104, 1, 12, 0.3);
    const minesIn = y.Enemies.list.filter((e) => e.alive && e.type === 'mine' && Math.abs(e.pos.x - 120) < 27 && Math.abs(e.pos.z + 6) < 25).map((e) => +e.pos.y.toFixed(2));
    return { pY: +p.pos.y.toFixed(2), ground: g, broken: y.Ship.broken, minesIn }; })));
  // into phase 2: the floor goes after the shell comes off; you stand on it, looking across
  await page.evaluate(() => { const y = window.__yard, p = y.player, b = y.Enemies.list.find((e) => e.boss); p.pos.set(104, 0, 12); p.yaw = Math.atan2(-(120 - 104), -(-6 - 12)); p.pitch = -0.2;
    y.Enemies.damage(b, 1e5, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(1.9); p.yaw = Math.atan2(16, -18) * -1; });
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(80, 0, 40); p.vel.set(0, 0, 0); p.yaw = Math.atan2(-(120 - 80), -(-6 - 40)); p.pitch = -0.32; y.sim(0.35); p.pos.set(80, 0, 40); p.pitch = -0.32; });
  await shot('v519_falling');
  console.log('after', JSON.stringify(await page.evaluate(() => { const y = window.__yard, b = y.Enemies.list.find((e) => e.boss); y.sim(3);
    const minesIn = y.Enemies.list.filter((e) => e.alive && e.type === 'mine' && Math.abs(e.pos.x - 120) < 27 && Math.abs(e.pos.z + 6) < 25).map((e) => e.bs + '@' + e.pos.y.toFixed(1));
    return { phase: b.k.phase, broken: y.Ship.broken, pitFloor: y.groundAt(120, 1, 2, 0.3), mid: y.groundAt(104, 1, 12, 0.3), minesIn, tilesLeft: y.Ship.pit.tiles.filter((t) => t.visible).length }; })));
  await page.evaluate(() => { const y = window.__yard, p = y.player; p.pos.set(80, 0, 40); p.vel.set(0, 0, 0); p.yaw = Math.atan2(-(120 - 80), -(-6 - 40)); p.pitch = -0.32; y.sim(1 / 30); p.pos.set(80, 0, 40); p.pitch = -0.32; y.sim(1/30); });
  await shot('v519_pit');
  // walk down into it from the rim and back up; then phase 3 and the boss down
  console.log('walk', JSON.stringify(await page.evaluate(() => { const y = window.__yard, p = y.player, out = []; p.pos.set(95, 0, -6); p.vel.set(0, 0, 0); p.yaw = -Math.PI / 2; y.keyDown('KeyW');
    for (let i = 0; i < 12; i++) { y.sim(0.5); p.yaw = -Math.PI / 2; out.push(+p.pos.y.toFixed(1)); } y.keyUp('KeyW'); return out; })));
  console.log('phase3', JSON.stringify(await page.evaluate(() => { const y = window.__yard, b = y.Enemies.list.find((e) => e.boss); y.Enemies.damage(b, 1e5, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(6);
    const hatch = y.Ship.hatches.filter((h) => h.open).length; b.hp = 1; y.Enemies.damage(b, 50, b.pos, { x: 0, y: 0, z: 1 }, false); y.sim(1); return { hatch, bossDead: !b.alive, chest: !!y.Loot.pending() }; })));
  console.log('errors', errs.join('\n') || 'none'); await browser.close();
})();
