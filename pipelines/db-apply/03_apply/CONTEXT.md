---
type: stage
title: 03_apply
description: Apply the approved set to production, in the approved order, with the grant replay.
tags: [pantry, database, safety]
timestamp: 2026-09-10T00:00:00Z
---

# 03_apply

## Inputs
- Layer 4 (working): `../02_review/output/decision-<date>.md` — **required**
- Layer 4 (working): the approved migration files
- Layer 3 (reference): [Neon project](../../../memory/entities/neon-project.md)

## Process
`NEON_DIRECT_URL` from `~/agents/.env.acceptance` (mode 600). **Never print it,
never echo it, never let it reach a log or a chat message.**

Apply exactly the approved set, in the approved order, `-1` per file, then replay
`db/neon-grants.sql`. Nothing extra — a file that was not approved does not go in
because it happens to be ready.

## Outputs
- `output/apply-<date>.md` — timestamps, statement counts, assert results.

## Verify
- The set applied equals the set in `decision-<date>.md`. Exactly.
- Asserts `n/n` on production.
- The direct URL appears in no output, no log, and no message.
