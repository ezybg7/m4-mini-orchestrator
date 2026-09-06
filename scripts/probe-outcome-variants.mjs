// Same safety as probe-outcome-race.mjs (invalid outcome -> 400 after RLS; DELETEs hit a random uuid). MODE=mix|nodelete|postburst|seq, N rounds.
import fs from 'node:fs';
const env = Object.fromEntries(fs.readFileSync(`${process.env.HOME}/agents/.env.acceptance`, 'utf8').split('\n').filter(l => l.includes('=')).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^'|'$/g, '')]; }));
const AUTH = 'https://pantry-api.everettzyan.workers.dev/auth'; const ORIGIN = new URL(AUTH).origin; const DATA = env.ACCEPTANCE_BRANCH_URL;
const res = await fetch(`${AUTH}/sign-in/email`, { method: 'POST', headers: { 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD }) });
const signin = await res.json().catch(() => ({})); if (!res.ok) { console.log('sign-in failed', res.status); process.exit(1); }
const cookie = (res.headers.getSetCookie?.() ?? []).map(c => c.split(';')[0]).join('; ');
const ah = { Origin: ORIGIN, Cookie: cookie, Authorization: `Bearer ${signin?.token ?? ''}` };
let jwt = (await fetch(`${AUTH}/get-session`, { headers: ah })).headers.get('set-auth-jwt');
if (!jwt) { const t = await fetch(`${AUTH}/token`, { headers: ah }); jwt = (await t.json().catch(() => ({})))?.token; }
if (!jwt) { console.log('no jwt'); process.exit(1); }
const hdr = (extra = {}) => ({ Authorization: `Bearer ${jwt}`, Accept: 'application/json', ...extra });
const HH = (await (await fetch(`${DATA}/household_members?select=household_id`, { headers: hdr() })).json())[0].household_id;
const SEL = encodeURIComponent('*,catalog_item:catalog_items(id,name,shelf_life,nutrition,nutrition_source,image_url)');
const uuid = () => crypto.randomUUID();
const post = async () => { const r = await fetch(`${DATA}/food_outcomes`, { method: 'POST', headers: hdr({ 'content-type': 'application/json' }), body: JSON.stringify([{ household_id: HH, name: 'probe', category: 'dairy_eggs', catalog_item_id: null, outcome: 'probe', days_kept: 0 }]) }); return { kind: 'post', status: r.status, body: (await r.text()).slice(0, 120) }; };
const get = async (kind, url, accept) => { const r = await fetch(url, { headers: hdr(accept ? { Accept: accept } : {}) }); const txt = await r.text(); let n = null; try { const j = JSON.parse(txt); n = Array.isArray(j) ? j.length : (j && typeof j === 'object' ? 1 : 0); } catch {} return { kind, status: r.status, rows: n, body: txt.slice(0, 120) }; };
const gets = () => [
  get('items', `${DATA}/inventory_items?select=${SEL}&household_id=eq.${HH}&order=expires_at.asc.nullslast&limit=500`),
  get('single', `${DATA}/inventory_items?select=${SEL}&id=eq.${uuid()}`, 'application/vnd.pgrst.object+json'),
  get('expiring', `${DATA}/inventory_items?select=${SEL}&household_id=eq.${HH}&status=neq.out&limit=500`),
  get('counts', `${DATA}/inventory_items?select=location_id,catalog_item_id,name_override,status&household_id=eq.${HH}&limit=2000`),
  get('locations', `${DATA}/storage_locations?select=*&household_id=eq.${HH}`),
];
const del = async () => { const r = await fetch(`${DATA}/inventory_items?id=eq.${uuid()}`, { method: 'DELETE', headers: hdr() }); return { kind: 'delete', status: r.status }; };
const MODE = process.env.MODE ?? 'mix'; const N = Number(process.env.N ?? 40);
const tally = {}; const bump = (k) => { tally[k] = (tally[k] ?? 0) + 1; };
let baselineRows = null; const anomalies = [];
for (let i = 0; i < N; i++) {
  let results;
  if (MODE === 'mix') { const d = await del(); bump(`delete.${d.status}`); results = await Promise.all([...gets(), post()]); }
  else if (MODE === 'nodelete') { results = await Promise.all([...gets(), post()]); }
  else if (MODE === 'postburst') { results = await Promise.all([post(), post(), post(), post(), post(), post()]); }
  else if (MODE === 'seq') { const d = await del(); bump(`delete.${d.status}`); results = [await post()]; }
  else if (MODE === 'getsonly') { results = await Promise.all(gets()); }
  for (const r of results) {
    bump(`${r.kind}.${r.status}`);
    if (r.kind === 'post' && r.status !== 400) anomalies.push(`round ${i}: POST ${r.status} ${r.body}`);
    if (r.kind === 'items' || r.kind === 'counts' || r.kind === 'locations' || r.kind === 'expiring') {
      const key = `${r.kind}.rows`; baselineRows ??= {}; baselineRows[key] ??= r.rows;
      if (r.rows !== baselineRows[key]) anomalies.push(`round ${i}: ${r.kind} returned ${r.rows} rows (baseline ${baselineRows[key]}) status ${r.status}`);
    }
  }
}
console.log(`MODE=${MODE} N=${N} baseline rows`, JSON.stringify(baselineRows));
console.log('tally', JSON.stringify(tally));
console.log(anomalies.length ? anomalies.join('\n') : 'no anomalies');
