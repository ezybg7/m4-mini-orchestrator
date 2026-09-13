#!/bin/zsh
set -u
source "$HOME/agents/runs/2026-09-12-design-tour/env.sh"
DSN=$(printf '%s' "$NEON_DIRECT_URL" | sed -E "s#@[^/]+/#@${BRANCH_DIRECT_HOST}/#")
psql "$DSN" -X -At -F ' | ' <<'SQL'
select 'TH_inv', l.name, coalesce(i.name_override, c.name), i.status, i.expires_at::date, (i.expires_at::date - current_date) as days
  from inventory_items i left join storage_locations l on l.id=i.location_id left join catalog_items c on c.id=i.catalog_item_id
  where i.household_id='e99fb3f2-a791-4cac-a9eb-5141098d322f' order by i.expires_at nulls last limit 20;
select 'TH_inv_count', count(*) from inventory_items where household_id='e99fb3f2-a791-4cac-a9eb-5141098d322f';
select 'TH_groc', name, status from grocery_items where household_id='e99fb3f2-a791-4cac-a9eb-5141098d322f';
select 'zones', z.name, l.name from zones z join storage_locations l on l.id=z.location_id;
SQL
