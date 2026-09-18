-- The gym formula. A 50 kg member benched 35 kg, got 8.75 points, and asked
-- why it was barely more than a push-up. It was right — at 50 kg a push-up
-- already moves 32 kg. But looking turned up three lifts where ADDING WEIGHT
-- made a movement score LESS, because the number typed into a weighted dip is
-- what hangs from the belt and the formula was reading it as the whole load.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

\echo '--- 1. the bench that started it: 50 kg lifter, 35 kg bar'
select '  35 kg x 8 reps = ' || public.calc_points('gymbench','reps',8,50,35) || ' points';
select case when public.calc_points('gymbench','reps',8,50,35) = 8.75
       then 'which is what he was given, so the arithmetic is not the problem'
       else 'THE BENCH NUMBER MOVED' end;
-- a push-up moves 0.64 of bodyweight; at 50 kg that is 32 kg, so a 32 kg bench
-- has to pay exactly what a push-up pays and not a fraction more
select case when public.calc_points('gymbench','reps',100,50,32)
          =  100 * (select (modes->'reps'->>'rate')::numeric
                    from public.exercises where key = 'pushups')
       then 'and benching your own push-up (32 kg at 50 kg) pays a push-up exactly'
       else 'THE BENCH AND THE PUSH-UP NO LONGER MEET' end;

\echo '--- 2. adding weight can never make a movement worth less'
-- the bug: a weighted dip with 20 kg on the belt paid 0.45/rep against 1.50
-- for the same rep with no belt, because the lifter''s own body vanished
select '  ' || rpad(g.name, 22) || ' 0 kg -> '
       || lpad(round(public.calc_points(g.key,'reps',1,70,0), 3)::text, 6)
       || '   20 kg -> '
       || lpad(round(public.calc_points(g.key,'reps',1,70,20), 3)::text, 6)
       || '   (' || b.name || ' alone ' || (b.modes->'reps'->>'rate') || ')'
from (values ('gymdip','dips'), ('gymweightpull','pullups'), ('gymcalf','calves'))
       v(gk, bk)
join public.exercises g on g.key = v.gk
join public.exercises b on b.key = v.bk;

select case when (select bool_and(
         public.calc_points(v.gk,'reps',1,70,20) > public.calc_points(v.gk,'reps',1,70,0)
         and public.calc_points(v.gk,'reps',1,70,0) > 0)
       from (values ('gymdip'),('gymweightpull'),('gymcalf')) v(gk))
       then 'every belt lift now pays more with weight than without'
       else 'ADDING WEIGHT STILL MAKES A LIFT WORTH LESS' end;

-- and with an empty belt it must equal the bodyweight movement EXACTLY, or
-- there is a cheaper way to log the very same rep
select case when (select bool_and(
         abs(public.calc_points(v.gk,'reps',1,70,0)
             - (select (modes->'reps'->>'rate')::numeric
                from public.exercises where key = v.bk)) < 0.005)
       from (values ('gymdip','dips'),('gymweightpull','pullups'),
                    ('gymcalf','calves')) v(gk, bk))
       then 'and with nothing on the belt it is the bodyweight movement, to the point'
       else 'THE TWO WAYS OF LOGGING ONE REP DISAGREE' end;

\echo '--- 3. it holds at every bodyweight, not just 70 kg'
select case when (select bool_and(
         public.calc_points(v.gk,'reps',1,bw,10) > public.calc_points(v.gk,'reps',1,bw,0))
       from (values ('gymdip'),('gymweightpull'),('gymcalf'),('gymbackext')) v(gk),
            generate_series(40, 140, 10) bw)
       then 'from 40 kg to 140 kg, one more kilo is always one more point'
       else 'IT INVERTS AT SOME BODYWEIGHT' end;

\echo '--- 4. the standing leg lifts kept the 0.85 they always had'
select case when public.calc_points('gymsquat','reps',1,70,60) = round(0.588 * (0.85 + 60/70.0), 2)
       then 'a back squat is priced exactly as it was before'
       else 'THE SQUAT MOVED' end;
select '  60 kg back squat at 70 kg bodyweight = '
       || public.calc_points('gymsquat','reps',1,70,60) || ' /rep (air squat 0.5)';

\echo '--- 5. a bodyweight-only entry still scores'
-- a hyperextension with no plate held is real work; it lands beside supermans
select '  back extension, no plate = ' || public.calc_points('gymbackext','reps',1,70,0)
       || ' /rep (supermans 0.25)';
select case when public.calc_points('gymbackext','reps',1,70,0) > 0
       then 'holding no plate is not zero points'
       else 'A BODYWEIGHT GYM LIFT SCORES NOTHING' end;

\echo '--- 6. the gym can now reach every region on the figure'
-- forearms and lower back had no gym lift that led with them, so a gym-only
-- member could not fill two of the fourteen however hard they trained
with lead as (
  select m.key, m.name,
         max((e.muscles->>m.key)::numeric) as best
  from public.muscles m
  cross join public.exercises e
  where e.cat = 'GYM' and e.muscles ? m.key
  group by 1, 2)
select case when (select count(*) from lead where best < 0.4) = 0
       then 'every one of the fourteen has a gym lift that leads with it'
       else 'STILL UNREACHABLE: ' ||
            (select string_agg(name, ', ') from lead where best < 0.4) end;
select '  gym lifts: ' || count(*) from public.exercises where cat = 'GYM';

\echo '--- 7. nothing about a bodyweight exercise changed'
select case when (select count(*) from public.exercises
                  where cat <> 'GYM' and modes ? 'reps'
                    and (modes->'reps'->>'rate') is null) = 0
       then 'every non-gym exercise still has a plain rate'
       else 'A BODYWEIGHT EXERCISE LOST ITS RATE' end;
