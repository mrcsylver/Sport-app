-- ======================================================================
--  IRON LEAGUE — shutting the door beside the functions
--
--  Paste the whole file into the Supabase SQL editor and press RUN, or apply
--  it over the API. Safe to run twice. NOTHING LOGGED IS TOUCHED, no points
--  move, and no profile changes hands. It only TAKES AWAY permissions.
--
--  Hand-written, unlike every other migration here: there is no function to
--  lift out of schema.sql, only grants and one policy. The same lines are in
--  schema.sql so a rebuild starts correct.
--
--  WHY
--  Every RPC in this schema is SECURITY DEFINER and checks what it is asked
--  to do. None of that matters if the TABLE underneath is reachable, and on
--  Supabase it is by default: `authenticated` arrives holding SELECT, INSERT,
--  UPDATE and DELETE on every column of every table in `public`, and
--  row-level security is the only thing in the way.
--
--  RLS filters ROWS. It does not filter COLUMNS, and it does not care which
--  column an UPDATE touches. Five things were therefore possible against the
--  live database, by anybody signed in, with one request each:
--
--   1. READ ANY LEAGUE-MATE'S RESTORE CODE. profiles_read allowed
--      `shares_league_with(id)`, and a profile row carries restore_code. A
--      restore code IS the account. Among forty friends that is one kind of
--      problem; with ninety-nine strangers in a campus league it is another.
--      The same row carries bodyweight, which is health data under GDPR and
--      is in there only to score gym lifts.
--
--   2. MAKE YOURSELF AN ADMIN. profiles_update allowed `user_id = auth.uid()`
--      -- "you may edit yourself" -- with UPDATE on every column, is_admin
--      included. One PATCH and the control room was yours: the cap, the
--      player list, every league, the shop.
--
--   3. TAKE ANY PAID COSMETIC. check_wear() guards set_banner, set_avatar,
--      set_frame and set_name_color. A direct UPDATE walked past all four.
--
--   4. STEP OVER THE GLOBAL CAP. create_profile() checks app_is_full().
--      A raw INSERT into profiles did not -- and could set is_admin on the
--      way in.
--
--   5. FLY A PAID CREST FOR FREE, as a league owner, round
--      set_league_badge()'s catalogue check, via leagues_update.
--
--  WHAT CHANGES
--  Reads of `profiles` are narrowed to your own row, and the write grants on
--  `profiles` and `leagues` are taken away from `anon` and `authenticated`.
--  Nothing else moves.
--
--  NOTHING IN EITHER APP BREAKS. Both clients read `profiles` only with
--  `.eq('user_id', <me>)` and neither has ever written to `profiles` or
--  `leagues` directly -- every change already goes through create_profile,
--  rename_profile, set_avatar, set_banner, set_name_color, set_frame,
--  set_bodyweight, set_body_form, set_units, set_pinned_badges,
--  restore_profile, wake_me, set_league_settings and set_league_badge.
--  Everything one person may know about another already comes out of
--  league_leaderboard(), which chooses what it returns.
--
--  `workouts` is deliberately left alone. Its BEFORE INSERT trigger forces
--  created_at and week_start and recomputes points, and its BEFORE UPDATE
--  guard pins id, profile, league, created_at, week_start and boost and
--  rescores the row -- so a direct write there can neither forge a score nor
--  reach a finished week, and the app edits and deletes entries that way.
--
--  TO UNDO, if something unexpected turns out to depend on it:
--    grant select, insert, update, delete on public.profiles to authenticated;
--    grant select, insert, update, delete on public.leagues  to authenticated;
--    alter policy profiles_read on public.profiles
--      using (user_id = auth.uid() or public.shares_league_with(id));
-- ======================================================================
begin;

-- --------------------------------------------------- profiles: reads ---
-- ALTER rather than DROP and CREATE: the migration channel this project
-- applies through will not run a DROP, and there is no reason to have an
-- instant where the policy does not exist.
alter policy profiles_read on public.profiles
  using (user_id = auth.uid());

-- -------------------------------------------------- profiles: writes ---
revoke insert, update, delete on public.profiles from anon, authenticated;
-- anon cannot pass the policy anyway, having no auth.uid(); there is still
-- no reason for the grant to exist.
revoke select on public.profiles from anon;

-- --------------------------------------------------- leagues: writes ---
revoke insert, update, delete on public.leagues from anon, authenticated;

-- ------------------------------------- and three nobody can use anyway ---
-- TRUNCATE is the one that matters: ROW-level security does not apply to it,
-- so a role holding it can empty a table whatever its policies say.
-- PostgREST never issues one, so this is not a reachable hole today -- it is
-- a privilege that exists for no reason, on the table holding every profile
-- in the app, and removing it costs nothing.
do $g$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('revoke truncate, trigger, references on public.%I '
                   'from anon, authenticated', t);
  end loop;
end $g$;

-- `anon` is the role before anybody has signed in, and nothing in either app
-- writes anything before that -- the first thing both do is sign in, even if
-- anonymously. Every write grant it holds is therefore unused, and every one
-- of them is a row-level policy away from being the only thing in the way.
do $g$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('revoke insert, update, delete on public.%I from anon', t);
  end loop;
end $g$;

-- ------------------------------------------- and the policies they used ---
-- The revokes above are what shut the door; these only stop the schema
-- claiming a permission that no longer exists. Guarded, because the channel
-- that cannot run a DROP will skip this block rather than fail the file.
do $p$
begin
  execute 'drop policy if exists profiles_insert on public.profiles';
  execute 'drop policy if exists profiles_update on public.profiles';
  execute 'drop policy if exists leagues_update  on public.leagues';
exception when insufficient_privilege or feature_not_supported then
  raise notice 'policies left in place; the revokes above are what matter';
end $p$;

commit;
