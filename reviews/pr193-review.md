# PR #193 review — Spec 58 skeleton loading (a48182b, spec-only) — 2026-09-05

**Verdict: approvable with fixes, plus one decision for Everett (Q3).** The inventory is accurate (30+ `file:line` citations re-checked; nits in FIND-009) and the predicate and token choices are right, but four spec-text defects would send PR 1 the wrong way, and Q3's default keeps spec 12's offline promise unreachable.

## Strengths
- Inventory holds: `(tabs)/_layout.tsx:40-46`, `(auth)/_layout.tsx:11`, `MyRecipes.tsx:180,188` (`?? 0`), `ReceiptCapture.tsx:104,298-300,659-663`, every Profile slot.
- `isColdLoad`'s `fetchStatus !== 'idle'` clause is anchored in a real defect (`expiring.tsx:349-353`); TanStack citations exact (`queryObserver.js:240`, `useBaseQuery.js:23`).
- Token discipline: `theme.ts:42` already names skeletons for `thumbFill`; `onGround → border` matches the hex values (:194-195, :269-270); both ratchets stay flat.
- RN `Animated` over Reanimated is argued from the harness's real cost (`zonesScreen.test.tsx:85-96`); `NativeAnimatedModule` is mocked under jest (`@react-native/jest-preset/jest/mocks/NativeModules.js:82`).

## Decisions
| # | Question | PR default | Recommendation | Who decides |
|---|---|---|---|---|
| 1 | `['households']` on spec 12's whitelist? | No; gate becomes a skeleton | **Yes** (or a `'household'` `SplashStep` under the 4 s deadline). The query (`context.tsx:88-97`) is `networkMode: 'online'` and unpersisted: an offline cold launch pauses at the gate forever, so spec 12's own offline acceptance is unreachable today; a static skeleton only paints it (FIND-001) | Everett (spec 12 owner) |
| 2 | Gate = "Pantry" title + PantrySkeleton | Yes | Only with a cached household hint: every sign-up lands on `/onboarding` (`(tabs)/_layout.tsx:72`), recovery on `/reset-password` (:57). Add the SearchField (FIND-004) | Everett |
| 3 | Recent skeleton, search spinner | Recent skeleton | Accept | Everett |
| 4 | Recipe hero 16:9 block | Yes | Accept | Everett |
| 5 | Paused cold state | Static skeleton | Accept for tab screens; the gate has no `OfflineBanner` (mounted at `_layout.tsx:84`, inside the success branch) — render it above `GateSkeleton` or use the sentence | Everett |
| 6 | Crossfade | None | Accept | Everett |

## FIND queue
**FIND-001 · High · logic · confirmed by trace** · `(tabs)/_layout.tsx:40-46,84`, `context.tsx:88-97`, `queryPersist.ts:89-100`. Offline cold launch: `households` unpersisted + `networkMode: 'online'` → `isPending` and `paused`; the gate never passes, and rule 5's banner is not rendered in that branch. Impact: static skeleton forever, no words. Fix: decision 1; at minimum mount `OfflineBanner` in the gate branch and expose `fetchStatus` from `useHousehold` (today only `loading`/`isError`, `context.tsx:293-294`).

**FIND-002 · High · contract/a11y · confirmed** · §Accessibility vs RNTL `helpers/accessibility.js:66,72`, `config.js:15`. The hide-pair (`accessibilityElementsHidden` + `no-hide-descendants`) on the labelled `progressbar` hides the container itself: Android never reaches the label, and `getByRole('progressbar')` — the core assertion in ~20 suites — fails (`defaultIncludeHiddenElements: false`). Fix: `accessible` + role + label on the group, `accessible={false}` on children; hide-pair for decoration only (`ScorecardCard.tsx:63`).

**FIND-003 · Medium · contract · confirmed** · §Client `useDelayedPending` vs §Acceptance failure path. `visible` stays true until pending is false **and** minMs passed, and the wiring is `visible ? <Skeleton/> : …`, so an error at +100 ms is masked ≤300 ms — contradicting "ErrorState the moment it fails". Fix: hook takes `interrupt` (`query.isError`) or wiring checks `isError` first; add the test.

**FIND-004 · Medium · logic · confirmed** · `(tabs)/index.tsx:263-271,545-549`, `SearchField.tsx:100`. Pantry always draws `searchWrap` (12 + 44 + 8 = 64 pt) between title and grid; `GateSkeleton` omits it → 64 pt jump at the most-seen handoff, every launch.

**FIND-005 · Medium · logic · confirmed** · `ItemRow.tsx:284-300`, `GroceryRow.tsx`, `RecipeRowItem.tsx`, `CommunityCard.tsx`, `insights.tsx`: zero `lineHeight` declarations. The contract sums `lineHeightFor` (1.3×) but real `Text` lays out natural leading (~1.2×): ItemRow ≈ 56 not 59, drifting over 6 rows; the jest equality passes against a number the device never renders. Fix: set `lineHeight: lineHeightFor(...)` on those styles in the same PR.

**FIND-006 · Medium · reliability/test-gap · likely** · `AccessibilityInfo.js:28` (`isReduceMotionEnabled` returns a Promise), `setup.js:57-60` (rAF = `setTimeout 0`). Spec omits cancelling the async read on unmount and `loop.stop()` on unmount / Reduce Motion flip → act warnings in every suite mounting a group; an unstopped loop re-arms timers after unmount.

**FIND-007 · Low · test-gap · confirmed** · spinner ratchet: starting ceiling unstated (31 importing files / 38 `<ActivityIndicator` sites today); `CommunityList.tsx:187` pager "stays" yet is missing from the allow-list; count JSX occurrences, not imports.

**FIND-008 · Low · test-gap · confirmed** · `pantryScreen.test.tsx:105-108` fixture has no `fetchStatus` (passes via `undefined !== 'idle'`); disabled fixtures need `'idle'`; `RestockReview.tsx:187` gates on `rows === null`, not a query.

**FIND-009 · Low · maintainability · confirmed** · `hooks.ts:47` is an invalidation (query: `context.tsx:88-97`); `SettingsLearned.tsx` is under `features/households/`; the auth-layout blank ends at `sign-in.tsx:65`'s `replace('/')` — the RTT is spent at the tabs gate; acceptance step 1: after a signed-out relaunch the first post-splash screen is Welcome.

**FIND-010 · Note** · Retry with nothing cached resets to `pending` (`query.js:350-353`) → skeleton returns after 150 ms: good, unspecified. `useAnnounce` has no Platform guard (`announce.ts:18-22`): Android hears live region + announcement (inherited). Folders `?? 0` is a spec-12 D3 defect — ship the one-liner now. Spec 12 needs two edits either way: the "Deliberately out" line and "pending → spinner" (`:34`). README rows well-formed; §History present.
