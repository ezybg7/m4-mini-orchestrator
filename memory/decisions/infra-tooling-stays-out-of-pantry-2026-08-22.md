---
type: decision
title: Orchestrator tooling stays out of the pantry repo
description: 2026-08-22 - PR
tags:
- conventions
- infra
timestamp: 2026-08-22 00:00:00+00:00
permalink: agents/decisions/infra-tooling-stays-out-of-pantry-2026-08-22
---

# Orchestrator tooling stays out of the pantry repo (2026-08-22)

**Decision.** Orchestrator and infrastructure tooling never goes in the pantry
repo. PR #101 (the Jetson Orin spec) was **closed without merge** for exactly
that reason. It lives in `~/agents` — this workspace.

**Consequence.** A useful script discovered while working in `pantry` belongs in
`~/agents/scripts/`, and the fact belongs in this vault, not in the app repo.
Parked unless Everett reopens it.

Related: [Working conventions](../../references/conventions.md) ·
[Jetson Orin node spec](../projects/plans/jetson-orin-node-spec-2026-08-19.md)