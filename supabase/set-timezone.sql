-- =====================================================================
--  CHANGE THE WEEKLY DEADLINE TIMEZONE
-- ---------------------------------------------------------------------
--  Run this in the Supabase SQL Editor if you ran schema.sql when it was
--  still set to a different timezone, or if your group moves country.
--
--  It is SAFE: it only swaps the timezone, it does not touch any data.
--  Whatever you put here must match TIMEZONE in config.js.
--  Currently set to Europe/Paris, which is what the app uses.
-- =====================================================================

create or replace function public.app_timezone() returns text
language sql immutable set search_path = public as $$ select 'Europe/Paris'::text $$;

-- Check it worked — should print your timezone and this week's Monday:
select public.app_timezone() as timezone, public.current_week_start() as week_started;
