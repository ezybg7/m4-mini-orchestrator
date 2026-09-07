Run 9 of the acceptance suite (2026-09-06 17:46–17:59 EDT, Neon branch
`rehearse-2026-09-06`) was **5/18** where run 8 had been 18/18. **No app
regression** — every failure screenshot shows the screen rendering correctly.
Two environmental causes, both fixed here, and the suite now passes **18/18
twice in a row on the same branch and the same installed build**.

## Cause 1 — iOS's "Save Password?" alert

The simulator was erased that morning, so the first sign-in raised the keychain's
save offer. That alert belongs to another process and Maestro's iOS driver is
app-scoped, so its hierarchy dump held **the status bar and nothing else** while
the app rendered perfectly underneath — and every assertion after the sign-in
failed against a screenshot that looks like a passing screen.

Evidence:
`~/.maestro/tests/2026-09-06_174646/01-auth/screenshots/step-020-assertCondition-Search_your_whole_pantry.png`
(Pantry header, "Search your whole pantry", Expiring Soon, the location cards,
all five tabs — with **Save Password? / Not Now / Save** over them) and the
matching `screen-hierarchy/step-020-…json`, whose only leaves are the clock,
Cellular, Wi-Fi and battery.

**Fix — make it never appear, at the simulator, not in the flows.**
`scripts/run-acceptance.mjs` now runs this before it spawns Maestro:

```
xcrun simctl spawn booted defaults write com.apple.WebUI AutoFillPasswords -bool false
```

`com.apple.WebUI` is the domain — **not** the widely cited
`com.apple.Preferences`. Its `AutoFillPasswords` key is named in the runtime's
own `System/Library/DefaultsConfigurations/com.apple.WebUI-cloud-users.defaults`,
which is the only file in the entire iOS 26.5 runtime that mentions the key at
all. Proven, not assumed:

1. erase → boot → install → `maestro test 01-auth` ⇒ **FAILED** at
   `assertCondition "Search your whole pantry"`, and `simctl io screenshot` at
   that moment shows the alert (reproduction of run 9 in isolation);
2. erase → boot → **the one `defaults write`** → install → `maestro test
   01-auth` ⇒ **passed end to end**, both sign-ins included, no other change.

Rejected alternatives: a Maestro-side `runFlow: when: visible:` tapping "Not
Now" cannot work — Maestro *cannot see the alert* (that is the failure), so it
could only tap blind coordinates, and the guard would then have to sit in every
flow's sign-in path. Setting the toggle once by hand does not survive
`simctl erase`, which is the case that broke.

It also went into `~/agents/scripts/acceptance-cycle.sh` right after boot, so a
`--build-only` cycle leaves the device ready; the repo copy is the one that
matters, because it also covers `--run-only`, where the boot block is skipped.

## Cause 2 — four flows asserting the shared account's totals

Not residue. Every acceptance branch forks **production**, and production's
seeded `test@pantry.dev` has grown data of its own (verified with `psql` against
the branch, never production):

- a grocery list of **six `needed` rows** — Tomatoes, Lemons, Yogurt, Butter,
  Coffee, Oat milk — **plus a `checked` Bananas**, all stamped 2026-09-06 18:10 UTC;
- **five recipes**, two of them `public` ("Spinach and lemon pasta",
  "Shakshuka"), seeded 18:12 UTC;
- ~36 inventory rows, about 20 of them in the Fridge.

**On the "root cause where cheap" ask:** the two public recipes are *not* suite
residue and no flow needs fixing for them. `10-recipes-crud` and `48-folders`
each delete the recipe they create (`Test Pancakes`, `Rated Pancakes`), and the
branch confirms it — the only recipes present are the five production ones, and
none of them carries a suite name.

