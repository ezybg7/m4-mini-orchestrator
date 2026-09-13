#!/bin/zsh
# prune-out.sh — drop Maestro's per-run debug trees once the PNGs have been
# collected into shots/. Keeps each run's manifest.json and the failure
# screenshots, which are the only parts worth re-reading.
#
# RUN THIS AFTER EVERY TOUR, not just to save the ~350 MB. Maestro writes the
# values it was given with `-e` into `commands.json` (the flow's
# defineVariablesCommand) and into `logs/maestro.log` — so a finished run leaves
# TEST_PASSWORD in plain text under out/. Those are exactly the two things this
# script deletes. Verify afterwards with:
#   source ./env.sh && grep -rlF "$TEST_PASSWORD" . || echo clean
set -u
cd "$(dirname $0)/.." || exit 2
before=$(du -sm out 2>/dev/null | cut -f1)
find out -type d -name screen-hierarchy -prune -exec rm -rf {} + 2>/dev/null
find out -type d -name takeScreenshot -prune -exec rm -rf {} + 2>/dev/null
find out -type d -name logs -prune -exec rm -rf {} + 2>/dev/null
find out -name "xctest_runner_*.log" -delete 2>/dev/null
find out -name "commands.json" -delete 2>/dev/null
after=$(du -sm out 2>/dev/null | cut -f1)
echo "out/: ${before}M -> ${after}M (kept manifest.json and the per-step failure screenshots)"
