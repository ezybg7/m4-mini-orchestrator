import { readFileSync, writeFileSync } from 'node:fs';
import { A_ROWS, B_ROWS, BROAD_SHELF, THIN_SHELF_EXTRA } from './roster.mjs';

const SEED = '/Users/orchestrator/agents/worktrees/broad/supabase/seed.sql';
const THIN_SHELF = {
  frozenPotato: { freezer: 365 },
  leanFish: { fridge: 2, freezer: 180 },
  ...THIN_SHELF_EXTRA,
};
export const SHELF = { ...THIN_SHELF, ...BROAD_SHELF };

const sqlStr = (s) => `'${s.replace(/'/g, "''")}'`;
const sqlArr = (a) => (a.length === 0 ? `'{}'` : `'{${a.map((x) => `"${x.replace(/(["\\])/g, '\\$1')}"`).join(', ')}}'`);
const shelfJson = (o) => `'{${Object.entries(o).map(([k, v]) => `"${k}": ${v}`).join(', ')}}'`;
export const rowLine = (name, aliases, category, shelfKey) =>
  `  (${sqlStr(name)}, ${sqlArr(aliases)}, '${category}', ${shelfJson(SHELF[shelfKey])})`;

const byCat = (rows, cat) => rows.filter((r) => r[2] === cat).sort((a, b) => a[0].localeCompare(b[0]));

// ---- comments for each new broad sub-section -------------------------------
const HEAD = (cat, body) =>
  `  -- ${cat}, 2026-09-06 broad extension (specs/catalog-seed.md §Broad\n` +
  `  -- extension), sorted by name. ${body}`;

const SECTIONS = {
  produce: HEAD('produce', 'Category per §Category mapping; every shelf life is\n  -- an entry of the amendment\'s table — peppers and tomatillos fridge 14,\n  -- leafy 5 (romaine 7), microgreens and figs 3, snap peas 5, roots 28\n  -- (leeks and fennel 14), shallots pantry 30, citrus fridge 21 / counter 7,\n  -- stone fruit 5/3, tropical 7/5, rhubarb and yuca fridge 7.'),
  dairy_eggs: HEAD('dairy & eggs', 'Hard and semi-hard cheeses take Cheddar\'s\n  -- fridge 42 / freezer 180, soft and fresh cheeses Ricotta\'s fridge 14, blue\n  -- cheese and cotija fridge 30, creams and drinkable yogurt fridge 14.'),
  meat_seafood: HEAD('meat & seafood', 'Poultry parts fridge 2 / freezer 270,\n  -- ground meats and meatballs 2/120, pork and lamb cuts 3/180, roasts and\n  -- brisket 3/365, fresh sausages 2/60, smoked and cured 14/45, prosciutto\n  -- fridge 21 — the amendment\'s table, which copies the rows beside them.'),
  grains_pasta: HEAD('grains & pasta', 'Bakery, wrappers and dry grains. Breads and\n  -- buns pantry 5 / freezer 90 (Bread), pastries 3/60 (Bagels), flatbreads\n  -- and wraps 7 / fridge 14 / freezer 90 (Flour tortillas), dry pasta, rice\n  -- and noodles pantry 730, instant ramen, couscous, polenta and gnocchi 365,\n  -- fresh wrappers fridge 14 / freezer 180, nori 365, rice paper 730.'),
  baking: HEAD('baking', 'Flours and mixes pantry 365, whole-grain and almond\n  -- flour 180 / fridge 365, gelatin, sprinkles and food colouring 1095,\n  -- doughs fridge 14 / freezer 180, condensed milk the canned-goods 730,\n  -- coconut flakes the dried-goods 365.'),
  canned: HEAD('canned', 'Canned beans, vegetables, fruit, tomatoes, soups and\n  -- chili take Canned black beans\' pantry 730; bone broth takes Chicken\n  -- broth\'s 365.'),
  condiments_oils: HEAD('condiments & oils', 'Shelf-stable sauces pantry 365 / fridge 180\n  -- (Ketchup), fermented pastes 730/900 (Soy sauce), refrigerated sauces and\n  -- dips fridge 14 (Salsa), dressings pantry 330 / fridge 90 (Salad\n  -- dressing), vinegars and nutritional yeast pantry 730.'),
  snacks: HEAD('snacks', 'Chips and straws pantry 60 (Potato chips), pretzels and\n  -- rice cakes 90 (Crackers), nuts and trail mix 120 / fridge 240 / freezer\n  -- 300 (Almonds), dried fruit, bars, candy, jerky and gum 365, shelf-stable\n  -- pudding and gelatin cups 365.'),
  other: HEAD('other', 'Store-prepared foods and the frozen-sold international\n  -- rows §Category mapping files here — Q8 keeps the existing Hummus and\n  -- Prepared meals rows in `leftovers` and lists them for a later re-file;\n  -- Q10 notes that spec 59 re-files the frozen-sold ones to `frozen`.\n  -- Frozen-sold prepared foods freezer 180, deli salads fridge 4, sushi 1,\n  -- tempeh and seitan fridge 10 / freezer 150 (Tofu).'),
};

let seed = readFileSync(SEED, 'utf8');

function insertAfter(anchor, text) {
  const i = seed.indexOf(anchor);
  if (i === -1) throw new Error('anchor not found: ' + anchor);
  seed = seed.slice(0, i + anchor.length) + text + seed.slice(i + anchor.length);
}

// ---- (1) the seven thin rows into the existing thin sub-sections ------------
const thinMeat = byCat(A_ROWS, 'meat_seafood');
const thinProduce = byCat(A_ROWS, 'produce');

