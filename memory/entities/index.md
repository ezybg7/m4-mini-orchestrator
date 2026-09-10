---
type: index
title: entities
description: Index of 6 concept(s) under entities/.
tags:
- index
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/entities/index
---

# entities

<!--okf:intro-->
A machine, repo, or service: what it is, how to reach it, and the operational
facts you need before touching it.

The three **machines** are not here — they are Layer 3 in
[`../../references/machines.md`](../../references/machines.md), because which box
does what is an operating rule, not project knowledge.
<!--/okf:intro-->

<!--okf:generated-->

## Concepts

| Concept | Type | Description |
|---------|------|-------------|
| [Ambry Cloudflare Worker](ambry-worker.md) | `entity` | The API surface - routes, secrets, deploy command, and what to smoke-test
after a deploy. |
| [Claude worker queue](claude-worker-queue.md) | `entity` | The launchd-watched task queue that runs headless Claude sessions on
the mini. |
| [CodeGraph](codegraph.md) | `entity` | SQLite symbol/edge index over a code repo. Answers code-structure questions
in one call; indexes code, not this vault. |
| [Codex](codex.md) | `entity` | Second agent runtime with five pantry lanes; sandboxed with no network.
Configured but not yet wired into the workspace protocol. |
| [Neon Postgres project](neon-project.md) | `entity` | Production endpoints, the branch workflow, and the pooler-vs-direct distinction
that migrations depend on. |
| [Obsidian](obsidian.md) | `entity` | Graph/editor view over the workspace. Installed, but pointed at ~/.hermes
rather than here. |