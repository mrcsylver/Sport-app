# ⚡ IRON LEAGUE — weekly calisthenics leaderboard

A mobile-first Progressive Web App (add it to your home screen, it behaves like a
real app) where you and up to 19 friends log calisthenics work, score points, and
fight for the weekly crown. The week resets **every Sunday at 23:59**.

- **Live weekly leaderboard** — tap any name to see everything that person logged.
- **Hall of Fame** — every past week's champion and full standings.
- **Log Workout** — pick an exercise, type reps / seconds / km, points are worked
  out for you. Log as many exercises as you want without closing the panel.
- **Personal leagues** — create your own league, share a link, 20 people max.
  Anyone can join at any time; they simply start the current week on 0 points.
- Free forever on Supabase's + GitHub's free tiers.

---

# 🚀 SET IT UP (about 15 minutes, no coding)

You need two free accounts: **Supabase** (the database) and **GitHub** (you already
have one — the code is in your repo `mrcsylver/Sport-app`).

Do the parts in order. Every click is written out.

---

## PART 1 — Create the database (Supabase)

1. Go to **https://supabase.com** → click **Start your project** → sign in
   (choose *Continue with GitHub*, it's the fastest).
2. Click **New project**.
   - *Name*: `iron-league`
   - *Database Password*: click **Generate a password**, then **copy it and paste it
     somewhere safe**. (You will probably never need it, but don't lose it.)
   - *Region*: pick the one closest to you.
   - *Plan*: **Free**.
   - Click **Create new project** and wait ~2 minutes while it builds.

3. **Create the tables.** In the left sidebar click **SQL Editor** (icon looks like
   a terminal) → **New query**.
   - Open the file `supabase/schema.sql` from this repository
     ([click here](https://github.com/mrcsylver/Sport-app/blob/claude/calisthenics-leaderboard-pwa-1gwhov/supabase/schema.sql)),
     click the **copy** button at the top-right of the file, and paste the whole
     thing into the Supabase query box.
   - Press **Run** (or Ctrl/Cmd + Enter).
   - You should see **"Success. No rows returned"**. That's what you want.

4. **Turn on passwordless login.** Left sidebar → **Authentication** →
   **Sign In / Providers** (older layout: *Providers*) → find
   **Anonymous sign-ins** → switch it **ON** → **Save**.

   > This is how friends get in by just typing a name — no email, no password.
   > If you skip this step the app will tell you so on the first screen.

5. **Copy your two keys.** Left sidebar → **Project Settings** (the gear at the
   bottom) → **API Keys** (or *API*). You need:
   - **Project URL** — looks like `https://abcdefghijklmnop.supabase.co`
   - the **anon public** key (newer projects call it **publishable key**, starting
     with `sb_publishable_…`) — a long string.

   Leave this browser tab open, you need these in one minute.

   > These two values are *meant* to be public — the database is protected by
   > security rules that were installed by the SQL you ran. Never publish the
   > **service_role** / **secret** key, though.

---

## PART 2 — Nothing to do ✅

`config.js` already contains your project URL and your anon key, and the
weekly deadline is set to **Europe/Paris** in both the app and the database —
the week ends **Sunday 23:59 Paris time** wherever your friends' phones are.

Everything in this part was verified directly against your live database:
the tables, the security rules, the points engine, joining by invite code,
and profile restore.

If your group ever moves timezone, change it in **both** places: the
`TIMEZONE` line in `config.js`, and by running `supabase/set-timezone.sql`
in the Supabase SQL editor.

---

## PART 3 — Put the app online (GitHub Pages, free)

1. Go to **https://github.com/mrcsylver/Sport-app/settings/pages**
2. Under **Build and deployment → Source**, choose **Deploy from a branch**.
3. Under **Branch**, pick **`claude/calisthenics-leaderboard-pwa-1gwhov`**
   and folder **`/ (root)`** → click **Save**.
4. Wait 1–2 minutes, then refresh that page. It will show:

   > **Your site is live at https://mrcsylver.github.io/Sport-app/**

**That is the link you send to your friends.** 🎉

<details>
<summary>Prefer a cleaner setup? (optional)</summary>

You can merge this branch into `main` first (GitHub will offer a
*"Compare & pull request"* button on the repo home page → **Create pull request**
→ **Merge pull request**), then choose `main` in step 3 instead. If you do this,
don't delete the branch until Pages is pointing at `main`, or the site goes down
for a minute.
</details>

<details>
<summary>Alternative host: Netlify (if GitHub Pages gives you trouble)</summary>

1. On the repo page click the green **Code** button → **Download ZIP**, and unzip it.
2. Go to **https://app.netlify.com/drop** and drag the unzipped folder onto the page.
3. You get a link immediately. Sign in (free) to keep it permanently and to rename it.

Remember to edit `config.js` **before** zipping/dragging, or edit it and drop the
folder again.
</details>

---

## PART 4 — First run, and inviting your friends

1. Open the link **on your phone**.
2. Type your name → **ENTER THE ARENA**. Since you are the first one, you also name
   your league (e.g. `THE CREW`).
3. Go to the **LEAGUES** tab → **COPY** the invite link → paste it in your group chat.
4. Everyone who opens that link picks a name and is instantly in the league.
   No account, no password, no app store.

### Add it to the home screen (this is the PWA part)
- **iPhone / iPad (Safari):** tap the **Share** button (square with an arrow) →
  scroll down → **Add to Home Screen** → **Add**.
- **Android (Chrome):** tap the **⋮** menu → **Add to Home screen** / **Install app**.
  Many phones also pop up an *Install* banner by themselves, and there is an
  **ADD TO HOME SCREEN** button in the LEAGUES tab.

Once installed it opens full screen with no browser bar, and the app shell still
loads when you have no signal (you just can't post until you're back online).

---

# 🏋️ HOW SCORING WORKS

| Exercise | Points |
|---|---|
| Standard Push-ups | 1 pt / rep |
| Handstand Push-ups / Holds | 3 pts / rep **or** 1 pt / 5 sec |
| Dips | 1.5 pts / rep |
| Strict Pull-ups | 3 pts / rep |
| Muscle-up / Flag | 8 pts / rep **or** 2 pts / sec |
| Air Squats | 0.5 pt / rep |
| Pistol Squats | 3 pts / rep |
| Knee Raises | 1 pt / rep |
| L-Sit Hold | 1 pt / 3 sec |
| Run | 10 pts / km |
| Sprint Intervals | 5 pts / min |
| Stretching Session | 2 pts flat |

Points are always calculated **on the server**, so nobody can fake a score by
fiddling with their phone. A week runs **Monday 00:00 → Sunday 23:59**; when it
ends, the standings freeze into the Hall of Fame and everyone restarts at 0.

### Want to change a points value?
Change it in **two** places, then re-run the SQL file:
1. `supabase/schema.sql` → the `calc_points` function
2. `app.js` → the `EXERCISES` list at the top

---

# 🧩 LEAGUES

- Anyone can create a league from the **LEAGUES** tab; they get a 6-character code
  and a share link.
- **20 people maximum** per league (the database refuses number 21).
- You can be in several leagues at once — tap one in the LEAGUES tab to switch.
  Each league has its own separate leaderboard and history.
- Joining mid-week is fine: you simply start that week on 0 points.

---

# 🔧 IF SOMETHING GOES WRONG

**"SETUP NEEDED" screen**
`config.js` still has the placeholder text, or a quote/comma got deleted. Re-open
it on GitHub and compare with the example in Part 2.

**"Anonymous sign-ins are still OFF in Supabase"**
Do Part 1 step 4, then reload the page.

**The Pages link shows 404**
Give it 2 more minutes. Then re-check Settings → Pages that the **branch** and
**/ (root)** folder are selected and saved.

**I changed config.js but the app still uses the old values**
The app caches itself so it works offline. Close it completely and reopen it, or
pull down to refresh in the browser. If it is really stubborn, edit `sw.js` and
change `ironleague-v1` to `ironleague-v2`, then commit — that forces every phone to
pick up the new files.

**A friend changed phone / cleared their browser and lost their profile**
Every profile has a **restore code** (LEAGUES tab → MY PROFILE). On the new phone,
tap *"Changed phone? Restore your profile"* on the first screen and type that code.
Tell everyone to screenshot their code once.

**Nobody logged anything for a week**
Supabase pauses free projects after ~1 week with no activity. Open your Supabase
dashboard and click **Restore project** — nothing is lost.

**Somebody logged a wrong number**
They can delete their own entries: tap their own name on the leaderboard, then the
✕ next to the entry.

---

# 📁 What is in this repository

```
index.html          the whole app's HTML
styles.css          the dark competitive look
app.js              all the logic (points, leaderboard, leagues, countdown)
config.js           >>> the only file you edit <<<
sw.js               service worker: offline support / installability
manifest.webmanifest  makes it installable as an app
supabase/schema.sql >>> run this once in Supabase <<<
vendor/supabase.js  the Supabase library, bundled so nothing loads from the internet
fonts/, icons/      the typeface and the app icon
```

No build step, no npm, no framework. Every file is served exactly as it is,
which is why any free static host can run it.
