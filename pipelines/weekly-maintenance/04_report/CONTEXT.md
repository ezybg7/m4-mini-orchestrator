---
type: stage
title: 04_report
description: One summary line to the weekly log.
tags: [infra]
timestamp: 2026-09-10T00:00:00Z
---

# 04_report

## Inputs
- Layer 4 (working): stages 1-3 outputs

## Process
Append one line to `~/agents/logs/pantry-weekly.log`: date, `origin/main` sha,
secret days-remaining, and the merged / closed / escalated / skipped counts.

## Outputs
- One line in the weekly log.

## Verify
The line exists for every Monday. A missing Monday means cron missed the slot
while the mini slept — cron does not catch up; launchd `StartCalendarInterval`
would. Only worth switching if weeks go missing.
