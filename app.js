/* =====================================================================
   IRON LEAGUE — app logic
   Plain JavaScript, no build step. Talks to Supabase over HTTPS.
   ===================================================================== */
(function () {
  'use strict';

  var CFG = window.APP_CONFIG || {};
  var TZ = CFG.TIMEZONE || 'Europe/Paris';
  var APP_VERSION = '1.0.0';

  /* ===================================================================
     1. THE POINTS TABLE
     Keep this identical to calc_points() in supabase/schema.sql.
     The server always recalculates, so this is only for the preview.
     =================================================================== */
  var EXERCISES = [
    { key: 'pushups',    tag: 'PSH', name: 'Push-ups',
      modes: [{ mode: 'reps', rate: 1, label: '1 pt / rep' }] },
    { key: 'handstand',  tag: 'HSP', name: 'Handstand Push-ups / Hold',
      modes: [{ mode: 'reps', rate: 3, label: '3 pts / rep' },
              { mode: 'seconds', rate: 1 / 5, label: '1 pt / 5 sec' }] },
    { key: 'dips',       tag: 'DIP', name: 'Dips',
      modes: [{ mode: 'reps', rate: 1.5, label: '1.5 pts / rep' }] },
    { key: 'pullups',    tag: 'PUL', name: 'Strict Pull-ups',
      modes: [{ mode: 'reps', rate: 3, label: '3 pts / rep' }] },
    { key: 'muscleup',   tag: 'MU',  name: 'Muscle-up / Flag',
      modes: [{ mode: 'reps', rate: 8, label: '8 pts / rep' },
              { mode: 'seconds', rate: 2, label: '2 pts / sec' }] },
    { key: 'airsquats',  tag: 'SQT', name: 'Air Squats',
      modes: [{ mode: 'reps', rate: 0.5, label: '0.5 pt / rep' }] },
    { key: 'pistols',    tag: 'PST', name: 'Pistol Squats',
      modes: [{ mode: 'reps', rate: 3, label: '3 pts / rep' }] },
    { key: 'kneeraises', tag: 'KNE', name: 'Knee Raises',
      modes: [{ mode: 'reps', rate: 1, label: '1 pt / rep' }] },
    { key: 'lsit',       tag: 'LST', name: 'L-Sit Hold',
      modes: [{ mode: 'seconds', rate: 1 / 3, label: '1 pt / 3 sec' }] },
    { key: 'run',        tag: 'RUN', name: 'Run',
      modes: [{ mode: 'km', rate: 10, label: '10 pts / km' }] },
    { key: 'sprints',    tag: 'SPR', name: 'Sprint Intervals',
      modes: [{ mode: 'minutes', rate: 5, label: '5 pts / min' }] },
    { key: 'stretch',    tag: 'STR', name: 'Stretching Session',
      modes: [{ mode: 'flat', rate: 2, label: '2 pts flat' }] }
  ];

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
    LEAGUE_FULL: 'That league is full — 20 fighters maximum.',
    NO_SUCH_LEAGUE: 'No league found with that code.',
    BAD_CODE: 'That restore code does not match any profile.',
    DEVICE_HAS_DATA: 'This phone already has a profile with workouts on it.',
    NO_PROFILE: 'Pick your name first.',
    TOO_MANY_LEAGUES: 'You already own 10 leagues.',
    NOT_SIGNED_IN: 'Connection lost — reload the page.'
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
    view: 'live'
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
  async function startOnboarding() {
    show('#onboard');
    var code = state.pendingCode;
    if (code) {
      var pv = await sb.rpc('league_preview', { p_code: code });
      var l = pv.data && pv.data[0];
      if (l) {
        $('#joinPreview').hidden = false;
        $('#joinPreview').innerHTML =
          '<div class="jc-k">YOU ARE JOINING</div>' +
          '<div class="jc-n">' + esc(l.name) + '</div>' +
          '<div class="muted small mono">' + l.members + '/' + l.max_members +
          ' FIGHTERS · CODE ' + esc(l.code) + '</div>' +
          (l.members >= l.max_members
            ? '<div class="err small">This league is full.</div>' : '');
      } else {
        state.pendingCode = null;
        try { sessionStorage.removeItem('ironleague.invite'); } catch (e) {}
      }
    }
    $('#newLeagueWrap').hidden = !!state.pendingCode;
    $('#nameInput').focus();
  }

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

      if (state.pendingCode) {
        var j = await sb.rpc('join_league_by_code', { p_code: state.pendingCode });
        if (j.error) throw j.error;
        state.leagueId = j.data.id;
      } else {
        var lname = ($('#firstLeague').value || '').trim() || (name.toUpperCase() + "'S LEAGUE");
        var c = await sb.rpc('create_league', { p_name: lname.slice(0, 28) });
        if (c.error) throw c.error;
        state.leagueId = c.data.id;
      }
      try { sessionStorage.removeItem('ironleague.invite'); } catch (e) {}
      state.pendingCode = null;
      localStorage.setItem(LS.league, state.leagueId);
      await enterApp();
    } catch (e) {
      $('#onboardErr').textContent = niceError(e);
    } finally {
      btn.disabled = false; btn.textContent = 'ENTER THE ARENA';
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
    var ms = weekDeadlineMs(wk) - Date.now();
    if (ms < 0) ms = 0;
    var s = Math.floor(ms / 1000);
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
        m = Math.floor(s % 3600 / 60), sec = s % 60;
    var pad = function (n) { return String(n).padStart(2, '0'); };
    var t = $('#cdTimer');
    t.textContent = (d > 0 ? d + 'D ' : '') + pad(h) + ':' + pad(m) + ':' + pad(sec);
    t.classList.toggle('urgent', s < 3600 * 6);

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
    await Promise.all([loadBoard(), loadHistory()]);
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
          '<span class="who"><span class="nm">' + esc(p.display_name) +
            (p.profile_id === me ? ' <span class="muted" style="font-size:11px">(YOU)</span>' : '') +
          '</span>' +
          '<span class="sub">' + p.entries + (Number(p.entries) === 1 ? ' entry' : ' entries') + '</span></span>' +
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
      var u = UNITS[w.mode] || { short: '' };
      var when = new Date(w.created_at);
      var day = new Intl.DateTimeFormat('en-GB', { weekday: 'short', timeZone: TZ }).format(when).toUpperCase();
      var hh = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: TZ }).format(when);
      return '<div class="fitem">' +
        '<span class="fx">' + esc(ex ? ex.name : w.exercise_key) +
          '<span class="famt"> · ' + num(w.amount) + ' ' + u.short + ' · ' + day + ' ' + hh + '</span></span>' +
        '<span class="fpts">+' + num(w.points) + '</span>' +
        (w.profile_id === me ? '<button class="del" data-del="' + w.id + '" title="Delete">✕</button>' : '') +
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
    var del = e.target.closest('[data-del]');
    if (del) {
      e.stopPropagation();
      if (!confirm('Delete this entry?')) return;
      var r = await sb.from('workouts').delete().eq('id', del.getAttribute('data-del'));
      if (r.error) { toast(niceError(r.error), true); return; }
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
            '<span class="week-who" style="display:block">' + esc(win.display_name) + '</span></span>' +
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

  $('#createBtn').addEventListener('click', async function () {
    var name = $('#newLeagueInput').value.trim();
    if (name.length < 2) { toast('Give the league a name.', true); return; }
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
    $('#pointsTable').innerHTML = EXERCISES.map(function (ex) {
      return '<div><span>' + esc(ex.name) + '</span><b>' +
        ex.modes.map(function (m) { return m.label; }).join(' / ') + '</b></div>';
    }).join('');
  }

  /* ===================================================================
     12. Tabs
     =================================================================== */
  function switchView(v) {
    state.view = v;
    $('#view-live').hidden = v !== 'live';
    $('#view-hall').hidden = v !== 'hall';
    $('#view-me').hidden = v !== 'me';
    Array.prototype.forEach.call(document.querySelectorAll('.tab'), function (t) {
      t.classList.toggle('is-active', t.getAttribute('data-view') === v);
    });
    if (v === 'me') renderMe();
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
    b.classList.remove('spin');
    toast('Refreshed');
  });

  /* ===================================================================
     13. Log workout modal
     =================================================================== */
  var modal = { key: null, mode: null };

  function buildExerciseSelect() {
    $('#exSelect').innerHTML = EXERCISES.map(function (ex) {
      return '<option value="' + ex.key + '">' + esc(ex.name) + '</option>';
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

  function applyMode() {
    var u = UNITS[modal.mode];
    $('#amountLbl').textContent = u.label;
    $('#amountInput').value = u.def;
    $('#amountInput').step = u.step;
    $('#quickRow').innerHTML = u.quick.map(function (q) {
      return '<button type="button" data-q="' + q + '">' + q + ' ' + u.short + '</button>';
    }).join('');
    var ex = exercise(modal.key);
    var m = ex.modes.filter(function (x) { return x.mode === modal.mode; })[0];
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
    var u = UNITS[modal.mode];
    var v = parseFloat($('#amountInput').value); if (!isFinite(v)) v = 0;
    v = Math.max(0, Math.round((v + dir * u.step) * 100) / 100);
    $('#amountInput').value = v;
    updatePreview();
  }

  function openModal() {
    if (!state.leagueId) { toast('Join or create a league first.', true); switchView('me'); return; }
    state.session = [];
    $('#sessionBox').hidden = true;
    $('#sessionList').innerHTML = '';
    $('#sessionTotal').textContent = '0';
    $('#modalErr').textContent = '';
    selectExercise(modal.key || EXERCISES[0].key);
    $('#logModal').hidden = false;
    document.body.style.overflow = 'hidden';
    document.body.classList.add('modal-open');
  }
  async function closeModal() {
    $('#logModal').hidden = true;
    document.body.style.overflow = '';
    document.body.classList.remove('modal-open');
    if (state.session.length) {
      state.feeds = {};
      await refreshAll();
      Object.keys(state.open).forEach(function (id) { if (state.open[id]) loadFeed(id); });
    }
  }
  $('#logBtn').addEventListener('click', openModal);
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
    var btn = this; btn.disabled = true; btn.textContent = 'SAVING…';
    try {
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
      toast('+' + num(r.data.points) + ' pts');
      $('#amountInput').value = UNITS[modal.mode].def;
      updatePreview();
    } catch (e) {
      $('#modalErr').textContent = niceError(e);
    } finally {
      btn.disabled = false; btn.textContent = 'ADD';
    }
  });

  function renderSession() {
    var box = $('#sessionBox');
    box.hidden = state.session.length === 0;
    var total = state.session.reduce(function (a, w) { return a + Number(w.points); }, 0);
    $('#sessionTotal').textContent = num(total);
    $('#sessionList').innerHTML = state.session.slice().reverse().map(function (w) {
      var ex = exercise(w.exercise_key), u = UNITS[w.mode];
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
