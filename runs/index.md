---
type: index
title: runs
description: Layer 4 - per-run working artifacts, disposable; the area is kept even when empty because CONTEXT.md routes one-offs here.
tags: [index, runs]
timestamp: 2026-09-12T00:00:00Z
---

# runs

Layer 4. One folder per run, `<date>-<slug>/`, holding that run's scaffolding — never a
durable fact (those go to `memory/` as concept files). Disposable by design.

Everything that lived here before 2026-09-12 was moved to `_archive/2026-09-12/` when the
local task queue was retired (board card AMBR-26); the Multica board's own runs live in
Multica, not on this filesystem. The area stays so that `CONTEXT.md`'s "one-off with no
pipeline" route still has a home.

## Runs

- [2026-09-12 apply 0066–0069](2026-09-12-apply-0066-0069/index.md) — the production apply of the recipe-comments, recipe-following and frozen-category migrations, run by Everett from `apply.sh` after the orchestrator's session was refused the command.
- [2026-09-12 design tour](2026-09-12-design-tour/index.md) — a repeatable Maestro screenshot tour of every reachable Ambry screen on the iPhone 17 Pro simulator, in light, dark and largest-accessibility-text, against a disposable Neon branch, for the orchestrator's HIG review.
- [2026-09-12 USDA tranche 2 apply (AMBR-34)](2026-09-12-apply-usda-t2/index.md) — staged dry run + apply for Everett's seat
