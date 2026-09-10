import { readFileSync, writeFileSync, appendFileSync } from 'node:fs';
import { B_ROWS, BROAD_SHELF } from './roster.mjs';
import { B_PANELS } from './panels.mjs';
import { BROAD_FAMILIES, BROAD_APPLIED_FAMILIES, BROAD_PROBES } from './bfam.mjs';

const TEST = '/Users/orchestrator/agents/worktrees/broad/tests/catalog-seed-extension.test.ts';
const SEED = readFileSync('/Users/orchestrator/agents/worktrees/broad/supabase/seed.sql', 'utf8');
const ROW = /^ {2}\('((?:[^']|'')*)', '\{(.*?)\}', '(\w+)', '(\{.*?\})'\)/gm;
const seedRows = [...SEED.matchAll(ROW)].map((m) => ({
  name: m[1].replace(/''/g, "'"), category: m[3],
}));
const catOf = new Map(seedRows.map((r) => [r.name, r.category]));
const newNames = new Set(B_ROWS.map((r) => r[0]));

const CAT_ORDER = ['produce', 'dairy_eggs', 'meat_seafood', 'grains_pasta', 'baking', 'canned', 'condiments_oils', 'snacks', 'other'];
const FAM_ORDER = ['bakery', 'international', 'breakfast', 'grains', 'snacks', 'condiments', 'canned', 'baking', 'dairy', 'meat', 'deli', 'produce'];
const ts = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;

// ---- BROAD_SHELF ------------------------------------------------------------
const SHELF_COMMENT = {
  bread: 'breads, buns and rolls (Bread)',
  pastry: 'croissants, donuts, brownies (Bagels 2/90)',
  flatbread: 'pita, naan, wraps, flatbread (Flour tortillas)',
  dryGrain: 'dry pasta, rice, grains, noodles, dal (Pasta, Rice)',
  instantGrain: 'instant ramen, polenta, gnocchi, couscous (Rolled oats)',
  freshWrapper: 'fresh wonton and dumpling wrappers (Flour tortillas\' fridge)',
  frozenPrepared: 'frozen-sold prepared foods (Frozen dinners, halved)',
  chips: 'chips, pita chips, veggie straws (Potato chips)',
  riceCake: 'pretzels and rice cakes (Crackers)',
  nuts: 'nuts, seeds and trail mix (Almonds)',
  driedSnack: 'dried fruit, bars, candy, jerky, gum, coconut flakes (the sealed-pack floor)',
  shelfStableCup: 'shelf-stable pudding and gelatin cups',
  sauce: 'shelf-stable sauces and condiments, unopened (Ketchup)',
  fermentedPaste: 'fermented pastes — miso, gochujang, fish sauce, sambal (Soy sauce)',
  fridgeSauce: 'refrigerated sauces and dips — pesto, tzatziki, chimichurri, harissa (Salsa)',
  dressing: 'dressings (Salad dressing)',
  vinegar: 'vinegars and nutritional yeast',
  cannedGood: 'canned beans, vegetables, fruit, soups, tomatoes (Canned black beans)',
  broth: 'broths (Chicken broth)',
  flourMix: 'flours and mixes (All-purpose flour)',
  wholeFlour: 'whole wheat and almond flour',
  bakingVeryLong: 'gelatin, sprinkles, food colouring (Honey 1095)',
  doughPastry: 'pie crust, puff pastry, phyllo',
  hardCheese: 'hard and semi-hard cheeses (Cheddar cheese)',
  softCheese: 'soft and fresh cheeses (Ricotta)',
  blueShredded: 'blue cheese, cotija, shredded cheese',
  cream: 'cream, whipped cream, kefir, yogurt drinks',
  poultryParts: 'fresh poultry parts (Chicken breast)',
  groundMeat: 'ground meats, meatballs, stew meat (Ground beef)',
  porkLambCut: 'pork and lamb cuts, veal, bison, duck',
  roast: 'roasts and brisket',
  freshSausage: 'fresh sausages — bratwurst, chorizo, breakfast (Sausage)',
  curedMeat: 'smoked and cured — kielbasa, deli meats (Deli turkey)',
  prosciutto: 'prosciutto',
  preparedSalad: 'store-prepared salads and dips (Prepared meals)',
  sushi: 'sushi',
  tempehSeitan: 'tempeh and seitan (Tofu)',
  nori: 'nori',
  ricePaper: 'rice paper',
  peppers: 'jalapeños, serranos, poblanos, tomatillos (Bell peppers 10)',
  leafy: 'leafy — mixed greens, chard, collards, watercress, endive (Spinach)',
  romaine: 'romaine (Lettuce)',
  tender: 'microgreens and figs (Strawberries)',
  snapPeas: 'snap peas',
  roots: 'roots — parsnips, radishes, turnips, beets (Carrots)',
  leekFennel: 'leeks and fennel',
  shallots: 'shallots (Onions)',
  citrus: 'citrus — clementines (Lemons)',
  stoneFruit: 'stone fruit — nectarines, apricots',
  tropical: 'tropical — papaya, guava, lychee, passion fruit, dragon fruit, starfruit, persimmons, plantains',
  rhubarbYuca: 'rhubarb and yuca',
};
const shelfLines = Object.entries(BROAD_SHELF).map(([k, v]) => {
  const body = Object.entries(v).map(([a, b]) => `${a}: ${b}`).join(', ');
  return `  ${k}: { ${body} }, // ${SHELF_COMMENT[k]}`;
});

