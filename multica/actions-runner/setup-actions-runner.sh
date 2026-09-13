#!/bin/bash
# setup-actions-runner.sh — spec 60 §The runner: install the ephemeral just-in-time
# GitHub Actions runner on the M4 mini — a root supervisor that creates and destroys a
# throwaway macOS account per job. Replaces the persistent `m4-mini` registration that
# runs CI as `orchestrator` (spec 60 §The boundary, FIND-002, FIND-009).
#
#   Everett runs, once, as admin:   sudo bash ~/agents/multica/actions-runner/setup-actions-runner.sh
#   Re-runnable: every step checks its own state first and says what it did.
#   Companion: RUNBOOK.md next to this file (the ordered list, operate, rollback).
#
# What it installs (nothing lives in a user home):
#   /opt/actions-runner/                      pristine runner release, root:wheel, 755/644
#                                             + .path (Homebrew first, as today) and .env
#                                             + .jit-pin (the version+sha256 this script wrote)
#   /opt/actions-runner-jit/actions-runner-jit.sh   the supervisor loop (root, 755)
#   /etc/actions-runner-jit/                  root:wheel 700
#       jit_pat                               fine-grained PAT, Administration: write on ezybg7/pantry (600)
#       uid_counter                           monotonic UID counter, starts at 5000 (600)
#   /private/var/actions-runner-jobs/         root:wheel 755 — the per-job roots the supervisor makes
#   /var/log/actions-runner-jit/              root:wheel 750 — the daemon's stdout/stderr
#   /Library/LaunchDaemons/com.user.actions-runner-jit.plist   root, KeepAlive, root-owned logs
#   group `actions-jobs` (gid 5000)           the job accounts' primary group — never `staff`
#
# The PAT is typed into a hidden prompt and written straight to its 600 root-only file:
# never in argv, never echoed, never in this script's output.
#
# Flags:
#   --dry-run            print every step and every file it would write; runs as a normal
#                        user, changes nothing, touches no token
#   --remove-persistent  STEP (e), run as orchestrator WITHOUT sudo, only after the
#                        supervisor is proven: stop, uninstall and unregister the old
#                        persistent `m4-mini` runner in ~/actions-runner
#   --rotate-pat         re-prompt for the JIT PAT even though one is stored
#   --skip-daemon        do everything except install/bootstrap the LaunchDaemon
set -euo pipefail

# Where the payload (the supervisor and the plist) lives — resolved before any cd,
# so a relative invocation (`bash setup-actions-runner.sh`) still finds it.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
# Pinned release. Provenance (2026-09-12):
#   https://api.github.com/repos/actions/runner/releases/latest -> tag v2.337.0, published 2026-08-26
#   sha256 from that release's body, marker <!-- BEGIN SHA osx-arm64 -->
# To bump: re-read both, change these three constants, re-run this script (see RUNBOOK Operate).
RUNNER_VERSION=2.337.0
RUNNER_ASSET=actions-runner-osx-arm64-2.337.0.tar.gz
RUNNER_SHA256=5a2cd92908a93d7276a194e1de6008099f3e7946f3f8e14aa7a1a7b4a31fdec2
RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$RUNNER_ASSET"

REPO=ezybg7/pantry
RUNNER_NAME=m4-mini
LABEL=com.user.actions-runner-jit
PLIST=/Library/LaunchDaemons/$LABEL.plist

PRISTINE=/opt/actions-runner
SUPERVISOR_DIR=/opt/actions-runner-jit
SUPERVISOR=$SUPERVISOR_DIR/actions-runner-jit.sh
CONF_DIR=/etc/actions-runner-jit
PAT_FILE=$CONF_DIR/jit_pat
UID_COUNTER=$CONF_DIR/uid_counter
JOBS_ROOT=/private/var/actions-runner-jobs
LOG_DIR=/var/log/actions-runner-jit

JOB_GROUP=actions-jobs
JOB_GID=5000            # free on this machine (dscl . -list /Groups PrimaryGroupID, 2026-09-12)
UID_START=5000          # see RUNBOOK "Why UID 5000+"

BREW=/opt/homebrew
GH=$BREW/bin/gh
JQ=$BREW/bin/jq
# Byte-identical to the persistent runner's .path (~orchestrator/actions-runner/.path):
# Homebrew first, as CI expects today.
RUNNER_PATH_LINE='/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
# The old install, for --remove-persistent only.
OLD_RUNNER_DIR=/Users/orchestrator/actions-runner
OLD_SVC_NAME=actions.runner.ezybg7-pantry.m4-mini

