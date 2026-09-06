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
drop table if exists public.workouts       cascade;
drop table if exists public.league_members cascade;
drop table if exists public.leagues        cascade;
drop table if exists public.profiles       cascade;

drop function if exists public.app_timezone()                     cascade;
drop function if exists public.current_week_start()               cascade;
drop function if exists public.calc_points(text, text, numeric)   cascade;
drop function if exists public.my_profile_id()                    cascade;
drop function if exists public.is_member(uuid)                    cascade;
drop function if exists public.shares_league_with(uuid)           cascade;
drop function if exists public.create_profile(text)               cascade;
drop function if exists public.restore_profile(text)              cascade;
drop function if exists public.rename_profile(text)               cascade;
drop function if exists public.league_preview(text)               cascade;
drop function if exists public.create_league(text)                cascade;
drop function if exists public.join_league_by_code(text)          cascade;
drop function if exists public.leave_league(uuid)                 cascade;
drop function if exists public.league_leaderboard(uuid, date)     cascade;
drop function if exists public.weekly_history(uuid)               cascade;
drop function if exists public.my_leagues()                       cascade;

-- ---------------------------------------------------------------------
-- 1. Timezone + week helpers
-- ---------------------------------------------------------------------

-- >>> CHANGE YOUR TIMEZONE HERE <<<
create function public.app_timezone() returns text
language sql immutable as $$ select 'Europe/Paris'::text $$;

-- A "week" runs Monday 00:00 -> Sunday 23:59:59 in the timezone above.
-- This returns the Monday that the current week started on.
create function public.current_week_start() returns date
language sql stable as $$
  select (date_trunc('week', (now() at time zone public.app_timezone())))::date
$$;

-- ---------------------------------------------------------------------
-- 2. Points engine  (must stay in sync with EXERCISES in app.js)
-- ---------------------------------------------------------------------
create function public.calc_points(p_key text, p_mode text, p_amount numeric)
returns numeric language sql immutable as $$
  select round(coalesce(
    case
      when p_key = 'pushups'    and p_mode = 'reps'    then p_amount * 1
      when p_key = 'handstand'  and p_mode = 'reps'    then p_amount * 3
      when p_key = 'handstand'  and p_mode = 'seconds' then p_amount / 5
      when p_key = 'dips'       and p_mode = 'reps'    then p_amount * 1.5
      when p_key = 'pullups'    and p_mode = 'reps'    then p_amount * 3
      when p_key = 'muscleup'   and p_mode = 'reps'    then p_amount * 8
      when p_key = 'muscleup'   and p_mode = 'seconds' then p_amount * 2
      when p_key = 'airsquats'  and p_mode = 'reps'    then p_amount * 0.5
      when p_key = 'pistols'    and p_mode = 'reps'    then p_amount * 3
      when p_key = 'kneeraises' and p_mode = 'reps'    then p_amount * 1
      when p_key = 'lsit'       and p_mode = 'seconds' then p_amount / 3
      when p_key = 'run'        and p_mode = 'km'      then p_amount * 10
      when p_key = 'sprints'    and p_mode = 'minutes' then p_amount * 5
      when p_key = 'stretch'    and p_mode = 'flat'    then p_amount * 2
    end, 0), 2)
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
  created_at   timestamptz not null default now()
);

create table public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 2 and 28),
  code        text not null unique
                default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  max_members int  not null default 20 check (max_members between 2 and 20),
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

create index workouts_board_idx on public.workouts (league_id, week_start);
create index workouts_feed_idx  on public.workouts (profile_id, week_start);
create index members_profile_idx on public.league_members (profile_id);

-- ---------------------------------------------------------------------
-- 4. Triggers: the server (not the phone) decides points and the week
-- ---------------------------------------------------------------------
create or replace function public.workouts_stamp() returns trigger
language plpgsql as $$
begin
  new.created_at := now();
  new.week_start := public.current_week_start();
  new.points     := public.calc_points(new.exercise_key, new.mode, new.amount);
  if new.points <= 0 then
    raise exception 'Unknown exercise or unit (% / %)', new.exercise_key, new.mode;
  end if;
  return new;
end $$;

create trigger workouts_stamp_trg
  before insert on public.workouts
  for each row execute function public.workouts_stamp();

-- Hard cap on league size (default 20).
create or replace function public.enforce_league_capacity() returns trigger
language plpgsql as $$
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
  using (profile_id = public.my_profile_id());

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

-- The live board. Every member appears, even on 0 points.
create function public.league_leaderboard(p_league uuid, p_week date default null)
returns table (profile_id uuid, display_name text, points numeric,
               entries bigint, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name,
         coalesce(sum(w.points), 0)::numeric,
         count(w.id),
         m.joined_at
  from public.league_members m
  join public.profiles p on p.id = m.profile_id
  left join public.workouts w
         on w.profile_id = p.id
        and w.league_id  = p_league
        and w.week_start = coalesce(p_week, public.current_week_start())
  where m.league_id = p_league
    and public.is_member(p_league)
  group by p.id, p.display_name, m.joined_at
  order by 3 desc, 5 asc
$$;

-- Every finished week, best first — used by the Hall of Fame tab.
create function public.weekly_history(p_league uuid)
returns table (week_start date, profile_id uuid, display_name text,
               points numeric, entries bigint)
language sql stable security definer set search_path = public as $$
  select w.week_start, p.id, p.display_name,
         sum(w.points)::numeric, count(*)
  from public.workouts w
  join public.profiles p on p.id = w.profile_id
  where w.league_id = p_league
    and w.week_start < public.current_week_start()
    and public.is_member(p_league)
  group by w.week_start, p.id, p.display_name
  order by w.week_start desc, 4 desc
$$;

-- ---------------------------------------------------------------------
-- 8. Permissions
-- ---------------------------------------------------------------------
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
grant execute on function public.current_week_start()          to authenticated;
