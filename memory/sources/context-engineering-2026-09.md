---
type: source
title: Context engineering for coding agents — sources read 2026-09-15
description: The external sources behind the board's context-layer research (Anthropic
  engineering posts and Claude Code/API docs, Manus, Cognition, OpenHands, ACON, Context-Folding,
  Chroma's Context Rot, Systima's subagent tax, Aider's repo map, Roo Code issues,
  practitioner reports), with what each settled and its rung; the full record is docs/research/context-engineering-2026-09.md
  in pantry.
tags:
- multica
- cost
- claude-code
- context
timestamp: 2026-09-15 00:00:00+00:00
permalink: agents/sources/context-engineering-2026-09-1
---

# Context engineering for coding agents — sources read 2026-09-15

Full record with every citation: pantry `docs/research/context-engineering-2026-09.md` (`35d8bb6d`).
The board's own measurements live in [Multica run economics](../entities/multica-run-economics.md).

## What each source settled (rung in brackets)

- **Chroma, "Context Rot" (2025-07-14) [3]** — quality falls monotonically with input length across 18 models, even on trivial retrieval; a smaller working context is a quality lever, not only a cost lever. https://research.trychroma.com/context-rot
- **Systima, "The Subagent Tax" (2026-07-22) [3/4]** — 2-subagent fan-out costs 2.6–5.9× the input tokens of sequential work and is slower; subagents start with a cold cache. https://systima.ai/blog/subagent-tax
- **Anthropic, multi-agent research system (2025-06-13) [2, interested]** — agents ~4× chat tokens, multi-agent ~15×; token use explains 80% of eval variance; coding is less parallelisable than research. https://www.anthropic.com/engineering/multi-agent-research-system
- **Anthropic, harness design for long-running apps (2026-03-24) [2/4]** — context resets with a structured hand-off beat compaction for coding; separate the worker from the judge. https://www.anthropic.com/engineering/harness-design-long-running-apps
- **Anthropic, effective context engineering (2025-09-29) [2]** — tool-result clearing is the safest compaction; subagents return 1–2K-token summaries; just-in-time retrieval by identifier. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- **Claude API cost page [2]** — on a long run a prune saved 39% and compaction 32%; context editing cost 74% more on short runs; clears invalidate the cache from that point. https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- **Claude Code docs [2]** — CLAUDE.md under ~200 lines, skills on demand, hooks pre-filter tool output, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, subagents isolated with a cold cache bucket, cache reads ~10% of input. https://code.claude.com/docs/en/costs
- **Manus (2025-07) [2]** — KV-cache hit rate is the metric; stable prefixes, append-only context, file system as memory, recitation, keep failures. https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus
- **Cognition (2025-06) [2]** — share full traces within a task; a compressor model is "hard to get right". https://cognition.ai/blog/dont-build-multi-agents
- **OpenHands condenser (2025-04-09) [2/4]** — per-turn cost under 50% once active, SWE-bench 54% vs 53%. https://openhands.dev/blog/openhands-context-condensensation-for-more-efficient-ai-agents
- **ACON (arXiv:2510.00615) and Context-Folding (arXiv:2510.11967) [2/3]** — 26–54% peak-token cuts with success up; branch-and-fold keeps active context ~10× smaller.
- **Aider repo map [2]** — graph-ranked, token-budgeted context instead of whole files. https://aider.chat/docs/repomap.html
- **Roo Code issues [4]** — how auto-condense fails in a shipped product: silently, on the wrong model, prematurely. https://github.com/RooCodeInc/Roo-Code
- **Practitioners [4]** — fresh sessions + hand-off files (ghuntley.com/ralph, badlogic's compaction gist), 200K over 1M (HN 47768517, albertsikkema.com 2026-04-23), lean CLAUDE.md (boringbot 2026-05-29).

## What it decided for the board
A static per-card **context pack** at the hand-offs plus symbol-level reads, fresh fix rounds and stable prefixes; no dynamic model-managed broker. See the record's "What this changes for the board".