// ---- BROAD_ROWS -------------------------------------------------------------
const rowLines = [];
for (const fam of FAM_ORDER) {
  const rows = B_ROWS.filter((r) => r[4] === fam).sort((a, b) => a[0].localeCompare(b[0]));
  rowLines.push(`  // ${fam} (${rows.length})`);
  for (const r of rows) rowLines.push(`  [${ts(r[0])}, '${r[2]}', '${r[3]}'],`);
}

// ---- BROAD_EXISTING ---------------------------------------------------------
const existing = [...new Set(BROAD_FAMILIES.map(([, want]) => want).concat(BROAD_APPLIED_FAMILIES.map(([, w]) => w)))]
  .filter((n) => !newNames.has(n))
  .sort((a, b) => (CAT_ORDER.indexOf(catOf.get(a)) - CAT_ORDER.indexOf(catOf.get(b))) || a.localeCompare(b));
const existingLines = existing.map((n) => `  [${ts(n)}, '${catOf.get(n) ?? '??'}'],`);

// ---- panels / nulls ---------------------------------------------------------
const panelRows = B_ROWS.filter((r) => r[0] in B_PANELS).length;

const familyCounts = FAM_ORDER.map((f) => `${f} ${B_ROWS.filter((r) => r[4] === f).length}`).join(' · ');

