#!/bin/bash
# actions-runner-jit.sh — spec 60 §The runner: the root supervisor loop behind
# /Library/LaunchDaemons/com.user.actions-runner-jit.plist.
#
#   Who runs it:  launchd, as root, KeepAlive. Never a human, except:
#                   sudo bash /opt/actions-runner-jit/actions-runner-jit.sh --once
#                   sudo bash /opt/actions-runner-jit/actions-runner-jit.sh --sweep-only
#                 and only with the daemon booted out (a lock refuses a second instance).
#   Installed by: setup-actions-runner.sh (this file is its payload; do not edit in place —
#                 edit ~/agents/multica/actions-runner/actions-runner-jit.sh and re-run the setup).
#
# One cycle = one job, one OS principal:
#   1. allocate the next UID from the root-only monotonic counter (never reused)
#   2. create account job-<uid>, primary group actions-jobs, hidden, no usable login,
#      home/work/tmp inside /private/var/actions-runner-jobs/<uid>/, mode 700
#   3. clone the pristine root-owned runner from /opt/actions-runner into the per-job root
#      (the runner writes _diag/ and rewrites run-helper.sh in its own root, so it cannot
#      run out of a root-owned 755 install; /opt stays pristine and unwritable to jobs)
#   4. mint a single-use JIT registration with the root-only PAT (GH_TOKEN, one gh call)
#   5. run it as that account until the one job ends (ephemeral JIT runners exit after one job)
#   6. TEARDOWN BY UID — on normal exit, on error, on SIGTERM, and for leftovers at every start
#   7. loop
#
# Secrets: the PAT is read into a variable for exactly one `gh` call and is never
# logged, never written, never in argv. The JIT config is a single-use runner
# credential; it is never logged either. It does reach run.sh's argv, where any
# local account can read it with `ps` until the job ends (macOS does not hide argv
# across users — measured 2026-09-12) — that is the credential the job holds anyway
# (spec 60 §What a job holds), it is consumed at runner start, and it dies with the job.
set -euo pipefail

# ----------------------------------------------------------------------------
# Constants — keep in step with setup-actions-runner.sh
# ----------------------------------------------------------------------------
REPO=ezybg7/pantry
RUNNER_NAME=m4-mini                       # so every workflow's runs-on is unchanged
RUNNER_GROUP_ID=1                         # Default
RUNNER_LABELS=(self-hosted macOS ARM64 m4-mini)
RUNNER_LABELS_FALLBACK=(m4-mini)          # if GitHub refuses the reserved names (it adds them itself)

PRISTINE=/opt/actions-runner              # root:wheel 755, the pinned release
JOBS_ROOT=/private/var/actions-runner-jobs # root:wheel 755, per-job roots live here
CONF_DIR=/etc/actions-runner-jit          # root:wheel 700
PAT_FILE=$CONF_DIR/jit_pat                # root:wheel 600 — fine-grained PAT, Administration: write
UID_COUNTER=$CONF_DIR/uid_counter         # root:wheel 600 — next UID to allocate
LOCK_DIR=/var/run/actions-runner-jit.lock

JOB_GROUP=actions-jobs
JOB_PREFIX=job-                           # account name is job-<uid>: one number, self-describing
UID_MIN=5000                              # see RUNBOOK "Why UID 5000+"
UID_MAX=60000
RUNNER_SHELL=/bin/bash

# PATH for the job account: Homebrew first, exactly as /opt/actions-runner/.path.
JOB_PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
# Absolute paths for everything the supervisor itself runs, so a PATH game cannot redirect root.
GH=/opt/homebrew/bin/gh
JQ=/opt/homebrew/bin/jq
DSCL=/usr/bin/dscl
SYSADMINCTL=/usr/sbin/sysadminctl
DSEDITGROUP=/usr/sbin/dseditgroup
LAUNCHCTL=/bin/launchctl
PKILL=/usr/bin/pkill
PGREP=/usr/bin/pgrep
SUDO=/usr/bin/sudo
CRONTAB=/usr/bin/crontab
CRON_TABS=/usr/lib/cron/tabs

