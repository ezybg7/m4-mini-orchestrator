#!/usr/bin/env python3
"""Build Everett's handoff page (Ambry release pass) from data.json + summary.json."""
import json, hashlib, html, os, re
HOME = os.path.expanduser('~'); A = f'{HOME}/agents/artifact'
data = json.load(open(f'{A}/data.json')); S = json.load(open(f'{A}/summary.json'))
def esc(s): return html.escape(str(s), quote=True)
def cid(*parts): return hashlib.sha1('|'.join(parts).encode()).hexdigest()[:10]
def linkify(s):
    s = esc(s)
    s = re.sub(r'#(\d{2,4})\b', r'<a class="pr" href="https://github.com/ezybg7/pantry/pull/\1" target="_blank" rel="noopener">#\1</a>', s)
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    return s
items = []  # every checkable manual item: {id, group, area, text, expected, flags}
def add(group, area, text, expected='', flags=()):
    items.append({'id': cid(group, area, text), 'group': group, 'area': area, 'text': text, 'expected': expected, 'flags': list(flags)})
# Device pass
for r in data['device_plan']:
    if r['done']: continue
    flags = [f for f in ('[2-DEVICE]', '[DARK]', '[manual]') if f in r['section'] or f in r['text']]
    add('device', r['section'], r['text'], '', flags)
# Runbook manual rows
for r in data['runbook_manual']:
    add('runbook', r['scenario'], f"{r['step']} · {r['action']}", r['expected'])
# Spec 19 gates + production checklist (unchecked only)
for g in data['spec19_gates']:
    if any(o in g['text'].lower() for o in [o.lower() for o in S.get('overrides_done',[])]): continue
    if not g['done']: add('release', 'Spec 19 §D — pre-submission gates', g['text'])
OVR=[o.lower() for o in S.get('overrides_done',[])]
for r in data['production_checklist']:
    if any(o in r['text'].lower() for o in OVR): continue
    if not r['done'] and r['section'].split('.')[0].strip() in ('13', '13c', '12', '11', '10', '9', '8', '0'): add('release', r['section'], r['text'])
groups = {'device': 'Device pass', 'runbook': 'Runbook steps marked [manual]', 'release': 'Release gates'}
counts = {g: sum(1 for i in items if i['group'] == g) for g in groups}
def section_items(group):
    out = []; areas = []
    for i in items:
        if i['group'] == group and i['area'] not in areas: areas.append(i['area'])
    for area in areas:
        rows = [i for i in items if i['group'] == group and i['area'] == area]
        out.append(f'<details class="area" open><summary><span class="area-title">{esc(area)}</span><span class="area-count" data-area="{cid(group, area)}">{len(rows)}</span></summary><ul class="checks">')
        for i in rows:
            flags = ''.join(f'<span class="flag">{esc(f.strip("[]"))}</span>' for f in i['flags'])
            exp = f'<div class="expected">{linkify(i["expected"])}</div>' if i['expected'] else ''
            out.append(f'<li class="check" data-id="{i["id"]}" data-area="{cid(group, area)}" data-group="{group}"><label><input type="checkbox" data-id="{i["id"]}"><span class="box" aria-hidden="true"></span><span class="text">{linkify(i["text"])} {flags}</span></label>{exp}<div class="note-row"><input class="note" type="text" placeholder="Note for Claude (what you saw)" data-id="{i["id"]}" aria-label="Note"></div></li>')
        out.append('</ul></details>')
    return '\n'.join(out)
# PR ledger grouped
waves = S['waves']  # list of {name, blurb, prs:[n]}
prmap = {p['number']: p for p in data['merged_prs']}
ledger = []
for w in waves:
    rows = ''.join(f'<li><a class="pr" href="https://github.com/ezybg7/pantry/pull/{n}" target="_blank" rel="noopener">#{n}</a><span>{esc(prmap[n]["title"]) if n in prmap else esc(S["extra_titles"].get(str(n), ""))}</span></li>' for n in w['prs'])
    ledger.append(f'<div class="wave"><h3>{esc(w["name"])} <span class="muted">· {len(w["prs"])} PRs</span></h3><p>{linkify(w["blurb"])}</p><ul class="prs">{rows}</ul></div>')
def table(rows, head):
    th = ''.join(f'<th>{esc(h)}</th>' for h in head)
    body = ''.join('<tr>' + ''.join(f'<td>{linkify(c) if not str(c).startswith("<") else c}</td>' for c in r) + '</tr>' for r in rows)
    return f'<div class="scroll"><table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table></div>'
