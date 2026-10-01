-- The season table. People start and fade: a week is a sprint and winning it
-- is all-or-nothing, so anybody who cannot realistically top the board has
-- nothing to play for by Wednesday. The crowns race it replaced had the same
-- hole — only a winner ever moved. Every finished week now pays by FINISHING
-- POSITION, and these hold that payout honest.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

\echo '--- 1. the payout table'
select '  ' || lpad(r::text || case when r % 10 = 1 and r <> 11 then 'st'
                                    when r % 10 = 2 and r <> 12 then 'nd'
                                    when r % 10 = 3 and r <> 13 then 'rd'
                                    else 'th' end, 6)
       || ' -> ' || public.rank_points(r)
from generate_series(1, 21) r where r in (1,2,3,5,10,15,20,21);
select case when public.rank_points(1) = 5.00 and public.rank_points(20) = 0.10
             and public.rank_points(21) = 0 and public.rank_points(500) = 0
       then 'first pays 5, twentieth pays 0.1, and nothing below that scores'
       else 'THE ENDS OF THE TABLE MOVED' end;
-- every place must be worth strictly less than the one above it, or two
-- positions are the same position
select case when (select count(*) from generate_series(1, 19) r
                  where public.rank_points(r) <= public.rank_points(r + 1)) = 0
       then 'and every place is worth strictly less than the one above it'
       else 'TWO PLACES PAY THE SAME' end;
-- winning has to stay clearly better than not winning
select case when public.rank_points(1) / public.rank_points(2) >= 1.3
       then 'a win is worth ' || round(100 * (public.rank_points(1) /
            public.rank_points(2) - 1)) || '% more than second'
       else 'WINNING IS BARELY BETTER THAN SECOND' end;
-- and the midfield has to be worth climbing, not a rounding error
select case when public.rank_points(11) / public.rank_points(16) >= 2
       then 'and climbing 16th -> 11th more than doubles the week'
       else 'THE MIDFIELD IS FLAT, SO THERE IS NOTHING TO CLIMB' end;

insert into auth.users (id) values
  ('51111111-1111-1111-1111-111111111111'),
  ('52222222-2222-2222-2222-222222222222'),
  ('53333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('5aaa0000-0000-0000-0000-000000000001','51111111-1111-1111-1111-111111111111','ACE','SN1'),
  ('5aaa0000-0000-0000-0000-000000000002','52222222-2222-2222-2222-222222222222','STEADY','SN2'),
  ('5aaa0000-0000-0000-0000-000000000003','53333333-3333-3333-3333-333333333333','GHOST','SN3');
-- A four week season with no off-season, created five weeks ago, so week 5
-- opens season 2. The break gets its own section further down, and starting
-- at zero keeps the boundary arithmetic here readable.
insert into public.leagues (id, name, code, owner_id, rest_dow, season_weeks,
                            season_break, created_at)
values ('5bbb0000-0000-0000-0000-000000000001','IRON','SEA001',
        '5aaa0000-0000-0000-0000-000000000001',
        array[(extract(isodow from (now() at time zone public.app_timezone()))::int % 7) + 1],
        4, 0, now() - interval '35 days');
insert into public.league_members (league_id, profile_id) values
  ('5bbb0000-0000-0000-0000-000000000001','5aaa0000-0000-0000-0000-000000000001'),
  ('5bbb0000-0000-0000-0000-000000000001','5aaa0000-0000-0000-0000-000000000002'),
  ('5bbb0000-0000-0000-0000-000000000001','5aaa0000-0000-0000-0000-000000000003');

\echo '--- 2. five finished weeks: ACE wins four, STEADY is always second'
-- GHOST shows up for one week and fades, which is the whole reason the table
-- exists. Built with the triggers off, the only way to write a finished week.
alter table public.workouts disable trigger user;
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount,
                             points, week_start, created_at)
select '5bbb0000-0000-0000-0000-000000000001', who, 'pushups', 'reps', 10, pts,
       public.league_week0('5bbb0000-0000-0000-0000-000000000001') + (w * 7),
       (public.league_week0('5bbb0000-0000-0000-0000-000000000001') + (w * 7))::timestamptz
         + interval '12 hours'
from (values
  (0,'5aaa0000-0000-0000-0000-000000000001'::uuid,100),(0,'5aaa0000-0000-0000-0000-000000000002',90),
  (0,'5aaa0000-0000-0000-0000-000000000003',80),
  (1,'5aaa0000-0000-0000-0000-000000000001',100),(1,'5aaa0000-0000-0000-0000-000000000002',90),
  (2,'5aaa0000-0000-0000-0000-000000000001',100),(2,'5aaa0000-0000-0000-0000-000000000002',90),
  (3,'5aaa0000-0000-0000-0000-000000000002',100),(3,'5aaa0000-0000-0000-0000-000000000001',90),
  (4,'5aaa0000-0000-0000-0000-000000000001',100),(4,'5aaa0000-0000-0000-0000-000000000002',90)
) v(w, who, pts);
alter table public.workouts enable trigger user;

