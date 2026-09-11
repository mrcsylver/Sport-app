# Iron League — decisions parked for later

Things we have decided but deliberately have not built. Each one says **why**
it is waiting and **what has to happen** before it can be picked up, so nobody
has to reconstruct the reasoning months from now.

---

## 1. Per-league timezone (blocks worldwide release)

**Decision: yes, before the app goes out beyond one country.**

Today `app_timezone()` is a single value (`Europe/Paris`) baked into
`config.js`. Everything that has a clock in it reads that one function:

| what | why the timezone matters |
|---|---|
| `current_week_start()` | when Monday 00:00 actually happens |
| `is_rest_day()` / `rest_day_check()` | which calendar day a rest day falls on |
| `bounty_date()` / `bounty_index()` | which day the weekly quest runs |
| `week_combo_bonus()` | which logs count as "the same day" |
| the countdown in `app.js` | the clock every phone shows |

A league in Sydney on a Paris clock closes its week on **Monday morning
local**, and its Thursday bounty half lands on Wednesday. That is not cosmetic:
it changes who wins.

**What to do.** Add `leagues.tz text not null default 'Europe/Paris'`, then
thread the league through every function above — most already take
`p_league`, so the change is mechanical but wide. The client already computes
its countdown from an offset, so it needs the league's tz instead of the
global one.

**Why not now.** Every member is in Paris, so the benefit today is zero and
the blast radius is the entire scoring core. Do it as its own change, with
the full test suite green before and after, not bundled with features.

**Watch out for:** a person in two leagues in different timezones. Their
workout fans out to both, and each row must be stamped with *that* league's
week. `workouts.week_start` is set once per row in `workouts_stamp()`, so it
already can be per-league — but the trigger currently calls
`current_week_start()` with no argument. That is the one line that matters.

---

## 2. Pooled entry fees / prize pots — United States only

**Question asked: can we ship this in the US only?**

**Answer: yes, and country-gating is the normal way this is done** — but the
gate is the easy half.

Holding a pot of other people's money and taking a cut of it is regulated
differently in almost every country. In France it lands near ANJ (gambling)
territory. Several US states also restrict paid-entry contests
(Washington, Arizona, Iowa, Louisiana, Montana are the usual list daily
fantasy operators carve out), so "the US" is not one jurisdiction either.

**What shipping it actually needs**, beyond the code:

1. A payment provider that knows you are pooling stakes and approves it —
   Stripe requires disclosure for contests with prizes; being shut off
   mid-season is the real risk, not a fine.
2. Identity and location checks on the organiser, and probably on entrants.
3. A written answer on the states you exclude.
4. Someone to hold the float and handle refunds when a season is abandoned.

**Technically**, gating is straightforward: a `country` on the profile or the
league, the feature hidden unless it is `US` and not an excluded state, and
the payment rails only mounted for those leagues. Keep the pot **entirely
separate** from scoring — the leaderboard must never know money exists, so
that pulling the feature later removes a screen and nothing else.

**Recommended order:** sponsored bounties first (advertising, not stakes, no
regulator), and only look at pots once there are enough users for the legal
work to be worth paying for.

---

## 3. "Tournament pot" → a real merchandise shop

The original note said *tournament pot* and nobody could remember what it
meant. Reinterpreted, and this version is better:

**A shop where the league buys real things — shirts, bands, bottles — from us
directly, and we ship them.**

- It is a straightforward goods sale. No pooled stakes, no regulator, no
  holding anyone else's money.
- It fits what the app already knows: a league with a crest and a name is a
  team that wants a shirt with that crest on it.
- Beta shows a placeholder only. Nothing takes payment.

**Before building:** who fulfils and ships (print-on-demand vs. stock),
returns, VAT on physical goods across borders. All ordinary retail problems,
all solvable, none of them legal risk.

---

## 4. Master League Pass

A one-off unlock for the organiser, not a subscription and not per player:
unlimited slots above the free cap, custom crest and colours, penalty
trackers, raw data export. Charged once, to the person who set the league up.

Parked because pricing depends on what the free tier ends up being, and that
depends on real usage. The slot exists in the shop.

---

## 5. Bounty types that block logging

**Decided against.** The idea was an endurance-only week where rep-based
exercises cannot be logged. An app that refuses to record training somebody
actually did is worse than one that scores it oddly — the log is the one
thing that must always accept the truth.

**Do instead:** themed weeks that *reweight* rather than reject. Endurance
week doubles cardio; strength week doubles the heavy lifts. Same intent,
nothing is ever turned away.

---

## 6. Still to build from the motivation list

- ~~**Co-op league raids**~~ — built.
- ~~**Badges tab**~~ — built.
- **Sponsored bounties** — the upload path exists now (the control room can
  write a quest and pin it to a week). What is missing is a sponsor worth
  the trouble, and a way to show whose quest it is without it reading as an
  advert inside somebody's training log.


## 7. A season that does not restart every week

**Asked for on 11 September.** The board resets every Monday. That is right
for most people — a bad week is forgotten by Tuesday, which is most of why
anybody comes back. But a serious athlete on a training block wants the
opposite: one table that runs for a month, with rest days, and no weekly
wipe.

This is not a setting we can add in an afternoon, and it is worth being
honest about why. `week_start` is stamped on every workout row and is the
key that the leaderboard, the combo bonus, the bounty, the raid, the
rivalry pairing and the whole hall of fame all group by. A league that does
not reset weekly needs a second grouping — call it a block — that those
seven things read instead, and every one of them needs an answer to a
question it has never been asked:

- **The leaderboard** is the easy one: group by block instead of week.
- **The daily combo** is unaffected; it is already per-day.
- **The bounty** runs once a week on a fixed weekday. In a month-long block
  it should probably still be weekly — four bounties inside one table —
  rather than one bounty a month, which would be forgettable.
- **The raid** is calibrated on a week of the league's real output. Over a
  month the target has to be four times bigger, and a league that falls
  behind in week one can see it is unreachable by week two, which is worse
  than no raid.
- **Rivalries** pair off using last week's finish. In a block they would
  have to re-pair weekly anyway, or the same two people are stuck together
  for a month.
- **The hall of fame** currently shows finished weeks. It would show
  finished blocks, and a league that switched mid-way has a history of two
  different shapes.
- **Streaks** are per-day and unaffected.

The shape that probably works: keep the week as the unit everything is
*scored* in, and add a block that is only a way of *totalling* weeks. A
month-long league is then four normal weeks whose points are added up, the
bounty and raid keep working exactly as they do, and the only new thing is
which total the table shows. That is a much smaller change than a second
grouping key, and it gives the athlete what they actually want: a table
that does not wipe.

Worth doing when somebody actually asks for it twice. Right now it is one
person's guess about what other people would like.
