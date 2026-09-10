"""Frontmatter parsing for OKF bundles. No dependencies, deliberately.

OKF's promise is "just markdown, just files, just YAML frontmatter" -- a bundle
must be readable without installing anything. So this parses the YAML subset
that frontmatter actually uses rather than pulling in a library:

  key: value                      scalar
  key: [a, b]                     flow sequence
  key:                            block sequence
  - a
  - b
  key: a long value               folded continuation (indented next line)
    that wraps

It also merges CONSECUTIVE frontmatter blocks. basic-memory syncs this vault and
can leave a second block stacked on top; both are ours, first wins on conflict.
"""

def _parse_block(lines):
    fields, key, buf = [], None, []

    def flush():
        nonlocal key, buf
        if key is not None:
            fields.append((key, "\n".join(buf).strip() if len(buf) > 1
                           else (buf[0].strip() if buf else "")))
        key, buf = None, []

    seq = None
    for raw in lines:
        if not raw.strip():
            continue
        if raw.lstrip().startswith("- ") and (seq is not None):
            seq.append(raw.lstrip()[2:].strip())
            continue
        if raw[:1] in (" ", "\t") and key is not None:   # folded continuation
            buf.append(raw.strip())
            continue
        if ":" not in raw:
            return None                                   # not flat enough
        flush()
        if seq is not None:
            fields.append((seq_key, "[" + ", ".join(seq) + "]"))
            seq = None
        k, v = raw.split(":", 1)
        k, v = k.strip(), v.strip()
        if v == "":                                       # block sequence opens
            seq, seq_key = [], k
            continue
        key, buf = k, [v]
    flush()
    if seq is not None:
        fields.append((seq_key, "[" + ", ".join(seq) + "]"))
    return fields


def _one(text):
    if not text.startswith("---\n"):
        return [], text
    end = text.find("\n---\n", 4)
    if end == -1:
        return [], text
    f = _parse_block(text[4:end].split("\n"))
    if f is None:
        return None, text
    return f, text[end + 5:]


def split(text):
    """-> (fields, body, n_blocks). fields is None if unparseable."""
    fields, body = _one(text)
    if fields is None:
        return None, text, 0
    n = 1 if fields else 0
    seen = {k for k, _ in fields}
    while True:
        stripped = body.lstrip("\n")
        if not stripped.startswith("---\n"):
            break
        more, rest = _one(stripped)
        if not more:
            break
        for k, v in more:
            if k not in seen:
                fields.append((k, v))
                seen.add(k)
        body, n = rest, n + 1
    return fields, body, n


def get(text):
    """Convenience: -> dict of frontmatter fields (empty dict if none)."""
    f, _, _ = split(text)
    return dict(f) if f else {}
