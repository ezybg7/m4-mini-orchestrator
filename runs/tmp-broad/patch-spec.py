import sys
P = '/Users/orchestrator/agents/worktrees/broad/specs/catalog-seed.md'
s = open(P).read()
n = 0


def rep(a, b):
    global s, n
    if a not in s:
        print('MISS: %r' % a[:160])
        sys.exit(1)
    s = s.replace(a, b, 1)
    n += 1


# ---- thin-category amendment: built line -----------------------------------
rep("""**Built 2026-09-06** on `feat/catalog-spices-2026-09-06`; the production data apply is still ⏳. **80 new rows** (the floor was 70), whole catalog **538 → 618**: **8** plant milks and creamers (`dairy_eggs`, all `{}`), **21** frozen vegetables and fruit (`produce`), **13** fish and shellfish (`meat_seafood`), **4** canned fish (`canned`), **34** drinks (`beverages`). **43 USDA panels**""",
    """**Built 2026-09-06** on `feat/catalog-spices-2026-09-06`; the production data apply is still ⏳. **87 new rows** (the floor was 70), whole catalog **538 → 625** before the broad extension below took it to 811: **8** plant milks and creamers (`dairy_eggs`, all `{}`), **22** frozen vegetables and fruit (`produce`), **19** fish and shellfish (`meat_seafood`), **4** canned fish (`canned`), **34** drinks (`beverages`). **49 USDA panels**""")

rep("""**Seven §Families items got no new row because an existing row already answers them** — `cod`/`haddock`/`halibut` (aliases of `White fish`), `clams`/`mussels`/`oysters` (aliases of `Live shellfish`), and `tater tots`/`frozen french fries` (`French fries`, FoodKeeper's "Frozen potato products", filed under `other`): a hand row under any of those names makes `scripts/build-catalog-seed.mjs` prune the alias off the FoodKeeper row that carries it, which rewrites seed.sql's generated block. That is the amendment's own "alias only if X already answers" idiom applied to six more rows, it satisfies §Acceptance's "by name or alias", and it is the one call worth overruling — the PR description says exactly what flipping it would cost.""",
    """~~**Seven §Families items got no new row because an existing row already answers them** — `cod`/`haddock`/`halibut` (aliases of `White fish`), `clams`/`mussels`/`oysters` (aliases of `Live shellfish`), and `tater tots` (`French fries`, FoodKeeper's "Frozen potato products", filed under `other`)~~ — **reversed the same day** by §"Decision on the seven pruned items" below: all seven are rows of their own (`Cod`, `Haddock`, `Halibut` lean fish 2/180; `Clams`, `Mussels`, `Oysters` live shellfish 2/75; `Tater tots` frozen potatoes 365), which is why this amendment ships 87 rows and not 80. Six of them carry a panel; `Oysters` is null because eastern-wild, Pacific and eastern-farmed disagree 51/59/81 with no plainest entry. The cost is the sixteen aliases `scripts/build-catalog-seed.mjs` prunes off the FoodKeeper bucket rows because they now equal a hand row's name — listed one by one in the PR description and pinned in `tests/catalog-seed-extension.test.ts` as `PRUNED_ALIASES`. `frozen french fries` still resolves to `French fries`, the row that owns the phrase.""")

rep("""- [x] ≥ 70 new rows across the four families; every §Families item present by name or alias; mapping per §Category mapping — **80 rows**;""",
    """- [x] ≥ 70 new rows across the four families; every §Families item present by name or alias; mapping per §Category mapping — **87 rows**;""")
rep("""- [x] FDC panels only where one clear entry exists, each traceable to its description; the rest null — **43 panels / 37 null**,""",
    """- [x] FDC panels only where one clear entry exists, each traceable to its description; the rest null — **49 panels / 38 null**,""")
rep("""every one carrying its `<row> -> <FDC description> [fdc_id]` comment (asserted, all 43)""",
    """every one carrying its `<row> -> <FDC description> [fdc_id]` comment (asserted, all 49)""")

