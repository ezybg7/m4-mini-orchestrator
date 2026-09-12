# PR #185 review — Spec 57, email verification at sign-up (beefa77, docs only)

**Verdict: approvable for Everett WITH FIXES.** The strict gate is his call (DECISION 2 / K7) and the spec argues it correctly. Two spec-text defects must be fixed before the implementation PR starts (FIND-001/002); neither needs a new product decision. Every Better Auth citation I checked against the pinned 1.7.2 source is line-accurate.

## Strengths
1. `specs/email-verification.md:117-137` — every option carries a 1.7.2 source line; all nine I checked hold.
2. `:139-143` "Why the link is inert" — verified: `/verify-email` flips the flag, answers `{status:true,user:null}`, sets a cookie only under `autoSignInAfterVerification` (`email-verification.mjs:287-321`). D8/D9/O2 genuinely stand.
3. `:88-111` + `:230-248` — every string enumerated; outcome-based acceptance with the failure path and the RLS boundary.
4. `:189-198` + `:265-272` — grant-on-verification reconciled with #182; grandfather ordered before 0061.

## Decisions
| # | Question | PR default | Recommendation | Who decides |
|---|---|---|---|---|
| 1 | Gate strictness | strict | Keep strict — the lenient axis is five places to forget a check | Everett (re-confirm on the PR) |
| 2 | Prune scope | any unverified user, no session row, >30 d | Credential-only accounts with no `household_members` row | Agent; Everett informed |
| 3 | Per-address mail ceiling | 1/min, verification mail only | 1/min **and** ≤5/day, covering the existing-account notice | Agent |
| 4 | Grant trigger naming | spec 57 names `grant_welcome_if_verified()` | Spec 57 states the event; #182 names the function (its text still says the signup trigger) | Both PR authors |
| 5 | Resend state after a process kill | in-memory 60 s countdown | Persist last-sent time per address (AsyncStorage) | Agent |

## FIND queue
**FIND-001 · High · security · likely** — `:125`, `:158`. The existing-account notice (`onExistingUserSignUp`) is a fourth mail trigger outside the cooldown "applied inside `sendVerificationEmail`". Re-POST `/sign-up/email` for a victim's address from rotating IPs (10/min per IP; Better Auth's limiter is per-isolate) → unbounded mail to **any** existing account, and Resend's quota exhausted → reset and sign-up fail for everyone. The unverified-address resend path is also 1,440/day for 30 days. Fix: same per-address key for the notice, a daily ceiling for both kinds, one limiter call + one conditional send in both branches (timing parity).

**FIND-002 · High · logic / data loss · likely** — `:176`, `:219`. `not exists session` means "no live session row", not "never signed in". A provider-unverified social account (signed in per `:84-86`) can own a household; `/sign-out` deletes its session row, and an expired row (7-day default) is deleted on the next `/get-session`. At day 30 the prune deletes user → `profiles` (0049:82) → `household_members` (0001:47), orphaning the household. Fix: prune only users whose sole `account` row is `credential` and who have no `household_members` row; assert it in the libpg-query test.

**FIND-003 · Medium · logic/UX · confirmed** — `:69`, `:99`, `:129`. "Sent again" and "we've just sent the link … again" are asserted while the server may have refused silently (one 60 s wall spans sign-up → 403 → Resend). Fix: decision 5; hedge the 403 body.

**FIND-004 · Medium · contract · confirmed** — `:182`, `:221` vs `src/features/auth/context.tsx:131-151`. The handled-URL guard ignores a repeated identical URL; the reset arm clears it only on failure (`:150`). `verify-offline` says "tap the link again" — ignored unless the guard clears on every non-ok verify outcome.

**FIND-005 · Low · security · hypothesis** — `:158`, `:203`. The 500 ms floor is a floor: an awaited Resend call exceeding it tells a probe "exists and unverified". Record as accepted or raise the floor.

**FIND-006 · Low · logic · likely** — `:216-217`. Reset-to-claim inherits the stranger's `name`/`display_name`. Onboarding re-asks, or `onPasswordReset` clears it.

**FIND-007 · Low · test-gap · confirmed** — `:147`. "Awaited" holds only while `advanced.backgroundTasks.handler` is unset (`runInBackgroundOrAwait`); pin it in §Test plan.

**FIND-008 · Low · contract · likely** — `:151`. Mail-less build, correct password, unverified account: the 403 path throws `EmailNotConfiguredError` → 400 with the *reset* message; sign-in has no branch.

**FIND-009 · Low · privacy accuracy · confirmed** — `docs/privacy.md:38-44,152`. "Cannot be signed in to until you tap it" and "Apple or Google confirms the address" are false for `email_verified:false` social accounts (`:84-86`); the Resend row is present tense for a future build. Publishes on merge (`pages.yml`).

**FIND-010 · Note · ops** — `/Users/orchestrator/code/pantry/workers/node_modules` became a self-referential symlink at 07:03 today (not this PR, not my worktree link). Worker typecheck/tests fail until `rm` + `npm ci` in `workers/`. Left untouched.

## Source checks
| Claim | Where | Result |
|---|---|---|
| 403 only after the password matched; mail before the 403; `sendOnSignIn` gates it | `sign-in.mjs:321-352`; docs email-password | ✔ source; latest docs say "every sign-in" — drift, spec sets it explicitly |
| Generic duplicate when `requireEmailVerification \|\| autoSignIn===false`; password hashed; `onExistingUserSignUp({user})` | `sign-up.mjs:163,205-210`; docs | ✔ both |
| `/send-verification-email` 500 ms floor, sends only for existing unverified; HS256 JWT `{email}` exp 3600; GET sans `callbackURL` → 401 JSON / `{status:true,user:null}` | `email-verification.mjs:14-19,105-118,167-181`; `crypto/jwt.mjs:6` | ✔ |
| `onPasswordReset({user})`; `requireLocalEmailVerified` default `true`; `sendOnSignUp ?? provider.requireEmailVerification` | `password.mjs:172`; `link-account.mjs:82-83,259`; docs | ✔ source; docs silent on `requireLocalEmailVerified` |
| Own limiter special-cases `/send-verification-email` (3/60 s) | `rate-limiter/index.mjs:311`; docs rate-limit | ✔ source; docs list other examples |
| Hooks awaited; sign-out deletes the row; expired rows deleted on `/get-session`; TTL 7 d | jsDelivr 1.7.2 `create-context.mjs`, `sign-out.mjs`, `session.mjs`, `internal-adapter.mjs`; `authService.ts:504-507` | ✔ → FIND-002/007 |
| Repo facts | `0048:74`; `index.ts:169-174`; `wrangler.jsonc:16,41-77` (four bindings, 1005 free; hourly cron); `invite.ts:42`; `routes/invite.ts:95-101` (`/reset` renders only); `deleteAccount.ts:239`; #182 diff still names `handle_new_neon_user` | ✔ — `/verify` is the Worker's first state-changing unauthenticated GET, accepted at `:141` |
