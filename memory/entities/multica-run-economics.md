---
type: reference
title: Multica run economics
description: What a board run spends tokens on and why - cost is API turns times context
  size, Claude Code's 1M window means board runs never compact, the review loop costs
  as much as the build, and the per-agent levers that change it without touching the
  daemon (measured 2026-09-11 to 13).
tags:
- multica
- m4-mini
- cost
- claude-code
timestamp: 2026-09-13 00:00:00+00:00
permalink: agents/entities/multica-run-economics
---

# Multica run economics

Measured from every board run 2026-09-11 → 09-13 (571 runs, 59 cards; the per-model totals
Claude Code reports in its final result event, read via `multica issue runs <KEY> --output json`).
The review page with the charts and Everett's decisions:
https://claude.ai/code/artifact/7502e7f2-ada5-43b0-88a7-9fb1c04cb696 (daily-log 2026-09-13 12:05).

## The model

- **A run's cost is turns × context.** Every tool call is one API turn and every turn re-reads
  the whole conversation as cache-read tokens. Cache reads were 97% of all tokens (2.14B of 2.21B)
  and, at a tenth of the input rate, still two-thirds of the Opus dollar figure.
- **Board runs never compact.** In Claude Code the 1M window is on by default for Opus 5 and
  Sonnet 5 and auto-compaction fires at ~967K. A build run (AMBR-49: 69 min, 282 tool calls,
  ~296 turns, 104.6M reads) averaged ≈350K tokens per turn and ended near 700K. A reviewer run
  sits at ≈136K per turn (90 calls, 12.3M); Codex at ≈170K (it compacts on its own).
- **The fixed prefix is not the cost.** Multica's per-task workdir `CLAUDE.md` (25K chars: its
  brief plus the 5-8K agent instructions) and the skill descriptions are under 3% of a run.
- **The review loop costs as much as the build.** On six of the eight milestone cards the
  fix-and-re-review rounds cost more than the first implementer run; every round is a full
  review (npm ci, codegraph init, typecheck, lint, jest, every changed file) although CI on the
  mini already ran the gates. Rounds find less each time: r1 47 surviving findings on 5 cards,
  r2 15 on 4, r3 5 on 4 (two zero), r4 1. Of 20 loop cards: r1 1 · r2 3 · r3 10 · r4 5 · r5 1.
