---
type: project
title: Everett-only items (2026-09-04)
description: 'The DB applies and deploys only Everett can do: migrations 0047/0053/0054 with their assert counts, the USDA seed, and the Worker deploys.'
tags: [pantry, infra, database, release, acceptance, memory]
timestamp: 2026-09-04T00:00:00Z
permalink: agents/projects/pantry-everett-only-2026-09-04
---

# Ambry — Everett-only items as of 2026-09-04 evening (durable copy; the session scratchpad was wiped at a process restart)

## DB applies (apply-before-merge; rehearse on a Neon branch first; psql on the direct endpoint; `-1` per file; asserts must read ALL n PASSED)
**APPLIED 2026-09-05 11:17–11:18 EDT by the orchestrator at Everett's word ("you apply 0054 and 0053, merge #161"): 0054 8/8 live, 0053 16/16 live, grants replayed (122), both suites green again; production direct URL now in ~/agents/.env.acceptance as NEON_DIRECT_URL (600; never print it). Remaining: 0047 + the USDA seed.** Update 2026-09-04 21:50 EDT — all three rehearsed clean tonight on `acceptance-2026-09-03` (`br-damp-art-a6r6pyld`, reset from production at ~21:40 EDT, expiry now 2026-09-05 21:42 EDT), psql direct endpoint as neondb_owner, `-v ON_ERROR_STOP=1 -1` per file, order 0054 (8/8) → 0053 (16/16) → #161 neon-grants.sql replay (119 stmts) → 0054 asserts 8/8 → 0047 (7/7) → 0053 asserts 16/16. Production applies still need Everett's explicit "apply to production" (and the production direct URL, never pasted in chat: same Connect-dialog copy flow into ~/agents/.env.acceptance as NEON_DIRECT_URL). The 0047 seed: Everett said yes 2026-09-05 10:35 EDT; generated + rehearsed (13,587 rows, 3.8 s, asserts 7/7, prefilter 8.3 ms); file `~/agents/usda/usda-foods-seed.sql`; production apply is his (after 0047).

