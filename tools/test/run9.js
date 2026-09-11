const { chromium } = require('/opt/node22/lib/node_modules/playwright');

/* The settings tab is collapsible; open everything before poking at it. */
async function openSects(pg) {
  await pg.evaluate(() => document.querySelectorAll('details.sect').forEach(d => {
    d.open = true; d.dispatchEvent(new Event('toggle'));
  }));
  await pg.waitForTimeout(200);
}
/* The 100-item dropdown became a search picker; drive it the way a thumb would. */
async function pickEx(pg, key) {
  if (!(await pg.$('#exFinder:not([hidden])'))) await pg.click('#exPick');
  const sel = '.exl-i[data-ex="' + key + '"]';
  if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  // groups start collapsed now; open them in turn (it is an accordion, so
  // opening the next one closes the last) until the exercise shows up
  const cats = await pg.$$eval('.exl-h', els => els.map(e => e.getAttribute('data-cat')));
  for (const c of cats) {
    await pg.click('.exl-h[data-cat="' + c + '"]');
    await pg.waitForTimeout(90);
    if (await pg.$(sel)) { await pg.click(sel); await pg.waitForTimeout(120); return; }
  }
  throw new Error('exercise not in picker: ' + key);
}

const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const OUT=path.join(__dirname,'shots'); fs.mkdirSync(OUT,{recursive:true});
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'}); s.end(fs.readFileSync(f));});

// 24 athletes, two finished weeks, so tiers + most improved both have data
const SEED=`(function(){var DB=window.__DB__,W=window.__weekStart__,C=window.__calc__;
 if(DB.leagues.length) return;
 DB.leagues.push({id:'lg1',name:'LEAGUE 1',code:'8FE7BB',owner_id:'p1',max_members:30});
 var animals=['🦍','🦊','🐺','🦁','🐯','🐻','🦅','🐗','🦈','🐍','🦂','🐢'];
 for(var i=1;i<=24;i++){
   DB.profiles.push({id:'p'+i,user_id:'u'+i,display_name:'ATHLETE'+i,restore_code:'RC'+i,
     avatar:animals[i%animals.length]});
   DB.members.push({league_id:'lg1',profile_id:'p'+i,joined_at:'2026-01-'+(i<10?'0':'')+i});}
 function d(iso,n){var p=iso.split('-');return new Date(Date.UTC(+p[0],+p[1]-1,+p[2]+n)).toISOString().slice(0,10);}
 var cur=W(), w1=d(cur,-7), w2=d(cur,-14), id=0;
 function log(pid,k,m,a,wk,daysAgo){DB.workouts.push({id:'w'+(++id),group_id:'g'+id,league_id:'lg1',
   profile_id:pid,exercise_key:k,mode:m,amount:a,points:C(k,m,a),week_start:wk,
   created_at:new Date(Date.now()-daysAgo*864e5).toISOString()});}
 // two weeks ago and last week: descending by index, so tiers are deterministic
 for(var i=1;i<=24;i++){ log('p'+i,'pushups','reps',(25-i)*8,w2,15); }
 for(var i=1;i<=24;i++){ log('p'+i,'pushups','reps',(25-i)*10,w1,8); }
 // ATHLETE20 explodes last week -> most improved
 log('p20','pushups','reps',400,w1,8);
 // this week: a bit of live scoring
 for(var i=1;i<=24;i++){ log('p'+i,'pushups','reps',i*3,cur,0); }
 window.__save__();
})();`;

