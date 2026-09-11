\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

-- two people in one league, one of them an admin
insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','MARCO','RC1', true),
  ('aaaaaaaa-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','SARAH','RC2', false);
insert into public.leagues (id, name, code, owner_id) values
  ('bbbbbbbb-0000-0000-0000-000000000001','IRON','TESTAA','aaaaaaaa-0000-0000-0000-000000000001');
insert into public.league_members (league_id, profile_id) values
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001'),
  ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002');

\echo '--- 1. every week of 2026 and 2027 picks a real bounty'
select 'weeks resolved: ' || count(*) || ' / distinct bounties: ' || count(distinct idx)
from (select public.bounty_index((date '2026-01-05' + (n*7))::date) as idx
      from generate_series(0,51) n) t;

\echo '--- 2. no bounty repeats inside a year'
select case when count(*) = count(distinct idx) then 'no repeats in 2026'
            else 'REPEATS FOUND' end
from (select public.bounty_index((date '2026-01-05' + (n*7))::date) as idx
      from generate_series(0,51) n) t;

\echo '--- 3. a different year draws a different order'
select case when a.seq is distinct from b.seq then 'reshuffled for 2027'
            else 'SAME AS LAST YEAR' end
from (select string_agg(public.bounty_index((date '2026-01-05' + (n*7))::date)::text, ',' order by n) seq
      from generate_series(0,51) n) a,
     (select string_agg(public.bounty_index((date '2027-01-04' + (n*7))::date)::text, ',' order by n) seq
      from generate_series(0,51) n) b;

\echo '--- 4. how much of the pool a single year uses'
select 'year uses ' || count(distinct idx) || ' of ' || (select count(*) from public.bounties)
from (select public.bounty_index((date '2026-01-05' + (n*7))::date) as idx
      from generate_series(0,51) n) t;

\echo '--- 5. pinning a week overrides the shuffle'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select 'before pin: ' || public.bounty_pick(public.current_week_start());
select public.admin_pin_bounty(public.current_week_start(), 53, 'micro week');
select case when public.bounty_pick(public.current_week_start()) = 53
            then 'pin honoured' else 'PIN IGNORED' end;
select public.admin_unpin_bounty(public.current_week_start());
select case when public.bounty_pick(public.current_week_start()) <> 53
            or (select count(*) from public.bounties) = 54
            then 'unpin restored the shuffle' else 'UNPIN FAILED' end;

\echo '--- 6. a non-admin cannot pin'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
  perform public.admin_pin_bounty(public.current_week_start(), 1);
  raise exception 'A NON-ADMIN WAS ALLOWED TO PIN';
exception when others then
  if sqlerrm like '%A NON-ADMIN%' then raise; end if;
  raise notice 'non-admin refused: %', sqlerrm;
end $$;

\echo '--- 7. cat_points counts one group and ignores the rest'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001',
        'pullups','reps',40);
select 'pull points today: ' || public.bounty_cat_points(
  'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
  'PULL', (now() at time zone public.app_timezone())::date);
select 'push points today: ' || public.bounty_cat_points(
  'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
  'PUSH', (now() at time zone public.app_timezone())::date);
select case when public.bounty_done(
   'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
   '{"kind":"cat_points","cat":"PULL","min":50}'::jsonb,
   (now() at time zone public.app_timezone())::date)
  then 'PULL DAY done' else 'PULL DAY not done (correct: 40 reps is 80 pts, so it should be done)' end;
select case when public.bounty_done(
   'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
   '{"kind":"cat_points","cat":"PUSH","min":60}'::jsonb,
   (now() at time zone public.app_timezone())::date)
  then 'PUSH DAY WRONGLY DONE' else 'push day correctly not done' end;

\echo '--- 8. the "cats" kind needs both groups'
select case when public.bounty_done(
   'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
   '{"kind":"cats","cats":[{"cat":"PUSH","min":40},{"cat":"PULL","min":40}]}'::jsonb,
   (now() at time zone public.app_timezone())::date)
  then 'UPPER LOCK WRONGLY DONE' else 'upper lock correctly not done (no pushing yet)' end;
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001',
        'pushups','reps',50);
select case when public.bounty_done(
   'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001',
   '{"kind":"cats","cats":[{"cat":"PUSH","min":40},{"cat":"PULL","min":40}]}'::jsonb,
   (now() at time zone public.app_timezone())::date)
  then 'upper lock done once both groups are in' else 'UPPER LOCK STILL NOT DONE' end;

\echo '--- 9. every built-in bounty is reachable and none is impossible'
select 'bounties whose exercise does not exist: ' || count(*)
from public.bounties b,
     lateral jsonb_array_elements(coalesce(b.spec->'reqs', b.spec->'any', '[]'::jsonb)) r
where r->>'ex' is not null
  and not exists (select 1 from public.exercises e where e.key = r->>'ex');

