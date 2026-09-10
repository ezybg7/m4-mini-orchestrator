import * as m from './match.mjs';
import { seedRows } from './parse-seed.mjs';
import { A_ROWS, B_ROWS } from './roster.mjs';
const norm = (s) => s.replace(/\s+/g, ' ').trim().toLowerCase();
// seed rows + new rows, minus the aliases the builder will prune off generated rows
const PRUNE = { 'Beef roast':['brisket'], 'Smoked sausage':['kielbasa'], 'White fish':['cod','haddock','halibut'],
  'Shucked shellfish':['mussels','oysters','clams'], 'Live shellfish':['mussels','oysters','clams'],
  'Cherries (sweet)':['lychee'], 'Mango':['Papaya'], 'Stone fruit':['nectarines'],
  'French fries':['tater tots'], 'Dried fruit':['raisins'] };
// hand-row alias growth this pass adds in the SEED
export const SEED_ALIAS_GROWTH = {
  Pasta: ['elbow pasta'],
  Breadcrumbs: ['bread crumbs'],
  'Active dry yeast': ['instant yeast'],
};
// generated-row alias growth that can only live in the APPLY file
export const APPLY_ALIAS_GROWTH = {
  'Green onions': ['scallions'],
  'Barbecue sauce': ['bbq sauce', 'bbq'],
  Walnuts: ['chopped walnuts'],
  'Pumpkin seeds': ['pepitas'],
  'Veggie burgers': ['plant-based burger', 'plant based patty'],
};
export const rows = seedRows.map((r) => {
  const drop = (PRUNE[r.name] ?? []).map(norm);
  const grow = SEED_ALIAS_GROWTH[r.name] ?? [];
  return { ...r, aliases: [...r.aliases.filter((a) => !drop.includes(norm(a))), ...grow] };
}).concat(
  [...A_ROWS.map((r) => ({ name: r[0], aliases: r[1], category: r[2] })),
   ...B_ROWS.map((r) => ({ name: r[0], aliases: r[1], category: r[2] }))],
);
export const catalog = rows.map((r) => ({ id: r.name, name: r.name, aliases: r.aliases }));
export const appliedCatalog = rows.map((r) => ({
  id: r.name, name: r.name,
  aliases: [...r.aliases, ...(APPLY_ALIAS_GROWTH[r.name] ?? [])],
}));
export function probe(list, cat = catalog) {
  let bad = 0;
  for (const [q, want] of list) {
    const got = m.matchCatalog(q, cat).match?.name ?? '(none)';
    if (got !== want) { console.log('  MISMATCH', JSON.stringify(q), 'want', want, 'got', got); bad += 1; }
  }
  console.log(`  ${list.length - bad}/${list.length} ok`);
  return bad;
}

import { readFileSync } from 'node:fs';
const APPLY = readFileSync('/Users/orchestrator/agents/worktrees/broad/db/apply/catalog-extension-2026-09.sql', 'utf8');
export const EXISTING_APPLY_ALIASES = [...APPLY.matchAll(
  /set aliases = aliases \|\| array\(select a from unnest\(array\[(.*?)\]::text\[\]\) a\n\s*where a <> all\(aliases\)\)\n\s*where lower\(name\) = lower\('((?:[^']|'')*)'\)/g,
)].map((m) => [m[2].replace(/''/g, "'"), [...m[1].matchAll(/'((?:[^']|'')*)'/g)].map((a) => a[1].replace(/''/g, "'"))]);
const addMap = new Map();
for (const [n, al] of EXISTING_APPLY_ALIASES) addMap.set(norm(n), al);
for (const [n, al] of Object.entries(APPLY_ALIAS_GROWTH)) addMap.set(norm(n), [...(addMap.get(norm(n)) ?? []), ...al]);
export const appliedCatalog2 = rows.map((r) => ({
  id: r.name, name: r.name,
  aliases: [...r.aliases, ...(addMap.get(norm(r.name)) ?? []).filter((a) => !r.aliases.includes(a))],
}));
