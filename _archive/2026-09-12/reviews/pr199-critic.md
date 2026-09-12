# PR #199 — CRITIC review (catalog extension: spices, thin categories, twelve thin families)

**Branch** `feat/catalog-spices-2026-09-06` @ `b5fb23e9` · reviewed 2026-09-06 against `origin/main` (`dfcd0f0`)
**Method** read-only worktree; every claim re-derived mechanically (own SQL parsers, own USDA-mirror comparison, own `matchCatalog` harness built from the two seeds). No database touched.
**Verdict** The data itself is the cleanest part of this PR — 390 inserts, 38 alias updates and 223 panels all verify byte-for-byte. What does **not** hold up is (a) the effect of 390 new rows on the *server-side* type-ahead, (b) the rehearsal's expected counts, and (c) four of the seven manual acceptance expectations, which describe a code path that does not exist. FIND-001..003 should block the apply/merge; FIND-004/004b are cheap to fix and worth fixing before the data lands. `origin/main` moved during this review (#200, spec 59) — **#199 still merges cleanly** (`git merge-tree`, no conflicts), but see the closing note.

---

## FIND-001 — 390 new rows push pre-existing staples out of the Add-tab type-ahead (20-row cap, alphabetical)
- **Severity** High · **Category** logic / contract · **Confidence** confirmed
- **Location** `src/features/data/serverRepository.ts:554-562` (`catalogSearch`), consumed by `src/features/capture/SearchCapture.tsx:206,363` and `src/features/grocery/AddGroceryInput.tsx:79`
- **Symptom** The visible suggestion list is `select … from catalog_items where name ilike '%term%' order by name limit 20`. The PR nearly doubles the catalog (421 → 811) without touching that query, so common substrings now overflow 20 and the overflow is cut **alphabetically**, not by relevance. Measured on the two seeds (identical under C and en_US collation):

  | typed | main hits | branch hits | pre-existing rows now invisible |
  |---|---|---|---|
  | `frozen` | 15 | **36** | Frozen pizza, Frozen shrimp, Frozen vegetables, Frozen waffles, Frozen orange juice concentrate, Lobster tails (frozen), Sausages (frozen), Precooked sausages (frozen), Soft pretzels (frozen) |
  | `canned` | 13 | **26** | Canned tuna, Canned vegetables, Canned seafood, Coconut milk (canned), Coconut cream (canned) |
  | `nut` | 21 | **26** | Peanuts, Peanuts (in shell), Pine nuts, Walnuts, Shredded coconut |
  | `sauce` | 12 | **22** | Worcestershire sauce |
  | `dried` | 7 | **25** | Sun-dried tomatoes |

  The branch's first 20 for `frozen` are `Breaded fish (frozen) … Frozen mango` — the whole tail of the alphabet is gone.
- **Impact** A user typing `frozen` can no longer pick **Frozen pizza** or **Frozen vegetables**; typing `canned` can no longer pick **Canned tuna**. Those are staples that worked before this PR. Nothing in the diff, the spec or the 640 new tests looks at this path — every "type-ahead probe" in the suite goes through `matchCatalog`, which is *not* what the suggestion list uses.
- **Fix intent** Either raise/relevance-rank the cap (prefix matches before infix, exact name first) or accept it explicitly in the spec. Cheapest defensible fix: order by `(name ilike term || '%') desc, length(name), name` and lift the limit to ~30. This is a client change, so it is a decision, not a silent tweak — but shipping 390 rows without it is a regression.
- **How to verify** `select name from catalog_items where name ilike '%frozen%' order by name limit 20;` on a branch with the apply landed — `Frozen pizza` is absent.

## FIND-002 — The rehearsal's expected spice counts (48 / 92 / 140) are wrong; the operator will read a mismatch as a failure
- **Severity** High · **Category** contract / reliability · **Confidence** confirmed
- **Location** `db/apply/catalog-extension-2026-09.sql:2852-2856` (second count check) and its comment `:2851`; `specs/MIGRATIONS.md` (new bash comment "Second check: 48 usda_panels / 92 no_panel / 140 spice_rows" and the registry bullet "expect 48 / 92 / 140")
- **Symptom** The query is scoped to the **whole** category:
  ```sql
  select count(*) filter (where nutrition_source = 'usda') as usda_panels,
         count(*) filter (where nutrition is null)         as no_panel,
         count(*)                                          as spice_rows
    from catalog_items where category = 'spices';
  ```
  but the expectation counts only the 117 **new** rows. On production, **16 of the 23 existing spice rows already carry `nutrition_source = 'usda'`** — `db/apply/usda-nutrition-backfill.sql` (✅ applied 2026-08-08, re-applied 2026-08-11 per `specs/MIGRATIONS.md:198`) stamps Bay leaves, Black pepper, Chili powder, Cinnamon, Cracked black pepper, Cumin, Curry powder, Dried oregano, Garlic powder, Ground cumin, Ground mustard, Nutmeg, Onion powder, Paprika, Red pepper flakes and **Salt**. (Tranche 2, which covers the other seven, is still ⏳.)
  Predicted actual result: **63 usda_panels / 77 no_panel / 140 spice_rows** — not 48 / 92 / 140. If tranche 2 is applied first it becomes 70 / 70 / 140.
  Corollary: the `Salt` statement (`:769`) is guarded `nutrition is null` and `Salt` already has 173468's panel, so **it is a no-op on production** — 47 panel writes, not 48.
