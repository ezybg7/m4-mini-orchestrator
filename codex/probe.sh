#!/usr/bin/env bash
# probe.sh — proves the Codex sandbox denials actually hold.
#
# THIS IS A HARD GATE, NOT A FORMALITY. Verified 2026-09-07 on codex-cli
# 0.153.2: a permissions profile with a misspelled filesystem key loads
# without error and denies NOTHING — under one such profile the sandbox read
# ~/.claude/oauth_token in full. Neither `codex doctor` nor
# `codex debug prompt-input` catches it. Only running commands under the
# sandbox does.
#
# Run: before the first real Codex run, and after every `codex update`.
# Needs no credentials — `codex sandbox` exercises Seatbelt without the model.
set -uo pipefail
# NOTE: no `pipefail` on the check pipelines — `grep -q` exits early and the
# resulting SIGPIPE would mark a *successful* denial as a failure. Every check
# below captures output into a variable first, then greps it.

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"; export CODEX_HOME
REPO="${REPO:-$HOME/code/pantry}"
WT="$(mktemp -d "${TMPDIR:-/tmp}/codex-probe-XXXXXX")"
pass=0; fail=0
ok(){   printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
bad(){  printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
run(){ codex sandbox -P "$1" -C "$2" -- "${@:3}" 2>&1; }

cleanup(){ git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"; }
trap cleanup EXIT

echo "CODEX_HOME=$CODEX_HOME"
codex debug prompt-input >/dev/null 2>&1 || { echo "config does not load"; exit 2; }

echo; echo "── pantry-review: secrets must be unreadable ──"
for f in "$HOME/.claude/oauth_token" "$HOME/.ssh/id_ed25519" \
         "$HOME/.config/gh/hosts.yml" "$HOME/agents/.env.acceptance" "$REPO/.env"; do
  [ -e "$f" ] || { printf '  ----  %s (absent, skipped)\n' "$f"; continue; }
  out="$(run pantry-review "$REPO" /bin/cat "$f")"
  if printf '%s' "$out" | grep -qiE 'not permitted|denied|no such file'; then
    ok "denied: $f"; else bad "READABLE: $f"; fi
done

echo; echo "── pantry-review: repo source must stay readable ──"
out="$(run pantry-review "$REPO" /bin/cat "$REPO/package.json")"
printf '%s' "$out" | grep -q '"name"' \
  && ok "repo source readable" || bad "repo source NOT readable (profile too tight)"

echo; echo "── pantry-review: no writes ──"
run pantry-review "$REPO" /usr/bin/touch "$WT/nope" >/dev/null 2>&1
[ -e "$WT/nope" ] && bad "wrote outside workspace under read-only" || ok "write refused under read-only"

echo; echo "── pantry-fix: worktree write yes, commit no, network no ──"
git -C "$REPO" worktree add --detach "$WT" >/dev/null 2>&1 || { echo "  (worktree add failed)"; }
if [ -d "$WT/.git" ] || [ -f "$WT/.git" ]; then
  run pantry-fix "$WT" /usr/bin/touch "$WT/probe-write" >/dev/null 2>&1
  [ -e "$WT/probe-write" ] && ok "write inside worktree allowed" || bad "cannot write inside worktree"

  out="$(run pantry-fix "$WT" /usr/bin/git -C "$WT" commit --allow-empty -m probe)"
  if printf '%s' "$out" | grep -qiE 'not permitted|denied|read-only|fatal|unable to'; then
    ok "git commit blocked in worktree"; else bad "GIT COMMIT SUCCEEDED — no merge authority guarantee"; fi

  out="$(run pantry-fix "$WT" /usr/bin/curl -sS --max-time 8 https://api.openai.com/v1/models)"
  if [ -z "$out" ] || printf '%s' "$out" | grep -qiE 'not permitted|denied|could not resolve|failed to connect|resolve host'; then
    ok "network blocked"; else bad "NETWORK REACHABLE from sandbox"; fi

  run pantry-fix "$WT" /usr/bin/touch "$HOME/codex-probe-escape" >/dev/null 2>&1
  [ -e "$HOME/codex-probe-escape" ] && { bad "ESCAPED: wrote to \$HOME"; rm -f "$HOME/codex-probe-escape"; } \
                                    || ok "no write outside worktree"

  out="$(run pantry-fix "$WT" /bin/cat "$HOME/.claude/oauth_token")"
  printf '%s' "$out" | grep -qiE 'not permitted|denied' \
    && ok "denied: oauth_token under pantry-fix" || bad "READABLE under pantry-fix: oauth_token"
fi

echo; echo "── execpolicy ──"
RULES="$REPO/.codex/rules/pantry.rules"
if [ -f "$RULES" ]; then
  out="$(codex execpolicy check --rules "$RULES" git push 2>/dev/null)"
  printf '%s' "$out" | grep -q '"decision":"forbidden"' \
    && ok "execpolicy forbids git push" || bad "execpolicy does NOT forbid git push"
  out="$(codex execpolicy check --rules "$RULES" npm test 2>/dev/null)"
  printf '%s' "$out" | grep -q '"matchedRules":\[\]' \
    && ok "execpolicy allows npm test" || bad "execpolicy wrongly matches npm test"
else
  printf '  ----  %s not present yet\n' "$RULES"
fi

echo; echo "════ $pass passed, $fail failed ════"
[ "$fail" -eq 0 ] || { echo "DO NOT RUN CODEX UNTIL THIS IS CLEAN."; exit 1; }
