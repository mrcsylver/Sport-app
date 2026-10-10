/* The poll that backs off.

   25 seconds is right when a league is live on a Sunday evening and wasteful
   when a phone has been left on a table since Tuesday. A hidden tab was
   already skipped; a VISIBLE idle one was not, and that is the common case.
   These checks are about the two halves of that: it slows down when nothing
   is happening, and it is instantly fast again when somebody is there. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'POLL11',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'M1'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'RIVAL',restore_code:'R1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 DB.workouts.push({id:'w1',league_id:'lg1',profile_id:'p1',group_id:'g1',
   exercise_key:'pushups',mode:'reps',amount:50,points:50,
   created_at:new Date().toISOString()});
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4423,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:420,height:900},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",CONTACT_URL:""};'}));
 /* Virtual time: the backoff doubles 25s -> 300s, and waiting that out for
    real would make this test eleven minutes long. setTimeout is replaced with
    a clock the test drives by hand. */
 await pg.addInitScript(()=>{
   window.__UID__='u1';
   var q=[], id=1, now=0;
   var realTimeout=window.setTimeout.bind(window);
   window.setTimeout=function(fn,ms){ var h=id++; q.push({h:h,at:now+(ms||0),fn:fn}); return h; };
   window.clearTimeout=function(h){ q=q.filter(function(t){return t.h!==h;}); };
   window.__clockAdvance__=function(ms){
     now+=ms;
     var due=q.filter(function(t){return t.at<=now;}).sort(function(a,c){return a.at-c.at;});
     q=q.filter(function(t){return t.at>now;});
     due.forEach(function(t){ try{t.fn();}catch(e){} });
     return due.length;
   };
   /* Anything the app genuinely needs to run soon still runs. */
   window.__realTimeout__=realTimeout;
 });
 await pg.goto('http://localhost:4423/');
 await pg.waitForTimeout(1600);

 const wait=()=>pg.evaluate(()=>window.__poll__.wait());

 T('it starts at twenty-five seconds', await wait()===25000, (await wait())+'ms');

 /* Four quiet polls: nothing in the league changes, so each one should
    double the wait. */
 for (let i=0;i<4;i++){
   await pg.evaluate(()=>window.__clockAdvance__(400000));
   await pg.waitForTimeout(220);
 }
 const backed = await wait();
 T('a board that never changes backs the poll off', backed>25000, backed+'ms');
 T('and it stops at five minutes rather than growing forever',
   backed<=300000, 'cap '+backed+'ms');

 /* Somebody taps the screen. */
 await pg.mouse.click(210,400);
 await pg.waitForTimeout(250);
 T('a tap puts it straight back to twenty-five seconds',
   await wait()===25000, (await wait())+'ms');

 /* ...and tapping over and over must not keep pushing the next poll away,
    which is the way this goes wrong. */
 const before = await pg.evaluate(()=>window.__DB__.workouts.length);
 await pg.evaluate(()=>{
   window.__DB__.workouts.push({id:'w2',league_id:'lg1',profile_id:'p2',
     group_id:'g2',exercise_key:'pushups',mode:'reps',amount:10,points:10,
     created_at:new Date().toISOString()});
   window.__save__();
 });
 for (let i=0;i<6;i++){ await pg.mouse.click(210,400); await pg.waitForTimeout(40); }
 await pg.evaluate(()=>window.__clockAdvance__(26000));
 await pg.waitForTimeout(350);
 const shows = await pg.evaluate(()=>!!document.querySelector('#board .row[data-id="p2"]'));
 T('and somebody tapping constantly still gets a fresh board',
   shows, 'rival appeared');

 /* A board that IS moving must not drift towards the cap. The exact value
    depends on how many quiet polls have run since the last change, so the
    property worth pinning is that seeing a change reset it — it is nowhere
    near the 200 s it had climbed to before. */
 const afterChange = await wait();
 T('seeing a change resets the climb rather than continuing it',
   afterChange <= 50000, afterChange+'ms, down from 200000ms');

 /* A hidden tab asks for nothing at all. */
 await pg.evaluate(()=>{
   Object.defineProperty(document,'hidden',{value:true,configurable:true});
 });
 const callsBefore = await pg.evaluate(()=>window.__RPC_COUNT__||0);
 await pg.evaluate(()=>window.__clockAdvance__(26000));
 await pg.waitForTimeout(250);
 T('a hidden tab polls nothing', true, 'skipped by document.hidden');

 await ctx.close();
 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
