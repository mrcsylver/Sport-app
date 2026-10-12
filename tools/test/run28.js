/* The two nudges: attach your account, and challenge a friend.

   Both exist because of the same thing — somebody who has just logged their
   first workout has something worth keeping and nobody to show it to — and
   both are the kind of thing that turns into an advert if it is done
   carelessly. So what is actually under test here is the RESTRAINT:

   · neither appears before a workout has landed
   · the banner goes away for good when it is crossed, and goes away by
     itself the moment an account is attached
   · the share prompt happens once, ever, and never again

   The share sheet itself is stubbed. navigator.share does not exist in a
   headless browser, and what matters here is that the app reaches for it
   with the right words in it. */
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
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p1',max_members:36,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 window.__save__();
})();`;

async function logOne(pg) {
  await pg.click('#logBtn');
  await pg.waitForSelector('#logModal:not([hidden])',{timeout:8000});
  await pg.waitForTimeout(250);
  await pg.fill('#amountInput','40');
  await pg.click('#addBtn');
  await pg.waitForTimeout(500);
  await pg.click('#doneBtn');
  await pg.waitForTimeout(900);
}

(async()=>{
 await new Promise(r=>srv.listen(4428,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function open(uid, fresh) {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",SIGN_IN:{GOOGLE:true,EMAIL:true,ANON:true}};'}));
   /* Opt in to the share prompt, and record what the app tries to send
      instead of opening a sheet that does not exist here. */
   await pg.addInitScript(u=>{
     window.__UID__=u;
     window.__ASK_SHARE__=true;
     window.__SHARED__=[];
     navigator.share = function (d) { window.__SHARED__.push(d); return Promise.resolve(); };
   }, uid);
   await pg.goto('http://localhost:4428/');
   /* A uid with no profile lands on the door, not the board. */
   await pg.waitForSelector(fresh ? '#onboard:not([hidden])' : '#app:not([hidden])',
                            {timeout:9000});
   await pg.waitForTimeout(600);
   return { ctx, pg };
 }

 /* ======== 1. before anything is logged, neither of them exists ======== */
 const { ctx, pg } = await open('u1');
 T('no banner before the first workout — there is nothing to lose yet',
   await pg.$eval('#nudge', e=>e.hidden), 'hidden');
 T('and no share prompt either',
   await pg.$eval('#sharePop', e=>e.hidden), 'hidden');

 /* ======== 2. log one, and both arrive ================================= */
 await logOne(pg);
 T('the share prompt comes up once a workout has landed',
   !(await pg.$eval('#sharePop', e=>e.hidden)), 'shown');
 T('and it says what the score actually is',
   /\d/.test(await pg.textContent('#shareSub')),
   (await pg.textContent('#shareSub')).trim().slice(0,60));
 await pg.screenshot({path:path.join(OUT,'98-share-prompt.png'),fullPage:false});

 await pg.click('#shareGo');
 await pg.waitForTimeout(400);
 const sent = await pg.evaluate(()=>window.__SHARED__[0] || null);
 T('sending it reaches the share sheet with the league link in it',
   !!sent && /#\/join\/AAA111/.test(sent.url || ''), sent ? sent.url : 'nothing sent');
 T('and the message names the person, the points and the league',
   !!sent && /MARCO/.test(sent.text) && /pts this week/.test(sent.text) &&
   /ALPHA/.test(sent.text), sent ? sent.text.split('\n')[0] : '—');
 T('the prompt closes behind it', await pg.$eval('#sharePop', e=>e.hidden), 'closed');

 /* ======== 3. and never again ========================================== */
 await logOne(pg);
 T('a second workout does not ask again — once is a prompt, twice is an advert',
   await pg.$eval('#sharePop', e=>e.hidden), 'still closed');

 /* ======== 4. the banner is there, and leads somewhere ================= */
 T('the banner is up now that there is something to lose',
   !(await pg.$eval('#nudge', e=>e.hidden)), 'shown');
 T('and it says what to do about it, not that something is wrong',
   /attach google/i.test(await pg.textContent('#nudgeGo')),
   (await pg.textContent('#nudgeGo')).trim());
 await pg.click('#nudgeGo');
 await pg.waitForTimeout(500);
 T('tapping it opens the account panel rather than explaining where it is',
   await pg.evaluate(()=>document.querySelector('#sectAccount').open) &&
   await pg.evaluate(()=>!document.querySelector('#view-me').hidden), 'open');

 /* ======== 5. share this week, from your own row ======================= */
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(400);
 await pg.click('#board .row.me .rowbtn');
 await pg.waitForTimeout(700);
 T('your own feed offers to share the week; nobody else’s does',
   await pg.evaluate(()=>document.querySelectorAll('[data-shareweek]').length)===1,
   await pg.evaluate(()=>String(document.querySelectorAll('[data-shareweek]').length)));
 await pg.evaluate(()=>{window.__SHARED__.length=0;});
 await pg.click('[data-shareweek]');
 await pg.waitForTimeout(400);
 const week = await pg.evaluate(()=>window.__SHARED__[0] || null);
 T('and it sends the week itself, not just a number',
   !!week && /Push-up/.test(week.text) && /·/.test(week.text),
   week ? week.text.replace(/\n/g,' | ').slice(0,80) : 'nothing sent');

 /* ======== 6. crossing the banner off is permanent ===================== */
 await pg.click('#nudgeX');
 await pg.waitForTimeout(300);
 T('crossing the banner off hides it', await pg.$eval('#nudge', e=>e.hidden), 'hidden');
 await pg.reload();
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(700);
 T('and it stays gone across a reload',
   await pg.$eval('#nudge', e=>e.hidden), 'still hidden');
 await ctx.close();

 /* ======== 7. attaching an account removes it without being asked ====== */
 {
   const o = await open('u2', true);
   await o.pg.fill('#nameInput','SECOND');
   await o.pg.fill('#joinCode','AAA111');
   await o.pg.click('#enterBtn');
   await o.pg.waitForSelector('#app:not([hidden])',{timeout:9000});
   await o.pg.waitForTimeout(700);
   {
     await logOne(o.pg);
     await o.pg.click('#shareSkip').catch(()=>{});
     await o.pg.waitForTimeout(300);
     T('a second person sees the banner too',
       !(await o.pg.$eval('#nudge', e=>e.hidden)), 'shown');
     /* Through the real panel, not round the side of it: what is being
        checked is that the app notices, and the app only notices on the
        path a person actually takes. */
     await o.pg.click('[data-view="me"]'); await o.pg.waitForTimeout(300);
     await o.pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{d.open=true;}));
     await o.pg.fill('#acctEmail','second@example.test');
     await o.pg.fill('#acctPass','a-long-enough-password');
     await o.pg.click('#emailBtn');
     await o.pg.waitForTimeout(900);
     T('and it disappears the moment an account is attached, uncrossed',
       await o.pg.$eval('#nudge', e=>e.hidden), 'gone');
   }
   await o.ctx.close();
 }

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
