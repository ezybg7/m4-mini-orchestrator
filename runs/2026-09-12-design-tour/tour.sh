#!/bin/zsh
# tour.sh — the whole design tour in one command.
#
#   ~/agents/runs/2026-09-12-design-tour/tour.sh                  # fixture + light, dark, ax5
#   ~/agents/runs/2026-09-12-design-tour/tour.sh light dark       # only those modes
#   SKIP_SEED=1 ~/agents/runs/2026-09-12-design-tour/tour.sh dark # skip the fixture flow
#
# Preconditions: the Release build at ~/agents/builds/Ambry-sim-release-design-tour.app
# is installed on the booted iPhone 17 Pro and points at the design-tour Neon
# branch. Rebuild with ./build.sh, which re-proves the baked endpoint with
# `strings` before anything runs. Credentials never appear on a command line:
# env.sh sources the shared file internally and only TEST_EMAIL / TEST_PASSWORD
# are handed to maestro through -e.
#
# WHY THE SCREENSHOTS ARE COLLECTED RATHER THAN WRITTEN IN PLACE: Maestro 2.10
# sandboxes `takeScreenshot` — an absolute path is refused outright ("it resolves
# outside this run's takeScreenshot output folder") and a relative one lands under
# <run output>/<flow>/takeScreenshot/. So the flows use BARE names, the run is
# pointed at out/<mode> with --test-output-dir, and the PNGs are copied from
# there into shots/<mode>/ afterwards.
set -u
cd "$(dirname $0)" || exit 2
source ./env.sh
if [ $# -gt 0 ]; then MODES=($@); else MODES=(light dark ax5); fi
mkdir -p logs out

warm_signin() {  # sign in at the DEFAULT text size — see flows/_signin.yaml for why
  xcrun simctl ui $UDID content_size large >/dev/null
  xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
  rm -rf out/signin
  caffeinate -dims maestro --device $UDID test --test-output-dir "$PWD/out/signin" \
    -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" \
    flows/_signin.yaml > logs/signin-warm.log 2>&1
}
say_mode() {  # $1 = mode → sets the simulator's appearance and text size
  case $1 in
    light) xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    dark)  xcrun simctl ui $UDID appearance dark  >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    ax5)   xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size accessibility-extra-extra-extra-large >/dev/null ;;
    *) echo "unknown mode: $1 (light|dark|ax5)"; return 2 ;;
  esac
}
collect() {  # $1 = mode → copy this run's screenshots into shots/<mode>/
  mkdir -p "shots/$1"
  find "out/$1" -path '*/takeScreenshot/*.png' -exec cp {} "shots/$1/" \; 2>/dev/null
}

xcrun simctl bootstatus $UDID -b >/dev/null 2>&1 || { echo "could not boot $UDID"; exit 2; }
xcrun simctl spawn $UDID defaults write com.apple.WebUI AutoFillPasswords -bool false 2>/dev/null

# Keep the branch compute warm for the whole tour: a cold read exceeds the app's
# 12 s DB_TIMEOUT, and every data-bearing screen would screenshot its skeleton.
pkill -f neon-branch-keepalive 2>/dev/null
NEON_DATA_API_URL="$BRANCH_URL" node $HOME/agents/scripts/neon-branch-keepalive.mjs > logs/keepalive-tour.log 2>&1 &
KA=$!
trap 'kill $KA 2>/dev/null' EXIT
sleep 20; tail -1 logs/keepalive-tour.log

if [ "${SKIP_SEED:-0}" != 1 ]; then
  echo "== $(date '+%H:%M:%S') fixture (00-seed-tour)"
  say_mode light
  xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
  rm -rf out/fixture
  caffeinate -dims maestro --device $UDID test --test-output-dir "$PWD/out/fixture" \
    -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" \
    flows/00-seed-tour.yaml > logs/seed-tour-fixture.log 2>&1
  grep -E '\[(Passed|Failed)\]' logs/seed-tour-fixture.log | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -3
fi

for m in $MODES; do
  warm_signin
  say_mode $m || continue
  echo "== $(date '+%H:%M:%S') mode $m  (appearance $(xcrun simctl ui $UDID appearance), text $(xcrun simctl ui $UDID content_size))"
  # A relaunch is cheaper than trusting a live trait change to reach every
  # already-mounted screen.
  xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
  rm -rf "out/$m"
  caffeinate -dims maestro --device $UDID test --test-output-dir "$PWD/out/$m" \
    -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" \
    flows/ > "logs/tour-$m.log" 2>&1
  rc=$?
  collect $m
  echo "  exit=$rc shots=$(ls "shots/$m" 2>/dev/null | wc -l | tr -d ' ')"
  grep -E '\[(Passed|Failed)\]' "logs/tour-$m.log" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -10
done

# --- 480px-wide JPEG contact copies ----------------------------------------
for m in $MODES; do
  [ -d "shots/$m" ] || continue
  mkdir -p "thumbs/$m"
  for f in shots/$m/*.png; do
    [ -e "$f" ] || continue
    sips -s format jpeg -s formatOptions 72 --resampleWidth 480 "$f" \
      --out "thumbs/$m/$(basename ${f%.png}).jpg" >/dev/null 2>&1
  done
  echo "thumbs/$m: $(ls "thumbs/$m" 2>/dev/null | wc -l | tr -d ' ')"
done

# --- Leave the simulator as it was found ----------------------------------
xcrun simctl ui $UDID appearance light >/dev/null
xcrun simctl ui $UDID content_size large >/dev/null
echo "== $(date '+%H:%M:%S') tour done; simulator restored to light / large"
