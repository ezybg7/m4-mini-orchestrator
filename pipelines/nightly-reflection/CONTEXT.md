---
type: stage
title: Nightly reflection pipeline
description: Cron 03:00 - survey the day's logs, refine skills on a branch, fold old daily-logs, report.
tags: [infra, skills, memory]
timestamp: 2026-09-10T00:00:00Z
---

# Nightly reflection

Runs at **03:00 daily** via cron → `scripts/nightly-reflection.sh`, which queues
one task for `claude-worker`. This folder is the source of truth for what that
task does; the script only schedules it.

| # | Stage | Writes |
|---|-------|--------|
| 1 | [`01_survey`](01_survey/CONTEXT.md) | `01_survey/output/findings.md` |
| 2 | [`02_skills`](02_skills/CONTEXT.md) | branch `nightly-<date>` in `~/agents/skills` |
| 3 | [`03_memory_fold`](03_memory_fold/CONTEXT.md) | moved files in `memory/daily-log/archive/` |
| 4 | [`04_report`](04_report/CONTEXT.md) | `memory/daily-log/<date>.md` |

**Review gates.** Stage 2 pushes but **never merges** — Everett merges the branch
chain (see [safety rules](../../references/safety-rules.md)). Stage 3 leaves the
vault **staged, not committed**; the 02:30 backup commits it.

**Honesty rule, load-bearing.** An idle day is a valid outcome. If the survey
finds nothing new, stage 2 writes nothing rather than inventing an edit. The log
has recorded 13-night idle streaks — that is the system working.

Related: [claude worker queue](../../memory/entities/claude-worker-queue.md)
