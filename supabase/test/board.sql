-- The leaderboard's lifetime column, scoped to a league.
--
-- life_scored_in() exists only to be cheaper than life_scored_all(). The one
-- thing it must never be is DIFFERENT, so every assertion here is a version
-- of "the same number comes out". The trap it is built around: a lifetime
-- counts what somebody logged in EVERY league, so narrowing the people must
-- never narrow the leagues.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('b1111111-1111-1111-1111-111111111111'),
  ('b2222222-2222-2222-2222-222222222222'),
  ('b3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('bbbb0000-0000-0000-0000-000000000001','b1111111-1111-1111-1111-111111111111','DOUBLE','BRD1'),
  ('bbbb0000-0000-0000-0000-000000000002','b2222222-2222-2222-2222-222222222222','SINGLE','BRD2'),
  ('bbbb0000-0000-0000-0000-000000000003','b3333333-3333-3333-3333-333333333333','ELSEWHERE','BRD3');
insert into public.leagues (id, name, code, owner_id) values
  ('bbbb1111-0000-0000-0000-00000000000a','ALPHA','BRDAAA','bbbb0000-0000-0000-0000-000000000001'),
  ('bbbb1111-0000-0000-0000-00000000000b','BETA', 'BRDBBB','bbbb0000-0000-0000-0000-000000000001');
-- DOUBLE is in both leagues, SINGLE only in alpha, ELSEWHERE only in beta.
insert into public.league_members (league_id, profile_id, joined_at) values
  ('bbbb1111-0000-0000-0000-00000000000a','bbbb0000-0000-0000-0000-000000000001','2026-01-05'),
  ('bbbb1111-0000-0000-0000-00000000000b','bbbb0000-0000-0000-0000-000000000001','2026-01-05'),
  ('bbbb1111-0000-0000-0000-00000000000a','bbbb0000-0000-0000-0000-000000000002','2026-01-05'),
  ('bbbb1111-0000-0000-0000-00000000000b','bbbb0000-0000-0000-0000-000000000003','2026-01-05');

\echo '--- 1. a log fans out to every league, and counts once'
set request.jwt.claim.sub = 'b1111111-1111-1111-1111-111111111111';
select '  logged ' || (public.log_workout('bbbb1111-0000-0000-0000-00000000000a',
                                        'pushups', 'reps', 100)).points || ' points';
select '  rows written: ' || count(*) || ' (one per league)'
from public.workouts where profile_id = 'bbbb0000-0000-0000-0000-000000000001';
select case when (select count(distinct group_id) from public.workouts
                  where profile_id = 'bbbb0000-0000-0000-0000-000000000001') = 1
       then 'both rows share one group, which is what stops a double count'
       else 'THE FAN-OUT DID NOT GROUP' end;

\echo '--- 2. the two functions agree, for a person in two leagues'
select '  all   : ' || points from public.life_scored_all()
 where profile_id = 'bbbb0000-0000-0000-0000-000000000001';
select '  alpha : ' || points
from public.life_scored_in('bbbb1111-0000-0000-0000-00000000000a')
 where profile_id = 'bbbb0000-0000-0000-0000-000000000001';
select '  beta  : ' || points
from public.life_scored_in('bbbb1111-0000-0000-0000-00000000000b')
 where profile_id = 'bbbb0000-0000-0000-0000-000000000001';
select case when (select points from public.life_scored_all()
                   where profile_id = 'bbbb0000-0000-0000-0000-000000000001')
          = (select points from public.life_scored_in('bbbb1111-0000-0000-0000-00000000000a')
                   where profile_id = 'bbbb0000-0000-0000-0000-000000000001')
       then 'a lifetime read through one league is the whole lifetime'
       else 'SCOPING THE PEOPLE SCOPED THE POINTS' end;

\echo '--- 3. the trap: work done in ANOTHER league still counts'
set request.jwt.claim.sub = 'b1111111-1111-1111-1111-111111111111';
select '  logged in beta: ' || (public.log_workout(
  'bbbb1111-0000-0000-0000-00000000000b', 'pullups', 'reps', 50)).points || ' points';
select case when (select points from public.life_scored_in('bbbb1111-0000-0000-0000-00000000000a')
                   where profile_id = 'bbbb0000-0000-0000-0000-000000000001')
          = (select points from public.life_scored_all()
                   where profile_id = 'bbbb0000-0000-0000-0000-000000000001')
       then 'alpha still shows a lifetime that includes beta — people narrowed, leagues not'
       else 'A LEAGUE IS HIDING WORK DONE IN ANOTHER ONE' end;

\echo '--- 4. every member of every league, both ways, no exceptions'
select case when (
  select count(*) from public.leagues l
  cross join lateral public.life_scored_in(l.id) s
  join public.life_scored_all() a on a.profile_id = s.profile_id
  where s.points is distinct from a.points) = 0
  then 'identical for every (league, member) pair there is'
  else 'A PAIR DISAGREES' end;

\echo '--- 5. somebody outside the league is not in its answer'
select case when not exists (
  select 1 from public.life_scored_in('bbbb1111-0000-0000-0000-00000000000a')
   where profile_id = 'bbbb0000-0000-0000-0000-000000000003')
  then 'alpha does not carry a beta-only member, so the board stays small'
  else 'THE SCOPE IS NOT SCOPING' end;

\echo '--- 6. and the board itself shows the same lifetime it always did'
select '  ' || display_name || ' lifetime ' || lifetime
from public.league_leaderboard('bbbb1111-0000-0000-0000-00000000000a', public.current_week_start())
order by display_name;
select case when (
  select b.lifetime from public.league_leaderboard(
      'bbbb1111-0000-0000-0000-00000000000a', public.current_week_start()) b
   where b.profile_id = 'bbbb0000-0000-0000-0000-000000000001')
  = (select points from public.life_scored_all()
      where profile_id = 'bbbb0000-0000-0000-0000-000000000001')
  then 'the number on the board is the whole lifetime, unchanged'
  else 'THE BOARD LOST POINTS' end;

\echo '--- 7. somebody who never logged is zero on the board, not missing'
select case when (
  select count(*) from public.league_leaderboard(
      'bbbb1111-0000-0000-0000-00000000000a', public.current_week_start())) = 2
  then 'both members are on the board, the one with no logs included'
  else 'A MEMBER FELL OFF THE BOARD' end;
