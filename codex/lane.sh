#!/usr/bin/env bash
# lane.sh — run one Codex lane for pantry (Ambry). Spec 56, specs/codex-qa-lane.md
#
#   lane.sh review    <base-ref>        second-opinion review of a diff
#   lane.sh implement <task-file>       build a merged spec's §Acceptance
#   lane.sh tests     <task-file>       test-gap finding, jest only
#   lane.sh hunt      <area>            bug hunt, read-only
#   lane.sh fix       <task-file>       one confirmed finding + its anchor test
#
# Orchestrator tooling lives in ~/agents, never in the pantry repo (PR #101).
#
# WHY THE WRAPPER EXISTS: Codex's sandbox has NO NETWORK, so `npm ci` has to run
# out here before Codex starts, and lane output has to be written out here too.
set -uo pipefail

LANE_KIND="${1:-}"; ARG="${2:-}"
REPO="${REPO:-$HOME/code/pantry}"
WT_ROOT="${WT_ROOT:-$HOME/codex-worktrees}"
LOGS="$HOME/agents/logs"
LOCK="$HOME/agents/.codex.lock"
SCHEMA="$HOME/agents/codex/review-output.schema.json"
COOL="$HOME/agents/codex/.cooling"
# Inside the sandbox jest cannot spawn fb-watchman; --watchman=false is required.
export JEST_SANDBOX_FLAGS="--watchman=false"
MODEL="${CODEX_MODEL:-gpt-5.6-sol}"
EFFORT="${CODEX_EFFORT:-high}"
IDLE="${CODEX_IDLE_TIMEOUT:-1800}"
STAMP="$(date +%Y-%m-%dT%H%M%S)"

die(){ echo "lane.sh: $*" >&2; exit 2; }
case "$LANE_KIND" in review|implement|tests|hunt|fix) ;; *)
  die "usage: lane.sh <review|implement|tests|hunt|fix> <arg>";; esac
[ -n "$ARG" ] || die "missing argument for lane '$LANE_KIND'"

# --- refuse the sandbox bypass, however it arrives -------------------------
for a in "$@" ${CODEX_EXTRA_ARGS:-}; do
  case "$a" in --dangerously-bypass-approvals-and-sandbox|--yolo|--dangerously-bypass-hook-trust)
    die "refusing: '$a' defeats the containment this lane depends on";; esac
done

# --- cooling marker: a 429 last time means back off, not fail --------------
if [ -f "$COOL" ] && [ "$(cat "$COOL" 2>/dev/null)" = "$(date +%F)" ]; then
  echo "lane.sh: Codex is cooling after a rate limit today ($COOL)." >&2
  echo "lane.sh: proceed Claude-only and note it in the PR comment." >&2
  exit 3
fi

# --- single instance: an idle codex exec is ~0.3-0.6 GB before it spawns jest
# macOS ships NO `flock` (verified 2026-09-07), so the original flock+pgrep path
# silently degraded to a racy check. `mkdir` is atomic on every POSIX fs.
LOCKDIR="$LOCK.d"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  holder="$(cat "$LOCKDIR/pid" 2>/dev/null || echo '?')"
  if [ "$holder" != "?" ] && kill -0 "$holder" 2>/dev/null; then
    die "another Codex lane is running (pid $holder)"
  fi
  echo "lane.sh: clearing stale lock from pid $holder" >&2
  rm -rf "$LOCKDIR"; mkdir "$LOCKDIR" 2>/dev/null || die "cannot take lock $LOCKDIR"
fi
echo "$$" > "$LOCKDIR/pid"
release_lock(){ rm -rf "$LOCKDIR"; }

mkdir -p "$LOGS" "$WT_ROOT"
case "$LANE_KIND" in
  review|hunt) PROFILE=pantry-review ;;
  *)           PROFILE=pantry-fix ;;
esac

# --- prepare an isolated worktree ------------------------------------------
# Worktrees live OUTSIDE ~/agents so the profile can deny ~/agents wholesale
# (it holds .env.acceptance, a Neon owner connection string).
SLUG="$LANE_KIND-$STAMP"
WT="$WT_ROOT/$SLUG"
cleanup(){ [ "${KEEP_WORKTREE:-0}" = "1" ] || git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; release_lock; }
trap cleanup EXIT

git -C "$REPO" worktree add --detach "$WT" "${BASE_REF:-HEAD}" >/dev/null 2>&1 \
  || die "could not create worktree at $WT"

