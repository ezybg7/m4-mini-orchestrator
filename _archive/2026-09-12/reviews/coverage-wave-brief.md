# Coverage wave — new Maestro golden paths (brief, 2026-09-04 evening)

Goal: every shipped user-facing spec has a golden-path flow that has RUN green, or an explicit `e2e: n/a — reason` line. Today 13 flows run (01 02 03 09 10 11-account-deletion 11-grocery-restock 12 13 14 44 47 48). Candidates without a flow, in priority order (single seeded account, iPhone 17 Pro simulator, Release build against the Neon acceptance branch with 0054 applied):

1. `04-item-screen.yaml` (spec 25 §Item screen, package P4 #173): open Fridge → Milk → tap `+1w` → toast "“Milk” now expires <date>" with Undo → Undo restores → rename via the Name field blur → toast → reset by clearing. Cleanup: leave Milk as found.
2. `05-status-lifecycle.yaml` (specs stock-levels/out-lifecycle; runbook Scenario 3): Fridge → Milk chip Stocked → low → out (toast with Delete) → Delete → Undo restores as out → set back to Stocked.
3. `06-households.yaml` (spec household-management, P5 #179): Profile → Household row → rename → toast → regenerate invite code (the OverflowMenu "More invite code actions") → code changes → rename back.
4. `07-profile.yaml` (spec 51 creator profiles; needs 0054 — applied on the branch): Profile → About you → set a bio → save → "View my public profile" shows it → clear the bio.
5. `08-paywall.yaml` (spec 23; RevenueCat dark): Profile → Ambry Plus → the paywall renders the locked price copy from STATIC_PACKAGES, a Restore purchases control (guideline 3.1.1), and closes; assert no hard-coded quota number in the meter (the meter reads a number from the payload).
6. `15-zones.yaml` (spec zones-ui, P3 #180): Fridge → ⋯ → Zones → add a zone → rename → delete (confirm) — no drag (manual).
7. `16-invite-link.yaml` (spec 43): `openLink` on a `https://pantry-api.everettzyan.workers.dev/join/<token>` for the seeded household's own invite → the confirm sheet says you are already a member (or the equivalent copy) — read `src/app/join/[token].tsx` for the exact state; if it needs a second account, record `e2e: [manual]` in the spec instead.
8. `17-dark-mode.yaml` (spec dark-mode): Profile → Appearance → Dark → assert a known dark-only token/label if any exists in the hierarchy; otherwise mark `e2e: [manual]`.
9. Capture (barcode/receipt/photo) stays `e2e: [manual]` (camera) — the mock-Worker scenario 7 is tagged `needs-mock-worker` and excluded; leave as is but confirm the spec lines say so.
10. Recipe import (spec recipe-import) — tag `needs-mock-worker`; author only if the mock provider covers import; else `e2e: n/a — Worker route tests cover it`.

Rules: read the runbook's flow conventions (`_launch.yaml`, `_login.yaml`, the cold-start guard, `centerElement`, `timeout` on scrolls); every flow cleans up after itself; authored-but-never-run = no coverage, so each flow must be run alone until green, then the full suite once, and the runbook's tables updated (coverage table + run log). Add the `e2e:` line to each spec touched. One PR, watcher armed.
