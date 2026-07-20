const fs = require('fs');
const url = 'http://127.0.0.1:54321/functions/v1/parse-receipt';

async function probe() {
  const out = {};
  try { out.options = (await fetch(url, { method: 'OPTIONS' })).status; } catch (e) { out.options = 'ERR ' + e.message; }
  try {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    out.post = r.status;
  } catch (e) { out.post = 'ERR ' + e.message; }
  return out;
}

(async () => {
  let res;
  for (let i = 0; i < 5; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    res = await probe();
    console.log(`attempt ${i + 1}: OPTIONS=${res.options} POST(no-auth)=${res.post}`);
    if (res.options === 204 || res.post === 401) break; // runtime up
  }
  try {
    const log = fs.readFileSync('/Users/orchestrator/agents/logs/pantry-functions-serve.log', 'utf8');
    console.log('--- serve log tail ---\n' + log.slice(-1000));
  } catch (e) { console.log('no log yet'); }
})();
