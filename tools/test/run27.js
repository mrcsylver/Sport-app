/* A league that holds more than 36.

   36 was a hard ceiling, and 36 is the number the five divisions come to.
   That is the right size for a group of friends and the wrong one for a
   poster on a gym wall: the 37th person to scan the QR code is turned away
   at the door, and they do not come back.

   Two halves to check. The creator can set the number, at creation and
   afterwards and never below the people already in — and the BOARD still
   reads as a league at that size, which is the half that is easy to forget:
   a hundred people through the old division sizes is five divisions and
   then a crowd of seventy. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* A 100-seat league with 60 people in it, so the board has enough rows for
   the divisions to have to decide something. */
const SEED=`(function(){var DB=window.__DB__, ws=window.__weekStart__();
 DB.leagues.push({id:'lg1',name:'CAMPUS',code:'CAM100',owner_id:'p1',max_members:100,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'OWNER',restore_code:'OWN00001'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 for (var i=2;i<=60;i++){
   DB.profiles.push({id:'p'+i,user_id:'u'+i,display_name:'LIFTER'+i,restore_code:'C'+i});
   DB.members.push({league_id:'lg1',profile_id:'p'+i,joined_at:'2026-01-02'});
   DB.workouts.push({id:'w'+i,group_id:'g'+i,league_id:'lg1',profile_id:'p'+i,
     exercise_key:'pushups',mode:'reps',amount:100-i,points:(100-i),week_start:ws,
     created_at:ws+'T09:00:00.000Z',boost:1});
 }
 DB.workouts.push({id:'w1',group_id:'g1',league_id:'lg1',profile_id:'p1',
   exercise_key:'pushups',mode:'reps',amount:500,points:500,week_start:ws,
   created_at:ws+'T09:00:00.000Z',boost:1});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4427,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:420,height:1200},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4427/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(800);

 /* ---- 1. the arithmetic, on its own ------------------------------------ */
 const sizes = await pg.evaluate(()=>({
   small: window.__tierSizes__(20), full: window.__tierSizes__(36),
   just:  window.__tierSizes__(37), big:  window.__tierSizes__(100)
 }));
 /* Seven letters now, not five invented places, but the shape of the thing
    is unchanged: a fixed split up to 36, then the bottom five growing in
    proportion while the top two never move. */
 T('a league of 36 or fewer is divided by the fixed split',
   JSON.stringify(sizes.full)==='[2,3,5,7,10,6,3]' &&
   JSON.stringify(sizes.small)==='[2,3,5,7,10,6,3]', JSON.stringify(sizes.full));
 T('37 is not a cliff',
   JSON.stringify(sizes.just)==='[2,3,5,7,10,6,4]', JSON.stringify(sizes.just));
 /* The point of the proportional split: without it the leftover sixty-four
    all fell into the bottom division and a league of 100 read as six
    divisions and then a crowd. */
 T('and 100 people are seven divisions, not six and a crowd',
   sizes.big.reduce((a,c)=>a+c,0)===100 && sizes.big[6] < 25,
   JSON.stringify(sizes.big));
 T('the two at the top never grow — being pushed out of them is the point',
   sizes.big[0]===2 && sizes.big[1]===3, sizes.big[0]+'+'+sizes.big[1]);

 /* ---- 2. the board actually draws them --------------------------------- */
 const heads = await pg.$$eval('.divhead-t b', e=>e.map(x=>x.textContent.trim()));
 T('all seven divisions are on a 60-person board',
   heads.length===7, heads.join(' · '));
 const rows = await pg.$$eval('#board .row', e=>e.length);
 T('and every one of the 60 is on it', rows===60, rows+' rows');
 await pg.screenshot({path:path.join(OUT,'97-big-board.png'),fullPage:false});

 /* ---- 3. the owner can resize from settings ---------------------------- */
 await pg.click('[data-view="me"]'); await pg.waitForTimeout(400);
 /* The league block is a <details>; open every one so nothing is hidden
    behind a disclosure the test has to know the name of. */
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{d.open=true;}));
 await pg.waitForTimeout(300);
 T('the size box shows what the league holds',
   await pg.inputValue('#lgSize')==='100', await pg.inputValue('#lgSize'));
 T('and says how far down it is allowed to go',
   /60 in now/.test(await pg.textContent('#lgSizeNow')),
   (await pg.textContent('#lgSizeNow')).trim());

 await pg.fill('#lgSize','80');
 await pg.dispatchEvent('#lgSize','change');
 await pg.waitForTimeout(900);
 T('lowering it to a number above the membership saves',
   await pg.evaluate(()=>window.__DB__.leagues[0].max_members)===80,
   await pg.evaluate(()=>String(window.__DB__.leagues[0].max_members)));

 /* below the 60 who are in it: refused, and said in words */
 await pg.fill('#lgSize','10');
 await pg.dispatchEvent('#lgSize','change');
 await pg.waitForTimeout(900);
 T('below the people already in, it is refused',
   await pg.evaluate(()=>window.__DB__.leagues[0].max_members)===80,
   await pg.evaluate(()=>String(window.__DB__.leagues[0].max_members)));
 T('and the reason is a sentence, not a code',
   /already in/i.test(await pg.textContent('#rulesState')),
   (await pg.textContent('#rulesState')).trim());
 T('the box is put back to what the league actually says',
   await pg.inputValue('#lgSize')==='80', await pg.inputValue('#lgSize'));

 /* ---- 4. creating one at a size ---------------------------------------- */
 await pg.click('#createToggle'); await pg.waitForTimeout(250);
 await pg.fill('#newLeagueInput','GYM FLOOR');
 await pg.fill('#newLeagueSize','100');
 pg.once('dialog', d=>d.accept());
 await pg.click('#createBtn');
 await pg.waitForTimeout(1200);
 T('a new league is created at the size that was asked for',
   await pg.evaluate(()=>{var l=window.__DB__.leagues.filter(function(x){return x.name==='GYM FLOOR';})[0];
     return l && l.max_members===100;}),
   await pg.evaluate(()=>{var l=window.__DB__.leagues.filter(function(x){return x.name==='GYM FLOOR';})[0];
     return l?String(l.max_members):'not created';}));

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
