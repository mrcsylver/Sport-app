# The database

`schema.sql` is the whole thing: paste it into the Supabase SQL editor, press
RUN, and you have a working database. It drops everything first, so running it
twice is a rebuild, not a mess — and running it on a live database wipes it.

`bounty-pool.sql`, `catch-up-day.sql`, `dashboard-points.sql`,
`body-and-crowns.sql`, `repetition-cap.sql`, `gym-lifts.sql`,
`progressions.sql`, `season-table.sql`, `season-stats.sql`, `cup.sql`,
`membership.sql`, `rest-day.sql`, `launch-gate.sql`, `shop.sql`,
`faster-board.sql`, `restore-throttle.sql` and `big-league.sql` are
migrations for a database that is already running. They only add; nothing logged is touched, and all of
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

`season-table.sql` replaces the race to five crowns with a season table, and
stores nothing to do it. People start and then fade: a week is a sprint and
winning it is all-or-nothing, so anybody who cannot realistically top the board
has no reason to care by Wednesday. The crowns race had the same hole — only a
winner ever moved, so "first to five" was a contest between the same two or
three people and wallpaper for everybody else.

Every finished week now pays by finishing position, and the season adds it up:

| | | | | | | | |
|---|---|---|---|---|---|---|---|
| 1st | 5.00 | 6th | 1.60 | 11th | 0.70 | 16th | 0.27 |
| 2nd | 3.60 | 7th | 1.35 | 12th | 0.60 | 17th | 0.21 |
| 3rd | 2.80 | 8th | 1.15 | 13th | 0.50 | 18th | 0.16 |
| 4th | 2.30 | 9th | 1.00 | 14th | 0.40 | 19th | 0.13 |
| 5th | 1.90 | 10th | 0.85 | 15th | 0.33 | 20th | 0.10 |

21st and below score nothing. A win is worth 39% more than second — the gap
motor racing uses — so the top of the board still means something, and below
that it decays gently enough that climbing always pays: 16th to 11th more than
doubles your week. Over 38 weeks a perfect run is 190 and a steady tenth is 32.

`leagues.season_weeks` already existed and did nothing but print itself; it is
the season length now, and its ceiling went from 26 to 52 so a real season fits
(38 for a football year, 50 for a calendar one, null for one that never ends). A
season is counted in **calendar** weeks from the Monday the league was created,
so a quiet week still burns one — otherwise a league that went dead for a month
would quietly extend its own season and the table would never close.

Nothing is stored. `league_season()` derives the whole table from
`weekly_history` on read, the way divisions, streaks and the repetition discount
already do, so weeks already played land in season 1 with nothing to backfill
and nothing to repair. Crowns still follow the person across every season.

Two functions here are named for a reason that is not obvious. `league_season_info`
returns six columns and `league_season_state` returns nine — the same query,
twice. The nine-column shape is the real one; the six-column name stayed because
it is live, an app in somebody's pocket is still calling it, and `create or
replace` cannot widen a function. Dropping one the hall tab polls would blank
that tab for every member until they reloaded. `my_leagues` is the same story
and is deliberately NOT carrying `season_break` for it; the off-season setting is
read off `league_season_state()` instead.

### An overload is not a compatibility shim

`set_league_settings` gained its fifth parameter as an overload on the reasoning
that PostgREST resolves by argument name, so an app that had not updated would
keep hitting the four-argument version. **That is wrong, and it broke the live
database for a day.** PostgREST does resolve by name, but a call naming four
arguments matches BOTH a four-argument function and a five-argument one whose
fifth has a default, and Postgres does not prefer the exact arity — it refuses
the call:

```
function public.set_league_settings(p_league => uuid, p_rest_dow => integer[],
  p_season_weeks => integer, p_catchup_dow => integer) is not unique
