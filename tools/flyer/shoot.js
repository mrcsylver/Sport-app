/* A4 at 300 dpi out of the browser: 794 x 1123 CSS pixels at 3x.
   deviceScaleFactor rather than a bigger viewport, so every length in the
   stylesheet stays the one the app uses and only the output is denser. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => {
  const [url, out] = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const pg = await b.newPage({ colorScheme: "dark", viewport: { width: 827, height: 1169 }, deviceScaleFactor: 3 });
  await pg.goto(url, { waitUntil: 'networkidle' });
  await pg.evaluate(() => document.fonts.ready);
  await pg.waitForTimeout(300);
  await pg.screenshot({ path: out });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
