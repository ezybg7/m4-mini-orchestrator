import { BROAD_SHELF, THIN_SHELF_EXTRA } from './roster.mjs';
const THIN_SHELF = {
  frozenPotato: { freezer: 365 },
  leanFish: { fridge: 2, freezer: 180 },
  ...THIN_SHELF_EXTRA,
};
export const SHELF = { ...THIN_SHELF, ...BROAD_SHELF };
const sqlStr = (s) => `'${s.replace(/'/g, "''")}'`;
const sqlArr = (a) => (a.length === 0 ? `'{}'` : `'{${a.map((x) => `"${x.replace(/(["\\])/g, '\\$1')}"`).join(', ')}}'`);
const shelfJson = (o) => `'{${Object.entries(o).map(([k, v]) => `"${k}": ${v}`).join(', ')}}'`;
export const rowLine = (name, aliases, category, shelfKey) =>
  `  (${sqlStr(name)}, ${sqlArr(aliases)}, '${category}', ${shelfJson(SHELF[shelfKey])})`;
