#!/usr/bin/env python3
"""Bring a markdown file's frontmatter up to OKF v0.1 conformance.

OKF requires exactly one field: `type`. Conventional fields, in this order:
type, title, description, resource, tags, timestamp. Any other key already
present (e.g. basic-memory's `permalink`) is preserved verbatim and appended --
OKF is minimally opinionated about fields it does not define.

Idempotent: re-running never overwrites a field that is already meaningful.
Usage: okf-normalize.py <path>...   (--dry-run to preview)
"""
import re
import sys
import datetime
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import okf_fm

OKF_ORDER = ["type", "title", "description", "resource", "tags", "timestamp"]
# `note` is the basic-memory default and carries no information. SPEC.md §7.2
# forbids it: a type that applies to everything types nothing.
UNINFORMATIVE = {"note", ""}

TAG_VOCAB = {
    "pantry": ["pantry", "ambry", "expo", "recipe", "grocery"],
    "skills": ["skill", "nightly-2026", "curator"],
    "hermes": ["hermes", "gateway", "mcp"],
    "infra": ["cron", "launchd", "watchdog", "backup", "worker", "queue"],
    "database": ["migration", "neon", "psql", "postgres", "0047", "0053", "0054"],
    "release": ["app store", "testflight", "eas build", "revenuecat"],
    "acceptance": ["maestro", "acceptance", "simulator"],
    "memory": ["daily-log", "vault", "fold"],
}


def yaml_scalar(v):
    """Quote a value that a YAML parser would otherwise choke on.

    An unquoted plain scalar containing ": " is invalid YAML -- the parser reads
    it as a nested mapping and errors. That is not academic here: basic-memory
    could not parse such a file, so instead of merging its `permalink` into the
    existing block it prepended a second block, and every normalize/sync cycle
    re-created it. Emitting valid YAML is what actually stops that.
    """
    v = v.strip()
    if not v:
        return v
    if v[0] in "'\"[{":                      # already quoted or a flow collection
        return v
    needs = (": " in v or v.endswith(":") or " #" in v
             or v[0] in "&*!|>%@`,?-" or v in ("true", "false", "null", "~"))
    if not needs:
        return v
    return "'" + v.replace("'", "''") + "'"


def _one_block_raw(text):
    """-> (block_text, rest) for a leading --- block, or (None, text)."""
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    return text[:end + 5], text[end + 5:]


def infer_type(path, body):
    if path.name == "index.md":
        return "index"
    parts = path.parts
    if "daily-log" in parts:
        return "log"
    if "plans" in parts:
        return "plan"
    if "decisions" in parts:
        return "decision"
    if "entities" in parts:
        return "entity"
    if "references" in parts:
        return "reference"
    if "pipelines" in parts:
        return "stage"
    if "projects" in parts:
        return "project"
    if re.search(r"^#+ .*runbook", body, re.I | re.M):
        return "runbook"
    return "reference"


def infer_description(path, body):
    """Honest and derived -- headings the author already wrote, never invented."""
    heads = [h.strip() for h in re.findall(r"^##+ +(.+)$", body, re.M)]
    heads = [re.sub(r"[*`_]", "", h) for h in heads]
    heads = [h for h in heads if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", h)]
    if heads:
        d = "; ".join(heads[:3])
        if len(heads) > 3:
            d += f"; +{len(heads) - 3} more"
        return d[:300]
    for line in body.split("\n"):
        s = line.strip()
        if s and not s.startswith("#") and not s.startswith("---"):
            return re.sub(r"[*`_\[\]]", "", s)[:200]
    return "No content recorded."


def infer_tags(path, body):
    hay = (str(path) + "\n" + body).lower()
    tags = [t for t, kws in TAG_VOCAB.items() if any(k in hay for k in kws)]
    return tags or ["misc"]


def infer_timestamp(path, existing_body=None):
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", path.name)
    if m:
        return f"{m.group(0)}T00:00:00Z"
    ts = datetime.datetime.utcfromtimestamp(path.stat().st_mtime)
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize(path, dry_run=False):
    text = path.read_text()
    fields, body, nblocks = okf_fm.split(text)
    if fields is None:
        return "skipped (unparseable frontmatter)"

    have = dict(fields)
    extras = [(k, v) for k, v in fields if k not in OKF_ORDER]
    changes = []

    if have.get("type", "").strip("'\"") in UNINFORMATIVE:
        have["type"] = infer_type(path, body)
        changes.append(f"type->{have['type']}")
    if not have.get("title"):
        have["title"] = f"'{path.stem}'"
        changes.append("title")
    if not have.get("description"):
        have["description"] = infer_description(path, body)
        changes.append("description")
    if not have.get("tags"):
        have["tags"] = "[" + ", ".join(infer_tags(path, body)) + "]"
        changes.append("tags")
    if not have.get("timestamp"):
        have["timestamp"] = infer_timestamp(path)
        changes.append("timestamp")

    invalid = [k for k, v in fields
               if yaml_scalar(v) != v.strip() and v.strip()[:1] not in "'\"[{"]
    if invalid:
        changes.append("quoted " + ", ".join(sorted(set(invalid))))

    if nblocks > 1 and not changes:
        # Only defect is a stacked block. Drop the redundant LEADING block and
        # leave the rest byte-for-byte.
        #
        # Rewriting the whole file here would convert basic-memory's canonical
        # YAML (block sequences, "2026-09-03 00:00:00+00:00") back into our flat
        # style, which reads to its watcher as a change -- it re-syncs, prepends
        # its block again, and the two tools flip-flop forever. A surgical edit
        # leaves nothing for it to react to.
        text2 = text
        while True:
            head, rest = _one_block_raw(text2)
            if head is None:
                break
            nxt = rest.lstrip("\n")
            if not nxt.startswith("---\n"):
                break
            text2 = nxt          # drop this block, keep the next one intact
        if not dry_run:
            path.write_text(text2)
        return f"collapsed {nblocks} frontmatter blocks (style preserved)"

    if nblocks > 1:
        changes.append(f"merged {nblocks} frontmatter blocks")

    if not changes:
        return "already conformant"

    out = ["---"]
    for k in OKF_ORDER:
        if k in have and have[k] != "":
            out.append(f"{k}: {yaml_scalar(have[k])}")
    for k, v in extras:
        out.append(f"{k}: {yaml_scalar(v)}")
    out.append("---")
    new = "\n".join(out) + "\n" + body

    if not dry_run:
        path.write_text(new)
    return "updated: " + ", ".join(changes)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    for a in args:
        p = pathlib.Path(a)
        print(f"{p}: {normalize(p, dry)}")
