---
title: pantry
type: note
permalink: agents/projects/pantry
---

# Pantry

_Updated: 2026-07-21 · Repo: github.com/ezybg7/pantry (private) · Local: ~/code/pantry_
_(2026-07-17 daily-log folded in during the 2026-07-25 nightly archival; 2026-07-18 folded in during the 2026-07-26 nightly — durable fixtures/gotchas below. 07-18's Gemini→Claude vision evolution + spec suite are already in the Status entries; its Hermes model-swap saga lives in the `hermes-local-gateway-ops` skill and its duplicate-run/queue-lifecycle fixes in `delegate-to-claude` — nothing lost.)_
_(2026-07-19 daily-log folded in during the 2026-07-27 nightly archival — **nothing new to add**: its durable facts were all already captured. The receipt-capture client (PR #8) is in the Status board; the permanent `test@pantry.dev`/`password123` login is under Local dev fixtures; the worker node/npm PATH copy-trick is in the `claude-worker-env` skill; and the "0% Claude usage" investigation, `delegate_task` ban, SOUL.md rewrite, Gemini-flip tripwire, and launchd queue-runner live in `hermes-local-gateway-ops` + `delegate-to-claude`.)_
_(2026-07-21 daily-log folded in during the 2026-07-29 nightly archival — **one genuinely new fold** (first non-no-op since archival began): the receipt-parsing/purchase-date half was already in the Status board (2026-07-21 entry), but the log's **second** deliverable — the spec-audit → `chore/spec-audit-tracking-issues` branch — was captured nowhere and is now added to Status below. The `claude-worker-env` sandbox corrections in that log (Write blocks /tmp + .git, `rm` gated → use `git clean -f`, node at /opt/homebrew/bin off-PATH, `gh` gated) already live in the `claude-worker-env` skill; the stacked-PR-rebase recovery in `github-workflow`; the Gemini 250K-tok/min limiter + persona-drift + SSH-PasswordAuthentication finding in `hermes-local-gateway-ops` — nothing lost.)_
_(2026-07-20 daily-log folded in during the 2026-07-28 nightly archival — **nothing new to add**: its durable facts were all already captured. The PR #9 (orchestration-hardening) and PR #10 (vision-model-selection) work, the #9-merge/#10-un-stack rebase, and the barcode-#2 prep are all in the Status board; the Claude Haiku 4.5 production decision is in "AI vision provider gotchas" + Status; the 503 edge-runtime-down root cause, `supabase functions serve`-vs-`start`, OrbStack xbin docker, and destructive `db reset` live in the `claude-worker-env` skill; the `sess_12345` UUID-fabrication rule and the shared-key Gemini 20/day burn live in `hermes-local-gateway-ops` + `claude-worker-env`. The detached functions-serve pid was ephemeral (dies on reboot) — not folded.)_
_(2026-07-22 daily-log folded in during the 2026-07-30 nightly archival — **no-op, verified section-by-section**: that log was itself a nightly-reflection, and all four of its durable findings already live elsewhere — the "budget ONE probe of a gated tool" lesson in `claude-worker-env`, the "RESUME copies the session_id from the **slug's** result JSON, not the newest" lesson in `delegate-to-claude`, the idempotent-`gh`-script pattern in `github-workflow`, and its spec-audit → `chore/spec-audit-tracking-issues` deliverable already folded into the Status board (07-21 entry) during the 07-29 nightly. The recurring Discord-DNS liveness-probe errors it flagged are confirmed offline/network noise, not a bug — nothing lost.)_

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

## Local dev fixtures & gotchas (folded from 2026-07-17 setup)

- **Permanent local test login** (seeded in `seed.sql`, survives `supabase db reset`):
  **`test@pantry.dev` / `password123`** — member of household **"Test Home"** (invite
  code `testhome`) with default storage locations. Use for on-device/local smoke tests.
- **Migration-grants lesson** (`supabase-cli-migration-grants`): local Supabase CLI 2.x
  does **not** apply default privileges, so a migration that creates tables without
  explicit `GRANT`s for `anon`/`authenticated`/`service_role` makes every REST query
  fail `42501` while only `SECURITY DEFINER` RPCs work. `0001_init.sql` now ships the
  standard API-role grants (re-apply the `anon` RPC revokes **after** the blanket
  routines grant). Fixed 07-17 in `8d935fa`.
- **Mobile dark-mode UX rule**: never ship hardcoded-light screens with
  `userInterfaceStyle: automatic` — dark mode turned white-on-white TextInputs
  unreadable and silently broke signup on Everett's first device run. Always set
  explicit `color` + `placeholderTextColor` + background on every TextInput; the
  scaffold is pinned to `userInterfaceStyle: "light"` until a real dark theme exists.
- **Toolchain notes**: `create-expo-app` is broken under npm 12 (can't parse
  `npm pack --dry-run`) — worked around by extracting the expo-template tarball by
  hand. Supabase CLI is not installed here; `config.toml` is hand-written minimal.
  OrbStack needs one GUI launch to create `/var/run/docker.sock`; until then supabase
  commands need `DOCKER_HOST=unix://$HOME/.orbstack/run/docker.sock`.

_Orchestrator/host infra facts from the same 07-17 log (config.yaml YAML-parse hazard,
qwen3 40960-ctx ceiling, Tailscale argv[0] wrapper, repo hygiene) live in the
`hermes-local-gateway-ops` skill — not duplicated here._

## AI vision provider gotchas (folded from 2026-07-18)

- **Never pin a dated model id — use the `-latest` alias.** The Gemini adapter must
  target `gemini-flash-latest`; pinned/dated ids retire out from under you. (Gemini
  is now the config-flip *fallback*; Claude Haiku 4.5 is the production vision
  provider per the 2026-07-20 Status entry — but the fallback still hits this.)
- **Receipt/photo images are never persisted** — a hard privacy invariant: the
  Edge Function extracts items in-memory and drops the image; only the `ai_calls`
  row (with the 20/day/user cap, migration 0003) survives. Keep it that way when
  touching the vision path.

## Roadmap authority

**specs/README.md in the repo is now the single source of truth for all remaining work** — 19 specs with status board, dependency graph, build order (Phase A: features in Expo Go+local → Phase B: hosted Supabase → Phase C: EAS/dev builds/App Store), migration number registry (0004–0010 reserved), and cold-session resume checklist. Read it before doing anything in this project.

## Status

- 2026-07-17: repo created; SPEC.md + CLAUDE.md on **PR #1** (`feat/initial-spec`, updated same day with three-tier recipe visibility) — awaiting Everett's review/merge.
- 2026-07-17: scaffold on **PR #2** (`feat/scaffold`) — Expo SDK 57 app (TS strict, expo-router tabs: pantry/expiring/add/recipes/settings), Supabase migration `0001_init.sql` (full schema, RLS, `create_household`/`join_household` RPCs, new-user trigger), ~90-item catalog seed, email auth + household onboarding, location + item CRUD with computed expiry and manual override, category/zone grouping with urgency sort (19 unit tests on the pure logic), GitHub Actions CI (typecheck/lint/test). CodeGraph index initialized locally (gitignored). Supabase CLI not installed on this machine — config.toml is hand-written minimal; `supabase init --force` regenerates.
- 2026-07-20: receipt-capture backend+client merged (PRs #7, #8 squashed into main). **Hardening on PR #9** (`feat/orchestration-hardening`): Gemini mock provider (`RECEIPT_PROVIDER=mock` → Gemini-free dev), `thinkingConfig.thinkingBudget:0` (fixes MAX_TOKENS→502 on the thinking model `gemini-3.5-flash`), client `unavailable` vs `retry` error split, spec errata (Gemini free tier is **~20 req/day per model**, not ~1,500), and a worker **Autonomy & escalation** policy in repo CLAUDE.md + queue preamble. New design spec `specs/local-vision-model.md` (local VLM plan, needs go/no-go). Checks green (40 tests). Restarted the local **edge runtime** (was stopped → the 07-20 503 root cause; `functions serve` detached pid 37757, log `~/agents/logs/pantry-functions-serve.log`). Catalog still empty — needs `supabase db reset` (NOT auto-run: destructive).
- Next: Everett review/merge **PR #9**; decide local-vision-model go/no-go + give the app its own Gemini key (the shared-key 20/day issue); `supabase db reset` to seed the catalog; device-test a real receipt. Roadmap continues: barcode (#2) → ai-shelf-life (#3) → zones (#4) → realtime (#5).- 2026-07-20: **Production vision provider decided + implemented — PR #10** (`feat/vision-model-selection`, stacked on #9). **Claude Haiku 4.5 via Anthropic Messages API forced tool use** replaces Gemini as the production receipt/photo vision provider (Gemini kept as a config-flip fallback, mock for dev). Chosen for **no-training-by-default privacy** (Anthropic never trains on API data — no billing-conditional "wrong tier" like Gemini's free tier), top-tier thermal-receipt accuracy, and consolidation onto the `claude-sonnet-5` vendor. New `_shared/{provider,anthropic}.ts` + `anthropic.test.ts` + `RESPONSE_SCHEMA_JSON`; decision doc `specs/vision-model-selection.md`; removed `specs/local-vision-model.md` (chose cloud over self-hosted VLM). Checks green (45 tests). **This retires the "flip Gemini to paid tier" launch blocker** — the new prereq is an **Anthropic API key** (Everett, billing enabled). Next: review/merge #9→#10; provision ANTHROPIC_API_KEY; pre-beta accuracy eval on real receipts; then roadmap resumes (barcode #2 → ai-shelf-life #3 → zones #4 → realtime #5).
- 2026-07-20 (later): **PR #9 MERGED** (`14b3f86` on main). **PR #10 un-stacked and made review-ready**: it was left CONFLICTING/DIRTY when #9 squash-merged (base was #9's branch); rebased `--onto origin/main` dropping the merged commit (tip `3e744ad`, clean 16-file vision-only diff), retargeted base→main via `gh pr edit`, and triggered a fresh CI run (close/reopen) → **now OPEN · base main · MERGEABLE/CLEAN · CI green (run 29780328450)**. Ready for Everett's solo review/merge; no longer depends on #9. Barcode (#2) is unblocked and well-teed-up (capture hub + Scan placeholder already on main, `suggestLocation` shared, catalog `barcodes` col exists) but NOT started — its spec is still "draft for review" (needs sign-off), and the #2 PR will add the `expo-camera` dep + a `barcode-lookup` Edge Function.
- 2026-07-21: **Receipt PDF ingestion + purchase-date extension — branch `feat/receipt-parsing`** (3 commits, pushed; stacked on `feat/vision-model-selection`/#10). A queued "design/implement a receipt→LLM pipeline" task was **already ~90% done** (pipeline merged #7/#8/#9; Claude provider on #10) — audited first, did **not** rebuild; delivered only the delta: PDFs flow through the existing vision-provider seam (Claude `document` block, Gemini `inline_data` unchanged, index.ts accepts `application/pdf`), **no separate OCR stage**; new nullable top-level `purchase_date` (YYYY-MM-DD, validated) in schema/prompt/response + review header; unit tests; new spec `specs/receipt-pdf.md` + updated receipt-capture.md/README. **`total cost`/prices deliberately NOT added** (privacy posture excludes payment data) — surfaced as a go/no-go decision for Everett in the PR + spec. **Client "Import PDF" picker deferred** — needs `expo-document-picker` but npm install is gated in the worker shell (can't update package-lock → npm ci fails); backend accepts PDFs today. **PR NOT opened: `gh` is gated in the worker shell** (git push works, gh doesn't) — open via a permissioned spawn (`gh pr create -R ezybg7/pantry --base feat/vision-model-selection --head feat/receipt-parsing`) or the compare URL; CI runs only once the PR exists (ci.yml is pull_request-triggered), and it is the check gate since local npm/tsc are gated.
- 2026-07-21: **Spec audit → GitHub tracking-issues generator — branch `chore/spec-audit-tracking-issues`** (pushed, commit `d79a799`, based on origin/main). Audited `specs/`: 21 files, 19 numbered feature specs; **only spec 1** (receipt-capture / vision-model-selection / receipt-pdf) is implemented or in-flight — **specs 2–19 are all not-yet-implemented**, verified against the codebase not just the README board (recipes tab is a literal "Recipes arrive in M3" placeholder, Settings read-only, no `expo-camera`/barcode dep, no realtime subscription, no query-cache persistence, only migrations 0001+0003, only the `parse-receipt` Edge Function). Deliverable: **idempotent `scripts/create-tracking-issues.sh`** — upserts 9 labels, fetches existing issue titles and **skips any that already exist** (the no-duplicates guard runs at execution time), then files 18 issues `[spec 2]…[spec 19]` (each: summary + scope + depends-on/blockers + migration, linking its spec file), labeled `spec-tracking` + phase-a/b/c + feature/data/infra/release + `blocked:everett`; supports `DRY_RUN=1`; spec 1 excluded (tracked by PRs #7–#10 + receipt-parsing). **BLOCKER — the 18 issues are NOT created**: `gh` is gated in the worker shell. **Open for Everett:** `DRY_RUN=1 bash scripts/create-tracking-issues.sh` to preview, then `bash scripts/create-tracking-issues.sh` to file them (no PR required; optionally review/merge the script via a PR off `chore/spec-audit-tracking-issues` → main, then delete the branch).
