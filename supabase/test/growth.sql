-- Is the thing growing, and does anybody come back.
--
-- Both answers are derived on read: there is no analytics table and nothing
-- is written when somebody opens the app. The one thing worth testing hard
-- is `landed`, because it counts rows in auth.users that have NO profile —
-- somebody who scanned the poster, saw the first screen and left — and that
-- is the only number here that can quietly become nonsense if the sign-in
-- flow ever changes.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

-- Three weeks of history, built by hand so the arithmetic is checkable.
-- The cohort joins TWO weeks ago on purpose: retention only reports a week
-- that has finished, so a cohort from last week cannot yet be judged on
-- this one — which is the point of section 6.
\set w0 '(select current_week_start())'
insert into auth.users (id, created_at) values
  -- two weeks ago: four landed, two of them went on to make a profile
  ('aa000001-0000-0000-0000-000000000001', (select current_week_start() - 14)::timestamptz + interval '2h'),
  ('aa000002-0000-0000-0000-000000000002', (select current_week_start() - 14)::timestamptz + interval '3h'),
  ('aa000003-0000-0000-0000-000000000003', (select current_week_start() - 14)::timestamptz + interval '4h'),
  ('aa000004-0000-0000-0000-000000000004', (select current_week_start() - 14)::timestamptz + interval '5h'),
  -- this week: one landed, and bounced
  ('aa000005-0000-0000-0000-000000000005', (select current_week_start())::timestamptz + interval '1h')
on conflict (id) do nothing;

insert into public.profiles (id, user_id, display_name, restore_code, created_at) values
  ('bb000001-0000-0000-0000-000000000001','aa000001-0000-0000-0000-000000000001','STAYED','GROW0001',
   (select current_week_start() - 14)::timestamptz + interval '2h'),
  ('bb000002-0000-0000-0000-000000000002','aa000002-0000-0000-0000-000000000002','LEFT','GROW0002',
   (select current_week_start() - 14)::timestamptz + interval '3h');

-- An admin to ask the questions as. Everything below is read through the
-- same `where public.is_admin()` the control room goes through.
update public.profiles set is_admin = true
 where id = 'bb000001-0000-0000-0000-000000000001';
set request.jwt.claim.sub = 'aa000001-0000-0000-0000-000000000001';

insert into public.leagues (id, name, code, owner_id)
  values ('bbbbaaaa-0000-0000-0000-00000000000a','GROWTH','GRW001',
          'bb000001-0000-0000-0000-000000000001');
insert into public.league_members (league_id, profile_id) values
  ('bbbbaaaa-0000-0000-0000-00000000000a','bb000001-0000-0000-0000-000000000001'),
  ('bbbbaaaa-0000-0000-0000-00000000000a','bb000002-0000-0000-0000-000000000002');

-- Both logged in the week they joined. Only STAYED logged the week after,
-- which is exactly the shape retention is meant to catch.
--
-- Triggers off: workouts_stamp() overwrites week_start with THIS week on
-- every insert, so a finished week cannot be written any other way. The
-- first run of this test passed while silently stamping all three rows into
-- the current week, which made both cohort members look like they came
-- back. Same idiom as season.sql, and for the same reason.
alter table public.workouts disable trigger user;
insert into public.workouts
  (profile_id, league_id, exercise_key, mode, amount, points, week_start, group_id,
   created_at)
values
  ('bb000001-0000-0000-0000-000000000001','bbbbaaaa-0000-0000-0000-00000000000a',
   'pushups','reps',20,20,(select current_week_start() - 14),'cc000001-0000-0000-0000-000000000001',
   (select current_week_start() - 14)::timestamptz + interval '12h'),
  ('bb000002-0000-0000-0000-000000000002','bbbbaaaa-0000-0000-0000-00000000000a',
   'pushups','reps',20,20,(select current_week_start() - 14),'cc000002-0000-0000-0000-000000000002',
   (select current_week_start() - 14)::timestamptz + interval '13h'),
  ('bb000001-0000-0000-0000-000000000001','bbbbaaaa-0000-0000-0000-00000000000a',
   'pushups','reps',30,30,(select current_week_start() - 7),'cc000003-0000-0000-0000-000000000003',
   (select current_week_start() - 7)::timestamptz + interval '9h');
alter table public.workouts enable trigger user;

\echo '--- 1. two weeks ago: four landed, two joined, two were active'
select 'landed ' || landed || ', joined ' || joined || ', active ' || active
       || ', workouts ' || workouts
from public.admin_growth(4) where week_start = (select current_week_start() - 14);

\echo '--- 2. this week: one landed and bounced, and nobody has logged yet'
select 'landed ' || landed || ', joined ' || joined || ', active ' || active
from public.admin_growth(4) where week_start = (select current_week_start());

\echo '--- 3. the poster conversion is joined over landed, and it is a half'
select case when (select joined::numeric / landed from public.admin_growth(4)
                   where week_start = (select current_week_start() - 14)) = 0.5
       then 'two of the four who landed that week typed a name'
       else 'THE CONVERSION RATE IS WRONG' end;

\echo '--- 4. a landing with no profile behind it is the whole point'
-- If create_profile ever starts running at boot, this is the test that goes
-- red, and the conversion column stops meaning anything the moment it does.
select case when (select landed from public.admin_growth(4)
                   where week_start = (select current_week_start()))
          > (select joined from public.admin_growth(4)
                   where week_start = (select current_week_start()))
       then 'somebody can open the app without costing a seat'
       else 'EVERY LANDING IS NOW A PROFILE — THE CAP WILL BURN' end;

\echo '--- 5. retention: of that week''s two, exactly one came back'
-- The half that matters. Both logged in the week they joined; only STAYED
-- logged in the week after, and a cohort of 2 with back_1 of 2 would mean
-- the fixture was stamped into one week rather than two.
select case when size = 2 and back_1 = 1
            then 'cohort of 2, one of them came back the following week'
            else 'RETENTION IS WRONG: cohort ' || size || ', back ' ||
                 coalesce(back_1::text, 'null') end
from public.admin_retention(4) where week_start = (select current_week_start() - 14);

\echo '--- 6. the week in progress is null, not zero'
-- back_2 for this cohort lands on the CURRENT week. On a Tuesday that is one
-- day of evidence, and reporting it as 0 would make every recent cohort look
-- like a disaster. It has to come back blank until the week is over.
select case when (select back_2 from public.admin_retention(4)
                   where week_start = (select current_week_start() - 14)) is null
       then 'the week still being played is left blank rather than called zero'
       else 'THE WEEK IN PROGRESS IS BEING REPORTED AS NOBODY CAME BACK' end;

\echo '--- 6b. and so is last week''s cohort, judged on a week one day old'
select case when (select back_1 from public.admin_retention(4)
                   where week_start = (select current_week_start() - 7)) is null
       then 'a cohort that arrived last week is not yet judged on this one'
       else 'A COHORT IS BEING JUDGED ON AN UNFINISHED WEEK' end;

\echo '--- 7. the window is a window'
select 'asking for six weeks gives ' || count(*) || ' rows'
from public.admin_growth(6);

\echo '--- 8. and none of it is readable by somebody who is not an admin'
update public.profiles set is_admin = false
 where id = 'bb000001-0000-0000-0000-000000000001';
select case when (select count(*) from public.admin_growth(12)) = 0
             and (select count(*) from public.admin_retention(12)) = 0
       then 'a player sees nothing at all, not even the week count'
       else 'A PLAYER CAN READ THE GROWTH NUMBERS' end;

reset role;