- **Not the cost:** retries (all runs attempt 1), failures (7.9M reads total), prompt caching
  (writes 1.4% of reads; the subscription's 1-hour TTL), the review-lead's 211 wake-ups (~$112).

## How a run is launched (Multica source, `pkg/agent/claude.go`)

`claude -p --output-format stream-json --input-format stream-json --verbose --permission-mode
bypassPermissions --disallowedTools AskUserQuestion --model <model> --effort <thinking_level>`,
plus per-agent `custom_args` and `custom_env`. The daemon blocks only `--effort`,
`--permission-mode`, `-p`, the two format flags and `--mcp-config`; it passes every user-facing
`CLAUDE_CODE_*` variable through (it strips only its own session markers). No agent carries
`--max-turns`, `--settings` or custom args today; `high` is Claude Code's default effort for these
models, so no agent runs above default.

## The levers, per agent, no daemon restart

1. **Context ceiling** — `CLAUDE_CODE_AUTO_COMPACT_WINDOW=200000` in the agent's `custom_env`
   (`multica agent env set <id> --custom-env-stdin`, keep the existing map) or
   `multica agent update <id> --custom-args '["--autocompact","200k"]'`;
   `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` is the blunt form. Expected ≈ −70% of implementer reads,
   ≈ −30% overall. Trial on two build cards; compare rounds, findings and elapsed on the lead's
   instrumentation line before making it default.
2. **Targeted rounds ≥ 2** — reviewers review the diff since the previous pinned SHA plus the
   findings list, re-read only files with new hunks, skip gate re-runs when `gh pr checks` is
   green for that head. ≈ −11%.
3. **Implementer test-loop budget** — full suite at most twice per run, targeted suites
   otherwise, `debug-gate-failure` after the second red. ≈ −4% and shorter runs.
4. **Sonnet 5 for the stand-in implementer** ≈ −22% (its reads are $0.20/M vs Opus $0.50,
   output $10 vs $25; Sonnet-built cards closed in the same 3-4 rounds) — Everett's 2026-09-12
   item 12 says Opus; a decision, not a default.

Pricing used (API list, claude-api reference cached 2026-06-24): Opus 5 $5 / $0.50 cache read /
$6.25 cache write / $25 output per MTok; Sonnet 5 $2 / $0.20 / $2.50 / $10; Fable 5.1
$10 / $0.25 / $12.50 / $50. The Max plan is flat-rate; these are a proxy for how fast the weekly
caps drain, and the docs do not state how the caps weight cache reads.

Related: [Multica server on the mini](multica-server.md) · [Codex](codex.md) ·
[CodeGraph](codegraph.md).
## Applied 2026-09-14 (Everett's decisions t1–t5)

- **Ceiling on, as a trial:** `CLAUDE_CODE_AUTO_COMPACT_WINDOW=200000` in the custom_env of
  `claude-implementer`, `claude-reviewer`, `claude-spec-reviewer`. Judge it on the next two build
  cards: `multica issue usage <KEY>` reads/run against the baseline (implementer 27.7M, reviewers
  5.5-6.2M) and the lead's round line, which now records `mode <full|targeted>`.
- **Rounds ≥ 2 targeted, green gates not re-run** (both reviewer files, `codex-reviewer.md` kept in
  sync while archived, `review-lead.md` dispatches `targeted` by default after a fix round).
- **Implementer test-loop budget** (full suite ≤ 2×/run, targeted suites, `debug-gate-failure`
  after the second red) in both implementer files.
- **Weekly burn report:** `~/agents/scripts/multica-usage-report.py` → standing card AMBR-60
  (backlog, unassigned), LaunchAgent `com.user.multica-usage-report` Mondays 09:15; each report
  shows the previous 7 days beside the current ones.
- **Kept Opus 5** for the stand-in implementer (item 12). **Proposed (t6):** slice big cards by
  blast radius into fresh implementer runs (router `issue rerun` on a `next-slice:` HANDOFF line).
- Record: spec 61 §History 2026-09-14 05:40 (`82f278fc`), daily log 2026-09-14.

## Resume, not fresh: why fix rounds cost as much as builds (found 2026-09-14)

Multica hands every later run on the same card + agent the prior Claude session id
(`PriorSessionID` → `claude --resume`): a `direct` run after re-assignment and a `comment`
run after the lead's hand-back both continue the build's conversation, so a fix round starts
with the build's whole context and grows it. Only `multica issue rerun` starts clean — it pins
`force_fresh_session=true` (`internal/service/task.go:5676`), which is what the slice loop
relies on (confirmed live 2026-09-14 04:47: the slice-2 run opened by re-reading the card).
With the 200K ceiling a resumed session compacts on its first turn over the threshold. A fresh
session per fix round would need the router to trigger fix rounds through the rerun API rather
than the assign trigger — a candidate lever; measure the resumed-plus-ceiling cost first.

## Live test 2026-09-14 (AMBR-57, the 0070 build) — the levers measured

Released 04:39, approved 06:36: 14 runs, 53.6M cache reads, 570K output ≈ $52, two review
rounds — against $96–153 and three rounds for the 2026-09-13 design-pass milestones. Build as
three fresh slice runs 0.6M + 6.7M + 13.3M reads (baseline single builds 102–105M); round-1
reviewers 4.7M / 5.3M (baseline 12.3M / 11.5M); the fix round 9.2M on a resumed session under
the ceiling (baseline 22–55M) with 19 jest calls (baseline 81). Round 1 elapsed 16 min (baseline
58). The gate-skip half of lever 2 did not fire: the daemon PAT cannot read PR checks — grant
read-only Checks / Commit statuses / Actions. The targeted-round path was not exercised (round 2
was a legitimate full pass: shared payload keys removed) — first exercise on a later card.
