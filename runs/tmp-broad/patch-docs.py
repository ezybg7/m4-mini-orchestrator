import sys
ROOT = '/Users/orchestrator/agents/worktrees/broad/'
n = 0


def patch(path, pairs):
    global n
    s = open(ROOT + path).read()
    for a, b in pairs:
        if a not in s:
            print('MISS in %s: %r' % (path, a[:140]))
            sys.exit(1)
        s = s.replace(a, b, 1)
        n += 1
    open(ROOT + path, 'w').write(s)


# ---------------------------------------------------------------- MIGRATIONS
patch('specs/MIGRATIONS.md', [
    ("""# DATA APPLY, no migration number — `db/apply/catalog-extension-2026-09.sql` (spec 13
# §Spice extension AND §Thin-category extension — both amendments, one file, one
# transaction). It goes LAST in this block because it HAS no number: the""",
     """# DATA APPLY, no migration number — `db/apply/catalog-extension-2026-09.sql` (spec 13
# §Spice extension AND §Thin-category extension AND §Broad extension — all three
# amendments, one file, one transaction). It goes LAST in this block because it HAS no number: the"""),

    ("""# expect: spices 140 (23 + 117); dairy_eggs +8, produce +21, meat_seafood +13,
# canned +4, beverages +34; catalog total 628 (431 + 117 + 80). Second check:
# 48 usda_panels / 92 no_panel / 140 spice_rows. Third check: 80 thin_rows /
# 43 usda_panels / 37 no_panel. `on conflict do nothing` means a LOWER insert
# count is possible (a user had already created the name) — record it in the
# registry entry rather than treating it as a failure. Re-run it on the same
# branch to prove idempotence: every count must be unchanged.""",
     """# expect: spices 140 (23 + 117); the thin families add dairy_eggs +8, produce
# +22, meat_seafood +19, canned +4, beverages +34; the twelve broad families then
# add produce +26, dairy_eggs +18, meat_seafood +16, grains_pasta +37, baking
# +17, canned +19, condiments_oils +24, snacks +16, other +13; catalog total 821
# (431 + 117 + 87 + 186). Second check: 48 usda_panels / 92 no_panel /
# 140 spice_rows. Third check: 87 thin_rows / 49 usda_panels / 38 no_panel.
# Fourth check: 186 broad_rows / 126 usda_panels / 60 no_panel. `on conflict do
# nothing` means a LOWER insert count is possible (a user had already created the
# name) — record it in the registry entry rather than treating it as a failure.
# Re-run it on the same branch to prove idempotence: every count must be
# unchanged."""),
])

