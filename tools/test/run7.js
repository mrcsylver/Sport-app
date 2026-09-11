const { chromium } = require('/opt/node22/lib/node_modules/playwright');
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

const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 if(DB.leagues.length) return;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1',avatar:'🦍'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 window.__save__();
})();`;

async function boot(b, whenISO){
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
   timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 await pg.clock.install({time:new Date(whenISO)});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{ try{ localStorage.setItem('mock.uid','u1'); }catch(e){} });
 return {ctx,pg};
}

(async()=>{
 await new Promise(r=>srv.listen(4405,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const res=[],errs=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 /* ---------- FRIDAY: normal ---------- */
 let {ctx,pg}=await boot(b,'2026-09-11T10:00:00+02:00');   // Friday
 pg.on('pageerror',e=>errs.push(e.message));
 await pg.goto('http://localhost:4405/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000}); await pg.waitForTimeout(700);
 T('weekday label says league closes', (await pg.textContent('.cd-label')).includes('CLOSES'), await pg.textContent('.cd-label'));
 T('weekday countdown targets Saturday night', (await pg.textContent('#cdTimer')).startsWith('1D'), await pg.textContent('#cdTimer'));
 await pg.click('#logBtn'); await pg.waitForTimeout(500);
 const groups=await pg.$$eval('.exl-h', e=>e.map(x=>x.textContent.trim()));
 T('all groups available on a weekday', groups.length===8, groups.join(','));
 T('no rest notice on a weekday', await pg.isHidden('#restNote'), 'hidden');
 await ctx.close();

 /* ---------- SUNDAY: rest day ---------- */
 ({ctx,pg}=await boot(b,'2026-09-13T10:00:00+02:00'));      // Sunday
 pg.on('pageerror',e=>errs.push(e.message));
 await pg.goto('http://localhost:4405/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000}); await pg.waitForTimeout(800);
 T('rest day label', (await pg.textContent('.cd-label')).includes('REST DAY'), await pg.textContent('.cd-label'));
 T('rest banner replaces the combo card', (await pg.textContent('#comboCard')).includes('LEAGUE CLOSED'), 'yes');
 T('banner explains the one stretch', (await pg.textContent('#comboCard')).includes('stretching session'), 'yes');
 await pg.screenshot({path:path.join(OUT,'60-restday.png')});

 await pg.click('#logBtn'); await pg.waitForTimeout(600);
 const opts=await pg.$$eval('.exl-i', e=>e.map(x=>x.getAttribute('data-ex')));
 T('only recovery offered on a rest day', opts.length>0 && opts.every(k=>k==='stretch'||k==='sauna'), opts.join(','));
 T('rest notice shown in the sheet', await pg.isVisible('#restNote'), await pg.textContent('#restNote'));
 T('add button still enabled before use', !(await pg.isDisabled('#addBtn')), 'enabled');
 await pg.screenshot({path:path.join(OUT,'61-restday-modal.png')});
 await pg.click('#addBtn'); await pg.waitForTimeout(700);
 T('stretch accepted, worth 5', (await pg.textContent('#sessionTotal'))==='5', await pg.textContent('#sessionTotal'));
 T('add button now disabled', await pg.isDisabled('#addBtn'), 'disabled');
 T('notice switches to already logged', (await pg.textContent('#restNote')).includes('already logged'), await pg.textContent('#restNote'));
 await pg.screenshot({path:path.join(OUT,'62-restday-done.png')});

 /* server-side refusals, independent of the UI */
 const forced=await pg.evaluate(async ()=>{
   const sb=window.supabase.createClient();
   const a=await sb.from('workouts').insert({league_id:'lg1',profile_id:'p1',
     exercise_key:'pushups',mode:'reps',amount:100}).select().single();
   const c=await sb.from('workouts').insert({league_id:'lg1',profile_id:'p1',
     exercise_key:'stretch',mode:'flat',amount:1}).select().single();
   return {push:a.error?a.error.message:'ALLOWED', second:c.error?c.error.message:'ALLOWED'};
 });
 T('push-ups refused by the server on Sunday', forced.push==='REST_DAY', forced.push);
 T('second stretch refused by the server', forced.second==='REST_DAY_DONE', forced.second);

 await pg.click('.iconbtn.close'); await pg.waitForTimeout(800);
 await pg.click('#board .row.me .rowbtn'); await pg.waitForTimeout(600);
 T('no edit/delete controls while closed', (await pg.$$('#board [data-edit]')).length===0, 'none');
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
