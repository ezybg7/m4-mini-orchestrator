#!/usr/bin/env bash
# The frozen catalog re-file on PRODUCTION (spec 59 rollout step 4), to run AFTER the Worker deploy
# that follows #225's merge. Fixture first (self-seeding, rolls back, expects ALL 8 ASSERTIONS PASSED),
# then the transactional, idempotent apply (expects UPDATE 56 on the category rows and UPDATE 1 on the alias).
# Files come from main at the sha given (default: origin/main). Never prints the URL.
set -uo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
REPO=~/code/pantry; SHA=${1:-origin/main}
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: URL is a pooler endpoint"; exit 2;; esac
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C "$REPO" fetch -q origin
mkdir -p "$W/db/apply" "$W/db/asserts"
git -C "$REPO" show "$SHA:db/apply/catalog-frozen-refile-2026-09.sql" > "$W/db/apply/catalog-frozen-refile-2026-09.sql"
git -C "$REPO" show "$SHA:db/asserts/catalog-frozen-refile-2026-09.sql" > "$W/db/asserts/catalog-frozen-refile-2026-09.sql"
echo "target: $(psql "$P" -X -Atc 'select current_database()') · before: $(psql "$P" -X -Atc "select count(*) || ' rows, frozen=' || count(*) filter (where category='frozen') from public.catalog_items")"
echo; echo "== fixture (rolls back)"
( cd "$W" && psql "$P" -X -At -f db/asserts/catalog-frozen-refile-2026-09.sql 2>&1 | grep -E 'PASSED|FAIL|ERROR' | tail -3 )
v=$( cd "$W" && psql "$P" -X -At -f db/asserts/catalog-frozen-refile-2026-09.sql 2>&1 | grep -E 'ASSERTIONS PASSED|FAIL' | tail -1 )
case "$v" in *"ALL 8 ASSERTIONS PASSED"*) ;; *) echo "fixture did not pass ($v) — stopping"; exit 1;; esac
echo; echo "== apply (one transaction)"
psql "$P" -X -v ON_ERROR_STOP=1 -1 -f "$W/db/apply/catalog-frozen-refile-2026-09.sql" 2>&1 | grep -v -E '^(BEGIN|COMMIT|SET)$'
echo; echo "== after: $(psql "$P" -X -Atc "select count(*) || ' rows, frozen=' || count(*) filter (where category='frozen') from public.catalog_items")"
echo "== RE-FILE DONE (expected: 56 frozen)"
