/* Tapping somebody's face.

   Tapping a NAME opens that person's week. Tapping their FACE opens who
   they are — which is what you want when somebody you do not recognise is
   above you, and on a campus that is most of them.

   Three things worth checking, and the third is the one that matters:
   the two taps do different things and neither swallows the other; the
   card carries what a person chose to show; and it carries NOTHING ELSE.
   A profile row holds a restore code, and the whole reason this is a
   function rather than a wider leaderboard is so it can choose. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__, ws=window.__weekStart__();
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:36,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111'});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'SARAH',restore_code:'SARAH222',
   avatar:'gi:wolf-head|c=gold', bio:'Third year. Chasing a one-arm.',
   pinned_badges:['champion'], name_color:'gold'});
 DB.profiles.push({id:'p9',user_id:'u9',display_name:'NOBODY',restore_code:'NOBOD999'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-02-01'});
 DB.workouts.push({id:'w1',group_id:'g1',league_id:'lg1',profile_id:'p2',
   exercise_key:'pullups',mode:'reps',amount:60,points:120,week_start:ws,
   created_at:ws+'T09:00:00.000Z',boost:1});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4429,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4429/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(800);

 /* ---- 1. the two taps are different gestures ------------------------- */
 T('the card is shut to begin with',
   await pg.$eval('#cardPop', e=>e.hidden), 'hidden');
 await pg.click('#board .row:not(.me) .rowbtn .who');
 await pg.waitForTimeout(600);
 T('tapping the NAME opens their week, not a card',
   await pg.$eval('#cardPop', e=>e.hidden) &&
   await pg.evaluate(()=>!!document.querySelector('#board .feed')), 'feed open');
 await pg.click('#board .row:not(.me) .rowbtn .who');
 await pg.waitForTimeout(400);

 /* ---- 2. the face opens the card ------------------------------------- */
 await pg.click('#board .row:not(.me) [data-card]');
 await pg.waitForTimeout(600);
 T('tapping the FACE opens the card',
   !(await pg.$eval('#cardPop', e=>e.hidden)), 'open');
 T('and did not also open their week underneath it',
   await pg.evaluate(()=>!document.querySelector('#board .feed')), 'board untouched');
 T('it is the right person', (await pg.textContent('#cardName')).trim()==='SARAH',
   (await pg.textContent('#cardName')).trim());
 T('with the grade their lifetime has earned',
   (await pg.textContent('#cardGrade')).trim().length > 0,
   (await pg.textContent('#cardGrade')).trim());
 T('the lifetime number is there',
   (await pg.textContent('#cardPts')).trim()==='120',
   (await pg.textContent('#cardPts')).trim());
 T('the line they wrote about themselves',
   /one-arm/.test(await pg.textContent('#cardBio')),
   (await pg.textContent('#cardBio')).trim());
 T('their emblem, in the colour they chose',
   await pg.evaluate(()=>!!document.querySelector('#cardArt .av svg')), 'drawn');
 T('and a badge they pinned',
   await pg.evaluate(()=>document.querySelectorAll('#cardBadges .worn').length)===1,
   await pg.evaluate(()=>String(document.querySelectorAll('#cardBadges .worn').length)));
 await pg.screenshot({path:path.join(OUT,'99-player-card.png'),fullPage:false});

 /* ---- 3. what it must NOT carry -------------------------------------- */
 const shown = await pg.textContent('.playercard');
 T('no restore code anywhere on it', !/SARAH222/.test(shown), 'absent');
 T('and nothing the server did not send',
   await pg.evaluate(()=>{
     var c = window.__DB__.profiles.filter(function(p){return p.id==='p2';})[0];
     return !document.querySelector('.playercard').textContent.includes(c.restore_code);
   }), 'clean');

 await pg.click('#cardX'); await pg.waitForTimeout(300);
 T('the cross shuts it', await pg.$eval('#cardPop', e=>e.hidden), 'shut');

 /* ---- 4. somebody you share no league with --------------------------- */
 await pg.evaluate(()=>window.__openCard__('p9'));
 await pg.waitForTimeout(500);
 T('a stranger has no card, and the app says so rather than showing a blank',
   await pg.$eval('#cardPop', e=>e.hidden) &&
   /not in any of your leagues/i.test(await pg.textContent('#toast')),
   (await pg.textContent('#toast')).trim());

 /* ---- 5. writing your own line, where you read it --------------------
    The line is about you, so the place to write it is the place you see
    it, not a box three screens away whose result you then have to go and
    look at. */
 await pg.evaluate(()=>window.__openCard__('p1'));
 await pg.waitForTimeout(500);
 T('your own card offers the box; somebody else\u2019s does not',
   !(await pg.$eval('#cardMine', e=>e.hidden)), 'editable');
 await pg.fill('#cardBioEdit','Second year. Here for the pull-up bar.');
 T('and counts down from 140 as you type',
   (await pg.textContent('#cardBioLeft')).trim()==='102',
   (await pg.textContent('#cardBioLeft')).trim());
 await pg.click('#cardBioSave'); await pg.waitForTimeout(600);
 T('your line saves',
   await pg.evaluate(()=>window.__DB__.profiles[0].bio)==='Second year. Here for the pull-up bar.',
   await pg.evaluate(()=>String(window.__DB__.profiles[0].bio)));
 await pg.click('#cardX'); await pg.waitForTimeout(200);

 /* an empty one clears rather than storing a blank line */
 await pg.evaluate(()=>window.__openCard__('p1'));
 await pg.waitForTimeout(500);
 await pg.fill('#cardBioEdit','   ');
 await pg.click('#cardBioSave'); await pg.waitForTimeout(600);
 T('clearing it stores nothing, not a blank line',
   await pg.evaluate(()=>window.__DB__.profiles[0].bio)===null,
   await pg.evaluate(()=>String(window.__DB__.profiles[0].bio)));
 await pg.click('#cardX'); await pg.waitForTimeout(200);

 /* and a card that is not yours has no box on it at all */
 await pg.evaluate(()=>window.__openCard__('p2'));
 await pg.waitForTimeout(500);
 T('nobody can type into somebody else\u2019s card',
   await pg.$eval('#cardMine', e=>e.hidden), 'read only');
 await pg.click('#cardX'); await pg.waitForTimeout(200);

 /* ---- 6. the settings tab says what is in it ------------------------- */
 await pg.click('[data-view="me"]'); await pg.waitForTimeout(300);
 const heads = await pg.$$eval('#view-me details.sect > summary > span:first-child',
   e=>e.map(x=>x.textContent.trim()));
 T('every section is named for what is inside it',
   JSON.stringify(heads)===JSON.stringify(['MY LEAGUES','HOW I LOOK','ARMOURY',
     'MY ACCOUNT','BODY & UNITS','APP THEME','HOW SCORING WORKS']),
   heads.join(' · '));
 T('the tab is called SETTINGS, which is what it is',
   /SETTINGS/.test(await pg.textContent('.tab[data-view="me"]')),
   (await pg.textContent('.tab[data-view="me"]')).trim());
 T('your name and your restore code sit with your account',
   await pg.evaluate(()=>{
     var a = document.querySelector('#sectAccount');
     return !!a.querySelector('#renameInput') && !!a.querySelector('#restoreCode');
   }), 'together');

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
