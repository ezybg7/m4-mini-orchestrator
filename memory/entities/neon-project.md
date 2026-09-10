---
type: entity
title: Neon Postgres project
description: Production endpoints, the branch workflow, and the pooler-vs-direct distinction
  that migrations depend on.
tags:
- pantry
- database
- infra
timestamp: 2026-09-05 00:00:00+00:00
permalink: agents/entities/neon-project
---

# Neon Postgres project

Project `red-water-68835077`.

- **Production Data API host**:
  `ep-autumn-dew-a6utgshf.apirest.us-west-2.aws.neon.tech`.
  **Drop `-pooler` for psql and DDL** — migrations run on the *direct* endpoint.
- **Direct URL** for production lives in `~/agents/.env.acceptance` as
  `NEON_DIRECT_URL` (mode 600). **Never print it.**
- **Branch workflow**: rehearse every migration on a throwaway branch first
  (e.g. `acceptance-2026-09-03` = `br-damp-art-a6r6pyld`, endpoint
  `ep-still-sun-a6sf0f5w`). Branches auto-delete; reset from production before a
  rehearsal. `scripts/neon-branch-keepalive.mjs` keeps one warm.
- **Apply style**: psql on the direct endpoint, `-v ON_ERROR_STOP=1 -1` per file,
  asserts must read ALL n PASSED.
- **Grants**: every migration ships its own GRANTs — Neon applies no default
  privileges. `db/neon-grants.sql` restates them idempotently; `recipes` grants
  are column-scoped since 0050.

Related: [db-apply pipeline](../../pipelines/db-apply/CONTEXT.md) ·
[Everett-only items](../projects/pantry-everett-only-2026-09-04.md)