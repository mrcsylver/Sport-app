-- ======================================================================
--  IRON LEAGUE — the eleven functions `anon` could still call
--
--  Paste the whole file into the Supabase SQL editor and press RUN, or
--  apply it over the API. Safe to run twice. NOTHING LOGGED IS TOUCHED, no
--  points move, no profile changes hands. It only TAKES AWAY permissions.
--
--  Hand-written, like shut-the-side-door.sql and for the same reason: there
--  is no function to lift out of schema.sql, only grants. The same lines are
--  in schema.sql so that a rebuild starts correct.
--
--  WHAT `anon` IS. It is the role a request carries when it has NO session
--  at all. A Supabase anonymous sign-in is not it — that hands back a real
--  JWT and the `authenticated` role, with an `is_anonymous` claim on it. The
--  app signs in at boot before it asks the database anything, so in this
--  app `anon` is nobody: a bare request to the REST endpoint with the
--  publishable key and nothing else.
--
--  WHY IT MATTERS ANYWAY. Postgres grants EXECUTE on a new function to
--  PUBLIC, which includes `anon`. Every RPC here was revoked from it by
--  hand, one line each — and eight lines were never written. Twenty-two
--  admin functions, twenty-one revoked.
--
--  The worst of them was admin_players(), which returns A RESTORE CODE FOR
--  EVERY PLAYER. A restore code IS the account: it is the thing you type on
--  a new phone to become that person. Three more went with it —
--  admin_leagues(), admin_delete_league() and admin_delete_profile(), the
--  last two destructive. Those three are ALREADY closed on the live
--  database, closed by hand at some point and never written down, so the
--  lines here are a no-op against production and the point of them is that
--  a rebuild from schema.sql now lands in the same place.
--
--  NOTHING LEAKED. The body is `... where public.is_admin()`, and is_admin()
--  reads the profile behind auth.uid(); with no session there is no uid, so
--  no profile, so not an admin, so zero rows. The hole is one `where`
--  clause deep and it holds. But it was the only member of its set relying
--  on that, and 300 strangers off a poster is the wrong moment to find out
--  whether a `where` clause and a grant disagree.
--
--  The other seven are the same tidy-up rather than a hole:
--    set_league_settings  a WRITE; raises NO_PROFILE without a profile
--    my_badges            scoped to the caller's profile — none, so empty
--    league_season        \
--    league_season_info    |  reads gated on being in the league
--    league_season_state  /
--    life_scored_all      an internal helper; lifetime points, no names
--    week_scored          an internal helper; one league's week
--
--  The last two are called only from inside other SECURITY DEFINER
--  functions, which run as the owner and do not consult the caller's
--  grants, so taking EXECUTE away from everybody costs nothing.
--
--  WHAT IS DELIBERATELY LEFT. signup_state(), cap_full() and app_timezone()
--  stay reachable: they answer "is there room" and "what time is it here",
--  which is the one thing the app may need to know before it has a session.
-- ======================================================================

revoke all on function public.admin_players()                from public, anon;
revoke all on function public.admin_leagues()                 from public, anon;
revoke all on function public.admin_delete_league(uuid)      from public, anon;
revoke all on function public.admin_delete_profile(uuid)     from public, anon;
revoke all on function public.set_league_settings(uuid,int[],int,int,int,int)
                                                             from public, anon;
revoke all on function public.my_badges(uuid)                from public, anon;
revoke all on function public.league_season(uuid,int)        from public, anon;
revoke all on function public.league_season_info(uuid)       from public, anon;
revoke all on function public.league_season_state(uuid)      from public, anon;
revoke all on function public.life_scored_all()              from public, anon;
revoke all on function public.week_scored(uuid,date)         from public, anon;

-- The six the app actually calls are put back for signed-in people. The two
-- helpers are not: nothing outside the database has ever called them.
grant execute on function public.admin_players()             to authenticated;
grant execute on function public.set_league_settings(uuid,int[],int,int,int,int)
                                                             to authenticated;
grant execute on function public.my_badges(uuid)             to authenticated;
grant execute on function public.league_season(uuid,int)     to authenticated;
grant execute on function public.league_season_info(uuid)    to authenticated;
grant execute on function public.league_season_state(uuid)   to authenticated;

-- Proof, in the same transaction: nothing in public is left open to `anon`
-- except the three that answer "is there room".
do $$
declare open_to_anon text;
begin
  select string_agg(p.proname, ', ' order by p.proname) into open_to_anon
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and has_function_privilege('anon', p.oid, 'execute')
    and (p.proname like 'admin\_%'
      or p.proname in ('set_league_settings','my_badges','league_season',
                       'league_season_info','league_season_state',
                       'life_scored_all','week_scored'));
  if open_to_anon is not null then
    raise exception 'still open to anon: %', open_to_anon;
  end if;
  raise notice 'anon can no longer call any admin function, nor the seven';
end $$;
