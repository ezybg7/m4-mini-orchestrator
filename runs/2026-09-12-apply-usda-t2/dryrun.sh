#!/usr/bin/env bash
# USDA nutrition tranche 2 (AMBR-34, PR #231, head b8543645) — ROLLED-BACK dry run on PRODUCTION.
# Runs the approved file with its final `commit;` replaced by `rollback;`, so nothing persists;
# prints the before/after count rows and every UPDATE line so the deltas (+9 usda, −9 null) and
# the ten UPDATE 1 lines can be read before the real apply. Never prints the URL.
# Usage: dryrun.sh [sha]   (default: the reviewed head b8543645b83479aeaf53a38d2adf5ff0e583011e)
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
sed -E 's/^commit;$/rollback;/' "$W/t2.sql" > "$W/t2-dry.sql"
grep -q -E '^rollback;$' "$W/t2-dry.sql" || { echo "REFUSING: rollback substitution failed"; exit 2; }
echo "target: $(psql "$P" -X -Atc 'select current_database() || '"'"' as '"'"' || current_user')  (DRY RUN — rolls back)"
echo "file: $SHA:db/apply/usda-nutrition-backfill-2.sql  sha256 $(shasum -a 256 "$W/t2.sql" | cut -c1-16)…  statements: $(grep -c '^update catalog_items' "$W/t2.sql")"
echo
psql "$P" -X -v ON_ERROR_STOP=1 -f "$W/t2-dry.sql" 2>&1 | grep -v -E '^(SET|BEGIN)$' | tee "$W/out"
echo
b=$(awk -F'|' '$1=="before"{print $2" "$3}' "$W/out"); a=$(awk -F'|' '$1=="after"{print $2" "$3}' "$W/out")
if [ -z "$b" ] || [ -z "$a" ]; then
  # psql prints aligned tables by default; parse those too
  b=$(grep -E '^\s*before' "$W/out" | awk -F'|' '{gsub(/ /,"",$2); gsub(/ /,"",$3); print $2" "$3}')
  a=$(grep -E '^\s*after'  "$W/out" | awk -F'|' '{gsub(/ /,"",$2); gsub(/ /,"",$3); print $2" "$3}')
fi
set -- $b; bu=${1:-?}; bn=${2:-?}; set -- $a; au=${1:-?}; an=${2:-?}
u=$(grep -c '^UPDATE 1$' "$W/out"); z=$(grep -c '^UPDATE 0$' "$W/out")
echo "== counts: usda $bu → $au (Δ $((au-bu)))   null $bn → $an (Δ $((an-bn)))   UPDATE 1 ×$u   UPDATE 0 ×$z"
if [ "$((au-bu))" = 9 ] && [ "$((an-bn))" = -9 ] && [ "$u" = 10 ] && [ "$z" = 0 ]; then echo "== DRY RUN MATCHES EXPECTATION (+9 usda, −9 null, ten UPDATE 1) — rolled back, nothing persisted"; else echo "== DRY RUN DOES NOT MATCH (+9/−9/10×UPDATE 1 expected) — do not apply; paste this output on AMBR-34"; exit 1; fi
