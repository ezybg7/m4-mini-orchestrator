#!/bin/bash
# finish-xcode-setup.sh — the steps after Xcode.app lands in /Applications that
# need an admin password (so the mini's agents cannot run them unattended).
# Written 2026-09-03 during the M4-mini setup. Run once, in a terminal:
#
#   ~/agents/scripts/finish-xcode-setup.sh
#
# What it does: point the command-line tools at Xcode, accept the license,
# install Xcode's bundled components, download the iOS simulator runtime, then
# print the simulators so `npm run ios` and the Maestro acceptance suite have a
# device to target.
set -euo pipefail

XCODE="/Applications/Xcode.app"
if [ ! -d "$XCODE" ]; then
  echo "Xcode.app is not in /Applications yet — install it from the App Store first" >&2
  echo "(open 'macappstore://apps.apple.com/app/id497799835')" >&2
  exit 1
fi

echo "==> Selecting $XCODE for the developer tools (sudo)"
sudo xcode-select -s "$XCODE/Contents/Developer"

echo "==> Accepting the Xcode license (sudo)"
sudo xcodebuild -license accept

echo "==> Installing Xcode's bundled components (sudo)"
sudo xcodebuild -runFirstLaunch

echo "==> Downloading the iOS simulator platform (large; no sudo)"
xcodebuild -downloadPlatform iOS

echo "==> Done. Toolchain:"
xcodebuild -version
echo "==> Available iPhone simulators:"
xcrun simctl list devices available | grep -E "iPhone" | head -8 || echo "(none listed — open Xcode → Settings → Components and add an iOS simulator runtime)"
echo
echo "Next: 'eas login' (interactive), then from ~/code/pantry: 'npm run ios' for the simulator,"
echo "or the acceptance suite per docs/ACCEPTANCE_TESTS.md (Release simulator build + a disposable Neon branch)."
