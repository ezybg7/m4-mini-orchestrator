# PR #199 — ADVOCATE review (the shopper's seat)

Reviewer: advocate agent · 2026-09-06 · branch `feat/catalog-spices-2026-09-06` @ `b5fb23e9`
Worktree: `~/agents/worktrees/review199a` (read-only; removed after)

**What I actually checked, mechanically.** Parsed both seed blocks before and after
(421 → 811 rows; 390 new, 30 seed alias edits, 38 alias edits in the apply, 0 rows
removed, 0 category or shelf-life changes to existing rows). Compiled the real
`supabase/functions/_shared/match.ts` and ran ~600 shopper queries through
`matchCatalog` against both the seed-only catalog and the post-apply catalog
(seed + the apply file's alias updates, parsed back out of the SQL). Extracted all
223 nutrition statements from `db/apply/catalog-extension-2026-09.sql` and
spot-checked ~30 of the 168 nulls against `~/agents/usda/usda-foods-seed.sql`.
Ran the suite: `tests/catalog-seed-extension.test.ts` — **640 passed**.

Verdict in one line: **this is a big, careful, well-tested win for the type-ahead —
merge it, but fix FIND-101 and FIND-102 first, because both are claims the PR
makes that are not true, and both are hard to walk back once the data apply lands.**

---

## FIND queue

### FIND-101 · HIGH · confidence HIGH — Brand names in the spice aliases, and the test that would catch them only covers 186 of the 390 rows

`supabase/seed.sql` L375, L433, L446, L453, L471, L472 (and the mirrored inserts in
`db/apply/catalog-extension-2026-09.sql` section (a)):

| row | alias | brand |
|---|---|---|
| `Adobo seasoning` | `goya adobo` | Goya |
| `Sazon seasoning` | `sazon goya` | Goya |
| `Kosher salt` | `diamond crystal`, `mortons kosher salt` | Diamond Crystal, Morton |
| `Seasoned salt` | `lawrys seasoned salt` | Lawry's |
| `Flaky sea salt` | `maldon` | Maldon |
| `MSG` | `accent seasoning`, `aji no moto` | Ac'cent, Ajinomoto |

**What the user sees:** nothing bad — these are genuinely the words a US cook types,
and they route correctly. The problem is the other direction. Spec 13 §Out of scope
bans brand names; Q9 restates it and the PR description states flatly *"No brand
names anywhere, per spec 13's out-of-scope line"*. That is false. The Q9 test
(`tests/catalog-seed-extension.test.ts:1519`) iterates `BROAD_ROWS` only — the 186
broad-extension rows — so the 117 spice rows and the 87 thin rows are unchecked, and
the spice half is where the brands are. (`Old Bay seasoning` and `Tajin` are brands
too, but §Sources ¶2 names both explicitly, so those are Everett's call already made.)

**Why now and not later:** the apply file only ever *adds* aliases. Once it lands,
removing these six needs a second data apply. `Chocolate hazelnut spread` still
carrying `Nutella` (pre-existing, generated) is the same rule leaking, and shows the
cost of not enforcing it globally.

**Fix intent:** widen the Q9 brand sweep to all 390 new rows (one-line change: iterate
`[...SPICE_ROWS, ...THIN_ROWS, ...BROAD_ROWS]`), then either (a) drop the six brand
aliases, or (b) get an explicit "brand aliases are allowed where shoppers type them"
decision from Everett and amend spec 13 §Out of scope + Q9 in the same PR. Do not
ship the current state, where the rule, the test and the data disagree three ways.

---

### FIND-102 · HIGH · confidence HIGH — Fourteen nutrition rows are null on reasoning that the FDC mirror contradicts

The apply file's own stated rule is *"an FNDDS survey entry is an as-consumed value…
it answers for bread, cheese and bottled sauce… and it counts only when it is the
only candidate."* That rule was applied to `Sushi` (Sushi, NFS), `Tzatziki`,
`Steak sauce`, `Cocktail sauce`, `Prosciutto`, `Paneer`, `Kefir`, `Brioche`,
`Rice paper`, `Whipped topping`, `Colby jack`, `Yogurt drinks`, `Hard cider` — and
then *not* applied to foods of exactly the same shape. Grepped from
`~/agents/usda/usda-foods-seed.sql`:

| row (null today) | the entry that exists | value |
|---|---|---|
| `Tequila` | 2710705 `Tequila` [survey] | **231 kcal — identical to the 80-proof entry the other four spirits took** |
| `Kombucha` | 2710509 `Tea, kombucha` | 16 kcal, 11 mg caffeine |
| `Sparkling wine` | 2710687 `Wine, sparkling` | 75 kcal |
| `Hard seltzer` | 2710622 `Hard seltzer` | 24 kcal |
| `Dragon fruit` | 2709234 `Dragon fruit` | 68 kcal |
| `Goat cheese` | 2705716 `Cheese, goat` | 364 kcal — the plain entry, no texture qualifier; the rule names *cheese* outright |
| `Sports drink` | 2710771 `Sports drink, NFS` | 26 kcal — unbranded |
| `Catfish` | 2684445 `Fish, catfish, farm raised, raw` [**foundation**] | 129 kcal — same shape as `Tilapia`, which took the Foundation farm-raised entry *because US tilapia is farmed* |
| `Trout` | 173717 `Fish, trout, rainbow, farmed, raw` | 141 kcal — same argument |
| `Frozen mixed vegetables` | 170471 `Vegetables, mixed, frozen, **unprepared**` | 72 kcal — the exact state used for Frozen peas/corn/broccoli |
| `Frozen mango` / `Frozen cherries` / `Frozen pineapple` | 2709244 / 2709233 / 2709264 | 60 / 71 / — kcal, one candidate each |
| `Sprinkles` / `Fruit snacks` | 2710334 / 2710367 | 473 / 371 kcal, one candidate each |

**What the user sees:** a blank "No nutrition info available for this food" card on
fourteen rows that could have one, and a recipe estimate that says *"4 of 9
ingredients"* where it could say 5. Not dangerous — but it is exactly the coverage the
PR is selling.

**What is worse than the blanks:** the PR description and (via `docs/adr/catalog.md`
O1) the durable record say these are *"foods FDC does not describe"* and that sports
drinks *"exist only as brands"*. Four of the six foods named in that sentence have
entries; the sports-drink NFS entry is unbranded. Whoever reads ADR O1 in six months
will take that as settled.

**Fix intent:** run the null list back through the mirror with the file's own stated
rule and take the ones that pass (I count 14; `Lobster`, `Stew meat`, `Falafel`,
`Pierogi`, `Bao`, `Gnocchi` correctly stay null because FNDDS is as-*consumed* and
those are cooked). Then correct the prose in the PR, the spec and ADR O1 —
"FDC does not describe it" must not be the reason recorded for a food FDC describes.

---

### FIND-103 · MEDIUM · confidence HIGH — `dill` lands on `Dill seeds`

`supabase/seed.sql` L411 (`Dill seeds`, pantry 1460) and L415 (`Dried dill`, pantry 730).
There is no fresh `Dill` produce row. Both new rows score 0.667 on the bare query and
the tie breaks **alphabetically**, so `Dill seeds` wins.

```
dill  ->  Dill seeds   | cands: Dill seeds(0.67), Dried dill(0.67)
```

**What the user sees:** they type "dill" — the single most common way anyone refers to
this herb — and get whole dill seed with a four-year pantry life. Every sibling herb
behaves correctly (`sage` → Dried sage, `tarragon` → Dried tarragon, `chives` →
Chives) because none of them has a competing seed row. This one is *new*: before this
PR "dill" matched nothing.

**Fix intent:** add `dill` to `Dried dill`'s aliases (it wins on dice once the alias is
an exact one-token match). One-word change, and it makes `dill weed` / `dried dill`
keep working.

---

### FIND-104 · MEDIUM · confidence HIGH — `butternut squash` lands on the frozen row

`supabase/seed.sql` L88 `Frozen butternut squash` `{"fridge":4,"freezer":420}`.

```
butternut squash  ->  Frozen butternut squash(0.80)   [Winter squash sits at 0.50]
butternut         ->  Frozen butternut squash(0.67)
```

**What the user sees:** a whole fresh butternut squash goes in the Pantry, matches the
frozen row, and the row has no `pantry` key — so the item gets **no expiry at all**.
The correct row (`Winter squash`, generated, produce) is never reachable by the name
US shoppers use. Same class as `hash browns` → `Frozen hash browns` and `stir fry` →
`Frozen stir-fry vegetables`, but those two are right; this one is not.

**Fix intent:** add `butternut squash` (and `butternut`) as an alias on the existing
`Winter squash` row — an apply-only alias, since it is a generated row. Costs nothing;
the frozen row still wins on "frozen butternut squash".

---

### FIND-105 · MEDIUM · confidence HIGH — The amendment-3 manual test row does not test what it says it tests

`docs/ACCEPTANCE_TESTS.md:1751`:

> …and **"green onions"** proves the one the apply file adds to a *generated* row
> (`scallions` → Green onions) — that last pair is the check that fails if the apply
> ran without section (h)

Measured, seed-only vs post-apply:

```
seed only :  green onions -> Green onions      scallions -> NO MATCH
applied   :  green onions -> Green onions      scallions -> Green onions
```

`green onions` is the row's **canonical name**. It resolves identically with the apply
and without it. The stated check cannot fail. The probe that actually proves section
(h) is `scallions`, and it is the one the row does not use.

**What the user sees:** nothing — which is the problem. This is the only manual gate
on the apply-only aliases, and it passes on an unapplied database.

**Fix intent:** change the fourth probe to **scallions** and keep the expectation
`Green onions`. (`pepitas` → `Pumpkin seeds` and `bbq sauce` → `Barbecue sauce` are
the other apply-only routes worth a second probe.)

---

### FIND-106 · MEDIUM · confidence HIGH — `peppercorns` lands on ground `Black pepper`, and the manual test enshrines it

`supabase/seed.sql` L360 `Black pepper` keeps `peppercorns` in its alias list
(pantry **1095**); the new L391 `Black peppercorns` is pantry **1460**.
`docs/ACCEPTANCE_TESTS.md:1714` asserts the expected answer *is* `Black pepper`.

```
peppercorns  ->  Black pepper(1.00)   | Black peppercorns(0.67), Green peppercorns(0.67)
```

**What the user sees:** they are holding a grinder jar of whole peppercorns, they type
the word on the label, and they get the ground-pepper row with the ground shelf life.
The spice amendment's whole premise (Q2: whole forms are distinct products shoppers
buy) is contradicted at the one place a shopper types the whole form's actual name.
The grow-only rule means the alias could not be removed — but nothing stopped a
tighter alias landing on the new row.

