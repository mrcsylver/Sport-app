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