BACKOFF_BASE=30                           # seconds, doubled per consecutive failure
BACKOFF_MAX=300
IDLE_SLEEP=2                              # breathing room between cycles
TERM_GRACE=5                              # seconds a mid-job runner gets to cancel cleanly
HARDEN_DISABLE_LOGIN=1                    # mark the account ;DisabledUser; — see RUNBOOK Residuals

ONCE=0; SWEEP_ONLY=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --once)       ONCE=1 ;;
    --sweep-only) SWEEP_ONLY=1 ;;
    -h|--help)    sed -n '2,29p' "$0"; exit 0 ;;
    *) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# ----------------------------------------------------------------------------
# Logging — one line per event, UTC, never a secret
# ----------------------------------------------------------------------------
log()   { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
warn()  { log "WARN  $*" >&2; }
fatal() { log "FATAL $*" >&2; exit 1; }   # KeepAlive restarts us; ThrottleInterval bounds the loop

# State of the cycle in flight, so the EXIT trap can always tear it down.
CUR_UID=""; CUR_ACCT=""; CUR_ROOT=""; CUR_RUNNER_ID=""; CHILD_PID=""

# ----------------------------------------------------------------------------
# Teardown — the boundary. Idempotent, never fatal, always by UID.
# ----------------------------------------------------------------------------
teardown() {  # <uid> [account] [per-job root]
  local uid=$1 acct=${2:-} root=${3:-} n i left
  [[ $uid =~ ^[0-9]+$ ]] || { warn "teardown: refusing a non-numeric uid '$uid'"; return 0; }
  (( uid >= UID_MIN && uid <= UID_MAX )) || { warn "teardown: refusing uid $uid outside $UID_MIN-$UID_MAX"; return 0; }
  [[ -n $acct ]] || acct="$JOB_PREFIX$uid"
  [[ -n $root ]] || root="$JOBS_ROOT/$uid"
  log "teardown uid=$uid account=$acct root=$root — start"
  set +e

  # 1. anything the job registered with launchd
  if $LAUNCHCTL print "user/$uid" >/dev/null 2>&1; then
    $LAUNCHCTL bootout "user/$uid" >/dev/null 2>&1
    log "teardown uid=$uid launchctl bootout user/$uid done"
  fi

  # 2. every process of that UID, however it detached
  for i in 1 2 3 4 5 6 7 8 9 10; do
    $PGREP -U "$uid" >/dev/null 2>&1 || break
    n=$($PGREP -U "$uid" 2>/dev/null | wc -l | tr -d ' ')
    $PKILL -9 -U "$uid" >/dev/null 2>&1
    log "teardown uid=$uid pkill -9 pass $i ($n process(es))"
    sleep 1
  done
  if $PGREP -U "$uid" >/dev/null 2>&1; then
    warn "teardown uid=$uid still has processes after 10 passes — leaving the account in place for inspection"
    set -e; return 1
  fi

  # 3. the crontab, before the record goes (and the spool file after, which works either way)
  $CRONTAB -u "$acct" -r >/dev/null 2>&1
  rm -f "$CRON_TABS/$acct"

  # 4. the account itself
  if $DSCL . -read "/Users/$acct" >/dev/null 2>&1; then
    $SYSADMINCTL -deleteUser "$acct" >/dev/null 2>&1
    if $DSCL . -read "/Users/$acct" >/dev/null 2>&1; then
      warn "teardown uid=$uid sysadminctl -deleteUser left the record — falling back to dscl -delete"
      $DSCL . -delete "/Users/$acct" >/dev/null 2>&1
    fi
    if $DSCL . -read "/Users/$acct" >/dev/null 2>&1; then
      warn "teardown uid=$uid the account record SURVIVED deletion — do not let the next job start; see the runbook"
      set -e; return 1
    fi
    log "teardown uid=$uid account $acct deleted"
  fi

  # 5. the per-job root (home, work, tmp and the runner clone all live inside it)
  if [[ -d $root ]]; then
    case $root in "$JOBS_ROOT"/*) rm -rf "$root"; log "teardown uid=$uid removed $root" ;;
                  *) warn "teardown uid=$uid refusing to remove '$root' — not under $JOBS_ROOT" ;; esac
  fi

  # 6. every path a non-admin account can write outside its home (by numeric uid: the name is gone)
  left=$(find /private/tmp /private/var/tmp /private/var/folders /Users/Shared -user "$uid" -depth -print 2>/dev/null)
  if [[ -n $left ]]; then
    n=$(printf '%s\n' "$left" | wc -l | tr -d ' ')
    printf '%s\n' "$left" | while IFS= read -r p; do [[ -n $p ]] && rm -rf "$p"; done
    log "teardown uid=$uid swept $n leftover path(s) from /private/tmp /private/var/tmp /private/var/folders /Users/Shared"
  fi
  left=$(find /private/tmp /private/var/tmp /private/var/folders /Users/Shared -user "$uid" -print 2>/dev/null | head -5)
  [[ -z $left ]] || warn "teardown uid=$uid sweep did not converge: $(printf '%s' "$left" | tr '\n' ' ')"

  set -e
  log "teardown uid=$uid — done"
  return 0
}

# Drop the JIT registration if the runner never consumed it (a stale offline entry would
# make the poller's gate read "no online ephemeral runner"; spec 60 FIND-010).
delete_registration() {  # <runner id>
  local id=$1 pat
  [[ $id =~ ^[0-9]+$ ]] || return 0
  pat=$(cat "$PAT_FILE" 2>/dev/null) || { warn "cannot read the PAT file to delete registration $id"; return 0; }
  if GH_TOKEN="$pat" $GH api -X DELETE "repos/$REPO/actions/runners/$id" >/dev/null 2>&1; then
    log "registration $id deleted"
  else
    log "registration $id already gone (the ephemeral runner deregistered itself)"
  fi
  pat=""
}

# Clear stale offline *ephemeral* m4-mini registrations left by a crash. Never touches a
# persistent registration — removing that one is Everett's explicit step (--remove-persistent).
prune_stale_registrations() {
  local pat ids id
  pat=$(cat "$PAT_FILE" 2>/dev/null) || return 0
  ids=$(GH_TOKEN="$pat" $GH api "repos/$REPO/actions/runners" --paginate \
        --jq ".runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true and .status==\"offline\") | .id" 2>/dev/null) || ids=""
  pat=""
  for id in $ids; do
    delete_registration "$id"
    log "pruned stale offline ephemeral registration $id"
  done
}

on_exit() {
  local rc=$?
  trap - EXIT
  if [[ -n $CHILD_PID ]] && kill -0 "$CHILD_PID" 2>/dev/null; then
    log "stopping the in-flight runner (pid $CHILD_PID) — grace ${TERM_GRACE}s"
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    for _ in $(seq 1 "$TERM_GRACE"); do kill -0 "$CHILD_PID" 2>/dev/null || break; sleep 1; done
  fi
  if [[ -n $CUR_UID ]]; then
    log "exit rc=$rc with job $CUR_ACCT in flight — tearing it down"
    teardown "$CUR_UID" "$CUR_ACCT" "$CUR_ROOT" || true
    [[ -n $CUR_RUNNER_ID ]] && delete_registration "$CUR_RUNNER_ID" || true
  fi
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  log "supervisor exit rc=$rc"
  exit "$rc"
}

# ----------------------------------------------------------------------------
# Leftovers: every job-* account and every per-job root, at every start
# ----------------------------------------------------------------------------
sweep_leftovers() {
  local found=0 name uid d
  while read -r name uid; do
    [[ $name == $JOB_PREFIX* ]] || continue
    [[ $uid =~ ^[0-9]+$ ]] || continue
    log "startup sweep: leftover account $name (uid $uid)"
    teardown "$uid" "$name" "$JOBS_ROOT/$uid" || true
    found=$((found + 1))
  done < <($DSCL . -list /Users UniqueID 2>/dev/null | awk -v p="^${JOB_PREFIX}[0-9]+$" '$1 ~ p {print $1, $2}')

  for d in "$JOBS_ROOT"/*; do
    [[ -d $d ]] || continue
    uid=${d##*/}
    [[ $uid =~ ^[0-9]+$ ]] || { warn "startup sweep: $d is not a numeric per-job root — leaving it"; continue; }
    log "startup sweep: leftover per-job root $d"
    teardown "$uid" "$JOB_PREFIX$uid" "$d" || true
    found=$((found + 1))
  done

  # Monotonicity: never hand out a UID at or below anything we just swept.
  local hi=0 cur
  for d in "$JOBS_ROOT"/*; do [[ -d $d ]] || continue; uid=${d##*/}; [[ $uid =~ ^[0-9]+$ ]] && (( uid > hi )) && hi=$uid; done
  if (( hi > 0 )); then
    cur=$(cat "$UID_COUNTER" 2>/dev/null || echo 0)
    [[ $cur =~ ^[0-9]+$ ]] || cur=0
    (( cur <= hi )) && { printf '%s\n' "$((hi + 1))" > "$UID_COUNTER.tmp"; chmod 600 "$UID_COUNTER.tmp"; mv -f "$UID_COUNTER.tmp" "$UID_COUNTER"; log "startup sweep: counter advanced past a leftover to $((hi + 1))"; }
  fi
  prune_stale_registrations
  log "startup sweep: $found leftover(s) handled"
}

