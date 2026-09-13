#!/bin/bash
# setup-ci-triage-poller.sh — spec 60 §The shape / §Operating it, Everett's action (4):
# install the CI-triage tick as a root-owned LaunchDaemon that runs as `multica`.
#
#   Everett runs, once, as admin:
#       sudo bash ~/agents/multica/actions-runner/setup-ci-triage-poller.sh <main sha>
#   Re-runnable: every step checks its own state first and says what it did.
#   Companion: RUNBOOK.md step (4) next to this file.
#
# The sha is required and is the point: the three repo files that run must be a `main`
# sha someone typed (spec 60 FIND-004). The script refuses unless
#   /Users/orchestrator/code/pantry is checked out at exactly that sha,
#   the sha is an ancestor of origin/main, and
#   the three files have no uncommitted edits
# so the bytes it installs are provably that commit's bytes. It prints their sha256.
#
# What it installs (nothing runnable lives in a user home):
#   /opt/ci-triage/poll.sh      755 root  <- .github/scripts/ci-triage-poll.sh
#   /opt/ci-triage/queue.sh     755 root  <- .github/scripts/ci-triage-queue.sh
#   /opt/ci-triage/prompt.md    644 root  <- .github/ci-triage-prompt.md
#   /opt/ci-triage/run-poll.sh  755 root  <- generated here: the LaunchDaemon's entry point
#   /Library/LaunchDaemons/com.user.ci-triage-poll.plist   root, UserName multica, StartInterval 300
#   /var/log/ci-triage-poll/poll.log      the wrapper's own stdout/stderr (owner multica, 600)
#   /Users/multica/ci-triage/             the poller's state: ci-triage.log, poll.lock, counters
#
# Credentials: none are read, printed or copied here. The wrapper exports GH_TOKEN from
# /Users/multica/.config/multica-daemon/github_token (600, multica's, written by
# setup-multica-user.sh) at tick time, exactly as multica-daemon-launchd.sh does for the
# daemon. This script only checks that the file is non-empty. The Claude token is
# deliberately NOT loaded: the poller creates Multica issues, it never runs a session.
#
# Flags:  --dry-run      print every step and every file it would write; runs as a normal
#                        user, changes nothing, reads no token
#         --skip-daemon  install the files but do not write/bootstrap the LaunchDaemon
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
CHECKOUT=/Users/orchestrator/code/pantry
REPO=ezybg7/pantry
DEST=/opt/ci-triage
LOG_DIR=/var/log/ci-triage-poll
LOG_FILE=$LOG_DIR/poll.log
LABEL=com.user.ci-triage-poll
PLIST=/Library/LaunchDaemons/$LABEL.plist
INTERVAL=300                     # spec 60 §Operating it: StartInterval 300

MULTICA_USER=multica
MULTICA_GROUP=staff
MULTICA_HOME=/Users/$MULTICA_USER
STATE_DIR=$MULTICA_HOME/ci-triage             # poll.sh/queue.sh: "$HOME/ci-triage"
GH_TOKEN_FILE=$MULTICA_HOME/.config/multica-daemon/github_token
# Same PATH the Multica daemon's wrapper uses, and it must resolve every tool the two
# scripts call: gh, jq, multica (the CLI login lives in $HOME/.multica), shlock, date, awk.
USER_PATH="$MULTICA_HOME/.local/bin:/opt/homebrew/opt/node@22/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# checkout path -> installed name, mode
SRC_POLL=.github/scripts/ci-triage-poll.sh
SRC_QUEUE=.github/scripts/ci-triage-queue.sh
SRC_PROMPT=.github/ci-triage-prompt.md

DRY_RUN=0; SKIP_DAEMON=0; SHA=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)     DRY_RUN=1 ;;
    --skip-daemon) SKIP_DAEMON=1 ;;
    -h|--help)     sed -n '2,38p' "$SELF_DIR/$(basename "$0")"; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *)  [[ -z $SHA ]] || { printf 'give exactly one sha\n' >&2; exit 2; }; SHA=$1 ;;
  esac
  shift
