---
type: decision-brief
title: Self-hosting Multica on the M4 mini
description: Native Go+Next under launchd with a local Homebrew Postgres, versus OrbStack compose and Neon — evidence, tradeoffs, runbook.
tags: [multica, m4-mini, self-host, research]
timestamp: 2026-09-11T00:00:00Z
source_commit: multica-ai/multica 51803b3 (v0.4.42 era), clone at ~/agents/research/multica/src
---

# Self-hosting Multica on the M4 mini

## Recommendation

Run Multica **natively under launchd** (option B) with a **local Homebrew `postgresql@17`** on port 5433 (option iii), localhost-only, `APP_ENV=production`, no Resend (login codes read from the server log), signup restricted to Everett's address. The container path is not the install headache the premise assumed — OrbStack is already on the mini — but its VM costs ~3.6–4.2 GiB of the 16 GB at idle (measured today), which is half the agent fleet's headroom, and it must run permanently. The native path costs roughly 0.5–1 GB, uses toolchains Homebrew has (Go 1.27.1, pnpm) and the Node already installed, and its one real tax is that every Multica release is a rebuild (~5–10 min, releases land every ~2 days). Neon is ruled out for this workload on the free plan: the Go server keeps its compute awake around the clock (30-second sweeper and scheduler queries, 15-second daemon heartbeats), which burns ~180 CU-hours a month against a 100 CU-hour allowance and suspends the project mid-month — and a second database inside the Pantry project would take **Ambry production** down with it. Local Postgres also cuts each query from ~86 ms (mini → Oregon) to sub-millisecond. The pantry "no local database" rule is about Ambry schema parity with Neon; a Multica store on a non-default port, holding no Ambry data, is outside it, and the runbook keeps it visibly separate.

## Premise corrections (verified on the machine, 2026-09-11)

1. **OrbStack is installed, not absent.** `/usr/local/bin/docker` symlinks into `/Applications/OrbStack.app/Contents/MacOS/xbin/`, `orbctl` 2.2.3 is at `/usr/local/bin/orbctl`, the `orbstack` cask is in `brew list --cask`, its privileged-helper LaunchDaemon dates from Jul 17. Its VM had been stopped since Sep 3 (`~/.orbstack/log/vmgr.1.log`: "VM stopped" 09-03 17:45) — "no runtime reachable" was true, "no OrbStack" was not. It is presumably what pantry's Docker MCP gateway runs on (that gateway failed to connect in this session).
2. **Side effect, disclosed:** my `orbctl status` / `orbctl config show` probes booted the VM (helper RSS 4,263 MiB thirty seconds in; `~/.orbstack/run/docker.sock` appeared 01:13). I returned it to the prior state with `orbctl stop` (vmgr.log: "VM stopped" 01:36; socket gone). Do not use `orbctl` as a probe; `ls ~/.orbstack/run/docker.sock` is the safe check.
3. **pgvector is not required.** No migration declares a `vector` column or extension (grep of `server/migrations/`); the image name is historical (SELF_HOSTING_ADVANCED.md:244-247). Hard requirements: `pgcrypto` (001_init.up.sql:2), `pg_trgm` (137_search_index_pg_trgm_extension.up.sql:4); `pg_bigm`/`pg_cron` are `DO … EXCEPTION`-guarded and skipped (032_issue_search_index.up.sql:3-9; 076_task_usage_pgcron_extension.up.sql:24-31).
4. `psql`/`pg_ctl` come from `libpq` 18.4; there is no Postgres server (`brew list --formula`).

## 1. Native vs container

Architecture: Go single binary (REST + WebSocket) on 8080, Next.js 16 on 3000, PostgreSQL 17; the agent daemon is a CLI process on the operator's machine, never in a container (SELF_HOSTING.md:9-11, :101).

### A — OrbStack VM + official compose

