# Runbook — spec 60 §The runner: the ephemeral JIT Actions runner

One sitting, ~30 minutes plus two proof runs, all from the orchestrator account on
the mini. One token is minted by you and pasted into a hidden prompt — it never
goes through chat, a file the orchestrator can read, or a log. The install script
is idempotent: if anything stops, fix the reason and re-run it; finished steps say
"present / skipping".

**What this replaces.** Today CI runs as `orchestrator`: the `m4-mini` runner
service is a LaunchAgent in `~orchestrator/Library/LaunchAgents`, so every PR's
`npm ci` and `npm test` execute as you, next to your `gh` token, your Claude token
and `.env.acceptance` — and next to the runner's own registration credential
(spec 60 §The boundary, FIND-002). After this runbook, each CI job gets a
throwaway macOS account that exists only for that job, and a root supervisor
destroys the account, its processes and its files when the job ends (FIND-009).

**Order matters.** Steps (a)–(d) install and prove the new runner; only then (e)
retires the old one; only after (f) records the proof does the spec 60 build PR
merge, and only after that merge does (g) install the poller. Between (b) and (e)
both runners are registered — jobs may land on either, which is harmless and is
why (e) is separate. In spec 60 §Operating it these are Everett's actions (3),
(4) and (5); (g) explains why the poller install and the merge are the other way
round on the ground.

| | |
|---|---|
| Install script | `~/agents/multica/actions-runner/setup-actions-runner.sh` |
| Runner pinned | **v2.337.0**, `actions-runner-osx-arm64-2.337.0.tar.gz`, sha256 `5a2cd92908a93d7276a194e1de6008099f3e7946f3f8e14aa7a1a7b4a31fdec2` |
| Supervisor | `/opt/actions-runner-jit/actions-runner-jit.sh` (root, loops forever) |
| LaunchDaemon | `/Library/LaunchDaemons/com.user.actions-runner-jit.plist` (root, KeepAlive) |
| Logs | `/var/log/actions-runner-jit/supervisor.log` (+ `.err.log`), root-only |
| Root-only files | `/etc/actions-runner-jit/jit_pat`, `/etc/actions-runner-jit/uid_counter` (600 root) |
| Job accounts | `job-<uid>`, group `actions-jobs` (gid 5000), home `/private/var/actions-runner-jobs/<uid>/home` |
| Poller (step (g)) | `~/agents/multica/actions-runner/setup-ci-triage-poller.sh <main sha>` → `/opt/ci-triage/`, `com.user.ci-triage-poll` |

## Why UID 5000+

The counter starts at **5000** and refuses to pass 60000. Teardown works **by
UID** — `pkill -9 -U <uid>`, `find … -user <uid>`, and the account deletion — so
the one thing that must never happen is a counter value landing on an account
that is not ours: the sweep would kill that account's processes and delete its
files. 501 and 502 are `orchestrator` and `multica`, macOS hands out new local
accounts from 503 upward, and Apple reserves everything under 500 for its own
`_` service accounts, some of which arrive with an OS update. Starting at 600
would sit in the path of both. 5000 is far from anything macOS or Homebrew
allocates and leaves ~55000 jobs of headroom (decades at this volume); the
supervisor also skips any UID that already exists rather than reusing it.

"Below 1000 so macOS hides it" is not a reason: macOS hides accounts under UID
500, not under 1000, and the account is hidden explicitly anyway — the supervisor
sets `IsHidden 1` and marks the record `;DisabledUser;`, so it appears in no
login window or Users & Groups list and no password can be used with it.

## The ordered list

### (a) Mint the JIT PAT

GitHub → your avatar → **Settings** → **Developer settings** (bottom of the left
column) → **Personal access tokens** → **Fine-grained tokens** → **Generate new
token**:

| Field | Value |
|---|---|
| Token name | `m4-mini actions-runner-jit` |
| Expiration | **1 year** (put it on the rotation list — spec 60 §The runner, "One more PAT") |
| Resource owner | `ezybg7` |
| Repository access | **Only select repositories** → `ezybg7/pantry` |
| Repository permissions | **Administration: Read and write** — and nothing else (Metadata: Read is added for you) |
| Account permissions | none |

