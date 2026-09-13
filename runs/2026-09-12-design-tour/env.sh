#!/bin/zsh
# env.sh — design-tour environment. Sourced by every script in this run dir.
# It reads the shared credential file INTERNALLY and exports only TEST_EMAIL /
# TEST_PASSWORD (which are then handed to maestro via -e, exactly as
# ~/agents/scripts/acceptance-cycle.sh does). No value from that file is ever
# echoed, and no script here writes one to disk.
set -u
source "$HOME/agents/.env.acceptance"
export TEST_EMAIL TEST_PASSWORD

# --- The disposable Neon branch this tour runs against (step 1) -------------
export TOUR_BRANCH_ID=br-winter-hall-a630bzfe
export TOUR_ENDPOINT_ID=ep-lucky-heart-a6fj97ku
export TOUR_REGION=us-west-2
export BRANCH_URL="https://${TOUR_ENDPOINT_ID}.apirest.${TOUR_REGION}.aws.neon.tech/neondb/rest/v1"
export BRANCH_HOST="${TOUR_ENDPOINT_ID}.apirest.${TOUR_REGION}.aws.neon.tech"
export BRANCH_DIRECT_HOST="${TOUR_ENDPOINT_ID}.${TOUR_REGION}.aws.neon.tech"

export UDID=${UDID:-70893D75-19E3-4CF2-8DBC-84B6BD00C3C7}
export BUNDLE_ID=com.everettyan.ambry
export REPO=${REPO:-$HOME/code/pantry}
export RUN_DIR="$HOME/agents/runs/2026-09-12-design-tour"
export APP_OUT="$HOME/agents/builds/Ambry-sim-release-design-tour.app"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