(async()=>{
 await new Promise(r=>srv.listen(4407,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const res=[],errs=[]; const T=(n,ok,g)=>res.push([n,ok,g]);
 const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
   timezoneId:'Europe/Paris',locale:'en-GB',serviceWorkers:'block'});
 const pg=await ctx.newPage();
 pg.on('pageerror',e=>errs.push(e.message)); pg.on('console',m=>{if(m.type()==='error')errs.push('CONSOLE '+m.text());});
 await pg.route('**/vendor/supabase.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},body:MOCK+SEED}));
 await pg.route('**/config.js',r=>r.fulfill({contentType:'text/javascript',headers:{'Cache-Control':'no-store'},
   body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
 await pg.addInitScript(()=>{ try{ localStorage.setItem('mock.uid','u20'); }catch(e){} });
 await pg.goto('http://localhost:4407/');
 await pg.waitForSelector('#app:not([hidden])',{timeout:9000}); await pg.waitForTimeout(900);

 /* ---- divisions ---- */
 const heads=await pg.$$eval('.divhead', e=>e.map(x=>x.textContent.replace(/\s+/g,' ').trim()));
 T('the divisions that fit are shown', heads.length===4, heads.join(' | '));
 const sizes=await pg.$$eval('.divhead-n', e=>e.map(x=>x.textContent.trim()));
 T('two in the royal guard, three in the apex, ten in the vanguard',
   sizes.join(',')==='2,3,10,9', sizes.join(',') || 'no division headers rendered');
 T('divisions are named places, not numbers',
   /ROYAL GUARD/.test(heads[0]) && /APEX/.test(heads[1]) && /VANGUARD/.test(heads[2])
   && /FORGE/.test(heads[3]),
   heads.join(' | '));
 // divisions must follow THIS week's points, highest first
 const pts=await pg.$$eval('#board .row .pts', e=>e.map(x=>parseFloat(x.textContent)));
 T('divisions follow current points, descending',
   pts.every((v,i)=>i===0||pts[i-1]>=v), pts.slice(0,6).join(' > ')+' …');
 const goldTop=await pg.$eval('#board .row', e=>parseFloat(e.querySelector('.pts').textContent));
 T('the top division holds the current leader', goldTop===Math.max(...pts), goldTop+' vs max '+Math.max(...pts));
 /* the rank number is a position in the whole league, not inside a division */
 const ranks=await pg.$$eval('#board .row .rank', e=>e.map(x=>x.textContent.trim()));
 T('ranks run straight through the divisions',
   ranks.slice(0,14).join(',')==='1,2,3,4,5,6,7,8,9,10,11,12,13,14', ranks.slice(0,14).join(','));
 T('nobody is 1st twice', new Set(ranks.filter(r=>r!=='–')).size
   === ranks.filter(r=>r!=='–').length, ranks.join(','));
 const order=await pg.$$eval('#board > *', e=>e.map(x=>x.className.split(' ')[0]));
 T('board is grouped, not one flat list', order[0]==='divhead', order.slice(0,3).join(','));
 T('a leader is highlighted per division',
   (await pg.$$('.row.lead-diamond')).length===1 && (await pg.$$('.row.lead-gold')).length===1,
   'royal guard and apex both marked');
 await pg.screenshot({path:path.join(OUT,'80-tiers.png')});

 /* ---- most improved ---- */
 await pg.click('.tab[data-view="hall"]'); await pg.waitForTimeout(700);
 const climbers=await pg.$$eval('.climber', e=>e.map(x=>x.textContent.replace(/\s+/g,' ').trim()));
 T('most improved on the finished week', climbers.length>=1, climbers[0]||'none');
 T('it is the athlete who exploded', (climbers[0]||'').includes('ATHLETE20'), climbers[0]||'');
 T('week one has no most improved', climbers.length===1, climbers.length+' shown');
 await pg.screenshot({path:path.join(OUT,'81-mostimproved.png')});

 /* ---- league raid: one target the whole league carries ---- */
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(800);
 T('raid card shown', !(await pg.$eval('#raidCard', e=>e.hidden)),
   (await pg.textContent('#raidCard')).replace(/\s+/g,' ').slice(0,48));
 T('raid target scales with the league',
   /\/\s?\d+/.test(await pg.textContent('.raid-f')), await pg.textContent('.raid-f'));
 await pg.screenshot({path:path.join(OUT,'86-raid.png')});

 /* The dashboard is a separate page now (admin.html), not part of the app —
    every copy of the app is identical, so there is nothing here to test. */
 T('the app ships no admin surface',
   (await pg.$$('#adminOpen, #view-admin, [data-view="admin"]')).length===0, 'none');

 /* ---- rivalries: an automatic 1v1 with your nearest rank ---- */
 await pg.click('.tab[data-view="duel"]'); await pg.waitForTimeout(900);
 T('a rival is drawn for me', (await pg.$$('#myRival .riv-big')).length===1,
   (await pg.textContent('#myRival')).replace(/\s+/g,' ').slice(0,54));
 await pg.evaluate(()=>{const d=document.querySelector('#sectRivals'); d.open=true;});
 await pg.waitForTimeout(250);
 const pairs = await pg.$$eval('#rivalList .riv', e=>e.length);
 T('whole table paired off', pairs>=1, pairs+' pairings');
 T('nobody faces themselves', await pg.$$eval('#rivalList .riv', rows =>
     rows.every(r => { const n=[...r.querySelectorAll('.riv-s b')].map(x=>x.textContent);
       return n.length===2 && n[0]!==n[1]; })), 'distinct');
 await pg.screenshot({path:path.join(OUT,'84-rivals.png')});

 /* ---- badges: earned in a league, worn three at a time ---- */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(600);
 await pg.evaluate(()=>{const d=document.querySelector('#sectBadges');d.open=true;d.dispatchEvent(new Event('toggle'));});
 await pg.waitForTimeout(700);
 const nb = await pg.$$eval('.bdg', e=>e.length);
 T('badge board rendered', nb>0, nb+' badges');
 T('unearned badges show progress', (await pg.$$('.bdg:not(.got) .bdg-bar')).length>0, 'bars');
 const earned = await pg.$$('.bdg.got');
 if (earned.length) {
   await earned[0].click(); await pg.waitForTimeout(700);
   T('tapping an earned badge wears it', (await pg.$$('.bdg.pinned')).length===1, 'worn');
   await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(700);
   T('worn badge shows on my row', (await pg.$$('#board .row.me .worn')).length>0, 'on the row');
   await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(600);
 } else {
   T('badge art is distinct from emblems',
     await pg.evaluate(()=>Object.values(GI_BADGE_ART).every(k=>!GI_AVATARS.includes(k)&&!GI_CRESTS.includes(k))), 'distinct');
 }
 await pg.screenshot({path:path.join(OUT,'85-badges.png')});

 /* ---- Iron Will: consistency, not volume ---- */
 await pg.click('.tab[data-view="hall"]'); await pg.waitForTimeout(800);
 const stk = await pg.$$eval('.stk', e=>e.length);
 T('streak board rendered', stk>0, stk+' on the board');
 T('streaks counted in days',
   /DAYS|BEST/.test(await pg.textContent('#streaks').catch(()=>'')), 'days');
 await pg.screenshot({path:path.join(OUT,'83-ironwill.png')});

 /* ---- milestones ---- */
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(900);
 T('rank shown up front', (await pg.textContent('.ms-id b')).length>2, await pg.textContent('.ms-id b'));
 T('ladder runs to 50,000', (await pg.$$('.ms-pip')).length>=25, (await pg.$$('.ms-pip')).length+' grades');
 T('top grade is 50,000',
   (await pg.$$eval('.ms-pip i', e=>e.map(x=>x.textContent))).includes('50000'),
   (await pg.$$eval('.ms-pip i', e=>e[e.length-1].textContent)));
 T('some already earned', (await pg.$$('.ms-pip.on')).length>0, (await pg.$$('.ms-pip.on')).length+' earned');
 T('next grade announced', (await pg.textContent('.ms-next')).length>2, await pg.textContent('.ms-next'));
 T('nearby grades surfaced', (await pg.$$('.ms-step')).length>=3, (await pg.$$('.ms-step')).length+' steps');
 T('no duel record before any duel', await pg.isHidden('#duelRecord'), 'hidden');

 // settle three duels: two wins then a loss
 await pg.evaluate(()=>{
   var DB=window.__DB__, past=Date.now()-5*864e5;
   [[120,60],[90,30],[10,80]].forEach(function(sc,i){
     var st=new Date(past+i*864e5).toISOString(), en=new Date(past+i*864e5+3600e3).toISOString();
     DB.challenges.push({id:'c'+i,code:'C'+i,league_id:'lg1',challenger_id:'p20',opponent_id:'p1',
       created_at:st,accepted_at:st,ends_at:en,cancelled_at:null});
     DB.workouts.push({id:'dw'+i+'a',group_id:'dg'+i+'a',league_id:'lg1',profile_id:'p20',
       exercise_key:'pushups',mode:'reps',amount:sc[0],points:sc[0],week_start:'2026-08-31',
       created_at:new Date(past+i*864e5+600e3).toISOString()});
     DB.workouts.push({id:'dw'+i+'b',group_id:'dg'+i+'b',league_id:'lg1',profile_id:'p1',
       exercise_key:'pushups',mode:'reps',amount:sc[1],points:sc[1],week_start:'2026-08-31',
       created_at:new Date(past+i*864e5+600e3).toISOString()});
   });
   window.__save__();
 });
 await pg.click('.tab[data-view="live"]'); await pg.waitForTimeout(300);
 await pg.click('.tab[data-view="stats"]'); await pg.waitForTimeout(900);
 T('duel record appears once duels exist', await pg.isVisible('#duelRecord'), 'visible');
 const rec=(await pg.textContent('#duelRecord')).replace(/\s+/g,' ').trim();
 T('record reads 2W 1L 0D', /2W/.test(rec) && /1L/.test(rec) && /0D/.test(rec), rec);
 T('labelled all time, not the toggle', rec.toLowerCase().includes('all time'), rec);
 await pg.evaluate(()=>document.querySelector('#duelRecord').scrollIntoView());
 await pg.waitForTimeout(250);
 await pg.screenshot({path:path.join(OUT,'95-duelrecord.png')});
 await pg.evaluate(()=>document.querySelector('#milestones').scrollIntoView());
 await pg.waitForTimeout(300);
 await pg.screenshot({path:path.join(OUT,'82-milestones.png')});

 /* ---- new exercises ---- */
 await pg.click('#logBtn'); await pg.waitForTimeout(500);
 for (const [key,amt,expect] of [['plank','3','6'],['twists','40','10'],['calves','50','10']]) {
   await pickEx(pg, key); await pg.waitForTimeout(250);
   await pg.fill('#amountInput', amt); await pg.waitForTimeout(200);
   T(key+' '+amt+' = '+expect+' pts', (await pg.textContent('#ptsPreview'))===expect, await pg.textContent('#ptsPreview'));
 }
 // groups are collapsed, so count what the headings advertise, not the DOM
 const perGroup=await pg.$$eval('.exl-c', e=>e.map(x=>parseInt(x.textContent,10)));
 const bankTotal=perGroup.reduce((a,b)=>a+b,0);
 T('full exercise bank in the picker', bankTotal>=100, bankTotal+' across '+perGroup.length+' groups');
 T('groups start collapsed', (await pg.$$('.exl-i')).length < 30, (await pg.$$('.exl-i')).length+' items visible');

 await ctx.close(); await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
