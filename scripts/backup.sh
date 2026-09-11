#!/bin/bash
set -euo pipefail
cd ~/agents

# 1. Snapshot config that lives outside ~/agents (known-safe files only — never token/credential files)
mkdir -p system-config
crontab -l                                        > system-config/crontab.txt
pmset -g                                          > system-config/pmset.txt
ollama list                                       > system-config/ollama-models.txt 2>/dev/null || true
cp ~/.hermes/SOUL.md                                system-config/SOUL.md            2>/dev/null || true
cp ~/.claude/CLAUDE.md                              system-config/CLAUDE.global.md   2>/dev/null || true
cp ~/.tmux.conf                                     system-config/tmux.conf          2>/dev/null || true
cp ~/.codex/config.toml                             system-config/codex.config.toml  2>/dev/null || true
# NEVER back up ~/.codex/auth.json (credentials).
cp ~/Library/LaunchAgents/com.user.*.plist            system-config/                   2>/dev/null || true

# 1b. Multica store (pantry spec 61): pg_dump of the local postgresql@17 on 5433, 7-day rotation.
#     Peer auth over the socket (no password). Data, not knowledge: backups/multica/ is gitignored.
#     Restore: createdb -h /tmp -p 5433 -O multica multica && gunzip -c <dump> | psql -h /tmp -p 5433 -d multica
mkdir -p backups/multica
MULTICA_DUMP="backups/multica/multica-$(date +%F).sql.gz"
/opt/homebrew/opt/postgresql@17/bin/pg_dump -h /tmp -p 5433 -d multica | gzip > "$MULTICA_DUMP" \
  || { echo "multica pg_dump FAILED" >&2; rm -f "$MULTICA_DUMP"; }
find backups/multica -name 'multica-*.sql.gz' -mtime +7 -delete

# 2. Converge the OKF bundle before committing.
#    basic-memory is a second producer on this vault: it canonicalizes YAML and
#    asynchronously re-prepends its own permalink block after any external edit,
#    which leaves two stacked frontmatter blocks. Normalizing here means the
#    committed state is always conformant, whoever wrote last.
find memory references -name '*.md' -print0 2>/dev/null \
  | xargs -0 python3 scripts/okf-normalize.py >/dev/null 2>&1 || true
python3 scripts/okf-index.py memory references   >/dev/null 2>&1 || true
python3 scripts/okf-check.py                     >  logs/okf-check.log 2>&1 || \
  echo "okf-check FAILED — see logs/okf-check.log" >&2

# 3. Commit + push ~/agents (exit quietly if nothing changed)
git add -A
git commit -m "backup $(date +%F)" || exit 0
git push origin main

# 4. Push the skills repo (all branches, so unreviewed nightly-* branches survive too)
cd ~/agents/skills && git push origin --all