Generate, then copy it once; it starts with `github_pat_`. *Administration:
write* is the permission that mints a just-in-time runner registration; nothing
else on the token is needed and nothing else should be granted. This token stays
in a root-only file and **never enters a job's environment** — what a job gets is
the single-use registration the token produces.

### (b) Run the install

Look first, change nothing:

```bash
bash ~/agents/multica/actions-runner/setup-actions-runner.sh --dry-run
```

It prints every step, every file and every mode it would write, runs as you (no
sudo), touches no token and changes nothing. Then, for real:

```bash
sudo bash ~/agents/multica/actions-runner/setup-actions-runner.sh
```

It prompts once — `PAT (input hidden, then Enter):` — paste the token from (a).
Nothing is echoed. Expect, in order:

1. **preflight** — tools, macOS/arm64, the payload parses and lints, free space.
2. **group `actions-jobs` (gid 5000)** — created, with no members: it is only a primary group.
3. **pristine runner 2.337.0 at `/opt/actions-runner`** — downloads the pinned
   tarball, prints `sha256 verified: 5a2cd9…`, extracts it, moves it into place,
   `chown -R root:wheel`, and confirms `Runner.Listener` reports the pin. **A
   hash mismatch aborts before anything is installed** — if that happens, the pin
   is stale (re-read the release and update the three constants at the top of the
   script) or the download was tampered with. On a re-run it says "already
   installed and pinned … skipping the download".
4. **`.path` and `.env`** — `.path` is byte-identical to the old runner's
   (Homebrew first), so CI behaves as it does today. `TMPDIR` is *not* in `.env`:
   the supervisor appends a per-job `TMPDIR` to each job's own copy.
5. **UID counter** — `/etc/actions-runner-jit/uid_counter` = 5000 on a first run;
   on a re-run it is never lowered.
6. **the PAT** — hidden prompt → `/etc/actions-runner-jit/jit_pat` (600 root),
   then verified by *reading* the runners API (which needs the Administration
   scope). The script never mints a JIT config itself: that would leave an
   offline registration behind and the poller's gate reads those as an outage.
   It prints the token's expiry date if GitHub reports one.
7. **the supervisor** → `/opt/actions-runner-jit/actions-runner-jit.sh`, 755 root.
8. **the LaunchDaemon** → installs and bootstraps
   `system/com.user.actions-runner-jit`, then waits up to 60 s for the first
   online ephemeral registration to appear.
9. **self-check** — a `PASS` line per check: the group, the modes and owners of
   every installed path, `Runner.Listener` = the pin, `.jit-pin`, `.path`,
   `.env`, the install not writable by your account, the PAT file and counter
   *not readable* by your account, the counter ≥ 5000, the supervisor parses, the
   plist lints and `state = running`, a `supervisor start` line in the log, no
   `FATAL`, exactly one ephemeral `m4-mini` online, and no `job-*` account
   between jobs. It also reports `FAIL  1 non-ephemeral runner(s) still
   registered` — **that one is expected until step (e)**. Any other FAIL stops
   the script with the reason; fix it and re-run.

macOS may show a "Background Items Added" notification for the new LaunchDaemon.
If the daemon does not start, check System Settings → General → Login Items &
Extensions → *Allow in the Background*.

### (c) Verify from the seat (no sudo)

```bash
bash ~/agents/multica/actions-runner/self-check.sh
```

This is spec 60 §Acceptance's runner boxes in the parts provable without root.
Every line under **RUNS NOW** must be `PASS` (again, the non-ephemeral line stays
`FAIL` until (e)). It also prints, and does not attempt, the handful of proofs
that need root:

```bash
sudo launchctl print system/com.user.actions-runner-jit | grep -E 'state|pid|last exit'
sudo tail -50 /var/log/actions-runner-jit/supervisor.log
sudo cat /etc/actions-runner-jit/uid_counter          # strictly greater after every job
```

A healthy log, between jobs, reads like this (one line per event, UTC, never a
token or a jitconfig):

