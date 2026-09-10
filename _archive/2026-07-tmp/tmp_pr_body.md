## What & why

Follow-up to the 2026-07-20 receipt-scanning debug session. That session found the field failure ("Something went wrong while reading the receipt") was **operational**, not a code bug: the local Edge runtime was down (503), and the Gemini key was shared with the Hermes relay, exhausting the free tier — which is **~20 requests/day per model per project**, not the ~1,500/day the spec assumed. This PR makes those failure modes cheap, self-diagnosing, and avoidable in dev.

Based on `main` (PR #8 merged 2026-07-20). Rebased so the diff is only the hardening — 12 files.

## Changes

1. **Gemini-free local dev (mock provider)** — `RECEIPT_PROVIDER=mock` returns a canned response from `supabase/functions/_shared/mock.ts`; Gemini is never called (free, offline, deterministic). The whole pipeline downstream of the model (cap, matching, expiry, review UI) runs unchanged. Default stays `gemini`; mock activates only on the exact value so prod can't be tripped by a typo. Scenarios `items` (default) / `empty`.
2. **`thinkingConfig` + model pin** — the adapter now sends `thinkingConfig: { thinkingBudget: 0 }`. `gemini-flash-latest` resolves to the *thinking* model `gemini-3.5-flash`; unbounded thinking was consuming the `maxOutputTokens` budget → `MAX_TOKENS` → 502. Model default stays the resilient alias (specific ids 404 for new keys); `GEMINI_MODEL` documents the prod pin path.
3. **Client error messaging** — new `unavailable` reason (500/503/network = service/infra down → "is the backend running?") distinct from `retry` (502 = model busy/failed). The old code collapsed both into a generic "something went wrong", which hid the exact 07-20 failure.
4. **Autonomy & escalation policy** — `CLAUDE.md` now tells any worker to perform operational work directly (restart services, migrations, db reset, file mgmt) and to escalate only genuine design/implementation-choice decisions — in the PR, not as a mid-task block.
5. **Spec errata** — the ~20 req/day reality replaces the ~1,500/day assumption throughout `specs/receipt-capture.md`; the stale "Claude vision call" line and the SPEC.md AI row are corrected to the Gemini adapter. New `specs/local-vision-model.md` (task 3) outlines hosting a local VLM (Qwen2.5-VL via Ollama/llama.cpp) on the Mac mini to drop the Gemini dependency for dev — and maybe prod.

## Checks
`npm run typecheck` ✅ · `npm run lint` ✅ · `npm test` ✅ (40 passed, +5 from `mock.test.ts`).

## Needs a decision (not blocking this PR)
- **Local vision model** (`specs/local-vision-model.md`): go/no-go on a ~half-day spike; dev-only vs prod ambition. Recommended default: Ollama + Qwen2.5-VL-7B, adopt for dev immediately if recall is moderate, prod eval-gated.
- **Dedicated Gemini key**: give the app its own key / paid tier so another tool can't exhaust its 20/day.

## Operational notes (local machine — worker sandbox can't run docker/supabase)
- Restart the Edge runtime if down: `supabase start` then `supabase functions serve --env-file supabase/functions/.env`.
- Load the seed catalog (fixes empty-catalog matching): `supabase db reset`.
- Test end-to-end with **zero Gemini calls**: set `RECEIPT_PROVIDER=mock` in `supabase/functions/.env`, restart `functions serve`.

## Out of band (orchestrator config, not in this repo)
- Queue preamble (`~/agents/queue/.preamble.md`) updated with the autonomy directive so every future task carries it.
- Proposed matching edit to the `delegate-to-claude` skill (route operational asks to do/re-queue, only design questions to the user) — deferred: it's a permission-gated global file.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
