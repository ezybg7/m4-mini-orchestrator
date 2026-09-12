# PR #198 review — Spec 58 skeleton loading, PR 2 (7f98de3 on 00034bb) — 2026-09-05

**Verdict: needs fixes (FIND-001/002, both small) → then mergeable after #196.** Verified on a detached worktree: `tsc` ✓, `eslint` ✓, the 11 touched suites 174/174. #196's FIND-002 (`useAnnounceArrival`, `profile/[id]/index.tsx:100`), FIND-007 (`!!ownerId` / `!!household` / `!!id` on every hold) and FIND-009 (exact ratchet: `toBe` 18/22; `grep` finds 18 files / 22 sites) are honoured. All ten screens share one wiring — `failed` first, `interrupt: failed`, `held = !!enabled && !failed && (isPending || visible)`; `RefreshControl`, `StaleBanner` and the `refetching` paths are untouched, the pager spinner stays (`CommunityList.tsx:198`), and `BottomSheet` is a `Modal`, so a closed sheet mounts no group.

## Strengths
- `useDelayedPending.ts:80,93-101` — `interrupt` is one branch: zero-length timer, no set-state in the effect body, cleanup on every path; `useDelayedPending.test.ts:210-273` pins the spec's three cases plus the zero-delay seed.
- `profile/[id]/index.tsx:69-100` — the two-query hold done right: `person` withheld so header actions, banner and empty sentence settle once; `titlePending` only while the name itself is missing.
- `MyRecipes.tsx:159-165,228-236` — spec-12 D3: one static bar, no second progressbar, the label drops its count claim; all four cases in `recipesTab.test.tsx:292-346`.
- Contract by construction: `RECIPE_ROW` / `COMMUNITY_CARD` exported from the rows, `recipeLayout.ts` for the routes, `lineHeightFor` on every line a bar stands for; 66/86/87/78/46/44 re-derived in `recipes/skeletons.test.tsx`. D4: `styles.photo` (`index.tsx:591-596`) is the same `width:'100%', aspectRatio:16/9` box in the same padding — no jump with a photo; a photo-less recipe loses the block, as D4 accepted.

## Decisions
| # | Question | PR default | Recommendation | Who |
|---|---|---|---|---|
| 1 | Community search → skeleton (rule 9 exception) | New term/filter key → skeleton | Accept for filter/sort. `term` reaches the key un-debounced (`CommunityList.tsx:45,52,91`): on a slow network each keystroke past `MIN_SEARCH_CHARS` is a grey 4-card block plus a 300 ms hold. `placeholderData: keepPreviousData` on `useCommunityFeed` keeps the old cards while typing — PR 3 | Everett |
| 2 | Empty header slot under the delay | `title=''`, bar only while visible | Accept — ≤150 ms of nothing is invisible, never a wrong word | Lead |
| 3 | Cook chip shape (three 87 pt "almost there" rows) | Shipped | Accept for the device pass; "You can make" rows are 66 pt, so rows may shrink 21 pt — FIND-002 is the bigger jump | Everett (device) |

