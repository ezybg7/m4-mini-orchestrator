---
type: stage
title: 01_rehearse
description: Reset a disposable Neon branch from production and apply the migration set on it in order.
tags: [pantry, database]
timestamp: 2026-09-10T00:00:00Z
---

# 01_rehearse

## Inputs
- Layer 4 (working): the migration files, in dependency order
- Layer 4 (working): `db/neon-grants.sql` from the PR branch
- Layer 3 (reference): [Neon project](../../../memory/entities/neon-project.md)
- Layer 3 (reference): [Safety rules](../../../references/safety-rules.md)

## Process
1. Reset a disposable Neon branch from production. Note its id, endpoint and
   expiry — branches auto-delete.
2. psql the **direct** endpoint (drop `-pooler`) as `neondb_owner`,
   `-v ON_ERROR_STOP=1 -1` **per file**.
3. Apply in dependency order, then replay `db/neon-grants.sql` — Neon applies no
   default privileges, so every migration ships its own GRANTs.
4. Re-run each file's asserts after the grant replay.

Never touch the production endpoint in this stage.

## Outputs
- `output/rehearsal-<date>.md`: branch id and expiry, apply order, assert counts
  as `n/n`, timings, and anything that needed a retry.

## Verify
- Every assert reads **ALL n PASSED**. Any partial → this stage failed; fix the
  migration and rehearse again. Do not proceed.
- The grant replay ran **after** the DDL and the asserts ran **after** the replay.
