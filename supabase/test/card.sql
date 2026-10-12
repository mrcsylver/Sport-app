-- The card you get when you tap somebody's face on the board.
--
-- It is a function and not a wider leaderboard for two reasons, and both of
-- them are checked here: a board is polled every 25 seconds by everybody
-- with the app open, so nothing belongs on it that is read once; and
-- `profiles` is readable only for your own row, deliberately, because that
-- row carries a restore code. A card therefore has to CHOOSE what it
-- returns, and the whole value of this file is proving what it chose.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('f1111111-1111-1111-1111-111111111111'),
  ('f2222222-2222-2222-2222-222222222222'),
  ('f3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, bodyweight) values
  ('ffff0000-0000-0000-0000-000000000001','f1111111-1111-1111-1111-111111111111','LIFTER','CARD0001', 82),
  ('ffff0000-0000-0000-0000-000000000002','f2222222-2222-2222-2222-222222222222','TEAMMATE','CARD0002', 70),
  ('ffff0000-0000-0000-0000-000000000003','f3333333-3333-3333-3333-333333333333','OUTSIDER','CARD0003', 90);

set request.jwt.claim.sub = 'f1111111-1111-1111-1111-111111111111';
insert into public.leagues (id, name, code, owner_id, rest_dow)
  values ('ffffaaaa-0000-0000-0000-00000000000a','THE GYM','CRD001',
          'ffff0000-0000-0000-0000-000000000001', '{}');
insert into public.league_members (league_id, profile_id) values
  ('ffffaaaa-0000-0000-0000-00000000000a','ffff0000-0000-0000-0000-000000000001'),
  ('ffffaaaa-0000-0000-0000-00000000000a','ffff0000-0000-0000-0000-000000000002');

select '  logged: ' || count(*) from public.log_workout(
  'ffffaaaa-0000-0000-0000-00000000000a', 'pullups', 'reps', 40);

\echo '--- 1. a bio is one line, and the server is what decides that'
select case when (select bio from public.set_bio('   Third year. Chasing a one-arm.   '))
            = 'Third year. Chasing a one-arm.'
       then 'saved, trimmed at both ends' else 'THE BIO WAS NOT TRIMMED' end;
do $t$ begin
  perform public.set_bio(repeat('x', 141));
  raise notice 'A 141-CHARACTER BIO WAS ACCEPTED';
exception when others then raise notice '141 characters: %', sqlerrm;
end $t$;
select case when (select bio from public.profiles
                   where id = 'ffff0000-0000-0000-0000-000000000001')
            = 'Third year. Chasing a one-arm.'
       then 'and the one that failed changed nothing'
       else 'THE FAILED BIO OVERWROTE THE GOOD ONE' end;
select case when (select bio from public.set_bio('   ')) is null
       then 'an empty one comes back as nothing, not a blank line'
       else 'AN EMPTY BIO WAS STORED AS TEXT' end;
select '  (restored) ' || coalesce((select bio from public.set_bio('Third year. Chasing a one-arm.')), '');

\echo '--- 2. a league-mate can read the card'
set request.jwt.claim.sub = 'f2222222-2222-2222-2222-222222222222';
select case when (select display_name from public.player_card(
                   'ffff0000-0000-0000-0000-000000000001')) = 'LIFTER'
       then 'somebody on your board has a card' else 'A LEAGUE-MATE SEES NOTHING' end;
select case when (select bio from public.player_card(
                   'ffff0000-0000-0000-0000-000000000001'))
            = 'Third year. Chasing a one-arm.'
       then 'and the line they wrote is on it' else 'THE BIO IS MISSING' end;

\echo '--- 3. the lifetime on it is the same number the board shows'
-- Not a second opinion: a card disagreeing with the row it opened from is
-- worse than a card with no number on it.
select case when (select lifetime from public.player_card(
                   'ffff0000-0000-0000-0000-000000000001'))
            = (select points from public.life_scored_all()
                where profile_id = 'ffff0000-0000-0000-0000-000000000001')
       then 'the card and the board agree on a lifetime'
       else 'THE CARD DISAGREES WITH THE BOARD' end;

\echo '--- 4. a stranger gets nothing at all'
set request.jwt.claim.sub = 'f3333333-3333-3333-3333-333333333333';
select case when (select count(*) from public.player_card(
                   'ffff0000-0000-0000-0000-000000000001')) = 0
       then 'somebody you share no league with has no card to you'
       else 'A STRANGER READ A CARD' end;

\echo '--- 5. and it carries nothing it should not'
-- The card is the one thing a person sees about somebody else, so what it
-- CANNOT say matters more than what it can.
select case when not exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'player_card'
            and (pg_get_function_result(p.oid) ilike '%restore_code%'
              or pg_get_function_result(p.oid) ilike '%bodyweight%'
              or pg_get_function_result(p.oid) ilike '%user_id%'))
       then 'no restore code, no bodyweight, no account id'
       else 'THE CARD IS LEAKING SOMETHING' end;

\echo '--- 6. your own card is readable, which is how the preview works'
set request.jwt.claim.sub = 'f1111111-1111-1111-1111-111111111111';
select case when (select display_name from public.player_card(
                   'ffff0000-0000-0000-0000-000000000001')) = 'LIFTER'
       then 'you can see your own, so the app can show you what others see'
       else 'A PERSON CANNOT SEE THEIR OWN CARD' end;

\echo '--- 7. a line can be taken down, by one person and only one'
-- "The admin can delete the whole account" is not a proportionate answer to
-- a rude sentence, so there is a way to clear just the line.
set request.jwt.claim.sub = 'f2222222-2222-2222-2222-222222222222';
do $t$ begin
  perform public.admin_clear_bio('ffff0000-0000-0000-0000-000000000001');
  raise notice 'A MEMBER CLEARED SOMEBODY ELSE''S LINE';
exception when others then raise notice 'a member cannot: %', sqlerrm;
end $t$;
select case when (select count(*) from public.admin_bios()) = 0
       then 'and cannot even list them' else 'A MEMBER LISTED EVERY BIO' end;

update public.profiles set is_admin = true
 where id = 'ffff0000-0000-0000-0000-000000000002';
select case when (select count(*) from public.admin_bios()) = 1
       then 'the admin sees the lines that exist, and only those'
       else 'THE MODERATION LIST IS WRONG' end;
select public.admin_clear_bio('ffff0000-0000-0000-0000-000000000001');
select case when (select bio from public.profiles
                   where id = 'ffff0000-0000-0000-0000-000000000001') is null
            and (select display_name from public.profiles
                  where id = 'ffff0000-0000-0000-0000-000000000001') = 'LIFTER'
       then 'cleared, and nothing else about the person touched'
       else 'CLEARING A BIO DID SOMETHING ELSE' end;
