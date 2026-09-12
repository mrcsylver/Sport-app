-- =====================================================================
--  IRON LEAGUE — Supabase database schema
-- ---------------------------------------------------------------------
--  HOW TO USE THIS FILE (no coding knowledge needed):
--    1. Open your project on supabase.com
--    2. Click "SQL Editor" in the left sidebar
--    3. Click "New query"
--    4. Copy EVERYTHING in this file, paste it, press RUN
--    5. You should see "Success. No rows returned"
--
--  You can safely run this file again later: it cleans up after itself
--  before recreating everything.
--
--  >>> TIMEZONE <<<
--  The weekly scoring window ends every SUNDAY at 23:59 in the timezone
--  set below. Change 'Europe/Paris' to your own timezone if needed
--  (e.g. 'America/New_York', 'Europe/London'), in the app_timezone()
--  function a few lines down AND in config.js of the website.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Clean slate (safe to re-run)
-- ---------------------------------------------------------------------
drop table if exists public.bounties       cascade;
drop table if exists public.exercises      cascade;
drop table if exists public.muscles        cascade;
drop table if exists public.raids          cascade;
drop table if exists public.challenges     cascade;
drop table if exists public.workouts       cascade;
drop table if exists public.league_members cascade;
drop table if exists public.bounty_schedule cascade;
drop table if exists public.leagues        cascade;
drop table if exists public.profiles       cascade;

drop function if exists public.accept_challenge(p_code text) cascade;
drop function if exists public.app_timezone() cascade;
drop function if exists public.bounty_date(p_week date) cascade;
drop function if exists public.bounty_done(p_profile uuid, p_league uuid, p_spec jsonb, p_day date) cascade;
drop function if exists public.bounty_dow() cascade;
drop function if exists public.bounty_index(p_week date) cascade;
drop function if exists public.bounty_pick(p_week date) cascade;
drop function if exists public.bounty_cat_points(p_profile uuid, p_league uuid, p_cat text, p_day date) cascade;
drop function if exists public.builtin_bounty_count() cascade;
drop function if exists public.bounty_open_to_all(p_key text) cascade;
drop function if exists public.bounty_exercises() cascade;
drop function if exists public.admin_schedule() cascade;
drop function if exists public.admin_bounties() cascade;
drop function if exists public.admin_pin_bounty(p_week date, p_idx int, p_note text) cascade;
drop function if exists public.admin_unpin_bounty(p_week date) cascade;
drop function if exists public.admin_add_bounty(p_name text, p_descr text, p_points numeric, p_ex text, p_mode text, p_min numeric, p_from_h int, p_to_h int) cascade;
drop function if exists public.admin_delete_bounty(p_idx int) cascade;
drop function if exists public.bounty_req(p_profile uuid, p_league uuid, p_req jsonb, p_day date) cascade;
drop function if exists public.calc_points(p_key text, p_mode text, p_amount numeric) cascade;
drop function if exists public.calc_points(p_key text, p_mode text, p_amount numeric, p_bw numeric, p_load numeric) cascade;
drop function if exists public.cancel_challenge(p_id uuid) cascade;
drop function if exists public.challenge_points(p_league uuid, p_profile uuid, p_from timestamptz, p_to timestamptz) cascade;
drop function if exists public.challenge_preview(p_code text) cascade;
drop function if exists public.challenge_status(p_cancelled timestamptz, p_accepted timestamptz, p_ends timestamptz, p_created timestamptz) cascade;
drop function if exists public.combo_threshold() cascade;
drop function if exists public.create_challenge(p_league uuid) cascade;
drop function if exists public.create_league(p_name text) cascade;
drop function if exists public.create_profile(p_name text) cascade;
drop function if exists public.current_bounty(p_league uuid) cascade;
drop function if exists public.current_week_start() cascade;
drop function if exists public.enforce_league_capacity() cascade;
drop function if exists public.exercise_category(p_key text) cascade;
drop function if exists public.has_open_challenge(p_profile uuid) cascade;
drop function if exists public.is_member(p_league uuid) cascade;
drop function if exists public.is_rest_day(p_league uuid) cascade;
drop function if exists public.is_catchup_day(p_league uuid) cascade;
drop function if exists public.catchup_multiplier(p_league uuid, p_profile uuid) cascade;
drop function if exists public.catchup_floor() cascade;
drop function if exists public.catchup_ceiling() cascade;
drop function if exists public.catchup_max() cascade;
drop function if exists public.join_league_by_code(p_code text) cascade;
drop function if exists public.league_leaderboard(p_league uuid, p_week date) cascade;
drop function if exists public.league_preview(p_code text) cascade;
drop function if exists public.leave_league(p_league uuid) cascade;
drop function if exists public.log_workout(p_league uuid, p_key text, p_mode text, p_amount numeric) cascade;
drop function if exists public.log_workout(p_league uuid, p_key text, p_mode text, p_amount numeric, p_bw numeric, p_load numeric) cascade;
drop function if exists public.my_challenges() cascade;
drop function if exists public.my_duel_record(p_league uuid) cascade;
drop function if exists public.my_combo_today(p_league uuid) cascade;
drop function if exists public.my_leagues() cascade;
drop function if exists public.my_profile_id() cascade;
drop function if exists public.my_stats(p_league uuid, p_all boolean) cascade;
drop function if exists public.rename_profile(p_name text) cascade;
drop function if exists public.rest_day_check(p_profile uuid, p_league uuid, p_key text, p_at timestamptz, p_exclude uuid) cascade;
drop function if exists public.restore_profile(p_code text) cascade;
drop function if exists public.set_avatar(p_avatar text) cascade;
drop function if exists public.set_bodyweight(p_kg numeric) cascade;
drop function if exists public.set_units(p_units text) cascade;
drop function if exists public.set_body_form(p_form text) cascade;
drop function if exists public.muscle_charge(p_points numeric, p_target numeric) cascade;
drop function if exists public.my_muscles(p_league uuid, p_all boolean) cascade;
drop function if exists public.muscle_dose(p_profile uuid) cascade;
drop function if exists public.league_wins(p_league uuid) cascade;
drop function if exists public.league_champions(p_league uuid) cascade;
drop function if exists public.set_banner(p_banner text) cascade;
drop function if exists public.set_name_color(p_color text) cascade;
drop function if exists public.current_raid(p_league uuid) cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.admin_leagues() cascade;
drop function if exists public.admin_players() cascade;
drop function if exists public.admin_delete_league(p_league uuid) cascade;
drop function if exists public.admin_delete_profile(p_profile uuid) cascade;
drop function if exists public.league_streaks(p_league uuid, p_min numeric) cascade;
drop function if exists public.set_pinned_badges(p_keys text[]) cascade;
drop function if exists public.my_badges(p_league uuid) cascade;
drop function if exists public.league_rivalries(p_league uuid, p_week date) cascade;
drop function if exists public.delete_league(p_league uuid) cascade;
drop function if exists public.set_league_settings(p_league uuid, p_rest_dow int[], p_season_weeks int) cascade;
drop function if exists public.set_league_settings(p_league uuid, p_rest_dow int[], p_season_weeks int, p_catchup_dow int) cascade;
drop function if exists public.set_league_badge(p_league uuid, p_badge jsonb) cascade;
drop function if exists public.shares_league_with(p_profile uuid) cascade;
drop function if exists public.week_bounty_points(p_league uuid, p_week date) cascade;
drop function if exists public.week_combo_bonus(p_league uuid, p_week date) cascade;
drop function if exists public.weekly_history(p_league uuid) cascade;
drop function if exists public.workouts_stamp() cascade;
drop function if exists public.workouts_update_guard() cascade;

-- These functions call each other in both directions, and two of them read
-- tables created further down. Postgres resolves a SQL function body at the
-- moment the function is created, so a strict run would stop at the first
-- forward reference and the file would only work if it were sorted into an
-- order no human could maintain. Turning that one check off for the length of
-- the script is what makes it runnable top to bottom on a fresh database —
-- every body is still parsed, so a typo is still an error.
set check_function_bodies = off;

-- ---------------------------------------------------------------------
-- 1. Timezone + week helpers
-- ---------------------------------------------------------------------

-- >>> CHANGE YOUR TIMEZONE HERE <<<
create function public.app_timezone() returns text
language sql immutable set search_path = public as $$ select 'Europe/Paris'::text $$;

-- A "week" runs Monday 00:00 -> Sunday 23:59:59 in the timezone above.
-- This returns the Monday that the current week started on.
create function public.current_week_start() returns date
language sql stable set search_path = public as $$
  select (date_trunc('week', (now() at time zone public.app_timezone())))::date
$$;

-- Sunday is a rest day. The competition runs Monday 00:00 -> Saturday 23:59;
-- on Sunday the only thing that counts is one stretching session, and nothing
-- can be edited or deleted, so Saturday night's standings are final. The week
-- itself is unchanged and still settles Sunday 23:59.
create function public.is_rest_day(p_league uuid default null)
returns boolean language sql stable set search_path = public as $$
  -- Rest days are a league setting. The no-argument call still means Sunday,
  -- so anything that has not been told about leagues keeps working.
  select extract(isodow from (now() at time zone public.app_timezone()))::int =
         any (coalesce((select rest_dow from public.leagues where id = p_league), '{7}'::int[]))
$$;

-- ---------------------------------------------------------------------
-- 1b. The catch-up day
-- ---------------------------------------------------------------------
-- One day a week where being behind is worth something. Everything logged
-- that day is multiplied by how far off the lead you are, so a person who
-- missed three days has a reason to turn up rather than write the week off.
--
-- It is deliberately not a handicap: the leader still trains and still
-- scores, they simply score at 1.0 like anybody within touching distance.
-- Nobody loses anything, and the most it can be worth is 40 per cent.

-- Under this many points behind, you are close enough that you do not need it.
create function public.catchup_floor()   returns numeric
language sql immutable set search_path = public as $$ select 150::numeric $$;
-- At this many behind and beyond, the multiplier is at its maximum.
create function public.catchup_ceiling() returns numeric
language sql immutable set search_path = public as $$ select 500::numeric $$;
create function public.catchup_max()     returns numeric
language sql immutable set search_path = public as $$ select 1.40::numeric $$;

create function public.is_catchup_day(p_league uuid) returns boolean
language sql stable set search_path = public as $$
  select coalesce(
    (select l.catchup_dow from public.leagues l where l.id = p_league)
      = extract(isodow from (now() at time zone public.app_timezone()))::int,
    false)
$$;

-- How much this person's work is worth today, in this league. Straight line
-- from 1.0 at the floor to the maximum at the ceiling.
create function public.catchup_multiplier(p_league uuid, p_profile uuid)
returns numeric language sql stable set search_path = public as $$
  with tot as (
    select w.profile_id, coalesce(sum(w.points), 0) as p
    from public.workouts w
    where w.league_id = p_league
      and w.week_start = public.current_week_start()
    group by 1),
  best as (select coalesce(max(p), 0) as top from tot),
  mine as (select coalesce((select p from tot where profile_id = p_profile), 0) as p),
  gap  as (select greatest((select top from best) - (select p from mine), 0) as g)
  select round(
    1 + (public.catchup_max() - 1)
        * least(greatest((select g from gap) - public.catchup_floor(), 0)
                / (public.catchup_ceiling() - public.catchup_floor()), 1)
  , 2)
$$;

-- Raises if an entry breaks the rest day rule. p_at is the day the entry
-- belongs to, so an edit is judged on its own date, not on today.
create function public.rest_day_check(
  p_profile uuid, p_league uuid, p_key text, p_at timestamptz, p_exclude uuid)
returns void language plpgsql stable set search_path = public as $$
declare
  tz   text := public.app_timezone();
  dows int[] := coalesce((select rest_dow from public.leagues where id = p_league), '{7}'::int[]);
  d    date;
begin
  if not (extract(isodow from (p_at at time zone tz))::int = any (dows)) then return; end if;
  if p_key <> 'stretch' then raise exception 'REST_DAY'; end if;
  d := (p_at at time zone tz)::date;
  if exists (
    select 1 from public.workouts w
    where w.profile_id = p_profile
      and w.league_id  = p_league
      and (w.created_at at time zone tz)::date = d
      and (p_exclude is null or w.id <> p_exclude)
  ) then
    raise exception 'REST_DAY_DONE';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 2. Points engine  (must stay in sync with EXERCISES in app.js)
-- ---------------------------------------------------------------------
-- Every exercise the app knows, and what a unit of it is worth. Rates live
-- here rather than in a CASE so the client and the scorer read one table, and
-- so adding an exercise is data, not a code change. Regenerate the seed at the
-- bottom of this file with tools/build_exercises.py — never edit it by hand.
create table public.exercises (
  key      text primary key,
  name     text not null,
  cat      text not null,
  variants text not null default '',
  aliases  text not null default '',
  sort     int  not null default 100,
  modes    jsonb not null,
  -- what the movement trains, as a share of the points it scores, adding to
  -- 1. Recovery trains nothing and carries {}.
  muscles  jsonb not null default '{}'::jsonb
);
alter table public.exercises enable row level security;
create policy exercises_read on public.exercises for select to authenticated using (true);

-- The fourteen regions the figure is drawn from. `target` is a week's work on
-- that region in points, scaled by how much of you it is: a hundred points of
-- calf raises should not read like a hundred points of squats. `view` says
-- which side of the figure it appears on; four of them appear on both.
create table public.muscles (
  key    text primary key,
  name   text not null,
  view   text not null check (view in ('front','back','both')),
  target int  not null check (target > 0),
  sort   int  not null default 0
);
alter table public.muscles enable row level security;
create policy muscles_read on public.muscles for select to authenticated using (true);

create function public.calc_points(
  p_key text, p_mode text, p_amount numeric,
  p_bw numeric default null, p_load numeric default null)
returns numeric language sql stable set search_path = public as $$
  with e as (
    select x.cat, x.modes -> p_mode as m
    from public.exercises x where x.key = p_key
  )
  select round(coalesce(
    case
      -- Gym: points/rep = k x R, where R = (load x equip [+ 0.85 BW]) / bodyweight.
      -- R is the same "fraction of bodyweight moved" that prices calisthenics,
      -- so a bench at 64% of your weight scores like a push-up. Legs add the
      -- lifter's own mass, which rides above the bar on a squat but not on a
      -- seated machine.
      when (select cat from e) = 'GYM' then
        case
          when p_bw is null or p_bw < 30 or p_bw > 250 then 0
          when p_load is null or p_load < 0 or p_load > 500 then 0
          else p_amount * (select (m->>'k')::numeric from e)
               * ( ( p_load * (select (m->>'equip')::numeric from e)
                     + case when (select m->>'legs' from e) = 'true'
                            then 0.85 * p_bw else 0 end )
                   / p_bw )
        end
      else p_amount * (select (m->>'rate')::numeric from e)
    end, 0), 2)
$$;

-- Muscle group of an exercise (used by the stats tab).
create or replace function public.exercise_category(p_key text) returns text
language sql stable set search_path = public as $$
  -- Menu grouping is not training grouping: a bench press trains PUSH and a
  -- football match is cardio, so combos and the stats bars stay at five groups
  -- however many menu sections exist. Mirrors trainingCat() in app.js.
  select case
    when x.cat = 'GYM'   then upper(x.modes -> 'reps' ->> 'pattern')
    when x.cat = 'SPORT' then 'CARDIO'
    else x.cat
  end
  from public.exercises x where x.key = p_key
$$;


-- ---------------------------------------------------------------------
-- 3. Tables
-- ---------------------------------------------------------------------

-- One row per athlete. There is no password: the app signs each device in
-- anonymously, and the profile is attached to that anonymous account.
-- restore_code lets someone move their profile to a new phone.
create table public.profiles (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null
                 check (char_length(btrim(display_name)) between 2 and 18),
  restore_code text not null unique
                 default upper(substr(md5(gen_random_uuid()::text), 1, 8)),
  -- "gi:<icon>|c=<colour>|p=<emoji>": an emblem, its tint, and an optional
  -- emoji pinned to it. A bare emoji (what people picked first) still parses.
  avatar       text check (avatar is null or char_length(avatar) between 1 and 80),
  -- only used to score gym lifts; never shown to anyone else
  bodyweight   numeric constraint profiles_bw_sane
                 check (bodyweight is null or bodyweight between 30 and 250),
  -- which silhouette the muscle figure is drawn as. It changes the drawing
  -- and nothing else: no score, no target and no ranking reads it.
  body_form    text not null default 'neutral'
                 constraint profiles_body_form_check
                 check (body_form in ('masc','fem','neutral')),
  -- what a person types weights in; storage is always kilos
  units        text not null default 'kg'
                 constraint profiles_units_check check (units in ('kg','lb')),
  -- name of a banner skin; the look itself is CSS, so nothing is stored but a word
  banner       text constraint profiles_banner_check
                 check (banner is null or char_length(banner) between 1 and 24),
  -- which badges to wear on the board, in order, at most three
  -- chosen text colour for the name, so a banner never swallows it
  name_color   text constraint profiles_name_color_check
                 check (name_color is null or char_length(name_color) <= 16),
  -- admin is a flag the DATABASE checks inside every admin function; no
  -- service key ever reaches a browser
  is_admin     boolean not null default false,
  pinned_badges text[] not null default '{}'
                 constraint profiles_pinned_sane
                 check (array_length(pinned_badges, 1) is null
                        or array_length(pinned_badges, 1) <= 3),
  created_at   timestamptz not null default now()
);