# ----------------------------------------------------------------------------
# UID allocation — monotonic, never reused, never on top of an existing account
# ----------------------------------------------------------------------------
uid_taken() {  # <uid>
  local u=$1
  [[ -n $($DSCL . -search /Users UniqueID "$u" 2>/dev/null) ]] && return 0
  $DSCL . -read "/Users/$JOB_PREFIX$u" >/dev/null 2>&1 && return 0
  [[ -e $JOBS_ROOT/$u ]] && return 0
  return 1
}

next_uid() {
  local n
  n=$(cat "$UID_COUNTER" 2>/dev/null) || fatal "cannot read $UID_COUNTER"
  n=${n//[[:space:]]/}
  [[ $n =~ ^[0-9]+$ ]] || fatal "$UID_COUNTER does not hold a number"
  (( n >= UID_MIN )) || fatal "$UID_COUNTER holds $n, below the floor $UID_MIN"
  while uid_taken "$n"; do
    log "uid $n is already taken — skipping it (a UID is never reused)"
    n=$((n + 1))
    (( n <= UID_MAX )) || fatal "UID counter exhausted at $UID_MAX"
  done
  (( n <= UID_MAX )) || fatal "UID counter exhausted at $UID_MAX"
  # Bump before use: a crash between here and account creation loses a UID, never reuses one.
  printf '%s\n' "$((n + 1))" > "$UID_COUNTER.tmp"
  chmod 600 "$UID_COUNTER.tmp"; chown root:wheel "$UID_COUNTER.tmp"
  mv -f "$UID_COUNTER.tmp" "$UID_COUNTER"
  printf '%s\n' "$n"
}

# ----------------------------------------------------------------------------
# The throwaway account
# ----------------------------------------------------------------------------
create_account() {  # <uid>
  local uid=$1 acct="$JOB_PREFIX$1" root="$JOBS_ROOT/$1" pw out d l
  install -d -o root -g wheel -m 755 "$root"
  # A random password nobody keeps: sysadminctl needs one or it prompts. It is on
  # sysadminctl's argv for ~2s (readable by any local account), so the record is marked
  # ;DisabledUser; immediately afterwards, which makes a captured password worthless.
  pw=$(/usr/bin/openssl rand -base64 64 | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-48)
  if ! out=$($SYSADMINCTL -addUser "$acct" -fullName "GitHub Actions job $uid" \
                -UID "$uid" -GID "$JOB_GID" \
                -shell "$RUNNER_SHELL" -home "$root/home" -password "$pw" 2>&1); then
    pw=""
    warn "sysadminctl -addUser $acct failed: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
    return 1
  fi
  pw=""
  # SecureToken warnings are expected and harmless (this account never unlocks FileVault).
  printf '%s\n' "$out" | grep -vi 'secure token' | sed '/^[[:space:]]*$/d' | while IFS= read -r l; do log "sysadminctl: $l"; done || true

  $DSCL . -create "/Users/$acct" IsHidden 1 2>/dev/null || warn "could not set IsHidden on $acct"
  if [[ $HARDEN_DISABLE_LOGIN == 1 ]]; then
    $DSCL . -append "/Users/$acct" AuthenticationAuthority ';DisabledUser;' 2>/dev/null \
      || warn "could not mark $acct ;DisabledUser; (login stays behind the random password)"
  fi

  for d in home work tmp; do
    install -d -o "$acct" -g "$JOB_GROUP" -m 700 "$root/$d"
  done
  chown -R "$acct:$JOB_GROUP" "$root/home"
  # Directory Services can take a moment to publish a new record; give it a few tries
  # before declaring the account unusable (the caller would otherwise burn a UID).
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ $(id -u "$acct" 2>/dev/null) == "$uid" ]] && break
    sleep 1
  done
  [[ $(id -u "$acct" 2>/dev/null) == "$uid" ]] || { warn "$acct does not resolve to uid $uid after 10s"; return 1; }
  log "account $acct created: uid=$uid group=$JOB_GROUP home=$root/home shell=$RUNNER_SHELL hidden=yes admin=no"
  return 0
}

