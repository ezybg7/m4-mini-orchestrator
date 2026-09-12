## Broad extension (amendment, 2026-09-06) — the twelve thin families

_Status: 📋 specced 2026-09-06 · Everett: "go, add the third pass too, after completion merge and do production readiness checks." Ships in the same PR and the same data apply as the two amendments above._

### Goal

The 2026-09-06 broad probe (267 everyday items, twelve families) found about half: bakery 4/17, international 5/21, breakfast 3/8, grains and pasta 8/22, snacks 9/23, condiments and sauces 12/30, canned 8/19, baking 11/20, dairy 13/22, meat 12/20, deli 7/11, produce 36/50. This pass closes those families the way the first two closed spices and the four thin ones: **≥ 150 new rows**, every probe miss named in §Families present by name or alias, same row rules, same nutrition rule, same apply-before-merge order. Baby food and pet food stay out (spec 13 excluded them on purpose).

### Category mapping (no schema change; the nearest existing row decides)

| Family | Category | Precedent |
|---|---|---|
| Bakery (breads, buns, rolls, pastries, flatbreads, wraps) | `grains_pasta` | Bread, Bagels, Flour tortillas |
| Grains, pasta, rice, noodles | `grains_pasta` | Pasta, Rice, Lentils |
| Breakfast: mixes → `baking`; instant oatmeal → `grains_pasta`; toaster pastries → `snacks`; breakfast sausage → `meat_seafood`; yogurt drinks → `dairy_eggs`; frozen breakfast sandwiches → `other` (frozen-sold; spec 59 re-files) | as listed | Oats, Sausage, Yogurt, Frozen dinners |
| Snacks, nuts, dried fruit, candy | `snacks` | Potato chips, Almonds, Granola |
| Condiments, sauces, dressings, oils, vinegars, pastes | `condiments_oils` | Ketchup, Soy sauce, Salad dressing |
| Canned goods and broths | `canned` | Canned black beans, Chicken broth |
| Baking | `baking` | All-purpose flour, Chocolate chips, Sugar |
| Dairy and cheese | `dairy_eggs` | Cheddar cheese, Ricotta, Milk |
| Fresh meat, sausages, cured and deli meats | `meat_seafood` | Chicken breast, Sausage, Deli turkey |
| Store-prepared foods (deli salads, sushi, dips) | `other` | Frozen dinners → other. (Hummus sits in `leftovers` today, an inconsistency this pass does not touch — Q8.) |
| International: tempeh, seitan → `other` (Tofu); paneer, queso fresco, cotija → `dairy_eggs` (Ricotta); nori, rice paper, wrappers → `grains_pasta`; dal → `grains_pasta` (Lentils); chickpea flour, masa harina → `baking`; tamarind paste → `condiments_oils`; frozen-sold dumplings, gyoza, pierogi, spring rolls, bao, veggie burgers, falafel → `other` (spec 59 re-files) | as listed | |
| Produce | `produce` | Bell peppers, Carrots, Lettuce |

### Families (every item present by name or alias)

