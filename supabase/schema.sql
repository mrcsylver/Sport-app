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
drop table if exists public.challenges     cascade;
drop table if exists public.workouts       cascade;
drop table if exists public.league_members cascade;
drop table if exists public.leagues        cascade;
drop table if exists public.profiles       cascade;

drop function if exists public.accept_challenge(p_code text) cascade;
drop function if exists public.app_timezone() cascade;
drop function if exists public.bounty_date(p_week date) cascade;
drop function if exists public.bounty_done(p_profile uuid, p_league uuid, p_spec jsonb, p_day date) cascade;
drop function if exists public.bounty_dow() cascade;
drop function if exists public.bounty_index(p_week date) cascade;
drop function if exists public.bounty_req(p_profile uuid, p_league uuid, p_req jsonb, p_day date) cascade;
drop function if exists public.calc_points(p_key text, p_mode text, p_amount numeric) cascade;
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
drop function if exists public.is_rest_day() cascade;
drop function if exists public.join_league_by_code(p_code text) cascade;
drop function if exists public.league_leaderboard(p_league uuid, p_week date) cascade;
drop function if exists public.league_preview(p_code text) cascade;
drop function if exists public.leave_league(p_league uuid) cascade;
drop function if exists public.log_workout(p_league uuid, p_key text, p_mode text, p_amount numeric) cascade;
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
drop function if exists public.shares_league_with(p_profile uuid) cascade;
drop function if exists public.week_bounty_points(p_league uuid, p_week date) cascade;
drop function if exists public.week_combo_bonus(p_league uuid, p_week date) cascade;
drop function if exists public.weekly_history(p_league uuid) cascade;
drop function if exists public.workouts_stamp() cascade;
drop function if exists public.workouts_update_guard() cascade;

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
create function public.is_rest_day() returns boolean
language sql stable set search_path = public as $$
  select extract(isodow from (now() at time zone public.app_timezone())) = 7
$$;

-- Raises if an entry breaks the rest day rule. p_at is the day the entry
-- belongs to, so an edit is judged on its own date, not on today.
create function public.rest_day_check(
  p_profile uuid, p_league uuid, p_key text, p_at timestamptz, p_exclude uuid)
returns void language plpgsql stable set search_path = public as $$
declare
  tz text := public.app_timezone();
  d  date;
begin
  if extract(isodow from (p_at at time zone tz)) <> 7 then return; end if;
  if p_key <> 'stretch' then raise exception 'REST_DAY'; end if;
  d := (p_at at time zone tz)::date;
  if exists (
    select 1 from public.workouts w
    where w.profile_id = p_profile and w.league_id = p_league
      and (w.created_at at time zone tz)::date = d
      and (p_exclude is null or w.id <> p_exclude)
  ) then
    raise exception 'REST_DAY_DONE';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Points engine  (must stay in sync with EXERCISES in app.js)
-- ---------------------------------------------------------------------
create function public.calc_points(p_key text, p_mode text, p_amount numeric)
returns numeric language sql immutable set search_path = public as $$
  select round(coalesce(
    case
      -- PUSH
      when p_key = 'pushups'    and p_mode = 'reps'    then p_amount * 1
      when p_key = 'dips'       and p_mode = 'reps'    then p_amount * 1.5
      when p_key = 'handstand'  and p_mode = 'reps'    then p_amount * 2.5
      when p_key = 'handstand'  and p_mode = 'seconds' then p_amount / 5
      -- PULL
      when p_key = 'rows'       and p_mode = 'reps'    then p_amount * 1
      when p_key = 'pullups'    and p_mode = 'reps'    then p_amount * 2
      when p_key = 'muscleup'   and p_mode = 'reps'    then p_amount * 3.5
      when p_key = 'muscleup'   and p_mode = 'seconds' then p_amount * 2
      -- LEGS
      when p_key = 'airsquats'  and p_mode = 'reps'    then p_amount * 0.5
      when p_key = 'pistols'    and p_mode = 'reps'    then p_amount * 2
      when p_key = 'calves'     and p_mode = 'reps'    then p_amount * 0.2
      -- CORE
      when p_key = 'kneeraises' and p_mode = 'reps'    then p_amount * 1
      when p_key = 'lsit'       and p_mode = 'seconds' then p_amount / 3
      when p_key = 'plank'      and p_mode = 'minutes' then p_amount * 2
      when p_key = 'twists'     and p_mode = 'reps'    then p_amount * 0.25
      -- CARDIO   (a "sprint" is one 15 sec / 100 m effort)
      when p_key = 'run'        and p_mode = 'km'      then p_amount * 5
      when p_key = 'sprints'    and p_mode = 'reps'    then p_amount * 2
      when p_key = 'bike'       and p_mode = 'km'      then p_amount * 1.5
      when p_key = 'swim'       and p_mode = 'minutes' then p_amount * 8 / 60
      when p_key = 'walk'       and p_mode = 'km'      then p_amount * 2.5
      -- RECOVERY (10 minutes minimum)
      when p_key = 'stretch'    and p_mode = 'flat'    then p_amount * 5
    end, 0), 2)
