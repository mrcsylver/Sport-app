/* The clock belongs to the league, not to the phone.

   Somebody in Chicago and somebody in Paris are in the same league, and the
   week has to end at the same instant for both of them. This runs the whole
   app twice at one frozen moment — Monday 01:30 in Paris, which is Sunday
   18:30 in Chicago, so the two devices disagree about the day AND the date —
   and asserts that everything the app decides comes out identical. */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http=require('http'), fs=require('fs'), path=require('path');
const ROOT='/home/user/Sport-app';
const MOCK=fs.readFileSync(path.join(__dirname,'mock-supabase.js'),'utf8');
const MIME={'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json'};
const srv=http.createServer((q,s)=>{let p=decodeURIComponent(q.url.split('?')[0]); if(p==='/')p='/index.html';
 const f=path.join(ROOT,p); if(!fs.existsSync(f)||fs.statSync(f).isDirectory()){s.writeHead(404);return s.end();}
 s.writeHead(200,{'Content-Type':MIME[path.extname(f)]||'application/octet-stream'}); s.end(fs.readFileSync(f));});

/* 2026-09-13T23:30:00Z — Monday 01:30 in Paris, Sunday 18:30 in Chicago. */
const FROZEN = Date.UTC(2026, 8, 13, 23, 30, 0);

/* A league that rests on Monday, which is the case that broke: the rest day
   is the first day of the week, so the week rolls over into a closed day. */
const SEED=`(function(){var DB=window.__DB__;
 DB.leagues.push({id:'lg1',name:'IRON CIRCLE',code:'8FE7BB',owner_id:'p1',
                  max_members:36,rest_dow:[1],catchup_dow:7});
 DB.profiles.push({id:'p1',user_id:'u1',display_name:'MARCO',restore_code:'RC1'});
 DB.members.push({league_id:'lg1',profile_id:'p1',joined_at:'2026-09-01'});
 window.__save__();
})();`;

async function look(browser, tz) {
  const ctx = await browser.newContext({ viewport:{width:420,height:900},
    timezoneId: tz, locale:'en-GB', serviceWorkers:'block' });
  const pg = await ctx.newPage();
  const errs = [];
  pg.on('pageerror', e => errs.push(e.message));
  await pg.addInitScript(t => {
    /* freeze the device clock so both runs describe the same instant */
    const Real = Date;
    function Fake(...a){ return a.length ? new Real(...a) : new Real(t); }
    Fake.prototype = Real.prototype;
    Fake.now = () => t;
    Fake.UTC = Real.UTC; Fake.parse = Real.parse;
    window.Date = Fake;
    window.__UID__ = 'u1';
  }, FROZEN);
  await pg.route('**/vendor/supabase.js*', r=>r.fulfill({contentType:'text/javascript',body:MOCK+SEED}));
  await pg.route('**/config.js*', r=>r.fulfill({contentType:'text/javascript',
    body:'window.APP_CONFIG={SUPABASE_URL:"https://d.supabase.co",SUPABASE_ANON_KEY:"k",TIMEZONE:"Europe/Paris",DEFAULT_LEAGUE_CODE:"",APP_NAME:"IRON LEAGUE"};'}));
  await pg.goto('http://localhost:4416/');
  await pg.waitForSelector('#view-live:not([hidden])',{timeout:9000});
  await pg.waitForTimeout(700);
  const seen = await pg.evaluate(() => {
    const c = window.__clock__;
    const w = c.wallNow();
    return {
      tz: c.tz,
      deviceDay: new Date().getDay(),          // what the phone thinks
      wall: w.toISOString().slice(0, 16),      // what the app thinks, in Paris
      weekStart: c.weekStart(),
      rest: c.isRestDay(),
      dows: c.restDows().join(','),
      close: c.close(c.weekStart()),
      restEnd: c.restEnd(),
      label: document.querySelector('.cd-label').textContent,
      timer: document.querySelector('#countdown .cd-t')
             ? document.querySelector('#countdown .cd-t').textContent : ''
    };
  });
  await ctx.close();
  return { seen, errs };
}

(async()=>{
 await new Promise(r=>srv.listen(4416,r));
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
 const res=[]; const T=(n,ok,g)=>res.push([n,ok,g]);

 const paris = await look(b, 'Europe/Paris');
 const chi   = await look(b, 'America/Chicago');
 const errs  = paris.errs.concat(chi.errs);

 T('the two devices really do disagree about the day',
   paris.seen.deviceDay !== chi.seen.deviceDay,
   'phone says ' + paris.seen.deviceDay + ' in Paris, ' + chi.seen.deviceDay + ' in Chicago');

 T('both read the league timezone, not their own',
   paris.seen.tz === 'Europe/Paris' && chi.seen.tz === 'Europe/Paris', chi.seen.tz);
 T('both put the wall clock at the same Paris minute',
   paris.seen.wall === chi.seen.wall && paris.seen.wall === '2026-09-14T01:30',
   chi.seen.wall);
 T('both start the week on the same Monday',
   paris.seen.weekStart === chi.seen.weekStart && paris.seen.weekStart === '2026-09-14',
   chi.seen.weekStart);
 T('both agree it is the rest day',
   paris.seen.rest === true && chi.seen.rest === true,
   'paris ' + paris.seen.rest + ', chicago ' + chi.seen.rest);
 T('and on which days rest', paris.seen.dows === '1' && chi.seen.dows === '1',
   chi.seen.dows);
 T('both close the league at the same instant',
   paris.seen.close === chi.seen.close, new Date(chi.seen.close).toISOString());
 T('both end the rest day at the same instant',
   paris.seen.restEnd === chi.seen.restEnd, new Date(chi.seen.restEnd).toISOString());

 /* the close instant itself: a league resting on Monday scores until the end
    of Sunday, which is 21:59:59.999Z in September */
 T('a Monday-resting league scores until Sunday night, Paris',
   new Date(paris.seen.close).toISOString() === '2026-09-20T21:59:59.999Z',
   new Date(paris.seen.close).toISOString());
 T('and the rest day ends at Monday midnight, Paris',
   new Date(paris.seen.restEnd).toISOString() === '2026-09-14T21:59:59.999Z',
   new Date(paris.seen.restEnd).toISOString());

 T('the countdown says it is the rest day, on both',
   /REST DAY/.test(paris.seen.label) && /REST DAY/.test(chi.seen.label),
   chi.seen.label);

 await b.close(); srv.close();
 let bad=0; res.forEach(([n,ok,g])=>{if(!ok)bad++;console.log((ok?'  PASS  ':'> FAIL <')+' '+n+'   ['+g+']');});
 console.log('\nJS errors: '+(errs.length?'\n  '+errs.join('\n  '):'none'));
 console.log(bad?bad+' FAILURES':'all '+res.length+' checks passed');
 process.exit(bad?1:0);
})().catch(e=>{console.error('CRASH',e);process.exit(1);});
