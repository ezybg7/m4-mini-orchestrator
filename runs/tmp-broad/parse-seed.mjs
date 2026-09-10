import { readFileSync } from 'node:fs';
const SEED = readFileSync('/Users/orchestrator/agents/worktrees/broad/supabase/seed.sql', 'utf8');
const ROW = /^ {2}\('((?:[^']|'')*)', '\{(.*?)\}', '(\w+)', '(\{.*?\})'\)/gm;
export function parseRows(sql) {
  const rows = [];
  for (const m of sql.matchAll(ROW)) {
    rows.push({
      name: m[1].replace(/''/g, "'"),
      aliases: [...m[2].matchAll(/"([^"]*)"/g)].map((a) => a[1]),
      category: m[3],
      shelf: JSON.parse(m[4]),
    });
  }
  return rows;
}
export const seedRows = parseRows(SEED);
export const handBlock = SEED.slice(SEED.indexOf('-- BEGIN hand-tuned catalog'), SEED.indexOf('-- END hand-tuned catalog'));
export const handNames = new Set([...handBlock.matchAll(/^\s*\('((?:[^']|'')+)'/gm)].map((m) => m[1].replace(/''/g, "'")));
