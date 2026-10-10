/* The armoury, and the lock that was not on it.

   Before this the setters took any string that fit the column, so the first
   item anybody charged for would have been free to anybody willing to call
   the function by hand. Every check below is a version of "the catalogue is
   the authority, not the client" — plus the ring, which is the one cosmetic
   that shows on somebody else's screen. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

/* A one-pixel transparent PNG, so a ring has artwork without a network hop. */
const PIX='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAABfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const SEED = (opts) => `(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'SHOP11',owner_id:'p1',max_members:30,rest_dow:[]});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'MARCO111',is_admin:true});
 DB.profiles.push({id:'p2',user_id:'u2',display_name:'RIVAL',restore_code:'RIVAL222'
   ${opts.rivalRing ? ", frame:'gold-pulse'" : ''}});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
 DB.members.push({league_id:'lg1',profile_id:'p2',joined_at:'2026-01-02'});
 DB.workouts.push({id:'w1',league_id:'lg1',profile_id:'p1',group_id:'g1',
   exercise_key:'pushups',mode:'reps',amount:50,points:50,
   created_at:new Date().toISOString()});
 DB.workouts.push({id:'w2',league_id:'lg1',profile_id:'p2',group_id:'g2',
   exercise_key:'pushups',mode:'reps',amount:40,points:40,
   created_at:new Date().toISOString()});
 ${opts.paid ? `
 /* A banner somebody has to be given, and a ring that is free to all. */
 DB.shop.push({key:'player_banner:warlord',kind:'player_banner',item:'warlord',
   name:'WARLORD',price_cents:499,asset_path:'designs/warlord.webp',
   asset_kind:'webp',thumb_path:'designs/warlord.webp',animated:true,sort:99});
 DB.shop.push({key:'frame:gold-pulse',kind:'frame',item:'gold-pulse',
   name:'GOLD PULSE',price_cents:null,asset_path:'designs/gold-pulse.webp',
   asset_kind:'webp',thumb_path:'designs/gold-pulse.webp',animated:true,sort:0});` : ''}
 ${opts.granted ? `DB.entitlements.push({profile_id:'p1',
   item_key:'player_banner:warlord',source:'gift'});` : ''}
 window.__save__();})();`;

(async()=>{
 await new Promise(r=>srv.listen(4422,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 async function boot(seed, uid, page) {
   const ctx=await b.newContext({viewport:{width:420,height:1100},timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
   const pg=await ctx.newPage();
   pg.on('pageerror',e=>errs.push(e.message));
   pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
   await pg.route('**/vendor/supabase.js*',r=>r.fulfill({contentType:'text/javascript',body:MOCK+seed}));
   await pg.route('**/config.js*',r=>r.fulfill({contentType:'text/javascript',
     body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE",CURRENCY:"\\u20ac",CONTACT_URL:""};'}));
   /* Artwork never leaves the machine: every design URL answers with a pixel. */
   await pg.route('**/storage/v1/object/public/**',r=>r.fulfill({status:200,
     contentType:'image/png',body:Buffer.from(PIX.split(',')[1],'base64')}));
   await pg.addInitScript(u=>{window.__UID__=u;}, uid);
   await pg.goto('http://localhost:4422/'+(page||''));
   await pg.waitForTimeout(1500);
   return {ctx,pg};
 }
 async function openShop(pg) {
   await pg.click('[data-view="me"]');
   await pg.waitForTimeout(300);
   await pg.evaluate(()=>{document.querySelector('#sectShop').open=true;});
   await pg.waitForTimeout(400);
 }

 /* ===== 1. everything free: the shelf says so and nothing is dimmed ===== */
 let {ctx,pg}=await boot(SEED({}),'u1');
 await openShop(pg);
 T('with nothing priced the shelf still says ALL FREE',
   (await pg.textContent('#shopTag')).trim()==='ALL FREE',
   await pg.textContent('#shopTag'));
 T('and every shipped cosmetic is on it',
   (await pg.$$('#shopPlayer button')).length===16 &&
   (await pg.$$('#shopCrests button')).length===56,
   (await pg.$$('#shopPlayer button')).length+' banners, '+
   (await pg.$$('#shopCrests button')).length+' crests');
 T('none of it locked',
   (await pg.$$('#shopPlayer button.locked')).length===0, 'nothing dimmed');
 T('and there is no ring shelf until somebody uploads one',
   await pg.$eval('#shopRingsWrap', e=>e.hidden), 'hidden');
 /* a free banner goes on from the shelf, which is the ordinary case */
 await pg.click('#shopPlayer button[data-skin="ember"]');
 await pg.waitForTimeout(700);
 T('a free banner goes on by tapping it',
   await pg.evaluate(()=>window.__DB__.profiles.find(x=>x.id==='p1').banner==='ember'),
   'INFERNO on');
 await ctx.close();

 /* ===== 2. a priced banner: visible, dimmed, and refused ===== */
 ({ctx,pg}=await boot(SEED({paid:true}),'u1'));
 await openShop(pg);
 T('a priced item is shown rather than hidden — a shop you cannot see into sells nothing',
   (await pg.$$('#shopPlayer button[data-skin="warlord"]')).length===1, 'on the shelf');
 T('but dimmed, with the price on it',
   await pg.$eval('#shopPlayer button[data-skin="warlord"]',
     e=>e.classList.contains('locked') && /4\.99/.test(e.textContent)),
   (await pg.textContent('#shopPlayer button[data-skin="warlord"] small')).trim());
 T('and the header stops claiming everything is free',
   (await pg.textContent('#shopTag')).trim()==='ARMOURY',
   await pg.textContent('#shopTag'));
 await pg.click('#shopPlayer button[data-skin="warlord"]');
 await pg.waitForTimeout(700);
 T('tapping it explains itself instead of a silent nothing',
   /not yours yet/i.test(await pg.textContent('#toast')),
   (await pg.textContent('#toast')).trim().slice(0,44));
 T('and nothing was stored',
   await pg.evaluate(()=>!window.__DB__.profiles.find(x=>x.id==='p1').banner),
   'still bare');
 /* the real test of a paywall: go round the shelf and call the server direct */
 const forced = await pg.evaluate(async()=>{
   const sb = window.supabase.createClient('https://d.supabase.co','k');
   const r = await sb.rpc('set_banner',{p_banner:'warlord'});
   return r.error ? r.error.message : 'ACCEPTED';
 });
 T('and calling the server directly is refused too, which is the whole point',
   /LOCKED_ITEM/.test(forced), forced);
 await pg.screenshot({path:path.join(OUT,'98-shop-locked.png'),fullPage:true});
 await ctx.close();

 /* ===== 3. once it is granted, it is theirs ===== */
 ({ctx,pg}=await boot(SEED({paid:true,granted:true}),'u1'));
 await openShop(pg);
 T('a granted item reads as YOURS, not as a price',
   /YOURS/.test(await pg.textContent('#shopPlayer button[data-skin="warlord"]')),
   (await pg.textContent('#shopPlayer button[data-skin="warlord"] small')).trim());
 await pg.click('#shopPlayer button[data-skin="warlord"]');
 await pg.waitForTimeout(700);
 T('and goes on like any other',
   await pg.evaluate(()=>window.__DB__.profiles.find(x=>x.id==='p1').banner==='warlord'),
   'WARLORD on');
 await ctx.close();

 /* ===== 4. the ring: the one cosmetic other people see ===== */
 ({ctx,pg}=await boot(SEED({paid:true}),'u1'));
 await openShop(pg);
 T('the ring shelf appears once a ring exists',
   !(await pg.$eval('#shopRingsWrap', e=>e.hidden)) &&
   (await pg.$$('#shopRings button')).length===1, 'one ring');
 T('and the tile draws your own emblem inside the ring it is selling',
   (await pg.$$('#shopRings button .av .av-rimg')).length===1, 'ring over face');
 await pg.click('#shopRings button[data-ring="gold-pulse"]');
 await pg.waitForTimeout(900);
 T('putting one on sticks',
   await pg.evaluate(()=>window.__DB__.profiles.find(x=>x.id==='p1').frame==='gold-pulse'),
   'ring on');
 T('and it is drawn on your row of the board, not just in settings',
   await pg.evaluate(()=>!!document.querySelector('#board .row.me .av-ring .av-rimg')),
   'on the board');
 T('with a way to take it off again',
   !(await pg.$eval('#shopRingOff', e=>e.hidden)), 'off button');
 await pg.click('#shopRingOff');
 await pg.waitForTimeout(900);
 T('which works',
   await pg.evaluate(()=>!window.__DB__.profiles.find(x=>x.id==='p1').frame),
   'ring off');
 await ctx.close();

 /* ===== 5. somebody ELSE's ring shows on their row ===== */
 ({ctx,pg}=await boot(SEED({paid:true,rivalRing:true}),'u1'));
 await pg.waitForTimeout(400);
 T("a rival's ring is drawn on their row, which is what makes one worth having",
   await pg.evaluate(()=>!!document.querySelector('#board .row[data-id="p2"] .av-ring .av-rimg')),
   'rival ringed');
 T('and nobody without one grows a ring',
   await pg.evaluate(()=>!document.querySelector('#board .row[data-id="p1"] .av-ring')),
   'plain row stays plain');
 await pg.screenshot({path:path.join(OUT,'99-ring-board.png'),fullPage:true});
 await ctx.close();

 /* ===== 6. the control room: constraints stated, and a bad file caught ===== */
 ({ctx,pg}=await boot(SEED({paid:true}),'u1','admin.html'));
 await pg.fill('#code','MARCO111');
 await pg.click('#go');
 await pg.waitForTimeout(1400);
 const designs = await pg.textContent('#designs');
 T('the control room lists what was uploaded, and only that',
   /GOLD PULSE/.test(designs) && /WARLORD/.test(designs) && !/CARBON/.test(designs),
   'two uploads, no CSS rows');
 T('and says what the bucket accepts, in bytes somebody can act on',
   /PNG, WebP, or Lottie JSON/.test(await pg.textContent('#panel')) &&
   /No SVG/.test(await pg.textContent('#panel')),
   'formats stated');
 T('a label fills the short name in, because typing it twice is a chore',
   await (async()=>{ await pg.fill('#dName','Gold Pulse II');
     await pg.waitForTimeout(200);
     return (await pg.inputValue('#dSlug'))==='gold-pulse-ii'; })(),
   await pg.inputValue('#dSlug'));
 /* an SVG is the one that matters: it can carry script, and the app inlines
    emblem artwork, so the answer has to come before the upload */
 const svgSays = await pg.evaluate(()=>{
   const f = new File(['<svg/>'],'x.svg',{type:'image/svg+xml'});
   return window.__fileProblem__(f,'frame',false);
 });
 T('an SVG is refused by name, with the reason, before anything is uploaded',
   /SVG is not accepted/.test(svgSays||''), (svgSays||'').slice(0,40));
 const gifSays = await pg.evaluate(()=>{
   const f = new File(['x'],'x.gif',{type:'image/gif'});
   return window.__fileProblem__(f,'frame',false);
 });
 T('and so is a GIF',
   /not accepted/.test(gifSays||''), (gifSays||'').slice(0,40));
 const fatSays = await pg.evaluate(()=>{
   const f = new File([new Uint8Array(400*1024)],'x.png',{type:'image/png'});
   return window.__fileProblem__(f,'frame',false);
 });
 T('a ring well over its weight is called out, with the number',
   /under 250 KB/.test(fatSays||'') && /400 KB/.test(fatSays||''),
   (fatSays||'').slice(0,52));
 const okSays = await pg.evaluate(()=>{
   const f = new File([new Uint8Array(30*1024)],'x.webp',{type:'image/webp'});
   return window.__fileProblem__(f,'frame',false);
 });
 T('and a sensible one passes without a word',
   okSays===null, String(okSays));
 await pg.screenshot({path:path.join(OUT,'99-admin-designs.png'),fullPage:true});
 await ctx.close();

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
