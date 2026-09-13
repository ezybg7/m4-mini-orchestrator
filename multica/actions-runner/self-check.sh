#!/bin/bash
# self-check.sh — spec 60 §Acceptance, the runner boxes, in the parts that can be proven
# from the orchestrator seat WITHOUT sudo.
#
#   Who runs it:  Everett or the orchestrator, as a normal user:
#                   bash ~/agents/multica/actions-runner/self-check.sh
#                 No sudo, no installation, no change to anything. Read-only.
#
# Three sections:
#   RUNS NOW      proven here and now; every line must be PASS after RUNBOOK step (b)+(e).
#                 Before the install, these FAIL by design — that is the "before" state.
#   NEEDS SUDO    the same file or domain, but only root may look — printed with the exact
#                 command, never attempted (this script must stay sudo-free).
#   NEEDS A JOB   boxes 2 and 3 of §Acceptance: proof-job.yml on a scratch branch.
#
# It never reads a credential file. Where a secret is involved the proof is that the read
# is DENIED; on an unexpected success it reports the byte count, never the bytes.
set -euo pipefail

REPO=ezybg7/pantry
RUNNER_NAME=m4-mini
LABEL=com.user.actions-runner-jit
PLIST=/Library/LaunchDaemons/$LABEL.plist
PRISTINE=/opt/actions-runner
SUPERVISOR=/opt/actions-runner-jit/actions-runner-jit.sh
CONF_DIR=/etc/actions-runner-jit
PAT_FILE=$CONF_DIR/jit_pat
UID_COUNTER=$CONF_DIR/uid_counter
JOBS_ROOT=/private/var/actions-runner-jobs
LOG_DIR=/var/log/actions-runner-jit
OLD_RUNNER_DIR=/Users/orchestrator/actions-runner
OLD_SVC_PLIST=/Users/orchestrator/Library/LaunchAgents/actions.runner.ezybg7-pantry.m4-mini.plist
RUNNER_PATH_LINE='/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
GH=/opt/homebrew/bin/gh
JQ=/opt/homebrew/bin/jq

