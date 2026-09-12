#!/usr/bin/env bash
# Re-dump production's schema (no rows) into the rehearsal project's `base` database.
# Run after EVERY production apply — base goes stale the moment a migration lands.
set -euo pipefail
P=$(cat ~/agents/.neon_production_url); R=$(cat ~/agents/.neon_rehearsal_url)
pg_dump "$P" --schema-only --no-owner -f ~/prod-schema.sql
psql "$R" -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='base'" >/dev/null 2>&1 || true
psql "$R" -c "drop database if exists base" >/dev/null
psql "$R" -v ON_ERROR_STOP=1 -c "create database base" >/dev/null
B=$(python3 ~/agents/scripts/neon-rehearsal-url.py base)
psql "$B" -q -f ~/prod-schema.sql >/tmp/base-reload.log 2>&1 || true
psql "$R" -c "alter database base with allow_connections false" >/dev/null
echo "base refreshed: $(grep -c '^CREATE TABLE' ~/prod-schema.sql) tables, latest migration files on main: $(ls ~/code/pantry/supabase/migrations | tail -1), load errors: $(grep -c ERROR /tmp/base-reload.log) (2 expected: cloud_admin default privileges)"
