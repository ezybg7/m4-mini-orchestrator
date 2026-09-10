---
type: stage
title: 01_survey
description: Read the day's logs and identify repeated procedures, failures and near-misses.
tags: [infra, skills]
timestamp: 2026-09-10T00:00:00Z
---

# 01_survey

## Inputs
- Layer 4 (working): `~/.hermes/logs/` — gateway, curator, parks
- Layer 4 (working): `~/agents/logs/` — worker-runner, errors, ci-triage, watchdog
- Layer 4 (working): `~/agents/queue/done/`, `~/agents/queue/failed/`
- Layer 3 (reference): `~/agents/skills/` — what is already documented

## Process
Identify **only what post-dates the previous nightly run.** For each finding,
record the evidence line that supports it — a log timestamp, a count, a filename.
A finding with no evidence line is not a finding.

Classify each: repeated procedure (→ a skill), failure, or near-miss.

## Outputs
- `output/findings-<YYYY-MM-DD>.md` — one bullet per finding, each with its
  evidence. **Dated**: an undated name lets a later run read a previous run's
  evidence and act on it as if it were tonight's.
  Write "No findings; idle night." and stop if that is the truth.

## Verify
Every bullet cites a log line or count. No bullet restates something already in a
`SKILL.md` — that is not new.
