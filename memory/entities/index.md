---
type: index
title: entities
description: Index of 3 concept(s) under entities/.
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
| [Neon Postgres project](neon-project.md) | `entity` | Production endpoints, the branch workflow, and the pooler-vs-direct distinction
that migrations depend on. |