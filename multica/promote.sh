#!/usr/bin/env bash
# promote.sh <ISSUE> <column> [actor]
# Moves a card into a pipeline column in a way that always starts a run: the router's
# "same assignee → no-op" guard (which stops hot loops) would otherwise swallow a card
# that is re-entering with its old assignee still on it. Unassign first, set the column,
# then let the router (or an explicit --to) assign.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
K="$1"; COL="$2"; TO="${3:-}"
multica issue assign "$K" --unassign >/dev/null 2>&1 || true
multica issue status "$K" "$COL" --no-start >/dev/null
if [ -n "$TO" ]; then multica issue assign "$K" --to "$TO" >/dev/null; echo "$(date +%H:%M:%S) $K → $COL, assigned $TO"
else echo "$(date +%H:%M:%S) $K → $COL (router assigns within 60 s)"; fi
