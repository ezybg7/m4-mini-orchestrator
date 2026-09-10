---
type: stage
title: 05_instruction_drift
description: Flag when one of the repo's two instruction files moved without the other.
tags: [tooling, conventions]
timestamp: 2026-09-10T00:00:00Z
---

# 05_instruction_drift

## Inputs
- Layer 3 (reference): `~/code/pantry/CLAUDE.md` and `AGENTS.md`
- Layer 4 (working): `system-config/instruction-drift.json` — the recorded baseline

## Process
`python3 ~/agents/scripts/instruction-drift.py`. Exit 1 means one file moved
alone: CLAUDE.md binds Claude, AGENTS.md binds Codex, and AGENTS.md deliberately
does not restate CLAUDE.md's rules — so one moving alone means the two models are
working from different instructions and nothing else says so.

On drift, read the change and decide whether it needs a matching edit in the
other file. Then `--accept` to record the new baseline. **Do not `--accept`
without reading the diff** — that turns the check into a rubber stamp.

## Outputs
- A line in the weekly log; on drift, a note in `output/drift-<date>.md` naming
  which file moved and what was decided.

## Verify
- Exit 0, or a recorded decision explaining the drift.
- The baseline was accepted only after the change was actually read.
