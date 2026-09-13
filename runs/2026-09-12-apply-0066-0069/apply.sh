#!/usr/bin/env bash
# Apply the pending block 0066 -> 0067 -> 0068 -> 0069 to PRODUCTION, on Everett's word
# ("apply to production all four", handoff page decision 1, 2026-09-12 14:15 UTC).
# One file at a time, ON_ERROR_STOP, the assert suite after each; stops at the first failure
# and prints that step's full output. Files come from the PR head SHAs the review squad approved.
# Never prints the URL.
# Usage: apply.sh <sha-#219> <sha-#220> <sha-#225> [--from NNNN]   (--from skips migrations below NNNN)
set -uo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
REPO=~/code/pantry
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: URL is a pooler endpoint"; exit 2;; esac
S219=$1; S220=$2; S225=$3; FROM=0066
[ "${4:-}" = "--from" ] && FROM=$5
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
x(){ local pfx=a_; case "$2" in supabase/migrations/*) pfx=m_;; esac; git -C "$REPO" show "$1:$2" > "$W/${pfx}$(basename "$2")" || { echo "MISSING $1:$2"; exit 2; }; }
x "$S219" supabase/migrations/0066_recipe_comments.sql;        x "$S219" db/asserts/0066_recipe_comments.sql
x "$S220" supabase/migrations/0067_user_follows.sql;           x "$S220" db/asserts/0067_user_follows.sql
x "$S220" supabase/migrations/0068_user_follows_hardening.sql; x "$S220" db/asserts/0068_user_follows_hardening.sql
x "$S225" supabase/migrations/0069_frozen_category.sql;        x "$S225" db/asserts/0069_frozen_category.sql
echo "target: $(psql "$P" -X -Atc 'select current_database() || '"'"' as '"'"' || current_user')  (from $FROM)"
step(){ echo; echo "== $(date +%H:%M:%S) $1"; }
run_assert(){ # name file
  step "assert $1"
  psql "$P" -X -At -f "$W/a_$2" > "$W/out" 2>&1
  local v; v=$(grep -E 'ASSERTIONS PASSED|FAIL' "$W/out" | tail -1); echo "${v:-<no verdict line>}"
  case "$v" in *"ASSERTIONS PASSED"*) ;; *) echo "-- full output of the suite:"; grep -v -E '^(NOTICE|INSERT 0 1|CREATE FUNCTION|BEGIN|SET)$' "$W/out" | tail -30; echo "ASSERT DID NOT PASS — stopping"; exit 1;; esac
}
apply(){ # name file [-1]
  local name=$1 file=$2 one=${3:-}
  [ "$name" \< "$FROM" ] && { echo; echo "== skip $name (already applied)"; return 0; }
  step "apply $name"
  if psql "$P" -X -v ON_ERROR_STOP=1 $one -q -f "$W/m_$file" 2>"$W/err"; then echo "applied"; else echo "APPLY FAILED:"; cat "$W/err"; exit 1; fi
  run_assert "$name" "$file"
}
apply 0066 0066_recipe_comments.sql -1
apply 0067 0067_user_follows.sql -1
apply 0068 0068_user_follows_hardening.sql -1
apply 0069 0069_frozen_category.sql
step "post-apply shape"
psql "$P" -X -At <<'SQL'
select 'recipe_comments: ' || (to_regclass('public.recipe_comments') is not null)::text || ' · user_follows: ' || (to_regclass('public.user_follows') is not null)::text || ' · frozen label: ' || exists(select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='food_category' and e.enumlabel='frozen')::text;
select 'catalog_items unchanged: ' || count(*) || ' rows, frozen=' || count(*) filter (where category = 'frozen') from public.catalog_items;
SQL
echo; echo "== ALL FOUR APPLIED"
