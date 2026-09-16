#!/usr/bin/env bash
# Weekly: pull upstream Multica, reapply the local bind-host patch, rebuild, restart the
# backend + web LaunchAgents, health-check. Runs as orchestrator (the server is its); the
# daemon (multica user) is untouched — it only talks to the server over localhost.
# Logs to ~/agents/logs/multica-rebuild.log. Fails loud and leaves the running build alone
# if upstream does not build — the old binaries and the old .next are still what launchd runs.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/opt/node@22/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
SRC=~/agents/research/multica/src; LOG=~/agents/logs/multica-rebuild.log
WEB="$SRC/apps/web"; STAMP=~/agents/logs/.multica-rebuild-deployed
say(){ echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
cd "$SRC"
before=$(git rev-parse --short HEAD)
git fetch -q origin
# "Nothing to rebuild" needs BOTH: the tree already contains origin/main, AND that exact
# commit is the one we last installed and restarted. Without the stamp, a run that rebases
# and then fails to build leaves the tree ahead of the running binaries forever — every
# later run just says "up to date" and launchd keeps serving the old code. (Exactly what
# happened after the 2026-09-13 web-build failure.)
if git merge-base --is-ancestor origin/main HEAD 2>/dev/null && [ "$(cat "$STAMP" 2>/dev/null || true)" = "$(git rev-parse HEAD)" ]; then
  say "up to date at $before and deployed — nothing to rebuild"; exit 0
fi
say "rebuilding: HEAD $before, upstream $(git rev-parse --short origin/main)"
git stash -q 2>/dev/null || true
git checkout -q mini/bind-host 2>/dev/null || true
if ! git rebase -q origin/main 2>>"$LOG"; then git rebase --abort 2>/dev/null || true; say "REBASE FAILED — bind-host patch no longer applies; leaving the running build alone"; exit 1; fi
# go build needs a C compiler for runtime/cgo, and the one xcode-select points at
# (/Applications/Xcode.app) is gated behind a license agreement that every Xcode update
# resets — on 2026-09-15 clang, xcrun and /usr/bin/git were all failing with "You have not
# agreed to the Xcode license agreements", which took the Go build down with them. The
# Command Line Tools toolchain is not behind that gate, so fall back to it rather than let
# an unattended weekly job die on a licence prompt. Agreeing to the licence machine-wide
# (sudo xcodebuild -license) is the operator's call, not this script's.
if ! /usr/bin/clang --version >/dev/null 2>&1 && [ -x /Library/Developer/CommandLineTools/usr/bin/clang ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  say "Xcode toolchain unusable (licence not agreed) — building cgo against the Command Line Tools"
fi
# launchd runs ./server/bin/migrate up && ./server/bin/server from this tree, and next from apps/web.
# Build to temp paths first so a failed build never replaces a working binary. The -ldflags
# mirror the repo's own `make build` (Makefile lines 324-342): without them main.commit keeps
# its default and /health reports {"commit":"unknown"}, so nothing on the box can tell which
# build is live. migrate takes no ldflags there either.
VER=$(git describe --tags --match 'v[0-9]*' --always --dirty 2>/dev/null || echo dev)
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
if ! ( cd server && go build -ldflags "-X main.version=$VER -X main.commit=$SHA" -o /tmp/multica-server-new ./cmd/server && go build -o /tmp/multica-migrate-new ./cmd/migrate ) >>"$LOG" 2>&1; then say "GO BUILD FAILED — leaving the running build alone"; exit 1; fi
# Web tier. This repo is a pnpm workspace: pnpm-workspace.yaml, an 849K pnpm-lock.yaml, and
# "packageManager": "pnpm@10.28.2" — there is no package-lock.json anywhere, and apps/web
# depends on @multica/{core,ui,views,eslint-config} via workspace:* plus catalog: versions.
# npm understands none of that, so `npm ci` here could only ever fail (EUSAGE, no lockfile);
# --silent then swallowed the error, which is why 2026-09-13 logged a bare "WEB BUILD FAILED"
# with nothing above it. Install at the workspace root from the committed lockfile, then let
# turbo run the mdx step and `next build` (turbo.json: build dependsOn ^build + mdx).
# next build writes into .next in place and launchd's `next start` serves straight out of it,
# so snapshot the live build (minus the ~1.5G .next/cache) and restore it if the build fails.
snap(){ rm -rf "$WEB/.next.prev"; [ -d "$WEB/.next" ] || return 0; mkdir -p "$WEB/.next.prev"; ( cd "$WEB/.next" && tar -cf - --exclude ./cache . ) | ( cd "$WEB/.next.prev" && tar -xf - ); }
unsnap(){ [ -d "$WEB/.next.prev" ] || return 0; mkdir -p "$WEB/.next"; find "$WEB/.next" -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} +; ( cd "$WEB/.next.prev" && tar -cf - . ) | ( cd "$WEB/.next" && tar -xf - ); rm -rf "$WEB/.next.prev"; }
snap
if ! ( cd "$SRC" && pnpm install --frozen-lockfile && pnpm exec turbo build --filter=@multica/web ) >>"$LOG" 2>&1; then unsnap; say "WEB BUILD FAILED — leaving the running build alone"; exit 1; fi
rm -rf "$WEB/.next.prev"
install -m 755 /tmp/multica-server-new server/bin/server && install -m 755 /tmp/multica-migrate-new server/bin/migrate
launchctl kickstart -k "gui/$(id -u)/com.user.multica-backend"; launchctl kickstart -k "gui/$(id -u)/com.user.multica-web"
# `next start` on a freshly written .next can take well past the 8s the old script waited;
# poll so a slow-but-healthy restart is not reported as a failed one.
ok=0; for _ in $(seq 1 30); do sleep 2; if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1 && curl -fsS -o /dev/null http://127.0.0.1:3000/ 2>/dev/null; then ok=1; break; fi; done
if [ "$ok" = 1 ]; then git rev-parse HEAD > "$STAMP"; say "rebuilt and healthy at $(git rev-parse --short HEAD)"; else say "HEALTH CHECK FAILED after rebuild — investigate"; exit 1; fi
