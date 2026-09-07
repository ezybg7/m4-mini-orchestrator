## Thin-category extension (amendment, 2026-09-06)

_Status: 📋 specced 2026-09-06 · Everett, after the spice decision: "also add the other thin categories, plant milks, frozen veg, drinks, fish." Ships in the same PR and the same data apply as the spice extension above._

### Goal

Close the five misses of the 2026-09-06 common-basket probe (frozen peas, oat milk, sparkling water, beer, tilapia) at the family level rather than one row at a time: every plant milk, frozen vegetable and fruit, drink, and fish or shellfish a US shopper is likely to type gets a row, with aliases, a defensible shelf life, and a FoodData Central panel where one exists. Floor: **70 new rows** across the four families, and every item named in §Families present by name or alias.

### Category mapping (no schema change)

`food_category` is a Postgres enum (0001) and this PR does not add a value. The seed's existing precedent decides the family → category mapping: plant milks → `dairy_eggs` (as Almond milk, Soy milk, Rice milk, Coconut milk (refrigerated) are today); frozen vegetables and fruit → `produce` (as Frozen vegetables, Frozen fruit, Edamame (frozen)); drinks → `beverages`; fish and seafood → `meat_seafood`; canned fish → `canned` (as Canned tuna). Storage is the location's job, not the category's.

### Families

