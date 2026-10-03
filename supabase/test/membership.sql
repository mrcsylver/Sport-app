-- Leaving a league, and being taken out of one.
--
-- The thing that makes this worth a test file is what must NOT happen. A
-- membership is one row, but deleting the league it points at cascades the
-- workouts away, and a workout is what a lifetime total is made of. Somebody
-- who leaves their only league to keep a quiet account must come back to the
-- rank they earned, not to zero.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('71111111-1111-1111-1111-111111111111'),
  ('72222222-2222-2222-2222-222222222222'),
  ('73333333-3333-3333-3333-333333333333'),
  ('74444444-4444-4444-4444-444444444444')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('7aaa0000-0000-0000-0000-000000000001','71111111-1111-1111-1111-111111111111','FOUNDER','MB1',false),
  ('7aaa0000-0000-0000-0000-000000000002','72222222-2222-2222-2222-222222222222','SECOND','MB2',false),
  ('7aaa0000-0000-0000-0000-000000000003','73333333-3333-3333-3333-333333333333','THIRD','MB3',false),
  ('7aaa0000-0000-0000-0000-000000000004','74444444-4444-4444-4444-444444444444','BOSS','MB4',true);
insert into public.leagues (id, name, code, owner_id, rest_dow) values
  ('7bbb0000-0000-0000-0000-00000000000a','ALPHA','MEM00A','7aaa0000-0000-0000-0000-000000000001','{}'),
  ('7bbb0000-0000-0000-0000-00000000000b','BETA', 'MEM00B','7aaa0000-0000-0000-0000-000000000002','{}');
-- FOUNDER joined ALPHA first, SECOND a day later, THIRD a day after that.
insert into public.league_members (league_id, profile_id, joined_at) values
  ('7bbb0000-0000-0000-0000-00000000000a','7aaa0000-0000-0000-0000-000000000001','2026-01-01'),
  ('7bbb0000-0000-0000-0000-00000000000a','7aaa0000-0000-0000-0000-000000000002','2026-01-02'),
  ('7bbb0000-0000-0000-0000-00000000000a','7aaa0000-0000-0000-0000-000000000003','2026-01-03'),
  ('7bbb0000-0000-0000-0000-00000000000b','7aaa0000-0000-0000-0000-000000000002','2026-01-04'),
  ('7bbb0000-0000-0000-0000-00000000000b','7aaa0000-0000-0000-0000-000000000003','2026-01-05');

set request.jwt.claim.sub = '73333333-3333-3333-3333-333333333333';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('7bbb0000-0000-0000-0000-00000000000a','7aaa0000-0000-0000-0000-000000000003','pushups','reps',100),
       ('7bbb0000-0000-0000-0000-00000000000b','7aaa0000-0000-0000-0000-000000000003','pushups','reps',40);

\echo '--- 1. leaving one league does not touch the others'
select '  THIRD is in ' || count(*) || ' leagues before'
from public.league_members where profile_id = '7aaa0000-0000-0000-0000-000000000003';
select public.leave_league('7bbb0000-0000-0000-0000-00000000000a');
select case when (select count(*) from public.league_members
                   where profile_id = '7aaa0000-0000-0000-0000-000000000003') = 1
             and exists (select 1 from public.league_members
                          where profile_id = '7aaa0000-0000-0000-0000-000000000003'
                            and league_id = '7bbb0000-0000-0000-0000-00000000000b')
       then 'out of ALPHA, still in BETA'
       else 'LEAVING ONE LEAGUE TOOK THE OTHER' end;
select case when (select count(*) from public.my_leagues()) = 1
       then 'and the app only offers the one that is left'
       else 'MY_LEAGUES DISAGREES' end;

\echo '--- 2. the league and what was logged in it both survive'
-- This is the whole point. league_members is one row; the league is where the
-- workouts live, and the workouts are the lifetime total.
select case when exists (select 1 from public.leagues
                          where id = '7bbb0000-0000-0000-0000-00000000000a')
             and (select count(*) from public.workouts
                   where league_id = '7bbb0000-0000-0000-0000-00000000000a') = 1
       then 'the league is still there and so is the work logged into it'
       else 'LEAVING DELETED HISTORY' end;
select '  lifetime after leaving: ' ||
  coalesce((select points from public.life_scored_all()
            where profile_id = '7aaa0000-0000-0000-0000-000000000003'), 0);
select case when coalesce((select points from public.life_scored_all()
                   where profile_id = '7aaa0000-0000-0000-0000-000000000003'), 0) >= 100
       then 'and the lifetime total still counts both leagues'
       else 'LEAVING A LEAGUE COST SOMEBODY THEIR RANK' end;