DRY_RUN=0; REMOVE_PERSISTENT=0; ROTATE_PAT=0; SKIP_DAEMON=0
# Run from / so nothing inherits a cwd a job account could have replaced. $0 is unusable
# after this — everything uses $SELF_DIR, resolved above.
cd / || exit 1
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)           DRY_RUN=1 ;;
    --remove-persistent) REMOVE_PERSISTENT=1 ;;
    --rotate-pat)        ROTATE_PAT=1 ;;
    --skip-daemon)       SKIP_DAEMON=1 ;;
    -h|--help)           sed -n '2,34p' "$SELF_DIR/$(basename "$0")"; exit 0 ;;
    *) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a mutating command — or, under --dry-run, print it and do nothing.
x() {
  if [[ $DRY_RUN == 1 ]]; then printf '    + %s\n' "$(printf '%q ' "$@")"; return 0; fi
  "$@"
}
# Write a file from stdin: wf <dest> <mode> <owner:group>. Under --dry-run, print it.
wf() {
  local dest=$1 mode=$2 own=$3 tmp
  if [[ $DRY_RUN == 1 ]]; then
    printf '    + would write %s (mode %s, owner %s):\n' "$dest" "$mode" "$own"
    sed 's/^/          | /'
    return 0
  fi
  [[ ! -L $dest ]] || die "$dest is a symlink — refusing to write through it"
  tmp=$(mktemp /var/tmp/jit-setup.XXXXXX)
  cat > "$tmp"
  install -o "${own%%:*}" -g "${own##*:}" -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  note "wrote $dest ($mode ${own})"
}

# ============================================================================
# STEP (e) — remove the persistent runner. Runs as orchestrator, NOT as root:
# svc.sh refuses to run under sudo, and the LaunchAgent lives in orchestrator's
# own launchd domain. Run this only after the supervisor is proven.
# ============================================================================
if [[ $REMOVE_PERSISTENT == 1 ]]; then
  say "--remove-persistent — retire the persistent $RUNNER_NAME registration"
  [[ $(id -u) -ne 0 ]] || die "run this WITHOUT sudo, as the user that owns $OLD_RUNNER_DIR (svc.sh refuses to run as root): bash $0 --remove-persistent"
  [[ -d $OLD_RUNNER_DIR ]] || die "$OLD_RUNNER_DIR does not exist — nothing to remove"
  [[ $(stat -f %Su "$OLD_RUNNER_DIR") == "$(id -un)" ]] || die "$OLD_RUNNER_DIR is owned by $(stat -f %Su "$OLD_RUNNER_DIR"), not $(id -un) — run this as that user"
  have "$GH" || die "missing $GH"

  note "runners registered now:"
  "$GH" api "repos/$REPO/actions/runners" \
    --jq '.runners[] | "      id=\(.id) name=\(.name) status=\(.status) ephemeral=\(.ephemeral) busy=\(.busy)"' || die "cannot read the runners API"

  if [[ -f $HOME/Library/LaunchAgents/$OLD_SVC_NAME.plist ]]; then
    say "1/4 ./svc.sh stop"
    ( cd "$OLD_RUNNER_DIR" && ./svc.sh stop ) || note "svc.sh stop reported a problem — continuing to uninstall"
    say "2/4 ./svc.sh uninstall (removes ~/Library/LaunchAgents/$OLD_SVC_NAME.plist)"
    ( cd "$OLD_RUNNER_DIR" && ./svc.sh uninstall ) || die "svc.sh uninstall failed — fix it before unregistering"
  else
    note "1-2/4 no LaunchAgent at ~/Library/LaunchAgents/$OLD_SVC_NAME.plist — already uninstalled"
  fi

  say "3/4 removal token (single use, ~1 hour, never printed)"
  RM_TOKEN=$("$GH" api -X POST "repos/$REPO/actions/runners/remove-token" --jq .token) \
    || die "could not mint a removal token (needs admin on $REPO)"
  [[ -n $RM_TOKEN ]] || die "empty removal token"
  note "minted (${#RM_TOKEN} chars, not shown)"

  say "4/4 ./config.sh remove — deletes .runner and .credentials and deregisters server-side"
  if ( cd "$OLD_RUNNER_DIR" && ./config.sh remove --token "$RM_TOKEN" ); then
    RM_TOKEN=""
    note "config.sh remove succeeded"
  else
    RM_TOKEN=""
    note "config.sh remove failed. Fallback, server-side only (leaves the local .credentials — delete the directory afterwards):"
    note "  gh api -X DELETE repos/$REPO/actions/runners/<id>"
    die "config.sh remove failed"
  fi

  say "verify"
  left=$("$GH" api "repos/$REPO/actions/runners" --jq '[.runners[] | select(.ephemeral != true)] | length' || echo '?')
  if [[ $left == 0 ]]; then printf '    PASS  no non-ephemeral runner is registered on %s\n' "$REPO"
  else printf '    FAIL  %s non-ephemeral runner(s) still registered — list them with: gh api repos/%s/actions/runners\n' "$left" "$REPO"; fi
  for f in .credentials .credentials_rsaparams .runner; do
    if [[ -e $OLD_RUNNER_DIR/$f ]]; then printf '    FAIL  %s still exists\n' "$OLD_RUNNER_DIR/$f"
    else printf '    PASS  %s is gone\n' "$OLD_RUNNER_DIR/$f"; fi
  done
  cat <<EOF

    The old install is now credential-free. When you are happy, delete it:
      rm -rf $OLD_RUNNER_DIR
    CI from here on runs only under the supervisor (/opt/actions-runner).
