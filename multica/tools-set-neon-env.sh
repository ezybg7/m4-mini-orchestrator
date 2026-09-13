#!/usr/bin/env bash
# tools-set-neon-env.sh <agent-id-or-name> — give one board agent the rehearsal Neon URL as
# custom env (NEON_REHEARSAL_URL), the same way codex-implementer, claude-planner and
# claude-reviewer already have it. Reads ~/agents/.neon_rehearsal_url INTERNALLY (never echoed);
# every existing key on the agent is preserved (sent back as **** so the server keeps it).
# The rehearsal project is schema-only and disposable; this is never the production URL.
set -euo pipefail; export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
[ $# -eq 1 ] || { echo "usage: $0 <agent-id-or-name>"; exit 2; }
F=~/agents/.neon_rehearsal_url; [ -f "$F" ] || { echo "missing rehearsal url file"; exit 2; }
URL=$(tr -d '[:space:]' < "$F"); [ -n "$URL" ] || { echo "empty rehearsal url file"; exit 2; }
case "$URL" in *production*|*red-water*) echo "REFUSING: this looks like the production project"; exit 2;; esac
id=$1
case "$id" in
  *-*-*-*-*) ;;
  *) id=$(multica agent list --output json | python3 -c "import json,sys; print([a['id'] for a in json.load(sys.stdin) if a['name']=='$1'][0])") ;;
esac
existing=$(multica agent env get "$id" --output json 2>/dev/null || echo '{}')
NEON_REHEARSAL_URL="$URL" python3 - "$existing" <<'PY' | multica agent env set "$id" --custom-env-stdin --output table >/dev/null
import json, os, sys
try:
    cur = json.loads(sys.argv[1]); cur = cur.get("custom_env", cur) if isinstance(cur, dict) else {}
except Exception:
    cur = {}
merged = {k: "****" for k in cur.keys()}
merged["NEON_REHEARSAL_URL"] = os.environ["NEON_REHEARSAL_URL"]
print(json.dumps(merged))
PY
echo "custom env keys on $id: $(multica agent env get "$id" --output json | python3 -c "import json,sys; d=json.load(sys.stdin); d=d.get('custom_env',d); print(', '.join(sorted(d.keys())))")"
