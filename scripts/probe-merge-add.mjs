// Reproduce the client's merge_add_items call against a Neon branch Data API. Prints status + body only; never the tokens.
import fs from 'node:fs';
const env = Object.fromEntries(fs.readFileSync(`${process.env.HOME}/agents/.env.acceptance`, 'utf8').split('\n').filter(l => l.includes('=')).map(l => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^'|'$/g, '')]; }));
const AUTH = 'https://pantry-api.everettzyan.workers.dev/auth';
const ORIGIN = new URL(AUTH).origin;
const DATA = process.env.DATA_API_URL ?? env.ACCEPTANCE_BRANCH_URL;
const res = await fetch(`${AUTH}/sign-in/email`, { method: 'POST', headers: { 'content-type': 'application/json', Origin: ORIGIN }, body: JSON.stringify({ email: env.TEST_EMAIL, password: env.TEST_PASSWORD }) });
const body = await res.json().catch(() => ({}));
if (!res.ok) { console.log('sign-in failed', res.status); process.exit(1); }
const cookie = (res.headers.getSetCookie?.() ?? []).map(c => c.split(';')[0]).join('; ');
const headers = { Origin: ORIGIN, Cookie: cookie, Authorization: `Bearer ${body?.token ?? ''}` };
let jwt = (await fetch(`${AUTH}/get-session`, { headers })).headers.get('set-auth-jwt');
if (!jwt) { const t = await fetch(`${AUTH}/token`, { headers }); const tb = await t.json().catch(() => ({})); jwt = tb?.token ?? t.headers.get('set-auth-jwt'); }
if (!jwt) { console.log('no jwt'); process.exit(1); }
console.log('jwt minted (len', jwt.length, ')');
const rpc = process.env.RPC ?? 'merge_add_items';
const payload = JSON.parse(process.argv[2]);
const r = await fetch(`${DATA}/rpc/${rpc}`, { method: 'POST', headers: { Authorization: `Bearer ${jwt}`, 'content-type': 'application/json', Accept: 'application/json' }, body: JSON.stringify(payload) });
console.log('rpc', rpc, 'status', r.status); console.log((await r.text()).slice(0, 800));
