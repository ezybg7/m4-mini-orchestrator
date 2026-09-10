---
type: stage
title: 04_report
description: Append a short, honest summary of the night to today's daily-log.
tags: [memory]
timestamp: 2026-09-10T00:00:00Z
---

# 04_report

## Inputs
- Layer 4 (working): `../01_survey/output/findings.md`
- Layer 4 (working): what stages 2 and 3 actually did

## Process
Append a `## Nightly reflection` section to
`~/agents/memory/daily-log/<YYYY-MM-DD>.md`: SKILLS, infra, MEMORY, then standing
carry-overs that are **not** yours to action.

State idle nights as idle. Name the streak.

## Outputs
- `memory/daily-log/<date>.md`, ~5 bullets.

## Verify
Every claim traces to stage 1's evidence or to a command this run actually ran.
No claim rests on memory of an earlier night.