\echo '--- 3. leaving the last one leaves an account with no league at all'
select public.leave_league('7bbb0000-0000-0000-0000-00000000000b');
select case when (select count(*) from public.my_leagues()) = 0
             and exists (select 1 from public.profiles
                          where id = '7aaa0000-0000-0000-0000-000000000003')
       then 'no leagues, and the account is still standing'
       else 'THE ACCOUNT WENT WITH THE LAST LEAGUE' end;
select case when coalesce((select points from public.life_scored_all()
                   where profile_id = '7aaa0000-0000-0000-0000-000000000003'), 0) >= 100
       then 'with the lifetime total intact'
       else 'THE LAST LEAVE WIPED THE RANK' end;

\echo '--- 4. when the owner walks out, the league goes to whoever has been in it longest'
select '  ALPHA owner before: ' || (select p.display_name from public.leagues l
  join public.profiles p on p.id = l.owner_id
  where l.id = '7bbb0000-0000-0000-0000-00000000000a');
set request.jwt.claim.sub = '71111111-1111-1111-1111-111111111111';
select public.leave_league('7bbb0000-0000-0000-0000-00000000000a');
select '  ALPHA owner after : ' || (select p.display_name from public.leagues l
  join public.profiles p on p.id = l.owner_id
  where l.id = '7bbb0000-0000-0000-0000-00000000000a');
select case when (select owner_id from public.leagues
                   where id = '7bbb0000-0000-0000-0000-00000000000a')
                = '7aaa0000-0000-0000-0000-000000000002'
       then 'SECOND has it, so the settings are still reachable'
       else 'THE LEAGUE IS ORPHANED' end;

\echo '--- 5. the last one out stays the owner, so the code hands it back'
set request.jwt.claim.sub = '72222222-2222-2222-2222-222222222222';
select public.leave_league('7bbb0000-0000-0000-0000-00000000000a');
select case when (select count(*) from public.league_members
                   where league_id = '7bbb0000-0000-0000-0000-00000000000a') = 0
             and (select owner_id from public.leagues
                   where id = '7bbb0000-0000-0000-0000-00000000000a')
                = '7aaa0000-0000-0000-0000-000000000002'
       then 'empty, still owned, still there'
       else 'AN EMPTY LEAGUE LOST ITS OWNER OR ITSELF' end;
select case when (select name from public.join_league_by_code('MEM00A')) = 'ALPHA'
       then '  rejoined ALPHA' else '  REJOIN FAILED' end;
select case when (select count(*) from public.my_leagues()) >= 1
       then 'and rejoining with the code gives it straight back'
       else 'THE OWNER COULD NOT GET BACK IN' end;

\echo '--- 6. the control room can take one person out of one league'
set request.jwt.claim.sub = '74444444-4444-4444-4444-444444444444';
select '  BETA holds: ' || string_agg(display_name, ', ' order by display_name)
from public.admin_memberships() where league_name = 'BETA';
select public.admin_remove_member('7bbb0000-0000-0000-0000-00000000000b',
                                  '7aaa0000-0000-0000-0000-000000000002');
select case when not exists (select 1 from public.league_members
                              where league_id = '7bbb0000-0000-0000-0000-00000000000b'
                                and profile_id = '7aaa0000-0000-0000-0000-000000000002')
             and exists (select 1 from public.profiles
                          where id = '7aaa0000-0000-0000-0000-000000000002')
       then 'out of BETA, and the account is untouched'
       else 'THE KICK TOOK THE ACCOUNT WITH IT' end;
select case when (select restore_code from public.profiles
                   where id = '7aaa0000-0000-0000-0000-000000000002') is not null
             and (select count(*) from public.league_members
                   where profile_id = '7aaa0000-0000-0000-0000-000000000002') >= 1
       then 'with its restore code and its other league'
       else 'THE KICK WENT WIDER THAN ONE LEAGUE' end;

\echo '--- 7. and somebody who is not an admin cannot'
set request.jwt.claim.sub = '73333333-3333-3333-3333-333333333333';
do $t$ begin
  perform public.admin_remove_member('7bbb0000-0000-0000-0000-00000000000b',
                                     '7aaa0000-0000-0000-0000-000000000003');
  raise notice 'A NON-ADMIN KICKED SOMEBODY';
exception when others then raise notice 'non-admin refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.admin_memberships()) = 0
       then 'and the membership list is shut to them too'
       else 'THE MEMBERSHIP LIST IS READABLE BY ANYBODY' end;

\echo '--- 8. removing somebody who is not there says so'
set request.jwt.claim.sub = '74444444-4444-4444-4444-444444444444';
do $t$ begin
  perform public.admin_remove_member('7bbb0000-0000-0000-0000-00000000000b',
                                     '7aaa0000-0000-0000-0000-000000000001');
  raise notice 'A GHOST WAS REMOVED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
