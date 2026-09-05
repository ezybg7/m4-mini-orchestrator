#!/usr/bin/env python3
"""Build the screen-directions review gallery: research + alternative mocks per screen + a decision recorder (db)."""
import json, os, glob, html, re, hashlib
HOME = os.path.expanduser('~'); R = f'{HOME}/agents/research/screens'; M = f'{HOME}/agents/research/mocks'; OUT = f'{HOME}/agents/artifact/ambry-screen-directions.html'
def esc(s): return html.escape(str(s), quote=True)
def slug(s): return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')[:60]
GROUP_ORDER = ['account', 'pantry', 'add-capture', 'lists-recipes']
GROUP_TITLES = {'account': 'Account, onboarding, profile, paywall, insights', 'pantry': 'Pantry, locations, zones, expiring, item', 'add-capture': 'Add tab and capture', 'lists-recipes': 'Lists, restock, recipes'}
groups = []
MANIFEST = {}
for g in GROUP_ORDER:
    mp = f'{M}/{g}/manifest.json'
    if os.path.exists(mp):
        try:
            for e in json.load(open(mp)):
                MANIFEST[(g, e.get('screen_slug') or slug(e.get('screen','')))] = e
        except Exception as ex: print('bad manifest', mp, ex)
for g in GROUP_ORDER:
    p = f'{R}/{g}.json'
    if not os.path.exists(p): continue
    try: screens = json.load(open(p))
    except Exception as e: print('bad json', p, e); continue
    if isinstance(screens, dict): screens = screens.get('screens') or list(screens.values())[0]
    groups.append((g, screens))
def mock_html(g, screen, direction):
    """A mock is an HTML fragment (own <style> allowed) at mocks/<group>/<screen-slug>/<direction-slug>.html — rendered inside a declarative shadow root so its CSS stays scoped."""
    p = f'{M}/{g}/{slug(screen)}/{slug(direction)}.html'
    if not os.path.exists(p):
        return '<div class="nomock">Mock not built yet — wireframe on the right describes it.</div>'
    frag = open(p, encoding='utf-8').read()
    return f'<div class="phone"><template shadowrootmode="open"><style>:host{{display:block;width:390px;height:844px;overflow:hidden;background:#fff;color:#1a1a1a;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif;font-size:15px;line-height:1.35}}*{{box-sizing:border-box}}</style>{frag}</template></div>'
nav = []; body = []
n_screens = 0; n_dirs = 0
for g, screens in groups:
    nav.append(f'<div class="nav-group">{esc(GROUP_TITLES.get(g, g))}</div>')
    body.append(f'<section class="group" id="g-{g}"><h2>{esc(GROUP_TITLES.get(g, g))}</h2>')
    for sc in screens:
        n_screens += 1; sid = f'{g}--{slug(sc["screen"])}'
        nav.append(f'<a class="item" href="#{sid}">{esc(sc["screen"])}</a>')
        apps = ''.join(f'<li><strong>{esc(a["name"])}</strong> — {esc(a.get("what",""))}<ul>' + ''.join(f'<li>{esc(x.get("aspect",""))} <span class="why">— {esc(x.get("why",""))}</span> {("<a href=%s target=_blank rel=noopener>source</a>" % esc(x["source"])) if x.get("source") else ""}</li>' for x in a.get('aspects', [])) + '</ul></li>' for a in sc.get('apps', []))
        man = MANIFEST.get((g, slug(sc['screen'])), {})
        today_look = (man.get('today') or {}).get('look_for', '')
        today_panel = f'<div class="direction today"><div class="dir-head"><span class="letter now">Now</span><div><h4>Today</h4><p class="pitch">{esc(today_look or "The screen as it ships on main.")}</p></div></div><div class="dir-body">{mock_html(g, sc["screen"], "today")}<div class="dir-notes"><p>{esc(sc.get("current_summary",""))}</p></div></div></div>'
        dirs = [today_panel]
        for i, d in enumerate(sc.get('directions', [])):
            n_dirs += 1; letter = 'ABC'[i] if i < 3 else str(i + 1)
            regions = ''.join(f'<li>{esc(r)}</li>' for r in d.get('regions', []))
            borrowed = ''.join(f'<li>{esc(b.get("aspect",""))} <span class="why">({esc(b.get("app",""))})</span></li>' for b in d.get('borrowed', []))
            look = next((x.get('look_for','') for x in (man.get('directions') or []) if x.get('slug') == slug(d.get('name',''))), '')
            dirs.append(f'''<div class="direction"><div class="dir-head"><span class="letter">{letter}</span><div><h4>{esc(d.get("name",""))}</h4><p class="pitch">{esc(d.get("pitch",""))}</p>{('<p class="look">Look for: ' + esc(look) + '</p>') if look else ''}</div></div>
<div class="dir-body">{mock_html(g, sc["screen"], d.get("name",""))}<div class="dir-notes"><h5>Regions</h5><ol>{regions}</ol><h5>Borrowed</h5><ul>{borrowed}</ul><p><strong>Cost after:</strong> {esc(d.get("cost",""))}</p><p><strong>Trade-off:</strong> {esc(d.get("tradeoff",""))}</p></div></div></div>''')
        choices = ''.join(f'<label><input type="radio" name="{sid}" value="{v}"><span>{t}</span></label>' for v, t in [('A', 'Adopt A'), ('B', 'Adopt B'), ('C', 'Adopt C'), ('keep', 'Keep as is'), ('mix', 'Mix (say which parts)')])
        body.append(f'''<article class="screen" id="{sid}" data-screen="{sid}"><h3>{esc(sc["screen"])} <span class="route">{esc(sc.get("route",""))}</span></h3>
<p class="current"><strong>Today:</strong> {esc(sc.get("current_summary",""))}</p>
<details class="research"><summary>What other apps do ({len(sc.get("apps", []))} studied)</summary><ul class="apps">{apps}</ul></details>
<div class="directions">{''.join(dirs)}</div>
<div class="decide"><div class="choices">{choices}</div><input class="dnote" type="text" placeholder="Your notes for this screen (what to take, what to skip)" data-screen="{sid}"><span class="saved" data-screen="{sid}"></span></div>
</article>''')
    body.append('</section>')
