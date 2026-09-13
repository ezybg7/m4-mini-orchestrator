---
type: log
title: Ambry design tour — 2026-09-12
description: A repeatable Maestro screenshot tour of every reachable Ambry screen on the iPhone 17 Pro simulator, in light, dark and largest-accessibility-text, against a disposable Neon branch.
tags: [pantry, design, hig, maestro, simulator, neon]
timestamp: 2026-09-12T15:04:00Z
---

# Ambry design tour — 2026-09-12

A run directory, not a knowledge concept: the scripts, flows and screenshots that
let the orchestrator score Ambry's UI against Apple's HIG, and re-capture the same
set after the feature PRs merge. Durable facts that come out of it belong in
`~/agents/memory/`, linked from there — not here.

## What this is

| | |
|---|---|
| Repo under test | `/Users/orchestrator/code/pantry` @ `main` `2d945d7f` |
| Device | iPhone 17 Pro, iOS 26.5, udid `70893D75-19E3-4CF2-8DBC-84B6BD00C3C7` |
| Build | `~/agents/builds/Ambry-sim-release-design-tour.app` (Release, unsigned, `--device generic` path) |
| Database | Neon branch `design-tour-2026-09-12` = `br-winter-hall-a630bzfe`, endpoint `ep-lucky-heart-a6fj97ku` (us-west-2), parent `production` |
| Data API | `https://ep-lucky-heart-a6fj97ku.apirest.us-west-2.aws.neon.tech/neondb/rest/v1` — **already active**, inherited from production with no CLI step needed |
| Production | never written to. Proof: `strings Ambry.app/main.jsbundle \| grep -c <prod endpoint id>` = **0**, branch endpoint id = **1**. The bundle is Hermes bytecode, so a plain `grep` on the file reports 0 for everything and proves nothing — `strings` first is the whole point. |

## Three things that cost a pass each, recorded so the next tour does not

1. **Maestro 2.10 sandboxes `takeScreenshot`.** An absolute path is refused
   ("it resolves outside this run's takeScreenshot output folder"); a relative one
   lands under the run's own output dir. So the flows use BARE names and `tour.sh`
   points the run at `out/<mode>` with `--test-output-dir`, then copies the PNGs
   into `shots/<mode>/`. An absolute `runFlow`, by contrast, works fine.
2. **`launchApp: clearState: true` does not sign Ambry out.** It wipes the app
   container, but the Better Auth session does not live there — the first attempt
   cleared state, relaunched, and landed on a fully signed-in Pantry tab. The
   signed-out flow uses the app's own Profile → Sign out instead, which is both
   reliable and the honest gesture.
3. **The keyboard is over the tab bar, and Maestro taps through it.** The grocery
   field re-focuses itself after every Enter (`blurOnSubmit={false}`), so the
   fixture's `tapOn: 'Pantry, tab.*'` hit a key. Fixed by ordering the grocery
   block last; the same class of bug put a CTA below the fold ("Start cooking" is
   the last child of the recipe ScrollView, so `visible` is false on any recipe
   long enough to scroll — the nav-bar Favorites button is the signal instead).

## Files

- `env.sh` — sources `~/agents/.env.acceptance` internally and exports only
  `TEST_EMAIL` / `TEST_PASSWORD` (handed to maestro via `-e`), plus the branch
  identifiers. No credential value is written to disk or printed by anything here.
- `build.sh` — Release simulator build with the branch Data API URL baked in,
  following `~/agents/scripts/acceptance-cycle.sh`'s build path (metro cache
  cleared, `xcodebuild` from `ios/`, `strings` proof, install, launch).
- `seed.sh` — one pass of the repo's Maestro acceptance suite against the branch,
  to fill it with items, grocery rows, recipes, zones and waste outcomes.
- `flows/` — the tour itself (Maestro YAML). `_login.yaml` delegates to the repo's
  `.maestro/acceptance/_login.yaml` by absolute path, so the sign-in idioms are
  never forked (Maestro 2.10 resolves an absolute `runFlow`, verified by probe).
  `00-seed-tour.yaml` + `01-seed-outcomes.yaml` are the fixture the tour needs on
  top of the suite's residue; `10`–`90` are the six screenshot flows.