## FIND queue
**FIND-001 · Medium · contract · confirmed** · `Skeleton.tsx:206-209`, `recipes/skeletons.tsx:141` vs `RecipeRowItem.tsx`, `CommunityCard.tsx`, `CookList.tsx:216-255`, `recipe-folders/index.tsx`, `AddToFolderSheet.tsx`. `SkeletonRow` and `CookRow` stack column-wise at `fontScale ≥ 1.5`, but none of the five real rows stacks — `useLargeText` only sets `numberOfLines` (grep: zero layout branches; `ItemRow.tsx:249` is where the rule came from). At 1.5× a recipe row is ≈ 80 pt horizontal, its skeleton ≈ 134 pt stacked: ~54 pt a row, ~215 pt over four, on six screens. Fix: `SkeletonRow stack?: boolean` (default current), `false` from the recipe compositions; drop `large && rowStacked` from `CookRow`; a `fontScale: 2` case in `recipes/skeletons.test.tsx` asserting `flexDirection: 'row'`. (Or make the real rows stack — Everett's call.)

**FIND-002 · Medium · contract · confirmed** · `CookList.tsx:154-155,189-200`. The hold returns `<CookSkeleton />` bare; the real segment is `container` (`gap: 8`) → the ideas `Button` (`minHeight: 44`, `Button.tsx:186`) → the list, so every row drops ≥ 52 pt at the swap (+ `expiringHeader` when it applies) — PR 1's FIND-004 class. Reach: first sign-in / new household / purge. Fix: the skeleton inside the same `container` with a 44 pt `radii.control` `onGround` bar in the button's slot (or the real `Button`, neutral title, disabled); pin in `skeletons.test.tsx`.

**FIND-003 · Low · logic · likely** · `recipe-folders/[id].tsx:53-58`. `held` omits the name read. Both reads cold (deep link / gc eviction): contents answer at 100 ms, the list at 400 → rows under an empty title, then at 150 ms `skeleton.visible` (`isColdLoad(folders) && !folder` still pending) → `held` true → rows vanish → skeleton + title bar → rows again after the minimum. Fix: `… (recipes.isPending || nameHeld || skeleton.visible)`; add the case to `folderScreen.test.tsx`.

**FIND-004 · Low · contract · confirmed** · `recipes/skeletons.tsx:294-316`, `RecipeForm.tsx:405-424,651-659`. Three 44 pt inputs, but the form's first three fields are Title, **Photo** (`photoPlaceholder`: `paddingVertical 24` + a 28 pt icon + `gap 6` + a line ≈ 100 pt) and Servings — the second block is ~55 pt short; and `Input` lays out ≈ 41–43 (no `minHeight`), not 44. Rare (the editor follows a detail that just fetched the key). Fix: a photo-slot block from `RECIPE_FORM`; `minHeight: MIN_TAP_TARGET` on `Input`; amend the §Scope Edit row.

**FIND-005 · Low · contract · confirmed** · `recipe/[id]/index.tsx:606-612`. `title` (`fontSize: 22`) declares no `lineHeight`; the skeleton pins `lineHeightFor(22)` = 29 (`skeletons.test.tsx:262`). Masked at 1.0× by the 72 pt ring; in the stacked `titleBlock` it is ≈ 26.4×fontScale against 29× — 4–8 pt at 1.5–3.1×. Fix: `lineHeight: lineHeightFor(22)` (leading, not a size token).

**FIND-006 · Note · test-gap** · `recipeRating.test.tsx`. "Pre-existing" act() noise — on PR 1's tip: 10 warnings, all `AddToFolderSheet`; on 7f98de3: 4 plus one new `RecipeScreen`, all from `notifyManager.ts:42`'s `setTimeout` — unmocked queries (`@/features/recipes/folders` is not mocked there, unlike `recipeDetail.test.tsx:62-68`). Fix: mock the folders hooks (and `useRecipeNutrition`) as `recipeDetail.test.tsx` does.

**FIND-007 · Note · test-gap** · `creatorProfile.test.tsx:520-556` asserts the arrival sentence with `toHaveBeenCalledWith` but never that a later `recipeCount` change leaves the count at 2 (#196 FIND-002's ask).

**FIND-008 · Note · maintainability** · `MyRecipes.tsx:163`. `foldersHeld` has no `!!ownerId` guard: a disabled `folders` read (`folders.ts:48`) is pending forever → "Folders" with neither count nor bar. Benign, unreachable behind the gate.

**FIND-009 · Note · contract** · `profile/[id]/index.tsx:69-74`. `interrupt` is the profile read alone, not the OR rule 3's as-built text prescribes for two-query screens. Right for the wiring (a failed `recipes` read is a `StaleBanner`, not the `ErrorState`) — amend the sentence so spec and code agree.