create table public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 2 and 28),
  code        text not null unique
                default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  -- 36, not a round number: the divisions come to exactly this, and an even
  -- league is what lets the Monday rivalry pair everybody off without
  -- leaving one person without an opponent.
  max_members int  not null default 36 check (max_members between 2 and 36),
  -- composable crest: {"shape":..,"color":..,"emblem":..}; null falls back to
  -- one derived from the league id, so every league looks distinct from day one
  badge       jsonb,
  -- which weekdays this league rests on (ISO 1=Mon … 7=Sun); empty = never
  rest_dow    int[] not null default '{7}',
  -- how long a season runs; null means it just keeps going
  season_weeks int constraint leagues_season_sane
                 check (season_weeks is null or season_weeks between 1 and 26),
  -- one day a week where being behind is worth something: everything logged
  -- that day is multiplied by how far off the lead you are. Null means the
  -- league does not have one, which is what every league is now.
  catchup_dow  int constraint leagues_catchup_sane
                 check (catchup_dow is null or catchup_dow between 1 and 7),
  created_at  timestamptz not null default now()
);

create table public.league_members (
  league_id  uuid not null references public.leagues(id)  on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (league_id, profile_id)
);

-- One row per league. A single log action writes one row into every league
-- the athlete belongs to at that moment; those rows share a group_id so an
-- edit or a delete moves them together. Joining a league later never
-- back-fills older workouts, so everyone still starts at zero.
create table public.workouts (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid    not null default gen_random_uuid(),
  league_id     uuid    not null references public.leagues(id)  on delete cascade,
  profile_id    uuid    not null references public.profiles(id) on delete cascade,
  exercise_key  text    not null,
  mode          text    not null
                  check (mode in ('reps','seconds','minutes','km','flat')),
  amount        numeric not null check (amount > 0 and amount <= 100000),
  points        numeric not null default 0,
  -- what a gym set was actually done with, so an edit can rescore it
  bodyweight    numeric,
  load          numeric,
  week_start    date    not null default current_date,
  created_at    timestamptz not null default now(),
  -- what the catch-up day multiplied this by, stamped at the moment it was
  -- logged so it can never change afterwards. 1 on every other day.
  boost         numeric not null default 1 check (boost between 1 and 3)
);

-- A duel is 24 hours, one on one, inside a league you both belong to. It
-- stores no workouts of its own: it reads what you already logged for the
-- league inside its window, so nothing is ever entered twice.
create table public.challenges (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique
                  default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  league_id     uuid not null references public.leagues(id)  on delete cascade,
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id   uuid          references public.profiles(id) on delete cascade,
  created_at    timestamptz not null default now(),
  accepted_at   timestamptz,
  ends_at       timestamptz,
  cancelled_at  timestamptz,
  constraint no_self_duel check (opponent_id is null or opponent_id <> challenger_id)
);
create index challenges_league_idx on public.challenges (league_id);

-- One side quest per week, always on the same weekday. Everyone who does it
-- scores; the first to finish also takes a badge worth nothing. Completion is
-- read from the workouts already logged, so there is nothing to claim.
-- A raid is one target the whole league carries together for a week. The
-- target scales with headcount, so a group of 8 and a group of 28 both get
-- something that needs everybody rather than one strong person.
-- per_member is calibrated at roughly 1.5x what a league actually produces:
-- a raid nobody can reach is a raid nobody tries. Retune with one UPDATE.
create table public.raids (
  idx        int primary key,
  name       text not null,
  descr      text not null,
  ex_keys    text[] not null,
  mode       text not null,
  per_member numeric not null,
  unit       text not null
);
alter table public.raids enable row level security;
create policy raids_read on public.raids for select to authenticated using (true);

create table public.bounties (
  idx    int primary key,
  name   text    not null,
  descr  text    not null,
  points numeric not null check (points > 0),
  spec   jsonb   not null
);

-- Which bounty runs in a given week is normally a shuffle of the pool (see
-- bounty_index below). A row here overrides that for one week — the control
-- room's way of putting a chosen quest on a chosen date.
create table public.bounty_schedule (
  week_start date primary key,
  bounty_idx int  not null references public.bounties(idx) on delete cascade,
  note       text,
  set_at     timestamptz not null default now()
);
alter table public.bounty_schedule enable row level security;
create policy bounty_schedule_read on public.bounty_schedule
  for select to authenticated using (true);
create index challenges_ppl_idx    on public.challenges (challenger_id, opponent_id);

create index workouts_board_idx on public.workouts (league_id, week_start);
create index workouts_group_idx on public.workouts (group_id);
create index workouts_feed_idx  on public.workouts (profile_id, week_start);
create index members_profile_idx on public.league_members (profile_id);

-- ---------------------------------------------------------------------
-- 4. Triggers: the server (not the phone) decides points and the week
-- ---------------------------------------------------------------------
create or replace function public.workouts_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  new.created_at := now();
  new.week_start := public.current_week_start();
  perform public.rest_day_check(new.profile_id, new.league_id,
                                new.exercise_key, new.created_at, null);
  if public.is_rest_day(new.league_id) then
    new.amount := 1;                       -- one session, no stacking
  end if;
  new.points := public.calc_points(new.exercise_key, new.mode, new.amount,
                                   new.bodyweight, new.load);
  -- On a catch-up day, what this is worth depends on how far behind you were
  -- when you logged it. Stamped now, so it never changes afterwards and the
  -- board never re-reads it: two people logging the same set an hour apart
  -- can legitimately score differently, and both keep what they earned.
  if public.is_catchup_day(new.league_id) then
    new.boost  := public.catchup_multiplier(new.league_id, new.profile_id);
    new.points := round(new.points * new.boost, 2);
  end if;
  if new.points <= 0 then
    if (select cat = 'GYM' from public.exercises where key = new.exercise_key) then
      raise exception 'A gym lift needs your bodyweight (30-250 kg) and the weight lifted (0-500 kg)';
    end if;
    raise exception 'Unknown exercise or unit (% / %)', new.exercise_key, new.mode;
  end if;
  return new;
end $$;

create trigger workouts_stamp_trg
  before insert on public.workouts
  for each row execute function public.workouts_stamp();

-- Entries stay correctable while their week is running and freeze afterwards.
-- An edit may change the numbers only, never the owner, league, or week.
create or replace function public.workouts_update_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if old.week_start <> public.current_week_start() then
    raise exception 'WEEK_CLOSED';
  end if;
  new.id         := old.id;
  new.profile_id := old.profile_id;
  new.league_id  := old.league_id;
  new.created_at := old.created_at;
  new.week_start := old.week_start;
  perform public.rest_day_check(new.profile_id, new.league_id,
                                new.exercise_key, old.created_at, old.id);
  if extract(isodow from (old.created_at at time zone public.app_timezone())) = 7 then
    new.amount := 1;
  end if;
  -- An edit rescores the row, and it has to rescore it the way the row was
  -- written: the catch-up multiplier belongs to the moment it was logged, so
  -- it rides through an edit rather than being recalculated or dropped.
  -- Recomputing without it quietly took forty per cent off anybody who fixed
  -- a typo in a set they logged on a catch-up day.
  new.boost  := old.boost;
  new.points := round(public.calc_points(new.exercise_key, new.mode, new.amount,
                                         new.bodyweight, new.load) * old.boost, 2);
  if new.points <= 0 then
    if (select cat = 'GYM' from public.exercises where key = new.exercise_key) then
      raise exception 'A gym lift needs your bodyweight (30-250 kg) and the weight lifted (0-500 kg)';
    end if;
    raise exception 'Unknown exercise or unit (% / %)', new.exercise_key, new.mode;
  end if;
  return new;
end $$;

create trigger workouts_update_guard_trg
  before update on public.workouts
  for each row execute function public.workouts_update_guard();

-- Hard cap on league size (default 20).
create or replace function public.enforce_league_capacity() returns trigger
language plpgsql set search_path = public as $$
declare
  cap int;
  taken int;
begin
  select max_members into cap from public.leagues where id = new.league_id for update;
  if cap is null then
    raise exception 'League not found';
  end if;
  select count(*) into taken from public.league_members where league_id = new.league_id;
  if taken >= cap then
    raise exception 'LEAGUE_FULL';
  end if;
  return new;
end $$;

create trigger league_capacity_trg
  before insert on public.league_members
  for each row execute function public.enforce_league_capacity();

-- ---------------------------------------------------------------------
-- 5. Identity helpers (security definer so RLS can use them safely)
-- ---------------------------------------------------------------------
create function public.my_profile_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.profiles where user_id = auth.uid() limit 1
$$;

create function public.is_member(p_league uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.league_members m
    where m.league_id = p_league
      and m.profile_id = (select id from public.profiles where user_id = auth.uid())
  )
$$;

-- True when the given profile is in at least one league with me.
create function public.shares_league_with(p_profile uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.league_members mine
    join public.league_members theirs on theirs.league_id = mine.league_id
    where mine.profile_id = (select id from public.profiles where user_id = auth.uid())
      and theirs.profile_id = p_profile
  )
$$;

-- ---------------------------------------------------------------------
-- 6. Row Level Security — everyone only sees the leagues they belong to
-- ---------------------------------------------------------------------
alter table public.profiles       enable row level security;
alter table public.leagues        enable row level security;
alter table public.league_members enable row level security;
alter table public.workouts       enable row level security;
alter table public.challenges     enable row level security;
alter table public.bounties       enable row level security;

-- profiles: you can read your own, plus anyone you share a league with.
create policy profiles_read on public.profiles for select to authenticated
  using (user_id = auth.uid() or public.shares_league_with(id));
