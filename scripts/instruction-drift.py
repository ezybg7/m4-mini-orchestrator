#!/usr/bin/env python3
"""Detect drift between a repo's two instruction files.

pantry's AGENTS.md says it plainly: "Two instruction files with no drift check is
the standard failure mode of a two-model setup." CLAUDE.md binds Claude, AGENTS.md
binds Codex, and AGENTS.md deliberately does not restate CLAUDE.md's rules -- so
when one moves alone, the two models are working from different instructions and
nothing says so.

This does not try to understand the files. It records a hash of each and reports
when ONE moved without the other, which is the signal worth having.

  instruction-drift.py            check, exit 1 on drift
  instruction-drift.py --accept   record the current pair as the new baseline
"""
import hashlib, json, pathlib, sys

REPO = pathlib.Path.home() / "code" / "pantry"
PAIR = ["CLAUDE.md", "AGENTS.md"]
STATE = pathlib.Path.home() / "agents" / "system-config" / "instruction-drift.json"


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16] if p.exists() else None


def main():
    now = {}
    for name in PAIR:
        d = digest(REPO / name)
        if d is None:
            print(f"MISSING {REPO/name} — cannot check drift")
            return 1
        now[name] = d

    if not STATE.exists():
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(now, indent=2) + "\n")
        print(f"baseline recorded: {', '.join(f'{k}={v}' for k, v in now.items())}")
        return 0

    was = json.loads(STATE.read_text())
    moved = [n for n in PAIR if was.get(n) != now[n]]

    if "--accept" in sys.argv:
        STATE.write_text(json.dumps(now, indent=2) + "\n")
        print(f"baseline updated ({len(moved)} file(s) had moved)")
        return 0

    if not moved:
        print("no drift — both instruction files unchanged since the baseline")
        return 0
    if len(moved) == len(PAIR):
        print("both instruction files moved together — no drift signal")
        print("run with --accept to record the new baseline")
        return 0

    other = [n for n in PAIR if n not in moved][0]
    print(f"DRIFT: {moved[0]} changed, {other} did not.")
    print(f"  {REPO/moved[0]}")
    print(f"  Review whether the change needs a matching edit in {other}.")
    print("  Then: instruction-drift.py --accept")
    return 1


if __name__ == "__main__":
    sys.exit(main())
