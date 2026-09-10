#!/bin/bash
# Processes queued task files with claude -p, one at a time.
# Task file header lines (each optional, at the top, in this order):
#   RESUME:<session_id>   — continue that Claude session (must be line 1)
#   MODEL:<model>         — e.g. fable, opus (default: user's saved default)
#   EFFORT:<level>        — max for thinking-heavy tasks, high for regular
# Everything after the headers is the prompt.
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
  echo "claude-worker: processing $name ..."
  content=$(cat "$f")
  sid=""; model=""; effort=""
  while :; do
    line=${content%%$'\n'*}
    case "$line" in
      RESUME:*) [ -n "$sid" ] && break; sid=$(echo "${line#RESUME:}" | tr -d ' ') ;;
      MODEL:*)  model=$(echo "${line#MODEL:}" | tr -d ' ') ;;
      EFFORT:*) effort=$(echo "${line#EFFORT:}" | tr -d ' ') ;;
      *) break ;;
    esac
    case "$content" in
      *$'\n'*) content=${content#*$'\n'} ;;
      *) content=""; break ;;
    esac
  done
  cmd=(claude -p "$content" --output-format json)
  [ -n "$sid" ] && cmd+=(--resume "$sid")
  [ -n "$model" ] && cmd+=(--model "$model")
  [ -n "$effort" ] && cmd+=(--effort "$effort")
  ok=0; "${cmd[@]}" > "$out" 2>&1 && ok=1
  if [ "$ok" = 1 ]; then
    mv "$f" "$QUEUE/done-$name.task"
    echo "claude-worker: done ($name) → $out"
  else
    mv "$f" "$QUEUE/failed-$name.task"
    echo "claude-worker: FAILED ($name) — details in $out"
  fi
done
