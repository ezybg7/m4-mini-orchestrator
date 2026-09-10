---
type: decision
title: Adopt OKF + ICM for the orchestrator workspace
description: 2026-09-10 - ~/agents restructured as an ICM staged workspace whose knowledge
  layer is an OKF bundle.
resource: https://arxiv.org/abs/2603.16021
tags:
- protocol
- memory
- workflow
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/decisions/adopt-okf-icm-2026-09-10
---

# Adopt OKF + ICM (2026-09-10)

**Decision.** `~/agents` follows two external specs: **OKF v0.1** for the
knowledge layer and **ICM** (arXiv:2603.16021) for the workflow layer. Full
ruleset and rationale in [SPEC.md](../../SPEC.md).

**Why.** Before this, the workspace had no Layer 0/1/2 at all — no `CLAUDE.md`,
no `CONTEXT.md`, no `index.md` anywhere. An agent starting cold grepped and
guessed. Durable knowledge was a 105-line mega-note; recurring workflows were
tribal knowledge inside shell scripts; the root held 20 stale `tmp_*` files.

**What changed.** Layers 0 and 1 added at the root; `memory/` normalized to OKF
frontmatter with indexes and cross-links; the mega-note split one-concept-per-file;
`pipelines/` created for the three recurring workflows; the root cleaned into
`_archive/` and `runs/`.

**Standing consequence.** New durable facts get a concept file with frontmatter
and an index link — not a paragraph appended to an existing note. New recurring
workflows get a stage contract, not a shell script with the logic inside it.

Related: [Working conventions](../../references/conventions.md) ·
[Safety rules](../../references/safety-rules.md)