---
type: decision
title: Self-hosted Better Auth on the Worker
description: 2026-08-22 (spec 46) - replaced Neon Managed Auth; migrations 0048/0049,
  PRs
tags:
- pantry
- stack
- security
timestamp: 2026-08-22 00:00:00+00:00
permalink: agents/decisions/self-hosted-better-auth-2026-08-22
---

# Self-hosted Better Auth on the Worker (2026-08-22, spec 46)

**Decision.** Auth is **Better Auth self-hosted on the Cloudflare Worker**,
replacing Neon Managed Auth. Migrations 0048/0049, PRs #109/#120.

**Consequences.**
- A child Neon branch's Data API inherits production's auth providers — the
  "Other" provider is the Worker's own JWKS — so a branch needs no auth setup.
- The auth service rejects foreign `Origin` headers.
- The Apple arm was parked on 2026-08-11 for "Neon Auth has no apple provider".
  **That park predates this cutover** and the `APPLE_CLIENT_SECRET` set on 08-22 —
  re-read `specs/auth-provider-migration.md` and `docs/adr/auth.md` D11 before
  repeating it.

**Same-day security pass.** The Gemini adapter was deleted; Claude **Haiku 4.5**
serves every AI route, server-side only.

Related: [Ambry stack](../projects/pantry-stack.md) ·
[Neon + Cloudflare cutover](neon-cloudflare-cutover-2026-07-29.md)