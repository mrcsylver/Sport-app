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

/* The 100-item dropdown became a search picker; drive it the way a thumb would. */
async function pickEx(pg, key) {
  if (!(await pg.$('#exFinder:not([hidden])'))) await pg.click('#exPick');
  const sel = '.exl-i[data-ex="' + key + '"]';
  if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  // groups start collapsed now; open them in turn (it is an accordion, so
  // opening the next one closes the last) until the exercise shows up
  const cats = await pg.$$eval('.exl-h', els => els.map(e => e.getAttribute('data-cat')));
  for (const c of cats) {
    await pg.click('.exl-h[data-cat="' + c + '"]');
    await pg.waitForTimeout(90);
    if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  }
  throw new Error('exercise not in picker: ' + key);
}

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = '/home/user/Sport-app';
const MOCK = fs.readFileSync(path.join(__dirname, 'mock-supabase.js'), 'utf8');
const OUT = path.join(__dirname, 'shots');
fs.mkdirSync(OUT, { recursive: true });

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.png': 'image/png', '.woff2': 'font/woff2', '.webmanifest': 'application/manifest+json' };

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) {
    res.writeHead(404); return res.end('nope');
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' });
  res.end(fs.readFileSync(f));
});

const SEED = `
(function(){
  var W = window.__weekStart__, C = window.__calc__;
  function d(iso, days){ var p=iso.split('-'); var x=new Date(Date.UTC(+p[0],+p[1]-1,+p[2]+days)); return x.toISOString().slice(0,10); }
  var DB = window.__DB__;
  var cur = W();
  var L = { id:'lg1', name:'THE IRON CIRCLE', code:'X7K2Q9', owner_id:'p1', max_members:20 };
  DB.leagues.push(L);
  var names = ['MARCO','LEO','SARAH','TOM','NINA','BIG DAVE'];
  names.forEach(function(n,i){
    var p = { id:'p'+(i+1), user_id:'u'+(i+1), display_name:n, restore_code:'CODE000'+i, created_at:'2026-01-01' };
    DB.profiles.push(p);
    DB.members.push({ league_id:'lg1', profile_id:p.id, joined_at:'2026-01-0'+(i+1) });
  });
  function log(pid, key, mode, amt, week, hoursAgo){
    DB.workouts.push({ id:'w'+Math.random().toString(36).slice(2,9), league_id:'lg1', profile_id:pid,
      exercise_key:key, mode:mode, amount:amt, points:C(key,mode,amt), week_start:week,
      created_at:new Date(Date.now()-hoursAgo*3600e3).toISOString() });
  }
  // current week
  log('p1','pushups','reps',120,cur,30); log('p1','pullups','reps',35,cur,29); log('p1','run','km',7.2,cur,5);
  log('p2','muscleup','reps',9,cur,50);  log('p2','dips','reps',60,cur,48); log('p2','lsit','seconds',95,cur,4);
  log('p3','pushups','reps',200,cur,20); log('p3','airsquats','reps',300,cur,19); log('p3','stretch','flat',2,cur,2);
  log('p4','handstand','seconds',240,cur,12); log('p4','pistols','reps',24,cur,11);
  log('p5','kneeraises','reps',80,cur,8); log('p5','sprints','minutes',14,cur,7);
  // two finished weeks
  var w1 = d(cur,-7), w2 = d(cur,-14);
  log('p3','pushups','reps',420,w1,200); log('p1','pullups','reps',90,w1,201); log('p2','run','km',22,w1,202);
  log('p4','dips','reps',150,w1,203); log('p5','pushups','reps',110,w1,204);
  log('p2','muscleup','reps',31,w2,400); log('p1','run','km',18,w2,401); log('p3','airsquats','reps',600,w2,402);
})();`;

