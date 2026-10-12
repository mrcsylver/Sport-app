/* The gate on the door — Cloudflare Turnstile.

   The front door of this app is Supabase's anonymous sign-in, which writes a
   row in auth.users, and the key that calls it is public by design. Without
   a gate a script can mint accounts until a free database is full, and each
   fresh identity also buys ten more guesses at somebody else's restore code.

   Two things to prove, and the first matters more than the second:

   1. WITH NO SITE KEY NOTHING CHANGES. No script is fetched, no challenge is
      asked for, nobody is held at the door. This is the shipped state, so a
      regression here breaks the app for everybody at once.
   2. WITH A KEY the token reaches the three calls Supabase checks — signup,
      password sign-in, anonymous sign-in — and is NOT sent on the ones it
      does not check, because a token spent somewhere Supabase ignores is a
      token the next real call cannot reuse.

   Cloudflare's own script is stubbed. What is under test is this app's
   wiring, not Cloudflare's widget. */
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
 window.__save__();
})();`;

/* Cloudflare's api.js, as far as this app is concerned: render, execute,
   reset, and a callback with a token. It also records how it was called so
   the test can check the widget is interaction-only rather than a checkbox
   bolted onto the onboarding screen. */
const FAKE_TURNSTILE = `
window.__TS__ = { renders: [], executes: 0, resets: 0 };
window.turnstile = {
  render: function (el, o) { window.__TS__.renders.push(o); window.__TS__.opts = o; return 'w1'; },
  reset: function () { window.__TS__.resets++; },
  execute: function (id, o) {
    window.__TS__.executes++;
    var cb = (o && o.callback) || (window.__TS__.opts && window.__TS__.opts.callback);
    setTimeout(function () { cb('tok-' + window.__TS__.executes); }, 10);
  }
};`;

function cfg(key) {
  return 'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",' +
         'TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",' +
         'SIGN_IN:{GOOGLE:true,EMAIL:true,ANON:true},TURNSTILE_SITE_KEY:' +
         JSON.stringify(key) + '};';
}

(async()=>{
 await new Promise(r=>srv.listen(4426,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function open(key, uid) {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   const asked=[];
   await pg.route('**/challenges.cloudflare.com/**', r=>{
     asked.push(r.request().url());
     r.fulfill({contentType:'text/javascript', body:FAKE_TURNSTILE});
   });
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:cfg(key)}));
   await pg.addInitScript(u=>{window.__UID__=u;window.__CAPTCHA_REQUIRED__=true;}, uid);
   return { ctx, pg, asked };
 }

 /* ======== 1. no key: the gate does not exist ========================== */
 /* __CAPTCHA_REQUIRED__ is deliberately still on here. Supabase refusing
    without a token while no key is configured is exactly the half-configured
    state the config comments warn about, and the app must say something
    true about it rather than hang. */
 {
   const { ctx, pg, asked } = await open('', 'unone');
   await pg.goto('http://localhost:4426/');
   await pg.waitForTimeout(1200);
   T('with no site key, Cloudflare is never contacted', asked.length===0,
     asked.length + ' requests');
   T('and no challenge box is put in the page',
     await pg.evaluate(()=>!document.querySelector('.ilcap')), 'no overlay');
   T('the half-configured state says something true rather than hanging',
     /robot check/i.test(await pg.textContent('body')),
     (await pg.textContent('#setupErr') || '').trim().slice(0,70) || 'shown');
   await ctx.close();
 }

 /* ======== 2. no key, nothing demanding one: the normal shipped state === */
 {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   const asked=[];
   await pg.route('**/challenges.cloudflare.com/**', r=>{asked.push(1);r.fulfill({contentType:'text/javascript',body:FAKE_TURNSTILE});});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:cfg('')}));
   await pg.addInitScript(()=>{window.__UID__='uplain';});
   await pg.goto('http://localhost:4426/');
   await pg.waitForSelector('#onboard:not([hidden])',{timeout:9000});
   T('off is the shipped state: the door opens as it always has',
     !(await pg.$eval('#onboard', e=>e.hidden)) && asked.length===0, 'straight in');
   await ctx.close();
 }

 /* ======== 3. a key: the token reaches the anonymous sign-in =========== */
 {
   const { ctx, pg, asked } = await open('1x00000000000000000000AA', 'ukey');
   await pg.goto('http://localhost:4426/#/join/AAA111');
   await pg.waitForSelector('#onboard:not([hidden])',{timeout:9000});
   await pg.waitForTimeout(300);
   T('the script is fetched once, and only once', asked.length===1, asked.length+' fetches');
   T('the anonymous sign-in carried a token',
     await pg.evaluate(()=>window.__CAP_SEEN__.length===1 &&
        /^tok-/.test(window.__CAP_SEEN__[0])),
     await pg.evaluate(()=>JSON.stringify(window.__CAP_SEEN__)));
   T('and it got in',
     !(await pg.$eval('#onboard', e=>e.hidden)), 'at the name box');

   /* The widget must be interaction-only and execute-driven. A visible
      checkbox on the first screen is a different product. */
   T('the widget is interaction-only, so most people never see it',
     await pg.evaluate(()=>window.__TS__.opts.appearance==='interaction-only' &&
        window.__TS__.opts.execution==='execute'),
     await pg.evaluate(()=>window.__TS__.opts.appearance+'/'+window.__TS__.opts.execution));
   T('the overlay is built but stays hidden while nothing is asked',
     await pg.evaluate(()=>{var b=document.querySelector('.ilcap');return !!b && b.hidden;}),
     'hidden');

   /* Now through the name box, so there is a profile, and on to the parts
      of the account screen that do and do not need a token. */
   await pg.fill('#nameInput','GATED');
   await pg.click('#enterBtn');
   await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
   await pg.waitForTimeout(500);
   const before = await pg.evaluate(()=>window.__CAP_SEEN__.length);

   /* Attaching an email to an account that already exists is updateUser,
      which Supabase does not check — so no token should be spent on it. */
   await pg.evaluate(async ()=>{
     await window.__sb__().auth.updateUser({ email: 'gated@example.test' });
   });
   T('attaching an email to an existing account spends no token',
     await pg.evaluate(()=>window.__CAP_SEEN__.length)===before,
     before + ' before, ' + (await pg.evaluate(()=>window.__CAP_SEEN__.length)) + ' after');

   /* A fresh signUp and a password sign-in both go through endpoints that
      ARE checked, and each needs its own token: they are single-use. */
   await pg.evaluate(async ()=>{
     window.__capProbe__ = [];
     var a = await window.__capOpts__();
     window.__capProbe__.push(a.captchaToken || null);
     var b = await window.__capOpts__();
     window.__capProbe__.push(b.captchaToken || null);
   });
   const two = await pg.evaluate(()=>window.__capProbe__);
   T('each call gets its own token, because a token is single-use',
     two.length===2 && two[0] && two[1] && two[0]!==two[1], two.join(' / '));
   T('and the widget was reset between them',
     await pg.evaluate(()=>window.__TS__.resets>=1),
     await pg.evaluate(()=>window.__TS__.resets+' resets'));
   await pg.screenshot({path:path.join(OUT,'96-captcha-on.png'),fullPage:false});
   await ctx.close();
 }

 /* ======== 4. the script never arrives ================================= */
 {
   const ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   await pg.route('**/challenges.cloudflare.com/**', r=>r.abort());
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:cfg('1x00000000000000000000AA')}));
   await pg.addInitScript(()=>{window.__UID__='ublocked';window.__CAPTCHA_REQUIRED__=true;});
   await pg.goto('http://localhost:4426/');
   await pg.waitForTimeout(1500);
   const txt = await pg.textContent('body');
   T('an ad blocker gets a sentence, not a spinner that never stops',
     /robot check could not load|ad blocker/i.test(txt),
     (txt.match(/[^.]*robot check[^.]*\./)||['nothing about it'])[0].trim().slice(0,80));
   await ctx.close();
 }

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