create policy profiles_insert on public.profiles for insert to authenticated
  with check (user_id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- leagues: only visible to members (joining happens through join_league_by_code)
create policy leagues_read on public.leagues for select to authenticated
  using (public.is_member(id) or owner_id = public.my_profile_id());
create policy leagues_update on public.leagues for update to authenticated
  using (owner_id = public.my_profile_id())
  with check (owner_id = public.my_profile_id());

create policy members_read on public.league_members for select to authenticated
  using (public.is_member(league_id));
create policy members_delete on public.league_members for delete to authenticated
  using (profile_id = public.my_profile_id());

-- workouts: read every log of every league you are in, write only your own.
create policy workouts_read on public.workouts for select to authenticated
  using (public.is_member(league_id));
create policy workouts_insert on public.workouts for insert to authenticated
  with check (profile_id = public.my_profile_id() and public.is_member(league_id));
create policy workouts_delete on public.workouts for delete to authenticated
  using (profile_id = public.my_profile_id()
         and week_start = public.current_week_start()
         and not public.is_rest_day());
create policy workouts_update on public.workouts for update to authenticated
  using      (profile_id = public.my_profile_id()
              and week_start = public.current_week_start()
              and not public.is_rest_day())
  with check (profile_id = public.my_profile_id());

create policy bounties_read on public.bounties for select to authenticated using (true);

create policy challenges_read on public.challenges for select to authenticated
  using (challenger_id = public.my_profile_id() or opponent_id = public.my_profile_id());

-- ---------------------------------------------------------------------
-- 7. The API the app calls
-- ---------------------------------------------------------------------

-- Sign-up: pick a display name. Called once per device/account.
create function public.create_profile(p_name text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles;
begin
  if auth.uid() is null then raise exception 'NOT_SIGNED_IN'; end if;
  select * into p from public.profiles where user_id = auth.uid();
  if found then return p; end if;
  insert into public.profiles (user_id, display_name)
  values (auth.uid(), btrim(p_name))
  returning * into p;
  return p;
end $$;

create function public.rename_profile(p_name text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles;
begin
  update public.profiles set display_name = btrim(p_name)
  where user_id = auth.uid() returning * into p;
  if not found then raise exception 'NO_PROFILE'; end if;
  return p;
end $$;

-- Moving to a new phone: type your restore code, get your profile back.
create function public.restore_profile(p_code text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  target   public.profiles;
  existing public.profiles;
  logs     int;
begin
  if auth.uid() is null then raise exception 'NOT_SIGNED_IN'; end if;

  select * into target from public.profiles
   where restore_code = upper(btrim(p_code));
  if not found then raise exception 'BAD_CODE'; end if;
  if target.user_id = auth.uid() then return target; end if;

  -- If this device already made a throwaway profile, drop it (only if unused).
  select * into existing from public.profiles where user_id = auth.uid();
  if found then
    select count(*) into logs from public.workouts where profile_id = existing.id;
    if logs > 0 then raise exception 'DEVICE_HAS_DATA'; end if;
    delete from public.profiles where id = existing.id;
  end if;

  update public.profiles set user_id = auth.uid()
   where id = target.id returning * into target;
  return target;
end $$;

-- What a league looks like from the outside, before you join it.
create function public.league_preview(p_code text)
returns table (id uuid, name text, code text, members int, max_members int)
language sql security definer set search_path = public as $$
  select l.id, l.name, l.code,
         (select count(*)::int from public.league_members m where m.league_id = l.id),
         l.max_members
  from public.leagues l
  where l.code = upper(btrim(p_code))
$$;

create function public.create_league(p_name text)
returns public.leagues
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.my_profile_id();
  l  public.leagues;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if (select count(*) from public.leagues where owner_id = me) >= 10 then
    raise exception 'TOO_MANY_LEAGUES';
  end if;
  insert into public.leagues (name, owner_id) values (btrim(p_name), me)
  returning * into l;
  insert into public.league_members (league_id, profile_id) values (l.id, me);
  return l;
end $$;

-- Anyone with the code can join at any time, as long as there is room.
-- You always start the current week on 0 points.
create function public.join_league_by_code(p_code text)
returns public.leagues
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.my_profile_id();
  l  public.leagues;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  select * into l from public.leagues where code = upper(btrim(p_code));
  if not found then raise exception 'NO_SUCH_LEAGUE'; end if;
  if exists (select 1 from public.league_members
              where league_id = l.id and profile_id = me) then
    return l;
  end if;
  insert into public.league_members (league_id, profile_id) values (l.id, me);
  return l;
end $$;

create function public.leave_league(p_league uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id();
begin
  delete from public.league_members where league_id = p_league and profile_id = me;
end $$;

create function public.my_leagues()
returns table (id uuid, name text, code text, owner_id uuid, members int,
               max_members int, joined_at timestamptz,
               badge jsonb, rest_dow int[], season_weeks int, catchup_dow int,
               created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.name, l.code, l.owner_id,
         (select count(*)::int from public.league_members m2 where m2.league_id = l.id),
         l.max_members, m.joined_at,
         l.badge, l.rest_dow, l.season_weeks, l.catchup_dow, l.created_at
  from public.leagues l
  join public.league_members m on m.league_id = l.id
  where m.profile_id = public.my_profile_id()
  order by m.joined_at
$$;

-- The live board. Every member appears, even on 0 points, and each total
-- already includes that week's daily combo bonuses.
create function public.league_leaderboard(p_league uuid, p_week date default null)
returns table (profile_id uuid, display_name text, avatar text, points numeric,
               base_points numeric, bonus numeric, entries bigint,
               joined_at timestamptz, lifetime numeric, banner text,
               pinned_badges text[], name_color text)
language sql stable security definer set search_path = public as $$
  -- `lifetime` drives the rank banner on each row. Like divisions and duel
  -- records it is derived on read, so there is nothing to store or award.
  with wk as (select coalesce(p_week, public.current_week_start()) as w),
  cb as (select * from public.week_combo_bonus(p_league, (select w from wk))),
  bb as (select * from public.week_bounty_points(p_league, (select w from wk))),
  lt as (
    -- Lifetime follows the person, not the league. A log fans out to one row
    -- per league, so count each log once (by group_id) or joining a second
    -- league would double everyone's rank.
    select profile_id, sum(points) as total
    from (select distinct on (group_id) group_id, profile_id, points
          from public.workouts order by group_id, league_id) one_per_log
    group by profile_id)
  select p.id, p.display_name, p.avatar,
         (coalesce(sum(w.points), 0) + coalesce(max(cb.bonus), 0)
                                     + coalesce(max(bb.bounty), 0))::numeric,
         coalesce(sum(w.points), 0)::numeric,
         (coalesce(max(cb.bonus), 0) + coalesce(max(bb.bounty), 0))::numeric,
         count(w.id), m.joined_at,
         coalesce(max(lt.total), 0)::numeric, p.banner, p.pinned_badges,
         p.name_color
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join public.workouts w
         on w.profile_id = p.id and w.league_id = p_league
        and w.week_start = (select w from wk)
  left join cb on cb.profile_id = p.id
  left join bb on bb.profile_id = p.id
  left join lt on lt.profile_id = p.id
  where m.league_id = p_league and public.is_member(p_league)
  group by p.id, p.display_name, p.avatar, p.banner, p.pinned_badges,
           p.name_color, m.joined_at
  order by 4 desc, 8 asc
$$;

-- Every finished week, best first — used by the Hall of Fame tab.
-- Consistency, counted in days rather than volume, so a beginner doing 20
-- push-ups daily can top a table the strongest athlete does not. Consecutive
-- dates share (date - row_number), which finds runs without a recursive walk.
create function public.set_pinned_badges(p_keys text[])
returns public.profiles language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if array_length(p_keys, 1) > 3 then raise exception 'Three badges on show, maximum'; end if;
  update public.profiles set pinned_badges = coalesce(p_keys, '{}')
   where id = me returning * into row;
  return row;
end $$;

-- Badges are earned inside a league and computed from what already happened —
-- no award step, nothing to backfill, and a badge added later retro-grants
-- itself to everyone who already qualified.
create function public.my_badges(p_league uuid)
returns table (key text, name text, descr text, earned boolean,
               progress numeric, target numeric)
language sql stable security definer set search_path = public as $$
  with me as (select public.my_profile_id() as id),
  wins as (
    select count(*)::numeric n from (
      select h.week_start, h.profile_id,
             row_number() over (partition by h.week_start
                                order by h.points desc, h.joined_at asc) rk
      from public.weekly_history(p_league) h
      where h.week_start < public.current_week_start()
    ) x where x.rk = 1 and x.profile_id = (select id from me)
  ),
  strk as (select best_streak from public.league_streaks(p_league)
           where profile_id = (select id from me)),
  life as (select coalesce(sum(points), 0) as pts, count(*)::numeric as logs
           from public.workouts
           where league_id = p_league and profile_id = (select id from me)),
  duels as (select coalesce(won, 0)::numeric as w
            from public.my_duel_record(p_league) limit 1),
  cats as (select count(distinct public.exercise_category(exercise_key))::numeric as n
           from public.workouts
           where league_id = p_league and profile_id = (select id from me)),
  gymn as (select count(*)::numeric n from public.workouts w
           join public.exercises e on e.key = w.exercise_key
           where w.league_id = p_league and w.profile_id = (select id from me)
             and e.cat = 'GYM'),
  km as (select coalesce(sum(amount), 0)::numeric n from public.workouts
         where league_id = p_league and profile_id = (select id from me)
           and exercise_key in ('run','walk','bike') and mode = 'km'),
  -- The weakest region on the figure, this week and at its best ever. One
  -- number, because the point of the figure is the part you are neglecting:
  -- your balance is your worst muscle, and no amount of curling raises it.
  bal as (select coalesce(min(pct), 0) as now
          from public.my_muscles(p_league, false)),
  balbest as (
    select coalesce(max(worst), 0) as best from (
      select w.week_start,
             min(public.muscle_charge(coalesce(sp.pts, 0),
                 m.target * public.muscle_dose((select id from me)))) as worst
      from public.muscles m
      cross join (select distinct week_start from public.workouts
                  where league_id = p_league and profile_id = (select id from me)) w
      left join lateral (
        select sum(x.points * (s.value)::numeric) as pts
        from public.workouts x
        join public.exercises e on e.key = x.exercise_key
        cross join lateral jsonb_each_text(e.muscles) as s(key, value)
        where x.league_id = p_league and x.profile_id = (select id from me)
          and x.week_start = w.week_start and s.key = m.key
      ) sp on true
      group by w.week_start) z
  ),
  b(key, name, descr, progress, target) as (values
    ('week_win','CHAMPION','Win a week in this league', (select n from wins), 1::numeric),
    ('win3','TRIPLE CROWN','Win three weeks', (select n from wins), 3),
    ('win5','FIVE CROWNS','Win five weeks', (select n from wins), 5),
    ('win10','TEN CROWNS','Win ten weeks', (select n from wins), 10),
    ('balance40','NO WEAK LINK','Every muscle past 40% in one week',
      (select best from balbest), 40),
    ('balance100','FULLY FORGED','A full week on all fourteen at once',
      (select best from balbest), 100),
    ('streak7','SEVEN STRAIGHT','Seven days running above 20 points',
      (select coalesce(max(best_streak),0)::numeric from strk), 7),
    ('streak14','FORTNIGHT','Fourteen days running',
      (select coalesce(max(best_streak),0)::numeric from strk), 14),
    ('streak30','UNBROKEN','Thirty days running',
      (select coalesce(max(best_streak),0)::numeric from strk), 30),
    ('duel3','DUELLIST','Win three duels', (select w from duels), 3),
    ('duel10','GLADIATOR','Win ten duels', (select w from duels), 10),
    ('century','CENTURION','A hundred logged sets here', (select logs from life), 100),
    ('grand','FIVE THOUSAND','Five thousand points here', (select pts from life), 5000),
    ('allrounder','ALL ROUNDER','Train all five muscle groups', (select n from cats), 5),
    ('gym','IRON PLATE','Fifty gym sets', (select n from gymn), 50),
    ('runner','DISTANCE','A hundred kilometres covered', (select n from km), 100)
  )
  select b.key, b.name, b.descr,
         coalesce(b.progress, 0) >= b.target,
         least(coalesce(b.progress, 0), b.target), b.target
  from b
  order by (coalesce(b.progress,0) >= b.target) desc,
           coalesce(b.progress,0) / nullif(b.target,0) desc
$$;

-- Rivalries: every Monday the table is paired off top-down — 1v2, 3v4, 5v6 —
-- using LAST week's finish, so a pairing holds still all week instead of
-- reshuffling every time somebody logs. An odd table leaves the last person
-- out rather than inventing an opponent.
create function public.league_rivalries(p_league uuid, p_week date default null)
returns table (a_id uuid, a_name text, a_avatar text, a_points numeric,
               b_id uuid, b_name text, b_avatar text, b_points numeric,
               seed int, mine boolean)
language sql stable security definer set search_path = public as $$
  with wk as (select coalesce(p_week, public.current_week_start()) as w),
  prev as (
    select l.profile_id,
           row_number() over (order by l.points desc, l.joined_at asc) as rk
    from public.league_leaderboard(p_league, (select w from wk) - 7) l
  ),
  live as (
    select l.profile_id, l.points, l.display_name, l.avatar
    from public.league_leaderboard(p_league, (select w from wk)) l
  ),
  pairs as (
    select o.profile_id as a, e.profile_id as b, ((o.rk + 1) / 2)::int as seed
    from prev o join prev e on e.rk = o.rk + 1
    where o.rk % 2 = 1
  )
  select p.a, la.display_name, la.avatar, la.points,
         p.b, lb.display_name, lb.avatar, lb.points,
         p.seed,
         (p.a = public.my_profile_id() or p.b = public.my_profile_id())
  from pairs p
  join live la on la.profile_id = p.a
  join live lb on lb.profile_id = p.b
  where public.is_member(p_league)
  order by p.seed
$$;

create function public.league_streaks(p_league uuid, p_min numeric default 20)
returns table (profile_id uuid, display_name text, avatar text, banner text,
               current_streak int, best_streak int, active_days int)
language sql stable security definer set search_path = public as $$
  with days as (
    select w.profile_id,
           (w.created_at at time zone public.app_timezone())::date as d,
           sum(w.points) as pts
    from public.workouts w
    where w.league_id = p_league
    group by 1, 2
    having sum(w.points) >= p_min
  ),
  grp as (
    select profile_id, d,
           d - (row_number() over (partition by profile_id order by d))::int as run
    from days
  ),
  runs as (
    select profile_id, run, count(*)::int as len, max(d) as ended
    from grp group by 1, 2
  ),
  today as (select (now() at time zone public.app_timezone())::date as t)
  select p.id, p.display_name, p.avatar, p.banner,
         coalesce(max(r.len) filter (where r.ended >= (select t from today) - 1), 0)::int,
         coalesce(max(r.len), 0)::int,
         coalesce(sum(r.len), 0)::int
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join runs r on r.profile_id = p.id
  where m.league_id = p_league and public.is_member(p_league)
  group by p.id, p.display_name, p.avatar, p.banner
  order by 5 desc, 6 desc, 7 desc
$$;

-- A finished week has to read the same number the board read while it was
-- running, or the Hall of Fame quietly disagrees with what people watched
-- happen. It used to add the combo bonus and drop the bounty, so a week won
-- on a Thursday quest was recorded as a week lost. Both bonuses are in now,
-- and joined_at rides along so a tie is broken here the way the live board
-- breaks it — which is also what decides who won the week.
create function public.weekly_history(p_league uuid)
returns table (week_start date, profile_id uuid, display_name text, avatar text,
               points numeric, entries bigint, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.week_start, t.profile_id, t.display_name, t.avatar,
         (t.pts + coalesce(cb.bonus, 0) + coalesce(bb.bounty, 0))::numeric,
         t.n, t.joined_at
  from (
    select w.week_start, p.id as profile_id, p.display_name, p.avatar,
           sum(w.points) as pts, count(*) as n, m.joined_at
    from public.workouts w
    join public.profiles p on p.id = w.profile_id
    join public.league_members m
      on m.profile_id = p.id and m.league_id = w.league_id
    where w.league_id = p_league
      and w.week_start < public.current_week_start()
      and public.is_member(p_league)
    group by w.week_start, p.id, p.display_name, p.avatar, m.joined_at
  ) t
  left join lateral (
    select bonus from public.week_combo_bonus(p_league, t.week_start) b
    where b.profile_id = t.profile_id
  ) cb on true
  left join lateral (
    select bounty from public.week_bounty_points(p_league, t.week_start) b
    where b.profile_id = t.profile_id
  ) bb on true
  order by t.week_start desc, 5 desc, t.joined_at asc
$$;

-- Daily combo: cover several muscle groups in one day for a small bonus.
-- Recovery is excluded so a stretch cannot buy a group.
create function public.combo_threshold() returns numeric
language sql immutable set search_path = public as $$ select 10::numeric $$;

create function public.week_combo_bonus(p_league uuid, p_week date)
returns table (profile_id uuid, bonus numeric, best_day int)
language sql stable set search_path = public as $$
  with daily as (
    select w.profile_id,
           (w.created_at at time zone public.app_timezone())::date as d,
           public.exercise_category(w.exercise_key) as cat,
           sum(w.points) as pts
    from public.workouts w
    where w.league_id  = p_league
      and w.week_start = p_week
      and public.exercise_category(w.exercise_key) <> 'RECOVERY'
    group by 1, 2, 3
  ),
  cov as (
    select profile_id, d, count(*)::int as cats
    from daily where pts >= public.combo_threshold() group by 1, 2
  )
  select profile_id,
         sum(case when cats >= 5 then 12
                  when cats  = 4 then 8
                  when cats  = 3 then 5
                  else 0 end)::numeric,
         max(cats)
  from cov group by 1
$$;

create function public.my_combo_today(p_league uuid)
returns table (category text, points numeric)
language sql stable security definer set search_path = public as $$
  select public.exercise_category(w.exercise_key), sum(w.points)::numeric
  from public.workouts w
  where w.league_id  = p_league
    and w.profile_id = public.my_profile_id()
    and (w.created_at at time zone public.app_timezone())::date
        = (now() at time zone public.app_timezone())::date
    and public.exercise_category(w.exercise_key) <> 'RECOVERY'
    and public.is_member(p_league)
  group by 1
$$;

create function public.set_avatar(p_avatar text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare p public.profiles;
begin
  update public.profiles set avatar = nullif(btrim(p_avatar), '')
   where user_id = auth.uid() returning * into p;
  if not found then raise exception 'NO_PROFILE'; end if;
  return p;
end $$;

-- Bodyweight is what turns a barbell number into points. Stored on the profile
-- so the gym fields arrive pre-filled instead of being retyped every set.
create function public.set_bodyweight(p_kg numeric)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if p_kg is not null and p_kg not between 30 and 250 then
    raise exception 'Bodyweight must be between 30 and 250 kg';
  end if;
  update public.profiles set bodyweight = p_kg where id = me returning * into row;
  return row;
end $$;

create function public.set_banner(p_banner text)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  update public.profiles set banner = nullif(p_banner, '') where id = me returning * into row;
  return row;
end $$;

create function public.set_units(p_units text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if p_units not in ('kg','lb') then raise exception 'Units must be kg or lb'; end if;
  update public.profiles set units = p_units where id = me returning * into row;
  return row;
end $$;

create function public.set_body_form(p_form text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if p_form not in ('masc','fem','neutral') then
    raise exception 'Pick one of the three figures';
  end if;
  update public.profiles set body_form = p_form where id = me returning * into row;
  return row;
end $$;

-- ---------------------------------------------------------------------
-- 9c. The muscle figure
-- ---------------------------------------------------------------------
-- How much of each region a person has actually worked, as a percentage of a
-- full week's dose of it.
--
-- Points on a region are the points of every set that trains it, times that
-- set's share of it: a hundred points of bench press put fifty into the chest
-- and thirty into the triceps. Turning those points into a percentage is the
-- part that matters, because the obvious way — this region as a share of all
-- your work — is wrong twice over. It makes the numbers add to a hundred, so
-- training your legs harder makes your chest look worse; and it says nothing
-- about whether you did enough, only about proportion.
--
-- So each region is measured against a week's dose of itself instead:
--
--     pct = 100 x points / target
--
-- 100% is a full week of that muscle. There are fourteen of them and the
-- score is the one you have filled least, so the way up is always the thing
-- you have been avoiding. Past 100 it keeps counting — 240% is three weeks of
-- chest in one — but the bar is full and the effort is worth more elsewhere.
--
-- This replaced an exponential that approached 100 without ever reaching it.
-- That version was tidy, unfakeable, and impossible to explain: nobody could
-- say what 63% meant. A percentage of a week is a sentence anyone can finish.
create function public.muscle_charge(p_points numeric, p_target numeric)
returns numeric language sql immutable set search_path = public as $$
  select round(least(100 * greatest(p_points, 0) / greatest(p_target, 1), 999)::numeric, 0)
$$;

-- How big a week is, for this person.
--
-- A fixed dose is wrong at both ends: 645 points across the fourteen is a
-- serious week for somebody four weeks in and a light one for somebody
-- putting up thirteen hundred, and the second person reading 200% on six
-- regions is being told nothing at all. So the dose scales with the athlete,
-- from two things, whichever is higher:
--
--   the grade  0.6 + 0.9 x log10(1 + lifetime/200), held between 0.6 and 2.8.
--              Coarse and slow, but it works from the first week, before
--              there is any history to read.
--
--   the habit  the middle one of their finished weeks, divided by 645. Once
--              somebody has a few weeks in the books this is the honest
--              number: a full week for you is what your weeks actually are.
--
-- Taking the greater means the grade sets a floor that rises as you climb and
-- your own weeks take over as soon as they exist. It is capped at four so a
-- single enormous week cannot put the bar out of reach for a month.
create function public.muscle_dose(p_profile uuid)
returns numeric language sql stable set search_path = public as $$
  with life as (
    select coalesce(sum(points), 0) as pts from (
      select distinct on (group_id) group_id, points
      from public.workouts where profile_id = p_profile
      order by group_id, league_id) one),
  weeks as (
    select percentile_cont(0.5) within group (order by pts) as mid from (
      select week_start, sum(points) as pts from (
        select distinct on (group_id) group_id, week_start, points
        from public.workouts where profile_id = p_profile
        order by group_id, league_id) one
      where week_start < public.current_week_start()
      group by week_start) w)
  -- log() over numeric, not float: round(double precision, int) does not
  -- exist in Postgres and the whole expression has to stay numeric.
  select round(least(4.0, greatest(
    least(2.8, 0.6 + 0.9 * log(10.0, 1 + (select pts from life) / 200.0)),
    coalesce((select mid from weeks), 0)::numeric / 645.0,
    0.6))::numeric, 2)
$$;

-- One row per region, for this week or for everything.
--
-- Over a range longer than a week the target grows with it, otherwise every
-- region would read 99 by the second month and the figure would stop saying
-- anything. It is scaled by the weeks somebody actually logged in, not by the
-- weeks on the calendar, so a fortnight off does not punish the reading.
create function public.my_muscles(p_league uuid, p_all boolean default false)
returns table (key text, name text, view text, points numeric,
               pct numeric, target numeric, weeks int)
language sql stable security definer set search_path = public as $$
  with me as (select public.my_profile_id() as id),
  mine as (
    select w.exercise_key, w.points
    from public.workouts w
    where w.league_id = p_league and w.profile_id = (select id from me)
      and (p_all or w.week_start = public.current_week_start())
  ),
  wk as (
    select greatest(count(distinct w.week_start), 1)::int as n
    from public.workouts w
    where w.league_id = p_league and w.profile_id = (select id from me)
      and (p_all or w.week_start = public.current_week_start())
  ),
  dose as (select public.muscle_dose((select id from me)) as f),
  spread as (
    select s.key as mkey, sum(x.points * (s.value)::numeric) as pts
    from mine x
    join public.exercises e on e.key = x.exercise_key
    cross join lateral jsonb_each_text(e.muscles) as s(key, value)
    group by 1
  )
  select m.key, m.name, m.view,
         round(coalesce(sp.pts, 0), 1),
         public.muscle_charge(coalesce(sp.pts, 0),
                              m.target * (select f from dose) * (select n from wk)),
         round(m.target * (select f from dose) * (select n from wk))::numeric,
         (select n from wk)
  from public.muscles m
  left join spread sp on sp.mkey = m.key
  where public.is_member(p_league)
  order by m.sort, m.key
$$;

-- Who won each finished week, oldest first. The crowns board needs the
-- ORDER, not just the totals, because "first to five" is a race with a finish
-- line: somebody reaches it, that run is over, and the next one starts from
-- the following week. Handing back the sequence lets the target be changed on
-- the phone without the server storing a single thing about it — pick first
-- to three instead of five and every past run is re-cut on the spot.
create function public.league_champions(p_league uuid)
returns table (week_start date, profile_id uuid, display_name text, avatar text)
language sql stable security definer set search_path = public as $$
  select x.week_start, x.profile_id, x.display_name, x.avatar
  from (
    select h.week_start, h.profile_id, h.display_name, h.avatar,
           row_number() over (partition by h.week_start
                              order by h.points desc, h.joined_at asc) as rk
    from public.weekly_history(p_league) h
    where h.week_start < public.current_week_start()
  ) x
  where x.rk = 1 and public.is_member(p_league)
  order by x.week_start
$$;

-- ---------------------------------------------------------------------
-- 9d. Who has won weeks
-- ---------------------------------------------------------------------
-- Every finished week has exactly one winner: the top of that week's board.
-- Nothing is stored — the same weekly_history the Hall of Fame is drawn from
-- is read again and ranked — so a week that is corrected corrects the count,
-- and a league that starts today has an honest empty table rather than a
-- backfill nobody can check.
--
-- A tie on points is broken the way the live board breaks it, by who joined
-- first, so the winner of a week is the person who was actually shown at the
-- top of it.
create function public.league_wins(p_league uuid)
returns table (profile_id uuid, display_name text, avatar text,
               wins int, last_win date, weeks int, banner text,
               pinned_badges text[], name_color text, mine boolean)
language sql stable security definer set search_path = public as $$
  with done as (
    select h.week_start, h.profile_id,
           row_number() over (partition by h.week_start
                              order by h.points desc, h.joined_at asc) as rk
    from public.weekly_history(p_league) h
    where h.week_start < public.current_week_start()
  ),
  won as (select profile_id, count(*)::int n, max(week_start) last
          from done where rk = 1 group by 1),
  n as (select count(distinct week_start)::int c from done)
  select p.id, p.display_name, p.avatar,
         coalesce(w.n, 0), w.last, (select c from n),
         p.banner, p.pinned_badges, p.name_color,
         p.id = public.my_profile_id()
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join won w on w.profile_id = p.id
  where m.league_id = p_league and public.is_member(p_league)
  order by coalesce(w.n, 0) desc, w.last desc nulls last, m.joined_at
$$;

-- Only the person who made a league can delete it. The cascade takes the
-- memberships and that league's copies of everyone's logs; each log still
-- exists in the other leagues it fanned out to.
create function public.delete_league(p_league uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id();
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if not exists (select 1 from public.leagues where id = p_league and owner_id = me) then
    raise exception 'Only the person who created a league can delete it';
  end if;
  delete from public.leagues where id = p_league;
end $$;

create function public.set_league_settings(
  p_league uuid, p_rest_dow int[], p_season_weeks int,
  p_catchup_dow int default null)
returns public.leagues language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.leagues;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if not exists (select 1 from public.leagues where id = p_league and owner_id = me) then
    raise exception 'Only the person who created a league can change its settings';
  end if;
  if p_rest_dow is not null and exists (
      select 1 from unnest(p_rest_dow) d where d < 1 or d > 7) then
    raise exception 'Rest days must be weekday numbers 1 to 7';
  end if;
  if array_length(p_rest_dow, 1) > 3 then
    raise exception 'At most three rest days a week';
  end if;
  if p_catchup_dow is not null and (p_catchup_dow < 1 or p_catchup_dow > 7) then
    raise exception 'A catch-up day is a weekday number 1 to 7';
  end if;
  -- A rest day closes the league, so it cannot also be the day being behind
  -- is worth something. One or the other.
  if p_catchup_dow is not null and p_catchup_dow = any (coalesce(p_rest_dow, '{}'::int[])) then
    raise exception 'The catch-up day cannot also be a rest day';
  end if;
  update public.leagues
     set rest_dow = coalesce(p_rest_dow, rest_dow), season_weeks = p_season_weeks,
         catchup_dow = p_catchup_dow
   where id = p_league returning * into row;
  return row;
end $$;

create function public.set_league_badge(p_league uuid, p_badge jsonb)
returns public.leagues language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.leagues;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if not exists (select 1 from public.leagues where id = p_league and owner_id = me) then
    raise exception 'Only the person who created a league can change its crest';
  end if;
  if p_badge is not null and (
       coalesce(length(p_badge->>'shape'), 0)  > 20 or
       coalesce(length(p_badge->>'color'), 0)  > 20 or
       coalesce(length(p_badge->>'skin'), 0)   > 24 or
       coalesce(length(p_badge->>'text'), 0)   > 16 or
       coalesce(length(p_badge->>'emblem'), 0) > 40) then
    raise exception 'Badge values are too long';
  end if;
  update public.leagues
     set badge = case when p_badge is null then null else jsonb_strip_nulls(jsonb_build_object(
       'shape', p_badge->>'shape', 'color', p_badge->>'color',
       'emblem', p_badge->>'emblem', 'skin', p_badge->>'skin',
       'text', p_badge->>'text')) end
   where id = p_league returning * into row;
  return row;
end $$;

-- Log once, counted in every league you belong to.
-- p_bw and p_load are the gym pair: your bodyweight and what is on the bar.
-- They are null for everything else. The parameter list was left behind when
-- gym scoring arrived, so the body used two names the signature never
-- declared — a rebuild from this file produced a log_workout that could not
-- score a lift.
create function public.log_workout(
  p_league uuid, p_key text, p_mode text, p_amount numeric,
  p_bw numeric default null, p_load numeric default null)
returns table (id uuid, group_id uuid, exercise_key text, mode text,
               amount numeric, points numeric, leagues int)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.my_profile_id();
  g  uuid := gen_random_uuid();
  n  int;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if not public.is_member(p_league) then raise exception 'NOT_A_MEMBER'; end if;
  -- Remember the bodyweight so nobody retypes it every gym set.
  if p_bw is not null and p_bw between 30 and 250 then
    update public.profiles set bodyweight = p_bw where profiles.id = me;
  end if;

  insert into public.workouts (group_id, league_id, profile_id,
                               exercise_key, mode, amount, bodyweight, load)
  select g, m.league_id, me, p_key, p_mode, p_amount, p_bw, p_load
  from public.league_members m
  where m.profile_id = me;
  get diagnostics n = row_count;
  return query
  select w.id, w.group_id, w.exercise_key, w.mode, w.amount, w.points, n
  from public.workouts w
  where w.group_id = g and w.league_id = p_league;
end $$;

-- Duels ---------------------------------------------------------------
create function public.challenge_status(
  p_cancelled timestamptz, p_accepted timestamptz,
  p_ends timestamptz, p_created timestamptz)
returns text language sql stable set search_path = public as $$
  select case
    when p_cancelled is not null then 'CANCELLED'
    when p_accepted is null and p_created < now() - interval '24 hours' then 'EXPIRED'
    when p_accepted is null then 'PENDING'
    when now() < p_ends then 'LIVE'
    else 'FINISHED'
  end
$$;

create function public.challenge_points(
  p_league uuid, p_profile uuid, p_from timestamptz, p_to timestamptz)
returns numeric language sql stable set search_path = public as $$
  select coalesce(sum(w.points), 0)::numeric
  from public.workouts w
  where w.league_id = p_league and w.profile_id = p_profile
    and p_from is not null and w.created_at >= p_from and w.created_at < p_to
$$;

create function public.has_open_challenge(p_profile uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (
    select 1 from public.challenges c
    where (c.challenger_id = p_profile or c.opponent_id = p_profile)
      and public.challenge_status(c.cancelled_at, c.accepted_at, c.ends_at, c.created_at)
          in ('PENDING', 'LIVE')
  )
$$;

create function public.create_challenge(p_league uuid) returns public.challenges
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); c public.challenges;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  if not public.is_member(p_league) then raise exception 'NOT_A_MEMBER'; end if;
  if public.has_open_challenge(me) then raise exception 'ALREADY_IN_CHALLENGE'; end if;
  insert into public.challenges (league_id, challenger_id)
  values (p_league, me) returning * into c;
  return c;
end $$;

create function public.challenge_preview(p_code text)
returns table (code text, league_name text, challenger_name text,
               challenger_avatar text, status text)
language sql security definer set search_path = public as $$
  select c.code, l.name, p.display_name, p.avatar,
         public.challenge_status(c.cancelled_at, c.accepted_at, c.ends_at, c.created_at)
  from public.challenges c
  join public.leagues  l on l.id = c.league_id
  join public.profiles p on p.id = c.challenger_id
  where c.code = upper(btrim(p_code))
$$;

create function public.accept_challenge(p_code text) returns public.challenges
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); c public.challenges;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  select * into c from public.challenges where code = upper(btrim(p_code));
  if not found then raise exception 'NO_SUCH_CHALLENGE'; end if;
  if c.challenger_id = me then raise exception 'OWN_CHALLENGE'; end if;
  if public.challenge_status(c.cancelled_at, c.accepted_at, c.ends_at, c.created_at)
     <> 'PENDING' then raise exception 'CHALLENGE_UNAVAILABLE'; end if;
  if not public.is_member(c.league_id) then raise exception 'NOT_A_MEMBER'; end if;
  if public.has_open_challenge(me) then raise exception 'ALREADY_IN_CHALLENGE'; end if;
  update public.challenges
     set opponent_id = me, accepted_at = now(), ends_at = now() + interval '24 hours'
   where id = c.id returning * into c;
  return c;
end $$;

create function public.cancel_challenge(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id();
begin
  update public.challenges set cancelled_at = now()
   where id = p_id and challenger_id = me and accepted_at is null and cancelled_at is null;
end $$;

-- Lifetime duel record for the stats tab. Results are derived from the
-- workouts inside each duel's window rather than stored, and the challenge
-- rows themselves are never deleted, so the record is permanent.
create function public.my_duel_record(p_league uuid)
returns table (played int, won int, lost int, drawn int, best_streak int)
language sql stable security definer set search_path = public as $$
  with me as (select public.my_profile_id() as pid),
  fin as (
    select c.ends_at,
           public.challenge_points(c.league_id, (select pid from me),
                                   c.accepted_at, c.ends_at) as mine,
           public.challenge_points(c.league_id,
             case when c.challenger_id = (select pid from me)
                  then c.opponent_id else c.challenger_id end,
             c.accepted_at, c.ends_at) as theirs
    from public.challenges c
    where c.league_id = p_league
      and (c.challenger_id = (select pid from me) or c.opponent_id = (select pid from me))
      and public.challenge_status(c.cancelled_at, c.accepted_at,
                                  c.ends_at, c.created_at) = 'FINISHED'
      and public.is_member(p_league)
  ),
  runs as (
    select mine > theirs as w,
           row_number() over (order by ends_at)
             - row_number() over (partition by mine > theirs order by ends_at) as grp
    from fin
  )
  select (select count(*)::int from fin),
         (select count(*) filter (where mine >  theirs)::int from fin),
         (select count(*) filter (where mine <  theirs)::int from fin),
         (select count(*) filter (where mine =  theirs)::int from fin),
         coalesce((select max(c)::int from (
            select count(*) as c from runs where w group by grp) s), 0)
$$;

create function public.my_challenges()
returns table (id uuid, code text, status text, league_name text,
               me_name text, me_avatar text, me_points numeric,
               foe_name text, foe_avatar text, foe_points numeric,
               created_at timestamptz, ends_at timestamptz, i_started boolean)
language sql stable security definer set search_path = public as $$
  with me as (select public.my_profile_id() as pid)
  select c.id, c.code,
         public.challenge_status(c.cancelled_at, c.accepted_at, c.ends_at, c.created_at),
         l.name, mp.display_name, mp.avatar,
         public.challenge_points(c.league_id, (select pid from me), c.accepted_at, c.ends_at),
         fp.display_name, fp.avatar,
         public.challenge_points(c.league_id,
           case when c.challenger_id = (select pid from me) then c.opponent_id
                else c.challenger_id end, c.accepted_at, c.ends_at),
         c.created_at, c.ends_at, (c.challenger_id = (select pid from me))
  from public.challenges c
  join public.leagues l on l.id = c.league_id
  join public.profiles mp on mp.id = (select pid from me)
  left join public.profiles fp on fp.id =
       (case when c.challenger_id = (select pid from me) then c.opponent_id
             else c.challenger_id end)
  where c.challenger_id = (select pid from me) or c.opponent_id = (select pid from me)
  order by case public.challenge_status(c.cancelled_at, c.accepted_at, c.ends_at, c.created_at)
             when 'LIVE' then 0 when 'PENDING' then 1 else 2 end,
           c.created_at desc
  limit 12
$$;

-- Personal totals for the stats tab.
create function public.my_stats(p_league uuid, p_all boolean default false)
returns table (exercise_key text, category text, mode text,
               total_amount numeric, total_points numeric, entries bigint,
               active_days bigint)
language sql stable security definer set search_path = public as $$
  select w.exercise_key, public.exercise_category(w.exercise_key), w.mode,
         sum(w.amount)::numeric, sum(w.points)::numeric, count(*),
         count(distinct (w.created_at at time zone public.app_timezone())::date)
  from public.workouts w
  where w.league_id  = p_league
    and w.profile_id = public.my_profile_id()
    and (p_all or w.week_start = public.current_week_start())
    and public.is_member(p_league)
  group by 1, 2, 3
  order by 5 desc
$$;

-- ---------------------------------------------------------------------
-- 7b. Weekly bounty
-- ---------------------------------------------------------------------

-- >>> WHICH DAY THE BOUNTY RUNS <<<  1=Monday … 6=Saturday
create function public.bounty_dow() returns int
language sql immutable set search_path = public as $$ select 4 $$;   -- Thursday

-- Which bounty a week gets. A hash of (year, idx) puts the pool in a
-- different order every year; the week number then picks a position in that
-- order. It is deterministic, so every league in the world sees the same
-- quest on the same day and can talk about it — but no two years run the same
-- sequence, and with a pool this size most of it is unseen in any one year.
create function public.bounty_index(p_week date) returns int
language sql stable set search_path = public as $$
  with n as (select count(*)::int as total from public.bounties),
       y as (select extract(isoyear from p_week)::int as yr,
                    extract(week    from p_week)::int as wk),
       shuffled as (
         select b.idx,
                (row_number() over (order by md5((select yr from y)::text
                                                 || ':' || b.idx::text)) - 1)::int as slot
         from public.bounties b)
  select s.idx from shuffled s
  where s.slot = ((select wk from y) - 1) % greatest((select total from n), 1)
$$;

-- A pinned week wins over the shuffle. Everything downstream asks this one.
create function public.bounty_pick(p_week date) returns int
language sql stable set search_path = public as $$
  select coalesce((select bounty_idx from public.bounty_schedule
                   where week_start = p_week),
                  public.bounty_index(p_week))
$$;

create function public.bounty_date(p_week date) returns date
language sql immutable set search_path = public as $$
  select p_week + (public.bounty_dow() - 1)
$$;

-- One requirement: "at least N of X, optionally inside an hour window".
create function public.bounty_req(
  p_profile uuid, p_league uuid, p_req jsonb, p_day date) returns boolean
language sql stable set search_path = public as $$
  select coalesce(sum(w.amount), 0) >= (p_req->>'min')::numeric
  from public.workouts w
  where w.profile_id = p_profile
    and w.league_id  = p_league
    and (w.created_at at time zone public.app_timezone())::date = p_day
    and (p_req->>'ex'   is null or w.exercise_key = p_req->>'ex')
    and (p_req->>'mode' is null or w.mode         = p_req->>'mode')
    and (p_req->>'from_h' is null or
         extract(hour from (w.created_at at time zone public.app_timezone())) >= (p_req->>'from_h')::int)
    and (p_req->>'to_h'   is null or
         extract(hour from (w.created_at at time zone public.app_timezone())) <  (p_req->>'to_h')::int)
$$;

-- Points earned today inside one muscle group. This is what lets a bounty say
-- "pulling only" — everything else logged that day simply does not count.
create function public.bounty_cat_points(
  p_profile uuid, p_league uuid, p_cat text, p_day date) returns numeric
language sql stable set search_path = public as $$
  select coalesce(sum(w.points), 0)
  from public.workouts w
  where w.profile_id = p_profile
    and w.league_id  = p_league
    and (w.created_at at time zone public.app_timezone())::date = p_day
    and public.exercise_category(w.exercise_key) = p_cat
$$;

create function public.bounty_done(
  p_profile uuid, p_league uuid, p_spec jsonb, p_day date) returns boolean
language plpgsql stable set search_path = public as $$
declare
  tz   text := public.app_timezone();
  kind text := coalesce(p_spec->>'kind', 'reqs');
  r    jsonb;
  n    int;
begin
  if kind = 'cat_points' then
    return public.bounty_cat_points(p_profile, p_league, p_spec->>'cat', p_day)
           >= (p_spec->>'min')::numeric;

  elsif kind = 'cats' then
    for r in select * from jsonb_array_elements(p_spec->'cats') loop
      if public.bounty_cat_points(p_profile, p_league, r->>'cat', p_day)
         < (r->>'min')::numeric then return false; end if;
    end loop;
    return true;

  elsif kind = 'reqs' then
    for r in select * from jsonb_array_elements(p_spec->'reqs') loop
      if not public.bounty_req(p_profile, p_league, r, p_day) then return false; end if;
    end loop;
    return true;

  elsif kind = 'any' then
    for r in select * from jsonb_array_elements(p_spec->'any') loop
      if public.bounty_req(p_profile, p_league, r, p_day) then return true; end if;
    end loop;
    return false;

  elsif kind = 'distinct' then
    select count(distinct case when p_spec->>'what' = 'cat'
                               then public.exercise_category(w.exercise_key)
                               else w.exercise_key end)
      into n
    from public.workouts w
    where w.profile_id = p_profile and w.league_id = p_league
      and (w.created_at at time zone tz)::date = p_day
      and (p_spec->>'from_h' is null or
           extract(hour from (w.created_at at time zone tz)) >= (p_spec->>'from_h')::int)
      and (p_spec->>'to_h' is null or
           extract(hour from (w.created_at at time zone tz)) <  (p_spec->>'to_h')::int);
    return coalesce(n, 0) >= (p_spec->>'min')::int;

  elsif kind = 'reps_across' then
    select count(distinct w.exercise_key) into n
    from public.workouts w
    where w.profile_id = p_profile and w.league_id = p_league
      and w.mode = 'reps' and (w.created_at at time zone tz)::date = p_day;
    if coalesce(n, 0) < (p_spec->>'exercises')::int then return false; end if;
    return (select coalesce(sum(w.amount), 0) from public.workouts w
            where w.profile_id = p_profile and w.league_id = p_league
              and w.mode = 'reps' and (w.created_at at time zone tz)::date = p_day)
           >= (p_spec->>'min')::numeric;

  elsif kind = 'split' then
    return public.bounty_req(p_profile, p_league,
             jsonb_build_object('ex', p_spec->>'ex', 'min', p_spec->>'min', 'to_h', 12), p_day)
       and public.bounty_req(p_profile, p_league,
             jsonb_build_object('ex', p_spec->>'ex', 'min', p_spec->>'min', 'from_h', 12), p_day);

  elsif kind = 'hourly' then
    select count(*) into n from (
      select extract(hour from (w.created_at at time zone tz)) as h, sum(w.amount) as a
      from public.workouts w
      where w.profile_id = p_profile and w.league_id = p_league
        and w.exercise_key = p_spec->>'ex'
        and (w.created_at at time zone tz)::date = p_day
      group by 1
    ) t where t.a >= (p_spec->>'each')::numeric;
    return coalesce(n, 0) >= (p_spec->>'hours')::int;

  elsif kind = 'pr' then
    return (select coalesce(sum(w.points), 0) from public.workouts w
            where w.profile_id = p_profile and w.league_id = p_league
              and (w.created_at at time zone tz)::date = p_day)
         > coalesce((select max(d.p) from (
             select (w.created_at at time zone tz)::date as d, sum(w.points) as p
             from public.workouts w
             where w.profile_id = p_profile and w.league_id = p_league
               and (w.created_at at time zone tz)::date < p_day
             group by 1) d), 0);

  elsif kind = 'team' then
    select count(distinct w.profile_id) into n
    from public.workouts w
    where w.league_id = p_league and (w.created_at at time zone tz)::date = p_day;
    return coalesce(n, 0) >= (p_spec->>'members')::int;

  elsif kind = 'duo' then
    return exists (
      select 1 from public.workouts a
      join public.workouts b on b.league_id = a.league_id
                            and b.profile_id <> a.profile_id
                            and abs(extract(epoch from (b.created_at - a.created_at))) <= 3600
      where a.profile_id = p_profile and a.league_id = p_league
        and (a.created_at at time zone tz)::date = p_day);

  elsif kind = 'underdog' then
    if not exists (select 1 from public.workouts w
                   where w.profile_id = p_profile and w.league_id = p_league
                     and (w.created_at at time zone tz)::date = p_day) then
      return false;
    end if;
    return (select coalesce(sum(w.points), 0) from public.workouts w
            where w.profile_id = p_profile and w.league_id = p_league
              and w.week_start = date_trunc('week', p_day)::date)
        <= (select min(t.p) from (
              select w.profile_id, coalesce(sum(w.points), 0) as p
              from public.workouts w
              where w.league_id = p_league
                and w.week_start = date_trunc('week', p_day)::date
                and exists (select 1 from public.workouts x
                            where x.profile_id = w.profile_id and x.league_id = p_league
                              and (x.created_at at time zone tz)::date = p_day)
              group by w.profile_id) t);
  end if;
  return false;
end $$;

create function public.week_bounty_points(p_league uuid, p_week date)
returns table (profile_id uuid, bounty numeric)
language sql stable set search_path = public as $$
  with b as (select * from public.bounties where idx = public.bounty_pick(p_week)),
       d as (select public.bounty_date(p_week) as day)
  select m.profile_id, (select points from b)::numeric
  from public.league_members m
  where m.league_id = p_league
    and (select count(*) from b) = 1
    and public.bounty_done(m.profile_id, p_league, (select spec from b), (select day from d))
$$;

create function public.current_raid(p_league uuid)
returns table (idx int, name text, descr text, unit text,
               target numeric, progress numeric, members int,
               done boolean, top_name text, top_amount numeric)
language sql stable security definer set search_path = public as $$
  with wk as (select public.current_week_start() as w),
  r as (select * from public.raids
        where idx = ((extract(epoch from (select w from wk))::bigint / 604800)
                     % (select count(*) from public.raids))::int),
  n as (select count(*)::int c from public.league_members where league_id = p_league),
  contrib as (
    select w.profile_id, sum(w.amount) as amt
    from public.workouts w, r
    where w.league_id = p_league
      and w.week_start = (select w from wk)
      and w.exercise_key = any (r.ex_keys)
      and w.mode = r.mode
    group by 1
  ),
  top as (select p.display_name, c.amt from contrib c
          join public.profiles p on p.id = c.profile_id
          order by c.amt desc limit 1)
  select r.idx, r.name, r.descr, r.unit,
         (r.per_member * (select c from n))::numeric,
         coalesce((select sum(amt) from contrib), 0)::numeric,
         (select c from n),
         coalesce((select sum(amt) from contrib), 0) >= r.per_member * (select c from n),
         (select display_name from top), (select amt from top)
  from r
  where public.is_member(p_league)
$$;

create function public.set_name_color(p_color text)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  update public.profiles set name_color = nullif(p_color, '') where id = me returning * into row;
  return row;
end $$;

-- ---------------------------------------------------------------------
-- Master dashboard. Admin is a flag on a profile and every function below
-- checks it server-side, so the browser never holds a privileged key: a
-- member who forces the screen open still gets nothing back, and any delete
-- they attempt is refused here.
-- ---------------------------------------------------------------------
create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles
                   where id = public.my_profile_id()), false)
$$;

create function public.admin_leagues()
returns table (id uuid, name text, code text, owner_name text, members int,
               workouts bigint, last_log timestamptz, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.name, l.code, o.display_name,
         (select count(*)::int from public.league_members m where m.league_id = l.id),
         (select count(*) from public.workouts w where w.league_id = l.id),
         (select max(w.created_at) from public.workouts w where w.league_id = l.id),
         l.created_at
  from public.leagues l
  join public.profiles o on o.id = l.owner_id
  where public.is_admin()
  order by l.created_at
$$;

-- Two different totals, because the control room kept being read as if it
-- showed one. `lifetime` follows the person: a log fans out to a row per
-- league, so it counts each one once (distinct on group_id) and carries no
-- league bonus at all. `week_points` is the number on a league board right
-- now -- this week's base plus the combo and bounty bonuses -- taken from
-- whichever of the player's leagues it is highest in. They are meant to
-- differ; naming them apart is what stops the difference reading as a bug.
create function public.admin_players()
returns table (id uuid, display_name text, avatar text, restore_code text,
               leagues int, workouts bigint, lifetime numeric, week_points numeric,
               last_log timestamptz, created_at timestamptz, is_admin boolean)
language sql stable security definer set search_path = public as $$
  with wk as (select public.current_week_start() as w),
  lg as (select distinct league_id from public.league_members),
  base as (
    select x.profile_id, x.league_id, sum(x.points) as pts
    from public.workouts x
    where x.week_start = (select w from wk)
    group by 1, 2),
  cb as (
    select l.league_id, c.profile_id, c.bonus
    from lg l, lateral public.week_combo_bonus(l.league_id, (select w from wk)) c),
  bb as (
    select l.league_id, b.profile_id, b.bounty
    from lg l, lateral public.week_bounty_points(l.league_id, (select w from wk)) b),
  board as (
    select m.profile_id,
           max(coalesce(base.pts, 0) + coalesce(cb.bonus, 0)
                                     + coalesce(bb.bounty, 0)) as total
    from public.league_members m
    left join base on base.profile_id = m.profile_id and base.league_id = m.league_id
    left join cb   on cb.profile_id   = m.profile_id and cb.league_id   = m.league_id
    left join bb   on bb.profile_id   = m.profile_id and bb.league_id   = m.league_id
    group by 1)
  select p.id, p.display_name, p.avatar, p.restore_code,
         (select count(*)::int from public.league_members m where m.profile_id = p.id),
         (select count(distinct w.group_id) from public.workouts w where w.profile_id = p.id),
         coalesce((select sum(points) from (
            select distinct on (group_id) group_id, points
            from public.workouts where profile_id = p.id
            order by group_id, league_id) x), 0),
         coalesce((select total from board where board.profile_id = p.id), 0)::numeric,
         (select max(w.created_at) from public.workouts w where w.profile_id = p.id),
         p.created_at, p.is_admin
  from public.profiles p
  where public.is_admin()
  order by p.created_at
$$;

create function public.admin_delete_league(p_league uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  delete from public.leagues where id = p_league;
end $$;

create function public.admin_delete_profile(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid;
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  if p_profile = public.my_profile_id() then
    raise exception 'You cannot delete your own account from here';
  end if;
  select user_id into u from public.profiles where id = p_profile;
  delete from public.profiles where id = p_profile;
  if u is not null then delete from auth.users where id = u; end if;
end $$;

-- The next six months of bounties, so the control room can see what is coming
-- and change it. `pinned` marks a week somebody chose rather than the shuffle.
create function public.admin_schedule()
returns table (week_start date, bounty_idx int, name text, descr text,
               points numeric, pinned boolean, note text)
language sql stable security definer set search_path = public as $$
  with weeks as (
    select (public.current_week_start() + (n * 7))::date as w
    from generate_series(0, 25) n)
  select k.w, public.bounty_pick(k.w), b.name, b.descr, b.points,
         exists (select 1 from public.bounty_schedule s where s.week_start = k.w),
         (select note from public.bounty_schedule s where s.week_start = k.w)
  from weeks k
  join public.bounties b on b.idx = public.bounty_pick(k.w)
  where public.is_admin()
  order by k.w
$$;

-- The one list of exercises a bounty may name. A quest is handed to every
-- player in every league at once, so it cannot need a gym, a pool, a bike, a
-- pitch, a rope, or a move that takes a year to learn: a floor, a wall, a
-- chair, a bar and a street have to be enough. Not a preference — a bounty
-- nobody in your league can attempt is just a week with no bounty.
--
-- GENERATED by tools/build_bounties.py from the same set it checks the
-- built-in pool against, so the pool and the control room cannot drift apart.
create function public.bounty_open_to_all(p_key text) returns boolean
language sql immutable set search_path = public as $$
  select p_key = any (array[
    'airsquats',
    'benchdips',
    'bicycle',
    'birddog',
    'calves',
    'chinups',
    'commandopull',
    'crunches',
    'deadbug',
    'deadhang',
    'declinepush',
    'diamondpush',
    'dips',
    'flutterkick',
    'gluteBridge',
    'hangingleg',
    'hollowhold',
    'inclinepush',
    'jumpsquats',
    'kneepush',
    'kneeraises',
    'legraises',
    'lunges',
    'mountainclimb',
    'pikepush',
    'plank',
    'pullups',
    'pushups',
    'rows',
    'run',
    'scapulapull',
    'sidecrunch',
    'sideplank',
    'situps',
    'sphinxpush',
    'splitsquat',
    'sprints',
    'stepups',
    'stretch',
    'supermans',
    'twists',
    'vups',
    'walk',
    'wallpush',
    'wallsit',
    'widepullup',
    'widepush'
  ])
$$;

-- What the control room may build a bounty out of: the open list, in the
-- order the app shows exercises.
create function public.bounty_exercises()
returns table (key text, name text, cat text, modes jsonb)
language sql stable set search_path = public as $$
  select e.key, e.name, e.cat, e.modes
  from public.exercises e
  where public.bounty_open_to_all(e.key)
  order by e.sort, e.name
$$;

-- The whole pool, with the next week each one is due to run.
create function public.admin_bounties()
returns table (idx int, name text, descr text, points numeric, spec jsonb,
               runs_on date, custom boolean)
language sql stable security definer set search_path = public as $$
  with weeks as (
    select (public.current_week_start() + (n * 7))::date as w
    from generate_series(0, 51) n),
  built as (select max(idx) as top from public.bounties)
  select b.idx, b.name, b.descr, b.points, b.spec,
         (select min(w) from weeks where public.bounty_pick(w) = b.idx),
         b.idx >= public.builtin_bounty_count()
  from public.bounties b
  where public.is_admin()
  order by b.idx
$$;

-- How many bounties shipped with the app. Anything above this line was added
-- from the control room and may be deleted again; the built-ins may not.
create function public.builtin_bounty_count() returns int
language sql immutable set search_path = public as $$ select 110 $$;

create function public.admin_pin_bounty(p_week date, p_idx int, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  if p_week < public.current_week_start() then
    raise exception 'That week has already been played';
  end if;
  if p_week <> date_trunc('week', p_week)::date then
    raise exception 'Pin a Monday — a bounty week starts on one';
  end if;
  if not exists (select 1 from public.bounties where idx = p_idx) then
    raise exception 'No bounty has that number';
  end if;
  insert into public.bounty_schedule (week_start, bounty_idx, note)
  values (p_week, p_idx, nullif(btrim(coalesce(p_note, '')), ''))
  on conflict (week_start) do update
    set bounty_idx = excluded.bounty_idx, note = excluded.note, set_at = now();
end $$;

create function public.admin_unpin_bounty(p_week date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  delete from public.bounty_schedule where week_start = p_week;
end $$;

-- Writing a bounty by hand. The spec language is deliberately not exposed:
-- one exercise, one amount, an optional hour window. That covers most of the
-- pool and cannot produce a quest nobody is able to finish.
create function public.admin_add_bounty(
  p_name text, p_descr text, p_points numeric,
  p_ex text, p_mode text, p_min numeric,
  p_from_h int default null, p_to_h int default null)
returns int language plpgsql security definer set search_path = public as $$
declare next_idx int; req jsonb;
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 3 then
    raise exception 'Give it a name';
  end if;
  if p_points is null or p_points < 5 or p_points > 100 then
    raise exception 'Points must be between 5 and 100';
  end if;
  if not exists (select 1 from public.exercises e
                 where e.key = p_ex and e.modes ? p_mode) then
    raise exception 'That exercise cannot be logged that way';
  end if;
  if not public.bounty_open_to_all(p_ex) then
    raise exception 'A bounty goes to everybody, so it has to be something '
                    'everybody can do — no gym, no sport, no equipment';
  end if;
  if p_min is null or p_min <= 0 then raise exception 'Set an amount'; end if;
  if p_from_h is not null and (p_from_h < 0 or p_from_h > 23) then
    raise exception 'An hour is 0 to 23';
  end if;
  if p_to_h is not null and (p_to_h < 1 or p_to_h > 24) then
    raise exception 'An hour is 1 to 24';
  end if;

  req := jsonb_strip_nulls(jsonb_build_object(
    'ex', p_ex, 'mode', p_mode, 'min', p_min,
    'from_h', p_from_h, 'to_h', p_to_h));
  select coalesce(max(idx), -1) + 1 into next_idx from public.bounties;
  insert into public.bounties (idx, name, descr, points, spec)
  values (next_idx, upper(btrim(p_name)), btrim(coalesce(p_descr, '')), p_points,
          jsonb_build_object('reqs', jsonb_build_array(req)));
  return next_idx;
end $$;

create function public.admin_delete_bounty(p_idx int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  if p_idx < public.builtin_bounty_count() then
    raise exception 'A built-in bounty cannot be deleted, only left unpinned';
  end if;
  delete from public.bounties where idx = p_idx;
end $$;

create function public.current_bounty(p_league uuid)
returns table (idx int, name text, descr text, points numeric,
               on_date date, mine boolean, winners int, first_name text,
               first_avatar text)
language sql stable security definer set search_path = public as $$
  with wk as (select public.current_week_start() as w),
       b  as (select * from public.bounties where idx = public.bounty_pick((select w from wk))),
       d  as (select public.bounty_date((select w from wk)) as day),
       done as (select profile_id from public.week_bounty_points(p_league, (select w from wk))),
       firsts as (
         select w2.profile_id, min(w2.created_at) as t
         from public.workouts w2
         where w2.league_id = p_league
           and (w2.created_at at time zone public.app_timezone())::date = (select day from d)
           and w2.profile_id in (select profile_id from done)
         group by 1 order by 2 limit 1)
  select b.idx, b.name, b.descr, b.points, (select day from d),
         exists (select 1 from done where profile_id = public.my_profile_id()),
         (select count(*)::int from done),
         (select p.display_name from firsts f join public.profiles p on p.id = f.profile_id),
         (select p.avatar from firsts f join public.profiles p on p.id = f.profile_id)
  from b
  where public.is_member(p_league)
$$;

-- ---------------------------------------------------------------------
-- 8. Permissions
-- ---------------------------------------------------------------------
-- Internal helpers used by the RLS policies. Signed-in users must keep
-- EXECUTE (policies call them on the caller's behalf), but there is no
-- reason to expose them at /rest/v1/rpc/... to logged-out visitors.
revoke all on function public.my_profile_id()               from public, anon;
revoke all on function public.is_member(uuid)               from public, anon;
revoke all on function public.shares_league_with(uuid)      from public, anon;
grant execute on function public.my_profile_id()            to authenticated;
grant execute on function public.is_member(uuid)            to authenticated;
grant execute on function public.shares_league_with(uuid)   to authenticated;

revoke all on function public.create_profile(text)          from public, anon;
revoke all on function public.rename_profile(text)          from public, anon;
revoke all on function public.restore_profile(text)         from public, anon;
revoke all on function public.league_preview(text)          from public, anon;
revoke all on function public.create_league(text)           from public, anon;
revoke all on function public.join_league_by_code(text)     from public, anon;
revoke all on function public.leave_league(uuid)            from public, anon;
revoke all on function public.my_leagues()                  from public, anon;
revoke all on function public.league_leaderboard(uuid,date) from public, anon;
revoke all on function public.weekly_history(uuid)          from public, anon;
revoke all on function public.my_stats(uuid, boolean)       from public, anon;
revoke all on function public.set_avatar(text)              from public, anon;
revoke all on function public.my_combo_today(uuid)          from public, anon;
revoke all on function public.week_combo_bonus(uuid, date)  from public, anon;
revoke all on function public.set_body_form(text)           from public, anon;
revoke all on function public.muscle_charge(numeric,numeric) from public, anon;
revoke all on function public.my_muscles(uuid,boolean)      from public, anon;
revoke all on function public.muscle_dose(uuid)             from public, anon;
revoke all on function public.league_wins(uuid)             from public, anon;
revoke all on function public.league_champions(uuid)        from public, anon;
revoke all on function public.combo_threshold()             from public, anon;
revoke all on function public.is_rest_day(uuid)             from public, anon;
revoke all on function public.is_catchup_day(uuid)          from public, anon;
revoke all on function public.catchup_multiplier(uuid,uuid) from public, anon;
revoke all on function public.week_bounty_points(uuid,date) from public, anon;
revoke all on function public.current_bounty(uuid)          from public, anon;
revoke all on function public.bounty_done(uuid,uuid,jsonb,date) from public, anon;
revoke all on function public.bounty_req(uuid,uuid,jsonb,date)  from public, anon;
revoke all on function public.bounty_pick(date)             from public, anon;
revoke all on function public.bounty_cat_points(uuid,uuid,text,date) from public, anon;
revoke all on function public.bounty_open_to_all(text)      from public, anon;
revoke all on function public.bounty_exercises()            from public, anon;
revoke all on function public.admin_schedule()              from public, anon;
revoke all on function public.admin_bounties()              from public, anon;
revoke all on function public.admin_pin_bounty(date,int,text) from public, anon;
revoke all on function public.admin_unpin_bounty(date)      from public, anon;
revoke all on function public.admin_add_bounty(text,text,numeric,text,text,numeric,int,int)
  from public, anon;
revoke all on function public.admin_delete_bounty(int)      from public, anon;
revoke all on function public.log_workout(uuid,text,text,numeric,numeric,numeric) from public, anon;
revoke all on function public.create_challenge(uuid)        from public, anon;
revoke all on function public.accept_challenge(text)        from public, anon;
revoke all on function public.cancel_challenge(uuid)        from public, anon;
revoke all on function public.challenge_preview(text)       from public, anon;
revoke all on function public.my_challenges()               from public, anon;
revoke all on function public.exercise_category(text)       from public, anon;
revoke all on function public.current_week_start()          from public, anon;

grant select on public.exercises to authenticated;
grant select on public.raids     to authenticated;

grant execute on function public.create_profile(text)          to authenticated;
grant execute on function public.rename_profile(text)          to authenticated;
grant execute on function public.restore_profile(text)         to authenticated;
grant execute on function public.league_preview(text)          to authenticated;
grant execute on function public.create_league(text)           to authenticated;
grant execute on function public.join_league_by_code(text)     to authenticated;
grant execute on function public.leave_league(uuid)            to authenticated;
grant execute on function public.my_leagues()                  to authenticated;
grant execute on function public.league_leaderboard(uuid,date) to authenticated;
grant execute on function public.weekly_history(uuid)          to authenticated;
grant execute on function public.my_stats(uuid, boolean)       to authenticated;
grant execute on function public.set_avatar(text)              to authenticated;
grant execute on function public.set_bodyweight(numeric)       to authenticated;
grant execute on function public.set_units(text)               to authenticated;
grant execute on function public.set_body_form(text)           to authenticated;
grant execute on function public.muscle_charge(numeric,numeric) to authenticated;
grant execute on function public.my_muscles(uuid,boolean)      to authenticated;
grant execute on function public.muscle_dose(uuid)             to authenticated;
grant execute on function public.league_wins(uuid)             to authenticated;
grant select on public.muscles to authenticated;
grant execute on function public.set_banner(text)              to authenticated;
grant execute on function public.set_name_color(text)          to authenticated;
grant execute on function public.current_raid(uuid)            to authenticated;
grant execute on function public.is_admin()                    to authenticated;
grant execute on function public.admin_leagues()               to authenticated;
grant execute on function public.admin_players()               to authenticated;
grant execute on function public.admin_delete_league(uuid)     to authenticated;
grant execute on function public.admin_delete_profile(uuid)    to authenticated;
grant execute on function public.admin_schedule()              to authenticated;
grant execute on function public.admin_bounties()              to authenticated;
grant execute on function public.admin_pin_bounty(date,int,text) to authenticated;
grant execute on function public.admin_unpin_bounty(date)      to authenticated;
grant execute on function public.admin_add_bounty(text,text,numeric,text,text,numeric,int,int)
  to authenticated;
grant execute on function public.admin_delete_bounty(int)      to authenticated;
grant execute on function public.builtin_bounty_count()        to authenticated;
grant execute on function public.bounty_pick(date)             to authenticated;
grant execute on function public.bounty_cat_points(uuid,uuid,text,date) to authenticated;
grant execute on function public.bounty_open_to_all(text)      to authenticated;
grant execute on function public.bounty_exercises()            to authenticated;
grant select on public.bounty_schedule to authenticated;
grant execute on function public.league_streaks(uuid,numeric)  to authenticated;
grant execute on function public.set_pinned_badges(text[])     to authenticated;
grant execute on function public.my_badges(uuid)               to authenticated;
grant execute on function public.league_rivalries(uuid,date)   to authenticated;
grant execute on function public.delete_league(uuid)           to authenticated;
grant execute on function public.set_league_settings(uuid,int[],int,int) to authenticated;
grant execute on function public.set_league_badge(uuid,jsonb)  to authenticated;
grant execute on function public.my_combo_today(uuid)          to authenticated;
grant execute on function public.week_combo_bonus(uuid, date)  to authenticated;
grant execute on function public.combo_threshold()             to authenticated;
grant execute on function public.is_rest_day(uuid)              to authenticated;
grant execute on function public.is_catchup_day(uuid)           to authenticated;
grant execute on function public.catchup_multiplier(uuid,uuid)  to authenticated;
grant execute on function public.catchup_floor()                to authenticated;
grant execute on function public.catchup_ceiling()              to authenticated;
grant execute on function public.catchup_max()                  to authenticated;
grant execute on function public.bounty_dow()                  to authenticated;
grant execute on function public.bounty_index(date)            to authenticated;
grant execute on function public.bounty_date(date)             to authenticated;
grant execute on function public.week_bounty_points(uuid,date) to authenticated;
grant execute on function public.current_bounty(uuid)          to authenticated;
grant execute on function public.bounty_done(uuid,uuid,jsonb,date) to authenticated;
grant execute on function public.bounty_req(uuid,uuid,jsonb,date)  to authenticated;
grant execute on function public.log_workout(uuid,text,text,numeric,numeric,numeric) to authenticated;
grant execute on function public.create_challenge(uuid)        to authenticated;
grant execute on function public.accept_challenge(text)        to authenticated;
grant execute on function public.cancel_challenge(uuid)        to authenticated;
grant execute on function public.challenge_preview(text)       to authenticated;
grant execute on function public.my_challenges()               to authenticated;
grant execute on function public.exercise_category(text)       to authenticated;
grant execute on function public.current_week_start()          to authenticated;

-- ---------------------------------------------------------------------
-- 9. The 52 weekly bounties (one per week, rotating)
-- ---------------------------------------------------------------------
-- The exercise bank. GENERATED by tools/build_exercises.py — do not edit
-- by hand. Rates are derived from how much bodyweight a movement moves,
-- anchored to the original hand-tuned table, so the bank inherits balance
-- the league already agreed on. Mirrors EX_BANK in app.js exactly.
-- ---------------------------------------------------------------------
-- BANK BEGIN
insert into public.exercises (key,name,cat,variants,aliases,sort,modes,muscles)
select e->>0, e->>1, e->>2, e->>3, e->>4, (e->>5)::int, e->6, e->7
from jsonb_array_elements($j$[["wallpush","Wall Push-up","PUSH","","wall easy beginner",0,{"reps":{"rate":0.25}},{"chest":0.5,"shoulders":0.2,"triceps":0.3}],["kneepush","Knee Push-up","PUSH","","knees modified beginner",1,{"reps":{"rate":0.75}},{"chest":0.5,"shoulders":0.2,"triceps":0.3}],["inclinepush","Incline Push-up","PUSH","","bench elevated hands raised",2,{"reps":{"rate":0.75}},{"chest":0.5,"shoulders":0.2,"triceps":0.3}],["pushups","Push-ups","PUSH","Any hand position. Wide, diamond and decline have their own entries.","pushup press floor",3,{"reps":{"rate":1.0}},{"chest":0.45,"shoulders":0.15,"triceps":0.3,"abs":0.1}],["widepush","Wide Push-up","PUSH","","wide grip chest",4,{"reps":{"rate":1.0}},{"chest":0.6,"shoulders":0.2,"triceps":0.2}],["diamondpush","Diamond Push-up","PUSH","","triceps close narrow",5,{"reps":{"rate":1.0}},{"chest":0.35,"shoulders":0.15,"triceps":0.5}],["declinepush","Decline Push-up","PUSH","","feet elevated",6,{"reps":{"rate":1.25}},{"chest":0.4,"shoulders":0.3,"triceps":0.25,"abs":0.05}],["pikepush","Pike Push-up","PUSH","","shoulders delts",7,{"reps":{"rate":1.25}},{"chest":0.15,"shoulders":0.55,"triceps":0.3}],["clappush","Clap Push-up","PUSH","","explosive plyo power",8,{"reps":{"rate":1.5}},{"chest":0.4,"shoulders":0.2,"triceps":0.3,"abs":0.1}],["archerpush","Archer Push-up","PUSH","","one side unilateral",9,{"reps":{"rate":1.5}},{"chest":0.45,"shoulders":0.2,"triceps":0.25,"abs":0.1}],["planchepush","Pseudo Planche Push-up","PUSH","","lean planche straight arm",10,{"reps":{"rate":1.5}},{"chest":0.3,"shoulders":0.35,"triceps":0.15,"abs":0.2}],["benchdips","Bench Dips","PUSH","","tricep chair",11,{"reps":{"rate":0.75}},{"chest":0.2,"shoulders":0.2,"triceps":0.6}],["dips","Dips","PUSH","Parallel bars, rings or between two chairs","parallel bars triceps",12,{"reps":{"rate":1.5}},{"chest":0.4,"shoulders":0.2,"triceps":0.4}],["ringdips","Ring Dips","PUSH","","rings unstable",13,{"reps":{"rate":1.75}},{"chest":0.35,"shoulders":0.2,"triceps":0.35,"abs":0.1}],["onearmpush","One-arm Push-up","PUSH","","single arm",14,{"reps":{"rate":2.0}},{"chest":0.4,"shoulders":0.15,"triceps":0.25,"abs":0.2}],["sphinxpush","Sphinx Push-up","PUSH","","sphinx forearm tricep",15,{"reps":{"rate":0.75}},{"chest":0.15,"triceps":0.7,"abs":0.15}],["handstand","Handstand Push-up","PUSH","Against a wall, freestanding, or hanging from a bar","hspu wall overhead invert",16,{"reps":{"rate":2.5},"seconds":{"rate":0.3}},{"shoulders":0.55,"triceps":0.3,"traps":0.1,"abs":0.05}],["rows","Inverted Rows","PULL","","australian bodyweight row horizontal",17,{"reps":{"rate":1.0}},{"biceps":0.25,"forearms":0.15,"traps":0.2,"lats":0.4}],["scapulapull","Scapular Pull-up","PULL","","scap shrug",18,{"reps":{"rate":0.75}},{"forearms":0.2,"traps":0.5,"lats":0.3}],["bandpullup","Assisted Pull-up","PULL","","band assisted machine",19,{"reps":{"rate":1.25}},{"biceps":0.3,"forearms":0.15,"traps":0.1,"lats":0.45}],["chinups","Chin-ups","PULL","","supinated underhand biceps",20,{"reps":{"rate":2.0}},{"biceps":0.4,"forearms":0.15,"traps":0.1,"lats":0.35}],["pullups","Pull-ups","PULL","Overhand grip. Kipping counts, but be honest.","pullup overhand lats",21,{"reps":{"rate":2.0}},{"biceps":0.25,"forearms":0.15,"traps":0.15,"lats":0.45}],["widepullup","Wide-grip Pull-up","PULL","","wide lats",22,{"reps":{"rate":2.25}},{"biceps":0.15,"forearms":0.15,"traps":0.15,"lats":0.55}],["commandopull","Commando Pull-up","PULL","","mixed grip",23,{"reps":{"rate":2.25}},{"biceps":0.3,"forearms":0.15,"lats":0.4,"obliques":0.15}],["lsitpullup","L-sit Pull-up","PULL","","lsit legs out",24,{"reps":{"rate":2.5}},{"biceps":0.2,"forearms":0.2,"lats":0.35,"abs":0.25}],["typewriter","Typewriter Pull-up","PULL","","side to side",25,{"reps":{"rate":2.5}},{"biceps":0.2,"forearms":0.2,"lats":0.4,"obliques":0.2}],["archerpull","Archer Pull-up","PULL","","one side unilateral",26,{"reps":{"rate":2.5}},{"biceps":0.25,"forearms":0.2,"lats":0.4,"obliques":0.15}],["muscleup","Muscle-up / Flag","PULL","Bar or rings. The human flag scores here too.","muscleup bar ring humanflag",27,{"reps":{"rate":3.5},"seconds":{"rate":2.0}},{"shoulders":0.15,"biceps":0.2,"triceps":0.2,"forearms":0.15,"lats":0.3}],["deadhang","Dead Hang","PULL","","hang grip forearm",28,{"seconds":{"rate":0.2}},{"forearms":0.6,"traps":0.2,"lats":0.2}],["frontlever","Front Lever","PULL","","lever static hold",29,{"seconds":{"rate":0.75}},{"forearms":0.2,"lats":0.35,"lowerback":0.15,"abs":0.3}],["calves","Calf Raises","LEGS","","calf standing seated",30,{"reps":{"rate":0.2}},{"calves":1.0}],["airsquats","Air Squats","LEGS","","bodyweight squat",31,{"reps":{"rate":0.5}},{"glutes":0.3,"quads":0.5,"hamstrings":0.2}],["jumpsquats","Jump Squats","LEGS","","plyo explosive",32,{"reps":{"rate":0.75}},{"glutes":0.25,"quads":0.45,"hamstrings":0.1,"calves":0.2}],["lunges","Lunges","LEGS","","walking reverse forward",33,{"reps":{"rate":0.5}},{"glutes":0.35,"quads":0.4,"hamstrings":0.25}],["splitsquat","Bulgarian Split Squat","LEGS","","bulgarian rear foot elevated",34,{"reps":{"rate":0.75}},{"glutes":0.35,"quads":0.4,"hamstrings":0.25}],["stepups","Step-ups","LEGS","","box bench",35,{"reps":{"rate":0.5}},{"glutes":0.35,"quads":0.4,"hamstrings":0.15,"calves":0.1}],["gluteBridge","Glute Bridge","LEGS","","hip thrust glutes",36,{"reps":{"rate":0.25}},{"lowerback":0.1,"glutes":0.6,"hamstrings":0.3}],["nordic","Nordic Curl","LEGS","","hamstring eccentric",37,{"reps":{"rate":1.0}},{"glutes":0.15,"hamstrings":0.75,"calves":0.1}],["sissy","Sissy Squat","LEGS","","quads",38,{"reps":{"rate":0.75}},{"abs":0.1,"quads":0.8,"calves":0.1}],["shrimp","Shrimp Squat","LEGS","","advanced single leg",39,{"reps":{"rate":1.0}},{"glutes":0.3,"quads":0.45,"hamstrings":0.15,"calves":0.1}],["pistols","Pistol Squats","LEGS","","single leg one",40,{"reps":{"rate":2.0}},{"glutes":0.3,"quads":0.45,"hamstrings":0.15,"calves":0.1}],["wallsit","Wall Sit","LEGS","","isometric quads",41,{"seconds":{"rate":0.15}},{"glutes":0.2,"quads":0.7,"calves":0.1}],["crunches","Crunches","CORE","","crunch sit abs",42,{"reps":{"rate":0.25}},{"abs":1.0}],["situps","Sit-ups","CORE","","situp full",43,{"reps":{"rate":0.5}},{"abs":0.8,"obliques":0.1,"quads":0.1}],["twists","Russian Twists","CORE","","oblique twist side",44,{"reps":{"rate":0.25}},{"abs":0.3,"obliques":0.7}],["legraises","Lying Leg Raises","CORE","","floor lying",45,{"reps":{"rate":0.5}},{"abs":0.8,"quads":0.2}],["kneeraises","Hanging Knee Raises","CORE","","hanging knee tuck",46,{"reps":{"rate":1.0}},{"forearms":0.15,"abs":0.7,"obliques":0.15}],["hangingleg","Hanging Leg Raises","CORE","","straight leg toes",47,{"reps":{"rate":1.5}},{"forearms":0.15,"abs":0.65,"obliques":0.1,"quads":0.1}],["toestobar","Toes to Bar","CORE","","ttb crossfit",48,{"reps":{"rate":2.0}},{"forearms":0.15,"lats":0.15,"abs":0.6,"obliques":0.1}],["dragonflag","Dragon Flag","CORE","","dragon advanced",49,{"reps":{"rate":3.0}},{"lats":0.15,"lowerback":0.2,"abs":0.55,"obliques":0.1}],["vups","V-ups","CORE","","v up jackknife",50,{"reps":{"rate":0.75}},{"abs":0.75,"obliques":0.1,"quads":0.15}],["supermans","Supermans","CORE","","lower back extension",51,{"reps":{"rate":0.25}},{"traps":0.15,"lowerback":0.6,"glutes":0.25}],["sidecrunch","Lateral Crunches","CORE","","side oblique lateral crunch",52,{"reps":{"rate":0.25}},{"abs":0.2,"obliques":0.8}],["bicycle","Bicycle Crunches","CORE","","bicycle cycling abs",53,{"reps":{"rate":0.25}},{"abs":0.5,"obliques":0.5}],["deadbug","Dead Bug","CORE","","deadbug stability",54,{"reps":{"rate":0.5}},{"lowerback":0.2,"abs":0.8}],["birddog","Bird Dog","CORE","","birddog stability back",55,{"reps":{"rate":0.5}},{"lowerback":0.5,"abs":0.25,"glutes":0.25}],["flutterkick","Flutter Kicks","CORE","","flutter scissor kicks",56,{"reps":{"rate":0.25}},{"abs":0.7,"quads":0.3}],["mountainclimb","Mountain Climbers","CORE","","mountain climber cardio abs",57,{"reps":{"rate":0.25}},{"shoulders":0.2,"abs":0.5,"obliques":0.1,"quads":0.2}],["rollout","Ab Wheel Rollout","CORE","","ab wheel rollout barbell",58,{"reps":{"rate":2.0}},{"shoulders":0.1,"lats":0.2,"lowerback":0.1,"abs":0.6}],["plank","Plank","CORE","","front elbow forearm",59,{"minutes":{"rate":10.0}},{"shoulders":0.2,"lowerback":0.2,"abs":0.6}],["sideplank","Side Plank","CORE","","oblique side",60,{"minutes":{"rate":12.0}},{"shoulders":0.2,"abs":0.1,"obliques":0.7}],["hollowhold","Hollow Hold","CORE","","hollow body",61,{"seconds":{"rate":0.25}},{"abs":0.8,"quads":0.2}],["lsit","L-sit","CORE","","lsit legs parallel",62,{"seconds":{"rate":0.4}},{"triceps":0.2,"abs":0.6,"quads":0.2}],["run","Run","CARDIO","Outdoor or treadmill","running jog jogging",63,{"km":{"rate":5.0}},{"glutes":0.15,"quads":0.3,"hamstrings":0.25,"calves":0.3}],["sprints","Sprint Intervals","CARDIO","One sprint = 15 sec flat out, 100 m minimum","sprint interval hiit",64,{"reps":{"rate":2.0}},{"glutes":0.2,"quads":0.3,"hamstrings":0.3,"calves":0.2}],["bike","Biking","CARDIO","Road / Trail / Stationary","cycling bicycle spin",65,{"km":{"rate":1.5}},{"glutes":0.2,"quads":0.5,"hamstrings":0.1,"calves":0.2}],["swim","Swim","CARDIO","Any stroke, active swim time","swimming pool crawl",66,{"minutes":{"rate":0.5}},{"chest":0.15,"shoulders":0.3,"triceps":0.1,"lats":0.3,"abs":0.15}],["walk","Walking","CARDIO","Hiking counts too","walk hike hiking steps",67,{"km":{"rate":2.5}},{"glutes":0.15,"quads":0.3,"hamstrings":0.2,"calves":0.35}],["row","Rowing Machine","CARDIO","Indoor erg","erg ergometer concept2",68,{"minutes":{"rate":0.5}},{"biceps":0.15,"traps":0.15,"lats":0.3,"lowerback":0.15,"quads":0.25}],["jumprope","Jump Rope","CARDIO","Skipping","skipping rope",69,{"minutes":{"rate":0.55}},{"shoulders":0.15,"quads":0.2,"hamstrings":0.1,"calves":0.55}],["stairs","Stair Climbing","CARDIO","Real stairs or machine","stairmaster steps",70,{"minutes":{"rate":0.5}},{"glutes":0.3,"quads":0.4,"hamstrings":0.1,"calves":0.2}],["football","Football / Soccer","SPORT","Actual playing time, not time at the venue","soccer foot futbol match",71,{"minutes":{"rate":0.25}},{"shoulders":0.1,"abs":0.1,"glutes":0.15,"quads":0.25,"hamstrings":0.2,"calves":0.2}],["basketball","Basketball","SPORT","Actual playing time, not time at the venue","basket hoops ball",72,{"minutes":{"rate":0.25}},{"shoulders":0.1,"abs":0.1,"glutes":0.15,"quads":0.25,"hamstrings":0.15,"calves":0.25}],["rugby","Rugby","SPORT","Actual playing time, not time at the venue","rugby union league",73,{"minutes":{"rate":0.25}},{"shoulders":0.15,"abs":0.1,"glutes":0.15,"quads":0.25,"hamstrings":0.2,"calves":0.15}],["handball","Handball","SPORT","Actual playing time, not time at the venue","hand ball",74,{"minutes":{"rate":0.25}},{"shoulders":0.2,"abs":0.15,"obliques":0.1,"quads":0.25,"hamstrings":0.1,"calves":0.2}],["hockey","Hockey","SPORT","Actual playing time, not time at the venue","ice field puck",75,{"minutes":{"rate":0.25}},{"forearms":0.1,"obliques":0.15,"glutes":0.2,"quads":0.3,"hamstrings":0.15,"calves":0.1}],["squash","Squash","SPORT","Actual playing time, not time at the venue","squash racket court",76,{"minutes":{"rate":0.25}},{"shoulders":0.15,"forearms":0.1,"obliques":0.15,"quads":0.3,"hamstrings":0.1,"calves":0.2}],["boxing","Boxing / Martial Arts","SPORT","Actual playing time, not time at the venue","box mma judo bjj karate muay sparring",77,{"minutes":{"rate":0.25}},{"chest":0.1,"shoulders":0.25,"triceps":0.15,"abs":0.2,"obliques":0.15,"calves":0.15}],["climbing","Climbing","SPORT","Actual playing time, not time at the venue","bouldering rock wall",78,{"minutes":{"rate":0.25}},{"shoulders":0.1,"biceps":0.15,"forearms":0.3,"lats":0.3,"abs":0.15}],["tennis","Tennis","SPORT","Actual playing time, not time at the venue","tennis racket court",79,{"minutes":{"rate":0.166667}},{"shoulders":0.2,"forearms":0.1,"obliques":0.15,"quads":0.25,"hamstrings":0.1,"calves":0.2}],["padel","Padel","SPORT","Actual playing time, not time at the venue","padel paddle",80,{"minutes":{"rate":0.166667}},{"shoulders":0.2,"forearms":0.1,"obliques":0.15,"quads":0.25,"hamstrings":0.1,"calves":0.2}],["volleyball","Volleyball","SPORT","Actual playing time, not time at the venue","volley beach net",81,{"minutes":{"rate":0.166667}},{"shoulders":0.25,"abs":0.1,"quads":0.3,"hamstrings":0.1,"calves":0.25}],["badminton","Badminton","SPORT","Actual playing time, not time at the venue","badminton shuttle",82,{"minutes":{"rate":0.166667}},{"shoulders":0.2,"forearms":0.15,"obliques":0.15,"quads":0.25,"calves":0.25}],["tabletennis","Table Tennis","SPORT","Actual playing time, not time at the venue","ping pong",83,{"minutes":{"rate":0.166667}},{"shoulders":0.25,"forearms":0.2,"obliques":0.2,"quads":0.2,"calves":0.15}],["othersport","Other Sport","SPORT","Actual playing time, not time at the venue","other misc game match",84,{"minutes":{"rate":0.166667}},{"chest":0.075,"shoulders":0.15,"lats":0.075,"abs":0.15,"glutes":0.1,"quads":0.2,"hamstrings":0.1,"calves":0.15}],["gymbench","Bench Press","GYM","Type the total on the bar, not counting your own weight","bench barbell chest press flat",85,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"chest":0.5,"shoulders":0.2,"triceps":0.3}],["gymdbbench","Dumbbell Bench Press","GYM","Type the total on the bar, not counting your own weight","dumbbell db incline chest",86,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"chest":0.5,"shoulders":0.25,"triceps":0.25}],["gymohp","Overhead Press","GYM","Type the total on the bar, not counting your own weight","ohp military shoulder press standing",87,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"shoulders":0.55,"triceps":0.3,"traps":0.15}],["gymdip","Weighted Dips","GYM","Type the total on the bar, not counting your own weight","weighted dip belt",88,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"chest":0.4,"shoulders":0.2,"triceps":0.4}],["gymchestmach","Chest Press (Machine)","GYM","Type the total on the bar, not counting your own weight","machine chest press pec",89,{"reps":{"k":1.5625,"equip":0.75,"legs":false,"pattern":"push"}},{"chest":0.6,"shoulders":0.15,"triceps":0.25}],["gymtricep","Tricep Pushdown","GYM","One side at a time \u2014 type the weight of the single dumbbell","cable pushdown tricep rope",90,{"reps":{"k":1.5625,"equip":0.6,"legs":false,"pattern":"push"}},{"triceps":1.0}],["gymlatraise","Lateral Raise","GYM","One side at a time \u2014 type the weight of the single dumbbell","side delt raise shoulder",91,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"shoulders":0.85,"traps":0.15}],["gymdeadlift","Deadlift","GYM","Type the total on the bar, not counting your own weight","deadlift conventional sumo barbell",92,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"forearms":0.1,"traps":0.15,"lowerback":0.25,"glutes":0.25,"hamstrings":0.25}],["gymbarbellrow","Barbell Row","GYM","Type the total on the bar, not counting your own weight","bent over row pendlay",93,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"biceps":0.2,"forearms":0.1,"traps":0.2,"lats":0.4,"lowerback":0.1}],["gymdbrow","Dumbbell Row","GYM","One side at a time \u2014 type the weight of the single dumbbell","one arm db row",94,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"biceps":0.2,"forearms":0.15,"traps":0.2,"lats":0.45}],["gymlatpull","Lat Pulldown","GYM","Type the total on the bar, not counting your own weight","pulldown machine lats",95,{"reps":{"k":2.0,"equip":0.75,"legs":false,"pattern":"pull"}},{"biceps":0.3,"forearms":0.15,"lats":0.55}],["gymcablerow","Seated Cable Row","GYM","Type the total on the bar, not counting your own weight","cable row seated",96,{"reps":{"k":2.0,"equip":0.6,"legs":false,"pattern":"pull"}},{"biceps":0.2,"forearms":0.1,"traps":0.25,"lats":0.45}],["gymweightpull","Weighted Pull-up","GYM","Type the total on the bar, not counting your own weight","weighted pullup belt",97,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"biceps":0.25,"forearms":0.15,"traps":0.15,"lats":0.45}],["gymcurl","Bicep Curl","GYM","One side at a time \u2014 type the weight of the single dumbbell","curl barbell dumbbell biceps",98,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"biceps":0.8,"forearms":0.2}],["gymfacepull","Face Pull","GYM","Type the total on the bar, not counting your own weight","cable rear delt",99,{"reps":{"k":2.0,"equip":0.6,"legs":false,"pattern":"pull"}},{"shoulders":0.5,"biceps":0.15,"traps":0.35}],["gymsquat","Back Squat","GYM","Type the total on the bar, not counting your own weight","squat barbell back high bar",100,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"lowerback":0.1,"glutes":0.3,"quads":0.45,"hamstrings":0.15}],["gymfrontsquat","Front Squat","GYM","Type the total on the bar, not counting your own weight","front squat clean grip",101,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"lowerback":0.1,"abs":0.15,"glutes":0.2,"quads":0.55}],["gymlegpress","Leg Press","GYM","Type the total on the bar, not counting your own weight","leg press machine",102,{"reps":{"k":0.588,"equip":0.75,"legs":true,"pattern":"legs"}},{"glutes":0.3,"quads":0.55,"hamstrings":0.15}],["gymrdl","Romanian Deadlift","GYM","Type the total on the bar, not counting your own weight","rdl stiff leg hamstring",103,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"lowerback":0.25,"glutes":0.3,"hamstrings":0.45}],["gymhipthrust","Hip Thrust","GYM","Type the total on the bar, not counting your own weight","glute bridge barbell",104,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"lowerback":0.05,"glutes":0.7,"hamstrings":0.25}],["gymlegcurl","Leg Curl","GYM","Type the total on the bar, not counting your own weight","hamstring machine curl",105,{"reps":{"k":0.588,"equip":0.75,"legs":false,"pattern":"legs"}},{"hamstrings":0.9,"calves":0.1}],["gymlegext","Leg Extension","GYM","Type the total on the bar, not counting your own weight","quad machine extension",106,{"reps":{"k":0.588,"equip":0.75,"legs":false,"pattern":"legs"}},{"quads":1.0}],["gymlunge","Weighted Lunge","GYM","Type the total on the bar, not counting your own weight","dumbbell lunge walking",107,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"glutes":0.35,"quads":0.4,"hamstrings":0.25}],["gymcalf","Weighted Calf Raise","GYM","Type the total on the bar, not counting your own weight","calf machine standing",108,{"reps":{"k":0.588,"equip":0.75,"legs":false,"pattern":"legs"}},{"calves":1.0}],["gymcablecrunch","Cable Crunch","GYM","Type the total on the bar, not counting your own weight","cable crunch kneeling abs",109,{"reps":{"k":1.0,"equip":0.6,"legs":false,"pattern":"core"}},{"abs":0.9,"obliques":0.1}],["gymwoodchop","Woodchoppers","GYM","One side at a time \u2014 type the weight of the single dumbbell","woodchop cable oblique rotation",110,{"reps":{"k":1.0,"equip":0.6,"legs":false,"pattern":"core"}},{"shoulders":0.1,"abs":0.2,"obliques":0.7}],["gympullover","Dumbbell Pullover","GYM","Type the total on the bar, not counting your own weight","pullover lats chest",111,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"chest":0.25,"triceps":0.2,"lats":0.55}],["gymshrug","Shrug","GYM","Type the total on the bar, not counting your own weight","shrug traps barbell",112,{"reps":{"k":2.0,"equip":1.0,"legs":false,"pattern":"pull"}},{"forearms":0.15,"traps":0.85}],["gymincline","Incline Bench Press","GYM","Type the total on the bar, not counting your own weight","incline bench upper chest",113,{"reps":{"k":1.5625,"equip":1.0,"legs":false,"pattern":"push"}},{"chest":0.45,"shoulders":0.3,"triceps":0.25}],["gymgoblet","Goblet Squat","GYM","Type the total on the bar, not counting your own weight","goblet kettlebell squat",114,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"abs":0.15,"glutes":0.3,"quads":0.45,"hamstrings":0.1}],["gymstepup","Weighted Step-up","GYM","Type the total on the bar, not counting your own weight","step up box weighted",115,{"reps":{"k":0.588,"equip":1.0,"legs":true,"pattern":"legs"}},{"glutes":0.35,"quads":0.4,"hamstrings":0.15,"calves":0.1}],["stretch","Stretching Session","RECOVERY","At least 10 minutes of stretching, mobility or yoga","stretch mobility yoga flexibility",116,{"flat":{"rate":5.0}},{}],["sauna","Sauna / Cold Plunge","RECOVERY","","sauna ice bath cold recovery",117,{"flat":{"rate":3.0}},{}]]$j$::jsonb) as e
on conflict (key) do update set
  name = excluded.name, cat = excluded.cat, variants = excluded.variants,
  aliases = excluded.aliases, sort = excluded.sort, modes = excluded.modes,
  muscles = excluded.muscles;

