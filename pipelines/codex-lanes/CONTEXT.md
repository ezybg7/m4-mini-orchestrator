---
type: stage
title: Codex lanes pipeline
description: How Claude drives a Codex lane - write the task file, dispatch, adjudicate the output, land it.
tags: [tooling, pantry, workflow]
timestamp: 2026-09-10T00:00:00Z
---

# Codex lanes

**These contracts are read by Claude, not by Codex.** Codex cannot read this
workspace — `~/agents/**` is denied by its sandbox profile, deliberately, because
that tree holds `.env.acceptance`. Its own instructions live in the repo at
`~/code/pantry/AGENTS.md`, reachable from the worktree. Never add an `AGENTS.md`
here: [why](../../memory/decisions/no-agents-md-in-agents-workspace-2026-09-10.md).

So this pipeline is the **orchestrator's** side of the handoff. Claude owns
intent; Codex executes and attacks it. See [Model roles](../../references/model-roles.md).

| # | Stage | Owner |
|---|-------|-------|
| 1 | [`01_task_file`](01_task_file/CONTEXT.md) | Claude — the interface between the two models |
| 2 | [`02_dispatch`](02_dispatch/CONTEXT.md) | `lane.sh`, mechanical |
| 3 | [`03_adjudicate`](03_adjudicate/CONTEXT.md) | Claude — **the gate** |
| 4 | [`04_land`](04_land/CONTEXT.md) | Claude opens the PR; Everett merges |

The lane kind is a **parameter** of this sequence, not a separate pipeline:

| Lane | Use it for | Profile |
|------|-----------|---------|
| `review <base-ref>` | second-opinion review of a diff, incl. security | `pantry-review` |
| `hunt <area>` | exploratory bug/security hunt, read-only | `pantry-review` |
| `tests <task-file>` | test-gap finding; jest only, no source changes | `pantry-fix` |
| `implement <task-file>` | build a **merged** spec's §Acceptance | `pantry-fix` |
| `fix <task-file>` | one confirmed finding + its anchor test | `pantry-fix` |

**Deviation from ICM I6, recorded:** the numbering here is the handoff sequence,
which every lane follows. It is not a ranking of the lanes.

## Hard preconditions

- `codex/probe.sh` passes **14/14**. Required before the first run and after
  every `codex update`. A profile with a misspelled filesystem key loads without
  error and denies *nothing* — only running commands under the sandbox catches it.
- Codex is not cooling (`codex/.cooling` dated today means a 429 last run —
  proceed Claude-only and say so in the PR).
- `implement` requires a **merged** spec. Speculating from an unmerged spec is
  how a whole run gets wasted.

Related: [Codex](../../memory/entities/codex.md) ·
[Safety rules](../../references/safety-rules.md)
