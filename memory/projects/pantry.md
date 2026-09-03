---
title: pantry
type: note
permalink: agents/projects/pantry
---

# Ambry (repo: pantry)

_Updated: 2026-09-03 · Repo: github.com/ezybg7/pantry (private) · Local on the mini: ~/code/pantry (also reachable as ~/Code/pantry — APFS is case-insensitive)_

**2026-09-03 ground-truth reset.** Rewritten from GitHub + `origin/main` the day Everett made the M4 Mac mini the primary workplace. The previous version of this note had a Status board that stopped at 2026-08-19 while ~400 commits (PRs #11–#139) landed from the laptop and Claude Code web sessions; the mini's clone was never pulled, so the nightly reflection kept re-reporting carry-overs that had been resolved for weeks (see "Retired carry-overs" — do not resurrect them). The old note, including its fold-provenance ledger, is in this vault's git history (`ezybg7/m4-mini-orchestrator`, commit `ca6fc07` = backup 2026-09-03); `daily-log/archive/` remains the record of the folds.

## What it is

Mobile pantry tracker: household inventory with auto-estimated expirations, self-organizing storage locations, capture by type-ahead / barcode / receipt photo, grocery list, and recipes (deterministic "what can I make" + AI ideas + a growing community layer). Public multi-user app, iOS first. **SPEC.md in the repo is product truth; specs/README.md is the status board; this note is the summary plus the machine/orchestration facts the repo deliberately does not hold.**

## Machines & roles (2026-09-03)

- **M4 Mac mini** (`m4-mini`, user `orchestrator`) — **primary workplace from 2026-09-03.** Hosts the orchestration: Hermes gateway (launchd `com.user.hermes`), the Claude worker queue (launchd `com.user.claude-worker` watching `~/agents/queue`), and cron — hc-ping every 10 min, `watchdog.sh` every 30 min, `backup.sh` 02:30 (commits + pushes `~/agents` to `ezybg7/m4-mini-orchestrator`, pushes `~/agents/skills` all branches), `nightly-reflection.sh` 03:00 (queues the reflect task), `pantry-weekly-maintenance.sh` Mon 09:00 (Dependabot triage + Apple-secret expiry watch).
- **MacBook** (user `ezy`, repo `~/Code/pantry`) — still in use. It is where Xcode, the simulator, Maestro and the EAS device loop live (the 08-30/31 smoke + acceptance runs happened there). `gh` is not installed there, so the GitHub MCP server is the PR interface on that machine; the repo CLAUDE.md is written from its point of view.
- **Windows box**: `C:\Users\evere\projects\pantry`.
- **Sync is GitHub only**: code via `ezybg7/pantry`, this vault via the nightly backup of `ezybg7/m4-mini-orchestrator`. Nothing else syncs between machines — `git pull` first, every session, on every machine.

## Stack (since the 2026-07-29 cutover, spec 36)

- **App**: Expo SDK 57 · React Native 0.86 · React 19.2 · TypeScript 6 · Expo Router. Device loop = **EAS development build on Everett's iPhone** (`npx expo start --dev-client`); Expo Go and the SDK-54 pin were retired 2026-08-08 (spec 15). Native changes (new module, config plugin, SDK bump) need a fresh `eas build --profile development --platform ios`.
- **Backend**: **Neon** Postgres (RLS, PostgREST-compatible Data API spoken by `@supabase/postgrest-js` in `src/lib/dataClient.ts`) + **self-hosted Better Auth on the Worker** (spec 46, cut over 2026-08-22 — replaced Neon Managed Auth; migrations 0048/0049, PRs #109/#120) + **Cloudflare Workers** (`workers/`, API `https://pantry-api.everettzyan.workers.dev`), R2 photos, one Durable Object per household for realtime.
- **AI**: Claude **Haiku 4.5** for every AI route (receipt vision, shelf-life, ideas, import), server-side only; `RECEIPT_PROVIDER=mock` is the one key-free dev switch; escalate per route with `IDEAS_MODEL` / `IMPORT_MODEL` / `ANTHROPIC_MODEL`. The Gemini arm was deleted in the 08-22 security pass.
- **Hard rules** (enforced by `.claude/hooks/guard-bash.mjs`, which inspects every Bash command — even quoting the forbidden commands inside a heredoc gets blocked): no Docker, no local Supabase, no emulator — everything runs against Neon branches; never force `npm audit fix` (it downgrades expo). `supabase/migrations/` is only the historical directory name; migrations are rehearsed on a Neon branch then applied by hand with psql on the direct endpoint (`specs/MIGRATIONS.md`).
- **Env**: `.env` needs `EXPO_PUBLIC_DATA_API_URL`, `EXPO_PUBLIC_AUTH_URL`, `EXPO_PUBLIC_WORKER_URL` (the client throws without them); the values equal `eas.json`'s profiles. Worker secrets go through `wrangler secret put` from `workers/` (`ANTHROPIC_API_KEY`, `RECEIPT_PROVIDER`, `APPLE_CLIENT_SECRET`, `YOUTUBE_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, …).
- **Identifiers**: display name **Ambry** (rebrand 2026-07-31, PR #68), bundle id `com.everettyan.ambry`, Apple team `SANRTXS285`; repo/package/slug/infra stay `pantry`. Dev login **test@pantry.dev / password123** (household "Test Home", invite `testhome`) lives in production Neon — read freely, **write only on a disposable Neon branch** (rule of 2026-08-31); the acceptance flows assume that account owns zero recipes/folders.
- **Gates**: `npm run typecheck` · `npm run lint` · `npm test` · workers `npm run typecheck` — `ci.yml` runs all four on push/PR. `npm run test:acceptance` = Maestro (needs a signed simulator build + a warm Neon branch; deliberately not in CI). `nightly-sync.yml` reports branch drift into issue #26. `pages.yml` publishes `docs/privacy.md` + `site/` to https://ezybg7.github.io/pantry/ (`site/` is PUBLIC — never a secret there).

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

## Standing gotchas that still apply

- Never pin a dated Claude model id in code; resolution is `claude-haiku-4-5*` + env-var escalation.
- Receipt/photo images are never persisted (privacy invariant) — only the `ai_calls` row survives; scans and ideas are monthly-bucketed (ideas 3/mo free, 100/mo Plus).
- Every migration ships its own GRANTs (Neon applies no default privileges either); `db/neon-grants.sql` restates them idempotently; `recipes` grants are **column-scoped** since 0050 — new author-editable columns must be granted explicitly.
- Both colour schemes are live (spec 18, `src/lib/theme.ts`, ≥4.5:1 contrast asserted in `theme.test.ts`) — never hardcode light colours.
- Toolchain: `create-expo-app` is broken under npm 12 (extract the template tarball); CocoaPods dies silently without a UTF-8 locale; Maestro needs Homebrew's JDK on `JAVA_HOME`; the auth service rejects foreign `Origin` headers; unattended suite runs need the lid open + `caffeinate`.
- The Sign-in-with-Apple client secret (ES256 JWT) **expires 2027-02-18**; the weekly script warns under 30 days and prints the regeneration commands (`scripts/apple-client-secret.mjs`, key id `YK8V7A579F`).
- Orchestrator/infra tooling never goes in the pantry repo (PR #101 was closed for exactly that) — it lives in `~/agents`.

## Mini-specific dev facts (set up 2026-09-03)

- Clone fast-forwarded `53ab58f` → `838f135`; `npm ci` in root (711 packages) and `workers/` (45; **wrangler 4.125 is available as `npx wrangler` from `workers/`**); **typecheck (root + workers), lint and jest (110/1715) all green** on Node 26.5 / npm 12 (CI pins Node 22). CodeGraph daemon running, index 380 files.
- `.env` rewritten to the Neon + Cloudflare values (identical to eas.json's `development` profile, plus the public Google iOS client id); the Supabase-era file is kept as `.env.supabase-era.local` (gitignored).
- **Present**: node 26.5, npm 12, gh 2.96 (authed `ezybg7`, ssh), codegraph 1.4.1, OrbStack/Docker 29 (needed only for the `.mcp.json` `docker-gateway` MCP — Context7 + sequentialthinking; start OrbStack or those tools simply don't appear), Homebrew, Command Line Tools, ollama, tailscale, hermes, basic-memory, supabase CLI 2.109 (obsolete for this project).
- **Missing**: **Xcode** (only CLT → no iOS simulator, no `npm run ios`, no Maestro runs on the mini), `eas-cli` (`npm i -g eas-cli` + `eas login` when a build is needed), `maestro`, `psql` (`brew install libpq` before a migration apply; see `scripts/psql.mjs`), watchman (optional). The device loop still works from the mini: `npx expo start --dev-client` serves Metro over LAN to the iPhone's installed dev client.
- Twelve July-era local branches have no remote any more (`feat/receipt-parsing`, `feat/vision-model-selection`, `chore/spec-audit-tracking-issues`, `feat/jetson-orin-setup-plan`, `feat/nightly-pull-routine`, `feat/orchestration-hardening`, `feat/receipt-capture`, `feat/roadmap-specs`, `feat/capture-specs`, `feat/sdk-54`, `feat/scaffold`, `feat/initial-spec`) — dead ends, safe to `git branch -D`, left in place. A **locked** worktree entry `.claude/worktrees/pantry` (branch `worktree-pantry`) points at a directory that no longer exists — `git worktree unlock` + `git worktree prune` when convenient.
- **Weekly maintenance** (`~/agents/pantry-weekly-maintenance.sh`, Mon 09:00) had failed on 08-24 and 08-31 with "Not logged in" because cron's `claude -p` had no OAuth token. Fixed 2026-09-03: it now exports `CLAUDE_CODE_OAUTH_TOKEN` from `~/.claude/oauth_token` exactly as `claude-worker.sh` does, and its prompt says `gh` IS installed here (the GitHub MCP plugin does not connect on the mini — "does not support dynamic client registration"). First real run: Mon 2026-09-07 09:00, with the 3 Dependabot PRs waiting. Not test-run by hand (it merges PRs).
- `~/.claude/settings.json` carries two dead `Write(...)` allow rules that print a warning on every headless run (only `Edit(path)` rules count, and the matching Edit rules already exist) — cosmetic, unfixed.

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

## Pointers

- Repo entry points: `CLAUDE.md` → `SPEC.md` → `specs/README.md` → owning `docs/adr/<area>.md` → `specs/MIGRATIONS.md`; changelog `site/updates.md`; what's-next `site/tasks.md`; device checklist `docs/device-test-plan.md`; E2E policy `docs/ACCEPTANCE_TESTS.md`; PRD `docs/prd/recipe-engagement.md`; project skills `.claude/skills/pantry-*`.
- Public: https://ezybg7.github.io/pantry/ (landing · `/privacy` · `/dev/…` dashboard). Worker: https://pantry-api.everettzyan.workers.dev. Neon Data API host `ep-autumn-dew-a6utgshf.apirest.us-west-2.aws.neon.tech` (production; drop `-pooler` for psql/DDL).
- Orchestrator skills on the mini (`~/agents/skills`, symlinked as `~/.claude/skills`): `hermes-local-gateway-ops`, `delegate-to-claude`, `claude-worker-env`, `nightly-maintenance`, `github-workflow`, `memory-protocol`, `typescript-style`.
