---
type: entity
title: Codex
description: Second agent runtime with five pantry lanes; sandboxed with no network.
  Configured but not yet wired into the workspace protocol.
tags:
- tooling
- pantry
- infra
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/entities/codex
---

# Codex

Canonical config `~/agents/codex/config.toml`, installed to `~/.codex/config.toml`.
Spec 56 (`specs/codex-qa-lane.md`) in the pantry repo. `gpt-5.6-sol`,
reasoning effort high, `approval_policy = "never"`, web search disabled,
history persistence off.

## Lanes

`~/agents/codex/lane.sh <lane>` — `review <base-ref>`, `implement <task-file>`,
`tests <task-file>`, `hunt <area>`, `fix <task-file>`.

The wrapper exists because **Codex's sandbox has no network**, so dependency
installs must happen outside it.

## The config trap, worth repeating

Verified against codex-cli 0.153.2 on 2026-09-07: only `default_permissions` and
`extends` are statically validated. **Everything else is silently ignored if
misspelled** — `access = "bogus-value"` and invented field names both load
without error, so a typo in a `file_system` entry yields a profile with *no
denial* that looks correct on review. `~/agents/codex/probe.sh` is therefore a
hard gate before the first real run and after every `codex update`. Static review
cannot substitute for it.

## Status here

**Validated 2026-09-10**: `probe.sh` passes **14/14** on codex-cli 0.153.2 —
every sandbox denial holds, `git commit` is blocked inside the worktree, network
is off, and `.env.acceptance` and `oauth_token` are unreadable under both
profiles. The canonical config matches the installed one.

**It cannot read `~/agents` — that is deliberate and must stay.** The profiles
deny `/Users/orchestrator/agents/**` because that tree holds `.env.acceptance`
(a Neon owner connection string). Codex's instruction file is
**`~/code/pantry/AGENTS.md`**, inside the repo, reachable from the worktree.

**Do not put an `AGENTS.md` in `~/agents` or above it.** Codex walks up for the
nearest one at session start; finding one it is denied makes it fail fatally
("failed to load AGENTS.md instructions for environment `local`"), which takes
`probe.sh` down with it. → [the decision](../decisions/no-agents-md-in-agents-workspace-2026-09-10.md)

Claude drives the lanes through [codex-lanes](../../pipelines/codex-lanes/CONTEXT.md);
`lane.sh` stages any Layer 3 context into the worktree, outside the sandbox.

Related: [Producers and consumers](../../references/tool-harmony.md) ·
[Working conventions](../../references/conventions.md)