```

So a defaulted parameter is only backwards compatible if the old shape stops
being visible. Two ways out are closed here and worth writing down so nobody
spends an afternoon rediscovering them:

* `create or replace` **cannot** remove a default — *"cannot remove parameter
  defaults from existing function"* — so the tie cannot be broken by taking the
  default off the wider function.
* the migration channel this project applies through **refuses every DROP**. It
  does not error, it hangs: `drop function if exists` on a function that has
  never existed times out after sixty seconds. That was the probe that settled
  it.

What does work is `alter function … set schema`, which is not a drop. The old
shape moves into a schema called `retired`, which PostgREST does not serve and
which grants nothing to anybody, so exactly one candidate is left in `public`
and a call naming the old arguments resolves to the new function and its
defaults. It is reversible with one more `ALTER`, which a drop is not.
`supabase/season-stats.sql` does this for the two functions below, in the same
transaction that creates them, so there is no instant where both are callable.
`supabase/test/run.sh` asserts the count afterwards — one `my_stats`, one
`my_muscles`, both old shapes parked — because the failure mode is silent until
somebody on an old build opens a tab.

### A rest day belongs to a league, not to a person

`log_workout()` writes one row per league the person is in, and the rest rule
used to raise from the insert trigger. A raise from any one of those rows
aborts the whole statement — so while ONE league was resting, somebody in two
could not log anything at all, and the league that was open lost the entry
too.

The rule is a question before it is a rule now:

| | |
|---|---|
| `rest_day_block()` | why this league will not take this entry, or null |
| `rest_day_check()` | the same answer as a raise, for the triggers |

`log_workout()` filters the fan-out on the question, so the open leagues score
it and the resting ones sit it out, and raises only when **every** league
refuses — with the reason the league on screen gives, which keeps the message
identical for somebody in one league. It also returns a row from whichever
league did take it (`order by (league_id = p_league) desc limit 1`), because
asking from the resting league used to come back empty, which reads as
"nothing happened".

The triggers still call `rest_day_check()`, so a direct write — an edit, or
anything not coming through the RPC — is refused exactly as before. That
split is the point: the RPC decides which leagues to *offer* the row to, the
trigger decides whether a row is *allowed*, and they cannot drift because they
are the same function underneath.

`rest_day_block()` is deliberately **not** revoked from `authenticated`: the
update trigger runs as the person doing the edit and reaches it through
`rest_day_check()`, so taking the grant away makes every correction fail with
a permission error. It is safe to leave — not security definer, so RLS still
decides which leagues and workouts it can see.

### A revoke that does not revoke

Worth its own heading because it cost a live hole. `drop_membership()` is an
internal helper — `leave_league()` and `admin_remove_member()` call it, nothing
else should — so it shipped SECURITY DEFINER with no check of its own and

```sql
revoke all on function public.drop_membership(uuid,uuid) from public, anon;
```

**That is not enough.** A new function in `public` ends up executable by
`authenticated` as well, and revoking from `public` and `anon` leaves that
grant alone. For about an hour any signed-in person could take anybody out of
any league through `/rest/v1/rpc/drop_membership`.

Two rules came out of it, and both are in `schema.sql`:

* **Name `authenticated` in the revoke.** Every internal helper here now reads
  `from public, anon, authenticated`. Verify with
  `has_function_privilege('authenticated', p.oid, 'execute')` rather than by
  reading the revoke — the whole point is that the revoke looked right.
* **Guard the body anyway.** A SECURITY DEFINER function that writes must
  check its own caller, because one `create or replace` in a future migration
  re-grants it and nobody will notice. `drop_membership()` now refuses unless
  the caller is the person being removed or an admin.

`supabase/test/membership.sql` asserts both: that a third party is refused by
the body, and that `authenticated` has no execute privilege at all.

### Leaving, and being removed

`membership.sql` puts both halves through one function, `drop_membership()`,
because they have to agree about the two awkward cases and neither is obvious.

**The league is never deleted, even when the last member walks out.**
`leagues.id` is the parent of `workouts.league_id ON DELETE CASCADE`, and a
workout is what a lifetime total is made of — somebody who leaves their only
league to keep a quiet account must come back to the rank they earned, not to
zero. An empty league is invisible to everybody (`my_leagues()` only returns
what you are a member of) and costs one row; the control room can delete it
when it really is rubbish.

**If the owner leaves, the league goes to whoever has been in it longest.**
Otherwise `owner_id` points at a non-member and the settings, the crest and
the delete button are all unreachable for everyone. If the owner was the last
one out they stay the owner of an empty league, so rejoining with the code
hands it straight back.

`admin_remove_member()` is the half of `admin_delete_profile()` that somebody
usually actually wants: one membership goes, and the account, its restore
code, its badges and everything it logged in other leagues stay. The control
room reads `admin_memberships()` to know which leagues to offer.

An account with **no league at all** is a supported state on both clients, not
an error — the web lands on the leagues tab and iOS has a `noLeague` phase. It
used to fall through to onboarding, which hands somebody with a perfectly good
profile a "pick a fighter name" screen and implies their rank is gone.

### A finished week outlives the membership that scored it

`weekly_history()`, `league_wins()` and `league_season()` used to walk
`league_members`, which meant a week's champion vanished from the hall the
moment they left — the league's own history rewritten by somebody else's exit.

`league_roster()` is the fix: a full outer join of the membership against
"everybody who has ever logged in this league", so the history functions see
both. Each row carries a `member` boolean, and that boolean is what the live
board keys on:

| reads as | who | where they show |
|---|---|---|
| `member = true` | in the league right now | everywhere |
| `member = false` | left, kicked, or parked | the hall and the season table only |

A parked account reads exactly like somebody who left, on purpose: `member`
means "counts right now", and a seat on hold does not count. Nobody who never
scored leaves a ghost behind, because the outer join has nothing to join to.

### Seats, and parking somebody

`app_settings` is a one-row table — `only_row boolean primary key default true
check (only_row)`, so a second row is a constraint violation rather than a
convention — holding `user_cap`. Nil means no cap, which is the shipped state.

`profiles.dormant_at` is how a seat is freed without deleting anybody. A parked
profile keeps its restore code, its badges, every week it won and everything it
ever logged; it is simply invisible to the live board, to streaks, to member
counts and to league capacity, and it does not count against the cap.

| function | what it answers |
|---|---|
| `signup_state()` | cap, used, `is_full` — asked before a name box is drawn |
| `app_is_full()` | the same question as a boolean, for the guards |
| `wake_me()` | un-park me, or raise `APP_FULL` |
| `admin_overview()` | the control room's five tiles |
| `admin_set_cap(int)` | set or clear the cap |
| `admin_set_dormant(uuid, boolean)` | park or un-park somebody |

The column is `is_full`, not `full`, because `full` is a reserved word in a
`FROM` clause and `select ... from signup_state()` is how every caller reads it.

Three rules the tests pin down, because each one is a way to get this wrong:

* **the cap holds on the way back in.** `create_profile()` raises `APP_FULL`,
  and so does waking — a parked account is not owed its old seat ahead of
  somebody at the door. `restore_profile()` is the one exception and only when
  the profile is *not* parked: moving a live account to another phone is not a
  new sign-up, and the row already exists either way.
* **an admin cannot park themselves**, which would lock the only person able to
  unpark anybody out of the room that does it.
* **nobody is woken into a full app**, not even by an admin, or the count the
  cap exists to hold stops meaning anything.

`admin_set_dormant()` is deliberately manual. An "inactive for 30 days" rule
parks the person who broke an ankle and keeps the person who logs one push-up a
month, so the control room tags quiet accounts (`Nd QUIET` at thirty days) and
leaves the decision to a human.

### One poll was re-scoring the whole app

`league_leaderboard()` read `life_scored_all()`, which has no `WHERE` clause:
every workout ever logged, by anybody, in any league, sorted to dedupe the
multi-league fan-out and scored in full. The board then threw away every row
but its own members'.

The app polls that every 25 seconds, per person with it open. So the cost of
a poll grew with the app, the number of polls grew with the app, and the
product of the two is what runs out of CPU first — well before the database
runs out of room. Measured on a database seeded to 290 people with a year of
training each (49,300 workouts, 13 MB):

| part of the board | cost |
|---|---|
| `life_scored_all()` | **357 ms** |
| `week_bounty_points()` | 11 ms |
| `week_scored()` | 2.7 ms |
| `week_combo_bonus()` | 2.7 ms |

and the sort spilled to disk — 654 temp blocks — on every call.

`life_scored_in(p_league)` narrows the **people** to that league's members and
nothing else. The same board costs 38 ms, and it now scales with how many
people are in a league rather than with how big the app has become.

The thing it must never do is change a number, so `supabase/test/board.sql`
proves it equal to `life_scored_all()` for every (league, member) pair, and
the migration replay in `run.sh` asserts the same after the file is applied.
Two traps it is built around:

* **only the people are narrowed, never the leagues.** A lifetime counts what
  somebody logged everywhere, so the filter is on `profile_id` and the
  `distinct on (group_id)` dedup is untouched. Filtering by `league_id`
  instead would quietly hide a person's work in their other leagues.
* **`life_scored_all()` stays.** `admin_players()` genuinely does want
  everybody at once, and that page is read by one person, rarely.

A covering index on `(group_id, league_id)` was tried first and rejected: it
turned 370 ms into 345 ms and cost 4.4 MB. The dedup was never the problem —
scoring 290 people to show 29 was.

### The shop had no lock on it

`set_banner`, `set_avatar`, `set_name_color` and `set_league_badge` took any
string that fit the column. Length was the only check. So the first item
anybody charged for would have been free to anybody willing to call the
function by hand, and "everything here is free while we build it out" was
doing the work a paywall is supposed to do.

`shop_items` is the catalogue those four now check against. One row per
cosmetic the app can draw — 198 of them — generated by `tools/build_shop.py`
from the client's own arrays, into the SQL seed **and** the browser mock,
because the app now draws every shelf from the catalogue rather than from its
arrays. A key missing from the seed is somebody's banner refusing to save.

`key` is namespaced (`player_banner:carbon`) so a crest shape called `gold` and
a crest metal called `gold` cannot collide; `item` is the bare value a profile
stores. `may_wear(kind, item)` is the rule and `check_wear()` raises
`LOCKED_ITEM`; `shop_catalogue()` is the shelf, with `owned` worked out per
caller so the client never reasons about entitlements itself.

Three things it is careful about:

* **the empty key is always allowed** — it is how a cosmetic comes off, and a
  catalogue that refused it would make "none" unreachable.
* **an emoji avatar never goes near the catalogue.** The spec `gi:<emblem>|c=<tint>`
  is two items and both are checked; a bare emoji is not an item and never
  will be.
* **retiring takes an item off the shelf without stripping it off anybody.**
  Nothing re-reads a profile against the catalogue, so a retired row stays on
  the people wearing it and simply cannot be newly chosen.

`entitlements` is what somebody owns beyond the free rows. A payment provider
is the next writer of it; until then `admin_grant_item()` hands things out by
name, which stays useful afterwards — a prize, an apology, a founder's gift.

### A league can hold 100

36 was a hard ceiling in a CHECK constraint, and 36 is the number the five
divisions come to: 2 + 3 + 10 + 15 + 6. That is the right size for a group of
friends and the wrong one for a poster on a gym wall — the 37th person to scan
the QR code is turned away at the door, and they do not come back.

The creator picks it now, 2 to 100, at creation and afterwards. **The default
is still 36**, so a league created without an opinion is the league it has
always been, and every league that already exists keeps the size it has.

It can go **up** at any time and never below the people already in.
`enforce_league_capacity` only runs on the way IN, so shrinking would remove
nobody — it would leave a league reading 40/30 and refusing the 41st with no
way to explain itself. `set_league_settings` raises `LEAGUE_SHRINK` instead,
and the box in the app says what the floor is before you type into it.

Both functions changed shape, which is the awkward part and the reason
`big-league.sql` is not a create-only file. A defaulted new parameter looks
like it keeps an app that has not updated working. It does not: PostgREST
resolves a call by argument **name**, so an old call matches both versions and
Postgres refuses it as not unique. Exactly one of each may be visible, so the
old pair moves into the `retired` schema in the same transaction — the same
trick `season-stats.sql` used.

**The divisions are client-side**, so they are not in the SQL, but they had to
move with it. Up to 36 rows the split is the fixed 2/3/10/15/6 and nothing
about an existing league changes. Past it, the bottom three grow in the
proportion they already have and the top two never do:

| table | Royal Guard | Apex | Vanguard | Forge | Commoner |
|---|---|---|---|---|---|
| 36 | 2 | 3 | 10 | 15 | 6 |
| 60 | 2 | 3 | 18 | 27 | 10 |
| 100 | 2 | 3 | 31 | 46 | 18 |

A Royal Guard of six is not a Royal Guard — the whole point of those five
places is that one good evening can push you out of them. Without the rule the
overflow all landed in COMMONER, so a league of 100 read as five divisions and
then a crowd of seventy.

**What it costs.** A board is about 276 bytes per member per poll, so a
100-person board is ~28 KB against ~10 KB for 36. Free Supabase gives 5 GB of
egress a month. At a realistic five minutes of app-open time per person per
day that is roughly 1 GB a month for a full 100-seat league — comfortable, but
no longer something to ignore. The poll backoff (25 s when a board is moving,
up to 5 minutes when it is not) is what keeps it there, so if egress ever gets
close, that interval is the lever, not the league size.

### Ten guesses an hour at a restore code

A restore code is 8 hex characters: 32 bits, and whoever has one owns the
account it belongs to — its history, its badges, every week it won. That was a
sensible trade while the only way to try a code was to type it into a phone and
everybody with the app was a friend. It stops being one the day the app is
advertised on a wall, because then 32 bits is a number a script walks.

`restore_profile()` now refuses a caller after ten failures in a rolling hour —
**the right code included**, which is the only part that matters: a script that
finally lands on a real code still cannot spend it. The count is of failures
only, so somebody typing their own code correctly is never affected however
often they do it, and the window rolls, so a lockout is an hour and not
forever. `restore_tries` is the log; RLS is on with no policy at all, so the
only thing that can read or write it is the `SECURITY DEFINER` function itself
and a caller cannot clear their own record.

It is keyed on `auth.uid()`, because Postgres cannot see the caller's IP from
PostgREST. That is only worth having because the cheap way to get a fresh uid —
signing in anonymously — is itself behind a CAPTCHA. The two together are the
fence; either one alone is a gate.

**The part that is not obvious.** The obvious way to write this is: record the
failure, then `raise exception 'BAD_CODE'` the way every other refusal in the
file does. It does not work. PostgREST runs one call as one transaction, so the
raise rolls back the row that records the failure that caused it. The counter
counted to zero forever, the lock never closed, and nothing about the app
looked any different from outside — the caller gets the same refusal either
way. The first version shipped here was written that way and
`supabase/test/guessing.sql` section 2 is the check that found it.

So a code that matches nothing is answered with **zero rows** instead, which
means the return type went from `public.profiles` to `setof public.profiles`.
`create or replace` cannot change a return type, so `restore-throttle.sql`
moves the old version into the `retired` schema in the same transaction —
the same trick `season-stats.sql` used, reversible with one `ALTER`.

That also took `restore_profile` out of `launch-gate.sql`, which used to carry
it: a generated migration lifts the *current* definition out of `schema.sql`,
and lifting the new one into a file that runs before this one made that file
fail outright on any database already holding the new shape. The APP_FULL
branch `launch-gate.sql` added to the function is still there — it travels in
`restore-throttle.sql` now, which runs after it.

Both clients read an empty answer as "no profile has that code", which is what
a wrong code means anyway, so **this file goes in before the app, not after**.
The other order would leave a real refusal looking like a crash.

### Uploaded designs, and the bucket they live in

`profiles.frame` is a ring drawn around an avatar on every row of every board.
It is the one cosmetic slot that is uploaded artwork rather than CSS, because a
ring is small, sits on one element, and is where a moving design is worth its
bytes — and it is the only cosmetic that shows on somebody else's screen
without them opening anything.

`league_frames()` is how a board learns who is wearing one. A separate call
rather than a column on `league_leaderboard()`, `league_streaks()`, the duel
pair and four more that already return an avatar: widening a return type means
dropping the function first, and seven drops to carry one short text column is
the wrong trade. Only people actually wearing a ring come back, so it is
usually empty.

The `designs` bucket holds the files, created by a guarded `do` block at the
foot of `schema.sql` — guarded because this file has to run on a plain
Postgres too, and the SQL test rig has no `storage` schema. Reading is public
and goes through the CDN, which is the only way the bandwidth works on a free
project. Writing is admin-only, checked by the same `is_admin()` flag as
everything else.

`allowed_mime_types` is the real gate, and **SVG is deliberately not on it**: an
SVG can carry script, and this app inlines emblem SVGs, so one uploaded here
would be one paste away from running. The client never inlines an uploaded
file either — uploaded artwork is always an `<img>`, which cannot run anything
whatever the bytes turn out to be. PNG, WebP and Lottie JSON cover everything
the shop needs, animation included.

### The cup

`cup.sql` adds a straight knockout for the top of the season, played over its
last four weeks. Create-only: nothing already live changes shape.

The season table rewards turning up, which is the right thing to reward and a
quiet thing to watch. The cup is the other half — one bad week ends you however
good the year has been.

* the field is the top 16 of the season; 8 or 4 in a league that cannot fill
  16, and no cup under 4
* the bracket appears ten weeks before the final and is drawn from the table as
  it stands, so a ninth place can see who they would draw and a seventeenth can
  see what they are missing
* it locks four weeks out, then runs one round a week, with the final in the
  season's last week
* a tie is won on that week's league points; a dead heat goes to the higher
  seed, which is what keeps the regular season worth playing

Nothing is stored. `cup_seeds()` cuts the season table to the weeks before the
lock, `league_cup_state()` says which phase the cup is in, and `league_cup()`
walks the rounds and returns one row per tie. `cup_seeds()` and the three
arithmetic helpers are not granted to anybody: they are read by the two
security-definer functions above and never by an app.

One piece of that arithmetic is worth spelling out, because the obvious version
does not terminate. The lock date is **fixed at four weeks before the final**,
whatever the field turns out to be, and a smaller field simply starts later. It
has to be fixed: the field size is read off the weeks before the lock, so if
the lock moved with the field size neither would ever settle. A field of 8
therefore ignores the week between the lock and its own first round for
seeding, which is a week of slack, not a bug.

`a_from` and `b_from` on each tie are the seeds that can still arrive on that
side — a quarter-final reads `1/16 v 8/9` until both halves are settled. That
is what makes the bracket worth looking at six weeks before it is played, which
is the whole reason it shows up early.

### A season on the stats tab

The tab had `THIS WEEK` and `ALL TIME`. The season is the unit the league plays
in and had no tab, so "how is my season going" could only be answered from the
hall table, which shows placings rather than what you lifted. `my_stats()` and
`my_muscles()` take a third argument, `p_from`, which bounds the range below:

| tab | `p_all` | `p_from` |
|---|---|---|
| week | false | null |
| season | true | `league_season_state().first_week` |
| all time | true | null |

The bound is a date rather than a season number so nothing has to be stored, and
an off-season shows the season that just closed instead of an empty tab. The
rank ladder stays lifetime whatever the tab shows: a season view that reset
somebody's rank would read as the app losing their work, so it asks for the
unbounded range separately.

`season_break` is how many weeks of off-season sit between one season and the
next — 0 to 6, two by default. A cycle is `season_weeks` of play then
`season_break` of rest, and it repeats. A break week belongs to no season:
`season_index()` returns null for it, so it pays nobody season points and the
table a break shows is the final standings of the season that just ended. The
league stays open through it and the week still scores for the hall of fame — a
breather, not a shutdown. An endless season never breaks, whatever the break is
set to.

The TRIPLE CROWN, FIVE CROWNS and TEN CROWNS badges go with the race. CHAMPION
— win a week — stays, because winning a week is still the thing.

The rank ladder is client-side only, so it is not in here, but it moved at the
same time: it used to top out at 50,000 lifetime points, which the league's best
player — measured at 1,082 points a week on real data — reached in eleven
months. A lifetime ladder you finish inside a year has nothing at the top of it.
ETERNAL is 300,000 now, which is 5.5 years at that rate and 8.6 at a strong but
not top 700 a week. The eleven grades, their numerals and the 25-40% step
between rungs are untouched; only the scale moved, so SPARK is still the first
session.

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
- `restore_profile`'s new throttle recorded its failures and then raised,
  which rolled the record back, so the lock never closed. Nothing about the
  call looked different from outside — only counting the rows afterwards
  showed it.
- `launch-gate.sql`, generated months earlier, carried a `create or replace`
  of that same function and so stopped running the moment its return type
  changed. The suite applies every migration three times for exactly this.

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
| `season-table.sql` | `tools/build_season_migration.py` |
| `season-stats.sql` | `tools/build_stats_migration.py` |
| `cup.sql` | `tools/build_cup_migration.py` |
| `membership.sql` | `tools/build_membership_migration.py` |
| `rest-day.sql` | `tools/build_restday_migration.py` |
| `launch-gate.sql` | `tools/build_launchgate_migration.py` |
| `shop.sql` | `tools/build_shop_migration.py` |
| `faster-board.sql` | `tools/build_board_migration.py` |
| `restore-throttle.sql` | `tools/build_restore_migration.py` |
| `big-league.sql` | `tools/build_bigleague_migration.py` |
| the `muscles` seed in `schema.sql` | `tools/build_exercises.py` |
| `BODY` in `app.js` (the figure) | `tools/build_body.py`, from `tools/body_source.json` |
| `RATES`/`CATS`/`CAPS`/`MUSCLE_OF` in the browser mock | `tools/build_exercises.py` |
| the `SHOP` block in `schema.sql` and in the browser mock | `tools/build_shop.py` |
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
