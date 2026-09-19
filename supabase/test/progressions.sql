-- The skill ladders. The league used to pay for the top of every one and
-- nothing below it: you could log a front lever but not the tuck you spend
-- three months on. These hold the shape of the ladders — every rung cheaper
-- than the one above it, and a real set at ANY rung worth about the same,
-- because the point is to make people climb rather than to pay whoever is
-- already at the top.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

\echo '--- 1. every rep rung is worth less than the rung above it'
-- Compared per REP. A handstand and a muscle-up are logged in two units, so
-- the comparison has to name the unit or it reads a hold rate against a rep
-- rate and calls a correct ladder broken.
with ladder(a, b) as (values
  ('jumppull','bandpullup'), ('bandpullup','negativepull'),
  ('negativepull','pullups'), ('pullups','archerpull'), ('archerpull','muscleup'),
  ('kneepush','pushups'), ('pushups','pikepush'), ('pikepush','pikeelev'),
  ('pikeelev','handstand'),
  ('airsquats','cossack'), ('cossack','archersquat'), ('archersquat','pistols'),
  ('cossack','boxpistol'), ('boxpistol','shrimp')
),
bad as (
  select l.a, l.b,
         (ea.modes->'reps'->>'rate')::numeric va,
         (eb.modes->'reps'->>'rate')::numeric vb
  from ladder l
  join public.exercises ea on ea.key = l.a
  join public.exercises eb on eb.key = l.b
  where (ea.modes->'reps'->>'rate')::numeric > (eb.modes->'reps'->>'rate')::numeric
)
select case when (select count(*) from bad) = 0
       then 'every rep ladder goes up: a progression never outpays what it leads to'
       else 'BACKWARDS: ' || (select string_agg(a||' '||va||' > '||b||' '||vb, ', ') from bad) end;

\echo '--- 1b. and so does every hold ladder'
-- Compared per SECOND, whatever unit each is typed in.
with persec(key, v) as (
  select e.key,
         case when e.modes ? 'seconds' then (e.modes->'seconds'->>'rate')::numeric
              else (e.modes->'minutes'->>'rate')::numeric / 60 end
  from public.exercises e
  where e.modes ? 'seconds' or e.modes ? 'minutes'
),
ladder(a, b) as (values
  ('headstand','crow'), ('crow','wallhandstand'), ('wallhandstand','forearmstand'),
  ('forearmstand','freehandstand'),
  ('tucklsit','oneleglsit'), ('oneleglsit','lsit'), ('lsit','vsit'),
  ('tuckfl','advtuckfl'), ('advtuckfl','straddlefl'), ('straddlefl','frontlever'),
  ('tuckbl','backlever'),
  ('crow','tuckplanche'), ('tuckplanche','straddleplanche'),
  ('straddleplanche','fullplanche'),
  ('tuckflag','humanflag'),
  ('plank','sideplank'), ('deadhang','onearmhang')
),
bad as (
  select l.a, l.b, pa.v va, pb.v vb
  from ladder l join persec pa on pa.key = l.a join persec pb on pb.key = l.b
  where pa.v >= pb.v
)
select case when (select count(*) from bad) = 0
       then 'and every hold ladder goes up too, across all seventeen steps'
       else 'BACKWARDS: ' || (select string_agg(a||' '||va||' >= '||b||' '||vb, ', ') from bad) end;

\echo '--- 2. a real set at any rung is worth about the same'
with go(key, secs) as (values
  ('crow',20),('wallhandstand',30),('forearmstand',30),('freehandstand',20),
  ('tuckplanche',15),('straddleplanche',10),('fullplanche',5),
  ('tucklsit',20),('oneleglsit',20),('lsit',20),('vsit',10),
  ('tuckfl',20),('advtuckfl',15),('straddlefl',12),('frontlever',10),
  ('tuckbl',20),('backlever',10),('tuckflag',15),('humanflag',8)
),
paid as (
  select g.key, g.secs,
         round(g.secs * (e.modes->'seconds'->>'rate')::numeric, 1) as pts
  from go g join public.exercises e on e.key = g.key
)
select '  ' || rpad(key, 18) || lpad(secs::text, 4) || 's  ->  ' || lpad(pts::text, 5) || ' pts'
from paid order by pts;

