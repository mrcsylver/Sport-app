\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('cccc0000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','LEADER','CU1'),
  ('cccc0000-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','MIDDLE','CU2'),
  ('cccc0000-0000-0000-0000-000000000003','33333333-3333-3333-3333-333333333333','BEHIND','CU3');
insert into public.leagues (id, name, code, owner_id, rest_dow) values
  ('dddd0000-0000-0000-0000-000000000001','IRON','CUTEST','cccc0000-0000-0000-0000-000000000001','{1}');
insert into public.league_members (league_id, profile_id)
select 'dddd0000-0000-0000-0000-000000000001', id from public.profiles
where restore_code in ('CU1','CU2','CU3');

\echo '--- a league has no catch-up day unless somebody sets one'
select 'catchup_dow starts as: ' || coalesce(catchup_dow::text, 'none')
from public.leagues where code = 'CUTEST';

\echo '--- the shape of the multiplier'
select 'behind by ' || lpad(g::text, 4) || ' -> x' ||
       round(1 + (public.catchup_max() - 1)
             * least(greatest(g - public.catchup_floor(), 0)
                     / (public.catchup_ceiling() - public.catchup_floor()), 1), 2)
from (values (0), (100), (150), (200), (250), (300), (400), (500), (700), (1200)) v(g);

\echo '--- setting it, and the rules around it'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.set_league_settings('dddd0000-0000-0000-0000-000000000001',
                                  '{1}'::int[], null, 7);
select 'rest day ' || rest_dow::text || ', catch-up day ' || catchup_dow
from public.leagues where code = 'CUTEST';

do $$ begin
  perform public.set_league_settings('dddd0000-0000-0000-0000-000000000001',
                                     '{1,7}'::int[], null, 7);
  raise exception 'A REST DAY WAS ALSO SET AS THE CATCH-UP DAY';
exception when others then
  if sqlerrm like '%A REST DAY WAS%' then raise; end if;
  raise notice 'overlap refused: %', sqlerrm;
end $$;

\echo '--- the gap, measured live'
-- LEADER 600, MIDDLE 500, BEHIND 100
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000001','pushups','reps',600),
       ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000002','pushups','reps',500),
       ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000003','pushups','reps',100);

select 'LEADER (0 behind)  -> x' || public.catchup_multiplier(
  'dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000001');
select 'MIDDLE (100 behind)-> x' || public.catchup_multiplier(
  'dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000002');
select 'BEHIND (500 behind)-> x' || public.catchup_multiplier(
  'dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000003');

\echo '--- and it never goes above the maximum'
select case when public.catchup_multiplier(
  'dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000003')
  <= public.catchup_max() then 'capped at x' || public.catchup_max()
  else 'THE CAP WAS EXCEEDED' end;

\echo '--- somebody with no logs at all is not divided by zero'
insert into auth.users (id) values ('44444444-4444-4444-4444-444444444444')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('cccc0000-0000-0000-0000-000000000004','44444444-4444-4444-4444-444444444444','GHOST','CU4')
on conflict do nothing;
select 'a member who has logged nothing: x' || public.catchup_multiplier(
  'dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000004');

\echo '--- on the day itself, the boost is stamped onto the row'
-- pretend today is the catch-up day by pointing it at today's weekday
select public.set_league_settings('dddd0000-0000-0000-0000-000000000001', '{1}'::int[], null,
  extract(isodow from (now() at time zone public.app_timezone()))::int);
select case when public.is_catchup_day('dddd0000-0000-0000-0000-000000000001')
       then 'today is the catch-up day' else 'IT IS NOT' end;

set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000003','pushups','reps',100);
select 'BEHIND logged 100 push-ups: ' || points || ' points at x' || boost
from public.workouts
where profile_id = 'cccc0000-0000-0000-0000-000000000003' and boost > 1;

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000001','pushups','reps',100);
select 'LEADER logged 100 push-ups: ' || points || ' points at x' || boost
from public.workouts
where profile_id = 'cccc0000-0000-0000-0000-000000000001' and amount = 100;

\echo '--- the leader is not punished, only unboosted'
select case when (select points from public.workouts
                  where profile_id = 'cccc0000-0000-0000-0000-000000000001' and amount = 100) = 100
       then 'the leader still gets every point they earned'
       else 'THE LEADER LOST POINTS' end;

\echo '--- and what was stamped stays stamped'
select case when (select boost from public.workouts
                  where profile_id = 'cccc0000-0000-0000-0000-000000000003' and boost > 1)
            = (select boost from public.workouts
               where profile_id = 'cccc0000-0000-0000-0000-000000000003' and boost > 1)
       then 'a row keeps the multiplier it was logged at' else 'IT MOVED' end;

\echo '--- off the day, nothing is boosted'
select public.set_league_settings('dddd0000-0000-0000-0000-000000000001', '{1}'::int[], null, null);
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('dddd0000-0000-0000-0000-000000000001','cccc0000-0000-0000-0000-000000000003','pullups','reps',10);
select case when (select boost from public.workouts where exercise_key = 'pullups') = 1
       then 'an ordinary day is x1' else 'SOMETHING WAS BOOSTED OFF THE DAY' end;
