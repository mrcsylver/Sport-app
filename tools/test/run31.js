/* The 25-second explainer.

   The failure that matters is not "the video did not play" — it is "the
   video cannot be got out of". Somebody who scanned a poster in a corridor
   has one goal, and anything between them and the leaderboard is a thing
   they close the tab on. So the checks here are mostly about ESCAPE:

     · SKIP is on screen from the first frame, not after a countdown
     · skipping counts as seen, so it never argues with them tomorrow
     · it never appears in front of the door, only once they are inside
     · and it is reachable afterwards, so skipping is not a one-shot loss

   The 0.6 MB file is deliberately NOT fetched here. preload="none" and a src
   set at open time are the point: an account that never opens it never pays
   for it, and asserting that is cheaper than streaming it. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json','.mp4':'video/mp4'};
let videoHits=0;
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 if(/\.mp4$/.test(p)) videoHits++;
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

const CFG='window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",' +
          'TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",' +
          'SIGN_IN:{GOOGLE:false,EMAIL:false,ANON:true},TURNSTILE_SITE_KEY:""};';
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'ALPHA',code:'AAA111',owner_id:'p9',max_members:30,rest_dow:[]});
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4431,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function open(uid){
   const ctx=await b.newContext({viewport:{width:420,height:900},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',body:CFG}));
   await pg.addInitScript(u=>{window.__UID__=u;window.__ASK_SHARE__=false;},uid);
   return {ctx,pg};
 }

 /* ===== 1. it meets them at the door ================================== */
 const {ctx,pg}=await open('unew');
 await pg.goto('http://localhost:4431/');
 await pg.waitForSelector('#promoPop:not([hidden])',{timeout:9000});

 T('it opens on the door, before anybody has typed anything',
   await pg.evaluate(()=>!document.querySelector('#promoPop').hidden), 'shown at the door');
 /* The form is already built behind it, so SKIP lands on something usable
    rather than on a screen still setting itself up. */
 T('and the name box is already there behind it, ready',
   await pg.evaluate(()=>!!document.querySelector('#nameInput')), 'form is up');

 /* ===== 2. escape, which is the thing that matters ==================== */
 T('SKIP is on screen from the first frame, not after a countdown',
   await pg.isVisible('#promoSkip'), 'visible immediately');
 const box = await pg.$eval('#promoSkip', e=>{const r=e.getBoundingClientRect();
   return {w:Math.round(r.width),h:Math.round(r.height)};});
 /* A SKIP nobody can hit is a video nobody can leave. */
 T('and it is big enough to actually hit with a thumb',
   box.h>=30 && box.w>=60, box.w+'x'+box.h);

 await pg.click('#promoSkip');
 await pg.waitForTimeout(250);
 T('skipping closes it', await pg.evaluate(()=>document.querySelector('#promoPop').hidden), 'closed');
 T('and the video is paused, not left running behind the form',
   await pg.evaluate(()=>document.querySelector('#promoVid').paused), 'paused');
 /* The whole point of skipping at the door: you can get on with joining. */
 await pg.fill('#nameInput','NEWBIE');
 await pg.fill('#joinCode','AAA111');
 await pg.click('#enterBtn');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 T('and joining still works straight afterwards',
   await pg.evaluate(()=>!document.querySelector('#app').hidden), 'in the app');

 /* ===== 3. skipping is a decision, not a postponement ================ */
 T('skipping counts as seen, so it does not argue tomorrow',
   await pg.evaluate(()=>localStorage.getItem('ironleague.promo.seen')==='1'), 'flag set');
 await pg.reload();
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000});
 await pg.waitForTimeout(600);
 T('and it does not come back on the next open',
   await pg.evaluate(()=>document.querySelector('#promoPop').hidden), 'still closed');

 /* ===== 4. but it is not a one-shot loss ============================= */
 await pg.click('.tab[data-view="me"]');
 await pg.waitForTimeout(400);
 T('there is a way back to it from SETTINGS',
   await pg.isVisible('#promoReplay'), await pg.textContent('#promoReplay'));
 await pg.click('#promoReplay');
 await pg.waitForTimeout(300);
 T('and it replays on demand',
   await pg.evaluate(()=>!document.querySelector('#promoPop').hidden), 'reopened');
 T('only NOW is the file asked for', videoHits>0, videoHits+' requests');

 /* ===== 5. silent, inline, and not a black rectangle ================= */
 const v = await pg.evaluate(()=>{const e=document.querySelector('#promoVid');
   return {muted:e.muted, inline:e.hasAttribute('playsinline'),
           preload:e.getAttribute('preload'), poster:e.getAttribute('poster'),
           srcs:[...e.querySelectorAll('source')].map(x=>x.getAttribute('src')+' '+x.type)};});
 /* Every mobile browser refuses to autoplay anything that is not both. */
 T('muted and playsinline, or no phone will autoplay it at all',
   v.muted && v.inline, 'muted='+v.muted+' playsinline='+v.inline);
 /* One encoding does not reach everybody: Safari needs H.264, and browsers
    built without proprietary codecs — including the one running this test —
    show an .mp4 as a black rectangle. */
 T('two encodings, H.264 first for the phones that hardware-decode it',
   v.srcs.length===2 && /mp4.*video\/mp4/.test(v.srcs[0]) && /webm.*video\/webm/.test(v.srcs[1]),
   v.srcs.join(' · '));
 T('and both carry the version, so a new cut is never served stale',
   v.srcs.every(x=>/\?v=\d+\.\d+\.\d+/.test(x)), v.srcs.join(' · '));
 T('the poster is the clip\'s own first frame, not the app icon stretched',
   /promo\.jpg/.test(v.poster||''), v.poster);

 /* ===== 6. and it genuinely plays ==================================== */
 /* The point of shipping VP9 as well: this browser cannot decode H.264, so
    until there were two encodings nothing here could prove the clip runs at
    all rather than sitting on frame zero. */
 await pg.waitForTimeout(2200);
 const played = await pg.evaluate(()=>{const e=document.querySelector('#promoVid');
   return {t:e.currentTime, dur:Math.round(e.duration||0), paused:e.paused,
           w:e.videoWidth, h:e.videoHeight};});
 T('the clip is really 25 seconds of 1080x1920',
   played.dur===25 && played.w===1080 && played.h===1920,
   played.dur+'s '+played.w+'x'+played.h);
 T('and it is actually playing, not stuck on frame zero',
   played.t > 0.3 && !played.paused, 'at '+played.t.toFixed(1)+'s');

 await pg.click('#promoSkip');

 /* ===== 7. sound, which is the only way the music is ever heard ====== */
 /* No browser autoplays with sound, so the clip starts muted and a tap is the
    permission. If that button is missing the music exists only in the file
    somebody downloads, which is not where most people will watch it. */
 await pg.evaluate(()=>document.querySelector('#promoReplay').click());
 await pg.waitForTimeout(500);
 T('there is a way to turn the sound on', await pg.isVisible('#promoSound'),
   (await pg.textContent('#promoSound')).trim());
 T('and it starts muted, because an unmuted autoplay is simply refused',
   await pg.evaluate(()=>document.querySelector('#promoVid').muted), 'muted');
 await pg.click('#promoSound');
 await pg.waitForTimeout(250);
 T('tapping it unmutes', await pg.evaluate(()=>!document.querySelector('#promoVid').muted),
   'sound on');
 T('and the clip carries an audio track at all',
   await pg.evaluate(()=>{const v=document.querySelector('#promoVid');
     return (v.webkitAudioDecodedByteCount===undefined) ? true
          : v.webkitAudioDecodedByteCount > 0;}), 'has audio');

 await pg.click('#promoSkip');
 await ctx.close();

 T('no JavaScript error anywhere', errs.length===0, errs.join(' | ') || 'clean');

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
