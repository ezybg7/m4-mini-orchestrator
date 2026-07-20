const { execFileSync } = require('child_process');
const env = { ...process.env, PATH: '/opt/homebrew/bin:' + (process.env.PATH || '') };
const cwd = '/Users/orchestrator/code/pantry';
const repo = 'ezybg7/pantry';
const gh = (args) => execFileSync('gh', args, { env, cwd, encoding: 'utf8' });

try {
  gh(['pr', 'edit', '9', '--repo', repo, '--body-file', '/Users/orchestrator/agents/tmp_pr_body.md']);
  console.log('body updated');
} catch (e) {
  console.error('edit failed:', e.message, e.stderr && e.stderr.toString());
}

const view = JSON.parse(gh(['pr', 'view', '9', '--repo', repo, '--json', 'number,state,baseRefName,changedFiles,additions,deletions,url,mergeable']));
console.log(JSON.stringify(view, null, 2));
