-- The global cap, and parking an account to free a seat.
--
-- The rule the whole thing has to obey: parking is NOT deleting. Everything
-- the person logged stays, every week they won stays theirs, and putting them
-- back is one switch. They simply stop counting against the cap and drop off
-- live boards, which is what frees the seat for somebody else.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('91111111-1111-1111-1111-111111111111'),
  ('92222222-2222-2222-2222-222222222222'),
  ('93333333-3333-3333-3333-333333333333'),
  ('94444444-4444-4444-4444-444444444444')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('9aaa0000-0000-0000-0000-000000000001','91111111-1111-1111-1111-111111111111','BOSS','CAP1',true),
  ('9aaa0000-0000-0000-0000-000000000002','92222222-2222-2222-2222-222222222222','REGULAR','CAP2',false),
  ('9aaa0000-0000-0000-0000-000000000003','93333333-3333-3333-3333-333333333333','FADER','CAP3',false);

\echo '--- 1. no cap to begin with, which is where a free app starts'
select '  cap ' || coalesce(cap::text,'none') || ' · used ' || used ||
       ' · full ' || is_full from public.signup_state();
select case when (select not is_full from public.signup_state())
       then 'nobody is turned away when no cap is set'
       else 'A CAP APPEARED FROM NOWHERE' end;

\echo '--- 2. the control room sets it, and it bites immediately'
set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
select '  cap set to ' || public.admin_set_cap(3);
select '  cap ' || cap || ' · used ' || used || ' · full ' || is_full
from public.signup_state();
select case when (select is_full from public.signup_state())
       then 'three accounts against a cap of three reads as full'
       else 'THE CAP IS NOT BITING' end;

\echo '--- 3. a fourth person is turned away, and no half-account is left behind'
set request.jwt.claim.sub = '94444444-4444-4444-4444-444444444444';
do $t$ begin
  perform public.create_profile('LATECOMER');
  raise notice 'A FOURTH ACCOUNT WAS CREATED OVER THE CAP';
exception when others then raise notice 'turned away: %', sqlerrm;
end $t$;
select case when (select count(*) from public.profiles) = 3
       then 'still three accounts, nothing half-made'
       else 'A GHOST ACCOUNT WAS LEFT BEHIND' end;

\echo '--- 4. parking somebody frees the seat'
set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
select '  parked ' || display_name from public.admin_set_dormant(
  '9aaa0000-0000-0000-0000-000000000003', true);
select '  cap ' || cap || ' · used ' || used || ' · full ' || is_full
from public.signup_state();
select case when (select not is_full from public.signup_state())
             and (select used from public.signup_state()) = 2
       then 'the seat is free and the count dropped'
       else 'PARKING DID NOT FREE A SEAT' end;
-- and the account is emphatically still there
select case when exists (select 1 from public.profiles
                          where id = '9aaa0000-0000-0000-0000-000000000003'
                            and restore_code = 'CAP3')
       then 'while the account, and its restore code, are untouched'
       else 'PARKING DELETED SOMETHING' end;

\echo '--- 5. so the fourth person gets in'
set request.jwt.claim.sub = '94444444-4444-4444-4444-444444444444';
select '  created ' || display_name from public.create_profile('LATECOMER');
select case when (select is_full from public.signup_state())
       then 'and the door shuts again behind them'
       else 'THE DOOR STAYED OPEN' end;

\echo '--- 6. the parked person comes back to a full app and waits'
set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
do $t$ begin
  perform public.admin_set_dormant('9aaa0000-0000-0000-0000-000000000003', false);
  raise notice 'A PARKED ACCOUNT WOKE INTO A FULL APP';
exception when others then raise notice 'waking refused: %', sqlerrm;
end $t$;
set request.jwt.claim.sub = '93333333-3333-3333-3333-333333333333';
do $t$ begin
  perform public.wake_me();
  raise notice 'A PARKED ACCOUNT WOKE ITSELF INTO A FULL APP';
exception when others then raise notice 'waking itself refused: %', sqlerrm;
end $t$;
select case when (select dormant_at is not null from public.profiles
                   where id = '9aaa0000-0000-0000-0000-000000000003')
       then 'still parked, still intact, waiting for room'
       else 'IT WOKE ANYWAY' end;

\echo '--- 7. raise the cap and they walk straight back in'
set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
select '  cap raised to ' || public.admin_set_cap(10);
set request.jwt.claim.sub = '93333333-3333-3333-3333-333333333333';
select '  woke ' || display_name from public.wake_me();
select case when (select dormant_at is null from public.profiles
                   where id = '9aaa0000-0000-0000-0000-000000000003')
       then 'back in, with everything they had'
       else 'THEY COULD NOT GET BACK IN' end;

\echo '--- 8. and the cap is the control room''s alone'
set request.jwt.claim.sub = '92222222-2222-2222-2222-222222222222';
do $t$ begin
  perform public.admin_set_cap(99999);
  raise notice 'ANYBODY CAN RAISE THE CAP';
exception when others then raise notice 'non-admin refused: %', sqlerrm;
end $t$;
do $t$ begin
  perform public.admin_set_dormant('9aaa0000-0000-0000-0000-000000000003', true);
  raise notice 'ANYBODY CAN PARK ANYBODY';
exception when others then raise notice 'non-admin refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.admin_overview()) = 0
       then 'and the overview is shut to them too'
       else 'THE OVERVIEW IS READABLE BY ANYBODY' end;

\echo '--- 9. an admin cannot park themselves out of the control room'
set request.jwt.claim.sub = '91111111-1111-1111-1111-111111111111';
do $t$ begin
  perform public.admin_set_dormant('9aaa0000-0000-0000-0000-000000000001', true);
  raise notice 'AN ADMIN PARKED THEMSELVES';
exception when others then raise notice 'self-park refused: %', sqlerrm;
end $t$;
select '  overview: cap ' || cap || ' · used ' || used || ' · parked ' || dormant
from public.admin_overview();
