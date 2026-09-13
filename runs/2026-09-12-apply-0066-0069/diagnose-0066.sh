#!/usr/bin/env bash
# Re-run ONLY the 0066 assert suite against production with its full output (the suite is
# begin … rollback: it writes nothing), plus the shape 0066 should have left. Never prints the URL.
set -uo pipefail; export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: pooler endpoint"; exit 2;; esac
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C ~/code/pantry show 7ab86424d91504220b91f1d56eedfeaef14426ac:db/asserts/0066_recipe_comments.sql > "$W/a.sql"
echo "== shape after 0066"
psql "$P" -X -At <<'SQL'
select 'recipe_comments: ' || (to_regclass('public.recipe_comments') is not null)::text || ' · comment_reports: ' || (to_regclass('public.comment_reports') is not null)::text;
select 'functions: ' || string_agg(proname, ', ' order by proname) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('comments_open','my_comments_default','recipe_comments_rate_cap','delete_recipe_comment');
select 'policies on recipe_comments: ' || count(*) from pg_policies where tablename = 'recipe_comments';
select 'recipes.comments_enabled: ' || count(*) || ' · profiles.comments_default: ' || (select count(*) from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='comments_default') from information_schema.columns where table_schema='public' and table_name='recipes' and column_name='comments_enabled';
SQL
echo; echo "== 0066 assert suite, full output (stderr merged)"
psql "$P" -X -At -f "$W/a.sql" 2>&1 | grep -v -E '^(NOTICE|INSERT 0 1|CREATE FUNCTION|BEGIN|SET)$' | tail -40
echo "(exit ${PIPESTATUS[0]})"
