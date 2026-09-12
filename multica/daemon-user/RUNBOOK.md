# Runbook — spec 61 phase 2: the `multica` daemon user

One sitting, ~15 minutes, all from the orchestrator account on the mini (you
have its password; `sudo` works there). Three tokens are minted by you and
pasted into hidden prompts — they never go through chat, a file the
orchestrator can read, or a log. The script is idempotent: if anything
stops, fix the reason and re-run it; finished steps say "present/skipping".

Before you start, the `multica` user must exist as a **Standard** user
(it does: uid 502, home `/Users/multica`, created 2026-09-11). If it did not:
`sudo sysadminctl -addUser multica -fullName "Multica Daemon" -password -`.

## The ordered list

**(a) Log in to Multica.** Open <http://localhost:3000>, enter your address,
then read the code from the server log (no e-mail provider is configured):

```bash
grep "Verification code" ~/agents/multica/logs/backend.log | tail -1
```

If the last code has expired, request a new one and run the grep again. The
first login creates the shared workspace; afterwards the orchestrator flips
`DISABLE_WORKSPACE_CREATION=true` (phase 1 note — not your step).

**(b) Multica API token.** Settings → **API Token** → create, name
`m4-mini daemon`, expiry **1 year**. Copy it once; it starts with `mul_` and
is shown exactly once.

**(c) GitHub fine-grained PAT.** GitHub → Settings → Developer settings →
Personal access tokens → **Fine-grained tokens** → Generate new token:

| Field | Value |
|---|---|
| Token name | `m4-mini multica daemon` |
| Expiration | 1 year (the script prints the exact expiry date it sees) |
| Resource owner | `ezybg7` |
| Repository access | **Only select repositories** → `ezybg7/pantry` |
| Repository permissions | **Contents: Read** · **Pull requests: Read and write** (Metadata: Read is added automatically) |
| Account permissions | none |

Why Contents is *read*, not read/write: pushes go over the deploy key (SSH),
`gh` only needs to read refs and write pull requests. A fine-grained PAT is
*your* identity (repository admin); with Contents: write it could update
`main` through the API, which is the one thing the spec keeps human. If the
first agent run fails at `gh pr create` with a permissions error, edit the
token to Contents: Read and write — that is the fallback, not the default.
The token starts with `github_pat_`.

**(d) Claude Code long-lived token.** In the orchestrator terminal (its
`claude` is signed in to your account):

```bash
claude setup-token
```

It opens the browser, then prints a token starting with `sk-ant-oat01-`.
Copy it. It is inference-only (no Remote Control), which is all the daemon
needs, and it counts against the same subscription as your own sessions.

Do it a second time for the orchestrator itself: on 2026-09-11 the
orchestrator's own `~/.claude/oauth_token` was echoed into an agent
transcript by a test harness (see the daily log). Replace it —
`claude setup-token`, then paste the new value into `~/.claude/oauth_token`
(mode 600). If your Claude account settings list the old long-lived token, revoke it there; the replacement is what matters.

**(e) Run the script.**

```bash
sudo bash ~/agents/multica/daemon-user/setup-multica-user.sh
```

It installs Claude Code and the Multica CLI (0.4.42, pinned to the server's
release, checksum-verified) into `/Users/multica/.local/bin`, generates the
deploy key, then prompts for the three tokens with hidden input — paste (d),
(c), (b) in that order. It logs the CLI in, verifies the PAT, and then
**waits, showing the public deploy key** — that is step (f). Everything the
script does is listed in its header comment.

**(f) Add the deploy key** (while the script waits). Either
<https://github.com/ezybg7/pantry/settings/keys> → *Add deploy key* → title
`m4-mini multica daemon`, paste the key, tick **Allow write access** — or in a
second orchestrator tab (its `gh` is logged in as `ezybg7`, no sudo needed):

```bash
gh repo deploy-key add /Users/Shared/multica-daemon/pantry_deploy_ed25519.pub \
  --allow-write --title "m4-mini multica daemon" --repo ezybg7/pantry
```

Back in the script, press Enter. It tests `ssh -T git@github.com`, clones
`git@github.com:ezybg7/pantry.git` into `/Users/multica/work/pantry`,
installs `/Library/LaunchDaemons/com.user.multica-daemon.plist`, starts the
daemon, and runs the self-check. Expect a **PASS** line for each of: launchd
state running · `multica daemon status` running with `claude` detected and
≥ 1 workspace · logged in · CLI = 0.4.42 · `claude --version` ≥ 2 · `gh auth
status` · PAT reads `ezybg7/pantry` · `ssh -T git@github.com` authenticated ·
clone over SSH · three credential files 600/multica · PAT scratch file gone ·
home mode 700 — then the boundary proofs, which PASS only when they are
**denied**: `cat ~orchestrator/agents/.env.acceptance`, `ls ~orchestrator`,
`cat ~orchestrator/.claude/oauth_token`, `cat ~orchestrator/.config/gh/hosts.yml`,
`cat ~orchestrator/agents/multica/.env`, `psql` over the socket as
`orchestrator` (peer) and as `multica` (pg_hba reject), `psql` over TCP as
`multica` and as `orchestrator` without a password. Any FAIL stops the script
with the reason; fix it and re-run.

