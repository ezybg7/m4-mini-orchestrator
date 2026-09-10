---
type: decision
title: The M4 mini is the primary workplace
description: 2026-09-03 - orchestration, builds, simulator and acceptance moved from
  the MacBook to the mini.
tags:
- infra
- machines
timestamp: 2026-09-03 00:00:00+00:00
permalink: agents/decisions/mini-is-primary-workplace-2026-09-03
---

# The M4 mini is the primary workplace (2026-09-03)

**Decision.** The M4 Mac mini (`m4-mini`, user `orchestrator`) became the primary
workplace on 2026-09-03. It hosts the Hermes gateway, the Claude worker queue and
cron, and — after that day's Xcode 26.6 install and `eas login` — can do
everything the laptop could: `npm run ios`, Release simulator builds, the Maestro
acceptance suite, and EAS builds.

**Why it was forced.** The mini's clone had never been pulled while ~400 commits
(PRs #11–#139) landed from the laptop and web sessions, so the nightly reflection
kept re-reporting carry-overs that had been resolved for weeks. The same day, the
project note was rewritten from GitHub ground truth.

**Consequence.** `git pull` first, every session, on every machine. GitHub is the
only sync path — code via `ezybg7/pantry`, the vault via the 02:30 backup of
`ezybg7/m4-mini-orchestrator`.

Related: [Machines & roles](../../references/machines.md) ·
[Ambry retired carry-overs](../projects/pantry-retired.md)