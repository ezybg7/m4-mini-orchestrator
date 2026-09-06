"""Resolve the #185 (spec 57) rebase conflicts against main. Re-runnable: each rule is stated
against HEAD (main) and THEIRS (the spec-57 commit) rather than against fixed text."""
import re, sys
def hunks(s):
    return list(re.finditer(r'<<<<<<< HEAD\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n', s, flags=re.S))
def resolve(path, fn):
    s = open(path).read(); out = []; last = 0; n = 0
    for m in hunks(s):
        out.append(s[last:m.start()]); out.append(fn(m.group(1), m.group(2))); last = m.end(); n += 1
    out.append(s[last:]); r = ''.join(out)
    assert '<<<<<<<' not in r and '>>>>>>>' not in r, path
    open(path, 'w').write(r); print(f"{path}: {n} hunk(s) resolved")

# docs/adr/auth.md — HEAD's two lines, plus spec 57 in the Governs list (after spec 46's item).
def adr(head, theirs):
    item = '`specs/email-verification.md` (57 — verification at sign-up, D12) · '
    assert item.strip(' ·') in theirs
    if item.strip(' ·') in head: return head
    return head.replace('`specs/invite-links.md` (43', item + '`specs/invite-links.md` (43', 1)

# specs/README.md — hunk 1: the _Updated_ line = HEAD's line with the row-57 clause in front;
# hunk 2: HEAD's rows (58 as main has it now) plus THEIRS' row 57 placed before them.
def readme(head, theirs):
    if head.startswith('_Updated'):
        clause = ('_Updated 2026-09-05 — row **57** ([email-verification](email-verification.md)) added: '
                  'audit-2026-09-04 DECISION 2 (K7) is decided, verification is ON, specced docs-only with ADR auth D12. '
                  'Same day, earlier ')
        if 'row **57**' in head: return head
        return head.replace('_Updated 2026-09-05 ', clause, 1)
    row57 = [l for l in theirs.splitlines(True) if l.startswith('| 57 |')]
    assert len(row57) == 1, theirs[:200]
    head = ''.join(l for l in head.splitlines(True) if not l.startswith('| 57 |'))  # THEIRS' row 57 always wins
    return row57[0] + head

# specs/auth.md — THEIRS' spec-57 pointer, keeping #182's welcome-grant dependency note.
def auth(head, theirs):
    dep = ' — spec 23\'s welcome grant is issued only to verified accounts, so it depends on this'
    t = theirs.rstrip('\n')
    return (t if dep.strip(' —') in t else t + dep) + '\n'

# docs/ACCEPTANCE_TESTS.md — THEIRS' spec 57 section (only that section) before HEAD's spec 58 section.
def acc(head, theirs):
    m = re.search(r'(### Spec 57 \(email verification\).*?)(?=\n### Spec \d|\Z)', theirs, flags=re.S)
    if not m:
        return theirs + head  # a partial hunk inside the section: the branch's edit first, then main's text
    sec57 = m.group(1).rstrip('\n') + '\n\n'
    head = re.sub(r'### Spec 57 \(email verification\).*?(?=\n### Spec \d|\Z)\n*', '', head, flags=re.S)  # THEIRS' section always wins
    return sec57 + head

resolve('docs/adr/auth.md', adr); resolve('specs/README.md', readme); resolve('specs/auth.md', auth); resolve('docs/ACCEPTANCE_TESTS.md', acc)
