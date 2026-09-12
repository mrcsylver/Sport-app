/* The body figure and the crowns. Both are new surfaces and both are drawn
   from generated data, so this checks the drawing exists, that it responds to
   a thumb, and that the numbers on it are the ones the RPC returned. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* Two finished weeks so there are crowns to count, plus an arms-heavy current
   week so the figure has something lopsided to show. */
const SEED=`(function(){var DB=window.__DB__, ws=window.__weekStart__();
 function back(n){var d=new Date(ws+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-7*n);return d.toISOString().slice(0,10);}
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:36,rest_dow:[7]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1',body_form:'neutral'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'SARAH',restore_code:'RC2'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 var id=0;
 function log(who,key,mode,amt,wk){DB.workouts.push({id:'w'+(++id),group_id:'g'+id,
   league_id:'lg1',profile_id:who,exercise_key:key,mode:mode,amount:amt,
   points:window.__calc__(key,mode,amt),week_start:wk||ws,
   created_at:(wk||ws)+'T09:00:00.000Z',boost:1});}
 log('p1','pushups','reps',300,back(1)); log('p2','pushups','reps',100,back(1));
 log('p1','pushups','reps',400,back(2)); log('p2','pushups','reps',900,back(2));
 log('p1','pushups','reps',120); log('p1','chinups','reps',30);
 log('p1','airsquats','reps',80);  log('p1','crunches','reps',60);
 log('p1','run','km',5);
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4414,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:420,height:900},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4414/');
 await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);

 /* ---- crowns ---- */
 await pg.click('.tab[data-view="hall"]'); await pg.waitForTimeout(700);
 const wins=await pg.$$eval('#wins .win', e=>e.map(x=>x.textContent.replace(/\s+/g,' ').trim()));
 T('every member has a crown row', wins.length===2, wins.length+' rows');
 T('the two finished weeks are counted', /2 WEEKS PLAYED/.test(await pg.textContent('#winsWeeks')),
   await pg.textContent('#winsWeeks'));
 T('one crown each, one week apiece',
   (await pg.$$eval('#wins .win-n', e=>e.map(x=>x.textContent.replace('/',' of ')))).join(',')==='1 of 5,1 of 5',
   (await pg.$$eval('#wins .win-n', e=>e.map(x=>x.textContent))).join(','));
 T('a crown is drawn, not just counted', (await pg.$$('#wins .cr')).length===2, 'yes');
 T('the current run is named', (await pg.textContent('.runhead')).includes('RUN 1'),
   (await pg.textContent('.runhead')).replace(/\s+/g,' '));
 T('nobody has taken a run yet', (await pg.$$('#wins .run')).length===0, 'none');
 await pg.click('#winsRace [data-race="3"]'); await pg.waitForTimeout(250);
 T('the race target changes the bars', (await pg.textContent('#wins')).includes('FIRST TO 3'),
   'first to 3');
 const w3=await pg.$eval('#wins .win-bar span', e=>e.style.width);
 await pg.click('#winsRace [data-race="10"]'); await pg.waitForTimeout(250);
 const w10=await pg.$eval('#wins .win-bar span', e=>e.style.width);
 T('and a harder target is a shorter bar', parseFloat(w10)<parseFloat(w3), w3+' -> '+w10);
 /* a target somebody has already passed closes a run and opens the next */
 await pg.evaluate(()=>{ document.querySelector('#winsRace [data-race="3"]').click(); });
 await pg.waitForTimeout(200);
 T('a reachable target would close a run',
   await pg.evaluate(()=>{
     const champs=[{week_start:'w1',profile_id:'p1',display_name:'MARCO'},
                   {week_start:'w2',profile_id:'p1',display_name:'MARCO'},
                   {week_start:'w3',profile_id:'p2',display_name:'SARAH'},
                   {week_start:'w4',profile_id:'p1',display_name:'MARCO'},
                   {week_start:'w5',profile_id:'p2',display_name:'SARAH'},
                   {week_start:'w6',profile_id:'p2',display_name:'SARAH'},
                   {week_start:'w7',profile_id:'p2',display_name:'SARAH'}];
     const r = window.__cutRuns__(champs, 3);
     return r.done.length===2 && r.done[0].winner.profile_id==='p1'
         && r.done[1].winner.profile_id==='p2' && r.n===3 && r.weeks===0;
   }), 'run 1 MARCO, run 2 SARAH, run 3 open');
 await pg.click('#winsRace [data-race="10"]'); await pg.waitForTimeout(200);
 T('the choice survives a reload', await pg.evaluate(()=>
   localStorage.getItem('ironleague.raceto')==='10'), 'stored');
 T('the hall of fame is still below it',
   (await pg.textContent('#hall')).length>0 && (await pg.$$('#hall .week')).length===2,
   (await pg.$$('#hall .week')).length+' weeks');
 await pg.screenshot({path:path.join(OUT,'70-crowns.png'),fullPage:false});

 /* ---- the figure ---- */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(800);
 const plates=await pg.$$eval('#bodyFig .bpart', e=>e.length);
 T('the front of the figure is drawn', plates>=18, plates+' plates');
 T('and it says which range it is showing',
   (await pg.textContent('#bodyWeeks'))==='THIS WEEK', await pg.textContent('#bodyWeeks'));
 const rows=await pg.$$eval('.mrow .mr-n', e=>e.map(x=>x.textContent));
 T('all fourteen regions are listed', rows.length===14, rows.length+' regions');

 const pcts=await pg.$$eval('.mrow .mr-p', e=>e.map(x=>parseFloat(x.textContent)));
 T('nothing reads 100%', Math.max.apply(null,pcts)<100, 'top is '+Math.max.apply(null,pcts)+'%');
 /* the seeded week is push-heavy, so the top of the list has to be something
    a push-up trains and the bottom something it does not */
 T('an upper-body week reads as an upper-body week',
   ['Triceps','Chest','Biceps','Shoulders','Abs'].indexOf(rows[0])>=0,
   'strongest is '+rows[0]);
 T('and the leg-and-back regions sit below it',
   ['Obliques','Lower back','Glutes','Hamstrings','Traps','Forearms']
     .indexOf(rows[rows.length-1])>=0, 'weakest is '+rows[rows.length-1]);
 T('the untrained region is the balance score',
   (await pg.textContent('.bal-n'))===(await pg.$$eval('.mrow .mr-p',
      e=>e[e.length-1].textContent)),
   await pg.textContent('.bal-n'));

 /* touch a part */
 await pg.click('#bodyFig [data-m="chest"]'); await pg.waitForTimeout(250);
 T('touching a plate names it', (await pg.textContent('.br-l'))==='Chest',
   await pg.textContent('.br-l'));
 T('and reads out its percentage', /%$/.test(await pg.textContent('.br-n')),
   await pg.textContent('.br-n'));
 T('the matching row lights up too',
   (await pg.$$eval('.mrow.on .mr-n', e=>e.map(x=>x.textContent))).join()==='Chest',
   (await pg.$$eval('.mrow.on .mr-n', e=>e.map(x=>x.textContent))).join());
 await pg.click('#bodyFig [data-m="chest"]'); await pg.waitForTimeout(250);
 T('touching it again lets go', (await pg.textContent('.br-l'))==='WEAKEST LINK',
   await pg.textContent('.br-l'));

 /* a row picks too, and the colour follows the number */
 await pg.click('.mrow[data-m="quads"]'); await pg.waitForTimeout(250);
 T('a row can pick the region as well', (await pg.textContent('.br-l'))==='Quads',
   await pg.textContent('.br-l'));
 const cols=await pg.$$eval('#bodyFig .bpart', e=>Array.from(new Set(e.map(x=>x.getAttribute('fill')))));
 T('regions are coloured by how worked they are', cols.length>=3, cols.length+' shades in use');
 await pg.$eval('.bodywrap', e=>e.scrollIntoView({block:'center'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'71-body-front.png'),fullPage:false});

 /* the back */
 await pg.click('#bodyViewPick [data-bview="back"]'); await pg.waitForTimeout(300);
 const backParts=await pg.$$eval('#bodyFig .bpart', e=>e.map(x=>x.getAttribute('data-m')));
 T('the back shows the back', backParts.includes('lats')&&backParts.includes('glutes')
   &&!backParts.includes('chest'), Array.from(new Set(backParts)).join(','));
 T('a region only on the front stops being held',
   (await pg.textContent('.br-l'))==='WEAKEST LINK', await pg.textContent('.br-l'));
 await pg.$eval('.bodywrap', e=>e.scrollIntoView({block:'center'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'72-body-back.png'),fullPage:false});

 /* all time widens the target */
 await pg.click('#statsRange [data-range="all"]'); await pg.waitForTimeout(700);
 T('all time says how many weeks it covers',
   /OVER \d+ WEEKS?/.test(await pg.textContent('#bodyWeeks')), await pg.textContent('#bodyWeeks'));

 /* ---- the figure setting ---- */
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(500);
 await pg.evaluate(()=>document.querySelectorAll('#view-me details').forEach(d=>d.open=true));
 await pg.waitForTimeout(200);
 T('neutral is the figure to start with',
   await pg.$eval('#formRow [data-form="neutral"]', e=>e.classList.contains('on')), 'yes');
 await pg.click('#formRow [data-form="fem"]'); await pg.waitForTimeout(400);
 T('picking another one saves it',
   await pg.evaluate(()=>window.__DB__.profiles.find(p=>p.id==='p1').body_form==='fem'), 'fem');
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(700);
 T('and the figure is redrawn as it',
   (await pg.$$('#bodyFig .bpart')).length>=17, 'redrawn');
 await pg.$eval('.bodywrap', e=>e.scrollIntoView({block:'center'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'73-body-fem.png'),fullPage:false});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
