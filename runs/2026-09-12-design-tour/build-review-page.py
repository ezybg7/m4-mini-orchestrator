#!/usr/bin/env python3
"""Build the screen-review handoff page from scores*.md + thumbs/. Output: review.html (in this dir).
Each proposed change is a decision with a note field; answers land in the artifact's `decisions` collection."""
import base64, html, json, os, re, sys, datetime

R = os.path.dirname(os.path.abspath(__file__))
SCORE_FILES = [f"{R}/scores.md", f"{R}/scores-2.md", f"{R}/scores-3.md"]
THUMBS = f"{R}/thumbs"
ROUTES = {}
try:
    idx = json.load(open(f"{R}/shots/index.json"))
    items = idx.get("screens", idx) if isinstance(idx, dict) else idx
    rows = items.items() if isinstance(items, dict) else [(i.get("name"), i) for i in items]
    for name, info in rows:
        ROUTES[name] = info.get("routes") or info.get("route_files") or info.get("files") or []
except Exception:
    pass

HEAD_RE = re.compile(r"^## (?P<name>[^—\n]+?)\s*(?:\((?P<alias>[^)]*)\))?\s*—\s*(?P<total>\d+)/40\s*\((?P<parts>[^)]*)\)", re.M)

def parse(path):
    if not os.path.exists(path):
        return []
    s = open(path).read()
    out = []
    heads = list(HEAD_RE.finditer(s))
    for i, m in enumerate(heads):
        body = s[m.end(): heads[i + 1].start() if i + 1 < len(heads) else len(s)].strip()
        name = m.group("name").strip()
        key = re.sub(r"\s.*$", "", name)  # first token = screenshot name (e.g. "profile" from "profile (behaviour …)")
        changes = ""
        cm = re.search(r"Changes:\s*(.*)", body, re.S)
        if cm:
            changes = cm.group(1).strip()
            body = body[: cm.start()].strip()
        parts = dict(re.findall(r"([A-Za-z]+)(\d)", m.group("parts")))
        out.append({"name": name, "key": key, "total": int(m.group("total")), "parts": parts, "body": body, "changes": changes})
    return out

screens = []
for f in SCORE_FILES:
    screens += parse(f)

def thumb(mode, key):
    p = f"{THUMBS}/{mode}/{key}.jpg"
    if not os.path.exists(p):
        return None
    return "data:image/jpeg;base64," + base64.b64encode(open(p, "rb").read()).decode()

def esc(t):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    return t

PRINCIPLES = [("P", "Purpose"), ("A", "Agency"), ("R", "Responsibility"), ("Fa", "Familiarity"), ("Fl", "Flexibility"), ("S", "Simplicity"), ("C", "Craft"), ("D", "Delight")]

def score_bar(parts):
    cells = []
    for k, label in PRINCIPLES:
        v = parts.get(k)
        cells.append(f'<span class="pp" title="{label}"><i>{label[:2] if k!="Fl" and k!="Fa" else label[:3]}</i>{v if v else "–"}</span>')
    return "".join(cells)

# ---- systemic decisions (cross-screen), authored here ----
SYSTEMIC = json.load(open(f"{R}/systemic.json")) if os.path.exists(f"{R}/systemic.json") else []

def sys_items():
    out = []
    for i, s in enumerate(SYSTEMIC, 1):
        out.append(f'''
    <li class="d headline" data-id="{s['id']}"><span class="num">S{i} · {esc(s['scope'])}</span><span class="tag">{esc(s.get('tag','needs you'))}</span>
      <h3>{esc(s['title'])}</h3>
      <p>{esc(s['why'])}</p>
      <div class="default"><b>Proposed:</b> {esc(s['proposal'])}</div>
      {('<p class="small">Evidence: ' + esc(s['evidence']) + '</p>') if s.get('evidence') else ''}
      <div class="answer"><textarea placeholder="sure / not now / do it differently: …"></textarea><button>Decided</button></div><div class="saved"></div>
    </li>''')
    return "\n".join(out)

