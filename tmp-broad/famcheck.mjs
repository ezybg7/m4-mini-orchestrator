import * as m from './match.mjs';
import { seedRows, handNames } from './parse-seed.mjs';
const catalog = seedRows.map((r) => ({ id: r.name, name: r.name, aliases: r.aliases }));
const norm = (s) => s.replace(/\s+/g,' ').trim().toLowerCase();
const names = new Set(seedRows.map(r=>norm(r.name)));
export function check(list, label) {
  console.log('== ' + label);
  for (const item of list) {
    const exists = names.has(norm(item));
    const r = m.matchCatalog(item, catalog);
    const row = seedRows.find(x=>norm(x.name)===norm(r.match?.name||''));
    console.log(
      (exists ? 'ROW ' : '    ') + item.padEnd(30),
      '->', (r.match ? r.match.name : '(none)').padEnd(28),
      row ? row.category : '');
  }
  console.log();
}
