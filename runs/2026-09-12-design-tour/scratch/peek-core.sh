#!/bin/zsh
set -u
source "$HOME/agents/runs/2026-09-12-design-tour/env.sh"
DSN=$(printf '%s' "$NEON_DIRECT_URL" | sed -E "s#@[^/]+/#@${BRANCH_DIRECT_HOST}/#")
psql "$DSN" -X -At -F ' | ' <<'SQL'
select 'recipes', id, title, visibility, owner_id from recipes order by created_at;
select 'public_count', count(*) from recipes where visibility='public';
select 'inventory', count(*) from inventory_items;
select 'inv_rows', i.name, l.name, i.status, i.expires_on from inventory_items i left join storage_locations l on l.id=i.location_id limit 12;
select 'locations', id, name, household_id from storage_locations;
select 'households', id, name from households;
select 'grocery', name, bought from grocery_items limit 10;
select 'profiles', id, display_name, bio from profiles;
SQL
