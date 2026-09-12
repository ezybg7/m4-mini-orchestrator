#!/usr/bin/env bash
# Wave 1 of the overnight run. Waits until 03:00:30 local, then promotes five cards.
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
LOG=~/agents/multica/runs/kickoff-2026-09-12.log; P=~/agents/multica/promote.sh
say(){ echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
target=$(date -j -f "%Y-%m-%d %H:%M:%S" "2026-09-12 03:00:30" +%s); now=$(date +%s)
[ "$now" -lt "$target" ] && { say "waiting $((target-now))s for 03:00:30"; sleep $((target-now)); }
say "=== WAVE 1 ==="
$P AMBR-2  code                    | tee -a "$LOG"     # router → codex-implementer
$P AMBR-5  todo  claude-planner    | tee -a "$LOG"     # Fable: the untested planning half
$P AMBR-21 todo  claude-planner    | tee -a "$LOG"     # Fable: CI-triage spec (planner max 2)
$P AMBR-23 todo  research          | tee -a "$LOG"     # squad: first marketing run
multica issue comment add AMBR-30 --content "[@research-lead](mention://agent/5be42585-d0be-43af-a661-2501895bc20f) — your ruling at 17:35 is the deliverable; please open the PR adding docs/research/agent-orchestration.md with it (Answer / Findings / Disputed / Unverified / What this changes), on branch research/agent-orchestration, then set this issue to done. No new research." >/dev/null && say "AMBR-30: lead asked to file the PR"
say "wave 1 dispatched; monitor with: multica issue list | awk '/AMBR-(2|5|21|23|30) /'"
