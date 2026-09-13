#!/bin/zsh
# fill.sh — re-capture SOME flows in SOME modes, into the same shots/<mode>/.
# The point is a targeted second pass: when one flow's selector was wrong, or a
# fixture landed after a mode had already run, re-running the whole tour to fix
# six screenshots is wasteful.
#
#   ./fill.sh "10-pantry 40-recipes" "light dark ax5"
#   ./fill.sh 10-pantry light
#
# Same guarantees as tour.sh: same appearance/text-size table, same keep-alive,
# same collection out of --test-output-dir, and the simulator is restored at the
# end. It does NOT run the fixture flows — run those yourself first if the data
# is what changed:  maestro --device $UDID test -e ... flows/01-seed-outcomes.yaml
set -u
cd "$(dirname $0)" || exit 2
source ./env.sh
FLOWS=(${=1:-10-pantry})
MODES=(${=2:-light dark ax5})
mkdir -p logs out
warm_signin() {  # sign in at the DEFAULT text size — see flows/_signin.yaml for why
  xcrun simctl ui $UDID content_size large >/dev/null
  xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
  rm -rf out/signin
  caffeinate -dims maestro --device $UDID test --test-output-dir "$PWD/out/signin" \
    -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" \
    flows/_signin.yaml > logs/signin-warm.log 2>&1
}
say_mode() {
  case $1 in
    light) xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    dark)  xcrun simctl ui $UDID appearance dark  >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null ;;
    ax5)   xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size accessibility-extra-extra-extra-large >/dev/null ;;
    *) echo "unknown mode: $1"; return 2 ;;
  esac
}
pkill -f neon-branch-keepalive 2>/dev/null
NEON_DATA_API_URL="$BRANCH_URL" node $HOME/agents/scripts/neon-branch-keepalive.mjs > logs/keepalive-fill.log 2>&1 &
KA=$!; trap 'kill $KA 2>/dev/null' EXIT
sleep 15
for m in $MODES; do
  warm_signin
  say_mode $m || continue
  for f in $FLOWS; do
    echo "== $(date '+%H:%M:%S') fill $m / $f"
    xcrun simctl terminate $UDID $BUNDLE_ID >/dev/null 2>&1
    rm -rf "out/fill-$m-$f"
    caffeinate -dims maestro --device $UDID test --test-output-dir "$PWD/out/fill-$m-$f" \
      -e TEST_EMAIL="$TEST_EMAIL" -e TEST_PASSWORD="$TEST_PASSWORD" \
      "flows/$f.yaml" > "logs/fill-$m-$f.log" 2>&1
    rc=$?
    mkdir -p "shots/$m"
    find "out/fill-$m-$f" -path '*/takeScreenshot/*.png' -exec cp {} "shots/$m/" \; 2>/dev/null
    echo "   exit=$rc  shots/$m now $(ls shots/$m | wc -l | tr -d ' ')"
    grep -E '\[(Passed|Failed)\]' "logs/fill-$m-$f.log" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -2
  done
done
for m in $MODES; do
  mkdir -p "thumbs/$m"
  for f in shots/$m/*.png; do
    [ -e "$f" ] || continue
    sips -s format jpeg -s formatOptions 72 --resampleWidth 480 "$f" --out "thumbs/$m/$(basename ${f%.png}).jpg" >/dev/null 2>&1
  done
done
xcrun simctl ui $UDID appearance light >/dev/null; xcrun simctl ui $UDID content_size large >/dev/null
echo "== $(date '+%H:%M:%S') fill done; simulator restored to light / large"
