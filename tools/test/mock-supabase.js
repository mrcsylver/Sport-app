/* In-memory stand-in for @supabase/supabase-js, mirroring schema.sql */
(function () {
  /* The fake database survives a page reload so a test can switch phones. */
  var DB;
  try { DB = JSON.parse(localStorage.getItem('mock.db')); } catch (e) { DB = null; }
  if (!DB) DB = { profiles: [], leagues: [], members: [], workouts: [], challenges: [] };
  DB.challenges = DB.challenges || [];
  /* A small stand-in for the bounty pool the control room manages. */
  DB.bounties = DB.bounties || [
    { idx: 0, name: 'DAWN PRESS', descr: '40 push-ups before 09:00', points: 30,
      spec: { reqs: [{ ex: 'pushups', mode: 'reps', min: 40, to_h: 9 }] } },
    { idx: 1, name: 'CENTURY PUSH', descr: '100 push-ups across the day', points: 40,
      spec: { reqs: [{ ex: 'pushups', mode: 'reps', min: 100 }] } },
    { idx: 2, name: 'THREE-MINUTE PLANK', descr: 'Three minutes of plank', points: 20,
      spec: { reqs: [{ ex: 'plank', mode: 'minutes', min: 3 }] } }
  ];
  DB.builtinBounties = DB.builtinBounties === undefined ? 3 : DB.builtinBounties;
  DB.schedule = DB.schedule || {};
  /* Enough of the exercise table for the control room's picker. The app
     itself carries its own copy, so this is only read by admin.html. */
  DB.exercises = DB.exercises || [
    { key: 'pushups', name: 'Push-up',  cat: 'PUSH',   sort: 3,  modes: { reps: { rate: 1 } } },
    { key: 'pullups', name: 'Pull-up',  cat: 'PULL',   sort: 24, modes: { reps: { rate: 2 } } },
    { key: 'plank',   name: 'Plank',    cat: 'CORE',   sort: 60, modes: { minutes: { rate: 0.2 } } },
    { key: 'run',     name: 'Run',      cat: 'CARDIO', sort: 64, modes: { km: { rate: 6 } } }
  ];
  window.__EXERCISES__ = DB.exercises;
  window.__DB__ = DB;
  function save() { try { localStorage.setItem('mock.db', JSON.stringify(DB)); } catch (e) {} }
  window.__save__ = save;
  var TZ = 'Europe/Paris';
  var uid = null;
  try { uid = localStorage.getItem('mock.uid'); } catch (e) {}
  uid = uid || window.__UID__ || 'auth-me';
  var signedIn = !!window.__SIGNED_IN__;

  function id() { return 'id-' + Math.random().toString(36).slice(2, 10); }
  function tzOffsetMs(d) {
    var dtf = new Intl.DateTimeFormat('en-US', { timeZone: TZ, hourCycle: 'h23', year: 'numeric',
      month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
    var p = {}; dtf.formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
    return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second) - Math.floor(d / 1000) * 1000;
  }
  function weekStart(date) {
    var n = date || new Date();
    var w = new Date(n.getTime() + tzOffsetMs(n));
    var back = (w.getUTCDay() + 6) % 7;
    var d = new Date(Date.UTC(w.getUTCFullYear(), w.getUTCMonth(), w.getUTCDate() - back));
    return d.toISOString().slice(0, 10);
  }
  window.__weekStart__ = weekStart;

  var RATES = { pushups:{reps:1}, dips:{reps:1.5}, handstand:{reps:2.5,seconds:1/5},
    rows:{reps:1}, pullups:{reps:2}, muscleup:{reps:3.5,seconds:2},
    airsquats:{reps:0.5}, pistols:{reps:2}, calves:{reps:0.2},
    kneeraises:{reps:1}, lsit:{seconds:1/3}, plank:{minutes:2}, twists:{reps:0.25},
    run:{km:5}, sprints:{reps:2}, bike:{km:1.5}, swim:{minutes:8/60}, walk:{km:2.5},
    stretch:{flat:5} };
  var CATS = { pushups:'PUSH',dips:'PUSH',handstand:'PUSH', rows:'PULL',pullups:'PULL',muscleup:'PULL',
    airsquats:'LEGS',pistols:'LEGS',calves:'LEGS', kneeraises:'CORE',lsit:'CORE',plank:'CORE',twists:'CORE',
    run:'CARDIO',sprints:'CARDIO',bike:'CARDIO',swim:'CARDIO',walk:'CARDIO', stretch:'RECOVERY' };
  function calc(k, m, a) { return Math.round((((RATES[k] || {})[m]) || 0) * a * 100) / 100; }
  window.__calc__ = calc;

  function me() { return DB.profiles.filter(function (p) { return p.user_id === uid; })[0] || null; }
  function isMember(lid) { var m = me(); return !!m && DB.members.some(function (x) { return x.league_id === lid && x.profile_id === m.id; }); }
  function ok(d) { return Promise.resolve({ data: d, error: null }); }
  function bad(msg) { return Promise.resolve({ data: null, error: new Error(msg) }); }

  DB.challenges = DB.challenges || [];
  function chStatus(c) {
    var now = Date.now();
    if (c.cancelled_at) return 'CANCELLED';
    if (!c.accepted_at && new Date(c.created_at).getTime() < now - 864e5) return 'EXPIRED';
    if (!c.accepted_at) return 'PENDING';
    return now < new Date(c.ends_at).getTime() ? 'LIVE' : 'FINISHED';
  }
  function chPoints(lg, pid, from, to) {
    if (!from || !pid) return 0;
    return Math.round(DB.workouts.filter(function (w) {
      return w.league_id === lg && w.profile_id === pid &&
             w.created_at >= from && w.created_at < to;
    }).reduce(function (s, w) { return s + w.points; }, 0) * 100) / 100;
  }
  function openCh(pid) {
    return DB.challenges.some(function (c) {
      return (c.challenger_id === pid || c.opponent_id === pid) &&
             ['PENDING', 'LIVE'].indexOf(chStatus(c)) !== -1;
    });
  }

  var RPC = {
    current_week_start: function () { return ok(weekStart()); },
    create_profile: function (a) {
      var p = me(); if (p) return ok(p);
      if (a.p_name.trim().length < 2) return bad('display_name_check');
      p = { id: id(), user_id: uid, display_name: a.p_name.trim(),
            restore_code: 'A1B2C3D4', created_at: new Date().toISOString() };
      DB.profiles.push(p); return ok(p);
    },
    rename_profile: function (a) { var p = me(); if (!p) return bad('NO_PROFILE'); p.display_name = a.p_name.trim(); return ok(p); },
    restore_profile: function (a) {
      var t = DB.profiles.filter(function (p) { return p.restore_code === a.p_code.toUpperCase(); })[0];
      if (!t) return bad('BAD_CODE');
      t.user_id = uid; return ok(t);
    },
    league_preview: function (a) {
      var l = DB.leagues.filter(function (x) { return x.code === a.p_code.toUpperCase(); })[0];
      if (!l) return ok([]);
      return ok([{ id: l.id, name: l.name, code: l.code, max_members: l.max_members,
        members: DB.members.filter(function (m) { return m.league_id === l.id; }).length }]);
    },
    create_league: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      var l = { id: id(), name: a.p_name, code: 'K' + Math.random().toString(36).slice(2, 7).toUpperCase(),
                owner_id: p.id, max_members: 20 };
      DB.leagues.push(l);
      DB.members.push({ league_id: l.id, profile_id: p.id, joined_at: new Date().toISOString() });
      return ok(l);
    },
    join_league_by_code: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      var l = DB.leagues.filter(function (x) { return x.code === a.p_code.toUpperCase(); })[0];
      if (!l) return bad('NO_SUCH_LEAGUE');
      if (DB.members.some(function (m) { return m.league_id === l.id && m.profile_id === p.id; })) return ok(l);
      if (DB.members.filter(function (m) { return m.league_id === l.id; }).length >= l.max_members) return bad('LEAGUE_FULL');
      DB.members.push({ league_id: l.id, profile_id: p.id, joined_at: new Date().toISOString() });
      return ok(l);
    },
    my_leagues: function () {
      var p = me(); if (!p) return ok([]);
      return ok(DB.members.filter(function (m) { return m.profile_id === p.id; }).map(function (m) {
        var l = DB.leagues.filter(function (x) { return x.id === m.league_id; })[0];
        /* Same columns as the real my_leagues(). Dropping badge here made
           the crest look like it never saved, which is a lie the tests must
           not be able to tell. */
        return { id: l.id, name: l.name, code: l.code, owner_id: l.owner_id, max_members: l.max_members,
          members: DB.members.filter(function (x) { return x.league_id === l.id; }).length,
          joined_at: m.joined_at, badge: l.badge || null,
          rest_dow: l.rest_dow || [7], season_weeks: l.season_weeks || null };
      }));
    },
    my_combo_today: function (a) {
      var p = me(); if (!p) return ok([]);
      var today = new Date().toISOString().slice(0, 10), agg = {};
      DB.workouts.filter(function (w) {
        return w.league_id === a.p_league && w.profile_id === p.id &&
               w.created_at.slice(0, 10) === today && CATS[w.exercise_key] !== 'RECOVERY';
      }).forEach(function (w) {
        agg[CATS[w.exercise_key]] = (agg[CATS[w.exercise_key]] || 0) + w.points;
      });
      return ok(Object.keys(agg).map(function (k) { return { category: k, points: agg[k] }; }));
    },
    set_avatar: function (a) { var p = me(); if (!p) return bad('NO_PROFILE');
      p.avatar = a.p_avatar || null; return ok(p); },
    league_leaderboard: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var wk = a.p_week || weekStart();
      var rows = DB.members.filter(function (m) { return m.league_id === a.p_league; }).map(function (m) {
        var p = DB.profiles.filter(function (x) { return x.id === m.profile_id; })[0];
        var ws = DB.workouts.filter(function (w) {
          return w.league_id === a.p_league && w.profile_id === p.id && w.week_start === wk; });
        var base = Math.round(ws.reduce(function (s, w) { return s + w.points; }, 0) * 100) / 100;
        var byDay = {};
        ws.forEach(function (w) {
          if (CATS[w.exercise_key] === 'RECOVERY') return;
          var d = w.created_at.slice(0, 10);
          byDay[d] = byDay[d] || {};
          byDay[d][CATS[w.exercise_key]] = (byDay[d][CATS[w.exercise_key]] || 0) + w.points;
        });
        var bonus = 0;
        Object.keys(byDay).forEach(function (d) {
          var n = Object.keys(byDay[d]).filter(function (c) { return byDay[d][c] >= 10; }).length;
          bonus += n >= 5 ? 12 : n === 4 ? 8 : n === 3 ? 5 : 0;
        });
        // lifetime drives the rank banner on each row
        var life = DB.workouts.filter(function (w) {
          return w.league_id === a.p_league && w.profile_id === p.id;
        }).reduce(function (t, w) { return t + w.points; }, 0);
        return { profile_id: p.id, display_name: p.display_name, avatar: p.avatar || null,
          joined_at: m.joined_at, entries: ws.length, lifetime: Math.round(life * 100) / 100,
          base_points: base, bonus: bonus, points: Math.round((base + bonus) * 100) / 100 };
      });
      rows.sort(function (x, y) { return y.points - x.points || (x.joined_at < y.joined_at ? -1 : 1); });
      return ok(rows);
    },
    set_name_color: function (a) { var p = me(); if (!p) return bad('NO_PROFILE');
      p.name_color = a.p_color || null; save(); return ok(p); },
    current_raid: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var mem = DB.members.filter(function (m) { return m.league_id === a.p_league; }).length;
      var keys = ['pushups','widepush','diamondpush','declinepush','kneepush'];
      var tot = 0, by = {};
      DB.workouts.forEach(function (w) {
        if (w.league_id !== a.p_league || keys.indexOf(w.exercise_key) < 0) return;
        if (w.mode !== 'reps') return;
        tot += w.amount; by[w.profile_id] = (by[w.profile_id] || 0) + w.amount;
      });
      var topId = Object.keys(by).sort(function (x, y) { return by[y] - by[x]; })[0];
      var topP = topId && DB.profiles.filter(function (q) { return q.id === topId; })[0];
      var target = 175 * mem;
      return ok([{ idx: 0, name: 'THE WALL', descr: 'Push-ups, all of you, one pile',
        unit: 'push-ups', target: target, progress: tot, members: mem,
        done: tot >= target, top_name: topP ? topP.display_name : null,
        top_amount: topId ? by[topId] : null }]);
    },
    admin_leagues: function () {
      var p = me(); if (!p || !p.is_admin) return ok([]);
      return ok(DB.leagues.map(function (l) {
        var o = DB.profiles.filter(function (x) { return x.id === l.owner_id; })[0];
        var ws = DB.workouts.filter(function (w) { return w.league_id === l.id; });
        return { id: l.id, name: l.name, code: l.code,
                 owner_name: o ? o.display_name : '?',
                 members: DB.members.filter(function (m) { return m.league_id === l.id; }).length,
                 workouts: ws.length,
                 last_log: ws.length ? ws[ws.length - 1].created_at : null,
                 created_at: l.created_at || new Date().toISOString() };
      }));
    },
    admin_players: function () {
      var p = me(); if (!p || !p.is_admin) return ok([]);
      return ok(DB.profiles.map(function (q) {
        var ws = DB.workouts.filter(function (w) { return w.profile_id === q.id; });
        return { id: q.id, display_name: q.display_name, avatar: q.avatar || null,
                 restore_code: q.restore_code, leagues:
                   DB.members.filter(function (m) { return m.profile_id === q.id; }).length,
                 workouts: ws.length,
                 points: ws.reduce(function (t, w) { return t + w.points; }, 0),
                 last_log: ws.length ? ws[ws.length - 1].created_at : null,
                 created_at: q.created_at || new Date().toISOString(),
                 is_admin: !!q.is_admin };
      }));
    },
    /* The bounty pool the control room manages. The real ones live in SQL;
       these behave the same way from the page's point of view. */
    admin_bounties: function () {
      var p = me(); if (!p || !p.is_admin) return ok([]);
      return ok(DB.bounties.map(function (b) {
        return { idx: b.idx, name: b.name, descr: b.descr, points: b.points,
                 spec: b.spec, runs_on: null, custom: b.idx >= DB.builtinBounties };
      }));
    },
    admin_schedule: function () {
      var p = me(); if (!p || !p.is_admin) return ok([]);
      var out = [], w = weekStart();
      for (var i = 0; i < 26; i++) {
        var day = new Date(w + 'T00:00:00Z');
        day.setUTCDate(day.getUTCDate() + i * 7);
        var iso = day.toISOString().slice(0, 10);
        var pinned = DB.schedule[iso];
        var idx = pinned !== undefined ? pinned : (i % DB.bounties.length);
        var b = DB.bounties[idx] || DB.bounties[0];
        out.push({ week_start: iso, bounty_idx: b.idx, name: b.name, descr: b.descr,
                   points: b.points, pinned: pinned !== undefined, note: null });
      }
      return ok(out);
    },
    admin_pin_bounty: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      DB.schedule[a.p_week] = a.p_idx; save(); return ok(null);
    },
    admin_unpin_bounty: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      delete DB.schedule[a.p_week]; save(); return ok(null);
    },
    admin_add_bounty: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      if (!a.p_name || a.p_name.trim().length < 3) return bad('Give it a name');
      if (!(a.p_points >= 5 && a.p_points <= 100)) {
        return bad('Points must be between 5 and 100');
      }
      var ex = (window.__EXERCISES__ || []).filter(function (e) {
        return e.key === a.p_ex; })[0];
      if (!ex || !ex.modes[a.p_mode]) return bad('That exercise cannot be logged that way');
      var idx = DB.bounties.length;
      DB.bounties.push({ idx: idx, name: a.p_name.trim().toUpperCase(),
        descr: a.p_descr || '', points: a.p_points,
        spec: { reqs: [{ ex: a.p_ex, mode: a.p_mode, min: a.p_min }] } });
      save(); return ok(idx);
    },
    admin_delete_bounty: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      if (a.p_idx < DB.builtinBounties) {
        return bad('A built-in bounty cannot be deleted, only left unpinned');
      }
      DB.bounties = DB.bounties.filter(function (b) { return b.idx !== a.p_idx; });
      save(); return ok(null);
    },
    admin_delete_league: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      DB.leagues = DB.leagues.filter(function (l) { return l.id !== a.p_league; });
      DB.members = DB.members.filter(function (m) { return m.league_id !== a.p_league; });
      DB.workouts = DB.workouts.filter(function (w) { return w.league_id !== a.p_league; });
      save(); return ok(null);
    },
    admin_delete_profile: function (a) {
      var p = me(); if (!p || !p.is_admin) return bad('Not allowed');
      if (a.p_profile === p.id) return bad('You cannot delete your own account from here');
      DB.profiles = DB.profiles.filter(function (q) { return q.id !== a.p_profile; });
      DB.members = DB.members.filter(function (m) { return m.profile_id !== a.p_profile; });
      DB.workouts = DB.workouts.filter(function (w) { return w.profile_id !== a.p_profile; });
      save(); return ok(null);
    },
    set_pinned_badges: function (a) { var p = me(); if (!p) return bad('NO_PROFILE');
      p.pinned_badges = (a.p_keys || []).slice(0, 3); save(); return ok(p); },
    my_badges: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var p = me(); if (!p) return ok([]);
      var mine = DB.workouts.filter(function (w) {
        return w.league_id === a.p_league && w.profile_id === p.id; });
      var pts = mine.reduce(function (t, w) { return t + w.points; }, 0);
      var cats = {}; mine.forEach(function (w) { cats[CATS[w.exercise_key]] = 1; });
      function row(k, n, d, prog, tgt) {
        return { key: k, name: n, descr: d, earned: prog >= tgt,
                 progress: Math.min(prog, tgt), target: tgt };
      }
      return ok([
        row('century','CENTURION','A hundred logged sets here', mine.length, 100),
        row('grand','FIVE THOUSAND','Five thousand points here', pts, 5000),
        row('allrounder','ALL ROUNDER','Train all five muscle groups',
            Object.keys(cats).filter(function (c) { return c && c !== 'RECOVERY'; }).length, 5),
        row('week_win','CHAMPION','Win a week in this league', 0, 1)
      ].sort(function (x, y) { return (y.earned - x.earned)
        || (y.progress / y.target - x.progress / x.target); }));
    },
    league_rivalries: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var p = me();
      var rows = DB.members.filter(function (m) { return m.league_id === a.p_league; })
        .map(function (m) {
          var q = DB.profiles.filter(function (x) { return x.id === m.profile_id; })[0];
          var pts = DB.workouts.filter(function (w) {
            return w.league_id === a.p_league && w.profile_id === q.id; })
            .reduce(function (t, w) { return t + w.points; }, 0);
          return { id: q.id, n: q.display_name, av: q.avatar || null, pts: pts };
        }).sort(function (x, y) { return y.pts - x.pts; });
      var out = [];
      for (var i = 0; i + 1 < rows.length; i += 2) {
        var A = rows[i], B = rows[i + 1];
        out.push({ a_id: A.id, a_name: A.n, a_avatar: A.av, a_points: A.pts,
                   b_id: B.id, b_name: B.n, b_avatar: B.av, b_points: B.pts,
                   seed: out.length + 1,
                   mine: !!p && (A.id === p.id || B.id === p.id) });
      }
      return ok(out);
    },
    league_streaks: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var min = a.p_min == null ? 20 : a.p_min;
      var today = new Date().toISOString().slice(0, 10);
      return ok(DB.members.filter(function (m) { return m.league_id === a.p_league; })
        .map(function (m) {
          var p = DB.profiles.filter(function (x) { return x.id === m.profile_id; })[0];
          var byDay = {};
          DB.workouts.filter(function (w) {
            return w.league_id === a.p_league && w.profile_id === p.id;
          }).forEach(function (w) {
            var d = w.created_at.slice(0, 10);
            byDay[d] = (byDay[d] || 0) + w.points;
          });
          var days = Object.keys(byDay).filter(function (d) { return byDay[d] >= min; }).sort();
          var best = 0, run = 0, prev = null, cur = 0;
          days.forEach(function (d) {
            var gap = prev ? (Date.parse(d) - Date.parse(prev)) / 86400000 : 999;
            run = gap === 1 ? run + 1 : 1;
            best = Math.max(best, run);
            prev = d;
          });
          if (prev) {
            var since = (Date.parse(today) - Date.parse(prev)) / 86400000;
            cur = since <= 1 ? run : 0;
          }
          return { profile_id: p.id, display_name: p.display_name, avatar: p.avatar || null,
                   banner: p.banner || null, current_streak: cur, best_streak: best,
                   active_days: days.length };
        }).sort(function (x, y) { return y.current_streak - x.current_streak || y.best_streak - x.best_streak; }));
    },
    set_banner: function (a) { var p = me(); if (!p) return bad('NO_PROFILE');
      p.banner = a.p_banner || null; save(); return ok(p); },
    /* Mirrors the SQL: strips nulls, and only the owner may write. */
    set_league_badge: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      var l = DB.leagues.filter(function (x) { return x.id === a.p_league; })[0];
      if (!l) return bad('NOT_A_MEMBER');
      if (l.owner_id !== p.id) {
        return bad('Only the person who created a league can change its crest');
      }
      var b = a.p_badge || {}, out = {};
      ['shape', 'color', 'emblem', 'skin', 'text'].forEach(function (k) {
        if (b[k] !== null && b[k] !== undefined && b[k] !== '') out[k] = b[k];
      });
      l.badge = Object.keys(out).length ? out : null;
      save(); return ok(l);
    },
    set_league_settings: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      var l = DB.leagues.filter(function (x) { return x.id === a.p_league; })[0];
      if (!l) return bad('NOT_A_MEMBER');
      if (l.owner_id !== p.id) {
        return bad('Only the person who created a league can change its settings');
      }
      if (a.p_rest_dow) l.rest_dow = a.p_rest_dow;
      l.season_weeks = a.p_season_weeks || null;
      save(); return ok(l);
    },
    my_stats: function (a) {
      var p = me(); if (!p) return ok([]);
      var cur = weekStart(), agg = {};
      DB.workouts.filter(function (w) {
        return w.league_id === a.p_league && w.profile_id === p.id &&
               (a.p_all || w.week_start === cur);
      }).forEach(function (w) {
        var k = w.exercise_key + '|' + w.mode;
        if (!agg[k]) agg[k] = { exercise_key: w.exercise_key, category: CATS[w.exercise_key],
          mode: w.mode, total_amount: 0, total_points: 0, entries: 0, active_days: 1 };
        agg[k].total_amount += Number(w.amount);
        agg[k].total_points = Math.round((agg[k].total_points + w.points) * 100) / 100;
        agg[k].entries++;
      });
      var out = Object.keys(agg).map(function (k) { return agg[k]; });
      out.sort(function (x, y) { return y.total_points - x.total_points; });
      return ok(out);
    },
    create_challenge: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      if (!isMember(a.p_league)) return bad('NOT_A_MEMBER');
      if (openCh(p.id)) return bad('ALREADY_IN_CHALLENGE');
      var c = { id: id(), code: 'D' + Math.random().toString(36).slice(2, 7).toUpperCase(),
        league_id: a.p_league, challenger_id: p.id, opponent_id: null,
        created_at: new Date().toISOString(), accepted_at: null, ends_at: null, cancelled_at: null };
      DB.challenges.push(c); return ok(c);
    },
    challenge_preview: function (a) {
      var c = DB.challenges.filter(function (x) { return x.code === a.p_code.toUpperCase(); })[0];
      if (!c) return ok([]);
      var ch = DB.profiles.filter(function (x) { return x.id === c.challenger_id; })[0];
      var l = DB.leagues.filter(function (x) { return x.id === c.league_id; })[0];
      return ok([{ code: c.code, league_name: l.name, challenger_name: ch.display_name,
        challenger_avatar: ch.avatar || null, status: chStatus(c) }]);
    },
    accept_challenge: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      var c = DB.challenges.filter(function (x) { return x.code === a.p_code.toUpperCase(); })[0];
      if (!c) return bad('NO_SUCH_CHALLENGE');
      if (c.challenger_id === p.id) return bad('OWN_CHALLENGE');
      if (chStatus(c) !== 'PENDING') return bad('CHALLENGE_UNAVAILABLE');
      if (!isMember(c.league_id)) return bad('NOT_A_MEMBER');
      if (openCh(p.id)) return bad('ALREADY_IN_CHALLENGE');
      c.opponent_id = p.id; c.accepted_at = new Date().toISOString();
      c.ends_at = new Date(Date.now() + 864e5).toISOString();
      return ok(c);
    },
    cancel_challenge: function (a) {
      var p = me();
      DB.challenges.forEach(function (c) {
        if (c.id === a.p_id && c.challenger_id === p.id && !c.accepted_at) c.cancelled_at = new Date().toISOString();
      });
      return ok(null);
    },
    my_challenges: function () {
      var p = me(); if (!p) return ok([]);
      var out = DB.challenges.filter(function (c) {
        return c.challenger_id === p.id || c.opponent_id === p.id;
      }).map(function (c) {
        var foeId = c.challenger_id === p.id ? c.opponent_id : c.challenger_id;
        var foe = DB.profiles.filter(function (x) { return x.id === foeId; })[0];
        var l = DB.leagues.filter(function (x) { return x.id === c.league_id; })[0];
        return { id: c.id, code: c.code, status: chStatus(c), league_name: l.name,
          me_name: p.display_name, me_avatar: p.avatar || null,
          me_points: chPoints(c.league_id, p.id, c.accepted_at, c.ends_at),
          foe_name: foe ? foe.display_name : null, foe_avatar: foe ? (foe.avatar || null) : null,
          foe_points: chPoints(c.league_id, foeId, c.accepted_at, c.ends_at),
          created_at: c.created_at, ends_at: c.ends_at, i_started: c.challenger_id === p.id };
      });
      var rank = { LIVE: 0, PENDING: 1 };
      out.sort(function (x, y) { return (rank[x.status] === undefined ? 2 : rank[x.status]) -
        (rank[y.status] === undefined ? 2 : rank[y.status]); });
      return ok(out);
    },
    log_workout: function (a) {
      var p = me(); if (!p) return bad('NO_PROFILE');
      if (!isMember(a.p_league)) return bad('NOT_A_MEMBER');
      var g = id(), mine = DB.members.filter(function (m) { return m.profile_id === p.id; });
      var wall = new Date(Date.now() + tzOffsetMs(new Date()));
      var amount = Number(a.p_amount), made = [];
      for (var i = 0; i < mine.length; i++) {
        var lg = mine[i].league_id;
        if (wall.getUTCDay() === 0) {
          if (a.p_key !== 'stretch') return bad('REST_DAY');
          var todayIso = wall.toISOString().slice(0, 10);
          if (DB.workouts.some(function (w) {
                return w.profile_id === p.id && w.league_id === lg &&
                  new Date(new Date(w.created_at).getTime() + tzOffsetMs(new Date(w.created_at)))
                    .toISOString().slice(0, 10) === todayIso; })) return bad('REST_DAY_DONE');
          amount = 1;
        }
        var pts = calc(a.p_key, a.p_mode, amount);
        if (pts <= 0) return bad('Unknown exercise or unit');
        var row = { id: id(), group_id: g, league_id: lg, profile_id: p.id,
          exercise_key: a.p_key, mode: a.p_mode, amount: amount, points: pts,
          week_start: weekStart(), created_at: new Date().toISOString() };
        DB.workouts.push(row); made.push(row);
      }
      var here = made.filter(function (w) { return w.league_id === a.p_league; })[0] || made[0];
      return ok([{ id: here.id, group_id: g, exercise_key: here.exercise_key, mode: here.mode,
        amount: here.amount, points: here.points, leagues: made.length }]);
    },
    current_bounty: function (a) {
      var b = window.__BOUNTY__;
      if (!b) return ok([]);
      return ok([b]);
    },
    my_duel_record: function (a) {
      var p = me(); if (!p) return ok([{played:0,won:0,lost:0,drawn:0,best_streak:0}]);
      var fin = DB.challenges.filter(function (c) {
        return c.league_id === a.p_league && chStatus(c) === 'FINISHED' &&
          (c.challenger_id === p.id || c.opponent_id === p.id); });
      var w=0,l=0,d=0,run=0,best=0;
      fin.sort(function(x,y){ return new Date(x.ends_at)-new Date(y.ends_at); });
      fin.forEach(function (c) {
        var foe = c.challenger_id === p.id ? c.opponent_id : c.challenger_id;
        var mine = chPoints(c.league_id, p.id, c.accepted_at, c.ends_at);
        var theirs = chPoints(c.league_id, foe, c.accepted_at, c.ends_at);
        if (mine > theirs) { w++; run++; best = Math.max(best, run); }
        else if (mine < theirs) { l++; run = 0; }
        else { d++; run = 0; }
      });
      return ok([{ played: fin.length, won: w, lost: l, drawn: d, best_streak: best }]);
    },
    weekly_history: function (a) {
      if (!isMember(a.p_league)) return ok([]);
      var cur = weekStart(), agg = {};
      DB.workouts.filter(function (w) { return w.league_id === a.p_league && w.week_start < cur; })
        .forEach(function (w) {
          var k = w.week_start + '|' + w.profile_id;
          if (!agg[k]) agg[k] = { week_start: w.week_start, profile_id: w.profile_id, points: 0, entries: 0,
            display_name: (DB.profiles.filter(function (p) { return p.id === w.profile_id; })[0] || {}).display_name };
          agg[k].points = Math.round((agg[k].points + w.points) * 100) / 100; agg[k].entries++;
        });
      var out = Object.keys(agg).map(function (k) { return agg[k]; });
      out.sort(function (x, y) { return x.week_start < y.week_start ? 1 : x.week_start > y.week_start ? -1 : y.points - x.points; });
      return ok(out);
    }
  };

  function Builder(table) {
    this.t = table; this.f = []; this._single = false;
  }
  Builder.prototype.select = function () { return this; };
  Builder.prototype.eq = function (c, v) { this.f.push([c, v]); return this; };
  /* order() used to ignore which column it was given and sort by created_at
     descending whatever you asked for, which quietly scrambled any table
     without one. It honours the column now, and the direction. */
  Builder.prototype.order = function (col, opts) {
    // PostgREST sorts ascending unless told otherwise; the app asks for
    // descending explicitly where it wants it.
    this._order = { col: col || 'created_at',
                    asc: !(opts && opts.ascending === false) };
    return this;
  };
  Builder.prototype.maybeSingle = function () { this._single = 'maybe'; return this; };
  Builder.prototype.single = function () { this._single = true; return this; };
  Builder.prototype.insert = function (o) { this._insert = o; return this; };
  Builder.prototype.delete = function () { this._delete = true; return this; };
  Builder.prototype.update = function (o) { this._update = o; return this; };
  Builder.prototype.rows = function () {
    var self = this;
    return (DB[this.t] || []).filter(function (r) {
      return self.f.every(function (p) { return String(r[p[0]]) === String(p[1]); });
    });
  };
  Builder.prototype.then = function (res, rej) {
    var self = this, out;
    if (this._insert) {
      var o = this._insert;
      var p = me();
      if (!p || o.profile_id !== p.id) { return ok(null).then(function(){ return { data:null, error:new Error('row-level security') }; }).then(res, rej); }
      var wall = new Date(Date.now() + tzOffsetMs(new Date()));
      var amount = Number(o.amount);
      if (wall.getUTCDay() === 0) {                    // Sunday = rest day
        if (o.exercise_key !== 'stretch') {
          return Promise.resolve({ data: null, error: new Error('REST_DAY') }).then(res, rej);
        }
        var todayIso = wall.toISOString().slice(0, 10);
        var already = DB.workouts.some(function (w) {
          return w.profile_id === o.profile_id && w.league_id === o.league_id &&
            new Date(new Date(w.created_at).getTime() + tzOffsetMs(new Date(w.created_at)))
              .toISOString().slice(0, 10) === todayIso;
        });
        if (already) {
          return Promise.resolve({ data: null, error: new Error('REST_DAY_DONE') }).then(res, rej);
        }
        amount = 1;
      }
      o = Object.assign({}, o, { amount: amount });
      var pts = calc(o.exercise_key, o.mode, amount);
      if (pts <= 0) return bad('Unknown exercise or unit').then(res, rej);
      var row = { id: id(), league_id: o.league_id, profile_id: o.profile_id, exercise_key: o.exercise_key,
        mode: o.mode, amount: Number(o.amount), points: pts, week_start: weekStart(),
        created_at: new Date().toISOString() };
      DB.workouts.push(row); out = row;
    } else if (this._update) {
      var rows = this.rows(), o2 = this._update, changed = [];
      rows.forEach(function (r) {
        if (r.week_start !== weekStart()) return;       // closed week: no rows affected
        for (var k in o2) r[k] = o2[k];
        r.points = calc(r.exercise_key, r.mode, Number(r.amount));
        r.amount = Number(r.amount);
        changed.push(r);
      });
      out = changed;
    } else if (this._delete) {
      var keep = [], gone = [];
      (DB[this.t] || []).forEach(function (r) {
        var match = self.f.every(function (p) { return String(r[p[0]]) === String(p[1]); });
        if (match && self.t === 'workouts' && r.week_start !== weekStart()) match = false;
        (match ? gone : keep).push(r);
      });
      DB[this.t] = keep; out = gone;
    } else {
      out = this.rows().slice();
      if (this._order) {
        var col = this._order.col, dir = this._order.asc ? 1 : -1;
        out.sort(function (a, b) {
          if (a[col] === b[col]) return 0;
          return (a[col] > b[col] ? 1 : -1) * dir;
        });
      }
      if (this._single) out = out[0] || null;
    }
    save();
    return Promise.resolve({ data: out, error: null }).then(res, rej);
  };

  window.supabase = {
    createClient: function () {
      return {
        auth: {
          getSession: function () { return Promise.resolve({ data: { session: signedIn ? { user: { id: uid } } : null } }); },
          signInAnonymously: function () { signedIn = true; return Promise.resolve({ data: { user: { id: uid } }, error: null }); },
          getUser: function () { return Promise.resolve({ data: { user: { id: uid } } }); }
        },
        rpc: function (name, args) {
          if (!RPC[name]) return bad('unknown rpc ' + name);
          var out = RPC[name](args || {}); save(); return out;
        },
        from: function (t) { return new Builder(t); }
      };
    }
  };
})();
