---
type: stage
title: 02_review
description: The human gate. Present the rehearsal evidence and stop until Everett says apply to production.
tags: [safety, database]
timestamp: 2026-09-10T00:00:00Z
---

# 02_review — HUMAN GATE

## Inputs
- Layer 4 (working): `../01_rehearse/output/rehearsal-<date>.md`

## Process
Present to Everett, in one message:
- which migrations, in which order;
- the assert counts, as `n/n` per file;
- what users see **until** it is applied (e.g. "Profile tab shows *Couldn't load
  your profile* until 0054 lands");
- what has to follow the apply — a grant replay, a Worker deploy, a PR merge.

Then **stop**. This is an edit surface: Everett may reorder, drop a file, or ask
for another rehearsal. Whatever he leaves is what stage 3 reads.

## Outputs
- `output/decision-<date>.md` — his words, quoted, with the date and time.

## Verify
Stage 3 does not start until `decision-<date>.md` records an explicit
**"apply to production"**. A green rehearsal is not consent. Silence is not
consent. A prior approval for a different migration is not consent.
