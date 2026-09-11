-- Put a database back to what the live one looks like before the bounty pool
-- migration: 52 quests, the old modulo rotation, no schedule table. Applying
-- the migration to this is the thing that has to work.
delete from public.bounties where idx >= 52;
drop table if exists public.bounty_schedule cascade;
drop function if exists public.bounty_pick(date) cascade;
drop function if exists public.bounty_cat_points(uuid,uuid,text,date) cascade;
drop function if exists public.builtin_bounty_count() cascade;
drop function if exists public.admin_schedule() cascade;
drop function if exists public.admin_bounties() cascade;
drop function if exists public.admin_pin_bounty(date,int,text) cascade;
drop function if exists public.admin_unpin_bounty(date) cascade;
drop function if exists public.admin_add_bounty(text,text,numeric,text,text,numeric,int,int) cascade;
drop function if exists public.admin_delete_bounty(int) cascade;
create or replace function public.bounty_index(p_week date) returns int
language sql immutable set search_path = public as $$
  select ((floor((p_week - date '2026-01-05') / 7)::int % 52) + 52) % 52
$$;

-- and back before the catch-up day
alter table public.leagues  drop column if exists catchup_dow cascade;
alter table public.workouts drop column if exists boost cascade;
drop function if exists public.is_catchup_day(uuid) cascade;
drop function if exists public.catchup_multiplier(uuid,uuid) cascade;
drop function if exists public.catchup_floor() cascade;
drop function if exists public.catchup_ceiling() cascade;
drop function if exists public.catchup_max() cascade;
drop function if exists public.set_league_settings(uuid,int[],int,int) cascade;
-- the stamp trigger knows about the catch-up day; a database that predates it
-- does not, so put the old one back or every insert fails
create or replace function public.workouts_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  new.created_at := now();
  new.week_start := public.current_week_start();
  perform public.rest_day_check(new.profile_id, new.league_id,
                                new.exercise_key, new.created_at, null);
  if public.is_rest_day(new.league_id) then
    new.amount := 1;
  end if;
  new.points := public.calc_points(new.exercise_key, new.mode, new.amount,
                                   new.bodyweight, new.load);
  if new.points <= 0 then
    raise exception 'Unknown exercise or unit (% / %)', new.exercise_key, new.mode;
  end if;
  return new;
end $$;
drop function if exists public.my_leagues() cascade;
create or replace function public.my_leagues()
returns table (id uuid, name text, code text, owner_id uuid, members int,
               max_members int, joined_at timestamptz,
               badge jsonb, rest_dow int[], season_weeks int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.name, l.code, l.owner_id,
         (select count(*)::int from public.league_members m2 where m2.league_id = l.id),
         l.max_members, m.joined_at,
         l.badge, l.rest_dow, l.season_weeks, l.created_at
  from public.leagues l
  join public.league_members m on m.league_id = l.id
  where m.profile_id = public.my_profile_id()
  order by m.joined_at
$$;
