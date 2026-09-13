#!/usr/bin/env bash
# USDA nutrition tranche 2 (AMBR-34, PR #231, head b8543645) — REAL apply on PRODUCTION.
# Everett's decision 2 (handoff page, 2026-09-12): option 2, the ten FNDDS matches only.
# Run dryrun.sh first and read "DRY RUN MATCHES EXPECTATION". This applies the same file
# unchanged (its own begin/commit), prints the count rows, every UPDATE line, and the Sorbet
# panel (the re-match that the deltas cannot prove). Never prints the URL.
# Usage: apply.sh [sha]   (default: the reviewed head b8543645b83479aeaf53a38d2adf5ff0e583011e)
set -uo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
REPO=~/code/pantry
SHA=${1:-b8543645b83479aeaf53a38d2adf5ff0e583011e}
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: URL is a pooler endpoint"; exit 2;; esac
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C "$REPO" fetch -q origin data/usda-tranche-2-matches-only 2>/dev/null || true
git -C "$REPO" show "$SHA:db/apply/usda-nutrition-backfill-2.sql" > "$W/t2.sql" || { echo "MISSING $SHA:db/apply/usda-nutrition-backfill-2.sql"; exit 2; }
n=$(grep -c -E '^commit;$' "$W/t2.sql"); [ "$n" = 1 ] || { echo "REFUSING: expected exactly one 'commit;' line, found $n"; exit 2; }
echo "target: $(psql "$P" -X -Atc 'select current_database() || '"'"' as '"'"' || current_user')  (REAL APPLY)"
echo "file: $SHA:db/apply/usda-nutrition-backfill-2.sql  sha256 $(shasum -a 256 "$W/t2.sql" | cut -c1-16)…  statements: $(grep -c '^update catalog_items' "$W/t2.sql")"
echo
psql "$P" -X -v ON_ERROR_STOP=1 -f "$W/t2.sql" 2>&1 | grep -v -E '^(SET|BEGIN)$' | tee "$W/out"
rc=${PIPESTATUS[0]}
echo
[ "$rc" = 0 ] || { echo "== APPLY FAILED (psql exit $rc) — the file's own transaction rolled back; paste this output on AMBR-34"; exit 1; }
b=$(grep -E '^\s*before' "$W/out" | awk -F'|' '{gsub(/ /,"",$2); gsub(/ /,"",$3); print $2" "$3}')
a=$(grep -E '^\s*after'  "$W/out" | awk -F'|' '{gsub(/ /,"",$2); gsub(/ /,"",$3); print $2" "$3}')
set -- $b; bu=${1:-?}; bn=${2:-?}; set -- $a; au=${1:-?}; an=${2:-?}
u=$(grep -c '^UPDATE 1$' "$W/out"); z=$(grep -c '^UPDATE 0$' "$W/out")
echo "== counts: usda $bu → $au (Δ $((au-bu)))   null $bn → $an (Δ $((an-bn)))   UPDATE 1 ×$u   UPDATE 0 ×$z"
echo "== Sorbet (re-match; expects source usda and kcal 110):"
psql "$P" -X -At -c "select name || ' · ' || coalesce(nutrition_source,'null') || ' · kcal ' || coalesce(nutrition->>'kcal','null') from catalog_items where id = '05a53260-f953-453e-9b69-1426508759d0'"
echo "== totals now: $(psql "$P" -X -Atc "select count(*) filter (where nutrition_source='usda') || ' usda rows · ' || count(*) filter (where nutrition is null) || ' null rows · ' || count(*) || ' catalog rows' from catalog_items")"
if [ "$((au-bu))" = 9 ] && [ "$((an-bn))" = -9 ] && [ "$u" = 10 ]; then echo "== TRANCHE 2 APPLIED — say \"tranche 2 applied\" and paste the counts line"; else echo "== APPLIED BUT COUNTS DIFFER FROM EXPECTATION — paste this output on AMBR-34 before anything else runs"; exit 1; fi
