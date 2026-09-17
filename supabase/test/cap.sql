-- The repetition discount. One person found that 898 step-ups was seven per
-- cent of a whole league's week, because points are linear in reps while the
-- effort of the tenth easy rep is not. These hold the curve, the per-exercise
-- caps, and the promise that no total is ever actually capped.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('c1111111-1111-1111-1111-111111111111'),
  ('c2222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('cccc0000-0000-0000-0000-000000000001','c1111111-1111-1111-1111-111111111111','FARMER','CP1',true),
  ('cccc0000-0000-0000-0000-000000000002','c2222222-2222-2222-2222-222222222222','SPREAD','CP2',false);
-- rest day is tomorrow, so the fixture can log on any weekday it runs
insert into public.leagues (id, name, code, owner_id, rest_dow)
values ('dddd0000-0000-0000-0000-000000000001','IRON','CAP001',
        'cccc0000-0000-0000-0000-000000000001',
        array[(extract(isodow from (now() at time zone public.app_timezone()))::int % 7) + 1]);
insert into public.league_members (league_id, profile_id) values
  ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000001'),
  ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000002');

\echo '--- 1. the curve: full, then half, then a quarter, and never zero'
select '  ' || lpad(v::text, 4) || ' raw -> ' || lpad(public.tier_points(v)::text, 7)
from (values (0),(100),(200),(300),(400),(600),(1000),(5000)) t(v);
select case when public.tier_points(200) = 200
             and public.tier_points(300) = 250
             and public.tier_points(400) = 300
             and public.tier_points(600) = 350
       then 'the first 200 pay in full, the next 200 half, the rest a quarter'
       else 'THE CURVE IS WRONG' end;
select case when public.tier_points(5000) > public.tier_points(4000)
       then 'and it never flattens: more work is always more points'
       else 'THE CURVE REACHED A CEILING' end;

\echo '--- 2. a cap is the exercise''s own, because a bike ride is not repetition'
select '  ' || key || ' pays in full up to ' || cap || ' points'
from public.exercises where key in ('pushups','run','walk','bike') order by cap, key;
select case when public.tier_points(500, public.exercise_cap('run')) = 500
             and public.tier_points(1000, public.exercise_cap('run')) = 750
       then '100 km of running is full price; 200 km is not free but is not full'
       else 'THE PER-EXERCISE CAP DID NOT APPLY' end;

set request.jwt.claim.sub = 'c1111111-1111-1111-1111-111111111111';

\echo '--- 3. the order entries arrive in cannot change the week'
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',100);
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',100);
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',100);
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',100);
select '  400 push-ups in four sets: ' || points
from public.week_scored('dddd0000-0000-0000-0000-000000000001', public.current_week_start())
where profile_id = 'cccc0000-0000-0000-0000-000000000001';
set request.jwt.claim.sub = 'c2222222-2222-2222-2222-222222222222';
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',400);
select '  400 push-ups in one set  : ' || points
from public.week_scored('dddd0000-0000-0000-0000-000000000001', public.current_week_start())
where profile_id = 'cccc0000-0000-0000-0000-000000000002';
select case when (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001')
          =  (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000002')
       then 'four sets and one set score the same — no way to split around it'
       else 'SPLITTING THE SETS BEAT THE DISCOUNT' end;

\echo '--- 4. deleting an early entry cannot mis-score the ones after it'
set request.jwt.claim.sub = 'c1111111-1111-1111-1111-111111111111';
delete from public.workouts
 where profile_id = 'cccc0000-0000-0000-0000-000000000001'
   and id = (select id from public.workouts
             where profile_id = 'cccc0000-0000-0000-0000-000000000001'
             order by created_at limit 1);
select case when (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001') = 250
       then '300 push-ups left scores 250, exactly as if the fourth never was'
       else 'A DELETED ROW LEFT THE REST MIS-SCORED' end;

\echo '--- 5. spreading the same effort beats farming one movement'
-- FARMER has 300 push-ups (250 scored). SPREAD matches it with variety.
set request.jwt.claim.sub = 'c2222222-2222-2222-2222-222222222222';
delete from public.workouts where profile_id = 'cccc0000-0000-0000-0000-000000000002';
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','pushups','reps',100);
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','declinepush','reps',80);
select 'logged' from public.log_workout('dddd0000-0000-0000-0000-000000000001','airsquats','reps',200);
select '  FARMER 300 push-ups   : ' || points from public.week_scored(
  'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
  where profile_id = 'cccc0000-0000-0000-0000-000000000001';
select '  SPREAD 300 raw, varied: ' || points from public.week_scored(
  'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
  where profile_id = 'cccc0000-0000-0000-0000-000000000002';
select case when (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000002')
            > (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001')
       then 'the same raw points spread over three movements score more'
       else 'VARIETY DID NOT PAY' end;

\echo '--- 6. every screen reads the same number'
set request.jwt.claim.sub = 'c1111111-1111-1111-1111-111111111111';
select case when (select base_points from public.league_leaderboard(
                    'dddd0000-0000-0000-0000-000000000001')
                  where display_name = 'FARMER')
          =  (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001')
       then 'the live board is the scored week, not the raw rows'
       else 'THE BOARD DID NOT DISCOUNT' end;
select case when (select week_points from public.admin_players() where display_name = 'FARMER')
          >= (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001')
       then 'and so is the control room'
       else 'THE CONTROL ROOM DID NOT DISCOUNT' end;
select case when (select sum(total_points) from public.my_stats(
                    'dddd0000-0000-0000-0000-000000000001'))
          =  (select points from public.week_scored(
                    'dddd0000-0000-0000-0000-000000000001', public.current_week_start())
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001')
       then 'and the stats tab adds up to the very same week'
       else 'THE STATS TAB DISAGREES WITH THE BOARD' end;
select '  stats tab shows ' || raw_points || ' raw -> ' || total_points
       || ' scored, out of a ' || cap || ' budget'
  from public.my_stats('dddd0000-0000-0000-0000-000000000001')
 where exercise_key = 'pushups';

\echo '--- 7. lifetime is the sum of its weeks, not one giant curve'
-- a second finished week of the same work: two weeks of 250 is 500, not the
-- 350 that running 600 raw points through one curve would give.
alter table public.workouts disable trigger user;
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount,
                             points, week_start, created_at)
values ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000001',
        'pushups','reps',300,300,public.current_week_start() - 7, now() - interval '8 days');
alter table public.workouts enable trigger user;
select '  two weeks of 300 push-ups: ' || points
  from public.life_scored_all() where profile_id = 'cccc0000-0000-0000-0000-000000000001';
select case when (select points from public.life_scored_all()
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001') = 500
       then 'each week is discounted on its own; a year is not one session'
       else 'LIFETIME RAN EVERY WEEK THROUGH ONE CURVE' end;
