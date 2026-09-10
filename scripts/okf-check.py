#!/usr/bin/env python3
"""Conformance checker: OKF v0.1 + ICM stage contracts, over the whole workspace.

An independent consumer -- it uses nothing but the files on disk, which is the
point of a format rather than a platform (OKF O9).

  ERROR -> exit 1.  WARN -> reported, exit 0.
Usage: okf-check.py [--quiet]
"""
import re, sys, pathlib, collections

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import okf_fm

HOME = pathlib.Path.home() / "agents"
UNINFORMATIVE = {"note", ""}
KNOWN_TYPES = {"index", "project", "decision", "entity", "reference",
               "runbook", "plan", "log", "spec", "stage"}

# Each area declares which filename acts as its index and which subdirectories
# are exempt from needing one. pipelines/ uses CONTEXT.md as its index: a stage
# contract IS the index of its folder.
AREAS = [
    {"root": "memory",     "index": "index.md",   "exempt": set()},
    {"root": "references", "index": "index.md",   "exempt": set()},
    {"root": "pipelines",  "index": "CONTEXT.md", "exempt": {"output", "references"},
     "root_index": "index.md"},
    {"root": "runs",       "index": None,         "exempt": set(),
     "root_index": "index.md"},          # run folders are disposable, exempt
]
# NOTE: no AGENTS.md. Codex walks up for the nearest one and its sandbox denies
# ~/agents/**, so an AGENTS.md here is fatal to it. See the 2026-09-10 decision.
ROOT_DOCS = ["CLAUDE.md", "CONTEXT.md", "SPEC.md"]

errors, warns = [], []
def err(m): errors.append(m)
def warn(m): warns.append(m)


def fm_of(path):
    fields, body, n = okf_fm.split(path.read_text())
    return (dict(fields) if fields else None), body, n


def rel(p):
    return str(p.relative_to(HOME))


# ---- O3: every concept carries frontmatter, with `type` required -----------
concepts = []
for area in AREAS:
    root = HOME / area["root"]
    if not root.exists():
        err(f"area missing: {area['root']}")
        continue
    for p in sorted(root.rglob("*.md")):
        # per-run artifacts under a stage's output/ are Layer 4, not concepts
        if "output" in p.relative_to(root).parts:
            continue
        if area["root"] == "runs" and p.name != "index.md":
            continue
        concepts.append(p)
concepts += [HOME / d for d in ROOT_DOCS if (HOME / d).exists()]

for p in concepts:
    fm, _, nblocks = fm_of(p)
    if nblocks > 1:
        warn(f"{rel(p)}: {nblocks} stacked frontmatter blocks — run okf-normalize.py")
    if fm is None:
        err(f"{rel(p)}: frontmatter is unparseable (O3)")
        continue
    t = fm.get("type", "").strip("'\"")
    if not t:
        err(f"{rel(p)}: missing required field `type` (O3)")
    elif t in UNINFORMATIVE:
        err(f"{rel(p)}: type '{t}' carries no information (SPEC §7.2)")
    elif t not in KNOWN_TYPES:
        warn(f"{rel(p)}: unknown type '{t}' — allowed by O7, listed for review")
    for conv in ("title", "description", "tags", "timestamp"):
        if conv not in fm:
            warn(f"{rel(p)}: no `{conv}` (conventional, not required)")
    # O3 requires YAML that a parser can actually read
    for k, v in (fm or {}).items():
        v = v.strip()
        if v[:1] not in ("'", '"', "[", "{", "") and (": " in v or v.endswith(":")):
            err(f"{rel(p)}: `{k}` is invalid YAML — unquoted value contains ': ' "
                f"(run okf-normalize.py)")
        # A quoted value can be just as broken: inside single quotes an internal
        # apostrophe must be doubled. "Hermes's" silently breaks the quoting, and
        # a parser that then cannot read the file prepends its own frontmatter
        # block instead of merging -- which is the write loop, all over again.
        if v[:1] == "'" and v[-1:] == "'" and len(v) > 1:
            inner = v[1:-1]
            if len(re.findall(r"(?<!')'(?!')", inner.replace("''", ""))) or \
               inner.replace("''", "").count("'"):
                err(f"{rel(p)}: `{k}` has an unescaped apostrophe inside single "
                    f"quotes — double it as '' (run okf-normalize.py)")

