#!/usr/bin/env bash
# 0070 (AMBR-57, PR #256) — the orchestrator's rehearsal of the pending block on a FRESH copy of `base`
# in the rehearsal project (spec 61 §5, neon-rehearsal skill): terminate base sessions, create db,
# migration in one transaction, assert file (expects ALL 16 ASSERTIONS PASSED), main's grants replay,
# asserts again, the dry-run shape, drop. Never prints the URL; the rehearsal project's pooler URL is
# the one the skill says to use as-is.
set -uo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
D=$(cd "$(dirname "$0")" && pwd); REPO=~/code/pantry
U=$(cat ~/agents/.neon_rehearsal_url)
DB="rehearse_ambr_57_$(date +%s)"
psql "$U" -X -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='base'" >/dev/null
psql "$U" -X -v ON_ERROR_STOP=1 -Atc "create database $DB template base" >/dev/null || { echo "create failed"; exit 1; }
C=$(python3 ~/agents/scripts/neon-rehearsal-url.py "$DB") || { psql "$U" -X -c "drop database if exists $DB" >/dev/null; exit 2; }
echo "copy: $(psql "$C" -X -Atc 'select current_database()')"
echo "== 1. migration (one transaction)"; psql "$C" -X -v ON_ERROR_STOP=1 -1 -f "$D/0070_claim_ai_call_pools.sql" 2>&1 | grep -v -E '^(SET|BEGIN|COMMIT)$' | tail -3
echo "== 2. assert file"; A1=$(psql "$C" -X -At -f "$D/0027_ai_quota.sql" 2>&1 | grep -E 'ASSERTIONS|FAILED' | tail -1); echo "$A1"
echo "== 3. grants replay (main's db/neon-grants.sql)"; git -C "$REPO" show origin/main:db/neon-grants.sql > /tmp/grants-$$.sql; psql "$C" -X -v ON_ERROR_STOP=1 -f /tmp/grants-$$.sql 2>&1 | grep -c -E '^(GRANT|REVOKE)' | sed 's/^/grant+revoke statements ok: /'; rm -f /tmp/grants-$$.sql
echo "== 4. assert file again"; A2=$(psql "$C" -X -At -f "$D/0027_ai_quota.sql" 2>&1 | grep -E 'ASSERTIONS|FAILED' | tail -1); echo "$A2"
echo "== 5. the dry-run shape (begin; migration; assert file; rollback) on the same copy"; ( printf 'begin;\n'; cat "$D/0070_claim_ai_call_pools.sql"; printf '\n'; cat "$D/0027_ai_quota.sql" ) | psql "$C" -X -v ON_ERROR_STOP=1 2>&1 | grep -E 'ASSERTIONS|FAILED|ROLLBACK|ERROR|WARNING' | tail -4
psql "$U" -X -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='$DB'" >/dev/null
psql "$U" -X -Atc "drop database if exists $DB" >/dev/null && echo "dropped $DB"
[ "$A1" = "ALL 16 ASSERTIONS PASSED" ] && [ "$A2" = "ALL 16 ASSERTIONS PASSED" ] && echo "== REHEARSAL OK: 16/16 before and after the grants replay" || { echo "== REHEARSAL NOT OK"; exit 1; }
