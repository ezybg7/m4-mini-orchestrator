---
type: stage
title: 02_dispatch
description: Run the lane. Mechanical work only - the wrapper exists because the sandbox has no network.
tags: [tooling, infra]
timestamp: 2026-09-10T00:00:00Z
---

# 02_dispatch

## Inputs
- Layer 4 (working): `../01_task_file/output/task-<lane>-<date>.md`
- Layer 3 (reference): [Codex](../../../memory/entities/codex.md)

## Process
`~/agents/codex/lane.sh <lane> <arg>`. Nothing here is a judgment call — the
wrapper exists to do what the sandbox cannot: `npm ci` before Codex starts
(no network inside), create the worktree at `~/codex-worktrees/` (**outside**
`~/agents`, so the denial there can stay total), hold the single-instance lock,
and write output back out.

Never pass `--dangerously-bypass-approvals-and-sandbox`, `--yolo`, or
`--dangerously-bypass-hook-trust`. `lane.sh` refuses them; do not work around it.

## Outputs
- `~/agents/logs/codex-<lane>-<stamp>.json` (events) and `.last.txt` (final JSON)
- for `implement` / `fix` / `tests`: an **uncommitted** diff in the kept worktree

## Verify
- **Check what the worktree is cut from.** `lane.sh` defaults `BASE_REF` to
  `HEAD`, which is the checkout's *current branch* — not `main`. On 2026-09-10
  that checkout sat on `ci/cut-actions-minutes`, 7 commits ahead of `origin/main`,
  so an unset `BASE_REF` would have reviewed the wrong base without saying so.
  Set it explicitly.
- Exit 3 means rate-limited, not failed: Codex is marked cooling for the day.
  Proceed Claude-only and say so in the PR. Do not retry in a loop.
- Non-`implement` output validated against `review-output.schema.json` —
  `verdict`, `summary`, `findings`, `next_steps` all present; every finding has
  `file` + `line_start` and a severity of `critical`/`high`/`medium`/`low`.
- Nothing was committed. Codex cannot commit; if something is committed, the
  containment is broken — stop and re-run `probe.sh`.
