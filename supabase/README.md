# The database

`schema.sql` is the whole thing: paste it into the Supabase SQL editor, press
RUN, and you have a working database. It drops everything first, so running it
twice is a rebuild, not a mess — and running it on a live database wipes it.

`bounty-pool.sql`, `catch-up-day.sql`, `dashboard-points.sql`,
`body-and-crowns.sql`, `repetition-cap.sql`, `gym-lifts.sql` and
`progressions.sql` are migrations for a database that is already running. They only add; nothing logged is touched, and all of
them are safe to run twice.

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

`repetition-cap.sql` makes one movement get cheaper as the week fills. The
first `cap` points of a single exercise in a single week pay in full, the next
`cap` pay half, everything past that pays a quarter — and it never reaches
zero, so no total is capped, nobody is ever told to stop, and more work is
always more points.

The reason is that points are linear in reps and effort is not. The ceiling on
a hard movement is what a body can do; the ceiling on an easy one is only
boredom. So the cheapest thing a person can repeat forever was the best points
per hour going, and it showed: one member's step-ups were seven per cent of an
entire league's week, and push-ups alone were sixteen. Repeating one movement
now stops being the best way to score, which makes variety the best move left.
There is no separate bonus for variety — a bonus large enough to matter only
ever pays the people already scoring the most.

The default cap is 200 points and it is generous on purpose: 200 push-ups, 100
pull-ups, 400 squats, 800 Russian twists, twenty minutes of plank. Across every
week logged so far, nine person-weeks out of six hundred crossed it. Distance
cardio has its own numbers, because a long ride is one session and not a farm
— 100 km of running, 100 km of walking, 200 km of biking. They live in
`public.exercises.cap`, so tuning one movement is a seed change.

Nothing is stamped. `workouts.points` stays what the movement is worth and
every board derives the discount on read, the way divisions and streaks
already do. That buys three things: an edit or a delete can never leave the
rows after it mis-scored, the order entries arrived in cannot change a week,
and the migration rewrites no history. A lifetime total is the sum of its
discounted weeks, never one giant pile run through the curve.

`gym-lifts.sql` fixes the gym formula and adds the rest of the gym. A lift is
priced by the fraction of bodyweight it moves — the same quantity that prices a
push-up — and how much of that fraction the movement already carries used to be
a yes/no: 0.85 for a standing leg lift, nothing for anything else. Right for a
bench, wrong for anything you hang from, because the number typed into a
weighted dip is what is on the *belt*. A 70 kg lifter with 20 kg round their
waist scored 0.45 a rep against 1.50 for the same rep with no belt, and needed
67 kg before the weighted version caught up. Adding weight made a movement worth
less.

It is now `R = own + (load × equip) / bodyweight`, and the belt lifts take their
`own` from the anchors, so a weighted dip with an empty belt scores exactly what
a dip scores. A standing leg lift keeps its 0.85 and a back squat is priced to
the point as it was before; a bench is unchanged, which means at 70 kg
bodyweight it still takes 45 kg to match your own push-up — 0.64 × 70, which is
the model working, not a bug.

Thirteen lifts come with it. Two of the fourteen regions on the figure had no
gym lift that led with them, so a gym-only member could not fill forearms or
lower back however hard they trained; the wrist curl and the back extension
close both. Nothing logged changes, because points are stamped when a row is
written.

`progressions.sql` adds thirty-three exercises and changes no scoring code at
all — the bank is data, so adding to it is an insert. The league was paying for
the top of every skill ladder and nothing below it: you could log a front lever
but not the tuck you spend three months on, an L-sit but not the tucked one, a
pistol but not the box pistol on the way to it. The handstand, planche, L-sit,
front lever, back lever and flag lines now have their rungs, along with jumping
and negative pull-ups, dive bombers, wall walks, cossack / box pistol / archer
squats, hollow rocks, windshield wipers, the full bridge, one-arm hangs, loaded
carries, and two loaded-cardio entries (weighted run 6.5/km, rucking 3.5/km,
both budgeted at 100 km like run and walk).

The rates are set so an honest set at your own level is worth about the same at
every rung — twenty seconds of crow pays 4.0, twenty seconds of a freestanding
handstand 10.0, five seconds of a full planche 5.0. The rate climbs steeply with
difficulty and the hold anybody can actually finish shrinks just as fast, so the
two cancel. Nobody is punished for standing at the bottom of a ladder and nobody
is paid twice for standing at the top. The same holds for the rep lines: a
jumping pull-up is 1.0 against a pull-up's 2.0 and a box pistol 0.75 against a
pistol's 2.0 — always worth logging, never worth more than the real thing, and
never under a third of it.

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
| `repetition-cap.sql` | `tools/build_cap_migration.py` |
| `gym-lifts.sql` | `tools/build_gym_migration.py` |
| `progressions.sql` | `tools/build_progression_migration.py` |
| the `muscles` seed in `schema.sql` | `tools/build_exercises.py` |
| `BODY` in `app.js` (the figure) | `tools/build_body.py`, from `tools/body_source.json` |
| `RATES`/`CATS`/`CAPS`/`MUSCLE_OF` in the browser mock | `tools/build_exercises.py` |
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
