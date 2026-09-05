// Reproduce the client's merge_add_items call against a Neon branch Data API. Prints status + body only; never the tokens.
import fs from 'node:fs';
const env = Object.fromEntries(fs.readFileSync(`${process.env.HOME}/agents/.env.acceptance`, 'utf8').split('\n').filter(l => l.includes('=')).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^'|'$/g, '')]; }));
const AUTH = 'https://pantry-api.everettzyan.workers.dev/auth';
const ORIGIN = new URL(AUTH).origin;
const DATA = process.env.DATA_API_URL ?? env.ACCEPTANCE_BRANCH_URL;
// Probe: does a food_outcomes INSERT pass RLS for the seeded account on this Data API?
// SAFE BY CONSTRUCTION: `outcome` is deliberately invalid ('probe'), so Postgres
// evaluates the RLS WITH CHECK first (403 if it fails) and then the CHECK
// constraint rejects the row (400) — nothing can ever be written.
const res = await fetch(`${AUTH}/sign-in/email`, { method: 'POST', headers: { 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD }) });
const body = await res.json().catch(() => ({}));
if (!res.ok) { console.log('sign-in failed', res.status); process.exit(1); }
const cookie = (res.headers.getSetCookie?.() ?? []).map(c => c.split(';')[0]).join('; ');
const headers = { Origin: ORIGIN, Cookie: cookie, Authorization: `Bearer ${body?.token ?? ''}` };
let jwt = (await fetch(`${AUTH}/get-session`, { headers })).headers.get('set-auth-jwt');
if (!jwt) { const t = await fetch(`${AUTH}/token`, { headers }); const tb = await t.json().catch(() => ({})); jwt = tb?.token ?? t.headers.get('set-auth-jwt'); }
if (!jwt) { console.log('no jwt'); process.exit(1); }
const claims = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());
console.log('jwt minted (len', jwt.length, ') claims keys:', Object.keys(claims).join(','), 'role:', claims.role ?? '(none)', 'ttl s:', claims.exp - claims.iat);
const HH = process.env.HOUSEHOLD ?? 'e99fb3f2-a791-4cac-a9eb-5141098d322f';
const row = (hh, outcome) => [{ household_id: hh, name: 'probe', category: 'dairy_eggs', catalog_item_id: null, outcome, days_kept: 0 }];
async function post(label, rows, extra = {}) {
  const r = await fetch(`${DATA}/food_outcomes`, { method: 'POST', headers: { Authorization: `Bearer ${jwt}`, 'content-type': 'application/json', Accept: 'application/json', Prefer: 'return=minimal', ...extra }, body: JSON.stringify(rows) });
  console.log(label, 'status', r.status, (await r.text()).slice(0, 300));
}
const n = Number(process.env.N ?? 3);
for (let i = 1; i <= n; i++) await post(`insert#${i} (invalid outcome, own household)`, row(HH, 'probe'));
await post('control (invalid outcome, foreign household)', row('00000000-0000-0000-0000-000000000001', 'probe'));
const g = await fetch(`${DATA}/food_outcomes?select=id&limit=1`, { headers: { Authorization: `Bearer ${jwt}` } });
console.log('select status', g.status);