const block = `

/* ===========================================================================
 * §"Broad extension (amendment, 2026-09-06) — the twelve thin families" —
 * bakery, international, breakfast, grains and pasta, snacks, condiments and
 * sauces, canned goods, baking, dairy and cheese, meat, deli and prepared,
 * and produce.
 *
 * The 2026-09-06 broad probe found about half of 267 everyday items. This half
 * of the suite asks the same four questions the thin-category half asks, of a
 * much wider surface: are the ${B_ROWS.length} rows there and shaped the way §Row rules
 * says, did every family land on the category §Category mapping names, does
 * every shelf life come out of §Shelf lives and nowhere else, and is every item
 * §Families names reachable through the real matcher.
 *
 * Rows per family: ${familyCounts}.
 * ======================================================================== */

/** §Shelf lives, verbatim. A broad-extension row may carry one of these and
 *  nothing else — the amendment invents no value per row. Three of the table's
 *  entries are not used because the food that would take them already had a
 *  row: coconut cream (Coconut cream (canned)), the refrigerated pudding cup
 *  (both new cup rows are the shelf-stable aisle product), and the 540-day
 *  baking staples (baking powder, cocoa, molasses and baking chocolate all
 *  exist). Sugars are the fourth — see the test below. */
const BROAD_SHELF = {
${shelfLines.join('\n')}
} as const;

/**
 * The ${B_ROWS.length} new rows, written out rather than derived, exactly as the thin half
 * writes out its ${'87'}: name, the category §Category mapping assigns, and which
 * §Shelf lives row it takes.
 */
const BROAD_ROWS: [string, string, keyof typeof BROAD_SHELF][] = [
${rowLines.join('\n')}
];

const broadByName = new Map(BROAD_ROWS.map(([name, category, shelf]) => [name, { category, shelf }]));

/** The rows the twelve families name that ALREADY EXISTED — every one of them
 *  is an "alias only if the row exists" case, and §Acceptance says they keep id,
 *  name and category. Written out with the category they must keep. */
const BROAD_EXISTING: [string, string][] = [
${existingLines.join('\n')}
];

/** The pre-amendment aliases of the three HAND rows this amendment edits.
 *  §Acceptance: "aliases only grow". */
const BROAD_ALIASES_BEFORE: Record<string, string[]> = {
  Pasta: ['spaghetti', 'penne', 'macaroni'],
  Breadcrumbs: ['panko'],
  'Active dry yeast': ['yeast'],
};

/** The sixteen aliases \`scripts/build-catalog-seed.mjs\` prunes off GENERATED
 *  rows because they now equal a hand row's canonical name — the whole cost of
 *  the pruned-items decision, written out so a silent change to the generated
 *  block cannot hide inside it. \`Papaya\`, \`Lychee\`, \`Nectarines\`, \`Raisins\`,
 *  \`Brisket\` and \`Kielbasa\` are the broad extension's own six. */
const PRUNED_ALIASES: [string, string][] = [
  ['White fish', 'cod'],
  ['White fish', 'haddock'],
  ['White fish', 'halibut'],
  ['Live shellfish', 'clams'],
  ['Live shellfish', 'mussels'],
  ['Live shellfish', 'oysters'],
  ['Shucked shellfish', 'clams'],
  ['Shucked shellfish', 'mussels'],
  ['Shucked shellfish', 'oysters'],
  ['French fries', 'tater tots'],
  ['Mango', 'papaya'],
  ['Cherries (sweet)', 'lychee'],
  ['Stone fruit', 'nectarines'],
  ['Dried fruit', 'raisins'],
  ['Beef roast', 'brisket'],
  ['Smoked sausage', 'kielbasa'],
];

describe('the twelve thin families', () => {
  it('adds at least 150 rows and every one the amendment names', () => {
    expect(BROAD_ROWS.length).toBeGreaterThanOrEqual(150);
    expect(BROAD_ROWS.length).toBe(${B_ROWS.length});
    for (const [name] of BROAD_ROWS) expect(seedRows.find((r) => r.name === name)).toBeDefined();
    expect(new Set(BROAD_ROWS.map(([n]) => norm(n))).size).toBe(BROAD_ROWS.length);
  });

  it('maps every family onto an existing category (§Category mapping)', () => {
    // Again no \`food_category\` value is added: spec 59 owns \`frozen\`, and Q10
    // records that the frozen-sold rows here are filed \`other\` until it lands.
    const known = new Set(seedRows.map((r) => r.category));
    for (const [name, category] of BROAD_ROWS) {
      expect(known.has(category)).toBe(true);
      expect(seedRows.find((r) => r.name === name)!.category).toBe(category);
    }
  });

  it('gives every new row a shelf life from the §Shelf lives table', () => {
    for (const [name, , shelf] of BROAD_ROWS) {
      expect(seedRows.find((r) => r.name === name)!.shelfLife).toEqual(BROAD_SHELF[shelf]);
    }
  });

  it('leaves the sugars at {} and adds no sugar row of its own', () => {
    // §Acceptance says "sugars ship {}". §Families names Brown sugar and
    // Powdered sugar, and both already existed — so the clause binds nothing
    // new, and the honest test is that nothing moved: the two rows that ship
    // {} still do, and the two hand rows that carry a real number keep it,
    // because an existing row is never re-valued.
    expect(BROAD_ROWS.some(([n]) => /sugar/i.test(n))).toBe(false);
    for (const name of ['Sugar', 'Powdered sugar']) {
      expect(seedRows.find((r) => r.name === name)!.shelfLife).toEqual({});
    }
    expect(seedRows.find((r) => r.name === 'Granulated sugar')!.shelfLife).toEqual({ pantry: 730 });
    expect(seedRows.find((r) => r.name === 'Brown sugar')!.shelfLife).toEqual({ pantry: 365 });
  });

  it('obeys the alias rules on every new row', () => {
    for (const [name] of BROAD_ROWS) {
      const row = seedRows.find((r) => r.name === name)!;
      expect(row.aliases.length).toBeLessThanOrEqual(6);
      for (const alias of row.aliases) {
        expect(alias).toBe(alias.toLowerCase());
        expect(norm(alias)).not.toBe(norm(row.name));
      }
      expect(new Set(row.aliases.map(norm)).size).toBe(row.aliases.length);
    }
  });

  it('carries no brand name, anywhere in the new rows (Q9)', () => {
    // §Aliases and probes: "no brand names (so no tabasco, jello, cool whip,
    // spam)". Q9 keeps them out even as aliases; a brand arrives by barcode.
    const BRANDS = [
      'tabasco', 'jello', 'jell o', 'cool whip', 'spam', 'oreo', 'craisins', 'goldfish',
      'kraft', 'heinz', 'gatorade', 'red bull', 'doritos', 'cheerios', 'nutella', 'velveeta',
    ];
    for (const [name] of BROAD_ROWS) {
      const row = seedRows.find((r) => r.name === name)!;
      for (const text of [row.name, ...row.aliases]) {
        for (const brand of BRANDS) expect(norm(text)).not.toContain(brand);
      }
    }
  });

  it('keeps every pre-existing row these families name, category untouched', () => {
    for (const [name, category] of BROAD_EXISTING) {
      const row = seedRows.find((r) => r.name === name);
      expect(row).toBeDefined();
      expect(row!.category).toBe(category);
    }
  });

  it('only grows the aliases of the three hand rows it edits', () => {
    for (const [name, before] of Object.entries(BROAD_ALIASES_BEFORE)) {
      const row = seedRows.find((r) => r.name === name)!;
      for (const alias of before) expect(row.aliases).toContain(alias);
      expect(row.aliases.length).toBe(before.length + 1);
    }
  });

  it('prunes exactly the sixteen aliases the decision costs, and no more', () => {
    // specs/catalog-seed.md §"Decision on the seven pruned items": the
    // generated block may differ from its previous state ONLY by aliases the
    // builder drops because they now equal a hand row's name. Each pruned
    // alias is checked twice — gone from the generated row, and owned by a hand
    // row of that name, which is what makes the loss deliberate rather than
    // accidental.
    const generated = section(SEED, '-- BEGIN generated catalog', '-- END generated catalog');
    const generatedRows = parseRows(generated);
    const handNames = new Set(parseRows(handBlock).map((r) => norm(r.name)));
    for (const [row, alias] of PRUNED_ALIASES) {
      const target = generatedRows.find((r) => r.name === row);
      expect(target).toBeDefined();
      expect(target!.aliases.map(norm)).not.toContain(norm(alias));
      expect(handNames.has(norm(alias))).toBe(true);
    }
    // …and nothing else went missing: every generated alias that survives is
    // one no hand row is named after.
    for (const row of generatedRows) {
      for (const alias of row.aliases) expect(handNames.has(norm(alias))).toBe(false);
    }
  });
});
`;

appendFileSync(TEST, block);
console.log('appended part 1', { rows: B_ROWS.length, panels: panelRows, existing: existing.length });
writeFileSync('/Users/orchestrator/agents/tmp-broad/test-meta.json', JSON.stringify({ panels: panelRows, nulls: B_ROWS.length - panelRows }));