# The runner cannot run out of the root-owned install: run.sh rewrites run-helper.sh in
# its own directory and the listener writes _diag/ there. Each job gets its own copy
# (APFS clone where possible: near-instant, no extra space).
clone_runner() {  # <uid>
  local uid=$1 acct="$JOB_PREFIX$1" root="$JOBS_ROOT/$1" dst="$JOBS_ROOT/$1/runner"
  if ! cp -Rpc "$PRISTINE" "$dst" 2>/dev/null; then
    cp -Rp "$PRISTINE" "$dst" || { warn "could not copy $PRISTINE to $dst"; return 1; }
    log "runner copied to $dst (plain copy — APFS clone unavailable)"
  else
    log "runner cloned to $dst (APFS clonefile)"
  fi
  chown -R "$acct:$JOB_GROUP" "$dst"
  chmod 700 "$dst"
  # The job's own TMPDIR for every step the runner launches. .env is KEY=VALUE only — no comments.
  printf 'TMPDIR=%s\n' "$root/tmp" >> "$dst/.env"
  rm -f "$dst/.jit-pin"
  return 0
}

# ----------------------------------------------------------------------------
# The JIT registration — one gh call, the PAT only in its environment
# ----------------------------------------------------------------------------
MINT_JSON=""   # holds a single-use credential between mint_jit and run_job; never logged
mint_jit() {   # <uid> ; sets MINT_JSON
  local uid=$1 root="$JOBS_ROOT/$1" pat args=() l out rc
  pat=$(cat "$PAT_FILE" 2>/dev/null) || { warn "cannot read $PAT_FILE"; return 1; }
  [[ -n $pat ]] || { warn "$PAT_FILE is empty"; return 1; }

  args=(api -X POST "repos/$REPO/actions/runners/generate-jitconfig"
        -f "name=$RUNNER_NAME" -F "runner_group_id=$RUNNER_GROUP_ID" -f "work_folder=$root/work")
  for l in "${RUNNER_LABELS[@]}"; do args+=(-f "labels[]=$l"); done

  rc=0; out=$(GH_TOKEN="$pat" $GH "${args[@]}" 2>&1) || rc=$?
  if (( rc != 0 )) && grep -qiE 'already exists|409' <<<"$out"; then
    log "mint refused: the name $RUNNER_NAME is still registered — pruning stale entries and retrying once"
    prune_stale_registrations
    rc=0; out=$(GH_TOKEN="$pat" $GH "${args[@]}" 2>&1) || rc=$?
  fi
  if (( rc != 0 )) && grep -qiE 'label|422' <<<"$out"; then
    log "mint refused the label list — retrying with the custom label only (GitHub adds the read-only ones)"
    args=(api -X POST "repos/$REPO/actions/runners/generate-jitconfig"
          -f "name=$RUNNER_NAME" -F "runner_group_id=$RUNNER_GROUP_ID" -f "work_folder=$root/work")
    for l in "${RUNNER_LABELS_FALLBACK[@]}"; do args+=(-f "labels[]=$l"); done
    rc=0; out=$(GH_TOKEN="$pat" $GH "${args[@]}" 2>&1) || rc=$?
  fi
  pat=""

  if (( rc != 0 )); then
    # The error body can echo request fields; it never contains the config (the call failed).
    warn "generate-jitconfig failed (rc=$rc): $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-240)"
    out=""; return 1
  fi
  MINT_JSON=$out; out=""
  CUR_RUNNER_ID=$(printf '%s' "$MINT_JSON" | $JQ -r '.runner.id // empty')
  [[ -n $CUR_RUNNER_ID ]] || { warn "generate-jitconfig returned no runner id"; MINT_JSON=""; return 1; }
  log "jit config minted: runner_id=$CUR_RUNNER_ID name=$RUNNER_NAME labels=$(printf '%s,' "${RUNNER_LABELS[@]}" | sed 's/,$//') work_folder=$root/work"
  return 0
}

