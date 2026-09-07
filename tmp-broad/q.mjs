import { find } from './usda.mjs';
export function q(label, ...terms) {
  const r = find(...terms);
  const line = r.slice(0, 14).map((f) => `[${f.id}]${f.type === 'foundation' ? '*F' : f.type === 'survey_fndds' ? '~s' : ''} ${f.desc} (${JSON.parse(f.n).kcal})`);
  console.log(`## ${label} <${terms.join('+')}> n=${r.length}`);
  for (const l of line) console.log('   ' + l);
  if (r.length > 14) console.log(`   ... +${r.length - 14}`);
}