def screen_cards():
    out = []
    for sc in sorted(screens, key=lambda x: x["total"]):
        key = sc["key"]
        imgs = []
        for mode, label in (("light", "Light"), ("dark", "Dark"), ("ax5", "Largest text")):
            t = thumb(mode, key)
            if t:
                imgs.append(f'<figure><img src="{t}" alt="{esc(sc["name"])} — {label}" loading="lazy"><figcaption>{label}</figcaption></figure>')
        routes = ", ".join(ROUTES.get(key, []))
        grade = "low" if sc["total"] < 29 else ("mid" if sc["total"] < 33 else "high")
        out.append(f'''
    <li class="d screen" data-id="s-{html.escape(key)}" id="s-{html.escape(key)}"><span class="tag {grade}">{sc['total']} / 40</span>
      <h3>{esc(sc['name'])}</h3>
      {('<p class="route mono">' + html.escape(routes) + '</p>') if routes else ''}
      <div class="bar">{score_bar(sc['parts'])}</div>
      <div class="shots">{''.join(imgs)}</div>
      <p>{esc(sc['body'])}</p>
      {('<div class="default"><b>Proposed changes:</b> ' + esc(sc['changes']) + '</div>') if sc['changes'] else ''}
      <div class="answer"><textarea placeholder="sure / skip / notes"></textarea><button>Decided</button></div><div class="saved"></div>
    </li>''')
    return "\n".join(out)

n = len(screens); avg = sum(s["total"] for s in screens) / max(n, 1)
lowest = sorted(screens, key=lambda x: x["total"])[:5]
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

