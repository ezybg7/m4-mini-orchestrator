#!/usr/bin/env bash
# 0070 claim_ai_call pools (AMBR-57, PR #256) — REAL apply on PRODUCTION.
# Run dryrun.sh first and read "DRY RUN OK". Order (spec 23 §Migrations 0070 §Order): PR #255 merged
# (54436cf8, done) AND the Worker DEPLOYED before this runs. Applies the migration in one transaction,
# runs the assert file (self-rolls-back, leaves no rows), then the one thing the asserts cannot show
# on a rowless copy: the live function and check constraint now carry meal_plan and the per-kind pools.
# Never prints the URL.   Usage: apply.sh [sha]   (default: the tip of origin/feat/wave-a2-claim-ai-call-pools)
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
S=$(shasum -a 256 "$W/m.sql" | cut -c1-16); [ "$S" = "$REVIEWED" ] || { echo "REFUSING: migration sha256 $S… differs from the reviewed $REVIEWED…"; exit 2; }
echo "target: $(psql "$P" -X -Atc 'select current_database() || '"'"' as '"'"' || current_user')  (REAL APPLY)"
echo "file: ${SHA:0:8}:supabase/migrations/0070_claim_ai_call_pools.sql  sha256 $S…"
echo
psql "$P" -X -v ON_ERROR_STOP=1 -1 -f "$W/m.sql" 2>&1 | grep -v -E '^(SET|BEGIN)$' | tee "$W/out"; rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] || { echo "== APPLY FAILED (psql exit $rc) — the single transaction rolled back; paste this output on AMBR-57"; exit 1; }
echo "== asserts (behavioural, self-rolling-back):"; A=$(psql "$P" -X -At -f "$W/a.sql" 2>&1 | grep -E 'ASSERTIONS|FAILED' | tail -1); echo "   $A"
echo "== live function and constraint:"; psql "$P" -X -At -c "select 'claim_ai_call mentions meal_plan: ' || (position('meal_plan' in pg_get_functiondef('public.claim_ai_call(uuid,text,integer,integer,integer)'::regprocedure)) > 0)::text" -c "select 'ai_calls_kind_check has meal_plan: ' || (pg_get_constraintdef(oid) like '%meal_plan%')::text from pg_constraint where conname='ai_calls_kind_check'"
if [ "$A" = "ALL 16 ASSERTIONS PASSED" ]; then echo "== 0070 APPLIED — say \"0070 applied\"; the orchestrator merges #256, records the ledger and refreshes the rehearsal base"; else echo "== APPLIED BUT THE ASSERTS DID NOT PASS — paste this output on AMBR-57 before anything else runs"; exit 1; fi
