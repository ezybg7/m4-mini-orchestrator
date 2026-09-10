---
type: reference
title: Model roles
description: 'Which system does which work: Claude owns intent, Codex owns execution and verification against it.'
tags: [conventions, tooling, workflow]
timestamp: 2026-09-10T00:00:00Z
---

# Model roles

Layer 3 reference. Read before deciding **who** should do a piece of work.

## Claude and Codex

The split is **intent versus execution**. Claude decides what should be true;
Codex builds it and attacks it.

| Work | Owner |
|------|-------|
| PRDs — writing them, and re-reviewing them | **Claude** |
| Specs — writing, reviewing, amending | **Claude** |
| Adjudicating findings; running the gates; commits; PRs | **Claude** |
| Implementing a merged spec's §Acceptance | **Codex** |
| Code review of a diff | **Codex** |
| Security findings | **Codex** |
| Test-gap finding and writing tests | **Codex** |

Codex has **no merge authority, by construction**: its sandbox keeps `.git`
read-only inside a writable worktree and gives child commands no network, so
`git commit`, `git push`, `gh` and `wrangler` cannot succeed even if attempted.
Its output is a diff or a queue of findings. A human-reviewed Claude PR is the
only path to `main`.

Codex must never touch: migrations, RLS policies or grants; spec and ADR text;
dependency moves; the simulator or Maestro; Worker deploys; secrets; merges. If a
task appears to need one, stopping and saying so is the **correct** outcome.

**Why the boundary sits there.** A spec is a statement of intent, and the system
that wrote the intent is the worst one to certify that the code matches it. Codex
reviewing Claude's implementation, and Claude adjudicating Codex's findings, is
the only arrangement where neither marks its own homework.

Corollary, from spec 56: **never take a premise on faith.** If a task states a
prior decision and the repo says otherwise, report the contradiction rather than
building on it. This binds both directions.

## Claude models (Everett, 2026-09-05)

Fable plans (PRDs, specs, review decisions, merges/ops). Opus 5 codes — every implementation, fix-round and test change is an `Agent` launch with `model: "opus"`. Fable never edits source files.

Related: [Working conventions](conventions.md) ·
[codex-lanes](../pipelines/codex-lanes/CONTEXT.md) ·
[Codex](../memory/entities/codex.md)
