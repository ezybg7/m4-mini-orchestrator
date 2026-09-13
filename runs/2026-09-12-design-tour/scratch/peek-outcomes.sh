#!/bin/zsh
set -u
source "$HOME/agents/runs/2026-09-12-design-tour/env.sh"
DSN=$(printf '%s' "$NEON_DIRECT_URL" | sed -E "s#@[^/]+/#@${BRANCH_DIRECT_HOST}/#")
psql "$DSN" -X -At -F ' | ' <<'SQL'
select 'cols', string_agg(column_name,' ') from information_schema.columns where table_schema='public' and table_name='food_outcomes';
select 'rows', outcome, count(*) from food_outcomes where household_id='e99fb3f2-a791-4cac-a9eb-5141098d322f' group by outcome;
SQL