set request.jwt.claim.sub = '51111111-1111-1111-1111-111111111111';

\echo '--- 3. the season boundary falls where the calendar says, not the logs'
select '  season of week ' || w || ': ' || public.season_index(
         '5bbb0000-0000-0000-0000-000000000001',
         public.league_week0('5bbb0000-0000-0000-0000-000000000001') + (w * 7))
from generate_series(0, 5) w;
select case when public.season_index('5bbb0000-0000-0000-0000-000000000001',
               public.league_week0('5bbb0000-0000-0000-0000-000000000001') + 21) = 0
         and public.season_index('5bbb0000-0000-0000-0000-000000000001',
               public.league_week0('5bbb0000-0000-0000-0000-000000000001') + 28) = 1
       then 'a four week season ends after week four, whatever was logged'
       else 'THE SEASON BOUNDARY IS IN THE WRONG PLACE' end;

\echo '--- 4. where the season stands'
select '  season ' || (season + 1) || ' of ' || seasons || ', week ' || weeks_done
       || ' of ' || season_weeks
from public.league_season_state('5bbb0000-0000-0000-0000-000000000001');

\echo '--- 5. season 1: ACE 3 wins + 1 second, STEADY the reverse'
select '  ' || rpad(display_name, 8) || lpad(points::text, 7) || '  '
       || weeks || 'wk  ' || wins || 'W  best ' || coalesce(best_rank::text, '-')
from public.league_season('5bbb0000-0000-0000-0000-000000000001', 0);
-- 3 firsts and 1 second = 3*5.00 + 3.60
select case when (select points from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 0) where display_name = 'ACE')
          =  3 * public.rank_points(1) + public.rank_points(2)
       then 'ACE scores three wins and a second, to the decimal'
       else 'THE SEASON TOTAL IS NOT THE SUM OF THE PLACINGS' end;
-- GHOST showed up once, finished third, and has 0.80 for the season. The
-- point of the whole thing: turning up at all is worth more than nothing.
select case when (select points from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 0) where display_name = 'GHOST')
          =  public.rank_points(3)
       then 'and somebody who turned up once and came third still has a score'
       else 'TURNING UP ONCE IS WORTH NOTHING' end;
select case when (select count(*) from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 0)) = 3
       then 'every member is on the table, scoring or not'
       else 'THE TABLE LEAVES MEMBERS OFF' end;

\echo '--- 6. the table is sorted by season points, best first'
select case when (select display_name from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 0) limit 1) = 'ACE'
       then 'the leader is first in the list'
       else 'THE TABLE IS NOT SORTED' end;

\echo '--- 7. season 2 starts from zero, and the crowns carry over'
select '  ' || rpad(display_name, 8) || lpad(points::text, 7)
       || '  season wins ' || wins || ', crowns all time ' || lifetime_wins
from public.league_season('5bbb0000-0000-0000-0000-000000000001', 1);
select case when (select points from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 1) where display_name = 'ACE')
          =  public.rank_points(1)
       then 'season 2 holds only its own week'
       else 'SEASON 2 INHERITED SEASON 1' end;
select case when (select lifetime_wins from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 1) where display_name = 'ACE') = 4
       then 'but the crown count follows the person across seasons'
       else 'THE CROWNS RESET WITH THE SEASON' end;

\echo '--- 8. with no season length there is one season that never ends'
update public.leagues set season_weeks = null
 where id = '5bbb0000-0000-0000-0000-000000000001';
select case when (select count(distinct public.season_index(
                    '5bbb0000-0000-0000-0000-000000000001',
                    public.league_week0('5bbb0000-0000-0000-0000-000000000001') + (w*7)))
                  from generate_series(0, 60) w) = 1
       then 'every week of a sixty week run lands in the same season'
       else 'AN OPEN SEASON STILL SPLIT' end;
