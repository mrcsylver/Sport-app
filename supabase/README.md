# The database

`schema.sql` is the whole thing: paste it into the Supabase SQL editor, press
RUN, and you have a working database. It drops everything first, so running it
twice is a rebuild, not a mess — and running it on a live database wipes it.

`bounty-pool.sql`, `catch-up-day.sql` and `dashboard-points.sql` are migrations
for a database that is already running. They only add; nothing logged is
touched, and all three are safe to run twice.

`dashboard-points.sql` splits the control room's one "Points" column in two.
It was lifetime — every workout ever logged, counted once even when the same
set fanned out to several leagues, and with no bonus in it — read next to a
league board showing this week with the combo and bounty bonuses on top. A
player showed 720 in one and 706 in the other and neither was wrong. The
function now returns `lifetime` and `week_points` under names that say which
question each answers. Nothing is recalculated, because nothing was broken.

`body-and-crowns.sql` adds the muscle figure and the crowns tracker, and
reprices the two families of exercise that were wrong against everything else
— the endurance holds (a plank paid 2 points a minute where a set of reps pays
20-30) and the continuous cardio (an hour of running paid 50, an hour of
swimming 12). Twenty-six rates change; nothing already earned does, because
points are stamped when a row is written. The file rescores the week in
progress, and only that week, so a live week is not half priced at the old
rates and half at the new ones.

`fix-this-week.sql` is a one-off. Running `bounty-pool.sql` mid-week changed
which quest the week was for, and because bounty points are worked out on read
rather than stored, anybody who had already finished the old one lost the
points for it. This pins the week back to the quest it started with. The
migration now does the same thing on its own, so it only matters if you ran it
before that was fixed.

## Testing it for real

```bash
supabase/test/run.sh
```

This starts a throwaway Postgres, builds the database from `schema.sql`,
exercises the bounty system and the control room's two totals, then applies
every migration three times to a database wound back to look like the live
one.

It is worth having because parsing SQL proves almost nothing. Two real bugs
survived months of `pglast` checks and were both found the first time the file
was actually executed:

- `log_workout` declared four parameters and its body used six. Gym scoring
  worked in production only because the live database had a newer version
  applied by hand — a rebuild from this file produced a function that could
  not score a lift.
- `revoke all on function public.is_rest_day()` named a signature that does
  not exist (a default argument does not create a second one), so the run
  stopped there and the revoke never applied.

Both are fixed. The suite exists so the next one is found here.

## What is generated

Do not hand-edit these:

| file | written by |
|---|---|
| the `exercises` seed in `schema.sql` | `tools/build_exercises.py` |
| the `bounties` seed in `schema.sql` | `tools/build_bounties.py` |
| `bounty-pool.sql` | `tools/build_bounties.py` |
| `catch-up-day.sql` | `tools/build_catchup.py` |
| `dashboard-points.sql` | `tools/build_dashboard.py` |
| `body-and-crowns.sql` | `tools/build_body_migration.py` |
| the `muscles` seed in `schema.sql` | `tools/build_exercises.py` |
| `BODY` in `app.js` (the figure itself) | `tools/build_body.py` |
| `RATES`/`CATS`/`MUSCLE_OF` in the browser mock | `tools/build_exercises.py` |
| the open-exercise list in `bounty_open_to_all()` | `tools/build_bounties.py` |
| the `OPEN_TO_ALL` block in `tools/test/mock-supabase.js` | `tools/build_bounties.py` |

`build_bounties.py` validates before it writes: every exercise a bounty names
must exist, and must be loggable in the mode the bounty asks for. It has
already caught six quests that nobody could have completed — a three-minute
plank asked for seconds, and plank is only logged in minutes.

It also enforces who can complete them. A bounty reaches every league at once,
so it may only name an exercise anybody has: no gym, no pool, no bike, no
pitch, no rope, and no move that takes a year to learn. Thirty-two quests
failed that rule the day it was added — dragon flags, boxing rounds, ring
dips, stair sprints — and were replaced. The same list is written into
`bounty_open_to_all()`, so the control room cannot write one either, and into
the browser mock, so the tests refuse what the server refuses. An `any` quest
needs only one of its options to be open; everything else must be open on
every exercise it names.

None of the migrations is written by hand. Every function in them is lifted
out of `schema.sql`, which is the one definition of each, because two hand-kept
copies of a hundred-line function drift and the drift is always found in
production. `tools/sqllift.py` does the lifting; the generators only say which
objects they need.

`build_exercises.py` used to write two files for somebody to paste in by
hand. It splices them now — into `app.js`, `schema.sql` and the browser mock —
because a paste step gets skipped, and when it does the client previews one
number while the server awards another.

Two things the lift has to know: `create or replace function` cannot change
what a function returns, and it cannot add a parameter either. `my_leagues`
gained a column and `set_league_settings` gained an argument, so
`build_catchup.py` drops those two first and rebuilds them. `admin_players`
renamed a column and added one, so `build_dashboard.py` drops it too.

One rule the migration follows: **a week already being played keeps the quest
it started with.** Changing the rotation under people mid-week silently takes
away points they had already earned, because the points are derived. The
migration pins the current week to whatever the old rotation gave it, and only
when somebody has actually logged that week.

## Why `check_function_bodies` is off

The first thing `schema.sql` does is `set check_function_bodies = off`. These
functions call each other in both directions, and Postgres resolves a SQL
function body the moment the function is created — so a strict run stops at
the first forward reference, and the file would only work if it were sorted
into an order no human could maintain. Every body is still parsed, so a typo
is still an error; only name resolution is deferred.