- **Install:** nothing new — `orbctl start`, then `git clone … ~/.multica/server && make selfhost` (creates `.env`, generates `JWT_SECRET`/`POSTGRES_PASSWORD`/`MULTICA_VCS_SECRET_KEY`, pulls GHCR images, starts the stack: Makefile:82-113). `linux/arm64` images exist (release.yml:123-125, :240-242).
- **What runs where:** three containers — `pgvector/pgvector:pg17`, backend, frontend — published on `127.0.0.1:8080` / `127.0.0.1:3000` only, by design (docker-compose.selfhost.yml:3-8, :61, :208); the entrypoint migrates before serving (docker/entrypoint.sh:26-41). The daemon runs natively (SELF_HOSTING.md:139-147).
- **RAM:** the VM measured **4,263 MiB RSS at +30 s, 3,655 MiB after ~20 min idle with no user containers**; cap `memory_mib: 8192` (`orbctl config show`). The chart declares 256 Mi requests / 1 Gi limits per service (values.yaml:64-70, :153-159, :187-193). Steady state ≈ 4–5 GB of 16.
- **Upgrade:** compose `pull` then `up -d`; pin with `MULTICA_IMAGE_TAG` (SELF_HOSTING.md:461-466). Minutes, no build.
- **Failure modes:** the VM must run permanently and `app.start_at_login` is `false` — it needs its own launchd start or survives no reboot; the pantry hook blocks every `docker …` except `docker mcp` in any pantry session (`.claude/hooks/guard-bash.mjs:40-41`, project-scoped via `.claude/settings.json:9`), so operations must run from a non-pantry shell; `docker.expose_ports_to_lan: true` is set, though the compose file's `127.0.0.1` bindings keep it local.

### B — native Go binary + Next.js under launchd

- **Install:** `brew install go pnpm postgresql@17` (Go 1.27.1 builds the `go 1.26.6` module, server/go.mod:3; pnpm self-selects `pnpm@10.28.2` from `packageManager`, package.json:36; Node 26.5.0 satisfies `engines >=22`, package.json:33-35, though upstream pins 22 — `.nvmrc`, Dockerfile.web:2 — a risk to note). Then `make build` → `server/bin/{server,multica,migrate}` (Makefile:338-342), `pnpm install --frozen-lockfile --filter @multica/web...`, `pnpm --filter @multica/web build` (what the image does, Dockerfile.web:50), `migrate up`, `server`, `REMOTE_API_URL=http://localhost:8080 pnpm --filter @multica/web start` (SELF_HOSTING_ADVANCED.md:366-389).
- **What runs where:** four launchd jobs — Postgres :5433, server :8080 (plus a fixed loopback pprof listener 127.0.0.1:6060, profiling/server.go:9, main.go:809-814), web :3000, daemon (health 127.0.0.1:19514, daemon/config.go:69, health.go:88-95). The browser talks HTTP to 3000 (Next proxies `/api`, `/v1`, `/auth`, `/uploads` to `REMOTE_API_URL` at request time, proxy.ts:114-127, next.config.ts:67-94) and WebSocket straight to `ws://localhost:8080/ws`, the client default when `NEXT_PUBLIC_*` are unset (core-provider.tsx:118, runtime-urls.ts:102-108).
- **RAM (estimates):** ~100–300 MB Go server, ~150–350 MB `next start`, ~150–250 MB Postgres (128 MB `shared_buffers` + ≤25 backends; pool 25/5, dbstats.go:38-39), ~50 MB daemon: **≈0.5–1 GB**. Agent CLIs cost the same in both paths.
- **Upgrade:** no server binaries are released — v0.4.42's assets are CLI tarballs and desktop installers (`gh release view`); goreleaser builds only `./cmd/multica` (.goreleaser.yml:6-9). Every release = checkout tag, `make build`, `pnpm install`, web build, `migrate up`, restart. The repo documents no timings; estimate 5–10 min on the M4 (Go ~1 min warm, Next webpack 2–5 min with a 2–4 GB transient) — run it in the 02:30–03:00 maintenance window. Cadence: 12 releases Aug 20–Sep 9 (`gh release list`); weekly tracking is reasonable.
- **Failure modes:** the server binds `":"+PORT` on **all interfaces**, no bind-host knob (main.go:679), and the macOS application firewall is **disabled** (`socketfilterfw --getglobalstate`), so 8080 is reachable on the LAN (10.0.0.74) and tailnet (100.121.102.56) — mitigated in §3; `migrate` and `server` find `migrations/` from the working directory (migrations.go:15-42; readiness needs it, health.go:73-83) so `WorkingDirectory` must be the checkout; `LOCAL_UPLOAD_DIR` is CWD-relative unless absolute (SELF_HOSTING_ADVANCED.md:101); login codes go to **stdout** via `fmt.Printf` (email.go:353), so the plist must capture `StandardOutPath`.