EOF
  exit 0
fi

# ============================================================================
# PREFLIGHT
# ============================================================================
if [[ $DRY_RUN == 1 ]]; then
  say "DRY RUN — running as $(id -un) (uid $(id -u)); nothing below is executed, no token is touched"
else
  [[ $(id -u) -eq 0 ]] || die "run as admin: sudo bash $0   (or --dry-run to see every step as a normal user)"
  ( : < /dev/tty ) 2>/dev/null || die "needs an interactive terminal (the PAT prompt)"
fi

say "preflight"
[[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || die "this script is for macOS on arm64 (osx-arm64 runner asset)"
for t in "$GH" "$JQ" /usr/bin/curl /usr/bin/shasum /usr/bin/tar /usr/sbin/sysadminctl /usr/bin/dscl /usr/sbin/dseditgroup /usr/bin/plutil /bin/launchctl /usr/bin/sudo; do
  [[ -x $t ]] || die "missing tool: $t"
done
note "tools: gh $("$GH" --version | awk 'NR==1{print $3}'), jq $("$JQ" --version), $(sw_vers -productName) $(sw_vers -productVersion) $(uname -m)"
[[ -f $SELF_DIR/actions-runner-jit.sh ]] || die "actions-runner-jit.sh is not next to this script ($SELF_DIR)"
[[ -f $SELF_DIR/$LABEL.plist ]]          || die "$LABEL.plist is not next to this script ($SELF_DIR)"
bash -n "$SELF_DIR/actions-runner-jit.sh" || die "actions-runner-jit.sh does not parse"
/usr/bin/plutil -lint "$SELF_DIR/$LABEL.plist" >/dev/null || die "$LABEL.plist does not lint"
note "payload: actions-runner-jit.sh parses, $LABEL.plist lints"
avail=$(df -g /opt | awk 'NR==2{print $4}')
[[ ${avail:-0} -ge 5 ]] || die "only ${avail}GB free on /opt — the runner release needs ~1GB per concurrent job clone"
note "free space on /opt: ${avail}GB"
if [[ $DRY_RUN != 1 ]]; then
  note "old persistent runner: $(if [[ -f /Users/orchestrator/Library/LaunchAgents/$OLD_SVC_NAME.plist ]]; then echo "still installed (step (e) retires it — after the proof)"; else echo "no LaunchAgent found"; fi)"
fi

# ============================================================================
# 1. the group the job accounts belong to (never `staff`)
# ============================================================================
say "1. group $JOB_GROUP (gid $JOB_GID)"
if /usr/bin/dscl . -read "/Groups/$JOB_GROUP" >/dev/null 2>&1; then
  note "present: gid $(/usr/bin/dscl . -read "/Groups/$JOB_GROUP" PrimaryGroupID | awk '{print $2}') — skipping"
else
  if [[ $DRY_RUN != 1 ]] && [[ -n $(/usr/bin/dscl . -search /Groups PrimaryGroupID "$JOB_GID" 2>/dev/null) ]]; then
    die "gid $JOB_GID is already taken by $(/usr/bin/dscl . -search /Groups PrimaryGroupID "$JOB_GID" | awk 'NR==1{print $1}') — pick another JOB_GID"
  fi
  x /usr/sbin/dseditgroup -o create -n . -i "$JOB_GID" -r "GitHub Actions job accounts (spec 60)" "$JOB_GROUP"
  note "created $JOB_GROUP with gid $JOB_GID — no members: it is only a primary group"
fi

# ============================================================================
# 2. root-owned directories
# ============================================================================
say "2. directories"
x install -d -o root -g wheel -m 700 "$CONF_DIR"
x install -d -o root -g wheel -m 755 "$JOBS_ROOT"
x install -d -o root -g wheel -m 750 "$LOG_DIR"
x install -d -o root -g wheel -m 755 "$SUPERVISOR_DIR"
note "$CONF_DIR 700 · $JOBS_ROOT 755 · $LOG_DIR 750 · $SUPERVISOR_DIR 755 — all root:wheel, none in a user home"

# ============================================================================
# 3. the pristine runner install (pinned, sha256-verified, root-owned)
# ============================================================================
say "3. pristine runner $RUNNER_VERSION at $PRISTINE"
note "asset  $RUNNER_ASSET"
note "sha256 $RUNNER_SHA256"
pinned=""
[[ -f $PRISTINE/.jit-pin ]] && pinned=$(awk '{print $1}' "$PRISTINE/.jit-pin" 2>/dev/null || true)
if [[ $pinned == "$RUNNER_VERSION" && -x $PRISTINE/run.sh ]]; then
  note "already installed and pinned to $RUNNER_VERSION — skipping the download"
  x chown -R root:wheel "$PRISTINE"
  x chmod -R u=rwX,go=rX "$PRISTINE"
elif [[ $DRY_RUN == 1 ]]; then
  note "+ would create a root-only staging dir under /var/tmp"
  note "+ would curl -fsSL -o <stage>/$RUNNER_ASSET $RUNNER_URL"
  note "+ would verify sha256 against $RUNNER_SHA256 and ABORT on any mismatch"
  note "+ would tar -xzf <stage>/$RUNNER_ASSET into <stage>/x (the tarball has no top-level dir)"
  note "+ would move <stage>/x to $PRISTINE (previous install kept as $PRISTINE.old until the move succeeds)"
  note "+ would chown -R root:wheel $PRISTINE && chmod -R u=rwX,go=rX $PRISTINE   (755 dirs / 644 files, world-readable, root-writable only)"
  note "+ would check $PRISTINE/bin/Runner.Listener --version == $RUNNER_VERSION"
else
  [[ -n $pinned ]] && note "installed pin is '$pinned', wanted $RUNNER_VERSION — replacing"
  STAGE=$(mktemp -d /var/tmp/actions-runner-setup.XXXXXX)
  chmod 700 "$STAGE"
  trap 'rm -rf "$STAGE"' EXIT
  note "downloading $RUNNER_URL"
  /usr/bin/curl -fsSL --max-time 900 -o "$STAGE/$RUNNER_ASSET" "$RUNNER_URL" || die "download failed"
  got=$(/usr/bin/shasum -a 256 "$STAGE/$RUNNER_ASSET" | awk '{print $1}')
  if [[ $got != "$RUNNER_SHA256" ]]; then
    die "sha256 MISMATCH for $RUNNER_ASSET
       expected $RUNNER_SHA256
       got      $got
     Nothing was installed. Either the pin is stale (re-read the release and update the
     constants at the top of this script) or the download was tampered with."
  fi
  note "sha256 verified: $got"
  mkdir -p "$STAGE/x"
  /usr/bin/tar -xzf "$STAGE/$RUNNER_ASSET" -C "$STAGE/x" || die "tar failed"
  [[ -x $STAGE/x/run.sh && -x $STAGE/x/config.sh ]] || die "the tarball did not contain run.sh/config.sh"
  rm -rf "$PRISTINE.old"
  [[ -d $PRISTINE ]] && mv "$PRISTINE" "$PRISTINE.old"
  mv "$STAGE/x" "$PRISTINE" || die "could not move the extracted runner to $PRISTINE"
  chown -R root:wheel "$PRISTINE"
  chmod -R u=rwX,go=rX "$PRISTINE"
  rm -rf "$PRISTINE.old" "$STAGE"
  trap - EXIT
  got=$("$PRISTINE/bin/Runner.Listener" --version 2>/dev/null | tr -d '\r')
  [[ $got == "$RUNNER_VERSION" ]] || die "installed runner reports '$got', expected $RUNNER_VERSION"
  note "installed and verified: Runner.Listener $got, root:wheel, 755/644"
fi
wf "$PRISTINE/.jit-pin" 644 root:wheel <<EOF
$RUNNER_VERSION $RUNNER_SHA256
EOF

# ============================================================================
# 4. .path and .env — the two files the runner reads from its own root
# ============================================================================
say "4. $PRISTINE/.path and $PRISTINE/.env"
note ".path is byte-identical to the persistent runner's: Homebrew first, so CI behaves as today"
wf "$PRISTINE/.path" 644 root:wheel <<EOF
$RUNNER_PATH_LINE
EOF
# KEY=VALUE only — the runner parses every line; a comment would become a bogus variable.
# TMPDIR is NOT here: the supervisor appends the per-job TMPDIR to each job's own copy.
wf "$PRISTINE/.env" 644 root:wheel <<'EOF'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
HOMEBREW_PREFIX=/opt/homebrew
EOF
note "TMPDIR is appended per job (inside the per-job root) by the supervisor, never pinned here"

# ============================================================================
# 5. the UID counter (root-only, monotonic)
# ============================================================================
say "5. UID counter $UID_COUNTER"
if [[ $DRY_RUN == 1 ]]; then
  note "+ would write $UID_COUNTER = $UID_START (600 root:wheel) if absent; an existing counter is never lowered"
elif [[ -s $UID_COUNTER ]]; then
  cur=$(tr -d '[:space:]' < "$UID_COUNTER")
  [[ $cur =~ ^[0-9]+$ ]] || die "$UID_COUNTER does not hold a number — inspect it by hand"
  if (( cur < UID_START )); then
    printf '%s\n' "$UID_START" > "$UID_COUNTER"; chmod 600 "$UID_COUNTER"; chown root:wheel "$UID_COUNTER"
    note "counter was $cur, below the floor — raised to $UID_START (a UID is never reused)"
  else
    note "present: next UID is $cur — left alone (monotonic)"
  fi
else
  ( umask 077; printf '%s\n' "$UID_START" > "$UID_COUNTER" )
  chown root:wheel "$UID_COUNTER"; chmod 600 "$UID_COUNTER"
  note "created: next UID is $UID_START"
fi

# ============================================================================
# 6. the JIT PAT (hidden prompt -> 600 root-only file; never argv, never echoed)
# ============================================================================
say "6. JIT PAT at $PAT_FILE"
if [[ $DRY_RUN == 1 ]]; then
  note "+ would prompt (hidden input, from /dev/tty) for the fine-grained PAT:"
  note "    GitHub -> Settings -> Developer settings -> Fine-grained tokens"
  note "    repository $REPO only, Repository permissions: Administration = Read and write, nothing else"
  note "+ would write it to $PAT_FILE (600 root:wheel) with umask 077, never echoing it"
  note "+ would verify it with: GH_TOKEN=<pat> gh api repos/$REPO/actions/runners --jq .total_count"
  note "  (a read of the runners API needs the Administration scope; it creates nothing —"
  note "   this script never mints a JIT config, which would leave an offline registration behind)"
elif [[ -s $PAT_FILE && $ROTATE_PAT != 1 ]]; then
  note "already stored — use --rotate-pat to replace it"
else
  [[ ! -L $PAT_FILE ]] || die "$PAT_FILE is a symlink — refusing"
  printf '    Paste the fine-grained PAT (Administration: write on %s).\n' "$REPO"
  while :; do
    IFS= read -rs -p "  PAT (input hidden, then Enter): " val < /dev/tty || die "no input"
    printf '\n' > /dev/tty
    val=${val//[[:space:]]/}
    [[ -n $val ]] || { note "empty — try again"; continue; }
    [[ $val == github_pat_* ]] || note "warning: expected it to start with 'github_pat_' (a fine-grained token) — storing anyway"
    break
  done
  ( umask 077; printf '%s\n' "$val" > "$PAT_FILE" )
  chown root:wheel "$PAT_FILE"; chmod 600 "$PAT_FILE"
  val=""
  note "stored at $PAT_FILE (600 root:wheel)"
fi
if [[ $DRY_RUN != 1 ]]; then
  pat=$(cat "$PAT_FILE")
  if out=$(GH_TOKEN="$pat" "$GH" api "repos/$REPO/actions/runners" --jq '.total_count' 2>&1); then
    note "PAT verified: it can read $REPO's runners API (total_count=$out) — the Administration scope is present"
  else
    pat=""
    die "the stored PAT cannot read repos/$REPO/actions/runners: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)
     Check: fine-grained, resource owner ezybg7, repository $REPO, Administration = Read and write, not expired.
     Re-run with --rotate-pat to replace it."
  fi
  exp=$(GH_TOKEN="$pat" "$GH" api "repos/$REPO" -i 2>/dev/null | awk -F': ' 'tolower($1)=="github-authentication-token-expiration"{print $2}' | tr -d '\r') || true
  [[ -n ${exp:-} ]] && note "PAT expires: $exp"
  pat=""
fi

# ============================================================================
# 7. the supervisor
# ============================================================================
say "7. supervisor $SUPERVISOR"
x install -o root -g wheel -m 755 "$SELF_DIR/actions-runner-jit.sh" "$SUPERVISOR"
note "installed from $SELF_DIR/actions-runner-jit.sh (root:wheel 755 — a job account can neither write nor read-modify it)"
if [[ $DRY_RUN != 1 ]]; then
  bash -n "$SUPERVISOR" || die "the installed supervisor does not parse"
  note "bash -n on the installed copy: OK"
fi

# ============================================================================
# 8. the LaunchDaemon
# ============================================================================
if [[ $SKIP_DAEMON == 1 ]]; then
  say "8. LaunchDaemon skipped (--skip-daemon)"
else
  say "8. LaunchDaemon $LABEL"
  for needle in "$SUPERVISOR" "$LOG_DIR/supervisor.log" "$LABEL"; do
    grep -q -- "$needle" "$SELF_DIR/$LABEL.plist" || die "$SELF_DIR/$LABEL.plist does not mention $needle — the plist and this script have drifted"
  done
  note "plist cross-check: Label, supervisor path and log paths agree with this script's constants"
  note "runs as root (no UserName key): only root can create and destroy accounts and kill by UID"
  if [[ $DRY_RUN == 1 ]]; then
    note "+ would install $SELF_DIR/$LABEL.plist to $PLIST (644 root:wheel):"
    sed 's/^/          | /' "$SELF_DIR/$LABEL.plist"
    note "+ would launchctl enable system/$LABEL && launchctl bootstrap system $PLIST"
    note "+ (if already loaded with an identical plist: leave it running; if it differs: bootout, install, bootstrap)"
  else
    loaded=0; /bin/launchctl print "system/$LABEL" >/dev/null 2>&1 && loaded=1
    if [[ $loaded == 1 ]] && cmp -s "$SELF_DIR/$LABEL.plist" "$PLIST"; then
      note "already loaded with an identical plist — restarting it so it picks up this run's supervisor and pin"
      /bin/launchctl kickstart -k "system/$LABEL" || die "launchctl kickstart -k system/$LABEL failed"
    else
      if [[ $loaded == 1 ]]; then
        note "a different plist is loaded — booting it out first (any job in flight is torn down by the supervisor's SIGTERM trap)"
        /bin/launchctl bootout "system/$LABEL" || true
        sleep 3
      fi
      install -o root -g wheel -m 644 "$SELF_DIR/$LABEL.plist" "$PLIST"
      /bin/launchctl enable "system/$LABEL" 2>/dev/null || true
      for attempt in 1 2 3; do
        if /bin/launchctl bootstrap system "$PLIST"; then break; fi
        [[ $attempt == 3 ]] && die "launchctl bootstrap system $PLIST failed three times — see: sudo launchctl print system/$LABEL"
        sleep 3
      done
      note "installed $PLIST and bootstrapped it into the system domain"
    fi
    printf '    waiting for the first JIT registration'
    for _ in $(seq 1 30); do
      n=$(GH_TOKEN="$(cat "$PAT_FILE")" "$GH" api "repos/$REPO/actions/runners" \
            --jq "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true and .status==\"online\")] | length" 2>/dev/null || echo 0)
      [[ ${n:-0} -ge 1 ]] && break
      printf '.'; sleep 2
    done
    printf '\n'
    [[ ${n:-0} -ge 1 ]] || note "WARNING: no online ephemeral $RUNNER_NAME yet — the self-check below will say why (logs: sudo tail -50 $LOG_DIR/supervisor.log)"
  fi
fi

# ============================================================================
# 9. self-check
# ============================================================================
if [[ $DRY_RUN == 1 ]]; then
  say "9. self-check (skipped in --dry-run; it would check:)"
  cat <<EOF
          | group $JOB_GROUP exists with gid $JOB_GID
          | $PRISTINE: root:wheel, 755, Runner.Listener == $RUNNER_VERSION, .jit-pin matches, .path/.env as written
          | $PRISTINE is not writable by a non-root account (probed as the invoking user)
          | $CONF_DIR is 700 root:wheel; $PAT_FILE and $UID_COUNTER are 600 root:wheel
          | $UID_COUNTER holds a number >= $UID_START
          | $SUPERVISOR is 755 root:wheel and parses
          | $PLIST is 644 root:wheel, lints, and system/$LABEL state = running
          | $LOG_DIR exists, 750 root:wheel, and the supervisor has logged a start line
          | exactly one $RUNNER_NAME runner is registered: ephemeral true, online
          | no runner with ephemeral != true is registered (step (e) may still be pending)
          | no job-* account exists between jobs, and $JOBS_ROOT is empty
EOF
  say "DRY RUN complete — no file was written, no account touched, no token read"
  note "next: sudo bash $SELF_DIR/$(basename "$0")"
  exit 0
fi

say "9. self-check"
FAILS=()
pass() { printf '    PASS  %s\n' "$*"; }
fail() { printf '    FAIL  %s\n' "$*"; FAILS+=("$*"); }
own_mode() { stat -f '%Lp %Su:%Sg' "$1" 2>/dev/null; }
expect_mode() {  # <path> <mode> <owner:group>
  local got; got=$(own_mode "$1")
  if [[ $got == "$2 $3" ]]; then pass "$1 is $2 $3"; else fail "$1 is '${got:-missing}', expected '$2 $3'"; fi
}

gid=$(/usr/bin/dscl . -read "/Groups/$JOB_GROUP" PrimaryGroupID 2>/dev/null | awk '{print $2}')
if [[ $gid == "$JOB_GID" ]]; then pass "group $JOB_GROUP has gid $gid"; else fail "group $JOB_GROUP gid is '${gid:-missing}', expected $JOB_GID"; fi

expect_mode "$PRISTINE" 755 root:wheel
expect_mode "$PRISTINE/.path" 644 root:wheel
expect_mode "$PRISTINE/.env" 644 root:wheel
expect_mode "$CONF_DIR" 700 root:wheel
expect_mode "$PAT_FILE" 600 root:wheel
expect_mode "$UID_COUNTER" 600 root:wheel
expect_mode "$SUPERVISOR" 755 root:wheel
expect_mode "$JOBS_ROOT" 755 root:wheel
expect_mode "$LOG_DIR" 750 root:wheel
[[ $SKIP_DAEMON == 1 ]] || expect_mode "$PLIST" 644 root:wheel

v=$("$PRISTINE/bin/Runner.Listener" --version 2>/dev/null | tr -d '\r')
if [[ $v == "$RUNNER_VERSION" ]]; then pass "Runner.Listener reports $v (the pin)"; else fail "Runner.Listener reports '${v:-nothing}', expected $RUNNER_VERSION"; fi
if [[ $(cat "$PRISTINE/.jit-pin") == "$RUNNER_VERSION $RUNNER_SHA256" ]]; then pass ".jit-pin records $RUNNER_VERSION and its sha256"; else fail ".jit-pin does not match the constants in this script"; fi
if [[ $(cat "$PRISTINE/.path") == "$RUNNER_PATH_LINE" ]]; then pass ".path is Homebrew-first, as the persistent runner was"; else fail ".path is not the expected line"; fi
if grep -q '^HOMEBREW_PREFIX=/opt/homebrew$' "$PRISTINE/.env"; then pass ".env carries LANG/LC_ALL/HOMEBREW_PREFIX"; else fail ".env is missing HOMEBREW_PREFIX"; fi

# A non-root account must not be able to write into the install. Probed as the user who
# invoked sudo — the same class of principal a job account is (non-admin is stricter still).
prober=${SUDO_USER:-nobody}
if sudo -n -u "$prober" test -w "$PRISTINE" 2>/dev/null; then fail "$PRISTINE is writable by $prober — it must be root-only"; else pass "$PRISTINE is not writable by $prober (probe: test -w as that user)"; fi
if sudo -n -u "$prober" cat "$PAT_FILE" >/dev/null 2>&1; then fail "$PAT_FILE is READABLE by $prober — it must be root-only"; else pass "$PAT_FILE is not readable by $prober"; fi
if sudo -n -u "$prober" cat "$UID_COUNTER" >/dev/null 2>&1; then fail "$UID_COUNTER is READABLE by $prober"; else pass "$UID_COUNTER is not readable by $prober"; fi

c=$(tr -d '[:space:]' < "$UID_COUNTER")
if [[ $c =~ ^[0-9]+$ ]] && (( c >= UID_START )); then pass "UID counter holds $c (next UID; floor $UID_START)"; else fail "UID counter holds '$c'"; fi

if bash -n "$SUPERVISOR" 2>/dev/null; then pass "the installed supervisor parses"; else fail "the installed supervisor does not parse"; fi

if [[ $SKIP_DAEMON != 1 ]]; then
  if /usr/bin/plutil -lint "$PLIST" >/dev/null 2>&1; then pass "$PLIST lints"; else fail "$PLIST does not lint"; fi
  st=$(/bin/launchctl print "system/$LABEL" 2>/dev/null | awk -F'= ' '/^[[:space:]]*state = /{print $2}' | sed -n 1p || true)
  if [[ $st == running ]]; then pass "launchd: system/$LABEL state = running"
  else fail "launchd: system/$LABEL state is '${st:-not loaded}' ($(/bin/launchctl print "system/$LABEL" 2>&1 | grep -E 'state|last exit' | tr -s ' ' | tr '\n' ';' | cut -c1-160 || true))"; fi
  if [[ -s $LOG_DIR/supervisor.log ]] && grep -q 'supervisor start' "$LOG_DIR/supervisor.log"; then
    pass "supervisor log has a start line ($(grep -c 'supervisor start' "$LOG_DIR/supervisor.log" || true) so far)"
  else fail "no 'supervisor start' line in $LOG_DIR/supervisor.log"; fi
  if grep -qiE 'FATAL' "$LOG_DIR/supervisor.err.log" 2>/dev/null; then
    fail "FATAL in $LOG_DIR/supervisor.err.log: $(grep -i FATAL "$LOG_DIR/supervisor.err.log" | tail -1 | cut -c1-140 || true)"
  else pass "no FATAL line in $LOG_DIR/supervisor.err.log"; fi
fi

# The registration state spec 60 §Acceptance asks for.
runners=$(GH_TOKEN="$(cat "$PAT_FILE")" "$GH" api "repos/$REPO/actions/runners" 2>/dev/null) || runners=""
if [[ -n $runners ]]; then
  jqr() { printf '%s' "$runners" | "$JQ" "$@" 2>/dev/null || echo '?'; }
  eph=$(jqr    "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true)] | length")
  online=$(jqr "[.runners[] | select(.name==\"$RUNNER_NAME\" and .ephemeral==true and .status==\"online\")] | length")
  pers=$(jqr   '[.runners[] | select(.ephemeral != true)] | length')
  if [[ $eph == 1 && $online == 1 ]]; then pass "exactly one $RUNNER_NAME runner registered, ephemeral true, online"
  else fail "ephemeral $RUNNER_NAME runners: $eph (online $online) — expected exactly 1 online between jobs"; fi
  if [[ $pers == 0 ]]; then pass "no non-ephemeral runner is registered"
  else fail "$pers non-ephemeral runner(s) still registered — run step (e): bash $0 --remove-persistent (as orchestrator, after the proof)"; fi
else
  fail "could not read repos/$REPO/actions/runners with the stored PAT"
fi

# No principal and no per-job root between jobs.
leftover_accts=$(/usr/bin/dscl . -list /Users | grep -cE '^job-[0-9]+$' || true)
if [[ ${leftover_accts:-0} -eq 0 ]]; then pass "no job-* account exists (nothing survived teardown)"
else fail "${leftover_accts} job-* account(s) exist: $(/usr/bin/dscl . -list /Users | grep -E '^job-[0-9]+$' | tr '\n' ' ')"; fi
busy=$(/bin/ls -A "$JOBS_ROOT" 2>/dev/null | wc -l | tr -d ' ')
if [[ $busy == 0 ]]; then pass "$JOBS_ROOT is empty (no per-job root between jobs)"
else note "NOTE  $JOBS_ROOT holds: $(/bin/ls -A "$JOBS_ROOT" | tr '\n' ' ') — expected only while a job is running"; fi

if [[ ${#FAILS[@]} -gt 0 ]]; then
  printf '\nSELF-CHECK FAILED (%d):\n' "${#FAILS[@]}"
  printf '  - %s\n' "${FAILS[@]}"
  printf '\nStop here. Fix the reason above and re-run this script (every step is idempotent).\n'
  printf 'Logs: sudo tail -50 %s/supervisor.log %s/supervisor.err.log\n' "$LOG_DIR" "$LOG_DIR"
  exit 1
fi

say "done — all checks passed"
cat <<EOF
    Next (RUNBOOK.md steps (c)-(f)):
      (c) bash ~/agents/multica/actions-runner/self-check.sh        # no sudo; the seat-level proofs
      (d) the proof job on a scratch branch (proof-job.yml) — boxes 2 and 3 of spec 60 §Acceptance
      (e) bash ~/agents/multica/actions-runner/setup-actions-runner.sh --remove-persistent   # as orchestrator, NO sudo
      (f) paste the proof onto board card AMBR-21
    Operate:
      sudo launchctl print system/$LABEL | grep -E 'state|pid'
      sudo tail -f $LOG_DIR/supervisor.log
      sudo launchctl kickstart -k system/$LABEL     # restart (a job in flight is torn down)
      sudo launchctl bootout  system/$LABEL         # stop all CI on the mini (jobs queue)
EOF