MIG_OLD = open(ROOT + 'specs/MIGRATIONS.md').read()
start = MIG_OLD.index('- ⏳ **Data apply (not a migration — no schema change): `db/apply/catalog-extension-2026-09.sql`**')
end = MIG_OLD.index('\n', start)
NEW_ENTRY = (
    '- ⏳ **Data apply (not a migration — no schema change): `db/apply/catalog-extension-2026-09.sql`** '
    '(specs/catalog-seed.md §"Spice extension (amendment, 2026-09-06)", §"Thin-category extension (amendment, 2026-09-06)" '
    'AND §"Broad extension (amendment, 2026-09-06) — the twelve thin families" — all three amendments ship in this one file, '
    'one transaction, one trailing count block; it was `catalog-spices-2026-09.sql` until the second amendment widened it on '
    '2026-09-06, before any apply) — **generated 2026-09-06, NOT rehearsed, NOT applied.** Adds **390 rows** to `catalog_items`: '
    '**117 `spices`** (23 → 140), **87 thin-category rows** — 8 plant milks and creamers (`dairy_eggs`), 22 frozen vegetables and '
    'fruit (`produce`), 19 fish and shellfish (`meat_seafood`), 4 canned fish (`canned`), 34 drinks (`beverages`) — and '
    '**186 rows across the twelve thin families**: 26 `produce`, 18 `dairy_eggs`, 16 `meat_seafood`, 37 `grains_pasta`, '
    '17 `baking`, 19 `canned`, 24 `condiments_oils`, 16 `snacks`, 13 `other`. Grows the aliases of **38** existing rows '
    '(14 spice + 16 thin + 8 broad; 18 of the 38 target generated rows whose aliases can only live here). Writes **223 USDA '
    'panels** — 48 spice (47 new rows plus `Salt`), 49 thin-category and 126 broad; the other 167 new rows are null by design. '
    '**No `food_category` enum value is added** and no client code changes: every family lands on a category the seed already '
    'uses (spec 59 owns `frozen`, and the frozen-sold rows here are filed `other` until it lands — §Broad extension Q10). '
    'One transaction. Every insert carries `on conflict do nothing` against 0017\'s `catalog_items_name_key (lower(name))`, so a '
    'name a user already created keeps THEIR row; every alias update appends only what is missing; every nutrition update is '
    'guarded `nutrition is null and cardinality(barcodes) = 0 and source = \'seed\'` — so the file is **idempotent** end to end '
    'and re-running it changes nothing. Nothing is renamed, deleted or re-categorised: `inventory_items` rows reference these ids. '
    '**One consequence of the 2026-09-06 pruned-items decision to note at rehearsal time:** `Cod`, `Haddock`, `Halibut`, `Clams`, '
    '`Mussels`, `Oysters` and `Tater tots` are now rows of their own, and the seed\'s GENERATED block loses the sixteen aliases '
    'that equal one of the new hand names. This file does NOT remove those aliases from production — it only ever adds — so after '
    'the apply `White fish` still carries `cod` while `Cod` exists beside it; `matchCatalog` breaks that tie name-over-alias, so '
    'the new row wins the query either way, and `supabase/snippets/catalog-review.sql` queries 7 and 8 list the pairs for a future '
    'merge migration. The same rows live in `supabase/seed.sql` (the source of truth, which seeds a fresh project together with the '
    'regenerated `scripts/hosted-seed-catalog.sql`, 811 rows); `tests/catalog-seed-extension.test.ts` pins that the two files agree, '
    'row for row, for all three amendments. **Apply-before-merge**: rehearse on a Neon branch cut from production, read all four '
    'trailing counts, apply to production, flip this entry to ✅, then merge the PR. Its psql line is at the foot of the shared block '
    'above — last, because a data apply has no number and the tripwire checks that the numbered arguments ascend. **Record in this '
    'entry after the rehearsal:** the branch name, `select category, count(*)` before and after, the second check\'s '
    '`usda_panels / no_panel / spice_rows` (expect 48 / 92 / 140), the third check\'s `thin_rows / usda_panels / no_panel` '
    '(expect 87 / 49 / 38), the fourth check\'s `broad_rows / usda_panels / no_panel` (expect 186 / 126 / 60), the row count actually '
    'inserted (390 unless a user-created name collided), and the output of queries 6, 7 and 8 (`duplicate families`) in '
    '`supabase/snippets/catalog-review.sql`. Validated before the PR only as far as this machine allows: the file parses under '
    '**libpg_query (pglast 7.18, PG 17.7)** — 270 statements, clean — and all 390 insert rows are pinned byte-equal to the seed\'s by '
    'jest; there is no database in this repo\'s development loop, so the counts above are predictions from the 2026-09-06 production '
    'probe (431 rows, 23 spices) and not measurements.'
)
s = MIG_OLD[:start] + NEW_ENTRY + MIG_OLD[end:]
open(ROOT + 'specs/MIGRATIONS.md', 'w').write(s)
n += 1

# ---------------------------------------------------------------- specs/README
README = open(ROOT + 'specs/README.md').read()
old_start = README.index('| 13 | [catalog-seed](catalog-seed.md) |')
old_end = README.index('\n', old_start)
NEW_ROW = (
    '| 13 | [catalog-seed](catalog-seed.md) | ✅ built (811 items: 481 hand + 330 FoodKeeper-generated; nutrition = barcode-only, '
    'decision recorded — **reversed 2026-08-08**, generic rows carry USDA panels). **Three amendments, 2026-09-06, one PR and one '
    'data apply.** §Spice extension: `spices` 23 → 140 rows, 117 new, 48 USDA panels. §Thin-category extension: 87 more rows closing '
    'the basket probe\'s five misses — plant milks (`dairy_eggs`), frozen vegetables and fruit (`produce`), fish and shellfish '
    '(`meat_seafood`), canned fish (`canned`), drinks (`beverages`), 49 panels; the seven bucket-alias items (`Cod`, `Haddock`, '
    '`Halibut`, `Clams`, `Mussels`, `Oysters`, `Tater tots`) got rows of their own by the orchestrator\'s pruned-items decision. '
    '§Broad extension: 186 rows across the twelve thin families the 267-item broad probe half-missed — bakery, international, '
    'breakfast, grains and pasta, snacks, condiments, canned, baking, dairy, meat, deli and produce — 126 panels. No new '
    '`food_category` value and no client change; 167 of the 390 new rows are null by design. Acceptance `e2e: n/a` + 5 `[manual]`. '
    'Seed and `scripts/hosted-seed-catalog.sql` are in the repo; **`db/apply/catalog-extension-2026-09.sql` is ⏳ NOT applied** '
    '(specs/MIGRATIONS.md §Pending applies) | — | — |'
)
open(ROOT + 'specs/README.md', 'w').write(README[:old_start] + NEW_ROW + README[old_end:])
n += 1

