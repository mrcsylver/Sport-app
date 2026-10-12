-- What a request with NO session at all can call.
--
-- `anon` is not the anonymous sign-in. An anonymous sign-in hands back a
-- real JWT and the `authenticated` role; `anon` is a bare request to the
-- REST endpoint carrying the publishable key and nothing else. In this app
-- that is nobody — it signs in before it asks anything — which is exactly
-- why the grants on it were never looked at, and why eight of them were
-- still whatever Postgres hands to PUBLIC on a new function.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

\echo '--- 1. the eleven that were open are shut'
select case when count(*) = 0 then 'anon cannot call any of the eleven'
            else 'STILL OPEN TO ANON: ' || string_agg(proname, ', ') end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and has_function_privilege('anon', p.oid, 'execute')
  and (p.proname like 'admin\_%'
    or p.proname in ('set_league_settings','my_badges','league_season',
                     'league_season_info','league_season_state',
                     'life_scored_all','week_scored'));

\echo '--- 2. no admin function at all is reachable without a session'
-- The one that mattered returns a restore code for every player, so this is
-- the check that is really worth having: it covers the next admin function
-- somebody adds, not just the one that was missed.
select case when count(*) = 0 then 'no admin_* function is open to anon'
            else 'ADMIN FUNCTION OPEN TO ANON: ' || string_agg(proname, ', ') end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'admin\_%'
  and has_function_privilege('anon', p.oid, 'execute');

\echo '--- 3. and the reason it mattered: that function carries restore codes'
select case when pg_get_function_result(p.oid) ilike '%restore_code%'
       then 'admin_players() does return restore_code, as the control room needs'
       else 'ADMIN_PLAYERS NO LONGER RETURNS WHAT THIS TEST IS ABOUT' end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'admin_players';

\echo '--- 4. the six the app calls still work for somebody signed in'
select case when count(*) = 6 then 'the six the app calls are granted to authenticated'
            else 'MISSING A GRANT: only ' || count(*) || ' of 6' end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and has_function_privilege('authenticated', p.oid, 'execute')
  and p.proname in ('admin_players','set_league_settings','my_badges',
                    'league_season','league_season_info','league_season_state');

\echo '--- 5. the two internal helpers are shut to everybody outside'
-- They are called from inside other SECURITY DEFINER functions, which run as
-- the owner and never consult the caller's grants.
select case when count(*) = 0 then 'the two helpers are callable by nobody outside'
            else 'A HELPER IS STILL EXPOSED: ' || string_agg(proname, ', ') end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('life_scored_all','week_scored')
  and (has_function_privilege('anon', p.oid, 'execute')
    or has_function_privilege('authenticated', p.oid, 'execute'));

\echo '--- 6. what is deliberately left open, is'
-- The app has to be able to ask "is there room" before it has anybody to
-- ask on behalf of. Breaking this breaks the full-house screen.
select case when count(*) = 1 then 'signup_state() is still reachable without a session'
            else 'THE FULL-HOUSE SCREEN CANNOT ASK ANY MORE' end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'signup_state'
  and has_function_privilege('anon', p.oid, 'execute');

\echo '--- 7. the board still does not hand out restore codes to anybody'
select case when not exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public'
            and p.proname in ('league_leaderboard','player_card','life_scored_all')
            and pg_get_function_result(p.oid) ilike '%restore_code%')
       then 'nothing a player can call returns a restore code'
       else 'A PLAYER-FACING FUNCTION IS LEAKING RESTORE CODES' end;
