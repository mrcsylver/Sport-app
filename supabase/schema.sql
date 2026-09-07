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
drop table if exists public.challenges     cascade;
drop table if exists public.workouts       cascade;
drop table if exists public.league_members cascade;
drop table if exists public.leagues        cascade;
drop table if exists public.profiles       cascade;

drop function if exists public.accept_challenge(p_code text) cascade;
drop function if exists public.app_timezone() cascade;
drop function if exists public.calc_points(p_key text, p_mode text, p_amount numeric) cascade;
drop function if exists public.cancel_challenge(p_id uuid) cascade;
drop function if exists public.challenge_points(p_league uuid, p_profile uuid, p_from timestamptz, p_to timestamptz) cascade;
drop function if exists public.challenge_preview(p_code text) cascade;
drop function if exists public.challenge_status(p_cancelled timestamptz, p_accepted timestamptz, p_ends timestamptz, p_created timestamptz) cascade;
drop function if exists public.combo_threshold() cascade;
drop function if exists public.create_challenge(p_league uuid) cascade;
drop function if exists public.create_league(p_name text) cascade;
drop function if exists public.create_profile(p_name text) cascade;
drop function if exists public.current_week_start() cascade;
drop function if exists public.enforce_league_capacity() cascade;
drop function if exists public.exercise_category(p_key text) cascade;
drop function if exists public.has_open_challenge(p_profile uuid) cascade;
drop function if exists public.is_member(p_league uuid) cascade;
drop function if exists public.join_league_by_code(p_code text) cascade;
drop function if exists public.league_leaderboard(p_league uuid, p_week date) cascade;
drop function if exists public.league_preview(p_code text) cascade;
drop function if exists public.leave_league(p_league uuid) cascade;
drop function if exists public.my_challenges() cascade;
drop function if exists public.my_combo_today(p_league uuid) cascade;
drop function if exists public.my_leagues() cascade;
drop function if exists public.my_profile_id() cascade;
drop function if exists public.my_stats(p_league uuid, p_all boolean) cascade;
drop function if exists public.rename_profile(p_name text) cascade;
drop function if exists public.restore_profile(p_code text) cascade;
drop function if exists public.set_avatar(p_avatar text) cascade;
drop function if exists public.shares_league_with(p_profile uuid) cascade;
drop function if exists public.week_combo_bonus(p_league uuid, p_week date) cascade;
drop function if exists public.weekly_history(p_league uuid) cascade;
drop function if exists public.workouts_stamp() cascade;
drop function if exists public.workouts_update_guard() cascade;
drop function if exists public.is_rest_day() cascade;
drop function if exists public.rest_day_check(p_profile uuid, p_league uuid, p_key text, p_at timestamptz, p_exclude uuid) cascade;

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
      -- CORE
      when p_key = 'kneeraises' and p_mode = 'reps'    then p_amount * 1
      when p_key = 'lsit'       and p_mode = 'seconds' then p_amount / 3
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
    when 'airsquats' then 'LEGS' when 'pistols' then 'LEGS'
    when 'kneeraises' then 'CORE' when 'lsit' then 'CORE'
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

create table public.workouts (
  id            uuid primary key default gen_random_uuid(),
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
create index challenges_ppl_idx    on public.challenges (challenger_id, opponent_id);

create index workouts_board_idx on public.workouts (league_id, week_start);
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
  cb as (select * from public.week_combo_bonus(p_league, (select w from wk)))
  select p.id, p.display_name, p.avatar,
         (coalesce(sum(w.points), 0) + coalesce(max(cb.bonus), 0))::numeric,
         coalesce(sum(w.points), 0)::numeric,
         coalesce(max(cb.bonus), 0)::numeric,
         count(w.id), m.joined_at
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join public.workouts w
         on w.profile_id = p.id and w.league_id = p_league
        and w.week_start = (select w from wk)
  left join cb on cb.profile_id = p.id
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
grant execute on function public.create_challenge(uuid)        to authenticated;
grant execute on function public.accept_challenge(text)        to authenticated;
grant execute on function public.cancel_challenge(uuid)        to authenticated;
grant execute on function public.challenge_preview(text)       to authenticated;
grant execute on function public.my_challenges()               to authenticated;
grant execute on function public.exercise_category(text)       to authenticated;
grant execute on function public.current_week_start()          to authenticated;
