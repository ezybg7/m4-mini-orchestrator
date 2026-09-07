import { readFileSync, writeFileSync } from 'node:fs';
import { A_ROWS, B_ROWS } from './roster.mjs';
import { A_PANELS, B_PANELS } from './panels.mjs';
import { foods } from './usda.mjs';
import { SHELF, rowLine } from './gen-seed-lib.mjs';

const APPLY = '/Users/orchestrator/agents/worktrees/broad/db/apply/catalog-extension-2026-09.sql';
const byId = new Map(foods.map((f) => [f.id, f]));
let sql = readFileSync(APPLY, 'utf8');

const CAT_ORDER = ['produce', 'dairy_eggs', 'meat_seafood', 'grains_pasta', 'baking', 'canned', 'condiments_oils', 'snacks', 'other'];

function panelStatement(name, id, reason) {
  const f = byId.get(id);
  if (!f) throw new Error('no fdc ' + id);
  const head = `-- ${name} -> ${f.desc} [fdc_id ${id}]${reason ? ' — ' + reason : ''}`;
  return `${head}\nupdate catalog_items set\n  nutrition = '${f.n}'::jsonb,\n  nutrition_source = 'usda'\n where lower(name) = lower('${name.replace(/'/g, "''")}')\n   and nutrition is null\n   and cardinality(barcodes) = 0\n   and source = 'seed';`;
}

// ---------------------------------------------------------------- (d) + (f)
// the seven thin rows and their six panels
{
  const tots = A_ROWS.find((r) => r[0] === 'Tater tots');
  const anchorD = "  ('Frozen strawberries', '{\"strawberries frozen\", \"frozen sliced strawberries\"}', 'produce', '{\"freezer\": 420}'),";
  if (!sql.includes(anchorD)) throw new Error('(d) produce anchor missing');
  sql = sql.replace(anchorD, anchorD + '\n' + rowLine(tots[0], tots[1], tots[2], tots[3]) + ',');

  // meat_seafood group of (d): merge the six in, sorted
  const first = "  ('Catfish', ";
  const last = "  ('Trout', '{\"rainbow trout\", \"trout fillets\", \"steelhead\"}', 'meat_seafood', '{\"fridge\": 2, \"freezer\": 90}'),";
  const from = sql.indexOf(first, sql.indexOf('-- (d) new rows'));
  const to = sql.indexOf(last, from) + last.length;
  if (from === -1 || to < from) throw new Error('(d) meat group missing');
  const merged = [
    ...sql.slice(from, to).split('\n').map((l) => ({ name: /^ {2}\('((?:[^']|'')*)'/.exec(l)[1].replace(/''/g, "'"), line: l.replace(/,$/, '') })),
    ...A_ROWS.filter((r) => r[2] === 'meat_seafood').map((r) => ({ name: r[0], line: rowLine(r[0], r[1], r[2], r[3]) })),
  ].sort((a, b) => a.name.localeCompare(b.name));
  sql = sql.slice(0, from) + merged.map((m) => m.line).join(',\n') + ',' + sql.slice(to);
}

// (f): rebuild the section, keeping its family order and sorting within
{
  const head = '-- (f) USDA panels for the thin-category rows that have one ------------------\n\n';
  const from = sql.indexOf(head);
  const to = sql.indexOf('\n-- (g) count check');
  if (from === -1 || to < from) throw new Error('(f) section missing');
  const body = sql.slice(from + head.length, to);
  const existing = body.trim().split('\n\n').map((stmt) => ({
    name: /^-- (.+?) -> /.exec(stmt)[1],
    stmt,
  }));
  const thinCat = new Map([
    ...existing.map((e) => [e.name, null]),
  ]);
  // categories: read them out of the (d) section
  const dSection = sql.slice(sql.indexOf('-- (d) new rows'), sql.indexOf('-- (e) alias growth'));
  for (const m of dSection.matchAll(/^ {2}\('((?:[^']|'')*)', '\{.*?\}', '(\w+)'/gm)) {
    thinCat.set(m[1].replace(/''/g, "'"), m[2]);
  }
  const added = Object.entries(A_PANELS).map(([name, [id, reason]]) => ({ name, stmt: panelStatement(name, id, reason) }));
  const all = [...existing, ...added];
  const ORDER = ['dairy_eggs', 'produce', 'meat_seafood', 'canned', 'beverages'];
  all.sort((a, b) => ORDER.indexOf(thinCat.get(a.name)) - ORDER.indexOf(thinCat.get(b.name)) || a.name.localeCompare(b.name));
  sql = sql.slice(0, from + head.length) + all.map((x) => x.stmt).join('\n\n') + '\n' + sql.slice(to);
}

