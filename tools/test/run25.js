/* Guessing a restore code from the login screen.

   A restore code is 32 bits and hands over a whole account. Typed by a person
   that is fine; typed by a script behind a QR code on a gym wall it is a
   number you walk. The server now stops answering a caller after ten failures
   in an hour — and because it has to RECORD those failures, a wrong code comes
   back as an empty answer rather than an error (a raise would roll the record
   back; supabase/restore-throttle.sql has the whole story).

   So there are two things to check here that no SQL test can: that an empty
   answer still reads as "wrong code" to a person, and that the lockout is a
   sentence rather than a stack trace. */
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
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'VICTIM',restore_code:'AAAA1111'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4425,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message));
 pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{window.__UID__='uguess';});
 await pg.goto('http://localhost:4425/');
 await pg.waitForSelector('#onboard:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(400);
 await pg.click('#restoreToggle'); await pg.waitForTimeout(250);

 /* 1. the first wrong code: an empty answer, read as a wrong code */
 await pg.fill('#restoreInput','DEAD0001');
 await pg.click('#restoreBtn'); await pg.waitForTimeout(350);
 T('an empty answer still reads as a wrong code, not a crash',
   /does not match/i.test(await pg.textContent('#onboardErr')),
   (await pg.textContent('#onboardErr')).trim());
 T('and it did not let anybody in',
   !(await pg.$eval('#onboard', e=>e.hidden)), 'still on the login screen');

 /* 2. nine more — people mistype, so ten is the allowance */
 for (let i=2;i<=10;i++){
   await pg.fill('#restoreInput','DEAD'+String(i).padStart(4,'0'));
   await pg.click('#restoreBtn'); await pg.waitForTimeout(140);
 }
 T('ten tries are all answered the same way',
   /does not match/i.test(await pg.textContent('#onboardErr')),
   (await pg.textContent('#onboardErr')).trim());
 T('and all ten were recorded',
   await pg.evaluate(()=>window.__DB__.restoreTries['uguess'].length===10),
   await pg.evaluate(()=>String((window.__DB__.restoreTries['uguess']||[]).length)+' failures'));

 /* 3. the eleventh is refused, in words */
 await pg.fill('#restoreInput','DEAD9999');
 await pg.click('#restoreBtn'); await pg.waitForTimeout(350);
 const locked = (await pg.textContent('#onboardErr')).trim();
 T('the eleventh says wait an hour, in a sentence',
   /wait an hour/i.test(locked) && !/TOO_MANY_TRIES/.test(locked), locked);
 await pg.screenshot({path:path.join(OUT,'95-restore-locked.png'),fullPage:false});

 /* 4. the point of the whole thing: the RIGHT code is refused too, so a
       script that finally lands on one cannot spend it */
 await pg.fill('#restoreInput','AAAA1111');
 await pg.click('#restoreBtn'); await pg.waitForTimeout(400);
 T('even the right code is refused while they are locked out',
   /wait an hour/i.test(await pg.textContent('#onboardErr')),
   (await pg.textContent('#onboardErr')).trim());
 T('so the account they were guessing at never moved',
   await pg.evaluate(()=>window.__DB__.profiles[0].user_id==='u1'), 'u1');
 T('and they are still outside',
   !(await pg.$eval('#onboard', e=>e.hidden)), 'login screen');

 /* 5. a different phone is not punished for the guesser */
 const ctx2=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg2=await ctx2.newPage();
 pg2.on('pageerror',e=>errs.push(e.message));
 await pg2.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg2.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg2.addInitScript(()=>{window.__UID__='uclean';});
 await pg2.goto('http://localhost:4425/');
 await pg2.waitForSelector('#onboard:not([hidden])',{timeout:9000});
 await pg2.waitForTimeout(400);
 await pg2.click('#restoreToggle'); await pg2.waitForTimeout(250);
 await pg2.fill('#restoreInput','AAAA1111');
 await pg2.click('#restoreBtn');
 await pg2.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg2.waitForTimeout(600);
 T('the real owner, on a clean phone, walks straight in',
   await pg2.evaluate(()=>window.__state__.profile.display_name)==='VICTIM', 'VICTIM');
 T('no error was thrown anywhere on the way',
   errs.length===0, errs.join(' | ') || 'clean');

 await ctx.close(); await ctx2.close();
 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
