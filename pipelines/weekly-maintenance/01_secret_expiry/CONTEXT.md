---
type: stage
title: 01_secret_expiry
description: Warn on the Apple client secret before anything that can fail runs.
tags: [security, pantry]
timestamp: 2026-09-10T00:00:00Z
---

# 01_secret_expiry

## Inputs
- Layer 3 (reference): expiry **2027-02-18**, key id `YK8V7A579F`
- Layer 3 (reference): `scripts/apple-client-secret.mjs` (in the pantry repo)

## Process
Runs **first**, before anything that can fail. Compute days remaining; under 30,
warn and print the exact regeneration commands into the log.

Dependabot cannot see this — it is a signed ES256 JWT with a hard 6-month expiry,
not a package. Nothing else in the system will notice it lapsing.

## Outputs
- A line in `~/agents/logs/pantry-weekly.log`.

## Verify
The line is present for **every** run, including runs where nothing else happened.
Its absence means the job died before stage 1 — investigate that, not the PRs.
