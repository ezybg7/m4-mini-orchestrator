import subprocess, os
env = dict(os.environ)
env['PATH'] = '/opt/homebrew/bin:' + env.get('PATH', '')
def run(args):
    r = subprocess.run(['gh'] + args, env=env, capture_output=True, text=True,
                       cwd='/Users/orchestrator/code/pantry')
    print('$ gh', ' '.join(args), '| rc', r.returncode)
    print(r.stdout.strip() or r.stderr.strip())
    print('---')
run(['pr', 'checks', '10'])
run(['run', 'list', '--branch', 'feat/vision-model-selection', '--limit', '5'])
