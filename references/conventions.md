---
type: reference
title: Working conventions
description: Model roles, the review loop, and the working rules code follows on this workspace.
tags: [conventions, workflow]
timestamp: 2026-09-05T00:00:00Z
---

# Working conventions

Layer 3 reference. Applies to every task in this workspace.

## Model roles (Everett, 2026-09-05)
Fable plans (PRDs, specs, review decisions, merges/ops). Opus 5 codes — every implementation, fix-round and test change is an `Agent` launch with `model: "opus"`. Fable never edits source files.

## Git and PR flow

- Branch → PR → **Everett merges**. Never self-merge to `main`.
  Exception: the pantry review loop merges on a clean adversarial pass (below).
- Code never waits on Everett (rule of 2026-08-30). Implementation goes through an
  adversarial agent review loop — review → fix everything → review again — and
  merges on a clean pass. Everett reviews PRDs and specs and runs device passes.
- **Apply-before-merge** for migrations the new client depends on.
- `site/updates.md` is appended at the end of every working session.
- Orchestrator and infra tooling never goes in the pantry repo — PR #101 was
  closed for exactly that. It lives in `~/agents`.

## Spec-first

Before building new functionality, write the spec first and keep it in the repo:
whole project → `SPEC.md`; individual feature → `specs/<feature>.md`. When
behavior changes, the spec changes in the same PR. Pure bug fixes and
behavior-preserving refactors need no new spec. → `~/.claude/CLAUDE.md`

## Session hygiene

- `git pull` first, every session, on every machine. GitHub is the only sync path.
- Work in `runs/<YYYY-MM-DD>-<slug>/`, never in the workspace root.
- End a task with a handoff note in
  [`memory/daily-log/`](../memory/daily-log/index.md) and any durable fact in its
  own concept file.