// meat & seafood thin section: merge the six into the sorted 13
const MEAT_THIN_FIRST = "  ('Catfish', ";
const MEAT_THIN_LAST = "  ('Trout', '{\"rainbow trout\", \"trout fillets\", \"steelhead\"}', 'meat_seafood', '{\"fridge\": 2, \"freezer\": 90}'),";
{
  const from = seed.indexOf(MEAT_THIN_FIRST);
  const to = seed.indexOf(MEAT_THIN_LAST) + MEAT_THIN_LAST.length;
  if (from === -1 || to < from) throw new Error('meat thin section not found');
  const existing = seed.slice(from, to).split('\n');
  const merged = [
    ...existing.map((l) => ({ name: /^ {2}\('((?:[^']|'')*)'/.exec(l)[1].replace(/''/g, "'"), line: l.replace(/,$/, '') })),
    ...thinMeat.map((r) => ({ name: r[0], line: rowLine(r[0], r[1], r[2], r[3]) })),
  ].sort((a, b) => a.name.localeCompare(b.name));
  seed = seed.slice(0, from) + merged.map((m) => m.line).join(',\n') + ',' + seed.slice(to);
}

// produce thin section: Tater tots sorts last
const PRODUCE_THIN_LAST = "  ('Frozen strawberries', '{\"strawberries frozen\", \"frozen sliced strawberries\"}', 'produce', '{\"freezer\": 420}'),";
insertAfter(PRODUCE_THIN_LAST, '\n' + thinProduce.map((r) => rowLine(r[0], r[1], r[2], r[3])).join(',\n') + ',');

// ---- alias growth on three hand rows (before the anchors that use them) ----
const GROW = [
  ["  ('Pasta', '{\"spaghetti\", \"penne\", \"macaroni\"}', 'grains_pasta', '{\"pantry\": 730}'),",
   "  ('Pasta', '{\"spaghetti\", \"penne\", \"macaroni\", \"elbow pasta\"}', 'grains_pasta', '{\"pantry\": 730}'),"],
  ["  ('Breadcrumbs', '{\"panko\"}', 'grains_pasta', '{\"pantry\": 180}'),",
   "  ('Breadcrumbs', '{\"panko\", \"bread crumbs\"}', 'grains_pasta', '{\"pantry\": 180}'),"],
  ["  ('Active dry yeast', '{\"yeast\"}', 'baking', '{\"pantry\": 120, \"fridge\": 180}'),",
   "  ('Active dry yeast', '{\"yeast\", \"instant yeast\"}', 'baking', '{\"pantry\": 120, \"fridge\": 180}'),"],
];
for (const [from, to] of GROW) {
  if (!seed.includes(from)) throw new Error('grow anchor not found: ' + from);
  seed = seed.replace(from, to);
}

// ---- (2) the broad sections -------------------------------------------------
const ANCHORS = {
  produce: "  ('Tater tots', ",       // replaced below by "end of produce thin"
  dairy_eggs: "  ('Plant-based creamer', '{\"non-dairy creamer\", \"nondairy creamer\", \"almond creamer\", \"coconut creamer\", \"vegan creamer\"}', 'dairy_eggs', '{}'),",
  meat_seafood: null,
  grains_pasta: "  ('Breadcrumbs', '{\"panko\", \"bread crumbs\"}', 'grains_pasta', '{\"pantry\": 180}'),",
  baking: "  ('Cocoa powder', '{\"cocoa\"}', 'baking', '{\"pantry\": 730}'),",
  canned: "  ('Canned sardines', '{\"sardines\", \"tinned sardines\", \"sardines in oil\"}', 'canned', '{\"pantry\": 1095}'),",
  condiments_oils: "  ('Salsa', '{}', 'condiments_oils', '{\"fridge\": 14}'),",
  snacks: "  ('Granola bars', '{}', 'snacks', '{\"pantry\": 180}'),",
  other: null,
};

function block(cat) {
  const rows = byCat(B_ROWS, cat);
  return '\n' + SECTIONS[cat] + '\n' + rows.map((r) => rowLine(r[0], r[1], r[2], r[3])).join(',\n') + ',';
}

// produce: after the thin section (which now ends with Tater tots)
insertAfter(rowLine('Tater tots', A_ROWS.find((r) => r[0] === 'Tater tots')[1], 'produce', 'frozenPotato') + ',', block('produce'));
insertAfter(ANCHORS.dairy_eggs, block('dairy_eggs'));
// meat: after the thin section's last row, which is now Trout
insertAfter(MEAT_THIN_LAST, block('meat_seafood'));
insertAfter(ANCHORS.grains_pasta, block('grains_pasta'));
insertAfter(ANCHORS.baking, block('baking'));
insertAfter(ANCHORS.canned, block('canned'));
insertAfter(ANCHORS.condiments_oils, block('condiments_oils'));
insertAfter(ANCHORS.snacks, block('snacks'));

// other: a brand-new section at the very end of the hand block
const LAST_HAND = "  ('Whiskey', '{\"bourbon\", \"scotch\", \"rye whiskey\", \"whisky\"}', 'beverages', '{\"pantry\": 1825}');";
{
  const i = seed.indexOf(LAST_HAND);
  if (i === -1) throw new Error('last hand row not found');
  const rows = byCat(B_ROWS, 'other');
  seed = seed.slice(0, i) + LAST_HAND.replace(/;$/, ',') + '\n' + SECTIONS.other + '\n'
    + rows.map((r) => rowLine(r[0], r[1], r[2], r[3])).join(',\n') + ';'
    + seed.slice(i + LAST_HAND.length);
}

writeFileSync(SEED, seed);
console.log('seed written');
