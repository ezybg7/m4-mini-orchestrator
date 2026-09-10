---
type: stage
title: 03_adjudicate
description: Claude judges the findings or the diff. The gate - Codex proposes, Claude disposes.
tags: [tooling, pantry, safety]
timestamp: 2026-09-10T00:00:00Z
---

# 03_adjudicate

## Inputs
- Layer 4 (working): `../02_dispatch` output — the findings JSON or the worktree diff
- Layer 3 (reference): the spec's §Acceptance
- Layer 3 (reference): [Ambry gotchas](../../../memory/projects/pantry-gotchas.md)

## Process
Judge each finding on its own evidence. A finding without a location and a
concrete failure — the input, and the observable wrong outcome — is noise;
"this could race" is not a finding. Accept, reject, or downgrade each, and say
why. Silence is not acceptance.

For a diff: check it against the acceptance criteria **as written**, not against
what you would have built. Files touched outside the task's scope must have been
called out explicitly; if they were not, that is a finding against the run.

This is the edit surface. Edit the worktree diff directly where it is nearly
right — the next stage reads what is there.

## Outputs
- `output/adjudication-<date>.md`: each finding, the verdict, and the reason
- an edited worktree diff, if any

## Verify
- Every finding has a recorded verdict.
- A rejected security finding needs a stated reason, not an omission. The review
  rules exist because these defects have bitten this repo before — missing
  `GRANT`s, RLS gaps, `SECURITY DEFINER` without a pinned `search_path`, SSRF
  through a scanned barcode, a Worker route echoing a provider error, a persisted
  receipt image.
- If Codex reported drift between `CLAUDE.md` and `AGENTS.md`, or contradicted a
  premise in the task, resolve **that** before the code. It is usually right and
  is the most valuable thing it produces.
