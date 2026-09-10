---
type: entity
title: Ambry Cloudflare Worker
description: The API surface - routes, secrets, deploy command, and what to smoke-test
  after a deploy.
resource: https://pantry-api.everettzyan.workers.dev
tags:
- pantry
- infra
- stack
timestamp: 2026-09-05 00:00:00+00:00
permalink: agents/entities/ambry-worker
---

# Ambry Cloudflare Worker

`workers/` in the pantry repo · API `https://pantry-api.everettzyan.workers.dev`

- **Deploy**: `wrangler deploy` from `workers/` (Everett's token). `npx wrangler`
  resolves to 4.125 from `workers/` on the mini.
- **Serves**: the AI routes (receipt vision, shelf-life, ideas, import — all
  Haiku 4.5, server-side only), self-hosted Better Auth, billing routes, and the
  AASA document at `/.well-known/apple-app-site-association`.
- **Secrets** via `wrangler secret put`: `ANTHROPIC_API_KEY`, `RECEIPT_PROVIDER`,
  `APPLE_CLIENT_SECRET`, `YOUTUBE_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`,
  `BETTER_AUTH_SECRET`, `AUTH_BASE_URL`, `RESEND_API_KEY`. Verify with
  `wrangler secret list` — never by echoing a value.
- **Smoke after deploy**: `show timezone` = UTC through the pooler (scanQuota);
  one digest tick; AASA shows both `applinks` and `webcredentials`.

Related: [Ambry stack](../projects/pantry-stack.md) ·
[Safety rules](../../references/safety-rules.md) · [Neon project](neon-project.md)