- **Bakery**: English muffins, Pita bread, Naan, Croissants, Baguette, Sourdough bread, Hamburger buns, Hot dog buns, Dinner rolls, Donuts, Muffins, Brownies, Wraps, Flatbread, Rye bread, Brioche, Ciabatta, Pretzel buns, Bread crumbs (alias only if the row exists).
- **International**: Tempeh, Seitan, Nori (alias seaweed sheets), Rice paper, Wonton wrappers, Dumpling wrappers, Dumplings (alias potstickers), Gyoza, Paneer, Dal (aliases red lentils, split lentils if no row), Chickpea flour (alias besan), Tamarind paste, Masa harina, Queso fresco, Cotija, Plant-based burger (alias veggie burger), Falafel (mix or frozen — one row, aliases both), Pierogi, Spring rolls (alias egg rolls), Bao, Rice flour, Coconut flour, Curry leaves (alias only if the spice pass added it), Plantains, Yuca (alias cassava).
- **Breakfast**: Pancake mix (alias waffle mix), Breakfast sausage, Instant oatmeal, Toaster pastries, Frozen breakfast sandwiches, Yogurt drinks (alias drinkable yogurt), Granola bars (alias only if the row exists), Breakfast cereal (alias only if Cereal exists).
- **Grains and pasta**: Lasagna noodles, Ramen (instant), Rice noodles, Udon, Soba, Couscous, Farro, Barley, Bulgur, Brown rice, Jasmine rice, Basmati rice, Arborio rice, Wild rice, Polenta, Gnocchi, Orzo, Egg noodles, Quinoa (alias only if the row exists), Fresh pasta, Macaroni (alias elbow pasta), Spaghetti, Penne (aliases only where a "Pasta" row already answers — the test decides by probe).
- **Snacks**: Tortilla chips, Pretzels, Protein bars, Trail mix, Cashews, Peanuts, Pecans, Raisins, Dried cranberries, Dried apricots, Rice cakes, Candy, Chocolate bars, Gum, Fruit snacks, Applesauce, Pudding cups, Gelatin cups (alias jello — the brand stays out), Beef jerky, Seaweed snacks, Pita chips, Veggie straws, Popcorn (alias only), Mixed nuts, Sunflower seeds, Pumpkin seeds (alias pepitas).
- **Condiments and sauces**: Fish sauce, BBQ sauce, Ranch dressing, Blue cheese dressing, Italian dressing, Vinaigrette, Dijon mustard, Relish, Tahini, Miso, Gochujang, Harissa, Pesto, Marinara sauce, Alfredo sauce, Curry paste, Teriyaki sauce, Sesame oil, Coconut oil, Avocado oil, Vegetable oil, Canola oil, Rice vinegar, Nutritional yeast, Chili crisp, Buffalo sauce, Steak sauce, Cocktail sauce, Tartar sauce, Horseradish, Wasabi, Chili paste (alias sambal), Enchilada sauce, Tzatziki, Chimichurri.
- **Canned**: Kidney beans, Pinto beans, Cannellini beans, Refried beans, Baked beans, Tomato sauce, Crushed tomatoes, Canned pumpkin, Jackfruit, Canned soup, Green chiles, Coconut cream, Beef broth, Vegetable broth, Bone broth, Canned peaches, Canned pineapple, Canned mushrooms, Canned green beans, Canned peas, Canned carrots, Canned chili, Canned chicken.
- **Baking**: Bread flour, Whole wheat flour, Almond flour, Cake flour, Baking powder, Active dry yeast (alias instant yeast), Cocoa powder, Brown sugar, Powdered sugar, Molasses, Gelatin, Sprinkles, Sweetened condensed milk, Shortening, Pie crust, Puff pastry, Phyllo dough, Food coloring, Baking chocolate, Panko, Cornbread mix, Cake mix, Brownie mix, Pancake mix (see breakfast — one row), Coconut flakes, Chopped walnuts (alias only).
- **Dairy and cheese**: Whipped cream, Feta, Goat cheese, Provolone, Pepper jack, American cheese, Gouda, Blue cheese, Kefir, Shredded cheese, Half and half, Heavy cream, Cottage cheese, Swiss cheese, String cheese, Egg whites, Ghee, Brie, Monterey jack, Colby jack, Queso blanco, Sour cream (alias only), Buttermilk (alias only), Whipped topping.
- **Meat**: Chicken wings, Chicken drumsticks, Chicken thighs, Whole chicken, Ground chicken, Ground turkey, Ground pork, Pork tenderloin, Pork shoulder, Pork belly, Pork ribs, Brisket, Lamb chops, Ground lamb, Veal, Bratwurst, Chorizo, Kielbasa, Meatballs, Stew meat, Beef roast, Hot dogs (alias only if the row exists), Turkey breast, Pork chops (alias only if the row exists), Bison, Duck.
- **Deli and prepared**: Prosciutto, Salami (alias only if the row exists), Sushi, Potato salad, Coleslaw, Rotisserie chicken (alias only if the row exists), Deli roast beef, Deli chicken, Pepperoni (alias only if the row exists), Guacamole (alias only if the row exists), Macaroni salad, Chicken salad, Egg salad.
- **Produce**: Clementines, Parsnips, Scallions (alias green onions), Shallots, Jalapeños, Serrano peppers, Poblano peppers, Snap peas, Romaine, Mixed greens (alias spring mix), Microgreens, Figs, Tomatillos, Nectarines, Apricots, Honeydew, Cantaloupe (alias only if the row exists), Radishes, Turnips, Beets, Leeks, Fennel, Endive, Watercress, Chard, Collard greens, Okra, Rhubarb, Persimmons, Passion fruit, Dragon fruit, Papaya, Guava, Lychee, Starfruit, Jackfruit (fresh — alias only if the canned row answers "jackfruit"; otherwise its own row).

