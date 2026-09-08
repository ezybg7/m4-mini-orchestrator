#!/usr/bin/env bash
# Regression tests for lane.sh's refusals. No credentials needed.
set -u
L="$HOME/agents/codex/lane.sh"; p=0; f=0
expect(){ got="$($2 2>&1 | head -1)"; case "$got" in *"$1"*) p=$((p+1)); printf '  PASS  %s\n' "$3";;
  *) f=$((f+1)); printf '  FAIL  %s\n        got: %s\n' "$3" "$got";; esac; }
expect "usage:"    "bash $L"                        "no args -> usage"
expect "usage:"    "bash $L bogus x"                "unknown lane rejected"
expect "missing"   "bash $L review"                 "missing arg rejected"
expect "refusing"  "bash $L review main --yolo"     "--yolo refused"
expect "refusing"  "bash $L review main --dangerously-bypass-approvals-and-sandbox" "bypass flag refused"
echo "  $p passed, $f failed"; [ "$f" -eq 0 ]
