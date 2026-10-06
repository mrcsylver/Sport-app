-- A rest day belongs to a LEAGUE, and a person can be in several.
--
-- log_workout() writes one row per league. The rest day rule used to raise
-- from the trigger, and a raise from any one of those rows takes the whole
-- statement down — so somebody in two leagues could not log anything at all
-- while ONE of them was resting, including into the league that was open.
-- One league closing its own Sunday must close that league, not the person's
-- day.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('81111111-1111-1111-1111-111111111111'),
  ('82222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('8aaa0000-0000-0000-0000-000000000001','81111111-1111-1111-1111-111111111111','TWOLEAGUES','RD1'),
  ('8aaa0000-0000-0000-0000-000000000002','82222222-2222-2222-2222-222222222222','ONELEAGUE','RD2');

-- RESTING rests today, whatever today is. OPEN never rests. SECONDREST also
-- rests today, for the case where every league somebody is in is shut.
insert into public.leagues (id, name, code, owner_id, rest_dow) values
  ('8bbb0000-0000-0000-0000-00000000000a','RESTING','RDA001',
   '8aaa0000-0000-0000-0000-000000000001',
   array[extract(isodow from (now() at time zone public.app_timezone()))::int]),
  ('8bbb0000-0000-0000-0000-00000000000b','OPEN','RDB002',
   '8aaa0000-0000-0000-0000-000000000001', '{}'),
  ('8bbb0000-0000-0000-0000-00000000000c','SECONDREST','RDC003',
   '8aaa0000-0000-0000-0000-000000000002',
   array[extract(isodow from (now() at time zone public.app_timezone()))::int]);
insert into public.league_members (league_id, profile_id) values
  ('8bbb0000-0000-0000-0000-00000000000a','8aaa0000-0000-0000-0000-000000000001'),
  ('8bbb0000-0000-0000-0000-00000000000b','8aaa0000-0000-0000-0000-000000000001'),
  ('8bbb0000-0000-0000-0000-00000000000c','8aaa0000-0000-0000-0000-000000000002');

set request.jwt.claim.sub = '81111111-1111-1111-1111-111111111111';

\echo '--- 1. the question each league is asked'
select '  RESTING, push-ups : ' || coalesce(public.rest_day_block(
  '8aaa0000-0000-0000-0000-000000000001','8bbb0000-0000-0000-0000-00000000000a',
  'pushups', now(), null), 'takes it');
select '  OPEN,    push-ups : ' || coalesce(public.rest_day_block(
  '8aaa0000-0000-0000-0000-000000000001','8bbb0000-0000-0000-0000-00000000000b',
  'pushups', now(), null), 'takes it');
select '  RESTING, stretch  : ' || coalesce(public.rest_day_block(
  '8aaa0000-0000-0000-0000-000000000001','8bbb0000-0000-0000-0000-00000000000a',
  'stretch', now(), null), 'takes it');

\echo '--- 2. one league resting no longer costs the other one'
-- The entry is made FROM the resting league, which is the worst case: the
-- screen somebody is looking at is the one refusing.
select '  logged into ' || leagues || ' league(s), worth ' || points
from public.log_workout('8bbb0000-0000-0000-0000-00000000000a',
                        'pushups', 'reps', 50);
select case when (select count(*) from public.workouts
                   where profile_id = '8aaa0000-0000-0000-0000-000000000001'
                     and league_id = '8bbb0000-0000-0000-0000-00000000000b') = 1
       then 'the open league scored it'
       else 'THE OPEN LEAGUE MISSED IT' end;
select case when (select count(*) from public.workouts
                   where profile_id = '8aaa0000-0000-0000-0000-000000000001'
                     and league_id = '8bbb0000-0000-0000-0000-00000000000a') = 0
       then 'and the resting one sat it out, as it should'
       else 'THE RESTING LEAGUE TOOK IT ANYWAY' end;

\echo '--- 3. it still answers with a points figure, even from the shut screen'
-- The app needs a number to show. Asking from the resting league used to
-- return no row at all, which reads as "nothing happened".
select case when (select count(*) from public.log_workout(
                    '8bbb0000-0000-0000-0000-00000000000a',
                    'pushups', 'reps', 10)) = 1
       then 'one row back, so the toast has something to say'
       else 'NOTHING CAME BACK FROM THE RESTING LEAGUE' end;

\echo '--- 4. a stretch goes into both, and counts once in the resting one'
select '  logged into ' || leagues || ' league(s)'
from public.log_workout('8bbb0000-0000-0000-0000-00000000000b',
                        'stretch', 'flat', 2);
select '  RESTING amount: ' || amount || ' · OPEN amount: ' ||
  (select w2.amount from public.workouts w2
    where w2.league_id = '8bbb0000-0000-0000-0000-00000000000b'
      and w2.exercise_key = 'stretch')
from public.workouts w
where w.league_id = '8bbb0000-0000-0000-0000-00000000000a'
  and w.exercise_key = 'stretch';
select case when (select amount from public.workouts
                   where league_id = '8bbb0000-0000-0000-0000-00000000000a'
                     and exercise_key = 'stretch') = 1
             and (select amount from public.workouts
                   where league_id = '8bbb0000-0000-0000-0000-00000000000b'
                     and exercise_key = 'stretch') = 2
       then 'the resting league counts one session; the open one takes both'
       else 'THE REST DAY STOPPED CAPPING THE SESSION' end;

\echo '--- 5. a second stretch: the resting league is done, the open one is not'
select '  logged into ' || leagues || ' league(s)'
from public.log_workout('8bbb0000-0000-0000-0000-00000000000b',
                        'stretch', 'flat', 1);
select case when (select count(*) from public.workouts
                   where league_id = '8bbb0000-0000-0000-0000-00000000000a'
                     and exercise_key = 'stretch') = 1
             and (select count(*) from public.workouts
                   where league_id = '8bbb0000-0000-0000-0000-00000000000b'
                     and exercise_key = 'stretch') = 2
       then 'one recovery in the resting league, both in the open one'
       else 'THE ONE-A-DAY RECOVERY RULE BROKE' end;

\echo '--- 6. when EVERY league is shut, it still stops you, with the old words'
set request.jwt.claim.sub = '82222222-2222-2222-2222-222222222222';
do $t$ begin
  perform public.log_workout('8bbb0000-0000-0000-0000-00000000000c',
                             'pushups', 'reps', 50);
  raise notice 'A REST DAY STOPPED NOBODY';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.workouts
                   where profile_id = '8aaa0000-0000-0000-0000-000000000002') = 0
       then 'nothing was written'
       else 'SOMETHING SLIPPED THROUGH' end;
-- a stretch is allowed once, and the second one says so
select case when (select count(*) from public.log_workout(
                    '8bbb0000-0000-0000-0000-00000000000c',
                    'stretch', 'flat', 1)) = 1
       then 'but the one stretch still goes in'
       else 'THE REST DAY STRETCH WAS REFUSED' end;
do $t$ begin
  perform public.log_workout('8bbb0000-0000-0000-0000-00000000000c',
                             'stretch', 'flat', 1);
  raise notice 'A SECOND RECOVERY WAS ALLOWED';
exception when others then raise notice 'second recovery refused: %', sqlerrm;
end $t$;

\echo '--- 7. and a direct write is still refused, however it arrives'
-- log_workout() filters, but the trigger is what makes the rule true: an
-- edit, or anything not coming through the RPC, still has to obey it.
do $t$ begin
  insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
  values ('8bbb0000-0000-0000-0000-00000000000c',
          '8aaa0000-0000-0000-0000-000000000002', 'pushups', 'reps', 20);
  raise notice 'A DIRECT INSERT WALKED PAST THE REST DAY';
exception when others then raise notice 'direct insert refused: %', sqlerrm;
end $t$;