if [ "$PROFILE" = "pantry-fix" ] || [ "$LANE_KIND" = "review" ]; then
  echo "lane.sh: npm ci in the worktree (Codex has no network) ..."
  ( cd "$WT" && npm ci --silent ) || die "npm ci failed in $WT"
  [ -d "$WT/workers" ] && ( cd "$WT/workers" && npm ci --silent ) || true
fi

# --- build the prompt -------------------------------------------------------
PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/codex-prompt-XXXXXX")"
{
  case "$LANE_KIND" in
    review)
      echo "MODE: review"
      echo "Review the diff below against AGENTS.md's Code Review Rules."
      echo "Report only. Change nothing. Prefer no finding to a speculative one."
      echo; echo "--- diff vs $ARG ---"
      git -C "$WT" diff "$ARG"...HEAD 2>/dev/null || git -C "$REPO" diff "$ARG" ;;
    hunt)
      echo "MODE: review"
      echo "Bug hunt in area: $ARG. Repro-first: a finding names the input and the"
      echo "observable wrong outcome, or it is discarded." ;;
    implement) echo "MODE: implement"; cat "$ARG" ;;
    tests)     echo "MODE: tests";     cat "$ARG" ;;
    fix)       echo "MODE: fix";       cat "$ARG" ;;
  esac
} > "$PROMPT_FILE"

OUT="$LOGS/codex-$SLUG.json"
LAST="$LOGS/codex-$SLUG.last.txt"

echo "lane.sh: $LANE_KIND · profile=$PROFILE · model=$MODEL · worktree=$WT"
set -o pipefail
perl -e "alarm $IDLE; exec @ARGV" \
  codex exec \
    -C "$WT" \
    --ephemeral \
    --json \
    -o "$LAST" \
    --output-schema "$SCHEMA" \
    -c "default_permissions=$PROFILE" \
    -m "$MODEL" \
    -c "model_reasoning_effort=$EFFORT" \
    - < "$PROMPT_FILE" | tee "$OUT"
rc=$?
rm -f "$PROMPT_FILE"

# --- rate limits fail-WARN, never fail-stop --------------------------------
if grep -qiE 'usage_limit_reached|rate.?limit|429' "$OUT" 2>/dev/null; then
  date +%F > "$COOL"
  echo "lane.sh: rate limited — marked cooling. Proceed Claude-only." >&2
  exit 3
fi

# --- kill orphans; the sandbox helper can outlive a timeout ----------------
# NOT `pkill -f codex-darwin`: that kills every Codex on the machine, including
# an interactive session Everett may be running. Only our own descendants.
if [ -n "${CODEX_PID:-}" ]; then kill -TERM "$CODEX_PID" 2>/dev/null; fi
pkill -P $$ 2>/dev/null

if [ "$LANE_KIND" != "implement" ] && [ -s "$LAST" ]; then
  python3 - "$LAST" "$SCHEMA" <<'PY' || echo "lane.sh: WARNING output failed schema validation"
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception as e:
    print("lane.sh: output is not JSON:",e); sys.exit(1)
req={"verdict","summary","findings","next_steps"}   # plugin schema requires all four
if not req<=set(d): print("lane.sh: missing",req-set(d)); sys.exit(1)
if d["verdict"] not in ("approve","needs-attention"):
    print("lane.sh: bad verdict",d["verdict"]); sys.exit(1)
for f in d.get("findings",[]):
    if not f.get("file") or not f.get("line_start"):
        print("lane.sh: finding without file:line ->",f.get("title")); sys.exit(1)
    if f.get("severity") not in ("critical","high","medium","low"):
        print("lane.sh: bad severity",f.get("severity"),"->",f.get("title")); sys.exit(1)
print(f"lane.sh: {len(d['findings'])} finding(s), verdict={d['verdict']}")
PY
fi

if [ "$LANE_KIND" = "implement" ] || [ "$LANE_KIND" = "fix" ] || [ "$LANE_KIND" = "tests" ]; then
  echo "lane.sh: diff produced in $WT (NOT committed — Codex cannot commit):"
  git -C "$WT" --no-pager diff --stat
  echo "lane.sh: worktree kept for Claude review. Remove with:"
  echo "  git -C $REPO worktree remove --force $WT"
  KEEP_WORKTREE=1
fi
echo "lane.sh: events=$OUT last=$LAST rc=$rc"
exit $rc
