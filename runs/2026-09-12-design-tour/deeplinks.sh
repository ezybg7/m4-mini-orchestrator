#!/bin/zsh
# deeplinks.sh — capture the screens the tour cannot reach through the UI, by
# opening the app's own URL scheme (`pantry://…`) with simctl and screenshotting
# headlessly. `xcrun simctl openurl` hands the URL straight to the app, so it does
# NOT raise the SpringBoard "Open in Ambry?" confirmation that a Maestro
# `openLink` (which goes via Safari) does — the reason .maestro/acceptance/
# _launch.yaml is a bare `launchApp`.
#
#   ./deeplinks.sh                 # light, dark, ax5
#   ./deeplinks.sh light
#
# Routes that need a real token (reset-password, join/<token>) are listed but not
# opened: mint the token first and pass it as ROUTE=... yourself.
set -u
cd "$(dirname $0)" || exit 2
source ./env.sh
if [ $# -gt 0 ]; then MODES=($@); else MODES=(light dark ax5); fi
ROUTES=(paywall first-run onboarding)
for m in $MODES; do
  case $m in
    light) xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    dark)  xcrun simctl ui $UDID appearance dark  >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    ax5)   xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size accessibility-extra-extra-extra-large >/dev/null ;;
  esac
  mkdir -p "shots/$m"
  for r in $ROUTES; do
    xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
    xcrun simctl launch $UDID $BUNDLE_ID >/dev/null 2>&1
    sleep 6
    xcrun simctl openurl $UDID "pantry://$r" >/dev/null 2>&1 || { echo "$m/$r: openurl refused"; continue; }
    sleep 5
    xcrun simctl io $UDID screenshot --type=png "shots/$m/$r.png" >/dev/null 2>&1 \
      && echo "$m/$r: captured" || echo "$m/$r: screenshot failed"
  done
done
xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null
echo "NOTE: a captured file is not proof the route rendered — open it and check."
echo "NOT attempted (need a live token): pantry://reset-password?token=<recovery token>, pantry://join/<invite token>"