done
# Run from / so nothing inherits a cwd another account could have replaced. $0 is unusable
# after this — everything uses $SELF_DIR, resolved above.
cd / || exit 1

say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
x() {
  if [[ $DRY_RUN == 1 ]]; then printf '    + %s\n' "$(printf '%q ' "$@")"; return 0; fi
  "$@"
}
wf() {  # wf <dest> <mode> <owner:group>  — content on stdin
  local dest=$1 mode=$2 own=$3 tmp
  if [[ $DRY_RUN == 1 ]]; then
    printf '    + would write %s (mode %s, owner %s):\n' "$dest" "$mode" "$own"
    sed 's/^/          | /'
    return 0
  fi
  [[ ! -L $dest ]] || die "$dest is a symlink — refusing to write through it"
  tmp=$(mktemp /var/tmp/ci-triage-setup.XXXXXX)
  cat > "$tmp"
  install -o "${own%%:*}" -g "${own##*:}" -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  note "wrote $dest ($mode $own)"
}
# Every git read runs as the checkout's owner: git refuses to work on a repo owned by
# someone else ("dubious ownership"), and root has no business writing in that repo anyway.
CHECKOUT_OWNER=$(stat -f %Su "$CHECKOUT" 2>/dev/null || echo orchestrator)
git_ro() {
  if [[ $(id -un) == "$CHECKOUT_OWNER" ]]; then git -C "$CHECKOUT" "$@"
  else sudo -n -u "$CHECKOUT_OWNER" git -C "$CHECKOUT" "$@"; fi
}

# A refusal. In a real run it stops the install; under --dry-run it is reported and the
# preview continues, so the steps can be reviewed before the build PR has merged.
GUARD_FAILED=0
guard() {
  if [[ $DRY_RUN == 1 ]]; then printf '\n    ** WOULD REFUSE: %s\n\n' "$1"; GUARD_FAILED=1; return 0; fi
  die "$1"
}

# One command line as multica, in a clean environment — the same shape the daemon gets.
as_multica() {
  sudo -u "$MULTICA_USER" -H env -i HOME="$MULTICA_HOME" USER="$MULTICA_USER" \
    LOGNAME="$MULTICA_USER" SHELL=/bin/bash PATH="$USER_PATH" LANG=en_US.UTF-8 \
    bash -o pipefail -c "cd \"\$HOME\" && { $1; }"
}

# ============================================================================
# PREFLIGHT — the sha guard is the whole point of this script
# ============================================================================
if [[ $DRY_RUN == 1 ]]; then
  say "DRY RUN — running as $(id -un) (uid $(id -u)); nothing below is executed, no token is read"
else
  [[ $(id -u) -eq 0 ]] || die "run as admin: sudo bash $SELF_DIR/$(basename "$0") <main sha>   (or --dry-run)"
fi

say "preflight"
[[ -n $SHA ]] || die "give the merged \`main\` sha to install from:
     sudo bash $SELF_DIR/$(basename "$0") \$(git -C $CHECKOUT rev-parse origin/main)
   The three files that run must be a main sha someone typed (spec 60 §Operating it)."
[[ $SHA =~ ^[0-9a-f]{40}$ ]] || die "'$SHA' is not a 40-character sha — pass the full sha, not a short one or a ref"
[[ -d $CHECKOUT/.git ]] || die "no checkout at $CHECKOUT"

head=$(git_ro rev-parse HEAD 2>/dev/null) || die "cannot read HEAD of $CHECKOUT (as $CHECKOUT_OWNER)"
if [[ $head != "$SHA" ]]; then
  guard "$CHECKOUT is at $head, not $SHA.
     Check it out and re-run:  git -C $CHECKOUT fetch origin && git -C $CHECKOUT switch --detach $SHA
     (or pass the sha it is actually at, if that is the merged main commit you mean)"
else
  note "checkout HEAD == $SHA"
fi
if git_ro merge-base --is-ancestor "$SHA" origin/main 2>/dev/null; then
  note "$SHA is an ancestor of origin/main ($(git_ro rev-parse --short origin/main)) — it is a main sha"
