const __EXPECT = [["ALL OK", "all checks"]];
// pass or fail: the lines this test prints are checked against what they should say when it runs to the end
const __lines = [], __log = console.log; console.log = (...a) => { __lines.push(a.join(' ')); __log(...a); };
process.on('exit', () => { const t = '\n' + __lines.join('\n'); const bad = __EXPECT.filter(([re]) => !new RegExp(re).test(t)).map(([, n]) => n);
  __log(bad.length ? 'FAILED: ' + bad.join(', ') : 'ALL OK'); if (bad.length) process.exitCode = 1; });
const { chromium, devices } = require('playwright');
(async () => {
  const S = require('path').resolve(__dirname, '..'); require('fs').mkdirSync(S + '/tests/shots', { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] }); const errs = []; let bad = 0;
  const check = (n, ok, msg) => { console.log((ok ? 'ok   ' : 'FAIL ') + n + ' ' + msg); if (!ok) bad++; };
  const param = (url, k) => { const q = url.slice(url.indexOf('?') + 1).split('&'); for (const kv of q) { const i = kv.indexOf('='); if (kv.slice(0, i) === k) return decodeURIComponent(kv.slice(i + 1)); } return null; };
  for (const [n, o] of [['pc', { viewport: { width: 1280, height: 800 } }], ['phone', devices['Pixel 7']]]) {
    const c = await b.newContext(o); await c.grantPermissions(['clipboard-read', 'clipboard-write']);
    const p = await c.newPage(); p.on('pageerror', (e) => errs.push(n + ': ' + e.message));
    await p.goto(process.env.URL || ('file://' + S + '/build/test.html')); await p.waitForTimeout(2500);
    // a progress worth mailing: some money and two stages cleared
    await p.evaluate(() => { const y = window.__yard; y.save.money = 123456; for (const s of [1, 6]) if (!y.save.cleared.includes(s)) y.save.cleared.push(s);
      document.addEventListener('click', (e) => { if (e.target.closest && e.target.closest('#mailbtn,#gmailbtn')) e.preventDefault(); }, true); });
    await p.click('#savebtn'); await p.waitForTimeout(200);
    const s1 = await p.evaluate(() => ({ row: !document.getElementById('mailrow').hidden, addr: document.getElementById('mailto').value, code: document.getElementById('codebox').textContent,
      mail: document.getElementById('mailbtn').href, gmail: document.getElementById('gmailbtn').href, ok: document.getElementById('dlgok').textContent }));
    check(n, s1.row, 'mail row shown on save');
    check(n, s1.addr === '', 'address starts empty (nothing prefilled): "' + s1.addr + '"');
    check(n, s1.ok === '코드 복사', 'main button reads ' + s1.ok);
    check(n, s1.mail.startsWith('mailto:?subject='), 'mailto with no address: ' + s1.mail.slice(0, 40) + '… (' + s1.mail.length + ' chars)');
    const body = param(s1.mail, 'body'), subj = param(s1.mail, 'subject');
    check(n, body && body.split('\r\n')[2] === s1.code, 'body line 3 is the code ' + s1.code);
    check(n, /^야르 07 저장 코드 · \d{4}-\d\d-\d\d \d\d:\d\d$/.test(subj), 'subject ' + subj);
    check(n, /깬 스테이지: .*1-1/.test(body) && /가방: /.test(body), 'body lists cleared stages and money: ' + body.split('\r\n').slice(4, 7).join(' | '));
    check(n, param(s1.gmail, 'body') === body && param(s1.gmail, 'su') === subj && param(s1.gmail, 'to') === null && s1.gmail.startsWith('https://mail.google.com/mail/?view=cm&fs=1&'), 'gmail link carries the same subject/body, no to: (' + s1.gmail.length + ' chars)');
    // an address typed in goes into both links and is remembered on this device
    await p.fill('#mailto', 'player@example.com'); await p.waitForTimeout(100);
    const s2 = await p.evaluate(() => ({ mail: document.getElementById('mailbtn').href, gmail: document.getElementById('gmailbtn').href, st: JSON.parse(localStorage.getItem('yard07.settings') || '{}').mailTo }));
    check(n, s2.mail.startsWith('mailto:player@example.com?subject='), 'mailto gets the address');
    check(n, param(s2.gmail, 'to') === 'player@example.com', 'gmail gets to=');
    check(n, s2.st === 'player@example.com', 'address stored in settings');
    await p.fill('#mailto', 'not-an-address'); await p.waitForTimeout(100);
    check(n, (await p.evaluate(() => document.getElementById('mailbtn').href)).startsWith('mailto:?'), 'a malformed address is left out of the link');
    await p.fill('#mailto', 'player@example.com');
    await p.click('#mailbtn'); check(n, /메일 앱을 엽니다/.test(await p.textContent('#dlgmsg')), 'mail button message: ' + await p.textContent('#dlgmsg'));
    await p.click('#gmailbtn'); check(n, /Gmail/.test(await p.textContent('#dlgmsg')), 'gmail button message: ' + await p.textContent('#dlgmsg'));
    await p.click('#mailcopy'); await p.waitForTimeout(300);
    const msg = await p.textContent('#dlgmsg'); let clip = null; try { clip = await p.evaluate(() => navigator.clipboard.readText()); } catch (e) { clip = 'read failed: ' + e.message.split('\n')[0]; }
    check(n, /복사했습니다/.test(msg), 'copy message: ' + msg);
    check(n, clip && clip.includes(s1.code) && clip.startsWith('야르 07 저장 코드 · '), 'clipboard holds subject + body with the code (' + (clip || '').length + ' chars)');
    await p.screenshot({ path: S + '/tests/shots/mail_' + n + '.png' });
    const lay = await p.evaluate(() => { const el = (id) => document.getElementById(id).getBoundingClientRect(); const W = innerWidth;
      const ids = ['mailto', 'mailbtn', 'gmailbtn', 'mailcopy', 'dlgok', 'dlgcancel']; const r = {}; for (const id of ids) { const b = el(id); r[id] = [Math.round(b.left), Math.round(b.top), Math.round(b.width), Math.round(b.height)]; }
      const body = document.querySelector('#dlg .sheet-body'), cs = getComputedStyle(body), bb = body.getBoundingClientRect(), L = bb.left + parseFloat(cs.paddingLeft), R = bb.right - parseFloat(cs.paddingRight);
      return { W, H: innerHeight, r, box: [Math.round(L), Math.round(R)], over: ids.filter((id) => el(id).right > R + 0.5 || el(id).left < L - 0.5), sx: document.documentElement.scrollWidth > W + 1 }; });
    check(n, lay.over.length === 0 && !lay.sx, 'everything inside the dialog (' + lay.box + ') at ' + lay.W + 'x' + lay.H + ': ' + (lay.over.join(',') || 'none past') + ' ' + JSON.stringify(lay.r));
    // reopen after a reload: the address is still there; the load dialog has no mail row
    await p.reload(); await p.waitForTimeout(2500); await p.click('#savebtn'); await p.waitForTimeout(150);
    check(n, (await p.inputValue('#mailto')) === 'player@example.com', 'address remembered after reload');
    await p.click('#dlgcancel'); await p.waitForTimeout(150); await p.click('#loadbtn'); await p.waitForTimeout(150);
    check(n, await p.evaluate(() => document.getElementById('mailrow').hidden), 'no mail row on load');
    const li = await p.evaluate(() => { const body = document.querySelector('#dlg .sheet-body'), cs = getComputedStyle(body), bb = body.getBoundingClientRect(), r = document.getElementById('codein').getBoundingClientRect();
      return [Math.round(r.left), Math.round(r.right), Math.round(bb.left + parseFloat(cs.paddingLeft)), Math.round(bb.right - parseFloat(cs.paddingRight))]; });
    check(n, li[0] >= li[2] - 0.5 && li[1] <= li[3] + 0.5, 'load code input inside the dialog ' + li);
    await p.screenshot({ path: S + '/tests/shots/mail_load_' + n + '.png' });
    await c.close();
  }
  console.log('errors', errs.join('\n') || 'none'); console.log(bad ? bad + ' FAILED' : 'ALL OK'); await b.close();
})();
