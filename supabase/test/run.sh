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
clean() { grep -viE '^(SET|INSERT|UPDATE|DELETE|DO|ALTER|CREATE|Output format)' | grep -v '^$' | grep -v '^(dddd'; }

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

echo "· the season table"
fresh ironseason
psql -d ironseason -f "$HERE/season.sql" 2>&1 | clean

echo "· leaving and being removed"
fresh ironmem
psql -d ironmem -f "$HERE/membership.sql" 2>&1 | clean

echo "· the cup"
fresh ironcup2
psql -d ironcup2 -f "$HERE/cup.sql" 2>&1 | clean

echo "· the skill ladders"
fresh ironprog
psql -d ironprog -f "$HERE/progressions.sql" 2>&1 | clean

echo "· the gym formula"
fresh irongym
psql -d irongym -f "$HERE/gym.sql" 2>&1 | clean

echo "· the repetition discount"
fresh ironcap
psql -d ironcap -f "$HERE/cap.sql" 2>&1 | clean

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
  psql -q -d ironlive -f "$ROOT/supabase/repetition-cap.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/gym-lifts.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/progressions.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/season-table.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/season-stats.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/cup.sql" >/dev/null 2>&1
  psql -q -d ironlive -f "$ROOT/supabase/membership.sql" >/dev/null 2>&1
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
psql -tAd ironlive -c "select 'one movement pays in full up to '||cap||' points a week, '
  ||'and '||(select cap from exercises where key='run')||' for a run'
  from exercises where key = 'pushups';"
psql -tAd ironlive -c "select case when tier_points(600) = 350
  then 'and the repetition discount survived the migration'
  else 'THE DISCOUNT DID NOT SURVIVE' end;"
psql -tAd ironlive -c "select 'the gym holds '||count(*)||' lifts' from exercises where cat='GYM';"
psql -tAd ironlive -c "select case
  when calc_points('gymdip','reps',1,70,20) > calc_points('gymdip','reps',1,70,0)
  then 'and a weighted dip is finally worth more than a plain one'
  else 'THE BELT LIFTS ARE STILL INVERTED' end;"
psql -tAd ironlive -c "select case when rank_points(1) = 5.00 and rank_points(20) = 0.10
  then 'a weekly place is worth season points, 5.00 down to 0.10'
  else 'THE SEASON TABLE DID NOT SURVIVE' end;"
psql -tAd ironlive -c "select case when (select count(*) from pg_constraint
    where conname = 'leagues_season_sane'
      and pg_get_constraintdef(oid) like '%52%') = 1
  then 'and a 38 or 50 week season fits where 26 was the ceiling'
  else 'THE SEASON LENGTH IS STILL CAPPED AT 26' end;"
# The stats tab's season range. A defaulted third parameter is only safe if the
# two-argument version has stopped being visible: PostgREST resolves by argument
# name, so two overloads that both take p_league and p_all are ambiguous and an
# app that has not updated gets an error instead of the old answer.
psql -tAd ironlive -c "select case when count(*) = 1
  then 'exactly one my_stats is callable, so an old app is not ambiguous'
  else 'MY_STATS IS AMBIGUOUS — '||count(*)||' OVERLOADS IN public' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'my_stats';"
psql -tAd ironlive -c "select case when count(*) = 1
  then 'and exactly one my_muscles'
  else 'MY_MUSCLES IS AMBIGUOUS — '||count(*)||' OVERLOADS IN public' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'my_muscles';"
psql -tAd ironlive -c "select case when count(*) >= 2
  then 'the old shapes are parked in retired, recoverable with one ALTER'
  else 'THE OLD SHAPES WERE NOT PARKED — '||count(*)||' IN retired' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'retired'
    and (p.proname like 'my\\_stats%' or p.proname like 'my\\_muscles%');"
psql -tAd ironlive -c "select case when has_schema_privilege('authenticated', 'retired', 'usage')
  then 'BUT retired IS REACHABLE BY AN APP'
  else 'and nothing an app signs in as can reach that schema' end;"
psql -tAd ironlive -c "set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  select case when (select count(*) from my_stats(
      p_league => (select id from leagues order by created_at limit 1),
      p_all => true)) >= 0
  then 'a two-argument call by name still answers'
  else 'AN OLD APP WOULD BREAK ON THE STATS TAB' end;"
psql -tAd ironlive -c "select case when public.cup_field(18) = 16
    and (public.cup_seed_order(16))[2] = 16
  then 'and the cup survived the migration: top 16, bottom seed drawn first'
  else 'THE CUP DID NOT SURVIVE' end;"
psql -tAd ironlive -c "select case when (select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('drop_membership','admin_memberships','admin_remove_member')) = 3
  then 'and somebody can leave a league, or be taken out of one, without losing an account'
  else 'THE MEMBERSHIP TOOLS DID NOT SURVIVE' end;"
echo "· all clear"
