#!/usr/bin/env python3
"""Write the bounty seed into both places it has to exist, from one source.

  · supabase/schema.sql        the paste-and-run rebuild
  · supabase/bounty-pool.sql   the migration for a database already running

It validates first: every exercise key must exist in the bank, every mode
must be one the exercise actually offers, every category must be real, and
no two bounties may share a name. A bounty that names an exercise nobody
can log is a bounty nobody can ever complete.

Usage:  python3 tools/build_bounties.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from bounty_pool import POOL                                    # noqa: E402

SCHEMA = os.path.join(ROOT, "supabase", "schema.sql")
MIGRATION = os.path.join(ROOT, "supabase", "bounty-pool.sql")
BANK = os.path.join(HERE, "exercises.json")

CATS = {"PUSH", "PULL", "LEGS", "CORE", "CARDIO", "SPORT", "GYM", "RECOVERY"}

# A bounty is the one thing in the app that is handed to everybody at once, so
# it has to be something everybody can actually do. No gym, no pool, no bike,
# no pitch, no rope — and no move that takes a year to learn. Somebody with a
# floor, a wall, a chair, a bar and a street should be able to finish every
# quest in the pool.
EVERYWHERE = {
    # push
    "wallpush", "kneepush", "inclinepush", "pushups", "widepush", "diamondpush",
    "declinepush", "pikepush", "benchdips", "dips", "sphinxpush",
    # pull
    "rows", "scapulapull", "chinups", "pullups", "widepullup", "commandopull",
    "deadhang",
    # legs
    "calves", "airsquats", "jumpsquats", "lunges", "splitsquat", "stepups",
    "gluteBridge", "wallsit",
    # core
    "crunches", "situps", "twists", "legraises", "kneeraises", "hangingleg",
    "vups", "supermans", "sidecrunch", "bicycle", "deadbug", "birddog",
    "flutterkick", "mountainclimb", "plank", "sideplank", "hollowhold",
    # cardio, and the one recovery entry
    "run", "sprints", "walk", "stretch",
}

# Categories a quest may ask for points from. GYM needs a gym and SPORT needs
# somewhere to play, so neither can be the whole requirement.
EVERYWHERE_CATS = {"PUSH", "PULL", "LEGS", "CORE", "CARDIO", "RECOVERY"}
KINDS = {"reqs", "any", "distinct", "cat_points", "cats", "reps_across",
         "split", "hourly", "pr", "team", "duo", "underdog"}


def bank():
    items = json.load(open(BANK))
    return {x["key"]: x for x in items}


def check(pool, ex):
    """Every claim a bounty makes must be one the app can actually satisfy."""
    problems = []
    names = {}
    for i, (name, descr, points, spec) in enumerate(pool):
        where = "#%d %s" % (i, name)
        if name in names:
            problems.append("%s: name already used at #%d" % (where, names[name]))
        names[name] = i
        if not 5 <= points <= 100:
            problems.append("%s: %d points is outside 5…100" % (where, points))

        kind = spec.get("kind", "reqs")
        if kind not in KINDS:
            problems.append("%s: unknown kind %r" % (where, kind))
            continue

        reqs = []
        if kind == "reqs":
            reqs = spec.get("reqs", [])
            if not reqs:
                problems.append("%s: no requirements" % where)
        elif kind == "any":
            reqs = spec.get("any", [])
            if len(reqs) < 2:
                problems.append("%s: 'any' with fewer than two options" % where)
        elif kind in ("split", "hourly"):
            reqs = [{"ex": spec.get("ex"), "mode": "reps"}]
        elif kind == "cat_points":
            if spec.get("cat") not in CATS:
                problems.append("%s: %r is not a muscle group" % (where, spec.get("cat")))
        elif kind == "cats":
            for c in spec.get("cats", []):
                if c.get("cat") not in CATS:
                    problems.append("%s: %r is not a muscle group" % (where, c.get("cat")))

        for r in reqs:
            key = r.get("ex")
            if key is None:
                continue
            if key not in ex:
                problems.append("%s: no such exercise %r" % (where, key))
                continue
            mode = r.get("mode")
            if mode and mode not in ex[key]["modes"]:
                problems.append("%s: %s cannot be logged in %s (only %s)"
                                % (where, key, mode, "/".join(sorted(ex[key]["modes"]))))
    problems += reachable(pool)
    return problems


def reachable(pool):
    """Every quest must be finishable by everybody in the league.

    An "any" quest only needs one of its options to be open to everyone —
    that is the whole point of offering a choice. Everything else has to be
    open on every requirement it names.
    """
    out = []
    for i, (name, _descr, _points, spec) in enumerate(pool):
        kind = spec.get("kind", "reqs")
        where = "#%d %s" % (i, name)

        if kind == "any":
            options = [r.get("ex") for r in spec.get("any", [])]
            if options and not any(k in EVERYWHERE for k in options if k):
                out.append("%s: none of its options is open to everyone (%s)"
                           % (where, ", ".join(str(o) for o in options)))
            continue

        if kind == "cat_points":
            if spec.get("cat") not in EVERYWHERE_CATS:
                out.append("%s: %s needs a gym or somewhere to play"
                           % (where, spec.get("cat")))
            continue

        if kind == "cats":
            for c in spec.get("cats", []):
                if c.get("cat") not in EVERYWHERE_CATS:
                    out.append("%s: %s needs a gym or somewhere to play"
                               % (where, c.get("cat")))
            continue

        named = [r.get("ex") for r in spec.get("reqs", [])]
        if spec.get("ex"):
            named.append(spec["ex"])
        for key in named:
            if key and key not in EVERYWHERE:
                out.append("%s: %s is not something everybody can do" % (where, key))
    return out


def sql_rows(pool):
    out = []
    for i, (name, descr, points, spec) in enumerate(pool):
        out.append("(%d,%s,%s,%d,%s)"
                   % (i, q(name), q(descr), points,
                      q(json.dumps(spec, separators=(",", ":")))))
    return ",\n".join(out)


def q(text):
    return "'" + str(text).replace("'", "''") + "'"


HEAD = """-- The bounty pool: %d side quests. One is drawn each week; which one is a
-- deterministic shuffle of the whole pool, reseeded every year, so no two
-- years run the same order and nothing repeats inside a year.
--
-- GENERATED by tools/build_bounties.py from tools/bounty_pool.py — edit
-- there and re-run, never here.
"""


def stamp_count(n):
    """builtin_bounty_count() must equal the pool, or a generated bounty could
    be deleted from the control room as if somebody had written it."""
    s = open(SCHEMA, encoding="utf-8").read()
    fixed = re.sub(r"(create function public\.builtin_bounty_count\(\) returns int\n"
                   r"language sql immutable set search_path = public as \$\$ select )\d+",
                   r"\g<1>%d" % n, s)
    if fixed != s:
        open(SCHEMA, "w", encoding="utf-8").write(fixed)


def stamp_everywhere():
    """Write the open list into bounty_open_to_all().

    The control room can write a bounty too, and it must be held to the same
    rule as the generated pool. Keeping the list in one place is the only way
    the two do not drift: this rewrites the array in schema.sql from the same
    set `reachable` validates against.
    """
    s = open(SCHEMA, encoding="utf-8").read()
    keys = ",\n    ".join("'%s'" % k for k in sorted(EVERYWHERE))
    fixed = re.sub(r"(create function public\.bounty_open_to_all\(p_key text\) "
                   r"returns boolean\nlanguage sql immutable set search_path = public "
                   r"as \$\$\n  select p_key = any \(array\[\n    ).*?(\n  \]\))",
                   lambda m: m.group(1) + keys + m.group(2), s, flags=re.S)
    if fixed == s and "'wallpush'" not in s:
        raise SystemExit("cannot find bounty_open_to_all() in schema.sql")
    if fixed != s:
        open(SCHEMA, "w", encoding="utf-8").write(fixed)
    return len(EVERYWHERE)


MOCK = os.path.join(HERE, "test", "mock-supabase.js")


def stamp_mock():
    """The browser mock has to refuse what the server refuses.

    It answered a control room that can no longer offer a gym lift, so the
    list lives here too — written from the same set, never typed twice.
    """
    s = open(MOCK, encoding="utf-8").read()
    keys = "".join("    %s: 1,\n" % k if k.isidentifier() else "    '%s': 1,\n" % k
                   for k in sorted(EVERYWHERE))
    block = ("/* OPEN-TO-ALL BEGIN */\n  var OPEN_TO_ALL = {\n"
             + keys.rstrip(",\n") + "\n  };\n  /* OPEN-TO-ALL END */")
    fixed = re.sub(r"/\* OPEN-TO-ALL BEGIN \*/.*?/\* OPEN-TO-ALL END \*/",
                   lambda m: block, s, flags=re.S)
    if fixed == s and "OPEN-TO-ALL BEGIN" not in s:
        raise SystemExit("cannot find the OPEN-TO-ALL block in mock-supabase.js")
    if fixed != s:
        open(MOCK, "w", encoding="utf-8").write(fixed)


SEED_MARK = "-- The bounty pool:"


def write_schema(pool):
    """Replace the seed AND the header above it.

    Replacing only the INSERT left the previous run's header in place and
    prepended a new one, so the comment grew by four lines every time this
    was run. Start from the marker when it is there.
    """
    s = open(SCHEMA, encoding="utf-8").read()
    insert = s.index("insert into public.bounties (idx, name, descr, points, spec) values")
    mark = s.rfind(SEED_MARK, 0, insert)
    start = mark if mark >= 0 else insert
    end = s.index(";\n", insert) + 2
    block = (HEAD % len(pool)
             + "insert into public.bounties (idx, name, descr, points, spec) values\n"
             + sql_rows(pool) + ";\n")
    open(SCHEMA, "w", encoding="utf-8").write(s[:start] + block + s[end:])
    return len(block.splitlines())


from sqllift import lift, grants                                 # noqa: E402


MIGRATION_OBJECTS = [
    ("table", "bounty_schedule"),
    ("function", "bounty_open_to_all"),
    ("function", "bounty_exercises"),
    ("function", "bounty_cat_points"),
    ("function", "bounty_done"),
    ("function", "bounty_index"),
    ("function", "bounty_pick"),
    ("function", "builtin_bounty_count"),
    ("function", "week_bounty_points"),
    ("function", "current_bounty"),
    ("function", "admin_schedule"),
    ("function", "admin_bounties"),
    ("function", "admin_pin_bounty"),
    ("function", "admin_unpin_bounty"),
    ("function", "admin_add_bounty"),
    ("function", "admin_delete_bounty"),
]


def write_migration(pool):
    schema = open(SCHEMA, encoding="utf-8").read()
    parts = [MIGRATION_HEAD % {"count": len(pool)}]
    parts.append("-- ------------------------------------------------------------ the pool ---")
    parts.append("delete from public.bounties where idx >= %d;\n" % len(pool))
    parts.append("insert into public.bounties (idx, name, descr, points, spec) values")
    parts.append(sql_rows(pool))
    parts.append("on conflict (idx) do update\n"
                 "  set name = excluded.name, descr = excluded.descr,\n"
                 "      points = excluded.points, spec = excluded.spec;\n")
    for kind, name in MIGRATION_OBJECTS:
        parts.append("-- " + ("-" * (72 - len(name))) + " " + name + " ---")
        parts.append(lift(schema, kind, name) + "\n")
    # after the schedule table exists, or there is nothing to insert into
    parts.append(KEEP_THIS_WEEK)
    parts.append("-- -------------------------------------------------------------- grants ---")
    parts.append(grants(schema))
    parts.append("\ncommit;")
    body = "\n".join(parts) + "\n"
    open(MIGRATION, "w", encoding="utf-8").write(body)
    return len(body.splitlines())


# Changing the rotation mid-week changes which quest the week was for, and
# because bounty points are worked out on read rather than stored, anybody who
# had already finished the old one loses the points for it. A week being played
# keeps the quest it started with; the shuffle takes over from the next Monday.
KEEP_THIS_WEEK = """-- ------------------------------------------- the week already in progress ---
-- Only pins a week somebody has actually logged in, so a fresh database is
-- left alone and the shuffle starts clean.
insert into public.bounty_schedule (week_start, bounty_idx, note)
select public.current_week_start(),
       ((floor((public.current_week_start() - date '2026-01-05') / 7)::int % 52) + 52) % 52,
       'kept from the old rotation: this week was already being played'