insert into public.muscles (key,name,view,target)
select m->>0, m->>1, m->>2, (m->>3)::int
from jsonb_array_elements($j$[["chest","Chest","front",70],["shoulders","Shoulders","both",55],["biceps","Biceps","front",30],["triceps","Triceps","both",40],["forearms","Forearms","both",25],["traps","Traps","both",30],["lats","Lats","back",70],["lowerback","Lower back","back",30],["abs","Abs","front",45],["obliques","Obliques","front",30],["glutes","Glutes","back",55],["quads","Quads","front",85],["hamstrings","Hamstrings","back",55],["calves","Calves","both",25]]$j$::jsonb) as m
on conflict (key) do update set
  name = excluded.name, view = excluded.view, target = excluded.target;
-- BANK END

-- The eight raids, rotating one a week.
insert into public.raids (idx,name,descr,ex_keys,mode,per_member,unit) values
  (0,'THE WALL','Push-ups, all of you, one pile','{pushups,widepush,diamondpush,declinepush,kneepush,inclinepush,archerpush,clappush,sphinxpush}','reps',175,'push-ups'),
  (1,'DEAD LIFT','Pull-ups and rows, together','{pullups,chinups,rows,widepullup,commandopull,archerpull,lsitpullup,typewriter}','reps',25,'pulls'),
  (2,'LEG DAY','Squats until the league cannot walk','{airsquats,jumpsquats,lunges,splitsquat,stepups,sissy,shrimp,pistols}','reps',170,'squats'),
  (3,'THE MARCH','Kilometres covered by the whole league','{run,walk,bike}','km',15,'km'),
  (4,'CORE OF IRON','Every ab rep counts','{crunches,situps,twists,legraises,kneeraises,hangingleg,toestobar,vups,sidecrunch,bicycle,flutterkick,mountainclimb}','reps',150,'reps'),
  (5,'THE DIP TANK','Dips and presses','{dips,benchdips,ringdips,pikepush,handstand}','reps',40,'dips'),
  (6,'LONG HAUL','Minutes of cardio and sport, pooled','{swim,row,jumprope,stairs,football,basketball,rugby,handball,hockey,squash,boxing,climbing,tennis,padel,volleyball,badminton,tabletennis,othersport}','minutes',35,'minutes'),
  (7,'HOLD THE LINE','Seconds of holding still','{hollowhold,lsit,wallsit,deadhang,frontlever}','seconds',45,'seconds');

