#!/usr/bin/env bash
# Cron strips PATH to almost nothing; claude lives in ~/.local/bin on the mini.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
#
# pantry-weekly-maintenance.sh — weekly dependency + security pass for Ambry
# (repo ezybg7/pantry, checkout ~/Code/pantry).
#
# CRONTAB LINE — Everett installs this himself with `crontab -e`; this script
# never touches crontab. Weekly, Monday 09:00:
#
#   0 9 * * 1 /Users/ezy/agents/pantry-weekly-maintenance.sh
#
# No redirect needed: the script sends all of its own output to
# ~/agents/logs/pantry-weekly.log (see `exec` below).
#
# Run `pantry-weekly-maintenance.sh --check` to self-test the date arithmetic.
#
set -euo pipefail

REPO="${PANTRY_REPO:-$HOME/Code/pantry}"
LOG="${PANTRY_WEEKLY_LOG:-$HOME/agents/logs/pantry-weekly.log}"

# The Apple "client secret" is a signed ES256 JWT with a hard 6-month expiry,
# not a static key. When it lapses, Sign in with Apple fails for everyone.
# Dependabot does not and cannot catch this. Set 2026-08-22, 180 days.
APPLE_SECRET_EXPIRY="2027-02-18"
APPLE_WARN_DAYS=30

# Days from today until $1 (YYYY-MM-DD). BSD date first (the mini is macOS),
# GNU date as the fallback — this line is the one thing worth self-testing.
days_until() {
  local epoch
  epoch=$(date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || date -d "$1" +%s)
  echo $(( (epoch - $(date +%s)) / 86400 ))
}

# ponytail: the only real logic here is the date math, so it gets the only test.
if [ "${1:-}" = "--check" ]; then
  today=$(date +%Y-%m-%d)
  [ "$(days_until "$today")" = "0" ] || { echo "FAIL: today should be 0 days out"; exit 1; }
  [ "$(days_until "2099-01-01")" -gt 20000 ] || { echo "FAIL: 2099 should be far away"; exit 1; }
  [ "$(days_until "2000-01-01")" -lt 0 ] || { echo "FAIL: 2000 should be negative"; exit 1; }
  echo "ok: date arithmetic works on this box"
  exit 0
fi

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }

log "=== pantry weekly maintenance start ==="

# --- 1. Apple client secret expiry -------------------------------------------
# First, because it costs nothing and must be reported even if everything below
# falls over.
apple_days=$(days_until "$APPLE_SECRET_EXPIRY")
if [ "$apple_days" -lt "$APPLE_WARN_DAYS" ]; then
  log "APPLE SECRET ⚠️  ${apple_days}d left (expires ${APPLE_SECRET_EXPIRY}) — REGENERATE NOW."
  log "APPLE SECRET  node scripts/apple-client-secret.mjs --key ~/Downloads/AuthKey_YK8V7A579F.p8 \\"
  log "APPLE SECRET    --key-id YK8V7A579F --team-id SANRTXS285 --client-id com.everettyan.ambry"
  log "APPLE SECRET  then: cd workers && wrangler secret put APPLE_CLIENT_SECRET && wrangler deploy"
else
  log "apple secret: ${apple_days}d left (expires ${APPLE_SECRET_EXPIRY}), no action"
fi

# --- 2. Refresh the checkout --------------------------------------------------
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" fetch --prune --quiet && log "fetched origin ($(git -C "$REPO" rev-parse --short origin/main))"
else
  log "SKIP: no git checkout at $REPO"
  exit 0
fi

# --- 3. Dependabot triage, delegated to a headless Claude ---------------------
# Everything policy-shaped lives in the prompt, not in bash: deciding whether a
# bump is a security fix or fights the Expo pin is a reading job, not a regex.
if ! command -v claude >/dev/null 2>&1; then
  log "SKIP: claude CLI not on PATH — no Dependabot triage this week"
  log "=== pantry weekly maintenance end ==="
  exit 0