select 'bounties asking for a mode the exercise lacks: ' || count(*)
from public.bounties b,
     lateral jsonb_array_elements(coalesce(b.spec->'reqs', b.spec->'any', '[]'::jsonb)) r
where r->>'ex' is not null and r->>'mode' is not null
  and not exists (select 1 from public.exercises e
                  where e.key = r->>'ex' and e.modes ? (r->>'mode'));

\echo '--- 10. writing a bounty from the control room'
select 'new bounty idx: ' || public.admin_add_bounty(
  'test quest', 'Ten dips before lunch', 25, 'dips', 'reps', 10, null, 12);
select 'pool is now ' || count(*) from public.bounties;
select case when public.admin_delete_bounty(110) is null then 'custom bounty deleted' end;
do $$ begin
  perform public.admin_delete_bounty(3);
  raise exception 'A BUILT-IN WAS DELETED';
exception when others then
  if sqlerrm like '%A BUILT-IN%' then raise; end if;
  raise notice 'built-in protected: %', sqlerrm;
end $$;

\echo '--- 11. a bad bounty is refused'
do $$ begin
  perform public.admin_add_bounty('bad', 'x', 25, 'pushups', 'km', 5);
  raise exception 'AN IMPOSSIBLE BOUNTY WAS ACCEPTED';
exception when others then
  if sqlerrm like '%AN IMPOSSIBLE%' then raise; end if;
  raise notice 'impossible bounty refused: %', sqlerrm;
end $$;

\echo '--- 12. the schedule the control room shows'
select 'weeks listed: ' || count(*) || ', all with a name: ' ||
       (count(*) = count(name))::text from public.admin_schedule();
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

\echo '--- 5 (redone). pin a bounty the shuffle did NOT choose'
select 'shuffle would give: ' || public.bounty_index(public.current_week_start());
select public.admin_pin_bounty(public.current_week_start(),
  case when public.bounty_index(public.current_week_start()) = 7 then 9 else 7 end);
select 'after pin: ' || public.bounty_pick(public.current_week_start());
select case when public.bounty_pick(public.current_week_start())
              <> public.bounty_index(public.current_week_start())
            then 'pin overrides the shuffle' else 'PIN IGNORED' end;
select case when (select pinned from public.admin_schedule()
                  where week_start = public.current_week_start())
            then 'control room shows it as pinned' else 'NOT MARKED PINNED' end;
select public.admin_unpin_bounty(public.current_week_start());
select case when public.bounty_pick(public.current_week_start())
              = public.bounty_index(public.current_week_start())
            then 'unpin restores the shuffle' else 'UNPIN FAILED' end;

\echo '--- 5b. the current bounty a member actually sees follows the pin'
select public.admin_pin_bounty(public.current_week_start(), 55);
select 'members see: ' || name from public.current_bounty('bbbbbbbb-0000-0000-0000-000000000001');
select public.admin_unpin_bounty(public.current_week_start());

\echo '--- 5c. a past week cannot be pinned'
do $$ begin
  perform public.admin_pin_bounty(public.current_week_start() - 7, 1);
  raise exception 'A FINISHED WEEK WAS PINNED';
exception when others then
  if sqlerrm like '%A FINISHED WEEK%' then raise; end if;
  raise notice 'past week refused: %', sqlerrm;
end $$;

\echo '--- 5d. only a Monday can be pinned'
do $$ begin
  perform public.admin_pin_bounty(public.current_week_start() + 3, 1);
  raise exception 'A MID-WEEK DATE WAS PINNED';
exception when others then
  if sqlerrm like '%A MID-WEEK%' then raise; end if;
  raise notice 'mid-week refused: %', sqlerrm;
end $$;

\echo '--- 10 (redone). the custom bounty really goes away'
select 'pool before: ' || count(*) from public.bounties;
select public.admin_delete_bounty(110);
select 'pool after: ' || count(*) from public.bounties;
select case when not exists (select 1 from public.bounties where idx = 110)
            then 'custom bounty deleted' else 'STILL THERE' end;

\echo '--- 13. a micro bounty completes from one short set'
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002',
        'plank','minutes',3);
select case when public.bounty_done(
   'aaaaaaaa-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001',
   (select spec from public.bounties where name = 'THREE-MINUTE PLANK'),
   (now() at time zone public.app_timezone())::date)
  then 'three-minute plank scores' else 'MICRO BOUNTY UNREACHABLE' end;
select 'it is worth ' || points || ' points for '
       || round(extract(epoch from interval '3 minutes')/60) || ' minutes of work'
from public.bounties where name = 'THREE-MINUTE PLANK';

\echo '--- 14. the whole pool is completable in principle'
select 'micro bounties (flat 20): ' || count(*) from public.bounties where points = 20;
select 'muscle-group-only bounties: ' || count(*) from public.bounties
where spec->>'kind' in ('cat_points','cats');
select 'points spread: ' || min(points) || ' to ' || max(points) from public.bounties;
