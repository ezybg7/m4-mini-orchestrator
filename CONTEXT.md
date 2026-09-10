---
type: index
title: Layer 1 — Routing
description: Where to go next, by task. The workspace's routing table.
tags: [protocol, index]
timestamp: 2026-09-10T00:00:00Z
---

# Layer 1 — Routing

You have read [CLAUDE.md](CLAUDE.md). This answers: **where do I go next?**

| If the task is… | Go to |
|---|---|
| Nightly maintenance / reflection | [nightly-reflection](pipelines/nightly-reflection/CONTEXT.md) |
| Applying a database migration | [db-apply](pipelines/db-apply/CONTEXT.md) — **never skip a gate** |
| Weekly Dependabot + secret-expiry pass | [weekly-maintenance](pipelines/weekly-maintenance/CONTEXT.md) |
| Any other recurring workflow | [pipelines/](pipelines/index.md) |
| A project's current state | [memory/](memory/index.md) → `projects/` |
| "Why did we do it this way?" | [memory/decisions/](memory/decisions/index.md) |
| "What is this machine / repo / service?" | [memory/entities/](memory/entities/index.md) |
| A one-off with no pipeline | work in [runs/](runs/index.md)`<date>-<slug>/` |

## Layer 3 — load only what the task needs

- [safety-rules.md](references/safety-rules.md) — **before any production action**
- [machines.md](references/machines.md) — what runs where
- [conventions.md](references/conventions.md) · [model-roles.md](references/model-roles.md)
- [tool-harmony.md](references/tool-harmony.md) — who else writes these files
- [references/](references/index.md) · [memory/](memory/index.md)

## If no pipeline fits

Never create a folder at the workspace root. Work in `runs/`, or — if this will
recur and wants review between steps — scaffold one:
`python3 scripts/new-pipeline.py <name> <stage>...` writes conformant contracts
and registers them. Fill the TODOs, then `okf-check.py`. Rules: [SPEC.md](SPEC.md) §2.2.
