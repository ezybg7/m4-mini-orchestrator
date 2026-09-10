---
type: reference
title: Machines & roles
description: Which box does what, what is installed where, and how the three machines sync.
tags: [infra, machines]
timestamp: 2026-09-03T00:00:00Z
---

# Machines & roles

Layer 3 reference. Used by [pantry](../memory/projects/pantry.md) and every task that touches more than one machine.

## Machines & roles (2026-09-03)

- **M4 Mac mini** (`m4-mini`, user `orchestrator`) — **primary workplace from 2026-09-03.** Hosts the orchestration: Hermes gateway (launchd `com.user.hermes`), the Claude worker queue (launchd `com.user.claude-worker` watching `~/agents/queue`), and cron — hc-ping every 10 min, `watchdog.sh` every 30 min, `backup.sh` 02:30 (commits + pushes `~/agents` to `ezybg7/m4-mini-orchestrator`, pushes `~/agents/skills` all branches), `nightly-reflection.sh` 03:00 (queues the reflect task), `pantry-weekly-maintenance.sh` Mon 09:00 (Dependabot triage + Apple-secret expiry watch).
- **MacBook** (user `ezy`, repo `~/Code/pantry`) — still in use. It is where Xcode, the simulator, Maestro and the EAS device loop live (the 08-30/31 smoke + acceptance runs happened there). `gh` is not installed there, so the GitHub MCP server is the PR interface on that machine; the repo CLAUDE.md is written from its point of view.
- **Windows box**: `C:\Users\evere\projects\pantry`.
- **Sync is GitHub only**: code via `ezybg7/pantry`, this vault via the nightly backup of `ezybg7/m4-mini-orchestrator`. Nothing else syncs between machines — `git pull` first, every session, on every machine.
