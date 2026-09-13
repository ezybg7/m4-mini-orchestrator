---
type: entity
title: Multica server on the mini
description: Multica's Go API and Next.js web tier, built from source and run natively under
  launchd on the M4 mini, localhost-only, on a local Homebrew postgresql@17 at port 5433
  (spec 61 phase 1), with the dedicated `multica` daemon user live since 2026-09-11 under a
  system LaunchDaemon - twelve agents, two squads and one autopilot now run Ambry's
  development, review and research loops on it.
tags:
- m4-mini
- infra
- multica
- launchd
- postgres
- security
timestamp: 2026-09-12 00:00:00+00:00
permalink: agents/entities/multica-server
---

# Multica server on the mini

Installed 2026-09-11 for pantry **spec 61 phase 1** (`specs/multica-integration.md`,
PR #215; the decision brief is `~/agents/research/multica/hosting.md`). **Phase 2 went live 2026-09-11**: the `multica` daemon user is provisioned and
running under `/Library/LaunchDaemons/com.user.multica-daemon.plist`, and the
board now runs the development loop (planner -> implementer -> a three-lens
review squad), a research squad, and a weekly Dependabot autopilot. How to drive
it is the runbook in `~/agents/references/multica-board.md`; the operating detail
Claude Code sessions load is `project-multica-runbook` in the pantry project memory. Sibling:
[OrbStack on the mini](orbstack.md) (the container path we did not take).

## What runs where

| Piece | Runs as | Listens on | Supervised by |
|---|---|---|---|
| PostgreSQL 17.11 (Homebrew `postgresql@17`) | `orchestrator` | `127.0.0.1:5433`, `[::1]:5433`, socket `/tmp/.s.PGSQL.5433` | `brew services` → `sh.brew.postgresql@17` (`~/Library/LaunchAgents/sh.brew.postgresql@17.plist`) |
| Go API `server/bin/server` | `orchestrator` | `127.0.0.1:8080` (+ pprof `127.0.0.1:6060`) | `com.user.multica-backend` |
| Next.js 16 web `next start` on node@22 | `orchestrator` | `127.0.0.1:3000` | `com.user.multica-web` |

Never on the default port 5432, never off loopback. This store is **outside**
pantry's "no local database" rule: it holds no Ambry data and is never a schema
verification target ([Neon project](neon-project.md) stays the only one).

## Paths

- Build: `~/agents/research/multica/src` — upstream commit `51803b3` (v0.4.42 era)
  plus one local commit on branch **`mini/bind-host`** (`c4af104`):
  `server/cmd/server/listen_addr_local.go` adds `MULTICA_BIND_HOST` (upstream
  binds `:PORT` on all interfaces, no knob, and the macOS firewall is off).
  Unset = upstream behaviour. Build outputs: `server/bin/{server,multica,migrate}`,
  `apps/web/.next` (1.5 GB, gitignored upstream).
- Config: `~/agents/multica/.env` (mode 600; `.env*` is gitignored in this vault) —
  keys only: `APP_ENV=production PORT MULTICA_BIND_HOST DATABASE_URL JWT_SECRET
  MULTICA_VCS_SECRET_KEY FRONTEND_ORIGIN MULTICA_APP_URL ALLOW_SIGNUP=false
  ALLOWED_EMAILS DISABLE_WORKSPACE_CREATION LOCAL_UPLOAD_DIR REMOTE_API_URL`.
  No Resend/SMTP: login codes are printed to the backend log.
- Logs: `~/agents/multica/logs/{backend,web}.{log,err}` (dir mode 700 —
  `backend.log` carries the `[DEV] Verification code for …` lines). Postgres:
  `/opt/homebrew/var/log/postgresql@17.log`.
- Data: `/opt/homebrew/var/postgresql@17` (cluster), `~/agents/multica/data/uploads`.
- Backups: `~/agents/backups/multica/multica-YYYY-MM-DD.sql.gz`, written by
  `scripts/backup.sh` step 1b nightly at 02:30 (peer auth over the socket, no
  password), 7-day rotation, gitignored.
- Plists: `~/Library/LaunchAgents/com.user.multica-{backend,web}.plist`
  (modelled on `com.user.hermes.plist`; snapshotted nightly into `system-config/`).

## Operate

```bash
# status / restart / logs
launchctl print gui/501/com.user.multica-backend | grep -E 'state|pid'
launchctl kickstart -k gui/501/com.user.multica-backend     # also re-runs migrate up
launchctl kickstart -k gui/501/com.user.multica-web
tail -f ~/agents/multica/logs/backend.err                    # slog; codes are in backend.log
curl -s localhost:8080/health; curl -s localhost:8080/readyz; curl -s localhost:3000/api/config

# database (superuser = orchestrator via the peer socket; multica = app role, scram over TCP)
/opt/homebrew/opt/postgresql@17/bin/psql -h /tmp -p 5433 -d multica

# login: Everett enters his address at http://localhost:3000, the code is here:
grep 'Verification code for' ~/agents/multica/logs/backend.log | tail -1
```

Signup is locked from first boot without a bootstrap dance: `ALLOWED_EMAILS`
is checked **before** `ALLOW_SIGNUP` (`server/internal/handler/auth.go`
`checkSignupAllowed`) and existing users always log in. After Everett's first
login has created the shared workspace: set `DISABLE_WORKSPACE_CREATION=true`
in the `.env` and kickstart the backend (upstream's documented order —
`SELF_HOSTING_ADVANCED.md` "Locking down workspace creation").

## Upgrade (weekly pinned bump, 02:30 window — ~80 s measured)

```bash
cd ~/agents/research/multica/src
git checkout -- apps/web/next-env.d.ts            # next build rewrites it
git fetch --tags origin && git rebase <new-tag>   # carries the one mini/bind-host commit
export PATH=/opt/homebrew/opt/node@22/bin:/opt/homebrew/bin:$PATH
make build && pnpm install --frozen-lockfile --filter '@multica/web...' && pnpm --filter @multica/web build
launchctl kickstart -k gui/501/com.user.multica-backend && launchctl kickstart -k gui/501/com.user.multica-web
```

Measured 2026-09-11: `make build` 14 s cold (88 s CPU), install 12 s,
`next build` 54 s. Idle RSS: backend 36 MB, web 210 MB (+16 MB esbuild
helper), Postgres ~166 MB summed over 14 processes (double-counts shared
pages) — about 430 MB combined against the spec's 1 GB ceiling.

## Rollback

Stop half (rehearsed, restart verified): `launchctl bootout gui/501/com.user.multica-web`,
`launchctl bootout gui/501/com.user.multica-backend`, `brew services stop postgresql@17`.
Remove: `rm ~/Library/LaunchAgents/com.user.multica-*.plist`; `pg_dump` first if
worth keeping; `rm -rf ~/agents/multica ~/agents/backups/multica /opt/homebrew/var/postgresql@17`;
in the clone `git checkout main && git branch -D mini/bind-host && rm -rf server/bin apps/web/.next node_modules`;
drop the backup.sh step 1b block and the two Multica lines in `.gitignore`;
optionally `brew uninstall postgresql@17 go pnpm node@22`. Neon and Ambry are never touched.

## Daemon user (spec 61 phase 2 — prepared 2026-09-11, not yet run)

The agents run as **`multica`** (uid 502, Standard, home `/Users/multica`,
created by Everett 2026-09-11) — Multica's own recommended boundary, since a
run is `claude -p --permission-mode bypassPermissions` with every prompt
auto-allowed. Provisioning is one admin run of
`~/agents/multica/daemon-user/setup-multica-user.sh` (`sudo bash …`, idempotent;
the ordered list is `RUNBOOK.md` beside it). Until Everett runs it, nothing
below exists on disk.

| Piece | Where / how |
|---|---|
| Claude Code | `~multica/.local/bin/claude`, Anthropic's native installer (sha256 vs its manifest); auth = `CLAUDE_CODE_OAUTH_TOKEN` from `~multica/.claude/oauth_token` (600), minted by `claude setup-token` — the documented headless path; it passes the daemon's child-env filter |
| Multica CLI | `~multica/.local/bin/multica`, release tarball `multica-cli-<ver>-darwin-arm64.tar.gz` sha256-checked against `checksums.txt`, **pinned to the server's tag** (`MULTICA_CLI_VERSION`, 0.4.42 today), `disable_auto_update=true`; profile `~multica/.multica/config.json` (600): `server_url http://127.0.0.1:8080`, `app_url http://localhost:3000`, `device_name m4-mini`, `max_concurrent_tasks 2`; PAT via `multica login --token` read from a 600 file on stdin |
| GitHub | deploy key `~multica/.ssh/pantry_deploy_ed25519` (write, ezybg7/pantry; public copy at `/Users/Shared/multica-daemon/`) is the **only git write path** — `~/.ssh/config` pins it with `IdentitiesOnly`, `known_hosts` from api.github.com/meta; `gh` uses `GH_TOKEN` from `~multica/.config/multica-daemon/github_token` (600), a fine-grained PAT — recommended Contents: read + Pull requests: write (narrower than the spec table; Everett's call) |
| Clone | `~multica/work/pantry` over the deploy key — the `local_directory` resource for agents that need the repo's `.claude/settings.json` hooks; `github_repo` resources are cloned by the daemon into `~multica/multica_workspaces/` |
| Service | **LaunchDaemon** `/Library/LaunchDaemons/com.user.multica-daemon.plist` (root-owned, `UserName multica`, KeepAlive, `nice 5`, `MULTICA_DAEMON_MAX_CONCURRENT_TASKS=2`) → `~multica/.local/bin/multica-daemon-launchd.sh` → `multica daemon start --foreground --max-concurrent-tasks 2`. Not a LaunchAgent: a user that never logs in has no `gui/502` domain (`launchctl print gui/502` → "Could not find domain"). Health `127.0.0.1:19514`; daemon log `~multica/.multica/daemon.log` (rotated); wrapper log `~multica/Library/Logs/multica-daemon/launchd.log` |

Operate (admin): `sudo launchctl print system/com.user.multica-daemon | grep -E 'state|pid'` ·
`sudo launchctl kickstart -k system/com.user.multica-daemon` ·
`sudo -u multica -H /Users/multica/.local/bin/multica daemon logs -n 100`. Weekly bump:
re-run the script with `MULTICA_CLI_VERSION=<new tag>` after the server rebuild.

Boundary proofs the script's self-check enforces (as `multica`): `~orchestrator`
(mode 700) unreadable — `.env.acceptance`, `.claude/oauth_token`,
`.config/gh/hosts.yml`, `agents/multica/.env` all "Permission denied"; `psql`
over the socket as `orchestrator` (peer) and as `multica` (reject rule) and
over TCP as either without a password all fail. `/Users/multica` is set to 700.
`main` on ezybg7/pantry is **unprotected** (checked 2026-09-11); the runbook
recommends a ruleset (require PR, block force-push, bypass = repository admin,
never deploy keys) as Everett's decision.

## Remote access over Tailscale (2026-09-12)

Everett's phone reaches the board at **`http://m4-mini.tail5cb205.ts.net`** (short form
`http://m4-mini`) with the Tailscale app connected — tailnet only, no Funnel. He applied it
himself on 2026-09-12 after a scratch-session investigation (daily log 12:40):

- `tailscale serve --bg --http=80 http://127.0.0.1:3000` — Serve proxies in-process to the
  loopback web tier; the web and API listeners are unchanged (`127.0.0.1`). Inspect with
  `tailscale serve status`; remove with `tailscale serve reset`. Persists across reboots.
- `CORS_ALLOWED_ORIGINS=http://localhost:3000,http://m4-mini.tail5cb205.ts.net,https://m4-mini.tail5cb205.ts.net`
  lives in **`com.user.multica-backend.plist` → `EnvironmentVariables`**, not in the `.env`
  (which does not define the key, so the plist value survives sourcing). The value *replaces*
  `FRONTEND_ORIGIN` as the CORS + WebSocket-origin allowlist, so localhost must stay listed;
  it is read at startup. A plist change needs `launchctl bootout` + `bootstrap`; `kickstart -k`
  (what the weekly rebuild does) keeps it.
- Next 16 `next start` proxies the `/ws` upgrade to the backend (verified: 101 through :3000
  with the tailnet Host header), so no reverse proxy and no `NEXT_PUBLIC_WS_URL` rebuild,
  contrary to upstream's LAN docs. `FRONTEND_ORIGIN` / `MULTICA_APP_URL` stay
  `http://localhost:3000`, so the session cookie stays non-`Secure` and works on both origins.
- Login on the phone: email → code in `backend.log` (same grep as above); session cookie 30 days.
  Multica ships `appleWebApp` metadata, so Safari's Add to Home Screen gives a standalone app.
- HTTPS: tailnet certificates are **not enabled** (`tailscale status --json` → `CertDomains`
  empty). Enabling them in the Tailscale admin console (DNS → HTTPS certificates) and then
  `tailscale serve --bg http://127.0.0.1:3000` gives `https://m4-mini.tail5cb205.ts.net`; the
  allowlist above already includes that origin. Plain HTTP inside the tunnel is already
  WireGuard-encrypted; HTTPS only removes Safari's "Not Secure" label.

## Gotchas

- **Auth hardening is deliberate.** Homebrew's cluster defaults to `trust`; with it
  any local user — the future `multica` daemon user — could connect as the
  `orchestrator` superuser and `pg_read_file` the files spec 61 fences off.
  `pg_hba.conf` is `peer` on the socket and `scram-sha-256` on TCP; the
  superuser has no password, so it is socket-only. Since 2026-09-11 the first
  rule is `local all multica reject`: with plain `peer`, the multica **OS**
  user would pass as the multica **DB** role over the socket (same name) and
  own the Multica database; the backend only ever connects over TCP.
  Backup of the previous file: `pg_hba.conf.bak-2026-09-11`.
- **Homebrew dependency bumps can break the default Node.** Installing node@22
  bumped `simdutf`; `merve` (linked by the default node 26.5.0) broke until
  `brew upgrade merve` alone. `HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1` keeps
  such a repair from touching `node` itself.
- Multica's `next start` reads `../../.env` (the clone root) via dotenv — keep
  the clone root free of any `.env`; ours lives in `~/agents/multica/`.
- launchd does not rotate logs; `backend.log` and `backend.err` grow. Open item.
- Toolchain: Go 1.27.1, pnpm 12.3.4 (self-selects 10.28.2 from `packageManager`),
  node@22 22.23.2 keg-only (`/opt/homebrew/opt/node@22/bin`), postgresql@17 17.11.
  Default Node 26.5.0 untouched.
