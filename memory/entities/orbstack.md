---
type: entity
title: OrbStack on the mini
description: Container runtime that IS installed on the M4 mini (cask, v2.2.3) but normally
  stopped; any orbctl call boots its ~4 GiB VM, so probe the socket file instead.
tags:
- m4-mini
- infra
- multica
timestamp: 2026-09-11 00:00:00+00:00
permalink: agents/entities/orbstack
---

# OrbStack on the mini

Verified 2026-09-11 while researching Multica hosting (brief:
`~/agents/research/multica/hosting.md`). Corrects the earlier record that the
mini has "no container runtime": it has one, it is just off.

## Facts

- `/usr/local/bin/docker` → `/Applications/OrbStack.app/Contents/MacOS/xbin/docker`
  (symlink, Aug 23); `/usr/local/bin/orbctl` 2.2.3; `brew list --cask` → `orbstack`;
  privileged helper `/Library/LaunchDaemons/dev.orbstack.OrbStack.privhelper.plist` (Jul 17).
- Config (`orbctl config show`): `memory_mib: 8192`, `cpu: 10`,
  `app.start_at_login: false`, `docker.expose_ports_to_lan: true`.
- The VM had been stopped since 2026-09-03 17:45 (`~/.orbstack/log/vmgr.1.log`).
  This is why pantry's Docker MCP gateway (`.mcp.json`) reports CONNECTION_CLOSED.
- **Measured cost while up:** helper `vmgr` RSS 4,263 MiB thirty seconds after
  boot, 3,655 MiB after ~20 min idle with no user containers.

## Operating rule

- **Any `orbctl` invocation — even `status`, `version`, `config show` — starts the
  helper and boots the VM.** Read-only check: `ls ~/.orbstack/run/docker.sock`
  (present ⇒ running). Stop with `orbctl stop`.
- The pantry guard hook blocks `docker …` (not `docker mcp`) in pantry sessions
  (`.claude/hooks/guard-bash.mjs:40-41`); `orbctl` is not blocked.
- Decision taken for Multica: do not depend on it — native launchd services
  instead (see the brief). The VM's ~4 GiB is fleet headroom
  ([agent concurrency rule](../../../.claude/projects/-Users-orchestrator-code-pantry/memory/feedback-agent-concurrency.md)).

Related: [Machines & roles](../../references/machines.md) ·
[Neon Postgres project](neon-project.md)
