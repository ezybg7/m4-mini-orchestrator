#!/opt/homebrew/bin/python3
"""Weekly token-burn report for the Multica board (Everett's decision t5, 2026-09-14).

Rolls up every run's usage record (multica issue runs <KEY> --output json -> usage[])
for the last --days days, with the previous window as a comparison, by agent, model
and card, priced at API list rates for Claude models (a proxy for how fast the plan's
weekly caps drain; Codex is reported in tokens only). Posts one Markdown comment on the
standing card (--issue) or prints it (--dry-run).

Usage: multica-usage-report.py --issue AMBR-nn [--days 7] [--dry-run]
"""
import argparse, collections, datetime, json, os, subprocess, sys

os.environ["PATH"] = "/usr/local/bin:/opt/homebrew/bin:" + os.environ.get("PATH", "")
# $/MTok: input, cache read, cache write (5-min), output. claude-api reference, cached 2026-06-24.
PRICE = {
    "claude-opus-5": (5.0, 0.50, 6.25, 25.0),
    "claude-sonnet-5": (2.0, 0.20, 2.50, 10.0),
    "claude-fable-5-1": (10.0, 0.25, 12.50, 50.0),
    "claude-haiku-4-5-20251001": (1.0, 0.10, 1.25, 5.0),
}
# Archived agents keep their old id; the live list does not name them.
ARCHIVED = {"be4d47df": "codex-reviewer (archived)", "3861132c": "retired reviewer seat", "8294f1d6": "probe agent",
            "51f1647a": "probe agent", "4370ec18": "retired seat", "71c871dc": "retired seat", "3899cfea": "retired seat"}