# ---------------------------------------------------------------- ACCEPTANCE
patch('docs/ACCEPTANCE_TESTS.md', [
    ("""| 2 | `[manual]` Add **Frozen peas** to a **Freezer** location, then add it again to a **Fridge** location | The freezer copy is dated **~14 months out** (420 days) and the fridge copy **4 days** out — the row carries both and the LOCATION picks, which is the whole point of §Category mapping filing frozen food under `produce` rather than inventing a `frozen` category. The fridge copy shows up in Expiring within the week; the freezer copy does not |
""",
     """| 2 | `[manual]` Add **Frozen peas** to a **Freezer** location, then add it again to a **Fridge** location | The freezer copy is dated **~14 months out** (420 days) and the fridge copy **4 days** out — the row carries both and the LOCATION picks, which is the whole point of §Category mapping filing frozen food under `produce` rather than inventing a `frozen` category. The fridge copy shows up in Expiring within the week; the freezer copy does not |

### Spec 13 amendment 3 (the twelve thin families) — `e2e: n/a`

**No Maestro flow, deliberately** — third time, same reasoning and the same data
apply (`db/apply/catalog-extension-2026-09.sql`): **186 rows** of seed data in
nine categories the client already knows, no screen, no control, no new code
path, no new `food_category` value. `tests/catalog-seed-extension.test.ts` covers
it hermetically — 640 cases in all now, including every §Families item of all
twelve families resolved through the real `matchCatalog`.

**The check below needs the data apply landed** on whatever the device points at;
until then the type-ahead answers from the pre-amendment shelf.

| # | Action | Expected result |
|---|--------|-----------------|
| 1 | `[manual]` In the Add tab's search field type, one at a time: **english muffin**, **potstickers**, **chicken wings**, **green onions** | Each returns a suggestion: **English muffins**, **Dumplings**, **Chicken wings**, **Green onions**. "potstickers" proves the alias route on a new row and "green onions" proves the one the apply file adds to a *generated* row (`scallions` → Green onions) — that last pair is the check that fails if the apply ran without section (h) |
"""),
])

# ---------------------------------------------------------------- ADR
patch('docs/adr/catalog.md', [
    ("""_**And the same for the thin categories, 2026-09-06**""",
     """_**And once more for the twelve thin families, 2026-09-06** (specs/catalog-seed.md §Broad extension, the third amendment in the same PR and the same data apply). Of the 186 bakery, international, breakfast, grain, snack, condiment, canned, baking, dairy, meat, deli and produce rows, **126 carry an FDC panel and 60 are null** — the same three populations again, and the twelve families forced three clauses of the matching rule into the open, all of them written at the top of `db/apply/catalog-extension-2026-09.sql` so a reviewer can check them: the state that counts is **the state a shopper buys** (raw or dry for anything cooked at home, as-sold for a can, a bottle or a gelatin cup); an **FNDDS survey entry is an as-consumed value**, so it answers for bread, cheese and bottled sauce and never for gnocchi, pierogi or falafel, and it counts only when it is the only candidate; and where two entries carry the **same description** the Foundation one supersedes the legacy one rather than competing with it. The 60 nulls are foods FDC does not describe (seitan, gochujang, harissa, dragon fruit, orzo, basmati), rows that name a category rather than a food (Candy, Canned soup, Cake mix, Mixed greens, the deli salads), and plausible entries that disagree materially (goat cheese 264/364/452 by texture, canned peaches 24-96 by pack, oysters 51/59/81 by stock). Nothing about this entry's Why moves: a number still needs a source that describes the thing._

_**And the same for the thin categories, 2026-09-06**"""),
])

print('patched %d spots' % n)