def pill(v):
    cls = {'pass': 'ok', 'done': 'ok', 'open': 'warn', 'yours': 'warn', 'waived': 'muted', 'fail': 'bad', 'n/a': 'muted'}.get(v.lower(), 'muted')
    return f'<span class="pill {cls}">{esc(v)}</span>'
evidence = table([[r[0], pill(r[1]), r[2]] for r in S['evidence']], ['Gate', 'State', 'Evidence'])
actions = []
for a in S['actions']:
    cmd = f'<pre class="cmd"><code>{esc(a["command"])}</code></pre>' if a.get('command') else ''
    actions.append(f'<li class="check action" data-id="{cid("action", a["title"])}" data-group="actions"><label><input type="checkbox" data-id="{cid("action", a["title"])}"><span class="box" aria-hidden="true"></span><span class="text"><strong>{esc(a["title"])}</strong> — {linkify(a["detail"])}</span></label>{cmd}</li>')
def decision_li(d):
    if d.get('answer'):
        return f'<li class="check decision done-answer"><div class="text"><strong>{esc(d["q"])}</strong><br><span class="muted">Your call ({esc(d["answered_at"])}): “{esc(d["answer"])}”</span><br>{linkify(d["resolution"])}</div></li>'
    return f'<li class="check decision" data-id="{cid("decision", d["q"])}" data-group="decisions"><label><input type="checkbox" data-id="{cid("decision", d["q"])}"><span class="box" aria-hidden="true"></span><span class="text"><strong>{esc(d["q"])}</strong><br><span class="muted">Default in force: {linkify(d["default"])}</span></span></label><div class="note-row"><input class="note" type="text" placeholder="Your call" data-id="{cid("decision", d["q"])}" aria-label="Decision"></div></li>'
