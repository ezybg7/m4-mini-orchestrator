---
type: stage
title: Database apply pipeline
description: Rehearse a migration on a Neon branch, gate on Everett's explicit word, apply to production, verify.
tags: [pantry, database, safety]
timestamp: 2026-09-10T00:00:00Z
---

# Database apply

The most safety-critical pipeline here. Before this existed it was tribal
knowledge spread across a project note and two dated folders; every run risked
being reconstructed slightly differently.

| # | Stage | Gate |
|---|-------|------|
| 1 | [`01_rehearse`](01_rehearse/CONTEXT.md) | autonomous |
| 2 | [`02_review`](02_review/CONTEXT.md) | **HUMAN — hard stop** |
| 3 | [`03_apply`](03_apply/CONTEXT.md) | only past stage 2 |
| 4 | [`04_verify`](04_verify/CONTEXT.md) | autonomous, then merge |

**The gate is the point.** Stage 1 is fully autonomous — rehearse freely, as often
as you like. Stage 3 never runs without Everett's explicit "apply to production".
There is no phrasing of stage 1's success that authorizes stage 3.

**One branch, deliberately manual.** Rehearsal pass/fail is the one place this
pipeline branches. ICM §5.2 says automated mid-pipeline branching is where the
approach breaks down, so it is a human review gate, not a rule. See
[SPEC.md](../../SPEC.md) §8.1.

**Order matters.** Files apply in dependency order, `-1` per file, and every
assert must read ALL n PASSED. A partial pass is a failure.

Related: [Neon project](../../memory/entities/neon-project.md) ·
[Safety rules](../../references/safety-rules.md) ·
[Everett-only items](../../memory/projects/pantry-everett-only-2026-09-04.md)
