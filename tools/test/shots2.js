const { chromium } = require('/opt/node22/lib/node_modules/playwright');
/* The settings tab is collapsible now; a test should not care which section
   a control sits in, so open them all before poking at it. */
async function openSects(pg) {
  await pg.evaluate(() => document.querySelectorAll('details.sect')
    .forEach(d => { d.open = true; }));
  await pg.waitForTimeout(120);
}

/* The 100-item dropdown became a search picker; drive it the way a thumb would. */
async function pickEx(pg, key) {
  if (!(await pg.$('#exFinder:not([hidden])'))) await pg.click('#exPick');
  await pg.waitForSelector('.exl-i[data-ex="' + key + '"]', { timeout: 8000 });
  await pg.click('.exl-i[data-ex="' + key + '"]');
  await pg.waitForTimeout(120);
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
 ['MARCO','SARAH'].forEach(function(n,i){DB.profiles.push({id:'p'+(i+1),user_id:'u'+(i+1),
   display_name:n,restore_code:'RC'+i,avatar:i===1?'🦊':null});
   DB.members.push({league_id:'lg1',profile_id:'p'+(i+1),joined_at:'2026-01-0'+(i+1)});});
 var cur=W(),id=0;
 function log(pid,k,m,a){DB.workouts.push({id:'w'+(++id),league_id:'lg1',profile_id:pid,exercise_key:k,
   mode:m,amount:a,points:C(k,m,a),week_start:cur,created_at:new Date().toISOString()});}
 // MARCO: push 12, pull 10, legs 10 -> 3 groups today = +5
 log('p1','pushups','reps',12); log('p1','pullups','reps',5); log('p1','airsquats','reps',20);
 log('p2','pushups','reps',40);
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4403,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.route('**/sw.js', r => r.abort());
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4403/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(800);

 /* combo tracker */

 /* board with named divisions + rank banners */
 await pg.waitForTimeout(500);
 await pg.screenshot({path:path.join(OUT,'A1-divisions.png')});

 /* stats tab, rank first */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(900);
 await pg.screenshot({path:path.join(OUT,'A2-rank.png')});

 /* collapsed exercise groups */
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(300);
 await pg.click('#logBtn'); await pg.waitForSelector('#logModal:not([hidden])');
 await pg.waitForTimeout(300);
 await pg.click('#exPick'); await pg.waitForTimeout(300);
 await pg.screenshot({path:path.join(OUT,'A3-groups.png')});
 await pg.click('.iconbtn.close'); await pg.waitForTimeout(300);

 /* emblem builder + shop */
 await pg.click('.tab[data-view="me"]'); await openSects(pg); await pg.waitForTimeout(400);
 await pg.evaluate(()=>document.querySelector('#avColors').scrollIntoView());
 await pg.waitForTimeout(250);
 await pg.screenshot({path:path.join(OUT,'A4-emblem.png')});
 await pg.evaluate(()=>document.querySelector('.shop-i').scrollIntoView());
 await pg.waitForTimeout(250);
 await pg.screenshot({path:path.join(OUT,'A5-shop.png')});
 console.log('  new shots written');
 process.exit(0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
