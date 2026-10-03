/* Leaving a league, and coming back on a new phone.

   Two things people could not find. Restore was a second underlined link
   under another underlined link, so they made a new profile and lost their
   rank; leaving was at the bottom of the league settings block, past the
   crest options. And the state underneath them — an account with no league at
   all — had never been walked through, only booted into. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* MARCO owns ALPHA and joined BETA. SARAH joined ALPHA a day after him, so
   when he walks out of it she is the one who has been there longest. */
const SEED=`(function(){var DB=window.__DB__, ws=window.__weekStart__();
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.leagues.push({id:'lg2',name:'BETA', code:'BBB222',owner_id:'p2',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'SARAH',restore_code:'SARAH222'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 DB.members.push({league_id:'lg2',profile_id:'p1',joined_at:'2026-01-03'});
 DB.workouts.push({id:'w1',group_id:'g1',league_id:'lg1',profile_id:'p1',
   exercise_key:'pushups',mode:'reps',amount:100,points:100,week_start:ws,
   created_at:ws+'T09:00:00.000Z',boost:1});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4419,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 /* ================= 1. the login screen ================================= */
 let ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 let pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='unobody';});
 await pg.goto('http://localhost:4419/');
 await pg.waitForSelector('#onboard:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(400);

 T('coming back has a panel of its own, not a second underlined link',
   await pg.$eval('.backcard', e=>getComputedStyle(e).borderStyle!=='none'), 'bordered');
 T('and it says in words what it is for',
   /BEEN HERE BEFORE/.test(await pg.textContent('.backcard')),
   (await pg.textContent('.backcard')).trim().split('\n')[0]);
 /* It must be visible without hunting, and still lose to the primary button:
    a second red button here would send first-timers down the wrong path. */
 const box = await pg.$eval('#restoreToggle', e=>{const r=e.getBoundingClientRect();
   return {top:r.top, w:r.width};});
 T('visible on a phone screen without scrolling', box.top < 1000, Math.round(box.top)+'px down');
 T('but it is not a second primary button',
   !(await pg.$eval('#restoreToggle', e=>e.classList.contains('primary'))), 'ghost');
 T('the enter button is still the loud one',
   await pg.$eval('#enterBtn', e=>e.classList.contains('primary')), 'primary');
 T('the code box is folded away until asked for',
   await pg.$eval('#restoreBox', e=>e.hidden), 'hidden');
 await pg.click('#restoreToggle'); await pg.waitForTimeout(250);
 T('and tapping it opens the code box',
   !(await pg.$eval('#restoreBox', e=>e.hidden)), 'open');
 await pg.screenshot({path:path.join(OUT,'92-login-restore.png'),fullPage:true});

 /* it still actually restores */
 await pg.fill('#restoreInput','SARAH222');
 await pg.click('#restoreBtn');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);
 T('restoring brings the old profile back, not a new one',
   await pg.evaluate(()=>window.__state__.profile.display_name)==='SARAH', 'SARAH');
 await ctx.close();

 /* ================= 2. leaving ========================================== */
 ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 pg.on('dialog', d=>d.accept());
 await pg.goto('http://localhost:4419/');
 await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(600);

 T('leaving sits with the leagues, not at the bottom of the settings',
   await pg.evaluate(()=>{
     const list = document.querySelector('#leagueList').getBoundingClientRect().bottom;
     const box  = document.querySelector('#leaveBox').getBoundingClientRect().top;
     const sect = document.querySelector('#view-me details').getBoundingClientRect().top;
     return box > list && box < sect; }), 'between the list and the settings');
 T('and the button names the league you are standing in',
   (await pg.textContent('#leaveBtn')).indexOf('ALPHA')>=0, await pg.textContent('#leaveBtn'));
 T('an owner is warned who the league goes to',
   /passes to whoever/.test(await pg.textContent('#leaveNote')), 'handover explained');
 await pg.screenshot({path:path.join(OUT,'93-leaving.png'),fullPage:false});

 await pg.click('#leaveBtn'); await pg.waitForTimeout(900);
 T('leaving one league leaves the other alone',
   await pg.evaluate(()=>window.__state__.leagues.length===1 &&
                         window.__state__.leagues[0].name==='BETA'),
   'BETA is still there');
 T('and the league you left passes to its longest-standing member',
   await pg.evaluate(()=>window.__DB__.leagues.find(l=>l.id==='lg1').owner_id==='p2'),
   'SARAH owns ALPHA');
 T('the button retitles itself for the league you are now in',
   (await pg.textContent('#leaveBtn')).indexOf('BETA')>=0, await pg.textContent('#leaveBtn'));

 /* ================= 3. no league at all ================================= */
 await pg.click('#leaveBtn'); await pg.waitForTimeout(900);
 T('leaving the last one is allowed',
   await pg.evaluate(()=>window.__state__.leagues.length===0), 'no leagues');
 T('and it lands on the leagues tab rather than a dead board',
   !(await pg.$eval('#view-me', e=>e.hidden)), 'on the me tab');
 T('which says so in words',
   /not in a league yet/.test(await pg.textContent('#leagueList')),
   (await pg.textContent('#leagueList')).trim().slice(0,40));
 T('the leave panel takes itself away when there is nothing to leave',
   await pg.$eval('#leaveBox', e=>e.hidden), 'hidden');
 T('the profile is still signed in and still itself',
   await pg.evaluate(()=>!!window.__state__.profile &&
                         window.__state__.profile.display_name==='MARCO'), 'MARCO');
 T('and what was logged is still logged',
   await pg.evaluate(()=>window.__DB__.workouts.length>0), 'history intact');
 T('no error was thrown on the way down',
   errs.length===0, errs.join(' | ') || 'clean');
 await pg.screenshot({path:path.join(OUT,'94-no-league.png'),fullPage:false});

 /* and the way back in */
 await pg.fill('#joinCodeInput','BBB222');
 await pg.click('#joinBtn'); await pg.waitForTimeout(900);
 T('joining a code from here puts you straight back in',
   await pg.evaluate(()=>window.__state__.leagues.length===1), 'back in BETA');
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
