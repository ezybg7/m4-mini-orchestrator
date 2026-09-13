---
type: project
title: pantry
description: 'Ambry - mobile pantry tracker. Hub note: what it is, where it stands, what Everett owes, and links to every other Ambry concept.'
resource: https://github.com/ezybg7/pantry
tags: [pantry, release, database, acceptance]
timestamp: 2026-09-05T00:00:00Z
permalink: agents/projects/pantry
---

# Ambry (repo: pantry)

_Updated: 2026-09-03 · Repo: github.com/ezybg7/pantry (private) · Local on the mini: ~/code/pantry (also reachable as ~/Code/pantry — APFS is case-insensitive)_

**2026-09-03 ground-truth reset.** Rewritten from GitHub + `origin/main` the day Everett made the M4 Mac mini the primary workplace. The previous version of this note had a Status board that stopped at 2026-08-19 while ~400 commits (PRs #11–#139) landed from the laptop and Claude Code web sessions; the mini's clone was never pulled, so the nightly reflection kept re-reporting carry-overs that had been resolved for weeks (see "Retired carry-overs" — do not resurrect them). The old note, including its fold-provenance ledger, is in this vault's git history (`ezybg7/m4-mini-orchestrator`, commit `ca6fc07` = backup 2026-09-03); `daily-log/archive/` remains the record of the folds.

## Related concepts

This note is the hub. Detail lives in its own file, one concept per file:

- [Ambry stack](pantry-stack.md) — app, backend, AI, hard rules, env, CI gates
- [Ambry operational gotchas](pantry-gotchas.md) — traps that have cost time before
- [Ambry retired carry-overs](pantry-retired.md) — closed items; do not resurrect
- [Ambry state 2026-09-04](pantry-state-2026-09-04.md) — historical snapshot
- [Everett-only items 2026-09-04](pantry-everett-only-2026-09-04.md) — DB applies and deploys
- [Monetization plan](pantry-monetization-plan-2026-09-04.md) — Ambry Plus pricing and scope
- [Machines & roles](../../references/machines.md) — Layer 3 reference
- [Working conventions](../../references/conventions.md) — Layer 3 reference
- Build plans: [specs 50/51](plans/pantry-specs-50-51-build-plan-2026-09-04.md) ·
  [specs 52/53/45](plans/pantry-specs-52-53-45-build-plan-2026-09-04.md)

## What it is

Mobile pantry tracker: household inventory with auto-estimated expirations, self-organizing storage locations, capture by type-ahead / barcode / receipt photo, grocery list, and recipes (deterministic "what can I make" + AI ideas + a growing community layer). Public multi-user app, iOS first. **SPEC.md in the repo is product truth; specs/README.md is the status board; this note is the summary plus the machine/orchestration facts the repo deliberately does not hold.**

## Where things stand (2026-09-03 · main = `838f135` · last merge PR #139 on 2026-09-01)

- **Specs 1–53** exist. Everything through spec 49 is built and live except: 17 apple-sign-in (client built, parked 08-11 on "Neon Auth has no apple provider" — that park predates the self-hosted Better Auth cutover and the `APPLE_CLIENT_SECRET` set 08-22, so re-read specs/auth-provider-migration.md + docs/adr/auth.md D11 before repeating it); 19 app-store-release (console work only); 20/37 retired; 42 recipe-nutrition partial; 44 leftover-composition device pass pending; 45 catalog-nutrition-matching specced (migration 0047 reserved, unwritten); 46 built + cut over 08-22 with the Apple/Google arms config-gated ("dark").
- **Recipe engagement pack** (PRD `docs/prd/recipe-engagement.md`, signed off 08-29, specs 47–53): **wave 1 = 47 ratings · 48 folders + Favorites · 49 time + difficulty — built, reviewed three rounds, merged 08-30 (#133–#136), migrations 0050–0052 applied to production first**, acceptance suite 10/10 on 08-31. **Wave 2 not started: 51 profiles → 52 comments → 53 following** (migrations expected 0053–0056); 50 moderation-admin's migration can land any time, its `/admin` dashboard is built-when-needed. 49 added `react-native-svg`, so the difficulty ring needs the next dev build.
- **Database**: 0001–0052 applied to production except the reserved 0047; nothing pending. One data apply outstanding: `db/apply/usda-nutrition-backfill-2.sql` (rehearsed 08-23, not applied).
- **Production Worker** runs the real Claude provider (the acceptance suite excludes the ideas flow precisely because the Worker is not in mock mode); the board still lists "confirm `ANTHROPIC_API_KEY` is set as a Worker secret" as a pre-beta check — treat that as "verify with `wrangler secret list`", not as an unprovisioned key.
- **Open on GitHub**: PRs = Dependabot only (#116 actions/checkout 4→7, #137 app-routine group ×20, #138 worker-routine group ×3); issues = #26 nightly-sync report only. Remote branches besides main: the Dependabot heads, `feat/store-foundations` (its PR #58 closed 07-30) and `chore/retire-repo-pages` (PR #97 closed 08-23 — Pages stays the host).
- **Suite size**: 110 jest suites / 1,715 tests (verified green on the mini 2026-09-03).
- **Working rules since 08-30**: code never waits on Everett — Everett reviews PRDs and specs and runs the device passes; code goes through an adversarial agent review loop (review → fix everything → review again) and merges on a clean pass; apply-before-merge for migrations the new client depends on; `site/updates.md` is appended at the end of every working session.

## Everett's plate (site/tasks.md + specs/README.md, unchanged since 08-31)

1. **Install the newest EAS development build** (`2925130a`; first binary with `react-native-svg`, `expo-network`, `expo-localization`, `ios.associatedDomains`), then the on-device passes: VoiceOver stars, ring bands in dark mode, floor snap-up, two-account rating average, airplane-mode matrix (§14), invite-link two-device pass (§2), realtime (§9), grocery collab (§7), password reset (§1). `eas build --profile preview --platform ios` is the no-Metro alternative.
2. **LLC conversion of the Apple Developer account** (D-U-N-S → Individual→Organization → Paid Apps agreement / banking / W-9 / DSA) **before** anything financial; then the **RevenueCat turn-on** sequence in spec 23 §Turning it on ($2.99/mo · $24.99/yr, entitlement `plus`, webhook secret, `EXPO_PUBLIC_REVENUECAT_IOS_KEY` in every eas.json profile → new build).
3. **App Store Connect record** (`Ambry: Kitchen Inventory`, Food & Drink, 4+) → `ascAppId` + ASC API key into eas.json's submit block; screenshots (6.9" + 6.5", 5 each), demo review account, listing read-through (`docs/store-listing.md`).
4. **Decisions waiting**: multi-list grocery go/no-go (spec 30 G1); member-limit upsell wording (PR #100); adaptive shelf-life announcement copy (spec 40); Plus ideas bucket 100/mo.
5. **Next agent build work**: wave 2 (51 → 52 → 53) through the review loop; spec 50's migration; spec 45 (0047); the 3 Dependabot PRs (the weekly job's job).

## Pointers

- Repo entry points: `CLAUDE.md` → `SPEC.md` → `specs/README.md` → owning `docs/adr/<area>.md` → `specs/MIGRATIONS.md`; changelog `site/updates.md`; what's-next `site/tasks.md`; device checklist `docs/device-test-plan.md`; E2E policy `docs/ACCEPTANCE_TESTS.md`; PRD `docs/prd/recipe-engagement.md`; project skills `.claude/skills/pantry-*`.
- Public: https://ezybg7.github.io/pantry/ (landing · `/privacy` · `/dev/…` dashboard). Worker: https://pantry-api.everettzyan.workers.dev. Neon Data API host `ep-autumn-dew-a6utgshf.apirest.us-west-2.aws.neon.tech` (production; drop `-pooler` for psql/DDL).
- Orchestrator skills on the mini (`~/agents/skills`, symlinked as `~/.claude/skills`): `orchestrator` (the board procedure — load first for anything Multica), `hermes-local-gateway-ops`, `delegate-to-claude`, `claude-worker-env`, `nightly-maintenance`, `github-workflow`, `memory-protocol`, `typescript-style`.