```
2026-09-12T11:02:03Z supervisor start: pid=931 repo=ezybg7/pantry runner=m4-mini pristine=/opt/actions-runner (runner 2.337.0) uid_range=5000-60000 once=0
2026-09-12T11:02:03Z startup sweep: 0 leftover(s) handled
2026-09-12T11:02:05Z account job-5000 created: uid=5000 group=actions-jobs home=/private/var/actions-runner-jobs/5000/home shell=/bin/bash hidden=yes admin=no
2026-09-12T11:02:06Z runner cloned to /private/var/actions-runner-jobs/5000/runner (APFS clonefile)
2026-09-12T11:02:07Z jit config minted: runner_id=22 name=m4-mini labels=self-hosted,macOS,ARM64,m4-mini work_folder=/private/var/actions-runner-jobs/5000/work
2026-09-12T11:02:07Z job start: account=job-5000 uid=5000 runner_id=22 root=/private/var/actions-runner-jobs/5000
```

### (d) The proof job, on a scratch branch

This is boxes 2 and 3 of §Acceptance. The workflow is
`~/agents/multica/actions-runner/proof-job.yml`. **It must never be merged to
`main`** — it deliberately writes markers into world-writable directories,
installs a crontab and detaches a process.

```bash
cd ~/code/pantry && git fetch origin && git switch -c scratch/jit-proof origin/main
mkdir -p .github/workflows
cp ~/agents/multica/actions-runner/proof-job.yml .github/workflows/jit-proof.yml
git add .github/workflows/jit-proof.yml
git commit -m "scratch: JIT runner proof job (do not merge)"
git push -u origin scratch/jit-proof
RUN=$(gh run list -b scratch/jit-proof -L1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN"
gh run view "$RUN" --log | less     # every PASS/FAIL line
gh run view "$RUN" --web            # the step summary: the account, its UID, what to check next
```

**How to read it.** The run is green only if every proof passed. The summary
table at the top gives the account (`job-<uid>`), its UID, its home and its
TMPDIR. In the logs:

- step 1 — `id -un` is a `job-<n>` account, `HOME` and `TMPDIR` are inside
  `/private/var/actions-runner-jobs/<n>/`, not in the admin group, no sudo, and
  the only token-shaped variables are the ones GitHub issued for this job
  (names printed, never values).
- step 2 — the home is fresh: no `.gitconfig`, `.npmrc`, `.ssh`, `.npm` or
  Keychain, and git reads no config from outside the system file.
- step 3 — `Permission denied` for `~orchestrator/.claude/oauth_token`,
  `~orchestrator/.config/gh/hosts.yml`, `~orchestrator/agents/.env.acceptance`,
  `ls ~orchestrator`, the old runner's `.credentials`, `~multica/.ssh`,
  `~multica/.multica`, the supervisor's PAT file and UID counter, and for writes
  into `/opt/homebrew/bin`, `/opt/actions-runner`, `/opt/actions-runner-jit`,
  the jobs parent directory and `/Library/LaunchDaemons`.
- step 4 — it leaves markers everywhere it can, installs a crontab, and detaches
  two processes (a `nohup` beacon and a `launchctl submit` job).

Then, **on the mini after the run finishes**, with `<uid>` from the summary:

```bash
dscl . -read /Users/job-<uid>                      # must fail: no such record
ls -d /private/var/actions-runner-jobs/<uid>       # must fail: no such directory
pgrep -U <uid>                                     # must print nothing
find /private/tmp /private/var/tmp /Users/Shared -user <uid> -print   # nothing
sudo find /private/var/folders -user <uid> -print                     # nothing
sudo crontab -u job-<uid> -l                       # must fail: no such user
sudo launchctl print user/<uid>                    # must fail: no such domain
sudo cat /etc/actions-runner-jit/uid_counter       # greater than <uid>
bash ~/agents/multica/actions-runner/self-check.sh # every RUNS NOW line PASS again
```

Box 3 asks for three runs, so repeat twice more with an interruption mid-job
(start a run, then while it is going):

```bash
gh workflow run jit-proof.yml --ref scratch/jit-proof   # then, mid-job:
sudo launchctl kickstart -k system/com.user.actions-runner-jit   # SIGTERM -> the trap tears down
# and, for the third case:
sudo pkill -9 -f actions-runner-jit.sh                  # KeepAlive restarts it; the startup sweep cleans up
```

