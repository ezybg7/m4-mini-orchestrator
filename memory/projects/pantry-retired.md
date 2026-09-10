---
type: project
title: Ambry retired carry-overs
description: Items verified closed against GitHub on 2026-09-03. Do NOT resurrect
  these.
tags:
- pantry
- memory
timestamp: 2026-09-03 00:00:00+00:00
permalink: agents/projects/pantry-retired
---

# Ambry retired carry-overs

Part of [Ambry / pantry](pantry.md).

## Retired carry-overs (verified against GitHub 2026-09-03 — do NOT repeat)

- "Review PR #10" → **MERGED 2026-07-21.**
- "Open a PR for `feat/nightly-pull-routine`" → **MERGED as PR #15 on 2026-07-23** (`npm run sync` + `nightly-sync.yml` are on main).
- "Open a PR for `feat/receipt-parsing`" → never opened; branch deleted from origin; the PDF + purchase-date work is on main (spec 1 row). Dead local branch.
- "`chore/spec-audit-tracking-issues` / run `create-tracking-issues.sh` for 18 issues" → obsolete: the roadmap was rebuilt around specs/README.md (53 specs, board + dependency graph); branch deleted from origin; no `spec-tracking` issues exist and none are wanted.
- "Review PR #101 (Jetson Orin spec)" → **CLOSED 2026-08-22 without merge** (infra tooling stays out of the pantry repo). Parked unless Everett reopens it.
- "Provision `ANTHROPIC_API_KEY`" → the production Worker has served the Claude routes since the 08-08/08-11 deploys; the only remaining key-flavoured item is the pre-beta accuracy eval on real receipts.
- "Flip Gemini to the paid tier" → moot, the adapter is gone (`wrangler secret delete GEMINI_API_KEY` if it was ever set).
- "OrbStack docker.sock / `supabase start` / `supabase db reset` to seed the catalog" → retired with the 07-29 cutover; the 421-item catalog is seeded in production Neon.
- Skills-chain note: the `nightly-2026-*` branches of `~/agents/skills` (84 commits ahead of that repo's main) still await Everett's review/merge — that one is real and unchanged.