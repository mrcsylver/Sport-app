-- Guessing a restore code at machine speed.
--
-- A restore code is 8 hex characters: 32 bits, and whoever has one owns the
-- account it belongs to. Among friends that is fine, because the only way to
-- try one is to type it. Behind a QR code on a public wall it is a number a
-- script can walk. These checks are about the throttle that makes that
-- expensive -- and about the two ways a throttle like this usually goes
-- wrong: locking out the innocent, and counting the wrong thing.
--
-- The counting is the subtle half. restore_profile() answers a code that
-- matches nothing with ZERO ROWS rather than an exception, because one call
-- is one transaction: a raise on the way out would roll back the very row
-- that records the failure. Written the obvious way, this throttle counted
-- to zero forever. Section 2 is the check that would have caught it.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('c1111111-1111-1111-1111-111111111111'),
  ('c2222222-2222-2222-2222-222222222222'),
  ('c3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('cccc0000-0000-0000-0000-000000000001','c1111111-1111-1111-1111-111111111111','VICTIM','AAAA1111'),
  ('cccc0000-0000-0000-0000-000000000002','c2222222-2222-2222-2222-222222222222','GUESSER','BBBB2222');

\echo '--- 1. a wrong code is answered with nothing, not an error'
-- People mistype their own code, so the first ten are allowed. Each one is
-- a plain empty answer: the app turns that into "no profile has that code".
set request.jwt.claim.sub = 'c2222222-2222-2222-2222-222222222222';
do $t$
declare i int; rows_back int; quiet int := 0;
begin
  for i in 1..10 loop
    select count(*) into rows_back
      from public.restore_profile('DEAD' || lpad(i::text, 4, '0'));
    if rows_back = 0 then quiet := quiet + 1; end if;
  end loop;
  raise notice 'ten wrong codes, ten empty answers, no exception: %', quiet = 10;
exception when others then raise notice 'A WRONG CODE RAISED: %', sqlerrm;
end $t$;

\echo '--- 2. the failures were actually recorded'
-- The whole point. A rollback here is invisible from the app -- the caller
-- sees the same empty answer either way -- and silently disarms the lock.
select case when (select count(*) from public.restore_tries
                   where user_id = 'c2222222-2222-2222-2222-222222222222') = 10
       then 'ten failures survived the calls that caused them'
       else 'THE COUNTER IS WRONG' end;

\echo '--- 3. the eleventh is refused before the lookup even happens'
do $t$ begin
  perform public.restore_profile('DEAD9999');
  raise notice 'THE THROTTLE DID NOT FIRE';
exception when others then raise notice 'guess 11: %', sqlerrm;
end $t$;

\echo '--- 4. and the REAL code is refused too, once they are throttled'
-- A script that happens to hit the right code on guess 300 still cannot
-- spend it, which is the only reason a throttle on this is worth anything.
do $t$ begin
  perform public.restore_profile('AAAA1111');
  raise notice 'A THROTTLED CALLER STILL GOT IN';
exception when others then raise notice 'even the right code: %', sqlerrm;
end $t$;
select case when (select user_id from public.profiles where display_name = 'VICTIM')
            = 'c1111111-1111-1111-1111-111111111111'
       then 'so the account they were guessing at never moved'
       else 'THE ACCOUNT WAS TAKEN' end;

\echo '--- 5. somebody else is not punished for the guesser'
set request.jwt.claim.sub = 'c3333333-3333-3333-3333-333333333333';
select '  restored as ' || display_name from public.restore_profile('AAAA1111');
select case when (select user_id from public.profiles where display_name = 'VICTIM')
            = 'c3333333-3333-3333-3333-333333333333'
       then 'a clean caller with the right code gets straight in'
       else 'A CLEAN CALLER WAS BLOCKED' end;

\echo '--- 6. success is never counted, so a correct code never locks you out'
do $t$
declare i int;
begin
  for i in 1..15 loop
    perform public.restore_profile('AAAA1111');
  end loop;
  raise notice 'fifteen correct restores in a row: still fine';
exception when others then raise notice 'A CORRECT CODE WAS THROTTLED: %', sqlerrm;
end $t$;
select case when (select count(*) from public.restore_tries
                   where user_id = 'c3333333-3333-3333-3333-333333333333') = 0
       then 'and nothing was written against them'
       else 'SUCCESSES ARE BEING COUNTED' end;

\echo '--- 7. the window rolls, so a lockout is not forever'
update public.restore_tries set tried_at = now() - interval '2 hours'
 where user_id = 'c2222222-2222-2222-2222-222222222222';
set request.jwt.claim.sub = 'c2222222-2222-2222-2222-222222222222';
do $t$
declare rows_back int;
begin
  select count(*) into rows_back from public.restore_profile('DEADBEEF');
  raise notice 'an hour later they are asked again: %', rows_back = 0;
exception when others then raise notice 'STILL LOCKED OUT: %', sqlerrm;
end $t$;
select case when (select count(*) from public.restore_tries
                   where user_id = 'c2222222-2222-2222-2222-222222222222') = 1
       then 'the old failures aged out on the way past, only the new one counts'
       else 'THE WINDOW IS NOT ROLLING' end;

\echo '--- 8. nobody can read or write the attempt log directly'
-- RLS on with no policy at all: the only way in is the SECURITY DEFINER
-- function above, so a caller cannot clear their own record.
select case when (select relrowsecurity from pg_class
                   where oid = 'public.restore_tries'::regclass)
            and (select count(*) from pg_policies
                  where tablename = 'restore_tries') = 0
       then 'locked, and no policy opens it'
       else 'THE ATTEMPT LOG IS REACHABLE' end;
