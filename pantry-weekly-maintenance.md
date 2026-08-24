# pantry-weekly-maintenance — runbook

Weekly dependency + security pass for **Ambry** (`ezybg7/pantry`, checkout
`~/Code/pantry`). Lives here, on the mini, deliberately: orchestrator/infra
tooling does not go in the pantry repo (PR #101 was closed and deleted for
exactly that).

## Install the cron entry

The script does **not** install itself. Run `crontab -e` and add:

```
0 9 * * 1 /Users/ezy/agents/pantry-weekly-maintenance.sh
```

Monday 09:00. No redirect needed — the script writes everything to
`~/agents/logs/pantry-weekly.log` itself.

If the mini sleeps, cron misses the slot silently; `launchd` with
`StartCalendarInterval` catches up on wake. Only worth switching if you find
weeks missing from the log.

## What one run does

1. **Apple client secret expiry.** Hardcoded `2027-02-18`, warns under 30 days
   left, and prints the exact regeneration commands into the log. Runs first,
   before anything that can fail. Dependabot cannot see this — it is a signed
   ES256 JWT with a hard 6-month expiry, not a package.
2. **`git fetch --prune`** on the checkout, logging the new `origin/main` sha.
3. **Dependabot triage** via `claude -p`, which merges, closes, or comments per
   the policy below, then appends one summary line to the log.

Everything policy-shaped is in the prompt inside the script, not in bash —
deciding whether a bump is a security fix or fights the Expo pin is a reading
job, not a regex.

## The triage policy

The repo carries its own `.github/dependabot.yml` (added 2026-08-22) and the
prompt reads it first. Two facts from it shape everything below:

- **Bumps are grouped** — `app-routine` for `/`, `worker-routine` for
  `/workers`, plus github-actions. One PR usually moves several packages, so it
  is judged by its worst member.
- **The Expo-pinned set and TypeScript are already `ignore`d**, so they should
  never appear as routine bumps. Security advisories are *not* ignorable and do
  still open PRs — which is why an expo-shaped PR is a signal, not noise.

| Situation | Action |
|---|---|
| Routine bump to `expo`, `expo-*`, `@expo/*`, `react-native*`, `react`, `react-dom`, `jest-expo`, or TypeScript | **Close** + comment (SDK-pinned / one unified TS major; the ignore list should have caught it) |
| **Security advisory** on any of that same set | **Escalate** — never merged, never closed. The fix has to go through `npx expo install` or an SDK upgrade, which is a human's call |
| CI fully green **and** every package in the PR is patch/minor, or the PR is a security fix at any level | **Merge** (squash) |
| CI red, CI pending, any major in the set, anything uncertain | **Skip** + comment saying why |

"CI green" is the whole gate set: `.github/workflows/ci.yml` runs root
typecheck, workers typecheck, lint and jest, so the script never re-runs them
locally.

Standing prohibition, repeated in the prompt: never `npm audit fix --force`. It
offers a semver-major *downgrade* of `expo` (53 against a 57 project). The
repo's own `.claude/hooks/guard-bash.mjs` blocks it too, so this is belt and
braces.

The script never edits `package.json` / `package-lock.json` and never pushes.
It merges, closes, and comments — that is the whole blast radius.

## Permissions

The `claude -p` call runs `--dangerously-skip-permissions` because cron cannot
answer a prompt. Bounded by: the tight prompt, the repo's guard hook, and the
fact that merging a PR is the most destructive thing in scope. If you would
rather allowlist, replace that flag with `--allowedTools` naming the GitHub MCP
tools — but confirm the tool prefix on this machine first (`mcp__…__github__*`
varies with how the server is registered), because a wrong prefix makes the run
silently do nothing.

## Reading the log

```
tail -40 ~/agents/logs/pantry-weekly.log
grep 'APPLE SECRET ⚠️' ~/agents/logs/pantry-weekly.log   # the one line worth alerting on
grep 'dependabot:' ~/agents/logs/pantry-weekly.log       # one line per run
```

## Checks and manual runs

```
~/agents/pantry-weekly-maintenance.sh --check   # self-tests the date arithmetic, no side effects
~/agents/pantry-weekly-maintenance.sh           # a real run, right now
```

`--check` exists because BSD-vs-GNU `date` is the one thing here that can break
silently on a new box and would hide the Apple expiry warning.

Overrides: `PANTRY_REPO`, `PANTRY_WEEKLY_LOG`.

## When the Apple warning fires

```
cd ~/Code/pantry
node scripts/apple-client-secret.mjs --key ~/Downloads/AuthKey_YK8V7A579F.p8 \
  --key-id YK8V7A579F --team-id SANRTXS285 --client-id com.everettyan.ambry
cd workers && wrangler secret put APPLE_CLIENT_SECRET && wrangler deploy
```

Then update `APPLE_SECRET_EXPIRY` in the script to the new date (+180 days).
The `.p8` is reusable — it is the *secret JWT* that expires, not the key.