// ---------------------------------------------------------------- (g)(h)(i)
const gRows = (() => {
  const lines = ['-- (g) new rows, the twelve thin families --------------------------------------', '',
    'insert into catalog_items (name, aliases, category, shelf_life) values'];
  const parts = [];
  for (const cat of CAT_ORDER) {
    const rows = B_ROWS.filter((r) => r[2] === cat).sort((a, b) => a[0].localeCompare(b[0]));
    if (rows.length === 0) continue;
    parts.push(`  -- ${cat} (${rows.length})`);
    for (const r of rows) parts.push(rowLine(r[0], r[1], r[2], r[3]) + ',');
  }
  parts[parts.length - 1] = parts[parts.length - 1].replace(/,$/, '');
  return lines.concat(parts, ['on conflict do nothing;']).join('\n');
})();

const SEED_GROWTH = [
  ['Pasta', ['elbow pasta'], true, '§Families\' "Macaroni (alias elbow pasta)": the row already answers macaroni, spaghetti and penne'],
  ['Breadcrumbs', ['bread crumbs'], true, '§Bakery\'s "Bread crumbs (alias only if the row exists)" — it does, but the two-word spelling did not resolve'],
  ['Active dry yeast', ['instant yeast'], true, '§Baking\'s "Active dry yeast (alias instant yeast)"'],
];
const APPLY_ONLY_GROWTH = [
  ['Green onions', ['scallions'], '§Produce\'s "Scallions (alias green onions)" — the row exists and the amendment gives scallions no shelf life of its own'],
  ['Barbecue sauce', ['bbq sauce', 'bbq'], '§Condiments\' "BBQ sauce" — Barbecue sauce is the row'],
  ['Walnuts', ['chopped walnuts'], '§Baking\'s "Chopped walnuts (alias only)"'],
  ['Pumpkin seeds', ['pepitas'], '§Snacks\' "Pumpkin seeds (alias pepitas)"'],
  ['Veggie burgers', ['plant-based burger'], '§International\'s "Plant-based burger (alias veggie burger)" — Veggie burgers already answers "veggie burger" by name. This row already carries FoodKeeper\'s six keyword aliases, so it ends at seven, deliberately over spec 13\'s cap for the reason the (b) note gives'],
];

function aliasUpdate(name, aliases, note) {
  return `-- ${name} — ${note}\nupdate catalog_items\n   set aliases = aliases || array(select a from unnest(array[${aliases.map((a) => `'${a.replace(/'/g, "''")}'`).join(', ')}]::text[]) a\n                                   where a <> all(aliases))\n where lower(name) = lower('${name.replace(/'/g, "''")}')\n   and source = 'seed';`;
}

const hAliases = [
  '-- (h) alias growth for the existing rows the broad families name --------------',
  '',
  '-- Hand-tuned rows: these updates and supabase/seed.sql agree exactly.',
  '',
  ...SEED_GROWTH.map(([n, a, , note]) => aliasUpdate(n, a, note + ' (hand-tuned row)') + '\n'),
  '-- Generated rows: seed.sql\'s generated block is rewritten from',
  '-- scripts/data/catalog-rows.json by scripts/build-catalog-seed.mjs, so these',
  '-- aliases exist HERE ONLY — the same situation as (b) and (e).',
  '',
  ...APPLY_ONLY_GROWTH.map(([n, a, note]) => aliasUpdate(n, a, note + ' (generated row)') + '\n'),
].join('\n').trimEnd();

const iPanels = (() => {
  const rows = B_ROWS.map((r) => r[0]).filter((n) => n in B_PANELS);
  const catOf = new Map(B_ROWS.map((r) => [r[0], r[2]]));
  rows.sort((a, b) => CAT_ORDER.indexOf(catOf.get(a)) - CAT_ORDER.indexOf(catOf.get(b)) || a.localeCompare(b));
  return ['-- (i) USDA panels for the broad-extension rows that have one ------------------', '',
    ...rows.map((n) => panelStatement(n, B_PANELS[n][0], B_PANELS[n][1]) + '\n')].join('\n').trimEnd();
})();

// ---------------------------------------------------------------- assemble
{
  const i = sql.indexOf('-- (g) count check');
  if (i === -1) throw new Error('count check missing');
  sql = sql.slice(0, i) + gRows + '\n\n' + hAliases + '\n\n' + iPanels + '\n\n' + sql.slice(i).replace('-- (g) count check', '-- (j) count check');
}

writeFileSync(APPLY, sql);
console.log('apply written');
