/* The control room is a separate page and nothing had ever loaded it in a
   browser — which is how it shipped once reading a config global that did not
   exist. This covers the page itself and the bounty tools on it. */
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
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:30});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'ADMIN123',is_admin:true});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'SARAH',restore_code:'RC2'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4412,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:1200,height:900},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4412/admin.html');
 await pg.waitForSelector('#login',{timeout:8000});

 T('the page reads its config', await pg.evaluate(()=>!!window.APP_CONFIG), 'yes');

 await pg.fill('#code','ADMIN123');
 await pg.click('#go');
 await pg.waitForSelector('#panel:not([hidden])',{timeout:8000});
 await pg.waitForTimeout(600);

 T('signed in as the admin', (await pg.textContent('#who')).includes('MARCO'), await pg.textContent('#who'));
 T('no error on load', (await pg.textContent('#err')).trim()==='', await pg.textContent('#err'));
 T('leagues listed', (await pg.textContent('#leagues')).includes('IRON CIRCLE'), 'yes');
 T('players listed', (await pg.textContent('#players')).includes('SARAH'), 'yes');

 /* the bounty schedule */
 const weeks = await pg.$$eval('#schedule tr', e=>e.length-1);
 T('six months of weeks shown', weeks===26, weeks+' weeks');
 T('this week is marked', (await pg.textContent('#schedule')).includes('NOW'), 'yes');
 const opts = await pg.$$eval('#schedule select:first-of-type option', e=>e.length);
 T('every quest is choosable', opts>=3, opts+' options');

 /* pinning one */
 const firstWeek = await pg.$eval('#schedule select', e=>e.getAttribute('data-week'));
 await pg.selectOption('#schedule select[data-week="'+firstWeek+'"]', '2');
 await pg.waitForTimeout(500);
 T('pin saved', await pg.evaluate(w=>window.__DB__.schedule[w]===2, firstWeek),
   JSON.stringify(await pg.evaluate(()=>window.__DB__.schedule)));
 T('row now says PINNED', (await pg.textContent('#schedule')).includes('PINNED'), 'yes');
 T('the pinned quest is the one chosen',
   (await pg.textContent('#schedule tr:nth-child(2)')).includes('THREE-MINUTE PLANK'),
   (await pg.textContent('#schedule tr:nth-child(2)')).replace(/\s+/g,' ').slice(0,60));

 await pg.click('[data-unpin="'+firstWeek+'"]');
 await pg.waitForTimeout(500);
 T('unpin removes it', await pg.evaluate(w=>window.__DB__.schedule[w]===undefined, firstWeek), 'yes');

 /* writing one */
 await pg.evaluate(()=>document.querySelectorAll('details').forEach(d=>d.open=true));
 await pg.waitForTimeout(200);
 const modes = await pg.$$eval('#nbMode option', e=>e.map(x=>x.value));
 T('modes follow the exercise', modes.join(',')==='reps', modes.join(','));
 await pg.selectOption('#nbEx','plank');
 await pg.waitForTimeout(200);
 T('picking plank switches to minutes',
   (await pg.$$eval('#nbMode option', e=>e.map(x=>x.value))).join(',')==='minutes',
   (await pg.$$eval('#nbMode option', e=>e.map(x=>x.value))).join(','));

 await pg.fill('#nbName','LUNCH HOLD');
 await pg.fill('#nbDescr','Two minutes of plank at lunch');
 await pg.fill('#nbPoints','25');
 await pg.fill('#nbMin','2');
 await pg.click('#nbAdd');
 await pg.waitForTimeout(600);
 T('the new quest is in the pool',
   await pg.evaluate(()=>window.__DB__.bounties.some(b=>b.name==='LUNCH HOLD')),
   JSON.stringify(await pg.evaluate(()=>window.__DB__.bounties.map(b=>b.name))));
 T('it is marked as yours', (await pg.textContent('#pool')).includes('YOURS'), 'yes');

 /* and a bad one is refused, with the reason shown */
 await pg.fill('#nbName','NOPE');
 await pg.fill('#nbPoints','500');
 await pg.click('#nbAdd');
 await pg.waitForTimeout(400);
 T('bad points refused with a reason',
   (await pg.textContent('#err')).toLowerCase().includes('between 5 and 100'),
   await pg.textContent('#err'));

 /* deleting a custom one, but not a built-in */
 const customIdx = await pg.evaluate(()=>window.__DB__.bounties.find(b=>b.name==='LUNCH HOLD').idx);
 pg.on('dialog', d=>d.accept());
 await pg.click('[data-db="'+customIdx+'"]');
 await pg.waitForTimeout(500);
 T('custom quest deleted',
   !(await pg.evaluate(()=>window.__DB__.bounties.some(b=>b.name==='LUNCH HOLD'))), 'gone');
 T('built-ins offer no delete button',
   (await pg.$$('[data-db="0"]')).length===0, 'none');

 await pg.screenshot({path:path.join(OUT,'61-admin-bounties.png'),fullPage:false});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
