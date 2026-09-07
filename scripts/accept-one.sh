#!/bin/zsh
# Run ONE acceptance flow against the branch, with the keep-alive warm.
# Usage: accept-one.sh <flow-basename> [repo]   e.g. accept-one.sh 01-auth ~/agents/worktrees/accept
set -u
FLOW=${1:?flow name}; REPO=${2:-$HOME/agents/worktrees/accept}
UDID=${UDID:-70893D75-19E3-4CF2-8DBC-84B6BD00C3C7}
source $HOME/agents/.env.acceptance
BRANCH_URL=$ACCEPTANCE_BRANCH_URL
BRANCH_HOST=$(echo "$BRANCH_URL" | sed -E 's#https://([^/]+).*#\1#')
export TEST_EMAIL TEST_PASSWORD LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
pgrep -f neon-branch-keepalive >/dev/null 2>&1 || {
  NEON_DATA_API_URL="$BRANCH_URL" node $HOME/agents/scripts/neon-branch-keepalive.mjs \
    > $HOME/agents/logs/keepalive-one.log 2>&1 &
  sleep 12
}
cd $REPO || exit 2
maestro test .maestro/acceptance/$FLOW.yaml -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" 2>&1 | grep -vE 'WARNING: (Use --enable|Mutating final)'
