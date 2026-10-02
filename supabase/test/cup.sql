-- The cup. A season table rewards consistency, which is the right thing to
-- reward and a dull thing to watch; the cup is the other half, a straight
-- knockout over the season's last four weeks where one bad week ends you.
--
-- Nothing about it is stored, so every one of these reads the bracket out of
-- the same weekly_history the hall tab is drawn from. The things that can go
-- wrong are all arithmetic: a draw that puts the top two seeds in the same
-- half, a field that changes size while the cup is being played, a lock date
-- that depends on the field size that depends on the lock date, and a dead
-- heat that advances nobody.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

\echo '--- 1. the draw keeps the top two apart'
select '  field 16 -> ' || public.cup_seed_order(16)::text;
select '  field 8  -> ' || public.cup_seed_order(8)::text;
select '  field 4  -> ' || public.cup_seed_order(4)::text;
-- The first tie must be the top seed against the bottom one, and seeds 1 and 2
-- must sit in opposite halves or they meet before the final.
select case when (select o[1] = 1 and o[2] = 16
                       and (array_position(o, 2) > 8)
                  from (select public.cup_seed_order(16) as o) q)
       then 'the top seed draws the bottom one, and 1 and 2 are in opposite halves'
       else 'THE DRAW IS WRONG' end;
-- every seed exactly once, or somebody is playing twice
select case when (select count(distinct s) = 16 and count(*) = 16
                  from unnest(public.cup_seed_order(16)) s)
       then 'and every seed appears exactly once'
       else 'A SEED IS MISSING OR DUPLICATED' end;

\echo '--- 2. the field is the biggest power of two that fits, capped at 16'
select '  ' || e || ' played -> field ' || public.cup_field(e)
from (values (3),(4),(7),(8),(15),(16),(31)) v(e);
select case when public.cup_field(3) = 0 and public.cup_field(7) = 4
             and public.cup_field(15) = 8 and public.cup_field(40) = 16
       then 'under four there is no cup, and 16 is the ceiling'
       else 'THE FIELD SIZES ARE WRONG' end;

\echo '--- 3. what each round is called'
select '  round ' || r || ' of 4 -> ' || public.cup_round_name(r, 4)
from generate_series(1, 4) r;
select case when public.cup_round_name(4,4) = 'FINAL'
             and public.cup_round_name(1,4) = 'ROUND OF 16'
             and public.cup_round_name(1,3) = 'QUARTER-FINALS'
       then 'and a smaller field starts further in, not at a round of 16'
       else 'THE ROUNDS ARE MISNAMED' end;

-- ---------------------------------------------------------------- fixtures
-- Eighteen people, so sixteen get in and two are left looking at the cut.
insert into auth.users (id)
select ('61111111-0000-0000-0000-' || lpad(k::text, 12, '0'))::uuid
from generate_series(1, 18) k on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code)
select ('6aaa0000-0000-0000-0000-' || lpad(k::text, 12, '0'))::uuid,
       ('61111111-0000-0000-0000-' || lpad(k::text, 12, '0'))::uuid,
       'P' || lpad(k::text, 2, '0'), 'CUP' || lpad(k::text, 3, '0')
from generate_series(1, 18) k;

create function pg_temp.mkleague(p_id uuid, p_code text, p_weeks int,
                                 p_age int, p_members int) returns void
language plpgsql as $$
begin
  insert into public.leagues (id, name, code, owner_id, rest_dow, season_weeks,
                              season_break, created_at)
  values (p_id, 'CUP ' || p_code, p_code,
          '6aaa0000-0000-0000-0000-000000000001', '{}'::int[], p_weeks, 0,
          (public.current_week_start() - p_age * 7)::timestamptz
            + interval '12 hours');
  insert into public.league_members (league_id, profile_id)
  select p_id, ('6aaa0000-0000-0000-0000-' || lpad(k::text, 12, '0'))::uuid
  from generate_series(1, p_members) k;
end $$;