select case when (select points from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001') where display_name = 'ACE')
          =  4 * public.rank_points(1) + public.rank_points(2)
       then 'and all five weeks are in one table'
       else 'THE OPEN SEASON LOST A WEEK' end;
update public.leagues set season_weeks = 38
 where id = '5bbb0000-0000-0000-0000-000000000001';

\echo '--- 8b. an off-season between two seasons'
-- A 38 week table with no end is a treadmill. Two weeks of break means the
-- cycle is six weeks on this fixture: four played, two off.
update public.leagues set season_weeks = 4, season_break = 2
 where id = '5bbb0000-0000-0000-0000-000000000001';
select '  week ' || w || ': ' || coalesce(public.season_index(
         '5bbb0000-0000-0000-0000-000000000001',
         public.league_week0('5bbb0000-0000-0000-0000-000000000001') + (w*7))::text,
       'off season')
from generate_series(0, 7) w;
select case when (select count(*) from generate_series(0,3) w
                  where public.season_index('5bbb0000-0000-0000-0000-000000000001',
                    public.league_week0('5bbb0000-0000-0000-0000-000000000001')+(w*7)) = 0) = 4
         and (select count(*) from generate_series(4,5) w
              where public.season_index('5bbb0000-0000-0000-0000-000000000001',
                public.league_week0('5bbb0000-0000-0000-0000-000000000001')+(w*7)) is null) = 2
         and public.season_index('5bbb0000-0000-0000-0000-000000000001',
               public.league_week0('5bbb0000-0000-0000-0000-000000000001')+(6*7)) = 1
       then 'four weeks on, two off, then season 2 — and the cycle repeats'
       else 'THE OFF-SEASON IS IN THE WRONG PLACE' end;
-- the whole point: a break week pays nobody any season points
select case when (select coalesce(sum(points), -1) from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001', 1)) = 0
       then 'and the season after the break starts everybody on zero'
       else 'A BREAK WEEK PAID SEASON POINTS' end;
-- but the week still happened, so the hall of fame keeps it
select case when (select count(distinct week_start) from public.weekly_history(
                    '5bbb0000-0000-0000-0000-000000000001')) = 5
       then 'the hall of fame still holds every week, break or not'
       else 'A BREAK WEEK VANISHED FROM THE HALL' end;
select '  ' || case when on_break then 'on the break, next season opens '
                    else 'in season, next one opens ' end || next_start
from public.league_season_state('5bbb0000-0000-0000-0000-000000000001');
-- and an endless season never breaks, whatever the break is set to
update public.leagues set season_weeks = null, season_break = 3
 where id = '5bbb0000-0000-0000-0000-000000000001';
select case when (select count(*) from generate_series(0,60) w
                  where public.season_index('5bbb0000-0000-0000-0000-000000000001',
                    public.league_week0('5bbb0000-0000-0000-0000-000000000001')+(w*7))
                    is distinct from 0) = 0
       then 'a season with no end never takes a break either'
       else 'AN ENDLESS SEASON TOOK A BREAK' end;
update public.leagues set season_weeks = 38, season_break = 2
 where id = '5bbb0000-0000-0000-0000-000000000001';

\echo '--- 9. a real season length is allowed'
select '  38 and 50 week seasons both fit: ' ||
       (select season_weeks::text from public.leagues
        where id = '5bbb0000-0000-0000-0000-000000000001');
-- the owner setting it, through the same call the app uses
select '' from public.set_league_settings('5bbb0000-0000-0000-0000-000000000001',
         array[7], 50, null, 3);
select case when (select season_break from public.leagues
                  where id = '5bbb0000-0000-0000-0000-000000000001') = 3
       then 'and the owner sets the off-season through the same call'
       else 'THE OFF-SEASON DID NOT SAVE' end;
select case when (select season_weeks from public.leagues
                  where id = '5bbb0000-0000-0000-0000-000000000001') = 50
       then 'a fifty week season saves, where the old ceiling was 26'
       else 'A LONG SEASON IS STILL REFUSED' end;

\echo '--- 9b. the old six-column name still answers, for an app not yet updated'
-- league_season_info is live in somebody's pocket. Dropping a function the
-- hall tab polls would blank that tab until they reloaded, so the wider shape
-- took a new name and the old one became a thin view onto it.
select case when (select count(*) from public.league_season_info(
                    '5bbb0000-0000-0000-0000-000000000001')) = 1
         and (select season from public.league_season_info(
                '5bbb0000-0000-0000-0000-000000000001'))
           = (select season from public.league_season_state(
                '5bbb0000-0000-0000-0000-000000000001'))
       then 'the old name still works and agrees with the new one'
       else 'AN OLD CLIENT WOULD BREAK' end;

\echo '--- 10. and it is shut to somebody outside the league'
set request.jwt.claim.sub = '53333333-3333-3333-3333-333333333333';
select case when (select count(*) from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001')) > 0
       then 'a member reads the table' else 'A MEMBER CANNOT READ IT' end;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000dead';
select case when (select count(*) from public.league_season(
                    '5bbb0000-0000-0000-0000-000000000001')) = 0
       then 'and a stranger reads nothing' else 'A STRANGER READ THE TABLE' end;
