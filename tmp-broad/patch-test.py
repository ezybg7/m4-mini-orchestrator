import sys

p = '/Users/orchestrator/agents/worktrees/broad/tests/catalog-seed-extension.test.ts'
s = open(p).read()
n = 0


def rep(a, b):
    global s, n
    n += 1
    if a not in s:
        print('MISS #%d: %r' % (n, a[:120]))
        sys.exit(1)
    s = s.replace(a, b, 1)


rep(""" * The spice shelf and the four thin categories, pinned.
 *
 * specs/catalog-seed.md §"Spice extension (amendment, 2026-09-06)" grew
 * `category = 'spices'` from 23 rows to 140; §"Thin-category extension
 * (amendment, 2026-09-06)" then added 80 plant-milk, frozen, drink and fish rows
 * across five existing categories. Both ship in one PR and one data apply, so
 * they share this file (renamed from `catalog-seed-spices.test.ts` on
 * 2026-09-06). There is no database to check them against — this is a pure suite
 * that reads `supabase/seed.sql`, the one source of truth for the rows, and
 * answers the four questions the amendments' §Test plan asks:""",
    """ * The spice shelf, the four thin categories and the twelve thin families,
 * pinned.
 *
 * specs/catalog-seed.md §"Spice extension (amendment, 2026-09-06)" grew
 * `category = 'spices'` from 23 rows to 140; §"Thin-category extension
 * (amendment, 2026-09-06)" then added 87 plant-milk, frozen, drink and fish rows
 * across five existing categories; §"Broad extension (amendment, 2026-09-06) —
 * the twelve thin families" then added 186 more across nine. All three ship in
 * one PR and one data apply, so they share this file (renamed from
 * `catalog-seed-spices.test.ts` on 2026-09-06). There is no database to check
 * them against — this is a pure suite that reads `supabase/seed.sql`, the one
 * source of truth for the rows, and answers the four questions the amendments'
 * §Test plan asks:""")

rep(""" * The thin-category half adds one thing the spice half did not need: a SECOND
 * catalog, `appliedCatalog`, which is the seed plus the alias updates the data
 * apply carries. Eleven of the rows those families gain aliases on live in
 * seed.sql's GENERATED block, which `scripts/build-catalog-seed.mjs` rewrites
 * from `scripts/data/catalog-rows.json` on every run — so those aliases can only
 * live in the apply file, and `calamari`, `fish sticks` and `smoked salmon` are
 * probes against what production looks like AFTER the apply, not before it.
 */""",
    """ * The thin-category half adds one thing the spice half did not need: a SECOND
 * catalog, `appliedCatalog`, which is the seed plus the alias updates the data
 * apply carries. Sixteen of the rows these families gain aliases on live in
 * seed.sql's GENERATED block, which `scripts/build-catalog-seed.mjs` rewrites
 * from `scripts/data/catalog-rows.json` on every run — so those aliases can only
 * live in the apply file, and `calamari`, `fish sticks`, `smoked salmon`,
 * `scallions` and `pepitas` are probes against what production looks like AFTER
 * the apply, not before it.
 */""")

rep("    expect(seedRows.length).toBe(618);\n    expect(parseRows(handBlock).length).toBe(288);",
    "    expect(seedRows.length).toBe(811);\n    expect(parseRows(handBlock).length).toBe(481);")

rep("""  shellfish: { fridge: 2, freezer: 135 },""",
    """  shellfish: { fridge: 2, freezer: 135 },
  liveShellfish: { fridge: 2, freezer: 75 },""")

rep("""  ['Frozen strawberries', 'produce', 'frozenFruit'],
  // fish and shellfish -> meat_seafood
  ['Catfish', 'meat_seafood', 'leanFish'],""",
    """  ['Frozen strawberries', 'produce', 'frozenFruit'],
  ['Tater tots', 'produce', 'frozenPotato'],
  // fish and shellfish -> meat_seafood
  ['Catfish', 'meat_seafood', 'leanFish'],
  ['Clams', 'meat_seafood', 'liveShellfish'],
  ['Cod', 'meat_seafood', 'leanFish'],
  ['Haddock', 'meat_seafood', 'leanFish'],
  ['Halibut', 'meat_seafood', 'leanFish'],""")

rep("""  ['Mahi-mahi', 'meat_seafood', 'leanFish'],
  ['Octopus', 'meat_seafood', 'shellfish'],""",
    """  ['Mahi-mahi', 'meat_seafood', 'leanFish'],
  ['Mussels', 'meat_seafood', 'liveShellfish'],
  ['Octopus', 'meat_seafood', 'shellfish'],
  ['Oysters', 'meat_seafood', 'liveShellfish'],""")

rep("""/**
 * The 80 new rows, written out rather than derived: name, the category
 * §Category mapping assigns, and which §Shelf lives row it takes. Deriving this
 * from the file under test would make every assertion below vacuous — and these
 * three facts are exactly what a careless edit would change.
 */""",
    """/**
 * The 87 new rows, written out rather than derived: name, the category
 * §Category mapping assigns, and which §Shelf lives row it takes. Deriving this
 * from the file under test would make every assertion below vacuous — and these
 * three facts are exactly what a careless edit would change.
 *
 * Seven of them — `Cod`, `Haddock`, `Halibut`, `Clams`, `Mussels`, `Oysters`
 * and `Tater tots` — were aliases of the FoodKeeper bucket rows in this
 * amendment's first draft. specs/catalog-seed.md §"Decision on the seven pruned
 * items" reversed that: a shopper who types "cod" should land on Cod with its
 * own shelf life and its own panel, not on the `White fish` bucket. The cost is
 * paid in the generated block, where the builder prunes the sixteen aliases that
 * now equal a hand row's name; `scripts/seed-report.md` counts them.
 */""")

