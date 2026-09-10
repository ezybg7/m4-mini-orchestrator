---
type: decision
title: No AGENTS.md in ~/agents or above it
description: 2026-09-10 - an AGENTS.md at the workspace root breaks every Codex invocation
  under ~/agents, including its safety gate.
tags:
- tooling
- infra
- safety
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/decisions/no-agents-md-in-agents-workspace-2026-09-10
---

# No AGENTS.md in `~/agents` or above it (2026-09-10)

**Decision.** `~/agents` must not contain an `AGENTS.md`, and neither may any
directory above it. Codex's instruction file belongs in the repository it works
on — `~/code/pantry/AGENTS.md`.

**Why.** Codex walks up from its working directory for the nearest `AGENTS.md`
at session start. Its own sandbox profiles deny `/Users/orchestrator/agents/**`
(deliberately — that tree holds `.env.acceptance`, a Neon owner connection
string). So an `AGENTS.md` there is a file Codex is required to read and
forbidden to read, and it fails fatally:

```
Error: Fatal error: Failed to initialize session: failed to load AGENTS.md
instructions for environment `local`: Operation not permitted (os error 1)
```

**How it was found.** One was added at the workspace root on 2026-09-10, on the
mistaken assumption that it would give Codex the same Layer 0 entry Claude has.
It cannot: the lanes run `codex exec -C <worktree>` and `~/agents` is denied. The
breakage surfaced when `codex/probe.sh` — the mandatory sandbox gate — died at
its precondition, so the failure mode is worse than it first looks: **it takes
down the check that would catch other sandbox problems.** Removing the file
restored `codex debug prompt-input` and probe.sh went 14/14.

**Consequence.** `scripts/okf-check.py` no longer expects an `AGENTS.md`, and
carries a comment saying why. If a shared entry point for another runtime is ever
wanted, it must not use that reserved filename.

**Related prior warning.** Spec 56 already cautioned that `AGENTS.md` must not be
a symlink or import of `CLAUDE.md` — CLAUDE.md tells its reader to open PRs and
merge, which Codex must never do, and a copy becomes a second undrifted home for
ADR-owned rules (recorded [2026-09-07](../daily-log/2026-09-07.md)). Same
direction: that filename is Codex's, and it belongs to the repo.

Related: [Codex](../entities/codex.md) ·
[codex-lanes](../../pipelines/codex-lanes/CONTEXT.md) ·
[Producers and consumers](../../references/tool-harmony.md)