# ---- O5: an index at every level, listing everything in it ----------------
for area in AREAS:
    root = HOME / area["root"]
    if not root.exists():
        continue
    ri = area.get("root_index")
    if ri and not (root / ri).exists():
        err(f"{area['root']}/: no {ri} (O5)")
    if area["index"] is None:
        continue
    dirs = [root] + [d for d in root.rglob("*") if d.is_dir()
                     and not d.name.startswith(".")]
    for d in dirs:
        parts = set(d.relative_to(root).parts)
        if parts & area["exempt"]:
            continue
        idx = d / area["index"]
        if d == root and ri:
            idx = root / ri
        if not idx.exists():
            err(f"{rel(d)}/: no {area['index']} (O5)")
            continue
        body = idx.read_text()
        for f in d.glob("*.md"):
            if f.name in (idx.name, area["index"]):
                continue
            if f"({f.name})" not in body:
                err(f"{rel(idx)}: does not link {f.name} (O5)")

# ---- O4: every relative markdown link resolves ---------------------------
LINK = re.compile(r"\[[^\]]*\]\(([^)#\s]+\.md)[^)]*\)")
graph = collections.defaultdict(set)
for p in concepts:
    for target in LINK.findall(p.read_text()):
        if target.startswith(("http://", "https://")):
            continue
        dest = (p.parent / target).resolve()
        if not dest.exists():
            err(f"{rel(p)}: dead link -> {target} (O4)")
        else:
            graph[p.resolve()].add(dest)

# ---- O4: no orphans — reachable from the entry points -------------------
roots = [(HOME / d).resolve() for d in ROOT_DOCS if (HOME / d).exists()]
roots.append((HOME / "memory" / "index.md").resolve())
seen, stack = set(roots), list(roots)
while stack:
    for nxt in graph.get(stack.pop(), ()):
        if nxt not in seen:
            seen.add(nxt); stack.append(nxt)
for p in concepts:
    if p.resolve() not in seen:
        err(f"{rel(p)}: orphan — not reachable by links (O4)")

# ---- ICM I7: stage contracts declare Inputs / Process / Outputs ---------
stages = 0
for c in sorted((HOME / "pipelines").rglob("CONTEXT.md")):
    if not re.match(r"\d\d_", c.parent.name):
        continue
    stages += 1
    body = c.read_text()
    for sec in ("## Inputs", "## Process", "## Outputs"):
        if sec not in body:
            err(f"{rel(c)}: stage contract missing `{sec}` (ICM I7)")
    if "## Verify" not in body:
        warn(f"{rel(c)}: no `## Verify` section (ICM §6.2, recommended)")
    if "## Inputs" in body:
        for line in body.split("## Inputs", 1)[1].split("##", 1)[0].strip().split("\n"):
            s = line.strip()
            if s.startswith("- ") and not re.search(r"Layer [34]", s):
                warn(f"{rel(c)}: input not tagged Layer 3/4 — {s[:60]}")
    # ICM I4: the edit surface has to exist
    if not (c.parent / "output").is_dir():
        err(f"{rel(c.parent)}/: no output/ — nothing for a human to edit (ICM I4)")

# ---- ICM budgets (advisory) --------------------------------------------
BUDGET = {"CLAUDE.md": 800, "CONTEXT.md": 300}
for name, budget in BUDGET.items():
    f = HOME / name
    if f.exists():
        tok = len(f.read_text().split()) * 4 // 3
        if tok > budget:
            warn(f"{name}: ~{tok} tokens over the ICM Layer budget of {budget}")
for c in sorted((HOME / "pipelines").rglob("CONTEXT.md")):
    if re.match(r"\d\d_", c.parent.name):
        tok = len(c.read_text().split()) * 4 // 3
        if tok > 500:
            warn(f"{rel(c)}: ~{tok} tokens over the ICM stage budget of 500")

# ---- report ------------------------------------------------------------
if "--quiet" not in sys.argv:
    print(f"checked {len(concepts)} documents across {len(AREAS)} areas, "
          f"{stages} stage contracts")
for w in warns:
    print(f"  WARN  {w}")
for e in errors:
    print(f"  ERROR {e}")
print(f"\n{len(errors)} error(s), {len(warns)} warning(s)")
sys.exit(1 if errors else 0)
