-- The control room against a league board, on the same person, at the same
-- moment. A real player showed 720 in one and 706 in the other; neither was
-- wrong, they were answering different questions. This holds them apart.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('a1111111-1111-1111-1111-111111111111'),
  ('a2222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('aaaa0000-0000-0000-0000-000000000001','a1111111-1111-1111-1111-111111111111','BOSS','AD1',true),
  ('aaaa0000-0000-0000-0000-000000000002','a2222222-2222-2222-2222-222222222222','QUENTIN','AD2',false);

-- two leagues, both of which QUENTIN is in, which is what makes a naive
-- lifetime total double-count: one log writes one row per league
insert into public.leagues (id, name, code, owner_id, rest_dow) values
  ('bbbb0000-0000-0000-0000-000000000001','IRON','ADM001','aaaa0000-0000-0000-0000-000000000001','{1}'),
  ('bbbb0000-0000-0000-0000-000000000002','STEEL','ADM002','aaaa0000-0000-0000-0000-000000000001','{1}');
insert into public.league_members (league_id, profile_id) values
  ('bbbb0000-0000-0000-0000-000000000001','aaaa0000-0000-0000-0000-000000000001'),
  ('bbbb0000-0000-0000-0000-000000000001','aaaa0000-0000-0000-0000-000000000002'),
  ('bbbb0000-0000-0000-0000-000000000002','aaaa0000-0000-0000-0000-000000000002');

set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';

\echo '--- last week, in one league only'
-- the stamp trigger always writes the current week, and the update guard
-- refuses to move a row out of it, so a finished week has to be built with
-- both of them off. Only the fixture does this; nothing in the app can.
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('bbbb0000-0000-0000-0000-000000000001','aaaa0000-0000-0000-0000-000000000002',
        'pushups','reps',200);
alter table public.workouts disable trigger user;
update public.workouts set week_start = public.current_week_start() - 7,
                           created_at = now() - interval '8 days'
 where profile_id = 'aaaa0000-0000-0000-0000-000000000002';
alter table public.workouts enable trigger user;

\echo '--- and this week, fanned out to both leagues under one group'
select 'logged' from public.log_workout('bbbb0000-0000-0000-0000-000000000001','pushups','reps',300);
select 'logged' from public.log_workout('bbbb0000-0000-0000-0000-000000000001','airsquats','reps',300);
select 'logged' from public.log_workout('bbbb0000-0000-0000-0000-000000000001','crunches','reps',200);
select 'rows written: ' || count(*) || ' across ' || count(distinct league_id)
       || ' leagues, from ' || count(distinct group_id) || ' logs'
from public.workouts where profile_id = 'aaaa0000-0000-0000-0000-000000000002'
  and week_start = public.current_week_start();

set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';

\echo '--- what each screen says'
select 'dashboard lifetime   : ' || lifetime
  from public.admin_players() where display_name = 'QUENTIN';
select 'dashboard this week  : ' || week_points
  from public.admin_players() where display_name = 'QUENTIN';
select 'league board this week: ' || points || ' (' || base_points || ' + ' || bonus || ' bonus)'
  from public.league_leaderboard('bbbb0000-0000-0000-0000-000000000001')
 where display_name = 'QUENTIN';

\echo '--- and how they line up'
select case when (select week_points from public.admin_players()
                  where display_name = 'QUENTIN')
          =  (select points from public.league_leaderboard('bbbb0000-0000-0000-0000-000000000001')
              where display_name = 'QUENTIN')
       then 'this week matches the board exactly, bonuses included'
       else 'THE DASHBOARD AND THE BOARD DISAGREE' end;

select case when (select lifetime from public.admin_players()
                  where display_name = 'QUENTIN')
          =  (select lifetime from public.league_leaderboard('bbbb0000-0000-0000-0000-000000000001')
              where display_name = 'QUENTIN')
       then 'lifetime matches the rank banner the app shows'
       else 'THE TWO LIFETIME NUMBERS DISAGREE' end;

select 'last week, plus this week, counted once: ' || lifetime
  from public.admin_players() where display_name = 'QUENTIN';
select case when (select lifetime from public.admin_players()
                  where display_name = 'QUENTIN')
            < (select sum(points) from public.workouts
               where profile_id = 'aaaa0000-0000-0000-0000-000000000002')
       then 'lifetime counts a log once, not once per league'
       else 'LIFETIME DOUBLE-COUNTED THE FAN-OUT' end;
select case when (select lifetime from public.admin_players()
                  where display_name = 'QUENTIN')
            > (select week_points from public.admin_players()
               where display_name = 'QUENTIN')
       then 'and it carries the weeks that are already over'
       else 'LIFETIME FORGOT A FINISHED WEEK' end;

select case when (select week_points from public.admin_players()
                  where display_name = 'QUENTIN')
            > (select coalesce(sum(points), 0) from public.workouts
               where profile_id = 'aaaa0000-0000-0000-0000-000000000002'
                 and league_id = 'bbbb0000-0000-0000-0000-000000000001'
                 and week_start = public.current_week_start())
       then 'this week carries the bonuses the raw rows do not'
       else 'THE BONUSES ARE MISSING FROM THIS WEEK' end;

\echo '--- somebody who has never logged is zero, not null'
select 'BOSS: lifetime ' || lifetime || ', this week ' || week_points
  from public.admin_players() where display_name = 'BOSS';

\echo '--- and it is still shut to everybody else'
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
select case when (select count(*) from public.admin_players()) = 0
       then 'a player sees nothing' else 'A PLAYER READ THE WHOLE DASHBOARD' end;