### Shelf lives (unopened, from purchase; the precedent column is the existing row copied)

| Family | Value | Precedent |
|---|---|---|
| Breads, buns, rolls | `{"pantry": 5, "freezer": 90}` | Bread |
| Pastries (croissants, donuts, muffins, brownies) | `{"pantry": 3, "freezer": 60}` | Bagels 2/90 |
| Flatbreads, pita, naan, wraps | `{"pantry": 7, "fridge": 14, "freezer": 90}` | Flour tortillas |
| Dry pasta, rice, grains, noodles, dal | `{"pantry": 730}` | Pasta, Rice |
| Instant ramen, polenta, shelf-stable gnocchi, couscous | `{"pantry": 365}` | Rolled oats |
| Fresh pasta, wonton and dumpling wrappers | `{"fridge": 14, "freezer": 180}` | Flour tortillas' fridge |
| Frozen-sold prepared foods (dumplings, pierogi, spring rolls, bao, veggie burgers, breakfast sandwiches) | `{"freezer": 180}` | Frozen dinners 360 halved for the smaller pack |
| Chips, pretzels, pita chips, veggie straws, rice cakes | `{"pantry": 60}` / pretzels and rice cakes `{"pantry": 90}` | Potato chips, Crackers |
| Nuts and seeds | `{"pantry": 120, "fridge": 240, "freezer": 300}` | Almonds |
| Dried fruit, bars, candy, jerky, seaweed snacks, gum, fruit snacks | `{"pantry": 365}` | Granola 225 → the sealed-pack floor |
| Applesauce, pudding and gelatin cups | `{"pantry": 365}` shelf-stable; refrigerated cups `{"fridge": 30}` | — |
| Shelf-stable sauces and condiments (unopened) | `{"pantry": 365, "fridge": 180}` | Ketchup |
| Fermented pastes (miso, gochujang, fish sauce) | `{"pantry": 730, "fridge": 900}` | Soy sauce |
| Refrigerated sauces and dips (pesto, tzatziki, chimichurri, harissa) | `{"fridge": 14}` | Salsa |
| Dressings | `{"pantry": 330, "fridge": 90}` | Salad dressing |
| Oils | `{"pantry": 365}` | — (olive oil row) |
| Vinegars, nutritional yeast | `{"pantry": 730}` | — |
| Canned beans, vegetables, fruit, soups, tomatoes | `{"pantry": 730}` | Canned black beans |
| Broths and coconut cream | `{"pantry": 365}` / `{"pantry": 540}` | Chicken broth, Coconut milk |
| Flours and mixes | `{"pantry": 365}`; whole wheat and almond flour `{"pantry": 180, "fridge": 365}` | All-purpose flour |
| Sugars | `{}` | Sugar |
| Baking powder, cocoa, molasses, gelatin, sprinkles, food coloring, baking chocolate | `{"pantry": 540}` / cocoa, molasses, vinegars `{"pantry": 730}` / gelatin, sprinkles, food coloring `{"pantry": 1095}` | Honey 1095 |
| Yeast | `{"pantry": 365, "fridge": 540}` | — |
| Pie crust, puff pastry, phyllo | `{"fridge": 14, "freezer": 180}` | — |
| Hard and semi-hard cheeses (provolone, pepper jack, gouda, swiss, monterey/colby jack, american, string) | `{"fridge": 42, "freezer": 180}` | Cheddar cheese |
| Soft and fresh cheeses (feta, goat, brie, queso fresco, queso blanco, paneer, cottage) | `{"fridge": 14}` | Ricotta |
| Blue cheese, cotija, shredded cheese | `{"fridge": 30}` | — |
| Cream, half and half, whipped cream, kefir, yogurt drinks, egg whites | `{"fridge": 14}` / egg whites `{"fridge": 7}` | Greek yogurt |
| Ghee | `{"pantry": 365}` | — |
| Fresh poultry parts, whole birds | `{"fridge": 2, "freezer": 270}` / whole `{"fridge": 2, "freezer": 365}` | Chicken breast |
| Ground meats, meatballs, stew meat | `{"fridge": 2, "freezer": 120}` | Ground beef |
| Pork and lamb cuts, veal, roasts, brisket, bison, duck | `{"fridge": 3, "freezer": 180}` / roasts and brisket `{"fridge": 3, "freezer": 365}` | FoodKeeper chops/roasts |
| Fresh sausages (bratwurst, chorizo, breakfast) | `{"fridge": 2, "freezer": 60}` | Sausage |
| Smoked and cured (kielbasa, prosciutto, deli meats) | `{"fridge": 14, "freezer": 45}` / prosciutto `{"fridge": 21}` | Deli turkey |
| Store-prepared salads, sushi, dips | `{"fridge": 4}` / sushi `{"fridge": 1}` | Prepared meals |
| Tempeh, seitan | `{"fridge": 10, "freezer": 150}` | Tofu |
| Nori, rice paper | `{"pantry": 365}` / `{"pantry": 730}` | — |
| Peppers (jalapeño, serrano, poblano), tomatillos | `{"fridge": 14}` | Bell peppers 10 |
| Leafy (romaine, mixed greens, chard, collards, watercress, endive) | `{"fridge": 5}` / romaine `{"fridge": 7}` | Spinach, Lettuce |
| Microgreens, figs, snap peas | `{"fridge": 3}` / snap peas `{"fridge": 5}` | Strawberries |
| Roots (parsnips, radishes, turnips, beets, leeks, fennel) | `{"fridge": 28}` / leeks, fennel `{"fridge": 14}` | Carrots |
| Shallots | `{"pantry": 30}` | Onions |
| Citrus (clementines) | `{"fridge": 21, "counter": 7}` | Lemons |
| Stone fruit (nectarines, apricots) | `{"fridge": 5, "counter": 3}` | Tomatoes' shape |
| Melons (honeydew) | `{"fridge": 7, "counter": 7}` | — |
| Tropical (papaya, guava, lychee, passion fruit, dragon fruit, starfruit, persimmons, plantains) | `{"fridge": 7, "counter": 5}` | Tomatoes' shape |
| Okra, rhubarb, yuca | `{"fridge": 4}` / rhubarb, yuca `{"fridge": 7}` | — |

