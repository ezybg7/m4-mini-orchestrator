#!/usr/bin/env bash
# Read-only pre-checks on production before the 0066-0069 applies. Never prints the URL.
set -uo pipefail; export PATH=/opt/homebrew/bin:$PATH
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: URL is a pooler endpoint"; exit 2;; esac
psql "$P" -X -At <<'SQL'
select 'db=' || current_database() || ' user=' || current_user;
select 'recipe_comments exists: ' || (to_regclass('public.recipe_comments') is not null)::text;
select 'user_follows exists: ' || (to_regclass('public.user_follows') is not null)::text;
select 'recipes.comments_enabled exists: ' || exists(select 1 from information_schema.columns where table_schema='public' and table_name='recipes' and column_name='comments_enabled')::text;
select 'profiles.comments_default exists: ' || exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='comments_default')::text;
select 'food_category frozen label: ' || exists(select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='food_category' and e.enumlabel='frozen')::text;
select 'catalog_items: ' || count(*) || ' rows, usda=' || count(*) filter (where nutrition_source='usda') || ', nutrition null=' || count(*) filter (where nutrition is null) from public.catalog_items;
select 'recipes: ' || count(*) || ', profiles: ' || (select count(*) from public.profiles) from public.recipes;
select 'email_sends (0065) exists: ' || (to_regclass('app_auth.email_sends') is not null)::text;
SQL