- `deeplinks.sh` — the screens no UI path reaches, via `pantry://` and
  `xcrun simctl openurl`.
- `tour.sh` — the one command: fixture, then three appearance passes, then the
  480px JPEG copies, then restore the simulator.
- `make-index.sh` → `shots/index.json` — screen name → route file(s) → which
  modes captured it.
- `shots/<light|dark|ax5>/<name>.png`, `thumbs/<mode>/<name>.jpg`.
- `README.md` — how to re-run after a rebuild, and what is missing and why.

## Seeding run (step 3) — the repo's acceptance suite, once, against the branch

**16 / 18 passed** in ~17 min (`logs/seed-acceptance.log`). The two failures are
the suite meeting a branch forked from **production** rather than a freshly reset
one, not app defects:

| flow | result |
|---|---|
| 01-auth, 02-add-item, 03-search, 04-item-screen, 05-status-lifecycle | Passed |
| 09-grocery-list, 10-recipes-crud, 11-grocery-restock | Passed |
| **12-expiring-swipe** | **Failed** — `.*Milk, Fridge.*` not visible. The seeded Milk row is marked *out* (struck through) on this branch, so it is not in the expiring list the flow swipes. |
| **13-waste-scorecard** | **Failed** — `Mozzarella, added.*` not found. It builds a five-item fixture and re-finds each row in the Fridge; on a branch whose Fridge already holds 11 foods the new row is below the fold. |
| 15-zones, 44-leftover-composition, 47-ratings, 48-folders | Passed |
| 06-households, 07-profile, 08-paywall, 11-account-deletion | Passed |

Both failures are worth reporting upstream: the suite's flows assume a household
with no inventory, and say so in their own headers ("run the suite in filename
order on a freshly branched Neon database"). A branch off production is not that.

## Result

See `README.md` for the captured/missing tables, the data the tour depends on,
and the one-command re-run.

## What the accessibility pass cost, and what it found

The `ax5` mode (light + `accessibility-extra-extra-extra-large`) needed seven
selector changes that the other two modes did not, and every one of them is a
layout fact worth a reviewer's attention rather than a flake:

| what broke | why |
|---|---|
| sign-in | `sign-in-submit` is below the fold. The screen scrolls (`sign-in.tsx:111`) but nothing says so, and the repo's `_login.yaml` taps the button without scrolling. Worked around with `flows/_signin.yaml`, which signs in at the default size first. |
| Fridge location screen | the dismissible "Struck-through items are ones you've run out of…" banner fills the entire viewport; the search field below it is off-screen. |
| the waste scorecard card | below the location grid and so below the fold on the Pantry tab. |
| Lists → Restock | four To Buy rows push the Restock button under the fold. |
| My recipes → Folders | the Folders row is below the segment header's own controls. |
| Profile → Household | the Account card alone is taller than the screen. |
| Profile → Sign out | the tab is several screens tall; 30 s of scrolling did not reach the bottom. |
| Pantry tab → a location card | the Expiring Soon card alone takes most of the viewport, so the location grid starts below the fold. |

Two more render facts visible in the shots themselves: the Pantry tab's location
card clips its own name ("Pantr / y"), and the sign-in screen's Google button
label runs off the right edge mid-word.


## Review page

- **Ambry Screen Review** (artifact, decisions in its `decisions` collection): https://claude.ai/code/artifact/4e22db74-5799-4a17-be40-e6d587f108aa — 43 screens scored (avg 30.9/40), 12 cross-screen decisions (`systemic.json`), per-screen findings and proposed changes (`scores.md`, `scores-2.md`, `scores-3.md`); rebuilt by `python3 build-review-page.py` and republished to the same URL.
- Capture used for the page: the 13:05 recapture of `main` at b40d2bf (light 46 · dark 46 · ax5 26, including the deep-link screens first-run, onboarding, paywall via `deeplinks.sh`).
