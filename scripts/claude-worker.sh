#!/bin/bash
# Processes queued task files with claude -p, one at a time.
# Task file header lines (each optional, at the top, in this order):
#   RESUME:<session_id>   — continue that Claude session (must be line 1)
#   MODEL:<model>         — e.g. fable, opus (default: user's saved default)
#   EFFORT:<level>        — max for thinking-heavy tasks, high for regular
# Everything after the headers is the prompt.
# Finished tasks move to $QUEUE/done/ or $QUEUE/failed/ — never renamed in
# place, because done-*.task in the queue root matches the *.task glob and
# re-runs forever (test -> done-test -> done-done-test -> ...).
set -euo pipefail
# Single-instance lock. Lives OUTSIDE ~/agents/queue so lock churn never
# retriggers the launchd WatchPaths watcher on the queue directory.
LOCKDIR="$HOME/agents/.worker.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "claude-worker: another instance holds the lock; exiting"
  exit 0
fi
trap 'rmdir "$LOCKDIR"' EXIT
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.claude/oauth_token)"
QUEUE=~/agents/queue
LOGS=~/agents/logs
mkdir -p "$QUEUE/done" "$QUEUE/failed"
shopt -s nullglob
tasks=("$QUEUE"/*.task)
if [ ${#tasks[@]} -eq 0 ]; then
  echo "claude-worker: no .task files in $QUEUE (files must end in .task)"
  exit 0
fi
for f in "${tasks[@]}"; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .task)
  case "$name" in
    done-*)
      mv "$f" "$QUEUE/done/"
      echo "claude-worker: archived stale done marker $name (pre-fix leftover, not re-run)"
      continue ;;
    failed-*)
      mv "$f" "$QUEUE/failed/"
      echo "claude-worker: archived stale failed marker $name (pre-fix leftover, not re-run)"
      continue ;;
  esac
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
  PREAMBLE="$QUEUE/.preamble.md"
  if [ -f "$PREAMBLE" ]; then
    content="$(cat "$PREAMBLE")"$'\n\n'"$content"
  fi
  cmd=(claude -p "$content" --output-format json)
  [ -n "$sid" ] && cmd+=(--resume "$sid")
  [ -n "$model" ] && cmd+=(--model "$model")
  [ -n "$effort" ] && cmd+=(--effort "$effort")
  ok=0; "${cmd[@]}" > "$out" 2>&1 && ok=1
  if [ "$ok" = 1 ]; then
    mv "$f" "$QUEUE/done/$name.task"
    echo "claude-worker: done ($name) → $out"
  else
    mv "$f" "$QUEUE/failed/$name.task"
    echo "claude-worker: FAILED ($name) — details in $out"
  fi
  # Push the outcome straight to Discord. `hermes send` reuses the gateway's
  # bot token with no LLM and no agent loop, so notifications can't be lost to
  # relay rate limits or forgotten by the orchestrator. Never fatal.
  notify_target="${WORKER_NOTIFY_TARGET:-discord:#reports}"
  python3 - "$out" "$name" "$ok" > "$LOGS/.notify-body" 2>/dev/null <<'PY' || true
import json, re, sys
path, name, ok = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
try:
    d = json.load(open(path))
except Exception:
    d = {}
result = (d.get("result") or "").strip()
sid = d.get("session_id") or ""
mins = round((d.get("duration_ms") or 0) / 60000, 1)
cost = d.get("total_cost_usd")
head = f"{'✅' if ok else '❌'} Task **{name}** {'finished' if ok else 'FAILED'}"
meta = [f"{mins} min"] + ([f"${cost:.2f}"] if isinstance(cost, (int, float)) else [])
lines = [head + f"  ({' · '.join(meta)})"]
pr = re.search(r"^PR: (\S+)", result, re.M)
if pr:
    lines.append(f"PR: {pr.group(1)}")
body = result[-900:].strip()
if body:
    lines.append("```\n" + (("…" + body) if len(result) > 900 else body) + "\n```")
if sid:
    lines.append(f"session_id: `{sid}`  (reply to continue this task)")
print("\n".join(lines)[:1900])
PY
  if [ -s "$LOGS/.notify-body" ]; then
    hermes send --to "$notify_target" --quiet --file "$LOGS/.notify-body" \
      || echo "claude-worker: notify failed (task result is still in $out)"
  fi
done