say()  { printf '\n== %s\n' "$*"; }
FAILS=()
pass() { printf '  PASS  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILS+=("$*"); }
info() { printf '  ....  %s\n' "$*"; }
sudocmd() { printf '  SUDO  %s\n            %s\n' "$1" "$2"; }
denied() {  # <description> <command...> — PASS only when it fails with a permission error
  local desc=$1; shift
  local out rc=0
  out=$("$@" 2>&1) || rc=$?
  if (( rc == 0 )); then fail "$desc — SUCCEEDED (must be denied; ${#out} bytes came back, not shown)"
  elif grep -qi 'permission denied' <<<"$out"; then pass "$desc — Permission denied"
  else fail "$desc — failed for the wrong reason: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; fi
}

printf 'spec 60 §Acceptance — runner boxes, no-sudo proofs\n'
printf 'host %s · as %s (uid %s) · %s UTC\n' "$(hostname -s)" "$(id -un)" "$(id -u)" "$(date -u +%FT%TZ)"

# ============================================================================
say "RUNS NOW — 1. the registration state (box 1: the runner is ephemeral)"
# ============================================================================
if runners=$("$GH" api "repos/$REPO/actions/runners" 2>&1); then
  q() { printf '%s' "$runners" | "$JQ" "$@" 2>/dev/null || echo 0; }
  eph=$(q     "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true)] | length")
  online=$(q  "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true and .status==\"online\")] | length")
  offline=$(q "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true and .status!=\"online\")] | length")
  pers=$(q    '[.runners[] | select(.ephemeral != true)] | length')
  printf '%s' "$runners" | "$JQ" -r '.runners[] | "        id=\(.id) name=\(.name) status=\(.status) busy=\(.busy) ephemeral=\(.ephemeral) labels=\([.labels[].name]|join(","))"' || true
  [[ $eph == 1 ]]     && pass "exactly one ephemeral $RUNNER_NAME runner is registered"         || fail "ephemeral $RUNNER_NAME runners: $eph (expected 1 between jobs)"
  [[ $online == 1 ]]  && pass "it is online"                                                    || fail "online ephemeral $RUNNER_NAME runners: $online (expected 1)"
  [[ $offline == 0 ]] && pass "no stale offline ephemeral registration"                          || fail "$offline offline ephemeral registration(s) — the gate reads these as an outage (FIND-010)"
  [[ $pers == 0 ]]    && pass "no non-ephemeral runner is registered (the persistent m4-mini is gone)" \
                      || fail "$pers non-ephemeral runner(s) registered — RUNBOOK step (e) is still pending"
else
  fail "gh api repos/$REPO/actions/runners failed: $(printf '%s' "$runners" | tr '\n' ' ' | cut -c1-140)"
fi

# ============================================================================
say "RUNS NOW — 2. the pristine install is root-owned and unwritable"
# ============================================================================
mode_is() {  # <path> <mode> <owner:group>
  local got; got=$(stat -f '%Lp %Su:%Sg' "$1" 2>/dev/null || true)
  [[ $got == "$2 $3" ]] && pass "$1 is $2 $3" || fail "$1 is '${got:-missing}', expected '$2 $3'"
}
mode_is "$PRISTINE" 755 root:wheel
mode_is "$PRISTINE/.path" 644 root:wheel
mode_is "$PRISTINE/.env" 644 root:wheel
mode_is "$SUPERVISOR" 755 root:wheel
mode_is "$JOBS_ROOT" 755 root:wheel
if [[ -r $PRISTINE/.jit-pin ]]; then
  pin=$(awk '{print $1}' "$PRISTINE/.jit-pin" 2>/dev/null || true)
  v=$("$PRISTINE/bin/Runner.Listener" --version 2>/dev/null | tr -d '\r' || true)
  [[ -n $pin && $v == "$pin" ]] && pass "Runner.Listener $v matches .jit-pin ($pin)" || fail "Runner.Listener '$v' vs .jit-pin '$pin'"
else
  fail "$PRISTINE/.jit-pin is missing — the install did not complete"
fi
if [[ -r $PRISTINE/.path ]]; then
  [[ $(cat "$PRISTINE/.path" 2>/dev/null || true) == "$RUNNER_PATH_LINE" ]] && pass ".path is Homebrew-first, as the persistent runner was" || fail ".path is not the expected line"
fi
if [[ -e $PRISTINE ]]; then
  [[ -w $PRISTINE ]] && fail "$PRISTINE is writable by $(id -un)" || pass "$PRISTINE is not writable by $(id -un)"
  denied "touch $PRISTINE/probe-$(id -u)" touch "$PRISTINE/probe-$(id -u)"
fi
if [[ -x $SUPERVISOR ]]; then
  bash -n "$SUPERVISOR" 2>/dev/null && pass "the installed supervisor parses (bash -n)" || fail "the installed supervisor does not parse"
fi

# ============================================================================
say "RUNS NOW — 3. the root-only files are root-only"
# ============================================================================
if [[ -d $CONF_DIR ]]; then
  pass "$CONF_DIR exists"
  denied "ls $CONF_DIR"      ls "$CONF_DIR"
  denied "cat $PAT_FILE"     cat "$PAT_FILE"
  denied "cat $UID_COUNTER"  cat "$UID_COUNTER"
else
  fail "$CONF_DIR does not exist — the PAT file and UID counter are not installed"
fi
if [[ -d $LOG_DIR ]]; then
  pass "$LOG_DIR exists (root-owned, not in a user home)"
  denied "ls $LOG_DIR" ls "$LOG_DIR"
else
  fail "$LOG_DIR does not exist"
fi

# ============================================================================
say "RUNS NOW — 4. the LaunchDaemon"
# ============================================================================
if [[ -f $PLIST ]]; then
  mode_is "$PLIST" 644 root:wheel
  plutil -lint "$PLIST" >/dev/null 2>&1 && pass "$PLIST lints" || fail "$PLIST does not lint"
  grep -q '<key>KeepAlive</key>' "$PLIST" && pass "KeepAlive is set" || fail "KeepAlive is not set"
  grep -q '<key>ExitTimeOut</key>' "$PLIST" && pass "ExitTimeOut is set (teardown gets time before SIGKILL)" || fail "ExitTimeOut is not set"
  grep -q '<key>UserName</key>' "$PLIST" && fail "the plist has a UserName key — the supervisor must run as root" || pass "no UserName key: the supervisor runs as root"
  grep -q "<string>$LOG_DIR/supervisor.log</string>" "$PLIST" && pass "StandardOutPath is under $LOG_DIR (never a user home)" || fail "StandardOutPath is not $LOG_DIR/supervisor.log"
  grep -q "<string>$SUPERVISOR</string>" "$PLIST" && pass "ProgramArguments runs $SUPERVISOR" || fail "the plist does not run $SUPERVISOR"
else
  fail "$PLIST is missing"
fi

# ============================================================================
say "RUNS NOW — 5. no principal and no state between jobs (box 3)"
# ============================================================================
accts=$(dscl . -list /Users | grep -E '^job-[0-9]+$' || true)
if [[ -z $accts ]]; then pass "no job-* account exists in Directory Services"
else fail "job-* account(s) exist between jobs: $(printf '%s' "$accts" | tr '\n' ' ')"; fi
if [[ -d $JOBS_ROOT ]]; then
  left=$(ls -A "$JOBS_ROOT" 2>/dev/null | tr '\n' ' ' || true)
  if [[ -z ${left// /} ]]; then pass "$JOBS_ROOT is empty"
  else info "$JOBS_ROOT holds: $left  (expected only while a job is running — see the live check below)"; fi
fi
if pgrep -qf 'bin/Runner\.Listener' 2>/dev/null; then
  info "a runner is live — checking who owns it (§Acceptance box 1, during a job):"
  ps -o user=,uid=,pid=,args= -p "$(pgrep -f 'bin/Runner\.Listener' | tr '\n' ',' | sed 's/,$//')" 2>/dev/null | cut -c1-150 | sed 's/^/        /' || true
  u=$(ps -o user= -p "$(pgrep -f 'bin/Runner\.Listener' | awk 'NR==1{print}')" 2>/dev/null | tr -d ' ' || true)
  if [[ $u == job-* ]]; then
    pass "Runner.Listener runs as $u"
    h=$(dscl . -read "/Users/$u" NFSHomeDirectory 2>/dev/null | awk '{print $2}' || true)
    [[ $h == $JOBS_ROOT/* ]] && pass "its home is $h (inside the per-job root)" || fail "its home is '$h', not under $JOBS_ROOT"
  else
    fail "Runner.Listener runs as '$u' — it must be a job-<n> account, never a human account"
  fi
else
  info "no Runner.Listener process right now (between jobs, or the daemon is stopped — check the state under NEEDS SUDO)"
fi

# ============================================================================
say "RUNS NOW — 6. the persistent runner is retired (RUNBOOK step (e))"
# ============================================================================
if [[ -f $OLD_SVC_PLIST ]]; then fail "the old LaunchAgent still exists: $OLD_SVC_PLIST — step (e) is pending"
else pass "no LaunchAgent at $OLD_SVC_PLIST"; fi
if launchctl print "gui/$(id -u)/actions.runner.ezybg7-pantry.m4-mini" >/dev/null 2>&1; then
  fail "the old runner service is still loaded in gui/$(id -u)"
else pass "the old runner service is not loaded in gui/$(id -u)"; fi
for f in .credentials .credentials_rsaparams .runner; do
  if [[ -e $OLD_RUNNER_DIR/$f ]]; then fail "$OLD_RUNNER_DIR/$f still exists (existence only — never read)"
  else pass "$OLD_RUNNER_DIR/$f is gone"; fi
done
procs=$(ps -x -o user=,args= -U "$(id -un)" 2>/dev/null || true)
if grep -qE '/bin/[R]unner\.Listener( |$)' <<<"$procs"; then
  fail "a Runner.Listener process is running as $(id -un) — CI must never run as a human account again"
else pass "no Runner.Listener process runs as $(id -un)"; fi

# ============================================================================
say "NEEDS SUDO — same proofs, root's to read"
# ============================================================================
sudocmd "the daemon is loaded and running"      "sudo launchctl print system/$LABEL | grep -E 'state|pid|last exit'"
sudocmd "the supervisor's own log (one line per event)" "sudo tail -50 $LOG_DIR/supervisor.log"
sudocmd "errors only"                            "sudo tail -50 $LOG_DIR/supervisor.err.log"
sudocmd "the UID counter is monotonic"           "sudo cat $UID_COUNTER    # must be strictly greater after every job"
sudocmd "no leftover in another user's temp"     "sudo find /private/var/folders -user <uid of the finished job> -print"
sudocmd "the PAT file's mode (never its content)" "sudo stat -f '%Lp %Su:%Sg %N' $PAT_FILE   # expect 600 root:wheel"

# ============================================================================
say "NEEDS A JOB — boxes 2 and 3 (proof-job.yml on a scratch branch)"
# ============================================================================
cat <<EOF
  Push the proof workflow to a scratch branch and read its result. It must NEVER
  reach main (spec 60 §Acceptance; it deliberately writes markers and detaches a process).

    cd ~/code/pantry && git fetch origin && git switch -c scratch/jit-proof origin/main
    mkdir -p .github/workflows
    cp ~/agents/multica/actions-runner/proof-job.yml .github/workflows/jit-proof.yml
    git add .github/workflows/jit-proof.yml
    git commit -m "scratch: JIT runner proof job (do not merge)"
    git push -u origin scratch/jit-proof
    gh run watch "\$(gh run list -b scratch/jit-proof -L1 --json databaseId --jq '.[0].databaseId')"
    gh run view  "\$(gh run list -b scratch/jit-proof -L1 --json databaseId --jq '.[0].databaseId')" --log | less

  Read the run's summary (the job writes it to the step summary): the account name,
  its UID, one PASS/FAIL line per denied read and write, and the after-job commands.
  Then, back here, with <uid> from that summary:

    dscl . -read /Users/job-<uid>                      # must fail: no such record
    ls -d $JOBS_ROOT/<uid>                            # must fail: no such directory
    find /private/tmp /private/var/tmp /Users/Shared -user <uid> -print   # must print nothing
    sudo find /private/var/folders -user <uid> -print                     # must print nothing
    sudo crontab -u job-<uid> -l                       # must fail: no such user
    pgrep -U <uid>                                     # must print nothing
    bash ~/agents/multica/actions-runner/self-check.sh  # re-run: every line PASS again

  Run the workflow a second time (gh workflow run jit-proof.yml --ref scratch/jit-proof)
  and confirm the new UID is HIGHER and that its first step shows none of the previous
  job's git/npm config. Then the two interrupted cases from box 3, mid-job:
    sudo launchctl kickstart -k system/$LABEL     # the SIGTERM trap tears the job down
    sudo pkill -9 -f actions-runner-jit.sh        # KeepAlive restarts it; the startup sweep cleans up
  After each, repeat the <uid> checks above. Finally delete the branch:
    git push origin --delete scratch/jit-proof
EOF

printf '\n'
if [[ ${#FAILS[@]} -gt 0 ]]; then
  printf 'RUNS NOW: %d FAIL(s)\n' "${#FAILS[@]}"
  printf '  - %s\n' "${FAILS[@]}"
  printf '\nBefore the install every line above fails by design. After it, each FAIL is a real finding.\n'
  exit 1
fi
printf 'RUNS NOW: every check passed.\n'
