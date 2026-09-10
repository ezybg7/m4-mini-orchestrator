---
type: plan
title: Codex integration plan
description: 'How to bring Codex under the workspace protocol: shared entry, lane
  contracts, and the vault as its context source.'
tags:
- tooling
- pantry
- protocol
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/projects/plans/codex-icm-integration-plan
---

# Codex integration plan

**Status: planned, not started.** Everett asked to plan this and integrate after
the OKF/ICM restructure lands. Prerequisite done: [`AGENTS.md`](../../../AGENTS.md)
gives Codex the same Layer 0 door Claude uses.

Background: [Codex](../../entities/codex.md) ·
[Producers and consumers](../../../references/tool-harmony.md)

## Goal

Codex reads the same context, through the same layers, as Claude — so a lane's
behavior is edited by changing a markdown file, not by editing `lane.sh`. Today
its five lanes carry their instructions inside a shell wrapper, which is exactly
the shape ICM says to invert.

## Why it is cheap

Codex's sandbox has **no network**. It can still read a folder of markdown. A
knowledge format that required an SDK, an API, or a running service could not
cross that boundary at all; a directory of files crosses it for free. This is
the concrete payoff of "format, not platform" — it is what makes a second,
locked-down runtime a first-class citizen with no adapter.

## Stages

### 1. Shared entry — DONE
`AGENTS.md` at the workspace root points at `CLAUDE.md` → `CONTEXT.md`, with no
Claude-specific content in either. Both runtimes enter through the same door.

### 2. Lanes become stage contracts
Create `pipelines/codex-lanes/` with one folder per lane — `01_review`,
`02_hunt`, `03_tests`, `04_implement`, `05_fix` — each a `CONTEXT.md` with
`## Inputs` / `## Process` / `## Outputs` / `## Verify`. Move the lane prompts
out of `lane.sh` into those contracts; `lane.sh` keeps only the mechanical work
it exists for (dependency install outside the sandbox, ref resolution, invoking
the binary). Same inversion already applied to `nightly-reflection.sh`.

Numbering is by review-risk, not execution order: read-only lanes first, lanes
that write code last. Note in the pipeline `CONTEXT.md` that these are
independent entry points, not a sequence — a deliberate deviation from ICM I6.

### 3. Vault as Codex's context source
Each lane's `## Inputs` names Layer 3 files by path — `references/safety-rules.md`,
`references/conventions.md`, the relevant `memory/projects/pantry-*.md`. Codex
reads them from disk. Nothing is passed through the wrapper.

### 4. Outputs land in Layer 4
Lanes write to `runs/<date>-codex-<lane>/`, not to scratch directories.
`review-output.schema.json` stays the contract for the review lane's JSON —
plain text as the interface, exactly ICM I2.

### 5. Close the loop
A finding Codex produces that is durable becomes a concept in the vault, through
the same `okf-normalize.py` → `okf-index.py` → `okf-check.py` path everything
else uses. Codex becomes a **producer** on the bundle, and the register in
`references/tool-harmony.md` gains a row.

## Gates

- `codex/probe.sh` must pass **before** the first run under the new contracts and
  after every `codex update`. The config silently ignores misspelled fields, so a
  contract change that touches permissions is not reviewable by reading it.
- The `implement` and `fix` lanes write code. They go through the existing
  adversarial review loop and Everett's merge — the protocol change does not
  alter who merges.

## Open questions

1. Does Codex read `AGENTS.md` automatically from the working directory, or must
   `lane.sh` cat it into the prompt? Determines whether stage 1 is genuinely done
   or needs a wrapper line. **Verify before starting stage 2.**
2. Lane prompts currently live in `lane.sh` **and** in pantry's `specs/codex-qa-lane.md`
   (spec 56). Moving them here would make three homes. Decide which is canonical
   first — probably: spec 56 stays the product spec, the contracts become the
   runtime source, and `lane.sh` holds neither.
3. Whether `hunt` (read-only, exploratory) deserves a contract at all, or whether
   it is genuinely ad-hoc work that belongs in `runs/`.