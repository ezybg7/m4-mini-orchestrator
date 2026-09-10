---
type: stage
title: 04_land
description: Claude runs the gates, commits and opens the PR. Everett merges.
tags: [tooling, pantry]
timestamp: 2026-09-10T00:00:00Z
---

# 04_land

## Inputs
- Layer 4 (working): the adjudicated diff
- Layer 3 (reference): [Working conventions](../../../references/conventions.md)
- Layer 3 (reference): [Safety rules](../../../references/safety-rules.md)

## Process
Run the gates yourself — root typecheck, workers typecheck, lint, jest. Codex
could not: no network, and `.git` read-only. Then branch, commit and open the PR
from the main checkout.

Attribute the work in the PR body: which lane ran, what it found, what was
rejected and why. A reviewer should not have to guess which model wrote what.

If Codex was cooling and the work proceeded Claude-only, say so.

## Outputs
- A branch and a PR. A daily-log entry. Anything durable folded into its concept.

## Verify
- All four gates green **before** the PR, not after.
- Apply-before-merge if a migration is involved — and the migration itself is
  Claude's work, never Codex's.
- The PR says which model produced the diff.
- **Everett merges.** Codex has no merge authority by construction; do not
  substitute your own.
