---
type: stage
title: Weekly maintenance pipeline
description: Monday 09:00 - Apple secret expiry watch, fetch, Dependabot triage, report.
tags: [pantry, infra, security]
timestamp: 2026-09-10T00:00:00Z
---

# Weekly maintenance

Monday 09:00 via cron → `scripts/pantry-weekly-maintenance.sh`.

| # | Stage | Why the order |
|---|-------|---------------|
| 1 | [`01_secret_expiry`](01_secret_expiry/CONTEXT.md) | **first** — it must run even if everything after it fails |
| 2 | [`02_fetch`](02_fetch/CONTEXT.md) | ground truth before judging PRs |
| 3 | [`03_dependabot_triage`](03_dependabot_triage/CONTEXT.md) | the reading job |
| 4 | [`04_report`](04_report/CONTEXT.md) | one line to the log |
| 5 | [`05_instruction_drift`](05_instruction_drift/CONTEXT.md) | report-only; accepting a baseline stays manual |

The runbook that preceded this already had the right instinct — *"everything
policy-shaped is in the prompt inside the script, not in bash — deciding whether
a bump is a security fix or fights the Expo pin is a reading job, not a regex."*
That is ICM's split between `scripts/` and a stage contract. The policy now lives
here, where it can be edited without touching the script.

The full prose runbook is [`references/runbook.md`](references/runbook.md).

Related: [Ambry stack](../../memory/projects/pantry-stack.md) ·
[Safety rules](../../references/safety-rules.md)
