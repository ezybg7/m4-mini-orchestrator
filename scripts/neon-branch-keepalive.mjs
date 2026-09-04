#!/usr/bin/env node
// neon-branch-keepalive.mjs — keep a disposable Neon branch's compute warm while
// the Maestro acceptance suite runs (docs/ACCEPTANCE_TESTS.md, work bucket 3).
//
// Why: a cold branch read exceeds the app's 12 s DB_TIMEOUT and hangs the add-item
// flow. An UNauthenticated 400 only wakes PostgREST, not Postgres, so the loop
// signs in as the seeded dev account and issues one authenticated read every
// INTERVAL_MS. The Origin header must be the auth service's own origin — the old
// hardcoded https://pantry.app now draws a 403 (2026-08-31 host gotcha).
//
// Usage (leave it running in its own terminal; Ctrl-C to stop):
//   NEON_DATA_API_URL=https://ep-…/neondb/rest/v1 \
//   TEST_EMAIL=test@pantry.dev TEST_PASSWORD=… \
//   node ~/agents/scripts/neon-branch-keepalive.mjs
//
// Optional: AUTH_URL (default: the production Worker's /auth mount),
//           INTERVAL_MS (default 20000), JWT_REFRESH_MS (default 600000).

const DATA_API = process.env.NEON_DATA_API_URL?.replace(/\/$/, '');
const AUTH = (process.env.AUTH_URL ?? 'https://pantry-api.everettzyan.workers.dev/auth').replace(/\/$/, '');
const EMAIL = process.env.TEST_EMAIL;
const PASSWORD = process.env.TEST_PASSWORD;
const INTERVAL_MS = Number(process.env.INTERVAL_MS ?? 20_000);
const JWT_REFRESH_MS = Number(process.env.JWT_REFRESH_MS ?? 600_000);

if (!DATA_API || !EMAIL || !PASSWORD) {
  console.error('Set NEON_DATA_API_URL, TEST_EMAIL and TEST_PASSWORD.');
  process.exit(2);
}

// Better Auth always trusts its own base URL as an Origin (src/lib/authClient.ts).
const ORIGIN = new URL(AUTH).origin;
const stamp = () => new Date().toISOString().slice(11, 19);

function cookieHeaderFrom(res) {
  const raw = res.headers.getSetCookie?.() ?? [res.headers.get('set-cookie') ?? ''];
  return raw
    .flatMap((c) => c.split(/,(?=[^;]+=[^;]*;?)/))
    .map((c) => c.split(';')[0].trim())
    .filter(Boolean)
    .join('; ');
}

let session = null; // { cookie, bearer }

async function signIn() {
  const res = await fetch(`${AUTH}/sign-in/email`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`sign-in ${res.status}: ${JSON.stringify(body).slice(0, 200)}`);
  session = { cookie: cookieHeaderFrom(res), bearer: body?.token ?? null };
  console.log(`${stamp()} signed in as ${EMAIL} (cookie: ${session.cookie ? 'yes' : 'no'}, bearer: ${session.bearer ? 'yes' : 'no'})`);
}

async function authedGet(path) {
  const headers = { Origin: ORIGIN };
  if (session?.cookie) headers.Cookie = session.cookie;
  if (session?.bearer) headers.Authorization = `Bearer ${session.bearer}`;
  return fetch(`${AUTH}${path}`, { headers });
}

/** Data-API JWT: `/get-session` returns it in a `set-auth-jwt` header; `/token` in the body. */
async function mintJwt() {
  const gs = await authedGet('/get-session').catch(() => null);
  const fromHeader = gs?.headers.get('set-auth-jwt');
  if (fromHeader) return fromHeader;
  const tk = await authedGet('/token').catch(() => null);
  const body = tk ? await tk.json().catch(() => ({})) : {};
  const token = body?.token ?? tk?.headers.get('set-auth-jwt') ?? null;
  if (!token) throw new Error(`could not mint a JWT (get-session ${gs?.status ?? 'unreachable'}, token ${tk?.status ?? 'unreachable'})`);
  return token;
}

async function main() {
  await signIn();
  let jwt = await mintJwt();
  let mintedAt = Date.now();
  console.log(`${stamp()} JWT minted; warming ${new URL(DATA_API).host} every ${INTERVAL_MS / 1000}s — Ctrl-C to stop`);
  for (;;) {
    if (Date.now() - mintedAt > JWT_REFRESH_MS) {
      try {
        jwt = await mintJwt();
        mintedAt = Date.now();
        console.log(`${stamp()} JWT refreshed`);
      } catch (e) {
        console.log(`${stamp()} JWT refresh failed (${e.message}); signing in again`);
        await signIn().catch((err) => console.log(`${stamp()} re-sign-in failed: ${err.message}`));
      }
    }
    const t0 = Date.now();
    try {
      const res = await fetch(`${DATA_API}/storage_locations?select=id&limit=1`, {
        headers: { Authorization: `Bearer ${jwt}`, Accept: 'application/json' },
      });
      const ms = Date.now() - t0;
      const rows = res.ok ? (await res.json().catch(() => [])).length : 0;
      console.log(`${stamp()} ${res.status} in ${ms} ms${res.ok ? ` (${rows} row)` : ''}${ms > 5000 ? '  <- slow: compute was cold' : ''}`);
      if (res.status === 401) {
        jwt = await mintJwt();
        mintedAt = Date.now();
        console.log(`${stamp()} 401 -> JWT re-minted`);
      }
    } catch (e) {
      console.log(`${stamp()} request failed: ${e.message}`);
    }
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
  }
}

main().catch((e) => {
  console.error(`${stamp()} fatal: ${e.message}`);
  process.exit(1);
});
