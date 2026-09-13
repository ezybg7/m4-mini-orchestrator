#!/bin/zsh
# make-index.sh — rebuild shots/index.json from what is actually on disk, joined
# with scratch/routes.json (the screen -> route-file map). Run after tour.sh.
set -u
cd "$(dirname $0)" || exit 2
python3 - <<'PY'
import json, os, datetime
run = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
run = os.getcwd()
routes = json.load(open(os.path.join(run, 'scratch/routes.json')))
modes = ['light', 'dark', 'ax5']
present = {m: set() for m in modes}
for m in modes:
    d = os.path.join(run, 'shots', m)
    if os.path.isdir(d):
        present[m] = {f[:-4] for f in os.listdir(d) if f.endswith('.png')}
names = sorted(set().union(*present.values()) | set(routes))
screens = {}
for n in names:
    captured = [m for m in modes if n in present[m]]
    screens[n] = {
        'routes': routes.get(n, {}).get('routes', []),
        'note': routes.get(n, {}).get('note', ''),
        'modes': captured,
        'missing_modes': [m for m in modes if m not in captured],
        'shots': {m: f'shots/{m}/{n}.png' for m in captured},
        'thumbs': {m: f'thumbs/{m}/{n}.jpg' for m in captured
                   if os.path.exists(os.path.join(run, 'thumbs', m, n + '.jpg'))},
    }
out = {
    'generated': datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
    'device': {'name': 'iPhone 17 Pro', 'udid': '70893D75-19E3-4CF2-8DBC-84B6BD00C3C7', 'runtime': 'iOS 26.5'},
    'modes': {
        'light': {'appearance': 'light', 'content_size': 'large'},
        'dark': {'appearance': 'dark', 'content_size': 'large'},
        'ax5': {'appearance': 'light', 'content_size': 'accessibility-extra-extra-extra-large'},
    },
    'repo': '/Users/orchestrator/code/pantry',
    'counts': {m: len(present[m]) for m in modes},
    'screens': screens,
}
json.dump(out, open(os.path.join(run, 'shots/index.json'), 'w'), indent=2)
print('shots/index.json:', {m: len(present[m]) for m in modes}, 'screens:', len(screens))
PY