**Fix intent:** either add `peppercorns` to `Black peppercorns` (name-over-alias will
not save it — both would be alias/name hits at 1.00 and `Black pepper` wins on
`viaName`; so the real fix is to accept it and change the manual row's expectation),
or acknowledge in the spec that the ground row owns the bare plural. Right now the
acceptance doc quietly documents the confusable as correct.

---

### FIND-107 · MEDIUM-LOW · confidence HIGH — `crab` still lands on a FoodKeeper bucket the pruned-seven decision was supposed to kill

`supabase/seed.sql` L757 `Live shellfish` keeps `crab` as an alias.

```
crab  ->  Live shellfish(1.00)   | Crab legs(0.67), Crab meat(0.67)
```

**What the user sees:** the decision gave `Clams`, `Mussels` and `Oysters` real rows
precisely so "a shopper who types 'cod' should land on Cod with its own panel and shelf
life, not on a bucket". Four words from the same bucket got that treatment; `crab` —
the one an American shopper is most likely to type — did not, and still lands on a row
called **"Live shellfish"** with a 2-day fridge life. `Crab meat` (fridge 330) and
`Crab legs` (fridge 3) both exist and are both better answers.

**Fix intent:** either a `Crab` row (costs one more pruned alias, exactly the mechanism
the decision blessed) or an apply-only alias moving `crab` onto `Crab meat`. Listing it
in `catalog-review.sql` query 7 is not enough — the other six got fixed.

---

### FIND-108 · MEDIUM-LOW · confidence HIGH — Two identical deli salads, two different pantry sections

New rows filed `other`: `Potato salad` L622, `Egg salad` L616, `Coleslaw` L614,
`Macaroni salad` L620, `Sushi` L625.
Existing rows left in `leftovers`: `Chicken salad` L951, `Guacamole` L956, `Hummus` L958.

**What the user sees:** on the Fridge screen, the tub of potato salad appears under
**Other 🛒** and the tub of chicken salad from the same deli counter appears under
**Leftovers 🍱** — the section spec 3 reserves for the household's own leftovers.
Before this PR every store-prepared salad was consistently (if wrongly) in Leftovers.
Q8 chose `other` for the new ones and deferred the existing three; the net effect is
that the inconsistency became *visible* rather than staying uniform.

**Fix intent:** not blocking, but say so in the PR body under the Q8 line: the deferral
now costs a split section, not just a wrong one, and `catalog-review.sql` query 8 is
the list a follow-up re-file works from. Worth asking Everett whether the three-row
re-file migration is cheaper now than living with the split.

---

### FIND-109 · LOW · confidence HIGH — Three more section splits of the same shape

- **Frozen potatoes**: `Tater tots` L103 and `Frozen hash browns` L94 → `produce`;
  `French fries` L967 → `other`. Three bags in one freezer drawer, two sections.
- **Jerky**: `Beef jerky` L545 → `snacks`; `Jerky` L839 → `canned` (deviation 3 owns this).
- **Bakery**: `Croissants` L257, `Donuts` L260, `Brownies` L254 → `grains_pasta`
  ("Grains & Pasta 🌾"); `Muffins` L918 and `Toaster pastries` → `snacks`.

**What the user sees:** a donut filed under Grains & Pasta next to the muffin filed
under Snacks. Each individual call follows §Category mapping and the never-re-categorise
rule, so nothing here is a defect — but the aggregate is the thing a shopper notices
first, and no manual test row looks at a section. Worth one line in the PR body so
Everett sees the aggregate rather than three separate defensible decisions.

---

### FIND-110 · LOW-MEDIUM · confidence HIGH — Phrases people actually type that miss, where the row exists

The matcher scores each alias **separately** and gates on coverage, so an alias only
works when it covers the *whole* phrase. These all fail today:

| typed | lands on | should be |
|---|---|---|
| `seltzer water` | NO MATCH | Sparkling water (has `seltzer`, not `seltzer water`) |
| `light beer` | NO MATCH | Beer |
| `panko breadcrumbs` | NO MATCH | Breadcrumbs (has both `panko` and `bread crumbs`, neither covers the phrase) |
| `elbow macaroni` | NO MATCH | Pasta — the PR added `elbow pasta` for exactly this and missed the noun people use |
| `miso paste` | NO MATCH | Miso (row has **zero** aliases and sits in `other`) |
| `wasabi paste` | NO MATCH | — no row; `wasabi` scrapes into `Wasabi powder` at 0.67 |
| `baby spinach` | NO MATCH | Spinach |
| `green peas` | NO MATCH | Frozen peas |
| `mandarin oranges` | NO MATCH | Clementines (has `mandarins`) |
| `skim milk` | NO MATCH | Milk (has `whole milk`, `2% milk`) |
| `italian sausage` | NO MATCH | Sausage |
| `half & half` | **Chicken breasts** | Half and half — `&` is stripped, `half` is an alias on Chicken breasts |
| `pasta salad` | Macaroni salad | debatable, but a homemade pasta salad gets a 4-day deli shelf life |

**Fix intent:** a dozen alias additions, most of them on rows this PR already edits.
`half & half` is the one worth a separate look — it is a pre-existing landmine in the
`Chicken breasts` alias set, in the middle of the dairy family this pass claims to close.

---

### FIND-111 · LOW · confidence MEDIUM — Shelf lives a cook would argue with

40 rows checked against FoodKeeper and my own knowledge; **34 are right or defensibly
conservative**. The six worth a second look:

| row | value | why |
|---|---|---|
| `Feta` L168 | `{"fridge":14}` | Unopened brined feta runs 2–3 months. Ricotta's 14 is the wrong precedent — feta is a brined cheese, not a fresh whey cheese. Nags at two weeks on a sealed tub. |
| `Cotija` L167 | `{"fridge":30}` | Cotija is a hard aged grating cheese — the cheddar 42/180 bucket, not the blue-cheese 30. |
| `Prosciutto` L232 | `{"fridge":21}`, no freezer | A sealed pack is months; and every other cured meat in the pass carries a freezer value. |
| `Stew meat` L233 | `{"fridge":2,…}` | FoodKeeper gives stew meat 3–5 days (it is cut, not ground). Took the Ground beef precedent and lost a day. |
| `Hot chocolate mix` L586 | `{"pantry":270}` | The PR flags this itself. A tin of cocoa mix is 1–2 years; 9 months nags. |
| `Vanilla bean` L483 | `{"pantry":1460}` | Beans dry to sticks well inside four years. The one whole-spice value that hides a real spoilage rather than being merely conservative. |

Correct and worth saying so: fresh fish fridge **2** and lean/fatty freezer **180/90**
match FoodKeeper exactly; beer **180** matches brewers' guidance; rice vinegar **730**
is conservative-harmless; canned fish **1095**; chicken parts **2/270**; fresh sausage
**2/60**; `Sushi` **fridge 1**. Plant milks at `{}` is spec'd (Q5 keeps the package
date in charge) — see FIND-112 for the consistency wrinkle.

