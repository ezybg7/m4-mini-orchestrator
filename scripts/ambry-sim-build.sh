#!/bin/bash
# ambry-sim-build.sh — build Ambry for the iOS simulator on the mini, then
# install and launch it.
#
#   ~/agents/scripts/ambry-sim-build.sh            # Debug (dev client; then `npx expo start --dev-client`)
#   ~/agents/scripts/ambry-sim-build.sh Release    # standalone Release build (what the Maestro acceptance suite needs)
#
# Why not plain `npx expo run:ios`? Ambry's entitlements (aps-environment, Sign in
# with Apple, associated domains) make Expo CLI 57 insist on a code-signing team
# for ANY named simulator target (@expo/cli run/ios/XcodeBuild.js:279 →
# codeSigning/simulatorCodeSigning.js). The mini has no Apple ID in Xcode, so the
# CLI aborts with "No code signing certificates are available to use" before
# xcodebuild starts. The `--device generic` path skips that gate, builds the
# unsigned simulator .app (which runs fine — verified 2026-09-03), and this
# script installs/launches it with simctl. Adding the developer account in
# Xcode → Settings → Accounts (team SANRTXS285) removes the need for this script.
set -euo pipefail

CONFIG="${1:-Debug}"
case "$CONFIG" in
  Debug|Release) ;;
  *) echo "usage: $0 [Debug|Release]" >&2; exit 2 ;;
esac
REPO="${PANTRY_REPO:-$HOME/code/pantry}"
OUT="$HOME/agents/builds/Ambry-sim-$CONFIG"
SIM_NAME="${AMBRY_SIM:-iPhone 17 Pro}"
BUNDLE_ID="com.everettyan.ambry"

# CocoaPods dies silently without a UTF-8 locale; Sentry's build phase must not
# try to upload source maps from a local build; CI=1 keeps the CLI non-interactive.
export LANG="${LANG:-en_US.UTF-8}" LC_ALL="${LC_ALL:-en_US.UTF-8}"
export SENTRY_DISABLE_AUTO_UPLOAD=true SENTRY_ALLOW_FAILURE=true CI=1

cd "$REPO"
rm -rf "$OUT"
echo "==> Building $CONFIG for the generic simulator destination -> $OUT"
caffeinate -dims npx expo run:ios --configuration "$CONFIG" --device generic --output "$OUT"

if ! xcrun simctl list devices booted | grep -q Booted; then
  UDID=$(xcrun simctl list devices available -j | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      const j = JSON.parse(s);
      for (const r in j.devices) for (const d of j.devices[r]) if (d.name === process.argv[1]) { console.log(d.udid); process.exit(0); }
      process.exit(1);
    })' "$SIM_NAME")
  echo "==> Booting $SIM_NAME ($UDID)"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
fi
open -a Simulator

echo "==> Installing and launching $BUNDLE_ID"
xcrun simctl install booted "$OUT/Ambry.app"
xcrun simctl launch booted "$BUNDLE_ID"

if [ "$CONFIG" = "Debug" ]; then
  echo "Dev client installed. Start Metro with:  cd $REPO && npx expo start --dev-client"
else
  echo "Standalone Release build installed. Acceptance suite (docs/ACCEPTANCE_TESTS.md):"
  echo "  TEST_EMAIL=... TEST_PASSWORD=... ACCEPTANCE_TARGET_HOST=<neon branch host> npm run test:acceptance"
fi