**Verdict: B.** B buys ~3–4 GB of fleet headroom and no VM babysitting at the price of a scripted 5–10-minute rebuild per release; A buys pull-and-go upgrades at the price of a permanently resident VM and a Docker CLI the project's own tooling refuses to run.

## 2. Database

Requirements confirmed above: PostgreSQL 17, `pgcrypto`, `pg_trgm`; both ship in Homebrew's `postgresql@17` (SELF_HOSTING_ADVANCED.md:258-261). The migrator holds a **session-level advisory lock** (migrate/main.go:819-868) and 203 migration files use `CREATE INDEX CONCURRENTLY`, so migrations need a direct, non-transaction-pooled connection — on Neon that means the non-`-pooler` host (neon-postgres skill, SKILL.md:271-278).

**How chatty is the server?** No LISTEN/NOTIFY (grep). But three loops touch the DB regardless of traffic: the runtime sweeper every 30 s (runtime_sweeper.go:26, :224), the scheduler tick every 30 s (`dbNow`, scheduler/manager.go:51, :124-125), and each daemon heartbeat every 15 s (CLI_AND_DAEMON.md:240; handler/daemon.go:1207, :1252), plus a warm pool of 5. Neon suspends only after 5 idle minutes (plans doc), so a running Multica **never lets its compute sleep**. Page loads issue many sequential queries; measured TCP RTT mini → `ep-autumn-dew-….us-west-2` is **86 ms median** (the mini egresses from Virginia).

| | (i) separate Neon project | (ii) second DB in Pantry project | (iii) Homebrew postgresql@17 |
|---|---|---|---|
| Isolation from Ambry | full (own creds, own compute) | **none that matters**: same compute endpoint, same CU budget, same host; credential blast radius shared | full: different host, port 5433, own role, no Neon creds involved |
| Latency | ~86 ms/query | ~86 ms/query | <1 ms |
| Backup/restore | 6 h restore window on Free (plans doc) | shares Pantry's window; a restore rolls both apps | nightly `pg_dump` into the existing 02:30 `backup.sh`, restore = `psql < dump` |
| Free-plan cost | allowed (100 projects), but 0.25 CU × 720 h = **180 CU-h > 100 CU-h/project/month** → compute suspended ~day 17 until next month; scale-to-zero cannot be disabled on Free | the same 180 CU-h lands on Pantry's budget → **Ambry production suspended** mid-month (Pantry has used ~14 CU-h since Jul 29: `compute_time_seconds` 50085 on branch `production`) | none |
| Pantry "no local DB" rule | n/a | n/a | see below |

Neon facts: org `Pantry` is on plan `free` with one project, `red-water-68835077` (`neon orgs list -o json`, `neon projects list`). Free plan: 100 projects, 100 CU-hours/project/month, 0.5 GB/project, 6-hour restore, 10 branches, scale-to-zero after 5 min "cannot disable", and "when you run out of CU-hours … your compute is suspended until the next billing period or until you upgrade" — the repo is silent on plan limits, so this is from https://neon.com/docs/introduction/plans (fetched 2026-09-11). Pantry's branch shows `compute_time/active_time = 50085/193300 ≈ 0.26`, i.e. it runs at the 0.25 CU floor.

