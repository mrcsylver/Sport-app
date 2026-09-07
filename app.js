/* =====================================================================
   IRON LEAGUE — app logic
   Plain JavaScript, no build step. Talks to Supabase over HTTPS.
   ===================================================================== */
(function () {
  'use strict';

  var CFG = window.APP_CONFIG || {};
  var TZ = CFG.TIMEZONE || 'Europe/Paris';
  var APP_VERSION = '1.5.0';

  /* ===================================================================
     1. THE POINTS TABLE
     Keep this identical to calc_points() in supabase/schema.sql.
     The server always recalculates, so this is only for the preview.
     =================================================================== */
  var EXERCISES = [
    { key: 'pushups',    cat: 'PUSH',     name: 'Push-ups',
      variants: 'Incline · Standard · Diamond',
      modes: [{ mode: 'reps', rate: 1, label: '1 pt / rep' }] },
    { key: 'dips',       cat: 'PUSH',     name: 'Dips',
      variants: 'Bench · Parallel bars · Rings',
      modes: [{ mode: 'reps', rate: 1.5, label: '1.5 pts / rep' }] },
    { key: 'handstand',  cat: 'PUSH',     name: 'Handstand Push-up / Hold',
      variants: 'Against a wall · Hanging · Freestanding',
      modes: [{ mode: 'reps', rate: 2.5, label: '2.5 pts / rep' },
              { mode: 'seconds', rate: 1 / 5, label: '1 pt / 5 sec' }] },

    { key: 'rows',       cat: 'PULL',     name: 'Inverted Rows',
      variants: 'Table · Low bar · Rings',
      modes: [{ mode: 'reps', rate: 1, label: '1 pt / rep' }] },
    { key: 'pullups',    cat: 'PULL',     name: 'Pull-ups',
      variants: 'Pronated · Supinated · Neutral — full range only',
      modes: [{ mode: 'reps', rate: 2, label: '2 pts / rep' }] },
    { key: 'muscleup',   cat: 'PULL',     name: 'Muscle-up / Flag Hold',
      variants: 'Bar · Rings · Human flag',
      modes: [{ mode: 'reps', rate: 3.5, label: '3.5 pts / rep' },
              { mode: 'seconds', rate: 2, label: '2 pts / sec' }] },

    { key: 'airsquats',  cat: 'LEGS',     name: 'Air Squats',
      variants: 'Bodyweight squats',
      modes: [{ mode: 'reps', rate: 0.5, label: '0.5 pt / rep' }] },
    { key: 'pistols',    cat: 'LEGS',     name: 'Pistol Squats',
      variants: 'Assisted · Full — counted per leg',
      modes: [{ mode: 'reps', rate: 2, label: '2 pts / rep' }] },

    { key: 'kneeraises', cat: 'CORE',     name: 'Knee / Leg Raises',
      variants: 'Floor · Hanging',
      modes: [{ mode: 'reps', rate: 1, label: '1 pt / rep' }] },
    { key: 'lsit',       cat: 'CORE',     name: 'L-Sit Hold',
      variants: 'Tuck · Advanced tuck · Full',
      modes: [{ mode: 'seconds', rate: 1 / 3, label: '1 pt / 3 sec' }] },

    { key: 'run',        cat: 'CARDIO',   name: 'Run',
      variants: 'Outdoor or treadmill',
      modes: [{ mode: 'km', rate: 5, label: '5 pts / km' }] },
    { key: 'sprints',    cat: 'CARDIO',   name: 'Sprint Intervals',
      variants: 'One sprint = 15 sec flat out, 100 m minimum',
      modes: [{ mode: 'reps', rate: 2, label: '2 pts / sprint',
                short: 'sprints', unitLabel: 'SPRINTS', step: 1, def: 6,
                quick: [4, 6, 8, 12] }] },
    { key: 'bike',       cat: 'CARDIO',   name: 'Biking',
      variants: 'Road · Trail · Stationary',
      modes: [{ mode: 'km', rate: 1.5, label: '1.5 pts / km' }] },
    { key: 'swim',       cat: 'CARDIO',   name: 'Swim',
      variants: 'Any stroke · active swim time',
      modes: [{ mode: 'minutes', rate: 8 / 60, label: '8 pts / hour',
                def: 30, quick: [30, 45, 60, 90] }] },
    { key: 'walk',       cat: 'CARDIO',   name: 'Walking',
      variants: 'Hiking counts too',
      modes: [{ mode: 'km', rate: 2.5, label: '2.5 pts / km' }] },

    { key: 'stretch',    cat: 'RECOVERY', name: 'Stretching Session',
      variants: 'At least 10 minutes of stretching · mobility, yoga',
      modes: [{ mode: 'flat', rate: 5, label: '5 pts / session' }] }
  ];

  /* Order the categories appear in menus and on the scoring card. */
  var CATEGORIES = ['PUSH', 'PULL', 'LEGS', 'CORE', 'CARDIO', 'RECOVERY'];

  /* Muscle groups that count towards the daily combo (recovery is excluded
     so a stretch cannot buy a group). Mirrors week_combo_bonus() in SQL. */
  var COMBO_CATS = ['PUSH', 'PULL', 'LEGS', 'CORE', 'CARDIO'];
  var COMBO_MIN = 10;
  var COMBO_TIERS = [{ n: 5, pts: 12 }, { n: 4, pts: 8 }, { n: 3, pts: 5 }];

  /* Avatars: animal emoji only. Nothing to upload, nothing to host. */
  var ANIMALS = (
    '🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🙈🙉🙊🐒🦍🦧' +
    '🐔🐧🐦🐤🦆🦅🦉🦇🦜🦚🦢🦩🐓🦃🕊️' +
    '🐺🐗🐴🦄🦓🦌🐪🐫🦒🦘🐘🦛🦏🐃🐂🐄🐎🐖🐏🐑🦙🐐' +
    '🐕🐩🦮🐈🐇🦝🦨🦡🦦🦥🐁🐀🐿️🦔' +
    '🐝🐛🦋🐌🐞🐜🦗🕷️🦂' +
    '🐢🐍🦎🦖🦕🐊' +
    '🐙🦑🦐🦞🦀🐡🐠🐟🐬🐳🐋🦈'
  ).match(/\p{Extended_Pictographic}\uFE0F?/gu) || [];

  var UNITS = {
    reps:    { label: 'REPS',       short: 'reps', step: 1,   def: 10, quick: [5, 10, 20, 50] },
    seconds: { label: 'SECONDS',    short: 'sec',  step: 5,   def: 30, quick: [15, 30, 60, 120] },
    minutes: { label: 'MINUTES',    short: 'min',  step: 1,   def: 10, quick: [5, 10, 20, 30] },
    km:      { label: 'KILOMETRES', short: 'km',   step: 0.5, def: 5,  quick: [1, 3, 5, 10] },
    flat:    { label: 'SESSIONS',   short: 'sessions', step: 1, def: 1, quick: [1, 2, 3] }
  };

  function exercise(key) {
    for (var i = 0; i < EXERCISES.length; i++) if (EXERCISES[i].key === key) return EXERCISES[i];
    return null;
  }
  function pointsFor(key, mode, amount) {
    var ex = exercise(key); if (!ex) return 0;
    for (var i = 0; i < ex.modes.length; i++) {
      if (ex.modes[i].mode === mode) return Math.round(amount * ex.modes[i].rate * 100) / 100;
    }
    return 0;
  }

  /* ===================================================================
     2. Small helpers
     =================================================================== */
  var $ = function (s) { return document.querySelector(s); };
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function num(n) {
    n = Math.round(Number(n) * 100) / 100;
    return (n % 1 === 0) ? String(n) : String(Math.round(n * 10) / 10);
  }
  var toastTimer;
  function toast(msg, bad) {
    var t = $('#toast');
    t.textContent = msg;
    t.className = 'toast' + (bad ? ' bad' : '');
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.hidden = true; }, bad ? 4200 : 2400);
  }
  var FRIENDLY = {
    LEAGUE_FULL: 'That league is full — 30 fighters maximum.',
    NO_SUCH_LEAGUE: 'No league found with that code. Check the 6 characters.',
    BAD_CODE: 'That restore code does not match any profile.',
    DEVICE_HAS_DATA: 'This phone already has a profile with workouts on it.',
    NO_PROFILE: 'Pick your name first.',
    TOO_MANY_LEAGUES: 'You already own 10 leagues.',
    NOT_SIGNED_IN: 'Connection lost — reload the page.',
    WEEK_CLOSED: 'That week is over — its entries are locked.',
    ALREADY_IN_CHALLENGE: 'You already have a duel open. Finish or cancel it first.',
    OWN_CHALLENGE: 'That is your own duel code.',
    NO_SUCH_CHALLENGE: 'No duel found with that code.',
    CHALLENGE_UNAVAILABLE: 'That duel is no longer open.',
    NOT_A_MEMBER: 'That duel belongs to a league you are not in.',
    REST_DAY: 'Sunday is a rest day — a stretching session is the only thing that counts.',
    REST_DAY_DONE: 'You already logged your recovery today. Rest.'
  };
  function niceError(e) {
    if (!e) return 'Something went wrong.';
    var m = e.message || e.error_description || String(e);
    for (var k in FRIENDLY) if (m.indexOf(k) !== -1) return FRIENDLY[k];
    if (/display_name_check|char_length/.test(m)) return 'Names must be 2 to 18 characters.';
    if (/Anonymous sign-ins are disabled/i.test(m)) {
      return 'Anonymous sign-ins are still OFF in Supabase (Authentication → Sign In / Providers).';
    }
    if (/Failed to fetch|NetworkError|load failed/i.test(m)) return 'No connection. Try again.';
    return m;
  }

  /* ===================================================================
     3. Weeks and the Sunday 23:59 deadline (timezone aware)
     =================================================================== */
  function tzOffsetMs(date, tz) {
    var dtf = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit'
    });
    var p = {}, parts = dtf.formatToParts(date), i;
    for (i = 0; i < parts.length; i++) p[parts[i].type] = parts[i].value;
    var asUTC = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
    return asUTC - Math.floor(date.getTime() / 1000) * 1000;
  }
  /* "Wall clock" date: a Date whose UTC fields hold the local time in TZ. */
  function wallNow() { var n = new Date(); return new Date(n.getTime() + tzOffsetMs(n, TZ)); }
  function wallToUtcMs(wallMs) {
    var g = wallMs - tzOffsetMs(new Date(wallMs), TZ);
    return wallMs - tzOffsetMs(new Date(g), TZ);
  }
  function iso(d) {
    return d.getUTCFullYear() + '-' +
      String(d.getUTCMonth() + 1).padStart(2, '0') + '-' +
      String(d.getUTCDate()).padStart(2, '0');
  }
  /* Monday of the current week, as YYYY-MM-DD (matches Postgres date_trunc). */
  function currentWeekStart() {
    var w = wallNow();
    var back = (w.getUTCDay() + 6) % 7;
    return iso(new Date(Date.UTC(w.getUTCFullYear(), w.getUTCMonth(), w.getUTCDate() - back)));
  }
  /* Sunday is a rest day: the league is closed and only recovery counts. */
  function isRestDay() { return wallNow().getUTCDay() === 0; }

  /* Instant of Saturday 23:59:59.999 — when the competition stops. */
  function competitionEndMs(weekStartIso) {
    var p = weekStartIso.split('-');
    return wallToUtcMs(Date.UTC(+p[0], +p[1] - 1, +p[2] + 5, 23, 59, 59, 999));
  }

  /* Instant of Sunday 23:59:59.999 that closes the given week. */
  function weekDeadlineMs(weekStartIso) {
    var p = weekStartIso.split('-');
    var wallEnd = Date.UTC(+p[0], +p[1] - 1, +p[2] + 6, 23, 59, 59, 999);
    return wallToUtcMs(wallEnd);
  }
  function weekRangeLabel(weekStartIso) {
    var p = weekStartIso.split('-');
    var a = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2]));
    var b = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + 6));
    var f = function (d) {
      return new Intl.DateTimeFormat('en-GB', {
        day: 'numeric', month: 'short', timeZone: 'UTC'
      }).format(d).toUpperCase();
    };
    return f(a) + ' – ' + f(b);
  }

  /* ===================================================================
     4. State
     =================================================================== */
  var sb = null;
  var state = {
    profile: null,
    leagues: [],
    leagueId: null,
    week: currentWeekStart(),
    board: [],
    history: [],
    open: {},          // profile ids whose activity feed is expanded
    openWeeks: {},
    feeds: {},
    session: [],       // items logged inside the currently open modal
    pendingCode: null,
    view: 'live',
    statsRange: 'week',
    duels: [],
    restDone: false
  };
  var LS = {
    league: 'ironleague.league'
  };

  /* ===================================================================
     5. Boot
     =================================================================== */
  function configured() {
    return CFG.SUPABASE_URL && CFG.SUPABASE_ANON_KEY &&
      CFG.SUPABASE_URL.indexOf('PASTE') === -1 &&
      CFG.SUPABASE_ANON_KEY.indexOf('PASTE') === -1 &&
      /^https?:\/\//.test(CFG.SUPABASE_URL);
  }
  function show(id) {
    ['#boot', '#setup', '#onboard', '#app'].forEach(function (s) {
      $(s).hidden = (s !== id);
    });
  }

  function readInviteCode() {
    var h = location.hash || '';
    var m = h.match(/join\/([A-Za-z0-9]{4,10})/) || h.match(/join=([A-Za-z0-9]{4,10})/);
    if (!m) {
      var q = new URLSearchParams(location.search);
      if (q.get('join')) m = [null, q.get('join')];
    }
    if (m) {
      try { sessionStorage.setItem('ironleague.invite', m[1].toUpperCase()); } catch (e) {}
      history.replaceState(null, '', location.pathname + location.search);
      return m[1].toUpperCase();
    }
    try { return sessionStorage.getItem('ironleague.invite'); } catch (e) { return null; }
  }

  async function boot() {
    if (CFG.APP_NAME) { $('#brandName').textContent = CFG.APP_NAME; }
    $('#version').textContent = 'IRON LEAGUE ' + APP_VERSION + ' · ' + TZ;

    if (!configured()) { show('#setup'); return; }
    if (typeof supabase === 'undefined') {
      show('#setup');
      $('#setupErr').textContent = 'Could not load vendor/supabase.js — is the whole folder uploaded?';
      return;
    }

    sb = supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, storageKey: 'ironleague.auth' }
    });

    state.pendingCode = readInviteCode() || (CFG.DEFAULT_LEAGUE_CODE || '').toUpperCase() || null;

    try {
      var got = await sb.auth.getSession();
      if (!got.data.session) {
        var anon = await sb.auth.signInAnonymously();
        if (anon.error) throw anon.error;
      }
    } catch (e) {
      failSetup(e);
      return;
    }

    try { await loadProfile(); } catch (e) { toast(niceError(e), true); }

    if (!state.profile) { startOnboarding(); return; }
    await enterApp();
  }

  /* The setup screen doubles as the "cannot reach the server" screen. */
  function failSetup(e) {
    var msg = niceError(e);
    show('#setup');
    if (/connection|reload the page/i.test(msg)) {
      $('#setupTitle').innerHTML = 'NO<br><span class="accent">SIGNAL</span>';
      $('#setupIntro').textContent = 'Iron League could not reach the server.';
      $('#setupSteps').hidden = true;
      $('#setupHelp').hidden = true;
      $('#retryBtn').hidden = false;
    }
    $('#setupErr').textContent = msg;
  }
  $('#retryBtn').addEventListener('click', function () { location.reload(); });

  async function loadProfile() {
    var u = await sb.auth.getUser();
    if (!u.data || !u.data.user) return;
    var r = await sb.from('profiles').select('*').eq('user_id', u.data.user.id).maybeSingle();
    if (r.error) throw r.error;
    state.profile = r.data;
  }

  /* ===================================================================
     6. Onboarding
     =================================================================== */
  /* 'invite'  = arrived through a friend's link, league already known
     'join'    = default: type the code you were given
     'create'  = deliberately starting a new group                        */
  var onboardMode = 'join';

  function setOnboardMode(m) {
    onboardMode = m;
    $('#joinWrap').hidden      = (m !== 'join');
    $('#newLeagueWrap').hidden = (m !== 'create');
    $('#joinPreview').hidden   = (m !== 'invite');
    $('#modeToggle').hidden    = (m === 'invite');
    $('#modeToggle').textContent = (m === 'create')
      ? 'Actually, I have a league code'
      : 'No code? Start a brand new league';
    $('#enterBtn').textContent = (m === 'create') ? 'CREATE MY LEAGUE' : 'ENTER THE ARENA';
  }

  async function startOnboarding() {
    show('#onboard');
    var code = state.pendingCode;
    if (code) {
      var pv = await sb.rpc('league_preview', { p_code: code });
      var l = pv.data && pv.data[0];
      if (l) {
        $('#joinPreview').innerHTML =
          '<div class="jc-k">YOU ARE JOINING</div>' +
          '<div class="jc-n">' + esc(l.name) + '</div>' +
          '<div class="muted small mono">' + l.members + '/' + l.max_members +
          ' FIGHTERS · CODE ' + esc(l.code) + '</div>' +
          (l.members >= l.max_members
            ? '<div class="err small">This league is full.</div>' : '');
        setOnboardMode('invite');
        $('#nameInput').focus();
        return;
      }
      state.pendingCode = null;
      try { sessionStorage.removeItem('ironleague.invite'); } catch (e) {}
    }
    setOnboardMode('join');
    $('#nameInput').focus();
  }

  $('#modeToggle').addEventListener('click', function () {
    setOnboardMode(onboardMode === 'create' ? 'join' : 'create');
    $('#onboardErr').textContent = '';
  });

  /* Check the code as it is typed, so nobody discovers a typo after signing up. */
  var codeCheckTimer;
  $('#joinCode').addEventListener('input', function () {
    var v = this.value.trim().toUpperCase();
    this.value = v;
    var hint = $('#codeHint');
    clearTimeout(codeCheckTimer);
    hint.style.color = '';
    if (v.length < 6) {
      hint.className = 'muted small';
      hint.textContent = 'The 6 characters your friend sent you.';
      return;
    }
    hint.className = 'muted small';
    hint.textContent = 'Checking…';
    codeCheckTimer = setTimeout(async function () {
      try {
        var pv = await sb.rpc('league_preview', { p_code: v });
        var l = pv.data && pv.data[0];
        if (!l) {
          hint.className = 'err small';
          hint.textContent = 'No league with that code.';
        } else if (l.members >= l.max_members) {
          hint.className = 'err small';
          hint.textContent = l.name + ' is full (' + l.members + '/' + l.max_members + ').';
        } else {
          hint.className = 'small';
          hint.style.color = 'var(--green)';
          hint.textContent = '✓ ' + l.name + ' — ' + l.members + '/' + l.max_members + ' fighters';
        }
      } catch (e) { /* leave the hint as it is */ }
    }, 350);
  });

  $('#restoreToggle').addEventListener('click', function () {
    var b = $('#restoreBox'); b.hidden = !b.hidden;
    if (!b.hidden) $('#restoreInput').focus();
  });

  $('#enterForm').addEventListener('submit', async function (ev) {
    ev.preventDefault();
    var btn = $('#enterBtn');
    var name = $('#nameInput').value.trim();
    $('#onboardErr').textContent = '';
    if (name.length < 2) { $('#onboardErr').textContent = 'Name must be at least 2 characters.'; return; }
    btn.disabled = true; btn.textContent = 'ENTERING…';
    try {
      var p = await sb.rpc('create_profile', { p_name: name });
      if (p.error) throw p.error;
      state.profile = p.data;

      if (onboardMode === 'create') {
        var lname = ($('#firstLeague').value || '').trim();
        if (lname.length < 2) throw new Error('Give your new league a name.');
        var c = await sb.rpc('create_league', { p_name: lname.slice(0, 28) });
        if (c.error) throw c.error;
        state.leagueId = c.data.id;
      } else {
        var code = state.pendingCode || $('#joinCode').value.trim().toUpperCase();
        if (!code) {
          throw new Error('Enter the league code your friend sent you, ' +
                          'or tap "Start a brand new league" below.');
        }
        var j = await sb.rpc('join_league_by_code', { p_code: code });
        if (j.error) throw j.error;
        state.leagueId = j.data.id;
      }
      try { sessionStorage.removeItem('ironleague.invite'); } catch (e) {}
      state.pendingCode = null;
      localStorage.setItem(LS.league, state.leagueId);
      await enterApp();
    } catch (e) {
      $('#onboardErr').textContent = niceError(e);
    } finally {
      btn.disabled = false;
      btn.textContent = (onboardMode === 'create') ? 'CREATE MY LEAGUE' : 'ENTER THE ARENA';
    }
  });

  $('#restoreBtn').addEventListener('click', async function () {
    var code = $('#restoreInput').value.trim();
    $('#onboardErr').textContent = '';
    if (!code) return;
    try {
      var r = await sb.rpc('restore_profile', { p_code: code });
      if (r.error) throw r.error;
      state.profile = r.data;
      toast('Welcome back, ' + r.data.display_name);
      await enterApp();
    } catch (e) {
      $('#onboardErr').textContent = niceError(e);
    }
  });

  /* ===================================================================
     7. Entering the app
     =================================================================== */
  async function enterApp() {
    show('#app');
    try {
      var w = await sb.rpc('current_week_start');
      if (!w.error && w.data) state.week = w.data;
    } catch (e) { /* keep the locally computed week */ }

    await loadLeagues();

    // An invite arriving while already signed in: join it now.
    if (state.pendingCode) {
      var known = state.leagues.filter(function (l) { return l.code === state.pendingCode; })[0];
      if (known) { state.leagueId = known.id; }
      else {
        try {
          var j = await sb.rpc('join_league_by_code', { p_code: state.pendingCode });
          if (j.error) throw j.error;
          state.leagueId = j.data.id;
          toast('Joined ' + j.data.name);
          await loadLeagues();
        } catch (e) { toast(niceError(e), true); }
      }
      try { sessionStorage.removeItem('ironleague.invite'); } catch (e) {}
      state.pendingCode = null;
      localStorage.setItem(LS.league, state.leagueId);
    }

    buildExerciseSelect();
    buildPointsTable();
    buildComboRules();
    loadRestState();

    if (!state.leagues.length) { renderMe(); switchView('me'); tick(); return; }

    var saved = localStorage.getItem(LS.league);
    var ok = state.leagues.filter(function (l) { return l.id === state.leagueId; })[0] ||
             state.leagues.filter(function (l) { return l.id === saved; })[0];
    state.leagueId = (ok || state.leagues[0]).id;
    localStorage.setItem(LS.league, state.leagueId);

    renderHeader();
    tick();
    await refreshAll();
    startAutoRefresh();
  }

  function league() {
    return state.leagues.filter(function (l) { return l.id === state.leagueId; })[0] || null;
  }

  async function loadLeagues() {
    var r = await sb.rpc('my_leagues');
    if (r.error) { toast(niceError(r.error), true); return; }
    state.leagues = r.data || [];
  }

  function renderHeader() {
    var l = league();
    if (!l) return;
    $('#lgName').textContent = l.name;
    $('#lgMeta').textContent = l.members + '/' + l.max_members + ' · CODE ' + l.code;
    $('#weekLabel').textContent = weekRangeLabel(state.week);
  }

  /* ===================================================================
     8. Countdown to Sunday 23:59
     =================================================================== */
  var lastWeekSeen = state.week;
  function tick() {
    var wk = currentWeekStart();
    var rest = isRestDay();
    var ms = (rest ? weekDeadlineMs(wk) : competitionEndMs(wk)) - Date.now();
    if (ms < 0) ms = 0;
    var s = Math.floor(ms / 1000);
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
        m = Math.floor(s % 3600 / 60), sec = s % 60;
    var pad = function (n) { return String(n).padStart(2, '0'); };
    var t = $('#cdTimer');
    t.textContent = (d > 0 ? d + 'D ' : '') + pad(h) + ':' + pad(m) + ':' + pad(sec);
    t.classList.toggle('urgent', s < 3600 * 6 && !rest);
    document.querySelector('.cd-label').textContent =
      rest ? 'REST DAY · OPENS IN' : 'LEAGUE CLOSES IN';
    $('#countdown').classList.toggle('resting', rest);

    if (state.view === 'duel') tickDuel();

    if (wk !== lastWeekSeen) {          // a new week just started
      lastWeekSeen = wk;
      state.week = wk;
      state.feeds = {};
      state.open = {};
      rollOver();
      toast('New week. Everyone back to zero.');
    }
  }
  setInterval(tick, 1000);

  async function rollOver() {
    if (!sb || !state.leagueId) return;
    try {
      var w = await sb.rpc('current_week_start');
      if (!w.error && w.data) state.week = w.data;
    } catch (e) { /* keep local value */ }
    refreshAll();
  }

  /* ===================================================================
     9. Live leaderboard
     =================================================================== */
  async function refreshAll() {
    await Promise.all([loadBoard(), loadHistory(), loadCombo()]);
    renderHeader();
  }

  async function loadBoard() {
    if (!state.leagueId) return;
    var r = await sb.rpc('league_leaderboard', { p_league: state.leagueId, p_week: state.week });
    if (r.error) { toast(niceError(r.error), true); return; }
    state.board = r.data || [];
    renderBoard();
  }

  function ranked(rows) {
    var out = [], rank = 0, prev = null;
    for (var i = 0; i < rows.length; i++) {
      var pts = Number(rows[i].points) || 0;
      if (prev === null || pts !== prev) { rank = i + 1; prev = pts; }
      out.push({ row: rows[i], rank: pts > 0 ? rank : null });
    }
    return out;
  }

  function renderBoard() {
    var box = $('#board');
    if (!state.board.length) {
      box.innerHTML = '<div class="empty">Nobody here yet. Share your link!</div>';
      return;
    }
    var me = state.profile ? state.profile.id : null;
    var html = ranked(state.board).map(function (r) {
      var p = r.row, pts = Number(p.points) || 0;
      var cls = 'row' + (r.rank && r.rank <= 3 ? ' r' + r.rank : '') + (p.profile_id === me ? ' me' : '');
      var open = !!state.open[p.profile_id];
      return '<div class="' + cls + '" data-id="' + p.profile_id + '">' +
        '<button class="rowbtn" type="button" data-toggle="' + p.profile_id + '">' +
          '<span class="rank">' + (r.rank ? r.rank : '–') + '</span>' +
          (p.avatar ? '<span class="av">' + esc(p.avatar) + '</span>' : '') +
          '<span class="who"><span class="nm">' + esc(p.display_name) +
            (p.profile_id === me ? ' <span class="muted" style="font-size:11px">(YOU)</span>' : '') +
          '</span>' +
          '<span class="sub">' + p.entries + (Number(p.entries) === 1 ? ' entry' : ' entries') +
            (Number(p.bonus) > 0 ? ' · <b class="cbadge">+' + num(p.bonus) + ' combo</b>' : '') +
          '</span></span>' +
          '<span class="pts">' + num(pts) + '<small>PTS</small></span>' +
          '<span class="chev">' + (open ? '▲' : '▼') + '</span>' +
        '</button>' +
        (open ? '<div class="feed" data-feed="' + p.profile_id + '">' +
                  (state.feeds[p.profile_id] ? feedHtml(state.feeds[p.profile_id]) :
                   '<div class="muted small" style="padding:8px 0">Loading…</div>') +
                '</div>' : '') +
      '</div>';
    }).join('');
    box.innerHTML = html;
  }

  function feedHtml(rows) {
    if (!rows.length) return '<div class="muted small" style="padding:8px 0">Nothing logged this week.</div>';
    var me = state.profile ? state.profile.id : null;
    return rows.map(function (w) {
      var ex = exercise(w.exercise_key);
      var u = unitFor(w.exercise_key, w.mode);
      var when = new Date(w.created_at);
      var day = new Intl.DateTimeFormat('en-GB', { weekday: 'short', timeZone: TZ }).format(when).toUpperCase();
      var hh = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: TZ }).format(when);
      return '<div class="fitem">' +
        '<span class="fx">' + esc(ex ? ex.name : w.exercise_key) +
          '<span class="famt"> · ' + num(w.amount) + ' ' + u.short + ' · ' + day + ' ' + hh + '</span></span>' +
        '<span class="fpts">+' + num(w.points) + '</span>' +
        (w.profile_id === me && !isRestDay()
          ? '<button class="del" data-edit="' + w.id + '" title="Edit">✎</button>' +
            '<button class="del" data-del="' + w.id + '" title="Delete">✕</button>'
          : '') +
      '</div>';
    }).join('');
  }

  async function loadFeed(profileId) {
    var r = await sb.from('workouts').select('*')
      .eq('league_id', state.leagueId)
      .eq('profile_id', profileId)
      .eq('week_start', state.week)
      .order('created_at', { ascending: false });
    if (r.error) { toast(niceError(r.error), true); return; }
    state.feeds[profileId] = r.data || [];
    var box = document.querySelector('[data-feed="' + profileId + '"]');
    if (box) box.innerHTML = feedHtml(state.feeds[profileId]);
  }

  $('#board').addEventListener('click', async function (e) {
    var ed = e.target.closest('[data-edit]');
    if (ed) {
      e.stopPropagation();
      openEdit(ed.getAttribute('data-edit'));
      return;
    }
    var del = e.target.closest('[data-del]');
    if (del) {
      e.stopPropagation();
      if (!confirm('Delete this entry?')) return;
      var r = await sb.from('workouts').delete()
                .eq('id', del.getAttribute('data-del')).select();
      if (r.error) { toast(niceError(r.error), true); return; }
      if (!r.data || !r.data.length) {
        toast('That week is over — its entries are locked.', true); return;
      }
      state.feeds = {};
      toast('Entry deleted');
      await refreshAll();
      Object.keys(state.open).forEach(function (id) { if (state.open[id]) loadFeed(id); });
      return;
    }
    var btn = e.target.closest('[data-toggle]');
    if (!btn) return;
    var id = btn.getAttribute('data-toggle');
    state.open[id] = !state.open[id];
    renderBoard();
    if (state.open[id] && !state.feeds[id]) loadFeed(id);
  });

  /* ===================================================================
     10. Hall of fame
     =================================================================== */
  async function loadHistory() {
    if (!state.leagueId) return;
    var r = await sb.rpc('weekly_history', { p_league: state.leagueId });
    if (r.error) { toast(niceError(r.error), true); return; }
    state.history = r.data || [];
    renderHall();
  }

  function renderHall() {
    var box = $('#hall');
    if (!state.history.length) {
      box.innerHTML = '<div class="empty">No finished week yet.<br>' +
        'The first champion is crowned on Sunday at 23:59.</div>';
      return;
    }
    var weeks = [], byWeek = {};
    state.history.forEach(function (r) {
      if (!byWeek[r.week_start]) { byWeek[r.week_start] = []; weeks.push(r.week_start); }
      byWeek[r.week_start].push(r);
    });
    box.innerHTML = weeks.map(function (wk) {
      var rows = byWeek[wk].slice().sort(function (a, b) { return b.points - a.points; });
      var win = rows[0];
      var open = !!state.openWeeks[wk];
      return '<div class="week">' +
        '<button class="week-top" type="button" data-week="' + wk + '">' +
          '<span class="crown">👑</span>' +
          '<span><span class="week-when">' + weekRangeLabel(wk) + '</span>' +
            '<span class="week-who" style="display:block">' +
              (win.avatar ? esc(win.avatar) + ' ' : '') + esc(win.display_name) + '</span></span>' +
          '<span class="week-pts">' + num(win.points) + '<br>' +
            '<span class="muted" style="font-size:10px;letter-spacing:.14em">PTS</span></span>' +
          '<span class="week-chev">' + (open ? '▲' : '▼') + '</span>' +
        '</button>' +
        (open ? '<div class="week-body">' + rows.map(function (r, i) {
            return '<div class="mini"><span class="mn">' + (i + 1) + '. ' + esc(r.display_name) +
                   '</span><span class="mp">' + num(r.points) + ' pts · ' + r.entries + '</span></div>';
          }).join('') + '</div>' : '') +
      '</div>';
    }).join('');
  }

  $('#hall').addEventListener('click', function (e) {
    var b = e.target.closest('[data-week]');
    if (!b) return;
    var wk = b.getAttribute('data-week');
    state.openWeeks[wk] = !state.openWeeks[wk];
    renderHall();
  });

  /* ===================================================================
     11. Leagues / profile tab
     =================================================================== */
  function shareUrl(code) {
    return location.origin + location.pathname + '#/join/' + code;
  }

  function renderMe() {
    var box = $('#leagueList');
    if (!state.leagues.length) {
      box.innerHTML = '<div class="empty">You are not in a league yet.<br>' +
        'Create one below, or open a friend\'s invite link.</div>';
    } else {
      box.innerHTML = state.leagues.map(function (l) {
        var full = l.members >= l.max_members;
        return '<button class="lg-card' + (l.id === state.leagueId ? ' active' : '') +
          '" type="button" data-league="' + l.id + '">' +
          '<span><span class="t">' + esc(l.name) + '</span>' +
          '<span class="s">CODE ' + esc(l.code) +
          (state.profile && l.owner_id === state.profile.id ? ' · YOURS' : '') + '</span></span>' +
          '<span class="cap' + (full ? ' full' : '') + '">' + l.members + '/' + l.max_members + '</span>' +
        '</button>';
      }).join('');
    }
    var l = league();
    $('#shareLink').value = l ? shareUrl(l.code) : '—';
    if (state.profile) {
      $('#renameInput').value = state.profile.display_name;
      $('#restoreCode').textContent = state.profile.restore_code;
      buildAvatarGrid();
    }
    if (navigator.share) $('#shareBtn').hidden = !l;
  }

  $('#leagueList').addEventListener('click', async function (e) {
    var b = e.target.closest('[data-league]');
    if (!b) return;
    state.leagueId = b.getAttribute('data-league');
    localStorage.setItem(LS.league, state.leagueId);
    state.feeds = {}; state.open = {}; state.openWeeks = {};
    renderHeader(); renderMe();
    switchView('live');
    await refreshAll();
  });

  $('#copyBtn').addEventListener('click', async function () {
    var v = $('#shareLink').value;
    try {
      await navigator.clipboard.writeText(v);
      toast('Link copied — paste it in your group chat');
    } catch (e) {
      $('#shareLink').select(); document.execCommand('copy');
      toast('Link copied');
    }
  });
  $('#shareBtn').addEventListener('click', function () {
    var l = league(); if (!l) return;
    navigator.share({
      title: l.name,
      text: 'Join my calisthenics league "' + l.name + '" — weekly leaderboard, no mercy.',
      url: shareUrl(l.code)
    }).catch(function () {});
  });

  $('#joinBtn').addEventListener('click', async function () {
    var code = $('#joinCodeInput').value.trim();
    if (!code) return;
    try {
      var j = await sb.rpc('join_league_by_code', { p_code: code });
      if (j.error) throw j.error;
      $('#joinCodeInput').value = '';
      state.leagueId = j.data.id;
      localStorage.setItem(LS.league, state.leagueId);
      await loadLeagues();
      renderMe(); renderHeader();
      toast('Joined ' + j.data.name);
      switchView('live');
      await refreshAll();
    } catch (e) { toast(niceError(e), true); }
  });

  $('#createToggle').addEventListener('click', function () {
    var w = $('#createWrap');
    w.hidden = !w.hidden;
    this.textContent = w.hidden ? 'SHOW CREATE OPTION' : 'HIDE';
    if (!w.hidden) $('#newLeagueInput').focus();
  });

  $('#createBtn').addEventListener('click', async function () {
    var name = $('#newLeagueInput').value.trim();
    if (name.length < 2) { toast('Give the league a name.', true); return; }
    if (state.leagues.length && !confirm(
      'This creates a SEPARATE league with its own leaderboard.\n\n' +
      'To add friends to "' + league().name + '", close this and send them ' +
      'your invite link instead.\n\nCreate a new league anyway?')) return;
    try {
      var c = await sb.rpc('create_league', { p_name: name });
      if (c.error) throw c.error;
      $('#newLeagueInput').value = '';
      state.leagueId = c.data.id;
      localStorage.setItem(LS.league, state.leagueId);
      await loadLeagues();
      renderMe(); renderHeader();
      buildExerciseSelect();
      toast('League created — code ' + c.data.code);
      await refreshAll();
    } catch (e) { toast(niceError(e), true); }
  });

  $('#renameBtn').addEventListener('click', async function () {
    var n = $('#renameInput').value.trim();
    if (n.length < 2) { toast('Names must be at least 2 characters.', true); return; }
    try {
      var r = await sb.rpc('rename_profile', { p_name: n });
      if (r.error) throw r.error;
      state.profile = r.data;
      toast('Name updated');
      await refreshAll();
    } catch (e) { toast(niceError(e), true); }
  });

  function buildPointsTable() {
    $('#pointsTable').innerHTML = CATEGORIES.map(function (cat) {
      var list = EXERCISES.filter(function (e) { return e.cat === cat; });
      if (!list.length) return '';
      return '<div class="pcat">' + cat + '</div>' + list.map(function (ex) {
        return '<div class="pex">' +
          '<div class="pex-n">' + esc(ex.name) + '</div>' +
          '<div class="pex-v">' + esc(ex.variants) + '</div>' +
          ex.modes.map(function (m) {
            return '<div class="pex-r">' + m.label + '</div>';
          }).join('') +
        '</div>';
      }).join('');
    }).join('');
  }

  /* ===================================================================
     10b. Duels — 24h head to head. A duel never stores its own workouts;
     it simply reads what you already logged for the league in its window,
     so nothing is ever entered twice.
     =================================================================== */
  function hhmmss(ms) {
    if (ms < 0) ms = 0;
    var s = Math.floor(ms / 1000), pad = function (n) { return String(n).padStart(2, '0'); };
    return pad(Math.floor(s / 3600)) + ':' + pad(Math.floor(s % 3600 / 60)) + ':' + pad(s % 60);
  }

  async function loadDuels() {
    if (!state.leagueId) return;
    var r = await sb.rpc('my_challenges');
    if (r.error) { toast(niceError(r.error), true); return; }
    state.duels = r.data || [];
    renderDuels();
  }

  function renderDuels() {
    var open = state.duels.filter(function (d) {
      return d.status === 'LIVE' || d.status === 'PENDING';
    })[0];
    var past = state.duels.filter(function (d) {
      return d.status === 'FINISHED' || d.status === 'CANCELLED' || d.status === 'EXPIRED';
    });

    $('#duelStart').hidden = !!open;
    $('#duelActive').innerHTML = open ? (open.status === 'LIVE' ? liveDuel(open) : pendingDuel(open)) : '';
    $('#duelPastHead').hidden = !past.length;
    $('#duelPast').innerHTML = past.map(pastDuel).join('');
    tickDuel();
  }

  function liveDuel(d) {
    var me = Number(d.me_points), foe = Number(d.foe_points);
    return '<div class="duel live">' +
      '<div class="duel-top"><span class="duel-tag">DUEL LIVE</span>' +
        '<span class="duel-clock" data-ends="' + d.ends_at + '">--:--:--</span></div>' +
      '<div class="duel-body">' +
        '<div class="duel-side' + (me > foe ? ' lead' : '') + '">' +
          '<div class="duel-av">' + (d.me_avatar || '🔥') + '</div>' +
          '<div class="duel-name">YOU</div>' +
          '<div class="duel-pts">' + num(me) + '</div></div>' +
        '<div class="duel-vs">VS</div>' +
        '<div class="duel-side' + (foe > me ? ' lead' : '') + '">' +
          '<div class="duel-av">' + (d.foe_avatar || '🔥') + '</div>' +
          '<div class="duel-name">' + esc(d.foe_name || '—') + '</div>' +
          '<div class="duel-pts">' + num(foe) + '</div></div>' +
      '</div>' +
      '<div class="duel-note"><b>Log once.</b> Everything you log normally counts ' +
        'for your league week <b>and</b> for this duel. There is nothing extra to enter.</div>' +
    '</div>';
  }

  function pendingDuel(d) {
    var left = new Date(d.created_at).getTime() + 24 * 3600e3 - Date.now();
    return '<div class="duel">' +
      '<div class="duel-top"><span class="duel-tag">WAITING FOR AN OPPONENT</span>' +
        '<span class="duel-clock" data-ends="' +
          new Date(new Date(d.created_at).getTime() + 24 * 3600e3).toISOString() +
        '">--:--:--</span></div>' +
      '<div style="padding:12px 13px">' +
        '<p class="muted small">Send this code to someone in ' + esc(d.league_name) +
          '. The first one to enter it starts a 24 hour duel with you.</p>' +
        '<div class="duel-code">' + esc(d.code) + '</div>' +
        '<div class="copyrow">' +
          '<button class="btn ghost sm" style="flex:1" data-duelcopy="' + esc(d.code) + '">COPY CODE</button>' +
          '<button class="btn ghost sm" style="flex:1" data-duelcancel="' + d.id + '">CANCEL</button>' +
        '</div>' +
        (left < 0 ? '' : '<p class="muted small" style="margin-top:10px">Unclaimed codes expire after 24 hours.</p>') +
      '</div>' +
    '</div>';
  }

  function pastDuel(d) {
    var me = Number(d.me_points), foe = Number(d.foe_points);
    var cls = 'd', label = 'DRAW';
    if (d.status === 'CANCELLED') { cls = 'd'; label = 'CANCELLED'; }
    else if (d.status === 'EXPIRED') { cls = 'd'; label = 'NO TAKER'; }
    else if (me > foe) { cls = 'w'; label = 'WON'; }
    else if (foe > me) { cls = 'l'; label = 'LOST'; }
    var settled = d.status === 'FINISHED';
    return '<div class="duel-row">' +
      '<span class="duel-res ' + cls + '">' + label + '</span>' +
      '<span class="dr">' + (settled ? 'vs ' + (d.foe_avatar ? d.foe_avatar + ' ' : '') +
        esc(d.foe_name || '—') : esc(d.league_name)) + '</span>' +
      '<span class="ds">' + (settled ? num(me) + ' – ' + num(foe) : '') + '</span>' +
    '</div>';
  }

  /* the live/pending clock, driven by the one-second loop */
  function tickDuel() {
    Array.prototype.forEach.call(document.querySelectorAll('[data-ends]'), function (el) {
      var ms = new Date(el.getAttribute('data-ends')).getTime() - Date.now();
      el.textContent = hhmmss(ms);
      if (ms <= 0) el.textContent = 'OVER';
    });
  }

  $('#duelCreateBtn').addEventListener('click', async function () {
    this.disabled = true;
    try {
      var r = await sb.rpc('create_challenge', { p_league: state.leagueId });
      if (r.error) throw r.error;
      toast('Duel code ' + r.data.code + ' — send it to someone');
      await loadDuels();
    } catch (e) { toast(niceError(e), true); }
    this.disabled = false;
  });

  $('#duelAcceptBtn').addEventListener('click', async function () {
    var code = $('#duelCodeInput').value.trim();
    if (!code) return;
    try {
      var r = await sb.rpc('accept_challenge', { p_code: code });
      if (r.error) throw r.error;
      $('#duelCodeInput').value = '';
      $('#duelPreview').textContent = '';
      toast('Duel on. 24 hours.');
      await loadDuels();
    } catch (e) { toast(niceError(e), true); }
  });

  /* show who is behind a code before committing to it */
  var duelPeekTimer;
  $('#duelCodeInput').addEventListener('input', function () {
    var v = this.value.trim().toUpperCase();
    this.value = v;
    var out = $('#duelPreview');
    clearTimeout(duelPeekTimer);
    out.className = 'muted small';
    if (v.length < 6) { out.textContent = ''; return; }
    duelPeekTimer = setTimeout(async function () {
      var r = await sb.rpc('challenge_preview', { p_code: v });
      var c = r.data && r.data[0];
      if (!c) { out.className = 'err small'; out.textContent = 'No duel with that code.'; return; }
      if (c.status !== 'PENDING') {
        out.className = 'err small';
        out.textContent = 'That duel is ' + c.status.toLowerCase() + '.';
        return;
      }
      out.style.color = 'var(--green)';
      out.textContent = '✓ ' + (c.challenger_avatar ? c.challenger_avatar + ' ' : '') +
        c.challenger_name + ' is waiting — ' + c.league_name;
    }, 350);
  });

  $('#duelActive').addEventListener('click', async function (e) {
    var copy = e.target.closest('[data-duelcopy]');
    if (copy) {
      var code = copy.getAttribute('data-duelcopy');
      try { await navigator.clipboard.writeText(code); } catch (err) {}
      toast('Code ' + code + ' copied');
      return;
    }
    var can = e.target.closest('[data-duelcancel]');
    if (can) {
      if (!confirm('Cancel this duel code?')) return;
      var r = await sb.rpc('cancel_challenge', { p_id: can.getAttribute('data-duelcancel') });
      if (r.error) { toast(niceError(r.error), true); return; }
      toast('Duel cancelled');
      await loadDuels();
    }
  });

  /* ===================================================================
     11a. Daily combo
     =================================================================== */
  function comboReward(n) {
    for (var i = 0; i < COMBO_TIERS.length; i++) {
      if (n >= COMBO_TIERS[i].n) return COMBO_TIERS[i].pts;
    }
    return 0;
  }

  async function loadCombo() {
    if (!state.leagueId) return;
    if (isRestDay()) {
      $('#comboCard').hidden = false;
      $('#comboCard').className = 'combo rest';
      $('#comboCard').innerHTML =
        '<div class="combo-top"><span class="combo-t">REST DAY</span>' +
          '<span class="combo-p">LEAGUE CLOSED</span></div>' +
        '<div class="combo-hint">Saturday night closed the week — nothing can be ' +
        'added, edited or deleted today. One <b>stretching session</b> is the only ' +
        'thing that still counts. Recover, and come back Monday.</div>';
      return;
    }
    $('#comboCard').className = 'combo';
    var r = await sb.rpc('my_combo_today', { p_league: state.leagueId });
    if (r.error) return;
    var got = {};
    (r.data || []).forEach(function (x) { got[x.category] = Number(x.points); });
    var hit = COMBO_CATS.filter(function (c) { return (got[c] || 0) >= COMBO_MIN; });
    var earned = comboReward(hit.length);
    var next = null;
    for (var i = COMBO_TIERS.length - 1; i >= 0; i--) {
      if (COMBO_TIERS[i].n > hit.length) { next = COMBO_TIERS[i]; break; }
    }
    $('#comboCard').hidden = false;
    $('#comboCard').innerHTML =
      '<div class="combo-top"><span class="combo-t">DAILY COMBO</span>' +
        '<span class="combo-p' + (earned ? ' on' : '') + '">' +
          (earned ? '+' + earned + ' TODAY' : 'NO BONUS YET') + '</span></div>' +
      '<div class="combo-pips">' + COMBO_CATS.map(function (c) {
        var v = got[c] || 0, done = v >= COMBO_MIN;
        return '<span class="pip' + (done ? ' done' : '') + '">' + c +
               '<i>' + num(Math.min(v, COMBO_MIN)) + '/' + COMBO_MIN + '</i></span>';
      }).join('') + '</div>' +
      '<div class="combo-hint">' + (next
        ? (next.n - hit.length) + ' more group' + (next.n - hit.length > 1 ? 's' : '') +
          ' today for +' + next.pts
        : 'Maximum combo reached today. ') + '</div>';
  }

  function buildComboRules() {
    $('#comboRules').innerHTML =
      '<p class="muted small">Score at least <b>' + COMBO_MIN + ' points</b> in ' +
      'different muscle groups on the <b>same day</b> and the bonus is added ' +
      'automatically. Only the highest tier counts.</p>' +
      '<div class="ptable">' + COMBO_TIERS.slice().reverse().map(function (t) {
        return '<div class="pex" style="display:flex;justify-content:space-between">' +
          '<span>' + t.n + ' groups in one day</span>' +
          '<b style="color:var(--red);font-family:var(--display)">+' + t.pts + '</b></div>';
      }).join('') + '</div>' +
      '<p class="muted small" style="margin-top:8px">Groups: ' + COMBO_CATS.join(' · ') +
      '. Recovery does not count.</p>';
  }

  /* ===================================================================
     11b. Personal stats
     =================================================================== */
  var CAT_COLOR = { PUSH: '#ff2e2e', PULL: '#ff8a1f', LEGS: '#ffc93c',
                    CORE: '#26d07c', CARDIO: '#3aa8ff', RECOVERY: '#9b7bff' };

  async function loadStats() {
    if (!state.leagueId) return;
    $('#statsWho').textContent = state.profile ? state.profile.display_name : '';
    var r = await sb.rpc('my_stats', {
      p_league: state.leagueId, p_all: state.statsRange === 'all'
    });
    if (r.error) { toast(niceError(r.error), true); return; }
    renderStats(r.data || []);
  }

  function renderStats(rows) {
    var total = rows.reduce(function (a, r) { return a + Number(r.total_points); }, 0);
    var entries = rows.reduce(function (a, r) { return a + Number(r.entries); }, 0);
    var days = rows.reduce(function (a, r) { return Math.max(a, Number(r.active_days)); }, 0);
    $('#statPoints').textContent = num(total);
    $('#statSub').textContent = entries + (entries === 1 ? ' entry' : ' entries') +
      (days ? ' · ' + days + (days === 1 ? ' active day' : ' active days') : '') +
      (league() ? ' · ' + league().name : '');

    /* share of points per muscle group */
    var byCat = {};
    rows.forEach(function (r) {
      byCat[r.category] = (byCat[r.category] || 0) + Number(r.total_points);
    });
    var cats = CATEGORIES.filter(function (c) { return byCat[c] > 0; });
    $('#statBar').innerHTML = total > 0 ? cats.map(function (c) {
      return '<span style="width:' + (byCat[c] / total * 100).toFixed(2) + '%;background:' +
        CAT_COLOR[c] + '" title="' + c + '"></span>';
    }).join('') : '';
    $('#statLegend').innerHTML = cats.map(function (c) {
      return '<span><i style="background:' + CAT_COLOR[c] + '"></i>' + c +
             ' ' + num(byCat[c]) + '</span>';
    }).join('');

    if (!rows.length) {
      $('#statList').innerHTML = '<div class="empty">Nothing logged ' +
        (state.statsRange === 'all' ? 'yet.' : 'this week yet.') + '</div>';
      return;
    }
    $('#statList').innerHTML = rows.map(function (r) {
      var ex = exercise(r.exercise_key);
      var u = unitFor(r.exercise_key, r.mode);
      return '<div class="srow">' +
        '<span class="sdot" style="background:' + (CAT_COLOR[r.category] || '#666') + '"></span>' +
        '<span class="sname">' + esc(ex ? ex.name : r.exercise_key) +
          '<span class="ssub">' + num(r.total_amount) + ' ' + u.short +
          ' · ' + r.entries + 'x</span></span>' +
        '<span class="spts">' + num(r.total_points) + '</span>' +
      '</div>';
    }).join('');
  }

  $('#statsRange').addEventListener('click', function (e) {
    var b = e.target.closest('[data-range]'); if (!b) return;
    state.statsRange = b.getAttribute('data-range');
    Array.prototype.forEach.call(this.querySelectorAll('button'), function (x) {
      x.classList.toggle('on', x === b);
    });
    loadStats();
  });

  /* ===================================================================
     11c. Light / dark
     =================================================================== */
  function applyTheme(pref) {
    var root = document.documentElement;
    if (pref === 'auto') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', pref);
    try { localStorage.setItem('ironleague.theme', pref); } catch (e) {}
    var dark = pref === 'dark' || (pref === 'auto' &&
      !window.matchMedia('(prefers-color-scheme: light)').matches);
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', dark ? '#08090c' : '#f4f5f7');
    Array.prototype.forEach.call(document.querySelectorAll('#themeRow button'), function (b) {
      b.classList.toggle('on', b.getAttribute('data-theme') === pref);
    });
  }
  function savedTheme() {
    try { return localStorage.getItem('ironleague.theme') || 'dark'; } catch (e) { return 'dark'; }
  }
  function buildAvatarGrid() {
    var mine = state.profile && state.profile.avatar;
    $('#avatarGrid').innerHTML = ANIMALS.map(function (e) {
      return '<button type="button" class="av-opt' + (e === mine ? ' on' : '') +
             '" data-av="' + e + '">' + e + '</button>';
    }).join('');
  }
  async function saveAvatar(v) {
    try {
      var r = await sb.rpc('set_avatar', { p_avatar: v });
      if (r.error) throw r.error;
      state.profile = r.data;
      buildAvatarGrid();
      toast(v ? 'You are now ' + v : 'Animal removed');
      await refreshAll();
    } catch (e) { toast(niceError(e), true); }
  }
  $('#avatarGrid').addEventListener('click', function (e) {
    var b = e.target.closest('[data-av]'); if (!b) return;
    saveAvatar(b.getAttribute('data-av'));
  });
  $('#avatarClear').addEventListener('click', function () { saveAvatar(''); });

  $('#themeRow').addEventListener('click', function (e) {
    var b = e.target.closest('[data-theme]'); if (!b) return;
    applyTheme(b.getAttribute('data-theme'));
  });
  applyTheme(savedTheme());

  /* ===================================================================
     12. Tabs
     =================================================================== */
  function switchView(v) {
    state.view = v;
    $('#view-live').hidden  = v !== 'live';
    $('#view-duel').hidden  = v !== 'duel';
    $('#view-hall').hidden  = v !== 'hall';
    $('#view-stats').hidden = v !== 'stats';
    $('#view-me').hidden    = v !== 'me';
    Array.prototype.forEach.call(document.querySelectorAll('.tab'), function (t) {
      t.classList.toggle('is-active', t.getAttribute('data-view') === v);
    });
    if (v === 'me') renderMe();
    if (v === 'stats') loadStats();
    if (v === 'duel') loadDuels();
    window.scrollTo(0, 0);
  }
  Array.prototype.forEach.call(document.querySelectorAll('.tab'), function (t) {
    t.addEventListener('click', function () { switchView(t.getAttribute('data-view')); });
  });
  $('#leagueBtn').addEventListener('click', function () { switchView('me'); });
  $('#refreshBtn').addEventListener('click', async function () {
    var b = $('#refreshBtn'); b.classList.add('spin');
    state.feeds = {};
    await loadLeagues();
    await refreshAll();
    Object.keys(state.open).forEach(function (id) { if (state.open[id]) loadFeed(id); });
    if (state.view === 'stats') await loadStats();
    if (state.view === 'duel') await loadDuels();
    b.classList.remove('spin');
    toast('Refreshed');
  });

  /* ===================================================================
     13. Log workout modal
     =================================================================== */
  var modal = { key: null, mode: null, editing: null };

  function buildExerciseSelect() {
    if (isRestDay()) {
      $('#exSelect').innerHTML = EXERCISES.filter(function (e) { return e.cat === 'RECOVERY'; })
        .map(function (ex) {
          return '<option value="' + ex.key + '">' + esc(ex.name) + '</option>';
        }).join('');
      selectExercise('stretch');
      return;
    }
    $('#exSelect').innerHTML = CATEGORIES.map(function (cat) {
      var list = EXERCISES.filter(function (e) { return e.cat === cat; });
      if (!list.length) return '';
      return '<optgroup label="' + cat + '">' + list.map(function (ex) {
        return '<option value="' + ex.key + '">' + esc(ex.name) + '</option>';
      }).join('') + '</optgroup>';
    }).join('');
    selectExercise(EXERCISES[0].key);
  }

  function selectExercise(key) {
    var ex = exercise(key);
    modal.key = key;
    modal.mode = ex.modes[0].mode;
    $('#exSelect').value = key;
    var row = $('#modeRow');
    if (ex.modes.length > 1) {
      row.hidden = false;
      row.innerHTML = ex.modes.map(function (m, i) {
        return '<button type="button" data-mode="' + m.mode + '" class="' + (i === 0 ? 'on' : '') + '">' +
          (m.mode === 'reps' ? 'REPS' : UNITS[m.mode].label) + '</button>';
      }).join('');
    } else {
      row.hidden = true; row.innerHTML = '';
    }
    applyMode();
  }

  /* A mode may override how its unit is named and stepped
     (a "sprint" is a rep, but nobody calls it that). */
  function unitFor(key, mode) {
    var base = UNITS[mode] || {};
    var ex = exercise(key);
    var m = ex && ex.modes.filter(function (x) { return x.mode === mode; })[0];
    return {
      label: (m && m.unitLabel) || base.label,
      short: (m && m.short) || base.short,
      step:  (m && m.step)  || base.step,
      def:   (m && m.def)   || base.def,
      quick: (m && m.quick) || base.quick
    };
  }

  function applyMode() {
    var u = unitFor(modal.key, modal.mode);
    $('#amountLbl').textContent = u.label;
    $('#amountInput').value = u.def;
    $('#amountInput').step = u.step;
    var ex = exercise(modal.key);
    var m = ex.modes.filter(function (x) { return x.mode === modal.mode; })[0];
    $('#quickRow').innerHTML = u.quick.map(function (q) {
      return '<button type="button" data-q="' + q + '">' + q + ' ' + u.short + '</button>';
    }).join('');
    $('#exVariants').textContent = ex.cat + ' · ' + ex.variants;
    $('#rateLbl').textContent = m ? m.label : '';
    updatePreview();
  }

  function updatePreview() {
    var v = parseFloat($('#amountInput').value);
    if (!isFinite(v) || v < 0) v = 0;
    $('#ptsPreview').textContent = num(pointsFor(modal.key, modal.mode, v));
  }

  $('#exSelect').addEventListener('change', function () { selectExercise(this.value); });
  $('#modeRow').addEventListener('click', function (e) {
    var b = e.target.closest('[data-mode]'); if (!b) return;
    modal.mode = b.getAttribute('data-mode');
    Array.prototype.forEach.call(this.querySelectorAll('button'), function (x) {
      x.classList.toggle('on', x === b);
    });
    applyMode();
  });
  $('#quickRow').addEventListener('click', function (e) {
    var b = e.target.closest('[data-q]'); if (!b) return;
    $('#amountInput').value = b.getAttribute('data-q');
    updatePreview();
  });
  $('#amountInput').addEventListener('input', updatePreview);
  $('#plusBtn').addEventListener('click', function () { bump(1); });
  $('#minusBtn').addEventListener('click', function () { bump(-1); });
  function bump(dir) {
    var u = unitFor(modal.key, modal.mode);
    var v = parseFloat($('#amountInput').value); if (!isFinite(v)) v = 0;
    v = Math.max(0, Math.round((v + dir * u.step) * 100) / 100);
    $('#amountInput').value = v;
    updatePreview();
  }

  function findEntry(id) {
    for (var pid in state.feeds) {
      var rows = state.feeds[pid] || [];
      for (var i = 0; i < rows.length; i++) if (rows[i].id === id) return rows[i];
    }
    return null;
  }

  /* Correcting an entry. Only possible while its week is still running —
     the database refuses anything older, so this can never rewrite history. */
  function openEdit(id) {
    var w = findEntry(id);
    if (!w) { toast('Entry not found — refresh and try again.', true); return; }
    selectExercise(w.exercise_key);
    modal.mode = w.mode;
    var row = $('#modeRow');
    if (!row.hidden) {
      Array.prototype.forEach.call(row.querySelectorAll('button'), function (b) {
        b.classList.toggle('on', b.getAttribute('data-mode') === w.mode);
      });
    }
    applyMode();
    $('#amountInput').value = Number(w.amount);
    updatePreview();

    modal.editing = id;
    state.session = [];
    $('#sessionBox').hidden = true;
    $('#modalErr').textContent = '';
    $('#sheetTitle').textContent = 'EDIT ENTRY';
    $('#addBtn').textContent = 'SAVE CHANGES';
    $('#cancelEditBtn').hidden = false;
    document.querySelector('.sheet-foot').hidden = true;   // CANCEL EDIT replaces DONE
    $('#logModal').hidden = false;
    document.body.style.overflow = 'hidden';
    document.body.classList.add('modal-open');
  }

  /* On a rest day, has this athlete already taken their one session? */
  async function loadRestState() {
    state.restDone = false;
    if (!isRestDay() || !state.leagueId || !state.profile) return;
    var r = await sb.from('workouts').select('created_at')
      .eq('league_id', state.leagueId)
      .eq('profile_id', state.profile.id)
      .eq('week_start', state.week);
    if (r.error || !r.data) return;
    var today = iso(wallNow());
    state.restDone = r.data.some(function (w) {
      return iso(new Date(new Date(w.created_at).getTime() +
             tzOffsetMs(new Date(w.created_at), TZ))) === today;
    });
  }

  function applyRestMode() {
    var rest = isRestDay();
    $('#restNote').hidden = !rest;
    if (!rest) { $('#addBtn').disabled = false; return; }
    $('#restNote').innerHTML = state.restDone
      ? '<b>Recovery already logged.</b> That is your one session for today — ' +
        'the league opens again on Monday.'
      : '<b>Rest day.</b> The league closed on Saturday night. One stretching ' +
        'session is all that counts today, and only once.';
    $('#addBtn').disabled = state.restDone;
  }

  function openModal() {
    if (!state.leagueId) { toast('Join or create a league first.', true); switchView('me'); return; }
    modal.editing = null;
    $('#sheetTitle').textContent = 'LOG WORKOUT';
    $('#addBtn').textContent = 'ADD';
    $('#cancelEditBtn').hidden = true;
    document.querySelector('.sheet-foot').hidden = false;
    state.session = [];
    $('#sessionBox').hidden = true;
    $('#sessionList').innerHTML = '';
    $('#sessionTotal').textContent = '0';
    $('#modalErr').textContent = '';
    selectExercise(modal.key || EXERCISES[0].key);
    $('#logModal').hidden = false;
    document.body.style.overflow = 'hidden';
    document.body.classList.add('modal-open');
    loadRestState().then(applyRestMode);
  }
  async function closeModal(force) {
    $('#logModal').hidden = true;
    document.body.style.overflow = '';
    document.body.classList.remove('modal-open');
    modal.editing = null;
    if (state.session.length || force === true) {
      state.feeds = {};
      await refreshAll();
      Object.keys(state.open).forEach(function (id) { if (state.open[id]) loadFeed(id); });
      if (state.view === 'stats') loadStats();
      if (state.view === 'duel') loadDuels();
    }
  }
  $('#logBtn').addEventListener('click', openModal);
  $('#cancelEditBtn').addEventListener('click', function () { closeModal(); });
  Array.prototype.forEach.call(document.querySelectorAll('[data-close]'), function (b) {
    b.addEventListener('click', closeModal);
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !$('#logModal').hidden) closeModal();
  });

  $('#addBtn').addEventListener('click', async function () {
    var amount = parseFloat($('#amountInput').value);
    $('#modalErr').textContent = '';
    if (!isFinite(amount) || amount <= 0) { $('#modalErr').textContent = 'Enter a number above zero.'; return; }
    var btn = this; btn.disabled = true;
    var label = modal.editing ? 'SAVE CHANGES' : 'ADD';
    btn.textContent = 'SAVING…';
    try {
      if (modal.editing) {
        var up = await sb.from('workouts').update({
          exercise_key: modal.key, mode: modal.mode, amount: amount
        }).eq('id', modal.editing).select();
        if (up.error) throw up.error;
        if (!up.data || !up.data.length) {
          throw new Error('That week is over — its entries are locked.');
        }
        toast('Updated — now ' + num(up.data[0].points) + ' pts');
        await closeModal(true);
        return;
      }
      var r = await sb.from('workouts').insert({
        league_id: state.leagueId,
        profile_id: state.profile.id,
        exercise_key: modal.key,
        mode: modal.mode,
        amount: amount
      }).select().single();
      if (r.error) throw r.error;
      state.session.push(r.data);
      renderSession();
      if (isRestDay()) { state.restDone = true; applyRestMode(); }
      toast('+' + num(r.data.points) + ' pts');
      $('#amountInput').value = unitFor(modal.key, modal.mode).def;
      updatePreview();
    } catch (e) {
      $('#modalErr').textContent = niceError(e);
    } finally {
      btn.textContent = label;
      btn.disabled = isRestDay() && state.restDone;   // keep the rest lock on
    }
  });

  function renderSession() {
    var box = $('#sessionBox');
    box.hidden = state.session.length === 0;
    var total = state.session.reduce(function (a, w) { return a + Number(w.points); }, 0);
    $('#sessionTotal').textContent = num(total);
    $('#sessionList').innerHTML = state.session.slice().reverse().map(function (w) {
      var ex = exercise(w.exercise_key), u = unitFor(w.exercise_key, w.mode);
      return '<div class="sitem">' +
        '<span class="sx">' + esc(ex ? ex.name : w.exercise_key) +
        ' <span class="muted">· ' + num(w.amount) + ' ' + u.short + '</span></span>' +
        '<span class="sp">+' + num(w.points) + '</span>' +
        '<button class="del" data-undo="' + w.id + '" title="Remove">✕</button>' +
      '</div>';
    }).join('');
  }

  $('#sessionList').addEventListener('click', async function (e) {
    var b = e.target.closest('[data-undo]'); if (!b) return;
    var id = b.getAttribute('data-undo');
    var r = await sb.from('workouts').delete().eq('id', id);
    if (r.error) { toast(niceError(r.error), true); return; }
    state.session = state.session.filter(function (w) { return w.id !== id; });
    renderSession();
    toast('Removed');
  });

  /* ===================================================================
     14. Keep it live
     =================================================================== */
  var autoTimer = null;
  function startAutoRefresh() {
    if (autoTimer) clearInterval(autoTimer);
    autoTimer = setInterval(function () {
      if (document.hidden || !$('#logModal').hidden) return;
      loadBoard();
      if (state.view === 'duel') loadDuels();
    }, 25000);
  }
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden && state.leagueId) { state.feeds = {}; refreshAll(); }
  });

  /* ===================================================================
     15. PWA plumbing
     =================================================================== */
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('./sw.js').catch(function () {});
    });
  }
  var deferredPrompt = null;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    deferredPrompt = e;
    $('#installBtn').hidden = false;
  });
  $('#installBtn').addEventListener('click', async function () {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
    $('#installBtn').hidden = true;
  });

  boot();
})();
