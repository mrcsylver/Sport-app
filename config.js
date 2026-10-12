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
  APP_NAME: "IRON LEAGUE",

  // Sign-in methods offered on the door and in settings.
  //
  // GOOGLE: a verified identity, free, and the only one that proves an email
  // address is real. Leave false until the Google Cloud console side is set
  // up, or the button appears and fails.
  // EMAIL: email + password. With "Confirm email" off in Supabase these are
  // NOT verified addresses -- it is a username that looks like an email, and
  // there is no password reset. The restore code is the recovery path.
  // ANON: let somebody in with no account at all, as the app has always
  // worked. Keeps the "logging push-ups in twenty seconds" path open; they
  // are nudged to secure the account once they have something worth keeping.
  SIGN_IN: { GOOGLE: true, EMAIL: true, ANON: true },

  // The currency the shop prints prices in. A symbol, not a code: it sits in
  // front of a number on a small tile. Nothing charges anybody yet — this is
  // what the labels say.
  CURRENCY: "\u20ac",

  // Where somebody turned away by the cap is sent to ask for a seat. An
  // email, an Instagram profile, a WhatsApp link — anything a browser can
  // open. Leave "" and the button is hidden rather than dead.
  CONTACT_URL: "mailto:mrcsylver@gmail.com",

  // Cloudflare Turnstile — the free CAPTCHA in front of signing in.
  //
  // WHY IT MATTERS. Opening the app with no account at all calls Supabase's
  // anonymous sign-in, which writes a row in auth.users. Anybody can call
  // that endpoint directly with the key above, which is public by design, so
  // without a gate a script can mint accounts until the free database is
  // full — and each fresh identity also gets its own ten guesses at other
  // people's restore codes. Cloudflare's own IP limit (30 an hour) slows one
  // machine down; it does not stop a handful.
  //
  // Leave "" and nothing changes: no script is loaded and no challenge is
  // ever shown.
  //
  // THE ORDER TO TURN IT ON IS THIS ONE. Key here first, push, check the app
  // still opens, THEN switch on CAPTCHA protection in Supabase
  // (Authentication → Attack Protection). In between, the app sends a token
  // nothing checks, which costs nobody anything — and a challenge that
  // cannot be completed is passed through for Supabase to judge rather than
  // refused here, so a blocked widget in that window locks nobody out.
  // Backwards (Supabase first) there is a window where NOBODY can sign in.
  //
  // The SITE key is public, like the one above. The SECRET key belongs in
  // the Supabase dashboard and nowhere in this repository.
  TURNSTILE_SITE_KEY: "0x4AAAAAAFUQq7PR_61iGs7y"
};
