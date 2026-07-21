## Summary

Selects and implements the **production vision model for receipt scanning**, resolving the "paid / no-training vision provider" launch blocker (CLAUDE.md, receipt-capture.md §Privacy).

**Decision: Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) via the Anthropic Messages API (forced tool use).** Gemini Flash is kept as a one-env-var fallback; `mock` stays for dev. Full rationale, comparison table, and config live in the new **`specs/vision-model-selection.md`**.

> **Stacked on #9** (`feat/orchestration-hardening`) — this branch builds on the mock provider / `RECEIPT_PROVIDER` seam introduced there, so the PR is based on that branch for a clean diff. Merge #9 first, then this retargets to `main`.

## Why Claude over the Gemini baseline (and GPT-4o-mini)

Evaluated on the task's criteria — latency, thermal-receipt accuracy, cost/scan, and **data privacy (no training, a hard constraint)**:

1. **Privacy is the decider, and Anthropic's no-training is the _default_, not a paid-tier setting.** Every candidate avoids training on API data *at the right tier*, but Gemini's guarantee holds **only on the paid tier** — a fresh key or billing lapse silently reverts to free-tier terms that **may train on a user's receipt photo** (exactly the state dev has run in). With Anthropic there is no "wrong tier." For a product whose input is a photo of someone's shopping, that removes an entire class of privacy foot-gun.
2. **Top-tier accuracy on thermal receipts** (faded, curled, abbreviated) — co-leads with Gemini, clearly ahead of GPT-4o-mini (small-model vision degrades on exactly these inputs).
3. **Provider consolidation** — the app already uses Anthropic (`claude-sonnet-5`) for its other AI, so this is one vendor / key / billing / DPA / wire format instead of two.
4. **Cost is competitive and trivial at this volume** — Haiku 4.5 (~$1/$5 per M tok) actually undercuts the `gemini-3.5-flash` the alias currently resolves to (~$1.50/$9) per scan; at the 20-scans/user/day cap, monthly spend is single-digit dollars for any candidate.

GPT-4o-mini (cheapest headline, meets no-training) and a self-hosted local VLM (the now-removed `specs/local-vision-model.md`) were considered and rejected — see the decision doc's §Alternatives.

## Implementation (behind the existing adapter seam)

- **`_shared/provider.ts`** (new) — shared adapter contract (`ProviderError`, `VisionJsonRequest`), extracted so both adapters throw the same error type and `parse-receipt` maps failures identically.
- **`_shared/anthropic.ts`** (new) — Claude adapter: one Messages call with a forced tool (`record_items`) whose `input_schema` is our item schema → always structured JSON. Same `ProviderError` mapping as Gemini. **Unit-tested** (`anthropic.test.ts`, fetch mocked: happy path + 429/5xx/4xx/no-tool-use).
- **`_shared/receipt.ts`** — added `RESPONSE_SCHEMA_JSON` (Anthropic JSON-Schema dialect) beside the Gemini one; both draw the enum from `FOOD_CATEGORIES` so they can't drift.
- **`parse-receipt/index.ts`** — `RECEIPT_PROVIDER` selects `claude` (default) | `gemini` (fallback) | `mock`. Only the exact string `mock` serves canned data; any unknown value falls through to Claude, so a typo can't serve fake data in prod. Reads `ANTHROPIC_API_KEY`/`ANTHROPIC_MODEL`. The 20/day cap is reframed as cost/abuse control (no free-tier quota on the paid provider).
- **`gemini.ts`** — call logic unchanged; now imports the shared contract. Still the fallback.
- Docs updated: receipt-capture.md, README.md, SPEC.md, CLAUDE.md, hosted-supabase.md, app-store-release.md; `specs/local-vision-model.md` removed.

## Testing

- `npm run typecheck` ✅ · `npm run lint` ✅ · `npm test` ✅ (6 suites, **45 tests**; +5 for the new adapter).
- The Deno function code (`index.ts`, adapters) is excluded from `tsc` and not covered by jest by repo design; I reviewed it directly and jest exercises the `anthropic.ts`→`provider.ts` import chain. `deno check` and live web lookups were **blocked in this worker sandbox** (tooling limit) — pricing figures are labeled verify-at-deploy and the real Claude call is validated by the pre-beta eval below.

## Decisions surfaced for you / open items

- **Model choice** (Claude Haiku 4.5) is the main design decision here — pushback welcome; swapping to `gemini` or a larger Claude is one env var.
- **You'll need an Anthropic API key** (billing enabled) for prod/beta: `supabase secrets set ANTHROPIC_API_KEY=…`, leave `RECEIPT_PROVIDER` unset (defaults to `claude`). This **replaces** the former "flip Gemini to paid tier" blocker. Local dev needs no key (`.env` set to `RECEIPT_PROVIDER=mock`).
- **Pre-beta accuracy eval** (vision-model-selection.md §Accuracy): run ~10 real thermal receipts through Claude, confirm ≥70 % food-line recall, before external users. Needs a key + real receipts.
- **Local `.env`** was set to `RECEIPT_PROVIDER=mock`; the running `functions serve` won't pick that up until restarted (`supabase functions serve --env-file supabase/functions/.env`). Sandbox couldn't restart it here.
- Follow-up (out of scope): the unbuilt text AI features (ai-shelf-life, recipe-ideas) are specced against `gemini-flash-latest` though the project default for non-vision AI is `claude-sonnet-5` — natural to consolidate onto Claude now that the adapter exists.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
