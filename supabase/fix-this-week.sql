-- ======================================================================
--  Put this week's bounty back to the one people were actually doing.
--
--  Running bounty-pool.sql mid-week changed which quest the week was for,
--  and because bounty points are worked out on read rather than stored,
--  anybody who had already finished the old one lost the points for it.
--  This pins the week back to the quest it started with.
--
--  Paste into the Supabase SQL editor and press RUN. Safe to run twice.
--  From next Monday the new shuffle takes over on its own.
-- ======================================================================
insert into public.bounty_schedule (week_start, bounty_idx, note)
select public.current_week_start(),
       -- what the old rotation would have given this week
       ((floor((public.current_week_start() - date '2026-01-05') / 7)::int % 52) + 52) % 52,
       'kept from the old rotation: this week was already being played'
on conflict (week_start) do nothing;

-- what the week is now set to
select b.idx, b.name, b.descr, b.points
from public.bounty_schedule s
join public.bounties b on b.idx = s.bounty_idx
where s.week_start = public.current_week_start();
