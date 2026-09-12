# PR #197 review — Spec 58 skeleton loading, PR 3 (8d871a8 on 7f98de3) — 2026-09-05

**Verdict: needs fixes (FIND-001 Medium; FIND-002/003 small) → then mergeable after #198.** Verified on a detached worktree: `tsc` ✓, `eslint` ✓, 22 touched suites 341/341, `--detectOpenHandles` clean. #196/#198's contracts hold: announce once via `useAnnounceArrival`; `!!enabled`/`isColdLoad` holds (Expiring branches on the household first); `failed` first everywhere (no `interrupt` passed — recorded); no composition stacks a row the real row doesn't; ratchet exact and matching the tree (`grep`: 10 files / 14 sites, `PENDING` empty), allow-list = the spec's exceptions (Button, three search sites, two camera files, join ×3, two AI working states, the Community pager). `ReceiptCapture`'s hand-rolled blocks are gone; `container.gap` 12 = `RECEIPT_SKELETON.gap`; fill `border` = `onGround`. Every pinned height re-derived against the real styles (59 / 67·44 / 44 / 125·45 / 51 — the real Recent row has no `sub` line / 78·31 / 55 / 44 / 52); `lineHeightFor` is on every line a bar stands for, `insights.tsx` included.

## Strengths
- `RestockReview.tsx:83-86,183-197` — `rows === null` is a one-shot snapshot: a refetch never re-skeletons, a failed load never seeds an empty snapshot, error branch first; `RestockReview.test.tsx:241-263` pins "one read back is not a snapshot yet".
- `capture/skeletons.tsx:30-36,124-175` + `CaptureReviewList.tsx:135-157` — `REVIEW_ROW` exported from the list, `REVIEW_CHIP` derived from `CHIP_BOX`: 78/31 true by construction.
- `Skeleton.tsx:326-329`, `SettingsRow.tsx:112-122` — a silent group keeps role + label and drops the live region; pinned in `Skeleton.test.tsx:421-446`. Fixtures set `fetchStatus` everywhere; `expiringNoHousehold.test.tsx:73-98` pins FIND-007 both ways.

## Decisions
| # | Question | PR default | Recommendation |
|---|---|---|---|
| 1 | Item header bar vs `title=""` | `title=""` | Accept — the header shows what the loaded screen shows; amend rule 6 (FIND-009) |
| 2 | Zones count bar | None | Accept — pinned zones are the minority |
| 3 | Real row numbers over the table | Real numbers | Accept. Device-pass flag: a fresh account's COMMON state is shorter than the skeleton — Members "just you" ≈ 67 vs 88, Learned footnote ≈ 23 vs 55; consider `MEMBER_ROWS = 1` + a footnote bar |
| 4 | `ReviewListSkeleton` in `capture/` | capture | Accept; spec updated |
| 5 | Chip +1 pt app-wide | Shipped | Accept for the device pass — PR 1's SectionHeader trade |
| 6 | Slots collapsed under the delay | Quiet 0–150 ms | Device-pass flag: Learned (55) + AI scans (52) appear at 150 ms and push everything below ~107 pt — the old jump front-loaded; if it shows, reserve the slot's `minHeight` from the first frame |
| 7 | D2 stored-id hint | Follow-up | Not a merge blocker: sign-up half of row 1c, cosmetic, no regression; its own small PR before the device pass |

## FIND queue
**FIND-001 · Medium · contract · confirmed** · `expiring.tsx:419-450` vs `inventory/skeletons.tsx:27-33`. The real `ListHeaderComponent` draws the "See what you can make with these" `Button` (`minHeight` 44 + `cookLink` margins 8/8 = 60 pt) above the first section whenever `sections.length > 0`; `ExpiringSkeleton` is header bar + 4 rows, nothing in that slot. Every cold load with ≥ 1 item — the case the summary row sends you here for — swaps with the rows dropping 60 pt (#198 FIND-002's class). Fix: a 44 pt `radii.control` `onGround` bar in the same margins atop `ExpiringSkeleton`; pin in `inventory/skeletons.test.tsx`.

**FIND-002 · Low · logic · confirmed** · `(tabs)/profile.tsx:266-269`. `value={isPlus ? 'Ambry Plus' : 'Free'}` is unconditional and `valuePending` only while `usageSlot === 'skeleton'`, so under the delay the row reads "Free" — the claim decision 5 set out to remove — then a bar, then the word: every Free user sees word → bar → word on each cold open, where before the word held still. Fix: `value={usageHeld ? undefined : …}` (`SettingsDisplayName.tsx:110-111`'s shape); assert "Free" absent under the delay in `profileScreen.test.tsx`.

**FIND-003 · Low · a11y · confirmed** · `(tabs)/profile.tsx:90-95`. "Loading profile" is timed on `membersCold || quotaCold`; the name, bio and learned slots time their own silent skeletons. Members + quota inside 150 ms and any other read past it → grey slots with no announcement anywhere. Fix: subscribe to the same keys in the tab (TanStack dedupes — `useProfile`, `useLearnedShelfLife`, an extracted `useDisplayName`) and OR all five; test it.

**FIND-004 · Low · logic · confirmed** · `expiring.tsx:340-354`. The nav-bar "Add all" is gated on `sections.length > 0`, not `held`: rows landing at +160 ms put the button in the header while the skeleton holds to +450 — data-shaped chrome ahead of its data, what `:365-371` gates the subtitle on `held` to prevent. Fix: `!held && sections.length > 0`.

**FIND-005 · Low · contract · likely** · `inventory/skeletons.tsx:93-95,133-136` vs `item/[id].tsx:1078-1085`, `Input.tsx:54`. The name field is `Input` (paddingVertical 10) + a 17 pt line floored at 44: at 1.0× both sides say 44; at fontScale 1.5/2.0 the TextInput lays out ≈ 51/61 while `nameSlot` stays 44 — 7–17 pt short under large text. Fix: `nameSlot` = `paddingVertical: 10` + `minHeight: 44`, `lineHeight: lineHeightFor(fontSize.title)` on `nameInput`.

**FIND-006 · Note · test-gap** · `BasketReview.test.tsx`, `SettingsMembers.test.tsx`, `SettingsRow.test.tsx` — the new fake-timer cases emit "An update to Icon … not wrapped in act(...)" (Ionicons' async font load; #198 FIND-006's class). `await flushEffects()` after render.

**FIND-007 · Note · maintainability** · `item/[id].tsx:287`, `zones.tsx:100` — `held` has no `!!id` guard (#198 put one on every route hold). Unreachable from a matched route; guard for consistency.

**FIND-008 · Note · contract** · `spinner-ratchet.test.ts:71-73` calls both `ScanCapture` sites camera-permission; `:284` is the `looking` barcode-lookup overlay — allowed (rule 8), misdescribed.

**FIND-009 · Note · spec** · rule 6 still cites `item/[id].tsx:447` as a header that should carry a bar while §Rollout PR 3 (1) records the opposite; amend it. Pre-existing, unchanged (rule 4): a failed name read prints "Not set", a failed learned read "Nothing yet".
