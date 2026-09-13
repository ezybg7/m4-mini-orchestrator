#!/usr/bin/env bash
# One-shot kickoff for the 2026-09-12 board run. Runs from cron at 03:05, after Fable's 03:00 reset.
# Promotes the first batch by COLUMN (the router assigns); the queue and its reasoning are in
# ~/agents/multica/board-run-2026-09-12.md. Idempotent: every step checks before acting.
set -uo pipefail
export PATH="/usr/local/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"
LOG="$HOME/agents/logs/board-run-2026-09-12.log"; say(){ echo "$(date '+%F %T') $*" >> "$LOG"; }
say "=== kickoff ==="
status(){ multica issue get "$1" --output json 2>/dev/null | python3 -c "import json,sys;i=json.load(sys.stdin);i=i.get('issue',i);print(i['status'])"; }

# 0. AMBR-30's research record: merge the docs PR, close the issue.
cd "$HOME/code/pantry" && git fetch -q origin
if [ "$(gh pr view 221 --json state --jq .state 2>/dev/null)" = "OPEN" ]; then
  if gh pr checks 221 2>/dev/null | grep -qE "fail|pending"; then say "#221 checks not clean — left open"; else
    gh pr merge 221 --squash --delete-branch >/dev/null 2>&1 && say "merged #221 (research doc)" || say "#221 merge FAILED"; fi
fi
[ "$(status AMBR-30)" != "done" ] && multica issue status AMBR-30 done --no-start >/dev/null 2>&1 && say "AMBR-30 → done"

# 1. AMBR-5: the planner. Its last task failed on credits; re-assignment is the only way to start it.
if [ "$(status AMBR-5)" = "todo" ]; then
  multica issue assign AMBR-5 --unassign >/dev/null 2>&1; sleep 2
  multica issue assign AMBR-5 --to claude-planner >/dev/null 2>&1 && say "AMBR-5 → claude-planner (Fable, first real run)"
fi

# 2–3. Implementer work that needs no spec: Backlog/Blocked → Code (the router assigns the implementer).
# AMBR-33 sits in backlog assigned to the implementer: leaving backlog starts it (Multica's own trigger).
# AMBR-2 sits in BLOCKED assigned to the implementer: leaving blocked triggers nothing natively, and the
# router sees the same assignee — so clear the assignee first and let the router assign on the next tick.
s=$(status AMBR-33); case "$s" in backlog) multica issue status AMBR-33 code >/dev/null 2>&1 && say "AMBR-33 backlog → code";; *) say "AMBR-33 already $s";; esac
s=$(status AMBR-2); case "$s" in blocked)
  multica issue assign AMBR-2 --unassign >/dev/null 2>&1
  multica issue status AMBR-2 code --no-start >/dev/null 2>&1 && say "AMBR-2 blocked → code, unassigned (router assigns the implementer)";; *) say "AMBR-2 already $s";; esac

# 4. Marketing research: assign the squad (its issue is in backlog; assignment in backlog does not run — promote too).
if [ "$(status AMBR-23)" = "backlog" ]; then
  multica issue status AMBR-23 in_progress --no-start >/dev/null 2>&1   # a non-pipeline column: the router leaves squad-owned issues alone
  # The squad was already the assignee, and re-assigning the same actor is a no-op: clear it first.
  multica issue assign AMBR-23 --unassign >/dev/null 2>&1; sleep 2
  multica issue assign AMBR-23 --to research >/dev/null 2>&1 && say "AMBR-23 → research squad (re-assigned, so the leader actually starts)"
fi
say "=== kickoff done; AMBR-21 waits until AMBR-5's spec PR is up (orchestrator promotes it) ==="
