---
type: entity
title: Claude worker queue
description: The launchd-watched task queue that runs headless Claude sessions on
  the mini.
tags:
- infra
- memory
timestamp: 2026-09-09 00:00:00+00:00
permalink: agents/entities/claude-worker-queue
---

# Claude worker queue

launchd `com.user.claude-worker`, watching `~/agents/queue`.

- **Enqueue**: drop a `<name>.task` file in `~/agents/queue/`, then call
  `scripts/claude-worker.sh`.
- **Standing context**: `queue/.preamble.md` is prepended to every queued task.
  It is Layer 3 material — edit it there, not in individual tasks.
- **Lifecycle**: finished tasks move to `queue/done/` or `queue/failed/`. They are
  **not** renamed in place — the old `done-<name>.task` scheme re-enqueued
  finished work on the next glob and re-ran a whole reflect job (fixed 2026-07-19;
  do not reintroduce it).
- **Job classes seen**: nightly `reflect-<date>`, `ci-triage` (since 2026-09-08),
  ad-hoc delegations.
- **Auth**: exports `CLAUDE_CODE_OAUTH_TOKEN` from `~/.claude/oauth_token`; cron
  jobs that call `claude -p` must do the same or they fail "Not logged in".

Related: [nightly-reflection pipeline](../../pipelines/nightly-reflection/CONTEXT.md) ·
[Machines & roles](../../references/machines.md)