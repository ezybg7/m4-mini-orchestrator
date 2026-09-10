import { readFileSync, writeFileSync } from 'node:fs';
import { A_ROWS, B_ROWS } from './roster.mjs';

const APPLY = '/Users/orchestrator/agents/worktrees/broad/db/apply/catalog-extension-2026-09.sql';
let sql = readFileSync(APPLY, 'utf8');

const rep = (from, to) => {
  if (!sql.includes(from)) throw new Error('not found:\n' + from);
  sql = sql.replace(from, to);
};

// ---- header ---------------------------------------------------------------
rep(
  `-- §"Spice extension (amendment, 2026-09-06)" and §"Thin-category extension
-- (amendment, 2026-09-06)" — both amendments, one file, one transaction.`,
  `-- §"Spice extension (amendment, 2026-09-06)", §"Thin-category extension
-- (amendment, 2026-09-06)" and §"Broad extension (amendment, 2026-09-06) — the
-- twelve thin families" — all three amendments, one file, one transaction.`,
);

rep(
  `--   (d) 80 new rows — 8 plant milks and creamers (\`dairy_eggs\`), 21 frozen
--       vegetables and fruit (\`produce\`), 13 fish and shellfish (\`meat_seafood\`),
--       4 canned fish (\`canned\`), 34 drinks (\`beverages\`). Same
--       \`on conflict do nothing\`, same anchor. §Category mapping: no enum value
--       is added, every family lands on a category the seed already uses.
--   (e) alias growth for 16 existing rows in those families — 5 hand-tuned
--       (which supabase/seed.sql carries too) and 11 generated, whose aliases can
--       ONLY live here (see the note above that section).
--   (f) 43 USDA panels for the thin-category rows that have one clear entry;
--       the other 37 rows are null by design.
--   (g) a trailing count check with the expected totals for BOTH amendments.`,
  `--   (d) 87 new rows — 8 plant milks and creamers (\`dairy_eggs\`), 22 frozen
--       vegetables and fruit (\`produce\`), 19 fish and shellfish (\`meat_seafood\`),
--       4 canned fish (\`canned\`), 34 drinks (\`beverages\`). Same
--       \`on conflict do nothing\`, same anchor. §Category mapping: no enum value
--       is added, every family lands on a category the seed already uses.
--       **80 of these shipped in the first draft of this file**; the other seven
--       — \`Cod\`, \`Haddock\`, \`Halibut\`, \`Clams\`, \`Mussels\`, \`Oysters\` and
--       \`Tater tots\` — were aliases of the FoodKeeper bucket rows until the
--       orchestrator's 2026-09-06 decision (specs/catalog-seed.md §"Decision on
--       the seven pruned items") gave them rows of their own.
--   (e) alias growth for 16 existing rows in those families — 5 hand-tuned
--       (which supabase/seed.sql carries too) and 11 generated, whose aliases can
--       ONLY live here (see the note above that section).
--   (f) 49 USDA panels for the thin-category rows that have one clear entry;
--       the other 38 rows are null by design.
--
-- THE TWELVE THIN FAMILIES (§Broad extension):
--   (g) 186 new rows across bakery, international, breakfast, grains and pasta,
--       snacks, condiments and sauces, canned goods, baking, dairy and cheese,
--       meat, deli and prepared, and produce — 26 \`produce\`, 18 \`dairy_eggs\`,
--       16 \`meat_seafood\`, 37 \`grains_pasta\`, 17 \`baking\`, 19 \`canned\`,
--       24 \`condiments_oils\`, 16 \`snacks\`, 13 \`other\`. Same
--       \`on conflict do nothing\`, same anchor, and again no enum value is added.
--   (h) alias growth for 8 more existing rows — 3 hand-tuned and 5 generated.
--   (i) 126 USDA panels for the broad-extension rows that have one clear entry;
--       the other 60 rows are null by design.
--   (j) a trailing count check with the expected totals for ALL THREE amendments.`,
);

rep(
  `-- Which thin-category rows get a panel (§Nutrition, made mechanical): candidates
-- are the mirror entries that name the plain food in the state §Nutrition asks
-- for — raw / unprepared / unsweetened / regular / canned-as-sold. Entries naming
-- a different state (cooked, dried, salted, sweetened, breaded, concentrated), a
-- different food, a brand, or the Alaska-Native traditional-foods collection are
-- not candidates. A panel is taken when exactly one candidate survives, or when
-- the survivors agree within 10% on kcal and one of them is the Foundation entry
-- or the one whose description names the plain product; the reason is written
-- above every statement. Everything else stays NULL: blends and mixed bags`,
  `-- Which thin-category rows get a panel (§Nutrition, made mechanical): candidates
-- are the mirror entries that name the plain food in the state §Nutrition asks
-- for — raw / unprepared / unsweetened / regular / canned-as-sold. Entries naming
-- a different state (cooked, dried, salted, sweetened, breaded, concentrated), a
-- different food, a brand, or the Alaska-Native traditional-foods collection are
-- not candidates. A panel is taken when exactly one candidate survives, or when
-- the survivors agree within 10% on kcal and one of them is the Foundation entry
-- or the one whose description names the plain product; the reason is written
-- above every statement. Everything else stays NULL: blends and mixed bags`,
);

