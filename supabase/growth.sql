-- ======================================================================
--  IRON LEAGUE — is the thing growing, and does anybody come back
--
--  Paste the whole file into the Supabase SQL editor and press RUN, or apply
--  it over the API. Safe to run twice. NOTHING LOGGED IS TOUCHED and no
--  points move: it only ADDS two read-only functions the control room asks.
--
--  There is no analytics table and there never will be. Nothing is written
--  when somebody opens the app, no third party is told anything, and both
--  numbers below are derived on read from rows that already exist — the same
--  way divisions, streaks, badges and the season table work.
--
--  WHAT `landed` IS, AND WHY IT IS THE INTERESTING ONE. The app signs in
--  anonymously the moment a page loads, and only writes a profile when
--  somebody types a name. So a row in auth.users with no profile behind it
--  is exactly one person who scanned a poster, looked at the first screen,
--  and left. joined/landed is the poster's conversion rate, and it is the
--  only number here that distinguishes "the poster is not working" from
--  "the poster is working and the first screen is not".
--
--  It counts devices, not people: a phone that clears its site data and
--  comes back lands twice, and somebody who scans on the bus and again at
--  the gym lands twice. So landed is a ceiling and the percentage is a
--  floor. Week over week it is still the right shape to watch, which is all
--  it is for.
--
--  Both are admin-only, through the same `where public.is_admin()` as every
--  other control-room function, and both are revoked from `anon` on the way
--  in rather than later.
-- ======================================================================

drop function if exists public.admin_growth(p_weeks int) cascade;
drop function if exists public.admin_retention(p_weeks int) cascade;

create function public.admin_growth(p_weeks int default 12)
returns table (week_start date, landed int, joined int, active int, workouts int)
language sql stable security definer set search_path = public as $$
  with weeks as (
    select (public.current_week_start() - (n * 7))::date as w
    from generate_series(0, greatest(coalesce(p_weeks, 12), 1) - 1) n)
  select wk.w,
         (select count(*)::int from auth.users u
           where (u.created_at at time zone public.app_timezone())::date
                 between wk.w and wk.w + 6),
         (select count(*)::int from public.profiles p
           where (p.created_at at time zone public.app_timezone())::date
                 between wk.w and wk.w + 6),
         (select count(distinct x.profile_id)::int from public.workouts x
           where x.week_start = wk.w),
         (select count(distinct x.group_id)::int from public.workouts x
           where x.week_start = wk.w)
  from weeks wk
  where public.is_admin()
  order by wk.w desc
$$;

create function public.admin_retention(p_weeks int default 10)
returns table (week_start date, size int, back_1 int, back_2 int, back_4 int)
language sql stable security definer set search_path = public as $$
  with weeks as (
    select (public.current_week_start() - (n * 7))::date as w
    from generate_series(1, greatest(coalesce(p_weeks, 10), 1)) n),
  cohort as (
    select wk.w, p.id
    from weeks wk
    join public.profiles p
      on (p.created_at at time zone public.app_timezone())::date
         between wk.w and wk.w + 6),
  back as (
    select c.w, k.n,
           count(distinct c.id) filter (
             where exists (select 1 from public.workouts x
                            where x.profile_id = c.id
                              and x.week_start = c.w + (k.n * 7))) as came
    from cohort c, (values (1), (2), (4)) as k(n)
    group by c.w, k.n)
  select wk.w,
         (select count(*)::int from cohort c where c.w = wk.w),
         -- STRICTLY before this week: the target week has to be FINISHED, not
         -- merely started. On a Tuesday, "did last week's joiners come back
         -- this week" is a question about one day, and answering it 0 makes
         -- every recent cohort look like a disaster that it is not.
         case when wk.w + 7  < public.current_week_start()
              then (select came::int from back where back.w = wk.w and back.n = 1) end,
         case when wk.w + 14 < public.current_week_start()
              then (select came::int from back where back.w = wk.w and back.n = 2) end,
         case when wk.w + 28 < public.current_week_start()
              then (select came::int from back where back.w = wk.w and back.n = 4) end
  from weeks wk
  where public.is_admin()
  order by wk.w desc
$$;

revoke all on function public.admin_growth(int)    from public, anon;
revoke all on function public.admin_retention(int) from public, anon;
grant execute on function public.admin_growth(int)    to authenticated;
grant execute on function public.admin_retention(int) to authenticated;

do $$ begin
  if (select count(*) from public.admin_growth(4)) = 0 then
    raise notice 'growth installed (you are not an admin, so it answered nothing)';
  else
    raise notice 'growth installed';
  end if;
end $$;
