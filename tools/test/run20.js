const { chromium } = require('/opt/node22/lib/node_modules/playwright');
/* A rest day belongs to a LEAGUE, and you can be in several.

   Somebody in two leagues could not log anything at all while ONE of them was
   resting: log_workout writes a row per league, the rest rule raised on the
   resting one, and the whole statement went down with it — including the
   leagues that were open. The sheet made it worse by narrowing itself to a
   stretch whenever the league ON SCREEN was resting, with an open league one
   tap away. */
async function pickEx(pg, key) {
  if (!(await pg.$('#exFinder:not([hidden])'))) await pg.click('#exPick');
  const sel = '.exl-i[data-ex="' + key + '"]';
  if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return true; }
  const cats = await pg.$$eval('.exl-h', els => els.map(e => e.getAttribute('data-cat')));
  for (const c of cats) {
    await pg.click('.exl-h[data-cat="' + c + '"]');
    await pg.waitForTimeout(90);
    if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return true; }
  }
  return false;
}

const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

/* Today's ISO weekday in Paris, worked out here rather than in the page, so
   the fixture and the app cannot disagree about what day it is. */
const PARIS = new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Paris', weekday: 'short' })
  .format(new Date());
const DOW = { Mon:1, Tue:2, Wed:3, Thu:4, Fri:5, Sat:6, Sun:7 }[PARIS];

/* RESTING rests today. OPEN rests today too only when `shut`, which is the
   case where it really is your rest day. */
const seed = (shut) => `(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'RESTING',code:'RST111',owner_id:'p1',max_members:30,rest_dow:[${DOW}]});
 DB.leagues.push({id:'lg2',name:'OPEN',code:'OPN222',owner_id:'p1',max_members:30,rest_dow:${shut?'['+DOW+']':'[]'}});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg2',profile_id:'p1',joined_at:'2026-01-02'});
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4420,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function boot(SEED) {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
   await pg.addInitScript(()=>{window.__UID__='u1';});
   await pg.goto('http://localhost:4420/');
   await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
   await pg.waitForTimeout(700);
   /* Stand in RESTING — the worst case, because the screen you are looking at
      is the one refusing. */
   await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(400);
   await pg.click('#leagueList [data-league="lg1"]'); await pg.waitForTimeout(1000);
   return {ctx,pg};
 }

 /* ================= 1. one resting, one open ========================== */
 let {ctx,pg}=await boot(seed(false));
 T('standing in the league that is resting',
   await pg.evaluate(()=>window.__state__.leagueId)==='lg1', 'RESTING');

 await pg.click('#logBtn'); await pg.waitForTimeout(700);
 T('the sheet is not locked',
   !(await pg.$eval('#addBtn', e=>e.disabled)), 'ADD is live');
 const note = (await pg.textContent('#restNote')).replace(/\s+/g,' ').trim();
 T('and it names the league sitting today out',
   /^RESTING is resting today\./.test(note), note.slice(0,46));
 T('while saying the other one still counts',
   /still counts in your other league/.test(note), note.slice(44,110));

 /* the thing that was broken */
 T('push-ups are still in the picker', await pickEx(pg,'pushups'), 'offered');
 await pg.fill('#amountInput','50');
 await pg.click('#addBtn'); await pg.waitForTimeout(900);
 T('and they log, from the resting league',
   await pg.evaluate(()=>window.__DB__.workouts.length)===1,
   (await pg.evaluate(()=>window.__DB__.workouts.length))+' row');
 T('landing in the open league only',
   await pg.evaluate(()=>window.__DB__.workouts.every(w=>w.league_id==='lg2')),
   await pg.evaluate(()=>window.__DB__.workouts.map(w=>w.league_id).join(',')));
 T('with no error on the sheet',
   (await pg.textContent('#modalErr')).trim()==='', await pg.textContent('#modalErr'));
 T('and a toast that says where it went',
   /1 of 2 leagues/.test(await pg.textContent('#toast')),
   (await pg.textContent('#toast')).trim());
 await pg.screenshot({path:path.join(OUT,'95-rest-one-league.png'),fullPage:false});

 /* a stretch reaches both, and counts once in the resting one */
 await pickEx(pg,'stretch');
 await pg.click('#addBtn'); await pg.waitForTimeout(900);
 const st = await pg.evaluate(()=>window.__DB__.workouts
   .filter(w=>w.exercise_key==='stretch').map(w=>w.league_id+':'+w.amount));
 T('a stretch reaches both leagues', st.length===2, st.join(' '));
 T('and counts as one session in the resting one',
   st.indexOf('lg1:1')>=0, st.join(' '));
 await ctx.close();

 /* ================= 2. every league resting ============================ */
 ({ctx,pg}=await boot(seed(true)));
 await pg.click('#logBtn'); await pg.waitForTimeout(700);
 const note2 = (await pg.textContent('#restNote')).replace(/\s+/g,' ').trim();
 T('with every league shut it is a rest day again',
   /^Rest day\./.test(note2), note2.slice(0,50));
 T('and push-ups are gone from the picker',
   !(await pickEx(pg,'pushups')), 'stretch only');
 await pg.click('#addBtn'); await pg.waitForTimeout(900);
 T('the one stretch still goes into both',
   await pg.evaluate(()=>window.__DB__.workouts.length)===2,
   (await pg.evaluate(()=>window.__DB__.workouts.length))+' rows');
 T('and then the sheet locks, as it always did',
   await pg.$eval('#addBtn', e=>e.disabled), 'ADD disabled');
 const note3 = (await pg.textContent('#restNote')).replace(/\s+/g,' ').trim();
 T('saying the recovery is done',
   /Recovery already logged/.test(note3), note3.slice(0,40));
 await pg.screenshot({path:path.join(OUT,'96-rest-all-leagues.png'),fullPage:false});
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
