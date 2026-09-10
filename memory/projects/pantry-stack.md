---
type: project
title: Ambry stack
description: App, backend, AI, hard rules, env vars and CI gates for Ambry as of the
  2026-07-29 cutover.
tags:
- pantry
- stack
- database
timestamp: 2026-09-03 00:00:00+00:00
permalink: agents/projects/pantry-stack
---

# Ambry stack

Part of [Ambry / pantry](pantry.md).

## Stack (since the 2026-07-29 cutover, spec 36)

- **App**: Expo SDK 57 · React Native 0.86 · React 19.2 · TypeScript 6 · Expo Router. Device loop = **EAS development build on Everett's iPhone** (`npx expo start --dev-client`); Expo Go and the SDK-54 pin were retired 2026-08-08 (spec 15). Native changes (new module, config plugin, SDK bump) need a fresh `eas build --profile development --platform ios`.
- **Backend**: **Neon** Postgres (RLS, PostgREST-compatible Data API spoken by `@supabase/postgrest-js` in `src/lib/dataClient.ts`) + **self-hosted Better Auth on the Worker** (spec 46, cut over 2026-08-22 — replaced Neon Managed Auth; migrations 0048/0049, PRs #109/#120) + **Cloudflare Workers** (`workers/`, API `https://pantry-api.everettzyan.workers.dev`), R2 photos, one Durable Object per household for realtime.
- **AI**: Claude **Haiku 4.5** for every AI route (receipt vision, shelf-life, ideas, import), server-side only; `RECEIPT_PROVIDER=mock` is the one key-free dev switch; escalate per route with `IDEAS_MODEL` / `IMPORT_MODEL` / `ANTHROPIC_MODEL`. The Gemini arm was deleted in the 08-22 security pass.
- **Hard rules** (enforced by `.claude/hooks/guard-bash.mjs`, which inspects every Bash command — even quoting the forbidden commands inside a heredoc gets blocked): no Docker, no local Supabase, no emulator — everything runs against Neon branches; never force `npm audit fix` (it downgrades expo). `supabase/migrations/` is only the historical directory name; migrations are rehearsed on a Neon branch then applied by hand with psql on the direct endpoint (`specs/MIGRATIONS.md`).
- **Env**: `.env` needs `EXPO_PUBLIC_DATA_API_URL`, `EXPO_PUBLIC_AUTH_URL`, `EXPO_PUBLIC_WORKER_URL` (the client throws without them); the values equal `eas.json`'s profiles. Worker secrets go through `wrangler secret put` from `workers/` (`ANTHROPIC_API_KEY`, `RECEIPT_PROVIDER`, `APPLE_CLIENT_SECRET`, `YOUTUBE_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, …).
- **Identifiers**: display name **Ambry** (rebrand 2026-07-31, PR #68), bundle id `com.everettyan.ambry`, Apple team `SANRTXS285`; repo/package/slug/infra stay `pantry`. Dev login **test@pantry.dev / password123** (household "Test Home", invite `testhome`) lives in production Neon — read freely, **write only on a disposable Neon branch** (rule of 2026-08-31); the acceptance flows assume that account owns zero recipes/folders.
- **Gates**: `npm run typecheck` · `npm run lint` · `npm test` · workers `npm run typecheck` — `ci.yml` runs all four on push/PR. `npm run test:acceptance` = Maestro (needs a signed simulator build + a warm Neon branch; deliberately not in CI). `nightly-sync.yml` reports branch drift into issue #26. `pages.yml` publishes `docs/privacy.md` + `site/` to https://ezybg7.github.io/pantry/ (`site/` is PUBLIC — never a secret there).