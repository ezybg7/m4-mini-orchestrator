#!/bin/zsh
export GH_REPO=${GH_REPO:-ezybg7/pantry}
# Robust PR merge watcher (2026-09-04): merges PR $1 (squash) only when `gh pr checks`
# is non-empty, every line is `pass`, a `checks pass` line exists, and the PR is OPEN.
# Empty output never merges (the #175 lesson). Pass --keep-branch to skip --delete-branch.
n=$1; extra="--delete-branch"; [ "$2" = "--keep-branch" ] && extra=""
for i in {1..240}; do
  out=$(gh pr checks "$n" 2>/dev/null)
  state=$(gh pr view "$n" --json state --jq .state 2>/dev/null)
  [ "$state" != "OPEN" ] && { echo "#$n is $state — nothing to do"; exit 0; }
  if [ -n "$out" ] && ! echo "$out" | awk '{print $2}' | grep -vq '^pass$' && echo "$out" | grep -qE '^checks[[:space:]]+pass'; then
    if gh pr merge "$n" --squash $extra 2>&1 | grep -v 'failed to delete local'; then :; fi
    sleep 3; echo "#$n $(gh pr view "$n" --json state --jq .state)"; exit 0
  fi
  if echo "$out" | awk '{print $2}' | grep -qE '^(fail|cancelled|error)$'; then echo "#$n NOT ALL PASS"; echo "$out"; exit 1; fi
  sleep 30
done
echo "#$n watcher timed out"; exit 1