- **Plant milks** (`dairy_eggs`): Oat milk, Cashew milk, Pea milk, Hemp milk, Macadamia milk, Flax milk, Oat creamer, Plant-based creamer; aliases carry the brand-free forms shoppers type ("barista oat milk", "oatmilk", "almond creamer"). Almond, Soy, Rice and refrigerated Coconut milk already exist and only gain aliases.
- **Frozen vegetables and fruit** (`produce`): Frozen peas, Frozen corn, Frozen spinach, Frozen broccoli, Frozen green beans, Frozen mixed vegetables, Frozen cauliflower, Frozen cauliflower rice, Frozen stir-fry vegetables, Frozen Brussels sprouts, Frozen butternut squash, Frozen edamame (alias only — the row exists), Frozen hash browns, Tater tots, Frozen french fries, Frozen berries, Frozen strawberries, Frozen blueberries, Frozen mango, Frozen mixed fruit, Frozen pineapple, Frozen cherries, Açaí packs, Frozen avocado. Naming: `Frozen <thing>` (the "Frozen shrimp" / "Frozen vegetables" pattern), alias `<thing> frozen` and the bare `<thing>` where the fresh row does not already own it.
- **Drinks** (`beverages`): Sparkling water (aliases seltzer, carbonated water, mineral water), Club soda, Tonic water, Cola, Diet soda, Lemon-lime soda, Ginger ale, Root beer, Ginger beer, Lemonade, Iced tea, Sweet tea, Kombucha, Sports drink (alias electrolyte drink), Energy drink, Cold brew coffee, Hot chocolate mix, Apple juice, Cranberry juice, Grape juice, Tomato juice, Vegetable juice, Protein shake, Beer (aliases lager, IPA, ale, pilsner), Non-alcoholic beer, Hard seltzer, Hard cider, Sparkling wine (aliases prosecco, champagne, cava), Rosé wine, Vodka, Whiskey (aliases bourbon, scotch, rye), Rum, Gin, Tequila. Red wine, White wine, Orange juice, Coconut water, Coffee and Tea rows already exist and only gain aliases. No brand names anywhere (a brand arrives by barcode, per spec 13's out-of-scope line).
- **Fish and seafood** (`meat_seafood`, canned rows in `canned`): Tilapia, Cod, Haddock, Halibut, Mahi-mahi, Sea bass, Trout, Catfish, Snapper, Swordfish, Mackerel, Sardines (fresh), Anchovies (canned), Canned sardines, Canned salmon, Canned mackerel, Smoked salmon (alias lox — if a "Lox" row exists, alias only), Fish sticks (alias only if "Breaded fish (frozen)" already answers; otherwise its own row), Imitation crab (alias surimi), Scallops, Clams, Mussels, Oysters, Squid (alias calamari), Octopus, Lobster, Crawfish, Sea scallops (alias only), Fish fillets (frozen — alias only if "Fish (frozen)" answers). Fresh fish rows are named by species, singular, aliases `<species> fillet` / `fillets`; shellfish plural where shoppers say so. Salmon, Shrimp, Frozen shrimp, Crab meat, Crab legs, Lobster tails, Canned tuna, Live shellfish, Cooked fish exist and only gain aliases.

### Shelf lives (unopened, from purchase; consistent with the existing rows they sit beside)

| Family | Value | Precedent |
|---|---|---|
| Plant milks, creamers | `{}` — no estimate; the package date rules | spec 13's non-numeric FoodKeeper rule; Almond milk, Soy milk ship `{}` today |
| Frozen vegetables | `{"freezer": 420, "fridge": 4}` | Frozen vegetables |
| Frozen potatoes (hash browns, tots, fries) | `{"freezer": 365}` | FoodKeeper frozen potato products |
| Frozen fruit, açaí | `{"freezer": 420}` | Frozen fruit |
| Carbonated and shelf-stable drinks (waters, sodas, sports and energy drinks, juices in cartons, shakes) | `{"pantry": 270}` | Coconut water 360 / Fruit juice 21 bracket it; nine months is the industry unopened floor |
| Refrigerated drinks (kombucha, cold brew, lemonade, iced tea, sweet tea) | `{"fridge": 14}` | Orange juice fridge 7; these are pasteurised and last longer |
| Beer, non-alcoholic beer, hard seltzer, hard cider | `{"pantry": 180}` | none in the seed; six months is the brewers' guidance |
| Sparkling wine, rosé | `{"pantry": 1460}` | Red wine, White wine |
| Spirits | `{"pantry": 1825}` | the salt cap: effectively indefinite |
| Lean fish (tilapia, cod, haddock, halibut, mahi-mahi, sea bass, catfish, snapper, swordfish) | `{"fridge": 2, "freezer": 180}` | Ocean fish |
| Fatty fish (trout, mackerel, fresh sardines) | `{"fridge": 2, "freezer": 90}` | FoodKeeper fatty fish 2–3 months |
| Shellfish (scallops, squid, octopus, crawfish, lobster) | `{"fridge": 2, "freezer": 135}` | Frozen shrimp / FoodKeeper shellfish 3–6 months |
| Live shellfish (clams, mussels, oysters) | `{"fridge": 2, "freezer": 75}` | Live shellfish |
| Smoked salmon, imitation crab | `{"fridge": 14, "freezer": 60}` | Cold-smoked fish 22 (vacuum), surimi FoodKeeper |
| Canned fish | `{"pantry": 1095}` | Canned tuna |

### Nutrition

Same rule as the spices: a row whose plain form has one clear FoodData Central entry in the mirror gets that panel (`nutrition_source = 'usda'`, spec 45's panel rules). Take the raw / unprepared / unsweetened / regular variant ("Fish, tilapia, raw"; "Peas, green, frozen, unprepared"; "Beverages, almond milk, unsweetened"; "Alcoholic beverage, beer, regular, all"). Where the mirror holds several plausible entries whose panels differ materially (mixed vegetables, mixed berries, hard seltzer, protein shake, creamers, plant milks other than oat/almond/soy/rice/coconut), stay **null** — the tie-abstention principle of spec 45, not a guess. Record per row in the apply file's comment which FDC description a panel came from.

### Aliases and probes

Aliases ≤ 6, lowercase, no brand names, and every FDC-backed row carries its entry's distinguishing tokens. The type-ahead probe list in `tests/catalog-seed-extension.test.ts` gains: oat milk, oatmilk, frozen peas, sparkling water, seltzer, beer, IPA, tilapia, lox, calamari, fish sticks, prosecco, bourbon, tater tots, açaí.

### Acceptance (in addition to the spice amendment's)

- [ ] ≥ 70 new rows across the four families; every §Families item present by name or alias; mapping per §Category mapping
- [ ] Every shelf life matches the table; plant milks ship `{}`
- [ ] FDC panels only where one clear entry exists, each traceable to its description; the rest null
- [ ] Existing rows in these families keep id, name and category; aliases only grow
- [ ] Same data apply, same registry entry, same rehearse → apply → merge order as the spices

### Open questions (defaults picked; overrule in the PR)

- **Q5 — drink shelf lives.** FoodKeeper says "package use-by" for most drinks, which spec 13 turned into `{}` for Soda. This amendment gives new drinks numbers (the table) because an unopened can or bottle does have a defensible floor; the existing Soda row is left as is. Everett can send them all to `{}` for consistency.
- **Q6 — alcohol in the catalog.** Included: it sits in every kitchen and the recipe matcher names it (wine, beer, spirits). Remove the family if the store-listing age rating would rather not mention it.
- **Q7 — frozen potatoes under `produce`.** Defaulted there for want of a frozen category; a future `frozen` enum value is a migration and a separate decision.

### Out of scope

Fresh herbs and produce beyond the frozen rows · dairy beyond creamers · pastes and condiments (see the spice amendment) · brand names · a `frozen` category · nutrition for mixed frozen bags and creamers (null by rule).
