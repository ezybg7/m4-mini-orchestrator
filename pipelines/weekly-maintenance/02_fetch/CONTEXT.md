---
type: stage
title: 02_fetch
description: Refresh the checkout so triage judges the real current main.
tags: [pantry, infra]
timestamp: 2026-09-10T00:00:00Z
---

# 02_fetch

## Inputs
- Layer 4 (working): the pantry checkout

## Process
`git fetch --prune`; log the new `origin/main` sha.

## Outputs
- The sha, in the weekly log.

## Verify
The sha is newer than or equal to last week's. If it is older, the checkout is
wrong — stop; do not triage against a stale main.
