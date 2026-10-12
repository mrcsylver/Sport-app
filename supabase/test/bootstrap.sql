-- Enough of Supabase to run schema.sql against a plain Postgres: the auth
-- schema, the two roles, and a uid() that a test can set.
create schema if not exists auth;
-- `created_at` is here because admin_growth() counts landings out of this
-- table: a row with no profile behind it is one person who scanned the
-- poster, saw the first screen and left. Without the column that number
-- could not be tested at all, which is how it would have shipped untested.
-- `is_anonymous` is the same shape of thing: an anonymous sign-in is still
-- the `authenticated` role, and forgetting that is what left eleven
-- functions open to `anon`.
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now(),
  is_anonymous boolean not null default true
);
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;
grant usage on schema public to anon, authenticated;

-- AND THE PART THAT MATTERS MOST. Supabase hands `anon` and `authenticated`
-- SELECT, INSERT, UPDATE and DELETE on every table created in `public`,
-- through ALTER DEFAULT PRIVILEGES, and leaves row-level security as the
-- only thing in the way. A plain Postgres grants nothing.
--
-- So without these two lines the local database is STRICTER than production,
-- and every check that a table cannot be reached directly passes for the
-- wrong reason. That is exactly how four open doors survived twenty-eight
-- test files: `update profiles set is_admin = true` failed here because the
-- role held no grant, and succeeded in production because it held them all.
alter default privileges in schema public
  grant all on tables to anon, authenticated;
alter default privileges in schema public
  grant all on sequences to anon, authenticated;
