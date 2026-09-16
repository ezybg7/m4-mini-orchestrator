#!/usr/bin/env bash
# Weekly: pull upstream Multica, reapply the local bind-host patch, rebuild, restart the
# backend + web LaunchAgents, health-check. Runs as orchestrator (the server is its); the
# daemon (multica user) is untouched — it only talks to the server over localhost.
# Logs to ~/agents/logs/multica-rebuild.log. Fails loud and leaves the running build alone
# if upstream does not build — the old binaries are still what launchd is running.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/opt/node@22/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
SRC=~/agents/research/multica/src; LOG=~/agents/logs/multica-rebuild.log
say(){ echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
cd "$SRC"
before=$(git rev-parse --short HEAD)
git fetch -q origin
if git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then say "up to date at $before — nothing to rebuild"; exit 0; fi
say "rebuilding: $before → $(git rev-parse --short origin/main)"
git stash -q 2>/dev/null || true
git checkout -q mini/bind-host 2>/dev/null || true
if ! git rebase -q origin/main 2>>"$LOG"; then git rebase --abort 2>/dev/null || true; say "REBASE FAILED — bind-host patch no longer applies; leaving the running build alone"; exit 1; fi
# launchd runs ./server/bin/migrate up && ./server/bin/server from this tree, and next from apps/web.
# Build to temp paths first so a failed build never replaces a working binary.
if ! ( cd server && go build -o /tmp/multica-server-new ./cmd/server && go build -o /tmp/multica-migrate-new ./cmd/migrate ) >>"$LOG" 2>&1; then say "GO BUILD FAILED — leaving the running build alone"; exit 1; fi
if ! ( cd apps/web && npm ci --silent && npm run build --silent ) >>"$LOG" 2>&1; then say "WEB BUILD FAILED — leaving the running build alone"; exit 1; fi
install -m 755 /tmp/multica-server-new server/bin/server && install -m 755 /tmp/multica-migrate-new server/bin/migrate
launchctl kickstart -k "gui/$(id -u)/com.user.multica-backend"; launchctl kickstart -k "gui/$(id -u)/com.user.multica-web"
sleep 8
if curl -fsS http://127.0.0.1:8080/health >/dev/null && curl -fsS -o /dev/null http://127.0.0.1:3000/; then say "rebuilt and healthy at $(git rev-parse --short HEAD)"; else say "HEALTH CHECK FAILED after rebuild — investigate"; exit 1; fi
