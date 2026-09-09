## What failed

- **Workflow:** Nightly build check (`.github/workflows/nightly-build.yml`)
- **Job:** `bundle` (`runs-on: ubuntu-latest`)
- **Step:** none — the job never started
- **Trigger:** `schedule` (nightly cron) on `main` @ `1be495c`
- **Run:** https://github.com/ezybg7/pantry/actions/runs/34230947259

GitHub attached this annotation to the run, and produced no step log:

```
The job was not started because recent account payments have failed or your
spending limit needs to be increased. Please check the 'Billing & plans'
section in your settings
```

```
$ gh run view 34230947259 --log-failed
log not found: 102076626538
```

## Classification and why — `infra`

This is the canonical GitHub-hosted dispatch failure, not anything in the repo:

- **`jobs` API** — the `bundle` job has **zero steps** and an **empty runner** — nothing was ever scheduled onto a machine:
  ```json
  {"name":"bundle","conclusion":"failure","status":"completed",
   "runner_name":"","runner_id":0,"steps":0,
   "started_at":"2026-09-08T13:16:24Z","completed_at":"2026-09-08T13:16:26Z"}
  ```
- **Duration** — the whole run lived ~4s (created `13:16:23` → updated `13:16:27`); the job "ran" 2s. No `npm ci`, no `expo export` ever executed.
- **The annotation names the cause outright**: failed payment / spending limit.

That rules out the other three classes:
- **`code`** — impossible: the change under test never ran. `head_sha` is `main`; a scheduled run, no diff to blame. No compile, no bundle, no output.
- **`test`** — no test executed; there is no assertion, snapshot, or fixture in play.
- **`flake`** — this is not a race that a re-run clears. Until billing is restored, every `ubuntu-latest` dispatch will fail the same way, so a re-run would only burn a triage slot. (Deliberately **not** re-run for that reason.)

## Root cause

GitHub refused to dispatch the `bundle` job onto a GitHub-hosted `ubuntu-latest`
runner because the account's Actions billing is blocked — "recent account
payments have failed or your spending limit needs to be increased." No runner
was assigned (`runner_name: ""`), so no step log exists (`log not found`). The
repository, the workflow, and the commit under test are all fine.

The self-hosted runner is unaffected: `m4-mini` reports `status: online`,
`busy: false`. The failure is specific to GitHub-hosted minutes.

## Reproduced locally?

**Not reproduced locally**, and it is not reproducible locally by nature — this
is a GitHub Actions billing/dispatch condition on GitHub's side, with no repo
input. The evidence is the run's own API + annotation, quoted above.

## What changed, and what deliberately did not

**Nothing in the repo — and nothing should.** No PR. Rule 1 / Step 5: an `infra`
failure means nothing in the repo is broken, so nothing in the repo changes. The
tempting move — quietly editing `nightly-build.yml` to move `bundle` onto
`[self-hosted, m4-mini]` so the nightly goes green — was refused: that is a real
workflow design decision (a single Mac mini vs. GitHub's ephemeral Ubuntu
images, and `expo export --platform ios` toolchain differences), it is Everett's
call, and making it here would hide a billing problem that affects **every**
hosted job, not just this one.

## Remedy — Everett's to do

One of:

1. **Restore Actions billing** — GitHub → Settings → **Billing & plans** → clear
   the failed payment / raise the spending limit. This is the direct fix and
   unblocks all hosted-runner jobs at once. *(I could not confirm the exact
   billing state via API — the token lacks the `user`/billing scope; the
   `settings/billing/actions` endpoint returned 404/needs-scope. The run
   annotation is the authoritative signal.)*
2. **(Optional, separate decision)** Move the nightly `bundle` job onto the
   self-hosted `[self-hosted, m4-mini]` runner — it is online and idle, and
   macOS runs the iOS bundle fine. This removes the nightly's dependence on
   hosted minutes but is a deliberate workflow change, not a triage fix; open it
   as its own PR if you want it.

## How to verify

After billing is restored, re-run the nightly (or wait for tonight's 09:00 UTC
cron): `gh run rerun 34230947259`. A healthy run assigns a non-empty
`runner_name`, executes `npm ci` + `npx expo export`, and produces a step log.

## What is still uncertain

- The **precise** billing state (failed card vs. spending-limit hit) — token
  scope prevented reading the billing API; the annotation says "payments have
  failed or your spending limit needs to be increased" and does not disambiguate.
- Whether other recent **hosted** jobs (several `CI` / `Secret scan` /
  `Disclosures` PR runs failed today) share this exact cause was **not** verified
  here — they are outside this run's scope, on other branches, and some CI is
  mid-migration to self-hosted (`ci/self-hosted-remaining-*`). If billing is the
  common cause, restoring it clears them too.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
