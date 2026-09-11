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

const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 ['MARCO','SARAH'].forEach(function(n,i){DB.profiles.push({id:'p'+(i+1),user_id:'u'+(i+1),display_name:n,restore_code:'RC'+i});
   DB.members.push({league_id:'lg1',profile_id:'p'+(i+1),joined_at:'2026-01-0'+(i+1)});});
 var cur=W(); var id=0;
 function log(pid,k,m,a,wk){DB.workouts.push({id:'w'+(++id),league_id:'lg1',profile_id:pid,exercise_key:k,
   mode:m,amount:a,points:C(k,m,a),week_start:wk||cur,created_at:new Date().toISOString()});}
 log('p1','pushups','reps',120); log('p1','pullups','reps',20); log('p1','airsquats','reps',60);
 log('p1','run','km',6); log('p1','lsit','seconds',90); log('p1','swim','minutes',30);
 log('p1','bike','km',12); log('p1','stretch','flat',1);
 log('p2','pushups','reps',40);
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4402,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.route('**/sw.js', r => r.abort());
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4402/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);

 /* ---- stats tab ---- */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(700);
 const pts=await pg.textContent('#statPoints');
 // 120 push + 40 pull + 30 legs + 30 run + 30 lsit + 4 swim(30min@8/h) + 18 bike + 5 stretch
 T('stats total points', pts==='277', pts);
 const legend=await pg.textContent('#statLegend');
 T('every trained group in legend', ['PUSH','PULL','LEGS','CORE','CARDIO','RECOVERY'].every(c=>legend.includes(c)), legend.replace(/\s+/g,' ').slice(0,80));
 const rows=await pg.$$eval('#statList .srow .sname', e=>e.map(x=>x.textContent.trim()));
 T('per-exercise rows listed', rows.length===8, rows.length+' rows');
 T('shows raw amounts not just points', (await pg.textContent('#statList')).includes('120 reps'), 'yes');
 const barw=await pg.$$eval('#statBar span', e=>e.length);
 T('category bar rendered', barw===6, barw+' segments');
 await pg.screenshot({path:path.join(OUT,'30-stats.png')});
 await pg.click('#statsRange [data-range="all"]'); await pg.waitForTimeout(500);
 T('ALL TIME range works', (await pg.textContent('#statPoints'))==='277', await pg.textContent('#statPoints'));

 /* ---- scoring card: one item per line ---- */
 await pg.click('.tab[data-view="me"]'); await openSects(pg); await pg.waitForTimeout(400);
 await pg.evaluate(()=>document.querySelector('#pointsTable').scrollIntoView());
 await pg.waitForTimeout(300);
 const cats=await pg.$$eval('#pointsTable .pcat', e=>e.map(x=>x.textContent));
 T('scoring grouped by category', cats.join(',')==='PUSH,PULL,LEGS,CORE,CARDIO,SPORT,GYM,RECOVERY', cats.join(','));
 const nEx=await pg.$$eval('#pointsTable .pex', e=>e.length);
 T('full exercise bank listed', nEx>=100, nEx+'');
 const hs=await pg.$$eval('#pointsTable .pex', els=>{
   const el=els.find(e=>e.querySelector('.pex-n').textContent.includes('Handstand'));
   return {rates:[...el.querySelectorAll('.pex-r')].map(r=>r.textContent), variants:el.querySelector('.pex-v').textContent};
 });
 T('dual-rate exercise = one rate per line', hs.rates.length===2, JSON.stringify(hs.rates));
 T('variations shown under the name', /against a wall/i.test(hs.variants) && /hanging/i.test(hs.variants), hs.variants);
 await pg.screenshot({path:path.join(OUT,'31-scoring.png'), fullPage:false});

 /* ---- theme ---- */
 await pg.click('#themeRow [data-theme="light"]'); await pg.waitForTimeout(400);
 const themeAttr=await pg.getAttribute('html','data-theme');
 const bg=await pg.evaluate(()=>getComputedStyle(document.body).backgroundColor);
 T('light theme applied', themeAttr==='light' && bg==='rgb(244, 245, 247)', themeAttr+' / '+bg);
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(400);
 await pg.screenshot({path:path.join(OUT,'32-light.png')});
 await pg.click('.tab[data-view="me"]'); await openSects(pg); await pg.waitForTimeout(200);
 await pg.click('#themeRow [data-theme="dark"]'); await pg.waitForTimeout(300);
 T('back to dark', (await pg.getAttribute('html','data-theme'))==='dark', 'dark');

 /* ---- log modal shows variants + swim preset ---- */
 await pg.click('#logBtn'); await pg.waitForSelector('#logModal:not([hidden])'); await pg.waitForTimeout(300);
 await pickEx(pg, 'swim'); await pg.waitForTimeout(300);
 T('variants line under picker', (await pg.textContent('#exVariants')).includes('CARDIO'), await pg.textContent('#exVariants'));
 const quick=await pg.$$eval('#quickRow button', e=>e.map(x=>x.textContent.trim()));
 T('swim uses its own presets', quick[0]==='20 min', quick.join(' '));
 await pg.fill('#amountInput','60'); await pg.waitForTimeout(200);
 T('swim 1 hour = 12 pts', (await pg.textContent('#ptsPreview'))==='12', await pg.textContent('#ptsPreview'));
 await pg.screenshot({path:path.join(OUT,'33-modal-swim.png')});
 const groups=await pg.$$eval('.exl-h', e=>e.map(x=>x.textContent.trim()));
 T('picker grouped by muscle group', groups.length===8, groups.join(','));

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
