---
type: decision
title: Cutover from Supabase to Neon + Cloudflare
description: 2026-07-29 (spec 36) - Neon Postgres plus Cloudflare Workers replaced
  Supabase; no Docker, no local stack.
tags:
- pantry
- database
- stack
timestamp: 2026-07-29 00:00:00+00:00
permalink: agents/decisions/neon-cloudflare-cutover-2026-07-29
---

# Neon + Cloudflare cutover (2026-07-29, spec 36)

**Decision.** Ambry's backend is **Neon** Postgres (RLS, PostgREST-compatible
Data API) plus **Cloudflare Workers**, R2 for photos, and one Durable Object per
household for realtime.

**Consequence — the hard rule.** No Docker, no local Supabase, no emulator.
Everything runs against Neon branches. `supabase/migrations/` is only the
historical directory name; migrations are rehearsed on a Neon branch, then applied
by hand with psql on the **direct** endpoint. Enforced in the pantry repo by
`.claude/hooks/guard-bash.mjs`.

**Follow-on.** Auth moved again on 2026-08-22 — see
[self-hosted Better Auth](self-hosted-better-auth-2026-08-22.md).

Related: [Ambry stack](../projects/pantry-stack.md) ·
[Safety rules](../../references/safety-rules.md)