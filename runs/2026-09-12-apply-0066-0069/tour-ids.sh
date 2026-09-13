#!/usr/bin/env bash
# Read-only: the ids the design tour's deep links need (test household's locations, a public
# recipe, the seeded account's profile, a folder if any). Never prints the URL or any secret.
set -uo pipefail; export PATH=/opt/homebrew/bin:$PATH
P=$(cat ~/agents/.neon_production_url)
case "$P" in *pooler*) echo "REFUSING: pooler endpoint"; exit 2;; esac
psql "$P" -X -At <<'SQL'
select 'profile ' || p.id || ' ' || coalesce(p.display_name, '') from public.profiles p order by p.created_at limit 3;
select 'location ' || l.id || ' ' || l.name || ' household=' || l.household_id from public.storage_locations l order by l.created_at limit 6;
select 'recipe ' || r.id || ' ' || r.title || ' visibility=' || r.visibility from public.recipes r order by r.created_at limit 6;
select 'folder ' || f.id || ' ' || f.name from public.recipe_folders f order by f.created_at limit 3;
select 'items in test household: ' || count(*) from public.inventory_items;
select 'grocery rows: ' || count(*) from public.grocery_items;
SQL