rep("""    expect(THIN_ROWS.length).toBeGreaterThanOrEqual(70);""",
    """    expect(THIN_ROWS.length).toBe(87);
    expect(THIN_ROWS.length).toBeGreaterThanOrEqual(70);""")

for a, b in [("['tater tots', 'French fries'],\n  ['frozen french fries', 'French fries'],",
              "['tater tots', 'Tater tots'],\n  ['frozen french fries', 'French fries'],"),
             ("['cod', 'White fish'],", "['cod', 'Cod'],"),
             ("['haddock', 'White fish'],", "['haddock', 'Haddock'],"),
             ("['halibut', 'White fish'],", "['halibut', 'Halibut'],"),
             ("['clams', 'Live shellfish'],", "['clams', 'Clams'],"),
             ("['mussels', 'Live shellfish'],", "['mussels', 'Mussels'],"),
             ("['oysters', 'Live shellfish'],", "['oysters', 'Oysters'],")]:
    rep(a, b)

rep(""" * Run through the real matcher, like the spice half: "present" is only worth
 * asserting if a shopper can reach it. Six entries resolve to a row that
 * ALREADY EXISTED and already answers the phrase, which is the amendment's own
 * idiom ("alias only if X already answers"): `cod`, `haddock` and `halibut` are
 * aliases of `White fish`, `clams`/`mussels`/`oysters` of `Live shellfish`, and
 * `tater tots` of `French fries`. Adding rows under those names would have made
 * the builder prune the aliases off the FoodKeeper rows that carry them, which
 * rewrites seed.sql's generated block — see the PR description.
 */""",
    """ * Run through the real matcher, like the spice half: "present" is only worth
 * asserting if a shopper can reach it. `frozen edamame`, `smoked salmon`,
 * `fish sticks` and `sea scallops` still resolve to rows that ALREADY EXISTED,
 * which is the amendment's own idiom ("alias only if X already answers"); the
 * seven that used to join them — `cod`, `haddock`, `halibut`, `clams`,
 * `mussels`, `oysters` and `tater tots` — have rows of their own since the
 * pruned-items decision, and these cases are what proves the promotion reached
 * the type-ahead rather than only the row count. `frozen french fries` still
 * routes to `French fries`, which is the row that owns the phrase.
 */""")

rep("  ['tater tots', 'French fries'],\n  ['açaí', 'Acai packs'],",
    "  ['tater tots', 'Tater tots'],\n  ['açaí', 'Acai packs'],")
rep("    for (const probe of ['oatmilk', 'seltzer', 'IPA', 'prosecco', 'bourbon', 'tater tots', 'açaí']) {",
    "    for (const probe of ['oatmilk', 'seltzer', 'IPA', 'prosecco', 'bourbon', 'açaí']) {")

rep("""  it('inserts exactly the 80 new thin-category rows', () => {""",
    """  it('inserts exactly the 87 new thin-category rows', () => {""")
rep("""  const applyThin = parseRows(APPLY).filter((r) => r.category !== 'spices');""",
    """  const applyThin = parseRows(section(APPLY, '-- (d) new rows', '-- (e) alias growth'));""")
rep("""  it('writes 43 thin-category panels and leaves 37 rows null by design', () => {""",
    """  it('writes 49 thin-category panels and leaves 38 rows null by design', () => {""")

rep("""    const section = APPLY.slice(APPLY.indexOf('-- (f) USDA panels'));
    const targets = [...section.matchAll(/ where lower\\(name\\) = lower\\('((?:[^']|'')*)'\\)/g)].map(
      (m) => m[1].replace(/''/g, "'"),
    );
    expect(targets).toHaveLength(43);
    expect(new Set(targets).size).toBe(43);
    for (const name of targets) expect(thinByName.has(name)).toBe(true);
    expect(THIN_ROWS.length - targets.length).toBe(37);""",
    """    const body = section(APPLY, '-- (f) USDA panels', '-- (g) new rows');
    const targets = [...body.matchAll(/ where lower\\(name\\) = lower\\('((?:[^']|'')*)'\\)/g)].map(
      (m) => m[1].replace(/''/g, "'"),
    );
    expect(targets).toHaveLength(49);
    expect(new Set(targets).size).toBe(49);
    for (const name of targets) expect(thinByName.has(name)).toBe(true);
    expect(THIN_ROWS.length - targets.length).toBe(38);""")

rep("""    const section = APPLY.slice(APPLY.indexOf('-- (f) USDA panels'));
    const comments = [...section.matchAll(/^-- (.+?) -> (.+?) \\[fdc_id (\\d+)\\]/gm)];
    expect(comments).toHaveLength(43);""",
    """    const body = section(APPLY, '-- (f) USDA panels', '-- (g) new rows');
    const comments = [...body.matchAll(/^-- (.+?) -> (.+?) \\[fdc_id (\\d+)\\]/gm)];
    expect(comments).toHaveLength(49);""")

rep("""    expect(generatedTargets.length).toBeGreaterThanOrEqual(11);""",
    """    expect(generatedTargets.length).toBeGreaterThanOrEqual(16);""")
rep(""" *  Eleven of these target GENERATED rows and exist nowhere else. */""",
    """ *  Sixteen of these target GENERATED rows and exist nowhere else. */""")

open(p, 'w').write(s)
print('test file patched (%d replacements)' % n)
