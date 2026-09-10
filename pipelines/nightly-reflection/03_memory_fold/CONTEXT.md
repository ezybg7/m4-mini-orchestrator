---
type: stage
title: 03_memory_fold
description: Fold daily-logs older than 7 days into the concepts they belong to, then archive them.
tags: [memory]
timestamp: 2026-09-10T00:00:00Z
---

# 03_memory_fold

## Inputs
- Layer 4 (working): `~/agents/memory/daily-log/*.md` older than 7 days
- Layer 3 (reference): `~/agents/memory/projects/`, `decisions/`, `entities/`
- Layer 3 (reference): [SPEC.md](../../../SPEC.md) §2.1 — OKF rules

## Process
For each log strictly older than 7 days, fold each durable fact into the concept
it belongs to. **The vault is one-concept-per-file now** — fold to the specific
file, not to the hub:

| The fact is about | Fold into |
|---|---|
| Ambry status, Everett's plate | `projects/pantry.md` |
| stack, versions, env, CI gates | `projects/pantry-stack.md` |
| a trap, a workaround, a toolchain quirk | `projects/pantry-gotchas.md` |
| something now closed | `projects/pantry-retired.md` |
| a choice made, with a why | a **new** file in `decisions/` |
| a machine, repo, or service | `entities/` |

A fact already present elsewhere is a **verified no-op fold** — say so and move on.
Then `git mv` the log to `daily-log/archive/`.

New files need OKF frontmatter (`scripts/okf-normalize.py` fills it) and a link
from the enclosing `index.md` (`scripts/okf-index.py` regenerates it).

## Outputs
- Updated concept files; the log moved to `daily-log/archive/`.

## Verify
- `scripts/okf-check.sh` exits 0.
- Nothing lost: every durable fact in the folded log is findable in the vault.
- Left **staged, not committed** — the 02:30 backup commits.
