-- The shop: what you may wear, and what stops you wearing what you have not
-- got.
--
-- The rule the whole thing exists for: before this, `set_banner('whatever')`
-- was accepted, so the first item anybody charged for would have been free to
-- anybody willing to call the function by hand. Every assertion below is a
-- version of "the catalogue is the authority, not the client".
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

insert into auth.users (id) values
  ('a1111111-1111-1111-1111-111111111111'),
  ('a2222222-2222-2222-2222-222222222222'),
  ('a3333333-3333-3333-3333-333333333333')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code, is_admin) values
  ('aaaa0000-0000-0000-0000-000000000001','a1111111-1111-1111-1111-111111111111','BOSS','SHOP1',true),
  ('aaaa0000-0000-0000-0000-000000000002','a2222222-2222-2222-2222-222222222222','SPENDER','SHOP2',false),
  ('aaaa0000-0000-0000-0000-000000000003','a3333333-3333-3333-3333-333333333333','SKINT','SHOP3',false);

\echo '--- 1. the catalogue covers everything the client can draw'
select '  ' || kind || ' ' || count(*) from public.shop_items
group by kind order by kind;
select case when (select count(*) from public.shop_items) >= 190
       then 'every shipped cosmetic is a row, so nothing refuses to save'
       else 'THE CATALOGUE IS SHORT — SOMETHING WILL NOT SAVE' end;
select case when (select count(*) from public.shop_items where price_cents is not null) = 0
       then 'and all of it is free, which is how the app shipped'
       else 'SOMETHING IS PRICED THAT WAS NOT MEANT TO BE' end;

\echo '--- 2. a free item goes on, and off again'
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
select '  banner is now ' || coalesce(banner,'none')
from public.set_banner('carbon');
select '  and now ' || coalesce(banner,'none') from public.set_banner('');
select case when (select banner is null from public.profiles
                  where display_name = 'SPENDER')
       then 'taking a cosmetic off is always allowed'
       else 'AN EMPTY KEY WAS REFUSED' end;

\echo '--- 3. a key that is not in the catalogue is refused'
do $t$ begin
  perform public.set_banner('definitely-not-a-banner');
  raise notice 'AN INVENTED BANNER WAS ACCEPTED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select banner is null from public.profiles
                  where display_name = 'SPENDER')
       then 'so nothing is stored that the app cannot draw'
       else 'AN INVENTED BANNER WAS STORED' end;

\echo '--- 4. a priced item is locked until somebody owns it'
set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
select '  made ' || name || ' at ' || price_cents || 'c'
from public.admin_save_shop_item('player_banner','warlord','WARLORD',
                                 'designs/warlord.webp','webp',
                                 'designs/warlord-thumb.webp', true, 499, 99);
set request.jwt.claim.sub = 'a3333333-3333-3333-3333-333333333333';
do $t$ begin
  perform public.set_banner('warlord');
  raise notice 'A PAID BANNER WENT ON FOR FREE';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select banner is null from public.profiles
                  where display_name = 'SKINT')
       then 'so a paid banner cannot be worn by typing its name'
       else 'THE PAYWALL IS DECORATIVE' end;
select case when (select not owned from public.shop_catalogue()
                  where item = 'warlord')
       then 'and the shelf shows it as not theirs'
       else 'THE SHELF CLAIMS THEY OWN IT' end;

\echo '--- 5. an entitlement unlocks it, for that person only'
set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
select '  granting to SPENDER' from (select public.admin_grant_item(
  'aaaa0000-0000-0000-0000-000000000002','player_banner:warlord','launch gift')) x;
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
select '  banner is now ' || banner from public.set_banner('warlord');
select case when (select owned from public.shop_catalogue() where item = 'warlord')
       then 'the person who was given it can wear it'
       else 'A GRANT DID NOTHING' end;
set request.jwt.claim.sub = 'a3333333-3333-3333-3333-333333333333';
select case when (select not owned from public.shop_catalogue() where item = 'warlord')
       then 'and nobody else gained anything by it'
       else 'A GRANT LEAKED TO EVERYBODY' end;

\echo '--- 6. retiring takes it off the shelf without stripping it off anybody'
set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
select '  retired ' || item from public.admin_retire_shop_item('player_banner:warlord', true);
select case when (select count(*) from public.shop_catalogue()
                  where item = 'warlord') = 0
       then 'it is gone from the shelf'
       else 'A RETIRED ITEM IS STILL ON SALE' end;
select case when (select banner = 'warlord' from public.profiles
                  where display_name = 'SPENDER')
       then 'and the person wearing it still is — nothing re-checks a profile'
       else 'RETIRING STRIPPED SOMEBODY' end;
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
do $t$ begin
  perform public.set_banner('warlord');
  raise notice 'A RETIRED BANNER WAS RE-CHOSEN';
exception when others then raise notice 'cannot be chosen again: %', sqlerrm;
end $t$;

