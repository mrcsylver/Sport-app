/* Capture the clip one frame at a time.

   The page is a pure function of time: we set it, we shoot it, we step. No
   CSS animation is running, so a slow screenshot costs wall-clock seconds
   and nothing else — the output is identical every run, on any machine.
   Recording a real-time animation instead would make the clip a function of
   how busy the box was. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => {
  const [url, outDir, fpsArg, wArg, hArg] = process.argv.slice(2);
  const fps = Number(fpsArg) || 30;
  const b = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const pg = await b.newPage({
    colorScheme: 'dark',
    viewport: { width: Number(wArg) || 540, height: Number(hArg) || 960 },
    deviceScaleFactor: 2 });
  await pg.goto(url, { waitUntil: 'networkidle' });
  await pg.evaluate(() => document.fonts.ready);
  const dur = await pg.evaluate(() => window.DUR);
  const total = Math.round(dur * fps);
  const stage = await pg.$('#stage');
  for (let i = 0; i < total; i++) {
    await pg.evaluate(t => window.draw(t), i / fps);
    await stage.screenshot({
      path: outDir + '/f' + String(i).padStart(5, '0') + '.png' });
    if (i % 60 === 0) process.stdout.write('  frame ' + i + '/' + total + '\n');
  }
  await b.close();
  process.stdout.write('  ' + total + ' frames\n');
})().catch(e => { console.error(e); process.exit(1); });
