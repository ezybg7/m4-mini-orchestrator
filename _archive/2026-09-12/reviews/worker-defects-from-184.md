# Defects surfaced by PR #184's route tests (as `it.failing`) — fix PR queued after #184 merges
1. Medium — `workers/src/routes/importRecipe.ts:275`: the catalog read sits outside the refund guard; a catalog failure after a successful `import` claim rejects the handler without `refund_ai_call` → expected refund + 5xx.
2. Low — `workers/src/routes/barcode.ts:155`: the conflict Error names the typed product name; the dispatcher logs it (user string in logs).
3. Low — JSON `null` body → TypeError → 500 at `barcode.ts:97`, `ideas.ts:101`, `importRecipe.ts:307`; expected 422.
Fix agent: flip the three `it.failing` tests to passing while fixing the code; keep every other assertion; spec/ADR notes if behaviour text changes (receipt/import quota refund rule in specs/recipe-import.md §Server).
4. Low (from PR #185's reading) — the seed script's "already exists" branch has been dead since #162 (a synthetic user id → SQL for a nonexistent row). Fix or delete the branch; note in docs/PRODUCTION_CHECKLIST.md §0 if the seeded login procedure changes.
