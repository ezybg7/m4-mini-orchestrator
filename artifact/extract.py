#!/usr/bin/env python3
"""Collect the manual-test and change sources for Everett's artifact into one JSON file."""
import json, re, os, subprocess
HOME = os.path.expanduser('~'); REPO = f'{HOME}/code/pantry'
def read(p): return open(p, encoding='utf-8').read()
def strip_md(s):
    s = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', s); s = s.replace('**', '')
    return re.sub(r'\s+', ' ', s).strip()
out = {}
# 1. device test plan: sections + checkboxes
sec = None; plan = []
for line in read(f'{REPO}/docs/device-test-plan.md').splitlines():
    m = re.match(r'^## (.+)$', line)
    if m: sec = strip_md(m.group(1)); continue
    m = re.match(r'^\s*- \[( |x)\] (.+)$', line)
    if m and sec: plan.append({'section': sec, 'done': m.group(1) == 'x', 'text': strip_md(m.group(2))[:400]})
out['device_plan'] = plan
# 2. production checklist: unchecked, not struck
sec = None; pc = []
for line in read(f'{REPO}/docs/PRODUCTION_CHECKLIST.md').splitlines():
    m = re.match(r'^## (.+)$', line)
    if m: sec = strip_md(m.group(1)); continue
    m = re.match(r'^\s*- \[( |x)\] (.+)$', line)
    if m and sec and not m.group(2).startswith('~~'): pc.append({'section': sec, 'done': m.group(1) == 'x', 'text': strip_md(m.group(2))[:400]})
out['production_checklist'] = pc
# 3. spec 19 §D gates
txt = read(f'{REPO}/specs/app-store-release.md'); d = re.search(r'^## D.*?(?=^## E)', txt, re.S | re.M)
gates = []
if d:
    for line in d.group(0).splitlines():
        m = re.match(r'^\s*- \[( |x)\] (.+)$', line)
        if m: gates.append({'done': m.group(1) == 'x', 'text': strip_md(m.group(2))[:400]})
out['spec19_gates'] = gates
# 4. runbook [manual] rows per scenario
sec = None; rows = []
for line in read(f'{REPO}/docs/ACCEPTANCE_TESTS.md').splitlines():
    m = re.match(r'^### (.+)$', line)
    if m: sec = strip_md(m.group(1)); continue
    if '[manual]' in line and line.startswith('|') and sec:
        cells = [strip_md(c) for c in line.strip().strip('|').split('|')]
        if len(cells) >= 3: rows.append({'scenario': sec, 'step': cells[0], 'action': cells[1].replace('[manual]', '').strip()[:300], 'expected': cells[2][:400]})
out['runbook_manual'] = rows
# 5. Everett-only note sections
sec = None; ev = {}
for line in read(f'{HOME}/agents/memory/projects/pantry-everett-only-2026-09-04.md').splitlines():
    m = re.match(r'^## (.+)$', line)
    if m: sec = strip_md(m.group(1))[:80]; ev[sec] = []; continue
    if sec and line.strip(): ev[sec].append(strip_md(line.strip().lstrip('-').lstrip('0123456789.').strip())[:700])
out['everett_only'] = ev
# 6. merged PR ledger
led = []
for line in read(f'{HOME}/agents/logs/merged-prs-since-2026-09-03.txt').splitlines():
    m = re.match(r'^(\S+) #(\d+) (.+)$', line)
    if m: led.append({'merged': m.group(1), 'number': int(m.group(2)), 'title': m.group(3)})
out['merged_prs'] = led
json.dump(out, open(f'{HOME}/agents/artifact/data.json', 'w'), indent=1)
print({k: (len(v) if isinstance(v, list) else {kk: len(vv) for kk, vv in v.items()}) for k, v in out.items()})