### Nutrition

Same rule as the amendments above: one clear FoodData Central entry in the mirror → that panel (`nutrition_source = 'usda'`); take the plain raw / dry / unprepared / regular variant ("Bread, pita, white, enriched"; "Cheese, feta"; "Nuts, cashew nuts, raw"; "Beans, kidney, red, mature seeds, canned, solids and liquids"; "Chicken, broilers or fryers, wings, meat and skin, raw"; "Sauce, barbecue"). Mixes, prepared foods, dressings with many variants, candy, and anything the mirror answers with several materially different panels stay **null**. Record the FDC description per panel in the apply file's comments.

### Aliases and probes

Aliases ≤ 6, lowercase, no brand names (so no "tabasco", "jello", "cool whip", "spam" — generic names only; a brand arrives by barcode). The type-ahead probe list in `tests/catalog-seed-extension.test.ts` gains, one per family at least: english muffin, naan, potstickers, paneer, pancake mix, ramen, basmati, cashews, jerky, fish sauce, ranch, pinto beans, bread flour, feta, chicken wings, prosciutto, scallions, green onions, jalapeño, jalapeno (accent-free), spring mix.

### Acceptance (in addition to the amendments above)

- [ ] ≥ 150 new rows; every §Families item present by name or alias; mapping per §Category mapping
- [ ] Every shelf life matches the table; sugars ship `{}`
- [ ] FDC panels only where one clear entry exists, each traceable; the rest null
- [ ] Existing rows keep id, name and category; aliases only grow
- [ ] Same data apply, same registry entry, same rehearse → apply → merge order

### Open questions (defaults picked; overrule in the PR)

- **Q8 — store-prepared foods in `other`.** Hummus and Prepared meals sit in `leftovers` today, which spec 3 reserves for the household's own leftovers. New deli rows go to `other`; the two existing rows are left alone and listed in the review snippet for a later re-file.
- **Q9 — near-brand generic names.** "Tabasco", "jello", "cool whip", "spam", "oreo" are excluded even though shoppers type them; the alias rule stays brand-free. Revisit if the barcode path does not catch them in beta.
- **Q10 — frozen-sold rows filed `other` for now** (dumplings, breakfast sandwiches, pierogi, spring rolls, bao, veggie burgers): spec 59 re-files them to `frozen`; they are listed in that spec's enumerated re-file list by the spec 59 builder.

### Out of scope

Baby food, formula, pet food (spec 13's exclusion stands) · household and personal-care items (spec 29 deferred those enum values) · regional or branded products · a second alias language.
