---
type: index
title: pipelines
description: Layer 2 - stage contracts for the workspace's recurring, human-reviewed workflows.
tags: [index, workflow]
timestamp: 2026-09-10T00:00:00Z
---

# pipelines

Layer 2. Each folder is one ICM pipeline: numbered stages, each with a contract
declaring `## Inputs`, `## Process`, `## Outputs` and `## Verify`.

| Pipeline | Runs | Human gate |
|----------|------|------------|
| [nightly-reflection](nightly-reflection/CONTEXT.md) | cron 03:00 daily | push, never merge |
| [db-apply](db-apply/CONTEXT.md) | on demand | **stage 2 — hard stop** |
| [weekly-maintenance](weekly-maintenance/CONTEXT.md) | cron Mon 09:00 | escalate, never merge, on a pinned-set advisory |

Adding one: a workflow earns a pipeline when it is **sequential, reviewable and
repeatable**. Real-time coordination, concurrency, and automated branching do not
belong here — see [SPEC.md](../SPEC.md) §2.2 rule I11.
