---
type: entity
title: Multica server on the mini
description: Multica's Go API and Next.js web tier, built from source and run natively under
  launchd on the M4 mini, localhost-only, on a local Homebrew postgresql@17 at port 5433.
  Phase 1 of pantry spec 61 - no daemon, no agents, no multica user yet.
tags:
- m4-mini
- infra
- multica
- launchd
- postgres
timestamp: 2026-09-11 00:00:00+00:00
permalink: agents/entities/multica-server
---

# Multica server on the mini

Installed 2026-09-11 for pantry **spec 61 phase 1** (`specs/multica-integration.md`,
PR #215; the decision brief is `~/agents/research/multica/hosting.md`). The
server and the web app run; nothing executes tasks until Everett creates the
`multica` Unix user and phase 1's agent is registered. Sibling:
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

## Gotchas

- **Auth hardening is deliberate.** Homebrew's cluster defaults to `trust`; with it
  any local user — the future `multica` daemon user — could connect as the
  `orchestrator` superuser and `pg_read_file` the files spec 61 fences off.
  `pg_hba.conf` is `peer` on the socket and `scram-sha-256` on TCP; the
  superuser has no password, so it is socket-only.
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
