/* The gym formula, in the browser, through the real log sheet.

   A 50 kg member benched 35 kg, got 8.75 points, and asked why that was
   barely more than a push-up. It was right — at 50 kg a push-up already moves
   32 kg. But looking turned up three lifts where ADDING WEIGHT scored LESS,
   because the number typed into a weighted dip is what hangs from the belt
   and the formula read it as the whole load.

   The SQL suite proves calc_points(). This proves the PREVIEW agrees with it,
   which is the number somebody actually reads before committing a set. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* Wednesday, so the rest day never gets in the way. */
const FROZEN = Date.UTC(2026, 8, 16, 12, 0, 0);
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',
                  max_members:36,rest_dow:[7],catchup_dow:null});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'BRIVICE',restore_code:'RC1',bodyweight:50});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-09-01'});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4418,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',
   locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage(); const errs=[];
 pg.on('pageerror',e=>errs.push(e.message));
 await pg.addInitScript(t=>{const R=Date;function F(...a){return a.length?new R(...a):new R(t);}
   F.prototype=R.prototype;F.now=()=>t;F.UTC=R.UTC;F.parse=R.parse;window.Date=F;window.__UID__='u1';},FROZEN);
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.goto('http://localhost:4418/');
 await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);
 const res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 await pg.click('#logBtn');
 await pg.waitForSelector('#logModal:not([hidden])');
 await pg.waitForTimeout(400);

 /* pick a gym lift, set bodyweight + load, read the preview */
 /* the finder searches names and aliases, never the internal key */
 const NAME = { gymbench:'Bench Press', gymdip:'Weighted Dips',
                gymweightpull:'Weighted Pull-up', gymcalf:'Weighted Calf Raise',
                gymsquat:'Back Squat', gymbackext:'Back Extension' };
 async function preview(key, bw, load, reps) {
   await pg.evaluate(() => { document.querySelector('#exPick').click(); });
   await pg.waitForTimeout(150);
   await pg.fill('#exSearch', NAME[key]); await pg.waitForTimeout(250);
   await pg.click(`#exList [data-ex="${key}"]`); await pg.waitForTimeout(300);
   await pg.fill('#bwInput', String(bw));
   await pg.fill('#loadInput', String(load));
   await pg.fill('#amountInput', String(reps));
   await pg.waitForTimeout(250);
   return pg.evaluate(() => ({
     pts: parseFloat(document.querySelector('#ptsPreview').textContent),
     gymShown: !document.querySelector('#gymRow').hidden,
     note: document.querySelector('#exVariants').textContent
   }));
 }

 /* 1. the bench that started it */
 let v = await preview('gymbench', 50, 35, 8);
 T('the gym fields appear for a barbell lift', v.gymShown, String(v.gymShown));
 /* the preview draws one decimal, so 8.75 reads as 8.8 — compare to the
    stored value with that much room, not to the character on screen */
 T('50 kg lifter, 35 kg bench, 8 reps = 8.75, same as the server gave him',
   Math.abs(v.pts - 8.75) < 0.06, v.pts + ' (want 8.75, shown to 1 dp)');
 T('and the bar is spelled out, because people were typing the plates only',
   /bar plus plates/i.test(v.note) && /20/.test(v.note) && /10/.test(v.note), v.note);

 /* a push-up at 50 kg moves 0.64 x 50 = 32 kg, so a 32 kg bench must match */
 v = await preview('gymbench', 50, 32, 100);
 T('benching your own push-up (32 kg at 50 kg) pays exactly a push-up',
   v.pts === 100, v.pts + ' (want 100)');

 /* 2. the three belt lifts: more weight can never be fewer points */
 for (const [key, name, bare] of [['gymdip','Weighted Dips',1.5],
                                  ['gymweightpull','Weighted Pull-up',2.0],
                                  ['gymcalf','Weighted Calf Raise',0.2]]) {
   const empty = await preview(key, 70, 0, 100);
   const belt  = await preview(key, 70, 20, 100);
   T(name + ' with an empty belt is exactly the bodyweight movement',
     Math.abs(empty.pts - bare * 100) < 0.5, empty.pts + ' (want ' + bare * 100 + ')');
   T(name + ' with 20 kg is worth MORE, not less',
     belt.pts > empty.pts, empty.pts + ' -> ' + belt.pts);
 }

 /* 3. the standing leg lifts did not move */
 /* 0.588 x (0.85 + 60/70) = 1.00378 a rep. `own` 0.85 is exactly what the
    old legs flag did, so this number must not have moved at all. */
 v = await preview('gymsquat', 70, 60, 100);
 T('a 60 kg back squat at 70 kg is priced exactly as it was before',
   Math.abs(v.pts - 0.588 * (0.85 + 60 / 70) * 100) < 0.1,
   v.pts + ' (want 100.38)');

 /* 4. a plate-free gym entry still scores */
 v = await preview('gymbackext', 70, 0, 100);
 T('a back extension with no plate is worth points, not zero',
   v.pts > 20 && v.pts < 35, v.pts + ' for 100 reps (supermans would be 25)');

 /* 5. the new lifts are findable and the two holes are closed */
 const found = await pg.evaluate(() => {
   const out = {};
   for (const q of ['wrist', 'hack', 'pec deck', 'skullcrusher', 'hyperextension',
                    'hammer', 'preacher', 'trap bar']) {
     document.querySelector('#exSearch').value = q;
     document.querySelector('#exSearch').dispatchEvent(new Event('input'));
     out[q] = document.querySelectorAll('#exList [data-ex]').length;
   }
   return out;
 });
 T('every new lift is reachable from the search box',
   Object.values(found).every(n => n > 0), JSON.stringify(found));

 /* 6. and a gym lift really does save at the previewed number */
 v = await preview('gymdip', 70, 20, 10);
 const want = v.pts;
 await pg.click('#addBtn'); await pg.waitForTimeout(700);
 const sess = await pg.evaluate(() => document.querySelector('#sessionTotal').textContent);
 T('what the sheet previewed is what the server stored',
   Math.abs(parseFloat(sess) - want) < 0.02, sess + ' vs previewed ' + want);

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
