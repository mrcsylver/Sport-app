/* =====================================================================
   IRON LEAGUE — your settings
   ---------------------------------------------------------------------
   Already filled in for your Supabase project. You normally never
   need to touch this file again.
   ===================================================================== */

window.APP_CONFIG = {

  SUPABASE_URL: "https://ivjufpcmrhvjrysvomji.supabase.co",

  // Your "anon public" key. It is designed to be public — the database is
  // protected by the security rules in supabase/schema.sql, not by this key.
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2anVmcGNtcmh2anJ5c3ZvbWppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MTAzMzMsImV4cCI6MjEwNDI4NjMzM30.a4J2lNrwBvZNqjHS0JxjoMQkRwan4A_jhuKSkJ8Xarc",

  // If Supabase ever tells you legacy keys are switched off, swap the line
  // above for this newer key instead (delete the // in front of it and put
  // // in front of the line above):
  // SUPABASE_ANON_KEY: "sb_publishable_C0elAnrTtjzRtCn0O43D-A_8rNJWLHU",

  // The week ends every Sunday 23:59 in this timezone.
  // Must match app_timezone() in supabase/schema.sql
  TIMEZONE: "Europe/Paris",

  // Optional: paste your main league code here (e.g. "A1B2C3") so that the
  // bare link already points at your group. Leave "" to disable.
  DEFAULT_LEAGUE_CODE: "",

  // Shown in the header and on the home screen icon.
  APP_NAME: "IRON LEAGUE"
};
