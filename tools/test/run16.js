/* The weekly budget, in the log sheet, before anything is committed.

   The rule itself is tested in SQL. What this covers is the promise that
   makes it survivable: a person has to meet the discount BEFORE they commit a
   set, not after. A discount discovered afterwards is indistinguishable from
   a broken app — this project has already had to rip out one formula nobody
   could explain, and that is the failure mode being guarded here. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* Wednesday, so no rest day gets in the way whatever the suite runs on. */
const FROZEN = Date.UTC(2026, 8, 16, 12, 0, 0);

/* 180 push-ups already banked this week: 20 short of the 200 budget, so the
   very next set straddles the line — which is the only interesting case. */
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',
                  max_members:36,rest_dow:[7],catchup_dow:null});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-09-01'});
 DB.workouts.push({id:'w1',group_id:'g1',league_id:'lg1',profile_id:'p1',
   exercise_key:'pushups',mode:'reps',amount:180,points:180,boost:1,
   week_start:window.__weekStart__(),created_at:new Date().toISOString()});
 window.__save__();
})();`;

const sel = s => document.querySelector(s);

(async()=>{
 await new Promise(r=>srv.listen(4417,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const ctx=await b.newContext({viewport:{width:420,height:900},timezoneId:'Europe/Paris',
   locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage(); const errs=[];
 pg.on('pageerror',e=>errs.push(e.message));
 await pg.addInitScript(t=>{const R=Date;function F(...a){return a.length?new R(...a):new R(t);}
   F.prototype=R.prototype;F.now=()=>t;F.UTC=R.UTC;F.parse=R.parse;window.Date=F;window.__UID__='u1';},FROZEN);
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.goto('http://localhost:4417/');
 await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);

 const res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 /* the board already shows the week discounted: 180 raw is under the budget */
 const board = await pg.$eval('#board .row.me .pts', e=>e.textContent);
 T('a week under its budget is paid in full', parseFloat(board) === 180, board);

 await pg.click('#logBtn');
 await pg.waitForSelector('#logModal:not([hidden])');
 await pg.waitForTimeout(400);

 const read = () => pg.evaluate(() => ({
   shown: !document.querySelector('#budgetRow').hidden,
   txt: document.querySelector('#budgetTxt').textContent,
   cls: document.querySelector('#budgetFill').className,
   width: document.querySelector('#budgetFill').style.width,
   pts: document.querySelector('#ptsPreview').textContent
 }));

 /* default is 10 push-ups: 180 + 10 = 190, still inside the budget */
 let v = await read();
 T('the budget is on screen before anything is logged', v.shown, String(v.shown));
 T('it names the movement and how full its week is',
   /Push-ups/.test(v.txt) && /190\/200/.test(v.txt), v.txt);
 T('and says nothing about points being taken away',
   !/penal|lost|lose|\-\s*\d/i.test(v.txt), v.txt);
 T('10 more push-ups inside the budget are worth 10', parseFloat(v.pts) === 10, v.pts);

 /* 40 straddles the line: 20 at full price, 20 at half = 30 */
 await pg.fill('#amountInput','40'); await pg.waitForTimeout(250);
 v = await read();
 T('a set that straddles the line is priced across it',
   parseFloat(v.pts) === 30, v.pts + ' (want 20 full + 20 half = 30)');
 T('and the bar says the week is over its full-price budget',
   v.cls === 'half' && /half points/.test(v.txt), v.cls + ' · ' + v.txt);

 /* far past it: 620 raw -> 20 full + 200 half + 400 quarter = 220 */
 await pg.fill('#amountInput','620'); await pg.waitForTimeout(250);
 v = await read();
 T('past twice the budget it is a quarter, never zero',
   parseFloat(v.pts) === 220, v.pts + ' (want 20 + 100 + 100 = 220)');
 T('the bar is full and says so', v.cls === 'quarter' && /full for this week/.test(v.txt),
   v.cls + ' · ' + v.txt);

 /* a movement with its own cap: running is 100 km, not 40 */
 await pg.evaluate(() => { document.querySelector('#exPick').click(); });
 await pg.waitForTimeout(200);
 await pg.fill('#exSearch','Run'); await pg.waitForTimeout(250);
 await pg.click('#exList [data-ex="run"]'); await pg.waitForTimeout(350);
 await pg.fill('#amountInput','100'); await pg.waitForTimeout(250);
 v = await read();
 T('distance cardio carries its own budget, so 100 km of running is full price',
   parseFloat(v.pts) === 500 && /500\/500/.test(v.txt), v.pts + ' · ' + v.txt);
 T('and it is not the push-up budget', /Run/.test(v.txt), v.txt);

 /* commit a discounted set and check the toast, the session and the board */
 await pg.evaluate(() => { document.querySelector('#exPick').click(); });
 await pg.waitForTimeout(200);
 await pg.fill('#exSearch','Push-ups'); await pg.waitForTimeout(250);
 await pg.click('#exList [data-ex="pushups"]'); await pg.waitForTimeout(300);
 await pg.fill('#amountInput','40');
 await pg.click('#addBtn'); await pg.waitForTimeout(600);

 const sess = await pg.evaluate(() => ({
   total: document.querySelector('#sessionTotal').textContent,
   item: document.querySelector('#sessionList .sitem').textContent
 }));
 T('the session counts what the set actually scored', parseFloat(sess.total) === 30, sess.total);
 T('and shows what it would have been at full price',
   /40 at full price/.test(sess.item), sess.item.replace(/\s+/g,' ').trim());

 await pg.click('#doneBtn'); await pg.waitForTimeout(900);
 const after = await pg.$eval('#board .row.me .pts', e=>e.textContent);
 T('the board agrees with the sheet: 180 + 30, not 180 + 40',
   parseFloat(after) === 210, after);

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
