#!/usr/bin/env python3
"""Print the rehearsal project's connection string with the database swapped.

Inline python inside a shell double-quoted string kept eating the `$` end-anchor and
silently yielding an empty URL — which psql happily interprets as "connect to the local
socket", turning a failed rehearsal into a false pass. One file, no quoting layers.
"""
import os, re, sys
u = open(os.path.expanduser("~/agents/.neon_rehearsal_url")).read().strip()
db = sys.argv[1]
out = re.sub(r"/[^/?]+(\?|$)", "/" + db + r"\1", u, count=1)
if "/" + db not in out:
    sys.exit("could not rewrite the database name")
print(out)