$$;

-- Muscle group of an exercise (used by the stats tab).
create or replace function public.exercise_category(p_key text) returns text
language sql immutable set search_path = public as $$
  select case p_key
    when 'pushups' then 'PUSH'  when 'dips' then 'PUSH'  when 'handstand' then 'PUSH'
    when 'rows' then 'PULL'     when 'pullups' then 'PULL' when 'muscleup' then 'PULL'
    when 'airsquats' then 'LEGS' when 'pistols' then 'LEGS' when 'calves' then 'LEGS'
    when 'kneeraises' then 'CORE' when 'lsit' then 'CORE'
    when 'plank' then 'CORE'     when 'twists' then 'CORE'
    when 'run' then 'CARDIO'    when 'sprints' then 'CARDIO' when 'bike' then 'CARDIO'
    when 'swim' then 'CARDIO'   when 'walk' then 'CARDIO'
    when 'stretch' then 'RECOVERY'
  end
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
  avatar       text check (avatar is null or char_length(avatar) between 1 and 8),
  created_at   timestamptz not null default now()
);

create table public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 2 and 28),
  code        text not null unique
                default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  max_members int  not null default 30 check (max_members between 2 and 30),
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
  week_start    date    not null default current_date,
  created_at    timestamptz not null default now()
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
create table public.bounties (
  idx    int primary key,
  name   text    not null,
  descr  text    not null,
  points numeric not null check (points > 0),
  spec   jsonb   not null
);
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
  if public.is_rest_day() then
    new.amount := 1;                       -- one session, no stacking
  end if;
  new.points := public.calc_points(new.exercise_key, new.mode, new.amount);
  if new.points <= 0 then
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
  new.points := public.calc_points(new.exercise_key, new.mode, new.amount);
  if new.points <= 0 then
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
returns table (id uuid, name text, code text, owner_id uuid,
               members int, max_members int, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.name, l.code, l.owner_id,
         (select count(*)::int from public.league_members m2 where m2.league_id = l.id),
         l.max_members, m.joined_at
  from public.leagues l
  join public.league_members m on m.league_id = l.id
  where m.profile_id = public.my_profile_id()
  order by m.joined_at
$$;

-- The live board. Every member appears, even on 0 points, and each total
-- already includes that week's daily combo bonuses.
create function public.league_leaderboard(p_league uuid, p_week date default null)
returns table (profile_id uuid, display_name text, avatar text,
               points numeric, base_points numeric, bonus numeric,
               entries bigint, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  with wk as (select coalesce(p_week, public.current_week_start()) as w),
  cb as (select * from public.week_combo_bonus(p_league, (select w from wk))),
  bb as (select * from public.week_bounty_points(p_league, (select w from wk)))
  select p.id, p.display_name, p.avatar,
         (coalesce(sum(w.points), 0) + coalesce(max(cb.bonus), 0)
                                     + coalesce(max(bb.bounty), 0))::numeric,
         coalesce(sum(w.points), 0)::numeric,
         (coalesce(max(cb.bonus), 0) + coalesce(max(bb.bounty), 0))::numeric,
         count(w.id), m.joined_at
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join public.workouts w
         on w.profile_id = p.id and w.league_id = p_league
        and w.week_start = (select w from wk)
  left join cb on cb.profile_id = p.id
  left join bb on bb.profile_id = p.id
  where m.league_id = p_league and public.is_member(p_league)
  group by p.id, p.display_name, p.avatar, m.joined_at
  order by 4 desc, 8 asc
$$;

-- Every finished week, best first — used by the Hall of Fame tab.
create function public.weekly_history(p_league uuid)
returns table (week_start date, profile_id uuid, display_name text, avatar text,
               points numeric, entries bigint)
language sql stable security definer set search_path = public as $$
  select t.week_start, t.profile_id, t.display_name, t.avatar,
         (t.pts + coalesce(cb.bonus, 0))::numeric, t.n
  from (
    select w.week_start, p.id as profile_id, p.display_name, p.avatar,
           sum(w.points) as pts, count(*) as n
    from public.workouts w
    join public.profiles p on p.id = w.profile_id
    where w.league_id = p_league
      and w.week_start < public.current_week_start()
      and public.is_member(p_league)
    group by w.week_start, p.id, p.display_name, p.avatar
  ) t
  left join lateral (
    select bonus from public.week_combo_bonus(p_league, t.week_start) b
    where b.profile_id = t.profile_id
  ) cb on true
  order by t.week_start desc, 5 desc
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

-- Log once, counted in every league you belong to.
create function public.log_workout(
  p_league uuid, p_key text, p_mode text, p_amount numeric)
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
  insert into public.workouts (group_id, league_id, profile_id,
                               exercise_key, mode, amount)
  select g, m.league_id, me, p_key, p_mode, p_amount
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

create function public.bounty_index(p_week date) returns int
language sql immutable set search_path = public as $$
  select ((floor((p_week - date '2026-01-05') / 7)::int % 52) + 52) % 52
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

create function public.bounty_done(
  p_profile uuid, p_league uuid, p_spec jsonb, p_day date) returns boolean
language plpgsql stable set search_path = public as $$
declare
  tz   text := public.app_timezone();
  kind text := coalesce(p_spec->>'kind', 'reqs');
  r    jsonb;
  n    int;
begin
  if kind = 'reqs' then
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
  with b as (select * from public.bounties where idx = public.bounty_index(p_week)),
       d as (select public.bounty_date(p_week) as day)
  select m.profile_id, (select points from b)::numeric
  from public.league_members m
  where m.league_id = p_league
    and (select count(*) from b) = 1
    and public.bounty_done(m.profile_id, p_league, (select spec from b), (select day from d))
$$;

create function public.current_bounty(p_league uuid)
returns table (idx int, name text, descr text, points numeric,
               on_date date, mine boolean, winners int, first_name text,
               first_avatar text)
language sql stable security definer set search_path = public as $$
  with wk as (select public.current_week_start() as w),
       b  as (select * from public.bounties where idx = public.bounty_index((select w from wk))),
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
revoke all on function public.combo_threshold()             from public, anon;
revoke all on function public.is_rest_day()                 from public, anon;
revoke all on function public.week_bounty_points(uuid,date) from public, anon;
revoke all on function public.current_bounty(uuid)          from public, anon;
revoke all on function public.bounty_done(uuid,uuid,jsonb,date) from public, anon;
revoke all on function public.bounty_req(uuid,uuid,jsonb,date)  from public, anon;
revoke all on function public.log_workout(uuid,text,text,numeric) from public, anon;
revoke all on function public.create_challenge(uuid)        from public, anon;
revoke all on function public.accept_challenge(text)        from public, anon;
revoke all on function public.cancel_challenge(uuid)        from public, anon;
revoke all on function public.challenge_preview(text)       from public, anon;
revoke all on function public.my_challenges()               from public, anon;
revoke all on function public.exercise_category(text)       from public, anon;
revoke all on function public.current_week_start()          from public, anon;

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
grant execute on function public.my_combo_today(uuid)          to authenticated;
grant execute on function public.week_combo_bonus(uuid, date)  to authenticated;
grant execute on function public.combo_threshold()             to authenticated;
grant execute on function public.is_rest_day()                 to authenticated;
grant execute on function public.bounty_dow()                  to authenticated;
grant execute on function public.bounty_index(date)            to authenticated;
grant execute on function public.bounty_date(date)             to authenticated;
grant execute on function public.week_bounty_points(uuid,date) to authenticated;
grant execute on function public.current_bounty(uuid)          to authenticated;
grant execute on function public.bounty_done(uuid,uuid,jsonb,date) to authenticated;
grant execute on function public.bounty_req(uuid,uuid,jsonb,date)  to authenticated;
grant execute on function public.log_workout(uuid,text,text,numeric) to authenticated;
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
delete from public.bounties;
insert into public.bounties (idx, name, descr, points, spec) values
(0,'DAWN PRESS','40 push-ups before 09:00',30,'{"reqs":[{"ex":"pushups","mode":"reps","min":40,"to_h":9}]}'),
(1,'CENTURY PUSH','100 push-ups across the day',40,'{"reqs":[{"ex":"pushups","mode":"reps","min":100}]}'),
(2,'DIP MASTER','30 dips',40,'{"reqs":[{"ex":"dips","mode":"reps","min":30}]}'),
(3,'DIP CENTURY','50 dips',50,'{"reqs":[{"ex":"dips","mode":"reps","min":50}]}'),
(4,'INVERTED WORLD','60 seconds of handstand hold',40,'{"reqs":[{"ex":"handstand","mode":"seconds","min":60}]}'),
(5,'CEILING PRESS','5 handstand push-ups',35,'{"reqs":[{"ex":"handstand","mode":"reps","min":5}]}'),
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
(16,'SKILL WORK','3 muscle-ups, or a 10 second flag hold',50,'{"kind":"any","any":[{"ex":"muscleup","mode":"reps","min":3},{"ex":"muscleup","mode":"seconds","min":10}]}'),
(17,'EVENING LATS','20 pull-ups after 18:00',35,'{"reqs":[{"ex":"pullups","mode":"reps","min":20,"from_h":18}]}'),
(18,'GREASE THE GROOVE','1 pull-up in each of 8 different hours',40,'{"kind":"hourly","ex":"pullups","each":1,"hours":8}'),
(19,'PULL DOUBLE','15 pull-ups before noon and 15 after',45,'{"kind":"split","ex":"pullups","min":15}'),
(20,'MORNING LEGS','100 air squats before 10:00',35,'{"reqs":[{"ex":"airsquats","mode":"reps","min":100,"to_h":10}]}'),
(21,'PISTOL PURSUIT','10 pistol squats',40,'{"reqs":[{"ex":"pistols","mode":"reps","min":10}]}'),
(22,'PISTOL BURNER','16 pistol squats',45,'{"reqs":[{"ex":"pistols","mode":"reps","min":16}]}'),
(23,'CORE LOCK','2 minutes of plank',30,'{"reqs":[{"ex":"plank","mode":"minutes","min":2}]}'),
(24,'KNEE RAISE SURGE','60 knee raises',35,'{"reqs":[{"ex":"kneeraises","mode":"reps","min":60}]}'),
(25,'THE L','30 seconds of L-sit',35,'{"reqs":[{"ex":"lsit","mode":"seconds","min":30}]}'),
(26,'SQUAT CENTURY','100 air squats',30,'{"reqs":[{"ex":"airsquats","mode":"reps","min":100}]}'),
(27,'AFTERNOON LEGS','80 air squats between 13:00 and 17:00',30,'{"reqs":[{"ex":"airsquats","mode":"reps","min":80,"from_h":13,"to_h":17}]}'),
(28,'CORE AND SQUAT','50 air squats and 30 knee raises',35,'{"reqs":[{"ex":"airsquats","mode":"reps","min":50},{"ex":"kneeraises","mode":"reps","min":30}]}'),
(29,'TWIST AND PISTOL','60 Russian twists and 6 pistol squats',40,'{"reqs":[{"ex":"twists","mode":"reps","min":60},{"ex":"pistols","mode":"reps","min":6}]}'),
(30,'EARLY RUN','3 km before 09:00',35,'{"reqs":[{"ex":"run","mode":"km","min":3,"to_h":9}]}'),
(31,'BIKE TOUR','10 km on the bike',35,'{"reqs":[{"ex":"bike","mode":"km","min":10}]}'),
(32,'SPRINT FINISHER','10 sprints',35,'{"reqs":[{"ex":"sprints","mode":"reps","min":10}]}'),
(33,'LUNCH WALK','3 km walk between 11:00 and 14:00',25,'{"reqs":[{"ex":"walk","mode":"km","min":3,"from_h":11,"to_h":14}]}'),
(34,'POOL SESSION','30 minutes of swimming',40,'{"reqs":[{"ex":"swim","mode":"minutes","min":30}]}'),
(35,'FIVE K','Run 5 km',40,'{"reqs":[{"ex":"run","mode":"km","min":5}]}'),
(36,'DOUBLE MOBILITY','Two separate stretching sessions',25,'{"reqs":[{"ex":"stretch","mode":"flat","min":2}]}'),
(37,'NIGHT WALK','4 km walk after 19:00',30,'{"reqs":[{"ex":"walk","mode":"km","min":4,"from_h":19}]}'),
(38,'SWIM AND STRETCH','20 minutes swimming and a stretching session',35,'{"reqs":[{"ex":"swim","mode":"minutes","min":20},{"ex":"stretch","mode":"flat","min":1}]}'),
(39,'CYCLE CENTURY','15 km on the bike',40,'{"reqs":[{"ex":"bike","mode":"km","min":15}]}'),
(40,'MORNING DISTANCE','4 km run or 12 km bike before 11:00',40,'{"kind":"any","any":[{"ex":"run","mode":"km","min":4,"to_h":11},{"ex":"bike","mode":"km","min":12,"to_h":11}]}'),
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
(51,'NIGHT OWL','Two different exercises after 21:00',25,'{"kind":"distinct","what":"ex","min":2,"from_h":21}');