After each, repeat the `<uid>` checks. Every run's UID must be **higher** than the
last. Finally:

```bash
git push origin --delete scratch/jit-proof
cd ~/code/pantry && git switch main && git branch -D scratch/jit-proof
```

### (e) Retire the persistent runner — after (d) passes

**Without sudo**, as `orchestrator` (the runner's `svc.sh` refuses to run as
root, and its LaunchAgent lives in your own launchd domain):

```bash
bash ~/agents/multica/actions-runner/setup-actions-runner.sh --remove-persistent
```

It lists what is registered, then runs `./svc.sh stop`, `./svc.sh uninstall`
(removing `~/Library/LaunchAgents/actions.runner.ezybg7-pantry.m4-mini.plist`),
mints a single-use removal token with
`gh api -X POST repos/ezybg7/pantry/actions/runners/remove-token` (never
printed), and runs `./config.sh remove --token …`, which deregisters the runner
server-side and deletes `.runner` and `.credentials` locally. It then verifies
that no non-ephemeral runner remains and that the three credential files are
gone — existence only; it never reads them.

If `config.sh remove` fails, the server-side fallback is
`gh api -X DELETE repos/ezybg7/pantry/actions/runners/21` — that deregisters but
leaves the local credential, so delete the directory afterwards. When you are
happy: `rm -rf ~/actions-runner`.

Re-run `bash ~/agents/multica/actions-runner/self-check.sh`: **now every line,
including "no non-ephemeral runner is registered", must PASS.**

### (f) Record the proof on AMBR-21

Spec 60 §Operating it, Everett's action (3): the runner boxes are recorded on the
board card **before** the poller is installed and before the build PR merges.
Paste this onto AMBR-21, filled in:

```
Runner proof (spec 60 §Acceptance, runner boxes) — <date>

Install: runner v2.337.0, sha256 5a2cd92908a93d7276a194e1de6008099f3e7946f3f8e14aa7a1a7b4a31fdec2 (verified)
         /opt/actions-runner root:wheel 755 · supervisor /opt/actions-runner-jit/actions-runner-jit.sh
         LaunchDaemon com.user.actions-runner-jit: state = running
         UID range 5000+, group actions-jobs (gid 5000)

Box 1 — ephemeral principal: gh api .../actions/runners = exactly one m4-mini,
        ephemeral true, online, no persistent runner (persistent id 21 removed in step (e)).
        During the job: Runner.Listener ran as job-<uid>, home /private/var/actions-runner-jobs/<uid>/home.
        After: dscl . -read /Users/job-<uid> fails; the directory is gone; the next job's UID was <uid+1>.

Box 2 — a job holds nothing: proof run <run url>. id -un = job-<uid>;
        token variables = GITHUB_TOKEN (+ the runner's own ACTIONS_* per-job tokens), nothing from the host;
        Permission denied for all 10 host reads and all 5 writes listed in the spec.

Box 3 — nothing survives teardown: proven three ways —
        normal completion <run url>, kickstart -k mid-job <run url>, kill -9 mid-job <run url>.
        In all three: pgrep -U <uid> empty, dscl has no record, find over /private/tmp
        /private/var/tmp /private/var/folders /Users/Shared -user <uid> empty, crontab gone,
        launchctl user/<uid> domain gone. Next job's git/npm config showed nothing from the earlier job.

self-check.sh: all RUNS NOW checks PASS (output attached).
Residuals accepted as written in spec 60 §The runner (+ RUNBOOK §Residuals).
```