# ----------------------------------------------------------------------------
# Run one job as the throwaway account
# ----------------------------------------------------------------------------
run_job() {  # <uid> ; consumes MINT_JSON
  local uid=$1 acct="$JOB_PREFIX$1" root="$JOBS_ROOT/$1" jit rc=0 started elapsed
  jit=$(printf '%s' "$MINT_JSON" | $JQ -r '.encoded_jit_config // empty')
  MINT_JSON=""
  [[ -n $jit ]] || { warn "no encoded_jit_config in the mint response"; return 1; }

  log "job start: account=$acct uid=$uid runner_id=$CUR_RUNNER_ID root=$root"
  started=$(date +%s)
  # sudo -u, not launchctl asuser: an account that never logs in has no gui/<uid> domain to
  # bootstrap into, and `env -i` gives the listener a clean, login-less environment.
  # Backgrounded and waited on so a SIGTERM reaches the trap at once instead of being
  # deferred until the job finishes (bash defers traps during a foreground child).
  $SUDO -u "$acct" -H /usr/bin/env -i \
      HOME="$root/home" USER="$acct" LOGNAME="$acct" SHELL="$RUNNER_SHELL" \
      PATH="$JOB_PATH" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
      TMPDIR="$root/tmp" HOMEBREW_PREFIX=/opt/homebrew \
      RUNNER_MANUALLY_TRAP_SIG=1 \
      /bin/bash -c 'cd "$1" || exit 1; exec ./run.sh --jitconfig "$2"' _ "$root/runner" "$jit" &
  CHILD_PID=$!
  jit=""
  wait "$CHILD_PID" || rc=$?
  CHILD_PID=""
  elapsed=$(( $(date +%s) - started ))
  log "job end: account=$acct uid=$uid exit=$rc after ${elapsed}s"
  return "$rc"
}

