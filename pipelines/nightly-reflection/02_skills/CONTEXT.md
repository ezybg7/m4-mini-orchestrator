---
type: stage
title: 02_skills
description: Turn findings into SKILL.md refinements on a dated branch. Push, never merge.
tags: [skills]
timestamp: 2026-09-10T00:00:00Z
---

# 02_skills

## Inputs
- Layer 4 (working): `../01_survey/output/findings.md`
- Layer 3 (reference): existing `~/agents/skills/*/SKILL.md`

## Process
Branch `nightly-<YYYY-MM-DD>` off the previous night's branch (verify the chain
with `git merge-base --is-ancestor`). Refine or create `SKILL.md` files from the
findings. Commit with messages that name the evidence.

**If `findings.md` says idle: make no edits.** Do not manufacture a commit to
have something to show.

## Outputs
- Pushed branch `nightly-<date>` in `~/agents/skills`.

## Verify
- The branch chain is unbroken back to the previous night.
- **Not merged, no PR.** Everett merges the chain himself.
- Every edit traces to a bullet in `findings.md`.
