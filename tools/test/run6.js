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

// One shared in-memory DB across both "phones" via a server-side store
const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 if(DB.leagues.length) return;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 [['p1','u1','MARCO','🦍'],['p2','u2','SARAH','🦊']].forEach(function(x,i){
   DB.profiles.push({id:x[0],user_id:x[1],display_name:x[2],restore_code:'RC'+i,avatar:x[3]});
   DB.members.push({league_id:'lg1',profile_id:x[0],joined_at:'2026-01-0'+(i+1)});});
 window.__log__=function(pid,k,m,a){DB.workouts.push({id:'w'+Math.random().toString(36).slice(2,8),
   league_id:'lg1',profile_id:pid,exercise_key:k,mode:m,amount:a,points:C(k,m,a),
   week_start:W(),created_at:new Date().toISOString()});window.__save__();};
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4404,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 // shared DB object lives in one page; simulate two users by switching __UID__ in the SAME page
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   headers:{'Cache-Control':'no-store'},
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.route('**/sw.js', r => r.abort());
 await pg.addInitScript(()=>{ try{ if(!localStorage.getItem('mock.uid')) localStorage.setItem('mock.uid','u1'); }catch(e){} });
 await pg.goto('http://localhost:4404/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);

 /* ---- MARCO creates a duel ---- */
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(500);
 T('duel tab present', await pg.isVisible('#view-duel'), 'yes');
 T('offers to start a duel', await pg.isVisible('#duelCreateBtn'), 'yes');
 await pg.screenshot({path:path.join(OUT,'50-duel-empty.png')});
 await pg.click('#duelCreateBtn'); await pg.waitForTimeout(700);
 const code=(await pg.textContent('.duel-code')).trim();
 T('code generated + waiting state', /^D[A-Z0-9]{5}$/.test(code), code);
 T('create button hidden while waiting', await pg.isHidden('#duelStart'), 'hidden');
 await pg.screenshot({path:path.join(OUT,'51-duel-pending.png')});

 /* can't open a second one */
 await pg.evaluate(async ()=>{
   const sb=window.supabase.createClient();
   window.__second__=await sb.rpc('create_challenge',{p_league:'lg1'});
 });
 const second=await pg.evaluate(()=>window.__second__.error ? window.__second__.error.message : 'ALLOWED');
 T('second duel blocked', second.includes('ALREADY_IN_CHALLENGE'), second);

 /* ---- SARAH accepts on her phone ---- */
 await pg.evaluate(u=>{ localStorage.setItem('mock.uid',u); localStorage.removeItem('ironleague.league'); }, 'u2');
 await pg.reload(); await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(500);
 await pg.fill('#duelCodeInput', code); await pg.waitForTimeout(900);
 T('preview names the challenger', (await pg.textContent('#duelPreview')).includes('MARCO'), await pg.textContent('#duelPreview'));
 await pg.click('#duelAcceptBtn'); await pg.waitForTimeout(900);
 T('duel goes live for the acceptor', await pg.isVisible('.duel.live'), 'yes');
 T('opponent shown', (await pg.textContent('.duel-body')).includes('MARCO'), 'yes');
 T('countdown running', /\d\d:\d\d:\d\d/.test(await pg.textContent('.duel-clock')), await pg.textContent('.duel-clock'));
 T('log-once warning present', (await pg.textContent('.duel-note')).includes('Log once'), 'yes');

 /* ---- SARAH logs ONE workout; it must feed both ---- */
 await pg.click('#logBtn'); await pg.waitForSelector('#logModal:not([hidden])'); await pg.waitForTimeout(300);
 await pickEx(pg, 'pushups'); await pg.fill('#amountInput','50');
 await pg.click('#addBtn'); await pg.waitForTimeout(500);
 await pg.click('.iconbtn.close'); await pg.waitForTimeout(900);
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(700);
 const sides=await pg.$$eval('.duel-pts', e=>e.map(x=>x.textContent));
 T('duel score updated from that log', sides[0]==='50', sides.join(' vs '));
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(700);
 T('league board counts the same log', (await pg.textContent('#board .row.me .pts')).startsWith('50'), await pg.textContent('#board .row.me .pts'));
 const rows=await pg.evaluate(()=>window.__DB__.workouts.length);
 T('only ONE workout row stored', rows===1, rows+' row(s)');
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(500);
 await pg.screenshot({path:path.join(OUT,'52-duel-live.png')});

 /* ---- expiry: force the duel to end, tab should reset ---- */
 await pg.evaluate(()=>{ window.__DB__.challenges[0].ends_at=new Date(Date.now()-1000).toISOString(); });
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(200);
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(700);
 T('finished duel leaves the active slot', await pg.isVisible('#duelCreateBtn'), 'tab reset');
 T('result recorded in past duels', (await pg.textContent('#duelPast')).includes('WON'), (await pg.textContent('#duelPast')).replace(/\s+/g,' ').slice(0,50));
 await pg.screenshot({path:path.join(OUT,'53-duel-finished.png')});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
