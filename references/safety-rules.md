---
type: reference
title: Safety rules
description: What requires Everett's explicit word, how secrets are handled, and the operations that are never taken unilaterally.
tags: [safety, secrets, database, infra]
timestamp: 2026-09-10T00:00:00Z
---

# Safety rules

Layer 3 reference. **Read before any production action.** Every rule here is
sourced from a decision already recorded in this vault — the source is named so
the rule can be traced back and corrected at the source (SPEC.md I10).

## Requires Everett's explicit word

- **Applying a migration to production.** Rehearsal on a Neon branch is
  autonomous; the production apply is not. The phrasing that counts is an
  explicit "apply to production".
  → [Everett-only items](../memory/projects/pantry-everett-only-2026-09-04.md)
- **Merging the `nightly-2026-*` skill branch chain.** These are pushed, never
  PR'd, and Everett merges the chain himself.
  → [daily-log](../memory/daily-log/index.md), every nightly entry
- **Anything financial** — the LLC conversion and the RevenueCat turn-on sequence
  are his, in order. → [pantry](../memory/projects/pantry.md) *Everett's plate*

## Secrets

- The production Neon **direct URL** lives in `~/agents/.env.acceptance` (mode
  600). **Never print it**, never paste it into a chat, never commit it.
- Worker secrets go through `wrangler secret put` from `workers/`. Verify with
  `wrangler secret list` — never by echoing a value.
- `site/` is published to GitHub Pages and is **PUBLIC**. Never put a secret there.
- The Sign-in-with-Apple client secret (ES256 JWT) **expires 2027-02-18**; the
  weekly job warns under 30 days.
  → [Ambry stack](../memory/projects/pantry-stack.md)

## Destructive and irreversible

- The dev account `test@pantry.dev` lives in **production** Neon. Read freely;
  **write only on a disposable Neon branch** (rule of 2026-08-31).
- Never force `npm audit fix` — it downgrades expo.
- No Docker, no local Supabase, no emulator. Enforced by
  `.claude/hooks/guard-bash.mjs` in the pantry repo, which inspects every Bash
  command — quoting a forbidden command inside a heredoc is blocked too.
- Receipt and photo images are **never persisted** (privacy invariant). Only the
  `ai_calls` row survives.
- Never pin a dated Claude model id in code; resolution is `claude-haiku-4-5*`
  plus env-var escalation.
  → [Ambry operational gotchas](../memory/projects/pantry-gotchas.md)

## Autonomy boundary

Do the work; don't hand it back. Restart services, apply migrations **to a
branch**, reset/seed, install deps, run the app to verify. A blocked sandbox tool
is a tooling limit, not a user question — note the exact command and continue.

Escalate only for genuine design decisions, and escalate **in the PR**, never by
blocking a task. → `queue/.preamble.md`
