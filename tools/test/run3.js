const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 ['MARCO','SARAH','LEO'].forEach(function(n,i){
   DB.profiles.push({id:'p'+(i+1),user_id:'u'+(i+1),display_name:n,restore_code:'RC'+i});
   DB.members.push({league_id:'lg1',profile_id:'p'+(i+1),joined_at:'2026-01-0'+(i+1)});});
 function d(iso,n){var p=iso.split('-');return new Date(Date.UTC(+p[0],+p[1]-1,+p[2]+n)).toISOString().slice(0,10);}
 var cur=W();
 DB.workouts.push({id:'wA',league_id:'lg1',profile_id:'p1',exercise_key:'pushups',mode:'reps',
   amount:100,points:100,week_start:cur,created_at:new Date().toISOString()});
 DB.workouts.push({id:'wOld',league_id:'lg1',profile_id:'p1',exercise_key:'dips',mode:'reps',
   amount:20,points:30,week_start:d(cur,-7),created_at:new Date(Date.now()-8*864e5).toISOString()});
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4401,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[], res=[];
 const T=(n,ok,got)=>res.push([n,ok,got]);
 async function page_(uid){
   const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
   await pg.route('**/sw.js', r => r.abort());
   await pg.addInitScript(u=>{window.__UID__=u;},uid);
   return {ctx,pg};
 }

 /* ---- A. bare link now defaults to JOIN, not create ---- */
 let {ctx,pg}=await page_('n1');
 await pg.goto('http://localhost:4401/');
 await pg.waitForSelector('#onboard:not([hidden])');
 await pg.waitForTimeout(300);
 T('bare link shows LEAGUE CODE field', !(await pg.isHidden('#joinWrap')), 'visible');
 T('bare link hides "name your league"', await pg.isHidden('#newLeagueWrap'), 'hidden');
 T('offers create as secondary link', (await pg.textContent('#modeToggle')).includes('brand new'), await pg.textContent('#modeToggle'));
 await pg.screenshot({path:path.join(OUT,'20-onboard-joinfirst.png')});

 /* live code check */
 await pg.fill('#joinCode','8FE7BB'); await pg.waitForTimeout(700);
 T('valid code confirmed inline', (await pg.textContent('#codeHint')).includes('LEAGUE 1'), await pg.textContent('#codeHint'));
 await pg.screenshot({path:path.join(OUT,'21-code-ok.png')});
 await pg.fill('#joinCode','ZZZZZZ'); await pg.waitForTimeout(700);
 T('bad code caught before signup', (await pg.textContent('#codeHint')).toLowerCase().includes('no league'), await pg.textContent('#codeHint'));

 /* submitting with no code explains itself */
 await pg.fill('#joinCode',''); await pg.fill('#nameInput','NEWBIE');
 await pg.click('#enterBtn'); await pg.waitForTimeout(400);
 T('empty code gives guidance', (await pg.textContent('#onboardErr')).toLowerCase().includes('code'), (await pg.textContent('#onboardErr')).slice(0,60));

 /* join for real */
 await pg.fill('#joinCode','8FE7BB'); await pg.click('#enterBtn');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(600);
 T('joined the right league', (await pg.textContent('#lgName')).trim()==='LEAGUE 1', await pg.textContent('#lgName'));
 T('cap now reads 30', (await pg.textContent('#lgMeta')).includes('/30'), await pg.textContent('#lgMeta'));
 await ctx.close();

 /* ---- B. editing your own entry ---- */
 ({ctx,pg}=await page_('u1'));            // sign in AS MARCO's device
 await pg.goto('http://localhost:4401/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);
 const before=await pg.textContent('#board .row.me .pts');
 await pg.click('#board .row.me .rowbtn'); await pg.waitForTimeout(500);
 await pg.screenshot({path:path.join(OUT,'22-own-feed.png')});
 T('own entry offers an edit button', await pg.isVisible('#board [data-edit]'), 'yes');
 await pg.click('#board [data-edit]'); await pg.waitForTimeout(500);
 T('modal switches to EDIT ENTRY', (await pg.textContent('#sheetTitle')).trim()==='EDIT ENTRY', await pg.textContent('#sheetTitle'));
 T('prefilled with the logged amount', (await pg.inputValue('#amountInput'))==='100', await pg.inputValue('#amountInput'));
 T('button says SAVE CHANGES', (await pg.textContent('#addBtn')).includes('SAVE'), await pg.textContent('#addBtn'));
 await pg.screenshot({path:path.join(OUT,'23-edit-entry.png')});
 await pg.fill('#amountInput','160'); await pg.click('#addBtn');
 await pg.waitForTimeout(900);
 const after=await pg.textContent('#board .row.me .pts');
 T('edit recalculated the score', before.startsWith('100') && after.startsWith('160'), before+' -> '+after);
 await pg.screenshot({path:path.join(OUT,'24-after-edit.png')});
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
