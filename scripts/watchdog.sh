#!/bin/bash
# Restart services if down; log memory pressure.
curl -fsS -m 5 http://localhost:11434/v1/models >/dev/null || launchctl kickstart -k gui/$(id -u)/com.user.ollama
launchctl list | grep -q com.user.hermes || launchctl load ~/Library/LaunchAgents/com.user.hermes.plist
echo "$(date +%FT%T) $(memory_pressure | grep 'System-wide')" >> ~/agents/logs/mempressure.log
