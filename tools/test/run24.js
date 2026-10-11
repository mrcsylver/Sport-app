/* Attaching a real sign-in to an account that already exists.

   The property the whole thing rests on: linking keeps the SAME auth user
   id, so profiles.user_id still points where it pointed and nothing in the
   database moves. If that is ever not true, somebody upgrading their account
   loses every workout they ever logged — so that is what most of these
   checks are about. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'AUTH11',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.workouts.push({id:'w1',league_id:'lg1',profile_id:'p1',group_id:'g1',
   exercise_key:'pushups',mode:'reps',amount:50,points:50,
   created_at:new Date().toISOString()});
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4424,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 let ctx,pg;

 async function boot(uid, cfg) {
   ctx=await b.newContext({viewport:{width:420,height:1000},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",'
        +'TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",CONTACT_URL:"",'
        +'SIGN_IN:'+JSON.stringify(cfg)+'};'}));
   await pg.addInitScript(u=>{window.__UID__=u;}, uid);
   await pg.goto('http://localhost:4424/');
   await pg.waitForTimeout(1500);
 }
 async function openAccount() {
   await pg.click('[data-view="me"]'); await pg.waitForTimeout(250);
   await pg.evaluate(()=>{document.querySelector('#sectAccount').open=true;});
   await pg.waitForTimeout(250);
 }

 /* ===== 1. an anonymous account says so, loudly ===== */
 await boot('u1',{GOOGLE:true,EMAIL:true,ANON:true});
 await openAccount();
 T('an account with no sign-in is flagged AT RISK, not left quiet',
   (await pg.textContent('#acctTag')).trim()==='AT RISK',
   await pg.textContent('#acctTag'));
 T('and it says plainly that the account lives in this browser only',
   /this browser only/i.test(await pg.textContent('#acctState')),
   (await pg.textContent('#acctState')).slice(0,46));
 T('the restore code is called the ONLY way back in while that is true',
   /ONLY way back/i.test(await pg.textContent('#restoreWhy')),
   (await pg.textContent('#restoreWhy')).slice(0,42));
 /* the one that would lose somebody their account */
 T('and there is no sign-out button to lose it with',
   await pg.$eval('#signOutBtn', e=>e.hidden), 'hidden while anonymous');
 await pg.screenshot({path:path.join(OUT,'a1-at-risk.png'),fullPage:true});

 /* ===== 2. attaching an email keeps EVERYTHING ===== */
 const before = await pg.evaluate(()=>({
   uid: window.__DB__.profiles.find(p=>p.id==='p1').user_id,
   workouts: window.__DB__.workouts.length,
 }));
 await pg.fill('#acctEmail','marco@example.com');
 await pg.fill('#acctPass','longenough1');
 await pg.click('#emailBtn');
 await pg.waitForTimeout(800);
 const after = await pg.evaluate(()=>({
   uid: window.__DB__.profiles.find(p=>p.id==='p1').user_id,
   workouts: window.__DB__.workouts.length,
   email: window.__DB__.authEmails['u1'],
 }));
 T('the auth id does not change, which is why nothing has to be migrated',
   before.uid===after.uid && after.uid==='u1', after.uid);
 T('the profile still has its workouts',
   after.workouts===before.workouts && after.workouts===1, after.workouts+' kept');
 T('and the email is on the account',
   after.email==='marco@example.com', after.email);
 T('the section now reads SAVED rather than AT RISK',
   (await pg.textContent('#acctTag')).trim()==='SAVED',
   await pg.textContent('#acctTag'));
 T('and the restore code is re-described as the password reset there is not',
   /no password reset/i.test(await pg.textContent('#restoreWhy')),
   (await pg.textContent('#restoreWhy')).slice(0,40));
 T('sign out appears only now that there is a way back',
   !(await pg.$eval('#signOutBtn', e=>e.hidden)), 'offered');
 await ctx.close();

 /* ===== 3. a typo is refused before it becomes permanent ===== */
 await boot('u2',{GOOGLE:false,EMAIL:true,ANON:true});
 await pg.evaluate(()=>{window.__DB__.profiles.push({id:'p2',user_id:'u2',
   display_name:'RIVAL',restore_code:'RIVAL222'}); window.__save__();});
 await pg.reload(); await pg.waitForTimeout(1400);
 await openAccount();
 T('google is hidden when it is not configured, rather than failing on tap',
   await pg.$eval('#googleBtn', e=>e.hidden), 'hidden');
 await pg.fill('#acctEmail','not-an-email');
 await pg.fill('#acctPass','longenough1');
 await pg.click('#emailBtn'); await pg.waitForTimeout(400);
 T('a malformed address is caught before it is saved',
   /does not look like/i.test(await pg.textContent('#acctErr')),
   (await pg.textContent('#acctErr')).slice(0,38));
 await pg.fill('#acctEmail','rival@example.com');
 await pg.fill('#acctPass','short');
 await pg.click('#emailBtn'); await pg.waitForTimeout(400);
 T('and so is a password nobody could call one',
   /at least 8/i.test(await pg.textContent('#acctErr')),
   (await pg.textContent('#acctErr')).slice(0,30));
 T('the caveat about typos being permanent is actually on screen',
   /typo here is permanent/i.test(await pg.textContent('#emailCaveat')),
   'stated');

 /* ===== 4. somebody else's email is refused, not silently merged =====
    Each context starts with its own storage, so the clash has to be put
    there on purpose rather than carried over from check 2. */
 await pg.evaluate(()=>{window.__DB__.authEmails['u1']='marco@example.com';
   window.__save__();});
 await pg.fill('#acctEmail','marco@example.com');
 await pg.fill('#acctPass','longenough1');
 await pg.click('#emailBtn'); await pg.waitForTimeout(600);
 T("taking an email that is already on another account is refused",
   /already on another account/i.test(await pg.textContent('#acctErr')),
   (await pg.textContent('#acctErr')).slice(0,44));
 T('and nothing was attached to this one',
   await pg.evaluate(()=>!window.__DB__.authEmails['u2']), 'still bare');
 await ctx.close();

 /* ===== 5. Google, when it is switched on ===== */
 await boot('u3',{GOOGLE:true,EMAIL:true,ANON:true});
 await pg.evaluate(()=>{window.__DB__.profiles.push({id:'p3',user_id:'u3',
   display_name:'THIRD',restore_code:'THIRD333'}); window.__save__();});
 await pg.reload(); await pg.waitForTimeout(1400);
 await openAccount();
 T('the google button is offered once configured',
   !(await pg.$eval('#googleBtn', e=>e.hidden)), 'shown');
 await pg.click('#googleBtn'); await pg.waitForTimeout(600);
 await pg.evaluate(()=>window.__renderAccount__ && window.__renderAccount__());
 const g = await pg.evaluate(()=>({
   uid: window.__DB__.profiles.find(p=>p.id==='p3').user_id,
   ids: (window.__DB__.authIdentities['u3']||[]).map(i=>i.provider),
 }));
 T('linking Google also keeps the same auth id',
   g.uid==='u3' && g.ids.indexOf('google')>=0, g.uid+' · '+g.ids.join(','));
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