\echo '--- 7. the avatar spec is two items, and an emoji is neither'
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
select '  avatar is ' || avatar from public.set_avatar('gi:wolf-head|c=crimson');
do $t$ begin
  perform public.set_avatar('gi:not-an-emblem|c=crimson');
  raise notice 'AN INVENTED EMBLEM WAS ACCEPTED';
exception when others then raise notice 'emblem refused: %', sqlerrm;
end $t$;
do $t$ begin
  perform public.set_avatar('gi:wolf-head|c=rainbow');
  raise notice 'AN INVENTED TINT WAS ACCEPTED';
exception when others then raise notice 'tint refused: %', sqlerrm;
end $t$;
select '  and an animal still works: ' || avatar from public.set_avatar('🦍');
select case when (select avatar = '🦍' from public.profiles
                  where display_name = 'SPENDER')
       then 'an emoji is not an item and never goes near the catalogue'
       else 'AN EMOJI WAS TREATED AS A PAID ITEM' end;

\echo '--- 8. a crest is four separate slots, each checked on its own'
insert into public.leagues (id, name, code, owner_id) values
  ('aaaa1111-0000-0000-0000-000000000001','SHOP LEAGUE','SHOPLG',
   'aaaa0000-0000-0000-0000-000000000002');
insert into public.league_members (league_id, profile_id) values
  ('aaaa1111-0000-0000-0000-000000000001','aaaa0000-0000-0000-0000-000000000002');
select '  crest set' from (select public.set_league_badge(
  'aaaa1111-0000-0000-0000-000000000001',
  '{"shape":"hex","color":"gold","emblem":"castle","skin":"neon"}'::jsonb)) x;
do $t$ begin
  perform public.set_league_badge('aaaa1111-0000-0000-0000-000000000001',
    '{"shape":"hex","color":"gold","emblem":"castle","skin":"made-up"}'::jsonb);
  raise notice 'AN INVENTED LEAGUE BANNER WAS ACCEPTED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
do $t$ begin
  -- A player emblem is not a league crest mark: two sets, on purpose.
  perform public.set_league_badge('aaaa1111-0000-0000-0000-000000000001',
    '{"shape":"hex","color":"gold","emblem":"wolf-head","skin":"neon"}'::jsonb);
  raise notice 'A PLAYER EMBLEM WAS WORN BY A LEAGUE';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select badge->>'skin' = 'neon' from public.leagues
                  where code = 'SHOPLG')
       then 'the crest that was legal stuck, and the two that were not did not'
       else 'A CREST WAS OVERWRITTEN BY A REFUSED ONE' end;

\echo '--- 9. the ring is its own slot, and uploaded artwork is how it is made'
set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
select '  made ' || name || ' (' || asset_kind || ', animated ' || animated || ')'
from public.admin_save_shop_item('frame','gold-pulse','GOLD PULSE',
                                 'designs/gold-pulse.webp','webp',
                                 'designs/gold-pulse-still.webp', true, null, 0);
set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
select '  ring is now ' || frame from public.set_frame('gold-pulse');
do $t$ begin
  perform public.set_frame('not-a-ring');
  raise notice 'AN INVENTED RING WAS ACCEPTED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select frame = 'gold-pulse' from public.profiles
                  where display_name = 'SPENDER')
       then 'a free uploaded design is wearable by everybody'
       else 'AN UPLOADED DESIGN COULD NOT BE WORN' end;

\echo '--- 10. none of the control room is reachable without the flag'
set request.jwt.claim.sub = 'a3333333-3333-3333-3333-333333333333';
select case when (select count(*) from public.admin_shop_items()) = 0
       then 'a member reading the catalogue manager gets nothing'
       else 'THE CATALOGUE MANAGER LEAKS' end;
do $t$ begin
  perform public.admin_save_shop_item('frame','mine','MINE');
  raise notice 'A MEMBER ADDED A SHOP ITEM';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
do $t$ begin
  perform public.admin_grant_item('aaaa0000-0000-0000-0000-000000000003',
                                  'player_banner:warlord');
  raise notice 'A MEMBER GRANTED THEMSELVES A PAID ITEM';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.entitlements
                  where profile_id = 'aaaa0000-0000-0000-0000-000000000003') = 0
       then 'and could not hand themselves the paid one either'
       else 'A MEMBER GRANTED THEMSELVES AN ITEM' end;

\echo '--- 11. a name an admin types is still checked'
set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
do $t$ begin
  perform public.admin_save_shop_item('frame','Not A Slug!','BAD');
  raise notice 'A BAD SLUG WAS ACCEPTED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
do $t$ begin
  perform public.admin_save_shop_item('frame','nameless','   ');
  raise notice 'A NAMELESS ITEM WAS ACCEPTED';
exception when others then raise notice 'refused: %', sqlerrm;
end $t$;
select case when (select count(*) from public.shop_items
                  where kind = 'frame') = 1
       then 'so the only ring in the catalogue is the one that was made properly'
       else 'A MALFORMED ITEM GOT IN' end;
