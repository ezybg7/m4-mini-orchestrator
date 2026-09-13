#!/usr/bin/env bash
# Direct verification of 0066 on production WITHOUT impersonating `authenticated` (the PR's
# suite needs `grant authenticated to neondb_owner`, which Neon's managed role refuses).
# Read-only. Never prints the URL.
set -uo pipefail; export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: pooler endpoint"; exit 2;; esac
psql "$P" -X -At -v ON_ERROR_STOP=1 <<'SQL'
select 'V1 tables: ' || (to_regclass('public.recipe_comments') is not null and to_regclass('public.comment_reports') is not null)::text;
select 'V2 columns default true: ' || (select column_default from information_schema.columns where table_schema='public' and table_name='recipes' and column_name='comments_enabled') || ' / ' || (select column_default from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='comments_default');
select 'V3 RLS enabled: ' || string_agg(relname || '=' || relrowsecurity::text, ', ') from pg_class where relname in ('recipe_comments','comment_reports');
select 'V4 policies: ' || string_agg(tablename || '.' || policyname || '[' || cmd || ']', ', ' order by tablename, policyname) from pg_policies where tablename in ('recipe_comments','comment_reports');
select 'V5 select policy uses comments_open: ' || (qual like '%comments_open%')::text from pg_policies where tablename='recipe_comments' and policyname='recipe_comments_select';
select 'V6 insert policy binds author: ' || (with_check like '%author_id = auth.uid()%' and with_check like '%comments_open%')::text from pg_policies where tablename='recipe_comments' and policyname='recipe_comments_insert';
select 'V7 authenticated table grants: recipe_comments select=' || has_table_privilege('authenticated','public.recipe_comments','select')::text || ' delete=' || has_table_privilege('authenticated','public.recipe_comments','delete')::text || ' update=' || has_table_privilege('authenticated','public.recipe_comments','update')::text || ' insert(body)=' || has_column_privilege('authenticated','public.recipe_comments','body','insert')::text || ' insert(created_at)=' || has_column_privilege('authenticated','public.recipe_comments','created_at','insert')::text;
select 'V8 author switch grants: recipes.comments_enabled update=' || has_column_privilege('authenticated','public.recipes','comments_enabled','update')::text || ' insert=' || has_column_privilege('authenticated','public.recipes','comments_enabled','insert')::text || ' · profiles.comments_default select=' || has_column_privilege('authenticated','public.profiles','comments_default','select')::text || ' update(table-level)=' || has_table_privilege('authenticated','public.profiles','update')::text;
select 'V9 PUBLIC grants on the two tables: ' || count(*) from information_schema.role_table_grants where table_schema='public' and table_name in ('recipe_comments','comment_reports') and grantee='PUBLIC';
select 'V10 functions: ' || string_agg(p.proname || '(definer=' || p.prosecdef::text || ', exec_auth=' || has_function_privilege('authenticated', p.oid, 'execute')::text || ', exec_public=' || has_function_privilege('anonymous', p.oid, 'execute')::text || ')', ', ' order by p.proname) from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in ('comments_open','my_comments_default','delete_recipe_comment','recipe_comments_rate_cap');
select 'V11 rate-cap trigger: ' || tgname || ' enabled=' || (tgenabled <> 'D')::text from pg_trigger where tgrelid='public.recipe_comments'::regclass and tgname='recipe_comments_rate_cap';
select 'V12 comment_reports open-once index: ' || (indexdef like '%WHERE (status = ''open''%')::text from pg_indexes where tablename='comment_reports' and indexname='comment_reports_open_once';
select 'V13 existing rows untouched: recipes=' || count(*) || ' all comments_enabled=' || bool_and(comments_enabled)::text from public.recipes;
SQL
