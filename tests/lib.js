// shared bits for the tests: open the built game (build/test.html) in a desktop, phone-browser or app-like browser, and get into a stage
const { chromium, devices } = require('playwright');
const path = require('path'), fs = require('fs');
const ROOT = path.resolve(__dirname, '..'), SHOTS = path.join(__dirname, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });
const ARGS = ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
const KINDS = {
  pc: { viewport: { width: 1280, height: 720 } },
  phone: { viewport: { width: 915, height: 412 }, isMobile: true, hasTouch: true, userAgent: devices['Pixel 7'].userAgent },
  app: { viewport: { width: 915, height: 412 }, isMobile: true, hasTouch: true, userAgent: devices['Pixel 7'].userAgent + ' Yard07App/1.0' },
};
async function open(browser, kind, settings) {
  const ctx = await browser.newContext(KINDS[kind]);
  await ctx.addInitScript((st) => { localStorage.setItem('yard07.settings', JSON.stringify(st)); }, Object.assign({ gfx: 'low', dev: true }, settings || {}));
  const page = await ctx.newPage(); page.errs = []; page.on('pageerror', (e) => page.errs.push(e.message));
  await page.goto('file://' + path.join(ROOT, 'build', 'test.html')); await page.waitForTimeout(3000);
  return page;
}
async function play(page, stage) {
  await page.evaluate((st) => { const y = window.__yard; y.dbg.freeze = true; y.startStage(st); document.getElementById('deploybtn').click(); for (let i = 0; i < 900 && y.state === 'cutscene'; i++) y.cutStep(1 / 30); }, stage);
  await page.waitForTimeout(150); await page.evaluate(() => { if (window.__yard.state === 'paused') document.getElementById('resumebtn').click(); }); await page.waitForTimeout(150);
}
let fails = 0;
function check(name, ok, info) { console.log((ok ? 'ok   ' : 'FAIL ') + name + (info !== undefined ? ' ' + (typeof info === 'string' ? info : JSON.stringify(info)) : '')); if (!ok) fails++; }
function done(pages) { const errs = [].concat(...pages.map((p) => p.errs)); check('no page errors', errs.length === 0, errs.join(' | ')); console.log(fails ? fails + ' FAILED' : 'ALL OK'); process.exitCode = fails ? 1 : 0; }
module.exports = { chromium, ARGS, ROOT, SHOTS, open, play, check, done };
