/* Tapping a badge wears it.

   This shipped saying TAP TO WEAR with nothing listening. The markup carried
   data-badge, set_pinned_badges existed in the database and was granted, iOS
   called it — and the web app never did. Nothing threw and nothing logged, so
   from the outside it read as a tap that had not registered rather than as a
   thing that was never built. That is the worst kind of broken: a button that
   looks fine, says the right words, and is wired to nothing.

   So the checks here are blunt on purpose. Does the row actually change in
   the database. Does it survive a reload. Does the cap hold. Does an unearned
   badge refuse. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json','.mp4':'video/mp4','.webm':'video/webm','.jpg':'image/jpeg'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const CFG='window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",' +
          'TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",' +
          'SIGN_IN:{GOOGLE:false,EMAIL:false,ANON:true},TURNSTILE_SITE_KEY:""};';

/* Enough logged to earn FOUR badges, because three is the cap and a cap with
   exactly three candidates is a cap nothing tests. 120 sets across all five
   groups at 50 points each clears CENTURION, ALL ROUNDER and FIVE THOUSAND;
   a finished week nobody else logged in clears CHAMPION. */
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'WEARER',restore_code:'WEAR0001'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-09-01'});
 var w=window.__weekStart__(new Date()), ex=['pushups','pullups','airsquats','crunches','run'];
 for(var i=0;i<120;i++) DB.workouts.push({id:'w'+i,group_id:'g'+i,profile_id:'p1',
   league_id:'lg1',exercise_key:ex[i%5],mode:'reps',amount:10,points:50,
   week_start:w,created_at:new Date().toISOString()});
 var last=window.__weekStart__(new Date(Date.now()-7*86400000));
 DB.workouts.push({id:'wwin',group_id:'gwin',profile_id:'p1',league_id:'lg1',
   exercise_key:'pushups',mode:'reps',amount:10,points:90,
   week_start:last,created_at:last+'T12:00:00Z'});
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4432,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:CFG}));
 await pg.addInitScript(()=>{window.__UID__='u1';window.__ASK_SHARE__=false;});
 await pg.goto('http://localhost:4432/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});

 async function openBadges(){
   await pg.click('.tab[data-view="stats"]');
   await pg.waitForTimeout(400);
   await pg.evaluate(()=>{const d=document.querySelector('#sectBadges');
     if(!d.open){ d.open=true; d.dispatchEvent(new Event('toggle')); }});
   await pg.waitForSelector('#badges .bdg',{timeout:8000});
   await pg.waitForTimeout(300);
 }
 await openBadges();

 const earned = await pg.$$eval('#badges .bdg.got',
   e=>e.map(x=>x.getAttribute('data-badge')));
 T('some badges are earned, so there is something to wear',
   earned.length>=2, earned.join(', ') || 'none earned');

 /* ---- 1. the thing that was broken ---------------------------------- */
 T('an earned badge offers to be worn',
   (await pg.textContent('#badges .bdg.got .bdg-on')).trim()==='TAP TO WEAR',
   await pg.textContent('#badges .bdg.got .bdg-on'));

 await pg.click('#badges .bdg.got');
 await pg.waitForTimeout(500);

 /* Against the database, not the label. A button that turns green while
    nothing is stored is the same bug wearing a different coat. */
 const stored = await pg.evaluate(()=>
   (JSON.parse(localStorage.getItem('mock.db')||'{}').profiles||[])
     .filter(p=>p.id==='p1')[0]?.pinned_badges || []);
 T('TAPPING IT ACTUALLY STORES IT — the bug this file exists for',
   stored.length===1 && stored[0]===earned[0], JSON.stringify(stored));
 T('and the tile says it is on show',
   (await pg.textContent('#badges .bdg.pinned .bdg-on')).trim()==='ON SHOW',
   await pg.textContent('#badges .bdg.pinned .bdg-on'));

 /* ---- 2. tapping again takes it off --------------------------------- */
 await pg.click('#badges .bdg.pinned');
 await pg.waitForTimeout(450);
 T('tapping a worn badge takes it off',
   (await pg.$$('#badges .bdg.pinned')).length===0,
   (await pg.$$('#badges .bdg.pinned')).length+' still worn');

 /* ---- 3. three is the cap, and it is refused politely ---------------- */
 for (const k of earned.slice(0,3)) {
   await pg.click('#badges .bdg[data-badge="'+k+'"]');
   await pg.waitForTimeout(350);
 }
 T('three can be worn at once',
   (await pg.$$('#badges .bdg.pinned')).length===Math.min(3,earned.length),
   (await pg.$$('#badges .bdg.pinned')).length+' worn');

 if (earned.length > 3) {
   await pg.click('#badges .bdg[data-badge="'+earned[3]+'"]');
   await pg.waitForTimeout(400);
   T('a fourth is refused rather than silently dropped',
     (await pg.$$('#badges .bdg.pinned')).length===3 &&
     /three/i.test(await pg.textContent('#toast')),
     (await pg.textContent('#toast')).trim());
 }

 /* ---- 4. it survives a reload --------------------------------------- */
 await pg.reload();
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await openBadges();
 T('what is worn survives a reload',
   (await pg.$$('#badges .bdg.pinned')).length===Math.min(3,earned.length),
   (await pg.$$('#badges .bdg.pinned')).length+' worn after reload');

 /* ---- 5. an unearned badge cannot be worn --------------------------- */
 const locked = await pg.$$eval('#badges .bdg:not(.got)',
   e=>e.map(x=>({k:x.getAttribute('data-badge'), off:x.disabled})));
 T('unearned badges are disabled, not merely unstyled',
   locked.length>0 && locked.every(x=>x.off),
   locked.length+' locked, all disabled');

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