page = f'''<title>Ambry Screen Directions</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{{--bg:#F4F6F3;--surface:#FFFFFF;--surface-2:#EAEFEA;--ink:#1A221E;--ink-2:#4A5650;--muted:#6F7A74;--line:#D5DDD7;--accent:#2E6A4E;--accent-ink:#FFFFFF;--accent-soft:#DDEBE2;--warn:#9A6B12;--warn-soft:#F6EBD2;--sans:'IBM Plex Sans',system-ui,-apple-system,sans-serif;--mono:'IBM Plex Mono',ui-monospace,Menlo,monospace;color-scheme:light}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#131816;--surface:#1B221E;--surface-2:#232C27;--ink:#E7ECE8;--ink-2:#B9C3BD;--muted:#8B968F;--line:#2E3934;--accent:#7CC39A;--accent-ink:#0F1813;--accent-soft:#1F3A2C;--warn:#E0B45E;--warn-soft:#3A3020;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#131816;--surface:#1B221E;--surface-2:#232C27;--ink:#E7ECE8;--ink-2:#B9C3BD;--muted:#8B968F;--line:#2E3934;--accent:#7CC39A;--accent-ink:#0F1813;--accent-soft:#1F3A2C;--warn:#E0B45E;--warn-soft:#3A3020;color-scheme:dark}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans);font-size:15px;line-height:1.5}} a{{color:var(--accent)}}
.layout{{display:grid;grid-template-columns:250px minmax(0,1fr)}} nav{{position:sticky;top:0;height:100vh;overflow:auto;padding:20px 16px;border-right:1px solid var(--line);background:var(--surface)}} nav .brand{{font-weight:600;margin:0 0 2px}} nav .sub{{color:var(--muted);font-size:12.5px;margin:0 0 14px}} .nav-group{{font-size:11.5px;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);margin:14px 0 4px}} nav a.item{{display:block;padding:5px 8px;border-radius:6px;color:var(--ink-2);text-decoration:none;font-size:13.5px}} nav a.item:hover{{background:var(--surface-2)}}
main{{padding:26px clamp(18px,3vw,48px) 80px;max-width:1500px}} h1{{font-size:28px;margin:0 0 6px;font-weight:600;text-wrap:balance}} h2{{font-size:21px;margin:44px 0 8px;font-weight:600}} h3{{font-size:18px;margin:34px 0 6px;font-weight:600}} h4{{margin:0;font-size:15.5px;font-weight:600}} h5{{margin:10px 0 4px;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted)}}
.lede{{color:var(--ink-2);max-width:72ch;font-size:16px}} .route{{font-family:var(--mono);font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}} .current{{max-width:80ch;color:var(--ink-2)}}
details.research{{border:1px solid var(--line);border-radius:8px;background:var(--surface);padding:0 14px;margin:8px 0 14px;max-width:960px}} details.research summary{{cursor:pointer;padding:10px 0;font-weight:500}} ul.apps{{padding-left:18px;margin:0 0 12px}} ul.apps>li{{margin:6px 0}} ul.apps ul{{padding-left:16px;color:var(--ink-2);font-size:14px}} .why{{color:var(--muted)}}
.directions{{display:grid;gap:18px}} .direction{{border:1px solid var(--line);border-radius:10px;background:var(--surface);padding:14px 16px}} .dir-head{{display:flex;gap:12px;align-items:flex-start;margin-bottom:10px}} .letter.now{{background:var(--surface-2);color:var(--ink-2);width:auto;padding:0 8px;font-size:12px}} .look{{margin:4px 0 0;font-size:13.5px;color:var(--muted)}} .direction.today{{border-style:dashed}}
.letter{{font-family:var(--mono);font-weight:500;background:var(--accent);color:var(--accent-ink);border-radius:6px;width:28px;height:28px;display:grid;place-items:center;flex:none}} .pitch{{margin:2px 0 0;color:var(--ink-2)}}
.dir-body{{display:grid;grid-template-columns:auto minmax(260px,1fr);gap:18px;align-items:start}} .phone{{width:390px;height:844px;border-radius:44px;border:8px solid #1c1c1e;box-shadow:0 10px 30px rgba(0,0,0,.18);overflow:hidden;background:#fff;transform-origin:top left;flex:none}} .nomock{{width:390px;height:200px;display:grid;place-items:center;border:1px dashed var(--line);border-radius:10px;color:var(--muted);text-align:center;padding:20px}} .dir-notes{{font-size:14px;color:var(--ink-2)}} .dir-notes ol,.dir-notes ul{{padding-left:18px;margin:0}} .dir-notes li{{margin:2px 0}}
.decide{{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:14px 0 6px;padding:12px 14px;border:1px solid var(--line);border-left:3px solid var(--accent);border-radius:8px;background:var(--surface)}} .choices{{display:flex;flex-wrap:wrap;gap:6px}} .choices label{{display:inline-flex;align-items:center;gap:6px;padding:6px 10px;border:1px solid var(--line);border-radius:999px;cursor:pointer;font-size:14px}} .choices input{{accent-color:var(--accent)}} .choices label:has(input:checked){{background:var(--accent-soft);border-color:var(--accent)}} .dnote{{flex:1;min-width:240px;padding:7px 10px;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--ink);font:inherit;font-size:14px}} .saved{{font-size:12.5px;color:var(--muted)}}
.sync{{font-size:12.5px;color:var(--muted);margin:8px 0 0}} .sync.on{{color:var(--accent)}}
@media (max-width:1100px){{.phone{{transform:scale(.8);margin-bottom:-169px;margin-right:-78px}}}} @media (max-width:820px){{.layout{{grid-template-columns:1fr}} nav{{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line)}} main{{padding:16px}} .dir-body{{grid-template-columns:1fr}} .phone{{transform:scale(.85);margin-bottom:-126px}}}}
@media (prefers-reduced-motion:reduce){{*{{transition:none!important}}}}
</style>
<div class="layout"><nav aria-label="Screens"><p class="brand">Ambry Screen Directions</p><p class="sub">{n_screens} screens · {n_dirs} directions</p>{''.join(nav)}</nav>
<main><h1>Screen directions — research and alternatives for your call</h1>
<p class="lede">For every screen: what it does today, what comparable apps do (with sources), and three materially different directions built from those aspects, each as a phone mock beside its wireframe and trade-off. Pick one per screen, or keep it, or say which parts to mix; your notes are saved for Claude to act on.</p>
<p class="sync" id="sync">Decisions save on this device</p>
{''.join(body)}
</main></div>
<script>
(function(){{const LS='ambry-screen-directions-v1';const state={{}};try{{Object.assign(state,JSON.parse(localStorage.getItem(LS)||'{{}}'))}}catch(e){{}}
let col=null;const arts=[...document.querySelectorAll('article.screen')];
function render(){{for(const a of arts){{const id=a.dataset.screen;const s=state[id]||{{}};for(const r of a.querySelectorAll('input[type=radio]'))r.checked=(r.value===s.choice);const n=a.querySelector('.dnote');if(document.activeElement!==n)n.value=s.note||'';a.querySelector('.saved').textContent=s.at?('saved '+new Date(s.at).toLocaleString()):'';}}}}
function persist(){{try{{localStorage.setItem(LS,JSON.stringify(state))}}catch(e){{}}}}
async function save(id,patch){{state[id]=Object.assign({{}},state[id]||{{}},patch,{{at:new Date().toISOString()}});persist();render();if(col){{try{{await col.doc(id).set(state[id])}}catch(e){{setSync(false,'Could not reach the shared record — kept on this device')}}}}}}
function setSync(on,msg){{const s=document.getElementById('sync');s.classList.toggle('on',on);s.textContent=msg}}
for(const a of arts){{const id=a.dataset.screen;for(const r of a.querySelectorAll('input[type=radio]'))r.addEventListener('change',()=>save(id,{{choice:r.value}}));const n=a.querySelector('.dnote');let t;n.addEventListener('input',()=>{{clearTimeout(t);t=setTimeout(()=>save(id,{{note:n.value}}),600)}});n.addEventListener('blur',()=>save(id,{{note:n.value}}));}}
render();
(async()=>{{let db=null;try{{db=window.claude&&await window.claude.use('db')}}catch(e){{}} if(!db)return;col=db.collection('decisions');col.onSnapshot(snap=>{{for(const d of snap.docs)if(d.exists)state[d.id]=Object.assign({{}},state[d.id]||{{}},d.data());persist();render();setSync(true,'Decisions are shared with Claude')}},()=>setSync(false,'Shared record unavailable — kept on this device'))}})();
}})();
</script>'''
open(OUT, 'w', encoding='utf-8').write(page)
print('groups', [g for g, _ in groups], 'screens', n_screens, 'directions', n_dirs, 'bytes', len(page))