-- ---------------------------------------------------------------------
delete from public.bounties;
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
-- The bounty pool: 110 side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
insert into public.bounties (idx, name, descr, points, spec) values
(0,'DAWN PRESS','40 push-ups before 09:00',30,'{"reqs":[{"ex":"pushups","mode":"reps","min":40,"to_h":9}]}'),
(1,'CENTURY PUSH','100 push-ups across the day',40,'{"reqs":[{"ex":"pushups","mode":"reps","min":100}]}'),
(2,'DIP MASTER','30 dips',40,'{"reqs":[{"ex":"dips","mode":"reps","min":30}]}'),
(3,'DIP CENTURY','50 dips',50,'{"reqs":[{"ex":"dips","mode":"reps","min":50}]}'),
(4,'SHOULDER BURN','30 pike push-ups',40,'{"reqs":[{"ex":"pikepush","mode":"reps","min":30}]}'),
(5,'CLOSE QUARTERS','35 diamond push-ups',35,'{"reqs":[{"ex":"diamondpush","mode":"reps","min":35}]}'),
(6,'LUNCH PRESS','30 push-ups between 12:00 and 14:00',25,'{"reqs":[{"ex":"pushups","mode":"reps","min":30,"from_h":12,"to_h":14}]}'),
(7,'NIGHTCAP PUSH','40 push-ups after 20:00',30,'{"reqs":[{"ex":"pushups","mode":"reps","min":40,"from_h":20}]}'),
(8,'CLOCK PUNCHER','10 push-ups in each of 5 different hours',40,'{"kind":"hourly","ex":"pushups","each":10,"hours":5}'),
(9,'SPLIT CENTURY','50 push-ups before noon and 50 after',40,'{"kind":"split","ex":"pushups","min":50}'),
(10,'FIRST PULL','10 pull-ups before 10:00',30,'{"reqs":[{"ex":"pullups","mode":"reps","min":10,"to_h":10}]}'),
(11,'ROW COLLECTOR','50 inverted rows',40,'{"reqs":[{"ex":"rows","mode":"reps","min":50}]}'),
(12,'PULL CENTURY','30 pull-ups across the day',50,'{"reqs":[{"ex":"pullups","mode":"reps","min":30}]}'),
(13,'BAR SURGE','20 pull-ups',35,'{"reqs":[{"ex":"pullups","mode":"reps","min":20}]}'),
(14,'PULL AND ROW','15 pull-ups and 30 rows',45,'{"reqs":[{"ex":"pullups","mode":"reps","min":15},{"ex":"rows","mode":"reps","min":30}]}'),
(15,'MIDDAY PULL','15 pull-ups between 12:00 and 15:00',30,'{"reqs":[{"ex":"pullups","mode":"reps","min":15,"from_h":12,"to_h":15}]}'),
(16,'ANY BAR WILL DO','20 pull-ups, 20 chin-ups, or 40 inverted rows',50,'{"kind":"any","any":[{"ex":"pullups","mode":"reps","min":20},{"ex":"chinups","mode":"reps","min":20},{"ex":"rows","mode":"reps","min":40}]}'),
(17,'EVENING LATS','20 pull-ups after 18:00',35,'{"reqs":[{"ex":"pullups","mode":"reps","min":20,"from_h":18}]}'),
(18,'GREASE THE GROOVE','1 pull-up in each of 8 different hours',40,'{"kind":"hourly","ex":"pullups","each":1,"hours":8}'),
(19,'PULL DOUBLE','15 pull-ups before noon and 15 after',45,'{"kind":"split","ex":"pullups","min":15}'),
(20,'MORNING LEGS','100 air squats before 10:00',35,'{"reqs":[{"ex":"airsquats","mode":"reps","min":100,"to_h":10}]}'),
(21,'SPLIT DUTY','50 split squats',40,'{"reqs":[{"ex":"splitsquat","mode":"reps","min":50}]}'),
(22,'STEP MACHINE','100 step-ups',45,'{"reqs":[{"ex":"stepups","mode":"reps","min":100}]}'),
(23,'CORE LOCK','2 minutes of plank',30,'{"reqs":[{"ex":"plank","mode":"minutes","min":2}]}'),
(24,'KNEE RAISE SURGE','60 knee raises',35,'{"reqs":[{"ex":"kneeraises","mode":"reps","min":60}]}'),
(25,'THE HOLLOW','Four minutes of hollow hold',40,'{"reqs":[{"ex":"hollowhold","mode":"seconds","min":240}]}'),
(26,'SQUAT CENTURY','100 air squats',30,'{"reqs":[{"ex":"airsquats","mode":"reps","min":100}]}'),
(27,'AFTERNOON LEGS','80 air squats between 13:00 and 17:00',30,'{"reqs":[{"ex":"airsquats","mode":"reps","min":80,"from_h":13,"to_h":17}]}'),
(28,'CORE AND SQUAT','50 air squats and 30 knee raises',35,'{"reqs":[{"ex":"airsquats","mode":"reps","min":50},{"ex":"kneeraises","mode":"reps","min":30}]}'),
(29,'TWIST AND SQUAT','60 Russian twists and 60 air squats',45,'{"reqs":[{"ex":"twists","mode":"reps","min":60},{"ex":"airsquats","mode":"reps","min":60}]}'),
(30,'EARLY RUN','3 km before 09:00',35,'{"reqs":[{"ex":"run","mode":"km","min":3,"to_h":9}]}'),
(31,'WALK IT OFF','6 km on foot',35,'{"reqs":[{"ex":"walk","mode":"km","min":6}]}'),
(32,'SPRINT FINISHER','10 sprints',35,'{"reqs":[{"ex":"sprints","mode":"reps","min":10}]}'),
(33,'LUNCH WALK','3 km walk between 11:00 and 14:00',25,'{"reqs":[{"ex":"walk","mode":"km","min":3,"from_h":11,"to_h":14}]}'),
(34,'THE LONG WALK','10 km of walking',45,'{"reqs":[{"ex":"walk","mode":"km","min":10}]}'),
(35,'FIVE K','Run 5 km',40,'{"reqs":[{"ex":"run","mode":"km","min":5}]}'),
(36,'DOUBLE MOBILITY','Two separate stretching sessions',25,'{"reqs":[{"ex":"stretch","mode":"flat","min":2}]}'),
(37,'NIGHT WALK','4 km walk after 19:00',30,'{"reqs":[{"ex":"walk","mode":"km","min":4,"from_h":19}]}'),
(38,'MOVE AND STRETCH','3 km on foot and a stretching session',35,'{"reqs":[{"ex":"walk","mode":"km","min":3},{"ex":"stretch","mode":"flat","min":1}]}'),
(39,'ROAD WORK','6 km run',45,'{"reqs":[{"ex":"run","mode":"km","min":6}]}'),
(40,'MORNING DISTANCE','4 km run or 6 km walk before 11:00',40,'{"kind":"any","any":[{"ex":"run","mode":"km","min":4,"to_h":11},{"ex":"walk","mode":"km","min":6,"to_h":11}]}'),
(41,'FULL BODY TRIAD','30 push-ups, 15 pull-ups and 30 air squats',45,'{"reqs":[{"ex":"pushups","mode":"reps","min":30},{"ex":"pullups","mode":"reps","min":15},{"ex":"airsquats","mode":"reps","min":30}]}'),
(42,'DUO SYNC','Train within an hour of somebody else in the league',30,'{"kind":"duo"}'),
(43,'IRON TRIFECTA','20 dips, 10 pull-ups and 50 air squats',45,'{"reqs":[{"ex":"dips","mode":"reps","min":20},{"ex":"pullups","mode":"reps","min":10},{"ex":"airsquats","mode":"reps","min":50}]}'),
(44,'UNDERDOG BOOST','Last in the league this week? Log anything today',50,'{"kind":"underdog"}'),
(45,'MINI MURPH','1.5 km run, 30 push-ups, 15 pull-ups, 45 air squats',60,'{"reqs":[{"ex":"run","mode":"km","min":1.5},{"ex":"pushups","mode":"reps","min":30},{"ex":"pullups","mode":"reps","min":15},{"ex":"airsquats","mode":"reps","min":45}]}'),
(46,'MIDDAY MADNESS','Two different exercises between 12:00 and 13:00',30,'{"kind":"distinct","what":"ex","min":2,"from_h":12,"to_h":13}'),
(47,'CENTURY CLUB','100 reps spread across 3 different exercises',40,'{"kind":"reps_across","exercises":3,"min":100}'),
(48,'PERSONAL RECORD','Beat your own best single day of points',50,'{"kind":"pr"}'),
(49,'TEAM SURGE','If 4 of you log today, everybody scores',30,'{"kind":"team","members":4}'),
(50,'TRIPLE THREAT','Train three different muscle groups today',40,'{"kind":"distinct","what":"cat","min":3}'),
(51,'NIGHT OWL','Two different exercises after 21:00',25,'{"kind":"distinct","what":"ex","min":2,"from_h":21}'),
(52,'MINUTE OF PUSH','As many push-ups as you can in one minute — 30 or more',20,'{"reqs":[{"ex":"pushups","mode":"reps","min":30}]}'),
(53,'THREE-MINUTE PLANK','Three minutes of plank, in as many goes as you like',20,'{"reqs":[{"ex":"plank","mode":"minutes","min":3}]}'),
(54,'SIXTY SQUATS','Sixty air squats — under two minutes if you keep moving',20,'{"reqs":[{"ex":"airsquats","mode":"reps","min":60}]}'),
(55,'DEAD HANG','Ninety seconds hanging from a bar',20,'{"reqs":[{"ex":"deadhang","mode":"seconds","min":90}]}'),
(56,'TEN PULL','Ten pull-ups. That is the whole bounty',20,'{"reqs":[{"ex":"pullups","mode":"reps","min":10}]}'),
(57,'WALL SIT','Two minutes in a wall sit',20,'{"reqs":[{"ex":"wallsit","mode":"seconds","min":120}]}'),
(58,'MOUNTAIN MINUTE','150 mountain climbers',20,'{"reqs":[{"ex":"mountainclimb","mode":"reps","min":150}]}'),
(59,'TEN SPRINTS','Ten sprints',20,'{"reqs":[{"ex":"sprints","mode":"reps","min":10}]}'),
(60,'HOLLOW HOLD','Ninety seconds of hollow hold',20,'{"reqs":[{"ex":"hollowhold","mode":"seconds","min":90}]}'),
(61,'BURST OF DIPS','Twenty dips, any bar or bench',20,'{"kind":"any","any":[{"ex":"dips","mode":"reps","min":20},{"ex":"benchdips","mode":"reps","min":30}]}'),
(62,'FORTY CRUNCH','Forty crunches',20,'{"reqs":[{"ex":"crunches","mode":"reps","min":40}]}'),
(63,'TWO MINUTES OF ANYTHING','Any two minutes of held work — plank, hang, wall sit or L-sit',20,'{"kind":"any","any":[{"ex":"plank","mode":"minutes","min":2},{"ex":"deadhang","mode":"seconds","min":120},{"ex":"wallsit","mode":"seconds","min":120},{"ex":"lsit","mode":"seconds","min":120}]}'),
(64,'PUSH DAY','60 points of pushing and nothing else counts',45,'{"kind":"cat_points","cat":"PUSH","min":60}'),
(65,'PULL DAY','50 points of pulling and nothing else counts',45,'{"kind":"cat_points","cat":"PULL","min":50}'),
(66,'LEG DAY','60 points of legs and nothing else counts',45,'{"kind":"cat_points","cat":"LEGS","min":60}'),
(67,'CORE DAY','45 points of core and nothing else counts',40,'{"kind":"cat_points","cat":"CORE","min":45}'),
(68,'ENDURANCE ONLY','50 points of cardio and nothing else counts',45,'{"kind":"cat_points","cat":"CARDIO","min":50}'),
(69,'LEGS AND CORE','50 points of legs and 40 of core, nothing else counts',50,'{"kind":"cats","cats":[{"cat":"LEGS","min":50},{"cat":"CORE","min":40}]}'),
(70,'FULL BODY LOCK','30 points each of push, pull and legs',55,'{"kind":"cats","cats":[{"cat":"PUSH","min":30},{"cat":"PULL","min":30},{"cat":"LEGS","min":30}]}'),
(71,'UPPER LOCK','40 points of push and 40 of pull, same day',55,'{"kind":"cats","cats":[{"cat":"PUSH","min":40},{"cat":"PULL","min":40}]}'),
(72,'TWO HUNDRED','200 push-ups across the day',60,'{"reqs":[{"ex":"pushups","mode":"reps","min":200}]}'),
(73,'WIDE LOAD','60 wide push-ups',45,'{"reqs":[{"ex":"widepush","mode":"reps","min":60}]}'),
(74,'PIKE POWER','40 pike push-ups',40,'{"reqs":[{"ex":"pikepush","mode":"reps","min":40}]}'),
(75,'DECLINE DAY','50 decline push-ups',45,'{"reqs":[{"ex":"declinepush","mode":"reps","min":50}]}'),
(76,'CHAIR DIPS','70 bench dips',50,'{"reqs":[{"ex":"benchdips","mode":"reps","min":70}]}'),
(77,'CHIN COLLECTOR','40 chin-ups',50,'{"reqs":[{"ex":"chinups","mode":"reps","min":40}]}'),
(78,'HANGING RAISES','30 hanging leg raises',45,'{"reqs":[{"ex":"hangingleg","mode":"reps","min":30}]}'),
(79,'THREE MINUTE HANG','Three minutes hanging from a bar',50,'{"reqs":[{"ex":"deadhang","mode":"seconds","min":180}]}'),
(80,'V FOR VOLUME','80 V-ups',50,'{"reqs":[{"ex":"vups","mode":"reps","min":80}]}'),
(81,'JUMP AND HOLD','60 jump squats and two minutes of wall sit',45,'{"reqs":[{"ex":"jumpsquats","mode":"reps","min":60},{"ex":"wallsit","mode":"seconds","min":120}]}'),
(82,'BRIDGE AND BIRD','120 glute bridges and 60 bird dogs',50,'{"reqs":[{"ex":"gluteBridge","mode":"reps","min":120},{"ex":"birddog","mode":"reps","min":60}]}'),
(83,'JUMP DAY','80 jump squats',45,'{"reqs":[{"ex":"jumpsquats","mode":"reps","min":80}]}'),
(84,'LUNGE MILE','120 lunges',45,'{"reqs":[{"ex":"lunges","mode":"reps","min":120}]}'),
(85,'BRIDGE BUILDER','100 glute bridges',35,'{"reqs":[{"ex":"gluteBridge","mode":"reps","min":100}]}'),
(86,'SIT UP STRAIGHT','120 sit-ups',40,'{"reqs":[{"ex":"situps","mode":"reps","min":120}]}'),
(87,'SIDE ON','Three minutes of side plank, both sides',35,'{"reqs":[{"ex":"sideplank","mode":"minutes","min":3}]}'),
(88,'SUPERMAN','80 supermans',30,'{"reqs":[{"ex":"supermans","mode":"reps","min":80}]}'),
(89,'BICYCLE RACE','150 bicycle crunches',35,'{"reqs":[{"ex":"bicycle","mode":"reps","min":150}]}'),
(90,'CLIMBER','200 mountain climbers',35,'{"reqs":[{"ex":"mountainclimb","mode":"reps","min":200}]}'),
(91,'TEN K','Ten kilometres on foot, running or walking',55,'{"kind":"any","any":[{"ex":"run","mode":"km","min":10},{"ex":"walk","mode":"km","min":12}]}'),
(92,'THE LONG ONE','12 km running, or 15 km walking',45,'{"kind":"any","any":[{"ex":"run","mode":"km","min":12},{"ex":"walk","mode":"km","min":15}]}'),
(93,'FLUTTER','200 flutter kicks',45,'{"reqs":[{"ex":"flutterkick","mode":"reps","min":200}]}'),
(94,'ROW YOUR OWN','80 inverted rows',40,'{"reqs":[{"ex":"rows","mode":"reps","min":80}]}'),
(95,'AGAINST THE WALL','Five minutes of wall sit',45,'{"reqs":[{"ex":"wallsit","mode":"seconds","min":300}]}'),
(96,'SHADOW WORK','300 mountain climbers',40,'{"reqs":[{"ex":"mountainclimb","mode":"reps","min":300}]}'),
(97,'PUSH ONE FIFTY','150 push-ups across the day',45,'{"reqs":[{"ex":"pushups","mode":"reps","min":150}]}'),
(98,'TWO HUNDRED SQUATS','200 air squats',45,'{"reqs":[{"ex":"airsquats","mode":"reps","min":200}]}'),
(99,'FIFTY PULLS','50 pull-ups across the day',55,'{"reqs":[{"ex":"pullups","mode":"reps","min":50}]}'),
(100,'SEVEN HOURS','One set in each of 7 different hours',50,'{"kind":"hourly","ex":"pushups","each":5,"hours":7}'),
(101,'SUNRISE AND SUNSET','30 pull-ups before noon and 30 after',50,'{"kind":"split","ex":"pullups","min":30}'),
(102,'FIVE WAYS','Train five different muscle groups',50,'{"kind":"distinct","what":"cat","min":5}'),
(103,'TEN EXERCISES','Ten different exercises in one day',45,'{"kind":"distinct","what":"ex","min":10}'),
(104,'SPREAD THE LOAD','300 reps across at least 6 exercises',55,'{"kind":"reps_across","exercises":6,"min":300}'),
(105,'BEAT YESTERDAY','Score more points today than on any day before it',45,'{"kind":"pr"}'),
(106,'SIX OF YOU','Six people in the league log something today',45,'{"kind":"team","members":6}'),
(107,'FULL HOUSE','Ten people in the league log something today',60,'{"kind":"team","members":10}'),
(108,'TRAINING PARTNER','Log within an hour of somebody else in the league',35,'{"kind":"duo"}'),
(109,'BACK FROM THE DEAD','Bottom of the table and still turned up',40,'{"kind":"underdog"}');

reset check_function_bodies;