Also worth knowing (not a defect): eleven frozen-fruit rows carry only `{"freezer":…}`,
so the same item put in a Fridge or Pantry location gets **no** expiry rather than a
wrong one — `computeExpiresAt` returns null on a missing key
(`src/features/inventory/expiry.ts:100`). Safe, just silent.

---

### FIND-112 · LOW · confidence HIGH — One shelf, two behaviours: `Soda` `{}` vs thirteen new sodas at 270

`supabase/seed.sql` L946 `Soda` ships `{}` (Q5 leaves it alone); `Cola` L575,
`Diet soda` L578, `Root beer` L593, `Ginger ale` L581, `Lemon-lime soda` L589 and the
rest ship `{"pantry":270}`.

**What the user sees:** they add "soda" and it never expires; they add "cola" and it
expires in nine months. Same shelf, same physical can. The plant milks have the mirror
version of this (`{}` while every bottled drink beside them carries a number).

**Fix intent:** Q5's default is fine, but either bring `Soda` to 270 in the apply
(it is a value change on an existing row — needs an explicit decision, so PR body) or
say in the spec that the bucket row is deliberately left dateless.

---

### FIND-113 · LOW · confidence HIGH — Dead and misleading aliases

**Dead** (they never route to their own row, so they are doing nothing):
`Clementines` → `tangerines` (goes to `Citrus fruit`), `Mixed greens` → `salad greens`
(goes to `Arugula`), `Candy` → `sweets` (goes to `Baking chocolate`). Every other one
of the 390 rows' aliases routes correctly — I checked all of them.

