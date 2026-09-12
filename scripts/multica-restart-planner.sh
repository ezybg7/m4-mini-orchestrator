#!/usr/bin/env bash
# One-shot: restart the parked planner issue once Everett's Fable window resets (03:00).
# AMBR-5 failed twice on 2026-09-11 with "out of usage credits" for claude-fable-5-1 while
# Opus 5 ran fine on the same token — a plan allotment, not a token fault. Re-assigning is
# the only way to start a run for an issue whose task already failed.
# No-ops once the issue has actually run, so it is safe to leave in crontab; remove the
# crontab line when the loop is routine.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
ISSUE="${1:-AMBR-5}"
LOG="$HOME/agents/logs/multica-restart-planner.log"
say(){ echo "$(date '+%F %T') $*" >> "$LOG"; }

timeline=$(multica issue timeline "$ISSUE" 2>&1 || true)
if grep -q "task_completed" <<<"$timeline"; then
  say "$ISSUE already completed a run — nothing to do"; exit 0
fi
if ! grep -q "task_failed" <<<"$timeline"; then
  say "$ISSUE has no failed task (may be running or queued) — leaving it alone"; exit 0
fi

multica issue assign "$ISSUE" --unassign >/dev/null 2>&1 || true
if multica issue assign "$ISSUE" --to claude-planner >/dev/null 2>&1; then
  say "$ISSUE re-assigned to claude-planner"
else
  say "$ISSUE re-assign FAILED"; exit 1
fi
sleep 90
if multica issue timeline "$ISSUE" 2>&1 | tail -3 | grep -q "task_failed"; then
  say "$ISSUE failed again — credits likely still exhausted, or a different fault"
else
  say "$ISSUE is running"
fi
