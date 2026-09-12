# PR #196 review — Spec 58 skeleton loading, PR 1 (f9f81fa on 19712c8) — 2026-09-05

**Verdict: needs fixes (two small ones, FIND-001/002, in this PR) → then mergeable after #193.** Verified myself on a detached worktree: `typecheck` ✓, `lint` ✓ (0/0), the 13 touched suites 171/171 with `--detectOpenHandles` clean. Spec §Rules/§Motion/§Accessibility/§Component API are honoured line by line except the three deviations below (two recorded "as built", one not).

## Strengths
- `src/components/Skeleton.tsx:252-305` — one `Animated.Value` per group, loop keyed on `still` so a Reduce Motion flip runs `stop()` + reset, hide-pair on the inner wrapper; `Skeleton.test.tsx:76-98` pins the RNTL `getByRole('progressbar')` contract that #193's FIND-002 was about.
- `src/lib/useDelayedPending.ts:65-85` — one timer alive at a time, the zero-length hide timer keeps one code path; every scenario asked for (100/200 ms, re-pend, drop-and-rise, unmount) is in `useDelayedPending.test.ts:39-179`.
- `src/test/screens/tabsGate.test.tsx:263-283` — the real layouts under `renderRouter`; the restore-window `'idle'` case is the one that would have redirected a cached account to onboarding.
- D1 is safe: `['households', userId]` is keyed per user, sign-out runs `queryClient.clear()` → `clearPersistedCache()` (`auth/context.tsx:223-224`) with the owed-purge marker, `dropForeignCache` runs at session resolve (`queryPersist.ts:238-262`); `queryPersist.test.ts` pins the root in and out of the identity list. `networkMode: 'online'` is right — paused, not failing.

## Decisions
| # | Question | PR default | Recommendation | Who decides |
|---|---|---|---|---|
| 1 | `['households']` persisted (D1) | Applied | Keep — per-user key, purge + owner stamp cover device handover | Everett (spec 12) |
| 2 | Gate shape without a hint (D2) | "Pantry" always; hint queued | Both layouts already read `passwordRecovery` — pass it as `neutral` now (one prop); stored-id hint in PR 2 (FIND-006) | Everett |
| 3 | Explicit `lineHeightFor` leading (+~3 pt/row; `SectionHeader` app-wide) | Shipped; recorded in `design-system.md` contracts + touched-files | Accept, device row 4. Maestro flows assert text only (`09-grocery-list.yaml:40`) — unaffected | Everett (device) |
| 4 | `interrupt` on the hook | Not built; error-first wiring, recorded | Accept; build for the first two-query screen (PR 2) | Lead |
| 5 | Global `expo-network` mock in `jest.setup.js` | Added | Accept — the app's own fallback; local mocks win; `offlineCache.test.tsx` green | Lead |
| 6 | Gate→tab handoff blank (FIND-001) | Ships | Fix here — it is the flow the gate skeleton exists for | Lead |

## FIND queue
**FIND-001 · Medium · logic · confirmed** · `(tabs)/index.tsx:136-145,367-372`, `households/skeletons.tsx:62`. On the first-ever load the gate draws `PantrySkeleton` (search bar, summary, cards); the tabs mount and the Pantry's own `locations` read starts only then (`useLocations` lives in the screen; nothing prefetches it), so for ≤150 ms `gridHeld` is true and `gridPlaceholder` is `null`: grey → **blank region under the real title/field** → grey (a second "Loading pantry" announcement) → grid. Rule 3's flash inverted, on the exact flow acceptance row 1 ("never a blank frame") covers. Fix: a one-shot latch set by `GateSkeleton` while `visible`, consumed by the Pantry tab as `delayMs: 0` (minimum still applies); add a handoff case to `tabsGate.test.tsx`.

**FIND-002 · Medium · a11y · confirmed** · `GroceryList.tsx:127-129`, `(tabs)/index.tsx:145-149`, `location/[id]/index.tsx:145`, `announce.ts:19-21`. `useAnnounce` fires on every `message` change, and the sentence is recomputed from live data whenever `wasShown` — after one cold load, every checkbox toggle speaks "2 to buy", "1 to buy" over the checkbox's own state for the rest of the mount; Pantry/Location re-announce on every add or delete. Spec: "announces it once"; and behaviour now differs between a cold and a cached session. Fix: latch the first non-held sentence in a ref, pass `null` afterwards; assert `toHaveBeenCalledTimes(2)` across a later data change.

**FIND-003 · Low · logic · likely** · `(tabs)/index.tsx:664-666`, `locations/skeletons.test.tsx:89-94`. The card glyph is a 26 pt `Text` with no `lineHeight`; the contract sums `max(26, 29)` = 77, but an emoji line at 26 pt lays out ~31–34 pt on iOS, so the real card is ~79–82 (the spec table's own "≈ 79") and each grid row shifts at the swap. Fix: `lineHeight: lineHeightFor(glyphSize.card)` on `cardIcon`, the same line box in the skeleton, re-pin.

**FIND-004 · Low · contract · confirmed** · spec §Accessibility vs `src/lib/announce.ts` (untouched). The spec says PR 1 adds the `Platform.OS === 'ios'` guard so Android hears the live region once; not done, not recorded as built. Add the guard (all three callers pair it with a live region) or amend the sentence.

**FIND-005 · Low · test-gap · confirmed** · `Skeleton.test.tsx` has neither "`reduceMotionChanged` → true stops the loop and pins 1.0" nor "unmount leaves `jest.getTimerCount()` at 0" (spec §Test plan, from #193 FIND-006; grep: 0 hits). `tabsGate.test.tsx` has no recovery-session case.

**FIND-006 · Low · design · confirmed** · `households/skeletons.tsx:46-66` always draws "Pantry": every sign-up and recovery session sees it for one round trip (title at once, blocks after 150 ms). Decision 2.

**FIND-007 · Note · maintainability** · `held = isPending || visible` (`GroceryList.tsx:124`; `(tabs)/index.tsx:142`) is needed for the restore window (`isColdLoad` alone would flash the empty sentence during hydration) but also holds a **disabled** read (`enabled: !!householdId`) as a blank region with no skeleton — unreachable behind the gate today, reachable on PR 3's Expiring no-household case. Branch on the no-household state before the hold, or use `useIsRestoring()`.

**FIND-008 · Note · reliability · hypothesis** · `Skeleton.tsx:278` — `pulse.setValue(1)` in the unmount cleanup on a native-driven value whose views may already be detached re-creates a native node (`AnimatedNode.__getNativeTag`) nothing drops. Harmless on the flip path; verify on device or reset only on the flip.

**FIND-009 · Note · test-gap** · `spinner-ratchet.test.ts:153` tolerates a 3-spinner slack below `OCCURRENCE_CEILING`, so three removals then three additions pass; the scan counts `<ActivityIndicator` in comments (none today) and misses `<RN.ActivityIndicator`. Tighten to exact when each PR rewrites the ceilings.
