const fs = require('fs');
const home = process.env.HOME;
const yaml = fs.readFileSync(home + '/.config/gh/hosts.yml', 'utf8');
const token = (yaml.match(/oauth_token:\s*(\S+)/) || [])[1];
if (!token) { console.error('NO_TOKEN'); process.exit(1); }
const body = fs.readFileSync(home + '/agents/tmp_pr-vision.md', 'utf8');
const payload = {
  title: 'Select and implement Claude Haiku 4.5 as the production receipt vision provider',
  head: 'feat/vision-model-selection',
  base: 'feat/orchestration-hardening',
  body,
};
fetch('https://api.github.com/repos/ezybg7/pantry/pulls', {
  method: 'POST',
  headers: {
    Authorization: 'token ' + token,
    Accept: 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'User-Agent': 'pantry-worker',
  },
  body: JSON.stringify(payload),
})
  .then(async (r) => {
    const j = await r.json();
    if (r.ok) console.log('PR_URL=' + j.html_url);
    else { console.error('ERROR ' + r.status + ': ' + JSON.stringify(j).slice(0, 600)); process.exit(1); }
  })
  .catch((e) => { console.error('FETCH_FAIL ' + e.message); process.exit(1); });
