---
title: 0070 claim_ai_call pools — production apply (AMBR-57, PR #256)
type: run
date: 2026-09-14
status: applied 2026-09-15 — 0070 on production, #256 merged 3ffebf78, base refreshed
description: Rehearsal record and the dry-run + apply scripts for migration 0070 (spec 23 wave A), run from Everett's seat after PR #255's Worker deploy; expectations and the follow-up steps.
tags: [production-apply, migration, ambr-57, neon]
timestamp: 2026-09-14T06:45:00-04:00
---

# 0070 claim_ai_call pools — production apply

AMBR-57 (the 0070 build) was approved by the review squad in round 2 (three Low, non-blocking).
PR #255 (Worker limits, inert against 0043) is merged as `54436cf8`; PR #256 carries the migration
and waits, apply-before-merge.

**Order is load-bearing (spec 23 §Migrations 0070 §Order, round-1 FIND-001):** #255 merged → the
Worker **deployed** (Everett's `cd ~/code/pantry/workers && npm run deploy` — wrangler is a local devDependency, a bare `wrangler` is not on PATH) → 0070 applied → #256 merged.
`shelfLife.ts` on `main` passes `0, 0` as shelf-life's monthly limits: inert while that pool is
null under 0043, a kill switch once 0070 gives the pool a real limit — so the Worker must be on
the new limits before the pool exists.

Rehearsed by the orchestrator 2026-09-14 06:44 on a fresh copy of `base` (`rehearse.sh`):
migration in one transaction · `ALL 16 ASSERTIONS PASSED` · main's grants replay (137 statements)
· `ALL 16 ASSERTIONS PASSED` again · the dry-run shape (begin; migration; assert file) ended in
`ROLLBACK` with 16/16 · copy dropped. The implementer had rehearsed it twice plus a negative
control (pre-0070 function reproduces the L9 bug). Not covered by a rowless copy: existing
`ai_calls` rows and the advisory lock under concurrency (pinned as text, G16).

From Everett's seat (the desktop app's classifier denies production commands from the orchestrator):

1. Deploy the Worker from `main` (#255 is in it).
2. `bash ~/agents/runs/2026-09-14-apply-0070/dryrun.sh` — expects the last line
   `== DRY RUN OK: 0070 applies on production and 16/16 assertions pass — rolled back, nothing persisted`.
3. `bash ~/agents/runs/2026-09-14-apply-0070/apply.sh` — expects `ALL 16 ASSERTIONS PASSED`, two `true` lines
   for the live function and constraint, and the last line `== 0070 APPLIED — say "0070 applied" …`.
4. Say "0070 applied". The orchestrator then merges #256 (after its mechanical rebase round),
   records it in `specs/MIGRATIONS.md` / `MIGRATIONS-history.md`, runs
   `~/agents/scripts/refresh-rehearsal-base.sh`, and moves AMBR-57 to done.

Both scripts take the migration and the assert file from the PR branch at run time, refuse a pooler
URL, refuse a migration whose sha256 differs from the reviewed `f8c4357c59abf5a1…`, and never print
the connection string. The free-tier numbers stay as today until the RevenueCat turn-on flips them.

**Correction 2026-09-15 10:10 (orchestrator scratch-2026-09-12-5f6cc5, append-only):** step 1 above says "Everett's `wrangler deploy` from `workers/`" — a bare `wrangler` is not on Everett's PATH (it is a local devDependency; his first try ended `zsh: command not found: wrangler`, so nothing was deployed or applied). The command is `cd ~/code/pantry/workers && npm run deploy` (`package.json` script `deploy: wrangler deploy`; the checkout is at main `eaf4026f`). Same wording now on the token-review page t8 and the board handoff page.

**Applied 2026-09-15 (orchestrator):** Everett ran the sequence — deploy `69d68747`, dry run OK (16/16, rolled back), apply OK (16/16, both live checks `true`); #256 merged `3ffebf78`; ledger `0edd8cfd`; `base` refreshed. The first dry-run attempt died on the `$S…` bash quirk before any SQL ran; both scripts were braced and re-tested on a rehearsal copy before the retry.
