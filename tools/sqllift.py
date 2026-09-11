#!/usr/bin/env python3
"""Lift objects out of schema.sql so a migration never retypes them.

schema.sql is the one definition of every table and function. A migration is
the same definitions made safe to run on a database that already exists:
`create` becomes `create or replace`, `create table` becomes
`create table if not exists`, and a policy is dropped before it is recreated.

Two hand-kept copies of a hundred-line function drift, and the drift is always
found in production.
"""
import re
import sys


def lift(schema, kind, name):
    """One object out of schema.sql, made safe to run on a live database."""
    if kind == "function":
        # A body ends with "$$;" — on its own line for most, after "end " for
        # plpgsql, and at the end of the same line for a one-liner. Requiring
        # any particular shape made the match run on and swallow whole
        # functions that came after it, so this stops at the first line that
        # ends there, whatever precedes it.
        m = re.search(r"^create function public\.%s\(.*?\$\$;$"
                      % re.escape(name), schema, re.S | re.M)
        if not m:
            raise SystemExit("cannot find function %s in schema.sql" % name)
        return one_object(m.group(0), name).replace(
            "create function", "create or replace function", 1)

    m = re.search(r"^create table public\.%s \(.*?^\);$" % re.escape(name),
                  schema, re.S | re.M)
    if not m:
        raise SystemExit("cannot find table %s in schema.sql" % name)
    body = one_object(m.group(0), name).replace(
        "create table public.", "create table if not exists public.", 1)
    # the RLS lines that belong with it
    rls = re.search(r"^alter table public\.%s enable row level security;\n"
                    r"create policy (\w+) on public\.%s\n(.*?);$"
                    % (re.escape(name), re.escape(name)), schema, re.S | re.M)
    if rls:
        body += ("\nalter table public.%s enable row level security;"
                 "\ndrop policy if exists %s on public.%s;"
                 "\ncreate policy %s on public.%s\n%s;"
                 % (name, rls.group(1), name, rls.group(1), name, rls.group(2)))
    return body


def one_object(block, name):
    """A lifted block must contain exactly one definition.

    An over-greedy match looks fine until the migration is run: the swallowed
    function keeps its plain "create function", and applying the file twice
    fails on "already exists". Cheaper to notice here.
    """
    n = len(re.findall(r"^create (?:table|function) ", block, re.M))
    if n != 1:
        raise SystemExit("lifting %s picked up %d definitions — the match ran on"
                         % (name, n))
    return block


BOUNTY_GRANTS = ("bounty_pick", "bounty_cat_points", "builtin_bounty_count",
                 "admin_schedule", "admin_bounties", "admin_pin_bounty",
                 "admin_unpin_bounty", "admin_add_bounty", "admin_delete_bounty",
                 "bounty_schedule")


def grants(schema, wanted=BOUNTY_GRANTS):
    """The revokes and grants schema.sql already spells out for these."""
    out = []
    kept_last = False
    for line in schema.splitlines():
        t = line.strip()
        is_grant = t.startswith("grant ") or t.startswith("revoke ")
        is_tail = t.startswith("to authenticated;") or t.startswith("from public, anon;")
        if not (is_grant or is_tail):
            continue
        if is_tail:
            # a grant long enough to wrap; it belongs to the line above, and
            # only travels if that line was one we kept
            if kept_last and out:
                out[-1] = out[-1] + "\n" + line
            continue
        kept_last = any(w in line for w in wanted)
        if kept_last:
            out.append(line)
    return "\n".join(out)