-- A finished week is written with the triggers off: they stamp the current week
-- and recompute the points, which is exactly what a past week must not get.
alter table public.workouts disable trigger user;

-- `pts` is the RAW total for the week; weekly_history runs it through the
-- repetition discount, which keeps the order but squashes the gaps. 1000 - 10k
-- gives person k place k in every week, every week, so the seeding is
-- predictable enough to assert on.
create function pg_temp.mkweeks(p_id uuid, p_members int, p_from int,
                                p_to int) returns void
language plpgsql as $$
begin
  insert into public.workouts (league_id, profile_id, exercise_key, mode,
                               amount, points, week_start, created_at)
  select p_id, ('6aaa0000-0000-0000-0000-' || lpad(k::text, 12, '0'))::uuid,
         'pushups', 'reps', 10, 1000 - 10 * k,
         public.league_week0(p_id) + (w * 7),
         (public.league_week0(p_id) + (w * 7))::timestamptz + interval '12 hours'
  from generate_series(1, p_members) k, generate_series(p_from, p_to) w;
end $$;

-- ================================================================ league A
-- A twelve week season, eleven weeks old, so THIS week is the final. The cup
-- locks four weeks out (week 8) and its rounds are weeks 8, 9, 10 and 11 —
-- three of them finished, the last one being played right now.
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000a', 'CUPA', 12, 11, 18);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000a', 18, 0, 11);
-- THE UPSET: the bottom seed outscores the top one in the round of 16, which
-- is the whole point of a knockout.
update public.workouts set points = 4000
 where league_id = '6bbb0000-0000-0000-0000-00000000000a'
   and profile_id = '6aaa0000-0000-0000-0000-000000000016'
   and week_start = public.league_week0('6bbb0000-0000-0000-0000-00000000000a') + 8 * 7;
-- A DEAD HEAT in the semi-final: seed 8 matches seed 4 exactly.
update public.workouts set points = 1000 - 10 * 4
 where league_id = '6bbb0000-0000-0000-0000-00000000000a'
   and profile_id = '6aaa0000-0000-0000-0000-000000000008'
   and week_start = public.league_week0('6bbb0000-0000-0000-0000-00000000000a') + 10 * 7;
alter table public.workouts enable trigger user;

set request.jwt.claim.sub = '61111111-0000-0000-0000-000000000017';

\echo '--- 4. where the cup stands'
select '  phase ' || phase || ' · season ' || season || ' · field ' || field
       || ' · ' || rounds || ' rounds · ' || entrants || ' played'
from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a');
select '  locks ' || lock_week || ' · opens ' || first_week || ' · final ' || final_week
       || ' · now round ' || round || ' (' || round_name || ')'