(async () => {
  await new Promise(r => server.listen(4321, r));
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const errors = [];

  async function newPage(opts = {}) {
    const ctx = await browser.newContext({
      viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
      timezoneId: 'Europe/Paris', locale: 'en-GB', serviceWorkers: 'block'
    });
    const page = await ctx.newPage();
    page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });
    page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));
    await page.route('**/vendor/supabase.js', route =>
      route.fulfill({ contentType: 'text/javascript', body: MOCK + (opts.seed !== false ? SEED : '') }));
    await page.route('**/config.js', route => route.fulfill({ contentType: 'text/javascript',
      body: 'window.APP_CONFIG={SUPABASE_URL:"https://demo.supabase.co",SUPABASE_ANON_KEY:"demo-key",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};' }));
    await page.route('**/sw.js', route => route.fulfill({ contentType: 'text/javascript', body: '' }));
    if (opts.uid) await page.addInitScript(u => { window.__UID__ = u; }, opts.uid);
    return { ctx, page };
  }
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, n + '.png'), fullPage: !!0 });

  /* ---------- 1. onboarding via invite link ---------- */
  let { ctx, page } = await newPage({ uid: 'auth-new' });
  await page.goto('http://localhost:4321/#/join/X7K2Q9');
  await page.waitForSelector('#onboard:not([hidden])', { timeout: 8000 });
  await page.waitForTimeout(400);
  await shot(page, '01-onboard-invite');

  await page.fill('#nameInput', 'CLAUDE');
  await page.click('#enterBtn');
  await page.waitForSelector('#app:not([hidden])', { timeout: 8000 });
  await page.waitForTimeout(700);
  await shot(page, '02-leaderboard');

  /* ---------- 2. expand a competitor's feed ---------- */
  await page.click('#board .row >> nth=0 >> .rowbtn');
  await page.waitForTimeout(500);
  await shot(page, '03-feed-expanded');

  /* ---------- 3. log workouts ---------- */
  await page.click('#logBtn');
  await page.waitForSelector('#logModal:not([hidden])');
  await page.waitForTimeout(350);
  await shot(page, '04-modal');

  await pickEx(page, 'muscleup');
  await page.waitForTimeout(200);
  await shot(page, '05-modal-modes');
  await page.fill('#amountInput', '6');
  await page.click('#addBtn');
  await page.waitForTimeout(400);

  await pickEx(page, 'handstand');
  await page.click('#modeRow button[data-mode="seconds"]');
  await page.fill('#amountInput', '75');
  await page.click('#addBtn');
  await page.waitForTimeout(400);

  await pickEx(page, 'run');
  await page.fill('#amountInput', '5');
  await page.click('#addBtn');
  await page.waitForTimeout(500);
  await shot(page, '06-modal-session');

  await page.click('#doneBtn');
  await page.waitForTimeout(800);
  await shot(page, '07-after-log');

  const myPts = await page.$eval('#board .row.me .pts', e => e.textContent);
  // PULL + PUSH + CARDIO all clear the 10-point floor, so the 3-group combo pays +5
  const expect = 3.5*6 + 75/5 + 5*5 + 5;
  console.log('my points after logging:', myPts, '(expect 21+15+25+5 combo =', expect + ')');
  if (parseFloat(myPts) !== expect) { console.log('> FAIL < points mismatch'); process.exitCode = 1; }
  else console.log('  PASS   new scoring matrix applied end to end');

  /* ---------- 4. hall of fame ---------- */
  await page.click('.tab[data-view="hall"]');
  await page.waitForTimeout(500);
  await shot(page, '08-hall');
  await page.click('#hall .week-top');
  await page.waitForTimeout(350);
  await shot(page, '09-hall-open');

  /* ---------- 5. leagues tab ---------- */
  await page.click('.tab[data-view="me"]'); await openSects(page);
  await page.waitForTimeout(400);
  await shot(page, '10-leagues');
  await page.evaluate(() => window.scrollTo(0, 620));
  await page.waitForTimeout(300);
  await shot(page, '11-leagues-scrolled');

  const share = await page.inputValue('#shareLink');
  console.log('share link:', share);

  /* ---------- 6. first-ever user (no invite) ---------- */
  await ctx.close();
  ({ ctx, page } = await newPage({ uid: 'auth-first', seed: false }));
  await page.goto('http://localhost:4321/');
  await page.waitForSelector('#onboard:not([hidden])');
  await page.waitForTimeout(300);
  await shot(page, '12-onboard-first');          // now defaults to JOIN
  await page.click('#modeToggle');               // "start a brand new league"
  await page.waitForTimeout(250);
  await shot(page, '12b-onboard-create');
  await page.fill('#nameInput', 'FOUNDER');
  await page.fill('#firstLeague', 'GARAGE GOBLINS');
  await page.click('#enterBtn');
  await page.waitForSelector('#app:not([hidden])');
  await page.waitForTimeout(600);
  await shot(page, '13-first-league');

  /* ---------- 7. unconfigured install ---------- */
  await ctx.close();
  ({ ctx, page } = await newPage({ seed: false }));
  await page.unroute('**/config.js');
  await page.route('**/config.js', r => r.fulfill({ contentType: 'text/javascript',
    body: 'window.APP_CONFIG={SUPABASE_URL:"PASTE_YOUR_PROJECT_URL_HERE",SUPABASE_ANON_KEY:"PASTE",TIMEZONE:"Europe/Paris"};' }));
  await page.goto('http://localhost:4321/');
  await page.waitForSelector('#setup:not([hidden])');
  await shot(page, '14-setup');
  await ctx.close();

  await browser.close();
  server.close();
  console.log('\nJS errors: ' + (errors.length ? '\n  ' + errors.join('\n  ') : 'none'));
})().catch(e => { console.error('FAILED:', e); process.exit(1); });
