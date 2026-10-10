/* The cap, the full screen, and a parked seat.

   Parking is not deleting: the account, its rank and everything it logged
   stay exactly where they are, and putting it back is one button — if there
   is room. The screens have to say that, because "FULL" on its own reads as
   "your account is gone". */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

const SEED = (cap, parked) => `(function(){var DB=window.__DB__;
 window.__CAP__ = ${cap === null ? 'null' : cap};
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'CAP111',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'FADER',restore_code:'FADER222'
   ${parked ? ", dormant_at:'2026-01-01T00:00:00.000Z'" : ''}});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4421,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function boot(seed, uid, contact) {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+seed}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",CONTACT_URL:'+JSON.stringify(contact||'')+'};'}));
   await pg.addInitScript(u=>{window.__UID__=u;}, uid);
   await pg.goto('http://localhost:4421/');
   await pg.waitForTimeout(1400);
   return {ctx,pg};
 }

 /* ===== 1. a newcomer arriving at a full app ===== */
 let {ctx,pg}=await boot(SEED(2,false),'unew','mailto:hi@example.com');
 T('a newcomer gets the full screen, not a name box',
   !(await pg.$eval('#full', e=>e.hidden)) && await pg.$eval('#onboard', e=>e.hidden),
   'full');
 T('and is told before typing anything',
   /AT CAPACITY/.test(await pg.textContent('#full')),
   (await pg.textContent('#fullWhy')).trim().slice(0,46));
 T('with a way to ask for a seat',
   await pg.$eval('#fullContact', e=>!e.hidden && e.getAttribute('href')==='mailto:hi@example.com'),
   'contact wired');
 /* the important one: coming back is not a new sign-up */
 T('and the restore box is on the full screen too',
   !(await pg.$eval('#fullRestore', e=>e.hidden)), 'restore offered');
 await pg.screenshot({path:path.join(OUT,'97-full.png'),fullPage:true});
 await pg.fill('#fullRestore','MARCO111');
 await pg.click('#fullRestoreBtn');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 T('an existing account still gets in through a shut door',
   await pg.evaluate(()=>window.__state__.profile.display_name)==='MARCO', 'MARCO');
 await ctx.close();

 /* ===== 2. no contact set: the button hides rather than dying ===== */
 ({ctx,pg}=await boot(SEED(2,false),'unew2',''));
 T('with no contact configured the button hides instead of going nowhere',
   await pg.$eval('#fullContact', e=>e.hidden), 'hidden');
 await ctx.close();

 /* ===== 3. a parked account, with no room ===== */
 ({ctx,pg}=await boot(SEED(1,true),'u2','mailto:hi@example.com'));
 T('a parked account gets the waiting room, not onboarding',
   !(await pg.$eval('#parked', e=>e.hidden)), 'parked');
 T('it is named, so it reads as theirs',
   (await pg.textContent('#parkedName'))==='FADER', await pg.textContent('#parkedName'));
 T('and it says nothing was deleted',
   /nothing has been deleted/i.test(await pg.textContent('#parked')), 'reassured');
 await pg.screenshot({path:path.join(OUT,'98-parked.png'),fullPage:true});
 await pg.click('#parkedRetry'); await pg.waitForTimeout(700);
 T('retrying while still full says so without losing anything',
   /Still full/.test(await pg.textContent('#parkedErr')) &&
     !(await pg.$eval('#parked', e=>e.hidden)),
   (await pg.textContent('#parkedErr')).trim().slice(0,30));
 T('the account is still parked and still intact',
   await pg.evaluate(()=>{const p=window.__DB__.profiles.find(x=>x.id==='p2');
     return !!p.dormant_at && p.restore_code==='FADER222';}), 'intact');
 /* a seat frees up */
 await pg.evaluate(()=>{ window.__CAP__ = 5; });
 await pg.click('#parkedRetry');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 T('and when a seat frees they walk straight back in',
   await pg.evaluate(()=>window.__state__.profile.display_name)==='FADER', 'FADER');
 T('with the park lifted',
   await pg.evaluate(()=>!window.__DB__.profiles.find(x=>x.id==='p2').dormant_at), 'awake');
 await ctx.close();

 /* ===== 4. a parked account with room wakes itself silently ===== */
 ({ctx,pg}=await boot(SEED(null,true),'u2',''));
 T('with no cap at all a parked account just wakes up',
   !(await pg.$eval('#app', e=>e.hidden)), 'straight in');
 await ctx.close();

 /* ===== 5. no cap, no parking: nothing changes for anybody ===== */
 ({ctx,pg}=await boot(SEED(null,false),'unew3',''));
 T('and a newcomer to an uncapped app sees the normal sign-up',
   !(await pg.$eval('#onboard', e=>e.hidden)) && await pg.$eval('#full', e=>e.hidden),
   'onboarding');
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
