#!/bin/zsh
# build.sh — bake the design-tour branch's Data API URL into a Release simulator
# build, verify the baked endpoint, install it on the booted iPhone 17 Pro.
# Modelled on ~/agents/scripts/acceptance-cycle.sh's build path (which is the
# one that bakes a BRANCH url correctly — ambry-sim-build.sh is production-only).
set -u
source "$(dirname $0)/env.sh"
export SENTRY_DISABLE_AUTO_UPLOAD=true SENTRY_ALLOW_FAILURE=true CI=1
PROD_ID=$(grep -oE 'EXPO_PUBLIC_DATA_API_URL=https://[^.]+' $REPO/.env 2>/dev/null | sed 's#.*https://##' | head -1)
[ -n "$PROD_ID" ] || { echo "no EXPO_PUBLIC_DATA_API_URL in $REPO/.env — refusing to build a bundle with no endpoint"; exit 2; }
cd $REPO || exit 2
APP=$REPO/ios/build/Build/Products/Release-iphonesimulator/Ambry.app
echo "== $(date '+%H:%M:%S') repo $(git rev-parse --abbrev-ref HEAD) $(git log --oneline -1)"
echo "== $(date '+%H:%M:%S') clear metro cache (EXPO_PUBLIC_* is inlined at transform time; the cache key ignores values)"
setopt null_glob 2>/dev/null; rm -rf ${TMPDIR:-/tmp}/metro-cache ${TMPDIR:-/tmp}/metro-file-map-* 2>/dev/null; unsetopt null_glob 2>/dev/null
echo "== $(date '+%H:%M:%S') prebuild"; cp package.json $RUN_DIR/scratch/package.json.bak
npx expo prebuild --platform ios --no-install >/dev/null 2>&1 && echo prebuild-ok || { cp $RUN_DIR/scratch/package.json.bak package.json; echo "prebuild FAILED"; exit 3; }
cp $RUN_DIR/scratch/package.json.bak package.json   # prebuild rewrites scripts/version; never leave that behind
echo "== $(date '+%H:%M:%S') pod install"; (cd ios && pod install --silent >/dev/null 2>&1 && echo pods-ok || echo "pod install failed (continuing)")
echo "== $(date '+%H:%M:%S') xcodebuild Release (branch URL baked)"
(cd ios && SENTRY_DISABLE_AUTO_UPLOAD=true EXPO_PUBLIC_DATA_API_URL="$BRANCH_URL" caffeinate -dims xcodebuild -workspace Ambry.xcworkspace -scheme Ambry -configuration Release -sdk iphonesimulator -derivedDataPath build -destination "platform=iOS Simulator,id=$UDID" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build -quiet 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)' | tail -5)
[ -d "$APP" ] || { echo "no .app produced"; exit 4; }
echo "PROOF  prod id hits: $(strings $APP/main.jsbundle | grep -c "$PROD_ID")  branch id hits: $(strings $APP/main.jsbundle | grep -c "$TOUR_ENDPOINT_ID")   (prod MUST be 0)"
rm -rf "$APP_OUT"; cp -R "$APP" "$APP_OUT"; echo "kept at $APP_OUT"
for d in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do [ "$d" != "$UDID" ] && xcrun simctl shutdown $d >/dev/null 2>&1; done
xcrun simctl bootstatus $UDID -b >/dev/null 2>&1 && echo "booted $UDID" || { echo "could not boot $UDID"; exit 4; }
xcrun simctl spawn $UDID defaults write com.apple.WebUI AutoFillPasswords -bool false 2>/dev/null && echo "autofill passwords off"
echo "== $(date '+%H:%M:%S') install"; xcrun simctl uninstall $UDID $BUNDLE_ID >/dev/null 2>&1; xcrun simctl install $UDID "$APP" && echo installed
xcrun simctl launch $UDID $BUNDLE_ID && echo launched
echo "== $(date '+%H:%M:%S') done"
