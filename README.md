# ⚡ IRON LEAGUE — weekly calisthenics leaderboard

A mobile-first Progressive Web App (add it to your home screen, it behaves like a
real app) where you and up to 19 friends log calisthenics work, score points, and
fight for the weekly crown. The week resets **every Sunday at 23:59**.

- **Live weekly leaderboard** — tap any name to see everything that person logged.
- **Daily combo bonus** — small rewards for training more than one muscle group in a day.
- **Weekly bounty** — a rotating Thursday side quest, verified automatically.
- **Sunday rest day** — the league closes Saturday night; only a stretch counts.
- **Stats tab** — your own totals, this week or all time, split by muscle group.
- **Duels** — 24 hour head to head against anyone in your league, by code.
- **Animal avatars, light or dark theme** — set in the Leagues tab.
- **Hall of Fame** — every past week's champion and full standings.
- **Log Workout** — pick an exercise, type reps / seconds / km, points are worked
  out for you. Log as many exercises as you want without closing the panel.
- **Personal leagues** — create your own league, share a link, 30 people max.
- **Log once** — an entry counts in every league you are in.
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

| Category | Exercise | Points |
|---|---|---|
| **Push** | Push-ups *(incline · standard · diamond)* | 1 pt / rep |
| | Dips *(bench · bars · rings)* | 1.5 pts / rep |
| | Handstand Push-up / Hold *(wall · hanging · free)* | 2.5 pts / rep · 1 pt / 5 sec |
| **Pull** | Inverted Rows *(table · low bar · rings)* | 1 pt / rep |
| | Pull-ups *(full range only)* | 2 pts / rep |
| | Muscle-up / Flag Hold | 3.5 pts / rep · 2 pts / sec |
| **Legs** | Air Squats | 0.5 pt / rep |
| | Pistol Squats *(per leg)* | 2 pts / rep |
| | Calf Raises | 0.2 pt / rep |
| **Core** | Knee / Leg Raises *(floor · hanging)* | 1 pt / rep |
| | L-Sit Hold *(tuck → full)* | 1 pt / 3 sec |
| | Plank *(forearm · high · side)* | 2 pts / min |
| | Russian Twists *(one rep = one side)* | 0.25 pt / rep |
| **Cardio** | Run | 5 pts / km |
| | Sprint Intervals *(one sprint = 15 sec / 100 m)* | 2 pts / sprint |
| | Biking | 1.5 pts / km |
| | Swim *(active swim time)* | 8 pts / hour |
| | Walking | 2.5 pts / km |
| **Recovery** | Stretching Session *(10 min minimum)* | 5 pts flat |

Variations of the same movement are worth the same. The point is to train and
progress, not to farm the easiest option.

### Divisions

The standings are split into **Gold / Silver / Bronze, ten athletes each**,
cut from the live table: the current top ten are Gold, the next ten Silver, the
rest Bronze. Every division has its own 1 to 10, so there is a race to win at
every level — and because it follows this week's points, logging a session can
move you up a division the moment you do it. Below eleven members the league
stays as one table, since a single division is not a division.

### Hall of Fame

Each finished week crowns two people: the **champion** on points, and **Most
Improved** — the biggest gain on your own previous week. You have to have
competed the week before to win it, so it cannot be won by simply showing up.

### Duel record

The stats tab keeps a lifetime **W / L / D** and your best winning run. Duel
results are worked out from the workouts inside each duel's window rather than
stored, and challenge rows are never deleted, so the record is permanent. It is
lifetime regardless of the week / all-time toggle, and stays hidden until your
first duel has been settled.

### Milestones

The stats tab tracks lifetime points against nine ranks, from SPARK at 25 up to
IMMORTAL at 5000. They are personal, so they are worth chasing no matter where
you sit in the table.

### Weekly bounty

Every week has one side quest, and it always runs on the **same weekday
(Thursday)** so it is easy to plan around. It rotates through 52 of them, so
the same quest does not come back for a year.

**It has to be done ON that day** — not by that day. Only workouts logged on the
Thursday itself count, from 00:00 to 23:59. The card says which state it is in:
*counts on Thursday only* before the day, *today only, until midnight* on the
day, and *closed* afterwards.

- **Bounties are worth 25 to 60 points** depending on how hard they are — a
  big enough swing to move you up the table, so missing one costs you.
- **Everybody who completes it earns the points** — it is not a race you can
  lose by being busy in the morning.
