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

**Configured, not integrated.** It has no Layer 0/1 entry of its own, does not
read the vault, and its five lanes are not stage contracts. [`AGENTS.md`](../../AGENTS.md)
now gives it the same door Claude uses; the rest is planned in
[the integration plan](../projects/plans/codex-icm-integration-plan.md).

The reason this integration is cheap: a sandbox with no network can still read a
folder of markdown. A knowledge format that needs an SDK or an API could not
cross that boundary at all.

Related: [Producers and consumers](../../references/tool-harmony.md) ·
[Working conventions](../../references/conventions.md)