| Flow | What failed | What changed |
|---|---|---|
| `09-grocery-list` | `assertNotVisible: 'To Buy'` with six seeded rows still in the section (`09-grocery-list/screenshots/step-025-…png`) | Empties the list first via the new shared include, so every claim about a section appearing/disappearing is about **its** row again. Every existing assertion kept, verbatim |
| `11-grocery-restock` | `.*Restock 1 bought item.*` against a cart holding two bought Bananas — the button read **Restock 2 to Kitchen** (`11-grocery-restock/screenshots/step-021-…png`) | Same include. The `1` stays absolute **on purpose**: with the list empty it counts exactly what the flow ticked off, which is the assertion's point |
| `44-leftover-composition` | `.*Leftovers \(with meat\).*` on a correct ~20-row Fridge where the row is simply **below the fold** (`44-leftover-composition/screenshots/step-036-…png`) | Filters the shelf with "Search this location" → `Leftovers` (05's habit) before asserting, and **deletes its own row at the end** — it used to be documented residue |
| `07-profile` | `0 recipes · 0 followers · 0 following` against **"2 recipes · …"** over two production recipes (`07-profile/screenshots/step-030-…png`) | Asserts the line's shape (`\d+ recipes? · 0 followers · 0 following`) **and that the count agrees with the list under it**, in two arms |

### The new shared include

`.maestro/acceptance/_empty-grocery-list.yaml` — one place, following the
`_launch` / `_login` convention (the leading underscore keeps it out of
`config.yaml`'s `[0-9]*.yaml` batch). It ticks every To Buy row into the cart
(`repeat: while: visible: '.*, not bought'`, capped at 30) and then empties the
cart through the In Your Cart overflow menu: the app's own gestures, never SQL,
per §Preconditions. Looping the tick is safe because `useSetGroceryStatus`'
`onMutate` is optimistic, so the row has left the section before Maestro
re-reads the hierarchy — and the loop converges even if a tap lands twice.

### On `07-profile`, said plainly

The flow still proves the bio round trip (row → editor → Save → the row speaks
it → the public profile shows it → clear), still proves the stats line renders,
and now proves something the old assertion only implied: **the count and the
list agree**. Two arms — empty state ⇒ `0 recipes`; no empty state ⇒ a non-zero
count *and* a listed card (`Open <title>`) — so a screen whose header and list
came from different queries fails whichever arm it is in.

One thing is genuinely weaker and is recorded in the doc rather than glossed:
**the count moving when a recipe is published is not proven end-to-end.** Making
it so would mean `07` creating a public recipe through the create form and the
visibility editor, which scenario 10 marks `[manual]` precisely because it is
fiddly — a flakiness risk in the release gate for a claim already covered by
`creatorProfile.test.tsx` and spec 51's row-4 two-account pass.

## Runs

**Run 10 — 2026-09-06 18:33–18:46 EDT, 18/18 in 12 m 30 s.** From a genuinely
cold start: `xcrun simctl erase` first, which is the condition that produced run
9's alert. The seeded grocery list was restored on the branch beforehand (psql,
branch only) so the run faced the same seven rows the ninth met.

```
prod id hits: 0  branch id hits: 1  (prod must be 0)
autofill passwords off
run-acceptance: target confirmed — ep-bold-voice-a6u2s6nc.apirest.us-west-2.aws.neon.tech
run-acceptance: iOS AutoFill Passwords disabled on the booted simulator
[Passed] 01-auth (1m 6s)          [Passed] 13-waste-scorecard (1m 45s)
[Passed] 02-add-item (38s)        [Passed] 15-zones (32s)
[Passed] 03-search (22s)          [Passed] 44-leftover-composition (35s)
[Passed] 04-item-screen (29s)     [Passed] 47-ratings (35s)
[Passed] 05-status-lifecycle (36s)[Passed] 48-folders (57s)
[Passed] 09-grocery-list (39s)    [Passed] 06-households (33s)
[Passed] 10-recipes-crud (53s)    [Passed] 07-profile (45s)
[Passed] 11-grocery-restock (33s) [Passed] 08-paywall (18s)
[Passed] 12-expiring-swipe (25s)  [Passed] 11-account-deletion (50s)
18/18 Flows Passed in 12m 30s
```

**Run 11 — 18:46–18:59 EDT, 18/18 in 12 m 28 s**, `--run-only`, started thirteen
minutes later. Same installed build, simulator **not** erased, branch **not**
reset — it began on exactly what run 10 left behind, which I checked first: one
`needed` Milk row (12's List swipe, deliberate), **zero** Leftovers rows (44's
new cleanup), recipes back to production's five. **This is the proof**, not run
10: a flow still depending on a pristine account fails here.

```
[Passed] 01-auth (1m 16s)         [Passed] 13-waste-scorecard (1m 46s)
[Passed] 02-add-item (37s)        [Passed] 15-zones (32s)
[Passed] 03-search (22s)          [Passed] 44-leftover-composition (35s)
[Passed] 04-item-screen (29s)     [Passed] 47-ratings (35s)
[Passed] 05-status-lifecycle (33s)[Passed] 48-folders (57s)
[Passed] 09-grocery-list (30s)    [Passed] 06-households (33s)
[Passed] 10-recipes-crud (52s)    [Passed] 07-profile (45s)
[Passed] 11-grocery-restock (33s) [Passed] 08-paywall (18s)
[Passed] 12-expiring-swipe (25s)  [Passed] 11-account-deletion (51s)
18/18 Flows Passed in 12m 28s
```

Logs: `~/agents/logs/acceptance-run10.log`, `~/agents/logs/acceptance-run11.log`.
Gates: `npm run typecheck`, `npm run lint`, `npx jest --maxWorkers=2` (199 suites,
4319 passed) all green.

## Also fixed on the way

`acceptance-cycle.sh`'s "prod must be 0" bake guard **silently degraded in a
worktree**: `.env` is gitignored, so a fresh checkout has none, `PROD_ID` came
out empty, and `grep -c ""` then counted every line of the bundle — the guard
printed `prod id hits: 14778` while the real signal, `branch id hits: 0`,
scrolled past. Nothing was baked at all (no Neon host anywhere in the bundle;
`EXPO_PUBLIC_*` comes from `.env`, not from the `xcodebuild` environment alone).
Caught before any flow ran, the run was killed, and the script now refuses to
build when `PROD_ID` is empty. That script lives in `~/agents/scripts/`, so the
fix is not in this diff — it is recorded here so it is not lost.

## Still fragile

- **`07-profile`'s empty arm is `[manual]` in practice.** The seeded account has
  public recipes, so the `0 recipes` + "No public recipes yet." branch is never
  the one that executes on this account.
- **`12-expiring-swipe` still leaves a `needed` Milk row** behind by design.
  Nothing reads the list after it, and `05` removes it on the next run before
  `09` empties — but it is the one piece of grocery residue the suite still
  creates deliberately.
- **`06-households` still leaves the invite code rotated**, as its header says.
- **The suite still mutates a shared account.** These four flows no longer
  *depend* on its state, but 02/05/12/13 do write to it. The rule added under
  §E2E gate is what keeps that from turning back into this failure.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
