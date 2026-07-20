const { execFileSync } = require('child_process');
const env = {
  ...process.env,
  PATH: '/opt/homebrew/bin:' + (process.env.PATH || ''),
  DOCKER_HOST: 'unix:///Users/orchestrator/.orbstack/run/docker.sock',
};
const cwd = '/Users/orchestrator/code/pantry';
function run(args, timeout) {
  try {
    return { ok: true, out: execFileSync('supabase', args, { env, cwd, encoding: 'utf8', timeout }) };
  } catch (e) {
    return { ok: false, msg: e.message, stdout: e.stdout && e.stdout.toString(), stderr: e.stderr && e.stderr.toString() };
  }
}
console.log('--- supabase start ---');
const s = run(['start'], 150000);
if (s.ok) console.log(s.out.slice(-600));
else console.log(('FAILED: ' + s.msg + '\n' + (s.stdout || '') + '\n' + (s.stderr || '')).slice(0, 2500));
console.log('--- supabase status (services) ---');
const st = run(['status'], 30000);
console.log(st.ok ? 'status OK (all services reported)' : ('status: ' + (st.stderr || st.msg || '').slice(0, 800)));
