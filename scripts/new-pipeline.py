#!/usr/bin/env python3
"""Scaffold a conformant ICM pipeline.

CONTEXT.md tells you to "add a pipeline per SPEC.md §2.2", but §2.2 is a table of
principles, not a procedure -- so the first thing anyone does is copy an existing
pipeline and edit it, which is how conventions drift. ICM ships a
workspace-builder for exactly this reason (paper §4.4). This is the small version:
it encodes the conventions the checker enforces, so a new pipeline starts valid.

  new-pipeline.py <name> <stage> [<stage> ...]
  new-pipeline.py release-cut plan build verify ship
"""
import pathlib, re, sys

H = pathlib.Path.home() / "agents"
TODAY = "2026-09-10"


def slug(s):
    return re.sub(r"[^a-z0-9_]+", "_", s.lower()).strip("_")


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    name, stages = slug(argv[0]), [slug(s) for s in argv[1:]]
    root = H / "pipelines" / name
    if root.exists():
        print(f"{root} already exists")
        return 1

    rows = "\n".join(
        f"| {i} | [`{i:02d}_{s}`]({i:02d}_{s}/CONTEXT.md) | _who owns this stage_ |"
        for i, s in enumerate(stages, 1))
    (root).mkdir(parents=True)
    (root / "CONTEXT.md").write_text(f"""---
type: stage
title: {name.replace('_', ' ')} pipeline
description: 'TODO one line: what this pipeline does and when it runs.'
tags: [workflow]
timestamp: {TODAY}T00:00:00Z
---

# {name.replace('_', ' ')}

_TODO: what triggers this, and what it produces._

| # | Stage | Owner |
|---|-------|-------|
{rows}

**Review gates.** _TODO: name every point where a human must look before the next
stage runs. If there is none, this may not belong in `pipelines/` at all — ICM is
for workflows that are sequential, reviewable and repeatable (SPEC.md §2.2 I11)._

Related: [pipelines](../index.md) · [SPEC.md](../../SPEC.md)
""")

    for i, s in enumerate(stages, 1):
        d = root / f"{i:02d}_{s}"
        (d / "output").mkdir(parents=True)
        (d / "output" / ".gitkeep").touch()
        prev = f"`../{i-1:02d}_{stages[i-2]}/output/`" if i > 1 else "_the trigger_"
        (d / "CONTEXT.md").write_text(f"""---
type: stage
title: {i:02d}_{s}
description: 'TODO one line: what this stage does.'
tags: [workflow]
timestamp: {TODAY}T00:00:00Z
---

# {i:02d}_{s}

## Inputs
- Layer 4 (working): {prev}
- Layer 3 (reference): _TODO — every file this stage needs, by path. This table is
  the scoping mechanism; a file not named here will not be loaded._

## Process
_TODO: what to do. One job only._

## Outputs
- `output/{s}-<YYYY-MM-DD>.md`
  _Date it: an undated name lets a later run read a previous run's output._

## Verify
_TODO: what must be true before the next stage reads this. State it so it can be
checked, not felt._
""")
    # Register it. A pipeline that is not linked from the index is an orphan and
    # fails okf-check immediately -- so the scaffold must not leave that to memory.
    idx = H / "pipelines" / "index.md"
    text = idx.read_text()
    row = (f"| [{name}]({name}/CONTEXT.md) | _TODO when_ | _TODO gate_ |\n")
    marker = "\nAdding one:"
    if marker in text:
        head, tail = text.split(marker, 1)
        idx.write_text(head.rstrip("\n") + "\n" + row + marker + tail)
    else:
        idx.write_text(text.rstrip("\n") + "\n" + row)

    print(f"created pipelines/{name}/ with {len(stages)} stages, registered in the index")
    print("  next: fill every TODO, then `python3 scripts/okf-check.py`")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