// the broad half's rule, appended after the thin half's rule paragraph
rep(
  `-- salt) — honest, not invented (docs/adr/catalog.md O1).
--`,
  `-- salt) — honest, not invented (docs/adr/catalog.md O1).
--
-- The broad half (i) reads the same rule with three clauses the twelve families
-- forced into the open, and every one of them is stated so a reviewer can check
-- it rather than trust it:
--   • "the state §Nutrition asks for" means THE STATE A SHOPPER BUYS: raw / dry /
--     unprepared for anything cooked at home, as-sold for anything eaten as it
--     comes (a canned bean, a bottle of teriyaki, a gelatin cup). This is what
--     rules the FNDDS survey entries in and out — they are as-consumed values,
--     so they answer for bread, cheese and bottled sauce and never for gnocchi,
--     pierogi or falafel, which FDC only reports cooked.
--   • An FNDDS survey entry counts only when it is the ONLY candidate.
--   • Where two entries carry the SAME description the Foundation one supersedes
--     the legacy one rather than competing with it; otherwise the entry naming
--     the plain product with the fewest qualifiers wins. Two entries whose kcal
--     differ by less than 5 per 100 g agree whatever the percentage says — at
--     the lettuce end of the scale 10% is finer than the gap between two
--     analyses of the same leaf.
-- The 60 broad rows with no panel are the same three populations: foods FDC does
-- not describe (seitan, gochujang, harissa, dragon fruit, orzo, basmati), rows
-- that name a category rather than a food (Candy, Canned soup, Cake mix, Mixed
-- greens, the deli salads), and plausible entries that disagree materially
-- (goat cheese 264/364/452 by texture, canned peaches 24-96 by pack, oysters
-- 51/59/81 by stock).
--`,
);

// ---- section (d)/(e)/(f) in-file headings ----------------------------------
rep('-- (d) new rows, thin categories --------------------------------------------',
    '-- (d) new rows, thin categories (87: the 80 of the first draft plus the seven\n--     the pruned-items decision promoted from aliases to rows) ----------------');
rep('-- (f) USDA panels for the thin-category rows that have one ------------------',
    '-- (f) USDA panels for the thin-category rows that have one (49) -------------');

// ---- (j) the count block ---------------------------------------------------
rep(
  `-- Expected against production (probe of 2026-09-06: 431 catalog rows, 23 of them
-- \`spices\`): spices 23 + 117 = 140; the thin-category families gain dairy_eggs
-- +8, produce +21, meat_seafood +13, canned +4, beverages +34; catalog total
-- 431 + 117 + 80 = 628. A name a user had already created is skipped by
-- \`on conflict do nothing\`, so a LOWER number is a fact to record in the
-- registry entry, not a failure.`,
  `-- Expected against production (probe of 2026-09-06: 431 catalog rows, 23 of them
-- \`spices\`): spices 23 + 117 = 140; the thin-category families gain dairy_eggs
-- +8, produce +22, meat_seafood +19, canned +4, beverages +34; the twelve broad
-- families then add produce +26, dairy_eggs +18, meat_seafood +16, grains_pasta
-- +37, baking +17, canned +19, condiments_oils +24, snacks +16, other +13;
-- catalog total 431 + 117 + 87 + 186 = 821. A name a user had already created is
-- skipped by \`on conflict do nothing\`, so a LOWER number is a fact to record in
-- the registry entry, not a failure.`,
);
rep(
  `-- Panels, thin categories: 43 of the 80 new rows carry one, 37 are null by
-- design (§Nutrition's tie-abstention). Counted by name, so nothing else already
-- living in those five categories can move these numbers.`,
  `-- Panels, thin categories: 49 of the 87 new rows carry one, 38 are null by
-- design (§Nutrition's tie-abstention). Counted by name, so nothing else already
-- living in those five categories can move these numbers.`,
);

// extend the thin name list with the seven, and add the fourth check
{
  const marker = `    'vegetable juice', 'vodka', 'whiskey'
 ]::text[]);`;
  const seven = A_ROWS.map((r) => r[0].toLowerCase()).sort();
  rep(marker, `    'vegetable juice', 'vodka', 'whiskey',
    ${seven.map((n) => `'${n}'`).join(', ')}
 ]::text[]);`);
}

const broadNames = B_ROWS.map((r) => r[0].toLowerCase().replace(/'/g, "''")).sort();
const wrapped = [];
{
  let line = '   ';
  for (const n of broadNames) {
    const piece = ` '${n}',`;
    if ((line + piece).length > 92) { wrapped.push(line); line = '   '; }
    line += piece;
  }
  wrapped.push(line.replace(/,$/, ''));
}
sql = sql.replace(/\ncommit;\s*$/, `
-- Panels, the twelve thin families: 126 of the 186 new rows carry one, 60 are
-- null by design. Counted by name for the same reason as the check above — these
-- rows land in nine categories that already hold 400 rows between them.
select count(*)                                          as broad_rows,
       count(*) filter (where nutrition_source = 'usda') as usda_panels,
       count(*) filter (where nutrition is null)         as no_panel
  from catalog_items
 where lower(name) = any (array[
${wrapped.join('\n')}
 ]::text[]);

commit;
`);

writeFileSync(APPLY, sql);
console.log('apply header/counts updated');