1. **0047_usda_foods.sql** (spec 45, PR #156) — 7 assertions. Also its data seed: approve downloading the three FDC datasets (~200 MB; URLs in scripts/usda-match/README.md on the PR branch), run `python3 scripts/usda-match/export-usda-foods.py` → db/apply/usda-foods-seed.sql, apply the seed after the migration; then `db/neon-grants.sql` (it now names usda_foods). Then I merge #156.
2. **0053_merge_integrity.sql** (PR #161) — 16 assertions; then re-apply `db/neon-grants.sql` (column-scoped UPDATE grants). Then I merge #161.
3. **0054_creator_profiles.sql** (spec 51, already on main) — 8 assertions. Users see "Couldn't load your profile" on the Profile tab until this is applied.
4. Later (files not written yet): 0058 entitlements.source sandbox, 0059 claim_ai_call UTC cast, 0060 entitlements.last_event_at (RevenueCat go-live), 0061–0063 monetization (welcome grant, member cap 3, barcode daily split), 0057 reserved for spec 50.

## Deploys
- `wrangler deploy` from workers/ (Everett's token): #157/#162/#163/#164/#165/#168/#169/#174 changed the Worker (AASA webcredentials section, digest window, billing routes dark until secrets, rate limits). Confirm BETTER_AUTH_SECRET, AUTH_BASE_URL, RESEND_API_KEY are set first. Smoke after deploy: `show timezone` = UTC through the pooler (scanQuota), one digest tick, AASA at /.well-known/apple-app-site-association shows both applinks and webcredentials.
- New EAS dev build: app.json gained `webcredentials:pantry-api.everettzyan.workers.dev` (#174); native modules not added on purpose (no datetimepicker, clipboard, application, alternate icons yet).
- Sentry D13 steps: create the project, EXPO_PUBLIC_SENTRY_DSN in eas.json profiles, then drop SENTRY_DISABLE_AUTO_UPLOAD for production with SENTRY_ORG/PROJECT/AUTH_TOKEN as EAS secrets, verify a real crash arrives.

## Consoles / secrets
- Rotate/retire the seeded dev account (test@pantry.dev / password123 documented in supabase/seed.sql) before beta; when rotated, put the new value in ~/agents/.env.acceptance (chmod 600).
- Anthropic console budget alert; Expo EXPO_ACCESS_TOKEN as a Worker secret (push sends are unauthenticated until then).
- RevenueCat go-live gate (do NOT set REVENUECAT_WEBHOOK_SECRET / REVENUECAT_SECRET_KEY until): (1) db/asserts/revenuecat_webhook_upsert.sql green on a branch — **DONE 2026-09-04 22:35 EDT: ALL 12 PASSED on acceptance-2026-09-03 (production copy)**; (2) 0060 last_event_at ordering shipped (closes the annual-refund → monthly re-subscribe lockout and the TRANSFER-giver variant); (3) the later-end stale-event assert case; then `wrangler secret put REVENUECAT_SECRET_KEY` + webhook secret; transfer setting = transfer to new App User ID; Family Sharing OFF.

## Decisions (defaults picked; overrule in a PR comment)
- Second-device push: one token per profile (last device wins); push_tokens table queued. DIGEST_WINDOW_HOURS = 3.
- Legacy reminders flag deleted, not migrated (re-seeded from the per-user pushed key).
- Email verification (unset), barcode counter (fixed by L9 in the monetization phase), PDF page cap (cap pages), dateless spice re-add, quota window (UTC), beta free tier vs O3, owner-gate semantic, retention 13 months, Guideline 1.2 posture, OTA ADR, twelve empty seed foods.
- Design: primary button = ink (contrast-measured); "Cook becomes the tab" not now; visibility memory: remember private↔household only; first-run cut to one message; native date picker + clipboard paste wait for a native build; reminder time picker queued; A7's one-tap add supersedes ADR capture-vision D3's 2026-07-26 revision; grocery row lost its trash while expiring keeps one (SPEC.md §4); haptics seam admits one success tick.
- PR #176 (specs 55/56 Obsidian + Codex): approve with the amendments in my consolidated comment; six questions answered there. Merge is yours.
- PR #142 (spec 54 load testing): yours.
- Monetization ⭐ DECIDED 2026-09-04 22:19 EDT (page reply "sure go ahead"): $4.99/mo · $29.99/yr · 14-day trial with an in-trial cap (60 scans / 20 ideas); ASC + STATIC_PACKAGES must match. Also decided the same minute: perks default (drop priority learning, defer themes/rich export), hashed-email grant ledger, email verification at sign-up ON (K7), #176 parked until the project is done, #142 reviewed by the orchestrator. Welcome grant 10 scans + 3 ideas; free scans 10 → 8; free members 2 → 3; barcode never metered; community publishing free; no lifetime SKU; paywall 3.1.2 price-prominence fix; Apple Small Business Program enrol before launch.

## Phone / device passes
- Airplane-mode matrix (spec 12); AutoFill with an empty keychain after the AASA deploy + new build; camera-first receipt flow; swipe gestures (expiring leading/trailing, grocery trailing); zones drag; OverflowMenu sheet→second-modal timing (ten opens each); the Add tab badge label order with a staged basket; acceptance scenario 1's reset half.

## Acceptance (delegated 2026-09-04 21:20 EDT: Everett gives the branch's DIRECT URL; I rehearse 0047/0053/0054 + the FDC seed on it, verify the asserts, then run the acceptance suite against the same branch; PRODUCTION applies only if he also puts NEON_DIRECT_URL in the env file and says "apply to production")
- The Neon branch acceptance-2026-09-03 expired 20:47 EDT before a clean run. Create a fresh branch AFTER the applies above (so it carries 0047/0053/0054), enable its Data API, put `ACCEPTANCE_BRANCH_URL=https://<ep>.apirest.<region>.aws.neon.tech/neondb/rest/v1` and the branch's direct URL as `NEON_BRANCH_DIRECT_URL=postgresql://…` into ~/agents/.env.acceptance (chmod 600); I run ~/agents/scripts/acceptance-cycle.sh. The sign-out regression fix must be merged first or scenario 1 fails.
**Acceptance update 2026-09-04 21:50 EDT:** Everett let me drive his Chrome ("M4 Mini") in the Neon console instead of handing over URLs. Done there with his approval: 8 stale rehearsal branches deleted (project 2/10), `acceptance-2026-09-03` reset from production, its direct URL copied via the clipboard into `~/agents/.env.acceptance` (`NEON_BRANCH_DIRECT_URL`, plus `ACCEPTANCE_BRANCH_URL`; both single-quoted because the URL carries `&`). Cycle c3 (`~/agents/scripts/acceptance-cycle.sh c3`, log `~/agents/logs/acceptance-c3.log`) launched 21:47 EDT against the branch with 0054/0053/0047 applied, main at dfcd0f0 (includes the #181 sign-out fix).

**Update 2026-09-05 07:10 EDT:** #142 (spec 54) merged by the orchestrator at Everett's delegation. New for Everett's approval: #182 (spec 23, decisions written in; round 2 in flight) and #185 (spec 57 email verification, strict gate default). Screen-directions gallery published for his per-screen decisions: https://claude.ai/code/artifact/35a97b24-9c2f-4841-b4e1-d3f130bb31d9 (decisions land in the artifact's `decisions` collection — read with read_db). Acceptance 12/12 on the reset branch (PR #186).

**Rotation list 2026-09-05 (see ~/agents/security/rotation-2026-09-05.md):** (1) Neon `neondb_owner` password — the branch direct URL (same password) sat in the private vault repo for one push; reset in the console, then update `~/agents/.env.acceptance` and any Worker secret using the owner role. (2) test@pantry.dev / password123 — documented in the repo and a live production credential; rotate, move the value to env, strip it from docs/seed script. (3) Delete the three `@ambry-test.invalid` residue accounts on production auth.
