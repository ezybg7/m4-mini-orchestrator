import { readFileSync } from 'node:fs';
const SQL = readFileSync('/Users/orchestrator/agents/usda/usda-foods-seed.sql', 'utf8');
const RE = /^\s*\((\d+), '((?:[^']|'')*)', '(\w+)', '(\{.*?\})'::jsonb\)/gm;
export const foods = [];
for (const m of SQL.matchAll(RE)) {
  foods.push({ id: Number(m[1]), desc: m[2].replace(/''/g, "'"), type: m[3], n: m[4] });
}
export function find(...terms) {
  const t = terms.map((x) => x.toLowerCase());
  return foods.filter((f) => t.every((x) => f.desc.toLowerCase().includes(x)));
}
export function show(...terms) {
  const r = find(...terms);
  console.log(`-- ${terms.join(' + ')} : ${r.length}`);
  for (const f of r.slice(0, 40)) console.log(`  [${f.id}] (${f.type}) ${f.desc}\n      ${f.n}`);
  if (r.length > 40) console.log(`  ... ${r.length - 40} more`);
}