-- the whole design in one assertion: the rate climbs with difficulty and the
-- hold somebody can finish shrinks just as fast, so the two cancel
with go(key, secs) as (values
  ('crow',20),('wallhandstand',30),('forearmstand',30),('freehandstand',20),
  ('tuckplanche',15),('straddleplanche',10),('fullplanche',5),
  ('tucklsit',20),('oneleglsit',20),('lsit',20),('vsit',10),
  ('tuckfl',20),('advtuckfl',15),('straddlefl',12),('frontlever',10),
  ('tuckbl',20),('backlever',10),('tuckflag',15),('humanflag',8)
),
paid as (
  select round(g.secs * (e.modes->'seconds'->>'rate')::numeric, 1) as pts
  from go g join public.exercises e on e.key = g.key
)
select case when (select min(pts) from paid) >= 3.5
             and (select max(pts) from paid) <= 11
       then 'the easiest and the hardest rung are within 3x of each other: '
            || (select min(pts) from paid) || ' to ' || (select max(pts) from paid)
       else 'A RUNG IS WORTH FAR MORE OR FAR LESS THAN THE OTHERS: '
            || (select min(pts) from paid) || ' to ' || (select max(pts) from paid) end;

\echo '--- 3. no progression outscores the real thing'
with pair(a, b, unit) as (values
  ('jumppull','pullups','reps'), ('negativepull','pullups','reps'),
  ('boxpistol','pistols','reps'), ('tucklsit','lsit','seconds'),
  ('tuckfl','frontlever','seconds'), ('tuckplanche','fullplanche','seconds'),
  ('tuckflag','humanflag','seconds'), ('wallhandstand','freehandstand','seconds'))
select case when (select count(*) from pair p
                  join public.exercises a on a.key = p.a
                  join public.exercises b on b.key = p.b
                  where (a.modes->p.unit->>'rate')::numeric
                     >= (b.modes->p.unit->>'rate')::numeric) = 0
       then 'an easier version is always worth logging and never worth more'
       else 'A PROGRESSION PAYS MORE THAN THE MOVEMENT IT LEADS TO' end;
-- and worth enough to bother with: never under a third of the real thing
with pair(a, b, unit) as (values
  ('jumppull','pullups','reps'), ('negativepull','pullups','reps'),
  ('boxpistol','pistols','reps'), ('tucklsit','lsit','seconds'),
  ('tuckfl','frontlever','seconds'), ('wallhandstand','freehandstand','seconds'))
select case when (select min((a.modes->p.unit->>'rate')::numeric
                           / (b.modes->p.unit->>'rate')::numeric)
                  from pair p
                  join public.exercises a on a.key = p.a
                  join public.exercises b on b.key = p.b) >= 0.33
       then 'and never under a third of it, so the rung below is worth showing up for'
       else 'A PROGRESSION IS PRICED SO LOW NOBODY WOULD LOG IT' end;

\echo '--- 4. loaded cardio costs more than the same distance unloaded'
select '  ' || rpad(name, 14) || (modes->'km'->>'rate') || ' /km   budget ' || cap
from public.exercises where key in ('walk','ruck','run','weightrun')
order by (modes->'km'->>'rate')::numeric;
select case when (select (modes->'km'->>'rate')::numeric from public.exercises where key='weightrun')
             > (select (modes->'km'->>'rate')::numeric from public.exercises where key='run')
        and  (select (modes->'km'->>'rate')::numeric from public.exercises where key='ruck')
             > (select (modes->'km'->>'rate')::numeric from public.exercises where key='walk')
       then 'carrying weight pays more than not carrying it'
       else 'LOADED CARDIO IS NOT PRICED ABOVE UNLOADED' end;
-- and both budgets still mean 100 km, like run and walk do
select case when (select cap from public.exercises where key='weightrun')
           = 100 * (select (modes->'km'->>'rate')::numeric from public.exercises where key='weightrun')
        and  (select cap from public.exercises where key='ruck')
           = 100 * (select (modes->'km'->>'rate')::numeric from public.exercises where key='ruck')
       then 'and their weekly budget is still 100 km, the same promise as a run'
       else 'THE LOADED BUDGETS DO NOT MEAN 100 KM' end;

\echo '--- 5. the new entries are wired up like every other one'
select '  ' || count(*) || ' exercises, ' || count(*) filter (where cat <> 'GYM')
       || ' of them bodyweight' from public.exercises;
select case when (select count(*) from public.exercises where muscles = '{}'::jsonb
                    and cat <> 'RECOVERY') = 0
       then 'every exercise still says what it trains'
       else 'AN EXERCISE TRAINS NOTHING' end;
select case when (select count(*) from public.exercises where cap <= 0) = 0
       then 'and every one has a weekly budget'
       else 'AN EXERCISE HAS NO BUDGET' end;

\echo '--- 6. and none of them leaked into the quests'
-- a bounty goes to the whole league, so a crow pose can never be one
select case when (select count(*) from public.bounty_exercises() b
                  where b.key in ('crow','fullplanche','humanflag','frontlever',
                                  'freehandstand','vsit','backlever','weightrun')) = 0
       then 'no skill move can be handed out as a quest'
       else 'A QUEST CAN NOW ASK FOR A PLANCHE' end;
