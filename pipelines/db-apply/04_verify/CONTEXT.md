---
type: stage
title: 04_verify
description: Confirm production is live and correct, then merge the PR that depended on it.
tags: [pantry, database]
timestamp: 2026-09-10T00:00:00Z
---

# 04_verify

## Inputs
- Layer 4 (working): `../03_apply/output/apply-<date>.md`
- Layer 3 (reference): [Working conventions](../../../references/conventions.md)

## Process
1. Re-run the asserts against production; confirm the grant replay took.
2. Smoke the dependent surface — the screen or route that was broken before.
3. **Apply-before-merge**: only now merge the PR the client depended on.
4. Record the outcome in `memory/daily-log/<date>.md`, and fold anything durable
   into its concept file.

## Outputs
- `output/verify-<date>.md`; a merged PR; a daily-log entry.

## Verify
- Asserts `n/n` on production, after the replay.
- The PR merged **after** the apply, never before.
- If a fix was needed here that a contract should have prevented, amend the
  contract in this folder — not just this run's notes (SPEC.md I10).
