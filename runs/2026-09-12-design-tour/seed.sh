#!/bin/zsh
# seed.sh — run the repo's Maestro acceptance suite ONCE against the design-tour
# branch, to populate it with items, grocery rows, recipes, zones and waste
# outcomes. Same shape as ~/agents/scripts/acceptance-cycle.sh's run half:
# warm the branch compute, then npm run test:acceptance with the branch env.
# Credentials come out of env.sh (which sources the shared file internally) and
# reach maestro only through the runner's -e flags.
set -u
source "$(dirname $0)/env.sh"
cd $REPO || exit 2
mkdir -p $HOME/agents/logs
echo "== $(date '+%H:%M:%S') keep-alive"
pkill -f neon-branch-keepalive 2>/dev/null
NEON_DATA_API_URL="$BRANCH_URL" node $HOME/agents/scripts/neon-branch-keepalive.mjs > $RUN_DIR/logs/keepalive-seed.log 2>&1 &
KA=$!
sleep 20; tail -2 $RUN_DIR/logs/keepalive-seed.log
echo "== $(date '+%H:%M:%S') acceptance run (seeding)"
EXPO_PUBLIC_DATA_API_URL="$BRANCH_URL" ACCEPTANCE_TARGET_HOST="$BRANCH_HOST" \
  caffeinate -dims npm run test:acceptance 2>&1 | tee $RUN_DIR/logs/seed-acceptance.log | grep -E '^\[|Flows|run-acceptance|Passed|Failed' | tail -40
echo "== $(date '+%H:%M:%S') done"
kill $KA 2>/dev/null