# ---- broad extension: built line -------------------------------------------
rep("""_Status: 📋 specced 2026-09-06 · Everett: "go, add the third pass too, after completion merge and do production readiness checks." Ships in the same PR and the same data apply as the two amendments above._""",
    """_Status: 📋 specced 2026-09-06 · Everett: "go, add the third pass too, after completion merge and do production readiness checks." Ships in the same PR and the same data apply as the two amendments above._

**Built 2026-09-06** on `feat/catalog-spices-2026-09-06`; the production data apply is still ⏳. **186 new rows** (the floor was 150), whole catalog **625 → 811** (481 hand + 330 generated). By family: **17** bakery · **20** international · **5** breakfast · **14** grains and pasta · **16** snacks · **23** condiments and sauces · **19** canned · **13** baking · **14** dairy and cheese · **13** meat · **7** deli and prepared · **25** produce. By category: 37 `grains_pasta`, 26 `produce`, 24 `condiments_oils`, 19 `canned`, 18 `dairy_eggs`, 17 `baking`, 16 `meat_seafood`, 16 `snacks`, 13 `other` — no `food_category` value added, so no client code moves. **126 USDA panels**, every value copied verbatim out of the FDC mirror by script and every one carrying its `<row> -> <FDC description> [fdc_id]` comment; **60 rows null by design**, in the three populations `docs/adr/catalog.md` O1 now names. **93 rows the families name already existed and only gain aliases** — every "alias only if the row exists" conditional was checked against the actual seed with the real `matchCatalog`, not assumed: `Muffins`, `Breadcrumbs` (which needed the two-word `bread crumbs` alias to resolve at all), `Tempeh`, `Coconut flour`, `Curry leaves`, `Plantains`, `Toaster pastries`, `Granola bars`, `Breakfast cereal`, `Quinoa`, `Popcorn kernels`, `Applesauce`, `Coconut cream (canned)`, `Wasabi powder`, `Swiss chard`, `Cantaloupe`, `Hot dogs`, `Pork chops`, `Salami`, `Pepperoni`, `Rotisserie chicken`, `Guacamole`, `Chicken salad` and the rest. Eight existing rows gain aliases: three hand rows in the seed (`Pasta` → `elbow pasta`, `Breadcrumbs` → `bread crumbs`, `Active dry yeast` → `instant yeast`) and five generated rows whose aliases can only live in the data apply (`Green onions` → `scallions`, `Barbecue sauce` → `bbq sauce`, `Walnuts` → `chopped walnuts`, `Pumpkin seeds` → `pepitas`, `Veggie burgers` → `plant-based burger`). Two naming calls follow the `Arbol chiles` / `Acai packs` precedent: **`Jalapenos`** drops the accent in the canonical name (`normalizeTokens` strips every non-ASCII character) and carries `jalapeño` and `jalapeños` as the aliases that make the accented query land; `Yuca` is spelled the way US stores label it, with `cassava` as an alias. Q9 is enforced by a test rather than by care: no new name or alias contains a brand string.""")

# ---- broad extension acceptance --------------------------------------------
rep("""- [ ] ≥ 150 new rows; every §Families item present by name or alias; mapping per §Category mapping
- [ ] Every shelf life matches the table; sugars ship `{}`
- [ ] FDC panels only where one clear entry exists, each traceable; the rest null
- [ ] Existing rows keep id, name and category; aliases only grow
- [ ] Same data apply, same registry entry, same rehearse → apply → merge order""",
    """- [x] ≥ 150 new rows; every §Families item present by name or alias; mapping per §Category mapping — **186 rows**; the §Families items are pinned one per case in `tests/catalog-seed-extension.test.ts` (294 of them, five more against the post-apply catalog), each resolved through the real `matchCatalog` rather than by string compare, and the category of every new row is asserted against a written-out literal
- [x] Every shelf life matches the table; sugars ship `{}` — the table is transcribed into the test as `BROAD_SHELF` and every row must deep-equal one of its entries. **The sugar clause binds nothing new**: §Families names Brown sugar and Powdered sugar and both already existed, and an existing row is never re-valued — so the test asserts instead that no new row is a sugar, that `Sugar` and `Powdered sugar` still ship `{}`, and that `Granulated sugar` (730) and `Brown sugar` (365) keep the values they had. Three more entries of the table go unused for the same reason (coconut cream, the refrigerated pudding cup, the 540-day baking staples), and the test says which and why
- [x] FDC panels only where one clear entry exists, each traceable; the rest null — **126 panels / 60 null**. The twelve families forced three clauses of the matching rule into the open and all three are written at the top of the apply file: the state that counts is the state a shopper BUYS; an FNDDS survey entry is an as-consumed value, so it answers for bread, cheese and bottled sauce and never for gnocchi, pierogi or falafel, and only when it is the only candidate; and where two entries carry the same description the Foundation one supersedes the legacy one
- [x] Existing rows keep id, name and category; aliases only grow — the 93 rows these families name are written out in the test with their category, and the three hand rows that gain an alias have their prior alias sets pinned as literals
- [ ] Same data apply, same registry entry, same rehearse → apply → merge order — **the apply is still ⏳**: `db/apply/catalog-extension-2026-09.sql` now carries all three amendments (390 inserts, 38 alias updates, 223 panels, one transaction, four trailing count checks) and is registered, not rehearsed and not applied""")

# ---- broad extension open questions ----------------------------------------
rep("""### Open questions (defaults picked; overrule in the PR)

- **Q8 — store-prepared foods in `other`.**""",
    """### Open questions (defaults picked; overrule in the PR)

_Defaults applied 2026-09-06, all three as written: **Q8** the five new deli rows (Sushi, Potato salad, Coleslaw, Macaroni salad, Egg salad) are `other`, `Hummus` and `Prepared meals` stay in `leftovers` and are listed by `supabase/snippets/catalog-review.sql` query 8 for a later re-file; **Q9** no brand name appears in any new name or alias, and a test enforces it (`tabasco`, `jello`, `cool whip`, `spam`, `oreo` and ten more are checked against every new row) — `Gelatin cups` and `Pudding cups` are the rows that would otherwise have carried one; **Q10** the frozen-sold rows (Dumplings, Gyoza, Falafel, Pierogi, Spring rolls, Bao, Frozen breakfast sandwiches, and `Seitan` beside `Tempeh`) are filed `other` and are spec 59's to re-file to `frozen`._

- **Q8 — store-prepared foods in `other`.**""")

open(P, 'w').write(s)
print('spec patched (%d spots)' % n)
