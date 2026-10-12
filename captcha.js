/* =====================================================================
   IRON LEAGUE — the gate on the door  (Cloudflare Turnstile)
   ---------------------------------------------------------------------
   The front door of this app is Supabase's anonymous sign-in, and that
   writes a row in auth.users. The key that calls it is public by design, so
   without a gate a script can mint accounts until a free database is full --
   and every fresh identity also comes with its own ten guesses at somebody
   else's restore code, which is what makes the throttle inside
   restore_profile() a fence rather than a gate.

   Turnstile is free and, with an interaction-only widget, invisible to
   almost everybody: Cloudflare only draws something when it is unsure.

   OFF BY DEFAULT, and the off switch is the absence of a site key. No key
   means no script is fetched and no challenge is ever asked for, so this
   whole file is inert until config.js carries one. It has to be turned on in
   two places at once -- here and in Supabase's own Attack Protection -- and
   either alone is a broken door: a key here with nothing checking it is
   theatre, and Supabase checking with no key here means nobody can sign in.

   Its own file, and its own markup and styles, because the control room
   signs in through the same endpoint and has neither this app's HTML nor
   its stylesheet. One copy, two pages.
   ===================================================================== */
(function () {
  var URL_ = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
  var load = null, id = null, box = null;

  function key() {
    return (window.APP_CONFIG && window.APP_CONFIG.TURNSTILE_SITE_KEY) || '';
  }
  function on() { return !!key(); }

  /* One <script> tag, once, and only if there is a key. */
  function script() {
    if (load) return load;
    load = new Promise(function (resolve, reject) {
      var t = document.createElement('script');
      t.src = URL_; t.async = true; t.defer = true;
      t.onload = function () { resolve(true); };
      /* Blocked by an extension, or no network. The caller goes on without a
         token and gets Supabase's refusal, which says something true rather
         than hanging on a widget that is never going to arrive. */
      t.onerror = function () { reject(new Error('CAPTCHA_UNREACHABLE')); };
      document.head.appendChild(t);
    });
    return load;
  }

  /* The challenge cannot live inside display:none -- it would have nowhere
     to draw itself -- so it gets an overlay that is only ever on screen
     while Cloudflare is actually asking for something. */
  function mount() {
    if (box) return box;
    var css = document.createElement('style');
    css.textContent =
      '.ilcap{position:fixed;inset:0;z-index:95;display:grid;place-items:center;' +
      'background:#000000cc;padding:20px;font-family:inherit}' +
      '.ilcap[hidden]{display:none}' +
      '.ilcap-card{background:#14161a;border:1px solid #2a2f37;border-radius:6px;' +
      'padding:18px;text-align:center;max-width:min(360px,90vw);color:#e7e9ee}' +
      '.ilcap-ttl{font-weight:700;letter-spacing:.08em;font-size:12px;' +
      'color:#8b929e;margin:0 0 12px}' +
      '.ilcap-sub{font-size:12px;color:#8b929e;margin:12px 0 0}';
    document.head.appendChild(css);
    box = document.createElement('div');
    box.className = 'ilcap';
    box.hidden = true;
    box.innerHTML =
      '<div class="ilcap-card"><p class="ilcap-ttl">ONE QUICK CHECK</p>' +
      '<div id="ilcap-widget"></div>' +
      '<p class="ilcap-sub">Proving you are not a script. Most people never see this.</p></div>';
    document.body.appendChild(box);
    return box;
  }
  function show(yes) { mount().hidden = !yes; }

  /* A token, or null when this is switched off. Single-use, so the widget is
     reset before every execute -- reusing one is an error from Supabase that
     looks exactly like a wrong key. */
  function token(how) {
    if (!on()) return Promise.resolve(null);
    var seen = !!(how && how.visible);
    return script().then(function () {
      mount();
      return new Promise(function (resolve, reject) {
        var done = false, timer;
        function finish(tok, err) {
          if (done) return;
          done = true;
          clearTimeout(timer);
          show(false);
          if (err) reject(err); else resolve(tok);
        }
        var opts = {
          sitekey: key(),
          /* `visible` asks for the plain Managed widget, drawn straight away
             and waited on. It is slower and it is seen, and it is what the
             CONTROL ROOM uses: that page is one person, rarely, and if its
             door ever sticks there is nothing left to fix anything with. No
             invisible path means no invisible failure. */
          execution: seen ? 'render' : 'execute',
          appearance: seen ? 'always' : 'interaction-only',
          callback: function (tok) { finish(tok, null); },
          'error-callback': function () {
            finish(null, new Error('CAPTCHA_FAILED'));
            return true;                       /* we reported it ourselves */
          },
          'timeout-callback': function () { finish(null, new Error('CAPTCHA_FAILED')); },
          'before-interactive-callback': function () { show(true); },
          'after-interactive-callback': function () { show(false); }
        };
        try {
          if (seen) show(true);
          if (id === null) {
            id = window.turnstile.render('#ilcap-widget', opts);
          } else {
            window.turnstile.reset(id);
          }
          if (!seen) window.turnstile.execute(id, opts);
        } catch (e) { finish(null, new Error('CAPTCHA_FAILED')); return; }
        /* A challenge somebody walks away from must not wedge a sign-in. */
        timer = setTimeout(function () {
          finish(null, new Error('CAPTCHA_FAILED'));
        }, 90000);
      });
    });
  }

  /* The options bag for the three calls Supabase checks a CAPTCHA on:
     signing up, signing in with a password, and signing in anonymously
     (which is a signup). An OAuth redirect is not one of them, and neither
     is updateUser -- so linking Google, or attaching an email to an account
     that already exists, needs no token. */
  /* A challenge that could not be completed does NOT fail the call here. It
     goes out without a token and lets SUPABASE decide, which is the only
     side that knows whether a token was required:

       protection off -> the sign-in works, and a blocked widget has cost
                         nobody anything
       protection on  -> Supabase refuses, and the app says why, using the
                         reason kept below rather than Supabase's wording

     Written the other way round, this file could lock everybody out of an
     app whose database was not even asking for a token -- which is exactly
     the window between pushing a site key and turning the Supabase side on,
     and is a bad way to find out somebody runs a strict ad blocker. */
  var lastError = null;

  function opts(extra, how) {
    return token(how).then(function (tok) {
      var o = extra || {};
      if (tok) { o.captchaToken = tok; lastError = null; }
      return o;
    }, function (e) {
      lastError = e;
      return extra || {};
    });
  }

  window.IronCaptcha = {
    on: on, token: token, opts: opts,
    /* What went wrong last time, so a refusal can name it. */
    lastError: function () { return lastError; }
  };
})();