decisions = ''.join(decision_li(d) for d in S['decisions'])
_unused = ''.join(f'<li class="check decision" data-id="{cid("decision", d["q"])}" data-group="decisions"><label><input type="checkbox" data-id="{cid("decision", d["q"])}"><span class="box" aria-hidden="true"></span><span class="text"><strong>{esc(d["q"])}</strong><br><span class="muted">Default in force: {linkify(d["default"])}</span></span></label><div class="note-row"><input class="note" type="text" placeholder="Your call" data-id="{cid("decision", d["q"])}" aria-label="Decision"></div></li>' for d in S['decisions'])
open_items = ''.join(f'<li>{linkify(o)}</li>' for o in S['open_items'])
total_manual = sum(counts.values())
page = f'''<title>Ambry Release Pass</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{{--bg:#F4F6F3;--surface:#FFFFFF;--surface-2:#EAEFEA;--ink:#1A221E;--ink-2:#4A5650;--muted:#6F7A74;--line:#D5DDD7;--accent:#2E6A4E;--accent-ink:#FFFFFF;--accent-soft:#DDEBE2;--ok:#2E6A4E;--warn:#9A6B12;--warn-soft:#F6EBD2;--bad:#A83A3A;--bad-soft:#F5DEDE;--mono:'IBM Plex Mono',ui-monospace,SFMono-Regular,Menlo,monospace;--sans:'IBM Plex Sans',system-ui,-apple-system,'Segoe UI',sans-serif;color-scheme:light}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#131816;--surface:#1B221E;--surface-2:#232C27;--ink:#E7ECE8;--ink-2:#B9C3BD;--muted:#8B968F;--line:#2E3934;--accent:#7CC39A;--accent-ink:#0F1813;--accent-soft:#1F3A2C;--ok:#7CC39A;--warn:#E0B45E;--warn-soft:#3A3020;--bad:#E38B8B;--bad-soft:#3D2323;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#131816;--surface:#1B221E;--surface-2:#232C27;--ink:#E7ECE8;--ink-2:#B9C3BD;--muted:#8B968F;--line:#2E3934;--accent:#7CC39A;--accent-ink:#0F1813;--accent-soft:#1F3A2C;--ok:#7CC39A;--warn:#E0B45E;--warn-soft:#3A3020;--bad:#E38B8B;--bad-soft:#3D2323;color-scheme:dark}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans);font-size:15px;line-height:1.5;-webkit-font-smoothing:antialiased}}
a{{color:var(--accent)}} code{{font-family:var(--mono);font-size:.9em;background:var(--surface-2);padding:.05em .35em;border-radius:3px}}
.layout{{display:grid;grid-template-columns:230px minmax(0,1fr);min-height:100vh}}
nav{{position:sticky;top:0;height:100vh;overflow:auto;padding:22px 18px;border-right:1px solid var(--line);background:var(--surface)}}
nav .brand{{font-weight:600;letter-spacing:.01em;margin:0 0 2px}} nav .sub{{color:var(--muted);font-size:12.5px;margin:0 0 18px}}
nav a.item{{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:7px 8px;border-radius:6px;color:var(--ink-2);text-decoration:none;font-size:14px}} nav a.item:hover{{background:var(--surface-2)}} nav a.item .n{{font-family:var(--mono);font-size:12px;color:var(--muted)}}
main{{padding:28px clamp(18px,4vw,56px) 80px;max-width:1080px}}
h1{{font-size:28px;line-height:1.15;margin:0 0 6px;text-wrap:balance;font-weight:600}} h2{{font-size:20px;margin:44px 0 10px;font-weight:600;text-wrap:balance}} h3{{font-size:16px;margin:22px 0 6px;font-weight:600}}
p{{max-width:68ch}} .lede{{color:var(--ink-2);font-size:16px;max-width:70ch}} .muted{{color:var(--muted);font-weight:400}}
.stats{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:18px 0 6px}}
.stat{{background:var(--surface);border:1px solid var(--line);border-radius:8px;padding:12px 14px}} .stat .v{{font-family:var(--mono);font-size:24px;font-weight:500;font-variant-numeric:tabular-nums}} .stat .l{{color:var(--muted);font-size:12.5px;letter-spacing:.02em;text-transform:uppercase}}
.progress{{height:6px;background:var(--surface-2);border-radius:3px;overflow:hidden;margin-top:8px}} .progress i{{display:block;height:100%;width:0;background:var(--accent);transition:width .3s}}
.toolbar{{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:14px 0 10px}} .toolbar input[type=search]{{flex:1;min-width:200px;padding:8px 10px;border:1px solid var(--line);border-radius:6px;background:var(--surface);color:var(--ink);font:inherit}}
.toolbar label{{display:flex;gap:6px;align-items:center;color:var(--ink-2);font-size:14px}}
.sync{{font-size:12.5px;color:var(--muted);display:flex;align-items:center;gap:6px}} .sync b{{display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--muted)}} .sync.on b{{background:var(--ok)}}
details.area{{border:1px solid var(--line);border-radius:8px;background:var(--surface);margin:10px 0}} details.area>summary{{cursor:pointer;list-style:none;display:flex;justify-content:space-between;align-items:center;padding:10px 14px;font-weight:600}} details.area>summary::-webkit-details-marker{{display:none}} details.area>summary::before{{content:"▸";color:var(--muted);margin-right:8px;transition:transform .15s}} details.area[open]>summary::before{{transform:rotate(90deg)}}
.area-count{{font-family:var(--mono);font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums}}
ul.checks{{list-style:none;margin:0;padding:0 14px 8px}} li.check{{border-top:1px solid var(--line);padding:9px 0}} li.check label{{display:grid;grid-template-columns:20px minmax(0,1fr);gap:10px;align-items:start;cursor:pointer}}
li.check input[type=checkbox]{{position:absolute;opacity:0;width:1px;height:1px}} .box{{width:18px;height:18px;border:1.5px solid var(--ink-2);border-radius:4px;margin-top:3px;background:var(--surface);position:relative}} li.check input:checked+.box{{background:var(--accent);border-color:var(--accent)}} li.check input:checked+.box::after{{content:"";position:absolute;left:5px;top:1px;width:5px;height:10px;border:solid var(--accent-ink);border-width:0 2px 2px 0;transform:rotate(45deg)}} li.check input:focus-visible+.box{{outline:2px solid var(--accent);outline-offset:2px}}
li.check.done .text{{color:var(--muted);text-decoration:line-through}} li.check.hidden{{display:none}}
.expected{{margin:4px 0 0 30px;color:var(--ink-2);font-size:14px}} .expected::before{{content:"Expect: ";color:var(--muted)}}
.note-row{{margin:6px 0 0 30px}} .note{{width:100%;max-width:640px;padding:5px 8px;border:1px dashed var(--line);border-radius:5px;background:transparent;color:var(--ink);font:inherit;font-size:13.5px}} .note:focus{{border-style:solid;outline:none;border-color:var(--accent)}} .note.has{{border-style:solid;background:var(--surface-2)}}
li.done-answer{{border-top:1px solid var(--line);padding:9px 0}} li.done-answer .text{{display:block;padding-left:30px;position:relative}} li.done-answer .text::before{{content:"✓";position:absolute;left:4px;top:0;color:var(--ok);font-weight:600}}
.flag{{display:inline-block;font-family:var(--mono);font-size:11px;padding:1px 6px;border-radius:3px;background:var(--warn-soft);color:var(--warn);margin-left:4px;vertical-align:middle}}
.pill{{display:inline-block;font-size:12px;font-weight:500;padding:2px 8px;border-radius:999px;background:var(--surface-2);color:var(--ink-2);white-space:nowrap}} .pill.ok{{background:var(--accent-soft);color:var(--ok)}} .pill.warn{{background:var(--warn-soft);color:var(--warn)}} .pill.bad{{background:var(--bad-soft);color:var(--bad)}}
.scroll{{overflow-x:auto;border:1px solid var(--line);border-radius:8px;background:var(--surface)}} table{{border-collapse:collapse;width:100%;font-size:14px}} th,td{{text-align:left;padding:9px 12px;border-top:1px solid var(--line);vertical-align:top}} th{{border-top:0;font-size:12px;letter-spacing:.03em;text-transform:uppercase;color:var(--muted);font-weight:600}} td:first-child{{font-weight:500;white-space:nowrap}}
.wave{{border-left:3px solid var(--accent-soft);padding:2px 0 2px 16px;margin:16px 0}} .wave h3{{margin:0 0 4px}} ul.prs{{list-style:none;margin:6px 0 0;padding:0;display:grid;gap:4px}} ul.prs li{{display:grid;grid-template-columns:56px minmax(0,1fr);gap:8px;font-size:14px}} a.pr{{font-family:var(--mono);font-size:13px;text-decoration:none;color:var(--accent)}}
pre.cmd{{margin:8px 0 0 30px;padding:10px 12px;background:var(--surface-2);border:1px solid var(--line);border-radius:6px;overflow-x:auto;font-family:var(--mono);font-size:12.5px;line-height:1.5;max-width:760px}}
ul.plain{{padding-left:18px}} ul.plain li{{margin:4px 0;max-width:75ch}}
.callout{{border:1px solid var(--line);border-left:3px solid var(--warn);background:var(--surface);padding:10px 14px;border-radius:6px;max-width:75ch;margin:12px 0}}
@media (max-width:820px){{.layout{{grid-template-columns:1fr}} nav{{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:4px;padding:12px}} nav .brand,nav .sub{{width:100%}} nav a.item{{padding:6px 8px;font-size:13px}} main{{padding:18px 16px 60px}}}}
@media (prefers-reduced-motion:reduce){{*{{transition:none!important}}}}
</style>
<div class="layout">
<nav aria-label="Sections"><p class="brand">Ambry Release Pass</p><p class="sub">{esc(S['as_of'])}</p>
<a class="item" href="#overview">Overview</a>
<a class="item" href="#changes">What changed <span class="n">{len(data['merged_prs'])} PRs</span></a>
<a class="item" href="#actions">Your actions <span class="n">{len(S['actions'])}</span></a>
<a class="item" href="#decisions">Decisions <span class="n">{len(S['decisions'])}</span></a>
<a class="item" href="#device">Device pass <span class="n">{counts['device']}</span></a>
<a class="item" href="#runbook">Runbook [manual] <span class="n">{counts['runbook']}</span></a>
<a class="item" href="#release">Release gates <span class="n">{counts['release']}</span></a>
<a class="item" href="#evidence">Verified by Claude <span class="n">{len(S['evidence'])}</span></a>
<a class="item" href="#open">Still open <span class="n">{len(S['open_items'])}</span></a>
</nav>
<main>
<section id="overview"><h1>Ambry release pass — what changed, what you test</h1>
<p class="lede">{linkify(S['lede'])}</p>
<div class="stats">
<div class="stat"><div class="v">{len(data['merged_prs'])}</div><div class="l">PRs merged since Sep 3</div></div>
<div class="stat"><div class="v">{esc(S['stats']['acceptance'])}</div><div class="l">Acceptance flows (simulator)</div></div>
<div class="stat"><div class="v">{esc(S['stats']['unit'])}</div><div class="l">Jest suites · tests in CI</div></div>
<div class="stat"><div class="v">{total_manual}</div><div class="l">Manual checks for you</div></div>
<div class="stat"><div class="v" id="done-count">0</div><div class="l">Ticked so far</div><div class="progress"><i id="done-bar"></i></div></div>
</div>
<div class="toolbar"><input type="search" id="q" placeholder="Filter checks (e.g. swipe, invite, dark)"><label><input type="checkbox" id="hide-done"> Hide ticked</label><span class="sync" id="sync"><b></b><span>Ticks save on this device</span></span></div>
<div class="callout">{linkify(S['callout'])}</div>
</section>
<section id="changes"><h2>What changed</h2><p>{linkify(S['changes_intro'])}</p>{''.join(ledger)}</section>
<section id="actions"><h2>Your actions (only you can do these)</h2><p>{linkify(S['actions_intro'])}</p><ul class="checks">{''.join(actions)}</ul></section>
<section id="decisions"><h2>Decisions waiting on you</h2><p>Each has a default already in force so nothing blocks on it. Overrule in the PR comment named, or write your call here and I will pick it up.</p><ul class="checks">{decisions}</ul></section>
<section id="device"><h2>Device pass</h2><p>{linkify(S['device_intro'])}</p>{section_items('device')}</section>
<section id="runbook"><h2>Runbook steps marked [manual]</h2><p>{linkify(S['runbook_intro'])}</p>{section_items('runbook')}</section>
<section id="release"><h2>Release gates</h2><p>{linkify(S['release_intro'])}</p>{section_items('release')}</section>
<section id="evidence"><h2>Verified by Claude</h2><p>{linkify(S['evidence_intro'])}</p>{evidence}</section>
<section id="open"><h2>Still open</h2><ul class="plain">{open_items}</ul></section>
</main></div>
<script>
(function(){{
const state={{}};const LS='ambry-release-pass-v1';
try{{Object.assign(state,JSON.parse(localStorage.getItem(LS)||'{{}}'))}}catch(e){{}}
let db=null,col=null;
const boxes=[...document.querySelectorAll('input[type=checkbox][data-id]')];const notes=[...document.querySelectorAll('input.note[data-id]')];
function render(){{
  let done=0;const total=boxes.length;
  for(const b of boxes){{const s=state[b.dataset.id]||{{}};b.checked=!!s.done;const li=b.closest('li.check');li.classList.toggle('done',!!s.done);if(s.done)done++;}}
  for(const n of notes){{const s=state[n.dataset.id]||{{}};if(document.activeElement!==n)n.value=s.note||'';n.classList.toggle('has',!!(s.note));}}
  const dc=document.getElementById('done-count');dc.textContent=done;document.getElementById('done-bar').style.width=(total?100*done/total:0)+'%';
  const per={{}};for(const b of boxes){{const li=b.closest('li.check');const a=li.dataset.area;if(!a)continue;per[a]=per[a]||{{d:0,t:0}};per[a].t++;if(b.checked)per[a].d++;}}
  for(const el of document.querySelectorAll('.area-count')){{const p=per[el.dataset.area];if(p)el.textContent=p.d+' / '+p.t;}}
  filter();
}}
function filter(){{const q=document.getElementById('q').value.trim().toLowerCase();const hd=document.getElementById('hide-done').checked;
  for(const li of document.querySelectorAll('li.check')){{const hit=!q||li.textContent.toLowerCase().includes(q);const d=li.classList.contains('done');li.classList.toggle('hidden',!hit||(hd&&d));}}}}
function persistLocal(){{try{{localStorage.setItem(LS,JSON.stringify(state))}}catch(e){{}}}}
async function save(id,patch){{state[id]=Object.assign({{}},state[id]||{{}},patch,{{at:new Date().toISOString()}});persistLocal();render();
  if(col){{try{{await col.doc(id).set(state[id])}}catch(e){{setSync(false,'Could not save to the shared record — kept on this device')}}}}}}
function setSync(on,msg){{const s=document.getElementById('sync');s.classList.toggle('on',on);s.querySelector('span').textContent=msg}}
for(const b of boxes)b.addEventListener('change',()=>save(b.dataset.id,{{done:b.checked}}));
for(const n of notes){{let t;n.addEventListener('input',()=>{{clearTimeout(t);t=setTimeout(()=>save(n.dataset.id,{{note:n.value}}),600)}});n.addEventListener('blur',()=>save(n.dataset.id,{{note:n.value}}));}}
document.getElementById('q').addEventListener('input',filter);document.getElementById('hide-done').addEventListener('change',filter);
render();
(async()=>{{try{{db=window.claude&&await window.claude.use('db');}}catch(e){{db=null}}
  if(!db)return;col=db.collection('checks');
  col.onSnapshot(snap=>{{for(const d of snap.docs){{if(d.exists)state[d.id]=Object.assign({{}},state[d.id]||{{}},d.data());}}persistLocal();render();setSync(true,'Ticks and notes are shared with Claude')}},err=>setSync(false,'Shared record unavailable — kept on this device'));
}})();
}})();
</script>'''
open(f'{A}/ambry-release-pass.html', 'w').write(page)
print('items:', counts, 'total', total_manual, 'bytes', len(page))
