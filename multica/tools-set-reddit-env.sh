#!/usr/bin/env bash
# Give the two research agents Reddit API credentials as audited custom env, reading them from
# ~/agents/multica/reddit_app (mode 600; lines REDDIT_CLIENT_ID=… REDDIT_CLIENT_SECRET=… REDDIT_USERNAME=…).
# Existing keys on each agent are preserved (Multica keeps entries whose value is '****').
# Never prints a value. Re-run after rotating the file.
set -euo pipefail; export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
F=~/agents/multica/reddit_app; [ -f "$F" ] || { echo "missing $F"; exit 2; }
set -a; . "$F"; set +a
: "${REDDIT_CLIENT_ID:?}" "${REDDIT_CLIENT_SECRET:?}"
for name in researcher-external research-lead; do
  id=$(multica agent list --output json | python3 -c "import json,sys; print([a['id'] for a in json.load(sys.stdin) if a['name']=='$name'][0])")
  existing=$(multica agent env get "$id" --output json 2>/dev/null || echo '{}')
  REDDIT_CLIENT_ID="$REDDIT_CLIENT_ID" REDDIT_CLIENT_SECRET="$REDDIT_CLIENT_SECRET" REDDIT_USERNAME="${REDDIT_USERNAME:-}" \
  python3 - "$existing" <<'PY' | multica agent env set "$id" --custom-env-stdin --output table >/dev/null
import json, os, sys
try:
    cur = json.loads(sys.argv[1]); cur = cur.get("custom_env", cur) if isinstance(cur, dict) else {}
except Exception:
    cur = {}
merged = {k: "****" for k in cur.keys()}
merged.update({"REDDIT_CLIENT_ID": os.environ["REDDIT_CLIENT_ID"], "REDDIT_CLIENT_SECRET": os.environ["REDDIT_CLIENT_SECRET"], "REDDIT_USERNAME": os.environ.get("REDDIT_USERNAME", "")})
print(json.dumps(merged))
PY
  echo "custom env set on $name ($(multica agent env get "$id" --output json | python3 -c "import json,sys; d=json.load(sys.stdin); d=d.get('custom_env',d); print(', '.join(sorted(d.keys())))"))"
done
echo "proof (as orchestrator, same credentials):"; set -a; . "$F"; set +a; /opt/homebrew/bin/reddit-search search "pantry inventory app" --limit 3 --time year | head -5