else
  guard "$SHA is not an ancestor of origin/main (or origin/main is stale).
     Run: git -C $CHECKOUT fetch origin main
     and re-run. A non-main sha must never be what runs (spec 60 FIND-004): the poller and
     the guard script are root-owned precisely so only a merged, named commit executes."
fi
HAVE_SRC=1
for f in "$SRC_POLL" "$SRC_QUEUE" "$SRC_PROMPT"; do
  if [[ ! -f $CHECKOUT/$f ]]; then
    HAVE_SRC=0
    guard "$CHECKOUT/$f does not exist at $SHA — is this the sha that merged the build PR (#229)?
     The three files reach main only when that PR merges; install from the merge commit."
    continue
  fi
  git_ro diff --quiet HEAD -- "$f" \
    || guard "$f has uncommitted edits in $CHECKOUT — the installed bytes must be $SHA's bytes.
     Run: git -C $CHECKOUT checkout -- $f"
done
if [[ $HAVE_SRC == 1 ]]; then
  note "the three source files exist at $SHA and are unmodified in the working tree"
  for f in "$SRC_POLL" "$SRC_QUEUE"; do
    bash -n "$CHECKOUT/$f" || guard "$f does not parse"
  done
  [[ -s $CHECKOUT/$SRC_PROMPT ]] || guard "$SRC_PROMPT is empty"
  note "poll.sh and queue.sh parse; prompt.md is non-empty ($(wc -l < "$CHECKOUT/$SRC_PROMPT" | tr -d ' ') lines)"
  for f in "$SRC_POLL" "$SRC_QUEUE" "$SRC_PROMPT"; do
    note "sha256 $(shasum -a 256 "$CHECKOUT/$f" | awk '{print $1}')  $f"
  done
else
  note "(the per-file sha256, bash -n and non-empty checks run once the files exist at the sha)"
fi

