---
type: plan
title: Codex integration plan
description: 'Superseded by what testing found: Codex cannot read this workspace,
  so the integration is orchestrator-side. What is done and what remains.'
tags:
- tooling
- pantry
- protocol
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/projects/plans/codex-icm-integration-plan
---

# Codex integration plan

**Rewritten 2026-09-10 after testing the sandbox.** The first version of this
plan assumed Codex could be given the same Layer 0 entry Claude has, via an
`AGENTS.md` at the workspace root. That was wrong in two ways, and both were
found by running commands rather than reading config:

1. Codex's profiles deny `/Users/orchestrator/agents/**` — deliberately, because
   that tree holds `.env.acceptance`. Verified:
   `codex sandbox -P pantry-review -- cat ~/agents/CLAUDE.md` → *Operation not
   permitted*. **Codex will never read this workspace, and should not.**
2. Worse, the `AGENTS.md` I added *broke* Codex: it walks up for the nearest one
   at session start, found a file it is forbidden to read, and died — taking
   `probe.sh`, the mandatory sandbox gate, down with it.
   → [decision](../../decisions/no-agents-md-in-agents-workspace-2026-09-10.md)

So the integration is **orchestrator-side**: Claude drives the lanes and the
contracts describe Claude's half of the handoff.

## Validated 2026-09-10

- `codex/probe.sh` **14/14** on codex-cli 0.153.2 — every denial holds, commits
  blocked inside the worktree, network off, `oauth_token` and `.env.acceptance`
  unreadable under both profiles.
- Canonical `~/agents/codex/config.toml` matches the installed `~/.codex/config.toml`.
- [`pipelines/codex-lanes/`](../../../pipelines/codex-lanes/CONTEXT.md) — the
  four-stage handoff, lane kind as a parameter.
- [`references/model-roles.md`](../../../references/model-roles.md) — the
  division of labor as a Layer 3 rule: Claude owns intent, Codex owns execution
  and attacking it.
- `scripts/instruction-drift.py` — closes the gap AGENTS.md names itself
  ("two instruction files with no drift check is the standard failure mode of a
  two-model setup"). Baseline recorded; self-tested.

## Remaining

1. **Run a real lane end to end.** Everything above is validated without spending
   a Codex call. A `hunt` or `review` lane is read-only and the cheapest honest
   test of the whole path — task file → dispatch → adjudicate. Not yet done.
2. **Wire the drift check into a schedule.** It is referenced by
   `01_task_file`'s `## Verify` but nothing runs it periodically. Weekly
   maintenance is the natural home.
3. **Decide where lane prompts are canonical.** They exist in `lane.sh` (thin:
   `MODE:` plus a line or two) and in pantry's `AGENTS.md` (the real rules) and
   spec 56. Current answer, not yet written down as a decision: **AGENTS.md is
   canonical** because it is the file Codex actually reads; `lane.sh` should hold
   no policy; spec 56 stays the product spec. Confirm, then prune whatever
   duplicates.
4. **`hunt` may not deserve a contract** — it is exploratory and read-only, and
   may belong in `runs/`. Left as a lane for now.

## Non-goals

Weakening the sandbox to let Codex read `~/agents`. The config's own comments
record why that is dangerous: a profile with a misspelled filesystem key loads
**without error and denies nothing** — one such profile read `~/.claude/oauth_token`
in full. Anything Codex needs from Layer 3 gets quoted into the task file by
`01_task_file`, outside the sandbox.

Related: [Codex](../../entities/codex.md) ·
[Model roles](../../../references/model-roles.md) ·
[codex-lanes](../../../pipelines/codex-lanes/CONTEXT.md)