where exists (select 1 from public.workouts
              where week_start = public.current_week_start())
on conflict (week_start) do nothing;
"""


MIGRATION_HEAD = """-- ======================================================================
--  IRON LEAGUE — the bounty pool
--
--  Paste the whole file into the Supabase SQL editor and press RUN.
--  Safe to run twice. Nothing already logged is touched.
--
--  GENERATED by tools/build_bounties.py, which lifts every function below
--  straight out of supabase/schema.sql. Edit tools/bounty_pool.py or
--  schema.sql and re-run it — never edit this file.
--
--  What changes:
--    · the pool grows to %(count)d quests, including short ones worth a flat 20
--      points that take under three minutes, so a busy week still scores
--    · a bounty can now ask for points from one muscle group only — pulling
--      day, cardio day, iron day — and nothing else counts toward it
--    · which quest runs in a week becomes a shuffle of the whole pool,
--      reseeded every year, instead of week-number modulo 52
--    · you can pin a chosen quest to a chosen week, and write your own,
--      from the control room
-- ======================================================================
begin;
"""


def main():
    ex = bank()
    problems = check(POOL, ex)
    if problems:
        print("The pool does not hold up:")
        for p in problems:
            print("  ·", p)
        sys.exit(1)

    stamp_count(len(POOL))
    n0 = stamp_everywhere()
    stamp_mock()
    n1 = write_schema(POOL)
    n2 = write_migration(POOL)
    print("%d bounties validated, all of them out of the %d exercises "
          "everybody has" % (len(POOL), n0))
    print("  schema.sql seed    : %d lines" % n1)
    print("  bounty-pool.sql    : %d lines" % n2)


if __name__ == "__main__":
    main()