**The pantry rule.** CLAUDE.md:17: "No Docker, no local Supabase, no emulator. Development and schema verification run against Neon branches — the same stack as production"; specs/README.md:8: "there is no local database … in this workflow". Its object is Ambry's schema work — never verify Ambry migrations against anything but Neon — and the enforcement (guard-bash.mjs:36-45) blocks container and Supabase commands, not Postgres. A Multica store is another application's state, run by its own launchd job on port 5433 with no Ambry table; documented as such (a memory concept under `~/agents/memory/entities/`, no `localhost:5432`, nothing in pantry's `.env*`) it cannot be mistaken for a verification target.

**Verdict: (iii).** (i) becomes viable only on a paid Neon plan, and would still carry the 86 ms tax.

## 3. Auth and exposure

- **`APP_ENV=production`.** It is the switch that makes the server refuse a weak `JWT_SECRET` (main.go:287-292, :315-322) and ignore `MULTICA_DEV_VERIFICATION_CODE` (main.go:329-335). Compose pins it (docker-compose.selfhost.yml:100); `.env.example:40` leaves it empty for dev. A persistent instance has no reason to run any other way.
- **Codes: log, not Resend.** With neither `SMTP_HOST` nor `RESEND_API_KEY`, the code is printed `[DEV] Verification code for …` (email.go:349-355; SELF_HOSTING.md:92). Logins are rare — the CLI holds a 90-day token (CLI_AND_DAEMON.md:68), the browser a session cookie — so reading `~/agents/logs/multica-server.log` is fine. Reusing the Ambry `RESEND_API_KEY` would also need `RESEND_FROM_EMAIL` on a domain verified in that account; the default sender `noreply@multica.ai` (email.go:114-121) would be rejected. Defer.
- **Signup:** `ALLOWED_EMAILS` is checked before `ALLOW_SIGNUP` (auth.go:255-268) and existing users always log in (auth.go:245-247), so set `ALLOW_SIGNUP=false` **and** `ALLOWED_EMAILS=<Everett's address>` from the first boot — no bootstrap toggle dance. Leave `DISABLE_WORKSPACE_CREATION` empty; it only 403s `POST /api/workspaces` (SELF_HOSTING_ADVANCED.md:77).
- **Nothing needs to be reachable from outside.** The daemon dials out to `ws://localhost:8080/ws` (SELF_HOSTING_ADVANCED.md:210); the browser-login callback is an ephemeral `tcp4` loopback port (cmd_auth.go:245-256); the daemon's health port is loopback (health.go:88-95); agents (`claude`, `codex`, `hermes`, all on PATH here) are spawned locally.
- **No reverse proxy, no TLS.** The proxy is for "production" hostnames (SELF_HOSTING_ADVANCED.md:394); on `http://localhost:3000` cookies are correctly non-`Secure` (:148), `COOKIE_DOMAIN` stays empty (:146), the WebSocket origin check passes for localhost (:160). Reaching it from the MacBook over Tailscale would need `CORS_ALLOWED_ORIGINS`/`FRONTEND_ORIGIN` plus a Caddy for `/ws` or a rebuild with `NEXT_PUBLIC_WS_URL` (:556-561, :572-588) — an open question, not a day-one need.
- **Residual exposure:** the Go server listens on all interfaces (main.go:679), so 8080 is open to the LAN/tailnet as an authenticated surface (`APP_ENV=production` + `ALLOWED_EMAILS` + a 32-byte `JWT_SECRET`). Enabling the macOS application firewall closes it; `next start -H 127.0.0.1` keeps the web tier loopback-only.

## 4. Coexistence

- **Ports (lsof, read-only):** in use — ollama `127.0.0.1:11434`, Tailscale 43031/65138/49155, OrbStack helper ports only while its VM runs. **Free:** 3000, 8080, 6060, 9090, 19514, 5432, 5433. No clash with the runner, queue worker, Hermes (no TCP listener), Codex lanes, or Expo/Wrangler dev ports (8081/8787).
- **RAM:** the fleet rule is application memory, not count — 6–8 agents while free ≥ 25 % and compressed < 8 GB (feedback-agent-concurrency.md). Today: free 71 %, swap used 316 MB. Native Multica's ~0.5–1 GB fits; the OrbStack VM's ~4 GB would cut a wave by roughly a third.
- **launchd:** mirror `com.user.hermes.plist` — `/bin/bash -c` with a `PATH` export, `RunAtLoad`, `KeepAlive`, logs under `~/agents/logs/` — but source secrets from a mode-600 env file, not `EnvironmentVariables` (plists are 644). launchd has no ordering; the server retries the DB for up to 3 min at boot (main.go:373-387; `MULTICA_DATABASE_STARTUP_TIMEOUT`, compose:103), so `KeepAlive` covers Postgres starting later. Chain `migrate up && exec server` like the image entrypoint. Run the daemon `--foreground` (cmd_daemon.go:96) so launchd supervises it; it re-execs into a rebuilt binary when idle (CLI_AND_DAEMON.md:128-146).

## 5. Install runbook (option B + iii)

Never paste values; `~/agents/.env.multica` is mode 600 like `.env.acceptance`.

```bash
# 0. toolchain (brew update first — Homebrew 6.0.11 threw "undefined method 'stop_timeout'" parsing postgresql@17's service block)
brew update && brew install go pnpm postgresql@17

# 1. Postgres on 5433, loopback only
PG=/opt/homebrew/opt/postgresql@17/bin
$PG/initdb -D ~/agents/multica-pgdata -U multica_admin --auth=scram-sha-256 --pwprompt
printf "port = 5433\nlisten_addresses = '127.0.0.1'\n" >> ~/agents/multica-pgdata/postgresql.conf
# start via com.user.multica-postgres.plist (below), then:
$PG/psql -h 127.0.0.1 -p 5433 -U multica_admin -d postgres -c "CREATE ROLE multica LOGIN PASSWORD '<generate>';" \
  -c "CREATE DATABASE multica OWNER multica;"
$PG/psql -h 127.0.0.1 -p 5433 -U multica_admin -d multica -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto; CREATE EXTENSION IF NOT EXISTS pg_trgm;'

# 2. checkout + build (pin a tag; every upgrade repeats this block)
git clone https://github.com/multica-ai/multica.git ~/agents/multica && cd ~/agents/multica && git checkout v0.4.42
make build                                    # server/bin/{server,multica,migrate}
pnpm install --frozen-lockfile --filter @multica/web...
pnpm --filter @multica/web build
install -m 755 server/bin/multica ~/.local/bin/multica

# 3. env file: ~/agents/.env.multica (names only)
#   DATABASE_URL  JWT_SECRET (openssl rand -hex 32)  APP_ENV=production  PORT=8080
#   FRONTEND_ORIGIN=http://localhost:3000  MULTICA_APP_URL=http://localhost:3000
#   ALLOW_SIGNUP=false  ALLOWED_EMAILS  LOCAL_UPLOAD_DIR=/Users/orchestrator/agents/multica-data/uploads
#   MULTICA_VCS_SECRET_KEY (openssl rand -base64 32)  REMOTE_API_URL=http://localhost:8080
#   leave unset: RESEND_API_KEY SMTP_HOST MULTICA_DEV_VERIFICATION_CODE COOKIE_DOMAIN NEXT_PUBLIC_*
chmod 600 ~/agents/.env.multica

# 4. migrate once by hand (WorkingDirectory matters), then load the plists
set -a; . ~/agents/.env.multica; set +a; ./server/bin/migrate up
for j in postgres server web daemon; do launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.multica-$j.plist; done

# 5. daemon: one-time config + login (browser on the mini, or --token with a PAT)
multica setup self-host          # writes ~/.multica/config.json → localhost:8080/3000, logs in, starts daemon
launchctl kickstart -k gui/$(id -u)/com.user.multica-daemon   # hand it to launchd (--foreground in the plist)
```

**Plists** (`~/Library/LaunchAgents/com.user.multica-*.plist`, template: `com.user.hermes.plist`):

- `com.user.multica-postgres`: `/opt/homebrew/opt/postgresql@17/bin/postgres -D /Users/orchestrator/agents/multica-pgdata`; `KeepAlive`; logs `~/agents/logs/multica-postgres.{log,err}`.
- `com.user.multica-server`: `/bin/bash -c 'set -a; . "$HOME/agents/.env.multica"; set +a; cd "$HOME/agents/multica" && ./server/bin/migrate up && exec ./server/bin/server'`; `WorkingDirectory` `/Users/orchestrator/agents/multica`; `StandardOutPath` **required** (login codes); `KeepAlive`.
- `com.user.multica-web`: `/bin/bash -c 'export PATH="/opt/homebrew/bin:$PATH"; set -a; . "$HOME/agents/.env.multica"; set +a; export PORT=3000; cd "$HOME/agents/multica/apps/web" && exec pnpm start -- -H 127.0.0.1 -p 3000'` (Next reads `PORT` for its own listener; keep it out of the server's environment).
- `com.user.multica-daemon`: `/bin/bash -c 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"; exec multica daemon start --foreground'`; `KeepAlive`; logs `~/agents/logs/multica-daemon.{log,err}`.

**Smoke test:** `curl -s localhost:8080/health` → `{"status":"ok","pid":…,"commit":"…"}` (health.go:85-90); `curl -s localhost:8080/readyz` → `{"status":"ok","checks":{"db":"ok","migrations":"ok"}}` (SELF_HOSTING_ADVANCED.md:600-601); `curl -s localhost:3000/api/config` → JSON with `"allow_signup":false` (proves the Next→backend rewrite; router.go:1392, config.go:102); browser `http://localhost:3000` → login with the code from `multica-server.log` → **Settings → Runtimes** lists `m4-mini` (SELF_HOSTING.md:166); `multica daemon status` shows claude/codex/hermes detected.

**Rollback:** `launchctl bootout gui/$(id -u)/com.user.multica-{daemon,web,server,postgres}` → `rm ~/Library/LaunchAgents/com.user.multica-*.plist` → `pg_dump` if worth keeping → `rm -rf ~/agents/multica ~/agents/multica-pgdata ~/agents/multica-data ~/.multica ~/multica_workspaces ~/.local/bin/multica ~/agents/.env.multica` → optionally `brew uninstall postgresql@17 go pnpm`. Nothing else is touched; Neon and Ambry are never involved.

## Open questions for Everett

1. **Localhost-only, or reachable from the MacBook over Tailscale?** Localhost needs nothing; Tailscale needs `FRONTEND_ORIGIN`/`CORS_ALLOWED_ORIGINS` set to the tailnet origin and either Caddy in front (for `/ws`) or a web rebuild with `NEXT_PUBLIC_WS_URL`. Default taken: localhost-only.
2. **Upgrade cadence:** follow every tag (~every 2 days, 5–10 min rebuild each) or a weekly pinned bump in the 02:30 maintenance window? Default taken: weekly, pinned tag.
3. **Should the daemon's own Codex/Claude runs share the queue's concurrency budget?** `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` defaults to 20 (CLI_AND_DAEMON.md:260); on this box it should be 2–3 so Multica agents and queue agents together stay inside the 16 GB rule. Default taken: 2.
4. **Is a paid Neon plan on the table?** Only then does a separate Neon project become viable (and still ~86 ms/query). Default taken: no — local Postgres.
5. **Postgres backups:** add `pg_dump` of `multica` to the nightly `backup.sh` (into the vault repo is wrong — it is data, not knowledge); a local `~/agents/backups/` with 7-day rotation is the default taken.

## Sources

Repo (`~/agents/research/multica/src`, commit 51803b3): SELF_HOSTING.md:9-11, 46, 50, 89-97, 101, 139-147, 166, 461-466, 483-485 · SELF_HOSTING_ADVANCED.md:13-15, 23-24, 33, 39-40, 58, 74-77, 83-90, 101, 146-148, 156-160, 210-214, 244-247, 249-256, 258-261, 366-389, 394, 556-561, 572-588, 594-610, 600-601, 636-649, 669 · CLI_AND_DAEMON.md:68, 104-114, 122-126, 128-146, 237-241, 260, 264 · CLI_INSTALL.md:43, 76-83 · docker-compose.selfhost.yml:3-8, 37, 56, 61, 65, 72, 100, 103, 107, 204, 208, 211, 217-219 · docker-compose.selfhost.build.yml:5-20 · Makefile:43-64, 82-113, 338-342 · Dockerfile:2, 19-23, 26, 37, 39-44 · Dockerfile.web:2, 47, 50, 57-58, 75-78 · docker/entrypoint.sh:26-41 · scripts/install.sh:19, 314-331, 385-389, 406 · .env.example:37-45, 77, 386, 613-632 · .goreleaser.yml:6-9, 43-54 · .github/workflows/release.yml:123-125, 141, 240-242 · package.json:33-36 · .nvmrc · apps/web/package.json:7-9, 25 · apps/web/next.config.ts:15, 42, 67-94 · apps/web/proxy.ts:114-127 · apps/web/config/runtime-urls.ts:57-64, 102-108 · apps/web/app/layout.tsx:129-130 · packages/core/platform/core-provider.tsx:118 · deploy/helm/multica/values.yaml:64-70, 153-159, 187-193 · server/go.mod:3 · server/cmd/server/main.go:287-292, 303-309, 315-335, 337-340, 360-363, 373-387, 679, 809-822 · server/cmd/server/dbstats.go:38-39, 229-256 · server/cmd/server/runtime_sweeper.go:26, 224 · server/cmd/server/health.go:24, 73-90 · server/cmd/server/router.go:1313-1315, 1338, 1392, 1440 · server/internal/scheduler/manager.go:51, 124-125 · server/internal/handler/daemon.go:1207, 1252 · server/internal/handler/auth.go:244-276 · server/internal/handler/config.go:102 · server/internal/service/email.go:114-121, 349-355 · server/internal/profiling/server.go:9 · server/internal/daemon/config.go:69 · server/internal/daemon/health.go:88-95 · server/cmd/multica/cmd_auth.go:245-256 · server/cmd/multica/cmd_daemon.go:96 · server/cmd/migrate/main.go:761, 819-868 · server/internal/migrations/migrations.go:15-42 · server/migrations/001_init.up.sql:2, 032_issue_search_index.up.sql:3-9, 076_task_usage_pgcron_extension.up.sql:24-31, 137_search_index_pg_trgm_extension.up.sql:4 (grep: no `vector` in `server/migrations/`; 203 files use `CONCURRENTLY`).

Pantry: `/Users/orchestrator/code/pantry/CLAUDE.md:17` · `specs/README.md:8` · `.claude/settings.json:9` · `.claude/hooks/guard-bash.mjs:31-45` · `~/.claude/projects/-Users-orchestrator-code-pantry/memory/feedback-agent-concurrency.md` · `~/agents/memory/entities/neon-project.md` · `~/Library/LaunchAgents/com.user.hermes.plist`, `com.user.ollama.plist`.

Machine (read-only, 2026-09-11): `sw_vers` 26.6.2; `sysctl hw.memsize` 16 GiB, Apple M4; `node -v` 26.5.0; `command -v go pnpm corepack` missing; `brew --version` 6.0.11; `brew list --formula` libpq (18.4), node; `brew list --cask` orbstack; `brew info` go 1.27.1, pnpm 11.25.0, postgresql@17 17.11 keg-only; `orbctl version` 2.2.3; `orbctl config show` (memory_mib 8192, cpu 10, app.start_at_login false, docker.expose_ports_to_lan true); `ps` OrbStack Helper RSS 4,263 → 3,655 MiB; `~/.orbstack/log/vmgr*.log`; `launchctl list`; `lsof -nP -iTCP -sTCP:LISTEN`; `memory_pressure` 71 % free; `sysctl vm.swapusage`; `socketfilterfw --getglobalstate` disabled; `ifconfig` 10.0.0.74/44, 100.121.102.56; Python TCP connect to `ep-autumn-dew-a6utgshf.us-west-2.aws.neon.tech:5432` ×5, median 85.7 ms; `curl ipinfo.io` Short Pump, VA.

Neon: `npx neon@latest orgs list -o json` (plan `free`) · `projects list --org-id …` (one project, aws-us-west-2, PG 17) · `branches list --project-id red-water-68835077 -o json` (`compute_time_seconds` 50085, `active_time_seconds` 193300) · https://neon.com/docs/introduction/plans (fetched 2026-09-11 — repo silent on plan limits).

GitHub (read-only `gh`): `gh release view --repo multica-ai/multica` (v0.4.42, 2026-09-09, asset list) · `gh release list --limit 12`.
