// Readiness check (2026-09-06): as the seeded test account on PRODUCTION, add one
// free-text food the catalog lacks, call the Worker's estimate-shelf-life route
// (real Haiku call), read the answer, delete the inventory row. Prints statuses and
// counts only — never tokens or cookies.
import fs from 'node:fs';
const parse = (p) => Object.fromEntries(fs.readFileSync(p, 'utf8').split('\n').filter(l => /^[A-Z_]+=/.test(l)).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^'|'$/g, '')]; }));
const env = { ...parse(`${process.env.HOME}/agents/.env.acceptance`), ...parse('/Users/orchestrator/code/pantry/.env') };
const AUTH = env.EXPO_PUBLIC_AUTH_URL, WORKER = env.EXPO_PUBLIC_WORKER_URL, DATA = env.EXPO_PUBLIC_DATA_API_URL, ORIGIN = new URL(WORKER).origin;
const FOOD = process.argv[2] ?? 'Quince';
const res = await fetch(`${AUTH}/sign-in/email`, { method: 'POST', headers: { 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD }) });
const signin = await res.json().catch(() => ({})); console.log('sign-in', res.status);
if (!res.ok) process.exit(1);
const cookie = (res.headers.getSetCookie?.() ?? []).map(c => c.split(';')[0]).join('; ');
const authHeaders = { Origin: ORIGIN, Cookie: cookie, Authorization: `Bearer ${signin?.token ?? ''}` };
let jwt = (await fetch(`${AUTH}/get-session`, { headers: authHeaders })).headers.get('set-auth-jwt');
if (!jwt) { const t = await fetch(`${AUTH}/token`, { headers: authHeaders }); jwt = (await t.json().catch(() => ({})))?.token ?? t.headers.get('set-auth-jwt'); }
console.log('jwt minted', jwt ? 'yes' : 'NO'); if (!jwt) process.exit(1);
const api = (path, init = {}) => fetch(`${DATA}${path}`, { ...init, headers: { Authorization: `Bearer ${jwt}`, 'content-type': 'application/json', ...(init.headers ?? {}) } });
const hh = await (await api('/households?select=id,name')).json(); console.log('households', Array.isArray(hh) ? hh.length : hh);
const household = hh[0].id;
const locs = await (await api(`/storage_locations?select=id,name,kind&household_id=eq.${household}&limit=1`)).json(); console.log('location', locs[0]?.name, locs[0]?.kind);
const ins = await api('/inventory_items', { method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify({ household_id: household, location_id: locs[0].id, name_override: FOOD, category: 'produce' }) });
const row = (await ins.json().catch(() => []))[0]; console.log('insert', ins.status, row?.id ? 'row ok' : 'no row');
if (!row?.id) process.exit(1);
const t0 = Date.now();
const est = await fetch(`${WORKER}/estimate-shelf-life`, { method: 'POST', headers: { Authorization: `Bearer ${jwt}`, 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ household_id: household, timezone: 'America/New_York' }) });
console.log('estimate-shelf-life', est.status, JSON.stringify(await est.json().catch(() => ({}))), `${Date.now() - t0}ms`);
const after = await (await api(`/inventory_items?select=id,name_override,catalog_item_id,expires_at,expiry_source&id=eq.${row.id}`)).json(); console.log('row after', JSON.stringify(after[0] ?? null).replace(/"[0-9a-f-]{36}"/g, '"…"'));
const del = await api(`/inventory_items?id=eq.${row.id}`, { method: 'DELETE' }); console.log('cleanup delete', del.status);
