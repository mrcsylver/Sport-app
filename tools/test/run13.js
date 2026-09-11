/* Balanced scoring: the league setting, what it does to the board, and that
   nothing anybody logged is touched by switching it. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* p1 owns the league and trains 15 minutes; p2 grinds 400 push-ups. */
const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:30});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'BUSY',restore_code:'RC1'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'GRINDER',restore_code:'RC2'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 var cur=W(),id=0;
 function log(pid,k,m,a){DB.workouts.push({id:'w'+(++id),league_id:'lg1',profile_id:pid,
   exercise_key:k,mode:m,amount:a,points:C(k,m,a),week_start:cur,
   created_at:new Date().toISOString()});}
 log('p1','pushups','reps',50); log('p1','pullups','reps',20);
 for(var i=0;i<10;i++) log('p2','pushups','reps',40);
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
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(800);

 const pts = async () => pg.$$eval('#board .row', rows => rows.map(r => ({
   n: r.querySelector('.nm').textContent.trim().replace(/\s*\(YOU\)$/,''),
   p: Number(r.querySelector('.pts').textContent.replace(/PTS/,'')) })));

 const hard = await pts();
 T('hardcore board: grinder has 400', hard.find(x=>x.n==='GRINDER').p===400, JSON.stringify(hard));
 T('hardcore board: busy has 90', hard.find(x=>x.n==='BUSY').p===90, JSON.stringify(hard));
 T('no taper note in a hardcore league',
   !(await pg.textContent('#board')).includes('logged'), 'none');

 /* the setting */
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(300);
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{
   d.open=true; d.dispatchEvent(new Event('toggle'));}));
 await pg.waitForTimeout(300);

 const modes = await pg.$$eval('#scoringPick .mode', e=>e.map(x=>x.getAttribute('data-mode')));
 T('both modes offered', modes.join(',')==='hardcore,balanced', modes.join(','));
 T('the one in use is marked',
   (await pg.textContent('#scoringPick .mode.on')).includes('IN USE'),
   (await pg.textContent('#scoringPick .mode.on')).slice(0,30));
 T('each one explains itself',
   (await pg.textContent('#scoringPick')).includes('fifteen-minute'), 'yes');
 await pg.evaluate(()=>document.querySelector('#scoringPick').scrollIntoView());
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'62-scoring-modes.png')});

 await pg.click('.mode[data-mode="balanced"]');
 await pg.waitForTimeout(800);
 T('the league is now balanced',
   await pg.evaluate(()=>window.__DB__.leagues[0].scoring==='balanced'),
   await pg.evaluate(()=>window.__DB__.leagues[0].scoring));

 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(700);
 const soft = await pts();
 const g = soft.find(x=>x.n==='GRINDER').p, bu = soft.find(x=>x.n==='BUSY').p;
 T('grinder tapered to 197.5', Math.abs(g-197.5)<0.6, String(g));
 T('busy barely touched (87 of 90)', Math.abs(bu-87)<0.6, String(bu));
 T('the gap closed from 310 to about 110', Math.abs((g-bu)-110.5)<1.5, String(Math.round(g-bu)));
 T('your own row says what was logged',
   (await pg.textContent('#board .row.me')).includes('90 logged'),
   (await pg.textContent('#board .row.me')).replace(/\s+/g,' ').slice(0,80));
 T("but not on anybody else's row",
   !(await pg.$$eval('#board .row:not(.me)', r=>r.map(x=>x.textContent).join(''))).includes('logged'),
   'none');
 await pg.screenshot({path:path.join(OUT,'63-balanced-board.png')});

 /* nothing was rewritten */
 T('every logged row keeps its own points',
   await pg.evaluate(()=>window.__DB__.workouts.every(w=>w.points>0)
     && window.__DB__.workouts.filter(w=>w.profile_id==='p2')
          .reduce((s,w)=>s+w.points,0)===400),
   'all 400 still stored');

 /* and switching back restores it exactly */
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(300);
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{d.open=true;}));
 await pg.click('.mode[data-mode="hardcore"]');
 await pg.waitForTimeout(800);
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(700);
 const back = await pts();
 T('switching back restores the raw board',
   back.find(x=>x.n==='GRINDER').p===400 && back.find(x=>x.n==='BUSY').p===90,
   JSON.stringify(back));

 /* somebody who did not make the league cannot change it */
 await pg.evaluate(()=>{window.__DB__.leagues[0].owner_id='p2'; window.__save__();});
 await pg.reload(); await pg.waitForSelector('#app:not([hidden])'); await pg.waitForTimeout(700);
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(300);
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{
   d.open=true; d.dispatchEvent(new Event('toggle'));}));
 await pg.waitForTimeout(300);
 T('a member sees the mode but cannot change it',
   await pg.$$eval('#scoringPick .mode', e=>e.every(x=>x.disabled)), 'disabled');
 T('and is told why',
   (await pg.textContent('#scoringNote')).includes('created the league'),
   await pg.textContent('#scoringNote'));

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
