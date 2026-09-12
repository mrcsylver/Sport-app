const { chromium } = require('/opt/node22/lib/node_modules/playwright');
/* The settings tab is collapsible now; a test should not care which section
   a control sits in, so open them all before poking at it. */
async function openSects(pg) {
  // setting .open directly does not fire 'toggle' reliably, and the emblem
  // grids are built on that event, so dispatch it ourselves
  await pg.evaluate(() => document.querySelectorAll('details.sect').forEach(d => {
    d.open = true;
    d.dispatchEvent(new Event('toggle'));
  }));
  await pg.waitForTimeout(200);
}

const http = require('http'); const fs = require('fs'); const path = require('path');
const ROOT = '/home/user/Sport-app';
const MOCK = fs.readFileSync(path.join(__dirname, 'mock-supabase.js'), 'utf8');
const OUT = path.join(__dirname, 'shots'); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json' };
const server = http.createServer((req,res)=>{ let p=decodeURIComponent(req.url.split('?')[0]); if(p==='/')p='/index.html';
  const f=path.join(ROOT,p); if(!f.startsWith(ROOT)||!fs.existsSync(f)||fs.statSync(f).isDirectory()){res.writeHead(404);return res.end();}
  res.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); res.end(fs.readFileSync(f)); });

const SEED = `(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'THE IRON CIRCLE',code:'X7K2Q9',owner_id:'p1',max_members:20});
 DB.leagues.push({id:'lg2',name:'FULL HOUSE',code:'FULL01',owner_id:'p1',max_members:20});
 for(var i=1;i<=20;i++){ DB.profiles.push({id:'f'+i,user_id:'uf'+i,display_name:'BOT'+i,restore_code:'FC'+i}); DB.members.push({league_id:'lg2',profile_id:'f'+i,joined_at:'2026-01-01'}); }
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO123',created_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});})();`;

(async () => {
  await new Promise(r => server.listen(4322, r));
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const errors = []; const results = [];
  async function newPage(uid) {
    const ctx = await browser.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2, isMobile:true, hasTouch:true, timezoneId:'Europe/Paris', locale:'en-GB' });
    const page = await ctx.newPage();
    page.on('console', m => { if (m.type()==='error') errors.push('CONSOLE: '+m.text()); });
    page.on('pageerror', e => errors.push('PAGEERROR: '+e.message));
    page.on('dialog', d => d.accept());   // the new "create a SEPARATE league?" confirm
    await page.route('**/vendor/supabase.js*', r => r.fulfill({ contentType:'text/javascript', body: MOCK + SEED }));
    await page.route('**/config.js*', r => r.fulfill({ contentType:'text/javascript',
      body:'window.APP_CONFIG={SUPABASE_URL:"https://demo.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"X7K2Q9",APP_NAME:"IRON LEAGUE"};' }));
    await page.route('**/sw.js', r => r.fulfill({ contentType:'text/javascript', body:'' }));
    await page.addInitScript(u => { window.__UID__ = u; }, uid);
    return { ctx, page };
  }

  /* A. DEFAULT_LEAGUE_CODE makes the bare link join the main league */
  let { ctx, page } = await newPage('auth-a');
  await page.goto('http://localhost:4322/');
  await page.waitForSelector('#onboard:not([hidden])');
  const previewed = await page.textContent('#joinPreview .jc-n');
  results.push(['bare link shows default league', previewed.trim() === 'THE IRON CIRCLE', previewed]);
  await page.fill('#nameInput','TESTER'); await page.click('#enterBtn');
  await page.waitForSelector('#app:not([hidden])'); await page.waitForTimeout(500);
  const hdr = await page.textContent('#lgName');
  results.push(['joined default league', hdr.trim()==='THE IRON CIRCLE', hdr]);
  const meta = await page.textContent('#lgMeta');
  results.push(['member count updated to 2', /2\/20/.test(meta), meta]);

  /* B. join a FULL league by code -> friendly error */
  await page.click('.tab[data-view="me"]'); await openSects(page); await page.waitForTimeout(300);
  await page.fill('#joinCodeInput','FULL01'); await page.click('#joinBtn');
  await page.waitForSelector('#toast:not([hidden])'); await page.waitForTimeout(200);
  const t1 = await page.textContent('#toast');
  results.push(['full league rejected clearly', /full/i.test(t1), t1]);

  /* C. create a league and switch between leagues */
  await page.click('#createToggle');
  await page.waitForSelector('#newLeagueInput', { state: 'visible', timeout: 8000 });
  await page.fill('#newLeagueInput','GARAGE GOBLINS');
  await page.click('#createBtn');
  await page.waitForFunction(() => [...document.querySelectorAll('.lg-card')]
    .some(e => /GARAGE GOBLINS/.test(e.textContent)), null, { timeout: 15000 });
  const cards = await page.$$eval('.lg-card .t', els => els.map(e=>e.textContent.trim()));
  results.push(['two leagues listed', cards.length===2 && cards.includes('GARAGE GOBLINS'), cards.join(' | ')]);
  // Click by league identity, not position: a background refresh can re-render
  // the list between reading it and clicking, detaching an nth-child match.
  const gid = await page.$$eval('.lg-card', els => {
    const c = els.find(e => /GARAGE GOBLINS/.test(e.textContent));
    return c ? c.getAttribute('data-league') : null;
  });
  await page.click('.lg-card[data-league="' + gid + '"]');
  await page.waitForTimeout(600);
  const hdr2 = await page.textContent('#lgName');
  results.push(['switched league', hdr2.trim()==='GARAGE GOBLINS', hdr2]);
  const emptyBoard = await page.textContent('#board');
  results.push(['new league board has only me', /TESTER/.test(emptyBoard), emptyBoard.replace(/\s+/g,' ').slice(0,60)]);
  await page.screenshot({ path: path.join(OUT,'15-new-league.png') });

  /* D. restore code on a fresh device */
  await ctx.close();
  ({ ctx, page } = await newPage('auth-newphone'));
  await page.goto('http://localhost:4322/');
  await page.waitForSelector('#onboard:not([hidden])');
  await page.click('#restoreToggle');
  await page.fill('#restoreInput','marco123');
  await page.click('#restoreBtn');
  await page.waitForSelector('#app:not([hidden])', { timeout: 6000 });
  await page.waitForTimeout(600);
  await page.click('.tab[data-view="me"]'); await openSects(page); await page.waitForTimeout(300);
  const restored = await page.inputValue('#renameInput');
  results.push(['restored profile on new phone', restored==='MARCO', restored]);
  await page.screenshot({ path: path.join(OUT,'16-restored.png') });

  /* E. bad restore code */
  await ctx.close();
  ({ ctx, page } = await newPage('auth-bad'));
  await page.goto('http://localhost:4322/');
  await page.waitForSelector('#onboard:not([hidden])');
  await page.click('#restoreToggle');
  await page.fill('#restoreInput','NOPE'); await page.click('#restoreBtn');
  await page.waitForTimeout(400);
  const err = await page.textContent('#onboardErr');
  results.push(['bad restore code explained', /does not match/i.test(err), err]);
  await ctx.close();

  await browser.close(); server.close();
  let fail = 0;
  results.forEach(([n, ok, got]) => { if (!ok) fail++; console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+got+']'); });
  console.log('\nJS errors: ' + (errors.length ? '\n  '+errors.join('\n  ') : 'none'));
  console.log(fail ? fail+' FAILURES' : 'all '+results.length+' checks passed');
  process.exit(fail?1:0);
})().catch(e => { console.error('CRASH', e); process.exit(1); });