macOS will show a "Background Items Added" notification for the new
LaunchDaemon. It is enabled by default; if the daemon does not start, check
System Settings → General → Login Items & Extensions → *Allow in the
Background* and make sure it is on.

**(g) What you should see in Multica** (<http://localhost:3000>):

- **Runtimes**: a computer named **m4-mini** (the script sets
  `device_name`) with a **Claude Code** runtime online, CLI 0.4.42. It is
  *private* to you — only you can create agents on it, which is what we want.
- Nothing runs until an agent exists. Next steps, in the UI or CLI:
  1. Register the repo **with the SSH URL**, so the daemon's clone and every
     agent push travel over the deploy key, never the PAT:
     `sudo -u multica -H /Users/multica/.local/bin/multica repo add --url git@github.com:ezybg7/pantry.git`
  2. Agents → New agent → runtime *m4-mini / Claude Code*, e.g. `pantry-dev`
     (instructions from the spec's phase 1 notes: `github_repo` mode puts the
     CLI one level above the checkout, so repo hooks do not load; agents that
     need them use a `local_directory` resource pointing at
     `/Users/multica/work/pantry` in `worktree` mode).
  3. Assign it a trivial pantry issue — the phase 1 acceptance line: a PR from
     a branch pushed with the deploy key, opened with the scoped token,
     **unmerged**.

**(g2) Recommended, your call — protect `main`.** Today `main` has no
protection, so the deploy key (write) could push to it directly. A ruleset
keeps the boundary honest: GitHub → repo Settings → Rules → Rulesets → *New
branch ruleset*: target `main`; rules **Require a pull request before
merging** and **Block force pushes**; bypass list **Repository admin** (that
is you and the orchestrator's `gh`, so "trivial fixes straight to main" keep
working) — and do **not** add *Deploy keys* to the bypass list. Not applied by
the orchestrator because a ruleset also binds any workflow that pushes to
`main`; check `.github/workflows` first.

## Operate

```bash
sudo launchctl print system/com.user.multica-daemon | grep -E 'state|pid'
sudo launchctl kickstart -k system/com.user.multica-daemon      # restart (cancels running tasks)
sudo -u multica -H /Users/multica/.local/bin/multica daemon status
sudo -u multica -H /Users/multica/.local/bin/multica daemon logs -n 100   # ~multica/.multica/daemon.log (rotated)
sudo cat /Users/multica/Library/Logs/multica-daemon/launchd.log          # only start lines and crashes
curl -s 127.0.0.1:19514/health | jq .                                     # daemon health (loopback only)
```

- Concurrency is 2 (`MULTICA_DAEMON_MAX_CONCURRENT_TASKS`, also persisted in
  the CLI config). The job runs at `nice 5`, so agent builds yield to the
  queue worker and to you.
- **Weekly bump**: when the orchestrator rebuilds the server from a new tag,
  re-run `sudo MULTICA_CLI_VERSION=<new> bash ~/agents/multica/daemon-user/setup-multica-user.sh`
  — it replaces only the CLI binary (checksum-verified) and skips every
  stored token. The daemon notices the replaced binary and restarts into it
  once idle; `kickstart -k` forces it.
- **Token renewal**: `--rotate-tokens` re-prompts for all three. The Multica
  PAT self-renews while it has an expiry; GitHub and Claude tokens do not —
  the script prints the GitHub expiry it sees.

## Rollback

```bash
# 1. stop the daemon and remove the job (KeepAlive stops with the bootout)
sudo launchctl bootout system/com.user.multica-daemon
sudo rm /Library/LaunchDaemons/com.user.multica-daemon.plist
# 2. revoke the three tokens where they were minted
#    Multica:  Settings → API Token → revoke "m4-mini daemon"
#    GitHub:   Settings → Developer settings → Fine-grained tokens → delete "m4-mini multica daemon"
#    Claude:   your Claude account settings → sessions/devices → revoke the setup-token entry
#              (or mint a new one with `claude setup-token`; the old file is deleted with the user)
# 3. delete the deploy key
gh repo deploy-key list --repo ezybg7/pantry        # find the id of "m4-mini multica daemon"
gh repo deploy-key delete <id> --repo ezybg7/pantry
# 4. remove the user and its home (tokens, clone, workspaces, CLI installs all live there)
sudo sysadminctl -deleteUser multica                 # add -secure to overwrite the home first
sudo rm -rf /Users/Shared/multica-daemon
# 5. (optional) drop the pg_hba.conf reject line for role multica — harmless to keep
```

Nothing in this runbook touches Neon, the Ambry app, or the Multica
server/web services from phase 1.
