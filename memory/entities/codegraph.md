---
type: entity
title: CodeGraph
description: SQLite symbol/edge index over a code repo. Answers code-structure questions
  in one call; indexes code, not this vault.
tags:
- tooling
- infra
- pantry
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/entities/codegraph
---

# CodeGraph

`~/.local/bin/codegraph`, v1.4.1 on the mini (v1.6.0 available — the upgrade is
Everett's call). Indexed repo: `~/code/pantry/.codegraph` (~380 files).

## What it is for

A SQLite knowledge graph of a codebase's symbols, edges and files. One
`codegraph_explore` call returns the relevant symbols' verbatim, line-numbered
source **plus the call paths between them**, including dynamic-dispatch hops grep
cannot follow. It replaces a grep-and-read loop with one round trip.

- MCP: `codegraph_explore` (pass `projectPath` for a repo other than the default)
- Shell: `codegraph explore "<symbols or question>"`

## Where it sits in this workspace

CodeGraph is a **consumer of code, not of this bundle** — it indexes source, and
`~/agents` is markdown and shell scripts. Indexing `~/agents` was considered and
rejected: there are no symbol graphs here to traverse, and the bundle already has
its own navigation in `index.md` files and cross-links. **That is the division:
CodeGraph is the index for code, the OKF bundle is the index for knowledge.**

The rule of thumb, matching `~/.claude/CLAUDE.md`: in a repo with a `.codegraph/`
directory, reach for it **before** grep or reading files. With no `.codegraph/`,
skip it — indexing is the user's decision.

## Contract

Read-only with respect to this workspace. Writes nothing here; owns `.codegraph/`
inside the repos it indexes.

Related: [Producers and consumers](../../references/tool-harmony.md) ·
[Ambry stack](../projects/pantry-stack.md)