**Misleading** (they route, to the wrong food):
- `Snap peas` L131 → `snow peas`. Snow peas are a different vegetable; `Green beans`
  already carries `snow`.
- `Dijon mustard` L519 → `whole grain mustard`. Different product, and this is the
  only route for the phrase, so it is a confident wrong answer rather than a miss.
- `Sea bass` L209 → `striped bass`. Different species; the panel taken is sea bass.
- `Rye bread` L280 → `pumpernickel`. Distinct bread.
- `Sparkling water` L596 → `mineral water`. Mineral water is frequently still.
- `Spring rolls` L624 → `egg rolls`. Distinct in US usage (and FDC has separate entries).

---

### FIND-114 · LOW · confidence HIGH — `Frozen peas` claims the bare word `peas`

`supabase/seed.sql` L98. Before the PR, `peas` resolved to `Green beans` (which carries
`peas` as a FoodKeeper residue alias, L668) — so this is an improvement, and frozen is
how most Americans buy peas. But there is no fresh/shelled peas row anywhere, and
`green peas` now matches **nothing at all**. Worth an alias, not a row.

---

### FIND-115 · LOW-MEDIUM · confidence HIGH — What the three manual test blocks do not cover

Answering Q8 of the brief directly: **all five rows are walkable**, and rows 1 and 2 of
amendment 2 are genuinely good — row 2 (Frozen peas into Freezer then Fridge, 420 vs 4
days) is the only check in the whole set that a pure test could not make, and it is
exactly the right one. Amendment 1 row 2 (two spices, no batch, no nag) is likewise
well-chosen and I verified the probes in rows 1 of amendments 1 and 2 all land as
written (`za'atar`, `haldi`, `kosher salt`, `oat milk`, `frozen peas`, `seltzer`,
`tilapia`, `english muffin`, `potstickers`, `chicken wings`).

