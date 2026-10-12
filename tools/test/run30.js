/* The growth panel in the control room.

   The app is going on a poster in a corridor, which changes what the control
   room is for. Headcount answers "how many", and that was all it answered.
   The question a poster raises is "is this working", and that is three
   different numbers:

     landed  — somebody opened the app at all
     joined  — of those, somebody typed a name
     back    — of those, somebody returned the following week

   LANDED IS THE ONE THAT CAN QUIETLY BREAK. It counts rows in auth.users
   with no profile behind them, which only means anything because the app
   signs in anonymously at boot and writes a profile later. If profile
   creation ever moves to boot, landed and joined become the same number,
   the conversion column reads 100% forever, and nothing anywhere would say
   so. Section 3 is that check.

   The arithmetic lives in Postgres and is tested in supabase/test/growth.sql.
   What is under test here is the panel: that it asks, that it renders the
   numbers it is given, and above all that a week which has not happened yet
   is drawn as blank rather than as nobody coming back. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const CFG='window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",' +
          'TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",' +
          'SIGN_IN:{GOOGLE:false,EMAIL:false,ANON:true},TURNSTILE_SITE_KEY:""};';

/* Three weeks of history. The cohort joins TWO weeks ago, because retention
   only reports a week that has FINISHED: a cohort that arrived last week
   cannot be judged on this one, which on a Tuesday is one day old. CLARA
   came back the following week; DAN never did.
   __LANDED__ says eight people opened the app that week against three who
   typed a name, so the panel has to show 38% rather than 100%. */
const SEED=`(function(){var DB=window.__DB__;
 var w1=window.__weekStart__(new Date(Date.now()-7*86400000));
 var w2=window.__weekStart__(new Date(Date.now()-14*86400000));
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'ADMIN123',
                   is_admin:true,created_at:w2+'T09:00:00Z'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'CLARA',restore_code:'CLARA001',
                   created_at:w2+'T10:00:00Z'});
 DB.profiles.push({id:'p3',user_id:'u3',display_name:'DAN',restore_code:'DAN00001',
                   created_at:w2+'T11:00:00Z'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:w2});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:w2});
 DB.members.push({league_id:'lg1',profile_id:'p3',joined_at:w2});
 [['p2','g1',w2],['p3','g2',w2],['p2','g3',w1]].forEach(function(r){
   DB.workouts.push({id:'x'+r[1],group_id:r[1],profile_id:r[0],league_id:'lg1',
     exercise_key:'pushups',mode:'reps',amount:10,points:10,week_start:r[2],
     created_at:r[2]+'T12:00:00Z'});
 });
 window.__save__();
})();`;

/* Appended AFTER the mock rather than injected as an init script: it needs
   the mock's own week arithmetic, and an init script runs at document start,
   before vendor/supabase.js has defined anything. */
const LANDED=`(function(){
 var w1=window.__weekStart__(new Date(Date.now()-7*86400000));
 var w2=window.__weekStart__(new Date(Date.now()-14*86400000));
 var m={}; m[w2]=8; m[w1]=4; window.__LANDED__=m;
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4430,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:1100,height:1400},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED+LANDED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:CFG}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4430/admin.html');
 await pg.waitForSelector('#login',{timeout:8000});
 await pg.fill('#code','ADMIN123');
 await pg.click('#go');
 await pg.waitForSelector('#growth tr',{timeout:8000});
 await pg.waitForTimeout(400);

 const rows = await pg.evaluate(()=>Array.from(document.querySelectorAll('#growth tr'))
   .slice(1).map(tr=>Array.from(tr.querySelectorAll('td')).map(td=>td.textContent.trim())));
 const ret = await pg.evaluate(()=>Array.from(document.querySelectorAll('#retention tr'))
   .slice(1).map(tr=>Array.from(tr.querySelectorAll('td')).map(td=>td.textContent.trim())));

 /* ---- 1. the panel is there and asked for twelve weeks ---------------- */
 T('the control room has a growth table', rows.length===12, rows.length+' weeks');

 /* ---- 2. the seeded week's row is the seeded arithmetic --------------- */
 const last = rows[2];
 T('two weeks ago reads 8 landed, 3 joined, 2 of them logged',
   last[1]==='8' && last[2]==='3' && last[4]==='2',
   'landed '+last[1]+', joined '+last[2]+', active '+last[4]);

 /* ---- 3. the conversion column, which is the whole point -------------- */
 /* 3 of 8 is 38%. A panel showing 100% here means landed has collapsed into
    joined, which is what happens if a profile is ever created at boot. */
 T('and the conversion is joined over landed, not 100%',
   last[3]==='38%', last[3]);

 /* ---- 4. a bar is drawn, because five columns of digits hide a trend -- */
 T('each week draws two bars', (await pg.$$('#growth td div')).length===24,
   (await pg.$$('#growth td div')).length+' bars');

 /* ---- 5. retention: a third of that cohort came back ----------------- */
 /* Index 0, not 1: last week's cohort is empty and empty cohorts are not
    listed, so the seeded week is the first row there is. */
 const cohort = ret[0];
 T('three joined that week, one of whom came back the week after',
   cohort[1]==='3' && /^1 /.test(cohort[2]), cohort.join(' | '));

 /* ---- 6. AND THE ONE THAT MATTERS: an unfinished week is blank -------- */
 /* Drawing the week still being played as 0 (0%) would read as "nobody came
    back" and is the single most misleading thing this panel could do: on a
    Tuesday it would make every recent cohort look like a disaster. */
 T('the week still being played is a dash, not 0 (0%)',
   cohort[3]==='—' && cohort[4]==='—', 'two weeks: '+cohort[3]+', four: '+cohort[4]);

 /* ---- 7. empty cohorts are not listed at all ------------------------- */
 T('weeks nobody joined in are left out rather than shown as zeroes',
   ret.length===1, ret.length+' cohort rows');

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
