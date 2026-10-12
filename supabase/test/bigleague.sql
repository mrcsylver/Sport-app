-- A league that holds more than 36.
--
-- 36 was a hard ceiling, and 36 is the number the five divisions come to.
-- That is the right size for a group of friends and the wrong one for a
-- poster on a gym wall. These checks are about the three ways raising a
-- ceiling usually goes wrong: letting it go somewhere silly, letting it go
-- DOWN past the people already inside, and quietly resizing leagues that
-- never asked.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('d1111111-1111-1111-1111-111111111111'),
  ('d2222222-2222-2222-2222-222222222222'),
  ('d3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('dddd0000-0000-0000-0000-000000000001','d1111111-1111-1111-1111-111111111111','OWNER','BIG00001'),
  ('dddd0000-0000-0000-0000-000000000002','d2222222-2222-2222-2222-222222222222','OTHER','BIG00002'),
  ('dddd0000-0000-0000-0000-000000000003','d3333333-3333-3333-3333-333333333333','THIRD','BIG00003');

set request.jwt.claim.sub = 'd1111111-1111-1111-1111-111111111111';

\echo '--- 1. a league created with no opinion is still 36'
select case when (select max_members from public.create_league('PLAIN')) = 36
       then 'the default did not move' else 'THE DEFAULT MOVED' end;

\echo '--- 2. a campus league can be created at 100'
select case when (select max_members from public.create_league('CAMPUS', 100)) = 100
       then 'a hundred places, straight from the creator'
       else 'A HUNDRED WAS REFUSED' end;

\echo '--- 3. and the silly numbers are refused on the way in'
do $t$
declare bad int := 0;
begin
  begin perform public.create_league('TOO BIG', 101);
  exception when others then bad := bad + 1; end;
  begin perform public.create_league('TOO SMALL', 1);
  exception when others then bad := bad + 1; end;
  raise notice '101 and 1 both refused: %', bad = 2;
end $t$;

\echo '--- 4. the ceiling is the constraint, not just the function'
-- Belt and braces: the function is the door, the CHECK is the wall. A direct
-- UPDATE that went round the function must still not get past 100.
do $t$ begin
  update public.leagues set max_members = 250 where name = 'PLAIN';
  raise notice 'THE WALL IS NOT THERE';
exception when check_violation then raise notice 'the wall holds: 250 refused';
end $t$;

\echo '--- 5. the size can be raised afterwards'
select case when (select max_members from public.set_league_settings(
         (select id from public.leagues where name = 'PLAIN'),
         '{7}'::int[], null, null, null, 80)) = 80
       then '36 raised to 80 by the owner' else 'THE RAISE DID NOT TAKE' end;

\echo '--- 6. and never below the people already in it'
-- Three in, and 2 is a perfectly legal size -- so this is the shrink rule
-- doing the refusing, not the 2..100 range.
insert into public.league_members (league_id, profile_id)
  select id, 'dddd0000-0000-0000-0000-000000000002'
  from public.leagues where name = 'PLAIN';
insert into public.league_members (league_id, profile_id)
  select id, 'dddd0000-0000-0000-0000-000000000003'
  from public.leagues where name = 'PLAIN';
do $t$ begin
  perform public.set_league_settings(
    (select id from public.leagues where name = 'PLAIN'),
    '{7}'::int[], null, null, null, 2);
  raise notice 'A LEAGUE WAS SHRUNK UNDER ITS OWN MEMBERS';
exception when others then raise notice '3 in, shrink to 2: %', sqlerrm;
end $t$;
select case when (select max_members from public.leagues where name = 'PLAIN') = 80
       then 'and the size it already had is untouched'
       else 'THE FAILED SHRINK CHANGED SOMETHING' end;

\echo '--- 7. leaving the size out changes nothing about it'
-- Every other setting still saves on its own, which is what the app does on
-- every tap of a rest day.
select case when (select max_members from public.set_league_settings(
         (select id from public.leagues where name = 'PLAIN'),
         '{6,7}'::int[], 12, null, 3)) = 80
       then 'rest days and a season saved, size left alone'
       else 'A NULL SIZE OVERWROTE THE SIZE' end;

\echo '--- 8. the capacity trigger counts against the new number'
-- 100 places means the 37th person gets in, which is the entire point.
insert into public.league_members (league_id, profile_id)
  select (select id from public.leagues where name = 'CAMPUS'),
         'dddd0000-0000-0000-0000-000000000002';
select case when (select count(*) from public.league_members m
                   join public.leagues l on l.id = m.league_id
                  where l.name = 'CAMPUS') = 2
       then 'joining a 100-seat league works like any other'
       else 'THE TRIGGER IS STILL COUNTING TO 36' end;

\echo '--- 9. only the owner can resize'
set request.jwt.claim.sub = 'd2222222-2222-2222-2222-222222222222';
do $t$ begin
  perform public.set_league_settings(
    (select id from public.leagues where name = 'PLAIN'),
    '{7}'::int[], null, null, null, 100);
  raise notice 'A MEMBER RESIZED SOMEBODY ELSE''S LEAGUE';
exception when others then raise notice 'a member cannot: %', sqlerrm;
end $t$;
