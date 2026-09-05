#!/bin/zsh
# Acceptance cycle (durable copy, 2026-09-04): pull main, bake the BRANCH Data API URL into a
# Release simulator build (docs/ACCEPTANCE_TESTS.md gotchas 1–4), install it on the booted
# iPhone 17 Pro, warm the branch, run the Maestro suite. Needs ~/agents/.env.acceptance with
#   ACCEPTANCE_BRANCH_URL=https://<ep>.apirest.<region>.aws.neon.tech/neondb/rest/v1
#   TEST_EMAIL=… TEST_PASSWORD=…   (the seeded dev login)
# Usage: acceptance-cycle.sh <label> [--build-only|--run-only]
set -u
LABEL=${1:-cycle}; MODE=${2:-}
REPO=/Users/orchestrator/code/pantry; UDID='70893D75-19E3-4CF2-8DBC-84B6BD00C3C7'
source $HOME/agents/.env.acceptance
BRANCH_URL=${ACCEPTANCE_BRANCH_URL:?set ACCEPTANCE_BRANCH_URL in ~/agents/.env.acceptance}
BRANCH_HOST=$(echo "$BRANCH_URL" | sed -E 's#https://([^/]+).*#\1#'); BRANCH_ID=$(echo "$BRANCH_HOST" | cut -d. -f1)
export TEST_EMAIL TEST_PASSWORD LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 SENTRY_DISABLE_AUTO_UPLOAD=true SENTRY_ALLOW_FAILURE=true CI=1
PROD_ID=$(grep -oE 'EXPO_PUBLIC_DATA_API_URL=https://[^.]+' $REPO/.env 2>/dev/null | sed 's#.*https://##' | head -1)
cd $REPO || exit 2
APP=$REPO/ios/build/Build/Products/Release-iphonesimulator/Ambry.app
if [ "$MODE" != "--run-only" ]; then
  echo "== $(date '+%H:%M:%S') pull main"; git pull -q --rebase origin main; git log --oneline -1
  echo "== $(date '+%H:%M:%S') clear metro cache"; setopt null_glob 2>/dev/null; rm -rf ${TMPDIR:-/tmp}/metro-cache ${TMPDIR:-/tmp}/metro-file-map-* 2>/dev/null; unsetopt null_glob 2>/dev/null
  echo "== $(date '+%H:%M:%S') prebuild"; cp package.json /tmp/ambry-package.json.bak
  npx expo prebuild --platform ios --no-install >/dev/null 2>&1 && echo prebuild-ok || { cp /tmp/ambry-package.json.bak package.json; echo "prebuild FAILED"; exit 3; }
  cp /tmp/ambry-package.json.bak package.json   # prebuild rewrites scripts/version; never commit that
  echo "== $(date '+%H:%M:%S') pod install"; (cd ios && pod install --silent >/dev/null 2>&1 && echo pods-ok || echo "pod install failed (continuing)")
  echo "== $(date '+%H:%M:%S') xcodebuild Release (branch URL baked)"
  (cd ios && EXPO_PUBLIC_DATA_API_URL="$BRANCH_URL" xcodebuild -workspace Ambry.xcworkspace -scheme Ambry -configuration Release -sdk iphonesimulator -derivedDataPath build -destination "platform=iOS Simulator,id=$UDID" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build -quiet 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)' | tail -5)
  [ -d "$APP" ] || { echo "no .app produced"; exit 4; }
  echo "prod id hits: $(strings $APP/main.jsbundle | grep -c "$PROD_ID")  branch id hits: $(strings $APP/main.jsbundle | grep -c "$BRANCH_ID")  (prod must be 0)"
  rm -rf $HOME/agents/builds/Ambry-sim-release-branch-$(date +%F)-$LABEL.app; cp -R "$APP" $HOME/agents/builds/Ambry-sim-release-branch-$(date +%F)-$LABEL.app
  echo "== $(date '+%H:%M:%S') device"; for d in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do [ "$d" != "$UDID" ] && { echo "shutting down other booted simulator $d"; xcrun simctl shutdown $d >/dev/null 2>&1; }; done; xcrun simctl bootstatus $UDID -b >/dev/null 2>&1 && echo "booted $UDID" || { echo "could not boot $UDID"; exit 4; }
  echo "== $(date '+%H:%M:%S') install"; xcrun simctl uninstall $UDID com.everettyan.ambry >/dev/null 2>&1; xcrun simctl install $UDID "$APP" && echo installed
  [ "$MODE" = "--build-only" ] && exit 0
fi
echo "== $(date '+%H:%M:%S') keep-alive"; pkill -f neon-branch-keepalive 2>/dev/null
NEON_DATA_API_URL="$BRANCH_URL" node $HOME/agents/scripts/neon-branch-keepalive.mjs > $HOME/agents/logs/keepalive-$LABEL.log 2>&1 & KA=$!
sleep 20; tail -2 $HOME/agents/logs/keepalive-$LABEL.log
[ -n "$NEON_BRANCH_DIRECT_URL" ] && { psql "$NEON_BRANCH_DIRECT_URL" -X -Atc "notify pgrst, 'reload schema'" >/dev/null 2>&1 && echo "schema cache reload sent"; }
echo "== $(date '+%H:%M:%S') acceptance run"; EXPO_PUBLIC_DATA_API_URL="$BRANCH_URL" ACCEPTANCE_TARGET_HOST="$BRANCH_HOST" npm run test:acceptance 2>&1 | grep -E '^\[|Flows|run-acceptance' | tail -30
echo "== $(date '+%H:%M:%S') done"; kill $KA 2>/dev/null
