import subprocess, os
env = dict(os.environ)
env['PATH'] = '/opt/homebrew/bin:' + env.get('PATH', '')
r = subprocess.run(
    ['gh', 'pr', 'create',
     '--base', 'feat/orchestration-hardening',
     '--head', 'feat/vision-model-selection',
     '--title', 'Select and implement Claude Haiku 4.5 as the production receipt vision provider',
     '--body-file', os.path.expanduser('~/agents/tmp_pr-vision.md')],
    env=env, capture_output=True, text=True, cwd='/Users/orchestrator/code/pantry')
print('RC', r.returncode)
print('OUT', r.stdout.strip())
print('ERR', r.stderr.strip())
