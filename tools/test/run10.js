const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

function seed(bounty){ return `(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 window.__BOUNTY__=${JSON.stringify(bounty)};
 if(DB.leagues.length) return;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 [['p1','u1','MARCO','🦍'],['p2','u2','SARAH','🦊']].forEach(function(x,i){
   DB.profiles.push({id:x[0],user_id:x[1],display_name:x[2],restore_code:'RC'+i,avatar:x[3]});
   DB.members.push({league_id:'lg1',profile_id:x[0],joined_at:'2026-01-0'+(i+1)});});
 DB.workouts.push({id:'w1',group_id:'g1',league_id:'lg1',profile_id:'p1',exercise_key:'pushups',
   mode:'reps',amount:30,points:30,week_start:W(),created_at:new Date().toISOString()});
 window.__save__();})();`; }

(async()=>{
 await new Promise(r=>srv.listen(4408,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const res=[],errs=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function open_(bounty){
  const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
    timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
  const pg=await ctx.newPage();
  pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
  await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},body:MOCK+seed(bounty)}));
  await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},
    body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
  await pg.addInitScript(()=>{ try{ localStorage.setItem('mock.uid','u1'); }catch(e){} });
  await pg.goto('http://localhost:4408/');
  await pg.waitForSelector('#app:not([hidden])',{timeout:9000}); await pg.waitForTimeout(800);
  return {ctx,pg};
 }

 /* not yet done by me */
 let {ctx,pg}=await open_({idx:35,name:'FIVE K',descr:'Run 5 km',points:15,
   on_date:'2026-09-10',mine:false,winners:0,first_name:null,first_avatar:null});
 await pg.evaluate(()=>{const w=document.querySelector('#weekBox'); if(w) w.open=true;});
 await pg.waitForTimeout(250);
 T('bounty card visible', await pg.isVisible('#bountyCard'), 'yes');
 T('card names its state', /THURSDAY|TODAY|CLOSED/i.test(await pg.textContent('.bo-tag')), await pg.textContent('.bo-tag'));
 T('shows quest + reward', (await pg.textContent('.bo-name'))==='FIVE K' && (await pg.textContent('.bo-pts'))==='+15',
   (await pg.textContent('.bo-name'))+' '+(await pg.textContent('.bo-pts')));
 T('describes what to do', (await pg.textContent('.bo-desc'))==='Run 5 km', await pg.textContent('.bo-desc'));
 T('says nobody claimed it', (await pg.textContent('.bo-foot')).includes('Nobody'), await pg.textContent('.bo-foot'));
 T('states the day-only rule', /not before, not after|today only|is over/i.test(await pg.textContent('.bo-rule')), await pg.textContent('.bo-rule'));
 T('not marked as done', !(await pg.$eval('#bountyCard', e=>e.classList.contains('got'))), 'plain');
 await pg.screenshot({path:path.join(OUT,'90-bounty-open.png')});
 await ctx.close();

 /* done by me, someone else was first */
 ({ctx,pg}=await open_({idx:35,name:'FIVE K',descr:'Run 5 km',points:15,
   on_date:'2026-09-10',mine:true,winners:3,first_name:'SARAH',first_avatar:'🦊'}));
 T('marked done when earned', await pg.$eval('#bountyCard', e=>e.classList.contains('got')), 'got');
 T('tick on the points', (await pg.textContent('.bo-pts')).includes('✓'), await pg.textContent('.bo-pts'));
 T('counts the finishers', (await pg.textContent('.bo-foot')).includes('3 have done it'), await pg.textContent('.bo-foot'));
 T('credits first blood', (await pg.textContent('.bo-foot')).includes('SARAH'), await pg.textContent('.bo-foot'));
 await pg.screenshot({path:path.join(OUT,'91-bounty-done.png')});
 await ctx.close();

 /* the bounty day itself */
 const today = new Date().toLocaleDateString('en-CA',{timeZone:'Europe/Paris'});
 ({ctx,pg}=await open_({idx:35,name:'FIVE K',descr:'Run 5 km',points:15,
   on_date:today,mine:false,winners:0,first_name:null,first_avatar:null}));
 T('tag says today only', (await pg.textContent('.bo-tag')).includes('TODAY ONLY'), await pg.textContent('.bo-tag'));
 T('rule mentions midnight', (await pg.textContent('.bo-rule')).includes('midnight'), await pg.textContent('.bo-rule'));
 T('highlighted while live', await pg.$eval('#bountyCard', e=>e.classList.contains('now')), 'now');
 await pg.screenshot({path:path.join(OUT,'92-bounty-today.png')});
 await ctx.close();

 /* after the day has passed */
 ({ctx,pg}=await open_({idx:35,name:'FIVE K',descr:'Run 5 km',points:15,
   on_date:'2026-09-03',mine:false,winners:0,first_name:null,first_avatar:null}));
 T('closed once the day is gone', (await pg.textContent('.bo-tag')).includes('CLOSED'), await pg.textContent('.bo-tag'));
 T('dimmed when closed', await pg.$eval('#bountyCard', e=>e.classList.contains('shut')), 'shut');
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
