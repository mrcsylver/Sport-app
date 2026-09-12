const { chromium } = require('/opt/node22/lib/node_modules/playwright');
/* The settings tab is collapsible now; a test should not care which section
   a control sits in, so open them all before poking at it. */
async function openSects(pg) {
  // setting .open directly does not fire 'toggle' reliably, and the emblem
  // grids are built on that event, so dispatch it ourselves
  await pg.evaluate(() => document.querySelectorAll('details.sect').forEach(d => {
    d.open = true;
    d.dispatchEvent(new Event('toggle'));
  }));
  await pg.waitForTimeout(200);
}

/* The 100-item dropdown became a search picker; drive it the way a thumb would. */
async function pickEx(pg, key) {
  if (!(await pg.$('#exFinder:not([hidden])'))) await pg.click('#exPick');
  const sel = '.exl-i[data-ex="' + key + '"]';
  if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  // groups start collapsed now; open them in turn (it is an accordion, so
  // opening the next one closes the last) until the exercise shows up
  const cats = await pg.$$eval('.exl-h', els => els.map(e => e.getAttribute('data-cat')));
  for (const c of cats) {
    await pg.click('.exl-h[data-cat="' + c + '"]');
    await pg.waitForTimeout(90);
    if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  }
  throw new Error('exercise not in picker: ' + key);
}

const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__;
 if(DB.leagues.length) return;
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1',avatar:'🦍'});
 ['A','B','C'].forEach(function(x,i){
   DB.leagues.push({id:'lg'+i,name:'LEAGUE '+x,code:'CODE0'+i,owner_id:'p1',max_members:30});
   DB.members.push({league_id:'lg'+i,profile_id:'p1',joined_at:'2026-01-0'+(i+1)});});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4406,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const res=[],errs=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
   timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{ try{ localStorage.setItem('mock.uid','u1'); }catch(e){} });
 await pg.goto('http://localhost:4406/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000}); await pg.waitForTimeout(800);

 await pg.click('#logBtn'); await pg.waitForSelector('#logModal:not([hidden])'); await pg.waitForTimeout(400);
 T('sheet warns it counts everywhere', await pg.isVisible('#multiNote'), (await pg.textContent('#multiNote')).trim());
 await pickEx(pg, 'pushups'); await pg.fill('#amountInput','40');
 await pg.click('#addBtn'); await pg.waitForTimeout(700);
 T('toast names the league count', (await pg.textContent('#toast')).includes('3 leagues'), await pg.textContent('#toast'));
 T('one action, three rows', await pg.evaluate(()=>window.__DB__.workouts.length)===3, await pg.evaluate(()=>window.__DB__.workouts.length)+'');
 T('all rows share one group', await pg.evaluate(()=>new Set(window.__DB__.workouts.map(w=>w.group_id)).size)===1, 'yes');
 await pg.click('.iconbtn.close'); await pg.waitForTimeout(900);

 /* every league board shows it */
 const boards=[];
 for (const name of ['LEAGUE A','LEAGUE B','LEAGUE C']) {
   await pg.click('.tab[data-view="me"]'); await openSects(pg); await pg.waitForTimeout(400);
   await pg.click(`.lg-card:has-text("${name}")`); await pg.waitForTimeout(800);
   boards.push(name+'='+(await pg.textContent('#board .row.me .pts')).trim());
 }
 T('counted on all three boards', boards.every(x=>x.includes('40PTS')), boards.join(' '));

 /* edit once -> all three follow */
 await pg.click('#board .row.me .rowbtn'); await pg.waitForTimeout(600);
 await pg.click('#board [data-edit]'); await pg.waitForTimeout(500);
 await pg.fill('#amountInput','90'); await pg.click('#addBtn'); await pg.waitForTimeout(900);
 T('edit propagated to every copy',
   await pg.evaluate(()=>window.__DB__.workouts.every(w=>Number(w.amount)===90))===true,
   await pg.evaluate(()=>window.__DB__.workouts.map(w=>w.amount).join(',')));
 T('this board shows the edit', (await pg.textContent('#board .row.me .pts')).startsWith('90'), await pg.textContent('#board .row.me .pts'));
 await pg.screenshot({path:path.join(OUT,'70-multileague.png')});

 /* delete once -> all three go */
 pg.on('dialog',d=>d.accept());
 await pg.click('#board .row.me .rowbtn'); await pg.waitForTimeout(500);
 if ((await pg.$$('#board [data-del]')).length===0) { await pg.click('#board .row.me .rowbtn'); await pg.waitForTimeout(500); }
 await pg.click('#board [data-del]'); await pg.waitForTimeout(1000);
 T('delete removed every copy', await pg.evaluate(()=>window.__DB__.workouts.length)===0,
   await pg.evaluate(()=>window.__DB__.workouts.length)+' rows left');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