Gaps against the actual risk this PR carries:
1. **The apply-only alias route is untested** — see FIND-105; the one probe meant to
   cover it does not.
2. **The pruned-alias tie is untested.** The PR names this itself: after the apply,
   `White fish` still carries `cod` while `Cod` exists beside it. A row typing **cod**
   and expecting **Cod** (not White fish) is one line and covers the one thing the
   rehearsal is explicitly told to watch. I verified it resolves correctly today —
   but nothing pins it.
3. **No row looks at a section.** 13 rows land in `other` and 22 frozen rows in
   `produce` by deliberate decision (Q10, Q7). One row — add `Dumplings`, confirm it
   shows under **Other**; add `Frozen peas`, confirm **Produce** — would make Q10's
   deferral visible to whoever runs the device pass, and is the check spec 59's builder
   will want to diff against.

---

### FIND-116 · LOW · confidence HIGH — `Wasabi` (the tube) has no row

§Families (broad, condiments) names **Wasabi**. `Wasabi powder` L484 is the only row,
so `wasabi` scrapes in at 0.67 and `wasabi paste` misses entirely. A tube of wasabi is
a refrigerated condiment; the powder row is `spices`, pantry 913. Two different foods,
two different sections, one row.

---

## Coverage: what a US shopper still types weekly and still misses

