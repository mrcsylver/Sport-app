-- What a signed-in stranger can reach.
--
-- Every RPC in this schema is SECURITY DEFINER and checks what it is asked
-- to do. None of that matters if the TABLE underneath is reachable, and by
-- default on Supabase it is: `authenticated` arrives holding SELECT, INSERT,
-- UPDATE and DELETE on every column of every table, and row-level security
-- is the only thing in the way. RLS filters ROWS. It does not filter
-- COLUMNS, and it does not care which column an UPDATE touches.
--
-- So these checks are not about the functions. They are about the door
-- beside the functions, and each one is a thing that was actually possible
-- in this database until the policy and the grants were narrowed.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('e1111111-1111-1111-1111-111111111111'),
  ('e2222222-2222-2222-2222-222222222222'),
  ('e3333333-3333-3333-3333-333333333333')   -- signed in, no profile yet
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('eeee0000-0000-0000-0000-000000000001','e1111111-1111-1111-1111-111111111111','VICTIM','SECRET01'),
  ('eeee0000-0000-0000-0000-000000000002','e2222222-2222-2222-2222-222222222222','ATTACKER','PLAIN002');

-- Both in the same league, which is the whole point: this is not a stranger
-- on the internet, it is somebody on your leaderboard.
set request.jwt.claim.sub = 'e1111111-1111-1111-1111-111111111111';
insert into public.leagues (id, name, code, owner_id)
  values ('eeeeaaaa-0000-0000-0000-00000000000a','THE GYM','GYM001',
          'eeee0000-0000-0000-0000-000000000001');
insert into public.league_members (league_id, profile_id) values
  ('eeeeaaaa-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-000000000001'),
  ('eeeeaaaa-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-000000000002');

-- From here on, everything runs as the ATTACKER through the `authenticated`
-- role, exactly as a browser holding the public anon key does.
set role authenticated;
set request.jwt.claim.sub = 'e2222222-2222-2222-2222-222222222222';

\echo '--- 1. a league-mate cannot read your restore code'
-- The one that matters most: a restore code IS the account.
select case when (select count(*) from public.profiles
                   where id = 'eeee0000-0000-0000-0000-000000000001') = 0
       then 'somebody else''s profile row is not readable at all'
       else 'THE VICTIM''S ROW IS READABLE' end;

\echo '--- 2. you can still read your own'
select case when (select restore_code from public.profiles
                   where id = 'eeee0000-0000-0000-0000-000000000002') = 'PLAIN002'
       then 'and your own row still is, restore code included'
       else 'A PERSON CANNOT READ THEIR OWN PROFILE' end;

\echo '--- 3. nobody can make themselves an admin'
-- One PATCH against /rest/v1/profiles and the control room was yours.
do $t$ begin
  update public.profiles set is_admin = true
   where id = 'eeee0000-0000-0000-0000-000000000002';
  raise notice 'A USER PROMOTED THEMSELVES TO ADMIN';
exception when insufficient_privilege then raise notice 'self-promotion refused';
end $t$;
select case when (select count(*) from public.profiles where is_admin) = 0
       then 'and there is still no admin in this database'
       else 'SOMEBODY IS AN ADMIN WHO SHOULD NOT BE' end;

\echo '--- 4. nor hand themselves a paid cosmetic'
-- check_wear() guards the setter functions. A direct UPDATE walked past it.
do $t$ begin
  update public.profiles set banner = 'bloodline', frame = 'anything-at-all'
   where id = 'eeee0000-0000-0000-0000-000000000002';
  raise notice 'THE SHOP WAS BYPASSED';
exception when insufficient_privilege then raise notice 'free cosmetics refused';
end $t$;

\echo '--- 5. nor insert a profile that skips the cap'
-- create_profile() checks app_is_full(). A raw INSERT did not. Run as a
-- third account that has no profile yet, or this is refused as a duplicate
-- and passes for the wrong reason.
set request.jwt.claim.sub = 'e3333333-3333-3333-3333-333333333333';
do $t$ begin
  insert into public.profiles (user_id, display_name, is_admin)
    values ('e3333333-3333-3333-3333-333333333333', 'SNEAK', true);
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.profiles where display_name = 'SNEAK') = 0
       then 'no profile appeared round the side of create_profile()'
       else 'A PROFILE WAS INSERTED ROUND THE FRONT DOOR' end;
set request.jwt.claim.sub = 'e2222222-2222-2222-2222-222222222222';

\echo '--- 6. nor rewrite a league they do not own'
-- Checked by VALUE, not by exception: RLS does not raise when it blocks a
-- write, it quietly matches zero rows. A test that waits for an error passes
-- whether the door is shut or merely not used.
do $t$ begin
  update public.leagues set max_members = 2
   where id = 'eeeeaaaa-0000-0000-0000-00000000000a';
exception when others then raise notice 'refused outright: %', sqlerrm;
end $t$;
select case when (select max_members from public.leagues
                   where id = 'eeeeaaaa-0000-0000-0000-00000000000a') = 36
       then 'a member cannot resize somebody else''s league'
       else 'A LEAGUE WAS REWRITTEN BY A MEMBER' end;

\echo '--- 7. and the OWNER cannot either, round set_league_badge'
set request.jwt.claim.sub = 'e1111111-1111-1111-1111-111111111111';
do $t$ begin
  update public.leagues set badge = '{"skin":"luxury"}'::jsonb
   where id = 'eeeeaaaa-0000-0000-0000-00000000000a';
exception when others then raise notice 'refused outright: %', sqlerrm;
end $t$;
select case when (select badge from public.leagues
                   where id = 'eeeeaaaa-0000-0000-0000-00000000000a') is null
       then 'and the owner cannot fly a paid crest round the shop either'
       else 'THE OWNER FLEW A PAID CREST FOR FREE' end;

\echo '--- 8. the app still works: everything legitimate goes through an RPC'
select case when (select display_name from public.rename_profile('RENAMED')) = 'RENAMED'
       then 'renaming yourself still works' else 'THE APP IS BROKEN' end;
select case when (select count(*) from public.league_leaderboard(
                    'eeeeaaaa-0000-0000-0000-00000000000a')) = 2
       then 'and the board still shows everybody in the league'
       else 'THE BOARD CANNOT SEE THE LEAGUE' end;

\echo '--- 9. the board is where other people''s details come from'
-- It chooses what it returns, which is the entire difference.
select case when (select count(*) from information_schema.columns
                   where table_name = 'profiles'
                     and column_name in ('restore_code','bodyweight')) = 2
            and not exists (
              select 1 from pg_proc p
               join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'league_leaderboard'
                 and pg_get_function_result(p.oid) ilike '%restore_code%')
       then 'and league_leaderboard() has never returned a restore code'
       else 'THE BOARD IS LEAKING' end;

reset role;