- The first person to finish also gets a 🩸 next to their name. Worth nothing,
  purely for bragging.
- **There is nothing to claim and nothing to tap.** The app reads your normal
  logs and works out whether you did it, so a bounty cannot be faked.

To change the day, edit `bounty_dow()` in `supabase/schema.sql` (1 = Monday).
To change the quests themselves, edit the list at the bottom of that file.

### Sunday is a rest day 😴

The league runs **Monday 00:00 → Saturday 23:59**. Saturday night it closes:

- Nothing can be logged, edited or deleted on Sunday.
- The single exception is **one stretching session** (5 pts), once, to reward
  actually recovering.
- The week still settles Sunday 23:59, which is the moment the new week opens.

The rule is enforced by the database, not just hidden in the app, so it cannot
be worked around.

### Daily combo

Score at least **10 points in different muscle groups on the same day** and a
bonus is added automatically:

| Groups covered in one day | Bonus |
|---|---|
| 3 | +5 |
| 4 | +8 |
| 5 | +12 |

Only the highest tier counts. Eligible groups are Push, Pull, Legs, Core and
Cardio — **Recovery does not count**, so stretching cannot be used to buy a
group. The live tab shows which groups you have already covered today.

Points are always calculated **on the server**, so nobody can fake a score by
fiddling with their phone. A week runs **Monday 00:00 → Sunday 23:59**; when it
ends, the standings freeze into the Hall of Fame and everyone restarts at 0.

### Want to change a points value?
Change it in **two** places, then re-run the SQL file:
1. `supabase/schema.sql` → the `calc_points` function
2. `app.js` → the `EXERCISES` list at the top

Changing values does **not** rewrite history: every entry stores the points it
scored at the time. If you change the scale mid-week, re-score just the running
week with `update public.workouts set amount = amount where week_start =
public.current_week_start();` so everyone in that week is measured the same way.

---

# ⚔️ DUELS

A duel is **24 hours, one against one**, inside a league you both belong to.

1. Open the **DUELS** tab and tap **CREATE A DUEL CODE**.
2. Send the code to someone in your league. The first person to enter it
   becomes your opponent and the clock starts.
3. Whoever scores more points in those 24 hours wins.

**You never log anything twice.** A duel does not have its own logging — it
simply reads the workouts you already logged for your league during its
window, so one entry counts for your league week *and* the duel. The live
duel card says so on screen.

One duel at a time per person. An unclaimed code expires after 24 hours, and
when a duel ends the tab clears itself and the result drops into *Past duels*.

---

# 🧩 LEAGUES

You can be in **as many leagues as you like** (you can create up to 10 of your
own). Tap one in the LEAGUES tab to switch; each has its own leaderboard,
history, combo bonus and duels.

**You only ever log a workout once.** It is counted in *every* league you
belong to at that moment, and editing or deleting it updates all of them
together. Joining a new league never back-fills your older workouts, so
everybody genuinely starts that league on zero.

- Anyone can create a league from the **LEAGUES** tab; they get a 6-character code
  and a share link.
- **30 people maximum** per league (the database refuses number 31).
- You can be in several leagues at once — tap one in the LEAGUES tab to switch.
  Each league has its own separate leaderboard and history.
- Joining mid-week is fine: you simply start that week on 0 points.

---

# 🔗 WHICH LINK TO SEND

| Link | Give it to | What they can do |
|---|---|---|
| `https://mrcsylver.github.io/Sport-app/` | anyone, safely | Sign up and start **their own** league. They cannot see or join yours. |
| `https://mrcsylver.github.io/Sport-app/#/join/YOURCODE` | only your own group | Joins your league directly |

The 6-character code is the only thing protecting your league, so keep the invite
link inside your group chat. Everything else is safe to share publicly: people who
sign up land in their own empty world and, thanks to the database security rules,
cannot see your league, your friends' names, or anyone's workouts.

Your GitHub repository is public, so your Supabase URL and `anon` key are visible in
`config.js`. That is fine and intended — the `anon` key is the public one, which is
exactly why every table has row level security. Never publish the **service_role**
key from the Supabase dashboard.

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
They fix it themselves: tap their own name on the leaderboard, then ✎ to correct the
entry or ✕ to delete it. This works **only for the week that is still running** —
once Sunday 23:59 passes, that week's entries are frozen for everyone, so finished
standings can never change afterwards.

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