fi

# A plain heredoc redirect, NOT `PROMPT=$(cat <<'EOF' … )`: bash 3.2 (which is
# what /bin/bash on macOS still is) mis-scans quotes inside a heredoc nested in
# a command substitution, so one apostrophe in the prompt breaks the script.
# `read -d ''` reads to NUL, i.e. the whole document, and returns 1 at EOF.
IFS= read -r -d '' PROMPT <<'EOF' || true
You are the weekly dependency maintainer for Ambry (repo ezybg7/pantry, base
branch main, checkout ~/Code/pantry). Read ~/Code/pantry/CLAUDE.md first — its
hard rules bind you.

Use the GitHub MCP server for all GitHub work: the gh CLI is NOT installed on
this machine. Never report "gh: command not found" as a blocker.

Read `.github/dependabot.yml` in the checkout before you start — it is the
repo's own written policy and it outranks any assumption. As of 2026-08-22 it
GROUPS routine bumps, so one PR usually carries several packages ("app-routine"
for /, "worker-routine" for /workers, plus github-actions). Judge a grouped PR
by its worst member, never its title.

CI green means the four gates already ran (root typecheck, workers typecheck,
lint, jest) — .github/workflows/ci.yml runs all of them, so you do not need to
run them locally.

For EVERY open pull request authored by Dependabot:

1. List every package and version jump it contains (a group PR lists them in
   the body), and read its CI state (pull_request_read, method get_check_runs).

2. If it touches ANY of: expo, expo-*, @expo/*, react-native, react-native-*,
   react, react-dom, jest-expo — or moves TypeScript — STOP and think, because
   dependabot.yml already IGNORES version updates for exactly these:

   * If it is a routine version bump, the ignore list leaked or was edited:
     CLOSE it with a comment saying these move only via `npx expo install` or a
     deliberate SDK upgrade (they are pinned to the Expo SDK, and a lone bump
     desynchronises the native runtime from the JS bundle), or, for TypeScript,
     that the repo runs ONE unified TS major on purpose.
   * If it is a SECURITY ADVISORY, do NOT close it and do NOT merge it —
     advisories are not ignorable and this one got through on purpose. Comment
     that it needs a human because the fix has to go through `npx expo install`
     or an SDK upgrade rather than a version bump, and say so in your log line.

3. Otherwise MERGE it (squash) if BOTH hold: every required check is GREEN, and
   EVERY package in it is a patch-level or minor-level bump, or the PR is a
   security fix at any level (a Dependabot advisory in the body is what makes
   it one).

4. Anything else — CI red, CI still pending, any major bump in the set, an
   unfamiliar package, or any case you are less than confident about — do NOT
   merge and do NOT close. Leave one short comment saying exactly why you
   skipped it and what a human should check.

5. You merge, close and comment. Nothing else. Do NOT edit package.json or
   package-lock.json, do NOT push commits, and NEVER run `npm audit fix
   --force` — it proposes a semver-major DOWNGRADE of expo and is a standing
   hard rule in this repo.

Finally, append EXACTLY ONE line to __LOGFILE__ (append, never overwrite):

  <ISO8601 timestamp> dependabot: merged=<n> closed=<n> skipped=<n> (<short clause>)

If there were no open Dependabot PRs, write that line with all zeros and the
clause "none open".
EOF
PROMPT="${PROMPT//__LOGFILE__/$LOG}"

log "--- dependabot triage (claude -p) ---"
# Unattended, so permissions cannot be prompted for. The blast radius is bounded
# by the prompt above plus the repo's own guard hook (.claude/hooks/guard-bash.mjs
# blocks `npm audit fix --force` and docker regardless of what the model decides).
if claude -p "$PROMPT" --dangerously-skip-permissions; then
  log "--- dependabot triage done ---"
else
  log "DEPENDABOT ⚠️  claude -p exited non-zero — triage incomplete, check by hand"
fi

log "=== pantry weekly maintenance end ==="