# ----------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------
[[ $(id -u) -eq 0 ]] || fatal "must run as root (launchd does; by hand: sudo bash $0 --once)"
for t in "$GH" "$JQ" "$DSCL" "$SYSADMINCTL" "$DSEDITGROUP" "$LAUNCHCTL" "$PKILL" "$PGREP" "$SUDO" "$CRONTAB"; do
  [[ -x $t ]] || fatal "missing tool: $t"
done
[[ -d $PRISTINE && -x $PRISTINE/run.sh ]] || fatal "no pristine runner install at $PRISTINE — run setup-actions-runner.sh"
[[ -f $PAT_FILE ]] || fatal "no PAT file at $PAT_FILE — run setup-actions-runner.sh"
[[ $(stat -f '%Lp %u' "$PAT_FILE") == "600 0" ]] || fatal "$PAT_FILE is not 600 root ($(stat -f '%Lp %u' "$PAT_FILE"))"
[[ -f $UID_COUNTER ]] || fatal "no UID counter at $UID_COUNTER — run setup-actions-runner.sh"
JOB_GID=$($DSCL . -read "/Groups/$JOB_GROUP" PrimaryGroupID 2>/dev/null | awk '{print $2}') \
  || fatal "group $JOB_GROUP does not exist — run setup-actions-runner.sh"