Probed ~300 everyday phrases post-apply. The list below is **true gaps** — no candidate
above 0.4 — not phrase-coverage misses (those are FIND-110). Family names are the
amendment's own.

**Bakery (7)** — `pizza dough` / `pizza crust` (the refrigerated tube; a weekly US
staple), `biscuits`, `crescent rolls`, `cinnamon rolls` (the three refrigerated doughs),
`focaccia`, `challah`, `texas toast`

**Grains and pasta (7)** — named pasta shapes beyond the three `Pasta` carries:
`rigatoni`, `rotini`, `fettuccine`, `linguine`, `farfalle`/`bowtie`; plus
`mac and cheese` (boxed) and `stuffing mix`

**Dairy and cheese (6)** — `fresh mozzarella` / `burrata`, `mascarpone`, `havarti`,
`asiago`, `romano`, `manchego`

**Meat and deli (6)** — named beef cuts (`ribeye`, `sirloin`, `filet mignon`,
`new york strip`), `pastrami`, `mortadella` / `capicola`

**Condiments and sauces (5)** — **`capers`** (spec 13 §Sources ¶1 lists FDC's
`Capers` entry as available and no row was made), `agave`, `marmalade`, `aioli`,
`sweet chili sauce`

**Canned (5)** — `bouillon` / `bouillon cubes`, `cream of mushroom soup`, `tomato soup`,
`chicken noodle soup` (the three named soups; `Canned soup` covers only the word "soup"),
`black-eyed peas`, `navy beans`

