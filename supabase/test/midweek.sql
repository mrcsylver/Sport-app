-- A league with somebody who has already logged this week, so the migration
-- has a week in progress to protect.
insert into auth.users (id) values ('55555555-5555-5555-5555-555555555555')
on conflict (id) do nothing;
insert into public.profiles (id, user_id, display_name, restore_code) values
  ('eeee0000-0000-0000-0000-000000000001','55555555-5555-5555-5555-555555555555',
   'QUENTIN','MW1') on conflict do nothing;
insert into public.leagues (id, name, code, owner_id) values
  ('ffff0000-0000-0000-0000-000000000001','MIDWEEK','MWTEST',
   'eeee0000-0000-0000-0000-000000000001') on conflict do nothing;
insert into public.league_members (league_id, profile_id) values
  ('ffff0000-0000-0000-0000-000000000001','eeee0000-0000-0000-0000-000000000001')
on conflict do nothing;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
insert into public.workouts (league_id, profile_id, exercise_key, mode, amount)
values ('ffff0000-0000-0000-0000-000000000001','eeee0000-0000-0000-0000-000000000001',
        'run', 'km', 5);