[[ $JOB_GID =~ ^[0-9]+$ ]] || fatal "group $JOB_GROUP has no usable PrimaryGroupID — run setup-actions-runner.sh"
install -d -o root -g wheel -m 755 "$JOBS_ROOT"

# One supervisor at a time (launchd guarantees it; --once by hand must not collide).
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [[ -f $LOCK_DIR/pid ]] && kill -0 "$(cat "$LOCK_DIR/pid" 2>/dev/null)" 2>/dev/null; then
    fatal "another supervisor is running (pid $(cat "$LOCK_DIR/pid")) — bootout the daemon first: sudo launchctl bootout system/com.user.actions-runner-jit"
  fi
  log "stale lock $LOCK_DIR (no live pid) — taking it"
  rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR" || fatal "cannot take the lock $LOCK_DIR"
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"

trap on_exit EXIT
trap 'log "SIGTERM received"; exit 143' TERM
trap 'log "SIGINT received";  exit 130' INT
trap 'log "SIGHUP received";  exit 129' HUP

PIN=$(awk '{print $1; exit}' "$PRISTINE/.jit-pin" 2>/dev/null || true); PIN=${PIN:-unknown}
log "supervisor start: pid=$$ repo=$REPO runner=$RUNNER_NAME pristine=$PRISTINE (runner $PIN) uid_range=$UID_MIN-$UID_MAX once=$ONCE"
sweep_leftovers
if [[ $SWEEP_ONLY == 1 ]]; then log "--sweep-only: done"; exit 0; fi

# ----------------------------------------------------------------------------
# The loop
# ----------------------------------------------------------------------------
fails=0
while :; do
  uid=$(next_uid)
  CUR_UID=$uid; CUR_ACCT="$JOB_PREFIX$uid"; CUR_ROOT="$JOBS_ROOT/$uid"; CUR_RUNNER_ID=""
  ok=1
  create_account "$uid" || ok=0
  [[ $ok == 1 ]] && { clone_runner "$uid" || ok=0; }
  [[ $ok == 1 ]] && { mint_jit "$uid"   || ok=0; }
  if [[ $ok == 1 ]]; then
    rc=0; run_job "$uid" || rc=$?
    [[ $rc -eq 0 ]] && fails=0 || fails=$((fails + 1))
  else
    fails=$((fails + 1))
  fi

  teardown "$CUR_UID" "$CUR_ACCT" "$CUR_ROOT" || warn "teardown left work behind for uid $CUR_UID — inspect before the next job"
  [[ -n $CUR_RUNNER_ID ]] && delete_registration "$CUR_RUNNER_ID"
  CUR_UID=""; CUR_ACCT=""; CUR_ROOT=""; CUR_RUNNER_ID=""

  if [[ $ONCE == 1 ]]; then log "--once: one cycle done"; exit 0; fi
  if (( fails > 0 )); then
    back=$(( BACKOFF_BASE * (1 << (fails > 4 ? 4 : fails - 1)) ))
    (( back > BACKOFF_MAX )) && back=$BACKOFF_MAX
    log "cycle failed ($fails consecutive) — backing off ${back}s"
    sleep "$back"
  else
    sleep "$IDLE_SLEEP"
  fi
done
