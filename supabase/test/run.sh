#!/usr/bin/env bash
# Run schema.sql, then the migration, then the bounty tests, against a throwaway
# Postgres. This is the only way to find out whether the SQL actually works —
# parsing it proves nothing, and two real bugs (a function whose parameter list
# did not match its body, and a REVOKE naming a signature that does not exist)
# were both invisible until the file was executed.
#
#   supabase/test/run.sh
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$(dirname "$HERE")")"
PGD=${PGD:-/var/tmp/ironpg}
PORT=${PORT:-55432}
BIN=${BIN:-/usr/lib/postgresql/16/bin}

if ! pg_isready -h /var/tmp -p "$PORT" >/dev/null 2>&1; then
  echo "· starting a scratch Postgres in $PGD"
  rm -rf "$PGD"; mkdir -p "$PGD"
  chown postgres:postgres "$PGD"; chmod 700 "$PGD"
  su postgres -c "$BIN/initdb -D $PGD -U postgres --auth=trust" >/dev/null
  su postgres -c "$BIN/pg_ctl -D $PGD -o '-p $PORT -k /var/tmp' -l /var/tmp/pg.log start" >/dev/null
  sleep 2
fi

psql() { command psql -h /var/tmp -p "$PORT" -U postgres -v ON_ERROR_STOP=1 "$@"; }

# Each test file gets its own database. They seed the same fixture ids, and a
# shared database only means one of them fails on a duplicate key.
fresh() {
  psql -q -c "drop database if exists $1;" -c "create database $1;" 2>/dev/null
  psql -q -d "$1" -f "$HERE/bootstrap.sql"
  psql -q -d "$1" -f "$ROOT/supabase/schema.sql" >/dev/null 2>&1
}
clean() { grep -viE '^(SET|INSERT|UPDATE|DO|ALTER|Output format)' | grep -v '^$' | grep -v '^(dddd'; }

echo "· a fresh database from schema.sql"
fresh iron
psql -tAd iron -c "select (select count(*) from bounties)||' bounties, '
  ||(select count(*) from exercises)||' exercises, '
  ||(select count(*) from raids)||' raids';"

echo "· the catch-up day"
fresh ironsc
psql -d ironsc -f "$HERE/catchup.sql" 2>&1 | clean

echo "· the control room's two totals"
fresh irondash
psql -d irondash -f "$HERE/dashboard.sql" 2>&1 | clean

echo "· the figure and the wins"
fresh ironbody
psql -d ironbody -f "$HERE/body.sql" 2>&1 | clean

echo "· the bounty system"
psql -d iron -f "$HERE/bounties.sql" 2>&1 | clean

echo "· the migrations, onto a database that looks like the live one"
fresh ironlive
psql -q -d ironlive -f "$HERE/rewind.sql" >/dev/null 2>&1
# somebody mid-week, which is the case that cost a real person 40 points:
# changing the rotation under a week being played changes what the week was
# for, and bounty points are worked out on read rather than stored
psql -q -d ironlive -f "$HERE/midweek.sql" >/dev/null 2>&1
for i in 1 2 3; do
  psql -q -d ironlive -f "$ROOT/supabase/bounty-pool.sql"  >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/catch-up-day.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/dashboard-points.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/body-and-crowns.sql" >/dev/null 2>&1
  echo "  run $i: clean"
done
psql -tAd ironlive -c "select 'leagues now hold '||max(max_members)||' people'
  ||case when max(max_members) % 2 = 0 then ', which is even so the Monday rivalry pairs everybody'
         else ' — ODD, SOMEBODY WILL HAVE NO RIVAL' end from leagues;"
psql -tAd ironlive -c "select 'and none has a catch-up day until somebody sets one: '
  ||(select count(*) from leagues where catchup_dow is not null)::text;"
psql -tAd ironlive -c "select 'the week in progress kept its quest: '
  ||coalesce((select b.name from bounty_schedule s join bounties b on b.idx = s.bounty_idx
              where s.week_start = current_week_start()), 'nothing was being played');"
psql -tAd ironlive -c "select count(*)||' bounties after three runs' from bounties;"
psql -tAd ironlive -c "select 'the figure has '||count(*)||' regions and '
  ||(select count(*) from exercises where muscles <> '{}'::jsonb)||' exercises feeding it'
  from muscles;"
psql -tAd ironlive -c "select 'a plank minute is now worth '
  ||(modes->'minutes'->>'rate')||' points' from exercises where key = 'plank';"
echo "· all clear"
