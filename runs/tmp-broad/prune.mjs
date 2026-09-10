import { readFileSync } from 'node:fs';
import { seedRows, handNames } from './parse-seed.mjs';
const norm = (s) => s.replace(/\s+/g, ' ').trim().toLowerCase().normalize('NFC');
const { rows } = JSON.parse(readFileSync('/Users/orchestrator/agents/worktrees/broad/scripts/data/catalog-rows.json', 'utf8'));
const handSet = new Set([...handNames].map(norm));
const GENERIC = new Set(['can','jar','shell','fresh','whole','low','high']);
const ALIAS_FIXES = new Map([['avodaco oil','avocado oil']]);
/** returns {prunedNow:[...], prunedWithNew:[...]} */
export function simulate(newNames) {
  const run = (extra) => {
    const hs = new Set([...handSet, ...extra.map(norm)]);
    const kept = [];
    const seen = new Set();
    for (const row of rows) {
      const k = norm(row.name);
      if (hs.has(k)) continue;
      if (seen.has(k)) continue;
      seen.add(k);
      kept.push(row);
    }
    const canonical = new Set([...hs, ...kept.map((r) => norm(r.name))]);
    const pruned = [];
    const result = new Map();
    for (const row of kept) {
      const s = new Set();
      const out = [];
      for (let alias of row.aliases) {
        alias = ALIAS_FIXES.get(norm(alias)) ?? alias;
        const key = norm(alias);
        if (GENERIC.has(key) || canonical.has(key) || s.has(key)) { pruned.push(`${row.name}: ${alias}`); continue; }
        s.add(key); out.push(alias);
      }
      result.set(row.name, out);
    }
    return { pruned, kept: kept.map((r) => r.name), result };
  };
  const before = run([]);
  const after = run(newNames);
  const droppedRows = before.kept.filter((n) => !after.kept.includes(n));
  const newlyPruned = after.pruned.filter((p) => !before.pruned.includes(p));
  return { droppedRows, newlyPruned };
}
