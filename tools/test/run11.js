/* The three CHANGE buttons under "This league's identity" were placeholders
   that did nothing at all, and crest shape and colour had no picker anywhere.
   This covers both: the buttons now reach the shop, and every crest field
   actually saves. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* p1 owns the league, so every crest control should be live for them. */
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',max_members:30});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-01-01'});
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4411,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const errs=[],res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.route('**/sw.js', r => r.abort());
 await pg.addInitScript(()=>{window.__UID__='u1';});
 await pg.goto('http://localhost:4411/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:8000}); await pg.waitForTimeout(700);

 await pg.click('.tab[data-view="me"]'); await pg.waitForTimeout(400);
 await pg.evaluate(()=>document.querySelectorAll('details.sect').forEach(d=>{
   d.open=true; d.dispatchEvent(new Event('toggle'));}));
 await pg.waitForTimeout(300);

 /* the buttons exist and are no longer inert placeholders */
 const soon = await pg.$$eval('[data-soon]', e=>e.length);
 T('no dead placeholder buttons left', soon===0, soon+' remaining');
 const jumps = await pg.$$eval('[data-goshop]', e=>e.map(x=>x.getAttribute('data-goshop')));
 T('three CHANGE buttons wired', jumps.length===3, jumps.join(', '));
 T('each points at a real heading',
   await pg.evaluate(ts=>ts.every(t=>!!document.getElementById(t)), jumps), 'yes');

 /* clicking one opens the shop */
 await pg.evaluate(()=>{ document.querySelector('#sectShop').open=false; });
 await pg.click('[data-goshop="shopShapeHead"]');
 await pg.waitForTimeout(400);
 T('CHANGE opens the shop', await pg.evaluate(()=>document.querySelector('#sectShop').open), 'open');

 /* shape and colour are pickable, and drawn as the badge you would get */
 const shapes = await pg.$$eval('#shopShapes [data-cshape]', e=>e.length);
 const metals = await pg.$$eval('#shopMetals [data-cmetal]', e=>e.length);
 T('every shape offered', shapes===8, shapes+' shapes');
 T('every colour offered', metals===8, metals+' colours');
 T('shape buttons draw a real badge',
   await pg.$$eval('#shopShapes [data-cshape] svg path', e=>e.length>=8), 'yes');

 const before = await pg.evaluate(()=>window.__DB__.leagues[0].badge||null);
 await pg.click('#shopShapes [data-cshape="hex"]'); await pg.waitForTimeout(500);
 await pg.click('#shopMetals [data-cmetal="jade"]'); await pg.waitForTimeout(500);
 await pg.click('#shopCrests [data-crest="chess-rook"]'); await pg.waitForTimeout(500);
 const after = await pg.evaluate(()=>window.__DB__.leagues[0].badge||null);
 T('nothing was set before', before===null, JSON.stringify(before));
 T('shape saved', after && after.shape==='hex', JSON.stringify(after));
 T('colour saved', after && after.color==='jade', after&&after.color);
 T('emblem saved alongside', after && after.emblem==='chess-rook', after&&after.emblem);

 /* a later choice must not wipe an earlier one */
 await pg.click('#shopBanners [data-skin="aurora"]'); await pg.waitForTimeout(500);
 const withSkin = await pg.evaluate(()=>window.__DB__.leagues[0].badge);
 T('banner saved without dropping the crest',
   withSkin.skin==='aurora' && withSkin.shape==='hex' && withSkin.color==='jade'
   && withSkin.emblem==='chess-rook', JSON.stringify(withSkin));

 /* and the rows report what is actually set */
 await pg.waitForTimeout(300);
 const rowCrest = (await pg.textContent('#optCrest')).trim();
 const rowBanner = (await pg.textContent('#optBanner')).trim();
 const rowMetal = (await pg.textContent('#optMetal')).trim();
 T('crest row names the choice', /chess rook/i.test(rowCrest), rowCrest);
 T('banner row names the skin', /aurora/i.test(rowBanner), rowBanner);
 T('shape row names both', /hex/.test(rowMetal) && /jade/.test(rowMetal), rowMetal);
 T('rows no longer say "Nothing yet"',
   !/Nothing yet/.test(rowBanner) && !/nothing chosen/i.test(rowCrest), 'yes');

 await pg.evaluate(()=>document.querySelector('#shopShapes').scrollIntoView());
 await pg.waitForTimeout(250);
 await pg.screenshot({path:path.join(OUT,'60-crest-shop.png')});

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
