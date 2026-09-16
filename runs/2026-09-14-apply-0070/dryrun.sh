#!/usr/bin/env bash
# 0070 claim_ai_call pools (AMBR-57, PR #256) — ROLLED-BACK dry run on PRODUCTION.
# One transaction: the migration, then the behavioural assert file (its own `begin;` only warns
# inside ours; its final `rollback;` rolls the whole thing back) — so the function is exercised
# against production's real schema and NOTHING persists. Expects "ALL 16 ASSERTIONS PASSED" then
# ROLLBACK. Refuses a pooler URL, refuses a file whose sha256 differs from the reviewed one.
# Never prints the URL.   Usage: dryrun.sh [sha]   (default: the tip of origin/feat/wave-a2-claim-ai-call-pools)
set -uo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
REPO=~/code/pantry; BR=feat/wave-a2-claim-ai-call-pools; REVIEWED=f8c4357c59abf5a1
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: URL is a pooler endpoint"; exit 2;; esac
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C "$REPO" fetch -q origin "$BR" 2>/dev/null || true
SHA=${1:-$(git -C "$REPO" rev-parse "origin/$BR")}
git -C "$REPO" show "${SHA}:supabase/migrations/0070_claim_ai_call_pools.sql" > "$W/m.sql" || { echo "MISSING migration at $SHA"; exit 2; }
git -C "$REPO" show "${SHA}:db/asserts/0027_ai_quota.sql" > "$W/a.sql" || { echo "MISSING assert file at $SHA"; exit 2; }
S=$(shasum -a 256 "$W/m.sql" | cut -c1-16); [ "$S" = "$REVIEWED" ] || { echo "REFUSING: migration sha256 ${S}… differs from the reviewed ${REVIEWED}…"; exit 2; }
grep -q '^rollback;$' "$W/a.sql" || { echo "REFUSING: assert file does not end in rollback"; exit 2; }
echo "target: $(psql "$P" -X -Atc 'select current_database() || '"'"' as '"'"' || current_user')  (DRY RUN — rolls back)"
echo "file: ${SHA:0:8}:supabase/migrations/0070_claim_ai_call_pools.sql  sha256 ${S}…  asserts: $(grep -c 'ASSERTIONS PASSED' "$W/a.sql") expected string"
echo
( printf 'begin;\n'; cat "$W/m.sql"; printf '\n'; cat "$W/a.sql" ) | psql "$P" -X -v ON_ERROR_STOP=1 2>&1 | grep -v -E '^(SET|BEGIN)$' | grep -E 'ALTER|CREATE|ASSERTIONS|FAILED|ROLLBACK|ERROR|WARNING' | tee "$W/out"
echo
if grep -q '^ *ALL 16 ASSERTIONS PASSED' "$W/out" && grep -q '^ROLLBACK' "$W/out" && ! grep -q 'ERROR' "$W/out"; then echo "== DRY RUN OK: 0070 applies on production and 16/16 assertions pass — rolled back, nothing persisted"; else echo "== DRY RUN NOT OK — do not apply; paste this output on AMBR-57"; exit 1; fi
