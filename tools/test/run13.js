/* The catch-up day: the setting, the rules around it, and that the leader is
   never punished — only unboosted. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:30,rest_dow:[1]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4413,r));
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
 await pg.goto('http://localhost:4413/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);

 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(300);
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{
   d.open=true; d.dispatchEvent(new Event('toggle'));}));
 await pg.waitForTimeout(300);

 T('seven days offered', (await pg.$$('#catchDows .dow')).length===7, '7');
 T('none is chosen to begin with',
   (await pg.$$('#catchDows .dow.on')).length===0, 'none');
 T('it explains what it does',
   (await pg.textContent('#leagueOwnerBox')).includes('×1.4')
   || (await pg.textContent('#leagueOwnerBox')).includes('1.4'), 'yes');

 /* Monday is already the rest day, so it cannot be the catch-up day */
 T('the rest day is greyed out of the catch-up row',
   await pg.$eval('#catchDows [data-catch="1"]', e=>e.disabled), 'Monday disabled');

 await pg.click('#catchDows [data-catch="7"]');
 await pg.waitForTimeout(200);
 T('Sunday picks', (await pg.$$('#catchDows .dow.on')).length===1, 'one');
 /* no SAVE button any more: the toggles save themselves, debounced */
 await pg.waitForTimeout(900);
 T('saved to the league on its own',
   await pg.evaluate(()=>window.__DB__.leagues[0].catchup_dow===7),
   String(await pg.evaluate(()=>window.__DB__.leagues[0].catchup_dow)));

 /* only one day at a time */
 await pg.click('#catchDows [data-catch="6"]'); await pg.waitForTimeout(200);
 T('picking another moves it rather than adding one',
   (await pg.$$('#catchDows .dow.on')).length===1,
   String((await pg.$$('#catchDows .dow.on')).length));
 /* and tapping the chosen one clears it */
 await pg.click('#catchDows [data-catch="6"]'); await pg.waitForTimeout(200);
 T('tapping it again turns it off',
   (await pg.$$('#catchDows .dow.on')).length===0, 'none');
 await pg.waitForTimeout(900);
 T('a league can have no catch-up day at all',
   await pg.evaluate(()=>window.__DB__.leagues[0].catchup_dow===null),
   String(await pg.evaluate(()=>window.__DB__.leagues[0].catchup_dow)));

 /* The bug this replaced: the SAVE button sat three blocks lower, next to
    the season-length dropdown, so people tapped days and closed the app with
    nothing sent. Every control here has to save itself, and say that it did. */
 await pg.click('#restDows [data-dow="3"]'); await pg.waitForTimeout(900);
 T('a rest day saves itself with no button pressed',
   await pg.evaluate(()=>(window.__DB__.leagues[0].rest_dow||[]).indexOf(3)>=0),
   JSON.stringify(await pg.evaluate(()=>window.__DB__.leagues[0].rest_dow)));
 T('and the screen says what is actually in force',
   /^Saved · rest /.test(await pg.textContent('#rulesState')),
   await pg.textContent('#rulesState'));
 await pg.click('#restDows [data-dow="3"]'); await pg.waitForTimeout(900);
 T('turning it back off saves too',
   await pg.evaluate(()=>(window.__DB__.leagues[0].rest_dow||[]).indexOf(3)<0), 'gone');
 T('there is no save button left to miss',
   (await pg.$$('#saveRules')).length===0, 'none');

 /* making a rest day out of the catch-up day takes it away */
 await pg.click('#catchDows [data-catch="7"]'); await pg.waitForTimeout(150);
 await pg.click('#restDows [data-dow="7"]'); await pg.waitForTimeout(250);
 T('marking it a rest day clears the catch-up day',
   (await pg.$$('#catchDows .dow.on')).length===0
   && await pg.$eval('#catchDows [data-catch="7"]', e=>e.disabled),
   'cleared and disabled');

 await pg.evaluate(()=>document.querySelector('#catchDows').scrollIntoView());
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'62-catchup-day.png')});

 /* and the boost shows on a logged entry */
 await pg.evaluate(()=>{
   var DB=window.__DB__;
   DB.workouts.push({id:'wb1',league_id:'lg1',profile_id:'p1',exercise_key:'pushups',
     mode:'reps',amount:100,points:140,boost:1.4,week_start:window.__weekStart__(),
     created_at:new Date().toISOString()});
   window.__save__();
 });
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(600);
 await pg.click('#board .row .rowbtn'); await pg.waitForTimeout(600);
 T('the feed says what it was multiplied by',
   (await pg.textContent('#board')).includes('×1.4'),
   (await pg.textContent('.fitem') || '').replace(/\s+/g,' ').slice(0,60));

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
