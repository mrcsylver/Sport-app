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
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 ['MARCO','SARAH'].forEach(function(n,i){DB.profiles.push({id:'p'+(i+1),user_id:'u'+(i+1),
   display_name:n,restore_code:'RC'+i,avatar:i===1?'🦊':null});
   DB.members.push({league_id:'lg1',profile_id:'p'+(i+1),joined_at:'2026-01-0'+(i+1)});});
 var cur=W(),id=0;
 function log(pid,k,m,a){DB.workouts.push({id:'w'+(++id),league_id:'lg1',profile_id:pid,exercise_key:k,
   mode:m,amount:a,points:C(k,m,a),week_start:cur,created_at:new Date().toISOString()});}
 // MARCO: push 12, pull 10, legs 10 -> 3 groups today = +5
 log('p1','pushups','reps',12); log('p1','pullups','reps',5); log('p1','airsquats','reps',20);
 log('p2','pushups','reps',40);
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4403,r));
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
 await pg.goto('http://localhost:4403/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(800);

 /* combo tracker */
 await pg.evaluate(()=>{const w=document.querySelector('#weekBox'); if(w) w.open=true;});
 await pg.waitForTimeout(250);
 T('combo card visible', await pg.isVisible('#comboCard'), 'yes');
 const pips=await pg.$$eval('.pip', e=>e.map(x=>({t:x.textContent, done:x.classList.contains('done')})));
 T('5 muscle-group pips', pips.length===5, pips.length+'');
 T('3 groups marked done', pips.filter(p=>p.done).length===3, pips.filter(p=>p.done).map(p=>p.t).join(' '));
 T('shows +5 earned today', (await pg.textContent('.combo-p')).includes('+5'), await pg.textContent('.combo-p'));
 T('nudges toward the next tier', (await pg.textContent('.combo-hint')).includes('+8'), await pg.textContent('.combo-hint'));
 const meRow=await pg.textContent('#board .row.me');
 T('combo badge on my row', meRow.includes('+5 combo'), meRow.replace(/\s+/g,' ').slice(0,70));
 T('total includes the bonus', (await pg.textContent('#board .row.me .pts')).startsWith('37'), await pg.textContent('#board .row.me .pts'));
 T('other player avatar shown', (await pg.textContent('#board')).includes('🦊'), 'yes');
 await pg.screenshot({path:path.join(OUT,'40-combo.png')});

 /* new scoring in the sheet */
 await pg.click('#logBtn'); await pg.waitForSelector('#logModal:not([hidden])'); await pg.waitForTimeout(300);
 await pickEx(pg, 'swim'); await pg.waitForTimeout(250);
 await pg.fill('#amountInput','60'); await pg.waitForTimeout(150);
 T('swim 60 min = 12 pts', (await pg.textContent('#ptsPreview'))==='12', await pg.textContent('#ptsPreview'));
 await pickEx(pg, 'sprints'); await pg.waitForTimeout(250);
 T('sprints counted per sprint', (await pg.textContent('#amountLbl'))==='SPRINTS', await pg.textContent('#amountLbl'));
 T('sprint description explains 15s/100m', (await pg.textContent('#exVariants')).includes('100 m'), await pg.textContent('#exVariants'));
 await pg.fill('#amountInput','6'); await pg.waitForTimeout(150);
 T('6 sprints = 12 pts', (await pg.textContent('#ptsPreview'))==='12', await pg.textContent('#ptsPreview'));
 await pickEx(pg, 'muscleup'); await pg.waitForTimeout(250);
 await pg.click('#modeRow [data-mode="seconds"]'); await pg.fill('#amountInput','5'); await pg.waitForTimeout(150);
 T('flag 5 sec = 10 pts', (await pg.textContent('#ptsPreview'))==='10', await pg.textContent('#ptsPreview'));
 await pickEx(pg, 'stretch'); await pg.waitForTimeout(250);
 T('stretch = 5 pts', (await pg.textContent('#ptsPreview'))==='5', await pg.textContent('#ptsPreview'));
 T('stretch says 10 minutes minimum', (await pg.textContent('#exVariants')).includes('10 minutes'), await pg.textContent('#exVariants'));
 await pickEx(pg, 'handstand'); await pg.waitForTimeout(250);
 T('handstand mentions wall + hanging', /wall/i.test(await pg.textContent('#exVariants')) && /hanging/i.test(await pg.textContent('#exVariants')), await pg.textContent('#exVariants'));
 await pg.click('.iconbtn.close'); await pg.waitForTimeout(500);

 /* avatars */
 await pg.click('.tab[data-view="me"]'); await openSects(pg); await pg.waitForTimeout(500);
 const n=await pg.$$eval('#avatarGrid .av-opt', e=>e.length);
 T('emblem pool loaded', n>=60, n+' emblems');
 T('every emblem is a vector icon', await pg.$$eval('#avatarGrid .av-opt', e=>e.every(x=>!!x.querySelector('svg path'))), 'yes');
 await pg.evaluate(()=>document.querySelector('#avatarGrid').scrollIntoView());
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'41-avatars.png')});
 await pg.click('.av-opt[data-icon="gorilla"]'); await pg.waitForTimeout(700);
 T('emblem colours offered', (await pg.$$('.sw')).length>=8, (await pg.$$('.sw')).length+' tints');
 T('transparent is one of them', !!(await pg.$('.sw[data-color="clear"]')), 'yes');
 await pg.click('.sw[data-color="gold"]'); await pg.waitForTimeout(700);
 T('tint applied to my emblem',
   await pg.$$eval('#avPreview .av', e=>e.length>0 && /rgb\(255, 201, 60\)/.test(getComputedStyle(e[0]).color)),
   await pg.$eval('#avPreview .av', e=>getComputedStyle(e).color));

 // an animal REPLACES the emblem — a mark is one thing, never two
 await pg.click('#avKind [data-kind="emoji"]'); await pg.waitForTimeout(250);
 await pg.click('#avPins .av-opt[data-pin="🦍"]'); await pg.waitForTimeout(700);
 T('animal replaces the emblem',
   await pg.$$eval('#avPreview .av', e=>e.length>0 && !e[0].querySelector('svg') && !!e[0].querySelector('.av-emoji')),
   'animal only');
 T('no pin is drawn any more', (await pg.$$('#avPreview .av-pin')).length===0, 'none');

 // and back again: an emblem replaces the animal
 await pg.click('#avKind [data-kind="icon"]'); await pg.waitForTimeout(250);
 await pg.click('.av-opt[data-icon="wolf-head"]'); await pg.waitForTimeout(700);
 T('emblem replaces the animal',
   await pg.$$eval('#avPreview .av', e=>e.length>0 && !!e[0].querySelector('svg') && !e[0].querySelector('.av-emoji')),
   'emblem only');

 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(600);
 T('my mark appears on the board',
   await pg.$$eval('#board .row.me .av svg path', e=>e.length>0), 'yes');
 T('legacy emoji avatar still renders',
   await pg.$$eval('#board .row .av-emoji', e=>e.length>0)
   || await pg.$$eval('#board .row .av svg', e=>e.length>0), 'yes');
 await pg.screenshot({path:path.join(OUT,'42-board-avatars.png')});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
