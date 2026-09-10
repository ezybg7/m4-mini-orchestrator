#!/usr/bin/env python3
"""Generate OKF index.md files from the bundle's own frontmatter.

OKF O5: index.md at every level, for progressive disclosure as an agent
navigates down. This is a *consumer* of the bundle -- it reads only the
structured frontmatter fields, exactly as any other consumer would (O8).

Hand-written prose between <!--okf:intro--> and <!--/okf:intro--> is preserved
across regeneration; everything after <!--okf:generated--> is rewritten.

Usage: okf-index.py <root>...
"""
import re, sys, pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import okf_fm

GEN = "<!--okf:generated-->"
INTRO_RE = re.compile(r"<!--okf:intro-->(.*?)<!--/okf:intro-->", re.S)


def frontmatter(path):
    """Frontmatter with YAML quoting removed -- an index row is display text.

    Values containing ": " must be quoted in the file to stay valid YAML, but the
    quotes are syntax, not content, and rendering them makes every such row read
    as 'Some description... instead of Some description...
    """
    return {k: v.strip().strip("'\"") for k, v in okf_fm.get(path.read_text()).items()}


def build(d: pathlib.Path, root_name: str):
    existing = (d / "index.md").read_text() if (d / "index.md").exists() else ""
    m = INTRO_RE.search(existing)
    intro = m.group(1).strip() if m else ""

    subdirs = sorted(p for p in d.iterdir() if p.is_dir() and not p.name.startswith("."))
    files = sorted(p for p in d.iterdir()
                   if p.suffix == ".md" and p.name != "index.md")

    title = d.name if d.name != root_name else root_name

    # Carry through any frontmatter key this generator does not own -- notably
    # basic-memory's `permalink`. Rebuilding the block from scratch dropped it,
    # basic-memory re-added it on its next sync, and the two tools rewrote these
    # index files against each other forever: 8 files of churn on every run.
    OWNED = {"type", "title", "description", "tags", "timestamp"}
    carried = [(k, v) for k, v in frontmatter(d / "index.md").items()
               if k not in OWNED] if (d / "index.md").exists() else []

    lines = [
        "---",
        "type: index",
        f"title: {title}",
        f"description: Index of {len(files)} concept(s)"
        + (f" and {len(subdirs)} subdirectory(ies)" if subdirs else "")
        + f" under {d.name}/.",
        "tags: [index]",
        "timestamp: 2026-09-10T00:00:00Z",
    ] + [f"{k}: {v}" for k, v in carried] + [
        "---",
        "",
        f"# {title}",
        "",
        "<!--okf:intro-->",
        intro or "_Progressive disclosure: this index lists what is here so an agent "
                 "can pick one file instead of reading the directory._",
        "<!--/okf:intro-->",
        "",
        GEN,
        "",
    ]

    if subdirs:
        lines += ["## Subdirectories", ""]
        for s in subdirs:
            idx = s / "index.md"
            desc = frontmatter(idx).get("description", "") if idx.exists() else ""
            lines.append(f"- [{s.name}/]({s.name}/index.md) — {desc}" if idx.exists()
                         else f"- `{s.name}/`")
        lines.append("")

    if files:
        lines += ["## Concepts", "", "| Concept | Type | Description |",
                  "|---------|------|-------------|"]
        for f in files:
            fm = frontmatter(f)
            t = fm.get("type", "**MISSING**")
            desc = fm.get("description", "").replace("|", "\\|")[:150]
            name = fm.get("title", f.stem).strip("'")
            lines.append(f"| [{name}]({f.name}) | `{t}` | {desc} |")
        lines.append("")

    (d / "index.md").write_text("\n".join(lines))
    return len(files), len(subdirs)


if __name__ == "__main__":
    for root in sys.argv[1:]:
        rp = pathlib.Path(root)
        dirs = [rp] + [p for p in rp.rglob("*") if p.is_dir()
                       and not p.name.startswith(".")]
        # deepest first, so parent indexes can read child descriptions
        for d in sorted(dirs, key=lambda p: -len(p.parts)):
            nf, nd = build(d, rp.name)
            print(f"  {d}/index.md  ({nf} concepts, {nd} subdirs)")