**Baking (5)** — `cream of tartar`, `self-rising flour`, `frosting` / `icing`,
`semolina`, `stevia` / `monk fruit`

**Snacks (4)** — `chia seeds`, `flax seeds`, `hemp seeds` (all three route to
`Pumpkin seeds` at 0.67 and fail coverage), `dark chocolate`, `hazelnuts`

**Frozen (4)** — `frozen burritos`, `frozen garlic bread`, `popsicles`,
`frozen onion rings`

**Produce (3)** — `habanero` (the pepper family got jalapeño/serrano/poblano and
stopped), `fresh dill` / `fresh sage` / `fresh tarragon` (the fresh herbs whose only
rows are now the dried/seed forms — see FIND-103)

*(Total: 52 phrases across 10 families; the top 40 by weekly frequency are, in order:
pizza dough, biscuits, crescent rolls, mac and cheese, rigatoni, rotini, fettuccine,
linguine, fresh mozzarella, capers, bouillon, cream of mushroom soup, tomato soup,
chicken noodle soup, chia seeds, flax seeds, frosting, cream of tartar, self-rising
flour, ribeye, sirloin, pastrami, italian sausage, dark chocolate, agave, marmalade,
cinnamon rolls, frozen burritos, popsicles, frozen garlic bread, habanero, black-eyed
peas, navy beans, stuffing mix, focaccia, burrata, mascarpone, aioli, sweet chili sauce,
hemp seeds.)*

Brand-shaped queries that miss by design and are worth naming once so Q9 gets revisited
with evidence rather than principle: `coke`, `diet coke`, `sprite`, `dr pepper`,
`gatorade`, `red bull`, `la croix`, `topo chico`, `tabasco`, `cool whip`, `white claw`.
Eleven of the most-typed grocery words in America resolve to nothing.

---

## Checked, fine

- **No regressions.** Zero rows removed, zero categories changed, zero shelf lives
  changed on existing rows. I replayed all **858** name-and-alias phrases from the
  pre-PR catalog through the matcher: **19 winners changed, 17 of them clear
  improvements** (`cod` White fish → Cod, `clams`/`mussels`/`oysters` Live shellfish →
  their own rows, `brisket` Beef roast → Brisket, `kielbasa` Smoked sausage → Kielbasa,
  `lychee` Cherries (sweet) → Lychee, `papaya` Mango → Papaya, `nectarines` Stone fruit
  → Nectarines, `raisins` Dried fruit → Raisins, `tater tots` French fries → Tater tots,
  `diet sodas` Soda → Diet soda). The other two are `peas`/`pea` (FIND-114).
- **Every one of the 390 new rows' canonical names resolves to itself**, and 793 of
  the 796 new aliases resolve to their own row (the three exceptions are FIND-113).
- **No nutrition regression on recipe ingredients.** 119 common recipe lines replayed
  before/after: 21 changed, **13 gained a panel where there was none**, 0 lost one.
  `coriander`, `turmeric`, `cayenne`, `ground ginger`, `bay leaf`, `feta`, `scallions`,
  `jalapeno`, `dried cranberries`, `fish sauce`, `tilapia`, `prosciutto` all newly
  count toward a recipe estimate.
