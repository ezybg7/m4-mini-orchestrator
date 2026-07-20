---
title: pantry
type: note
permalink: agents/projects/pantry
---

# Pantry

_Updated: 2026-07-17 · Repo: github.com/ezybg7/pantry (private) · Local: ~/code/pantry_

Mobile pantry tracker: household inventory with auto-estimated expirations, self-organizing storage locations, and recipes (deterministic "what can I make" matching + AI ideas). Public multi-user app. Full spec lives in the repo's SPEC.md — that file is the source of truth; this note is the summary.

## Stack decision (2026-07-17 kickoff interview)

- **Expo / React Native (TypeScript)** — Everett wants Apple App Store first, Google Play later; PWA explicitly ruled out (no reliable Apple review path for wrapped web apps). SwiftUI rejected to avoid a second Android codebase.
- **Pinned to Expo SDK 54** (2026-07-17): App Store Expo Go is stuck at SDK 54 by Apple's review backlog, and Everett tests on-device via Expo Go (no Xcode, no paid Apple Developer yet). Scaffold was SDK 57 → downgraded. Upgrade back to current SDK in one hop when we switch to development builds (M4 push notifications force that anyway; Apple Developer enrollment ~$99 needed then too).
- **Supabase** — Postgres + RLS (household-scoped), Auth (email + Sign in with Apple), Storage, Realtime, Edge Functions.
- **Claude API** (`claude-sonnet-5`) via Edge Functions only: photo→items recognition, shelf-life estimates for unknown items, recipe ideas from expiring stock.
- Open Food Facts for barcode lookup; TanStack Query client-side.
- v1 scope calls: online-required (no offline sync), quantities are 3-state (stocked/low/out), capture = type-ahead + barcode + photo AI (no voice), push = daily expiry digest via Expo push.
- Recipe visibility (decided 2026-07-17): three tiers — `private` (owner only, default), `household` (owner's household members), `public` (community). 

## Schema sketch

- `profiles`, `households`, `household_members` (role owner/member, invite code join)
- `catalog_items` — global: name, aliases, category, `shelf_life` jsonb (days per storage kind: pantry/fridge/freezer/counter), barcodes, source seed|user|ai
- `storage_locations` (household, kind drives shelf-life pick) → `zones` (custom groups, drag-pin overrides auto category grouping)
- `inventory_items` — household instance: catalog ref or free-text name, location + optional zone pin, status stocked|low|out, added_at, expires_at + expiry_source shelf_life|ai|manual (manual always wins; recompute on location-kind move)
- `recipes` (owner, visibility private|household|public) → `recipe_ingredients` (catalog ref or free text, optional flag), `recipe_saves`, `recipe_reports`
- Matching rule: ingredient in stock ⇔ catalog/name match with status ≠ out; rank fully-makeable (favoring soon-expiring usage), then missing-1, missing-2.

## Open questions

1. Catalog seed: verify USDA FoodKeeper data (public domain?) and build ~200-item seed (~90 hand-written items shipped in scaffold).
2. AI cost control: per-user daily caps; monetization undecided (free during beta).
3. App Store display name — "Pantry" is crowded; bundle id TBD before M4.
4. Community moderation beyond report + manual takedown if usage grows.
5. Recipe import from URL — v2 candidate.

## Roadmap authority

**specs/README.md in the repo is now the single source of truth for all remaining work** — 19 specs with status board, dependency graph, build order (Phase A: features in Expo Go+local → Phase B: hosted Supabase → Phase C: EAS/dev builds/App Store), migration number registry (0004–0010 reserved), and cold-session resume checklist. Read it before doing anything in this project.

## Status

- 2026-07-17: repo created; SPEC.md + CLAUDE.md on **PR #1** (`feat/initial-spec`, updated same day with three-tier recipe visibility) — awaiting Everett's review/merge.
- 2026-07-17: scaffold on **PR #2** (`feat/scaffold`) — Expo SDK 57 app (TS strict, expo-router tabs: pantry/expiring/add/recipes/settings), Supabase migration `0001_init.sql` (full schema, RLS, `create_household`/`join_household` RPCs, new-user trigger), ~90-item catalog seed, email auth + household onboarding, location + item CRUD with computed expiry and manual override, category/zone grouping with urgency sort (19 unit tests on the pure logic), GitHub Actions CI (typecheck/lint/test). CodeGraph index initialized locally (gitignored). Supabase CLI not installed on this machine — config.toml is hand-written minimal; `supabase init --force` regenerates.
- 2026-07-20: receipt-capture backend+client merged (PRs #7, #8 squashed into main). **Hardening on PR #9** (`feat/orchestration-hardening`): Gemini mock provider (`RECEIPT_PROVIDER=mock` → Gemini-free dev), `thinkingConfig.thinkingBudget:0` (fixes MAX_TOKENS→502 on the thinking model `gemini-3.5-flash`), client `unavailable` vs `retry` error split, spec errata (Gemini free tier is **~20 req/day per model**, not ~1,500), and a worker **Autonomy & escalation** policy in repo CLAUDE.md + queue preamble. New design spec `specs/local-vision-model.md` (local VLM plan, needs go/no-go). Checks green (40 tests). Restarted the local **edge runtime** (was stopped → the 07-20 503 root cause; `functions serve` detached pid 37757, log `~/agents/logs/pantry-functions-serve.log`). Catalog still empty — needs `supabase db reset` (NOT auto-run: destructive).
- Next: Everett review/merge **PR #9**; decide local-vision-model go/no-go + give the app its own Gemini key (the shared-key 20/day issue); `supabase db reset` to seed the catalog; device-test a real receipt. Roadmap continues: barcode (#2) → ai-shelf-life (#3) → zones (#4) → realtime (#5).