Attach the `self-check.sh` output and the three run URLs. Then the poller install
(Everett's action (4)) and the build PR merge (action (5)) are unblocked.

### (g) Install the CI-triage poller — spec 60's action (4)

This is the other half of the spec: the five-minute tick that notices a red run
and creates the Multica issue. It is **inert** until the runner side is
finished — with a persistent runner still registered, every tick logs
`degraded  persistent runner registered` and creates nothing (FIND-010, the gate
fails closed) — so it is safe to install as soon as (f) is recorded.

**(g1) Merge the build PR first.** Spec 60 §Operating it numbers the poller
install (4) before the build-PR merge (5), but on the ground it has to be the
other way round: `.github/scripts/ci-triage-poll.sh`, `ci-triage-queue.sh` and
`.github/ci-triage-prompt.md` only reach `main` when that PR merges, and the
installer refuses any sha that is not an ancestor of `origin/main` (FIND-004 —
what runs as root must be a `main` sha someone typed). Nothing triages in the
gap: that merge deletes `.github/workflows/ci-triage.yml`, and no poller exists
yet. Merge PR **#229** (`gh pr ready 229 && gh pr merge 229 --squash`), then:

```bash
cd ~/code/pantry && git fetch origin main && git switch main && git pull --ff-only
SHA=$(git rev-parse HEAD)          # the merge commit — this is the sha that will run
echo "$SHA"
```

**(g2) Preview, then install.**

```bash
bash ~/agents/multica/actions-runner/setup-ci-triage-poller.sh --dry-run "$SHA"
sudo bash ~/agents/multica/actions-runner/setup-ci-triage-poller.sh "$SHA"
```

It prints the three files' sha256, then installs `poll.sh` and `queue.sh` 755
root and `prompt.md` 644 root into `/opt/ci-triage/`, records the sha in
`/opt/ci-triage/.installed-from`, generates `/opt/ci-triage/run-poll.sh` (the
LaunchDaemon's entry point: it exports `GH_TOKEN` from
`/Users/multica/.config/multica-daemon/github_token` and sets `HOME`, `PATH` and
`LANG`, exactly as the Multica daemon's own wrapper does — the Claude token is
deliberately not loaded), creates `/Users/multica/ci-triage/` (700 `multica`) for
the six-column log and the locks, creates `/var/log/ci-triage-poll/poll.log` (600
`multica`, in a root-owned directory) for the wrapper's own output, writes
`/Library/LaunchDaemons/com.user.ci-triage-poll.plist` (root, `UserName
multica`, `StartInterval 300`, **no** `StandardOutPath`) and bootstraps it.
It refuses if the checkout is not at that sha, if the sha is not on `main`, if any
of the three files has an uncommitted edit, if the `multica` user or its PAT file
is missing, or if the Multica CLI is not logged in for that user.

**(g3) Verify, and watch one tick.** `RunAtLoad` fires the first tick at
bootstrap and the self-check waits for it, so the install itself proves the tick
runs. To look again:

```bash
sudo launchctl print system/com.user.ci-triage-poll | grep -E 'state|runs|last exit'
sudo tail -f /var/log/ci-triage-poll/poll.log        # "tick start … / tick end rc=0"
sudo tail -5 /Users/multica/ci-triage/ci-triage.log  # the six-column decision log
sudo launchctl kickstart -k system/com.user.ci-triage-poll   # run a tick now
```

Before step (e) the expected decision line is
`…  -  poller  -  degraded  persistent runner registered`. After (e), with one
online ephemeral runner, a tick with no new failures writes nothing at all and
`rc=0` is the whole story.

**(g4) Two things only you can do**, in Multica (<http://localhost:3000>):
create the agent **`claude-triage`** (Agents → New agent, runtime *m4-mini /
Claude Code*) — `queue.sh` assigns every triage issue to that exact name — and
confirm an assignee named **`Everett`** exists, because runner-outage issues are
assigned to it. Until the agent exists, issues are created and sit unassignable;
that is a `degraded` line, not a lost failure.

**(g5) Deploying a change to the three files** later: merge to `main`, then
re-run the installer with the new sha (it replaces only those files and restarts
the daemon), and add one line to spec 60 §History naming that sha.

```bash
cd ~/code/pantry && git switch main && git pull --ff-only
sudo bash ~/agents/multica/actions-runner/setup-ci-triage-poller.sh "$(git rev-parse HEAD)"
```

## To disable (spec 60 §Operating it, in increasing bluntness)

```bash
# 1. disable the claude-triage agent in Multica — triggers still log, issues queue
#    (Multica UI -> Agents -> claude-triage -> disable)
# 2. no triggers at all: stop the tick
sudo launchctl bootout system/com.user.ci-triage-poll
# 3. remove the trigger path entirely
sudo rm -rf /opt/ci-triage
# 4. pause for one UTC day without touching anything else: append six synthetic
#    `queued` lines, which is what the daily cap counts
sudo -u multica -H bash -c 'for i in 1 2 3 4 5 6; do printf "%s\t0\tmanual\tmanual\tqueued\tpaused by hand\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> ~/ci-triage/ci-triage.log; done'
# 5. stop all CI on the mini (jobs queue at GitHub until it is back)
sudo launchctl bootout system/com.user.actions-runner-jit
```

To replay one triage by hand, as `multica`: export the six variables
(`RUN_ID WORKFLOW_NAME HEAD_BRANCH HEAD_SHA RUN_EVENT PR_NUMBER`) plus `GH_TOKEN`
and run `/opt/ci-triage/queue.sh` — it creates the issue. To exercise a guard
without creating anything, point `HOME` at a scratch directory first.

## Operate

```bash
sudo launchctl print system/com.user.actions-runner-jit | grep -E 'state|pid|last exit'
sudo tail -f /var/log/actions-runner-jit/supervisor.log      # one line per event
sudo tail -20 /var/log/actions-runner-jit/supervisor.err.log # WARN and FATAL only
sudo launchctl kickstart -k system/com.user.actions-runner-jit  # restart; a job in flight is torn down
sudo launchctl bootout  system/com.user.actions-runner-jit      # stop ALL CI on the mini (jobs queue)
sudo launchctl enable   system/com.user.actions-runner-jit && \
  sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.actions-runner-jit.plist   # start again
gh api repos/ezybg7/pantry/actions/runners --jq '.runners[] | "\(.id) \(.name) \(.status) ephemeral=\(.ephemeral)"'
```

- **Log volume** is a few lines per job; truncate with
  `sudo : > /var/log/actions-runner-jit/supervisor.log` if it ever matters. A
  job's own runner diagnostics live in the per-job root and die with it, so the
  only place to see a job's detail after the fact is the GitHub run log.
- **A job hangs** → cancel it on GitHub; the runner exits and the supervisor
  tears the account down. If a process refuses to die the log says
  `still has processes after 10 passes` and leaves the account for inspection;
  that blocks nothing (the next job gets a new UID) but is a finding.
- **`degraded: no online ephemeral runner`** from the poller → check the daemon
  state and the log. A mint failure logs
  `generate-jitconfig failed` and backs off 30 s → 5 min; the usual cause is an
  expired PAT (step (a) again, then
  `sudo bash …/setup-actions-runner.sh --rotate-pat`).
- **Bump the runner version** (a runner too old is refused by GitHub):
  ```bash
  curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name
  curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .body | grep osx-arm64
  ```
  Put the new version, asset name and sha256 into the three constants at the top
  of `setup-actions-runner.sh`, then re-run
  `sudo bash ~/agents/multica/actions-runner/setup-actions-runner.sh`. It
  replaces `/opt/actions-runner` only (sha256-verified), leaves the PAT and the
  counter alone, and restarts the daemon — a job in flight is torn down, so do it
  when CI is idle. Note the bump in `~/agents/memory/entities/multica-server.md`.
- **A one-off cycle by hand** (with the daemon booted out):
  `sudo bash /opt/actions-runner-jit/actions-runner-jit.sh --once`, and
  `--sweep-only` to tear down leftovers and exit.

## Rollback

```bash
# 1. stop the supervisor (KeepAlive stops with the bootout) and remove the job
sudo launchctl bootout system/com.user.actions-runner-jit
sudo rm /Library/LaunchDaemons/com.user.actions-runner-jit.plist
# 2. tear down anything a job left, then the install itself
sudo bash /opt/actions-runner-jit/actions-runner-jit.sh --sweep-only    # do this BEFORE deleting the script
sudo rm -rf /opt/actions-runner /opt/actions-runner-jit /private/var/actions-runner-jobs
sudo rm -rf /etc/actions-runner-jit /var/log/actions-runner-jit /var/run/actions-runner-jit.lock
# 3. any job account the sweep could not reach (there should be none)
dscl . -list /Users | grep -E '^job-[0-9]+$'
sudo sysadminctl -deleteUser job-<uid>          # per account
# 4. the group
sudo dseditgroup -o delete -n . actions-jobs
# 5. the PAT: GitHub -> Settings -> Developer settings -> Fine-grained tokens
#    -> delete "m4-mini actions-runner-jit"
# 6. if CI is needed again immediately, re-register a persistent runner the old way
#    (github.com/ezybg7/pantry/settings/actions/runners -> New self-hosted runner)
#    — that puts CI back under `orchestrator`, which is the exposure spec 60 exists to close.
```

And the poller half, independently (it can be removed without touching the runner):

```bash
sudo launchctl bootout system/com.user.ci-triage-poll
sudo rm /Library/LaunchDaemons/com.user.ci-triage-poll.plist
sudo rm -rf /opt/ci-triage /var/log/ci-triage-poll
# the six-column log and the locks are multica's own state; keep them for the record or:
sudo rm -rf /Users/multica/ci-triage
# and disable or delete the claude-triage agent in Multica
```

Nothing here touches Neon, the Ambry app, the Multica server, the `multica`
daemon user's credentials or the repository's workflows.

## Residuals

What spec 60 §The runner accepts, unchanged — for the duration of a job:

- the mini's **CPU and outbound network**;
- **reachability of localhost services** (Multica web/API, Postgres 5433), each
  of which demands a credential the job does not hold (spec 61's proofs:
  `pg_hba` reject for the `multica` role, TCP without a password fails);
- a **`PATH` that includes Homebrew binaries**, which a job can read and execute
  but not modify (`/opt/homebrew` is owner `orchestrator`, group `admin`);
- **information passing through a sticky world-writable directory**: a job can
  make a file world-readable before teardown sweeps it, and a later job could
  read it if `main`'s workflows chose to — none does, `$RUNNER_TEMP` is inside
  the per-job root, and the sweep removes it by owner. This is information, not
  privilege;
- the invariant **holds against a non-root adversary only**: a job account has no
  admin group, no sudo and a root-owned install, and a kernel or `sysadminctl`
  escape is out of this spec's scope;
- every job starts **cold** — no `~/.npm`, no cached Node — so `npm ci`
  downloads each time and the ~85 s CI job takes roughly three minutes. A
  persisted cache is declined (PRD Q4). Concurrency is unchanged (one runner,
  one job at a time, as the persistent runner was), and each job in a multi-job
  workflow now also pays about four seconds for its account and its runner
  clone.

Three more this build adds, none of them privilege:

- **The JIT config is on `run.sh`'s argv.** macOS does not hide process arguments
  from other local accounts (measured on this machine, 2026-09-12), so
  `orchestrator` or `multica` could read a running job's registration token with
  `ps`. It is the single-use credential that job already holds, it is consumed
  when the listener starts, and it dies with the job. The runner also accepts
  config arguments via `ACTIONS_RUNNER_INPUT_<ARG>` environment variables, which
  would close even this; it is unproven on `run --jitconfig`, so this build uses
  the argv form the spec names and leaves the env form as a follow-up once the
  first proof is green.
- **A 3–5 second window per job with no runner registered**, between teardown and
  the next mint. The poller's gate fails closed there (`degraded: no online
  ephemeral runner`, no issue, no PR) and self-corrects on the next tick; three
  consecutive degraded ticks are needed for an outage issue, so a false alarm is
  effectively impossible at a 5-minute poll.
- **Root executes `gh` and `jq` from `/opt/homebrew`,** which is owned by
  `orchestrator`. A compromised orchestrator account can therefore influence the
  supervisor — but that account is the operator's, already holds every secret on
  the machine, and the spec's boundary is the *job*, not the operator. Vendoring
  a private copy of `gh` for root is the fix if that ever changes.

One knob, in case a job ever misbehaves in a way that points at the account
record: the supervisor's `HARDEN_DISABLE_LOGIN=1` marks each job account
`;DisabledUser;` immediately after creation (so that the random password
`sysadminctl` briefly carries on its argv is worthless). Set it to `0` and
re-run the install to fall back to "random password only".