- **The per-100 g panels are used correctly, not decoratively.** `nutrition.ts` parses
  `tsp`/`tbsp`/`cup` (4.93/14.79/236.6 g) and scales, so `Salt`'s 97 g/100 g becomes
  ~2 g of salt for "1 tsp salt" — right. `NutritionFacts` puts "per 100 g" in the
  subtitle, so the item-detail card is honest about its basis. The rows the brief
  flagged as nonsense-risk are fine in practice: extracts, baking powder, blends and
  the salts other than `Salt` are all **null**; the spirits' 231 kcal is real; `Gum` at
  360 kcal is the only genuinely silly one and it is FDC's own number.
- **Alias hygiene**: no row anywhere in the 811-row seed exceeds the 6-alias cap; no
  new alias duplicates its row's name; all lowercase; no within-row duplicates.
- **Accents handled right.** `Arbol chiles` / `Acai packs` / `Rose wine` / `Jalapenos`
  drop the accent in the canonical name because `normalizeTokens` strips non-ASCII, and
  carry the accented spelling as an alias — verified: `jalapeño`, `jalapeno`, `açaí`,
  `rosé`, `pimentón`, `za'atar` all land.
- **The alias-only routes work**: `seltzer`, `haldi`, `pimentón`, `everything seasoning`,
  `chili flakes`, `sambal`, `sriracha`, `bourbon`, `prosecco`, `champagne`, `calamari`,
  `surimi`, `pepitas`, `potstickers`, `togarashi`, `tots`, `booch`, `hoisin`, `dijon`,
  `alfredo`, `marinara`, `chevre`, `gorgonzola`, `branzino`, `satsumas`.
- **The confusable pairs the brief named all break the right way:**
  `cumin`→Cumin, `ground cumin`→Ground cumin, `cumin seeds`→Cumin seeds ·
  `jerky`→Jerky, `beef jerky`→Beef jerky · `lox`/`smoked salmon`→Lox ·
  `frozen vegetables`→Frozen vegetables, `frozen mixed vegetables`→Frozen mixed
  vegetables · `chili powder`→Chili powder, `chili flakes`/`red pepper flakes`→Red
  pepper flakes · `whipped cream`→Whipped cream, `whipped topping`→Whipped topping ·
  `frozen fish`/`fish fillets`→Fish (frozen), `fish sticks`→Breaded fish (frozen) ·
  `sardines`→Canned sardines (right: most people mean the tin). The only pair that
  breaks wrong is `hot chocolate`/`cocoa` — `cocoa` lands on **Chocolate hazelnut
  spread** (pre-existing alias), not `Cocoa powder`, though `cocoa powder` and
  `hot cocoa` are both correct.
- **Suite green**: `tests/catalog-seed-extension.test.ts` — 640 passed, 2.1 s.
- **Naming and plurals follow the seed's convention**: produce plural where shoppers
  say so (Clementines, Shallots, Radishes, Jalapenos), fish and meat singular (Cod,
  Halibut, Brisket, Veal), shellfish plural (Clams, Mussels, Oysters, Scallops). No
  USDA-ese anywhere in the 390 — no `Flavored or herb mixes` was created, and the five
  existing buckets deliberately gained no aliases so they cannot compete. Title case is
  consistent; the only capitalised inner words are proper nouns (`Old Bay seasoning`,
  `Herbes de Provence`, `Frozen Brussels sprouts`, `Chinese five-spice`, `Za'atar`).

---

## Bottom line

Merge-worthy. The type-ahead gets meaningfully better for a US home cook and I could
not find a way to make it worse. Two things should not go into the production data
apply as they stand — the brand aliases the PR says are not there (FIND-101) and the
fourteen nulls justified by a claim the mirror contradicts (FIND-102) — because the
apply file never removes an alias and ADR O1 is where the reasoning goes to become
permanent. FIND-103 (`dill`), FIND-104 (`butternut squash`), FIND-105 (the manual row
that cannot fail) and FIND-106 (`peppercorns`) are each a one-line data or doc fix and
are worth doing in the same PR. Everything below that is a note for the PR body or a
follow-up.
