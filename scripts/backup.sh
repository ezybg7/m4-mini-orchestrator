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
cp ~/Library/LaunchAgents/com.user.*.plist            system-config/                   2>/dev/null || true

# 2. Commit + push ~/agents (exit quietly if nothing changed)
git add -A
git commit -m "backup $(date +%F)" || exit 0
git push origin main

# 3. Push the skills repo (all branches, so unreviewed nightly-* branches survive too)
cd ~/agents/skills && git push origin --all
