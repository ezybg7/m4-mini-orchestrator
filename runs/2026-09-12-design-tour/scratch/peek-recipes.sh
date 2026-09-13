#!/bin/zsh
set -u
source "$HOME/agents/runs/2026-09-12-design-tour/env.sh"
DSN=$(printf '%s' "$NEON_DIRECT_URL" | sed -E "s#@[^/]+/#@${BRANCH_DIRECT_HOST}/#")
psql "$DSN" -X -At -F ' | ' <<'SQL'
select 'r', title, visibility, jsonb_array_length(coalesce(steps,'[]'::jsonb)) as nsteps, time_minutes, difficulty from recipes order by created_at;
select 'ing', r.title, count(i.*) from recipes r left join recipe_ingredients i on i.recipe_id=r.id group by r.title;
select 'folders', name from recipe_folders;
select 'folder_items', count(*) from recipe_folder_items;
select 'zones', z.name, l.name from zones z join storage_locations l on l.id=z.location_id;
select 'groc', name, status from grocery_items where household_id='e99fb3f2-a791-4cac-a9eb-5141098d322f';
select 'outcomes_month', count(*) from food_outcomes where date_trunc('month', created_at)=date_trunc('month', now());
SQL
