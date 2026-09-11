\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

-- two leagues, same people, same logs, different scoring modes
insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('cccc0000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','BUSY','SC1'),
  ('cccc0000-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','GRINDER','SC2');
insert into public.leagues (id, name, code, owner_id, scoring) values
  ('dddd0000-0000-0000-0000-000000000001','HARD','HARDAA','cccc0000-0000-0000-0000-000000000001','hardcore'),
  ('dddd0000-0000-0000-0000-000000000002','FAIR','FAIRAA','cccc0000-0000-0000-0000-000000000001','balanced');
insert into public.league_members (league_id, profile_id)
select l.id, p.id from public.leagues l, public.profiles p
where l.code in ('HARDAA','FAIRAA') and p.restore_code in ('SC1','SC2');

\echo '--- a league is hardcore unless somebody changes it'
select 'new leagues default to: ' || scoring from public.leagues where code = 'HARDAA';

\echo '--- the curve itself'
select 'push  40 pts -> ' || public.decay_points(40, 'PUSH');
select 'push  85 pts -> ' || public.decay_points(85, 'PUSH');
select 'push 300 pts -> ' || public.decay_points(300, 'PUSH');
select 'cardio 105 pts (half marathon) -> ' || round(public.decay_points(105, 'CARDIO'), 1);
select 'cardio 210 pts (marathon)      -> ' || round(public.decay_points(210, 'CARDIO'), 1);
select 'recovery is never tapered: 5 -> ' || public.decay_points(5, 'RECOVERY');

\echo '--- the same log in both leagues'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
-- BUSY: 50 push-ups + 20 pull-ups (90 raw)
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
select l.id, 'cccc0000-0000-0000-0000-000000000001', v.k, 'reps', v.n
from public.leagues l, (values ('pushups', 50), ('pullups', 20)) v(k, n)
where l.code in ('HARDAA','FAIRAA');
-- GRINDER: 400 push-ups, split into ten sets to prove splitting does not help
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
select l.id, 'cccc0000-0000-0000-0000-000000000002', 'pushups', 'reps', 40
from public.leagues l, generate_series(1,10) g
where l.code in ('HARDAA','FAIRAA');

select 'HARDCORE  ' || display_name || ': ' || points || ' (logged ' || logged || ')'
from public.league_leaderboard('dddd0000-0000-0000-0000-000000000001') order by points desc;
select 'BALANCED  ' || display_name || ': ' || round(points,1) || ' (logged ' || logged || ')'
from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002') order by points desc;

\echo '--- the gap, which is the whole point'
select 'hardcore gap: ' || round(max(points) - min(points), 1)
from public.league_leaderboard('dddd0000-0000-0000-0000-000000000001');
select 'balanced gap: ' || round(max(points) - min(points), 1)
from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002');

\echo '--- ten sets of 40 scores the same as one set of 400'
select case when (select round(points,2) from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002')
                  where display_name = 'GRINDER')
          = round(public.decay_points(400, 'PUSH'), 2)
       then 'splitting sets changes nothing' else 'SPLITTING HELPED — BUG' end;

\echo '--- the busy person barely notices'
select case when (select points from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002')
                  where display_name = 'BUSY') >= 85
       then 'a 15-minute session keeps 94% or more' else 'THE SHORT SESSION WAS PUNISHED' end;

\echo '--- midnight empties the bucket: yesterday is scored on its own'
-- the stamp trigger sets created_at itself, and rightly so — a workout cannot
-- be backdated through the app — so the test writes round it to place a row
-- on another day
alter table public.workouts disable trigger workouts_stamp_trg;
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount,
                             points, week_start, created_at)
select l.id, 'cccc0000-0000-0000-0000-000000000001', 'pushups', 'reps', 50,
       50, public.current_week_start(), now() - interval '1 day'
from public.leagues l where l.code in ('HARDAA','FAIRAA');
alter table public.workouts enable trigger workouts_stamp_trg;

select 'BUSY in the balanced league is now ' ||
       round((select points from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002')
              where display_name = 'BUSY'), 1);
select case when (select points from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002')
                  where display_name = 'BUSY') = 87 + public.decay_points(50, 'PUSH')
       then 'yesterday scored on its own — 50 push-ups at full rate'
       else 'THE DAY BUCKET DID NOT RESET' end;
select case when public.decay_points(100, 'PUSH') < 2 * public.decay_points(50, 'PUSH')
       then 'and 100 in one day is worth less than 50 on each of two'
       else 'SPREADING WAS NOT REWARDED' end;

\echo '--- switching a league over does not touch anybody''s logs'
select public.set_league_scoring('dddd0000-0000-0000-0000-000000000001', 'balanced');
select 'HARD is now ' || scoring from public.leagues where code = 'HARDAA';
select 'and its board now reads ' ||
       round((select points from public.league_leaderboard('dddd0000-0000-0000-0000-000000000001')
              where display_name = 'GRINDER'), 1) || ' for the grinder';
select public.set_league_scoring('dddd0000-0000-0000-0000-000000000001', 'hardcore');
select 'switched back: ' ||
       round((select points from public.league_leaderboard('dddd0000-0000-0000-0000-000000000001')
              where display_name = 'GRINDER'), 1) || ' — nothing was lost';

\echo '--- only the owner may change it'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
  perform public.set_league_scoring('dddd0000-0000-0000-0000-000000000001', 'balanced');
  raise exception 'A NON-OWNER CHANGED THE SCORING';
exception when others then
  if sqlerrm like '%A NON-OWNER%' then raise; end if;
  raise notice 'non-owner refused: %', sqlerrm;
end $$;

\echo '--- a bad mode is refused'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ begin
  perform public.set_league_scoring('dddd0000-0000-0000-0000-000000000001', 'easy');
  raise exception 'A NONSENSE MODE WAS ACCEPTED';
exception when others then
  if sqlerrm like '%A NONSENSE%' then raise; end if;
  raise notice 'nonsense mode refused: %', sqlerrm;
end $$;

\echo '--- bounties and combos are flat, so they are untouched by the taper'
select 'the taper only reads base points: ' ||
       case when (select bonus from public.league_leaderboard('dddd0000-0000-0000-0000-000000000002')
                  where display_name = 'BUSY') =
                 (select bonus from public.league_leaderboard('dddd0000-0000-0000-0000-000000000001')
                  where display_name = 'BUSY')
       then 'same bonus in both leagues' else 'BONUS DIFFERED' end;
