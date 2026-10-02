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
 function wk0(n){var d=new Date(ws+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-7*n);return d.toISOString();}
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:36,rest_dow:[7],season_weeks:38,created_at:wk0(8)});
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
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4414/');
 await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);

 /* ---- the season table ----
    It replaced a "first to five crowns" race whose fatal hole was that only a
    winner ever moved: anybody who could not realistically top the board had
    nothing to chase by Wednesday, which is exactly how people fade. Two
    members, one win each — so their season totals must come out IDENTICAL at
    5.00 + 3.60, which is the cleanest proof that places are what pay. */
 await pg.click('.tab[data-view="hall"]'); await pg.waitForTimeout(700);
 T('the season table is the first thing on the hall tab',
   await pg.$eval('#sectSeason', e=>e.open), 'open by default');
 T('and says where you stand on the tab itself',
   /WEEK 2\/38 · YOU 1st/.test(await pg.textContent('#seasonWhere')),
   await pg.textContent('#seasonWhere'));
 T('iron will still folds away', await pg.$eval('#sectStreaks', e=>!e.open), 'shut');

 const sea = await pg.$$eval('#seasonTable .sea', e=>e.map(x=>({
   pos: x.querySelector('.sea-p').textContent.trim(),
   who: x.querySelector('.sea-w b').textContent.trim(),
   sub: x.querySelector('.sea-w i').textContent.replace(/\s+/g,' ').trim(),
   pts: x.querySelector('.sea-n').textContent.trim()
 })));
 T('every member is on the table', sea.length===2, sea.length+' rows');
 T('a win and a second is 5.00 + 3.60 = 8.6',
   sea.every(r=>r.pts==='8.6'), sea.map(r=>r.who+' '+r.pts).join(', '));
 T('positions are numbered down the table',
   sea.map(r=>r.pos).join(',')==='1,2', sea.map(r=>r.pos).join(','));
 T('the row says how many weeks, the crown, and the best place',
   /2 weeks/.test(sea[0].sub) && /best 1st/.test(sea[0].sub), sea[0].sub);
 T('a crown is drawn, not just counted',
   (await pg.$$('#seasonTable .cr')).length===2, 'one each');
 T('the header names the season and how far in it is',
   /2 of 38/.test(await pg.textContent('.seahead')),
   (await pg.textContent('.seahead')).replace(/\s+/g,' ').trim());

 /* The payout table is behind one tap: read once, then never again. */
 T('what each place pays is folded away',
   await pg.$eval('#sectPayout', e=>!e.open), 'shut');
 await pg.$eval('#sectPayout', e=>{e.open=true;}); await pg.waitForTimeout(250);
 const pay = await pg.$$eval('#payout .pay', e=>e.map(x=>x.textContent.trim()));
 T('twenty places are priced, 1st down to 20th',
   pay.length===20 && pay[0].indexOf('1st')===0 && pay[19].indexOf('20th')===0,
   pay.length+' places: '+pay[0]+' … '+pay[19]);
 T('the client table matches the server to the decimal',
   await pg.evaluate(()=>{
     const p = window.__RANK_POINTS__;
     return p.length===20 && p[0]===5 && p[19]===0.1
       && p.every((v,i)=>i===0||v<p[i-1]);          // strictly decreasing
   }), '5.00 down to 0.10, every step down');

 /* The race is gone, and nothing that drove it is left behind. */
 T('the crowns race is gone from the page',
   await pg.evaluate(()=>!document.querySelector('#winsRace')
     && !document.querySelector('#wins') && !document.querySelector('#sectCrowns')),
   'no race switch, no run board');

 /* ---- hall of fame: the newest week out in the open, the rest behind a tap */
 T('only the latest week is out in the open',
   (await pg.$$('#hall .week')).length===1, (await pg.$$('#hall .week')).length+' week');
 T('and the earlier ones are behind one tap',
   await pg.$eval('#sectPastWeeks', e=>!e.open && !e.hidden), 'shut but there');
 T('the tab says how many are hidden',
   (await pg.textContent('#pastCount')).trim()==='1 WEEK',
   await pg.textContent('#pastCount'));
 await pg.$eval('#sectPastWeeks', e=>{e.open=true;}); await pg.waitForTimeout(250);
 T('opening it shows the rest', (await pg.$$('#hallPast .week')).length===1,
   (await pg.$$('#hallPast .week')).length+' earlier week');
 /* a week inside the dropdown still expands, which needs its own listener */
 await pg.click('#hallPast [data-week]'); await pg.waitForTimeout(300);
 T('and a hidden week still opens to its full table',
   (await pg.$$('#hallPast .week-body .mini')).length===2,
   (await pg.$$('#hallPast .week-body .mini')).length+' placings');
 T('each placing shows what the season paid for it',
   /\+5\.00/.test(await pg.textContent('#hallPast .week-body')) &&
   /\+3\.60/.test(await pg.textContent('#hallPast .week-body')),
   (await pg.textContent('#hallPast .week-body')).replace(/\s+/g,' ').trim());
 await pg.screenshot({path:path.join(OUT,'70-season.png'),fullPage:false});

 /* ---- the figure ---- */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(800);
 T('the fourteen regions fold away as well',
   await pg.$eval('#sectMuscles', e=>!e.open), 'shut');
 T('with the weakest one on the tab',
   /%\s*WEAKEST/.test(await pg.textContent('#muscleCount')),
   await pg.textContent('#muscleCount'));
 await pg.$eval('#sectMuscles', e=>{e.open=true;}); await pg.waitForTimeout(250);
 const plates=await pg.$$eval('#bodyFig .bpart', e=>e.length);
 T('the front of the figure is drawn', plates>=18, plates+' plates');
 T('and the headline counts the regions filled',
   /^\d+ \/ 14 FILLED$/.test(await pg.textContent('#bodyWeeks')),
   await pg.textContent('#bodyWeeks'));
 const rows=await pg.$$eval('.mrow .mr-n', e=>e.map(x=>x.textContent));
 T('all fourteen regions are listed', rows.length===14, rows.length+' regions');

 const pcts=await pg.$$eval('.mrow .mr-p', e=>e.map(x=>parseFloat(x.textContent)));
 T('100% means a full week of that muscle, and is reachable',
   pcts.every(p=>p>=0), 'top is '+Math.max.apply(null,pcts)+'% of a week');
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

 /* suggestions: what to actually do about the region being shown */
 const fixes = await pg.$$eval('#bodyFix .fix-b', e=>e.map(x=>x.textContent));
 T('the weakest region comes with a way out', fixes.length===3, fixes.join(' | '));
 T('and each suggestion is priced', fixes.every(t=>/\d/.test(t)), fixes[0]);
 T('nothing needing a gym or a pitch is suggested',
   await pg.evaluate(()=>Array.from(document.querySelectorAll('#bodyFix [data-fix]'))
     .every(b=>!/^gym/.test(b.getAttribute('data-fix')))), 'bodyweight only');
 T('the suggestions follow the region you are holding',
   await pg.evaluate(async()=>{
     const hit = q => document.querySelector(q).dispatchEvent(
       new MouseEvent('click', {bubbles:true}));
     hit('#bodyFig [data-m="chest"]');
     await new Promise(r=>setTimeout(r,200));
     const a = document.querySelector('#bodyFix .fix-l').textContent;
     hit('#bodyFig [data-m="quads"]');
     await new Promise(r=>setTimeout(r,200));
     return a.includes('CHEST') &&
            document.querySelector('#bodyFix .fix-l').textContent.includes('QUADS');
   }), 'chest then quads');
 T('a region already half done needs less than an empty one',
   await pg.evaluate(()=>{
     const empty = window.__fixFor__({key:'chest',name:'Chest',pct:0,target:70,points:0});
     const half  = window.__fixFor__({key:'chest',name:'Chest',pct:50,target:70,points:35});
     const n = t => parseFloat((t.match(/>([\d.]+) /)||[0,0])[1]);
     return n(half) > 0 && n(half) < n(empty);
   }), 'yes');
 T('a region already full says so instead of inventing a chore',
   await pg.evaluate(()=>{
     const html = window.__fixFor__(
       {key:'abs',name:'Abs',pct:140,target:45,points:63},
       {key:'lats',name:'Lats',pct:9,target:70,points:6});
     return /ABS IS FULL FOR THE WEEK/.test(html) && /data-jump="lats"/.test(html);
   }), 'sends you to the weak one');
 T('tapping that redirect holds the weak region',
   await pg.evaluate(async()=>{
     const before = document.querySelector('.br-l').textContent;
     document.querySelector('#bodyFix').innerHTML =
       window.__fixFor__({key:'abs',name:'Abs',pct:140,target:45,points:63},
                         {key:'lats',name:'Lats',pct:9,target:70,points:6});
     document.querySelector('#bodyFix [data-jump]')
       .dispatchEvent(new MouseEvent('click',{bubbles:true}));
     await new Promise(r=>setTimeout(r,200));
     return document.querySelector('.br-l').textContent === 'Lats' && before !== 'Lats';
   }), 'holds Lats');
 T('and no suggestion asks for more than a week of anything',
   await pg.evaluate(()=>{
     const caps = {reps:400, seconds:900, minutes:40, km:20, flat:6};
     return ['chest','lats','quads','abs','calves','lowerback'].every(function (k) {
       const html = window.__fixFor__({key:k,name:k,pct:20,target:80,points:16}, null);
       return (html.match(/<i>([\d.]+) (\w+)</g) || []).every(function (bit) {
         const m = /<i>([\d.]+) (\w+)</.exec(bit);
         const unit = {reps:'reps',sec:'seconds',min:'minutes',km:'km'}[m[2]] || m[2];
         return parseFloat(m[1]) <= (caps[unit] || 200);
       });
     });
   }), 'all inside a week');

 /* tapping one opens the log sheet already set to it */
 await pg.evaluate(()=>{document.querySelector('#bodyFig [data-m="quads"]')
   .dispatchEvent(new MouseEvent('click',{bubbles:true}));});
 await pg.waitForTimeout(200);
 const firstFix = await pg.$eval('#bodyFix [data-fix]', e=>e.getAttribute('data-fix'));
 await pg.click('#bodyFix [data-fix]'); await pg.waitForTimeout(500);
 T('tapping one opens the log sheet on that exercise',
   await pg.evaluate(k=>!document.querySelector('#logModal').hidden &&
      document.querySelector('#exPickName').textContent ===
      window.__EXNAME__(k), firstFix), firstFix);
 await pg.click('#logModal .iconbtn.close'); await pg.waitForTimeout(400);

 /* a row picks too, and the colour follows the number */
 /* chest, not quads: the fix chip above already left quads held, and a second
    tap on the same region is a release rather than a pick */
 await pg.click('.mrow[data-m="chest"]'); await pg.waitForTimeout(250);
 T('a row can pick the region as well', (await pg.textContent('.br-l'))==='Chest',
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
   /\d+ \/ 14 FILLED · \d+W/.test(await pg.textContent('#bodyWeeks')),
   await pg.textContent('#bodyWeeks'));

 /* ---- the figure setting ---- */
 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(500);
 await pg.evaluate(()=>document.querySelectorAll('#view-me details').forEach(d=>d.open=true));
 await pg.waitForTimeout(200);
 T('two bodies to choose between, male lit to start with',
   (await pg.$$('#formRow [data-form]')).length===2 &&
   await pg.$eval('#formRow [data-form="masc"]', e=>e.classList.contains('on')),
   'male');
 const maleFront = await pg.evaluate(()=>window.__BODY__.masc.front.length);
 await pg.click('#formRow [data-form="fem"]'); await pg.waitForTimeout(400);
 T('picking the other one saves it',
   await pg.evaluate(()=>window.__DB__.profiles.find(p=>p.id==='p1').body_form==='fem'), 'fem');
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(700);
 T('and the figure is redrawn as the other body',
   (await pg.$$('#bodyFig .bpart')).length>=17, 'redrawn');
 T('the two bodies are actually different art',
   await pg.evaluate(m=>window.__BODY__.fem.front.map(p=>p.d).join('') !==
                        window.__BODY__.masc.front.map(p=>p.d).join('') , maleFront),
   'different paths');
 T('and the rest of the body is drawn but not tappable',
   (await pg.$$('#bodyFig .bskin')).length > 10 &&
   await pg.evaluate(()=>getComputedStyle(document.querySelector('.bskin'))
     .pointerEvents === 'none'), 'head, hands, feet');
 await pg.$eval('.bodywrap', e=>e.scrollIntoView({block:'center'}));
 await pg.waitForTimeout(200);
 await pg.screenshot({path:path.join(OUT,'73-body-fem.png'),fullPage:false});

 /* ---- the stats tab's third range ----
    WEEK and ALL TIME left the season — the unit the league actually plays in —
    with no tab of its own, so "how is my season going" could only be answered
    from the hall table, which shows placings rather than what you lifted.
    The season is bounded BELOW by the Monday it opened, which means the test
    needs a league whose season has already turned over once: a five week
    season and a log older than the current one, so the three ranges have to
    come out different. */
 await pg.evaluate(()=>{
   const DB = window.__DB__, ws = window.__weekStart__();
   const back = n => { const d = new Date(ws+'T00:00:00Z');
     d.setUTCDate(d.getUTCDate()-7*n); return d.toISOString().slice(0,10); };
   const lg = DB.leagues.find(l=>l.id==='lg1');
   lg.season_weeks = 5; lg.season_break = 0;
   DB.workouts.push({id:'wold',group_id:'gold',league_id:'lg1',profile_id:'p1',
     exercise_key:'pushups',mode:'reps',amount:100,
     points:window.__calc__('pushups','reps',100),week_start:back(5),
     created_at:back(5)+'T09:00:00.000Z',boost:1});
   window.__save__();
 });
 await pg.reload(); await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(800);
 T('the stats tab offers three ranges, not two',
   (await pg.$$('#statsRange [data-range]')).length===3,
   (await pg.$$eval('#statsRange [data-range]', e=>e.map(x=>x.textContent))).join('/'));
 const total = async () => Number((await pg.textContent('#statPoints')).replace(/[^\d.]/g,''));
 const week = await total();
 await pg.click('#statsRange [data-range="all"]'); await pg.waitForTimeout(700);
 const all = await total();
 await pg.click('#statsRange [data-range="season"]'); await pg.waitForTimeout(700);
 const season = await total();
 T('a season is more than a week and less than a lifetime',
   week < season && season < all, week+' < '+season+' < '+all);
 T('and it is bounded by the Monday the season opened',
   await pg.evaluate(()=>{
     const r = window.__statsRange__();
     return r.p_all === true &&
            r.p_from === window.__state__.seasonInfo.first_week;
   }), 'p_from = first_week');
 T('the figure is held to the same weeks as the table',
   /\d+ \/ 14 FILLED · \d+W/.test(await pg.textContent('#bodyWeeks')),
   await pg.textContent('#bodyWeeks'));
 /* The rank ladder is a lifetime thing whatever the tab is showing. A season
    tab that reset somebody's rank would read as the app losing their work. */
 T('but the rank ladder still counts a whole lifetime',
   await pg.evaluate(a=>{
     const pips = Array.from(document.querySelectorAll('.ms-pip'));
     const lit = pips.filter(p=>p.classList.contains('on')).length;
     return lit >= 1 && a > 0;
   }, all), 'lifetime, not the season');
 await pg.screenshot({path:path.join(OUT,'74-stats-season.png'),fullPage:false});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