if [[ $DRY_RUN != 1 ]]; then
  id -u "$MULTICA_USER" >/dev/null 2>&1 \
    || die "user '$MULTICA_USER' does not exist — run ~/agents/multica/daemon-user/setup-multica-user.sh first (spec 61 phase 2)"
  # Existence and mode only. This script never reads the token.
  [[ -s $GH_TOKEN_FILE ]] \
    || die "$GH_TOKEN_FILE is missing or empty — run setup-multica-user.sh (it prompts for the PAT)"
  m=$(stat -f '%Lp %Su' "$GH_TOKEN_FILE")
  [[ $m == "600 $MULTICA_USER" ]] || die "$GH_TOKEN_FILE is '$m', expected '600 $MULTICA_USER'"
  note "$GH_TOKEN_FILE: present, 600 $MULTICA_USER (content never read)"
  # Every tool the two scripts call must resolve for the multica user on $USER_PATH.
  as_multica 'miss=""; for t in gh jq multica shlock date awk sed; do command -v "$t" >/dev/null || miss="$miss $t"; done
    [ -z "$miss" ] || { echo "not on PATH for multica:$miss"; exit 1; }
    echo "    gh $(gh --version | awk "NR==1{print \$3}") · jq $(jq --version) · multica $(multica version | awk "NR==1{print \$2}") · shlock $(command -v shlock)"' \
    || die "the multica user cannot reach every tool poll.sh and queue.sh need (PATH=$USER_PATH)"
  as_multica 'multica auth status 2>&1 | grep -q "^User:"' \
    || die "the Multica CLI is not logged in for $MULTICA_USER — the poller cannot create issues.
     Fix: sudo bash ~/agents/multica/daemon-user/setup-multica-user.sh (it runs \`multica login\`)"
  note "Multica CLI: logged in for $MULTICA_USER"
fi

# ============================================================================
# 1. the three repo files, root-owned, under /opt/ci-triage
# ============================================================================
say "1. $DEST (from $SHA)"
x install -d -o root -g wheel -m 755 "$DEST"
x install -o root -g wheel -m 755 "$CHECKOUT/$SRC_POLL"   "$DEST/poll.sh"
x install -o root -g wheel -m 755 "$CHECKOUT/$SRC_QUEUE"  "$DEST/queue.sh"
x install -o root -g wheel -m 644 "$CHECKOUT/$SRC_PROMPT" "$DEST/prompt.md"
note "poll.sh and queue.sh 755 root:wheel · prompt.md 644 root:wheel — multica can read and run them, never write them"
wf "$DEST/.installed-from" 644 root:wheel <<EOF
$SHA
EOF
note "the sha is recorded at $DEST/.installed-from — quote it in §History when you deploy a change"

# ============================================================================
# 2. the LaunchDaemon's entry point
# ============================================================================
say "2. $DEST/run-poll.sh"
note "poll.sh needs HOME (it dies on an unset one), a PATH with gh/jq/multica/shlock, GH_TOKEN"
note "and the CLI login in \$HOME/.multica — launchd supplies none of that, so the wrapper does."
wf "$DEST/run-poll.sh" 755 root:wheel <<EOF
#!/bin/bash
# run-poll.sh — entry point for $LABEL. Runs as $MULTICA_USER (UserName in the plist).
# Installed root-owned by setup-ci-triage-poller.sh; do not hand-edit.
#
# It does exactly what multica-daemon-launchd.sh does for the daemon: export the
# credential the tick needs from its 600 file, then run the real script. The Claude
# token is deliberately not loaded — the poller creates issues, it never runs a session.
set -euo pipefail
export HOME=$MULTICA_HOME
export USER=$MULTICA_USER LOGNAME=$MULTICA_USER SHELL=/bin/bash
export PATH=$USER_PATH
export LANG=en_US.UTF-8
umask 077

# Own log: launchd must not open a file for us (StandardOutPath in a path this user owns
# would be root opening a user-writable path). If the root-owned log is not writable,
# fall back to the state directory rather than losing the tick.
LOGFILE=$LOG_FILE
if : >> "\$LOGFILE" 2>/dev/null; then
  exec >> "\$LOGFILE" 2>&1
else
  mkdir -p "\$HOME/ci-triage"
  exec >> "\$HOME/ci-triage/run-poll.log" 2>&1
fi

echo "[\$(date -u +%FT%TZ)] tick start pid \$\$ as \$(id -un) home \$HOME"
TOKEN=$GH_TOKEN_FILE
[ -s "\$TOKEN" ] || { echo "missing credential file \$TOKEN — run setup-multica-user.sh"; exit 78; }
GH_TOKEN="\$(<"\$TOKEN")"; export GH_TOKEN
# Fixture overrides must never leak into a real tick (they redirect the guard script
# and the prompt); tests/ci-triage-shell.sh sets them, deployment must not.
unset CI_TRIAGE_QUEUE CI_TRIAGE_PROMPT
cd "\$HOME"
rc=0
$DEST/poll.sh || rc=\$?
echo "[\$(date -u +%FT%TZ)] tick end rc=\$rc"
exit "\$rc"
EOF
if [[ $DRY_RUN != 1 ]]; then
  bash -n "$DEST/run-poll.sh" || die "the generated wrapper does not parse"
  note "bash -n on the installed wrapper: OK"
fi

# ============================================================================
# 3. the state directory and the wrapper's log
# ============================================================================
say "3. state and log"
if [[ $DRY_RUN == 1 ]]; then
  note "+ would install -d -o $MULTICA_USER -g $MULTICA_GROUP -m 700 $STATE_DIR   (ci-triage.log, poll.lock, queue.lock, runner-degraded-ticks)"
  note "+ would install -d -o root -g wheel -m 755 $LOG_DIR"
  note "+ would create $LOG_FILE owned by $MULTICA_USER, mode 600 (the wrapper appends; launchd never opens it)"
else
  if [[ -e $STATE_DIR || -L $STATE_DIR ]]; then
    [[ -d $STATE_DIR && ! -L $STATE_DIR ]] || die "$STATE_DIR exists and is not a plain directory — refusing"
    [[ $(stat -f %Su "$STATE_DIR") == "$MULTICA_USER" ]] || die "$STATE_DIR is not owned by $MULTICA_USER — refusing"
    note "$STATE_DIR present, owner $MULTICA_USER"
  else
    install -d -o "$MULTICA_USER" -g "$MULTICA_GROUP" -m 700 "$STATE_DIR"
    note "created $STATE_DIR (700 $MULTICA_USER) — the six-column log and the locks live here, as the spec says"
  fi
  install -d -o root -g wheel -m 755 "$LOG_DIR"
  if [[ -L $LOG_FILE ]]; then die "$LOG_FILE is a symlink — refusing"; fi
  [[ -f $LOG_FILE ]] || : > "$LOG_FILE"
  chown "$MULTICA_USER:$MULTICA_GROUP" "$LOG_FILE"; chmod 600 "$LOG_FILE"
  note "$LOG_DIR 755 root:wheel with $LOG_FILE 600 $MULTICA_USER — a root-owned directory, no log in a user home"
fi

# ============================================================================
# 4. the LaunchDaemon
# ============================================================================
if [[ $SKIP_DAEMON == 1 ]]; then
  say "4. LaunchDaemon skipped (--skip-daemon)"
else
  say "4. LaunchDaemon $LABEL (UserName $MULTICA_USER, StartInterval $INTERVAL)"
  PLIST_BODY=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>UserName</key><string>$MULTICA_USER</string>
  <key>GroupName</key><string>$MULTICA_GROUP</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DEST/run-poll.sh</string>
  </array>
  <key>WorkingDirectory</key><string>$MULTICA_HOME</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$MULTICA_HOME</string>
    <key>USER</key><string>$MULTICA_USER</string>
    <key>LOGNAME</key><string>$MULTICA_USER</string>
    <key>PATH</key><string>$USER_PATH</string>
    <key>LANG</key><string>en_US.UTF-8</string>
  </dict>
  <key>StartInterval</key><integer>$INTERVAL</integer>
  <key>RunAtLoad</key><true/>
  <key>Nice</key><integer>5</integer>
</dict>
</plist>
EOF
)
  # No StandardOutPath/StandardErrorPath on purpose: launchd would open that file with
  # root's privileges, and the wrapper (which runs as multica) opens its own log instead.
  # No KeepAlive: this is a periodic tick, not a daemon — StartInterval runs it every 300s.
  if [[ $DRY_RUN == 1 ]]; then
    note "+ would write $PLIST (644 root:wheel):"
    printf '%s\n' "$PLIST_BODY" | sed 's/^/          | /'
    note "+ would launchctl enable system/$LABEL && launchctl bootstrap system $PLIST"
    note "+ RunAtLoad means the first tick runs at bootstrap — watch it with: sudo tail -f $LOG_FILE"
  else
    printf '%s\n' "$PLIST_BODY" | wf "$PLIST" 644 root:wheel
    /usr/bin/plutil -lint "$PLIST" >/dev/null || die "$PLIST does not lint"
    if /bin/launchctl print "system/$LABEL" >/dev/null 2>&1; then
      /bin/launchctl bootout "system/$LABEL" || true
      sleep 2
      note "unloaded the previous job"
    fi
    /bin/launchctl enable "system/$LABEL" 2>/dev/null || true
    for attempt in 1 2 3; do
      if /bin/launchctl bootstrap system "$PLIST"; then break; fi
      [[ $attempt == 3 ]] && die "launchctl bootstrap system $PLIST failed three times — see: sudo launchctl print system/$LABEL"
      sleep 3
    done
    note "installed $PLIST and bootstrapped it (RunAtLoad ran the first tick)"
  fi
fi

# ============================================================================
# 5. self-check
# ============================================================================
if [[ $DRY_RUN == 1 ]]; then
  say "5. self-check (skipped in --dry-run; it would check:)"
  cat <<EOF
          | $DEST/poll.sh and queue.sh are 755 root:wheel and parse; prompt.md is 644 root:wheel and non-empty
          | the three installed files' sha256 match $CHECKOUT's at $SHA
          | $DEST/run-poll.sh is 755 root:wheel and parses
          | $DEST/.installed-from records the sha
          | multica can read and execute $DEST/poll.sh but cannot write anything in $DEST
          | $STATE_DIR is 700 $MULTICA_USER; $LOG_FILE is 600 $MULTICA_USER and appendable by it
          | $PLIST is 644 root:wheel, lints, UserName $MULTICA_USER, StartInterval $INTERVAL,
          |   and names no StandardOutPath under /Users
          | system/$LABEL is loaded
          | a tick has written a "tick start"/"tick end" pair to $LOG_FILE
          | (no tick is provoked by this script: a real tick can create a Multica issue)
EOF
  if [[ $GUARD_FAILED == 1 ]]; then
    say "DRY RUN complete — and this sha WOULD BE REFUSED (see ** above)"
    note "The install can only run from a sha where the three files are on main — i.e. from the"
    note "commit that merges the build PR (#229). Until then there is nothing to install."
    note "Then: sudo bash $SELF_DIR/$(basename "$0") \$(git -C $CHECKOUT rev-parse origin/main)"
  else
    say "DRY RUN complete — no file was written, no token read, no tick run"
    note "next: sudo bash $SELF_DIR/$(basename "$0") $SHA"
  fi
  exit 0
fi

say "5. self-check"
FAILS=()
pass() { printf '    PASS  %s\n' "$*"; }
fail() { printf '    FAIL  %s\n' "$*"; FAILS+=("$*"); }
expect_mode() {  # <path> <mode> <owner:group>
  local got; got=$(stat -f '%Lp %Su:%Sg' "$1" 2>/dev/null || true)
  if [[ $got == "$2 $3" ]]; then pass "$1 is $2 $3"; else fail "$1 is '${got:-missing}', expected '$2 $3'"; fi
}
expect_mode "$DEST" 755 root:wheel
expect_mode "$DEST/poll.sh" 755 root:wheel
expect_mode "$DEST/queue.sh" 755 root:wheel
expect_mode "$DEST/prompt.md" 644 root:wheel
expect_mode "$DEST/run-poll.sh" 755 root:wheel
expect_mode "$STATE_DIR" 700 "$MULTICA_USER:$MULTICA_GROUP"
expect_mode "$LOG_DIR" 755 root:wheel
expect_mode "$LOG_FILE" 600 "$MULTICA_USER:$MULTICA_GROUP"
[[ $SKIP_DAEMON == 1 ]] || expect_mode "$PLIST" 644 root:wheel

for pair in "poll.sh:$SRC_POLL" "queue.sh:$SRC_QUEUE" "prompt.md:$SRC_PROMPT"; do
  inst=${pair%%:*}; src=${pair##*:}
  a=$(shasum -a 256 "$DEST/$inst" | awk '{print $1}')
  b=$(shasum -a 256 "$CHECKOUT/$src" | awk '{print $1}')
  if [[ $a == "$b" ]]; then pass "$inst is byte-identical to $src at $SHA (${a:0:12}…)"
  else fail "$inst does not match $src (${a:0:12}… vs ${b:0:12}…)"; fi
done
if [[ $(cat "$DEST/.installed-from") == "$SHA" ]]; then pass ".installed-from records $SHA"; else fail ".installed-from does not record $SHA"; fi
for f in poll.sh queue.sh run-poll.sh; do
  if bash -n "$DEST/$f" 2>/dev/null; then pass "$f parses"; else fail "$f does not parse"; fi
done
if [[ -s $DEST/prompt.md ]]; then pass "prompt.md is non-empty ($(wc -l < "$DEST/prompt.md" | tr -d ' ') lines)"; else fail "prompt.md is empty"; fi

# The boundary: multica runs what root installed and can change none of it.
if as_multica "test -r '$DEST/poll.sh' && test -x '$DEST/poll.sh'" >/dev/null 2>&1; then
  pass "$MULTICA_USER can read and execute $DEST/poll.sh"
else fail "$MULTICA_USER cannot read/execute $DEST/poll.sh"; fi
for p in "$DEST/poll.sh" "$DEST/queue.sh" "$DEST/prompt.md" "$DEST/run-poll.sh"; do
  if as_multica "test -w '$p'" >/dev/null 2>&1; then
    fail "$MULTICA_USER can write $p — the trigger path must be root-owned (FIND-004)"
  else pass "$MULTICA_USER cannot write $p"; fi
done
if as_multica "touch '$DEST/.write-probe'" >/dev/null 2>&1; then
  rm -f "$DEST/.write-probe"
  fail "$MULTICA_USER can create files in $DEST — it must be root-owned"
else pass "$MULTICA_USER cannot create files in $DEST"; fi
if as_multica "test -w '$LOG_FILE'" >/dev/null 2>&1; then pass "$MULTICA_USER can append to $LOG_FILE"; else fail "$MULTICA_USER cannot append to $LOG_FILE"; fi

if [[ $SKIP_DAEMON != 1 ]]; then
  if /usr/bin/plutil -lint "$PLIST" >/dev/null 2>&1; then pass "$PLIST lints"; else fail "$PLIST does not lint"; fi
  for needle in "<key>UserName</key><string>$MULTICA_USER</string>" "<key>StartInterval</key><integer>$INTERVAL</integer>" "$DEST/run-poll.sh"; do
    if grep -qF -- "$needle" "$PLIST"; then pass "plist carries $needle"; else fail "plist is missing $needle"; fi
  done
  if grep -q 'StandardOutPath\|StandardErrorPath' "$PLIST"; then
    fail "the plist names a launchd log path — the wrapper must own its log, not launchd"
  else pass "no StandardOutPath/StandardErrorPath (the wrapper opens its own log)"; fi
  if /bin/launchctl print "system/$LABEL" >/dev/null 2>&1; then
    pass "launchd: system/$LABEL is loaded ($(/bin/launchctl print "system/$LABEL" 2>/dev/null | awk -F'= ' '/^[[:space:]]*(state|runs) = /{printf "%s ", $0}' | tr -s ' ' | cut -c1-90 || true))"
  else fail "launchd: system/$LABEL is not loaded"; fi
  printf '    waiting for the first tick (RunAtLoad)'
  for _ in $(seq 1 20); do
    grep -q 'tick end' "$LOG_FILE" 2>/dev/null && break
    printf '.'; sleep 2
  done
  printf '\n'
  if grep -q 'tick end' "$LOG_FILE" 2>/dev/null; then
    pass "a tick ran: $(grep 'tick ' "$LOG_FILE" | tail -2 | tr '\n' ' ' | cut -c1-120)"
  else
    fail "no 'tick end' line in $LOG_FILE yet — look at it: sudo tail -30 $LOG_FILE"
  fi
  if [[ -s $STATE_DIR/ci-triage.log ]]; then
    pass "the six-column log has lines: $(tail -1 "$STATE_DIR/ci-triage.log" | tr '\t' ' ' | cut -c1-110)"
  else
    note "NOTE  $STATE_DIR/ci-triage.log is empty — expected only if the tick failed before its first decision"
  fi
fi

if [[ ${#FAILS[@]} -gt 0 ]]; then
  printf '\nSELF-CHECK FAILED (%d):\n' "${#FAILS[@]}"
  printf '  - %s\n' "${FAILS[@]}"
  printf '\nStop here. Fix the reason above and re-run (every step is idempotent).\n'
  printf 'Logs: sudo tail -30 %s   and   sudo tail -5 %s/ci-triage.log\n' "$LOG_FILE" "$STATE_DIR"
  exit 1
fi

say "done — all checks passed"
cat <<EOF
    Installed from $SHA. While a persistent runner is still registered, every tick logs
    "degraded  persistent runner registered" and creates nothing — the gate is fail-closed
    (spec 60 FIND-010), so this install is inert until the runner side is finished.

    Still yours to do (spec 60 §Operating it, action (4)):
      • create the \`claude-triage\` agent in Multica (http://localhost:3000 -> Agents -> New
        agent, runtime m4-mini / Claude Code) — queue.sh assigns issues to that exact name
      • confirm an assignee named \`Everett\` exists — runner-outage issues go to it
    Watch it:
      sudo launchctl print system/$LABEL | grep -E 'state|runs|last exit'
      sudo tail -f $LOG_FILE                       # tick start/end and any stderr
      sudo tail -5 $STATE_DIR/ci-triage.log        # the six-column decision log
    Deploy a change (after it merges to main):
      sudo bash $SELF_DIR/$(basename "$0") <new main sha>
EOF
