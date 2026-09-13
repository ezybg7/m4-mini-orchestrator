#!/bin/zsh
# Fallback if Maestro refuses a runFlow outside the workspace: copy the repo's
# two shared includes into flows/ and point the shim at the local copy. Re-run
# after the repo's own _login.yaml changes (that is the drift this costs).
set -u
RUN="$HOME/agents/runs/2026-09-12-design-tour"
SRC=/Users/orchestrator/code/pantry/.maestro/acceptance
cp "$SRC/_launch.yaml" "$RUN/flows/_launch.yaml"
cp "$SRC/_login.yaml"  "$RUN/flows/_login.yaml"
echo "copied _launch.yaml and _login.yaml from $SRC into flows/ (the shim is now the copy itself)"
