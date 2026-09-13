---
type: reference
title: Driving the Multica board
description: The operating rules for the self-hosted Multica board on the mini — assignment is the only trigger, who does what, and what not to do.
tags: [multica, workflow, m4-mini, agents]
timestamp: 2026-09-11T00:00:00Z
---

# Driving the Multica board

The board is the layer over Claude Code and Codex on the mini (the machine and
security facts: [Multica server on the mini](../memory/entities/multica-server.md);
the written spec: `specs/multica-integration.md` in pantry).

## The columns are the pipeline

`Backlog` parked · `Todo` -> `claude-planner` · `Code` -> `codex-implementer` ·
`In Review` -> squad `review` · `Blocked` needs Everett · `Done`. Everett drives
it by moving cards. Never set `in_progress`: it is not a stage, and an issue
there belongs to no column.

## The procedure

The operating procedure for a session that works this board — start, classify, drive each card
to its gate, merge authority, production applies, fixing the setup, the skill-growth loop, ending
a session — is the `orchestrator` skill (`~/agents/skills/orchestrator/SKILL.md`, every Claude Code
session on the mini sees it through `~/.claude/skills`). This file stays the rules; the skill is
how they are applied.

## The rule underneath

**Assignment starts a run.** Not a status change, not a comment, not a GitHub
event. `~/agents/scripts/multica-router.py` (LaunchAgent
`com.user.multica-router`, 60 s) bridges the two by assigning the actor each
column implies -- so agents set status and never assign.

- `multica issue assign <KEY> --to <agent|squad|everettyan>` begins work.
  Re-assigning the same agent is a **no-op** — `--unassign` first to retry.
- **Assigned + `backlog` does not run.** Leaving `backlog` starts it. This is the
  park-and-drag gate for work a human must approve first.
- A **comment** wakes whoever owns the issue — the agent, or a squad's leader.
- Assigning a **squad** routes to its **leader only**; it @mentions members.
- Work returns to Everett exactly one way: assigned to `everettyan`.

## Who does what

| Agent / squad | Role |
|---|---|
| `claude-planner` | PRD + spec → one cross-model review by `codex-spec-reviewer` (Astra) → rules → one PR; leaves the card in `Todo` |
| `codex-implementer` | Builds from the spec, runs the gates, opens the PR, hands to the review squad |
| squad `review` | `claude-reviewer` (two lenses, one Claude agent) + `codex-reviewer` (spec) in parallel; the lead pins a SHA, dedupes, ranks, resolves the thread, routes; owns the 3-round cap |
| squad `research` | `researcher-external` + `researcher-ambry`; conflicts argued, one decided document |
| `claude-dev` | Catch-all board work |
| `dependabot-maintainer` | Weekly autopilot, Mondays 09:00 ET |

Reviewers report; they never route.

Every turn ends in a `HANDOFF` block (head SHA, round, did, decided, open, stale-risk, verify-with-outputs); reviewers review the pinned SHA and never route.

## Operating

- Agent instructions live in `~/agents/multica/agents/<name>.md`. Editing the file
  changes nothing until `multica agent update <id> --instructions "$(cat …)"`.
- Skills: `python3 ~/agents/multica/sync-skills.py`. The repo is the home;
  `skill refresh` does not work on locally-supplied skills.
- Never run `multica daemon start` as orchestrator — the daemon is the `multica`
  user's, and running it as orchestrator would put the boundary back where it was.
- `multica setup` **without** `self-host` points at Multica Cloud. That happened
  once, on 2026-09-11.

## Known constraints

Codex agents need `GH_TOKEN` as audited `custom_env` and get no auto-checkout.
Jest on the daemon user needs `--watchman=false`. A task workdir is fresh with no
repo in it. Fable credits exhaust before Opus does on Everett's plan.
