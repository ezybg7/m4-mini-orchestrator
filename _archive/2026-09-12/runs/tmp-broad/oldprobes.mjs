import { readFileSync } from 'node:fs';
const T = readFileSync('/Users/orchestrator/agents/worktrees/broad/tests/catalog-seed-extension.test.ts', 'utf8');
function grab(name) {
  const start = T.indexOf(`const ${name}: [string, string][] = [`);
  if (start === -1) throw new Error('missing ' + name);
  const from = T.indexOf('[', start + `const ${name}: [string, string][] = `.length - 1);
  const end = T.indexOf('\n];', from);
  const body = T.slice(from, end);
  const out = [];
  for (const m of body.matchAll(/^\s*\['((?:[^']|\\')*)', '((?:[^']|\\')*)'\],?\s*$/gm)) {
    out.push([m[1].replace(/\\'/g, "'"), m[2].replace(/\\'/g, "'")]);
  }
  return out;
}
export const SOURCES_2 = grab('SOURCES_2');
export const PROBES = grab('PROBES');
export const FAMILIES = grab('FAMILIES');
export const THIN_PROBES = grab('THIN_PROBES');
export const APPLIED_PROBES = grab('APPLIED_PROBES');
