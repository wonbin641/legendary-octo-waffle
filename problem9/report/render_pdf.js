// Render the report HTML to an A4 PDF with headless Chromium (Playwright).
// usage: node render_pdf.js in.html out.pdf
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const [inp, out] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + path.resolve(inp), { waitUntil: 'networkidle' });
  await page.waitForFunction(() => document.querySelectorAll('.math').length === 0 ||
    document.querySelectorAll('.katex').length >= document.querySelectorAll('.math').length, null, { timeout: 30000 });
  await page.evaluate(() => document.fonts.ready);
  await page.pdf({
    path: out, format: 'A4', printBackground: true,
    margin: { top: '20mm', bottom: '17mm', left: '16mm', right: '16mm' },
    displayHeaderFooter: true,
    headerTemplate: '<div style="font-family:Noto Sans KR;font-size:7.5px;color:#24507a;width:100%;padding:0 16mm;">' +
      '문제 9 · 검토 결과와 최종 해답<div style="border-bottom:0.6px solid #1c2430;margin-top:2px"></div></div>',
    footerTemplate: '<div style="font-family:Noto Sans KR;font-size:7.5px;color:#5b6573;width:100%;text-align:center;">' +
      '<span class="pageNumber"></span></div>',
  });
  await browser.close();
})();