- **Impact** The PR's whole gate is "rehearse, read all four trailing counts, then apply." Three of the four numbers are right (the thin and broad checks list names explicitly and I verified both lists match their insert sets exactly); the spice one is off by 15 in both directions. An operator following the registry literally sees a mismatch and must either abort a correct apply or wave through a mismatch they were told to check.
- **Fix intent** Scope the spice check by name like the other two (or subtract the 23 known names), and restate the expectation. Also drop or re-word the "48 panels (47 new rows + `Salt`)" claim, since `Salt` will not be written.
- **How to verify** On the rehearsal branch, before the apply: `select count(*) filter (where nutrition_source='usda'), count(*) from catalog_items where category='spices';` → expect 16 / 23.

## FIND-003 — Four of the seven `[manual]` acceptance expectations describe behaviour the app does not have
- **Severity** High · **Category** test-gap / docs-truth · **Confidence** confirmed
- **Location** `docs/ACCEPTANCE_TESTS.md` (three new sections, rows 1 of each) vs `src/features/data/serverRepository.ts:554-562`
- **Symptom** The Add tab's search field renders **only** `useCatalogSearch` → `catalogSearch`, which is `ilike('name', '%term%')`. **Aliases are not in that query and no client-side `matchCatalog` fallback exists in `SearchCapture.tsx`.** So:
  - `haldi` → expects **Turmeric**. No row's *name* contains "haldi" → **zero results**.
  - `seltzer` → expects **Sparkling water**. Only `Hard seltzer` matches by name → **wrong row**.
  - `potstickers` → expects **Dumplings**. No name contains it → **zero results**.
  - `peppercorns` → expects **Black pepper**. Returns Black/Green/Pink/White peppercorns → **wrong row**.
  - `green onions` → the doc says it is "the check that fails if the apply ran without section (h)". It matches the row **by name** and passes with or without section (h); the alias it claims to prove (`scallions`) is untestable through this field. **Rationale false.**
  (`za'atar`, `kosher salt`, `oat milk`, `frozen peas`, `tilapia`, `english muffin`, `chicken wings` do pass — they match by name.)
- **Impact** These `[manual]` rows are the only human verification this PR gets. Four of them cannot pass, so a device pass either reports a false failure or the tester "fixes" the expectation and the alias work goes unverified forever.
- **Fix intent** Rewrite the alias rows to exercise the path that actually uses aliases — the grocery add field's silent categorization on Return (`AddGroceryInput.addTyped` → `categorizeGroceryName`): "type `haldi` in the grocery field, press Return, the item files itself under Spices." Or make the type-ahead search aliases (a repository change, out of scope here).
- **How to verify** Read `catalogSearch`; then on device type `haldi` in the Add tab with the apply landed.

---

## FIND-004 — `plant-based burger` confidently mis-matches `Plant-based creamer` (a dairy row), and the test accepts it
- **Severity** Medium · **Category** logic / test-gap · **Confidence** confirmed
- **Location** new row `Plant-based creamer` (`supabase/seed.sql`, thin half, `dairy_eggs`, `{}`); assertion `tests/catalog-seed-extension.test.ts:1940`
- **Symptom** Against the seed alone, `matchCatalog('plant-based burger', seed)` returns **`Plant-based creamer`** at score 0.667 / coverage 0.667 — over both gates, so it is a **confident auto-link**. Candidates: `Plant-based creamer:0.67 | Veggie burgers:0.40 | Hamburger buns:0.40`. The intended target (`Veggie burgers` via the apply-only alias `plant-based burger`) only wins after section (h) lands. The suite's guard is `expect(matchCatalog(probe, catalog).match?.name).not.toBe('Veggie burgers')` — which a *wrong* confident match satisfies just as well as no match. The other four applied-probes (`scallions`, `bbq sauce`, `chopped walnuts`, `pepitas`) correctly return `NONE` before the apply; this one is the outlier and the test cannot tell the difference.
- **Impact** A vegan burger silently filed as `dairy_eggs` and linked to a creamer — a category/allergen-class error through a silent auto-link, which is the failure `supabase/functions/_shared/match.ts:88-95` says the design exists to prevent. It is live for (a) every project seeded from `scripts/hosted-seed-catalog.sql`, which by its own header carries none of the apply's generated-row aliases, and (b) the whole window between merge and apply if the order ever slips.
- **Fix intent** `Plant-based creamer` is a **new** row, so renaming is free (no inventory references): `Non-dairy creamer` with `plant-based creamer` as an alias removes the collision outright. Alternatively give `Plant-based burger` its own hand row — §Families names it as an item. And tighten the assertion to `expect(match).toBeNull()` where that is the real claim.
- **How to verify** `matchCatalog('plant-based burger', seedRows)` → `Plant-based creamer`.

