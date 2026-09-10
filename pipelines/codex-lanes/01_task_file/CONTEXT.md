---
type: stage
title: 01_task_file
description: Claude writes the task file - the only interface Codex gets, since it cannot read this workspace.
tags: [tooling, pantry]
timestamp: 2026-09-10T00:00:00Z
---

# 01_task_file

## Inputs
- Layer 3 (reference): [Model roles](../../../references/model-roles.md) — is this even Codex's work?
- Layer 3 (reference): the **merged** spec's §Acceptance (in the repo)
- Layer 4 (working): the diff, area, or finding this run is about

## Process
Write the task file. It is the **whole** interface: Codex sees this text, the
worktree, and the repo's own `AGENTS.md`. It cannot read this workspace, so
anything from Layer 3 that it needs must be quoted into the task file or already
present in the repo.

State the mode, name the files in scope, and give the acceptance criteria
verbatim from the spec. Do not paraphrase acceptance criteria — paraphrase is how
intent drifts between the two models.

If the task depends on a prior decision, cite where it is recorded so Codex can
check it. It is instructed to report a contradiction rather than build on a wrong
premise, and it can only do that if it can find the source.

## Outputs
- `output/task-<lane>-<date>.md`

## Verify
- The work is Codex's per [Model roles](../../../references/model-roles.md). If it
  touches migrations, RLS, grants, spec/ADR text, deps, deploys, secrets or
  merges — **stop**; that is Claude's, and handing it over is the error.
- The spec is **merged**, not proposed.
- Acceptance criteria are quoted, not summarized.
- `scripts/instruction-drift.py` reports no drift between the repo's `CLAUDE.md`
  and `AGENTS.md` — two instruction files with no drift check is the standard
  failure mode of a two-model setup.
