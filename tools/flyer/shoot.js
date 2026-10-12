/* The sheet out of the browser at 300 dpi: the page's own CSS pixel size at
   3x. deviceScaleFactor rather than a bigger viewport, so every length in
   the stylesheet stays the one the app uses and only the output is denser.

   A4     827 x 1169 CSS px -> 2481 x 3507
   Letter 850 x 1100 CSS px -> 2550 x 3300 */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => {
  const [url, out, w, h] = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const pg = await b.newPage({
    colorScheme: "dark",
    viewport: { width: Number(w) || 827, height: Number(h) || 1169 },
    deviceScaleFactor: 3 });
  await pg.goto(url, { waitUntil: 'networkidle' });
  await pg.evaluate(() => document.fonts.ready);
  await pg.waitForTimeout(300);
  await pg.screenshot({ path: out });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
