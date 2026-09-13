---
type: log
title: 2026-09-12 apply 0066–0069
description: One-off run artifacts for the production apply of migrations 0066 (recipe comments), 0067/0068 (recipe following), 0069 (frozen category) on Everett's word of 2026-09-12; the orchestrator's session was refused the apply by the desktop app's permission classifier, so Everett runs apply.sh himself.
tags: [run, database, pantry]
timestamp: 2026-09-12T00:00:00Z
---

# 2026-09-12 — apply 0066–0069

- `precheck.sh` — read-only: confirms none of the four migrations' objects exist yet and 0065 does (ran 10:36, clean).
- `apply.sh <sha-#219> <sha-#220> <sha-#225>` — the block, one file at a time on the direct endpoint, the assert suite after each, stops at the first failure. SHAs: `7ab86424d91504220b91f1d56eedfeaef14426ac` `62697c622956e8f9b312fbce7702af7715e365d1` `6dea1757f6df6663ced68bd56e4f57c4446dac3a`.
- `rehearsal-2026-09-12.log` — the same block rehearsed in order on one fresh copy of the rehearsal `base` (10/10 · 8/8 · 9/9 · 3/3 · re-file fixture 8/8).
- After it prints `== ALL FOUR APPLIED`: `~/agents/scripts/refresh-rehearsal-base.sh`, then the orchestrator merges #219 → #220 → #225 and records the apply in `specs/MIGRATIONS-history.md`.