## FIND-004b — "null by design, not a queue" is unenforced: spec 45's deployed shelf-life route will overwrite ~15% of the abstentions, with rules #199 explicitly rejects
- **Severity** Medium · **Category** contract / logic · **Confidence** confirmed
- **Location** `workers/src/routes/shelfLife.ts:296-400,695` (`fillUsdaNutrition`, guarded only `nutrition is null and cardinality(barcodes)=0 and nutrition_source is distinct from 'off'`) vs `docs/adr/catalog.md` O1's new paragraphs ("they ship `nutrition = null` and that is the finished state, **not a queue**")
- **Symptom** Spec 45 (#156) is merged and deployed: any shelf-life pass that touches a catalog row calls `matchUsda(name, prefiltered usda_foods)` and writes a panel if it finds one. It cannot tell a deliberate abstention from an unfilled row. I ran the real `matchUsda` (plus an emulation of the Worker's `ilike any` prefilter, cap 400) over a 113-name sample of #199's null-by-design rows: **17 matched, 15 of them genuinely null in #199** (Saffron and Mace are false positives of my sample — #199 does fill those).

  | #199 row (null by design) | what spec 45 would write | why #199 abstained |
  |---|---|---|
  | `Orange blossom water` | 2710647 **"Orange Blossom", 98 kcal** | **plainly wrong food** — 98 kcal/100 g for an aromatic water |
  | `Lobster` | 2706349 "Lobster" (FNDDS, 97) | three raw entries at 59 / 77 / 112; and #199's own rule bars an FNDDS as-consumed value for a raw food |
  | `Epazote` | 169398 "Epazote, **raw**" (32) | the row is a *dried* herb (730 d); wrong state |
  | `Kashmiri chili powder` | 171319 "Spices, chili powder" | a different chile — the representative-entry move #199 declined |
  | `Cake mix` | 172701 "Cake, **gingerbread**, dry mix" | row names a category, not a food |
  | `Mixed greens`, `Potato salad`, `Coleslaw`, `Frozen mixed vegetables` | FNDDS composites | "mixed bags and blends" — a panel would be a guess about proportions |
  | `Kombucha`, `Hard seltzer`, `Sparkling wine`, `Energy drink`, `Dragon fruit`, `Pork belly` | various | "foods FDC does not describe" (they now do, in FNDDS) |

- **Impact** The ADR paragraph this PR adds is a claim nothing enforces. Within days of the apply, the abstentions start filling in opportunistically with numbers chosen by a *different* rule set than the one the apply file writes down and the reviewer is asked to check — including at least one that is simply the wrong food. That is the exact failure ADR O1 exists to prevent ("a number needs a source that describes the thing").
- **Fix intent** Either mark the deliberate abstentions so the runtime filler skips them (a `nutrition_source = 'none'` sentinel, or a `nutrition_checked_at` column — needs a migration and a spec line), or soften ADR O1 to say the nulls are *this pass's* answer and spec 45's route may later fill them. Independently, `Orange blossom water` matching "Orange Blossom" is a spec 45 bug worth its own ticket.
- **How to verify** `matchUsda('Orange blossom water', prefiltered)` → fdc 2710647, 98 kcal. Or on a rehearsal branch after the apply: run a shelf-life pass over an item linked to one of these rows and re-read `nutrition`.

## FIND-005 — `curry` and `chili` regress to worse rows, decided by the alphabetical tie-break
- **Severity** Medium · **Category** logic · **Confidence** confirmed
- **Location** new rows `Curry leaves` (spices, 730), `Canned chili` (canned, 730), `Chili crisp`, `Chili paste`
- **Symptom** Both are 3+-way ties at dice 0.667 / coverage 1.0, so `matchCatalog`'s final `a.name.localeCompare(b.name)` leg picks the winner:
  - `"curry"` → **main `Curry powder`** → **branch `Curry leaves`** (`Curry leaves:0.67 | Curry paste:0.67 | Curry powder:0.67`)
  - `"chili"` → **main `Chili powder`** → **branch `Canned chili`** (`Canned chili:0.67 | Chili crisp:0.67 | Chili paste:0.67`)
- **Impact** Both are confident matches, so a typed grocery entry auto-links and auto-categorises. "curry" now means a niche South-Indian aromatic leaf; "chili" now means a can of chili con carne in `canned` rather than the spice. Recipe-ingredient matching (spec 8) uses the same function, and recipes say "curry"/"chili" constantly.
- **Fix intent** Not a matcher change — a data one. Add `curry` to `Curry powder`'s aliases and `chili` to `Chili powder`'s (both are hand rows; both alias sets are already grown by section (b), so it is one array element each) so the intended row wins on an exact alias at 1.00.
- **How to verify** The probe table in the appendix; re-run after adding the aliases.

## FIND-006 — Brand names ship in four spice aliases, and the Q9 test does not cover the spice half
- **Severity** Medium · **Category** contract (spec violation) · **Confidence** confirmed
- **Location** `supabase/seed.sql` / `db/apply/catalog-extension-2026-09.sql:108,225-ish` — `Adobo seasoning` → `goya adobo`; `Sazon seasoning` → `sazon goya`; `Kosher salt` → `diamond crystal`, `mortons kosher salt`; `Flaky sea salt` → `maldon`. Test scope: `tests/catalog-seed-extension.test.ts:1519-1530`.
- **Symptom** spec 13 §Out of scope and §Broad extension Q9 exclude brand names ("a brand arrives by barcode"), and the PR body asserts "**No brand names anywhere**". Goya Foods, Diamond Crystal (Cargill), Morton Salt and Maldon Salt Company are all trademarks. `maldon` is not an oversight — it is one of the six named alias-only *probes* the PR advertises, so the suite actively pins a brand alias in place. The Q9 sweep iterates `BROAD_ROWS` only (the 186), and its 16-string list omits `goya`, `maldon`, `morton`, `diamond crystal`.
- **Impact** A stated product rule is broken in the half of the data nobody checked, and one violation is load-bearing in a test.
- **Fix intent** Drop the four aliases (each row keeps a generic alias); widen the Q9 sweep to all 390 new rows and add those four strings. If Everett wants `maldon`/`kosher` retained as shopper vocabulary, that is a spec amendment, not a silent exception.
- **How to verify** Regex `(^|[^a-z])(goya|maldon|morton|diamond crystal)([^a-z]|$)` over all 390 new rows' names+aliases → 4 hits (`black mission figs` is a cultivar, not a brand — false positive).

## FIND-007 — "92 new spice rows carry no panel" is wrong; it is 70, and the number is repeated in four places
- **Severity** Medium · **Category** docs-truth · **Confidence** confirmed
- **Location** `docs/adr/catalog.md` O1 (new spice paragraph, "92 of the 117 new ones have no SR Legacy entry"); `specs/catalog-seed.md:41` (§Spice extension status line); the PR body; and `specs/MIGRATIONS.md`'s 48 / **92** / 140 expectation
- **Symptom** 117 new spice rows, 47 of them written a panel (section (c) has 48 statements, one targeting the pre-existing `Salt`). 117 − 47 = **70**. `db/apply/catalog-extension-2026-09.sql:2851` has it right ("47 new rows carry one; the other 70 are null by design"); every other document says 92, which is `140 − 48` — the same category-scoping mistake as FIND-002.
- **Impact** The ADR is the durable record of *which foods are deliberately null*, and it is off by 22 rows. It is also the arithmetic the rehearsal expectation is built on.
- **Fix intent** 92 → 70 in the ADR, the spec status line and the registry.
- **How to verify** Count section (c)'s statements and subtract the one whose target is not a section (a) insert.

## FIND-008 — ADR O1's thin-category paragraph still carries the pre-reversal numbers
- **Severity** Medium · **Category** docs-truth · **Confidence** confirmed
- **Location** `docs/adr/catalog.md` O1, the "And the same for the thin categories" paragraph
- **Symptom** It says "Of the **80** plant-milk, frozen, drink, fish and canned-fish rows, **43** carry an FDC panel and **37** are null." The pruned-seven decision — implemented in this same PR — makes it **87 / 49 / 38**, which is what the apply file, the spec's §Acceptance and the registry all say. The ADR paragraph was not updated.
- **Impact** The ADR is the entry a future reviewer cites; it now contradicts the file it points at.
- **Fix intent** 80 → 87, 43 → 49, 37 → 38, and add `Oysters` to the "entries disagree materially" list (51/59/81), which the paragraph omits.
- **How to verify** Count section (d) inserts (87) and section (f) statements (49).

---

## FIND-009 — `catalog-review.sql` query 3 expects 538, one amendment out of date
- **Severity** Low · **Category** docs-truth · **Confidence** confirmed
- **Location** `supabase/snippets/catalog-review.sql:47` — "Expect seed = 538"
- **Symptom** 538 is the amendment-1 total. Amendments 2 and 3 took it to 625 and then **811**; the snippet was updated once and then missed twice.
- **Fix intent** 538 → 811 (and note the pre-apply value is 421+user rows, so the number only holds after the apply).

## FIND-010 — New rows create confident matches for generic single words
- **Severity** Low · **Category** logic · **Confidence** confirmed
- **Location** new rows `Rice paper`, `Baked beans`, `Blue cheese`, `Club soda`, `Iced tea`, `Sparkling water`
- **Symptom** Answers that were `NONE` (or something else) on main are now confident:
  - `"paper"` → **Rice paper** (0.67, `grains_pasta`). "paper" is common shorthand for paper towels; the household-supply query now auto-links to a food. (`paper towels` itself still correctly returns `NONE`.)
  - `"beans"` → main `Bean sprouts` → branch **`Baked beans`** (`canned`), a 3-way tie broken alphabetically.
  - `"blue"` → **Blue cheese**; `"club"` → **Club soda**; `"iced"` → **Iced tea**; `"sparkling"` → **Sparkling water**.
- **Impact** Mostly benign; `"paper"` is the one that files a non-food as `grains_pasta`.
- **Fix intent** None required beyond awareness; if `"paper"` matters, `Rice paper` could carry `rice paper sheets` and the row name stays as is (the collision is the *name*, so only a matcher change or a stopword fixes it — probably not worth it).

## FIND-011 — Four rows exceed spec 13's six-alias cap after the apply, not the two the PR documents
- **Severity** Low · **Category** contract · **Confidence** confirmed
- **Location** section (b)/(e)/(h) alias updates
- **Symptom** Post-apply counts: `Cumin` 7, `Cracked black pepper` 7 (both documented), **`Lox` 8**, **`Veggie burgers` 7** (neither documented). All are well under 0029's hard cap of 24, so nothing breaks.
- **Fix intent** One line in the apply file's section (e)/(h) note; or trim a residue alias.

## FIND-012 — "167 of the 390 new rows are null by design" is 168
- **Severity** Low · **Category** docs-truth · **Confidence** confirmed
- **Location** `specs/README.md` row 13; `specs/MIGRATIONS.md` registry bullet ("the other 167 new rows are null by design")
- **Symptom** 223 panel statements, one of which targets the pre-existing `Salt`, so 222 new rows get a panel: 390 − 222 = **168** (70 + 38 + 60, which is what the PR's own table says).

## FIND-013 — `[same material]` accounting does not match the file
- **Severity** Low · **Category** docs-truth · **Confidence** confirmed
- **Location** PR body ("25 of the 48 are flagged `[same material]`") vs `db/apply/catalog-extension-2026-09.sql`
- **Symptom** The file carries **11** `[same material, other form]` flags (Black/Brown/Yellow mustard seeds, Black/White peppercorns, Cardamom pods, Cinnamon sticks, Coriander, Whole allspice, Whole cloves, Whole nutmeg). Separately, two panels are arguably the same case and are **not** flagged: `Dried sage` ← "Spices, sage, **ground**" and `Dried savory` ← "Spices, savory, **ground**".
- **Fix intent** Correct the PR text; flag the two unflagged ones so the "every same-material panel names its form" claim is true.

## FIND-014 — `catalogIndex` fetches the whole catalog with no `limit`; the failure mode is silent truncation
- **Severity** Low · **Category** reliability · **Confidence** likely (depends on the Neon Data API's row cap, which I could not query)
- **Location** `src/features/data/serverRepository.ts:546-552`; doc comment `src/features/catalog/hooks.ts:17-19`
- **Symptom** No `.limit()` — the client relies on the server's default max rows for a table that just went 421 → 811 (plus every visible `user` row). PostgREST deployments commonly cap at 1000. If the cap is hit the request **succeeds** with a truncated array: grocery categorization and recipe matching silently lose rows with no error anywhere. The doc comment ("~421 rows, a few tens of KB") is now stale — the index payload measures **50 KB → 104 KB** of JSON for name+aliases+category+id alone.
- **Fix intent** Confirm the Data API's cap during the rehearsal (`select count(*) from catalog_items` vs what the client receives), and either paginate or assert the count client-side. Update the comment either way.

## FIND-015 — Two of the 93 "pre-existing rows" were created by this same PR
- **Severity** Low · **Category** test-gap · **Confidence** confirmed
- **Location** `BROAD_EXISTING` in `tests/catalog-seed-extension.test.ts`
- **Symptom** `Curry leaves` and `Wasabi powder` are asserted as rows that "already existed and were left exactly as they are"; both were added by the spice half of this PR. (§Families anticipated it for Curry leaves — "alias only if the spice pass added it" — not for Wasabi powder, which §Families names as `Wasabi`, a condiment.)
- **Impact** The assertion is circular for those two, and `Wasabi` (a condiment) resolves to `Wasabi powder` in `spices` at 0.67.

## FIND-016 — Matching cost doubles; one O(n) scan per matched row in the Worker
- **Severity** Low · **Category** reliability · **Confidence** confirmed
- **Location** `supabase/functions/_shared/match.ts` (`matchCatalog`); `workers/src/routes/shelfLife.ts:475`
- **Symptom** Measured on this machine: a 60-item receipt batch goes **40.1 ms → 86.8 ms** of CPU (surfaces 1054 → 2262). Scaling is linear — **no O(n²) appeared**, and the `WeakMap` caches for the normalized catalog and the fuzzy index hold. `shelfLife.ts:475` re-scans the catalog array (`.find`) once per matched row, which is now 811 entries per row.
- **Fix intent** Nothing urgent; if the Worker's CPU budget is tight on `parse-receipt`, build the `byId` map once in `shelfLife.ts` as `receipt.ts:195` already does.

---

## Notes

- **FIND-017 (Note)** `scallions` is a §Families **produce** item, and the acceptance box "every §Families item present by name or alias" is ticked — but it is present only *after* the apply (it is one of the 18 generated-row aliases). A project seeded from `scripts/hosted-seed-catalog.sql` alone fails that criterion for all 18. The file's header says so; the ticked box does not.
- **FIND-018 (Note)** `"peas"` → main `Green beans`, branch **`Frozen peas`** — a three-way 1.00 tie (`Frozen peas | Green beans | Split peas`) broken alphabetically. Better than what it replaced, but there is still no plain `Peas` row and the winner is arbitrary.
- **FIND-019 (Note)** `Jackfruit` is filed `canned` `{"pantry":730}` and is the only row answering "jackfruit", so the **fresh** produce query gets a canned shelf life. Per spec (the canned family names it), recorded because §Families produce also names it.
- **FIND-020 (Note)** `specs/MIGRATIONS.md`'s new bash comment says "read **BOTH** trailing counts" while there are four; the registry bullet below it says four.
- **FIND-021 (Note, cross-PR)** `origin/main` moved to `9f00914` mid-review: **spec 59 (the `frozen` category) merged as #200** while this review ran. #199 still merges cleanly into it (verified with `git merge-tree` — no conflicts, including `docs/adr/catalog.md`, `specs/MIGRATIONS.md` and `specs/README.md`). But `specs/frozen-category.md:3` names its dependency as "spec 13 … incl. the 2026-09-06 **spice and thin-category** amendments" and its §What-is-`frozen` list enumerates frozen vegetables/fruit/potatoes/açaí/shrimp/fish/lobster tails/breaded fish — it was written **before the broad extension existed**, so #199's eight frozen-sold `other` rows (`Bao`, `Dumplings`, `Gyoza`, `Pierogi`, `Spring rolls`, `Falafel`, `Frozen breakfast sandwiches`, and `Seitan` beside Tempeh) are **not** in spec 59's re-file list even though #199's Q10 says spec 59 will re-file them. Whoever writes `db/apply/catalog-frozen-refile-2026-09.sql` needs #199's Q10 list added, or those eight stay in `other` forever. Worth one line in #199's PR description so the next builder sees it.

---

## Verified clean (attacks that found nothing)

**The data apply** — `db/apply/catalog-extension-2026-09.sql`
- 270 statements, one `begin;`/`commit;` pair. 3 inserts (117 + 87 + 186 = **390**), 38 alias updates (14+16+8), 223 nutrition updates (48+49+126). Every count in the PR body matches the file.
- **Every one of the 261 updates** carries `where lower(name) = lower('…')` **and** `and source = 'seed'`. No statement can touch a `user`, `ai` or `off` row. No update without a `WHERE`.
- All three inserts carry `on conflict do nothing` (unqualified, so 0017's `lower(name)` index is the anchor). A user-held name keeps the user's row and neither the alias nor the panel update reaches it — correct, and the file says so.
- **Alias updates UNION, they never replace**: `aliases || array(select a from unnest(array[…]) a where a <> all(aliases))`. Grow-only; a second run adds nothing; no curated or later-added alias can be dropped.
- **Idempotent by construction**: inserts skip on conflict, alias updates are set-union, panel updates are gated `nutrition is null`.
- Panel guards: all 223 carry `nutrition is null and cardinality(barcodes) = 0 and source = 'seed'` and all 223 set `nutrition_source = 'usda'`. (`barcodes` is `not null default '{}'` and `source` `not null default 'seed'` — 0001 — so the rows inserted earlier in the same transaction *do* qualify.)
- Quoting: the only apostrophe (`Za''atar`, `:225`) is correctly doubled. No non-ASCII in any canonical name.
- The registry's psql line sits **last** in the first bash block with no `migrations/NNNN_` argument, so `tests/migrations-registered.test.ts`'s ascending-order tripwire is unaffected — and the whole suite is green (**198 suites, 4164 passed, 4 skipped**).

**Apply ↔ seed ↔ hosted seed**
- All **390** insert rows match `supabase/seed.sql` exactly on name, aliases, category and shelf life. All 38 alias-update targets and all 223 panel targets exist in the seed.
- `scripts/hosted-seed-catalog.sql` is row-for-row identical to `seed.sql` (811 rows, 481 hand + 330 generated) — zero mismatches.
- **811 rows, 811 distinct `lower(name)`** — no duplicate anywhere, hand or generated. (0017's index would have killed the apply mid-flight.)
- The generated block differs from `origin/main` by **exactly the 16 documented pruned aliases** across 10 rows, and nothing else — no category, shelf-life or row change.
- The thin and broad count-check name lists (87 and 186 entries) match their insert sets **exactly**, in both directions.
- `scripts/seed-report.md`'s "aliases pruned 53 → 69" is consistent with the 16 prunings.

**Seed hygiene (all 390 new rows)**
- Zero alias-hygiene defects: none > 6 aliases, none uppercase, none equal to its own row name, no within-row duplicates, no stray whitespace.
- All names Title case (interior capitals are proper nouns only: Brussels, Provence, Old Bay, Himalayan); max name length 31 (cap 120); max alias-string length 87 (cap 1500); max alias count 6 (cap 24). No `food_category` value outside 0001's enum.
- Shelf lives: every spice row is one of the eight table values (35 × 1460 whole+extracts, 27 × 548 blends, 24 × 913 ground, 17 × 730 herbs, 9 × 1825 salts+MSG, 5 × 365 chiles = 117); every thin row deep-equals one of the 15 table rows (87 accounted for exactly); every broad row falls in the transcribed `BROAD_SHELF` table, and that transcription matches the spec's table row for row. The only `{}` rows are the eight plant milks and creamers, as §Shelf lives requires.

**Nutrition — the strongest part of the PR**
- I rebuilt an index of all **13,587** rows of `~/agents/usda/usda-foods-seed.sql` and compared every one of the **223** panels:
  - **0** fdc_ids missing from the mirror
  - **0** panel value mismatches — every key and every number is byte-identical to the mirror's entry
  - **0** description mismatches — the `-> <FDC description>` in each comment equals the mirror's `description` exactly
  - **0** keys outside `Nutrition` in `src/lib/types.ts`; 0 non-numeric or negative values
- No panel is invented, none is estimated, and every one is traceable. The `[same material]` claims that *are* flagged are defensible (ground vs whole of the same spice, fdc_id and form named). The two shared-entry pairs (`Baguette`/`Sourdough bread` ← 172675, `Hamburger buns`/`Hot dog buns` ← 172796) are legitimate: the FDC description names both foods.

**Matching regressions (the highest-value check)**
- **Spec 13 §Acceptance probe list (20 queries): 20/20 unchanged.** cumin, tortillas, greek yogurt, cheddar, salmon, hummus, oat, lentil, sriracha→Hot sauce, pistachio, rotisserie, kimchi, ghee, tofu, arugula, balsamic, granola, baking soda, mozzarella, deli turkey all resolve exactly as on main.
- **Receipt-style list (15 queries): 15/15 unchanged**, including the two that legitimately return `NONE` on both (GRND BEEF, EGGS LG).
- **Grocery categorizer (20 typed names): 19/20 unchanged, 1 improvement** (`salmon fillet` NONE → Salmon / meat_seafood).
- **Full sweep of every name and alias on `origin/main` (881 queries): 19 changes, all improvements** — bucket rows losing a word to the specific row that now owns it (cod/haddock/halibut→Cod/Haddock/Halibut, clams/mussels/oysters→their own rows, raisins→Raisins, brisket→Brisket, kielbasa→Kielbasa, nectarines→Nectarines, lychee→Lychee, Papaya→Papaya, tater tots→Tater tots, diet sodas→Diet soda, peas→Frozen peas). None is a staple losing its row.
- **Self-resolution of all 390 new rows**: 0 name misroutes, 0 unmatched aliases, 3 alias misroutes to pre-existing rows (`tangerines`→Citrus fruit, `salad greens`→Arugula, `sweets`→Baking chocolate) — dead weight, not regressions.
- The **16 pruned aliases** are safe post-apply: the apply never removes an alias, so production keeps `cod` on `White fish` beside the new `Cod`, and `matchCatalog`'s name-over-alias tie-break sends `cod` to `Cod` either way. Verified against a catalog carrying both.

**Tests**
- `tests/catalog-seed-extension.test.ts` runs **640 cases, all green**, and is **not vacuous**: I mutated one alias in `supabase/seed.sql` (`coarse salt` → `coarse salts`) and the apply↔seed pinning failed immediately. Restored.

---

# Appendix A — matching answers that changed (main → branch)

## A1. Full sweep of main's own surfaces (881 queries, 19 changes — all bucket → specific row)

| query | main | branch | verdict |
|---|---|---|---|
| `cod` | White fish | **Cod** | improvement |
| `haddock` | White fish | **Haddock** | improvement |
| `halibut` | White fish | **Halibut** | improvement |
| `clams` / `clam` | Live shellfish | **Clams** | improvement |
| `mussels` / `mussel` | Live shellfish | **Mussels** | improvement |
| `oysters` | Live shellfish | **Oysters** | improvement |
| `tater tots` | French fries | **Tater tots** | improvement |
| `raisins` / `raisin` | Dried fruit | **Raisins** | improvement |
| `brisket` | Beef roast | **Brisket** | improvement |
| `kielbasa` | Smoked sausage | **Kielbasa** | improvement |
| `nectarines` | Stone fruit | **Nectarines** | improvement |
| `lychee` | Cherries (sweet) | **Lychee** | improvement |
| `Papaya` | Mango | **Papaya** | improvement |
| `diet sodas` | Soda | **Diet soda** | improvement |
| `peas` / `Pea` | Green beans | **Frozen peas** | improvement (still arbitrary — FIND-018) |

## A2. Everyday-vocabulary sweep (271 queries, 63 changes) — the ones that are NOT simply NONE → a new row

| query | main | branch | verdict |
|---|---|---|---|
| `curry` | Curry powder [spices] | **Curry leaves** [spices] | **regression — FIND-005** |
| `chili` | Chili powder [spices] | **Canned chili** [canned] | **regression — FIND-005** |
| `paper` | NONE | **Rice paper** [grains_pasta] | **regression — FIND-010** |
| `beans` | Bean sprouts [produce] | **Baked beans** [canned] | lateral (both arbitrary) |
| `swiss` | Swiss chard [produce] | **Swiss cheese** [dairy_eggs] | improvement |
| `lobster` | Lobster tails | **Lobster** | improvement |
| `hot dog buns` | Hot dogs [meat_seafood] | **Hot dog buns** [grains_pasta] | improvement |
| `blue` | NONE | **Blue cheese** | neutral |
| `club` / `iced` / `sparkling` | NONE | Club soda / Iced tea / Sparkling water | neutral |

The remaining 54 are `NONE → <the new row>`, which is the point of the PR: beer, candy, ranch, turmeric, tilapia, seltzer, tonic, lemonade, kombucha, naan, pita, croissant, baguette, sourdough, buns, rolls, donuts, ramen, udon, soba, couscous, farro, feta, provolone, gouda, wings, jalapeno, cumin seeds, oat milk, goat cheese, chicken wings, kosher salt, romaine lettuce, pancake mix, apple juice, tomato sauce, pie crust, hamburger buns, english muffins, rye bread, sushi, canned soup, …

## A3. Not fixed by the seed, only by the apply (correct, but the seed-only state is what jest and a fresh project see)

| query | seed alone | after the apply |
|---|---|---|
| `scallions` | NONE | Green onions |
| `bbq sauce` | NONE (top candidate **Applesauce** 0.67) | Barbecue sauce |
| `chopped walnuts` | NONE | Walnuts |
| `pepitas` | NONE | Pumpkin seeds |
| `plant-based burger` | **Plant-based creamer [dairy_eggs] 0.67 — confident** | Veggie burgers |
| `smoked salmon` | NONE | Lox |
| `calamari` / `fish sticks` / `sea scallops` / `fish fillets` | NONE | Squid / Breaded fish (frozen) / Scallops / Fish (frozen) |

# Appendix B — measurements

| | main (421 rows) | branch (811 rows) |
|---|---|---|
| catalog rows | 421 (91 hand + 330 generated) | 811 (481 + 330) |
| matchable surfaces (names + aliases) | 1,054 | 2,262 |
| client catalog-index JSON (id+name+aliases+category) | 50,450 B | 103,716 B |
| `scripts/hosted-seed-catalog.sql` | 35,623 B | 79,126 B |
| 60-query `matchCatalog` batch, cold array | 40.1 ms | 86.8 ms |
| 60-query `matchCatalog` batch, warm caches | 37.7 ms | 83.4 ms |

Scaling is linear in surfaces; no quadratic behaviour appeared at 811 rows.