def mc(*args):
    r = subprocess.run(["multica", *args, "--output", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"multica {' '.join(args)} failed: {r.stderr.strip()[:300]}")
    return json.loads(r.stdout) if r.stdout.strip() else []

def items_of(d):
    if isinstance(d, list): return d
    for k in ("issues", "runs", "data", "items"):
        if isinstance(d, dict) and isinstance(d.get(k), list): return d[k]
    return []

def ts(s):
    return datetime.datetime.fromisoformat(s) if s else None

def usd(u):
    p = PRICE.get(u.get("model"))
    if not p: return None
    return (u.get("input_tokens", 0) * p[0] + u.get("cache_read_tokens", 0) * p[1]
            + u.get("cache_write_tokens", 0) * p[2] + u.get("output_tokens", 0) * p[3]) / 1e6

def fmt(n):
    n = float(n)
    return f"{n/1e9:.2f}B" if n >= 1e9 else f"{n/1e6:.1f}M" if n >= 1e6 else f"{n/1e3:.0f}K" if n >= 1e3 else f"{n:.0f}"

LEVERS_SINCE = "2026-09-14T04:00:00-04:00"   # compaction ceiling + targeted rounds + test-loop budget went live
def packs_since():
    try: return open(os.path.expanduser("~/agents/multica/.phase-packs-since")).read().strip()
    except OSError: return "9999-12-31T00:00:00Z"
ROLE = {"claude-implementer": "impl", "codex-implementer": "impl", "claude-reviewer": "rev", "claude-spec-reviewer": "rev",
        "codex-reviewer (archived)": "rev", "retired reviewer seat": "rev", "review-lead": "lead", "claude-planner": "plan"}

def phase_of(first_created):
    """Phase by the card's first run (ISO with offset). Compares in UTC."""
    t = ts(first_created).astimezone(datetime.timezone.utc)
    if t >= ts(packs_since().replace("Z", "+00:00")).astimezone(datetime.timezone.utc): return "packs"
    if t >= ts(LEVERS_SINCE).astimezone(datetime.timezone.utc): return "levers"
    return "baseline"

def card_scorecard(key, agents):
    runs = [r for r in items_of(mc("issue", "runs", key)) if r.get("status") == "completed" and r.get("usage")]
    if not runs: return None
    runs.sort(key=lambda r: r["created_at"])
    by = collections.defaultdict(lambda: dict(n=0, cr=0, out=0, usd=0.0, mins=0.0))
    tot = dict(n=0, cr=0, out=0, usd=0.0)
    for r in runs:
        role = ROLE.get(agents.get(r["agent_id"][:8], ""), "other")
        st, en = ts(r.get("started_at")), ts(r.get("completed_at"))
        mins = (en - st).total_seconds() / 60 if st and en else 0
        for u in r["usage"]:
            cr, out = u.get("cache_read_tokens", 0), u.get("output_tokens", 0); d = usd(u) or 0.0
            by[role]["cr"] += cr; by[role]["out"] += out; by[role]["usd"] += d; tot["cr"] += cr; tot["out"] += out; tot["usd"] += d
        by[role]["n"] += 1; by[role]["mins"] += mins; tot["n"] += 1
    meta = mc("issue", "get", key)
    rounds = (meta.get("metadata") or {}).get("review_round") if isinstance(meta, dict) else None
    return dict(key=key, phase=phase_of(runs[0]["created_at"]), first=runs[0]["created_at"][:16], runs=tot["n"], cr=tot["cr"], out=tot["out"], usd=tot["usd"], rounds=rounds,
                impl=by["impl"], rev=by["rev"], lead=by["lead"])

def phase_report(a):
    agents = {ag["id"][:8]: ag["name"] for ag in items_of(mc("agent", "list"))}; agents.update({k: v for k, v in ARCHIVED.items() if k not in agents})
    if a.card:
        c = card_scorecard(a.card, agents)
        if not c: print("no completed runs with usage on", a.card); return
        print(f"{c['key']} · phase {c['phase']} · first run {c['first']} · rounds {c['rounds']} · {c['runs']} runs · reads {fmt(c['cr'])} · out {fmt(c['out'])} · ${c['usd']:.0f}")
        for role in ("impl", "rev", "lead"):
            g = c[role]; print(f"  {role:5} runs {g['n']:2d} · reads/run {fmt(g['cr']/max(g['n'],1)):>7} · out {fmt(g['out']):>6} · ${g['usd']:.0f} · {g['mins']/max(g['n'],1):.0f} min/run")
        return
    issues = []; offset = 0
    while True:
        page = mc("issue", "list", "--limit", "100", "--offset", str(offset), "--fields", "identifier,title,status,metadata"); batch = items_of(page); issues.extend(batch)
        if not batch or not (isinstance(page, dict) and page.get("has_more")): break
        offset += len(batch)
    cards = []
    for i in issues:
        if not (i.get("metadata") or {}).get("review_round"): continue   # loop cards only: they went through build + review
        c = card_scorecard(i["identifier"], agents)
        if c: c["title"] = (i.get("title") or "")[:48]; cards.append(c)
    cards.sort(key=lambda c: c["first"])
    print(f"| Card | Phase | Rounds | Runs | Reads | Impl reads/run | Rev reads/run | $-equiv |")
    print("|---|---|---:|---:|---:|---:|---:|---:|")
    for c in cards:
        print(f"| {c['key']} {c['title']} | {c['phase']} | {c['rounds']} | {c['runs']} | {fmt(c['cr'])} | {fmt(c['impl']['cr']/max(c['impl']['n'],1))} | {fmt(c['rev']['cr']/max(c['rev']['n'],1))} | ${c['usd']:.0f} |")
    import statistics
    print()
    print("| Phase | Cards | Median $ | Median reads | Median rounds | Median impl reads/run | Median rev reads/run |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    for ph in ("baseline", "levers", "packs"):
        cs = [c for c in cards if c["phase"] == ph and c["usd"] > 0]
        if not cs: print(f"| {ph} | 0 | — | — | — | — | — |"); continue
        med = lambda f: statistics.median(f(c) for c in cs)
        print(f"| {ph} | {len(cs)} | ${med(lambda c: c['usd']):.0f} | {fmt(med(lambda c: c['cr']))} | {med(lambda c: c['rounds'] or 0):.0f} | {fmt(med(lambda c: c['impl']['cr']/max(c['impl']['n'],1)))} | {fmt(med(lambda c: c['rev']['cr']/max(c['rev']['n'],1)))} |")
    print(f"\n_Phases by each card's first run: baseline < {LEVERS_SINCE[:16]} (before the ceiling, targeted rounds and test budget) · levers until the pack rollout ({packs_since()[:16]}) · packs after. Claude $-equivalent at API list rates; Codex-only cards show $0._")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issue", default=os.environ.get("MULTICA_USAGE_CARD", ""))
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--card", default="", help="print a scorecard for one card (reads/run by role, rounds, phase) and exit")
    ap.add_argument("--phases", action="store_true", help="print the before/after table by phase (baseline · levers · packs) and exit")
    a = ap.parse_args()
    if a.card or a.phases:
        return phase_report(a)
    now = datetime.datetime.now().astimezone()
    w1 = now - datetime.timedelta(days=a.days)          # this window start
    w0 = now - datetime.timedelta(days=2 * a.days)      # previous window start
    agents = {ag["id"][:8]: ag["name"] for ag in items_of(mc("agent", "list"))}
    agents.update({k: v for k, v in ARCHIVED.items() if k not in agents})
    issues, offset = [], 0
    while True:  # the server pages at 100; json output carries has_more
        page = mc("issue", "list", "--limit", "100", "--offset", str(offset), "--fields", "identifier,title,status")
        batch = items_of(page); issues.extend(batch)
        if not batch or not (isinstance(page, dict) and page.get("has_more")): break
        offset += len(batch)
    title = {i["identifier"]: (i.get("title") or "")[:60] for i in issues}

    # per window: agent, model, card, run rows
    W = {"cur": collections.defaultdict(lambda: collections.defaultdict(float)),
         "prev": collections.defaultdict(lambda: collections.defaultdict(float))}
    runs_rows = []
    counts = {"cur": collections.Counter(), "prev": collections.Counter()}
    for key in title:
        for r in items_of(mc("issue", "runs", key)):
            c = ts(r.get("created_at"))
            if not c or c < w0: continue
            win = "cur" if c >= w1 else "prev"
            counts[win]["runs"] += 1
            if r.get("status") == "failed": counts[win]["failed"] += 1
            agent = agents.get((r.get("agent_id") or "")[:8], (r.get("agent_id") or "?")[:8])
            tot_cr = tot_out = 0; tot_usd = 0.0; codex = False
            for u in (r.get("usage") or []):
                d = usd(u)
                m = u.get("model") or "unknown"
                cr, out, cw, inp = (u.get("cache_read_tokens", 0), u.get("output_tokens", 0),
                                    u.get("cache_write_tokens", 0), u.get("input_tokens", 0))
                tot_cr += cr; tot_out += out
                for g in (W[win][("agent", agent)], W[win][("model", m)], W[win][("card", key)], W[win][("total", "")]):
                    g["cr"] += cr; g["out"] += out; g["cw"] += cw; g["inp"] += inp; g["n"] += 0
                    if d is not None: g["usd"] += d
                    else: g["codex_cr"] += cr; g["codex_out"] += out
                if d is None: codex = True
                else: tot_usd += d
            for g in (W[win][("agent", agent)], W[win][("card", key)], W[win][("total", "")]): g["n"] += 1
            if win == "cur":
                st, en = ts(r.get("started_at")), ts(r.get("completed_at"))
                mins = (en - st).total_seconds() / 60 if st and en else 0
                runs_rows.append((tot_cr + tot_out, key, agent, ",".join(sorted({u.get("model", "?")[:16] for u in (r.get("usage") or [])})),
                                  tot_cr, tot_out, tot_usd if not codex else None, mins))

    def row(kind, name, win):
        return W[win].get((kind, name)) or collections.defaultdict(float)
    cur_t, prev_t = row("total", "", "cur"), row("total", "", "prev")
    L = []
    L.append(f"## Token burn — {a.days} days ending {now:%Y-%m-%d} (vs the {a.days} days before)")
    L.append("")
    L.append(f"Runs **{counts['cur']['runs']}** (prev {counts['prev']['runs']}) · failed {counts['cur']['failed']} (prev {counts['prev']['failed']}) · "
             f"cache reads **{fmt(cur_t['cr'])}** (prev {fmt(prev_t['cr'])}) · output **{fmt(cur_t['out'])}** (prev {fmt(prev_t['out'])}) · "
             f"Claude $-equiv **${cur_t['usd']:,.0f}** (prev ${prev_t['usd']:,.0f}) · Codex reads {fmt(cur_t['codex_cr'])} (prev {fmt(prev_t['codex_cr'])})")
    L.append("")
    L.append("| Agent | runs | cache read | output | reads/run | $-equiv | prev $ |")
    L.append("|---|---:|---:|---:|---:|---:|---:|")
    ag_rows = sorted([(k[1], v) for k, v in W["cur"].items() if k[0] == "agent"], key=lambda kv: -(kv[1]["usd"] * 1e9 + kv[1]["cr"]))
    for name, v in ag_rows:
        pv = row("agent", name, "prev")
        money = f"${v['usd']:,.0f}" if v["usd"] else ("codex" if v["codex_cr"] else "$0")
        L.append(f"| {name} | {int(v['n'])} | {fmt(v['cr'])} | {fmt(v['out'])} | {fmt(v['cr']/max(v['n'],1))} | {money} | {('$%.0f' % pv['usd']) if pv['usd'] else '—'} |")
    L.append("")
    L.append("| Model | cache read | cache write | output | $-equiv | prev $ |")
    L.append("|---|---:|---:|---:|---:|---:|")
    for k, v in sorted([(k, v) for k, v in W["cur"].items() if k[0] == "model"], key=lambda kv: -kv[1]["cr"]):
        pv = row("model", k[1], "prev")
        L.append(f"| {k[1]} | {fmt(v['cr'])} | {fmt(v['cw'])} | {fmt(v['out'])} | {('$%.0f' % v['usd']) if v['usd'] else 'n/a'} | {('$%.0f' % pv['usd']) if pv['usd'] else '—'} |")
    L.append("")
    L.append("| Card | runs | cache read | output | $-equiv |")
    L.append("|---|---:|---:|---:|---:|")
    for k, v in sorted([(k, v) for k, v in W["cur"].items() if k[0] == "card"], key=lambda kv: -(kv[1]["usd"] * 1e9 + kv[1]["cr"]))[:12]:
        L.append(f"| {k[1]} {title.get(k[1],'')} | {int(v['n'])} | {fmt(v['cr'])} | {fmt(v['out'])} | {('$%.0f' % v['usd']) if v['usd'] else ('codex' if v['codex_cr'] else '$0')} |")
    L.append("")
    L.append("Top runs this window (cache read · output · minutes):")
    for _, key, agent, model, cr, out, d, mins in sorted(runs_rows, reverse=True)[:6]:
        L.append(f"- {key} · {agent} · {model} · {fmt(cr)} · {fmt(out)} · {mins:.0f} min · {('$%.0f' % d) if d is not None else 'codex'}")
    L.append("")
    L.append("_Prices: API list rates (Opus 5 $5/$0.50/$6.25/$25 per MTok input/cache read/cache write/output; Sonnet 5 $2/$0.20/$2.50/$10; Fable 5.1 $10/$0.25/$12.50/$50) — a proxy for how fast the plan's weekly caps drain, not a bill. A run's cost is turns × context; reads/run is the number to watch. Source: `multica issue runs <KEY> --output json`. Script: `~/agents/scripts/multica-usage-report.py`._")
    # before/after by phase, appended to every weekly report
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try: phase_report(argparse.Namespace(card="", phases=True))
        except Exception as e: print(f"(phase table unavailable: {e})")
    L.append(""); L.append("### Before / after, by card phase"); L.append(buf.getvalue().rstrip())
    body = "\n".join(L)
    if a.dry_run or not a.issue:
        print(body); return
    r = subprocess.run(["multica", "issue", "comment", "add", a.issue, "--content-stdin", "--output", "json"], input=body, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"comment add failed: {r.stderr.strip()[:300]}")
    print(f"posted to {a.issue}: {len(body)} chars")

if __name__ == "__main__":
    main()
