#!/usr/bin/env bash
# Event stream for the board run: emits one line per actionable change, nothing otherwise.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
KICK="$HOME/agents/logs/board-run-2026-09-12.log"; ROUTER="$HOME/agents/logs/multica-router.log"
STATE="$HOME/agents/logs/.board-watch-state"; mkdir -p "$STATE"
touch "$KICK"; kick_n=$(wc -l < "$KICK"); router_n=$(wc -l < "$ROUTER" 2>/dev/null || echo 0)
prs=$(gh pr list --state open --json number --jq '.[].number' 2>/dev/null | sort | paste -sd, -)
fired=0
while true; do
  now=$(date +%H:%M)
  # kickoff log
  n=$(wc -l < "$KICK"); [ "$n" -gt "$kick_n" ] && tail -n +$((kick_n+1)) "$KICK" | sed 's/^/KICKOFF /'; kick_n=$n
  # kickoff sanity: by 03:12 the log must have moved
  if [ "$fired" = 0 ] && [[ "$now" > "03:11" ]] && [[ "$now" < "23:00" ]]; then fired=1; grep -q "kickoff done" "$KICK" || echo "ALERT kickoff did not run by 03:12 — run board-run-3am.sh by hand"; fi
  # router
  m=$(wc -l < "$ROUTER" 2>/dev/null || echo 0); [ "$m" -gt "$router_n" ] && tail -n +$((router_n+1)) "$ROUTER" | sed 's/^/ROUTER /'; router_n=$m
  # issues: emit terminal/transition events not seen before
  for k in AMBR-5 AMBR-33 AMBR-2 AMBR-23 AMBR-21 AMBR-30 AMBR-12 AMBR-13; do
    multica issue timeline "$k" 2>/dev/null | awk 'NR>1' | grep -E "task_failed|task_completed|status_changed|assignee_changed|squad_leader_evaluated" | tail -6 | while IFS= read -r line; do
      key=$(echo "$line" | md5 -q 2>/dev/null || echo "$line" | md5sum | cut -c1-32)
      [ -f "$STATE/$key" ] && continue; touch "$STATE/$key"
      # only surface the interesting kinds
      case "$line" in *task_failed*|*status_changed*|*"→ member:everettyan"*|*"→ squad:"*) echo "$k $(echo "$line" | cut -c12-16) $(echo "$line" | awk '{print $2, $3}') $(echo "$line" | cut -c60-150)";; esac
    done
    # a failure comment (credits, blocked, cancelled) is worth its text
    multica issue comment list "$k" --output json --compact --since "$(date -u -v-2M +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); cs=d if isinstance(d,list) else d.get('comments',[])
    for c in cs:
        t=(c.get('content') or '')
        if any(w in t[:200] for w in ('out of usage credits','cancelled by server','Blocked by','VERDICT','HANDOFF')): print('$k COMMENT', t[:160].replace('\n',' '))
except Exception: pass"
  done
  # new PRs
  cur=$(gh pr list --state open --json number --jq '.[].number' 2>/dev/null | sort | paste -sd, -); [ "$cur" != "$prs" ] && echo "PRS open set changed: $prs -> $cur"; prs=$cur
  # memory
  free=$(memory_pressure 2>/dev/null | awk '/free percentage/{print $NF}' | tr -d '%'); [ -n "$free" ] && [ "$free" -lt 12 ] && echo "MEMORY free ${free}% — daemon cap 6 may be too high"
  sleep 60
done