page = f'''<title>Ambry Screen Review</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bitter:wght@500;600&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{{--paper:#F2F4F6;--surface:#FFFFFF;--ink:#1A1F26;--muted:#5A6572;--line:#D3D9DF;--accent:#2C5A85;--accent-ink:#FFFFFF;--you:#A4491A;--you-soft:#FBEFE7;--ok:#2C7A4B;--ok-soft:#E5F3EA;--warn:#8A6D1F;--warn-soft:#F8F0D8;--code-bg:#EAEEF2;--note-bg:#FAFBFC;--focus:#2C5A85}}
@media (prefers-color-scheme: dark){{:root:not([data-theme="light"]){{--paper:#13171C;--surface:#1B2027;--ink:#E4E8EC;--muted:#98A3AE;--line:#2E3742;--accent:#7FB0E0;--accent-ink:#0F1418;--you:#E6925C;--you-soft:#2C2119;--ok:#6FC08F;--ok-soft:#172A1E;--warn:#D9B85A;--warn-soft:#2B2612;--code-bg:#0F1318;--note-bg:#161B21;--focus:#7FB0E0}}}}
:root[data-theme="dark"]{{--paper:#13171C;--surface:#1B2027;--ink:#E4E8EC;--muted:#98A3AE;--line:#2E3742;--accent:#7FB0E0;--accent-ink:#0F1418;--you:#E6925C;--you-soft:#2C2119;--ok:#6FC08F;--ok-soft:#172A1E;--warn:#D9B85A;--warn-soft:#2B2612;--code-bg:#0F1318;--note-bg:#161B21;--focus:#7FB0E0}}
*{{box-sizing:border-box}}
body{{background:var(--paper);color:var(--ink);font-family:"IBM Plex Sans",-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;font-size:15.5px;line-height:1.55;margin:0}}
main{{max-width:84ch;margin:0 auto;padding:40px 22px 80px}}
h1,h2,h3{{font-family:Bitter,Georgia,"Times New Roman",serif;text-wrap:balance;line-height:1.2;margin:0}}
h1{{font-size:30px;font-weight:600}} h2{{font-size:21px;font-weight:600;margin-top:44px;padding-top:18px;border-top:1px solid var(--line)}} h3{{font-size:16.5px;font-weight:600}}
p{{margin:10px 0}} .eyebrow{{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:500;margin-bottom:6px}} .lede{{color:var(--muted);margin-top:8px;max-width:72ch}}
code,pre,.mono{{font-family:"IBM Plex Mono",ui-monospace,Menlo,Consolas,monospace}} code{{background:var(--code-bg);padding:1px 5px;border-radius:3px;font-size:.92em}}
.strip{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:26px 0 6px}} .tile{{background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:14px 16px}} .tile .n{{font-family:Bitter,Georgia,serif;font-size:30px;font-weight:600;font-variant-numeric:tabular-nums;line-height:1}} .tile .l{{color:var(--muted);font-size:13px;margin-top:6px}}
ol.decisions{{list-style:none;padding:0;margin:18px 0 0;display:flex;flex-direction:column;gap:14px}}
.d{{background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:16px 18px 14px;position:relative}} .d.headline{{border-left:4px solid var(--you)}}
.d .num{{position:absolute;left:-2px;top:-12px;background:var(--paper);color:var(--muted);font-size:12px;letter-spacing:.06em;padding:0 8px}} .d h3{{padding-right:110px}}
.tag{{position:absolute;right:16px;top:16px;font-size:11.5px;letter-spacing:.06em;text-transform:uppercase;padding:3px 8px;border-radius:999px;background:var(--you-soft);color:var(--you);font-weight:500;font-variant-numeric:tabular-nums}}
.tag.high{{background:var(--ok-soft);color:var(--ok)}} .tag.mid{{background:var(--warn-soft);color:var(--warn)}} .tag.low{{background:var(--you-soft);color:var(--you)}}
.default{{margin:8px 0 0;padding:8px 12px;background:var(--note-bg);border-left:3px solid var(--accent);border-radius:0 4px 4px 0;font-size:14.5px}} .default b{{color:var(--accent)}}
.route{{font-size:12px;color:var(--muted);margin:2px 0 8px}}
.bar{{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0 10px}} .pp{{font-size:12px;background:var(--code-bg);border-radius:4px;padding:2px 7px;font-variant-numeric:tabular-nums}} .pp i{{font-style:normal;color:var(--muted);margin-right:4px}}
.shots{{display:flex;gap:10px;overflow-x:auto;padding:4px 0 6px}} figure{{margin:0;flex:0 0 auto}} figure img{{width:190px;height:auto;border:1px solid var(--line);border-radius:10px;display:block}} figcaption{{font-size:12px;color:var(--muted);text-align:center;margin-top:4px}}
.answer{{display:flex;gap:10px;align-items:flex-start;margin-top:12px}} textarea{{flex:1;min-height:44px;resize:vertical;font:inherit;font-size:14px;color:var(--ink);background:var(--note-bg);border:1px solid var(--line);border-radius:4px;padding:8px 10px}}
textarea:focus,button:focus{{outline:2px solid var(--focus);outline-offset:2px}} button{{font:inherit;font-size:13.5px;font-weight:500;padding:9px 14px;border-radius:4px;border:1px solid var(--accent);background:var(--accent);color:var(--accent-ink);cursor:pointer;white-space:nowrap}} button[disabled]{{opacity:.55;cursor:default}}
.saved{{font-size:13px;color:var(--ok);margin-top:6px;min-height:1.2em}} .saved.err{{color:var(--you)}} .small{{font-size:13px;color:var(--muted)}} #dbnote{{font-size:13px;color:var(--muted);margin-top:10px}}
.toc{{columns:2;column-gap:24px;font-size:14px;margin:12px 0 0}} .toc a{{color:var(--accent);text-decoration:none}} .toc li{{break-inside:avoid;margin:2px 0}}
@media (max-width:640px){{.strip{{grid-template-columns:1fr 1fr}}.d h3{{padding-right:0}}.tag{{position:static;display:inline-block;margin-top:6px}}.toc{{columns:1}}}}
</style>
<main>
  <div class="eyebrow">Ambry · design re-evaluation · {now}</div>
  <h1>Screen review</h1>
  <p class="lede">Every screen the app has, captured on the iPhone 17 Pro simulator from a Release build on a disposable copy of production, in light, dark and the largest accessibility text size, and scored against Apple's June 2026 Human Interface Guidelines: the eight principles (1–5 each, 40 total), the hard numbers (44 pt targets, 4.5:1 contrast, largest text, the eight states), and the thirteen rules that apply specifically to this Expo stack (<code>docs/research/hig-2026-for-ambry.md</code>). Cross-screen decisions come first because one answer there settles many screens; then each screen, lowest score first, with its shots, findings and proposed changes. Type an answer and press <em>Decided</em>; a terse "sure" takes the proposal.</p>
  <div class="strip">
    <div class="tile"><div class="n">{n}</div><div class="l">screens scored</div></div>
    <div class="tile"><div class="n">{avg:.1f}</div><div class="l">average of 40</div></div>
    <div class="tile"><div class="n">{len(SYSTEMIC)}</div><div class="l">cross-screen decisions</div></div>
    <div class="tile"><div class="n">{sum(1 for s in screens if s['changes'])}</div><div class="l">screens with proposed changes</div></div>
  </div>
  <p id="dbnote">Answers save to this page's shared store when it is opened in Claude. If that is unavailable here, reply in chat with the item name.</p>
  <p class="small"><b>Lowest five:</b> {" · ".join(esc(s['name']) + ' ' + str(s['total']) for s in lowest)}</p>
  <p class="small"><b>What was captured:</b> a Release build of <code>main</code> at <code>b40d2bf</code> (with the recipe comments, following and frozen-category work merged today), 46 screens in light and dark and 26 at the largest text size — the 20 the tour cannot reach at that size are themselves the finding in S6. Three screens were reached by deep link (first run, onboarding, the Plus paywall with billing off). <b>Not captured:</b> a stranger's creator profile (Follow / Report — needs a second user's public recipe), the reset-password and join-by-invite screens (need live tokens), and the paywall's live purchase state.</p>

  <h2>Cross-screen decisions</h2>
  <ol class="decisions" id="systemic">{sys_items()}</ol>

  <h2>Every screen, lowest first</h2>
  <ul class="toc">{"".join(f'<li><a href="#s-{html.escape(s["key"])}">{esc(s["name"])}</a> — {s["total"]}</li>' for s in sorted(screens, key=lambda x: x["total"]))}</ul>
  <ol class="decisions" id="screens">{screen_cards()}</ol>
</main>
<script>
(function(){{
  const items = Array.from(document.querySelectorAll('li.d')); const note = document.getElementById('dbnote');
  function mark(li, data){{ const tag = li.querySelector('.tag'); const saved = li.querySelector('.saved');
    if (data && data.decided){{ if (li.classList.contains('headline')) {{ tag.textContent = 'decided'; }} saved.textContent = 'Answered' + (data.at ? ' ' + new Date(data.at).toLocaleString() : '') + (data.note ? ': ' + data.note : ' (default)'); li.querySelector('textarea').value = data.note || ''; }} }}
  items.forEach(li => {{ const btn = li.querySelector('button'); const ta = li.querySelector('textarea'); const saved = li.querySelector('.saved');
    btn.addEventListener('click', async () => {{ const db = await claude.use('db'); if (!db){{ saved.textContent = 'Not saved here — reply in chat with the item name.'; saved.classList.add('err'); return; }}
      btn.disabled = true; const data = {{ note: ta.value.trim(), decided: true, at: new Date().toISOString() }};
      try {{ await db.doc('decisions/' + li.dataset.id).set(data); mark(li, data); saved.classList.remove('err'); saved.textContent = 'Saved.'; }} catch (e){{ saved.textContent = 'Could not save (' + (e && e.code || 'error') + ') — reply in chat.'; saved.classList.add('err'); }}
      btn.disabled = false; }}); }});
  claude.use('db').then(db => {{ if (!db){{ note.textContent = 'Answers cannot be saved from this view — reply in chat with the item name.'; return; }} note.textContent = 'Answers save to this page and are read back by the orchestrator.';
    db.collection('decisions').onSnapshot(snap => {{ snap.docs.forEach(d => {{ const li = document.querySelector('li.d[data-id="' + d.id + '"]'); if (li && d.exists) mark(li, d.data()); }}); }}, () => {{}}); }});
}})();
</script>
'''
open(f"{R}/review.html", "w").write(page)
print(f"review.html: {n} screens, avg {avg:.1f}, {len(SYSTEMIC)} systemic, {os.path.getsize(f'{R}/review.html')//1024} KB")
