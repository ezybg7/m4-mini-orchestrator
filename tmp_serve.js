const { spawn } = require('child_process');
const fs = require('fs');

const logPath = '/Users/orchestrator/agents/logs/pantry-functions-serve.log';
const fd = fs.openSync(logPath, 'w'); // fresh log
const env = {
  ...process.env,
  // OrbStack's docker CLI (xbin) + Homebrew supabase; functions serve shells out to `docker`.
  PATH: '/Applications/OrbStack.app/Contents/MacOS/xbin:/opt/homebrew/bin:' + (process.env.PATH || ''),
  DOCKER_HOST: 'unix:///Users/orchestrator/.orbstack/run/docker.sock',
};
const child = spawn(
  'supabase',
  ['functions', 'serve', '--env-file', 'supabase/functions/.env'],
  { cwd: '/Users/orchestrator/code/pantry', env, detached: true, stdio: ['ignore', fd, fd] },
);
child.unref();
console.log('spawned functions serve, pid=', child.pid, 'log=', logPath);
