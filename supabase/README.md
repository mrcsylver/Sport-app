# The database

`schema.sql` is the whole thing: paste it into the Supabase SQL editor, press
RUN, and you have a working database. It drops everything first, so running it
twice is a rebuild, not a mess — and running it on a live database wipes it.

`bounty-pool.sql` and `scoring-modes.sql` are migrations for a database that
is already running. They only add; nothing logged is touched, and both are
safe to run twice.

## Testing it for real

```bash
supabase/test/run.sh
```

This starts a throwaway Postgres, builds the database from `schema.sql`,
exercises the bounty system, then applies the migration three times to a
database wound back to look like the live one.

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
| `scoring-modes.sql` | `tools/build_scoring.py` |

`build_bounties.py` validates before it writes: every exercise a bounty names
must exist, and must be loggable in the mode the bounty asks for. It has
already caught six quests that nobody could have completed — a three-minute
plank asked for seconds, and plank is only logged in minutes.

Neither migration is written by hand. Every function in them is lifted out of
`schema.sql`, which is the one definition of each, because two hand-kept
copies of a hundred-line function drift and the drift is always found in
production. `tools/sqllift.py` does the lifting; the two generators only say
which objects they need.

One thing the lift has to know: `create or replace function` cannot change
what a function returns. `league_leaderboard` and `my_leagues` both gained a
column, so `build_scoring.py` drops those two first and rebuilds them.

## Why `check_function_bodies` is off

The first thing `schema.sql` does is `set check_function_bodies = off`. These
functions call each other in both directions, and Postgres resolves a SQL
function body the moment the function is created — so a strict run stops at
the first forward reference, and the file would only work if it were sorted
into an order no human could maintain. Every body is still parsed, so a typo
is still an error; only name resolution is deferred.
