---
type: reference
title: Producers and consumers
description: 'Every tool that reads or writes this workspace: what it owns, what it must not touch, and the contract between them.'
tags: [conventions, infra, protocol]
timestamp: 2026-09-10T00:00:00Z
---

# Producers and consumers

OKF's second principle is **producer/consumer independence**: who writes the
knowledge is separate from who reads it, the format is the contract, and the
tooling at each end is swappable. That only works if the contract is written
down. This is that register.

A tool is a **producer** if it writes files here, a **consumer** if it reads
them. Several are both. None of them may require another to be installed.

## The register

| Tool | Role | Owns | Contract |
|------|------|------|----------|
| **Claude Code** | both | nothing exclusively | Enters at [CLAUDE.md](../CLAUDE.md) → [CONTEXT.md](../CONTEXT.md). Writes concepts through `okf-normalize.py`. |
| **basic-memory** (MCP) | both | `permalink`; YAML canonicalization | Syncs asynchronously and re-prepends its block when it **cannot parse** a file's frontmatter. Emit valid YAML and it merges cleanly. |
| **`okf-check.py`** | consumer | — | Validates OKF + stage contracts. Must exit 0 before a commit. |
| **`okf-index.py`** | producer | `index.md` below `<!--okf:generated-->` | Prose between the `okf:intro` markers is hand-written and preserved. |
| **`okf-normalize.py`** | producer | frontmatter shape | Idempotent. Runs **last**, after content edits. |
| **Obsidian** | both | `.obsidian/` UI state | Configured for relative markdown links so hand- and tool-written links stay one style. See [Obsidian](../memory/entities/obsidian.md). |
| **CodeGraph** | consumer | `.codegraph/` in indexed repos | Indexes **code**, not this vault. See [CodeGraph](../memory/entities/codegraph.md). |
| **Codex** | both | `~/agents/codex/` | Enters at [AGENTS.md](../AGENTS.md). Integration is planned, not done — see [the plan](../memory/projects/plans/codex-icm-integration-plan.md). |
| **cron / launchd** | producer | schedules only | Schedules pipelines; never defines what they do. |
| **git** | consumer | history | The backup and the undo. `backup.sh` converges the bundle before committing. |

## The four rules that keep them from fighting

1. **Emit valid YAML.** An unquoted scalar containing `": "` is not valid YAML.
   This is not pedantry — it is the actual cause of the only producer conflict
   this workspace has had. A parser that fails cannot merge, so it prepends,
   and the two tools fight forever. `okf-normalize.py` quotes for you.
2. **One writer per field.** basic-memory owns `permalink`; `okf-index.py` owns
   generated index bodies; humans own the `okf:intro` blocks. Do not cross.
3. **No tool is required.** The bundle is readable with `cat`. Every tool here
   is an accelerator, and removing any one leaves the knowledge intact. This is
   what "format, not platform" means in practice.
4. **Converge before committing.** `backup.sh` runs normalize → index → check.
   Whoever wrote last, the committed state is conformant.

## Why this is the whole integration story

There is no integration layer here, and that is the design. Tools cooperate
because they share a directory of markdown files with frontmatter, not because
anyone wrote an adapter. Adding a tool means teaching it the format — or
teaching nothing, if it already reads markdown.

Related: [SPEC.md](../SPEC.md) §2.1 O8 ·
[OKF](../memory/sources/okf-open-knowledge-format.md)
