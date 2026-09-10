#!/bin/bash
# Processes queued task files with claude -p, one at a time.
# A task whose first line is "RESUME:<session_id>" continues that Claude session.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.claude/oauth_token)"
QUEUE=~/agents/queue
LOGS=~/agents/logs
shopt -s nullglob
tasks=("$QUEUE"/*.task)
if [ ${#tasks[@]} -eq 0 ]; then
  echo "claude-worker: no .task files in $QUEUE (files must end in .task)"
  exit 0
fi
for f in "${tasks[@]}"; do
  name=$(basename "$f" .task)
  out="$LOGS/claude-$name-$(date +%Y%m%d-%H%M%S).json"
  first=$(head -n1 "$f")
  echo "claude-worker: processing $name ..."
  if [[ "$first" == RESUME:* ]]; then
    sid=$(echo "${first#RESUME:}" | tr -d ' ')
    ok=0; claude -p "$(tail -n +2 "$f")" --resume "$sid" --output-format json > "$out" 2>&1 && ok=1
  else
    ok=0; claude -p "$(cat "$f")" --output-format json > "$out" 2>&1 && ok=1
  fi
  if [ "$ok" = 1 ]; then
    mv "$f" "$QUEUE/done-$name.task"
    echo "claude-worker: done ($name) → $out"
  else
    mv "$f" "$QUEUE/failed-$name.task"
    echo "claude-worker: FAILED ($name) — details in $out"
  fi
done
