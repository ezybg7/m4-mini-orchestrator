// Replays the app's request mix around an item-screen delete against the branch
// Data API and counts refused ledger inserts. WRITES NOTHING: every POST carries
// outcome='probe', which fails the CHECK constraint (400) only AFTER the RLS
// WITH CHECK passed; a 403 is RLS/privilege refusing the row. DELETEs target a
// random uuid (0 rows). Prints statuses and body prefixes only — never tokens.
import fs from 'node:fs';
const env = Object.fromEntries(fs.readFileSync(`${process.env.HOME}/agents/.env.acceptance`, 'utf8').split('\n').filter(l => l.includes('=')).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^'|'$/g, '')]; }));
const AUTH = 'https://pantry-api.everettzyan.workers.dev/auth';
const ORIGIN = new URL(AUTH).origin;
const DATA = env.ACCEPTANCE_BRANCH_URL;
const N = Number(process.env.N ?? 25);

const res = await fetch(`${AUTH}/sign-in/email`, { method: 'POST', headers: { 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD }) });
const signin = await res.json().catch(() => ({}));
if (!res.ok) { console.log('sign-in failed', res.status); process.exit(1); }
const cookie = (res.headers.getSetCookie?.() ?? []).map(c => c.split(';')[0]).join('; ');
const authHeaders = { Origin: ORIGIN, Cookie: cookie, Authorization: `Bearer ${signin?.token ?? ''}` };
async function mint() {
  const r = await fetch(`${AUTH}/get-session`, { headers: authHeaders });
  let jwt = r.headers.get('set-auth-jwt');
  if (!jwt) { const t = await fetch(`${AUTH}/token`, { headers: authHeaders }); const tb = await t.json().catch(() => ({})); jwt = tb?.token ?? t.headers.get('set-auth-jwt'); }
  return jwt;
}
const claimsOf = (jwt) => JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());
const jwtA = await mint();
if (!jwt_ok(jwtA)) process.exit(1);
function jwt_ok(j) { if (!j) { console.log('no jwt'); return false; } return true; }
const cA = claimsOf(jwtA);
console.log('jwt A: claim keys', Object.keys(cA).join(','), '| role', cA.role ?? '(none)', '| ttl s', cA.exp - cA.iat, '| jti', cA.jti ? typeof cA.jti : '(none)');

const hdr = (jwt, extra = {}) => ({ Authorization: `Bearer ${jwt}`, Accept: 'application/json', ...extra });
const hm = await fetch(`${DATA}/household_members?select=household_id`, { headers: hdr(jwtA) });
const hmRows = await hm.json().catch(() => []);
const HH = process.env.HOUSEHOLD ?? hmRows?.[0]?.household_id;
console.log('household_members GET', hm.status, 'rows', Array.isArray(hmRows) ? hmRows.length : '?', '| HH', HH ? HH.slice(0, 8) + '…' : '(none)');
if (!HH) process.exit(1);

const row = (hh) => [{ household_id: hh, name: 'probe', category: 'dairy_eggs', catalog_item_id: null, outcome: 'probe', days_kept: 0 }];
async function post(jwt, hh = HH) {
  const r = await fetch(`${DATA}/food_outcomes`, { method: 'POST', headers: hdr(jwt, { 'content-type': 'application/json' }), body: JSON.stringify(row(hh)) });
  return { status: r.status, body: (await r.text()).slice(0, 160) };
}
const uuid = () => crypto.randomUUID();
const ITEM_SELECT = '*,catalog_item:catalog_items(id,name,shelf_life,nutrition,nutrition_source,image_url)';
const gets = (jwt) => [
  fetch(`${DATA}/inventory_items?select=${encodeURIComponent(ITEM_SELECT)}&household_id=eq.${HH}&order=expires_at.asc.nullslast&limit=500`, { headers: hdr(jwt) }),
  fetch(`${DATA}/inventory_items?select=${encodeURIComponent(ITEM_SELECT)}&id=eq.${uuid()}`, { headers: hdr(jwt, { Accept: 'application/vnd.pgrst.object+json' }) }),
  fetch(`${DATA}/inventory_items?select=${encodeURIComponent(ITEM_SELECT + ',location:storage_locations(id,name)')}&household_id=eq.${HH}&status=neq.out&expires_at=not.is.null&order=expires_at.asc&limit=500`, { headers: hdr(jwt) }),
  fetch(`${DATA}/inventory_items?select=location_id,catalog_item_id,name_override,status&household_id=eq.${HH}&limit=2000`, { headers: hdr(jwt) }),
];

const tally = {};
const bump = (k, s) => { tally[k] ??= {}; tally[k][s] = (tally[k][s] ?? 0) + 1; };

console.log(`\n== phase 1: sequential control POST x3`);
for (let i = 0; i < 3; i++) { const p = await post(jwtA); bump('p1.post', p.status); if (p.status !== 400) console.log('  UNEXPECTED', p.status, p.body); }
const foreign = await post(jwtA, '00000000-0000-0000-0000-000000000001'); console.log('  foreign-household control', foreign.status, foreign.body);

console.log(`\n== phase 2: app mix x${N} — DELETE(0 rows) then 4 GET + POST concurrently`);
for (let i = 0; i < N; i++) {
  const d = await fetch(`${DATA}/inventory_items?id=eq.${uuid()}`, { method: 'DELETE', headers: hdr(jwtA) });
  bump('p2.delete', d.status);
  const t0 = Date.now();
  const [g1, g2, g3, g4, p] = await Promise.all([...gets(jwtA), post(jwtA)]);
  for (const [k, g] of [['p2.get.items', g1], ['p2.get.single', g2], ['p2.get.expiring', g3], ['p2.get.counts', g4]]) bump(k, g.status);
  bump('p2.post', p.status);
  if (p.status !== 400) console.log(`  iter ${i}: POST ${p.status} after ${Date.now() - t0} ms:`, p.body);
  if (g1.status !== 200) console.log(`  iter ${i}: items GET ${g1.status}`, (await g1.text()).slice(0, 120));
}

console.log(`\n== phase 3: freshly minted token used immediately x5`);
const fresh = [];
for (let i = 0; i < 5; i++) {
  const j = await mint(); if (!j) { console.log('  mint failed'); break; }
  fresh.push(j);
  const c = claimsOf(j);
  const p = await post(j); bump('p3.post', p.status);
  console.log(`  mint#${i} iat delta vs local ${Math.round(Date.now() / 1000 - c.iat)} s → POST ${p.status}${p.status !== 400 ? ' ' + p.body : ''}`);
  await new Promise(r => setTimeout(r, 1200));
}

console.log(`\n== phase 4: old token A and newest token interleaved concurrently x${Math.min(N, 12)} rounds of 6`);
const jwtB = fresh.at(-1) ?? await mint();
for (let i = 0; i < Math.min(N, 12); i++) {
  const results = await Promise.all([post(jwtA), post(jwtB), post(jwtA), post(jwtB), post(jwtA), post(jwtB)]);
  results.forEach((p, k) => { bump(`p4.post.${k % 2 ? 'B' : 'A'}`, p.status); if (p.status !== 400) console.log(`  round ${i} slot ${k} (${k % 2 ? 'B' : 'A'}) → ${p.status}`, p.body); });
}

console.log('\n== tally'); for (const [k, v] of Object.entries(tally)) console.log(' ', k.padEnd(18), JSON.stringify(v));
