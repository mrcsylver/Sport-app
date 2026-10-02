/* The cup. A straight knockout for the top of the season over its last four
   weeks, drawn from the season table and stored nowhere. Three scenarios, each
   its own page because each needs its own league shape: a cup in its final
   week, a cup that has not locked yet, and a season with too long to run for a
   cup to be worth showing. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* `age` is how many weeks ago the league was created, which is also the index
   of the week being played. A twelve week season aged 11 means THIS week is the
   final; aged 5 means six weeks still to run, so the draw is on show and still
   moving. Person k scores 1000 - 10k every week, so person k is kth in every
   week and the seeding is predictable enough to assert on. */
const seed = (age, weeks, members, upset) => `(function(){
 var DB=window.__DB__, ws=window.__weekStart__();
 function back(n){var d=new Date(ws+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-7*n);return d.toISOString().slice(0,10);}
 DB.leagues.push({id:'lg1',name:'IRON CUP',code:'CUP111',owner_id:'p01',
   max_members:36,rest_dow:[],season_weeks:${weeks},season_break:0,
   created_at:back(${age})+'T12:00:00.000Z'});
 for(var k=1;k<=${members};k++){
   var id='p'+(k<10?'0':'')+k;
   DB.profiles.push({id:id,user_id:'u'+(k<10?'0':'')+k,
     display_name:'P'+(k<10?'0':'')+k,restore_code:'RC'+k});
   DB.members.push({league_id:'lg1',profile_id:id,joined_at:'2026-01-0'+(k<10?k:1)});
 }
 var id=0;
 for(var w=0;w<=${age};w++){
   for(var k=1;k<=${members};k++){
     var who='p'+(k<10?'0':'')+k;
     /* THE UPSET: the bottom seed outscores the top one in the round of 16. */
     var pts=(${upset?'true':'false'}&&w===8&&k===16)?4000:(1000-10*k);
     DB.workouts.push({id:'w'+(++id),group_id:'g'+id,league_id:'lg1',
       profile_id:who,exercise_key:'pushups',mode:'reps',amount:10,points:pts,
       week_start:back(${age}-w),created_at:back(${age}-w)+'T12:00:00.000Z',boost:1});
   }
 }
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4418,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function boot(SEED, uid) {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
   await pg.addInitScript(u=>{window.__UID__=u;}, uid);
   await pg.goto('http://localhost:4418/');
   await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
   await pg.waitForTimeout(600);
   await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(900);
   return {ctx,pg};
 }

 /* ================= 1. the final week, seen by the fourth seed ============ */
 let {ctx,pg}=await boot(seed(11,12,18,true),'u04');
 T('the cup is on the duels tab', !(await pg.$eval('#cupWrap', e=>e.hidden)),
   await pg.textContent('#cupWhere'));
 T('and it says which round is being played',
   /^FINAL · /.test(await pg.textContent('#cupWhere')),
   await pg.textContent('#cupWhere'));
 const tabs=await pg.$$eval('#cupRounds button', e=>e.map(x=>x.textContent));
 T('four rounds to flick between', tabs.join('/')==='R16/QF/SEMIS/FINAL', tabs.join('/'));
 T('and it opens on the one being played',
   await pg.$eval('#cupRounds button.on', e=>e.textContent)==='FINAL', 'FINAL');
 T('the final is one tie', (await pg.$$('#cupTies .tie')).length===1,
   (await pg.$$('#cupTies .tie')).length+' tie');

 /* the round of 16: eight ties, and the upset has to be in there */
 await pg.click('#cupRounds [data-cupr="1"]'); await pg.waitForTimeout(400);
 T('the round of 16 is eight ties', (await pg.$$('#cupTies .tie')).length===8,
   (await pg.$$('#cupTies .tie')).length+' ties');
 const first=await pg.$eval('#cupTies .tie', e=>({
   won: e.querySelector('.tie-side.won b').textContent,
   out: e.querySelector('.tie-side.out b').textContent }));
 T('points beat seeding: the bottom seed went through',
   first.won==='P16' && first.out==='P01', first.out+' lost to '+first.won);
 T('and a finished tie dims the side that went out',
   (await pg.$$('#cupTies .tie-side.out')).length===8, 'eight losers');

 /* the quarter-final the upset created */
 await pg.click('#cupRounds [data-cupr="2"]'); await pg.waitForTimeout(400);
 T('the upset carried into the quarter-finals',
   (await pg.textContent('#cupTies')).includes('P16'), 'P16 is still in it');

 /* my own tie, lifted out above the round */
 T('your own tie is pulled out above the bracket',
   /SEEDED 4|Seeded 4/.test(await pg.textContent('#cupMine')),
   (await pg.textContent('#cupMine')).replace(/\s+/g,' ').slice(0,90));
 T('and it names who you are playing',
   (await pg.textContent('#cupMine')).includes('P02'),
   (await pg.textContent('#cupMine')).replace(/\s+/g,' ').slice(0,60));
 await pg.click('#cupRounds [data-cupr="4"]'); await pg.waitForTimeout(300);
 await pg.$eval('#cupWrap', e=>e.scrollIntoView({block:'start'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'80-cup-final.png'),fullPage:false});
 await ctx.close();

 /* ================= 2. the same cup, seen from 17th ====================== */
 ({ctx,pg}=await boot(seed(11,12,18,true),'u17'));
 const outside=(await pg.textContent('#cupMine')).replace(/\s+/g,' ');
 T('somebody outside the field is told so', /NOT IN THE CUP/.test(outside), outside.slice(0,40));
 T('and told exactly where they finished', /17th IN THE SEASON/i.test(outside),
   outside.slice(0,70));
 T('the bracket is still there to look at', (await pg.$$('#cupTies .tie')).length===1,
   'the final');
 await ctx.close();

 /* ================= 3. six weeks out: a projection ====================== */
 ({ctx,pg}=await boot(seed(5,12,18,false),'u09'));
 T('before it locks it says when it stops moving',
   /LOCKS IN 3 WEEKS/.test(await pg.textContent('#cupWhere')),
   await pg.textContent('#cupWhere'));
 T('the first round already has sixteen names in it',
   (await pg.$$('#cupTies .tie-side b')).length===16,
   (await pg.$$('#cupTies .tie-side b')).length+' names');
 T('and no tie has been decided',
   (await pg.$$('#cupTies .tie-side.won')).length===0, 'nothing won yet');
 await pg.click('#cupRounds [data-cupr="2"]'); await pg.waitForTimeout(400);
 const open=await pg.$$eval('#cupTies .tie-open', e=>e.map(x=>x.textContent));
 T('a later round shows who can still reach it',
   open.length===8 && open[0]==='#1 / #16' && open[1]==='#8 / #9',
   open.slice(0,2).join(' v '));
 T('the ninth seed is told its seed, not that it is out',
   /Seeded 9/.test(await pg.textContent('#cupMine')),
   (await pg.textContent('#cupMine')).replace(/\s+/g,' ').slice(0,60));
 await pg.click('#cupRounds [data-cupr="1"]'); await pg.waitForTimeout(300);
 await pg.$eval('#cupWrap', e=>e.scrollIntoView({block:'start'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'81-cup-projected.png'),fullPage:false});
 await ctx.close();

 /* ================= 4. too early, and too few =========================== */
 ({ctx,pg}=await boot(seed(2,38,18,false),'u04'));
 T('a season with thirty-five weeks to run shows no bracket',
   await pg.$eval('#cupWrap', e=>e.hidden), 'hidden');
 T('and the duels are still there',
   !(await pg.$eval('#duelStart', e=>e.hidden)), 'duels intact');
 await ctx.close();

 ({ctx,pg}=await boot(seed(11,12,3,false),'u02'));
 T('three players is not a tournament',
   await pg.$eval('#cupWrap', e=>e.hidden), 'hidden');
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
