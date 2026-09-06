/* =====================================================================
   IRON LEAGUE — your settings
   ---------------------------------------------------------------------
   This is the ONLY file you need to edit. Replace the two values marked
   PASTE_... with the ones from your Supabase project
   (Supabase dashboard -> Project Settings -> API / "API Keys").
   Keep the quotes around the values.
   ===================================================================== */

window.APP_CONFIG = {

  // Looks like: https://abcdefghijklm.supabase.co
  SUPABASE_URL: "PASTE_YOUR_PROJECT_URL_HERE",

  // The long "anon" / "publishable" key. It is safe to publish this one.
  SUPABASE_ANON_KEY: "PASTE_YOUR_ANON_PUBLIC_KEY_HERE",

  // The week ends every Sunday 23:59 in this timezone.
  // Must match app_timezone() in supabase/schema.sql
  TIMEZONE: "Europe/Paris",

  // Optional: paste your main league code here (e.g. "A1B2C3") so that the
  // bare link already points at your group. Leave "" to disable.
  DEFAULT_LEAGUE_CODE: "",

  // Shown in the header and on the home screen icon.
  APP_NAME: "IRON LEAGUE"
};
