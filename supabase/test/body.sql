-- The muscle figure and the wins tracker, against a real week of training.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('b1111111-1111-1111-1111-111111111111'),
  ('b2222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('eeee0000-0000-0000-0000-000000000001','b1111111-1111-1111-1111-111111111111','ARM DAY','BD1'),
  ('eeee0000-0000-0000-0000-000000000002','b2222222-2222-2222-2222-222222222222','ROUNDED','BD2');
insert into public.leagues (id, name, code, owner_id, rest_dow) values
  ('ffff0000-0000-0000-0000-000000000001','IRON','BODY01','eeee0000-0000-0000-0000-000000000001','{1}');
insert into public.league_members (league_id, profile_id) values
  ('ffff0000-0000-0000-0000-000000000001','eeee0000-0000-0000-0000-000000000001'),
  ('ffff0000-0000-0000-0000-000000000001','eeee0000-0000-0000-0000-000000000002');

\echo '--- 1. a percentage of a full week, and what it reads at'
select 'at ' || lpad(x::text, 4) || ' of a 100 target -> ' ||
       lpad(public.muscle_charge(x, 100)::text, 5) || '%'
from (values (0), (25), (50), (100), (200), (300), (500), (1000), (100000)) v(x);
select case when public.muscle_charge(100, 100) = 100
       then 'a full dose reads exactly 100' else 'A FULL DOSE IS NOT 100' end;
select case when public.muscle_charge(0, 100) = 0
       then 'and nothing logged is 0' else 'EMPTY IS NOT ZERO' end;
select case when public.muscle_charge(1e9, 100) = 999
       then 'and it stops counting at 999 rather than printing a novel'
       else 'THE CAP IS WRONG' end;

\echo '--- 2. one exercise spreads its points over the regions it trains'
set request.jwt.claim.sub = 'b1111111-1111-1111-1111-111111111111';
select 'logged' from public.log_workout(
  'ffff0000-0000-0000-0000-000000000001','gymcurl','reps',100, 80, 40);
select m.key || ': ' || m.points || ' pts'
from public.my_muscles('ffff0000-0000-0000-0000-000000000001') m
where m.points > 0 order by m.points desc;
select case when (select round(sum(points), 1) from
                  public.my_muscles('ffff0000-0000-0000-0000-000000000001'))
          =  (select round(sum(points), 1) from public.workouts
              where profile_id = 'eeee0000-0000-0000-0000-000000000001')
       then 'every point landed on a muscle, once'
       else 'THE SPREAD LOST OR INVENTED POINTS' end;

\echo '--- 3. an arms-only week is visibly an arms-only week'
select 'strongest: ' || key || ' ' || pct || '% of a week'
from public.my_muscles('ffff0000-0000-0000-0000-000000000001')
order by pct desc limit 1;
select 'weakest (this is the balance score): ' || min(pct) || '%'
from public.my_muscles('ffff0000-0000-0000-0000-000000000001');

\echo '--- 4. spreading the same work raises the weakest link'
set request.jwt.claim.sub = 'b2222222-2222-2222-2222-222222222222';
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','pushups','reps',80);
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','pullups','reps',30);
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','airsquats','reps',120);
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','crunches','reps',100);
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','run','km',6);
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','plank','minutes',5);
select 'ROUNDED, lowest three: ' || string_agg(key || ' ' || pct || '%', ', ')
from (select key, pct from public.my_muscles('ffff0000-0000-0000-0000-000000000001')
      order by pct limit 3) z;
select 'ROUNDED, highest three: ' || string_agg(key || ' ' || pct || '%', ', ')
from (select key, pct from public.my_muscles('ffff0000-0000-0000-0000-000000000001')
      order by pct desc limit 3) z;
select case when (select count(*) from
                  public.my_muscles('ffff0000-0000-0000-0000-000000000001')
                  where pct > 0) >= 13
       then 'six honest exercises light up thirteen of the fourteen regions'
       else 'THE SPREAD IS TOO NARROW TO BE USEFUL' end;

\echo '--- 5. recovery is worth points and trains nothing'
select 'logged' from public.log_workout('ffff0000-0000-0000-0000-000000000001','stretch','flat',1);
select case when (select sum(points) from public.workouts
                  where profile_id = 'eeee0000-0000-0000-0000-000000000002'
                    and exercise_key = 'stretch') > 0
        and  (select count(*) from public.exercises e
              cross join lateral jsonb_each_text(e.muscles) m(key, value)
              where e.key = 'stretch') = 0
       then 'stretching scores but moves no region'
       else 'RECOVERY LEAKED INTO THE FIGURE' end;

\echo '--- 6. every region is reachable and every exercise lands somewhere'
select 'exercises training nothing: ' || count(*) from public.exercises
 where muscles = '{}'::jsonb and cat <> 'RECOVERY';
select 'exercises whose shares do not add to 1: ' || count(*) from (
  select e.key from public.exercises e
  cross join lateral jsonb_each_text(e.muscles) s(key, value)
  where e.muscles <> '{}'::jsonb
  group by e.key having abs(sum((s.value)::numeric) - 1) > 0.0001) bad;
select 'regions nothing trains: ' || count(*) from public.muscles m
 where not exists (select 1 from public.exercises e where e.muscles ? m.key);
select 'exercises naming a region that does not exist: ' || count(*) from (
  select e.key from public.exercises e
  cross join lateral jsonb_object_keys(e.muscles) k
  where not exists (select 1 from public.muscles m where m.key = k)) bad;

\echo '--- 7. the figure is per league and shut to non-members'
insert into auth.users (id) values ('b3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('eeee0000-0000-0000-0000-000000000003','b3333333-3333-3333-3333-333333333333','OUTSIDER','BD3');
set request.jwt.claim.sub = 'b3333333-3333-3333-3333-333333333333';
select case when (select count(*) from
                  public.my_muscles('ffff0000-0000-0000-0000-000000000001')) = 0
       then 'a non-member sees no figure' else 'AN OUTSIDER READ THE FIGURE' end;

\echo '--- 8. the figure setting'
set request.jwt.claim.sub = 'b1111111-1111-1111-1111-111111111111';
select 'starts as: ' || body_form from public.profiles where restore_code = 'BD1';
select 'switched to: ' || body_form from public.set_body_form('fem');
do $$ begin
  perform public.set_body_form('werewolf');
  raise exception 'A NONSENSE FIGURE WAS ACCEPTED';
exception when others then
  if sqlerrm like '%A NONSENSE FIGURE%' then raise; end if;
  raise notice 'nonsense figure refused: %', sqlerrm;
end $$;

\echo '--- 8b. all time stretches the target with the weeks, so it stays readable'
select 'this week : biceps ' || pct || '% over ' || weeks || ' week'
from public.my_muscles('ffff0000-0000-0000-0000-000000000001', false) where key = 'biceps';
select 'all time  : biceps ' || pct || '% over ' || weeks || ' week'
from public.my_muscles('ffff0000-0000-0000-0000-000000000001', true) where key = 'biceps';
select case when (select target from public.my_muscles(
                    'ffff0000-0000-0000-0000-000000000001', true) where key = 'biceps')
          >= (select target from public.my_muscles(
                    'ffff0000-0000-0000-0000-000000000001', false) where key = 'biceps')
       then 'a longer range asks for more work, not the same work'
       else 'ALL TIME WOULD READ 99 FOR EVERYBODY BY MONTH TWO' end;

\echo '--- 8c. the dose grows with the athlete'
select 'a beginner (nothing logged)      -> x' || public.muscle_dose(
  'eeee0000-0000-0000-0000-000000000003');
select 'somebody a week or two in        -> x' || public.muscle_dose(
  'eeee0000-0000-0000-0000-000000000002');
select case when public.muscle_dose('eeee0000-0000-0000-0000-000000000002')
          >= public.muscle_dose('eeee0000-0000-0000-0000-000000000003')
       then 'the further along you are, the bigger a full week is'
       else 'THE DOSE SHRANK' end;
select case when public.muscle_dose('eeee0000-0000-0000-0000-000000000003') >= 0.6
       then 'and it never drops below the beginner floor' else 'IT WENT UNDER' end;
-- the figure has to ask for the base dose times this person's own factor,
-- which for somebody one light week in is less than the base, not more
select 'the figure asks this reader for ' ||
       (select max(target) from public.my_muscles('ffff0000-0000-0000-0000-000000000001'))
       || ' on the biggest region, base ' || (select max(target) from public.muscles);
select case when (select max(target) from public.my_muscles(
                    'ffff0000-0000-0000-0000-000000000001'))
          =  round((select max(target) from public.muscles)
                   * public.muscle_dose('eeee0000-0000-0000-0000-000000000001'))
       then 'the target is the base scaled by that reader''s dose'
       else 'THE TARGET IGNORED THE DOSE' end;

\echo '--- 9. wins: nobody has won anything before the first week ends'
select 'members listed: ' || count(*) || ', weeks finished: ' || max(weeks)
       || ', wins between ' || min(wins) || ' and ' || max(wins)
from public.league_wins('ffff0000-0000-0000-0000-000000000001');

\echo '--- 10. finish two weeks and count them'
alter table public.workouts disable trigger user;
-- ARM DAY takes last week, ROUNDED takes the one before
update public.workouts set week_start = public.current_week_start() - 7
 where profile_id = 'eeee0000-0000-0000-0000-000000000001';
update public.workouts set week_start = public.current_week_start() - 14
 where profile_id = 'eeee0000-0000-0000-0000-000000000002';
alter table public.workouts enable trigger user;
select display_name || ': ' || wins || ' win(s), last ' || coalesce(last_win::text, 'never')
from public.league_wins('ffff0000-0000-0000-0000-000000000001');
select 'weeks in the books: ' || max(weeks)
from public.league_wins('ffff0000-0000-0000-0000-000000000001');
select case when (select sum(wins) from public.league_wins('ffff0000-0000-0000-0000-000000000001'))
          =  (select max(weeks) from public.league_wins('ffff0000-0000-0000-0000-000000000001'))
       then 'every finished week has exactly one winner'
       else 'THE WINS DO NOT ADD UP TO THE WEEKS' end;

\echo '--- 11. and the badge agrees with the tracker'
select 'CHAMPION: ' || case when earned then 'earned' else 'not yet' end
       || ' (' || progress || '/' || target || ')'
from public.my_badges('ffff0000-0000-0000-0000-000000000001') where key = 'week_win';
select key || ': ' || progress || '/' || target
from public.my_badges('ffff0000-0000-0000-0000-000000000001')
where key in ('win3','win5','win10','balance40','balance60') order by key;
select case when (select progress from public.my_badges('ffff0000-0000-0000-0000-000000000001')
                  where key = 'win5')
          =  (select wins from public.league_wins('ffff0000-0000-0000-0000-000000000001')
              where mine)
       then 'the badge counts the same wins the tracker does'
       else 'THE BADGE AND THE TRACKER DISAGREE' end;

\echo '--- 12. a finished week is worth what the board said it was worth'
select case when exists (
         select 1 from public.weekly_history('ffff0000-0000-0000-0000-000000000001'))
       then 'the hall of fame has weeks in it' else 'NO HISTORY' end;
select 'columns carry joined_at for the tie-break: ' ||
       case when (select count(*) from public.weekly_history(
                    'ffff0000-0000-0000-0000-000000000001')
                  where joined_at is not null) > 0 then 'yes' else 'NO' end;
