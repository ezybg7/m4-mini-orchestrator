import { find } from './usda.mjs';
export function q(label, ...terms) {
  const r = find(...terms);
  console.log(`## ${label} <${terms.join('+')}> n=${r.length}`);
  for (const f of r.slice(0, 10)) console.log(`   [${f.id}]${f.type === 'foundation' ? '*F' : f.type === 'survey_fndds' ? '~s' : ''} ${f.desc} (${JSON.parse(f.n).kcal})`);
  if (r.length > 10) console.log(`   ... +${r.length - 10}`);
}