from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a');
select case when (select phase = 'RUNNING' and field = 16 and rounds = 4
                       and entrants = 18 and round = 4 and round_name = 'FINAL'
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a'))
       then 'eighteen played, sixteen got in, and the final is the week being played'
       else 'THE PHASE OR THE FIELD IS WRONG' end;
-- the final must land on the season's last week, or the cup and the table stop
-- finishing together
select case when (select final_week = public.league_week0(
                    '6bbb0000-0000-0000-0000-00000000000a') + 11 * 7
                   and first_week = final_week - 3 * 7
                   and lock_week = first_week
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a'))
       then 'and it is the last week of the season, with the draw locked four out'
       else 'THE CUP IS NOT ANCHORED TO THE END OF THE SEASON' end;

\echo '--- 5. the seventeenth place can see exactly what it is missing'
select '  rank ' || my_rank || ' · seeded ' || coalesce(my_seed::text, 'no')
       || ' · the cut was worth ' || cut_points
from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a');
select case when (select my_rank = 17 and my_seed is null and cut_points > 0
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a'))
       then 'out of the cup, and told what the sixteenth seed scored'
       else 'THE CUT IS NOT REPORTED' end;
set request.jwt.claim.sub = '61111111-0000-0000-0000-000000000004';
select case when (select my_rank = 4 and my_seed = 4
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000a'))
       then 'and somebody in the field is told their seed'
       else 'A SEEDED PLAYER IS NOT TOLD THEIR SEED' end;

\echo '--- 6. the bracket'
select '  ' || lpad(round_name, 14) || ' | ' || coalesce(a_name, a_from::text)
       || ' ' || coalesce(a_points::text, '-') || ' v '
       || coalesce(b_points::text, '-') || ' ' || coalesce(b_name, b_from::text)
       || ' | ' || status || ' -> ' || coalesce(winner_seed::text, '?')
from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
order by round, slot;
select case when (select count(*) = 15 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000a'))
       then 'fifteen ties: eight, four, two and one'
       else 'THE BRACKET IS THE WRONG SIZE' end;

\echo '--- 7. points beat seeding'
select case when (select winner_seed = 16 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000a')
                  where round = 1 and slot = 1)
       then 'the bottom seed outscored the top one and went through'
       else 'THE UPSET DID NOT COUNT' end;
-- and the upset has to travel: the quarter-final must be against seed 16, not
-- against whoever the draw said "should" be there
select case when (select 16 in (a_seed, b_seed) from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000a')
                  where round = 2 and slot = 1)
       then 'and it carried into the next round'
       else 'THE BRACKET IGNORED ITS OWN RESULT' end;

\echo '--- 8. a dead heat goes to the higher seed'
select case when (select a_points = b_points and winner_seed = least(a_seed, b_seed)
                  from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
                  where round = 3 and slot = 1)
       then 'level on points, and the better season went through'
       else 'A DEAD HEAT ADVANCED NOBODY OR THE WRONG BODY' end;

\echo '--- 9. the week being played is live and undecided'
select case when (select status = 'LIVE' and winner is null
                       and a_profile is not null and b_profile is not null
                  from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
                  where round = 4)
       then 'the final has both players, a running score and no winner yet'
       else 'THE FINAL IS SETTLED TOO EARLY OR NOT SET AT ALL' end;
-- a finished round is settled all the way through
select case when (select count(*) = 0 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000a')
                  where status = 'DONE' and winner is null)
       then 'and every finished tie has a winner'
       else 'A FINISHED TIE ADVANCED NOBODY' end;

\echo '--- 10. a tie says who can still reach it'
select '  QF slot 1 can come from ' || a_from::text || ' and ' || b_from::text
from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
where round = 2 and slot = 1;
select case when (select a_from = array[1,16] and b_from = array[8,9]
                  from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
                  where round = 2 and slot = 1)
       then 'a quarter-final knows it is 1/16 against 8/9'
       else 'THE POSSIBLE VERSUS IS WRONG' end;
select case when (select array_length(a_from, 1) = 8
                       and array_length(b_from, 1) = 8
                  from public.league_cup('6bbb0000-0000-0000-0000-00000000000a')
                  where round = 4)
       then 'and the final can be reached by either half of the draw'
       else 'THE FINAL DOES NOT KNOW ITS HALVES' end;

-- ================================================================ league B
-- Six weeks from the final, so the bracket is on show and still moving.
alter table public.workouts disable trigger user;
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000b', 'CUPB', 12, 5, 18);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000b', 18, 0, 5);
alter table public.workouts enable trigger user;

\echo '--- 11. before it locks, it is a projection'
select '  phase ' || phase || ' · locks in ' || weeks_to_lock || ' weeks'
from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000b');
select case when (select phase = 'PROJECTED' and weeks_to_lock = 3 and field = 16
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000b'))
       then 'drawn from where the table stands, and it says when it stops moving'
       else 'THE PROJECTION IS WRONG' end;
select case when (select count(*) = 8 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000b')
                  where round = 1 and status = 'SCHEDULED'
                    and a_profile is not null and b_profile is not null)
       then 'and all eight first round ties already have two names on them'
       else 'THE POSSIBLE VERSUS IS NOT THERE YET' end;
select case when (select count(*) = 0 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000b')
                  where round > 1 and (a_profile is not null or winner is not null))
       then 'while nothing past the first round pretends to know who is in it'
       else 'A LATER ROUND INVENTED ITS ENTRANTS' end;

-- ================================================================ league C
-- Ten people, so the cup is a field of eight and starts a week later.
alter table public.workouts disable trigger user;
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000c', 'CUPC', 12, 11, 10);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000c', 10, 0, 11);
alter table public.workouts enable trigger user;

\echo '--- 12. a smaller league gets a smaller cup, ending on the same week'
select '  field ' || field || ' · ' || rounds || ' rounds · opens ' || first_week
       || ' · final ' || final_week || ' · ' || round_name
from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000c');
select case when (select field = 8 and rounds = 3 and round_name = 'FINAL'
                       and first_week = final_week - 2 * 7
                  from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000c'))
       then 'eight players, three rounds, and the final still closes the season'
       else 'THE SMALL CUP IS MISSHAPEN' end;
select case when (select count(*) = 7 from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000c'))
       then 'seven ties'
       else 'THE SMALL BRACKET IS THE WRONG SIZE' end;

-- ================================================================ no cup
alter table public.workouts disable trigger user;
-- an endless season has no finish line to hang a final off
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000d', 'CUPD', 12, 11, 18);
update public.leagues set season_weeks = null
 where id = '6bbb0000-0000-0000-0000-00000000000d';
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000d', 18, 0, 11);
-- a season short enough to be all cup is not a season
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000e', 'CUPE', 4, 3, 18);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000e', 18, 0, 3);
-- a season with thirty-six weeks still to run
select pg_temp.mkleague('6bbb0000-0000-0000-0000-00000000000f', 'CUPF', 38, 1, 18);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-00000000000f', 18, 0, 1);
-- three people is not a tournament
select pg_temp.mkleague('6bbb0000-0000-0000-0000-000000000010', 'CUPG', 12, 11, 3);
select pg_temp.mkweeks('6bbb0000-0000-0000-0000-000000000010', 3, 0, 11);
alter table public.workouts enable trigger user;

\echo '--- 13. and the cases that must show nothing at all'
select '  endless season : ' || (select count(*) from public.league_cup_state(
         '6bbb0000-0000-0000-0000-00000000000d'));
select '  four week season: ' || (select count(*) from public.league_cup_state(
         '6bbb0000-0000-0000-0000-00000000000e'));
select '  too early      : ' || (select count(*) from public.league_cup_state(
         '6bbb0000-0000-0000-0000-00000000000f'));
select '  three players  : ' || (select count(*) from public.league_cup_state(
         '6bbb0000-0000-0000-0000-000000000010'));
select case when (select count(*) from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000d')) = 0
             and (select count(*) from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000e')) = 0
             and (select count(*) from public.league_cup_state('6bbb0000-0000-0000-0000-00000000000f')) = 0
             and (select count(*) from public.league_cup_state('6bbb0000-0000-0000-0000-000000000010')) = 0
             and (select count(*) from public.league_cup('6bbb0000-0000-0000-0000-00000000000f')) = 0
       then 'no finish line, no room, too early or too few — and the tab stays empty'
       else 'A CUP APPEARED WHERE THERE SHOULD BE NONE' end;

\echo '--- 14. and it is shut to somebody outside the league'
set request.jwt.claim.sub = '61111111-0000-0000-0000-000000000018';
delete from public.league_members
 where league_id = '6bbb0000-0000-0000-0000-00000000000a'
   and profile_id = '6aaa0000-0000-0000-0000-000000000018';
select case when (select count(*) from public.league_cup_state(
                    '6bbb0000-0000-0000-0000-00000000000a')) = 0
             and (select count(*) from public.league_cup(
                    '6bbb0000-0000-0000-0000-00000000000a')) = 0
       then 'a stranger sees no bracket'
       else 'THE CUP IS READABLE FROM OUTSIDE THE LEAGUE' end;
