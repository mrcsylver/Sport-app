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
clean() { grep -viE '^(SET|INSERT|DO|ALTER|Output format)' | grep -v '^$' | grep -v '^(dddd'; }

echo "· a fresh database from schema.sql"
fresh iron
psql -tAd iron -c "select (select count(*) from bounties)||' bounties, '
  ||(select count(*) from exercises)||' exercises, '
  ||(select count(*) from raids)||' raids';"

echo "· how a league scores"
fresh ironsc
psql -d ironsc -f "$HERE/scoring.sql" 2>&1 | clean

echo "· the bounty system"
psql -d iron -f "$HERE/bounties.sql" 2>&1 | clean

echo "· the migrations, onto a database that looks like the live one"
fresh ironlive
psql -q -d ironlive -f "$HERE/rewind.sql" >/dev/null 2>&1
for i in 1 2 3; do
  psql -q -d ironlive -f "$ROOT/supabase/bounty-pool.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/scoring-modes.sql" >/dev/null 2>&1
  echo "  run $i: clean"
done
psql -tAd ironlive -c "select 'every league still scores '
  ||coalesce((select distinct scoring from leagues), 'hardcore (none yet)');"
psql -tAd ironlive -c "select count(*)||' bounties after three runs' from bounties;"
echo "· all clear"
