const { execFileSync } = require('child_process');
const env = { ...process.env, PATH: '/opt/homebrew/bin:' + (process.env.PATH || '') };
const cwd = '/Users/orchestrator/code/pantry';
const repo = 'ezybg7/pantry';

function gh(args) {
  return execFileSync('gh', args, { env, cwd, encoding: 'utf8' });
}

let base = 'feat/receipt-capture';
try {
  const j = JSON.parse(gh(['pr', 'view', '8', '--repo', repo, '--json', 'state,mergedAt']));
  console.log('PR #8:', j.state, 'mergedAt=', j.mergedAt);
  if (j.state === 'MERGED') base = 'main';
} catch (e) {
  console.log('could not read PR #8:', e.message);
}
console.log('base:', base);

try {
  const out = gh([
    'pr', 'create', '--repo', repo, '--base', base, '--head', 'feat/orchestration-hardening',
    '--title', 'Harden receipt scanning + codify worker autonomy policy',
    '--body-file', '/Users/orchestrator/agents/tmp_pr_body.md',
  ]);
  console.log('PR_URL:', out.trim());
} catch (e) {
  console.error('create failed:', e.message);
  if (e.stdout) console.error('stdout:', e.stdout.toString());
  if (e.stderr) console.error('stderr:', e.stderr.toString());
  process.exit(1);
}
