-- ======================================================================
--  IRON LEAGUE — where somebody can be found, and the sheet for the wall
--
--  Paste the whole file into the Supabase SQL editor and press RUN, or apply
--  it over the API. Safe to run twice. NOTHING LOGGED IS TOUCHED and no
--  points move.
--
--  TWO THINGS.
--
--  1. AN INSTAGRAM AND A SNAPCHAT HANDLE on a profile, both optional and
--     blank by default. Two columns rather than one "socials" box, because a
--     handle you can link to is worth something and a string somebody typed
--     is not: these become instagram.com/<handle> and
--     snapchat.com/add/<handle>, and anything that is not a handle is refused
--     on the way in rather than rendered as a dead link. A leading @ is
--     stripped rather than refused -- everybody types it.
--
--     They show on the player card, which is already only openable by
--     somebody who shares a league with you: the same people who can already
--     see the name and the grade. Nothing new is exposed to strangers.
--
--  2. THE FULL RANKING OF EVERY FINISHED WEEK, for the control room. The
--     HALL tab shows the most recent winner with the rest folded away, which
--     is right for a player and useless for printing a sheet to pin up.
--     weekly_history() could not answer it either: it is gated on
--     `is_member`, so an admin who is not IN that league gets nothing back.
--     admin_league_weeks() is the same arithmetic without that gate, with the
--     places worked out.
--
--  player_card() is DROPPED and recreated rather than replaced, because
--  `create or replace` cannot change a return type and two columns are being
--  added to it.
-- ======================================================================

alter table public.profiles
  add column if not exists instagram text,
  add column if not exists snapchat text;
do $$ begin
  alter table public.profiles add constraint profiles_instagram_ck
    check (instagram is null or instagram ~ '^[A-Za-z0-9._]{1,30}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.profiles add constraint profiles_snapchat_ck
    check (snapchat is null or snapchat ~ '^[A-Za-z0-9._-]{1,30}$');
exception when duplicate_object then null; end $$;

drop function if exists public.player_card(uuid) cascade;
drop function if exists public.admin_socials() cascade;
drop function if exists public.admin_league_weeks(uuid, int) cascade;

create or replace function public.set_social(p_instagram text, p_snapchat text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := public.my_profile_id(); row public.profiles;
        ig text; sc text;
begin
  if me is null then raise exception 'NO_PROFILE'; end if;
  ig := nullif(btrim(regexp_replace(coalesce(p_instagram, ''), '^@+', '')), '');
  sc := nullif(btrim(regexp_replace(coalesce(p_snapchat, ''), '^@+', '')), '');
  if ig is not null and ig !~ '^[A-Za-z0-9._]{1,30}$' then
    raise exception 'That is not an Instagram handle — letters, numbers, dots and underscores only';
  end if;
  if sc is not null and sc !~ '^[A-Za-z0-9._-]{1,30}$' then
    raise exception 'That is not a Snapchat handle — letters, numbers, dots, dashes and underscores only';
  end if;
  update public.profiles set instagram = ig, snapchat = sc
   where id = me returning * into row;
  return row;
end $$;


create function public.player_card(p_profile uuid)
returns table (profile_id uuid, display_name text, avatar text, banner text,
               name_color text, frame text, bio text,
               pinned_badges text[], lifetime numeric, joined_at timestamptz,
               instagram text, snapchat text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.avatar, p.banner, p.name_color, p.frame,
         p.bio, p.pinned_badges,
         coalesce((select sum(public.tier_points(x.raw, x.cap))
                   from (select sum(o.points) as raw, max(e.cap) as cap
                         from (select distinct on (w.group_id)
                                      w.group_id, w.exercise_key, w.week_start, w.points
                               from public.workouts w
                               where w.profile_id = p.id
                               order by w.group_id, w.league_id) o
                         left join public.exercises e on e.key = o.exercise_key
                         group by o.week_start, o.exercise_key) x), 0)::numeric,
         (select min(m.joined_at) from public.league_members m where m.profile_id = p.id),
         p.instagram, p.snapchat
  from public.profiles p
  where p.id = p_profile
    and (p.user_id = auth.uid() or public.shares_league_with(p.id))
$$;


create function public.admin_socials()
returns table (profile_id uuid, display_name text, instagram text,
               snapchat text, last_log timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name, p.instagram, p.snapchat,
         (select max(w.created_at) from public.workouts w where w.profile_id = p.id)
  from public.profiles p
  where public.is_admin()
    and (p.instagram is not null or p.snapchat is not null)
  order by p.display_name
$$;


create function public.admin_league_weeks(p_league uuid, p_weeks int default 12)
returns table (week_start date, place int, profile_id uuid,
               display_name text, points numeric, entries bigint)
language sql stable security definer set search_path = public as $$
  with wk as (
    select distinct w.week_start
    from public.workouts w
    where w.league_id = p_league and w.week_start < public.current_week_start()
    order by 1 desc
    limit greatest(coalesce(p_weeks, 12), 1)),
  base as (
    select e.week_start, p.id as profile_id, p.display_name,
           sum(public.tier_points(e.raw, e.cap)) as pts, sum(e.n) as n
    from (select w.week_start, w.profile_id, w.exercise_key,
                 sum(w.points) as raw, count(*) as n, max(x.cap) as cap
          from public.workouts w
          left join public.exercises x on x.key = w.exercise_key
          where w.league_id = p_league
            and w.week_start in (select week_start from wk)
          group by 1, 2, 3) e
    join public.profiles p on p.id = e.profile_id
    group by e.week_start, p.id, p.display_name),
  tot as (
    select b.week_start, b.profile_id, b.display_name, b.n,
           (b.pts + coalesce(cb.bonus, 0) + coalesce(bb.bounty, 0))::numeric as pts
    from base b
    left join lateral (select bonus from public.week_combo_bonus(p_league, b.week_start) c
                        where c.profile_id = b.profile_id) cb on true
    left join lateral (select bounty from public.week_bounty_points(p_league, b.week_start) c
                        where c.profile_id = b.profile_id) bb on true)
  select t.week_start,
         row_number() over (partition by t.week_start order by t.pts desc,
                            t.display_name)::int,
         t.profile_id, t.display_name, t.pts, t.n
  from tot t
  where public.is_admin()
  order by t.week_start desc, 2
$$;


revoke all on function public.set_social(text,text)          from public, anon;
revoke all on function public.player_card(uuid)              from public, anon;
revoke all on function public.admin_socials()                from public, anon;
revoke all on function public.admin_league_weeks(uuid,int)   from public, anon;
grant execute on function public.set_social(text,text)         to authenticated;
grant execute on function public.player_card(uuid)             to authenticated;
grant execute on function public.admin_socials()               to authenticated;
grant execute on function public.admin_league_weeks(uuid,int)  to authenticated;

do $$ begin raise notice 'handles and the week sheet are in'; end $$;
