---
title: USDA nutrition tranche 2 — production apply (AMBR-34, PR #231)
type: run
date: 2026-09-12
status: staged — waits on Everett's seat
description: Dry run and apply scripts for the ten-statement USDA tranche 2 file (PR #231), run from Everett's seat; expectations and the follow-up steps.
tags: [production-apply, usda, ambr-34, neon]
timestamp: 2026-09-12T13:10:00-04:00
---

# USDA nutrition tranche 2 — production apply

Decision 2 on the 2026-09-12 handoff page: **option 2** — the ten FNDDS matches only (nine new
fills plus the Sorbet re-match); the nine representative-entry proposals stay null. PR #231
(head `b8543645`) was approved by the review squad in round 3 (two Low doc notes, non-blocking).

Apply-before-merge, from Everett's seat (the desktop app's classifier denies production
commands from the orchestrator's):

1. `bash ~/agents/runs/2026-09-12-apply-usda-t2/dryrun.sh` — runs the file with `commit;` → `rollback;`
   on the direct production endpoint; expects `DRY RUN MATCHES EXPECTATION (+9 usda, −9 null, ten UPDATE 1)`.
2. `bash ~/agents/runs/2026-09-12-apply-usda-t2/apply.sh` — the real apply; expects `TRANCHE 2 APPLIED`,
   prints the counts line and the Sorbet panel (`usda · kcal 110`).
3. Say "tranche 2 applied" and paste the counts line. The orchestrator then merges #231, records the
   measured counts in `specs/MIGRATIONS.md` / `specs/MIGRATIONS-history.md` (with the two Low sentences
   from the review), runs `~/agents/scripts/refresh-rehearsal-base.sh`, and closes AMBR-34 and AMBR-15.

Both scripts refuse a pooler URL, refuse a file with other than exactly one `commit;` line, and never
print the connection string.
