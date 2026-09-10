#!/usr/bin/env python3
"""Conformance checker for this workspace: OKF v0.1 + ICM stage contracts.

An independent consumer of the bundle -- it uses nothing but the files on disk,
which is the whole point of a format rather than a platform (OKF O9).

  ERROR -> exit 1. WARN -> reported, exit 0.
Usage: okf-check.py [--quiet]
"""
import re, sys, pathlib, collections

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import okf_fm

HOME = pathlib.Path.home() / "agents"
BUNDLES = [HOME / "memory", HOME / "references"]
PIPELINES = HOME / "pipelines"
UNINFORMATIVE = {"note", ""}
KNOWN_TYPES = {"index", "project", "decision", "entity", "reference",
               "runbook", "plan", "log", "spec", "stage"}

errors, warns = [], []
def err(m): errors.append(m)
def warn(m): warns.append(m)


def frontmatter(path):
    t = path.read_text()
    fields, body, n = okf_fm.split(t)
    if fields is None:
        return None, t
    return dict(fields), body


# ---- O3: frontmatter, with `type` the one required field ------------------
all_md = []
for b in BUNDLES:
    if not b.exists():
        err(f"bundle missing: {b}")
        continue
    all_md += sorted(b.rglob("*.md"))

for p in all_md:
    rel = p.relative_to(HOME)
    _f, _b, _n = okf_fm.split(p.read_text())
    if _n > 1:
        warn(f"{rel}: {_n} stacked frontmatter blocks — run okf-normalize.py")
    fm, _ = frontmatter(p)
    if fm is None:
        err(f"{rel}: no YAML frontmatter (O3)")
        continue
    t = fm.get("type", "").strip("'\"")
    if not t:
        err(f"{rel}: missing required field `type` (O3)")
    elif t in UNINFORMATIVE:
        err(f"{rel}: type '{t}' carries no information (SPEC §7.2)")
    elif t not in KNOWN_TYPES:
        warn(f"{rel}: unknown type '{t}' — fine per O7, listed for review")
    for conv in ("title", "description", "tags", "timestamp"):
        if conv not in fm:
            warn(f"{rel}: no `{conv}` (conventional, not required)")

# ---- O5: index.md everywhere, listing everything --------------------------
for b in BUNDLES:
    if not b.exists():
        continue
    for d in [b] + [x for x in b.rglob("*") if x.is_dir() and not x.name.startswith(".")]:
        idx = d / "index.md"
        rel = d.relative_to(HOME)
        if not idx.exists():
            err(f"{rel}/: no index.md (O5)")
            continue
        body = idx.read_text()
        for f in d.glob("*.md"):
            if f.name != "index.md" and f"({f.name})" not in body:
                err(f"{rel}/index.md: does not link {f.name} (O5)")

# ---- O4: every relative markdown link resolves ---------------------------
LINK = re.compile(r"\[[^\]]*\]\(([^)#\s]+\.md)[^)]*\)")
link_graph = collections.defaultdict(set)
for p in all_md + sorted(PIPELINES.rglob("*.md")) + [HOME / "CLAUDE.md",
                                                     HOME / "CONTEXT.md",
                                                     HOME / "AGENTS.md",
                                                     HOME / "SPEC.md"]:
    if not p.exists():
        continue
    for target in LINK.findall(p.read_text()):
        if target.startswith(("http://", "https://")):
            continue
        dest = (p.parent / target).resolve()
        if not dest.exists():
            err(f"{p.relative_to(HOME)}: dead link -> {target} (O4)")
        else:
            link_graph[p.resolve()].add(dest)

# ---- O4: no orphans — reachable from memory/index.md --------------------
root = (HOME / "memory" / "index.md").resolve()
seen, stack = {root}, [root]
for extra in (HOME / "CLAUDE.md", HOME / "CONTEXT.md", HOME / "AGENTS.md"):
    if extra.exists():
        seen.add(extra.resolve()); stack.append(extra.resolve())
while stack:
    for nxt in link_graph.get(stack.pop(), ()):
        if nxt not in seen:
            seen.add(nxt); stack.append(nxt)
for p in all_md:
    if p.resolve() not in seen:
        err(f"{p.relative_to(HOME)}: orphan — not reachable by links (O4)")

# ---- ICM I7: stage contracts declare Inputs / Process / Outputs ---------
stage_ct = 0
if PIPELINES.exists():
    for c in sorted(PIPELINES.rglob("CONTEXT.md")):
        rel = c.relative_to(HOME)
        body = c.read_text()
        is_stage = re.match(r"\d\d_", c.parent.name)
        if not is_stage:
            continue
        stage_ct += 1
        for sec in ("## Inputs", "## Process", "## Outputs"):
            if sec not in body:
                err(f"{rel}: stage contract missing `{sec}` (ICM I7)")
        if "## Verify" not in body:
            warn(f"{rel}: no `## Verify` section (ICM §6.2, recommended)")
        inputs = body.split("## Inputs", 1)[1].split("##", 1)[0]
        for line in inputs.strip().split("\n"):
            s = line.strip()
            if s.startswith("- ") and not re.search(r"Layer [34]", s):
                warn(f"{rel}: input not tagged Layer 3/4 — {s[:60]}")

# ---- report -------------------------------------------------------------
q = "--quiet" in sys.argv
if not q:
    print(f"checked {len(all_md)} concepts across "
          f"{len([b for b in BUNDLES if b.exists()])} bundles, {stage_ct} stage contracts")
for w in warns:
    print(f"  WARN  {w}")
for e in errors:
    print(f"  ERROR {e}")
print(f"\n{len(errors)} error(s), {len(warns)} warning(s)")
sys.exit(1 if errors else 0)
